# ============================================
# PCL Log Analyzer - 日志解析模块
# ============================================

param(
    [string]$LogPath,
    [string]$ScriptRoot = $PSScriptRoot
)

# 加载错误规则
$errorRulesScript = Join-Path $ScriptRoot "ErrorRules.ps1"
. $errorRulesScript

# 初始化分析结果
$analysis = @{
    GameVersion = "Unknown"; ModLoader = "Unknown"; ModCount = 0
    JavaVersion = "Unknown"; Memory = "Unknown"; Errors = @(); KeyLines = @()
    GameStatus = "Unknown"; IsCrashed = $false
    JvmVendor = "Unknown"; OS = "Unknown"; Username = "Unknown"
    Resolution = "Unknown"; NeoForgeVersion = "Unknown"
    GPU = "Unknown"; CPU = "Unknown"; GLVersion = "Unknown"
    CrashReport = ""; ModLauncher = "Unknown"
}

# 读取日志内容
$logContent = Get-Content $LogPath -Encoding UTF8

# ============================================
# 1. 检查游戏状态
# ============================================
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

# ============================================
# 2. 解析基本信息
# ============================================
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
    
    # Java Version
    if ($line -match 'Java Version:\s*([\d\.]+),\s*(.+?)\s*$') {
        # 匹配 "Java Version: 25.0.1, Oracle Corporation"
        $analysis.JavaVersion = $matches[1]
        $analysis.JvmVendor = $matches[2].Trim()
    }
    elseif ($line -match 'JVM identified as (.+?) (\d+\.\d+\.\d+[^\s]*)') { 
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
    
    # Memory
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
    if ($line -match 'Operating System:\s*(.+?)\s+\(amd64\)\s+version\s+([\d\.]+)') {
        # 匹配 "Operating System: Windows 11 (amd64) version 10.0"
        $analysis.OS = "$($matches[1]) (version $($matches[2]))"
    }
    elseif ($line -match 'OS[:\s]+(.+?) arch (.+?) version (.+)') {
        $analysis.OS = "$($matches[1]) $($matches[3]) ($($matches[2]))"
    }
    elseif ($line -match 'OS[:\s]+(.+?) \(([\d\.]+)\)') {
        $analysis.OS = "$($matches[1]) $($matches[2])"
    }
    
    # CPU Info
    if ($line -match 'CPU[:\s]+(\d+)x (.+?)$') {
        $analysis.CPU = "$($matches[1])x $($matches[2])"
    }
    elseif ($line -match 'Processor Name:\s*(.+?)\s*$') {
        # 从崩溃报告的 System Details 中提取 CPU 名称
        if ($analysis.CPU -eq "Unknown") {
            $analysis.CPU = $matches[1].Trim()
        }
    }
    elseif ($line -match 'CPUs:\s*(\d+)') {
        # 从 "CPUs: 20" 提取核心数，但只有在已经有 CPU 名称时才添加
        if ($analysis.CPU -ne "Unknown" -and $analysis.CPU -notmatch '^\d+x') {
            $cpuCount = $matches[1]
            $analysis.CPU = "$cpuCount x $($analysis.CPU)"
        }
    }
    # 注意：arch amd64/x86 只是架构类型，不是真正的CPU型号，不提取
    
    # GPU Info
    if ($line -match 'GL info:\s*(.+?)/(?:PCIe|SSE2)') {
        # 匹配 "GL info: NVIDIA GeForce RTX 5060 Laptop GPU/PCIe/SSE2"
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'Backend API:\s*(.+?)/(?:PCIe|SSE2)') {
        # 匹配 "Backend API: NVIDIA GeForce RTX 4060 Laptop GPU/PCIe/SSE2"
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'Graphics card #0 name:\s*(.+?)\s*$') {
        # 从崩溃报告的 System Details 中提取主显卡名称
        if ($analysis.GPU -eq "Unknown") {
            $analysis.GPU = $matches[1].Trim()
        }
    }
    elseif ($line -match 'GL_RENDERER\s*:\s*(.+?)\s*$') {
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'OpenGL Vendor:\s*(.+?)\s*$') {
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'GPU:\s*(.+?)\s*$') {
        $analysis.GPU = $matches[1].Trim()
    }
    
    # OpenGL Version
    if ($line -match 'OpenGL Version:\s*(.+?)\s*$') {
        $analysis.GLVersion = $matches[1]
    }
    elseif ($line -match 'GL version (.+?),') {
        $analysis.GLVersion = $matches[1]
    }
    
    # Username
    if ($line -match 'Setting user: (.+?)$') {
        $analysis.Username = $matches[1]
    }
    
    # Resolution
    if ($line -match 'Created: (\d+)x(\d+)') {
        $analysis.Resolution = "$($matches[1])x$($matches[2])"
    }
    
    # Mod Count
    if ($line -match 'Loaded (\d+) mods?:') {
        $modCount = [int]$matches[1]
        if ($modCount -gt $analysis.ModCount) {
            $analysis.ModCount = $modCount
        }
    }
    elseif ($line -match '(\d+) mod files? loaded') {
        $modCount = [int]$matches[1]
        if ($modCount -gt $analysis.ModCount) {
            $analysis.ModCount = $modCount
        }
    }
    
    # Crash Report
    if ($line -match 'A detailed walkthrough of the error.+?is available in (.+)') {
        $analysis.CrashReport = $matches[1]
    }
}

# ============================================
# 3. 应用错误规则检测错误
# ============================================
$allRules = Get-ErrorTypes
$lineNumber = 0

foreach ($line in $logContent) {
    $lineNumber++
    
    foreach ($rule in $allRules) {
        if ($line -match $rule.Pattern) {
            $existingError = $analysis.Errors | Where-Object { $_.Type -eq $rule.Type }
            
            if ($existingError) {
                $existingError.Count++
                
                if ($rule.CollectDetails -and $matches[1]) {
                    # 组合多个捕获组形成详细信息
                    if ($matches.Count -gt 3) {
                        # 格式: Mod名 → 依赖 版本+
                        $detail = "$($matches[1]) → $($matches[2]) $($matches[3])+"
                    }
                    elseif ($matches.Count -gt 2) {
                        # 格式: Mod名 → 依赖
                        $detail = "$($matches[1]) → $($matches[2])"
                    }
                    else {
                        $detail = $matches[1].Trim()
                    }
                    
                    if ($existingError.Details -notcontains $detail) {
                        $existingError.Details += $detail
                    }
                }
            }
            else {
                $newError = @{
                    Type = $rule.Type
                    Severity = $rule.Severity
                    Content = $line.Trim()
                    Count = 1
                    Details = @()
                    Priority = $rule.Priority
                }
                
                if ($rule.CollectDetails -and $matches[1]) {
                    # 组合多个捕获组形成详细信息
                    if ($matches.Count -gt 3) {
                        # 格式: Mod名 → 依赖 版本+
                        $detail = "$($matches[1]) → $($matches[2]) $($matches[3])+"
                    }
                    elseif ($matches.Count -gt 2) {
                        # 格式: Mod名 → 依赖
                        $detail = "$($matches[1]) → $($matches[2])"
                    }
                    else {
                        $detail = $matches[1].Trim()
                    }
                    $newError.Details += $detail
                }
                
                $analysis.Errors += $newError
            }
            
            # 收集关键日志（包含ERROR/FATAL级别）
            if ($line -match '/ERROR\]|/FATAL\]') {
                if ($analysis.KeyLines -notcontains $line) {
                    $analysis.KeyLines += $line.Trim()
                }
            }
            
            break
        }
    }
}

# ============================================
# 4. 返回解析结果
# ============================================
return $analysis

