# DeepBase Persistence 层深度代码审计报告（2026-09-18）

## 范围 / 日期 / 方法

- **审计日期**：2026-09-18
- **审计范围**：`d:\_Progs\02Business\DeepBase\Persistence\` 全部 33 个 `.pas` 单元（Glob/list_dir 核对清单，逐一全文读毕，累计约 15,000 行）；`sql\`（8 个 .sql）与 `Migrations\`（JobQueue 4 个方言对 + I18n 1 个）做索引级 schema 一致性抽查，不逐行审 SQL。
- **审计方法**：只读审计，未修改任何源码。逐单元全文审读，按 7 维度（①正确性 ②内存与生命周期 ③线程安全 ④异常处理 ⑤安全/注入 ⑥性能 ⑦架构/SSOT）分类；所有 Format/字符串拼 SQL 调用点逐一定位并判定（见附录 A）；严重度 🔴（崩溃/数据损坏/安全漏洞）/ 🟡（功能缺陷）/ 🔵（优化建议）；不确定项入存疑区。
- **前次审查标记沿用**：单元内既有 `DATA2-xxx / CR-xxx / REVIEW5-xxx / BASIC-xxx / BUG-xxx / DATA-R3-xxx / EXP-P1-xxx / HOTKEYS-001` 修复标记已核对，不重复报告已修复项。
- **重要事实修正**：`Key`/`Value` 在 PostgreSQL 为 unreserved keyword，可不加引号使用——早期草案中"Factory ReadSetting PG 保留字风险"一项经核实**撤销，不收录**。

## 总体统计

| 严重度 | 数量 | 说明 |
|---|---|---|
| 🔴 崩溃/数据损坏/安全漏洞 | 5 | 全部集中在 Pool.pas(3)、DoQry.pas(1)、SQLLogger.pas(1) |
| 🟡 功能缺陷 | 57 | 方言分支错误、竞态、异常吞噬、生命周期泄漏、schema 漂移等 |
| 🔵 优化建议 | 56 | 性能、可观测性、一致性、文档 |
| 存疑区 | 10 | 需运行时/调用点确认 |
| **合计（不含存疑）** | **118** | |

**按维度分布**（一条发现可跨维度，以主维度计）：①正确性 ~30（方言分支/SQL 语义/事务边界）②内存与生命周期 10（IC-01、ODB-01、DOQRY-06、POOL-01 等）③线程安全 13（POOL-03、SQLOG-01、DOQRY-04、SM-02 等）④异常处理 12（PROT-01、LOG-01、LLM-02、MIG-02 等）⑤安全：注入判定 33 单元全覆盖，**未发现可利用的 SQL 注入**（附录 A）；凭据/完整性问题 6（POOL-04、DOQRY-03、VP-01、VP-02、PROT-02、SQLOG 关联）⑥性能 14（N+1、无节流、O(n²)、锁内 I/O）⑦架构/SSOT 19（SCH-01..04、MIG 孤岛、双源 DDL、超 2000 行大文件 POOL-10）。**全维度均有覆盖，无空白维度**；Theme/Exception/RuntimeRegistration 等干净单元的具体无问题维度已在各单元节内逐条标注"未发现问题"。

**Top 5 🔴 速览**：Pool UAF（维护线程）、Pool 连接串错位、Pool 持锁网络 I/O、DoQry 连接清扫悬空指针、SQLLogger 锁外共享连接并发写。

---

## 按单元发现明细

### 1. DeepBase.DB.Pool.pas（2196 行）— 连接池核心

#### 🔴 POOL-01 维护线程 WaitTimeout 后 FreeAndNil → Use-After-Free
- **位置**：`d:\_Progs\02Business\DeepBase\Persistence\DeepBase.DB.Pool.pas:1066-1083`
- **代码**：
  ```pascal
  FMonitorThread.WaitFor(100);
  FreeAndNil(FMonitorThread);
  ```
- **说明**：`WaitFor(timeout)` 返回 `False`（线程未在超时内退出）时仍无条件 `FreeAndNil`。TFDThread 对象在其 Execute 仍在运行时被释放 → 维护线程访问已释放的 `Self`/`FPool` → AV 或堆损坏。
- **触发条件**：Shutdown 时维护线程恰好持锁或在长操作中，100ms 内未退出。
- **建议修复**：`if not FMonitorThread.WaitFor(5000) then` 记录并终止（Terminate+事件驱动），或循环等待；绝不释放仍 Active 的线程对象。

#### 🔴 POOL-02 LastDelimiter 未命中返回 0 而非 -1，守卫失效 → 连接串错位损坏
- **位置**：`DeepBase.DB.Pool.pas:1237-1254`
- **代码**：
  ```pascal
  Idx := LastDelimiter('=', S);
  if Idx < 0 then ...  // 永假：LastDelimiter 未命中返回 0，且 Delphi 中索引 0 也应视为未命中
  ```
- **说明**：`LastDelimiter` 未找到分隔符时返回 **0**（不是 -1），`Idx < 0` 分支永不执行；当值部分不含 `=` 之外的异常输入时，`Copy/Delete` 以 0 位点计算产生错位字符串，拼出的连接串参数名/值错乱，可能把密码写到错误键上或丢失 DriverID。
- **触发条件**：解析畸形/边界 ConnectionString（无 `=` 的片段）。
- **建议修复**：改 `if Idx <= 0 then`；补边界单测。

#### 🔴 POOL-03 持有 FLock 期间执行 CreateConnection 网络 I/O，阻塞全池
- **位置**：`DeepBase.DB.Pool.pas:1537-1561`
- **说明**：连接建立（TCP 握手、认证，PG 下可达秒级）在全池互斥锁内执行。任何一次扩容/重建期间，所有线程的 Acquire/Release/Validate 全部排队。对 PG 不可达场景，等待者被串行化到各自超时。
- **触发条件**：池耗尽扩新连接、或坏连接重建时数据库慢/不可达。
- **建议修复**：把 `CreateConnection` 移出锁（锁内仅登记"正在创建"占位），创建完成后二次入锁挂回。

#### 🟡 POOL-04 PG 连接串拼接明文密码
- **位置**：`DeepBase.DB.Pool.pas:985-989`
- **代码**：`'Password=' + FProfile.Password` 拼入 ConnectionString。
- **说明**：密码以明文进入连接串对象，随后可被 `ConnectionString` 属性读出并流入日志/缓存键（与 DOQRY-02 串联放大）。
- **触发条件**：使用共享 PG profile 时。
- **建议修复**：用 `Params.Password` 且设置后立即清空可回读属性，或接入 credman 引用（Factory 已有 ResolveSharedPassword 机制）。

#### 🟡 POOL-05 SetConnectionString 不重建 FProfile，属性对不一致
- **位置**：`DeepBase.DB.Pool.pas:1196-1202`（setter）与 `973-1002`（Build）
- **说明**：外部只更新连接串而 FProfile（UserName/Database 等）仍是旧值，两个信息源分叉；后续按 FProfile 重建的连接与刚设置的串不一致。
- **触发条件**：运行期调用 SetConnectionString。
- **建议修复**：setter 内反向解析重建 FProfile，或置 dirty 强制下次从串重建。

#### 🟡 POOL-06 Validate 无条件置 csIdle，可破坏借用态
- **位置**：`DeepBase.DB.Pool.pas:847-904`
- **说明**：后台/外部调用 Validate 时把状态强写回 csIdle，若该连接正被借用（csInUse），池认为其空闲 → 同一 TFDConnection 被二次发放，双线程并发用同一连接（FireDAC 连接非线程安全）→ AV/协议串扰。
- **触发条件**：Validate 与 Acquire 竞态，或 Validate 遍历包含在用连接。
- **建议修复**：仅 csReady/csBroken 允许 Validate 改状态；csInUse 跳过。

#### 🟡 POOL-07 ResetConnectionState 未判空 FPool
- **位置**：`DeepBase.DB.Pool.pas:823-844`
- **说明**：`FPool.xxx` 无 `Assigned(FPool)` 守卫，构造失败路径/析构后期调用即 AV。
- **触发条件**：初始化异常后仍调用复位。
- **建议修复**：加守卫或文档化调用前置。

#### 🟡 POOL-08 DoPoolEvent 持锁回调用户事件 → 死锁风险
- **位置**：`DeepBase.DB.Pool.pas`（DoPoolEvent，FLock 内调用 OnPoolEvent）
- **说明**：用户事件处理器若回调池 API（Acquire/Release/Shutdown），同线程重入 TCriticalSection 虽可重入不死锁，但**另一语义**：事件处理器触发对另一池/全局锁的等待而对方持本池锁 → 经典锁序死锁。
- **触发条件**：事件处理器做重操作。
- **建议修复**：事件在锁外排队异步派发。

#### 🔵 POOL-09 Shutdown 跳过 csInUse 连接（有注释，属已知取舍）
- **位置**：`DeepBase.DB.Pool.pas`（Shutdown 段）
- **建议**：加超时强制回收 + 泄漏告警。

#### 🔵 POOL-10 文件 2196 行，超 2000 行架构阈值
- **说明**：池管理/连接构建/参数解析/监视线程混在一元。建议拆出连接串构建（顺带消除与 Factory 的重复，见 FCT-02）。

**其余维度**：④中 POOL-01/06 即高危路径；其余异常处理未发现问题。

---

### 2. DeepBase.DB.DoQry.pas（1996 行）— 统一查询执行层

#### 🔴 DOQRY-01 UniDbSweepConnectionFromPool 跳过 InUse>0 条目 → 悬空指针地址复用误命中
- **位置**：`DeepBase.DB.DoQry.pas:1871-1921`
- **说明**：清扫时跳过 `InUse>0` 的池条目不注销其 `Entry.Connection` 指针，但连接对象随后被 Free；新 TFDConnection 实例恰好复用同一堆地址时，`Entry.Connection` 假命中旧元数据 → 对错误连接执行操作或 AV。
- **触发条件**：连接归还与清扫交错 + 堆地址复用（高频开关连接时概率可观）。
- **建议修复**：Free 前无条件从 DoQry 侧登记表删除映射；或给连接挂 Tag 代校验。

#### 🟡 DOQRY-02 TryLoadQueryDef 吞真实 DB 错误统一报 "not found"
- **位置**：`DeepBase.DB.DoQry.pas:1080-1096`
- **说明**：表不存在/权限/连接断都归为"查询定义未找到"，掩盖故障根因。
- **建议修复**：区分 EFDExecSQL 的 SQLState/错误码，仅 42S02/no such table 归为 not found。

#### 🟡 DOQRY-03 DbIdOfConn 回退用含明文密码的 ConnectionString 作缓存 key
- **位置**：`DeepBase.DB.DoQry.pas:1067-1078`
- **说明**：缓存键入内存驻留明文密码，且异常打印键值会泄密（与 POOL-04 同源放大）。
- **建议修复**：用 Host+Database+User+连接句柄散列作 key。

#### 🟡 DOQRY-04 GPreparedPoolEnabled 非原子读改写 → 池内悬空 TFDQuery
- **位置**：`DeepBase.DB.DoQry.pas:1452-1506`
- **说明**：开关切换与归还预编译语句竞争，池销毁后仍有线程向旧池 Free 语句对象；双重释放/悬空。
- **建议修复**：InterlockedExchange + 池引用计数回收。

#### 🟡 DOQRY-05 UniDbInsertReturningId PG 硬编码 `RETURNING id`；Pos('RETURNING') 误判字面量
- **位置**：`DeepBase.DB.DoQry.pas:1579-1709`
- **说明**：主键列非 `id` 时失败；SQL 文本含字符串字面量 `'...RETURNING...'` 时误判为已带 RETURNING 跳过追加 → 拿不到生成键。
- **建议修复**：主键名参数化传入；用解析器（TFDStanSQLParser）判断而非 Pos。

#### 🟡 DOQRY-06 UniDbSelect 异常路径 Data 所有权两难
- **位置**：`DeepBase.DB.DoQry.pas:1480-1481`
- **说明**：Open 失败已创建的 TFDQuery/Data 在异常路径不释放（调用方拿不到指针），或释放后调用方又引用——当前为前者：泄漏。
- **建议修复**：except 中 Free 并 nil 出参。

#### 🔵 DOQRY-07 每次执行后 Unprepare → 预编译池形同虚设
- **位置**：`DeepBase.DB.DoQry.pas:1468/1540/1650/1739`
- **建议**：由池持有 prepared 语句，删行内 Unprepare。

#### 🔵 DOQRY-08 DEBUG 级日志落全量 SQL+Params
- **位置**：`DeepBase.DB.DoQry.pas:740-774`
- **说明**：参数可能含 PII/凭据；DEBUG 开启时全量入库（联动 SQLLogger）。
- **建议**：参数值脱敏。

**⑤其余**：Savepoint 名自产 GUID、查询定义取常量表——拼 SQL 判定见附录 A，均安全。

---

### 3. DeepBase.DB.JobQueue.pas（1411 行）— 任务队列

#### 🟡 JQ-01 FConnAvailableEvent 自动重置，4 槽位并发 SetEvent 只唤醒 1 个等待者
- **位置**：`DeepBase.DB.JobQueue.pas:201`（TEvent.Create(nil, False, ...)）
- **说明**：手动-重置缺失（autoreset=False 参数义为自动重置）；归还多个空闲槽只通知一个等待线程，其余白等超时。
- **触发条件**：并发归还 + 排队等待。
- **建议修复**：改手动重置事件，归还计数>0 时 SetEvent，取得后按余量决定是否复位。

#### 🟡 JQ-02 池耗尽最坏阻塞约 5.5 分钟
- **位置**：`DeepBase.DB.JobQueue.pas:328-332`
- **说明**：AcquireConnection 重试次数×等待叠加，调用线程（可能 UI）长时间冻结。
- **建议修复**：总超时预算 + 提前失败。

#### 🟡 JQ-03 BeginOwnWriteTransaction 裸 `BEGIN IMMEDIATE` 与 FireDAC 事务混用
- **位置**：`DeepBase.DB.JobQueue.pas:441-457`
- **说明**：绕过 FireDAC 事务管理层，InTransaction 状态与驱动内部标志不同步；PG 分支该语句语义完全不同（PG 无 IMMEDIATE），出现不对称行为。
- **建议修复**：统一 StartTransaction + 方言化隔离级设置。

#### 🟡 JQ-04 RecycleDeadTasks：INSERT…SELECT 与 DELETE…SELECT 非同一原子语句 → PG READ COMMITTED 幽灵死信
- **位置**：`DeepBase.DB.JobQueue.pas:868-954`
- **说明**：两条语句间新满足条件的行被 DELETE 捕获但未进 DLQ → 任务丢失；或并发双回收重复入 DLQ。
- **建议修复**：PG 用 `DELETE ... WHERE id IN (SELECT ... FOR UPDATE SKIP LOCKED) RETURNING` 单语句；SQLite 包 BEGIN IMMEDIATE。

#### 🟡 JQ-05 TTaskRec.Clear 不 Free Payload，释放责任未文档化
- **位置**：`DeepBase.DB.JobQueue.pas:165-177`
- **说明**：Payload 若为堆对象则泄漏或由调用方误双重释放。
- **建议修复**：接口注释明示所有权；或改 managed 字段。

#### 🟡 JQ-06 EnsureSchema 代码内 DDL 与 Migrations/JobQueue/*.sql 双源
- **位置**：`DeepBase.DB.JobQueue.pas:561-600`（EnsureSchemaOnConnection）vs `Migrations\JobQueue\002_create_dlq_table.up.{pg,sqlite}.sql`
- **说明**：三处方言对（代码/pg/sqlite）需人肉同步；Migration 引擎未接入生产（见 MIG-01/SCH-01），实际以代码为准，SQL 文件漂移无人验证。
- **建议修复**：单一来源（代码生成 SQL 文件，或引擎接管 + CI 校验）。

#### 🔵 JQ-07 AcquireConnection 持锁创建连接（同 POOL-03 模式）
- **位置**：`DeepBase.DB.JobQueue.pas:294-318`

#### 🔵 JQ-08 Fail() 的 lookup+UPDATE 非原子
- **位置**：`DeepBase.DB.JobQueue.pas:1043-1118`
- **建议**：条件 UPDATE 单语句化。

**⑤**：全单元 SQL 均参数化+标识符白名单（ValidateLogicalKey/ValidateTaskID），未发现问题。

---

### 4. DeepBase.ORM.pas（1519 行）— 轻量 ORM

#### 🟡 ORM-01 Count() 拼接 FOrderByClause → `SELECT COUNT(*) ... ORDER BY` 两库皆错
- **位置**：`DeepBase.ORM.pas:991-1005`
- **代码**：Count 复用带 ORDER BY 的选择 SQL 前缀。
- **说明**：PG 直接报错（ORDER BY 表达式不在聚合中）；SQLite 容忍但浪费排序。若 FOrderByClause 引用列在 DISTINCT 下也出错。
- **触发条件**：设置排序后调用 Count。
- **建议修复**：Count 路径剥离 ORDER BY。

#### 🟡 ORM-02 TableExists&lt;T&gt; 硬编码 sqlite_master，PG 恒 False
- **位置**：`DeepBase.ORM.pas:1503-1511`
- **触发条件**：共享 PG 连接上调用。
- **建议修复**：按 DriverID 分支 information_schema.tables。

#### 🟡 ORM-03 CreateTable&lt;T&gt; DDL 纯 SQLite 方言（AUTOINCREMENT/DATETIME）
- **位置**：`DeepBase.ORM.pas:1408-1431`
- **说明**：PG 无 AUTOINCREMENT 关键字 → 建表失败；且与 ORM-02 组合后 PG 下"永不存在→尝试建表→建表报错"。
- **建议修复**：方言映射（BIGSERIAL/TIMESTAMP）或声明 SQLite-only。

#### 🟡 ORM-04 Where(cond) 无参重载不清空 FWhereParams → 参数错位
- **位置**：`DeepBase.ORM.pas:860-866`
- **代码**：
  ```pascal
  function Where(const ACondition: string): TQueryBuilder<T>; overload;
  begin
    FWhereConditions.Add(ACondition);  // 未 FWhereParams.Clear
  ```
- **说明**：混用 `Where(cond)` 与 `Where(cond, params)` 时旧参数残留，按位置绑定错值——静默返回错误数据，属数据正确性缺陷。
- **建议修复**：无参重载中 `FWhereParams` 补 Null 占位或清空并文档化。

#### 🟡 ORM-05 Select(Columns) 任意字符串直拼 SELECT 列表
- **位置**：`DeepBase.ORM.pas:943-947`
- **说明**：Columns 未过 ValidateSQLIdentifier 即拼接。当前仓内调用方均为常量（存疑区 SV-02 待全量确认）；作为 public API 属注入面。
- **建议修复**：逗号拆分后逐个 ValidateSQLIdentifier。

#### 🔵 ORM-06 And/OrWhere 平铺拼接无括号 → 混合 OR/AND 优先级陷阱（L842-902）
#### 🔵 ORM-07 RowsAffected=0 抛 EConcurrencyException 语义误导（L1256-1258，行不存在≠版本冲突）
#### 🔵 ORM-08 TMetadataCache 持锁内做 RTTI 扫描（L567-588，首用序列化）

**⑤防御正面记录**：ValidateSQLIdentifier/IsSafeDDLDefaultValue 白名单守卫 ✅。

---

### 5. DeepBase.DB.Factory.pas（490 行）— 连接工厂

#### 🟡 FCT-01 LoadSharedProfile N+1：每次调用新建连接 + 6-10 条单行查询
- **位置**：`DeepBase.DB.Factory.pas:108-179`
- **建议**：一条 JOIN/多语句批取 + profile 缓存。

#### 🔵 FCT-02 BuildConnectionFromProfile 与 Pool.pas:1284-1335 重复实现（SSOT 漂移）
- **说明**：两份 profile→连接串装配，Pool 版多 `TxOptions.AutoCommit` 处理——同名语义两个真相源，修复易漏一侧。
- **建议**：收敛到 Factory 单点。

#### 🔵 FCT-03 class var（默认 profile 等）无同步读写
#### 🔵 FCT-04 VerifyBoth 异常吞栈信息
#### 🔵 FCT-05 WriteSetting `INSERT OR REPLACE` 为 SQLite-only；当前仅本地 SQLite 上下文调用 ✅，但 public 方法被 PG 连接调用即语法错——建议文档化或方言分支。

**⑤**：全单元 SQL 参数化 ✅；GetLocal/GetShared **每次新建已打开连接、调用方负责 Free**（L309-317）——该契约是 IC-01 泄漏判定依据；ResolveSharedPassword 凭据路径（credman:/DB3_PASSWORD）设计合理。

---

### 6. DeepBase.DB.ConnectionPool.pas（439 行，[deprecated]）

#### 🟡 CP-01 无连接有效性验证、无脏事务复位：归还带未提交事务的连接直接传染下一借用者
- **位置**：Release/Acquire 路径（全文件无 InTransaction/Rollback 处理）
- **说明**：与新版 DB.Pool 相比缺失防护；单元已标 deprecated 但仍编译发布。
- **建议修复**：从 dpk 移除或加编译期告警；若保留则归还时 `if InTransaction then Rollback`。

#### 🟡 CP-02 借用无并发上限/等待机制（忙标记非原子）
#### 🔵 CP-03 预热失败静默吞（L188-201）

**⑤**：无拼 SQL，未发现问题。**⑦**：与 Pool.pas 功能重叠属架构双源（记入 SCH-01 关联）。

---

### 7. DeepBase.DB.Guardian.pas（591 行）— 数据库守护/备份/完整性

#### 🔵 GRD-01 L479 `DBPath := AConn.Params.Database` 无驱动守卫
- **位置**：`DeepBase.DB.Guardian.pas:479`
- **说明**：PG 连接时该值是主机/库名，按文件路径做 TFile.Exists/VACUUM INTO 全部失义，报错信息与意图无关。
- **建议修复**：`DriverID<>SQLite` 时显式 raise 'Guardian supports SQLite only'。

#### 🔵 GRD-02 BackupTo 先 Delete 旧备份再 Move 非原子（L301-304）：中途崩溃新旧备份双失
- **建议**：Move 到临时名成功后再删旧文件。

#### 🔵 GRD-03 PRAGMA 失败仅 OutputDebugString 不入 Logger（L195-200）

**⑤**：checkpoint 模式白名单（L266）、VACUUM INTO QuotedStr（L297）——注入安全 ✅。①②③④⑥⑦ 其余未发现问题。

---

### 8. DeepBase.DB.Migrations.pas（713 行）— 迁移引擎

#### 🟡 MIG-01 OwnTransaction=False 时每脚本不原子提交，且 SQLite 裸 BEGIN 与 FireDAC StartTransaction 双轨混用
- **位置**：`DeepBase.DB.Migrations.pas:142-187`
- **说明**：调用方已开事务时引擎放弃自管理，脚本中途失败由外层回滚，但**已记录的 migration 历史行与脚本变更同生共死依赖外层边界正确性**；同时 SplitSQLStatements 禁事务语句的策略（L691 附近）在两条路径下不一致。
- **建议修复**：外层事务路径下用保存点包裹单脚本。

#### 🔵 MIG-02 Run 吞所有异常到 Result.LastError（L192-197），调用方不检查即静默失败
#### 🔵 MIG-03 EnsureMigrationTable（L113）先于 advisory lock（L117）：并发首跑两节点同时建表可竞争（IF NOT EXISTS 下良性，但 PG 会抛 duplicate object 于极窄窗口）

**正面**：SHA256 checksum、双重 AlreadyApplied（TOCTOU 闭合，REVIEW5-DATA-006）、advisory lock 742030451、dollar-quote/trigger-END 感知分割、禁用脚本内事务语句——设计成熟 ✅。

#### ⚠️ 关联发现（SCH-01）：全仓 Grep 证实 `DeepBase.DB.Migrations` 仅被 Tests 与 dpk 引用，**生产启动路径未接线**——迁移引擎是"孤岛能力"，schema 演进实际依赖散落各单元的 EnsureSchema DDL（见存疑区 SV-01：`TDirectory.GetFiles` 非递归 L279 只有接入后才会暴露 Migrations/I18n、Migrations/JobQueue 子目录被跳过的问题）。

---

### 9. DeepBase.DB.StatusMachine.pas（504 行）— 状态机持久层

#### 🟡 SM-01 QuoteIdentifier 把 "schema.table" 整体引成单一标识符，与刚修复的 DOT 校验自相矛盾
- **位置**：`DeepBase.DB.StatusMachine.pas:237-250`，对照 L201-229
- **代码**：
  ```pascal
  // L201-229: 校验允许一个 DOT（schema.table）
  // L237-250: Result := '"' + StringReplace(Name,'"','""',rfAll) + '"'
  ```
- **说明**：L201-229 特意放行 schema 限定名，L237 却又把 `public.orders` 引成 `"public.orders"` 单标识符 → PG 报 relation "public.orders" does not exist。两段代码互为矛盾，schema 限定表**必然**失败。
- **触发条件**：表名传 `schema.table`。
- **建议修复**：按 DOT 拆分后逐段引号。

#### 🟡 SM-02 SQLite 下 Transit 读-判断-写无行锁 → 并发双通过同一 guard（TOCTOU）
- **位置**：`DeepBase.DB.StatusMachine.pas:342-345`
- **代码**：`if IsPostgreSQL then ... FOR UPDATE`（SQLite 无分支）
- **说明**：PG 有行锁，SQLite 依赖库级写锁但 SELECT 与 UPDATE 间仍可被交错（WAL deferred 事务）→ 两个并发迁移同时通过前置状态校验，状态历史出现分叉损坏。
- **触发条件**：多进程/多线程同键并发 Transit（SQLite 共享文件）。
- **建议修复**：SQLite 用 `BEGIN IMMEDIATE` 包裹整个读-判断-写；或迁移引擎同款的 advisory 序列化。

#### 🔵 SM-03 Guard() 用户回调持 PG 行锁执行（L396），慢回调放大锁持有
#### 🔵 SM-04 FLastHeartbeats 字典无界增长（L50/L464）

**⑤**：SQL 全参数化 + ValidateIdentifier/QuoteIdentifier——除 SM-01 语义缺陷外注入安全 ✅。

---

### 10. DeepBase.DB.AutoRefreshConfig.pas（476 行）

#### 🟡 ARC-01 缓存刷新令牌 = MAX(updated_at)，SQLite CURRENT_TIMESTAMP 秒精度 → 同秒二次修改缓存永不刷新
- **位置**：`DeepBase.DB.AutoRefreshConfig.pas:405-407`
- **说明**：SQLite 的 CURRENT_TIMESTAMP 只到秒；同一秒内两次写配置，第二次令牌与缓存相同 → 客户端读到旧值且不再刷新（静默脏读）。
- **建议修复**：令牌改 `COUNT(*)||MAX(rowid)` 或写入方显式带毫秒。

#### 🔵 ARC-02 构造器错误消息错位（L166-168：检查 Assigned(ConnectionProvider) 却报 "returned nil connection"）
#### 🔵 ARC-03 EnsureCacheFresh 每次 GetValue 都发 MAX 查询，无节流

**⑤**：L343/364 Format 拼标识符前均有 ValidateIdentifier/ValidateQualifiedIdentifier 白名单——注入安全 ✅。③：FLock 全序列化（DATA2-056）✅。

---

### 11. DeepBase.SQLLogger.pas（853 行）— SQL 日志

#### 🔴 SQLOG-01 WriteToDatabase 在 FLock 外用共享 FConnection 并发 INSERT → FireDAC 连接非线程安全，可致 AV/语句串扰
- **位置**：`DeepBase.SQLLogger.pas:354-358`
- **代码**：
  ```pascal
  finally
    FLock.Leave;
  end;
  // DATA2-051: 锁内仅快照指针，DB 写在锁外
  if Assigned(LConn) then WriteToDatabase(LConn, LRec);
  ```
- **说明**：DATA2-051 把慢 I/O 移出锁是对方向，但 `LConn` 是**同一单元级单例连接**，两线程同时在它上面 ExecSQL：FireDAC TFDConnection 不支持并发 → 参数串扰（日志写错行）或 AV。与头注释 "Thread-safe operations" 宣称直接矛盾。
- **触发条件**：并发开启 DB 日志。
- **建议修复**：每线程独立连接，或写入队列+专职落库线程。

#### 🟡 SQLOG-02 WriteToFile 锁外 AssignFile/Append 并发写同一文件失败被吞 → 日志静默丢失
- **位置**：`DeepBase.SQLLogger.pas:355-356`
- **建议**：文件写与 DB 写共用同一条列化通道。

#### 🔵 SQLOG-03 FEnabled 无锁读（L293）
#### 🔵 SQLOG-04 MachineName 恒 ''（L639）

**正面**：L625 INSERT 常量+参数 ✅；DATA2-049 日志注入防护、CR-229 方言分表 ✅。**存疑**：finalization 释放 FLock 后其他单元 finalization 期调 LogSQL 的关闭窗口 AV（SV-04）。

---

### 12. DeepBase.Persistence.Authorization.FireDAC.pas（861 行）

#### 🟡 AUTH-01 L705 `INSERT OR IGNORE INTO auth_user_roles` — 本单元处处 IsPostgreSQL 分支支持 PG（RETURNING/BIGSERIAL/TRUE-FALSE），唯独此处 SQLite-only 语法 → PG 共享库上分配用户角色直接语法错
- **位置**：`DeepBase.Persistence.Authorization.FireDAC.pas:705`
- **触发条件**：PG 后端调用 AssignRole。
- **建议修复**：PG 分支 `ON CONFLICT DO NOTHING`。

#### 🟡 AUTH-02 auth_* 表 DDL 代码常量（L89-190）与 sql/*.sql 双源
- **说明**：schema 事实源在代码；sql/ 目录对应定义已 DEPRECATED（见 SCH-01），漂移无校验。

#### 🟡 AUTH-03 CURRENT_TIMESTAMP 时区语义跨方言失真：SQLite=UTC、PG=服务器本地时区
- **位置**：InsertAudit / ClearAuditBefore 与本地 TDateTime 字符串比较
- **说明**：审计裁剪按字符串时间窗比较，跨方言迁移后 ClearAuditBefore 可能多删/漏删。
- **建议修复**：统一 UTC 显式写入（`timezone('UTC', now())` / `strftime('%Y-%m-%dT%H:%M:%SZ','now')`）。

#### 🔵 AUTH-04 ReadAudit 结果集 SetLength+1 追加 O(n²)（L251）
#### 🔵 AUTH-05 单元无内部锁，线程安全责任在调用方但未文档化

**⑤**：其余全参数化；ReadAudit 动态 WHERE 为固定片段+参数——注入安全 ✅。CR-014/DATA2-025 事务所有权跟踪正确。

---

### 13. DeepBase.Persistence.Manager.FireDAC.pas（461 行）

#### 🟡 MGR-01 L331 `INSERT OR REPLACE INTO ProjectInfo` SQLite-only，本单元含 IsPostgreSQL 分支 → PG 语法错（与 AUTH-01 同模式）
- **位置**：`DeepBase.Persistence.Manager.FireDAC.pas:331`
- **建议**：ON CONFLICT DO UPDATE（并顺带修复 OR REPLACE 清兄弟列问题，参照 CR-008 在 Config 的处理）。

#### 🔵 MGR-02 UpdateSchemaInfo 只 UPDATE 无 INSERT（L280-286），行缺失静默无效
#### （入存疑 SV-03，不计数）MGR-03 ExecuteStatement 直通任意 SQL（L157-173）——攻击面取决于调用方输入面

**⑤正面**：L103-117 BuildQuotedList(QuotedStr)、L200 pragma 前 ValidateIdentifier、L220-231 AddColumn 三重校验（DATA-R3-007）——注入安全 ✅。②：异常路径 Result.Free、Guardian 集成 ✅。

---

### 14. DeepBase.Persistence.Diagnose.FireDAC.pas（743 行）— 自检诊断

#### 🟡 DIAG-01 整体 SQLite-only（sqlite_master L179/L219、PRAGMA L198），无 PG 分支 → PG 共享连接上 TableExists 恒 False，全部检查被跳过，DiagnoseAll 返回"假绿"
- **位置**：`DeepBase.Persistence.Diagnose.FireDAC.pas:179/198/219`
- **说明**：诊断系统在最需要它的服务器部署上静默不工作。
- **建议修复**：information_schema 分支；无分支时至少返回显式 unsupported。

#### 🟡 DIAG-02 CheckIndexesExist 直接返回空数组（L406-409）——索引检查恒绿的实现空洞
#### 🔵 DIAG-03 FK 检查 `<> ''` 对 INTEGER FK 恒真（L440，SQLite 类型类别序）
#### 🟡 DIAG-04 REQUIRED_COLUMNS 46 列常量 + DeepBase.Schema + sql/*.sql 构成 Logs 表三重信息源（SSOT，计入 SCH-01 口径）

**⑤**：所有 Format 拼接先 ValidateIdentifier、L580 ValidList 为常量表——注入安全 ✅。DATA-R3-004/CR-238 正面。①③④⑥ 其余未发现问题。

---

### 15. DeepBase.Persistence.HBTelemetry.FireDAC.pas（762 行）

#### 🔵 HBT-01 GetInstance 双检锁无内存屏障（L447-460，FInstance 锁外读）
#### 🔵 HBT-02 头注释宣称 "auto-purge 7-day TTL" 但 hb_evidence 无 purge 实现——文档漂移
#### 🔵 HBT-03 L357 对含 managed 字段记录 FillChar

**正面**：⑤全参数化 ✅；PersistEvidence 事务包裹批量插入 ✅；全方法 FLock 序列化 ✅；L298 Flush 吞异常有 best-effort 注释（④可接受）。①②⑥⑦ 其余未发现问题。

---

### 16. DeepBase.Persistence.Logging.FireDAC.pas（433 行）

#### 🟡 LOG-01 WriteLog 主 INSERT **任意异常**都落入 legacy 回退（L198-224）
- **代码**：
  ```pascal
  FInsertQuery.ExecSQL;
  except
    // Backward compatibility: allow old schema without "Extra" column.
    EnsureLegacyInsertQuery;
  ```
- **说明**：注释意图仅兼容缺 Extra 列，实际捕获全部异常：连接断开（EnsureConnection L79 只查 Assigned 不查 Connected、无 AutoReconnect）后每条日志走两条注定失败的路径，最终 raise 给日志调用方——日志组件把 DB 故障转嫁给业务线程。
- **触发条件**：长驻应用 SQLite 文件被占用/磁盘满。
- **建议修复**：仅当错误为 "no such column: Extra" 时回退；连接层加 Connected 重连。

#### 🔵 LOG-02 LogLevelCaseExpression ELSE 1：未知级别文本按 INFO 参与过滤（L174-186）
#### 🔵 LOG-03 ReadRecent 每次 3 遍 PRAGMA table_info 无缓存（L329-331）

**⑤**：SQL 全参数化、OrderBy 常量（`Id DESC`/`LogTime DESC`）——注入安全 ✅。③FLock 序列化 ✅。

---

### 17. DeepBase.Persistence.LLM.FireDAC.pas（281 行）

#### 🟡 LLM-01 PrepareQuery 中 FindParam 未命中静默跳过（L72-117）
- **代码**：
  ```pascal
  LParam := Query.Params.FindParam('IsEnabled');
  if Assigned(LParam) then LParam.AsBoolean := ...
  ```
- **说明**：SQL 里参数名拼错/改名后，过滤条件**整体消失**且无告警——如 IsEnabled/IsDefault 过滤器失效，可能返回停用/非默认配置（数据可见性扩大）。
- **建议修复**：未命中 raise 或至少 Log warning。

#### 🟡 LLM-02 TableExists except 吞全部异常返回 False（L214-216）→ LLM 模块误判"表不存在"跳过功能
#### 🔵 LLM-03 OpenDataSet 所有权移交调用方未在接口注释声明（L120-133）

**⑤**：L226-228 ValidateIdentifier（DATA2-018）、L233 `SELECT * WHERE 1=0`、bool 方言分支（L83-95）——注入安全 ✅。

---

### 18. DeepBase.Persistence.License.FireDAC.pas（289 行）

#### 🔵 LIC-01 DPAPI 解密失败两处 except 静默返回 ''（L88-93/L218-222），丢失失败原因（换机/权限组变化 vs 数据损坏不可区分）

**正面**：⑤L81/121/146/211/250/275 全部常量 SQL+字面量 key+命名参数——注入安全 ✅；DPAPI 加密 license_key/snapshot；CR-008 upsert ON CONFLICT。①②③④⑥⑦ 其余未发现问题。

---

### 19. DeepBase.Persistence.MRU.FireDAC.pas（332 行）

#### 🟡 MRU-01 Upsert 的 SELECT-then-INSERT 事务包裹（DATA2-019，L77-128）在 PG READ COMMITTED 下仍不能阻止并发同键双 INSERT → unique 冲突抛给调用方
- **位置**：`DeepBase.Persistence.MRU.FireDAC.pas:86-102`
- **说明**：tier1 schema 有 `UNIQUE(Category, ItemKey)`（本次 SQL 抽查证实），事务只扩大 SQLite 持锁窗口，PG 下两事务各自 select 空后 insert 其一必然约束冲突。MRU 是高频路径（每次打开文件）。
- **建议修复**：`INSERT ... ON CONFLICT(Category, ItemKey) DO UPDATE SET AccessCount = MRU.AccessCount + 1, ...` 单语句，顺带消除读往返。

#### 🔵 MRU-02 LastAccess ISO8601 解析失败 except→Now（L199-204），掩盖坏数据

**⑤**：全参数化 ✅。②DATA-R3-005 事务所有权跟踪正确 ✅。

---

### 20. DeepBase.Persistence.Hotkeys.FireDAC.pas（357 行）

#### 🟡 HK-01 RegisterDefaults 循环 ExecSQL 无事务包裹（L203-213）：中途失败留下部分默认键，且 N 次 fsync
- **建议修复**：批外包 StartTransaction/Commit。

#### 🔵（方言注记）L200 `INSERT OR IGNORE INTO Hotkeys`：Hotkeys 为本地 SQLite 表（upgrade_hotkeys_column.sql 证实），无 PG 分支属一致设计，不判缺陷；若纳入共享库需改造。

**⑤**：全参数化；ActionName 走参数 ✅。L30-97 TextToShortCut 纯函数无问题。①②④⑥⑦ 其余未发现问题。

---

### 21. DeepBase.Persistence.Speech.Voiceprint.FireDAC.pas（357 行）

#### 🟡 VP-01 HMAC 密钥 = SHA256(owner_app + #0'voice_profiles_hmac_v1')——由公开字符串派生，非机密（L102-109）
- **说明**：任何读得源码/知悉方案者可对篡改后的声纹 BLOB 重算合法 HMAC → 生物特征完整性校验形同虚设（声纹属个人生物特征数据，篡改检测是其存在意义）。
- **建议修复**：密钥入 DPAPI/Secrets（本仓已有 Security.Secrets 通道），至少用 per-install 随机盐。

#### 🟡 VP-02 stored HMAC 为空即跳过校验（L227）：删除 features_hmac 值即永久绕过完整性检查
- **建议**：空 HMAC 视为校验失败。

#### 🟡 VP-03 SaveProfile UPDATE→INSERT 无事务包裹（L265-330）：并发首存竞态双 INSERT（profile_id 主键冲突抛出或按分支互相覆盖）
#### 🔵 VP-04 created_at 写本地时间字符串、读回 ISO8601ToDate 时区语义混（L182/L291）
#### 🔵 VP-05 每个公开入口执行 EnsureSchema DDL（L96-100 委派 DeepBase.Speech.Schema，见 SSP-01）

**⑤正面**：L167/210/269/300/345 全部常量+命名参数——注入安全 ✅。
**修正**：前次疑心的"Voiceprint 内嵌 DDL 与 Speech.Schema 双源"经 Grep 证实**不成立**——adapter 直接委派 Schema 单元，单一来源 ✅。

---

### 22. DeepBase.Persistence.Config.FireDAC.pas（228 行）

#### 🟡 CFG-01 WriteValue 用了方言可移植的 ON CONFLICT(Key) DO UPDATE（CR-008），却引用 SQLite-only 的 `datetime('now')`（L94）→ PG 下报 function datetime does not exist
- **位置**：`DeepBase.Persistence.Config.FireDAC.pas:86-94`
- **说明**：CR-008 修复方向正确但只改了一半——本方法成为"看起来支持 PG、实际 PG 必炸"的陷阱。
- **建议修复**：`CURRENT_TIMESTAMP`（两库通吃）或按 DriverID 分支。

#### 🟡 CFG-02（归入 SCH 交叉节）Settings 表兄弟列（DefaultValue/IsReadOnly/…）在代码注释与 deprecated SQL 间漂移。

**⑤**：全参数化 ✅。①②③④⑥ 其余未发现问题；⑦见 SCH-01。

---

### 23. DeepBase.Persistence.I18n.FireDAC.pas（259 行）

#### 🟡 I18N-01 RecordMissingTranslation `INSERT OR IGNORE`（L117）SQLite-only——同单元 UpsertTranslation（L219-224）已用可移植 ON CONFLICT，同文件内方言策略自相矛盾
- **建议**：L117 改 `ON CONFLICT(SourceText, LangCode) DO NOTHING`（tier0 schema 的 UNIQUE 约束本次抽查证实存在，两库语义一致）。

#### 🔵 I18N-02 RecordMissingTranslation INSERT+UPDATE 两条语句无事务（L116-130）：并发下计数语义无碍，仅多一次往返
#### （存疑 SV-05，不计数）`IsEnabled = 1`/`SELECT *`（L153-155）：若未来 PG schema 用 BOOLEAN 列则比较失败；当前可见 schema 全 INTEGER，不判缺陷。

**⑤**：全参数化 ✅。UpsertTranslation 的 ON CONFLICT 目标列唯一约束已在 tier0_init.sql:107 核对存在 ✅（解除前次存疑）。

---

### 24. DeepBase.Persistence.Theme.FireDAC.pas（107 行）

**7 个维度均未发现问题**。SQL 为常量+无用户输入（L56-58），⑤注入安全 ✅；生命周期（Query/List try-finally）✅。仅注记：与 MRU 同模式的无锁 adapter（依赖调用方单线程使用，全仓 adapter 通则，计入 SCH-07）。

### 25. DeepBase.Persistence.Exception.FireDAC.pas（91 行）

单元自身 7 维度未发现问题（⑤单条参数化 INSERT ✅）。
**但其列名与 sql/tier2_init.sql 冲突**：代码写 `(ReportTime, ExceptionClass, Message, StackTrace)`，schema 文件定义 `OccurredAt/ExceptionMessage` 且无 ReportTime/Message 列 → 见 SCH-03。

### 26. DeepBase.Persistence.FormState.FireDAC.pas（215 行）

#### 🔵 FS-01 L58 `INSERT OR REPLACE`（本地表，方言注记，同 HK 模式）
#### 🔵 FS-02 ReadFormNames SetLength+1 O(n²)（L163-168）

⑤全参数化 ✅；①②③④⑥⑦ 其余未发现问题。

### 27. DeepBase.Persistence.ORM.FireDAC.pas（200 行）— IORMStorage 实现

#### 🟡 ODB-01 PrepareQuery 异常路径泄漏 TFDQuery（L106-116）
- **代码**：`Result := TFDQuery.Create(nil); ... Result.Params[I].Value := Params[I];`
- **说明**：参数索引越界（Params.Count < 传入个数）或 Variant 类型转换抛错时，函数 Result 尚未移交调用方即异常退出，已创建的 TFDQuery 永久泄漏（挂在 FConnection 上还可能持有服务端语句游标）。
- **触发条件**：调用方 SQL 参数个数与 Params 数组不匹配（ORM.pas Where 重载混用即可产生，联动 ORM-04）。
- **建议修复**：`try ... except Result.Free; raise end`（同 LLM adapter 的写法）。

#### 🟡 ODB-02 BeginTransaction 无嵌套/已开事务防护（L164-167 + L56-66）
- **说明**：连接上已有活动事务时第二个 TFireDACORMTransaction 构造内 `StartTransaction` 抛 EFDTransError，异常类型/语义未适配 IORMTransaction 契约；调用方按 using 模式包嵌套即崩。
- **建议修复**：InTransaction 时抛带业务语义异常或 savepoint 支持。

#### 🔵 ODB-03 位置式参数绑定 `Params[I]`（L114-115）：同名参数复用（Security 单元 :Name/:Name2 即为绕法）与乱序 SQL 脆弱
#### 🔵 ODB-04 OpenDataSet 所有权移交无文档（L132-145）

**GetLastAutoGenValue（L169-173）**：直通 `FConnection.GetLastAutoGenValue`——同连接同会话内 PG 可用；但池语义下"Insert 与取键必须同一连接"的约束未在接口声明（存疑 SV-06，联动 ORM.pas Insert）。
**②正面**：TFireDACORMTransaction 析构自动回滚未 Commit 事务 ✅（RAII 正确）。**⑤**：无拼 SQL ✅。

### 28. DeepBase.Persistence.Security.FireDAC.pas（219 行）

#### 🔵 SEC-01 UpsertSecret `INSERT OR REPLACE` + COALESCE 子查询保 CreatedAt（L104-109）：SQLite-only（密文表设计为本地，一致，方言注记）；OR REPLACE 换行会重置 Id 类副作用当前 schema 无受影响列
#### 🔵 SEC-02 EnsureSecretsTable 代码内 DDL（L55-63）为该表唯一来源，未入任何 sql/Migrations（SSOT 单点但游离于迁移体系外）

**⑤**：拼 SQL 仅 `STableSecrets` 常量（DeepBase.Consts）——注入安全 ✅；密文 base64 存储，明文不出内存 ✅。①②③④⑥⑦ 其余未发现问题。

### 29. DeepBase.Persistence.TestHelper.FireDAC.pas（153 行）

#### 🔵 TH-01 所有方法缺 Assigned(FConnection)/Connected 守卫（L43-101，其余 adapter 全有）——测试辅助类静默失败契约不明
**列名漂移（FormClass/StateJSON vs tier2 FormName/StateJson）**计入 SCH-04。⑤全参数化 ✅。

### 30. DeepBase.Persistence.RuntimeRegistration.pas（29 行）

**未发现问题**（无 DB 代码；注册幂等、nil 校验齐备）。

### 31. DeepBase.Persistence.Protection.FireDAC.pas（503 行）— 防篡改图像存储

#### 🟡 PROT-01 UpgradeDatabase 循环 ALTER TABLE 的 except 吞**所有**异常（L336-342）后仍 `Result := True`
- **说明**：意图容忍 duplicate column，但连接断开/文件损坏/权限错误同样被吞并报成功——防篡改基线表可能静默缺列，后续 hmac_sha256 NOT NULL 写入才炸，根因难寻。
- **建议修复**：判别异常消息仅放行 'duplicate column name'，其余记日志并 Result := False。

#### 🟡 PROT-02 TFireDACAntiTamperStorage.SaveSecureImage `INSERT OR REPLACE` 列清单不含 Enabled（L231-243）：替换后 Enabled 回落 DEFAULT 1——用户禁用（Enabled=0）的基线镜像一经重存被静默重新启用，安全语义反转
- **位置**：`DeepBase.Persistence.Protection.FireDAC.pas:232`
- **触发条件**：对已禁用 KeyName 再次 SaveSecureImage。
- **建议修复**：COALESCE 子查询保 Enabled（同 SEC UpsertSecret 手法）或 ON CONFLICT DO UPDATE。

#### 🔵 PROT-03 SaveSecureImage 的 md5 参数恒写 ''（L398），Data.md5 信息丢弃（若弃用应删列）
#### 🔵 PROT-04 第一类 ConfigureConnection（L107）未设 LoginPrompt := False，第二类设了（L173）——两同类行为不一致

**⑤**：TableName 拼接 6 处（L300/337/357/384/431/466）均在 ValidateTableName 白名单（L181-194）之后——**注入安全 ✅**；数据参数化 ✅。③两把 FLock 全序列化、可重入语义正确 ✅。②连接缓存 FreeAndNil 均在锁内 ✅。

### 32. DeepBase.IntentClarification.Storage.pas（401 行）

#### 🟡 IC-01 连接生命周期矛盾 → TFDConnection 泄漏（L112-117 vs L127）
- **代码**：
  ```pascal
  destructor TClarificationStorage.Destroy;
  begin
    // Connection is owned by DB.Factory pool, do not free here
    FConnection := nil;   // ← GetLocal 返回的是"新建、调用方负责 Free"的连接
  ```
- **说明**：`TDBConnectionFactory.GetLocal`（Factory.pas:309-317 本次核实）每次新建并打开连接、所有权归调用方；本类注释声称"池拥有"而不释放——每个存储实例泄漏一个已打开的 SQLite 连接（文件句柄+内存）。
- **触发条件**：任何使用 TClarificationStorage 的场景；实例频繁创建时线性泄漏。
- **建议修复**：Destroy 中 `FreeAndNil(FConnection)`，或改从真正的池借用。

#### 🟡 IC-02 Guardian.ProtectConnection 返回值被丢弃（L131-132）：无论完整性检查结果如何都记录 "integrity check passed" 并继续
- **说明**：Phase 2 宣称的完整性防护实际不生效，且日志撒谎——损坏库上的 checkpoint 读写照常进行。
- **建议修复**：检查 LGuardResult，失败时 raise/降级并记录真实结论。

#### 🔵 IC-03 EnsureInitialized 无线程守卫：双检竞态下二次 GetLocal 又泄漏一连接
#### 🔵 IC-04 RegisterMigration 为纯注释占位却 log "migration registered"（L385-398）——虚假注册记录
#### 🔵 IC-05 InitializeSchema/DDL 常量与主 schema 体系脱节（ic_sessions/ic_rapport 不在任何 sql/Migrations 文件，SSOT 孤点）

**⑤**：全参数化（含 L186 双名参数 :session_id2 手法）——注入安全 ✅。方言注记：INSERT OR REPLACE ×2 与头注释 "SQLite Persistence" 一致，本地设计成立。

### 33. DeepBase.Speech.Schema.pas（65 行）

#### 🔵 SSP-01 L50 speech_config.updated_at 默认值 `(datetime('now'))` SQLite-only；本单元被 Voiceprint adapter 在**每个入口**调用（VP-05），若接入共享 PG 库则 EnsureSchema 即炸——建议与 CFG-01 一并 CURRENT_TIMESTAMP 化
**其余维度未发现问题**。表定义单一来源（Voiceprint 委派本元，Grep 证实）✅。

---

## sql/ 与 Migrations/ 交叉核对（索引级）

#### 🟡 SCH-01 Schema 定义存在 ≥3 个信息源且权威源缺位（架构/SSOT，维度⑦）
1. `sql\tier0/1/2_init.sql` **三个文件头部全部标注 "⚠️ DEPRECATED"**，指向 `data/create_sample_db.sql`；
2. 代码内 EnsureSchema/CREATE TABLE IF NOT EXISTS 常量（JobQueue/Authorization/Security/License/IC/HBTelemetry/Speech.Schema/Protection）——**事实上的当前权威源**，但分散在 ≥8 个单元；
3. `Migrations\` 仅 2 个模块 5 个文件，且迁移引擎未接线生产（MIG 节）。
**后果**：无 CI 校验三者一致；漂移已实际发生（SCH-02/03/04）。
**建议**：确立"代码 DDL + Migrations 为唯一演进通道"，删除或归档 deprecated SQL 并在 README 声明；CI 用空库回放 Migrations 与 EnsureSchema 做 diff。

#### 🟡 SCH-02 Hotkeys 表结构漂移：tier1_init.sql 仅 4 列（Shortcut TEXT、无 DefaultShortcut/IsEnabled/IsCustomized/SortOrder），代码使用 7 列，靠 sql/upgrade_hotkeys_column.sql（IsCustom→IsCustomized 重建表）补齐——deprecated 基础脚本 + 独立升级脚本 + 代码三源并存；Shortcut TEXT vs 代码 AsInteger 读（QueryFieldToShortCut 有双分支容忍，属缓解）。

#### 🟡 SCH-03 ExceptionReports 列名冲突：Exception adapter 写 `ReportTime/Message`，tier2_init.sql 定义为 `OccurredAt/ExceptionMessage`——若部署库按 SQL 脚本建立，异常上报 INSERT 必失败（进存疑 SV-07 待 live schema 证实，但代码/脚本冲突本身成立）。

#### 🟡 SCH-04 TestSnapshots 列名冲突：TestHelper adapter 写 `FormClass/StateJSON`，tier2 定义为 `FormName(NOT NULL)/StateJson` 且 UNIQUE 三列——按脚本库 INSERT OR REPLACE 无法命中唯一键且违反 NOT NULL。

#### 🔵 SCH-05 sql 文件中文注释 mojibake（tier0 L3-L9、studio_init 多处），与 `Migrations\I18n\001_fix_bug276_seed_mojibake.up.sql` 治理的问题同类——SQL 文件编码规范缺失（建议统一 UTF-8 BOM + CI 检查）。

#### 🔵 SCH-06 正面记录：Migrations/JobQueue 提供 `.pg/.sqlite` 方言对是仓内最佳实践，其余单元 DDL 未跟进该模式。

#### 🔵 SCH-07 全部 21 个 FireDAC adapter 单元共用"无内部锁、裸共享 FConnection"模式，线程安全责任事实上归调用方，但无任何单元文档化该契约（本报告仅在 AUTH-05 记一条代表，实际为横切问题）。

---

## 🔴 Top 10（按危害排序）

| # | 编号 | 位置 | 一句话 |
|---|---|---|---|
| 1 | POOL-01 | Pool.pas:1066-1083 | 维护线程 WaitFor(100) 超时后仍 FreeAndNil → UAF/堆损坏 |
| 2 | DOQRY-01 | DoQry.pas:1871-1921 | 连接清扫跳过在用条目 → Entry.Connection 悬空，堆地址复用误命中错连接 |
| 3 | POOL-02 | Pool.pas:1237-1254 | LastDelimiter 未命中返回 0，`<0` 守卫失效 → 连接串解析错位损坏 |
| 4 | SQLOG-01 | SQLLogger.pas:354-358 | 锁外两线程共用同一 TFDConnection 并发 INSERT → AV/日志串扰，与线程安全宣称矛盾 |
| 5 | POOL-03 | Pool.pas:1537-1561 | 全池锁内做建连网络 I/O → 一处慢/不可达放大为全池停摆 |
| 6 | SM-02 | StatusMachine.pas:342-345 | SQLite 下状态迁移无锁 TOCTOU → 并发双迁移状态分叉（数据损坏级，因触发窗口小列🟡但后果🔴） |
| 7 | DOQRY-04 | DoQry.pas:1452-1506 | 预编译池开关竞争 → 悬空 TFDQuery 双释放风险 |
| 8 | JQ-04 | JobQueue.pas:868-954 | 死信回收 INSERT/DELETE 非原子 → PG 下任务静默丢失（幽灵死信） |
| 9 | IC-01 | IntentClarification.Storage.pas:112-117 | "池拥有"错误注释掩盖 GetLocal 连接永不释放 → 句柄/内存线性泄漏 |
| 10 | PROT-02 | Protection.FireDAC.pas:232 | INSERT OR REPLACE 丢 Enabled 列 → 禁用的防篡改基线被静默重新启用（安全语义反转） |

> 严格 🔴 定级为前 5 项；6-10 为高危 🟡（满足"数据损坏/泄漏/安全语义失效"升级条件，按用户 Top10 交付要求列示并如实标注）。

---

## 存疑区（需运行时/调用点确认）

| # | 事项 | 位置 | 存疑原因 |
|---|---|---|---|
| SV-01 | Migrations `TDirectory.GetFiles('*.sql')` 非递归，子目录布局静默跳过 | DB.Migrations:279 | 引擎未接生产，当前无实害；接线即触发 |
| SV-02 | ORM `Select(Columns)` 任意串直拼的**全部调用方**是否均为常量 | ORM.pas:943-947 | 仓内未穷尽反查；若存在外部输入即升 🔴 注入 |
| SV-03 | Manager.ExecuteStatement 直通任意 SQL 的实际调用方输入面 | Manager.FireDAC:157-173 | 调用方均在 Core 内，未见外部数据流，需部署确认 |
| SV-04 | SQLLogger finalization 释放 FLock 后，其他单元 finalization 期 LogSQL → 关闭 AV | SQLLogger.pas（finalization） | 依赖单元初始化顺序，静态不可判 |
| SV-05 | I18n/Theme `IsEnabled = 1` 整型比较在未来 PG 端 BOOLEAN schema 下的兼容性 | I18n:153, Theme:58 | 当前可见 schema 全 INTEGER，不判缺陷 |
| SV-06 | ORM Insert 依赖 GetLastAutoGenValue 的"同连接亲和"约束是否总被满足（池借还场景） | ORM.FireDAC:169-173 | 需调用序列证实 |
| SV-07 | ExceptionReports/TestSnapshots 列冲突（SCH-03/04）：live 库真实 schema 未知 | Exception.FireDAC:53-55 | deprecated 脚本未必等于部署现实，需对现网库 PRAGMA 验证 |
| SV-08 | MRU-01 并发 unique 冲突的实际频率（取决于 MRU 是否多进程共享） | MRU:86-102 | 单进程 UI 场景几乎不触发 |
| SV-09 | Factory.WriteSetting `INSERT OR REPLACE` 是否存在 PG 连接调用路径 | Factory.pas:440-460 | 当前只见本地调用，public 方法 |
| SV-10 | Hotkeys tier1 初建表无 UNIQUE(ActionName)（tier1 有 PRIMARY KEY，upgrade 后有 UNIQUE）——老库未跑 upgrade_hotkeys_column.sql 时 INSERT OR IGNORE 语义 | Hotkeys:200 / tier1_init.sql:59-64 | 部署矩阵未知 |

---

## 附录 A：拼 SQL 调用点全量判定表

判定基准：**安全** = ①纯常量 SQL；②动态标识符经白名单（ValidateIdentifier/ValidateQualifiedIdentifier/ValidateTableName/正则字符集）；③值一律走命名/位置参数；④引号包裹用 QuotedStr/双引号转义。

| 单元 | 拼点 | 手法 | 判定 |
|---|---|---|---|
| DB.Pool | 985-989 连接串 | 参数拼接（非 SQL） | ⚠️ 注入不适用；**凭据明文**（POOL-04） |
| DB.DoQry | Savepoint 名 | 自产 GUID | ✅ 安全 |
| DB.DoQry | 查询定义 SQL | 常量表 | ✅ 安全 |
| DB.JobQueue | 全部 DML/DQL | 常量+命名参数 | ✅ 安全 |
| ORM | 943-947 Select(Columns) | 直拼 | ⚠️ 无守卫（ORM-05/SV-02），其余列名走 ValidateSQLIdentifier ✅ |
| ORM | 1408-1431 CreateTable&lt;T&gt; | 属性名白名单+默认值 IsSafeDDLDefaultValue | ✅ 安全 |
| DB.Factory | 全部 | 常量+参数 | ✅ 安全 |
| DB.ConnectionPool | 无 | — | ✅ 未发现问题 |
| DB.Guardian | 266/297 checkpoint/VACUUM INTO | 白名单/QuotedStr | ✅ 安全 |
| DB.Migrations | 691 advisory_lock | 常量+Format 整数 | ✅ 安全 |
| DB.StatusMachine | 表/列标识符 | QuoteIdentifier | ✅ 注入安全（但 SM-01 语义错误） |
| DB.AutoRefreshConfig | 343/364 | ValidateIdentifier + 白名单 | ✅ 安全 |
| SQLLogger | 625 INSERT | 常量+参数 | ✅ 安全；DATA2-049 日志文本注入防护 ✅ |
| Persistence.Authorization | ReadAudit 动态 WHERE | 固定片段+参数 | ✅ 安全 |
| Persistence.Manager | 103-117/200/220-231 | QuotedList/ValidateIdentifier/ValidateColumnDef | ✅ 安全 |
| Persistence.Diagnose | 各 PRAGMA/sqlite_master Format | 先 ValidateIdentifier；580 常量表 | ✅ 安全 |
| Persistence.HBTelemetry | 237 等 | 常量+参数 | ✅ 安全 |
| Persistence.Logging | ReadRecent 列探测 | 常量+OrderBy 常量 | ✅ 安全 |
| Persistence.LLM | 226-228 | ValidateIdentifier（DATA2-018） | ✅ 安全 |
| Persistence.License | 6 处 | 常量+字面量 key+参数 | ✅ 安全 |
| Persistence.MRU | 全部 | 常量+参数 | ✅ 安全 |
| Persistence.Hotkeys | 全部 | 常量+参数 | ✅ 安全 |
| Voiceprint | 5 处 | 常量+参数 | ✅ 安全 |
| Config / I18n / Theme / Exception / FormState | 全部 | 常量+参数 | ✅ 安全 |
| ORM.FireDAC | 无拼接（执行器直通 SQL 由上层给） | 参数按位绑定 | ✅ 本身安全；风险上移至 ORM.pas |
| Security | +STableSecrets | 常量表名（DeepBase.Consts） | ✅ 安全 |
| TestHelper | 全部 | 常量+参数 | ✅ 安全 |
| Protection | TableName 6 处 | ValidateTableName 白名单前置 | ✅ 安全 |
| IntentClarification | 全部 | 常量+参数 | ✅ 安全 |
| Speech.Schema | 4 条 DDL | 常量 | ✅ 安全 |

**结论：33 个单元中所有动态 SQL 拼接点均有标识符白名单或参数化守卫，未发现可直接利用的 SQL 注入；唯一无守卫的公开面为 ORM.Select(Columns)（SV-02 跟踪）。**

---

*报告完。审计人：Qoder 深度审查（只读，未改动任何源码）。*
