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
| 5 | My Collection: manual entry (5a) + CSV import in the app's **own** format (5b) | Built, **not yet tested on the phone**. See "Current state" |
| 6 | Raid Counter Picker | **Groundwork only** (battle tables + damage math, tested). No UI yet |
| 7 | Team Rocket Counter Sheet | Not started |
| 8 | Trade Planner | Not started |
| 9 | Home tab + polish, final README | Not started (the app icon already exists) |

## Current state (update this section as work continues)

- Last code commit: Phase 5b, CSV import (`ceab27b`), plus `50b7f94` (runner back to `macos-15`, this file).
- **No green build of Phase 5b yet.** On 2026-11-11 GitHub had no free macOS runners in either pool:
  - build #10 (Intel) was never acquired
  - build #11 (`macos-15`) was never acquired
  - build #12 (`macos-15`, `b42edb7`) was never acquired; the runner was then switched to `macos-15-intel`
- If the latest run failed with "not acquired", start the workflow again (later in the day helps).
- The last green build was #9 (`6ecefe9`): Phase 5a manual entry plus the raid groundwork. Its IPA is in `%USERPROFILE%\Downloads\TrainerToolkit-build9`, not yet tested by the user.
- **Next steps:**
  1. Get a green build of `ceab27b` or later.
  2. The user installs it and tests Phase 5: manual entry and CSV import.
  3. Once they reply "All passed", start Phase 6.
- **Phase 5 phone test checklist** (give it to the user with the IPA):
  - Collection empty state.
  - Add a Pokémon manually: species picker, IVs, level or "Find level from CP", move pickers with ★ for elite moves, flags.
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

## Open question for Phase 6 (ask the user before building the raid UI)

**Raid boss HP and boss CP multiplier per tier are not in the game master**, because the game's servers hold them. DPS rankings don't need them. The "how many trainers needed" estimate does. The options are:
- a community table with a citation, marked `TODO: verify`
- leaving the trainer estimate out

Phase 6 also needs: the raid boss list from ScrapedDuck `raids.json` (name → GamemasterLookup), the per-boss weaknesses from BattleTables, generic counters (all species at a chosen level, best moveset per DamageCalculator), the user's counters from CollectedPokemon, a party of 6, and a "how this is calculated" note.

## Where things are

- `App/`: app entry, tab bar, `DataCenter` (feeds → decoded gamemaster, lookup, events)
- `Features/<Feature>/`: SwiftUI screens per feature
- `Persistence/`: SwiftData models (`AppModelContainer.schema` lists them all)
- `Packages/TrainerKit/`: pure Swift, tested with `swift test` on CI
  - `DataSources`: feeds, cache, `EventCalendar`, `EventExtras`, `GamemasterLookup`, snapshots
  - `GameMath`: level/battle tables, CP, costs, `DamageCalculator`
  - `SearchBuilder`: `search-terms.json` and the query builder
  - `CollectionImport`: `CSVReader` and `CollectionCSV`
- `scripts/`:
  - `update-snapshots.sh`: bundled feed snapshots
  - `update-level-tables.ps1`: PokeMiners tables
  - `make-app-icon.ps1`
- Docs: README.md, INSTALL.md, DATA_SOURCES.md, COLLECTION_IMPORT.md
