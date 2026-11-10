# Data sources

Every piece of game data in Trainer Toolkit comes from a source listed here.
Nothing is typed in from memory. Values not yet confirmed are marked `TODO: verify` in code and listed at the bottom.

All sources were checked live on **2026-11-10**.

## In use

### PvPoke gamemaster: Pokémon and moves

| | |
| --- | --- |
| URL | `https://raw.githubusercontent.com/pvpoke/pvpoke/master/src/data/gamemaster.min.json` |
| Project | https://github.com/pvpoke/pvpoke |
| License | MIT, © 2019 pvpoke. The notice is shown in the app under More > Data sources > Credits |
| Used for | Species, forms, base stats (atk/def/hp), types, fast/charged/elite/legacy move lists, move names and types, families/evolutions, tags (legendary, mythical, shadow-eligible, ...) |
| Size | ~0.94 MB minified. Identical content to `gamemaster.json` (1.7 MB): both had 1,752 Pokémon entries and 355 moves on 2026-11-10 |
| Refresh rules | No limit is stated. raw.githubusercontent.com serves `Cache-Control: max-age=300`, so the app never asks more than once per 5 minutes, sends `If-None-Match` (ETag) and by default checks only every 6 hours |

**Limitation:** the move `power`, `energy`, `energyGain`, `cooldown` and `turns` values in this file are **PvP (trainer battle) stats**.
Raid and gym (PvE) move stats are different and are **not** in this file. See "Open questions" below.

### ScrapedDuck: events, raids, research, Rocket lineups

| | |
| --- | --- |
| URLs | `https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/{events,raids,research,rocketLineups}.min.json` |
| Project | https://github.com/bigfoott/ScrapedDuck (code: AGPL-3.0). Data is scraped from **LeekDuck.com** with permission |
| Terms (README "For Developers") | Free to use as long as the app is **not behind a paywall**, is **not monetized with ads**, and **credits ScrapedDuck and LeekDuck.com**. This app meets all three: it is free and personal, has no ads, and credits both under More > Data sources > Credits |
| Refresh rules | Wiki "Rate-Limits": GitHub caches the files for 5 minutes, so don't fetch an endpoint more than once per 5 minutes. The app enforces a 5-minute minimum per source, even for "Refresh now", and checks only every 6 hours by default |
| Images | The feeds contain LeekDuck image URLs. The app does **not** decode, show or load them (no official artwork) |
| Dates | Per the wiki: a time ending in `Z` is the same moment worldwide (UTC). A time without a zone is local wall-clock time in each trainer's own time zone. Handled by `EventTime` (tested) |

Files on 2026-11-10: events 53, raid bosses 12, research tasks 39, Rocket lineups 26 (Giovanni, 3 leaders, 22 grunt types).

What the event feed does and doesn't contain (checked 2026-11-10):
- **Contains:**
  - for Community Days: spawns, shinies, bonuses (with disclaimers) and special research steps
  - for raid battles: bosses and shinies
  - for Spotlight Hours: the featured Pokémon and the bonus
  - for Research Breakthroughs: the featured Pokémon
  - for every event: whether it has spawns or field research
- **Does not contain:** the Community Day **exclusive move** or the **evolve deadline**. The app never guesses these. The trainer types both in from the official announcement. As a hint, the app shows PvPoke's `eliteMoves` for the evolution line, clearly labelled as candidates.
- **What to evolve** comes from PvPoke's `family.evolutions`, matching ScrapedDuck names such as "Galarian Meowth" to PvPoke names such as "Meowth (Galarian)".
`rocketLineups.json` exists on the data branch but has no wiki page. Its format (`name`, `title`, `type`, `firstPokemon`/`secondPokemon`/`thirdPokemon`) was read from the file itself.

### Niantic help article: in-game search terms

| | |
| --- | --- |
| URL | https://niantic.helpshift.com/hc/en/6-pokemon-go/faq/1486-searching-filtering-your-pokemon-inventory/ |
| Checked | 2026-11-10 (the page said "Last Updated: 83d") |
| Used for | Every search keyword and operator in `Packages/TrainerKit/Sources/SearchBuilder/Resources/search-terms.json` |

Terms are kept in that JSON file, not in code, so they can be added or fixed without code changes.
Any entry marked `"verified": false` gets an orange question mark in the app. There are none right now.

These four are not in the article, but were **confirmed in the game on 2026-11-10**:

- `#` on its own matches any tag, so `!#` hides tagged Pokémon. The "Safe to transfer" preset uses this.
- Age ranges such as `age0-7`.
- `distance100-` written without a space.
- When mixing `&` and `,`, the commas are applied first: `0*,1*&shiny` gives only shiny 0★ and 1★ Pokémon. The app also never puts a `!` term inside a comma list.

### PokeMiners game master: level and power-up tables

| | |
| --- | --- |
| Source | https://github.com/PokeMiners/game_masters, file `latest/latest.json` (~19.5 MB). A community datamine of the game's public game master |
| Pinned to | commit `8e227be44f288d34463e23bf04e9b564d3c16f79`, extracted 2026-11-10 (the repo's last update was 2026-08-29) |
| License | None stated. Used with your approval; only small numeric tables are kept |
| Extracted by | `scripts/update-level-tables.ps1` into `Packages/TrainerKit/Sources/GameMath/Resources/level-tables.json` (the file records its source commit) |
| Templates | `PLAYER_LEVEL_SETTINGS` (CP multiplier per whole level), `POKEMON_UPGRADE_SETTINGS` (stardust / candy / XL Candy per level, shadow and purified multipliers, max level 50, Best Buddy +1), `LUCKY_POKEMON_SETTINGS` (lucky stardust ×0.5) |

Not in the game master, so these are community-documented formulas (e.g. Bulbapedia "Combat Power", GamePress):

- CP = floor((Atk+IV) × √(Def+IV) × √(Sta+IV) × CPM² / 10), minimum 10.
- Half-level CPM = √((CPM(L)² + CPM(L+1)²) / 2).

Both are **checked in unit tests against PvPoke's own numbers**:
- `level25CP` matches for 483 of 484 non-Mega species. The odd one out is Hisuian Electrode, where PvPoke's value looks stale.
- None of 5,256 PvPoke rank-1 league IV sets exceeds its league CP cap.

`TODO: verify`: the game master gives the shadow (×1.2), purified (×0.9) and lucky (×0.5) multipliers, but not how fractional results are rounded. The app rounds **up** per power-up (for example, 1 Candy becomes 2 for a shadow). It also assumes a lucky purified Pokémon gets both stardust discounts.

## How the app uses them

- **Bundled snapshot:** a copy of every file ships in the app (`Packages/TrainerKit/Sources/DataSources/Snapshots`, dates in `manifest.json`), so the app works offline on first launch.
  To refresh it, run `scripts/update-snapshots.sh` (by hand, before a release).
- **Cache:** downloaded copies live in the app's Application Support folder, on the device only.
- **Automatic refresh:** when the app opens or returns to the foreground, any source older than the interval set in Settings (3/6/12/24 h, default 6 h) is checked, one source at a time.
- **Validation:** every download is decoded before use. It's rejected if it isn't valid JSON, has no entries, or more than 10% of entries don't match the expected format.
  A rejected or failed download never replaces the last good copy. The app shows a small warning instead.
- **No personal data is sent.** Requests carry only a generic `User-Agent: TrainerToolkit/1.0 (personal iOS app)`.

### PokeMiners game master: battle tables (for Raids)

`scripts/update-level-tables.ps1` also writes `Packages/TrainerKit/Sources/GameMath/Resources/battle-tables.json`, from the same pinned commit:

- **Type chart:** from the `POKEMON_TYPE_*` templates (`typeEffective.attackScalar`).
  - Each row is in the game's internal type order. That order was confirmed against the Fire row, and tests check that the chart is oriented correctly.
- **Weather boosts:** from `WEATHER_AFFINITY_*`.
- **Multipliers:**
  - from `BATTLE_SETTINGS`: same-type ×1.2, shadow attack ×1.2, shadow defense ×0.833
  - from `WEATHER_BONUS_SETTINGS`: weather ×1.2
- **PvE moves:** 403 moves from the `V*_MOVE_*` templates, with power, duration, damage window and energy.
  - The game master's `_FAST` suffix is removed, so the ids match PvPoke's.
  - 22 moves have numeric ids in the game master and won't match a PvPoke move.

The damage formula (`floor(0.5 × Power × Atk/Def × multipliers) + 1`) and the fast/charged "cycle DPS" model are standard community models, documented in `GameMath/DamageCalculator.swift`. They are not data from the game master.

## Open questions (decisions needed before later phases)

1. **Raid boss HP and boss CP multiplier per tier (Phase 6).** These are **not** in the game master; the game's servers hold them. The "how many trainers" estimate needs them, but DPS rankings don't. The options are a cited community table, marked `TODO: verify`, or leaving the trainer estimate out.
2. **Trade stardust costs (Phase 8):** will have a cited source, checked before use.

## Not used

- No Niantic login, no unofficial game APIs, nothing read from the game app.
- No sprites, logos or other official artwork.
