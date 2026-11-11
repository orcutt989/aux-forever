-- auxForever local basics suite: player-facing core, no game client.
--
--   cd auxForever
--   lua5.1 ../tests/load_test.lua basics
--
-- Or from repo root (Windows):
--   powershell -File tests/test-basics.ps1
--
-- Covers: TOC load (via harness), money text, disenchant table, Forever/Classic
-- link quality, tooltip DE/vendor/value matrix, suffix +stat inject without wiping DE.

return function(env)
  local G, check, try, addon, tick = env.G, env.check, env.try, env.addon, env.tick

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
      if tostring(t):find(fragment, 1, true) then
        return true
      end
    end
    return false
  end

  local function plain(t)
    return ((t or ''):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[^:]+:', ''):gsub('|r', ''):gsub('FONT_COLOR_CODE_CLOSE', ''))
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
    for k, v in pairs(tip) do
      saved[k] = v
    end
    for k, v in pairs(overrides) do
      tip[k] = v
    end
    local ok, err = pcall(body, aux, tip)
    for k in pairs(tip) do
      tip[k] = nil
    end
    for k, v in pairs(saved) do
      tip[k] = v
    end
    if not ok then
      error(err, 0)
    end
  end

  try('basics: money text', function()
    local money = module 'aux.util.money'
    check('basics: 1c formats', money.to_string2(1):find('1', 1, true) ~= nil)
    check('basics: 100c is 1s', money.to_string2(100):find('1', 1, true) ~= nil)
    check('basics: 10000c is 1g', money.to_string2(10000):find('1', 1, true) ~= nil)
  end)

  try('basics: buy bar stack quantities', function()
    local bar = module 'aux.gui.buy_bar'
    local function same(a, b)
      if #a ~= #b then return false end
      for i = 1, #a do if a[i] ~= b[i] then return false end end
      return true
    end
    check('basics: stack 20', same(bar.quantities(20), {1, 5, 10, 20}))
    check('basics: stack 5', same(bar.quantities(5), {1, 5}))
    check('basics: stack 1 empty', same(bar.quantities(1), {}))
  end)

  try('basics: disenchant table', function()
    local de = module 'aux.core.disenchant'
    check('basics: green chest DE', #de.distribution('INVTYPE_CHEST', 2, 20) > 0)
    check('basics: green weapon DE', #de.distribution('INVTYPE_WEAPON', 2, 30) > 0)
    check('basics: white chest no DE', #de.distribution('INVTYPE_CHEST', 1, 20) == 0)
    check('basics: shirt no DE', #de.distribution('INVTYPE_BODY', 2, 20) == 0)
    check('basics: tabard no DE', #de.distribution('INVTYPE_TABARD', 2, 20) == 0)
    check('basics: gray no DE', #de.distribution('INVTYPE_CHEST', 0, 20) == 0)
  end)

  -- Grunt Axe of Power tip (Forever): Disenchants into Lesser Astral Essence 75%, Strange Dust
  -- 15%, Small Glimmering Shard 10% (uncommon weapon ilvl 21–25). Mat history shaped like the
  -- live SV: today's market is cheap, an older day is expensive. history.value (usual) still
  -- follows the old day and ignores today until midnight — that produced Disenchant: 46s53c
  -- while today's mats imply ~10s. Tooltip DE value should track latest mat prices (same idea
  -- as Value:), not the inflated usual.
  try('basics: DE value uses latest mat prices (Grunt Axe)', function()
    local de = module 'aux.core.disenchant'
    local h = module 'aux.core.history'
    local today = h.today()

    local dist = de.distribution('INVTYPE_WEAPON', 2, 25)
    check('basics: Grunt Axe bracket has 3 outcomes', #dist == 3)
    local by_id = {}
    for _, e in ipairs(dist) do by_id[e.item_id] = e end
    check('basics: Grunt Axe 75% Lesser Astral Essence',
      by_id[10998] and by_id[10998].probability == .75
        and by_id[10998].min_quantity == 1 and by_id[10998].max_quantity == 2)
    check('basics: Grunt Axe 15% Strange Dust 4-6',
      by_id[10940] and by_id[10940].probability == .15
        and by_id[10940].min_quantity == 4 and by_id[10940].max_quantity == 6)
    check('basics: Grunt Axe 10% Small Glimmering Shard',
      by_id[10978] and by_id[10978].probability == .10)

    -- Live-shaped history (copper): today market vs older point that still drives usual.
    h.write_record('10998:0', {
      day = today, low = 800, market = 800, units = 150,
      points = {{ day = today - 3, value = 4000, units = 23 }},
    })
    h.write_record('10940:0', {
      day = today, low = 79, market = 79, units = 2707,
      points = {
        { day = today - 1, value = 125, units = 2468 },
        { day = today - 2, value = 101, units = 985 },
        { day = today - 3, value = 115, units = 1909 },
      },
    })
    h.write_record('10978:0', {
      day = today, low = 390, market = 390, units = 139,
      points = {
        { day = today - 1, value = 674, units = 115 },
        { day = today - 3, value = 949, units = 78 },
      },
    })

    local usual_essence = h.value('10998:0')
    local latest_essence = h.latest('10998:0')
    check('basics: essence usual still old 40s', usual_essence == 4000)
    check('basics: essence latest is today 8s', latest_essence == 800)

    local function expected_from(price_of)
      local total = 0
      for _, e in ipairs(dist) do
        local p = price_of(e.item_id .. ':0') or 0
        total = total + e.probability * (e.min_quantity + e.max_quantity) / 2 * p
      end
      return total
    end
    local from_usual = expected_from(h.value)
    local from_latest = expected_from(function(key) return select(1, h.latest(key)) end)

    check('basics: usual-based DE matches inflated tip (~46s)',
      from_usual > 4500 and from_usual < 4800)
    check('basics: latest-based DE is ~today mats (~10s)',
      from_latest > 900 and from_latest < 1200)

    local got = de.value('INVTYPE_WEAPON', 2, 25)
    check('basics: DE value follows latest mats not stale usual',
      got and abs(got - from_latest) < 1)
    check('basics: DE value is not the inflated usual expectation',
      got and abs(got - from_usual) > 100)
  end)

  try('basics: link quality formats', function()
    local info_mod = module 'aux.util.info'
    local cases = {
      { '|cffffffff|Hitem:6125|h[x]|h|r', 1 },
      { '|cff1eff00|Hitem:6545|h[x]|h|r', 2 },
      { '|cff9d9d9d|Hitem:1|h[x]|h|r', 0 },
      { '|cnIQ1:|Hitem:6125|h[x]|h|r', 1 },
      { '|cnIQ2:|Hitem:6545|h[x]|h|r', 2 },
      { '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r', 1 },
      { '|cnlQ2:|Hitem:6545|h[x]|h|r', 2 },
      { '|cnIQ3|Hitem:1|h[x]|h|r', 3 },
      { 'item:6545', nil },
    }
    for i, c in ipairs(cases) do
      check('basics: link quality #' .. i, info_mod.quality_from_link(c[1]) == c[2])
    end
    local white = '|cnlQ1:|Hitem:6125|h[x]|h|r'
    local green = '|cnIQ2:|Hitem:6545|h[x]|h|r'
    local bare = 'item:6125::::::::17:1486::75:::::::'
    local signals = {
      { 'hover white beats info q2', { quality = 2 }, white, nil, 1 },
      { 'hover green beats info q1', { quality = 1 }, green, nil, 2 },
      { 'bare + tip_quality white', { quality = 2 }, bare, 1, 1 },
      { 'bare + tip_quality green', { quality = 1 }, bare, 2, 2 },
      -- Last resort: bare link + GetItemInfo.quality (greens when Forever omits color).
      -- Whites are blocked by prefer_quality_link + colored hyperlink, not by rejecting this.
      { 'bare + numeric uses GetItemInfo quality', { quality = 2 }, bare, nil, 2 },
      { 'prefer_quality_link picks white hyperlink', nil, nil, nil, white,
        prefer = { bare, white } },
      { 'tooltip data quality helper', nil, nil, nil, 1, { lines = {{ type = 22, quality = 1, leftText = 'Shirt' }} } },
    }
    local real_q = G.C_Item and G.C_Item.GetItemQualityByID
    if G.C_Item then G.C_Item.GetItemQualityByID = function() return nil end end
    for _, c in ipairs(signals) do
      if c.prefer then
        check('basics: ' .. c[1], info_mod.prefer_quality_link(unpack(c.prefer)) == c[5])
      elseif c[6] then
        check('basics: ' .. c[1], info_mod.quality_from_tooltip_data(c[6]) == c[5])
      else
        check('basics: ' .. c[1], info_mod.disenchant_quality(c[2], c[3], c[4]) == c[5])
      end
    end
    if G.C_Item then G.C_Item.GetItemQualityByID = real_q end
  end)

  try('basics: tooltip matrix', function()
    local tip_mod = module 'aux.core.tooltip'
    local white_named = '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r'
    local green_named = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r'
    local green_hex = '|cff1eff00|Hitem:6545::::::0:0|h[Soldier\'s Boots]|h|r'

    -- tip_quality = Forever ItemName.quality from TooltipDataProcessor (nil when absent).
    local matrix = {
      {
        name = 'forever green colored hover',
        id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', green_named, 2, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true, value = true,
        history_key = '6545:0', history_copper = 250,
      },
      {
        name = 'classic green hex hover',
        id = 6545, link = green_hex, tip_quality = nil,
        info = row('Soldier\'s Boots', green_hex, 2, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true, value = false,
      },
      {
        name = 'green hover when GetItemInfo quality lies white',
        id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', green_named, 1, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true, value = false,
      },
      {
        name = 'AH colored green hyperlink (data.hyperlink shape)',
        id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', white_named, 1, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true, value = false,
      },
      {
        name = 'AH bare green + tip_quality 2',
        id = 6545, link = 'item:6545::::::::20:1489:::::::', tip_quality = 2,
        info = row('Soldier\'s Boots', white_named, 1, 20, 'INVTYPE_FEET', 100),
        de = true, vendor = true, value = false,
      },
      {
        name = 'AH bare + lying GetItemInfo only → no DE',
        id = 6125, link = 'item:6125::::::::17:1486::75:::::::', tip_quality = nil,
        info = row('Brawler\'s Harness', white_named, 2, 1, 'INVTYPE_CHEST', 1),
        de = false, vendor = true, value = false,
      },
      {
        name = 'forever white colored hover',
        id = 6125, link = white_named, tip_quality = nil,
        info = row('Brawler\'s Harness', white_named, 1, 1, 'INVTYPE_BODY', 1, 'Armor', 'Miscellaneous'),
        de = false, vendor = true, value = false,
      },
      {
        name = 'white hover when GetItemInfo lies green CHEST',
        id = 6125, link = white_named, tip_quality = nil,
        info = row('Brawler\'s Harness', white_named, 2, 1, 'INVTYPE_CHEST', 1),
        de = false, vendor = true, value = false,
      },
      {
        name = 'AH bare white + tip_quality 1 + lying GetItemInfo CHEST',
        id = 6125, link = 'item:6125::::::::17:1486::75:::::::', tip_quality = 1,
        info = row('Brawler\'s Harness', green_named, 2, 1, 'INVTYPE_CHEST', 1),
        de = false, vendor = true, value = false,
      },
      {
        name = 'shirt BODY never DE even if tip says green',
        id = 6125, link = 'item:6125::::::::17:1486::75:::::::', tip_quality = 2,
        info = row('Brawler\'s Harness', green_named, 2, 1, 'INVTYPE_BODY', 1),
        de = false, vendor = true, value = false,
      },
      {
        name = 'DE switches off',
        id = 6545, link = green_named, tip_quality = nil,
        info = row('Soldier\'s Boots', green_named, 2, 20, 'INVTYPE_FEET', 100),
        de = false, vendor = true, value = false,
        switches = { disenchant_value = false, disenchant_distribution = false },
      },
    }

    for _, case in ipairs(matrix) do
      with_tooltip_settings({
        disenchant_value = true,
        disenchant_distribution = true,
        merchant_sell = true,
        value = case.value and true or false,
        money_icons = false,
      }, function(aux)
        if case.switches then
          for k, v in pairs(case.switches) do
            aux.character_data.tooltip[k] = v
          end
        end
        if case.value and case.history_key then
          local h = module 'aux.core.history'
          local today = h.today()
          h.write_record(case.history_key, {
            day = today,
            market = case.history_copper,
            low = case.history_copper,
            units = 1,
            points = {{ day = today, value = case.history_copper }},
          })
        end
        local tip, lines = tip_lines()
        with_item_info({ [case.id] = case.info }, function()
          tip_mod.extend_tooltip(tip, case.link, 1, case.tip_quality)
        end)
        local got_de = has(lines, 'Disenchants into:') or has(lines, 'Disenchant:')
        check('basics matrix: ' .. case.name .. ' DE', got_de == case.de)
        check('basics matrix: ' .. case.name .. ' Vendor', has(lines, 'Vendor:') == case.vendor)
        if case.value then
          check('basics matrix: ' .. case.name .. ' Value', has(lines, 'Value:'))
        end
      end)
    end
  end)

  try('basics: value age on tip', function()
    local tip_mod = module 'aux.core.tooltip'
    local h = module 'aux.core.history'
    local today = h.today()
    h.write_record('9301:0', { day = today, points = {{ day = today - 3, value = 1000 }} })
    with_tooltip_settings({
      value = true, merchant_sell = false, disenchant_value = false, disenchant_distribution = false, money_icons = false,
    }, function()
      local tip, lines = tip_lines()
      with_item_info({
        [9301] = row('X', '|cffffffff|Hitem:9301::::::0:0|h[X]|h|r', 1, 1, '', 0),
      }, function()
        tip_mod.extend_tooltip(tip, '|cffffffff|Hitem:9301::::::0:0|h[X]|h|r', 1)
      end)
      local value_line
      for _, l in ipairs(lines) do
        if plain(l):find('^Value') then value_line = plain(l) end
      end
      check('basics: Value shows age', value_line and value_line:find('seen 3 days ago', 1, true) ~= nil)
    end)
  end)

  try('basics: shift stack value', function()
    local tip_mod = module 'aux.core.tooltip'
    local h = module 'aux.core.history'
    local today = h.today()
    h.write_record('7401:0', { day = today, market = 40, points = {{ day = today, value = 40 }} })
    local real_shift = G.IsShiftKeyDown
    G.IsShiftKeyDown = function() return true end
    with_tooltip_settings({
      value = true, merchant_sell = false, disenchant_value = false, disenchant_distribution = false, money_icons = false,
    }, function()
      local tip, lines = tip_lines()
      with_item_info({
        [7401] = row('X', '|cffffffff|Hitem:7401::::::0:0|h[X]|h|r', 1, 1, '', 0),
      }, function()
        tip_mod.extend_tooltip(tip, '|cffffffff|Hitem:7401::::::0:0|h[X]|h|r', 3)
      end)
      local value_line
      for _, l in ipairs(lines) do
        if plain(l):find('^Value') then value_line = plain(l) end
      end
      check('basics: stack Value says for 3', value_line and value_line:find('for 3', 1, true) ~= nil)
    end)
    G.IsShiftKeyDown = real_shift
  end)

  try('basics: suffix inject keeps DE', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_mod = G.ITEM_MOD_STRENGTH_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      dest.RESISTANCE0_NAME = 10
      if type(link) == 'string' and link:find('12732', 1, true) then
        dest.ITEM_MOD_STRENGTH_SHORT = 5
        dest.ITEM_MOD_STAMINA_SHORT = 3
      end
      return dest
    end
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end

    local auction_link = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots]|h|r'
    with_tooltip_settings({
      disenchant_value = true, disenchant_distribution = true, merchant_sell = false, value = false, money_icons = false,
    }, function()
      local tip, lines = tip_lines()
      local show_calls = 0
      with_item_info({
        [6545] = row('Soldier\'s Boots', auction_link, 2, 20, 'INVTYPE_FEET', 100),
      }, function()
        tip_mod.extend_tooltip(tip, auction_link, 1)
        check('basics: DE after extend', has(lines, 'Disenchants into:') and has(lines, 'Disenchant:'))
        check('basics: +stat after extend', has(lines, '+5 Strength'))
        rawset(tip, 'Show', function()
          show_calls = show_calls + 1
          for i = #lines, 1, -1 do lines[i] = nil end
        end)
        tip_mod.schedule_suffix_stats(tip, auction_link)
        for _ = 1, 10 do tick() end
      end)
      check('basics: DE after suffix retry', has(lines, 'Disenchants into:') and has(lines, 'Disenchant:'))
      check('basics: +stat after suffix retry', has(lines, '+5 Strength'))
      check('basics: suffix retry did not Show', show_calls == 0)
    end)

    G.GetItemStats = real_stats
    if G.C_Item then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_mod
  end)

  -- Forever AH "of the X" (random suffix): aux notes the full auction itemLink (bonus IDs),
  -- then TooltipDataProcessor post-call supplies a colored hyperlink / bare GetItem WITHOUT
  -- those bonuses. The link fed to extend_tooltip / schedule_suffix_stats must still carry
  -- the bonus id, or +Strength/+Stamina never appear on the tip.
  try('basics: of-the-X AH tip keeps suffix stats', function()
    local tip_mod = module 'aux.core.tooltip'
    local info_mod = module 'aux.util.info'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_str, real_sta = G.ITEM_MOD_STRENGTH_SHORT, G.ITEM_MOD_STAMINA_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      dest.RESISTANCE0_NAME = 10
      -- Bonus id 12732 = rolled "of the Bear" stats on this harness stub.
      if type(link) == 'string' and link:find('12732', 1, true) then
        dest.ITEM_MOD_STRENGTH_SHORT = 5
        dest.ITEM_MOD_STAMINA_SHORT = 3
      end
      return dest
    end
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end

    local auction_link = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots of the Bear]|h|r'
    local tip_hyperlink = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots of the Bear]|h|r'
    local bare_getitem = 'item:6545::::::::20:1489:::::::'

    with_tooltip_settings({
      disenchant_value = true, disenchant_distribution = true,
      merchant_sell = false, value = false, money_icons = false,
    }, function()
      local tip, lines = tip_lines()
      tip_mod.note_link(tip, auction_link)
      tip_mod.note_hover({ item_id = 6545, suffix_id = 14312, link = auction_link }, auction_link)

      -- Same picker the Forever Item post-call uses.
      local link = info_mod.tip_item_link(auction_link, tip_hyperlink, bare_getitem)
      check('basics: of-the-X post-call link keeps bonus id 12732',
        type(link) == 'string' and link:find('12732', 1, true) ~= nil)

      with_item_info({
        [6545] = row('Soldier\'s Boots of the Bear', auction_link, 2, 20, 'INVTYPE_FEET', 100),
      }, function()
        tip_mod.extend_tooltip(tip, link, 1)
        tip_mod.schedule_suffix_stats(tip, link)
        for _ = 1, 10 do tick() end
      end)

      check('basics: of-the-X AH tip shows +Strength', has(lines, '+5 Strength'))
      check('basics: of-the-X AH tip shows +Stamina', has(lines, '+3 Stamina'))
      check('basics: of-the-X AH tip still has DE',
        has(lines, 'Disenchants into:') and has(lines, 'Disenchant:'))
    end)

    G.GetItemStats = real_stats
    if G.C_Item then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_str
    G.ITEM_MOD_STAMINA_SHORT = real_sta
  end)

  -- FB-023: Fast parent rows call SetItemKey (suffix name, no bonus IDs). Opened auctions
  -- remember a full link; the parent must still inject +stats when the tip post-call only
  -- sees stripped GetItem / hyperlink. Also works via synthetic itemSuffix bonus link
  -- before any auction is opened, when GetItemStats accepts that form.
  try('basics: of-the-X Fast parent SetItemKey shows suffix stats', function()
    local tip_mod = module 'aux.core.tooltip'
    local info_mod = module 'aux.util.info'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_str, real_sta = G.ITEM_MOD_STRENGTH_SHORT, G.ITEM_MOD_STAMINA_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      dest.RESISTANCE0_NAME = 10
      if type(link) == 'string' and (link:find('12732', 1, true) or link:find('14312', 1, true)) then
        dest.ITEM_MOD_STRENGTH_SHORT = 5
        dest.ITEM_MOD_STAMINA_SHORT = 3
      end
      return dest
    end
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end

    local auction_link = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots of the Bear]|h|r'
    local tip_hyperlink = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots of the Bear]|h|r'
    local bare_getitem = 'item:6545::::::::20:1489:::::::'
    local key = { itemID = 6545, itemLevel = 20, itemSuffix = 14312 }

    local function run_fast_parent(inject_link)
      local tip, lines = tip_lines()
      tinsert(lines, 'Soldier\'s Boots of the Bear')
      local record = {
        browse_key = key,
        link = tip_hyperlink,
        suffix_id = 14312,
      }
      -- ShowRecordTooltip contract: note_hover + inject_link first, then SetItemKey-like
      -- post-call (stripped tip signals), Show wipe, then schedule inject_link.
      tip_mod.note_hover(record, inject_link)
      if inject_link then
        tip_mod.note_link(tip, inject_link)
        record.suffix_stats = tip_mod.cache_suffix_stats(inject_link)
      end
      local post_link = info_mod.tip_item_link(
        inject_link, tip_hyperlink, bare_getitem
      )
      with_tooltip_settings({
        disenchant_value = true, disenchant_distribution = true,
        merchant_sell = false, value = false, money_icons = false,
      }, function()
        with_item_info({
          [6545] = row('Soldier\'s Boots of the Bear', tip_hyperlink, 2, 20, 'INVTYPE_FEET', 100),
        }, function()
          tip_mod.extend_tooltip(tip, post_link, 1)
          -- Forever Show() rebuild drops aux lines.
          for i = #lines, 2, -1 do lines[i] = nil end
          tip_mod.schedule_suffix_stats(tip, inject_link or post_link)
          for _ = 1, 10 do tick() end
        end)
      end)
      return lines, record
    end

    -- After an item search remembered the bonus link (opened auctions).
    info_mod.remember_suffix_link(6545, 14312, auction_link)
    local lines_remember = run_fast_parent(tip_mod.link_for_item_key(key))
    check('basics: Fast parent with remember shows +Strength', has(lines_remember, '+5 Strength'))
    check('basics: Fast parent with remember shows +Stamina', has(lines_remember, '+3 Stamina'))

    -- Never opened: link_for_item_key must still find a usable of-the-X link (synthetic).
    -- Clear remember table by remembering over a different key path — use fresh suffix module state
    -- via a key that only synthetic can satisfy on a new item id.
    local key2 = { itemID = 6546, itemLevel = 20, itemSuffix = 14312 }
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      dest.RESISTANCE0_NAME = 10
      if type(link) == 'string' and link:find('6546', 1, true) and link:find('14312', 1, true) then
        dest.ITEM_MOD_STRENGTH_SHORT = 5
        dest.ITEM_MOD_STAMINA_SHORT = 3
      end
      return dest
    end
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end
    local synth = tip_mod.link_for_item_key(key2)
    check('basics: Fast parent synthetic link_for_item_key', type(synth) == 'string' and synth:find('14312', 1, true) ~= nil)
    local tip2, lines2 = tip_lines()
    tinsert(lines2, 'Boots of the Bear')
    local record2 = { browse_key = key2, link = 'item:6546', suffix_id = 14312 }
    tip_mod.note_hover(record2, synth)
    record2.suffix_stats = tip_mod.cache_suffix_stats(synth)
    tip_mod.note_link(tip2, synth)
    local post2 = info_mod.tip_item_link(synth, '|cnIQ2:|Hitem:6546|h[x]|h|r', 'item:6546')
    with_item_info({
      [6546] = row('Boots of the Bear', 'item:6546', 2, 20, 'INVTYPE_FEET', 100),
    }, function()
      tip_mod.extend_tooltip(tip2, post2, 1)
      for i = #lines2, 2, -1 do lines2[i] = nil end
      tip_mod.schedule_suffix_stats(tip2, synth)
      for _ = 1, 10 do tick() end
    end)
    check('basics: Fast parent synthetic shows +Strength', has(lines2, '+5 Strength'))

    G.GetItemStats = real_stats
    if G.C_Item then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_str
    G.ITEM_MOD_STAMINA_SHORT = real_sta
  end)

  try('basics: suffix add_suffix_stats', function()
    local tip_mod = module 'aux.core.tooltip'
    local info_mod = module 'aux.util.info'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_str, real_sta = G.ITEM_MOD_STRENGTH_SHORT, G.ITEM_MOD_STAMINA_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
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
    if G.C_Item then G.C_Item.GetItemStats = G.GetItemStats end

    local lines = { 'Soldier\'s Boots' } -- add_suffix_stats requires an open tip with >= 1 line
    local tip = {
      NumLines = function() return #lines end,
      AddLine = function(_, text) tinsert(lines, text) end,
      Show = function() end,
      IsShown = function() return true end,
      IsForbidden = function() return false end,
      GetName = function() return 'GameTooltip' end,
    }
    for i = 1, 10 do
      G['GameTooltipTextLeft' .. i] = { GetText = function() return lines[i] end }
    end
    local auction_link = 'item:6545::::::::20:1489::1:12732::::'
    check('basics: suffix injects', tip_mod.add_suffix_stats(tip, auction_link))
    check('basics: suffix strength', has(lines, '+5 Strength'))
    check('basics: suffix stamina', has(lines, '+3 Stamina'))
    local before = #lines
    tip_mod.add_suffix_stats(tip, auction_link)
    check('basics: suffix no dupes', #lines == before)
    info_mod.remember_suffix_link(6545, 14312, auction_link)
    check('basics: suffix remember', tip_mod.link_for_item_key({ itemID = 6545, itemSuffix = 14312 }) == auction_link)

    G.GetItemStats = real_stats
    if G.C_Item then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_str
    G.ITEM_MOD_STAMINA_SHORT = real_sta
  end)

  -- Forever-shaped API: global GetItemStats exists but returns nothing useful; only
  -- C_Item.GetItemStats(link) (no dest table) returns rolled of-the-X stats — matching
  -- AuxSuffixFix. Preferring the empty global masks C_Item and wipes +stats in game.
  try('basics: of-the-X prefers C_Item.GetItemStats over empty GetItemStats', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_str, real_sta = G.ITEM_MOD_STRENGTH_SHORT, G.ITEM_MOD_STAMINA_SHORT
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.ITEM_MOD_STAMINA_SHORT = 'Stamina'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      return dest -- empty, like Forever's unusable global
    end
    G.C_Item = G.C_Item or {}
    G.C_Item.GetItemStats = function(link)
      if type(link) == 'string' and link:find('12732', 1, true) then
        return {
          RESISTANCE0_NAME = 10,
          ITEM_MOD_STRENGTH_SHORT = 5,
          ITEM_MOD_STAMINA_SHORT = 3,
        }
      end
      if type(link) == 'string' and link:match('item:(%d+)') then
        return { RESISTANCE0_NAME = 10 }
      end
    end

    local auction_link = 'item:6545::::::::20:1489::1:12732::::'
    local lines = tip_mod.suffix_stat_lines(auction_link)
    check('basics: C_Item path yields Strength delta', lines and (function()
      for _, e in ipairs(lines) do if e.label == 'Strength' and e.amount == 5 then return true end end
    end)())
    check('basics: C_Item path yields Stamina delta', lines and (function()
      for _, e in ipairs(lines) do if e.label == 'Stamina' and e.amount == 3 then return true end end
    end)())

    local tip, tip_lines_ = tip_lines()
    tinsert(tip_lines_, 'Soldier\'s Boots of the Bear')
    check('basics: C_Item path injects into tip', tip_mod.add_suffix_stats(tip, auction_link))
    check('basics: C_Item path tip +Strength', has(tip_lines_, '+5 Strength'))

    G.GetItemStats = real_stats
    if real_cstats then G.C_Item.GetItemStats = real_cstats end
    G.ITEM_MOD_STRENGTH_SHORT = real_str
    G.ITEM_MOD_STAMINA_SHORT = real_sta
  end)

  -- After an AH of-the-X hover, add_suffix_stats fell through to last_hover.record.suffix_stats
  -- on the next tip when the new link had no cache — leaking green +stats onto unrelated items
  -- (Deviate Hide / Wool Cloth / Tel'Abim Banana, …). Invariant: only the owning item_id may
  -- receive those lines — enumerate named cases plus a wide id sweep so we do not play whack-a-mole.
  try('basics: suffix stats do not leak onto next item tip', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    local real_dps = G.DAMAGE_PER_SECOND
    G.DAMAGE_PER_SECOND = 'damage per second'
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      return dest
    end
    local function axe_bonus_stats(link)
      -- Bonus id 12732 on the axe — not bare item:12732 (Incendia Agave).
      return type(link) == 'string' and link:find('item:4568:', 1, true) and link:find(':12732', 1, true)
    end
    if G.C_Item then
      G.C_Item.GetItemStats = function(link)
        if axe_bonus_stats(link) then
          return { ITEM_MOD_STRENGTH_SHORT = 5, DAMAGE_PER_SECOND = 15 }
        end
        return {}
      end
    end

    local axe_id = 4568
    local axe_link = 'item:4568::::::::20:1489::1:12732::::'
    local axe_record = {
      item_id = axe_id,
      link = axe_link,
      suffix_stats = {
        { label = 'damage per second', amount = 15 },
        { label = 'Strength', amount = 5 },
      },
    }
    tip_mod.note_hover(axe_record, axe_link)
    tip_mod.cache_suffix_stats(axe_link)

    local function assert_no_leak(label, item_id)
      local tip, lines = tip_lines()
      tinsert(lines, label)
      local before = #lines
      local link = format('item:%d::::::::20:1489:::::::', item_id)
      -- Only suffix inject — extend_tooltip also writes Value/Vendor and would false-fail #lines.
      tip_mod.add_suffix_stats(tip, link)
      local leaked = false
      for i = before + 1, #lines do
        local t = lines[i]
        if t:find('+15 damage per second', 1, true) or t:find('+5 Strength', 1, true) or t:find('^%+%d+ ') then
          leaked = true
          break
        end
      end
      leaked = leaked or #lines ~= before
      check('basics: no suffix leak on ' .. label .. ' (' .. item_id .. ')', not leaked)
      return leaked
    end

    -- Named cases seen in game (and close cousins).
    local named = {
      { 'Deviate Hide', 6470 },
      { 'Linen Cloth', 2589 },
      { 'Wool Cloth', 2592 },
      { 'Tel\'Abim Banana', 4538 },
      { 'Slimy Ichor', 3676 },
      { 'Serpentbloom', 5339 },
      { 'Brawler\'s Harness', 6125 },
      { 'Tough Jerky', 117 },
      { 'Soldier\'s Boots (no bonus)', 6545 },
      { 'Rough Stone', 2835 },
      { 'Light Feather', 17056 },
      { 'Empty Vial', 3371 },
    }
    local leak_count = 0
    for _, v in ipairs(named) do
      if assert_no_leak(v[1], v[2]) then
        leak_count = leak_count + 1
      end
    end

    -- Wide sweep: any other item id must not inherit axe suffix_stats (owner id excluded).
    local sweep = {
      118, 159, 414, 1179, 2589, 2592, 2770, 2836, 4536, 4537, 4538, 4539, 4604,
      4605, 4656, 5057, 6470, 6471, 7005, 8948, 14047, 16204, 17056, 3371, 3372,
    }
    local seen = { [axe_id] = true }
    for _, v in ipairs(named) do seen[v[2]] = true end
    for _, id in ipairs(sweep) do
      if not seen[id] then
        seen[id] = true
        if assert_no_leak('item:' .. id, id) then
          leak_count = leak_count + 1
        end
      end
    end
    check('basics: suffix leak victim count is 0', leak_count == 0)

    -- Control: the axe itself still gets equip +stats from its own link.
    local tip_axe, lines_axe = tip_lines()
    tinsert(lines_axe, 'Grunt Axe of Power')
    tip_mod.add_suffix_stats(tip_axe, axe_link)
    check('basics: axe owner still shows +Strength', has(lines_axe, '+5 Strength'))

    G.GetItemStats = real_stats
    if real_cstats then G.C_Item.GetItemStats = real_cstats end
    G.DAMAGE_PER_SECOND = real_dps
  end)

  -- Once a leak runs, cached_suffix_lines[victim] is poisoned for the session — even after
  -- last_hover is cleared, Wool Cloth would keep showing the axe's +stats.
  try('basics: suffix leak must not poison victim cache', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_cstats = G.C_Item and G.C_Item.GetItemStats
    G.DAMAGE_PER_SECOND = 'damage per second'
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    if G.C_Item then
      G.C_Item.GetItemStats = function() return {} end
    end
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      return dest
    end

    local axe_link = 'item:4568::::::::20:1489::1:12732::::'
    local wool_link = 'item:2592::::::::20:1489:::::::'
    tip_mod.note_hover({
      item_id = 4568,
      link = axe_link,
      suffix_stats = { { label = 'Strength', amount = 5 } },
    }, axe_link)

    local tip1, lines1 = tip_lines()
    tinsert(lines1, 'Wool Cloth')
    tip_mod.add_suffix_stats(tip1, wool_link)
    -- Clear AH hover memory (as if the player moved on).
    tip_mod.note_hover(nil, nil)

    local tip2, lines2 = tip_lines()
    tinsert(lines2, 'Wool Cloth')
    tip_mod.add_suffix_stats(tip2, wool_link)
    check('basics: wool cache not poisoned after leak', not has(lines2, '+5 Strength'))

    if real_cstats then G.C_Item.GetItemStats = real_cstats end
  end)

  -- OnUpdate retry can still call add_suffix_stats(GameTooltip, axe_link) while the tip now
  -- shows Tel'Abim Banana — painting axe +stats onto the banana tip.
  try('basics: suffix retry must not paint prior item onto new tip', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_cstats = G.C_Item and G.C_Item.GetItemStats
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    if G.C_Item then
      G.C_Item.GetItemStats = function(link)
        if type(link) == 'string' and link:find('12732', 1, true) then
          return { ITEM_MOD_STRENGTH_SHORT = 5 }
        end
        return {}
      end
    end

    local axe_link = 'item:4568::::::::20:1489::1:12732::::'
    local banana_link = 'item:4538::::::::20:1489:::::::'
    local tip, lines = tip_lines()
    tinsert(lines, 'Grunt Axe of Power')
    tip_mod.note_hover({ item_id = 4568, link = axe_link }, axe_link)
    tip_mod.schedule_suffix_stats(tip, axe_link)

    -- Tip switches to banana while retry frames are still pending.
    for i = #lines, 1, -1 do lines[i] = nil end
    tinsert(lines, 'Tel\'Abim Banana')
    tip_mod.note_hover({ item_id = 4538, link = banana_link }, banana_link)
    tip_mod.note_link(tip, banana_link)
    for _ = 1, 10 do tick() end

    check('basics: banana tip has no retry-painted +Strength', not has(lines, '+5 Strength'))

    if real_cstats then G.C_Item.GetItemStats = real_cstats end
  end)

  -- GetItemStats includes DAMAGE_PER_SECOND for weapons; that is not a random-suffix bonus and
  -- must not become a green "+N damage per second" AddLine (looks like the Deviate Hide bug).
  try('basics: suffix inject skips damage per second', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_cstats = G.C_Item and G.C_Item.GetItemStats
    local real_dps = G.DAMAGE_PER_SECOND
    G.DAMAGE_PER_SECOND = 'damage per second'
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    if G.C_Item then
      G.C_Item.GetItemStats = function(link)
        if type(link) == 'string' and link:find('12732', 1, true) then
          return {
            ITEM_MOD_STRENGTH_SHORT = 5,
            DAMAGE_PER_SECOND = 15,
            RESISTANCE0_NAME = 20,
          }
        end
        if type(link) == 'string' and link:find('item:4568', 1, true) then
          return { DAMAGE_PER_SECOND = 10, RESISTANCE0_NAME = 20 }
        end
        return {}
      end
    end

    local axe_link = 'item:4568::::::::20:1489::1:12732::::'
    local lines = tip_mod.suffix_stat_lines(axe_link) or {}
    local has_dps_line = false
    local has_str = false
    for _, e in ipairs(lines) do
      if e.label == 'damage per second' then has_dps_line = true end
      if e.label == 'Strength' and e.amount == 5 then has_str = true end
    end
    check('basics: suffix_stat_lines omits damage per second', not has_dps_line)
    check('basics: suffix_stat_lines keeps Strength', has_str)

    local tip, tip_lines_ = tip_lines()
    tinsert(tip_lines_, 'Grunt Axe of Power')
    tip_mod.add_suffix_stats(tip, axe_link)
    check('basics: tip omits +15 damage per second', not has(tip_lines_, 'damage per second'))
    check('basics: tip keeps +5 Strength', has(tip_lines_, '+5 Strength'))

    if real_cstats then G.C_Item.GetItemStats = real_cstats end
    G.DAMAGE_PER_SECOND = real_dps
  end)
end
