# ============================================
# PCL Log Analyzer - 打包脚本
# 功能：自动替换版本号、更新文件大小并打包工具
# ============================================

$ErrorActionPreference = "Stop"

# 修复中文显示
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
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
# 步骤 1: 读取版本号配置
# ============================================
Write-Host "[1/5] 读取版本号..." -ForegroundColor Yellow

$versionFile1 = Join-Path $devRoot "Custom.xaml.ini"

if (-not (Test-Path $versionFile1)) {
    Write-Host "错误：找不到版本文件 Custom.xaml.ini" -ForegroundColor Red
    exit 1
}

# 从ini文件读取version=x.x.x
$iniContent = Get-Content $versionFile1
$versionLine = $iniContent | Where-Object { $_ -match '^version=(.+)$' } | Select-Object -First 1

if (-not $versionLine) {
    Write-Host "错误：Custom.xaml.ini 中未找到 version=x.x.x 配置" -ForegroundColor Red
    Write-Host "请在第一行添加：version=1.0.2" -ForegroundColor Yellow
    exit 1
}

$newVersion = $matches[1].Trim()
$currentDate = Get-Date -Format 'yyyy-MM-dd'
Write-Host "  目标版本: $newVersion" -ForegroundColor Green
Write-Host "  当前日期: $currentDate" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 2: 自动替换所有文件中的版本号和日期
# ============================================
Write-Host "[2/5] 替换版本号和日期..." -ForegroundColor Yellow

$versionPattern1 = 'v\d+\.\d+\.\d+'           # 匹配 v1.0.2
$versionPattern2 = '版本：\d+\.\d+\.\d+'        # 匹配 版本：1.0.2
$datePattern = '更新日期：\d{4}-\d{2}-\d{2}'   # 匹配 更新日期：2025-11-04
$replacementPattern1 = "v$newVersion"
$replacementPattern2 = "版本：$newVersion"
$replacementDate = "更新日期：$(Get-Date -Format 'yyyy-MM-dd')"

$filesToUpdate = Get-ChildItem -Path $toolDir -Recurse -File | Where-Object {
    $_.Extension -eq '.ps1' -or $_.Extension -eq '.html'
}

# 同时处理 Custom.xaml
$customXamlPath = Join-Path $devRoot "Custom.xaml"
if (Test-Path $customXamlPath) {
    $filesToUpdate += Get-Item $customXamlPath
}

$updatedCount = 0
foreach ($file in $filesToUpdate) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $originalContent = $content
    
    # 替换版本号和日期（三种格式都替换）
    $content = $content -replace $versionPattern1, $replacementPattern1
    $content = $content -replace $versionPattern2, $replacementPattern2
    $content = $content -replace $datePattern, $replacementDate
    
    if ($content -ne $originalContent) {
        $content | Out-File -FilePath $file.FullName -Encoding UTF8 -NoNewline
        $relativePath = $file.FullName.Replace($devRoot + '\', '')
        Write-Host "  ✓ $relativePath" -ForegroundColor Gray
        $updatedCount++
    }
}

Write-Host "  已更新 $updatedCount 个文件" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 3: 扫描文件并计算大小
# ============================================
Write-Host "[3/5] 扫描文件并计算大小..." -ForegroundColor Yellow

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
# 步骤 4: 更新版本文件
# ============================================
Write-Host "[4/5] 更新版本文件..." -ForegroundColor Yellow

# 生成版本文件内容（第一行是 version=x.x.x）
$versionContent = @("version=$newVersion")
foreach ($file in ($fileList | Sort-Object Path)) {
    $versionContent += "$($file.Path)=$($file.Size)"
}

# 写入两个版本文件
$versionFile2 = Join-Path $toolDir "Custom.xaml.ini"
$versionContent | Out-File -FilePath $versionFile1 -Encoding UTF8
Write-Host "  已更新: Custom.xaml.ini" -ForegroundColor Green

$versionContent | Out-File -FilePath $versionFile2 -Encoding UTF8
Write-Host "  已更新: PCL Log Analyzer/Custom.xaml.ini" -ForegroundColor Green
Write-Host ""

# ============================================
# 步骤 5: 打包成 ZIP
# ============================================
Write-Host "[5/5] 打包工具..." -ForegroundColor Yellow

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
Write-Host "版本: $newVersion" -ForegroundColor Gray
Write-Host "日期: $currentDate" -ForegroundColor Gray
Write-Host "文件数: $($fileList.Count)" -ForegroundColor Gray
Write-Host "ZIP大小: $zipSize KB" -ForegroundColor Gray
Write-Host ""

Start-Sleep -Seconds 3
