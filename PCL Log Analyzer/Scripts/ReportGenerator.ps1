# ============================================
# PCL Log Analyzer - 报告生成模块
# ============================================

param(
    [hashtable]$Analysis,
    [string]$LogFileName,
    [string]$TemplateDir,
    [string]$OutputPath,
    [string]$ScriptRoot = $PSScriptRoot
)

# 加载错误规则（从JSON）
$rulesPath = Join-Path (Split-Path $ScriptRoot -Parent) "Rules\Rules.json"
$rulesJson = Get-Content $rulesPath -Raw -Encoding UTF8 | ConvertFrom-Json
$allRules = $rulesJson.errors

# ============================================
# 1. 排序错误并生成建议
# ============================================
$sortedErrors = $Analysis.Errors | Sort-Object { 
    if ($null -eq $_.Priority) { 100 } else { $_.Priority }
}

$displayErrorCount = $sortedErrors.Count

$suggestions = @()
foreach ($err in $sortedErrors) {
    # 从 JSON 规则中获取主建议
    $matchedRule = $allRules | Where-Object { $_.id -eq $err.RuleId } | Select-Object -First 1
    
    if ($matchedRule -and $matchedRule.suggestion) {
        # 检查是否已存在此错误类型的建议
        $existingSuggestion = $suggestions | Where-Object {$_.Title -eq $err.Type} | Select-Object -First 1
        
        if ($existingSuggestion) {
            # 如果已存在，只添加新的原因建议（如果有）
            if ($err.CausedBy -and $err.CausedBy.Count -gt 0) {
                foreach ($cause in $err.CausedBy) {
                    if ($cause.Suggestion) {
                        # 检查是否已有此原因
                        $hasThisCause = $false
                        foreach ($existingCause in $existingSuggestion.CausedBySuggestions) {
                            if ($existingCause.Reason -eq $cause.Reason) {
                                $hasThisCause = $true
                                break
                            }
                        }
                        
                        if (-not $hasThisCause) {
                            $existingSuggestion.CausedBySuggestions += @{
                                Reason = $cause.Reason
                                Text = $cause.Suggestion
                            }
                        }
                    }
                }
            }
        } else {
            # 创建新的建议对象
            $mainSuggestion = @{
                Title = $err.Type
                Text = $matchedRule.suggestion
                ErrorType = $err.Type
                Severity = $err.Severity
                Priority = $err.Priority
                CausedBySuggestions = @()
            }
            
            # 添加原因建议（如果有）
            if ($err.CausedBy -and $err.CausedBy.Count -gt 0) {
                foreach ($cause in $err.CausedBy) {
                    if ($cause.Suggestion) {
                        $mainSuggestion.CausedBySuggestions += @{
                            Reason = $cause.Reason
                            Text = $cause.Suggestion
                        }
                    }
                }
            }
            
            $suggestions += $mainSuggestion
        }
    }
}

# ============================================
# 2. 生成基本信息HTML
# ============================================
$basicInfoHtml = @"
<div class='info-grid-3'>
<div class='info-item'><div class='info-label'>游戏版本</div><div class='info-value'>$($Analysis.GameVersion)</div></div>
<div class='info-item'><div class='info-label'>Mod加载器</div><div class='info-value'>$($Analysis.ModLoader)</div></div>
<div class='info-item'><div class='info-label'>Java版本</div><div class='info-value'>$($Analysis.JavaVersion)</div></div>
$(if ($Analysis.Memory -ne "Unknown") { "<div class='info-item'><div class='info-label'>内存分配</div><div class='info-value'>$($Analysis.Memory)</div></div>" })
$(if ($Analysis.ModCount -gt 0) { "<div class='info-item'><div class='info-label'>Mod数量</div><div class='info-value'>$($Analysis.ModCount)</div></div>" })
$(if ($Analysis.Username -ne "Unknown") { "<div class='info-item'><div class='info-label'>用户名</div><div class='info-value'>$($Analysis.Username)</div></div>" })
$(if ($Analysis.Resolution -ne "Unknown") { "<div class='info-item'><div class='info-label'>分辨率</div><div class='info-value'>$($Analysis.Resolution)</div></div>" })
    </div>
<div class='info-grid-2'>
$(if ($Analysis.JvmVendor -ne "Unknown") { "<div class='info-item'><div class='info-label'>JVM厂商</div><div class='info-value'>$($Analysis.JvmVendor)</div></div>" })
$(if ($Analysis.CPU -ne "Unknown") { "<div class='info-item'><div class='info-label'>CPU</div><div class='info-value'>$($Analysis.CPU)</div></div>" })
$(if ($Analysis.GPU -ne "Unknown") { "<div class='info-item'><div class='info-label'>GPU</div><div class='info-value'>$($Analysis.GPU)</div></div>" })
$(if ($Analysis.GLVersion -ne "Unknown") { "<div class='info-item'><div class='info-label'>OpenGL</div><div class='info-value'>$($Analysis.GLVersion)</div></div>" })
$(if ($Analysis.OS -ne "Unknown") { "<div class='info-item'><div class='info-label'>操作系统</div><div class='info-value'>$($Analysis.OS)</div></div>" })
$(if ($Analysis.CrashReport) { "<div class='info-item' style='grid-column:1/-1;border-left-color:#ff6b6b'><div class='info-label'>崩溃报告</div><div class='info-value' style='color:#ff6b6b'>$($Analysis.CrashReport)</div></div>" })
</div>
"@

# ============================================
# 3. 序列化错误为JSON
# ============================================
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
        ModNames = $_.ModNames
        CausedBy = $_.CausedBy
        Priority = $_.Priority
        # 只要Details数组不为空，就显示详情
        IsCollectDetails = ($_.Details.Count -gt 0)
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

# ============================================
# 4. 生成建议HTML（分类：重要 vs 次要）
# 使用错误的 Severity 和 Priority 动态判断
# ============================================
$majorSuggestions = @()
$minorSuggestionsList = @()

foreach ($sug in $suggestions) {
    # 严重 + Priority < 30 = 重要建议
    if ($sug.Severity -eq '严重' -and ($null -eq $sug.Priority -or $sug.Priority -lt 30)) {
        $majorSuggestions += $sug
    } else {
        $minorSuggestionsList += $sug
    }
}

$sugHtml = ""
if ($suggestions.Count -eq 0) {
    $sugHtml = "<div class='empty-state'>暂无建议</div>"
} else {
    # 重点建议
    if ($majorSuggestions.Count -gt 0) {
        $sugHtml += "<div style='margin-bottom:12px;padding:8px;background:#fff3cd;border-left:3px solid #ffc107;border-radius:4px;font-size:13px;color:#856404'>"
        $sugHtml += "<strong>🔍 重点建议</strong>：以下 $($majorSuggestions.Count) 条建议针对根本原因"
        $sugHtml += "</div>"
        
        $i = 1
        foreach ($sug in $majorSuggestions) {
            $sugHtml += "<div class='sug-box'>"
            $sugHtml += "<div style='margin-bottom:4px'><strong>$i. $($sug.Title)</strong></div>"
            $sugHtml += "<div style='color:#333'>$($sug.Text)</div>"
            
            # 显示原因建议（如果有）
            if ($sug.CausedBySuggestions -and $sug.CausedBySuggestions.Count -gt 0) {
                $sugHtml += "<div style='margin-top:10px;padding-left:16px;border-left:3px solid #FF9800'>"
                foreach ($cause in $sug.CausedBySuggestions) {
                    $sugHtml += "<div style='margin-top:6px'>"
                    $sugHtml += "<div style='color:#F57C00;font-weight:bold'>原因：$($cause.Reason)</div>"
                    $sugHtml += "<div style='color:#666;margin-top:2px'>$($cause.Text)</div>"
                    $sugHtml += "</div>"
                }
                $sugHtml += "</div>"
            }
            
            $sugHtml += "</div>"
            $i++
        }
    }
    
    # 次要建议（可折叠）
    if ($minorSuggestionsList.Count -gt 0) {
        $sugHtml += "<div style='margin-top:16px;margin-bottom:8px;padding:8px;background:#e7f3ff;border-left:3px solid:#2196f3;border-radius:4px;font-size:12px;color:#0d47a1;cursor:pointer' onclick='toggleMinorSuggestions()'>"
        $sugHtml += "<span id='minor-sug-toggle'>▼</span> <strong>次要建议（$($minorSuggestionsList.Count)条）</strong>：通常是连带问题，点击查看"
        $sugHtml += "</div>"
        $sugHtml += "<div id='minor-suggestions' style='display:none'>"
        
        $i = 1
        foreach ($sug in $minorSuggestionsList) {
            $sugHtml += "<div class='sug-box'>"
            $sugHtml += "<div style='margin-bottom:4px'><strong>$i. $($sug.Title)</strong></div>"
            $sugHtml += "<div style='color:#333'>$($sug.Text)</div>"
            
            # 显示原因建议（如果有）
            if ($sug.CausedBySuggestions -and $sug.CausedBySuggestions.Count -gt 0) {
                $sugHtml += "<div style='margin-top:10px;padding-left:16px;border-left:3px solid #FF9800'>"
                foreach ($cause in $sug.CausedBySuggestions) {
                    $sugHtml += "<div style='margin-top:6px'>"
                    $sugHtml += "<div style='color:#F57C00;font-weight:bold'>原因：$($cause.Reason)</div>"
                    $sugHtml += "<div style='color:#666;margin-top:2px'>$($cause.Text)</div>"
                    $sugHtml += "</div>"
                }
                $sugHtml += "</div>"
            }
            
            $sugHtml += "</div>"
            $i++
        }
        $sugHtml += "</div>"
    }
}

# ============================================
# 5. 生成日志HTML
# ============================================
$logHtml = ""
foreach ($line in $Analysis.KeyLines) {
    $cleanLine = $line -replace '[^\x20-\x7E\u4e00-\u9fff\[\]\(\)\{\}\-\+\=\.\,\:\;\/\\]', '?'
    $logHtml += "<div class='log-line'>$cleanLine</div>"
}
if ($Analysis.KeyLines.Count -eq 0) {
    $logHtml = "<div class='empty-state'>无关键日志</div>"
}

# ============================================
# 6. 确定状态
# ============================================
$hasSevereError = $Analysis.Errors | Where-Object { $_.Severity -eq '严重' }
$isCritical = $Analysis.IsCrashed -or $hasSevereError.Count -gt 0

$statusColor = if ($isCritical) { '#ff6b6b' } elseif ($Analysis.Errors.Count -gt 0) { '#ffd93d' } else { '#6bcf7f' }
$statusText = if ($isCritical) { '游戏崩溃' } elseif ($Analysis.Errors.Count -gt 0) { '发现问题' } else { '运行正常' }

# ============================================
# 7. 读取并渲染模板
# ============================================
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$templatePath = Join-Path $TemplateDir "report-template.html"
$html = Get-Content $templatePath -Raw -Encoding UTF8

# 替换占位符
$html = $html -replace '{{PAGE_TITLE}}', "PCL Log Analyzer - $LogFileName"
$html = $html -replace '{{STATUS_COLOR}}', $statusColor
$html = $html -replace '{{LOG_FILE_NAME}}', $LogFileName
$html = $html -replace '{{STATUS_TEXT}}', $statusText
$html = $html -replace '{{BASIC_INFO_HTML}}', $basicInfoHtml
$html = $html -replace '{{SUGGESTIONS_HTML}}', $sugHtml
$html = $html -replace '{{ERROR_COUNT}}', $displayErrorCount
$html = $html -replace '{{ERRORS_JSON}}', $errorsJson
$html = $html -replace '{{LOG_COUNT}}', $Analysis.KeyLines.Count
$html = $html -replace '{{LOGS_HTML}}', $logHtml
$html = $html -replace '{{TIMESTAMP}}', $timestamp

# 输出HTML文件
$html | Out-File -FilePath $OutputPath -Encoding UTF8

# 返回生成的报告信息
return @{
    ReportPath = $OutputPath
    StatusText = $statusText
    ErrorCount = $displayErrorCount
    SuggestionCount = $suggestions.Count
}

