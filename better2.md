# DeepBase better2.md — 第二轮逐模块代码审阅

> 更新日期: 2026-05-15
> 用途: 在 better.md 基础上，对全部源码逐文件审阅后发现的新 bug / 错误 / 优化点
> 不含: better.md 中已记录的 BASIC-*/LLM-*/EDGE-*/COMM-*/SPEECH-*/GOV-* 等发现
> 不含: bugfix.md 中已记录并修复的 BUG-BA-* 系列问题

---

## 总览

| 模块 | BUG | ERROR | OPTIMIZE | 合计 |
|------|-----|-------|----------|------|
| Core | 14 | 0 | 3 | 17 |
| Persistence | 16 | 0 | 8 | 24 |
| Features | 13 | 2 | 5 | 20 |
| VCL/FMX | 7 | 1 | 5 | 13 |
| Governance | 5 | 0 | 4 | 9 |
| Browser | 6 | 0 | 4 | 10 |
| IntentClarification | 16 | 10 | 5 | 31 |
| Inference | 8 | 5 | 2 | 15 |
| **合计** | **85** | **18** | **36** | **139** |

---

## 一、Core 模块（17 项）

### NEW-001 · BUG · Config 缓存默认值导致错误返回
**文件:** `Core/DeepBase.Config.pas:282-296`

`GetConfig` 在 `Result = Default` 时也缓存返回值。如果存储被外部更新，缓存将无限期保留默认值。更严重的是，两个调用者用不同 `Default` 值调用同一键，第一个调用者的默认值被缓存并返回给第二个调用者。

**修复:** 仅当配置项确实存在于存储中时才缓存。需要在存储层区分"找到的值恰好等于默认"和"未找到"。

### NEW-002 · OPTIMIZE · Logging 无条件依赖 Winapi.Windows
**文件:** `Core/DeepBase.Logging.pas:190`

`implementation uses` 中无条件引用 `Winapi.Windows`（用于 `OutputDebugString`），破坏非 Windows 编译。

**修复:** 包裹 `{$IFDEF MSWINDOWS}`。

### NEW-003 · BUG · Logging 双重转义损坏 JSON
**文件:** `Core/DeepBase.Logging.pas:519-520`

`SanitizeLogMessage` 先运行，然后 `EscapeLogContent` 再次运行。JSON 格式下 `TJSONObject.ToString` 已生成合法 JSON，二次转义破坏结构。

**修复:** JSON 格式跳过 `EscapeLogContent`。

### NEW-004 · OPTIMIZE · 日志轮转无上限循环
**文件:** `Core/DeepBase.Logging.pas:629-642`

`NextRotatedFileName` 无最大索引限制，数千个轮转文件时无限循环。

**修复:** 加最大索引限制（如 999）。

### NEW-005 · BUG · TSimpleCrypto 盐值确定性派生
**文件:** `Core/DeepBase.Crypto.pas:1543-1577`

`EncryptBytes` 从密码派生盐值（`DeriveSalt`），相同密码总产生相同盐值，盐值不增加熵。

**修复:** 加密时生成随机盐值并存储在密文前。

### NEW-006 · OPTIMIZE · AES 密钥派生迭代数过低
**文件:** `Core/DeepBase.Crypto.pas:1208`

`SetKeyFromPassword` 仅用 10000 次 PBKDF2 迭代，远低于 `TPasswordUtils.HashPassword` 使用的 100000 次。

**修复:** 提高到至少 100000 次。

### NEW-007 · BUG · Crypto 加解密流一次性加载全部内存
**文件:** `Core/DeepBase.Crypto.pas:1453-1478`

`EncryptStream/DecryptStream` 将整个流读入内存，大文件会导致 OOM。

**修复:** 分块处理。

### NEW-008 · BUG · StateMachine.FireIfInState 死锁
**文件:** `Core/DeepBase.StateMachine.pas:751-766`

`FireIfInState` 在 `FLock` 内调用 `Fire`，而 `Fire` 也获取 `FLock`。`TCriticalSection` 不可重入，导致死锁。

**修复:** 创建无锁版本的 `FireInternal`，或改用 `TMonitor`（支持重入）。

### NEW-009 · BUG · StateMachine.IsInState 无循环检测
**文件:** `Core/DeepBase.StateMachine.pas:829-850`

如果状态父子层次配置错误形成环，`while True` 无限循环。

**修复:** 加最大深度计数器或已访问集合。

### NEW-010 · BUG · Cache FIFO 队列无限增长
**文件:** `Core/DeepBase.Cache.pas:380-447`

`Put` 替换已有键时 `FInsertOrder.Enqueue(Key)` 追加重复项。`EvictFIFO` 跳过不在字典中的项但队列本身无限增长。

**修复:** 覆盖时从队列中移除旧键，或改用有序字典。

### NEW-011 · OPTIMIZE · Cache LRU UpdateAccessOrder 线性搜索
**文件:** `Core/DeepBase.Cache.pas:741-749`

`FAccessOrder` 使用 `TList<K>` 线性搜索，每次 Put/TryGet 均为 O(n)。

**修复:** 改用 linked hash map 模式或维护索引字典。

### NEW-012 · BUG · ObjectPool 后台清理任务 FShutdown 无内存屏障
**文件:** `Core/DeepBase.ObjectPool.pas:506-528`

`FShutdown` 是普通 Boolean，后台任务跨线程读取无 `TInterlocked`，内存可见性无保证。

**修复:** 改用 `TInterlocked.Read/Exchange`。

### NEW-013 · BUG · Scheduler 异步任务闭包 use-after-free
**文件:** `Core/DeepBase.Scheduler.pas:976-1075`

`ExecuteTask` 闭包捕获 `Task: TScheduledTask`。Stop 等待最多 10 秒后直接销毁 FTasks，后台 TTask 仍可能通过捕获引用访问已释放对象。第 1000 行 `Task.FProc()` 可能在 Task 已释放后执行。

**修复:** 任务引用计数或强引用。

### NEW-014 · BUG · Scheduler FOnFailed 在锁内回调
**文件:** `Core/DeepBase.Scheduler.pas:1047`

异步任务的 `except` 块中 `Task.FOnFailed` 在 `FLock` 内调用。回调尝试与调度器交互会导致死锁。

**修复:** 锁外调用 `FOnFailed`。

### NEW-015 · BUG · Resilience.Timeout 跨线程变量无同步
**文件:** `Core/DeepBase.Resilience.Timeout.pas:93-117`

`Completed/ErrorClass/ErrorMsg` 在调用线程和 TTask 线程间共享无同步。TTask 完成与调用线程读取结果间存在竞态。

**修复:** 使用 TMonitor/TEvent 信号量或 Interlocked 操作。

### NEW-016 · BUG · Resilience.Timeout 超时后不取消后台任务
**文件:** `Core/DeepBase.Resilience.Timeout.pas:108-113`

超时后抛 `ETimeoutException` 但从不 `Task.Cancel`，后台任务继续运行消耗资源。

**修复:** 超时后调用 `Task.Cancel`。

### NEW-017 · BUG · Crypto.RandomInt 模偏差
**文件:** `Core/DeepBase.Crypto.pas:932-941`

`PCardinal(@LBytes[0])^ mod LRange` 引入模偏差。当 2^32 不被 LRange 整除时，部分结果概率更高。

**修复:** 使用拒绝采样消除模偏差。

### NEW-018 · BUG · CircuitBreaker.Execute 状态转换竞态
**文件:** `Core/DeepBase.Resilience.CircuitBreaker.pas:365-377`

`AllowRequest` 和 `RecordSuccess/RecordFailure` 分别获取释放 `FLock`。两步之间其他线程可能改变断路器状态，导致成功记录丢失。

**修复:** 整个 Execute 在单一锁获取内完成，或使用原子状态转换。

### NEW-019 · BUG · Crypto.VerifyPassword 异常处理掩盖格式错误
**文件:** `Core/DeepBase.Crypto.pas:1010-1046`

`try/except` 捕获所有异常返回 `False`。格式错误但可区分的哈希值可能被用于时序攻击。

**修复:** 先验证哈希格式（不依赖 try/except），再进行常量时间比较。

### NEW-020 · BUG · EventBus 全局实例双重检查锁定无内存屏障
**文件:** `Core/DeepBase.EventBus.pas:355-367`

`GEventBus = nil` 首次检查无内存屏障，ARM 上可能看到部分构造对象。同样的问题存在于 IoC.GlobalContainer、Logging.Logger、Manager.DeepBase、RuntimeContext.RuntimeContext。

**修复:** 使用 `TInterlocked.CompareExchange`。

### NEW-021 · BUG · Crypto.ParseDERPublicKey 无边界检查
**文件:** `Core/DeepBase.Crypto.pas:1800-1887`

`ReadLength` 不验证长度是否超出剩余数据。恶意 DER 输入可导致越界读取。

**修复:** 加边界检查。

### NEW-022 · BUG · Config 回调持锁触发（BASIC-027 补充）
**文件:** `Core/DeepBase.Config.pas:300-317`

`FOnConfigChanged` 在 `FLock` 内触发。回调执行慢逻辑会扩大锁范围。

**修复:** 锁内只写入和缓存更新，锁外触发回调。

### NEW-023 · BUG · Scheduler CronExpression DayOfWeek 映射缺注释
**文件:** `Core/DeepBase.Scheduler.pas:486`

`DayOfTheWeek(DT) mod 7` 映射依赖 `DayOfTheWeek` 返回 1..7 的事实，映射正确但缺注释说明。

**修复:** 添加注释。

---

## 二、Persistence 模块（24 项）

### PERSIST-001 · BUG · ConnectionPool.AcquireTimeout 丢失唤醒
**文件:** `Persistence/DeepBase.DB.ConnectionPool.pas:326-334`

`ResetEvent` 在锁内调用，但 `Release` 在锁外 `SetEvent`。`ResetEvent` 和 `WaitFor` 之间可能丢失信号。另外 `FindAvailableConnection` 正向遍历 `FPool.Delete(i)` 会跳过下一项。

**修复:** `ResetEvent` 在锁内、`SetEvent` 也在锁内。遍历改 `downto`。

### PERSIST-002 · BUG · UniPool.CreateConnection 统计计数器无锁
**文件:** `Persistence/DeepBase.DB.Pool.pas:982`

`Inc(FStatistics.TotalCreates)` 不持 `FStatsLock`，但 `GetStatistics/Execute` 在该锁下读写同一字段。

**修复:** 用 `FStatsLock` 包裹。

### PERSIST-003 · OPTIMIZE · UniPool.Execute/Query 无事务支持
**文件:** `Persistence/DeepBase.DB.Pool.pas:1342-1378`

便捷方法 acquire → delegate → release，但委托内的多步写入没有事务包裹。另外 `TPooledConnection.Release` 不调用 `FAvailableEvent.SetEvent`，依赖调用方手动信号。

**修复:** 考虑将 `FAvailableEvent.SetEvent` 移入 `Release`。

### PERSIST-004 · BUG · UniPool.Initialize 调用 Warmup 死锁
**文件:** `Persistence/DeepBase.DB.Pool.pas:890, 1458-1499`

`Initialize` 持有 `FLock` 后调用 `Warmup`，`Warmup` 再次获取 `FLock`。`TCriticalSection` 不可重入，死锁。

**修复:** 重构 `Warmup` 为不获取锁的内部版本，或使用可重入锁。

### PERSIST-005 · BUG · Guardian.Checkpoint SQL 注入
**文件:** `Persistence/DeepBase.DB.Guardian.pas:149-160`

`AMode` 直接拼入 `'PRAGMA wal_checkpoint(' + AMode + ')'`，无白名单验证。

**修复:** 验证 `AMode` 为 `['PASSIVE','FULL','RESTART','TRUNCATE']`。

### PERSIST-006 · OPTIMIZE · Migrations 校验和文件可能并发修改
**文件:** `Persistence/DeepBase.DB.Migrations.pas:311`

`CalculateChecksum` 用 `fmShareDenyNone` 打开文件，其他进程可在校验期间修改文件。

**修复:** 改用 `fmOpenRead or fmShareDenyWrite`。

### PERSIST-007 · OPTIMIZE · JobQueue 每次操作创建新连接
**文件:** `Persistence/DeepBase.DB.JobQueue.pas:307-348`

每个 Enqueue/Heartbeat/Complete/Fail 都创建并销毁 `TFDConnection`，开销大。

**修复:** 使用共享/池化连接。

### PERSIST-008 · BUG · StatusMachine SQL 拼接表名（已有 ValidateIdentifier 但模式不佳）
**文件:** `Persistence/DeepBase.DB.StatusMachine.pas:301,364,447`

`Format('... FROM %s WHERE ...', [TableName])`。已有白名单验证，但 Format 拼 SQL 的模式本身应标记。

**修复:** 无需立即修复，标记 ValidateIdentifier 为安全守卫。

### PERSIST-009 · OPTIMIZE · AutoRefreshConfig 持锁做 I/O
**文件:** `Persistence/DeepBase.DB.AutoRefreshConfig.pas:345-367`

`EnsureCacheFresh` 在 `FLock` 内执行数据库 I/O，阻塞所有读配置线程。

**修复:** 双检锁模式或读写锁。

### PERSIST-010 · OPTIMIZE · Logging.FireDAC 写入失败静默吞异常
**文件:** `Persistence/DeepBase.Persistence.Logging.FireDAC.pas:148-177`

主 insert 和 legacy insert 都失败后异常被吞，日志条目静默丢失，无任何 fallback。

**修复:** 至少 `OutputDebugString` 或写文件作为最终 fallback。

### PERSIST-011 · BUG · Logging.FireDAC 其他公共方法无锁
**文件:** `Persistence/DeepBase.Persistence.Logging.FireDAC.pas:70-136`

`WriteLog` 已用 `FLock` 保护，但 `PurgeOlderThan`、`CountByLevel`、`CountAll` 调用 `EnsureConnection` 时无锁。并发调用可能创建两个连接（其中一个泄漏）。

**修复:** 这些方法也加 `FLock`。

### PERSIST-012 · BUG · License/Security/Manager/Factory UPSERT 竞态
**文件:** `Persistence/DeepBase.Persistence.License.FireDAC.pas:63-107`，以及 `Security.FireDAC.pas:93-148`、`Manager.FireDAC.pas:286-331`、`DB.Factory.pas:237-264`

UPDATE → 检查 RowsAffected → INSERT 模式，两步之间其他线程可能插入同一键，导致 UNIQUE 约束违规。

**修复:** 用 `INSERT OR REPLACE` / `ON CONFLICT DO UPDATE` 原子操作。

### PERSIST-013 · OPTIMIZE · ORM.FireDAC OpenDataSet 所有权不清
**文件:** `Persistence/DeepBase.Persistence.ORM.FireDAC.pas:132-145`

返回 `TDataSet` 由调用方释放，常见泄漏源。另外 `LLM.FireDAC:222` 的 `TableHasColumn` 用 Format 拼表名无验证。

**修复:** 加表名验证（白名单）。

### PERSIST-014 · BUG · Diagnose.FireDAC 多处 SQL 拼接表名列名
**文件:** `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas:194,383-389,429-433,487-488,545-548,639`

`ColumnExists/CheckColumnsExist/CheckForeignKeys/CheckRequiredFields/CheckEnumValues/AddColumnIfNotExists` 均用 Format 嵌入标识符。方法为 public，可被外部传任意值。

**修复:** 入口加标识符验证或改为 private/protected。

### PERSIST-015 · BUG · Manager.FireDAC SQLite 路径 SQL 注入
**文件:** `Persistence/DeepBase.Persistence.Manager.FireDAC.pas:192-194`

SQLite 路径 `Format('SELECT COUNT(*) FROM pragma_table_info(''%s'') ...', [TableName, ColumnName])`，单引号可被注入。PostgreSQL 路径用参数化，SQLite 没有。

**修复:** SQLite 路径也用参数化或加验证。

### PERSIST-016 · BUG · Manager.FireDAC UpdateSchemaInfo 非原子
**文件:** `Persistence/DeepBase.Persistence.Manager.FireDAC.pas:242-263`

两条 UPDATE（SchemaVersion 和 LastUpgrade）无事务。第二条失败导致版本已更新但时间戳未更新。

**修复:** 包裹事务。

### PERSIST-017 · OPTIMIZE · Protection.FireDAC 每次调用创建新连接
**文件:** `Persistence/DeepBase.Persistence.Protection.FireDAC.pas:51-141`

`SetupDatabase/SaveSecureImage/TryLoadSecureImage` 每次创建并销毁 `TFDConnection`。

**修复:** 缓存连接或使用连接池。

### PERSIST-018 · BUG · SQLLogger 写文件/数据库持锁阻塞
**文件:** `Persistence/DeepBase.SQLLogger.pas:444-467`

`WriteToFile/WriteToDatabase` 在 `FLock` 内执行 I/O，慢磁盘或慢数据库阻塞所有日志线程。

**修复:** 改为生产者-消费者模式，后台线程写。

### PERSIST-019 · BUG · SQLLogger Extra 字段 JSON 注入
**文件:** `Persistence/DeepBase.SQLLogger.pas:503-510`

`Format('{"duration_ms":%d,...,"error":"%s"}', ...)` 中 `ErrorMessage` 只替换单引号，反斜杠/换行/控制字符未转义。`operation` 字段完全未转义。

**修复:** 用 `TJSONObject` 构建。

### PERSIST-020 · OPTIMIZE · DoQry UniDbInsertReturningId 不用预编译池
**文件:** `Persistence/DeepBase.DB.DoQry.pas:1356-1452`

每次创建新 `TFDQuery`，不检查 `GPreparedPoolEnabled`，与 Select/Exec/Scalar 不一致。

**修复:** 接入预编译池或文档说明排除原因。

### PERSIST-021 · BUG · UniPool 统计字段多处无 FStatsLock
**文件:** `Persistence/DeepBase.DB.Pool.pas:761,1571-1608,1535-1565`

`Validate` 的 `TotalValidations`、`RemoveExpiredConnections` 的 `TotalDestroys`、`ValidateIdleConnections` 的 `TotalInvalidations` 均不持 `FStatsLock`。`GetStatistics` 在该锁下读取，存在数据竞争。

**修复:** 统一用 `FStatsLock` 保护。

### PERSIST-022 · BUG · GDefaultPool 全局指针无锁
**文件:** `Persistence/DeepBase.DB.Pool.pas:420-428,1799`

`DefaultPool` 读取和 `SetDefaultPool` 写入 `GDefaultPool` 均无同步。`RemovePool` 在 `FLock` 下写 nil，但其他两个函数不。

**修复:** 用 `TInterlocked` 或加锁。

### PERSIST-023 · BUG · ConnectionPool.GetActiveCount/GetAvailableCount 公开但要求调用者持锁
**文件:** `Persistence/DeepBase.DB.ConnectionPool.pas:388-407`

注释说"Assumes caller has lock"，但方法是 public。直接调用会无锁遍历 FPool。

**修复:** 改为 private 或加锁。

### PERSIST-024 · OPTIMIZE · Guardian.BackupTo 先删目标文件
**文件:** `Persistence/DeepBase.DB.Guardian.pas:176-186`

删除目标文件后再 VACUUM INTO，崩溃窗口中既无旧备份也无新备份。

**修复:** VACUUM INTO 到临时文件再 rename。

---

## 三、Features 模块（20 项）

### FEAT-001 · BUG · Supabase SingleOrNull 返回已被释放的对象
**文件:** `Features/DeepBase.Commerce.Adapter.Supabase.pas:183-252`

`SingleOrNull` 从 `TJSONArray` 取 `Items[0] as TJSONObject`，但随后 `Arr.Free` 销毁了父数组及子对象。调用者使用已释放对象。

**修复:** 用 `Arr.Extract(0)` 从数组中取出后再释放数组。

### FEAT-002 · BUG · Firebase FirestoreGet/Post/Patch JSON 解析 nil 崩溃
**文件:** `Features/DeepBase.Commerce.Adapter.Firebase.pas:188-228`

`TJSONObject.ParseJSONValue` 返回 nil 时直接 `as TJSONObject`，访问违规。

**修复:** 类型转换前加 nil 检查。

### FEAT-003 · BUG · Supabase EntitlementToJson/PaymentToJson 写空字符串
**文件:** `Features/DeepBase.Commerce.Adapter.Supabase.pas:434,400`

`Result.AddPair('status', '')` 和 `Result.AddPair('channel', '')`——枚举转字符串未实现，导致 Supabase 存储中权益状态和支付渠道丢失。

**修复:** 实现枚举到字符串转换。

### FEAT-004 · BUG · SDKGateway Order.Metadata 无条件释放
**文件:** `Features/DeepBase.Commerce.SDKGateway.pas:123-135`

`Order.Metadata` 仅在 `APayerOpenId <> ''` 时创建，但 `finally` 块无条件调用 `Order.Metadata.Free`。

**修复:** 用 `FreeAndNil(Order.Metadata)`。

### FEAT-005 · BUG · CommerceService.BeginPayment 允许为失败/关闭订单重复支付
**文件:** `Features/DeepBase.Commerce.Service.pas:194`

只排除 `cosPaid`，`cosFailed/cosClosed` 的订单仍可创建新支付意图。

**修复:** 排除 `[cosPaid, cosClosed, cosFailed, cosRefunded]`。

### FEAT-006 · BUG · Supabase/Firebase ConsumeEntitlement 读取-修改-写入竞态
**文件:** `Features/DeepBase.Commerce.Adapter.Supabase.pas:675-708`、`Firebase.pas:853-889`

先读取 remaining_quota，在 Delphi 中计算，再写回。两个并发请求可能都成功导致超额消费。

**修复:** 使用 RPC/云函数执行原子 `UPDATE ... SET remaining_quota = remaining_quota - $1 WHERE remaining_quota >= $1`。

### FEAT-007 · BUG · SpeechService class var 注册无锁
**文件:** `Features/DeepBase.Speech.Service.pas:219-247`

`FASR/FTTS/FWakeWord/FVoiceprint` 等 class var 直接读写无同步。

**修复:** 加 `TMonitor` 或 `TCriticalSection`。

### FEAT-008 · BUG · SAPI TTS SpeakAsync 后台线程访问 COM 无封送
**文件:** `Features/DeepBase.Speech.TTS.SAPI.pas:136-151`

匿名线程访问 `FVoice.WaitUntilDone`，COM 对象是 STA 的，跨线程需封送。Stop 释放 COM 对象时后台线程可能仍在访问。

**修复:** 专用 STA 工作线程 + 调用队列。

### FEAT-009 · BUG · SAPI/TTS/WakeWord 全局单例竞态
**文件:** `Features/DeepBase.Speech.ASR.SAPI.pas:384-389`、`TTS.SAPI.pas:208-211`、`WakeWord.pas:256-261`

`if GlobalXxx = nil then GlobalXxx := TXxx.Create` 不在锁内，两线程可能都创建实例。

**修复:** 原子初始化或 class constructor。

### FEAT-010 · BUG · SAPI ASR Start 创建 FreeOnTerminate 线程但 Stop 不等待
**文件:** `Features/DeepBase.Speech.ASR.SAPI.pas:298-303`

`FWorkerThread` 用 `FreeOnTerminate := True`，`Stop` 只 `Sleep(100)` 后释放 COM 对象。工作线程可能仍在访问已释放对象。

**修复:** 不用 `FreeOnTerminate`，`Stop` 中 `WaitFor` 等待线程退出。

### FEAT-011 · BUG · WinMM IsRecording 非线程安全
**文件:** `Features/DeepBase.Speech.Audio.WinMM.pas:264-267`

`FIsRecording` 从 WaveInProc 回调和公共方法读写无同步。

**修复:** 用 `TInterlocked.Exchange/Read`。

### FEAT-012 · BUG · WinMM WaveInProc 与 StopRecording 竞态（use-after-free）
**文件:** `Features/DeepBase.Speech.Audio.WinMM.pas:58-75`

回调可能已通过 `IsRecording` 检查但 `StopRecording` 随后设为 False 并 `FreeBuffers`。回调继续执行 `FStream.Write` 时写入已释放内存。

**修复:** `StopRecording` 获取 `FLock` 确保回调未在执行。

### FEAT-013 · BUG · SpeechRegistry.EnsureInit 竞态
**文件:** `Features/DeepBase.Speech.Registry.pas:54-59`

`FLock = nil` 检查和创建之间无同步，两线程可能都创建锁对象。

**修复:** 原子初始化或依赖 initialization 块。

### FEAT-014 · ERROR · CommerceBackendHttpTransport 共享 THTTPClient 非线程安全
**文件:** `Features/DeepBase.Commerce.Backend.Http.pas:642-693`

单个 `FHttpClient` 在并发 `Send` 间共享无锁。

**修复:** 加锁或每次请求创建新客户端。

### FEAT-015 · OPTIMIZE · MFCC 使用 O(N^2) DFT
**文件:** `Features/DeepBase.Speech.MFCC.pas:153-178`

400 样本帧需 80400 次复数乘法，radix-2 FFT 仅需约 3600 次。

**修复:** 实现 radix-2 FFT 或使用第三方库。

### FEAT-016 · OPTIMIZE · SpeechService ShouldAutoStop 每次重处理全部音频
**文件:** `Features/DeepBase.Speech.Service.pas:176-198`

`GetFloatSamples` 复制全部已录音频，`ProcessAll` 从头重新分析。30 秒录音重复分析 480000 样本。

**修复:** 增量处理，只处理新样本。

### FEAT-017 · OPTIMIZE · SpeechService ShouldAutoStop 用 Now 计时精度低
**文件:** `Features/DeepBase.Speech.Service.pas:187`

`TDateTime` 精度约 1ms，且每次重新计算。

**修复:** 用 `QueryPerformanceCounter`。

### FEAT-018 · OPTIMIZE · SpeechService TranscribeFromMic 阻塞调用线程
**文件:** `Features/DeepBase.Speech.Service.pas:309`

`Sleep(Min(AMaxSeconds * 1000, 5000))` 冻结调用线程，无静音检测。

**修复:** 提供基于回调的录音循环。

---

## 四、VCL / FMX 模块（13 项）

### VCL-001 · BUG · LLMChatFrame 后台线程捕获 Self（use-after-free）
**文件:** `VCL/DeepBase.VCL.LLMChatFrame.pas:471-618`

匿名线程捕获 `Self`（TFrame），后台访问 `FClient.Chat`、`FHistory.GetMessages`。框架在线程执行期间被释放则 AV。`FCurrentTask` 声明但从未赋值，取消功能不可用。

**修复:** 捕获接口引用延长生命周期，或聊天逻辑移到独立对象。创建时赋值 `FCurrentTask`。

### VCL-002 · BUG · LLMChatFrame 后台线程无锁访问 FHistory
**文件:** `VCL/DeepBase.VCL.LLMChatFrame.pas:482-483,548`

后台线程调用 `FHistory.GetMessages/GetLastUserMessage` 无同步，主线程可能同时修改。

**修复:** 线程启动前捕获必要数据或加锁。

### VCL-003 · BUG · LLMSettingsFrame 后台线程访问 VCL 控件
**文件:** `VCL/DeepBase.VCL.LLMSettingsFrame.pas:262-271`

闭包捕获 `LbProviders.Items[LbProviders.ItemIndex]` 但 `Items[]` 访问发生在后台线程内。VCL 控件不在主线程访问不安全。

**修复:** 线程启动前将字符串捕获到局部变量。

### VCL-004 · BUG · LLMSettingsFrame RefreshTierList 硬编码选第一个 provider
**文件:** `VCL/DeepBase.VCL.LLMSettingsFrame.pas:346-354`

`if True then begin ProvName := P.Name; Break; end` 总是取第一个 provider，忽略模型匹配。

**修复:** 替换 `if True` 为实际模型匹配检查。

### VCL-005 · BUG · LLMSettingsFrame SwapTierItems 只改 UI 不持久化
**文件:** `VCL/DeepBase.VCL.LLMSettingsFrame.pas:407-418`

上下移动只调 `Items.Exchange`，不调 `LLMAdmin.SetTierModels`。下次刷新恢复原序。`SetTierStatus` 也是空操作。

**修复:** 交换后调用 `LLMAdmin.SetTierModels` 持久化。

### VCL-006 · BUG · WaitForm 双重初始化风险
**文件:** `VCL/DeepBase.VCL.WaitForm.pas:181-206`

`Create(AOwner)` 和 `CreateNew(AOwner)` 都调 `CreateControls`，通过不同路径构造可能重复创建控件。

**修复:** 重构为统一初始化方法。

### VCL-007 · OPTIMIZE · NotificationBar.CheckCancelled 每次调 ProcessMessages
**文件:** `VCL/DeepBase.VCL.NotificationBar.pas:543-547`

工作循环紧密调用 `CheckCancelled` 时 `ProcessMessages` 可能导致重入。

**修复:** 只返回 `FCancelled`，调用者负责抽取消息。

### VCL-008 · OPTIMIZE · LLMConfigPanel API 密钥可通过剪贴板泄露
**文件:** `VCL/DeepBase.VCL.LLMConfigPanel.pas:217-218`

`PasswordChar := '*'` 隐藏显示但复制/全选仍可用。

**修复:** 自定义编辑控件阻止复制。

### VCL-009 · OPTIMIZE · DeepMainForm DoClose 和 Destroy 重复关闭逻辑
**文件:** `VCL/DeepBase.VCL.DeepShell.MainForm.pas:398-461,473-489`

两处都调 `BeforeShellClose/SaveShellState/ShutdownShell`，靠 `FShellInitialised` 标志避免双重执行，但结构脆弱。

**修复:** 提取 `PerformShutdown` 方法。

### VCL-010 · OPTIMIZE · LLMChatFrame AppendToChat 每次 O(n) 重扫
**文件:** `VCL/DeepBase.VCL.LLMChatFrame.pas:365`

`Length(FRichEditChat.Text)` 每次重新组合全部内容。

**修复:** 用 `EM_GETTEXTLENGTH` 或维护位置变量。

### FMX-001 · BUG · FMX NotificationBar.CheckCancelled 调 ProcessMessages
**文件:** `FMX/DeepBase.FMX.NotificationBar.pas:437-441`

跨平台 ProcessMessages 可能触发重入。

**修复:** 只返回 `FCancelled`。

### FMX-002 · ERROR · LLMChatFrame EnableStreaming 声明但未实现
**文件:** `VCL/DeepBase.VCL.LLMChatFrame.pas:488-489`

`FEnableStreaming`/`FStreamBuffer`/`UpdateStreamContent` 已声明但从未使用。`EnableStreaming` 属性误导消费者。

**修复:** 实现真流式或移除相关字段和属性。

### VCL-011 · OPTIMIZE · LLMConfigPanel TestButtonClick 阻塞 UI 线程
**文件:** `VCL/DeepBase.VCL.LLMConfigPanel.pas:559-561`

`FLLM.TestConnection` 在主线程同步执行，冻结 UI。

**修复:** 移到后台线程。

---

## 五、Governance 模块（9 项）

### GOV-019 · BUG · RouteResolver.ReloadRules 不清除 FFallbacks
**文件:** `Governance/DeepBase.Governance.RouteResolver.pas:187-227`

`ClearRules` 清规则但不调 `FFallbacks.Clear`。旧 fallback 残留，删除的路由仍可被 fallback 到。

**修复:** `ClearRules` 后加 `FFallbacks.Clear`。

### GOV-020 · BUG · EvidenceRecorder 关闭不 drain 队列
**文件:** `Governance/DeepBase.Governance.EvidenceRecorder.pas:282-318`

工作线程退出时不处理剩余队列项。析构函数不调 `Flush`。

**修复:** 析构时先 `Flush` 再停线程。

### GOV-021 · OPTIMIZE · ActionGrid 无 bridge 时返回 Success
**文件:** `Governance/DeepBase.Governance.ActionGrid.pas:205-209`

无 bridge 的 action 返回 `Success('No bridge configured')`，下游审计记录夸大成功数。

**修复:** 返回专门的 noop/dry-run 状态。

### GOV-022 · BUG · ConfigRegistrar.RegisterPurpose 所有权不清（泄漏风险）
**文件:** `Governance/DeepBase.Governance.ConfigRegistrar.pas:435-452`

`FPurposeSet.Register` 可能获取所有权，但 `Register` 抛异常时局部变量未释放。`RegisterGate/RegisterAction` 同样。

**修复:** 明确所有权模型——Register 总获取所有权（失败时释放），或 Register 总复制。

### GOV-023 · OPTIMIZE · ValidationEngine.Validate 多次执行规则 O(n^2)
**文件:** `Governance/DeepBase.Governance.Validation.pas:442-461,487-492`

`CountBySeverity` 和 `CanRelease` 各调一次 `Validate`，规则重复执行。

**修复:** 缓存验证结果或 `CanRelease` 短路返回。

### GOV-024 · OPTIMIZE · LLMConfigPanel.SetLLM 用 Free 非 FreeAndNil
**文件:** `VCL/DeepBase.VCL.LLMConfigPanel.pas:373-379,394`

`SetLLM` 中 `FLLM.Free`（不置 nil），异常时 `FLLM` 指向已释放对象。

**修复:** 统一用 `FreeAndNil(FLLM)`。

### GOV-025 · ERROR · LLMConfigPanel.LoadConfig 无错误处理
**文件:** `VCL/DeepBase.VCL.LLMConfigPanel.pas:433-458`

`FLLM.GetConfig` 返回空配置时 UI 重置为默认，覆盖用户未保存的输入。

**修复:** 配置不存在时保留当前字段值。

### GOV-026 · OPTIMIZE · ActionGrid 全部字典无锁
**文件:** `Governance/DeepBase.Governance.ActionGrid.pas:28-29,87-94,170-210`

`FActions/FBridges` 字典所有方法均无锁。初始化阶段和运行时并发访问时可能 AV。

**修复:** 加 `TCriticalSection` 保护所有方法。

### GOV-027 · OPTIMIZE · DBInitWizard.ValidateStep 未验证默认路径可写
**文件:** `VCL/DeepBase.VCL.DBInitWizard.pas:147-174`

`radDefault.Checked` 路径直接返回 True，不检查路径是否可访问/可写。

**修复:** 加路径可写性检查。

---

## 六、最高优先级修复建议

### P0 — 必须立即修复

| 编号 | 问题 | 风险 |
|------|------|------|
| NEW-008 | StateMachine.FireIfInState 死锁 | 运行时死锁 |
| PERSIST-004 | UniPool.Initialize → Warmup 死锁 | 数据库初始化死锁 |
| FEAT-001 | Supabase SingleOrNull use-after-free | 每次调用都可能崩溃 |
| FEAT-012 | WinMM WaveInProc use-after-free | 音频录制崩溃 |
| FEAT-002 | Firebase JSON 解析 nil 崩溃 | HTTP 错误时崩溃 |
| NEW-015 | Timeout 跨线程变量无同步 | 竞态导致错误结果 |
| VCL-001 | LLMChatFrame 后台线程 use-after-free | 关闭聊天窗口时崩溃 |

### P1 — 尽快修复

| 编号 | 问题 | 风险 |
|------|------|------|
| PERSIST-005 | Guardian.Checkpoint SQL 注入 | 安全 |
| PERSIST-014/015 | Diagnose/Manager.FireDAC SQL 注入 | 安全 |
| PERSIST-012 | 四处 UPSERT 竞态 | 数据完整性 |
| FEAT-003 | Supabase 枚举写空字符串 | 数据损坏 |
| FEAT-005 | BeginPayment 允许失败订单重复支付 | 重复计费 |
| FEAT-006 | ConsumeEntitlement 超额消费 | 额度漏洞 |
| NEW-005 | Crypto 盐值确定性 | 加密强度不足 |
| NEW-017 | RandomInt 模偏差 | 安全随机数不安全 |
| NEW-018 | CircuitBreaker 状态转换竞态 | 熔断失效 |
| NEW-021 | DER 解析无边界检查 | 缓冲区越界 |
| PERSIST-019 | SQLLogger JSON 注入 | 日志注入 |

### P2 — 计划修复

其余 OPTIMIZE 类别项。

---

## 六、Browser 模块（10 项）

> 上下文：该模块已通过 6 轮评审（Phase 1-6），BUG-BA-001~028、C1-C7、H1-H12、M1-M11 全部关闭。
> 以下为第 7 轮审阅发现的新问题。

### BROWSER-001 · BUG · ScriptStore get_text 模板与消费者不匹配
**文件:** `Features/DeepBase.Browser.ScriptStore.pas:196-199`，`Features/DeepBase.BrowserAutomation.pas:624-704`

ScriptStore 的 `browser.get_text` 模板返回 `el ? el.textContent : ""`（纯文本），但 `RunAction(baatGetText)` 的消费者调用 `TryJsonGetText` 解析 `{found, text, error}` 结构。ScriptStore 路径是主路径，生产环境中 GetText 操作将错误解析。

**修复:** 更新 ScriptStore 的 `browser.get_text` 模板返回 `{"found":true/false, "text":"...", "error":"..."}` 结构。

### BROWSER-002 · BUG · ScriptStore click / input_text 模板不返回 {success} 结构
**文件:** `Features/DeepBase.Browser.ScriptStore.pas:189-195`，`Features/DeepBase.BrowserAutomation.pas:845-858`

`browser.click` 模板返回 `document.querySelector({{selector}}).click()`（返回 `undefined`），`RunAction` 消费者调用 `TryJsonBool` 检查 `success` 字段。`undefined` 不被解析为 `true`，生产环境中 Click/InputText 操作总是报告失败。

**修复:** 更新 `browser.click`、`browser.input_text` 模板返回 `{success: true/false, error: "..."}` 结构。

### BROWSER-003 · BUG · betWindowAcquired 事件已声明但从未发布
**文件:** `Features/DeepBase.Browser.WindowPool.pas:299-363`

M7 新增了 `betWindowAcquired` 事件类型，但 `Acquire` 方法发布的是 `betWindowOpened`（第 361 行）。`betWindowAcquired` 从未被使用。

**修复:** 从池中复用时发布 `betWindowAcquired`，新建时发布 `betWindowOpened`；或删除未使用的事件类型。

### BROWSER-004 · BUG · ResponseWaiter durationMs 字段 nil 崩溃
**文件:** `Features/DeepBase.Browser.ResponseWaiter.pas:239`

`LObj.GetValue('durationMs') as TJSONNumber`，如果键缺失则 `GetValue` 返回 nil，`as TJSONNumber` 导致 AV。

**修复:** 类型转换前检查 nil。

### BROWSER-005 · BUG · Selectors 测试与 BUG-BA-005 修复行为矛盾
**文件:** `Tests/Test.DeepBase.BrowserAutomation.pas:181-189`

`Test_Selectors_NonObjectJsonIgnored` 断言 `Input = ''`，但 BUG-BA-005 修复后 `LoadFromJson('[]')` 保留原值 `Input = 'textarea'`。

**修复:** 断言改为 `Assert.AreEqual('textarea', Selectors.Input)`。

### BROWSER-006 · BUG · Engine.WebView2 旧 TBrowserAutomationSessionAdapter 死代码
**文件:** `Features/DeepBase.Browser.Engine.WebView2.pas:142-295`

M1 将适配器移到 `AutomationAdapter.pas` 后，WebView2 单元中仍保留旧的 `TBrowserAutomationSessionAdapter`。其 `Navigate` 方法不检查 nil session，可能 AV。

**修复:** 删除 Engine.WebView2 中的旧适配器死代码。

### BROWSER-007 · BUG · WindowPool.ShutdownAll OwnsObjects 恢复竞态
**文件:** `Features/DeepBase.Browser.WindowPool.pas:396-433`

`OwnsObjects` 在两个独立的锁获取之间恢复为 `True`，微小窗口中新增条目可能不被拥有。

**修复:** 清除后在同一锁块内恢复 `OwnsObjects`。

### BROWSER-008 · OPTIMIZE · Session GetCurrentState/CanFire/GetPermittedTriggers 无锁
**文件:** `Features/DeepBase.Browser.Session.pas:370-386`

读取 `FStateMachine` 不获取 `FLock`，同类其他方法均用 `FLock`。

**修复:** 加 `FLock` 保护。

### BROWSER-009 · OPTIMIZE · Selectors 事件 JSON 原始拼接
**文件:** `Features/DeepBase.Browser.Selectors.pas:169`

`'{"selector":"' + AName + '","error":"not_found"}'`，`AName` 含引号/反斜杠时生成无效 JSON。

**修复:** 用 `TJSONObject` 或 `JsStringLiteral` 构建。

### BROWSER-010 · OPTIMIZE · CDP.WaitForSelector 线程对象泄漏
**文件:** `Features/DeepBase.Browser.CDP.pas:771`

匿名线程未设 `FreeOnTerminate := True`，每次调用泄漏线程对象。

**修复:** Start 前设 `FreeOnTerminate := True`。

---

## 七、IntentClarification 模块（31 项）

> 该模块为首次全面审阅。

### IC-001 · BUG · Engine HandleRegenerate 无锁写入 FSessions
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:479,797`

`HandleRegenerate` 和 budget 耗尽路径直接 `FSessions.AddOrSetValue` 不获取 `FLock`。主流程 `SubmitInput` 在 `FLock` 下执行同一操作。

**修复:** 两处调用都包裹 `FLock.Enter/Leave`。

### IC-002 · BUG · Engine HandleExit 读取后写入竞态
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:359-423`

`HandleExit` 接收的 `LState` 在锁外读取，修改后锁内写回。其他线程可能在读取和写入之间修改同一 session。

**修复:** 锁内重新读取 session state 再写回。

### IC-003 · ERROR · Engine budget 耗尽不记录 turn 到 history
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:793-803`

budget 耗尽时直接设 session 为 completed 并退出，跳过记录 turn（第 806-812 行）。最后一个 turn 从 history 丢失，checkpoint 恢复不完整。

**修复:** budget 耗尽退出前先记录 turn。

### IC-004 · BUG · Session.SuspendIdleSessions 遍历时修改字典
**文件:** `Features/DeepBase.IntentClarification.Session.pas:400-437`

`for ... in FSessions` 循环内调 `FSessions.AddOrSetValue`。现有 key 的 `AddOrSetValue` 在当前 Delphi RTL 中恰好安全，但违反字典契约。

**修复:** 先收集需暂停的 key，再统一更新。

### IC-005 · BUG · Types.FromJson 违反 Property 42（不应抛异常）
**文件:** `Features/DeepBase.IntentClarification.Types.pas:338-347`

`FromJson` 对无效 JSON 抛 `EArgumentException`。Property 42 要求"对非法 JSON 返回描述性错误而非抛异常"。

**修复:** 返回带错误信息的默认 checkpoint，不抛异常。

### IC-006 · BUG · Types.FromJson sessionState 类型转换未检查 nil
**文件:** `Features/DeepBase.IntentClarification.Types.pas:354`

`LRoot.GetValue('sessionState') as TJSONObject` 不检查 nil 和类型。`null` 或非对象值导致 AV。

**修复:** nil 检查 + 类型验证。

### IC-007 · BUG · Engine 降级处理器从未被调用
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:725-741`

当 `FindProvider` 返回 nil（无对应级别 provider）时，Engine 直接生成通用消息，不调用 `TDegradationHandler.Degrade`，也不尝试低级别 provider。Requirement 14.1 要求 L4→L3→L2→L1→L0 逐步降级。

**修复:** `FindProvider` 失败时循环递减级别尝试低级别 provider，通过 `TDegradationHandler` 记录降级。

### IC-008 · BUG · Provider L2 FDeniedHypotheses 无界增长 + 无线程安全
**文件:** `Features/DeepBase.IntentClarification.Provider.L2.pas:69-71,264-272`

`FDeniedHypotheses` 是 `TList<string>`，只增不删，长会话无限增长。`Contains` 是 O(n)。作为 IoC 单例共享时并发修改无线程安全。

**修复:** 改用 `THashSet<string>` 或 `TDictionary<string,Boolean>`，加 `TCriticalSection` 或改为 per-session。

### IC-009 · BUG · Provider L3 FCurrentExpert/FExpertSelected 无线程安全
**文件:** `Features/DeepBase.IntentClarification.Provider.L3.pas:118-139,259-273`

作为 IoC 单例共享时，并发 session 会互相覆盖专家选择状态。

**修复:** 加锁或改为 per-session。

### IC-010 · BUG · LLMResilience 超时只记录日志不实际中止
**文件:** `Features/DeepBase.IntentClarification.LLMResilience.pas:264-272`

用 `TStopwatch` 测量时间，超过 `TimeoutMs` 只写警告日志。`FInner.Chat` 阻塞多久 wrapper 就阻塞多久。

**修复:** 用 `TTask.WaitForAll(..., TimeoutMs)` 实际强制超时，或文档标注 `TimeoutMs` 仅为告警性。

### IC-011 · BUG · LLMResilience MakeFailureResult 丢弃错误信息
**文件:** `Features/DeepBase.IntentClarification.LLMResilience.pas:234-240,301`

`MakeFailureResult(AError)` 忽略 `AError` 参数，不填 `ErrorCode/ErrorMessage`。调用者无法知道失败原因。

**修复:** 填充 `Result.ErrorMessage := AError`。

### IC-012 · ERROR · LLMResilience GenerateImage 不走 resilience 包装
**文件:** `Features/DeepBase.IntentClarification.LLMResilience.pas:377-382`

`GenerateImage` 直接透传，无熔断/重试/失败记录。破坏装饰器契约。

**修复:** 包装相同 resilience 模式或注释说明排除原因。

### IC-013 · BUG · Storage.JsonToRapport 不处理 nil JSON 值
**文件:** `Features/DeepBase.IntentClarification.Storage.pas:337-342`

`LObj.GetValue('userId').Value` 不检查 nil。字段缺失时 AV。

**修复:** 使用带默认值的 helper 或 nil 检查。

### IC-014 · BUG · Storage.JsonToRapport boundaries 类型转换未验证
**文件:** `Features/DeepBase.IntentClarification.Storage.pas:344`

`LObj.GetValue('boundaries') as TJSONArray` 不验证类型。`"boundaries": "none"` 时崩溃。

**修复:** nil 检查 + `is TJSONArray` 验证。

### IC-015 · BUG · Templates.ApplyOverride 可产生无效枚举值
**文件:** `Features/DeepBase.IntentClarification.Templates.pas:118-120`

`TClarificationLevel(StrToIntDef(AValue, Ord(ATemplate.MaxLevel)))` 不做范围验证。整数值 99 产生无效枚举值。

**修复:** 范围验证后 fallback 到默认。

### IC-016 · ERROR · Templates.ApplyOverride 静默忽略未知字段名
**文件:** `Features/DeepBase.IntentClarification.Templates.pas:105-133`

未知 `AField` 返回模板不变，调用者不知道覆盖被忽略。

**修复:** 对未知字段名抛 `EArgumentException` 或返回 boolean。

### IC-017 · BUG · Anticipation FPredictionCounter/FFeedback 无线程安全
**文件:** `Features/DeepBase.IntentClarification.Anticipation.pas:69-73,238-254`

作为单例共享时 `FPredictionCounter` 递增和 `FFeedback` 列表操作无同步。

**修复:** `TInterlocked.Increment` 计数器，锁保护 feedback 列表。

### IC-018 · OPTIMIZE · Metrics 计数器非原子
**文件:** `Features/DeepBase.IntentClarification.Metrics.pas:94-129`

`Inc()` 和字段读取无同步，并发记录可能丢失或损坏计数器。

**修复:** `TInterlocked.Increment/Read`。

### IC-019 · OPTIMIZE · SignalDetector.CountToken O(n^2)
**文件:** `Features/DeepBase.IntentClarification.SignalDetector.pas:45-62`

`Copy(AText, LStart, MaxInt)` 每次循环创建新字符串副本，长文本 O(n^2)。

**修复:** 用 `PosEx(AToken, AText, LStart)`。

### IC-020 · ERROR · ParseOptions Chr(Ord('A') + I) 无上界检查
**文件:** `Features/DeepBase.IntentClarification.pas:307-311`

`I > 25` 时产生非字母字符。`AMaxOptions` 通常为 8 所以实际不会触发，但技术上无界。

**修复:** Cap `I` 到 25 或用 `IntToStr(I+1)`。

### IC-021 · ERROR · RegisterLLM 创建 L3/L4 时 persona registry 为 nil 且不可更新
**文件:** `Features/DeepBase.IntentClarification.Registration.pas:84-86`

`TL3ExpertProvider.Create(ALLM, nil)` 和 `TL4RoundtableProvider.Create(ALLM, nil)`。后续调 `RegisterPersonaRegistry` 不影响已创建的 provider（构造时已传入 nil）。

**修复:** 懒创建 provider 或 engine 处理时传递 persona registry。

### IC-022 · BUG · Rapport FProfiles 字典无线程安全
**文件:** `Features/DeepBase.IntentClarification.Rapport.pas:105-149`

作为单例共享时 `LoadProfile/SaveProfile/UpdateAfterSession` 并发调用无同步。

**修复:** 加 `TCriticalSection`。

### IC-023 · ERROR · SessionFSM 硬编码枚举序数值
**文件:** `Features/DeepBase.IntentClarification.SessionFSM.pas:79`

`IC_STATUS_COMPLETED = TSessionStatus(2)` 硬编码序数 2。枚举增删值时静默破坏。

**修复:** 直接用 `ssCompleted` 和 `ssArchived`。

### IC-024 · ERROR · FeatureConfig.GetBudgetConfig 忽略已配置的 UserPatienceThreshold
**文件:** `Features/DeepBase.IntentClarification.FeatureConfig.pas:184-192`

硬编码 `UserPatienceThreshold := 0.3`，`TBudgetConfig.Default` 用 `0.7`。不一致。

**修复:** 以 `TBudgetConfig.Default` 为基础，仅覆盖管理的字段。

### IC-025 · ERROR · TTurnRecord Answer/AssistantOutput 未赋值
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:806-812`

`LTurnRecord` 只赋值 `TurnNumber/UserInput/Question/Level/Posture/Timestamp`，`Answer` 和 `AssistantOutput` 始终为空字符串。

**修复:** 赋值 `LTurnRecord.Answer` 和 `LTurnRecord.AssistantOutput`。

### IC-026 · OPTIMIZE · Session TransitionTo 每次创建新 StateMachine
**文件:** `Features/DeepBase.IntentClarification.Session.pas:278-300`

每次 `TransitionTo` 创建并销毁一个 `TStateMachine` 实例，配置始终相同，浪费分配。

**修复:** 缓存 StateMachine 或缓存配置。

### IC-027 · OPTIMIZE · Provider L4 顺序 LLM 调用（3-5 次串行）
**文件:** `Features/DeepBase.IntentClarification.Provider.L4.pas:191-223`

每个专家串行调一次 LLM，再调一次合成。3-5 次串行调用是最慢路径。

**修复:** 用并行任务生成 viewpoints。

### IC-028 · ERROR · Engine FOwnsEventBus 永远为 False
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:196-205,226`

`Create(AEventBus)` 即使 `AEventBus` 为 nil 也不自建。`FOwnsEventBus` 永远为 False，析构中的释放路径不可达。

**修复:** 移除死代码或加自建选项。

### IC-029 · ERROR · 测试覆盖缺口
**文件:** `Tests/Test.DeepBase.IntentClarification.pas`

无 Provider L2/L3/L4、SignalDetector、Router、Budget、Exit、Rapport、Anticipation、Moments、Degradation 的专门测试。

**修复:** 优先补 Router、Budget、SignalDetector、Degradation 测试。

### IC-030 · ERROR · 设计文档 TAnticipationSource 与代码不一致
**文件:** `Features/DeepBase.IntentClarification.Types.pas:129-134` vs `.kiro/specs/intent-clarification/design.md:309-314`

设计文档定义为 enum，代码实现为 record。字段名也不一致（`PredictedIntent` vs `IntentName`）。

**修复:** 更新设计文档匹配实现。

### IC-031 · OPTIMIZE · Engine RecommendedOption 1-based 约定未文档化
**文件:** `Features/DeepBase.IntentClarification.Engine.pas:748,770`

所有 provider 返回 1-based `RecommendedOption`，但记录定义无文档说明约定。

**修复:** 在 `TProviderResult.RecommendedOption` 定义处注释 1-based 约定。

---

## 八、更新后的最高优先级修复建议

### P0 — 必须立即修复

| 编号 | 问题 | 风险 |
|------|------|------|
| NEW-008 | StateMachine.FireIfInState 死锁 | 运行时死锁 |
| PERSIST-004 | UniPool.Initialize → Warmup 死锁 | 数据库初始化死锁 |
| FEAT-001 | Supabase SingleOrNull use-after-free | 每次调用都可能崩溃 |
| FEAT-012 | WinMM WaveInProc use-after-free | 音频录制崩溃 |
| FEAT-002 | Firebase JSON 解析 nil 崩溃 | HTTP 错误时崩溃 |
| NEW-015 | Timeout 跨线程变量无同步 | 竞态导致错误结果 |
| VCL-001 | LLMChatFrame 后台线程 use-after-free | 关闭聊天窗口时崩溃 |
| **BROWSER-001** | **ScriptStore get_text 模板与消费者不匹配** | **生产环境 GetText 错误解析** |
| **BROWSER-002** | **ScriptStore click/input_text 模板不返回 {success}** | **生产环境 Click/InputText 报告失败** |
| **IC-007** | **降级处理器从未被调用** | **无 provider 时直接失败不降级** |
| **IC-003** | **budget 耗尽不记录 turn** | **历史丢失，checkpoint 不完整** |

### P1 — 尽快修复

| 编号 | 问题 | 风险 |
|------|------|------|
| PERSIST-005 | Guardian.Checkpoint SQL 注入 | 安全 |
| PERSIST-014/015 | Diagnose/Manager.FireDAC SQL 注入 | 安全 |
| PERSIST-012 | 四处 UPSERT 竞态 | 数据完整性 |
| FEAT-003 | Supabase 枚举写空字符串 | 数据损坏 |
| FEAT-005 | BeginPayment 允许失败订单重复支付 | 重复计费 |
| FEAT-006 | ConsumeEntitlement 超额消费 | 额度漏洞 |
| NEW-005 | Crypto 盐值确定性 | 加密强度不足 |
| NEW-017 | RandomInt 模偏差 | 安全随机数不安全 |
| NEW-018 | CircuitBreaker 状态转换竞态 | 熔断失效 |
| NEW-021 | DER 解析无边界检查 | 缓冲区越界 |
| PERSIST-019 | SQLLogger JSON 注入 | 日志注入 |
| **IC-001** | **Engine HandleRegenerate 无锁写入** | **并发崩溃** |
| **IC-008/009** | **L2/L3 Provider 单例无线程安全** | **并发 session 状态损坏** |
| **IC-010** | **LLMResilience 超时不强制中止** | **请求无限阻塞** |
| **IC-011** | **MakeFailureResult 丢弃错误信息** | **无法诊断失败** |
| **IC-021** | **RegisterLLM persona registry 不可更新** | **L3/L4 专家不可用** |
| **BROWSER-004** | **ResponseWaiter durationMs nil 崩溃** | **恶意 postMessage 导致 AV** |
| **INFER-001/002/003** | **Runtime 不清理 provider / 不重置 options / 全局变量** | **重新初始化行为不可预测** |
| **INFER-005** | **AnsiString 双重转换破坏非 ASCII 元数据** | **中文模型名乱码** |
| **INFER-012** | **IoC RegisterAll 失败泄漏 ONNX Runtime** | **资源泄漏** |

### P2 — 计划修复

其余 OPTIMIZE 类别项。

---

## 九、Inference 模块（15 项）

> 该模块为 ONNX 推理引擎接入层，刚集成。首次全面审阅。

### INFER-001 · BUG · Runtime Shutdown 不清理 ONNX provider / 不重置 SessionOptions
**文件:** `Features/DeepBase.Inference.Runtime.pas:131-138`

`ShutdownInternal` 只设 `FInitialized := False`，不 detach 执行 provider（DML/CUDA）、不重置 `DefaultSessionOptions`。Shutdown 后重新 Initialize 到不同 provider 时旧 provider 残留。

**修复:** 存储局部 `TORTSessionOptions`（非全局），Shutdown 时释放/重建。

### INFER-002 · ERROR · Runtime Initialize 不重置 DefaultSessionOptions
**文件:** `Features/DeepBase.Inference.Runtime.pas:77-118`

`Initialize` 调 `SetIntraOpNumThreads` 等但不先重置。以 4 线程初始化后 Shutdown，再 Initialize 不带线程覆盖时旧值残留（`> 0` 守卫跳过调用）。

**修复:** Initialize 开头先创建新的 `TORTSessionOptions`。

### INFER-003 · ERROR · DefaultSessionOptions 是全局变量
**文件:** `Features/DeepBase.Inference.Runtime.pas:90-98`

所有 session options 修改针对全局 `DefaultSessionOptions`。多 `TInferenceRuntime` 实例互相覆盖设置。

**修复:** 改为实例级 `TORTSessionOptions`。

### INFER-004 · BUG · Runtime GetProvider/IsInitialized 无锁读取
**文件:** `Features/DeepBase.Inference.Runtime.pas:67-75`

`GetProvider` 和 `IsInitialized` 不获取 `FLock`，但 `Initialize` 在 `FLock` 下写入。数据竞争。

**修复:** 加锁或用原子读取。

### INFER-005 · BUG · Session 元数据 AnsiString 双重转换破坏非 ASCII
**文件:** `Features/DeepBase.Inference.Session.pas:221-226`

`string(AnsiString(...))` 先过 ANSI 代码页再升 UTF-16。非 ASCII 元数据（中文、日文模型名等）出现乱码。

**修复:** 用 `UTF8ToString` 或 `TEncoding.UTF8.GetString`。

### INFER-006 · BUG · Session.Run 不验证 shape 乘积与元素数匹配
**文件:** `Features/DeepBase.Inference.Session.pas:260-286`

从原始字节算 `LElementCount`，从 `AInputShapes` 读 shape，但不检查维度乘积是否等于元素数。不匹配时 ONNX 运行时报难以理解的错误或内存损坏。

**修复:** 添加验证检查。

### INFER-007 · BUG · Session shape 数组反转需验证
**文件:** `Features/DeepBase.Inference.Session.pas:273-279`

代码反转 shape 数组（注释说"ORT binding expects reversed row-major"）。标准 ONNX Runtime 使用行主序 shape 不需反转。如果绑定实际不需要反转，会静默产生错误张量维度。

**修复:** 验证 ONNX binding 是否确实需要反转。不需要则删除。

### INFER-008 · BUG · Session 构造异常路径可能泄漏资源
**文件:** `Features/DeepBase.Inference.Session.pas:114-133,152-173`

`CreateFromPath/CreateFromBytes` 中如果 `TORTSession.Create` 成功但后续 `New(FOrtSession)` 或 `ExtractModelInfo` 失败，异常处理只设状态并重抛。部分路径可能泄漏 ONNX session 或 values。

**修复:** 用 `try/finally` 确保已分配资源在失败时释放。

### INFER-009 · BUG · TInferenceSession 无线程安全
**文件:** `Features/DeepBase.Inference.Session.pas:175-323`

`Dispose` 和 `Destroy` 都调 `ReleaseOrtSession` 但无锁。`FState` 写入非原子。并发 Dispose 和引用计数释放可能竞态。

**修复:** 加锁或文档标注非线程安全。

### INFER-010 · BUG · Service.IsReady 只检查 Factory 不检查 Runtime
**文件:** `Features/DeepBase.Inference.Service.pas:119-127`

`IsReady` 返回 `FSessionFactory <> nil` 但不验证 `FRuntime` 是否已初始化。Runtime 已 Shutdown 后 `IsReady` 仍返回 True。

**修复:** 加 `FRuntime.IsInitialized` 检查。

### INFER-011 · BUG · Service.Run 无锁，并发 Shutdown 时 session 可能被使用
**文件:** `Features/DeepBase.Inference.Service.pas:157-165`

`CreateSession` 获取 `FLock` 但 `Run` 不获取。Shutdown 在 Run 执行期间可能关闭底层 Runtime。

**修复:** Run 中获取锁或文档标注调用方负责生命周期。

### INFER-012 · ERROR · IoC RegisterAll 失败不清理 ONNX Runtime
**文件:** `Features/DeepBase.Inference.IoC.pas:38-68`

`LRuntime.Initialize(LConfig)` 成功但后续注册失败时，已初始化的 Runtime 不被 Shutdown，泄漏 ONNX 资源。

**修复:** `try/except` 包裹，失败时调 `LRuntime.Shutdown`。

### INFER-013 · OPTIMIZE · Run 每次重新分配 LFloatData/LRevShape
**文件:** `Features/DeepBase.Inference.Session.pas:268`

每次推理 `SetLength(LFloatData)` 和 `Copy(LShape)` 重新分配。高吞吐场景应复用缓冲区。

**修复:** 预分配缓冲区或提供 buffer pool。

### INFER-014 · OPTIMIZE · IoC RegisterAll 无重复注册保护
**文件:** `Features/DeepBase.Inference.IoC.pas:55-59`

重复调 `RegisterAll` 会在容器中注册重复单例。

**修复:** 检查是否已注册或文档标注只能调一次。

### INFER-015 · ERROR · Service 测试 class var 交叉污染风险
**文件:** `Tests/Test.DeepBase.Inference.Service.pas:164-167`

`TInferenceService` 用 `class var`，并行测试时 Setup/TearDown 互相踩踏。

**修复:** TearDown 恢复之前状态或用 per-fixture 实例。
