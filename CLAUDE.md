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

- **Phases:** stop after each phase. Tell the user what changed, how to install, a phone test checklist, and any `TODO: verify` items. Wait for "All passed" before starting the next phase.
- **Git:** commit or push only with the user's OK. The user usually answers "Push and build". Commits end with the `Co-Authored-By` line the session gives.
- **The user has no Mac.** The only compiler is GitHub Actions on the public repo `Vibecodedmess/TrainerToolkit`, using the workflow `.github/workflows/build.yml`.
  - It currently runs on `runs-on: macos-15-intel` (switched from `macos-15`, Apple silicon, on 2026-11-11). If a job sits "Queued" for 15 minutes and fails with "not acquired by Runner", that pool is out of capacity, not the code. Switch between `macos-15` and `macos-15-intel`, which needs a commit, so ask the user. The arm64 pool was full on 2026-11-10, the Intel pool on 2026-11-11, and arm64 again later on 2026-11-11 (build #12; GitHub's annotation names "capacity constraints" on macOS arm64).
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
| 10 | Add to Collection from screenshots (like Poke Genie) | Built 2026-11-12. **Not tested on the phone**. See "Screenshot import" |

## Current state (update this section as work continues)

- Last code commit: `9988d39`, Phases 6–9 (Raids, Rocket, Trades, Home, README). **Build #16 is green** (`macos-15-intel`): artifact `TrainerToolkit-ipa-16`, `/actions/runs/43040528767`.
  - Earlier on 2026-11-11: `a604f13` fixed the move-name lookup ("Seed Bomb" vs "Seed Bomb+"), and `8e90321` fixed the editor's CP box (build #15 green).
  - Builds #10–#12 were never acquired (no runner capacity); #13 failed on the Seed Bomb test.
- **Next steps:**
  1. The user installs build #16 and goes through the Phase 5 checklist below plus the Phases 6–9 checklist.
  2. Fix whatever fails. Then ask about the open raid decision (trainer estimate, see "Raids and Rocket").
- **Trade Planner `TODO: verify`** (tell the user): cost rounding (nearest stardust), the mapping of trade kinds to the game master's `unlockedTrading` ids, the attack bonus shown as a multiplier, and the readable category names. Friendship level names aren't in the data, so levels are shown as "Level N" with points.
- **Phases 6–9 phone test checklist:**
  - Home: live events, Community Day countdown, top raid tier rows open the boss screen, goals and collection links.
  - Raids tab: bosses grouped by tier, boss screen with Weak to / Resists, a party of 6 plus more counters. Changing the weather, level and toggles reranks. "My collection" uses your own Pokémon (they need a fast move). The settings are remembered.
  - More > Rocket: lineups grouped by role; each slot lists its Pokémon (tap to see the top 3 counters and weaknesses) and shows "Good against all of these". Works in airplane mode.
  - More > Trades: add a friend, want lists, base trade costs, cost check, Friendship levels screen.
  - Existing data (collection, goals, event checklists) survives installing over the old build (2 new SwiftData models were added).
- **Phase 5 phone test checklist** (give it to the user with the IPA):
  - Collection empty state.
  - Add a Pokémon manually: species picker, IVs, level or "Find level from CP", move pickers with ★ for elite moves, flags.
  - "Find level from CP": one matching level is applied as soon as the CP is typed. With several matches, Save stays disabled (orange hint) until one is picked or the box is cleared. Changing the level stepper clears the box. (Build #14 bug: a typed CP was dropped on Save unless "Use level" was tapped.)
  - The list shows CP, IV % and icons.
  - Search, the filter/sort menu (remembered), edit, and delete with confirmation.
  - Data persists after a force-close.
  - **+ > Import CSV:** share the template, fill one or two rows in a spreadsheet, export CSV, import. The preview shows warnings and duplicates, and bad rows are listed with line numbers.

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

## Screenshot import (Phase 10): how it works

- The user OK'd importing their own screenshots (2026-11-12): it's user-chosen data, like a CSV. No overlay, no screen recording, no automation. The game is in **English**.
- `Packages/TrainerKit/Sources/ScreenshotImport/`:
  - `ScreenshotParser`: reads recognised text lines (top-left normalised boxes): CP, "x / y HP", name above the HP line, "<FAMILY> CANDY", type labels, the POWER UP row's stardust and candy, move lines under "GYMS & RAIDS", PURIFY (shadow), LUCKY, and the appraisal labels.
  - `AppraisalBars`: bar fill from pixel rows. Saturated = filled, light grey = empty, white gaps ≤ 12 px are segment dividers. A bar must start within 2 label-heights of the scan start. IV = fill × 15.
  - `IVSolver`: every half level × IV combination, matched to CP, HP and the next power-up's stardust (`PowerUpCalculator`), narrowed by the bar IVs (±1).
  - `ScreenshotImporter`: species from the name (all forms with that base name), else the candy family's evolution line, filtered by type labels. It retries as lucky, then without the stardust.
- App: `Features/Collection/ScreenshotReader.swift` (Vision `VNRecognizeTextRequest`, `.accurate`, en-US, no language correction; scans rows from the label's bottom to 1.6 label-heights below) and `ScreenshotImportView.swift` (PhotosPicker, up to 4 images, "Read from the screenshots" summary, then the editor via `CollectionEditorView(prefilled:)`).
- Checked on the user's real screenshots (in `samples/`, gitignored, **never commit them or their values**): the CP/HP/stardust math and the bar measurement give the right level and IVs for both sample Pokémon. Their screenshots also show a third-party IV overlay (a dark "level, IV %, IVs" label at the top right); the app does **not** read it.
- Not verified until it runs on a phone: what Vision actually returns for these screens (line splitting, the CP font, the "Attack/Defense/HP" label boxes).

## Raids and Rocket (Phases 6–7): how they work

- `Packages/TrainerKit/Sources/Counters/CounterRanker.swift`: generic candidate pool (released PvPoke species, toggles for shadow, mega, elite/legacy moves), ranking by best-moveset DPS (`DamageCalculator`), `rankAgainstAll` (average relative DPS over several defenders, used per Rocket slot), weaknesses/resistances, and feed-name matching ("Mega Charizard X" → "Charizard (Mega X)", "Primal Kyogre" → "Kyogre (Primal)").
- Defenders (raid bosses, Rocket Pokémon) are modelled at **level 40, 15/15/15** because their real stats are server-side. Only **relative** DPS (% of the best counter) is shown, never absolute DPS. Rocket Pokémon are treated as shadow (shadow defence multiplier).
- **Open decision (still the user's):** the "how many trainers needed" raid estimate is **left out**, because it needs raid boss HP/CPM per tier, which no approved source has. The options are a cited community table marked `TODO: verify`, or keep leaving it out.
- App side: `Features/Counters/CounterSupport.swift` (shared settings, rows, method note; settings remembered in `@AppStorage` keys `counters.*`), `Features/Raids/*`, `Features/Rocket/*`. `DataCenter` now also loads `raids` and `rocketLineups`.
- Weather choices are the game master ids (`clear`, `overcast`, `partly_cloudy`, …), shown as text. The weather that boosts the boss's own types is marked.

## Where things are

- `App/`: app entry, tab bar, `DataCenter` (feeds → decoded gamemaster, lookup, events)
- `Features/<Feature>/`: SwiftUI screens per feature
- `Persistence/`: SwiftData models (`AppModelContainer.schema` lists them all)
- `Packages/TrainerKit/`: pure Swift, tested with `swift test` on CI
  - `DataSources`: feeds, cache, `EventCalendar`, `EventExtras`, `GamemasterLookup`, snapshots
  - `GameMath`: level/battle tables, CP, costs, `DamageCalculator`
  - `SearchBuilder`: `search-terms.json` and the query builder
  - `CollectionImport`: `CSVReader` and `CollectionCSV`
  - `Counters`: raid/Rocket counter rankings (`CounterRanker`)
  - `ScreenshotImport`: screenshot text parsing, appraisal bars, IV solver
- `scripts/`:
  - `update-snapshots.sh`: bundled feed snapshots
  - `update-level-tables.ps1`: PokeMiners tables
  - `make-app-icon.ps1`
- Docs: README.md, INSTALL.md, DATA_SOURCES.md, COLLECTION_IMPORT.md
