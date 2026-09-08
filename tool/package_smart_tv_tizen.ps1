param(
    [string]$OutputDir = "build/smart_tv_out"
)

$ErrorActionPreference = "Stop"
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  GOATPlayer - Samsung Tizen Smart TV Packaging  " -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$WgtPath = Join-Path $OutputDir "com.goatplayer.tv.wgt"
if (Test-Path $WgtPath) {
    Remove-Item -Force $WgtPath
}

Write-Host "`nPackaging smart_tv directory into Tizen .wgt package..." -ForegroundColor Yellow

$tizenCmd = Get-Command "tizen" -ErrorAction SilentlyContinue
if ($tizenCmd) {
    Write-Host "Found Tizen Studio CLI: $($tizenCmd.Source)" -ForegroundColor Green
    & $tizenCmd package -t wgt -s -- smart_tv -o $OutputDir
} else {
    Write-Host "Tizen CLI not found in PATH. Building standard W3C/Tizen .wgt package directly..." -ForegroundColor Yellow
    
    # Exclude webOS-specific appinfo.json from Tizen package
    $tempStaging = "build/tizen_staging"
    if (Test-Path $tempStaging) { Remove-Item -Recurse -Force $tempStaging }
    New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null

    Copy-Item -Path "smart_tv/*" -Destination $tempStaging -Recurse -Force
    if (Test-Path "$tempStaging/appinfo.json") {
        Remove-Item -Force "$tempStaging/appinfo.json"
    }
    if (Test-Path "$tempStaging/Debug") {
        Remove-Item -Recurse -Force "$tempStaging/Debug"
    }
    if (Test-Path "$tempStaging/.tizen-rds") {
        Remove-Item -Recurse -Force "$tempStaging/.tizen-rds"
    }
    if (Test-Path "$tempStaging/tizen_web_project.yaml") {
        Remove-Item -Force "$tempStaging/tizen_web_project.yaml"
    }

    # Create .wgt ZIP archive
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $tempStaging), (Resolve-Path -Path $OutputDir | Join-Path -ChildPath "com.goatplayer.tv.wgt"))
    Remove-Item -Recurse -Force $tempStaging
}

if (Test-Path $WgtPath) {
    $wgtFile = Get-Item $WgtPath
    $sizeMB = [math]::Round($wgtFile.Length / 1MB, 2)
    Write-Host "`nSuccessfully created Samsung Tizen package:" -ForegroundColor Green
    Write-Host "  $($wgtFile.FullName) ($sizeMB MB)" -ForegroundColor White
    Write-Host "You can deploy this .wgt directly to your Samsung TV using Tizen Device Manager or sdb install." -ForegroundColor Cyan
}
