param(
    [string]$OutputDir = "build/tizen_out",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - Samsung Tizen Packaging   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. Build Web target (if not skipped)
if (-not $SkipBuild) {
    Write-Host "`n[1/3] Building Web release for Tizen..." -ForegroundColor Yellow
    flutter build web --release
} else {
    Write-Host "`n[1/3] Skipping Flutter build (using existing build/web)..." -ForegroundColor Yellow
}

# 2. Stage files for Tizen
$StagingDir = "build/tizen_staging"
Write-Host "`n[2/3] Staging Tizen package in $StagingDir..." -ForegroundColor Yellow
if (Test-Path $StagingDir) {
    Remove-Item -Recurse -Force $StagingDir
}
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Copy built web artifacts
Copy-Item -Path "build/web/*" -Destination $StagingDir -Recurse -Force

# Patch <base href="/"> to <base href="./"> in staging index.html for TV file: URLs
$indexPath = Join-Path $StagingDir "index.html"
if (Test-Path $indexPath) {
    $content = Get-Content $indexPath -Raw
    $content = $content -replace '<base href="\/">', '<base href="./">'
    Set-Content -Path $indexPath -Value $content -NoNewline
}

# Copy Tizen config.xml and icon
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
$zipPath = Join-Path $OutputDir "goat_player.zip"
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

Compress-Archive -Path "$StagingDir/*" -DestinationPath $zipPath -Force
Rename-Item -Path $zipPath -NewName "goat_player.wgt" -Force

$fileSizeMB = [math]::Round(((Get-Item $WgtPath).Length / 1MB), 2)
Write-Host "`nSuccessfully created Samsung Tizen package: $WgtPath ($fileSizeMB MB)" -ForegroundColor Green
Write-Host "You can install this .wgt on Samsung Smart TVs via Tizen Device Manager or SDB CLI." -ForegroundColor Cyan

