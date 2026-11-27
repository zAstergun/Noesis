; Script de instalação oficial do Noesis (Inno Setup 6)
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#ifndef ReleaseDir
  #define ReleaseDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
  #define OutputDir "..\releases\windows"
#endif

[Setup]
AppId={{8C4E3B72-5A19-4F0A-9E32-6D1A4B2F9011}
AppName=Noesis
AppVersion={#MyAppVersion}
AppVerName=Noesis {#MyAppVersion}
AppPublisher=me.asterdev
AppPublisherURL=https://noesis.asterdev.me
AppSupportURL=https://github.com/zAstergun/Noesis
AppUpdatesURL=https://github.com/zAstergun/Noesis/releases
DefaultDirName={autopf}\Noesis
DefaultGroupName=Noesis
AllowNoIcons=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir={#OutputDir}
OutputBaseFilename=noesis-v{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\noesis.exe
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany=me.asterdev
VersionInfoDescription=Instalador oficial do Noesis para Windows (x64)
VersionInfoProductName=Noesis
VersionInfoProductVersion={#MyAppVersion}.0
VersionInfoCopyright=Copyright (C) 2026 me.asterdev

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Noesis"; Filename: "{app}\noesis.exe"
Name: "{autodesktop}\Noesis"; Filename: "{app}\noesis.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\noesis.exe"; Description: "{cm:LaunchProgram,Noesis}"; Flags: nowait postinstall skipifsilent
