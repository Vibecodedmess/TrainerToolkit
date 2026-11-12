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

## Current state (update this section as work continues)

- **As of 2026-11-12:** Phases 0–15 are built, and everything is confirmed on the phone except the CSV import, which is untested because the user has no CSV. Phase 16 (visual polish) is confirmed too.
- **Look and feel (Phase 16, user's choices):**
  - The user picked "polished native" over a card dashboard and a dark HUD. They explicitly did **not** want separate ATK/DEF/HP stat bars: keep the layout as it is.
  - **Stats line everywhere:** `CP 2651 · L30 · 13/15/14 · 93%`, IVs as Attack/Defense/HP. Use `PokemonStats.line` / `StatsLineText` in `Shared/Theme.swift`; don't hand-build it.
  - `Shared/Theme.swift` also has `AppTheme` (accent from `AccentColor.colorset`, type colour of a Pokémon), `MeterBar` (IV % or relative strength, in the type colour), `TypeStrip` (leading colour strip on raid/Rocket rows) and `InfoTile` (Home tiles).
  - Home: 2×2 tiles (collection, goals, Rocket, backup) using `navigationDestination(item:)`, then a tinted Community Day card, live events, the top raid tier and the next goals.
  - Counter bars take the colour of the attack's type (charged move, else fast move).
- **Maintenance (2026-11-12, user's choice):**
  - Snapshots refreshed.
  - PokeMiners pins checked: still the latest commits.
  - CI writes a "Compiler warnings" summary on each run page. Build #24 (`3c146c8`) had 0 warnings and was green.
- **No open feature ideas.** The user is **not interested in PvP** (declined PvP league IV ranks on 2026-11-12): do not suggest PvP features again. Wait for the user to name what they want next.
- **Open `TODO: verify` items** (each one is also marked in code and in DATA_SOURCES.md):
  - shadow/purified/lucky power-up cost rounding
  - Trade Planner:
    - cost rounding
    - trade kind → `unlockedTrading` mapping
    - attack bonus shown as a multiplier
    - readable category names
    - friendship levels shown as "Level N", since the names aren't in the data
  - raid tier numbers (Bulbapedia), including the 3-star Shadow time limit
  - evolution "how to get" texts (Pokémon GO Wiki)
- **CI tips:**
  - Build times vary from 4 to 10 minutes.
  - Read results on the run page, including the warnings summary.
  - Artifact downloads sometimes land in Downloads as random `*.tmp` files instead of `TrainerToolkit-ipa-N.zip`. Check each candidate is a zip containing `TrainerToolkit.ipa`, then use it and delete the leftovers.

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

- `App/`: app entry, tab bar, `DataCenter` (feeds → decoded gamemaster, lookup, events)
- `Features/<Feature>/`: SwiftUI screens per feature
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
  - `make-app-icon.ps1`
- Docs: README.md, INSTALL.md, DATA_SOURCES.md, COLLECTION_IMPORT.md
