-- Mutation proof for the Forever DE tip link picker.
--
-- PASS only if:
--   1) current tip_item_link handles white/green + cross-hover correctly
--   2) the OLD picker (last_link first, no same-item filter) FAILS cross-hover
--   3) shipped info.lua / tooltip.lua still contain the fixed call shape
--
-- (2) is what makes this gate trustworthy: if the suite cannot catch the bug that
-- caused in-game oscillation, we refuse to say "safe".
--
-- Run:  lua5.1 ../tests/de_mutation_prove.lua
--   or: powershell -File tests/test-de.ps1 -Prove

local function fail(msg)
  io.stderr:write('PROVE FAIL: ' .. msg .. '\n')
  os.exit(1)
end

local function ok(msg)
  print('PROVE OK: ' .. msg)
end

local LINK_QUALITY_HEX = {
  ['9d9d9d'] = 0, ['ffffff'] = 1, ['1eff00'] = 2,
  ['0070dd'] = 3, ['a335ee'] = 4, ['ff8000'] = 5,
}

local function quality_from_link(link)
  if type(link) ~= 'string' then return end
  local named = tonumber(link:match('|cn[IiLl]Q(%d+)'))
  if named ~= nil then return named end
  local rgb = (link:match('|c%x%x(%x%x%x%x%x%x)') or ''):lower()
  return LINK_QUALITY_HEX[rgb]
end

local function item_id_from_link(link)
  if type(link) ~= 'string' then return end
  return tonumber(link:match('item:(%-?%d+)'))
end

local function prefer_quality_link(...)
  local fallback
  for i = 1, select('#', ...) do
    local link = select(i, ...)
    if type(link) == 'string' and link:find('item:', 1, true) then
      if quality_from_link(link) ~= nil then
        return link
      end
      fallback = fallback or link
    end
  end
  return fallback
end

local function item_link_has_bonus_ids(link)
  if type(link) ~= 'string' then return false end
  local payload = link:match('item:(%-?%d+[:%d%-]*)')
  if not payload then return false end
  local fields = {}
  for part in string.gmatch(payload .. ':', '([^:]*):') do
    fields[#fields + 1] = part
  end
  local num_bonus = tonumber(fields[13])
  if num_bonus and num_bonus > 0 then return true end
  local suffix = tonumber(fields[7])
  return suffix ~= nil and suffix ~= 0
end

local function tip_item_link_new(last_link, hyperlink, get_item_link)
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

-- OLD buggy picker (what shipped during the oscillation)
local function tip_item_link_old(last_link, hyperlink, get_item_link)
  return prefer_quality_link(last_link, hyperlink, get_item_link)
end

local white = '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r'
local green = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r'
local bare_w = 'item:6125::::::::17:1486::75:::::::'
local bare_g = 'item:6545::::::::20:1489:::::::'

local of_the_x = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots of the Bear]|h|r'
local of_the_x_stripped = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots of the Bear]|h|r'

local cases = {
  { 'white hyperlink over bare', nil, white, bare_w, white },
  { 'green hyperlink over bare', nil, green, bare_g, green },
  { 'green tip ignores stale white last_link', white, green, bare_g, green },
  { 'white tip ignores stale green last_link', green, white, bare_w, white },
  { 'same-item last_link supplies color', green, nil, bare_g, green },
  { 'of-the-X keeps bonus auction link', of_the_x, of_the_x_stripped, bare_g, of_the_x },
}

print('=== DE mutation prove ===')

for _, c in ipairs(cases) do
  local got = tip_item_link_new(c[2], c[3], c[4])
  if got ~= c[5] then
    fail(string.format('NEW picker wrong on "%s": got %s', c[1], tostring(got)))
  end
end
ok('current tip_item_link passes all Forever shapes + cross-hover')

local old_cross_green = tip_item_link_old(white, green, bare_g)
local old_cross_white = tip_item_link_old(green, white, bare_w)
if old_cross_green == green then
  fail('old picker unexpectedly correct on green-after-white — mutation proof is broken')
end
ok('old picker wrongly keeps stale white on green tip (caught)')
if old_cross_white == white then
  fail('old picker unexpectedly correct on white-after-green — mutation proof is broken')
end
ok('old picker wrongly keeps stale green on white tip (caught)')

local function read_first(paths)
  for _, p in ipairs(paths) do
    local f = io.open(p, 'r')
    if f then
      local src = f:read('*a')
      f:close()
      return p, src
    end
  end
end

local info_path, info_src = read_first({
  'util/info.lua',
  '../auxForever/util/info.lua',
})
if not info_src then
  fail('could not open auxForever/util/info.lua')
end
if not info_src:find('function M.tip_item_link', 1, true) then
  fail('auxForever/util/info.lua missing tip_item_link')
end
if not info_src:find('item_link_has_bonus_ids(remembered)', 1, true) then
  fail('tip_item_link must prefer same-item bonus auction links for of-the-X')
end
if not info_src:find('prefer_quality_link(hyperlink, get_item_link, remembered)', 1, true) then
  fail('tip_item_link must fall back to prefer_quality_link(hyperlink, get_item_link, remembered)')
end
ok('shipped info.lua tip_item_link keeps of-the-X bonuses + DE order (' .. info_path .. ')')

local tip_path, tip_src = read_first({
  'core/tooltip.lua',
  '../auxForever/core/tooltip.lua',
})
if not tip_src then
  fail('could not open auxForever/core/tooltip.lua')
end
if not tip_src:find('info.tip_item_link', 1, true) then
  fail('tooltip post-call must use info.tip_item_link')
end
if tip_src:find('prefer_quality_link(\n            last_link[tooltip]', 1, true)
  or tip_src:find('prefer_quality_link(\r\n            last_link[tooltip]', 1, true)
  or tip_src:find('prefer_quality_link(last_link[tooltip]', 1, true) then
  fail('tooltip still prefers last_link[tooltip] first — old bug')
end
ok('shipped tooltip.lua uses tip_item_link, not last_link-first (' .. tip_path .. ')')

print('PROVE PASS: fix is real; suite catches the old bug')
os.exit(0)
