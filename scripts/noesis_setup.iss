; Official Noesis Windows Desktop Installer script (Inno Setup 6)
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
ShowLanguageDialog=yes
LanguageDetectionMethod=uilanguage
CloseApplications=yes
VersionInfoVersion={#MyAppVersion}.0
VersionInfoCompany=me.asterdev
VersionInfoDescription=Noesis Windows Desktop Installer (x64)
VersionInfoProductName=Noesis
VersionInfoProductVersion={#MyAppVersion}.0
VersionInfoCopyright=Copyright (C) 2026 me.asterdev

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "japanese"; MessagesFile: "compiler:Languages\Japanese.isl"
Name: "chinesesimplified"; MessagesFile: "isl\ChineseSimplified.isl"
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "vietnamese"; MessagesFile: "isl\Vietnamese.isl"
Name: "indonesian"; MessagesFile: "isl\Indonesian.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "german"; MessagesFile: "compiler:Languages\German.isl"
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "dutch"; MessagesFile: "compiler:Languages\Dutch.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "portuguese"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Noesis"; Filename: "{app}\noesis.exe"
Name: "{autodesktop}\Noesis"; Filename: "{app}\noesis.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\noesis.exe"; Description: "{cm:LaunchProgram,Noesis}"; Flags: nowait postinstall skipifsilent
