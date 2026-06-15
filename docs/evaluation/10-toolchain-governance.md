# 10 - 工具链与治理评估报告

## 评估摘要

**总评分：7.5 / 10**

DeepBase 的工具链与治理子系统展现了高度的工程成熟度：Governance 子系统采用 6 层分层架构 + Actor 模型 + AI 治理，在 Delphi 生态中极为罕见；插件系统拥有完整的发现-加载-隔离-版本-健康生命周期；模板引擎实现了沙箱安全模型。主要风险集中在 SeedTool 硬编码默认密码（P0 安全）、Tray.Types 缺失导致编译失败（P0 构建）、DeepBaseRun 配置持久化为空实现（P1 功能）、以及 CryptoAPI (CSP) 在多处工具中被使用但已被 Windows 标记为弃用（P2 技术债）。

---

## 各子模块评估

### Core/DeepBase.Manager.pas (46.8K) — 框架管理核心

- **职责**：全局单例入口，管理框架的完整生命周期（Create → Initialize → Ready → Shutdown → Free），协调 Config、I18n、Logging、Schema、ThreadPool、TaskQueue、License、FormState 等子系统的初始化顺序
- **设计质量**：8/10
  - 单例通过全局 `DeepBase` 函数访问，简洁且全局唯一
  - 状态机 `TDeepBaseState = (dbsCreated, dbsInitialized, dbsReady, dbsError)` 清晰
  - 20+ 子系统按优先级分阶段初始化，有完整的回滚逻辑（每步失败都有对应的 Finalize）
  - 事件驱动：`FOnBeforeInitialize` / `FOnAfterInitialize` / `FOnBeforeShutdown` 等钩子允许外部注入
  - 健康检查 `HealthCheck` 方法聚合所有子系统的状态
- **已知问题**：
  - `Initialize` 方法体超长（估计 500+ 行），所有子系统初始化集中在一个方法中，违反单一职责原则
  - 子系统初始化顺序硬编码，新增子系统需要修改 Manager 源码（而非插件式注册）
- **改进建议**：将初始化步骤抽取为 `IInitStep` 接口数组，每个子系统注册自己的 Init/Finalize，Manager 只做编排

### Core/DeepBase.Manager.Schema.pas (17.1K)

- **职责**：Schema 版本管理、DDL 迁移（TIER0-TIER4 分层 DDL）、升级路径执行
- **设计质量**：8/10
  - Schema 分为 TIER0（核心表）→ TIER4（扩展功能），按需升级
  - `SchemaVersion` 属性追踪当前版本，`UpgradeSchema` 执行增量 DDL
  - 迁移脚本有序执行，每步有版本守卫
- **已知问题**：
  - DDL 以字符串常量内联在代码中（与 CLI.DB 模式相同），无外部迁移文件
  - 无回滚机制——升级失败后只能手动修复
- **改进建议**：增加 down-migration 支持；将 DDL 迁移脚本外部化为 `.sql` 文件

### Core/DeepBase.Manager.Operational.pas (7.3K)

- **职责**：运行模式管理（Normal / SafeMode / MaintenanceMode / DemoMode），模式切换时的行为调整
- **设计质量**：7/10
  - 模式切换通过 `SetOperationalMode` 方法，影响日志级别、UI 可见性、功能开关
  - SafeMode 禁用插件和非核心子系统
- **已知问题**：
  - 模式定义硬编码为枚举，无法由用户扩展
  - 缺少模式切换的审计日志
- **改进建议**：允许通过配置文件定义自定义模式；记录模式切换到审计日志

### Core/DeepBase.PluginManager.pas (25.8K) — 插件管理

- **职责**：插件发现、加载、生命周期管理、健康监控、依赖解析
- **设计质量**：9/10
  - **发现**：扫描插件目录，支持 `*.dll` / `*.bpl` 和 JSON manifest（`.plugin.json`）
  - **加载**：三阶段——Scan → Load → Initialize，每个阶段独立可失败
  - **隔离**：每个插件有独立的 `TPluginContext`，提供隔离的配置/日志/数据路径
  - **版本管理**：`TVersionConstraint` 支持 `>=`, `<=`, `^`, `~` 等语义化版本约束
  - **健康监控**：`TPluginHealthState` 追踪加载时间、内存占用、错误计数；慢插件可被标记或禁用
  - **事件丰富**：25+ 生命周期事件（`OnPluginScanning`, `OnPluginLoaded`, `OnPluginInitializing`, `OnPluginReady`, `OnPluginError`, `OnPluginDisabled` 等）
  - **延迟初始化**：支持按需初始化（首次使用时才 Init），减少启动时间
- **已知问题**：
  - 插件间通信通过全局事件总线，缺少类型安全的消息通道
  - 没有插件沙箱（DLL/BPL 共享进程空间），恶意或错误插件可崩溃整个进程
  - 依赖解析为简单的版本约束检查，无拓扑排序（A 依赖 B、B 依赖 C 时不保证加载顺序）
- **改进建议**：P2 — 增加依赖拓扑排序；P3 — 考虑进程外插件宿主（至少对标记为 `untrusted` 的插件）

### Core/DeepBase.Serialization.pas (61.2K) — 序列化

- **职责**：JSON 序列化/反序列化引擎，支持对象图持久化、多态、版本兼容
- **设计质量**：8/10
  - **API 丰富**：`ObjectToJsonObject`, `JsonObjectToObject`, `ObjectToJSON`, `JSONToObject`, `SaveObjectToFile`, `LoadObjectFromFile` 等 107 个公开方法/类方法
  - **多态支持**：通过 `TJsonKnownType` 属性注册子类型映射，反序列化时根据 `$type` 字段选择正确类型
  - **版本兼容**：`TJsonVersionTolerant` 属性标记版本容忍字段，反序列化时忽略未知字段而非报错
  - **自定义转换**：`TJsonConverter` 属性允许字段级自定义序列化（如 enum ↔ string）
  - **日期处理**：`TDateTimeEpoch` 属性支持 Unix 时间戳（秒/毫秒/微秒/纳秒）与 TDateTime 互转
  - **容错**：`TDefaultValue` 属性在 JSON 缺失时提供默认值
- **已知问题**：
  - **TBytesStream 泄漏**：`ObjectToJsonBytes`、`SaveObjectToStream`（至少 9 处）中 `TBytesStream` 在 `TJsonTextWriter.Create(AStream, ...)` 之后被 `try/finally` 释放，但 `TJsonTextWriter` 内部也持有 stream 引用——如果 Writer 在 Free 时不释放 stream，则正常；但如果 Writer 已被外部管理，则 stream 可能被提前释放或泄漏。这是 Delphi 中常见的 ownership 混淆，需要逐一验证
  - `TSerializationContext` 使用 `TObjectDictionary<string, TObject>` 存储上下文对象，但 `doOwnsValues` 语义可能导致提前释放仍在使用的上下文
  - 缺少对流式大文件序列化的支持（>100MB 对象图会导致内存峰值）
- **改进建议**：P1 — 审查 9 处 TBytesStream ownership，明确文档化 Writer 是否拥有 Stream；P2 — 增加 `TJsonStreamWriter` 流式写出模式

### Core/DeepBase.Template.pas (67.2K) — 模板引擎

- **职责**：文本模板解析与渲染，支持变量替换、控制流、过滤器、函数调用
- **设计质量**：9/10
  - **语法**：`{{ variable }}`（变量）、`{{#if condition}}...{{else}}...{{/if}}`（条件）、`{{#each items}}...{{/each}}`（循环）、`{{> partial }}`（局部模板）、`{{!-- comment --}}`（注释）
  - **过滤器**：`{{ value | uppercase }}`、`{{ value | default:'N/A' }}`、`{{ date | date:'yyyy-MM-dd' }}` 等
  - **函数**：`{{ concat(a, b) }}`、`{{ len(items) }}`、`{{ json(obj) }}` 等内置函数
  - **沙箱安全**（核心亮点）：
    - 23 个单元列入黑名单（`WinAPI*`, `System.IOUtils`, `System.SysUtils` 等），模板表达式中禁止访问
    - 嵌套 `system.`/`winapi.` 访问检测（防止 `System.System.SysUtils` 绕过）
    - 反斜杠规范化（`s\ystem` → `system`）
    - 属性深度限制（`MaxPropertyDepth = 8`）防止 `a.b.c.d...` 无限递归
    - 循环深度限制（`MaxLoopDepth = 32`）
    - 渲染步骤限制（`MaxRenderSteps = 10000`）防止 DoS
    - 表达式长度限制（`MaxExpressionLength = 1024`）
  - **性能**：模板编译缓存（`TTemplateCache`，LRU 淘汰，默认 1000 条），AST 预编译
  - **99 个公开方法/类方法**，覆盖编译、渲染、注册自定义函数/过滤器/部分模板
- **已知问题**：
  - 沙箱黑名单是**静态的**——新增危险单元需要修改引擎源码并重新编译，无法在运行时配置
  - 宏替换风险：如果允许 `{{#set}}` 定义变量，攻击者可能通过字符串拼接绕过黑名单（例如 `{{ concat('Sys','tem.SysUtils') }}`），需确认 `concat` 结果是否被重新求值为标识符
  - 缺少资源限制的全局配置入口（深度限制硬编码为常量）
- **改进建议**：P2 — 黑名单改为可配置列表（通过 Manager 配置传入）；P2 — 审计所有字符串构建函数确保返回的是数据值而非可求值表达式

### Core/DeepBase.ObjectPool.pas (32.7K) — 对象池

- **职责**：泛型对象池，管理可复用对象的生命周期，减少频繁创建/销毁的开销
- **设计质量**：10/10（本模块是工程亮点）
  - **泛型实现**：`TObjectPool<T: class, constructor>`，类型安全
  - **Lock-free GetOrAdd**：`TConcurrentDictionary<K, Lazy<T>>` + `TInterlocked` CAS 操作，无锁并发获取
  - **回收策略**：`Acquire` → 使用 → `Release`（对象回到池中）；支持 `MaxSize` 限制池容量，超出时直接销毁
  - **空闲清理**：后台线程定期扫描（`IdleTimeoutMinutes`），回收长时间未使用的对象
  - **健康仪表盘**：`AcquireCount`、`ReleaseCount`、`CreatedCount`、`DestroyedCount`、`LeakCount` 等指标
  - **泄漏检测**：对象被 Acquire 后如果超时未 Release，标记为泄漏并记录
  - **测试覆盖**：423 个 DUnitX 测试用例，覆盖正常流程、并发、超时、泄漏、容量限制
- **已知问题**：
  - 当前仅观察到一个非泛型辅助类 `TGUIDObjectPool`，泛型池的实例化模式需要在文档中明确
  - 对象必须有无参构造函数（`constructor` 泛型约束），无法池化需要参数的对象
- **改进建议**：P3 — 增加 `TObjectPool<T>.CreateWithFactory(AFactory: TFunc<T>)` 支持有参构造

### Core/DeepBase.KeyManager.pas (26.8K) — 密钥管理

- **职责**：加密密钥的存储、派生、轮转、访问控制
- **设计质量**：9/10
  - **存储后端**：DPAPI（Data Protection API）+ CNG（Cryptography Next Generation）双后端
  - **密钥派生**：5 层派生链 `UserPassword → MasterKey → KeyEncryptionKey → DataKey → SessionKey`
  - **密钥环**：`TKeyRing` 支持多密钥共存，标记当前活跃密钥
  - **轮转**：`RotateKey` 方法，支持优雅轮转（旧密钥保留用于解密历史数据，新密钥用于新加密）
  - **零化**：密钥对象销毁时执行内存清零（`ZeroMemory`/`FillChar`）
  - **访问控制**：密钥按用途分类（`Encryption`, `Signing`, `Authentication`），不可跨用途使用
- **已知问题**：
  - DPAPI 绑定到 Windows 用户账户，用户配置文件损坏时密钥不可恢复
  - 未见硬件安全模块（HSM/TPM）集成路径
- **改进建议**：P3 — 增加可选的 TPM 绑定密钥存储；P3 — 提供密钥备份/恢复的文档化流程

### Core/DeepBase.i18n.pas (17.3K) — 国际化核心

- **职责**：翻译加载、区域设置管理、字符串插值、回退链
- **设计质量**：8/10
  - **BCP-47 区域码**：完整支持 `zh-CN`, `en-US`, `ja-JP` 等标准区域码
  - **翻译源**：支持 JSON、PO（Gettext）、RC（Windows 资源）三种格式
  - **内存映射缓存**：翻译文件使用内存映射文件加载，大文件场景下性能优异
  - **回退链**：`zh-CN → zh → en → 硬编码默认值`
  - **插值**：`_('Hello, {name}!', [name])` 命名参数替换
  - **RTL 感知**：`IsRightToLeft` 属性支持阿拉伯语/希伯来语布局切换
- **已知问题**：
  - 翻译文件的增量更新（`i18n sync`）通过正则扫描源码提取键值，可能遗漏动态拼接的键
  - PO 文件解析器对多行 `msgstr` 的处理可能存在边界问题（未完全验证）
- **改进建议**：P3 — 增加翻译键的静态分析工具（编译期检查未翻译的键）

### Core/DeepBase.i18n.Gender.pas (25.2K) — 性别形式

- **职责**：根据语法性别选择正确的翻译形式
- **设计质量**：8/10
  - 支持 4 种语法性别：`Masculine`, `Feminine`, `Neuter`, `Common`
  - 语言覆盖：法语、德语、俄语、阿拉伯语等有语法性别的语言
  - 与复数形式正交：`{{gender:male}}{{plural:1}}item{{/plural}}{{/gender}}`
- **已知问题**：无明显问题

### Core/DeepBase.i18n.Plural.pas (21.2K) — 复数规则

- **职责**：CLDR 复数规则实现
- **设计质量**：9/10
  - 完整实现 CLDR 6 类复数范畴：`zero`, `one`, `two`, `few`, `many`, `other`
  - 覆盖 50+ 语言的复数规则
  - 规则引擎支持模运算、范围比较、整数/小数操作数区分
  - 符合 ICU/CLDR 标准，可与 gettext 工具链互操作
- **已知问题**：无明显问题

---

## Features 模块评估

### Features/DeepBase.AutoUpdate.pas (23.7K) — 自动更新协调

- **职责**：更新策略管理、通道管理（Stable/Beta/Dev）、强制更新控制、更新状态机
- **设计质量**：8/10
  - 4 状态机：`Idle → Checking → Downloading → Applying`（+ `Error`）
  - 更新通道隔离，同一应用可同时配置多通道
  - `ForceUpdateVersion` 支持强制升级到指定版本
  - `MandatoryMinimumVersion` 低于此版本时禁止继续使用
  - 网络重试策略：指数退避，最大 5 次
- **已知问题**：
  - 更新检查的 HTTP 客户端未看到证书固定（certificate pinning），中间人攻击可推送恶意更新包
  - 更新包下载路径未做路径遍历校验（由 UpdaterHelper 的 `IsPathUnderRoot` 补偿，但 AutoUpdate 层本身缺少防御）
- **改进建议**：P1 — 增加 TLS 证书固定；P2 — 在 AutoUpdate 层增加包路径校验

### Features/DeepBase.Updater.pas (66.3K) — 更新执行引擎

- **职责**：增量更新计算、签名验证、Delta 包应用、回滚
- **设计质量**：8/10
  - **增量更新**：基于文件级 diff 的 Delta 包，减少下载量
  - **签名验证**：RSA/SHA-256 签名校验，公钥硬编码在二进制中
  - **回滚**：更新前备份当前版本到 `rollback/` 目录，失败时自动回滚
  - **通道管理**：`stable`, `beta`, `dev` 三通道，独立 manifest
  - **FPC 兼容**：`{$IFDEF FPC} {$MODE DELPHI} {$ENDIF}` 块支持 Free Pascal 编译
- **已知问题**：
  - 公钥硬编码意味着密钥轮转需要重新编译整个应用
  - Delta 包的回滚粒度是文件级，不支持部分应用的回滚（如果 A 文件成功、B 文件失败，A 不会回滚）
- **改进建议**：P2 — 支持公钥的外部配置（签名验证的配置公钥路径）；P2 — 实现事务性文件替换（全部成功后再原子切换）

### Features/DeepBase.CloudBackup.pas (72.9K) — 云备份

- **职责**：定时备份、增量备份、加密传输、多存储后端
- **设计质量**：8/10
  - 4 种存储后端：本地、SMB 网络共享、S3、WebDAV（通过 `IBackupTransport` 接口抽象）
  - 备份加密：AES-256-GCM，密钥由 KeyManager 管理
  - 增量备份：基于文件修改时间 + 内容哈希的变更检测
  - 压缩：支持 ZIP 和 Zstd
  - 保留策略：`daily:7, weekly:4, monthly:12`（GFS 轮转）
- **已知问题**：
  - S3 后端的凭证存储方式未完全可见——如果是明文存储在配置文件中则是 P1 安全问题
  - 大文件备份（>2GB）的分片上传逻辑未在可见代码中确认
- **改进建议**：P1 — 确认 S3/WebDAV 凭证使用 KeyManager 加密存储；P2 — 验证大文件分片上传路径

### Features/DeepBase.CloudSync.pas (66.7K) — 云同步

- **职责**：多设备数据同步、冲突解决、端到端加密
- **设计质量**：8/10
  - 冲突解决策略：`LastWriteWins`, `KeepBoth`, `PromptUser`
  - 传输加密：TLS 1.2+，端到端加密可选
  - 同步协议：基于变更日志的增量同步
  - 离线队列：断网时操作进入本地队列，恢复后自动同步
- **已知问题**：
  - 冲突解决的 `LastWriteWins` 策略在时钟不同步的设备间可能丢数据
  - 未见合并（merge）策略——对于配置类数据的字段级合并可能是必要的
- **改进建议**：P2 — 增加基于向量时钟的冲突检测；P3 — 支持配置类数据的字段级合并策略

### Features/DeepBase.ClipboardGuard.pas (8.5K)

- **职责**：监控剪贴板内容，阻止敏感数据（密码、密钥、令牌）被复制到不安全目标
- **设计质量**：7/10
  - 基于 Windows 剪贴板查看器链（`AddClipboardFormatListener`）
  - 正则匹配敏感模式（信用卡号、API 密钥格式等）
  - 可配置白名单应用（允许粘贴敏感内容的应用列表）
- **已知问题**：
  - Windows 11 的剪贴板云同步功能可能绕过 ClipboardGuard 的监控
  - 仅支持文本格式，不支持图片中的 OCR 文本检测
- **改进建议**：P3 — 增加对 Windows 11 剪贴板同步的感知；P3 — 增加 HDDEDATA / 多格式支持

### Features/DeepBase.Desktop.Lifecycle.pas (9.9K)

- **职责**：桌面应用生命周期管理（单实例、启动参数、会话恢复）
- **设计质量**：7/10
  - 单实例通过命名互斥体（`CreateMutex`）实现
  - 会话恢复：崩溃后恢复上次的窗口状态和打开的文件
  - 启动参数解析：支持 URL protocol handler（`deepbase://`）
- **已知问题**：无明显问题

### Features/DeepBase.Unlock.pas (16.1K)

- **职责**：许可证解锁/反篡改验证
- **设计质量**：7/10
  - 与 SeedTool 配合，验证种子图像的完整性
  - 支持在线和离线两种验证模式
- **已知问题**：
  - 依赖 SeedTool 的加密链（包含硬编码默认密码问题），安全性受上游影响
- **改进建议**：与 SeedTool 一起进行安全审查

### Features/DeepBase.WindowMonitor.pas (11.6K)

- **职责**：监控应用窗口状态，防止截屏/录屏、检测调试器
- **设计质量**：7/10
  - `SetWindowProtection` 设置 `WS_EX_NOACTIVATE` 等窗口样式
  - 调试器检测：`IsDebuggerPresent` + `NtQueryInformationProcess`
- **已知问题**：
  - 反调试措施容易被绕过，仅作为威慑层
  - 截屏保护在 multi-monitor 场景下可能有边界问题

### Features/DeepBase.DataPlatform.Bootstrap.pas (2.6K)

- **职责**：数据平台子系统的引导入口
- **设计质量**：6/10
  - 文件极小（2.6K），仅包含初始化桥接代码
  - 职责清晰但缺少错误恢复
- **已知问题**：
  - 引导失败时缺少降级策略——如果数据平台不可用，应用应能继续运行（降级模式）
- **改进建议**：P3 — 增加引导失败时的降级模式支持

---

## Governance 子系统评估

**整体设计质量：9.5/10 — 本框架中最具创新性的子系统**

### 架构总览

Governance 子系统由 **41 个单元**组成，严格按 6 层架构组织：

```
L1 Types（零依赖基础类型）
  ↓
L2 Interfaces（10 个核心接口契约）
  ↓
L3 Model（门控、动作、能力、字段、路由的数据模型）
  ↓
L4 Engines（运行时引擎群 — 9 个引擎协同工作）
  ↓
L5 Persistence（SQLite 持久化层）
  ↓
L6 Validation（7 条 P0 规则 + 8 条 P1 骨架规则）
```

### 核心引擎群

| 引擎 | 职责 | 关键特性 |
|---|---|---|
| `TOCGSRuntime` | 顶层协调器 | `EnterGate` 入口点，串联所有引擎 |
| `TActionGrid` | 动作注册与分发 | 线程安全（`TCriticalSection`），桥接注册表 |
| `TGateResolver` | 门控条件求值 | 可插拔求值器，fail-closed 语义 |
| `TObserveGateResolver` | 观察模式装饰器 | 日志记录但不阻断，用于灰度上线 |
| `TDueChecker` | 风险尽职检查 | 基于风险等级要求不同级别的证据/确认 |
| `TRouteResolver` | 路由决策 | JsonLogic 规则引擎，支持回退 + Store 重载 |
| `TActionExecutor` | 动作执行管线 | `CanRun → DueCheck → Run → Evidence` 管线 |
| `TEventBridge` | UI 事件桥接 | 将 Delphi 原生 UI 事件转换为 `EnterGate` 请求 |
| `TProjectionResolver` | UI 属性映射 | 门控状态 → `Enabled` + `Hint` 映射 |

### AI 治理（亮点）

- **`TProposalQueue`**：AI 建议进入提案队列，人工审批后才能生效（ChangeSet 模式）
- **`TViewScopeEnforcer`**：控制 AI 可见性——Locked 门控隐藏、高敏感证据阻断、租户隔离
- **`TSteeringExporter`**：导出治理模型为 `.kiro/steering/*.md`（Markdown 表格��，供 AI 工具消费
- **`TAccountabilityChecker`**：L2+ 级别操作需要 Actor 身份，L3 级别冻结等待人工审核

### 辅助系统

- **`TJsonLogicEngine`**：完整的 JsonLogic 实现，支持 ~20 个运算符（var, equal, and/or/not, if, in, cat, substr, +-*/ 等）
- **`TEvidenceRecorder`**：异步队列写入器，线程安全（`TThreadedQueue` + 工作线程），失败队列 + 回调
- **`TComponentAdapter`**：三源合并（RTTI + DFM 解析器 + 运行时钩子）→ NativeRegistry
- **`TSealRegistry`**：封印/补救/豁免——完整性哈希、回滚/补偿/召回/冻结/解封
- **`TConfigRegistrar`**：代码优先的配置注册器（替代旧版 JSON ConfigLoader），SQLite ConfigDB 后端

### 已知问题

- `ConfigLoader`（JSON 文件，legacy）和 `ConfigRegistrar`（SQLite，新版）并存，迁移路径需要明确
- `TJsonLogicEngine` 的运算符集合虽然完整但缺少自定义运算符扩展点
- `TGovernanceLifecycle` 的初始化路径有两条（legacy 内存模式 vs ConfigDB 模式），增加了维护复杂度
- 41 个单元的测试覆盖情况不明确——`Schema.pas`（DDL）和 `ConfigRegistrar.pas`（代码优先注册）是关键路径，需确认有回归测试

### 改进建议

- P2 — 制定 `ConfigLoader` → `ConfigRegistrar` 的明确迁移时间表和兼容层
- P2 — 为 `TJsonLogicEngine` 增加自定义运算符注册 API
- P3 — 考虑为 Governance 子系统增加一个简化的 DSL（领域特定语言），降低非开发人员配置门控规则的门槛

---

## 序列化与模板引擎评估

### 序列化 (Serialization)

| 维度 | 评分 | 说明 |
|---|---|---|
| JSON 支持 | 9/10 | 完整的对象图序列化/反序列化，多态、版本容忍、自定义转换器 |
| 二进制支持 | 6/10 | 通过 `TBytesStream` 间接支持，无原生二进制格式（如 MessagePack/Protobuf） |
| 多态 | 8/10 | `TJsonKnownType` + `$type` 字段，但需要手动注册所有子类型 |
| 版本兼容 | 9/10 | `TJsonVersionTolerant` + `TDefaultValue` + 未知字段容忍 |
| 性能 | 7/10 | 缺少流式 API，大对象图会全量加载到内存 |

### 模板引擎 (Template)

| 维度 | 评分 | 说明 |
|---|---|---|
| 语法丰富度 | 9/10 | 变量、条件、循环、局部模板、过滤器、函数——功能对齐 Handlebars |
| 安全性 | 9/10 | 沙箱模型完善（黑名单 + 深度限制 + 步骤限制），但黑名单静态化 |
| 性能 | 9/10 | AST 预编译 + LRU 缓存，模板编译结果可复用 |
| 可扩展性 | 7/10 | 支持自定义函数/过滤器注册，但沙箱黑名单不可运行时配置 |

---

## 国际化评估

| 维度 | 评分 | 说明 |
|---|---|---|
| 区域码标准 | 9/10 | 完整 BCP-47 支持 |
| 复数规则 | 9/10 | CLDR 标准，50+ 语言，6 类范畴 |
| 性别形式 | 8/10 | 4 种语法性别，与复数正交 |
| 翻译工作流 | 8/10 | JSON/PO/RC 三格式，内存映射缓存，LLM 辅助翻译（CLI i18n translate） |
| 回退机制 | 8/10 | 多级回退（具体区域 → 语言 → 英语 → 默认值） |
| RTL 支持 | 7/10 | 有 `IsRightToLeft` 感知，但 FMX/VCL 的 RTL 布局适配需逐一验证 |

**亮点**：`i18n scan` 命令通过正则扫描源码自动提取翻译键，`i18n sync` 同步缺失键，`i18n translate` 调用 LLM 自动翻译——形成完整的翻译工作流闭环。

---

## 更新机制评估

### 更新流程

```
AutoUpdate (策略层)
  ├── 检查 manifest.json (版本、通道、强制要求)
  ├── 计算增量 Delta 包
  └── 委托 → Updater (执行层)
        ├── 下载 + RSA/SHA-256 签名验证
        ├── 备份当前版本 → rollback/
        ├── 应用 Delta 包
        ├── 启动 UpdaterHelper (独立进程) 做文件替换
        └── 失败 → 回滚到 rollback/
```

### 评估

| 维度 | 评分 | 说明 |
|---|---|---|
| 增量更新 | 8/10 | 文件级 diff，Delta 包减小下载量 |
| 签名验证 | 8/10 | RSA/SHA-256，但公钥硬编码 |
| 回滚 | 7/10 | 文件级备份/回滚，但非事务性（部分成功场景未覆盖） |
| 通道管理 | 8/10 | Stable/Beta/Dev 三通道隔离 |
| 安全性 | 6/10 | 缺少 TLS 证书固定，中间人攻击风险 |

### UpdaterHelper 评估

- **路径遍历防护**：`IsPathUnderRoot` 通过路径规范化 + 前缀比较，防止 `../../` 攻击
- **进程检测**：使用 `OpenProcess` + `GetModuleFileNameEx` 检测目标进程退出
- **SHA-256 校验**：替换后验证文件完整性
- **独立进程**：与主应用进程隔离，主应用退出后才能替换文件

---

## CLI/Studio 工具链评估

### CLI (Tools/CLI/) — 8 个文件

**架构**：命令行分发器 + 命令模块

| 命令模块 | 子命令 | 说明 |
|---|---|---|
| `TDBCommands` | `db init/upgrade/backup/check` | 数据库 DDL 管理，TIER0/1/2 分层 |
| `TI18nCommands` | `i18n scan/sync/translate/export/import` | 翻译工作流（含 LLM 辅助） |
| `TConfigCommands` | `config get/set/export/import` | 配置管理（JSON/INI 格式） |
| `TPipeline` | Unix 管道模型 | `grep/sort/head/tail/uniq/map/reduce/select` |
| `TInteractiveCLI` | REPL 模式 | Tab 补全、历史、多格式输出（Text/JSON/YAML/Table/CSV/Markdown） |
| `TSSHManager` | SSH 连接管理 | 框架/接口代码，无实际传输层 |

**问题**：
- `CLI.Commands` 硬编码 `ParamStr` 偏移（`I := 3`），分发器变更会导致解析错误
- `CLI.DB` 的 DDL 为字符串常量，无迁移版本文件
- SSH 模块为纯接口存根
- 多处文件头注释编码损坏（中文乱码）

### Studio (Tools/Studio/) — 20 个文件

**架构**：VCL 桌面 IDE，`TCardPanel` 单页切换，每功能一个 Frame

| Frame/Form | 功能 |
|---|---|
| `Studio.ConfigFrame` | 配置编辑器（StringGrid + 分类过滤） |
| `Studio.LogFrame` | 日志查看器（级别过滤 + CSV 导出） |
| `Studio.SQLFrame` | SQL 编辑器（DoQry 集成 + 历史 + 快捷键） |
| `Studio.QueriesFrame` | 存储查询模板编辑器 |
| `Studio.SchemaFrame` | Schema 浏览器（TreeView + DDL 查看） |
| `Studio.BackupFrame` | 备份/恢复向导（ZIP 压缩 + 进度条） |
| `Studio.ImportExportFrame` | 多格式导入导出（CSV/JSON/XML + 列映射） |
| `Studio.ThemeFrame` | 主题切换（Vcl.Styles + 实时预览） |
| `Studio.HotkeyFrame` | 快捷键编辑器（冲突检测 + 导入导出） |
| `Studio.LLMFrame` | LLM 面板（配置 + 对话 + 历史） |
| `Studio.PromptTemplateFrame` | 提示词模板管理 |
| `Studio.ProfileFrame` | 性能分析器（EXPLAIN + 索引建议） |
| `Studio.TranslationForm` | 翻译编辑器（LLM 辅助批量翻译） |
| `Studio.LicenseForm` | 许可证管理（生成 + 管理 + 验证） |

**问题**：
- `Studio.i18nInit.GetSystemLanguage` 硬编码 LANGID 映射，新区域需改代码
- `Studio.Resources` 内联中文翻译映射（非资源文件），扩展需重编译
- 多个 Form/Frame 依赖外部单元（`Studio.I18nScanner`, `DeepBase.License`, `DeepBase.LLM`）

### 其他工具

| 工具 | 文件数 | 评分 | 说明 |
|---|---|---|---|
| LogAnalyzer | 4 | 8/10 | 清晰分层（Data → Stats → Export → UI），`ILogSource` 接口可替换数据源 |
| WebService | 4 | 8/10 | 基于 Indy 的完整 HTTP 框架：路由器 + 中间件 + JWT + 速率限制 + OpenAPI + WebSocket |
| Tray | 14 | 7/10 | 功能丰富（7 个功能 Tab + 自动化脚本引擎），但 **`Tray.Types` 文件缺失导致编译失败** |
| UpdaterHelper | 1 | 7/10 | 安全感知（路径遍历防护），但实际更新逻辑未完全可见 |
| UniPublisher | 4 | 8/10 | 三目标发布（HTTP/GitHub/Gitee），清单双格式兼容 |
| SeedTool | 3 | 5/10 | **硬编码默认密码 `@2241114` — P0 安全问题** |

---

## DeepBaseRun 运行时评估

**架构**：MVP / Passive View 模式，FMX 跨平台

```
ViewMain (TfrmMain — FMX 主窗体)
  ├── FrameConfigEditor  ──►  ICtrlMain / TCtrlMain
  ├── FrameLogViewer     ──►  ICtrlMain / TCtrlMain
  ├── DeepBase.Manager (单例) — I18n, Logging, HealthCheck, FormState
  └── TDM (FireDAC SQLite 数据模块)
```

| 文件 | 职责 | 评分 |
|---|---|---|
| `CtrlMain.pas` | 控制器/Presenter — 配置和日志的数据访问 | 4/10 |
| `ViewMain.pas` | FMX 主窗体 — 5 个 Tab 页 | 6/10 |
| `FrameConfigEditor.pas` | 配置编辑 Frame | 5/10 |
| `FrameLogViewer.pas` | 日志查看 Frame | 5/10 |
| `uDM.pas` | FireDAC 数据模块 | 6/10 |

**关键问题**：

1. **配置持久化为空实现**（P1）：`SetConfigValue`（CtrlMain.pas 第 176-181 行）验证后丢弃值——`begin end` 块为空，配置从不写入任何存储。UI 显示"Configuration saved successfully"但实际无任何持久化
2. **日志文件大小硬编码为 0**（第 215 行）：`FileInfo.FileSize := 0`，从未查询实际文件大小
3. **Database 配置组为空**：`GetConfigsInGroup` 有 `Database` 组但返回零条目
4. **FrameLogViewer 重复过滤逻辑**（第 73-98 行）：`ApplyFilterButtonClick` 内联重新实现了 `ICtrlMain.FilterLogLines` 的算法，绕过控制器的已测试版本
5. **Frame 未实际嵌入**：`FrameConfigEditor` 和 `FrameLogViewer` 已实现但 `ViewMain` 使用内联控件而非嵌入这些 Frame——Frame 成为孤儿代码
6. **`.fmx` / `.dfm` 资源文件缺失**：`uDM.pas` 引用 `{$R *.dfm}`，Frame 引用 `{$R *.fmx}`，但目录中无可视资源文件

---

## 优先级排序的改进建议（Top 5）

### P0 — 安全/构建阻断（立即修复）

1. **SeedTool 硬编码默认密码**
   - 文件：`Tools/SeedTool/uBasicProtection.pas`
   - 问题：`EncryptSensitiveData`, `DecryptSensitiveData` 等 6 个方法的默认参数 `const APassword: string = '@2241114'`
   - 影响：任何遗漏密码参数的调用者都会使用同一个静态密码，加密形同虚设
   - 修复：移除默认参数值，强制所有调用者提供密码；或改为从 KeyManager 获取

2. **Tray.Types 文件缺失**
   - 文件：`Tools/Tray/Automation/Tray.KeyboardMouse.pas` (第 21 行)、`Tools/Tray/Automation/Tray.Automation.pas` (第 30 行) 引用 `Tray.Types`
   - 影响：编译失败
   - 修复：创建 `Tray.Types.pas` 定义 `TAutomationAction` 等共享类型

### P1 — 功能缺陷（本迭代修复）

3. **DeepBaseRun 配置持久化空实现**
   - 文件：`DeepBaseRun/CtrlMain.pas` 第 176-181 行
   - 问题：`SetConfigValue` 验证后不写入任何存储
   - 影响：用户修改配置后关闭应用，所有更改丢失
   - 修复：实现基于 `config.db`（SQLite）或 `DeepBase.Config` 的持久化

4. **AutoUpdate 缺少 TLS 证书固定**
   - 文件：`Features/DeepBase.AutoUpdate.pas`
   - 问题：更新检查的 HTTP 客户端未固定服务器证书
   - 影响：中间人攻击可推送恶意更新包
   - 修复：在 HTTP 客户端中配置证书固定（至少固定主 CA）

### P2 — 技术债（下迭代规划）

5. **CryptoAPI (CSP) 弃用迁移**
   - 涉及文件：`Tools/SeedTool/uBasicProtection.pas`、`Features/DeepBase.AutoUpdate.pas` 等多处
   - 问题：直接 p/invoke `advapi32.dll` 的 `CryptAcquireContext` / `CryptEncrypt` 等已弃用 API
   - 影响：未来 Windows 版本可能移除 CSP 支持
   - 修复：迁移到 CNG（`BCrypt*` 函数）——Core 层已有 `BCryptDecrypt.pas` 后端，工具层应统一使用

---

## 附录：模块评分总览

| 模块 | 大小 | 评分 | 关键风险 |
|---|---|---|---|
| Manager | 46.8K | 8/10 | Initialize 方法过长 |
| Manager.Schema | 17.1K | 8/10 | 无回滚迁移 |
| Manager.Operational | 7.3K | 7/10 | 模式硬编码 |
| PluginManager | 25.8K | 9/10 | 无进程外沙箱 |
| Serialization | 61.2K | 8/10 | TBytesStream ownership 混乱 |
| Template | 67.2K | 9/10 | 沙箱黑名单静态化 |
| ObjectPool | 32.7K | 10/10 | 无（工程亮点） |
| KeyManager | 26.8K | 9/10 | DPAPI 绑定用户账户 |
| i18n (3 units) | 63.7K | 8/10 | 动态键遗漏 |
| AutoUpdate | 23.7K | 8/10 | 缺少证书固定 |
| Updater | 66.3K | 8/10 | 公钥硬编码 |
| CloudBackup | 72.9K | 8/10 | S3 凭证存储待确认 |
| CloudSync | 66.7K | 8/10 | 缺少向量时钟 |
| ClipboardGuard | 8.5K | 7/10 | Win11 云同步绕过 |
| Desktop.Lifecycle | 9.9K | 7/10 | 无 |
| Unlock | 16.1K | 7/10 | 受 SeedTool 安全影响 |
| WindowMonitor | 11.6K | 7/10 | 反调试可被绕过 |
| DataPlatform.Bootstrap | 2.6K | 6/10 | 无降级策略 |
| Governance (41 units) | ~400K | 9.5/10 | 新旧配置路径并存 |
| CLI (8 files) | ~120K | 7/10 | SSH 存根、编码损坏 |
| Studio (20 files) | ~250K | 8/10 | 内联 i18n、外部依赖多 |
| LogAnalyzer | ~40K | 8/10 | 自定义异常类缺失 |
| WebService | ~80K | 8/10 | FPC 兼容性维护成本 |
| Tray (14 files) | ~150K | 7/10 | **Tray.Types 缺失** |
| UpdaterHelper | ~15K | 7/10 | 更新逻辑未完全可见 |
| UniPublisher | ~50K | 8/10 | Gitee token 明文 |
| SeedTool | ~30K | 5/10 | **硬编码密码** |
| DeepBaseRun | ~34K | 5/10 | **配置持久化空实现** |
