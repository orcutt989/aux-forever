-- Comprehensive suffix-leak finder.
-- After an of-the-X AH hover, every other item tip must not inherit its +stats.
--
-- Driven by an item list file (id + optional name). The PowerShell runner builds that list
-- from the Forever auxForever SavedVariables item cache so we do not invent names by hand.
--
--   powershell -File tests/test-suffix-leak.ps1
--   lua5.1 ../tests/load_test.lua suffix-leak   # uses AUX_SUFFIX_LEAK_IDS or the fixture

return function(env)
  local G, check, try, addon = env.G, env.check, env.try, env.addon

  local function module(name)
    return loadstring("select(2, ...) '" .. name .. "'; return _M")('auxForever', addon)
  end

  local function load_items()
    local path = os.getenv('AUX_SUFFIX_LEAK_IDS')
    if (not path or path == '') and arg and arg[0] then
      local base = arg[0]:gsub('[^/\\]*$', '')
      path = base .. 'fixtures/suffix_leak_ids.tsv'
    end
    local items = {}
    if path then
      local f = io.open(path, 'r')
      if f then
        local first = true
        for line in f:lines() do
          if first then
            first = false
            -- skip header "id\tname"
          else
            local id, name = line:match('^(%d+)\t(.*)$')
            if id then
              tinsert(items, { id = tonumber(id), name = name ~= '' and name or ('item:' .. id) })
            end
          end
        end
        f:close()
      else
        print('suffix-leak: could not open ' .. tostring(path))
      end
    end
    if #items > 0 then
      return items
    end
    -- Built-in seed when no cache file exists yet.
    return {
      { id = 117, name = 'Tough Jerky' },
      { id = 2589, name = 'Linen Cloth' },
      { id = 2592, name = 'Wool Cloth' },
      { id = 3676, name = 'Slimy Ichor' },
      { id = 4538, name = 'Tel\'Abim Banana' },
      { id = 5339, name = 'Serpentbloom' },
      { id = 6125, name = 'Brawler\'s Harness' },
      { id = 6470, name = 'Deviate Hide' },
      { id = 6545, name = 'Soldier\'s Boots' },
      { id = 2835, name = 'Rough Stone' },
      { id = 17056, name = 'Light Feather' },
      { id = 3371, name = 'Empty Vial' },
    }
  end

  try('suffix-leak: scan item cache after of-the-X hover', function()
    local tip_mod = module 'aux.core.tooltip'
    local real_stats, real_cstats = G.GetItemStats, G.C_Item and G.C_Item.GetItemStats
    G.ITEM_MOD_STRENGTH_SHORT = 'Strength'
    G.DAMAGE_PER_SECOND = 'damage per second'
    G.GetItemStats = function(link, dest)
      dest = dest or {}
      for k in pairs(dest) do dest[k] = nil end
      return dest
    end
    local function owner_bonus_stats(link)
      -- Bonus id on the owner link — not bare item:12732 (Incendia Agave in the cache).
      return type(link) == 'string' and link:find('item:4568:', 1, true) and link:find(':12732', 1, true)
    end
    if G.C_Item then
      G.C_Item.GetItemStats = function(link)
        if owner_bonus_stats(link) then
          return { ITEM_MOD_STRENGTH_SHORT = 5, DAMAGE_PER_SECOND = 15 }
        end
        return {}
      end
    end

    local owner_id = 4568
    local owner_link = 'item:4568::::::::20:1489::1:12732::::'
    tip_mod.note_hover({
      item_id = owner_id,
      link = owner_link,
      suffix_stats = {
        { label = 'damage per second', amount = 15 },
        { label = 'Strength', amount = 5 },
      },
    }, owner_link)

    local items = load_items()
    local victims = {}
    local scanned = 0
    for _, row in ipairs(items) do
      local id = row.id or row[1]
      local name = row.name or row[2] or ('item:' .. tostring(id))
      id = tonumber(id)
      if id and id ~= owner_id then
        scanned = scanned + 1
        local tip_name = 'LeakTip' .. scanned
        local lines = { name }
        local tip = {
          GetName = function() return tip_name end,
          NumLines = function() return #lines end,
          AddLine = function(_, text) tinsert(lines, tostring(text or '')) end,
          Show = function() end,
          IsShown = function() return true end,
          IsForbidden = function() return false end,
        }
        for i = 1, 20 do
          G[tip_name .. 'TextLeft' .. i] = { GetText = function() return lines[i] end }
        end
        local before = #lines
        local link = format('item:%d::::::::20:1489:::::::', id)
        tip_mod.add_suffix_stats(tip, link)
        local leaked = false
        for i = before + 1, #lines do
          local t = lines[i]
          if t:find('+15 damage per second', 1, true) or t:find('+5 Strength', 1, true) or t:find('^%+%d+ ') then
            leaked = true
            break
          end
        end
        if leaked or #lines ~= before then
          tinsert(victims, { id = id, name = name })
        end
      end
    end

    print(format('suffix-leak scan: %d items, %d victims', scanned, #victims))
    local report_path
    if arg and arg[0] then
      report_path = arg[0]:gsub('[^/\\]*$', '') .. 'fixtures/suffix_leak_victims.tsv'
    end
    if report_path and #victims > 0 then
      local out = io.open(report_path, 'w')
      if out then
        out:write("id\tname\n")
        for _, v in ipairs(victims) do
          out:write(format("%d\t%s\n", v.id, v.name))
        end
        out:close()
        print('suffix-leak: full victim list -> ' .. report_path)
      end
    end
    local max_print = 30
    for i, v in ipairs(victims) do
      if i <= max_print then
        print(format('  VICTIM  %d  %s', v.id, v.name))
      end
    end
    if #victims > max_print then
      print(format('  ... and %d more (see fixtures/suffix_leak_victims.tsv)', #victims - max_print))
    end

    check('suffix-leak: scanned at least one non-owner item', scanned > 0)
    check('suffix-leak: zero victims across item cache', #victims == 0)

    G.GetItemStats = real_stats
    if real_cstats then G.C_Item.GetItemStats = real_cstats end
  end)
end
