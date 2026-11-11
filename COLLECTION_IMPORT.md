# Importing your Pokémon (CSV)

My Collection can import a CSV file in Trainer Toolkit's own simple format.
Make it in Google Sheets, Excel or Numbers, export it as CSV, and in the app go to **More > Collection > + > Import CSV**.
The app shows a preview, with problems and duplicates, before anything is saved.

You only need your **raid and battle attackers**, not your whole storage.

## Columns

The header row decides what each column means. Column order doesn't matter, and case and spaces are ignored.

| Column | Required | What to enter |
| --- | --- | --- |
| `Name` | yes | English name, e.g. `Machamp`, `Galarian Meowth` or `Meowth (Galarian)`. `Shadow Machamp` also marks it as a shadow |
| `CP` | yes* | CP shown in the game. The app works out the level from CP + IVs |
| `Attack` | yes | Attack IV, 0–15 |
| `Defense` | yes | Defense IV, 0–15 |
| `HP` | yes | HP (stamina) IV, 0–15 |
| `Fast move` | no | e.g. `Counter`, or the id `COUNTER` |
| `Charged move` | no | e.g. `Dynamic Punch` |
| `Second charged move` | no | Leave empty if not unlocked |
| `Shadow` / `Purified` / `Shiny` / `Lucky` | no | `yes` or `no` (also `y`, `x`, `true`, `1`, `ja`). Empty = no |
| `Level` | no* | e.g. `30` or `30.5`. If given, it is used instead of working the level out from CP |
| `Nickname` | no | |
| `Notes` | no | |

\* Each row needs a `CP` or a `Level`.

Also accepted as header names: `Pokémon`/`Species` (Name), `Atk`, `Def`, `Sta`/`Stamina`, `Fast`/`Quick move`, `Charged`, `Charged move 2`.

Comma, semicolon (Excel in Dutch and other European settings) and tab separated files all work, as do decimal commas (`30,5`).

## Example

```
Name,CP,Attack,Defense,HP,Fast move,Charged move,Second charged move,Shadow,Purified,Shiny,Lucky,Level,Nickname,Notes
Bulbasaur,,15,14,13,Vine Whip,Sludge Bomb,,no,no,no,no,25,,
```

The example uses `Level` with an empty `CP`. With your own Pokémon, just type the CP the game shows.

## What happens on import

- **Unknown Pokémon name:** the row is skipped and listed under "Not imported", with its line number.
- **No level matches the CP and IVs:** the row is skipped. Usually that means a typo in the CP or IVs, or the wrong form (e.g. Alolan vs regular).
- **Several levels fit the CP** (only at very low CP): the lowest is used, with a warning.
- **Unknown move name:** that move is left empty, with a warning.
- **A move PvPoke doesn't list for that Pokémon:** kept, with a warning.
- **Same Pokémon already in your collection** (same species, IVs, level and shadow status): skipped, unless you turn on "Import duplicates too".

The template can be shared from the import screen. It contains only the header row.
