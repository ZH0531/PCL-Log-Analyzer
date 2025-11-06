# ============================================
# PCL Log Analyzer - 自动发布脚本
# 功能：自动执行打包、预览、上传流程
# ============================================

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 自动发布工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptRoot = $PSScriptRoot

# ============================================
# 步骤 1: 打包工具
# ============================================
Write-Host "[1/3] 执行打包..." -ForegroundColor Yellow
Write-Host ""

$packageScript = Join-Path $scriptRoot "Package.ps1"
if (-not (Test-Path $packageScript)) {
    Write-Host "  错误: Package.ps1 不存在" -ForegroundColor Red
    exit 1
}

try {
    & $packageScript
    Write-Host ""
    Write-Host "  ✓ 打包完成" -ForegroundColor Green
} catch {
    Write-Host "  错误: 打包失败 - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "按任意键继续到Release打包脚本..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ============================================
# 步骤 2: 预览打包内容
# ============================================
Write-Host ""
Write-Host "[2/3] 预览打包内容..." -ForegroundColor Yellow
Write-Host ""

$releaseScript = Join-Path $scriptRoot "Release-Package.ps1"
if (-not (Test-Path $releaseScript)) {
    Write-Host "  错误: Release-Package.ps1 不存在" -ForegroundColor Red
    exit 1
}

try {
    & $releaseScript
    Write-Host ""
    Write-Host "  ✓ 预览完成" -ForegroundColor Green
} catch {
    Write-Host "  错误: 预览失败 - $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "确认无误后，按任意键继续上传..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# ============================================
# 步骤 3: 上传到CDN
# ============================================
Write-Host ""
Write-Host "[3/3] 上传到CDN..." -ForegroundColor Yellow
Write-Host ""

$uploadScript = Join-Path $scriptRoot "Upload.ps1"
if (-not (Test-Path $uploadScript)) {
    Write-Host "  错误: Upload.ps1 不存在" -ForegroundColor Red
    exit 1
}

try {
    & $uploadScript
    Write-Host ""
    Write-Host "  ✓ 上传完成" -ForegroundColor Green
} catch {
    Write-Host "  错误: 上传失败 - $_" -ForegroundColor Red
    exit 1
}

# ============================================
# 完成
# ============================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  发布流程全部完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "已完成：" -ForegroundColor Cyan
Write-Host "  1. ✓ 打包工具 (Package.ps1)" -ForegroundColor White
Write-Host "  2. ✓ 预览内容 (Release-Package.ps1)" -ForegroundColor White
Write-Host "  3. ✓ 上传CDN (Upload.ps1)" -ForegroundColor White
Write-Host ""

Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

