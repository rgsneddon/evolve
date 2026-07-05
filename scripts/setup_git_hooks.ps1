# Install git hooks so every push auto-bumps build from the latest known version.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$hooksDir = Join-Path $Root '.git\hooks'
if (-not (Test-Path $hooksDir)) {
    throw "Not a git repository: $Root"
}

$prePush = @'
#!/bin/sh
# Auto-bump Evolve build number before each push (consecutive from origin/main + tags).
ROOT="$(git rev-parse --show-toplevel)"
has_outgoing=0
while read local_ref local_sha remote_ref remote_sha; do
  if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
    continue
  fi
  if [ "$remote_sha" = "0000000000000000000000000000000000000000" ]; then
    has_outgoing=1
    break
  fi
  if [ "$local_sha" != "$remote_sha" ]; then
    has_outgoing=1
    break
  fi
done
if [ "$has_outgoing" -eq 0 ]; then
  exit 0
fi

git fetch origin main --quiet 2>/dev/null || true
if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/bump_version.ps1" -EnsureConsecutive -BuildOnly || exit 1
else
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$ROOT/scripts/bump_version.ps1" -EnsureConsecutive -BuildOnly || exit 1
fi
git add pubspec.yaml lib/perc/perc_app_version.dart version.json downloads/index.html 2>/dev/null
if ! git diff --cached --quiet; then
  VERSION=$(grep -E '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//')
  git commit -m "chore: bump version to $VERSION"
fi
exit 0
'@

Set-Content -Path (Join-Path $hooksDir 'pre-push') -Value $prePush -NoNewline -Encoding ascii
Write-Host 'Installed .git/hooks/pre-push (consecutive build bump from remote max on every push)' -ForegroundColor Green