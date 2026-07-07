param(
  [string]$Version = '4.0.0',
  [string]$ScratchDir = '',
  [string]$RepoName = 'evolve'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"
. "$PSScriptRoot\lib\github.ps1"

$tag = if ($Version -match '^v') { $Version } else { "v$Version" }
$owner = Get-GitHubOwner -Root $Root
$head = (git -C $Root rev-parse HEAD).Trim()

if (-not $ScratchDir) {
  $ScratchDir = Join-Path $env:TEMP 'grok-goal-release-verify'
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

$utf8 = New-Object System.Text.UTF8Encoding $false
$probePath = Join-Path $ScratchDir 'release_assets_probe.log'
$htmlPath = Join-Path $ScratchDir 'release_page_snippet.html'
$apiPath = Join-Path $ScratchDir 'release_api.json'

$lines = @(
  "=== release verify $(Get-Date -Format o) ==="
  "tag=$tag"
  "owner=$owner"
  "repo=$RepoName"
  "git_head=$head"
)

$env:GH_TOKEN = Get-GitHubToken
$releaseJson = gh api "repos/$owner/$RepoName/releases/tags/$tag" 2>&1
if ($LASTEXITCODE -ne 0) {
  $lines += "FAIL: gh api release lookup exit $LASTEXITCODE"
  $lines += $releaseJson
  [System.IO.File]::WriteAllLines($probePath, $lines, $utf8)
  exit 1
}

$release = $releaseJson | ConvertFrom-Json
$release | ConvertTo-Json -Depth 6 | Set-Content $apiPath -Encoding utf8

$lines += "release_id=$($release.id)"
$lines += "draft=$($release.draft)"
$lines += "published_at=$($release.published_at)"
$lines += "asset_count=$($release.assets.Count)"

if ($release.draft) {
  $lines += 'FAIL: release is still a draft'
  [System.IO.File]::WriteAllLines($probePath, $lines, $utf8)
  exit 1
}

$tagCommit = (git -C $Root rev-parse "${tag}^{commit}" 2>$null).Trim()
if (-not $tagCommit) {
  $lines += "WARN: local tag $tag not found; skipping tag commit equality"
} elseif ($tagCommit -ne $head) {
  $lines += "WARN: tag commit $tagCommit differs from HEAD $head (fixture-only commits may follow release tag)"
} else {
  $lines += "tag_commit_matches_head=true"
}

$failures = 0
foreach ($asset in $release.assets) {
  $url = $asset.browser_download_url
  try {
    $resp = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 60 -UseBasicParsing
    $lines += "OK $($asset.name) -> $($resp.StatusCode) size=$($asset.size)"
  } catch {
    $failures++
    $lines += "FAIL $($asset.name) -> $($_.Exception.Message)"
  }
}

$releaseUrl = "https://github.com/$owner/$RepoName/releases/tag/$tag"
try {
  $page = Invoke-WebRequest -Uri $releaseUrl -TimeoutSec 60 -UseBasicParsing
  $snippet = $page.Content
  if ($snippet.Length -gt 2048) { $snippet = $snippet.Substring(0, 2048) }
  [System.IO.File]::WriteAllText($htmlPath, $snippet, $utf8)
  $hasSorry = $page.Content -match 'Sorry, something went wrong|No results found'
  $lines += "release_page_status=$($page.StatusCode)"
  $lines += "release_page_spa_error=$hasSorry"
  $lines += "release_page_note=SPA widget errors do not block asset downloads; API probe is authoritative"
} catch {
  $lines += "release_page_fetch_fail=$($_.Exception.Message)"
  $failures++
}

$lines += "asset_probe_failures=$failures"
[System.IO.File]::WriteAllLines($probePath, $lines, $utf8)

if ($failures -gt 0) {
  Write-Error "Release asset probe failed ($failures failures). See $probePath"
  exit 1
}

Write-Host "Release verified: $tag ($($release.assets.Count) assets, probe log $probePath)" -ForegroundColor Green