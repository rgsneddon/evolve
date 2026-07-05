# Build UK electoral-ward MOD_* moderator username registry (ONS May 2025).
# Outputs:
#   - Desktop pack (private): %USERPROFILE%\Desktop\FCG_UK_Ward_Moderator_Usernames.txt
#   - Gitignored Dart list: lib/fcg/data/fcg_uk_ward_moderator_list_generated.dart
param(
    [string]$CsvPath = '',
    [string]$DesktopOut = '',
    [string]$DartOut = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
if (-not $CsvPath) {
    $CsvPath = Join-Path $Root 'build\uk_wards_may2025.csv'
}
if (-not $DesktopOut) {
    $DesktopOut = Join-Path $env:USERPROFILE 'Desktop\FCG_UK_Ward_Moderator_Usernames.txt'
}
if (-not $DartOut) {
    $DartOut = Join-Path $Root 'lib\fcg\data\fcg_uk_ward_moderator_list_generated.dart'
}

if (-not (Test-Path $CsvPath)) {
    throw "Missing ward CSV: $CsvPath. Download ONS Wards May 2025 CSV first."
}

function Normalize-Slug([string]$Text) {
    $lower = $Text.ToLowerInvariant()
    $sb = New-Object System.Text.StringBuilder
    $prevUnderscore = $false
    foreach ($ch in $lower.ToCharArray()) {
        if (($ch -ge 'a' -and $ch -le 'z') -or ($ch -ge '0' -and $ch -le '9')) {
            [void]$sb.Append($ch)
            $prevUnderscore = $false
        } elseif (-not $prevUnderscore) {
            [void]$sb.Append('_')
            $prevUnderscore = $true
        }
    }
    $slug = $sb.ToString().Trim('_')
    if ($slug.Length -gt 20) { $slug = $slug.Substring(0, 20).TrimEnd('_') }
    return $slug
}

function Build-ModUsername([string]$WardName, [string]$WardCode, [hashtable]$Used) {
    $code = $WardCode.ToLowerInvariant()
    $slug = Normalize-Slug $WardName
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = $code }

    $candidates = @(
        "mod_$slug",
        "mod_$($code.Substring(1))",
        "mod_$($code.Substring(1).Substring(0, [Math]::Min(20, $code.Length - 1)))"
    )

    foreach ($base in $candidates) {
        if ($base.Length -gt 24) { continue }
        if (-not $Used.ContainsKey($base)) {
            $Used[$base] = $true
            return $base
        }
    }

    for ($i = 4; $i -le 8; $i++) {
        $suffix = $code.Substring($code.Length - $i)
        $trim = [Math]::Min(20 - 1 - $i, $slug.Length)
        if ($trim -lt 1) { $trim = 1 }
        $short = $slug.Substring(0, $trim).TrimEnd('_')
        $candidate = "mod_${short}_$suffix"
        if ($candidate.Length -gt 24) {
            $candidate = "mod_$($code.Substring(1))"
            if ($candidate.Length -gt 24) {
                $candidate = $candidate.Substring(0, 24)
            }
        }
        if (-not $Used.ContainsKey($candidate)) {
            $Used[$candidate] = $true
            return $candidate
        }
    }

    throw "Could not allocate unique username for $WardCode $WardName"
}

$rows = Import-Csv $CsvPath | Sort-Object WD25CD
$used = @{}
$entries = New-Object System.Collections.Generic.List[object]

foreach ($row in $rows) {
    $name = ([string]$row.WD25NM).Trim()
    $code = ([string]$row.WD25CD).Trim()
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($code)) { continue }
    $username = Build-ModUsername $name $code $used
    $entries.Add([pscustomobject]@{
            Username   = $username
            Display    = "MOD_$($username.Substring(4).ToUpperInvariant())"
            WardName   = $name
            WardCode   = $code
        })
}

$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
$desktop = New-Object System.Text.StringBuilder
[void]$desktop.AppendLine('FCG UK Ward Moderator Usernames (PRIVATE - Ward Moderator Pack)')
[void]$desktop.AppendLine("Generated: $stamp")
[void]$desktop.AppendLine('Source: ONS Wards (May 2025) Names and Codes in the UK')
[void]$desktop.AppendLine("Total wards: $($entries.Count)")
[void]$desktop.AppendLine('')
[void]$desktop.AppendLine('Format: MOD_<WARD_NAME> | PERC username (mod_*) | ONS code (e/s/w/n + 8 digits)')
[void]$desktop.AppendLine('Register on Wallet tab with mod_* slug OR lowercase ONS code (Scottish: s1*).')
[void]$desktop.AppendLine('Only listed aliases receive MOD voting rights in Evolve.')
[void]$desktop.AppendLine('')

foreach ($e in $entries) {
    $fullMod = 'MOD_' + $e.WardName
    [void]$desktop.AppendLine("$fullMod | $($e.Username) | $($e.WardCode)")
}

$desktopDir = Split-Path $DesktopOut -Parent
if (-not (Test-Path $desktopDir)) { New-Item -ItemType Directory -Path $desktopDir -Force | Out-Null }
Set-Content -Path $DesktopOut -Value $desktop.ToString() -Encoding UTF8

$dartDir = Split-Path $DartOut -Parent
if (-not (Test-Path $dartDir)) { New-Item -ItemType Directory -Path $dartDir -Force | Out-Null }

$dart = New-Object System.Text.StringBuilder
[void]$dart.AppendLine('// GENERATED FILE - do not commit. Run scripts/generate_uk_ward_moderators.ps1')
[void]$dart.AppendLine('// ONS Wards (May 2025). Private moderator pack; not for public distribution.')
[void]$dart.AppendLine('')
[void]$dart.AppendLine('const Set<String> fcgUkWardModeratorUsernames = {')
foreach ($e in $entries) {
    [void]$dart.AppendLine("  '$($e.Username)',")
    $codeKey = $e.WardCode.ToLowerInvariant()
    [void]$dart.AppendLine("  '$codeKey',")
}
[void]$dart.AppendLine('};')
[void]$dart.AppendLine('')
[void]$dart.AppendLine('const Map<String, String> fcgUkWardModeratorWardNames = {')
foreach ($e in $entries) {
    $escaped = $e.WardName -replace "\\", "\\\\" -replace "'", "\\'"
    $codeKey = $e.WardCode.ToLowerInvariant()
    [void]$dart.AppendLine("  '$($e.Username)': '$escaped',")
    [void]$dart.AppendLine("  '$codeKey': '$escaped',")
}
[void]$dart.AppendLine('};')

Set-Content -Path $DartOut -Value $dart.ToString() -Encoding UTF8

$listDart = Join-Path $dartDir 'fcg_uk_ward_moderator_list.dart'
@'
/// Local full ward list - repoints at generated registry (do not commit this change).
export 'fcg_uk_ward_moderator_list_generated.dart';
'@ | Set-Content -Path $listDart -Encoding UTF8

Write-Host "Ward moderators: $($entries.Count)" -ForegroundColor Green
Write-Host "Note: fcg_uk_ward_moderator_list.dart now exports generated data - revert before git commit." -ForegroundColor Yellow
Write-Host "Desktop pack:    $DesktopOut" -ForegroundColor Green
Write-Host "Dart registry:   $DartOut (gitignored)" -ForegroundColor Green