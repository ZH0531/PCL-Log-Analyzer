# ============================================
# PCL Log Analyzer - 发布打包脚本
# ============================================

$ErrorActionPreference = "Stop"

# 修复中文显示
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 发布打包工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 读取版本号
# ============================================
Write-Host "[1/4] 读取版本信息..." -ForegroundColor Yellow

$devRoot = $PSScriptRoot
$iniFile = Join-Path $devRoot "Custom.xaml.ini"

if (!(Test-Path $iniFile)) {
    Write-Host "  ✗ 未找到 Custom.xaml.ini" -ForegroundColor Red
    exit 1
}

$iniContent = Get-Content $iniFile -Encoding UTF8
$versionLine = $iniContent[0].Trim()

if ($versionLine -match '^version=(.+)$') {
    $version = $matches[1]
    Write-Host "  当前版本: v$version" -ForegroundColor Green
} else {
    Write-Host "  ✗ 无法解析版本号" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================
# 检查必要文件
# ============================================
Write-Host "[2/4] 检查必要文件..." -ForegroundColor Yellow

$toolDir = Join-Path $devRoot "PCL Log Analyzer"
$customXaml = Join-Path $devRoot "Custom.xaml"

if (!(Test-Path $toolDir)) {
    Write-Host "  ✗ 未找到工具目录: PCL Log Analyzer" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $customXaml)) {
    Write-Host "  ✗ 未找到文件: Custom.xaml" -ForegroundColor Red
    exit 1
}

Write-Host "  ✓ PCL Log Analyzer 目录" -ForegroundColor Green
Write-Host "  ✓ Custom.xaml" -ForegroundColor Green
Write-Host ""

# ============================================
# 创建临时目录
# ============================================
Write-Host "[3/4] 准备打包..." -ForegroundColor Yellow

$tempDir = Join-Path $devRoot "temp_release"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# 复制文件到临时目录
$tempToolDir = Join-Path $tempDir "PCL Log Analyzer"
Copy-Item $toolDir -Destination $tempToolDir -Recurse
Copy-Item $customXaml -Destination $tempDir

Write-Host "  ✓ 文件已复制到临时目录" -ForegroundColor Green
Write-Host ""

# ============================================
# 创建压缩包
# ============================================
Write-Host "[4/4] 创建压缩包..." -ForegroundColor Yellow

$zipName = "PCL-Log-Analyzer-v$version.zip"
$zipPath = Join-Path $devRoot $zipName

# 删除旧的压缩包
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# 禁用PowerShell进度条
$ProgressPreference = 'SilentlyContinue'

# 压缩文件
Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

# 恢复进度条设置
$ProgressPreference = 'Continue'

# 清理临时目录
Remove-Item $tempDir -Recurse -Force

$zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 2)
Write-Host "  ✓ 压缩包已创建: $zipName ($zipSize KB)" -ForegroundColor Green
Write-Host ""

# ============================================
# 完成
# ============================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "  打包完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "发布文件: $zipName" -ForegroundColor Cyan
Write-Host "文件位置: $devRoot" -ForegroundColor Gray
Write-Host ""

Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

