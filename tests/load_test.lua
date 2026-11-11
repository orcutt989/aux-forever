-- Run from the auxForever folder: lua5.1 ../tests/load_test.lua
-- Fast tooltip loop:            lua5.1 ../tests/load_test.lua smoke
-- Local basics contract:        lua5.1 ../tests/load_test.lua basics
-- Classic look (full suite):    lua5.1 ../tests/load_test.lua classic
-- Load test: stub the WoW API, load every file in TOC order, then fire the startup events
-- (ADDON_LOADED, PLAYER_LOGIN), open the auction house, run OnUpdate scripts a few times and
-- walk through a commodity purchase.
-- Exits with status 1 when any check failed (so local scripts and CI can stop on red).
local G = _G
local frames = {}
local NUMERIC = { GetRight=1, GetLeft=1, GetTop=1, GetBottom=1, GetWidth=1, GetHeight=1, GetNumber=1, GetScale=1, GetEffectiveScale=1, GetAlpha=1, GetID=1, GetNumPoints=1, GetVerticalScroll=1, GetHorizontalScroll=1, GetCursorPosition=1, GetStringWidth=1, GetTextWidth=1, GetFrameLevel=1, GetValue=1, GetEffectiveAlpha=1, GetStringHeight=1 }

local MODE = arg and arg[1]
local SMOKE_ONLY = (MODE == 'smoke')
local BASICS_ONLY = (MODE == 'basics')
local DE_ONLY = (MODE == 'de')
local SUFFIX_LEAK_ONLY = (MODE == 'suffix-leak')
local EARLY_EXIT = SMOKE_ONLY or BASICS_ONLY or DE_ONLY or SUFFIX_LEAK_ONLY
local NUMERIC = { GetRight=1, GetLeft=1, GetTop=1, GetBottom=1, GetWidth=1, GetHeight=1, GetNumber=1, GetScale=1, GetEffectiveScale=1, GetAlpha=1, GetID=1, GetNumPoints=1, GetVerticalScroll=1, GetHorizontalScroll=1, GetCursorPosition=1, GetStringWidth=1, GetTextWidth=1, GetFrameLevel=1, GetValue=1 }
local function new_frame(name)
  local f = { __scripts = {}, __events = {}, __name = name, __shown = true, __text = '' }
  return setmetatable(f, { __index = function(t, k)
    if type(k) ~= 'string' or not k:match('^%u') then return nil end
    if k == 'GetName' then return function() return t.__name or 'Stub' end end
    -- frames made with CreateFrame know their parent, children and type, as in the game (the
    -- gamepad navigator walks them); other stubs keep answering with a fresh stub
    if k == 'GetParent' and t.__tracked then return function(self) return self.__parent end end
    if k == 'GetChildren' then return function(self) return unpack(self.__children or {}) end end
    if k == 'IsObjectType' then return function(self, kind)
      local own = self.__type
      return own == kind or (kind == 'Button' and own == 'CheckButton') or (kind == 'Frame' and own ~= nil)
    end end
    if k == 'GetObjectType' then return function(self) return self.__type end end
    if k == 'GetCenter' then return function() return 10, 10 end end
    if k == 'SetFrameStrata' then return function(self, strata) self.__strata = strata end end
    if k == 'GetFrameStrata' then return function(self) return self.__strata or 'MEDIUM' end end
    if k == 'SetScript' then return function(self, s, fn) self.__scripts[s] = fn end end
    if k == 'GetScript' then return function(self, s) return self.__scripts[s] end end
    -- like the game: a hook runs after the script already there
    if k == 'HookScript' then return function(self, s, fn)
      local before = self.__scripts[s]
      self.__scripts[s] = before and function(...) before(...); return fn(...) end or fn
    end end
    if k == 'RegisterEvent' then return function(self, e) self.__events[e] = true end end
    if k == 'UnregisterEvent' then return function(self, e) self.__events[e] = nil end end
    if k == 'Show' then return function(self) self.__shown = true; if self.__scripts.OnShow then self.__scripts.OnShow(self) end end end
    if k == 'Hide' then return function(self) self.__shown = false; if self.__scripts.OnHide then self.__scripts.OnHide(self) end end end
    if k == 'IsShown' or k == 'IsVisible' then return function(self) return self.__shown end end
    if k == 'SetText' then return function(self, x) self.__text = x end end
    if k == 'GetText' then return function(self) return self.__text end end
    -- like the game: SetFont needs a font file and a height above 0
    if k == 'SetFont' then return function(self, a, b, c, d)
      local path, height = a, b
      if a == 'p' or a == 'h1' or a == 'h2' or a == 'h3' then path, height = b, c end -- SimpleHTML
      if type(path) ~= 'string' then error("bad argument #1 to 'SetFont'", 2) end
      if not height or height <= 0 then error('Invalid font height', 2) end
      self.__font, self.__height = path, height
      return true
    end end
    if k == 'SetFontObject' then return function(self) self.__font, self.__height = [[Fonts\ARIALN.TTF]], 14 end end
    if k == 'GetFont' then return function(self)
      if self.__height then return self.__font, self.__height, '' end
      return 'font', 12, ''
    end end
    -- colors are kept so a test can read them back (0.6: the Classic look repaints)
    if k == 'SetTextColor' then return function(self, ...) self.__text_color = {...} end end
    if k == 'SetColorTexture' then return function(self, ...) self.__texture_color = {...} end end
    if k == 'SetVertexColor' then return function(self, ...) self.__vertex_color = {...} end end
    if k == 'IsEnabled' then return function() return true end end
    if k == 'GetChecked' or k == 'IsMouseOver' or k == 'HasFocus' or k == 'IsForbidden' then return function() return false end end
    if NUMERIC[k] then return function()
      if G.__geometry and (k == 'GetHeight' or k == 'GetWidth') then return G.__geometry.size end
      if G.__geometry and (k == 'GetRight' or k == 'GetLeft' or k == 'GetTop' or k == 'GetBottom') then return G.__geometry.edge end
      return 10
    end end
    if k:match('^Get') or k:match('^Create') then return function() return new_frame() end end
    return function() end
  end })
end
G.CreateFrame = function(kind, name, parent)
  local f = new_frame(name)
  f.__type, f.__tracked, f.__parent = kind, true, parent
  if type(parent) == 'table' then
    rawset(parent, '__children', rawget(parent, '__children') or {})
    tinsert(parent.__children, f)
  end
  tinsert(frames, f); if name then G[name] = f end return f
end
for _, n in ipairs{'UIParent','GameTooltip','ItemRefTooltip','DEFAULT_CHAT_FRAME','UIErrorsFrame','AuctionHouseFrame'} do G[n] = new_frame(n) end
G.UIParent.__tracked = true -- the top of the frame tree: no parent
G.UISpecialFrames = {}; G.StaticPopupDialogs = {}; G.SlashCmdList = {}; G.SOUNDKIT = {}
local api = function(t) return setmetatable(t or {}, {__index=function() return function() return 0 end end}) end
G.C_AuctionHouse = api{GetTimeLeftBandInfo=function(b) return 0, ({1800,7200,43200,86400})[b+1] end, IsThrottledMessageSystemReady=function() return true end, SupportsCopperValues=function() return true end, GetBrowseResults=function() return {} end}
G.Enum = setmetatable({}, {__index=function(t,k) local e = setmetatable({}, {__index=function() return 1 end}); rawset(t,k,e); return e end})
for _, n in ipairs{'C_Item','C_Container','C_CurrencyInfo','C_Sound','C_AddOns','C_MerchantFrame','C_PlayerInfo','TooltipDataProcessor','ItemLocation','ChatFrameUtil'} do G[n] = api() end
G.C_Container.GetContainerNumSlots = function() return 0 end
G.C_Item.GetItemQualityColor = function() return 1, 1, 1, 'ffffffff' end -- r, g, b and the color code, as in the game
G.ITEM_QUALITY_COLORS = setmetatable({}, {__index=function() return {r=1,g=1,b=1} end})
-- Forever's real category tree (Weapons, One-Handed, Daggers, ...), made from Blizzard's code by
-- tests/tools/make_forever_categories.lua. An empty list here hid FB-010 (slots under weapons).
G.AuctionCategories = dofile((arg and arg[0] or ''):gsub('[^/\\]*$', '') .. 'forever_categories.lua')
G.GetRealmName = function() return 'R' end; G.UnitName = function() return 'P' end; G.UnitFactionGroup = function() return 'Horde' end; G.UnitGUID = function() return 'g' end; G.UnitLevel = function() return 60 end
G.GetMoney = function() return 100000 end; G.GetItemInfo = function() end
local clock = 0; G.GetTime = function() return clock end; G.time = os.time; G.date = os.date
G.strmatch = string.match; G.strfind = string.find; G.strsub = string.sub; G.strlower = string.lower; G.strupper=string.upper; G.strlen=string.len; G.format=string.format; G.gsub=string.gsub; G.tinsert=table.insert; G.tremove=table.remove; G.sort=table.sort; G.floor=math.floor; G.ceil=math.ceil; G.max=math.max; G.min=math.min; G.abs=math.abs; G.mod=math.fmod; G.sin=math.sin
G.hooksecurefunc = function() end; G.FauxScrollFrame_Update = function() end; G.FauxScrollFrame_GetOffset = function() return 0 end; G.FauxScrollFrame_SetOffset=function() end; G.FauxScrollFrame_OnVerticalScroll=function() end
G.IsShiftKeyDown = function() return false end; G.IsAltKeyDown = G.IsShiftKeyDown; G.IsControlKeyDown = G.IsShiftKeyDown
G.PlaySound = function() end; G.ClearCursor = function() end; G.StaticPopup_Show = function() end; G.StaticPopup_Hide = function() end
for _, s in ipairs{'LIGHTYELLOW_FONT_COLOR_CODE','FONT_COLOR_CODE_CLOSE','GRAY_FONT_COLOR_CODE','HOURS','ITEM_SPELL_CHARGES'} do G[s] = s end
for i, q in ipairs{'Poor', 'Common', 'Uncommon', 'Rare', 'Epic'} do G['ITEM_QUALITY' .. (i - 1) .. '_DESC'] = q end
-- Without these, info.auctionable sees nil ~= nil and treats every empty tip as not auctionable,
-- so Value lines never appear in early/basics tests.
for _, s in ipairs{'ITEM_BIND_ON_PICKUP', 'ITEM_BIND_QUEST', 'ITEM_SOULBOUND', 'ITEM_CONJURED', 'ITEM_MIN_LEVEL'} do G[s] = s end
G.ITEM_SPELL_CHARGES = '%d Charges'; G.AUCTION_DURATION_ONE = '2 Hours'; G.AUCTION_DURATION_TWO = '8 Hours'; G.AUCTION_DURATION_THREE = '24 Hours'
setmetatable(G, {__index=function(_, k) if type(k)=='string' and (k:match('Button$') or k:match('ScrollBar$') or k:match('Text$') or k:match('Icon$') or k:match('Count$') or k:match('Text[LR]%a+%d+$')) then return new_frame(k) end end})

local errors = 0
local function try(label, f, ...)
  if EARLY_EXIT and type(label) == 'string' then
    local allow = label:match('^load ')
      or label:match('^smoke:')
      or label:match('^basics:')
      or label:match('^de%-tip:')
      or label:match('^suffix%-leak:')
      or label == 'ADDON_LOADED'
      or label == 'PLAYER_LOGIN'
      or label == 'AUCTION_HOUSE_SHOW'
      or label == 'OnUpdate'
    if not allow then
      return
    end
  end
  local ok, err = pcall(f, ...)
  if not ok then errors = errors + 1; print('ERROR', label, err) end
end
local function finish()
  print('done, errors: ' .. errors)
  if errors > 0 then
    os.exit(1)
  end
end
local addon = {}
for line in io.lines('auxForever.toc') do
  if not line:match('^##') and line:match('%S') then
    local file = line:gsub('\\','/'):gsub('%s+$','')
    try('load ' .. file, assert(loadfile(file)), 'auxForever', addon)
  end
end
local function fire(event, ...)
  for _, f in ipairs(frames) do
    if f.__events[event] and f.__scripts.OnEvent then try(event, f.__scripts.OnEvent, f, event, ...) end
  end
end
-- `lua5.1 ../tests/load_test.lua classic` runs everything again in the Classic look: the saved
-- settings ask for it, as they would after a player picked Classic (they load after the files)
THEME = (MODE == 'classic') and 'classic' or 'new'
if THEME == 'classic' then G.aux = {account = {theme = 'classic'}} end
-- a value the test expects, by look
local function pick(new, classic) if THEME == 'classic' then return classic end return new end
local mode_note = SUFFIX_LEAK_ONLY and ' (suffix-leak only)'
  or (DE_ONLY and ' (de only)' or (SMOKE_ONLY and ' (smoke only)' or (BASICS_ONLY and ' (basics only)' or '')))
print('look: ' .. THEME .. mode_note)
fire('ADDON_LOADED', 'auxForever')
fire('PLAYER_LOGIN')
fire('ADDON_LOADED', 'Blizzard_AuctionHouseUI')
fire('AUCTION_HOUSE_SHOW')
for i = 1, 5 do
  clock = clock + 0.1
  for _, f in ipairs(frames) do
    if f.__shown and f.__scripts.OnUpdate then try('OnUpdate', f.__scripts.OnUpdate, f, 0.1) end
  end
end
-- Buy bar (gui/buy_bar.lua)
local function check(label, ok)
  if not ok then errors = errors + 1; print('FAIL', label) end
end
local function tick()
  clock = clock + 0.1
  for _, f in ipairs(frames) do
    if f.__shown and f.__scripts.OnUpdate then try('OnUpdate', f.__scripts.OnUpdate, f, 0.1) end
  end
end
local function same(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end
local test_dir = (arg and arg[0] or ''):gsub('[^/\\]*$', '')
if SUFFIX_LEAK_ONLY then
  dofile(test_dir .. 'suffix_leak_scan.lua')({
    G = G, check = check, try = try, addon = addon, tick = tick,
  })
  finish()
  return
end
dofile(test_dir .. 'de_tooltip_test.lua')({
  G = G, check = check, try = try, addon = addon, tick = tick,
})
if DE_ONLY then
  finish()
  return
end
dofile(test_dir .. 'smoke_test.lua')({
  G = G, check = check, try = try, addon = addon, tick = tick,
})
if SMOKE_ONLY then
  finish()
  return
end
dofile(test_dir .. 'basics_test.lua')({
  G = G, check = check, try = try, addon = addon, tick = tick,
})
if BASICS_ONLY then
  finish()
  return
end
-- Full suite: also run the leak scan against the exported fixture / seed list.
dofile(test_dir .. 'suffix_leak_scan.lua')({
  G = G, check = check, try = try, addon = addon, tick = tick,
})
try('buy bar', function()
  local require = loadstring("select(2, ...) 'aux.test'; return require")('auxForever', addon)
  local bar = require 'aux.gui.buy_bar'

  -- quantity buttons follow the stack size, the full stack being the largest
  check('stack 20 -> 1 5 10 20', same(bar.quantities(20), {1, 5, 10, 20}))
  check('stack 10 -> 1 5 10', same(bar.quantities(10), {1, 5, 10}))
  check('stack 5 -> 1 5', same(bar.quantities(5), {1, 5}))
  check('stack 200 -> 1 50 100 200', same(bar.quantities(200), {1, 50, 100, 200}))
  check('no stack -> none', same(bar.quantities(1), {}))

  local calls = {}
  C_AuctionHouse.StartCommoditiesPurchase = function(id, n) tinsert(calls, 'start ' .. id .. ' ' .. n) end
  C_AuctionHouse.ConfirmCommoditiesPurchase = function(id, n) tinsert(calls, 'confirm ' .. id .. ' ' .. n) end
  C_AuctionHouse.CancelCommoditiesPurchase = function() tinsert(calls, 'cancel') end
  C_AuctionHouse.GetQuoteDurationRemaining = function() return 30 end
  local tiers = {{count = 6, commodity_unit_price = 6}, {count = 100, commodity_unit_price = 7}}
  local bought, refreshed
  bar.show_commodity{item_id = 123, name = 'Light Feather', max_stack = 20, tiers = function() return tiers end,
    on_success = function(n) bought = n end, on_refresh = function() refreshed = true end}
  tick()
  check('starts at one stack: Buy 20', bar.primary_label():find('^Buy 20 for') ~= nil)

  -- 20 units, cheapest first: 6 x 6c + 14 x 7c = 1s 34c
  bar.primary_click()
  check('quote requested for 20', calls[1] == 'start 123 20')
  fire('COMMODITY_PRICE_UPDATED', 7, 134)
  tick()
  check('confirm shows the price', bar.primary_label():find('^Confirm') ~= nil)
  check('nothing confirmed before the click', #calls == 1)
  bar.primary_click()
  check('confirmed after the click', calls[2] == 'confirm 123 20')
  fire('COMMODITY_PURCHASE_SUCCEEDED')
  tick()
  check('success reported for 20', bought == 20)
  check('back to Buy', bar.primary_label():find('^Buy') ~= nil)

  -- a server price above the estimate is cancelled, never confirmed, and the listings re-read
  calls = {}
  bar.primary_click()
  fire('COMMODITY_PRICE_UPDATED', 7, 135)
  tick()
  check('higher price cancelled', calls[2] == 'cancel')
  check('higher price not confirmed', #calls == 2)
  check('higher price refreshes listings', refreshed)
  check('higher price returns to Buy', bar.primary_label():find('^Buy') ~= nil)

  -- the Cancel button next to Confirm cancels the quote and buys nothing
  local cancel_button
  for _, f in ipairs(frames) do if f.__text == 'Cancel' and not cancel_button then cancel_button = f end end -- the buy bar's is created first
  calls = {}
  -- the colors the Buy button is painted in (0.8, Tyler: it stayed Confirm green after Cancel)
  local painted
  rawset(bar.primary_button, 'SetBackdropBorderColor', function(_, r, g, b) painted = r .. ',' .. g .. ',' .. b end)
  bar.primary_click()
  fire('COMMODITY_PRICE_UPDATED', 6, 120)
  tick()
  local confirm_paint = painted
  check('Cancel button exists and is shown with a quote', cancel_button and cancel_button.__shown)
  -- the bar redraws every frame; hiding the button between mouse press and release loses the click
  local hides = 0
  rawset(cancel_button, 'Hide', function(self) hides = hides + 1; self.__shown = false end)
  tick(); tick()
  rawset(cancel_button, 'Hide', nil)
  check('Cancel button is not hidden while the quote is shown', hides == 0 and cancel_button.__shown)
  cancel_button.__scripts.OnClick(cancel_button, 'LeftButton')
  tick()
  check('Cancel button cancels the quote', calls[2] == 'cancel' and #calls == 2)
  check('Cancel button returns to Buy', bar.primary_label():find('^Buy') ~= nil)
  check('after Cancel the Buy button loses the Confirm color', confirm_paint and painted ~= confirm_paint)
  rawset(bar.primary_button, 'SetBackdropBorderColor', nil)

  -- selecting something else while a price is shown cancels it
  calls = {}
  bar.primary_click()
  fire('COMMODITY_PRICE_UPDATED', 6, 120)
  bar.clear()
  check('clearing the bar cancels the quote', calls[2] == 'cancel')

  -- items: one per click at the price on the button; never your own
  local buys = 0
  local record = {buyout_price = 21000, bid_price = 15000, auction_count = 6}
  bar.show_item{record = record, name = 'Heavy Brown Bag', busy = function() return false end,
    on_buy = function() buys = buys + 1 end, on_bid = function() end}
  tick()
  check('item button shows its price', bar.primary_label():find('^Buy for') ~= nil)
  bar.primary_click()
  check('item bought once', buys == 1)
  bar.show_item{record = {buyout_price = 21000, bid_price = 15000}, name = 'Heavy Brown Bag', own = true,
    busy = function() return false end, on_buy = function() buys = buys + 1 end, on_bid = function() end}
  tick()
  bar.primary_click()
  check('own auction not bought', buys == 1)
end)

-- Listings sized by anchors have no size until the first layout pass (Post tab price lists).
try('listing before layout', function()
  local require = loadstring("select(2, ...) 'aux.test2'; return require")('auxForever', addon)
  local listing = require 'aux.gui.listing'
  G.__geometry = {size = 0, edge = nil}
  local st = listing.new(new_frame())
  st:SetColInfo{{name = 'Price', width = .5}, {name = 'Count', width = .5}}
  st:SetData{{cols = {{value = '1s'}, {value = '5'}}}}
  check('no rows before layout', st.numRows == 0)
  G.__geometry = {size = 200, edge = 100}
  st.__scripts.OnSizeChanged(st)
  check('rows appear after layout', st.numRows > 0 and #st.rows == st.numRows)
  G.__geometry = nil
end)

-- Resizable window: lists show as many rows as fit and keep up when the window changes size.
try('lists follow the window size', function()
  local require = loadstring("select(2, ...) 'aux.test3'; return require")('auxForever', addon)
  local auction_listing = require 'aux.gui.auction_listing'
  local item_listing = require 'aux.gui.item_listing'
  G.__geometry = {size = 0, edge = nil}
  local rt = auction_listing.new(new_frame(), 19, auction_listing.search_columns)
  check('auction list: no rows before layout', #rt.rows == 0)
  G.__geometry = {size = 29 + 19 * 14, edge = 100}
  rt.__scripts.OnSizeChanged(rt)
  check('auction list: 14 rows fit', #rt.rows == 14)
  for _, row in ipairs(rt.rows) do row:Show() end -- as if filled with auctions
  G.__geometry.size = 29 + 19 * 9
  rt.__scripts.OnSizeChanged(rt)
  check('auction list: shrinks to 9 rows', #rt.rows == 9 and not rt.all_rows[10].__shown)
  G.__geometry.size = 29 + 19 * 14
  rt.__scripts.OnSizeChanged(rt)
  check('auction list: grows back reusing rows', #rt.rows == 14 and #rt.all_rows == 14)

  G.__geometry = {size = 0, edge = nil}
  local il = item_listing.new(new_frame(), function() end, function() return false end)
  item_listing.populate(il, {})
  check('item list: no rows before layout', #il.rows == 0)
  G.__geometry = {size = 400, edge = 100}
  il.content_frame.__scripts.OnSizeChanged(il.content_frame)
  check('item list: 10 rows fit', #il.rows == 10)
  G.__geometry = nil

  -- FB-011 (Gaddor): a click on a row's icon selects the item, as a click on its name does
  local clicked = {}
  local il2 = item_listing.new(new_frame(), function(self, button) tinsert(clicked, {self.item_record, button}) end, function() return false end)
  G.__geometry = {size = 400, edge = 100}
  il2.content_frame.__scripts.OnSizeChanged(il2.content_frame)
  G.__geometry = nil
  local row = il2.rows[1]
  row.item_record = {name = 'Linen Cloth'}
  row.item.button.__scripts.OnMouseUp(row.item.button, 'LeftButton')
  check('item list: a click on the icon selects the item', clicked[1] and clicked[1][1] == row.item_record and clicked[1][2] == 'LeftButton')
  row.__scripts.OnMouseUp(row, 'RightButton')
  check('item list: a click on the name still does', clicked[2] and clicked[2][1] == row.item_record and clicked[2][2] == 'RightButton')

  -- the window size is saved and restored within the screen
  local aux = require 'aux'
  local f, w, h = aux.frame
  rawset(f, 'SetWidth', function(_, x) w = x end)
  rawset(f, 'SetHeight', function(_, x) h = x end)
  rawset(f, 'GetWidth', function() return w end)
  rawset(f, 'GetHeight', function() return h end)
  G.__geometry = {size = 3000, edge = 100}
  aux.account_data.window = {width = 1300, height = 700}
  aux.restore_window()
  check('window restores its saved size', w == 1300 and h == 700)
  aux.account_data.window = {width = 400, height = 9000}
  aux.restore_window()
  check('window size kept within bounds', w == 1000 and h == 3000)
  G.__geometry = nil
end)

-- Visual refresh: square styling (0.6, the UI Kit) keeps the old backdrop color calls working; seller column text
try('restyle', function()
  local require = loadstring("select(2, ...) 'aux.test4'; return require")('auxForever', addon)
  local gui = require 'aux.gui'
  local auction_listing = require 'aux.gui.auction_listing'
  local colored = {}
  local button = gui.button(new_frame())
  -- New: square (one fill, four 1px edges). Classic: rounded (four corners and three or four straight pieces)
  check('button has a square fill (Classic: rounded)', button.aux_fill and #button.aux_fill.pieces == pick(1, 7))
  check('button has a 1px outline on four sides (Classic: rounded)', button.aux_border and #button.aux_border.pieces == pick(4, 8))
  for _, t in ipairs(button.aux_fill.pieces) do rawset(t, 'SetVertexColor', function(_, r) colored[#colored + 1] = r end) end
  button:SetBackdropColor(.5, .5, .5, 1)
  check('SetBackdropColor recolors the fill', #colored == pick(1, 7) and colored[1] == .5)
  -- 0.6, the UI Kit: looks. Default buttons have a gold label, the primary one a gold outline,
  -- disabled ones a gray label; a selected tab stays lit although it is disabled
  local function label_color(b)
    local c
    rawset(b, 'GetFontString', function() return {SetTextColor = function(_, r, g, bl, a) c = {r, g, bl, a} end, GetFont = function() return 'f', 15 end, SetFont = function() end} end)
    return function() return c end
  end
  local b2 = gui.button(new_frame())
  local c2 = label_color(b2)
  gui.set_default(b2)
  check('default button: gold label (Classic: light)', math.abs(c2()[1] - pick(229, 243) / 255) < .001 and math.abs(c2()[3] - pick(91, 230) / 255) < .001)
  local border
  rawset(b2, 'SetBackdropBorderColor', function(_, r, g, bl) border = {r, g, bl} end)
  gui.set_primary(b2)
  check('primary button: gold outline (Classic: amber)', border and math.abs(border[1] - pick(229, 227) / 255) < .001)
  rawset(b2, 'IsEnabled', function() return false end)
  b2:Disable()
  check('disabled button: gray label', math.abs(c2()[1] - pick(107, 125) / 255) < .001)
  gui.apply_look(b2, 'selected', true)
  check('selected look drawn on a disabled tab', math.abs(c2()[1] - pick(255, 243) / 255) < .001 and math.abs(c2()[2] - pick(255, 239) / 255) < .001)
  check('a button has the raised gradient', b2.aux_sheen ~= nil)
  -- selection and hover of a table row are separate: hover never shows the gold bar
  local row = new_frame()
  local sel = gui.row_selection(row)
  check('row selection starts hidden', not sel:IsShown())
  sel:Show()
  check('row selection shows', sel:IsShown())
  -- a client whose SetGradient wants numbers must not break loading
  local tex = new_frame()
  rawset(tex, 'SetGradient', function() error('bad argument') end)
  G.CreateColor = function(r, g, b, a) return {r, g, b, a} end
  local ok = pcall(gui.set_gradient, tex, .3)
  G.CreateColor = nil
  check('gradient falls back without an error', ok)
  -- an input's red border for a bad value survives typing in it and clicking away
  local box = gui.editbox(new_frame())
  local shown_border
  for _, t in ipairs(box.aux_border.pieces) do rawset(t, 'SetVertexColor', function(_, r, g, b) shown_border = {r, g, b} end) end
  box:SetBackdropBorderColor(1, 0, 0, 1)
  box.__scripts.OnEditFocusGained(box)
  check('gold while typing (Classic: the usual edge)', math.abs(shown_border[1] - pick(229, 58) / 255) < .001)
  box.__scripts.OnEditFocusLost(box)
  check('red again after typing', shown_border[1] == 1 and shown_border[2] == 0)
  check('named seller shown', auction_listing.seller_text{owner = 'Violet Toes'} == 'Violet Toes')
  check('several sellers counted', auction_listing.seller_text{seller_count = 12}:find('12 sellers') ~= nil)
  check('unknown seller', auction_listing.seller_text{seller_count = 1} == '?')

  -- after a /reload the new font file is not available yet and a label reports height 0;
  -- the game errors on SetFont with height 0, so set_primary must never pass it on
  local heights = {}
  local label = new_frame()
  rawset(label, 'GetFont', function() return nil, 0 end)
  rawset(label, 'SetFont', function(_, _, h) heights[#heights + 1] = h end)
  local primary = gui.button(new_frame())
  rawset(primary, 'GetFontString', function() return label end)
  gui.set_primary(primary)
  check('primary button font height is never 0', #heights == 1 and heights[1] > 0)
  check('a font is always set', type(gui.font) == 'string' and type(gui.font_bold) == 'string')
end)

-- Dropdowns: on the modern client the edit box loses focus as soon as an option is pressed
try('dropdown option click', function()
  local require = loadstring("select(2, ...) 'aux.test5'; return require")('auxForever', addon)
  local gui = require 'aux.gui'
  local dropdown = gui.dropdown(new_frame())
  dropdown:SetOptions{'2 Hours', '8 Hours', '24 Hours'}
  dropdown:SetIndex(2)
  dropdown.focus_gain()
  local menu = gui.dropdown_menu
  check('menu opens', menu.__shown)
  rawset(menu, 'IsMouseOver', function() return true end)
  dropdown.focus_loss() -- the press on an option takes focus first
  check('menu stays open while an option is being clicked', menu.__shown)
  local option = gui.dropdown_items[3]
  option.__scripts.OnMouseDown(option)
  check('clicked option is selected', dropdown:GetIndex() == 3)
  check('menu closes after the click', not menu.__shown)
  rawset(menu, 'IsMouseOver', function() return false end)
  dropdown.focus_gain()
  dropdown.focus_loss()
  check('menu closes when focus leaves elsewhere', not menu.__shown)
end)

-- Posting: match the cheapest price by default, one step below it in undercut mode.
-- Gear is priced in whole silver; trade goods can use copper.
try('undercut mode', function()
  local require = loadstring("select(2, ...) 'aux.test6'; return require")('auxForever', addon)
  local aux = require 'aux'
  local post = require 'aux.tabs.post'
  local post_env = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  check('undercut mode is off by default', aux.account_data.post_undercut == false)
  post.set_undercut_mode(true)
  fire('AUCTION_HOUSE_SHOW')
  check('undercut mode starts off every time the auction house opens', aux.account_data.post_undercut == false)
  -- Tyler (2026-10-17, FB-018): once a player picks Undercut it stays for every post until the
  -- auction house closes, through other tabs and other items
  post.set_undercut_mode(true)
  aux.set_tab(1); aux.set_tab(3); aux.set_tab(4); aux.set_tab(3)
  check('undercut mode stays on through other tabs until the auction house closes', aux.account_data.post_undercut == true)
  fire('AUCTION_HOUSE_SHOW')

  post_env.selected_item = {commodity = true, key = '2447:0'}
  check('trade goods: default matches the cheapest price', post.undercut({unit_price = 88}, 1) == 88)
  post.set_undercut_mode(true)
  check('trade goods: undercut goes 1 copper below', post.undercut({unit_price = 88}, 1) == 87)
  check('own listing is never undercut', post.undercut({unit_price = 88, own = true}, 1) == 88)

  post_env.selected_item = {commodity = false, key = '15248:0'}
  check('gear: undercut goes 1 silver below', post.undercut({unit_price = 21000}, 1) == 20900)
  check('gear: never below 1 silver', post.undercut({unit_price = 100}, 1) == 100)
  check('gear: prices round down to whole silver', post.round_price(20947) == 20900 and post.round_price(40) == 100)
  post.set_undercut_mode(false)
  check('gear: default matches the cheapest price', post.undercut({unit_price = 21000}, 1) == 21000)

  local copper = C_AuctionHouse.SupportsCopperValues
  C_AuctionHouse.SupportsCopperValues = function() return false end
  post_env.selected_item = {commodity = true, key = '2447:0'}
  post.set_undercut_mode(true)
  check('trade goods without copper: 1 silver below', post.undercut({unit_price = 8800}, 1) == 8700)
  C_AuctionHouse.SupportsCopperValues = copper
  post.set_undercut_mode(false)
  check('turning it off matches again', post.undercut({unit_price = 88}, 1) == 88 and aux.account_data.post_undercut == false)
  post_env.selected_item = nil
end)

-- The status bar is amber only while something loads, a faint fill when idle, dark gold when done
try('status bar idle color', function()
  local require = loadstring("select(2, ...) 'aux.test7'; return require")('auxForever', addon)
  local gui = require 'aux.gui'
  local bar = gui.status_bar(new_frame())
  local color
  rawset(bar.primary_status_bar, 'SetStatusBarColor', function(_, r) color = r end)
  bar:update_status(0, 0)
  check('amber while loading', math.abs(color - pick(150, 227) / 255) < .001)
  bar:update_status(1, 1)
  check('faint when idle', math.abs(color - pick(255, 77) / 255) < .001)
  bar:set_done(true)
  check('dark gold when a search has finished', math.abs(color - pick(42, 58) / 255) < .001)
  bar:update_status(0, 0)
  check('amber again while loading', math.abs(color - pick(150, 227) / 255) < .001)
  bar:update_status(1, 1)
  bar:set_done(false)
  check('faint after leaving the search', math.abs(color - pick(255, 77) / 255) < .001)

  -- the search tab turns it gold for a finished search shown in the results, and off when leaving
  local aux = require 'aux'
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  search.frame:Show()
  search.new_search('light feather/exact', search.NORMAL_MODE or 1)
  search.set_subtab(search.RESULTS)
  check('new search is not gold', not aux.status_bar.done)
  search.current_search().complete = true
  search.update_done()
  check('finished search is gold', aux.status_bar.done)
  search.set_subtab(search.SAVED)
  check('leaving to saved searches ends gold', not aux.status_bar.done)
  search.set_subtab(search.RESULTS)
  check('back on the results it is gold again', aux.status_bar.done)
  search.new_search('copper ore/exact', search.NORMAL_MODE or 1)
  check('a new search ends gold', not aux.status_bar.done)
  search.previous_search()
  check('going back to the finished search is gold', aux.status_bar.done)
  search.frame:Hide()
  search.update_done()
  check('leaving the search tab ends gold', not aux.status_bar.done)
end)

-- Quick search menu: pinned (favorites) and recent searches with the last price seen
try('quick searches', function()
  local require = loadstring("select(2, ...) 'aux.test8'; return require")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local recent, favorites = search.recent_searches, search.favorite_searches
  while tremove(recent) do end
  while tremove(favorites) do end
  local copper = {filter_string = 'copper ore/exact', prettified = 'copper ore'}
  local cloth = {filter_string = 'cloth/20/30', prettified = 'cloth 20-30'}
  local hide = {filter_string = 'light hide/exact', prettified = 'light hide'}
  tinsert(recent, copper); tinsert(recent, cloth); tinsert(recent, hide)

  check('never searched shows a hint', search.quick_entry_detail(hide) == 'Search again to see prices')
  search.remember_search_result('copper ore/exact', {
    {item_id = 2770, unit_buyout_price = 300}, {item_id = 2770, unit_buyout_price = 277},
    {item_id = 2770, unit_buyout_price = 100, own = true}})
  check('cheapest price of other players is kept', copper.last_price == 277)
  check('single item search keeps the item', copper.item_id == 2770 and copper.last_time ~= nil)
  check('detail shows the cheapest price', search.quick_entry_detail(copper):find('^Cheapest') ~= nil)
  search.remember_search_result('cloth/20/30', {{item_id = 2589, unit_buyout_price = 50}, {item_id = 2996, unit_buyout_price = 900}})
  check('several items keep no item', cloth.item_id == nil and cloth.last_price == 50)
  search.remember_search_result('light hide/exact', {})
  check('nothing found has no price', hide.last_price == nil and hide.last_time ~= nil)

  local now = time()
  check('time: minutes', search.time_ago(now - 300) == '5m ago')
  check('time: hours', search.time_ago(now - 7200) == '2h ago')
  check('time: yesterday', search.time_ago(now - 90000) == 'yesterday')
  check('time: days', search.time_ago(now - 3 * 86400) == '3 days ago')

  search.frame:Show()
  search.toggle_quick_menu()
  check('menu opens', search.quick_menu.__shown)
  local function shown_rows()
    local n = 0
    for _, row in ipairs(search.quick_menu_rows) do if row.__shown then n = n + 1 end end
    return n
  end
  check('three recent rows', shown_rows() == 3)

  search.pin_search(cloth)
  check('pinned search is a favorite', favorites[1] == cloth and search.is_pinned(cloth))
  check('pinned search is listed once', shown_rows() == 3)
  search.pin_search(cloth)
  check('pinning twice adds nothing', #favorites == 1)
  search.unpin_search(cloth)
  check('unpinned search is no longer a favorite', #favorites == 0 and not search.is_pinned(cloth))
  local old = {filter_string = 'linen cloth/exact', prettified = 'linen cloth'}
  tinsert(favorites, old)
  search.unpin_search(old)
  check('unpinning a search that is not recent keeps it in recent', recent[1] == old)

  local row = search.quick_menu_rows[1]
  row.__scripts.OnClick(row)
  check('clicking a row closes the menu', not search.quick_menu.__shown)
  check('clicking a row searches it', search.search_box:GetText() == row.entry.filter_string)
  search.toggle_quick_menu()
  search.frame:Hide()
  check('menu closes with the search tab', not search.quick_menu.__shown)
end)

-- The back and forward arrows never disappear; they fade when there is nowhere to go
try('history arrows', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local state = {}
  for _, name in ipairs{'previous_button', 'next_button'} do
    local b = search[name]
    state[name] = {}
    rawset(b, 'Enable', function() state[name].enabled = true end)
    rawset(b, 'Disable', function() state[name].enabled = false end)
    rawset(b, 'SetAlpha', function(_, a) state[name].alpha = a end)
    rawset(b, 'Hide', function() state[name].hidden = true end)
  end
  search.new_search('copper ore/exact', search.NORMAL_MODE or 1)
  search.new_search('light hide/exact', search.NORMAL_MODE or 1)
  check('newest search: forward faded, not hidden', state.next_button.enabled == false and state.next_button.alpha < 1 and not state.next_button.hidden)
  check('newest search: back works', state.previous_button.enabled == true and state.previous_button.alpha == 1)
  search.previous_search()
  check('after going back: forward works', state.next_button.enabled == true and state.next_button.alpha == 1)
  for _, name in ipairs{'previous_button', 'next_button'} do
    for _, k in ipairs{'Enable', 'Disable', 'SetAlpha', 'Hide'} do rawset(search[name], k, nil) end
  end
end)

-- Background opacity: only backgrounds fade, never below 70%
try('background opacity', function()
  local require = loadstring("select(2, ...) 'aux.test9'; return require")('auxForever', addon)
  local aux = require 'aux'
  local gui = require 'aux.gui'
  local panel = gui.panel(new_frame())
  local alpha
  rawset(panel, 'SetBackdropColor', function(_, r, g, b, a) alpha = a end)
  aux.set_background_opacity(.85)
  check('opacity is saved', math.abs(aux.account_data.background_opacity - .85) < .001)
  check('panel background fades', math.abs(alpha - .85) < .001)
  aux.set_background_opacity(.2)
  check('opacity never goes below 50%', math.abs(aux.account_data.background_opacity - .5) < .001 and math.abs(alpha - .5) < .001)
  aux.set_background_opacity(1.5)
  check('opacity never goes above 100%', aux.account_data.background_opacity == 1)
  SlashCmdList.AUX('opacity 80')
  check('/aux opacity 80 sets 80%', math.abs(aux.account_data.background_opacity - .8) < .001)
  local button = gui.button(new_frame())
  local button_alpha
  rawset(button, 'SetBackdropColor', function(_, r, g, b, a) button_alpha = a end)
  aux.set_background_opacity(.5)
  check('buttons are not faded', button_alpha == nil)
  aux.set_background_opacity(1)
end)

-- Post tab panel: summary, note under the price, duration buttons, mode switch
try('post panel', function()
  local require = loadstring("select(2, ...) 'aux.test10'; return require")('auxForever', addon)
  local aux = require 'aux'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local function text(region) return region.__text end
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end

  post.selected_item = {commodity = true, key = '3385:0', item_id = 3385, name = 'Minor Mana Potion', quality = 1, count = 3, max_stack = 5}
  post.stack_size_input:SetNumber(3); post.stack_size_input.__number = 3
  rawset(post.stack_size_input, 'GetNumber', function() return 3 end)
  rawset(post.stack_count_input, 'GetNumber', function() return 2 end)
  post.set_unit_buyout_price(69)
  post.update_item_configuration()
  check('trade good: posts stack size x stacks', post.post_quantity() == 6)
  check('item name without brackets', text(post.item.name) == 'Minor Mana Potion')
  check('bags shown, no stacks for trade goods', plain(text(post.item_detail)):find('3 in your bags') ~= nil and plain(text(post.item_detail)):find('stack of') == nil)
  check('receipt: total line names the items', plain(text(post.posting_summary)) == 'Total, 6 items' and plain(text(post.total_summary)) == '4s 14c')
  check('receipt: the auction house cut, going out', plain(text(post.cut_summary)) == '-21c' and plain(text(post.cut_label)) == 'Auction house cut 5%')
  check('post button says what it posts', text(post.post_button) == 'Post 6 items')
  check('what you get is shown', text(post.net_label) == 'You get' and plain(text(post.net_summary)) == '3s 93c')
  check('the cut is 5%', post.AUCTION_CUT == .05)
  local colors = {}
  rawset(post.post_button, 'GetFontString', function(self) return self.label end)
  rawset(post.post_button.label, 'SetTextColor', function(_, r) colors[#colors + 1] = r end)
  rawset(post.post_button, 'IsEnabled', function() return false end)
  post.post_button:Disable()
  rawset(post.post_button, 'IsEnabled', nil)
  post.post_button:Enable()
  local enable_calls = #colors
  post.post_button:Enable()
  check('enabling an enabled button redraws nothing', #colors == enable_calls)
  rawset(post.post_button, 'IsEnabled', function() return false end)
  post.post_button:Disable()
  rawset(post.post_button, 'IsEnabled', nil)
  check('post button: gold label, gray when disabled', math.abs(colors[#colors - 1] - pick(229, 245) / 255) < .001 and math.abs(colors[#colors] - pick(107, 125) / 255) < .001)

  check('typed price note', plain(post.price_note_text()) == 'Your own price')
  post.set_buyout_selection({unit_price = 69})
  post.set_undercut_mode(false)
  check('match note', plain(post.price_note_text()):find('^Same as the lowest listing') ~= nil)
  post.set_undercut_mode(true)
  check('undercut note for trade goods', plain(post.price_note_text()):find('^1 copper below') ~= nil)
  post.selected_item.commodity = false
  check('undercut note for gear', plain(post.price_note_text()):find('^1 silver below') ~= nil and plain(post.price_note_text()):find('whole silver') ~= nil)
  post.set_undercut_mode(false)
  post.set_buyout_selection({unit_price = 69, own = true})
  check('own listing note', plain(post.price_note_text()):find('your own listing') ~= nil)
  post.set_buyout_selection()

  post.update_item_configuration()
  check('gear posts one per count', post.post_quantity() == 2)
  check('gear hides stack size', post.stack_size_input.__shown == false)
  check('gear count caption', text(post.stack_count_input.caption) == 'Count')

  local changed = 0
  local original = post.duration_dropdown.selection_change
  post.duration_dropdown.selection_change = function() changed = changed + 1 end
  post.duration_dropdown:SetIndex(3)
  check('duration buttons select', post.duration_dropdown:GetIndex() == 3 and changed == 1)
  post.duration_dropdown:SetIndex(3)
  check('same duration again changes nothing', changed == 1)
  post.duration_dropdown.buttons[1].__scripts.OnClick(post.duration_dropdown.buttons[1])
  check('clicking 2h selects it', post.duration_dropdown:GetIndex() == 1)
  post.duration_dropdown.selection_change = original

  local undercut_button = post.mode_switch.undercut_button
  undercut_button.__scripts.OnClick(undercut_button)
  check('switch turns undercut on', aux.account_data.post_undercut == true)
  post.mode_switch.match_button.__scripts.OnClick(post.mode_switch.match_button)
  check('switch turns it off', aux.account_data.post_undercut == false)
  post.selected_item = nil
  post.update_item_configuration()
  check('no item: post button plain', text(post.post_button) == 'Post')
end)

-- Post: once an item's listings are in, the price starts at the lowest listing (or one step below)
try('post auto price', function()
  local require = loadstring("select(2, ...) 'aux.test11'; return require")('auxForever', addon)
  local aux = require 'aux'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  post.clear_auctions()
  -- picking an item searches it (0.6.0.2); the search answers with these listings
  local scan_exports = require 'aux.core.scan'
  local real_start = scan_exports.start
  rawset(scan_exports, 'start', function(params)
    for _, price in ipairs{300, 240, 290} do
      params.on_auction({item_key = '4422:0', commodity = true, unit_buyout_price = price, count = 5, duration = 2, owner = 'Someone'})
    end
    params.on_complete()
  end)
  local item = {key = '4422:0', item_id = 4422, commodity = true, name = 'Scroll of Stamina', quality = 1, count = 2, max_stack = 5}
  post.set_undercut_mode(false)
  post.update_item(item)
  post.set_unit_buyout_price(30000) -- the price remembered from last time
  post.on_update()
  check('starts at the lowest listing', post.get_unit_buyout_price() == 240)
  check('the lowest listing is selected', post.get_buyout_selection() and post.get_buyout_selection().unit_price == 240)
  post.set_undercut_mode(true)
  post.on_update()
  check('undercut mode goes one step below the lowest', post.get_unit_buyout_price() == 239)
  post.set_undercut_mode(false)
  post.set_buyout_selection()
  post.set_unit_buyout_price(500)
  post.on_update()
  check('a typed price is kept', post.get_unit_buyout_price() == 500)
  post.update_item(item)
  post.on_update()
  check('loading the item again starts at the lowest again', post.get_unit_buyout_price() == 240)

  -- the status bar is gold once the listings are in, and back to normal on leaving the tab
  aux.set_tab(3) -- Search, Sniper, Post
  post.update_item(item)
  check('post: gold once the listings are in', aux.status_bar.done == true)
  local plain = function(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local stub_deposit = C_AuctionHouse.CalculateCommodityDeposit
  C_AuctionHouse.CalculateCommodityDeposit = function() return 120 end
  post.update_item_configuration()
  C_AuctionHouse.CalculateCommodityDeposit = stub_deposit
  check('deposit shown as money going out', plain(post.deposit.__text):find('^%-') ~= nil and plain(post.deposit_label.__text):find('^Deposit') ~= nil)
  check('you get shown in green', post.net_summary.__text:upper():find(pick('4DCC66', '6FD39A'), 1, true) ~= nil)
  aux.set_tab(4)
  check('post: leaving the tab ends gold', aux.status_bar.done == false)
  post.selected_item = nil
  rawset(scan_exports, 'start', real_start)
end)

-- Post: per-item amount and the vendor warning under "You get"; deposit explained on mouse over
try('post money details', function()
  local require = loadstring("select(2, ...) 'aux.test12'; return require")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local plain = function(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  post.selected_item = {commodity = true, key = '765:0', item_id = 765, name = 'Silverleaf', quality = 1, count = 20, max_stack = 20, unit_vendor_price = 5}
  rawset(post.stack_size_input, 'GetNumber', function() return 10 end)
  rawset(post.stack_count_input, 'GetNumber', function() return 2 end)
  post.set_unit_buyout_price(100)
  post.update_item_configuration()
  check('per item amount shown for several items', plain(post.net_detail.__text):find('95c each') ~= nil)
  check('no warning box when the auction house pays more', post.vendor_warning.__shown ~= true and plain(post.net_detail.__text):find('vendor pays 1s') ~= nil)
  post.set_unit_buyout_price(4)
  post.update_item_configuration()
  check('warning box when a vendor pays more', post.vendor_warning.__shown == true and plain(post.vendor_warning.amount.__text) == '1s' and plain(post.net_detail.__text):find('vendor') == nil)
  check('you get turns red below vendor price', post.net_summary.__text:upper():find(pick('E8574A', 'FF0000'), 1, true) ~= nil)
  local shows = 0
  rawset(post.vendor_warning, 'Show', function(self) shows = shows + 1; self.__shown = true end)
  post.update_item_configuration()
  check('the warning box is not shown again on every update', shows == 0)
  rawset(post.vendor_warning, 'Show', nil)
  rawset(post.stack_count_input, 'GetNumber', function() return 1 end)
  rawset(post.stack_size_input, 'GetNumber', function() return 1 end)
  post.set_unit_buyout_price(100)
  post.update_item_configuration()
  local layout = loadstring("select(2, ...) 'aux.tabs.post'; return price_layout")('auxForever', addon)
  check('the percentage has of usual under it', post.start_price_percentage.under.__text == 'of usual')
  check('post layout: the percentage fits left of the divider at the smallest window', 777 + layout.divider_from_right - layout.usual_x >= 64)
  check('post layout: the headings sit above the first price field', layout.header_y >= layout.first_row + 4)
  rawset(post.stack_count_input, 'GetNumber', function() return 1 end)
  rawset(post.stack_size_input, 'GetNumber', function() return 1 end)
  local deposit = C_AuctionHouse.CalculateCommodityDeposit
  C_AuctionHouse.CalculateCommodityDeposit = function() return 0 end
  post.update_item_configuration()
  check('no deposit shows 0c, not -0c', plain(post.deposit.__text) == '0c')
  C_AuctionHouse.CalculateCommodityDeposit = deposit
  check('no per item amount for a single item', plain(post.net_detail.__text) == 'vendor pays 5c' and post.vendor_warning.__shown ~= true)
  post.selected_item = {key = '2:0', item_id = 2, name = 'Staff', quality = 2, count = 1, unit_vendor_price = 0}
  post.set_unit_start_price(1500); post.set_unit_buyout_price(1500)
  check('gear: bid equal to buyout is explained', plain(post.price_note_text()):find('posts as buyout only') ~= nil)
  post.set_unit_start_price(1200)
  check('gear: a lower bid needs no note', plain(post.price_note_text()):find('buyout only') == nil)
  post.start_price_percentage:SetText('---')
  check('no usual price: the percentage says none', plain(post.start_price_percentage.text.__text) == 'none')
  rawset(post.stack_size_input, 'GetNumber', nil); rawset(post.stack_count_input, 'GetNumber', nil)
  post.selected_item = nil
end)

-- Tables: level first, units for sale, and no Bid column when every row is a trade good
try('table columns', function()
  local require = loadstring("select(2, ...) 'aux.test13'; return require")('auxForever', addon)
  local al = require 'aux.gui.auction_listing'
  for name, columns in pairs{search = al.search_columns, auctions = al.auctions_columns, bids = al.bids_columns} do
    -- Tyler, 0.7: Req, iLvl, Item, For sale (build 4: "Req first always"); the units for sale never
    -- next to a level
    check(name .. ': required level is the first column', columns[1].title == 'Req')
    check(name .. ': item level is second', columns[2].title == 'iLvl')
    check(name .. ': item is third', columns[3].title == 'Item')
    local titles = {}
    for _, c in ipairs(columns) do titles[#titles + 1] = type(c.title) == 'table' and c.title[1] or c.title end
    local joined = table.concat(titles, '|')
    check(name .. ': no Auctions or Stack Size column', not joined:find('Auctions|', 1, true) and not joined:find('Stack', 1, true))
  end
  check('search: For sale column', al.search_columns[4].title == 'For sale')
  local cell = {text = new_frame()}
  al.search_columns[4].fill(cell, {count = 1032}, 1032, 0, false)
  check('for sale shows units', cell.text.__text == 1032)
  al.search_columns[4].fill(cell, {count = 1}, 6, 2, false)
  check('for sale shows your own units', tostring(cell.text.__text):find('(2)', 1, true) ~= nil)

  local rt = al.new(new_frame(), 19, al.search_columns)
  local function bid_hidden() return rt.hide_bid == true end
  rt:SetDatabase({{commodity = true, count = 20, item_key = 'a', search_signature = 'a1', name = 'A', requirement = 0, unit_buyout_price = 7, buyout_price = 140, unit_bid_price = 0, bid_price = 0, duration = 2, sniping_signature = 'x'}})
  check('bid column hidden for trade goods only', bid_hidden())
  rt:SetDatabase({{commodity = true, count = 20, item_key = 'a', search_signature = 'a1', name = 'A', requirement = 0, unit_buyout_price = 7, buyout_price = 140, unit_bid_price = 0, bid_price = 0, duration = 2},
                  {count = 1, auction_count = 3, item_key = 'b', search_signature = 'b1', name = 'B', requirement = 10, unit_buyout_price = 900, buyout_price = 900, unit_bid_price = 500, bid_price = 500, high_bid = 0, duration = 3}})
  check('bid column shown when gear is in the results', not bid_hidden())
  -- the selected record stays selected when rows are added above it (Tyler, 0.4.1)
  local function grec(key, price) return {count = 1, item_key = key, search_signature = key, name = key, requirement = 0, unit_buyout_price = price, buyout_price = price, unit_bid_price = 0, bid_price = 0, high_bid = 0, duration = 2} end
  local ra, rb = grec('ka', 100), grec('kb', 200)
  local db = {ra, rb}
  rt:SetDatabase(db)
  rt:SetSelectedRecord(rb)
  tinsert(db, 1, grec('kc', 50))
  rt:SetDatabase(db)
  check('selection stays on the same record when rows are added', rt:GetSelection() and rt:GetSelection().record == rb)
  -- an auction with no starting bid shows no bid, not its buyout (Tyler, 0.4.1)
  local bid_col
  for i, c in ipairs(al.search_columns) do
    if type(c.title) == 'table' and c.title[1]:find('^Auction Bid') then bid_col = i end
  end
  local bcell = {text = new_frame()}
  al.search_columns[bid_col].fill(bcell, {count = 1, unit_buyout_price = 1200, buyout_price = 1200, unit_bid_price = 1200, bid_price = 1200, high_bid = 0})
  check('bid column: buyout only shows ---', bcell.text.__text == '---')
  al.search_columns[bid_col].fill(bcell, {count = 1, unit_buyout_price = 1200, buyout_price = 1200, unit_bid_price = 800, bid_price = 800, high_bid = 0})
  check('bid column: a real starting bid shows', tostring(bcell.text.__text):find('^8') ~= nil)
end)

-- Post price lists: units for sale, time left, price, % of usual
-- Tyler, 0.6.0.2 build 1: Light Feather showed three rows at 8c (26 and 480 at 24h, his own 2 at
-- 2h). A commodity is one row per price, yours apart, with the longest time left; gear is not merged.
try('post: one row per price for commodities', function()
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local data
  rawset(post.buyout_listing, 'SetData', function(_, rows) data = rows end)
  post.clear_auctions()
  local function listing(units, price, duration, own)
    post.record_auction({item_key = '17056:0', commodity = true, unit_buyout_price = price, count = units, duration = duration, owner = own and 'P' or 'Someone'})
  end
  listing(10, 8, 3); listing(26, 8, 4); listing(480, 8, 4); listing(2, 8, 2, true); listing(196, 9, 4)
  post.selected_item = {commodity = true, key = '17056:0', item_id = 17056, name = 'Light Feather', quality = 1, count = 12, max_stack = 200}
  post.update_auction_listings()
  local at8, own8, n = nil, nil, 0
  for _, row in ipairs(data or {}) do
    if not row.record.historical_value then
      n = n + 1
      if row.record.unit_price == 8 and not row.record.own then at8 = row end
      if row.record.unit_price == 8 and row.record.own then own8 = row end
    end
  end
  check('commodity rows: one row per price, yours apart', n == 3)
  check('commodity rows: units added up', at8 and at8.cols[1].value == 516)
  check('commodity rows: the longest time left', at8 and at8.record.duration == 4)
  check('commodity rows: your own stay a row of their own', own8 ~= nil)
  post.clear_auctions()
  post.record_auction({item_key = '5210:0', unit_buyout_price = 700, unit_blizzard_bid = 700, count = 1, duration = 4, owner = 'Someone'})
  post.record_auction({item_key = '5210:0', unit_buyout_price = 700, unit_blizzard_bid = 700, count = 1, duration = 2, owner = 'Someone'})
  post.selected_item = {key = '5210:0', item_id = 5210, name = 'Blazing Wand', quality = 2, count = 1, max_stack = 1}
  post.update_auction_listings()
  -- 0.8 (Tyler, build 7: "Why are we separating these lines?"): gear is one row per price too
  n = 0
  local wand
  for _, row in ipairs(data or {}) do if not row.record.historical_value then n = n + 1; wand = row end end
  check('gear rows: one row per price, whatever the time left', n == 1 and wand.cols[1].value == 2)
  check('gear rows: the longest time left', wand and wand.record.duration == 4)
  post.record_auction({item_key = '5210:0', unit_buyout_price = 700, unit_blizzard_bid = 700, count = 1, duration = 3, owner = 'P'})
  post.update_auction_listings()
  n = 0
  for _, row in ipairs(data or {}) do if not row.record.historical_value then n = n + 1 end end
  check('gear rows: your own stay a row of their own', n == 2)
  rawset(post.buyout_listing, 'SetData', nil)
  post.selected_item = nil
  post.clear_auctions()
end)

try('post listing columns', function()
  local require = loadstring("select(2, ...) 'aux.test14'; return require")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local data
  rawset(post.buyout_listing, 'SetData', function(_, rows) data = rows end)
  post.clear_auctions()
  post.record_auction({item_key = '2589:0', commodity = true, unit_buyout_price = 40, count = 206, duration = 3, owner = 'Someone'})
  post.selected_item = {commodity = true, key = '2589:0', item_id = 2589, name = 'Linen Cloth', quality = 1, count = 20, max_stack = 20}
  post.update_auction_listings()
  check('post list has four columns', data and data[1] and #data[1].cols == 4)
  check('post list first column is units for sale', data and data[1] and data[1].cols[1].value == 206)
  rawset(post.buyout_listing, 'SetData', nil)
  post.selected_item = nil
end)

fire('AUCTION_HOUSE_CLOSED')
-- Posting gear: the server refuses a buyout that is not above the starting bid ("Internal auction
-- error"), so a bid equal to the buyout is left out and the item goes up for buyout only.
try('post item prices', function()
  local require = loadstring("select(2, ...) 'aux.test15'; return require")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  post.selected_item = {key = '5210:0', item_id = 5210, name = 'Blazing Wand', quality = 2, count = 1, max_stack = 1}
  local bid, buyout = post.item_post_prices(700, 700)
  check('bid equal to buyout: buyout only', bid == nil and buyout == 700)
  bid, buyout = post.item_post_prices(900, 700)
  check('bid above buyout: buyout only', bid == nil and buyout == 700)
  bid, buyout = post.item_post_prices(500, 700)
  check('bid below buyout is kept', bid == 500 and buyout == 700)
  bid, buyout = post.item_post_prices(500, 0)
  check('no buyout: bid only', bid == 500 and buyout == nil)
  bid, buyout = post.item_post_prices(0, 700)
  check('no starting bid: buyout only, as in Blizzard\'s sell frame', bid == nil and buyout == 700)

  -- the post itself sends no bid when it would equal the buyout
  local args
  local real_post, real_find = C_AuctionHouse.PostItem, post.find_item_location
  C_AuctionHouse.PostItem = function(...) args = {n = select('#', ...), ...} return false end
  post.find_item_location = function() return 'bag slot' end
  rawset(post.stack_count_input, 'GetNumber', function() return 1 end)
  rawset(post.duration_dropdown, 'GetIndex', function() return 2 end)
  post.set_unit_start_price(700)
  post.set_unit_buyout_price(700)
  post.post_auction()
  check('PostItem called for gear', args ~= nil)
  check('PostItem gets no bid when it equals the buyout', args and args[4] == nil and args[5] == 700)
  C_AuctionHouse.PostItem, post.find_item_location = real_post, real_find
  rawset(post.stack_count_input, 'GetNumber', nil); rawset(post.duration_dropdown, 'GetIndex', nil)
  post.selected_item = nil
end)

-- Filter Builder: aux's and/or/not post filter as a tree of groups and back, and in words
try('filter builder model', function()
  local require = loadstring("select(2, ...) 'aux.test16'; return require")('auxForever', addon)
  local filter_util = require 'aux.util.filter'
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local function roundtrip(str)
    local parsed = filter_util.parse_filter_string(str)
    return s.post_string(s.tree_from_post(parsed.post)), s.tree_from_post(parsed.post)
  end
  check('single condition', roundtrip('price/5g') == 'price/5g')
  local out, root = roundtrip('or/price/5g/percent/60')
  check('or at the top shows as Match Any', root.mode == 'or' and #root.items == 2)
  check('or at the top writes back with a count', out == 'or2/price/5g/percent/60')
  check('not on a condition', roundtrip('not/price/5g') == 'not/price/5g')
  out, root = roundtrip('price/5g/not/or2/seller/bob/left/30m')
  check('negated group is one item', #root.items == 2 and root.items[2].kind == 'group' and root.items[2].negated and root.items[2].mode == 'or')
  check('negated group writes back', out == 'price/5g/not/or2/seller/bob/left/30m')
  out = roundtrip('or/and2/profit/5g/percent/60/and3/bid-profit/5g/bid-percent/60/left/30m')
  check("Simon's example keeps its meaning", out == 'or2/and2/profit/5g/percent/60/and3/bid-profit/5g/bid-percent/60/left/30m')
  check('a bare and over everything is the same as the top level', roundtrip('and/price/5g/percent/60') == 'price/5g/percent/60')
  local words = s.post_words(s.tree_from_post(filter_util.parse_filter_string('price/5g/not/or2/seller/bob/left/30m').post))
  check('in words: not and or read out', words and words:find('NOT (', 1, true) and words:find(' OR ', 1, true) and words:find(' AND ', 1, true))
  local g = s.new_group('and')
  local c = s.new_condition('price'); c.value = 'abc'
  tinsert(g.items, c)
  tinsert(g.items, s.new_condition('utilizable'))
  check('an unfinished condition is left out', s.post_string(g) == 'utilizable')
  c.value = '1.5g'
  check('money is written the aux way', s.post_string(g) == 'price/1g 50s/utilizable')
  local empty_group = s.new_group('or')
  tinsert(g.items, empty_group)
  check('an empty group is left out', s.post_string(g) == 'price/1g 50s/utilizable')
  check('every post filter has a menu entry', (function()
    for key in pairs(filter_util.filters) do
      local found
      for _, info in ipairs(s.CONDITIONS) do if info.key == key then found = true end end
      if not found then return false end
    end
    return true
  end)())
end)

-- Favorites: an empty search bar saves nothing, and a search is saved once
try('favorites', function()
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local before = #s.favorite_searches
  check('empty search is not saved', s.add_favorite('') == 'empty' and s.add_favorite('   ') == 'empty' and #s.favorite_searches == before)
  check('a search is saved', s.add_favorite('copper ore/exact') == 'saved' and #s.favorite_searches == before + 1)
  check('the same search again is not', s.add_favorite('Copper Ore/exact') == 'duplicate' and #s.favorite_searches == before + 1)
  tremove(s.favorite_searches, 1)
end)

-- Settings: default auction length
try('auction length setting', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local buttons = a.auction_length_buttons
  check('three auction length buttons', buttons and #buttons == 3)
  buttons[3].__scripts.OnClick(buttons[3])
  check('choosing one sets the default length', a.account_data.post_duration == 3)
  buttons[2].__scripts.OnClick(buttons[2])
  check('and back', a.account_data.post_duration == 2)
end)

-- Filter Builder: rows follow the search bar, and every edit rewrites the search bar
try('filter builder ui', function()
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local function shown_rows()
    local list = {}
    for _, row in ipairs(s.builder_rows) do if row.__shown and row.item then tinsert(list, row) end end
    return list
  end
  local function find_row(fn) for _, row in ipairs(shown_rows()) do if fn(row.item) then return row end end end
  local function click(widget) widget.__scripts.OnClick(widget) end
  local function pick(value)
    for _, b in ipairs(s.builder_menu_buttons) do if b.__shown and b.value == value then click(b) return true end end
  end
  local text = function() return s.search_box:GetText() end

  s.search_box:SetText('price/5g/not/or2/seller/bob/left/30m')
  s.set_subtab(s.FILTER)
  local rows = shown_rows()
  check('rows: condition, group, two inside, two add rows', #rows == 6)
  check('first row is the price condition', rows[1].item.kind == 'cond' and rows[1].type_btn.__text == 'Price per item' and rows[1].value_box.__text == '5g')
  check('group row is negated and Any', rows[2].item.kind == 'group' and rows[2].item.node.negated and rows[2].item.node.mode == 'or')
  check('in words shown', tostring(s.builder_words_text.__text):find('NOT (', 1, true) ~= nil)
  check('loading does not rewrite the search bar', text() == 'price/5g/not/or2/seller/bob/left/30m')

  click(rows[1].not_btn)
  check('not switch writes not', text() == 'not/price/5g/not/or2/seller/bob/left/30m')
  click(find_row(function(i) return i.kind == 'cond' and i.node.filter == 'price' end).not_btn)

  local root_add = find_row(function(i) return i.kind == 'add' and i.group == s.get_builder_root() end)
  click(root_add.add_cond)
  check('condition menu lists every filter', #s.builder_menu_buttons >= 18)
  check('picking a condition adds a row', pick('percent'))
  local pct = find_row(function(i) return i.kind == 'cond' and i.node.filter == 'percent' end)
  check('new condition row', pct ~= nil)
  check('unfinished condition stays out of the search bar', text() == 'price/5g/not/or2/seller/bob/left/30m')
  pct.value_box:SetText('60')
  pct.value_box.change(pct.value_box, true)
  check('typing a value writes it', text() == 'price/5g/not/or2/seller/bob/left/30m/percent/60')

  local left = find_row(function(i) return i.kind == 'cond' and i.node.filter == 'left' end)
  click(left.value_btn)
  check('choice menu', pick('2h'))
  check('choice written', text():find('left/2h', 1, true) ~= nil)

  click(find_row(function(i) return i.kind == 'group' end).remove)
  check('removing a group removes its conditions', text() == 'price/5g/percent/60')
  click(s.root_any_button)
  check('Match any at the top', text() == 'or2/price/5g/percent/60')
  click(s.root_all_button)

  root_add = find_row(function(i) return i.kind == 'add' and i.group == s.get_builder_root() end)
  click(root_add.add_group)
  local inner_add = find_row(function(i) return i.kind == 'add' and i.group ~= s.get_builder_root() end)
  check('a new group has its own add row', inner_add ~= nil)
  click(inner_add.add_cond); pick('seller')
  local seller = find_row(function(i) return i.kind == 'cond' and i.node.filter == 'seller' end)
  check('condition added inside the group', seller and seller.item.depth == 1)
  seller.value_box:SetText('Bob'); seller.value_box.change(seller.value_box, true)
  check('a group with one condition is written without and/or', text() == 'price/5g/percent/60/seller/bob')

  s.search_box:SetText('price/3g')
  s.search_box.change(s.search_box, true)
  rows = shown_rows()
  check('typing in the search bar updates the builder', #rows == 2 and rows[1].value_box.__text == '3g')
  s.search_box:SetText('price')
  s.search_box.change(s.search_box, true)
  check('unreadable search bar text is explained', tostring(s.builder_words_text.__text):find('cannot', 1, true) ~= nil)
  check('and the rows stay as they were', #shown_rows() == 2)

  s.search_box:SetText('copper ore/exact;linen cloth')
  s.load_builder()
  click(s.root_any_button)
  check('other searches after ; are kept', text():find(';linen cloth', 1, true) ~= nil)

  local favorites = #s.favorite_searches
  click(s.builder_clear_button)
  check('Clear all empties the search bar', text() == '' and #s.get_builder_root().items == 0)
  click(s.builder_save_button)
  check('saving an empty search saves nothing', #s.favorite_searches == favorites)
  s.set_subtab(s.SAVED)
end)

-- Search tab: result count on the sub tab, summary line next to the sub tabs, magnifier in the search bar
try('search results summary', function()
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local plain = function(t) return ((tostring(t or '')):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  check('no summary without results', s.results_summary({records = {}}) == nil)
  local search = {records = {{item_key = 'a', count = 20, auction_count = 1}, {item_key = 'a', count = 1, auction_count = 6}, {item_key = 'a', count = 1000, auction_count = 6}}, complete = true, completed_at = time()}
  local text = s.results_summary(search)
  check('one item: price levels and units', text and text:find('3 price levels, 6,026 for sale', 1, true) ~= nil)
  local gear = {records = {{item_key = 'x', count = 1}, {item_key = 'x', count = 1}, {item_key = 'y', count = 1}}, complete = true, completed_at = time()}
  check('many items: items and units', s.results_summary(gear):find('^2 items, 3 for sale') ~= nil)
  check('sub tab number counts items', s.results_count(gear) == 2 and s.results_count(search) == 3)
  check('summary says when', text and text:find('searched just now', 1, true) ~= nil)
  search.active, search.complete = true, false
  check('summary while searching', s.results_summary(search):find('still searching', 1, true) ~= nil)
  check('one price level', s.results_summary({records = {{count = 5}}}):find('^1 price level, 5 for sale') ~= nil)

  s.set_subtab(s.RESULTS)
  local current = s.current_search()
  local saved = current.records
  current.records = {{item_key = 'a', count = 3}, {item_key = 'a', count = 2}}
  current.complete, current.completed_at, current.active = true, time(), false
  s.update_results_summary(true)
  check('result count on the sub tab', plain(s.search_results_button.__text) == 'Search Results  2')
  check('summary line shown on Results', s.results_summary_label.__text:find('2 price levels, 5 for sale', 1, true) ~= nil)
  s.set_subtab(s.SAVED)
  check('summary hidden on other sub tabs', s.results_summary_label.__text == '')
  check('count stays on the sub tab', plain(s.search_results_button.__text) == 'Search Results  2')
  current.records = saved
  s.update_results_summary(true)
  check('magnifier in the search bar', s.search_icon ~= nil)
end)

-- Post: trade goods are one listing on Forever, so one Quantity box, and Max is everything in the bags
try('post quantity', function()
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  post.selected_item = {commodity = true, key = '7076:0', item_id = 7076, name = 'Blood Shard', quality = 1, count = 29, max_stack = 10}
  post.quantity_update(true)
  check('Max is everything in the bags', post.stack_count_input.max_value == 29)
  post.layout_parameters(true)
  check('the box is called Quantity', post.stack_count_input.caption.__text == 'Quantity')
  post.update_item_configuration()
  check('no stack size box', post.stack_size_input.__shown == false)
  post.layout_parameters(false)
  check('gear keeps Count', post.stack_count_input.caption.__text == 'Count')
  post.selected_item = nil
end)

-- Filter Builder: the builder keeps its own groups when it opens again, and All / Any fades when
-- there is nothing to choose between
try('filter builder keeps groups', function()
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  s.set_subtab(s.FILTER)
  s.clear_builder()
  local root = s.get_builder_root()
  root.mode = 'or'
  local g = s.new_group('and')
  local c1 = s.new_condition('price'); c1.value = '20s'
  local c2 = s.new_condition('item'); c2.value = 'linen cloth'
  tinsert(g.items, c1); tinsert(g.items, c2); tinsert(root.items, g)
  s.sync_builder(); s.update_builder()
  check('root switch faded with one group', s.root_any_button.idle == true)
  check('group switch active with two conditions', (function()
    for _, row in ipairs(s.builder_rows) do if row.__shown and row.item and row.item.kind == 'group' then return row.all_btn.idle == false end end
  end)())
  s.set_subtab(s.RESULTS)
  s.set_subtab(s.FILTER)
  check('the group is still a group after leaving and coming back', s.get_builder_root().items[1] == g and s.get_builder_root().mode == 'or')
  local g2 = s.new_group('and'); local c3 = s.new_condition('price'); c3.value = '3s'; tinsert(g2.items, c3); tinsert(root.items, g2)
  s.sync_builder(); s.update_builder()
  check('root switch active with two groups', s.root_any_button.idle == false)
  s.clear_builder()
  s.set_subtab(s.SAVED)
end)

-- Blizzard UI button: the Blizzard window comes to the front, the button shows its state, and the
-- hooks are installed even when another addon loaded Blizzard's auction house first
try('blizzard ui button', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local raised, hooks = 0, {}
  rawset(AuctionHouseFrame, 'Raise', function() raised = raised + 1 end)
  rawset(AuctionHouseFrame, 'HookScript', function(self, script, fn) hooks[script] = (hooks[script] or 0) + 1 end)
  a.hook_blizzard_frame(); a.hook_blizzard_frame()
  check('the Blizzard window is hooked only once', hooks.OnShow == nil and hooks.OnHide == nil)
  local lit
  rawset(a.blizzard_button, 'SetBackdropBorderColor', function(self, r, g, b) local br, bg, bb = a.color.blizzard(); lit = (r == br and g == bg and b == bb) end)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  check('Blizzard window shown and brought to the front', a.blizzard_frame_shown() and raised == 1)
  check('button lit while shown', lit == true)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  check('second click hides it', not a.blizzard_frame_shown() and lit == false)
  -- the game laid the window out while it was shrunk: 100 times too far, off screen
  local placed
  rawset(AuctionHouseFrame, 'GetPoint', function() return 'TOPLEFT', UIParent, 'TOPLEFT', 1600, -11600 end)
  rawset(AuctionHouseFrame, 'SetPoint', function(self, p, r, rp, x, y) placed = {x, y} end)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  check('an off screen window comes back where the layout meant it', placed and placed[1] == 16 and placed[2] == -116)
  placed = nil
  rawset(AuctionHouseFrame, 'GetPoint', function() return 'TOPLEFT', UIParent, 'TOPLEFT', 16, -2 end)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  check('a window in place is left alone', placed == nil)
  a.blizzard_button.__scripts.OnClick(a.blizzard_button)
  rawset(AuctionHouseFrame, 'GetPoint', nil); rawset(AuctionHouseFrame, 'SetPoint', nil)
  rawset(AuctionHouseFrame, 'Raise', nil); rawset(AuctionHouseFrame, 'HookScript', nil)
  rawset(a.blizzard_button, 'SetBackdropBorderColor', nil)

  -- Blizzard's tabs are measured again at full size when its window is shown
  local resized = {}
  local function tab(name)
    local t = new_frame(name)
    t.__scripts.OnShow = function(self) tinsert(resized, self.__name) end
    return t
  end
  rawset(AuctionHouseFrame, 'Tabs', {tab('Buy'), tab('Sell'), tab('Auctions')})
  local auctions_frame = new_frame('AuctionsFrame')
  rawset(auctions_frame, 'Tabs', {tab('Auctions sub'), tab('Bids sub')})
  rawset(AuctionHouseFrame, 'AuctionsFrame', auctions_frame)
  a.set_blizzard_frame_shown(true)
  check('Blizzard tabs are resized at full size', #resized == 5 and resized[1] == 'Buy' and resized[5] == 'Bids sub')
  resized = {}
  a.set_blizzard_frame_shown(false)
  check('tabs are not resized while hidden', #resized == 0)
  rawset(AuctionHouseFrame, 'Tabs', nil); rawset(AuctionHouseFrame, 'AuctionsFrame', nil)
end)

-- Settings: scale from 70% to 150% that is kept, no explanation text; the resize corner anchors
-- the window by its top left corner before sizing
try('settings scale and resize corner', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local scaled
  rawset(a.frame, 'SetScale', function(self, x) scaled = x end)
  a.change_window_scale(1.2)
  check('scale applied and kept', scaled == 1.2 and a.account_data.scale == 1.2)
  a.scale_buttons[2].__scripts.OnClick(a.scale_buttons[2])
  check('plus steps 5%', math.abs(a.account_data.scale - 1.25) < .001)
  a.change_window_scale(5)
  check('never above 150%', a.account_data.scale == 1.5)
  a.change_window_scale(.1)
  check('never below 70%', a.account_data.scale == .7)
  a.change_window_scale(1)
  check('scale values are cleaned up', a.clean_scale(1.31) == 1.3 and a.clean_scale('x') == 1)
  a.change_window_scale(1)
  rawset(a.frame, 'SetScale', nil)
  -- Tyler, 0.4.1: one click on the resize corner could make the whole window jump diagonally.
  -- aux sizes the window itself now: only a drag changes the size, by exactly the drag.
  local f, grip = a.frame, a.resize_grip
  local w, h, sizes, anchored = 1200, 600, 0, nil
  local cx, cy, down = 500, 300, true
  rawset(f, 'GetWidth', function() return w end); rawset(f, 'GetHeight', function() return h end)
  rawset(f, 'SetWidth', function(_, v) w = v; sizes = sizes + 1 end); rawset(f, 'SetHeight', function(_, v) h = v; sizes = sizes + 1 end)
  rawset(f, 'SetSize', function(_, x, y) w, h = x, y; sizes = sizes + 1 end)
  rawset(f, 'GetLeft', function() return 100 end); rawset(f, 'GetTop', function() return 900 end)
  rawset(f, 'GetEffectiveScale', function() return 1 end)
  rawset(UIParent, 'GetEffectiveScale', function() return 1 end)
  rawset(UIParent, 'GetWidth', function() return 1920 end); rawset(UIParent, 'GetHeight', function() return 1080 end)
  rawset(f, 'SetPoint', function(_, point) anchored = point end)
  rawset(f, 'StartSizing', function() anchored = 'game sizing' end)
  G.GetCursorPosition = function() return cx, cy end
  G.IsMouseButtonDown = function() return down end
  grip.__scripts.OnMouseDown(grip, 'LeftButton')
  check('resize corner anchors the window by its top left', anchored == 'TOPLEFT')
  for _ = 1, 3 do grip.__scripts.OnUpdate(grip) end
  grip.__scripts.OnMouseUp(grip)
  check('a click on the resize corner changes nothing', sizes == 0 and w == 1200 and h == 600)
  check('the drag stops with the click', grip.__scripts.OnUpdate == nil)
  down = true
  grip.__scripts.OnMouseDown(grip, 'LeftButton')
  cx, cy = 560, 260
  grip.__scripts.OnUpdate(grip)
  check('a drag resizes by exactly the drag', w == 1260 and h == 640)
  cx, cy = 5000, -5000
  grip.__scripts.OnUpdate(grip)
  check('the window stays on screen', w == 1820 and h == 900)
  down = false
  grip.__scripts.OnUpdate(grip)
  check('releasing the mouse anywhere ends the drag', grip.__scripts.OnUpdate == nil)
  for _, k in ipairs{'GetWidth', 'GetHeight', 'SetWidth', 'SetHeight', 'SetSize', 'GetLeft', 'GetTop', 'GetEffectiveScale', 'SetPoint', 'StartSizing'} do rawset(f, k, nil) end
  for _, k in ipairs{'GetEffectiveScale', 'GetWidth', 'GetHeight'} do rawset(UIParent, k, nil) end
  G.GetCursorPosition, G.IsMouseButtonDown = nil, nil
end)

-- Search timing log (/aux debug): the summary says where a search's time went
try('search timing log', function()
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local t = scan.new_timing()
  t.items, t.event, t.cached, t.timeout, t.dropped = 400, 380, 18, 2, 3
  t.browse, t.answer, t.throttle, t.item_data = 2, 150, 10, 5
  t.slow = {{name = 'Ritual Sandals', seconds = 21}, {name = 'Seer\'s Pants', seconds = 2}}
  local lines = scan.timing_report(t, 200)
  check('total and per item', lines[1] == 'Search timing: 3m 20s for 400 items, 0.50s each')
  check('where the time went', lines[2] == 'Waiting: item list 2.0s, server answers 2m 30s, throttle 10.0s, item data 5.0s, other 33.0s')
  check('how answers came', lines[3] == 'Answers: 380 on time, 18 after the 1s fallback, 2 timed out (20s each), 3 dropped and resent')
  check('slowest items first', lines[4] == 'Slowest: Ritual Sandals 21.0s, Seer\'s Pants 2.0s')
  check('stopped searches say so', scan.timing_report(scan.new_timing(), 1, true)[1]:find('(stopped)', 1, true) ~= nil)
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local before = a.account_data.debug_timing
  SlashCmdList.AUX('debug')
  check('/aux debug switches it', a.account_data.debug_timing == not before)
  SlashCmdList.AUX('debug')
end)

-- The timing log during a real search run: an item whose answer never comes as an event is
-- counted as answered after the 1s fallback, and the summary prints when the search ends
try('search timing during a search', function()
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  local saved = {}
  for k, v in pairs{GetItemKeyInfo = function() return {isCommodity = false, itemName = 'Test Item'} end,
                    HasSearchResults = function() return true end, HasFullItemSearchResults = function() return true end,
                    GetNumItemSearchResults = function() return 0 end} do
    saved[k] = rawget(C_AuctionHouse, k); C_AuctionHouse[k] = v
  end
  local cached_saved = C_Item.IsItemDataCachedByID
  C_Item.IsItemDataCachedByID = function() return true end
  a.account_data.debug_timing = true
  local done
  scan.start{type = 'list', queries = {{blizzard_query = {}, item_keys = {{itemID = 4}}}}, on_complete = function() done = true end}
  for _ = 1, 40 do if done then break end tick() end
  a.account_data.debug_timing = false
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)
  for k in pairs(saved) do C_AuctionHouse[k] = saved[k] end
  C_Item.IsItemDataCachedByID = cached_saved
  local all = table.concat(printed, '\n')
  check('the search finished', done)
  check('summary printed after the search', all:find('Search timing:', 1, true) ~= nil and all:find('for 1 item,', 1, true) ~= nil)
  check('the 1s fallback is counted', all:find('0 on time, 1 after the 1s fallback', 1, true) ~= nil)
end)

-- /aux debug list: times the whole auction house's item list without opening items
try('item list measurement', function()
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  local saved = {}
  for k, v in pairs{GetBrowseResults = function() return {{itemKey = {itemID = 1}}, {itemKey = {itemID = 2}}, {itemKey = {itemID = 3}}} end,
                    HasFullBrowseResults = function() return true end} do
    saved[k] = rawget(C_AuctionHouse, k); C_AuctionHouse[k] = v
  end
  local real_send = C_AuctionHouse.SendBrowseQuery
  local sent = 0
  -- the game answers a browse query with an event a moment later (so the request has to wait)
  local answer_due
  C_AuctionHouse.SendBrowseQuery = function() sent = sent + 1; answer_due = true end
  scan.measure_item_list()
  for _ = 1, 30 do
    tick()
    if answer_due then
      answer_due = false
      for _, f in ipairs(frames) do
        if f.__events['AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'] and f.__scripts.OnEvent then
          f.__scripts.OnEvent(f, 'AUCTION_HOUSE_BROWSE_RESULTS_UPDATED')
        end
      end
    end
  end
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)
  for k in pairs(saved) do C_AuctionHouse[k] = saved[k] end
  C_AuctionHouse.SendBrowseQuery = real_send
  local all = table.concat(printed, '\n')
  check('one browse request sent', sent >= 1)
  check('the measurement is reported', all:find('Item list of the whole auction house: 3 items in', 1, true) ~= nil and all:find('(1 request)', 1, true) ~= nil)
  check('no false "did not answer"', all:find('did not answer', 1, true) == nil)
end)


-- 0.3: a fake auction house that answers a moment after each request, as the game does
local function fake_ah(items)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local pending = {}
  local by_id = {}
  for _, it in ipairs(items) do by_id[it.id] = it end
  -- it.full_name: gear with a random ending, listed under its full name ("Bear Chest of the Bear")
  -- while the item's own name (GetItemInfo) is the plain one (0.8.2 test of FB-025)
  local function link(it, full) return '|cff1eff00|Hitem:' .. it.id .. '::::::' .. (it.suffix or 0) .. ':0|h[' .. (full and it.full_name or it.name) .. ']|h|r' end
  local browses = 0
  set(C_AuctionHouse, 'SendBrowseQuery', function() browses = browses + 1; tinsert(pending, {'AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'}) end)
  set(C_AuctionHouse, 'HasFullBrowseResults', function() return true end)
  set(C_AuctionHouse, 'GetBrowseResults', function()
    local r = {}
    for _, it in ipairs(items) do
      if it.qty > 0 then tinsert(r, {itemKey = {itemID = it.id, itemSuffix = it.suffix or 0, itemLevel = 0}, totalQuantity = it.qty, minPrice = it.min, containsOwnerItem = false}) end
    end
    return r
  end)
  set(C_AuctionHouse, 'GetItemKeyInfo', function(key) local it = by_id[key.itemID]; return it and {itemID = it.id, itemName = it.full_name or it.name, quality = it.quality or 2, iconFileID = 1, isCommodity = it.commodity or false} end)
  set(C_AuctionHouse, 'GetItemKeyRequiredLevel', function(key) return by_id[key.itemID].req or 1 end)
  set(C_AuctionHouse, 'SendSearchQuery', function(key)
    local it = by_id[key.itemID]
    if it.commodity then tinsert(pending, {'COMMODITY_SEARCH_RESULTS_UPDATED', it.id}) else tinsert(pending, {'ITEM_SEARCH_RESULTS_UPDATED', key}) end
  end)
  set(C_AuctionHouse, 'HasSearchResults', function() return true end)
  set(C_AuctionHouse, 'HasFullItemSearchResults', function() return true end)
  set(C_AuctionHouse, 'HasFullCommoditySearchResults', function() return true end)
  set(C_AuctionHouse, 'GetNumItemSearchResults', function(key) return by_id[key.itemID].qty > 0 and #by_id[key.itemID].auctions or 0 end)
  set(C_AuctionHouse, 'GetNumCommoditySearchResults', function(id) return by_id[id].qty > 0 and #by_id[id].auctions or 0 end)
  set(C_AuctionHouse, 'GetItemSearchResultInfo', function(key, i)
    local it = by_id[key.itemID]; local a = it.auctions[i]
    return {itemKey = key, itemLink = link(it, true), auctionID = it.id * 100 + i, quantity = a.qty or 1, buyoutAmount = a.buyout, minBid = a.bid or 0, bidAmount = 0,
      owners = {a.own and 'player' or 'Seller'}, totalNumberOfOwners = a.sellers or 1, containsOwnerItem = a.own or false, timeLeft = 3}
  end)
  set(C_AuctionHouse, 'GetCommoditySearchResultInfo', function(id, i)
    local a = by_id[id].auctions[i]
    return {itemID = id, quantity = a.qty or 1, unitPrice = a.buyout, auctionID = id * 100 + i, owners = {'Seller'}, numOwnerItems = 0, timeLeftSeconds = 3600, totalNumberOfOwners = a.sellers or 1}
  end)
  set(G, 'GetItemInfo', function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    local it = by_id[id]
    if not it then return end
    return it.name, link(it), it.quality or 2, 10, it.req or 1, 'Armor', 'Cloth', it.stack or 1, 'INVTYPE_CHEST', 1, it.sell or 0
  end)
  set(C_Item, 'IsItemDataCachedByID', function() return true end)
  -- the login walk over item numbers may reach these items at any moment and read their tooltip
  -- (when it gets there depends on how long the tests before ran)
  set(AuxTooltip, 'NumLines', function() return 0 end)
  local function deliver()
    local list = pending; pending = {}
    for _, p in ipairs(list) do fire(p[1], p[2]) end
  end
  local function run(n) for _ = 1, n or 40 do tick(); deliver() end end
  local function restore() for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end end
  return run, restore, function() return browses end
end

try('fast mode choice', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local require = loadstring("select(2, ...) 'aux.test30'; return require")('auxForever', addon)
  local filter = require 'aux.util.filter'
  local aux = require 'aux'
  check('price search is fast', search.fast_choice(filter.queries('herb/price/20s')) == true)
  check('percent and rarity are fast', search.fast_choice(filter.queries('robe/uncommon/percent/80')) == true)
  local fast, why = search.fast_choice(filter.queries('robe/seller/thrakk'))
  check('seller search reads every auction', fast == false and why == 'seller')
  fast, why = search.fast_choice(filter.queries('robe/left/30m'))
  check('time left search reads every auction', fast == false and why == 'time left')
  fast, why = search.fast_choice(filter.queries('robe/bid-price/1g'))
  check('bid search reads every auction', fast == false and why == 'bid')
  -- 0.8.2 (FB-025): tooltip text is checked on the item list; only gear with an ending is read in full
  fast, why = search.fast_choice(filter.queries('robe/of the owl'))
  check('tooltip text search is fast', fast == true and why == nil)
  fast, why = search.fast_choice(filter.queries('linen cloth/exact'))
  check('one exact item reads every auction', fast == false and why == nil)
  aux.account_data.full_search = true
  check('Full reads every auction', search.fast_choice(filter.queries('herb/price/20s')) == false)
  aux.account_data.full_search = false
end)

local ROBES = function()
  return {
    {id = 101, name = 'Spellbinder Robe', min = 18500, qty = 3, sell = 3000, auctions = {{buyout = 18500, bid = 15000}, {buyout = 21000, bid = 18000}, {buyout = 25000, bid = 20000}}},
    {id = 102, name = 'Greenweave Robe', min = 6400, qty = 2, auctions = {{buyout = 6400}, {buyout = 7000}}},
    {id = 103, name = 'Pagan Robe', min = 22000, qty = 1, auctions = {{buyout = 22000}}},
  }
end

try('fast search', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local require = loadstring("select(2, ...) 'aux.test31'; return require")('auxForever', addon)
  local history = require 'aux.core.history'
  local run, restore = fake_ah(ROBES())
  search.frame:Show()
  search.update_mode(search.NORMAL_MODE)
  search.search_box:SetText('robe')
  search.execute(nil, false)
  run(40)
  local s = search.current_search()
  check('fast: the search finished', s.complete == true and s.fast == true)
  local rows = {}
  for _, r in ipairs(s.records) do rows[r.item_id] = r end
  check('fast: one row per item', #s.records == 3 and rows[101] and rows[101].fast)
  check('fast: a row has the lowest price and the units for sale', rows[101].unit_buyout_price == 18500 and rows[101].count * rows[101].auction_count == 3)
  check('fast: the row is named from the item list', rows[101].name == 'Spellbinder Robe' and rows[101].item_key == '101:0')
  check('fast: summary says fast', (search.results_summary(s) or ''):find('3 items, 6 for sale, fast', 1, true) ~= nil)
  check('fast: the list is not price history', history.value('101:0') == nil)
  search.open_item(s, rows[101])
  run(40)
  local robes, list_rows = 0, 0
  for _, r in ipairs(s.records) do
    if r.item_id == 101 then robes = robes + 1; if r.fast then list_rows = list_rows + 1 end end
  end
  check('fast: an opened item shows its auctions', robes == 3 and list_rows == 0)
  check('fast: the other items stay as list rows', (function() for _, r in ipairs(s.records) do if r.item_id == 102 then return r.fast end end end)())
  local selection = s.table:GetSelection()
  check('fast: the cheapest auction is selected for the buy bar', selection and selection.record.unit_buyout_price == 18500 and not selection.record.fast)
  check('fast: the opened item is expanded', s.table.expanded['101:0'] == true)
  check('fast: its auctions are price history', history.value('101:0') == 18500)

  -- a condition the list does not have: every auction is read, and the summary says why
  search.search_box:SetText('robe/seller/seller')
  search.execute(nil, false)
  run(60)
  s = search.current_search()
  check('full: a seller search reads every auction', s.fast == false and #s.records == 6 and not s.records[1].fast)
  check('full: summary says why', (search.results_summary(s) or ''):find('full (uses seller)', 1, true) ~= nil)
  search.frame:Hide()
  restore()
end)

try('live mode', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local run, restore, browses = fake_ah(ROBES())
  search.frame:Show()
  search.update_mode(search.NORMAL_MODE)
  search.search_box:SetText('robe')
  search.toggle_live()
  local s = search.current_search()
  check('live: turning Live on runs the search', search.mode == search.LIVE_MODE and s.mode == search.LIVE_MODE and s.active)
  tick()
  check('live: "Updating" during a round', search.live_status(s) == 'updating' and search.mode_button:GetText() == 'Updating')
  run(20)
  local status, seconds = search.live_status(s)
  check('live: a countdown after the round', status == 'waiting' and seconds >= 1 and seconds <= search.LIVE_INTERVAL and s.live_round == 1)
  check('live: the button counts down', search.mode_button:GetText():find('^Live %ds$') ~= nil)
  check('live: summary says when the next round is', (search.results_summary(s) or ''):find('live: updated just now, next in', 1, true) ~= nil)
  run(70)
  check('live: the next round runs after the countdown', s.live_round >= 2)
  search.pause()
  check('live: Pause shows Paused', search.live_status(s) == 'paused')
  search.update_live_button()
  check('live: the button says Paused', search.mode_button:GetText() == 'Paused')
  check('live: Resume says Resume live', search.resume_button:GetText() == 'Resume live' and search.resume_button.__shown)
  local round = s.live_round
  run(80)
  check('live: no rounds while paused', s.live_round == round)
  search.execute(nil, true)
  run(20)
  check('live: Resume carries on', s.live_round > round and s.active)
  search.hold_live()
  round = s.live_round
  run(80)
  check('live: held while on another tab, not paused', s.live_round == round and search.live_status(s) ~= 'paused')
  search.resume_held_live()
  run(20)
  check('live: carries on when back on the tab', s.live_round > round)
  -- Tyler, 0.4.1: a live round during a trade good's price quote ended it with "Internal auction
  -- error"; live rounds wait while the buy bar is buying, and are held, not paused
  local live_req = loadstring("select(2, ...) 'aux.test50'; return require")('auxForever', addon)
  local live_bar = live_req 'aux.gui.buy_bar'
  local real_busy = live_bar.busy
  rawset(live_bar, 'busy', function() return true end)
  tick()
  round = s.live_round
  run(80)
  check('live: no round while buying', s.live_round == round and search.live_status(s) ~= 'paused')
  rawset(live_bar, 'busy', real_busy)
  run(30)
  check('live: rounds go on after the purchase', s.live_round > round)
  search.toggle_live()
  check('live: turning Live off stops it and keeps the results', s.mode == search.NORMAL_MODE and not s.active and #s.records > 0)
  local sent = browses()
  run(80)
  check('live: no more rounds once off', browses() == sent)
  search.update_live_button()
  check('live: the button says Live again', search.mode_button:GetText() == 'Live')
  -- Tyler, 0.4.1: a new search while Live is on (a saved recipe search) ends Live and runs
  search.search_box:SetText('robe')
  search.toggle_live()
  run(20)
  local old = search.current_search()
  local addon_aux = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  addon_aux.account_data.full_search = true
  rawset(AuxTooltip, 'NumLines', function() return 0 end)
  search.set_filter('spellbinder robe/exact;greenweave robe/exact')
  search.execute()
  local new = search.current_search()
  check('live: a new search ends Live', search.mode == search.NORMAL_MODE and new ~= old and new.mode == search.NORMAL_MODE)
  run(60)
  check('live: the new search runs', #new.records > 0 and not old.active)
  sent = browses()
  run(80)
  check('live: the old search does not go on', browses() == sent)
  addon_aux.account_data.full_search = false
  rawset(AuxTooltip, 'NumLines', nil)
  -- the item data this search loaded is not left for later tests
  for _, it in ipairs(ROBES()) do
    addon_aux.account_data.items[it.id] = nil
    addon_aux.account_data.item_ids[strlower(it.name)] = nil
  end
  search.frame:Hide()
  restore()
end)

-- daland, 0.7 (FB-014): a search found no Tigerstrike Mantle where Auctionator found 7. An item
-- the game had not loaded within 3 seconds was skipped without a word.
try('search: items the game loads late are waited for, unread items are reported', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local addon_aux = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local items = ROBES()
  tinsert(items, {id = 104, name = 'Tigerstrike Robe', min = 5000, qty = 1, auctions = {{buyout = 5000}}})
  local run, restore = fake_ah(items)
  -- Pagan Robe loads 4 seconds after it is first asked for; Tigerstrike Robe never loads
  local asked = {}
  local function loaded(id)
    asked[id] = asked[id] or clock
    if id == 104 then return false end
    return id ~= 103 or clock - asked[id] >= 4
  end
  local real_info = GetItemInfo
  rawset(G, 'GetItemInfo', function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if id and not loaded(id) then return end
    return real_info(x)
  end)
  local real_cached = C_Item.IsItemDataCachedByID
  rawset(C_Item, 'IsItemDataCachedByID', function(id) return loaded(id) end)
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  addon_aux.account_data.full_search = true
  rawset(AuxTooltip, 'NumLines', function() return 0 end)

  search.frame:Show()
  search.update_mode(search.NORMAL_MODE)
  search.set_filter('robe')
  search.execute(nil, false)
  run(250)
  local s = search.current_search()
  local found = {}
  for _, r in ipairs(s.records) do found[r.item_id] = true end
  check('search: an item the game loads late is still found', s.complete and found[103] == true)
  local told = false
  for _, text in ipairs(printed) do if text:find('1 item could not be read in time', 1, true) then told = true end end
  check('search: an item that could not be read is reported', told)
  -- fast mode, the usual way a name search runs
  addon_aux.account_data.full_search = false
  printed = {}
  search.set_filter('robe')
  search.execute(nil, false)
  run(100)
  told = false
  for _, text in ipairs(printed) do if text:find('1 item could not be read in time', 1, true) then told = true end end
  check('search: fast mode reports it too', search.current_search().fast and told)

  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)
  rawset(G, 'GetItemInfo', real_info)
  rawset(C_Item, 'IsItemDataCachedByID', real_cached)
  addon_aux.account_data.full_search = false
  rawset(AuxTooltip, 'NumLines', nil)
  for _, it in ipairs(items) do
    addon_aux.account_data.items[it.id] = nil
    addon_aux.account_data.item_ids[strlower(it.name)] = nil
  end
  search.frame:Hide()
  restore()
end)

try('sniper deal rule', function()
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local reason, profit = sniper.judge(50, nil, 100, 0, 60, 50)
  check('below vendor price is a deal without history', reason == 'vendor' and profit == 50)
  check('a trivial profit below vendor price is not a deal', sniper.judge(50, nil, 100, 0, 60, 500) == nil)
  check('no deal against the usual price with under 3 days of history', sniper.judge(1000, 5000, 0, 2, 60, 500) == nil)
  reason, profit = sniper.judge(1000, 5000, 0, 3, 60, 500)
  check('a deal: 20% of usual, profit after the cut', reason == 'usual' and profit == 3750)
  check('not a deal above the percentage', sniper.judge(3100, 5000, 0, 5, 60, 500) == nil)
  check('not a deal under the minimum profit', sniper.judge(200, 600, 0, 5, 60, 500) == nil)
  local _, _, pct = sniper.judge(100, 50, 200, 5, 60, 0)
  check('the usual price is never below the vendor price', pct == 50)
end)

-- 0.6 build 9 (Tyler): today's Full scan counts toward the days; the Sniper warns about stale prices
try('sniper history notice', function()
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local d = h.today()
  h.write_record('301:0', {day = d, points = {{value = 100, day = d - 1, units = 5}, {value = 100, day = d - 2, units = 5}}})
  local _, days = h.value_and_complete_days('301:0')
  check('history: two past days of Full scans count two', days == 2)
  h.write_record('301:0', {day = d, market = 100, units = 5, low = 90, points = {{value = 100, day = d - 1, units = 5}, {value = 100, day = d - 2, units = 5}}})
  _, days = h.value_and_complete_days('301:0')
  check('history: a Full scan today counts as a third day', days == 3)

  local day = 24 * 60 * 60
  local now = 1000 * day
  local text, kind = sniper.history_notice(now, now - 3 * day, 5, true)
  check('notice: a Full scan three days ago warns', kind == 'stale' and text:find('3 days ago', 1, true) ~= nil)
  text, kind = sniper.history_notice(now, now - day, 5, true)
  check('notice: a Full scan yesterday with enough history says nothing', text == nil)
  text, kind = sniper.history_notice(now, now - 3600, 2, true)
  check('notice: too little history says how far along it is', kind == 'thin' and text:find('3 days of Full scans; you have 2 so far', 1, true) ~= nil)
  text = sniper.history_notice(now, now - 3600, 0, false)
  check('notice: before the first round it waits to know', text == nil)
  text, kind = sniper.history_notice(now, 0, 0, false)
  check('notice: never scanned says so at once', kind == 'thin')
  local src = io.open('tabs/sniper/frame.lua'):read('*a')
  check('empty message: the Sniper works best with fresh Full scan data (Tyler, build 9)', src:find('Sniper works best with fresh Full scan data.', 1, true) ~= nil)
end)

try('sniper round', function()
  local aux_require = loadstring("select(2, ...) 'aux.test32'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local function days(key, value)
    local d = h.today()
    -- three days of Full scans (a complete look counts the units listed)
    h.write_record(key, {day = d, points = {{value = value, day = d - 1, units = 10}, {value = value, day = d - 2, units = 10}, {value = value, day = d - 3, units = 10}}})
  end
  days('201:0', 2200); days('203:0', 600); days('204:0', 5000)
  -- the kilt was only seen today: a usual price, but not one to show
  h.write_record('202:0', {day = h.today(), low = 1500, points = {}})
  local items = {
    -- 0.8.2 (FB-036): the normal market (300 at 23s) sits above the deal; 12 at 85c and 29 at 90c
    -- alone would be a flat market, which is no longer a deal
    {id = 201, name = 'Kingsblood', commodity = true, min = 850, qty = 341, sell = 50, stack = 20, auctions = {{buyout = 850, qty = 12}, {buyout = 900, qty = 29}, {buyout = 2300, qty = 300}}},
    {id = 202, name = 'Ritual Kilt', min = 1500, qty = 1, sell = 2200, auctions = {{buyout = 1500}}},
    {id = 203, name = 'Wool Cloth', commodity = true, min = 210, qty = 80, sell = 33, auctions = {{buyout = 210, qty = 80}}},
    {id = 204, name = 'Bid Only Robe', min = 1000, qty = 1, sell = 0, auctions = {{buyout = 0, bid = 1000}}},
  }
  local run, restore = fake_ah(items)
  aux.set_tab(2)
  check('sniper: second tab', sniper.frame.__shown)
  sniper.start()
  run(60)
  check('sniper: a round completed', sniper.round >= 1)
  check('sniper: three days of Full scans, no notice', sniper.history_days >= 3 and (sniper.notice_label.__text or '') == '')
  local scanned = aux.account_data.replicate_time
  aux.account_data.replicate_time = time() - 4 * 24 * 60 * 60
  local sets = 0
  local set_text = sniper.notice_label.SetText
  rawset(sniper.notice_label, 'SetText', function(self, t) sets = sets + 1; return set_text(self, t) end)
  sniper.update_controls(); sniper.update_controls()
  check('sniper: a stale Full scan shows the warning and its button, drawn once', (sniper.notice_label.__text or ''):find('4 days ago', 1, true) ~= nil and sniper.notice_button.__shown == true and sets == 1)
  aux.account_data.replicate_time = scanned
  sniper.update_controls()
  rawset(sniper.notice_label, 'SetText', nil)
  check('sniper: a fresh Full scan hides it again', sniper.notice_button.__shown == false)
  local found = {}
  for _, deal in ipairs(sniper.deals) do found[deal.name] = deal end
  check('sniper: a trade good under its usual price', found.Kingsblood and found.Kingsblood.deal_reason == 'usual' and found.Kingsblood.unit_buyout_price == 850 and found.Kingsblood.deal_percent == 39)
  check('sniper: below vendor price', found['Ritual Kilt'] and found['Ritual Kilt'].deal_reason == 'vendor' and found['Ritual Kilt'].deal_profit == 700)
  check('sniper: no usual price shown without enough history', found['Ritual Kilt'].deal_usual == nil and found.Kingsblood.deal_usual == 2200)
  check('sniper: too little profit is not a deal', not found['Wool Cloth'])
  check('sniper: a bid shown as the lowest price is not a deal', not found['Bid Only Robe'])
  check('sniper: deals are in the table', #sniper.listing.records == 2)
  check('sniper: a commodity deal keeps its tiers to buy', found.Kingsblood.deal_tiers and #found.Kingsblood.deal_tiers == 2)
  items[2].qty = 0
  run(40)
  check('sniper: a deal that sold shows as gone', found['Ritual Kilt'].deal_gone == true and not found.Kingsblood.deal_gone)
  check('sniper: the count says how many are left and gone', sniper.deals_count(sniper.shown_deals()) == '1 to buy, 1 gone')
  -- Tyler, 0.4.1: deals that sold go to the bottom of the table
  local function shown_order()
    local out = {}
    for _, info in ipairs(sniper.listing.rowInfo) do tinsert(out, info.children[1].record) end
    return out
  end
  found.Kingsblood.deal_found, found['Ritual Kilt'].deal_found = 100, 200 -- the gone one is newer
  sniper.update_deals()
  local order = shown_order()
  check('sniper: a deal that sold sorts below the ones to buy', #order == 2 and not order[1].deal_gone and order[2].deal_gone)
  -- Tyler, 0.4 build 2: after a few rounds every deal vanished from the table, then came back. The
  -- game had dropped the items' data for a moment, and a deal without item data was hidden.
  local real_info = G.GetItemInfo
  G.GetItemInfo = function() end
  sniper.update_deals()
  check('sniper: deals stay listed while the game reloads item data', #sniper.listing.records == 2 and sniper.deals_count(sniper.shown_deals()) == '1 to buy, 1 gone')
  G.GetItemInfo = real_info
  sniper.update_deals()
  aux.account_data.sniper_profit = 800
  sniper.settings_changed()
  check('sniper: a gone deal under the current rule is hidden', #sniper.listing.records == 1 and sniper.listing.records[1].name == 'Kingsblood')
  aux.account_data.sniper_profit = 500
  sniper.settings_changed()
  -- buying a deal from the buy bar: the cheapest units first, never above the price shown
  local bar = aux_require 'aux.gui.buy_bar'
  sniper.listing:SetSelectedRecord(found.Kingsblood)
  -- the deal is read again first (Tyler, 0.4.1: trade good buys failed on old deals)
  run(10)
  check('sniper: a trade good deal is read again when selected', sniper.refreshing == nil and #found.Kingsblood.deal_tiers == 2)
  check('sniper: the buy bar offers the deal', bar.primary_label():find('^Buy 20 for') ~= nil)
  bar.primary_click()
  fire('COMMODITY_PRICE_UPDATED', 900, 17400)
  tick()
  check('sniper: the server price is confirmed only after a click', bar.primary_label():find('^Confirm') ~= nil)
  bar.primary_click()
  fire('COMMODITY_PURCHASE_SUCCEEDED')
  tick()
  check('sniper: once its price is bought up the deal shows as bought', found.Kingsblood.deal_bought == true and found.Kingsblood.deal_gone == true)
  check('sniper: the rest stays to buy at the next price', #found.Kingsblood.deal_tiers == 1 and found.Kingsblood.deal_tiers[1].count == 21)
  found.Kingsblood.deal_gone, found.Kingsblood.deal_bought = nil, nil
  sniper.listing:SetSelectedRecord()
  tick()
  aux.account_data.sniper_percent = 30
  sniper.settings_changed()
  check('sniper: a stricter rule hides deals that no longer pass', #sniper.listing.records == 1)
  aux.account_data.sniper_percent = 60
  sniper.settings_changed()
  sniper.ignore(found.Kingsblood)
  check('sniper: an ignored item is removed and remembered', sniper.ignored_count() == 1 and #sniper.shown_deals() == 1)
  run(40)
  local again
  for _, deal in ipairs(sniper.deals) do if deal.name == 'Kingsblood' then again = true end end
  check('sniper: an ignored item is not found again', not again)
  sniper.unignore_all()
  sniper.stop()
  local round = sniper.round
  run(60)
  check('sniper: no rounds after Stop', sniper.round == round)
  aux.set_tab(1)
  sniper.clear_deals()
  restore()
end)


-- Tyler, 0.4: memory grew from 8.6 to 26 MB over Sniper rounds. Judging an item must not unpack its
-- saved history again each round, nor touch history for items that have none.
try('sniper: judging items reuses the history cache', function()
  local req = loadstring("select(2, ...) 'aux.test42'; return require")('auxForever', addon)
  local persistence = req 'aux.util.persistence'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local d = h.today()
  h.write_record('401:0', {day = d, points = {{value = 500, day = d - 1, units = 4}, {value = 500, day = d - 2, units = 4}, {value = 500, day = d - 3, units = 4}}})
  local real_read, reads = persistence.read, 0
  rawset(persistence, 'read', function(...) reads = reads + 1; return real_read(...) end)
  local real_info = G.GetItemInfo
  G.GetItemInfo = function(id) return 'Thing', 'link', 2, 1, 1, 'Armor', 'Cloth', 1, '', 1, 77 end
  local usual, vendor, days = sniper.item_facts('401:0', 401)
  check('sniper facts: usual price, vendor price and days', usual == 500 and vendor == 77 and days == 3)
  reads = 0
  for _ = 1, 5 do sniper.item_facts('401:0', 401) end
  check('sniper facts: the saved history is not unpacked again', reads == 0)
  local real_new, built = h.new_record, 0
  h.new_record = function() built = built + 1; return real_new() end
  local u2, _, d2 = sniper.item_facts('402:0', 402)
  h.new_record = real_new
  check('sniper facts: an item without history reads and builds nothing', reads == 0 and built == 0 and u2 == nil and d2 == 0)
  rawset(persistence, 'read', real_read)
  G.GetItemInfo = real_info
end)

-- Tyler, 0.4: memory after a cleanup went from 8.1 MB at login to 16.4 MB after 23 Sniper rounds.
-- The Sniper may keep notes on each item once, but nothing may pile up round after round.
try('sniper: rounds keep no memory', function()
  local aux_require = loadstring("select(2, ...) 'aux.test43'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local items = {}
  for i = 1, 2000 do
    tinsert(items, {id = 5000 + i, name = 'Item ' .. i, min = 1000, qty = 3, sell = 10, auctions = {{buyout = 1000}}})
  end
  local run, restore = fake_ah(items)
  aux.set_tab(2)
  sniper.start()
  local r0 = sniper.round
  local live = {}
  for _ = 1, 20000 do
    run(1)
    local r = sniper.round - r0
    if (r == 2 or r == 8) and not live[r] and not sniper.active then
      -- some prices change every round, so items are judged again
      for i = r, 2000, 7 do items[i].min = items[i].min + 1 end
      collectgarbage('collect')
      live[r] = collectgarbage('count')
    end
    if r >= 8 and live[8] then break end
  end
  check('sniper memory: measured at rounds 2 and 8', live[2] and live[8])
  check('sniper memory: no growth from round 2 to round 8', live[2] and live[8] and live[8] - live[2] < 64)
  sniper.stop()
  aux.set_tab(1)
  restore()
end)

-- Tyler, 0.4: the first round at 1c profit played the sound about 40 times before any deal showed
try('sniper: one sound per burst, deals shown during the round, no timing lines', function()
  local aux_require = loadstring("select(2, ...) 'aux.test41'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local items = {}
  for i = 1, 6 do
    tinsert(items, {id = 300 + i, name = 'Cheap Thing ' .. i, min = 100, qty = 1, sell = 900, auctions = {{buyout = 100}}})
  end
  local run, restore = fake_ah(items)
  local sounds = 0
  local real_sound = G.PlaySound
  G.PlaySound = function() sounds = sounds + 1 end
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  aux.account_data.debug_timing = true
  aux.account_data.sniper_profit = 1
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  local seen_mid_round, status_mid_round
  for _ = 1, 200 do
    run(1)
    if sniper.round == r0 and sniper.checking and sniper.checking.done > 0 and sniper.checking.done < sniper.checking.total and #sniper.listing.records > 0 then
      seen_mid_round = true
      status_mid_round = select(2, sniper.status())
    end
    if sniper.round > r0 then break end
  end
  check('sniper: the round found every deal', #sniper.deals == 6)
  check('sniper: deals show in the table before the round ends', seen_mid_round)
  check('sniper: the status says how many possible deals are being checked', status_mid_round and status_mid_round:find('checking 6 possible deals') ~= nil)
  check('sniper: six deals in one round play the sound once', sounds == 1)
  local timing_lines = 0
  for _, text in ipairs(printed) do if text:find('Search timing') then timing_lines = timing_lines + 1 end end
  check('sniper: rounds print no timing lines with /aux debug on', timing_lines == 0)
  -- 2.5 seconds between rounds (Tyler, 0.4): the next round starts after the pause, not before
  local r1 = sniper.round
  run(23)
  check('sniper: no new round during the pause', sniper.round == r1 and not sniper.active)
  run(5)
  check('sniper: the next round starts after 2.5 seconds', sniper.active or sniper.round > r1)
  sniper.stop()
  aux.account_data.debug_timing = false
  aux.account_data.sniper_profit = 500
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)
  G.PlaySound = real_sound
  aux.set_tab(1)
  sniper.clear_deals()
  restore()
end)

try('an error does not leave a search stuck', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local run, restore = fake_ah(ROBES())
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  local real_results = C_AuctionHouse.GetBrowseResults
  rawset(C_AuctionHouse, 'GetBrowseResults', function() error('test error in the item list') end)
  -- like tick(), but the error raised for BugSack is expected here
  local raised = 0
  local function quiet_run(n)
    for _ = 1, n do
      clock = clock + 0.1
      for _, f in ipairs(frames) do
        if f.__shown and f.__scripts.OnUpdate then
          if not pcall(f.__scripts.OnUpdate, f, 0.1) then raised = raised + 1 end
        end
      end
      for _, f in ipairs(frames) do
        if f.__events['AUCTION_HOUSE_BROWSE_RESULTS_UPDATED'] and f.__scripts.OnEvent then
          pcall(f.__scripts.OnEvent, f, 'AUCTION_HOUSE_BROWSE_RESULTS_UPDATED')
        end
      end
    end
  end
  search.frame:Show()
  search.update_mode(search.NORMAL_MODE)
  search.search_box:SetText('robe')
  search.toggle_live()
  local s = search.current_search()
  quiet_run(20)
  check('the error still reaches BugSack', raised >= 1)
  check('the scan is not left running', not scan.is_scanning())
  check('live shows Paused instead of Updating forever', search.live_status(s) == 'paused')
  check('chat says the search stopped because of an error', table.concat(printed, '\n'):find('stopped because of an error', 1, true) ~= nil)
  rawset(C_AuctionHouse, 'GetBrowseResults', real_results)
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)

  -- "Updating" with no round running carries on by itself
  search.execute(nil, true)
  run(20)
  local round = s.live_round or 0
  s.live_next = nil
  run(40)
  check('a live search with no round running carries on', (s.live_round or 0) > round)
  search.toggle_live()
  search.frame:Hide()
  restore()
end)


try('reagent bag', function()
  local require = loadstring("select(2, ...) 'aux.test33'; return require")('auxForever', addon)
  local info = require 'aux.util.info'
  local real = C_Container.GetContainerNumSlots
  -- backpack with 2 slots, no bags, a reagent bag with 3 slots
  C_Container.GetContainerNumSlots = function(bag) return ({[0] = 2, [5] = 3})[bag] or 0 end
  local slots = {}
  for slot in info.inventory() do tinsert(slots, slot[1] .. ':' .. slot[2]) end
  C_Container.GetContainerNumSlots = real
  check('the reagent bag is read', table.concat(slots, ' ') == '0:1 0:2 5:1 5:2 5:3')
end)


-- Performance: nothing heavy runs every frame (Tyler, 2026-10-05: performance matters)
try('per-frame work', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  -- events: unused ones are unregistered after a kill, and idle frames do nothing
  local id = a.event_listener('AUX_TEST_EVENT', function() end)
  local event_frame
  for _, f in ipairs(frames) do if f.__events['AUX_TEST_EVENT'] then event_frame = f end end
  local unregistered = 0
  rawset(event_frame, 'UnregisterEvent', function(self, e) unregistered = unregistered + 1; self.__events[e] = nil end)
  for _ = 1, 5 do tick() end
  check('idle frames unregister nothing', unregistered == 0)
  a.kill_listener(id)
  tick()
  check('a killed listener\'s event is unregistered', unregistered == 1 and not event_frame.__events['AUX_TEST_EVENT'])
  tick()
  check('and only once', unregistered == 1)
  rawset(event_frame, 'UnregisterEvent', nil)
  -- with many listeners an idle frame stays cheap (aux compared every listener with every other
  -- listener on every frame, all game long)
  local ids = {}
  for i = 1, 400 do tinsert(ids, a.event_listener('AUX_TEST_EVENT_' .. (i % 20), function() end)) end
  local t0 = os.clock()
  for _ = 1, 30 do event_frame.__scripts.OnUpdate(event_frame) end
  check('an idle frame costs next to nothing', os.clock() - t0 < .05)
  for _, i in ipairs(ids) do a.kill_listener(i) end
  tick()

  -- Auctions tab: the list follows events, not a rebuild every second
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local real_scan, scans = auctions.scan_auctions, 0
  auctions.scan_auctions = function() scans = scans + 1 end
  auctions.frame:Show()
  for _ = 1, 30 do tick() end
  check('Auctions tab: no rebuild every second', scans <= 1)
  auctions.refresh = true
  tick()
  check('Auctions tab: rebuilt when the game says the list changed', scans == 2)
  auctions.frame:Hide()
  auctions.scan_auctions = real_scan

  -- Full scan button: restyled only when ready changes
  local styled = 0
  rawset(a.scan_button, 'SetBackdropColor', function() styled = styled + 1 end)
  for _ = 1, 30 do tick() end
  check('Full scan button is not restyled every frame', styled <= 1)
  rawset(a.scan_button, 'SetBackdropColor', nil)
end)


try('/aux memory', function()
  local slash = loadstring("select(2, ...) 'aux.core.slash'; return _M")('auxForever', addon)
  local updated
  G.UpdateAddOnMemoryUsage = function() updated = true end
  G.GetAddOnMemoryUsage = function(name) return name == 'auxForever' and 3584 or 0 end
  local report = slash.memory_report()
  check('memory is measured when asked', updated == true)
  check('memory report in MB with the history size', report:find('uses 3.5 MB of memory; price history for %d+ items') ~= nil)
  check('memory report says what is left after a cleanup', report:find('After a cleanup: 3.5 MB', 1, true) ~= nil)
  local detail = slash.memory_detail()
  check('memory detail: one line per store', #detail == 6 and detail[1]:find('^Sniper: %d+ items known') ~= nil and detail[6]:find('^Events: %d+ listeners') ~= nil)
  G.UpdateAddOnMemoryUsage, G.GetAddOnMemoryUsage = nil, nil
end)


try('auctions tab: undercut check', function()
  local aux = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local items = ROBES()
  tinsert(items, {id = 104, name = 'Native Robe', min = 3000, qty = 1, auctions = {{buyout = 3000}}})
  -- another seller at 6400 for the Greenweave Robe, the same price as ours
  local run, restore = fake_ah(items)
  local function link(id, name) return '|cff1eff00|Hitem:' .. id .. '::::::0:0|h[' .. name .. ']|h|r' end
  local owned = {
    {auctionID = 9001, itemKey = {itemID = 101, itemSuffix = 0, itemLevel = 0}, itemLink = link(101, 'Spellbinder Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = 20000},
    {auctionID = 9002, itemKey = {itemID = 102, itemSuffix = 0, itemLevel = 0}, itemLink = link(102, 'Greenweave Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = 6400},
    {auctionID = 9003, itemKey = {itemID = 103, itemSuffix = 0, itemLevel = 0}, itemLink = link(103, 'Pagan Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = 21000},
    {auctionID = 9004, itemKey = {itemID = 101, itemSuffix = 0, itemLevel = 0}, itemLink = link(101, 'Spellbinder Robe'), status = 1, quantity = 1, timeLeft = 3, buyoutAmount = 19000},
  }
  local saved = {}
  local function set(k, v) saved[k] = rawget(C_AuctionHouse, k); rawset(C_AuctionHouse, k, v) end
  set('GetNumOwnedAuctions', function() return #owned end)
  set('GetOwnedAuctionInfo', function(i) return owned[i] end)
  local cancels = {}
  set('CancelAuction', function(id) tinsert(cancels, id) end)
  set('CanCancelAuction', function() return true end)
  set('GetCancelCost', function() return 925 end)
  local searches = 0
  local real_search = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(...) searches = searches + 1; return real_search(...) end)
  local real_sold = Enum.AuctionStatus
  rawset(Enum, 'AuctionStatus', {Active = 0, Sold = 1})

  aux.set_tab(4) -- Search, Sniper, Post, Auctions
  check('auctions: fourth tab', auctions.frame.__shown)
  run(60)
  local by_id = {}
  for _, record in ipairs(auctions.listing.records) do by_id[record.auction_id] = record end
  local status, amount, lowest = auctions.auction_status(by_id[9001])
  check('auctions: a lower price from someone else is undercut, by how much', status == 'undercut' and amount == 1500 and lowest == 18500)
  status, amount = auctions.auction_status(by_id[9002])
  check('auctions: someone else at your price is tied', status == 'tied' and amount == 1)
  check('auctions: cheapest is lowest', auctions.auction_status(by_id[9003]) == 'lowest')
  check('auctions: sold is sold', auctions.auction_status(by_id[9004]) == 'sold')
  check('auctions: each item is read once', searches == 3)
  check('auctions: summary', auctions.summary_text(auctions.status_counts()) == '4 auctions: 1 undercut, 1 tied, 1 lowest, 1 sold')

  auctions.update_controls()
  check('auctions: the button says how many are undercut', auctions.cancel_undercut_button:GetText() == 'Cancel undercut (1)')
  check('auctions: it says which one is next', auctions.next_label:GetText():find('Next: Spellbinder Robe', 1, true) ~= nil)
  auctions.cancel_next_undercut()
  check('auctions: Cancel undercut cancels the undercut one', #cancels == 1 and cancels[1] == 9001)
  -- 0.7.1 (FB-016): not "Cancelled" before the auction house says so
  check('auctions: it says cancelling until the auction house confirms', auctions.auction_status(by_id[9001]) == 'cancelling')
  fire('AUCTION_CANCELED', 9001)
  check('auctions: and cancelled once it does', auctions.auction_status(by_id[9001]) == 'cancelled')
  auctions.cancel_next_undercut()
  check('auctions: tied and lowest auctions are left alone', #cancels == 1)

  -- opening the tab again soon does not read the prices again
  aux.set_tab(1); aux.set_tab(4)
  run(20)
  check('auctions: no new check within two minutes', searches == 3)
  -- an auction posted since then is checked when the tab opens, without waiting two minutes
  tinsert(owned, {auctionID = 9005, itemKey = {itemID = 104, itemSuffix = 0, itemLevel = 0}, itemLink = link(104, 'Native Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = 3500})
  aux.set_tab(1); aux.set_tab(4)
  run(40)
  check('auctions: a newly posted auction is checked at once', searches == 7)
  aux.set_tab(1)
  rawset(C_AuctionHouse, 'SendSearchQuery', real_search)
  for k, v in pairs(saved) do rawset(C_AuctionHouse, k, v) end
  rawset(Enum, 'AuctionStatus', real_sold)
  restore()
end)


-- daland, 0.7 (FB-015 and FB-016): the Auctions tab folded identical auctions into one row with
-- Qty 1 and hid other prices of an item; Cancel said "Cancelled, comes by mail" before the
-- auction house answered
try('auctions tab: every auction on its own row, cancels the auction house confirms', function()
  local aux = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local run, restore = fake_ah(ROBES())
  local function link(id, name) return '|cff1eff00|Hitem:' .. id .. '::::::0:0|h[' .. name .. ']|h|r' end
  local function robe(id, buyout) return {auctionID = id, itemKey = {itemID = 101, itemSuffix = 0, itemLevel = 0}, itemLink = link(101, 'Spellbinder Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = buyout} end
  -- three robes posted at once are three identical auctions on Forever
  local owned = {robe(9101, 20000), robe(9102, 20000), robe(9103, 20000), robe(9104, 25000),
    {auctionID = 9105, itemKey = {itemID = 102, itemSuffix = 0, itemLevel = 0}, itemLink = link(102, 'Greenweave Robe'), status = 0, quantity = 1, timeLeft = 3, buyoutAmount = 6400}}
  local saved = {}
  local function set(k, v) saved[k] = rawget(C_AuctionHouse, k); rawset(C_AuctionHouse, k, v) end
  set('GetNumOwnedAuctions', function() return #owned end)
  set('GetOwnedAuctionInfo', function(i) return owned[i] end)
  local cancels = {}
  set('CancelAuction', function(id) tinsert(cancels, id) end)
  set('CanCancelAuction', function() return true end)
  set('GetCancelCost', function() return 0 end)
  local real_status = Enum.AuctionStatus
  rawset(Enum, 'AuctionStatus', {Active = 0, Sold = 1})

  aux.set_tab(4)
  run(60)
  local listing = auctions.listing
  check('auctions: five auctions, five rows', #listing.records == 5 and listing.rowInfo.numDisplayRows == 5)
  local by_id = {}
  for _, record in ipairs(listing.records) do by_id[record.auction_id] = record end
  listing:SetSelectedRecord(by_id[9102])
  check('auctions: selecting one of the identical auctions selects that one', listing:GetSelection().record == by_id[9102])

  -- a cancel with no answer from the auction house
  local printed = {}
  local real_add = DEFAULT_CHAT_FRAME.AddMessage
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, text) tinsert(printed, text) end)
  check('auctions: the cancel is sent', auctions.cancel_auction(by_id[9102]) and cancels[1] == 9102)
  check('auctions: the row says cancelling', auctions.auction_status(by_id[9102]) == 'cancelling')
  check('auctions: the identical ones are untouched', auctions.auction_status(by_id[9101]) ~= 'cancelling' and auctions.auction_status(by_id[9103]) ~= 'cancelling')
  check('auctions: no second cancel while waiting', not auctions.cancel_auction(by_id[9102]) and #cancels == 1)
  run(120) -- 12 seconds, no answer
  check('auctions: with no answer the row shows its status again', auctions.auction_status(by_id[9102]) ~= 'cancelling' and auctions.auction_status(by_id[9102]) ~= 'cancelled')
  local told = false
  for _, text in ipairs(printed) do if text:find('did not confirm cancelling', 1, true) then told = true end end
  check('auctions: and the player is told', told)
  rawset(DEFAULT_CHAT_FRAME, 'AddMessage', real_add)

  -- a cancel whose auction leaves the list: the row goes, nothing is left waiting
  run(10)
  auctions.cancel_auction(by_id[9103])
  tremove(owned, 3)
  fire('OWNED_AUCTIONS_UPDATED')
  run(5)
  check('auctions: a cancelled auction leaves the table', #listing.records == 4 and next(auctions.cancelling) == nil)

  aux.set_tab(1)
  for k, v in pairs(saved) do rawset(C_AuctionHouse, k, v) end
  rawset(Enum, 'AuctionStatus', real_status)
  restore()
end)


try('post: next item after posting', function()
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local list = {
    {key = 'd:0', name = 'Delta', count = 3}, {key = 'a:0', name = 'Alpha', count = 2},
    {key = 'c:0', name = 'Charlie', count = 0}, {key = 'b:0', name = 'Bravo', count = 1},
  }
  check('post: the next item in the list', (post.next_item_after('Alpha', 'a:0', list) or {}).name == 'Bravo')
  check('post: items with none left are skipped', (post.next_item_after('Bravo', 'b:0', list) or {}).name == 'Delta')
  check('post: nothing after the last item', post.next_item_after('Delta', 'd:0', list) == nil)
end)


try('per-frame work 0.4', function()
  local require = loadstring("select(2, ...) 'aux.test40'; return require")('auxForever', addon)
  -- tooltips: whether an item can be auctioned is read from a hidden tooltip once per item
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local built = 0
  rawset(AuxTooltip, 'SetHyperlink', function() built = built + 1 end)
  rawset(AuxTooltip, 'NumLines', function() return 0 end)
  local item_info = {link = 'item:4000', quality = 1}
  tooltip.is_auctionable(4000, item_info); tooltip.is_auctionable(4000, item_info); tooltip.is_auctionable(4000, item_info)
  check('an item tooltip is scanned once, not on every hover', built == 1)
  rawset(AuxTooltip, 'SetHyperlink', nil); rawset(AuxTooltip, 'NumLines', nil)

  -- Post tab: the Post button is checked a few times a second, not every frame
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local real_validate, validations = post.validate_parameters, 0
  post.validate_parameters = function() validations = validations + 1 end
  post.refresh = false
  for _ = 1, 20 do post.on_update() end
  check('Post tab: not validated every frame', validations <= 1)
  post.validate_parameters = real_validate

  -- buy bar: its texts refresh ten times a second, not every frame
  local bar = require 'aux.gui.buy_bar'
  local refreshed = 0
  bar.show_item{record = {buyout_price = 100, bid_price = 50, count = 1, auction_count = 1}, name = 'Test', busy = function() refreshed = refreshed + 1 return false end, on_buy = function() end, on_bid = function() end}
  refreshed = 0
  for _ = 1, 20 do bar.frame.__scripts.OnUpdate(bar.frame) end
  check('buy bar: not refreshed every frame', refreshed <= 2)
  bar.clear()

  -- price history: a price that is not a new daily low does not unpack the saved history
  local history = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local real_data, reads = history.data, 0
  history.data = setmetatable({}, {__index = function(_, k) reads = reads + 1 return real_data[k] end, __newindex = function(_, k, v) real_data[k] = v end})
  local function auction(price) return {item_key = '4321:0', buyout_price = price, count = 1} end
  history.process_auction(auction(500))
  local after_first = reads
  for _ = 1, 10 do history.process_auction(auction(600)) end
  check('history: higher prices do not unpack the saved history', reads == after_first)
  history.process_auction(auction(400))
  check('history: a new low is still recorded', history.market_value('4321:0') == 400)
  history.data = real_data
end)


-- Tyler, 0.4.1: the buy bar offered 20 Ironweb Spider Silk on the Sniper where only 7 were a deal,
-- and the buy did not go through while rounds kept running
try('sniper: only deal-priced units to buy, rounds wait while buying', function()
  local aux_require = loadstring("select(2, ...) 'aux.test47'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local buy_bar = aux_require 'aux.gui.buy_bar'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local items = {
    {id = 501, name = 'Ironweb Spider Silk', commodity = true, stack = 20, min = 2499, qty = 25, sell = 2500,
      auctions = {{buyout = 2499, qty = 7}, {buyout = 2550, qty = 18}}},
  }
  local run, restore = fake_ah(items)
  aux.account_data.sniper_profit = 1
  sniper.clear_deals()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 200 do run(1) if sniper.round > r0 then break end end
  local deal = sniper.deals[1]
  local units = 0
  for _, tier in ipairs(deal and deal.deal_tiers or {}) do units = units + tier.count end
  check('sniper: only the units below vendor price can be bought', deal and units == 7)
  -- selected later, after someone bought 4 of the 7: the deal is read again with today's counts
  -- (0.8.2, FB-028: "later" is more than FRESH_SECONDS; a deal read just now is not read again)
  items[1].auctions[1].qty = 3
  deal.deal_read_at = GetTime() - sniper.FRESH_SECONDS - 1
  sniper.listing:SetSelectedRecord(deal)
  run(10)
  units = 0
  for _, tier in ipairs(deal.deal_tiers or {}) do units = units + tier.count end
  check('sniper: a selected trade good deal shows what is left', units == 3)
  sniper.listing:SetSelectedRecord()
  run(2)
  local real_busy = buy_bar.busy
  rawset(buy_bar, 'busy', function() return true end)
  local r1 = sniper.round
  run(60)
  check('sniper: no round while a purchase is under way', sniper.round == r1 and not sniper.active)
  check('sniper: the status says it waits', select(2, sniper.status()) == 'waits while you buy')
  rawset(buy_bar, 'busy', real_busy)
  run(60)
  check('sniper: rounds go on after the purchase', sniper.round > r1)
  sniper.stop()
  aux.account_data.sniper_profit = 500
  sniper.clear_deals()
  aux.set_tab(1)
  restore()
end)

-- 0.8.2 build 7 (H-009, H-010, Tyler: "very jarring that we stop the entire search when someone
-- highlights something"): a selected trade good or gone deal no longer stops the rounds. The rounds
-- do not open the selected deal again (it would be replaced and the selection dropped); a selected
-- trade good that sells says so in the buy bar.
try('H-010: rounds go on while a trade good or a gone deal is selected', function()
  local aux_require = loadstring("select(2, ...) 'aux.test49h'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local bar = aux_require 'aux.gui.buy_bar'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local items = {
    {id = 711, name = 'Bolt of Woolen Cloth', commodity = true, stack = 20, min = 100, qty = 10, sell = 200, auctions = {{buyout = 100, qty = 10}}},
    {id = 712, name = 'Massive Battle Axe', min = 2800, qty = 1, sell = 3036, auctions = {{buyout = 2800}}},
  }
  local run, restore = fake_ah(items)
  local searched = {}
  local real_send = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(key, ...) searched[key.itemID] = (searched[key.itemID] or 0) + 1; return real_send(key, ...) end)
  aux.account_data.sniper_profit = 1
  sniper.clear_deals()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 300 do run(1) if sniper.round > r0 then break end end
  local function deal_of(id) for _, d in ipairs(sniper.deals) do if d.item_id == id then return d end end end
  local cloth = deal_of(711)
  check('H-010 1: the trade good deal is found', cloth ~= nil)
  sniper.listing:SetSelectedRecord(cloth)
  run(2)
  local r1 = sniper.round
  run(120)
  check('H-010 1: rounds go on while a trade good is selected', sniper.round > r1)
  check('H-010 1: the status does not say it holds', sniper.status() == 'Watching')
  -- its price moves on the list (still a deal): the rounds leave it alone while it is selected
  items[1].min, items[1].auctions[1].buyout = 99, 99
  local opened = searched[711] or 0
  local r2 = sniper.round
  for _ = 1, 300 do run(1) if sniper.round > r2 + 1 then break end end
  check('H-010 1: the selected deal is not opened again', (searched[711] or 0) == opened)
  check('H-010 1: the selected deal stays the same row', deal_of(711) == cloth and sniper.listing:GetSelection() and sniper.listing:GetSelection().record == cloth)
  -- let go: the next round opens it (it was not marked as judged)
  sniper.click_deal(cloth)
  local r3 = sniper.round
  for _ = 1, 300 do run(1) if sniper.round > r3 + 1 then break end end
  check('H-010 1: let go, the next round opens it', (searched[711] or 0) > opened and deal_of(711) ~= cloth and ceil(deal_of(711).unit_buyout_price) == 99)
  -- selected, then sold out: the round marks it gone and the buy bar says so
  cloth = deal_of(711)
  cloth.deal_read_at = GetTime()
  sniper.listing:SetSelectedRecord(cloth)
  run(2)
  items[1].qty = 0
  local r4 = sniper.round
  for _ = 1, 300 do run(1) if sniper.round > r4 then break end end
  local _, line2 = bar.lines()
  check('H-010 1: a selected trade good that sold shows as gone in the buy bar', cloth.deal_gone == true and line2 == 'Gone: sold or relisted')
  local r5 = sniper.round
  run(120)
  check('H-010 1: rounds go on while a gone deal is selected', sniper.round > r5)
  sniper.listing:SetSelectedRecord()
  run(2)
  -- a gear deal still holds them (Buy takes it from the item's latest search)
  local axe = deal_of(712)
  axe.deal_read_at = GetTime() - sniper.FRESH_SECONDS - 1
  sniper.listing:SetSelectedRecord(axe)
  run(20)
  local r6 = sniper.round
  run(120)
  check('H-010 1: a selected gear deal still holds the rounds', sniper.round == r6 and sniper.status() == 'Holding')
  sniper.listing:SetSelectedRecord()

  sniper.stop()
  rawset(C_AuctionHouse, 'SendSearchQuery', real_send)
  aux.account_data.sniper_profit = 500
  sniper.clear_deals()
  aux.set_tab(1)
  restore()
end)

-- H-010, finding 3: while a deal is selected the rounds go on, and the table does not move it: it and
-- the rows above it keep their places (a row above that sells dims where it is), new deals go in
-- below it, whatever column the table is sorted by. Ignoring the selected deal selects nothing else.
try('H-010: the selected row keeps its place while deals come and go', function()
  local aux_require = loadstring("select(2, ...) 'aux.test49p'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local function cloth(id, name, price)
    return {id = id, name = name, commodity = true, stack = 20, min = price, qty = 10, sell = 500, auctions = {{buyout = price, qty = 10}}}
  end
  local items = {cloth(721, 'Linen Cloth', 100), cloth(722, 'Wool Cloth', 300), cloth(723, 'Silk Cloth', 200), cloth(724, 'Mageweave Cloth', 150)}
  items[4].qty = 0 -- listed later
  local run, restore = fake_ah(items)
  aux.account_data.sniper_profit = 1
  sniper.clear_deals()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 300 do run(1) if sniper.round > r0 then break end end
  for _, d in ipairs(sniper.deals) do d.deal_found = ({[721] = 300, [722] = 200, [723] = 100})[d.item_id] end
  sniper.update_deals()
  local function order()
    local names = {}
    for _, row in ipairs(sniper.listing.rowInfo) do tinsert(names, row.children[1].record.name) end
    return table.concat(names, ', ')
  end
  check('H-010 3: newest first before', order() == 'Linen Cloth, Wool Cloth, Silk Cloth')
  local wool = sniper.listing.rowInfo[2].children[1].record
  wool.deal_read_at = GetTime()
  sniper.listing:SetSelectedRecord(wool)
  run(2)
  -- a new deal turns up and the row above the selected one sells
  items[4].qty = 10
  items[1].qty = 0
  local r1 = sniper.round
  for _ = 1, 300 do run(1) if sniper.round > r1 then break end end
  run(10)
  check('H-010 3: the new deal goes in below the selected one, the sold one stays above', order() == 'Linen Cloth, Wool Cloth, Mageweave Cloth, Silk Cloth')
  check('H-010 3: the row above sold and is dimmed in place', sniper.listing.rowInfo[1].children[1].record.deal_gone == true)
  -- the sold one is listed again, cheaper: the new read takes its place, not a place below
  items[1].qty, items[1].min, items[1].auctions[1].buyout = 10, 90, 90
  local r2 = sniper.round
  for _ = 1, 300 do run(1) if sniper.round > r2 then break end end
  run(10)
  local linen = sniper.listing.rowInfo[1].children[1].record
  check('H-010 3: a row above read again keeps its place', order() == 'Linen Cloth, Wool Cloth, Mageweave Cloth, Silk Cloth' and not linen.deal_gone and ceil(linen.unit_buyout_price) == 90)
  -- sorted by price, the selected row and the ones above still do not move
  sniper.listing:SetSort(6)
  check('H-010 3: sorting by another column keeps them too', order():find('^Linen Cloth, Wool Cloth, ') ~= nil)
  sniper.listing:SetSort(-1)
  -- Tyler, build 7: the deal sound played but the new row showed only after letting go (the mouse
  -- rested on the row just clicked). The selected row and those above it do not move: the table
  -- may change while the mouse is on them; a row below it still waits.
  G.__geometry = {size = 29 + 19 * 5, edge = 100}
  sniper.listing.__scripts.OnSizeChanged(sniper.listing)
  G.__geometry = nil
  local rows = sniper.listing.rows
  for _, row in pairs(rows) do rawset(row, 'IsVisible', function() return true end) end
  sniper.update_deals()
  check('H-010 3: row 2 on screen is the selected one', rows[2] and rows[2].record == wool)
  rawset(sniper.frame.listing.list, 'IsMouseOver', function() return true end)
  rawset(rows[2], 'IsMouseOver', function() return true end)
  sniper.deals_changed = true
  run(10)
  check('build 8: new deals show while the mouse rests on the selected row', sniper.deals_changed == false)
  rawset(rows[2], 'IsMouseOver', nil)
  rawset(rows[3], 'IsMouseOver', function() return true end)
  sniper.deals_changed = true
  run(10)
  check('build 8: a row below the selected one does not move under the mouse', sniper.deals_changed == true)
  rawset(rows[3], 'IsMouseOver', nil)
  rawset(sniper.frame.listing.list, 'IsMouseOver', nil)
  for _, row in pairs(rows) do rawset(row, 'IsVisible', nil) end
  G.__geometry = {size = 0, edge = nil}
  sniper.listing.__scripts.OnSizeChanged(sniper.listing)
  G.__geometry = nil
  run(10)
  -- let go: the table sorts as usual again, newest first (found times set: both were found this second)
  for _, d in ipairs(sniper.deals) do if d.item_id == 721 then d.deal_found = 500 elseif d.item_id == 724 then d.deal_found = 400 end end
  sniper.click_deal(wool)
  run(10)
  check('H-010 3: let go, the table sorts as usual', order() == 'Linen Cloth, Mageweave Cloth, Wool Cloth, Silk Cloth')
  -- ignoring the selected deal selects no other deal
  local silk = sniper.listing.rowInfo[3].children[1].record
  silk.deal_read_at = GetTime()
  sniper.listing:SetSelectedRecord(silk)
  run(2)
  -- the rows on screen (the stubs have no window size and say no frame is visible; the next row
  -- was taken from the screen)
  G.__geometry = {size = 29 + 19 * 5, edge = 100}
  sniper.listing.__scripts.OnSizeChanged(sniper.listing)
  G.__geometry = nil
  for _, row in pairs(sniper.listing.rows) do rawset(row, 'IsVisible', function() return true end) end
  sniper.update_deals()
  sniper.ignore(silk)
  run(2)
  for _, row in pairs(sniper.listing.rows) do rawset(row, 'IsVisible', nil) end
  G.__geometry = {size = 0, edge = nil}
  sniper.listing.__scripts.OnSizeChanged(sniper.listing)
  G.__geometry = nil
  check('H-010 3: ignoring the selected deal selects no other deal', sniper.listing:GetSelection() == nil)
  aux.account_data.sniper_ignored['723:0:0:0:0'] = nil
  for key, name in pairs(aux.account_data.sniper_ignored) do if name == 'Silk Cloth' then aux.account_data.sniper_ignored[key] = nil end end
  -- at most MAX_DEALS: the oldest go, never a row kept in place
  local real = {}
  for i, d in ipairs(sniper.deals) do real[i] = d end
  aux.wipe(sniper.deals)
  for i = 1, sniper.MAX_DEALS + 1 do tinsert(sniper.deals, {deal_key = 'k' .. i}) end
  sniper.deals[1].row_pin = 1
  sniper.trim_deals()
  check('H-010 3: trimming keeps a row kept in place', #sniper.deals == sniper.MAX_DEALS and sniper.deals[1].deal_key == 'k1' and sniper.deals[2].deal_key == 'k3')
  aux.wipe(sniper.deals)
  for i, d in ipairs(real) do sniper.deals[i] = d end

  sniper.stop()
  aux.account_data.sniper_profit = 500
  sniper.clear_deals()
  aux.set_tab(1)
  restore()
end)

-- Tyler, 0.4.1 build 4: gear deals could not be bought from the Sniper, and the table moved under the
-- mouse. A selected gear deal is read again before it can be bought, and the rounds hold meanwhile.
try('sniper: a selected gear deal is checked again and the rounds hold', function()
  local aux_require = loadstring("select(2, ...) 'aux.test48'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local bar = aux_require 'aux.gui.buy_bar'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local items = {
    {id = 601, name = 'Massive Battle Axe', min = 2800, qty = 1, sell = 3036, auctions = {{buyout = 2800}}},
    {id = 602, name = 'Long Redwood Bow', min = 5500, qty = 1, sell = 5568, auctions = {{buyout = 5500}}},
  }
  local run, restore = fake_ah(items)
  local searched = {}
  local real_send = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(key, ...) searched[key.itemID] = (searched[key.itemID] or 0) + 1; return real_send(key, ...) end)
  aux.account_data.sniper_profit = 1
  sniper.clear_deals()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 300 do run(1) if sniper.round > r0 then break end end
  local axe
  for _, d in ipairs(sniper.deals) do if d.item_id == 601 then axe = d end end
  check('sniper gear: the deal is found', axe ~= nil)
  local before = searched[601] or 0
  -- 0.8.2 (FB-028): selected after FRESH_SECONDS, it is read again first
  axe.deal_read_at = GetTime() - sniper.FRESH_SECONDS - 1
  sniper.listing:SetSelectedRecord(axe)
  run(3)
  check('sniper gear: selecting it reads its item again', (searched[601] or 0) > before)
  run(10)
  check('sniper gear: then the buy bar offers it', bar.primary_label():find('^Buy for') ~= nil)
  local r1 = sniper.round
  run(80)
  check('sniper gear: no round while a deal is selected', sniper.round == r1 and not sniper.active)
  check('sniper gear: the status says it holds', sniper.status() == 'Holding')
  sniper.click_deal(axe)
  check('sniper gear: a click on the selected deal lets it go', sniper.listing:GetSelection() == nil)
  run(80)
  check('sniper gear: the rounds go on', sniper.round > r1)

  -- sold before the click: the deal shows as gone, nothing to buy
  local bow
  for _, d in ipairs(sniper.deals) do if d.item_id == 602 then bow = d end end
  items[2].qty = 0
  sniper.listing:SetSelectedRecord(bow)
  run(15)
  check('sniper gear: sold before the click shows as gone', bow and bow.deal_gone == true)
  sniper.listing:SetSelectedRecord()

  -- the table waits while the mouse is over its rows
  local before_records = sniper.listing.records
  rawset(sniper.frame.listing.list, 'IsMouseOver', function() return true end)
  sniper.deals_changed = true
  sniper.update(); run(2)
  check('sniper: the table does not change under the mouse', sniper.listing.records == before_records and sniper.deals_changed == true)
  rawset(sniper.frame.listing.list, 'IsMouseOver', nil)
  run(10)
  check('sniper: the table catches up when the mouse leaves', sniper.deals_changed == false)
  -- H-010, finding 3: the mouse on the buy bar under the rows (inside the tab's panel) does not
  -- stop the table: on the way to Buy, new deals waited
  rawset(sniper.frame.listing, 'IsMouseOver', function() return true end)
  sniper.deals_changed = true
  run(10)
  check('H-010 3: the table changes while the mouse is on the buy bar', sniper.deals_changed == false)
  rawset(sniper.frame.listing, 'IsMouseOver', nil)

  sniper.stop()
  rawset(C_AuctionHouse, 'SendSearchQuery', real_send)
  aux.account_data.sniper_profit = 500
  sniper.clear_deals()
  aux.set_tab(1)
  restore()
end)

-- Tyler, 0.6.0.1: the Post tab showed Scroll of Stamina from the last full scan (27 at 13s, split
-- by listing) and the real listings only after Refresh (42 at 13s). Picking an item now always
-- searches it, and the full scan no longer hands listings to the Post tab.
try('post: picking an item reads its listings fresh', function()
  local req = loadstring("select(2, ...) 'aux.test46'; return require")('auxForever', addon)
  local scan_exports = req 'aux.core.scan'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local real_start, searches, answer = scan_exports.start, 0, nil
  rawset(scan_exports, 'start', function(params) searches = searches + 1; answer = params end)
  post.clear_auctions()
  -- listings known from earlier (a full scan, an earlier pick): old prices
  post.record_auction({item_key = '4422:0', commodity = true, unit_buyout_price = 1300, count = 6, duration = 4, owner = 'Someone'})
  post.record_auction({item_key = '765:0', commodity = true, unit_buyout_price = 50, count = 5, duration = 2, owner = 'Someone'})
  local item = {key = '4422:0', item_id = 4422, commodity = true, name = 'Scroll of Stamina', quality = 1, count = 2, max_stack = 5}
  post.update_item(item)
  check('fresh listings: picking an item searches it', searches == 1)
  check('fresh listings: old listings are not shown', post.memory_counts() == 0)
  answer.on_auction({item_key = '4422:0', commodity = true, unit_buyout_price = 1200, count = 42, duration = 4, owner = 'Someone'})
  answer.on_complete()
  post.on_update()
  check('fresh listings: the price comes from the search', post.get_unit_buyout_price() == 1200)
  post.update_item(item)
  check('fresh listings: picking it again searches again', searches == 2)
  check('fresh listings: a full scan no longer feeds the Post tab', post.record_scanned_auction == nil)
  rawset(scan_exports, 'start', real_start)
  post.selected_item = nil
  post.clear_auctions()
end)

-- Tyler, 0.6.0.2: each pick searched the item's name first, then read its listings: two requests
-- where Blizzard's Sell tab makes one. An item in the bags is now read by its item key.
try('post: an item in the bags is read with one request', function()
  local req = loadstring("select(2, ...) 'aux.test47'; return require")('auxForever', addon)
  local scan_exports = req 'aux.core.scan'
  local info = req 'aux.util.info'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local real_start, real_inventory, real_container = scan_exports.start, info.inventory, info.container_item
  local real_key, real_key_info = rawget(C_AuctionHouse, 'GetItemKeyFromItem'), rawget(C_AuctionHouse, 'GetItemKeyInfo')
  local equipment = false
  rawset(C_AuctionHouse, 'GetItemKeyInfo', function() return {isEquipment = equipment} end)
  local params
  rawset(scan_exports, 'start', function(p) params = p end)
  local in_bags = true
  rawset(info, 'inventory', function()
    local done = not in_bags
    return function() if not done then done = true return {0, 1} end end
  end)
  rawset(info, 'container_item', function() return {item_key = '4422:0', price_key = '4422:0', auctionable = true, item_location = 'bag 0 slot 1'} end)
  rawset(C_AuctionHouse, 'GetItemKeyFromItem', function(location) return location == 'bag 0 slot 1' and {itemID = 4422, itemLevel = 0, itemSuffix = 0} or nil end)
  local item = {key = '4422:0', item_id = 4422, commodity = true, name = 'Scroll of Stamina', quality = 1, count = 2, max_stack = 5}
  post.update_item(item)
  local query = params and params.queries[1]
  check('one request: the item key from the bags is searched', query and query.item_keys and query.item_keys[1].itemID == 4422)
  check('one request: no name search first', query and query.blizzard_query == nil)
  in_bags, params = false, nil
  post.update_item(item)
  query = params and params.queries[1]
  check('one request: not in the bags, the name search is the fallback', params ~= nil and not (query and query.item_keys))
  -- Tyler, build 3: Merc Sword (gear with random suffixes) found nothing by its item key
  in_bags, equipment, params = true, true, nil
  post.update_item(item)
  query = params and params.queries[1]
  check('one request: gear keeps the name search', params ~= nil and not (query and query.item_keys))
  rawset(scan_exports, 'start', real_start)
  rawset(info, 'inventory', real_inventory); rawset(info, 'container_item', real_container)
  rawset(C_AuctionHouse, 'GetItemKeyFromItem', real_key); rawset(C_AuctionHouse, 'GetItemKeyInfo', real_key_info)
  post.selected_item = nil
  post.clear_auctions()
end)

-- Tyler, 0.4.1: prices read "7s", not "7s 00c"
try('money without zero parts', function()
  local req = loadstring("select(2, ...) 'aux.test45'; return require")('auxForever', addon)
  local money = req 'aux.util.money'
  local function plain(n) return money.to_string(n, true, nil, nil, true) end
  check('money: 7s', plain(700) == '7s')
  check('money: 1g 92s', plain(19200) == '1g 92s')
  check('money: 1g 5c', plain(10005) == '1g 05c')
  check('money: 1s 23c', plain(123) == '1s 23c')
  check('money: 0c', plain(0) == '0c')
  check('money: 3g', plain(30000) == '3g')
  check('money: negative', plain(-700) == '-7s')
  -- Tyler: in a column of copper prices "1s" broke the line-up; tables with copper keep all parts
  money.set_full_parts(true)
  check('money in a table with copper: 1s 00c', plain(100) == '1s 00c')
  money.set_full_parts(false)
  check('money outside tables stays short', plain(100) == '1s')
  local al = req 'aux.gui.auction_listing'
  local buyout_col
  for i, c in ipairs(al.search_columns) do
    if type(c.title) == 'table' and c.title[1]:find('^Auction Buyout') then buyout_col = i end
  end
  local rt = al.new(new_frame(), 19, al.search_columns)
  local function rec(key, price) return {count = 1, item_key = key, search_signature = key, name = key, requirement = 0, unit_buyout_price = price, buyout_price = price, unit_bid_price = 0, bid_price = 0, high_bid = 0, duration = 2} end
  rt:SetDatabase({rec('a', 47), rec('b', 100)})
  check('table with copper: every price keeps its copper', rt.has_copper == true)
  rt:SetDatabase({rec('c', 1200), rec('d', 1500)})
  check('table without copper: prices stay short', rt.has_copper == false)
  rt.has_copper = true
  rt:UpdateRows()
  check('the table leaves short prices for everything else', plain(100) == '1s')
end)

try('an empty search does not list the whole auction house', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local req = loadstring("select(2, ...) 'aux.test49'; return require")('auxForever', addon)
  local exports = req 'aux.core.scan'
  local real_start, started = exports.start, false
  rawset(exports, 'start', function() started = true end)
  search.search_box:SetText('  ')
  search.execute(nil, false)
  check('empty search: nothing is searched', not started)
  rawset(exports, 'start', real_start)
end)

try('per-frame work 0.4.1', function()
  local aux_require = loadstring("select(2, ...) 'aux.test44'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  -- Saved Searches: the Alt key is only checked while a favorite is being dragged
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local real_alt, alt_checks = G.IsAltKeyDown, 0
  G.IsAltKeyDown = function() alt_checks = alt_checks + 1 return false end
  search.dragged_search = nil
  for _ = 1, 20 do search.frame.saved.__scripts.OnUpdate(search.frame.saved) end
  check('Saved Searches: no Alt check every frame while nothing is dragged', alt_checks == 0)
  G.IsAltKeyDown = real_alt

  -- Bids tab: its buttons follow the selection a few times a second, not every frame
  local bids = loadstring("select(2, ...) 'aux.tabs.bids'; return _M")('auxForever', addon)
  local real_get, gets = bids.listing.GetSelection, 0
  rawset(bids.listing, 'GetSelection', function() gets = gets + 1 end)
  bids.refresh, bids.next_refresh = false, GetTime() + 100
  for _ = 1, 20 do bids.on_update() end
  check('Bids tab: buttons not updated every frame', gets <= 1)
  rawset(bids.listing, 'GetSelection', nil)

  -- aux's item list at login: numbers the game says are no item are not asked about, and a
  -- complete list is walked over many frames, not in one long one
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local real_items, real_unused = aux.account_data.items, aux.account_data.unused_item_ids
  aux.account_data.items, aux.account_data.unused_item_ids = {}, {}
  for id = 1, 30000 do aux.account_data.unused_item_ids[id] = true end
  local real_exists, real_info, asked = C_Item.DoesItemExistByID, G.GetItemInfo, {}
  rawset(C_Item, 'DoesItemExistByID', function(id) return id ~= 777 end)
  G.GetItemInfo = function(x) asked[tonumber(tostring(x):match('%d+'))] = true end
  -- a complete list: nothing to ask, still spread over frames
  info.item_walk_done = nil
  info.fetch_item_data()
  check('item list: a complete list is not walked in one frame', not info.item_walk_done)
  for _ = 1, 100 do tick() end
  check('item list: a complete list is walked within a few frames', info.item_walk_done == true)
  aux.account_data.unused_item_ids[777], aux.account_data.unused_item_ids[778] = nil, nil
  info.item_walk_done = nil
  info.fetch_item_data()
  for _ = 1, 100 do tick() end
  check('item list: done after some frames', info.item_walk_done == true)
  check('item list: a number that is no item is not asked about', not asked[777] and asked[778])
  local known, _, _, done = info.item_list_progress()
  check('item list: progress for /aux memory', known == 0 and done == true)
  rawset(C_Item, 'DoesItemExistByID', real_exists)
  G.GetItemInfo = real_info
  aux.account_data.items, aux.account_data.unused_item_ids = real_items, real_unused
end)

try('recipe search', function()
  local aux = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local shortcut = loadstring("select(2, ...) 'aux.core.shortcut'; return _M")('auxForever', addon)
  check('recipe link: enchant', search.recipe_id_from_link('|cffffd000|Henchant:12046|h[Tailoring: Simple Kilt]|h|r') == 12046)
  check('recipe link: spell', search.recipe_id_from_link('|Hspell:12046|h[x]|h') == 12046)
  check('an item link is not a recipe', search.recipe_id_from_link('|Hitem:2589::::::0:0|h[Linen Cloth]|h') == nil)

  -- a made-up recipe: one robe from three of another robe and one of a third
  local schematic = {name = 'Robe Kit', outputItemID = 101, quantityMin = 1, reagentSlotSchematics = {
    {reagents = {{itemID = 102}}, quantityRequired = 3, required = true},
    {reagents = {{itemID = 103}}, quantityRequired = 1, required = true},
    {reagents = {{itemID = 104}}, quantityRequired = 1, required = false},
  }}
  G.C_TradeSkillUI = {GetRecipeSchematic = function(id) return id == 12046 and schematic or nil end}
  local parts = search.recipe_parts(12046)
  check('recipe: the item it makes', parts.output.item_id == 101 and parts.output.count == 1)
  check('recipe: required materials only', #parts.reagents == 2 and parts.reagents[1].count == 3)

  local run, restore = fake_ah(ROBES())
  search.update_mode(search.NORMAL_MODE)
  local was_shown = aux.frame.__shown
  aux.frame.__shown = true
  shortcut.on_modified_click('|cffffd000|Henchant:12046|h[Tailoring: Robe Kit]|h|r')
  check('recipe: a plain click on a recipe does nothing', search.search_box:GetText() ~= 'spellbinder robe/exact;greenweave robe/exact;pagan robe/exact')
  local real_alt = IsAltKeyDown
  G.IsAltKeyDown = function() return true end
  shortcut.on_modified_click('|cffffd000|Henchant:12046|h[Tailoring: Robe Kit]|h|r')
  G.IsAltKeyDown = real_alt
  run(120)
  local s = search.current_search()
  check('recipe: Alt-click searches the item and its materials', search.search_box:GetText() == 'spellbinder robe/exact;greenweave robe/exact;pagan robe/exact')
  check('recipe: the search knows its recipe', s.recipe and s.recipe.name == 'Robe Kit')
  -- materials: 3 x 64s + 2g 20s = 4g 12s; sells for 1g 85s less 5% = 1g 75s 75c: a loss
  search.update_results_summary(true)
  -- the coin letters carry their own colors (0.6), so compare the text without color codes
  local function uncolored(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local summary = uncolored(search.recipe_label.__text)
  check('recipe: the line adds up the craft', summary:find('materials 4g 12s', 1, true) ~= nil and summary:find('sells 1g 75s 75c after cut', 1, true) ~= nil and summary:find('loss 2g 36s 25c', 1, true) ~= nil)
  -- Tyler, 0.4: the cost crowded the line next to the sub tabs and was cut off; it is in the bottom bar
  check('recipe: the cost is in the bottom bar, not next to the sub tabs', summary:find('Robe Kit', 1, true) ~= nil and not (search.results_summary(s) or ''):find('materials', 1, true))
  -- Tyler, 0.4: "materials ?" did not say which material had no price (Gray Dye, not for sale)
  local without = {}
  for _, r in ipairs(s.records) do if r.item_id ~= 103 then tinsert(without, r) end end
  local partial = uncolored(search.recipe_summary{recipe = s.recipe, records = without})
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local dye = info.item(103).name
  check('recipe: a material without a price is named', partial:find('materials 1g 92s + ' .. dye .. ' (no price)', 1, true) ~= nil)
  check('recipe: with a material missing the loss is a bound', partial:find('loss at least 16s 25c', 1, true) ~= nil)

  -- Tyler, 0.4: a saved recipe search showed as its raw text "[Colorful Kilt];[Bolt of Woolen Cloth];..."
  local recent = search.recent_searches[1]
  check('recipe: the recent entry keeps its recipe', recent.recipe and recent.recipe.name == 'Robe Kit')
  local rows
  rawset(search.recent_searches_listing, 'SetData', function(_, r) rows = r end)
  search.update_search_listings()
  rawset(search.recent_searches_listing, 'SetData', nil)
  local name = rows and rows[1].cols[1].value or ''
  check('recipe: Recent shows "Recipe  Robe Kit  (2 materials)"', name:find('Recipe', 1, true) and name:find('Robe Kit', 1, true) and name:find('(2 materials)', 1, true) and not name:find('exact', 1, true))
  check('recipe: the quick menu shows the last profit or loss', recent.last_profit == -23625 and search.quick_entry_detail(recent):find('^Loss ') ~= nil)
  check('recipe: saved as a favorite with its recipe', search.save_favorite(search.search_box:GetText()) == 'saved' and search.favorite_searches[1].recipe ~= nil)
  -- another search, then the favorite again: the cost line comes back
  search.set_filter('pagan robe/exact')
  search.execute(nil, false)
  run(60)
  check('recipe: a plain search has no recipe', search.current_search().recipe == nil)
  search.handlers.OnClick(search.favorite_searches_listing, {search = search.favorite_searches[1], index = 1}, nil, 'LeftButton')
  run(120)
  local again = search.current_search()
  check('recipe: running the saved recipe search shows the cost line again', again.recipe and again.recipe.name == 'Robe Kit' and (search.recipe_summary(again) or ''):find('materials', 1, true) ~= nil)
  tremove(search.favorite_searches, 1)

  -- the button on the profession window
  local form = new_frame()
  rawset(form, 'GetRecipeInfo', function() return {recipeID = 12046} end)
  G.ProfessionsFrame = {CraftingPage = {SchematicForm = form}}
  fire('ADDON_LOADED', 'Blizzard_Professions')
  check('recipe: a Search in aux button on the profession window', search.recipe_button ~= nil and search.recipe_button.__text == 'Search in aux')
  -- Forever build 70291 put Blizzard's Track Recipe checkbox at the bottom right, under the button
  local track = new_frame()
  rawset(track, 'GetPoint', function() return 'BOTTOMRIGHT' end)
  check('recipe: no checkbox, the button keeps the corner', search.recipe_button_spot(form) == 'corner')
  form.TrackRecipeCheckbox = track
  check('recipe: the button moves left of a Track Recipe checkbox on the right', search.recipe_button_spot(form) == 'track')
  rawset(track, 'GetPoint', function() return 'BOTTOMLEFT' end)
  check('recipe: a checkbox on the left leaves the button in its corner', search.recipe_button_spot(form) == 'corner')
  form.TrackRecipeCheckbox = nil
  search.search_box:SetText('')
  search.recipe_button.__scripts.OnClick(search.recipe_button)
  run(120)
  check('recipe: the button searches the shown recipe', search.search_box:GetText():find('spellbinder robe/exact', 1, true) == 1)
  fire('AUCTION_HOUSE_CLOSED')
  check('recipe: the button hides when the auction house closes', not search.recipe_button.__shown)
  G.ProfessionsFrame, G.C_TradeSkillUI = nil, nil
  aux.frame.__shown = was_shown
  restore()
end)


-- 0.5: better price data (docs/price-data.md, "Plan for 0.5")
try('price data 0.5', function()
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local persistence = loadstring("select(2, ...) 'aux.test50'; return require")('auxForever', addon) 'aux.util.persistence'
  local today = h.today()

  -- one very cheap auction among many barely moves the market price; today's lowest is that auction
  local records = {{item_key = '9001:0', buyout_price = 1, count = 1}}
  for i = 1, 20 do tinsert(records, {item_key = '9001:0', buyout_price = 5000, count = 5}) end
  for _, r in ipairs(records) do h.process_auction(r) end
  h.record_view_of(records)
  local market, units = h.today_market('9001:0')
  check('price: today\'s lowest is the cheap auction', h.market_value('9001:0') == 1)
  check('price: one cheap auction barely moves the market price', market and market >= 950 and units == 101)
  check('price: with no past days the usual price is the market price', h.value('9001:0') == market)

  -- build 4: in a deep market the market price stays near the cheapest real listings (Linen Cloth in
  -- build 3: 32c, the average of the cheapest fifth, while 296 were listed at 23c)
  local linen = {23, 296, 24, 196, 25, 73, 30, 361, 33, 326, 34, 274, 35, 292, 36, 1148, 37, 2628, 38, 2272, 39, 1597, 40, 1153}
  local deep = h.market_price(linen)
  check('price: a deep market\'s price is near its lowest listings', deep <= 25)
  check('price: one odd cheap auction does not set it', h.market_price({1, 1, 1000, 100}) == 1000)

  -- gear rows: an item search row is auction_count auctions of one item
  check('price: units of a gear row', h.record_units({count = 1, auction_count = 4}) == 4 and h.record_units({count = 20}) == 20)

  -- recent days outweigh old ones: three recent days at 100 against five days a month old at 200
  local points = {}
  for d = 1, 3 do tinsert(points, {day = today - d, value = 100}) end
  for d = 25, 29 do tinsert(points, {day = today - d, value = 200}) end
  h.write_record('9002:0', {day = today, points = points})
  check('price: recent days count more in the usual price', h.value('9002:0') == 100)

  -- a day ends: its market price becomes a past day, its lowest is kept only without a market price
  h.write_record('9003:0', {day = today - 1, low = 50, market = 80, units = 12, points = {}})
  local r = h.read_record('9003:0')
  check('price: a finished day keeps its market price and units', #r.points == 1 and r.points[1].value == 80 and r.points[1].units == 12 and r.points[1].day == today - 1 and r.low == nil)
  h.write_record('9004:0', {day = today - 1, low = 50, points = {}})
  check('price: a day without a complete view keeps its lowest', h.read_record('9004:0').points[1].value == 50)
  local many = {}
  for d = 1, 20 do tinsert(many, {day = today - 1 - d, value = d}) end
  h.write_record('9005:0', {day = today - 1, low = 7, points = many})
  check('price: at most 14 past days are kept', #h.read_record('9005:0').points == 14)

  -- the age of a price: seen today, or how many days since the newest day
  local _, age = h.value_and_age('9001:0')
  check('price: seen today', age == 0 and h.age_text(age) == 'today')
  _, age = h.value_and_age('9002:0')
  check('price: seen 1 day ago', age == 1 and h.age_text(age) == '1 day ago' and h.age_text(9) == '9 days ago')

  -- version 2 (0.4) lines are converted: every old daily low survives with its day
  local old_schema = {'tuple', '#', {next_push='number'}, {daily_min_buyout='number'}, {data_points={'list', ';', {'tuple', '@', {value='number'}, {time='number'}}}}}
  local function midnight_after(days_ago)
    local t = os.date('*t', os.time() - days_ago * 86400)
    t.hour, t.min, t.sec = 24, 0, 0
    return os.time(t)
  end
  local old_points = {}
  local old_values = {300, 310, 290, 900, 305}
  for i, v in ipairs(old_values) do tinsert(old_points, {value = v, time = midnight_after(i)}) end
  h.data['9006:0'] = persistence.write(old_schema, {next_push = midnight_after(0), daily_min_buyout = 280, data_points = old_points})
  local converted = h.read_record('9006:0')
  local all_kept = #converted.points == #old_values
  for i, v in ipairs(old_values) do
    all_kept = all_kept and converted.points[i].value == v and converted.points[i].day == today - i
  end
  check('price: a 0.4 line keeps every daily low with its day', all_kept)
  check('price: a 0.4 line keeps today\'s lowest', converted.low == 280 and converted.day == today)
  check('price: the converted usual price is the old one for steady prices', h.value('9006:0') == 305)
  h.write_record('9006:0', converted)
  check('price: the converted line is saved in the 0.5 form', not h.data['9006:0']:find('^%d%d%d%d%d%d%d%d'))
  -- a stale day 0.4 line (last scanned days ago) moves its lowest into the past days
  h.data['9007:0'] = persistence.write(old_schema, {next_push = midnight_after(3), daily_min_buyout = 444, data_points = {}})
  local stale = h.read_record('9007:0')
  check('price: a stale 0.4 day becomes a past day', #stale.points == 1 and stale.points[1].value == 444 and stale.points[1].day == today - 3)

  -- day numbers are calendar days
  check('price: day numbers', h.day_number_of(1970, 1, 1) == 0 and h.day_number_of(2000, 3, 1) == 11017 and h.day_number_of(2026, 10, 8) - h.day_number_of(2026, 10, 7) == 1)
end)

try('price data 0.5: full scan', function()
  local req = loadstring("select(2, ...) 'aux.test51'; return require")('auxForever', addon)
  local scan = req 'aux.core.scan'
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  -- two items, auctions mixed: item 9101 has 50 units at 100c and one at 5c, item 9102 3 at 700c
  local list = {}
  for i = 1, 10 do tinsert(list, {id = 9101, count = 5, buyout = 500}) ; if i == 4 then tinsert(list, {id = 9102, count = 1, buyout = 700}) end end
  tinsert(list, 3, {id = 9101, count = 1, buyout = 5})
  tinsert(list, {id = 9102, count = 2, buyout = 1400})
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local fired
  set(C_AuctionHouse, 'ReplicateItems', function() fired = true end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return #list end)
  set(C_AuctionHouse, 'GetReplicateItemInfo', function(i)
    local a = list[i + 1]
    return 'Item', 1, a.count, 1, true, 1, nil, 0, 0, a.buyout, 0, false, nil, 'Seller', nil, 0, a.id, true
  end)
  set(C_AuctionHouse, 'GetReplicateItemLink', function(i) return '|cffffffff|Hitem:' .. list[i + 1].id .. '::::::0:0|h[Item]|h|r' end)
  set(G, 'GetItemInfo', function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if id ~= 9101 and id ~= 9102 then return end
    return 'Item ' .. id, '|cffffffff|Hitem:' .. id .. '::::::0:0|h[Item]|h|r', 1, 10, 1, 'Trade Goods', 'Herb', 20, '', 1, 1
  end)
  local views = {}
  local real_view = h.record_view
  h.record_view = function(key, flat) views[key] = (views[key] or 0) + 1; return real_view(key, flat) end
  local done
  scan.start{type = 'list', queries = {{blizzard_query = {}}}, get_all = true, quiet = true, on_complete = function() done = true end}
  for _ = 1, 10 do tick() end
  fire('REPLICATE_ITEM_LIST_UPDATE')
  for _ = 1, 80 do tick() end
  h.record_view = real_view
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
  check('full scan: finished', fired and done)
  check('full scan: each item recorded once', views['9101:0'] == 1 and views['9102:0'] == 1)
  local m1, u1 = h.today_market('9101:0')
  local m2, u2 = h.today_market('9102:0')
  -- 9101: 51 units; the cheapest 5% is 3 units (one at 5c, two at 100c); the middle one is 100c
  check('full scan: market price and units, whatever the order', m1 == 100 and u1 == 51 and m2 == 700 and u2 == 3)
  check('full scan: today\'s lowest', h.market_value('9101:0') == 5)
end)

-- 0.5: a view that missed auctions (a request for more went unanswered) gives no market price
try('price data 0.5: incomplete view', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local run, restore = fake_ah{{id = 9201, name = 'Partial Robe', min = 900, qty = 2, auctions = {{buyout = 900}, {buyout = 950}}}}
  local real_full = C_AuctionHouse.HasFullItemSearchResults
  rawset(C_AuctionHouse, 'HasFullItemSearchResults', function() return false end)
  rawset(C_AuctionHouse, 'RequestMoreItemSearchResults', function() end)
  search.set_filter('partial robe/exact')
  search.execute(nil, false)
  run(400)
  rawset(C_AuctionHouse, 'HasFullItemSearchResults', real_full)
  rawset(C_AuctionHouse, 'RequestMoreItemSearchResults', nil)
  check('incomplete: today\'s lowest is still recorded', h.market_value('9201:0') == 900)
  check('incomplete: no market price', h.today_market('9201:0') == nil)
  restore()
end)

-- 0.5: the usual price in tooltips says how fresh it is
try('price data 0.5: tooltip age', function()
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local today = h.today()
  h.write_record('9301:0', {day = today, points = {{day = today - 3, value = 1000}}})
  h.write_record('9302:0', {day = today, points = {{day = today - 9, value = 1000}}})
  local function value_line(id)
    local lines = {}
    local tip = new_frame()
    rawset(tip, 'AddLine', function(_, text) tinsert(lines, text) end)
    tooltip.extend_tooltip(tip, '|cffffffff|Hitem:' .. id .. '::::::0:0|h[X]|h|r', 1)
    for _, l in ipairs(lines) do if l:find('^Value') then return l end end
  end
  rawset(AuxTooltip, 'NumLines', function() return 0 end)
  local fresh, old = value_line(9301) or '', value_line(9302) or ''
  rawset(AuxTooltip, 'NumLines', nil)
  check('tooltip: Value says when it was seen', fresh:find('seen 3 days ago', 1, true) ~= nil)
  check('tooltip: an old price is dimmed', old:find('seen 9 days ago', 1, true) ~= nil and old ~= fresh:gsub('3 days', '9 days'))
end)


-- FB-003 (Darkhorse): clicking Post did nothing and said nothing. Every way a post can end says
-- what happened, and a faded Post button says why.
try('FB-003: posts always say what happened', function()
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  -- a fake bag: slot 1 holds the item
  local bag = {}
  local function link(id) return '|cffffffff|Hitem:' .. id .. '::::::0:0|h[Sword]|h|r' end
  set(C_Container, 'GetContainerNumSlots', function(b) return b == 0 and #bag or 0 end)
  set(C_Container, 'GetContainerItemLink', function(b, i) return bag[i] and link(bag[i].id) end)
  set(C_Container, 'GetContainerItemInfo', function(b, i) local it = bag[i]; return it and {stackCount = it.count or 1, isLocked = it.locked or false, iconFileID = 1, hasLoot = false} end)
  set(C_Container, 'GetContainerItemDurability', function(b, i) local it = bag[i]; if it and it.max then return it.dur, it.max end end)
  set(G, 'GetItemInfo', function(x) local id = tonumber(tostring(x):match('item:(%d+)') or x); if id == 7001 then return 'Sword', link(7001), 2, 20, 1, 'Weapon', 'Sword', 1, 'INVTYPE_WEAPON', 1, 100 end end)
  set(AuxTooltip, 'NumLines', function() return 0 end)
  for _, k in ipairs{'ITEM_BIND_ON_PICKUP', 'ITEM_BIND_QUEST', 'ITEM_SOULBOUND'} do set(G, k, k) end
  local posts = 0
  set(C_AuctionHouse, 'PostItem', function() posts = posts + 1 return false end)
  set(post.stack_count_input, 'GetNumber', function() return 1 end)
  set(post.duration_dropdown, 'GetIndex', function() return 2 end)
  local shown
  set(post.post_message, 'SetText', function(self, t) shown = t end)
  local printed = {}
  set(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, t) tinsert(printed, t) end)
  set(ItemLocation, 'CreateFromBagAndSlot', function(_, b, i) return {IsValid = function() return true end, bag = b, slot = i} end)
  set(C_AuctionHouse, 'IsSellItemValid', function(location) local it = bag[location.slot]; return it and not it.locked and not (it.max and it.dur < it.max) or false end)
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local function message() post.validate_parameters(); return plain(shown) end
  local function select_sword()
    post.selected_item = {key = '7001:0', item_id = 7001, name = 'Sword', quality = 2, count = 1, max_stack = 1}
    post.set_unit_start_price(5000)
    post.set_unit_buyout_price(9000)
  end
  post.frame:Show()

  -- the item left the bags
  bag = {}
  select_sword()
  post.post_auction()
  check('FB-003: an item no longer in the bags says so', message():find('no longer in your bags', 1, true) and posts == 0)
  check('FB-003: the reason is also in chat', printed[#printed] and printed[#printed]:find('no longer in your bags', 1, true))

  -- damaged gear (Darkhorse thought his might have been)
  bag = {{id = 7001, dur = 10, max = 50}}
  post.post_auction()
  check('FB-003: damaged gear says it needs a repair', message():find('must be repaired', 1, true) and posts == 0)

  -- locked (on the cursor, in a trade)
  bag = {{id = 7001, locked = true}}
  post.post_auction()
  check('FB-003: a locked item says so', message():find('mouse pointer', 1, true) and posts == 0)

  -- the auction house never answers
  bag = {{id = 7001}}
  post.post_auction()
  check('FB-003: the post is sent', posts == 1)
  check('FB-003: Post fades and says it is posting', message():find('Posting...', 1, true))
  for _ = 1, 70 do tick() end
  check('FB-003: no answer says so', message():find('No answer from the auction house', 1, true))

  -- the auction house refuses it, with the game's own red text repeated
  select_sword()
  post.post_auction()
  fire('UI_ERROR_MESSAGE', 1, 'Item must be repaired')
  fire('AUCTION_HOUSE_SHOW_ERROR', 1)
  for _ = 1, 3 do tick() end
  local m = message()
  check('FB-003: a refused post says so with the game\'s text', m:find('refused', 1, true) and m:find('Item must be repaired', 1, true))

  -- a post that went through says so too
  select_sword()
  post.post_auction()
  bag = {}
  fire('BAG_UPDATE', 0)
  for _ = 1, 3 do tick() end
  check('FB-003: a post that went through says Posted', message():find('Posted 1 × Sword', 1, true))

  -- a faded Post button says why
  bag = {{id = 7001}}
  for _ = 1, 200 do tick() end
  select_sword()
  post.set_unit_start_price(9500)
  check('FB-003: a bid above the buyout is explained', message():find('starting bid is above the buyout', 1, true))
  post.set_unit_start_price(5000)
  check('FB-003: a valid post shows no reason', message() == '')

  post.selected_item = nil
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
end)


-- FB-006 (Garsterson): after resizing and a scale change, the Recent Searches header stuck out of
-- the window. Tables lay out again when shown and when their content area changes size, and the
-- last column is anchored to the right edge instead of keeping an old width.
try('FB-006: list headers follow the window', function()
  local listing = loadstring("select(2, ...) 'aux.test55'; return require")('auxForever', addon) 'aux.gui.listing'
  local parent = new_frame()
  local st = listing.new(parent)
  local right = 400
  rawset(st, 'GetHeight', function() return 200 end)
  rawset(st.contentFrame, 'GetLeft', function() return 0 end)
  rawset(st.contentFrame, 'GetRight', function() return right end)
  st:SetColInfo{{name = 'Name', width = .7}, {name = 'Alert', width = .3}}
  st:SetData{}
  local function anchors(f)
    local points = {}
    rawset(f, 'ClearAllPoints', function() points = {} end)
    rawset(f, 'SetPoint', function(_, p, rel) tinsert(points, p) end)
    rawset(f, 'SetWidth', function(_, w) f.__w = w end)
    return function() return points end
  end
  local first, last = anchors(st.headCols[1]), anchors(st.headCols[2])
  -- the window shrinks while the table is hidden (another sub tab), then the table is shown
  right = 200
  st.__scripts.OnShow(st)
  check('FB-006: a table shown again uses its new width', st.headCols[1].__w == 140)
  local lp = last()
  local stretches = false
  for _, p in ipairs(lp) do if p == 'TOPRIGHT' then stretches = true end end
  check('FB-006: the last header column is anchored to the right edge', stretches)
  check('FB-006: content size changes lay the table out again', st.contentFrame.__scripts.OnSizeChanged ~= nil)
  right = 300
  st.contentFrame.__scripts.OnSizeChanged(st.contentFrame)
  check('FB-006: after a content size change the widths follow', st.headCols[1].__w == 210)
end)


-- 0.5 click standard (docs/clicks.md), with FB-002 (Darkhorse): right-click a bag item
try('clicks 0.5', function()
  local req = loadstring("select(2, ...) 'aux.test56'; return require")('auxForever', addon)
  local aux = req 'aux'
  local shortcut = loadstring("select(2, ...) 'aux.core.shortcut'; return _M")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local al = req 'aux.gui.auction_listing'
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local was_shown = aux.frame.__shown
  set(G, 'GameTooltip_SetDefaultAnchor', function(t, owner) t:SetOwner(owner) end)
  aux.frame.__shown = true
  local link = '|cffffffff|Hitem:7101::::::0:0|h[Linen Cloth]|h|r'
  set(G, 'GetItemInfo', function(x) local id = tonumber(tostring(x):match('item:(%d+)') or x); if id == 7101 then return 'Linen Cloth', link, 1, 5, 1, 'Trade Goods', 'Cloth', 20, '', 1, 10 end end)
  local executed = 0
  local real_execute = search.execute
  search.execute = function() executed = executed + 1 end

  -- Alt-click from the bags on the Sniper tab: switches to Search and searches it (did nothing)
  aux.set_tab(2)
  set(G, 'IsAltKeyDown', function() return true end)
  shortcut.on_modified_click(link)
  rawset(G, 'IsAltKeyDown', nil); G.IsAltKeyDown = G.IsShiftKeyDown
  check('clicks: Alt-click a bag item on the Sniper tab searches it', aux.get_tab() and aux.get_tab().name == 'Search' and search.search_box:GetText() == 'linen cloth/exact' and executed == 1)

  -- FB-002: right-click a bag item (Blizzard sends it to AuctionHouseFrame:SetPostItem)
  local hooked
  set(G, 'hooksecurefunc', function(t, name, f) if t == AuctionHouseFrame and name == 'SetPostItem' then hooked = f end end)
  set(AuctionHouseFrame, 'SetPostItem', function() end)
  shortcut.post_item_hooked = nil
  shortcut.hook_post_item()
  check('FB-002: aux follows Blizzard\'s post item', hooked ~= nil)
  local location = {IsValid = function() return true end}
  set(C_Item, 'GetItemLink', function(l) return l == location and link or nil end)
  local button = 'RightButton'
  set(G, 'GetMouseButtonClicked', function() return button end)
  local used
  aux.set_tab(3) -- Post
  local post_tab = aux.get_tab()
  local real_post_use = post_tab.USE_ITEM
  post_tab.USE_ITEM = function(id, suffix) used = id .. ':' .. suffix end
  if hooked then hooked(AuctionHouseFrame, location) end
  check('FB-002: right-click a bag item on the Post tab selects it for posting', used == '7101:0')
  used = nil
  button = 'LeftButton'
  shortcut.on_post_item(location)
  check('FB-002: only a right-click', used == nil)
  button = 'RightButton'
  post_tab.USE_ITEM = real_post_use
  -- on the Auctions tab a right-click searches it
  aux.set_tab(4) -- Auctions
  executed = 0
  shortcut.on_post_item(location)
  check('FB-002: right-click a bag item on another tab searches it', aux.get_tab().name == 'Search' and executed == 1)

  -- click the selected row again to let go of it, in every table
  local rt = al.new(new_frame(), 19, al.search_columns)
  local function grec(key, price) return {count = 1, item_key = key, search_signature = key, name = key, requirement = 0, unit_buyout_price = price, buyout_price = price, unit_bid_price = 0, bid_price = 0, high_bid = 0, duration = 2, link = link} end
  local ra = grec('ka', 100)
  rt:SetDatabase({ra, grec('kb', 200)})
  local row = {rt = rt, record = ra}
  rt.OnClick(row, 'LeftButton')
  check('clicks: a click selects', rt:GetSelection() and rt:GetSelection().record == ra)
  check('clicks: the hint says click again to let go', rt:ClickHint(row):find('Click again: let go', 1, true) ~= nil)
  rt.OnClick(row, 'LeftButton')
  check('clicks: clicking the selected row again lets go', rt:GetSelection() == nil)
  check('clicks: the hint says click to select and right-click to search', rt:ClickHint(row):find('Click: select', 1, true) and rt:ClickHint(row):find('Right-click: search', 1, true))
  rt.alt_hint = 'Alt-click: buy'
  rt.OnClick(row, 'LeftButton')
  aux.account_data.action_shortcuts = true
  check('clicks: Alt shortcuts are in the hint only when turned on', rt:ClickHint(row):find('Alt-click: buy', 1, true) ~= nil)
  aux.account_data.action_shortcuts = false
  check('clicks: and not otherwise', rt:ClickHint(row):find('Alt', 1, true) == nil)

  -- the Post tab's price lists: click the chosen price again to let go; right-click searches
  post.selected_item = {key = '7101:0', item_id = 7101, name = 'Linen Cloth', quality = 1, count = 20, max_stack = 20, commodity = true}
  local record = {unit_price = 12, count = 5}
  local data = {record = record}
  post.buyout_listing.handlers.OnClick(post.buyout_listing, data, nil, 'LeftButton')
  check('clicks: a price is chosen with a click', post.get_buyout_selection() == record)
  post.buyout_listing.handlers.OnClick(post.buyout_listing, data, nil, 'LeftButton')
  check('clicks: clicking the chosen price again lets go of it', post.get_buyout_selection() == nil)
  post.buyout_listing.handlers.OnClick(post.buyout_listing, data, nil, 'LeftButton')
  aux.set_tab(3) -- Post
  executed = 0
  post.buyout_listing.handlers.OnClick(post.buyout_listing, data, nil, 'RightButton')
  check('clicks: right-click a price row searches the item', aux.get_tab().name == 'Search' and search.search_box:GetText() == 'linen cloth/exact')
  post.selected_item = {key = '7101:0', item_id = 7101, name = 'Linen Cloth', quality = 1, count = 20, max_stack = 20, commodity = true}
  check('clicks: right-click no longer clears the price', post.get_buyout_selection() == record)
  check('clicks: double-click on a price row does nothing now', post.buyout_listing.handlers.OnDoubleClick == nil and post.bid_listing.handlers.OnDoubleClick == nil)
  post.selected_item = nil

  -- Saved Searches list their clicks
  check('clicks: Saved Searches hints', search.FAVORITE_HINT:find('Ctrl-right-click: rename', 1, true) and search.RECENT_HINT:find('Right-click: add to favorites', 1, true))

  search.execute = real_execute
  aux.frame.__shown = was_shown
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
end)


-- FB-001 (Darkhorse): the gray "Other" box did not look like a place to type. It is labeled
-- QUANTITY and always holds the number being bought; the buttons fill it in.
try('FB-001: the quantity box', function()
  local bar = loadstring("select(2, ...) 'aux.gui.buy_bar'; return _M")('auxForever', addon)
  local tiers = {{count = 6, commodity_unit_price = 6}, {count = 100, commodity_unit_price = 7}}
  bar.clear()
  bar.show_commodity{item_id = 321, name = 'Mageroyal', max_stack = 20, tiers = function() return tiers end}
  tick()
  local box = bar.other_input
  rawset(box, 'GetNumber', function(self) return tonumber(self.__text) or 0 end)
  check('FB-001: the box is labeled Quantity', box.caption and box.caption.__text == 'QUANTITY')
  check('FB-001: the box shows the quantity being bought from the start', box:GetText() == '20')
  bar.chips[2].__scripts.OnClick(bar.chips[2])
  tick()
  check('FB-001: a button fills the box in', box:GetText() == '5' and bar.primary_label():find('^Buy 5 for') ~= nil)
  box:SetText('37')
  box.change(box, true)
  tick()
  check('FB-001: typing a number changes what is bought', bar.primary_label():find('^Buy 37 for') ~= nil)
  box:SetText('')
  box.focus_loss(box)
  check('FB-001: left empty, the box shows the quantity again', box:GetText() == '37')
  bar.clear()
end)


-- FB-007 (Garsterson): what a recipe's materials cost, in the profession window, anywhere
try('FB-007: recipe cost line', function()
  local req = loadstring("select(2, ...) 'aux.test57'; return require")('auxForever', addon)
  local aux = req 'aux'
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local today = h.today()
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  h.write_record('7201:0', {day = today, points = {{day = today - 1, value = 26}}})   -- Mageroyal, usual 26c
  h.write_record('7202:0', {day = today, points = {{day = today - 9, value = 41}}})   -- Stranglekelp, old
  h.write_record('7203:0', {day = today, points = {{day = today - 1, value = 90}}})   -- Empty Vial: usual 90c...
  aux.account_data.merchant_buy[7203] = '20#0'                                         -- ...but a vendor sells it for 20c
  local parts = {name = 'Lesser Mana Potion', reagents = {{item_id = 7201, count = 2}, {item_id = 7202, count = 1}, {item_id = 7203, count = 1}}}
  local total, missing, rows = search.recipe_usual_cost(parts)
  check('FB-007: usual prices times amounts, vendor when cheaper', total == 2 * 26 + 41 + 20 and missing == 0)
  check('FB-007: where each price comes from', rows[1].source == 'latest' and rows[1].age == 1 and rows[3].source == 'vendor')
  check('FB-007: the line', plain(search.recipe_cost_text(parts)):find('Materials', 1, true) and not plain(search.recipe_cost_text(parts)):find('+', 1, true))
  -- one material without a price: the sum of the others and a "+"
  local some = {name = 'X', reagents = {{item_id = 7201, count = 1}, {item_id = 7299, count = 3}}}
  total, missing = search.recipe_usual_cost(some)
  check('FB-007: a material with no price leaves a +', total == 26 and missing == 1 and plain(search.recipe_cost_text(some)):find('+', 1, true))
  local none = {name = 'Y', reagents = {{item_id = 7298, count = 1}, {item_id = 7299, count = 1}}}
  check('FB-007: no material priced says no price yet', plain(search.recipe_cost_text(none)):find('no price yet', 1, true))
  -- the tooltip names the price basis and each material's source and age
  local lines = {}
  local tip = new_frame()
  rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
  rawset(tip, 'AddDoubleLine', function(_, a, b) tinsert(lines, plain(a) .. ' | ' .. plain(b)) end)
  search.recipe_cost_tooltip(tip, parts)
  local all = table.concat(lines, '\n')
  check('FB-007: tooltip explains the prices', all:find('Prices from your latest scans', 1, true) ~= nil)
  check('FB-007: tooltip shows sources and ages', all:find('seen 1 day ago', 1, true) and all:find('seen 9 days ago', 1, true) and all:find('vendor', 1, true))
  lines = {}
  search.recipe_cost_tooltip(tip, some)
  all = table.concat(lines, '\n')
  check('FB-007: tooltip names the unpriced material', all:find('no price yet', 1, true) and all:find('without 1 unpriced', 1, true))
  -- the line on the profession window: set when a recipe is shown, no auction house needed
  check('FB-007: the line exists on the profession window', search.recipe_cost_line ~= nil)
  if search.recipe_cost_line then
    local schematic = {name = 'Lesser Mana Potion', outputItemID = 7210, quantityMin = 1,
      reagentSlotSchematics = {{reagents = {{itemID = 7201}}, quantityRequired = 2}, {reagents = {{itemID = 7202}}, quantityRequired = 1}}}
    G.C_TradeSkillUI = {GetRecipeSchematic = function() return schematic end}
    local form = new_frame()
    rawset(form, 'GetRecipeInfo', function() return {recipeID = 555} end)
    local text
    rawset(search.recipe_cost_line.text, 'SetText', function(_, t) text = t end)
    search.update_cost_line(form)
    check('FB-007: the line shows the recipe\'s cost', plain(text):find('Materials', 1, true) and search.recipe_cost_line.__shown)
    G.C_TradeSkillUI = nil
  end
  aux.account_data.merchant_buy[7203] = nil
end)


-- 0.5 build 1 results (Tyler, 2026-10-07)
try('0.5 build 1 fixes', function()
  local req = loadstring("select(2, ...) 'aux.test58'; return require")('auxForever', addon)
  local aux = req 'aux'
  local gui = req 'aux.gui'
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  set(G, 'GameTooltip_SetDefaultAnchor', function(t, owner) t:SetOwner(owner) end)

  -- right-click a Post price row raised "attempt to index global 'selected_item'": leaving the Post
  -- tab clears it before the name was read
  aux.set_tab(3)
  post.selected_item = {key = '7101:0', item_id = 7101, name = 'Linen Cloth', quality = 1, count = 20, max_stack = 20, commodity = true}
  local ok, err = pcall(post.buyout_listing.handlers.OnClick, post.buyout_listing, {record = {unit_price = 12, count = 5}}, nil, 'RightButton')
  check('build 1: right-click a Post price row works from the Post tab', ok and aux.get_tab().name == 'Search' and search.search_box:GetText() == 'linen cloth/exact')
  if not ok then print('  ', err) end

  -- click hints: one line per click, the click on the left
  local doubles, singles = {}, 0
  local tip = new_frame()
  rawset(tip, 'AddDoubleLine', function(_, a, b) tinsert(doubles, a .. '=' .. b) end)
  rawset(tip, 'AddLine', function() singles = singles + 1 end)
  gui.add_click_hint(tip, 'Click: run' .. gui.HINT_SEPARATOR .. 'Alt-drag: reorder', true)
  check('build 1: each click on its own line', #doubles == 2 and doubles[1] == 'Click=run' and doubles[2] == 'Alt-drag=reorder' and singles == 0)

  -- the quantity box has no cursor mark (it looked like a bug)
  local bar = loadstring("select(2, ...) 'aux.gui.buy_bar'; return _M")('auxForever', addon)
  check('build 1: no cursor mark in the quantity box', bar.other_input.caret == nil)

  -- the recipe cost tooltip's total is not red
  local today = h.today()
  h.write_record('7401:0', {day = today, points = {{day = today - 1, value = 50}}})
  local total_args
  local tip2 = new_frame()
  rawset(tip2, 'AddDoubleLine', function(_, a, b, lr, lg, lb, rr, rg, rb) if a == 'Total' then total_args = {rr, rg, rb} end end)
  search.recipe_cost_tooltip(tip2, {reagents = {{item_id = 7401, count = 1}}})
  check('build 1: the cost total is white, not red', total_args and total_args[1] == 1 and total_args[2] == 1 and total_args[3] == 1)
  local row_args
  rawset(tip2, 'AddDoubleLine', function(_, a, b, lr, lg, lb, rr, rg, rb) if a ~= 'Total' then row_args = {rr, rg, rb} end end)
  search.recipe_cost_tooltip(tip2, {reagents = {{item_id = 7401, count = 1}}})
  check('build 2: each material\'s price is white, not the game\'s gold', row_args and row_args[1] == 1 and row_args[2] == 1 and row_args[3] == 1)
  check('build 2: the locked message fits in two lines', #post.NOT_POSTED.locked <= 80)

  -- with Shift held, tooltip prices are for the stack and say so
  rawset(AuxTooltip, 'NumLines', function() return 0 end)
  set(G, 'IsShiftKeyDown', function() return true end)
  local lines = {}
  local tip3 = new_frame()
  rawset(tip3, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
  tooltip.extend_tooltip(tip3, '|cffffffff|Hitem:7401::::::0:0|h[X]|h|r', 3)
  rawset(AuxTooltip, 'NumLines', nil)
  local value_line
  for _, l in ipairs(lines) do if l:find('^Value') then value_line = l end end
  check('build 1: a stack\'s Value says it is for the stack', value_line and value_line:find('for 3', 1, true) ~= nil)
  rawset(G, 'IsShiftKeyDown', nil); G.IsShiftKeyDown = function() return false end

  -- /aux price shows what aux recorded
  local printed = {}
  set(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, t) tinsert(printed, plain(t)) end)
  h.write_record('7402:0', {day = today, low = 38, market = 40, units = 83, points = {{day = today - 1, value = 87, units = 60}, {day = today - 3, value = 90}}})
  SlashCmdList.AUX('price |cffffffff|Hitem:7402::::::0:0|h[Banana]|h|r')
  local out = table.concat(printed, '\n')
  check('/aux price: the tooltip Value and the usual price', out:find('Value in tooltips (latest look, seen today): 40c', 1, true) and out:find('Usual price, for finding deals:', 1, true) and out:find('from 2 past days', 1, true))
  check('/aux price: today\'s lowest and market', out:find('lowest 38c', 1, true) and out:find('market 40c (of 83 listed)', 1, true))
  check('/aux price: the past days', out:find('1 day ago 87c (60 listed)', 1, true) and out:find('3 days ago 90c (lowest, 0.4)', 1, true))

  post.selected_item = nil
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
end)


-- build 3 (Tyler, 2026-10-07): players scan, post and leave; the tooltip shows the latest look at an
-- item, and the multi-day usual price stays for finding deals
try('0.5 build 3: latest price in tooltips', function()
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local today = h.today()
  -- the banana of build 1: two old daily lows, today's market 39c
  h.write_record('7501:0', {day = today, low = 38, market = 39, units = 82, points = {{day = today - 2, value = 87}, {day = today - 3, value = 11}}})
  local latest, age = h.latest('7501:0')
  check('build 3: the latest price is today\'s market price', latest == 39 and age == 0)
  check('build 3: the usual price stays for deals', h.value('7501:0') == 87)
  -- not seen today: the newest past day, with its age
  h.write_record('7502:0', {day = today, points = {{day = today - 4, value = 120}, {day = today - 5, value = 100}}})
  latest, age = h.latest('7502:0')
  check('build 3: not seen today, the newest day and its age', latest == 120 and age == 4)
  local function tip_lines(id)
    local lines = {}
    local tip = new_frame()
    rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
    rawset(AuxTooltip, 'NumLines', function() return 0 end)
    tooltip.extend_tooltip(tip, '|cffffffff|Hitem:' .. id .. '::::::0:0|h[X]|h|r', 1)
    rawset(AuxTooltip, 'NumLines', nil)
    return table.concat(lines, '\n')
  end
  local banana = tip_lines(7501)
  -- 0.8.2 build 4 (Tyler): the usual price is a percent on the Value line, no "usually" line
  check('build 3: tooltip Value is the latest price', banana:find('Value: 0.39 (45%)  seen today', 1, true) ~= nil)
  check('0.8.2: the usual price is a percent on the Value line, not a line of its own', banana:find('usually', 1, true) == nil)
  local steady = tip_lines(7502)
  check('build 3: no "usually" line when the two are close either', steady:find('usually', 1, true) == nil and steady:find('%)', 1, true) ~= nil)
  -- the recipe cost uses the latest price too
  local total = search.recipe_usual_cost({reagents = {{item_id = 7501, count = 2}}})
  check('build 3: the recipe cost uses the latest price', total == 78)
end)


-- build 3 results (Tyler, 2026-10-07)
try('0.5 build 3 results', function()
  local req = loadstring("select(2, ...) 'aux.test59'; return require")('auxForever', addon)
  local aux = req 'aux'
  local shortcut = loadstring("select(2, ...) 'aux.core.shortcut'; return _M")('auxForever', addon)
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local was_shown = aux.frame.__shown
  aux.frame.__shown = true

  -- a right-clicked bag item stayed locked in Blizzard's hidden Sell tab: aux empties it
  local cleared = 0
  set(AuctionHouseFrame, 'ClearPostItem', function() cleared = cleared + 1 end)
  set(G, 'GetMouseButtonClicked', function() return 'RightButton' end)
  local link = '|cffffffff|Hitem:7101::::::0:0|h[Linen Cloth]|h|r'
  set(C_Item, 'GetItemLink', function() return link end)
  set(G, 'GetItemInfo', function(x) local id = tonumber(tostring(x):match('item:(%d+)') or x); if id == 7101 then return 'Linen Cloth', link, 1, 5, 1, 'Trade Goods', 'Cloth', 20, '', 1, 10 end end)
  aux.set_tab(3)
  shortcut.on_post_item({IsValid = function() return true end})
  check('build 3: the right-clicked item is taken back from Blizzard\'s Sell tab (unlocked)', cleared == 1)

  -- hovering a faded Post button says why
  local tip_text
  set(GameTooltip, 'AddLine', function(_, t) tip_text = t end)
  post.selected_item = {key = '7101:0', item_id = 7101, name = 'Linen Cloth', quality = 1, count = 20, max_stack = 20}
  post.set_unit_start_price(900)
  post.set_unit_buyout_price(500)
  rawset(post.post_button, 'IsEnabled', function() return false end)
  post.post_button.__scripts.OnEnter(post.post_button)
  rawset(post.post_button, 'IsEnabled', nil)
  check('build 3: hovering a faded Post button says why', tip_text and tip_text:find('starting bid is above the buyout', 1, true) ~= nil)
  post.selected_item = nil

  -- a Full scan says it is waiting for the auction house, then how far it is
  local texts = {}
  set(aux.status_bar.text, 'SetText', function(_, t) tinsert(texts, t) end)
  -- the top bar's button (the Sniper's notice has a Full scan button too, build 9)
  local scan_button = aux.full_scan_button
  local list = {{id = 7101, count = 5, buyout = 50}, {id = 7101, count = 5, buyout = 55}}
  set(C_AuctionHouse, 'ReplicateItems', function() end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return #list end)
  set(C_AuctionHouse, 'GetReplicateItemInfo', function(i) local a = list[i + 1]; return 'Item', 1, a.count, 1, true, 1, nil, 0, 0, a.buyout, 0, false, nil, 'Seller', nil, 0, a.id, true end)
  set(C_AuctionHouse, 'GetReplicateItemLink', function() return link end)
  if scan_button then scan_button.__scripts.OnClick(scan_button) end
  for _ = 1, 3 do tick() end
  check('build 3: a Full scan says it is waiting for the auction house', texts[1] and texts[1]:find('waiting for the auction house', 1, true) ~= nil)
  fire('REPLICATE_ITEM_LIST_UPDATE')
  for _ = 1, 60 do tick() end
  local joined = table.concat(texts, '|')
  check('build 3: then how far it is, and nothing when done', joined:find('reading auctions, 100%', 1, true) ~= nil and texts[#texts] == '')

  aux.frame.__shown = was_shown
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
end)


-- 0.5 release (Tyler, 2026-10-07): the login line asks for Full scans, saying when the last one was
try('0.5: Full scan reminder at login', function()
  local aux = loadstring("select(2, ...) 'aux.test60'; return require")('auxForever', addon) 'aux'
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local now = 2000000000
  check('reminder: never scanned asks for one', plain(aux.full_scan_reminder(0, now)):find('click Full scan (top right of aux)', 1, true) ~= nil)
  check('reminder: hours ago', plain(aux.full_scan_reminder(now - 2 * 3600 - 5, now)):find('Last Full scan: 2 hours ago.', 1, true) ~= nil)
  check('reminder: days ago', plain(aux.full_scan_reminder(now - 3 * 86400, now)):find('Last Full scan: 3 days ago.', 1, true) ~= nil)
  check('reminder: just now', plain(aux.full_scan_reminder(now - 60, now)):find('less than an hour ago', 1, true) ~= nil)
  local src = io.open('aux-addon.lua'):read('*a')
  check('reminder: printed at login', src:find("print(full_scan_reminder(account_data.replicate_time, time()))", 1, true) ~= nil)
end)

-- 0.6: two looks, New (default) and Classic, picked in Settings and applied at login. Run with the
-- argument `classic` to check everything in the Classic look (the workflows run both).
try('0.6: looks', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local gui_env = loadstring("select(2, ...) 'aux.gui'; return _M")('auxForever', addon)
  local auction_listing = loadstring("select(2, ...) 'aux.test61'; return require")('auxForever', addon) 'aux.gui.auction_listing'
  local sniper_env = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local function near(x, n) return x and math.abs(x - n / 255) < .002 end
  check('looks: the saved look is in use', a.theme == THEME and a.account_data.theme == THEME)
  -- both palettes name the same colors, so no widget is left without one in either look
  local new_paths, classic_paths = a.palette_paths(a.PALETTES.new), a.palette_paths(a.PALETTES.classic)
  local same = true
  for k in pairs(new_paths) do if not classic_paths[k] then same = false; print('  missing in classic: ' .. k) end end
  for k in pairs(classic_paths) do if not new_paths[k] then same = false; print('  missing in new: ' .. k) end end
  check('looks: both palettes have the same colors', same)
  -- the colors in use are the look's
  local r = a.color.accent.background()
  check('looks: accent color of the look', near(r, pick(229, 227)))
  -- widgets made while the files loaded (before the look was known) carry the look's colors
  check('looks: a label made at load has the look\'s color', a.credit_label.__text_color and near(a.credit_label.__text_color[1], pick(107, 125)))
  check('looks: colored text made at load follows the look', auction_listing.time_left(1):upper():find(pick('E8574A', 'FF0000'), 1, true) ~= nil)
  check('looks: the window is square in New, rounded in Classic', #a.frame.aux_fill.pieces == pick(1, 7))
  local fill = a.frame.aux_fill.pieces[1]
  check('looks: the window fill has the look\'s color', fill.__vertex_color and near(fill.__vertex_color[1], pick(26, 22)))
  check('looks: column headers are square in both', #sniper_env.listing.headCells[1].aux_fill.pieces == 1)
  check('looks: the top bands only show in New', select(4, a.color.band_edge()) == pick(1, 0) and select(4, a.color.band()) == pick(1, 0))
  -- nothing is kept once the look is applied: painting costs nothing more while playing
  check('looks: nothing kept after login', gui_env.pending_paint == nil and gui_env.pending_shapes == nil and gui_env.pending_sheens == nil)
  check('looks: every color at login painted without an error', gui_env.theme_error == nil)
  local ran = 0
  gui_env.themed(function() ran = ran + 1 end)
  check('looks: painting after login runs once and is not kept', ran == 1 and gui_env.pending_paint == nil)
  -- an unknown look is the New look
  check('looks: unknown name is New', a.set_palette('bogus') == 'new')
  a.set_palette(THEME)
  -- Tyler, 2026-10-08: text boxes were hard to find on the near black panels (Filter Builder). In
  -- New a sunken field has a gray edge and is darker than the panel around it.
  local P = a.PALETTES.new
  check('new look: an input edge stands out from the panel', P.input.border[1] - P.panel.background[1] >= 30)
  check('new look: an input is darker than the panel', P.input.background[1] < P.panel.background[1])
  check('new look: blacks toned back', P.panel.background[1] >= 16 and P.window.background[1] >= 24)
end)

-- 0.6, Tyler build 5: the Sniper is for making money. Fading Echo (gray) and Trapper's Shirt showed
-- as deals at 1s against usual prices of 79s and 90s that no one pays.
try('0.6: sniper leaves out grays and thin history', function()
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local d = h.today()
  local real_info = G.GetItemInfo
  local quality = 0
  G.GetItemInfo = function(id) return 'Fading Echo', 'link', quality, 1, 1, 'Junk', 'Junk', 1, '', 1, 50 end
  local full = {{value = 7900, day = d - 1, units = 13}, {value = 7900, day = d - 2, units = 13}, {value = 7900, day = d - 3, units = 13}}
  h.write_record('601:0', {day = d, points = full})
  local usual, vendor, days = sniper.item_facts('601:0', 601)
  check('sniper: a gray item has no usual price and no vendor price', usual == nil and vendor == 0 and days == 0)
  check('sniper: so a gray item is never a deal, even below vendor price', sniper.judge(100, usual, vendor, days, 60, 0) == nil)
  quality = 1
  usual, vendor, days = sniper.item_facts('601:0', 601)
  check('sniper: a white item with 3 days of Full scans can be a deal', usual == 7900 and days == 3 and sniper.judge(100, usual, vendor, days, 60, 500) ~= nil)
  -- Fading Echo's history: yesterday a complete look (1s, 1 listed), before that two 0.4 lowest-only days at 79s
  h.write_record('602:0', {day = d, points = {{value = 100, day = d - 1, units = 1}, {value = 7900, day = d - 3}, {value = 7900, day = d - 4}}})
  usual, vendor, days = sniper.item_facts('602:0', 602)
  check('sniper: only days with a complete look count', days == 1)
  check('sniper: so Fading Echo at 1s is not a deal', sniper.judge(100, usual, vendor, days, 60, 5) == nil)
  G.GetItemInfo = real_info
end)

-- 0.6, Tyler build 4: g, s and c keep their coin colors wherever money is shown, buttons included
try('0.6: coin colors everywhere', function()
  local money = loadstring("select(2, ...) 'aux.test63'; return require")('auxForever', addon) 'aux.util.money'
  local bar_env = loadstring("select(2, ...) 'aux.gui.buy_bar'; return _M")('auxForever', addon)
  local recipe_env = loadstring("select(2, ...) 'aux.tabs.search.recipe'; return _M")('auxForever', addon)
  local sniper_env = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local bar = loadstring("select(2, ...) 'aux.test64'; return require")('auxForever', addon) 'aux.gui.buy_bar'
  bar.show_item{record = {item_id = 7101, name = 'Sword', buyout_price = 460, bid_price = 0, count = 1, link = 'x'}, name = 'Sword', texture = 1, on_buy = function() end, on_bid = function() end, busy = function() return false end}
  for _ = 1, 3 do tick() end
  local text = ''
  for _, f in ipairs(frames) do
    if type(f.__text) == 'string' and f.__text:find('^Buy for') then text = f.__text end
  end
  check('coins: the Buy button money has a silver s and a copper c', text:find('Buy for', 1, true) ~= nil and text:find(money.SILVER_TEXT, 1, true) ~= nil and text:find(money.COPPER_TEXT, 1, true) ~= nil)
  bar.clear()
  -- no money is ever written without its coin colors outside typing fields and search text
  local plain = 0
  for _, file in ipairs{'gui/buy_bar.lua', 'tabs/search/recipe.lua', 'tabs/sniper/frame.lua'} do
    local src = io.open(file):read('*a')
    for _ in src:gmatch('to_string%([^\n]-, *nil, *nil, *true%)') do plain = plain + 1 end
  end
  check('coins: no money without coin colors on buttons, the recipe line or the Sniper', plain == 0)
end)

-- 0.6, Tyler 2026-10-08: zebra rows, every second row dark gray, under hover and selection
try('0.6: zebra rows', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local sniper_env = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  -- rows are made when a table gets its height
  G.__geometry = {size = 300, edge = 100}
  local rt = sniper_env.listing
  rt.__scripts.OnSizeChanged(rt)
  local rows = rt.rows
  check('zebra: first row plain', rows[1] and rows[1].stripe == nil)
  check('zebra: second row striped', rows[2] and rows[2].stripe ~= nil)
  check('zebra: third row plain', rows[3] and rows[3].stripe == nil)
  local c = rows[2] and rows[2].stripe and rows[2].stripe.__texture_color
  check('zebra: a faint light shade (dark gray on the table)', c and c[1] == 1 and c[4] > 0 and c[4] < .08)
  local st = loadstring("select(2, ...) 'aux.test62'; return require")('auxForever', addon) 'aux.gui.listing'
  local t = st.new(new_frame())
  t:SetColInfo({{name = 'A', width = 1}})
  t:SetData({{cols = {{value = 'x'}}}, {cols = {{value = 'y'}}}})
  check('zebra: the other tables too', t.rows[2] and t.rows[2].stripe ~= nil and t.rows[1].stripe == nil)
  G.__geometry = nil
end)

-- 0.6: Settings has the look (with a reload button when the choice changes) and the tooltip lines
-- (a player on CurseForge asked for the chat settings in the menu, FB-008)
try('0.6: settings', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local other = THEME == 'new' and 'classic' or 'new'
  a.refresh_settings()
  check('settings: no reload button while the look is the one in use', a.reload_button.__shown == false)
  a.look_buttons[other].__scripts.OnClick(a.look_buttons[other])
  check('settings: picking the other look saves it', a.account_data.theme == other)
  check('settings: and offers a reload', a.reload_button.__shown == true and a.reload_note.__text:find('theme after a reload', 1, true) ~= nil)
  -- Tyler, build 4: players see it as the Theme, not the Look
  local src = io.open('frame.lua'):read('*a')
  check('settings: the row is called Theme', src:find("row(popup, LEFT_X, -110, 30, 'Theme',", 1, true) ~= nil and not src:find("30, 'Look',", 1, true))
  local reloaded
  G.ReloadUI = function() reloaded = true end
  a.reload_button.__scripts.OnClick(a.reload_button)
  check('settings: Reload now reloads', reloaded)
  a.look_buttons[THEME].__scripts.OnClick(a.look_buttons[THEME])
  check('settings: back to the look in use, no reload needed', a.account_data.theme == THEME and a.reload_button.__shown == false)
  check('settings: colors stay those of this login until the reload', a.theme == THEME)
  -- tooltip lines: each box flips its line and shows its state
  local keys = {}
  for _, box in ipairs(a.tooltip_boxes) do keys[box.key] = true end
  local all = true
  for _, k in ipairs{'value', 'usually', 'daily', 'merchant_sell', 'merchant_buy', 'disenchant_value', 'disenchant_distribution', 'money_icons'} do
    if not keys[k] then all = false end
  end
  check('settings: every /aux tooltip line has a box', all and #a.tooltip_boxes == 8)
  local box = a.tooltip_boxes[1]
  local checked
  local own_set_checked = rawget(box, 'SetChecked')
  rawset(box, 'SetChecked', function(_, v) checked = v end)
  local before = a.character_data.tooltip[box.key]
  box.__scripts.OnClick(box)
  check('settings: a box turns its tooltip line off and on', a.character_data.tooltip[box.key] == not before and checked == not before)
  box.__scripts.OnClick(box)
  check('settings: and back', a.character_data.tooltip[box.key] == before and checked == before)
  rawset(box, 'SetChecked', own_set_checked)
  -- build 3 (Tyler approved the mockup): the tooltip lines are switches, not checkboxes
  check('settings: tooltip lines are switches', box.knob ~= nil and box.on_click ~= nil)
  local was = a.character_data.tooltip[box.key]
  box.__scripts.OnClick(box)
  check('settings: a switch moves with its line', box:GetChecked() == not was)
  box.__scripts.OnClick(box)
  check('settings: and back again', box:GetChecked() == was)
  -- build 4 (Tyler): Bid prices left the menu (bids are rare on Forever and "per stack" means
  -- nothing there); /aux post bid still shows or hides the bid table at once
  local post_env = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  check('settings: no Bid prices row', a.bid_buttons == nil)
  SlashCmdList.AUX('post bid stack')
  check('settings: the chat command shows it at once too', a.account_data.post_bid == 'stack' and post_env.frame.bid_listing.__shown == true)
  SlashCmdList.AUX('post bid off')
  check('settings: and hides it', a.account_data.post_bid == nil and post_env.frame.bid_listing.__shown == false)
end)

-- FB-010 (reported by GregoryWW): Forever's auction house has a third level under weapons
-- (Weapons, One-Handed, Daggers), not only under armor. aux read a slot only under Armor, so
-- "daggers" became a tooltip text filter and the search went through every one-handed weapon.
try('0.6.1: slots under any category', function()
  local require = loadstring("select(2, ...) 'aux.test.fb010'; return require")('auxForever', addon)
  local filter_util = require 'aux.util.filter'
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local query = filter_util.query('weapons/one-handed/daggers')
  check('fb010: daggers is the slot', query and query.blizzard_query.class == 1 and query.blizzard_query.subclass == 1 and query.blizzard_query.slot == 4)
  check('fb010: not a tooltip text filter', query and #filter_util.parse_filter_string('weapons/one-handed/daggers').post == 0)
  local class_filters = query and scan.browse_query(query.blizzard_query).itemClassFilters
  check('fb010: the auction house is asked for daggers only', class_filters and #class_filters == 1 and class_filters[1].classID == 2 and class_filters[1].subClassID == 15)
  query = filter_util.query('armor/cloth/chest')
  check('fb010: armor slots still work', query and query.blizzard_query.class == 2 and query.blizzard_query.subclass == 4 and query.blizzard_query.slot == 3)
  query = filter_util.query('daggers')
  check('fb010: a slot name alone is still a name search', query and query.blizzard_query.name == 'daggers' and query.blizzard_query.slot == nil)
end)

-- Every category, type and slot of Forever's auction house, as the Which items menus write it into
-- the search bar, must read back as the same choice and ask the auction house for exactly that
-- category. Uses the real tree (tests/forever_categories.lua).
try('0.6.1: every category reads back', function()
  local require = loadstring("select(2, ...) 'aux.test.categories'; return require")('auxForever', addon)
  local filter_util = require 'aux.util.filter'
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local bad, count = {}, 0
  local function try_path(category, text, class, subclass, slot)
    count = count + 1
    local query = filter_util.query(text)
    local q = query and query.blizzard_query
    local ok = q and q.class == class and q.subclass == subclass and q.slot == slot and q.name == nil
      and #filter_util.parse_filter_string(text).post == 0
      and scan.browse_query(q).itemClassFilters == (category.filters or {})
    if not ok then tinsert(bad, text) end
  end
  for c, category in ipairs(AuctionCategories) do
    local c_text = strlower(category.name)
    try_path(category, c_text, c)
    for s, subcategory in ipairs(category.subCategories or {}) do
      local s_text = c_text .. '/' .. strlower(subcategory.name)
      try_path(subcategory, s_text, c, s)
      for t, slot in ipairs(subcategory.subCategories or {}) do
        try_path(slot, s_text .. '/' .. strlower(slot.name), c, s, t)
      end
    end
  end
  for _, text in ipairs(bad) do print('  does not read back: ' .. text) end
  check('categories: the tree is loaded', count > 100)
  -- core/scan.lua leaves out Blizzard's exact match for categories 1 and 2 (weapons and armor have
  -- random endings, so an exact name would miss them); that needs them first and second
  check('categories: Weapons is 1 and Armor is 2', AuctionCategories[1].filters[1].classID == 2 and AuctionCategories[2].filters[1].classID == 4)
  check('categories: every category, type and slot reads back', #bad == 0)
end)

-- Audit A2: the Which items menus take a slot under any category, and In words names the most
-- specific choice first ("one-handed (weapons, daggers)" before)
try('0.6.1: weapon slots in the Which items menus', function()
  local s = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local function load(text) s.search_box:SetText(text); s.load_builder(); return s.blizzard_string(), s.blizzard_words() end
  local text, words = load('weapons/one-handed/daggers')
  check('menus: a weapon slot from the search bar fills the menus', text == 'weapons/one-handed/daggers')
  check('in words: the slot first', words == 'Daggers (weapons, one-handed)')
  text, words = load('armor/cloth/chest')
  check('in words: an armor slot the same way', text == 'armor/cloth/chest' and words == 'Chest (armor, cloth)')
  text, words = load('armor/cloth')
  check('in words: no slot', words == 'Cloth (armor)')
  s.clear_builder()
end)

-- Audit A8: your characters are dated with the date, not the computer's uptime, so one not seen
-- for 30 days is forgotten; old uptime stamps count as seen today, so no alt is lost by updating
try('0.6.1: your characters', function()
  local require = loadstring("select(2, ...) 'aux.test.a8'; return require")('auxForever', addon)
  local aux = require 'aux'
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local own = aux.realm_data.characters
  local day = 60 * 60 * 24
  aux.realm_data.characters = {Uptime = 5000, Recent = time() - 2 * day, Gone = time() - 31 * day}
  info.update_characters()
  local c = aux.realm_data.characters
  check('characters: an old uptime stamp is kept and dated today', info.is_player('Uptime') and c.Uptime >= time() - 5)
  check('characters: one seen 2 days ago is kept', info.is_player('Recent'))
  check('characters: one not seen for 31 days is forgotten', not info.is_player('Gone') and c.Gone == nil)
  check('characters: the one logged in is dated now', info.is_player(UnitName'player') and c[UnitName'player'] >= time() - 5)
  aux.realm_data.characters = own
  info.update_characters()
end)

-- Audit A4 (Tyler, 2026-10-11: Forever will have many items Classic did not): aux's item list is
-- walked at login only up to item number 30000. An item seen at the auction house joins it at once.
try('0.6.1: items seen at the auction house join the item list', function()
  local require = loadstring("select(2, ...) 'aux.test.a4'; return require")('auxForever', addon)
  local aux = require 'aux'
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local real_info = G.GetItemInfo
  G.GetItemInfo = function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if id == 212345 or id == 212346 then return 'Forever Blade', 'link', 3, 30, 25, 'Weapon', 'Daggers', 1, 'INVTYPE_WEAPON', 1, 900 end
  end
  local function listed() local n = 0 for _, name in ipairs(aux.account_data.auctionable_items) do if name == 'forever blade' then n = n + 1 end end return n end
  check('item list: a new item is not known before', info.item_id('Forever Blade') == nil and listed() == 0)
  info.browse_record({itemKey = {itemID = 212345, itemSuffix = 0}, totalQuantity = 1, minPrice = 5000})
  check('item list: seen in an auction house list, it is known by name', info.item_id('Forever Blade') == 212345)
  check('item list: and offered for autocompletion once', listed() == 1)
  info.browse_record({itemKey = {itemID = 212345, itemSuffix = 0}, totalQuantity = 1, minPrice = 5000})
  info.browse_record({itemKey = {itemID = 212346, itemSuffix = 0}, totalQuantity = 1, minPrice = 5000})
  check('item list: seeing it again, or an item of the same name, adds no second entry', listed() == 1)
  G.GetItemInfo = real_info
  check('item list: its facts stay when the game has not loaded the item', info.item(212345) and info.item(212345).sell_price == 900)
  aux.account_data.items[212345], aux.account_data.items[212346], aux.account_data.item_ids['forever blade'] = nil, nil, nil
  for i = #aux.account_data.auctionable_items, 1, -1 do if aux.account_data.auctionable_items[i] == 'forever blade' then tremove(aux.account_data.auctionable_items, i) end end
end)

-- Gamepad mode (gamepad.lua): aux binds the pad buttons to buttons of its own while it is open and
-- never writes into Blizzard's gamepad system (2026-10-13: registering with Blizzard's window
-- manager tainted it and froze the game when aux closed).
try('gamepad: aux takes the pad buttons only while open, in gamepad mode', function()
  local aux_env = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local bindings, combat, gamepad_ui = {}, false, false
  local real = {G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown}
  G.SetOverrideBindingClick = function(_, _, key, button) bindings[key] = 'CLICK ' .. button .. ':LeftButton' end
  G.ClearOverrideBindings = function() bindings = {} end
  G.InCombatLockdown = function() return combat end
  G.InputUtil = {IsGamepadUIEnabled = function() return gamepad_ui end}
  G.GamepadMode = setmetatable({}, {__index = function() error('aux must not touch GamepadMode') end})
  local aux_frame = aux_env.frame
  local function count() local n = 0 for _ in pairs(bindings) do n = n + 1 end return n end

  aux_frame:Hide(); aux_frame:Show()
  check('gamepad: mouse and keyboard, no pad buttons taken', count() == 0)

  gamepad_ui = true
  aux_frame:Hide(); aux_frame:Show()
  check('gamepad: open, aux has the D-pad, A, B, X, Y, LB and RB', count() == 10 and bindings.PAD3 == 'CLICK auxForeverPadX:LeftButton' and bindings.PAD4 == 'CLICK auxForeverPadY:LeftButton' and bindings.PADDUP == 'CLICK auxForeverPadup:LeftButton' and bindings.PAD1 == 'CLICK auxForeverPadA:LeftButton')
  aux_frame:Hide()
  check('gamepad: closed, the pad buttons are given back', count() == 0)

  aux_frame:Show()
  combat = true
  aux_frame:Hide()
  check('gamepad: closed in combat, the bindings wait for the end of combat', count() == 10)
  combat = false
  for _, f in ipairs(frames) do
    if f.__events.PLAYER_REGEN_ENABLED then f.__scripts.OnEvent(f, 'PLAYER_REGEN_ENABLED') end
  end
  check('gamepad: after combat they are given back', count() == 0)

  aux_frame:Show()
  aux_env.blizzard_button.__scripts.OnClick(aux_env.blizzard_button)
  check('gamepad: Blizzard UI shown, its own navigation gets the pad back', count() == 0)
  aux_env.blizzard_button.__scripts.OnClick(aux_env.blizzard_button)
  check('gamepad: Blizzard UI hidden, aux takes it again', count() == 10)

  aux_frame:Hide(); aux_frame:Show()
  -- closed while still in gamepad mode, so aux gives the pad buttons back before the stubs go
  aux_frame:Hide()
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = real[1], real[2], real[3]
  G.InputUtil, G.GamepadMode = nil, nil
  aux_frame:Show()
end)

-- The navigator: a test layout far from aux's own controls (the stubs put those at 10, 10)
try('gamepad: the D-pad, A, B, LB and RB move around aux', function()
  local aux_env = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local require = loadstring("select(2, ...) 'aux.test.gamepad_nav'; return require")('auxForever', addon)
  local gui = require 'aux.gui'
  local real = {G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown}
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = function() end, function() end, function() return false end
  G.InputUtil = {IsGamepadUIEnabled = function() return true end}
  G.GamepadMode = setmetatable({}, {__index = function() error('aux must not touch GamepadMode') end})
  local aux_frame = aux_env.frame
  local function pad(name) local b = G['auxForeverPad' .. name]; b.__scripts.OnClick(b) end
  local function place(f, x, y)
    rawset(f, 'GetCenter', function() return x, y end)
    rawset(f, 'GetLeft', function() return x - 5 end)
    rawset(f, 'GetTop', function() return y + 5 end)
    return f
  end
  local function typing(box)
    rawset(box, 'SetFocus', function(self) self.__focus = true end)
    rawset(box, 'ClearFocus', function(self) self.__focus = false end)
    rawset(box, 'HasFocus', function(self) return self.__focus == true end)
  end

  local layout = CreateFrame('Frame', nil, aux_frame)
  local clicked
  local b1 = place(CreateFrame('Button', nil, layout), 1000, 600)
  local b2 = place(CreateFrame('Button', nil, layout), 1100, 600)
  for _, b in ipairs{b1, b2} do
    b:SetScript('OnClick', function(self) clicked = self end)
    rawset(b, 'Click', function(self) self.__scripts.OnClick(self) end)
  end
  local box = place(gui.editbox(layout), 1000, 550)
  typing(box)
  -- like the Post tab's -, + and Max: a button that is a child of the text box
  local plus = place(CreateFrame('Button', nil, box), 1060, 550)
  local list = CreateFrame('Frame', nil, layout)
  local content = CreateFrame('Frame', nil, list)
  local r1 = place(CreateFrame('Button', nil, content), 1000, 500)
  local r2 = place(CreateFrame('Button', nil, content), 1000, 480)
  local scroll_frame = CreateFrame('ScrollFrame', nil, list)
  local value = 0
  scroll_frame.ScrollBar = {
    GetValue = function() return value end,
    SetValue = function(_, v) value = v end,
    GetMinMaxValues = function() return 0, 50 end,
  }

  aux_frame:Hide(); aux_frame:Show()
  check('gamepad nav: aux opens with the focus on the first control', aux_env.gamepad_focused() == b1)
  pad('right')
  check('gamepad nav: right goes to the control on the right', aux_env.gamepad_focused() == b2)
  pad('A')
  check('gamepad nav: A clicks it', clicked == b2)
  pad('left'); pad('down')
  check('gamepad nav: down goes to the control below', aux_env.gamepad_focused() == box)
  pad('A')
  check('gamepad nav: A on a text box starts typing', box:HasFocus())
  pad('B')
  check('gamepad nav: B stops typing and stays', not box:HasFocus() and aux_env.gamepad_focused() == box and aux_frame.__shown)
  pad('right')
  check('gamepad nav: a button inside a text box can be reached (Post tab quantity -, +, Max)', aux_env.gamepad_focused() == plus)
  pad('left')
  check('gamepad nav: and left goes back to the box', aux_env.gamepad_focused() == box)
  pad('down'); pad('down')
  check('gamepad nav: down walks a list row by row', aux_env.gamepad_focused() == r2)
  pad('down')
  check('gamepad nav: past the last row shown, down scrolls the list', aux_env.gamepad_focused() == r2 and value == 10)
  pad('up')
  check('gamepad nav: up goes back a row', aux_env.gamepad_focused() == r1)

  -- LB and RB: tabs switch at once; past them come Settings, Full scan and Blizzard UI
  aux_env.set_tab(1)
  pad('RB')
  check('gamepad nav: RB opens the next tab', aux_env.tabs._selected == 2 and aux_env.gamepad_focused() == aux_env.tabs._tabs[2])
  pad('LB'); pad('LB')
  check('gamepad nav: LB from the first tab goes round to Blizzard UI, the tab stays', aux_env.tabs._selected == 1 and aux_env.gamepad_focused() == aux_env.blizzard_button)
  pad('RB')
  check('gamepad nav: RB from Blizzard UI goes round to the first tab', aux_env.tabs._selected == 1 and aux_env.gamepad_focused() == aux_env.tabs._tabs[1])
  pad('A')
  check('gamepad nav: A on a tab goes into it', aux_env.gamepad_focused() == b1)

  -- a popup (Settings, quick searches) keeps the focus inside it; B closes it
  local popup = CreateFrame('Frame', nil, layout)
  popup:SetFrameStrata('DIALOG')
  local inside = place(CreateFrame('Button', nil, popup), 2000, 300)
  pad('down')
  check('gamepad nav: an open popup takes the focus', aux_env.gamepad_focused() == inside)
  pad('B')
  check('gamepad nav: B closes the popup, aux stays open', not popup.__shown and aux_frame.__shown and aux_env.gamepad_focused() == b1)

  -- a dropdown: its menu opens outside aux; up and down walk the options, A picks one
  local dropdown = place(gui.dropdown(layout), 3000, -5000)
  typing(dropdown)
  dropdown:SetOptions{'All', 'Poor', 'Common', 'Uncommon'}
  dropdown:SetIndex(1)
  aux_env.gamepad_set_focus(dropdown)
  pad('A')
  dropdown.focus_gain()
  check('gamepad nav: A opens the dropdown', dropdown:HasFocus() and gui.dropdown_menu.__shown)
  pad('down'); pad('down')
  pad('A')
  check('gamepad nav: down twice and A picks the third option', dropdown:GetIndex() == 3 and not gui.dropdown_menu.__shown and aux_env.gamepad_focused() == dropdown)
  dropdown:SetFocus(); dropdown.focus_gain()
  pad('down')
  pad('B')
  check('gamepad nav: B closes the menu and keeps the choice', dropdown:GetIndex() == 3 and not gui.dropdown_menu.__shown)

  -- X: a right-click on the control
  local right_clicked
  local row = place(CreateFrame('Button', nil, layout), 4000, -6000)
  row:SetScript('OnClick', function(_, button) right_clicked = button end)
  rawset(row, 'Click', function(self, button) self.__scripts.OnClick(self, button) end)
  aux_env.gamepad_set_focus(row)
  pad('X')
  check('gamepad nav: X right-clicks a row', right_clicked == 'RightButton')
  box:SetText('linen')
  aux_env.gamepad_set_focus(box)
  pad('X')
  check('gamepad nav: X on a text box clears it, as a right-click does', box:GetText() == '')

  -- Y: the tab's main action (Search 1: Buy, Sniper 2: Start, Post 3: Post)
  local pressed = {}
  local quick = {
    require('aux.gui.buy_bar').primary_button,
    require('aux.tabs.sniper').run_button,
    require('aux.tabs.post').post_button,
    require('aux.tabs.auctions').cancel_button,
    require('aux.tabs.bids').buyout_button,
  }
  for i, b in ipairs(quick) do
    rawset(b, 'Click', function() pressed[i] = (pressed[i] or 0) + 1 end)
    rawset(b, 'IsVisible', function() return true end)
  end
  for i = 1, 5 do
    aux_env.set_tab(i)
    pad('Y')
  end
  check('gamepad nav: Y buys on Search, starts the Sniper, posts on Post', pressed[1] == 1 and pressed[2] == 1 and pressed[3] == 1)
  check('gamepad nav: Y cancels on Auctions and buys out on Bids', pressed[4] == 1 and pressed[5] == 1)
  aux_env.set_tab(3)
  rawset(quick[3], 'IsVisible', function() return false end)
  pad('Y')
  check('gamepad nav: Y does nothing when the action is not shown (no item picked)', pressed[3] == 1)
  rawset(quick[3], 'IsVisible', function() return true end)
  local cover = CreateFrame('Frame', nil, layout)
  cover:SetFrameStrata('DIALOG')
  place(CreateFrame('Button', nil, cover), 2000, 300)
  pad('Y')
  check('gamepad nav: Y does nothing while a popup is open', pressed[3] == 1)
  cover:Hide()
  for _, b in ipairs(quick) do rawset(b, 'Click', nil); rawset(b, 'IsVisible', nil) end
  aux_env.set_tab(1)

  aux_env.gamepad_set_focus(b1)
  pad('B')
  check('gamepad nav: B with nothing open closes aux', not aux_frame.__shown)

  layout:Hide()
  aux_frame:Show()
  -- closed while still in gamepad mode, so aux gives the pad buttons back before the stubs go
  aux_frame:Hide()
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = real[1], real[2], real[3]
  G.InputUtil, G.GamepadMode = nil, nil
  aux_frame:Show()
end)

-- aux's popups in gamepad mode: shown in a dialog of aux's own the pad can reach (a Blizzard popup
-- shown from aux's code registers with Blizzard's gamepad navigation, which taints it)
try('gamepad: aux popups open in a dialog of aux own', function()
  local aux_env = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local real = {G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown, G.StaticPopup_Show}
  local gamepad_ui, blizzard_popup = false, nil
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = function() end, function() end, function() return false end
  G.StaticPopup_Show = function(name) blizzard_popup = name end
  G.InputUtil = {IsGamepadUIEnabled = function() return gamepad_ui end}
  G.GamepadMode = setmetatable({}, {__index = function() error('aux must not touch GamepadMode') end})
  local function pad(name) local b = G['auxForeverPad' .. name]; b.__scripts.OnClick(b) end
  local accepted, cancelled, hidden = 0, 0, 0
  G.StaticPopupDialogs.AUX_TEST = {
    text = 'Post at %s?', button1 = 'Accept', button2 = 'Cancel',
    OnAccept = function(_, data) accepted = accepted + data end,
    OnCancel = function() cancelled = cancelled + 1 end,
    OnHide = function() hidden = hidden + 1 end,
  }
  local aux_frame = aux_env.frame
  aux_frame:Hide(); aux_frame:Show()

  aux_env.show_popup('AUX_TEST', '5g', nil, 1)
  check('gamepad popup: mouse and keyboard keep the game popup', blizzard_popup == 'AUX_TEST')

  gamepad_ui = true
  aux_frame:Hide(); aux_frame:Show()
  blizzard_popup = nil
  local dialog = aux_env.show_popup('AUX_TEST', '5g', nil, 1)
  for _, b in ipairs{dialog.button1, dialog.button2} do
    rawset(b, 'Click', function(self) self.__scripts.OnClick(self) end)
  end
  check('gamepad popup: shown by aux, not the game', blizzard_popup == nil and dialog and dialog.__shown and dialog.text.__text == 'Post at 5g?')
  check('gamepad popup: the focus starts on Cancel', aux_env.gamepad_focused() == dialog.button2)
  pad('A')
  check('gamepad popup: Cancel cancels and closes it, aux stays', cancelled == 1 and accepted == 0 and hidden == 1 and not dialog.__shown and aux_frame.__shown)

  aux_env.show_popup('AUX_TEST', '5g', nil, 2)
  rawset(dialog.button1, 'GetCenter', function() return 500, 100 end)
  rawset(dialog.button2, 'GetCenter', function() return 600, 100 end)
  pad('left'); pad('A')
  check('gamepad popup: Accept runs the action with its data', accepted == 2 and cancelled == 1 and not dialog.__shown)

  aux_env.show_popup('AUX_TEST', '5g', nil, 1)
  pad('B')
  check('gamepad popup: B cancels it and aux stays open', cancelled == 2 and not dialog.__shown and aux_frame.__shown)

  aux_env.show_popup('AUX_TEST', '5g', nil, 1)
  aux_env.hide_popup('AUX_TEST')
  check('gamepad popup: hidden by aux (the post went through), nothing is cancelled', cancelled == 2 and not dialog.__shown)

  -- review H-006, finding 4: a popup with a box (renaming a favorite) starts in the box, so B stops
  -- typing instead of closing it
  rawset(dialog.editBox, 'SetFocus', function(self) self.__focus = true end)
  rawset(dialog.editBox, 'ClearFocus', function(self) self.__focus = false end)
  rawset(dialog.editBox, 'HasFocus', function(self) return self.__focus == true end)
  G.StaticPopupDialogs.AUX_TEST_BOX = {
    text = 'Name', button1 = 'Accept', button2 = 'Cancel', hasEditBox = 1,
    OnShow = function(self) self.editBox:SetFocus() end,
    OnCancel = function() cancelled = cancelled + 1 end,
  }
  aux_env.show_popup('AUX_TEST_BOX')
  check('H-006 4: a popup with a box starts in the box', aux_env.gamepad_focused() == dialog.editBox)
  pad('B')
  check('H-006 4: and B stops typing, the popup stays', not dialog.editBox:HasFocus() and dialog.__shown and cancelled == 2)
  pad('B')
  check('H-006 4: a second B closes it', not dialog.__shown and cancelled == 3)
  G.StaticPopupDialogs.AUX_TEST_BOX = nil
  -- and a menu left open under the dialog (Settings is made long before it) does not take the pad
  local menu
  for _, child in ipairs{aux_frame:GetChildren()} do
    if child ~= dialog and child:GetFrameStrata() == 'DIALOG' then menu = child break end
  end
  menu:Show()
  aux_env.show_popup('AUX_TEST', '5g', nil, 1)
  pad('left')
  check('H-006 4: with a menu open under it, the pad stays in the dialog', menu ~= nil and aux_env.gamepad_focused() == dialog.button1)
  pad('B')
  menu:Hide()

  G.StaticPopupDialogs.AUX_TEST = nil
  aux_frame:Hide(); aux_frame:Show()
  -- closed while still in gamepad mode, so aux gives the pad buttons back before the stubs go
  aux_frame:Hide()
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown, G.StaticPopup_Show = real[1], real[2], real[3], real[4]
  G.InputUtil, G.GamepadMode = nil, nil
  aux_frame:Show()
end)

-- Button hints: one strip under the window with A, B, X, Y and LB/RB, each a badge with the letter or
-- the controller's own icon
try('gamepad: button hints', function()
  local aux_env = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local require = loadstring("select(2, ...) 'aux.test.gamepad_hints'; return require")('auxForever', addon)
  local gui = require 'aux.gui'
  local real = {G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown, G.C_Texture, G.C_GamePad}
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = function() end, function() end, function() return false end
  local gamepad_ui = true
  G.InputUtil = {IsGamepadUIEnabled = function() return gamepad_ui end}
  G.GamepadMode = setmetatable({}, {__index = function() error('aux must not touch GamepadMode') end})
  -- on Forever GetAtlasInfo fails (it needs Vector2DMixin, not loaded): aux must not depend on it
  G.C_Texture = {GetAtlasInfo = function() error('unable to find mixin or metatable (Vector2DMixin)') end}
  -- Blizzard's table of icons for the controller in use (InputIconTextureSetUtility), as PADChat reads it
  local icon_sets = {
    xbox = {PAD1 = 'gamepad-xbox1-buttona-normal', PAD2 = 'gamepad-xbox1-buttonb-normal', PADRSHOULDER = 'gamepad-xbox1-trigger-rb-normal'},
    ps = {PAD1 = 'gamepad-ps-buttoncrox-normal', PAD2 = 'gamepad-ps-buttoncircle-normal', PADRSHOULDER = 'gamepad-ps-triggerr1-normal'},
  }
  local controller
  local real_util = G.InputIconTextureSetUtility
  G.InputIconTextureSetUtility = {GetNormalActiveInputIconButtonTexture = function(key)
    if not controller then error('no icon set') end
    return icon_sets[controller][key]
  end}
  local function place(f, x, y)
    rawset(f, 'GetCenter', function() return x, y end)
    rawset(f, 'GetLeft', function() return x - 5 end)
    rawset(f, 'GetTop', function() return y + 5 end)
    return f
  end
  local aux_frame = aux_env.frame
  aux_env.set_tab(4)
  aux_frame:Hide(); aux_frame:Show()
  local hints = aux_env.gamepad_hints()
  local function label(key) local item = hints.items[key] return item.label.__shown and item.label:GetText() or nil end
  local function badges() local t = {} for _, key in ipairs{'A', 'B', 'X', 'Y', 'LB'} do tinsert(t, hints.items[key].badge) end tinsert(t, hints.items.LB.badge2) return t end
  for _, badge in ipairs(badges()) do
    rawset(badge.texture, 'SetAtlas', function(self, name) self.__atlas = name end)
    badge.key = nil
  end
  aux_env.update_hints()
  check('hints: the strip is shown in gamepad mode, with LB RB Tabs', hints.strip.__shown and label('LB') == 'Tabs' and hints.items.LB.badge2.__shown)
  check('hints: without the controller icons, each badge shows its letter', hints.items.A.badge.letters:GetText() == 'A' and hints.items.LB.badge2.letters:GetText() == 'RB' and not hints.items.A.badge.texture.__shown)

  local layout = CreateFrame('Frame', nil, aux_frame)
  local b1 = place(CreateFrame('Button', nil, layout), 1000, 600)
  local box = place(gui.editbox(layout), 1000, 550)
  local dropdown = place(gui.dropdown(layout), 1000, 500)
  aux_env.gamepad_set_focus(b1); aux_env.update_hints()
  check('hints: on a button, A selects, B closes, X right-clicks', label('A') == 'Select' and label('B') == 'Close' and label('X') == 'Right-click')
  aux_env.gamepad_set_focus(box); aux_env.update_hints()
  check('hints: on a text box, A types and X clears', label('A') == 'Type' and label('X') == 'Clear')
  rawset(box, 'HasFocus', function() return true end); aux_env.update_hints()
  check('hints: while typing, B is Done and there is no A', label('B') == 'Done' and label('A') == nil)
  check('hints: a hint left out leaves no gap (B moves to the start)', hints.items.B.after == false)
  rawset(box, 'HasFocus', nil)
  aux_env.gamepad_set_focus(dropdown); aux_env.update_hints()
  check('hints: on a dropdown, A opens it', label('A') == 'Open')
  rawset(dropdown, 'HasFocus', function() return true end)
  dropdown:SetOptions{'All', 'Poor'}
  dropdown.focus_gain(); aux_env.update_hints()
  check('hints: with its menu open, A picks and B closes, no X', label('A') == 'Pick' and label('B') == 'Close' and label('X') == nil)
  gui.dropdown_menu:Hide(); rawset(dropdown, 'HasFocus', nil)

  -- Y: named for the tab's action (Auctions: Cancel), only while its button can be pressed
  local cancel = require('aux.tabs.auctions').cancel_button
  rawset(cancel, 'IsVisible', function() return true end)
  rawset(cancel, 'IsEnabled', function() return false end)
  aux_env.update_hints()
  check('hints: no Y while its button is greyed out', label('Y') == nil)
  rawset(cancel, 'IsEnabled', function() return true end)
  aux_env.update_hints()
  check('hints: Y Cancel on Auctions', label('Y') == 'Cancel')
  local cover = CreateFrame('Frame', nil, layout)
  cover:SetFrameStrata('DIALOG')
  aux_env.update_hints()
  check('hints: no Y while a popup is open', label('Y') == nil)
  cover:Hide()
  rawset(cancel, 'IsVisible', nil); rawset(cancel, 'IsEnabled', nil)
  local buy = require('aux.gui.buy_bar').primary_button
  rawset(buy, 'IsVisible', function() return true end)
  rawset(buy, 'IsEnabled', function() return true end)
  aux_env.set_tab(1)
  buy:SetText('Buy 5 for 1g'); aux_env.update_hints()
  check('hints: Y Buy on Search', label('Y') == 'Buy')
  buy:SetText('Confirm 1g'); aux_env.update_hints()
  check('hints: Y Confirm once the price is known', label('Y') == 'Confirm')
  rawset(buy, 'IsVisible', nil); rawset(buy, 'IsEnabled', nil)

  controller = 'xbox'; aux_env.update_hints()
  check('hints: the Xbox icons from Blizzard\'s table', hints.items.A.badge.texture.__atlas == 'gamepad-xbox1-buttona-normal' and hints.items.A.badge.texture.__shown and hints.items.A.badge.letters:GetText() == '')
  controller = 'ps'; aux_env.update_hints()
  check('hints: switching to a PlayStation controller switches the icons', hints.items.B.badge.texture.__atlas == 'gamepad-ps-buttoncircle-normal' and hints.items.LB.badge2.texture.__atlas == 'gamepad-ps-triggerr1-normal')
  check('hints: a key the table has no icon for keeps its letter', hints.items.X.badge.letters:GetText() == 'X' and not hints.items.X.badge.texture.__shown)

  aux_env.blizzard_button.__scripts.OnClick(aux_env.blizzard_button)
  check('hints: hidden while Blizzard UI has the pad', not hints.strip.__shown)
  aux_env.blizzard_button.__scripts.OnClick(aux_env.blizzard_button)
  check('hints: back when aux has it again', hints.strip.__shown)
  aux_frame:Hide()
  check('hints: hidden when aux closes', not hints.strip.__shown)

  layout:Hide()
  gamepad_ui = false
  aux_frame:Show()
  check('hints: none with mouse and keyboard', not hints.strip.__shown)
  aux_frame:Hide(); aux_frame:Show()
  aux_env.set_tab(1)
  -- closed while still in gamepad mode, so aux gives the pad buttons back before the stubs go
  aux_frame:Hide()
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown, G.C_Texture, G.C_GamePad = real[1], real[2], real[3], real[4], real[5]
  G.InputUtil, G.GamepadMode, G.InputIconTextureSetUtility = nil, nil, real_util
  aux_frame:Show()
end)

-- Sniper by pad: A on a deal moves the focus to the buy bar's Buy once it shows (it shows only after
-- the deal is checked); B goes back to the deal. Y stays Start/Stop, so Y never buys on the Sniper.
try('gamepad: A on a Sniper deal jumps to Buy', function()
  local aux_env = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local require = loadstring("select(2, ...) 'aux.test.gamepad_sniper'; return require")('auxForever', addon)
  local real = {G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown}
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = function() end, function() end, function() return false end
  G.InputUtil = {IsGamepadUIEnabled = function() return true end}
  G.GamepadMode = setmetatable({}, {__index = function() error('aux must not touch GamepadMode') end})
  local function pad(name) local b = G['auxForeverPad' .. name]; b.__scripts.OnClick(b) end
  local aux_frame = aux_env.frame
  aux_frame:Hide(); aux_frame:Show()
  aux_env.set_tab(2)
  local deal = CreateFrame('Button', nil, require('aux.tabs.sniper').deals_list)
  local picked
  deal:SetScript('OnClick', function() picked = true end)
  rawset(deal, 'Click', function(self) self.__scripts.OnClick(self) end)
  local buy = require('aux.gui.buy_bar').primary_button
  local shown = false
  rawset(buy, 'IsVisible', function() return shown end)

  aux_env.gamepad_set_focus(deal)
  pad('A')
  check('sniper pad: A picks the deal; Buy is not shown yet, the focus waits', picked and aux_env.gamepad_focused() == deal)
  shown = true
  aux_env.gamepad_poll()
  check('sniper pad: once Buy shows, the focus moves to it', aux_env.gamepad_focused() == buy)
  aux_env.update_hints()
  check('sniper pad: B says Back there', aux_env.gamepad_hints().items.B.label:GetText() == 'Back')
  pad('B')
  check('sniper pad: B goes back to the deal, aux stays open', aux_env.gamepad_focused() == deal and aux_frame.__shown)

  shown = false
  pad('A')
  clock = clock + 6
  shown = true
  aux_env.gamepad_poll()
  check('sniper pad: a deal that never shows Buy (gone) is given up after 5 seconds', aux_env.gamepad_focused() == deal)
  shown = false
  pad('A')
  pad('down')
  shown = true
  aux_env.gamepad_poll()
  check('sniper pad: another press cancels the jump', aux_env.gamepad_focused() ~= buy)

  rawset(buy, 'IsVisible', nil)
  deal:Hide()
  aux_env.set_tab(1)
  aux_frame:Hide(); aux_frame:Show()
  -- closed while still in gamepad mode, so aux gives the pad buttons back before the stubs go
  aux_frame:Hide()
  G.SetOverrideBindingClick, G.ClearOverrideBindings, G.InCombatLockdown = real[1], real[2], real[3]
  G.InputUtil, G.GamepadMode = nil, nil
  aux_frame:Show()
end)

-- 0.7 (FB-013, HoaxBox): an item level column, and the required level colored by how far it is from
-- the player's level (Tyler, 2026-10-13: red far above, then orange, yellow, green; gray far below)
try('0.7: Req and iLvl columns', function()
  local require = loadstring("select(2, ...) 'aux.test.ilvl'; return require")('auxForever', addon)
  local aux = require 'aux'
  local al = loadstring("select(2, ...) 'aux.gui.auction_listing'; return _M")('auxForever', addon)
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local c = aux.color
  -- the colors, at level 24 (gray at 17 and below) and at 60 (gray at 47 and below)
  check('req: 5 or more levels above is red', al.requirement_color(29, 24) == c.red and al.requirement_color(40, 24) == c.red)
  check('req: 3 to 4 above is orange', al.requirement_color(27, 24) == c.orange and al.requirement_color(28, 24) == c.orange)
  check('req: 1 to 2 above is yellow', al.requirement_color(25, 24) == c.yellow and al.requirement_color(26, 24) == c.yellow)
  check('req: usable is green', al.requirement_color(24, 24) == c.green and al.requirement_color(18, 24) == c.green)
  check('req: far below is gray', al.requirement_color(17, 24) == c.trivial and al.requirement_color(1, 24) == c.trivial)
  check('req: at 60, 48 is green and 47 gray', al.requirement_color(48, 60) == c.green and al.requirement_color(47, 60) == c.trivial)
  check('req: nothing is gray up to level 5', al.requirement_color(1, 5) == c.green)
  check('req: gray levels follow Classic', al.gray_level(24) == 17 and al.gray_level(39) == 31 and al.gray_level(40) == 31 and al.gray_level(60) == 47)
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  check('req: the gray is in both themes', a.PALETTES.new.trivial ~= nil and a.PALETTES.classic.trivial ~= nil)

  -- the cells
  local cell = {text = new_frame()}
  al.search_columns[1].fill(cell, {requirement = 65})
  check('req cell: colored text', tostring(cell.text.__text):find('^|c') ~= nil and tostring(cell.text.__text):find('65', 1, true) ~= nil)
  al.search_columns[2].fill(cell, {item_level = 52})
  check('ilvl cell: the item level', cell.text.__text == 52)
  al.search_columns[2].fill(cell, {})
  check('ilvl cell: empty when not gear', cell.text.__text == '')
  check('ilvl: sorts by item level', al.search_columns[2].cmp({item_level = 30}, {item_level = 52}, false) ~= al.search_columns[2].cmp({item_level = 52}, {item_level = 30}, false))

  -- the other tables with a level column
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  check('auctions tab: Req, iLvl, Item', auctions.columns[1].title == 'Req' and auctions.columns[2].title == 'iLvl' and auctions.columns[3].title == 'Item')
  check('sniper: Req, iLvl, Item after Found', sniper.columns[2].title == 'Req' and sniper.columns[3].title == 'iLvl' and sniper.columns[4].title == 'Item')
  local function after_item(columns) for i, col in ipairs(columns) do if col.title == 'Item' then return columns[i + 1].title end end end
  check('for sale follows the item everywhere', after_item(al.search_columns) == 'For sale' and after_item(sniper.columns) == 'For sale' and after_item(al.bids_columns) == 'Quantity' and after_item(auctions.columns) == 'Qty')
  check('auctions tab: sorted by item within status', auctions.listing.sorts[2] and auctions.listing.columns[auctions.listing.sorts[2].index].title == 'Item')
  al.search_columns[1].fill(cell, {requirement = 65, deal_gone = true})
  check('req cell: a gone deal is dimmed, not colored by level', cell.text.__text == c.label.disabled(65))
  -- the default sorts still end on the same columns after the new one
  local function primary(listing) local col = listing.columns[listing.sorts[1].index] return type(col.title) == 'table' and col.title[1] or col.title end
  check('auctions tab: sorted by status first', primary(auctions.listing) == 'Status')
  local bids = loadstring("select(2, ...) 'aux.tabs.bids'; return _M")('auxForever', addon)
  check('bids tab: sorted by status first', primary(bids.listing) == 'Status')
  local src = io.open('tabs/search/results.lua'):read('*a')
  check('search: the default sort covers all 9 columns', src:find('SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)', 1, true) ~= nil)

  -- item levels in records: gear only, the auction house's item key first
  local real_info = G.GetItemInfo
  G.GetItemInfo = function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if id == 213001 then return 'Test Blade', 'link', 3, 30, 25, 'Weapon', 'Daggers', 1, 'INVTYPE_WEAPON', 1, 900 end
    if id == 213002 then return 'Test Cloth', 'link', 1, 15, 0, 'Trade Goods', 'Cloth', 20, '', 1, 10 end
    if id == 213003 then return 'Test Bag', 'link', 1, 25, 0, 'Container', 'Bag', 1, 'INVTYPE_BAG', 1, 10 end
  end
  local blade = info.browse_record({itemKey = {itemID = 213001, itemSuffix = 0}, totalQuantity = 1, minPrice = 5000})
  check('ilvl: gear has its item level', blade and blade.item_level == 30)
  blade = info.browse_record({itemKey = {itemID = 213001, itemSuffix = 0, itemLevel = 33}, totalQuantity = 1, minPrice = 5000})
  check('ilvl: the item key\'s level wins', blade and blade.item_level == 33)
  local cloth = info.browse_record({itemKey = {itemID = 213002, itemSuffix = 0, itemLevel = 15}, totalQuantity = 1, minPrice = 5000})
  check('ilvl: trade goods have none', cloth and cloth.item_level == nil)
  local bag = info.browse_record({itemKey = {itemID = 213003, itemSuffix = 0}, totalQuantity = 1, minPrice = 5000})
  check('ilvl: bags have none', bag and bag.item_level == nil)
  local row = info.item_search_record({itemKey = {itemID = 213001, itemSuffix = 0, itemLevel = 31}, itemLink = '|cff0070dd|Hitem:213001::::::::|h[Test Blade]|h|r', auctionID = 1, quantity = 1, buyoutAmount = 5000, minBid = 0, bidAmount = 0, owners = {'Seller'}, totalNumberOfOwners = 1, containsOwnerItem = false, timeLeft = 3})
  check('ilvl: an item search row has it too', row and row.item_level == 31)
  G.GetItemInfo = real_info
  for _, id in ipairs{213001, 213002, 213003} do aux.account_data.items[id] = nil end
  for _, name in ipairs{'test blade', 'test cloth', 'test bag'} do
    aux.account_data.item_ids[name] = nil
    for i = #aux.account_data.auctionable_items, 1, -1 do if aux.account_data.auctionable_items[i] == name then tremove(aux.account_data.auctionable_items, i) end end
  end
end)

-- 0.7 (FB-012, MDHippie): prices for other addons in the global AuxForeverAPI (docs/api.md)
try('0.7: AuxForeverAPI', function()
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local api = G.AuxForeverAPI
  check('api: a global table', type(api) == 'table')
  check('api: version 1', api.version == 1)
  check('api: ready after login', api.IsReady() == true)
  local d = h.today()
  h.write_record('214001:0', {day = d, market = 1200, units = 8, low = 1100, points = {{value = 1000, day = d - 1, units = 5}, {value = 1000, day = d - 2, units = 5}}})
  -- 0.8: gear with a random ending is priced under its ending (info.price_key)
  h.write_record('214001:of the eagle', {day = d, market = 9000, units = 1, low = 9000, points = {}})
  local real_get_info = G.GetItemInfo
  G.GetItemInfo = function(x) if x == 214001 then return 'Thing' end return real_get_info(x) end
  local latest, age = api.GetLatestPrice(214001)
  check('api: the latest price by item ID', latest == 1200 and age == 0)
  check('api: by ID as text and by item string', api.GetLatestPrice('214001') == 1200 and api.GetLatestPrice('item:214001::::::') == 1200)
  check('api: by link, with its random ending', api.GetLatestPrice('|cff1eff00|Hitem:214001::::::1234:::|h[Thing of the Eagle]|h|r') == 9000)
  G.GetItemInfo = real_get_info
  check('api: same as the tooltip Value', api.GetLatestPrice(214001) == h.latest('214001:0'))
  local usual, seen = api.GetUsualPrice(214001)
  check('api: the usual price', usual == h.value('214001:0') and seen == 0)
  check('api: unknown items give nil', api.GetLatestPrice(214999) == nil and api.GetUsualPrice(214999) == nil)
  check('api: bad input gives nil, not an error', api.GetLatestPrice(nil) == nil and api.GetLatestPrice({}) == nil and api.GetLatestPrice('Linen Cloth') == nil and api.GetUsualPrice(-3) == nil)
  h.data['214001:0'], h.data['214001:1234'] = nil, nil
  local src = io.open('core/api.lua'):read('*a')
  check('api: no frame or timer of its own (performance)', not src:find('CreateFrame', 1, true) and not src:find('coro_thread', 1, true) and not src:find('OnUpdate', 1, true))
end)

-- 0.7 build 3 (Tyler): after a fast resize down to the smallest window, the result table kept the
-- width of a step before and its right columns ran past the window's edge. It now lays out with the
-- width its content area reports, later refreshes keep that width, and the last column is anchored
-- to the right edge.
try('0.7: result tables follow a fast resize', function()
  local al = loadstring("select(2, ...) 'aux.gui.auction_listing'; return _M")('auxForever', addon)
  local real_create = G.CreateFrame
  G.CreateFrame = function(...)
    local f = real_create(...)
    rawset(f, 'SetPoint', function(self, p) self.__points = self.__points or {}; table.insert(self.__points, p) end)
    rawset(f, 'SetWidth', function(self, w) self.__w = w end)
    return f
  end
  local ok, rt = pcall(al.new, new_frame(), 19, al.search_columns)
  G.CreateFrame = real_create
  check('resize: table built', ok)
  if not ok then return end
  local function has(f, point) for _, p in ipairs(f.__points or {}) do if p == point then return true end end return false end
  local last = rt.headCells[#rt.headCells]
  check('resize: the last header column is anchored to the right edge', has(last, 'TOPRIGHT'))
  check('resize: the content area lays the table out when it changes size', rt.contentFrame.__scripts.OnSizeChanged ~= nil)
  local total = 0
  for _, c in ipairs(al.search_columns) do total = total + c.width end
  local function first_width() return rt.headCells[1].__w end
  local function near(a, b) return a and math.abs(a - b) < .01 end
  -- the old way of measuring still sees the wide window
  rawset(rt.contentFrame, 'GetLeft', function() return 0 end)
  rawset(rt.contentFrame, 'GetRight', function() return 1400 end)
  rt.contentFrame.__scripts.OnSizeChanged(rt.contentFrame, 1400, 300)
  check('resize: wide window', near(first_width(), 1400 * al.search_columns[1].width / total))
  -- one big step down to the smallest window, as in a fast drag
  rt.contentFrame.__scripts.OnSizeChanged(rt.contentFrame, 980, 300)
  check('resize: the reported width is used', near(first_width(), 980 * al.search_columns[1].width / total))
  rt:UpdateRows()
  rt:ResizeColumns()
  check('resize: a later refresh keeps the new width, not a stale measure', near(first_width(), 980 * al.search_columns[1].width / total))
  -- shown again after the window changed while hidden: measured again
  rawset(rt.contentFrame, 'GetRight', function() return 1200 end)
  rawset(rt, 'GetHeight', function() return 300 end)
  G.CreateFrame = function(...)
    local f = real_create(...)
    rawset(f, 'SetPoint', function(self, p) self.__points = self.__points or {}; table.insert(self.__points, p) end)
    return f
  end
  pcall(rt.__scripts.OnShow, rt)
  G.CreateFrame = real_create
  check('resize: shown again, the table measures its width', near(first_width(), 1200 * al.search_columns[1].width / total))
  local row = rt.all_rows and rt.all_rows[1]
  check('resize: the last cell of a row is anchored to the right edge', row and has(row.cells[#row.cells], 'TOPRIGHT'))
end)

-- 0.8 (FB-020, Harro22): Waylaid Crates. The bundles come from the crate's tooltip text, as seen in
-- game (Tyler, 2026-10-20); each is priced like a recipe's materials, less what is in the bags.
try('0.8: Waylaid Crates', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local aux = loadstring("select(2, ...) 'aux.test.crate'; return require 'aux'")('auxForever', addon)
  local today = h.today()
  -- the tooltip as the game shows it: the Use line holds the list, one row per line
  local textiles = {'Waylaid Crate: Journeyman Textiles',
    '|cff00ff00Use: Fill the crate with any bundle from the following list:\n- 20 Wool Cloth\n- 40 Silk Cloth\n- 20 Medium Leather|r',
    'Requires Level 10', 'Value: 60s seen today'}
  local b = search.crate_bundles_from_text(textiles)
  check('crate: three bundles read from the tooltip', b and #b == 3 and b[1].name == 'Wool Cloth' and b[1].count == 20 and b[2].name == 'Silk Cloth' and b[2].count == 40 and b[3].name == 'Medium Leather')
  -- the same list when the game gives each row its own line
  local fabrics = search.crate_bundles_from_text({'Waylaid Crate: Journeyman Fabrics', 'Use: Fill the crate with any bundle from the following list:', '- 6 Bolt of Woolen Cloth', '- 10 Bolt of Silk Cloth', '- 2 Cured Medium Hide', 'Requires Level 10'})
  check('crate: rows on lines of their own', fabrics and #fabrics == 3 and fabrics[1].name == 'Bolt of Woolen Cloth' and fabrics[1].count == 6 and fabrics[3].count == 2)
  check('crate: an item that is not a crate has no bundles', search.crate_bundles_from_text({'Medicine Staff of the Wolf', '+4 Agility', '+5 Spirit', 'Requires Level 14'}) == nil)
  -- review H-006, finding 6: a negative stat reads like a bundle row; only a crate's Use line opens the list
  check('H-006 6: "-5 Spirit" on gear is not a crate', search.crate_bundles_from_text({'Ring of Odd Luck', '+8 Agility', '-5 Spirit', 'Requires Level 20'}) == nil)
  -- build 14 (Tyler, build 13: crates in aux's results showed no bundles): the game loads a crate's
  -- Use text after the item; a tooltip read before that must not mark it "not a crate"
  do
    local real_get, real_item, real_spell = G.GetItemInfo, G.C_Item, G.C_Spell
    local loaded = false
    G.GetItemInfo = function(x)
      if x == 990004 or (type(x) == 'string' and x:find('item:990004', 1, true)) then return 'Waylaid Crate: Journeyman Herbs', 'item:990004', 2, 10, 10, 'Miscellaneous', 'Junk', 1, '', 1, 0 end
      return real_get(x)
    end
    G.C_Item = setmetatable({GetItemSpell = function(id) if id == 990004 then return 'Fill', 4242 end end}, {__index = real_item})
    G.C_Spell = {IsSpellDataCached = function() return loaded end, RequestLoadSpellData = function() end}
    local early = search.crate_bundles(990004, {'Waylaid Crate: Journeyman Herbs', 'Requires Level 10'})
    loaded = true
    local herbs = search.crate_bundles(990004, {'Waylaid Crate: Journeyman Herbs', 'Use: Fill the crate with any bundle from the following list:', '- 10 Stranglekelp', '- 10 Kingsblood', 'Requires Level 10'})
    check('build 14: a crate read before its Use text loaded is read again', early == nil and herbs and #herbs == 2 and herbs[1].name == 'Stranglekelp')
    check('build 14: an item with no use spell is still read once', search.crate_bundles(990005, {'Copper Bar'}) == nil)
    G.GetItemInfo, G.C_Item, G.C_Spell = real_get, real_item, real_spell
  end
  check('crate: read once per crate', search.crate_bundles(990001, textiles) == search.crate_bundles(990001) and search.crate_bundles(990002, {'Linen Cloth'}) == nil)

  -- prices: Wool 30c each (latest), Silk 15c each, Medium Leather unknown to aux
  local ids = aux.account_data.item_ids
  ids['wool cloth'], ids['silk cloth'] = 2592, 4306
  h.write_record('2592:0', {day = today, points = {{day = today - 1, value = 30}}})
  h.write_record('4306:0', {day = today, points = {{day = today - 1, value = 15}}})
  local bags = {}
  local real_item = G.C_Item
  G.C_Item = {GetItemCount = function(id) return bags[id] or 0 end}
  local rows, cheapest = search.crate_costs(b)
  check('crate: each bundle priced', rows[1].cost == 600 and rows[2].cost == 600 and rows[3].cost == nil)
  check('crate: a tie keeps the first listed', cheapest == 1)
  h.write_record('4306:0', {day = today, points = {{day = today - 1, value = 14}}})
  rows, cheapest = search.crate_costs(b)
  check('crate: the cheapest bundle is found', cheapest == 2 and rows[2].cost == 560)
  -- what is already in the bags is not bought again
  bags[2592] = 15
  rows, cheapest = search.crate_costs(b)
  check('crate: bags count, only the rest is priced', rows[1].have == 15 and rows[1].need == 5 and rows[1].cost == 150 and cheapest == 1)
  bags[2592] = 25
  rows, cheapest = search.crate_costs(b)
  check('crate: a bundle already in the bags costs nothing', rows[1].need == 0 and rows[1].cost == 0 and rows[1].source == 'bags' and cheapest == 1)
  -- no bundle with a price: no cheapest
  local none = search.crate_costs({{name = 'Medium Leather', count = 20}})
  check('crate: nothing priced, no cheapest', select(2, search.crate_costs({{name = 'Medium Leather', count = 20}})) == nil and none[1].cost == nil)

  G.C_Item = real_item
  ids['wool cloth'], ids['silk cloth'] = nil, nil
end)

-- 0.8: what aux shows for a crate (option A of the mockup, Tyler 2026-10-20) and the crate search
-- (option C: Alt-click a crate in the bags searches every bundle)
try('0.8: Waylaid Crates in the tooltip and the search', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local shortcut = loadstring("select(2, ...) 'aux.core.shortcut'; return _M")('auxForever', addon)
  local aux = loadstring("select(2, ...) 'aux.test.crate2'; return require 'aux'")('auxForever', addon)
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local today = h.today()
  local ids = aux.account_data.item_ids
  ids['wool cloth'], ids['silk cloth'] = 2592, 4306
  h.write_record('2592:0', {day = today, points = {{day = today - 1, value = 32}}})
  h.write_record('4306:0', {day = today, points = {{day = today - 1, value = 14}}})
  local bags = {[2592] = 12}
  local real_item, real_info = G.C_Item, G.C_TooltipInfo
  G.C_Item = setmetatable({GetItemCount = function(id) return bags[id] or 0 end}, {__index = real_item})
  local crate_lines = {{leftText = 'Waylaid Crate: Journeyman Textiles'},
    {leftText = 'Use: Fill the crate with any bundle from the following list:\n- 20 Wool Cloth\n- 40 Silk Cloth\n- 20 Medium Leather'},
    {leftText = 'Requires Level 10'}}

  -- the tooltip: every bundle, the cheapest in gold, the bags counted
  local lines, colors = {}, {}
  local tip = new_frame()
  rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
  rawset(tip, 'AddDoubleLine', function(_, a, b, r, g, bl) tinsert(lines, plain(a) .. ' | ' .. plain(b)); colors[plain(a)] = {r, g, bl} end)
  local reads = 0
  local function data() reads = reads + 1; return {lines = crate_lines} end
  tooltip.extend_tooltip(tip, '|cffffffff|Hitem:248698::::::0:0|h[Waylaid Crate: Journeyman Textiles]|h|r', 1, data())
  local all = table.concat(lines, '\n')
  check('crate tooltip: says what it shows', all:find('Cheapest way to fill it', 1, true) and all:find('Latest prices, less what is in your bags', 1, true))
  check('crate tooltip: a bundle partly in the bags, priced for the rest', all:find('20 Wool Cloth (12 in bags) | 2s 56c', 1, true) ~= nil)
  check('crate tooltip: the others', all:find('40 Silk Cloth | 5s 60c', 1, true) and all:find('20 Medium Leather | no price yet', 1, true))
  local gold = {aux.color.accent.background()}
  local wool = colors['20 Wool Cloth (12 in bags)']
  check('crate tooltip: the cheapest is in the accent gold, the others white', wool and wool[1] == gold[1] and wool[2] == gold[2] and colors['40 Silk Cloth'][1] == 1)
  bags[2592] = 20
  lines = {}
  tooltip.extend_tooltip(tip, '|cffffffff|Hitem:248698::::::0:0|h[Waylaid Crate: Journeyman Textiles]|h|r', 1, data())
  check('crate tooltip: a bundle already in the bags says so', table.concat(lines, '\n'):find('20 Wool Cloth | in your bags', 1, true) ~= nil)
  lines = {}
  tooltip.extend_tooltip(tip, '|cffffffff|Hitem:4575::::::0:0|h[Medicine Staff]|h|r', 1, {lines = {{leftText = 'Medicine Staff'}, {leftText = '+4 Agility'}}})
  check('crate tooltip: other items get no crate lines', not table.concat(lines, '\n'):find('Cheapest way', 1, true))
  -- the font strings, when the game hands no tooltip data
  local named = new_frame()
  rawset(named, 'GetName', function() return 'AuxCrateTip' end)
  rawset(named, 'NumLines', function() return 2 end)
  G.AuxCrateTipTextLeft1, G.AuxCrateTipTextLeft2 = new_frame(), new_frame()
  G.AuxCrateTipTextLeft1:SetText('Use: Fill the crate with any bundle from the following list:')
  G.AuxCrateTipTextLeft2:SetText('- 6 Bolt of Woolen Cloth')
  local texts = search.tooltip_texts(named, nil)
  check('crate tooltip: lines read from the tooltip itself', #texts == 2 and texts[2] == '- 6 Bolt of Woolen Cloth')
  G.AuxCrateTipTextLeft1, G.AuxCrateTipTextLeft2 = nil, nil

  -- live prices: the cheapest listings first, as many as the bundle needs
  local records = {
    {name = 'Wool Cloth', buyout_price = 300, count = 10, unit_buyout_price = 30},
    {name = 'Wool Cloth', buyout_price = 2000, count = 50, unit_buyout_price = 40},
    {name = 'Silk Cloth', buyout_price = 1400, count = 100, unit_buyout_price = 14},
    {name = 'Silk Cloth', buyout_price = 10, count = 1, unit_buyout_price = 10, own = true},
  }
  local parts = {crate = true, name = 'Journeyman Textiles', bundles = {{name = 'Wool Cloth', count = 20}, {name = 'Silk Cloth', count = 40}, {name = 'Medium Leather', count = 20}}, reagents = {}}
  bags[2592] = 0
  local rows, cheapest = search.crate_live_costs(parts, records)
  check('crate search: 10 at 30c then 10 at 40c', rows[1].cost == 700)
  check('crate search: your own auctions are not bought', rows[2].cost == 560 and cheapest == 2)
  check('crate search: nothing listed, the bundle cannot be filled', rows[3].short == 20)
  bags[2592] = 12
  rows, cheapest = search.crate_live_costs(parts, records)
  check('crate search: the bags change the cheapest', rows[1].cost == 240 and cheapest == 1)

  -- Alt-click a crate in the bags with aux open: one search for every bundle, the crate kept with it
  local run, restore = fake_ah({
    {id = 2592, name = 'Wool Cloth', commodity = true, min = 30, qty = 60, auctions = {{qty = 10, buyout = 30}, {qty = 50, buyout = 40}}},
    {id = 4306, name = 'Silk Cloth', commodity = true, min = 14, qty = 100, auctions = {{qty = 100, buyout = 14}}},
    {id = 4234, name = 'Medium Leather', commodity = true, min = 0, qty = 0, auctions = {}},
  })
  G.C_TooltipInfo = {GetHyperlink = function() return {lines = crate_lines} end}
  search.update_mode(search.NORMAL_MODE)
  local was_shown = aux.frame.__shown
  aux.frame.__shown = true
  local real_alt = IsAltKeyDown
  G.IsAltKeyDown = function() return true end
  shortcut.on_modified_click('|cff1eff00|Hitem:248711::::::0:0|h[Waylaid Crate: Journeyman Textiles]|h|r')
  G.IsAltKeyDown = real_alt
  run(120)
  local s = search.current_search()
  check('crate search: Alt-click searches every bundle', search.search_box:GetText() == 'wool cloth/exact;silk cloth/exact;medium leather/exact')
  check('crate search: the search knows its crate', s.recipe and s.recipe.crate and s.recipe.name == 'Journeyman Textiles')
  search.update_results_summary(true)
  local summary = plain(search.recipe_label.__text)
  check('crate search: the bottom bar names the cheapest fill', summary:find('Crate  Journeyman Textiles', 1, true) and summary:find('cheapest fill  20 Wool Cloth (12 in bags)  2s 40c', 1, true) ~= nil)
  check('crate search: and the next one', summary:find('next  40 Silk Cloth  5s 60c', 1, true) ~= nil)
  check('crate search: named as a crate in Recent searches', plain(search.recipe_entry_name(s)):find('Crate  Journeyman Textiles  (3 bundles)', 1, true) ~= nil)
  -- a plain Alt-click on something that is not a crate still brings the item into aux
  G.C_TooltipInfo = {GetHyperlink = function() return {lines = {{leftText = 'Spellbinder Robe'}}} end}
  aux.frame.__shown = was_shown
  restore()

  G.C_Item, G.C_TooltipInfo = real_item, real_info
  ids['wool cloth'], ids['silk cloth'] = nil, nil
end)

-- 0.8, gear versions: gear with a random ending is priced per ending. On Forever a link's suffix
-- field is empty (Medicine Staff of the Wolf, seen 2026-10-20), so every ending used to share one
-- price; the auction house's versions of one name have the same stats (seen 2026-10-20), so the
-- name is the key, as Blizzard's Sell window groups gear.
try('0.8: gear versions', function()
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local scan_exports = loadstring("select(2, ...) 'aux.test.gear'; return require 'aux.core.scan'")('auxForever', addon)
  local real_get_info = G.GetItemInfo
  G.GetItemInfo = function(x)
    if x == 4575 then return 'Medicine Staff' end
    if type(x) == 'string' and x:find('item:4575', 1, true) then return x:match('|h%[(.-)%]|h'), x end
    return real_get_info(x)
  end
  local function link(name) return '|cff1eff00|Hitem:4575::::::::24:1487::1:1:12726:1:28:5254::::|h[' .. name .. ']|h|r' end

  check('gear: an ending is part of the price key', info.price_key(4575, 'Medicine Staff of the Wolf') == '4575:of the wolf')
  check('gear: the link Tyler printed, ending from its name', info.link_price_key(link('Medicine Staff of the Wolf')) == '4575:of the wolf')
  check('gear: no ending, the key as before', info.price_key(4575, 'Medicine Staff') == '4575:0' and info.price_key(2589, 'Linen Cloth') == '2589:0')
  check('gear: no name, the key as before', info.price_key(4575, nil) == '4575:0')
  local real_key_info = rawget(C_AuctionHouse, 'GetItemKeyInfo')
  rawset(C_AuctionHouse, 'GetItemKeyInfo', function(key) return key.itemSuffix == 103 and {itemName = 'Medicine Staff of Arcane Protection'} or nil end)
  check('gear: an auction house version is keyed by its name', info.item_key_price_key({itemID = 4575, itemSuffix = 103}) == '4575:of arcane protection')
  check('gear: a version whose name has not loaded has no key yet', info.item_key_price_key({itemID = 4575, itemSuffix = 999}) == nil)
  check('gear: version 0 needs no name', info.item_key_price_key({itemID = 2589, itemSuffix = 0}) == '2589:0')
  rawset(C_AuctionHouse, 'GetItemKeyInfo', real_key_info)

  -- the tooltip of each ending shows that ending's price (all three showed 1g 50s before)
  local d = h.today()
  h.write_record('4575:of the wolf', {day = d, market = 15000, units = 1, low = 15000, points = {}})
  h.write_record('4575:of the bandit', {day = d, market = 11500, units = 1, low = 11500, points = {}})
  local function value_line(name)
    local lines = {}
    local tip = new_frame()
    rawset(tip, 'AddLine', function(_, text) tinsert(lines, text) end)
    rawset(tip, 'AddDoubleLine', function() end)
    tooltip.extend_tooltip(tip, link(name), 1, {lines = {}})
    for _, l in ipairs(lines) do if l:find('^Value') then return l end end
    return ''
  end
  rawset(AuxTooltip, 'NumLines', function() return 0 end)
  local wolf, bandit = value_line('Medicine Staff of the Wolf'), value_line('Medicine Staff of the Bandit')
  rawset(AuxTooltip, 'NumLines', nil)
  local function plain(t) return (t:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  check('gear: the Wolf staff shows the Wolf price', plain(wolf):find('Value: 1.50', 1, true) ~= nil)
  check('gear: the Bandit staff shows the Bandit price', plain(bandit):find('Value: 1.15', 1, true) ~= nil)

  -- prices seen in a search go to the ending's key
  h.process_auction({item_key = '4575:0', price_key = '4575:of the tiger', buyout_price = 9000, count = 1})
  check('gear: a search records the price under the ending', h.market_value('4575:of the tiger') == 9000 and h.market_value('4575:0') ~= 9000)

  -- the Auctions tab checks gear against every listing of its name: one name search for the item
  -- (the search is made from the item's own name, which the game gives for a plain item string)
  local gear_get_info = G.GetItemInfo
  G.GetItemInfo = function(x)
    if type(x) == 'string' and x:find('^item:4575') then return 'Medicine Staff', x end
    return gear_get_info(x)
  end
  local params
  local real_start = scan_exports.start
  rawset(scan_exports, 'start', function(p) params = p end)
  local mine = {item_id = 4575, price_key = '4575:of arcane protection', item_search_key = {itemID = 4575, itemSuffix = 103},
    unit_buyout_price = 12000, buyout_price = 12000, sale_status = 0}
  local cloth = {item_id = 2589, price_key = '2589:0', item_search_key = {itemID = 2589, itemSuffix = 0},
    unit_buyout_price = 20, buyout_price = 20, sale_status = 0}
  local real_records = auctions.listing.records
  auctions.listing.records = {mine, cloth}
  auctions.check_prices()
  local by_key, by_name = 0, 0
  for _, q in ipairs(params and params.queries or {}) do
    if q.item_keys then by_key = by_key + #q.item_keys elseif q.blizzard_query then by_name = by_name + 1 end
  end
  check('gear: cloth is read by its item key, the staff by a name search', by_key == 1 and by_name == 1)
  params.on_auction({item_id = 4575, price_key = '4575:of arcane protection', unit_buyout_price = 11000, seller_count = 1})
  params.on_auction({item_id = 4575, price_key = '4575:of arcane protection', unit_buyout_price = 11500, seller_count = 1})
  params.on_auction({item_id = 4575, price_key = '4575:of the wolf', unit_buyout_price = 9000, seller_count = 1})
  params.on_complete()
  local status, by, lowest = auctions.auction_status(mine)
  check('gear: undercut by the cheapest of its name, other versions counted, other endings not', status == 'undercut' and lowest == 11000 and by == 1000)
  auctions.listing.records = real_records
  rawset(scan_exports, 'start', real_start)
  G.GetItemInfo = real_get_info
end)

-- 0.8, Gemini's review of gear versions (docs/reviews/2026-10-26-gear-versions.md, H-002): findings 2
-- to 6 (finding 1 is in timing_test.lua, it needs the slow auction house)
try('0.8: review H-002', function()
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local filter_util = loadstring("select(2, ...) 'aux.test.h002'; return require 'aux.util.filter'")('auxForever', addon)
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local scan_exports = loadstring("select(2, ...) 'aux.test.h002b'; return require 'aux.core.scan'")('auxForever', addon)
  local aux = loadstring("select(2, ...) 'aux.test.h002c'; return require 'aux'")('auxForever', addon)
  local real_get_info = G.GetItemInfo
  -- the game's answer for the item: its own name, also for a link (finding 4's worry)
  G.GetItemInfo = function(x)
    if x == 4575 or (type(x) == 'string' and x:find('item:4575', 1, true)) then
      return 'Medicine Staff', type(x) == 'string' and x or '|cff1eff00|Hitem:4575::::::0:0|h[Medicine Staff]|h|r', 2, 19, 14, 'Weapon', 'Staves', 1, 'INVTYPE_2HWEAPON', 1, 1487
    end
    return real_get_info(x)
  end
  local ids = aux.account_data.item_ids
  ids['medicine staff'] = 4575
  local function link(name) return '|cff1eff00|Hitem:4575::::::::24:1487::1:1:12726:1:28:5254::::|h[' .. name .. ']|h|r' end

  -- finding 6: a typed full name, in any letter case
  check('H-002 6: a typed name finds its item and ending', info.split_ending('Medicine Staff of the Wolf') == 4575 and select(2, info.split_ending('medicine staff of the wolf')) == 'medicine staff')
  check('H-002 6: a typed name gives the ending key', info.price_key(4575, 'medicine staff of the wolf') == '4575:of the wolf')
  check('H-002 6: an unknown name finds nothing', info.split_ending('Unknown Thing of the Bear') == nil)

  -- finding 4: a record's name is the link's full name
  local function staff(name, buyout)
    return info.item_search_record({itemKey = {itemID = 4575, itemSuffix = 0}, itemLink = link(name), auctionID = 1, quantity = 1,
      buyoutAmount = buyout or 11000, minBid = 0, owners = {'Seller'}, totalNumberOfOwners = 1, timeLeft = 2})
  end
  local wolf, bandit = staff('Medicine Staff of the Wolf'), staff('Medicine Staff of the Bandit')
  check('H-002 4: the record is named with its ending', wolf and wolf.name == 'Medicine Staff of the Wolf')

  -- finding 3: two endings at the same price, time and seller are two rows
  check('H-002 3: different endings never share a row', wolf and bandit and wolf.search_signature ~= bandit.search_signature and wolf.sniping_signature ~= bandit.sniping_signature)

  -- finding 2: an exact search for a full name asks for the item and keeps only that ending
  local queries = filter_util.queries('medicine staff of the wolf/exact')
  local q = queries and queries[1]
  check('H-002 2: the auction house is asked for the item', q and q.blizzard_query.name == 'medicine staff')
  check('H-002 2: that ending is kept', q and q.validator(wolf) == true)
  check('H-002 2: other endings are not', q and q.validator(bandit) == false)
  local all = filter_util.queries('medicine staff/exact')
  check('H-002 2: the item\'s own name still finds every ending', all and all[1].validator(wolf) and all[1].validator(bandit))

  -- finding 5: the price check counts what it read when a name search is in it
  local params
  local real_start = scan_exports.start
  rawset(scan_exports, 'start', function(p) params = p end)
  local real_records = auctions.listing.records
  auctions.listing.records = {{item_id = 4575, price_key = '4575:of the wolf', item_search_key = {itemID = 4575, itemSuffix = 101},
    unit_buyout_price = 15000, buyout_price = 15000, sale_status = 0}}
  auctions.check_prices()
  for _ = 1, 4 do params.on_page_loaded() end
  check('H-002 5: no "4 of 1": the count read so far, with no total', auctions.checking.done == 4 and auctions.checking.total == nil)
  params.on_complete()
  auctions.listing.records = real_records
  rawset(scan_exports, 'start', real_start)
  ids['medicine staff'] = nil
  G.GetItemInfo = real_get_info
end)

-- 0.8 (Tyler, build 7: "Why are we separating these lines?"): one row per price in the result
-- tables. His Merc Sword of Healing search: 11s from four sellers (10, 2, 39 and 5 for sale, four
-- time lefts), 12s twice (one with an 11s bid), 18s and 30s.
try('0.8: one row per price', function()
  local info = loadstring("select(2, ...) 'aux.util.info'; return _M")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local al = loadstring("select(2, ...) 'aux.gui.auction_listing'; return _M")('auxForever', addon)
  local real_get_info = G.GetItemInfo
  G.GetItemInfo = function(x)
    if x == 4570 or (type(x) == 'string' and x:find('item:4570', 1, true)) then
      return 'Merc Sword', type(x) == 'string' and x or nil, 2, 16, 11, 'Weapon', 'One-Handed Swords', 1, 'INVTYPE_WEAPON', 1, 1049
    end
    return real_get_info(x)
  end
  local link = '|cff1eff00|Hitem:4570::::::::20:1487::1:1:12700:1:28:5254::::|h[Merc Sword of Healing]|h|r'
  local id = 0
  local function row(seller, quantity, buyout, bid, band)
    id = id + 1
    return info.item_search_record({itemKey = {itemID = 4570, itemSuffix = 0}, itemLink = link, auctionID = id, quantity = quantity,
      buyoutAmount = buyout, minBid = bid or 0, owners = {seller}, totalNumberOfOwners = 1, timeLeft = band})
  end
  local records = {
    row('Amelaina', 10, 1100, nil, 3), row('Kadathi', 2, 1100, nil, 0), row('Matkal', 39, 1100, nil, 2), row('Miguel', 5, 1100, nil, 1),
    row('Freddy', 1, 1200, 1100, 2), row('Bigldaddyl', 1, 1200, nil, 3), row('Lemon', 1, 1800, 1200, 2), row('Ungido', 1, 3000, nil, 2),
  }
  local t = search.current_search().table
  t:SetDatabase(records)
  -- one item in the table: each price is a row of its own
  local by_price, n = {}, 0
  for _, info_row in ipairs(t.rowInfo) do
    for _, child in ipairs(info_row.children) do n = n + 1; by_price[child.record.buyout_price] = child end
  end
  check('rows: one row per price (11s, 12s, 18s, 30s)', n == 4 and t.rowInfo.numDisplayRows == 4)
  check('rows: 11s adds up the four sellers', by_price[1100] and by_price[1100].count == 56)
  local function plain(x) return ((x or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  check('rows: and says so', by_price[1100] and plain(al.seller_text(by_price[1100].record)) == '4 sellers')
  check('rows: 12s is one row, with and without a bid', by_price[1200] and by_price[1200].count == 2)
  check('rows: the row buys a real auction at the price shown', by_price[1100] and by_price[1100].record.buyout_price == 1100 and by_price[1200].record.buyout_price == 1200)
  check('rows: one seller is named as before', by_price[3000] and plain(al.seller_text(by_price[3000].record)) == 'Ungido')
  -- the Auctions tab keeps each of your own auctions on its own row
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local mine = {row('P', 1, 1100, nil, 3), row('P', 1, 1100, nil, 2)}
  for _, r in ipairs(mine) do r.auction_id = r.auction_id + 1000; info.signatures(r) end
  local real = auctions.listing.records
  auctions.listing:SetDatabase(mine)
  check('rows: the Auctions tab keeps one row per auction', auctions.listing.rowInfo.numDisplayRows == 2)
  auctions.listing:SetDatabase(real or {})

  -- Gemini's review of one row per price (H-004, docs/reviews/2026-11-08-one-row-per-price.md)
  t:SetDatabase(records)
  local eleven
  for _, info_row in ipairs(t.rowInfo) do
    for _, child in ipairs(info_row.children) do if child.record.buyout_price == 1100 then eleven = child end end
  end
  check('H-004 5: the row tells the buy bar how many it holds', eleven and eleven.record.group_count == 56)
  local summary = plain(search.results_summary({records = records}) or '')
  check('H-004 7: the summary counts the rows shown', search.results_count({records = records}) == 4 and summary:find('4 price levels', 1, true) ~= nil)
  -- finding 6: one seller with two time lefts is one seller
  local twice = {row('Amelaina', 3, 1500, nil, 3), row('Amelaina', 2, 1500, nil, 1), row('Kadathi', 1, 1500, nil, 2)}
  t:SetDatabase(twice)
  local fifteen = t.rowInfo[1] and t.rowInfo[1].children[1]
  check('H-004 6: each seller counted once', fifteen and fifteen.count == 6 and plain(al.seller_text(fifteen.record)) == '2 sellers')
  -- finding 3: the row keeps the auction with the lowest starting bid, by value
  local bids = {row('Buyoutonly', 1, 1200, nil, 3), row('Lowbid', 1, 1200, 200, 2), row('Midbid', 1, 1200, 900, 2)}
  t:SetDatabase(bids)
  local twelve = t.rowInfo[1] and t.rowInfo[1].children[1]
  check('H-004 3: the 2s starting bid is the one kept, so Bid shows', twelve and twelve.count == 3 and twelve.record.owner == 'Lowbid')
  -- finding 2: auctions with no buyout stay apart, whatever their bid
  local bid_only = {row('Cheap', 1, 0, 200, 3), row('Dear', 1, 0, 10000, 3)}
  t:SetDatabase(bid_only)
  check('H-004 2: no-buyout auctions keep a row each', t.rowInfo.numDisplayRows == 2)
  -- findings 1 and 4: the Bids and Sniper tables list each auction apart
  local bids_tab = loadstring("select(2, ...) 'aux.tabs.bids'; return _M")('auxForever', addon)
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  check('H-004 1 and 4: the Bids and Sniper tables keep each auction on its own row', bids_tab.listing.one_row_each == true and sniper.listing.one_row_each == true)

  -- Gemini's release review (H-006, finding 5): sorting and selecting rows of several auctions.
  -- Columns of the search table: 4 For sale, 5 Time Left, 6 Seller.
  local saved_sorts = {}
  for i, sort in ipairs(t.sorts) do saved_sorts[i] = {index = sort.index, descending = sort.descending} end
  local function order()
    local prices = {}
    for _, info_row in ipairs(t.rowInfo) do
      for _, child in ipairs(info_row.children) do tinsert(prices, child.record.buyout_price) end
    end
    return table.concat(prices, ' ')
  end
  t:SetDatabase({row('Aaron', 2, 1100, nil, 2), row('Abe', 2, 1100, nil, 2), row('Mia', 3, 1500, nil, 2)})
  t:SetSort(-4)
  t:SetDatabase()
  check('H-006 5: For sale sorts a row by all it holds (4 before 3)', order() == '1100 1500')
  t:SetSort(6)
  t:SetDatabase()
  check('H-006 5: "2 sellers" sorts with the unnamed rows, after Mia', order() == '1500 1100')
  local kept = row('Lowbid', 1, 1100, 500, 3)
  local next_one = row('Other', 1, 1100, nil, 0)
  t:SetDatabase({kept, next_one, row('Mid', 1, 1500, nil, 1)})
  t:SetSort(5)
  t:SetDatabase()
  -- the table only: selecting a row would also look the auction up for the buy bar
  local on_select = t.handlers.OnSelectionChanged
  t.handlers.OnSelectionChanged = nil
  t:SetSelectedRecord(kept)
  local before = order()
  t:RemoveAuctionRecord(kept)
  check('H-006 5: after buying the auction a row kept, the row stays selected with its next one, though the sort moved it',
    before == '1500 1100' and order() == '1100 1500' and t.selected == next_one)
  t:SetSelectedRecord(nil)
  t.handlers.OnSelectionChanged = on_select
  -- build 14 (Tyler, build 13): in a table of several items, For sale sorts each item by all it has
  -- for sale, as its row shows, not by its first price ("18 (1)" sat below a 17)
  local function ending_row(ending, quantity, buyout)
    id = id + 1
    local ending_link = '|cff1eff00|Hitem:4570::::::::20:1487::1:1:12700:1:28:5254::::|h[Merc Sword ' .. ending .. ']|h|r'
    return info.item_search_record({itemKey = {itemID = 4570, itemSuffix = 0}, itemLink = ending_link, auctionID = id, quantity = quantity,
      buyoutAmount = buyout, minBid = 0, owners = {'S' .. id}, totalNumberOfOwners = 1, timeLeft = 2})
  end
  t:SetDatabase({ending_row('of Stamina', 16, 1100), ending_row('of Stamina', 2, 3000), ending_row('of the Owl', 17, 1100)})
  t:SetSort(-4)
  t:SetDatabase()
  local first = t.rowInfo[1] and t.rowInfo[1].children[1].record.name
  check('build 14: For sale sorts items by all they have for sale (18 before 17)', #t.rowInfo == 2 and first == 'Merc Sword of Stamina')
  t.sorts, t.isSorted = saved_sorts, nil
  t:SetDatabase({})
  G.GetItemInfo = real_get_info
end)

-- H-004, note 8: the Post tab's "cheapest other ending" never suggests your own listing back to you
try('0.8: H-004 note 8', function()
  local req = loadstring("select(2, ...) 'aux.test.h004'; return require")('auxForever', addon)
  local scan_exports = req 'aux.core.scan'
  local info = req 'aux.util.info'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local real_start, real_inventory = scan_exports.start, info.inventory
  local real_get_info, real_key_info = G.GetItemInfo, rawget(C_AuctionHouse, 'GetItemKeyInfo')
  G.GetItemInfo = function(x)
    if x == 4575 or (type(x) == 'string' and x:find('item:4575', 1, true)) then return 'Medicine Staff', nil, 2, 19, 14, 'Weapon', 'Staves', 1, 'INVTYPE_2HWEAPON', 1, 1487 end
    return real_get_info(x)
  end
  local names = {[104] = 'Medicine Staff of the Wolf', [102] = 'Medicine Staff of Arcane Protection'}
  rawset(C_AuctionHouse, 'GetItemKeyInfo', function(key) return names[key.itemSuffix] and {itemName = names[key.itemSuffix], isEquipment = true} end)
  rawset(info, 'inventory', function() return function() end end)
  local params
  rawset(scan_exports, 'start', function(p) params = p end)
  post.selected_item = {key = '4575:of the whale', item_id = 4575, name = 'Medicine Staff of the Whale', quality = 2, count = 1, max_stack = 1}
  post.refresh_entries()
  check('note 8: other endings are skipped', params and params.skip_key and params.skip_key({itemKey = {itemID = 4575, itemSuffix = 104}, minPrice = 9000, containsOwnerItem = true, totalQuantity = 1}) == true)
  check('note 8: your own only listing is not the suggestion', post.other_endings_lowest == nil)
  params.skip_key({itemKey = {itemID = 4575, itemSuffix = 102}, minPrice = 11000, totalQuantity = 2})
  check('note 8: another seller\'s is', post.other_endings_lowest == 11000)
  post.selected_item = nil
  rawset(scan_exports, 'start', real_start); rawset(info, 'inventory', real_inventory)
  rawset(C_AuctionHouse, 'GetItemKeyInfo', real_key_info)
  G.GetItemInfo = real_get_info
end)

-- Gemini's release review (H-006, docs/reviews/2026-11-08-release-0.8.md), findings 1 and 2
try('0.8: review H-006', function()
  local req = loadstring("select(2, ...) 'aux.test.h006'; return require")('auxForever', addon)
  local info = req 'aux.util.info'
  local scan_exports = req 'aux.core.scan'
  local post = loadstring("select(2, ...) 'aux.tabs.post'; return _M")('auxForever', addon)
  local real_get_info, real_key_info = G.GetItemInfo, rawget(C_AuctionHouse, 'GetItemKeyInfo')
  -- finding 1: the version's name has loaded, the item's own name not yet
  local base_loaded = false
  G.GetItemInfo = function(x)
    if x == 4591 or (type(x) == 'string' and x:find('item:4591', 1, true)) then
      if base_loaded then return 'Bandit Cloak', nil, 2, 18, 13, 'Armor', 'Cloth', 1, 'INVTYPE_CLOAK', 1, 900 end
      return
    end
    return real_get_info(x)
  end
  rawset(C_AuctionHouse, 'GetItemKeyInfo', function(key)
    if key.itemID == 4591 then return {itemName = 'Bandit Cloak of the Owl', isEquipment = true} end
    if key.itemID == 4575 then return {itemName = 'Medicine Staff of the Wolf', isEquipment = true} end
    return real_key_info and real_key_info(key)
  end)
  check('H-006 1: without the item\'s own name, no price key yet (not "4591:0")', info.item_key_price_key({itemID = 4591, itemSuffix = 103}) == nil)
  base_loaded = true
  check('H-006 1: once it loads, the ending', info.item_key_price_key({itemID = 4591, itemSuffix = 103}) == '4591:of the owl')

  -- finding 2: a gear read stopped before its end (a Full scan) does not unlock Post
  G.GetItemInfo = function(x)
    if x == 4575 or (type(x) == 'string' and x:find('item:4575', 1, true)) then return 'Medicine Staff', nil, 2, 19, 14, 'Weapon', 'Staves', 1, 'INVTYPE_2HWEAPON', 1, 1487 end
    return real_get_info(x)
  end
  local real_start, real_inventory = scan_exports.start, info.inventory
  rawset(info, 'inventory', function() return function() end end)
  local params
  rawset(scan_exports, 'start', function(p) params = p end)
  post.selected_item = {key = '4575:of the wolf', item_id = 4575, name = 'Medicine Staff of the Wolf', quality = 2, count = 1, max_stack = 1}
  post.refresh_entries()
  check('H-006 2: reading', post.disabled_reason() == 'Reading the listings...')
  params.on_abort()
  check('H-006 2: stopped halfway, Post stays faded and says how to go on', post.disabled_reason() == 'Reading stopped. Press Refresh, or type a price.')
  post.refresh_entries()
  check('H-006 2: Refresh reads again', post.disabled_reason() == 'Reading the listings...')
  post.selected_item = nil
  rawset(scan_exports, 'start', real_start); rawset(info, 'inventory', real_inventory)
  rawset(C_AuctionHouse, 'GetItemKeyInfo', real_key_info)
  G.GetItemInfo = real_get_info

  -- finding 7: 0.7 kept one mixed price for every ending under "id:0"; the first price of an ending
  -- retires it, so a price asked by item ID is not that old one forever. A plain price kept since
  -- the update stays.
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local api = G.AuxForeverAPI
  local today = h.today()
  h.write_record('4593:0', {day = today - 30, low = 900, points = {{day = today - 31, value = 950}}})
  h.write_record('4594:0', {day = today, low = 700, points = {}})
  check('H-006 7: before, the old mixed price answers by item ID', api.GetUsualPrice(4593) ~= nil)
  h.process_auction({buyout_price = 1000, count = 1, price_key = '4593:of the owl', item_key = '4593:0'})
  h.process_auction({buyout_price = 1000, count = 1, price_key = '4594:of the owl', item_key = '4594:0'})
  check('H-006 7: the old mixed price is retired once an ending has a price', h.data['4593:0'] == nil and api.GetUsualPrice(4593) == nil and api.GetLatestPrice(4593) == nil)
  check('H-006 7: the ending keeps its own price', h.data['4593:of the owl'] ~= nil)
  check('H-006 7: a plain price seen since the update stays', h.data['4594:0'] ~= nil)
  for _, key in ipairs{'4593:of the owl', '4594:0', '4594:of the owl'} do h.data[key] = nil end
end)

-- 0.8 (Tyler): clearing the search bar and clicking elsewhere showed "<>"
try('0.8: an empty search bar stays empty', function()
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  check('empty bar: shows nothing', search.search_box.formatter('') == '' and search.search_box.formatter('   ') == '')
  check('empty bar: a search still shows as before', plain(search.search_box.formatter('linen cloth')):find('linen cloth', 1, true) ~= nil)
end)

-- 0.8.0.1, FB-024 (reported by GregoryWW): "hillman's cloak/exact" found nothing. An exact search
-- asks for the item's own category; a cloak is cloth armor, so it asked for Armor > Cloth, but
-- Forever keeps cloaks under Armor > Miscellaneous > Cloak, and the slot was never found because
-- the game's equip location ("INVTYPE_CLOAK") is not the slot's name ("Cloak").
try('0.8.0.1: an exact search finds the item\'s own slot', function()
  local filter_util = loadstring("select(2, ...) 'aux.test.fb024'; return require 'aux.util.filter'")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.core.scan'; return _M")('auxForever', addon)
  local aux = loadstring("select(2, ...) 'aux.test.fb024b'; return require 'aux'")('auxForever', addon)
  local real_get_info = G.GetItemInfo
  local items = {
    [3719] = {"Hillman's Cloak", 1, 20, 15, 'Armor', 'Cloth', 'INVTYPE_CLOAK'},
    [9001] = {'Test Robe', 2, 20, 15, 'Armor', 'Cloth', 'INVTYPE_ROBE'},
    [9002] = {'Test Pendant', 2, 20, 15, 'Armor', 'Miscellaneous', 'INVTYPE_NECK'},
    [9003] = {'Test Dagger', 2, 20, 15, 'Weapon', 'Daggers', 'INVTYPE_WEAPON'},
  }
  G.GetItemInfo = function(x)
    local id = tonumber(tostring(x):match('%d+'))
    local t = items[id]
    if t then return t[1], 'link', t[2], t[3], t[4], t[5], t[6], 1, t[7], 1, 300 end
    return real_get_info(x)
  end
  for id, t in pairs(items) do aux.account_data.item_ids[strlower(t[1])] = id end
  local function filters_of(text)
    local queries = filter_util.queries(text)
    local q = queries and queries[1] and queries[1].blizzard_query
    return q and scan.browse_query(q).itemClassFilters, q
  end
  local function only(filters, class, subclass, inventory_type)
    if not filters or #filters == 0 then return false end
    for _, f in ipairs(filters) do
      if f.classID ~= class or f.subClassID ~= subclass or f.inventoryType ~= inventory_type then return false end
    end
    return true
  end
  local cloak = filters_of("hillman's cloak/exact")
  check('fb024: a cloak is asked for under Miscellaneous > Cloak', only(cloak, 4, 1, 16))
  local robe = filters_of('test robe/exact')
  local robe_ok = robe and #robe == 2
  for _, f in ipairs(robe or {}) do robe_ok = robe_ok and f.classID == 4 and f.subClassID == 1 and (f.inventoryType == 5 or f.inventoryType == 20) end
  check('fb024: a robe is asked for under Cloth > Chest', robe_ok)
  check('fb024: a pendant is asked for under Miscellaneous > Neck', only(filters_of('test pendant/exact'), 4, 0, 2))
  local dagger, dq = filters_of('test dagger/exact')
  check('fb024: a weapon keeps its whole category, as before', dq and dq.class == 1 and dq.subclass == nil and dq.slot == nil and dagger and #dagger > 1)
  check('fb024: still the name, the level and no exact-match filter for gear', not not (dq and dq.name == 'test dagger' and dq.min_level == 15 and dq.max_level == 15))
  G.GetItemInfo = real_get_info
  for _, t in pairs(items) do aux.account_data.item_ids[strlower(t[1])] = nil end
end)

-- 0.8.0.1, FB-034 (reported by Chawitsch): with aux open, the Professions window moved a little to
-- the right. Blizzard's auction house window takes the left and center places ("doublewide"), so
-- the game puts a side window to its right; shrunk to 1% that window is a few pixels wide. aux puts
-- the side window back where the game's layout would have it without the auction house.
try('0.8.0.1: a side window stays put while aux is open', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local real = {G.GetUIPanel, G.GetUIPanelLayoutAttribute, G.UpdateUIPanelPositions, G.hooksecurefunc, G.InCombatLockdown, G.GetUIPanelWidth, G.GetUIPanelWidthUnscaled}
  local real_attr = rawget(AuctionHouseFrame, 'GetAttribute')
  rawset(AuctionHouseFrame, 'GetAttribute', function(_, name) if name == 'UIPanelLayout-xoffset' then return 20 end end)
  local panels = {}
  -- the game's numbers: left place 16, gap 32, the auction house window's offset 20 and width 800
  -- (8 at aux's 1% scale)
  local side = {point = {'TOPLEFT', 'UIParent', 'TOPLEFT', 16 + 8 + 20 + 32, -104}, scale = 1, protected = false}
  function side:GetPoint() return unpack(self.point) end
  function side:SetPoint(p, r, rp, x, y) self.point = {p, r, rp, x, y} end
  function side:GetScale() return self.scale end
  function side:GetAttribute(name) if name == 'UIPanelLayout-xoffset' then return 0 end end
  function side:IsProtected() return self.protected end
  G.GetUIPanel = function(key) return panels[key] end
  G.GetUIPanelLayoutAttribute = function(name) return ({LEFT_OFFSET = 16, PANEl_SPACING_X = 32})[name] end
  G.GetUIPanelWidth = function(f) return f == AuctionHouseFrame and 8 or 600 end
  G.GetUIPanelWidthUnscaled = function(f) return f == AuctionHouseFrame and 800 or 600 end
  local hooked
  G.hooksecurefunc = function(name, f) if name == 'UpdateUIPanelPositions' then hooked = f end end
  G.UpdateUIPanelPositions = function() end
  G.InCombatLockdown = function() return false end
  a.hook_panel_layout()
  check('fb034: aux hooks the game\'s window layout (after it runs)', type(hooked) == 'function')
  panels.doublewide, panels.right = AuctionHouseFrame, side
  a.set_blizzard_frame_shown(false)
  check('fb034: the side window goes back to the left place', side.point[4] == 16 and side.point[5] == -104 and side.point[1] == 'TOPLEFT')
  side.point[4] = 76
  hooked()
  check('fb034: and again after each layout by the game', side.point[4] == 16)
  side.point[4] = 16 + 800 + 20 + 32
  hooked()
  check('fb034: also when the game placed it before aux shrank its window', side.point[4] == 16)
  side.scale, side.point[4] = .8, 76 / .8
  hooked()
  check('fb034: the game\'s offsets are divided by the window\'s scale, as the game does', math.abs(side.point[4] - 20) < 1e-9)
  side.scale = 1
  -- build 2 (Tyler's test): a window the player put somewhere themselves stays there
  side.point[4] = 500
  hooked()
  check('fb034: a window placed by the player is never moved', side.point[4] == 500)
  side.point = {'CENTER', 'UIParent', 'CENTER', 76, 0}
  hooked()
  check('fb034: nor one anchored another way', side.point[1] == 'CENTER' and side.point[4] == 76)
  side.point = {'TOPLEFT', 'UIParent', 'TOPLEFT', 76, -104}
  side.protected = true
  G.InCombatLockdown = function() return true end
  hooked()
  check('fb034: a protected window is never moved in combat', side.point[4] == 76)
  side.protected = false
  G.InCombatLockdown = function() return false end
  a.set_blizzard_frame_shown(true)
  side.point[4] = 76
  hooked()
  check('fb034: with Blizzard\'s window shown, the game\'s place stays', side.point[4] == 76)
  a.set_blizzard_frame_shown(false)
  panels.doublewide = nil
  side.point[4] = 76
  hooked()
  check('fb034: without the auction house, nothing is moved', side.point[4] == 76)
  rawset(AuctionHouseFrame, 'GetAttribute', real_attr)
  G.GetUIPanel, G.GetUIPanelLayoutAttribute, G.UpdateUIPanelPositions, G.hooksecurefunc, G.InCombatLockdown, G.GetUIPanelWidth, G.GetUIPanelWidthUnscaled = real[1], real[2], real[3], real[4], real[5], real[6], real[7]
end)

-- 0.8.1, FB-026 (suggested by deep_structure): the Materials line says whether a craft makes a
-- profit or a loss (Tyler, 2026-11-08: option A of the mockup, reversing FB-007's "cost only")
try('0.8.1: profit or loss on the Materials line', function()
  local req = loadstring("select(2, ...) 'aux.test.fb026'; return require")('auxForever', addon)
  local aux = req 'aux'
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local today = h.today()
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  h.write_record('7601:0', {day = today, points = {{day = today - 1, value = 26}}})   -- material, 26c
  h.write_record('7610:0', {day = today, points = {{day = today - 1, value = 200}}})  -- made item, 2s
  h.write_record('7611:0', {day = today, points = {{day = today - 1, value = 50}}})   -- made item, 50c
  local function recipe(output, count, reagents)
    return {name = 'Test', reagents = reagents or {{item_id = 7601, count = 2}}, output = output and {item_id = output, count = count or 1}}
  end
  local net, gross = search.recipe_sale(recipe(7610))
  check('fb026: the made item after the 5% cut', net == 190 and gross == 200)
  net, gross = search.recipe_sale(recipe(7610, 2))
  check('fb026: a recipe that makes two counts both', net == 380 and gross == 400)
  local line = plain(search.recipe_cost_text(recipe(7610)))
  check('fb026: profit on the line (190 - 52 = 138c)', line:find('Materials', 1, true) and line:find('Profit', 1, true) and line:find('1s 38c', 1, true) ~= nil)
  line = plain(search.recipe_cost_text(recipe(7611)))
  check('fb026: a loss says Loss (52 - 47 = 5c)', line:find('Loss', 1, true) and line:find('5c', 1, true) and not line:find('Profit', 1, true))
  line = plain(search.recipe_cost_text(recipe(7610, 1, {{item_id = 7601, count = 2}, {item_id = 7699, count = 1}})))
  check('fb026: a material with no price makes it "at most"', line:find('+', 1, true) and line:find('Profit at most', 1, true) ~= nil)
  line = plain(search.recipe_cost_text(recipe(7612)))
  check('fb026: a made item with no price says so', line:find('no sell price yet', 1, true) ~= nil)
  line = plain(search.recipe_cost_text(recipe(nil)))
  check('fb026: a recipe that makes no item shows the cost only', not line:find('Profit', 1, true) and not line:find('Loss', 1, true) and not line:find('sell', 1, true))
  line = plain(search.recipe_cost_text(recipe(7610, 1, {{item_id = 7698, count = 1}})))
  check('fb026: no material priced still says no price yet, nothing else', line:find('no price yet', 1, true) and not line:find('Profit', 1, true))
  local lines = {}
  local tip = new_frame()
  rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
  rawset(tip, 'AddDoubleLine', function(_, a, b) tinsert(lines, plain(a) .. ' | ' .. plain(b)) end)
  search.recipe_cost_tooltip(tip, recipe(7610))
  local all = table.concat(lines, '\n')
  check('fb026: the hover shows the selling price, the cut and the profit', all:find('sells for | 2s', 1, true) and all:find('After the 5% auction house cut | 1s 90c', 1, true) and all:find('Profit | 1s 38c', 1, true) ~= nil)
  lines = {}
  search.recipe_cost_tooltip(tip, recipe(7612))
  all = table.concat(lines, '\n')
  check('fb026: the hover says how to learn a missing price', all:find('no price yet', 1, true) and all:find('Search for it at the auction house', 1, true) ~= nil)
  for _, key in ipairs{'7601:0', '7610:0', '7611:0'} do h.data[key] = nil end
end)

-- 0.8.2, FB-036 (reported by Swiftwren): the Sniper offered "deals at 4% of the usual price" on items
-- listed by hundreds at that same price. The usual price is a slow average of past days; after
-- launch prices fell faster. Today's market, read from the item's own listings, now counts too.
try('0.8.2: the Sniper checks today\'s market', function()
  local aux_require = loadstring("select(2, ...) 'aux.test.fb036'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  -- the rule on its own: usual 22s, 3 days of history, 60%, profit at least 1c
  local reason, profit, pct = sniper.judge(850, 2200, 0, 3, 60, 1, 900)
  check('fb036: today\'s market just above the price: not a deal', reason == nil)
  reason, profit, pct = sniper.judge(300, 2200, 0, 3, 60, 1, 1000)
  check('fb036: well below today\'s market: a deal against the market', reason == 'market' and pct == 30 and profit == 950 - 300)
  reason, profit, pct = sniper.judge(850, 2200, 0, 3, 60, 1, 5000)
  check('fb036: a market above the usual price leaves the usual price', reason == 'usual' and pct == 39)
  reason = sniper.judge(850, 2200, 0, 3, 60, 1, nil)
  check('fb036: no market known: as before', reason == 'usual')
  reason, profit = sniper.judge(50, 2200, 100, 3, 60, 1, 60)
  check('fb036: below vendor price is still a deal whatever the market', reason == 'vendor' and profit == 50)
  local function rec(price, units, extra)
    local r = {buyout_price = price * units, unit_buyout_price = price, count = units, seller_count = 1}
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  check('fb036: market: hundreds just above the cheapest price', sniper.market_now({rec(85, 2), rec(87, 45), rec(90, 300)}) == 87)
  check('fb036: market: a few cheap units next to a normal market do not set it', sniper.market_now({rec(850, 12), rec(1000, 5), rec(2300, 100)}) == 2300)
  check('fb036: market: one price asked by 3 sellers is the market', sniper.market_now({rec(210, 80, {seller_count = 3})}) == 210)
  check('fb036: market: one price from one seller says nothing', sniper.market_now({rec(210, 80)}) == nil)
  check('fb036: market: a lone auction says nothing', sniper.market_now({rec(500, 1)}) == nil)
  check('fb036: market: the player\'s own listings do not count', sniper.market_now({rec(500, 1), rec(510, 50, {own = true})}) == nil)

  -- a round: usual 22s for every item, 3 days of Full scans
  local d = h.today()
  for id = 601, 605 do
    h.write_record(id .. ':0', {day = d, points = {{value = 2200, day = d - 1, units = 10}, {value = 2200, day = d - 2, units = 10}, {value = 2200, day = d - 3, units = 10}}})
  end
  local items = {
    -- Swiftwren's case: 2 at 85c, hundreds within a few copper
    {id = 601, name = 'Flat Herb', commodity = true, min = 85, qty = 347, sell = 1, auctions = {{buyout = 85, qty = 2}, {buyout = 87, qty = 45}, {buyout = 90, qty = 300}}},
    -- the whole market at one price, many sellers
    {id = 602, name = 'Flat Ore', commodity = true, min = 210, qty = 80, sell = 1, auctions = {{buyout = 210, qty = 80, sellers = 6}}},
    -- one seller dumping, nothing else listed: still a deal against the usual price
    {id = 603, name = 'Dumped Ore', commodity = true, min = 210, qty = 80, sell = 1, auctions = {{buyout = 210, qty = 80}}},
    -- a lone piece of gear far below its usual price: the classic snipe
    {id = 604, name = 'Lone Sword', min = 300, qty = 1, sell = 1, auctions = {{buyout = 300}}},
    -- the market fell to 10s, and one is listed at 3s
    {id = 605, name = 'Fallen Cloth', commodity = true, min = 300, qty = 205, sell = 1, auctions = {{buyout = 300, qty = 5}, {buyout = 1000, qty = 200}}},
  }
  local run, restore = fake_ah(items)
  local opened = {}
  local send = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(key, ...) opened[key.itemID] = (opened[key.itemID] or 0) + 1; return send(key, ...) end)
  aux.account_data.sniper_percent, aux.account_data.sniper_profit = 60, 1
  sniper.clear_deals()
  sniper.settings_changed()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 200 do run(1); if sniper.round > r0 then break end end
  local found = {}
  for _, deal in ipairs(sniper.deals) do found[deal.name] = deal end
  check('fb036: a flat market is not a deal (Swiftwren)', not found['Flat Herb'])
  check('fb036: one price many sellers ask is not a deal', not found['Flat Ore'])
  check('fb036: one seller dumping is still a deal', found['Dumped Ore'] and found['Dumped Ore'].deal_reason == 'usual')
  check('fb036: a lone sword is still a deal', found['Lone Sword'] and found['Lone Sword'].deal_reason == 'usual')
  check('fb036: below a fallen market it says so', found['Fallen Cloth'] and found['Fallen Cloth'].deal_reason == 'market' and found['Fallen Cloth'].deal_percent == 30
    and #found['Fallen Cloth'].deal_tiers == 1)
  -- a stricter setting judges a found deal again against the market it was found with: 30% of the
  -- market is 14% of the usual price, so at 20% it would wrongly stay with the usual price alone
  aux.account_data.sniper_percent = 20
  local still
  for _, deal in ipairs(sniper.shown_deals()) do if deal == found['Fallen Cloth'] then still = true end end
  check('fb036: a stricter rule hides a market deal that no longer passes', not still)
  aux.account_data.sniper_percent = 60
  -- the next rounds do not open the flat market again while its price only moves a copper
  local herb_opened = opened[601]
  items[1].min, items[1].auctions[1].buyout = 86, 86
  local r1 = sniper.round
  for _ = 1, 200 do run(1); if sniper.round > r1 then break end end
  check('fb036: a flat market whose price moves is not opened again', herb_opened == 1 and opened[601] == 1)
  sniper.stop()
  rawset(C_AuctionHouse, 'SendSearchQuery', send)
  restore()
  sniper.clear_deals()
  sniper.settings_changed()
  for id = 601, 605 do h.data[id .. ':0'] = nil end
end)

-- 0.8.2, FB-037 (reported by deep_structure: "i cant scan today") and FB-027: since launch the
-- server can take more than 5 minutes to send a Full scan's list (user_ayzkr6rhvrlna3ya). aux gave
-- up after 2 minutes. It now waits up to 10, shows how long so far, and says what each part took.
try('0.8.2: a Full scan waits for a slow auction house', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.test.fb037'; return require 'aux.core.scan'")('auxForever', addon)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  local list = {}
  for i = 1, 30 do tinsert(list, {id = 9301, count = 2, buyout = 200 + i}) end
  local asked = 0
  set(C_AuctionHouse, 'ReplicateItems', function() asked = asked + 1 end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return #list end)
  set(C_AuctionHouse, 'GetReplicateItemInfo', function(i) local x = list[i + 1]; return 'Item', 1, x.count, 1, true, 1, nil, 0, 0, x.buyout, 0, false, nil, 'Seller', nil, 0, x.id, true end)
  set(C_AuctionHouse, 'GetReplicateItemLink', function() return '|cffffffff|Hitem:9301::::::0:0|h[Item]|h|r' end)
  set(G, 'GetItemInfo', function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if id ~= 9301 then return end
    return 'Slow Herb', '|cffffffff|Hitem:9301::::::0:0|h[Slow Herb]|h|r', 1, 10, 1, 'Trade Goods', 'Herb', 20, '', 1, 1
  end)
  local texts, printed = {}, {}
  set(a.status_bar.text, 'SetText', function(_, t) tinsert(texts, t or '') end)
  set(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, t) tinsert(printed, t) end)
  local was_shown = a.frame.__shown
  a.frame.__shown = true
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')) end
  local function said(pattern)
    for _, t in ipairs(printed) do if plain(t):find(pattern, 1, true) then return plain(t) end end
  end

  -- the answer comes after 4 minutes
  a.account_data.replicate_time = 0
  a.full_scan_button.__scripts.OnClick(a.full_scan_button)
  for _ = 1, 2400 do tick() end
  check('fb037: still waiting after 4 minutes', scan.is_scanning() and asked == 1)
  local waiting = texts[#texts] or ''
  check('fb037: the status bar shows how long so far', waiting:find('waiting for the auction house, 4:00 so far', 1, true) ~= nil or waiting:find('waiting for the auction house, 3:59 so far', 1, true) ~= nil)
  fire('REPLICATE_ITEM_LIST_UPDATE')
  for _ = 1, 100 do tick(); if not scan.is_scanning() then break end end
  local line = said('Full scan complete')
  check('fb037: an answer after 4 minutes is read (2 minutes gave up)', not scan.is_scanning() and line ~= nil and line:find('30 auctions recorded', 1, true) ~= nil)
  check('fb027: the closing line says how long the auction house took', line and line:find('the auction house took 4m 0', 1, true) ~= nil)
  check('fb037: no "did not answer" for a slow answer', said('did not answer') == nil)

  -- no answer at all
  printed = {}
  a.account_data.replicate_time = 0
  a.full_scan_button.__scripts.OnClick(a.full_scan_button)
  for _ = 1, 6100 do tick(); if not scan.is_scanning() then break end end
  check('fb037: after 10 minutes without an answer it stops', not scan.is_scanning())
  check('fb037: and says nothing was recorded', said('did not answer within 10 minutes, so nothing was recorded') ~= nil)
  check('fb037: no "complete" line when nothing came', said('Full scan complete') == nil and said('full scan complete') == nil)
  check('fb037: the summary is empty for a failed scan', scan.full_scan_summary({full = {failed = true}}) == nil)

  a.frame.__shown = was_shown
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
  a.account_data.replicate_time = 0
end)

-- 0.8.2, FB-037: while a Full scan waits for the server (minutes since launch), the Sniper's next
-- round and the Auctions tab's price check started scans of their own, which stopped it: nothing was
-- recorded and the game still counted it. They now wait; a search the player starts says it stopped it.
try('0.8.2: nothing stops a Full scan by itself', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.test.fb037b'; return require 'aux.core.scan'")('auxForever', addon)
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local auctions = loadstring("select(2, ...) 'aux.tabs.auctions'; return _M")('auxForever', addon)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  set(C_AuctionHouse, 'ReplicateItems', function() end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return 0 end)
  local printed = {}
  set(DEFAULT_CHAT_FRAME, 'AddMessage', function(_, t) tinsert(printed, t) end)
  local was_shown = a.frame.__shown
  a.frame.__shown = true

  -- the Sniper is running when the Full scan starts
  a.set_tab(2)
  sniper.start()
  for _ = 1, 5 do tick() end
  a.account_data.replicate_time = 0
  a.full_scan_button.__scripts.OnClick(a.full_scan_button)
  for _ = 1, 100 do tick() end
  check('fb037: the Sniper does not stop a waiting Full scan', scan.is_full_scan())
  sniper.stop()

  -- the Auctions tab opens and would check prices
  a.set_tab(4)
  for _ = 1, 100 do tick() end
  check('fb037: the Auctions tab\'s price check waits too', scan.is_full_scan() and auctions.checking == nil)

  -- a search the player starts stops it, and says so
  scan.start{type = 'list', queries = {{blizzard_query = {}}}, quiet = true}
  local said
  for _, t in ipairs(printed) do if t:find('Full scan stopped by a new search before it finished', 1, true) then said = true end end
  check('fb037: a search stops it and says so', not scan.is_full_scan() and said)
  scan.abort()
  for _ = 1, 30 do tick() end

  a.set_tab(1)
  a.frame.__shown = was_shown
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
  a.account_data.replicate_time = 0
end)

-- 0.8.2, FB-028 (reported by user_ayzkr6rhvrlna3ya): "over 30 seconds from sounding off to
-- attempting the purchase". A deal clicked right after it was found is not read again first.
try('0.8.2: a fresh Sniper deal goes straight to the buy bar', function()
  local aux_require = loadstring("select(2, ...) 'aux.test.fb028'; return require")('auxForever', addon)
  local aux = aux_require 'aux'
  local bar = aux_require 'aux.gui.buy_bar'
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  -- the axe after the ore, so the round's last search is the axe's (review H-008, finding 6)
  local items = {
    {id = 702, name = 'Quick Ore', commodity = true, min = 100, qty = 7, sell = 300, auctions = {{buyout = 100, qty = 7}}},
    {id = 701, name = 'Quick Axe', min = 2800, qty = 1, sell = 3036, auctions = {{buyout = 2800}}},
  }
  local run, restore = fake_ah(items)
  local searched = {}
  local real_send = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(key, ...) searched[key.itemID] = (searched[key.itemID] or 0) + 1; return real_send(key, ...) end)
  aux.account_data.sniper_profit = 1
  sniper.clear_deals()
  sniper.settings_changed()
  aux.set_tab(2)
  local r0 = sniper.round
  sniper.start()
  for _ = 1, 300 do run(1) if sniper.round > r0 then break end end
  local axe, ore
  for _, d in ipairs(sniper.deals) do if d.item_id == 701 then axe = d elseif d.item_id == 702 then ore = d end end
  check('fb028: both deals found', axe ~= nil and ore ~= nil)
  -- the table shows new deals at most twice a second
  for _ = 1, 10 do tick() end
  local in_table = 0
  for _, r in ipairs(sniper.listing.records or {}) do if r == axe or r == ore then in_table = in_table + 1 end end
  check('fb028: both deals in the table', in_table == 2)
  local before = searched[701] or 0
  sniper.listing:SetSelectedRecord(axe)
  run(1)
  local reading = sniper.refreshing
  run(2)
  check('fb028: gear clicked at once is not read again', reading == nil and (searched[701] or 0) == before)
  check('fb028: and the buy bar offers it at once', bar.primary_label():find('^Buy for') ~= nil)
  sniper.listing:SetSelectedRecord()
  run(1)
  before = searched[702] or 0
  sniper.listing:SetSelectedRecord(ore)
  run(1)
  reading = sniper.refreshing
  run(2)
  check('fb028: a trade good clicked at once is not read again', reading == nil and (searched[702] or 0) == before)
  check('fb028: and the buy bar offers it at once', bar.primary_label():find('^Buy') ~= nil)
  sniper.listing:SetSelectedRecord()
  run(1)
  -- review H-008, finding 6: once another item was searched, a gear deal is read again first (0.4.1:
  -- a gear purchase did nothing after other searches), however fresh
  local scan = aux_require 'aux.core.scan'
  local done
  scan.start{type = 'list', quiet = true, no_view = true, queries = {{item_keys = {{itemID = 702, itemSuffix = 0, itemLevel = 0}}}}, on_complete = function() done = true end}
  for _ = 1, 20 do run(1); if done then break end end
  before = searched[701] or 0
  sniper.listing:SetSelectedRecord(axe)
  for _ = 1, 10 do run(1) end
  check('fb028: gear clicked after another search is read again', done and (searched[701] or 0) > before)
  check('h008 6: the last search is known', scan.last_read_is({itemID = 701, itemSuffix = 0, itemLevel = 0}))
  done = false
  scan.start{type = 'list', quiet = true, fast = true, queries = {{blizzard_query = {}}}, on_complete = function() done = true end}
  for _ = 1, 20 do run(1); if done then break end end
  check('h008 6: an item list in between clears it', done and not scan.last_read_is({itemID = 701, itemSuffix = 0, itemLevel = 0}))
  sniper.listing:SetSelectedRecord()
  sniper.stop()
  run(5)
  rawset(C_AuctionHouse, 'SendSearchQuery', real_send)
  restore()
  sniper.clear_deals()
  bar.clear()
end)

-- 0.8.2, FB-025 (suggested by RushJet1): "armor/mail/chest/usable/strength" took 2 minutes, because
-- tooltip text made the search read every auction of every item. The item list's own tooltips are
-- checked instead; only gear with a random ending (stats in the ending) is read in full.
try('0.8.2: tooltip text is checked on the item list', function()
  local scan = loadstring("select(2, ...) 'aux.test.fb025'; return require 'aux.core.scan'")('auxForever', addon)
  local filter_util = loadstring("select(2, ...) 'aux.test.fb025b'; return require 'aux.util.filter'")('auxForever', addon)
  local items = {
    {id = 811, name = 'Strong Chest', min = 1000, qty = 2, auctions = {{buyout = 1000}, {buyout = 1100}}},
    {id = 812, name = 'Weak Chest', min = 900, qty = 1, auctions = {{buyout = 900}}},
    {id = 813, name = 'Bear Chest', full_name = 'Bear Chest of the Bear', suffix = 77, min = 1500, qty = 1, auctions = {{buyout = 1500}}},
    {id = 814, name = 'Owl Chest', full_name = 'Owl Chest of the Owl', suffix = 78, min = 1400, qty = 1, auctions = {{buyout = 1400}}},
  }
  local run, restore = fake_ah(items)
  -- each tooltip as the game would build it from that link
  local lines_of = {
    ['Strong Chest'] = {'Strong Chest', '+5 Strength'},
    ['Weak Chest'] = {'Weak Chest', '+5 Intellect'},
    ['Bear Chest'] = {'Bear Chest', '<Random enchantment>'},
    ['Bear Chest of the Bear'] = {'Bear Chest of the Bear', '+3 Strength', '+3 Stamina'},
    ['Owl Chest'] = {'Owl Chest', '<Random enchantment>'},
    ['Owl Chest of the Owl'] = {'Owl Chest of the Owl', '+3 Intellect', '+3 Spirit'},
  }
  local shown = {}
  local old_lines = {}
  for i = 1, 4 do old_lines[i] = {G['AuxTooltipTextLeft' .. i], G['AuxTooltipTextRight' .. i]} end
  rawset(AuxTooltip, 'SetHyperlink', function(_, l) shown = lines_of[tostring(l):match('|h%[(.-)%]|h')] or {} end)
  rawset(AuxTooltip, 'ClearLines', function() shown = {} end)
  -- 0.8.2 build 6: a fast row of gear with an ending is built from its item key; the game gives the
  -- Bear chest's stats there, and only the Owl chest's name (so that one falls back to a full read)
  rawset(AuxTooltip, 'SetItemKey', function(_, id, level, suffix)
    if suffix == 77 then shown = lines_of['Bear Chest of the Bear'] elseif suffix == 78 then shown = {'Owl Chest of the Owl'} end
  end)
  rawset(AuxTooltip, 'NumLines', function() return #shown end)
  for i = 1, 4 do
    G['AuxTooltipTextLeft' .. i] = {GetText = function() return shown[i] end}
    G['AuxTooltipTextRight' .. i] = {GetText = function() end}
  end
  local searched = {}
  local real_send = C_AuctionHouse.SendSearchQuery
  rawset(C_AuctionHouse, 'SendSearchQuery', function(key, ...) searched[key.itemID] = (searched[key.itemID] or 0) + 1; return real_send(key, ...) end)
  local found, done = {}, false
  local queries = filter_util.queries('chest/strength')
  check('fb025: the search is fast', queries and queries[1].tooltip_text == true and queries[1].full_reason == nil)
  local redraws = 0
  scan.start{type = 'list', queries = queries, fast = true, quiet = true,
    on_auction = function(record) found[record.name] = (found[record.name] or 0) + 1 end,
    on_page_scanned = function() redraws = redraws + 1 end,
    on_complete = function() done = true end}
  for _ = 1, 100 do run(1); if done then break end end
  check('fb025: the search finished', done)
  check('fb025: a plain item with the word in its tooltip is listed from the item list', found['Strong Chest'] == 1 and not searched[811])
  check('fb025: a plain item without it is left out, unread', not found['Weak Chest'] and not searched[812])
  check('fb025: gear with an ending is matched on its item key\'s tooltip, unread', found['Bear Chest of the Bear'] == 1 and not searched[813])
  check('fb025: when the game gives only the name, it is read in full and left out', not found['Owl Chest of the Owl'] and searched[814] == 1)
  -- 4 items on the list: redrawn once at its end, and once more right after the Owl chest's read
  check('fb025: the table is redrawn right after a full read (Tyler: "This isnt returning items")', redraws == 2)
  rawset(C_AuctionHouse, 'SendSearchQuery', real_send)
  rawset(AuxTooltip, 'SetHyperlink', nil)
  rawset(AuxTooltip, 'NumLines', nil)
  rawset(AuxTooltip, 'ClearLines', nil)
  rawset(AuxTooltip, 'SetItemKey', nil)
  for i = 1, 4 do G['AuxTooltipTextLeft' .. i], G['AuxTooltipTextRight' .. i] = old_lines[i][1], old_lines[i][2] end
  restore()
end)

-- 0.8.2, FB-035 (suggested by deep_structure): the "usually" line in tooltips gets a switch of its
-- own (it could only go with Value). FB-033 (Chawitsch asked for stack prices, which Shift already
-- shows): a stack's Value line says so ("Shift for 20").
try('0.8.2: Usually switch and the Shift hint', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local tooltip = loadstring("select(2, ...) 'aux.core.tooltip'; return _M")('auxForever', addon)
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local today = h.today()
  -- latest 39c, usual 87c: a big gap, so "usually" shows when on
  h.write_record('7601:0', {day = today, low = 38, market = 39, units = 82, points = {{day = today - 2, value = 87}, {day = today - 3, value = 87}}})
  local shift = false
  local real_shift = G.IsShiftKeyDown
  G.IsShiftKeyDown = function() return shift end
  local function tip_lines(quantity)
    local lines = {}
    local tip = new_frame()
    rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
    rawset(AuxTooltip, 'NumLines', function() return 0 end)
    tooltip.extend_tooltip(tip, '|cffffffff|Hitem:7601::::::0:0|h[X]|h|r', quantity or 1)
    rawset(AuxTooltip, 'NumLines', nil)
    return table.concat(lines, '\n')
  end
  local settings = a.character_data.tooltip
  check('fb035: the switch is on by default', settings.usually == true)
  -- build 4 (Tyler): "Value: 0.39 (45%)  seen today", 39c being 45% of the usual 87c
  check('fb035: on, the percent of usual follows the price', tip_lines():find('Value: 0.39 (45%)  seen today', 1, true) ~= nil)
  SlashCmdList.AUX('tooltip percent')
  check('fb035: /aux tooltip percent turns it off', settings.usually == false and tip_lines():find('%', 1, true) == nil)
  check('fb035: Value stays', tip_lines():find('Value: 0.39  seen today', 1, true) ~= nil)
  SlashCmdList.AUX('tooltip usually')
  check('fb035: /aux tooltip usually still works', settings.usually == true)
  SlashCmdList.AUX('tooltip usually')
  local box
  for _, b in ipairs(a.tooltip_boxes) do if b.key == 'usually' then box = b end end
  box.__scripts.OnClick(box)
  check('fb035: the Settings switch turns it back on', settings.usually == true and tip_lines():find('(45%)', 1, true) ~= nil)
  local frame_src = io.open('frame.lua'):read('*a')
  check('fb035: the switch is called % of usual', frame_src:find("{'usually', '% of usual',", 1, true) ~= nil)
  -- a character saved before 0.8.2 has tooltip settings without the new line: it is filled in, on,
  -- and the player's own choices stay
  local older = a.character_settings({tooltip = {value = false, merchant_sell = true, daily = true}, bid_auction_ids = {7}})
  check('fb035: an older character gets the line on', older.tooltip.usually == true)
  check('fb035: and keeps its own choices', older.tooltip.value == false and older.tooltip.daily == true and older.bid_auction_ids[1] == 7)
  check('fb035: other missing lines get their defaults', older.tooltip.money_icons == false and older.tooltip.merchant_buy == false)
  local fresh = a.character_settings({})
  check('fb035: a new character gets every default', fresh.tooltip.value == true and fresh.tooltip.usually == true and fresh.tooltip.daily == false and type(fresh.bid_auction_ids) == 'table')

  -- the Shift hint
  local stack = tip_lines(20)
  -- build 6 (Tyler): no Shift instructions in the tooltip
  check('fb033: a stack shows no Shift hint', stack:find('Value: 0.39 (45%)  seen today', 1, true) ~= nil and stack:find('Shift', 1, true) == nil)
  check('fb033: one item says nothing either', tip_lines(1):find('Shift', 1, true) == nil)
  shift = true
  stack = tip_lines(20)
  check('fb033: with Shift held, the stack price', stack:find('Value: 7.80 (45%)  for 20  seen today', 1, true) ~= nil)
  G.IsShiftKeyDown = real_shift
  h.data['7601:0'] = nil
end)

-- 0.8.2 build 3, review H-008 (Gemini, docs/reviews/2026-11-09-sniper-0.8.2.md) of the Sniper's
-- logic, with the reviewer's own listings. FB-036 (Swiftwren): an Invoker's Cord at 12s next to 78 at
-- 13s, and 1,792 items opened in one round.
try('0.8.2: Sniper review H-008', function()
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local aux = loadstring("select(2, ...) 'aux.test.h008'; return require 'aux'")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.test.h008b'; return require 'aux.core.scan'")('auxForever', addon)
  local function rec(price, units, extra)
    local r = {buyout_price = price, unit_buyout_price = price, count = 1, auction_count = units, seller_count = 1}
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
  end
  -- finding 7: the column next to the price shows the price the deal was compared with
  check('h008 7: a market deal shows the market', sniper.compared_price({deal_reason = 'market', deal_market = 1000, deal_usual = 2200}) == 1000)
  check('h008 7: a usual deal shows the usual price', sniper.compared_price({deal_reason = 'usual', deal_market = 5000, deal_usual = 2200}) == 2200)
  check('h008 7: a below vendor deal shows the vendor price', sniper.compared_price({deal_reason = 'vendor', deal_vendor = 300, deal_usual = 2200}) == 300)
  check('h008 7: the column is called Compared to', sniper.columns[7] and sniper.columns[7].title == 'Compared to')
  -- finding 1: a price 3 or more sellers ask is the market, whatever is listed above it
  check('h008 1: 6 sellers at 2s 10c next to one at 22s is the market', sniper.market_now({rec(210, 80, {seller_count = 6}), rec(2200, 1)}) == 210)
  check('h008 1: the wall left after the cheap unit is bought', sniper.market_now({rec(87, 200, {seller_count = 5}), rec(2200, 5)}) == 87)
  -- finding 4: fewer than 3 units above the cheapest price are not a market
  check('h008 4: two cheap units 1c apart, nothing else: no market', sniper.market_now({rec(209, 1), rec(210, 1)}) == nil)
  check('h008 4: with 100 at 22s above them, 22s', sniper.market_now({rec(209, 1), rec(210, 1), rec(2200, 100)}) == 2200)
  check('h008 4: 78 at 13s above one at 12s is still the market (Invoker\'s Cord)', sniper.market_now({rec(1200, 1), rec(1300, 78)}) == 1300)

  -- item names and 3 days of usual price (32s) for the items below
  local d = h.today()
  local names = {[901] = "Invoker's Cord", [902] = 'Flat Belt', [903] = 'Lone Belt', [904] = 'Wall Herb'}
  for id in pairs(names) do
    h.write_record(id .. ':0', {day = d, points = {{value = 3200, day = d - 1, units = 10}, {value = 3200, day = d - 2, units = 10}, {value = 3200, day = d - 3, units = 10}}})
  end
  local real_info, real_key_info = G.GetItemInfo, C_AuctionHouse.GetItemKeyInfo
  G.GetItemInfo = function(x)
    local id = type(x) == 'number' and x or tonumber(tostring(x):match('item:(%d+)'))
    if names[id] then return names[id], '|cffffffff|Hitem:' .. id .. '::::::0:0|h[' .. names[id] .. ']|h|r', 2, 20, 15, 'Armor', 'Cloth', 1, 'INVTYPE_WAIST', 1, 1 end
    return real_info(x)
  end
  rawset(C_AuctionHouse, 'GetItemKeyInfo', function(key) return names[key.itemID] and {itemID = key.itemID, itemName = names[key.itemID], quality = 2} or real_key_info(key) end)
  aux.account_data.sniper_percent, aux.account_data.sniper_profit = 60, 1

  -- finding 2: today's market on the item list comes from the last Full scan by the Sniper's own
  -- rule (cheapest price left out), not from price history's latest price
  local list = {}
  for _ = 1, 78 do tinsert(list, {id = 902, buyout = 1300}) end
  tinsert(list, {id = 902, buyout = 1250})
  tinsert(list, {id = 903, buyout = 300}) -- a snipe already up during the scan
  for _ = 1, 39 do tinsert(list, {id = 903, buyout = 3200}) end
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  set(C_AuctionHouse, 'ReplicateItems', function() end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return #list end)
  set(C_AuctionHouse, 'GetReplicateItemInfo', function(i) local x = list[i + 1]; return names[x.id], 1, 1, 2, true, 20, nil, 0, 0, x.buyout, 0, false, nil, 'Seller', nil, 0, x.id, true end)
  set(C_AuctionHouse, 'GetReplicateItemLink', function(i) local id = list[i + 1].id; return '|cffffffff|Hitem:' .. id .. '::::::0:0|h[' .. names[id] .. ']|h|r' end)
  local done
  scan.start{type = 'list', queries = {{blizzard_query = {}}}, get_all = true, quiet = true, on_complete = function() done = true end}
  for _ = 1, 10 do tick() end
  fire('REPLICATE_ITEM_LIST_UPDATE')
  for _ = 1, 120 do tick(); if done then break end end
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
  check('h008 2: the Full scan finished', done)
  check('h008 2: price history counts the snipe as the market (why it is not used)', h.latest('903:0') == 300)

  local real_check = sniper.check_item
  local opened = {}
  sniper.check_item = function(item_key, key, price, others) opened[key] = others or true end
  local function result(id, suffix, qty, price) return {itemKey = {itemID = id, itemSuffix = suffix, itemLevel = 20}, totalQuantity = qty, minPrice = price} end
  local function round(results, keep)
    if not keep then sniper.settings_changed() end
    opened = {}
    sniper.check_list(results, {})
  end
  local flat, lone = result(902, 0, 79, 1250), result(903, 0, 40, 300)
  local kflat, klone = scan.item_key_string(flat.itemKey), scan.item_key_string(lone.itemKey)
  round({flat, lone})
  check('h008 2: a price close to the Full scan\'s market is not opened', not opened[kflat])
  check('h008 2: a snipe that was up during the Full scan is still opened', opened[klone] ~= nil)
  -- the Sniper's own read of an item no longer hides it next round
  h.write_record('903:0', {day = d, market = 300, units = 1, low = 300, points = h.data_points('903:0')})
  round({lone})
  check('h008 2: a deal read today is opened again next round', opened[klone] ~= nil)

  -- finding 3: versions are read for real when a candidate is opened, not judged on the list
  local a, b = result(901, 11, 1, 1000), result(901, 12, 1, 1100)
  local ka, kb = scan.item_key_string(a.itemKey), scan.item_key_string(b.itemKey)
  round({a, b})
  check('h008 3: two cheap versions no longer block each other', opened[ka] and opened[kb])
  check('h008 3: and each is opened with the other to read', type(opened[ka]) == 'table' and opened[ka][1].itemSuffix == 12)
  sniper.check_item = real_check
  -- check_item with fake reads: version 11 has 1 at 12s and 8 at 32s, version 12 has 78 at 13s
  local scan_exports = loadstring("select(2, ...) 'aux.test.h008c'; return require 'aux.core.scan'")('auxForever', addon)
  local real_read = scan_exports.read_item
  local function item_rec(id, price, units)
    return rec(price, units, {item_id = id, price_key = id .. ':0', item_key = id .. ':0', name = names[id], quality = 2, texture = 1,
      link = '|cff1eff00|Hitem:' .. id .. '::::::0:0|h[' .. names[id] .. ']|h|r'})
  end
  local function cord(price, units) return item_rec(901, price, units) end
  local reads = {}
  rawset(scan_exports, 'read_item', function(key)
    reads[#reads + 1] = key.itemSuffix
    if key.itemSuffix == 11 then return {cord(1200, 1), cord(3200, 8)} end
    if key.itemSuffix == 12 then return {cord(1300, 78)} end
  end)
  sniper.clear_deals()
  sniper.check_item(a.itemKey, ka, 1200, {b.itemKey})
  local deal
  for _, x in ipairs(sniper.deals) do if x.deal_key == ka then deal = x end end
  check('h008 3: the other version\'s 78 at 13s count, so 12s is no deal (Invoker\'s Cord)', deal == nil and reads[1] == 11 and reads[2] == 12)
  rawset(scan_exports, 'read_item', function(key)
    if key.itemSuffix == 11 then return {cord(600, 1), cord(3200, 8)} end
    if key.itemSuffix == 12 then return {cord(1300, 78)} end
  end)
  sniper.check_item(a.itemKey, ka, 600, {b.itemKey})
  for _, x in ipairs(sniper.deals) do if x.deal_key == ka then deal = x end end
  check('h008 3: 6s next to 78 at 13s is a deal against that market', deal and deal.deal_reason == 'market' and deal.deal_market == 1300)

  -- finding 5: a remembered market is dropped when the list shows the units that made it are gone,
  -- and an item refused only because of it is judged again
  rawset(scan_exports, 'read_item', function() return {item_rec(904, 85, 2), item_rec(904, 87, 45), item_rec(904, 2200, 100)} end)
  local herb = result(904, 0, 147, 85)
  local kherb = scan.item_key_string(herb.itemKey)
  sniper.settings_changed()
  sniper.check_item(herb.itemKey, kherb, 85)
  sniper.check_item = function(item_key, key) opened[key] = true end
  local function herb_round(price) herb.minPrice = price; round({herb}, true) end
  herb_round(55)
  check('h008 5: a 55c herb next to the 87c wall is not opened', not opened[kherb])
  herb_round(2200)
  herb_round(55)
  check('h008 5: once the wall sold (lowest 22s), a 55c snipe is opened', opened[kherb])
  sniper.settings_changed()
  sniper.check_item = real_check
  sniper.check_item(herb.itemKey, kherb, 85)
  sniper.check_item = function(item_key, key) opened[key] = true end
  herb_round(86)
  local memory = sniper.MARKET_MEMORY
  sniper.MARKET_MEMORY = 0
  herb_round(86)
  sniper.MARKET_MEMORY = memory
  check('h008 5: refused only because of the remembered market, it is judged again when that is gone', opened[kherb])

  sniper.check_item = real_check
  rawset(scan_exports, 'read_item', real_read)
  G.GetItemInfo = real_info
  rawset(C_AuctionHouse, 'GetItemKeyInfo', real_key_info)
  sniper.clear_deals()
  sniper.settings_changed()
  for id in pairs(names) do h.data[id .. ':0'] = nil end
end)

-- review H-008 (note under finding 2): reading one version of a Sniper deal again before buying it
-- recorded that version alone as the item's day price; that read records none now
try('0.8.2: a deal read again records no day price', function()
  local scan = loadstring("select(2, ...) 'aux.test.h008d'; return require 'aux.core.scan'")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local items = {{id = 951, name = 'Reread Belt', min = 500, qty = 2, auctions = {{buyout = 500}, {buyout = 600}}}}
  local run, restore = fake_ah(items)
  h.data['951:0'] = nil
  local done
  scan.start{type = 'list', quiet = true, no_view = true, queries = {{item_keys = {{itemID = 951, itemSuffix = 0, itemLevel = 0}}}}, on_complete = function() done = true end}
  for _ = 1, 40 do run(1); if done then break end end
  local _, units = h.today_market('951:0')
  check('h008: the re-read finished', done)
  check('h008: and wrote no day price', units == nil)
  done = false
  scan.start{type = 'list', quiet = true, queries = {{item_keys = {{itemID = 951, itemSuffix = 0, itemLevel = 0}}}}, on_complete = function() done = true end}
  for _ = 1, 40 do run(1); if done then break end end
  _, units = h.today_market('951:0')
  check('h008: a normal read still does', done and units == 2)
  restore()
  h.data['951:0'] = nil
end)

-- 0.8.2 build 5 (Tyler: "clean, consistent"): the Sniper's Why column shows its percent in the colors
-- of the Search tab's % Hist. Value column and the tooltip's "(67%)"
try('0.8.2: the Sniper\'s percent in the Search colors', function()
  local sniper = loadstring("select(2, ...) 'aux.tabs.sniper'; return _M")('auxForever', addon)
  local gui = loadstring("select(2, ...) 'aux.test.b5'; return require 'aux.gui'")('auxForever', addon)
  local why
  for _, column in ipairs(sniper.columns) do if column.title == 'Why' then why = column end end
  local shown
  local cell = {text = {SetText = function(_, t) shown = t end}}
  why.fill(cell, {deal_reason = 'usual', deal_percent = 30})
  check('b5: 30% of usual in the Search tab\'s color for 30%', shown and shown:find(gui.percentage_historical(30), 1, true) == 1 and shown:find('of usual', 1, true) ~= nil)
  why.fill(cell, {deal_reason = 'market', deal_percent = 70})
  check('b5: 70% of market in the color for 70%', shown and shown:find(gui.percentage_historical(70), 1, true) == 1 and shown:find('of market', 1, true) ~= nil)
  why.fill(cell, {deal_reason = 'vendor', deal_percent = 10})
  check('b5: below vendor stays as it was', shown and shown:find('below vendor', 1, true) ~= nil)
end)

-- 0.8.2 build 6, Tyler's build 5 test: the Full scan button was gray while the Sniper ran ("I had to
-- stop sniper for full scan to ungrey"); and "% of usual" in the profession window's Materials hover
try('0.8.2 build 6: Full scan button and % of usual in crafting', function()
  local a = loadstring("select(2, ...) 'aux'; return _M")('auxForever', addon)
  local scan = loadstring("select(2, ...) 'aux.test.b6'; return require 'aux.core.scan'")('auxForever', addon)
  local search = loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)
  local h = loadstring("select(2, ...) 'aux.core.history'; return _M")('auxForever', addon)
  local btn = a.full_scan_button
  local enabled
  local real_enable, real_disable = rawget(btn, 'Enable'), rawget(btn, 'Disable')
  rawset(btn, 'Enable', function() enabled = true end)
  rawset(btn, 'Disable', function() enabled = false end)
  local was_shown = a.frame.__shown
  a.frame.__shown = true
  a.account_data.replicate_time = 0
  scan.start{type = 'list', quiet = true, queries = {{blizzard_query = {}}}}
  for _ = 1, 8 do tick() end
  check('b6: a search under way leaves Full scan clickable', scan.is_scanning() and enabled == true)
  local saved = {}
  local function set(t, k, v) tinsert(saved, {t, k, rawget(t, k)}); rawset(t, k, v) end
  set(C_AuctionHouse, 'ReplicateItems', function() end)
  set(C_AuctionHouse, 'GetNumReplicateItems', function() return 0 end)
  scan.start{type = 'list', quiet = true, queries = {{blizzard_query = {}}}, get_all = true}
  for _ = 1, 8 do tick() end
  check('b6: a Full scan under way grays it', scan.is_full_scan() and enabled == false)
  scan.abort()
  for i = #saved, 1, -1 do rawset(saved[i][1], saved[i][2], saved[i][3]) end
  rawset(btn, 'Enable', real_enable); rawset(btn, 'Disable', real_disable)
  a.frame.__shown = was_shown
  a.account_data.replicate_time = 0

  -- crafting: each material's latest price and the made item's, with the share of the usual price
  local d = h.today()
  h.write_record('7701:0', {day = d, low = 38, market = 39, units = 82, points = {{day = d - 2, value = 87}, {day = d - 3, value = 87}}})
  h.write_record('7702:0', {day = d, low = 200, market = 200, units = 10, points = {{day = d - 2, value = 400}, {day = d - 3, value = 400}}})
  local function plain(t) return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', '')) end
  local lines = {}
  local tip = new_frame()
  rawset(tip, 'AddLine', function(_, t) tinsert(lines, plain(t)) end)
  rawset(tip, 'AddDoubleLine', function(_, l, r) tinsert(lines, plain(l) .. ' | ' .. plain(r)) end)
  search.recipe_cost_tooltip(tip, {reagents = {{item_id = 7701, count = 2}}, output = {item_id = 7702, count = 1}})
  local all = table.concat(lines, '\n')
  check('b6: a material\'s price says its share of usual', all:find('78c (45%)  seen today', 1, true) ~= nil)
  check('b6: the made item\'s price says its share of usual', all:find('2s (50%)  seen today', 1, true) ~= nil)
  a.character_data.tooltip.usually = false
  lines = {}
  search.recipe_cost_tooltip(tip, {reagents = {{item_id = 7701, count = 2}}, output = {item_id = 7702, count = 1}})
  check('b6: the % of usual switch turns it off there too', not table.concat(lines, '\n'):find('%)', 1, true))
  a.character_data.tooltip.usually = true
  h.data['7701:0'] = nil; h.data['7702:0'] = nil

-- White shirts (Brawler's Harness) must not show disenchant lines
try('disenchant skips whites and shirts', function()
  local de = assert(loadstring("select(2, ...) 'aux.core.disenchant'; return _M"))('auxForever', addon)
  local info_mod = assert(loadstring("select(2, ...) 'aux.util.info'; return _M"))('auxForever', addon)
  check('de: white chest empty', #de.distribution('INVTYPE_CHEST', 1, 20) == 0)
  check('de: shirt slot empty even if uncommon', #de.distribution('INVTYPE_BODY', 2, 20) == 0)
  check('de: tabard slot empty even if uncommon', #de.distribution('INVTYPE_TABARD', 2, 20) == 0)
  check('de: green chest has outcomes', #de.distribution('INVTYPE_CHEST', 2, 20) > 0)
  local white = '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r'
  local green = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r'
  check('de: forever white named link is common', info_mod.quality_from_link(white) == 1)
  check('de: forever green named link is uncommon', info_mod.quality_from_link(green) == 2)
  check('de: white link overrides wrong uncommon GetItemInfo',
    info_mod.disenchant_quality({ quality = 2 }, white) == 1)
  check('de: green link overrides wrong common GetItemInfo',
    info_mod.disenchant_quality({ quality = 1 }, green) == 2)
  check('de: bare + tip_quality white', info_mod.disenchant_quality({ quality = 2 }, 'item:6125', 1) == 1)
  check('de: bare + tip_quality green', info_mod.disenchant_quality({ quality = 1 }, 'item:6545', 2) == 2)
  check('de: prefer colored hyperlink over bare GetItem',
    info_mod.prefer_quality_link('item:6125', white) == white)
  local real_q = G.C_Item.GetItemQualityByID
  G.C_Item.GetItemQualityByID = function() return nil end
  local q = info_mod.disenchant_quality({ quality = 2 }, 'item:6125')
  G.C_Item.GetItemQualityByID = real_q
  check('de: bare falls back to GetItemInfo quality', q == 2)
end)

-- Forever: random-suffix +stats missing from SetItemKey / stripped GetItem() links (FB-023)
try('suffix stats on tooltip', function()
  local tip_mod = assert(loadstring("select(2, ...) 'aux.core.tooltip'; return _M"))('auxForever', addon)
  local info_mod = assert(loadstring("select(2, ...) 'aux.util.info'; return _M"))('auxForever', addon)
  G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
  G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
  -- Simulate the shared-table bug: without a fresh dest table, leftover Strength would cancel deltas.
  local shared = { RESISTANCE0_NAME = 10, ITEM_MOD_STRENGTH_SHORT = 5, ITEM_MOD_STAMINA_SHORT = 3 }
  G.GetItemStats = function(link, dest)
    dest = dest or shared
    for k in pairs(dest) do dest[k] = nil end
    dest.RESISTANCE0_NAME = 10
    if type(link) == 'string' and (link:find('12732', 1, true) or link:find('14312', 1, true)) then
      dest.ITEM_MOD_STRENGTH_SHORT = 5
      dest.ITEM_MOD_STAMINA_SHORT = 3
    end
    return dest
  end
  G.C_Item.GetItemStats = G.GetItemStats
  local lines = { 'Soldier\'s Boots' } -- add_suffix_stats no-ops on an empty tip
  rawset(G.GameTooltip, 'NumLines', function() return #lines end)
  rawset(G.GameTooltip, 'AddLine', function(_, text) tinsert(lines, text) end)
  rawset(G.GameTooltip, 'Show', function() end)
  rawset(G.GameTooltip, 'IsShown', function() return true end)
  for i = 1, 10 do
    G['GameTooltipTextLeft' .. i] = { GetText = function() return lines[i] end }
  end
  local auction_link = 'item:6545::::::::20:1489::1:12732::::'
  check('suffix: injects strength from a full auction link', tip_mod.add_suffix_stats(G.GameTooltip, auction_link))
  check('suffix: strength line present', (function()
    for _, t in ipairs(lines) do if t == '+5 Strength' then return true end end
  end)())
  check('suffix: stamina line present', (function()
    for _, t in ipairs(lines) do if t == '+3 Stamina' then return true end end
  end)())
  local before = #lines
  tip_mod.add_suffix_stats(G.GameTooltip, auction_link)
  check('suffix: does not duplicate lines already shown', #lines == before)
  info_mod.remember_suffix_link(6545, 14312, auction_link)
  check('suffix: remembered link for Fast parent item key', tip_mod.link_for_item_key({ itemID = 6545, itemSuffix = 14312 }) == auction_link)
  -- Synthetic is allowed when GetItemStats yields +stats; a dead suffix must still return nil.
  check('suffix: synthetic ignored when GetItemStats empty', tip_mod.link_for_item_key({ itemID = 9999, itemSuffix = 999999 }) == nil)
  tip_mod.cache_suffix_stats(auction_link)
  check('suffix: cache_suffix_stats stores lines', tip_mod.suffix_stat_lines(auction_link) ~= nil)
end)

-- what players do while the auction house is still answering: a slow auction house that answers
-- a second later (tests/timing_test.lua, tests/slow_server.lua; FB-021)
dofile((arg and arg[0] or ''):gsub('[^/\\]*$', '') .. 'timing_test.lua')({
  G = G, fire = fire, tick = tick, check = check, try = try, addon = addon,
  dir = (arg and arg[0] or ''):gsub('[^/\\]*$', ''),
})

finish()
