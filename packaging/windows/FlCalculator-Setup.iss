#ifndef AppSource
  #define AppSource "..\build\windows\x64\runner\Release"
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{A63F494F-0ED4-4B1D-9F1A-28F8407C6A7D}
AppName=FlCalculator
AppVersion={#AppVersion}
AppPublisher=FlCalculator
DefaultDirName={localappdata}\Programs\FlCalculator
DefaultGroupName=FlCalculator
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=FlCalculator-Setup
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\flcalculator.exe

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\FlCalculator"; Filename: "{app}\flcalculator.exe"
Name: "{autodesktop}\FlCalculator"; Filename: "{app}\flcalculator.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\flcalculator.exe"; Description: "Launch FlCalculator"; Flags: nowait postinstall skipifsilent
