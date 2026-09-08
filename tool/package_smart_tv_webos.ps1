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

$oldIpk = Join-Path $OutputDir "com.goatplayer.tv_1.0.0_all.ipk"
if (Test-Path $oldIpk) { Remove-Item -Force $oldIpk }

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

# Clean webOS staging (exclude Tizen configs)
$tempStaging = "build/webos_smart_tv_staging"
if (Test-Path $tempStaging) { Remove-Item -Recurse -Force $tempStaging }
New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

Copy-Item -Path "smart_tv/*" -Destination $tempStaging -Recurse -Force
if (Test-Path "$tempStaging/config.xml") { Remove-Item -Force "$tempStaging/config.xml" }
if (Test-Path "$tempStaging/tizen_web_project.yaml") { Remove-Item -Force "$tempStaging/tizen_web_project.yaml" }
if (Test-Path "$tempStaging/Debug") { Remove-Item -Recurse -Force "$tempStaging/Debug" }
if (Test-Path "$tempStaging/.tizen-rds") { Remove-Item -Recurse -Force "$tempStaging/.tizen-rds" }

& $aresPackageCmd $tempStaging -o $OutputDir
if ($LASTEXITCODE -ne 0) {
    throw "ares-package failed with exit code $LASTEXITCODE"
}
Remove-Item -Recurse -Force $tempStaging

$ipkFile = Get-ChildItem -Path $OutputDir -Filter "*.ipk" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($ipkFile) {
    $sizeMB = [math]::Round($ipkFile.Length / 1MB, 2)
    Write-Host "`nSuccessfully created LG webOS package:" -ForegroundColor Green
    Write-Host "  $($ipkFile.FullName) ($sizeMB MB)" -ForegroundColor White
    Write-Host "You can deploy this .ipk directly to your LG TV using webOS Dev Manager or ares-install." -ForegroundColor Cyan
}
