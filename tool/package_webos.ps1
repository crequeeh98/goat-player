param(
    [string]$OutputDir = "build/webos_out",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - LG webOS Packaging Tool  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Build Flutter Web target
if (-not $SkipBuild) {
    Write-Host "`n[1/3] Building Flutter Web release..." -ForegroundColor Yellow
    flutter build web --release
} else {
    Write-Host "`n[1/3] Skipping Flutter build (using existing build/web)..." -ForegroundColor Yellow
}

# 2. Stage files for webOS
$StagingDir = "build/webos_staging"
Write-Host "`n[2/3] Staging webOS package in $StagingDir..." -ForegroundColor Yellow
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

# Copy webos descriptor and icons
Copy-Item -Path "webos/appinfo.json" -Destination $StagingDir -Force
if (Test-Path "webos/icon.png") {
    Copy-Item -Path "webos/icon.png" -Destination $StagingDir -Force
}
if (Test-Path "webos/largeIcon.png") {
    Copy-Item -Path "webos/largeIcon.png" -Destination $StagingDir -Force
}
if (Test-Path "webos/splash.png") {
    Copy-Item -Path "webos/splash.png" -Destination $StagingDir -Force
}

# 3. Create .ipk package using ares-package (-n disables minification for CanvasKit)
Write-Host "`n[3/3] Packaging webOS IPK..." -ForegroundColor Yellow
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$packaged = $false
if (Get-Command ares-package -ErrorAction SilentlyContinue) {
    Write-Host "Using system ares-package..." -ForegroundColor Cyan
    ares-package -n $StagingDir -o $OutputDir
    $packaged = $true
} elseif (Get-Command npx -ErrorAction SilentlyContinue) {
    Write-Host "Using npx @webos-tools/cli ares-package..." -ForegroundColor Cyan
    npx -y -p @webos-tools/cli ares-package -n $StagingDir -o $OutputDir
    $packaged = $true
}

if ($packaged) {
    $ipkFiles = Get-ChildItem -Path $OutputDir -Filter "*.ipk" | Sort-Object LastWriteTime -Descending
    if ($ipkFiles.Count -gt 0) {
        $ipk = $ipkFiles[0]
        $fileSizeMB = [math]::Round(($ipk.Length / 1MB), 2)
        Write-Host "`nSuccessfully created LG webOS package: $($ipk.FullName) ($fileSizeMB MB)" -ForegroundColor Green
        Write-Host "You can deploy this .ipk directly to your LG TV using LG webOS Dev Manager or ares-install." -ForegroundColor Cyan
    }
} else {
    Write-Host "`nNOTE: 'ares-package' CLI not detected." -ForegroundColor DarkYellow
    Write-Host "Staged webOS application is ready at: $StagingDir" -ForegroundColor Cyan
    Write-Host "You can deploy directly to your LG TV using webOS Dev Manager or install LG webOS CLI." -ForegroundColor Cyan
}

