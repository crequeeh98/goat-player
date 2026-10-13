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

# 2. Automatically Sign with Samsung Certificate if tz.exe is available
$tzPath = "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\tizen-core\tz.exe"
if (-not (Test-Path $tzPath)) {
    $tzCmd = Get-Command "tz" -ErrorAction SilentlyContinue
    if ($tzCmd) { $tzPath = $tzCmd.Source }
}

$SignedWgtPath = Join-Path $OutputDir "com.goatplayer.tv.signed.wgt"
if (Test-Path $SignedWgtPath) { Remove-Item -Force $SignedWgtPath }

if (Test-Path $tzPath) {
    $activeProfile = "Samsung #3"
    $profilesOutput = & $tzPath security-profiles list 2>&1 | Out-String
    if ($profilesOutput -match 'Current Active Profile:\s*(.+)') {
        $activeProfile = $matches[1].Trim()
    }
    Write-Host "`nFound Tizen Core CLI ($tzPath). Signing with active profile '$activeProfile'..." -ForegroundColor Cyan
    try {
        & $tzPath pack -t wgt -s $activeProfile -b $WgtPath -o $SignedWgtPath
        if (Test-Path $SignedWgtPath) {
            Write-Host "Successfully signed package: $SignedWgtPath" -ForegroundColor Green
            $targetDeployWgt = $SignedWgtPath
        } else {
            $targetDeployWgt = $WgtPath
        }
    } catch {
        Write-Warning "Signing failed: $_. Using unsigned .wgt"
        $targetDeployWgt = $WgtPath
    }
} else {
    $targetDeployWgt = $WgtPath
}

# 3. Check for connected TV devices via SDB
$sdbPath = "C:\Users\crequ\.tizen-extension-platform\server\sdktools\data\tools\sdb.exe"
if (-not (Test-Path $sdbPath)) {
    $sdbCmd = Get-Command "sdb" -ErrorAction SilentlyContinue
    if ($sdbCmd) { $sdbPath = $sdbCmd.Source }
}

if (Test-Path $WgtPath) {
    $wgtFile = Get-Item $targetDeployWgt
    $sizeMB = [math]::Round($wgtFile.Length / 1MB, 2)
    Write-Host "`n=================================================" -ForegroundColor Green
    Write-Host "  Package Ready for Samsung Smart TV!            " -ForegroundColor Green
    Write-Host "=================================================" -ForegroundColor Green
    Write-Host "Package: $($wgtFile.FullName) ($sizeMB MB)" -ForegroundColor White

    if (Test-Path $sdbPath) {
        Write-Host "`nTo install on your Samsung TV:" -ForegroundColor Cyan
        Write-Host "  1. Connect: & `"$sdbPath`" connect <TV_IP>" -ForegroundColor Yellow
        Write-Host "  2. Install: & `"$sdbPath`" install `"$($wgtFile.FullName)`"" -ForegroundColor Yellow
    }
}

