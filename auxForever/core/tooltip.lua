select(2, ...) 'aux.core.tooltip'

local aux = require 'aux'
local info = require 'aux.util.info'
local money =  require 'aux.util.money'
local disenchant = require 'aux.core.disenchant'
local history = require 'aux.core.history'
local gui = require 'aux.gui'

local UNKNOWN = GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE

-- Forever: GameTooltip:GetItem() and SetItemKey often drop the random-suffix bonus IDs that
-- C_AuctionHouse item links carry, so the built-in tooltip shows the base item with no +stats.
-- Full auction links still work with GetItemStats; we note those links from AH hover code,
-- remember them by item key after an item search, and re-add missing +stat lines.

local last_link = {}
local last_hover = {}
local retry_tip, retry_link, retry_frames = nil, nil, 0
local inject_announced
local cached_suffix_lines = {}

local function item_string(link)
    return type(link) == 'string' and (strmatch(link, 'item:[%-:%d]+') or link)
end

-- Must be declared before note_hover / cache_suffix_stats (Lua locals are nil above their line).
local function nonempty_stat_lines(lines)
    return lines and #lines > 0 and lines or nil
end

local function prefetch_link(link)
    local item_id = tonumber(strmatch(link or '', 'item:(%-?%d+)'))
    if item_id and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(item_id)
    end
end

function M.note_link(tooltip, link)
    if tooltip and type(link) == 'string' and strfind(link, 'item:', 1, true)
        and not (issecretvalue and issecretvalue(link)) then
        last_link[tooltip] = link
        last_hover.link = link
        prefetch_link(link)
    end
end

-- AuxSuffixFix lesson: TooltipDataProcessor runs inside SetHyperlink, so the full auction
-- link must be stashed before that call. note_link alone is not enough if something else
-- invokes SetHyperlink without going through ShowRecordTooltip.
local function wrap_sethyperlink(tooltip)
    if not tooltip or tooltip.AuxForever_SetHyperlinkWrapped then
        return
    end
    local orig = tooltip.SetHyperlink
    if type(orig) ~= 'function' then
        return
    end
    tooltip.SetHyperlink = function(self, link, ...)
        note_link(self, link)
        return orig(self, link, ...)
    end
    tooltip.AuxForever_SetHyperlinkWrapped = true
end

function M.note_hover(record, link)
    last_hover.record = record
    if type(link) == 'string' then
        last_hover.link = link
    elseif record and type(record.link) == 'string' then
        last_hover.link = record.link
    end
    -- Prefetch only; never compute stats here (errors on hover blanked the buy bar).
    if last_hover.link then
        pcall(prefetch_link, last_hover.link)
    end
end

-- Always fill a fresh table. A shared GetItemStats return value keeps leftover keys from the
-- previous item, which made "full link vs base" deltas all zero.
-- Forever: prefer C_Item.GetItemStats(link) with no dest table (AuxSuffixFix). The global
-- GetItemStats often exists but returns an empty table, which previously masked C_Item.
local function copy_stats(link)
    link = item_string(link)
    if not link then
        return
    end
    local function take(src)
        if type(src) ~= 'table' then
            return
        end
        local copy = {}
        for k, v in pairs(src) do
            -- Forever may hand out secret numbers; keep values that compare as numbers.
            if type(v) == 'number' or (issecretvalue and issecretvalue(v)) then
                copy[k] = v
            end
        end
        return next(copy) and copy or nil
    end
    if C_Item and C_Item.GetItemStats then
        local ok, result = pcall(C_Item.GetItemStats, link)
        local copy = ok and take(result)
        if copy then
            return copy
        end
        local dest = {}
        ok, result = pcall(C_Item.GetItemStats, link, dest)
        copy = ok and (take(result) or take(dest))
        if copy then
            return copy
        end
    end
    if GetItemStats then
        local dest = {}
        local ok, result = pcall(GetItemStats, link, dest)
        local copy = ok and (take(result) or take(dest))
        if copy then
            return copy
        end
    end
end

local function stat_label(key)
    if type(key) ~= 'string' then
        return
    end
    local label = _G[key]
    if type(label) == 'string' and label ~= '' then
        return label
    end
    local short = strmatch(key, '^ITEM_MOD_(.+)_SHORT$') or strmatch(key, '^ITEM_MOD_(.+)$')
    if short then
        return gsub(strlower(short), '_', ' ')
    end
end

local function tooltip_has_label(tooltip, label)
    local name = tooltip:GetName()
    for i = 1, tooltip:NumLines() do
        local fs = _G[name .. 'TextLeft' .. i]
        local text = fs and fs:GetText()
        if type(text) == 'string' and strfind(text, label, 1, true) then
            return true
        end
    end
    return false
end

-- Equip-stat lines missing from the tooltip. Prefer bonus-vs-base deltas; if that yields nothing
-- (shared-table quirks, base equal), fall back to every ITEM_MOD_* on the link not already shown.
function M.suffix_stat_lines(link)
    link = item_string(link)
    if not link then
        return
    end
    local item_id = tonumber(strmatch(link, 'item:(%-?%d+)'))
    if not item_id then
        return
    end
    local with = copy_stats(link)
    if not with then
        return
    end
    local base = copy_stats('item:' .. item_id) or {}
    local lines, seen = {}, {}
    local function add(label, amount)
        if not label or seen[label] or amount == nil then
            return
        end
        local ok, positive = pcall(function() return amount > 0 end)
        if ok and positive then
            seen[label] = true
            tinsert(lines, { label = label, amount = amount })
        end
    end
    for k, v in pairs(with) do
        -- DPS / armor are base weapon/armor fields, not random-suffix bonuses.
        if k ~= 'RESISTANCE0_NAME' and k ~= 'DAMAGE_PER_SECOND' then
            local label = stat_label(k)
            local base_v = base[k] or 0
            local ok, delta = pcall(function() return v - base_v end)
            if ok then
                add(label, delta)
            end
        end
    end
    if #lines == 0 then
        for k, v in pairs(with) do
            if type(k) == 'string' and strfind(k, 'ITEM_MOD_', 1, true) then
                add(stat_label(k), v)
            end
        end
    end
    return nonempty_stat_lines(lines)
end

-- Drop weapon DPS (and any pre-poisoned DPS labels) from injectable +stat lines.
local function filter_suffix_lines(lines)
    if not lines or #lines == 0 then
        return
    end
    local dps_label = _G.DAMAGE_PER_SECOND
    local out = {}
    for _, entry in ipairs(lines) do
        local label = entry and entry.label
        if label and label ~= 'DAMAGE_PER_SECOND' and not (dps_label and label == dps_label) then
            tinsert(out, entry)
        end
    end
    return nonempty_stat_lines(out)
end

local function same_item_id(a, b)
    local id_a = info.item_id_from_link(a) or (type(a) == 'number' and a)
    local id_b = info.item_id_from_link(b) or (type(b) == 'number' and b)
    return id_a and id_b and id_a == id_b
end

-- Precomputed +stat lines by item string, filled when search results arrive (not on hover).
function M.cache_suffix_stats(link)
    link = item_string(link)
    if not link then
        return
    end
    -- Inside this module call the env name, not M.suffix_stat_lines: M has no __index.
    local lines = filter_suffix_lines(suffix_stat_lines(link))
    if lines then
        cached_suffix_lines[link] = lines
    end
    return lines
end

local suffix_retry = CreateFrame('Frame')
suffix_retry:Hide()
suffix_retry:SetScript('OnUpdate', function(self)
    -- Forever: a late GameTooltip:Show() rebuilds the tip and drops aux AddLines (DE / value /
    -- vendor). AddLine on an already-open tip is enough; never Show() from this retry.
    if retry_tip and retry_tip:IsShown() and retry_link then
        local tip_link = last_link[retry_tip]
        -- Tip moved to another item while frames were pending — do not paint prior +stats.
        if not tip_link or not same_item_id(tip_link, retry_link) then
            retry_frames = 0
            self:Hide()
            return
        end
        local ok, added = pcall(add_suffix_stats, retry_tip, retry_link)
        if ok and added then
            retry_frames = 0
        end
    end
    retry_frames = retry_frames - 1
    if retry_frames <= 0 then
        self:Hide()
    end
end)

-- Returns true when at least one line was added. Does not Show(): callers must Show, because a
-- mid-extend Show() on Forever can drop later AddLines (disenchant / value).
function M.add_suffix_stats(tooltip, link)
    link = item_string(link or last_link[tooltip])
    if not tooltip or not link or (tooltip.IsForbidden and tooltip:IsForbidden()) then
        return false
    end
    if tooltip:NumLines() < 1 then
        return false
    end
    local tip_id = info.item_id_from_link(link)
    -- Empty tables from an early (failed) cache must not block a later GetItemStats retry.
    -- last_hover.record.suffix_stats is only for the same item_id — never the next tip.
    local lines = filter_suffix_lines(cached_suffix_lines[link])
    if not lines then
        local record = last_hover.record
        local record_id = record and (record.item_id or info.item_id_from_link(record.link))
        if record and tip_id and record_id and tip_id == record_id then
            lines = filter_suffix_lines(record.suffix_stats)
        end
    end
    lines = lines or filter_suffix_lines(suffix_stat_lines(link))
    if lines then
        cached_suffix_lines[link] = lines
        local record = last_hover.record
        local record_id = record and (record.item_id or info.item_id_from_link(record.link))
        if record and tip_id and record_id and tip_id == record_id then
            record.suffix_stats = lines
        end
    else
        return false
    end
    local added = false
    for _, entry in ipairs(lines) do
        if not tooltip_has_label(tooltip, entry.label) then
            tooltip:AddLine(format('+%d %s', entry.amount, entry.label), 0, 1, 0)
            added = true
        end
    end
    if added and not inject_announced then
        inject_announced = true
        aux.print('Suffix stats: added +stat lines to the tooltip (this message once).')
    end
    return added
end

-- Forever ItemKey.itemSuffix is often usable as a bonus id when no auction itemLink was
-- remembered yet (Fast parent before the item is opened). Try bonus-ID form, then classic
-- random-suffix field 7. Only return a candidate that GetItemStats can turn into +stat lines.
function M.synthetic_suffix_link(item_id, item_suffix)
    if not item_id or not item_suffix or item_suffix == 0 then
        return
    end
    local candidates = {
        format('item:%d::::::::::::1:%d', item_id, item_suffix),
        format('item:%d::::::%d', item_id, item_suffix),
    }
    for _, candidate in ipairs(candidates) do
        if nonempty_stat_lines(suffix_stat_lines(candidate)) then
            return candidate
        end
    end
end

function M.link_for_item_key(item_key)
    if type(item_key) ~= 'table' or not item_key.itemID then
        return
    end
    local suffix = item_key.itemSuffix or 0
    if suffix == 0 then
        return
    end
    local remembered = info.suffix_link_for(item_key.itemID, suffix)
    if remembered then
        return remembered
    end
    local synthetic = synthetic_suffix_link(item_key.itemID, suffix)
    if synthetic then
        info.remember_suffix_link(item_key.itemID, suffix, synthetic)
        return synthetic
    end
end

function M.schedule_suffix_stats(tooltip, link)
    if not tooltip then
        return
    end
    -- Never downgrade a bonus/retry link to a stripped tip link (Show() re-entry post-call).
    local previous = retry_link or last_link[tooltip]
    if link and previous and info.item_link_has_bonus_ids(previous)
        and not info.item_link_has_bonus_ids(link)
        and info.item_id_from_link(previous) == info.item_id_from_link(link) then
        link = previous
    end
    if link then
        -- Call the env binding, not M.note_link: M has no __index, so reads on M are nil.
        note_link(tooltip, link)
    end
    retry_tip = tooltip
    retry_link = link or last_link[tooltip]
    retry_frames = 8
    suffix_retry:Show()
end

-- /aux suffix: dump the last hovered AH link and whether GetItemStats sees bonus stats
function M.suffix_report()
    local link = last_hover.link or last_link[GameTooltip]
    local lines_out = {}
    if not link then
        tinsert(lines_out, 'No AH item hovered yet. Hover an auction icon, then run /aux suffix.')
        return lines_out
    end
    tinsert(lines_out, 'link=' .. gsub(link, '|', '||'))
    local stats = copy_stats(link)
    if not stats then
        tinsert(lines_out, 'GetItemStats: nil (link not usable)')
    else
        local parts = {}
        for k, v in pairs(stats) do
            tinsert(parts, format('%s=%s', tostring(stat_label(k) or k), tostring(v)))
        end
        sort(parts)
        tinsert(lines_out, 'GetItemStats: ' .. (#parts > 0 and table.concat(parts, ', ') or '(empty)'))
    end
    local bonus = suffix_stat_lines(link)
    if not bonus or #bonus == 0 then
        tinsert(lines_out, 'bonus lines: none (no ITEM_MOD delta vs base)')
    else
        local parts = {}
        for _, e in ipairs(bonus) do
            tinsert(parts, format('+%d %s', e.amount, e.label))
        end
        tinsert(lines_out, 'bonus lines: ' .. table.concat(parts, ', '))
    end
    if GameTooltip:IsShown() then
        local added = add_suffix_stats(GameTooltip, link)
        tinsert(lines_out, added and 're-injected into the open tooltip' or 'open tooltip unchanged (already shown or nothing to add)')
    end
    return lines_out
end

local function tip_has(fragment)
    if not GameTooltip:IsShown() then
        return false
    end
    for i = 1, GameTooltip:NumLines() do
        local font = _G['GameTooltipTextLeft' .. i]
        local text = font and font:GetText()
        if text and strfind(text, fragment, 1, true) then
            return true
        end
    end
    return false
end

-- /aux smoke: tooltip switches and whether DE / value / vendor lines are on the open tip
function M.smoke_report()
    local s = settings or aux.character_data.tooltip
    local lines_out = {}
    local function on_off(v)
        return v and 'on' or 'off'
    end
    tinsert(lines_out, format(
        'switches: value=%s daily=%s vendor_sell=%s vendor_buy=%s de_value=%s de_into=%s',
        on_off(s.value), on_off(s.daily), on_off(s.merchant_sell), on_off(s.merchant_buy),
        on_off(s.disenchant_value), on_off(s.disenchant_distribution)
    ))
    local link = last_hover.link or last_link[GameTooltip]
    if not link then
        local _, tip_link = GameTooltip:GetItem()
        link = tip_link
    end
    if not link then
        tinsert(lines_out, 'No item tip open. Hover green gear, then /aux smoke.')
        return lines_out
    end
    tinsert(lines_out, 'link=' .. gsub(link, '|', '||'))
    local item_id = info.parse_link(link)
    local item_info = info.item(item_id)
    if not item_info then
        tinsert(lines_out, 'GetItemInfo: not ready for this item')
        return lines_out
    end
    local quality = info.disenchant_quality(item_info, link, nil, GameTooltip)
    tinsert(lines_out, format(
        'item: quality=%s (info=%s hover=%s title=%s) slot=%s level=%s',
        tostring(quality), tostring(item_info.quality), tostring(info.quality_from_link(link)),
        tostring(info.quality_from_tooltip_title(GameTooltip)),
        tostring(item_info.slot), tostring(item_info.level)
    ))
    local dist = disenchant.distribution(item_info.slot, quality, item_info.level)
    tinsert(lines_out, format('de table: %d outcomes', #dist))
    tinsert(lines_out, format(
        'open tip: Disenchants into=%s Disenchant:=%s Vendor:=%s Value:=%s',
        tip_has('Disenchants into:') and 'yes' or 'no',
        tip_has('Disenchant:') and 'yes' or 'no',
        tip_has('Vendor:') and 'yes' or 'no',
        tip_has('Value:') and 'yes' or 'no'
    ))
    local de_ok = quality == 2 or quality == 3 or quality == 4
    if tip_has('Disenchant') and not de_ok then
        tinsert(lines_out, 'FAIL: DE must not show on white/gray (or unreadable quality).')
    end
    if de_ok and #dist > 0 and not tip_has('Disenchant')
        and (s.disenchant_distribution or s.disenchant_value) then
        tinsert(lines_out, 'FAIL: DE should show on this green+ tip.')
    end
    if s.merchant_sell and (item_info.sell_price or 0) ~= 0 and not tip_has('Vendor:') then
        tinsert(lines_out, 'FAIL: Vendor should show on this tip.')
    end
    if s.value and is_auctionable(item_id, item_info) and not tip_has('Value:') then
        tinsert(lines_out, 'FAIL: Value should show on this tip.')
    end
    return lines_out
end

-- Forever: item tooltips are built through TooltipDataProcessor, so one post-call replaces the
-- per-method GameTooltip hooks of Classic aux. The quantity (used when Shift is held) is read from
-- the call that filled the tooltip, where the item's stack size is known.
local quantity_getters = {
    GetBagItem = function(bag, slot)
        local item = C_Container.GetContainerItemInfo(bag, slot)
        return item and item.stackCount
    end,
    GetInventoryItem = function(unit, slot)
        return GetInventoryItemCount(unit, slot)
    end,
    GetLootItem = function(slot)
        return select(3, GetLootSlotInfo(slot))
    end,
    GetMerchantItem = function(slot)
        return select(4, GetMerchantItemInfo(slot))
    end,
    GetBuybackItem = function(slot)
        return select(4, GetBuybackItemInfo(slot))
    end,
}

local function tooltip_quantity(tooltip)
    local processing_info = tooltip.processingInfo
    local getter = processing_info and quantity_getters[processing_info.getterName]
    if getter and processing_info.getterArgs then
        local ok, quantity = pcall(getter, unpack(processing_info.getterArgs, 1, processing_info.getterArgs.n or #processing_info.getterArgs))
        if ok and type(quantity) == 'number' and quantity > 0 then
            return quantity
        end
    end
    return 1
end

function aux.event.AUX_LOADED()
    settings = aux.character_data.tooltip
    wrap_sethyperlink(GameTooltip)
    wrap_sethyperlink(ItemRefTooltip)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
            return
        end
        if tooltip.IsForbidden and tooltip:IsForbidden() then
            return
        end
        local _, get_item_link = tooltip:GetItem()
        -- Forever: GetItem() is often bare item:…; data.hyperlink still has |cnlQ1: / |cnIQ2:.
        -- Never prefer last_link over this tip — a prior white/green hover poisoned DE.
        local link = info.tip_item_link(
            last_link[tooltip],
            data and data.hyperlink,
            get_item_link
        )
        if type(link) ~= 'string' then
            return
        end
        local ok_item, has_item = pcall(function() return strfind(link, 'item:', 1, true) end)
        if not ok_item or not has_item then
            return
        end
        -- Keep suffix memory on the current tip item only. Do not replace a same-item bonus
        -- auction link with a stripped Forever tip hyperlink (wipes of-the-X +stats).
        local previous = last_link[tooltip]
        if not (previous and info.item_link_has_bonus_ids(previous)
            and not info.item_link_has_bonus_ids(link)
            and info.item_id_from_link(previous) == info.item_id_from_link(link)) then
            last_link[tooltip] = link
            last_hover.link = link
        else
            link = previous
        end
        local tip_quality
        pcall(function() tip_quality = info.quality_from_tooltip_data(data) end)
        extend_tooltip(tooltip, link, tooltip_quantity(tooltip), tip_quality)
        pcall(schedule_suffix_stats, tooltip, link)
    end)
    aux.event_listener('GET_ITEM_INFO_RECEIVED', function(item_id, success)
        if not success then
            return
        end
        local link = retry_link or last_hover.link
        local link_id = link and tonumber(strmatch(link, 'item:(%-?%d+)'))
        if link_id and link_id == item_id then
            cache_suffix_stats(link)
            -- Same as the retry frame: AddLine only. Show() here wiped DE/value on Forever.
            -- Only inject when the open tip is still this item.
            if retry_tip and retry_tip:IsShown() then
                local tip_link = last_link[retry_tip]
                if tip_link and same_item_id(tip_link, link) then
                    pcall(add_suffix_stats, retry_tip, link)
                end
            end
        end
    end)
end

-- auxForever: whether an item can be auctioned is read from a hidden tooltip of the item, which
-- the game has to build. aux did that on every hover of every item, anywhere in the game; the
-- answer never changes for an item, so it is kept (one entry per item hovered).
local auctionable_cache = {}

function M.is_auctionable(item_id, item_info)
    local known = auctionable_cache[item_id]
    if known == nil then
        known = info.auctionable(info.tooltip('link', item_info.link), item_info.quality) and true or false
        auctionable_cache[item_id] = known
    end
    return known
end

-- auxForever (0.5): how fresh the usual price is, after Value: "  seen 3 days ago", gray, darker when
-- the newest price is a week old or more
function M.age_suffix(age)
    local text = history.age_text(age)
    if not text then
        return ''
    end
    local color = age >= history.OLD_DAYS and aux.color.label.disabled or aux.color.label.enabled
    return '  ' .. color('seen ' .. text)
end

function extend_tooltip(tooltip, link, quantity, tip_quality)
    local item_id, suffix_id = info.parse_link(link)
    quantity = IsShiftKeyDown() and quantity or 1
    -- auxForever (0.5): with Shift held the prices are for the whole stack; say so ("for 3"). In build
    -- 1 a stack's Value read as a far too high price per item (Windows' screenshot keys hold Shift).
    local per = quantity > 1 and ('  ' .. aux.color.label.enabled('for ' .. quantity)) or ''
    local item_info = info.item(item_id)
    -- auxForever: the disenchant table is only worked out when one of its lines is shown.
    -- Skip white/gray (and shirts). tip_quality is Forever's ItemName.quality when the hover link
    -- is a bare item: string with no |cnIQ color.
    local quality = item_info and info.disenchant_quality(item_info, link, tip_quality, tooltip)
    -- Compare with explicit uncommon/rare/epic — (quality or 0) >= 2 can fail on Forever secrets.
    local de_quality = quality == 2 or quality == 3 or quality == 4
    if item_info and (settings.disenchant_distribution or settings.disenchant_value)
        and de_quality then
        local distribution = disenchant.distribution(item_info.slot, quality, item_info.level)
        if #distribution > 0 then
            if settings.disenchant_distribution then
                tooltip:AddLine('Disenchants into:', aux.color.tooltip.disenchant.distribution())
                sort(distribution, function(a,b) return a.probability > b.probability end)
                for _, event in ipairs(distribution) do
                    tooltip:AddLine(format('  %s%% %s (%s-%s)', event.probability * 100, info.display_name(event.item_id, true) or 'item:' .. event.item_id, event.min_quantity, event.max_quantity), aux.color.tooltip.disenchant.distribution())
                end
            end
            if settings.disenchant_value then
                local disenchant_value = disenchant.value(item_info.slot, quality, item_info.level)
                if settings.money_icons then
                    tooltip:AddLine('Disenchant: ' .. (disenchant_value and GetCoinTextureString(disenchant_value) or UNKNOWN), aux.color.tooltip.disenchant.value())
                else
                    tooltip:AddLine('Disenchant: ' .. (disenchant_value and money.to_string2(disenchant_value) or UNKNOWN), aux.color.tooltip.disenchant.value())
                end
            end
        end
    end
    if settings.merchant_buy then
        local price, limited = info.merchant_buy_info(item_id)
        if price then
            if settings.money_icons then
                tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. GetCoinTextureString(price * quantity) .. per, aux.color.tooltip.merchant())
            else
                tooltip:AddLine('Vendor Buy ' .. (limited and '(limited): ' or ': ') .. money.to_string2(price * quantity) .. per, aux.color.tooltip.merchant())
            end
        end
    end
    if settings.merchant_sell then
        local price = item_info and item_info.sell_price
        if price ~= 0 then
            if settings.money_icons then
                tooltip:AddLine('Vendor: ' .. (price and GetCoinTextureString(price * quantity) .. per or UNKNOWN), aux.color.tooltip.merchant())
            else
                tooltip:AddLine('Vendor: ' .. (price and money.to_string2(price * quantity) .. per or UNKNOWN), aux.color.tooltip.merchant())
            end
        end
    end
    local auctionable = not item_info or is_auctionable(item_id, item_info)
    local item_key = (item_id or 0) .. ':' .. (suffix_id or 0)
    -- auxForever (0.5, build 3): Value is the latest look at the item (what players just saw at the
    -- auction house); the multi-day usual price shows under it only when the two differ a lot
    local latest, age = history.latest(item_key)
    local value = history.value(item_key)
    if auctionable then
        if settings.value then
            local function coins(amount)
                return settings.money_icons and GetCoinTextureString(amount) or money.to_string2(amount)
            end
            tooltip:AddLine('Value: ' .. (latest and coins(latest * quantity) .. per .. age_suffix(age) or UNKNOWN), aux.color.tooltip.value())
            if history.usually_differs(latest, value) then
                tooltip:AddLine('  ' .. aux.color.label.enabled('usually ') .. coins(value * quantity), aux.color.label.enabled())
            end
        end
        if settings.daily  then
            local market_value = history.market_value(item_key)
            if settings.money_icons then
                tooltip:AddLine('Today: ' .. (market_value and GetCoinTextureString(market_value * quantity) .. per .. ' (' .. gui.percentage_historical(aux.round(market_value / value * 100)) .. ')' or UNKNOWN))
            else
                tooltip:AddLine('Today: ' .. (market_value and money.to_string2(market_value * quantity) .. per .. ' (' .. gui.percentage_historical(aux.round(market_value / value * 100)) .. ')' or UNKNOWN), aux.color.tooltip.value())
            end
        end
    end

--    if tooltip == GameTooltip and game_tooltip_money > 0 then
--        SetTooltipMoney(tooltip, game_tooltip_money)
--    end
    -- Forever: suffix +stats after Value/DE so a failed GetItemStats cannot skip those lines.
    -- Show only when the tip is not already open: a second Show() on Forever rebuilds the tip
    -- and drops these AddLines (DE / value / vendor).
    pcall(add_suffix_stats, tooltip, link)
    if not tooltip:IsShown() then
        tooltip:Show()
    end
end

-- auxForever: /aux memory detail
function M.memory_counts()
    local n = 0
    for _ in pairs(auctionable_cache) do n = n + 1 end
    return n
end
