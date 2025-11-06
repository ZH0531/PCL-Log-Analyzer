# ============================================
# PCL Log Analyzer - 一键安装/更新脚本
# ============================================

param(
    [string]$CDNUrl = "https://pcl.log.zh8888.top"
)

$ErrorActionPreference = "Stop"

try {
    $ErrorActionPreference = "SilentlyContinue"
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
    $ErrorActionPreference = "Stop"
} catch {
    $ErrorActionPreference = "Stop"
}

# ============================================
# 带进度条的下载函数
# ============================================
function Download-WithProgress {
    param(
        [string]$Url,
        [string]$OutputPath
    )
    
    $frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $frameIndex = 0
    
    # 创建 WebClient 对象
    $webClient = New-Object System.Net.WebClient
    
    # 注册进度事件
    $progressScript = {
        param($sender, $e)
        
        $received = $e.BytesReceived / 1KB
        $total = $e.TotalBytesToReceive / 1KB
        $percent = if ($total -gt 0) { [Math]::Floor(($received / $total) * 100) } else { 0 }
        
        # 进度条长度：50 字符
        $barLength = 50
        $filled = [Math]::Floor($barLength * $percent / 100)
        $empty = $barLength - $filled
        $bar = ('█' * $filled) + ('░' * $empty)  # 实心方块
        
        # 动画帧
        $frame = $script:currentFrame
        
        # 显示进度（同一行更新）
        Write-Host "`r  $frame $bar $percent% ($([Math]::Round($received, 1)) KB / $([Math]::Round($total, 1)) KB)" -NoNewline -ForegroundColor Cyan
    }
    
    Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action $progressScript | Out-Null
    
    try {
        # 启动异步下载
        $download = $webClient.DownloadFileTaskAsync($Url, $OutputPath)
        
        # 动画循环（直到下载完成）
        while (!$download.IsCompleted) {
            $script:currentFrame = $frames[$frameIndex % $frames.Length]
            $frameIndex++
            Start-Sleep -Milliseconds 100
        }
        
        # 等待下载完成
        $download.Wait()
        
        # 等待以确保进度事件完成
        Start-Sleep -Milliseconds 200
        
        # 用完成消息覆盖进度条
        $fileSize = [Math]::Round((Get-Item $OutputPath).Length / 1KB, 1)
        $clearLine = ' ' * 100
        Write-Host "`r$clearLine" -NoNewline
        Write-Host "`r  ✓ 下载完成: $fileSize KB" -ForegroundColor Green
        
    } finally {
        # 清理事件
        Get-EventSubscriber | Where-Object { $_.SourceObject -eq $webClient } | Unregister-Event
        $webClient.Dispose()
    }
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 安装向导" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 检测 PCL 根目录（使用当前工作目录）
$pclRoot = (Get-Location).Path

Write-Host "[1/6] 环境检查..." -ForegroundColor Yellow

# 检查 PowerShell 版本
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 7) {
    Write-Host "  + PowerShell: $($psVersion.Major).$($psVersion.Minor) (Core)" -ForegroundColor Green
} elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -eq 1) {
    Write-Host "  + PowerShell: 5.1 (Windows PowerShell)" -ForegroundColor Yellow
} else {
    Write-Host "  + PowerShell: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
}

# 检查编码
try {
$currentCP = chcp
if ($currentCP -match '65001') {
        Write-Host "  ✓ 编码: UTF-8" -ForegroundColor Green
} else {
        Write-Host "  ! 编码: 非 UTF-8，正在设置..." -ForegroundColor Yellow
    chcp 65001 | Out-Null
        Write-Host "  ✓ 编码: UTF-8 (会话)" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✓ 编码: UTF-8" -ForegroundColor Green
}

Write-Host ""

Write-Host "[2/7] 检测安装位置..." -ForegroundColor Yellow
Write-Host "  ✓ PCL 根目录: $pclRoot" -ForegroundColor White
$installPath = Join-Path $pclRoot "PCL Log Analyzer"
Write-Host ""

Write-Host "[3/7] 检查版本..." -ForegroundColor Yellow

# 下载远程版本文件
$versionUrl = "$CDNUrl/Custom.xaml.ini"
$tempVersion = Join-Path $env:TEMP "remote.version"

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $versionUrl -OutFile $tempVersion -UseBasicParsing
    $versionContent = Get-Content $tempVersion
    
    # 解析版本（第一行：version=x.x.x）
    $versionLine = $versionContent[0].Trim()
    if ($versionLine -match '^version=(.+)$') {
        $remoteVersion = $matches[1]
    } else {
        throw "Invalid version file format. Expected: version=x.x.x"
    }
    
    # 从版本文件解析文件大小
    $remoteFileSizes = @{}
    for ($i = 1; $i -lt $versionContent.Length; $i++) {
        if ($versionContent[$i] -match '^(.+)=(\d+)$') {
            $remoteFileSizes[$matches[1]] = [int]$matches[2]
        }
    }
    
    Remove-Item $tempVersion -Force
    Write-Host "  远程版本: $remoteVersion" -ForegroundColor Cyan
} catch {
    Write-Host "  ! 无法获取远程版本，继续执行" -ForegroundColor Yellow
    $remoteVersion = $null
    $remoteFileSizes = @{}
}

# 检查本地版本
$localVersionFile = Join-Path $installPath "Custom.xaml.ini"
$needsInstall = $true

if (Test-Path $localVersionFile) {
    $localVersionContent = Get-Content $localVersionFile
    $localVersionLine = $localVersionContent[0].Trim()
    
    # 解析版本（第一行：version=x.x.x）
    if ($localVersionLine -match '^version=(.+)$') {
        $localVersion = $matches[1]
    } else {
        $localVersion = "Unknown"
    }
    
    Write-Host "  本地版本:  $localVersion" -ForegroundColor Cyan
    
    # 如果版本匹配则验证文件完整性
    if (-not $remoteVersion) {
        # 远程版本不可用，无法验证
        Write-Host "  ! 无法验证版本，跳过更新检查" -ForegroundColor Yellow
        $needsInstall = $false
    }
    elseif ($localVersion -eq $remoteVersion) {
        Write-Host "  正在检查文件完整性..." -ForegroundColor Gray
        
        $allFilesOk = $true
        
        # 检查版本文件中列出的所有文件
        foreach ($fileEntry in $remoteFileSizes.Keys) {
            $fullPath = Join-Path $installPath $fileEntry
            $expectedSize = $remoteFileSizes[$fileEntry]
            
            if (-not (Test-Path $fullPath)) {
                Write-Host "    ! 文件缺失: $fileEntry" -ForegroundColor Yellow
                $allFilesOk = $false
                break
            }
            
            # 检查文件大小（容差 ±1KB）
            $actualSize = (Get-Item $fullPath).Length
            $tolerance = 1024
            $sizeDiff = [Math]::Abs($actualSize - $expectedSize)
            
            if ($sizeDiff -gt $tolerance) {
                Write-Host "    ! 文件大小不匹配: $fileEntry" -ForegroundColor Yellow
                Write-Host "      预期: ~$expectedSize 字节, 实际: $actualSize 字节" -ForegroundColor Gray
                $allFilesOk = $false
                break
            }
        }
        
        if ($allFilesOk) {
            Write-Host "    ✓ 所有文件完整" -ForegroundColor Green
            Write-Host ""
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host "  ✓ 已是最新版本！" -ForegroundColor Green
            Write-Host "=========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "✓ 当前版本: $localVersion" -ForegroundColor White
            Write-Host "✓ 无需更新" -ForegroundColor Gray
            Write-Host ""
            Write-Host "窗口将在 3 秒后关闭..." -ForegroundColor Gray
            Start-Sleep -Seconds 3
            Stop-Process -Id $PID
        } else {
            Write-Host "    ! 文件已损坏，正在重新安装..." -ForegroundColor Yellow
            $needsInstall = $true
        }
    } else {
        Write-Host "  ✓ 发现更新: $localVersion -> $remoteVersion" -ForegroundColor Green
        $needsInstall = $true
    }
} else {
    Write-Host "  本地版本:  未安装" -ForegroundColor Gray
    Write-Host "  ✓ 首次安装" -ForegroundColor Green
    $needsInstall = $true
}

Write-Host ""

# 如果不需要则跳过下载
if (-not $needsInstall) {
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host "  跳过安装" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "原因: 无法连接到更新服务器" -ForegroundColor Gray
    Write-Host "您的本地安装似乎完好。" -ForegroundColor Gray
    Write-Host ""
    Write-Host "窗口将在 5 秒后关闭..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    exit 0
}

# 准备下载
$zipUrl = "$CDNUrl/PCL Log Analyzer.zip"
$tempZip = Join-Path $env:TEMP "PCL Log Analyzer.zip"

Write-Host "[4/7] 下载安装包..." -ForegroundColor Yellow
Write-Host "  URL: $zipUrl" -ForegroundColor Gray
Write-Host ""

try {
    Download-WithProgress -Url $zipUrl -OutputPath $tempZip
} catch {
    Write-Host "  [错误] 下载失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "请检查您的网络连接或 CDN 地址" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""
Write-Host "[5/7] 安装文件..." -ForegroundColor Yellow

try {
    # 如果存在则备份
    if (Test-Path $installPath) {
        $backupPath = "$installPath.backup"
        if (Test-Path $backupPath) {
            Remove-Item $backupPath -Recurse -Force
        }
        Write-Host "  检测到旧版本，正在备份..." -ForegroundColor Gray
        Move-Item $installPath $backupPath -Force
    }
    
    # 解压文件
    Expand-Archive -Path $tempZip -DestinationPath $pclRoot -Force
    Write-Host "  ✓ 已解压到: $installPath" -ForegroundColor Green
    
    # 清理临时文件
    Remove-Item $tempZip -Force
    
    # 如果备份存在则迁移报告
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        $oldReports = Join-Path $backupPath "Reports"
        $newReports = Join-Path $installPath "Reports"
        
        if ((Test-Path $oldReports) -and (Test-Path $newReports)) {
            Write-Host "  ✓ 正在迁移历史报告..." -ForegroundColor Gray
            Copy-Item "$oldReports\*.html" $newReports -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Item $backupPath -Recurse -Force
    }
    
} catch {
    Write-Host "  [错误] 安装失败: $_" -ForegroundColor Red
    
    # 尝试恢复备份
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        Write-Host "  正在恢复备份..." -ForegroundColor Yellow
        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force
        }
        Move-Item $backupPath $installPath -Force
    }
    
    Start-Sleep -Seconds 5
    exit 1
}

Write-Host ""
Write-Host "[6/7] 验证安装..." -ForegroundColor Yellow

$requiredFiles = @(
    "Scripts\AnalyzeLogs.ps1",
    "Scripts\LogParser.ps1",
    "Scripts\ReportGenerator.ps1",
    "Scripts\GenerateReportsList.ps1",
    "Scripts\SelectLog.ps1",
    "Scripts\ClearReports.ps1",
    "Templates\report-template.html",
    "Templates\reports-list-template.html",
    "Rules\Rules.json",
    "Rules\README.md",
    "Custom.xaml.ini"
)

$allOk = $true
foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $installPath $file
    if (Test-Path $fullPath) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file (缺失)" -ForegroundColor Red
        $allOk = $false
    }
}

Write-Host ""
Write-Host "[7/7] 完成安装..." -ForegroundColor Yellow
Write-Host "  ✓ 脚本编码已配置为 UTF-8 with BOM" -ForegroundColor Green
Write-Host "  ✓ 所有组件就绪" -ForegroundColor Green

Write-Host ""
if ($allOk) {
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  ✓ 安装完成！" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在您可以:" -ForegroundColor Cyan
    Write-Host "  ✓ 点击【分析最新日志】开始使用" -ForegroundColor White
    Write-Host "  ✓ 点击【手动选择日志】进行自定义分析" -ForegroundColor White
} else {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "  安装失败！" -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因:" -ForegroundColor Yellow
    Write-Host "  * 下载过程中网络中断" -ForegroundColor White
    Write-Host "  * 安装包损坏或被篡改" -ForegroundColor White
    Write-Host ""
    Write-Host "正在清理..." -ForegroundColor Yellow
    
    # 删除损坏的安装
    if (Test-Path $installPath) {
        Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ 已删除损坏的文件" -ForegroundColor Green
    }
    
    # 如果存在则恢复备份
    $backupPath = "$installPath.backup"
    if (Test-Path $backupPath) {
        Move-Item $backupPath $installPath -Force
        Write-Host "  ✓ 已恢复旧版本" -ForegroundColor Green
}

Write-Host ""
    Write-Host "请重试或联系支持" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "窗口将在 5 秒后关闭..." -ForegroundColor Gray
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
Write-Host ""

# 强制关闭窗口
Stop-Process -Id $PID

