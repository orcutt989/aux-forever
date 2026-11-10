# Testing auxForever in game

Each test build gets a test page from Claude: one card per step with Pass, Fail and Skip, a note
and screenshots. Answers save by themselves and Claude reads them, so say "done" in the chat when
finished. The steps below are the same as on the page, for anyone testing without it.

If BugSack shows an error at any point, copy its full text into that step's note.

## Local tests (no game client)

Prefer these until they are green. They stub the WoW API in Lua 5.1 and exit 1 on failure.

```
cd auxForever
lua5.1 ../tests/load_test.lua basics    # DE / value / vendor / suffix / money / buy bar
lua5.1 ../tests/load_test.lua smoke     # fast tooltip matrix (Forever |cnIQ + Classic hex)
lua5.1 ../tests/load_test.lua           # full suite
```

Windows one-shot: `powershell -File tests/test-basics.ps1` (syntax + basics + smoke).

Suffix-leak finder (every item in your Forever aux cache — no hand-maintained list):

```
powershell -File tests/test-suffix-leak.ps1
```

Writes `tests/fixtures/suffix_leak_ids.tsv` from SavedVariables and, on failure,
`tests/fixtures/suffix_leak_victims.tsv` (id + name of every tip that inherited of-the-X +stats).

Current test page: https://claude.ai/artifact/LUCZVgJV27irizAyKHTjhJ (private to Tyler)

## Current build: suffix tooltip stats (FB-023, unreleased)

`/reload` after copying the `auxForever` folder. Disable any leftover `AuxSuffixFix` companion.

- [ ] 1. Fast search for random-suffix gear. Hover a **parent** row icon: name may show the
      suffix; +stats may be missing until step 2.
- [ ] 2. Click the parent to open its auctions. Hover an auction icon: green `+N Stat` lines
      (and/or the game's own suffix stats) are visible.
- [ ] 3. Go back to the Fast list (or search again). Hover that same parent icon: the same
      +stats now show (remembered link from the opened search).
- [ ] 4. First search of the session still completes (no need to search twice).

## Previous build: 0.7.1.1 build 2

Fixes from FB-021 (sarrathsilentstrider could not post Rough Stone at 5c with the lowest at 7c)
and from the new slow auction house in the tests, which plays each tab against answers that come
a second later (`tests/slow_server.lua`, `tests/timing_test.lua`). Zip
`auxForever-0.7.1.1-build2.zip`; `/reload` is enough. Test page build id `0-7-1-1-build-2`. Use
the New theme. Have a cheap trade good several players sell (Linen Cloth, Rough Stone, Copper Ore)
and one cheap piece of gear. Build 2 adds gear with only a buyout (step 7) and a look at whether
Blizzard's window takes copper for gear (step 8); build 1 was not tested.

Tested by Tyler 2026-10-19 (test page `0-7-1-1-build-2`, screenshots): steps 1, 2, 5, 6 pass
(Light Feather listed at 7c: 4c typed and posted with Match lowest, 5c typed and posted with
Undercut on, "Your own price" both times; 1 Linen Cloth bought; Sniper watching with 97 deals).
Steps 3 and 4 could not be seen by hand: the listings arrive too fast ("I cant even move that
fast"); the timing tests cover them. Step 7: the sword was posted with bid equal to buyout (11s),
which Blizzard's list shows as buyout only; the empty starting bid case was not tried by hand
(covered by a test). Step 8: Blizzard's window has a copper box for gear, but the 10s 50c post
there does not seem to have gone through (`docs/forever-auction-house.md`, section 4).

- [ ] 1. Post tab: pick the trade good, wait until the bar at the bottom turns gold. Click the
      Buyout box, type a price 2c below the lowest listing, press Enter. Post is bright and the
      line under the price says "Your own price". Set the amount to 1 and Post: "Posted 1".
- [ ] 2. Click Undercut, then type a price 2c below the lowest again and press Enter. Post is
      bright. Post 1: "Posted 1".
- [ ] 3. Pick another item and, before the bar turns gold, type a price in the Buyout box. When
      the bar turns gold, your price is still there ("Your own price"). No need to post.
- [ ] 4. Pick another item and look at the Post button right away: faded, "Reading the
      listings..." next to it, until the bar turns gold. Skip if it is too quick to see.
- [ ] 5. Search `linen cloth` and buy 1 (Buy, then Confirm): "Bought 1 × Linen Cloth".
- [ ] 6. Sniper: Start. When a deal shows up, click it, then click it again to let go: the status
      goes back to "Watching" and the rounds go on. Skip if no deal shows up in a few minutes.
- [ ] 7. Post tab, a piece of gear: clear the Starting bid box (right-click it), type a buyout,
      press Enter. Post is bright and the note says "No starting bid, so it posts as buyout
      only". Post it at a price you are happy with: "Posted 1".
- [ ] 8. Blizzard UI button, Sell tab, put a piece of gear in: does its price box have a copper
      field (g, s and c), or only gold and silver? Screenshot. This decides whether aux may keep
      rounding gear prices to whole silver.

### 0.7.1 build 3

Build 3 takes out two things from build 2, after Tyler's test (2026-10-17): the deposit rounding
(Forever returns `SupportsCopperValues()` true, so it never applied) and the "Post tab starts on"
setting (Tyler: keep it as it is). The rest is build 2 (FB-014 to FB-016), tested. Zip
`auxForever-0.7.1-build3.zip`; `/reload` is enough. Test page build id `0-7-1-build-3`.
Tested by Tyler 2026-10-17 (screenshots): all 6 pass. Settings shows only Default duration;
Undercut stayed on across posts and reset on reopening; the item keys printed (below); the
Auctions tab said "Tied with 4 others" at 6s for Ritual Belt of Arcane Protection, which matches
the 5 listed under its exact key (his own plus 4); Classic shows one row per auction. Steps:

- [ ] 1. Settings (gear): Posting has only Default duration (no "Post tab starts on").
- [ ] 2. Post tab: click Undercut, post one cheap item, pick another item, post it. Both in
      Undercut mode. Close the auction house and open it again: Match lowest.
- [ ] 3. Post one cheap piece of gear that others also sell (Ritual Bands, or any green gear with
      several listings), then paste in chat:
      `/run for i=1,C_AuctionHouse.GetNumOwnedAuctions() do local a=C_AuctionHouse.GetOwnedAuctionInfo(i) local k=a.itemKey print("mine",a.itemLink,k.itemID,k.itemLevel,k.itemSuffix) end`
      Screenshot the chat.
- [ ] 4. In aux, search that item's name (Full mode), then paste:
      `/run for _,r in ipairs(C_AuctionHouse.GetBrowseResults()) do local k=r.itemKey print("listed",k.itemID,k.itemLevel,k.itemSuffix,r.totalQuantity,r.minPrice) end`
      Screenshot the chat and aux's results.
- [ ] 5. Auctions tab, Check prices: screenshot the row (Lowest other, Status) next to Blizzard's
      Sell tab for the same item.
- [ ] 6. Theme Classic, `/reload`, Auctions tab with that auction up: one row per auction.

### 0.7.1 build 2

Tested by Tyler 2026-10-17 (test page `0-7-1-build-2`, screenshots): two identical Ritual Bands
of Spirit showed as two rows; both cancelled and left the list; "tigerstrike mantle" found 2 in
aux and in Blizzard's window; `SupportsCopperValues()` is true; deposits matched the game for
Linen Cloth and Ritual Bands (1s each, 1s taken); "Post tab starts on" worked but Tyler did not
want it. The Classic step could not be done (no auctions left). Seen on the side: the Auctions tab
said "Only one listed" for the Ritual Bands while aux's Post tab had listed others of the same
version a minute before (9s, 1g 55s); steps 3 to 5 of build 3 check it.

### 0.7 build 4

FB-013 (HoaxBox, iLvl and colored Req columns) and FB-012 (MDHippie, `AuxForeverAPI`), plus the
fast resize fix. Tested by Tyler on 2026-10-13: all 6 steps pass. Released as 0.7. The steps are
in git history (`TESTING.md` at commit 37336f7).

### 0.6.1.1 build 1

Fix for FB-011 (Gaddor): clicking an item's icon in the Post tab's bag list selects it. Tested by
Tyler on 2026-10-12 (screenshots): all 3 steps pass (icon click selects, name click selects,
right-click on the icon searches). Released as 0.6.1.1.

Earlier: 0.6.1 build 2 (weapon slots in Search, audit fixes), tested in game and released. Its
steps and results, kept for reference:

### 0.6.1 build 2

Tested by Tyler on 2026-10-11 (test page `0-6-1-build-2`, screenshots): steps 1 to 5 pass
(daggers, staves, cloth chests and bows only, In words "Daggers (weapons, one-handed)."). Step 6:
autocompletion works ("linen" completed to "linen bag/exact"); own auctions not checked, he had
none up. Tyler found step 6 confusing (two checks in one, the second needing auctions). Optional
steps 7 and 8 done: the game's names, now in `tests/forever_categories.lua`.

0.6.1 build 1 was the same weapon slot fix under the name 0.6.0.3. `/reload` is enough (no new
files). Steps, in the New theme:

- [ ] 1. Search tab, "Which items": Category Weapons, Type One-Handed, Slot Daggers, then Search.
      The search bar shows `weapons/one-handed/daggers`, the search is short, and only daggers
      are listed.
- [ ] 2. Same with Two-Handed and Staves: only staves.
- [ ] 3. Armor, Cloth, Chest: only cloth chest pieces (this worked before; check it still does).
- [ ] 4. Type `weapons/ranged/bows` in the search bar and press Enter: only bows, and the menus
      show Weapons, Ranged, Bows.
- [ ] 5. Filter Builder tab, after step 1: "In words" reads "Daggers (weapons, one-handed)".
- [ ] 6. After a search, type the first letters of an item from the results in the search bar:
      its name is offered. Your own auctions still show as yours (green) in the Auctions tab.

Optional (checks the category names the automated tests use; `docs/audit-classic-code.md`), with
the auction house open, paste each line into chat and take a screenshot of what it prints:

- [ ] 7. `/run for i,c in ipairs(AuctionCategories) do local t={} for _,s in ipairs(c.subCategories or {}) do t[#t+1]=s.name end print(i,c.name,table.concat(t,", ")) end`
- [ ] 8. `/run for _,s in ipairs(AuctionCategories[1].subCategories) do local t={} for _,x in ipairs(s.subCategories or {}) do t[#t+1]=x.name end print(s.name,table.concat(t,", ")) end`

## Before every release: the 5-minute check

Tyler (2026-10-07): the old 15-minute quick run was too long. This is one walk through the
auction house, about 5 minutes, that touches every tab once. Everything else is covered by the
automated tests (run on every push) and by the build steps of the version, which test whatever
changed.

- [ ] 1. Log in and talk to an auctioneer: aux opens, no BugSack error.
- [ ] 2. Search `linen cloth` and buy 1 with the buy bar (Buy, then Confirm): it is bought.
- [ ] 3. Post tab: post one item at the price aux picks: it says "Posted".
- [ ] 4. Auctions tab: that item is listed with a status.
- [ ] 5. Sniper tab: Start, wait for one round, Stop.
- [ ] 6. Open a profession window: the Materials line shows under a recipe's reagents.

Agents: keep this list at six steps or fewer. Add a step only for something that broke in a
release before, and say which.

## For agents

Add the in-game checks for each change to "Current build" above (and to the build's test page, if
one exists). One thing per step. If a step needs something the tester may not have (auctions
up, a second character, a rare item), say how to set it up or leave the step out (0.6.1 build 2,
step 6: two checks in one, the second needing auctions; Tyler found it confusing). The
pre-release check stays at six steps (Tyler's limit); do not move build steps into it. Older
detailed checklists: `docs/testing-history.md`.
