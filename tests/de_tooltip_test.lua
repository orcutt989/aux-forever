-- Forever AH disenchant tip contract — both sides must pass:
--   WHITE: bare GetItem + white data.hyperlink → no DE  (even if GetItemInfo.quality lies as 2)
--   GREEN: bare GetItem + green data.hyperlink → DE
--   GREEN: bare GetItem only + GetItemInfo.quality 2 → DE  (Forever sometimes omits hyperlink color)
--   Cross-hover: stale last_link of the *other* color must not flip this tip's DE
--
-- Run alone:  lua5.1 ../tests/load_test.lua de
-- Or loop:    powershell -File tests/test-de.ps1

return function(env)
  local G, check, try, addon = env.G, env.check, env.try, env.addon

  local function module(name)
    return loadstring("select(2, ...) '" .. name .. "'; return _M")('auxForever', addon)
  end

  G.ITEM_QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1, g = 1, b = 1 },
    [2] = { r = 0.12, g = 1, b = 0 },
    [3] = { r = 0, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
  }

  local tip_serial = 0
  local function tip_frame()
    tip_serial = tip_serial + 1
    local tip_name = 'DeTip' .. tip_serial
    local lines = { 'Item' }
    local tip = {
      GetName = function() return tip_name end,
      NumLines = function() return #lines end,
      AddLine = function(_, text) tinsert(lines, tostring(text or '')) end,
      Show = function() end,
      IsShown = function() return true end,
      IsForbidden = function() return false end,
    }
    G[tip_name .. 'TextLeft1'] = { GetText = function() return lines[1] end }
    for i = 2, 40 do
      G[tip_name .. 'TextLeft' .. i] = { GetText = function() return lines[i] end }
    end
    if G.AuxTooltip then
      rawset(G.AuxTooltip, 'NumLines', function() return 0 end)
    end
    return tip, lines
  end

  local function has_de(lines)
    for _, t in ipairs(lines) do
      if t:find('Disenchants into:', 1, true) or t:find('Disenchant:', 1, true) then
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
      if row then return unpack(row) end
    end
    local ok, err = pcall(body)
    G.GetItemInfo = real
    if not ok then error(err, 0) end
  end

  local function row(name, link, quality, level, slot, sell)
    return { name, link, quality, level, 0, 'Armor', 'Leather', 1, slot, '', sell or 1 }
  end

  local white_hl = '|cnlQ1:|Hitem:6125::::::::17:1486::75:::::::|h[Brawler\'s Harness]|h|r'
  local green_hl = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots]|h|r'
  local bare_w = 'item:6125::::::::17:1486::75:::::::'
  local bare_g = 'item:6545::::::::20:1489:::::::'

  -- Exact Forever post-call path: tip_item_link then extend_tooltip.
  local function ah_tip(case)
    local tip_mod = module 'aux.core.tooltip'
    local info_mod = module 'aux.util.info'
    local aux = module 'aux'
    local tipset = aux.character_data.tooltip
    local saved = {}
    for k, v in pairs(tipset) do saved[k] = v end
    tipset.disenchant_value = true
    tipset.disenchant_distribution = true
    tipset.merchant_sell = true
    tipset.value = false
    tipset.money_icons = false

    local link = info_mod.tip_item_link(case.last_link, case.hyperlink, case.get_item)
    local tip, lines = tip_frame()
    with_item_info({ [case.id] = case.info }, function()
      tip_mod.extend_tooltip(tip, link, 1, case.tip_quality)
    end)

    for k in pairs(tipset) do tipset[k] = nil end
    for k, v in pairs(saved) do tipset[k] = v end
    return has_de(lines), link
  end

  try('de-tip: tip_item_link order', function()
    local info_mod = module 'aux.util.info'
    check('de-tip: WHITE hyperlink over bare GetItem',
      info_mod.tip_item_link(nil, white_hl, bare_w) == white_hl)
    check('de-tip: GREEN hyperlink over bare GetItem',
      info_mod.tip_item_link(nil, green_hl, bare_g) == green_hl)
    -- Stale last_link from the OTHER item must not win.
    check('de-tip: green tip ignores stale white last_link',
      info_mod.tip_item_link(white_hl, green_hl, bare_g) == green_hl)
    check('de-tip: white tip ignores stale green last_link',
      info_mod.tip_item_link(green_hl, white_hl, bare_w) == white_hl)
    -- Same item: colored last_link may fill in when hyperlink is bare.
    check('de-tip: same-item last_link supplies color',
      info_mod.tip_item_link(green_hl, nil, bare_g) == green_hl)
    local of_the_x = '|cnIQ2:|Hitem:6545::::::::20:1489::1:12732::::|h[Soldier\'s Boots of the Bear]|h|r'
    local stripped = '|cnIQ2:|Hitem:6545::::::::20:1489:::::::|h[Soldier\'s Boots of the Bear]|h|r'
    check('de-tip: of-the-X keeps bonus auction link over stripped hyperlink',
      info_mod.tip_item_link(of_the_x, stripped, bare_g) == of_the_x)
  end)

  try('de-tip: CONTRACT white no DE / green has DE', function()
    local real_q = G.C_Item.GetItemQualityByID
    G.C_Item.GetItemQualityByID = function() return nil end

    local white_de, white_link = ah_tip({
      id = 6125,
      get_item = bare_w,
      hyperlink = white_hl,
      last_link = nil,
      tip_quality = nil,
      info = row('Brawler\'s Harness', white_hl, 2, 1, 'INVTYPE_CHEST', 1),
    })
    check('de-tip: CONTRACT white uses colored hyperlink', white_link == white_hl)
    check('de-tip: CONTRACT white has NO Disenchant %', white_de == false)

    local green_de, green_link = ah_tip({
      id = 6545,
      get_item = bare_g,
      hyperlink = green_hl,
      last_link = nil,
      tip_quality = nil,
      info = row('Soldier\'s Boots', green_hl, 2, 20, 'INVTYPE_FEET', 100),
    })
    check('de-tip: CONTRACT green uses colored hyperlink', green_link == green_hl)
    check('de-tip: CONTRACT green HAS Disenchant %', green_de == true)

    local green_bare_de = ah_tip({
      id = 6545,
      get_item = bare_g,
      hyperlink = nil,
      last_link = nil,
      tip_quality = nil,
      info = row('Soldier\'s Boots', bare_g, 2, 20, 'INVTYPE_FEET', 100),
    })
    check('de-tip: CONTRACT green bare GetItemInfo q2 still DE', green_bare_de == true)

    -- The bug that made tests green while the game oscillated: previous hover's last_link.
    local green_after_white = ah_tip({
      id = 6545,
      get_item = bare_g,
      hyperlink = green_hl,
      last_link = white_hl,
      tip_quality = nil,
      info = row('Soldier\'s Boots', green_hl, 2, 20, 'INVTYPE_FEET', 100),
    })
    check('de-tip: CONTRACT green after white hover still DE', green_after_white == true)

    local white_after_green = ah_tip({
      id = 6125,
      get_item = bare_w,
      hyperlink = white_hl,
      last_link = green_hl,
      tip_quality = nil,
      info = row('Brawler\'s Harness', white_hl, 2, 1, 'INVTYPE_CHEST', 1),
    })
    check('de-tip: CONTRACT white after green hover still no DE', white_after_green == false)

    G.C_Item.GetItemQualityByID = real_q
  end)
end
