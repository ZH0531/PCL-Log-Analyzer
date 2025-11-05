# PCL Log Analyzer - 打包脚本
# 功能：更新版本文件并打包工具

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 打包工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 获取当前脚本所在目录（开发根目录）
$devRoot = $PSScriptRoot
$toolDir = Join-Path $devRoot "PCL Log Analyzer"

# 检查目录是否存在
if (-not (Test-Path $toolDir)) {
    Write-Host "错误：找不到工具目录 'PCL Log Analyzer'" -ForegroundColor Red
    exit 1
}

# ============================================
# 步骤 1: 读取当前版本号
# ============================================
Write-Host "[1/4] 读取版本号..." -ForegroundColor Yellow

$versionFile1 = Join-Path $devRoot "Custom.xaml.ini"
$versionFile2 = Join-Path $toolDir "Custom.xaml.ini"

if (-not (Test-Path $versionFile1)) {
    Write-Host "错误：找不到版本文件 Custom.xaml.ini" -ForegroundColor Red
    exit 1
}

$currentVersion = (Get-Content $versionFile1 -First 1).Trim()
Write-Host "  当前版本: $currentVersion" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 2: 扫描文件并计算大小
# ============================================
Write-Host "[2/4] 扫描文件并计算大小..." -ForegroundColor Yellow

$fileList = @()
Get-ChildItem -Path $toolDir -Recurse -File | Where-Object {
    $_.Extension -eq '.ps1' -or $_.Extension -eq '.html'
} | ForEach-Object {
    $relativePath = $_.FullName.Replace($toolDir + '\', '').Replace('\', '/')
    $fileList += [PSCustomObject]@{
        Path = $relativePath
        Size = $_.Length
    }
    Write-Host "  $relativePath = $($_.Length) bytes" -ForegroundColor Gray
}

if ($fileList.Count -eq 0) {
    Write-Host "错误：未找到任何 .ps1 或 .html 文件" -ForegroundColor Red
    exit 1
}

Write-Host "  共扫描到 $($fileList.Count) 个文件" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 3: 更新版本文件
# ============================================
Write-Host "[3/4] 更新版本文件..." -ForegroundColor Yellow

# 生成版本文件内容
$versionContent = @($currentVersion)
foreach ($file in ($fileList | Sort-Object Path)) {
    $versionContent += "$($file.Path)=$($file.Size)"
}

# 写入两个版本文件
$versionContent | Out-File -FilePath $versionFile1 -Encoding UTF8
Write-Host "  已更新: Custom.xaml.ini" -ForegroundColor Green

$versionContent | Out-File -FilePath $versionFile2 -Encoding UTF8
Write-Host "  已更新: PCL Log Analyzer/Custom.xaml.ini" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 4: 打包成 ZIP
# ============================================
Write-Host "[4/4] 打包工具..." -ForegroundColor Yellow

$zipPath = Join-Path $devRoot "PCL Log Analyzer.zip"

# 删除旧的 ZIP（如果存在）
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
    Write-Host "  已删除旧的 ZIP 文件" -ForegroundColor Gray
}

# 压缩文件夹
try {
    Compress-Archive -Path $toolDir -DestinationPath $zipPath -CompressionLevel Optimal
    $zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 2)
    Write-Host "  已创建: PCL Log Analyzer.zip ($zipSize KB)" -ForegroundColor Green
} catch {
    Write-Host "错误：打包失败 - $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  打包完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "输出文件：" -ForegroundColor Cyan
Write-Host "  - Custom.xaml.ini (已更新)" -ForegroundColor White
Write-Host "  - PCL Log Analyzer.zip" -ForegroundColor White
Write-Host ""
Write-Host "版本: $currentVersion" -ForegroundColor Gray
Write-Host "文件数: $($fileList.Count)" -ForegroundColor Gray
Write-Host "ZIP大小: $zipSize KB" -ForegroundColor Gray
Write-Host ""

Start-Sleep -Seconds 3

