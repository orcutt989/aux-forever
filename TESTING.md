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

## Unreleased build: suffix tooltip stats (FB-040, on top of 0.8.2)

`/reload` after copying the `auxForever` folder. Disable any leftover `AuxSuffixFix` companion.

- [ ] 1. Fast search for random-suffix gear. Hover a **parent** row icon: name may show the
      suffix; +stats may be missing until step 2.
- [ ] 2. Click the parent to open its auctions. Hover an auction icon: green `+N Stat` lines
      (and/or the game's own suffix stats) are visible.
- [ ] 3. Go back to the Fast list (or search again). Hover that same parent icon: the same
      +stats now show (remembered link from the opened search).
- [ ] 4. First search of the session still completes (no need to search twice).

## Current build: 0.8.2 build 8

One fix from Tyler's build 7 test (results below): with a material selected, the deal sound played
but new rows showed only after letting go. The table waited whenever the mouse was over its rows,
and the mouse rests on the row just clicked. The selected row and the rows above it no longer move,
so the table now updates while the mouse is on them; a row below still waits. Zip
`auxForever-0.8.2-build8.zip`; `/reload` is enough. Test page build id `0-8-2-build-8`.

- [ ] 1. Open the Sniper tab and click Start. Click a material deal (cloth, ore, herbs, leather)
      and leave the mouse where it is, on that row. When the deal sound plays, the new row shows up
      just below yours within a second, and your row does not move. If no sound plays within a few
      minutes, mark Skip.

Tested by Tyler 2026-11-09 (test page `0-8-2-build-8`): passes. Coarse Stone selected in row 1,
Deathweed "just now" right below it, the status "Watching first round; checking 987 possible deals".
General note: a player Tyler knows reported his Full scan "wasnt working" (FB-039).

### 0.8.2 build 7

Tested by Tyler 2026-11-09 (test page `0-8-2-build-7`): all eight steps pass. Full scan with the
Sniper running: the button is not gray, the bar showed "waiting for the auction house, 0:13 so far",
the Sniper waited ("first round") and went on by itself after the scan; the chat line (partly
hidden behind aux) reads "215090 auctions recorded in 50.5s (the ... answer, 2.0s to send the list;
reading took ...)" (FB-027). The tooltip-word search: "That was LIGHTNING fast", 36 chests. The sort
arrow sits left of "% of usual". The Materials hover shows "(73%)" and "(56%)" in color. No Shift
hint; with Shift "4s 80c (104%) for 20". Sniper: with Crippling Poison selected the status kept
"Watching round 5, ... checking 542 possible deals"; a selected gear deal (Light Bow) shows
"Holding while this item is selected, so Buy works; click it again to go on". Tyler on step 7:
"when my row is frozen I can hear sounds like new entries should be popping up but they dont show
up until I unselect the material I was holding" (fixed in build 8). Tyler kept gear holding the
rounds (option C): "keep it, or if you can think of a more elegant solution do it".

Build 6 (not tested yet) plus the Sniper no longer stopping while a deal is selected (Tyler,
2026-11-09: "very jarring"; Gemini's review H-009, answered in H-010): trade goods and gone deals
keep the rounds going, gear still pauses them, and the selected row stays in place while new deals
come in below it. Zip `auxForever-0.8.2-build7.zip`; `/reload` is enough. Test page build id
`0-8-2-build-7`. Steps 1 to 5 are build 6's.

- [ ] 1. Open the Sniper tab and click Start. The Full scan button at the top right is not gray
      (unless your last Full scan was less than 15 minutes ago: point the mouse at it to see when).
      Click it and wait without searching. At the end the chat says "Full scan complete: ...
      auctions recorded in ... (the auction house took ... to answer, ...)". Screenshot that line.
- [ ] 2. Stop the Sniper. Search tab, Fast selected, search `usable/armor/cloth/chest/intellect`.
      Rows appear while it runs, it ends in seconds, and the chests found say Intellect in their
      tooltip (an "of the Owl" one too).
- [ ] 3. In that table, click the "% of usual" column title (it was "% Hist. Value"). The gold arrow
      sits left of the title, not on top of the "%".
- [ ] 4. Open your Professions window, pick a recipe, and point the mouse at the line under its
      reagents ("Materials ..."). Each material bought at the auction house and the "sells for" line
      end with a percent in brackets, like "(67%)", in color.
- [ ] 5. Point the mouse at a stack in your bags: the Value line has no "Shift for" any more. Hold
      Shift: it shows the whole stack's price, "for 20".
- [ ] 6. Open the Sniper tab and click Start. When a material deal shows up (cloth, ore, herbs,
      leather), click it once. Next to Stop, the status keeps saying "Watching  round 12, ..." and
      the round number goes up; it does not say "Holding". If no material deal shows up within a few
      minutes, mark Skip.
- [ ] 7. Leave that row selected and wait for another deal to show up (the sound plays). The new row
      appears just below yours, and your row stays where it was. If none shows up within a few
      minutes, mark Skip.
- [ ] 8. Click a gear deal (armor or a weapon). The status says "Holding  while this item is
      selected, so Buy works; click it again to go on". Click the same row again: the status goes
      back to "Watching".

### 0.8.2 build 6

Fixes from Tyler's build 5 test (results below) and "% of usual" everywhere (Tyler, 2026-11-09,
"especially in crafting menus"). Zip `auxForever-0.8.2-build6.zip`; `/reload` is enough. Test page
build id `0-8-2-build-6`. Not tested on its own; its five steps passed as build 7's steps 1 to 5.

### 0.8.2 build 5

Tested by Tyler 2026-11-09 (test page `0-8-2-build-5`): the Full scan button stayed gray while the
Sniper ran ("I had to stop sniper for full scan to ungrey", fixed in build 6; the scan's closing
chat line was not in the screenshots). The tooltip-word search failed ("This isnt returning items
and there is a weird visual bug on % Hist Value": gear with an ending was read one by one and the
table was redrawn only every 100 items; the sort arrow sat on the "%"; both fixed in build 6). The
tooltip reads "Value: 1s 8c (83%)  seen today" and with Shift "4s 80c (104%) for 20"; the % of usual
switch turns the percent off (screenshots). Tyler: "I dont want to put shift instructions in the
tooltip" (removed in build 6). The Sniper after a round: 21 deals, some "% of market", percents in the
Search colors, "Compared to" filled (screenshot). Tyler on the Sniper stopping while a deal is
selected: "I find it very jarring that we stop the entire search when someone highlights
something" (handoff H-009 for Gemini).

Build 4 plus one consistency change (Tyler, 2026-11-09: wherever a price is compared with the usual
price, the same percent in the Search tab's colors): the Sniper's Why column shows "30% of usual" or
"70% of market" with the percent in the % Hist. Value colors (it was always green). The "usually"
line was the only other place with its own wording; it went in build 4. Zip
`auxForever-0.8.2-build5.zip`; `/reload` is enough. Test page build id `0-8-2-build-5`. Build 4's
steps; step 5 (Sniper screenshot) also shows the Why column's colors.

### 0.8.2 build 4

Build 3 plus one tooltip change (Tyler, 2026-11-09, after deep_structure asked again about
"usually"): the usual price is a percent on the Value line, "Value: 2s (67%)  seen today", instead
of a "usually 3s" line under it; the Settings switch is "% of usual". Zip
`auxForever-0.8.2-build4.zip`; `/reload` is enough. Test page build id `0-8-2-build-4`. Build 3's
six steps (below), with two changes:
- Step 3 (Shift on a stack): the Value line reads like "Value: 2s (67%)  seen today  Shift for 20".
- Step 4 (Settings): the new row under Value is called "% of usual". Click it off, point the mouse
  at an item: the percent is gone. Click it on again.

### 0.8.2 build 3

Build 2 plus Gemini's review of the Sniper logic (H-008, eight findings, all fixed with a test each,
`docs/reviews/2026-11-09-sniper-0.8.2.md`): the Sniper's check before opening an item uses the last
Full scan's market by the Sniper's own rule (the cheapest price left out), other gear versions are
read when one is opened, a price 3 sellers ask is the market, the column next to the price is
"Compared to". Zip `auxForever-0.8.2-build3.zip`; `/reload` is enough. Test page build id
`0-8-2-build-3`. The same six steps as build 2 (below); step 5 also checks the new column.

### 0.8.2 build 2 (not tested; replaced by build 3)

Fixes and small changes from player feedback (FB-025, FB-027, FB-028, FB-033, FB-035, FB-036,
FB-037). Build 1 was never tested (the game was down); build 2 adds Swiftwren's second comment: the
Sniper's list check uses today's Full scan and other versions of the same gear name, so far fewer
items are opened per round (FB-036). Zip `auxForever-0.8.2-build2.zip`; `/reload` is enough. Test
page build id `0-8-2-build-2`. The steps are the same as build 1's.

- [ ] 1. Full scan with the Sniper running. Open the Sniper tab and click Start. Then click Full
      scan at the top right (if it is grayed out, point the mouse at it: it says when it is
      available), and wait without searching. The bar under the window says "Full scan:
      waiting for the auction house, 0:05 so far..." if the answer takes more than 5 seconds. At
      the end the chat says "Full scan complete: ... auctions recorded in ... (the auction house
      took ... to answer, ... to send the list; reading took ...)". Screenshot that chat line.
      (Before, the Sniper's next round stopped the Full scan after a few seconds.)
- [ ] 2. Stop the Sniper. On the Search tab, with Fast selected (top right of the search bar),
      search `armor/mail/chest/usable/strength`. The results come in seconds, not minutes, and the
      chests in them say Strength in their tooltip.
- [ ] 3. Hover a stack in your bags, for example 20 Linen Cloth. The Value line ends with "Shift
      for 20". Hold Shift: the line shows the whole stack's price and ends with "for 20".
- [ ] 4. Click the gear at the top right (Settings). Under Tooltip lines there is a new row,
      Usually, under Value, and nothing is cut off at the bottom of the window.
- [ ] 5. Right after the Full scan of step 1, Sniper tab, Start, and let it run about 2 minutes.
      Screenshot the Sniper with its deals table and the line above it ("checking ... possible
      deals" while a round runs). Expect far fewer possible deals than before and none like
      Swiftwren's (an item listed by many at about the same price). The column after "Price each"
      is called "Compared to" (build 3).
- [ ] 6. Only if the Sniper finds a deal while you watch: when it appears (with the sound), click it
      within 15 seconds. The Buy button appears at once, without a "Checking..." message first. Do
      not buy. (A deal found longer ago is checked again first, as before.)

### 0.8.1 build 2

One fix from Tyler's build 1 test. Tyler keeps his Professions window where he dragged it; with
aux open, build 1 pulled it to the far left, behind aux's window (the fix for FB-034 moved any
window in the right-hand place). Now aux only undoes the game's own small shift and leaves a window
the player placed alone. Zip `auxForever-0.8.1-build2.zip`; `/reload` is enough. Test page build id
`0-8-1-build-2`.

- [ ] 1. Stand next to an auctioneer. Open your Professions window (it appears at the spot you
      moved it to). Right-click the auctioneer, so aux opens. The Professions window does not move
      (in build 1 it jumped to the far left, behind aux).
- [ ] 2. Keep aux open. Close the Professions window with its X, then open it again. It ends up at
      your spot (flashing at the left first and then jumping there is fine; it did that in build 1
      too).
- [ ] 3. In the Professions window, click a recipe whose item you have never searched for in aux
      (for example one you just learned). The small line under its reagents reads like
      "Materials 2s 40c   no sell price yet".

Tested by Tyler 2026-11-08 (build 2, test page `0-8-1-build-2`): steps 1 and 2 pass (the
Professions window, at his own spot, stays there when aux opens and after reopening). Step 3 could
not be done: "I dont think I have a single item that aux didnt already fullscan." The step needed
something the tester does not have (the rule under "For agents"); the "no sell price yet" case is
covered by the automated test `fb026: a made item with no price says so`. Every 0.8.1 change has
now passed in game.

Tested by Tyler 2026-11-08 (build 1, test page `0-8-1-build-1`): steps 1 and 2 pass from the
screenshots (`hillman's cloak/exact` lists Hillman's Cloak, 415 for sale; Robes of Arcana found
the same way); step 3 fails: his Professions window, at a spot he set himself, went to the far left
behind aux when the auction house opened, and on reopening it "starts on the left then teleports
to its custom position set by me" (fixed in build 2); step 4 passes; step 5 works from the
screenshot (Woolen Bag: "Materials 12s 97c  Loss 8s 22c"); step 6 passes from the same screenshot
(the hover shows "Woolen Bag sells for 5s seen today, After the 5% auction house cut 4s 75c, Loss
8s 22c"); Tyler's note "What?" meant the step's wording was unclear ("It was very unclear what you
were asking"), not the result, so the step-writing rule in `AGENTS.md` ("Tests") was added; step 7
skipped.

### 0.8.1 build 1

0.8.0.1 build 1 (below, the cloak search and the Professions window, unchanged) plus profit or
loss on the profession window's Materials line (FB-026, deep_structure; option A of the mockup,
https://claude.ai/artifact/6VxaaXKXe3f9uJEjK7Gtoy). Zip `auxForever-0.8.1-build1.zip`; `/reload`
is enough. Test page build id `0-8-1-build-1`: seven steps, 0.8.0.1 build 1's four steps (below)
first, then these three (Tyler had not started the 0.8.0.1 page).

- [ ] 1. Open your Professions window and pick a recipe whose made item aux has seen (searched or
      full scanned), for example Woolen Bag. The line under the reagents reads "Materials ...
      Profit ..." in green, or "Loss ..." in red. Screenshot it.
- [ ] 2. Hover that line. Under the total: "<item> sells for" with how old the price is, "After
      the 5% auction house cut", and Profit or Loss with the same amount as the line.
- [ ] 3. Pick a recipe whose made item aux has never seen: the line says "no sell price yet". If
      you have a recipe that makes no item (an enchant), it shows the cost only.

### 0.8.0.1 build 1

Two bug fixes from player feedback. An exact search for a cloak found nothing (FB-024, GregoryWW:
`hillman's cloak/exact`): aux asked for Cloth armor, and Forever keeps cloaks under Miscellaneous,
Cloak (Blizzard's code). With aux open, the Professions window moved a little to the right
(FB-034, Chawitsch): the game places side windows next to its own auction house window, which aux
keeps open but shrunk and invisible; aux now puts the side window back. Zip
`auxForever-0.8.0.1-build1.zip`; `/reload` is enough. Test page build id `0-8-0-1-build-1`.

- [ ] 1. Search for a cloak that is for sale with `/exact` after its name (for example
      `hillman's cloak/exact`; search `cloak` first to find one). It lists that cloak.
- [ ] 2. The same with a necklace, ring or robe that is for sale: it is found too.
- [ ] 3. Away from the auction house, open your Professions window and note where it sits. Open
      the auction house (aux opens): the Professions window stays where it was. Close it and open
      it again while aux is open: same place. Before, it moved a little to the right.
- [ ] 4. Click Blizzard UI, then go back to aux, then close the auction house. No errors, and the
      Professions window (if open) is still usable where it is.

### 0.8 build 14

Two fixes from Tyler's build 13 test. Crates hovered in aux's results showed no "Cheapest way to
fill it" lines (Journeyman Herbs, Artisan Curiosities). Likely cause (not confirmed in game): the
game loads a crate's list, the text of its use spell, after the item, and aux read the tooltip
before that and kept "not a crate" for the session; it now waits for the list (Blizzard's code:
`C_Item.GetItemSpell`, `C_Spell.IsSpellDataCached`). Sorting by For sale put "Merc Sword of Stamina
18 (1)" below a 17: an item's row sorted by its first price only; now by all it has for sale. Zip
`auxForever-0.8-build14.zip`; `/reload` is enough. Test page build id `0-8-build-14`.

- [ ] 1. After `/reload`, open aux and search `waylaid crate`. Hover three kinds of crate in the
      results: each shows "Cheapest way to fill it" with its bundles (the first hover may not; a
      second hover must). Screenshot one.
- [ ] 2. Hover the Waylaid Crate in your bags: the same lines show.
- [ ] 3. Search `merc sword` (Full), click For sale until the arrow points down: the numbers in
      that column only go down from the top (an item with yours, like "18 (1)", sits by its 18).

Tested by Tyler 2026-11-08 (test page `0-8-build-14`, screenshots, no marks; judged from the
screenshots): all three pass. In aux's results Apprentice Ore (20 Copper Ore 25s 80c, cheapest;
20 Tin Ore 32s 20c), Earthly Expert Herbs (four bundles, 10 Khadgar's Whisker 35s cheapest) and
Artisan Textiles (20 Thick Leather 96s 60c cheapest) show "Cheapest way to fill it"; the
Apprentice Ore crate in the bags shows the same; For sale sorted down puts "Merc Sword of Stamina
20 (1)" among the 20s.

### 0.8 build 13

The release candidate for 0.8, after Gemini's last review (H-006,
`docs/reviews/2026-11-08-release-0.8.md`): seven fixes, each with a test. Gear read on the Post tab
and stopped halfway (by a Full scan) no longer unlocks Post with a price from part of the listings;
a search stopped halfway through an item's versions keeps the day's price; sorting merged rows by
For sale and Seller; a crate's bundles are read only from a crate's own list; old shared gear
prices are removed; two gamepad popup fixes; and the help no longer states as fact that the newest
listing at a price sells first (not confirmed on Forever). Zip `auxForever-0.8-build13.zip`;
`/reload` is enough. Test page build id `0-8-build-13`.

- [ ] 1. Hover two kinds of Waylaid Crate other than Textiles and Fabrics (Herbs, Ore, Parts...):
      each still shows "Cheapest way to fill it" with its bundles. Screenshot one.
- [ ] 2. Search `merc sword` (Full). Click the For sale header (twice if needed): the rows with the
      most for sale come first. Click the Seller header: the "N sellers" rows sit together, not
      among the single names.
- [ ] 3. Hover a gear item with an ending in your bags (a Merc Sword or Medicine Staff "of ..."):
      Value shows as before.
- [ ] 4. Post tab: hover the "?" next to the goblin. It says the newest listing selling first is
      "Not yet confirmed on Forever". Type `/aux undercut`: the same.
- [ ] 5. Only if your Full scan is ready: Post tab, pick a gear item with an ending and click Full
      scan right away, while it says "Reading the listings...". Post stays faded and says
      "Reading stopped. Press Refresh, or type a price." Click Refresh: it reads again.

Tested by Tyler 2026-11-08 (test page `0-8-build-13`, screenshots, no marks; judged from the
screenshots): steps 2 (the Seller sort), 3 and 4 pass; step 2's For sale sort put "18 (1)" below a
17 (fixed in build 14); step 1 fails: Journeyman Herbs and Artisan Curiosities, hovered in aux's
results, showed their list but no "Cheapest way to fill it" (build 14); step 5 skipped ("I cant
move my hand that fast"; covered by the test "H-006 2").

### 0.8 build 12

The release candidate for 0.8. On top of build 11 (the empty search bar): after Cancel on a trade
good's price, the Buy button kept the Confirm green (Tyler's screenshot, Wool Cloth). It is
repainted whenever its look changes now. Zip `auxForever-0.8-build12.zip`; `/reload` is enough.
Test page build id `0-8-build-12`.

- [ ] 1. Search a cheap trade good (`wool cloth`), click a row, Buy: the button turns to Confirm in
      green. Click Cancel: the button says Buy again in its normal color, not green.
- [ ] 2. Search tab: clear the search bar (right-click it), click somewhere else: it stays empty.

Tested by Tyler 2026-11-08 (test page `0-8-build-12`): step 1 passes; step 2 passes from the
screenshot (an empty bar, the Wool Cloth buy bar's button back to its normal look).

### 0.8 build 11

The release candidate for 0.8. One fix on top of build 10: clearing the search bar and clicking
elsewhere showed "<>" (Tyler: "This appears when you clear the search bar and click somewhere
else"); aux writes an empty search that way, and the bar now stays empty. Zip
`auxForever-0.8-build11.zip`; `/reload` is enough. Test page build id `0-8-build-11`.

- [ ] 1. Search tab: clear the search bar (right-click it), then click somewhere else. The bar
      stays empty.

### 0.8 build 10

Gemini's review of one row per price (H-004, `docs/reviews/2026-11-08-one-row-per-price.md`):
all seven findings and the build 8 note taken, each with a test. The Bids and Sniper tabs list
each auction apart again; an auction with no buyout keeps its own row; the row keeps the auction
with the lowest starting bid; the buy bar and the result count match the merged rows; each seller
is counted once ("65 sellers" in build 9). Zip `auxForever-0.8-build10.zip`; `/reload` is enough.
Test page build id `0-8-build-10`.

- [ ] 1. Search `merc sword` (Full): the seller counts look believable (not 65 sellers for 69
      swords unless that many people really sell it), and the summary above the table counts the
      rows shown. Screenshot.
- [ ] 2. Click a merged row: the bar below says as many "for sale at this price" as the row shows.
- [ ] 3. Sniper: start it for a minute; each deal is its own row.

Tested by Tyler 2026-11-08 (test page `0-8-build-10`, screenshots, no marks; judged from the
screenshots): all three pass. `merc sword` (Full): "23 items, 383 for sale", one row per ending, a
seller count per row; the 9s Merc Sword of Intellect row's buy bar said "1 for sale at this price,
The last one at this price"; the Sniper showed 13 deals and 1 gone, one row each.

### 0.8 build 9

Tested by Tyler 2026-11-08 (test page `0-8-build-9`, screenshots): one row per price works in
search results ("Merc Sword of Healing 69, 65 sellers"; the seller count was wrong, review H-004
finding 6), buying from a merged row passes, the Post tab shows 66 at 11s on one row, the Auctions
tab still shows each auction ("Tied with 66 others").


One row per price (Tyler, build 7: "Why are we separating these lines?"; build 8: "go full auto").
Search results, the Sniper and the Post tab merge gear auctions at one buyout price into one row,
whatever the seller and time left; the seller column says "4 sellers". Zip
`auxForever-0.8-build9.zip`; `/reload` is enough. Test page build id `0-8-build-9`.

- [ ] 1. Search `merc sword of healing` (Full): one row per price; the 11s row adds up all the
      sellers at 11s and says how many sellers. Screenshot.
- [ ] 2. Buy one from the cheapest row (Buy, then Confirm): it costs the price shown, and the row's
      count goes down by one (or the next seller's auctions take its place).
- [ ] 3. Post tab, the same sword: one row per price there too (yours on a row of their own).
- [ ] 4. Auctions tab, if you have auctions up: each of your auctions is still its own row.

### 0.8 build 8

Tested by Tyler 2026-11-08 (test page `0-8-build-8`): step 1 passes (gear loads in a few seconds),
step 2 skipped.


From Tyler's test of build 7: the Post tab took a long time to load a Merc Sword. It searched every
ending of the item (about 25 searches); it now searches only the versions of its own ending and
takes the other endings' lowest prices from the item list. Zip `auxForever-0.8-build8.zip`;
`/reload` is enough. Test page build id `0-8-build-8`.

- [ ] 1. Post tab, a Merc Sword: the bar at the bottom turns gold in a few seconds (it took much
      longer in build 7), and the list matches a Search tab search of that full name.
- [ ] 2. Gear whose ending nobody sells: a price is still suggested ("None of this name for sale:
      the cheapest other ending").

### 0.8 build 7

Tested by Tyler 2026-11-08 on the released game (test page `0-8-build-7`, screenshots): step 1
passes (aux loads, BugSack "You have no bugs, yay!", a Full scan recorded 161,999 auctions; the
`GetBuildInfo()` line was not captured), step 2 passes (Value kept after a login). Step 3: the Post
tab's Merc Sword of Healing list matched the search (11s: 2, 5, 39 and 10 for sale; 12s, 18s,
30s), but loading took long (fixed in build 8). Tyler asked why one price shows as several rows
(four rows at 11s): open design question, `docs/status.md`. Steps 4 and 5 not done (the game
changed since the beta, so Tyler's items differ). The search bar showed `<>` once, cause unknown.


The first build on the released game. Fixes from Gemini's review of gear versions (H-002, all six
findings, `docs/reviews/2026-10-26-gear-versions.md`) on top of build 6, which was never tested.
Zip `auxForever-0.8-build7.zip`. Put the `auxForever` folder in the release game's
`Interface\AddOns` folder (not `_classic_beta_` any more, most likely; wherever your other addons
are) and **restart the game fully**. Test page build id `0-8-build-7`.

- [ ] 1. Release check: at the character screen, AddOns: is auxForever listed and ticked, or does
      it say "Out of date"? Then in game type `/run print(GetBuildInfo())` and screenshot the
      chat line (it gives the game version and the number the addon must declare).
- [ ] 2. Release check: hover an item you have searched before and note its Value. Log out, log
      back in, hover it again: is the Value still there? (Saved prices survive a login.)
- [ ] 3. Search `merc sword` (Full), then Post tab, Merc Sword of Healing: the Post tab lists the
      same Healing swords as the search (same counts and prices). Screenshot of both.
- [ ] 4. Medicine Staff of the Whale (or any gear nobody sells): a price is filled in and the line
      under it says "None of this name for sale: the cheapest other ending".
- [ ] 5. Still on the Post tab with a Merc Sword picked: right-click a price row. The Search tab
      shows only that ending (before: nothing at all).

### 0.8 build 6

Not tested in game (development paused 2026-10-26 until the game's release).


Fixes from Tyler's test of build 5 ("the numbers dont add up"; "we need to give them a price to
post at anyway"). The Post tab now reads every version of gear before it picks a price: one name
can sit under several versions, and stopping at the first one with a listing missed the rest. And
when nobody sells that name, it suggests the cheapest other ending of the item, with the note "None
of this name for sale: the cheapest other ending" (a suggestion; any price can be typed). Zip
`auxForever-0.8-build6.zip`; `/reload` is enough. Test page build id `0-8-build-6`. Reading
gear now takes a few seconds longer (one request per version of the item).

- [ ] 1. Search `merc sword` (Full) and note how many of each ending are for sale and at what
      price. Then Post tab, Merc Sword of Healing: once the bar turns gold, the table shows the
      same Healing listings (same counts and prices) and "Same as the lowest listing". Screenshot of
      both.
- [ ] 2. Merc Sword of Agility: the same check (if none are listed now, see step 3).
- [ ] 3. Medicine Staff of the Whale (nobody sells it): a price is filled in, the cheapest other
      Medicine Staff, and the line under it says "None of this name for sale: the cheapest other
      ending". Screenshot.

### 0.8 build 5

Fixes from Tyler's test of build 4: the Post tab found no listings for gear with an ending
(Merc Sword of Agility: 4 listed at 16s, the Post tab showed none and took the usual price). Two
causes, each with a test that fails without its fix: the listings were filed under the old item
key while the Post tab reads them by the price key; and the listings counted as read after the
first version of the item, before the item's own name came, so the price was picked from the usual
one. Also new: "None for sale. Type a price to post." when nothing of that name is listed (Medicine
Staff of the Whale). Zip `auxForever-0.8-build5.zip`; `/reload` is enough. Test page build id
`0-8-build-5`.

- [ ] 1. Post tab, Merc Sword of Agility: once the bar turns gold, the table lists the swords of
      Agility for sale and the price line says "Same as the lowest listing". Screenshot.
- [ ] 2. Merc Sword of Healing: the same, with the Healing listings.
- [ ] 3. Medicine Staff of the Whale: once the bar turns gold, it says "None for sale. Type a price
      to post." (if nobody sells a Whale staff). Screenshot.

Tested by Tyler 2026-10-21 (test page `0-8-build-5`, screenshots): Agility and Healing showed
listings of their own name and "Same as the lowest listing", but the counts did not match a search
a minute later (Healing 1 + 3 in the Post tab, 6 in the search): the Post tab stopped after the
first version with a listing (fixed in build 6; listings also changed in that minute, Agility was
gone from the later search). The Whale said "None for sale"; Tyler: "we need to give them a price
to post at anyway" (build 6 suggests the cheapest other ending).

### 0.8 build 4

Fix from Tyler's test of build 3: the Post tab's bag list named gear without its ending, so two
Merc Swords with different endings were two rows that looked alike ("I think we failed this").
Rows, the item heading and "Posted 1 × ..." now show the full name. Zip
`auxForever-0.8-build4.zip`; `/reload` is enough. Test page build id `0-8-build-4`.

- [ ] 1. Post tab: gear in the bag list shows its ending ("[Merc Sword of the Eagle]"); two of one
      kind with different endings show two different names. Screenshot.
- [ ] 2. Pick the Medicine Staff: the heading shows its full name. Its listings are those of that
      exact name; if nobody sells that ending right now, the list is empty and Post says "Type a
      price to post". Compare with a Search tab search of the full name. Screenshot of both.
- [ ] 3. Only if you have gear with an ending up for sale: Auctions tab, its status (Tied, Undercut,
      Lowest) compares with listings of the same name. Skip otherwise.

Tested by Tyler 2026-10-21 (test page `0-8-build-4`, screenshots): step 1 passes (Medicine Staff
of the Whale, Merc Sword of Agility, Merc Sword of Healing). Step 2: the Whale staff showed no
listings, right (none listed in the search), but "Type a price to post" read as broken; Merc Sword
of Agility showed none though 4 were listed at 16s, a bug (fixed in build 5). Step 3 not done.

### 0.8 build 3

Tested by Tyler 2026-10-20 (test page `0-8-build-3`, screenshots, no marks): step 1 passes
(Medicine Staff of Arcane Protection Value 1g 15s, of the Wolf 1g 50s; the % column per ending);
step 2 failed as seen (two "[Merc Sword]" rows, split but named alike: fixed in build 4); step 3:
the Medicine Staff in the bags showed no listings, which is right only if nobody sold its ending
(not known, its name was hidden; build 4 step 2); step 4 unclear (Tyler's note "???", no gear of
his up); step 5 passes (Peacebloom posted).


Gear versions, the last 0.8 item: gear with a random ending is priced per ending (Tyler, 2026-10-20:
two Medicine Staffs of Arcane Protection have the same stats, so gear is grouped by name). Zip
`auxForever-0.8-build3.zip`. `/reload` is enough (no new files since build 2). Test page build id
`0-8-build-3`. Use the New theme.
Have two pieces of gear of one kind with different endings in your bags if you can (any "of the
..." items).

- [ ] 1. Search `medicine staff` (or any gear with endings), Full. Hover two rows with different
      endings. Value differs between endings (or says "?" for an ending aux has not priced yet; it
      learns it from this search, so hover again after the search). Screenshot.
- [ ] 2. Post tab: gear with two different endings shows as two items in the bag list. Skip if you
      have none.
- [ ] 3. Post tab, a piece of gear with an ending: the price matches the lowest listing of the same
      name (check it in a Search tab search of that name), not a cheaper ending. Screenshot. No need
      to post.
- [ ] 4. Auctions tab, if you have gear with an ending up: its status compares with the same name
      ("Tied with ...", "Undercut by ...", or "Lowest"). Skip if you have none up.
- [ ] 5. A trade good: post 1 as usual ("Posted 1"); Value in its tooltip as before.

### 0.8 build 2

Waylaid Crates (FB-020, Harro22; mockup options A and C, chosen by Tyler on 2026-10-20), on top of
build 1's gamepad support. Zip `auxForever-0.8-build2.zip`. **Full game restart** needed (new
files `gamepad.lua` and `tabs/search/crate.lua`). Test page build id `0-8-build-2`. Use the New
theme. Have a Waylaid Crate in your bags, and ideally a few of one of its bundle items.

Tested by Tyler 2026-10-20 (test page `0-8-build-2`, screenshots, no marks; judged from the
screenshots): steps 1, 3, 4, 5 and 6 pass, step 2 skipped. Journeyman Ore's tooltip listed 10
Silver Ore 1g 50s (gold, cheapest) and 20 Iron Ore 2g 19s 60c; Alt-click searched `[Silver
Ore];[Iron Ore]` and the bottom bar said "Crate  Journeyman Ore  cheapest fill  10 Silver Ore  1g
50s  next  20 Iron Ore  2g 18s 31c"; Recent listed "Crate  Journeyman Ore  (2 bundles)";
Shift-click searched the crate; a Linen Cloth posted ("Posted 1 × Linen Cloth").

- [ ] 1. Hover the crate in your bags. Under aux's Value line: "Cheapest way to fill it", then each
      bundle with a price (or "no price yet" for items aux has not seen), the cheapest in gold.
      Screenshot.
- [ ] 2. If you carry some of a bundle's item: that row says "(N in bags)" and is priced only for
      the rest. Skip if you carry none.
- [ ] 3. Open aux at the auction house, Alt-click the crate in your bags. The Search tab searches
      every bundle's item, and the bottom bar says "Crate  <name>  cheapest fill  ..." and "next
      ...". Screenshot.
- [ ] 4. Recent searches (the clock button, or Saved Searches): the search is listed as "Crate
      <name>  (N bundles)". Click it: it runs again with the same bottom line.
- [ ] 5. Shift-click the crate: aux searches the crate itself, as before.
- [ ] 6. With mouse and keyboard, post 1 of a cheap trade good: "Posted 1" (nothing else changed).

### 0.8 build 1

Gamepad support, contributed by nokkty (GitHub issue #27, `docs/gamepad.md`), brought onto
0.7.1.1. Zip `auxForever-0.8-build1.zip`. **Full game restart** needed (new file `gamepad.lua`).
Test page build id `0-8-build-1`. Use the New theme. nokkty tested all of it with a controller on
0.7 (section "0.7 build 1" below); these steps check that it still works on top of 0.7.1.1 and,
most of all, that nothing changed for mouse and keyboard players.

With mouse and keyboard (gamepad mode off):

- [ ] 1. Open aux: no strip under the window, everything as before. Post 1 of a cheap trade good:
      "Posted 1".
- [ ] 2. Search tab, a favorite search (star one first if you have none): right-click it. The
      game's usual popup asks "Are you sure you want to remove this search from your favorites?";
      Yes removes it.

With a controller: Tyler will not test these (2026-10-20); they are for players with a
controller who want to help. Options, Controls, turn on gamepad mode.

- [ ] 3. Talk to an auctioneer: aux opens with a gold frame on a control and a strip under the
      window showing the controller's buttons. Move with the D-pad; RB and LB switch tabs.
- [ ] 4. Search `linen cloth` (typing it on the keyboard is fine), then with the pad: move onto a
      result, A, then Y (Buy), then Y (Confirm): "Bought 1 × Linen Cloth".
- [ ] 5. Post tab: pick a trade good with A, wait until the bar at the bottom turns gold, press Y:
      "Posted". Pressing Y before the bar turns gold does nothing.
- [ ] 6. Press B until aux closes: no freeze, no popup. Log out: no BugSack error.

### 0.7 build 1 (gamepad, on nokkty's fork)

Gamepad support (`docs/gamepad.md`). Zip `auxForever-0.7-build1.zip`. **Full game restart**
needed (new file `gamepad.lua`). Test page build id `0-7-build-1`. Tested in game on 2026-10-13 by
the contributor (New theme): all steps below pass, taint log clean (nothing
blocked), no BugSack error. Not tested yet: the Classic theme, a PlayStation controller.

Set up: Forever's gamepad mode on (Options, Controls, gamepad), BugSack enabled. Steps, in the New
theme, using only the controller:

- [x] 1. Talk to an auctioneer: aux opens with a gold frame on a control of the Search tab and a
      strip under the window showing A, B, X and LB RB with your controller's icons.
- [x] 2. Move around the Search tab with the D-pad: the gold frame goes to the nearest control in
      each direction, and the strip's words change (a button: Select; a text box: Type).
- [x] 3. Gold frame on Rarity, A, down twice, A: Rarity changes to the option picked.
- [x] 4. Run a search, move onto a cheap result, A, then Y (Buy), then Y (Confirm): it is bought.
- [x] 5. Down past the last result shown: the list scrolls.
- [x] 6. RB through the tabs: each opens at once; after Bids the frame goes to Settings, Full scan
      and Blizzard UI. LB goes back.
- [x] 7. A on Settings: the frame stays inside the Settings popup; B closes it and aux stays open.
- [x] 8. Post tab: pick an item with A; reach -, + and Max with the D-pad and press them; Y posts.
- [x] 9. Post tab: X on an item in the bag list searches it on the Search tab.
- [x] 10. Sniper: Y starts it. A on a deal: once checked, the frame moves to Buy; A, then A
      (Confirm): it is bought. B on the buy bar goes back to the deal. Y stops it. (To get a deal
      soon, set "% of usual" to 100 and "profit at least" to 1c, then set them back.)
- [x] 11. Auctions tab: select an auction of yours, Y: it is cancelled (costs its deposit).
- [x] 12. B until aux closes: no popup, no freeze. Log out: no BugSack error.

Not checked by a test step: the post confirmation popup in gamepad mode (the server's warning did
not come up during testing; covered by the automated tests), Bids with Y (no bid was up).

### 0.7.1.1 build 2

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
