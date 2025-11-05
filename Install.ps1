# ============================================
# PCL Log Analyzer - 一键安装/更新脚本
# ============================================

param(
    [string]$CDNUrl = "https://pcl.log.zh8888.top"
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - Setup Wizard" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Detect PCL root directory (use current working directory)
$pclRoot = (Get-Location).Path

Write-Host "[1/6] Environment Check..." -ForegroundColor Yellow

# Check PowerShell version
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "  + PowerShell: $($psVersion.Major).$($psVersion.Minor) (Core)" -ForegroundColor Green
} elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -eq 1) {
    Write-Host "  + PowerShell: 5.1 (Windows PowerShell)" -ForegroundColor Yellow
} else {
    Write-Host "  + PowerShell: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
}

# Check encoding
$currentCP = chcp
if ($currentCP -match '65001') {
    Write-Host "  + Encoding: UTF-8" -ForegroundColor Green
} else {
    Write-Host "  ! Encoding: Non-UTF8, setting..." -ForegroundColor Yellow
    chcp 65001 | Out-Null
    Write-Host "  + Encoding: UTF-8 (session)" -ForegroundColor Green
}

Write-Host ""

Write-Host "[2/7] Detecting Install Location..." -ForegroundColor Yellow
Write-Host "  PCL Root: $pclRoot" -ForegroundColor White
$installPath = Join-Path $pclRoot "PCL Log Analyzer"
Write-Host ""

Write-Host "[3/7] Checking Version..." -ForegroundColor Yellow

# Download remote version file
$versionUrl = "$CDNUrl/Custom.xaml.ini"
$tempVersion = Join-Path $env:TEMP "remote.version"

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $versionUrl -OutFile $tempVersion -UseBasicParsing
    $versionContent = Get-Content $tempVersion
    
    # Parse version (first line: version=x.x.x)
    $versionLine = $versionContent[0].Trim()
    if ($versionLine -match '^version=(.+)$') {
        $remoteVersion = $matches[1]
    } else {
        throw "Invalid version file format. Expected: version=x.x.x"
    }
    
    # Parse file sizes from version file
    $remoteFileSizes = @{}
    for ($i = 1; $i -lt $versionContent.Length; $i++) {
        if ($versionContent[$i] -match '^(.+)=(\d+)$') {
            $remoteFileSizes[$matches[1]] = [int]$matches[2]
        }
    }
    
    Remove-Item $tempVersion -Force
    Write-Host "  Remote Version: $remoteVersion" -ForegroundColor Cyan
} catch {
    Write-Host "  ! Cannot fetch remote version, continue anyway" -ForegroundColor Yellow
    $remoteVersion = $null
    $remoteFileSizes = @{}
}

# Check local version
$localVersionFile = Join-Path $installPath "Custom.xaml.ini"
$needsInstall = $true

if (Test-Path $localVersionFile) {
    $localVersionContent = Get-Content $localVersionFile
    $localVersionLine = $localVersionContent[0].Trim()
    
    # Parse version (first line: version=x.x.x)
    if ($localVersionLine -match '^version=(.+)$') {
        $localVersion = $matches[1]
    } else {
        $localVersion = "Unknown"
    }
    
    Write-Host "  Local Version:  $localVersion" -ForegroundColor Cyan
    
    # Verify file integrity if version matches
    if (-not $remoteVersion) {
        # Remote version unavailable, cannot verify
        Write-Host "  ! Cannot verify version, skipping update check" -ForegroundColor Yellow
        $needsInstall = $false
    }
    elseif ($localVersion -eq $remoteVersion) {
        Write-Host "  Checking file integrity..." -ForegroundColor Gray
        
        $allFilesOk = $true
        
        # Check all files listed in version file
        foreach ($fileEntry in $remoteFileSizes.Keys) {
            $fullPath = Join-Path $installPath $fileEntry
            $expectedSize = $remoteFileSizes[$fileEntry]
            
            if (-not (Test-Path $fullPath)) {
                Write-Host "    ! Missing: $fileEntry" -ForegroundColor Yellow
                $allFilesOk = $false
                break
            }
            
            # Check file size with tolerance (±1KB)
            $actualSize = (Get-Item $fullPath).Length
            $tolerance = 1024
            $sizeDiff = [Math]::Abs($actualSize - $expectedSize)
            
            if ($sizeDiff -gt $tolerance) {
                Write-Host "    ! Size mismatch: $fileEntry" -ForegroundColor Yellow
                Write-Host "      Expected: ~$expectedSize bytes, Got: $actualSize bytes" -ForegroundColor Gray
                $allFilesOk = $false
                break
            }
        }
        
        if ($allFilesOk) {
            Write-Host "    All files intact" -ForegroundColor Green
            Write-Host ""
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host "  Already Up-to-Date!" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Current version: $localVersion" -ForegroundColor White
            Write-Host "No update needed." -ForegroundColor Gray
            Write-Host ""
            Write-Host "Window will close in 3 seconds..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
            Stop-Process -Id $PID
        } else {
            Write-Host "    Files damaged, reinstalling..." -ForegroundColor Yellow
            $needsInstall = $true
        }
    } else {
        Write-Host "  Update available: $localVersion -> $remoteVersion" -ForegroundColor Green
        $needsInstall = $true
    }
} else {
    Write-Host "  Local Version:  Not installed" -ForegroundColor Gray
    Write-Host "  First time installation" -ForegroundColor Green
    $needsInstall = $true
}

Write-Host ""

# Skip download if not needed
if (-not $needsInstall) {
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "  Installation Skipped" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Reason: Cannot connect to update server" -ForegroundColor Gray
    Write-Host "Your local installation appears intact." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Window will close in 5 seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    exit 0
}

# Prepare download
$zipUrl = "$CDNUrl/PCL Log Analyzer.zip"
$tempZip = Join-Path $env:TEMP "PCL Log Analyzer.zip"

Write-Host "[4/7] Downloading Package..." -ForegroundColor Yellow
Write-Host "  URL: $zipUrl" -ForegroundColor Gray

try {
    # Download file (silent progress)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
    $fileSize = [Math]::Round((Get-Item $tempZip).Length / 1KB, 1)
    Write-Host "  + Downloaded: $fileSize KB" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check your network or CDN address" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""
Write-Host "[5/7] Installing Files..." -ForegroundColor Yellow

try {
    # Backup if exists
    if (Test-Path $installPath) {
        $backupPath = "$installPath.backup"
        if (Test-Path $backupPath) {
            Remove-Item $backupPath -Recurse -Force
        }
        Write-Host "  Old version detected, backing up..." -ForegroundColor Gray
        Move-Item $installPath $backupPath -Force
    }
    
    # Extract files
    Expand-Archive -Path $tempZip -DestinationPath $pclRoot -Force
    Write-Host "  + Extracted to: $installPath" -ForegroundColor Green
    
    # Clean temp file
    Remove-Item $tempZip -Force
    
    # Migrate reports if backup exists
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        $oldReports = Join-Path $backupPath "Reports"
        $newReports = Join-Path $installPath "Reports"
        
        if ((Test-Path $oldReports) -and (Test-Path $newReports)) {
            Write-Host "  Migrating report history..." -ForegroundColor Gray
            Copy-Item "$oldReports\*.html" $newReports -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Item $backupPath -Recurse -Force
    }
    
} catch {
    Write-Host "  [ERROR] Installation failed: $_" -ForegroundColor Red
    
    # Try to restore backup
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        Write-Host "  Restoring backup..." -ForegroundColor Yellow
        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force
        }
        Move-Item $backupPath $installPath -Force
    }
    
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""
Write-Host "[6/7] Verifying Installation..." -ForegroundColor Yellow

$requiredFiles = @(
    "Scripts\AnalyzeLogs.ps1",
    "Scripts\LogParser.ps1",
    "Scripts\ReportGenerator.ps1",
    "Scripts\GenerateReportsList.ps1",
    "Scripts\SelectLog.ps1",
    "Scripts\ClearReports.ps1",
    "Scripts\ErrorRules.ps1",
    "Templates\report-template.html",
    "Templates\reports-list-template.html",
    "Custom.xaml.ini"
)

$allOk = $true
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $installPath $file
    if (Test-Path $fullPath) {
        Write-Host "  + $file" -ForegroundColor Green
    } else {
        Write-Host "  - $file (missing)" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""
Write-Host "[7/7] Finalizing..." -ForegroundColor Yellow
Write-Host "  + All scripts configured with UTF-8" -ForegroundColor Green
Write-Host "  + Ready to use" -ForegroundColor Green

Write-Host ""
if ($allOk) {
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Now you can:" -ForegroundColor Cyan
    Write-Host "  * Click [Analyze Latest Log] to start" -ForegroundColor White
    Write-Host "  * Click [Manual Select Log] for custom analysis" -ForegroundColor White
} else {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "  Installation Failed!" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  * Network interruption during download" -ForegroundColor White
    Write-Host "  * Package corruption or tampering" -ForegroundColor White
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    
    # Remove corrupted installation
    if (Test-Path $installPath) {
        Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  + Removed corrupted files" -ForegroundColor Green
    }
    
    # Restore backup if exists
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        Move-Item $backupPath $installPath -Force
        Write-Host "  + Restored previous version" -ForegroundColor Green
}

Write-Host ""
    Write-Host "Please try again or contact support" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Window will close in 5 seconds..." -ForegroundColor Gray
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
Write-Host ""

# Force close window
Stop-Process -Id $PID

