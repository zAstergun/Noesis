param(
    [string]$Version = "1.0.0",
    [switch]$IncludePortableZip
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

$ApkSource = Join-Path $RepoRoot "build\app\outputs\apk\release\app-release.apk"
$WinReleaseDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"

$ApkDestDir = Join-Path $RepoRoot "releases\android"
$WinDestDir = Join-Path $RepoRoot "releases\windows"

New-Item -ItemType Directory -Force -Path $ApkDestDir, $WinDestDir | Out-Null

if (Test-Path $ApkSource) {
    $ApkDest = Join-Path $ApkDestDir "noesis-v$Version-android.apk"
    Copy-Item -Path $ApkSource -Destination $ApkDest -Force
    Write-Host "APK atualizado: $ApkDest"
} else {
    Write-Warning "APK release nao encontrado em $ApkSource. Rode 'flutter build apk --release'."
}

if (Test-Path $WinReleaseDir) {
    $IssScript = Join-Path $PSScriptRoot "noesis_setup.iss"
    $IsccCandidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    )
    $IsccPath = $IsccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
    if (-not $IsccPath) {
        $IsccCmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
        if ($IsccCmd) { $IsccPath = $IsccCmd.Source }
    }

    if ($IsccPath -and (Test-Path $IssScript)) {
        $SetupDest = Join-Path $WinDestDir "noesis-v$Version-windows-x64-setup.exe"
        if (Test-Path $SetupDest) { Remove-Item -Force $SetupDest }
        & $IsccPath "/DMyAppVersion=$Version" "/DReleaseDir=$WinReleaseDir" "/DOutputDir=$WinDestDir" $IssScript
        if ($LASTEXITCODE -ne 0) {
            throw "ISCC.exe falhou ao gerar $SetupDest (codigo $LASTEXITCODE)"
        }
        $SetupHash = (Get-FileHash -Path $SetupDest -Algorithm SHA256).Hash
        $SetupSize = (Get-Item -Path $SetupDest).Length
        Write-Host "Windows Setup atualizado: $SetupDest ($SetupSize bytes, SHA-256: $SetupHash)"
    } else {
        Write-Warning "Inno Setup 6 (ISCC.exe) nao encontrado. Instale o Inno Setup 6 para gerar o instalador."
    }

    if ($IncludePortableZip) {
        $WinZipDest = Join-Path $WinDestDir "noesis-v$Version-windows-x64.zip"
        $StagingParent = Join-Path $env:TEMP ("noesis-stage-" + [Guid]::NewGuid().ToString("N"))
        $StagingDir = Join-Path $StagingParent "Noesis-Windows-x64"
        try {
            New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
            Copy-Item -Path (Join-Path $WinReleaseDir "*") -Destination $StagingDir -Recurse -Force
            if (Test-Path $WinZipDest) { Remove-Item -Force $WinZipDest }
            $TarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
            if ($TarCmd) {
                & $TarCmd.Source -a -c -f $WinZipDest -C $StagingParent "Noesis-Windows-x64"
                if ($LASTEXITCODE -ne 0) {
                    throw "tar.exe falhou ao empacotar $WinZipDest (codigo $LASTEXITCODE)"
                }
            } else {
                Compress-Archive -Path $StagingDir -DestinationPath $WinZipDest -CompressionLevel Optimal
            }
            $ZipHash = (Get-FileHash -Path $WinZipDest -Algorithm SHA256).Hash
            $ZipSize = (Get-Item -Path $WinZipDest).Length
            Write-Host "Windows ZIP atualizado: $WinZipDest ($ZipSize bytes, SHA-256: $ZipHash)"
        } finally {
            if (Test-Path $StagingParent) { Remove-Item -Recurse -Force $StagingParent }
        }
    }
} else {
    Write-Warning "Windows release nao encontrado em $WinReleaseDir. Rode 'flutter build windows --release'."
}
