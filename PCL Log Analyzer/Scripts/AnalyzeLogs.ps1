# ============================================
# PCL Log Analyzer - 主分析脚本
# ============================================

param(
    [string]$CustomLogPath = ""
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Continue"

# ============================================
# 显示处理进度（轻量级，无性能损耗）
# ============================================
function Show-Processing {
    param([string]$Message)
    Write-Host "    $Message" -ForegroundColor Cyan
}

function Show-Complete {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PCL 日志分析工具 v1.2.0" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
$scriptRoot = $PSScriptRoot                     # Scripts 文件夹
$toolRoot = $scriptRoot | Split-Path -Parent    # PCL Log Analyzer 文件夹
$pclRoot = $toolRoot | Split-Path -Parent       # PCL 根目录
$mcDir = Join-Path $pclRoot ".minecraft"
$reportsDir = Join-Path $toolRoot "Reports"

if (!(Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir | Out-Null }

# If custom log path provided, use it directly
if ($CustomLogPath -and (Test-Path $CustomLogPath)) {
    Write-Host "[模式] 手动选择文件" -ForegroundColor Cyan
    Write-Host "  使用: $CustomLogPath" -ForegroundColor Green
    Write-Host ""
    
    $logPath = $CustomLogPath
    $logFileName = Split-Path $logPath -Leaf
    
    # Try to extract version from path
    if ($logPath -match 'versions\\(.+?)\\') {
        $lastVersion = $matches[1]
    } else {
        $lastVersion = "Custom"
    }
    
    # Get Java and Memory from bat file
    $javaFromBat = "Unknown"
    $memoryFromBat = "Unknown"
    $batFile = Join-Path $pclRoot "LatestLaunch.bat"
    
    if (Test-Path $batFile) {
        $batContent = Get-Content $batFile -Encoding UTF8
        foreach ($line in $batContent) {
            if ($line -match '"(.+?\\(JDK[^\\]+))\\bin\\java\.exe"') {
                $javaFromBat = $matches[2]
            }
            if ($line -match '-Xmx(\d+)m') {
                $memMb = [int]$matches[1]
                $memoryFromBat = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
            }
        }
    }
    
    # Skip to analysis
    $skipAutoFind = $true
    } else {
    $skipAutoFind = $false
}

if (!$skipAutoFind) {
    Write-Host "[步骤 1/5] 查找最近一次游戏版本..." -ForegroundColor Yellow
    $lastVersion = $null
    $lastVersionPath = $null
    $javaFromBat = "Unknown"
    $memoryFromBat = "Unknown"
    $batFile = Join-Path $pclRoot "LatestLaunch.bat"

if (Test-Path $batFile) {
    $batContent = Get-Content $batFile -Encoding UTF8
    $titleVersion = $null
    
    foreach ($line in $batContent) {
        # 提取版本名（从title行）
        if ($line -match 'title\s+启动\s*-\s*(.+)') {
            $titleVersion = $matches[1].Trim()
        }
        
        # 提取游戏路径（通用匹配：cd /D "任意绝对路径\"）
        if ($line -match 'cd /D "([A-Za-z]:\\.+?)\\"') {
            $gamePath = $matches[1]
            
            # 判断路径类型并提取版本名
            if ($gamePath -match '\\versions\\([^\\]+)$') {
                # 标准格式: ...\versions\版本名
                $lastVersionPath = $gamePath
                $lastVersion = $matches[1]
                Write-Host "  找到: $lastVersion" -ForegroundColor Green
            }
            elseif ($gamePath -match '\\.minecraft$') {
                # 整合包格式: ...\整合包名\.minecraft
                $lastVersionPath = $gamePath
                if ($titleVersion) {
                    $lastVersion = $titleVersion
                } elseif ($gamePath -match '\\([^\\]+)\\.minecraft$') {
                    $lastVersion = $matches[1]
                } else {
                    $lastVersion = "Modpack"
                }
                Write-Host "  找到: $lastVersion (整合包)" -ForegroundColor Green
            }
            else {
                # 其他自定义格式：使用title或最后一级目录名
                $lastVersionPath = $gamePath
                if ($titleVersion) {
                    $lastVersion = $titleVersion
                } elseif ($gamePath -match '\\([^\\]+)$') {
                    $lastVersion = $matches[1]
                } else {
                    $lastVersion = "Custom"
                }
                Write-Host "  找到: $lastVersion (自定义路径)" -ForegroundColor Green
            }
            Write-Host "  路径: $lastVersionPath" -ForegroundColor Gray
        }
        
        # 提取Java版本
        if ($line -match '"(.+?\\(JDK[^\\]+))\\bin\\java\.exe"') {
            $javaFromBat = $matches[2]
        }
        # 提取内存配置
        if ($line -match '-Xmx(\d+)m') {
            $memMb = [int]$matches[1]
            $memoryFromBat = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
        }
    }
} else {
    Write-Host "  [警告] 未找到 LatestLaunch.bat 文件" -ForegroundColor Yellow
    Write-Host "  建议：先启动一次游戏，或使用【手动选择日志】功能" -ForegroundColor Cyan
}

if (!$lastVersionPath) {
    Write-Host "  [警告] 无法从启动脚本中获取游戏路径" -ForegroundColor Yellow
    Write-Host "  建议：使用【手动选择日志】功能" -ForegroundColor Cyan
}

    if (!$lastVersionPath) {
        Write-Host "  [错误] 未找到游戏版本！" -ForegroundColor Red
        Write-Host ""
        Write-Host "窗口将在 5 秒后自动关闭..." -ForegroundColor Yellow
        for ($i = 5; $i -gt 0; $i--) {
            Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Stop-Process -Id $PID
    }
    
    Write-Host ""
    Write-Host "[步骤 2/5] 定位日志文件..." -ForegroundColor Yellow
    $logPath = Join-Path $lastVersionPath "logs\latest.log"
    $logFileName = Split-Path $logPath -Leaf

    if (!(Test-Path $logPath)) {
        Write-Host "  [错误] 日志文件不存在！" -ForegroundColor Red
        Write-Host ""
        Write-Host "窗口将在 5 秒后自动关闭..." -ForegroundColor Yellow
        for ($i = 5; $i -gt 0; $i--) {
            Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
            Start-Sleep -Seconds 1
        }
        Write-Host ""
        Stop-Process -Id $PID
    }
    
    $logSize = [Math]::Round((Get-Item $logPath).Length / 1MB, 2)
    Write-Host "  日志: ...\" -NoNewline; Write-Host "$logFileName" -ForegroundColor White
    Write-Host "  大小: $logSize MB" -ForegroundColor White
    Write-Host ""
}

# Common section (for both auto and manual mode)
if (!$logFileName) {
    $logFileName = Split-Path $logPath -Leaf
}
    
Write-Host "[步骤 3/5] 分析日志..." -ForegroundColor Yellow
Show-Processing "正在解析日志文件..."

# 调用日志解析模块
$logParserScript = Join-Path $scriptRoot "LogParser.ps1"
$analysis = & $logParserScript -LogPath $logPath -ScriptRoot $scriptRoot

Show-Complete "日志解析完成"
Write-Host ""

# 如果日志中没有找到内存信息和Java版本，尝试从bat文件提取
if ($analysis.JavaVersion -eq "Unknown") { $analysis.JavaVersion = $javaFromBat }

# 如果日志中没有找到内存信息，尝试从 bat 文件提取
if ($analysis.Memory -eq "Unknown") {
    # 确定要查找的 bat 文件
    if ($skipAutoFind) {
        # 手动模式：根据日志文件找对应的启动脚本
        $logDir = Split-Path $logPath -Parent
        $possibleBatFiles = @(
            (Join-Path $logDir "启动脚本.bat"),
            (Join-Path $logDir "launch.bat"),
            (Join-Path $pclRoot "LatestLaunch.bat")
        )
        
        foreach ($batPath in $possibleBatFiles) {
            if (Test-Path $batPath) {
                $batFile = $batPath
                break
            }
        }
    } else {
        # 自动模式：使用 LatestLaunch.bat
        $batFile = Join-Path $pclRoot "LatestLaunch.bat"
    }
    
    # 从 bat 文件提取内存
    if ($batFile -and (Test-Path $batFile)) {
        $batContent = Get-Content $batFile -Encoding UTF8
        foreach ($batLine in $batContent) {
            if ($batLine -match '-Xmx(\d+)m') {
                $memMb = [int]$matches[1]
                $analysis.Memory = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
                break
            }
        }
    }
}

Write-Host "  游戏: $($analysis.GameVersion)" -ForegroundColor White
Write-Host "  加载器: $($analysis.ModLoader)" -ForegroundColor White
if ($analysis.ModCount -gt 0) { Write-Host "  Mod数: $($analysis.ModCount)" -ForegroundColor White }
Write-Host "  Java: $($analysis.JavaVersion)" -ForegroundColor White
if ($analysis.Memory -ne "Unknown") { Write-Host "  内存: $($analysis.Memory)" -ForegroundColor White }
if ($analysis.GPU -ne "Unknown") { Write-Host "  GPU: $($analysis.GPU)" -ForegroundColor Gray }
if ($analysis.GLVersion -ne "Unknown") { Write-Host "  OpenGL: $($analysis.GLVersion)" -ForegroundColor Gray }
if ($analysis.CPU -ne "Unknown") { Write-Host "  CPU: $($analysis.CPU)" -ForegroundColor Gray }
if ($analysis.OS -ne "Unknown") { Write-Host "  系统: $($analysis.OS)" -ForegroundColor Gray }
Write-Host "  状态: $($analysis.GameStatus)" -ForegroundColor $(if ($analysis.IsCrashed) {'Red'} elseif ($analysis.GameStatus -eq 'Normal Exit') {'Green'} else {'Yellow'})
if ($analysis.CrashReport) { Write-Host "  崩溃报告: $($analysis.CrashReport)" -ForegroundColor Red }
Write-Host "  错误数: $($analysis.Errors.Count)" -ForegroundColor $(if ($analysis.Errors.Count -gt 0) {'Red'} else {'Green'})

if ($analysis.GameStatus -eq 'Normal Exit' -and $analysis.Errors.Count -eq 0) {
        Write-Host ""
    Write-Host "  游戏正常退出，未发现错误！" -ForegroundColor Green
    Write-Host "  （仅发现警告级别消息，不是严重问题）" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "[步骤 4/5] 生成报告..." -ForegroundColor Yellow
Show-Processing "正在生成 HTML 报告..."

# 准备报告文件路径
$timePrefix = Get-Date -Format 'yyMMdd-HHmmss'
$reportFile = "$timePrefix-$logFileName.html"
$reportPath = Join-Path $reportsDir $reportFile

# 调用报告生成模块
$reportGeneratorScript = Join-Path $scriptRoot "ReportGenerator.ps1"
$templateDir = Join-Path $toolRoot "Templates"
$reportResult = & $reportGeneratorScript `
    -Analysis $analysis `
    -LogFileName $logFileName `
    -TemplateDir $templateDir `
    -OutputPath $reportPath `
    -ScriptRoot $scriptRoot

# 复制为latest.html
Copy-Item $reportPath (Join-Path $reportsDir "latest.html") -Force

Show-Complete "报告生成完成"
Write-Host ""

Write-Host "  报告: $reportFile" -ForegroundColor Green
Write-Host "  状态: $($reportResult.StatusText)" -ForegroundColor $(if ($reportResult.StatusText -eq '游戏崩溃') {'Red'} elseif ($reportResult.StatusText -eq '发现问题') {'Yellow'} else {'Green'})
Write-Host "  错误: $($reportResult.ErrorCount) 个" -ForegroundColor $(if ($reportResult.ErrorCount -gt 0) {'Red'} else {'Green'})
Write-Host "  建议: $($reportResult.SuggestionCount) 条" -ForegroundColor Cyan
    Write-Host ""
    
Write-Host "[步骤 5/5] 生成历史报告列表..." -ForegroundColor Yellow
Show-Processing "正在更新历史报告索引..."

# 调用历史报告列表生成模块
$generateListScript = Join-Path $scriptRoot "GenerateReportsList.ps1"
$templateDir = Join-Path $toolRoot "Templates"
& $generateListScript -ReportsDir $reportsDir -TemplateDir $templateDir

Show-Complete "历史报告列表已更新"

Write-Host ""
Write-Host "✓ 分析完成！正在打开报告..." -ForegroundColor Green
Start-Process $reportPath
    
    Write-Host ""
Write-Host "窗口将在 5 秒后自动关闭..." -ForegroundColor Yellow
for ($i = 5; $i -gt 0; $i--) {
    Write-Host "  $i..." -NoNewline -ForegroundColor Cyan
    Start-Sleep -Seconds 1
}
Write-Host ""

# 强制关闭窗口
Stop-Process -Id $PID
