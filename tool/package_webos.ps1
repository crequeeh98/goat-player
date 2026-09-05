# Packaging script for LG webOS TV (creates .ipk package)
param(
    [string]$OutputDir = "build/webos_out"
)

$ErrorActionPreference = "Stop"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - LG webOS Packaging Tool  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Build Flutter Web target
Write-Host "`n[1/3] Building Flutter Web release..." -ForegroundColor Yellow
flutter build web --release --base-href ""

# 2. Stage files for webOS
$StagingDir = "build/webos_staging"
Write-Host "`n[2/3] Staging webOS package in $StagingDir..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Copy built web artifacts
Copy-Item -Path "build/web/*" -Destination $StagingDir -Recurse -Force

# Copy webos descriptor and icons
Copy-Item -Path "webos/appinfo.json" -Destination $StagingDir -Force
if (Test-Path "webos/icon.png") {
    Copy-Item -Path "webos/icon.png" -Destination $StagingDir -Force
}
if (Test-Path "webos/largeIcon.png") {
    Copy-Item -Path "webos/largeIcon.png" -Destination $StagingDir -Force
}

# 3. Create .ipk package using ares-package (if available)
Write-Host "`n[3/3] Packaging webOS IPK..." -ForegroundColor Yellow
if (Get-Command ares-package -ErrorAction SilentlyContinue) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    ares-package $StagingDir -o $OutputDir
    Write-Host "`nSuccessfully created webOS IPK in $OutputDir!" -ForegroundColor Green
} else {
    Write-Host "`nNOTE: 'ares-package' CLI not detected in PATH." -ForegroundColor DarkYellow
    Write-Host "Staged webOS application is ready at: $StagingDir" -ForegroundColor Cyan
    Write-Host "You can deploy directly to your LG TV using webOS Dev Manager or install LG webOS CLI." -ForegroundColor Cyan
}
