# Copy build/web output to repo root for GitHub Pages (main branch).
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$webDir = Join-Path $Root 'build\web'
if (-not (Test-Path $webDir)) {
    throw "Missing $webDir - run scripts\build.ps1 web first."
}
Copy-Item -Path (Join-Path $webDir '*') -Destination $Root -Recurse -Force
$nojekyll = Join-Path $Root '.nojekyll'
if (-not (Test-Path $nojekyll)) {
    New-Item -ItemType File -Path $nojekyll -Force | Out-Null
}
Write-Host "Synced $webDir -> $Root" -ForegroundColor Green