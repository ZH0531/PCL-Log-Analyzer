# PCL Log Analyzer

<div align="center">

![License](https://img.shields.io/badge/license-CC%20BY--NC--SA%204.0-orange.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey.svg)

</div>

> 一个轻量本地的 Minecraft 日志分析工具 

## 📖 简介 

PCL Log Analyzer 是一个专为 PCL（Plain Craft Launcher）设计的 Minecraft 日志分析工具。它能自动定位最新游戏日志，智能识别各类错误，并生成美观的 HTML 分析报告。



## 📁 文件结构(工具安装后文件，非本仓库)

```
PCL/Custom.xaml              # PCL 自定义主页

PCL/PCL Log Analyzer/        # 工具文件结构
├── Scripts/
│   ├── AnalyzeLogs.ps1      # 主分析脚本
│   ├── SelectLog.ps1        # 手动选择日志
│   ├── ClearReports.ps1     # 清理历史报告
│   └── ErrorRules.ps1       # 错误识别规则库
├── Templates/
│   └── report-template.html # HTML 报告模板
└── Reports/                 # 生成的报告存放位置
    ├── latest.html          # 最新报告
    └── report-*.html        # 历史报告
```

## 🚀 食用方法


### 一键安装
1. 打开 **PCL 启动器**
2. **设置** → **个性化** → **主页**→ **联网更新**
3. 输入地址：
   ```
   https://pcl-log-analyzer.oss-cn-hangzhou.aliyuncs.com/Custom.xaml
   ```

4. 回到主页，点击 **🔄 安装/更新工具**
5. 等待安装完成，开始使用

**就这么简单！** 工具会自动：
- 下载并解压到 `PCL\PCL Log Analyzer\`
- 检查环境
- 验证文件完整性

---

### 从本仓库拉取部署（可选）

如果需要获取最新版本：

1. 从本仓库下载 `PCL Log Analyzer/` 文件夹和 `Custom.xaml`
2. 复制到 PCL 根目录：
   ```
   PCL/
   ├── Custom.xaml
   └── PCL Log Analyzer/
   ```
3. PCL 中配置本地路径：`{PCL目录}\Custom.xaml`

## 🔄 更新流程

1. 在 PCL 主页点击 **🔄 安装/更新工具**
2. 自动下载最新版本
3. 自动备份旧版本和历史报告
4. 验证安装完整性


## 🛠️ 技术栈

- **语言**：PowerShell 5.1+
- **前端**：HTML + CSS（报告模板）
- **部署**：阿里云 OSS + CDN
- **UI**：PCL XAML 自定义主页

## 📝 主要组件说明

### Install.ps1
- 环境检查（PowerShell 版本、编码）
- 从 CDN 下载工具包
- 自动备份/恢复
- 文件完整性验证
- 历史报告迁移

### AnalyzeLogs.ps1
- 日志文件定位（自动/手动）
- 信息提取（3层优先级）
  1. 从日志文件提取（优先）
  2. 从 LatestLaunch.bat 提取（备用）
  3. 使用 "Unknown" 标记
- 错误识别与分类
- HTML 报告生成

### ErrorRules.ps1
- 15+ 种错误类型规则
- 正则表达式匹配
- 解决方案建议库

### Custom.xaml
- PCL 自定义主页
- 在线安装/更新按钮
- 工具调用接口


## 🎯 错误识别类型

| 类型 | 描述 | 示例 |
|------|------|------|
| Mod初始化失败 | Mod 构造函数或初始化阶段崩溃 | Failed to create mod instance |
| Mod加载失败 | Mod 文件损坏或加载异常 | Failed to load mod |
| Mod依赖缺失 | 缺少必需的前置 Mod | requires mod X version Y |
| Mod版本不匹配 | Mod 与游戏版本不兼容 | incompatible mod |
| 模型加载失败 | 方块/物品模型加载错误 | Unable to load model |
| 资源路径错误 | 资源文件路径不存在 | FileNotFoundException |
| 内存不足 | JVM 堆内存溢出 | OutOfMemoryError |
| 网络连接失败 | 无法连接认证服务器 | Connection refused |
| ... | 还有 7+ 种其他类型 | ... |



### 已知限制
- 需要 PowerShell 5.1+（Windows 10 自带）
- 仅支持 PCL 启动器
- 需要联网进行在线安装/更新（也可以在本仓库下载，无需后续联网）

## 📧 反馈与贡献

### 遇到问题？

如果工具分析错误或遇到 Bug，欢迎提交 [Issue](https://github.com/ZH0531/PCL-Log-Analyzer/issues)，并**附上日志文件**：

1. **提交日志**：
   - 上传 `.minecraft/versions/{版本}/logs/latest.log`或错误报告.zip
   - 或提交生成的 HTML 报告文件
   - 说明具体问题（崩溃？识别错误？）

2. **问题模板**：
   ```
   - 问题描述：XXX 错误未被识别
   - 日志文件：[附件]
   ```

### 贡献代码

如果你有能力改进工具，欢迎提交 Pull Request！

**可以贡献的方向**：
- 📝 添加新的错误识别规则（`ErrorRules.ps1`）
- 🎨 改进 HTML 报告样式（`report-template.html`）
- 🐛 修复 Bug 或优化性能
- 📖 完善文档说明

**简单的 PR 流程**：
1. Fork 本仓库
2. 创建新分支：`git checkout -b feature/your-feature`
3. 提交更改：`git commit -m "Add: your description"`
4. Push 分支：`git push origin feature/your-feature`
5. 提交 Pull Request

**代码规范**：
- PowerShell 脚本使用 UTF-8 with DOM 编码（适配低版本Shell）
- 添加注释说明逻辑
- 测试后再提交

---

## 📄 开源协议

本项目基于 [CC BY-NC-SA 4.0](LICENSE) 协议开源。

**你可以：**
- ✅ 自由使用、修改、分发
- ✅ 创建衍生作品

**必须遵守：**
- 📝 署名：保留原作者版权声明
- ❌ 非商业：**禁止用于商业目的（包括出售）**
- 🔄 相同方式共享：衍生作品必须使用相同协议

---

<div align="center">
  
Made with ❤️ by ZH0531

Licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)

</div>

