# ============================================
# PCL Log Analyzer - 上传到阿里云OSS
# ============================================

$ErrorActionPreference = "Stop"

# 修复中文显示
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Clear-Host
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PCL Log Analyzer - 上传工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 配置区域
# ============================================
$ossEndpoint = "oss-cn-hangzhou.aliyuncs.com"          # OSS endpoint（不含https://）
$ossBucket = "pcl-log-analyzer"                        # 存储桶名称
$ossPath = ""                                          # OSS路径前缀（留空表示根目录）

# 从环境变量读取 AccessKey（如果存在）
$ossAccessKeyId = $env:OSS_ACCESS_KEY_ID
$ossAccessKeySecret = $env:OSS_ACCESS_KEY_SECRET

# 如果环境变量不存在，使用配置值
if (!$ossAccessKeyId) { $ossAccessKeyId = "YOUR_ACCESS_KEY_ID" }
if (!$ossAccessKeySecret) { $ossAccessKeySecret = "YOUR_ACCESS_KEY_SECRET" }

# ============================================
# OSS 上传函数（使用 REST API）
# ============================================
function Upload-ToOSS {
    param(
        [string]$LocalFile,
        [string]$OssKey,
        [string]$Endpoint,
        [string]$Bucket,
        [string]$AccessKeyId,
        [string]$AccessKeySecret
    )
    
    $contentType = "application/octet-stream"
    $date = [DateTime]::UtcNow.ToString("r")
    
    # 构造签名字符串
    $canonicalizedResource = "/$Bucket/$OssKey"
    $stringToSign = "PUT`n`n$contentType`n$date`nx-oss-object-acl:public-read`n$canonicalizedResource"
    
    # HMAC-SHA1 签名
    $hmac = New-Object System.Security.Cryptography.HMACSHA1
    $hmac.Key = [Text.Encoding]::UTF8.GetBytes($AccessKeySecret)
    $signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signature = [Convert]::ToBase64String($signatureBytes)
    
    # 构造请求
    $url = "https://$Bucket.$Endpoint/$OssKey"
    $headers = @{
        "Date" = $date
        "Authorization" = "OSS ${AccessKeyId}:$signature"
        "Content-Type" = $contentType
        "x-oss-object-acl" = "public-read"
    }
    
    # 上传文件
    $ProgressPreference = 'SilentlyContinue'
    Invoke-RestMethod -Uri $url -Method Put -Headers $headers -InFile $LocalFile | Out-Null
}

# ============================================
# 检查必要文件
# ============================================
Write-Host "[1/3] 检查文件..." -ForegroundColor Yellow

$devRoot = $PSScriptRoot
$zipFile = Join-Path $devRoot "PCL Log Analyzer.zip"
$iniFile = Join-Path $devRoot "Custom.xaml.ini"
$installFile = Join-Path $devRoot "Install.ps1"
$xamlFile = Join-Path $devRoot "Custom.xaml"

$filesToUpload = @(
    @{ Local = $zipFile; Oss = "PCL Log Analyzer.zip"; Required = $true },
    @{ Local = $iniFile; Oss = "Custom.xaml.ini"; Required = $true },
    @{ Local = $installFile; Oss = "Install.ps1"; Required = $true },
    @{ Local = $xamlFile; Oss = "Custom.xaml"; Required = $true }
)

$allOk = $true
foreach ($file in $filesToUpload) {
    if (Test-Path $file.Local) {
        $size = [math]::Round((Get-Item $file.Local).Length / 1KB, 2)
        Write-Host "  ✓ $($file.Oss) ($size KB)" -ForegroundColor Green
    } else {
        if ($file.Required) {
            Write-Host "  ✗ $($file.Oss) (缺失)" -ForegroundColor Red
            $allOk = $false
        }
    }
}

if (!$allOk) {
    Write-Host ""
    Write-Host "  提示：请先运行 Package.ps1 打包工具" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ============================================
# 检查配置
# ============================================
Write-Host "[2/3] 检查配置..." -ForegroundColor Yellow

if ($ossAccessKeyId -eq "YOUR_ACCESS_KEY_ID" -or $ossAccessKeySecret -eq "YOUR_ACCESS_KEY_SECRET") {
    Write-Host "  ✗ 请先配置 AccessKey" -ForegroundColor Red
    Write-Host ""
    Write-Host "请编辑 Upload.ps1，修改以下配置：" -ForegroundColor Yellow
    Write-Host "  `$ossEndpoint = ""oss-cn-hangzhou.aliyuncs.com""" -ForegroundColor Cyan
    Write-Host "  `$ossBucket = ""your-bucket-name""" -ForegroundColor Cyan
    Write-Host "  `$ossAccessKeyId = ""YOUR_ACCESS_KEY_ID""" -ForegroundColor Cyan
    Write-Host "  `$ossAccessKeySecret = ""YOUR_ACCESS_KEY_SECRET""" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "  ✓ Endpoint: $ossEndpoint" -ForegroundColor Green
Write-Host "  ✓ Bucket: $ossBucket" -ForegroundColor Green
Write-Host "  ✓ AccessKey 已配置" -ForegroundColor Green
Write-Host ""

# ============================================
# 读取版本号
# ============================================
$iniContent = Get-Content $iniFile
$versionLine = $iniContent[0].Trim()
if ($versionLine -match '^version=(.+)$') {
    $version = $matches[1]
    Write-Host "当前版本: v$version" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "  ⚠ 无法读取版本号，使用默认文件名" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================
# 上传文件
# ============================================
Write-Host "[3/3] 上传到阿里云OSS..." -ForegroundColor Yellow
Write-Host ""

$uploadedCount = 0
$totalCount = $filesToUpload.Count

try {
    foreach ($file in $filesToUpload) {
        $ossKey = if ($ossPath) { "$ossPath$($file.Oss)" } else { $file.Oss }
        
        Write-Host "  [$($uploadedCount+1)/$totalCount] 上传 $($file.Oss)..." -ForegroundColor Cyan
        
        Upload-ToOSS -LocalFile $file.Local `
                     -OssKey $ossKey `
                     -Endpoint $ossEndpoint `
                     -Bucket $ossBucket `
                     -AccessKeyId $ossAccessKeyId `
                     -AccessKeySecret $ossAccessKeySecret
        
        Write-Host "  ✓ $($file.Oss) 上传成功" -ForegroundColor Green
        $uploadedCount++
    }
    
} catch {
    Write-Host ""
    Write-Host "  ✗ 上传失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能的原因：" -ForegroundColor Yellow
    Write-Host "  1. AccessKey 配置错误" -ForegroundColor White
    Write-Host "  2. 网络连接问题" -ForegroundColor White
    Write-Host "  3. 存储桶名称或权限错误" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  上传完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 询问是否刷新 CDN
$refreshCdn = Read-Host "是否刷新 CDN 缓存？(Y/N)"
if ($refreshCdn -eq 'Y' -or $refreshCdn -eq 'y') {
    Write-Host ""
    Write-Host "正在刷新 CDN..." -ForegroundColor Yellow
    
    try {
        # 阿里云 CDN API 参数
        $timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $nonce = [guid]::NewGuid().ToString()
        
        # 构造请求参数
        $params = @{
            'AccessKeyId' = $ossAccessKeyId
            'Action' = 'RefreshObjectCaches'
            'Format' = 'JSON'
            'ObjectPath' = 'https://pcl.log.zh8888.top/'
            'ObjectType' = 'Directory'
            'SignatureMethod' = 'HMAC-SHA1'
            'SignatureNonce' = $nonce
            'SignatureVersion' = '1.0'
            'Timestamp' = $timestamp
            'Version' = '2018-05-10'
        }
        
        # 按字典序排序参数
        $sortedParams = $params.GetEnumerator() | Sort-Object Name
        $canonicalQueryString = ($sortedParams | ForEach-Object {
            "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString($_.Value))"
        }) -join '&'
        
        # 构造待签名字符串
        $stringToSign = "POST&%2F&" + [uri]::EscapeDataString($canonicalQueryString)
        
        # 计算签名
        $hmac = New-Object System.Security.Cryptography.HMACSHA1
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes($ossAccessKeySecret + "&")
        $signature = [Convert]::ToBase64String($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))
        
        # 构造最终 URL
        $finalUrl = "https://cdn.aliyuncs.com/?$canonicalQueryString&Signature=$([uri]::EscapeDataString($signature))"
        
        # 发送请求
        $response = Invoke-RestMethod -Uri $finalUrl -Method Post -ErrorAction Stop
        
        if ($response.RequestId) {
            Write-Host "✓ CDN 刷新任务已提交 (RequestId: $($response.RequestId))" -ForegroundColor Green
            Write-Host "  刷新将在 5-6 分钟内生效" -ForegroundColor Gray
        } else {
            Write-Host "✓ CDN 刷新任务已提交" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ CDN 刷新失败: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "按任意键退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

