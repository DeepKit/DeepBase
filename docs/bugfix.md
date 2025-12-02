# UniBase Bug 修复记录

## 2025-12-01

### BUG-001: AES 加密实现不安全
- **严重程度**: 🔴 高
- **文件**: `UniBase.Crypto.pas`
- **问题**: TAESCrypto.Encrypt/Decrypt 使用简单 XOR 模拟，不是真正的 AES 加密
- **修复**: 使用 Windows BCrypt API 实现真正的 AES-256-CBC 加密
- **状态**: ✅ 已修复

### BUG-002: 随机数生成不安全
- **严重程度**: 🔴 高
- **文件**: `UniBase.Crypto.pas`
- **问题**: TRandomGenerator.RandomBytes 使用标准 Random() 函数，不适合加密用途
- **修复**: 使用 BCryptGenRandom 生成密码学安全的随机数
- **状态**: ✅ 已修复

### BUG-003: XOR 加密密钥硬编码
- **严重程度**: 🔴 高
- **文件**: `UniBase.Config.pas`
- **问题**: XOR 加密方法存在安全隐患
- **修复**: 添加 {$MESSAGE WARN} 编译器警告
- **状态**: ✅ 已修复

### BUG-004: RegisterSingleton 接口处理错误
- **严重程度**: 🟡 中
- **文件**: `UniBase.IoC.pas`
- **问题**: QueryInterface 返回的是接口引用，不能直接 as TObject
- **修复**: 重新设计接口实例存储逻辑，区分接口和类类型处理
- **状态**: ✅ 已修复

### BUG-005: TQueryBuilder 内存泄漏风险
- **严重程度**: 🟡 中
- **文件**: `UniBase.ORM.pas`
- **问题**: Query<T> 返回的对象由调用方负责释放，Fluent API 风格易忘记
- **修复**: 添加 IQueryBuilder<T> 接口，TQueryBuilder<T> 继承 TInterfacedObject 实现自动引用计数
- **状态**: ✅ 已修复

### BUG-006: RTTI 类型检查不安全
- **严重程度**: 🟡 中
- **文件**: `UniBase.Cache.pas`
- **问题**: 取地址后强制转换不安全
- **修复**: 添加 FreeValueIfOwned 方法，使用 PPointer 安全获取对象指针
- **状态**: ✅ 已修复

### BUG-007: UniDbSelect 类型不兼容
- **严重程度**: 🟡 中
- **文件**: `UniBase.DB.DoQry.pas`
- **问题**: TClientDataSet 和 TFDQuery 类型不兼容
- **修复**: 添加 CopyQueryToClientDataSet 辅助函数，正确复制数据
- **状态**: ✅ 已修复

### BUG-008: SQL 语句拼接问题
- **严重程度**: 🔴 高
- **文件**: `UniBase.Schema.pas`
- **问题**: 多条 INSERT 语句直接拼接，FireDAC TFDScript 解析失败 (`near "cn": syntax error`)
- **修复**: 在所有 SQL 语句之间添加 `#13#10` 换行符
- **状态**: ✅ 已修复

### BUG-009: datetime('now') 参数化问题
- **严重程度**: 🔴 高
- **文件**: `UniBase.i18n.pas`, `UniBase.Security.pas`, `UniBase.Manager.pas`
- **问题**: 直接在 SQL 中使用 `datetime('now')`，FireDAC 可能误解析为参数 (`Parameter [TIME] data type is unknown`)
- **修复**: 改用参数化查询，在 Delphi 代码中计算时间后传入 ISO8601 格式字符串
- **影响方法**: `RecordMissingTranslation`, `AddTranslation`, `SaveSecret`, `MigrateSchemaInternal`
- **状态**: ✅ 已修复

### BUG-010: Studio datetime('now') 问题
- **严重程度**: 🟡 中
- **文件**: `Studio.QueriesFrame.pas`
- **问题**: `SaveCurrent` 中使用 `datetime('now')`
- **修复**: 改用参数化查询 `:UpdatedAt`, `:CreatedAt`
- **状态**: ✅ 已修复

### BUG-011: Studio 资源泄漏
- **严重程度**: 🟡 中
- **文件**: `Studio.QueriesFrame.pas`
- **问题**: `SaveCurrent` 中 `Q.Free` 不在 `finally` 块中，异常时内存泄漏
- **修复**: 改为 `try-try-except-end-finally-end` 结构
- **状态**: ✅ 已修复

### BUG-012: FMX 应用崩溃
- **严重程度**: 🔴 高
- **文件**: `UniBase.Theme.pas`
- **问题**: `TStyleManager.ActiveStyle` 是 VCL 专用，FMX 应用中返回 nil 导致崩溃
- **修复**: 添加 `{$IFNDEF FMX}` 条件编译，FMX 中使用安全默认值和空操作
- **影响方法**: `Create`, `ApplyTheme`, `ApplyThemeSync`, `GetAvailableThemes`, `IsThemeAvailable`
- **状态**: ✅ 已修复

### BUG-013: Schema INSERT 中 datetime('now') 问题
- **严重程度**: 🔴 高
- **文件**: `UniBase.Schema.pas`
- **问题**: `SQL_TIER0_SCHEMA_INFO_DATA` 中的 `datetime('now')` 被 FireDAC 误解析
- **修复**: 改用 SQLite 的 `CURRENT_TIMESTAMP`
- **状态**: ✅ 已修复

### BUG-014: VCL-only 模块缺少 FMX 保护
- **严重程度**: 🟡 中
- **文件**: `UniBase.SplashScreen.pas`, `UniBase.TestHelper.pas`
- **问题**: 这些纯 VCL 模块如果被 FMX 应用引用会导致编译错误
- **修复**: 添加 `{$IFDEF FMX} {$MESSAGE FATAL ...} {$ENDIF}` 编译时错误提示
- **状态**: ✅ 已修复

### BUG-015: datetime('now') 全代码库修复
- **严重程度**: 🔴 高
- **文件**: 多个文件
- **问题**: 多个模块中的 INSERT/UPDATE SQL 使用 `datetime('now', 'localtime')`，FireDAC 误解析为参数
- **修复**: 改用参数化查询和 `FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now)`
- **影响文件**:
  - `UniBase.LLM.pas`: `SaveConfig`, `RecordCall`
  - `UniBase.LLM.Manager.pas`: `RecordLLMCall`, `UpdateVersionStats`, `SaveCategory`, `SavePrompt`, `SaveVersion`, `SaveMetaPrompt`
  - `UniBase.MRU.pas`: `AddItem`, `Touch`
  - `Tray.Database.pas`: `UpdateDevLog`, `IncrementCommandUsage`, `AddProjectHistory`, `SetSetting`
  - `Tray.NotesFrame.pas`: `SaveNote`, `MarkComplete`
  - `Tray.ProjectsFrame.pas`: `AddProject`, `OpenProject`, `OpenInIDE`
  - `Tray.SchedulerFrame.pas`: `RunTask`
- **状态**: ✅ 已修复

### BUG-016: SQL 语句拼接分隔符缺失
- **严重程度**: 🔴 高
- **文件**: `UniBase.Schema.pas`
- **问题**: `GetTier0SchemaSQL`, `GetTier1SchemaSQL`, `GetTier2SchemaSQL`, `GetFullSchemaSQL` 拼接 SQL 常量时没有换行分隔
- **表现**: `near "cn": syntax error`, `near "CREATE": syntax error` 等
- **修复**: 在所有 SQL 常量之间添加 `#13#10` 换行符
- **状态**: ✅ 已修复

### BUG-017: SQL 脚本与 Pascal 代码不一致
- **严重程度**: 🔴 高
- **文件**: `sql/tier1_init.sql`, `sql/tier2_init.sql`
- **问题**: SQL 脚本文件中的表结构与 `UniBase.Schema.pas` 中的定义不一致
- **影响**:
  - `Logs` 表: 列名 `Level` vs `LogLevel`，类型 INTEGER vs TEXT，缺少 ExceptionClass/ExceptionMessage/UserId 列
  - `MRU` 表: 列顺序不同，多余索引
  - `Hotkeys` 表: Shortcut 类型 INTEGER vs TEXT，多余列
  - `Themes` 表: 不同的列 (PreviewImage/Extra vs AccentColor/CustomCSS)
  - 版本号不一致 (1.0/2.0 vs 0.3)
  - 使用 `datetime('now')` 而不是 `CURRENT_TIMESTAMP`
- **修复**: 统一 SQL 脚本与 Pascal 代码，以 `UniBase.Schema.pas` 为准
- **状态**: ✅ 已修复

### BUG-018~024: Schema 初始化列数不匹配 (2025-12-01)
- **严重程度**: 🔴 高 (阻塞应用启动)
- **报告来源**: Insight 项目集成测试
- **文件**: `UniBase.Schema.pas`, `UniBase.Manager.pas`
- **问题描述**:
  - BUG-018: SchemaInfo INSERT 列数不匹配
  - BUG-019: ProjectInfo INSERT 列数不匹配
  - BUG-020: Settings 表缺少 ValueType 列
  - BUG-021: Languages INSERT 提供 7 个值但旧表只有 5 列
  - BUG-022: datetime('now') 被 FireDAC 误解析 (已在 BUG-015 修复)
  - BUG-023: MRU 表缺少 DisplayName 列
  - BUG-024: Logs 表缺少 LogTime 列
- **根本原因**: 旧版数据库表结构与新版 Schema 定义不兼容
- **修复方案**:
  1. `SQL_TIER0_LANGUAGES_DATA` 改用显式列名 INSERT
  2. 新增 `EnsureSchemaColumns` 方法自动检测并添加缺失列
  3. `CreateSchema` 修改为两次尝试机制：首次失败后调用 `EnsureSchemaColumns` 修复后重试
  4. 创建 `sql/upgrade_v0_2_to_v0_3.sql` 迁移脚本
- **影响方法**:
  - `TUniBaseManager.CreateSchema` - 重构为容错机制
  - `TUniBaseManager.EnsureSchemaColumns` - 新增自动修复方法
- **状态**: ✅ 已修复

### BUG-025: FMX I18n 控件未使用语言订阅
- **严重程度**: 🟡 中
- **文件**: `UniBase.FMX.I18nControls.pas`
- **问题**: `TFMXi18nLabel` 和 `TFMXi18nButton` 通过直接事件赋值处理语言变更，可能导致多实例冲突且释放时无法正确注销。
- **修复**: 改为使用 `UniBase.Manager.UniBase.I18n.SubscribeLanguageChange` / `UnsubscribeLanguageChange` 订阅语言变更事件，并在销毁时取消订阅。
- **状态**: ✅ 已修复

## 2025-12-02

### BUG-026: XOR 加密遗留实现仍可被调用
- **严重程度**: 🟡 中
- **文件**: `UniBase.Config.pas`
- **问题**: 配置模块仍然通过 XOR + Base64 方式实现 `GetConfigEncrypted`/`SetConfigEncrypted`，即使已经提供了基于 DPAPI 的安全模块。
- **修复**:
  - 移除 XOR 密钥常量和 EncryptValue/DecryptValue 实现
  - 将 `GetConfigEncrypted`/`SetConfigEncrypted` 修改为调用 `UniBase.Security.SaveSecret` / `LoadSecret`（DPAPI + Secrets 表）
  - 更新配置单元测试，验证密文存储在 Secrets 表中而非 Settings 表
- **状态**: ✅ 已修复

---

## 代码质量检查结果 (2025-12-01)

### QA-001: 非 Windows 平台加密不安全
- **严重程度**: 🔴 高
- **文件**: `UniBase.Security.pas`
- **问题**: 非 Windows 平台之前使用简单 UTF-8 编码作为 DPAPI 回退
- **修复**:
  - 新增 `UniBase.Crypto.OpenSSL.pas`：动态加载 libcrypto，实现 AES-256-GCM + PBKDF2
  - 修改 `UniBase.Security.pas` 非 Windows 分支，调用 OpenSSL 后端，使用 UBS2 格式
- **状态**: ✅ 已修复 (2025-12-02)

### QA-002: 泛型异常类型
- **严重程度**: 🟢 低
- **文件**: 多个文件
- **问题**: 使用 `raise Exception.Create(...)` 而非特定异常类型
- **修复**:
  - `UniBase.DB.ConnectionPool.pas`: 新增 `EConnectionPoolException` / `EConnectionPoolTimeout`
  - `UniBase.LLM.pas`: 新增 `ELLMException`
  - `UniBase.Memory.pas`: 新增 `EMemoryException` / `EMemoryPoolException` / `EMemoryCacheException`
  - `UniBase.Cache.pas`: 新增 `ECacheException`
- **状态**: ✅ 已修复 (2025-12-02, OPT-002)

### QA-003: 空 except 块
- **严重程度**: 🟢 低
- **文件**: 多个核心文件
- **统计**: 约 40+ 处空 except 块
- **分析**:
  - ✅ 大多数是有意设计的容错机制 (Destructor 清理、连接重试、回退逻辑)
  - ✅ DEBUG 模式下有 `OutputDebugString` 输出
  - ⚠️ 少数可能隐藏真正错误
- **主要位置**:
  - `UniBase.Manager.pas`: 12+ 处 (多为初始化/清理代码)
  - `UniBase.Logging.pas`: 8 处 (写入失败回退)
  - `UniBase.DB.DoQry.pas`: 6 处 (连接/查询失败处理)
- **状态**: 🟢 可接受 (设计意图明确，不影响功能)

### QA-004: TODO 标记待处理
- **严重程度**: 🟢 低
- **位置**:
  - `UniBase.Manager.pas`: INI 格式解析 TODO 已改为明确说明“当前不支持 INI 格式”
  - `UniBase.Config.pas`: 日志集成 TODO 已移除
  - `UniBase.FMX.Platform.pas`: 平台特定功能
  - `UniBase.CloudSync.pas`: 云同步功能
  - `UniBase.CLI.SSH.pas`: SSH 功能
- **状态**: ✅ 核心 TODO 已清理 (2025-12-02, OPT-004)

### QA-005: XOR 加密遗留代码
- **严重程度**: 🟡 中
- **文件**: `UniBase.Config.pas`
- **问题**: 早期版本使用 XOR + Base64 作为加密实现，安全性不足
- **当前状态**: 已在 2025-12-02 完全移除，改为委托 UniBase.Security（DPAPI + Secrets 表），详见 BUG-026
- **建议**: 使用 `UniBase.Security.SaveSecret/LoadSecret` 或 `GetConfigEncrypted/SetConfigEncrypted` 封装存取敏感配置
- **状态**: ✅ 已解决

---

## 代码质量总结

**整体评价**: 良好 ✅

**优点**:
- 核心模块有完整的 XMLDoc 文档
- 异常处理模式一致 (DEBUG 输出 + 回退机制)
- `UniBase.Reflection.pas` 等模块正确使用特定异常类型
- 线程安全设计合理 (锁、事件、原子操作)

**建议改进** (2025-12-02 已完成):
1. ✅ 为连接池、LLM、Memory、Cache 等模块添加了特定异常类型 (OPT-002)
2. ✅ 实现了跨平台加密方案：OpenSSL AES-256-GCM (OPT-001)
3. ✅ 清理了核心模块中过时的 TODO 注释 (OPT-004)
