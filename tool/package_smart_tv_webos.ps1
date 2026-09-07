param(
    [string]$OutputDir = "build/smart_tv_out"
)

$ErrorActionPreference = "Stop"
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - LG webOS Smart TV Packaging Tool" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "`nPackaging smart_tv directory into webOS IPK..." -ForegroundColor Yellow

$aresPackageCmd = Get-Command "ares-package" -ErrorAction SilentlyContinue
if (-not $aresPackageCmd) {
    # Check default LG webOS SDK installation path
    $defaultAresPath = "C:\webOS_TV_SDK\CLI\bin\ares-package.bat"
    if (Test-Path $defaultAresPath) {
        $aresPackageCmd = $defaultAresPath
    } else {
        throw "ares-package CLI not found in PATH or C:\webOS_TV_SDK\CLI\bin. Please ensure webOS TV SDK is installed."
    }
}

& $aresPackageCmd smart_tv -o $OutputDir
if ($LASTEXITCODE -ne 0) {
    throw "ares-package failed with exit code $LASTEXITCODE"
}

$ipkFile = Get-ChildItem -Path $OutputDir -Filter "*.ipk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ipkFile) {
    $sizeMB = [math]::Round($ipkFile.Length / 1MB, 2)
    Write-Host "`nSuccessfully created LG webOS package:" -ForegroundColor Green
    Write-Host "  $($ipkFile.FullName) ($sizeMB MB)" -ForegroundColor White
    Write-Host "You can deploy this .ipk directly to your LG TV using webOS Dev Manager or ares-install." -ForegroundColor Cyan
}
