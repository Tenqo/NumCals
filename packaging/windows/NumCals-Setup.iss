#ifndef AppSource
  #define AppSource "..\build\windows\x64\runner\Release"
#endif

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{A63F494F-0ED4-4B1D-9F1A-28F8407C6A7D}
AppName=NumCals
AppVersion={#AppVersion}
AppPublisher=Tenqo Digital
DefaultDirName={localappdata}\Programs\NumCals
DefaultGroupName=NumCals
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=NumCals-Setup
ArchitecturesInstallIn64BitMode=x64
Compression=lzma
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\NumCals.exe

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\NumCals"; Filename: "{app}\NumCals.exe"
Name: "{autodesktop}\NumCals"; Filename: "{app}\NumCals.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NumCals.exe"; Description: "Launch NumCals"; Flags: nowait postinstall skipifsilent
