# ============================================
# PCL Log Analyzer - 清理报告脚本
# ============================================

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Continue"

Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  清空历史报告" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$toolRoot = $PSScriptRoot | Split-Path -Parent  # PCL Log Analyzer 文件夹
$reportsDir = Join-Path $toolRoot "Reports"

Write-Host "[检查] 报告文件夹: $reportsDir" -ForegroundColor White

if (!(Test-Path $reportsDir)) {
    Write-Host "[提示] 报告文件夹不存在" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "窗口将在 3 秒后自动关闭..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Stop-Process -Id $PID
}

$files = Get-ChildItem $reportsDir -Filter "*.html" -ErrorAction SilentlyContinue
$count = $files.Count

Write-Host "[发现] $count 个报告文件" -ForegroundColor Green

if ($count -eq 0) {
    Write-Host "[提示] 没有报告需要清空" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "窗口将在 3 秒后自动关闭..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
    Stop-Process -Id $PID
}

Write-Host ""
Write-Host "将要删除的文件:" -ForegroundColor Yellow
foreach ($file in $files) {
    Write-Host "  - $($file.Name)" -ForegroundColor Gray
}

Write-Host ""
Add-Type -AssemblyName PresentationFramework

$msg1 = "确定要删除这 $count 个报告文件吗？"
$msg2 = "`n此操作不可恢复！"
$result = [System.Windows.MessageBox]::Show($msg1 + $msg2, "确认清空", "YesNo", "Warning")

if ($result -eq 'Yes') {
    Write-Host ""
    Write-Host "[执行] 正在删除文件..." -ForegroundColor Yellow
    
    try {
        Remove-Item "$reportsDir\*.html" -Force -ErrorAction Stop
        Write-Host "[成功] 已删除 $count 个文件" -ForegroundColor Green
        Write-Host ""
        
        $successMsg = "成功删除 $count 个报告文件"
        [System.Windows.MessageBox]::Show($successMsg, "完成", "OK", "Information")
    } catch {
        Write-Host "[错误] 删除失败: $_" -ForegroundColor Red
        Write-Host ""
        
        $errorMsg = "删除失败: " + $_.Exception.Message
        [System.Windows.MessageBox]::Show($errorMsg, "错误", "OK", "Error")
    }
} else {
    Write-Host ""
    Write-Host "[取消] 未删除任何文件" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "窗口将在 5 秒后自动关闭..." -ForegroundColor Yellow
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
Write-Host ""

# 强制关闭窗口
Stop-Process -Id $PID

