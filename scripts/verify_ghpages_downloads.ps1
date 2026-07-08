param(
  [string]$Version = '4.0.3',
  [string]$Build = '',
  [string]$ScratchDir = '',
  [string]$Owner = 'rgsneddon',
  [string]$RepoName = 'evolve'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

if (-not $Build) {
  $versionJsonPath = Join-Path $Root 'version.json'
  if (Test-Path $versionJsonPath) {
    $Build = (Get-Content $versionJsonPath -Raw | ConvertFrom-Json).build_number
  }
}

if (-not $ScratchDir) {
  $ScratchDir = Join-Path $env:TEMP 'grok-goal-ghpages-verify'
}
New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

$logPath = Join-Path $ScratchDir 'deploy_downloads.log'
$utf8 = New-Object System.Text.UTF8Encoding $false
$downloadsUrl = "https://$Owner.github.io/$RepoName/downloads/"
$versionUrl = "https://$Owner.github.io/$RepoName/version.json"

$lines = @(
  "=== gh-pages downloads verify $(Get-Date -Format o) ==="
  "downloads_url=$downloadsUrl"
  "expected_version=v$Version"
  "expected_build=$Build"
)

$failures = 0
try {
  $resp = Invoke-WebRequest -Uri $downloadsUrl -TimeoutSec 90 -UseBasicParsing
  $html = $resp.Content
  $snippetPath = Join-Path $ScratchDir 'downloads_page_snippet.html'
  $snippet = if ($html.Length -gt 4096) { $html.Substring(0, 4096) } else { $html }
  [System.IO.File]::WriteAllText($snippetPath, $snippet, $utf8)
  $lines += "downloads_status=$($resp.StatusCode)"

  if ($html -notmatch "v$([regex]::Escape($Version))") {
    $failures++
    $lines += "FAIL: downloads HTML missing v$Version"
  } else {
    $lines += "OK: downloads HTML contains v$Version"
  }

  if ($Build -and $html -notmatch "build\s+$Build") {
    $failures++
    $lines += "FAIL: downloads HTML missing build $Build"
  } elseif ($Build) {
    $lines += "OK: downloads HTML contains build $Build"
  }

  if ($html -match 'v4\.0\.2') {
    $failures++
    $lines += 'FAIL: downloads HTML still references v4.0.2'
  } else {
    $lines += 'OK: no v4.0.2 reference in downloads HTML'
  }
} catch {
  $failures++
  $lines += "FAIL: downloads fetch -> $($_.Exception.Message)"
}

try {
  $versionResp = Invoke-WebRequest -Uri $versionUrl -TimeoutSec 60 -UseBasicParsing
  $versionBody = $versionResp.Content
  $versionPath = Join-Path $ScratchDir 'pages_version_live.json'
  [System.IO.File]::WriteAllText($versionPath, $versionBody, $utf8)
  $lines += "pages_version_status=$($versionResp.StatusCode)"
  $vj = $versionBody | ConvertFrom-Json
  if ($vj.version -ne $Version) {
    $failures++
    $lines += "FAIL: pages version.json version=$($vj.version) expected $Version"
  } else {
    $lines += "OK: pages version.json version=$($vj.version)"
  }
  if ($Build -and "$($vj.build_number)" -ne "$Build") {
    $failures++
    $lines += "FAIL: pages version.json build=$($vj.build_number) expected $Build"
  } elseif ($Build) {
    $lines += "OK: pages version.json build=$($vj.build_number)"
  }
} catch {
  $failures++
  $lines += "FAIL: pages version.json fetch -> $($_.Exception.Message)"
}

$lines += "failures=$failures"
[System.IO.File]::WriteAllLines($logPath, $lines, $utf8)

if ($failures -gt 0) {
  Write-Error "gh-pages downloads verification failed ($failures). See $logPath"
  exit 1
}

Write-Host "gh-pages downloads verified: $downloadsUrl (v$Version build $Build)" -ForegroundColor Green