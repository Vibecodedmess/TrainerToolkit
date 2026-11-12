# Extracts evolution requirements from PokeMiners' game master, with the game's own English names
# and descriptions for evolution items and quests, into
# Packages/TrainerKit/Sources/GameMath/Resources/evolution-tables.json.
# Usage (PowerShell 7, from the repo root):
#   ./scripts/update-evolution-tables.ps1                       # download both pinned files
#   ./scripts/update-evolution-tables.ps1 -GameMaster C:\path\latest.json -Texts C:\path\i18n_english.json
#
# Sources (both pinned to a commit; with local files the commits are recorded as given):
#   - https://github.com/PokeMiners/game_masters  latest/latest.json (~20 MB): pokemonSettings.evolutionBranch
#     and the *_EVOLUTION_QUEST templates.
#   - https://github.com/PokeMiners/pogo_assets  "Texts/Latest APK/JSON/i18n_english.json" (~3 MB): the
#     game's English text, only for item names/descriptions and evolution quest text.
# Downloads go to a temp folder and are deleted. Mega (temporaryEvolution) branches are skipped.
#
# NOT in either file: how to get an item. That is in evolution-items-community.json (written by hand
# from a cited community wiki, marked unverified in the app).
param(
    [string]$GameMaster,
    [string]$Texts,
    [string]$GameMasterCommit = '8e227be44f288d34463e23bf04e9b564d3c16f79',
    [string]$TextsCommit = 'db10df75d6f6f92018d9786af0aecc238fecc4ef'
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $root 'Packages/TrainerKit/Sources/GameMath/Resources/evolution-tables.json'
$gmUrl = "https://raw.githubusercontent.com/PokeMiners/game_masters/$GameMasterCommit/latest/latest.json"
$textsUrl = "https://raw.githubusercontent.com/PokeMiners/pogo_assets/$TextsCommit/Texts/Latest%20APK/JSON/i18n_english.json"

$tmp = $null
try {
    if (-not $GameMaster -or -not $Texts) {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "evotab-$([guid]::NewGuid())")
    }
    if ($GameMaster) { $gmFile = (Resolve-Path $GameMaster).Path } else {
        $gmFile = Join-Path $tmp 'latest.json'
        Invoke-WebRequest -Uri $gmUrl -OutFile $gmFile -UseBasicParsing
    }
    if ($Texts) { $textsFile = (Resolve-Path $Texts).Path } else {
        $textsFile = Join-Path $tmp 'i18n_english.json'
        Invoke-WebRequest -Uri $textsUrl -OutFile $textsFile -UseBasicParsing
    }
    $gm = Get-Content $gmFile -Raw | ConvertFrom-Json

    # The text file is {"data": [key, value, key, value, ...]}.
    $flat = (Get-Content $textsFile -Raw | ConvertFrom-Json).data
    $text = @{}
    for ($i = 0; $i + 1 -lt $flat.Count; $i += 2) { $text[[string]$flat[$i]] = [string]$flat[$i + 1] }
    if ($text.Count -lt 1000) { throw "Text file looks wrong: only $($text.Count) entries" }

    function IntOrNull($v) { if ($null -eq $v) { $null } else { [int]$v } }
    function DoubleOrNull($v) { if ($null -eq $v) { $null } else { [double]$v } }

    # ---- Evolution branches (deduplicated: the game master repeats species under several templates) ----
    $seen = @{}
    $branches = New-Object System.Collections.Generic.List[object]
    $itemIds = @{}
    $questIds = @{}
    foreach ($t in $gm) {
        $ps = $t.data.pokemonSettings
        if (-not $ps -or -not $ps.evolutionBranch) { continue }
        foreach ($b in $ps.evolutionBranch) {
            if (-not $b.evolution) { continue }   # mega / temporary evolutions
            $quest = if ($b.questDisplay) { @($b.questDisplay)[0].questRequirementTemplateId } else { $null }
            # "<ID>_NORMAL" is the plain form: store it as no form, so the duplicates merge.
            $form = if ($ps.form -and [string]$ps.form -ne "$($ps.pokemonId)_NORMAL") { [string]$ps.form } else { $null }
            $evoForm = if ($b.form -and [string]$b.form -ne "$($b.evolution)_NORMAL") { [string]$b.form } else { $null }
            $branch = [ordered]@{
                pokemonId = [string]$ps.pokemonId
                form = $form
                evolution = [string]$b.evolution
                evolutionForm = $evoForm
                candyCost = (IntOrNull $b.candyCost)
                candyCostPurified = (IntOrNull $b.candyCostPurified)
                item = if ($b.evolutionItemRequirement) { [string]$b.evolutionItemRequirement } else { $null }
                itemCost = (IntOrNull $b.evolutionItemRequirementCost)
                lure = if ($b.lureItemRequirement) { [string]$b.lureItemRequirement } else { $null }
                kmBuddyDistance = (DoubleOrNull $b.kmBuddyDistanceRequirement)
                mustBeBuddy = [bool]$b.mustBeBuddy
                onlyDaytime = [bool]$b.onlyDaytime
                onlyNighttime = [bool]$b.onlyNighttime
                onlyDusk = [bool]$b.onlyDuskPeriod
                onlyFullMoon = [bool]$b.onlyFullMoon
                onlyUpsideDown = [bool]$b.onlyUpsideDown
                gender = if ($b.genderRequirement) { [string]$b.genderRequirement } else { $null }
                noCandyCostViaTrade = [bool]$b.noCandyCostViaTrade
                quest = $quest
            }
            $key = ($branch | ConvertTo-Json -Compress)
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            $branches.Add($branch)
            if ($branch.item) { $itemIds[$branch.item] = $true }
            if ($branch.lure) { $itemIds[$branch.lure] = $true }
            if ($quest) { $questIds[$quest] = $true }
        }
    }
    if ($branches.Count -lt 300) { throw "Only $($branches.Count) evolution branches found" }

    # ---- Item names and descriptions (the game's own English text) ----
    $items = @()
    foreach ($id in ($itemIds.Keys | Sort-Object)) {
        $k = ($id -replace '^ITEM_', 'item_').ToLowerInvariant()
        $name = $text["${k}_name"]
        if (-not $name) { throw "No English name for $id (${k}_name)" }
        $items += [ordered]@{ id = $id; name = $name; description = $text["${k}_desc"] }
    }

    # ---- Evolution quests: display text with the goal's target filled in ----
    $quests = @()
    foreach ($id in ($questIds.Keys | Sort-Object)) {
        $tpl = ($gm | Where-Object { $_.templateId -eq $id } | Select-Object -First 1).data.evolutionQuestTemplate
        $q = [ordered]@{ id = $id; text = $null }
        if ($tpl) {
            $target = @($tpl.goals)[0].target
            $raw = $text[[string]$tpl.display.description]
            if ($raw) { $q.text = if ($null -ne $target) { $raw -replace '\{0\}', [string]$target } else { $raw } }
        }
        if (-not $q.text) { Write-Warning "No text for quest $id" }
        $quests += $q
    }

    $tables = [ordered]@{
        source = [ordered]@{
            name = 'PokeMiners game_masters latest/latest.json + pogo_assets i18n_english.json'
            url = 'https://github.com/PokeMiners/game_masters'
            commit = "$GameMasterCommit (texts: pogo_assets $TextsCommit)"
            extracted = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            templates = @('pokemonSettings.evolutionBranch', '*_EVOLUTION_QUEST', 'i18n item_*_name/_desc and quest text')
        }
        branches = $branches
        items = $items
        quests = $quests
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
    [IO.File]::WriteAllText($outFile, ($tables | ConvertTo-Json -Depth 6 -Compress) + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Wrote $outFile ($($branches.Count) branches, $($items.Count) items, $($quests.Count) quests)"
} finally {
    if ($tmp) { Remove-Item -Recurse -Force $tmp }
}
