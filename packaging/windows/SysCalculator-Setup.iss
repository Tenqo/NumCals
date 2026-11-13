#ifndef AppSource
  #define AppSource "..\build\windows\x64\runner\Release"
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{A63F494F-0ED4-4B1D-9F1A-28F8407C6A7D}
AppName=SysCalculator
AppVersion={#AppVersion}
AppPublisher=Tenqo Digital
DefaultDirName={localappdata}\Programs\SysCalculator
DefaultGroupName=SysCalculator
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=SysCalculator-Setup
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\SysCalculator.exe

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SysCalculator"; Filename: "{app}\SysCalculator.exe"
Name: "{autodesktop}\SysCalculator"; Filename: "{app}\SysCalculator.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\SysCalculator.exe"; Description: "Launch SysCalculator"; Flags: nowait postinstall skipifsilent
