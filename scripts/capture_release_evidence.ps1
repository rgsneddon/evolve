param(
  [string]$ScratchDir = "",
  [string]$BaseRef = "3d09a3f",
  [string]$Version = "4.0.0"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

if (-not $ScratchDir) {
  $ScratchDir = Join-Path $env:TEMP "grok-goal-release-evidence"
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding $false
$releaseFiles = @(
  "pubspec.yaml", "lib/perc/perc_app_version.dart", "version.json",
  "README.md", "privacy_policy.txt", "download.html", "downloads/index.html",
  "installer/android/evolve-v$Version-android.json", "perc_chain/fixtures/relay_after_send.json"
)

$changed = @(
  "=== CHANGED FILES (evolve_app git diff $BaseRef..HEAD) ==="
  "repository=$RepoRoot"
  "note=harness workspace C:\Users\rgsne tracks .grok only; mirrored to goal/evolve_app_CHANGED_FILES.log"
)
$changed += git log --oneline "$BaseRef..HEAD"
$changed += ""
$changed += git diff --stat "$BaseRef..HEAD"
$changed += ""
$changed += git diff --name-only "$BaseRef..HEAD" | ForEach-Object { "evolve_app/$_" }

$patch = (git diff "$BaseRef..HEAD" -- @releaseFiles | Out-String).TrimEnd()
$full = (git diff "$BaseRef..HEAD" | Out-String).TrimEnd()

[System.IO.File]::WriteAllLines((Join-Path $ScratchDir "CHANGED_FILES.log"), $changed, $utf8)
[System.IO.File]::WriteAllText((Join-Path $ScratchDir "PATCH_DELTA.diff"), $patch, $utf8)
[System.IO.File]::WriteAllText((Join-Path $ScratchDir "evolve_app_full.patch"), $full, $utf8)

$goalDirs = @(
  "C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne\019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal",
  "C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne\019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal"
)
foreach ($goalDir in $goalDirs) {
  if (-not (Test-Path $goalDir)) { continue }
  [System.IO.File]::WriteAllLines((Join-Path $goalDir "evolve_app_CHANGED_FILES.log"), $changed, $utf8)
  [System.IO.File]::WriteAllText((Join-Path $goalDir "evolve_app_release.patch"), $patch, $utf8)
}

$paths = git diff --name-only "$BaseRef..HEAD" | ForEach-Object { @{ path = "evolve_app/$_"; status = "modified" } }
$manifest = @{
  exported_utc = (Get-Date).ToUniversalTime().ToString("o")
  release = $Version
  build = (Get-Content version.json -Raw | ConvertFrom-Json).build_number
  repo = $RepoRoot
  git_base = $BaseRef
  git_head = (git rev-parse HEAD).Trim()
  patch_file = "goal/evolve_app_release.patch"
  deliverables = @($paths)
  scratch_evidence = @{
    test_results = "implementer/test_results.log"
    changed_files = "implementer/CHANGED_FILES.log"
    patch_delta = "implementer/PATCH_DELTA.diff"
    full_patch = "implementer/evolve_app_full.patch"
  }
}
foreach ($goalDir in $goalDirs) {
  if (-not (Test-Path $goalDir)) { continue }
  ($manifest | ConvertTo-Json -Depth 6) | Set-Content (Join-Path $goalDir "deliverables_manifest.json") -Encoding utf8
}

Write-Host "Release evidence mirrored to $ScratchDir and goal session"