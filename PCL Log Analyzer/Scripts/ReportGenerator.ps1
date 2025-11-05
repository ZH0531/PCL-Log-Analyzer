# ============================================
# PCL Log Analyzer - 报告生成模块
# ============================================

param(
    [hashtable]$Analysis,
    [string]$LogFileName,
    [string]$TemplateDir,
    [string]$OutputPath,
    [scriptblock]$GetSuggestionFunc
)

# ============================================
# 1. 排序错误并生成建议
# ============================================
$sortedErrors = $Analysis.Errors | Sort-Object { 
    if ($null -eq $_.Priority) { 100 } else { $_.Priority }
}

$displayErrorCount = $sortedErrors.Count

$suggestions = @()
foreach ($err in $sortedErrors) {
    $suggestion = & $GetSuggestionFunc -ErrorType $err.Type
    if ($suggestion -and !($suggestions | Where-Object {$_.Title -eq $suggestion.Title})) {
        $suggestions += $suggestion
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
# 需要收集Details的错误类型
$collectDetailsTypes = @("Mod不兼容", "Mod依赖缺失", "Mod版本不匹配", "Incompatible mods found!")

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

# ============================================
# 4. 生成建议HTML
# ============================================
$sugHtml = ""
$i = 1
foreach ($sug in $suggestions) {
    $sugHtml += "<div class='sug-box'><strong>$i.</strong> $($sug.Text)</div>"
    $i++
}
if ($suggestions.Count -eq 0) {
    $sugHtml = "<div class='empty-state'>暂无建议</div>"
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

