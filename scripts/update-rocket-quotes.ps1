# Extracts what Team GO Rocket members say before a battle (the game's own English text) into
# Packages/TrainerKit/Sources/Counters/Resources/rocket-quotes.json.
# Usage (PowerShell 7, from the repo root):
#   ./scripts/update-rocket-quotes.ps1                          # download the pinned file
#   ./scripts/update-rocket-quotes.ps1 -Texts C:\path\i18n_english.json
#
# Source: PokeMiners pogo_assets "Texts/Latest APK/JSON/i18n_english.json" (~3 MB), pinned to a commit,
# the same file and commit as scripts/update-evolution-tables.ps1. Keys used:
#   combat_grunt_quote_<type>__<gender>_speaker   one line per grunt type (the same for both genders)
#   combat_grunt_quote#<n>__<gender>_speaker      lines of grunts without a type
#   combat_<leader>_quote__<gender>_speaker       Giovanni, Cliff, Arlo, Sierra
param(
    [string]$Texts,
    [string]$TextsCommit = 'db10df75d6f6f92018d9786af0aecc238fecc4ef'
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $root 'Packages/TrainerKit/Sources/Counters/Resources/rocket-quotes.json'
$textsUrl = "https://raw.githubusercontent.com/PokeMiners/pogo_assets/$TextsCommit/Texts/Latest%20APK/JSON/i18n_english.json"

$tmp = $null
try {
    if ($Texts) { $textsFile = (Resolve-Path $Texts).Path } else {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "rocketq-$([guid]::NewGuid())")
        $textsFile = Join-Path $tmp 'i18n_english.json'
        Invoke-WebRequest -Uri $textsUrl -OutFile $textsFile -UseBasicParsing
    }
    $flat = (Get-Content $textsFile -Raw | ConvertFrom-Json).data
    $text = [ordered]@{}
    for ($i = 0; $i + 1 -lt $flat.Count; $i += 2) { $text[[string]$flat[$i]] = [string]$flat[$i + 1] }

    # Male and female versions are identical in the pinned file; keep the first found, warn if they differ.
    function Pick($keys) {
        $values = @($keys | Where-Object { $text.Contains($_) } | ForEach-Object { $text[$_] } | Select-Object -Unique)
        if ($values.Count -gt 1) { Write-Warning "Different male/female text for $($keys -join ', '); keeping the first" }
        if ($values.Count -gt 0) { $values[0] } else { $null }
    }

    $typed = [ordered]@{}
    foreach ($key in $text.Keys) {
        if ($key -match '^combat_grunt_quote_([a-z]+)__(male|female)_speaker$') {
            $type = $Matches[1]
            if (-not $typed.Contains($type)) {
                $typed[$type] = Pick @("combat_grunt_quote_${type}__male_speaker", "combat_grunt_quote_${type}__female_speaker")
            }
        }
    }
    if ($typed.Count -lt 17) { throw "Only $($typed.Count) typed grunt quotes found" }

    $generic = @()
    for ($n = 1; $n -le 20; $n++) {
        $q = Pick @("combat_grunt_quote#${n}__male_speaker", "combat_grunt_quote#${n}__female_speaker")
        if ($q) { $generic += $q }
    }

    $leaders = [ordered]@{}
    foreach ($name in 'giovanni', 'cliff', 'arlo', 'sierra') {
        $q = Pick @("combat_${name}_quote__male_speaker", "combat_${name}_quote__female_speaker", "combat_${name}_quote")
        if ($q) { $leaders[$name] = $q } else { Write-Warning "No quote for $name" }
    }

    $sortedTyped = [ordered]@{}
    foreach ($k in ($typed.Keys | Sort-Object)) { $sortedTyped[$k] = $typed[$k] }

    $out = [ordered]@{
        source = [ordered]@{
            name = 'PokeMiners pogo_assets, Texts/Latest APK/JSON/i18n_english.json'
            url = 'https://github.com/PokeMiners/pogo_assets'
            commit = $TextsCommit
            extracted = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            templates = @('combat_grunt_quote_<type>', 'combat_grunt_quote#<n>', 'combat_<leader>_quote')
        }
        typed = $sortedTyped
        generic = $generic
        leaders = $leaders
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
    [IO.File]::WriteAllText($outFile, ($out | ConvertTo-Json -Depth 5) + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Wrote $outFile ($($typed.Count) grunt types, $($generic.Count) generic lines, $($leaders.Count) leaders)"
} finally {
    if ($tmp) { Remove-Item -Recurse -Force $tmp }
}
