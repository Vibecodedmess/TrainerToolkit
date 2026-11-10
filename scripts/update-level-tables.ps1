# Extracts the level / power-up tables the app needs from PokeMiners' game master
# into Packages/TrainerKit/Sources/GameMath/Resources/level-tables.json.
# Usage (PowerShell 7, from the repo root):  ./scripts/update-level-tables.ps1
#
# Source: https://github.com/PokeMiners/game_masters (latest/latest.json, ~20 MB).
# Only the small tables below are kept; the big file is downloaded to a temp folder and deleted.
# Templates used: PLAYER_LEVEL_SETTINGS, POKEMON_UPGRADE_SETTINGS, LUCKY_POKEMON_SETTINGS.
$ErrorActionPreference = 'Stop'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

$repoUrl = 'https://github.com/PokeMiners/game_masters'
$fileUrl = 'https://raw.githubusercontent.com/PokeMiners/game_masters/master/latest/latest.json'
$root = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $root 'Packages/TrainerKit/Sources/GameMath/Resources/level-tables.json'

$commit = ((git ls-remote "$repoUrl.git" refs/heads/master) -split '\s+')[0]
if (-not $commit) { throw 'Could not read the PokeMiners commit id' }

$tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "levtab-$([guid]::NewGuid())")
try {
    $file = Join-Path $tmp 'latest.json'
    Invoke-WebRequest -Uri $fileUrl -OutFile $file -UseBasicParsing
    $gm = Get-Content $file -Raw | ConvertFrom-Json

    function Template($id) {
        $t = $gm | Where-Object { $_.templateId -eq $id } | Select-Object -First 1
        if (-not $t) { throw "Template $id not found in game master" }
        $t.data
    }
    $player = (Template 'PLAYER_LEVEL_SETTINGS').playerLevel
    $upgrade = (Template 'POKEMON_UPGRADE_SETTINGS').pokemonUpgrades
    $lucky = (Template 'LUCKY_POKEMON_SETTINGS').luckyPokemonSettings

    function Nums($values) { ($values | ForEach-Object { ([double]$_).ToString('R', $inv) }) -join ', ' }
    function Num($v) { ([double]$v).ToString('R', $inv) }

    foreach ($pair in @(@('cpMultiplier', $player.cpMultiplier), @('stardustCost', $upgrade.stardustCost),
                        @('candyCost', $upgrade.candyCost), @('xlCandyCost', $upgrade.xlCandyCost))) {
        if (-not $pair[1] -or $pair[1].Count -lt 10) { throw "$($pair[0]) missing or too short" }
    }

    $json = @"
{
  "source": {
    "name": "PokeMiners game_masters, latest/latest.json",
    "url": "$repoUrl",
    "commit": "$commit",
    "extracted": "$((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd'))",
    "templates": ["PLAYER_LEVEL_SETTINGS", "POKEMON_UPGRADE_SETTINGS", "LUCKY_POKEMON_SETTINGS"]
  },
  "cpMultiplier": [$(Nums $player.cpMultiplier)],
  "upgradesPerLevel": $($upgrade.upgradesPerLevel),
  "maxNormalUpgradeLevel": $($upgrade.maxNormalUpgradeLevel),
  "bestBuddyExtraLevels": $($upgrade.defaultCpBoostAdditionalLevel),
  "stardustCost": [$(Nums $upgrade.stardustCost)],
  "candyCost": [$(Nums $upgrade.candyCost)],
  "xlCandyCost": [$(Nums $upgrade.xlCandyCost)],
  "xlCandyMinPokemonLevel": $($upgrade.xlCandyMinPokemonLevel),
  "shadowStardustMultiplier": $(Num $upgrade.shadowStardustMultiplier),
  "shadowCandyMultiplier": $(Num $upgrade.shadowCandyMultiplier),
  "purifiedStardustMultiplier": $(Num $upgrade.purifiedStardustMultiplier),
  "purifiedCandyMultiplier": $(Num $upgrade.purifiedCandyMultiplier),
  "luckyStardustDiscount": $(Num $lucky.powerUpStardustDiscountPercent)
}
"@
    New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
    [IO.File]::WriteAllText($outFile, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Wrote $outFile (PokeMiners commit $commit)"
} finally {
    Remove-Item -Recurse -Force $tmp
}
