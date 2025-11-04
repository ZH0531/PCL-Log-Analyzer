# PCL Log Analyzer - One-Click Install/Update Script
# Version: 1.0.0

param(
    [string]$CDNUrl = "https://pcl-log-analyzer.oss-cn-hangzhou.aliyuncs.com"
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

Write-Host "[2/6] Detecting Install Location..." -ForegroundColor Yellow
Write-Host "  PCL Root: $pclRoot" -ForegroundColor White
Write-Host ""

# Prepare download
$zipUrl = "$CDNUrl/PCL-Log-Analyzer.zip"
$tempZip = Join-Path $env:TEMP "PCL-Log-Analyzer.zip"
$installPath = Join-Path $pclRoot "PCL Log Analyzer"

Write-Host "[3/6] Downloading Package..." -ForegroundColor Yellow
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
Write-Host "[4/6] Installing Files..." -ForegroundColor Yellow

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
Write-Host "[5/6] Verifying Installation..." -ForegroundColor Yellow

$requiredFiles = @(
    "Scripts\AnalyzeLogs.ps1",
    "Scripts\SelectLog.ps1",
    "Scripts\ClearReports.ps1",
    "Scripts\ErrorRules.ps1",
    "Templates\report-template.html"
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
Write-Host "[6/6] Finalizing..." -ForegroundColor Yellow
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
    Write-Host "  Installation Incomplete" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Some files are missing. Please reinstall." -ForegroundColor Yellow
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

