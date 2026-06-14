# Run flutter doctor with Evolve build environment loaded.
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\env.ps1"

$info = Set-BuildEnvironment
& $info.FlutterExe doctor -v