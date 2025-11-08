# ============================================
# PCL Log Analyzer - 日志解析模块
# ============================================

param(
    [string]$LogPath,
    [string]$ScriptRoot = $PSScriptRoot
)

# 加载错误规则（从JSON）
$rulesPath = Join-Path (Split-Path $ScriptRoot -Parent) "Rules\Rules.json"
$rulesJson = Get-Content $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allRules = $rulesJson.errors

# 初始化分析结果
$analysis = @{
    GameVersion = "Unknown"; ModLoader = "Unknown"; ModCount = 0
    JavaVersion = "Unknown"; Memory = "Unknown"; Errors = @(); KeyLines = @()
    GameStatus = "Unknown"; IsCrashed = $false
    JvmVendor = "Unknown"; OS = "Unknown"; Username = "Unknown"
    Resolution = "Unknown"; NeoForgeVersion = "Unknown"
    GPU = "Unknown"; CPU = "Unknown"; GLVersion = "Unknown"
    CrashReport = ""; ModLauncher = "Unknown"
    CrashReportPath = ""  # 用于存储崩溃报告路径
}

# 读取日志内容（自动检测编码）
try {
    # 优先尝试 UTF-8
    $logContent = Get-Content $LogPath -Encoding UTF8 -ErrorAction Stop
    
    # 检测是否有乱码（��字符，通常是编码错误的标志）
    $hasMojibake = $false
    foreach ($line in ($logContent | Select-Object -First 100)) {
        if ($line -match '��') {
            $hasMojibake = $true
            break
        }
    }
    
    # 如果检测到乱码，尝试使用系统默认编码
    if ($hasMojibake) {
        $logContent = Get-Content $LogPath -Encoding Default
    }
} catch {
    # UTF-8 失败，回退到系统默认编码
    $logContent = Get-Content $LogPath -Encoding Default
}

# 清理 Minecraft 颜色代码（§ 字符及后续一个字符）
$logContent = $logContent | ForEach-Object {
    $_ -replace '§.', ''
}

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
    elseif ($line -match '--fml\.forgeVersion,\s*([\d\.]+)') {
        # 从启动参数提取 Forge 版本：--fml.forgeVersion, 47.4.10
        $analysis.ModLoader = "Forge $($matches[1])"
    }
    elseif ($line -match 'Forge ([\d\.]+)') {
        if ($analysis.ModLoader -eq "Unknown") {
            $analysis.ModLoader = "Forge $($matches[1])"
        }
    }
    elseif ($line -match 'MinecraftForge|forge') { 
        if ($analysis.ModLoader -eq "Unknown") { $analysis.ModLoader = "Forge" } 
    }
    
    # ModLauncher Version
    if ($line -match 'ModLauncher ([\d\.]+(?:\+[\w\.]+)?)') {
        $analysis.ModLauncher = $matches[1]
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
    if ($line -match 'Processor Name:\s*(.+?)\s*$') {
        # 从崩溃报告的 System Details 中提取 CPU 名称（优先）
        $analysis.CPU = $matches[1].Trim()
    }
    elseif ($line -match 'CPU[:\s]+(\d+)x (.+?)$') {
        # 格式: CPU: 20x Intel Core i9
        if ($analysis.CPU -eq "Unknown") {
            $analysis.CPU = "$($matches[1])x $($matches[2])"
        }
    }
    
    # CPU核心数（如果之前只提取了名称）
    if ($line -match 'CPUs:\s*(\d+)') {
        if ($analysis.CPU -ne "Unknown" -and $analysis.CPU -notmatch '^\d+\s*x') {
            $cpuCount = $matches[1]
            $analysis.CPU = "$cpuCount x $($analysis.CPU)"
        }
    }
    
    # Number of logical CPUs（备选）
    if ($line -match 'Number of logical CPUs:\s*(\d+)') {
        if ($analysis.CPU -ne "Unknown" -and $analysis.CPU -notmatch '^\d+\s*x') {
            $cpuCount = $matches[1]
            $analysis.CPU = "$cpuCount x $($analysis.CPU)"
        }
    }
    
    # 检测崩溃报告路径（支持多种格式）
    # 格式1: Crash report saved to: xxx
    # 格式2: This crash report has been saved to: xxx
    if ($line -match 'crash report (?:saved to|has been saved to):\s*(.+\.txt)') {
        $crashPath = $matches[1].Trim()
        
        # 方案1：尝试使用绝对路径
        if (Test-Path $crashPath) {
            $analysis.CrashReportPath = $crashPath
        }
        # 方案2：如果绝对路径不存在，尝试相对路径
        else {
            # 提取崩溃报告文件名（如 crash-2025-10-26_10.27.36-fml.txt）
            $crashFileName = Split-Path $crashPath -Leaf
            
            # 从主日志路径计算相对路径
            # 日志路径：D:\...\logs\latest.log
            # 崩溃路径：D:\...\crash-reports\crash-xxx.txt
            $logDir = Split-Path $LogPath -Parent  # 得到 logs 目录
            $versionDir = Split-Path $logDir -Parent  # 得到版本目录
            $relativeCrashPath = Join-Path $versionDir "crash-reports\$crashFileName"
            
            if (Test-Path $relativeCrashPath) {
                $analysis.CrashReportPath = $relativeCrashPath
            }
        }
    }
    
    # GPU Info
    if ($line -match 'GL info:\s*(.+?)/(?:PCIe|SSE2)') {
        # 匹配 "GL info: NVIDIA GeForce RTX 5060 Laptop GPU/PCIe/SSE2"
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'Backend API:\s*(.+?)(?:\s*\(Supports|\s*/|$)') {
        # 只提取GPU名称，去掉 /PCIe/SSE2 和 (Supports OpenGL...) 部分
        $gpuPart = $matches[1].Trim()
        $analysis.GPU = $gpuPart
    }
    elseif ($line -match 'Graphics card #0 name:\s*(.+?)\s*$') {
        # 从崩溃报告的 System Details 中提取主显卡名称
        if ($analysis.GPU -eq "Unknown") {
            $analysis.GPU = $matches[1].Trim()
        }
    }
    elseif ($line -match 'GL_RENDERER\s*:\s*(.+?)(?:\s*\(Supports|\s*/|$)') {
        # 只提取GPU名称，去掉 /PCIe/SSE2 和 (Supports OpenGL...) 部分
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'OpenGL Vendor:\s*(.+?)\s*$') {
        $analysis.GPU = $matches[1].Trim()
    }
    elseif ($line -match 'GPU:\s*(.+?)(?:\s*\(Supports|\s*/|$)') {
        # 只提取GPU名称，去掉 /PCIe/SSE2 和 (Supports OpenGL...) 部分
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
    
    # Resolution (从启动参数提取)
    if ($line -match '--width,\s*(\d+).*--height,\s*(\d+)') {
        $analysis.Resolution = "$($matches[1])x$($matches[2])"
    }
    
    # Mod Count
    if ($line -match 'Load(?:ed|ing) (\d+) mods?:') {
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
# 3. 辅助函数：提取 Mod 名称
# ============================================
function Extract-ModName {
    param([string]$Line)
    
    # 黑名单：非 Mod 的包名/类名
    $blacklist = @(
        'minecraft', 'forge', 'neoforge', 'fabricmc', 'fml', 'common',
        'http', 'https', 'file', 'jar', 'zip',
        'sun', 'java', 'javax', 'com', 'net', 'org',
        'ForgeMod', 'NeoForgeMod', 'MinecraftServer', 'CrashReport', 'ModLoader',
        'SSLHandshakeException', 'ValidatorException', 'SunCertPathBuilderException',
        'TagLoader', 'ForgeHooks', 'RecipeManager', 'ServerAdvancementManager',
        'ModelManager', 'Minecraft', 'DataPackConfig', 'ModSorter',
        'Logger', 'Message', 'Exception', 'Error', 'FATAL', 'ERROR', 'WARN', 'INFO',
        'load', 'task', 'can', 'not', 'has', 'from', 'with', 'this', 'that',
        'property', 'failed', 'item', 'references', 'element', 'missing', 'version',
        'loot_tables', 'advancement', 'recipe', 'data', 'config', 'path', 'mod',
        'phase', 'dependencies', 'loading', 'LOADING', 'CORE',
        'range', 'expected', 'actual', 'requested'
    )
    
    $modNames = @()
    
    # 优先级 1: 特殊模式 - task can not load: MSM_XXX
    if ($Line -match 'task can not load: (MSM_[A-Z0-9_]+)') {
        return 'maid_storage_manager'
    }
    
    # 优先级 2: Recipe/advancement/loot_tables 后的 modname:
    # 这些通常是错误的直接原因
    if ($Line -match '(?:Recipe|advancement|loot_tables|element)\s+([a-z][a-z0-9_\-]{2,}):') {
        $modName = $matches[1]
        if ($blacklist -notcontains $modName) {
            $modNames += $modName
        }
    }
    
    # 优先级 3: 日志中的其他 modname: 模式
    $allMatches = [regex]::Matches($Line, '\b([a-z][a-z0-9_\-]{2,}):')
    foreach ($match in $allMatches) {
        $modName = $match.Groups[1].Value
        if ($blacklist -notcontains $modName -and $modNames -notcontains $modName) {
            $modNames += $modName
        }
    }
    
    # 优先级 4: [ModName/]: 或 [ModName/Class]: 日志来源
    # 匹配格式: [Moonlight/]: 或 [maidsoulkitchen/VerifyExistence]:
    if ($Line -match '\[([a-zA-Z0-9_\-\.]+(?:/[a-zA-Z0-9_\-\.]+)?)\]:') {
        $fullPath = $matches[1]
        
        # 过滤黑名单：只检查关键组件名（不检查包名前缀）
        $lastPart = $fullPath
        if ($fullPath -match '\.([a-zA-Z0-9_\-]+)$') {
            $lastPart = $matches[1]
        }
        
        # 黑名单：只检查核心组件，不检查包名前缀（com/net/org）
        $coreBlacklist = @('minecraft', 'forge', 'neoforge', 'fabricmc', 'fml', 
                           'ForgeMod', 'NeoForgeMod', 'ModLoader', 'MinecraftServer', 'CrashReport',
                           'TagLoader', 'ForgeHooks', 'RecipeManager', 'ServerAdvancementManager',
                           'ModelManager', 'Minecraft', 'DataPackConfig')
        
        $containsBlacklisted = $false
        foreach ($blackItem in $coreBlacklist) {
            if ($fullPath -match [regex]::Escape($blackItem)) {
                $containsBlacklisted = $true
                break
            }
        }
        
        if (-not $containsBlacklisted -and $blacklist -notcontains $lastPart) {
            # 识别包名模式
            $modName = $null
            
            # 1) studio.fantasyit.maid_storage_manager.Logger → maid_storage_manager
            if ($fullPath -cmatch '\.([a-z][a-z0-9_\-]+)\.[A-Z]') {
                $modName = $matches[1]
            }
            # 2) maidsoulkitchen/MaidStorageManagerCompat → maidsoulkitchen
            #    maidsoulkitchen/VerifyExistence → maidsoulkitchen
            elseif ($fullPath -cmatch '^([a-z][a-z0-9_\-]+)/') {
                $modName = $matches[1]
            }
            # 3) 其他带大写字母的：xxxxx.ModName → 提取前面的小写部分
            elseif ($fullPath -cmatch '^([a-z][a-z0-9_\-]+)[/\.]?[A-Z]') {
                $modName = $matches[1]
            }
            # 3) 纯小写 Mod 名（如 Moonlight, Railways）
            elseif ($fullPath -match '^[a-zA-Z][a-zA-Z0-9_\-]+$') {
                $modName = $fullPath
            }
            
            # 排除 forge/minecraft
            if ($modName -and $modName -notmatch 'forge|minecraft' -and $modNames -notcontains $modName) {
                $modNames += $modName
            }
        }
    }
    
    # 返回第一个找到的 Mod 名称（优先级高的）
    if ($modNames.Count -gt 0) {
        return $modNames[0]
    }
    
    return $null
}

# ============================================
# 4. 应用错误规则检测错误
# ============================================
$lineNumber = 0
$processedModPairs = @()  # 记录已处理的依赖对，防止旧格式重复匹配
$lastErrorIndex = -1  # 记录最后一个检测到的ERROR在 $analysis.Errors 中的索引

foreach ($line in $logContent) {
    $lineNumber++
    
    # 特殊处理：检测到依赖问题报告时，继续读取缩进的详细行
    if ($line -match 'Missing or unsupported mandatory dependencies:') {
        # 匹配完整的依赖报告：Mod ID, Requested by, Expected range, Actual version
        $detailPattern = "Mod ID: '([^']+)',.*Requested by: '([^']+)',.*Expected range: '\[([^\]]+)\)',.*Actual version: '([^']+)'"
        
        # 先添加ERROR行本身到关键日志
        if ($line -match '/ERROR\]|/FATAL\]') {
            $analysis.KeyLines += $line.Trim()
        }
        
        # 查找或创建"Mod依赖版本不匹配"错误
        $depError = $analysis.Errors | Where-Object { $_.Type -eq 'Mod依赖版本不匹配' }
        if (-not $depError) {
            $depError = @{
                Type = 'Mod依赖版本不匹配'
                Severity = '严重'
                Content = ''
                Count = 0
                Details = @()
                ModNames = @()
                Priority = 2
                RuleId = 'mod_dependency_version_mismatch'
                CausedBy = @()
            }
            $analysis.Errors += $depError
        }
        
        # 向前查找接下来的缩进行
        for ($i = $lineNumber; $i -lt $logContent.Count; $i++) {
            $nextLine = $logContent[$i]
            
            # 如果是缩进行（以空格或制表符开头）
            if ($nextLine -match '^\s+Mod ID:') {
                # 尝试匹配依赖详情（完整版本信息）
                if ($nextLine -match $detailPattern) {
                    $dependency = $matches[1]
                    $requester = $matches[2]
                    $expectedRange = $matches[3]
                    $actualVersion = $matches[4]
                    
                    # 解析版本范围为自然语言
                    $versionDesc = ""
                    if ($expectedRange -match '^([^,]+),([^,]*)$') {
                        $minVer = $matches[1]
                        $maxVer = $matches[2]
                        
                        if ($maxVer -and $maxVer -ne '') {
                            # 有上限：1.9.0~1.10
                            $maxVer = $maxVer -replace '-$', ''  # 移除末尾的 -
                            $versionDesc = "版本 $minVer~$maxVer"
                        } else {
                            # 无上限：21.1.213+
                            $versionDesc = "版本 $minVer 或更高"
                        }
                    } else {
                        $versionDesc = "版本 $expectedRange"
                    }
                    
                    $detail = "$requester 需要 $dependency $versionDesc，但安装的是 $actualVersion"
                    $modPair = "$dependency|$requester"
                    
                    # 智能去重
                    $shouldAdd = $true
                    foreach ($existingDetail in $depError.Details) {
                        if ($existingDetail -match '(.+?)\s*需要\s*(.+?)(\s|$)') {
                            $existingRequester = $matches[1].Trim()
                            $existingDep = $matches[2].Trim() -replace '\s.*$', ''
                            $existingPair = "$existingDep|$existingRequester"
                            if ($existingPair -eq $modPair) {
                                $shouldAdd = $false
                                break
                            }
                        }
                    }
                    
                    if ($shouldAdd) {
                        $depError.Details += $detail
                        $depError.Count++
                        if ($requester -and $depError.ModNames -notcontains $requester) {
                            $depError.ModNames += $requester
                        }
                        # 记录已处理的依赖对，防止旧格式重复匹配
                        $processedModPairs += $modPair
                    }
                    
                    # 添加到关键日志（紧跟在ERROR行后面）
                    $analysis.KeyLines += $nextLine.Trim()
                }
            }
            # 如果不是缩进行或遇到新的日志条目，停止查找
            elseif ($nextLine -match '^\[' -or $nextLine -notmatch '^\s') {
                break
            }
        }
        
        # 跳过对此ERROR行的常规规则匹配（已特殊处理）
        continue
    }
    
    # 遇到新的日志行，清除 lastErrorIndex（防止将后续 WARN 的 Caused by 关联到之前的 ERROR）
    # 如果这行本身是 ERROR，会在后续规则匹配中重新设置
    if ($line -match '^\[') {
        $lastErrorIndex = -1
    }
    
    # 处理堆栈跟踪行（Caused by, at, 异常类型等）
    # 只有以 [ 开头的才是真正的日志条目
    if ($line -notmatch '^\[' -and $line.Trim()) {
        # 跳过 at 堆栈跟踪行（太多了）
        if ($line -match '^\s*at\s') {
            continue
        }
        
        # 只处理最近有 ERROR/FATAL 的情况
        if ($lastErrorIndex -ge 0 -and $lastErrorIndex -lt $analysis.Errors.Count) {
            # 收集异常详情到关键日志（包括 Caused by 和其他异常消息）
            $analysis.KeyLines += $line.Trim()
            
            # 注意：不要把异常详情行添加到 Details
            # Details 只用于存储 Mod 名称（如 Mod初始化失败、Mod加载失败）
            # 或特定的格式化信息（如 Mod依赖版本不匹配）
            
            # 如果是 Caused by 行，尝试匹配 causedBy 规则
            if ($line -match '^\s*Caused by:') {
                $lastError = $analysis.Errors[$lastErrorIndex]
                
                # 查找对应的规则
                $matchedRule = $allRules | Where-Object { $_.id -eq $lastError.RuleId } | Select-Object -First 1
                
                if ($matchedRule -and $matchedRule.causedBy) {
                    # 尝试匹配每个 causedBy 规则
                    foreach ($causedByRule in $matchedRule.causedBy) {
                        if ($line -match $causedByRule.pattern) {
                            # 匹配成功，添加原因信息
                            if (-not $lastError.CausedBy) {
                                $lastError | Add-Member -NotePropertyName 'CausedBy' -NotePropertyValue @() -Force
                            }
                            
                            # 检查是否已经添加过这个原因（去重）
                            $alreadyExists = $false
                            foreach ($existingCause in $lastError.CausedBy) {
                                if ($existingCause.Reason -eq $causedByRule.reason) {
                                    $alreadyExists = $true
                                    break
                                }
                            }
                            
                            if (-not $alreadyExists) {
                                $lastError.CausedBy += @{
                                    Reason = $causedByRule.reason
                                    Suggestion = $causedByRule.suggestion
                                    Content = $line.Trim()
                                }
                            }
                            
                            break
                        }
                    }
                }
            }
            
            # 尝试匹配规则，如果匹配到重要错误，作为新错误添加
            $matchedImportantRule = $false
            foreach ($rule in $allRules) {
                if ($line -match $rule.pattern) {
                    # 只处理高优先级错误（priority <= 20），避免误报
                    if ($rule.priority -le 20) {
                        # 添加为新错误
                        $existingError = $analysis.Errors | Where-Object { $_.Type -eq $rule.name }
                        if ($existingError) {
                            $existingError.Count++
                        } else {
                            $newError = @{
                                Type = $rule.name
                                Count = 1
                                Content = $line.Trim()
                                Severity = $rule.severity
                                Details = @()
                                ModNames = @()
                                Priority = $rule.priority
                                RuleId = $rule.id
                                CausedBy = @()
                            }
                            $analysis.Errors += $newError
                            $lastErrorIndex = $analysis.Errors.Count - 1
                        }
                        $matchedImportantRule = $true
                    }
                    break
                }
            }
            
            # 如果匹配到了重要错误，不要continue，让后续逻辑处理
            if (-not $matchedImportantRule) {
                continue
            }
        } else {
            continue
        }
    }
    
    foreach ($rule in $allRules) {
        if ($line -match $rule.pattern) {
            # 检查是否是依赖相关的规则，并且已被新格式处理过
            $skipDuplicateCheck = $false
            if ($rule.name -in @('Mod依赖版本不匹配', 'Mod版本不匹配', 'Mod依赖缺失') -and $matches.Count -gt 2) {
                # 提取 modPair 进行检查
                $checkModPair = $null
                if ($rule.name -eq 'Mod依赖版本不匹配' -and $matches.Count -gt 2) {
                    $checkModPair = "$($matches[1])|$($matches[2])"
                } elseif ($matches.Count -gt 2) {
                    $checkModPair = "$($matches[2])|$($matches[1])"
                }
                
                # 如果已被新格式处理过，跳过此规则
                if ($checkModPair -and $processedModPairs -contains $checkModPair) {
                    $skipDuplicateCheck = $true
                }
            }
            
            if ($skipDuplicateCheck) {
                # 跳过已被新格式处理过的依赖对
                continue
            }
            
            $existingError = $analysis.Errors | Where-Object { $_.Type -eq $rule.name }
            
            # 提取 Mod 名称
            # 对于特定规则，优先使用捕获组中的Mod ID
            if ($rule.id -eq 'mixin_conflict' -and $matches[1]) {
                $modName = $matches[1]
            } else {
                $modName = Extract-ModName -Line $line
            }
            
            if ($existingError) {
                $existingError.Count++
                
                # 更新最后一个 ERROR 的索引
                $lastErrorIndex = $analysis.Errors.IndexOf($existingError)
                
                # 添加 Mod 名称（去重，过滤空字符串）
                if ($modName -and $modName.Trim() -and $existingError.ModNames -notcontains $modName) {
                    if (-not $existingError.ModNames) {
                        $existingError | Add-Member -NotePropertyName 'ModNames' -NotePropertyValue @() -Force
                    }
                    $existingError.ModNames += $modName
                }
                
                if ($rule.collectDetails -and $matches[1]) {
                    # 组合多个捕获组形成详细信息
                    $detail = $null
                    $modPair = $null  # 用于智能去重：格式为 "依赖|请求者"
                    
                    # 判断规则类型，使用自然语言描述
                    if ($rule.id -eq 'mixin_conflict') {
                        # Mixin冲突：直接使用Mod ID
                        $detail = $matches[1].Trim()
                    }
                    elseif ($rule.name -eq 'Mod依赖版本不匹配' -and $matches.Count -gt 2) {
                        # 新格式：Mod ID (依赖) + Requested by (请求者)
                        # 捕获组1=依赖, 捕获组2=请求者
                        $detail = "$($matches[2]) 需要 $($matches[1])"
                        $modPair = "$($matches[1])|$($matches[2])"
                    }
                    elseif ($matches.Count -gt 3) {
                        # 旧格式：Mod名 需要 依赖 版本+
                        # 捕获组1=请求者, 捕获组2=依赖, 捕获组3=版本
                        $detail = "$($matches[1]) 需要 $($matches[2]) $($matches[3]) 或更高版本"
                        $modPair = "$($matches[2])|$($matches[1])"
                    }
                    elseif ($matches.Count -gt 2) {
                        # 旧格式：Mod名 需要 依赖
                        # 捕获组1=请求者, 捕获组2=依赖
                        $detail = "$($matches[1]) 需要 $($matches[2])"
                        $modPair = "$($matches[2])|$($matches[1])"
                    }
                    else {
                        $detail = $matches[1].Trim()
                    }
                    
                    # 智能去重：检查是否已存在相同的 Mod 对
                    if ($detail -and $detail.Trim()) {
                        $shouldAdd = $true
                        
                        if ($modPair) {
                            # 检查现有 Details 是否包含相同的 Mod 对
                            foreach ($existingDetail in $existingError.Details) {
                                if ($existingDetail -match '(.+?)\s*需要\s*(.+?)(\s|$)') {
                                    # 提取：请求者 需要 依赖
                                    $existingRequester = $matches[1].Trim()
                                    $existingDep = $matches[2].Trim() -replace '\s.*$', ''  # 移除版本号和其他描述
                                    $existingPair = "$existingDep|$existingRequester"
                                    if ($existingPair -eq $modPair) {
                                        $shouldAdd = $false
                                        break
                                    }
                                }
                            }
                        } elseif ($existingError.Details -contains $detail) {
                            $shouldAdd = $false
                        }
                        
                        if ($shouldAdd) {
                            $existingError.Details += $detail
                        }
                    }
                }
            }
            else {
                $newError = @{
                    Type = $rule.name
                    Severity = $rule.severity
                    Content = $line.Trim()
                    Count = 1
                    Details = @()
                    ModNames = @()
                    Priority = $rule.priority
                    RuleId = $rule.id
                    CausedBy = @()
                }
                
                # 添加 Mod 名称（过滤空字符串）
                if ($modName -and $modName.Trim()) {
                    $newError.ModNames += $modName
                }
                
                if ($rule.collectDetails -and $matches[1]) {
                    # 组合多个捕获组形成详细信息（自然语言描述）
                    $detail = $null
                    
                    if ($rule.id -eq 'mixin_conflict') {
                        # Mixin冲突：直接使用Mod ID
                        $detail = $matches[1].Trim()
                    }
                    elseif ($rule.name -eq 'Mod依赖版本不匹配' -and $matches.Count -gt 2) {
                        # 新格式：捕获组1=依赖, 捕获组2=请求者
                        $detail = "$($matches[2]) 需要 $($matches[1])"
                    }
                    elseif ($matches.Count -gt 3) {
                        # 旧格式：Mod名 需要 依赖 版本+
                        $detail = "$($matches[1]) 需要 $($matches[2]) $($matches[3]) 或更高版本"
                    }
                    elseif ($matches.Count -gt 2) {
                        # 旧格式：Mod名 需要 依赖
                        $detail = "$($matches[1]) 需要 $($matches[2])"
                    }
                    else {
                        $detail = $matches[1].Trim()
                    }
                    
                    # 过滤空字符串
                    if ($detail -and $detail.Trim()) {
                        $newError.Details += $detail
                    }
                }
                
                $analysis.Errors += $newError
                
                # 更新最后一个 ERROR 的索引（用于 Caused by 关联）
                $lastErrorIndex = $analysis.Errors.Count - 1
            }
            
            # 收集关键日志（包含ERROR/FATAL级别）
            if ($line -match '/ERROR\]|/FATAL\]') {
                $analysis.KeyLines += $line.Trim()
            }
            
            break
        }
    }
}

# ============================================
# 4. 补充崩溃报告中的系统信息
# ============================================

# 如果日志中没有找到崩溃报告路径，尝试自动查找最新的崩溃报告
if (-not $analysis.CrashReportPath) {
    try {
        $logDir = Split-Path $LogPath -Parent
        
        # 方案3：在日志同目录下查找（PCL打包格式）
        $sameDirCrash = Get-ChildItem -Path $logDir -Filter "crash-*.txt" -File -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1
        
        if ($sameDirCrash) {
            $analysis.CrashReportPath = $sameDirCrash.FullName
            Write-Host "    在日志同目录找到崩溃报告：$($sameDirCrash.Name)" -ForegroundColor Yellow
        }
        # 方案4：在标准crash-reports目录下查找
        else {
            $versionDir = Split-Path $logDir -Parent
            $crashReportsDir = Join-Path $versionDir "crash-reports"
            
            if (Test-Path $crashReportsDir) {
                # 查找最新的崩溃报告文件
                $latestCrash = Get-ChildItem -Path $crashReportsDir -Filter "crash-*.txt" -File |
                               Sort-Object LastWriteTime -Descending |
                               Select-Object -First 1
                
                if ($latestCrash) {
                    $analysis.CrashReportPath = $latestCrash.FullName
                    Write-Host "    自动找到最新崩溃报告：$($latestCrash.Name)" -ForegroundColor Yellow
                }
            }
        }
    }
    catch {
        # 静默失败，不影响主流程
    }
}

# 读取并补充崩溃报告中的系统信息（优先级最高）
if ($analysis.CrashReportPath -and (Test-Path $analysis.CrashReportPath)) {
    try {
        # 获取崩溃报告文件名用于显示
        $crashFileName = Split-Path $analysis.CrashReportPath -Leaf
        Write-Host "  + 发现崩溃报告：$crashFileName" -ForegroundColor Cyan
        Write-Host "    正在从崩溃报告提取系统信息..." -ForegroundColor Cyan
        
        $crashContent = Get-Content $analysis.CrashReportPath -Encoding UTF8 -ErrorAction SilentlyContinue
        if (-not $crashContent) {
            $crashContent = Get-Content $analysis.CrashReportPath -Encoding Default
        }
        
        # 重置需要从崩溃报告优先提取的字段
        $crashGPU = "Unknown"
        $crashOpenGL = "Unknown"
        $crashCPU = "Unknown"
        
        $inSystemDetails = $false
        $cpuCoreCount = 0  # 临时存储核心数
        
        foreach ($line in $crashContent) {
            # 标记进入 System Details 区域
            if ($line -match '-- System Details --') {
                $inSystemDetails = $true
                continue
            }
            
            # 只在 System Details 区域内提取信息
            if ($inSystemDetails) {
                # CPU 核心数（可能在Processor Name之前，先收集）
                if ($line -match '^\s*CPUs:\s*(\d+)\s*$') {
                    $cpuCoreCount = [int]$matches[1]
                }
                
                # CPU 详细信息（优先级最高）
                if ($line -match 'Processor Name:\s*(.+?)\s*$') {
                    # 去除多余空格（如：AMD Ryzen 7 6800H with Radeon Graphics         ）
                    $cpuName = $matches[1].Trim() -replace '\s+', ' '
                    
                    # 如果已收集到核心数，直接组合
                    if ($cpuCoreCount -gt 0) {
                        $crashCPU = "$cpuCoreCount x $cpuName"
                    } else {
                        $crashCPU = $cpuName
                    }
                }
                elseif ($line -match 'CPU:\s*(.+?)\s*$' -and $crashCPU -eq "Unknown") {
                    $cpuName = $matches[1].Trim() -replace '\s+', ' '
                    if ($cpuCoreCount -gt 0) {
                        $crashCPU = "$cpuCoreCount x $cpuName"
                    } else {
                        $crashCPU = $cpuName
                    }
                }
                
                # Graphics card 列表中提取（优先选择独显）
                if ($line -match 'Graphics card #\d+ name:\s*(.+?)\s*$') {
                    $gpuName = $matches[1].Trim()
                    
                    # 过滤虚拟显卡（如：OrayIddDriver Device）
                    if ($gpuName -notmatch 'IddDriver|Virtual|Microsoft Basic') {
                        # 判断显卡优先级
                        $isDiscrete = $gpuName -match 'GeForce|RTX|GTX|Radeon RX|Arc A\d+|Quadro|Tesla'
                        $currentIsDiscrete = $crashGPU -match 'GeForce|RTX|GTX|Radeon RX|Arc A\d+|Quadro|Tesla'
                        
                        # 更新条件：
                        # 1. 当前为Unknown
                        # 2. 新显卡是独显，但当前不是独显
                        # 3. 都是独显，优先NVIDIA
                        if ($crashGPU -eq "Unknown") {
                            $crashGPU = $gpuName
                        }
                        elseif ($isDiscrete -and -not $currentIsDiscrete) {
                            # 新显卡是独显，当前是集显 → 更新
                            $crashGPU = $gpuName
                        }
                        elseif ($isDiscrete -and $currentIsDiscrete) {
                            # 都是独显，优先选择NVIDIA
                            if ($gpuName -match 'NVIDIA|GeForce|RTX|GTX' -and $crashGPU -notmatch 'NVIDIA|GeForce|RTX|GTX') {
                                $crashGPU = $gpuName
                            }
                        }
                    }
                }
                # GL_RENDERER提取（兜底）
                elseif ($line -match 'GL_RENDERER:\s*(.+?)(?:\s*\(Supports|\s*/|$)' -and $crashGPU -eq "Unknown") {
                    # 只提取GPU名称，去掉 /PCIe/SSE2 和 (Supports OpenGL...) 部分
                    $crashGPU = $matches[1].Trim()
                }
                
                # Backend API 同时包含GPU和OpenGL信息（最高优先级，覆盖之前的选择）
                # 格式1: Backend API: AMD Radeon(TM) Graphics/PCIe/SSE2 GL version 4.6.0 Core Profile Context 25.3.2.250311, Advanced Micro Devices, Inc.
                if ($line -match 'Backend API:\s*(.+?)(?:/(?:PCIe|SSE2))+\s*GL version\s+(.+?)(?:,|$)') {
                    $gpuName = $matches[1].Trim()
                    $glVersion = $matches[2].Trim()
                    
                    # 覆盖GPU名称（不包含OpenGL信息，避免重复）
                    $crashGPU = $gpuName
                    
                    # 覆盖OpenGL版本
                    $crashOpenGL = $glVersion
                }
                # 格式2: Backend API: NVIDIA GeForce RTX 3050 Laptop GPU/PCIe/SSE2 (Supports OpenGL 3.2.0 NVIDIA 565.90)
                elseif ($line -match 'Backend API:\s*(.+?)(?:/(?:PCIe|SSE2))+\s*\(Supports OpenGL\s+(.+?)\)') {
                    $gpuName = $matches[1].Trim()
                    $glVersion = $matches[2].Trim()
                    
                    # 覆盖GPU名称
                    $crashGPU = $gpuName
                    
                    # 覆盖OpenGL版本
                    $crashOpenGL = $glVersion
                }
                # OpenGL 版本（独立提取，如果Backend API没有提取到）
                elseif ($line -match 'GL_VERSION:\s*(.+?)\s*$' -and $crashOpenGL -eq "Unknown") {
                    $crashOpenGL = $matches[1].Trim()
                }
                
                # 内存详细信息（提取-Xmx最大内存并转换为GB显示）
                if ($line -match 'JVM Flags:.*-Xmx(\d+)([MGmg])\b') {
                    $memSize = [int]$matches[1]
                    $memUnit = $matches[2].ToUpper()
                    
                    # 转换为GB和MB显示
                    if ($memUnit -eq 'G') {
                        $memMB = $memSize * 1024
                        $memGB = $memSize
                    } else {
                        # 单位是M
                        $memMB = $memSize
                        $memGB = [math]::Round($memMB / 1024, 1)
                    }
                    
                    $analysis.Memory = "$memGB GB ($memMB MB)"
                }
                
                # Java 详细版本
                if ($line -match 'Java Version:\s*(.+?),\s*(.+?)\s*$') {
                    $javaVer = $matches[1].Trim()
                    $javaVendor = $matches[2].Trim()
                    if ($analysis.JavaVersion -eq "Unknown") {
                        $analysis.JavaVersion = $javaVer
                    }
                    if ($analysis.JvmVendor -eq "Unknown") {
                        $analysis.JvmVendor = $javaVendor
                    }
                }
                
                # 操作系统
                if ($line -match 'Operating System:\s*(.+?)\s*\(') {
                    $analysis.OS = $matches[1].Trim()
                }
                
                # Mod 数量（Forge/NeoForge 格式）
                if ($line -match 'Mod List:\s*(\d+)\s*mods loaded') {
                    $modCount = [int]$matches[1]
                    if ($modCount -gt $analysis.ModCount) {
                        $analysis.ModCount = $modCount
                    }
                }
                
                # Fabric 版本信息
                if ($line -match 'Fabric (?:Loader )?Version:\s*(.+?)\s*$') {
                    $fabricVer = $matches[1].Trim()
                    if ($analysis.ModLoader -eq "Unknown") {
                        $analysis.ModLoader = "Fabric $fabricVer"
                    }
                }
                
                # Fabric API 版本
                if ($line -match 'Fabric API(?:\s+Version)?:\s*(.+?)\s*$') {
                    # Fabric API 版本信息（可选补充）
                }
                
                # Fabric Mods 数量（备选格式）
                if ($line -match 'Fabric Mods:\s*(\d+)') {
                    $modCount = [int]$matches[1]
                    if ($modCount -gt $analysis.ModCount) {
                        $analysis.ModCount = $modCount
                    }
                }
            }
        }
        
        # 崩溃报告信息优先，覆盖主日志的信息
        if ($crashCPU -ne "Unknown") {
            $analysis.CPU = $crashCPU
        }
        if ($crashGPU -ne "Unknown") {
            $analysis.GPU = $crashGPU
        }
        if ($crashOpenGL -ne "Unknown") {
            $analysis.GLVersion = $crashOpenGL
        }
        
        Write-Host "  ✓ 系统信息已从崩溃报告提取" -ForegroundColor Green
    }
    catch {
        Write-Host "  ⚠ 读取崩溃报告时出错：$($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ============================================
# 5. 返回解析结果
# ============================================
return $analysis

