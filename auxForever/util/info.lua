select(2, ...) 'aux.util.info'

local aux = require 'aux'

CreateFrame('GameTooltip', 'AuxTooltip', nil, 'GameTooltipTemplate')

-- Forever: posting durations are indices 1-3 into the auction house's duration options.
-- Their lengths are read from the client's own labels (AUCTION_DURATION_ONE..THREE), e.g. "12 Hours".
do
    local fallback = { [1] = 12, [2] = 24, [3] = 48 }
    local labels = { 'AUCTION_DURATION_ONE', 'AUCTION_DURATION_TWO', 'AUCTION_DURATION_THREE' }
    function M.duration_hours(duration_code)
        local label = _G[labels[duration_code] or '']
        local hours = label and tonumber(strmatch(label, '(%d+)'))
        return hours or fallback[duration_code]
    end
end

-- Forever: the auction house reports time left either as a band (Enum.AuctionHouseTimeLeftBand, 0-3)
-- or in seconds. aux keeps the Classic convention of duration codes 1-4 (short .. very long).
function M.duration_from_band(band)
    return band and band + 1
end

-- Short label for a duration code, e.g. '30m', '2h', '12h', '48h' (upper end of the time left band)
function M.time_left_label(duration_code)
    local fallback = { '30m', '2h', '12h', '48h' }
    local ok, _, max_seconds = pcall(C_AuctionHouse.GetTimeLeftBandInfo, duration_code - 1)
    if ok and max_seconds and max_seconds > 0 then
        if max_seconds < 3600 then
            return floor(max_seconds / 60) .. 'm'
        end
        return floor(max_seconds / 3600) .. 'h'
    end
    return fallback[duration_code]
end

function M.duration_from_seconds(seconds)
    if not seconds then return end
    for band = 0, 3 do
        local _, max_seconds = C_AuctionHouse.GetTimeLeftBandInfo(band)
        if max_seconds and seconds <= max_seconds then
            return band + 1
        end
    end
    return 4
end

-- Forever: full auction itemLinks carry bonus IDs for random suffixes; Fast browse rows only
-- have an ItemKey. Remember one working link per itemID:itemSuffix when an item search returns it.
local suffix_link_by_key = {}

function remember_suffix_link(item_id, item_suffix, link)
    if type(link) ~= 'string' or not strfind(link, 'item:', 1, true)
        or not item_id or not item_suffix or item_suffix == 0 then
        return
    end
    suffix_link_by_key[item_id .. ':' .. item_suffix] = link
    -- Warm the item cache so the first icon hover does not wait on GetItemStats
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(item_id)
    end
end

function M.suffix_link_for(item_id, item_suffix)
    if not item_id or not item_suffix or item_suffix == 0 then
        return
    end
    return suffix_link_by_key[item_id .. ':' .. item_suffix]
end

M.remember_suffix_link = remember_suffix_link

function M.container_item(bag, slot)
	local link = C_Container.GetContainerItemLink(bag, slot)
    if link then
        local item_id, suffix_id, unique_id, enchant_id = parse_link(link)
        local item_info = item(item_id, suffix_id, unique_id, enchant_id)
        if item_info then -- TODO apparently this can be undefined
            local containerInfo = C_Container.GetContainerItemInfo(bag, slot) -- TODO quality not working?
            local durability, max_durability = C_Container.GetContainerItemDurability(bag, slot)
            local tooltip = tooltip('bag', bag, slot)
            local max_charges = max_item_charges(item_id)
            local charges = max_charges and item_charges(tooltip)
            local auctionable = auctionable(tooltip) and durability == max_durability and charges == max_charges and not containerInfo.hasLoot
            local item_location = ItemLocation:CreateFromBagAndSlot(bag, slot)
            if auction_house_open() and item_location:IsValid() then
                auctionable = C_AuctionHouse.IsSellItemValid(item_location, false)
            end
            if max_charges and not charges then -- TODO find better fix
                return
            end
            return {
                item_id = item_id,
                suffix_id = suffix_id,
                unique_id = unique_id,
                enchant_id = enchant_id,

                link = link,
                item_key = item_id .. ':' .. suffix_id,

                name = item_info.name,
                texture = containerInfo.iconFileID,
                level = item_info.level,
                quality = item_info.quality,
                max_stack = item_info.max_stack,

                count = containerInfo.stackCount,
                locked = containerInfo.isLocked,
                readable = containerInfo.isReadable,
                auctionable = auctionable,

                tooltip = tooltip,
                item_location = item_location,
            }
        end
    end
end

do
    local open = false
    function aux.event.AUX_LOADED()
        aux.event_listener('AUCTION_HOUSE_SHOW', function() open = true end)
        aux.event_listener('AUCTION_HOUSE_CLOSED', function() open = false end)
    end
    function M.auction_house_open()
        return open
    end
end

-- Forever: auction records are built from C_AuctionHouse results instead of GetAuctionItemInfo.
-- They keep the field names of Classic aux so the listings, filters and history work unchanged.
-- See docs/forever-auction-house.md for how the modern auction house reports listings.
-- New fields:
--   auction_id     used to bid/buy directly
--   auction_count  how many identical auctions the record stands for (an item search row is a
--                  bucket of identical auctions, each priced per item)
--   commodity      bought by quantity, cheapest units first
--   item_search_key  the item key the record was searched with (to re-read its bucket)

local record_mt = {
    __index = function(record, key)
        -- the tooltip is only built when a filter actually needs it, which keeps scans fast
        if key == 'tooltip' and record.link then
            local tooltip = tooltip('link', record.link)
            rawset(record, 'tooltip', tooltip)
            return tooltip
        end
    end,
}

local function player_guid()
    return UnitGUID'player'
end

function M.signatures(record)
    local own = aux.account_data.ignore_owner and (is_player(record.owner) and 0 or 1) or (record.owner or '?')
    record.search_signature = aux.join({record.item_id, record.suffix_id, record.enchant_id, record.start_price, record.buyout_price, record.bid_price, record.count, record.sale_status == 1 and 0 or (record.duration or 0), record.high_bidder and 1 or 0, record.sale_status or 0, own}, ':')
    record.sniping_signature = aux.join({record.item_id, record.suffix_id, record.enchant_id, record.start_price, record.buyout_price, record.count, own, record.auction_id or 0}, ':')
end

-- auxForever (0.7): equip slots whose item level means nothing to a player (bags, quivers)
local NO_ITEM_LEVEL = {[''] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true}

-- Returns name, texture, quality, requirement, usable, link and item level for an item, or nil if
-- the client has not cached it yet. The item level is nil for anything that is not gear (0.7,
-- FB-013: Forever's tooltips do not show it, so the iLvl column is the only place to see it).
function M.item_basics(item_id, link)
    local name, item_link, quality, item_level, requirement, _, _, _, slot, texture = GetItemInfo(link or item_id)
    if name then
        local usable = true
        if C_PlayerInfo and C_PlayerInfo.CanUseItem then
            usable = C_PlayerInfo.CanUseItem(item_id)
        end
        if NO_ITEM_LEVEL[slot or ''] or (item_level or 0) <= 0 then
            item_level = nil
        end
        return name, texture, quality, requirement or 0, usable, item_link, item_level
    end
end

-- the item level of a gear record: the auction house's own item key when it gives one, else the item's
local function key_item_level(key, item_level)
    if item_level and type(key) == 'table' and (key.itemLevel or 0) > 0 then
        return key.itemLevel
    end
    return item_level
end

function M.request_item(item_id)
    if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(item_id)
    end
end

local function new_record(item_id, link, count)
    local record = setmetatable({}, record_mt)
    local _, suffix_id, unique_id, enchant_id = parse_link(link or '')
    local name, texture, quality, requirement, usable, item_link, item_level = item_basics(item_id, link)
    if not name then return end
    learn_item(item_id)
    link = link or item_link
    record.item_id = item_id
    record.suffix_id = suffix_id
    record.unique_id = unique_id
    record.enchant_id = enchant_id
    record.link = link
    record.item_key = item_id .. ':' .. suffix_id
    record.name = name
    record.texture = texture
    record.quality = quality
    record.requirement = requirement
    record.item_level = item_level
    record.usable = usable
    record.count = count
    return record
end

local function set_prices(record, min_bid, bid_amount, buyout)
    local count = max(record.count, 1)
    min_bid, bid_amount, buyout = min_bid or 0, bid_amount or 0, buyout or 0
    record.high_bid = bid_amount
    record.bid_price = min_bid > 0 and min_bid or buyout
    record.start_price = bid_amount > 0 and bid_amount or record.bid_price
    record.min_increment = bid_amount > 0 and max(0, record.bid_price - bid_amount) or 0
    record.blizzard_bid = bid_amount > 0 and bid_amount or record.bid_price
    record.buyout_price = buyout
    record.unit_blizzard_bid = record.blizzard_bid / count
    record.unit_bid_price = record.bid_price / count
    record.unit_buyout_price = buyout / count
end

-- The player's own entry in an owners list is the string "player"
local function seller(result, own)
    if own then
        return UnitName'player'
    elseif #result.owners == 1 and result.owners[1] ~= 'player' then
        return result.owners[1]
    end
end

-- Same rule as Blizzard's AuctionHouseUtil.IsOwnedAuction: every auction in the row is the player's
local function owned_row(result)
    return (#result.owners == 1 and (result.containsOwnerItem or result.containsAccountItem))
        or (#result.owners == 2 and result.containsOwnerItem and result.containsAccountItem)
        or false
end

-- One row of an item search (C_AuctionHouse.GetItemSearchResultInfo). The row is a bucket of
-- result.quantity identical auctions; its prices are for one item and PlaceBid buys one auction.
function M.item_search_record(result)
    local record = new_record(result.itemKey.itemID, result.itemLink, 1)
    if not record then return end
    record.auction_id = result.auctionID
    record.auction_count = max(1, result.quantity or 1)
    record.item_search_key = result.itemKey
    record.item_level = key_item_level(result.itemKey, record.item_level)
    record.raw_min_bid, record.raw_bid, record.raw_buyout = result.minBid or 0, result.bidAmount or 0, result.buyoutAmount or 0
    set_prices(record, result.minBid, result.bidAmount, result.buyoutAmount)
    record.high_bidder = result.bidder and result.bidder == player_guid() or nil
    record.own = owned_row(result)
    record.contains_own = result.containsOwnerItem or nil
    record.owner = seller(result, record.own)
    record.seller_count = result.totalNumberOfOwners or #result.owners
    record.duration = result.timeLeftSeconds and duration_from_seconds(result.timeLeftSeconds) or duration_from_band(result.timeLeft)
    record.sale_status = 0
    signatures(record)
    -- Forever: remember the full bonus link so Fast parent rows of this item key can show +stats.
    -- pcall: never let suffix work abort building a search row (buy bar depends on these records).
    local key = result.itemKey
    if key and result.itemLink then
        pcall(function()
            remember_suffix_link(key.itemID, key.itemSuffix or 0, result.itemLink)
            local tip = require 'aux.core.tooltip'
            record.suffix_stats = tip.cache_suffix_stats(result.itemLink)
        end)
    end
    return record
end

-- One price tier of a commodity (C_AuctionHouse.GetCommoditySearchResultInfo).
-- Commodities have no bids; buying a quantity always takes the cheapest listings and skips the
-- player's own, so the record's count is what the player can actually buy at this price.
function M.commodity_record(result)
    local available = result.quantity - (result.numOwnerItems or 0)
    local own = available <= 0
    local count = own and result.quantity or available
    local record = new_record(result.itemID, nil, count)
    if not record then return end
    record.commodity = true
    record.auction_id = result.auctionID
    record.commodity_unit_price = result.unitPrice
    set_prices(record, 0, 0, result.unitPrice * count)
    record.own = own
    record.own_count = result.numOwnerItems
    record.owner = seller(result, own)
    record.seller_count = result.totalNumberOfOwners or #result.owners
    record.duration = duration_from_seconds(result.timeLeftSeconds)
    record.sale_status = 0
    signatures(record)
    return record
end

-- auxForever: one item of a browse list (fast mode): only the lowest price and how many are for
-- sale are known, not the single auctions. The row stands for the whole item: count 1 at the lowest
-- price, auction_count the units for sale. Opening it reads the real auctions (tabs/search).
-- Returns nil if the client has not loaded the item yet.
function M.browse_record(result)
    local key = result.itemKey
    local item_id = key.itemID
    local name, texture, quality, requirement, usable, item_link, item_level = item_basics(item_id)
    if not name then return end
    learn_item(item_id)
    local key_info = C_AuctionHouse.GetItemKeyInfo(key)
    local record = setmetatable({}, record_mt)
    record.fast = true
    record.browse_key = key
    record.item_id = item_id
    record.suffix_id = key.itemSuffix or 0
    record.unique_id = 0
    record.enchant_id = 0
    record.link = item_link
    record.item_key = item_id .. ':' .. record.suffix_id
    record.name = type(key_info) == 'table' and key_info.itemName or name
    record.texture = type(key_info) == 'table' and key_info.iconFileID or texture
    record.quality = type(key_info) == 'table' and key_info.quality or quality
    record.is_commodity = type(key_info) == 'table' and key_info.isCommodity or nil
    local key_requirement = C_AuctionHouse.GetItemKeyRequiredLevel and C_AuctionHouse.GetItemKeyRequiredLevel(key)
    record.requirement = type(key_requirement) == 'number' and key_requirement > 0 and key_requirement or requirement
    record.item_level = key_item_level(key, item_level)
    record.usable = usable
    record.count = 1
    record.auction_count = max(1, result.totalQuantity or 1)
    set_prices(record, 0, 0, result.minPrice or 0)
    record.contains_own = result.containsOwnerItem or nil
    record.sale_status = 0
    signatures(record)
    return record
end

-- After part of a commodity tier was bought
function M.set_commodity_count(record, count)
    record.count = count
    set_prices(record, 0, 0, record.commodity_unit_price * count)
    signatures(record)
end

-- One listing from a full scan (C_AuctionHouse.GetReplicateItemInfo, 0-based index)
function M.replicate_record(index)
    local name, texture, count, quality, usable, level, _, min_bid, min_increment, buyout_price, bid_amount, high_bidder, _, owner, _, sale_status, item_id, has_all_info = C_AuctionHouse.GetReplicateItemInfo(index)
    if not has_all_info or not item_id then
        return nil, item_id
    end
    local link = C_AuctionHouse.GetReplicateItemLink(index)
    local record = new_record(item_id, link, count)
    if not record then
        return nil, item_id
    end
    set_prices(record, bid_amount > 0 and bid_amount + min_increment or min_bid, bid_amount, buyout_price)
    record.min_increment = min_increment
    record.high_bidder = (high_bidder == true or high_bidder == UnitName'player') or nil
    record.owner = owner
    record.duration = duration_from_band(C_AuctionHouse.GetReplicateItemTimeLeft(index))
    record.sale_status = sale_status
    signatures(record)
    return record
end

-- One of the player's own auctions (C_AuctionHouse.GetOwnedAuctionInfo)
function M.owned_record(owned)
    local item_id = owned.itemKey.itemID
    local record = new_record(item_id, owned.itemLink, owned.quantity)
    if not record then
        request_item(item_id)
        return
    end
    record.auction_id = owned.auctionID
    record.item_search_key = owned.itemKey
    -- like every other modern auction house price, these are per unit
    local quantity = max(1, owned.quantity or 1)
    local buyout = owned.buyoutAmount and owned.buyoutAmount * quantity or 0
    local bid = owned.bidAmount and owned.bidAmount * quantity or 0
    set_prices(record, 0, bid, buyout)
    record.start_price = bid > 0 and bid or buyout
    record.high_bidder = owned.bidder
    record.owner = UnitName'player'
    record.sale_status = owned.status == Enum.AuctionStatus.Sold and 1 or 0
    record.duration = owned.timeLeftSeconds and duration_from_seconds(owned.timeLeftSeconds) or duration_from_band(owned.timeLeft)
    signatures(record)
    -- 0.7.1 (FB-015): identical auctions of your own stay apart, each with its own row and cancel
    record.search_signature = record.search_signature .. ':' .. (owned.auctionID or 0)
    if owned.itemKey and owned.itemLink then
        remember_suffix_link(owned.itemKey.itemID, owned.itemKey.itemSuffix or 0, owned.itemLink)
    end
    return record
end

-- One auction the player has bid on (C_AuctionHouse.GetBidInfo)
function M.bid_record(bid)
    local item_id = bid.itemKey.itemID
    local record = new_record(item_id, bid.itemLink, 1)
    if not record then
        request_item(item_id)
        return
    end
    record.auction_id = bid.auctionID
    set_prices(record, bid.minBid, bid.bidAmount, bid.buyoutAmount)
    record.high_bidder = bid.bidder and bid.bidder == player_guid() or nil
    record.duration = duration_from_band(bid.timeLeft)
    record.sale_status = 0
    signatures(record)
    return record
end

function M.bid_update(auction_record)
    auction_record.high_bid = auction_record.bid_price
    auction_record.blizzard_bid = auction_record.bid_price
    auction_record.min_increment = max(1, floor(auction_record.bid_price / 100) * 5)
    auction_record.bid_price = auction_record.bid_price + auction_record.min_increment
    auction_record.unit_blizzard_bid = auction_record.blizzard_bid / auction_record.count
    auction_record.unit_bid_price = auction_record.bid_price / auction_record.count
    auction_record.high_bidder = 1
    signatures(auction_record)
end

function M.set_tooltip(itemstring, owner, anchor)
    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)
end

function M.tooltip_match(entry, tooltip)
    return aux.any(tooltip, function(text)
        return strupper(entry) == strupper(text)
    end)
end

function M.tooltip_find(pattern, tooltip)
    local count = 0
    for _, entry in pairs(tooltip) do
        if strfind(entry, pattern) then
            count = count + 1
        end
    end
    return count
end

function M.display_name(item_id, no_brackets, no_color)
	local item_info = item(item_id)
    if item_info then
        local name = item_info.name
        if not no_brackets then
            name = '[' .. name .. ']'
        end
        if not no_color then
            name = '|c' .. select(4, GetItemQualityColor(item_info.quality)) .. name .. FONT_COLOR_CODE_CLOSE
        end
        return name
    end
end

function M.auctionable(tooltip, quality)
    local status = tooltip[2]
    return (not quality or quality < 6)
            and status ~= ITEM_BIND_ON_PICKUP
            and status ~= ITEM_BIND_QUEST
            and status ~= ITEM_SOULBOUND
            and (not tooltip_match(ITEM_CONJURED, tooltip) or tooltip_find(ITEM_MIN_LEVEL, tooltip) > 1)
end

function M.tooltip(setter, arg1, arg2)
    AuxTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    AuxTooltip:ClearLines()
    if setter == 'bag' then
	    AuxTooltip:SetBagItem(arg1, arg2)
    elseif setter == 'inventory' then
	    AuxTooltip:SetInventoryItem(arg1, arg2)
    elseif setter == 'link' then
	    AuxTooltip:SetHyperlink(arg1)
    end
    local tooltip = {}
    for i = 1, AuxTooltip:NumLines() do
        for side in aux.iter('Left', 'Right') do
            local text = _G['AuxTooltipText' .. side .. i]:GetText()
            if text then
                tinsert(tooltip, text)
            end
        end
    end
    return tooltip
end

do
    local patterns = {}
    for i = 1, 10 do
        patterns[aux.pluralize(format(ITEM_SPELL_CHARGES, i))] = i
    end

	function item_charges(tooltip)
        for _, entry in pairs(tooltip) do
            if patterns[entry] then
                return patterns[entry]
            end
	    end
	end
end

do
	local data = {
		-- wizard oil
		[20744] = 5,
		[20746] = 5,
		[20750] = 5,
		[20749] = 5,

		-- mana oil
		[20745] = 5,
		[20747] = 5,
		[20748] = 5,

		-- discombobulator
		[4388] = 5,

		-- recombobulator
		[4381] = 10,
		[18637] = 10,

        -- deflector
        [4376] = 5,
        [4386] = 5,

		-- ... TODO
	}
	function M.max_item_charges(item_id)
	    return data[item_id]
	end
end

function M.item_key(link)
    local item_id, suffix_id = parse_link(link)
    return item_id .. ':' .. suffix_id
end

-- item:itemID:enchantID:gem1:gem2:gem3:gem4:suffixID:uniqueID:...
function M.parse_link(link)
    local item_string = strmatch(link, 'item:([%-%d:]*)')
    if not item_string then
        return 0, 0, 0, 0, strmatch(link, '|h%[(.-)%]|h')
    end
    local fields = aux.split(item_string, ':')
    local name = strmatch(link, '|h%[(.-)%]|h')
    return tonumber(fields[1]) or 0, tonumber(fields[7]) or 0, tonumber(fields[8]) or 0, tonumber(fields[2]) or 0, name
end

-- Quality from the hyperlink color. Forever uses named item-quality colors
-- (|cnIQ2: or |cnlQ2: — seen in game on Brawler's Harness); Classic hex
-- (|cff1eff00) still appears on some paths. Prefer this over GetItemInfo when
-- the two disagree (white shirt reported as uncommon, etc.).
local LINK_QUALITY_HEX = {
    ['9d9d9d'] = 0, -- poor
    ['ffffff'] = 1, -- common
    ['1eff00'] = 2, -- uncommon
    ['0070dd'] = 3, -- rare
    ['a335ee'] = 4, -- epic
    ['ff8000'] = 5, -- legendary
}

function M.quality_from_link(link)
    if type(link) ~= 'string' then
        return
    end
    -- Forever / modern: |cnIQ2: or |cnIQ2|H... (and Forever's |cnlQ1: form).
    local named = tonumber(strmatch(link, '|cn[IiLl]Q(%d+)'))
    if named ~= nil then
        return named
    end
    local rgb = strlower(strmatch(link, '|c%x%x(%x%x%x%x%x%x)') or '')
    return LINK_QUALITY_HEX[rgb]
end

function M.item_id_from_link(link)
    if type(link) ~= 'string' then
        return
    end
    local ok, id = pcall(function()
        return tonumber(strmatch(link, 'item:(%-?%d+)'))
    end)
    if ok then
        return id
    end
end

-- Forever "of the X" auction links carry numBonusIDs + bonus ids (field 13+). Tip GetItem /
-- data.hyperlink for the same row often strip those, which zeroes GetItemStats deltas.
function M.item_link_has_bonus_ids(link)
    if type(link) ~= 'string' then
        return false
    end
    local ok, payload = pcall(function()
        return strmatch(link, 'item:(%-?%d+[:%d%-]*)')
    end)
    if not ok or not payload then
        return false
    end
    local fields = {}
    for part in string.gmatch(payload .. ':', '([^:]*):') do
        tinsert(fields, part)
    end
    -- itemId, enchant, 4 gems, suffix, unique, level, spec, modifiers, context, numBonusIDs, ...
    local num_bonus = tonumber(fields[13])
    if num_bonus and num_bonus > 0 then
        return true
    end
    local suffix = tonumber(fields[7])
    return suffix ~= nil and suffix ~= 0
end

-- Forever TooltipDataProcessor: GetItem() is often a bare item: string; data.hyperlink still has
-- |cnlQ1: / |cnIQ2:. Prefer any link that carries a quality color.
-- Do not skip secret strings: Forever often secrets the tip hyperlink; skipping left only a stale
-- last_link from a previous hover, which flipped white/green DE.
function M.prefer_quality_link(...)
    local fallback
    for i = 1, select('#', ...) do
        local link = select(i, ...)
        if type(link) == 'string' then
            local ok_item, has_item = pcall(function()
                return strfind(link, 'item:', 1, true)
            end)
            if ok_item and has_item then
                local ok_q, q = pcall(quality_from_link, link)
                if ok_q and q ~= nil then
                    return link
                end
                fallback = fallback or link
            end
        end
    end
    return fallback
end

-- Pick the link for a tip post-call.
-- - Different-item last_link is ignored (stale white/green must not poison DE).
-- - Same-item last_link with bonus IDs wins over a colored tip hyperlink that stripped them
--   (otherwise "of the X" AH tips lose +stats).
-- - Otherwise prefer a colored tip hyperlink / GetItem over last_link.
function M.tip_item_link(last_link, hyperlink, get_item_link)
    local tip_id = item_id_from_link(hyperlink) or item_id_from_link(get_item_link)
    local remembered = last_link
    if remembered and tip_id then
        local last_id = item_id_from_link(remembered)
        if last_id and last_id ~= tip_id then
            remembered = nil
        end
    end
    if remembered and item_link_has_bonus_ids(remembered)
        and not item_link_has_bonus_ids(hyperlink)
        and not item_link_has_bonus_ids(get_item_link) then
        return remembered
    end
    return prefer_quality_link(hyperlink, get_item_link, remembered)
end

-- Coerce only plain strings/numbers. Never tonumber() a Forever secret value — that yields nil and
-- wiped Disenchant % on every item.
local function as_quality(q)
    if q == nil then
        return
    end
    if issecretvalue and issecretvalue(q) then
        return q
    end
    local t = type(q)
    if t == 'number' then
        return q
    end
    if t == 'string' then
        return tonumber(q)
    end
end

-- Map the painted tip title color to a quality. Forever AH often passes a bare item: link and no
-- usable ItemName.quality in the post-call payload; the name line is still white vs green on screen.
local function quality_from_rgb(r, g, b)
    if type(r) ~= 'number' or type(g) ~= 'number' or type(b) ~= 'number' then
        return
    end
    if ITEM_QUALITY_COLORS then
        local best, best_d
        for q = 0, 5 do
            local c = ITEM_QUALITY_COLORS[q]
            if c and type(c.r) == 'number' then
                local d = abs(c.r - r) + abs(c.g - g) + abs(c.b - b)
                if not best_d or d < best_d then
                    best, best_d = q, d
                end
            end
        end
        if best_d and best_d < 0.35 then
            return best
        end
    end
    -- Fallbacks when ITEM_QUALITY_COLORS is missing or stubbed.
    if r > 0.85 and g > 0.85 and b > 0.85 then
        return 1 -- common
    end
    if abs(r - 0.62) + abs(g - 0.62) + abs(b - 0.62) < 0.35 then
        return 0 -- poor
    end
    if g > 0.7 and g >= r and g >= b and r < 0.55 then
        return 2 -- uncommon
    end
    if b > 0.55 and b > r and b > g then
        return 3 -- rare
    end
    if r > 0.45 and b > 0.55 and g < 0.45 then
        return 4 -- epic
    end
end

function M.quality_from_tooltip_title(tooltip)
    if not tooltip or (issecretvalue and issecretvalue(tooltip)) then
        return
    end
    local name = tooltip.GetName and tooltip:GetName()
    local fs = name and _G[name .. 'TextLeft1']
    if not fs or not fs.GetTextColor then
        return
    end
    local ok, r, g, b = pcall(function() return fs:GetTextColor() end)
    if not ok then
        return
    end
    return quality_from_rgb(r, g, b)
end

-- Quality for disenchant tips. Order:
-- 1) Colored link (|cnIQ / |cnlQ / hex) — Forever data.hyperlink after prefer_quality_link
-- 2) Tip data ItemName.quality
-- 3) Painted tip title color
-- 4) C_Item.GetItemQualityByID
-- 5) GetItemInfo.quality (last resort so greens still work when Forever gives no color signal)
-- Prefer_quality_link is what stops whites: bare GetItem + white hyperlink must win over (5).
function M.disenchant_quality(item_info, link, tip_quality, tooltip)
    local from_hover = quality_from_link(link)
    if from_hover ~= nil then
        return from_hover
    end
    local from_tip = as_quality(tip_quality)
    if from_tip ~= nil then
        return from_tip
    end
    local from_title = quality_from_tooltip_title(tooltip)
    if from_title ~= nil then
        return from_title
    end
    local item_id = item_info and tonumber(item_info.item_id)
        or (link and tonumber(strmatch(link, 'item:(%-?%d+)')))
    if item_id and C_Item and C_Item.GetItemQualityByID then
        local ok, q = pcall(C_Item.GetItemQualityByID, item_id)
        if ok then
            q = as_quality(q)
            if q ~= nil then
                return q
            end
        end
    end
    return item_info and item_info.quality
end

-- Forever ItemName rows carry .quality on TooltipDataProcessor callbacks.
function M.quality_from_tooltip_data(data)
    if type(data) ~= 'table' or (issecretvalue and issecretvalue(data)) then
        return
    end
    local q = as_quality(data.quality)
    if q ~= nil then
        return q
    end
    local lines = data.lines
    if type(lines) ~= 'table' then
        return
    end
    for i = 1, #lines do
        local line = lines[i]
        if type(line) == 'table' and line.quality ~= nil then
            -- Prefer ItemName (22) when the line type is present.
            if line.type == nil or line.type == 22 then
                q = as_quality(line.quality)
                if q ~= nil then
                    return q
                end
            end
        end
    end
end

function M.item(item_id, suffix_id)
    local itemstring = 'item:' .. (item_id or 0) .. '::::::' .. (suffix_id or 0)
    local name, link, quality, level, requirement, class, subclass, max_stack, slot, texture, sell_price = GetItemInfo(itemstring)
    return name and {
        item_id = item_id,
        name = name,
        link = link,
        quality = quality,
        level = level,
        requirement = requirement,
        class = class,
        subclass = subclass,
        slot = slot,
        max_stack = max_stack,
        texture = texture,
        sell_price = sell_price
    } or item_info(item_id)
end

function M.category_index(category)
    for i, v in ipairs(AuctionCategories) do
        -- ignoring trailing s because sometimes type and category differ in number
        if gsub(strupper(v.name), 'S$', '') == gsub(strupper(category), 'S$', '') then
            return i, v.name
        end
    end
end

function M.subcategory_index(category_index, subcategory)
    if category_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories or empty) do
            if strupper(v.name) == strupper(subcategory) then
                return i, v.name
            end
        end
    end
end

function M.subsubcategory_index(category_index, subcategory_index, subsubcategory)
    if category_index > 0 and subcategory_index > 0 then
        for i, v in ipairs(AuctionCategories[category_index].subCategories[subcategory_index].subCategories or empty) do
            if strupper(v.name) == strupper(subsubcategory) then
                return i, v.name
            end
        end
    end
end

function M.item_quality_index(item_quality)
    for i = 0, 4 do
        local quality = _G['ITEM_QUALITY' .. i .. '_DESC']
        if strupper(item_quality) == strupper(quality) then
            return i, quality
        end
    end
end

-- auxForever: the backpack, the four bags and Forever's reagent bag (bag 5, Enum.BagIndex.ReagentBag
-- in Blizzard's Forever code); Classic aux stopped at bag 4, so reagent bag items never showed
function M.last_bag()
	return max(4, tonumber(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or 5)
end

function M.inventory()
	local bag, slot = 0, 0
	local last = last_bag()
	return function()
		if slot >= C_Container.GetContainerNumSlots(bag) then
			repeat bag = bag + 1 until bag > last or C_Container.GetContainerNumSlots(bag) > 0
			slot = 1
		else
			slot = slot + 1
		end
		if bag <= last then return {bag, slot} end
	end
end
