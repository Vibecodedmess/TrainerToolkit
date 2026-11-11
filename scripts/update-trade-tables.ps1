# Extracts the friendship / trade tables the Trade Planner needs from PokeMiners' game master
# into Packages/TrainerKit/Sources/GameMath/Resources/trade-tables.json.
# Usage (PowerShell 7, from the repo root):
#   ./scripts/update-trade-tables.ps1                              # download the pinned commit
#   ./scripts/update-trade-tables.ps1 -GameMaster C:\path\latest.json   # reuse a local copy of that commit
#   ./scripts/update-trade-tables.ps1 -Commit <sha>                 # pin a newer commit
#
# Source: https://github.com/PokeMiners/game_masters (latest/latest.json, ~20 MB), pinned to a commit.
# With -GameMaster the file is assumed to be the -Commit version; the commit id is recorded as given.
# Only the small tables below are kept; a downloaded file goes to a temp folder and is deleted.
# Templates used: FRIENDSHIP_LEVEL_<n> (friendshipMilestoneSettings), REMOTE_TRADE_SETTINGS.
#
# NOT in the game master (so not in this file): the base stardust cost of a trade, and the
# friendship level names. The app asks the user for base costs and labels levels by number.
param(
    [string]$GameMaster,
    [string]$Commit = '8e227be44f288d34463e23bf04e9b564d3c16f79'
)
$ErrorActionPreference = 'Stop'

$repoUrl = 'https://github.com/PokeMiners/game_masters'
$fileUrl = "https://raw.githubusercontent.com/PokeMiners/game_masters/$Commit/latest/latest.json"
$root = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $root 'Packages/TrainerKit/Sources/GameMath/Resources/trade-tables.json'

$tmp = $null
try {
    if ($GameMaster) {
        $file = (Resolve-Path $GameMaster).Path
    } else {
        $tmp = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "tradetab-$([guid]::NewGuid())")
        $file = Join-Path $tmp 'latest.json'
        Invoke-WebRequest -Uri $fileUrl -OutFile $file -UseBasicParsing
    }
    $gm = Get-Content $file -Raw | ConvertFrom-Json

    function IntOrNull($v) { if ($null -eq $v) { $null } else { [int]$v } }
    function DoubleOrNull($v) { if ($null -eq $v) { $null } else { [double]$v } }

    # ---- Friendship levels ----
    $levelTemplates = @($gm | Where-Object { $_.templateId -match '^FRIENDSHIP_LEVEL_\d+$' -and $_.data.friendshipMilestoneSettings } |
        Sort-Object { [int]($_.templateId -replace '^FRIENDSHIP_LEVEL_', '') })
    if ($levelTemplates.Count -lt 2) { throw "Expected several FRIENDSHIP_LEVEL_<n> templates, got $($levelTemplates.Count)" }

    $levels = @()
    $expected = 0
    foreach ($t in $levelTemplates) {
        $n = [int]($t.templateId -replace '^FRIENDSHIP_LEVEL_', '')
        if ($n -ne $expected) { throw "Friendship levels are not contiguous: expected $expected, got $n" }
        $expected++
        $s = $t.data.friendshipMilestoneSettings
        $levels += [ordered]@{
            level = $n
            minPointsToReach = (IntOrNull $s.minPointsToReach)
            relativePointsToReach = (IntOrNull $s.relativePointsToReach)
            milestoneXpReward = (IntOrNull $s.milestoneXpReward)
            attackBonusPercentage = (DoubleOrNull $s.attackBonusPercentage)
            raidBallBonus = (IntOrNull $s.raidBallBonus)
            tradingDiscount = (DoubleOrNull $s.tradingDiscount)
            unlockedTrading = [string[]]@($s.unlockedTrading | Where-Object { $_ })
            unlockedLuckyFriendApplicator = [bool]$s.unlockedLuckyFriendApplicator
        }
    }

    # ---- Remote trade settings (copied as-is; every key is optional in the app) ----
    $remote = $null
    $remoteTemplate = $gm | Where-Object { $_.templateId -eq 'REMOTE_TRADE_SETTINGS' } | Select-Object -First 1
    if ($remoteTemplate -and $remoteTemplate.data.remoteTradeSettings) {
        $remote = [ordered]@{}
        foreach ($p in $remoteTemplate.data.remoteTradeSettings.PSObject.Properties) { $remote[$p.Name] = $p.Value }
    } else {
        Write-Warning 'REMOTE_TRADE_SETTINGS not found; remoteTrade will be null'
    }

    $tables = [ordered]@{
        source = [ordered]@{
            name = 'PokeMiners game_masters, latest/latest.json'
            url = $repoUrl
            commit = $Commit
            extracted = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd')
            templates = @('FRIENDSHIP_LEVEL_*', 'REMOTE_TRADE_SETTINGS')
        }
        friendshipLevels = $levels
        remoteTrade = $remote
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
    [IO.File]::WriteAllText($outFile, ($tables | ConvertTo-Json -Depth 6) + "`n", (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Wrote $outFile ($($levels.Count) friendship levels, PokeMiners commit $Commit)"
} finally {
    if ($tmp) { Remove-Item -Recurse -Force $tmp }
}
