# Install git hooks so every push auto-bumps patch+build and commits if needed.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$hooksDir = Join-Path $Root '.git\hooks'
if (-not (Test-Path $hooksDir)) {
    throw "Not a git repository: $Root"
}

$prePush = @'
#!/bin/sh
# Auto-bump Evolve version before each push (patch +1, build +1).
ROOT="$(git rev-parse --show-toplevel)"
if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/bump_version.ps1" || exit 1
else
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/bump_version.ps1" || exit 1
fi
git add pubspec.yaml lib/perc/perc_app_version.dart version.json downloads/index.html 2>/dev/null
if ! git diff --cached --quiet; then
  VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
  git commit -m "chore: bump version to $VERSION"
fi
exit 0
'@

Set-Content -Path (Join-Path $hooksDir 'pre-push') -Value $prePush -NoNewline -Encoding ascii
Write-Host 'Installed .git/hooks/pre-push (auto bump patch+build on every push)' -ForegroundColor Green