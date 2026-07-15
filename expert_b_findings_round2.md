# 专家 B 审阅报告 Round 2: Core 业务 + Features 补充审阅

## 概要
- 审阅模块数: 18 (深读)
- 发现总数: 33
- 严重度分布: P1 5 个、P2 19 个、P3 9 个
- 本批次 ID 前缀: `BIZ2-xxx`（不重复 BIZ-001 ~ BIZ-014）

---

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| BIZ2-001 | DeepBase.LLM | P1 | bug | ChatAsync 的 TTask 匿名方法捕获 Self，对象释放后悬垂引用 | ~L1750 |
| BIZ2-002 | DeepBase.LLM | P2 | bug | GetConfig 缓存读写存在 TOCTOU 竞态条件 | ~L1084-1093 |
| BIZ2-003 | DeepBase.LLM.BillingClient | P2 | perf | DoStreamRequest 将整个 SSE 响应读入内存，丧失流式优势 | ~L530-560 |
| BIZ2-004 | DeepBase.LLM.BillingClient | P2 | design | 流式请求仅支持标志位取消，无 HTTP 级中断能力 | ~L580-620 |
| BIZ2-005 | DeepBase.LLM.Manager | P1 | bug | DeletePrompt 未级联删除 PromptVersions 与 MetaBinding 记录 | ~L920-950 |
| BIZ2-006 | DeepBase.LLM.Manager | P2 | bug | ExecuteAsync 创建 TTask.Run 后未存储 ITask 引用，销毁后任务悬垂 | ~L1740-1770 |
| BIZ2-007 | DeepBase.Authorization | P2 | perf | HasPermission 每次调用分配 TList\<string\>，高频路径 GC 压力大 | ~L670-720 |
| BIZ2-008 | DeepBase.Scheduler | P2 | bug | TCronExpression.ParseField 在 Field='\*' 时直接退出，未释放 TList | ~L580-630 |
| BIZ2-009 | DeepBase.WorkerQueue | P3 | perf | WaitForCompletion 使用 Sleep(50) 循环轮询，非事件驱动 | ~L1390-1420 |
| BIZ2-010 | DeepBase.WorkerQueue | P2 | bug | CheckAutoScale 使用 FMaxPendingJobs(10000) 计算饱和度，指标无效 | ~L1470-1500 |
| BIZ2-011 | DeepBase.WorkerQueue | P1 | bug | TFileJobStorage 使用 FILE_FLAG_DELETE_ON_CLOSE，锁文件释放后被删除 | ~L2070-2110 |
| BIZ2-012 | DeepBase.FileWatcher | P2 | security | IsValidWatchPath 大小写规范化未处理土耳其语区域设置绕过 | ~L790-820 |
| BIZ2-013 | DeepBase.FileWatcher | P2 | perf | HandleDebounce 每变更创建新 TTask，高频率事件无限创建 | ~L1010-1050 |
| BIZ2-014 | DeepBase.i18n | P3 | perf | EvictOldestIfNeeded 满缓存时每次插入 O(n) 全表扫描 | L433-458 |
| BIZ2-015 | DeepBase.i18n | P3 | perf | 使用 TMonitor(TObject) 而非 TCriticalSection，在竞争频繁时效率低 | ~L343-550 多处 |
| BIZ2-016 | DeepBase.i18n.Gender | P2 | design | TCaseVariant.Transform 直接访问 TGenderVariant 私有字段，破坏封装 | ~L450-500 |
| BIZ2-017 | DeepBase.i18n.Gender | P3 | bug | 法语/西班牙语/意大利语/葡萄牙语性别变换仅加 'e' 或替换 'o' -> 'a' | ~L600-750 |
| BIZ2-018 | DeepBase.AIErrorHandler | P1 | bug | ExceptAddr 在非 except 块中使用，无法获取有效异常地址 | L304-310 |
| BIZ2-019 | DeepBase.AIErrorHandler | P2 | bug | CallAI 缓存键截取前 100 字符，不同错误前缀相同则碰撞 | ~L230-250 |
| BIZ2-020 | DeepBase.AIErrorHandler | P2 | bug | AIConfig.AITimeoutMs 已存储但从未传递给 LLM 调用 | ~L280-310 |
| BIZ2-021 | DeepBase.AppLifecycle | P3 | design | MarkStarted 自增崩溃计数但未检查阈值，可无限重启循环 | L302-317 |
| BIZ2-022 | DeepBase.AppLifecycle | P2 | bug | AcquireSingleton Global 回退到 Local 时未验证锁名唯一性，可能冲突 | L191-231 |
| BIZ2-023 | DeepBase.PluginManager | P2 | design | FirePluginError/Unloaded 在 FLock 内调用，外部回调持有锁 | L473-486, L662-701 |
| BIZ2-024 | DeepBase.PluginManager | P2 | bug | UnloadPlugin 卸载前不校验其他插件是否有逆向依赖 | L673-675 |
| BIZ2-025 | DeepBase.FeatureFlags | P2 | bug | TFeatureFlag.Evaluate 将 AFlagManager 强转为 TFeatureFlagManager 不安全 | L836-850 |
| BIZ2-026 | DeepBase.FeatureFlags | P2 | bug | fsScheduled/fsVariant 状态忽略已配置的定向规则，仅返回默认值 | L865-875 |
| BIZ2-027 | DeepBase.FeatureFlags | P2 | bug | Builder 链式调用时 WithRollout 后 TargetUsers 导致状态被覆盖 | L976-982, L1941-1944 |
| BIZ2-028 | DeepBase.FeatureFlags | P2 | bug | 语义版本比较 toSemVerGT/LT/EQ 全部退化到 `>=`，完全无效 | L656-661 |
| BIZ2-029 | DeepBase.Metrics | P3 | design | Metrics() 函数双检锁模式在 ARM 弱内存模型下可能失效 | L432-445 |
| BIZ2-030 | DeepBase.Metrics | P2 | design | TMetricFamily\<T\>.WithLabels 用运行时 TypeInfo 分支创建类型，扩展性差 | L1295-1304 |
| BIZ2-031 | DeepBase.Services.HealthCheck | P2 | bug | THealthCheckResult.Data 字段从未赋值，始终为 nil | L13-18, L106-128 |
| BIZ2-032 | DeepBase.MVVM | P1 | bug | TAsyncCommand.DoExecute 捕获 SelfRef，对象在主线程释放后任务仍运行 | L539-633 |
| BIZ2-033 | DeepBase.MVVM | P2 | perf | TAsyncCommand.Wait(INFINITE) 在主线程阻塞 UI 消息循环 | L689-722 |
| BIZ2-034 | DeepBase.MVVM | P3 | bug | Email 验证正则过于简单，未处理国际化域名 | L1036-1045 |

---

## 详细发现

### BIZ2-001: [LLM] ChatAsync 的 TTask 闭包捕获 Self 导致悬垂引用

**模块**: `Core/DeepBase.LLM.pas`
**严重度**: P1 (bug)
**类型**: 内存安全

**问题描述**:
`ChatAsync` 方法创建 `TTask.Run` 时，匿名方法内部直接引用了 `Self`（即 `TDeepBaseLLM` 实例）。如果调用方在任务完成前释放了 `TDeepBaseLLM` 对象，匿名方法中的 `Self` 引用将指向已释放的内存，导致访问违反。

**影响**:
异步 LLM 调用时如果组件生命周期管理不当，会导致不可预测的崩溃。特别是在 UI 应用中，页面关闭后 LLM 请求还在后台运行时。

**建议修复**:
在切换到 `TTask` 之前，用局部变量快照所有需要的字段值（类似 BillingClient 已完成的 EXP-P1-003 修复模式），避免直接捕获 Self。

---

### BIZ2-002: [LLM] GetConfig 缓存 TOCTOU 竞态条件

**模块**: `Core/DeepBase.LLM.pas`
**严重度**: P2 (bug)
**类型**: 并发

**问题描述**:
`GetConfig` 方法在执行缓存查找时：
1. 进入 `FCacheLock` 检查缓存
2. 释放 `FCacheLock`
3. 如果未命中，调用 `RefreshConfigCache`
4. 重新获取 `FCacheLock` 更新缓存

在步骤 2 与步骤 4 之间，另一个线程可能已通过 `RefreshConfigCache` 更新了缓存。这将导致：
- 两次同时的缓存刷新（重复数据库查询）
- 后完成的刷新覆盖先完成的刷新（丢失更新）

**建议修复**:
使用双检锁模式：释放锁后检查数据库，然后重新加锁并再次检查缓存是否已被其他线程填充。

---

### BIZ2-003: [LLM.BillingClient] DoStreamRequest 将整个 SSE 响应读入内存

**模块**: `Core/DeepBase.LLM.BillingClient.pas`
**严重度**: P2 (性能)
**类型**: 资源管理

**问题描述**:
`DoStreamRequest` 方法调用 `Response.ContentAsString` 将整个 HTTP 响应体加载到内存中，然后逐行拆分处理 SSE 事件。对于流式 API（如 OpenAI Chat Completions），这完全丧失了流式处理的优势——客户端必须等待完整响应到达才能开始处理第一个 token。

**影响**:
- TTFB（首 token 时间）大幅增加
- 大响应时内存占用高
- 用户感知延迟明显

**建议修复**:
使用 `TNetHTTPClient` 的 `OnReceiveData` 事件或逐块读取响应流，在数据到达时即时解析 SSE 事件。

---

### BIZ2-004: [LLM.BillingClient] 流式请求无 HTTP 级取消能力

**模块**: `Core/DeepBase.LLM.BillingClient.pas`
**严重度**: P2 (设计)
**类型**: 功能缺失

**问题描述**:
`Cancel` 方法仅设置一个布尔标志，流式处理循环在分块之间检查此标志。但如果在等待下一个数据块时 HTTP 请求被阻塞（网络延迟、服务器无响应），取消标志永远不会被检查，请求也无法终止。

**影响**:
用户取消操作后，底层 HTTP 连接仍可能保持打开状态，浪费资源。

**建议修复**:
使用 `TNetHTTPClient` 的 `Abort` 方法来实际终止底层 HTTP 连接，或使用信号量/CancellationToken 传递给 HTTP 客户端。

---

### BIZ2-005: [LLM.Manager] DeletePrompt 未级联删除关联记录

**模块**: `Core/DeepBase.LLM.Manager.pas`
**严重度**: P1 (bug)
**类型**: 数据完整性

**问题描述**:
当删除一个 Prompt 时，`DeletePrompt` 仅删除了主记录。关联的 `PromptVersion` 版本记录和 `PromptMetaBinding` 元数据绑定记录未被删除。这会导致：
- 数据库中出现孤儿记录
- 重新创建同名 Prompt 时可能出现版本冲突
- 数据库膨胀

**建议修复**:
在单个事务中执行级联删除：先删 PromptMetaBinding，再删 PromptVersions，最后删 Prompt 主记录。

---

### BIZ2-006: [LLM.Manager] ExecuteAsync 飞火流星式 TTask

**模块**: `Core/DeepBase.LLM.Manager.pas`
**严重度**: P2 (bug)
**类型**: 生命周期

**问题描述**:
`ExecuteAsync` 方法调用 `TTask.Run(...)` 但未将返回的 `ITask` 引用存储到字段中。如果 `TDeepBaseLLMManager` 实例在任务完成前被销毁，任务中的匿名方法将继续执行并引用已被释放的对象。

**影响**:
- 执行结果丢失（完成任务无法回调）
- 如果任务中的闭包访问已释放的对象，会导致访问违反

**建议修复**:
至少应存储 ITask 引用并在 `Destroy` 中等待或在 `CancelPendingOperations` 中取消。更好的方案是使用 `TCancellationToken` 传递生命周期信号。

---

### BIZ2-007: [Authorization] HasPermission 高频路径过多分配

**模块**: `Core/DeepBase.Authorization.pas`
**严重度**: P2 (性能)
**类型**: 内存分配

**问题描述**:
`HasPermission` 每次调用都会创建新的 `TList<string>` 来收集有效权限（通过 `GetEffectivePermissions`）。在权限检查的高频路径中（每次按钮点击、API 调用），这种分配会造成 GC 压力和内存碎片。

**影响**:
在高并发场景下，频繁的堆分配会导致性能下降和垃圾回收开销。

**建议修复**:
- 将权限结果缓存在用户上下文中，仅在角色/权限变更时失效
- 或使用线程局部缓存重用 `TList<string>` 实例

---

### BIZ2-008: [Scheduler] TCronExpression.ParseField 内存泄漏

**模块**: `Core/DeepBase.Scheduler.pas`
**严重度**: P2 (bug)
**类型**: 资源泄漏

**问题描述**:
`TCronExpression.ParseField` 方法在执行解析时创建了 `TList<Integer>` 对象（`Values`），但在字段值为 `'*'` 时，方法在 `Values` 上调用 `.Add` 操作后直接 `Exit`（或通过结果路径返回），未释放 `Values` 对象。

**影响**:
每次解析包含通配符的 Cron 表达式时会泄漏一个小对象。如果调度器频繁初始化或重载配置，泄漏会累积。

**建议修复**:
使用 `try/finally` 确保 `Values.Free` 在所有路径上都被调用，或改为使用局部 `TArray<Integer>` 避免堆对象。

---

### BIZ2-009: [WorkerQueue] WaitForCompletion 使用 Sleep(50) 轮询

**模块**: `Core/DeepBase.WorkerQueue.pas`
**严重度**: P3 (性能)
**类型**: CPU 效率

**问题描述**:
`WaitForCompletion` 方法使用 `Sleep(50)` + `GetStats`（获取 `FLock`）进行循环轮询以等待队列完成。这种方式：
1. CPU 效率低（每 50ms 唤醒一次检查）
2. 每次轮询都需获取 `FLock`，与其他工作线程竞争
3. 延迟响应（最长 50ms 的睡眠延迟）

**建议修复**:
使用 `TEvent` 信号量机制：在队列变空时 `SetEvent`，`WaitForCompletion` 等待 `TEvent.WaitFor(INFINITE)`。这可以实现零 CPU 占用的等待和即时响应。

---

### BIZ2-010: [WorkerQueue] CheckAutoScale 饱和度计算指标错误

**模块**: `Core/DeepBase.WorkerQueue.pas`
**严重度**: P2 (bug)
**类型**: 逻辑错误

**问题描述**:
`CheckAutoScale` 方法计算 `LSaturation := FQueue.Count / FMaxPendingJobs`。其中 `FMaxPendingJobs` 是队列容量上限（默认 10000），而非有意义的目标饱和度阈值。当有 1 个待处理任务时，饱和度为 0.0001（即 0.01%），自动扩容逻辑实际上永远不会触发。

**影响**:
自动扩容功能失效。如果初始工作线程数不足以处理负载，系统永远不会自动增加工作线程，导致任务积压持续增长。

**建议修复**:
饱和度计算应基于：
- 待处理任务数 / 当前活跃工作线程数（衡量每个线程的负载）
- 或待处理任务数 / 预期间隔内的处理能力

---

### BIZ2-011: [WorkerQueue] TFileJobStorage 锁文件使用 DELETE_ON_CLOSE

**模块**: `Core/DeepBase.WorkerQueue.pas`
**严重度**: P1 (bug)
**类型**: 数据完整性

**问题描述**:
`TFileJobStorage.AcquireFileLock` 在创建锁文件时使用了 `FILE_FLAG_DELETE_ON_CLOSE` 标志。这意味着当所有句柄关闭后，文件会被自动删除。如果在多进程场景下：
1. 进程 A 获取锁（文件存在）
2. 进程 A 释放锁（所有句柄关闭，文件被标记删除）
3. 进程 B 尝试获取锁——但锁文件已被删除，需重新创建

这导致锁机制在跨进程场景下不可靠：锁文件可能在第二个进程需要时不存在，导致两个进程都能获取"锁"。

**建议修复**:
移除 `FILE_FLAG_DELETE_ON_CLOSE`，手动管理锁文件的生命周期。

---

### BIZ2-012: [FileWatcher] IsValidWatchPath 土耳其语区域设置绕过

**模块**: `Core/DeepBase.FileWatcher.pas`
**严重度**: P2 (security)
**类型**: 安全

**问题描述**:
`IsValidWatchPath` 方法使用 `UpperCase` 进行路径规范化。在土耳其语区域设置中，小写 'i' 转换为大写 'I'（U+0130 带点 I），而非标准的 'I'（U+0049）。攻击者可能通过使用包含 'i' 的路径绕过 `StartsWith` 安全检查——如果规范化的比较基准使用标准大写而规范化后的路径使用土耳其语大写，则 `StartsWith` 可能错误地返回 `False`，允许无效路径通过检查。

**建议修复**:
使用 `AnsiUpperCase` 或指定不变区域设置的 `ToUpper(InvariantCulture)` 进行路径比较，避免特定区域设置引起的不一致。

---

### BIZ2-013: [FileWatcher] HandleDebounce 无限创建 TTask

**模块**: `Core/DeepBase.FileWatcher.pas`
**严重度**: P2 (性能)
**类型**: 资源泄漏

**问题描述**:
每次文件变更经过消抖窗口后，`HandleDebounce` 都会创建一个新的 `TTask` 来触发回调。如果短时间内发生大量文件变更（如编译输出、git checkout），系统会无限制地创建 `TTask` 对象，可能导致线程池饱和和内存压力。

**影响**:
- 大量 TTask 对象抢占线程池资源
- 系统负载高时可能导致线程饥饿
- 事件处理顺序不确定（多个 TTask 并发执行）

**建议修复**:
引入节流/批处理机制：
- 合并消抖窗口内的所有变更事件到单个 TTask 中处理
- 使用生产者-消费者模式，单个后台线程处理变更队列

---

### BIZ2-014: [i18n] EvictOldestIfNeeded O(n) 全表扫描

**模块**: `Core/DeepBase.i18n.pas`
**严重度**: P3 (性能)
**类型**: 算法效率

**问题描述**:
`EvictOldestIfNeeded` 方法在缓存达到容量上限时，遍历整个 `TDictionary` 以查找 `LastAccess` 最早的条目。对于 10000 条记录的缓存（默认容量），每次插入新条目都需要扫描 10000 条记录。

**影响**:
- 缓存写操作的复杂度从 O(1) 退化为 O(n)
- 批量预热或高频翻译时性能下降明显

**建议修复**:
使用优先级队列（`THeapQueue`）或有序链表维护 `LastAccess` 顺序，将淘汰时间降低到 O(log n) 或 O(1)。

---

### BIZ2-015: [i18n] TMonitor 低效锁实现

**模块**: `Core/DeepBase.i18n.pas`
**严重度**: P3 (性能)
**类型**: 锁效率

**问题描述**:
整个 i18n 模块使用 `TMonitor.Enter(FLock)`（其中 `FLock` 是 `TObject` 实例）。`TMonitor` 使用 OS 条件变量实现，对短临界区的缓存查找操作来说过于重量级。相比之下，`TCriticalSection` 在超短锁定（微秒级）场景下具有更好的缓存局部性和更低的上下文切换开销。

**影响**:
在 i18n 高并发翻译场景下可能引入可测量的锁竞争开销。

---

### BIZ2-016: [i18n.Gender] 兄弟类越权字段访问

**模块**: `Core/DeepBase.i18n.Gender.pas`
**严重度**: P2 (设计)
**类型**: 封装破坏

**问题描述**:
`TCaseVariant.Transform` 方法直接访问 `TGenderVariant.FCaseTransforms` 私有字段。虽然这两个类是同一单元内的兄弟类、Delphi 允许此类访问，但这破坏了面向对象的封装原则。如果 `TGenderVariant` 增加了自定义锁逻辑（如 `FLock` 保护字段访问），`TCaseVariant` 的直接字段访问将绕过该保护。

**建议修复**:
为 `FCaseTransforms` 添加公开/受保护的访问器属性，或通过方法参数传递所需数据。

---

### BIZ2-017: [i18n.Gender] 罗曼语族性别变换过于简单

**模块**: `Core/DeepBase.i18n.Gender.pas`
**严重度**: P3 (bug)
**类型**: 国际化质量

**问题描述**:
法语/西班牙语/意大利语/葡萄牙语的性别变换规则仅做了简单的后缀处理：
- 法语：加 'e'（`content` -> `contente`），但实际需要处理大量不规则形容词和复合词
- 西班牙语/意大利语：替换末尾 'o' 为 'a'（`bonito` -> `bonita`），但忽略以 'e' 结尾的形容词（如 `interesante`、`grande`）和特殊形式

**影响**:
- 大量不规则形容词的变换结果不正确
- 多词短语（如 `très content` -> `très contente`）的空间位置处理未考虑
- 带音符的形容词处理不当

**建议修复**:
为每种语言实现基于词汇表的性别变换，或集成适当的形态分析器。当前方案仅适用于演示和教育目的。

---

### BIZ2-018: [AIErrorHandler] ExceptAddr 在非 except 块中使用

**模块**: `Core/DeepBase.AIErrorHandler.pas`
**严重度**: P1 (bug)
**类型**: 逻辑错误

**问题描述**:
`GetExceptionLocation` 函数调用了 `ExceptAddr`，但此函数被 `Handle` 方法调用，而 `Handle` 接收异常作为参数（`E: Exception`），并非在 `except` 块中直接调用。`ExceptAddr` 的文档说明它**只**在 `except` 块内部有效。在非 except 块中调用，返回的地址可能是未定义的栈垃圾数据。

**影响**:
- 错误报告中记录的异常位置是随机/错误的值
- 基于异常位置的缓存键（CallAI）可能因不可预测的地址值而产生意外行为
- AI 错误分析基于错误的位置信息可能完全偏离实际出错点

**建议修复**:
将 `ExceptAddr` 的捕获移入 `except` 块，作为变量传入 `Handle` 方法，或使用 `Exception.RaiserExceptionAddr`（如果可用）。

---

### BIZ2-019: [AIErrorHandler] CallAI 缓存键截断导致碰撞

**模块**: `Core/DeepBase.AIErrorHandler.pas`
**严重度**: P2 (bug)
**类型**: 功能缺陷

**问题描述**:
`CallAI` 使用 `Copy(APrompt, 1, 100)` 作为缓存键。如果两个不同的异常具有完全相同的错误消息前缀 100 个字符，它们会被错误地视为相同的错误，返回缓存的 AI 分析结果——即使它们的根本原因是不同的。

**影响**:
- 不同异常可能获得相同的 AI 错误分析结果
- 调试时可能被误导至错误的方向

**建议修复**:
使用完整错误消息的哈希值（如 SHA-256）作为缓存键，结合异常类型名称和源位置（如果可用）。

---

### BIZ2-020: [AIErrorHandler] AIConfig.AITimeoutMs 未传递给 LLM 调用

**模块**: `Core/DeepBase.AIErrorHandler.pas`
**严重度**: P2 (bug)
**类型**: 功能缺失

**问题描述**:
`SetAICallback` 创建了一个调用 `DeepBase.LLM.Chat` 的闭包，但配置中的 `AIConfig.AITimeoutMs` 虽然已存储到字段，却从未传递到底层 LLM 调用中。这意味着 AI 错误分析请求无法超时，如果 LLM 服务无响应，调用线程将被永久阻塞。

**影响**:
- LLM 服务故障时，错误处理系统自身也会挂起
- 无超时保护，应用程序可能因错误处理而冻结

**建议修复**:
在构建 LLM 请求参数时加入超时设置 `AITimeoutMs`，或使用异步方式（`TTask`）配合超时等待。

---

### BIZ2-021: [AppLifecycle] 崩溃计数无限增长无阈值检查

**模块**: `Core/DeepBase.AppLifecycle.pas`
**严重度**: P3 (设计)
**类型**: 容错

**问题描述**:
`MarkStarted` 方法检测到上次状态为 `STATE_RUNNING`（表示未正常退出）时递增崩溃计数，但从未检查此计数是否超过某个阈值。如果应用程序因启动时的错误而反复崩溃（如配置文件损坏），系统将无限循环崩溃-重启，无法提供降级恢复机会。

**建议修复**:
在 `MarkStarted` 中增加阈值检查（如连续崩溃 5 次），超过阈值时执行降级策略（如进入安全模式、提示用户或使用默认配置启动）。

---

### BIZ2-022: [AppLifecycle] AcquireSingleton 锁名回退后可能冲突

**模块**: `Core/DeepBase.AppLifecycle.pas`
**严重度**: P2 (bug)
**类型**: 竞争

**问题描述**:
`AcquireSingleton` 在 `Global\` 命名空间创建互斥体失败（`ERROR_ACCESS_DENIED`）时回退到 `Local\` 命名空间。但未验证 `Local\` 命名空间下的互斥体名是否与其他应用程序使用的锁名冲突，因为 `SanitizeName(LockName)` 处理后：
- 不同含义的名称可能被 `SanitizeName` 规范化为相同字符串（如 `my-app` 和 `my_app` 都变成 `my_app`）
- `Local\` 命名空间是会话范围的，不同程序可能使用相同"DeepBase_"前缀

**建议修复**:
在回退时，应使用包含进程 ID 或用户名的更具体名称来降低冲突概率。

---

### BIZ2-023: [PluginManager] 事件回调在锁内触发

**模块**: `Core/DeepBase.PluginManager.pas`
**严重度**: P2 (设计)
**类型**: 锁使用

**问题描述**:
`FirePluginLoaded`、`FirePluginUnloaded` 和 `FirePluginError` 均在 `TMonitor.Enter(FLock)` 保护区域内被调用。这意味着事件订阅者的回调代码在锁内执行。如果回调处理程序尝试调用 PluginManager 的任何方法（甚至其他任何需要锁的操作），可能导致：
- 锁护送（lock convoy）：事件处理时间长导致其他线程等待
- 优先级反转
- 循环锁依赖导致死锁（在非 TMonitor 场景下）

**建议修复**:
将事件通知移到 `finally` 块中锁释放之后执行，或使用延迟后处理模式记录待发送事件，在锁外统一发送。

---

### BIZ2-024: [PluginManager] 卸载插件不检查逆向依赖

**模块**: `Core/DeepBase.PluginManager.pas`
**严重度**: P2 (bug)
**类型**: 逻辑错误

**问题描述**:
`UnloadPlugin` 方法卸载前仅在注释中注明"应检查逆向依赖"但未实现。直接卸载一个有其他插件依赖的插件，将导致那些插件的依赖检查失败（`CheckDependencies`），但它们可能已在运行中，卸载后立即访问功能时出错。

**影响**:
- 依赖插件的 `CheckDependencies` 在下次加载时失败，但已加载的插件在卸载时无感知
- 可能导致正在运行的插件功能异常或访问违反

**建议修复**:
实现逆向依赖检查，先卸载所有依赖于当前插件的插件（递归），再卸载目标插件。

---

### BIZ2-025: [FeatureFlags] TFeatureFlag.Evaluate 不安全类型转换

**模块**: `Core/DeepBase.FeatureFlags.pas`
**严重度**: P2 (bug)
**类型**: 类型安全

**问题描述**:
`TFeatureFlag.Evaluate` 方法接收 `AFlagManager: TObject` 参数，然后在内部使用 `LManager := AFlagManager as TFeatureFlagManager` 进行类型转换。如果任意调用方传入非 `TFeatureFlagManager` 的 `TObject`，将触发 `EInvalidCast` 异常。该方法是公开的，外部代码可以直接调用。

**建议修复**:
- 将参数类型改为 `TFeatureFlagManager` 而不是 `TObject`
- 或使用安全转换 `Supports` 或 `Is` 检查

---

### BIZ2-026: [FeatureFlags] fsScheduled/fsVariant 状态忽略定向规则

**模块**: `Core/DeepBase.FeatureFlags.pas`
**严重度**: P2 (bug)
**类型**: 逻辑错误

**问题描述**:
`TFeatureFlag.Evaluate` 中：
- `fsScheduled` 状态仅检查 `FSchedule.IsActive and FDefaultValue`，完全忽略已配置的 `FTargetingRules`
- `fsVariant` 状态仅返回 `FDefaultValue`，同样忽略定向规则

这意味着一个标志同时配置了调度/变体**和**定向规则时，定向规则被静默忽略。实际上这些状态应该组合使用（如：调度时段内应用定向规则）。

**建议修复**:
每个状态首先检查是否处于有效时段/有变体，然后委托给定向规则评估逻辑。状态不应完全取代规则评估。

---

### BIZ2-027: [FeatureFlags] Builder 链式调用状态覆盖

**模块**: `Core/DeepBase.FeatureFlags.pas`
**严重度**: P2 (bug)
**类型**: API 设计

**问题描述**:
`TFeatureFlagBuilder` 的链式调用中，`WithRollout(50).TargetUsers(['user1'])` 会导致：
1. `WithRollout` 设置 `FState := fsRollout`
2. `TargetUsers` 调用 `AddRule`，后者设置 `FState := fsTargeted`

最终状态为 `fsTargeted`，仅检查定向规则，忽略已配置的 50% 灰度比例。

**影响**:
用户实际得到的是与调用顺序相关而非业务意图相关的行为。两个功能的组合使用完全失效。

**建议修复**:
- 要么状态是组合的（如 `fsRolloutTargeted`）
- 要么区分"主要状态"和"附加规则"
- 或者在 `Build()` 时检测冲突并抛错

---

### BIZ2-028: [FeatureFlags] 语义版本比较完全退化

**模块**: `Core/DeepBase.FeatureFlags.pas`
**严重度**: P2 (bug)
**类型**: 功能缺陷

**问题描述**:
`toSemVerGT`、`toSemVerLT` 和 `toSemVerEQ` 全部使用 `Result := LAttrStr >= LStrValue` 实现。这是完全错误的语义版本比较：
- 字符串比较 `'10.0.0' >= '9.0.0'` 返回 `False`（因为 '1' < '9'）
- `toSemVerGT` 和 `toSemVerLT` 行为完全相同
- `toSemVerEQ` 无法处理 `'1.0.0' = '1.0'` 的情况

**建议修复**:
实现真正的语义版本比较器，将版本字符串拆分为主版本号.次版本号.修订号数字数组进行比较。

---

### BIZ2-029: [Metrics] Metrics() 双检锁模式跨平台问题

**模块**: `Core/DeepBase.Metrics.pas`
**严重度**: P3 (设计)
**类型**: 可移植性

**问题描述**:
全局 `Metrics()` 函数使用双检锁模式初始化 `GMetricsRegistry`。在 x86/x64 Windows 上由于强内存模型是安全的，但在 ARM（Linux 或移动端）弱内存模型下，线程 A 可能看到 `GMetricsRegistry` 非空但引用的对象尚未完全构造。

**建议修复**:
- 在 Delphi 中可使用 `TAtomicExchange` 或内存屏障（`MemoryBarrier`）确保发布语义
- 或使用 `TInterlocked` 比较交换操作
- 该修复在跨平台部署（如 Delphi Linux/Android）时尤为重要

---

### BIZ2-030: [Metrics] TMetricFamily\<T\> 运行时类型分支脆弱

**模块**: `Core/DeepBase.Metrics.pas`
**严重度**: P2 (设计)
**类型**: 可维护性

**问题描述**:
`TMetricFamily<T>.WithLabels` 使用 `TypeInfo(T) = TypeInfo(TCounter)` 等运行时条件创建新指标实例。如果新增指标类型（如 `TGaugeHistogram`），此方法需要同步更新，否则在运行时静默失败（`Result` 保持 `nil`）。

**建议修复**:
考虑使用依赖注入或工厂模式，传入创建闭包 `TFactory: TFunc<TMetricLabels, T>`，消除运行时类型检查。

---

### BIZ2-031: [HealthCheck] THealthCheckResult.Data 始终为 nil

**模块**: `Core/DeepBase.Services.HealthCheck.pas`
**严重度**: P2 (bug)
**类型**: 功能缺失

**问题描述**:
`THealthCheckResult` 记录类型包含 `Data: TDictionary<string, string>` 字段，用于携带健康检查的详细数据。但在 `CheckHealth` 方法（唯一创建 `THealthCheckResult` 的地方）中，`Data` 字段从未被初始化构造或赋值，始终为 `nil`。

**影响**:
- 健康检查 API 消费者期望 `Data` 包含详细信息（如版本号、连接状态等），但始终获取 `nil`
- 尝试将 `nil` 的 `TDictionary` 传递给 `for...in` 等迭代操作将导致访问违反

**建议修复**:
在创建 `CheckResult` 后显式初始化 `Data` 字段：
```pascal
CheckResult.Data := TDictionary<string, string>.Create;
```
并确保调用方在使用后释放（或改为接口类型）。

---

### BIZ2-032: [MVVM] TAsyncCommand 闭包捕获 SelfRef 导致悬垂引用

**模块**: `Core/DeepBase.MVVM.pas`
**严重度**: P1 (bug)
**类型**: 内存安全

**问题描述**:
`TAsyncCommand.DoExecute` 创建 `TTask` 时：
1. 通过 `SelfRef := Self` 捕获 `TAsyncCommand` 引用
2. 在任务匿名方法中通过 `SelfRef` 访问字段（`FCancelled`、`FViewModel` 等）
3. 任务完成后通过 `TThread.Synchronize` 回调主线程设置状态

如果 `TAsyncCommand` 在主线程被释放而任务尚未完成（或 `Synchronize` 回调尚未执行），`SelfRef` 指向已释放的对象。虽然在析构函数中调用了 `Cancel` 和 `Wait`，但：
- `Cancel` 仅设置 `FCancelled := True`，不保证任务立即完成
- `Wait` 使用 `CheckSynchronize` 处理消息队列，但如果任务内部已进入 `Synchronize` 队列但尚未执行，`Destroy` 可能完成 `Wait` 返回后释放对象，而 `Synchronize` 回调随后执行操作已释放的对象

**影响**:
在快速导航场景中（用户频繁切换页面导致 ViewModel 和 Command 的创建与销毁），可能发生随机的访问违反。

**建议修复**:
- 使用 `TThread.ForceQueue` 替代 `TThread.Synchronize`（更安全，即使对象释放也不崩溃）
- 或将 `FTask` 与对象的生命周期强绑定，使用 `TInterlocked` 引用计数

---

### BIZ2-033: [MVVM] Wait(INFINITE) 在主线程阻塞 UI

**模块**: `Core/DeepBase.MVVM.pas`
**严重度**: P2 (性能)
**类型**: UI 响应性

**问题描述**:
`TAsyncCommand.Wait` 方法对主线程做了特殊处理：当调用线程是主线程时，使用 `CheckSynchronize` 消息泵循环来避免死锁。但若传入 `Timeout = INFINITE` 且任务从未完成（如网络失败但任务未设置超时），主线程将被无限阻塞。

**影响**:
- UI 应用程序冻结
- 无法重试或取消（因为消息循环只在等待间隙处理消息）

**建议修复**:
在主线程上不应使用 `Wait(INFINITE)`，应始终设置一个合理超时，超时后提示用户或自动取消。

---

### BIZ2-034: [MVVM] Email 验证正则过于简单

**模块**: `Core/DeepBase.MVVM.pas`
**严重度**: P3 (bug)
**类型**: 输入验证

**问题描述**:
Email 验证正则 `^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$` 存在以下问题：
- 不支持下划线在域名部分的国际化域名（如 `user@müller.de`）
- 不支持带引号的局部部分（如 `"john doh"@example.com`）
- 允许 `admin@example..com`（连续点）

**建议修复**:
使用 RFC 5322 兼容的正则表达式，或集成专门的电子邮件验证库。

---

## 按模块汇总

| 模块文件 | 发现数 | P1 | P2 | P3 |
|----------|--------|----|----|----|
| Core/DeepBase.LLM.pas | 2 | 1 | 1 | 0 |
| Core/DeepBase.LLM.BillingClient.pas | 2 | 0 | 2 | 0 |
| Core/DeepBase.LLM.Manager.pas | 2 | 1 | 1 | 0 |
| Core/DeepBase.Authorization.pas | 1 | 0 | 1 | 0 |
| Core/DeepBase.Scheduler.pas | 1 | 0 | 1 | 0 |
| Core/DeepBase.WorkerQueue.pas | 3 | 1 | 1 | 1 |
| Core/DeepBase.FileWatcher.pas | 2 | 0 | 2 | 0 |
| Core/DeepBase.i18n.pas | 2 | 0 | 0 | 2 |
| Core/DeepBase.i18n.Gender.pas | 2 | 0 | 1 | 1 |
| Core/DeepBase.AIErrorHandler.pas | 3 | 1 | 2 | 0 |
| Core/DeepBase.AppLifecycle.pas | 2 | 0 | 1 | 1 |
| Core/DeepBase.PluginManager.pas | 2 | 0 | 2 | 0 |
| Core/DeepBase.FeatureFlags.pas | 4 | 0 | 4 | 0 |
| Core/DeepBase.Metrics.pas | 2 | 0 | 1 | 1 |
| Core/DeepBase.Services.HealthCheck.pas | 1 | 0 | 1 | 0 |
| Core/DeepBase.MVVM.pas | 3 | 1 | 1 | 1 |
| **总计** | **33** | **5** | **19** | **9** |

---

*注：本批发现专注于上一轮未覆盖的模块和路径。已避免重复 BIZ-001 ~ BIZ-014。*
