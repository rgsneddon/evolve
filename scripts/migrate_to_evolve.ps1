# Copy evolve -> evolve_app and rename project branding to Evolve.
param(
    [string]$SourceRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$DestRoot = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'evolve_app')
)

$ErrorActionPreference = 'Stop'

if (Test-Path $DestRoot) {
    Write-Host "Removing existing $DestRoot" -ForegroundColor Yellow
    Remove-Item $DestRoot -Recurse -Force
}

$exclude = @('build', '.dart_tool', '.idea', 'evolve.iml', 'debug_run.log')
Write-Host "Copying $SourceRoot -> $DestRoot" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $DestRoot -Force | Out-Null
Get-ChildItem $SourceRoot -Force | Where-Object {
    $_.Name -notin $exclude
} | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $DestRoot $_.Name) -Recurse -Force
}

Set-Location $DestRoot

# Rename Dart files
$renames = @(
    @{ Old = 'lib\providers\evolve_provider.dart'; New = 'lib\providers\evolve_provider.dart' },
    @{ Old = 'lib\services\evolve_engine.dart'; New = 'lib\services\evolve_engine.dart' },
    @{ Old = 'lib\models\evolve_result.dart'; New = 'lib\models\evolve_result.dart' },
    @{ Old = 'test\ssucf_engine_test.dart'; New = 'test\evolve_engine_test.dart' }
)
foreach ($r in $renames) {
    $oldPath = Join-Path $DestRoot $r.Old
    $newPath = Join-Path $DestRoot $r.New
    if (Test-Path $oldPath) {
        Move-Item $oldPath $newPath -Force
    }
}

# Android MainActivity package path
$oldKt = Join-Path $DestRoot 'android\app\src\main\kotlin\com\rgsneddon\evolve'
$newKtDir = Join-Path $DestRoot 'android\app\src\main\kotlin\com\rgsneddon\evolve'
if (Test-Path $oldKt) {
    New-Item -ItemType Directory -Path $newKtDir -Force | Out-Null
    $kt = Get-Content (Join-Path $oldKt 'MainActivity.kt') -Raw
    $kt = $kt -replace 'com\.rgsneddon\.evolve', 'com.rgsneddon.evolve'
    Set-Content (Join-Path $newKtDir 'MainActivity.kt') $kt -NoNewline
    Remove-Item $oldKt -Recurse -Force
}

$textRoots = @('lib', 'test', 'scripts', 'tool', 'android', 'ios', 'windows', 'web', 'README.md', 'LICENSE', 'pubspec.yaml', 'Dockerfile.grok-proxy')
$replacements = @(
    @{ From = 'package:evolve/'; To = 'package:evolve/' },
    @{ From = 'EvolveProvider'; To = 'EvolveProvider' },
    @{ From = 'EvolveEngine'; To = 'EvolveEngine' },
    @{ From = 'EvolveResult'; To = 'EvolveResult' },
    @{ From = 'EvolveApp'; To = 'EvolveApp' },
    @{ From = 'evolveProvider'; To = 'evolveProvider' },
    @{ From = 'evolve_engine.dart'; To = 'evolve_engine.dart' },
    @{ From = 'evolve_provider.dart'; To = 'evolve_provider.dart' },
    @{ From = 'evolve_result.dart'; To = 'evolve_result.dart' },
    @{ From = 'com.rgsneddon.evolve'; To = 'com.rgsneddon.evolve' },
    @{ From = '@evolve_mock'; To = '@evolve_mock' },
    @{ From = '@evolve_web'; To = '@evolve_web' },
    @{ From = '@evolve_android'; To = '@evolve_android' },
    @{ From = 'Evolve-NarrativeReader'; To = 'Evolve-NarrativeReader' },
    @{ From = 'Evolve Mock User'; To = 'Evolve Mock User' },
    @{ From = 'Evolve Web Heuristic'; To = 'Evolve Web Heuristic' },
    @{ From = 'Evolve Android Heuristic'; To = 'Evolve Android Heuristic' },
    @{ From = 'evolve.exe'; To = 'evolve.exe' },
    @{ From = 'BINARY_NAME "evolve"'; To = 'BINARY_NAME "evolve"' },
    @{ From = 'project(evolve'; To = 'project(evolve' },
    @{ From = 'name: evolve'; To = 'name: evolve' },
    @{ From = '/evolve/'; To = '/evolve/' },
    @{ From = "RepoName = 'evolve'"; To = "RepoName = 'evolve'" },
    @{ From = 'evolve-$tag'; To = 'evolve-$tag' },
    @{ From = 'evolve-github-pages'; To = 'evolve-github-pages' },
    @{ From = 'evolve_local_serve'; To = 'evolve_local_serve' },
    @{ From = 'Evolve Grok Proxy'; To = 'Evolve Grok Proxy' },
    @{ From = 'Evolve'; To = 'Evolve' },
    @{ From = 'Evolve —'; To = 'Evolve —' },
    @{ From = 'Evolve '; To = 'Evolve ' },
    @{ From = 'Evolve,'; To = 'Evolve,' },
    @{ From = 'Evolve.'; To = 'Evolve.' },
    @{ From = "'Evolve'"; To = "'Evolve'" },
    @{ From = '"Evolve"'; To = '"Evolve"' },
    @{ From = 'short_name": "Evolve"'; To = 'short_name": "Evolve"' },
    @{ From = 'apple-mobile-web-app-title" content="Evolve"'; To = 'apple-mobile-web-app-title" content="Evolve"' },
    @{ From = 'android:label="Evolve"'; To = 'android:label="Evolve"' },
    @{ From = 'rgsneddon/evolve'; To = 'rgsneddon/evolve' },
    @{ From = 'rgsneddon/evolve'; To = 'rgsneddon/evolve' },
    @{ From = 'evolve'; To = 'evolve' }
)

function Update-TextFile([string]$path) {
    if (-not (Test-Path $path)) { return }
    $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
    if ($ext -in '.png', '.jpg', '.ico', '.apk', '.zip', '.exe', '.dll', '.jar', '.lock') { return }
    try {
        $raw = [IO.File]::ReadAllText($path)
    } catch {
        return
    }
    $updated = $raw
    foreach ($r in $replacements) {
        $updated = $updated.Replace($r.From, $r.To)
    }
    if ($updated -ne $raw) {
        [IO.File]::WriteAllText($path, $updated)
    }
}

foreach ($root in $textRoots) {
    $full = Join-Path $DestRoot $root
    if (-not (Test-Path $full)) { continue }
    if ((Get-Item $full).PSIsContainer) {
        Get-ChildItem $full -Recurse -File | ForEach-Object { Update-TextFile $_.FullName }
    } else {
        Update-TextFile $full
    }
}

# pubspec description
$pubspec = Join-Path $DestRoot 'pubspec.yaml'
$pub = Get-Content $pubspec -Raw
$pub = $pub -replace 'description: Evolve Chronoflux framework', 'description: Evolve — Chronoflux percent chance and social cohesion analysis.'
Set-Content $pubspec $pub -NoNewline

Write-Host "Evolve project ready at $DestRoot" -ForegroundColor Green