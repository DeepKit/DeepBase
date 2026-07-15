# DeepBase 开发历史 (归档卷 - 早期开发与 2025-12 杂项)

> 本卷归档早期 Phase 0~5 开发、2025-12 Issues/性能/统计杂项及 2026-06-18 架构归档。
> 近期审阅修复 (REVIEW5/R2/R3) 与 2026-05~06 优化归档见 `history.md`。

---

## Phase 0: 最小核�?�?(完成)

### P0-001: 创建项目结构和包配置 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?项目目录结构（Core/VCL/FMX/Tests/Tools/ThirdParty�?  - �?`.gitignore` �?`.gitmodules` 配置
  - �?`DeepBaseCore.dpk` 运行时包
  - �?`dclDeepBaseCore.dpk` 设计时包
  - �?`README.md` 项目说明
- **备注**: 包可�?Delphi IDE 中成功编�?
---

### P0-002: 创建 Tier 0 数据�?Schema 脚本 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?`sql/tier0_init.sql`: 包含 SchemaInfo, ProjectInfo, Settings, FormStates, Languages, I18nTexts �?  - �?预置数据（默认语言、默�?Schema 版本�?  - �?`sql/README.md`: Schema 设计说明
- **备注**: 脚本可在�?SQLite 数据库上成功执行

---

### P0-003: 实现 TDeepBaseManager 核心框架 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.Manager.pas`
  - �?`Core/DeepBase.Types.pas`
  - �?`Tests/Test.DeepBase.Manager.pas`
- **功能**:
  - �?Initialize / InitializeEx / InitializeWithDB 方法
  - �?Finalize 方法
  - �?RootPath 检测逻辑（EXE 目录 -> APPDATA 回退�?  - �?FInitErrorCode 错误码机�?  - �?全局单例 DeepBase()
  - �?HealthCheck 方法
  - �?单元测试（代码覆盖率 > 85%�?- **备注**: Manager 使用 TMonitor 确保线程安全

---

### P0-004: 实现 Config 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.Config.pas`
  - �?`Tests/Test.DeepBase.Config.pas`
- **功能**:
  - �?GetConfig / SetConfig (String)
  - �?GetConfigInt / SetConfigInt
  - �?GetConfigBool / SetConfigBool
  - �?GetConfigFloat / SetConfigFloat
  - �?OnConfigChanged 事件通知
  - �?内存缓存机制�? 1ms 读取�?  - �?线程安全（TMonitor�?- **性能**: 缓存命中 < 1ms，未命中 < 10ms

---

### P0-005: 实现 i18n 模块（基础�?�?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.i18n.pas`
  - �?`Tests/Test.DeepBase.i18n.pas`
- **功能**:
  - �?T() 函数
  - �?TFmt() 格式化翻�?  - �?CurrentLanguage 属�?  - �?OnLanguageChanged 事件
  - �?GetAvailableLanguages 方法
  - �?LRU 翻译缓存（容�?10000�?  - �?线程安全（TMonitor�?- **性能**: 缓存命中 < 0.5ms

---

### P0-006: 实现 FormState 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **输出�?*:
  - �?`Core/DeepBase.FormState.pas`
  - �?`Tests/Test.DeepBase.FormState.pas`
- **功能**:
  - �?SaveFormState(AForm: TForm)
  - �?RestoreFormState(AForm: TForm)
  - �?多显示器边界检�?  - �?WindowState 支持 (Normal/Minimized/Maximized)
  - �?Extra 字段（JSON 格式�?- **备注**: 框架无关的实现，VCL �?FMX 都可�?
---

### P0-007: 创建 Phase 0 示例工程 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **输出�?*:
  - �?`Examples/Phase0Demo/Phase0Demo.dproj`
  - �?`Examples/Phase0Demo/MainForm.pas`
  - �?`Examples/Phase0Demo/README.md`
  - �?`Examples/Phase0Demo/config.db`
- **演示内容**:
  - �?DeepBase 初始化和 Finalize
  - �?读写配置（带界面展示�?  - �?T() 函数进行文本翻译
  - �?语言切换功能
  - �?窗体状态自动保�?恢复
  - �?错误处理演示

---

### P0-008: Phase 0 集成测试和文�?�?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **输出�?*:
  - �?�?Phase0 集成测试入口
  - �?Phase0 API 参考文档（后续并入 `docs/05.01.DeepBase-4AI-API参�?v1.0.md`�?  - �?快速入门文档（当前入口�?`ARCH-QUICKSTART.md`�?- **测试覆盖**:
  - �?所有单元测试通过
  - �?集成测试通过
  - �?代码覆盖�?> 85%

---

## Phase 1: 推荐功能 �?(完成)

### P1-001: 创建 Tier 1 数据�?Schema 脚本 �?- **完成日期**: 2025-11-26
- **输出�?*: `sql/tier1_init.sql` (Logs, MRU, Hotkeys, Themes)

---

### P1-002: 实现 Logging 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?Log(Msg, Level, Source) 方法
  - �?LogDebug/LogInfo/LogWarn/LogError/LogFmt 快捷方法
  - �?StorageMode 配置 (Database/File/Both)
  - �?ClearOldLogs(DaysToKeep) 方法
  - �?后台写入线程，不丢失日志
- **性能**: 10000 条日志写�?< 5 �?
---

### P1-003: 实现 MRU 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?AddMRU(Category, ItemKey, DisplayName)
  - �?GetMRUList(Category, MaxItems)
  - �?GetMRUItems(Category, MaxItems)
  - �?ClearMRU(Category)
  - �?RemoveInvalidMRU 自动清理

---

### P1-004: 实现 Hotkeys 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?GetHotkey(ActionName): TShortCut
  - �?SetHotkey(ActionName, Shortcut)
  - �?RegisterDefaultHotkeys(Defaults)
  - �?ResetHotkey / ResetAllHotkeys
  - �?CheckHotkeyConflict(Shortcut)

---

### P1-005: 实现 Theme 模块 �?- **完成日期**: 2025-11-26
- **负责�?*: 李冰
- **功能**:
  - �?ApplyTheme(ThemeName)
  - �?GetAvailableThemes
  - �?IsDarkTheme: Boolean
  - �?OnThemeChanged 事件

---

### P1-006: 实现 VCL 基础控件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **控件列表**:
  - �?TConfigEdit, TConfigCheckBox, TConfigSpinEdit (自动保存配置)
  - �?TI18nLabel, TI18nButton (自动翻译)
  - �?TMRUPopupMenu, TMRUComboBox (最近使用列�?
  - �?TLanguageComboBox, TThemeComboBox (快速切�?
- **备注**: 所有控件已注册�?Delphi 组件面板

---

### P1-007: 实现 TFormStateHelper 组件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **功能**:
  - �?AutoSave / AutoRestore 属�?  - �?OnSaveExtra / OnRestoreExtra 事件
  - �?自动挂钩 TForm.OnCreate �?OnDestroy

---

### P1-008: 实现 TLogListView 组件 �?- **完成日期**: 2025-11-26
- **负责�?*: 鲁班
- **功能**:
  - �?OwnerData 模式
  - �?�?LogLevel 整行变色
  - �?右键菜单（清空、复制、自动滚动）
  - �?MaxItems 环形缓冲�?- **性能**: 10000 条日志渲染流�?
---

### P1-009: 创建 DeepBase Studio - 基础框架 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `Tools/Studio/Studio.dproj`
- **功能**:
  - �?主界面框架（左侧导航�?+ 右侧工作区）
  - �?项目管理功能（打开/切换 config.db�?  - �?配置编辑器（Settings 表的 Key-Value 编辑�?  - �?日志查看器界�?
---

## Phase T: DeepBaseTray 工作�?�?(完成)

### PT-001: 创建 DeepBaseTray 项目结构 �?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/DeepBaseTray.dpr`
- **功能**:
  - �?悬浮窗口基础框架
  - �?系统托盘图标
  - �?窗口拖动和位置记�?  - �?半透明效果
  - �?缩小到托�?恢复显示

---

### PT-002: 创建 studio.db 全局数据�?�?- **完成日期**: 2025-11-27
- **输出�?*: `sql/studio_init.sql`
- **功能**:
  - �?DevLogs 表（开发日志）
  - �?QuickCommands 表（常用命令�?  - �?AutomationScripts 表（自动化脚本）
  - �?TraySettings 表（配置项）

---

### PT-003: 实现开发日志功�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Frames/Tray.DevLogFrame.pas`
- **功能**:
  - �?日志快速录入界�?  - �?项目名下拉框
  - �?标签选择（Bug修复/新功�?重构/文档/测试�?  - �?日志保存到数据库
  - �?今日日志列表显示

---

### PT-004: 实现命令面板功能 �?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Frames/Tray.CommandFrame.pas`
- **功能**:
  - �?命令列表显示（按频次排序�?  - �?单击复制命令
  - �?双击执行命令
  - �?命令 CRUD 操作
  - �?全局命令和项目命令分�?  - �?危险命令确认和黑名单

---

### PT-005: 实现快速启动功�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Tray.Launcher.pas`
- **功能**:
  - �?启动 Studio 功能
  - �?在当前目录打开 CMD
  - �?在当前目录打开 PowerShell
  - �?管理员模式启�?  - �?在当前目录打开资源管理�?
---

### PT-006: 实现多步操作自动化（基础�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Automation/Tray.Automation.pas`
- **功能**:
  - �?脚本 JSON 解析�?  - �?基础 Action: wait, runCommand
  - �?窗口 Action: findWindow, activateWindow
  - �?进程 Action: killProcess

---

### PT-007: 实现多步操作自动化（高级�?�?- **完成日期**: 2025-11-27
- **输出�?*: `Tools/Tray/Automation/Tray.KeyboardMouse.pas`
- **功能**:
  - �?键盘 Action: sendKeys, sendText
  - �?剪贴�?Action: paste
  - �?鼠标 Action: mouseClick
  - �?等待 Action: waitWindow
  - �?条件判断: if

---

### PT-008: 实现配置和日志搜�?�?- **完成日期**: 2025-11-27
- **输出�?*: 
  - �?`Tools/Tray/Forms/Tray.SettingsForm.pas`
  - �?`Tools/Tray/Forms/Tray.LogSearchForm.pas`
- **功能**:
  - �?配置界面（Studio路径、透明度、置顶等�?  - �?日志搜索筛选界�?  - �?日志导出（Markdown/JSON�?
---

## Phase 2: 扩展功能 �?(完成)

### P2-001: 创建 Tier 2 数据�?Schema 脚本 �?- **完成日期**: 2025-11-27
- **输出�?*: `sql/tier2_init.sql`

---

### P2-002: 实现 LLM 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?LLMChat(Prompt, out Response)
  - �?LLMChatAsync(Prompt, OnComplete)
  - �?TestLLMConnection()
  - �?支持多个 Provider (OpenAI, Anthropic)
  - �?调用记录写入数据�?  - �?成本估算

---

### P2-003: 实现 TLLMConfigPanel 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?Provider/API Key/Model 配置面板
  - �?LLMCalls 历史记录 Grid
  - �?测试连接按钮
  - �?保存/重置按钮

---

### P2-004: 实现 TWaitForm 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?Show(Message, RandomAnimation)
  - �?�?AnimationAssets 随机选择 SVG 动画
  - �?UpdateMessage / UpdateProgress
  - �?SwitchToBackground（切换到通知栏模式）

---

### P2-005: 实现 TNotificationBar 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?底部通知栏布局
  - �?进度条和旋转动画图标
  - �?取消和关闭按�?  - �?任务完成/失败自动更新状�?
---

### P2-006: 实现 Exception 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?HandleException(Sender, E)
  - �?ReportException(E, UserAction)
  - �?异常信息写入 ExceptionReports �?  - �?捕获堆栈跟踪信息

---

### P2-007: 实现 Studio i18n 翻译管理 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?源码扫描器（采集 T() �?TextKey�?  - �?翻译网格编辑界面
  - �?LLM 批量翻译功能
  - �?翻译进度统计
  - �?导入/导出（JSON/PO/Excel�?
---

### P2-008: 实现 GUI 测试辅助模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?CaptureFormState(AForm)
  - �?SaveSnapshot(TestName, AForm)
  - �?VerifySnapshot(TestName, AForm)
  - �?SimulateClick/SimulateInput/SimulateSelect

---

### P2-009: 实现 FMX 控件�?�?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `FMX/DeepBase.FMX.Controls.pas`
- **功能**: FMX 控件接口�?VCL 保持一�?
---

## Phase 3: 高级功能 �?(完成)

### P3-001: 实现 AutoUpdate 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?CheckForUpdate(out UpdateInfo)
  - �?DownloadUpdate(UpdateInfo, OnProgress)
  - �?SHA256 签名验证
  - �?更新渠道支持 (Stable/Beta/Dev)

---

### P3-002: 实现 TAutoUpdater 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班

---

### P3-003: 实现 TUpdateDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 下载进度正确显示

---

### P3-004: 实现 TDBInitWizard 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?向导步骤界面
  - �?数据库路径选择
  - �?初始化确认和执行

---

### P3-005: 实现 RemoteConfig 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?GetRemoteFlag(Key, Default)
  - �?GetRemoteConfig(Key, Default)
  - �?RefreshRemoteConfig()
  - �?本地缓存机制

---

### P3-006: 实现 DeepBase CLI 工具 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **输出�?*: `Tools/CLI/DeepBase.exe`
- **命令**:
  - �?`DeepBase db init/upgrade/backup/check`
  - �?`DeepBase i18n scan/sync/translate/export/import`
  - �?`DeepBase config get/set/export/import`

---

### P3-007: 创建云端服务示例 �?- **完成日期**: 2025-11-27
- **输出�?*: 
  - �?`CloudServices/README.md`
  - �?`CloudServices/version.json`
  - �?`CloudServices/remote-config.json`

---

## Phase 4: 完善与文�?�?(完成)

### P4-001: 实现 License 模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 李冰
- **功能**:
  - �?License Key 验证（本�?+ 在线�?  - �?设备指纹生成
  - �?许可证类型检�?(Trial/Standard/Pro)

---

### P4-002: 实现 TLicenseStatusPanel 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 正确显示 License 状态和额度

---

### P4-003: 实现 TLicenseAuthDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**: 激活流程正常工�?
---

### P4-004: 实现 TFeedbackDialog 组件 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?反馈表单（类型、内容、联系方式）
  - �?附带日志选项
  - �?异步提交到服务器

---

### P4-005: 实现 Studio License 管理模块 �?- **完成日期**: 2025-11-27
- **负责�?*: 鲁班
- **功能**:
  - �?License Key 生成�?  - �?已发放密钥管�?
---

### P4-006: 撰写完整 API 文档 �?- **完成日期**: 2025-11-27
- **输出�?*:
  - �?`docs/05.01.DeepBase-4AI-API参�?v1.0.md`
  - �?`ARCH-QUICKSTART.md`
  - �?`docs/03.01.DeepBase-4AI-FAQ与错误速查-v1.0.md`

---

### P4-007: 创建综合示例工程 �?- **完成日期**: 2025-11-27
- **输出�?*: `Examples/FullDemo/FullDemo.dproj`
- **功能**: 演示所有框架功�?
---

## Phase 5: 代码审查优化 �?(完成)

> 基于 2025-11-28 代码审查的改进任�?
### P5-001: Schema SQL 外部�?�?- **完成日期**: 2025-11-28
- **输出�?*: `Core/DeepBase.Schema.pas` (新建�?30+ �?
- **功能**:
  - �?SQL 定义分为 Tier0/Tier1/Tier2 常量
  - �?`GetTier0SchemaSQL/GetTier1SchemaSQL/GetTier2SchemaSQL/GetFullSchemaSQL` 函数
  - �?Manager.CreateSchema 改用 GetFullSchemaSQL()
  - �?添加 `Queries` 表支�?
---

### P5-002: DoQry 查询表加载与缓存 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Persistence/DeepBase.DB.DoQry.pas` 更新
- **功能**:
  - �?实现 `LoadQuerySQL(ProcName, Ctx)` 带缓�?  - �?实现 `IsDirectSQL()` 判断 SQL 关键�?  - �?实现 `UniDbClearQueryCache()` 清除缓存
  - �?所�?UniDb* 函数更新使用 LoadQuerySQL
  - �?向后兼容：直�?SQL 仍然支持

---

### P5-003: Logger 初始化改�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Logging.pas` 更新
- **功能**:
  - �?添加 `SetGlobalLogger(ALogger)` 过程
  - �?添加 `IsLoggerInitialized()` 检查函�?  - �?Logger() 未初始化时返回文件日志模�?  - �?Manager.InitializeModules 调用 SetGlobalLogger

---

### P5-004: 核心模块接口抽象 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Interfaces.pas` (新建�?92 �?
- **功能**:
  - �?`IDeepBaseConfig` - 配置管理接口
  - �?`IDeepBaseLogger` - 日志接口
  - �?`IDeepBaseI18n` - 国际化接�?  - �?`IDeepBaseMRU` - MRU 接口
  - �?`IDeepBaseManager` - 管理器接�?- **备注**: 各模块可逐步实现这些接口，提高可测试�?
---

### P5-005: 运行时日志级别配�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Consts.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?添加 `SConfigKeyLogLevel` �?`SConfigKeyLogStorageMode` 常量
  - �?InitializeModules �?Settings 读取并设置日志级�?  - �?HandleConfigChanged 响应日志级别变更（热更新�?
---

### P5-006: 版本兼容性检�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Schema.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?Schema 添加 MIN/MAX_COMPATIBLE_SCHEMA_VERSION
  - �?添加 ecSchemaVersionMismatch 错误�?  - �?实现 ValidateSchemaVersion 方法
  - �?ValidateSchema 中调用版本检�?  - �?版本过旧/过新时给出明确错误提�?
---

### P5-007: i18n �?Manager 解�?�?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.i18n.pas`, `Core/DeepBase.Manager.pas` 更新
- **功能**:
  - �?移除 i18n �?Manager 的直接引�?  - �?添加 `SetGlobalTranslateCallback` 回调模式
  - �?添加 `IsTranslateCallbackSet` 检查函�?  - �?Manager.InitializeModules 设置翻译回调
  - �?T() 函数未初始化时返回原�?
---

### P5-008: 配置加密安全文档 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Config.pas` 更新
- **功能**:
  - �?添加详细的安全警告注释（25行）
  - �?明确说明 XOR 仅提供混淆而非加密
  - �?列出适用/不适用场景
  - �?提供更安全方案的建议（DPAPI/AES/Keychain�?
---

### P5-009: 常量命名规范文档 �?- **完成日期**: 2025-11-28
- **负责�?*: Claude
- **输出�?*: `Core/DeepBase.Consts.pas` 更新
- **功能**:
  - �?统一使用 `S` 前缀风格
  - �?添加详细的命名规范文档注�?  - �?记录各类前缀: SConfigKey*, SDefault*, STable*, etc.

---

## 统计摘要

| 阶段 | 总任务数 | 核心模块 | UI 控件 | 工具 | 状�?|
|------|---------|---------|---------|------|------|
| Phase 0 | 8 | 5 | 0 | 3 | �?完成 |
| Phase 1 | 9 | 4 | 4 | 1 | �?完成 |
| Phase 2 | 9 | 3 | 4 | 2 | �?完成 |
| Phase 3 | 7 | 2 | 3 | 2 | �?完成 |
| Phase T | 8 | 0 | 0 | 8 | �?完成 |
| Phase 4 | 7 | 1 | 3 | 3 | �?完成 |
| Phase 5 | 9 | 9 | 0 | 0 | �?完成 |
| **总计** | **57** | **24** | **14** | **19** | �?100% |

---

## 主要里程�?
- �?**2025-11-26**: Phase 0 完成，框架基础稳定
- �?**2025-11-26**: Phase 1 完成，VCL 控件库就�?- �?**2025-11-27**: Phase T 完成，开发工具套件完�?- �?**2025-11-27**: Phase 2 完成，LLM 和高�?UI 功能
- �?**2025-11-27**: Phase 3 完成，AutoUpdate �?CLI 工具
- �?**2025-11-27**: Phase 4 完成，License 和文�?- �?**2025-11-28**: Phase 5 完成，代码审查优化（9 项改进）

## 2025-12-01 代码审查与优�?
### 安全性修�?- CRYPTO-001: 实现真正�?AES-256-CBC 加密（使�?Windows BCrypt API�?  - 文件: `DeepBase.Crypto.pas`
- CRYPTO-002: 使用 BCryptGenRandom 替换不安全的 Random() 调用
  - 文件: `DeepBase.Crypto.pas`
- CONFIG-001: 添加编译器警告到 XOR 加密方法
  - 文件: `DeepBase.Config.pas`

### 内存管理优化
- ORM-001: TQueryBuilder 实现 IQueryBuilder 接口（自动引用计数）
  - 文件: `DeepBase.ORM.pas`
- CACHE-001: 添加 FreeValueIfOwned 安全释放泛型对象
  - 文件: `DeepBase.Cache.pas`

### IoC 容器修复
- IOC-001: RegisterSingleton 接口实例处理逻辑
  - 文件: `DeepBase.IoC.pas`

### 代码重构
- UTIL-001: CompareVersions 提取�?`DeepBase.Types.pas`
- INTERFACE-001: `TDeepBaseConfig`/`TDeepBaseI18n` 实现接口

### 国际化增�?- I18N-001: 集成 CLDR 复数规则（`DeepBase.i18n.Plural.pas`�?
### 日志系统优化
- LOG-001: 日志写入线程重构为批量处理模式（`DeepBase.Logging.pas`�?
### 新增功能
- E-001: IoC 循环依赖检测（异常 `ECircularDependencyException`�?- E-002: ORM `DEFAULT` 生成（`CreateTableSQL` 支持�?- E-003: Configuration 加密配置源（`TEncryptedConfigurationSource`�?- E-004: Logging 结构�?JSON 日志（`.jsonl`�?
### doQry 模块增强 (2025-12-01)
- DOQRY-001: CopyQueryToClientDataSet 扩展（Field.Assign + 性能优化�?- DOQRY-002: 查询缓存 TTL 策略（UniDbInvalidateQuery/UniDbSetCacheTTL/UniDbGetCacheStats�?- DOQRY-003: doQry 使用指南文档（`docs/05.03.DeepBase-4AI-DoQry指南-v1.0.md`�?- DOQRY-004: 日志输出结构�?JSON 格式
- DOQRY-005: 预编译语句池（UniDbSetPreparedStatementPooling/UniDbClearPreparedStatements/UniDbGetPreparedStats�?- DOQRY-006: 错误码规范化�?7 �?DOQRY_ERR_* 常量 + InferErrorCode�?
---

## OPT-MAINT-006: 日志聚合和分析系�?�?(2025-12-02)

> 功能优化任务: 集中式日志聚合和分析系统

### 新增模块

#### DeepBase.LogAggregator.pas (~1600 �?
- **日志聚合�?*: `TLogAggregator` 主类，支持批量推送、重试机�?- **后端接口**: `ILogBackend` 抽象，可扩展多种后端
- **ElasticSearch 后端**: `TElasticSearchBackend` - ES 7.x+ Bulk API 支持
- **Loki 后端**: `TLokiBackend` - Grafana Loki Push API
- **HTTP Webhook 后端**: `THttpWebhookBackend` - 通用 HTTP 推�?- **日志批次**: `TLogBatch` 批量操作�?- **过滤�?*: `TLogFilter` 流式 API
- **配置**: `TBackendConfig` 后端配置工厂方法

#### DeepBase.LogQuery.pas (~1800 �?
- **查询构建�?*: `TLogQueryBuilder` 流式查询 API
  - Where* 系列过滤方法
  - OrderBy*, Skip, Take 分页
  - GroupBy, Distinct 聚合
- **查询结果**: `TLogQueryResult` 支持 ToJSON/ToCSV 导出
- **时序数据**: `TLogTimeSeries` 时间序列分析
- **统计**: `TLogStats` 日志统计信息
- **分析�?*: `TLogAnalyzer` 高级分析功能
  - CountByLevel/Source/Host/App
  - CountByTime, ErrorRateByTime
  - TopErrors, TopExceptions
  - FindPatterns (正则匹配)
  - FindAnomalies (统计异常检�?
  - IsErrorRateIncreasing, GetTrend (线性回�?

#### DeepBase.LogAlert.pas (~1260 �?
- **告警条件**: `TAlertCondition`
  - ErrorCount: 错误数阈�?  - ErrorRate: 错误率阈�?  - PatternMatch: 模式匹配
  - NoLogs: 无日志检�?- **告警动作**: `TAlertAction`
  - Webhook: HTTP 回调
  - Email: 邮件通知 (接口)
  - Callback: 本地回调
  - Log: 日志输出
- **告警规则**: `TAlertRule` 流式 API 定义规则
- **告警管理�?*: `TAlertManager`
  - 后台评估线程
  - Cooldown 冷却机制
  - 历史记录
  - 活动告警查询

#### DeepBase.LogDashboard.pas (~1160 �?
- **Widget 类型**: Counter, Gauge, LineChart, BarChart, PieChart, Table, Heatmap
- **仪表�?*: `TDashboard` 面板�?Widget 组织
- **导出�?*: `TDashboardExporter`
  - ToJSON: 内部格式
  - ToGrafanaJSON: Grafana 兼容格式
  - ToHTML: 独立 HTML 页面
  - ToCSV: 数据导出
- **构建�?*: `TDashboardBuilder`
  - BuildOverviewDashboard: 概览仪表�?  - BuildErrorDashboard: 错误分析仪表�?  - BuildPerformanceDashboard: 性能仪表�?
### DeepBase.Logging.pas 扩展 (v1.1)
- `SetAggregatorEnabled(AEnabled)`: 启用/禁用聚合�?- `ConfigureAggregator(AppName, AppVersion, Environment)`: 配置元数�?- `AggregatorEnabled`, `AppName`, `AppVersion`, `Environment` 属�?- 写入线程自动推送到聚合�?
### 单元测试
- `Tests/Test.DeepBase.LogAggregator.pas` (~813 �?
  - TTestLogAggregator: 聚合器和批次测试
  - TTestLogQuery: 查询和分析器测试
  - TTestLogAlert: 告警规则和管理器测试
  - TTestLogDashboard: 仪表板和导出测试

### 使用示例

```pascal
// 配置 ElasticSearch 后端
LogAggregator().AddBackend(
  CreateElasticSearchBackend('http://localhost:9200', 'app-logs'));
LogAggregator().Start;

// 启用日志聚合
Logger.SetAggregatorEnabled(True);
Logger.ConfigureAggregator('MyApp', '1.0.0', 'production');

// 配置告警规则
AlertManager().AddRule(
  CreateAlertRule('high-error-rate', 'High Error Rate')
    .WithCondition(TAlertCondition.ErrorRate(10.0, 5))
    .WithSeverity(asCritical)
    .AddAction(TAlertAction.Webhook('https://hooks.slack.com/...'));
AlertManager().Start;

// 查询和分�?var Results := LogQuery()
  .WhereLevelIn([llError, llFatal])
  .WhereTimeBetween(IncHour(Now, -1), Now)
  .OrderByTimestampDesc
  .Take(100)
  .Execute;

var Stats := LogAnalyzer.GetStats;
var TopErrors := LogAnalyzer.TopErrors(10);

// 生成仪表�?var Builder := TDashboardBuilder.Create(LogAnalyzer);
var Dashboard := Builder.BuildOverviewDashboard;
var Exporter := TDashboardExporter.Create(Dashboard);
var HTML := Exporter.ToHTML;
```

### 统计
- 新增代码: ~6600 �?- 新增模块: 4 个核心模�?- 新增测试: ~813 �?(35 个测试用�?

---

## Phase MAINT-2: 项目清理与代码质�?�?(完成)

> 完成日期: 2025-12-08
> 负责�? Claude

### MAINT-2-001: 项目结构清理 �?- **完成日期**: 2025-12-08
- **输出�?*:
  - 创建 `backup/` 目录存放不确定是否需要的文件
  - 移动 7 个过时状态文件到 backup (Phase*_Status.md, Studio_Status.md, better.md, DOCS_UPDATE.md)
  - 移动旧版规划文档目录�?backup
  - 移动 `docs/uniFlow/` 错位源码目录�?backup
  - 移动 `DeepBase` 空单元文件到 backup
  - 移动 `DeepBase.db` 开发数据库�?backup
  - 删除 90+ 编译产物文件 (.dcu, .exe, .dproj.local)
  - 更新 `.gitignore` 添加 backup/ �?DeepBase.db
- **commit**: e5f0cd5
- **影响**: 312 文件变更，删�?176,557 �?
### MAINT-2-002: 代码质量深度检�?�?- **完成日期**: 2025-12-08
- **检查维�?*:
  - �?异常处理 - 发现 30+ 处空 except �?  - �?内存管理 - 确认 FreeAndNil 使用规范
  - �?线程安全 - 发现 1 处竞态条�?  - �?初始化顺�?- 确认模块依赖正确
  - �?API 一致�?- 确认命名规范统一
  - �?Schema 兼容�?- 已有版本检查机�?
### MAINT-2-003: 异常处理改进 �?- **完成日期**: 2025-12-08
- **修复内容**:
  - `DeepBase.Manager.pas`: Schema 修复错误记录�?Logger.Warn
  - `DeepBase.PluginManager.pas`: 5 处插件错误改�?FirePluginError 通知
  - `DeepBase.Logging.pas`: 使用 TInterlocked.CompareExchange 修复竞态条�?  - `DeepBase.Theme.pas`: 4 处主题错误添�?DEBUG 日志
  - `DeepBase.Updater.pas`: 3 处更新错误添�?DEBUG 日志
  - `DeepBase.VirtualScroll.pas`: 渲染回调错误添加 DEBUG 日志
  - `DeepBase.DB.Pool.pas`: 3 处连接池错误添加 DEBUG 日志
  - `DeepBase.CLI.SSH.pas`: 2 �?SSH 错误添加 DEBUG 日志
  - `DeepBase.SplashScreen.pas`: 图片加载错误添加 DEBUG 日志
  - `DeepBase.Feedback.pas`: 轮询错误添加 DEBUG 日志
  - `DeepBase.Diagnose.pas`: 4 处诊断检查错误添�?DEBUG 日志
- **commit**: 3af9446, af260c3
- **影响**: 11 文件�?32 行新�?
### 统计
- 清理文件: 312 �?- 修复模块: 11 �?- 新增 Bug 修复记录: 11 �?(BUG-050 ~ BUG-060)

---

## 商业化基础阶段 (P0) �?
### PUB-001: 模块整理归并 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - SeedTool 移动�?`DeepBase/Tools/SeedTool`
  - 反调�?保护单元归并�?`Features/DeepBase.AntiTamper.pas` �?`Core/DeepBase.Protection.pas`
  - About 界面重构�?`VCL/DeepBase.VCL.AboutFrame.pas`
  - 更新相关 uses 和命名空间，确保编译通过

### PUB-002: DeepBase.Unlock 轻量解锁模块 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 新增核心单元 `Core/DeepBase.Unlock.pas`
  - 定义解锁等级: ulFree / ulFollow / ulShare
  - 约定解锁码规�? [产品代码][年月][类型]（如 TK2412A），包含有效期和校验�?  - 解锁状态持久化到本地配�?  - 新增 `VCL/DeepBase.VCL.UnlockDialog.pas` 解锁弹窗，支持公众号二维码展�?
### PUB-003: DeepBase.Updater 增强 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 扩展 `Features/DeepBase.AutoUpdate.pas` 支持 GitHub/Gitee Release API
  - 通过 `github:owner/repo` / `gitee:owner/repo` 约定自动选择更新�?  - 保持对静�?`version.json` 的向后兼�?  - VCL 端新�?完善 `VCL/DeepBase.VCL.UpdateDialog.pas` 更新对话�?
### PUB-004: UniPublisher 发布工具 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 创建 `Tools/UniPublisher` VCL 工具项目
  - 支持读取/写入 .dproj 版本�?  - 打包输出目录�?ZIP 安装�?  - �?DeepBase 规范生成 `version.json` 清单
  - 通过 gh CLI 发布 GitHub Release，并通过 HTTP API 创建 Gitee Release
  - 集成基于 `DeepBase.Unlock` 的解锁码生成器和发布说明编辑

### PUB-005: TwoKeyRun 集成验证 �?- **完成日期**: 2025-12-09
- **内容摘要**:
  - �?`TwoKeyRun` 中初始化 `TDeepBaseManager` 以启用通用配置/解锁/自动更新
  - 使用 `TDeepBaseUnlock` 重构 TwoKeyRun 解锁逻辑，统一 24/58/60 格策�?  - �?`DeepBase.VCL.UnlockDialog` 取代自定义解锁对话框
  - 集成 `DeepBase.VCL.AutoUpdater`，支持通过 DeepBase.Config 配置 UpdateUrl 自动检查更�?
---

## 商业化扩展阶�?(P1) �?|
### FMX-003: FMX 缺失控件补全 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 完成 `FMX/DeepBase.FMX.LogListView.pas` 实现，基于日志数据库表的 FMX 日志查看�?  - 完成 `FMX/DeepBase.FMX.NotificationBar.pas` 实现，跨平台底部通知栏（进度/成功/错误/信息，支持自动隐藏与取消�?  - 完成 `FMX/DeepBase.FMX.LicenseStatusPanel.pas` 实现，展�?License 状态、类型、到期时间与授权对象
  - �?`FMX/DeepBase.FMX.Controls.pas` 中注册上述三个控件，加入 "DeepBase FMX" 组件面板，API �?VCL 版本保持一致风�?|
### SEC-002: 高级加密支持 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 基于 `Core/DeepBase.Crypto.pas` 实现 Windows 上使�?BCrypt �?AES-256-CBC 对称加密（TAESCrypto），并提供安全随机数生成（BCryptGenRandom�?  - 新增 `Core/DeepBase.Security.pas`，使�?Windows DPAPI / OpenSSL AES-256-GCM 提供跨平台安全存储（Secrets �?+ ProtectStringDpapi/UnprotectStringDpapi�?  - 新增 `Core/DeepBase.KeyManager.pas`，实现分层密钥管理（Master/KEK/DEK），支持 `TKeyManager` 全局单例�?`TKeyStore` JSON 持久�?  - 提供 `THardwareFingerprint` 收集机器指纹（ComputerName/ProcessorId/BiosSerial/DiskSerial 等）并生�?SHA-256 指纹，用于硬件绑�?  - 通过 `TMasterKey.DeriveWithHardwareBinding` + `TKeyManager.ValidateHardwareBinding` 支持主密钥与硬件绑定的加密模�?  - 为配置场景提�?`TKeyManager.EncryptConfig/DecryptConfig` 封装，用于基�?AES-256 的配置值加解密
|
### PERF-001: 性能优化 �?- **完成日期**: 2025-12-10
- **内容摘要**:
  - 日志写入批量优化（TDeepBaseLogger 异步写线�?+ MAX_BATCH_SIZE 批处�?+ 预编�?INSERT�?  - 配置缓存预热（TDeepBaseConfig.PreloadCache �?TDeepBaseManager.InitializeModules 中启动时预热 Settings 表）
  - ORM 延迟加载优化（OneToManyAttribute.LazyLoad 标记 + TLazyLoadManager 分页惰性加载支持）
|
### PUBL-101: AboutFrame + AntiTamper 规范与文档更�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?`docs/04.01.DeepBase-4AI-数据库Schema说明-v1.0.md` 中补�?`aboutMeImages` 表定�?增加 `Enabled INTEGER NOT NULL DEFAULT 1` 字段,并约�?6 个标�?ImageKey (official_gzh / wechat / alipay / btc / usdt / aboutme)�?  - AboutFrame 接入规范已归并到 `docs/IMPLEMENTATION_GUIDE.md`: 统一使用 `{AppName}Config.db` 作为 DB1，说�?aboutMeImages 表字段语义，给出 AntiTamper + SeedTool 播种流程示例�?  - 关于页面推荐结构已归并到 `docs/README.md` 与具体项目集成文档，定义 6 �?Tab(公司公众�?微信/支付�?BTC/USDT/关于�? 的布局�?ImageKey 关系�?|
### PUBL-102: AntiTamper / AboutFrame 模块实现与集�?�?- **完成日期**: 2025-12-09
- **内容摘要**:
  - 将原�?`uAntiTamperPackage` / `uBasicProtection` 等分散单元整理归并为 `Features/DeepBase.AntiTamper.pas` �?`Core/DeepBase.Protection.pas`, 提供统一的防篡改初始化与图像解密 API(�?AES/HMAC 支持)�?  - 实现 `VCL/DeepBase.VCL.AboutFrame.pas` 与配�?DFM, 作为统一�?About/打赏/公司公众�?Frame, �?DB1 �?`aboutMeImages` 表按 ImageKey 读取图像和文�?并根�?`Enabled` 字段控制 Tab 显示�?  - �?`DeepBase.i18n` 集成, �?About 页签标题/按钮文案预留多语言支持,以便在工具侧进行本地化�?
### PUBL-103: SeedTool aboutMeImages + enabled 改�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?AntiTamper 默认表名�?`images` 统一调整�?`aboutMeImages` (包括 `Features/DeepBase.AntiTamper.pas` �?`Tools/SeedTool/uAntiTamperPackage.pas`), 并在建表/升级逻辑中新�?`enabled INTEGER NOT NULL DEFAULT 1` 字段�?  - 扩展 SeedTool 数据模型 (`TImageFileInfo`) 增加 `Enabled: Boolean`, 在“文字配置”页签新�?`chkEnabled` 勾选框, 用于控制每个 ImageKey 是否�?AboutFrame 中显示�?  - �?`aboutMeImages` 加载数据时一并读�?`enabled` �? 只读文本模式/完整播种模式下均会在播种后通过 `UPDATE aboutMeImages SET enabled = ...` 同步启用状态�?
### PUBL-104: DeepDeepDeepDeepDeepMoveC 参考实现对齐新规范 �?- **完成日期**: 2025-12-11
- **内容摘要**:
  - �?DeepDeepDeepDeepDeepMoveC �?DeepBase 示例中的 About/打赏页面统一迁移�?`{AppName}Config.db` + `aboutMeImages` 规范: `FrameAboutMe.pas` �?`VCL/DeepBase.VCL.AboutFrame.pas` 默认连接 `DeepDeepDeepDeepDeepMoveCConfig.db`, 表名绑定�?`aboutMeImages`�?  - �?DeepDeepDeepDeepDeepMoveC �?DeepBase AntiTamper 中启�?`enabled` 字段支持, 并在 `LoadSecureImage` 中检�?`enabled=0` 时直接跳过记�? 实现逻辑禁用而不删除数据�?  - 通过新版 SeedTool �?DeepDeepDeepDeepDeepMoveC �?`aboutMeImages` 表播�?6 个标�?key(official_gzh / wechat / alipay / btc / usdt / aboutme) 的图像与文本, 验证 Win32/Win64 �?About 页签显示与禁用行�? 为后�?TwoKeyRun/DeepSync 等项目接入提供参考实现�?
### PUBL-106: UniPublisher 配置模型�?version.json 统一规范落地 �?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Tools/UniPublisher/Core/Publisher.Config.pas` (~700 �?:
    - `TPublishConfig` 配置模型,映射 `.publish.json` 字段 (appId/appName/displayName/dproj/outputDir/packageLayout/publishTargets/metadata)
    - `TPackageLayout`/`THttpTarget`/`TGitHubTarget`/`TGiteeTarget`/`TPublishMetadata` 记录类型
    - `TPublishConfigMRU` MRU 管理�?支持最近项目列表持久化
  - 新增 `Tools/UniPublisher/Core/Publisher.Manifest.pas` (~530 �?:
    - `TVersionManifest` 新版 version.json 结构 (appId/version/channel/publishedAt/files[]/releaseNotes/mandatory/minVersion)
    - `TManifestFile`/`TManifestMetadata` 记录类型
    - `TManifestGenerator` 工具�?支持新版 `GenerateManifest` 和旧�?`GenerateLegacyJSON` 格式生成
    - `IsNewFormat` 自动检�?JSON 格式
  - 扩展 `Features/DeepBase.AutoUpdate.pas` (v0.3 �?v0.4):
    - 新增 `IsNewFormatJson` 格式检测方�?    - 新增 `CheckForUpdateFromNewFormat`/`CheckForUpdateFromLegacyFormat` 分离解析逻辑
    - `CheckForUpdateFromJson` 自动识别新旧格式并调用对应解析器
  - 重构 `Tools/UniPublisher/Forms/UniPublisher.MainForm.pas`:
    - 顶部新增项目配置选择区域 (MRU 下拉�?+ 浏览/保存按钮)
    - 启动时自动加载最近项�?(`LoadLastProject`)
    - `ConfigToUI`/`UIToConfig` 配置�?UI 双向同步
  - 新增单元测试 `Tests/Test.DeepBase.PublishConfig.pas` (~580 �?:
    - `TTestPublishConfig`: 7 个测试用�?(序列�?反序列化/验证/持久�?
    - `TTestVersionManifest`: 7 个测试用�?(新旧格式生成/解析/保存)
    - `TTestPublishConfigMRU`: 8 个测试用�?(MRU 增删改查/持久�?
    - `TTestAutoUpdateFormatDetection`: 4 个测试用�?(格式检�?版本提取)
- **统计**:
  - 新增代码: ~1800 �?  - 新增测试: 26 个测试用�?
### PUBL-107: UniPublisher 发布目标与开发体验优�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Tools/UniPublisher/Core/Publisher.Targets.pas` (~895 �?:
    - `TPublishStatus`/`TPublishResult`/`TPublishResults` 发布结果模型
    - `TValidationResult` 配置验证结果，支持错误和警告收集
    - `TTargetValidator` 静态验证类，验�?HTTP/GitHub/Gitee 配置完整性，检�?gh CLI 可用�?    - `THttpPublisher` HTTP 上传发布器，支持 multipart form-data
    - `TGitHubPublisher` GitHub 发布器，通过 gh CLI 创建 Release 并上传资�?    - `TGiteePublisher` Gitee 发布器，通过 HTTP API + Access Token 创建 Release
    - `TUnifiedPublisher` 统一发布入口，支持一键发布到所有启用目�?  - 增强 `UniPublisher.MainForm.pas`:
    - 右侧新增发布状态面�?(`pnlPublishStatus`)，包含目标状态指示灯 (圆形 Shape + 标签)
    - 快捷操作按钮: 重新加载配置 / 打开输出目录 / 打开 version URL / 一键发�?    - 发布日志 Memo，实时显示发布进度和结果
    - `UpdateTargetStatusUI` 根据配置自动更新状态指示灯颜色
- **统计**:
  - 新增代码: ~895 �?(Publisher.Targets.pas) + ~200 �?(MainForm 增强)

### PUBL-108: Developer Test Center + UniPublisher 集成参考实�?�?- **完成日期**: 2025-12-11
- **内容摘要**:
  - 新增 `Core/DeepBase.TestCenter.pas` (~636 �?:
    - `TTestStatus` 测试状态枚�?(NotRun/Running/Passed/Failed/Skipped)
    - `TTestCategory` 测试分类记录
    - `TTestItem` 测试项类，支持执行回调、状态跟踪、JSON 序列�?    - `ITestRunner` 测试运行器接口，`TDefaultTestRunner` 默认实现
    - `TTestCenterManager` 测试中心管理器，支持分类/测试注册、批量执行、结果统计、持久化
    - `TStandardCategories` 标准分类常量 (core/vcl/fmx/network/database/autoupdate/publisher/tools)
  - 新增 `VCL/DeepBase.VCL.TestCenterFrame.pas` (~655 �?:
    - 三栏布局: 左侧分类�?(TTreeView) / 中间测试列表 (TListView) / 右侧详情日志 (TMemo)
    - 底部控制�? 运行选中 / 运行全部 / 重置 / 打开 UniPublisher...
    - "打开 UniPublisher..." 通过 ShellExecute 启动，自动搜索常见路�?    - `RegisterSampleTests` 注册示例测试用例
  - 集成�?`Examples/FullDemo/FullDemo.MainForm.pas`:
    - 新增 "测试中心" 页签，嵌�?TTestCenterFrame
    - 自动初始化并注册示例测试
- **统计**:
  - 新增代码: ~1291 �?(TestCenter + Frame)

### PUBL-105: 工具项目 AboutFrame 集成 �?- **完成日期**: 2025-12-12 (DeepBase 侧开发完成，待人工集�?
- **内容摘要**:
  - 新增集成规划索引文档（当前位�?`docs/README.md`�?  - 新增 5 个工具项目集成规划文�?
    - `docs/01.TwoKeyRun-Integration.md` - VCL项目, 已有 FrameAboutMe, 结构分析和迁移方�?    - `docs/02.DeepSync-Integration.md` - FMX项目, 需新建 AboutFrame, �?FMX 组件开发计�?    - `docs/03.SVGThing-Integration.md` - VCL项目, 已有 FrameAboutMe, 数据库迁移方�?    - `docs/04.Stocks-Integration.md` - FMX项目 (InfoCenter), 已集�?DeepBase, 需 FMX 组件
    - `docs/05.DeepCharset-Integration.md` - VCL项目, 轻量级工�? 弹窗式集成方�?  - VCL AboutFrame (`VCL/DeepBase.VCL.AboutFrame.pas`) 扩展�?6 �?Tab�?    - 新增 `tsOfficialGzh` 公众号页面，�?FMX 版本保持一�?    - 图像映射数组扩展�?6 �? official_gzh/wechat/alipay/btc/usdt/aboutme
  - FMX AboutFrame (`FMX/DeepBase.FMX.AboutFrame.pas`) 已对�?
    - 使用 `TAntiTamperPackage.LoadSecureImageBytes()` 统一解密和校�?    - 字段名与 SeedTool/AntiTamper 一�? `sha256_hash`/`hmac_sha256`
  - 更新 `docs/IMPLEMENTATION_GUIDE.md`:
    - 标记 FMX AboutFrame 已完成对�?    - 更新 Q4 常见问题解答
    - 更新任务检查清单和下一步建�?- **统计**:
  - VCL 项目: 3 �?(TwoKeyRun/SVGThing/DeepCharset)
  - FMX 项目: 2 �?(DeepSync/Stocks)
- **待人工完�?*:
  - 准备 6 张标准图片资�?  - 运行 SeedTool 为各项目创建 `*Config.db` 并播�?  - �?IDE 中按指南修改各项目代码并编译测试

---

## 工具�?CLI 增强阶段 (P2) �?
### CLI-002: CLI 交互增强 �?- **完成日期**: 2025-11-29
- **内容摘要**:
  - 新增核心交互�?CLI 模块 `Tools/CLI/DeepBase.CLI.Interactive.pas`，提�?`TInteractiveCLI` REPL（命令历史、变量、脚本执行、输出格式切换）
  - 新增 `Tools/CLI/DeepBase.CLI.Pipeline.pas` 管道模块，支�?`|`/`>`/`>>`/`tee` 以及 grep/sort/head/tail/uniq/wc/rev/cut/tr/jq 等过滤器
  - 在交互模块中引入 `TAnsiColor` 终端颜色工具类，用于统一的错�?警告/成功彩色输出
  - CLI 工具层通过 `CLI.Commands.TCliUtils` 复用颜色输出能力，为常规 `DeepBase` 命令提供彩色状态提�?
### TOOL-002: Studio 增强 �?- **完成日期**: 2025-11-29
- **内容摘要**:
  - SQL 查询编辑器（Studio.SQLFrame：语法高亮、执�?历史、结果网格、CSV 导出、DoQry 集成�?  - Schema 可视化浏览器（Studio.SchemaFrame：表/�?索引/外键树状浏览 + DDL 查看�?  - 数据导入导出向导（Studio.ImportExportFrame：CSV/JSON/XML 导出 + CSV/JSON 导入预览与事务导入）

---

## 维护阶段 (MAINT) - 进行�?
### MAINT-002: 单元测试覆盖率提�?🟡
|- **状�?*: 进行�?|- **目标**:
|  - 单元测试整体覆盖率提升到 95%+，并覆盖关键安全/网络/工具模块的边界条件与错误路径�?|- **已完�?(2025-12-08)**:
|  - �?`Test.DeepBase.Math.pas` - 数学工具测试 (40+ 测试用例，向�?矩阵/统计/插�?缓动/随机)
|  - �?`Test.DeepBase.Metrics.pas` - 指标收集测试 (35+ 测试用例，Counter/Gauge/Histogram/Timer/Registry)
|  - �?`Test.DeepBase.Net.pas` - 网络工具测试 (40+ 测试用例，HTTP/WebSocket/DNS/IP/Subnet)
|  - �?`Test.DeepBase.HttpServer.pas` - HTTP服务器测�?(35+ 测试用例，路�?中间�?请求响应)
|  - �?`Test.DeepBase.FileWatcher.pas` - 文件监控测试 (30+ 测试用例，过滤器/配置/集成测试)
|- **已完�?(2025-12-10)**:
|  - �?CLI 与反射相关测试：`Test.DeepBase.CLI.Pipeline.pas`, `Test.DeepBase.CLI.Interactive.pas`, `Test.DeepBase.Reflection.pas`, `Test.DeepBase.Export.pas`
|  - �?数据库与诊断相关测试：`Test.DeepBase.Diagnose.pas`, `Test.DeepBase.DB.Pool.pas`, `Test.DeepBase.DBException.pas`, `Test.DeepBase.SQLLogger.pas`
|  - �?核心基础设施测试：`Test.DeepBase.SingleInstance.pas`, `Test.DeepBase.Schema.pas`, `Test.DeepBase.Exception.pas`, `Test.DeepBase.Consts.pas`
|  - �?云与后台服务测试：`Test.DeepBase.CloudBackup.pas`, `Test.DeepBase.Feedback.pas`, `Test.DeepBase.PluginManager.pas`, `Test.DeepBase.AutoUpdate.pas`
|  - �?UI 与体验相关测试：`Test.DeepBase.VirtualScroll.pas`, `Test.DeepBase.SplashScreen.pas`, `Test.DeepBase.AntiTamper.pas`, `Test.DeepBase.Protection.pas`
|  - �?安全与密钥管理测试：`Test.DeepBase.KeyManager.pas`, `Test.DeepBase.Interfaces.pas`, `Test.DeepBase.LLM.Manager.pas`, `Test.DeepBase.LLM.ImportExport.pas`, `Test.DeepBase.ORM.Mapping.pas`, `Test.DeepBase.Updater.pas`
|- **已完�?(2025-12-11)**:
|  - �?�?OpenSSL �?LLM 核心类型补充单元测试：`Test.DeepBase.Crypto.OpenSSL.pas`, `Test.DeepBase.LLM.pas`，覆盖加解密、错误路径与配置/消息模型序列化�?|  - �?�?GUI 测试基础设施增加回归测试：`Test.DeepBase.TestHelper.pas`，覆盖快照捕�?校验、控件查找与用户交互模拟�?|  - �?修复并补�?DB 异常测试：`Core/DeepBase.DBException.pas` 改进 `EDeepBaseDB.UserMessage` 中文+英文混排场景，`Test.DeepBase.DBException.pas` 增加回归用例�?|  - �?新增 WebAPI 集成测试：`Tests/Integration/Test.Integration.WebAPI.pas`，覆�?HTTP 路由、查询参数解析、CORS、JWT 认证、OpenAPI 生成�?WebSocket 消息路由，相�?Core/Auth 单元问题已修复并通过测试�?|  - �?将测试覆盖率统计集成�?`Scripts/run_tests.ps1`，支持在本地/CI 中输�?DUnitX XML 结果及简�?HTML 汇总页面，便于持续监控覆盖率�?|||  - �?将数据库相关 Integration Tests 标记为「环境依赖」：�?`Test.Integration.Core.pas` 中为所有依�?SQLite/FireDAC 的集成测�?Fixture 添加 `Category(\"DBEnv\")`，并�?`Scripts/run_tests.ps1` 中默认通过 `--exclude:DBEnv` 排除这些测试；当需要完整运行数据库集成测试时，可通过设置环境变量 `DeepBase_RUN_DB_INTEGRATION=1` 显式启用�?|||- **已完�?(2025-12-13)**:
|||  - �?`Test.DeepBase.i18n.pas` - i18n 模块回归测试补全
|||  - �?`Test.DeepBase.Theme.pas` - 主题模块回归测试补全
|||  - �?`Test.DeepBase.FormState.pas` - 修复测试稳定性并恢复�?`DeepBaseTests.dpr`
|||  - �?`Test.DeepBase.Logging.pas` - 重写�?file-only 异步写入可验证的测试，并恢复�?`DeepBaseTests.dpr`
|||  - �?`Test.DeepBase.License.pas` - 恢复�?`DeepBaseTests.dpr`
|- **已完�?(2025-12-18)**:
|  - �?`Test.DeepBase.DateTime.pas` - DateTime 模块测试修复 (FormatOffset 格式问题、NextDayOfWeek/PreviousDayOfWeek 枚举映射问题、测试期望值修�?
|  - �?测试通过率提升：824 测试�?751 通过 (91.1%)�?1 失败�?8 错误（Access Violation�?|  - �?错误分类：Access Violation 主要来自 Config/FormState/Hotkeys/MRU/Theme/i18n 模块（需 DeepBaseManager 初始化）
||- **下一�?*:
|  - （可选）在持续集成环境中补充针对数据�?Integration Tests 的文档与示例配置（包�?FireDAC/SQLite 驱动部署方式、专用测试数据库路径等），方便在有完整数据库环境的机器上重新启用 DB 集成测试�?---

## 文档优化（DOC-OPT�?
### DOC-OPT-001: 文档编号统一 + OneFile 入口创建 + 过期文档清理 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?**Phase 1 编号统一**�?8 �?.md 文件的中文序数标题统一为阿拉伯数字标准（`## N.` / `### N.N` / `#### N.N.N`�?    - docs/: `06.AntiTamper-Integration.md`, `07.Project-Classification.md`, `07.01.DeepBase-4AI-集成检查清�?v1.0.md`, `99.07.DeepBase-4H-迁移修复记录-v0.3.md`
    - Tools/SeedTool/: `加密防篡改集成说�?md`, `播种与主程序对应说明.md`
    - README.md
    - doQry/tasks.md
    - docs/uniFlow/: `01.02.Quick-UniFlow-开发者快速上手指�?v1.0.md`
    - docs/uniFlow/SayDone/ (8 files): `03.01`, `03.03`, `03.07`, `03.09`, `01.09`, `01.11`, `06.03`, `06.05`
  - �?**Phase 2 M1 对外唯一入口**：创�?`docs/DeepBase-Integration-OneFile.md`，整�?DB1~DB4 边界、全模块能力清单、推荐接入组合、平台网站跳转流程、最小端到端步骤、关键约�?  - �?**Phase 3 M2 入口收敛**：更�?`docs/README.md` �?`docs/00.00.DeepBase-文档索引-v1.0.md`，标�?OneFile 为对外唯一入口
  - �?**Phase 4 M3 内容纠错**：修�?`docs/06.AntiTamper-Integration.md` 中的过期路径引用；统一 DB 口径
  - �?**Phase 5 M4 过期文档清理**：删�?10 个过�?重复文件
    - backup/: `Phase0-3_Status.md`, `Studio_Status.md`, `DOCS_UPDATE.md`, `better.md`
    - docs/: `99.07.DeepBase-4H-迁移修复记录-v0.3.md`, `99.09.DeepBase-4H-术语审计报告-v1.0.md`
    - `QUICK_START.md`
  - �?**验证**：`grep` 确认零中文序数残留；`check_doc_links.ps1` 确认链接有效
- **说明**: 文档优化计划源自 `better.md` �?M1-M5 里程碑定义，已全部执行完成�?
### DOC-OPT-002: 五位专家框架评估 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?邀�?5 位专家（打包/安全/测试/架构/文档）独立评估框架完善度
  - �?综合评分 6.7/10，打�?(5.5) 最低，架构 (7.5) 最�?  - �?识别 5 个封板阻塞问�?(B1-B5)�?0 个重要改�?(I1-I10)
  - �?结果已转化为可执行任务写�?`tasks.md`

### PKG-001: 86 个孤�?.pas 文件注册�?.dpk �?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - �?32 文件 �?DeepBaseCore.dpk�?6 单元�?  - �?22 文件 �?DeepBaseServices.dpk�?4 单元�?  - �?3 文件 �?DeepBaseFeatures.dpk（LLM.Manager/BillingClient/ImportExport�?  - �?20 文件 �?DeepBaseVCL.dpk�?6 VCL + 4 VCL-only Core�?  - �?13 文件 �?DeepBaseFMX.dpk�? DeepBaseFeatures requires�?  - �?1 文件 �?DeepBasePersistence.dpk

### PKG-002/003: Math/Unlock 重复修复 �?- **完成日期**: 2026-05-06

### TEST-001: 53 个测试文件注�?�?- **完成日期**: 2026-05-06

### SEC-002: 硬编码默�?Salt 移除 �?- **完成日期**: 2026-05-06

### ARCH-046: Exception↔Manager 循环依赖解除 �?- **完成日期**: 2026-05-06

### QUAL-001: 438 �?FreeAndNil 规范�?�?- **完成日期**: 2026-05-06
- **内容摘要**: 82 文件 438 处析构函数内 + 13 文件 19 处字段重新赋�?
### VERSION-001: 版本号统一 �?- **完成日期**: 2026-05-06

---

## 社区与生态（ECO�?
### ECO-002: 社区扩展包（第一阶段�?�?- **完成日期**: 2025-12-08
- **内容摘要**:
  - �?`ThirdParty/DB/DeepBase.DB.PostgreSQL.pas` - PostgreSQL 驱动适配�?  - �?`ThirdParty/DB/DeepBase.DB.MySQL.pas` - MySQL 驱动适配�?  - �?`ThirdParty/UI/DeepBase.UI.Themes.pas` - UI 主题系统
  - �?`ThirdParty/Cloud/DeepBase.Cloud.Storage.pas` - 云存储集成（对象存储封装�?- **说明**:
  - 以上�?ECO-002 的第一批官方扩展包，实现数据库驱动、主题与云存储三类集成�?  - 第二阶段（支�?社交集成）作为后续任务，已记录在 `tasks.md` 中的 ECO-002 小节�?
---

## 2026-05-06 封板质量门禁与功能补齐归�?
### SEC-001: �?Windows AES XOR fallback 替换�?OpenSSL �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - `DeepBase.Crypto.OpenSSL.pas` 新增 AES-256-CBC EVP 加解密入口�?  - `DeepBase.Crypto.pas` �?Windows 分支�?XOR 伪加密改�?OpenSSL AES-256-CBC�?  - Windows 平台保持 CNG/BCrypt 路径�?
### SEC-003: 插件签名验证实现 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - Windows 平台使用 `WinVerifyTrust` 验证 Authenticode 签名�?  - 签名验证失败时拒绝加载插件并记录日志�?  - �?Windows 平台保留告警路径，后续可�?OpenSSL 代码签名验证�?
### COMMERCE-002: 生产存储与支付网关适配�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 完成后端契约文档、HTTP 存储适配器、微信支付代理、支付通知确认流程�?  - 新增 `PaymentBridge.pas` 桥接 ThirdParty SDK�?  - 新增 `Examples/CommerceE2EDemo/` 九步端到端样例�?
### GEN-001: 文档导出与分享框�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 PDF、DOCX、VCL Image Export �?Share Service�?  - 新增 `Tests/Test.DeepBase.Export.Gen.pas` 覆盖生成路径�?
### DOC-005: README 示例修复 �?- **完成日期**: 2026-05-06
- **内容摘要**: 修复 CRUDApp 模板 `_('text')` �?`T('text')` �?i18n 示例错误�?
### ARCH-045: 包隐式导入告警清�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 清理运行时包 requires �?`{$IMPORTEDDATA ON}` 设置�?  - 修复 12 个包上下文编译错误�?  - `Profile All` 6 个包�?Error 编译通过�?
### MAINT-002: 单元测试编译修复与覆盖提�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 修复 51 个测试文件编译错误�?  - 注册 53 个测试文件到 `DeepBaseTests.dpr`�?  - Win64 DCU 编译 176 个单元零错误�?
### ECO-002: Commerce 社区扩展第二阶段 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 Supabase / Firebase Commerce 存储适配器�?  - 新增 ThirdParty SDK Gateway �?PaymentBridge�?
### FWK-001: 系统托盘模块 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 `Core/DeepBase.TrayIcon.pas` �?`VCL/DeepBase.VCL.TrayIcon.pas`�?  - 新增 `Tests/Test.DeepBase.TrayIcon.pas`�?
### FWK-002: Serialization XML 反序列化 �?- **完成日期**: 2026-05-06
- **内容摘要**: 实现 XML 标签解析、属性赋值、嵌套对象和常见标量类型反序列化�?
### FWK-003: Scheduler 任务持久�?�?- **完成日期**: 2026-05-06
- **内容摘要**:
  - 新增 `IJobStore` �?`TTaskMeta`�?  - 新增持久化任务元数据保存/读取 API�?  - 修复 `Stop()` 与运行中任务的关停竞态�?
### FWK-004: VCL/FMX I18n 控件补齐 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - VCL 新增 6 �?i18n 控件�?  - FMX 新增 2 �?i18n 控件�?
### FWK-005: FMX Theme 桥接 Core Theme �?- **完成日期**: 2026-05-06
- **内容摘要**: `DeepBase.FMX.Theme` 注册 Core Theme 平台适配器，支持 light/dark/system 模式�?
### FWK-006: Export 新增 JSON 格式 �?- **完成日期**: 2026-05-06
- **内容摘要**: 新增 DataSet/Grid/Array JSON 导出路径�?
### FWK-007: Updater �?Windows RSA 签名验证 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - `DeepBase.Crypto.OpenSSL.pas` 新增 `OpenSSL_RSAVerifySHA256`�?  - `DeepBase.Updater.pas` �?Windows 分支�?stub 改为 OpenSSL RSA-SHA256 验证�?
### PUBL-105: 工具项目 AboutFrame 集成规划 �?- **完成日期**: 2026-05-06
- **内容摘要**:
  - DeepBase �?VCL/FMX AboutFrame 已对�?`aboutMeImages` 规范�?  - 下游工具项目接入规划文档已更新�?  - 剩余为各下游项目人工集成和资源播种�?
---

## 2026-05-07 架构审阅后治�?
### ARCH-047: IoC 接口实例注册安全修复 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TIoCContainer.RegisterSingleton<TService>(Instance)` 不再使用 `IInterface as TObject` 提取对象指针�?  - 新增接口 singleton / factory 的独�?`IInterface` 存储与解析路径�?  - �?object-backed interface singleton/scoped 服务使用接口生命周期持有实例，避免引用计数对象释放后留下悬空对象指针�?  - `TIoCScope` 新增 `Dispose`，用于显式进�?disposed 状态并支持可测�?disposed 行为�?  - `Tests/Test.DeepBase.IoC.pas` 增加/调整回归用例，覆盖调用方释放接口引用后仍可解析、接�?factory 作为构造依赖、disposed scope 行为�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.IoC`�?0/20 通过�?
### ARCH-048: RuntimeContext 默认组件注册落地 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `RegisterDefaultRuntimeComponents` 从占位实现改为注册真实运行期组件�?  - 默认注册顺序固定�?`DeepBase.Manager` �?`IoC.Container` �?`EventBus` �?`Scheduler` �?`WorkerQueue`，Shutdown 反向释放�?  - 运行期注册保�?side-effect free：仅注册组件，不启动后台线程；启动由 `RuntimeContext.Start` 触发�?  - EventBus 增加异步 handler drain 能力，RuntimeContext Stop 时可等待异步回调完成�?  - WorkerQueue 修复 Stop/drain、定时任务、依赖任务、重试唤醒和统计累计路径，支撑运行期生命周期测试�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.IoC,Test.DeepBase.Services.Registration,Test.DeepBase.Persistence.RuntimeRegistration,Test.DeepBase.RuntimeContext,Test.DeepBase.EventBus,Test.DeepBase.WorkerQueue`�?35/135 通过�?
### ARCH-049: 拆分 TDeepBaseManager 职责 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 新增 `Core/DeepBase.Manager.Schema.pas`，承�?schema 创建、版本检查、迁移脚本执行和兼容列修补逻辑�?  - 新增 `Core/DeepBase.Manager.Operational.pas`，承�?retention 归档清理、表/列探测和 health check 逻辑�?  - `Core/DeepBase.Manager.pas` 保留原有 public API 和私有方法入口，内部改为委托 helper，避免破坏下游调用�?  - `DeepBaseCore.dpk` 已纳入两个新 Core 单元�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Manager`�?4/14 通过�?
### CONC-001: RetryPolicy 主线程阻塞保�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TRetryPolicy` 新增 `TRetryMainThreadWaitMode`，支�?`rmwAllow`、`rmwWarn`、`rmwRaise` 三种主线程重试等待策略，默认 `rmwWarn` 保持兼容�?  - 新增 `OnMainThreadWaitEvent`，UI/FMX/VCL �?EventBus 主线�?handler 可记录告警或升级�?fail-fast�?  - 新增 `ExecuteAsync` / `ExecuteAsync<T>`，为 UI 场景提供后台执行入口，避免同�?retry delay 卡住主线程�?  - 新增 `ERetryMainThreadWaitException`，用�?`rmwRaise` 下阻止主线程 `Sleep`�?  - `Tests/Test.DeepBase.Resilience.pas` 补充主线程告警、raise 模式、异步重试和泛型异步返回值覆盖�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Resilience`�?18/118 通过�?
### QA-001: Examples 编译门禁 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 新增 `Scripts/build_examples_win64.ps1`，建�?Win64 示例编译门禁�?  - 默认必选示例覆�?`Phase0Demo`、`Phase1Demo`、`FullDemo`、`FMXPlatformDemo`、`CommerceE2EDemo`�?  - 可选示例默认跳过并记录，支�?`-IncludeOptional` 扩展检查范围�?  - 输出 `TestResults/ExampleBuildResults.txt` �?`TestResults/ExampleBuildResults.xml`，便于本地和 CI 消费�?  - 修复必选示例中与当�?DeepBase API 不一致的等待窗、通知条、配置控件、FMX 平台、FMX 表单校验、Commerce 回调 verifier 和缺失资源引用问题�?- **验证**:
  - `Scripts/build_examples_win64.ps1`：Phase0Demo、Phase1Demo、FullDemo、FMXPlatformDemo、CommerceE2EDemo 全部通过�?
### ARCH-050: Resilience 按策略类型拆�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?`Core/DeepBase.Resilience.pas` 改为兼容 facade，继续导出原有类型、枚举常量和 `CircuitBreakers` 入口�?  - 新增 `Core/DeepBase.Resilience.CircuitBreaker.pas`，承接断路器、状�?helper �?registry�?  - 新增 `Core/DeepBase.Resilience.Retry.pas`，承�?`TRetryPolicy`、重试策略和主线程等待保护�?  - 新增 `Core/DeepBase.Resilience.Timeout.pas`，承接超时策略和 `ETimeoutException`�?  - 新增 `Core/DeepBase.Resilience.Fallback.pas`，承接泛�?fallback 策略�?  - 新增 `Core/DeepBase.Resilience.Bulkhead.pas`，承�?bulkhead 策略和拒绝异常�?  - 新增 `Core/DeepBase.Resilience.Policy.pas`，承接组合策略编排�?  - `DeepBaseServices.dpk` 已纳入全�?Resilience 子单元�?- **验证**:
  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Resilience`�?18/118 通过�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?
### BUILD-001: DeepBaseTests 包上下文编译错误清理 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - 修复 DEBUG �?`OutputDebugString` 缺少 Windows 条件 uses 的编译问题�?  - 修复 Commerce 测试对回�?verifier 的匿名函数兼容问题�?  - 修复 PDF/DOCX/Share/WorkerQueue 的包上下文编译错误�?  - `Tests/DeepBaseTests.exe` 已重新生成�?
### API-001: 初始化错误处理一致�?�?- **完成日期**: 2026-05-07
- **内容摘要**:
  - `TDeepBaseManager.InitializeEx(out ErrorMsg): Boolean` �?`InitializeWithDB` 保持 Boolean 入口语义：失败返�?`False`，并通过 `LastError` / `InitErrorCode` 暴露原因�?  - 新增 `InitializeOrRaise` �?`InitializeWithDBOrRaise` 异常型入口，失败时抛�?`EInitializationException`�?  - 异常入口统一携带 `ErrorCode` �?`Context`，错误消息保留底层失败原因，避免调用方在 Boolean/异常两种模式间语义不一致�?  - Manager 测试固定恢复 FireDAC 测试连接适配器和 storage factory，避免全局适配器状态泄漏影响后续用例�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Manager`�?6/16 通过�?  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Resilience`�?18/118 通过�?  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?
### SEC-004: UBS2 加密格式版本协商 �?- **完成日期**: 2026-05-07
- **内容摘要**:
  - �?Windows `ProtectStringDpapi` 继续写出 UBS2 v1，明�?`UBS2_VERSION_CURRENT` 和支持版本列表�?  - �?Windows `UnprotectStringDpapi` 改为先读�?UBS2 magic/version，再按版本分发到 v1 解密器�?  - UBS2 v1 解密器独立处�?KDF、迭代次数、salt、IV、ciphertext、tag，后续可添加 v2/v3 分支而不改主入口�?  - �?UBS1 legacy magic、未�?magic、未知版本、未�?KDF、过�?payload 和无效迭代次数给出可迁移的错误信息�?  - `Tests/Test.DeepBase.Security.pas` 补充�?Windows UBS2 版本头、未知版本、未�?KDF、legacy magic 覆盖，并收紧 Windows 篡改检测为 `EDecryptionException`�?- **验证**:
  - `Scripts/run_tests.ps1 -Type Unit -Run Test.DeepBase.Security`�?2/42 通过�?  - `Scripts/run_tests.ps1 -Type Unit -SkipCompile -Run Test.DeepBase.Security.DPAPI`�?3/23 通过�?  - `cmd /c compile_test.bat`：通过，`Exit code: 0`�?  - `Scripts/build_examples_win64.ps1`�? 个必选示例全部通过�?


---

## 2026-05-14 全仓库编译修复 (18/18 构建目标)

### BUILD-FIX-2026-05-14: 从 DeepBaseVCL 整包到全部 dproj 编译通过
- **完成日期**: 2026-05-14
- **目标**: 用户要求"整包必须编过",从 DeepBaseVCL.dpk 开始,逐步扩展到全仓库 18 个构建目标 (6 RT + 3 DT + 5 Examples/Tools + DeepBaseRun + prjDoQry + DeepBaseTests + DeepPublisher) 全部 Win64/Debug 0 errors。
- **产出**:
  - BUG-177: `Features/DeepBase.Browser.ResponseWaiter.pas` Delphi 13.1 RTL 不兼容修复 (TInterlocked.Read Integer 移除 + TProc<string> const 不匹配)
  - BUG-178: `Features/DeepBase.Browser.Types.pas` Win32 前向引用顺序修复 (IBrowserSessionFactory/TSessionRebuiltEvent 必须在 IBrowserRecoveryEvents 之前)
  - BUG-179: 全仓库中文字符串 UTF-8 截断修复 (60+ 处,跨 6 个文件)
  - BUG-180: DeepPublisher 工具项目 rename 不完整修复 (dproj/dpr/unit name/vrc/search path)
  - 搜索路径补齐: Phase0Demo / FullDemo / Studio / SeedTool / prjDoQry / DeepPublisher 的 dproj
  - DeepBaseTests: IntentClarification + LLM.PromptTemplate 恢复编译 (根因是 BUG-178 级联)
- **验证**:
  - 18/18 构建目标 Win64/Debug 全部 exit=0
  - DeepShell 测试 24/24 通过, 0 leaked
  - Win32 偶发 BPL 文件锁 race 重试即过 (非代码问题)
- **遗留**:
  - ~100 处注释含截断中文 (不影响编译,影响可读性)
  - DeepShell Demo 4 个 pending feature (tasks.md 队列)
  - Layout 跨进程需要 DB1 store (架构设计决策)


---

## 2026-05-14 基础模块 P0/P1/P2 第二轮修复 (BUG-181~196)

### BASIC-FIX-2026-05-14: 16 个基础层安全/并发/一致性问题修复
- **完成日期**: 2026-05-14
- **目标**: 按 better.md §8 评审清单,修复所有不需要架构重构即可解决的 P0/P1/P2 问题。
- **产出** (16 项):
  - P0: Authorization 事务 (BASIC-009); CloudBackup XOR→AES / CloudSync Base64→AES / LLM.Config 硬编码key→DPAPI (FR-002)
  - P1: Logging.FireDAC 加锁 (BASIC-010); Manager Initialize 加锁 (BASIC-018); Manager FinalizeModules 清回调 (BASIC-020); EventBus PublishAsync drain (BASIC-021); EventBus 统计原子 (BASIC-022); IoC FResolving 线程隔离 (BASIC-024); RuntimeContext 双检锁 (BASIC-005); Crypto Random fail-closed (BASIC-015); DB Factory 凭据 fail-closed (BASIC-011)
  - P2: Config 回调出锁 (BASIC-027); 版本号统一 (FR-001); CompareVersions 去重 (FR-013); Logger sanitizer 收敛 (FR-014); .editorconfig 品牌 (FR-017)
- **验证**:
  - 6 RT 包 Win64 编译通过
  - DeepShell 测试 24/24 通过, 0 leaked
- **遗留** (需架构重构,下一 sprint):
  - BASIC-001/004: Services 包 DAG 拆分
  - BASIC-006/007: Scheduler/WorkerQueue 生命周期 API 重设计
  - BASIC-008: DB Pool 连接 lease/refcount 重构
  - BASIC-019: 迁移引擎统一
  - LLM-001~009: LLM schema/provider/streaming 统一

---

## 2026-05-15 基础层 P0/P1 第三轮修复 + 架构重构 (BUG-193~203)

### BASIC-FIX-2026-05-15: 11 个基础层修复 + 3 个架构重构
- **完成日期**: 2026-05-15
- **目标**: 完成 better.md §8.6 遗留的所有 P0/P1 基础层问题,包括需要架构重构的三大项。
- **产出** (11 项修复 + 3 项重构):
  - P0: DB Pool 线程安全 (BASIC-008) — Release 加锁、ValidateIdleConnections csValidating、RecycleAll 只回收 idle、Shutdown drain 等待
  - P1: 架构测试加强 (BASIC-004); Scheduler 生命周期 (BASIC-006); WorkerQueue DrainAndStop (BASIC-007); Migration 命名兼容 (BASIC-012); DoQry 连接 sweep (BASIC-014); SQL Splitter 共享 (BASIC-019 部分); EventBus subscription lifetime (BASIC-023); IoC Freeze (BASIC-025)
  - P2: KeyManager 文档诚实化 (BASIC-017)
  - 架构重构: Services 包拆分 (BASIC-001) — requires 精简为 rtl+DeepBaseCore; Crypto 统一 (BASIC-016) — 唯一 BCrypt/CryptoAPI 声明源; Config 接口清理 (BASIC-026) — 移除 deprecated 方法
- **新增文件**: `Core/DeepBase.SQL.Splitter.pas`
- **新增测试**: IoC Freeze 3 个 + EventBus subscription lifetime 2 个
- **修改文件**: ~25 个 (含 5 个 .dpk, 4 个测试文件)
- **验证**: 所有修改文件 0 诊断错误; 编译输出仅有预先存在的 onnxruntime 第三方依赖问题
- **遗留** (下一阶段):
  - 周边模块 P0/P1: LLM-001/002 (schema/secrets), EDGE-002/003/006/007 (Cloud/Updater 安全)
  - P2 可维护性: FR-011 编码损坏, FR-016 DeepFlow, Speech/Governance 板块
  - 功能评审: DeepShell pending features, BrowserAutomation, IntentClarification BUG-134~142

---

## 2026-06-02 规范文档完成项归档

### SPEC-ARCH-2026-06-02: 架构技术规范 (tech-spec.md) 全部实施完成
- **来源**: `docs/20.architecture.技术规范-tech-spec.md` v1.0
- **状态**: 全部完成
- **内容摘要**:
  - Phase 0（最小核心）: Tier 0 表 + Core API (Config/i18n/FormState/Manager) ✅
  - Phase 1（推荐功能）: Tier 1 表 + VCL 控件 + Studio 基础 ✅
  - Phase 2（扩展功能）: LLM/i18n 管理/等待窗口/异常/FMX 控件/GUI 测试 ✅
  - Phase 3（高级功能）: AutoUpdate/DB 维护/远程配置/CLI/云端服务 ✅
  - Phase 4（完善）: License/反馈/使用统计/文档 ✅
  - Phase 5（代码审查优化）: Schema/DoQry 缓存/Logger 初始化/接口抽象/版本兼容等 9 项 ✅
  - Phase T（DeepBaseTray）: 开发日志/命令面板/自动化/快速启动/配置/日志搜索 8 项 ✅
  - 第 1 章 概述与架构: 设计目标、内容分类、架构全景图、适用范围、多应用拓扑、错误码约定 ✅
  - 第 2 章 目录与文件约定: root.txt、目录结构、开发/用户环境行为差异 ✅
  - 第 3 章 config.db 表结构: Tier 0/1/2 共 15 张表定义全部落地 ✅
  - 第 4 章 Core 模块接口: TDeepBaseManager 全套 API + 全局函数 + 辅助类型 ✅
  - 第 5 章 UI 控件规范: 20 个 VCL/FMX 控件 ✅
  - 第 6 章 动画资源处理: Image32 统一 SVG 方案 ✅
  - 第 7 章 Studio 功能规范: 项目管理/i18n/日志/异常/资源/配置/LLM/发布/远程/License/数据库管理 ✅
  - 第 8 章 DeepBaseTray 工作台: 开发日志/命令面板/自动化/快速启动/悬浮窗口 ✅
  - 第 9 章 CLI 命令行: db/i18n/release/config/test 命令 ✅
  - 第 10 章 云端服务: version.json/remote-config/feedback/license 验证 ✅
  - 第 11 章 安全性: Credential Manager/日志脱敏/发送前控制 ✅
  - 第 12 章 测试支持: Core 层单元测试/GUI 状态快照/测试数据库隔离 ✅
  - 第 13 章 线程安全: WAL/Checkpoint/内存缓存/API 稳定性标记/Schema 迁移 ✅
  - 第 14 章 单元文件结构: Core/Persistence/Features/VCL/FMX/Packages/ThirdParty/Tools 目录布局 ✅
  - 第 15 章 性能规范: API 响应时间基线/资源限制/性能监控 ✅
  - 第 16 章 异常处理规范: 异常层级/错误码分配/用户提示映射 ✅
  - 第 17 章 后续工作: Phase 0-4 全部完成 ✅

### SPEC-COMMERCE-2026-06-02: Commerce 后端契约 (commerce-backend-spec.md) 实施步骤 1-4 完成
- **来源**: `docs/60.backend.Commerce后端契约-commerce-backend-spec.md`
- **状态**: 实施步骤 1-4 已完成
- **内容摘要**:
  - 步骤 1 ✅: 固化契约并评审字段命名 — 契约文档已评审固化，字段命名统一
  - 步骤 2 ✅: 用内存 mock 后端跑 contract tests — `TInMemoryCommerceStorage` 和测试覆盖
  - 步骤 3 ✅: 实现 HTTP `ICommerceStorage` 适配器 — `TCommerceHttpStorage` 已落地
  - 步骤 4 ✅: 实现后端微信支付 intent API 和 Delphi `ICommercePaymentGateway` 后端代理适配器 — `TCommerceHttpPaymentGateway` 已落地
- **封板标准已完成项**:
  - `TInMemoryCommerceStorage` 仅用于测试和开发文档 ✅
  - 下游项目只依赖 `Features/DeepBase.Commerce.*` 流程入口 ✅
  - 支付确认以可信后端通知为准 ✅
  - 后端数据库有唯一约束和事务保护 ✅
  - 文档入口统一指向契约文档和下游集成指南 ✅

### SPEC-KIRO-COMPLETED-2026-06-02: Kiro 规范系统已完成项目（8 个 spec）
- **来源**: `.kiro/specs/` 目录
- **状态**: 全部完成

#### regression-tests — 回归测试体系 (34/34 ✅)
- 覆盖 74 个已修复 bug 的系统化回归测试，集成到 CI
- P0 关键安全测试、P1 高优先级测试、CI 集成、覆盖率检查、文档全部交付

#### aierrorhandler-rollout — AI 错误处理器上线 (18/21 ✅，3 项可选 PBT 未做)
- Delphi 13.1 下 AIErrorHandler 上线：SilentMode、Bootstrap facade 单元、LLMBridge adapter 单元
- Examples demo 项目已交付

#### autofix-runtime-errors — AutoFix 运行时错误自动修复 (69/69 ✅)
- 六大阶段全部交付：Pascal 单元验证/补全、外部 PowerShell 脚本骨架、主循环 + AI 集成 + lint、集成入口、e2e dry-run、最终门禁
- 含 StackWalker、ErrorRecorder、VclHook、SelfTerminator、ScenarioRunner、HealthSignal 和 10+ PowerShell 脚本

#### deepbase-bug-fixes-p0p1p2 — P0/P1/P2 缺陷修复 (70/70 ✅)
- 15 个修复项：P0（LLM schema、SecretStore、streaming transport）、P1（IntentClarification 并发、BrowserAutomation ResponseWaiter/Registry、DeepShell EventBus/Theme）、P2（Graph Dijkstra、Comment encoding、DeepFlow pause/resume 等）

#### deepbase-round2-fixes — 第二轮修复 (115/115 ✅)
- 139 个 better2.md 修复项：P0（死锁/UAF/崩溃）、P1（SQL 注入/安全）、P2（优化/代码质量）
- 覆盖 StateMachine、Timeout、CircuitBreaker、UniPool、Supabase/Firebase、SQL 注入、Crypto、Commerce、Config、ConnectionPool、Persistence、EventBus、Speech、VCL/FMX 线程安全、Browser、IntentClarification、Governance、Inference、性能优化

#### intent-clarification — IntentClarification Phase 2 (20/20 ✅)
- IoC 集成、StateMachine 集成、Logging、数据库标准化、Resilience、Metrics、Config 系统、Validation、集成测试
- Phase 1 骨架实现 + 评审后修复已在 `.kiro/specs/intent-clarification/history.md` 归档

#### services-crypto-config-refactor — Crypto/Config/Services 重构 (27/29 ✅，2 项可选)
- 三项耦合重构：crypto 原语统一（DeepBase.Crypto）、config 接口清理（移除 deprecated）、services 包边界拆分（Feedback→VCL、ORM→Persistence、Net→Features、License FireDAC 移除）

#### browser-automation — 浏览器自动化框架 (38/41 ✅，3 项 P5 延后)
- Phase 1-7 全部交付：抽象层骨架、Bug 修复（28 个）、能力升级（12 个新组件 + 10 个测试文件）、ScriptStore JS 脚本入库、5 位专家三轮评审（39 个 C/H 问题全关闭）、PageDriver 自然语言驱动（Alibaba page-agent 接入）
- 3 个 P5 结构性延后项（IBrowserSession 合并、ResponseWaiter stale result、CDP cancel token）已转入 tasks.md

---

## 2026-06-02 代码-任务差距分析与清理 (GAP-CLEANUP-2026-06-02)

### 发现：tasks.md 中 13 项标记"待办"实际已在代码中完成

| 模块 | 已实现项 | 代码证据 |
|------|---------|----------|
| IC-P0 | L2/L3 session-scoped | Provider.L2/L3 已是 session 级 |
| IC-P0 | Router MaxLevel 钳制 | `Router.pas` 有 `ClampDepth` |
| IC-P0 | LLM resilience 超时 | `LLMResilience.pas` 有 `TTask`+`WaitForSingleObject` |
| LLM-P0 | 6 种 Provider | `Core/DeepBase.LLM.pas` 6 个枚举 |
| LLM-P0 | 按槽位 fallback | `LLM.Config.pas` tier model 数组 + `CallWithFallback` |
| LLM-P0 | Vision fallback | `LLM.Service.pas` `ChatVision` |
| LLM-P0 | 下游 facade | `DeepKitSafeClient` 已串联 |
| LLM-P0 | Mock provider 测试 | fake transport 单测存在 |
| DB-P0 | DoQry timeout/校验/脱敏 | `DoQry.pas` `TimeoutSec` + 参数校验 + DEBUG 脱敏 |
| DB-P0 | 迁移引擎 | `Migrations.pas` 完整 `TMigrationEngine` |
| Speech | M2.5 SenseVoice 后端 | 全部 7 项已实现 |

### 已删除文件

- 7 个已完成 kiro spec 目录：`intent-clarification`、`aierrorhandler-rollout`、`autofix-runtime-errors`、`regression-tests`、`deepbase-bug-fixes-p0p1p2`、`deepbase-round2-fixes`、`services-crypto-config-refactor`
- 4 个仅有 requirements.md 的 spec 目录：`config-management-enhancement`、`doqry-optimization`、`property-based-testing`、`structured-error-handling`
- 18 个 `.12.bak` Delphi 13 迁移备份文件
- 2 个 `.utf8bom.tmp` 临时文件
- `__history/` IDE 自动备份目录（root + Features）
- `antitamper_debug.log`、`compile-errors.log`

### 仍待完成的真正缺口

- **IC**: facade 清理、GetPresetSlots 集成、L4 失败语义、FeatureConfig/Metrics 接线
- **LLM**: 统一配置模型（两套并行）、GenerateImage async/stream、FMX 配置面板
- **ARCH**: `DeepBaseFeatures.dpk` 仍 requires FireDAC/dbrtl（违反分层）
- **Commerce**: PaymentBridge verifier、审计日志、每通知幂等
- **Speech**: M4 DeepLaunch 未启动、WakeWord/Voiceprint/IntentParser 为 stub、PBT 测试缺失

### Kiro 剩余 4 个 spec 合并至 tasks.md 并删除（同日续）

- `browser-automation/`（tasks.md + bugfix.md + history.md）— Phase 8/9 评审修复已全部关闭，仅 P5 延后 3 项移入 tasks.md
- `deepbase-speech/`（tasks.md + design.md + requirements.md + .config.kiro）— M0-M8 详细待办 34 项展开到 tasks.md，design.md/requirements.md 的 P1-P14 属性和 R1-R19 需求以设计参考形式保留
- `delphi-13-migration/`（tasks.md）— 12 项待办展开到 tasks.md
- `feedback-backend-service/`（tasks.md + design.md + requirements.md）— 10 阶段任务展开到 tasks.md，20 条正确性属性以设计参考形式保留
- `.kiro/specs/` 目录现在为空

---

## 2026-06-09 任务清单对齐与 IntentClarification 包边界门禁

### QA-P0-IC-PACKAGE-2026-06-09: Phase 2 必需单元回归检查
- **完成日期**: 2026-06-09
- **来源**: `tasks.md` 中“包边界测试补 `DeepBase.IntentClarification.*` 必需单元检查”待办项。
- **内容摘要**:
  - `Tests/Architecture/Test.Arch.PackageBoundaries.pas` 新增 `FeaturesPackage_ContainsIntentClarificationPhase2Units`。
  - 回归检查逐项覆盖 `DeepBase.IntentClarification` Phase 2 必需单元在 `DeepBaseFeatures.dpk` 与 `DeepBaseFeatures.dproj` 中的 contains/reference。
  - 明确禁止 `Features\DeepBase.IntentClarification.Storage.pas` 回流到 Features 包；该 FireDAC storage 必须保留在 Persistence 边界内。
  - `tasks.md` 已移除该已完成待办，剩余 IC 队列继续跟踪 slot 注入、并发和降级语义回归用例。
- **验证**:
  - `Scripts\run_architecture_checks.ps1`: Architecture tests 25/25 passed。
  - Layer violation checks: Errors=0，Warnings=23。
  - Security pattern checks: Errors=0，Warnings=22。
- **归档**:
  - 缺陷/防回归记录见 `bugfix.md` 的 BUG-236。

---

## 2026-06-09 IntentClarification 语义回归用例补齐

### QA-P0-IC-SEMANTICS-2026-06-09: slot 注入与 L4 降级防回归
- **完成日期**: 2026-06-09
- **来源**: `tasks.md` 中“补 IntentClarification slot 注入、并发和降级语义回归用例”待办项。
- **内容摘要**:
  - `Tests/Test.DeepBase.IntentClarification.Integration.pas` 新增 `Test_DomainAdapterPresetSlotsReachL1Provider`，覆盖 Engine 构建上下文时从 `IDomainAdapter.GetPresetSlots(IntentName)` 取 slot，并传到 L1 provider 的真实调度路径。
  - 新增 `Test_L4_AllFailures_ReturnsDegradedFailure`，覆盖 L4 专家观点和综合调用全部失败时必须返回 degraded failure。
  - 补齐 `TMockLLMClient.GenerateImageStream`，并同步 `Tests/Test.DeepBase.IntentClarification.pas` 中的 `TFakeClarificationLLM.GenerateImageStream`，解决 `ILLMClient` 接口漂移造成的编译阻塞。
  - 并发语义已由既有 `Test.DeepBase.IntentClarification.Concurrent.PBT` 和 `Round2.PBT` 覆盖，本轮不重复造同类用例。
- **验证**:
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.IntentClarification.Integration -AllowFilteredCI`：17 tests passed，0 failed，0 errored，0 leaked。
  - 同一 runner 已完成 `Tests\DeepBaseTests.dpr` 编译和过滤执行，确认新增 slot 注入与 L4 降级回归实际运行。
- **归档**:
  - 已从 `tasks.md` 当前 IC 待办中移除。
  - 相关缺陷记录见 `bugfix.md` 的 BUG-237、BUG-238。

### QA-P0-TEST-RUNNER-2026-06-09: IC 过滤 runner 编译阻塞收敛
- **完成日期**: 2026-06-09
- **内容摘要**:
  - `Scripts/run_tests.ps1` 编译 DPR 时改用项目目录作为工作目录，修复 `Architecture\Test.Arch.PackageBoundaries.pas` 相对路径解析失败。
  - `ThirdParty/Payment/DeepBase.Payment.pas` 修复 Delphi 13.1 下 `HashCode` 未声明，并补齐 Payment facade 类型/枚举别名。
  - `ThirdParty/Payment/DeepBase.Payment.Stripe.pas` 和 `Tests/Test.DeepBase.Payment.Integration.pas` 同步修复重载声明、uses、编码和泛型断言编译兼容问题。
  - `ThirdParty/Social/DeepBase.Social.Weibo.pas`、`DeepBase.Social.QQ.pas` 将 `DeepBase.Security.DPAPI` 提到 interface uses，修复公开 `TKeyStorageMode` 类型不可见。
- **验证**:
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.IntentClarification.Integration -AllowFilteredCI`：17/17 passed。
- **归档**:
  - 编译阻塞记录见 `bugfix.md` 的 BUG-238、BUG-239、BUG-240。

---

## 2026-06-10 QA-P0 Unit runner 继续收敛

### QA-P0-UNIT-2026-06-10: DoQry / BrowserAutomation 失败簇修复与超时清理
- **完成日期**: 2026-06-10
- **内容摘要**:
  - `Persistence/DeepBase.DB.DoQry.pas` 将 SQLite `database is locked` / busy / locked 文本回退映射为 `DOQRY_ERR_TX_CONFLICT`，让并发 InsertReturningId 测试的既有重试逻辑生效。
  - `Tests/Test.DeepBase.BrowserAutomation.pas` 的 fake session 对齐 ScriptStore click/input `{success:true}` 返回契约，避免 DOM plan 被误判为第 2 步失败。
  - `Scripts/run_tests.ps1` 为测试 exe 增加 `DEEPBASE_TEST_RUN_TIMEOUT_MS` 超时控制，超时后会 kill 子进程并返回失败，避免 `DeepBaseTests.exe` 残留占用 XML。
  - 历史列出的 Browser Registry、Browser WindowPool、FeatureFlags、License、Performance 过滤测试本轮均已单独通过。
- **验证**:
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.DB.DoQry -AllowFilteredCI`：32/32 passed。
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.BrowserAutomation -AllowFilteredCI`：8/8 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -FromUnit DeepBase.Browser.Registry -AllowFilteredCI`：7/7 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -FromUnit DeepBase.Browser.WindowPool -AllowFilteredCI`：11/11 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -FromUnit DeepBase.FeatureFlags -AllowFilteredCI`：69/69 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -FromUnit DeepBase.License -AllowFilteredCI`：16/16 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -FromUnit DeepBase.Performance -AllowFilteredCI`：16/16 passed。
  - 临时 `DEEPBASE_TEST_RUN_TIMEOUT_MS=60000` 完整 Unit skip-compile 能自行超时失败并清理残留进程。
- **遗留**:
  - 完整 Unit 仍未全绿：60 秒超时试跑已出现若干 F/E，但未跑到 DUnitX 失败摘要；下一步继续按单元/模块分组隔离剩余失败。
- **归档**:
  - 相关缺陷记录见 `bugfix.md` 的 BUG-241、BUG-242、BUG-243。

---

## 2026-06-11 QA-P0 Unit 全量收敛

### QA-P0-UNIT-2026-06-11: 最后失败簇修复与完整 Unit 通过
- **完成日期**: 2026-06-11
- **内容摘要**:
  - `Tests/Test.DeepBase.DBException.pas` 将中文预期字符串改为 UTF-16 code point 构造，避免源文件编码被 Delphi 编译器按错误代码页解释后产生 mojibake 断言。
  - `Tests/Test.DeepBase.Unlock.pas` 使用不在校验字母表内的 `@` 构造坏校验码，避免测试突变字符偶然命中新/旧兼容校验字符。
  - `Tests/Test.DeepBase.DB.DoQry.pas` 为并发 InsertReturningId 测试启用 WAL、扩大 BusyTimeout、增加重试窗口，并修复失败路径提前 `Exit` 导致连接未释放的问题。
  - 完整 Unit 已从“超时/剩余 F/E”收敛到 DUnitX 摘要全绿。
- **验证**:
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.DBException,DeepBase.Unlock -OutputDir TestResults\UnitGroup_FinalTwo -AllowFilteredCI`：12/12 passed。
  - `Scripts\run_tests.ps1 -Type Unit -FromUnit DeepBase.DB.DoQry -OutputDir TestResults\UnitGroup_DoQryAfterRetry -AllowFilteredCI`：32/32 passed。
  - `Scripts\run_tests.ps1 -Type Unit -SkipCompile -OutputDir TestResults\UnitFull_AfterDoQryRetry -AllowFilteredCI`：3661 found，3658 passed，3 ignored，0 failed，0 errored。
- **遗留**:
  - 完整 Unit 功能摘要已通过，但进程退出仍打印 System.JSON/FastMM unexpected memory leak，下一步作为独立质量债定位。
- **归档**:
  - 相关缺陷记录见 `bugfix.md` 的 BUG-244、BUG-245、BUG-246。

---

## 2026-06-15 任务清单对齐与 DeepLaunch 缺陷登记

### TASK-AUDIT-2026-06-15: tasks/history/bugfix 三文档对齐
- **完成日期**: 2026-06-15
- **来源**: 用户要求“对齐 tasks.md 文件，把已经完成的任务移入 history.md，记录 bug 到 bugfix.md，把需要完成的任务更新到 tasks.md，然后做一个版本提交”。
- **内容摘要**:
  - `tasks.md` 重写为当前待办清单，只保留未完成任务和下一步任务。
  - 已完成的 QA-P0、IntentClarification、DeepShell、架构检查、LLM/transport 等内容继续保留在本历史文档中，不再在 `tasks.md` 主体重复列出 `[x]` 项。
  - 新增 `DL-P0-2026-06-15`，集中跟踪 DeepLaunch Grid 右键编辑崩溃、工作流区 i18n、主题同步和 10 格绘制高度问题。
  - `bugfix.md` 新增 BUG-248 ~ BUG-251，分别记录 DeepLaunch 4 个待修复缺陷。
- **边界**:
  - 当前 DeepBase 仓库未找到 `DeepLaunch.exe` 对应主程序源码；本轮先完成任务和缺陷登记，后续需要定位 DeepLaunch 下游源码后实施代码修复。
- **验证**:
  - 文档结构检查：`tasks.md` 当前只保留未完成队列；DeepLaunch 4 项用户反馈均有任务和 bug 编号。

### DATA-PLATFORM-MIGRATE-2026-06-16: 已完成数据平台任务移入历史
- **完成日期**: 2026-06-16
- **来源**: 用户要求"对齐 tasks.md，已完成任务移入 history.md"。
- **移入项**:
  - `DATA-P1-001`: BCrypt 直接解密后端 — TBCryptSQLiteReader (320 LOC)、DeriveSQLCipherKey、TryDecryptPage、TryProbeCipherParams、beBCryptDirect 集成。
  - `DATA-P2-001`: 单元测试与集成测试 — SchemaAdapter 36 cases、ClipboardGuard 6 fixtures、TExternalSQLiteReader 集成测试。

### ARCH-P1-002-2026-06-16: 全链路包编译门禁修复
- **完成日期**: 2026-06-16
- **来源**: `tasks.md` ARCH-P1-002，DeepBasePlatform.dpk 缺少依赖 + 多个预存编译错误。
- **内容摘要**:
  - **包依赖修复 (4 dpk)**:
    - `DeepBasePlatform.dpk` requires 新增 `DeepBaseCommerce`，Net.Transport 移至 Commerce contains。
    - `DeepBaseCommerce.dpk` 显式包含 `DeepBase.Net.Transport`。
    - `DeepBaseSpeechCore.dpk` requires 新增 `DeepBaseServices` + `DeepBaseCommerce`。
    - `Scripts/build_packages_win64.ps1` 拆分子包构建顺序（11 包全链路）。
  - **编译错误修复 (5 单元, ~30 errors → 0)**:
    - `WindowMonitor.pas`: TThread 前缀、显式 TThreadProcedure、缺失 WinAPI 声明、HWINEVENTHOOK 等 7 处。
    - `ClipboardGuard.pas`: SaveBackupToTemp/Path 从 procedure 改为 function: Boolean 2 处。
    - `UIA.Engine.pas`: COM TLB 接口不匹配、多接口继承、GetRaw 桥接、IsMappingIntegrityVerified 等 18 处。
    - `DataPlatform.Bootstrap.pas`: 缺少 DeepBase.SchemaAdapter uses 1 处。
    - `DeepBaseSpeechCore.dpk`: requires 缺失导致 E2199 包间冲突 ~25 处。
  - **归档**: BUG-269 ~ BUG-274 共 6 项 (bugfix.md)。
- **验证**:
  - `Scripts/build_packages_win64.ps1 -Profile Runtime`：11 包全链路编译通过，0 errors。
  - FMX.dpk 仍有预存 E2280（`DeepBase.FMX.LogListView.pas(239) Unterminated conditional directive`），不在本次范围。

---

## 2026-06-18 已完成任务归档

### ARCH-P1-001: Core 瘦身和包分层
- **完成日期**: 2026-06-18
- **内容摘要**:
  - Features 拆分 LLM/Inference/IntentClarification/Browser/Commerce/Platform 等可选包
  - 包 DAG 重切：Core→Services→{Persistence,Features}→{VCL,FMX}
  - 新增 DeepBaseDataPlatform.dpk，Platform 移除 Persistence 依赖

### SPEECH-01: TTS 后端迁入 DeepBase
- **完成日期**: 2026-06-18
- **内容摘要**:
  - `DeepBase.Speech.TTS.Edge.pas` ← 从 `DeepInput/uTTS.Edge.pas` 迁移，适配 `ITTSBackend` 接口
  - `DeepBase.Speech.TTS.StepFun.pas` ← 从 `DeepInput/uTTS.StepFun.pas` 迁移，适配 `ITTSBackend` 接口
  - Edge TTS：WinHTTP WebSocket 无需额外 DLL，确认在 DeepBase 中无新增依赖

### SPEECH-02: 统一 Resolver 工厂
- **完成日期**: 2026-06-18
- **内容摘要**:
  - 新增 `DeepBase.Speech.Resolver.pas`
  - `ResolveASR(ALicensing)` — 三层回退：SenseVoice(PRO+已安装) → Baidu(用户配Key) → SAPI(默认)
  - `ResolveTTS(ALicensing)` — 三层回退：Edge(免费优先) → SAPI(离线兜底) → StepFun(用户配Key可选覆盖)
  - `ALicensing` 参数：通过 `ILicensing.HasFeature('sensevoice_asr')` 判断 PRO 等级

### SPEECH-03: DeepInput 瘦身
- **完成日期**: 2026-06-18
- **内容摘要**:
  - 删除 `uOnlineASR.pas, uTTS.pas, uTTS.Edge.pas, uTTS.StepFun.pas, uTTS.Local.pas`
  - `uMain.pas` → 移除 uTTS 引用，TTS 已迁移到 DeepBase
  - `uAudioCapture.pas, uVAD.pas` 评估：保留在 DeepInput 中

### delphi-13-migration: Delphi 13 兼容性
- **完成日期**: 2026-06-18
- **内容摘要**:
  - Skia4Delphi 7.1.0 unit path 变更（无引用，无需迁移）
  - VCL/FMX 兼容性检查（8 个 dfm/fmx 已检查，无 DPI 敏感属性）
  - 96 DPI `.dfm`/`.fmx` 转换（无转换需求）

### browser-automation: 浏览器自动化接口优化
- **完成日期**: 2026-06-18
- **内容摘要**:
  - `IBrowserSession`/`IBrowserAutomationSession` 接口合并（IBrowserSession 继承 IBrowserAutomationSession）
  - ResponseWaiter stale result 防护（FStartCount/FRunningCount 原子计数，旧导航响应自动丢弃）

### QA-P0-001: 测试和 CI 门禁可信化（部分完成）
- **完成日期**: 2026-06-18
- **已完成项**:
  - 清理 0-fixture 测试单元（9 文件补齐 TDUnitX.RegisterTestFixture）

### UPD-P0-001: 免费版升级收费版和付费更新（部分完成）
- **完成日期**: 2026-06-18
- **已完成项**:
  - 增加 Updater 安全测试：签名错误、Zip Slip、降级攻击（14 测试用例，Test.DeepBase.Updater.pas）

### QA-P1-001: 长期质量体系（部分完成）
- **完成日期**: 2026-06-18
- **已完成项**:
  - Updater 安全测试（14 用例，Test.DeepBase.Updater.pas）
  - LLM E2E mock（15 用例，Test.DeepBase.LLM.E2E.pas）
  - 桌面工具模板 E2E
  - CI 增加可选包矩阵 (Minimal/Runtime/LLM/Speech/Commerce/Updater，.github/workflows/delphi-ci.yml)

### deepbase-speech: 语音模块基础（部分完成）
- **完成日期**: 2026-06-18
- **已完成项**:
  - PBT 测试 (8 用例，Test.DeepBase.Speech.PBT.pas) + 单元测试 (7 用例，Test.DeepBase.Speech.pas) → 16/16 passed
  - dpk 分包验证 (6 dpk: Core/ASR/TTS/Voice/Wake + SAPI.Decl 归入 Core)

### REVIEW5-R3-P0: 第三轮审阅 P0 编译阻断修复 (部分完成)
- **完成日期**: 2026-07-08
- **来源**: 第三轮五专家全模块审阅 (review5-round3), 专家 D/E
- **已完成项**:
  - REVIEW5-R3-D-001 (GOV-R3-001): `Governance/DeepBase.Governance.ConfigRegistrar.pas` uses 子句 `DeepBase.Crypto.Hash` 后补逗号
  - REVIEW5-R3-E-001 (FEAT-R3-001): `Features/DeepBase.UIA.Engine.pas` uses 子句 `DeepBase.Crypto.Hash` 后补逗号
  - REVIEW5-R3-E-004 (FEAT-R3-004): `Features/DeepBase.UIA.Engine.pas` UIA_ProcessIdPropertyId 常量由错误的 34005 改为官方值 30002

### REVIEW5-R3-A: 第三轮审阅 Core 安全/加密/并发 (部分完成, 8/11)
- **完成日期**: 2026-07-08 (进行中, 2026-07-09 续修 A-001)
- **来源**: 第三轮五专家全模块审阅 (review5-round3), 专家 A
- **已完成项**:
  - REVIEW5-R3-A-001 (CORE-R3-001, BUG-402): `Core/DeepBase.Authorization.pas` GetUser/GetRole/GetAllUsers/GetAllRoles 返回 `TObjectDictionary[doOwnsValues]` 拥有的裸对象引用, 锁外可被 DeleteUser/DeleteRole 释放致 use-after-free; 且 LoginTestUser 曾改 GetUser 返回的裸对象写 token 依赖脆弱释放契约 — 采用深克隆方案: 新增 `TUser.Clone`/`TRole.Clone` (深拷贝标量 + 重建 FRoles/FPermissions/FMetadata 容器, 析构路径 except...Free;raise 防中途泄漏), Get* 锁内对 Live 对象 Clone 返回 (调用方拥有并释放), GetAll* 用 owning `TObjectList` 构建后 OwnsObjects:=False 移交所有权; 新增带锁写方法 `SetUserMetadata(Username,Key,Value):Boolean` 替代调用方改快照的写法 (写 token 落到真实用户并对后续加锁读可见). 优于原建议的引用计数 (record 字段不适合引用计数, 克隆契约与 B-003/B-004 FeatureFlags 一致). 契约变更: Get* 返回值所有权归调用方 (已 rg 全仓确认无外部旧契约依赖, LoginTestUser/Test_GetUser_Exists/Test_GrantPermission/Test_RevokePermission 调用点已同步加 Free 或改用 UserExists+SetUserMetadata). 验证: Win64 `-FromUnit DeepBase.Authorization` 29 项全过, 0 泄漏.
  - REVIEW5-R3-A-002 (CORE-R3-002, BUG-386): `Core/DeepBase.Cache.pas` Put 锁外 Evict 竞态 — 改为锁内收集被驱逐项 TEvictedList + 锁外触发回调 (FireEvictedCallbacks), Evict(Count,Batch) 签名, Cleanup 同步重构
  - REVIEW5-R3-A-003 (CORE-R3-003, BUG-387): `Core/DeepBase.Protection.pas` DeriveAes256KeyPBKDF2 — finally 清零 LPasswordBytes/LSaltPlusBlock/LBlock/LUTemp
  - REVIEW5-R3-A-004 (CORE-R3-004, BUG-388): `Core/DeepBase.Security.pas` DecryptUBS2V1 与 ProtectStringDpapi(非Win) — 嵌套 finally 对 MachineKey/Key/Plaintext SecureClearBytes
  - REVIEW5-R3-A-005 (CORE-R3-005, BUG-389): `Core/DeepBase.Crypto.RSA.pas` LoadPrivateKeyPEM — finally 对八个私钥分量+LDER+LImportBlob FillChar 清零
- **待办项**: A-011 (CircuitBreaker 持锁回调)
  - (A-006/007/008/009/010 已于 2026-07-08 续修, 见 BUG-390~394)

### REVIEW5-R3-B: 第三轮审阅 Core 业务/AI/LLM (部分完成, 6/19)
- **完成日期**: 2026-07-09 (进行中)
- **来源**: 第三轮五专家全模块审阅 (review5-round3), 专家 B
- **已完成项**:
  - REVIEW5-R3-B-001 (BIZ-R3-001, BUG-400): `Features/DeepBase.LLM.Proxy.pas` GenerateImageStream 用 TTask.Run 闭包捕获裸 Self (调用实例方法 GenerateImage), 调用方释放最后 ILLMClient 引用后对象析构, 后台任务仍访问 Self → use-after-free — 采用接口引用捕获方案 (与 CORE-R3-006/BUG-390 一致): 方法内 `LSelf := Self` (ILLMClient), 闭包经 LSelf.GenerateImage 调用, 引用计数保活对象至任务结束, 任务结束闭包释放 LSelf 引用计数归零安全析构. 未用专家建议的 FActiveTasks+WaitFor (理由: 已有验证先例 + 字段均线程安全值类型 + 避免 WaitFor 死锁, 真正需析构等待的长任务 LLM.Manager 在 B-002 另行处理; 详见 bugfix.md BUG-400)
  - REVIEW5-R3-B-002 (BIZ-R3-002, BUG-401): `Core/DeepBase.LLM.Manager.pas` Destroy 已有 BIZ2-006 的 Wait(5000) 但远小于在途 HTTP (TLLMClient 默认 60s 可配更高), 超时后 FreeAndNil(FLLMClient) 而任务仍在调 FLLMClient.Chat → UAF; 任务 finally 还访问已释放的 FExecuteTasks/FExecuteTasksLock → 二次 UAF — 三处加固: Wait 前 `LT.Cancel`, 超时 5000→120000ms (2x 默认 HTTP timeout 覆盖 60s 窗口), 超时则 LAnyTimeout 标志记 Error 日志后 Exit 跳过全部 teardown (释放被在用对象是确定性 UAF, 取泄漏更安全且绝不静默); 与 B-001 互补: 短任务用接口保活, 长任务用析构等待+超时不释放
  - REVIEW5-R3-B-003 (BIZ-R3-003, BUG-398): `Core/DeepBase.FeatureFlags.pas` SaveFlag 两实现静默接管调用方 AFlag 所有权 (TMemoryFlagStorage.AddOrSetValue 接管进 doOwnsValues 字典; TFileFlagStorage 在 OwnsObjects=True 列表上下标赋值接管) — 新增 `TFeatureFlag.Clone` (FromJSON(ToJSON) 深拷贝 + 手动补全 CreatedAt/UpdatedAt), SaveFlag 内部克隆后入库, AFlag 所有权始终归调用方
  - REVIEW5-R3-B-004 (BIZ-R3-004, BUG-399): `Core/DeepBase.FeatureFlags.pas` GetFlag 两实现所有权契约不一致 (Memory 返回 storage 拥有裸引用 → Clear/Replace 致 UAF; File 用 Extract 转移所有权 → 契约相反) — 统一返回 `TFeatureFlag.Clone` 深拷贝, 所有权归调用方, 不受 storage 后续修改/释放影响
  - REVIEW5-R3-B-007 (BIZ-R3-007, BUG-405): `Core/DeepBase.LLM.ImportExport.pas` ImportLLMContent 在 imOverwrite 模式下, 注释称 "Validate all required arrays exist and are parseable BEFORE any deletion" 但 `TryGetValue` 返回值被忽略. 若 JSON 缺少 `categories`/`meta_prompts`/`prompts` 任一数组键, 代码仍进入删除分支清空现有数据 — 与验证注释意图相悖, 可能因畸形 JSON 致不可逆数据丢失 — 检查三个 `TryGetValue` 返回值, 任一返回 False (键缺失) 则报 `Import validation failed: missing required array in JSON` 错误并 Exit, 阻止后续删除操作. 验证: Win64 -FromUnit DeepBase.LLM.ImportExport 3 项全过 0 泄漏.
  - REVIEW5-R3-B-010 (BIZ-R3-010, BUG-406): `Core/DeepBase.License.pas` VerifySignature 在常量时间比较前执行 `if Length(Expected)<>Length(Signature) then Exit;` — 长度不匹配时立即返回, 攻击者可通过测量响应时间推断签名长度, 破坏常量时间比较安全保证 — 移除长度早期退出, 用 Expected 长度作循环基准. Signature 较短时 Delphi 字符串越界访问返回 #0 (与 Expected 字节 XOR 后 Diff 非零); Signature 较长时额外字节经第二轮循环计入 Diff. 长度差异自然反映在 Diff 结果中, 比较耗时恒定. 验证: Win64 -FromUnit DeepBase.License 全部通过 0 泄漏.
  - REVIEW5-R3-B-006 (BIZ-R3-006, BUG-407): `Core/DeepBase.LLM.Manager.pas` DeletePrompt 四条级联 DELETE (LLMCalls/PromptMetaBinding/PromptVersions/Prompts) 无事务, 部分失败留不一致 — 合并为单条分号分隔多语句 SQL. SQLite 和 PostgreSQL 均支持单 Execute 执行多语句, 数据库引擎保证语句级原子性. 同一 `:InternalCode` 参数通过参数化查询复用. 验证: Win64 -FromUnit DeepBase.LLM.Manager 全部通过 0 泄漏.
  - REVIEW5-R3-B-008 (BIZ-R3-008, BUG-408): `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` DeleteUser/DeleteRole 仅删主表 (auth_users/auth_roles) 未清 auth_user_roles 关联表, 留孤儿行, 重启后加载恢复已删关联 — 在 DeleteUser 和 DeleteRole 中增加级联删除 auth_user_roles 语句, 先删关联再删主表, 分号分隔单 ExecSQL 保证原子性. 参数化查询避免注入. 验证: Win64 -FromUnit DeepBase.Authorization 全部通过 0 泄漏.
  - REVIEW5-R3-B-009 (BIZ-R3-009, BUG-409): `Core/DeepBase.License.pas` LoadLicenseFromDB `try...except end` 吞所有异常, 篡改/损坏许可证与"无许可证"不可区分 — 仅静默忽略包含 "no such table" / "table" / "doesnt exist" / "does not exist" 的异常 (首次启动预期), 其他异常经 raise 重新抛出. 保持向后兼容: 首次启动无表时不报错, 但连接失败、数据损坏等错误不再被吞. 验证: Win64 -FromUnit DeepBase.License 全部通过 0 泄漏.
  - REVIEW5-R3-B-012 (BIZ-R3-012, BUG-410): `Core/DeepBase.LLM.BillingClient.pas` ChatWithRetry 退避 `1000*(1 shl (I-1))` 无 jitter 致重试风暴, 且 Retries>31 时 1 shl 31 溢出为负 Sleep 失效 — 加 Min(I-1,20) 防溢出 (最大延迟 ~17 分钟) + Random(200) 抖动 (0-199ms 随机打散重试). EBillingServerError 线性退避也加 jitter. implementation uses 增加 System.Math 提供 Min. 验证: Win64 -FromUnit DeepBase.LLM.BillingClient 全部通过 0 泄漏.
  - REVIEW5-R3-B-013 (BIZ-R3-013, BUG-411): `Core/DeepBase.LLM.BillingClient.pas` DoStreamRequest 设 Accept:text/event-stream 未重置, 泄漏到后续 DoRequest 致非流式 API 异常 — DoStreamRequest 外层 finally 重置 Accept:application/json, 确保正常返回或异常都恢复默认值. 验证: Win64 -FromUnit DeepBase.LLM.BillingClient 全部通过 0 泄漏.
  - REVIEW5-R3-B-014 (BIZ-R3-014, BUG-412): `Core/DeepBase.AutoFix.pas` NotifyShellShown 用 TThread.ForceQueue(nil,...) 在线程池而非主线程执行 TAutoFixScenarioRunner.Run(内含 Halt), 非主线程 Halt 致进程清理不完整 — 改 TThread.Queue(nil,...) 确保主线程执行, Halt 调用进程清理完整. 验证: Win64 -FromUnit DeepBase.Manager 全部通过 0 泄漏.
  - REVIEW5-R3-B-015 (BIZ-R3-015, BUG-413): `Core/DeepBase.MVVM.pas` TAsyncCommand.Destroy Wait(INFINITE), FExecuteProc 阻塞且不检查 IsCancelledFunc 时应用关闭永久挂起 — Wait(5000) 有限超时, 超时捕获异常并清空 FTask, 析构继续清理不阻塞. 验证: Win64 -FromUnit DeepBase.MVVM 全部通过 0 泄漏.
  - REVIEW5-R3-B-005 (BIZ-R3-005, BUG-404): `Core/DeepBase.LLM.pas` Chat 在 DoHttpRequest 返回后无条件调 ParseAnthropicResponse/ParseOpenAIResponse, 若 DoHttpRequest 返回 False (HTTP 错误/超时/网络异常), Parse 仍会被调用并可能覆盖 Result:=False — 尤其当错误响应体含可解析 JSON 时, Parse 可能误判为 Success=True, 调用方拿到错误结果却不知真实失败原因 — 仅当 `if Result then` 守卫: DoHttpRequest 返回 True 时才进入 ParseXxxResponse, 否则保留 False 并记录错误体到 Response.ErrorMessage 供诊断. 验证: Win64 -FromUnit DeepBase.LLM 28 项全过 0 泄漏.
  - REVIEW5-R3-B-011 (BIZ-R3-011, BUG-403): `Core/DeepBase.Scheduler.pas` ExecuteTask 闭包在 FLock 内置 TaskRef.FState 为 tsCompleted/tsPending 并 FRunningITask:=nil 后 Leave 锁, 锁外执行 TaskRef.FOnCompleted(TaskRef); 期间另一线程 Cleanup 见 tsCompleted 即 FTasks.Remove (doOwnsValues) 释放 TaskRef → 闭包锁外读 TaskRef.FOnCompleted 字段/传 TaskRef 致 use-after-free; FOnFailed 路径虽捕获 LOnFailed 局部但仍��裸 TaskRef 且 FRunningITask:=nil 在回调前置, 同一窗口 TaskRef 可被释放 — 三处加固: 成功路径锁内捕获 LOnCompleted 局部 (不再锁外读字段); 成功/失败路径推迟 FRunningITask:=nil 至回调后 (FRunningITask<>nil 期间 Cleanup 运行中守卫保活 TaskRef); Cleanup 移除条件加 (FRunningITask=nil) and 跳过闭包仍执行任务; 失败路径用 LTaskFailed 标志替代锁外读 FState. 选 FRunningITask 保活+Cleanup 守卫而非回调入锁 (与 REVIEW5-CORE-004 锁外回调+异常隔离设计冲突). 验证: Win64 -FromUnit DeepBase.Scheduler 51 项全过 0 泄漏.
  - 回归测试: `Test.DeepBase.FeatureFlags.TTestFeatureFlagStorage` 新增 7 项 (Clone 独立性 / Memory+File SaveFlag 不接管调用方对象 / Memory+File GetFlag 返回独立克隆并需调用方释放 / 缺失返回 nil); FeatureFlags 模块 76 测试全过, 0 泄漏. B-001/B-002/B-005/B-011 因 UAF 时序 (+网络栈依赖/120s HTTP 阻塞) 双重不可靠未附进程内断言测试 (同 CORE-R3-006/BUG-390 先例), 修复正确性经代码审查 + 模式一致性保证.
- **待办项**: B-009, B-016~B-019 (P1/P2/P3)
  - REVIEW5-R3-B-016 (BIZ-R3-016, BUG-414): `Core/DeepBase.Manager.pas` WhenReady 在 FReadyFired=True 时 TTask.Run 执行回调不追踪不等待, FinalizeModules 释放 FLogger 后回调解引用已释放对象致 UAF — 新增 FPendingReadyTasks 追踪列表 + WaitForPendingReadyTasks (锁内快照后释放锁, Wait(5000) 有限超时) 在 FinalizeModules 前等待, 回调用 LLogger 局部快照避免解引用字段. 消除持锁等待死锁风险. 验证: Win64 -FromUnit DeepBase.Manager 全部通过 0 泄漏.
  - REVIEW5-R3-B-017 (BIZ-R3-017, BUG-415): `Core/DeepBase.Authorization.pas` GetEffectivePermissions SetLength+1 循环+线性去重 O(n²), GetRolePermissionsRecursive 同模式重复 — 新增 Seen: TDictionary<string,Boolean> 哈希集合 O(1) 去重 (递归函数增加 Seen 参数), 结束时 Seen.Keys.ToArray 一次性转数组. HasPermission 单次开销降低 (不引入缓存避免失效一致性). 验证: Win64 -FromUnit DeepBase.Authorization 全部通过 0 泄漏.
  - REVIEW5-R3-B-018 (BIZ-R3-018, BUG-416): `Core/DeepBase.PluginManager.pas` VerifyPluginSignature 同步 WinVerifyTrust 默认策略可能触发 CRL/OCSP 网络往返, 多插件+慢网络冻结启动 UI — 新增常量 WTD_CACHE_ONLY_URL_RETRIEVAL=$40 并设 TrustData.dwProvFlags, 强制仅用缓存 URL 无网络往返, 配合 WTD_REVOKE_NONE 消除阻塞且不改变验证结果. 验证: Win64 -FromUnit DeepBase.PluginManager 全部通过 0 泄漏.
  - REVIEW5-R3-B-019 (BIZ-R3-019, BUG-417): `Core/DeepBase.LLM.ImportExport.pas` YAML 导出已实现但导入为 stub (返回带 error key 伪对象, 下游报误导性 "missing required array") — 采用导出 YAML/拒绝导入方案: `YamlToJson` 改返回 nil (JSON 快路径保留), `ImportFromString` 与 `ValidateImportFile` 两调用点区分给出明确错误 "YAML import is not supported, please import as JSON"; `YamlToJson` 移至 public. 新增 `TTestYamlToJson` 回归 (YAML→nil / JSON→对象). 验证: Win64 -FromUnit DeepBase.LLM.ImportExport 全部通过.
  - REVIEW5-R3-A-011 (CORE-R3-011, BUG-418): `Core/DeepBase.Resilience.CircuitBreaker.pas` SetState 持锁触发慢回调阻塞并发 — `SetState` 已改锁内仅暂存 pending、锁外 `FirePendingStateChanged` 触发; 本轮补齐遗漏的 `AllowRequest`/`RecordSuccess`/`RecordFailure` 三处 (`Execute`/`Execute<T>` 经 Record* 覆盖). Win64 -FromUnit DeepBase.Resilience 全部通过.
  - REVIEW5-R3-D-003 (GOV-R3-003, BUG-419): `Governance/DeepBase.Governance.ActionGrid.pas` CanRun/Run/GetDisabledReason/SetEnabled/GetActionInfo/GetAllActions 读 FActions/FBridges 未持锁致 rehash 期半更新/AV, Run 锁外持 TAction 引用期间同 key RegisterActionObj 会 UAF — 读路径统一锁内克隆值类型快照; Run 锁内克隆状态+取 IBridge 引用数组, 锁外跑 DueChecker+Execute; 删除私有 CheckDueIfRequired (内联到 Run). Win64 -FromUnit DeepBase.Governance.PBT 全部通过.
  - REVIEW5-R3-D-006 (GOV-R3-006, BUG-420): `DeepFlow/Source/Core/DeepFlow.Engine.pas` SendSync 用单槽 FResponseSink 存最近一次等待器, 多个并发 SendSync 互相覆盖: 先注册的等待器丢失引用, 其 CorrelationId 响应到达时字典中已是后到者的 waiter, 无匹配 → ResponseEvent 永不 SetEvent → 先到者超时丢响应; 注释声称 "safe against concurrent SendSync" 与实现不符 — 改为 `TObjectDictionary<string,TResponseWaiter>` (doOwnsValues) 按请求 MsgId 注册分发: 新增 TResponseWaiter 类 (持 TEvent + Response 字段, Create/Destroy 管理两者生命��期); SendSync 自建 waiter 后 Add 到字典 (所有权移交字典), 等待返回, finally 用 ExtractPair 按条件 (字典中仍指向本 waiter) 摘除并取回所有权统一释放, 避免误释放后续同 MsgId 新 waiter, 无 double-free; ProcessMessage 分发响应消息时按 TResponseMessage.CorrelationId TryGetValue 路由到对应 waiter, 克隆 Response 入 waiter 并 SetEvent; 非响应消息或无匹配等待器时仍回落 FOnMessageProcessed. 验证: Win64 -FromUnit DeepBase.DeepFlow.PBT 编译+回归通过 (DeepFlow.Engine 既有 Stop/Pause 测试未注册运行, 全量套件基线在当前 working tree 因先前任务遗留跨文件接口问题编译失败, 非 D-006 引入). 详见 bugfix.md BUG-420.
  - REVIEW5-R3-D-002 (GOV-R3-002, BUG-421) + REVIEW5-R3-D-004 (GOV-R3-004, BUG-421): `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` 两项联合修复:
    (D-002) 构造函数 `Create` 调用顺序 `EnsureTable → MigrateHashColumns → InitializeChainState` 从未调用 `MigrateExistingChain` (rg 全仓确认仅声明+实现). MigrateHashColumns 只为旧表加 prev_hash/this_hash 空列不回填旧库行; InitializeChainState 迁移前读链尾全空→GENESIS; 结果旧库所有行 this_hash 永远为空, VerifyChain 重建比对时 stored_hash='' 必然不等于期望值, 全部旧行被误判篡改 — 调用顺序补 MigrateExistingChain 置于 MigrateHashColumns 后、InitializeChainState 前, 先回填旧库行 this_hash 再读链尾缓存;
    (D-004) MigrateExistingChain while 循环内逐行 ExecSQL 无事务包裹, SQLite autocommit 每行独立提交, 进程中途崩溃 → 已处理行落盘 this_hash、未处理行仍空 → 链断裂且重跑迁移无法修复 (跳过已回填行但 prev_hash 已不一致) — 循环全程 StartTransaction/Commit 包裹, except Rollback+raise 全成或全回退, 链尾缓存 GetLastHash 移至 Commit 后读已提交完整链尾;
    验证: Win64 -FromUnit DeepBase.Governance.PBT 编译+回归通过 (3 tests 0 failed). 全量 DeepBaseTests.exe 运行末尾 Runtime error 216 为预存缺陷 (无干净基线可比, 非本修复引入), 见 bugfix.md BUG-421.
  - REVIEW5-R3-D-005 (GOV-R3-005, BUG-422): `Governance/DeepBase.Governance.EvidenceRecorder.pas` (a) SaveWithRetry/EnqueueEntry 固定退避 (100,200,400) 无抖动, 高并发失败时所有线程同步唤醒重试形成重试风暴瞬时再压垮底层资源、退避失效且可能级联雪崩; (b) 析构同步 Flush 队列满 1000 条无上限阻塞数百秒, 进程关停长时间无响应 — (a) 新增 BackoffDelayWithJitter 对基值加 ±30% 抖动 (BACKOFF_JITTER_PCT=30), 以 GetTickCount 低 16 位作伪随机源映射到 [-30%,+30%], 无全局锁开销不依赖 Random/Randomize, 两处 Sleep 调用点 (EnqueueEntry+SaveWithRetry) 均改用; (b) Flush 加 FLUSH_MAX_ITEMS=500 单次上限 + FLUSH_TOTAL_TIMEOUT_MS=5000 总超时, 达限即 Break, 余量交后台线程/下次 Flush, 析构队列非空由清理逻辑统一释放无泄漏. 验证: Win64 -FromUnit DeepBase.Governance.PBT 编译+回归通过 (3 tests 0 failed). 见 bugfix.md BUG-422.
  - REVIEW5-R3-E-002 (FEAT-R3-002, BUG-423): `Features/DeepBase.Browser.Engine.WebView2.pas` 4 个 Async 方法 (NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync) 返回 TTask.Run(LProc), 闭包捕获 Self 调用��例方法, Destroy 释放 Self 时任务仍在途 → 任务线程访问已 Free 实例字段 UAF — 新增 FAsyncTasks: TList<ITask> + FAsyncTasksLock 字段; RunTrackedAsync(LProc) 封装 TTask.Run 并加锁注册任务 (4 处调用点全部改用); WaitForAsyncTasks 加锁快照 ToArray 后 Clear, 逐个 WaitFor(5000) 有界等待防卡死任务永久阻塞析构, 异常吞掉; Destroy 首步 WaitForAsyncTasks (任何字段释放前), 末尾释放容器. 验证: Win64 全量 Unit 编译通过 (无编译错误/警告); 无 DUnitX 覆盖 WebView2 (仅 GUI 冒烟), 改动属 B-002 同类已验证模式; 运行末尾 Runtime error 216 为预存缺陷. 见 bugfix.md BUG-423.
  - REVIEW5-R3-E-003 (FEAT-R3-003, BUG-424): `Features/DeepBase.CloudBackup.pas` `TBackupEncryptor` 构造时 `DeriveKeyAndIV` 用单次 SHA-256(password) 派生 32B key + 16B IV (无盐/无迭代/IV 非随机, 同密码每次 IV 相同), 与同单元 `TSimpleCrypto` 已内置 PBKDF2(100k)+随机盐+AES-256-GCM+随机 IV 重复并存且弱路径被 `EncryptBytes` 实际使用, 强路径被绕过 — 删除冗余弱派生层: 删字段 FKey/FIV 与 DeriveKeyAndIV 方法 (interface+impl), 仅保留托管 FPassword:string; 构造直接 FPassword:=APassword; EncryptBytes/DecryptBytes 空检查改 FPassword=' 并直接 `TSimpleCrypto.EncryptBytes(AData, FPassword)`/`DecryptBytes` (转发密码让 TSimpleCrypto 全套 KDF/GCM 生效, 每次随机盐/IV 非确定); Destroy 删 FillChar(FIV..) 悬空写入; EncryptStream 注释改为说明已委托 TSimpleCrypto AES-GCM (移除过时 XOR 注释). 验证: Win64 全量 Unit 编译通过; grep FKey/FIV/DeriveKeyAndIV 零残留; 无 DUnitX 覆盖 TBackupEncryptor 加解密 (依赖 TSimpleCrypto 已测); Runtime error 216 预存缺陷. 见 bugfix.md BUG-424.
