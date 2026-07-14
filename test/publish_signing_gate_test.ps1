# Publish signing gate — dot-source wiring and SkipBuild-safe artifact probe.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$scratch = if ($env:GROK_GOAL_SCRATCH) { $env:GROK_GOAL_SCRATCH } else { Join-Path $env:TEMP 'grok-goal-publish-gate' }
New-Item -ItemType Directory -Path $scratch -Force | Out-Null

$publish = Get-Content (Join-Path $Root 'scripts\publish_github_release.ps1') -Raw
if ($publish -notmatch 'release_signing_status\.ps1') {
    throw 'publish_github_release.ps1 must dot-source release_signing_status.ps1'
}
if ($publish -notmatch 'Assert-PublishReleaseSigningGate') {
    throw 'publish_github_release.ps1 must call Assert-PublishReleaseSigningGate'
}
if ($publish -notmatch 'build\\downloads\\v\$versionNoV[\s\S]{0,600}Assert-PublishReleaseSigningGate') {
    throw 'Assert-PublishReleaseSigningGate must run on installerDir before packaging (SkipBuild path included)'
}

# Mirror publish script dot-source chain for the gate function.
. (Join-Path $Root 'scripts\lib\code_sign.ps1')
. (Join-Path $Root 'scripts\lib\android_sign.ps1')
. (Join-Path $Root 'scripts\lib\release_signing_status.ps1')

$caught = $false
try {
    Assert-PublishReleaseSigningGate -Root $Root -Version '4.1.5'
} catch {
    $caught = $true
    if ("$_" -notmatch 'Release publish blocked') {
        throw "Expected publish gate block, got: $_"
    }
    if ("$_" -match 'CommandNotFoundException|Get-ReleaseSigningStatus') {
        throw "Gate must not throw CommandNotFoundException: $_"
    }
    if ("$_" -notmatch 'Windows setup is not Authenticode-signed') {
        throw "Gate must report unsigned Windows setup: $_"
    }
}
if (-not $caught) {
    throw 'Assert-PublishReleaseSigningGate should block unsigned v4.1.5 Windows setup'
}

@(
    "dot_source_release_signing_status=True"
    "gate_after_installer_dir=True"
    "unsigned_windows_blocked=True"
    "command_not_found=False"
) | Set-Content (Join-Path $scratch 'publish_signing_gate_test.log') -Encoding utf8

Write-Host 'publish_signing_gate_test PASS' -ForegroundColor Green