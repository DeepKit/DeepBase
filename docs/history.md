# UniBase 开发历史记录

## 2025-12-01 代码审查与优化

### 安全性修复
- **CRYPTO-001**: 实现真正的 AES-256-CBC 加密（使用 Windows BCrypt API）
  - 文件: `UniBase.Crypto.pas`
  - 替换了不安全的 XOR 模拟实现
  
- **CRYPTO-002**: 使用 BCryptGenRandom 替换不安全的 Random() 调用
  - 文件: `UniBase.Crypto.pas`
  - 密码学安全的随机数生成

- **CONFIG-001**: 添加编译器警告到 XOR 加密方法
  - 文件: `UniBase.Config.pas`
  - 编译时强制提醒使用安全的加密方式

### 内存管理优化
- **ORM-001**: TQueryBuilder 实现 IQueryBuilder 接口
  - 文件: `UniBase.ORM.pas`
  - 自动引用计数，防止内存泄漏

- **CACHE-001**: 添加 FreeValueIfOwned 安全释放泛型对象
  - 文件: `UniBase.Cache.pas`
  - 使用 PPointer 安全获取对象指针

### IoC 容器修复
- **IOC-001**: RegisterSingleton 接口实例处理逻辑
  - 文件: `UniBase.IoC.pas`
  - 区分接口和类类型处理

### 代码重构
- **UTIL-001**: CompareVersions 提取到 UniBase.Types.pas
  - 统一版本比较逻辑，移除重复代码

- **INTERFACE-001**: TUniBaseConfig 和 TUniBaseI18n 实现接口
  - 文件: `UniBase.Config.pas`, `UniBase.i18n.pas`
  - 完善接口实现

### 国际化增强
- **I18N-001**: 集成 CLDR 复数规则
  - 文件: `UniBase.i18n.pas`, `UniBase.i18n.Plural.pas`
  - 支持 100+ 种语言的复数规则

### 日志系统优化
- **LOG-001**: 日志写入线程重构为批量处理模式
  - 文件: `UniBase.Logging.pas`
  - 减少锁竞争，提高性能

### 新增功能
- **E-001**: IoC 支持循环依赖检测
  - 文件: `UniBase.IoC.pas`
  - 解析时检测循环依赖并抛出清晰错误

- **E-002**: ORM 支持默认值 SQL 输出
  - 文件: `UniBase.ORM.pas`
  - CreateTableSQL 生成时包含 DEFAULT 子句

- **E-003**: Configuration 支持加密配置源
  - 文件: `UniBase.Configuration.pas`
  - TEncryptedConfigurationSource 自动解密 DPAPI 加密值

- **E-004**: Logging 支持结构化 JSON 日志
  - 文件: `UniBase.Logging.pas`
  - JSON Lines 格式输出

### DoQry 模块完善
- **DOQRY-001**: 扩展 CopyQueryToClientDataSet 类型覆盖
  - 使用 `Field.Assign` 正确处理多类型字段
  - 性能优化：`DisableControls`/`BeginBatchUpdate`/`LogChanges:=False`
  - 新增 3 个测试用例

- **DOQRY-002**: 查询缓存策略
  - 新增 `TQueryCacheEntry` 记录类型（SQL + ExpireTime）
  - `LoadQuerySQL` 支持 TTL 过期检查
  - API: `UniDbInvalidateQuery`, `UniDbSetCacheTTL`, `UniDbGetCacheStats`

- **DOQRY-003**: 新增 `docs/doQry_Guide.md` 使用指南（319 行）
  - 覆盖 API、参数绑定、Queries 表、缓存、事务、错误处理

- **DOQRY-004**: 日志字段对齐
  - `LogQuery` 重构为结构化 JSON 输出
  - SQL/参数仅在 DEBUG 级别记录

- **DOQRY-005**: 预编译语句池
  - 实现 `TPreparedEntry`、`GPreparedPool` 线程安全字典
  - API: `UniDbSetPreparedStatementPooling`, `UniDbClearPreparedStatements`, `UniDbGetPreparedStats`

- **DOQRY-006**: 错误码规范化
  - 定义 17 个错误码常量（`DOQRY_ERR_*`）
  - `EUniBaseDbError.ErrorCode` 字段 + `InferErrorCode` 自动推断

### 样例数据库完善
- 补全 `data/样例Config.db` 所有 17 个表
  - Tier 0: SchemaInfo, ProjectInfo, Settings, FormStates, Languages, I18nTexts
  - Tier 1: Logs, MRU, Hotkeys, Queries, Themes
  - Tier 2: LLMConfiguration, LLMCalls, ExceptionReports, AnimationAssets, TestSnapshots
  - Security: Secrets
- 更新 `docs/ARCH-QUICKSTART.md` 添加样例数据库说明

### LLM Prompt 模板管理系统 (LLM-001)
- Schema 扩展: `LLMPromptTemplates` 表新增字段
  - ParentTemplate (继承)
  - IncludeTemplates (组合)
  - OutputFormat (text/json/markdown)
  - ValidationRegex (输出验证)
  - Examples (示例 JSON)
- TLLMPromptTemplate 记录扩展: 支持继承链和模板组合
- 新增 API:
  - `SaveTemplate` / `DeleteTemplate` / `CopyTemplate`
  - `GetTemplatesByCategory`
  - `ValidateTemplate` (检测缺失变量、循环继承)
  - `RenderWithInheritance` (递归合并默认值)
  - `ExportTemplates` / `ImportTemplates` (JSON 格式)
- 单元测试: `Test.UniBase.LLM.PromptTemplate.pas` (15 个测试用例)
- Studio UI: `Studio.PromptTemplateFrame.pas` (1265 行)
  - 模板列表 (TreeView 按分类分组)
  - 模板编辑器 (Basic/Advanced/Test 三个 Tab)
  - 变量管理 (StringGrid)
  - 测试面板 (渲染预览 + LLM 执行)
  - 导入/导出 JSON

### LLM-001: Prompt 模板管理系统 Schema 补全
- **完成日期**: 2025-12-01
- **修改文件**:
  - `Core/UniBase.Schema.pas` - 添加 5 个 Prompt 管理表
  - `data/样例Config.db` - 创建表和示例数据（22个表）
  - `docs/ARCH-LLM.md` - 新增 LLM 模块架构文档
- **新增表**:
  - PromptCategories - 4级分类树
  - Prompts - 提示词主表
  - PromptVersions - 版本管理（每提示词最多4版本）
  - PromptMeta - 元提示词
  - PromptMetaBinding - 绑定关系
- **功能**:
  - 支持 `{{variable}}` 模板变量
  - 支持 PREFIX/SUFFIX/WRAP 元提示词合并
  - 支持 BoundQuery 上下文注入
  - 支持 A/B 测试和统计

### STUDIO-001: 完善 Studio 工具
- **完成日期**: 2025-12-01
- **描述**: 完善 UniBase Studio 的各功能模块
- **已完成子任务**:
  - i18n 翻译管理界面（TranslationForm）
  - 配置编辑器增强（分类筛选、搜索、即时保存）
  - 日志查看器（级别筛选、搜索、导出、自动刷新）
  - LLM 测试工具（TLLMManager）

### TEST-001: 单元测试覆盖率提升
- **完成日期**: 2025-12-01
- **描述**: 为核心模块补充单元测试
- **目标模块**:
  - UniBase.Configuration (80+ 个测试用例)
  - UniBase.IoC (19 个测试用例)
  - UniBase.Cache (40+ 个测试用例)
  - UniBase.EventBus (40+ 个测试用例)
  - UniBase.DB.DoQry (多项测试覆盖查询/缓存/错误处理)

### DOC-001: API 文档完善
- **完成日期**: 2025-12-01
- **描述**: 为公开 API 添加 XMLDoc 注释
- **已完成**:
  - UniBase.Manager.pas
  - UniBase.Config.pas
  - UniBase.Logging.pas
  - UniBase.DB.DoQry.pas

### FMX-001: FMX 控件库
- **完成日期**: 2025-12-01
- **描述**: 为 FMX 平台提供与 VCL 对等的核心控件支持
- **内容**:
  - TFMXi18nLabel / TFMXi18nButton 语言切换控件（使用 Subscribe/Unsubscribe 模式）
  - TFMXFormStateHelper 组件（保存/恢复窗体状态）
  - TFMXConfigEdit / TFMXConfigSpinBox / TFMXConfigSwitch 三个配置编辑控件

### PERF-001: 性能基准测试
- **完成日期**: 2025-12-01
- **描述**: 建立性能基准测试套件
- **文件**: `Tests/Test.UniBase.Performance.pas`
- **测试项**:
  - 配置读写性能 (Cached/Uncached/Write/Batch)
  - 日志写入性能 (Info/Formatted/Concurrent)
  - 缓存性能 (Get Hit/Miss/Set/GetOrAdd/Concurrent)
  - DoQry 查询性能 (Select/Parameterized/Insert/Update)
- **性能目标** (i7-10700 参考):
  - Config Read (cached): > 50K ops/sec
  - Log Write (async): > 100K ops/sec
  - Cache Hit: > 500K ops/sec
  - DoQry Select: > 5K ops/sec

### DOQRY-TESTS: DoQry 测试与文档任务
- **完成日期**: 2025-12-01
- **说明**: 对应上文 DOQRY-001 ~ DOQRY-006 改动（单元测试、缓存策略、预编译语句池、错误码等）

## 2025-12-02 优化与清理

### OPT-002: 特定异常类型
- **描述**: 为核心模块定义特定异常类型，提高错误处理精细度，便于上层捕获和分类处理。
- **修改文件**:
  - `Core/UniBase.DB.ConnectionPool.pas`: 新增 `EConnectionPoolException` / `EConnectionPoolTimeout`，`Acquire` 超时时抛出特定异常
  - `Core/UniBase.LLM.pas`: 新增 `ELLMException`，在保存模板时对空名称抛出特定异常
  - `Core/UniBase.Memory.pas`: 新增 `EMemoryException` / `EMemoryPoolException` / `EMemoryCacheException`，对象池和智能缓存使用特定异常
  - `Core/UniBase.Cache.pas`: 新增 `ECacheException` 作为缓存相关异常基类

### OPT-003: 移除 XOR 加密遗留代码
- **描述**: 完全移除配置模块中的 XOR + Base64 加密实现，统一改用 DPAPI + Secrets 表存储敏感数据。
- **修改文件**:
  - `Core/UniBase.Config.pas`: 移除 `CONFIG_ENCRYPT_KEY` 及 XOR 加解密实现；`GetConfigEncrypted`/`SetConfigEncrypted` 改为调用 `UniBase.Security.LoadSecret` / `SaveSecret`
  - `Core/UniBase.Interfaces.pas`: 保留加密配置接口，作为安全存储的薄封装层
  - `Tests/Test.UniBase.Config.pas`: 更新加密配置相关测试，验证数据存储在 Secrets 表而非 Settings 表
- **影响**:
  - 旧 XOR 加密配置不再受支持，需通过迁移脚本或一次性读取+重写迁移到 Secrets 表

### OPT-004: 清理 TODO 注释
- **描述**: 清理过时的 TODO 标记，避免与当前实现状态不符。
- **修改文件**:
  - `Core/UniBase.Manager.pas`: 将 `ReadRootTxt` 中的 INI 格式 TODO 改为明确说明“当前不支持 INI 格式 root.txt”，并保持记录失败日志的行为
  - `Core/UniBase.Config.pas`: 移除 `GetConfigInt` 中关于日志集成的 TODO，仅保留“类型转换失败返回默认值”的说明

### OPT-001: 跨平台加密实现
- **描述**: 为 macOS/Linux 平台实现安全加密，替换原不安全的简单编码回退。
- **新增文件**:
  - `Core/UniBase.Crypto.OpenSSL.pas`: OpenSSL libcrypto 动态加载器，提供 AES-256-GCM 加解密、PBKDF2-HMAC-SHA256 密钥派生、RAND_bytes 安全随机数
- **修改文件**:
  - `Core/UniBase.Security.pas` (v0.31 → v1.0): 非 Windows 分支调用 OpenSSL 后端，实现 UBS2 格式
  - `Tests/Test.UniBase.Security.pas`: 新增篡改检测测试、OpenSSL 后端测试
- **实现方案**:
  - Windows: 保持 DPAPI（用户级加密）
  - macOS/Linux: OpenSSL AES-256-GCM + PBKDF2-HMAC-SHA256 (100,000 迭代)
- **UBS2 数据格式**: `[Magic:4][Ver:1][KDF:1][Iter:4][Salt:16][IV:12][Cipher:N][Tag:16]`
- **安全特性**:
  - AEAD 认证加密（GCM 16 字节 Tag）
  - 每次加密随机 Salt/IV（防重放）
  - 机器特定熵源派生密钥（或 UNIBASE_MASTER_KEY 环境变量覆盖）
- 要求随应用打包 libcrypto

### SEC-001: RSA 签名验证实现
- **完成日期**: 2025-12-02
- **描述**: 为更新系统实现真正的 RSA-SHA256 签名验证，替换原来的占位实现。
- **修改文件**:
  - `Core/UniBase.Crypto.pas`: 新增 `TRSAVerifier` 类，使用 Windows CNG (BCrypt) 实现：
    - `LoadPublicKeyPEM` / `LoadPublicKeyDER` / `LoadPublicKeyFile` - 支持 PEM/DER 格式公钥加载
    - `VerifySignature` - RSA-SHA256 + PKCS#1 v1.5 填充签名验证
    - 内部实现：ASN.1 DER 公钥解析、BCrypt RSA 导入、SHA256 哈希
  - `Core/UniBase.Updater.pas`: 更新 `VerifySignature` 方法调用 `TRSAVerifier`
  - `Tests/Test.UniBase.Crypto.pas`: 新增 `TRSAVerifierTests` 测试套件 (8 个测试用例)
- **BCrypt API 声明**: `BCryptImportKeyPair`, `BCryptVerifySignature`, `BCryptHash`
- **平台支持**: Windows (BCrypt), 其他平台待实现 (OpenSSL)

### SSH-001: SSH 连接池空闲清理线程
- **完成日期**: 2025-12-02
- **描述**: 实现后台线程自动清理空闲的 SSH 连接，防止连接池资源耗尽。
- **修改文件**: `Core/UniBase.CLI.SSH.pas` (v0.1 → v0.2)
- **新增类**: `TSSHCleanupThread` - 后台清理线程
  - 使用 `TEvent` 实现可中断等待
  - 可配置清理间隔（默认 60 秒）
  - 线程安全的停止机制
- **修改类**: `TSSHConnectionPool`
  - 新增 `FCleanupThread` 和 `FCleanupInterval` 字段
  - 构造函数增加 `CleanupInterval` 参数（默认 60 秒）
  - 新增公开方法 `CleanupIdleSessions` 支持手动触发清理
  - 析构函数正确停止并释放清理线程
- **行为**: 后台线程每隔 `CleanupInterval` 秒检查并断开超过 `IdleTimeout` 未活动的连接

### SYNC-001: JSON 深度合并实现
- **完成日期**: 2025-12-02
- **描述**: 为云同步模块实现 JSON 对象的深度合并功能，支持多种数组合并策略。
- **修改文件**: `Core/UniBase.CloudSync.pas`
- **新增类型**: `TArrayMergeStrategy` 枚举
  - `amsReplace` - 替换（用源数组替换目标数组）
  - `amsAppend` - 追加（将源数组元素追加到目标）
  - `amsMergeByIndex` - 按索引合并（对象元素递归合并）
  - `amsUnion` - 并集去重（基于 JSON 值相等性）
- **新增函数**:
  - `JSONDeepMerge` - 递归合并两个 JSON 对象
  - `JSONClone` - 克隆 JSON 值
  - `JSONValuesEqual` - 比较 JSON 值相等性
  - `JSONMergeArrays` - 按策略合并 JSON 数组
- **修改方法**: `TCloudConfigSync.MergeItems`
  - JSON 类型配置现在使用深度合并（本地为基础，远程合并进来）
  - 默认使用 `amsUnion` 策略（数组去重合并）
  - 更新合并后的版本信息和校验和

### TEST-002: 补充缺失模块单元测试
- **完成日期**: 2025-12-02
- **描述**: 为 CloudSync、SSH、Updater 三个缺失测试的模块补充完整单元测试。
- **新增测试文件**:
  - `Tests/Test.UniBase.CloudSync.pas` - 7 个测试套件，覆盖:
    - JSON 深度合并函数 (JSONDeepMerge, JSONMergeArrays, JSONClone, JSONValuesEqual)
    - 四种数组合并策略 (Replace, Append, MergeByIndex, Union)
    - TLocalConfigStore CRUD 操作及持久化
    - TConfigItem 序列化/反序列化
    - TConfigVersion、TSyncProgress、TSyncStatistics 记录类型
  - `Tests/Test.UniBase.CLI.SSH.pas` - 8 个测试套件，覆盖:
    - TSSHCredentials 密码/公钥认证创建
    - TSSHOptions 默认值及主机字符串解析
    - TSSHResult OK/Error 工厂方法
    - TMockSSHBackend 连接/执行/Mock响应
    - TSSHSession 状态管理
    - TSSHConnectionPool 会话管理、最大连接限制、空闲清理
    - TSSHCleanupThread 线程行为
    - TSSHManager 别名管理
  - `Tests/Test.UniBase.Updater.pas` - 6 个测试套件，覆盖:
    - TSemanticVersion 解析/比较/运算符
    - 更新通道枚举 (ParseChannel, ChannelToString)
    - TUpdateInfo.IsEmpty 判断
    - TUpdateManager 初始化和配置
    - TUpdateProgress 进度百分比计算
    - 版本边缘情况测试

### FMX-002: FMX LLM 配置面板
- **完成日期**: 2025-12-02
- **描述**: 为 FMX 平台实现与 VCL 对等的 LLM 配置面板组件
- **新增文件**: `FMX/UniBase.FMX.LLMConfigPanel.pas`
- **修改文件**: `FMX/UniBase.FMX.Controls.pas` (添加注册)
- **组件**: `TFMXLLMConfigPanel`
- **功能**:
  - Provider 选择 (OpenAI/Anthropic/Azure/LiteLLM/Ollama/Custom)
  - API Key / Base URL / Model 配置
  - MaxTokens / Temperature 参数设置
  - 测试连接功能
  - 调用历史显示 (TStringGrid)
  - 配置保存/重置
- **API 与 VCL 版本对等**:
  - `ConfigName` 属性
  - `Connection` 属性
  - `SetLLM` 方法
  - `RefreshConfig` / `RefreshData` 方法
  - `OnConfigChanged` 事件

### DOC-002: 快速入门文档
- **完成日期**: 2025-12-02
- **描述**: 创建独立的快速入门文档
- **输出物**: `docs/QuickStart.md` (433 行)
- **内容**:
  - 系统要求和安装步骤
  - 控制台最小示例
  - VCL 应用完整示例 (DPR + 窗体)
  - 8 个核心功能速览:
    1. 配置管理 (GetConfig/SetConfig)
    2. 国际化 (T/TFmt)
    3. 日志系统 (Debug/Info/Warn/Error)
    4. 窗体状态管理 (TFormStateHelper)
    5. 单实例检测 (TAppInstance)
    6. 数据导出 (TDataExport)
    7. 启动画面 (TSplashScreen)
    8. LLM 集成 (Chat/ChatAsync)
  - VCL 控件一览表 (10 个控件)
  - 常见问题解答 (4 个 FAQ)
  - 示例工程指引

### PERF-002: SSH 连接池异步获取和超时等待
- **完成日期**: 2025-12-02
- **描述**: 优化 SSH 连接池并发场景下的阻塞问题
- **修改文件**: `Core/UniBase.CLI.SSH.pas` (v0.2 → v0.3)
- **新增 API**:
  - `GetSessionWithTimeout(Options, Creds, TimeoutMs)` - 带超时的同步获取
  - `TryGetSession(Options, Creds, Session)` - 无等待尝试获取，返回 TSSHAcquireResult
  - `GetSessionAsync(Options, Creds, Callback, TimeoutMs)` - 异步获取，回调在主线程执行
  - `WaitingCount` - 获取当前等待线程数
  - `DefaultAcquireTimeout` - 默认超时时间 (30000ms)
- **新增类型**:
  - `TSSHAcquireResult` 枚举 (arSuccess, arTimeout, arPoolFull, arConnectFailed)
  - `TSSHSessionCallback` - 异步回调类型
- **实现细节**:
  - 使用 `TEvent` 实现可中断等待
  - `ReleaseSession` 时自动通知等待线程
  - `TInterlocked.Increment/Decrement` 线程安全计数
- **新增测试**: 6 个测试用例
  - Test_WaitingCount_InitiallyZero
  - Test_GetSessionWithTimeout_ZeroTimeout_NoWait
  - Test_TryGetSession_ReturnsPoolFull_WhenFull
  - Test_DefaultAcquireTimeout_CanBeSet
  - Test_GetSessionAsync_CallsCallback
  - Test_CleanupIdleSessions 更新

### BUG-027: TFDScript 参数解析导致 SQL 语法错误
- **完成日期**: 2025-12-03
- **描述**: 修复多个集成 UniBase 的应用在启动时报告 SQLite 语法错误
- **错误信息**: `near "now": syntax error`, `near "cn": syntax error`, `near "SYS": syntax error`
- **修改文件**:
  - `Core/UniBase.Schema.pas`: 将 `datetime('now')` 改为 `CURRENT_TIMESTAMP`，将字符串内 `#13#10` 改为 `|| char(10) ||`
  - `Core/UniBase.Manager.pas`: 完全移除 TFDScript，改用 TFDQuery 逐条执行 SQL
- **修复方案**:
  1. 完全移除 TFDScript，避免其对多语句 SQL + Unicode 的解析问题
  2. 新增 `SplitSQLStatements` 函数，按分号分割但尊重字符串字面量
  3. 设置 `Query.ResourceOptions.ParamCreate := False`
  4. 使用 SQLite 的 `CURRENT_TIMESTAMP` 替代 `datetime('now')`
  5. 使用 `|| char(10) ||` 替代字符串内的 `#13#10`

