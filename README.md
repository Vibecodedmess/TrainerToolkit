# Trainer Toolkit

A personal-use iOS companion app for trainers: search string builder, power-up planner, raid and Rocket counters, event checklists and trade planning.
It is sideloaded, never published.

**Status:** Phase 3, the Candy & Stardust Planner. The data layer, the Search tab and the Planner (More > Planner) work. The other feature screens are still placeholders.

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
| `Packages/TrainerKit/` | Pure-Swift modules `GameMath` and `DataSources`, with unit tests |
| `Packages/TrainerKit/Sources/DataSources/Snapshots/` | Bundled offline copy of every dataset (see `DATA_SOURCES.md`) |
| `scripts/update-snapshots.sh` | Refreshes the bundled snapshots |
| `Packages/TrainerKit/Sources/SearchBuilder/` | Search string builder and `search-terms.json` (the editable term list) |
| `scripts/make-app-icon.ps1` | Builds `Resources/Assets.xcassets` from an icon image |
| `scripts/update-level-tables.ps1` | Extracts CP multiplier and power-up cost tables from PokeMiners' game master |
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
