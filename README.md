# DeepBase - Delphi 企业级应用开发基础框架

> **�?Delphi 企业级应用开发像 Spring Boot 一样简�?*

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](#-许可�?
[![Delphi](https://img.shields.io/badge/Delphi-10.3%2B-red.svg)](https://www.embarcadero.com/products/delphi)
[![Platform](https://img.shields.io/badge/platform-Windows%20(Core)%20%7C%20FMX%20(Extended)-lightgrey.svg)](https://github.com/DeepBase-framework/DeepBase)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/DeepBase-framework/DeepBase/actions)

## 🎯 项目定位

DeepBase 是一�?**Delphi 企业级应用开发基础框架**，提供现代化架构模式和常用功能封装：

| 类型 | 功能 |
|------|------|
| 🏗�?**架构模式** | IoC 依赖注入、EventBus 事件总线、MVVM、状态机 |
| 📦 **基础设施** | 配置管理、日志系统、缓存、对象池、工作队�?|
| 💼 **业务功能** | 数据验证、权限授权、国际化、功能开关、ORM、Commerce |
| 🛡�?**可靠�?* | 熔断/重试/超时、限流、定时调度、指标收�?|
| 🛠�?**工具封装** | 集合扩展、日期时间、加密哈希、序列化、模板引�?|

### 不是什�?

- �?游戏/图形引擎
- �?科学计算�?
- �?网络协议�?
- �?"大而全"的万能框�?
- �?强制绑定特定后端平台的中间件

详见：[docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md](docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md)

## 📦 核心特�?

### Phase 0: 最小核心（当前阶段�?
- 🗄�?**统一配置管理**：基�?SQLite 的类型安全配置系�?
- 🌍 **国际�?(i18n)**：`T()` 函数自动翻译，支持多语言
- 💾 **窗体状态管�?*：自动保�?恢复窗体位置、大�?
- 🔧 **线程安全**：所有核�?API 均线程安�?

### Phase 1-5（已完成�?
- 📝 日志系统 - 异步写入、文件轮转、数据库存储
- 📋 MRU（最近使用列表）
- ⌨️ 快捷键管�?
- 🎨 主题切换
- 🤖 LLM 集成 - 多模型支�?
- 🔄 自动更新
- 🛠�?DeepBase Studio（GUI 管理工具�?

### Phase 7（功能补充）
- 🔒 单实例检�?- 防止应用多开
- 📄 简单报表导�?- CSV/HTML
- 🌅 启动画面 - 淡入淡出、进度条

### ThirdParty 扩展（可选）
- ☁️ 云存储集�?- AWS S3/Azure Blob/阿里�?OSS
- 💾 数据库驱�?- PostgreSQL/MySQL 适配�?
- 🎨 UI 主题 - Material/Fluent/macOS 风格
- 💳 支付集成 - WeChat Pay/Alipay/Stripe/PayPal 直连 SDK，订单与权益流程�?Commerce

## 📊 功能矩阵 / 成熟度边界

> 详细矩阵见 [`docs/80.feature-matrix.md`](docs/80.feature-matrix.md)。下表只列关键边界。

| 类别 | 模块 | 成熟度 | 备注 |
|------|------|--------|------|
| 核心基础 | Config / i18n / FormState / Logging / MRU / Cache / ORM / EventBus / IoC / MVVM / Validation / StateMachine | Implemented | 需 `DeepBase.Initialize*` |
| Windows 桌面能力 | Hotkeys / TrayIcon / Protection / AutoFix / Browser | **Platform-limited (Windows)** | 非 Windows 平台为 stub 或无法使用 |
| 安全 | Security (DPAPI + AES-GCM) | Implemented | 非 Windows 默认 fail-closed, 需 `DEEPBASE_INSECURE_DEV_MODE` 显式启用开发模式 |
| 语音 | Speech (ASR/TTS/WakeWord/Voiceprint/Intent) | Implemented (Windows-primary) | 云端 provider (Baidu/StepFun/Edge) 需网络; SenseVoice 需 ONNX 模型目录 |
| LLM | LLM client (6 providers) | Needs-external-service | 需 HTTP 网络 + provider API key |
| Commerce | WeChatPay / Alipay / Stripe / PayPal | Needs-external-service | 需支付 SDK + 商户账号 + 回调服务器 |
| FMX mobile | Platform / Permission / Share / SafeArea | Partial (BUG-277, BUG-281) | 8 处 TODO 已标注任务 ID; 非 Android/iOS 时权限返回 False |
| DataPlatform | WeChat39x/4x schema 适配器 | Experimental | SQLCipher 适配器未实际编译到 DPK |
| AutoUpdate | Updater / AutoUpdate | Partial | 远端 version.json 缺失视为 "无更新" (fail-open) |

### 三条高层表述的边界

- **"像 Spring Boot 一样简单"** — 提供模块化包边界 + 依赖注入 + 统一初始化入口。**前提**: 任何调用 `DeepBase.Initialize*` 的最终程序必须链接 `DeepBase.Persistence.Manager.FireDAC`, 否则 `InitializeOrRaise` 抛 "No DB connection adapter registered"。
- **"所有核心 API 线程安全"** — 范围: Core 模块 (`Cache` / `EventBus` / `IoC` / `Config` / `i18n` / `Logging` / `MRU`) 内部用 `TCriticalSection` / `TMonitor` 保护。**例外**: 纯逻辑 builder 类 (`TValidation` / `TStateMachine` 单实例) 不承诺线程安全, 由调用方同步。验证见 `*.PBT.pas` 并发用例。
- **"跨平台"** — `DeepBaseCore` 明确为 **Windows 运行时核心** (依赖 Winapi, 含 TrayIcon / Hotkeys / Protection / FormState / AutoFix), 不直接依赖 VCL/FMX/FireDAC。跨平台扩展通过 `DeepBaseFMX` 包实现 (macOS/Linux), 当前 Partial (BUG-277/281 跟踪)。

## 🚀 快速开�?

### 安装要求

- **Delphi 版本**：Delphi 10.3 Rio 或更�?
- **数据�?*：FireDAC + SQLite（系统自带）
- **单元测试**：DUnitX（可选）

### 1. 安装�?

1. 基础能力：编�?`DeepBaseCore.dpk`
2. 服务/数据�?可选能力按需编译：`DeepBaseServices.dpk`、`DeepBasePersistence.dpk`、`DeepBaseFeatures.dpk`
3. 需�?IDE 拖控件时再安�?VCL/FMX 设计时包：`dclDeepBaseVCL.dpk` / `dclDeepBaseFMX.dpk`

运行时包边界：`DeepBaseCore.dpk` 是 **Windows 运行时核心**（依赖 Winapi / 包含 TrayIcon、Hotkeys、Protection、FormState、AutoFix 等桌面能力），**不直接依赖 VCL/FMX/FireDAC**。UI 框架相关的主题切换、全局异常展示等行为由 `DeepBaseVCL.dpk` / `DeepBaseFMX.dpk` 适配层承接。跨平台（macOS/Linux）扩展通过 FMX 包实现，Core 自身不承诺跨平台主题切换、全局异常展示�?UI 行为�?`DeepBaseVCL.dpk` / `DeepBaseFMX.dpk` 适配层承接。`DeepBaseFeatures.dpk` 依赖 `DeepBaseServices.dpk`，避免底层服务单元被重复打包�?

数据库接入前置条件：`DeepBase.Manager` 与 FireDAC 持久化适配器已经解耦。任何调用 `DeepBase.Initialize*` / `InitializeWithDB*` 的最终程序，都必须链接 `DeepBase.Persistence.Manager.FireDAC`，否则会报 `No DB connection adapter registered`。

### 2. 初始�?DeepBase

```delphi
program MyApp;

uses
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC; // registers Manager DB adapter

begin
  Application.Initialize;
  
  // 初始�?DeepBase
  DeepBase.InitializeOrRaise;
  
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
  
  // 清理资源
  DeepBase.Finalize;
end.
```

### 3. 使用核心功能

```delphi
// 读写配置
DeepBase.SetConfig('App.Username', 'admin');
var username := DeepBase.GetConfig('App.Username');

// 国际�?
Caption := T('Welcome');  // 自动翻译为当前语言
ShowMessage(TFmt('Hello, %s!', [username]));

// 窗体状态自动保�?
DeepBase.SaveFormState(Self);   // 窗体关闭时调�?
DeepBase.RestoreFormState(Self); // 窗体创建时调�?
```

### 单实例检�?

```delphi
uses DeepBase.SingleInstance;

// �?DPR 文件中，Application.Initialize 之前调用
if not TAppInstance.CheckSingleInstance('MyCompany.MyApp') then
begin
  TAppInstance.ActivateExistingInstance; // 激活已运行的实�?
  Exit;
end;
```

### 数据导出

```delphi
uses DeepBase.Export;

// 导出 DataSet �?CSV
TDataExport.ToCSV(MyDataSet, 'output.csv');

// 导出 DataSet �?HTML（带样式�?
TDataExport.ToHTML(MyDataSet, 'report.html', '报表标题');

// 导出 StringGrid
TDataExport.ToCSV(StringGrid1, 'grid.csv');
```

### 启动画面

```delphi
uses DeepBase.SplashScreen;

// 显示启动画面
TSplashScreen.Show('splash.png');
TSplashScreen.SetStatus('正在加载配置...');
TSplashScreen.SetProgress(30);

// ... 初始化操�?...

TSplashScreen.SetStatus('初始化完�?);
TSplashScreen.SetProgress(100);
TSplashScreen.Hide; // 淡出关闭
```

## 📁 项目结构

```
DeepBase/
├── Core/                    # 核心与兼容门面源码（DeepBaseCore.dpk 只选最小核心）
�?  ├── DeepBase.Manager.pas
�?  ├── DeepBase.Config.pas
�?  ├── DeepBase.i18n.pas
�?  └── DeepBase.Types.pas
├── Persistence/             # FireDAC/DB 持久化适配�?
├── Features/                # 可选功能（LLM、Commerce、更新、云同步、Graph、HttpServer 等）
├── VCL/                     # VCL 控件包与平台适配�?
├── FMX/                     # FMX 控件�?
├── ThirdParty/              # 第三方服�?SDK 适配�?
├── Tools/                   # Studio / Tray / CLI 等工�?
├── Tests/                   # 单元测试
├── Examples/                # 示例工程
├── sql/                     # 数据库脚�?
└── docs/                    # 文档

```

## 📖 文档

- [完整规范](docs/03.03.DeepBase-4H-技术规�?v1.0.md) - 设计规范�?API 参�?
- [集成指南](docs/01.01.DeepBase-4AI-集成指南-v1.0.md) - AI/外部程序集成入口
- [文档索引](docs/00.00.DeepBase-文档索引-v1.0.md) - 全部文档导航
- [下游集成](docs/DeepBase-Downstream-Integration.md) - 下游工程接入�?Commerce 流程
- [项目边界](docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md) - 什么能�?不能�?
- [扩展开发](docs/06.01.DeepBase-4H-ThirdParty扩展开发指�?v1.1.md) - 开发第三方集成

## 🔗 下游集成 DeepFlow（工作流引擎）

> DeepFlow 是 DeepBase 生态的工作流引擎。如果你要在产品里编排 AI 任务、管理多轮对话、调用外部 Skill，**不要自己造轮子——直接用 DeepFlow**。

### DeepFlow 是什么

| 概念 | 说明 |
|------|------|
| **Workflow** | JSON 定义步骤顺序，可视化编排任务流 |
| **Agent** | 执行工作流的实体，11 个角色类构成 OS 内核 |
| **Skill** | 跨语言工具插件（Delphi / Python / Node.js） |
| **Guard** | 熔断器 + 降级，AI 出错自动保护业务 |
| **Session** | 多轮对话上下文管理，保持记忆 |

### 当前状态

- v1.0 完成，112K LOC，M1-M6 全通过
- 5 条链路 E2E 验证通过（DocumentChain / AgentChain / AudioChain / VideoChain / PackageChain）
- 基于 DeepBase 构建，复用其 LLM / EventBus / StateMachine / Validation / Logging 模块

### 哪些产品应该用 DeepFlow

| 产品 | 怎么用 DeepFlow |
|------|-----------------|
| **DeepForge** | AI 代码生成 → 契约验证 → 测试 → 封存（Workflow + Guard） |
| **DeepShine** | 收集内容 → AI 改写 → 审核 → 多平台发布（Workflow + Skill） |
| **DeepInsight** | 五段决策流程 → 多 NPC 碰撞 → 输出胶片（Session + Workflow） |
| **ArtifactOS** | 选题 → 生产 → 验证 → 发布全链路（Workflow + EventBus） |
| **DeepAssist** | 员工操作 → 红绿灯协议 → 受控执行（Guard + Workflow） |

### DeepFlow 复用了 DeepBase 哪些模块

| DeepBase 模块 | DeepFlow 用途 |
|---------------|--------------|
| `DeepBase.LLM` + `DeepBase.LLM.Manager` | 统一 LLM 调用（OpenAI / Anthropic / Azure / LiteLLM / Ollama） |
| `DeepBase.EventBus` | 工作流状态变更通知、步骤事件广播、跨工作流通信 |
| `DeepBase.StateMachine` | 工作流实例状态管理（Created → Running → Paused → Completed） |
| `DeepBase.Validation` | 工作流输入参数验证、步骤输出校验、LLM 响应格式验证 |
| `DeepBase.Logging` | 结构化日志、异步写入、日志轮转 |
| `DeepBase.Config` | 工作流配置读取（超时、重试、默认 LLM 提供商等） |
| `DeepBase.Scheduler` | 定时触发工作流、延迟步骤执行 |
| `DeepBase.Types` | 共享类型定义（日志级别、事件类型） |

### 快速上手

1. 把 DeepFlow `Source/` 目录加入你的 Delphi 项目
2. 在工作流 JSON 里定义步骤顺序
3. 3 行代码执行：

```delphi
uses UniFlow.Workflow.Definition, UniFlow.Workflow.Executor, UniFlow.Workflow.Context;

var
  Executor: TWorkflowExecutor;
  Context: TWorkflowContext;
begin
  Executor := TWorkflowExecutor.Create(TWorkflowDefinition.FromFile('workflow.json'));
  Context := TWorkflowContext.Create;
  Context.SetVariable('user_input', '你好');
  Executor.Execute(Context);
end;
```

### 详细文档

- [DeepFlow 复用 DeepBase 模块策略](../DeepFlow/docs/DeepBase-reuse-strategy.md) — 每个模块的复用价值、集成代码示例、待删除重复文件清单
- [DeepFlow 快速入门（中文）](../DeepFlow/docs/zh/quick-start.md)
- [DeepFlow Quick Start（EN）](../DeepFlow/docs/en/quick-start.md)
- [DeepFlow 工作流定义](../DeepFlow/docs/zh/workflow-definition.md)
- [DeepFlow Skill 开发](../DeepFlow/docs/zh/skills-development.md)

---

## 🔧 乱码修复（fix-code 技能）

> 当你在 Delphi / C++ / Python / Web 项目中遇到中文乱码、注释变方块、.dfm 属性乱码、Git 合并后编码错乱时，**不要手动逐文件改——用 `fix-code` 技能系统性修复**。

### 技能说明

| 属性 | 值 |
|------|-----|
| 名称 | `fix-code` |
| 路径 | `D:\_Progs\00Common\skills\fix-code\SKILL.md` |
| 版本 | 1.0.0 |
| 作者 | 付乙 (ODDFounder) |
| 作用 | 诊断和修复源代码文件中的字符编码问题（GBK/Big5/UTF-8/Shift-JIS/EUC-KR 互转） |

### 什么时候使用

- Delphi 项目升级后 `.pas` / `.dfm` 中文注释乱码
- 跨平台迁移：Windows GBK → Linux/macOS UTF-8
- Git 合并后部分文件出现乱码
- 第三方库源码包含日文/韩文注释导致编译警告
- `.properties` / CSV / 日志文件编码不一致
- Web 前端 `<meta charset>` 与实际文件编码不符

### 乱码根源速查

| 症状 | 原因 |
|------|------|
| `ÄãºÃ`（拉丁扩展字符） | GBK 字节被当 Latin-1 解码 |
| `ä½ å¥½`（带变音符号） | GBK 字节被当 UTF-8 解码 |
| `???`（全问号） | 源编码字符在当前编码中不存在 |
| `□`（方块） | 字体不支持或编码完全错误 |

### 核心修复工具：DeepCharset

DeepCharset 是 fix-code 技能的首选执行工具：

```
工具路径: D:\_Progs\02Business\DeepCharset\DeepCharset.exe
CLI 路径: D:\_Progs\02Business\DeepCharset\bin\DeepCharset.exe
```

**常用命令：**

```bash
# 单个文件 GBK → UTF-8（最常用）
DeepCharset.exe -s GBK -t UTF-8 文件.pas

# 自动检测 → UTF-8
DeepCharset.exe -s auto -t UTF-8 文件.txt

# 递归处理整个项目目录
DeepCharset.exe -s auto -t UTF-8 -r C:\项目目录\

# 繁体 Big5 → UTF-8
DeepCharset.exe -s Big5 -t UTF-8 文件.pas

# 日文 Shift-JIS → UTF-8
DeepCharset.exe -s Shift-JIS -t UTF-8 文件.cpp

# 韩文 EUC-KR → UTF-8
DeepCharset.exe -s EUC-KR -t UTF-8 文件.java

# 添加 UTF-8 BOM（Delphi IDE 偏好）
DeepCharset.exe -s UTF-8 -t UTF-8 --add-bom 文件.pas

# 移除 UTF-8 BOM（某些编译器不认）
DeepCharset.exe -s UTF-8 -t UTF-8 --remove-bom 文件.h
```

### Delphi 专项处理

**老项目升级（Delphi 2007 GBK → Delphi 12+ UTF-8）：**

```bash
# 1. 关闭 Delphi IDE
# 2. 备份整个项目
xcopy /E /I C:\OldProject C:\OldProject_backup

# 3. 递归转换所有 .pas 和 .dfm
DeepCharset.exe -s GBK -t UTF-8 -r C:\OldProject\ --verbose

# 4. 添加 UTF-8 BOM（Delphi IDE 需要）
DeepCharset.exe -s UTF-8 -t UTF-8 --add-bom -r C:\OldProject\

# 5. 在 Delphi IDE 中重新打开项目
```

**.dfm 文件注意事项：**
- .dfm 可能包含二进制格式编码信息，转换后需检查窗体 Caption/Hint/Text
- 如有问题，在 IDE 中重新输入中文属性值

### 修复原则

1. **先备份，再动手** — DeepCharset 默认创建 `.bak`，不要关闭
2. **先诊断，再转码** — 用 `--detect` 确认源编码，不要猜
3. **小步验证** — 先转一个文件确认结果正确，再批量
4. **关闭 IDE** — Delphi/C++Builder 在 IDE 打开时转码可能冲突
5. **记录改动** — 批量转码后提交 Git，方便回溯

### 详细文档

完整修复指南（含诊断流程、编码速查表、常见误区、Git 编码配置等）：

📄 [`D:\_Progs\00Common\skills\fix-code\SKILL.md`](../../../../00Common/skills/fix-code/SKILL.md)

---

## 🧪 运行测试

推荐使用一键脚本（会自动编�?+ 运行，并输出 NUnit XML �?`TestResults/`）：

```powershell
# 运行全部（Unit + Integration�?
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type All

# 只运�?Unit Tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit

# 模块级快速回归（预置别名�?
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit -SkipCompile -Module LLM

# 按修改单元自动映射测试（支持单元名或 .pas 路径�?
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit -SkipCompile -FromUnit DeepBase.LLM,DeepBase.LLM.Manager
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit -SkipCompile -FromUnit ".\Core\DeepBase.ORM.pas,.\Core\DeepBase.ORM.Mapping.pas"

# �?Git 改动自动映射测试（默认对�?HEAD + 工作区改动）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit -SkipCompile -FromGitChanged
# 指定基线引用
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit -SkipCompile -FromGitChanged -GitRef "origin/main"

# 只运�?Integration Tests
# 默认会排除需要数据库环境的用例分类：DBEnv
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Integration

# 如需启用数据库环境相关的 Integration Tests�?
$env:DeepBase_RUN_DB_INTEGRATION = '1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Integration
Remove-Item Env:DeepBase_RUN_DB_INTEGRATION
```

Integration 默认排除 `DBEnv` 分类；CI 中需要完整数据库集成测试时显式设�?`DeepBase_RUN_DB_INTEGRATION=1`。Runner 需要安�?Delphi/RAD Studio �?FireDAC SQLite 驱动，并能提供与 `-Platform` 匹配�?`sqlite3.dll`，脚本会自动复制�?`Tests\Integration` 后清理�?
可用模块别名可通过 `-ListModules` 查看；`-Module` / `-FromUnit` / `-FromGitChanged` �?`-RunList` 互斥�?

也可以直接用 `dcc32` 编译 runner 并手工运行（不推荐，脚本更省事）�?

```bash
dcc32 Tests/DeepBaseTests.dpr
Tests\DeepBaseTests.exe --exitbehavior:Continue --xmlfile:TestResults\UnitTestResults.xml
```

## 🤝 贡献指南

### 技术约�?

- **线程安全**：使�?`TMonitor`（避�?TCriticalSection�?
- **单元测试**：使�?DUnitX，代码覆盖率 > 85%
- **性能基准**�?
  - Config 读取: < 1ms（缓存命中）
  - i18n 查询: < 0.5ms（缓存命中）
  - 日志写入: 10000 �?< 5s

### 开发流�?

1. Fork 项目
2. 阅读[项目边界文档](docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md)确认功能在边界内
3. 创建特性分�?(`git checkout -b feature/AmazingFeature`)
4. 提交变更 (`git commit -m 'Add some AmazingFeature'`)
5. 推送分�?(`git push origin feature/AmazingFeature`)
6. 提交 Pull Request

### 开发第三方集成

如果你想贡献新的 ThirdParty 扩展（如支付、社交媒体集成）�?

1. 阅读 [ThirdParty 扩展开发指南](docs/06.01.DeepBase-4H-ThirdParty扩展开发指�?v1.1.md)
2. 遵循「统一接口 + 多实�?+ 工厂函数」模�?
3. 参�?`ThirdParty/Cloud/DeepBase.Cloud.Storage.pas` 实现

### 与外部后端平台集�?

DeepBase 保持独立，不强制依赖特定后端。如需对接你的后端 API�?

- 使用 `DeepBase.Net` 调用 HTTP API
- 使用 `DeepBase.Config` 存储 API 配置
- 使用 `DeepBase.Authorization` 管理 Token
- 可选：�?`ThirdParty/` 下创建可复用的适配�?

## 📝 版本历史

- **v1.0.1** (2025-01-27) - 安全加固版本
  - 🔒 **安全修复**: 修复98个安全漏洞和代码质量问题
  - 🏗�?**架构优化**: 拆分Manager类，符合单一职责原则
  - �?**性能提升**: 优化锁机制、缓存策略和内存管理
  - 📋 **常量管理**: 提取硬编码值到DeepBase.Constants统一管理
  - 🧪 **测试覆盖**: 增强边界条件和异常处理测�?
  - 详见 [bugfix.md](bugfix.md)

- **v1.0.0** (2025-12-08) - 正式发布版本
  - Phase 0-7: 全部 81 个任务完�?�?
  - Phase R: 代码重构完成�? 项）
  - Bug 修复: 49+ Bug 已修�?
  - 单元测试: 215+ 测试用例
  - 文档: 完整的集成指南、API 参考、用户手�?
  - 详见 [CHANGELOG.md](CHANGELOG.md)

- **v0.3** (2025-11) - Beta 版本
- **v0.2** (2025-11) - Alpha 版本
- **v0.1** (2025-11) - 初版设计

## 🔒 安全�?

DeepBase v1.0.1 经过全面的安全审计，修复了以下关键安全问题：

- �?**配置加密**: 移除不安全的XOR加密，Secret 使用 DPAPI，LLM API Key 使用 Windows Credential Manager
- �?**插件安全**: 实现插件沙箱和数字签名验�?
- �?**支付安全**: 实现真正的RSA2-SHA256签名算法
- �?**反序列化**: 添加类型白名单验证机�?
- �?**路径安全**: 防止路径遍历攻击
- �?**日志安全**: 防止日志注入攻击
- �?**内存安全**: 修复内存泄漏和悬空指针问�?

详细安全报告请参�?[bugfix.md](bugfix.md)

## 📄 许可�?

MIT License

## 👥 贡献�?

- **盘古** - 系统架构师，架构设计和技术债务管理
- **仙儿** - 安全专家，安全审计和漏洞修复
- **鲁班** - 开发工程师，代码质量和性能优化
- **李冰** - 测试工程师，质量保证和测试覆�?
- **灵儿** - 产品经理，用户体验和功能完整�?

## 🤝 贡献指南

我们欢迎社区贡献！请参考以下指南：

1. **代码规范**: 遵循 [技术规范](docs/03.03.DeepBase-4H-技术规�?v1.0.md)
2. **安全要求**: 所有代码必须通过安全审计
3. **测试要求**: 新功能必须包含单元测�?
4. **文档要求**: 公共API必须有完整文�?

提交PR前请确保�?
- [ ] 代码通过所有测�?
- [ ] 遵循命名规范
- [ ] 包含必要的注�?
- [ ] 更新相关文档

## 🙏 鸣谢

- [Image32](https://github.com/AngusJohnson/Image32) - SVG 渲染�?
- [FireDAC](https://www.embarcadero.com/products/rad-studio/firedac) - 数据库访问框�?
