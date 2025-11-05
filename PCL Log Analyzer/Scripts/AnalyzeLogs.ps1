# PCL Log Analyzer v1.0.0

param(
    [string]$CustomLogPath = ""
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Continue"

    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PCL 日志分析工具 v1.0.0" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
$toolRoot = $PSScriptRoot | Split-Path -Parent  # PCL Log Analyzer 文件夹
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
    foreach ($line in $batContent) {
        if ($line -match 'cd /D "(.+?\\versions\\(.+?))\\"') {
            $lastVersionPath = $matches[1]
            $lastVersion = $matches[2]
            Write-Host "  找到: $lastVersion" -ForegroundColor Green
        }
        if ($line -match '"(.+?\\(JDK[^\\]+))\\bin\\java\.exe"') {
            $javaFromBat = $matches[2]
        }
        if ($line -match '-Xmx(\d+)m') {
            $memMb = [int]$matches[1]
            $memoryFromBat = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
        }
    }
}

if (!$lastVersionPath) {
    $versionsDir = Join-Path $mcDir "versions"
    if (Test-Path $versionsDir) {
        $latestFolder = Get-ChildItem $versionsDir -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latestFolder) {
            $lastVersion = $latestFolder.Name
            $lastVersionPath = $latestFolder.FullName
            Write-Host "  使用最近的: $lastVersion" -ForegroundColor Green
        }
    }
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
    
    $analysis = @{
    GameVersion = "Unknown"; ModLoader = "Unknown"; ModCount = 0
    JavaVersion = "Unknown"; Memory = "Unknown"; Errors = @(); KeyLines = @()
    GameStatus = "Unknown"; IsCrashed = $false
    JvmVendor = "Unknown"; OS = "Unknown"; Username = "Unknown"
    Resolution = "Unknown"; NeoForgeVersion = "Unknown"
    GPU = "Unknown"; CPU = "Unknown"; GLVersion = "Unknown"
    CrashReport = ""; ModLauncher = "Unknown"
}

$logContent = Get-Content $logPath -Encoding UTF8

# Check game status from last lines
$lastLines = $logContent | Select-Object -Last 50
$hasShutdown = $false
$hasCrash = $false

foreach ($line in $lastLines) {
    if ($line -match 'Stopping|Shutting down|Closing') { $hasShutdown = $true }
    if ($line -match 'Crash|Exception in|Fatal error') { $hasCrash = $true }
}

if ($hasCrash) {
    $analysis.GameStatus = "Crashed"
    $analysis.IsCrashed = $true
} elseif ($hasShutdown) {
    $analysis.GameStatus = "Normal Exit"
} else {
    $analysis.GameStatus = "Running or Incomplete"
}

        foreach ($line in $logContent) {
    # Game Version
    if ($line -match 'Loading Minecraft ([\d\.]+) with|Minecraft (\d+\.\d+\.?\d*)|mcVersion, (\d+\.\d+\.?\d*)') { 
        if ($matches[1]) { $analysis.GameVersion = $matches[1] }
        elseif ($matches[2]) { $analysis.GameVersion = $matches[2] }
        elseif ($matches[3]) { $analysis.GameVersion = $matches[3] }
    }
    
    # Mod Loader
    if ($line -match 'Loading Minecraft .+ with Fabric Loader ([\d\.]+)') { 
        $analysis.ModLoader = "Fabric $($matches[1])" 
    }
    elseif ($line -match 'Fabric Loader (\d+\.[\d\.]+)') { 
        $analysis.ModLoader = "Fabric $($matches[1])" 
    }
    elseif ($line -match 'neoForgeVersion, ([\d\.]+)') { 
        $analysis.ModLoader = "NeoForge $($matches[1])"
        $analysis.NeoForgeVersion = $matches[1]
    }
    elseif ($line -match 'NeoForge ([\d\.]+)') { 
        $analysis.ModLoader = "NeoForge $($matches[1])"
        $analysis.NeoForgeVersion = $matches[1]
    }
    elseif ($line -match 'MinecraftForge|forge') { 
        if ($analysis.ModLoader -eq "Unknown") { $analysis.ModLoader = "Forge" } 
    }
    
    # Java Version (detailed)
    if ($line -match 'JVM identified as (.+?) (\d+\.\d+\.\d+[^\s]*)') { 
        $analysis.JvmVendor = $matches[1]
        $analysis.JavaVersion = $matches[2]
    }
    elseif ($line -match 'java version ([\d\.]+) by (.+?);') { 
                $analysis.JavaVersion = $matches[1]
        $analysis.JvmVendor = $matches[2]
    }
    elseif ($line -match 'Java is Java HotSpot.+version ([0-9]+\.[0-9]+\.[0-9_]+)') { 
        $analysis.JavaVersion = $matches[1] 
    }
    
    # Memory Info (从日志中提取)
    if ($line -match '-Xmx(\d+)m\s|JVM Flags.*-Xmx(\d+)m') {
        if ($matches[1]) {
            $memMb = [int]$matches[1]
        } elseif ($matches[2]) {
            $memMb = [int]$matches[2]
        }
        if ($memMb -and $analysis.Memory -eq "Unknown") {
            $analysis.Memory = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
        }
    }
    elseif ($line -match 'Max memory:\s*(\d+)\s*MB') {
        if ($analysis.Memory -eq "Unknown") {
            $memMb = [int]$matches[1]
            $analysis.Memory = "$([Math]::Round($memMb/1024, 1)) GB ($memMb MB)"
        }
    }
    
    # OS Info
    if ($line -match 'OS[:\s]+(.+?) arch (.+?) version (.+)') {
        $analysis.OS = "$($matches[1]) $($matches[3]) ($($matches[2]))"
    }
    elseif ($line -match 'OS[:\s]+(.+?) \(([\d\.]+)\)') {
        $analysis.OS = "$($matches[1]) $($matches[2])"
    }
    
    # CPU Info
    if ($line -match 'CPU[:\s]+(\d+)x (.+?)$') {
        $analysis.CPU = "$($matches[1])x $($matches[2])"
    }
    
    # GPU Info
    if ($line -match 'GL info[:\s]+(.+?)/PCIe/SSE2 GL version (.+?), (.+)') {
        $analysis.GPU = $matches[1]
        $analysis.GLVersion = "$($matches[2]) ($($matches[3]))"
    }
    elseif ($line -match 'GPU[:\s]+(.+?)/PCIe/SSE2 \(Supports (.+?)\)') {
        $analysis.GPU = $matches[1]
        $analysis.GLVersion = $matches[2]
    }
    elseif ($line -match 'GPU[:\s]+(.+?)$') {
        $analysis.GPU = $matches[1]
    }
    elseif ($line -match 'OpenGL Renderer[:\s]+(.+)') {
        if ($analysis.GPU -eq "Unknown") { $analysis.GPU = $matches[1] }
    }
    elseif ($line -match 'OpenGL Version[:\s]+(.+)') {
        if ($analysis.GLVersion -eq "Unknown") { $analysis.GLVersion = $matches[1] }
    }
    
    # ModLauncher
    if ($line -match 'ModLauncher ([\d\.]+\+[^\s]+) starting') {
        $analysis.ModLauncher = $matches[1]
    }
    
    # Crash Report
    if ($line -match 'Crash report saved to .+\\(crash-[\d\-]+\.txt)') {
        $analysis.CrashReport = $matches[1]
        $analysis.IsCrashed = $true
    }
    
    # Username
    if ($line -match '--username, ([^,\]]+)|Setting user[:\s]+(.+)') { 
        if ($matches[1]) { $analysis.Username = $matches[1] }
        elseif ($matches[2]) { $analysis.Username = $matches[2] }
    }
    
    # Resolution
    if ($line -match '--width, (\d+), --height, (\d+)') { 
        $analysis.Resolution = "$($matches[1])x$($matches[2])"
    }
    
    # Mod Count
    if ($line -match 'Loading (\d+) mods[:\s]') { $analysis.ModCount = [int]$matches[1] }
}

if ($analysis.JavaVersion -eq "Unknown") { $analysis.JavaVersion = $javaFromBat }
if ($analysis.Memory -eq "Unknown") { $analysis.Memory = $memoryFromBat }

# 加载错误识别规则
. (Join-Path $PSScriptRoot "ErrorRules.ps1")
$errorTypes = Get-ErrorTypes

# 自动从规则中提取需要收集详情的错误类型
$collectDetailsTypes = @($errorTypes | Where-Object { $_.CollectDetails -eq $true } | ForEach-Object { $_.Type })

for ($i = 0; $i -lt $logContent.Count; $i++) {
    $line = $logContent[$i]
    $matched = $false
    
    foreach ($errType in $errorTypes) {
        if ($line -match $errType.Pattern) {
            $fullContent = $line.Trim()
            
            # Get next 5-10 lines for details (especially for "Currently" lines and Mod ID lists)
            if ($i + 1 -lt $logContent.Count) {
                for ($j = 1; $j -le 10; $j++) {
                    if ($i + $j -lt $logContent.Count) {
                        $nextLine = $logContent[$i + $j].Trim()
                        # Include lines that don't start with timestamp AND are not empty
                        if ($nextLine -and $nextLine -notmatch '^\[\d+' -and $nextLine.Length -gt 2) {
                            $fullContent += "`n  " + $nextLine
                        } elseif ($nextLine -match '^\[\d+') {
                            # Stop if we hit a new log entry
                            break
                        }
                    }
                }
            }
            
            # 智能去重逻辑
            $shouldAdd = $false
            $existingError = $null
            
            if ($collectDetailsTypes -contains $errType.Type) {
                # 收集详情类型：按类型合并，收集所有详细信息
                $existingIndex = -1
                for ($idx = 0; $idx -lt $analysis.Errors.Count; $idx++) {
                    if ($analysis.Errors[$idx].Type -eq $errType.Type) {
                        $existingIndex = $idx
                        break
                    }
                }
                
                if ($existingIndex -eq -1) {
                    $shouldAdd = $true
                } else {
                    # 已存在，直接更新数组中的对象
                    if ($errType.Type -eq 'Fabric环境安装了Forge Mod' -or $errType.Type -eq 'Forge环境安装了Fabric Mod') {
                        # 提取并合并错误的Mod文件名
                        if (!$analysis.Errors[$existingIndex].Details) { 
                            $analysis.Errors[$existingIndex].Details = @() 
                        }
                        $lines = $fullContent -split "`n"
                        foreach ($modLine in $lines) {
                            if ($modLine -match '^\s*-\s*\[.*?\]\s*([^\s]+\.jar)') {
                                $jarName = $matches[1]
                                if ($analysis.Errors[$existingIndex].Details -notcontains $jarName) {
                                    $analysis.Errors[$existingIndex].Details += $jarName
                                }
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod初始化失败') {
                        if ($fullContent -match 'for modid\s+(\w+)') {
                            if (!$analysis.Errors[$existingIndex].Details) { 
                                $analysis.Errors[$existingIndex].Details = @() 
                            }
                            $modName = $matches[1]
                            if ($analysis.Errors[$existingIndex].Details -notcontains $modName) {
                                $analysis.Errors[$existingIndex].Details += $modName
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod加载失败') {
                        if ($fullContent -match 'ModID:\s*(\w+)') {
                            if (!$analysis.Errors[$existingIndex].Details) { 
                                $analysis.Errors[$existingIndex].Details = @() 
                            }
                            $modName = $matches[1]
                            if ($analysis.Errors[$existingIndex].Details -notcontains $modName) {
                                $analysis.Errors[$existingIndex].Details += $modName
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod版本不匹配') {
                        # 提取版本不匹配的详细信息
                        if ($fullContent -match 'Mod\s+(\w+)\s+requires\s+(\w+)\s+([\d\.\-]+)\s+or\s+above(?:\s+and\s+below\s+([\d\.\-]+))?') {
                            if (!$analysis.Errors[$existingIndex].Details) { 
                                $analysis.Errors[$existingIndex].Details = @() 
                            }
                            $versionReq = if ($matches[4]) { "$($matches[3])~$($matches[4])" } else { "$($matches[3])+" }
                            $detail = "$($matches[1]) 需要 $($matches[2]) $versionReq"
                            if ($analysis.Errors[$existingIndex].Details -notcontains $detail) {
                                $analysis.Errors[$existingIndex].Details += $detail
                            }
                        } elseif ($fullContent -match 'Mod\s+(\w+)\s+requires\s+(\w+)') {
                            # 备用匹配：只提取Mod名称和依赖名称
                            if (!$analysis.Errors[$existingIndex].Details) { 
                                $analysis.Errors[$existingIndex].Details = @() 
                            }
                            $detail = "$($matches[1]) 需要 $($matches[2])"
                            if ($analysis.Errors[$existingIndex].Details -notcontains $detail) {
                                $analysis.Errors[$existingIndex].Details += $detail
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod依赖缺失') {
                        # 提取依赖缺失的详细信息
                        if (!$analysis.Errors[$existingIndex].Details) { 
                            $analysis.Errors[$existingIndex].Details = @() 
                        }
                        # 尝试多种格式匹配
                        $lines = $fullContent -split "`n"
                        foreach ($depLine in $lines) {
                            # 格式1: "Mod ID: 'modid'"
                            if ($depLine -match "Mod ID:\s*'([^']+)'") {
                                if ($analysis.Errors[$existingIndex].Details -notcontains $matches[1]) {
                                    $analysis.Errors[$existingIndex].Details += $matches[1]
                                }
                            }
                            # 格式2: "mod 'modid'"  
                            elseif ($depLine -match "mod\s+'([^']+)'") {
                                if ($analysis.Errors[$existingIndex].Details -notcontains $matches[1]) {
                                    $analysis.Errors[$existingIndex].Details += $matches[1]
                                }
                            }
                            # 格式3: 缩进的 "modid @ version" 或 "modid"
                            elseif ($depLine -match '^\s+([a-z_][a-z0-9_]*)\s*(@|$)') {
                                $modId = $matches[1]
                                if ($modId -and $modId.Length -gt 2 -and $analysis.Errors[$existingIndex].Details -notcontains $modId) {
                                    $analysis.Errors[$existingIndex].Details += $modId
                                }
                            }
                        }
    } else {
                        # 其他收集详情类型：直接增加计数
                        $analysis.Errors[$existingIndex].Count++
                    }
                }
            } else {
                # 具体错误：按类型去重
                $exists = $analysis.Errors | Where-Object { $_.Type -eq $errType.Type }
                if (!$exists) { $shouldAdd = $true }
            }
            
            if ($shouldAdd) {
                $newError = @{ Type = $errType.Type; Severity = $errType.Severity; Priority = $errType.Priority; Content = $fullContent }
                # 初始化计数和详情
                if ($collectDetailsTypes -contains $errType.Type) {
                    if ($errType.Type -eq 'Fabric环境安装了Forge Mod' -or $errType.Type -eq 'Forge环境安装了Fabric Mod') {
                        # 提取错误的Mod文件名
                        $newError.Details = @()
                        $lines = $fullContent -split "`n"
                        foreach ($modLine in $lines) {
                            # 匹配格式：	- [名称] filename.jar 或   - [名称] filename.jar
                            if ($modLine -match '^\s*-\s*\[.*?\]\s*([^\s]+\.jar)') {
                                $jarName = $matches[1]
                                if ($newError.Details -notcontains $jarName) {
                                    $newError.Details += $jarName
                                }
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod与MC版本不兼容') {
                        # Mod与MC版本不兼容：提取Mod名称
                        $newError.Details = @()
                        $lines = $fullContent -split "`n"
                        foreach ($modLine in $lines) {
                            # 提取Mod名称：'ModName' (modid) version
                            if ($modLine -match "['']([^'']+)[''][^)]*\(([^)]+)\)\s+([\d\.]+\+mc[\d\.]+)") {
                                $modName = $matches[1]
                                if ($newError.Details -notcontains $modName) {
                                    $newError.Details += $modName
                                }
                            }
                        }
                    } elseif ($errType.Type -eq 'Mod初始化失败') {
                        # Mod初始化失败：只用Details，不用Count
                        $newError.Details = @()
                        if ($fullContent -match 'for modid\s+(\w+)') {
                            $newError.Details += $matches[1]
                        }
                    } elseif ($errType.Type -eq 'Mod加载失败') {
                        # Mod加载失败：提取ModID
                        $newError.Details = @()
                        if ($fullContent -match 'ModID:\s*(\w+)') {
                            $newError.Details += $matches[1]
                        }
                    } elseif ($errType.Type -eq 'Mod版本不匹配') {
                        # Mod版本不匹配：提取详细信息
                        $newError.Details = @()
                        if ($fullContent -match 'Mod\s+(\w+)\s+requires\s+(\w+)\s+([\d\.\-]+)\s+or\s+above(?:\s+and\s+below\s+([\d\.\-]+))?') {
                            $versionReq = if ($matches[4]) { "$($matches[3])~$($matches[4])" } else { "$($matches[3])+" }
                            $newError.Details += "$($matches[1]) 需要 $($matches[2]) $versionReq"
                        } elseif ($fullContent -match 'Mod\s+(\w+)\s+requires\s+(\w+)') {
                            $newError.Details += "$($matches[1]) 需要 $($matches[2])"
                        }
                    } elseif ($errType.Type -eq 'Mod依赖缺失') {
                        # Mod依赖缺失：提取依赖列表
                        $newError.Details = @()
                        $lines = $fullContent -split "`n"
                        foreach ($depLine in $lines) {
                            # 格式1: "Mod ID: 'modid'"
                            if ($depLine -match "Mod ID:\s*'([^']+)'") {
                                if ($newError.Details -notcontains $matches[1]) {
                                    $newError.Details += $matches[1]
                                }
                            }
                            # 格式2: "mod 'modid'"  
                            elseif ($depLine -match "mod\s+'([^']+)'") {
                                if ($newError.Details -notcontains $matches[1]) {
                                    $newError.Details += $matches[1]
                                }
                            }
                            # 格式3: 缩进的 "modid @ version" 或 "modid"
                            elseif ($depLine -match '^\s+([a-z_][a-z0-9_]*)\s*(@|$)') {
                                $modId = $matches[1]
                                if ($modId -and $modId.Length -gt 2 -and $newError.Details -notcontains $modId) {
                                    $newError.Details += $modId
                                }
                            }
                        }
                    } else {
                        # 其他类型：使用Count
                        $newError.Count = 1
                        $newError.Details = @()
                    }
                }
                $analysis.Errors += $newError
            }
            
            $matched = $true
            break
        }
    }
    
    if ($line -match '/ERROR\]|/FATAL\]|^Caused by:|/WARN\].*(non-fabric mods|non-forge mods)') {
        $keyLine = $line.Trim()
        
        # 对于特定的WARN类型，收集后续的详细列表
        if ($line -match '/WARN\].*(non-fabric mods|non-forge mods)') {
            # 收集后续10行的详细列表
            if ($i + 1 -lt $logContent.Count) {
                for ($j = 1; $j -le 10; $j++) {
                    if ($i + $j -lt $logContent.Count) {
                        $nextLine = $logContent[$i + $j].Trim()
                        # 包含以 - 或 tab - 开头的列表项
                        if ($nextLine -match '^\s*-\s*\[' -or $nextLine -match '^\t-') {
                            $keyLine += "`n  " + $nextLine
                        } elseif ($nextLine -match '^\[\d+') {
                            # 遇到新的日志条目就停止
                            break
                        }
                    }
                }
            }
        }
        
        $analysis.KeyLines += $keyLine
    }
}


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

Write-Host "[步骤 4/5] 生成建议..." -ForegroundColor Yellow

# 按因果关系和严重程度排序（根本原因 > 直接错误 > 连带错误）
# 按优先级排序错误（使用错误规则中定义的Priority字段）
$sortedErrors = $analysis.Errors | Sort-Object { 
    if ($null -eq $_.Priority) { 100 } else { $_.Priority }
}

# 计算显示的错误数量（总错误数）
$displayErrorCount = $sortedErrors.Count

# 从排序后的错误生成建议
$suggestions = @()
foreach ($err in $sortedErrors) {
    $suggestion = Get-ErrorSuggestion -ErrorType $err.Type
    if ($suggestion -and !($suggestions | Where-Object {$_.Title -eq $suggestion.Title})) {
        $suggestions += $suggestion
    }
}
Write-Host "  生成了 $($suggestions.Count) 条建议" -ForegroundColor Green
Write-Host ""

Write-Host "[步骤 5/5] 生成报告..." -ForegroundColor Yellow
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$timePrefix = Get-Date -Format 'yyMMdd-HHmmss'
$reportFile = "$timePrefix-$logFileName.html"
$reportPath = Join-Path $reportsDir $reportFile

# 生成基本信息HTML
$basicInfoHtml = @"
<div class='info-grid-3'>
<div class='info-item'><div class='info-label'>游戏版本</div><div class='info-value'>$($analysis.GameVersion)</div></div>
<div class='info-item'><div class='info-label'>Mod加载器</div><div class='info-value'>$($analysis.ModLoader)</div></div>
<div class='info-item'><div class='info-label'>Java版本</div><div class='info-value'>$($analysis.JavaVersion)</div></div>
$(if ($analysis.Memory -ne "Unknown") { "<div class='info-item'><div class='info-label'>内存分配</div><div class='info-value'>$($analysis.Memory)</div></div>" })
$(if ($analysis.ModCount -gt 0) { "<div class='info-item'><div class='info-label'>Mod数量</div><div class='info-value'>$($analysis.ModCount)</div></div>" })
$(if ($analysis.Username -ne "Unknown") { "<div class='info-item'><div class='info-label'>用户名</div><div class='info-value'>$($analysis.Username)</div></div>" })
$(if ($analysis.Resolution -ne "Unknown") { "<div class='info-item'><div class='info-label'>分辨率</div><div class='info-value'>$($analysis.Resolution)</div></div>" })
    </div>
<div class='info-grid-2'>
$(if ($analysis.JvmVendor -ne "Unknown") { "<div class='info-item'><div class='info-label'>JVM厂商</div><div class='info-value'>$($analysis.JvmVendor)</div></div>" })
$(if ($analysis.CPU -ne "Unknown") { "<div class='info-item'><div class='info-label'>CPU</div><div class='info-value'>$($analysis.CPU)</div></div>" })
$(if ($analysis.GPU -ne "Unknown") { "<div class='info-item'><div class='info-label'>GPU</div><div class='info-value'>$($analysis.GPU)</div></div>" })
$(if ($analysis.GLVersion -ne "Unknown") { "<div class='info-item'><div class='info-label'>OpenGL</div><div class='info-value'>$($analysis.GLVersion)</div></div>" })
$(if ($analysis.OS -ne "Unknown") { "<div class='info-item'><div class='info-label'>操作系统</div><div class='info-value'>$($analysis.OS)</div></div>" })
$(if ($analysis.CrashReport) { "<div class='info-item' style='grid-column:1/-1;border-left-color:#ff6b6b'><div class='info-label'>崩溃报告</div><div class='info-value' style='color:#ff6b6b'>$($analysis.CrashReport)</div></div>" })
</div>
"@

# 将错误数据序列化为 JSON（由前端 JavaScript 渲染）
# 强制数组格式 @() 防止单个元素时变成对象
$errorsJsonData = @($sortedErrors | ForEach-Object {
    # 清理Content中的乱码字符
    $cleanContent = if ($_.Content) {
        $_.Content -replace '[^\x20-\x7E\u4e00-\u9fff\r\n\t]', '?'
    } else { "" }
    
    @{
        Type = $_.Type
        Severity = $_.Severity
        Content = $cleanContent
        Count = $_.Count
        Details = $_.Details
        Priority = $_.Priority
        IsCollectDetails = ($collectDetailsTypes -contains $_.Type)
    }
})

$errorsJson = $errorsJsonData | ConvertTo-Json -Depth 10 -Compress
if ($null -eq $errorsJson -or $errorsJson -eq "null") {
    $errorsJson = "[]"
}
# 强制确保是数组格式（修复PowerShell 5.1的单元素对象bug）
if ($errorsJson -notmatch '^\s*\[') {
    $errorsJson = "[$errorsJson]"
}

# 生成建议HTML
$sugHtml = ""
$i = 1
foreach ($sug in $suggestions) {
    $sugHtml += "<div class='sug-box'><strong>$i.</strong> $($sug.Text)</div>"
    $i++
}
if ($suggestions.Count -eq 0) {
    $sugHtml = "<div class='empty-state'>暂无建议</div>"
}

# 生成日志HTML
$logHtml = ""
foreach ($line in $analysis.KeyLines) {
    $cleanLine = $line -replace '[^\x20-\x7E\u4e00-\u9fff\[\]\(\)\{\}\-\+\=\.\,\:\;\/\\]', '?'
    $logHtml += "<div class='log-line'>$cleanLine</div>"
}
if ($analysis.KeyLines.Count -eq 0) {
    $logHtml = "<div class='empty-state'>无关键日志</div>"
}

# 确定状态（检查是否有严重错误）
$hasSevereError = $analysis.Errors | Where-Object { $_.Severity -eq '严重' }
$isCritical = $analysis.IsCrashed -or $hasSevereError.Count -gt 0

$statusColor = if ($isCritical) { '#ff6b6b' } elseif ($analysis.Errors.Count -gt 0) { '#ffd93d' } else { '#6bcf7f' }
$statusText = if ($isCritical) { '游戏崩溃' } elseif ($analysis.Errors.Count -gt 0) { '发现问题' } else { '运行正常' }

# 读取HTML模板
$templatePath = Join-Path $toolRoot "Templates\report-template.html"
$html = Get-Content $templatePath -Raw -Encoding UTF8

# 替换占位符
$html = $html -replace '{{PAGE_TITLE}}', "PCL Log Analyzer - $logFileName"
$html = $html -replace '{{STATUS_COLOR}}', $statusColor
$html = $html -replace '{{LOG_FILE_NAME}}', $logFileName
$html = $html -replace '{{STATUS_TEXT}}', $statusText
$html = $html -replace '{{BASIC_INFO_HTML}}', $basicInfoHtml
$html = $html -replace '{{SUGGESTIONS_HTML}}', $sugHtml
$html = $html -replace '{{ERROR_COUNT}}', $displayErrorCount
$html = $html -replace '{{ERRORS_JSON}}', $errorsJson
$html = $html -replace '{{LOG_COUNT}}', $analysis.KeyLines.Count
$html = $html -replace '{{LOGS_HTML}}', $logHtml
$html = $html -replace '{{TIMESTAMP}}', $timestamp

# 输出HTML文件
$html | Out-File -FilePath $reportPath -Encoding UTF8
Copy-Item $reportPath (Join-Path $reportsDir "latest.html") -Force

Write-Host "  报告: $reportFile" -ForegroundColor Green
    Write-Host ""
    
    Write-Host ""
Write-Host "分析完成！正在打开报告..." -ForegroundColor Green
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
