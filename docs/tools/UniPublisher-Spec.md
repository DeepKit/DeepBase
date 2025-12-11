# UniPublisher 工具规范

> 版本: 0.1  
> 生成日期: 2025-12-11  
> 适用范围: **所有使用 UniBase 架构的桌面应用程序**

---

## 1. 概述与定位

UniPublisher 是一个**统一的 GUI 打包与自动更新发布工具**,独立于各应用程序运行,为 UniBase 生态中的所有桌面应用提供标准化的发布流程。

### 1.1 核心职责

1. **版本管理**  
   - 读取/写入 `.dproj` 文件中的版本号
   - 维护版本历史和发布记录
   
2. **打包构建**  
   - 从 `.dproj` 编译输出目录打包为 ZIP 安装包
   - 支持自定义文件包含/排除规则
   
3. **更新清单生成**  
   - 生成统一的 `version.json` 格式(AutoUpdate 标准)
   - 计算文件哈希(SHA-256)确保完整性
   
4. **多平台发布**  
   - 上传到 HTTP 静态服务器
   - 发布 GitHub Release(通过 `gh` CLI)
   - 发布 Gitee Release(通过 HTTP API)

### 1.2 设计原则

- **完全独立**: UniPublisher 是独立的可执行文件(`UniPublisher.exe`),不依赖任何应用程序
- **配置驱动**: 每个应用有独立的 `.publish.json` 配置文件
- **零参数启动**: 从测试中心点击"打开 UniPublisher"时,无需传递参数,通过 MRU 机制记住最近使用的项目
- **统一标准**: 所有应用使用相同的 `version.json` 格式和字段约定

---

## 2. 配置文件格式

### 2.1 `.publish.json` 结构

每个应用在项目根目录下维护一个 `{AppName}.publish.json` 文件:

```json
{
  "appId": "com.goodmem.twokeyrun",
  "appName": "TwoKeyRun",
  "displayName": "双键快启",
  "dproj": "D:\\_Progs\\02Business\\TwoKeyRun\\TwoKeyRun.dproj",
  "outputDir": "D:\\_Progs\\02Business\\TwoKeyRun\\Win32\\Release",
  "packageLayout": {
    "includePatterns": [
      "*.exe",
      "*.dll",
      "assets/**",
      "config.db",
      "README.md"
    ],
    "excludePatterns": [
      "*.dcu",
      "*.map",
      "*.log"
    ]
  },
  "publishTargets": {
    "http": {
      "enabled": true,
      "uploadUrl": "https://www.goodmem.cn/upload/",
      "versionJsonPath": "https://www.goodmem.cn/updates/twokeyrun/version.json"
    },
    "github": {
      "enabled": true,
      "owner": "fuyi",
      "repo": "TwoKeyRun",
      "useGhCli": true
    },
    "gitee": {
      "enabled": false,
      "owner": "fuyi",
      "repo": "TwoKeyRun",
      "apiToken": ""
    }
  },
  "metadata": {
    "website": "https://twokeyrun.goodmem.cn",
    "supportEmail": "support@goodmem.cn",
    "category": "Utility"
  }
}
```

### 2.2 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `appId` | string | 应用唯一标识(建议使用反向域名,如 `com.goodmem.appname`) |
| `appName` | string | 应用英文名称(与 .dproj 文件名一致) |
| `displayName` | string | 应用显示名称(中文或本地化名称) |
| `dproj` | string | `.dproj` 文件的绝对路径 |
| `outputDir` | string | 编译输出目录(通常是 `Win32/Release` 或 `Win64/Release`) |
| `packageLayout.includePatterns` | array | 打包时包含的文件模式(支持通配符) |
| `packageLayout.excludePatterns` | array | 打包时排除的文件模式 |
| `publishTargets.http` | object | HTTP 上传配置 |
| `publishTargets.github` | object | GitHub Release 配置 |
| `publishTargets.gitee` | object | Gitee Release 配置 |
| `metadata` | object | 应用元数据(可选) |

---

## 3. 版本清单格式(`version.json`)

UniPublisher 生成的 `version.json` 遵循 UniBase.AutoUpdate 标准:

```json
{
  "appId": "com.goodmem.twokeyrun",
  "version": "1.2.0",
  "channel": "stable",
  "publishedAt": "2025-12-11T08:00:00Z",
  "files": [
    {
      "name": "TwoKeyRun-1.2.0-Win32.zip",
      "url": "https://github.com/fuyi/TwoKeyRun/releases/download/v1.2.0/TwoKeyRun-1.2.0-Win32.zip",
      "size": 5242880,
      "sha256": "abcdef1234567890..."
    }
  ],
  "releaseNotes": "## 新增功能\n- 支持多显示器\n- 优化启动速度\n\n## Bug 修复\n- 修复配置丢失问题",
  "mandatory": false,
  "minVersion": "1.0.0",
  "metadata": {
    "author": "付乙",
    "website": "https://twokeyrun.goodmem.cn",
    "changelogUrl": "https://github.com/fuyi/TwoKeyRun/releases/tag/v1.2.0"
  }
}
```

### 3.1 必需字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `appId` | string | 应用唯一标识(必须与 `.publish.json` 中一致) |
| `version` | string | 版本号(语义化版本,如 `1.2.0`) |
| `channel` | string | 更新渠道: `stable` / `beta` / `dev` |
| `publishedAt` | string | 发布时间(ISO 8601 格式) |
| `files` | array | 下载文件列表(至少包含一个 ZIP 包) |
| `files[].name` | string | 文件名 |
| `files[].url` | string | 下载 URL |
| `files[].size` | integer | 文件大小(字节) |
| `files[].sha256` | string | SHA-256 哈希值 |

### 3.2 可选字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `releaseNotes` | string | 更新日志(支持 Markdown) |
| `mandatory` | boolean | 是否强制更新(默认 `false`) |
| `minVersion` | string | 最低兼容版本(低于此版本必须更新) |
| `metadata` | object | 扩展元数据(各应用可自定义键值) |

---

## 4. UniPublisher 用户界面设计

### 4.1 主窗口布局

```
┌────────────────────────────────────────────────────────┐
│ UniPublisher - 发布工具                    [_][□][×]   │
├────────────────────────────────────────────────────────┤
│ 项目: [▼ TwoKeyRun.publish.json        ] [浏览...]    │
│       最近使用: TwoKeyRun, OmniSync, UniBase           │
├────────────────────────────────────────────────────────┤
│ ┌─ 基本信息 ──────────────────────────────────────┐   │
│ │ 应用名称: TwoKeyRun (双键快启)                    │   │
│ │ 当前版本: 1.1.0                                  │   │
│ │ 新版本号: [1.2.0________]  [+Major][+Minor][+Patch] │
│ │ 发布渠道: ⦿ Stable  ○ Beta  ○ Dev                │   │
│ └─────────────────────────────────────────────────┘   │
│ ┌─ 更新说明 ──────────────────────────────────────┐   │
│ │ ## 新增功能                                      │   │
│ │ - 支持多显示器                                   │   │
│ │ - 优化启动速度                                   │   │
│ │                                                  │   │
│ │ ## Bug 修复                                      │   │
│ │ - 修复配置丢失问题                               │   │
│ └─────────────────────────────────────────────────┘   │
│ ┌─ 发布目标 ──────────────────────────────────────┐   │
│ │ ☑ HTTP (www.goodmem.cn)                          │   │
│ │ ☑ GitHub Release (fuyi/TwoKeyRun)                │   │
│ │ ☐ Gitee Release (未配置)                         │   │
│ └─────────────────────────────────────────────────┘   │
│                                                        │
│ [1. 构建 ZIP] → [2. 生成清单] → [3. 上传发布]         │
│                                                        │
│ ┌─ 输出日志 ──────────────────────────────────────┐   │
│ │ [12:30:15] 开始打包...                           │   │
│ │ [12:30:16] 打包完成: TwoKeyRun-1.2.0-Win32.zip   │   │
│ │ [12:30:17] SHA-256: abcdef...                    │   │
│ │ [12:30:18] 上传到 GitHub...                      │   │
│ │ [12:30:20] ✓ 发布成功!                           │   │
│ └─────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### 4.2 MRU 机制(最近使用项目)

- UniPublisher 在自己的 `UniPublisherConfig.db` 中维护一个 MRU 列表
- 启动时自动加载上次使用的 `.publish.json`
- 下拉框显示最近 5 个项目,支持快速切换
- 用户也可以点击"浏览..."选择新的配置文件

### 4.3 操作流程

1. **选择项目**: 从 MRU 下拉框选择或浏览 `.publish.json`
2. **填写版本信息**:
   - 新版本号(可使用快捷按钮自动递增)
   - 更新说明(Markdown 格式)
   - 发布渠道(Stable/Beta/Dev)
3. **执行发布**:
   - 点击"1. 构建 ZIP": 从 `outputDir` 打包文件
   - 点击"2. 生成清单": 计算哈希,生成 `version.json`
   - 点击"3. 上传发布": 根据配置上传到各发布目标
4. **查看结果**: 在输出日志区查看操作详情和错误信息

---

## 5. 发布目标详解

### 5.1 HTTP 静态服务器

**配置示例**:
```json
"http": {
  "enabled": true,
  "uploadUrl": "https://www.goodmem.cn/upload/",
  "versionJsonPath": "https://www.goodmem.cn/updates/twokeyrun/version.json"
}
```

**上传方式**:
- 通过 HTTP POST 请求上传 ZIP 文件
- 上传完成后更新 `version.json` 文件
- 需要服务器端提供上传 API(如 PHP/Node.js 脚本)

### 5.2 GitHub Release

**配置示例**:
```json
"github": {
  "enabled": true,
  "owner": "fuyi",
  "repo": "TwoKeyRun",
  "useGhCli": true
}
```

**发布方式**:
- 使用 `gh` CLI 工具创建 Release
- 命令示例: `gh release create v1.2.0 TwoKeyRun-1.2.0-Win32.zip --title "v1.2.0" --notes-file release-notes.md`
- 自动上传 ZIP 文件作为 Release Asset

**前置条件**:
- 系统已安装 `gh` CLI: `winget install GitHub.cli`
- 已通过 `gh auth login` 认证

### 5.3 Gitee Release

**配置示例**:
```json
"gitee": {
  "enabled": true,
  "owner": "fuyi",
  "repo": "TwoKeyRun",
  "apiToken": "YOUR_GITEE_TOKEN"
}
```

**发布方式**:
- 通过 Gitee OpenAPI 创建 Release
- API 端点: `POST https://gitee.com/api/v5/repos/{owner}/{repo}/releases`
- 需要在配置中提供 Gitee Personal Access Token

---

## 6. 与测试中心的集成

### 6.1 集成方式

每个应用的测试中心界面中,只需添加**一个按钮**:

```pascal
procedure TTestCenterForm.ButtonOpenUniPublisherClick(Sender: TObject);
begin
  ShellExecute(0, 'open', 'UniPublisher.exe', '', '', SW_SHOWNORMAL);
end;
```

- **零参数启动**: 不传递任何命令行参数
- **MRU 记忆**: UniPublisher 自动加载最近使用的项目
- **快速切换**: 用户可在 UniPublisher 内通过下拉框切换项目

### 6.2 工作流示例

1. 开发者在应用的测试中心运行完整测试(单元测试+集成测试+GUI测试)
2. 测试通过后,点击"打开 UniPublisher"
3. UniPublisher 启动并自动加载该应用的 `.publish.json`
4. 开发者填写版本号和更新说明
5. 点击"上传发布",完成版本发布

---

## 7. 实现清单

### 7.1 核心模块(待实现)

```
UniPublisher/
├── Core/
│   ├── Publisher.ConfigReader.pas    # 读取 .publish.json
│   ├── Publisher.VersionManager.pas  # 版本号管理(读写 .dproj)
│   ├── Publisher.Packager.pas        # ZIP 打包逻辑
│   ├── Publisher.ManifestGenerator.pas # 生成 version.json
│   └── Publisher.Uploader.pas        # 上传到各发布目标
├── UI/
│   └── Publisher.MainForm.pas        # 主界面
└── UniPublisher.dpr                  # 主程序
```

### 7.2 待实现功能列表

- [ ] `.publish.json` 配置读取与验证
- [ ] MRU 项目列表(使用 UniBase.MRU)
- [ ] 版本号管理:
  - [ ] 从 `.dproj` 读取当前版本
  - [ ] 自动递增版本号(Major/Minor/Patch)
  - [ ] 写回新版本到 `.dproj`
- [ ] ZIP 打包:
  - [ ] 根据 `includePatterns` 和 `excludePatterns` 过滤文件
  - [ ] 支持通配符和递归目录
- [ ] `version.json` 生成:
  - [ ] 计算 SHA-256 哈希
  - [ ] 填充所有必需字段
- [ ] 发布目标实现:
  - [ ] HTTP 上传(使用 TIdHTTP 或 TNetHTTPClient)
  - [ ] GitHub Release(调用 `gh` CLI)
  - [ ] Gitee Release(调用 Gitee API)
- [ ] 日志与错误处理:
  - [ ] 实时输出到界面日志区
  - [ ] 错误回滚机制

---

## 8. 配置示例库

为方便各应用快速接入,提供标准配置模板:

### 8.1 最小配置(仅 HTTP)

```json
{
  "appId": "com.goodmem.myapp",
  "appName": "MyApp",
  "displayName": "我的应用",
  "dproj": "D:\\Projects\\MyApp\\MyApp.dproj",
  "outputDir": "D:\\Projects\\MyApp\\Win32\\Release",
  "packageLayout": {
    "includePatterns": ["*.exe", "*.dll", "config.db"],
    "excludePatterns": ["*.dcu"]
  },
  "publishTargets": {
    "http": {
      "enabled": true,
      "uploadUrl": "https://www.goodmem.cn/upload/",
      "versionJsonPath": "https://www.goodmem.cn/updates/myapp/version.json"
    }
  }
}
```

### 8.2 完整配置(所有发布目标)

见第 2.1 节示例。

---

## 9. 后续扩展

### 9.1 可选功能(未来版本)

- [ ] 多平台支持(Win32/Win64/macOS/Linux)
- [ ] 增量更新包生成(Delta Patch)
- [ ] 安装包制作(MSI/Inno Setup 集成)
- [ ] 版本回滚功能
- [ ] 发布审批流程(多人协作)
- [ ] 自动化 CI/CD 集成(命令行模式)

### 9.2 命令行模式(规划)

```bash
UniPublisher.exe --config MyApp.publish.json --version 1.2.0 --channel stable --auto-publish
```

用于在 CI/CD 流程中自动化发布。

---

## 10. 相关文档

- [Developer Test Center 规范](../ui/07-Developer-Test-Center.md)
- [UniBase.AutoUpdate API](../05.01.uniBase-4AI-API参考-v1.0.md)
- [发布更新解锁集成指南](../10.01.uniBase-4AI-发布更新解锁集成指南-v1.0.md)

---

**最后更新**: 2025-12-11  
**维护者**: UniBase 开发团队
