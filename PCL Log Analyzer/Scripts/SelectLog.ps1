# ============================================
# PCL Log Analyzer - 手动选择日志文件
# ============================================

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Continue"

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  手动选择日志文件" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$toolRoot = $PSScriptRoot | Split-Path -Parent  # PCL Log Analyzer 文件夹
$pclRoot = $toolRoot | Split-Path -Parent       # PCL 根目录
$mcDir = Join-Path $pclRoot ".minecraft"

# Open file dialog with better styling
Add-Type -AssemblyName System.Windows.Forms

$fileDialog = New-Object System.Windows.Forms.OpenFileDialog
$fileDialog.Title = "选择 Minecraft 日志文件"
$fileDialog.Filter = "日志文件 (*.log;*.txt)|*.log;*.txt|所有文件 (*.*)|*.*"
$fileDialog.InitialDirectory = Join-Path $mcDir "logs"
$fileDialog.Multiselect = $false
$fileDialog.RestoreDirectory = $true

Write-Host "请选择要分析的日志文件（通常为 latest.log）" -ForegroundColor Cyan
Write-Host "正在打开文件选择对话框..." -ForegroundColor Yellow

# Create a hidden form to center the dialog
$form = New-Object System.Windows.Forms.Form
$form.TopMost = $true
$form.StartPosition = 'CenterScreen'
$form.WindowState = 'Minimized'
$form.ShowInTaskbar = $false

$result = $fileDialog.ShowDialog($form)
$form.Dispose()

if ($result -eq 'OK') {
    $selectedFile = $fileDialog.FileName
    Write-Host ""
    Write-Host "已选择: $selectedFile" -ForegroundColor Green
    Write-Host "文件大小: $([Math]::Round((Get-Item $selectedFile).Length / 1KB, 1)) KB" -ForegroundColor White
    Write-Host ""
    
    # Create temp script to analyze this specific file
    $analyzeScript = Join-Path $PSScriptRoot "AnalyzeLogs.ps1"
    
    if (Test-Path $analyzeScript) {
        Write-Host "开始分析..." -ForegroundColor Cyan
        Write-Host ""
        
        # Pass the selected file path as parameter
        & $analyzeScript -CustomLogPath $selectedFile
    } else {
        Write-Host "[错误] 找不到 AnalyzeLogs.ps1！" -ForegroundColor Red
        Start-Process notepad.exe $selectedFile
    }
} else {
    Write-Host ""
    Write-Host "用户取消" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "窗口将在 5 秒后自动关闭..." -ForegroundColor Yellow
    for ($i = 5; $i -gt 0; $i--) {
        Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    Stop-Process -Id $PID
}
