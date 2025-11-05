# PCL Log Analyzer

<div align="center">

![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-orange.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)
[![爱发电](https://img.shields.io/badge/%E7%88%B1%E5%8F%91%E7%94%B5-%E6%94%AF%E6%8C%81%E4%BD%9C%E8%80%85-946ce6?logo=github-sponsors)](https://afdian.com/a/zh8888)

</div>

> 一个轻量本地的 Minecraft 日志分析工具，智能识别错误，生成可视化报告

## 📖 简介 

PCL Log Analyzer 是一个专为 PCL（Plain Craft Launcher）设计的 Minecraft 日志分析工具。它能自动定位最新游戏日志，智能识别各类错误，并生成美观的 HTML 分析报告，帮助玩家快速定位和解决游戏问题。

### ✨ 核心特性

- 🎯 **智能错误识别**：25+ 种常见错误类型，自动匹配并提供解决建议（欢迎issue！）
- 📊 **可视化报告**：美观的 HTML 报告，支持历史记录查看
- 🔄 **一键安装更新**：在线安装，自动版本检测和完整性验证
- 🗂️ **历史报告管理**：带搜索、筛选、排序的历史报告列表
- 🛠️ **模块化架构**：清晰的代码结构，易于维护和扩展

## 📁 文件结构

### 安装后的文件结构（非本仓库）

```
PCL/Custom.xaml              # PCL 自定义主页

PCL/PCL Log Analyzer/        # 工具根目录
├── Scripts/                 # 脚本文件夹
│   ├── AnalyzeLogs.ps1      # 主分析脚本（入口）
│   ├── LogParser.ps1        # 日志解析模块
│   ├── ReportGenerator.ps1  # 报告生成模块
│   ├── GenerateReportsList.ps1  # 历史报告列表生成
│   ├── ErrorRules.ps1       # 错误识别规则库
│   ├── SelectLog.ps1        # 手动选择日志文件
│   └── ClearReports.ps1     # 清理历史报告
├── Templates/               # HTML 模板文件夹
│   ├── report-template.html        # 单个报告模板
│   └── reports-list-template.html  # 历史报告列表模板
├── Custom.xaml.ini          # 版本控制文件
└── Reports/                 # 生成的报告存放目录
    ├── latest.html          # 最新报告
    ├── reports-list.html    # 历史报告列表页
    └── *.html               # 历史报告
```

### 开发目录结构（本仓库）

```
PCL Log Analyzer Dev/
├── Custom.xaml              # PCL 自定义主页源文件
├── Custom.xaml.ini          # 版本配置文件
├── Install.ps1              # 在线安装/更新脚本
├── Package.ps1              # 工具打包脚本（生成 PCL Log Analyzer.zip）
├── Release-Package.ps1      # Release打包脚本（生成预览发布包）
├── Upload.ps1               # 阿里云 OSS 上传脚本（自动部署到 CDN）
├── Sync.ps1                 # 开发同步用户端脚本，用于调试
├── README.md                # 项目文档
└── PCL Log Analyzer/        # 工具源码目录
    ├── Scripts/             # （同上）
    ├── Templates/           # （同上）
    └── Custom.xaml.ini      # 工具内版本文件
```

## 🚀 使用方法

### 一键安装（推荐）

1. 打开 **PCL 启动器**
2. **设置** → **个性化** → **主页**→ **联网更新**
3. 输入地址：
   ```
   https://pcl.log.zh8888.top/Custom.xaml
   ```

4. 回到主页，点击 **🔄 安装/更新工具**
5. 等待安装完成，开始使用

**就这么简单！** 安装脚本会自动：
- ✅ 检查 PowerShell 版本和编码环境
- ✅ 从 CDN 下载最新工具包
- ✅ 验证文件完整性（大小校验 ±1KB）
- ✅ 安全更新（临时备份，失败自动回滚）
- ✅ 迁移并保留所有历史报告

---

### 本地部署（不依赖在线更新）

如果你无法连接到 CDN 或希望离线使用，可以手动部署：

1. 前往 [Releases](https://github.com/ZH0531/PCL-Log-Analyzer/releases) 下载最新的 **完整发布包**
2. 解压下载的压缩包到 PCL 根目录（即 `PCL/` 文件夹）
3. 打开 **PCL 启动器** → **设置** → **个性化** → **主页** → **读取本地文件**
4. 点击刷新主页

> **注意**：本地部署后将无法使用在线更新功能，需要手动下载新版本替换。

---

## 🔄 更新方法

在 PCL 主页点击 **🔄 安装/更新工具** 即可自动更新到最新版本。

**工具会自动：**
- 检测新版本
- 下载并安装
- 保留所有历史报告
- 失败时自动回滚



## 🛠️ 技术栈

- **语言**：PowerShell 5.1+ (UTF-8 with BOM 编码)
- **前端**：HTML5 + CSS3 + Vanilla JavaScript
- **部署**：阿里云 OSS + CDN
- **UI**：PCL XAML 自定义主页
- **架构**：模块化设计，关注点分离



## 🎯 错误识别类型

| 类型 | 描述 | 严重程度 |
|------|------|----------|
| Mod初始化失败 | Mod 构造函数或初始化阶段崩溃 | 严重 |
| Mod加载失败 | Mod 文件损坏或加载异常 | 严重 |
| Mod依赖缺失 | 缺少必需的前置 Mod | 严重 |
| Mod版本不匹配 | Mod 与游戏版本不兼容 | 严重 |
| Mod不兼容 | 不同 Mod 之间的冲突 | 严重 |
| Incompatible mods found! | Fabric/Quilt 官方不兼容检测 | 严重 |
| Minecraft has crashed! | 游戏崩溃标志 | 严重 |
| 模型加载失败 | 方块/物品模型加载错误 | 中等 |
| 资源路径错误 | 资源文件路径不存在 | 中等 |
| Java版本不兼容 | Java 版本过旧或过新 | 严重 |
| 内存不足 | JVM 堆内存溢出 | 严重 |
| 网络连接失败 | 无法连接认证/资源服务器 | 轻微 |
| 配置文件错误 | Mod 配置文件格式错误 | 中等 |
| 命令执行失败 | 游戏内命令执行错误 | 轻微 |
| Mixin应用失败 | Mixin 注入/混入失败 | 中等 |

> **🔍 帮助我们完善错误识别**
> 
> 工具主要识别 **ERROR** 和 **FATAL** 级别的日志，部分重要的 **WARN** 级别也会识别（如 Mod 加载器不匹配）。
> 
> **我们需要你的帮助！** 🙏
> - 如果你遇到了工具未能识别的错误类型
> - 如果你有特殊的崩溃日志
> - 请在 [GitHub Issues](https://github.com/ZH0531/PCL-Log-Analyzer/issues) 提交日志或反馈
> - 你的贡献将帮助工具支持更多错误类型，让更多玩家受益！

## ⚙️ 版本控制文件格式

**Custom.xaml.ini** 格式：

```ini
version=1.0.2
Scripts/AnalyzeLogs.ps1=8456
Scripts/LogParser.ps1=15234
Scripts/ReportGenerator.ps1=9876
Scripts/GenerateReportsList.ps1=8192
Scripts/ErrorRules.ps1=14559
Scripts/SelectLog.ps1=2841
Scripts/ClearReports.ps1=2967
Templates/report-template.html=19601
Templates/reports-list-template.html=15000
```

**说明**：
- 第一行：`version=主版本号`
- 后续行：`文件路径=文件大小（字节）`
- Install.ps1 会验证每个文件的大小（±1KB 容差）

## 🌐 部署架构

```
开发者端:
  Custom.xaml.ini (修改版本号)
       ↓
  Package.ps1 (自动打包工具包)
       ↓
  Upload.ps1 (上传到阿里云 OSS)
       ↓
  可选：刷新 CDN 缓存
       ↓
  CDN 分发 (https://pcl.log.zh8888.top/)
  ```
  
  ```

用户端:
  PCL 主页 Custom.xaml (联网更新)
       ↓
  点击"安装/更新工具"按钮
       ↓
  Install.ps1 (从 CDN 下载)
       ↓
  自动安装/更新到本地
```

**更新流程说明**：

| 场景 | 行为 |
|------|------|
| 首次安装 | 下载并安装 |
| 版本相同 + 文件完整 | 退出（无需更新） |
| 版本相同 + 文件损坏 | 重新下载修复 |
| 有新版本 | 备份 → 下载 → 安装 → 迁移报告 → 删除备份 |
| 更新失败 | 自动回滚到备份版本 |
| 本地已安装 + 无法连接CDN | 跳过更新，使用本地版本 |

## 📊 工作流程图

```
用户启动游戏 (PCL)
    ↓
游戏退出/崩溃
    ↓
返回 PCL 主页
    ↓
点击"📊 分析日志"按钮
    ↓
AnalyzeLogs.ps1 启动
    ├─ 1. 定位最新游戏版本
    ├─ 2. 读取日志文件
    ├─ 3. 调用 LogParser.ps1 解析
    │     ├─ 提取游戏信息
    │     ├─ 应用错误规则
    │     └─ 返回 $analysis
    ├─ 4. 调用 ReportGenerator.ps1
    │     ├─ 生成 HTML 报告
    │     ├─ 序列化 JSON 数据
    │     └─ 输出 yyMMdd-HHmmss-*.log.html
    ├─ 5. 复制为 latest.html
    ├─ 6. 调用 GenerateReportsList.ps1
    │     └─ 生成 reports-list.html
    └─ 7. 自动打开报告（浏览器）
```

## 📦 依赖环境

### 必需
- **操作系统**：Windows 10/11
- **PowerShell**：5.1+ （Windows 10 自带）
- **启动器**：Plain Craft Launcher 2（PCL2）

### 可选
- **浏览器**：用于查看 HTML 报告（系统默认浏览器）
- **网络连接**：仅在线安装/更新时需要

### 已知限制
- ❌ 不支持 Linux/macOS
- ❌ 不支持其他启动器（如 HMCL、BakaXL）
- ⚠️ 需要 UTF-8 with BOM 编码支持（低版本 PowerShell 需 BOM 才能输出中文）

## 📧 反馈与贡献

### 遇到问题？

如果工具分析错误或遇到 Bug，欢迎提交 [Issue](https://github.com/ZH0531/PCL-Log-Analyzer/issues)，并**附上日志文件**：

**问题模板**：
```
- 问题类型：[未识别错误 / 工具崩溃 / 其他]
- 问题描述：XXX 错误未被识别 / 工具报错 XXX
- 日志文件：[上传 latest.log 或生成的 HTML 报告]
- 游戏版本：1.21.1
- Mod加载器：Fabric 0.17.3
- 工具版本：v1.0.2
```

**日志获取方式**：
1. 游戏崩溃后，点击 PCL 弹窗的 **导出错误报告** 按钮
2. 或在 `.minecraft/versions/{版本}/logs/latest.log` 手动获取
3. 或直接提交本工具生成的 HTML 报告（包含所有信息）

---

### 贡献代码

欢迎提交 Pull Request 改进工具！

**可以贡献的方向**：
- 📝 **添加新的错误规则**（`ErrorRules.ps1`）
- 🎨 **改进 HTML 样式**（`Templates/*.html`）
- 🐛 **修复 Bug 或优化性能**
- 🌐 **多语言支持**
- 📖 **完善文档**

**PR 流程**：
1. Fork 本仓库（请将本仓库放在 `/PCL` 目录下，并改名为`PCL Log Analyzer Dev`）
2. 创建新分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m "Add: your description"`
4. Push 分支：`git push origin feature/your-feature`
5. 提交 Pull Request

**代码规范**：
- ✅ PowerShell 脚本使用 **UTF-8 with BOM** 编码（兼容低版本）
- ✅ 添加清晰的注释说明
- ✅ 遵循现有代码风格
- ✅ 提交前测试功能

**添加新错误规则示例**：

在 `ErrorRules.ps1` 中：

**步骤1：在 `Get-ErrorTypes` 函数中添加错误规则**
```powershell
function Get-ErrorTypes {
    return @(
        # ... 其他规则 ...
        
        # 你的新规则（哈希表内用分号，数组元素末尾用逗号）
        @{ 
            Pattern = '/ERROR\].*你的正则表达式';  # 正则匹配模式
            Type = '新错误类型';                   # 错误类型名称
            Severity = '严重';                     # 严重/中等/轻微
            Priority = 25;                         # 优先级（数字越小越优先）
            CollectDetails = $true                 # 最后一个属性不需要分号
        },
        
        # 最后一个规则可以不加逗号
        @{ Pattern = '/ERROR\]'; Type = '一般错误'; Severity = '中等'; Priority = 50 }
    )
}
```

**步骤2：在 `Get-ErrorSuggestion` 函数中添加解决建议**
```powershell
function Get-ErrorSuggestion {
    param([string]$ErrorType)
    
    switch ($ErrorType) {
        # ... 其他建议 ...
        
        '新错误类型' { 
            return @{ 
                Title = 'YourID';                                        # 建议标识（简短唯一）
                Text = '问题描述和解决方法：①第一步 ②第二步 ③第三步'  # 建议内容
            }
        }
    }
}
```

**完整示例（添加Java版本检测）**：
```powershell
# 在 Get-ErrorTypes 中添加（哈希表内用分号，数组元素末尾用逗号）：
@{ Pattern = '/ERROR\].*UnsupportedClassVersionError'; Type = 'Java版本过低'; Severity = '严重'; Priority = 17 },

# 在 Get-ErrorSuggestion 中添加：
'Java版本过低' { 
    return @{ 
        Title = 'Java'; 
        Text = 'Java版本不兼容：当前Java版本过低。解决方法：在PCL设置中切换到Java 17或更高版本' 
    }
}
```

---

## 📄 开源协议

本项目基于 [CC BY-NC-SA 4.0](LICENSE) 协议开源。

**你可以：**
- ✅ 自由使用、修改、分发
- ✅ 创建衍生作品

**必须遵守：**
- 📝 **署名**：保留原作者版权声明
- ❌ **非商业**：禁止用于商业目的（包括出售、打包收费等）
- 🔄 **相同方式共享**：衍生作品必须使用相同协议

---

## 🎉 致谢

- 感谢 [Plain Craft Launcher](https://github.com/Meloong-Git/PCL) 提供强大的自定义主页功能
- 感谢所有为本项目提供反馈和建议的用户！

---

## ☕ 支持项目

如果这个工具帮助你解决了问题，节省了时间，欢迎通过以下方式支持：


**⭐ Star 本仓库** | **💖 [爱发电支持作者](https://afdian.com/a/zh8888)**

你的支持是我持续维护和改进的动力！🚀



---

<div align="center">
  
Made with ❤️ by ZH0531

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)

</div>
