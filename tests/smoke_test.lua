-- auxForever smoke checks: fast tooltip loop while editing FB-023 paths.
--
--   cd auxForever
--   lua5.1 ../tests/load_test.lua smoke
--
-- For the fuller local contract (money, buy bar, value age, suffix, DE matrix):
--   lua5.1 ../tests/load_test.lua basics
--
-- This file must restore every global and tooltip switch it touches so the full
-- load_test suite is not poisoned when smoke runs first.

return function(env)
  local G, check, try, addon = env.G, env.check, env.try, env.addon

  local function module(name)
    return loadstring("select(2, ...) '" .. name .. "'; return _M")('auxForever', addon)
  end

  local function tip_lines()
    local lines = {}
    local tip = {
      GetName = function() return 'GameTooltip' end,
      NumLines = function() return #lines end,
      AddLine = function(_, text) tinsert(lines, tostring(text or '')) end,
      Show = function() end,
      IsShown = function() return true end,
      IsForbidden = function() return false end,
      GetItem = function() return nil, nil end,
    }
    for i = 1, 40 do
      G['GameTooltipTextLeft' .. i] = { GetText = function() return lines[i] end }
    end
    if G.AuxTooltip then
      rawset(G.AuxTooltip, 'NumLines', function() return 0 end)
    end
    return tip, lines
  end

  local function has(lines, fragment)
    for _, t in ipairs(lines) do
      if t:find(fragment, 1, true) then
        return true
      end
    end
    return false
  end

  local function with_item_info(items, body)
    local real = G.GetItemInfo
    G.GetItemInfo = function(x)
      local id = tonumber(tostring(x):match('item:(%d+)') or tostring(x):match('(%d+)'))
      local row = id and items[id]
      if row then
        return unpack(row)
      end
    end
    local ok, err = pcall(body)
    G.GetItemInfo = real
    if not ok then
      error(err, 0)
    end
  end

  local function row(name, link, quality, level, slot, sell, class, subclass)
    return { name, link, quality, level, 0, class or 'Armor', subclass or 'Mail', 1, slot, '', sell or 0 }
  end

  local function with_tooltip_settings(overrides, body)
    local aux = module 'aux'
    local tip = aux.character_data.tooltip
    local saved = {}
    for k, v in pairs(tip) do saved[k] = v end
    for k, v in pairs(overrides) do tip[k] = v end
    local ok, err = pcall(body, aux)
    for k in pairs(tip) do tip[k] = nil end
    for k, v in pairs(saved) do tip[k] = v end
    if not ok then error(err, 0) end
  end

  try('smoke: disenchant table', function()
    local de = module 'aux.core.disenchant'
    check('smoke: green chest has DE outcomes', #de.distribution('INVTYPE_CHEST', 2, 20) > 0)
    check('smoke: green weapon has DE outcomes', #de.distribution('INVTYPE_WEAPON', 2, 30) > 0)
    check('smoke: white chest has no DE', #de.distribution('INVTYPE_CHEST', 1, 20) == 0)
    check('smoke: shirt slot has no DE', #de.distribution('INVTYPE_BODY', 2, 20) == 0)
    check('smoke: tabard slot has no DE', #de.distribution('INVTYPE_TABARD', 2, 20) == 0)
    check('smoke: gray junk has no DE', #de.distribution('INVTYPE_CHEST', 0, 20) == 0)
  end)

  try('smoke: quality_from_link formats', function()
    local info_mod = module 'aux.util.info'
    local cases = {
      { '|cffffffff|Hitem:6125|h[x]|h|r', 1, 'classic hex white' },
      { '|cff1eff00|Hitem:6545|h[x]|h|r', 2, 'classic hex green' },
      { '|cff9d9d9d|Hitem:1|h[x]|h|r', 0, 'classic hex gray' },
      { '|cnIQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r', 1, 'forever cnIQ1' },
      { '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r', 2, 'forever cnIQ2' },
      { '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r', 1, 'forever cnlQ1' },
      { '|cnlQ2:|Hitem:6545|h[x]|h|r', 2, 'forever cnlQ2' },
      { 'item:6545', nil, 'bare itemstring' },
    }
    for _, c in ipairs(cases) do
      check('smoke: link quality ' .. c[3], info_mod.quality_from_link(c[1]) == c[2])
    end
    local white = '|cnlQ1:|Hitem:6125|h[Brawler\'s Harness]|h|r'
    local green = '|cnIQ2:|Hitem:6545|h[Soldier\'s Boots]|h|r'
    check('smoke: white named beats wrong GetItemInfo',
      info_mod.disenchant_quality({ quality = 2 }, white) == 1)
    check('smoke: green named beats wrong GetItemInfo',
      info_mod.disenchant_quality({ quality = 1 }, green) == 2)
    check('smoke: bare + tip_quality white blocks DE',
      info_mod.disenchant_quality({ quality = 2 }, 'item:6125:::::::::', 1) == 1)
    check('smoke: bare + tip_quality green allows DE',
      info_mod.disenchant_quality({ quality = 1 }, 'item:6545:::::::::', 2) == 2)
    check('smoke: prefer hyperlink over bare GetItem',
      info_mod.prefer_quality_link('item:6125', white) == white)
    local real_q = G.C_Item.GetItemQualityByID
    G.C_Item.GetItemQualityByID = function() return nil end
    local q = info_mod.disenchant_quality({ quality = 2 }, 'item:6125')
    G.C_Item.GetItemQualityByID = real_q
    check('smoke: bare falls back to GetItemInfo quality', q == 2)
    check('smoke: tooltip data quality',
      info_mod.quality_from_tooltip_data({ lines = {{ type = 22, quality = 2 }} }) == 2)
  end)

  try('smoke: tooltip DE matrix', function()
    local tip_mod = module 'aux.core.tooltip'
    local white_named = '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r'
    local green_named = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r'
    local green_hex = '|cff1eff00|Hitem:6545::::::0:0|h[Soldier\'s Boots]|h|r'

    local matrix = {
      {
        name = 'classic green boots', id = 6545, link = green_hex, tip_quality = nil,
        info = row('Soldier\'s Boots', green_hex, 2, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true,
      },
      {
        name = 'forever green boots cnIQ2', id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', green_named, 2, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true,
      },
      {
        name = 'AH data.hyperlink green', id = 6545,
        link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', white_named, 1, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true,
      },
      {
        name = 'AH bare green + tip_quality 2', id = 6545,
        link = 'item:6545::::::::20:1489:::::::', tip_quality = 2,
        info = row('Soldier\'s Boots', white_named, 1, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true,
      },
      {
        name = 'AH bare + lying GetItemInfo only → no DE', id = 6125,
        link = 'item:6125::::::::17:1486::75:::::::', tip_quality = nil,
        info = row('Brawler\'s Harness', white_named, 2, 1, 'INVTYPE_CHEST', 1),
        de = false, vendor = true,
      },
      {
        name = 'forever white shirt cnlQ1', id = 6125, link = white_named, tip_quality = nil,
        info = row('Brawler\'s Harness', white_named, 1, 1, 'INVTYPE_BODY', 1, 'Armor', 'Miscellaneous'),
        de = false, vendor = true,
      },
      {
        name = 'AH bare white + tip_quality 1 + lying CHEST', id = 6125,
        link = 'item:6125::::::::17:1486::75:::::::', tip_quality = 1,
        info = row('Brawler\'s Harness', green_named, 2, 1, 'INVTYPE_CHEST', 1),
        de = false, vendor = true,
      },
      {
        name = 'settings off: green has no DE', id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', green_named, 2, 20, 'INVTYPE_FEET', 100),
        de = false, vendor = true,
        switches = { disenchant_value = false, disenchant_distribution = false },
      },
    }

    for _, case in ipairs(matrix) do
      with_tooltip_settings({
        disenchant_value = true,
        disenchant_distribution = true,
        merchant_sell = true,
        value = false,
        money_icons = false,
      }, function(aux)
        if case.switches then
          for k, v in pairs(case.switches) do aux.character_data.tooltip[k] = v end
        end
        local tip, lines = tip_lines()
        with_item_info({ [case.id] = case.info }, function()
          tip_mod.extend_tooltip(tip, case.link, 1, case.tip_quality)
        end)
        local got_de = has(lines, 'Disenchants into:') or has(lines, 'Disenchant:')
        check('smoke matrix: ' .. case.name .. ' DE', got_de == case.de)
        check('smoke matrix: ' .. case.name .. ' Vendor', has(lines, 'Vendor:') == case.vendor)
      end)
    end
  end)

  try('smoke: suffix inject must not erase DE lines', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_stats = G.GetItemStats
    local real_cstats = G.C_Item and G.C_Item.GetItemStats
    local real_mod = G.ITEM_MOD_STRENGTH_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = G.ITEM_MOD_STAMINA_SHORT or 'Stamina'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      dest.RESISTANCE0_NAME = 10
      -- Must match stats used by later basics/suffix tests: item_string() strips |cnIQ… so the
      -- cache key is shared across colored and bare links with the same item string.
      if type(link) == 'string' and link:find('12732', 1, true) then
        dest.ITEM_MOD_STRENGTH_SHORT = 5
        dest.ITEM_MOD_STAMINA_SHORT = 3
      end
      return dest
    end
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end

    local auction_link = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots]|h|r'
    local ok, err = pcall(function()
      with_tooltip_settings({
        disenchant_value = true,
        disenchant_distribution = true,
        merchant_sell = false,
        value = false,
        money_icons = false,
      }, function()
        local tip, lines = tip_lines()
        local show_calls = 0
        with_item_info({
          [6545] = row('Soldier\'s Boots', auction_link, 2, 20, 'INVTYPE_FEET', 100),
        }, function()
          tip_mod.extend_tooltip(tip, auction_link, 1)
          check('smoke: DE present after extend', has(lines, 'Disenchants into:') and has(lines, 'Disenchant:'))
          check('smoke: suffix +stat present after extend', has(lines, '+5 Strength'))
          rawset(tip, 'Show', function()
            show_calls = show_calls + 1
            for i = #lines, 1, -1 do lines[i] = nil end
          end)
          tip_mod.schedule_suffix_stats(tip, auction_link)
          for _ = 1, 10 do env.tick() end
        end)
        check('smoke: DE still present after suffix retry', has(lines, 'Disenchants into:') and has(lines, 'Disenchant:'))
        check('smoke: suffix +stat still present after retry', has(lines, '+5 Strength'))
        check('smoke: suffix retry did not Show (would wipe DE)', show_calls == 0)
      end)
    end)

    G.GetItemStats = real_stats
    if G.C_Item then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_mod
    if not ok then error(err, 0) end
  end)
end
