# Packaging script for Samsung Tizen TV (creates .wgt package)
param(
    [string]$OutputDir = "build/tizen_out"
)

$ErrorActionPreference = "Stop"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - Samsung Tizen Packaging   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Build Web target
Write-Host "`n[1/3] Building Web release for Tizen..." -ForegroundColor Yellow
flutter build web --release --base-href ""

# 2. Stage files for Tizen
$StagingDir = "build/tizen_staging"
Write-Host "`n[2/3] Staging Tizen package in $StagingDir..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Copy built web artifacts
Copy-Item -Path "build/web/*" -Destination $StagingDir -Recurse -Force

# Copy Tizen config.xml
Copy-Item -Path "tizen/config.xml" -Destination $StagingDir -Force
if (Test-Path "tizen/icon.png") {
    Copy-Item -Path "tizen/icon.png" -Destination $StagingDir -Force
}

# 3. Create .wgt package
Write-Host "`n[3/3] Creating Tizen .wgt package..." -ForegroundColor Yellow
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$WgtPath = Join-Path $OutputDir "goat_player.wgt"
if (Test-Path $WgtPath) {
    Remove-Item -Force $WgtPath
}

# Tizen .wgt is a zip container containing config.xml and web resources
Compress-Archive -Path "$StagingDir/*" -DestinationPath (Join-Path $OutputDir "goat_player.zip") -Force
Rename-Item -Path (Join-Path $OutputDir "goat_player.zip") -NewName "goat_player.wgt" -Force

Write-Host "`nSuccessfully created Samsung Tizen package: $WgtPath" -ForegroundColor Green
Write-Host "You can install this .wgt on Samsung Smart TVs via Tizen Device Manager or SDB CLI." -ForegroundColor Cyan
