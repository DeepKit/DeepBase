# DeepBase Persistence 持久层架构审查报告

- **审查日期**：2026-08-24
- **审查范围**：`d:\_Progs\02Business\DeepBase\Persistence\` 全部 32 个 `.pas` 单元（约 15,000+ 行）
- **审查方式**：5 组并行深度审查（连接池 / DoQry+Factory+SQLLogger+Guardian / ORM+Migrations+JobQueue / FireDAC 适配器 A 组 / FireDAC 适配器 B 组），主审对全部 🔴 级发现及关键 🟡 级发现逐条读取原文复核行号与代码片段（复核样本 100% 属实）
- **约定基准**：CLAUDE.md + .editorconfig（2 空格缩进、DeepBase.Exceptions 异常体系、try/finally + FreeAndNil、FireDAC SQL 参数化、`{$IFDEF MSWINDOWS}` 包裹 Windows API）
- **声明**：只报告，未修改任何文件
- **行号基准**：以 Read 工具读取的实际文件行号为准（部分文件行数与早期统计有出入，因早期统计漏计空行）

## 总体统计

| 严重度 | 数量 | 说明 |
|---|---|---|
| 🔴 崩溃或数据损坏 | 7 | Pool/ConnectionPool 生命周期、DoQry×3、StatusMachine 悬垂引用、IntentClarification 区域设置 |
| 🟡 功能缺陷 | 44 | 含 SQLite 方言与双后端不匹配、吞异常、线程安全、事务结构 |
| 🔵 优化建议 | 55 | 性能、防御性、约定一致性 |
| 存疑区 | 16 | 单列于文末，未混入确认列表 |

**优先修复 Top 5**：
1. 🔴 Pool.Shutdown 超时强制清池 → use-after-free（P-1）
2. 🔴 DoQry 字符串参数静默 Trim → 存储数据损坏（Q-1）
3. 🔴 DoQry Sweep 释放飞行中查询 → 双重释放（Q-3）
4. 🟡 Guardian 误隔离 + 备份回退 → 当日数据静默回退（G-1）
5. 🟡 DoQry INFO→llDebug 映射 → 成功查询参数批量落日志（Q-10）

---

## 🔴 崩溃或数据损坏（7 项，全部经原文复核）

### P-1. Shutdown 排空超时后强制 FPool.Clear，销毁仍被借出（csInUse）的连接 → use-after-free / 堆损坏
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:1066-1092`（已复核）
- **原始代码**：
```pascal
  // Drain: wait up to AcquireTimeoutMs for active connections to be released.
  DrainStart := Now;
  repeat
    HasActive := False;
    FLock.Enter;
    try
      for I := 0 to FPool.Count - 1 do
        if FPool[I].State = csInUse then
        begin
          HasActive := True;
          Break;
        end;
    finally
      FLock.Leave;
    end;

    if HasActive then
      Sleep(50);
  until (not HasActive) or
        (MilliSecondsBetween(Now, DrainStart) >= FConfig.AcquireTimeoutMs);

  // Now clear all connections under lock.
  FLock.Enter;
  try
    FInitialized := False;
    FPool.Clear;
```
- **问题**：drain 只等待 `AcquireTimeoutMs`（默认 30 秒）。超时后 `FPool.Clear`（TObjectList OwnsObjects=True）销毁**所有**连接，含仍在 `csInUse` 的。借用线程随后：① 继续在已 free 的 `TFDConnection` 上执行 SQL → AV/堆损坏；② 之后调用 `TPooledConnection.Release` 向已释放对象写 `FState`、调用即将析构的 `FPool.FLock.Enter` → 堆损坏。第 724 行析构中的 `TInterlocked.Exchange(Pointer(FConnection), nil)` 只防池内双重释放，不保护借用人。
- **触发条件**：Shutdown（含析构、`TPoolManager.ShutdownAll`）时有任意 worker 持有连接超过 30 秒（长事务、慢查询、死循环等）。
- **建议修复**：
```pascal
  FLock.Enter;
  try
    FInitialized := False;
    // 只销毁未借出的连接; 借出中的留给调用方 Release 兜底或泄漏告警
    for I := FPool.Count - 1 downto 0 do
      if FPool[I].State <> csInUse then
        FPool.Delete(I);
    if FPool.Count > 0 then
      DoPoolEvent(peConnectionLeakDetected,
        Format('Shutdown drained with %d connection(s) still in use; deferred', [FPool.Count]));
  finally
    FLock.Leave;
  end;
```
（注：析构中随后的 `FreeAndNil(FPool)` 仍会释放遗留 in-use 连接——进程退出期可接受，但应在文档明确"调用方必须先停止 worker 再销毁池"。）

### CP-1. 析构与并发 Release/Acquire 竞争：FreeAndNil(FPool) 后 nil 解引用 + 借出中连接被强制释放
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.ConnectionPool.pas:204-216`（已复核；竞争点在 355-360 等）
- **原始代码**：
```pascal
destructor TDBConnectionPool.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FPool);
  finally
    FLock.Leave;
  end;

  FreeAndNil(FLock);
  FreeAndNil(FAvailableEvent);
  inherited;
end;
```
- **问题**（类头声称 "All public methods are thread-safe"，以下场景违背该承诺）：
  - 场景 A：`FPool` 释放时 `TPooledConnection.Destroy`（160-169 行）会 `Close`+`Free` 正在使用的 `TFDConnection`——持有借出连接的 worker 随后使用 → use-after-free。
  - 场景 B：线程在 `Release`/`AcquireTimeout`/`GetActiveCount` 中阻塞于 `FLock.Enter`，Destroy 释放锁后继续执行 `FPool.Count`——此时 `FPool` 已为 **nil** → AV。
  - 另：Destroy 无任何 drain/等待借出连接归还的逻辑。
- **触发条件**：任何 worker 线程仍持连接或正在调用池方法时销毁池。
- **建议修复**（该类已 deprecated，最佳方案是迁移后删除本单元；若需保留）：
```pascal
destructor TDBConnectionPool.Destroy;
var
  DrainStart: TDateTime;
  HasActive: Integer;
begin
  DrainStart := Now;
  repeat
    HasActive := 0;
    FLock.Enter;
    try
      for I := 0 to FPool.Count - 1 do
        if FPool[I].InUse then Inc(HasActive);
    finally
      FLock.Leave;
    end;
    if HasActive > 0 then Sleep(50);
  until (HasActive = 0) or (MilliSecondsBetween(Now, DrainStart) >= 30000);

  FLock.Enter;
  try
    FreeAndNil(FPool);
    FDestroyed := True;  // 新增布尔字段, Release/AcquireTimeout 入口检查后直接返回
  finally
    FLock.Leave;
  end;
  // ...
end;
```

### Q-1. 字符串参数被静默 Trim —— 存储数据损坏
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:849`（已复核）
- **原始代码**：
```pascal
        S := Trim(Pair.JsonValue.Value);
```
（随后 868 行 `P.AsWideString := S` 将 Trim 后的值写入数据库）
- **问题**：绑定字符串参数前先 `Trim`，随后将 Trim 后的值写入数据库。所有带前导/尾随空格的字符串参数（姓名、地址、备注、格式化编码、含空格的口令/token）被静默篡改，且无任何注释说明是有意行为。Trim 本意应只是为 GUID 检测服务，却污染了绑定值。
- **触发条件**：任何 `ParamsJson` 中首尾含空格的字符串值，如 `{"name": "  双空格  "}`。
- **建议修复**：
```pascal
        S := Pair.JsonValue.Value;   // 保留原始空白，不做静默修改
        if S = '' then
          P.AsString := S
        else
        begin
          // GUID 检测使用 Trim 后的副本，仅用于判断，不改变绑定值
          if (Length(Trim(S)) = 36) and ...
```

### Q-2. UniDbBeginTx 未校验 nil 连接 —— 空指针崩溃
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:1318-1334`（已复核）
- **原始代码**：
```pascal
constructor TUniTransaction.Create(const Ctx: TUniQueryContext);
begin
  inherited Create;
  FCtx := Ctx;
  FCommitted := False;
  FRolledBack := False;
  FUseSavepoint := Assigned(FCtx.Connection) and FCtx.Connection.InTransaction;
  FSavepointName := '';

  if FUseSavepoint then
  begin
    FSavepointName := NewSavepointName;
    ExecTxSql('SAVEPOINT ' + FSavepointName);
  end
  else
    FCtx.Connection.StartTransaction;
end;
```
- **问题**：`Ctx.Connection = nil` 时 `FUseSavepoint = False`，落入 else 分支对 nil 引用调用 `StartTransaction` → AV 崩溃。`UniDbRunInTx` 直接暴露此公共 API，不经过 `LoadQuerySQL` 的连接检查（行 1112），无前置防护。
- **触发条件**：调用方传入 `Connection = nil` 的 Context（配置错误、测试桩、初始化顺序问题）调用 `UniDbBeginTx` / `UniDbRunInTx`。
- **建议修复**：
```pascal
constructor TUniTransaction.Create(const Ctx: TUniQueryContext);
begin
  inherited Create;
  if not Assigned(Ctx.Connection) then
    raise EDeepBaseDbError.Create('Transaction requires an active connection',
      '', '', '', Ctx.DBType, Ctx.CorrelationId, DOQRY_ERR_CONNECTION);
  FCtx := Ctx;
  // ...
```

### Q-3. Sweep/Clear 不检查 InUseCount —— 飞行中 TFDQuery 被释放（use-after-free + 双重释放）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:1788-1801`（已复核）
- **原始代码**：
```pascal
    KeysToRemove := TList<string>.Create;
    try
      for Pair in GPreparedPool do
        if Assigned(Pair.Value) and (Pair.Value.Connection = Conn) then
          KeysToRemove.Add(Pair.Key);
```
- **问题**：`UniDbSweepConnectionFromPool` 无条件移除该连接的所有条目（不检查 `InUseCount`），`GPreparedPool.Remove` 触发 `doOwnsValues` → `TPreparedEntry.Destroy` → `FreeAndNil(FQuery)` 释放**正在执行中**的 TFDQuery。工作线程随后在 `ReleaseQuery`（行 695-696）中因 `TryGetValue` 失败走兜底 `Q.Free` → **双重释放**。对比 `EvictOnePreparedLruEntry`（行 542-543）有 `InUseCount > 0 then Continue` 防护，此处缺失。`UniDbClearPreparedStatements`（行 1742-1745）同样无条件 `Clear`。已核实 `DeepBase.DB.Pool.pas:731` 在 `TPooledConnection.Destroy` 中真实调用 Sweep，不是死代码。
- **触发条件**：连接池因 MaxLifetime 失效/强制作废连接时，另一线程仍持有该连接上的池化查询（InUseCount>0，如慢查询执行中）；或运行时调用 `UniDbClearPreparedStatements` 时有并发查询在飞。
- **建议修复**：
```pascal
      for Pair in GPreparedPool do
        if Assigned(Pair.Value) and (Pair.Value.Connection = Conn)
          and (Pair.Value.InUseCount = 0) then      // 与 LRU 逐出策略对齐
          KeysToRemove.Add(Pair.Key);
```
`UniDbClearPreparedStatements` 同理：InUseCount>0 的条目应跳过（或断言无飞行查询再清空）。

### SM-1. GetTableDef 返回的 Def 引用在锁外使用，可被并发释放（use-after-free）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.StatusMachine.pas:371-372`（Transit，已复核）与 `:477-480`（Heartbeat 同模式）
- **原始代码**：
```pascal
  Def := GetTableDef(TableName);
  ValidateIdentifier(TableName);
```
（388 行随后锁外使用：`Rule := Def.FindTransition(CurrentStatus, NewStatus);`）
- **问题**：`GetTableDef` 在 `FLock` 内从 `FTables` 取出 `TTableStateDef` 引用后立即解锁并返回裸引用。而 `RegisterTable` 中的 `FTables.AddOrSetValue`（行 274，字典带 `doOwnsValues`）覆盖同 key 时会 **Free 旧 Def**，`Clear`（行 177）会释放全部 Def。线程 A 在 Transit/Heartbeat 中持有 Def 引用的同时，线程 B 重新注册同一表名或调用 Clear，旧 Def 被释放，线程 A 随后访问 `Def.FindTransition` / `Def.HeartbeatIntervalSec` 即为悬垂引用访问。
- **触发条件**：多线程使用 TStatusMachine，且运行期发生 `RegisterTable` 重复注册同表 或 `Clear`，与正在执行的 `Transit`/`Heartbeat` 竞态。
- **建议修复**（读取后克隆所需数据，或在锁内完成查找；最简单的是契约约定）：
```pascal
  // 方案A: 锁内拷贝快照
  FLock.Enter;
  try
    if not FTables.TryGetValue(NormalizeTableName(TableName), Def) then
      raise EInvalidOperationException.CreateFmt(
        'Status machine table is not registered: %s', [TableName]);
    // 锁内拷贝 Transitions 快照/所需字段, 锁外仅使用快照
  finally
    FLock.Leave;
  end;
```
或方案 B：类注释明确契约 `RegisterTable/Clear 仅允许初始化阶段单线程调用`。

### IC-1. StrToFloatDef 区域设置依赖导致信任度数据静默损坏
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.IntentClarification.Storage.pas:346`（已复核；同样模式 351、356）
- **原始代码**：
```pascal
    LJsonVal := LObj.GetValue('trustLevel');
    if LJsonVal <> nil then
      Result.TrustLevel := StrToFloatDef(LJsonVal.Value, 0.5)
```
- **问题**：写入侧 `RapportToJson`（行 301-303）用 `TJSONNumber.Create(AProfile.TrustLevel)` 序列化，JSON 输出是点分隔（`"trustLevel":0.7`）。读取侧 `StrToFloatDef` 按**用户当前区域设置**解析——在小数分隔符为逗号的区域（de-DE/fr-FR/ru-RU 等），`"0.7"` 解析失败，**静默回落到默认值 0.5**。用户画像的信任度/熟悉度/偏好深度在非点分隔区域下全部失真且无任何报错；且 save→load→save 循环会把失真值写回数据库，损坏持久化。
- **触发条件**：操作系统区域设置的小数分隔符非 `.`，加载任一已保存的 rapport profile。
- **建议修复**：
```pascal
    LJsonVal := LObj.GetValue('trustLevel');
    if LJsonVal is TJSONNumber then
      Result.TrustLevel := TJSONNumber(LJsonVal).AsDouble
    else
      Result.TrustLevel := 0.5;
```
（三处同改；或最低限度 `StrToFloatDef(LJsonVal.Value, 0.5, TFormatSettings.Invariant)`。）

---

## 🟡 功能缺陷（45 项）

### 一、DeepBase.DB.Pool.pas（9 项）

#### P-2. Shutdown 的 5 秒有界等待是假象：FreeAndNil(FMaintenanceThread) 内部 TThread.Destroy 仍会无界 WaitFor
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:1051-1064`
- **原始代码**：
```pascal
    {$IFDEF MSWINDOWS}
    if Winapi.Windows.WaitForSingleObject(FMaintenanceThread.Handle, 5000) = WAIT_TIMEOUT then
    begin
      {$IFDEF DEBUG}
      Winapi.Windows.OutputDebugString('DeepBase.DB.Pool: maintenance thread did not exit within 5 s during shutdown');
      {$ENDIF}
    end
    else
      FMaintenanceThread.WaitFor;
    {$ELSE}
    FMaintenanceThread.WaitFor;
    {$ENDIF}
    FreeAndNil(FMaintenanceThread);
```
- **问题**：已核实 Delphi 13.1 `System.Classes.pas`（TThread.Destroy → ShutdownThread → Terminate + WaitFor，无界）。WAIT_TIMEOUT 分支只打日志后仍执行 `FreeAndNil(FMaintenanceThread)` → 内部无界 `WaitFor`。DATA2-057 注释声称 "stuck maintenance thread cannot hang Shutdown indefinitely" 不成立。
- **触发条件**：维护线程卡在 `Validate`（最长 CommandTimeoutSec×1000 或 5s）或 `CreateConnection`（PG LoginTimeout 最长 30s）等超过 5 秒。
- **建议修复**：
```pascal
    if Winapi.Windows.WaitForSingleObject(FMaintenanceThread.Handle, 5000) = WAIT_TIMEOUT then
      FMaintenanceThread := nil   // 故意泄漏 TThread 包装对象, 避免析构内部无界 WaitFor 重新挂起 Shutdown
    else
      FreeAndNil(FMaintenanceThread);
```

#### P-3. Invalidate 后 Release 会"复活"已标记无效的连接
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:766` 与 `791-796`
- **原始代码**：
```pascal
    FPool.FLock.Enter;
    try
      FState := csIdle;
```
```pascal
procedure TPooledConnection.Invalidate;
begin
  FState := csInvalid;
```
- **问题**：`Release` 无条件把状态覆写回 `csIdle`。调用方按池 API 常见惯例对故障连接先 `Invalidate` 再 `Release` 后，若该连接 TCP 未断（`Connected=True`，如会话状态已损坏但链路活着），`GetIsValid` 通过，坏连接会被再次借出。
- **触发条件**：Invalidate → Release 序列，且故障表现为"会话坏但连接仍 Connected"。
- **建议修复**：
```pascal
    FPool.FLock.Enter;
    try
      if FState <> csInvalid then
        FState := csIdle;  // 保持无效标记, 交给维护线程/RecycleAllConnections 回收
      FLastUsedAt := Now;
```

#### P-4. ResetConnectionState 注释宣称重置隔离级别，实际只重置了 AutoCommit（BUG-431 意图未完全落地）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:818-820`
- **原始代码**：
```pascal
    // 2. 重置事务隔离级别到读取当前配置 (FireDAC 在下次 BeginTransaction 时按
    //    TxOptions 应用; 此处确保 TxOptions 反映池配置, 调用方临时改隔离级别后复位).
    FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit;
```
- **问题**：调用方临时修改 `TxOptions.IsolationLevel`（如提升到 Serializable）后归还，隔离级别会泄漏给下一个借用者——这正是第 758-762 行注释声称已修复的场景。另：回滚残留事务用 `peConnectionReleased` 事件类型（第 815 行）语义不当。
- **触发条件**：调用方修改隔离级别后归还连接，下一个借用者继承。
- **建议修复**：
```pascal
    FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit;
    FConnection.TxOptions.IsolationLevel := FPool.FDefaultIsolationLevel; // 建连时快照的默认值, 池内新增字段
```

#### P-5. TPooledConnection.Release 无状态守卫：双重 Release 会回滚他人进行中的事务
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:753-763`
- **原始代码**：
```pascal
procedure TPooledConnection.Release;
begin
  if Assigned(FPool) then
  begin
    var LUseTime := UseTime;
    // DATA-R3-001 (BUG-431): 归还前必须复位连接状态, 否则下个借用者继承脏连接
    ...
    ResetConnectionState;
    FPool.FLock.Enter;
```
- **问题**：`ResetConnectionState`（含 `Rollback`）在取锁前无条件执行。若同一 `TPooledConnection` 被二次 Release（第二次时连接可能已被其他线程借走、状态 csInUse、正在事务中），会回滚**他人**进行中的事务 → 数据丢失；且 `TotalReleases` 双计、`SetEvent` 虚发。
- **触发条件**：调用方（bug 代码或异常路径）对同一连接重复调用 Release。
- **建议修复**：
```pascal
  FPool.FLock.Enter;
  try
    if FState <> csInUse then
      Exit;                      // 双重 Release / 未借出: 拒绝
    FState := csValidating;      // 中间态, 阻止 FindAvailableConnection 取走
  finally
    FPool.FLock.Leave;
  end;
  ResetConnectionState;          // 锁外做连接级复位
  FPool.FLock.Enter;
  try
    FState := csIdle;            // 再置空闲并 SetEvent
```

#### P-6. TPoolManager.RegisterPool 覆盖同名池时静默释放旧池（doOwnsValues）→ 悬垂引用
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:2066-2071`（字典创建于 1990 行：`FPools := TObjectDictionary<string, TUniConnectionPool>.Create([doOwnsValues]);`）
- **原始代码**：
```pascal
  FLock.Enter;
  try
    FPools.AddOrSetValue(Name, Pool);
  finally
    FLock.Leave;
  end;
```
- **问题**：`AddOrSetValue` 替换旧值时，`doOwnsValues` 使旧 `TUniConnectionPool` 被 Free。仍持有旧池引用的线程 → use-after-free。且旧池的 `Shutdown`（最长 5s + 30s drain）在 `TPoolManager.FLock` 内随析构执行，阻塞所有管理器操作。
- **触发条件**：对已存在名称重复 RegisterPool，且旧池仍被使用。
- **建议修复**：替换前先 `ExtractPair` 取回旧值所有权（不释放），在锁外对其 `Shutdown` 后交还调用方处置，或直接抛 `EInvalidOperationException` 拒绝覆盖。

#### P-7. TPoolManager.RemovePool 静默释放池对象，外部引用悬垂
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:2080-2087`
- **原始代码**：
```pascal
  FLock.Enter;
  try
    if FPools.TryGetValue(Name, Pool) then
    begin
      if GDefaultPool = Pool then
        TInterlocked.Exchange(Pointer(GDefaultPool), nil);
      FPools.Remove(Name);
```
- **问题**：`TObjectDictionary.Remove` 在 doOwnsValues 下释放值。惯用法 `Pool := TPoolManager.GetPool('x'); TPoolManager.RemovePool('x'); Pool.GetConnection;` → AV。
- **触发条件**：移除后继续使用原引用。
- **建议修复**：改用 `FPools.ExtractPair(Name)`（归还所有权、不释放），由调用方决定 Shutdown/Free；或在方法注释中明示所有权转移。

#### P-8. 建连异常被吞，最终抛出误导性的超时异常（违背仓库"不吞异常"约定）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:1509-1512`
- **原始代码**：
```pascal
        except
          on E: Exception do
            DoPoolEvent(peConnectionInvalidated, 'Failed to create connection: ' + E.Message);
        end;
```
- **问题**：数据库完全不可达时，`TryGetConnection` 每秒静默重试建连直至 30 秒超时，`GetConnection` 抛 `EConnectionTimeoutException`——root cause 丢失，只在事件流里留痕；且 30 秒内每秒一次真实建连尝试（网络风暴）。应区分"池满等待"与"建连失败"。
- **触发条件**：DB 宕机/网络分区期间的 GetConnection。
- **建议修复**：
```pascal
        except
          on E: Exception do
          begin
            DoPoolEvent(peConnectionInvalidated, 'Failed to create connection: ' + E.Message);
            raise EPoolException.CreateFmt('Failed to create pooled connection: %s', [E.Message]);
          end;
        end;
```

#### P-9. 持 FLock 触发 DoPoolEvent 回调 + 回调再入 TPoolManager → 与 ShutdownAll 构成 ABBA 死锁
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:1571、1853、1869`（示例为 ClearIdleConnections）
- **原始代码**：
```pascal
        DoPoolEvent(peConnectionDestroyed, 'Connection destroyed');
        FPool.Delete(I);
```
- **问题**：`DoPoolEvent` 在持有池 `FLock` 时调用用户回调。锁层级现状：`TPoolManager.FLock → Pool.FLock`（ShutdownAll/RemovePool）。若用户在 `OnPoolEvent` 中调用 `TPoolManager.GetPool`/`GetPoolNames`（合理场景），则该线程持 `Pool.FLock` 等 `Manager.FLock`，与正在 `ShutdownAll`（持 `Manager.FLock`、等 `Pool.FLock`）的线程形成 **ABBA 死锁**。即使不死锁，慢回调也会拖住整个池。回调异常亦被吞（仅 DEBUG 记录）。
- **触发条件**：OnPoolEvent 处理器内调用 TPoolManager 任意方法，同时另一线程执行 ShutdownAll/RemovePool/RegisterPool。
- **建议修复**：把事件移出锁外触发（先在锁内收集 `(EventType, Msg)` 列表，解锁后统一 `DoPoolEvent`）；至少在文档中禁止回调内调用 TPoolManager。

### 二、DeepBase.DB.ConnectionPool.pas（2 项）

#### CP-2. TPooledConnection.Destroy 中 FConnection.Close 无异常保护：异常逃出析构函数 + TFDConnection 泄漏
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.ConnectionPool.pas:160-168`
- **原始代码**：
```pascal
destructor TPooledConnection.Destroy;
begin
  if Assigned(FConnection) then
  begin
    if FConnection.Connected then
      FConnection.Close;
    FreeAndNil(FConnection);
  end;
  inherited;
end;
```
- **问题**：`Close` 抛异常（连接已失效、文件锁冲突等）时：异常从析构函数逃逸；`FreeAndNil(FConnection)` 不执行 → 连接对象泄漏；若发生在 `FindAvailableConnection` 的 except 处理路径（`FPool.Delete` 触发析构），会形成"异常处理中再抛异常"。对照 Pool.pas 同名析构（739-747 行）已做 try-except 防护。
- **触发条件**：销毁池时任一连接 Close 失败。
- **建议修复**：
```pascal
destructor TPooledConnection.Destroy;
begin
  if Assigned(FConnection) then
  begin
    try
      if FConnection.Connected then
        FConnection.Close;
    except
      on E: Exception do ; // 析构路径吞异常, 确保 FConnection 必被释放
    end;
    FreeAndNil(FConnection);
  end;
  inherited;
end;
```

#### CP-3. 锁内执行建连/重连网络 I/O + 建连异常被吞导致超时误导
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.ConnectionPool.pas:313-329、262-275`
- **原始代码**：
```pascal
      if FPool.Count < FMaxPoolSize then
      begin
        try
          Pooled := TPooledConnection.Create(CreateConnection);
```
```pascal
        try
          Pooled.Connection.Open;
          Result := Pooled;
          Exit;
```
- **问题**：① `CreateConnection`（含 `Result.Open` 文件 I/O）与 `Pooled.Connection.Open` 重连都在持有 `FLock` 时执行——SQLite 文件在网络盘/杀软扫描时打开缓慢，会阻塞所有 Acquire/Release。② 建连失败仅记日志后继续循环（每秒重试），最终 `Acquire` 抛 `EConnectionPoolTimeout.Create('Connection pool timeout: no available connections')`——真实原因（DB 不可达）丢失。
- **触发条件**：池需扩容或存在断连 + 慢速存储/DB 宕机。
- **建议修复**：参照 Pool.pas 的 DATA2-058 模式——锁内只做判定与登记，建连移到锁外完成后再回锁加入；建连失败区分抛出带原因的异常。

### 三、DeepBase.DB.DoQry.pas（6 项）

#### Q-4. JSON 参数强转 as TJSONObject 抛 EInvalidCast
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:825`
- **原始代码**：
```pascal
  Params := TJSONObject.ParseJSONValue(ParamsJson) as TJSONObject;
```
- **问题**：合法 JSON 但非对象（如 `[1,2]`、`"abc"`、`123`）时 `as` 抛 EInvalidCast，被上层 except 捕获后伪装成 `DOQRY_ERR_UNKNOWN` 的数据库错误，错误类型与真实原因（调用方参数格式错误）完全脱节。
- **触发条件**：调用方传 `ParamsJson = '[1,2]'` 等非对象 JSON。
- **建议修复**：
```pascal
  var LParsed := TJSONObject.ParseJSONValue(ParamsJson);
  if not (LParsed is TJSONObject) then
    Exit;   // 或抛出带明确消息的 EDeepBaseDbError(DOQRY_ERR_PARAM_INVALID)
  Params := TJSONObject(LParsed);
```

#### Q-5. GUID 自动检测未复用验证函数，StringToGUID 可抛异常；TryParseGuid 为死代码
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:856-861`
- **原始代码**：
```pascal
          if (Length(S) = 36) and
             (S[9] = '-') and (S[14] = '-') and (S[19] = '-') and (S[24] = '-') then
          begin
            P.DataType := ftGuid;
            P.AsGuid := StringToGUID('{' + S + '}');
```
- **问题**：行 800-819 精心实现了带 hex 字符校验的 `TryParseGuid`（注释明确 "avoids exception-based flow control"），但此处完全未使用——36 字符、dash 位置正确但含非 hex 字符的普通文本会让 `StringToGUID` 抛 EConvertError，被上层伪装成数据库错误。
- **触发条件**：字符串参数恰好 36 字符且第 9/14/19/24 位为 `-`，但含非 hex 字符。
- **建议修复**：复用 `TryParseGuid`（或同等的 `IsHexWithDashes` 校验）通过后才设 `ftGuid`。

#### Q-6. InsertReturningId 用 32 位 AsInteger 读取主键 —— bigint 截断
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:1599`（行 1616 同）
- **原始代码**：
```pascal
          if not Q.Eof then
            Result := Q.Fields[0].AsInteger;
```
- **问题**：PostgreSQL `RETURNING id` 与 SQLite `last_insert_rowid()` 均可能返回超过 `Integer`（32 位）范围的 bigint 值，`AsInteger` 静默截断低位 → 返回错误 ID → 业务层用错误 ID 关联数据（数据损坏链）。
- **触发条件**：表主键为 bigint 且值超 ±21 亿（自增序列越过 Integer 范围）。
- **建议修复**：函数签名改返回 `Int64`；过渡期最小修复：`Result := Q.Fields[0].AsLargeInt;`

#### Q-7. SQLite 分支 last_insert_rowid() 语义缺陷
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:1613`
- **原始代码**：
```pascal
            IdQuery.SQL.Text := 'SELECT last_insert_rowid()';
```
- **问题**：`last_insert_rowid()` 返回**当前连接**上最后一次 INSERT 的 rowid。若 INSERT 语句带触发器、且触发器内又向其他表 INSERT，返回的是触发器最后插入的 rowid 而非目标表——静默返回错误 ID。
- **触发条件**：目标表带 AFTER INSERT 触发器且触发器内有 INSERT。
- **建议修复**：优先改用 `RETURNING`（SQLite 3.35+，FireDAC 自带版本满足）统一两分支；至少在文档注明触发器限制。

#### Q-10. LogQuery 将 'INFO' 误映射为 llDebug —— 成功查询的 SQL 与参数写入日志（敏感数据泄漏）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:715-720`（已复核）
- **原始代码**：
```pascal
  if Level = 'ERROR' then
    LogLevel := llError
  else if Level = 'WARN' then
    LogLevel := llWarn
  else
    LogLevel := llDebug;
```
- **问题**：已核实 `DeepBase.Logging.pas` 的 `TLogLevel` 含 `llInfo`。所有成功查询以 `'INFO'` 调用（行 1438、1498、1627、1689），落入 else 映射为 `llDebug`，使行 739 的守卫条件 `if LogLevel = llDebug then`（SQL 与参数仅 DEBUG 记录，避免敏感数据泄漏）恒真——每一条成功查询的完整参数 JSON（可含口令哈希、个人信息）都被写入日志，与注释声明的防护意图直接矛盾。
- **触发条件**：全局日志级别为 Debug（开发/排查环境常态）时，所有查询参数落盘。
- **建议修复**：
```pascal
  if Level = 'ERROR' then
    LogLevel := llError
  else if Level = 'WARN' then
    LogLevel := llWarn
  else if Level = 'INFO' then
    LogLevel := llInfo        // INFO 不携带 params
  else
    LogLevel := llDebug;
```

#### Q-11. TryLoadQueryDef 吞掉全部异常 → 真实故障被"查询定义未找到"掩盖
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.DoQry.pas:1041-1057`
- **原始代码**：
```pascal
    try
      Q.Open;
      if not Q.Eof then
      begin
        Result := True;
        LoadedSQL := Q.FieldByName(FieldName).AsString;
      end;
    except
      Result := False;
    end;
```
- **问题**：空 except（无日志、无异常对象捕获）吞掉连接闪断、Settings/Queries 表损坏等一切真实错误，最终报出误导性的 `Query definition not found`，运维排障被引向错误方向。
- **触发条件**：加载查询定义时连接断开或表访问失败。
- **建议修复**：捕获 `E: Exception` 记录到 LastError，`LoadQuerySQL` 抛 `DOQRY_ERR_QUERY_NOT_FOUND` 时附带真实原因。

### 四、DeepBase.DB.Factory.pas（1 项）

#### F-1. VerifyBoth 无锁读写 class var FLastError（string 引用计数竞态）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Factory.pas:459`（同 479）
- **原始代码**：
```pascal
  FLastError := '';
```
- **问题**：`FLastError: string` 是 class var，多线程并发调用 `VerifyBoth` 时对 string 的引用计数操作非原子，可致计数损坏/内存崩溃；即使不崩溃，两连接的验证错误互相覆盖，`LastError` 结果不可信。
- **触发条件**：两个线程同时调用 `TDBConnectionFactory.VerifyBoth`（如健康检查定时器 + 手动诊断并发）。
- **建议修复**：引入单元级 TCriticalSection 保护 FLastError 写读；或将 FLastError 改为 VerifyBoth 的 out 参数消除共享状态。

### 五、DeepBase.SQLLogger.pas（3 项）

#### S-1. FLogsTableEnsured 在 CREATE 失败时仍置 True + SQLite 方言 → 非 SQLite 连接下数据库日志永久静默失效
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.SQLLogger.pas:586`
- **原始代码**：
```pascal
      Q.ExecSQL;
    except
      on E: Exception do
      begin
        ...
      end;
    end;
    FLogsTableEnsured := True;
```
- **问题**：`FLogsTableEnsured := True` 位于内层 except **之后**——CREATE 失败（如 PG 不接受 `AUTOINCREMENT` 方言，建表语句为 563-573 行的 SQLite 方言）也置位。行 546-547 的注释声称 "the INSERT will fail and we will retry next write"，但置位后 `EnsureLogsTable`（行 548）直接 Exit，**永远不会重试 CREATE**；INSERT 持续失败被行 644-651 吞掉——数据库日志目标永久失效且零可见告警（仅 DebugView）。
- **触发条件**：`SetDBConnection` 传入 PostgreSQL 等非 SQLite 连接，或首次 CREATE 因瞬时错误失败。
- **建议修复**：
```pascal
    try
      Q.ExecSQL;
      FLogsTableEnsured := True;   // 仅成功时置位，失败下次重试
    except
      on E: Exception do
        ... // 记录，不置位
    end;
```
（方言问题可按连接 DriverName 分支建表。）

#### S-3. WriteToFile 在锁外并发写同一文件 —— 日志行交错损坏
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.SQLLogger.pas:524-533`
- **原始代码**：
```pascal
    AssignFile(LogFile, FLogFilePath);
    if FileExists(FLogFilePath) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    try
      WriteLn(LogFile, LogLine);
    finally
      CloseFile(LogFile);
    end;
```
- **问题**：LogSQLEx 特意将 I/O 移到 FLock 之外（producer-consumer，行 354-356），但多个线程的 `Append/WriteLn` 对同一文件无任何串行化——旧式 Pascal 文件 I/O 无并发保护，交错写入产生撕裂行；行 534-536 的空捕获再吞掉 I/O 错误，日志**静默丢失**。
- **触发条件**：`Destinations` 含 `ldFile` 且多线程记录日志。
- **建议修复**：为文件写入增加独立 TCriticalSection（持锁时间短），或引入单写线程 + TThreadedQueue。

#### S-5. OnLog/OnSlowQuery 回调在锁外无异常保护 —— 日志回调异常打断业务查询路径
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.SQLLogger.pas:359-362`
- **原始代码**：
```pascal
  if DoCallback then
    LOnLog(Entry);
  if DoSlowAlert then
    LOnSlowQuery(Entry);
```
- **问题**：回调由调用方注入（典型为 UI 刷新、告警推送），其异常将沿 `LogSQL` → `UniDbSelect/UniDbExec` 的调用栈传播，**日志副作用使业务 SQL 操作失败**。WriteToFile/WriteToDatabase 均有 except 保护，唯独回调裸奔。
- **触发条件**：注册的回调内抛异常（UI 控件已销毁、告警通道断开等）。
- **建议修复**：
```pascal
  if DoCallback then
    try LOnLog(Entry)
    except on E: Exception do OutputDebugString(PChar('SQLLogger callback: ' + E.Message)) end;
```

### 六、DeepBase.DB.Guardian.pas（4 项）

#### G-1. ProtectConnection 对 Open 失败一律隔离 —— 暂时性错误触发误隔离 + 旧备份恢复 = 数据回退
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Guardian.pas:398-409`
- **原始代码**：
```pascal
  if not AConn.Connected then
  try
    AConn.Open;
  except
    on E: Exception do
    begin
      // Open itself failed: DB file likely corrupted at filesystem level
      AResult.Message := 'Open failed: ' + E.Message;
      AResult.Status := isCorrupted;

      // Try quarantine + recovery
      Recovery := QuarantineAndRecover(DBPath);
```
- **问题**：Open 失败 ≠ 文件损坏。Windows 上杀毒软件扫描、备份软件占用、网络盘抖动、磁盘满都会导致 Open 失败（SQLITE_BUSY/IOERR 类），当前逻辑一律执行 `QuarantineAndRecover`：健康主文件被改名隔离，随后从**昨日备份**恢复 → 当日全部数据静默回退。这与文件头声明的设计目标 "Never lose data silently" 直接冲突。
- **触发条件**：启动时 DB 文件被第三方进程短暂锁定（杀软/备份软件的典型行为窗口）。
- **建议修复**：区分错误类型——仅 SQLite `SQLITE_NOTADB`(26)/`SQLITE_CORRUPT`(11) 类（`EFDDBEngineException` 的 NativeCode）才走隔离；BUSY/LOCKED/IOERR 类返回失败让上层重试。

#### G-2. 七条 PRAGMA 共用一个 try —— 首条失败后续全部跳过
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Guardian.pas:92-112`
- **原始代码**：
```pascal
  try
    // journal_mode=WAL: allows concurrent reads during write, atomic commits
    AConn.ExecSQL('PRAGMA journal_mode=WAL');
    // synchronous=NORMAL: fsync on checkpoint, safe with WAL
    AConn.ExecSQL('PRAGMA synchronous=NORMAL');
    // foreign_keys=ON: enforce FK constraints (SQLite default is OFF)
    AConn.ExecSQL('PRAGMA foreign_keys=ON');
    // busy_timeout: wait up to 5 seconds for locks instead of failing
    AConn.ExecSQL('PRAGMA busy_timeout=5000');
    ...
  except
    on E: Exception do
      OutputDebugString(PChar('Guardian: pragma failed: ' + E.Message));
  end;
```
- **问题**：`journal_mode=WAL` 切换需要短暂独占锁，恰是最易失败的一条（注释自己也承认并发场景）；一旦它在第一条失败，`busy_timeout=5000`、`foreign_keys=ON` 等关键防护**全部未生效**——外键约束静默失效属数据完整性风险。
- **触发条件**：ApplyRecommendedPragmas 执行瞬间另一连接持有锁（WAL 切换期常见）。
- **建议修复**：每条独立 try（数组循环），失败的仅记录该条名称。

#### G-3. BackupTo 的 Delete→Move 非原子窗口 —— 崩溃时旧备份已删、新备份未就位
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Guardian.pas:214-216`
- **原始代码**：
```pascal
    // Atomic rename: delete old backup then move temp into place
    if TFile.Exists(ADestPath) then
      TFile.Delete(ADestPath);
    TFile.Move(TempPath, ADestPath);
```
- **问题**：注释自称 "Atomic rename"，实际 Delete 与 Move 之间存在崩溃窗口——此间断电/崩溃将导致**新旧备份同时丢失**（旧已删、新未改名，temp 残留可救但依赖人工发现）。
- **触发条件**：备份替换瞬间进程崩溃/断电。
- **建议修复**：先 `TFile.Move(TempPath, ADestPath + '.new')`，再用 Winapi `MoveFileEx(PChar(New), PChar(Dest), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH)` 原子替换；失败时旧备份仍完好。

#### G-4. 备份恢复用非原子 TFile.Copy —— 半截数据库文件残留
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Guardian.pas:322`
- **原始代码**：
```pascal
      TFile.Copy(BackupPath, ADBPath);
```
- **问题**：Copy 中途失败（磁盘满/IO 错）留下不完整的 ADBPath；异常被行 327-330 捕获后走"fresh DB"路径，但**半截主文件已存在**——下次 Open 将再次失败、再次隔离，进入折腾循环而非干净的 fresh start。
- **触发条件**：恢复拷贝中途 IO 故障。
- **建议修复**：
```pascal
      TFile.Copy(BackupPath, ADBPath + '.restore');
      TFile.Move(ADBPath + '.restore', ADBPath);   // 同目录原子改名
```

### 七、DeepBase.ORM.pas（4 项）

#### ORM-1. ToList 异常路径泄漏结果列表（违反仓库"创建对象后 try/finally"约定）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.ORM.pas:953-955`
- **原始代码**：
```pascal
  Result := TObjectList<T>.Create(True);
  Query := FContext.RequireStorage.OpenDataSet(BuildSelectSQL, FWhereParams);
  try
```
- **问题**：`Result` 创建后、进入 `try` 之前调用了 `OpenDataSet`；Delphi 函数抛异常时 Result 对象不会自动释放。若 `OpenDataSet` 抛异常（连接断开、SQL 错误）→ `TObjectList` 泄漏；若循环内 `MapRowToEntity` 抛异常 → 列表连同已装入的全部实体泄漏。
- **触发条件**：任何查询执行失败或行映射失败。
- **建议修复**：
```pascal
var
  List: TObjectList<T>;
begin
  List := TObjectList<T>.Create(True);
  try
    Query := FContext.RequireStorage.OpenDataSet(BuildSelectSQL, FWhereParams);
    while not Query.Eof do
    begin
      List.Add(MapRowToEntity(Query));
      Query.Next;
    end;
    Result := List;
    List := nil;
  finally
    Query.Free;
    List.Free;
  end;
end;
```

#### ORM-2. MapRowToEntity 中途异常泄漏已创建实体
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.ORM.pas:801` 及 `:837`
- **原始代码**：
```pascal
  Result := T(FMetadata.EntityType.Create);
...
      Col.RttiField.SetValue(TObject(Result), Value);
```
- **问题**：实体在 801 行创建后，逐列 `SetValue`（837 行）过程中任一列类型不匹配抛异常 → 已创建实体泄漏（`TObjectList` 尚未接管所有权）。
- **触发条件**：结果集中某列类型与实体字段 RTTI 类型不兼容。
- **建议修复**：
```pascal
  Result := T(FMetadata.EntityType.Create);
  try
    ... // 循环 SetValue
  except
    Result.Free;
    raise;
  end;
```

#### ORM-3. OFFSET 不带 LIMIT 在 SQLite 上是语法错误
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.ORM.pas:782-786`
- **原始代码**：
```pascal
    if FLimitCount > 0 then
      SQL.Append(' LIMIT ').Append(FLimitCount);

    if FOffsetCount > 0 then
      SQL.Append(' OFFSET ').Append(FOffsetCount);
```
- **问题**：SQLite 要求 `OFFSET` 必须跟在 `LIMIT` 之后。仅调用 `.Offset(10)` 而未设置 Limit 时生成 `SELECT ... FROM t OFFSET 10` → SQLite 报 `syntax error near "OFFSET"`。本 ORM 明确面向 SQLite（见 ORM-11 的 sqlite_master 探测）。
- **触发条件**：`Query<T>.Offset(N)` 未同时调用 `Limit`。
- **建议修复**：
```pascal
    if (FLimitCount > 0) or (FOffsetCount > 0) then
    begin
      if FLimitCount > 0 then
        SQL.Append(' LIMIT ').Append(FLimitCount)
      else
        SQL.Append(' LIMIT -1');   // SQLite: OFFSET 前必须有 LIMIT
      if FOffsetCount > 0 then
        SQL.Append(' OFFSET ').Append(FOffsetCount);
    end;
```

#### ORM-11. Schema 操作族方言锁死 SQLite；TableExists 忽略 Schema
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.ORM.pas:1508-1510`（另见 `:1397`、`:1410-1411`）
- **原始代码**：
```pascal
  Result := not VarIsNull(ExecuteScalar(
    'SELECT name FROM sqlite_master WHERE type=''table'' AND name=?',
    [Metadata.TableName]));
```
- **问题**：`IORMStorage` 是数据库无关抽象，但 `TableExists` 查询 `sqlite_master`（PG 中不存在该表 → 直接异常）、`CreateTable` 生成 `AUTOINCREMENT`（SQLite 专用语法，PG/MySQL 报错）。且 `TableExists` 用 `Metadata.TableName` 而非 `GetFullTableName`，与建表/CRUD 路径不一致，带 Schema 的实体探测结果错误。
- **触发条件**：对 PG 连接调用 `EnsureTable<T>`/`TableExists<T>`；或实体带 Schema 调用 `TableExists`。
- **建议修复**：将"表是否存在/建表 DDL"下沉为 `IORMStorage` 的方言化能力；短期至少让 `TableExists` 传 `Metadata.GetFullTableName` 并在 PG 分支查 `information_schema.tables`。

### 八、DeepBase.DB.Migrations.pas（2 项）

#### MIG-1. except 分支内 ROLLBACK 失败会掩盖原始迁移异常
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Migrations.pas:178-187`
- **原始代码**：
```pascal
      except
        if OwnTransaction then
        begin
          if SQLiteImmediate then
            Connection.ExecSQL('ROLLBACK')
          else if Connection.InTransaction then
            Connection.Rollback;
        end;
        raise;
      end;
```
- **问题**：若迁移语句因连接级故障失败（磁盘 I/O 错、连接中断），except 块里的 `ExecSQL('ROLLBACK')`/`Rollback` 自身再抛异常，会**替换**原始异常（Delphi except 块内新异常掩盖原异常），最终 `Result.LastError` 记录的是回滚失败而非迁移真正的失败原因。
- **触发条件**：迁移失败且连接已不可用。
- **建议修复**：回滚操作包裹独立 try-except，失败时合并为 `CreateFmt('Migration failed: %s (rollback also failed: %s)', [E.Message, ...])` 后 re-raise。

#### MIG-2. 备份回退路径裸 except 吞异常 + 在线 TFile.Copy 可产生不一致备份
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Migrations.pas:677-681`
- **原始代码**：
```pascal
  try
    Connection.ExecSQL('VACUUM INTO ' + QuotedStr(Result));
  except
    TFile.Copy(DBPath, Result, True);
  end;
```
- **问题**：① 裸 `except` 捕获一切（含 EAbort），违反仓库"不吞异常"约定；② `VACUUM INTO` 失败（常见原因：SQLite < 3.27）回退到 `TFile.Copy` 直接拷贝**在线数据库主文件**——若 DB 处于 WAL 模式，`-wal`/`-shm` 未一并拷贝，备份可能缺最新事务甚至无法打开。
- **触发条件**：旧版 SQLite 或 VACUUM INTO 因锁失败，且数据库为 WAL 模式。
- **建议修复**：except 收窄为 `on E: EDatabaseException`；回退时同时拷贝 `-wal`/`-shm`（或拒绝回退、将备份失败作为 LastError 上报）。

### 九、DeepBase.DB.JobQueue.pas（2 项）

#### JQ-1. DequeueSQLite 用 DEFERRED 事务，多连接并发下有 SQLITE_BUSY 死锁窗口
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.JobQueue.pas:693-695`
- **原始代码**：
```pascal
  OwnTransaction := not Connection.InTransaction;
  if OwnTransaction then
    Connection.StartTransaction;
```
- **问题**：FireDAC SQLite 的 `StartTransaction` 默认发出 `BEGIN DEFERRED`。连接池有 4 条连接（`JOB_QUEUE_POOL_SIZE = 4`），两条连接并发出队时：各自 BEGIN DEFERRED → 各自 SELECT 取 SHARED 锁 → 各自 UPDATE 争 RESERVED → 一方 SQLITE_BUSY；持有方 COMMIT 需升 EXCLUSIVE 又被对方 SHARED 阻塞——SQLite 对这种经典推迟事务死锁直接返回 BUSY，**不受 busy timeout 保护**。出队抛异常，worker 反复失败。同仓库 Migrations 已用 `BEGIN IMMEDIATE` 解决同类问题，此处未对齐。
- **触发条件**：SQLite 后端 + 多线程 worker 并发 Dequeue。
- **建议修复**（与 Migrations 一致）：
```pascal
  OwnTransaction := not Connection.InTransaction;
  if OwnTransaction then
    Connection.ExecSQL('BEGIN IMMEDIATE');   // 写意图明确，避免升级死锁
```
并同步调整提交/回滚分支为 `ExecSQL('COMMIT')`/`ExecSQL('ROLLBACK')`。

#### JQ-2. LoadDeadLetterFromQuery 用区域敏感的 StrToDateTime 解析时间戳，失败静默置 0
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.JobQueue.pas:1113-1124`
- **原始代码**：
```pascal
  CreatedAtText := Query.FieldByName('created_at').AsString;
  MovedAtText := Query.FieldByName('moved_at').AsString;
  try
    Rec.CreatedAt := StrToDateTime(CreatedAtText);
  except
    Rec.CreatedAt := 0;
  end;
```
- **问题**：PG 返回 `2026-08-24 12:34:56`（ISO），但 `StrToDateTime` 按系统区域格式解析。在 `ShortDateFormat='dd.MM.yyyy'`（德语等）区域下解析失败 → except 吞掉 → `CreatedAt=0`，监控界面死信时间全部显示 1899-12-30。代码注释声称 "StrToDateTime accepts them" 与实际不符；且吞异常违反仓库约定。
- **触发条件**：非 ISO 日期格式的系统区域设置下调用 `PeekDeadLetters`。
- **建议修复**：
```pascal
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Invariant;
  FS.DateSeparator := '-';
  FS.TimeSeparator := ':';
  FS.ShortDateFormat := 'yyyy-mm-dd';
  FS.LongTimeFormat := 'hh:nn:ss';
  Rec.CreatedAt := StrToDateTimeDef(CreatedAtText, 0, FS);
```

### 十、DeepBase.DB.StatusMachine.pas（2 项）

#### SM-2. QuoteIdentifier 对 "schema.table" 形式整体加引号，语义错误
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.StatusMachine.pas:342-343`（另见 406-410、488-490 同模式）
- **原始代码**：
```pascal
    Query.SQL.Text := Format('SELECT status FROM %s WHERE id = :id',
      [QuoteIdentifier(TableName)]);
```
- **问题**：`ValidateIdentifier`（行 201-224，EXP-P1-016 修复）特意放行 `"schema.table"` 形式，但 `QuoteIdentifier`（行 237-250）把整个字符串包成 `"public.orders"` —— 在 PostgreSQL/SQLite 中这是**单个含点标识符**，而非 schema `public` 下的表 `orders`。注册 `"public.orders"` 后所有 SQL 都会因找不到表而失败。
- **触发条件**：调用方以 `RegisterTable('public.orders', ...)` 这类带 schema 的表名注册并执行 Transit/Heartbeat。
- **建议修复**：按 `.` 分段分别引用：
```pascal
class function TStatusMachine.QuoteIdentifier(const AName: string): string;
var
  Parts: TArray<string>;
  Part: string;
begin
  Parts := AName.Split(['.']);
  for Part in Parts do
    Part := '"' + Part.Replace('"', '""') + '"';
  Result := string.Join('.', Parts);
end;
```

#### SM-3. Transit 更新未命中（RowsAffected=0）时仍提交并记录心跳，与 Heartbeat 行为不一致
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.StatusMachine.pas:415-422`
- **原始代码**：
```pascal
        Result := Query.RowsAffected > 0;
      finally
        Query.Free;
      end;

      if OwnTransaction then
        Connection.Commit;
      RecordHeartbeat(TableName, EntityID);
```
- **问题**：实体行在 `ReadCurrentStatus` 之后、UPDATE 之前被并发删除时，`RowsAffected = 0`，但代码无条件 Commit 并 `RecordHeartbeat`。而 `Heartbeat` 方法（行 493-494）仅在 `RowsAffected > 0` 时记录心跳。Transit 失败却记录心跳，会让后续 `CanWriteHeartbeat` 在间隔内拦截真正的心跳写入。
- **触发条件**：Transit 目标行被并发删除（或 UPDATE 因触发器等未影响行）。
- **建议修复**：`if Result then RecordHeartbeat(TableName, EntityID);`

### 十一、FireDAC 存储适配器（12 项）

#### AU-1. AssignUserRole 使用 SQLite 专有 INSERT OR IGNORE，PG 后端语法错误
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Authorization.FireDAC.pas:704-705`
- **原始代码**：
```pascal
    Query.SQL.Text :=
      'INSERT OR IGNORE INTO auth_user_roles (user_id, role_id) VALUES (:user_id, :role_id)';
```
- **问题**：本单元处处以 `IsPostgreSQL` 分支支持双后端（建表、InsertUser、UpdateUser、InsertAudit 均有 PG 分支），但此处只有 SQLite 方言。PG 中 `INSERT OR IGNORE` 直接语法错误，注释宣称的"消除 TOCTOU 竞态"在 PG 上完全失效。
- **触发条件**：共享库为 PostgreSQL（`DB3.Type=PostgreSQL`）时调用 AssignUserRole。
- **建议修复**：
```pascal
    if IsPostgreSQL then
      Query.SQL.Text :=
        'INSERT INTO auth_user_roles (user_id, role_id) VALUES (:user_id, :role_id) ' +
        'ON CONFLICT (user_id, role_id) DO NOTHING'
    else
      Query.SQL.Text :=
        'INSERT OR IGNORE INTO auth_user_roles (user_id, role_id) VALUES (:user_id, :role_id)';
```

#### DI-1. AddColumnIfNotExists 的 AColumnDef 未验证即拼接 DDL（对比 Manager 同类方法已修复）
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas:686-687`
- **原始代码**：
```pascal
    FConnection.ExecSQL(Format('ALTER TABLE %s ADD COLUMN %s %s',
      [ATableName, AColumnName, AColumnDef]));
```
- **问题**：表名、列名都做了 `TSQLUtils.ValidateIdentifier`（行 681-682），但 `AColumnDef` 是公开接口 `IDiagnoseStorage.AddColumnIfNotExists` 的参数，原样拼进 DDL。仓库中同类方法 `Manager.AddColumn`（Manager.FireDAC.pas 行 222-226，DATA-R3-007）已引入 `TSQLUtils.ValidateColumnDef` 防注入，此处遗漏。
- **触发条件**：调用方将含分号/注释/DDL 关键字的字符串传入 AColumnDef。
- **建议修复**（与 Manager.AddColumn 对齐）：增加 `TSQLUtils.ValidateColumnDef(AColumnDef, 'Diagnose.AddColumn.ColumnDef');`

#### PR-1. UpgradeDatabase 空 except 块吞掉所有异常
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Protection.FireDAC.pas:336-343`
- **原始代码**：
```pascal
      try
        Sql := 'ALTER TABLE ' + TableName + ' ADD COLUMN ' + ColumnName;
        Conn.ExecSQL(Sql);
      except
        // Column already exists or legacy table is absent; caller can still
        // continue because SetupDatabase creates the modern table first.
      end;
```
- **问题**：注释假设异常只来自"列已存在/旧表缺失"，但空 except 同样吞掉磁盘满、数据库文件被锁、权限错误等真实故障，`Result := True` 照常返回，调用方以为升级成功。违反仓库"不吞异常"约定。
- **触发条件**：ALTER TABLE 因任何非"列已存在"原因失败。
- **建议修复**：先探测再执行（`ColumnExistsSlow`），避免靠异常控流；或至少判断 `E.Message` 包含 'duplicate column' 才忽略，其余 raise `EDatabaseException`。

#### LO-1. EnsureInsertQuery 创建对象后无 try-finally，异常路径泄漏并残留半初始化字段
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Logging.FireDAC.pas:107-120`（EnsureLegacyInsertQuery 行 131-143 同构）
- **原始代码**：
```pascal
  FInsertQuery := TFDQuery.Create(nil);
  FInsertQuery.Connection := FConnection;
  FInsertQuery.SQL.Text :=
    'INSERT INTO Logs (LogTime, LogLevel, Source, Message, StackTrace, ThreadId, Extra) ' +
    'VALUES (:LogTime, :Level, :Source, :Msg, :Stack, :TID, :Extra)';
  FInsertQuery.ParamByName('LogTime').DataType := ftString;
  ...
  FInsertQuery.Prepare;
```
- **问题**：`FInsertQuery` 赋值后到 `Prepare` 之间无保护。若 `Prepare` 抛异常（如 Logs 表不存在时 SQLite prepare 失败），对象已泄漏且字段非 nil——后续 `EnsureInsertQuery` 的 `if Assigned(FInsertQuery) then Exit`（行 100）会让所有后续写日志都使用这个处于失败态的 Query。违反仓库"创建对象后 try/finally 释放"约定。
- **触发条件**：首次写日志时 Logs 表不存在/连接异常，Prepare 或中途抛异常。
- **建议修复**：
```pascal
  FInsertQuery := TFDQuery.Create(nil);
  try
    FInsertQuery.Connection := FConnection;
    ...
    FInsertQuery.Prepare;
  except
    FreeAndNil(FInsertQuery);
    raise;
  end;
```

#### VP-1. HMAC 派生盐值含拼写错误 "veoice"，形成数据兼容性地雷
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas:107`
- **原始代码**：
```pascal
  Result := THashUtils.HASHBytes(
    TEncoding.UTF8.GetBytes(AOwnerApp + #0'veoice_profiles_hmac_v1'),
    haSHA256);
```
- **问题**：`veoice_profiles_hmac_v1` 应为 `voice_profiles_hmac_v1`。当前读写两端一致，HMAC 校验功能自洽；但这是**意外引入**的缺陷（非有意版本盐）。任何人日后"顺手修正拼写"，所有已存声纹的 `features_hmac` 将全部失配，`LoadFeatures` 对每条记录抛 `EDatabaseVoiceprintTampered`——整个声纹库被误判为篡改而不可用。
- **触发条件**：修复拼写而不做数据迁移/重算；当前代码不触发。
- **建议修复**：保持字符串不变，定义为有名常量并加注释警告；若该功能尚未投产/无存量数据，则现在改成正确拼写是唯一零成本窗口。

#### VP-2. SaveProfile 的 UPDATE-then-INSERT 无事务包裹，并发下撞唯一键
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas:265-330`（关键点：268-294 UPDATE、296-330 INSERT）
- **原始代码**：
```pascal
  LQry := TFDQuery.Create(nil);
  try
    LQry.Connection := FConnection;
    LQry.SQL.Text :=
      'UPDATE voice_profiles SET ' +
      ...
    LQry.ExecSQL;
    LIsUpdate := LQry.RowsAffected > 0;

    if not LIsUpdate then
    begin
      // 3. Row didn't exist — INSERT with a fresh created_at.
```
- **问题**：两个并发调用同时 UPDATE 同一 profile（都返回 RowsAffected=0），随后都走 INSERT，后提交者撞 `profile_id` 唯一键抛异常。对比同仓库 `MRU.Upsert`（DATA2-019 事务包裹）、`Authorization.DeleteUser`（事务包裹）已处理同类问题，此处缺失。
- **触发条件**：两个执行流（线程或进程）并发 SaveProfile 同一 profile_id。
- **建议修复**：包事务并捕获唯一键冲突（或 PG 用 `INSERT ... ON CONFLICT (profile_id, owner_app) DO UPDATE` 单语句 upsert）。

#### LL-1. 吞异常：TableExists 掩盖真实数据库故障
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.LLM.FireDAC.pas:214-216`
- **原始代码**：
```pascal
  except
    Result := False;
  end;
```
- **问题**：`except end` 式空捕获吞掉**所有**异常（连接中断、磁盘满、锁冲突、SQL 语法错误），统一返回"表不存在"。上层（含 `TableHasColumn` 及依赖它的建表/迁移分支）会把"数据库坏了"误判为"表不存在"，可能触发重建表等错误恢复路径。
- **触发条件**：数据库连接异常或 IO 故障时调用 `TableExists`。
- **建议修复**：捕获后至少 `OutputDebugString` 留痕，或收窄异常类型（`on E: EFDException`）。

#### TH-1. 所有方法均不检查连接可用性，破坏存储层统一契约
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.TestHelper.FireDAC.pas:48-50`
- **原始代码**：
```pascal
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
```
- **问题**：其余全部存储的方法都以 `if not Assigned(FConnection) or not FConnection.Connected then Exit;` 防御（如 FormState 行 51、Config 行 68），本文件 4 个方法（WriteSnapshot 行 43、TryReadSnapshot 行 64、DeleteSnapshot 行 88、ReadSnapshotNames 行 103）一个都没有。`FConnection = nil` 时以裸 `EFDException`（"command is not defined / no connection"）暴露，而非本层统一的静默降级契约。
- **触发条件**：连接为 nil 或未打开时调用任意方法。
- **建议修复**：补齐与其他存储一致的 `Assigned/Connected` 前置检查（或加注释声明有意暴露异常）。

#### IC-2. ProtectConnection 返回值被忽略，损坏库上记录"检查通过"
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.IntentClarification.Storage.pas:131-132`
- **原始代码**：
```pascal
  TDBGuardian.ProtectConnection(FConnection, LGuardResult);
  Log(ltDebug, 'IC: Storage integrity check passed (Guardian)');
```
- **问题**：已核实 `TDBGuardian.ProtectConnection` 的签名为 `class function ...(AConn: TFDConnection; out AResult: TGuardianResult): Boolean`，返回 False 表示连接不可用。本处忽略返回值：① 返回 False 时仍记录 "integrity check passed"（误导性日志）；② `FInitialized := True` 后续操作在坏连接上反复失败；③ `LGuardResult`（含失败详情、隔离路径）被声明后完全未使用。
- **触发条件**：DB 文件损坏且无可用备份时首次使用存储。
- **建议修复**：
```pascal
  if not TDBGuardian.ProtectConnection(FConnection, LGuardResult) then
    raise EDatabaseException.CreateFmt(
      'IC storage DB unusable: %s', [LGuardResult.Message]);
```

#### IC-3. EnsureInitialized 无锁，首次并发调用双重初始化
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.IntentClarification.Storage.pas:123-124`
- **原始代码**：
```pascal
  if FInitialized then
    Exit;
```
- **问题**：`FInitialized` 的检查-设置无 `TCriticalSection`/`TInterlocked` 保护。两个线程同时首次调用（如会话恢复与后台保存并发）都会通过检查，各自执行 `GetLocal` + `ProtectConnection` + `InitializeSchema`。`ProtectConnection` 内含每日备份逻辑（写同一备份文件），并发执行可能竞争备份文件。
- **触发条件**：多线程同时首次调用任意存储方法。
- **建议修复**：加 `FLock: TCriticalSection` 包裹 EnsureInitialized 全体，或用 `TInterlocked.CompareExchange` 守卫。

#### 跨文件横向问题 A：SQLite 方言与双后端设计不匹配（AU-1 之外另有 2 处，标[存疑]，见存疑区）
Manager.UpsertProjectInfo（`INSERT OR REPLACE`，行 330-331）、Hotkeys.RegisterDefaults（`INSERT OR IGNORE`，行 199-201）同属此类。建议统一约定：凡可绑到共享库的存储，写 SQL 时必须过 `IsPostgreSQL` 分支。

#### 跨文件横向问题 B：事务结构两种风格并存
`ReplaceRolePermissions`/`UpdateSchemaInfo`/`MRU.Upsert` 采用"StartTransaction 在 try 内 + OwnTx 跟踪"的正确模式；`DeleteUser`/`DeleteRole`（Authorization.FireDAC.pas:495-502、660-667）把 StartTransaction 放在 try 外——`TFDQuery.Create` 抛异常（OOM）时事务已开始却无回滚路径。建议统一为前者。

<!-- CONTINUED -->
