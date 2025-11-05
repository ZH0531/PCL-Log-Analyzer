# ============================================
# PCL Log Analyzer - 生成历史报告列表
# ============================================

param(
    [string]$ReportsDir,
    [string]$TemplateDir
)

# 设置路径
$listTemplatePath = Join-Path $TemplateDir "reports-list-template.html"
$listOutputPath = Join-Path $ReportsDir "reports-list.html"

Write-Host "正在生成历史报告列表..." -ForegroundColor Cyan

# 扫描Reports文件夹中的所有HTML文件（排除reports-list.html和latest.html）
$reportFiles = Get-ChildItem -Path $ReportsDir -Filter "*.html" -File | Where-Object { 
    $_.Name -ne "reports-list.html" -and $_.Name -ne "latest.html"
} | Sort-Object LastWriteTime -Descending

if ($reportFiles.Count -eq 0) {
    Write-Host "  警告：未找到任何报告文件" -ForegroundColor Yellow
    return
}

# 生成报告列表HTML
$reportsHtml = ""
$totalSize = 0
$index = 1

foreach ($file in $reportFiles) {
    $fileName = $file.Name
    $fileSize = [math]::Round($file.Length / 1KB, 2)
    $totalSize += $file.Length
    $fileTime = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
    $displayTime = $file.LastWriteTime.ToString("MM/dd HH:mm")
    $timestamp = [int64](Get-Date $file.LastWriteTime -UFormat %s)
    
    # 第一个文件（最新）添加标签
    $isLatest = ($index -eq 1)
    $itemClass = if ($isLatest) { "report-item latest" } else { "report-item" }
    $badge = if ($isLatest) { "<span class='badge'>最新</span>" } else { "" }
    
    # 读取报告文件，提取状态和版本信息
    $statusText = "未知"
    $statusColor = "#95a5a6"
    $gameVersion = "Unknown"
    $modLoader = "Unknown"
    $username = "Unknown"
    
    try {
        $reportContent = Get-Content $file.FullName -Raw -Encoding UTF8
        
        # 提取状态
        if ($reportContent -match "<div class='status-big'>([^<]+)</div>") {
            $statusText = $matches[1]
            # 根据状态文本设置颜色
            $statusColor = switch ($statusText) {
                "游戏崩溃" { "#ff6b6b" }
                "发现问题" { "#ffd93d" }
                "运行正常" { "#6bcf7f" }
                default { "#95a5a6" }
            }
        }
        
        # 提取游戏版本
        if ($reportContent -match "<div class='info-label'>游戏版本</div><div class='info-value'>([^<]+)</div>") {
            $gameVersion = $matches[1]
        }
        
        # 提取Mod加载器
        if ($reportContent -match "<div class='info-label'>Mod加载器</div><div class='info-value'>([^<]+)</div>") {
            $modLoader = $matches[1]
        }
        
        # 提取用户名
        if ($reportContent -match "<div class='info-label'>用户名</div><div class='info-value'>([^<]+)</div>") {
            $username = $matches[1]
        }
    } catch {
        # 忽略读取错误
    }
    
    # 生成显示名称（玩家名 · 游戏版本-Mod加载器）
    $displayName = if ($username -ne "Unknown" -and $gameVersion -ne "Unknown" -and $modLoader -ne "Unknown") {
        "$username · $gameVersion-$modLoader"
    } elseif ($username -ne "Unknown" -and $gameVersion -ne "Unknown") {
        "$username · $gameVersion"
    } elseif ($gameVersion -ne "Unknown" -and $modLoader -ne "Unknown") {
        "$gameVersion-$modLoader"
    } elseif ($gameVersion -ne "Unknown") {
        $gameVersion
    } else {
        # 降级：直接使用文件名
        $fileName -replace '\.html$', ''
    }
    
    # 构建搜索文本（包含所有可搜索内容）
    $searchText = "$fileName $displayName $fileTime $statusText"
    
    # 生成报告项（添加data属性用于搜索和排序）
    $reportsHtml += "<div class='$itemClass' "
    $reportsHtml += "data-filename='$fileName' "
    $reportsHtml += "data-time='$fileTime' "
    $reportsHtml += "data-timestamp='$timestamp' "
    $reportsHtml += "data-size='$fileSize' "
    $reportsHtml += "data-status='$statusText' "
    $reportsHtml += "data-search='$searchText' "
    $reportsHtml += "onclick='openReport(""$fileName"")'>"
    $reportsHtml += "<div class='report-number'>$index</div>"
    $reportsHtml += "<div class='report-info'>"
    $reportsHtml += "<div class='report-name'>$displayName$badge<span class='status-badge' style='background:$statusColor'>$statusText</span></div>"
    $reportsHtml += "<div class='report-meta'>"
    $reportsHtml += "<span>$fileTime</span>"
    $reportsHtml += "<span>$fileSize KB</span>"
    $reportsHtml += "<span>$fileName</span>"
    $reportsHtml += "</div>"
    $reportsHtml += "</div>"
    $reportsHtml += "</div>"
    
    $index++
}

if ($reportsHtml -eq "") {
    $reportsHtml = "<div class='empty-state'><div class='empty-state-icon'>📭</div><p>暂无历史报告</p></div>"
}

# 计算统计信息
$totalSizeKB = [math]::Round($totalSize / 1KB, 2)

# 统计各状态数量
$crashCount = 0
$issueCount = 0
$normalCount = 0

foreach ($file in $reportFiles) {
    try {
        $reportContent = Get-Content $file.FullName -Raw -Encoding UTF8
        if ($reportContent -match "<div class='status-big'>([^<]+)</div>") {
            $status = $matches[1]
            switch ($status) {
                "游戏崩溃" { $crashCount++ }
                "发现问题" { $issueCount++ }
                "运行正常" { $normalCount++ }
            }
        }
    } catch {
        # 忽略读取错误
    }
}

# 读取模板并替换
$listHtml = Get-Content $listTemplatePath -Raw -Encoding UTF8
$listHtml = $listHtml -replace '{{GENERATE_TIME}}', (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
$listHtml = $listHtml -replace '{{TOTAL_COUNT}}', $reportFiles.Count
$listHtml = $listHtml -replace '{{TOTAL_SIZE}}', "$totalSizeKB KB"
$listHtml = $listHtml -replace '{{CRASH_COUNT}}', $crashCount
$listHtml = $listHtml -replace '{{ISSUE_COUNT}}', $issueCount
$listHtml = $listHtml -replace '{{NORMAL_COUNT}}', $normalCount
$listHtml = $listHtml -replace '{{REPORTS_HTML}}', $reportsHtml

# 输出列表HTML
$listHtml | Out-File -FilePath $listOutputPath -Encoding UTF8
Write-Host "  ✓ 历史报告列表已生成: reports-list.html" -ForegroundColor Green

