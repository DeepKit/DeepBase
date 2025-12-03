# UniBase - Delphi 企业级应用开发基础框架

> **让 Delphi 企业级应用开发像 Spring Boot 一样简单**

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

详见：[docs/00_项目定位与开发边界.md](docs/00_项目定位与开发边界.md)

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

- [完整规范](docs/unibase-spec-v0.3.md) - 设计规范和 API 参考
- [任务清单](docs/tasks.md) - 开发任务和进度
- [快速开始](docs/QuickStart.md) - 快速入门指南

## 🧪 运行测试

```bash
# 编译并运行单元测试
dcc32 Tests/UniBaseTests.dpr
UniBaseTests.exe
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
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交变更 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 📝 版本历史

- **v0.3** (2025-12) - 当前版本
  - Phase 0-5: 核心功能已完成（57 个任务）
  - Phase R: 代码重构完成（7 项）
  - Phase 7: 功能补充（单实例、导出、启动画面）
  - Bug 修复: 6 个关键 Bug 已修复

- **v0.2** (2025-11) - 规划阶段
- **v0.1** (2025-11) - 初版设计

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 👥 作者

- **李冰** - Core 核心层开发
- **鲁班** - UI 控件层开发

## 🙏 鸣谢

- [Image32](https://github.com/AngusJohnson/Image32) - SVG 渲染库
- [FireDAC](https://www.embarcadero.com/products/rad-studio/firedac) - 数据库访问框架
