# UniBase - Delphi 应用基础设施框架

> **开箱即用的基础设施层**，为 Delphi 应用提供配置管理、国际化、日志记录等统一解决方案。

## 🎯 设计目标

UniBase 旨在解决 Delphi 开发中的常见痛点：

- ✅ 配置文件散乱（INI、Registry、XML 混用）
- ✅ 国际化困难（硬编码中文、乱码问题）
- ✅ 日志无统一规范
- ✅ 窗体状态保存重复实现
- ✅ 异常处理不一致
- ✅ 缺乏自动更新机制

## 📦 核心特性

### Phase 0: 最小核心（当前阶段）
- 🗄️ **统一配置管理**：基于 SQLite 的类型安全配置系统
- 🌍 **国际化 (i18n)**：`T()` 函数自动翻译，支持多语言
- 💾 **窗体状态管理**：自动保存/恢复窗体位置、大小
- 🔧 **线程安全**：所有核心 API 均线程安全

### Phase 1-4（规划中）
- 📝 日志系统
- 📋 MRU（最近使用列表）
- ⌨️ 快捷键管理
- 🎨 主题切换
- 🤖 LLM 集成
- 🔄 自动更新
- 🛠️ UniBase Studio（GUI 管理工具）

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
- [快速开始](docs/QuickStart.md) - 快速入门指南（待完成）

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

- **v0.3** (2025-11) - 当前开发版本
  - Phase 0: 最小核心实现中
  - 配置管理、i18n、FormState

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
