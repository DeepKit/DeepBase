# 专家 D 审阅报告: 数据层(Persistence)、治理层(Governance)、工作流(DeepFlow)、Schema 适配

> 审查日期: 2026-07-06
> 审查人: 专家 D(持久化、治理层、工作流与 Schema 适配专家)
> 审查范围: Persistence/(全部 38 个 .pas)、Governance/(全部 18+ 个 .pas)、DeepFlow/(全部 12 个 .pas)、Core/Schema、DeepAxis/
> 文件总数: 70+ 个 .pas

## 概要

| 项目 | 数值 |
|------|------|
| 审阅模块数 | 70+ |
| 发现总数 | 64 |
| P0(紧急) | 8 |
| P1(高) | 33 |
| P2(中) | 19 |
| P3(低) | 4 |
| 安全性相关 | 15 |
| 可靠性/正确性 | 27 |
| 架构/设计 | 12 |
| 线程安全 | 10 |

## 严重度定义

| 严重度 | 含义 |
|--------|------|
| P0 | 可直接导致资金损失、数据损坏或系统不可用;须立即修复 |
| P1 | 存在明显缺陷,特定场景下可触发错误;须在当前迭代修复 |
| P2 | 设计瑕疵或潜在风险;建议在后续迭代中修复 |
| P3 | 轻微问题或仅需文档说明 |

---

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| DATA2-001 | Persistence/ORM | P0 | security | Where/AndWhere/OrWhere 条件字符串直接拼接进 SQL,无参数化 | DeepBase.ORM.pas:691-738 |
| DATA2-002 | Persistence/ORM | P0 | security | OrderBy/OrderByDesc 列名直接拼接进 SQL | DeepBase.ORM.pas:753-765 |
| DATA2-003 | DeepAxis/BCryptDecrypt | P0 | security | AES/MAC 密钥析构时未从堆内存清除 | BCryptDecrypt.pas:291-303 |
| DATA2-004 | DeepAxis/BCryptDecrypt | P0 | security | 解密数据库写入可预测临时文件路径,无安全擦除 | BCryptDecrypt.pas:295 |
| DATA2-005 | Governance/Evidence | P0 | architecture | 证据链无防篡改哈希链/签名 | EvidenceStore.SQLite.pas:49-65 |
| DATA2-006 | Governance/Evidence | P0 | reliability | PushItem 返回值丢弃,队列溢出时证据静默丢失 | EvidenceRecorder.pas:265,287 |
| DATA2-007 | Governance/ConfigRegistrar | P1 | correctness | LoadFromDB 在 LoadActions 之前调用 LoadGates,始终抛出异常 | ConfigRegistrar.pas:606-610 |
| DATA2-008 | Governance/Lifecycle | P1 | resource-leak | Initialize 无防重入检查,重复调用泄漏所有引擎实例 | Lifecycle.pas:169-236 |
| DATA2-009 | DeepFlow/Engine | P1 | thread-safety | SendSync 无条件替换/恢复 FOnMessageProcessed 回调 | DeepFlow.Engine.pas:397-435 |
| DATA2-010 | DeepFlow/Engine | P1 | correctness | RouteMessage 广播分发共享同一消息实例 | DeepFlow.Engine.pas:637-650 |
| DATA2-011 | Persistence/ORM | P1 | thread-safety | TMetadataCache 无锁保护,并发访问竞争 | DeepBase.ORM.pas:439-444 |
| DATA2-012 | Persistence/ORM | P2 | reliability | 无脏写检测(乐观并发控制缺失) | DeepBase.ORM.pas:1073-1075 |
| DATA2-013 | Persistence/Migrations | P2 | correctness | PG 锁释放失败覆盖迁移成功状态 | Migrations.pas:200-212 |
| DATA2-014 | Core/SchemaAdapter | P1 | correctness | 指纹使用 StartsWith 前缀匹配导致碰撞 | SchemaAdapter.pas:243-249 |
| DATA2-015 | Core/SchemaAdapter.Registry | P1 | thread-safety | FAdapters 列表无同步机制 | Registry.pas:22-35 |
| DATA2-016 | DeepAxis/SQLiteReader | P1 | reliability | 无文件大小/行数限制,可能导致内存耗尽 | SQLiteReader.pas:227-242,522-544 |
| DATA2-017 | Core/WeChat adapters | P1 | functionality | 指纹为占位符,适配器解析实际已禁用 | WeChat39x.pas:44, WeChat4x.pas:81 |
| DATA2-018 | Persistence/LLM.FireDAC | P1 | security | TableHasColumn 表名直接拼接 SQL 无 ValidateIdentifier | LLM.FireDAC.pas:227 |
| DATA2-019 | Persistence/MRU.FireDAC | P2 | reliability | Upsert SELECT-then-INSERT/UPDATE 无事务封装 | MRU.FireDAC.pas:70-105 |
| DATA2-020 | Governance/ConfigLoader | P2 | security | FConfigDir 未规范化,路径遍历风险 | ConfigLoader.pas:85-93 |
| DATA2-021 | Governance/Accountability | P2 | security | user_id 来自不受信任的调用方上下文 | Accountability.pas:186-194 |
| DATA2-022 | Governance/ComponentAdapter | P2 | security | DFM 文件路径未规范化,路径遍历 | ComponentAdapter.pas:170-178 |
| DATA2-023 | Governance/ConfigRegistrar | P2 | security | 治理模式明文存储,DB 修改可绕过 enforce | ConfigRegistrar.pas:631-650 |
| DATA2-024 | Persistence/Manager.FireDAC | P2 | code-quality | CountCoreTables 对表名使用 QuotedStr(值引用) | Manager.FireDAC.pas:99-113 |
| DATA2-025 | Persistence/Authorization.FireDAC | P2 | compatibility | StartTransaction 在调用方拥有的连接上启动,嵌套风险 | Authorization.FireDAC.pas:590 |
| DATA2-026 | Persistence/DoQry | P1 | reliability | 预编译池键使用原始指针,连接释放+地址重用可匹配错误连接 | DoQry.pas:475-478,1709-1744 |
| DATA2-027 | DeepFlow/Engine | P1 | design | esError 状态无恢复路径,状态机不可逆 | DeepFlow.Engine.pas:31-39,204-259 |
| DATA2-028 | Persistence/DoQry | P1 | design | IsDirectSQL 直通 SQL 绕过参数化安全屏障 | DoQry.pas:935-974 |
| DATA2-029 | Persistence/ORM | P1 | design | DefaultValue 直接拼接到 DDL 无验证 | ORM.pas:1282-1285 |
| DATA2-030 | Core/WeChat4x | P2 | correctness | IsSender 正则无锚点,多标签时可能误判 | WeChat4x.pas:38-56 |
| DATA2-031 | Governance/JsonLogic | P2 | design | 表达式无注册时校验,OpVar("")暴露完整上下文 | JsonLogic.pas:301-306 |
| DATA2-032 | Governance/Validation | P3 | coverage | 8/15 验证规则为骨架空实现 | Validation.pas:435-475 |
| DATA2-033 | DeepFlow/Engine | P1 | memory-leak | SubmitMessage 队列满时消息对象未释放 | DeepFlow.Engine.pas:379-385 |
| DATA2-034 | DeepFlow/Engine | P1 | resource-leak | 工作线程自关闭(self-shutdown)时 TThread 对象未释放 | DeepFlow.Engine.pas:279-292 |
| DATA2-035 | DeepFlow/Context | P1 | thread-safety | TWorkflowContext 全类无锁,并行步骤数据竞争 | Context.pas:全文件 |
| DATA2-036 | DeepFlow/Engine | P1 | design | ProcessMessage 失败消息无重试/Ack/Nack | Engine.pas:600-605 |
| DATA2-037 | DeepFlow/Chronicler | P1 | performance | 同步磁盘 I/O 阻塞引擎工作线程 | Chronicler.pas:260-289 |
| DATA2-038 | DeepFlow/Message | P2 | correctness | FromJSON 反序列化丢失 MsgId/Priority/RetryCount | Message.pas:193-209 |
| DATA2-039 | DeepFlow/Commander | P1 | thread-safety | GetOrCreateSession 返回后会话状态无锁修改 | Commander.pas:349-371 |
| DATA2-040 | DeepFlow/Skill.Client | P2 | reliability | 无超时/重试/错误处理 | Skill.Client.pas:35-56 |
| DATA2-041 | DeepFlow/Guard | P2 | security | 无效正则表达式配置被静默忽略 | Guard.pas:168-173 |
| DATA2-042 | DeepFlow/Engine | P2 | design | Pause 状态对 GetState()不可见 | Engine.pas:311-316 |
| DATA2-043 | DeepFlow/Context | P2 | reliability | EvaluateCondition 递归无深度限制 | Context.pas:495-535 |
| DATA2-044 | DeepFlow/Guard | P2 | design | Guard 作为普通角色可被绕过 | Guard.pas:全文件 |
| DATA2-045 | Persistence/Diagnose.FireDAC | P2 | reliability | 5 处空 except 块吞没数据库异常 | Diagnose.FireDAC.pas:459,517,579,657,677 |
| DATA2-046 | Persistence/JobQueue | P1 | correctness | PG DLQ INSERT+DELETE 无事务包裹;部分失败导致两表均存行 | JobQueue.pas:968-1016 |
| DATA2-047 | Persistence/JobQueue | P1 | correctness | ReplayDeadLetter PG 路径同样缺少事务 | JobQueue.pas:1223-1227 |
| DATA2-048 | Persistence/JobQueue | P1 | correctness | PG backoff 使用客户端 Now() 与服务端 CURRENT_TIMESTAMP 时区不一致 | JobQueue.pas:1035-1042 |
| DATA2-049 | Persistence/SQLLogger | P1 | security | SQL 文本中换行符破坏文件日志结构(log injection) | SQLLogger.pas:442 |
| DATA2-050 | Persistence/SQLLogger | P1 | reliability | 无日志轮转,文件无限增长 | SQLLogger.pas:463-486 |
| DATA2-051 | Persistence/SQLLogger | P1 | thread-safety | FDBConnection 跨线程共享无同步 | SQLLogger.pas:488-547 |
| DATA2-052 | Persistence/SQLLogger | P1 | reliability | WriteToDatabase 假设 Logs 表存在,失败静默丢弃 | SQLLogger.pas:505 |
| DATA2-053 | Persistence/SQLLogger | P1 | thread-safety | GetStatistics 无锁读取 FMemoryLog.Count 和计数器 | SQLLogger.pas:635-658 |
| DATA2-054 | Persistence/SQLLogger | P1 | thread-safety | FSessionId 在锁外写入、锁内读取(竞态) | SQLLogger.pas:239-245 |
| DATA2-055 | Persistence/DB.Pool | P0 | reliability | Validate 验证查询无超时,csValidating 状态永不恢复,池收缩 | Pool.pas:780-827,1673,1702-1759 |
| DATA2-056 | Persistence/AutoRefreshConfig | P0 | thread-safety | 共享 FConnection 多线程无同步访问 | AutoRefreshConfig.pas:101-118,345-378 |
| DATA2-057 | Persistence/DB.Pool | P1 | reliability | Shutdown 在维护线程挂起时阻塞 | Pool.pas:984-991,1632-1644 |
| DATA2-058 | Persistence/DB.Pool | P1 | performance | DoWarmup 在 FLock 内创建连接(含网络 I/O) | Pool.pas:957,1577 |
| DATA2-059 | Persistence/DB.Pool | P1 | correctness | EnsureMinConnections TOCTOU + 可能在关闭时添加连接 | Pool.pas:1791-1840 |
| DATA2-060 | Persistence/DB.Pool | P1 | thread-safety | FShutdown 无内存屏障读写 | Pool.pas:982,1366,1632 |
| DATA2-061 | Persistence/DB.Guardian | P1 | reliability | 静默 except 块隐藏故障 | Guardian.pas:106-108,168-170 |
| DATA2-062 | Persistence/DB.Pool | P1 | reliability | TPooledConnection.Destroy 可能 double-free | Pool.pas:719-726 |
| DATA2-063 | Persistence/DB.StatusMachine | P1 | reliability | SQL 标识符未引用,保留字导致查询失败 | StatusMachine.pas:321,384-388,466-467 |
| DATA2-064 | Persistence/DB.Guardian | P2 | reliability | BackupTo 相对路径可能失败 | Guardian.pas:183-185 |

## 发现详细说明

### 安全性 (Security)

---

#### DATA2-001 — ORM SQL 注入: Where/AndWhere/OrWhere 条件直接拼接

**模块**: Persistence/DeepBase.ORM.pas
**严重度**: P0(安全缺陷)
**类型**: SQL 注入
**位置**: L691-695, L709-715, L731-738

`TQueryBuilder<T>.Where(const Condition: string)` 将 `Condition` 参数直接拼接进 WHERE 子句,不做任何转义或参数化。

```pascal
function TQueryBuilder<T>.Where(const Condition: string): IQueryBuilder<T>;
begin
  FWhereClause := Condition;  // 直接赋值,无转义
  Result := Self;
end;
```

`BuildSelectSQL`(L616-641) 将 `FWhereClause` 直接嵌入 SQL:
```pascal
SQL.Append(' WHERE ').Append(FWhereClause);
```

即使带 params 的重载 (L697-707),`Condition` 本身也是拼接的,仅 `?` 占位符被替换。若调用方传入用户可控字符串,SQL 注入立即生效。

**影响**: O/RM 的直接 SQL 注入。可导致数据泄露、提权、数据损坏。

**修复建议**:
1. Where/AndWhere/OrWhere 的无 params 重载应标记为 `deprecated` 或使用白名单验证。
2. SQL 片段不得拼接;改为完全参数化构建,或使用 QueryBuilder 自身管理的参数列表。

---

#### DATA2-002 — ORM SQL 注入: OrderBy/OrderByDesc 列名直接拼接

**模块**: Persistence/DeepBase.ORM.pas
**严重度**: P0(安全缺陷)
**类型**: SQL 注入
**位置**: L753-765

```pascal
function TQueryBuilder<T>.OrderBy(const Column: string): IQueryBuilder<T>;
begin
  if FOrderByClause <> '' then
    FOrderByClause := FOrderByClause + ', ' + Column
  else
    FOrderByClause := Column;
  Result := Self;
end;
```

`Column` 被直接拼接进 `ORDER BY` 子句,无转义。

**影响**: 与 DATA2-001 相同,SQL 注入。

**修复建议**: 添加列名白名单验证或使用 `QuoteIdentifier` 函数进行转义。

---

#### DATA2-003 — BCryptDecrypt 密钥材料未从内存清除

**模块**: DeepAxis/DeepBase.External.BCryptDecrypt.pas
**严重度**: P0(安全缺陷)
**类型**: 敏感信息残留
**位置**: L291-303

`TBCryptSQLiteReader` 以 `TBytes` 字段存储 AES-256 加密密钥和 HMAC-SHA1 MAC 密钥(共 64 字节敏感材料)。析构函数不归零这些缓冲区:

```pascal
destructor TBCryptSQLiteReader.Destroy;
begin
  if FDecryptedPath <> '' then
    TFile.Delete(FDecryptedPath);
  inherited;  // FAesKey/FMacKey 残留堆上
end;
```

`DeriveSQLCipherKey`(L102-135) 同样不清除派生的密钥字节。

**影响**: 进程转储(crash dump、任务管理器取证)会泄露完整的加密切话密钥。WeChat 数据库可被任何人解密。

**修复建议**: 在 `Destroy` 中对 `FAesKey` 和 `FMacKey` 执行 `FillChar` 置零后再 `SetLength(0)`,派生函数同样处理。

---

#### DATA2-004 — BCryptDecrypt 解密数据库写入可预测临时文件,无安全擦除

**模块**: DeepAxis/DeepBase.External.BCryptDecrypt.pas
**严重度**: P0(安全缺陷)
**类型**: 敏感数据泄露
**位置**: L295

```pascal
FDecryptedPath := TPath.GetTempFileName;
```

`TPath.GetTempFileName` 在系统临时目录创建可预测文件名的文件(格式 `TMP` + 随机数字),包含完整的明文 WeChat 消息数据库。任何具有本地用户访问权限的进程都可读取该文件。`TFile.Delete` 不执行安全覆盖,数据残留磁盘扇区。

**影响**: 解密后的 WeChat 数据库在临时目录中完全暴露。

**修复建议**:
1. 使用 `TGUID.NewGuid.ToString` 创建不可预测的文件名。
2. 在删除前用随机数据覆盖文件(至少 3 遍)。
3. 考虑使用 `FILE_FLAG_DELETE_ON_CLOSE` 或 NTFS 加密。

---

#### DATA2-005 — 治理层证据链无防篡改机制

**模块**: Governance/DeepBase.Governance.EvidenceStore.SQLite.pas
**严重度**: P0(架构缺陷)
**类型**: 审计完整性
**位置**: L49-65, EvidenceRecorder.pas L245-265

证据审计跟踪没有任何完整性保护。记录以明文行存储在 SQLite 中,以 UUID 为主键,但没有哈希链、数字签名或 WAL 级完整性检查。任何对 SQLite 数据库有写访问权限的实体都可以自由修改、删除或插入伪造证据记录而不被发现。

**修复建议**: 实现哈希链,每个记录包含前一个记录的 SHA-256 哈希 + 当前记录字段,并定期将聚合哈希锚定到外部可信存储(如 Windows 事件日志)。

---

#### DATA2-006 — 治理层证据记录在队列溢出时静默丢失

**模块**: Governance/DeepBase.Governance.EvidenceRecorder.pas
**严重度**: P0(可靠性缺陷)
**类型**: 数据丢失
**位置**: L265, L287

```pascal
FQueue.PushItem(LEntry);  // 丢弃返回值!
```

`LogAction`(L265)和 `LogBlocked`(L287)均调用 `FQueue.PushItem` 并丢弃其 `TWaitResult` 返回值。队列创建于 L132,容量为 1000,超时 50ms(`TThreadedQueue.Create(1000, 100, 50)`)。队列满或超时时,证据条目静默丢失——无异常、无日志、无回调。

**修复建议**: 检查 `PushItem` 的返回值。若返回 `wrTimeout`,应将条目推送到故障队列并立即调用故障回调,而不是丢弃。

---

### 可靠性/正确性 (Reliability/Correctness)

---

#### DATA2-007 — ConfigRegistrar.LoadFromDB 调用顺序错误导致 LoadGates 始终抛异常

**模块**: Governance/DeepBase.Governance.ConfigRegistrar.pas
**严重度**: P1(逻辑错误)
**类型**: 加载顺序缺陷
**位置**: L606-611

```pascal
procedure TConfigRegistrar.LoadFromDB;
begin
  LoadPurposes;   // L608
  LoadGates;      // L609 -- 校验 action_keys 存在性时 FActionGrid 尚未加载
  LoadActions;    // L610 -- 永远执行不到
end;
```

`LoadGates`(L520-531)校验每个 `Gate.ActionKeys` 是否在 `FActionGrid` 中注册。但 `LoadActions`(填充 `FActionGrid`)在 L610 调用,在 `LoadGates` 之后。因此任何 `action_keys` 非空的 gate 都会导致 `LoadFromDB` 抛出 `EConfigRegistrarError` 而失败。

**影响**: `LoadFromDB` 对任何启用了 action_keys 的配置数据库始终失败,系统无法加载治理配置。

**修复建议**: 将 `LoadActions` 移到 `LoadGates` 之前,或将 ActionKeys 验证移到后处理阶段。

---

#### DATA2-008 — Governance Lifecycle.Initialize 可被重复调用导致引擎实例泄漏

**模块**: Governance/DeepBase.Governance.Lifecycle.pas
**严重度**: P1(资源泄漏)
**类型**: 内存泄漏
**位置**: L169-236

```pascal
procedure TGovernanceLifecycle.Initialize;
begin
  if FMode = gmOff then Exit;
  FKeyResolver   := TKeyResolver.Create;    // 若第二次调用,旧实例泄漏
  FDueChecker    := TDueChecker.Create(FKeyResolver);
  FActionGrid    := TActionGrid.Create(FDueChecker);
  // ...
end;
```

无防重入检查。第二次调用 `Initialize` 时,所有 `:= T*.Create` 赋值静默覆盖前一次的对象指针而不释放,导致 `FKeyResolver`、`FDueChecker`、`FActionGrid`、`FGateResolver` 等实例全部泄漏。

**修复建议**: 在 `Initialize` 顶部添加 `if FInitialized then Exit` 守卫,或 `FreeAndNil` 旧实例再重建。

---

#### DATA2-009 — DeepFlow.Engine.SendSync 回调竞争条件

**模块**: DeepFlow/Source/Core/DeepFlow.Engine.pas
**严重度**: P1(线程安全)
**类型**: 竞争条件
**位置**: L397-435

`SendSync` 替换 `FOnMessageProcessed` 回调并在完成后恢复:

```pascal
OriginalCallback := FOnMessageProcessed;
FOnMessageProcessed := procedure(const AMsg: TDeepFlowMessage)
begin
  // ... 检查 correlationId ...
end;
SubmitMessage(AMessage);
// ... 等待响应 ...
FOnMessageProcessed := OriginalCallback;
```

若多线程同时调用 `SendSync`,会竞争设置和恢复 `FOnMessageProcessed`。无锁保护。这导致:
- 回调设置竞态:一个线程的响应可能被另一个线程的 `SendSync` 捕获
- 回调恢复竞态:恢复后可能留下错误的回调引用

**修复建议**: 使用 `TEvent` + 基于 `CorrelationId` 的响应字典,而非替换全局回调。

---

#### DATA2-010 — DeepFlow.Engine.RouteMessage 广播分发共享同一消息实例

**模块**: DeepFlow/Source/Core/DeepFlow.Engine.pas
**严重度**: P1(正确性)
**类型**: 共享状态
**位置**: L637-650

```pascal
for var RolePair in FRoles do
begin
  if RolePair.Value.CanHandle(AMessage.MsgType) then
  begin
    Response := RolePair.Value.HandleMessage(AMessage);  // 同一实例传给每个角色
    if Response <> nil then
      SubmitMessage(Response);
  end;
end;
```

广播时,同一 `AMessage` 实例依次传递给每个角色。若某个角色修改了消息内容(如设置 `Status`),后续角色看到的是被修改后的状态。不同角色之间产生意外耦合。

**修复建议**: 在广播循环中克隆消息,确保每个角色获得独立的副本。

---

#### DATA2-011 — ORM TMetadataCache 非线程安全

**模块**: Persistence/DeepBase.ORM.pas
**严重度**: P1(线程安全)
**类型**: 竞争条件
**位置**: L439-444

```pascal
class function TMetadataCache.GetMetadata(EntityType: TClass): TEntityMetadata;
begin
  if not FCache.TryGetValue(TypeInfo, Result) then
  begin
    Result := ExtractMetadata(EntityType);
    FCache.Add(TypeInfo, Result);  // 线程竞争:两个线程同时 Add
  end;
end;
```

"检查-执行"模式无锁保护。两线程同时解析同一未缓存类型时,会同时调用 `ExtractMetadata`,并且第二个 `FCache.Add` 会引发重复键异常(或静默覆盖导致字典泄漏元数据对象)。

**修复建议**: 添加 `TMonitor` 或 `TCriticalSection` 保护 `FCache` 的所有读写操作。使用双重检查锁定模式。

---

#### DATA2-012 — ORM 缺少脏写检测(无乐观并发控制)

**模块**: Persistence/DeepBase.ORM.pas
**严重度**: P2(可靠性)
**类型**: 数据完整性
**位置**: L1073-1075

```pascal
RowsAffected := RequireStorage.Execute(BuildUpdateSQL(Metadata), Params);
if RowsAffected = 0 then
  raise EConcurrencyException.Create('Entity was not found or has been modified');
```

仅检查 `RowsAffected = 0` 只能检测到行已被删除的情况,不能检测到并发修改。两个事务加载同一实体,事务 A 更新并提交,事务 B 使用旧值更新时静默覆盖 A 的更改。

**修复建议**: 引入版本列(如 `RowVersion` 或 `UpdatedAt`),在 UPDATE 的 WHERE 子句中检查版本,实现乐观并发控制。

---

#### DATA2-013 — Migrations 锁释放失败覆盖迁移成功状态

**模块**: Persistence/DeepBase.DB.Migrations.pas
**严重度**: P2(正确性)
**类型**: 状态误报
**位置**: L200-212

```pascal
if PgLockHeld then
begin
  try
    ReleasePostgreSQLLock(Connection);
  except
    on E: Exception do
    begin
      if Result.LastError = '' then
        Result.LastError := E.Message;
      Result.Success := False;  // 迁移已成功应用,但此处覆盖为失败
    end;
  end;
end;
```

迁移已全部成功应用,但 PostgreSQL 咨询锁释放失败时,`Result.Success` 被覆盖为 `False`。调用方看到 `AppliedCount > 0` 但 `Success = False` 后可能重试(虽然重试幂等,但产生不必要的告警和工作)。

**修复建议**: 锁释放失败不应影响 `Success` 状态;应记录警告而非覆盖。

---

#### DATA2-014 — SchemaAdapter 指纹前缀匹配导致碰撞

**模块**: Core/DeepBase.SchemaAdapter.pas
**严重度**: P1(架构缺陷)
**类型**: 数据损坏风险
**位置**: L243-249

```pascal
function TBaseSchemaAdapter.TryMatchFingerprint(const Fingerprint: string): Boolean;
begin
  for var Prefix in FSchemaFingerprintPrefixes do
    if Fingerprint.StartsWith(Prefix) then  // 前缀匹配,非精确匹配
      Exit(True);
  Result := False;
end;
```

使用 `StartsWith` 前缀匹配代替完整 SHA256 比较。指纹 `e4a7b3c9f1<完全不同的列结构>` 也会错误匹配 WeChat 3.9.x 适配器。结合 `TSchemaAdapterRegistry.TryResolve` 按注册顺序返回 **第一个** 匹配,前缀碰撞会静默选择错误适配器,导致列映射错误和数据损坏。

**修复建议**: 改为完整指纹匹配(`Fingerprint = Prefix`)或验证完整的 256 位十六进制字符串。

---

#### DATA2-015 — SchemaAdapter.Registry 非线程安全

**模块**: Core/DeepBase.SchemaAdapter.Registry.pas
**严重度**: P1(线程安全)
**类型**: 竞争条件
**位置**: L22-35, L51-59, L72-92

`FAdapters: TList<TVersionedAdapter>` 无同步机制。`Register` 修改列表,`TryResolve` 遍历列表。并发调用时,枚举过程中列表可能被重新分配,导致访问冲突。

**修复建议**: 为 `FAdapters` 的所有读写操作添加 `TCriticalSection` 保护。

---

#### DATA2-016 — SQLiteReader 无文件大小限制,可能导致内存耗尽

**模块**: DeepAxis/DeepBase.External.SQLiteReader.pas
**严重度**: P1(可靠性)
**类型**: 资源耗尽
**位置**: L227-242, L522-544

`OpenReadOnly` 无文件大小检查。`SafeQueryAsDict` 将所有行加载到内存,无 LIMIT 子句:

```pascal
while not Q.Eof do
begin
  var RowDict := TDictionary<string, Variant>.Create(Length(ColumnNames));
  RowList.Add(RowDict);
  Q.Next;
end;
```

恶意用户可指向大文件导致进程堆耗尽。

**修复建议**: 添加可配置的最大文件大小检查(如 >500MB 拒绝),并在 `SafeQueryAsDict` 中添加 LIMIT 参数。

---

#### DATA2-017 — WeChat 适配器指纹为占位符,适配器解析实际已禁用

**模块**: Core/DeepBase.SchemaAdapter.WeChat39x.pas, Core/DeepBase.SchemaAdapter.WeChat4x.pas
**严重度**: P1(功能缺陷)
**类型**: 功能不可用
**位置**: WeChat39x.pas:44, WeChat4x.pas:81

```pascal
// WeChat39x L44:
FSchemaFingerprintPrefixes := ['e4a7b3c9f1'];
// WeChat4x L81:
FSchemaFingerprintPrefixes := ['4x7f2a9b1c'];
```

注释为 "Replace with real prefix after probe run on production DB。" 这些是占位符,非真实 SHA256 前缀。适配器解析功能实际上已禁用——`TryResolve` 始终返回 `False`,`Resolve` 则抛出 `EUnsupportedSchemaVersion`。

**修复建议**: 运行实际指纹计算并替换占位符。在此之前,将适配器标记为 "experimental" 并文档说明。

---

#### DATA2-018 — FireDAC LLM 存储 TableHasColumn 表名直接拼接 SQL

**模块**: Persistence/DeepBase.Persistence.LLM.FireDAC.pas
**严重度**: P1(安全缺陷)
**类型**: SQL 注入
**位置**: L227

```pascal
DataSet := OpenDataSet(Format('SELECT * FROM %s WHERE 1 = 0', [TableName]), []);
```

表名 `TableName` 直接 `Format` 拼接进 SQL,无任何 `TSQLUtils.ValidateIdentifier` 调用。若从外部传入,是 SQL 注入向量。

**修复建议**: 拼接前调用 `TSQLUtils.ValidateIdentifier(TableName)`。

---

#### DATA2-019 — MRU Upsert SELECT-then-INSERT/UPDATE 无事务(TOCTOU 竞态)

**模块**: Persistence/DeepBase.Persistence.MRU.FireDAC.pas
**严重度**: P2(可靠性)
**类型**: 竞争条件
**位置**: L70-105

SELECT 检查存在性(L73)与后续 INSERT(L89)/UPDATE(L97)之间无事务保护。并发线程可同时检查到不存在、同时执行 INSERT 导致唯一约束违反,或一个线程覆盖另一个线程的插入。

**修复建议**: 将 SELECT + INSERT/UPDATE 包装在 `StartTransaction/Commit/Rollback` 中。

---

#### DATA2-020 — Governance ConfigLoader 路径遍历风险

**模块**: Governance/DeepBase.Governance.ConfigLoader.pas
**严重度**: P2(安全缺陷)
**类型**: 路径遍历
**位置**: L85-93

```pascal
function TConfigLoader.FileContent(const AFileName: string): string;
begin
  LPath := TPath.Combine(FConfigDir, AFileName);
  if TFile.Exists(LPath) then
    Result := TFile.ReadAllText(LPath, TEncoding.UTF8)
  else
    Result := '';
end;
```

`FConfigDir` 由构造函数传入(L74),无任何验证。攻击者可通过控制 `FConfigDir` 使用 `../` 遍历读取任意 JSON 文件。

**修复建议**: 将 `FConfigDir` 规范化为绝对路径,并验证解析后的文件路径在 `FConfigDir` 内。

---

#### DATA2-021 — Governance Accountability 中 user_id 来自不受信任的调用方上下文

**模块**: Governance/DeepBase.Governance.Accountability.pas
**严重度**: P2(安全缺陷)
**类型**: 身份验证绕过
**位置**: L186-194

```pascal
LActorKey := AContext.GetValue<string>('user_id', '');
```

`AContext` 中的 `user_id` 是调用方提供的用户控制输入。攻击者可提供任意 `user_id` 值来绕过 actor 存在性检查。检查仅验证 actor key 是否注册,不验证是否与已验证的会话匹配。

**修复建议**: `AContext` 中的 `user_id` 应仅用于关联/显示目的,实际的 actor 身份应从认证会话中获取。

---

#### DATA2-022 — Governance ComponentAdapter DFM 文件解析路径遍历

**模块**: Governance/DeepBase.Governance.ComponentAdapter.pas
**严重度**: P2(安全缺陷)
**类型**: 路径遍历
**位置**: L170-178

`ParseFile` 接受 `AFilePath` 不进行规范化/验证。攻击者可传递 `../../Config/settings.dfm` 读取任意文件。

**修复建议**: 规范化并验证解析后的路径在预期的 DFM 目录内。

---

#### DATA2-023 — Governance 观察/强制模式可通过直接修改数据库绕过

**模块**: Governance/DeepBase.Governance.ConfigRegistrar.pas, Governance/DeepBase.Governance.Lifecycle.pas
**严重度**: P2(安全缺陷)
**类型**: 权限绕过
**位置**: ConfigRegistrar.pas L631-650, Lifecycle.pas L199-207

治理模式以明文存储在 SQLite 的 `governance_config` 表中。对数据库有写访问权限的攻击者可直接 `UPDATE governance_config SET value='observe' WHERE key='mode'`,禁用所有强制的权限门禁。

**修复建议**: 对模式设置添加完整性保护(签名或 HMAC),或至少确保模式更改需要重启才能生效。

---

#### DATA2-024 — 火DAC Manager CountCoreTables 使用 QuotedStr 代替标识符引号

**模块**: Persistence/DeepBase.Persistence.Manager.FireDAC.pas
**严重度**: P2(代码质量)
**类型**: 不正确引用
**位置**: L99-113

`BuildQuotedList` 对表名使用 `QuotedStr()`(值引用),而非标识符引用。表名来自内部常量数组,实际无注入风险,但模式不正确。

**修复建议**: 对表名使用 `AnsiQuotedStr(TableName, '"')` 或 `TSQLUtils.QuoteIdentifier`。

---

#### DATA2-025 — Authorization FireDAC ReplaceRolePermissions 在调用方拥有的连接上启动事务

**模块**: Persistence/DeepBase.Persistence.Authorization.FireDAC.pas
**严重度**: P2(兼容性)
**类型**: 嵌套事务风险
**位置**: L590

```pascal
Connection.StartTransaction;  // 若调用方已有活动事务,在 SQLite 中会静默嵌套
```

`StartTransaction` 在共享的 `FConnection` 上调用。如果调用方已在此连接上有活动事务,FireDAC 行为取决于驱动——SQLite 可能静默使用 SAVEPOINT 嵌套,PG 可能抛出异常。

**修复建议**: 检查 `Connection.InTransaction` 并根据情况使用保存点。

---

### 架构/设计 (Architecture/Design)

---

#### DATA2-026 — DoQry 预编译语句池键使用原始指针,存在悬空指针风险

**模块**: Persistence/DeepBase.DB.DoQry.pas
**严重度**: P1(可靠性)
**类型**: 悬空指针
**位置**: L475-478, L563-596, L1709-1744

```pascal
function MakePreparedKey(Conn: TFDConnection; const SQL: string): string;
begin
  Result := IntToHex(NativeInt(Conn), 16) + '_' + IntToStr(SimpleHash(SQL));
end;
```

键使用 `NativeInt(Conn)`(原始 TFDConnection 指针)。连接释放后地址可被新连接重用。虽有 `UniDbSweepConnectionFromPool` 在连接销毁时清除,但调用方可能忘记调用它,且 "释放-重用" 窗口期仍可匹配错误连接。

L591-595 对悬空条目的处理仅在被查找触发时才执行 —— 没有主动检测废弃的机制。

**修复建议**: 使用单调递增的连接 ID(而非指针地址)作为键;或每次分配连接时生成唯一标识并注入为连接参数。

---

#### DATA2-027 — DeepFlow Engine 状态机缺少 esError 状态恢复路径

**模块**: DeepFlow/Source/Core/DeepFlow.Engine.pas
**严重度**: P1(设计缺陷)
**类型**: 状态不可恢复
**位置**: L31-39, L204-259

```pascal
TEngineState = (
  esUninitialized,
  esInitializing,
  esReady,
  esRunning,
  esStopping,
  esStopped,
  esError
);
```

`esError` 状态在引擎中已定义但无恢复路径。`Start`(L228)仅接受 `esReady`。进入 `esError` 后,无 `Reset`/`Recover` 方法可将引擎恢复到有效状态。`ProcessMessage`(L589-607)异常捕获未更新状态为 `esError`。

**修复建议**: 在 `Stop`/`Start` 中处理 `esError` 状态,添加 `Reset` 方法,并在关键异常时设置 `esError`。

---

#### DATA2-028 — DoQry 直通 SQL(IsDirectSQL)绕过参数化安全性

**模块**: Persistence/DeepBase.DB.DoQry.pas
**严重度**: P1(设计缺陷)
**类型**: 安全检查旁路
**位置**: L935-974, L1009-1012

`IsDirectSQL` 允许调用方通过传递以 SELECT/INSERT/UPDATE/DELETE/WITH/REPLACE 开头的字符串作为 `ProcName` 来执行即兴 SQL。该字符串直接用作 SQL 文本,无参数化:

```pascal
if IsDirectSQL(ProcName) then
begin
  Result := ProcName;  // 直接作为 SQL 返回
  Exit;
end;
```

虽然 `BindJsonParams` 对显式参数进行绑定,但 SQL 主体本身是完全动态的。任何将用户控制数据作为 `ProcName` 传递的代码路径都会执行任意 SQL。

**修复建议**: 将直通 SQL 限制为内部调用,或要求调用方显式 opt-in 并警告使用风险。考虑在直通 SQL 上添加正则约束(仅允许单一语句)。

---

#### DATA2-029 — ORM DefaultValue 直接拼接到 DDL

**模块**: Persistence/DeepBase.ORM.pas
**严重度**: P1(设计缺陷)
**类型**: SQL 注入(DDL)
**位置**: L1282-1285

```pascal
else
  // 数值/日期等类型默认按原样拼接,由调用方保证合法性
  SQL.Append(' DEFAULT ').Append(Col.DefaultValue);
```

非字符串类型的 `DefaultValue` 属性值直接拼接到 CREATE TABLE DDL 中。注释承认 "由调用方保证合法性",但无运行时验证。

**修复建议**: 对数值/日期类型执行严格的正则验证,或仅允许预定义字面量值。

---

#### DATA2-030 — WeChat 4x 适配器 IsSender 正则匹配可能误判

**模块**: Core/DeepBase.SchemaAdapter.WeChat4x.pas
**严重度**: P2(正确性)
**类型**: 数据误读
**位置**: L38-56

```pascal
var Match := TRegEx.Match(Source, '<IsSender>(\d)</IsSender>', [roIgnoreCase]);
```

正则无锚点(no `^`/`$`)。若 `source` 列包含多个 `<IsSender>` 标签(例如来自拼接的 XML 片段),正则匹配第一个出现。若第一个被伪造,方向被错误识别。

**修复建议**: 验证匹配的上下文或限制只能匹配一次。考虑针对恶意输入的正则拒绝服务保护。

---

#### DATA2-031 — 治理层 JsonLogic 无表达式注册时校验

**模块**: Governance/DeepBase.Governance.JsonLogic.pas, Governance/DeepBase.Governance.JsonLogicEvaluator.pas
**严重度**: P2(设计缺陷)
**类型**: 输入验证缺失
**位置**: JsonLogicEvaluator.pas L73-91, JsonLogic.pas L301-306

- 表达式仅在求值时校验,注册/加载时不校验。格式错误或计算昂贵的表达式在运行时才被捕获(然后被 error-handling 静默吞没)。
- `OpVar` 空路径(L301-306)返回整个 `AData` 的克隆,可能将敏感上下文数据暴露给求值结果。

**修复建议**: 在注册时添加表达式验证(如 `ConfigRegistrar.RegisterGate` 或 `Schema.pas`)。验证表达式不包含递归空路径 `var`。

---

#### DATA2-032 — 治理层验证规则 8/15 为骨架空实现,CanRelease 产生虚假安全感

**模块**: Governance/DeepBase.Governance.Validation.pas
**严重度**: P3(文档/覆盖)
**类型**: 功能不完整
**位置**: L435-475

```pascal
function TGateValidationEngine.RuleINV8_DuplicateKey: TArray<TValidationIssue>;
begin
  Result := nil;  // 骨架
end;
```

八个验证规则(INV-8 至 INV-15)是返回 `nil` 的骨架存根。`CanRelease` 仅检查 `CountBySeverity(vsSevere) = 0`,在 `vsSevere` 规则未注册时返回 "通过"。关键检查如重复键、循环路由、风险级别不匹配完全静默。

**修复建议**: 要么实现全部 15 条规则后再暴露 `CanRelease`,要么明确文档说明治理验证仅覆盖 7/15 的不变检查。

---

## 上一轮修复验证

| 上一轮 ID | 模块 | 问题 | 当前状态 |
|-----------|------|------|----------|
| PERS-001 | DB.Pool | Release 中 SetEvent 在锁外,与 csValidating 交互 | **已修复**: SetEvent 现位于 FLock 内(L753-761);注释明确说明 fix;FindAvailableConnection 正确仅检查 csIdle;维护线程在锁内设置 csValidating |
| PERS-002 | DB.StatusMachine | ValidateIdentifier 不支持 schema.table | **已修复**: L191-229 重写为支持最多一个点的 schema.table 格式,分段校验标识符合法性 |
| PERS-003 | DB.JobQueue | 无最大重试/指数退避/DLQ | **已修复**: 完整实现包括 DLQ 表、DEFAULT_JOB_MAX_RETRIES=5、ComputeBackoffSeconds(BASE=5 CAP=300)、Requeue 默认改为 False(L107),原子 DLQ 转移(L964-1017),全套 DLQ API |
| PERS-004 | DB.Factory | CreateConnectionFromProfile 创建临时池 | **部分修复**: L245 注释建议使用全局池或维护内部池,但实际代码未变更 |

## 审查说明

### 审查方法
静态代码分析,全文阅读 70+ 个文件。未执行编译或动态分析。覆盖:
- Persistence/ 全部 38 个 .pas
- Governance/ 全部 18+ 个 .pas
- DeepFlow/ 全部 12 个 .pas
- Core/DeepBase.Schema 系列 6 个 .pas
- DeepAxis/ 2 个 .pas

### 未覆盖事项
- 编译后动态分析(无法在静态分析中检测运行时竞态)
- 与第三方库的交互(如 FireDAC 驱动层行为)
- 性能基准测试(非代码审查范畴)
- DPK 包依赖声明的编译验证

## 优先级排序

1. **DATA2-001/002 (P0)**: ORM SQL 注入 — 最直接的安全风险
2. **DATA2-003/004 (P0)**: BCryptDecrypt 密钥残留 + 临时文件泄露
3. **DATA2-005/006 (P0)**: 治理证据链完整性丢失
4. **DATA2-055 (P0)**: Pool 验证查询超时导致池永久收缩
5. **DATA2-056 (P0)**: AutoRefreshConfig 共享连接多线程竞争
6. **DATA2-007 (P1)**: LoadFromDB 死路径
7. **DATA2-008 (P1)**: Lifecycle 泄漏
8. **DATA2-009/010 (P1)**: DeepFlow 引擎正确性缺陷
9. **DATA2-011 (P1)**: ORM 竞争条件
10. **DATA2-014/015 (P1)**: SchemaAdapter 碰撞/线程安全
11. **DATA2-016/017 (P1)**: SQLiteReader 资源耗尽/适配器禁用
12. **DATA2-018 (P1)**: FireDAC LLM SQL 注入
13. **DATA2-026 (P1)**: DoQry 预编译池键使用裸指针
14. **DATA2-033/034 (P1)**: DeepFlow 消息/线程泄漏
15. **DATA2-046/047 (P1)**: JobQueue PG 路径缺少事务原子性
