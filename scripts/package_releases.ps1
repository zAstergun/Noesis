param(
    [string]$Version = "1.0.0"
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
    $WinZipDest = Join-Path $WinDestDir "noesis-v$Version-windows-x64.zip"
    $StagingParent = Join-Path $env:TEMP ("noesis-stage-" + [Guid]::NewGuid().ToString("N"))
    $StagingDir = Join-Path $StagingParent "Noesis-Windows-x64"
    try {
        New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null
        Copy-Item -Path (Join-Path $WinReleaseDir "*") -Destination $StagingDir -Recurse -Force
        if (Test-Path $WinZipDest) { Remove-Item -Force $WinZipDest }
        Compress-Archive -Path $StagingDir -DestinationPath $WinZipDest -CompressionLevel Optimal
        Write-Host "Windows ZIP atualizado: $WinZipDest"
    } finally {
        if (Test-Path $StagingParent) { Remove-Item -Recurse -Force $StagingParent }
    }
} else {
    Write-Warning "Windows release nao encontrado em $WinReleaseDir. Rode 'flutter build windows --release'."
}
