# Verify X_CLIENT_ID in grok_proxy.local.env matches the built Android APK.
param(
    [string]$ApkPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'build\app\outputs\flutter-apk\app-release.apk'),
    [string]$ExpectedClientId = 'UHhEbWFCV3BJak9JS2NraldSMVY6MTpjaQ'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$envFile = Join-Path $Root 'grok_proxy.local.env'

if (-not (Test-Path $envFile)) {
    Write-Host 'grok_proxy.local.env not found.' -ForegroundColor Red
    exit 1
}

$clientId = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*X_CLIENT_ID=(.+)$') {
        $clientId = $matches[1].Trim().Trim('"')
    }
}

if (-not $clientId -or $clientId -match 'your_x_oauth') {
    Write-Host 'X_CLIENT_ID missing or placeholder in grok_proxy.local.env.' -ForegroundColor Red
    exit 1
}

Write-Host 'grok_proxy.local.env X_CLIENT_ID:' -ForegroundColor Cyan
Write-Host "  $clientId"
Write-Host ''

if ($ExpectedClientId -and $clientId -ne $ExpectedClientId) {
    Write-Host 'Expected Client ID (portal):' -ForegroundColor Yellow
    Write-Host "  $ExpectedClientId"
    Write-Host 'MISMATCH - update grok_proxy.local.env and rebuild the APK.' -ForegroundColor Red
    exit 1
}
Write-Host 'Matches expected portal Client ID.' -ForegroundColor Green
Write-Host ''

function Test-ApkContainsClientId {
    param([string]$Path, [string]$Id)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -notlike 'lib/*/libapp.so') { continue }
            $stream = $entry.Open()
            try {
                $ms = New-Object System.IO.MemoryStream
                $stream.CopyTo($ms)
                $bytes = $ms.ToArray()
            } finally {
                $stream.Close()
            }
            $text = [System.Text.Encoding]::UTF8.GetString($bytes)
            if ($text.Contains($Id)) {
                return @{ Found = $true; Location = $entry.FullName }
            }
        }
    } finally {
        $zip.Dispose()
    }
    return @{ Found = $false; Location = '' }
}

if (Test-Path $ApkPath) {
    $match = Test-ApkContainsClientId -Path $ApkPath -Id $clientId
    if ($match.Found) {
        Write-Host "APK contains this Client ID: YES ($($match.Location))" -ForegroundColor Green
    } else {
        Write-Host 'APK contains this Client ID: NO - rebuild with scripts\build.ps1 apk' -ForegroundColor Red
    }
} else {
    Write-Host "APK not found at $ApkPath - run scripts\build.ps1 apk after setting X_CLIENT_ID." -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'In console.x.com: Keys and tokens OAuth 2.0 Client ID must match exactly.' -ForegroundColor DarkGray
Write-Host 'That app must be Native App with callback evolve://auth/callback registered.' -ForegroundColor DarkGray