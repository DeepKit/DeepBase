# 核心基础设施模块评估报告

> **评估日期**: 2026-06-15
> **评估范围**: `Core/` 目录下 14 个基础设施模块（不含安全/加密）
> **评估视角**: 20 年 Delphi/Object Pascal 核心基础设施专家

---

## 评估摘要

**总评分: 7.0 / 10**

一句话结论：框架骨架完整，覆盖面广，泛型集合、事件总线、缓存、配置等关键模块均已就位，但**线程安全一致性差、异常体系在 Core 内部未统一使用、关键并发原语存在死锁/竞态隐患**，属于"功能丰富但需要系统性加固"的阶段。

---

## 各子模块评估

### DeepBase.Collections

- **职责**: 提供 10 种泛型容器（SortedList、CircularBuffer、LRUCache、BidiDictionary、MultiMap、OrderedDictionary、Deque、CountingSet、MinMaxStack、BlockingQueue）及一个通用 Interval record，附静态工厂 TCollections。

- **代码质量**:
  - 命名规范良好：T*/I*/F*/A* 前缀一致，XML `<summary>` 覆盖所有公开类型。
  - 缺少 `<param>`、`<returns>`、`<exception>` 标签；无算法复杂度说明。
  - 工厂方法 TCollections 命名缩写不一致：`BidiDict` vs `OrderedDict`（应统一缩写或全拼）。

- **线程安全性**:
  - **严重问题**: `TSortedList`（行 29）完全没有锁，但所有其他有状态容器都有 TCriticalSection，形成"隐式线程安全"的陷阱。
  - `TLRUCache`（行 706）的 `OnEvict` 回调在持有锁时调用，若回调再触达缓存，产生**重入死锁**。
  - `TBlockingQueue.TryDequeue`（行 1976）：`FNotEmpty.WaitFor` 在锁外执行，WaitFor 返回与加锁之间存在**竞态窗口**；`ATimeoutMs=0` 实际是非阻塞轮询，行为与直觉不符。

- **API 设计**:
  - `TryXxx` 系列存在，符合 Delphi 惯例。
  - `TLRUCache` 用 `Put/Get` 而非 `Add/Remove`，与本单元其他字典类不一致。
  - `TMultiMap.GetValues`（行 1125）对缺失 key 返回 `nil`，与"key 存在但值为空列表"无法区分。
  - `TCollections` 工厂类无实际价值（未注册替代实现），且缺少 `TMinMaxStack`/`TInterval` 工厂方法。

- **已知问题/风险**:
  1. [Critical] `TBlockingQueue.TryDequeue` 竞态窗口 (行 1976-1993)
  2. [High] `TLRUCache.OnEvict` 持锁回调 → 重入死锁 (行 706)
  3. [High] `TSortedList` 无锁 (行 29)
  4. [Medium] `TCountingSet.MostCommon` 用 `B.Value - A.Value` 排序存在整数溢出风险 (行 1734)
  5. [Medium] `TSortedList.GetRange` 无边界检查 (行 496)
  6. [Low] `ECollectionException` 是单一扁平类，无法区分"key not found" vs "queue full"

- **改进建议**:
  1. 给 `TSortedList` 添加可选 TCriticalSection 或在文档中标明 "NOT thread-safe"。
  2. 将 `OnEvict` 回调移到锁外：先在锁内收集待驱逐条目，释放锁后再调用回调。
  3. 引入异常层次：`EKeyNotFound`、`EDuplicateKey`、`EQueueFull`、`EContainerEmpty`、`EIndexOutOfBounds`。
  4. `TMultiMap.GetValues` 改为在 key 不存在时抛出 `EKeyNotFound`，或重命名为 `TryGetValues`。

---

### DeepBase.Cache

- **职责**: 通用泛型缓存，支持 LRU/LFU/FIFO/TTL 多种驱逐策略，带统计、事件回调、批量操作。附 `TMemoryCache` 全局单例。

- **代码质量**:
  - 结构清晰，分区注释齐全，XML 注释覆盖公开 API。
  - 中文注释与英文注释混用（如行 337 "BUG-047 FIX" 注释为乱码），建议统一为英文。
  - `FreeValueIfOwned`（行 766）使用 `GetTypeKind(V) = tkClass` + `PPointer(@Value)^` 在泛型上下文中安全地释放对象，但此技巧缺乏注释说明。

- **线程安全性**:
  - 全面使用 `FLock: TCriticalSection` + `try/finally`，模式统一正确。
  - `DoEvict`/`DoExpire`（行 754, 760）回调在锁内调用 → 与 `TBlockingQueue` 相同的**重入死锁风险**。
  - `EvictLFU`（行 646）为 O(n) 全表扫描找最小访问次数，大缓存下性能堪忧。

- **API 设计**:
  - `Put/Get/TryGet/GetOrLoad/Contains/Remove/Clear/Cleanup` 覆盖完整。
  - `GetMany`（行 781）内部对每个 key 调用 `TryGet`（每次加锁/解锁），批量操作应**一次性持有锁**。
  - `PutMany`（行 792）同理，每个 item 独立加锁，非原子。
  - `MaxItems`/`MaxSizeBytes`/`EvictionPolicy` 为可写属性，运行期修改不触发重新平衡，可能导致缓存超限。

- **已知问题/风险**:
  1. [High] `DoEvict/DoExpire` 回调在锁内调用 → 重入死锁
  2. [Medium] `GetMany/PutMany` 非原子，逐项加锁 → 性能差 + 不一致
  3. [Medium] `EvictLFU` O(n) 扫描，大缓存性能瓶颈
  4. [Low] `TMemoryCache` 单例无 `FreeInstance` 机制，进程退出时可能触发 AV

- **改进建议**:
  1. 将回调移到锁外（同 Collections 建议）。
  2. `GetMany/PutMany` 应在内部一次性加锁。
  3. 为 `EvictLFU` 考虑用 `TSortedDictionary<Int64, TList<K>>` 做频次桶，降为 O(log n)。

---

### DeepBase.DateTime

- **职责**: 全面的日期/时间工具集，包含扩展 TimeSpan、日期区间、时区处理、格式化（ISO 8601/RFC 2822/Unix 时间戳）、相对时间描述、日期算术、工作日计算、通用辅助类。

- **代码质量**:
  - 结构组织良好，按职责拆分为 `TTimeSpanEx`、`TDateRange`、`TTimeZones`、`TDateTimeFormat`、`TRelativeTime`、`TDateTimeCalc`、`TBusinessDays`、`TDateTimeUtils`。
  - `TDT = TDateTimeUtils` 别名简洁实用。
  - 注释覆盖充分，XML `<summary>` 完整。

- **线程安全性**:
  - `TTimeZones.FCache`（行 108）是 class var TDictionary，`InitCache`（行 570）体为空 → 缓存未实际初始化，若多线程访问 `FCache` 会 AV。
  - `TBusinessDays.FHolidays`（行 244）是 class var TList，`AddHoliday`/`ClearHolidays` 无锁 → 多线程不安全。
  - 所有 `TDateTimeUtils`/`TDateTimeCalc`/`TRelativeTime` 方法为无状态静态方法，隐式线程安全。

- **API 设计**:
  - 运算符重载（`TTimeSpanEx` 的 `+`、`-`、`=`、`<>`、`>`、`<`）使用自然。
  - `TDateRange.Today/ThisWeek/ThisMonth/ThisYear/LastNDays` 工厂方法实用。
  - `TTimeZones` 只暴露 `Local` 和 `UTC`，不支持任意时区转换 → 功能不完整。
  - `TDateTimeUtils.Create` 与 `System.SysUtils` 命名空间冲突风险（通过 `TDateTimeUtils.Create(AYear, AMonth, ADay)` 调用可避免，但新用户可能困惑）。

- **已知问题/风险**:
  1. [Medium] `TTimeZones.InitCache` 为空实现 (行 570)，`FCache` 始终为空字典
  2. [Medium] `TBusinessDays.FHolidays` 无并发保护
  3. [Low] `TTimeSpanEx.FromSeconds`（行 362）`AValue * 1000` 在 AValue 接近 `High(Int64)` 时溢出
  4. [Low] 时区功能仅 Local/UTC 双向，不支持 IANA 时区

- **改进建议**:
  1. 实现 `TTimeZones.InitCache` 或移除空方法，避免误导。
  2. 为 `TBusinessDays` 的 class var 添加 TCriticalSection。
  3. 在 `FromSeconds/FromMinutes/FromHours` 中添加溢出检查。

---

### DeepBase.Configuration

- **职责**: 完整的配置管理系统，支持多源（Memory/Environment/INI/JSON/CommandLine/Encrypted）、分层覆盖、热重载、Section 访问、类型安全绑定、Builder 模式。

- **代码质量**:
  - 架构设计成熟：IConfigurationSource 接口 + Builder + 多 Source 实现 + Section + TypedConfiguration。
  - 接口 GUID 硬编码（行 51 `'{A1B2C3D4-...}'`），在生产环境中若多个版本共存可能冲突。
  - `TConfiguration.FWatchThread`（行 233）暗示文件监控功能，但线程管理细节需确认。

- **线程安全性**:
  - `FLock: TCriticalSection`（行 228）+ `FCallbacksLock: TCriticalSection`（行 235）双锁设计。
  - 双锁场景下需注意加锁顺序一致性以避免死锁。

- **API 设计**:
  - Builder 模式 `TConfigurationBuilder` 流畅：`AddMemory().AddEnvironmentVariables().AddJsonFile().Build()`。
  - `TConfig` 静态类提供 `Get/GetInt/GetBool/GetFloat` 快捷访问。
  - `TTypedConfiguration<T>` 支持强类型绑定。
  - `TEncryptedConfigurationSource` 与 DeepBase.Security 的依赖关系清晰。

- **已知问题/风险**:
  1. [Medium] 接口 GUID 硬编码，版本演进时可能冲突
  2. [Medium] 文件监控线程（FWatchThread）的生命周期管理需验证
  3. [Low] `TConfig.Default` 单例无延迟初始化保护

- **改进建议**:
  1. 将接口 GUID 改为编译期生成的常量或文档化。
  2. 确保 `StartWatching/StopWatching` 的线程安全启停。

---

### DeepBase.Config

- **职责**: 轻量级配置管理器，面向数据库存储（通过 `IConfigStorage` 接口），带内存缓存、类型安全读写、全局便捷函数。与 `DeepBase.Configuration` 形成**双层配置架构**。

- **代码质量**:
  - 文件头注释清晰（版本号 0.3、线程安全声明）。
  - 命名遵循 Delphi 规范，T*/F* 前缀一致。
  - 注释 "R-002" 引用内部需求编号，说明有良好的需求追溯。

- **线程安全性**:
  - `FLock: TObject` 使用 `TMonitor` 风格的 `TObject.Create` 作为锁对象（行 169）。
  - `FOwnsLock` 标志区分外部注入 vs 自建锁，正确。
  - 声明 "所有公开方法线程安全"，与实现一致。

- **API 设计**:
  - 模块级便捷函数 `GetConfig/GetConfigInt/GetConfigBool/GetConfigFloat/ConfigExists/DeleteConfig` 极为实用，避免了 `DeepBase().Config.GetConfig(...)` 的冗长调用。
  - 类型化 `SetConfig*` 方法接收 `Category` 参数，支持分类管理。
  - `FConnectionStorageFactory` 类方法支持 DI 注入。

- **已知问题/风险**:
  1. [Medium] `DeepBase.Config` 与 `DeepBase.Configuration` 职责边界模糊，新人易混淆
  2. [Low] `FConnection: TObject` 弱类型，无编译期类型检查

- **改进建议**:
  1. 在模块注释中明确说明两者的职责划分（Configuration = 通用/文件/多源；Config = 数据库存储/运行时）。

---

### DeepBase.EventBus

- **职责**: 类型安全的发布-订阅事件总线，支持同步/异步/主线程分发、优先级、过滤、弱引用订阅、事件历史与重放、死信处理、统计。

- **代码质量**:
  - 功能极为丰富：`Subscribe/SubscribeWeak/SubscribeByType`、`Publish/PublishAsync/PublishByType`、`ReplayHistory`、`WaitForAsyncHandlers`。
  - `TWeakSubscriptionLink` 通过 `TComponent` 所有权实现弱引用，设计巧妙。
  - `FLiveSubscriptions`（BASIC-023）修复了 EventBus 销毁后外部 ISubscription 悬挂指针问题，体现了良好的 bug 修复追溯。
  - 注释 "R-007" 关于所有权转移的说明清晰。

- **线程安全性**:
  - `FLock: TCriticalSection` 统一保护所有订阅/取消订阅/发布操作。
  - 全局 `EventBus` 函数使用 `TInterlocked.CompareExchange`（行 371）实现无锁单例创建，正确。
  - `SetEventBus`（行 377）使用 `GEventBusLock` 保护所有权转移，正确。
  - `FAsyncDrained: TEvent`（手动重置事件）用于异步处理器排空等待。
  - **潜在问题**: `Publish<T>` 内部 `InvokeHandler` 若使用 `edmSync` 模式，handler 在持有 `FLock` 的情况下执行 → 如果 handler 内部再次调用 `Publish/Subscribe`，产生**重入死锁**。需确认是否有锁降级或快照机制。

- **API 设计**:
  - 泛型 API `Subscribe<T>/Publish<T>` 类型安全，使用 RTTI 自动获取类型名。
  - `ISubscription` 接口支持显式 Unsubscribe 和状态查询。
  - `IsValidEventType` 白名单机制（行 682）限制了 `SubscribeByType` 的事件类型 → 安全性好但灵活性差，新事件类型需修改白名单。

- **已知问题/风险**:
  1. [High] `Publish` 同步分发时若 handler 在锁内执行，可能重入死锁（需确认实现）
  2. [Medium] `ALLOWED_EVENT_TYPES` 硬编码白名单（行 682-684），扩展性差
  3. [Medium] `GetEventTypeName<T>` 使用 `PTypeInfo(TypeInfo(T))^.Name`，匿名 record 类型名可能为空
  4. [Low] 事件历史 `FEventHistory` 无锁保护读取（`ReplayHistory` 应加锁）

- **改进建议**:
  1. 确认 `Publish` 在分发前是否做了订阅者列表快照 + 释放锁后再调用 handler。
  2. 将白名单改为可配置（`RegisterEventType`/`UnregisterEventType`）。
  3. 为 `ReplayHistory` 添加锁保护。

---

### DeepBase.Diff

- **职责**: 文本差异比较与补丁系统，包含 LCS 算法、逐行/逐字符比较、Unified/Context/Side-by-Side/HTML 输出、Patch 解析与应用、三方合并、相似度计算、二进制检测。

- **代码质量**:
  - 功能完整度极高，涵盖 Git-like diff 核心功能。
  - `TDiffOptions` record 提供 `Default` 工厂方法。
  - `TDiffItem`/`TDiffHunk`/`TDiffResult`/`TPatch`/`TMergeResult` 类型层次清晰。

- **线程安全性**:
  - 无状态或基于局部变量的算法实现，隐式线程安全。
  - `TDiff.FDefaultDiff`（行 239）是 class var 实例，若内部有状态则可能竞争 → 但从 API 看是只读共享。

- **API 设计**:
  - `TTextDiff` 实例 API + `TDiff` 静态快捷 API 双轨设计，灵活。
  - `CompareFiles/CompareLines/CompareChars/CompareWords/Merge3Way` 覆盖全。
  - `ToUnifiedDiff/ToContextDiff/ToSideBySide/ToHTML` 多格式输出。
  - `TPatch.Apply/ApplyWithFuzz/Reverse/CanApply` 补丁操作完整。

- **已知问题/风险**:
  1. [Medium] LCS 算法对大文件 O(n*m) 空间复杂度可能内存不足（`ComputeLCS` 返回 `TArray<TArray<Integer>>`）
  2. [Low] `TDiff.FDefaultDiff` 生命周期由 class destructor 管理，进程退出时顺序敏感
  3. [Low] 无流式 diff 支持（大文件需全部加载到内存）

- **改进建议**:
  1. 为超大文件添加基于行的流式 LCS（Myers diff 算法 O(n+d) 空间）。
  2. 添加 `CompareStreams` 方法避免全量加载。

---

### DeepBase.Compression

- **职责**: 压缩工具集，支持 GZip/Deflate/ZLib 流压缩、ZIP 归档读写、进度回调、文件/流/字节/字符串多种操作形态。

- **代码质量**:
  - 封装了 `System.ZLib` 和 `System.Zip`，提供了更友好的高层 API。
  - `TZipArchiveReader/TZipArchiveWriter` 读写分离设计合理。
  - `TCompressionProgress` 回调支持取消（`var ACancel: Boolean`）。

- **线程安全性**:
  - 无明显并发保护 → 实例级使用需外部同步。
  - 作为工具类，通常单线程使用，可接受。

- **API 设计**:
  - `TGZipCompressor/TDeflateCompressor` 按格式分离，避免参数混乱。
  - `CompressBytes/DecompressBytes/CompressString/DecompressString/CompressFile/DecompressFile` 覆盖全。
  - `TZipArchiveWriter.Close` 显式调用 → 若忘记调用，析构函数应自动关闭（需确认）。

- **已知问题/风险**:
  1. [Low] 依赖 `System.Zip`（Delphi RTL），跨平台兼容性取决于 RTL 实现
  2. [Low] 无 BZip2/LZ4/Zstd 等现代算法支持

- **改进建议**:
  1. 确认 `TZipArchiveWriter.Destroy` 自动调用 `Close`。
  2. 考虑添加 `TCompressionFormat.AutoDetect` 根据魔数自动识别格式。

---

### DeepBase.Benchmark

- **职责**: 轻量级性能基准测试框架，包含高精度计时（QPC）、内存快照（Process/Heap）、统计分析（min/max/avg/stddev/P90/P95/P99）、多格式报告（Text/JSON/CSV/Markdown/HTML）、对比功能。

- **代码质量**:
  - 设计专业：`THiResStopwatch` → `TBenchmarkStats` → `TBenchmarkResult` → `TBenchmarkReport` 层次分明。
  - 使用 `Winapi.PsAPI` 获取内存信息，Windows 特定。
  - `TBenchmarkStats.Calculate` 支持完整统计量计算。

- **线程安全性**:
  - 作为基准测试工具，通常单线程使用，无并发保护，可接受。
  - `THiResStopwatch.FFrequencyInitialized` class var 无锁初始化 → 多线程首次调用可能竞争（但 QPC frequency 是系统常量，实际无害）。

- **API 设计**:
  - `TBenchmark` 支持 `WarmupIterations/Iterations/TrackMemory/Setup/Teardown`。
  - `TBenchmarkReport` 支持多格式输出和文件/流保存。
  - `CollectEnvironmentInfo` 自动收集环境信息。

- **已知问题/风险**:
  1. [Low] Windows 特定（`Winapi.Windows/Winapi.PsAPI`），非 Windows 平台需条件编译
  2. [Low] 无统计显著性检验（如置信区间）

- **改进建议**:
  1. 为非 Windows 平台提供 `{$IFDEF MSWINDOWS}` 降级实现。
  2. 考虑添加 Welch's t-test 或 Mann-Whitney U 检验用于对比。

---

### DeepBase.Exceptions

- **职责**: 统一的异常类层次结构，覆盖安全/加密、数据库、配置、备份、网络、弹性/容错、初始化、操作、文件、外部数据库、SchemaAdapter、UIA、剪贴板/窗口监控等域。

- **代码质量**:
  - 层次设计专业：`EDeepBaseException` → 各域基类 → 具体异常，3 层结构。
  - `EDeepBaseException` 携带 `ErrorCode`、`Context`、`Timestamp` 元数据，比标准 Exception 信息更丰富。
  - `CreateFmt` 重载方便格式化消息。
  - `ToString` 输出包含类名、消息、错误码、上下文，调试友好。
  - 辅助函数 `GetLastErrorMessage/RaiseLastOSError` 封装 Windows 错误。
  - 注释使用中文，与项目整体风格一致。

- **线程安全性**:
  - 纯类型声明 + 无状态构造函数，隐式线程安全。

- **API 设计**:
  - 按域分组，每组有基类（`ESecurityException`、`EDatabaseException`、`EConfigException` 等），方便 `except on E: EDatabaseException do` 捕获。
  - 具体异常如 `EConnectionTimeoutException`、`EPoolNotInitializedException` 粒度合适。
  - 外部数据库异常（`EExternalDBError`/`EExternalDBBusy`/`EWriteAttemptBlocked`）体现了 SQLite 并发场景。

- **已知问题/风险**:
  1. [High] `Core/` 内其他模块（Collections、Cache、DateTime、Configuration、Diff、Compression）均未使用 `EDeepBaseException` 层次，而是各自定义扁平异常（`ECollectionException`、`ECacheException`、`EDateTimeException` 等直接继承 `Exception`）→ 异常体系割裂。
  2. [Medium] `EFileNotFoundExceptionEx`（行 270）命名带 `Ex` 后缀，与 `System.SysUtils.EFOpenError` 等 RTL 异常不一致。
  3. [Low] 无 `EValidationException`、`EArgumentException`（使用 RTL 的）等通用异常。

- **改进建议**:
  1. **最关键改进**: 让 Collections/Cache/DateTime/Configuration/Diff/Compression 的异常类继承自 `EDeepBaseException`，形成统一层次。
  2. 在 `EDeepBaseException` 中添加 `InnerException` 支持（Delphi 12+ 原生支持，旧版需手动）。

---

### DeepBase.Exception (单数)

- **职责**: 异常报告处理器，拦截应用全局异常、记录到日志/数据库、调用平台 UI 显示。与 `DeepBase.Exceptions`（复数，异常类型声明）是不同模块。

- **代码质量**:
  - 通过 `TFunc<>` 回调解耦对 `DeepBase.Manager`/`DeepBase.Logging` 的依赖，架构干净。
  - `SetPlatformAdapter` 允许 UI 层注册异常展示适配器。
  - `SetStorageFactory` 支持 DI 注入异常报告存储。
  - `LogExceptionToDB` 外层 `try/except` 避免递归异常报告（行 174）→ 防御性编程良好。

- **线程安全性**:
  - 类方法（class methods）操作 class var，无锁保护。
  - `FInstance` 在 class constructor 中创建，class destructor 中释放 → 生命周期安全。
  - `HandleException` 可能被任何线程调用，但内部操作（日志写入、DB 写入）的线程安全依赖下游实现。

- **API 设计**:
  - `Install/HandleException/SetStorageFactory/SetPlatformAdapter/SetManagerCallbacks` 接口清晰。
  - `BuildExceptionReportData` 使用 `{$IF CompilerVersion >= 33.0}` 条件编译支持 `E.StackTrace`。

- **已知问题/风险**:
  1. [Medium] 命名 `DeepBase.Exception`（单数）与 `DeepBase.Exceptions`（复数）极易混淆。
  2. [Low] `HandleException` 中 `FGetLoggerProc` 返回 `TDeepBaseLogger`，若 Logger 已被释放则 AV。

- **改进建议**:
  1. 考虑重命名为 `DeepBase.ExceptionHandler` 或 `DeepBase.ExceptionReporting`。

---

### DeepBase.Constants

- **职责**: 全局数值常量集中定义（缓存、超时、线程池、重试、日志、网络、安全、性能、监控）。

- **代码质量**:
  - 分组清晰，注释含中文说明单位（秒/毫秒/MB/KB）。
  - 常量命名使用全大写 + 下划线，与 Delphi 惯例（resourcestring 用 S 前缀）不同，但作为数值常量可接受。

- **线程安全性**: 编译期常量，隐式线程安全。

- **已知问题/风险**:
  1. [Low] 缺少 `DEFAULT_` 前缀分组（如 `DEFAULT_CACHE_*` vs `DEFAULT_HTTP_*`），按域分组更好。
  2. [Low] 无 `const` typed constant（如 `DEFAULT_CACHE_MAX_ITEMS: Integer = 1000`），若需运行期覆盖则无法实现。

- **改进建议**:
  1. 按域拆分为多个 const section 或拆分为子单元（如 `DeepBase.Constants.Cache`）。

---

### DeepBase.Consts

- **职责**: 框架级字符串常量集中定义（版本号、配置键、配置类别、默认值、MRU 类别、表名、日志级别）。

- **代码质量**:
  - 命名规范 `S*` 前缀（Delphi 字符串常量惯例）。
  - 分组清晰，XML `<summary>` 注释完整。
  - 版本号 `DeepBase_VERSION_*` 放在此处而非 `.res` 文件，方便代码访问。

- **线程安全性**: 编译期常量，隐式线程安全。

- **已知问题/风险**:
  1. [Low] `DeepBase_VERSION_*` 命名使用 `DeepBase_` 前缀而非 `S` 前缀，与同单元其他常量不一致。
  2. [Low] `DeepBase.Constants` 与 `DeepBase.Consts` 两个单元职责重叠（一个数值常量、一个字符串常量），新人难以区分。

- **改进建议**:
  1. 考虑合并为 `DeepBase.Constants`，内部分为数值和字符串两组。

---

### DeepBase.AppLifecycle

- **职责**: 应用程序生命周期管理，包含单实例互斥锁（Named Mutex）、启动/正常关闭状态跟踪、崩溃计数、优雅关闭信号（TEvent + ConsoleCtrlHandler）。

- **代码质量**:
  - 功能实用：`AcquireSingleton/ReleaseSingleton`、`MarkStarted/MarkCleanShutdown`、`CrashCount`、`RequestShutdown/WaitForShutdownSignal`。
  - 状态持久化到文件（`.lifecycle`），进程重启后可检测上次是否崩溃。
  - `SanitizeName` 防止非法字符进入 Mutex 名。

- **线程安全性**:
  - `FLock: TCriticalSection` 保护所有 class var 状态。
  - `ConsoleCtrlHandler` 是 stdcall 回调，在独立线程中被系统调用 → 通过 `FShutdownRequested` Boolean 标志通信，无锁但使用 volatile 语义。

- **API 设计**:
  - `Configure/Reset` 控制生命周期配置。
  - `AcquireSingleton` 支持 Global/Local 命名空间选择。
  - `WaitForShutdownSignal` 接收 `TProc` 回调，支持优雅关闭。

- **已知问题/风险**:
  1. [Medium] `FShutdownRequested: Boolean` 无 `volatile` 或 `TInterlocked` 保护 → 在弱内存序架构（ARM）上可能可见性问题（x86/x64 上实际安全）。
  2. [Low] 状态文件路径硬编码 `%LOCALAPPDATA%\DeepBase\Lifecycle\`，不可配置。

- **改进建议**:
  1. 使用 `TInterlocked.Exchange` 读写 `FShutdownRequested`。
  2. 状态文件路径应可通过 `Configure` 覆盖（已支持 `StateDir` 参数，此条已满足）。

---

### DeepBase.Diagnose

- **职责**: 数据库 Schema 诊断工具，检查表/列/索引存在性、Schema 版本、数据完整性，支持自动修复、诊断报告生成。

- **代码质量**:
  - `IDiagnoseStorage` 接口解耦 FireDAC 依赖（ARCH-039），架构演进良好。
  - 每个诊断函数提供 `*WithStorage` 变体，支持 DI。
  - `TIER0_TABLES/TIER1_TABLES/TIER2_TABLES` 分层定义期望的表结构。

- **线程安全性**:
  - 诊断操作通常是单线程的管理操作，无并发保护。
  - `GConnectionStorageFactory` 全局变量无锁 → 初始化时需确保单线程。

- **API 设计**:
  - 函数式 API（非类方法），简洁直接。
  - `DiagnoseAll/CheckTablesExist/CheckColumnsExist/CheckIndexesExist/CheckSchemaVersion/CheckDataIntegrity/AutoFix` 覆盖全。
  - `GenerateDiagnoseReport/GenerateDiagnoseSummary` 报告生成。

- **已知问题/风险**:
  1. [Medium] `TIER*_TABLES` 硬编码在 Core 中，Schema 变更需修改 Core 代码 → 应考虑注册式。
  2. [Low] `AConnection: TObject` 弱类型，运行时可能传入错误对象。

- **改进建议**:
  1. 将 `TIER*_TABLES` 移到可注册/可扩展的配置中。
  2. 考虑将 `AConnection` 改为泛型参数或接口。

---

## 整体架构观察

### 模块间耦合度

- **低耦合亮点**:
  - `DeepBase.Exception` 通过 `TFunc<>` 回调解耦对 Manager/Logging 的依赖。
  - `DeepBase.Diagnose` 通过 `IDiagnoseStorage` 解耦 FireDAC。
  - `DeepBase.Config` 通过 `IConfigStorage` 解耦存储后端。
  - `DeepBase.Configuration` 通过 `IConfigurationSource` 解耦配置源。

- **高耦合问题**:
  - `DeepBase.Cache` 直接依赖 `DeepBase.Constants`（获取默认缓存配置），但 Constants 是纯数值常量，可接受。
  - `DeepBase.Config` 直接依赖 `DeepBase.Security`（行 147 `uses DeepBase.Security`），Core 对 Security 有向上依赖 → 违反分层原则。

### 公共 API 一致性

| 维度 | 一致性 | 说明 |
|------|--------|------|
| 命名前缀 | 高 | T*/I*/F*/A* 全局一致 |
| TryXxx 模式 | 高 | 所有模块统一使用 |
| 锁模式 | 高 | TCriticalSection + try/finally 统一 |
| 异常类 | **低** | 各模块自定义独立异常类，未继承 `EDeepBaseException` |
| XML 文档 | 中 | `<summary>` 覆盖，但缺 `<param>/<returns>/<exception>` |
| 工厂模式 | 中 | 部分模块有（TCollections、TConfig.Builder），部分无 |

### 缺失或薄弱环节

1. **统一异常层次未落地**: `EDeepBaseException` 设计良好但 Core 内部模块不使用，形同虚设。
2. **线程安全文档缺失**: 哪些类线程安全、哪些不是，没有文档标注。
3. **无 CancellationToken 模式**: 长时间操作（Compression、Diff）的取消机制不统一。
4. **无统一的 Result<T> 模式**: 错误处理混用异常和 Boolean 返回值。
5. **常量双单元**: `Constants` 和 `Consts` 职责边界模糊。

---

## 优先级排序的改进建议 (Top 5)

### P0 - 阻塞性并发缺陷

1. **修复 `TBlockingQueue.TryDequeue` 竞态窗口** (`Collections` 行 1976-1993)
   - `WaitFor` 在锁外执行，存在信号丢失风险。应在锁内等待，或使用条件变量模式。

2. **修复所有 OnEvict/OnExpire/On* 回调的持锁调用问题** (`Collections` LRU、`Cache`)
   - 在锁内调用用户回调是重入死锁的根源。应改为：锁内收集待通知条目 → 释放锁 → 调用回调。

### P1 - 架构统一

3. **让 Core 内所有模块的异常类继承 `EDeepBaseException`**
   - 当前 `ECollectionException`、`ECacheException`、`EDateTimeException`、`EConfigurationException`、`EDiffException`、`ECompressionException` 均直接继承 `Exception`。
   - 应改为 `ECollectionException = class(EDeepBaseException)` 等，使 `except on E: EDeepBaseException do` 能统一捕获。

### P2 - 线程安全补全

4. **为 `TSortedList` 添加线程安全选项或文档标注** (`Collections`)
   - 所有其他容器都有锁，唯独 `TSortedList` 没有，形成隐式陷阱。至少添加 `// NOT thread-safe` 注释，或添加 `TThreadSafeSortedList<T>` 变体。

5. **为 `TBusinessDays.FHolidays` 和 `TTimeZones.FCache` 添加并发保护** (`DateTime`)
   - class var 可变集合在多线程环境下需要 TCriticalSection 保护。

---

## 附录：评估矩阵

| 模块 | 功能完整度 | 代码质量 | 线程安全 | API 设计 | 文档 | 综合 |
|------|-----------|---------|---------|---------|------|------|
| Collections | 9 | 8 | 5 | 7 | 6 | 7.0 |
| Cache | 9 | 8 | 7 | 8 | 7 | 7.8 |
| DateTime | 9 | 8 | 6 | 8 | 7 | 7.6 |
| Configuration | 9 | 9 | 7 | 9 | 7 | 8.2 |
| Config | 8 | 8 | 8 | 8 | 7 | 7.8 |
| EventBus | 9 | 9 | 7 | 9 | 7 | 8.2 |
| Diff | 9 | 8 | 8 | 8 | 7 | 8.0 |
| Compression | 8 | 8 | 6 | 8 | 7 | 7.4 |
| Benchmark | 8 | 8 | 7 | 8 | 7 | 7.6 |
| Exceptions | 9 | 9 | 10 | 9 | 8 | 9.0 |
| Exception | 7 | 8 | 7 | 8 | 7 | 7.4 |
| Constants | 7 | 7 | 10 | 6 | 6 | 7.2 |
| Consts | 7 | 8 | 10 | 7 | 7 | 7.8 |
| AppLifecycle | 8 | 8 | 8 | 8 | 6 | 7.6 |
| Diagnose | 8 | 8 | 7 | 7 | 7 | 7.4 |
| **加权平均** | **8.4** | **8.2** | **7.3** | **7.9** | **6.8** | **7.0** |
