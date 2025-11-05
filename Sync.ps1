# ============================================
# PCL Log Analyzer - 同步脚本
# 功能：将开发目录同步到用户目录，便于调试
# ============================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 同步工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 获取目录路径
$devRoot = $PSScriptRoot
$pclRoot = Split-Path $devRoot -Parent

$sourceToolDir = Join-Path $devRoot "PCL Log Analyzer"
$targetToolDir = Join-Path $pclRoot "PCL Log Analyzer"

$sourceCustom = Join-Path $devRoot "Custom.xaml"
$targetCustom = Join-Path $pclRoot "Custom.xaml"

# ============================================
# 步骤 1: 同步工具包
# ============================================
Write-Host "[1/2] 同步工具包..." -ForegroundColor Yellow
Write-Host "  从: $sourceToolDir" -ForegroundColor Gray
Write-Host "  到: $targetToolDir" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $sourceToolDir)) {
    Write-Host "错误：源目录不存在" -ForegroundColor Red
    exit 1
}

# 创建目标目录（如果不存在）
if (-not (Test-Path $targetToolDir)) {
    New-Item -ItemType Directory -Path $targetToolDir -Force | Out-Null
    Write-Host "  已创建目标目录" -ForegroundColor Green
}

# 获取需要同步的文件和文件夹
$itemsToSync = @(
    @{ Name = "Scripts"; Type = "Directory" }
    @{ Name = "Templates"; Type = "Directory" }
    @{ Name = "Custom.xaml.ini"; Type = "File" }
)

$syncCount = 0
foreach ($item in $itemsToSync) {
    $sourcePath = Join-Path $sourceToolDir $item.Name
    $targetPath = Join-Path $targetToolDir $item.Name
    
    if (-not (Test-Path $sourcePath)) {
        Write-Host "  警告: 跳过不存在的 $($item.Name)" -ForegroundColor Yellow
        continue
    }
    
    if ($item.Type -eq "Directory") {
        # 同步目录（递归，覆盖）
        if (Test-Path $targetPath) {
            Remove-Item $targetPath -Recurse -Force
        }
        Copy-Item $sourcePath -Destination $targetPath -Recurse -Force
        $fileCount = (Get-ChildItem $targetPath -Recurse -File).Count
        Write-Host "  ✓ $($item.Name)/ ($fileCount 个文件)" -ForegroundColor Green
    } else {
        # 同步文件
        Copy-Item $sourcePath -Destination $targetPath -Force
        $size = [math]::Round((Get-Item $targetPath).Length / 1KB, 2)
        Write-Host "  ✓ $($item.Name) ($size KB)" -ForegroundColor Green
    }
    
    $syncCount++
}

Write-Host ""
Write-Host "  已同步 $syncCount 项" -ForegroundColor Green

# 检查并保留 Reports 文件夹
$reportsDir = Join-Path $targetToolDir "Reports"
if (Test-Path $reportsDir) {
    $reportCount = (Get-ChildItem $reportsDir -Filter "*.html" -ErrorAction SilentlyContinue).Count
    Write-Host "  保留: Reports/ ($reportCount 个报告)" -ForegroundColor Cyan
}

Write-Host ""

# ============================================
# 步骤 2: 同步 Custom.xaml
# ============================================
Write-Host "[2/2] 同步 Custom.xaml..." -ForegroundColor Yellow
Write-Host "  从: $sourceCustom" -ForegroundColor Gray
Write-Host "  到: $targetCustom" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $sourceCustom)) {
    Write-Host "错误：源文件不存在" -ForegroundColor Red
    exit 1
}

Copy-Item $sourceCustom -Destination $targetCustom -Force
$size = [math]::Round((Get-Item $targetCustom).Length / 1KB, 2)
Write-Host "  ✓ Custom.xaml ($size KB)" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  同步完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "已同步：" -ForegroundColor Cyan
Write-Host "  - PCL Log Analyzer/ → PCL Log Analyzer/" -ForegroundColor White
Write-Host "  - Custom.xaml → PCL/Custom.xaml" -ForegroundColor White
Write-Host ""

Start-Sleep -Seconds 3
