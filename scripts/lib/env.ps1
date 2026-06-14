# Shared environment helpers for Evolve Flutter builds on Windows.

function Get-FlutterExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat'),
        'C:\src\flutter\bin\flutter.bat',
        (Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat')
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    $onPath = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    throw 'Flutter not found. Install Flutter and add it to PATH, or place it at C:\src\flutter.'
}

function Get-JdkHome {
    $user = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ($user -and (Test-Path (Join-Path $user 'bin\java.exe'))) { return $user }

    $machine = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($machine -and (Test-Path (Join-Path $machine 'bin\java.exe'))) { return $machine }

    $microsoftJdkRoot = 'C:\Program Files\Microsoft'
    if (Test-Path $microsoftJdkRoot) {
        $jdk = Get-ChildItem $microsoftJdkRoot -Directory -Filter 'jdk-*' |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($jdk -and (Test-Path (Join-Path $jdk.FullName 'bin\java.exe'))) {
            return $jdk.FullName
        }
    }

    $java = Get-Command java -ErrorAction SilentlyContinue
    if ($java) {
        $javaHome = Split-Path (Split-Path $java.Source -Parent) -Parent
        if (Test-Path (Join-Path $javaHome 'bin\java.exe')) { return $javaHome }
    }

    return $null
}

function Get-AndroidSdkRoot {
    $candidates = @(
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'Machine'),
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    ) | Where-Object { $_ }

    foreach ($root in $candidates) {
        if (Test-Path (Join-Path $root 'platform-tools')) { return $root }
    }
    return Join-Path $env:LOCALAPPDATA 'Android\Sdk'
}

function Get-EdgeExecutable {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Add-PathEntry {
    param(
        [string]$PathValue,
        [string]$Entry
    )
    if ([string]::IsNullOrWhiteSpace($Entry)) { return $PathValue }
    if ($PathValue -like "*$Entry*") { return $PathValue }
    if ([string]::IsNullOrWhiteSpace($PathValue)) { return $Entry }
    return "$PathValue;$Entry"
}

function Set-BuildEnvironment {
    param(
        [switch]$Persist
    )

    $flutterExe = Get-FlutterExe
    $flutterBin = Split-Path $flutterExe -Parent
    $jdkHome = Get-JdkHome
    $sdkRoot = Get-AndroidSdkRoot
    $cmdlineBin = Join-Path $sdkRoot 'cmdline-tools\latest\bin'
    $platformTools = Join-Path $sdkRoot 'platform-tools'
    $edge = Get-EdgeExecutable

    $env:Path = Add-PathEntry $env:Path $flutterBin
    if ($jdkHome) {
        $env:JAVA_HOME = $jdkHome
        $env:Path = Add-PathEntry $env:Path (Join-Path $jdkHome 'bin')
    }
    $env:ANDROID_HOME = $sdkRoot
    $env:ANDROID_SDK_ROOT = $sdkRoot
    $env:Path = Add-PathEntry $env:Path $cmdlineBin
    $env:Path = Add-PathEntry $env:Path $platformTools
    if ($edge) { $env:CHROME_EXECUTABLE = $edge }

    if ($Persist) {
        if ($jdkHome) {
            [Environment]::SetEnvironmentVariable('JAVA_HOME', $jdkHome, 'User')
        }
        [Environment]::SetEnvironmentVariable('ANDROID_HOME', $sdkRoot, 'User')
        [Environment]::SetEnvironmentVariable('ANDROID_SDK_ROOT', $sdkRoot, 'User')

        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $userPath = Add-PathEntry $userPath $flutterBin
        if ($jdkHome) {
            $userPath = Add-PathEntry $userPath (Join-Path $jdkHome 'bin')
        }
        $userPath = Add-PathEntry $userPath $cmdlineBin
        $userPath = Add-PathEntry $userPath $platformTools
        [Environment]::SetEnvironmentVariable('Path', $userPath, 'User')

        & $flutterExe config --android-sdk $sdkRoot | Out-Null
    }

    return [PSCustomObject]@{
        FlutterExe = $flutterExe
        JavaHome   = $jdkHome
        AndroidSdk = $sdkRoot
        Edge       = $edge
    }
}