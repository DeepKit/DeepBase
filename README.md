# DeepBase - Delphi 企业级应用开发基础框架

> **�?Delphi 企业级应用开发像 Spring Boot 一样简�?*

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](#-许可�?
[![Delphi](https://img.shields.io/badge/Delphi-10.3%2B-red.svg)](https://www.embarcadero.com/products/delphi)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/DeepBase-framework/DeepBase)
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

## 🚀 快速开�?

### 安装要求

- **Delphi 版本**：Delphi 10.3 Rio 或更�?
- **数据�?*：FireDAC + SQLite（系统自带）
- **单元测试**：DUnitX（可选）

### 1. 安装�?

1. 基础能力：编�?`DeepBaseCore.dpk`
2. 服务/数据�?可选能力按需编译：`DeepBaseServices.dpk`、`DeepBasePersistence.dpk`、`DeepBaseFeatures.dpk`
3. 需�?IDE 拖控件时再安�?VCL/FMX 设计时包：`dclDeepBaseVCL.dpk` / `dclDeepBaseFMX.dpk`

运行时包边界：`DeepBaseCore.dpk` 不直接依�?VCL/FMX/FireDAC；主题切换、全局异常展示�?UI 行为�?`DeepBaseVCL.dpk` / `DeepBaseFMX.dpk` 适配层承接。`DeepBaseFeatures.dpk` 依赖 `DeepBaseServices.dpk`，避免底层服务单元被重复打包�?

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
