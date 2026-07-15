# Build Evolve for one platform: web | windows | android | apk
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('web', 'windows', 'android', 'apk')]
    [string]$Platform,

    [switch]$DebugBuild
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\env.ps1"

$info = Set-BuildEnvironment
$flutter = $info.FlutterExe
$mode = if ($DebugBuild) { '--debug' } else { '--release' }

Set-Location $Root

switch ($Platform) {
    'web' {
        & $flutter build web $mode --base-href /evolve/ --no-wasm-dry-run
        Write-Host ''
        Write-Host 'Output: build\web' -ForegroundColor Green
        Write-Host 'Serve:  flutter run -d web-server --web-port 8080 --release' -ForegroundColor Green
    }
    'windows' {
        & $flutter build windows $mode
        $envSrc = Join-Path $Root 'grok_proxy.local.env'
        $envDst = Join-Path $Root 'build\windows\x64\runner\Release\grok_proxy.local.env'
        if ((Test-Path $envSrc) -and (Test-Path (Split-Path $envDst -Parent))) {
            Copy-Item $envSrc $envDst -Force
            Write-Host 'Copied grok_proxy.local.env beside evolve.exe' -ForegroundColor Cyan
        } else {
            Write-Host 'No grok_proxy.local.env — Windows Grok will use mock X sign-in.' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host 'Output: build\windows\x64\runner\Release\evolve.exe' -ForegroundColor Green
    }
    { $_ -in 'android', 'apk' } {
        if (-not $info.JavaHome) {
            throw 'JDK required for Android builds. Run scripts\setup_build_tooling.ps1 first.'
        }
        . "$PSScriptRoot\lib\grok_env.ps1"
        $defineArgs = @()
        if (Import-GrokLocalEnv -Root $Root) {
            foreach ($key in @('X_CLIENT_ID', 'X_CLIENT_SECRET', 'XAI_API_KEY')) {
                $val = (Get-Item "env:$key" -ErrorAction SilentlyContinue).Value
                if ($val) { $defineArgs += "--dart-define=$key=$val" }
            }
            Write-Host 'Baked Grok OAuth credentials into Android build (dart-define).' -ForegroundColor Cyan
        } else {
            Write-Host 'No grok_proxy.local.env — Android Grok will use mock X sign-in.' -ForegroundColor Yellow
        }
        $apkDefineArgs = @('--android-skip-build-dependency-validation') + $defineArgs
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        # Flutter/Gradle write advisories to stderr; gate success on exit code only.
        & $flutter build apk $mode @apkDefineArgs 2>&1 | ForEach-Object {
          if ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-Host $_.ToString() -ForegroundColor Yellow
          } else { $_ }
        }
        $apkExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEap
        if ($apkExit -ne 0) { exit $apkExit }
        Write-Host ''
        Write-Host 'Output: build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Green
    }
}