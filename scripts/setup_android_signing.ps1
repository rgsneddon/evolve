# Create or verify Android release keystore for Evolve APK signing.
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\android_sign.ps1"

$keyPropsExample = Join-Path $Root 'android\key.properties.example'
$keyProps = Join-Path $Root 'android\key.properties'
$keystore = Join-Path $Root 'android\evolve-release.keystore'
$keyAlias = 'evolve-release'

if (-not (Test-Path $keyProps)) {
    if (-not (Test-Path $keyPropsExample)) {
        throw 'Missing android/key.properties.example'
    }
    Copy-Item $keyPropsExample $keyProps
    Write-Host "Created $keyProps - set storePassword and keyPassword before building." -ForegroundColor Yellow
}

$props = Import-AndroidKeyProperties -Root $Root
if ($props.storeFile) {
    $storePath = $props.storeFile
    if (-not [IO.Path]::IsPathRooted($storePath)) {
        $storePath = Join-Path (Join-Path $Root 'android') $storePath
    }
    $keystore = $storePath
}

if ((Test-Path $keystore) -and -not $Force) {
    Write-Host "Keystore already exists: $keystore" -ForegroundColor Green
} else {
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if (-not $keytool) {
        throw 'keytool not found. Install a JDK and ensure keytool is on PATH.'
    }

    $storePass = $props.storePassword
    $keyPass = $props.keyPassword
    if (-not $storePass -or $storePass -eq 'your_keystore_password') {
        throw 'Set storePassword in android/key.properties before generating the keystore.'
    }
    if (-not $keyPass -or $keyPass -eq 'your_key_password') {
        $keyPass = $storePass
    }

    if (Test-Path $keystore) { Remove-Item $keystore -Force }

    Write-Host "Generating release keystore: $keystore" -ForegroundColor Cyan
    & keytool -genkeypair `
        -v `
        -keystore $keystore `
        -alias $keyAlias `
        -keyalg RSA `
        -keysize 2048 `
        -validity 10000 `
        -storepass $storePass `
        -keypass $keyPass `
        -dname 'CN=Evolve Chronoflux, OU=Mobile, O=Evolve, L=UK, ST=UK, C=GB'
    if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }
    Write-Host 'Keystore created.' -ForegroundColor Green
}

if (Test-AndroidReleaseKeystoreConfigured -Root $Root) {
    Write-Host 'Android release signing is configured.' -ForegroundColor Green
} else {
    throw 'key.properties or keystore path is still invalid.'
}