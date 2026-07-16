; Evolve Chronoflux Windows installer (Inno Setup).
; Build: scripts\build_windows_installer.ps1

#ifndef EvolveVersion
  #define EvolveVersion "2.2.9"
#endif
#ifndef EvolveBuild
  #define EvolveBuild "59"
#endif

#define EvolveAppName "Evolve Chronoflux"
#define EvolvePublisher "Evolve Chronoflux"
#define EvolveExeName "evolve.exe"
#define EvolveReleaseDir "..\..\build\windows\x64\runner\Release"
#define EvolveOutputBase "evolve-v" + EvolveVersion + "-windows-x64-setup"

[Setup]
AppId={{A7F3C2E1-9B4D-4E8A-B1C6-EVOLVE229}
AppName={#EvolveAppName}
AppVersion={#EvolveVersion}
AppVerName={#EvolveAppName} {#EvolveVersion} (build {#EvolveBuild})
AppPublisher={#EvolvePublisher}
DefaultDirName={autopf}\{#EvolveAppName}
DefaultGroupName={#EvolveAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\build\installer\windows
OutputBaseFilename={#EvolveOutputBase}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\{#EvolveExeName}
VersionInfoVersion={#EvolveVersion}.{#EvolveBuild}
VersionInfoCompany={#EvolvePublisher}
VersionInfoDescription={#EvolveAppName} Windows installer
VersionInfoProductName={#EvolveAppName}
VersionInfoProductVersion={#EvolveVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#EvolveReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#EvolveAppName}"; Filename: "{app}\{#EvolveExeName}"
Name: "{autodesktop}\{#EvolveAppName}"; Filename: "{app}\{#EvolveExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#EvolveExeName}"; Description: "{cm:LaunchProgram,{#StringChange(EvolveAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent