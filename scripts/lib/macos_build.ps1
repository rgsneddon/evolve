# Shared helpers for Flutter macOS desktop packaging.

function Test-MacosBuildHost {
    if ($IsMacOS) { return $true }
    if ($env:GITHUB_ACTIONS -eq 'true' -and $env:RUNNER_OS -eq 'macOS') { return $true }
    return $false
}

function Get-FlutterMacosAppSource {
    param(
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidates = @(
        (Join-Path $Root 'build\macos\Build\Products\Release\Evolve.app'),
        (Join-Path $Root 'build\macos\Build\Products\Release\evolve.app')
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }

    $releaseDir = Join-Path $Root 'build\macos\Build\Products\Release'
    if (Test-Path $releaseDir) {
        $app = Get-ChildItem $releaseDir -Filter '*.app' -Directory -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($app) { return $app.FullName }
    }
    return $null
}

function Invoke-FlutterMacosBuild {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$FlutterExe
    )

    Set-Location $Root
    & $FlutterExe build macos --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
