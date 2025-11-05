# ============================================
# PCL Log Analyzer - 错误识别规则配置
# ============================================

# ============================================
# 错误类型定义
# ============================================
# Pattern: 正则表达式匹配模式
# Type: 错误类型名称
# Severity: 严重程度（严重/中等/轻微）
# Priority: 优先级（数字越小越优先）
# CollectDetails: 是否收集详情（$true/$false，默认$false）
#
# 注意：
# - 具体错误类型（如"内存溢出"）：同类型只记录1次
# - 通用错误类型（如"一般错误"）：按内容去重，不同错误都会记录
# - CollectDetails=$true 的类型会在前端显示详细信息
# ============================================
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    chcp 65001 | Out-Null
} catch {}

$ErrorActionPreference = "Continue"

function Get-ErrorTypes {
    return @(
        # ===== 根本原因（最高优先级，优先解决） =====
        @{ Pattern = '/WARN\].*Found \d+ non-fabric mods'; Type = 'Fabric环境安装了Forge Mod'; Severity = '严重'; Priority = 1; CollectDetails = $true },
        @{ Pattern = '/WARN\].*Found \d+ non-forge mods'; Type = 'Forge环境安装了Fabric Mod'; Severity = '严重'; Priority = 1; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*Incompatible mods found'; Type = 'Mod与MC版本不兼容'; Severity = '严重'; Priority = 2; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*Missing.*dependencies|/ERROR\].*unsupported mandatory'; Type = 'Mod依赖缺失'; Severity = '严重'; Priority = 3; CollectDetails = $true },
        @{ Pattern = '/FATAL\].*requires .+ or above|/ERROR\].*requires .+ or above'; Type = 'Mod版本不匹配'; Severity = '严重'; Priority = 4; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*ModResolutionException'; Type = 'Mod依赖问题'; Severity = '严重'; Priority = 5 },
        @{ Pattern = '/ERROR\].*Failed to parse.*(config|json|data)|/ERROR\].*(Not a string|Not a json array)|MalformedJsonException'; Type = '配置文件格式错误'; Severity = '中等'; Priority = 6 },
        
        # ===== 直接错误（导致崩溃的具体问题） =====
        @{ Pattern = '/FATAL\].*Error during.*loading|/ERROR\].*Failed to create mod instance'; Type = 'Mod加载失败'; Severity = '严重'; Priority = 10; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*(Caught exception during event FMLClientSetupEvent|Exception caught during firing event)'; Type = 'Mod初始化失败'; Severity = '严重'; Priority = 11; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*ClassCastException|Caused by.*ClassCastException'; Type = 'Mod兼容性问题'; Severity = '严重'; Priority = 12 },
        @{ Pattern = '/ERROR\].*MixinApplyError|/ERROR\].*Mixin.*failed'; Type = 'Mixin冲突'; Severity = '严重'; Priority = 13 },
        @{ Pattern = '/ERROR\].*(Unbound values in registry|Registry loading errors)'; Type = 'Mod注册冲突'; Severity = '严重'; Priority = 14 },
        @{ Pattern = '/ERROR\].*ClassNotFoundException|/FATAL\].*ClassNotFoundException'; Type = '缺少类文件'; Severity = '严重'; Priority = 15 },
        @{ Pattern = '/ERROR\].*OutOfMemoryError|/FATAL\].*OutOfMemoryError'; Type = '内存溢出'; Severity = '严重'; Priority = 16 },
        
        # ===== 崩溃相关 =====
        @{ Pattern = 'Manually triggered debug crash'; Type = '手动调试崩溃'; Severity = '轻微'; Priority = 19 },
        @{ Pattern = '/FATAL\].*Preparing crash report'; Type = '游戏崩溃'; Severity = '严重'; Priority = 20 },
        @{ Pattern = '/FATAL\]'; Type = '致命错误'; Severity = '严重'; Priority = 21; CollectDetails = $true },
        
        # ===== 连带错误（解决前面的问题后会自动消失） =====
        @{ Pattern = '/ERROR\].*Cowardly refusing to send event.*to a broken mod state'; Type = 'Mod状态异常'; Severity = '严重'; Priority = 30; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*Skipping.*due to previous error'; Type = 'Mod跳过加载'; Severity = '严重'; Priority = 31; CollectDetails = $true },
        
        # ===== 次要问题（通常不影响游戏运行） =====
        @{ Pattern = '/ERROR\].*Failed to verify authentication|Status: 401'; Type = '身份验证失败'; Severity = '中等'; Priority = 36 },
        @{ Pattern = '/ERROR\].*Unreported exception thrown'; Type = '未报告异常'; Severity = '中等'; Priority = 37 },
        @{ Pattern = 'PKIX path building failed|unable to find valid certification path'; Type = '证书验证失败'; Severity = '轻微'; Priority = 38 },
        @{ Pattern = '/ERROR\].*Failed to load model|/ERROR\].*ModelManager'; Type = '模型加载失败'; Severity = '中等'; Priority = 40; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*Invalid path in pack'; Type = '资源路径错误'; Severity = '中等'; Priority = 41; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*was null.*due to some mod not registering'; Type = '资源注册缺失'; Severity = '中等'; Priority = 42; CollectDetails = $true },
        @{ Pattern = '/ERROR\].*Unable to parse animation'; Type = '动画解析失败'; Severity = '轻微'; Priority = 43 },
        @{ Pattern = '/ERROR\].*Failed to load.*information'; Type = '网络资源加载失败'; Severity = '轻微'; Priority = 44 },
        @{ Pattern = '/ERROR\].*Failed to retrieve profile key pair'; Type = '密钥对获取失败'; Severity = '轻微'; Priority = 45 },
        @{ Pattern = '/ERROR\].*Mod mixin into Embeddium'; Type = 'Embeddium兼容性警告'; Severity = '轻微'; Priority = 46 },
        @{ Pattern = '/ERROR\].*Access transformer file.*does not exist'; Type = 'AT文件缺失'; Severity = '轻微'; Priority = 47 },
        
        # ===== 通用兜底 =====
        @{ Pattern = '/ERROR\]'; Type = '一般错误'; Severity = '中等'; Priority = 50; CollectDetails = $true }
    )
}

# ============================================
# 解决建议生成
# ============================================
# 根据错误类型返回对应的解决建议
# 返回格式: @{ Title = '标识'; Text = '建议内容' }
# ============================================

function Get-ErrorSuggestion {
    param(
        [string]$ErrorType
    )
    
    switch ($ErrorType) {
        'Fabric环境安装了Forge Mod' { 
            return @{ Title = 'Loader1'; Text = 'Mod加载器不匹配：当前是Fabric环境，但安装了Forge/NeoForge版本的Mod。解决方法：①查看报告中列出的Mod名称 ②重新下载这些Mod的Fabric版本（通常在Modrinth或CurseForge可以找到）③或移除这些Mod' }
        }
        'Forge环境安装了Fabric Mod' { 
            return @{ Title = 'Loader2'; Text = 'Mod加载器不匹配：当前是Forge/NeoForge环境，但安装了Fabric版本的Mod。解决方法：①查看报告中列出的Mod名称 ②重新下载这些Mod的Forge/NeoForge版本 ③或移除这些Mod' }
        }
        'Mod与MC版本不兼容' { 
            return @{ Title = 'Incom'; Text = 'Mod版本不匹配：某些Mod需要的MC版本与当前版本不符。解决方法：①查看报告中提示的Mod名称 ②重新下载对应当前MC版本的Mod' }
        }
        '内存溢出' { 
            return @{ Title = 'Mem'; Text = '增加内存：在PCL设置中将JVM内存调整到4-8GB' }
        }
        'Mod兼容性问题' { 
            return @{ Title = 'Compat'; Text = 'Mod不兼容（ClassCastException）：查看"关键日志"中的详细错误，找出涉及的Mod名称（常见：Create系列、Ponder、OptiFine等），确保所有相关Mod版本匹配当前MC和Forge版本，或尝试移除导致冲突的Mod' }
        }
        'Mod初始化失败' { 
            return @{ Title = 'Init'; Text = 'Mod启动失败：在"发现的问题"中查看具体是哪些Mod初始化失败（如sliceanddice、copycats、create等），通常是这些Mod版本不匹配或缺少依赖。建议：①检查所有相关Mod是否为同一版本系列 ②更新到最新版本 ③逐个移除测试找出问题Mod' }
        }
        'Embeddium兼容性警告' { 
            return @{ Title = 'Emb'; Text = 'Embeddium警告：有Mod修改了Embeddium内部代码，可能导致不稳定。这通常只是警告，如果游戏正常运行可以忽略' }
        }
        'Mod依赖缺失' { 
            return @{ Title = 'Dep1'; Text = '安装前置Mod：检查错误信息中缺少的Mod，从PCL2或CurseForge或Modrinth下载对应版本' }
        }
        'Mod版本不匹配' { 
            return @{ Title = 'Ver'; Text = '更新Mod版本：查看错误中提到的版本要求，下载符合要求的Mod版本' }
        }
        'Mod加载失败' { 
            return @{ Title = 'Load'; Text = 'Mod加载失败：某个Mod无法创建实例，通常是Mod损坏或配置文件错误。删除或重新下载失败的Mod，或检查其配置文件' }
        }
        '缺少类文件' { 
            return @{ Title = 'Cls'; Text = '安装依赖库：某些Mod需要额外的依赖库，检查Mod页面的前置要求' }
        }
        'Mixin冲突' { 
            return @{ Title = 'Mix'; Text = '解决冲突：移除或更新冲突的Mod，某些Mod不能同时使用（如OptiFine和Sodium）' }
        }
        'Mod依赖问题' { 
            return @{ Title = 'Dep2'; Text = 'Mod依赖：检查Mod的前置要求，确保所有依赖都已安装' }
        }
        'Mod注册冲突' { 
            return @{ Title = 'Reg'; Text = 'Mod冲突：多个Mod修改了相同的游戏内容（如生物群系、方块），移除或更新冲突的Mod' }
        }
        'Mod状态异常' { 
            return @{ Title = 'State'; Text = 'Mod崩溃后遗症：由于前面的错误导致Mod处于损坏状态，Forge拒绝发送事件。这是连带错误，解决根本原因（如依赖缺失、版本不匹配）后即可修复' }
        }
        'Mod跳过加载' { 
            return @{ Title = 'Skip'; Text = 'Mod跳过加载：由于前面的错误，某些Mod被跳过加载。解决前面显示的错误即可' }
        }
        '模型加载失败' { 
            return @{ Title = 'Model'; Text = '模型文件缺失：可以忽略，不影响游戏运行（如果游戏内某些物品显示异常，可尝试重新下载对应Mod）' }
        }
        '资源路径错误' { 
            return @{ Title = 'Path'; Text = '文件名非法字符：可以忽略，不影响游戏运行' }
        }
        '资源注册缺失' { 
            return @{ Title = 'Res'; Text = '资源未注册：可以忽略，通常不影响游戏运行' }
        }
        '动画解析失败' { 
            return @{ Title = 'Anim'; Text = '动画问题：GeckoLib动画文件错误，通常不影响游戏，可以忽略' }
        }
        '配置文件格式错误' { 
            return @{ Title = 'Cfg'; Text = '配置问题：数据包或Mod配置文件格式错误，删除有问题的数据包或重置Mod配置文件' }
        }
        '身份验证失败' { 
            return @{ Title = 'Auth'; Text = '登录验证问题：Microsoft账号验证失败（401错误），在PCL设置中重新登录账号，或检查网络连接' }
        }
        '密钥对获取失败' { 
            return @{ Title = 'Key'; Text = '密钥获取失败：无法获取账号密钥对，通常不影响游戏，可以忽略。如影响联机，请检查网络或重新登录' }
        }
        '未报告异常' { 
            return @{ Title = 'Exc'; Text = '未捕获异常：游戏内部发生未处理的错误，请查看关键日志中的详细堆栈信息定位问题' }
        }
        '证书验证失败' { 
            return @{ Title = 'Cert'; Text = 'SSL证书问题：某些Mod尝试连接网络但证书验证失败，通常不影响游戏，可以忽略' }
        }
        '网络资源加载失败' { 
            return @{ Title = 'Net'; Text = '网络问题：无法加载在线资源（如Patreon信息），不影响游戏，可以忽略' }
        }
        'Embeddium兼容性警告' { 
            return @{ Title = 'Emb'; Text = 'Embeddium注入：某些Mod修改了Embeddium内部代码，可能导致渲染问题，通常可以忽略' }
        }
        'AT文件缺失' { 
            return @{ Title = 'AT'; Text = 'Access Transformer文件缺失：Mod引用了不存在的AT文件，通常不影响游戏，可以忽略' }
        }
        '手动调试崩溃' { 
            return @{ Title = 'Debug'; Text = '这是你手动触发的调试崩溃（按F3+C）：不是真正的错误，用于测试或生成崩溃报告。如果不是你主动操作，可能是误触了F3+C组合键' }
        }
        '游戏崩溃' { 
            return @{ Title = 'Crash'; Text = '游戏崩溃：查看崩溃报告，根据具体错误排查问题' }
        }
        '致命错误' { 
            return @{ Title = 'Fat'; Text = '致命错误汇总：这是错误汇总提示，真正的问题请查看上方的具体错误类型（如Mod加载失败、依赖缺失等）' }
        }
        '一般错误' { 
            return @{ Title = 'Gen'; Text = '未分类错误：检测到多条未被识别的错误，请在关键日志中查看详细信息。如发现重复问题可反馈至GitHub' }
        }
        default {
            return $null
        }
    }
}

# ============================================
# 扩展规则示例（可以继续添加）
# ============================================
# 
# 添加新的错误类型：
# 1. 在 Get-ErrorTypes 函数中添加新的匹配规则（包含 Pattern, Type, Severity, Priority）
# 2. 在 Get-ErrorSuggestion 函数中添加对应的建议
#
# 优先级分配指南：
#   1-9: 根本原因（依赖缺失、版本不匹配、配置错误等）
#  10-19: 直接错误（Mod加载/初始化失败、兼容性问题等）
#  20-29: 崩溃相关（游戏崩溃、致命错误）
#  30-39: 连带错误（由前面错误引起，解决根因后自动消失）
#  40-49: 次要问题（通常不影响游戏运行）
#  50+: 通用/未分类错误
#
# 示例：
# @{ Pattern = '/ERROR\].*ConnectionException'; Type = '网络连接失败'; Severity = '中等'; Priority = 44 }
# '网络连接失败' { return @{ Title = 'Net'; Text = '检查网络连接：确保网络稳定，必要时配置代理' } }
#
# ============================================

