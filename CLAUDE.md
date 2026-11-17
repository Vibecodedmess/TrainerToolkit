# Trainer Toolkit: handover for Claude Code sessions

Personal-use iOS companion app for Pokémon GO. It is sideloaded with Sideloadly (free Apple ID) and never published.
The full original brief lives with the user. This file holds what a new session needs to continue.

## Hard rules (from the user, never break)

1. **No game account access, ever.** No Niantic login, no unofficial game APIs, no reading data from the game app, no automation. Data comes only from public community feeds or from what the user types or imports.
2. **Never invent game data.** Base stats, moves, CP multipliers, costs, raid bosses, Rocket lineups, event details and so on must come from a data source or a cited table. If a value is unsure, mark it `TODO: verify` in code **and tell the user**. Tests must not hard-code remembered game values: compute them from the bundled data, or use clearly made-up fixtures.
3. **No official artwork.** No sprites or logos, and never load the feeds' `image` URLs (the decoders skip them). Use text, type badges and SF Symbols. No "Pokémon" in the app name or icon.
4. **No backend, accounts or analytics.** All data stays on the device.
5. **Be polite to sources.** Cache, refresh every few hours at most (default 6 h), at most one request per source per 5 minutes, and use ETags.

Also:
- Swift / SwiftUI / SwiftData, iOS 17, Swift 5 language mode.
- No third-party dependencies without asking. XcodeGen is a build-time tool only.
- Dark mode and Dynamic Type supported.
- Unit tests for all game math.

## Working agreement

- **Phases:** stop after each phase or feature. Tell the user what changed, how to install, a phone test checklist, and any `TODO: verify` items. Wait for their test result before starting the next one; they pick what comes next.
- **Git:** commit or push only with the user's OK. The user usually answers "Push and build". Commits end with the `Co-Authored-By` line the session gives.
- **The user has no Mac.** The only compiler is GitHub Actions on the public repo `Vibecodedmess/TrainerToolkit`, using the workflow `.github/workflows/build.yml`.
  - It runs on `runs-on: macos-15-intel` (since 2026-11-11). If a job sits "Queued" for 15 minutes and fails with "not acquired by Runner", that pool is out of capacity, not the code. Switch between `macos-15` (Apple silicon) and `macos-15-intel`, which needs a commit, so ask the user. Both pools ran out of capacity at times on 2026-11-10 and 2026-11-11.
  - The runner is only the build machine. The IPA for the iPhone is identical either way.
  - The workflow only runs on demand (`workflow_dispatch`) or on `v*` tags. Start it in the **built-in browser pane**: Actions > Build unsigned IPA > Run workflow > Run workflow. There is no `gh` CLI here.
  - **The user signs in to GitHub themselves.** Never type a password. If the Run workflow button is missing, the pane has been signed out: open github.com/login and ask the user to sign in.
  - Check results on the run page in the browser. The anonymous GitHub API allows only 60 requests an hour, so don't poll it.
  - **Downloading the IPA:** navigate to the artifact URL `/actions/runs/<run>/artifacts/<id>`. It often needs a **second** navigate before the zip lands in `%USERPROFILE%\Downloads`. Unzip to `%USERPROFILE%\Downloads\TrainerToolkit-buildN\TrainerToolkit.ipa`, delete the zip, and send the IPA to the user. Ask the user before downloading.
- **Git identity** for this repo: the GitHub noreply address, set in the repo's local git config. Never use the user's private email in commits.
- **Windows machine:** no Swift, Python or jq. Use PowerShell 7 or Git Bash. In PowerShell, `CP` is an alias for Copy-Item, so don't name a function that.
- `samples/` and `*.csv` are gitignored (private collection data). `icon-source.*` is gitignored too.

## Phase status

| Phase | What | Status |
| --- | --- | --- |
| 0 | Skeleton, tab bar, CI, INSTALL.md | Confirmed on phone. Data survives install-over (verified) |
| 1 | Data layer (fetch, cache, snapshots, Data sources screen) | Confirmed |
| 2 | Search String Builder (+ app icon from the user's own image) | Confirmed. All 4 previously unverified terms confirmed in game |
| 3 | Candy & Stardust Planner (GameMath CP/costs) | Confirmed |
| 4 | Events, checklist, local reminders | Confirmed |
| 5 | My Collection: manual entry (5a) + CSV import in the app's **own** format (5b) | CP-box bug found on build #14 and fixed (`8e90321`). **CSV import untested**: the user has no CSV of their own Pokémon (2026-11-12). Don't make test CSVs; the user declined one |
| 6 | Raid Counter Picker | Confirmed on build #16 (2026-11-12) |
| 7 | Team Rocket Counter Sheet | Confirmed on build #16 |
| 8 | Trade Planner | Confirmed on build #16 |
| 9 | Home tab + polish, final README | Home confirmed on build #16. User: "a simple, pleasant app" |
| 10 | Add to Collection from screenshots (like Poke Genie) | Confirmed on build #18 (2026-11-12), including lucky, and the Shiny switch the user chose (the game's shiny mark isn't readable). See "Screenshot import" |
| 11 | Bulk screenshot import (many Pokémon at once) | Confirmed on build #19 (2026-11-12) |
| 12 | Evolution requirements in My Collection (items, lures, quests, buddy, time, gender) + how to get each item | Confirmed on build #20 (2026-11-12). See DATA_SOURCES.md "evolution requirements" |
| 13 | Collection power-ups: one-tap Planner goal + raid rank by level (and evolved) vs your other counters | Confirmed on build #21 (2026-11-12). `Counters/PowerUpValue.swift`, `Features/Collection/PowerUpValueView.swift` |
| 14 | Raid "trainers needed" estimate (community tier table, unverified) | Confirmed on build #23 (2026-11-12) |
| 15 | Backup and restore (iCloud Drive via Files; automatic daily backups to a chosen folder) | Confirmed on build #23 (2026-11-12; user asked for it because free sideloads expire weekly). See "Backup" |
| 16 | Visual polish, "concept A: polished native" (user's pick of 3 concepts) | Confirmed on build #25 (2026-11-12; user: "this looks very nice"). See "Look and feel" |
| 17 | Rocket lines (what each member says) shown and searchable; Rocket replaces Raids in the tab bar, Raids moves to More | Confirmed on build #27 (2026-11-16) |
| 18 | Screenshot import: at least 2 screenshots per Pokémon (misreads merged, majority vote); level/IVs from "L30 80% 12/12/12" nicknames; new app icon | Confirmed on build #29 (2026-11-16; user: "works pretty good") |
| 19 | Screenshot thumbnails on unsure Pokémon (and in the review, tap to enlarge); ★ on each species' best raid/gym moves | Confirmed on build #30 (2026-11-16). Elite moves now show "(Elite)" in the editor instead of ★ |
| 20 | More > Looks: pick Standard, Floating dock, Widget board or Timeline (concepts 6, 7, 8) | Confirmed on build #33 (2026-11-17). See "Looks" |
| 21 | Three more looks: Terminal (17), Alien signal (21), Terminal, alien edition (22), with an original moving alien background | Build #32 had the custom tab bars covering list bottoms and looks only on Home; fixed (bar below the screens, looks app-wide) and confirmed on build #33 (2026-11-17; user: "looks great!"). See "Looks" |
| 22 | Recommended (power-ups, events, raids) in More and on every Home look; all open `TODO: verify` items confirmed by the user | Confirmed on build #34 (2026-11-17; user: "Recommended works good!"). See "Recommended" |
| 23 | Home Screen widget: Community Day countdown and top raid bosses (small, medium, Lock Screen), fetching the feeds itself | Confirmed on build #35 (2026-11-17; user: "Widget works!"). See "Widget" |
| 24 | Widget styles (Standard, Alien signal, Terminal) picked in the widget's own settings; the alien scene moves a step every minute | Confirmed on build #36 (2026-11-17; user: "almost perfect"). See "Widget" |
| 25 | Widget style "Terminal, alien edition" (the user's favourite look): terminal on a see-through panel over the dimmed moving scene | Build #37 showed no movement in the alien styles; fixed (scene moved into the content layer, bigger poses, live ticking countdown and signal sweep) and confirmed on build #38 (2026-11-17; user: "works!"). See "Widget" |
| 26 | Review fixes (user asked for a whole-app review, 2026-11-17): (1) generic counters tried elite/legacy *charged* moves as fast moves (PvPoke's `eliteMoves`/`legacyMoves` mix both kinds and are already in `fastMoves`/`chargedMoves`), which inflated e.g. Mewtwo; `DamageCalculator.evaluate` now rejects the wrong kind of move. (2) If the store falls back to in-memory, automatic backups are skipped and Home shows `AppModelContainer.fallbackWarning`. (3) Reminders are re-synced after each foreground refresh too | Confirmed on build #39 (2026-11-17; user: "all works") |
| 27 | Expiry warning (user's pick, 2026-11-17): `InstallInfo.signingExpiry` reads `ExpirationDate` from the app's `embedded.mobileprovision` (Sideloadly's profile, 7 days on a free Apple ID). More > Settings shows "Signed until"; Home's banner warns 2 days before (`InstallInfo.expiryWarning`); `ReminderScheduler` schedules one notification (id `app.expiry`) a day before, only if notifications are already allowed. Bundled snapshots refreshed the same day | Built 2026-11-17, not yet on the phone |

## Current state (update this section as work continues)

- **As of 2026-11-17:** Phases 0–26 are confirmed on the phone (latest: build #39), except the CSV import (untested, the user has no CSV). Phase 27 (expiry warning) is built. The user's favourite look is Terminal, alien edition.
- **Tabs (user's choice, 2026-11-13):** Home, Search, **Rocket**, Events, More. Raids lives under More > Raids, and Home's tile shows the raid boss count instead of the Rocket count. `RaidsView` has no `NavigationStack` of its own (it's pushed); the Rocket tab wraps `RocketView` in one.
- **Rocket lines:** `Counters/RocketQuotes.swift` + `rocket-quotes.json` (the game's own text, see DATA_SOURCES.md). The list shows each lineup's line, the search (`RocketQuotes.matches`, punctuation- and accent-insensitive) covers lines, names, types and Pokémon, and the lineup screen shows the line at the top.
- **Look and feel (Phase 16, user's choices):**
  - The user picked "polished native" over a card dashboard and a dark HUD. They explicitly did **not** want separate ATK/DEF/HP stat bars: keep the layout as it is.
  - **Stats line everywhere:** `CP 1234 · L25 · 10/12/14 · 80%` (made-up example), IVs as Attack/Defense/HP. Use `PokemonStats.line` / `StatsLineText` in `Shared/Theme.swift`; don't hand-build it.
  - `Shared/Theme.swift` also has `AppTheme` (accent from `AccentColor.colorset`, type colour of a Pokémon), `MeterBar` (IV % or relative strength, in the type colour), `TypeStrip` (leading colour strip on raid/Rocket rows) and `InfoTile` (Home tiles).
  - Home: 2×2 tiles (collection, goals, raid bosses (was Rocket until 2026-11-13), backup) using `navigationDestination(item:)`, then a tinted Community Day card, live events, the top raid tier and the next goals.
  - Counter bars take the colour of the attack's type (charged move, else fast move).
  - **Shared helpers, use them instead of repeating code:** `FlagIcons` (shiny/shadow/purified/lucky/mine icons), `CollectedPokemon.duplicateKey` and `makeDuplicateKey` (import duplicate checks), and `GMPokemon.stats` (PvPoke base stats as GameMath `BaseStats`; defined once in the app and once in the Counters package).
- **Code cleanup (2026-11-12, user asked):** removed unused code (`PlaceholderView` and three unused members), merged the duplicated icon, duplicate-key and base-stats code into the helpers above, and fixed stale wording in README, INSTALL.md and comments. No behaviour change intended, except that the lucky icon is now the same star everywhere.
- **Maintenance (2026-11-12, user's choice):**
  - Snapshots refreshed.
  - PokeMiners pins checked: still the latest commits.
  - CI writes a "Compiler warnings" summary on each run page. Build #24 (`3c146c8`) had 0 warnings and was green.
- **No open feature ideas.** The user is **not interested in PvP** (declined PvP league IV ranks on 2026-11-12): do not suggest PvP features again. Wait for the user to name what they want next.
- **Open `TODO: verify` items: none.** On 2026-11-17 the user confirmed all of them in game: shadow/purified/lucky cost rounding; the Trade Planner's cost rounding, trade kind → `unlockedTrading` mapping, attack bonus as a multiplier, category names and "Level N" friendship levels; the Bulbapedia raid tier numbers (including the 3-star Shadow time limit); and the Pokémon GO Wiki "how to get" texts. Code, JSON notes, in-app footers and DATA_SOURCES.md now say "checked against the game on 17 November 2026"; the source credits stay (licences require them). New unsure values still get `TODO: verify`.
- **CI tips:**
  - Build times vary from 4 to 10 minutes.
  - Read results on the run page, including the warnings summary.
  - Artifact downloads sometimes land in Downloads as random `*.tmp` files instead of `TrainerToolkit-ipa-N.zip`. Check each candidate is a zip containing `TrainerToolkit.ipa`, then use it and delete the leftovers.

## Recommended (Phase 22): how it works

- User's request (2026-11-17): recommend Pokémon to upgrade, events to join "with what rewards", and bosses to clear.
- Logic in `Packages/TrainerKit/Sources/Counters/Recommender.swift` (tests in `RecommenderTests`, bundled data and made-up events only); screen in `Features/Recommended/RecommendedView.swift`, computed off the main thread.
  - **Power-ups:** My Collection entries with a fast move (`CounterPools.mine`). Each is taken to its next level step (`nextTarget`: next of 40/45/50) while the others stay put; picked when that gets it into the best 6 (`joinsTeam`) or makes it #1 (`becomesBest`) against a current raid boss. Needs more than 6 counters. Row links to `PowerUpValueView`; cost from `PowerUpCalculator`.
  - **Events:** live, or starting within 7 days. Reasons only from the feed (`EventExtras`): featured Pokémon in a goal's family (`GMPokemon.family`), Pokémon not in the collection (by dex), shinies, bonuses (incl. spotlight bonus), Special Research rewards. Events with no reason are left out.
  - **Raids:** `RaidEstimate` trainers needed with the user's best 6 (easiest first; not-estimated tiers last), top 3 counters, "you don't have it" and shiny flags.
- Entry points: More > Tools > Recommended, and one link on every Home look (`HomeView.Destination.recommended`).

## Widget (Phase 23): how it works

- `Widget/TrainerWidget.swift`, XcodeGen target `TrainerToolkitWidget` (app extension, bundle id `$(APP_BUNDLE_ID).widget`, Info.plist generated to `Config/Widget-Info.plist`, gitignored), embedded in the app's `PlugIns`. CI fails if the `.appex` is missing.
- Its own `DataStore` in its Caches folder with `sources: [.events, .raids]` (the `sources` parameter was added for this, so the widget never parses the 940 KB game master). Bundled snapshot first, `refreshIfStale(maxAge: 6 h)`.
- Timeline: one entry; next update when the Community Day starts or ends, else after 6 h. Countdown uses `Text(date, style: .relative)`, which ticks by itself.
- Families: small (Community Day), medium (plus the top raid tier, up to 4 bosses), accessoryRectangular (Lock Screen). Indigo tint; it can't know the app's look (no App Group).
- `SDRaidBoss.tiersInDisplayOrder` (DataSources) is the raid tier order shared by the app (`RaidsView.tiers`) and the widget.
- **Styles (Phase 24, user asked for the alien scene "animated" in the widget):** `AppIntentConfiguration` with `WidgetStyleIntent` (`WidgetStyle`: standard, alien, terminal, alienTerminal; `isAlien` = gets the per-minute poses), picked via touch and hold > Edit Widget. The widget can't see the app's look (no App Group). `Widget/WidgetStyles.swift`:
  - `AlienWidgetScene`: the app's alien scene rebuilt from SwiftUI shapes (same colours/layout as `Shared/AlienBackground.swift`; keep them in step). **Widgets can't animate continuously**: the alien style's timeline has one entry per minute for an hour (`WidgetData.alienSteps`), each a pose (`step` = minutes since reference date), and iOS animates between poses (`.animation(.smooth(duration: 1.8), value: step)`): rings turn, orbs bob, stars twinkle, the saucer crosses in 12 hops (hidden at both ends). Reduce Motion: one fixed pose. Data is still only downloaded when older than 6 h.
  - `AlienWidgetContent` (outlined rounded text, white stickers) and `TerminalWidgetContent` (green monospaced, `$ cd --next`, `$ raids --top`). Alien terminal (Phase 25): `TerminalWidgetContent(onAlienScene: true)` on a 62% black panel with a green border, over `AlienWidgetScene(dimmed: true)` (dark sky, shapes at 60%, like the app's `AlienBackground(dimmed: true)`).
  - The Lock Screen size ignores the style (iOS tints it).
  - **Movement fix (after build #37, user: "it doesn't move"):** the moving shapes now sit in the widget's *content* (a `ZStack` under the text), not its `containerBackground` (which now only holds the still `AlienWidgetSky`). The configuration uses `.contentMarginsDisabled()`, and every style pads its text with `@Environment(\.widgetContentMargins)`. Poses are bigger (rings 30°/−20° a step, saucer crosses in 6 hops, orbs bob 10 pt). Live elements iOS updates by itself: `LiveTimer` (`Text(timerInterval:countsDown:)`, ticks every second) in the alien sticker and the terminal (`T-52:14:09`), and a `ProgressView(timerInterval:)` "signal sweep" filling across the bottom of the scene each minute (hidden with Reduce Motion). Confirmed working on build #38.

## Widget research (2026-11-17)

- The user asked to look into a Home Screen widget.
- **App Groups are the problem:** with a free Apple ID, Sideloadly either renames the App Group to a team-unique id or doesn't provision it at all (reports differ; a widget that needs it can crash at launch). So the widget **can't rely on reading the app's data** (collection, goals, Recommended).
- **Workable plan:** a WidgetKit extension that fetches the public ScrapedDuck events/raids feeds itself (same politeness rules: cache, every few hours, ETags) and shows the Community Day countdown and current raid bosses as text. No App Group needed. Each extension needs its own App ID on the free account (10 new App IDs per 7 days). If an install fails, Sideloadly's advanced option to remove app extensions gets the app back without the widget.
- **Approved and built (2026-11-17)** after the user confirmed build #34. See "Widget" above.

## Looks (Phase 20): how they work

- **How it came about (2026-11-16):** the user asked for bigger design changes. They were shown 5 cosmetic options (1–5), asked for bolder ones, were shown 6–10, and chose to have 6, 7 and 8 selectable under More > Looks. Not chosen: 1–5, 9 (field notebook), 10 (retro handheld).
- **More looks (2026-11-17):** the user then asked for 10 "way more extreme" concepts (11–20; at least 3 in the chunky cartoon game style of a game player card they showed), liked 17 (Terminal), and asked for a moving background like one from that game. They got 21 and 22 with an **original** animated scene instead: don't copy another game's art or animation, even from a video the user links. They chose 17, 21 and 22. Not chosen: 11–16, 18–20.
- `Shared/AppLook.swift`: `AppLook` (`standard`, `dock`, `widgets`, `timeline`, `terminal`, `alien`, `alienTerminal`), stored in `@AppStorage("app.look")`. It's a display preference, so it's **not** in `BackupManager.settingsKeys`. `tint` and `colorScheme`: the terminal looks force dark mode and a green tint app-wide.
- Every look shows the same data: `HomeSnapshot` in `Features/Home/HomeShared.swift`, built once a minute in `HomeView`. `HomeView` owns the navigation (`Destination`), pull to refresh, the warning banner and the screenshot-import sheet, then switches on the look:
  - `StandardHome` (in `HomeView.swift`): the Phase 16 list, unchanged.
  - `DockHome.swift` (look 6): greeting, accent countdown card, round quick buttons (Collection, Goals, Raids, Scan), live events side by side, top raid tier, goals. Hides its own navigation bar.
  - `WidgetBoardHome.swift` (look 7): mixed-size widgets; titled "Today".
  - `TimelineHome.swift` (look 8): Today / This week switch (`home.timeline.week`), dots on a line, round scan button.
  - `TerminalHome.swift` (looks 17 and 22): `TerminalStyle`, the command-line Home (every line that leads somewhere is tappable, blinking cursor) and `TerminalTabBar` ("[1]home [2]srch ..."). With `alien: true` it sits on a dark panel over `AlienBackground(dimmed: true)`.
  - `AlienHome.swift` (look 21): `Chunky` (colours; font is SF Rounded Black, so no bundled font), `ChunkyOutline`, `ChunkyButtonStyle`, the sticker-style Home and `AlienTabBar`.
- **Alien background:** `Shared/AlienBackground.swift`, drawn with `TimelineView(.animation)` + `Canvas` at 30 fps: rings, orbs, stars, planet, saucer. No artwork, no video. It stands still with Reduce Motion and pauses when not on screen (`onAppear`/`onDisappear`, the `isActiveTab` environment value, scene phase).
- **Looks are app-wide (user's request, 2026-11-17):**
  - `RootTabView` sets `tint`, `fontDesign`, `fontWeight` and `preferredColorScheme` from the look for the whole app (sheets too). It also calls `LookAppearance.apply` (UIKit `UINavigationBar` appearance: black/green monospaced for terminal, lime with dark rounded titles for alien) and `.id(look)` so every tab is rebuilt with the new bar style.
  - **Every screen** has `.lookScreen()` right after its `.navigationTitle` (`Shared/LookScreen.swift`): hidden list background plus black or the alien scene behind it. **New screens must add it too.**
  - Alien signal is forced light (lists read as white stickers on the green scene); the terminal looks are forced dark. Widget board uses rounded text everywhere.
- **Custom tab bars:** `App/CustomTabView.swift`. `CustomTabView` keeps all five tab screens alive in a `ZStack` (only the selected one is visible, others get `isActiveTab = false`), with the look's bar (`FloatingDock`, `TerminalTabBar`, `AlienTabBar`) **below** it in a `VStack`. Not a safe-area inset or overlay: a bottom inset doesn't reach lists inside a NavigationStack, so on build #32 the bar covered the bottom of lists. The bar hides while the keyboard is up.
- **The user's screen recordings are HEVC `.MP4`**, which this PC can't decode (no ffmpeg, no HEVC codec; `MediaComposition.GetThumbnailAsync` fails with 0xC00D5212). Ask for screenshots instead. Chosen over hiding the system tab bar, which comes back on pushed screens. `AppTab` (in `RootTabView.swift`) holds each tab's title, icon and screen for both containers.
- Switching between looks with different tab containers rebuilds the tabs, so the More tab goes back to its first screen.

## Collection extras (Phases 12–13): how they work

- **Evolution:** see "Decisions already made" and DATA_SOURCES.md.
- **Power-up value:**
  - `PowerUpValue.evaluate` ranks the Pokémon at its current level and at 40/45/50 (up to the max upgrade level). It compares against the other collection entries, which stay at their own levels.
  - The boss is chosen from the current raids. There's an optional evolved form (regular moves only, same IVs).
  - Costs come from `PowerUpCalculator`, with shadow/purified/lucky.
  - A Pokémon without a saved fast move uses its species' regular moves, and the screen says so.
  - Planner hook: `GoalEditorView(prefilled:)` with `GoalDraft(collected:types:target:)`.

## Decisions already made

- **Data sources** (details in DATA_SOURCES.md):
  - PvPoke `gamemaster.min.json` (MIT): Pokémon and PvP moves.
  - ScrapedDuck `events`/`raids`/`research`/`rocketLineups` `.min.json`: must credit ScrapedDuck and LeekDuck, no paywall, no ads.
  - The Niantic help article #1486 for the search terms.
  - The **PokeMiners game master** (approved by the user) for:
    - level tables (CP multipliers, power-up costs)
    - battle tables (type chart, weather, multipliers, PvE moves)
  - PokeMiners data is extracted with `scripts/update-level-tables.ps1` and pinned to commit `8e227be`.
- **Community Day** exclusive move and evolve deadline are **not in any feed**, so the user types them in. The app shows PvPoke elite moves only as hints.
- **Collection CSV:** Poke Genie's export needs a subscription, so the user chose the **app's own format** (COLLECTION_IMPORT.md, `CollectionImport/CollectionCSV.swift`). Don't write importers for other apps without a real sample file from the user.
- **Shadow/purified/lucky cost rounding** is `TODO: verify`: rounded up per power-up, and lucky + purified stack.
- **Evolution data (2026-11-12):**
  - Requirements and the official item and quest names come from PokeMiners: the game master, plus the game's English text in `pogo_assets` (pinned `db10df7`, approved by the user). Extracted by `scripts/update-evolution-tables.ps1`.
  - **How to get an item** is community info from the Pokémon GO Wiki (CC BY-SA), cited and labelled unverified in the app. The user chose this over game text only. It's a hand-written paraphrase in `evolution-items-community.json`, and a test checks it covers exactly the items in the data.
  - App: `Features/Collection/EvolutionSection.swift`, shown in the collection editor plus an "Evolves with …" line in list rows. Species ids are mapped game master → PvPoke in `EvolutionTables.speciesKey` (`_ALOLA` → `_alolan` and so on). Cosmetic forms are filed under the plain species.

## Screenshot import (Phase 10): how it works

- The user OK'd importing their own screenshots (2026-11-12): it's user-chosen data, like a CSV. No overlay, no screen recording, no automation. The game is in **English**.
- `Packages/TrainerKit/Sources/ScreenshotImport/`:
  - `ScreenshotParser`: reads recognised text lines (top-left normalised boxes): CP, "x / y HP", name above the HP line, "<FAMILY> CANDY", type labels, the POWER UP row's stardust and candy, move lines under "GYMS & RAIDS", PURIFY (shadow), LUCKY, and the appraisal labels.
  - `AppraisalBars`: bar fill from pixel rows. Saturated = filled, light grey = empty, white gaps ≤ 12 px are segment dividers. A bar must start within 2 label-heights of the scan start. IV = fill × 15.
  - `IVSolver`: every half level × IV combination, matched to CP, HP and the next power-up's stardust (`PowerUpCalculator`), narrowed by the bar IVs (±1).
  - `ScreenshotImporter`: species from the name (all forms with that base name), else the candy family's evolution line, filtered by type labels. It retries as lucky, then without the stardust.
- App: `Features/Collection/ScreenshotReader.swift` (Vision `VNRecognizeTextRequest`, `.accurate`, en-US, no language correction; scans rows from the label's bottom to 1.6 label-heights below), `ScreenshotImportView.swift` (PhotosPicker, up to 40 images, one row per Pokémon found, "Save the N sure Pokémon"; a row shows a green check once a matching entry is in the collection) and `ScreenshotReviewView.swift` (what was read, species/level/IV choice, Shiny switch, then the editor via `CollectionEditorView(prefilled:)`).
- **Bulk import (2026-11-12, user's choice of next step):** `ScreenshotGrouping` splits a batch per Pokémon. Screenshots stay in picked order, and a new group starts when CP, max HP, name or candy family differs. Scrolled screenshots are matched by the name at the top. `Proposal.certainChoice` means one species and one level/IV option, or all 3 bars read and exactly one option matching them; only those are saved in bulk (shiny off, moves as read).
- **At least 2 screenshots per Pokémon (2026-11-16, the user's way of working):** `ScreenshotGrouping.minimumPerPokemon = 2`.
  - A group of one is treated as a misread. It joins the neighbouring group it disagrees with least, the one before it on a tie (`mergeSmallGroups`).
  - `ScreenshotGrouping.combine` decides CP, HP, name and candy by majority over the group's screenshots.
  - Bulk "Save the sure ones" skips groups with fewer than 2 screenshots. Their row says "Add its appraisal".
- **How the user adds Pokémon (examples in `samples/`, 2026-11-16):**
  - Two screenshots per Pokémon: the top of its screen, then scrolled down to the moves. **No appraisal.**
  - Their Pokémon are **nicknamed like "L30 80% 12/12/12"** (the IV tool's format). The species therefore comes from the candy name plus the type labels.
  - Without the nickname, 2–4 level/IV combinations fit each example, and a CP partly hidden behind the Pokémon may not be readable.
- **Nickname reading (user's choice, 2026-11-16):**
  - `NicknameStats.parse` reads the nickname, only in the name position: the nearest line above the HP line, or a centred line near the top on scrolled screenshots. Never the IV tool's label at the top right.
  - `ScreenshotImporter.solve` checks it first: its level and IVs must give the HP and the power-up stardust (each when read).
  - If the CP fits too, it's `.matched`. If the CP is missing or differs and the HP was read, it's `.usedWithoutCP` (a likely misread). Otherwise it's `.ignored`, and the usual solving runs.
  - Grouping compares nicknames and votes on them like CP and HP.
  - On the samples, the CP/HP/stardust math agrees with each nickname.
- Checked on the user's real screenshots (in `samples/`, gitignored, **never commit them or their values**): the CP/HP/stardust math and the bar measurement give the right level and IVs for both sample Pokémon. Their screenshots also show a third-party IV overlay (a dark "level, IV %, IVs" label at the top right); the app does **not** read it.
- Not verified until it runs on a phone: what Vision actually returns for these screens (line splitting, the CP font, the "Attack/Defense/HP" label boxes).
- **Shiny is not detected.** In the user's shiny screenshots the only sparkles belong to their IV tool (its label and side panel) or the Pokémon's animation; the game's own mark wasn't visible. The user chose a **Shiny switch on the import screen** (2026-11-12) over reading the tool's marker. Don't read the third-party overlay.

## Backup (Phase 15): how it works

- **No CloudKit:** free-signed sideloaded apps get no iCloud container entitlement. iCloud Drive is reached through the Files picker instead: `fileExporter`/`fileImporter`, plus a security-scoped **folder bookmark** for automatic backups.
- **Format:** `Packages/TrainerKit/Sources/BackupFormat/AppBackup.swift`, versioned JSON (`format: "trainer-toolkit-backup"`, `version`, ISO 8601 dates). It holds every SwiftData model and the user-entered settings in `BackupManager.settingsKeys` (base trade costs, refresh interval). A newer version is refused with a clear message.
- **App side:**
  - `Persistence/BackupManager.swift` does the snapshot and the restore (delete all, then insert). Before a restore it saves an **undo copy** at `Application Support/Backups/before-last-restore.json`.
  - Automatic backup runs when the app becomes active, at most every 24 h, with coordinated writes. It keeps the newest 14 `TrainerToolkit-backup-*.json` files and never touches other files.
  - `Features/Settings/BackupView.swift` (More > Backup), plus a Home row that turns orange after 7 days without a backup.
- **When adding a new @Model or a user-entered setting,** add it to `AppBackup`, `BackupManager.snapshot` and `BackupManager.restore`. Bump `AppBackup.currentVersion` only when old backups can't be read as they are.

## Raids and Rocket (Phases 6–7): how they work

- `Packages/TrainerKit/Sources/Counters/CounterRanker.swift`: generic candidate pool (released PvPoke species, toggles for shadow, mega, elite/legacy moves), ranking by best-moveset DPS (`DamageCalculator`), `rankAgainstAll` (average relative DPS over several defenders, used per Rocket slot), weaknesses/resistances, and feed-name matching ("Mega Charizard X" → "Charizard (Mega X)", "Primal Kyogre" → "Kyogre (Primal)").
- Defenders (raid bosses, Rocket Pokémon) are modelled at **level 40, 15/15/15** because their real stats are server-side. Only **relative** DPS (% of the best counter) is shown, never absolute DPS. Rocket Pokémon are treated as shadow (shadow defence multiplier).
- **Trainers needed (2026-11-12, user's choice):** a best-case estimate on each raid boss screen, under the party. It uses a cited community table from Bulbapedia (`Counters/Resources/raid-tiers.json`, CC BY-NC-SA, `TODO: verify`) for boss HP, multiplier and time limit. The game master has none of these. Shadow and Super Mega raids show no estimate (enrage, shields). See DATA_SOURCES.md.
- App side: `Features/Counters/CounterSupport.swift` (shared settings, rows, method note; settings remembered in `@AppStorage` keys `counters.*`), `Features/Raids/*`, `Features/Rocket/*`. `DataCenter` now also loads `raids` and `rocketLineups`.
- Weather choices are the game master ids (`clear`, `overcast`, `partly_cloudy`, …), shown as text. The weather that boosts the boss's own types is marked.

## Where things are

- `App/`: app entry, tab bar (`RootTabView`, `CustomTabView`), `DataCenter` (feeds → decoded gamemaster, lookup, events)
- `Features/<Feature>/`: SwiftUI screens per feature
- `Widget/`: the Home Screen widget extension (see "Widget")
- `Persistence/`: SwiftData models (`AppModelContainer.schema` lists them all) and `BackupManager`
- `Packages/TrainerKit/`: pure Swift, tested with `swift test` on CI
  - `DataSources`: feeds, cache, `EventCalendar`, `EventExtras`, `GamemasterLookup`, snapshots
  - `GameMath`: level/battle/trade/evolution tables, CP, costs, `DamageCalculator`
  - `SearchBuilder`: `search-terms.json` and the query builder
  - `CollectionImport`: `CSVReader` and `CollectionCSV`
  - `Counters`: raid/Rocket counter rankings (`CounterRanker`), `PowerUpValue`, `RaidEstimate` + `raid-tiers.json`
  - `ScreenshotImport`: screenshot text parsing, appraisal bars, IV solver, grouping
  - `BackupFormat`: the backup file format
- `scripts/`:
  - `update-snapshots.sh`: bundled feed snapshots
  - `update-level-tables.ps1`: PokeMiners level and battle tables
  - `update-trade-tables.ps1`: friendship/trade tables
  - `update-evolution-tables.ps1`: evolution requirements and the game's English item/quest text
  - `update-rocket-quotes.ps1`: what Rocket members say (game text)
  - `make-app-icon.ps1`
- Docs: README.md, INSTALL.md, DATA_SOURCES.md, COLLECTION_IMPORT.md
