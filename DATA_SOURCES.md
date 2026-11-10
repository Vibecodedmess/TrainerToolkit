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
`rocketLineups.json` exists on the data branch but has no wiki page. Its format (`name`, `title`, `type`, `firstPokemon`/`secondPokemon`/`thirdPokemon`) was read from the file itself.

### Niantic help article: in-game search terms

| | |
| --- | --- |
| URL | https://niantic.helpshift.com/hc/en/6-pokemon-go/faq/1486-searching-filtering-your-pokemon-inventory/ |
| Checked | 2026-11-10 (the page said "Last Updated: 83d") |
| Used for | Every search keyword and operator in `Packages/TrainerKit/Sources/SearchBuilder/Resources/search-terms.json` |

Terms are kept in that JSON file, not in code, so they can be added or fixed without code changes.
Entries with `"verified": false` are not in the article and are marked in the app with an orange question mark:

- `#` on its own meaning "has any tag". The article only documents `#tagname`. Used by the "Safe to transfer" preset as `!#`.
- Age ranges such as `age0-7`. The article only shows `age0` and `age1`.
- `distance1000` without a space. The article writes `distance 1000`.
- Precedence when mixing `&` and `,`. The app assumes the commas are applied first, so `0*,1*&shiny` means (0★ or 1★) and shiny. The app never puts a `!` term inside a comma list, which avoids ambiguity.

## How the app uses them

- **Bundled snapshot:** a copy of every file ships in the app (`Packages/TrainerKit/Sources/DataSources/Snapshots`, dates in `manifest.json`), so the app works offline on first launch.
  To refresh it, run `scripts/update-snapshots.sh` (by hand, before a release).
- **Cache:** downloaded copies live in the app's Application Support folder, on the device only.
- **Automatic refresh:** when the app opens or returns to the foreground, any source older than the interval set in Settings (3/6/12/24 h, default 6 h) is checked, one source at a time.
- **Validation:** every download is decoded before use. It's rejected if it isn't valid JSON, has no entries, or more than 10% of entries don't match the expected format.
  A rejected or failed download never replaces the last good copy. The app shows a small warning instead.
- **No personal data is sent.** Requests carry only a generic `User-Agent: TrainerToolkit/1.0 (personal iOS app)`.

## Open questions (decisions needed before later phases)

1. **PvE move stats, CP multipliers, power-up costs (Phases 3 and 6).** These are not in PvPoke's gamemaster. Candidates, both live on 2026-11-10:
   - **PokeMiners `game_masters`** (`latest/latest.json`, ~19.5 MB, last updated 2026-08-29): the datamined game master. Has PvE move stats, the CP multiplier per level and stardust/candy costs per level. It is large and has no license file.
   - **pokemon-go-api** (`pokemon-go-api.github.io/pokemon-go-api/api/pokedex.json`, ~14.9 MB, updated 2026-11-10): a JSON API generated from the game master.
   - Or a small static table file per value set, each citing its source.
2. **Trade stardust costs and type effectiveness / weather boosts:** to be decided with (1), each with a cited source.

## Not used

- No Niantic login, no unofficial game APIs, nothing read from the game app.
- No sprites, logos or other official artwork.
