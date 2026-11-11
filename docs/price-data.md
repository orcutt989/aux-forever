# Price data: where aux keeps prices and how it uses them

Written 2026-10-07 for Tyler and for any agent touching prices. Facts come from the code (file and
function named); anything else is marked as an inference or an opinion.

Note (0.5): the sections up to "Plan for 0.5" describe the 0.4 data as it was when this file was
written. 0.5 changed what is recorded and how the usual price is worked out; what was built is
at the start of "Plan for 0.5".

## In one paragraph

aux keeps one short line of text per item: the lowest price it saw for that item today, plus the
lowest price of each of up to 11 earlier days on which it saw the item. The "usual price" (called
"Value" in tooltips) is worked out from those daily lows. Everything aux has ever scanned feeds
this, not only the Full scan. It is saved in the game's own saved-variables file, so it is there
after a logout and away from the auction house.

## Where it is stored

- WoW lets an addon keep data in one way only: saved variables, which the game writes to a file
  when you log out or `/reload`. aux's are declared in `auxForever/auxForever.toc`
  (`## SavedVariables: aux`). On disk this is
  `World of Warcraft\_classic_beta_\WTF\Account\<account>\SavedVariables\auxForever.lua`
  (the game names the file after the addon folder).
- Inside it, price history sits under `aux.faction["<realm>|<faction>"].history`
  (`faction_data`, set up in `auxForever/aux-addon.lua`). So each realm and faction has its own
  history; characters of the same faction on the same realm share it.
- One entry per item, keyed `"<item id>:<suffix id>"` (gear "of the Owl" and "of the Bear" are
  separate items). The entry is packed text (`history_schema` in `auxForever/core/history.lua`):
  when today ends, today's lowest, and the list of past daily lows with their dates. Packing keeps
  the file and memory small.
- While playing, aux also keeps in memory (not saved): today's lowest per item seen today
  (`today_min`) and the usual prices worked out so far (`value_cache`). `/aux memory detail` counts
  them.

## How a price gets in

- Every auction any scan sees goes through `history.process_auction` (`auxForever/core/history.lua`,
  called from `auxForever/core/scan.lua`): Search (fast and full mode), Live, the Sniper's checks
  of single items (`scan.read_item`), and the Full scan.
- It records only a new low: if this auction's price per unit is below today's lowest for the
  item, it becomes today's lowest. Nothing else about the auction is kept (not how many were for
  sale, not the second cheapest).
- At local midnight (`get_next_push`), the next time the item is read, today's lowest moves into
  the list of daily lows. The list keeps the 11 most recent days that had a price (`push_record`).
  Days without a scan of the item add nothing; old days stay until 11 newer ones push them out.

## How the usual price is worked out

`history.value` in `auxForever/core/history.lua`:
- With no past days yet: today's lowest.
- Otherwise: a weighted median of the past daily lows (the middle value, with each day's weight
  `0.99 ^ days old`). Today's lowest is not part of it until the day ends.
- `history.market_value` is today's lowest ("Today" in tooltips).

## Where it is used

- Item tooltips: "Value" (usual) and "Today" (`auxForever/core/tooltip.lua`).
- Search results: the percentage of the usual price (`gui/auction_listing.lua`).
- Post tab: the "% of usual" badge, and the starting price when an item has no listings
  (`tabs/post/core.lua`).
- Sniper: the deal rule compares prices with the usual price, shown only with 3 or more days of
  history (`tabs/sniper/core.lua`). Since 0.8.2 (FB-036) also with today's market, read from the
  item's other listings (`market_now`): the lower of the two counts.
- Search filters such as `pct` and `profit` (`util/filter.lua`), disenchant values
  (`core/disenchant.lua`).
- Planned: recipe cost in the profession window (`docs/feedback.md`, FB-007).

## Is it the best way? (Claude's assessment, 2026-10-07)

Where it is stored is right: saved variables are the only place an addon can keep data, and one
packed line per item is small. Measured in 0.4: about 2,200 items with a usual price after normal
play, a small part of aux's memory (`docs/status.md`).

What it records is the weak part. These are inferences from the code, not measured in game:

1. **One cheap auction sets the day.** Only the single lowest unit price is kept. One trade good
   listed far too low (a mistake, or one unit) becomes that day's value. The weighted median over
   several days softens this, but a usual price built from only a few days of scans does not.
2. **It does not know how much is for sale at that price.** For buying 20 of a material, the
   cheapest unit understates the cost. This matters for the planned recipe cost (FB-007) and for
   the Sniper.
3. **Old prices count almost as much as new ones.** The weight `0.99 ^ days` is nearly flat: a
   price from 30 days ago counts about three quarters as much as yesterday's. With 11 days kept,
   someone who scans once a week has a usual price spread over about two and a half months.
4. **Nothing says how fresh a price is** when it is shown (except the Sniper's 3-day minimum).
5. **Per faction.** History is kept per realm and faction, as in Classic. Whether Forever's
   auction house is shared between factions: guides say each faction has its own house and only
   the neutral houses are shared (`docs/forever-auction-house.md`, section 1, Outside; experiment
   E2). If they are right, prices seen at a neutral house are mixed into the faction's history.

For comparison, from memory and not checked: TSM's "market value" averages the cheaper part of
the listings over about two weeks instead of taking the single lowest auction. Check TSM's own
documentation before relying on this.

## Plan for 0.5 (decided 2026-10-07, built 2026-10-07)

Built on 2026-10-07 as planned, with these details settled while building (`core/history.lua`):
- Record line (history version 3): `day#low#market#units#points`, points `day@price@units`. `day`
  is a calendar day number (days since 1 January 1970), so time zones and summer time never merge
  or skip a day. A point's price is that day's market price, or its lowest when no complete view
  was seen that day.
- Version 2 lines (0.4.x) are converted when an item is first read, not all at login, so login
  stays as fast as before. A 0.4 line is recognized by its first field (a 10 digit timestamp).
- Market price: average of the cheapest 20% of the units (at least one unit), rounded up.
  `MARKET_SHARE`, `MAX_POINTS` (14), `HALF_LIFE` (7 days) and `OLD_DAYS` (7) are constants at the
  top of the file.
- The age shown is "seen N days ago": days since aux last saw the item (today counts), from
  `history.value_and_age`. Tooltips add it after Value, darker from 7 days on.
- The Full scan still records each auction's low as it goes (so an interrupted scan keeps its
  lows) and records market prices once per item at the end. Items whose auctions did not all load
  get no market price.
- Weights are relative, so converted items' usual prices can shift where their old lows varied:
  recent days now count more. Steady prices stay the same (tested).

Changed after testing (build 3, Tyler's decision 2026-10-07): players do a full scan, post and
leave within minutes, and need to trust the tooltip away from the auction house. On day one the
usual price rested only on 0.4.1's daily lows (Tel'Abim Banana: usual 87c from one old low, while
today's market was 39c), and today's price would only count after midnight. So there are now two
numbers with two jobs:
- **Latest price** (`history.latest`): the market price of the most recent complete look (its
  lowest when there was none that day), with its age. Shown as Value in tooltips and used by the
  recipe cost line.
- **Usual price** (`history.value`): the multi-day weighted median above. Used to find deals: the
  Sniper's rule, the search % column, the Post tab's % badge, the percentage and profit filters,
  disenchant values. Tooltips show it as a percent on the Value line, "Value: 2s (67%)", in the
  Search tab's % of usual colors (0.8.2 build 4; before, a gray "usually ..." line when it
  differed from the latest by 30% or more). Disenchant expected value uses **latest** mat prices
  (with usual as fallback), so a tip's Disenchant: line matches today's reagents, not a stale usual day.
- Build 3 test: a Full scan alone recorded Rough Dynamite at 30c, the same as its lowest listing
  (514 listed), so Full scan prices look right. Linen Cloth showed 32c while 296 were listed at
  23c: the average of the cheapest 20% reached up to 36c in a deep market. Build 4 changed the
  market price to the middle unit price of the cheapest 5% of the units (`MARKET_SHARE = .05`),
  which gives 24c there and still ignores one odd cheap auction.

The plan as written before building:

Tyler: "I do want you to make changes to the data and make it better, [...] as this is going to be
like an improved version of the original." His concerns: storing too much, slowing the addon, and
what else a change this basic could break. He left the engineering to Claude. The plan below is
Claude's; numbers marked "start with" are first settings to check in game, not measured.

### What changes

1. **Two prices per day instead of one.** Keep today's lowest (as now, "Today" in tooltips) and add
   a **market price**: the average unit price of the cheapest 20% of the units listed (start
   with 20%; at least the cheapest auction), plus how many units were listed. One cheap auction
   then moves the market price only a little.
2. **Only from complete views of an item.** The market price needs every auction of the item, so it
   is recorded when aux has seen all of them: the Full scan, a full-mode search (one search per
   item returns all its auctions: `search` in `core/scan.lua` asks for more until
   `HasFull...SearchResults`; if a request for more fails, the view is not complete and records no
   market price), and the Sniper reading one item (`scan.read_item`). Fast mode
   rows already feed nothing (`process_auction` in `core/scan.lua` skips `auction.fast`). If an
   item is seen completely more than once a day, the latest view wins.
3. **Full scan collects, then records.** The Full scan's auctions arrive in no item order, so it
   gathers (unit price, count) per item in a temporary table while it runs and records each item
   once at the end, yielding every few hundred items (AGENTS.md, Performance). Use flat number
   arrays per item, not a table per auction. The table is dropped when the scan ends.
4. **Usual price from market prices, recent days counting more.** Weighted median of the daily
   market prices (old converted days use their daily low), weight halving every 7 days (start
   with 7; today it is about every 70 days). Keep up to 14 days of points (start with 14; today 11).
5. **Age is shown.** The usual price comes with how many days old its newest point is, shown in
   tooltips and the recipe cost tooltip ("usual, 3 days"), dimmed when old (start with 7 days).
6. **Smaller dates.** Store days as day numbers (5 digits) instead of full timestamps (10 digits),
   which pays for most of the added numbers.

### What stays the same

- `history.value`, `history.market_value` and `history.value_and_days` keep their names and
  meaning (a price per unit), so the places that use prices (list above: tooltips, search
  percentages, Post tab, Sniper, filters, disenchant) need no rewrite. Their numbers change, which
  is the point.
- Where it is stored (saved variables, per realm and faction), lazy unpacking (an item's line is
  only unpacked when asked for), the in-memory caches.

### How much code

- `core/history.lua` (144 lines): most of it rewritten (record format, market price, usual price,
  conversion).
- `core/scan.lua`: the four places that feed history (`process_auction`, `scan_item_keys`, the Full
  scan loop, `read_item`) hand over an item's auctions together instead of one at a time.
- `aux-addon.lua`: `history_version` 3 with a conversion of version 2 (the mechanism exists: it is
  how the first test version's bad prices were reset).
- `core/tooltip.lua`: the age next to Value.
- Tests in `tests/load_test.lua` (existing history tests at "fast: its auctions are price history",
  the Sniper history-cache tests and the memory tests must keep passing), plus new ones below.
- Nothing else is rewritten.

### Cost (estimates from the record format, not measured)

- Saved data: today about 220 characters per item; with the market price, the units listed and
  shorter dates, about 300. With every item on the auction house (about 7,700, the Sniper's count)
  that is roughly 2 MB now and under 3 MB after: under 1 MB more in the worst case. aux settles at
  about 10 to 17 MB in play (`docs/status.md`), so this is small.
- Login: unchanged. Lines are unpacked only when an item is asked about.
- Full scan: sorting each item's prices once at the end. A few hundred thousand numbers at most,
  spread over frames with `aux.coro_wait()`; inference: well under a second of work in total.
- Searches and the Sniper: one extra sort per item read, which is small next to the server's
  request limit (0.4s per item, measured in 0.2.1).

### Risks and how each is handled

1. **Prices players see will change.** Usual prices of items with outlier lows go up. The Sniper may
   find more or fewer deals, the Post tab's "% of usual" badge shifts. Intended; check the Sniper's
   default deal rule against the new numbers in game.
2. **Converting old history.** A bug there could wipe everyone's history. Test the conversion with
   real-looking version 2 lines, and check that every old daily low survives.
3. **Going back to 0.4.1 after 0.5** starts the price history over (0.4.1 resets any version that is
   not 2). Acceptable for a beta with few players; say so in the changelog.
4. **Memory during a Full scan.** Temporary, dropped at the end; test with the memory harness
   (`/aux memory`, the "rounds keep no memory" style tests).
5. **Two different days for "today".** Unchanged: the day still ends at local midnight.

### Tests to add (each fails without the change)

- One very cheap auction among many barely moves the market price, while today's lowest is that
  cheap auction.
- A Full scan records each item once, with the right market price and units, whatever order the
  auctions arrive in.
- Version 2 history converts: every old daily low is kept and the usual price is unchanged right
  after conversion.
- Recent days outweigh old ones in the usual price.
- No per-frame work and no memory kept after a Full scan ends.

### In game (for the 0.5 test page)

- After a Full scan, `/aux memory` before and after: the difference stays under about 1 MB.
- Tooltips on a few trade goods: Value, Today and the age look sensible next to the auction house.
- The Sniper still finds deals with the default rule.

### Open (unverified)

- Whether Forever's auction house is shared between factions. If it is, history could be kept per
  realm instead of per realm and faction. Check before changing; not part of the plan above.
