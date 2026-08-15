# Shared environment helpers for Evolve Flutter builds on Windows.

function Get-FlutterExe {
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'flutter\bin\flutter.bat'))
    }
    $candidates.Add('C:\src\flutter\bin\flutter.bat')
    if ($env:USERPROFILE) {
        $candidates.Add((Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat'))
        $candidates.Add((Join-Path $env:USERPROFILE 'flutter\bin\flutter'))
    }
    if ($env:HOME) {
        $candidates.Add((Join-Path $env:HOME 'flutter\bin\flutter'))
    }
    $candidates.Add('/opt/homebrew/bin/flutter')
    $candidates.Add('/usr/local/bin/flutter')
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) { return $path }
    }
    $onPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $onPathBat = Get-Command flutter.bat -ErrorAction SilentlyContinue
    if ($onPathBat) { return $onPathBat.Source }
    throw 'Flutter not found. Install Flutter and add it to PATH, or place it at C:\src\flutter.'
}

function Get-JdkHome {
    $user = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ($user -and ((Test-Path (Join-Path $user 'bin\java.exe')) -or (Test-Path (Join-Path $user 'bin\java')))) { return $user }

    $machine = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    if ($machine -and ((Test-Path (Join-Path $machine 'bin\java.exe')) -or (Test-Path (Join-Path $machine 'bin\java')))) { return $machine }

    if ($env:JAVA_HOME -and ((Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe')) -or (Test-Path (Join-Path $env:JAVA_HOME 'bin\java')))) {
        return $env:JAVA_HOME
    }

    foreach ($macJdk in @(
        '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home',
        '/opt/homebrew/opt/openjdk@17',
        '/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home'
    )) {
        if (Test-Path (Join-Path $macJdk 'bin/java')) { return $macJdk }
    }

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
        if ((Test-Path (Join-Path $javaHome 'bin\java.exe')) -or (Test-Path (Join-Path $javaHome 'bin\java'))) {
            return $javaHome
        }
    }

    return $null
}

function Get-AndroidSdkRoot {
    $candidates = @(
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_SDK_ROOT', 'User'),
        [Environment]::GetEnvironmentVariable('ANDROID_HOME', 'Machine'),
        $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Android\Sdk' } else { $null }),
        $(if ($env:HOME) { Join-Path $env:HOME 'Library\Android\sdk' } else { $null })
    ) | Where-Object { $_ }

    foreach ($root in $candidates) {
        if (Test-Path (Join-Path $root 'platform-tools')) { return $root }
    }
    if ($env:LOCALAPPDATA) {
        return Join-Path $env:LOCALAPPDATA 'Android\Sdk'
    }
    if ($env:HOME) {
        return Join-Path $env:HOME 'Library\Android\sdk'
    }
    return $null
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