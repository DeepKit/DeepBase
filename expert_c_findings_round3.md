# 专家 C 审阅报告: Persistence/数据平台/doQry（第三轮）

> 审查日期: 2026-07-08
> 审查范围: Persistence/DeepBase.ORM.pas、DeepBase.DB.{Pool,ConnectionPool,Factory,Guardian,JobQueue,Migrations,StatusMachine,AutoRefreshConfig,DoQry}.pas、Persistence/DeepBase.Persistence.{Diagnose,Exception,FormState,I18n,MRU,Manager,License,Hotkeys,Config,LLM,Authorization,Theme,Logging,Security,Speech.Voiceprint,TestHelper,ORM.FireDAC}.pas、Persistence/DeepBase.IntentClarification.Storage.pas、DeepAxis/DeepBase.External.{BCryptDecrypt,SQLiteReader}.pas、doQry/{doQryMain,uDoQryLegacy}.pas
> 文件总数: 25

## 概要

7 个新问题: 1 P0 / 3 P1 / 1 P2 / 2 P3。

- 连接池核心 P0: `TUniConnectionPool.Release` 归还连接前不回滚残留事务/不关闭游标，下个借用者会继承脏连接（事务未提交、隔离级别泄漏）。
- doQry 工具表单（doQryMain.pas）存在多处字符串拼接 SQL，含一个真实可触发的过滤注入点。
- Diagnose 适配器在 FK/必填字段/枚举校验中用 `OutputDebugString` 吞掉查询异常，诊断扫描会出现"假绿"。
- MRU.Upsert 无条件 `StartTransaction`，重入/共享连接场景会误回滚调用方事务。
- 第二轮修复已验证成立: ORM OrderBy/Where 参数化、BCryptDecrypt 密钥清零+随机临时路径+析构擦写删除、DB.Pool Validate 超时、AutoRefreshConfig 共享连接加锁、Migrations 读锁+校验和一致性。

## 发现列表

| 编号 | 严重度 | 模块 | 分类 | 简述 |
|------|--------|------|------|------|
| DATA-R3-001 | P0 | DeepBase.DB.Pool | 连接池脏状态归还 | Release 不回滚残留事务/不关闭游标，污染下个借用者 |
| DATA-R3-002 | P1 | doQry/doQryMain | SQL 注入 | btnSearchClick 过滤条件字符串拼接，可注入 |
| DATA-R3-003 | P1 | doQry/doQryMain | SQL 注入 | GetFieldList 用 Format 拼接 TableName 到 information_schema 查询 |
| DATA-R3-004 | P1 | Persistence.Diagnose.FireDAC | 异常吞没 | CheckForeignKeys/CheckRequiredFields/CheckEnumValues 用 OutputDebugString 吞查询异常，诊断假绿 |
| DATA-R3-005 | P2 | Persistence.MRU.FireDAC | 事务管理 | Upsert 无条件 StartTransaction，重入会误回滚调用方事务 |
| DATA-R3-006 | P3 | doQry/uDoQryLegacy | PII 日志 | ExecuteAndGetResult 把含参数值的完整 SQL 写进异常消息 |
| DATA-R3-007 | P3 | Persistence.Manager.FireDAC | 防御性缺口 | AddColumn 的 ColumnDef 原样拼入 DDL，无白名单校验 |

## 各发现详细说明

### DATA-R3-001 [P0] — 连接池归还脏连接：未回滚残留事务/未关闭游标
**文件**: D:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas
**位置**: 第 751-772 行（`TPooledConnection.Release`）；关联 `FindAvailableConnection` 第 1358-1379 行

`Release` 只把 `FState` 置 `csIdle` 并 `SetEvent`，既不检查 `FConnection.InTransaction`，也不回滚，更不关闭可能仍打开的 `TFDQuery` 游标。`FindAvailableConnection` 对 `csIdle` 连接只调用 `IsValid`（`SELECT 1` 探活），同样不清事务。后果：任意调用方经 `Pool.Execute`/`Pool.Query<T>`/`GetConnection` 借出连接后，若开启事务但在 `finally` 前抛异常（或忘了提交），该连接带着未提交事务被归还；下个借用者 `BeginTransaction` 在 SQLite 上会失败（"cannot start a transaction within a transaction"），在 PostgreSQL 上则可能读到上一调用方未提交的中间数据、甚至把别人的 `INSERT/UPDATE` 一起提交。

```delphi
procedure TPooledConnection.Release;
begin
  ...
  FPool.FLock.Enter;
  try
    FState := csIdle;          // ← 直接置空闲，无 InTransaction 检查/回滚
    FLastUsedAt := Now;
    ...
    FPool.FAvailableEvent.SetEvent;
  finally
    FPool.FLock.Leave;
  end;
```

**建议修复**: 在 `Release` 置 `csIdle` 之前做连接复位：
```delphi
try
  if FConnection.InTransaction then
    FConnection.Rollback;     // 丢弃任何残留事务
  FConnection.CloseActiveStatements; // FireDAC: 关闭所有活动游标
except
  // 复位失败则标记无效，避免污染
  FState := csInvalid;
end;
```
或至少在 `TryGetConnection` 借出前复位（但归还时复位更稳妥，因为避免借用者拿到脏连接后才报错）。

---

### DATA-R3-002 [P1] — 过滤条件字符串拼接 SQL 注入
**文件**: D:\_Progs\02Business\DeepBase\doQry\doQryMain.pas
**位置**: 第 149-152 行（`btnSearchClick`）

用户在 `edtSearch` 输入的字符串 `s` 直接拼进 ADO `Filter` 表达式，单引号未转义。`tblQueries.Filter` 在 ADO 里是类 SQL 的表达式，攻击者输入 `' OR 1=1 --` 类内容可改变过滤语义（虽不直接执行多语句，但可越权浏览全部 `proc_name`，并可触发 ADO 解析错误导致拒绝服务）。

```delphi
tblQueries.Filter := 'proc_name LIKE ''%' + s + '%''';
tblQueries.Filtered := True;
```

**建议修复**: 用 `QuotedStr` 转义或改用参数化查询替代 Filter：
```delphi
tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%');
```

---

### DATA-R3-003 [P1] — information_schema 查询拼接表名
**文件**: D:\_Progs\02Business\DeepBase\doQry\doQryMain.pas
**位置**: 第 305 行（`GetFieldList`），另见第 126 行 `btnGenSqlClick`、第 178 行 `Button1Click`

`TableName` 来自 `cboBoxTables` 选择（最终源于 `GetTableList` 查 `information_schema`），虽然不是直接用户键入，但通过 ADO 拼接到 SQL 字符串。第 286 行用 `Format` 但实际未使用 `DatabaseName` 参数；第 305 行真正拼接了 `TableName`。此为遗留 ADO 工具代码，但仍属注入面。

```delphi
aQry.SQL.Text := Format('SELECT column_name FROM information_schema.columns WHERE table_name = ''%s'';', [TableName]);
```

**建议修复**: 改用参数化：`... WHERE table_name = :t`，`Parameters.ParamByName('t').Value := TableName`。

---

### DATA-R3-004 [P1] — 诊断扫描静默吞异常，产生"假绿"结果
**文件**: D:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas
**位置**: 第 462-467 行（`CheckForeignKeys`）、第 522-527 行（`CheckRequiredFields`）、第 590-595 行（`CheckEnumValues`），以及第 615-619 行（`AddColumnIfNotExists`）

每个 FK/必填/枚举检查的 `Query.Open` 都包在 `try ... except on E: Exception do OutputDebugString(...)` 里。若某表存在但查询因列名漂移、权限、锁、类型不匹配等失败，该检查返回空结果（无任何 `TDiagnoseResult`），`DiagnoseAll` 因此报告"无问题"。运维据此以为数据库健康，实际问题被掩盖。`AddColumnIfNotExists` 同样吞异常返回 `False`，调用方无法区分"列已存在"与"ALTER 失败"。

```delphi
      try
        Query.Open;
        OrphanCount := Query.FieldByName('OrphanCount').AsInteger;
        ...
      except
        on E: Exception do
          OutputDebugString(PChar('Diagnose.CheckForeignKeys: ' + E.Message));
      end;
```

**建议修复**: 将异常转换为一条 `IsOK := False` 的 `TDiagnoseResult`（`IssueType := ditOther`，`Issue := '检查失败: ' + E.Message`），让诊断结果可见，而非依赖 DebugView。

---

### DATA-R3-005 [P2] — MRU.Upsert 无条件开启事务，重入误回滚调用方
**文件**: D:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.MRU.FireDAC.pas
**位置**: 第 72 行、第 109-112 行

`Upsert` 直接 `FConnection.StartTransaction`，未检查 `InTransaction`。对比同仓 `Authorization.ReplaceRolePermissions` 与 `Manager.UpdateSchemaInfo` 均使用 `OwnTx := not FConnection.InTransaction` 守卫。若 MRU 共享连接已被外层开启事务（例如批量导入场景把多个 MRU 更新包在一个事务里），`StartTransaction` 抛 `EFDException`，`except` 分支 `FConnection.Rollback` 会回滚外层事务，破坏调用方工作。

```delphi
  FConnection.StartTransaction;   // ← 第72行，无 InTransaction 判断
  try
    ...
    FConnection.Commit;
  except
    FConnection.Rollback;          // ← 第111行，会误回滚外层
    raise;
  end;
```

**建议修复**: 仿照 `Authorization` 的 `OwnTx` 模式：
```delphi
OwnTx := not FConnection.InTransaction;
if OwnTx then FConnection.StartTransaction;
try ... if OwnTx then FConnection.Commit;
except
  if OwnTx and FConnection.InTransaction then FConnection.Rollback;
  raise;
end;
```

---

### DATA-R3-006 [P3] — 异常消息中记录含参数值的完整 SQL（PII 泄漏）
**文件**: D:\_Progs\02Business\DeepBase\doQry\uDoQryLegacy.pas
**位置**: 第 756 行（`ExecuteAndGetResult`）

legacy 层用 `BuildSQL` 生成内联值的 SQL 字符串（值经 `QuoteValue`/`HandleParamValue` 拼入），`ExecuteAndGetResult` 失败时把 `aSQL` 原样塞进异常消息向上抛。这些值可能是聊天消息正文、用户 ID、分享链接等 PII，最终进入日志/错误对话框。

```delphi
raise EDatabaseException.CreateFmt('SQL执行错误: %s'#13#10'SQL: %s', [E.Message, aSQL]);
```

**建议修复**: 异常消息只保留错误本身与参数化占位 SQL（或仅表名/操作类型），完整 SQL 仅在 DEBUG 编译条件下输出，或经脱敏后记录。

---

### DATA-R3-007 [P3] — AddColumn 的 ColumnDef 原样拼入 DDL（防御性缺口）
**文件**: D:\_Progs\02Business\DeepBase\Persistence\DeepBase.Persistence.Manager.FireDAC.pas
**位置**: 第 216-223 行（`AddColumn`）

`TableName`、`ColumnName` 已经 `TSQLUtils.ValidateIdentifier` 校验，但 `ColumnDef`（如 `'TEXT DEFAULT ''LTR'''`）直接 `Format('ALTER TABLE %s ADD COLUMN %s %s', ...)` 拼入 DDL，无白名单。当前调用方（`Core/DeepBase.Manager.Schema.pas`）只传硬编码字面量，**目前不可利用**；但该方法在公共接口 `IManagerStorage.AddColumn` 上，任何未来调用方传入受外部影响的 `ColumnDef` 即引入 DDL 注入。

**建议修复**: 对 `ColumnDef` 做白名单校验（允许 `TEXT/INTEGER/REAL/BLOB/DEFAULT/NOT NULL`、数字、单引号字符串字面量），拒绝分号与 `--`；或将其改为强类型 `TColumnDef` 记录，从根本上杜绝任意字符串。

---

**未发现问题的文件（已验证干净）**: `Persistence.ORM.pas`（Where/OrderBy 参数化+标识符校验成立，`GetFullTableName` 来自编译期 `[Table]` 特性）、`DB.ConnectionPool.pas`（已 deprecated，且其 `Release` 脏连接问题与 DATA-R3-001 同源但属于遗留类，不重复列）、`DB.Guardian.pas`（Checkpoint 模式白名单、BackupTo 用 `QuotedStr` 转义）、`DB.Migrations.pas`（参数化、TOCTOU 读锁、savepoint/rollback 正确）、`DB.StatusMachine.pas`（`ValidateIdentifier`+`QuoteIdentifier`+事务回滚正确）、`DB.AutoRefreshConfig.pas`（共享连接加锁、标识符校验）、`DB.JobQueue.pas`（自动提交/savepoint 正确，归还前无残留事务）、`DB.DoQry.pas`（`TUniTransaction` 析构回滚、savepoint 嵌套正确）、`Persistence.{Exception,FormState,I18n,Config,LLM,Authorization,Theme,Logging,Security,Speech.Voiceprint,TestHelper,ORM}.FireDAC.pas`、`IntentClarification.Storage.pas`（均参数化、try/finally 释放正确）、`DeepAxis.BCryptDecrypt.pas`（密钥清零+随机临时路径+析构擦写删除成立）、`DeepAxis.SQLiteReader.pas`（`QueryPragmaInt` 仅以硬编码 `'schema_version'` 调用，schema 来源于 `sqlite_master`，`SafeQuery` 用白名单列名，`SafeQueryMessages` 分片上限正确）。
