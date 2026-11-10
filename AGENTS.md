# auxForever: guide for AI coding agents

This file is for any AI agent working on this repository (Claude Code, Gemini CLI, Jules, others).
`CLAUDE.md` and `GEMINI.md` only point here. Read this file, then `docs/status.md` (where things
stand), before changing anything.

## The project

auxForever is a port of **aux**, the auction house addon by shirsig (Simon), to **World of
Warcraft: Forever**, plus a visual redesign and modern improvements. The credit line, used in the
addon and on every page, is: "aux by shirsig, re-imagined by a fan". Simon gave written
permission by email (quoted in `README.md`); he is not involved in this version.

- Forever runs the modern client (Interface 16001, game version 1.60.1) with the modern auction
  house API (`C_AuctionHouse`). aux was written for Classic Era's old auction house, so search,
  buying and posting were rewritten. Facts about Forever's auction house, with sources:
  `docs/forever-auction-house.md`. Read it before touching scanning, buying or posting.
- **Only confirmed facts about Forever's auction house** (Tyler, 2026-10-11, "we need to confirm
  things like this"). Every fact in `docs/forever-auction-house.md` is labeled Seen (seen in game),
  Code (Blizzard's Forever code), Outside (another addon or a guide) or Unknown. Only a Seen fact
  goes to a player, into a reply Tyler sends, or into a design decision as plain fact; anything
  else is said with its label ("Blizzard's code shows X; not yet seen in game"). Retail WoW
  knowledge counts as Outside. A new fact goes into that file with its label; an Unknown that
  matters becomes an experiment there for Tyler.
- The addon is the `auxForever/` folder. Players copy it into
  `World of Warcraft\_classic_beta_\Interface\AddOns`.
- Released as a beta on CurseForge (unlisted). Page text and settings: `docs/curseforge.md`,
  paste-ready copy `docs/curseforge-description.md`. Version is in `auxForever/auxForever.toc`
  (`## Version: forever-x.y.z`).

## The owner: how to work with Tyler

Tyler owns the project and tests every change in the game. He is not a programmer.

- Explain in plain words. Say what to click and where. No unexplained jargon.
- Lead with the answer or recommendation, details after.
- After every change, give him a ready-to-install zip (see Packaging) and say whether `/reload` is
  enough or a **full game restart** is needed (any new file: Lua, texture, font).
- Ask before large or hard-to-redo work. For visual changes, show a mockup first and build only
  once he approves it (this was done for the Post tab, quick searches and the Filter Builder).
- Do not flatter. If an idea is weak, say so and why; push back on weak trade-offs. Say what you
  know, what you infer and what you are unsure of. Never invent facts; cite sources.
- No em dashes and no emojis in anything published: README, docs, commit messages, in-game text.
- Avoid filler words such as delve, leverage, robust, seamless, crucial, notably.
- Dates are Tyler's: UTC-6 in summer time, UTC-7 in winter (US daylight saving dates). The
  session clock and the date an agent is given are usually UTC, so from 6 pm his time (5 pm in
  winter) they already show the next day. Get his date with
  `TZ='<-07>7<-06>,M3.2.0,M11.1.0' date` and write that one in docs, comments, changelog headings and
  commit messages. Dates of outside events (a Blizzard patch, a player's message) stay as their
  source gives them. Older dates were corrected to his time on 2026-10-09 (Tyler).
- Privacy (Tyler, 2026-10-20): this repository is public, so write nothing about Tyler beyond
  what the work needs. No city, region or time zone name (only the UTC offsets above), no
  schedule or habits ("his evening"), no real-life details (job, family, contact details, his
  game characters, realm or guild members' details). The same goes for collaborators: the
  designer is called only "webster", never his real name, handles or job. Player rules are in
  `docs/feedback.md`. Earlier mentions were removed on 2026-10-20; git history still has them.
- He tests in game and reports with screenshots and BugSack error text. Each bug report becomes a
  fix plus a test that fails without the fix.
- The addon informs, it does not decide for the player (Tyler, 2026-10-19, after FB-021): "We
  aren't controlling people and telling them exactly what they need to do. People should be free
  to do whatever they want with our add-on. We just give them the tools that they need to make
  the correct decision." aux never blocks something Blizzard's own window allows (a price, a
  quantity, buyout only). It may warn (the red vendor warning) and suggest (the automatic price),
  never refuse. Before adding a check that fades a button, find the same rule in Blizzard's code
  (`Gethe/wow-ui-source`, branch `forever`) or in the game's answer.
- Feedback from players reaches us through Tyler and is logged in `docs/feedback.md` (rules at
  the top of that file) before anyone fixes it. A player's problem is treated as the addon's
  problem, never as the player's mistake: the addon should make players good at the auction house
  through clear screens and clear information (Tyler). One rare exception (Tyler, 2026-10-09):
  when a player asks for something Forever's auction house itself does not have (for example
  Classic stacks), the feedback is answered and recorded as `wont-fix`, not built. auxForever is for
  intermediate players who know the modern auction house; teaching it is not the addon's job.
  When in doubt, the main rule applies. Changes that come from feedback credit the player by
  in-game name in `docs/changelog.md`.

## Workflow

### Branches and coordination (several agents share this repo)

- Never push to `main` or merge a pull request unless Tyler asks.
- Work on a branch. Before starting, pull the latest of that branch. When done, commit, push, and
  update `docs/status.md` (what changed, what still needs testing in game). The next agent, which
  may be a different AI, relies on that file and on the git log.
- Only one agent works on a branch at a time. If two run at once, use two branches.
- Commit messages: a short summary line, then plain sentences on what and why. No em dashes.

### Wrapping up a session (Tyler, 2026-10-09)

When Tyler says or hints that he is stopping ("done for the night", "getting off", "that's it for
today", "goodnight", or similar), wrap up without being asked. The session may be closed or its
machine reclaimed at any time after that, so anything not pushed is lost.

1. If code changed since the last push: run the tests (both looks) and the syntax check.
2. Commit and push everything to the session's branch.
3. `docs/status.md`, "Start here": where things stand (what is built, tested, released, waiting),
   the next step, and open questions for Tyler. Use his date.
4. Record what was decided during the session where it belongs: rules about how to work in this
   file, player feedback in `docs/feedback.md`, plans in `docs/roadmap.md`, unreleased changes in
   `docs/changelog.md`, the current build's steps in `TESTING.md`.
5. If he tested a build and has not said "done", read the test page results first.
6. Reply in a few lines: what was saved, what is waiting, and what the next session starts with.

Wrapping up never merges, releases or opens a pull request; those wait for Tyler to ask. If
nothing changed since the last push, say so in one line.

### Tests (required before every push)

The test harness stubs the WoW API in plain Lua 5.1 and loads every file in TOC order.

```
cd auxForever
lua5.1 ../tests/load_test.lua basics    # local contract: DE/value/vendor/suffix/money/buy bar
lua5.1 ../tests/load_test.lua smoke     # fast tooltip DE matrix + suffix inject
lua5.1 ../tests/load_test.lua           # full suite (must end: done, errors: 0; exits 1 on fail)
lua5.1 ../tests/load_test.lua classic   # the same in the Classic look (0.6)
for f in $(find . -name '*.lua'); do luac5.1 -p "$f"; done   # syntax check
```

On Windows: `powershell -File tests/test-basics.ps1` (syntax + basics + smoke, non-zero exit on
fail). Prefer `basics` / that script while fixing tooltip DE; use the full suite before a push.

In game, `/aux smoke` prints tooltip switches and whether DE / value / vendor lines are on the
open tip (hover green gear first). Use it only after the local suite is green.

- Setup on Ubuntu/Debian (also a Jules setup script): `sudo apt-get update && sudo apt-get install -y lua5.1 zip`
- GitHub Actions runs the same checks on every push and pull request (`.github/workflows/test.yml`)
  and attaches the installable addon to the run. If Lua is not installed locally, push and read the
  result there.
- Add a test for each bug fixed and each feature. Check that it fails without the change
  (break the code on purpose, run, restore).
- The harness uses Forever's real auction house categories (`tests/forever_categories.lua`: Weapons,
  One-Handed, Daggers and so on, with the filters each one sends), made from Blizzard's code by
  `tests/tools/make_forever_categories.lua` (how to run it is at its top). After a Blizzard patch
  that changes the auction house categories, run it again. Item type names in it (Daggers, Cloth)
  are written by hand in the script, copied from what the game printed (2026-10-11); the two
  `/run` commands in `TESTING.md` (0.6.1 build 2) print them again if they need checking.
- Timing (2026-10-18, FB-021): the stubs answer a request at once, the game a second or more later
  while players keep clicking. `tests/slow_server.lua` is a fake auction house (a bag, listings,
  answers after `delay` seconds, a busy throttle, a record of what aux posted and bought), and
  `tests/timing_test.lua` plays the tabs against it. For anything that talks to the auction house
  (posting, buying, cancelling, scans), add a test there: do what a player does while the answer
  is on its way, and check what reached the server (`server.posts`, `server.purchases`), not only
  what the screen says. Click buttons only when the addon would have them enabled
  (`click_post` there): calling `OnClick` straight past a faded button hid FB-021.
- Harness limits: `GetChecked`, `HasFocus` and `IsMouseOver` always return false; `SetShown` does
  nothing; `Get*` methods return fresh stub frames; `SetText` does not fire `OnTextChanged`, so call
  an edit box's `change(self, true)` yourself. Reach a module's internals in a test with
  `loadstring("select(2, ...) 'aux.tabs.search'; return _M")('auxForever', addon)`.
- Tests cannot show layout or how the game reacts. Add the in-game checks for each change to
  `TESTING.md` ("Current build") so Tyler can verify; Claude also makes a test page per build
  where Tyler marks each step and Claude reads the results.

### Releases

Only when Tyler says a version is ready: merge its pull request into `main`, then run the Release
workflow (`.github/workflows/release.yml`) on `main`: Actions tab, Release, "Run workflow" (or, for
an agent, trigger the workflow through the GitHub API; Claude's session cannot push tags). It reads
the version from the TOC, runs the tests, builds `auxForever-<version>.zip`, creates the tag
`v<version>` and publishes a GitHub Release (pre-release while in beta) with the version's notes
from `docs/changelog.md`. Pushing a matching `v<version>` tag does the same. The same workflow then
uploads the zip to CurseForge (project 1727417) as a Beta file with the version's notes, using the
repository secret `CF_API_KEY` (`.github/scripts/curseforge.sh`; the CurseForge check workflow
shows which game version an upload would use, without uploading). The CurseForge page description
is still pasted by hand by Tyler (see `docs/curseforge.md`).

### Packaging

The zip must contain the `auxForever` folder at its top level:
`zip -qr auxForever.zip auxForever -x '*.git*'` (Windows PowerShell:
`Compress-Archive -Path auxForever -DestinationPath auxForever.zip -Force`). Each GitHub Actions run
also offers it as a download ("auxForever" under Artifacts).

## Code map

Load order is the TOC (`auxForever/auxForever.toc`).

- `libs/package.lua`: the module system (see gotchas). `compat.lua`: old Classic function names
  mapped to modern ones.
- `aux-addon.lua`: events, saved variables (`account_data` defaults), tab switching.
- `frame.lua`: the main window: top bar (logo, tabs, the settings gear, Full scan, Blizzard UI,
  close), resize grip, credit label. Settings (0.6) is two columns, approved by Tyler from a mockup:
  Window (background, scale, theme) and Posting (default duration) left, tooltip line switches
  right (bid prices left Settings in 0.6 build 5; `/aux post bid` remains). A setting that also has a chat command must behave the same from both.
- `color.lua`: the palettes of the two looks (New, Classic; see Design language). `gui/core.lua`:
  widgets (button, label, editbox, dropdown, checkbox, status bar, square or rounded shapes, button
  looks, `themed` and `settle_theme`, zebra rows, background opacity).
- `core/scan.lua`: the scan engine, rewritten for `C_AuctionHouse` (browse query, then one search
  per item key; full scan with `ReplicateItems`). Fast mode (`params.fast`) stops at the browse
  list: one row per item (`info.browse_record`, `record.fast`); `params.on_item_list` hands the raw
  list to the Sniper. `util/scan.lua`, `util/info.lua`: helpers and
  item/auction records. `core/history.lua`: price history (`docs/price-data.md`). Two prices since
  0.5: `history.latest` (market price of the latest complete look, shown as Value in tooltips and
  used by the recipe cost) and `history.value` (the multi-day usual price, used to find deals: the
  Sniper, % columns, filters). A complete look (Full scan, full-mode search, `scan.read_item`) feeds
  `history.record_view`; single auctions feed `process_auction` (today's lowest only).
  `/aux price <item>` prints what was recorded. `core/api.lua` (0.7): `AuxForeverAPI`, the only
  global other addons may call (prices by item link or ID; `docs/api.md`). Its names and meanings
  are a promise: add functions, never change or remove one.
- `util/filter.lua`: aux's search language: parsing, the post filters and their validators.
- `gui/auction_listing.lua`: the result tables (columns Req, iLvl, Item, For sale, ...; Tyler,
  0.7: Req always first, and the units for sale never sit next to another column of plain numbers). Since 0.7
  Req is colored by distance from the player's level (`requirement_color`) and iLvl shows gear's
  item level (`record.item_level`); the Sniper and Auctions tabs reuse both columns.
  `gui/buy_bar.lua`: buying under the search results.
- `tabs/search/`: `core.lua` (sub tabs), `results.lua` (searches, history arrows), `saved.lua`
  (favorites and recent), `quick.lua` (quick search menu), `filter.lua` (Filter Builder logic:
  condition tree, search text, "In words"), `frame.lua` (Search tab widgets),
  `builder.lua` (Filter Builder rows and menus), `recipe.lua` (recipe search: the button on the
  profession window, Alt-click on a recipe, the cost line in the bottom bar, and since 0.5 the
  Materials line under the profession window's reagents).
- `core/shortcut.lua`: clicks on items outside aux (bags, links, recipes), including right-click on
  a bag item (0.5, follows Blizzard's `AuctionHouseFrame:SetPostItem`). The click standard is in
  `docs/clicks.md`; row click hints come from `gui.add_click_hint`.
- `tabs/sniper/`: the Sniper tab (0.3): `core.lua` (rounds over the whole item list, the deal
  rule `judge`, checking a candidate's real auctions, buying), `frame.lua` (controls and table).
- `tabs/post/`: posting (auto price, undercut mode, deposit, "You get"). Since 0.6 the top panel is
  three columns (`frame.lua`, option A of the mockup): setup, price (with `price_layout`, checked
  by a test at the smallest window), and a receipt with the red vendor warning (`vendor_warning`,
  texture `textures/warning.tga`). `tabs/auctions/`,
  `tabs/bids/`: the other tabs. `core/slash.lua`: `/aux` commands.
- `textures/*.tga`: icons and rounded corners (addon textures load; addon fonts do not).

## Performance (Tyler: "add-on performance and compute cost is very important")

aux runs inside the game; every frame it spends time in costs the player frame rate.
- Nothing may run every frame while it has nothing to do. `OnUpdate` handlers return at once when
  idle, throttle to a few times a second (`GetTime()` checks), and only touch widgets (`SetText`,
  `SetBackdropColor`) when a value changed.
- No endless `aux.coro_thread` loops: a thread that `coro_wait`s forever is resumed every frame,
  all game long, even with the auction house closed. Use events, or a timestamp check inside a
  tab's own `on_update` (which only runs while the tab is shown).
- No work that grows with the square of anything per frame or per event.
- Long loops (thousands of items: the Sniper, fast lists, full scans) yield with `aux.coro_wait()`
  every few hundred items so the game does not stutter.
- Prefer one request over many: the item list (one request per 500 items) over one search per
  item, and read single items only when needed.
- Tests guard the rules above (`per-frame work` in `tests/load_test.lua`); add one when you add an
  `OnUpdate` or a timer.

## Code gotchas (each one has caused a real bug)

- **Module system:** a file starts with `select(2, ...) 'module.name'`. `M.x = v` writes both the
  module environment and its exports, but **reading `M.x` gives nil**. Read `x` from the
  environment, or use a local.
- `frame.lua` and `aux-addon.lua` are module `aux` itself: use `color`, `account_data`, `bounded`
  directly there, not `aux.color` (the global `aux` is the saved variables table).
- Lua 5.1 only (WoW): no `goto`, no `//`, no integer types. Use WoW globals such as `tinsert`,
  `strlower`, `format`.
- Never wrap code that waits (`aux.coro_wait`, any scan request) in `pcall`: Lua 5.1 cannot yield
  inside a `pcall`, so it fails at once. The test harness only notices if the stubbed answer
  arrives on a later tick, as in the game.
- Colors from `color.lua` are callable: `aux.color.accent.background('text')` returns colored
  text; `aux.color.accent.background()` returns r, g, b, a.
- `gui.editbox` calls `editbox.change(self, is_user_input)` on every text change, `enter`, `escape`,
  `char`, `focus_gain`, `focus_loss`. Right click clears it.
- The modern client takes edit box focus away on any mouse press. Dropdown options therefore act
  on `OnMouseDown`, and the menu stays open while hovered (`gui/core.lua`).
- Never hide and re-show a button every frame: the game drops clicks on it (this broke Cancel on
  the buy bar). Show or hide only when the state changes.
- Rounded styling: `gui.set_frame_style` replaces `SetBackdropColor`/`SetBackdropBorderColor` on
  the frame, so later calls recolor the rounded shape.
- Forever rejects fonts shipped in addons; the game font is used. `.tga` textures load.
- A hidden box still holds a value. Trade goods hide the starting bid, but aux kept one, and a
  check on it faded Post with a message about a box the player cannot see (FB-021). A check or
  message about a field applies only while that field is shown.
- Buying must never spend more than the player saw: the buy bar confirms only server quotes at or
  below the shown price. Keep that guarantee.
- Posting: an item auction's buyout must be above its starting bid, or the server answers
  "Internal auction error"; an equal bid is dropped (`item_post_prices` in `tabs/post/core.lua`).
  Gear is priced in whole silver; commodities may use copper. The auction house cut is the
  constant `AUCTION_CUT = .05` (Outside, not yet seen on an invoice). Deposits come from the game
  (`CalculateItemDeposit`).
- The Post tab matches the lowest price by default, on the belief that on Forever the newest
  listing at a price sells first. That belief has no recorded source (Unknown, experiment E6 in
  `docs/forever-auction-house.md`); do not tell players it as fact. Undercut mode (goblin switch)
  goes one step below. Undercut mode always starts off.
- Tables sort by column number (`listing:SetSort(2, 8)`; the last number is the main sort). Adding
  a column shifts the numbers after it: update every `SetSort` of that table (0.7, a test checks
  the main sort of each tab).
- Tabs by number: Search 1, Sniper 2, Post 3, Auctions 4, Bids 5. A test that switches to the wrong
  number passes for the wrong reason (this hid a Post tab error in 0.5).
- Leaving the Post tab clears `selected_item` (its `CLOSE`): read what you need from it before
  `aux.set_tab`.
- `aux.split` only works with one-character separators.
- `GameTooltip:AddDoubleLine` takes six color numbers; passing a color object's four values colors
  the right side wrongly, and leaving them out makes it the game's gold.
- `gui.label` is one line by default; call `SetWordWrap(true)` for messages that can be longer.
- Blizzard's auction house window stays open but invisible under aux. Anything that puts an item
  into Blizzard's Sell tab (a right-click on a bag item) locks that item (`C_Item.LockItem`);
  `AuctionHouseFrame:ClearPostItem()` releases it.
- Blizzard's own UI source for Forever is on GitHub: branch `forever` of `Gethe/wow-ui-source`
  (clone with `--filter=blob:none --no-checkout`, then check out single files). Read it before
  guessing how a Blizzard frame behaves.
- Filter Builder: write `and`/`or` with a count (`and2`); a bare `and` takes everything after it.
  The builder and the search bar stay in sync both ways; `loading` and `syncing` flags in
  `tabs/search/filter.lua` stop them from feeding back into each other.

## Design language

Since 0.6 there are two looks, picked in Settings (account-wide, `account_data.theme`) and applied
at the next login or `/reload` (Tyler, 2026-10-08: keep the 0.5 look as an option, move forward with
webster's). Both share one layout; only colors and shapes differ.

- **New** (the default): webster's UI Kit, Paper file "auxForever Screens" (pages "UI
  Kit" and "New"). Near-black surfaces with black 1px edges and square corners, raised controls
  lighter at the top (`gui.add_sheen`), sunken tables and inputs with a gray edge, one gold accent
  (`229, 190, 91`), zebra rows in dark gray. Its blacks are a little lighter than the kit's so text
  boxes stand out (Tyler, 2026-10-08).
- **Classic**: the 0.5 look. Dark slate panels, warm off-white text, amber accent
  (`227, 164, 59`), rounded corners (`textures/corner-*.tga`), flat buttons.

Rules for both looks (each one has caused a bug or would):
- Colors come from `color.lua` (`PALETTES.new` and `PALETTES.classic` name the same colors; a test
  checks it). Add a new color to both. Never write color numbers in a tab file.
- Buttons get a look with `gui.apply_look` (`default`, `primary`, `selected`, `choice`,
  `choice_on`, `tab`, `menu`, `confirm`; `gui/core.lua` has a table per look), not hand-set colors.
- The look is only known once the saved settings load, after every file has built its widgets. So
  a color set while a file loads must go through `gui.themed(function() ... end)` (or
  `gui.text_color`, `gui.texture_color`, `gui.vertex_color`): Classic paints those again at login.
  A plain `label:SetTextColor(aux.color.x())` at load stays in New's colors under Classic. Colors
  set later (in an update or a click) need nothing special. Colored text made once at load (like
  `TIME_LEFT_STRINGS`) goes in `gui.themed` too.
- Run the tests in both looks: `lua5.1 ../tests/load_test.lua` and `lua5.1 ../tests/load_test.lua
  classic` (GitHub Actions runs both). In game, check every change in New; Classic gets one short
  pass per version (open each tab).

Money coming in is green (`positive`), going out red (`negative`). Money always shows its coin
letters in their colors (gold `g`, silver `s`, copper `c`, from `money.to_string`), wherever a player
reads it: tables, buttons, labels, the recipe line (Tyler, 0.6). To tint a price, pass the color as
`money.to_string`'s fourth argument (it colors the numbers only); never wrap the whole text in one
color or use the no-color form, except for the raw text of a typing field and search text. In
player-facing text the two looks are called themes (Tyler, 0.6). Keep new screens in this style.
Direction (Tyler,
2026-10-07): auxForever should resemble TSM and the original aux, not Blizzard's auction house or
Auctionator; a player request to move toward the traditional layout was rejected
(`docs/feedback.md`, FB-004). Mockups so far were made
as interactive HTML pages; an HTML file Tyler can open in a browser works the same way.

## Where to find more

- `docs/status.md`: current state, decisions, open items. Keep it up to date.
- `docs/feedback.md`: every piece of player feedback, one numbered entry each (FB-001, ...),
  with the player's exact words and its status. Check it before planning a version; update an
  entry's status when you fix or build it.
- `docs/clicks.md`: every click and modifier click in the addon, and the click standard for 0.5.
  Check it before adding or changing a click.
- `docs/price-data.md`: where aux keeps prices (price history, the "usual price"), how they are
  recorded and used, and their known weak points.
- `docs/changelog.md`: what changed in each version; add an entry when the version number changes.
  List every change with a little detail (what changed and why it matters to a player), grouped
  by area, plus fixes and anything the player must do to update (Tyler, 2026-10-09: never "minor
  bug fixes" without saying which). It is also the CurseForge file's changelog.
- `docs/roadmap.md`: what each version is for. A patch version (0.3.x) is bug fixes, speed and
  small things only, no new features; new features go into the next minor version (0.4).
  Version numbers (Tyler, 2026-10-09): a bug fix raises the fourth number (0.6 -> 0.6.0.1 ->
  0.6.0.2); a bigger update within the same version raises the third (0.6.1); new features are
  the next minor version (0.7).
- `docs/forever-auction-house.md`: how Forever's auction house works, with sources.
- `docs/audit-classic-code.md`: the 2026-10-11 pass over code carried over from Classic aux (FB-010
  follow-up): what was checked, findings, open questions.
- `TESTING.md`: the current build's in-game checklist and the 5-minute check before every release
  (six steps at most, Tyler's limit).
  `docs/testing-history.md`: the older detailed checklists, by section number.
- `README.md`: credit, license, install. License: MIT for the changes made here; Simon's original
  code has no license and is used with his permission. CurseForge uses "All Rights Reserved".
- `git log`: every change with its reason. The first commit is the unmodified upstream aux, so
  `git diff <first commit>` shows everything changed for Forever.
