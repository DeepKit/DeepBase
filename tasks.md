# UniBase 开发任务文档导航

> 📋 **重要**: 所有 Phase 0~5 任务已 ✅ 100% 完成！
> 请参考以下文档了解项目现状和后续规划

---

## 📖 文档导航

### 项目现状
- **[history.md](history.md)** - 已完成的全部 57 个任务详细记录
- **[bugfix.md](bugfix.md)** - 修复的 22 个 Bug 和 4 个待处理 Issue
- **[tasks_next.md](tasks_next.md)** - 后续扩展任务规划

### 项目规划
- **[tasks_next.md](tasks_next.md)** - 后续开发任务

### 原始规范（仅供参考）
- **[unibase-spec-v0.3.md](unibase-spec-v0.3.md)** - 框架设计规范
- **[README.md](README.md)** - 项目说明

---

## ✅ 完成情况统计

| 阶段 | 任务数 | 状态 | 负责人 |
|------|--------|------|-------|
| Phase 0 | 8 | ✅ 完成 | 李冰、鲁班 |
| Phase 1 | 9 | ✅ 完成 | 李冰、鲁班 |
| Phase T | 8 | ✅ 完成 | 李冰、鲁班 |
| Phase 2 | 9 | ✅ 完成 | 李冰、鲁班 |
| Phase 3 | 7 | ✅ 完成 | 李冰、鲁班 |
| Phase 4 | 7 | ✅ 完成 | 李冰、鲁班 |
| Phase 5 | 9 | ✅ 完成 | Claude |
| **总计** | **57** | **✅ 100%** | - |

---

## 🚀 后续工作

已规划 **38 个**后续任务，分为以下类别：

- **维护与文档** (4) - API 文档、测试覆盖率、示例工程
- **功能优化** (6) - Plugin、DataBinding、MVVM、ORM、IoC、日志分析
- **平台扩展** (3) - FMX 跨平台、Web API、CLI 优化
- **云端集成** (3) - 配置同步、备份恢复、反馈收集
- **性能优化** (3) - 连接池、内存管理、UI 渲染
- **安全增强** (3) - 数据加密、权限管理、安全更新
- **国际化增强** (2) - 复数形式、性别变体
- **工具完善** (3) - Studio、Tray、CLI 进阶
- **测试与质量** (3) - 集成测试、GUI 自动化、压力测试
- **文档与培训** (3) - 开发者文档、用户手册、最佳实践
- **社区与生态** (2) - 示例库、扩展包

**总估算工时**: 880-1275 小时

---

## 📝 快速开始

### 项目结构
```
UniBase/
├── Core/                 # 核心模块（15 个）
├── VCL/                  # VCL 控件（14 个）
├── FMX/                  # FMX 控件（4 个）
├── Tools/                # 开发工具
│   ├── Studio/           # UniBase Studio
│   ├── Tray/             # Tray 工作台
│   └── CLI/              # 命令行工具
├── Examples/             # 示例工程
├── Tests/                # 单元测试
├── sql/                  # 数据库脚本
└── docs/                 # 文档
```

### 已完成功能

✅ **Core 模块**
- 框架管理 (Manager)
- 配置系统 (Config)
- 国际化 (i18n)
- 日志系统 (Logging)
- 最近使用 (MRU)
- 快捷键 (Hotkeys)
- 主题管理 (Theme)
- 窗体状态 (FormState)
- LLM 集成
- 异常处理
- 自动更新
- 远程配置
- License 管理
- GUI 测试辅助

✅ **VCL 控件**
- 配置控件 (TConfigEdit, TConfigCheckBox, 等)
- i18n 控件 (TI18nLabel, TI18nButton)
- MRU 控件 (TMRUPopupMenu, TMRUComboBox)
- 快速启动 (TLanguageComboBox, TThemeComboBox)
- 窗体状态辅助 (TFormStateHelper)
- 日志查看器 (TLogListView)
- LLM 配置面板 (TLLMConfigPanel)
- 等待窗体 (TWaitForm)
- 通知栏 (TNotificationBar)
- 自动更新器 (TAutoUpdater, TUpdateDialog)
- 数据库初始化向导 (TDBInitWizard)
- License 面板 (TLicenseStatusPanel, TLicenseAuthDialog)
- 反馈对话框 (TFeedbackDialog)

✅ **工具**
- UniBase Studio - 项目管理工具
- Tray 工作台 - 开发辅助工具
- CLI 工具 - 命令行管理工具

✅ **示例**
- Phase0Demo - 最小核心演示
- Phase1Demo - VCL 控件演示

---

## 📌 关键日期

- **2025-11-26**: Phase 0~1 完成
- **2025-11-27**: Phase T, 2, 3, 4 完成
- **2025-11-28**: Phase 5 代码审查优化完成（9 项改进，2 个 Bug 修复）
- **2025-11-29**: 扩展功能持续开发（CLI Pipeline、SSH、GUI测试、压力测试）
- **2025-11-30**: 平台扩展、云端集成、性能优化完成
- **2025-12-01**: Phase R 重构 + Bug 修复 + Phase 7 功能补充
- **后续**: 维护和优化阶段

---

## 🔗 相关资源

- [GitHub Repository](#) (待发布)
- [官方文档](#) (待发布)
- [示例代码库](#) (待发布)

---

## 🔧 核心维护任务（2025-12-01 Code Review）

### 📌 Bug 修复（6项） ✅ 全部已修复

#### 1. [BUG] Logging.GetLogCount 类型不匹配 ✅
**描述**: `WriteToDB` 存储 `LogLevel` 为 TEXT 类型，但 `GetLogCount` 使用 INTEGER 查询
**影响**: `GetLogCount` 永远返回 0
**修复**: 改为使用 `Logs.LogLevel` 字段和 AsString 参数绑定

#### 2. [BUG] 全局 Logger 双重释放风险 ✅
**描述**: Manager 与 Logging 单元都可能释放 GLogger，导致 AV
**影响**: 应用退出时可能崩溃
**修复**: Manager 释放前先调用 SetGlobalLogger(nil)，明确所有权

#### 3. [BUG] TConfigurationSection.GetKey 索引错误 ✅
**描述**: 硬编码 `LPos + 2` 假设单字符分隔符
**影响**: 多字符分隔符时解析出错
**修复**: 使用 `LPos + Length(FConfig.KeyDelimiter)` 动态计算

#### 4. [BUG] TConfiguration.WatchFiles 忽略参数 ✅
**描述**: `StartWatching(AIntervalMs)` 参数未被使用
**影响**: 无法动态配置轮询间隔
**修复**: 添加 `FWatchIntervalMs` 字段并在 Sleep 中使用

#### 5. [BUG] Configuration 回调列表并发不安全 ✅
**描述**: `OnChanged` 和 `NotifyChange` 未加锁
**影响**: 多线程注册回调或 Reload 时可能崩溃
**修复**: 在 `FCallbacksLock` 保护下操作 `FChangeCallbacks`

#### 6. [DESIGN] Manager 重复声明接口 ✅
**描述**: `UniBase.Manager` 重复定义 `IUniBaseConfig/IUniBaseI18n`（GUID 相同）
**影响**: 类型混淆、无法互换使用
**修复**: 删除本地声明，使用 `UniBase.Interfaces` 中的定义

### 🚀 增强功能（待规划）
- [ ] IoC 容器支持循环依赖检测
- [ ] ORM 默认值 SQL 拼接增强（类型化）
- [ ] Configuration 支持加密配置源
- [ ] Logging 支持结构化日志（JSON格式）

---

## 🔄 Phase R: 代码重构任务 (2025-12-01)

> **约束**: 所有重构必须保持对外接口不变，确保已集成 UniBase 的软件无需修改

### R-001: 拆分 TUniBaseManager.InitializeEx 方法 ✅
- **文件**: `Core/UniBase.Manager.pas:331-457`
- **问题**: 方法约120行，逻辑过于集中
- **任务**:
  - [x] 提取 `DoFindRootPath` 私有方法
  - [x] 提取 `DoLocateConfigDB` 私有方法  
  - [x] 提取 `DoConnectAndValidate` 私有方法
  - [x] 保持 `InitializeEx` 公开签名不变
- **状态**: ✅ 已完成

### R-002: 消除 SetConfig* 方法重复代码 ✅
- **文件**: `Core/UniBase.Config.pas`
- **问题**: SetConfigInt/Bool/Float 逻辑高度相似
- **任务**:
  - [x] 提取 `SetConfigInternal` 公共私有方法
  - [x] 保持公开方法签名不变
- **状态**: ✅ 已完成

### R-003: 优化 Logging 双重锁模式 ✅
- **文件**: `Core/UniBase.Logging.pas:303-342`
- **问题**: 同一方法两次加锁/解锁
- **任务**:
  - [x] 合并批处理后的状态检查
- **状态**: ✅ 已完成

### R-004: 消除 Schema 验证魔法数字 ✅
- **文件**: `Core/UniBase.Manager.pas:824`
- **问题**: Schema 验证使用硬编码 `6`
- **任务**:
  - [x] 定义 `REQUIRED_CORE_TABLES` 常量数组
  - [x] 动态计算所需表数量
- **状态**: ✅ 已完成

### R-005: 修复测试编译错误 ✅
- **文件**: `Tests/Test.UniBase.Config.pas:241-267`
- **问题**: 引用不存在的方法
- **任务**:
  - [x] 修改为使用正确的 `GetConfigsByCategory`
- **状态**: ✅ 已完成

### R-006: 改进空 except 块处理 ✅
- **文件**: 多处
- **问题**: 空 except 块吞掉异常
- **任务**:
  - [x] 添加 `{$IFDEF DEBUG}` 调试输出
- **状态**: ✅ 已完成

### R-007: 明确 SetEventBus 所有权语义 ✅
- **文件**: `Core/UniBase.EventBus.pas:296-308`
- **任务**:
  - [x] 添加详细注释说明所有权转移
- **状态**: ✅ 已完成

### Phase R 重构统计

| 任务编号 | 任务名称 | 影响范围 | 状态 |
|----------|----------|----------|------|
| R-001 | 拆分 InitializeEx | 内部 | ✅ |
| R-002 | 消除 SetConfig 重复 | 内部 | ✅ |
| R-003 | 优化 Logging 锁 | 内部 | ✅ |
| R-004 | 消除魔法数字 | 内部 | ✅ |
| R-005 | 修复测试编译 | 测试 | ✅ |
| R-006 | 改进异常处理 | 内部 | ✅ |
| R-007 | 明确所有权语义 | 文档 | ✅ |

---

## 📦 Phase 7: 功能补充 (2025-12-01)

> 状态: ✅ 已完成

### P7-001: 单实例检测 (UniBase.SingleInstance) ✅
- **优先级**: P0
- **预计工时**: 2-3 小时
- **输出物**: `Core/UniBase.SingleInstance.pas`
- **功能**:
  - 使用 Mutex 防止应用多开
  - 支持激活已运行实例（将窗口置前）
  - 支持传递命令行参数给已运行实例
  - 可配置是否允许多实例
- **用法示例**:
```pascal
if not TAppInstance.CheckSingleInstance('MyAppName') then
begin
  TAppInstance.ActivateExistingInstance;
  Application.Terminate;
  Exit;
end;
```

### P7-002: 简单报表导出 (UniBase.Export) ✅
- **优先级**: P1
- **预计工时**: 3-4 小时
- **输出物**: `Core/UniBase.Export.pas`
- **功能**:
  - CSV 导出（支持自定义分隔符、编码）
  - HTML 表格导出（带基本样式）
  - 支持从 TDataSet/TStringGrid/数组导出
  - 支持列标题、列宽度配置
- **用法示例**:
```pascal
TDataExport.ToCSV(DataSet, 'output.csv');
TDataExport.ToHTML(DataSet, 'report.html', '报表标题');
```

### P7-003: 启动画面 (UniBase.SplashScreen) ✅
- **优先级**: P1
- **预计工时**: 3-4 小时
- **输出物**: `Core/UniBase.SplashScreen.pas`
- **功能**:
  - 支持图片显示（PNG/JPG/BMP）
  - 可选进度条
  - 可选状态文本
  - 淡入淡出动画
  - 自动关闭或手动关闭
- **用法示例**:
```pascal
TSplashScreen.Show('splash.png');
TSplashScreen.SetStatus('正在加载配置...');
TSplashScreen.SetProgress(50);
// ... 初始化完成
TSplashScreen.Hide;
```

---

## 🤖 Phase 6: LLM 提示词管理系统 (2025-12-01)

> 状态: 🟡 设计完成，待开发

### P6-001: 创建提示词数据库表结构 ⭕
- **优先级**: P0
- **依赖**: P0-002
- **预计工时**: 4-6 小时
- **输出物**:
  - `sql/llm_prompts_init.sql`
- **任务内容**:
  1. PromptCategories 提示词分类表 (4级分类)
  2. Prompts 提示词主表 (InternalCode, BoundQueryName, VariablesJson)
  3. PromptVersions 提示词版本表 (最多4个版本)
  4. PromptMeta 元提示词表 (MergeMode: PREFIX/SUFFIX/WRAP)
  5. PromptMetaBinding 提示词-元提示词绑定表
  6. LLMConfigurations 更新字段 (IsDefault)
  7. LLMCalls 更新字段 (PromptId, VersionNumber)
- **验收标准**:
  - 脚本可在现有数据库上成功执行
  - 所有索引和约束正确创建

---

### P6-002: 实现 TLLMManager 核心类 ⭕
- **优先级**: P0
- **依赖**: P6-001
- **预计工时**: 15-20 小时
- **输出物**:
  - `Core/UniBase.LLM.Manager.pas`
  - `Core/UniBase.LLM.Types.pas`
  - `Core/UniBase.LLM.ContextBuilder.pas`
- **任务内容**:
  1. Execute(提示词Code, Params, Version, LLMConfig) 主调用方法
  2. ExecuteAsync 异步调用
  3. TContextBuilder.BuildContext(BoundQueryName, Params) 上下文构建
  4. TContextBuilder.BuildFinalPrompt 合并元提示词
  5. TPromptVersionStrategy 版本选择策略 (Production/Latest/Specific/ABTest)
  6. TLLMResponse 响应结构 (Content, Tokens, Cost, Status)
- **验收标准**:
  - 单元测试：变量替换正确
  - 单元测试：元提示词合并正确
  - 单元测试：BoundQuery 数据注入正确

---

### P6-003: 实现提示词调试窗口 ✅
- **优先级**: P1
- **依赖**: P6-002
- **预计工时**: 20-25 小时
- **输出物**:
  - `Tools/Studio/Forms/Studio.PromptDebugForm.pas`
- **任务内容**:
  1. 左侧上部: 4级分类树 (TTreeView)
  2. 左侧下部: 当前分类下提示词列表 (TListBox)
  3. 右侧属性区: 版本选择、描述编辑框、变量网格
  4. 右侧内容区: 提示词编辑框 + 发送按钮
  5. 右侧回复区: LLM回复显示 (Token/费用/耗时)
  6. BoundQuery 选择 + SQL预览
- **验收标准**:
  - 集成测试：发送按钮正常工作
  - 集成测试：回复实时显示
- **UI设计**: `docs/ui/svg/components/LLM_PromptDebugWindow.svg`

---

### P6-004: 实现提示词版本对比窗口 ✅
- **优先级**: P1
- **依赖**: P6-003
- **预计工时**: 15-20 小时
- **输出物**:
  - `Tools/Studio/Forms/Studio.PromptVersionCompareForm.pas`
- **任务内容**:
  1. 四栏平铺布局 (V1/V2/V3/V4)
  2. 每栏上部: 合成提示词显示
  3. 每栏下部: LLM回复显示
  4. 差异高亮 (新增/删除/修改)
  5. 统计信息 (Tokens/成功率/平均耗时)
  6. 弹出大窗按钮 (⇱) 查看/编辑单个版本
  7. “设为生产版本”、“复制到V4”、“重新测试”按钮
- **验收标准**:
  - 集成测试：四个版本同时显示
  - 集成测试：差异高亮正确
- **UI设计**: `docs/ui/svg/components/LLM_PromptVersionCompare.svg`

---

### P6-005: 实现 LLM 配置调试窗口 ✅
- **优先级**: P1
- **依赖**: P6-002
- **预计工时**: 12-15 小时
- **输出物**:
  - `Tools/Studio/Forms/Studio.LLMConfigForm.pas`
- **任务内容**:
  1. 上左: LLM属性编辑 (Provider/Model/APIKey/Temperature等)
  2. 上右: 测试连接区 + 回复显示
  3. 下部: 所有LLM配置列表 (Grid)
  4. 状态指示 (正常/离线/未测试)
  5. 统计信息 (调用次数/成功率/今日费用)
- **验收标准**:
  - 集成测试：测试连接正常工作
- **UI设计**: `docs/ui/svg/components/LLM_ConfigDebugWindow.svg`

---

### P6-006: 实现自绘变量网格控件 ✅
- **优先级**: P2
- **依赖**: P6-003
- **预计工时**: 10-12 小时
- **输出物**:
  - `VCL/UniBase.VCL.PromptVariableGrid.pas`
- **任务内容**:
  1. TDrawGrid 自绘实现
  2. 支持 7 种变量类型: String/Integer/Float/Boolean/Enum/JSON/BoundQuery
  3. 每种类型对应不同编辑器 (SpinEdit/CheckBox/ComboBox等)
  4. 添加/删除变量行
- **验收标准**:
  - 集成测试：变量编辑正常工作

---

### P6-007: 实现提示词导入导出 ✅
- **优先级**: P2
- **依赖**: P6-002
- **预计工时**: 8-10 小时
- **输出物**:
  - `Core/UniBase.LLM.ImportExport.pas`
- **任务内容**:
  1. ExportPrompts(FilePath, Format) 导出 (JSON/YAML)
  2. ImportPrompts(FilePath, Mode) 导入 (Merge/Replace)
  3. 包含元提示词和绑定关系
- **验收标准**:
  - 单元测试：导出后重新导入数据一致
- **文档**: `docs/12_LLM提示词集成指南.md`

---

### P6-008: 实现版本详情弹出窗口 ✅
- **优先级**: P2
- **依赖**: P6-004
- **预计工时**: 6-8 小时
- **输出物**:
  - `Tools/Studio/Forms/Studio.VersionDetailForm.pas`
- **任务内容**:
  1. 大窗显示单个版本详情
  2. 提示词内容编辑
  3. 最近LLM回复显示
  4. “重新测试”、“另存为新版本”按钮
- **UI设计**: `docs/ui/svg/components/LLM_VersionDetailPopup.svg`

---

### Phase 6 任务统计

| 任务编号 | 任务名称 | 优先级 | 预计工时 | 状态 |
|----------|----------|--------|----------|------|
| P6-001 | 数据库表结构 | P0 | 4-6h | ✅ |
| P6-002 | TLLMManager核心类 | P0 | 15-20h | ✅ |
| P6-003 | 提示词调试窗口 | P1 | 20-25h | ✅ |
| P6-004 | 版本对比窗口 | P1 | 15-20h | ✅ |
| P6-005 | LLM配置窗口 | P1 | 12-15h | ✅ |
| P6-006 | 自绘变量网格 | P2 | 10-12h | ✅ |
| P6-007 | 导入导出 | P2 | 8-10h | ✅ |
| P6-008 | 版本详情弹窗 | P2 | 6-8h | ✅ |
| **总计** | | | **90-116h** | |

### 已完成设计文档
- ✅ `docs/ui/svg/components/LLM_PromptDebugWindow.svg` - 提示词调试窗口
- ✅ `docs/ui/svg/components/LLM_PromptVersionCompare.svg` - 版本对比窗口
- ✅ `docs/ui/svg/components/LLM_ConfigDebugWindow.svg` - LLM配置窗口
- ✅ `docs/ui/svg/components/LLM_VersionDetailPopup.svg` - 版本详情弹窗
- ✅ `docs/12_LLM提示词集成指南.md` - 集成指南

### 已完成代码
- ✅ `sql/llm_prompts_init.sql` - LLM提示词数据库表结构 (P6-001)
- ✅ `Core/UniBase.LLM.Manager.pas` - TLLMManager核心类 (P6-002)
- ✅ `Tools/Studio/Forms/Studio.PromptDebugForm.pas` - 提示词调试窗口 (P6-003)
- ✅ `Tools/Studio/Forms/Studio.PromptVersionCompareForm.pas` - 版本对比窗口 (P6-004)
- ✅ `Tools/Studio/Forms/Studio.LLMConfigForm.pas` - LLM配置窗口 (P6-005)
- ✅ `VCL/UniBase.VCL.PromptVariableGrid.pas` - 自绘变量网格控件 (P6-006)
- ✅ `Core/UniBase.LLM.ImportExport.pas` - 提示词导入导出模块 (P6-007)
- ✅ `Tools/Studio/Forms/Studio.VersionDetailForm.pas` - 版本详情弹窗 (P6-008)

---

**最后更新**: 2025-12-01  
**维护者**: 李冰、鲁班、Claude  
**项目状态**: ✅ MVP 完成，进入维护和优化阶段

### 开发环境要求
- **Delphi 版本**: Delphi 10.3 Rio 或更高
- **数据库**: FireDAC + SQLite (系统自带)
- **单元测试**: DUnitX
- **版本控制**: Git + Git Submodules (用于 Image32)

### 线程安全策略
- 统一使用 `TMonitor` 进行同步（避免使用 TCriticalSection）
- 读多写少场景考虑使用 `TMultiReadExclusiveWriteSynchronizer`

### Schema 迁移规范
- 升级脚本命名：`sql/upgrade_v{old}_to_v{new}.sql`
- 例如：`sql/upgrade_v0.1_to_v0.2.sql`

### 性能基准
- Config 读取: < 1ms (内存缓存)
- Config 写入: < 10ms (批量提交)
- 日志写入: 10000 条 < 5s (异步队列)
- i18n 查询: < 0.5ms (内存缓存)
- MRU 查询: < 5ms (索引优化)

---

## 目录

1. [Phase 0: 最小核心 (Minimum Viable Core)](#phase-0-最小核心)
2. [Phase T: UniBaseTray 工作台](#phase-t-unibasetray-工作台) ← **独立模块，并行开发**
3. [Phase 1: 推荐功能 (Recommended Features)](#phase-1-推荐功能)
4. [Phase 2: 扩展功能 (Extended Features)](#phase-2-扩展功能)
5. [Phase 3: 高级功能 (Advanced Features)](#phase-3-高级功能)
6. [Phase 4: 完善与文档 (Polish & Documentation)](#phase-4-完善与文档)

---

## Phase 0: 最小核心

**目标**: 实现 Tier 0 表结构和对应的最小 Core API，使框架可以被其他项目引用。

### P0-001: 创建项目结构和包配置 ✅

- **优先级**: P0 (最高)
- **依赖**: 无
- **输出物**:
  - 项目目录结构（Core/VCL/FMX/Tests/Tools/ThirdParty）
  - `.gitignore` 和 `.gitmodules` 配置
  - `UniBaseCore.dpk` 运行时包
  - `dclUniBaseCore.dpk` 设计时包（暂时为空）
  - `README.md` 项目说明
- **验收标准**:
  - 包可在 Delphi IDE 中成功编译
  - Git 仓库结构清晰

---

### P0-002: 创建 Tier 0 数据库 Schema 脚本 ✅

- **优先级**: P0
- **依赖**: P0-001
- **输出物**:
  - `sql/tier0_init.sql`: 包含 `SchemaInfo`, `ProjectInfo`, `Settings`, `FormStates`, `Languages`, `I18nTexts` 六张表的 DDL
  - 预置数据（默认语言、默认 Schema 版本）
  - `sql/README.md`: Schema 设计说明
- **验收标准**:
  - 脚本可在空 SQLite 数据库上成功执行
  - 所有索引和约束正确创建
  - 预置数据完整

---

### P0-003: 实现 TUniBaseManager 核心框架 ✅

- **优先级**: P0
- **依赖**: P0-002
- **输出物**:
  - `Core/UniBase.Manager.pas`
  - `Core/UniBase.Types.pas`
  - `Tests/Test.UniBase.Manager.pas`
- **任务细节**:
  1. 实现 `Initialize` / `InitializeEx` / `InitializeWithDB` 方法
  2. 实现 `Finalize` 方法
  3. 实现 `RootPath` 检测逻辑（EXE 目录 -> APPDATA 回退）
  4. 实现 `FInitErrorCode` 错误码机制
  5. 实现全局单例 `function UniBase: TUniBaseManager;`
  6. 实现健康检查 `HealthCheck` 方法
  7. **同步编写单元测试**（TDD 方式）
- **验收标准**:
  - 单元测试：使用 `:memory:` 数据库成功初始化
  - 单元测试：`root.txt` 缺失时，能正确创建并写入
  - 单元测试：所有错误码场景覆盖
  - 代码覆盖率 > 85%

---

### P0-004: 实现 Config 模块 ✅

- **优先级**: P0
- **依赖**: P0-003
- **输出物**:
  - `Core/UniBase.Config.pas`
  - `Tests/Test.UniBase.Config.pas`
- **任务细节**:
  1. 实现 `GetConfig` / `SetConfig` (String)
  2. 实现 `GetConfigInt` / `SetConfigInt`
  3. 实现 `GetConfigBool` / `SetConfigBool`
  4. 实现 `GetConfigFloat` / `SetConfigFloat`
  5. 实现 `OnConfigChanged` 事件通知
  6. 实现内存缓存机制（减少数据库查询）
  7. 使用 `TMonitor` 确保线程安全
  8. **同步编写单元测试**
- **验收标准**:
  - 单元测试：读写各类型配置值正确
  - 单元测试：类型转换失败时返回默认值并记录警告
  - 单元测试：多线程并发读写无死锁和数据损坏（100 线程 x 1000 次）
  - 性能测试：缓存命中时 < 1ms，未命中时 < 10ms

---

### P0-005: 实现 i18n 模块（基础） ✅

- **优先级**: P0
- **依赖**: P0-003
- **输出物**:
  - `Core/UniBase.i18n.pas`
  - `Tests/Test.UniBase.i18n.pas`
- **任务细节**:
  1. 实现 `T(const Text: string): string` 函数
  2. 实现 `TFmt(const Text: string; const Args: array of const): string`
  3. 实现 `CurrentLanguage` 属性的 Getter/Setter
  4. 实现 `OnLanguageChanged` 事件通知
  5. 实现 `GetAvailableLanguages` 方法
  6. 实现翻译缓存机制（LRU Cache，容量 10000）
  7. 使用 `TMonitor` 确保线程安全
  8. **同步编写单元测试**
- **验收标准**:
  - 单元测试：已翻译文本返回正确翻译
  - 单元测试：未翻译文本返回原文（并记录到日志）
  - 单元测试：切换语言后缓存正确失效
  - 性能测试：缓存命中时 < 0.5ms

---

### P0-006: 实现 FormState 模块 ✅

- **优先级**: P0
- **依赖**: P0-003
- **负责人**: Claude
- **输出物**:
  - `Core/UniBase.FormState.pas`（或直接在 Manager 中实现）
  - `Tests/Test.UniBase.FormState.pas`
- **任务细节**:
  1. 实现 `SaveFormState(AForm: TForm)`
  2. 实现 `RestoreFormState(AForm: TForm)`
  3. 处理多显示器边界检查（窗体不能恢复到屏幕外）
  4. 支持 `WindowState` (Normal/Minimized/Maximized)
  5. 支持 Extra 字段（JSON 格式，用于自定义状态）
  6. **同步编写单元测试**
- **验收标准**:
  - 单元测试：保存后重新加载，窗体位置恢复正确
  - 单元测试：模拟显示器断开，窗体自动调整到主屏幕
  - 单元测试：Extra 字段 JSON 序列化正确

---

### P0-007: 创建 Phase 0 示例工程

- **优先级**: P0
- **依赖**: P0-001 ~ P0-006
- **负责人**: 鲁班
- **输出物**:
  - `Examples/Phase0Demo/Phase0Demo.dproj`
  - `Examples/Phase0Demo/MainForm.pas`
  - `Examples/Phase0Demo/README.md`
  - `Examples/Phase0Demo/config.db`（示例数据库）
- **任务细节**:
  1. 演示 UniBase 初始化和 Finalize
  2. 演示读写配置（带界面展示）
  3. 演示 `T()` 函数进行文本翻译
  4. 演示语言切换功能
  5. 演示窗体状态自动保存/恢复
  6. 演示错误处理（数据库损坏等场景）
- **验收标准**:
  - 示例工程可成功编译和运行
  - README 文档清晰说明如何运行
  - 包含功能演示截图

---

### P0-008: Phase 0 集成测试和文档

- **优先级**: P0
- **依赖**: P0-001 ~ P0-007
- **输出物**:
  - `Tests/Integration/Test.Phase0.Integration.pas`
  - `docs/API-Reference-Phase0.md`
  - `docs/QuickStart.md`
- **任务细节**:
  1. 编写 Phase 0 集成测试（完整流程测试）
  2. 编写 API 参考文档
  3. 编写快速开始指南
  4. 生成代码覆盖率报告
- **验收标准**:
  - 所有单元测试通过
  - 集成测试通过
  - 代码覆盖率 > 85% (Core 模块)
  - 文档完整清晰

---

## Phase T: UniBaseTray 工作台

**目标**: 实现日常开发辅助工具，包括开发日志、命令面板、自动化脚本。

> **注意**: 本模块与其他 Phase 并行开发，不依赖 Phase 0 以外的内容。

### PT-001: 创建 UniBaseTray 项目结构 ✅

- **优先级**: PT (高)
- **依赖**: 无
- **输出物**:
  - `Tools/Tray/UniBaseTray.dproj`
  - `Tools/Tray/Tray.MainForm.pas`
  - `Tools/Tray/Tray.DataModule.pas`
- **任务细节**:
  1. 创建悬浮窗口基础框架
  2. 实现系统托盘图标
  3. 实现窗口拖动和位置记忆
  4. 实现半透明效果
  5. 实现缩小到托盘/恢复显示
- **验收标准**:
  - 悬浮窗口可正常显示和拖动
  - 双击托盘图标可显示/隐藏窗口

---

### PT-002: 创建 studio.db 全局数据库 ✅

- **优先级**: PT
- **依赖**: PT-001
- **输出物**:
  - `sql/studio_init.sql`
  - `Tools/Tray/Tray.Database.pas`
- **任务细节**:
  1. 创建 DevLogs 表（开发日志）
  2. 创建 QuickCommands 表（常用命令）
  3. 创建 AutomationScripts 表（自动化脚本）
  4. 创建 TraySettings 表（配置项）
  5. 实现数据库初始化和连接管理
- **验收标准**:
  - studio.db 自动创建在 %APPDATA%/UniBase/
  - 所有表结构正确

---

### PT-003: 实现开发日志功能 ✅

- **优先级**: PT
- **依赖**: PT-002
- **输出物**:
  - `Tools/Tray/Frames/Tray.DevLogFrame.pas`
- **任务细节**:
  1. 实现日志快速录入界面
  2. 实现项目名下拉框（自动记住历史）
  3. 实现标签选择（Bug修复/新功能/重构/文档/测试）
  4. 实现日志保存到数据库
  5. 实现今日日志列表显示
- **验收标准**:
  - 可快速录入开发日志
  - 日志正确保存到数据库

---

### PT-004: 实现命令面板功能 ✅

- **优先级**: PT
- **依赖**: PT-002
- **输出物**:
  - `Tools/Tray/Frames/Tray.CommandFrame.pas`
- **任务细节**:
  1. 实现命令列表显示（按频次排序）
  2. 实现单击复制命令
  3. 实现双击执行命令
  4. 实现命令 CRUD 操作
  5. 实现全局命令和项目命令分类
  6. 实现危险命令确认和黑名单
- **验收标准**:
  - 命令可正确复制和执行
  - 危险命令执行前有确认提示
  - 黑名单命令禁止执行

---

### PT-005: 实现快速启动功能 ✅

- **优先级**: PT
- **依赖**: PT-001
- **输出物**:
  - `Tools/Tray/Tray.Launcher.pas`
- **任务细节**:
  1. 实现启动 Studio 功能（配置路径）
  2. 实现在当前目录打开 CMD
  3. 实现在当前目录打开 PowerShell
  4. 实现管理员模式启动 CMD/PowerShell
  5. 实现在当前目录打开资源管理器
- **验收标准**:
  - 所有启动功能正常工作
  - 管理员模式正确弹出 UAC 提示

---

### PT-006: 实现多步操作自动化（基础） ✅

- **优先级**: PT
- **依赖**: PT-002
- **输出物**:
  - `Tools/Tray/Automation/Tray.Automation.pas`
  - `Tools/Tray/Automation/Tray.AutoActions.pas`
- **任务细节**:
  1. 实现脚本 JSON 解析器
  2. 实现基础 Action: wait, runCommand
  3. 实现窗口 Action: findWindow, activateWindow
  4. 实现进程 Action: killProcess
  5. 实现脚本执行引擎
- **验收标准**:
  - 基础自动化脚本可正确执行
  - 错误处理完善

---

### PT-007: 实现多步操作自动化（高级） ✅

- **优先级**: PT
- **依赖**: PT-006
- **输出物**:
  - `Tools/Tray/Automation/Tray.KeyboardMouse.pas`
- **任务细节**:
  1. 实现键盘 Action: sendKeys, sendText
  2. 实现剪贴板 Action: paste
  3. 实现鼠标 Action: mouseClick
  4. 实现等待 Action: waitWindow
  5. 实现条件判断: if
- **验收标准**:
  - 完整自动化脚本可正确执行
  - 支持所有规范定义的 Action

---

### PT-008: 实现配置和日志搜索 ✅

- **优先级**: PT
- **依赖**: PT-003
- **输出物**:
  - `Tools/Tray/Forms/Tray.SettingsForm.pas`
  - `Tools/Tray/Forms/Tray.LogSearchForm.pas`
- **任务细节**:
  1. 实现配置界面（Studio路径、透明度、置顶等）
  2. 实现日志搜索筛选界面
  3. 实现日志导出（Markdown/JSON）
- **验收标准**:
  - 配置保存后立即生效
  - 日志可按日期/项目/标签筛选

---

## Phase 1: 推荐功能

**目标**: 实现 Tier 1 表结构和 VCL 控件，使框架具备生产可用性。

### P1-001: 创建 Tier 1 数据库 Schema 脚本 ✅

- **优先级**: P1
- **依赖**: P0-001
- **输出物**:
  - `sql/tier1_init.sql`: 包含 `Logs`, `MRU`, `Hotkeys`, `Themes` 四张表的 DDL。
- **验收标准**:
  - 脚本可在已有 Tier 0 数据库上成功执行。

---

### P1-002: 实现 Logging 模块 ✅

- **优先级**: P1
- **依赖**: P1-001
- **输出物**:
  - `Core/UniBase.Logging.pas`
- **任务细节**:
  1. 实现 `Log(Msg, Level, Source)` 方法。
  2. 实现 `LogDebug/LogInfo/LogWarn/LogError/LogFmt` 快捷方法。
  3. 支持 `Log.StorageMode` 配置 (Database/File/Both)。
  4. 实现 `ClearOldLogs(DaysToKeep)` 方法。
  5. 确保线程安全（写入队列 + 后台写入线程）。
- **验收标准**:
  - 单元测试：日志正确写入数据库。
  - 单元测试：多线程高并发写入不丢失。
  - 性能测试：10000 条日志写入 < 5 秒。

---

### P1-003: 实现 MRU 模块 ✅

- **优先级**: P1
- **依赖**: P1-001
- **输出物**:
  - `Core/UniBase.MRU.pas`
- **任务细节**:
  1. 实现 `AddMRU(Category, ItemKey, DisplayName)`。
  2. 实现 `GetMRUList(Category, MaxItems)`。
  3. 实现 `GetMRUItems(Category, MaxItems)` (返回完整结构体)。
  4. 实现 `ClearMRU(Category)`。
  5. 实现 `RemoveInvalidMRU` (自动移除不存在的文件路径)。
- **验收标准**:
  - 单元测试：添加项后列表正确排序（按 LastAccess DESC）。
  - 单元测试：重复添加同一 Key 时更新时间戳和计数。

---

### P1-004: 实现 Hotkeys 模块 ✅

- **优先级**: P1
- **依赖**: P1-001
- **输出物**:
  - `Core/UniBase.Hotkeys.pas`
- **任务细节**:
  1. 实现 `GetHotkey(ActionName): TShortCut`。
  2. 实现 `SetHotkey(ActionName, Shortcut)`。
  3. 实现 `RegisterDefaultHotkeys(Defaults)`。
  4. 实现 `ResetHotkey(ActionName)` / `ResetAllHotkeys`。
  5. 实现 `CheckHotkeyConflict(Shortcut): string`。
- **验收标准**:
  - 单元测试：快捷键保存后重新加载正确。
  - 单元测试：冲突检测返回正确的 ActionName。

---

### P1-005: 实现 Theme 模块 ✅

- **优先级**: P1
- **依赖**: P1-001
- **输出物**:
  - `Core/UniBase.Theme.pas`
- **任务细节**:
  1. 实现 `ApplyTheme(ThemeName)` (VCL: `TStyleManager.SetStyle`)。
  2. 实现 `GetAvailableThemes: TArray<TThemeInfo>`。
  3. 实现 `IsDarkTheme: Boolean`。
  4. 实现 `OnThemeChanged` 事件。
- **验收标准**:
  - 集成测试：切换主题后界面样式正确变化。

---

### P1-006: 实现 VCL 基础控件 ✅

- **优先级**: P1
- **依赖**: P0-003, P0-004, P1-003
- **输出物**:
  - `VCL/UniBase.VCL.Controls.pas` (注册单元)
  - `VCL/UniBase.VCL.ConfigControls.pas` (TConfigEdit, TConfigCheckBox, TConfigSpinEdit)
  - `VCL/UniBase.VCL.I18nControls.pas` (TI18nLabel, TI18nButton)
  - `VCL/UniBase.VCL.MRUControls.pas` (TMRUPopupMenu, TMRUComboBox)
  - `VCL/UniBase.VCL.ComboBoxes.pas` (TLanguageComboBox, TThemeComboBox)
- **任务细节**:
  - 每个控件实现设计时属性 (published)。
  - `TI18nLabel/Button` 在 `OnLanguageChanged` 时自动刷新 Caption。
  - `TConfigEdit/CheckBox` 实现 `AutoLoad` 和 `AutoSave`。
  - `TMRUPopupMenu` 实现自动刷新菜单项。
- **验收标准**:
  - 控件可在 Delphi IDE 中设计时使用。
  - 集成测试：拖放控件到窗体后，运行时功能正常。

---

### P1-007: 实现 TFormStateHelper 组件 ✅

- **优先级**: P1
- **依赖**: P0-006
- **输出物**:
  - `VCL/UniBase.VCL.FormStateHelper.pas`
- **任务细节**:
  1. 实现 `AutoSave` / `AutoRestore` 属性。
  2. 实现 `OnSaveExtra` / `OnRestoreExtra` 事件（用于保存自定义状态）。
  3. 在 `TForm.OnCreate` 和 `TForm.OnDestroy` 自动挂钩。
- **验收标准**:
  - 集成测试：拖放到窗体后，窗体状态自动保存/恢复。

---

### P1-008: 实现 TLogListView 组件 ✅

- **优先级**: P1
- **依赖**: P1-002
- **输出物**:
  - `VCL/UniBase.VCL.LogListView.pas`
- **任务细节**:
  1. 继承自 `TListView`，启用 `OwnerData` 模式。
  2. 在 `Loaded` 时自动注册为 Logger 的 Appender。
  3. 实现按 LogLevel 整行变色。
  4. 实现右键菜单（清空、复制、自动滚动）。
  5. 实现 `MaxItems` 属性（环形缓冲区，防止内存溢出）。
- **验收标准**:
  - 性能测试：10000 条日志渲染流畅。
  - 集成测试：拖放后自动显示 Log。

---

### P1-009: 创建 UniBase Studio - 基础框架 ✅

- **优先级**: P1
- **依赖**: P0 全部, P1-001 ~ P1-005
- **输出物**:
  - `Tools/Studio/Studio.dproj`
  - `Tools/Studio/Forms/Studio.MainForm.pas`
- **任务细节**:
  1. 实现主界面框架（左侧导航栏 + 右侧工作区）。
  2. 实现项目管理功能（打开/切换 config.db）。
  3. 实现配置编辑器（Settings 表的 Key-Value 编辑）。
  4. 实现日志查看器界面。
- **验收标准**:
  - Studio 可成功打开并管理 config.db。

---

## Phase 2: 扩展功能

**目标**: 实现 LLM 集成、等待窗口、异常处理和 GUI 测试支持。

### P2-001: 创建 Tier 2 数据库 Schema 脚本 ✅

- **优先级**: P2
- **依赖**: P1-001
- **输出物**:
  - `sql/tier2_init.sql`: 包含 `LLMConfiguration`, `LLMCalls`, `ExceptionReports`, `AnimationAssets`, `TestSnapshots` 表。
- **验收标准**:
  - 脚本可在已有 Tier 0+1 数据库上成功执行。

---

### P2-002: 实现 LLM 模块 ✅

- **优先级**: P2
- **依赖**: P2-001
- **输出物**:
  - `Core/UniBase.LLM.pas`
- **任务细节**:
  1. 实现 `LLMChat(Prompt, out Response): Boolean`。
  2. 实现 `LLMChatAsync(Prompt, OnComplete): ITask`。
  3. 实现 `TestLLMConnection(out DurationMs, out ErrorMsg): Boolean`。
  4. 支持 LiteLLM / OpenAI / Anthropic 等 Provider。
  5. 实现调用记录写入 `LLMCalls` 表。
  6. 实现成本估算（基于 Token 数和配置的价格）。
- **验收标准**:
  - 单元测试（Mock）：正确解析 LLM API 响应。
  - 集成测试：实际调用 LiteLLM 成功。

---

### P2-003: 实现 TLLMConfigPanel 组件 ✅

- **优先级**: P2
- **依赖**: P2-002
- **输出物**:
  - `VCL/UniBase.VCL.LLMConfigPanel.pas`
- **任务细节**:
  1. 上部：Provider/API Key/Model 配置面板。
  2. 下部：LLMCalls 历史记录 Grid。
  3. 测试连接按钮。
  4. 保存/重置按钮。
- **验收标准**:
  - 集成测试：配置保存后，LLM 模块可正常调用。

---

### P2-004: 实现 TWaitForm 组件 ✅

- **优先级**: P2
- **依赖**: P2-001 (AnimationAssets)
- **输出物**:
  - `VCL/UniBase.VCL.WaitForm.pas`
- **任务细节**:
  1. 实现 `TWaitForm.Show(Message, RandomAnimation)`。
  2. 实现从 `AnimationAssets` 随机选择 SVG 动画。
  3. 使用 Image32 库渲染 SVG。
  4. 实现 `UpdateMessage` / `UpdateProgress`。
  5. 实现 `SwitchToBackground`（切换到通知栏模式）。
- **验收标准**:
  - 集成测试：等待窗体正确显示和隐藏。
  - 集成测试：动画流畅播放。

---

### P2-005: 实现 TNotificationBar 组件 ✅

- **优先级**: P2
- **依赖**: P2-004
- **输出物**:
  - `VCL/UniBase.VCL.NotificationBar.pas`
- **任务细节**:
  1. 实现底部通知栏布局。
  2. 实现进度条和旋转动画图标。
  3. 实现取消和关闭按钮。
  4. 支持任务完成/失败自动更新状态。
- **验收标准**:
  - 集成测试：后台任务进度实时更新。

---

### P2-006: 实现 Exception 模块 ✅

- **优先级**: P2
- **依赖**: P2-001
- **输出物**:
  - `Core/UniBase.Exception.pas`
- **任务细节**:
  1. 实现 `HandleException(Sender, E)`。
  2. 实现 `ReportException(E, UserAction)`。
  3. 将异常信息写入 `ExceptionReports` 表。
  4. 捕获堆栈跟踪信息 (JclDebug / madExcept 集成)。
- **验收标准**:
  - 单元测试：异常正确记录到数据库。
  - 集成测试：未处理异常触发全局处理器。

---

### P2-007: 实现 Studio i18n 翻译管理 ✅

- **优先级**: P2
- **依赖**: P1-009
- **输出物**:
  - `Tools/Studio/Forms/Studio.TranslationForm.pas`
  - `Tools/Studio/Modules/Studio.I18nScanner.pas`
- **任务细节**:
  1. 实现源码扫描器（采集 `T('...')`、`TextKey` 属性）。
  2. 实现翻译网格编辑界面。
  3. 实现 LLM 批量翻译功能。
  4. 实现翻译进度统计。
  5. 实现导入/导出（JSON/PO/Excel）。
- **验收标准**:
  - 集成测试：扫描示例工程，正确采集翻译条目。
  - 集成测试：LLM 翻译功能正常工作。

---

### P2-008: 实现 GUI 测试辅助模块 ✅

- **优先级**: P2
- **依赖**: P2-001 (TestSnapshots)
- **输出物**:
  - `Core/UniBase.TestHelper.pas`
- **任务细节**:
  1. 实现 `CaptureFormState(AForm): string`。
  2. 实现 `SaveSnapshot(TestName, AForm)`。
  3. 实现 `VerifySnapshot(TestName, AForm): Boolean`。
  4. 实现 `SimulateClick/SimulateInput/SimulateSelect`。
- **验收标准**:
  - 单元测试：快照保存和验证正确。

---

### P2-009: 实现 FMX 控件包 ✅

- **优先级**: P2
- **依赖**: P1-006
- **输出物**:
  - `FMX/UniBase.FMX.Controls.pas`
  - `FMX/UniBase.FMX.*.pas` (与 VCL 对应)
- **验收标准**:
  - FMX 控件接口与 VCL 保持一致。
  - 集成测试：FMX 示例工程运行正常。

---

## Phase 3: 高级功能

**目标**: 实现自动更新、远程配置、CLI 工具和云端服务。

### P3-001: 实现 AutoUpdate 模块 ✅

- **优先级**: P3
- **依赖**: P0 全部
- **输出物**:
  - `Core/UniBase.AutoUpdate.pas`
- **任务细节**:
  1. 实现 `CheckForUpdate(out UpdateInfo): Boolean`。
  2. 实现 `DownloadUpdate(UpdateInfo, OnProgress)`。
  3. 实现 SHA256 签名验证。
  4. 实现更新渠道支持 (Stable/Beta/Dev)。
- **验收标准**:
  - 单元测试（Mock）：正确解析 version.json。
  - 集成测试：从测试服务器下载更新包。

---

### P3-002: 实现 TAutoUpdater 组件 ✅

- **优先级**: P3
- **依赖**: P3-001
- **输出物**:
  - `VCL/UniBase.VCL.AutoUpdater.pas`
- **验收标准**:
  - 集成测试：发现新版本时弹出提示对话框。

---

### P3-003: 实现 TUpdateDialog 组件 ✅

- **优先级**: P3
- **依赖**: P3-001
- **输出物**:
  - `VCL/UniBase.VCL.UpdateDialog.pas`
- **验收标准**:
  - 集成测试：下载进度正确显示。

---

### P3-004: 实现 TDBInitWizard 组件 ✅

- **优先级**: P3
- **依赖**: P0 全部
- **输出物**:
  - `VCL/UniBase.VCL.DBInitWizard.pas`
- **任务细节**:
  1. 实现向导步骤界面。
  2. 实现数据库路径选择。
  3. 实现初始化确认和执行。
- **验收标准**:
  - 集成测试：首次运行时正确引导用户。

---

### P3-005: 实现 RemoteConfig 模块 ✅

- **优先级**: P3
- **依赖**: P0 全部
- **输出物**:
  - `Core/UniBase.RemoteConfig.pas`
- **任务细节**:
  1. 实现 `GetRemoteFlag(Key, Default): Boolean`。
  2. 实现 `GetRemoteConfig(Key, Default): string`。
  3. 实现 `RefreshRemoteConfig`。
  4. 实现本地缓存机制。
- **验收标准**:
  - 单元测试（Mock）：正确解析 remote-config.json。

---

### P3-006: 实现 UniBase CLI 工具 ✅

- **优先级**: P3
- **依赖**: P0 全部, P2-007
- **输出物**:
  - `Tools/CLI/unibase.dproj`
  - `Tools/CLI/CLI.Commands.pas`
  - `Tools/CLI/CLI.DB.pas`
  - `Tools/CLI/CLI.I18n.pas`
  - `Tools/CLI/CLI.Config.pas`
- **任务细节**:
  1. 实现 `unibase db init/upgrade/backup/check` 命令。
  2. 实现 `unibase i18n scan/sync/translate/export/import` 命令。
  3. 实现 `unibase config get/set/export/import` 命令。
- **验收标准**:
  - 所有命令可从终端成功执行。
  - 帮助文档 (`--help`) 正确显示。

---

### P3-007: 创建云端服务示例 ✅

- **优先级**: P3
- **依赖**: P3-001, P3-005
- **输出物**:
  - `CloudServices/README.md` (部署指南)
  - `CloudServices/version.json` (示例版本文件)
  - `CloudServices/remote-config.json` (示例远程配置)
- **验收标准**:
  - 文档清晰说明如何部署静态文件服务。

---

## Phase 4: 完善与文档

**目标**: License 管理、用户反馈、使用统计和完整文档。

### P4-001: 实现 License 模块 ✅

- **优先级**: P4
- **依赖**: P0 全部
- **输出物**:
  - `Core/UniBase.License.pas`
- **任务细节**:
  1. 实现 License Key 验证（本地 + 在线）。
  2. 实现设备指纹生成。
  3. 实现许可证类型检查 (Trial/Standard/Pro)。
- **验收标准**:
  - 单元测试：正确验证有效/无效 Key。

---

### P4-002: 实现 TLicenseStatusPanel 组件 ✅

- **优先级**: P4
- **依赖**: P4-001
- **输出物**:
  - `VCL/UniBase.VCL.LicenseStatusPanel.pas`
- **验收标准**:
  - 集成测试：正确显示 License 状态和额度。

---

### P4-003: 实现 TLicenseAuthDialog 组件 ✅

- **优先级**: P4
- **依赖**: P4-001
- **输出物**:
  - `VCL/UniBase.VCL.LicenseAuthDialog.pas`
- **验收标准**:
  - 集成测试：激活流程正常工作。

---

### P4-004: 实现 TFeedbackDialog 组件 ✅

- **优先级**: P4
- **依赖**: P1-002 (Logging)
- **输出物**:
  - `VCL/UniBase.VCL.FeedbackDialog.pas`
- **任务细节**:
  1. 实现反馈表单（类型、内容、联系方式）。
  2. 实现附带日志选项。
  3. 实现异步提交到服务器。
- **验收标准**:
  - 集成测试：反馈成功提交。

---

### P4-005: 实现 Studio License 管理模块 ✅

- **优先级**: P4
- **依赖**: P4-001
- **输出物**:
  - `Tools/Studio/Forms/Studio.LicenseForm.pas`
- **任务细节**:
  1. 实现 License Key 生成器。
  2. 实现已发放密钥管理。
- **验收标准**:
  - 集成测试：生成的 Key 可被验证。

---

### P4-006: 撰写完整 API 文档 ✅

- **优先级**: P4
- **依赖**: 全部代码完成
- **输出物**:
  - `docs/api-reference.md`
  - `docs/getting-started.md`
  - `docs/faq.md`
- **验收标准**:
  - 所有公开 API 有文档说明。
  - 包含代码示例。

---

### P4-007: 创建综合示例工程 ✅

- **优先级**: P4
- **依赖**: 全部模块完成
- **输出物**:
  - `Examples/FullDemo/FullDemo.dproj`
- **验收标准**:
  - 示例工程演示所有框架功能。
  - 附带详细 README。

---

## 附录：任务统计

| 阶段 | 任务数 | 核心模块 | UI 控件 | 工具 |
|------|--------|----------|---------|------|
| Phase 0 | 7 | 5 | 0 | 2 |
| Phase 1 | 9 | 4 | 4 | 1 |
| Phase 2 | 9 | 3 | 4 | 2 |
| Phase 3 | 7 | 2 | 3 | 2 |
| Phase 4 | 7 | 1 | 3 | 3 |
| **总计** | **39** | **15** | **14** | **10** |

---

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| 1.0 | 2025-11-26 | 初稿，基于 spec v0.3 |
| 1.1 | 2025-11-28 | Phase 5 代码审查优化完成，文档对齐 |
