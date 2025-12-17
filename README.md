# UniBase - Delphi 企业级应用开发基础框架

> **让 Delphi 企业级应用开发像 Spring Boot 一样简单**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Delphi](https://img.shields.io/badge/Delphi-10.3%2B-red.svg)](https://www.embarcadero.com/products/delphi)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)](https://github.com/unibase-framework/unibase)
[![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)](https://github.com/unibase-framework/unibase/actions)

## 🎯 项目定位

UniBase 是一个 **Delphi 企业级应用开发基础框架**，提供现代化架构模式和常用功能封装：

| 类型 | 功能 |
|------|------|
| 🏗️ **架构模式** | IoC 依赖注入、EventBus 事件总线、MVVM、状态机 |
| 📦 **基础设施** | 配置管理、日志系统、缓存、对象池、工作队列 |
| 💼 **业务功能** | 数据验证、权限授权、国际化、功能开关、ORM |
| 🛡️ **可靠性** | 熔断/重试/超时、限流、定时调度、指标收集 |
| 🛠️ **工具封装** | 集合扩展、日期时间、加密哈希、序列化、模板引擎 |

### 不是什么

- ❌ 游戏/图形引擎
- ❌ 科学计算库
- ❌ 网络协议栈
- ❌ "大而全"的万能框架
- ❌ 强制绑定特定后端平台的中间件

详见：[docs/01.03.uniBase-4H-项目定位与边界-v1.0.md](docs/01.03.uniBase-4H-项目定位与边界-v1.0.md)

## 📦 核心特性

### Phase 0: 最小核心（当前阶段）
- 🗄️ **统一配置管理**：基于 SQLite 的类型安全配置系统
- 🌍 **国际化 (i18n)**：`T()` 函数自动翻译，支持多语言
- 💾 **窗体状态管理**：自动保存/恢复窗体位置、大小
- 🔧 **线程安全**：所有核心 API 均线程安全

### Phase 1-5（已完成）
- 📝 日志系统 - 异步写入、文件轮转、数据库存储
- 📋 MRU（最近使用列表）
- ⌨️ 快捷键管理
- 🎨 主题切换
- 🤖 LLM 集成 - 多模型支持
- 🔄 自动更新
- 🛠️ UniBase Studio（GUI 管理工具）

### Phase 7（功能补充）
- 🔒 单实例检测 - 防止应用多开
- 📄 简单报表导出 - CSV/HTML
- 🌅 启动画面 - 淡入淡出、进度条

### ThirdParty 扩展（可选）
- ☁️ 云存储集成 - AWS S3/Azure Blob/阿里云 OSS
- 💾 数据库驱动 - PostgreSQL/MySQL 适配器
- 🎨 UI 主题 - Material/Fluent/macOS 风格
- 💳 支付集成 - Stripe/PayPal/Alipay（计划中）

## 🚀 快速开始

### 安装要求

- **Delphi 版本**：Delphi 10.3 Rio 或更高
- **数据库**：FireDAC + SQLite（系统自带）
- **单元测试**：DUnitX（可选）

### 第一步：安装包

1. 打开 `UniBaseCore.dpk`
2. 编译并安装设计时包 `dclUniBaseCore.dpk`

### 第二步：初始化 UniBase

```delphi
program MyApp;

uses
  UniBase.Manager;

begin
  Application.Initialize;
  
  // 初始化 UniBase
  if not UniBase.Initialize then
  begin
    ShowMessage('Failed to initialize UniBase');
    Exit;
  end;
  
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
  
  // 清理资源
  UniBase.Finalize;
end.
```

### 第三步：使用核心功能

```delphi
// 读写配置
UniBase.SetConfig('App.Username', 'admin');
var username := UniBase.GetConfig('App.Username');

// 国际化
Caption := T('Welcome');  // 自动翻译为当前语言
ShowMessage(TFmt('Hello, %s!', [username]));

// 窗体状态自动保存
UniBase.SaveFormState(Self);   // 窗体关闭时调用
UniBase.RestoreFormState(Self); // 窗体创建时调用
```

### 单实例检测

```delphi
uses UniBase.SingleInstance;

// 在 DPR 文件中，Application.Initialize 之前调用
if not TAppInstance.CheckSingleInstance('MyCompany.MyApp') then
begin
  TAppInstance.ActivateExistingInstance; // 激活已运行的实例
  Exit;
end;
```

### 数据导出

```delphi
uses UniBase.Export;

// 导出 DataSet 到 CSV
TDataExport.ToCSV(MyDataSet, 'output.csv');

// 导出 DataSet 到 HTML（带样式）
TDataExport.ToHTML(MyDataSet, 'report.html', '报表标题');

// 导出 StringGrid
TDataExport.ToCSV(StringGrid1, 'grid.csv');
```

### 启动画面

```delphi
uses UniBase.SplashScreen;

// 显示启动画面
TSplashScreen.Show('splash.png');
TSplashScreen.SetStatus('正在加载配置...');
TSplashScreen.SetProgress(30);

// ... 初始化操作 ...

TSplashScreen.SetStatus('初始化完成');
TSplashScreen.SetProgress(100);
TSplashScreen.Hide; // 淡出关闭
```

## 📁 项目结构

```
UniBase/
├── Core/                    # 核心库（无 UI 依赖）
│   ├── UniBase.Manager.pas
│   ├── UniBase.Config.pas
│   ├── UniBase.i18n.pas
│   └── UniBase.Types.pas
├── VCL/                     # VCL 控件包
├── FMX/                     # FMX 控件包
├── Tests/                   # 单元测试
├── Examples/                # 示例工程
├── sql/                     # 数据库脚本
└── docs/                    # 文档

```

## 📖 文档

- [完整规范](docs/03.03.uniBase-4H-技术规范-v1.0.md) - 设计规范和 API 参考
- [集成指南](docs/01.01.uniBase-4AI-集成指南-v1.0.md) - AI/外部程序集成入口
- [文档索引](docs/00.00.uniBase-文档索引-v1.0.md) - 全部文档导航
- [项目边界](docs/01.03.uniBase-4H-项目定位与边界-v1.0.md) - 什么能做/不能做
- [扩展开发](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md) - 开发第三方集成

## 🧪 运行测试

推荐使用一键脚本（会自动编译 + 运行，并输出 NUnit XML 到 `TestResults/`）：

```powershell
# 运行全部（Unit + Integration）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type All

# 只运行 Unit Tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Unit

# 只运行 Integration Tests
# 默认会排除需要数据库环境的用例分类：DBEnv
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Integration

# 如需启用数据库环境相关的 Integration Tests：
$env:UNIBASE_RUN_DB_INTEGRATION = '1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\run_tests.ps1" -Type Integration
Remove-Item Env:UNIBASE_RUN_DB_INTEGRATION
```

也可以直接用 `dcc32` 编译 runner 并手工运行（不推荐，脚本更省事）：

```bash
dcc32 Tests/UniBaseTests.dpr
Tests\UniBaseTests.exe --exitbehavior:Continue --xmlfile:TestResults\UnitTestResults.xml
```

## 🤝 贡献指南

### 技术约定

- **线程安全**：使用 `TMonitor`（避免 TCriticalSection）
- **单元测试**：使用 DUnitX，代码覆盖率 > 85%
- **性能基准**：
  - Config 读取: < 1ms（缓存命中）
  - i18n 查询: < 0.5ms（缓存命中）
  - 日志写入: 10000 条 < 5s

### 开发流程

1. Fork 项目
2. 阅读[项目边界文档](docs/01.03.uniBase-4H-项目定位与边界-v1.0.md)确认功能在边界内
3. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
4. 提交变更 (`git commit -m 'Add some AmazingFeature'`)
5. 推送分支 (`git push origin feature/AmazingFeature`)
6. 提交 Pull Request

### 开发第三方集成

如果你想贡献新的 ThirdParty 扩展（如支付、社交媒体集成）：

1. 阅读 [ThirdParty 扩展开发指南](docs/06.01.uniBase-4H-ThirdParty扩展开发指南-v1.0.md)
2. 遵循「统一接口 + 多实现 + 工厂函数」模式
3. 参考 `ThirdParty/Cloud/UniBase.Cloud.Storage.pas` 实现

### 与外部后端平台集成

UniBase 保持独立，不强制依赖特定后端。如需对接你的后端 API：

- 使用 `UniBase.Net` 调用 HTTP API
- 使用 `UniBase.Config` 存储 API 配置
- 使用 `UniBase.Authorization` 管理 Token
- 可选：在 `ThirdParty/` 下创建可复用的适配器

## 📝 版本历史

- **v1.0.1** (2025-01-27) - 安全加固版本
  - 🔒 **安全修复**: 修复98个安全漏洞和代码质量问题
  - 🏗️ **架构优化**: 拆分Manager类，符合单一职责原则
  - ⚡ **性能提升**: 优化锁机制、缓存策略和内存管理
  - 📋 **常量管理**: 提取硬编码值到UniBase.Constants统一管理
  - 🧪 **测试覆盖**: 增强边界条件和异常处理测试
  - 详见 [docs/bugFixed.md](docs/bugFixed.md)

- **v1.0.0** (2025-12-08) - 正式发布版本
  - Phase 0-7: 全部 81 个任务完成 ✅
  - Phase R: 代码重构完成（7 项）
  - Bug 修复: 49+ Bug 已修复
  - 单元测试: 215+ 测试用例
  - 文档: 完整的集成指南、API 参考、用户手册
  - 详见 [CHANGELOG.md](CHANGELOG.md)

- **v0.3** (2025-11) - Beta 版本
- **v0.2** (2025-11) - Alpha 版本
- **v0.1** (2025-11) - 初版设计

## 🔒 安全性

UniBase v1.0.1 经过全面的安全审计，修复了以下关键安全问题：

- ✅ **配置加密**: 移除不安全的XOR加密，强制使用DPAPI
- ✅ **插件安全**: 实现插件沙箱和数字签名验证
- ✅ **支付安全**: 实现真正的RSA2-SHA256签名算法
- ✅ **反序列化**: 添加类型白名单验证机制
- ✅ **路径安全**: 防止路径遍历攻击
- ✅ **日志安全**: 防止日志注入攻击
- ✅ **内存安全**: 修复内存泄漏和悬空指针问题

详细安全报告请参考 [docs/bugFixed.md](docs/bugFixed.md)

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 👥 贡献者

- **盘古** - 系统架构师，架构设计和技术债务管理
- **仙儿** - 安全专家，安全审计和漏洞修复
- **鲁班** - 开发工程师，代码质量和性能优化
- **李冰** - 测试工程师，质量保证和测试覆盖
- **灵儿** - 产品经理，用户体验和功能完整性

## 🤝 贡献指南

我们欢迎社区贡献！请参考以下指南：

1. **代码规范**: 遵循 [docs/coding-standards.md](docs/coding-standards.md)
2. **安全要求**: 所有代码必须通过安全审计
3. **测试要求**: 新功能必须包含单元测试
4. **文档要求**: 公共API必须有完整文档

提交PR前请确保：
- [ ] 代码通过所有测试
- [ ] 遵循命名规范
- [ ] 包含必要的注释
- [ ] 更新相关文档

## 🙏 鸣谢

- [Image32](https://github.com/AngusJohnson/Image32) - SVG 渲染库
- [FireDAC](https://www.embarcadero.com/products/rad-studio/firedac) - 数据库访问框架
