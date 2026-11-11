# Changelog

What changed in each version, newest first. The text under each version is ready to paste into the
CurseForge file's changelog box.

A change that comes from a player's feedback credits them by in-game name at the end of its line:
"(suggested by Darkhorse)" or "(reported by Darkhorse)". Who to credit is in `docs/feedback.md`.

## Unreleased

### Search / tooltips

- Disenchant expected value uses each reagent's **latest** AH price (usual only as fallback). A green
  weapon tip could show Disenchant: ~46s when Lesser Astral Essence's usual was still an old 40s day
  while today was 8s; the line now tracks today's mats like Value: does.
- of-the-X green +stats no longer leak onto the next tip (cloth, food, reagents, …). Suffix inject
  only uses `last_hover` / cache for the same item id; OnUpdate retry aborts when the tip switches;
  weapon `DAMAGE_PER_SECOND` is not painted as a green +stat. Local scanner:
  `tests/test-suffix-leak.ps1` exports every Forever item-cache id and fails on any victim.

- White/gray items no longer show Disenchant %; green gear still does. Forever's tip post-call often
  has a bare `GetItem()` link and a colored `data.hyperlink` (`|cnlQ1:` / `|cnIQ2:`); aux prefers the
  colored hyperlink, then tip quality / title color / `GetItemQualityByID`, then GetItemInfo.quality
  as last resort. A prior hover's `last_link` no longer overrides this tip (that flipped white/green
  DE in game while local tests stayed green).   Same-item auction links that still carry bonus IDs win
  over a stripped tip hyperlink so "of the X" +stats stay on AH tips. Fast parent rows
  (`SetItemKey`) note/cached suffix stats before the tip builds, and `link_for_item_key` may
  synthesize a bonus link from `itemSuffix` when no auction link was remembered yet. Stat reads
  prefer `C_Item.GetItemStats(link)` (Forever's global `GetItemStats` is often empty and used to
  mask it). Covered by `basics: of-the-X prefers C_Item.GetItemStats over empty GetItemStats`.
  Loop: `tests/test-de.ps1` (`-Deploy`, `-Watch`).
- Tooltip smoke checks: `lua5.1 ../tests/load_test.lua smoke` and in-game `/aux smoke` (hover an
  item first) cover disenchant / value / vendor lines so suffix work cannot wipe them unnoticed.
- Disenchant chance and value show again after suffix inject: Forever's late `Show()` dropped those
  AddLines, and internal `M.fn()` calls never ran (the module proxy has no `__index`). (reported
  while testing FB-023)
- Random-suffix gear ("of the Bear", "of Strength", ...) again shows its rolled +stats on auction
  icon tooltips. Forever's Fast parent rows use `SetItemKey`, which often drops those bonuses;
  opened auctions already had a full `itemLink`. aux now fills the missing green +stat lines from
  `C_Item.GetItemStats`, and remembers a working link per item version so the Fast parent can show
  the same stats after you open that item (reported by Eacail).

## 0.8.2 (2026-11-09)

### Sniper

- Deals are checked against today's market. The Sniper compared prices only with an item's usual
  price, an average of past days, which can lag far behind when prices change fast: an item listed
  by hundreds at one price showed as "4% of usual", and a "deal" bought there could only be relisted
  at a loss. The Sniper now also looks at what the item's other listings ask (it reads them anyway
  before calling a deal, so this costs nothing). When that is lower than the usual
  price, the deal is judged against it and the Why column says "% of market". A single cheap
  auction on its own is still judged against the usual price (reported by Swiftwren).
- The Sniper opens far fewer items per round. Before opening an item it now also compares with the
  market from your last Full scan (if it was in the last 2 hours), worked out the same way with the
  cheapest price left out, so a normal price is not opened at all (Swiftwren saw 1,792 possible
  deals in one round, each one a request). A snipe that was already up during the Full scan is
  still found.
- Gear listed under several versions (same name, same stats): when one version looks like a deal,
  the Sniper reads the others too, and their listings count. An Invoker's Cord at 12s next to 78
  at 13s is not a deal, whether the 78 are the same version or another.
- A price that 3 or more sellers ask counts as the market, and fewer than 3 units listed above the
  cheapest price do not.
- The column next to the price is now "Compared to": the price the deal was compared with (the
  usual price, today's market or the vendor price), so the price, the percent and the profit add
  up.
- The Why column's percent ("30% of usual") is in the same colors as the Search tab's % of usual
  column and the tooltip's percent, so one color means the same thing everywhere.
- Clicking a deal found in the last 15 seconds shows the Buy button at once, without reading the
  item again first. Older deals are still read again, and so is gear when aux has searched another
  item since (buying gear needs its own search to be the latest). Buying still never spends more than the
  price shown (reported by user_ayzkr6rhvrlna3ya).
- Selecting a trade good or a deal that is gone no longer stops the Sniper: it keeps watching while
  you decide. Selecting gear still pauses it until you buy it or click it again, because buying
  gear needs its own search to be the latest one.
- While a deal is selected, the table no longer moves it: your row and the rows above it stay where
  they are, new deals appear just below it, and a deal above it that sells turns gray where it is.
  The table also updates while the mouse rests on your selected row or on the buy bar (it waited
  until the mouse left the whole table, so new deals stayed hidden while the sound played).
- A selected trade good that sells out meanwhile says "Gone: sold or relisted" in the buy bar
  right away, and Ignore item no longer selects the next deal by itself.

### Full scan

- The Full scan waits up to 10 minutes for the auction house to answer, instead of giving up after
  2: a player saw the answer take more than 5 minutes since launch. The bar under the window shows
  how long it has waited so far, and the chat line at the end says how long the auction house took to answer
  and to send the list (reported by deep_structure and user_ayzkr6rhvrlna3ya).
- The Sniper's rounds and the Auctions tab's price check no longer stop a Full scan that is
  waiting for the auction house; they wait until it is done. The Full scan button can be clicked
  while the Sniper runs (it was gray). A search you start yourself still
  stops it, and the chat now says so. Before, the scan ended without a word and the next one was
  15 minutes away.
- When the auction house never answers, the chat says nothing was recorded, instead of "full scan
  complete: 0 auctions recorded".

### Search

- Searching with a word from item tooltips, such as `armor/mail/chest/usable/strength`, is fast
  again. aux read every auction of every item to check the word, which took minutes; it now checks
  each item's own tooltip in the item list, gear with a random ending ("of the Bear") included, the
  way Blizzard's own list shows it, with no request per item. Results show while the search runs
  (suggested by RushJet1).
- The "% Hist. Value" columns of the Search and Post tabs are now called "% of usual", as
  everywhere else, and the sort arrow no longer sits on top of the title.

### Tooltips

- The usual price is now a percent on the Value line instead of a "usually" line under it:
  "Value: 2s (67%)  seen today" means the latest price is 67% of the usual one, in the same colors
  as the Search tab's % of usual column. It has its own switch: Settings, Tooltip lines, "% of
  usual", or `/aux tooltip percent` (suggested by deep_structure).
- The same "(67%)" in the profession window: pointing at the Materials line shows each material's
  price and the made item's price with its share of the usual price.

## 0.8.1 (2026-11-09)

### Professions window

- The Materials line under a recipe's reagents now says whether the craft makes a profit or a
  loss: "Materials 13s 84c   Profit 7s 6c" in green, or "Loss" in red. The made item's price is
  its latest price (its Value), minus the 5% auction house cut, so it works anywhere in the world.
  Hover the line for the selling price, the cut and the sum. "Profit at most" means a material has
  no price yet; "no sell price yet" means aux has not seen the made item at the auction house. A
  recipe that makes no item (an enchant) shows its cost only, as before (suggested by
  deep_structure).

### Search

- An exact search for a cloak finds it. `hillman's cloak/exact` found nothing while `hillman's`
  found many: aux asked the auction house for Cloth armor, but Forever keeps cloaks under
  Miscellaneous, Cloak. Exact searches for gear now ask for the slot the item really sits in, so
  necklaces, robes and other armor are also asked for more narrowly (reported by GregoryWW).

### Window

- Opening aux no longer moves Blizzard's Professions window (or another side window) a little to
  the right. The game places side windows next to its own auction house window, which aux keeps
  open but invisible; aux now undoes that small shift. A window you placed yourself with a window
  addon is left where you put it (reported by Chawitsch).

## 0.8 (2026-11-08)

### Gamepad

- auxForever can be used with a controller in Forever's gamepad mode. While aux is open, the
  D-pad moves a gold frame from control to control (and scrolls a list past its last row), A
  presses what has the frame, B closes what is open and then aux, X right-clicks, and LB and RB
  switch tabs. With mouse and keyboard nothing changes (contributed by nokkty on GitHub).
- Y does the open tab's main action: Buy and then Confirm on Search, Start or Stop on Sniper, Post
  on Post, Cancel on Auctions, Buyout on Bids.
- Sniper: A on a deal moves the frame to the Buy button once the deal is checked; A buys, A again
  confirms, B goes back to the deal. Y only starts and stops the Sniper, so it never spends money.
- Dropdowns (Category, Rarity, ...) open with A; up and down walk the options and A picks one.
- A strip under the window shows the buttons with your controller's own icons and what each one
  does right now; Y shows only while its button can be pressed.
- aux's popups (the post confirmation, the search notices, removing or renaming a favorite) open
  inside aux in gamepad mode, where the pad can reach them, with the focus on Cancel. Renaming a
  favorite starts in the name box, so B stops typing instead of closing the popup, and a popup
  over an open menu (Settings, quick searches) keeps the pad inside the popup.
- The Blizzard UI button hands the pad to Blizzard's window while it is shown.

### Waylaid Crates

- Hover a Waylaid Crate, in your bags or in aux's results: its tooltip lists every bundle that fills
  it with what that bundle costs, the cheapest in gold. Items already in your bags are counted
  ("(12 in bags)"), and a bundle you already hold says "in your bags". Prices are the latest aux
  has seen, or a vendor's when a vendor sells the item for less. aux reads the bundles from the
  crate itself, so new crates work without an update (requested by Harro22). Only a crate's own
  list counts: a line such as "-5 Spirit" on gear is not read as a bundle. A crate hovered before
  the game has loaded its list (often in aux's results) is read again on the next hover, instead of
  showing no costs until the next login.
- Alt-click a crate in your bags while aux is open: one search for every bundle's item, at today's
  prices, and the bottom bar names the cheapest way to fill it and the next cheapest. It takes the
  cheapest listings first, as many as the bundle needs, and skips your own auctions. The search
  stays in Recent searches as "Crate  Journeyman Textiles  (3 bundles)". Shift-click and
  right-click on a crate still search the crate itself.

### One row per price

- Search results and the Post tab show one row per price. The auction house hands
  listings over per seller and time left, so one price could fill several rows (four rows of Merc
  Swords of Healing at 11s, 56 for sale in all). Now it is one row, "For sale" adds them up, and the
  seller column says how many sellers there are. Buying from the row buys one real auction at the
  price shown; when it is gone the next one moves up. Your own auctions stay on a row of their
  own. The Auctions, Bids and Sniper tabs still show each auction separately, and an auction with
  no buyout keeps its own row. The buy bar and the result count match the merged rows. Sorting
  by For sale counts the whole row and each item by all it has for sale, sorting by Seller puts "4 sellers" with the other rows of
  several sellers, and after you buy from a row it stays selected with its next auction, even when
  the sort moves it.

### Fixes

- Post tab and `/aux undercut`: the help no longer states as fact that the newest listing at a
  price sells first. That is said of the modern auction house but not yet confirmed on Forever.
- Clearing the search bar and clicking elsewhere no longer leaves "<>" in it.
- Buying a trade good: after Cancel (or when aux cancels a price that went up), the Buy button goes
  back to its own color. It stayed Confirm green, as if a price were still waiting to be confirmed.

### Gear with random endings

- Gear with a random ending ("Medicine Staff of the Wolf") now has its own price per ending. Before,
  every ending of an item shared one price: the Bandit, Wolf and Arcane Protection staffs all showed
  the same Value, even though their stats differ. Tooltips, the % column, the Sniper and price
  filters now use the price of that ending.
- Post tab: each ending is its own item in the bag list, named with its ending ("Merc Sword of the
  Eagle"), and it is priced against listings of the same name only, as in Blizzard's Sell window.
  aux reads every version of the item first, since one name can be listed under several. When
  nobody sells that name, it suggests the cheapest other ending of the item, and says so ("None of
  this name for sale: the cheapest other ending"); with nothing of the item for sale at all it says
  "None for sale. Type a price to post." Before, a Merc Sword of the Eagle could be priced at
  what a Merc Sword of Strength was listed for.
- Search tables keep each ending apart: two staffs with different endings at the same price are
  two rows, not one row that hid the second. `medicine staff of the wolf/exact` finds that ending
  only (`medicine staff/exact` still finds every ending), and so does a right-click on a Post tab
  price. `/aux price` takes a typed name with its ending.
- When one name is listed under several versions, aux's price for the day now counts every version,
  not only the last one it read. A search stopped halfway through an item's versions keeps the
  day's price it had, instead of replacing it with part of the listings.
- Post tab: when reading a gear item's listings is stopped before the end (for example by a Full
  scan), Post stays faded and says "Reading stopped. Press Refresh, or type a price." Before, it
  picked a price from part of the listings and let you post at it.
- Post tab: gear with an ending loads much faster. aux searches only the versions of its own name
  and takes the other endings' lowest prices from the item list, instead of searching every ending
  (a Merc Sword took about 25 searches).
- Auctions tab: your gear is checked against every listing of its name. The auction house files
  one name under several versions with the same stats, and checking only your exact version said
  "Only one listed" while others of the same name were for sale.
- Prices aux saw for gear before this update were kept under one price per item and are no longer
  used for gear; each ending learns its own price again from your next searches or Full scan. The
  old shared price is removed the first time aux prices one of the item's endings, so an addon that
  asks aux for a price by item ID no longer gets it.
  Post settings saved for such gear (a hidden item, a duration) start fresh once.

A **full game restart** is needed to update (new files).
## 0.7.1.1 (2026-10-19)

### Post tab

- You can post a trade good at any price you type, below the lowest listing too. Typing a price
  under the automatic one (for example 5c with the lowest at 7c) faded the Post button with "The
  starting bid is above the buyout", about a starting bid that trade goods do not have, so only
  Undercut's one copper below could be posted (reported by sarrathsilentstrider).
- Gear can be posted with only a buyout, as in Blizzard's window: leave the starting bid empty.
  Before, Post asked for a price even with a buyout typed.
- A price you type while the listings are still loading is kept. Before, the automatic price
  replaced it the moment the listings arrived.
- Post waits until the item's listings are in ("Reading the listings..."), unless you typed a
  price. Before, a quick click (for example right after aux picked the next item for you) posted
  at the price from your last visit, which could be days old.
- A bag change that has nothing to do with your post (loot, a quest item) no longer ends the post
  early. Before, the tab said "Not posted" and let you click Post again while the first post was
  still on its way.
- A post that gets no answer while you are on another tab no longer leaves the Post button stuck
  on "Posting...".

### Buying

- When the auction house does not answer a purchase in time, aux now says it may still go through
  and to check your mail before buying again. Before, trade goods said "Nothing was bought" and
  gear said nothing, which could lead to buying twice.
- A search you start right after buying gear is no longer stopped by aux reading that item again.

### Sniper

- Possible deals the Sniper had not opened yet when you clicked a deal are opened in a later
  round. Before, they were skipped until their price changed.

`/reload` is enough to update.

## 0.7.1 (2026-10-17)

### Auctions tab

- Every one of your auctions now has its own row. Before, identical auctions (on Forever, posting
  several of an item makes one auction each) were folded into one row that still said Qty 1, and
  other prices of the same item were hidden under that row until you expanded it, so the tab
  could show far fewer auctions than you had up (reported by daland).
- Cancel now says **Cancelling...** until the auction house confirms, then "Cancelled, comes by
  mail". Before, the row said cancelled the moment you clicked, even if the auction house never
  confirmed it, and on a folded row only one of the identical auctions was cancelled while the
  row said cancelled. If no confirmation comes within 10 seconds, the row shows its real status
  again and a chat line tells you (reported by daland).

### Search

- A search no longer skips an item without a word. An item the game had not loaded yet (one you
  had never seen, or a slow server) was dropped after 3 seconds, so a search could find nothing
  where Blizzard's window found several. aux now waits up to 5 seconds more for it, and if an item
  still cannot be read, a chat line at the end of the search says how many, so you know to search
  again (reported by daland).

`/reload` is enough to update.

## 0.7 (2026-10-13)

### Search, Sniper, Auctions and Bids tables

- New **iLvl** column, after the level and before the item's name: the item level of weapons and
  armor (empty for everything else). Forever's tooltips do not show item level, so this is the
  only place to see it. Click its header to sort by it. The units for sale follow the item's
  name, with no other column of numbers next to them, so they are easy to read at a glance
  (suggested by HoaxBox).
- The level column, still the first column, is now called **Req** (the level needed to use the
  item; "Lvl" could be read as either) and is colored by how far it is from your level: red 5 or
  more levels above you, orange 3 to 4, yellow 1 to 2, green once you can use it, and gray when it
  is far below you (the levels at which quests and monsters turn gray). Before, it was only red
  when too high.

### Fixes

- Result tables (Search, Sniper, Auctions, Bids) follow the window when you resize it quickly.
  After a fast drag down to the smallest size, a table could keep the width it had a moment
  before, so its right columns (Bid, Buyout, %) ran past the window's edge until the next resize.
  The lists on the Saved Searches tab had the same problem, fixed in 0.5.

### For addon authors

- Other addons can now read aux's prices through the global `AuxForeverAPI`: `GetLatestPrice`
  (the Value shown in tooltips) and `GetUsualPrice` (the multi-day usual price), by item link or
  ID. How to use it: https://github.com/TylerHampton/aux-forever/blob/main/docs/api.md
  (suggested by MDHippie).

A **full game restart** is needed to update (a new file was added); `/reload` is not enough.

## 0.6.1.1 (2026-10-12): The Gaddor Update

**The Gaddor Update**

### Fixes

- Post tab: clicking an item's icon in the list of bag items on the left now selects it for
  posting, the same as clicking its name. Before, only the name worked and a click on the icon did
  nothing. Right-click on the icon also searches the item now, as it does on the name (reported
  by Gaddor).

`/reload` is enough to update.

## 0.6.1 (2026-10-11)

### Search

- Picking a slot under Weapons, such as Weapons, One-Handed, Daggers, now searches only daggers.
  Before, aux understood a slot only under Armor (as in Classic, where weapons had no third
  level), so it searched every one-handed weapon and then looked for the word "daggers" in each
  tooltip: a long search that found little or nothing. The same applies to every slot under
  Two-Handed, Ranged and Miscellaneous weapons, and to Containers and Item Enhancement under
  Consumables. Typing the same text in the search bar works the same way (reported by GregoryWW).
- Filter Builder, "In words": a slot is named first, so Weapons, One-Handed, Daggers reads
  "Daggers (weapons, one-handed)" instead of "One-handed (weapons, daggers)".
- Items Forever adds that Classic did not have now join aux's item list as soon as aux sees them
  at the auction house, so they autocomplete in the search bar and `/aux price <name>` finds them.
  Before, the list only learned items up to Classic's item numbers when you logged in.

### Fixes

- aux now forgets a character of yours that has not logged in for 30 days, as it was meant to.
  It dated each login by how long the computer had been running instead of by the date, so a
  character you deleted, renamed or moved could keep counting as yours, with its name's auctions
  shown as your own. Characters you still play are kept; nothing to do after updating.

`/reload` is enough to update.

## 0.6.0.2 (2026-10-10)

### Fixes

- Post tab: picking an item now always reads its current listings from the auction house, the
  same as pressing Refresh. Before, if you had run a Full scan, the Post tab showed that scan's
  listings instead, which could be an hour old: the price it picked could match an auction that
  had already sold or miss a newer, cheaper one. Those old listings were also split into one row
  per listing (the same price shown several times, some rows without a time left). A Full scan
  still records prices for tooltips, the Sniper and the % column (reported by Tyler).
- Post tab: picking the same item again, or the next item after posting, reads its listings
  again too, so other players' new auctions and sales since your last look show up.
- Post tab: trade goods and other items sold by quantity show one row per price, with the total
  for sale and the longest time left; your own auctions at that price stay a row of their own, in
  green. Before, the same price could appear on several rows (Light Feather: 26, 480 and 10 at 8c),
  which made it hard to see how much was for sale at the lowest price. Gear keeps one row per kind
  of auction (reported by Tyler).
- Post tab: trade goods, potions and other items that are not gear load faster. Picking one used
  to search the auction house for its name first and then read its listings, two requests in a
  row; the item is in your bags, so it is now read straight away with one request, as Blizzard's
  own Sell tab does. Gear loads as before.

`/reload` is enough to update.

## 0.6.0.1 (2026-10-09)

### Fixes

- The "Search in aux" button on the profession window no longer covers Blizzard's Track Recipe
  checkbox. Blizzard's patch of October 8 moved that checkbox from the bottom left of the recipe
  panel to the bottom right, where the button has been since 0.4; the button now sits just left
  of the checkbox wherever Blizzard puts it (reported by Tyler).

## 0.6 (2026-10-09)

A new look by webster, with the 0.5 look kept as the Classic theme, a redesigned Post tab, a bigger
Settings menu and a Sniper that only trusts prices it has seen for 3 days. Run a Full scan on each
visit to the auction house: tooltips, recipe costs and the Sniper all work from it.

**Updating: fully restart the game** after replacing the folder. 0.6 adds a new picture file (the
warning triangle), and the game only loads new files on a restart; `/reload` is not enough.

### The new look and themes

- New look, designed by webster from his UI Kit and screen mockups: near-black panels with black
  edges and square corners, raised buttons that are lighter at the top, and one gold color for
  what is selected or the main action of a screen.
- The selected tab, sub tab and buy quantity have a gold outline. The main button of each screen
  (Search, Post, Buy, Start) has a gold outline and label instead of a solid orange fill.
- Tables have raised column headers, the sorted column is white with a gold arrow, and the
  selected row is gold with a bar at its left edge. Every second row is shaded dark gray (zebra
  rows), which makes long lists easier to follow across.
- Text boxes are a little lighter than the panels and have a gray edge, so you can see where to
  type (the Filter Builder's boxes were hard to find in the first version of the look).
- The percentages, money coming in and going out, and warnings use softer colors.
- Two themes, picked in Settings (the gear, top right): New, the default, and Classic, the look of
  0.5 with its slate panels, amber accent and rounded corners. Changing it shows a Reload now
  button, since the theme is applied when the interface loads. In Classic the main buttons are now
  dark amber with an amber outline instead of solid amber, so prices on them stay readable.
- Money shows its gold, silver and copper letters in their coin colors everywhere a price appears:
  tables, the Buy and Confirm buttons, the recipe line, the Sniper and the Post tab.
- The game's own font is kept: Forever does not load fonts from addons.

### Settings

- The Settings menu is wider and in two columns. Left: Window (background opacity, scale, theme)
  and Posting (default auction length). Right: Tooltip lines, each with an on/off switch: Value,
  Today, vendor sell price, vendor buy price, disenchant value, disenchants into and coin icons.
  These used to be chat commands only; the `/aux tooltip ...` commands still work and stay in step
  with the switches (suggested by a player on CurseForge).
- `/aux post bid` shows or hides the Post tab's bid table at once; it used to need a reload. It is
  no longer offered in Settings: on Forever only gear can take bids, so the setting confused more
  than it helped.

### Post tab

- The panel above the listings is laid out again in three columns: what you post, its price, and
  what you get:
  - Left: the item, Count (gear) or Quantity (trade goods), Duration, the message after a post,
    and Hide from this list (moved here from the top right).
  - Middle: Match lowest / Undercut and the ? button right above the prices they change, price
    fields sized for real prices instead of half the window, and the percentage of the usual price
    beside each field with "of usual" under it (it used to sit in boxes that looked like you could
    type in them).
  - Right, a receipt read top to bottom: the total for the items, the auction house cut (5%, now
    shown as its own line), what you get, and the deposit, then a wide Post button.
- When a vendor pays more than the auction house would, a red box with a red warning triangle says
  "Vendor pays more" with the vendor's amount, and "You get" turns red. It used to be a line of
  small red text that was easy to miss. When the auction house pays more, the vendor's price is a
  quiet gray line under "You get", next to the amount per item.
- The deposit line says "Deposit now, back if it sells" and sits apart from "You get": the deposit
  is paid when you post and comes back when the item sells, so it was misleading right next to
  what you get. A trade good with no deposit shows 0c instead of "-0c".
- Gear whose starting bid equals its buyout gets a gray note: "Bid equals buyout, so it posts as
  buyout only". The game rejects a bid equal to the buyout, so aux already left it out; now it
  says so.
- The note under the price is shorter ("Same as the lowest listing"). Why matching the lowest price
  sells as fast as undercutting on Forever is still explained when you hover the ? button.
- "Posting 1 item" moved into the Post button ("Post 14 items") and the total line ("Total, 14
  items").
- A new goblin on the Undercut button: a new drawing made for auxForever.
- The layout fits the smallest window size without anything overlapping.

### Sniper

- Gray (poor quality) items are never deals, not even below the vendor price.
- A deal against the usual price now needs the usual price to rest on at least 3 days with a
  complete look at the item (a Full scan, or a Full search of the item). Before, a few old asking
  prices could make junk look like a bargain (a Trapper's Shirt listed at 1s showed a usual price
  of 90s). Deals below the vendor price need no history and always show.
- Today's Full scan counts toward those 3 days, so scanning every day gives you usual-price deals
  a day sooner.
- A line next to the deal count tells you where your price history stands: how many days of Full
  scans you have while it is fewer than 3, or an orange warning when your last Full scan is more
  than 2 days old ("usual prices may be out of date"), with a Full scan button beside it. It is a
  warning, not a lock: the Sniper always works.
- While the Sniper runs with no deals, the message under the table explains that gray items are
  left out, that deals against the usual price need 3 days with a Full scan, and that the Sniper
  works best with fresh Full scan data.

### Fixes during 0.6 testing

- The Settings row for bid prices ran its gray line under the Off / Item / Stack buttons.
- The Buy button showed its price without coin colors.
- On the new Post panel: the PER ITEM heading touched the top of the price field, the percentage
  heading was cut off by the divider in a narrow window, and an item with no deposit showed "-0c".

## 0.5 (2026-10-07)

Better prices, clearer posting and clicks that work the same everywhere, with player feedback from
Darkhorse and Garsterson. Run a Full scan on each visit to the auction house: it keeps the prices in
your tooltips and recipe costs current.

- Price data: aux now records a market price from every complete look at an item (Full scan, normal
  searches, the Sniper's checks): the middle price of the cheapest twentieth of what is listed,
  close to the cheapest listings with a real amount behind them. One odd cheap auction no longer
  sets the price. Tooltips show the price from your latest scan as Value, with
  when aux saw it ("seen today", "seen 3 days ago", darker when a week old or more), so a quick
  scan before posting is what you see afterwards anywhere in the world. When that is far from the
  usual price of the last two weeks, a gray "usually ..." line shows it. The usual price, with
  recent days counting more, is what the Sniper and the % columns compare against. Your 0.4.1
  price history is converted, not wiped. Going back to 0.4.1 after this version starts the price
  history over.
- Post tab: a post that does not happen always says why, under Duration and in chat: the item left
  your bags, is locked, needs a repair, was refused (with the game's own reason), or the auction
  house did not answer. A post that went through says "Posted". When the Post button is faded,
  the same place says why (no price, the starting bid above the buyout, not enough money for the
  deposit). (reported by Darkhorse)
- The Saved Searches lists and the Post tab's price lists lay out their columns again when shown
  and when resized, and their last column always ends at the window's edge. After a resize and a
  scale change, the Recent Searches header could stick out of the window. (reported by Garsterson)
- Right-click an item in your bags to bring it into aux: the Post tab selects it, the Search tab
  searches it. (suggested by Darkhorse)
- Clicks work the same way everywhere. Shift- and Alt-click from the bags now also work from the
  Sniper, Auctions and Bids tabs (they switch to Search). Click a selected row again to let go of
  it, in every table. In the Post tab's price
  lists, right-click searches the item like every other row, and click a chosen price again to let
  go of it. Hovering any row shows a gray line with what its clicks do.
- Buy bar: the box for typing how many to buy is labeled QUANTITY and always shows the number you
  are buying; the quantity buttons fill it in, and typing any number changes it. It used to be a
  gray "Other" that looked like a button. (suggested by Darkhorse)
- Profession window: a line under the reagents says what one craft's materials cost at the prices
  of your latest scans (or the vendor price when a vendor sells it for less), anywhere in the world. A gray "+"
  means some materials have no price yet; hover the line for each material's price and where it
  comes from. (suggested by Garsterson)
- Tooltips: with Shift held (prices for the whole stack), Value, Today and the vendor prices say
  "for 3" so they are not read as the price of one.
- Full scan: the status bar says "waiting for the auction house" during the several seconds before
  the list arrives, then how far it is, so the scan never looks stuck.
- Post tab: hovering a faded Post button says why it is faded.
- Right-clicking a bag item into the Post tab no longer leaves it locked (Blizzard's hidden Sell
  tab held on to it, so it could not be picked up).
- At login and after a reload, aux says when your last Full scan was and asks for one on each visit
  to the auction house.
- `/aux price <item>` prints what aux has recorded for an item: the Value shown in tooltips, the
  usual price and how many days it rests on, today's lowest and market price, and each past day.

## 0.4.1 (2026-10-05)

Performance, memory and fixes from a week of testing.

- Memory: a full scan no longer keeps the listings of every item on the auction house for the Post
  tab (about 30 MB for the rest of the session); it keeps those of the items in your bags. Sniper
  rounds keep nothing from round to round.
- Performance: aux's item list at login no longer asks the server about item numbers the game says
  do not exist, and walks the list in steps instead of one long frame. Saved Searches, the Bids tab
  and the quick search menu no longer do work every frame. The Classic-only crafting cost code and
  its `/aux crafting cost` setting are removed; recipe search does this job.
- Sniper: gear deals can be bought. A selected deal is checked again first ("Checking the
  auction...", or what is left of a trade good), the buy bar offers only the units that are a deal,
  and the rounds hold while a deal is selected (click it again to go on) or a purchase is under
  way. Deals that sold sort to the bottom, and the table no longer changes while the mouse is over
  it.
- Live: a new search of any kind ends Live mode, and Live rounds wait while you buy (a round during
  a trade good's price quote ended it with "Internal auction error").
- Tables keep the same row selected when rows are added above it.
- Prices leave out parts that are zero ("7s" instead of "7s 00c"); in a table where any price has
  copper, every price keeps all its parts so the column lines up. The Auction Bid column shows "---"
  for auctions with no starting bid.
- The resize corner: aux sizes the window itself while you drag. A single click on it could make
  the whole window jump.
- An empty search bar no longer lists the whole auction house.
- `/aux memory` also reports the size after a cleanup and the item list; `/aux memory detail` lists
  what aux keeps.

## 0.4 (2026-10-05)

- Auctions tab: each of your auctions is compared with the other sellers: undercut (and by how
  much), tied, lowest or sold. "Cancel undercut" cancels the undercut ones, one click each, and
  shows what each cancel costs; cancelled items come back by mail. Prices are read when the tab
  opens (or with Check prices), half a second per item, never in the background.
- Recipe search: with aux open at the auction house, the profession window gets a "Search in aux"
  button, and Alt-click on a recipe does the same. aux searches the item the recipe makes and all
  its materials at once. The bar under the results adds up the materials (cheapest auction or
  vendor price), what the item sells for after the cut, and the profit or loss; a material with
  no price is named, and the result becomes "loss at least" or "profit at most". Recipe searches
  show in Saved and Recent as "Recipe  Name  (N materials)" and keep their cost line. Nothing is
  read before you click.
- Post tab: after posting everything of an item, the next item in the list is selected.
- Sniper: deals show while a round runs, with "checking N possible deals (k done)"; one sound for
  a burst of deals (at most one every 10 seconds); deals no longer vanish for a while when the game
  reloads item data; 2.5 seconds between rounds instead of 1; the empty table's text is no longer
  cut off.
- Performance and memory: item tooltips no longer build a hidden tooltip on every hover; the Post
  tab and the buy bar no longer redo their work every frame; scans no longer unpack each item's
  price history for every auction they see; Sniper rounds build no tables per item and keep
  nothing from round to round (about 1 MB of notes on the items, once).
- `/aux memory` also shows what is left after a cleanup, to tell real use from garbage the game
  has not freed yet. `/aux debug` prints timing for searches only, not for every Sniper round or
  Auctions check.

## 0.3.1 (2026-10-05)

- Performance: aux no longer does work every frame while idle. A check inherited from Classic aux
  compared every event listener with every other one on every frame, all game long, even away
  from the auction house; the Auctions and Bids tabs each ran a timer every frame to rebuild their
  lists every second; the Full scan button repainted itself every frame. Now the event cleanup
  runs only after a change, the Auctions and Bids lists follow the game's events (and refresh
  every 10 seconds while open), and the Full scan button and Live and Sniper status lines update a
  few times a second.
- `/aux memory` says how much memory aux uses and how many items its price history holds.

## 0.3 (2026-10-05)

- Fast searches: a search over many items lists each item once with its lowest price and how many
  are for sale, read from the auction house's item list in seconds instead of minutes. Click an
  item to see its auctions and buy. A Fast / Full switch sits next to Search. Searches for one
  exact item, or using seller, time left, bid or tooltip text, read every auction as before, and
  the line next to the tabs says why.
- Live mode shows what it is doing: "Updating" during a round, then a countdown to the next one
  ("Live 4s"), and "Paused" only when you pause it. It repeats the search every 5 seconds, holds
  while you are on another tab and carries on when you come back.
- New Sniper tab: watches the whole auction house round after round (about 8 seconds a round) and
  lists deals: below vendor price, or at most 60% of the usual price, with at least 5s profit
  either way (both adjustable). The usual price needs 3 days of price history. Each deal is
  checked against the item's real auctions before it is shown, and buying works as on the Search
  tab. A sound and a flashing game icon for new deals; ignore items you do not want.
- Post tab: items in the reagent bag are listed too.
- The Blizzard window's own tabs (Buy, Sell, Auctions) no longer stretch off the screen.
- A search that hits an error now stops cleanly and says so in chat, instead of looking busy
  forever.
- New credit line: "aux by shirsig, re-imagined by a fan".
- Needs a full game restart after updating (new files).

## 0.2.1 (2026-10-04)

First release since 0.1.1, so it also brings everything from 0.2: the new Filter Builder
(conditions in plain words, Match All or Any, "not", groups inside groups, an "In words" line,
kept in sync with the search bar), the default duration setting and the favorites fix.

- Post tab: trade goods have one Quantity box instead of Stack size and Stacks. Forever posts a
  trade good as one listing of any size, so Max now posts everything you have.
- Search tab: the Search Results tab shows how many items were found, a line next to the tabs
  says what they hold ("37 items, 403 for sale, searched 2m ago"), and the search bar has a
  magnifier.
- Filter Builder: a Match All / Any switch is faded while it has fewer than two conditions under
  it, and the builder keeps your groups when you leave it and come back.
- Settings: a Scale setting (70% to 150%), handy on large monitors, and the scale is now kept
  after a reload. The settings menu has no explanation text; the auction length setting is now
  called Default duration, like the Duration buttons on the Post tab.
- `/aux debug` turns on a search timing log: after each search, chat shows where the time went.
- The resize corner no longer makes the window jump to full screen on a single click.
- Blizzard UI button: the Blizzard window could end up off screen after opening another game
  window (character sheet, spellbook, a vendor), so the button seemed to do nothing. It now
  always opens on screen and in front of aux, and the button is lit while it is shown.
- Needs a full game restart after updating (a new icon was added).

## 0.2 (2026-10-04)

- New Filter Builder: conditions in plain words, Match All or Any, "not" on any condition, groups
  inside groups, and an "In words" line that reads the search back. It stays in sync with the
  search bar.
- Settings: default auction length (2h, 8h or 24h) for items you have not posted before.
- Favorites: an empty search is no longer saved, and the same search is not saved twice.
- Needs a full game restart after updating (a new file was added).

## 0.1.1 (2026-10-04)

- Fixed: posting gear failed with "Internal auction error" when the starting bid equalled the
  buyout. Such items are now posted for buyout only.

## 0.1 (2026-10-04)

- First test release of auxForever, aux by shirsig rebuilt for WoW Forever: search, buying (trade
  goods by quantity with a confirmed price, gear one at a time), posting at the lowest price with
  an optional undercut mode, quick searches and price history.
