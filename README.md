# Trainer Toolkit

A personal-use iOS companion app for trainers: search string builder, power-up planner, raid and Rocket counters, event checklists and trade planning.
It is sideloaded, never published.

**Status:** all planned features are built (Phases 0–10). See "Features" below and `CLAUDE.md` for what has been tested on a phone.

## Features

| Tab or screen | What it does |
| --- | --- |
| Home | Live events, a countdown to the next Community Day, the top raid tier, your power-up goals and collection size |
| Search | Builds in-game search strings from filters, with saved presets |
| Raids | Current raid bosses by tier; per boss: weaknesses, resistances and a ranked party of 6 counters, either from every released Pokémon or from My Collection, with weather |
| Events | Event calendar with local times, checklists and reminders, Community Day details |
| More > Planner | Candy, XL candy and stardust needed to power a Pokémon up to a target level |
| More > Collection | Your own Pokémon: manual entry, from screenshots (on-device text recognition reads CP, HP, name, power-up cost, moves and the appraisal bars, then works out level and IVs), or CSV import (see [COLLECTION_IMPORT.md](COLLECTION_IMPORT.md)) |
| More > Rocket | Giovanni, leader and grunt lineups; counters per possible Pokémon and per slot; works offline |
| More > Trades | Friends, want lists and an estimated stardust cost per trade |

Counter rankings use the PvE damage formula with the game master's type chart, weather and move stats. The opponent's real stats are server-side, so percentages are relative to the best counter (each screen has a "How this is calculated" note).

## Ground rules

- No game account access, no unofficial game APIs, no automation. Data comes only from public community feeds or from what you enter.
- No invented game data. Every value comes from a cited source (see `DATA_SOURCES.md`, added in Phase 1). Anything unsure is marked `TODO: verify`.
- No official artwork. Text, type color badges and SF Symbols only.
- No backend, no accounts, no analytics. All data stays on the device.

## Layout

| Path | What |
| --- | --- |
| `project.yml` | XcodeGen spec. The `.xcodeproj` is generated in CI, not committed |
| `Config/Shared.xcconfig` | Bundle ID, display name, version (the one place to change them) |
| `App/` | App entry point and tab bar |
| `Features/*` | One folder per feature screen |
| `Shared/` | Reusable SwiftUI views |
| `Persistence/` | On-device storage (SwiftData from Phase 1 on) |
| `Packages/TrainerKit/` | Pure-Swift modules `GameMath`, `DataSources`, `SearchBuilder`, `CollectionImport`, `Counters` and `ScreenshotImport`, with unit tests |
| `Packages/TrainerKit/Sources/DataSources/Snapshots/` | Bundled offline copy of every dataset (see `DATA_SOURCES.md`) |
| `scripts/update-snapshots.sh` | Refreshes the bundled snapshots |
| `Packages/TrainerKit/Sources/SearchBuilder/` | Search string builder and `search-terms.json` (the editable term list) |
| `scripts/make-app-icon.ps1` | Builds `Resources/Assets.xcassets` from an icon image |
| `scripts/update-level-tables.ps1` | Extracts level/cost tables and battle tables (type chart, weather, PvE moves) from PokeMiners' game master |
| `Packages/TrainerKit/Sources/CollectionImport/` | CSV reader and the collection import format |
| `Packages/TrainerKit/Sources/Counters/` | Raid and Rocket counter rankings |
| `Packages/TrainerKit/Sources/ScreenshotImport/` | Screenshot text parsing, appraisal bar reading and the IV solver |
| `scripts/update-trade-tables.ps1` | Extracts friendship trade discounts from PokeMiners' game master |
| `.github/workflows/build.yml` | macOS CI: tests, then an unsigned `.ipa` artifact |

## Building

There is no local build on Windows: iOS apps can only be compiled on macOS.
The GitHub Actions workflow does it:

1. `swift test --package-path Packages/TrainerKit`
2. `xcodegen generate`
3. `xcodebuild ... -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`
4. Zip `Payload/TrainerToolkit.app` into `TrainerToolkit.ipa`

See [INSTALL.md](INSTALL.md) for getting the IPA onto your iPhone.

Requirements: iOS 17+, Swift 5 language mode, no third-party runtime dependencies. XcodeGen is a build-time tool only.
