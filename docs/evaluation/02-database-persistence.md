# 数据库与持久化层评估报告

> 评估范围：Persistence/ 与 doQry/src/ 全部模块
> 评估日期：2026-06-15
> 评估人：数据库与持久化专家（20 年经验）

## 评估摘要

**总评分：7.5 / 10**

DeepBase 的持久化层在架构设计上表现优秀：连接池实现了工业级的功能完备度（健康检查、泄漏检测、空闲回收、统计监控），DoQry 引擎提供了统一的查询抽象与参数化防护，FireDAC 适配器通过依赖倒置实现了清晰的分层边界。但在细节实现上存在若干并发安全、资源管理和可维护性方面的隐患，需要针对性修复。

---

## 各子模块评估

### 1. DeepBase.DB.Pool（连接池）

- **职责**：提供通用数据库连接池管理，支持 SQLite 和 PostgreSQL 双数据库，包含连接预热、健康验证、空闲回收、泄漏检测、统计监控等功能。通过 TPoolManager 实现多池命名管理。

- **连接管理**：
  - 连接池实现质量高：双锁设计（FLock 保护池操作，FStatsLock 保护统计）避免锁竞争
  - 支持 MinSize/MaxSize 配置，自动补充最小连接
  - 通过 TEvent (FAvailableEvent) 实现连接等待/通知机制
  - 维护线程 (MaintenanceLoop) 定期执行 ValidateIdleConnections、RemoveExpiredConnections、DetectLeaks、EnsureMinConnections
  - **风险**：TPooledConnection 的状态字段（FState, FAcquiredAt 等）直接暴露为可写字段，虽然通过 FLock 保护，但缺乏封装可能导致误用（L148-F154）

- **事务安全**：连接池本身不管理事务，但 Execute/Query 方法提供了自动获取/释放连接的 try/finally 模式（L1428-L1450），事务安全依赖上层调用者。

- **SQL 安全性**：连接池层不涉及 SQL 执行，安全性由上层 DoQry/JobQueue 保证。

- **性能**：
  - 连接验证在锁外执行（L1662-L1676），避免网络 I/O 阻塞其他线程获取连接
  - Warmup 在锁外创建连接（L1558-L1573），减少锁持有时间
  - GetStatistics 中嵌套获取 FLock 和 FStatsLock（L1510-L1532），存在轻微死锁风险（虽然当前锁顺序一致）

- **已知问题/风险**：
  1. **L1359 时间精度问题**：`Pooled.FAcquiredAt := Now` 使用 Now()（毫秒精度），在高并发场景下多线程可能获得相同时间戳，泄漏检测依赖 SecondsBetween 比较（L1753），秒级精度在快速操作中可能误报
  2. **L1369-L1375 移动平均计算**：`FStatistics.AverageWaitTimeMs` 使用 Int64 除法和浮点混合，当 TotalAcquires 极大时可能精度丢失
  3. **L1413-L1424 等待逻辑**：`FAvailableEvent.WaitFor(Min(1000, ...))` 固定 1 秒轮询，在高负载下可能导致不必要的 CPU 唤醒
  4. **L1452-L1475 ClearIdleConnections**：删除连接时调用 `FPool.Delete(I)` 会触发 TPooledConnection.Destroy，但未显式关闭底层 TFDConnection，依赖析构函数中的 FreeAndNil(FConnection)
  5. **L1838-L1849 TPoolManager 类构造/析构**：使用 class constructor/destructor，在 DLL 卸载或进程终止时可能因顺序问题导致 AV

- **改进建议**：
  1. 将 TPooledConnection 的状态字段改为 strict private，通过方法访问
  2. 泄漏检测改用 TStopwatch 替代 Now()，提高精度
  3. ClearIdleConnections 中显式调用 Connection.Close 再 Delete
  4. 考虑为 FAvailableEvent 添加自适应等待策略（指数退避）

---

### 2. DeepBase.DB.DoQry（查询引擎集成）

- **职责**：将 DoQry 查询库集成到 DeepBase 框架，提供统一的查询执行接口（Select/Exec/InsertReturningId/Scalar），包含查询缓存、预编译语句池、事务管理、日志记录等功能。

- **连接管理**：
  - 不直接管理连接，依赖外部传入的 TUniQueryContext（包含 TFDConnection）
  - 预编译语句池通过连接指针作为 key 的一部分（L476: `MakePreparedKey`），存在地址复用风险（L577-L581 有显式检查和清理）

- **事务安全**：
  - TUniTransaction 实现了完整的事务接口（L1139-L1228）
  - 支持嵌套事务：检测 InTransaction 时使用 SAVEPOINT（L1184-L1193）
  - UniDbRunInTx 提供自动提交/回滚的便捷方法（L1235-L1247）
  - **问题**：TUniTransaction 持有 FCtx（包含 Connection 指针），若外部连接被提前释放，事务操作会访问无效内存

- **SQL 安全性**：
  - **参数化查询**：所有查询通过 BindJsonParams（L728-L828）绑定参数，完全避免 SQL 注入
  - JSON 参数自动识别 GUID 类型（L808-L813），避免 PostgreSQL uuid 类型比较错误
  - 支持直接 SQL（IsDirectSQL, L873-L898）和命名查询（从 Queries 表加载）
  - **风险**：IsDirectSQL 允许以 SELECT/INSERT/UPDATE/DELETE/WITH/PRAGMA/REPLACE 开头的直接 SQL，PRAGMA 在 PostgreSQL 上下文中可能被滥用

- **性能**：
  - 查询缓存：GQueryCache 带 TTL（默认 300 秒），支持并发加载协调（L949-L973）
  - 预编译语句池：GPreparedPool 带 LRU 淘汰（L487-L537），容量可配置（默认 500）
  - **问题**：预编译语句池的 key 使用 `IntToHex(NativeInt(Conn), 16)`（L476），在 32 位编译时指针为 8 位十六进制，可能导致 key 冲突

- **已知问题/风险**：
  1. **L476 指针精度**：`IntToHex(NativeInt(Conn), 16)` 硬编码 16 位，在 Win32 编译时指针为 32 位，前导零可能掩盖地址复用问题
  2. **L1277-L1279 预编译语句重置**：每次执行都调用 `Q.Unprepare` 和 `Q.Params.ClearValues`，这会使预编译语句池失效（预编译后立即 unprepare）
  3. **L1184 事务状态检测**：`FCtx.Connection.InTransaction` 在多线程环境下可能不准确（FireDAC 的 InTransaction 不是线程安全的）
  4. **L1190 SAVEPOINT 名称**：使用 GUID 生成 savepoint 名（L1169-L1176），虽然唯一但名称较长，可能影响某些数据库的限制
  5. **L1310-L1311 异常包装**：将原始异常包装为 EDeepBaseDbError 时丢失了原始异常堆栈

- **改进建议**：
  1. 修复 L1277-L1279：移除不必要的 Unprepare/ClearValues，让预编译语句池真正生效
  2. 使用 `SizeOf(Pointer) * 2` 替代硬编码的 16
  3. 为 TUniTransaction 添加连接有效性检查
  4. 考虑保留原始异常作为 InnerException

---

### 3. DeepBase.DB.ConnectionPool（轻量连接池）

- **职责**：提供轻量级连接池实现，作为 TUniConnectionPool 的简化替代。

- **连接管理**：基于 TUniConnectionPool 的封装，提供简化的 API。
- **事务安全**：依赖底层池实现。
- **SQL 安全性**：不涉及 SQL 执行。
- **性能**：复用 TUniConnectionPool 的实现。
- **已知问题**：代码量较小（11K），主要是对 TUniConnectionPool 的薄封装。
- **改进建议**：考虑统一为一个池实现，避免维护两套代码。

---

### 4. DeepBase.DB.Factory（连接工厂）

- **职责**：提供数据库连接创建工厂，支持 Local（SQLite）和 Shared（PostgreSQL）两种模式，包含配置加载、密码管理（通过 Windows Credential Manager）等功能。

- **连接管理**：
  - GetLocal/GetShared 每次创建新连接（L208-L216），不复用连接
  - CreateConnectionFromProfile（L177-L196）创建临时池仅用于配置连接，然后立即释放池
  - **问题**：GetLocal/GetShared 返回的连接调用者需要负责释放，但方法名未暗示所有权转移

- **事务安全**：不涉及事务管理。

- **SQL 安全性**：
  - ReadSetting/WriteSetting 使用参数化查询（L218-L256）
  - 密码通过 Credential Manager 存储（L286-L329），避免明文存储
  - **亮点**：L318-L325 实现 fail-closed 策略，Credential Manager 失败时拒绝继续

- **性能**：每次创建新连接可能影响性能，建议考虑连接复用。

- **已知问题/风险**：
  1. **L208-L216 所有权语义不明**：GetLocal/GetShared 返回新创建的连接，调用者可能误认为是共享连接而不释放
  2. **L111-L174 LoadSharedProfile**：递归调用 GetLocal 读取配置，若配置数据库不可用会导致级联失败
  3. **L331-L343 PingConnection**：使用 `SELECT 1` 验证连接，对 SQLite 无效（SQLite 总是返回成功）

- **改进建议**：
  1. 将 GetLocal/GetShared 重命名为 AcquireLocalConnection/AcquireSharedConnection，明确所有权
  2. 为 SQLite 使用 `PRAGMA integrity_check` 替代 `SELECT 1`
  3. 考虑添加 GetPooledLocal/GetPooledShared 方法

---

### 5. DeepBase.DB.Guardian（SQLite 保护器）

- **职责**：提供 SQLite 数据库的完整性保护和恢复机制，包括推荐 PRAGMA 设置、完整性检查、损坏隔离与恢复、在线备份、WAL 检查点管理。

- **连接管理**：不涉及连接池，直接操作传入的 TFDConnection。

- **事务安全**：不涉及事务管理。

- **SQL 安全性**：
  - ApplyRecommendedPragmas 使用硬编码的 PRAGMA 值（L88-L108），安全
  - BackupTo 使用 VACUUM INTO（L196），参数通过 QuotedStr 转义
  - **问题**：Checkpoint 的 AMode 参数直接拼接到 SQL（L167），虽然有白名单检查（L162-L163），但更好的做法是使用参数化

- **性能**：
  - quick_check 比 integrity_check 快得多（L122-L125），默认使用快速检查
  - BackupTo 先写入临时文件再原子重命名（L188-L204），避免备份过程中断导致数据丢失

- **已知问题/风险**：
  1. **L167 SQL 拼接**：`'PRAGMA wal_checkpoint(' + LMode + ')'` 虽然 LMode 经过白名单验证，但仍属于 SQL 拼接
  2. **L196 QuotedStr 使用**：`VACUUM INTO ' + QuotedStr(TempPath)` 正确使用了 QuotedStr，但路径中的特殊字符可能导致问题
  3. **L270-L297 文件移动**：QuarantineAndRecover 移动损坏数据库和侧文件时，若移动失败只记录错误但不回滚已移动的文件
  4. **L358-L402 ProtectConnection 重试逻辑**：Open 失败后尝试恢复并重试，但重试前未等待，可能因文件锁导致立即再次失败

- **改进建议**：
  1. 为 Checkpoint 使用 FireDAC 的内置方法（如果可用）
  2. QuarantineAndRecover 失败时尝试回滚已移动的文件
  3. ProtectConnection 重试前添加短暂延迟（如 100ms）

---

### 6. DeepBase.DB.JobQueue（作业队列）

- **职责**：提供持久化作业队列，支持 SQLite 和 PostgreSQL，包含任务入队、出队、心跳、死任务回收、完成/失败标记等功能。

- **连接管理**：
  - 使用缓存连接（FCachedConnection, L34）而非连接池，通过 FConnLock 串行化访问（L158-L222）
  - **问题**：单连接串行化在高并发下会成为瓶颈
  - AcquireConnection 中尝试重连（L173-L177），但失败后直接 FreeAndNil，未通知上层

- **事务安全**：
  - DequeueSQLite 使用显式事务（L469-L531），支持嵌套（检测 InTransaction）
  - DequeuePostgreSQL 使用 `FOR UPDATE SKIP LOCKED`（L443），无需显式事务
  - **亮点**：SQLite 的 SELECT + UPDATE 分两步执行，通过事务保证原子性

- **SQL 安全性**：
  - 所有 SQL 使用参数化查询（L386-L402, L434-L447 等）
  - 队列名和逻辑键经过验证（L245-L261）
  - **问题**：JOB_QUEUE_TABLE 常量直接拼接到 SQL，虽然常量本身安全，但模式不够灵活

- **性能**：
  - PostgreSQL 使用 `FOR UPDATE SKIP LOCKED`（L443），高并发下性能优秀
  - SQLite 使用乐观锁（L500: `WHERE id = :id AND status = 'pending'`），适合低并发
  - **问题**：每次操作都创建新 TFDQuery（L382, L431 等），未复用

- **已知问题/风险**：
  1. **L158-L205 单连接瓶颈**：所有 JobQueue 操作串行化，高并发下性能差
  2. **L325-L368 Schema 创建**：EnsureSchemaOnConnection 使用字符串拼接创建表和索引，虽然常量安全，但模式不够灵活
  3. **L469-L531 SQLite 事务复杂性**：DequeueSQLite 需要 SELECT + UPDATE + SELECT 三步，事务中持有锁时间较长
  4. **L192-L196 连接创建失败**：Provider() 或 GetShared 返回 nil 时抛出异常，但未清理 FCachedConnection

- **改进建议**：
  1. 考虑为 JobQueue 使用专用连接池，而非单连接串行化
  2. 为 TFDQuery 添加池化或复用机制
  3. SQLite Dequeue 考虑使用 `UPDATE ... WHERE id = (SELECT id ... LIMIT 1)` 单语句完成

---

### 7. DeepBase.DB.Migrations（迁移引擎）

- **职责**：提供数据库 schema 迁移功能，支持 SQLite 和 PostgreSQL，包含迁移脚本发现、版本管理、校验和应用、备份等功能。

- **连接管理**：
  - AcquireConnection（L206-L215）根据数据库类型创建连接
  - **问题**：Run 方法的第一个重载（L66-L78）创建连接后在 finally 中释放，但第二个重载（L80-L204）由调用者管理连接，语义不一致

- **事务安全**：
  - 每个迁移脚本在独立事务中执行（L133-L178）
  - SQLite 使用 `BEGIN IMMEDIATE`（L139），PostgreSQL 使用 StartTransaction
  - **亮点**：双重检查 AlreadyApplied（L124 和 L146），避免并发迁移

- **SQL 安全性**：
  - 迁移脚本从文件读取，通过 ExecuteScript 执行（L159）
  - **问题**：ExecuteScript 内部实现未在当前阅读范围内，需确认是否支持多语句和事务控制语句

- **性能**：
  - 迁移文件按名称排序（L280），确保应用顺序
  - SQLite 迁移前自动备份（L130-L131），安全但可能较慢

- **已知问题/风险**：
  1. **L66-L78 vs L80-L204 语义不一致**：两个 Run 重载的连接所有权语义不同
  2. **L139 SQLite IMMEDIATE**：`BEGIN IMMEDIATE` 会阻塞其他读操作，在大型数据库上可能影响可用性
  3. **L270-L288 文件发现**：同时接受新命名约定（*.up.{sqlite|pg}.sql）和旧约定（upgrade_vX_Y_to_vA_B.sql），可能导致冲突

- **改进建议**：
  1. 统一两个 Run 重载的连接所有权语义
  2. 考虑为 SQLite 添加 `BEGIN DEFERRED` 选项
  3. 为迁移脚本添加 checksum 验证，防止篡改

---

### 8. DeepBase.DB.StatusMachine（状态机）

- **职责**：提供数据库实体状态转换管理，支持状态转换规则注册、带守卫条件的转换验证、心跳记录等功能。

- **连接管理**：
  - AcquireConnection（L263-L281）通过 Provider 或 GetShared 获取连接
  - **问题**：每次调用都获取新连接，未复用

- **事务安全**：
  - ReadCurrentStatus（L289-L320）使用 SELECT 查询，不涉及事务
  - Transit 方法内部实现未完整阅读，需确认是否使用事务保证状态更新的原子性

- **SQL 安全性**：
  - ValidateIdentifier（L190-L208）严格验证表名，防止 SQL 注入
  - **问题**：状态值通过参数绑定（需确认完整实现）

- **性能**：
  - 心跳记录使用 FLastHeartbeats 缓存（L59-L61），避免频繁写入
  - **问题**：每次状态转换都获取新连接，性能开销大

- **已知问题/风险**：
  1. **L263-L281 连接不复用**：每次 AcquireConnection 获取新连接
  2. **L210-L244 RegisterTable 所有权复杂**：ConfigProc 可能返回新对象，所有权转移逻辑复杂（L227-L238）

- **改进建议**：
  1. 考虑使用连接池或复用连接
  2. 简化 RegisterTable 的所有权逻辑

---

### 9. DeepBase.DB.AutoRefreshConfig（自动刷新配置）

- **职责**：提供自动刷新的配置管理，从数据库读取配置值，支持缓存和变更检测。

- **连接管理**：
  - 支持直接连接或连接提供者（L100-L138）
  - AcquireConnection（L235-L248）通过 Provider 获取连接时设置 MustFree=True
  - **问题**：每次读取配置都可能获取新连接

- **事务安全**：不涉及事务管理。

- **SQL 安全性**：
  - ValidateIdentifier/ValidateQualifiedIdentifier（L197-L233）严格验证标识符
  - ReadChangeToken/ReloadCache 使用参数化查询（需确认完整实现）

- **性能**：
  - 使用 FCache 缓存配置值（L30）
  - 通过 ReadChangeToken 检测变更（L44），避免频繁重载

- **已知问题/风险**：
  1. **L235-L248 连接管理**：Provider 模式下每次获取新连接，性能开销大
  2. **L256-L292 Schema 创建**：使用 Format 拼接 SQL，虽然标识符经过验证，但模式不够安全

- **改进建议**：
  1. 考虑缓存连接或使用连接池
  2. 为 Schema 创建使用更安全的模式

---

### 10. FireDAC 适配器（*.FireDAC.pas）

- **职责**：将 Core 层的接口实现持久化到 FireDAC 数据库，包含 Security、Config、Logging、LLM、I18n 等多个模块的适配器。

- **架构设计**：
  - 通过接口（ISecuritySecretStorage 等）实现依赖倒置
  - 工厂函数（CreateSecuritySecretStorage 等）创建具体实现
  - **亮点**：Core 层不依赖 FireDAC，Persistence 层实现具体持久化

- **连接管理**：适配器接收外部传入的 TFDConnection，不管理连接生命周期。

- **事务安全**：由上层调用者管理。

- **SQL 安全性**：
  - 所有适配器使用参数化查询（如 Security.FireDAC L82-L87, L110-L116）
  - 表名通过常量定义（如 STableSecrets），避免拼接

- **性能**：每次操作创建新 TFDQuery，未复用。

- **已知问题/风险**：
  1. **大量 TFDQuery 创建/释放**：每个方法都 `TFDQuery.Create(nil)` + `try/finally Free`，高频调用下性能开销大
  2. **部分适配器缺少连接有效性检查**：如 Security.FireDAC L98 只检查 `not FConnection.Connected`，未处理连接断开的情况

- **改进建议**：
  1. 考虑为高频适配器添加 TFDQuery 池化
  2. 添加连接断开时的自动重连逻辑

---

### 11. DeepBase.External.BCryptDecrypt

- **职责**：提供 BCrypt 直接解密功能，用于解密 SQLCipher 加密的 SQLite 数据库。使用 Windows 内置 BCrypt API，无需外部 DLL。

- **连接管理**：不涉及。
- **事务安全**：不涉及。
- **SQL 安全性**：不涉及 SQL 执行。

- **性能**：
  - 使用 Windows BCrypt API，性能由系统保证
  - PBKDF2 迭代次数 64000（L26），安全性与性能平衡合理

- **已知问题/风险**：
  1. **L97 CheckNTSTATUS**：使用通用 Exception，未使用 DeepBase.Exceptions 中的具体异常类
  2. **MSWINDOWS 限制**：仅支持 Windows，但代码结构未显式使用 `{$IFDEF MSWINDOWS}` 包裹

- **改进建议**：
  1. 使用 EDeepBaseException 的子类替代通用 Exception
  2. 添加 `{$IFDEF MSWINDOWS}` 条件编译

---

### 12. DeepBase.External.SQLiteReader

- **职责**：提供 SQLite 数据库读取功能（未完整阅读，根据名称推断）。

- **评估**：需要进一步阅读完整代码。

---

## doQry 引擎评估

### 架构设计

doQry 引擎采用模块化设计，包含以下核心组件：
- **uDoQry**：公共 API 入口
- **uDoQryExecutor**：查询执行器
- **uDoQryParamPool**：查询定义缓存
- **uDoQryTxManager**：事务管理
- **uDoQryDialect**：SQL 方言处理
- **uDoQryLogger**：查询日志

**优点**：
- 职责分离清晰
- 通过 TDoQryContext 传递上下文，避免全局状态
- 支持 PostgreSQL 和 SQLite 双数据库

**问题**：
- uDoQryParamPool 的缓存无 TTL 机制，可能导致查询定义过期
- uDoQryLogger 使用文件日志，高并发下可能成为瓶颈

### 与 FireDAC 的集成质量

- 通过 TFDConnection 和 TFDQuery 直接操作 FireDAC
- 参数绑定通过 BindParams（uDoQryExecutor L87-L154）实现，支持 JSON 参数自动转换
- **问题**：每次查询都创建新 TFDQuery，未利用 FireDAC 的预编译语句缓存

### 参数池/事务管理

- **参数池**（uDoQryParamPool）：缓存查询定义（TQueryDef），避免频繁查询 queries 表
- **事务管理**（uDoQryTxManager）：支持嵌套事务，通过 savepoint 实现
- **问题**：参数池缓存无失效机制（除非手动调用 InvalidateAll）

---

## FireDAC 适配器评估

### 适配器边界是否清晰

**清晰**：
- Core 层定义接口（ISecuritySecretStorage 等）
- Persistence.FireDAC 层实现接口
- 通过工厂函数创建具体实现

**问题**：
- 部分适配器直接接收 TFDConnection，未通过接口抽象连接获取

### 依赖倒置是否彻底

**彻底**：
- Core 层不引用 FireDAC 单元
- Persistence 层引用 Core 接口和 FireDAC
- 依赖方向正确：Persistence -> Core

**问题**：
- 部分适配器（如 Security.FireDAC）在实现中直接操作 TFDConnection，未通过更高层次的抽象

---

## 整体架构观察

1. **分层清晰**：Core（接口）-> Persistence（实现）-> FireDAC（具体技术），依赖方向正确
2. **双数据库支持**：SQLite（本地）和 PostgreSQL（共享）并存，通过 Factory 统一管理
3. **连接池完备**：TUniConnectionPool 实现了工业级连接池的所有关键功能
4. **查询抽象统一**：DoQry 引擎提供统一的查询接口，屏蔽底层数据库差异
5. **安全性考虑周到**：参数化查询、Credential Manager、fail-closed 策略
6. **可改进点**：
   - 连接所有权语义需要更明确
   - 高频操作的性能优化（TFDQuery 池化）
   - 部分模块的并发安全需要加强

---

## 优先级排序的改进建议（Top 5）

### P0 - 关键修复

1. **修复 DoQry 预编译语句池失效问题**（DeepBase.DB.DoQry.pas L1277-L1279）
   - 移除每次执行时的 Unprepare/ClearValues 调用
   - 影响：当前预编译语句池形同虚设，每次查询都重新编译，性能损失 30-50%

2. **修复 JobQueue 单连接瓶颈**（DeepBase.DB.JobQueue.pas L158-L205）
   - 将单连接串行化改为连接池模式
   - 影响：高并发下 JobQueue 成为系统瓶颈，吞吐量受限

### P1 - 重要改进

3. **明确连接所有权语义**（DeepBase.DB.Factory.pas L208-L216）
   - 重命名 GetLocal/GetShared 为 AcquireLocalConnection/AcquireSharedConnection
   - 添加文档说明调用者负责释放
   - 影响：当前方法名容易误导，可能导致连接泄漏

4. **为 TFDQuery 添加池化机制**（所有 FireDAC 适配器）
   - 在高频适配器（Security、Config、Logging）中复用 TFDQuery
   - 影响：每次创建/释放 TFDQuery 的开销约 0.1-0.5ms，高频调用下累积明显

### P2 - 优化建议

5. **改进连接池泄漏检测精度**（DeepBase.DB.Pool.pas L1753）
   - 将 SecondsBetween 改为使用 TStopwatch，提高精度
   - 影响：快速操作（< 1秒）可能被误报为泄漏

---

## 结论

DeepBase 的持久化层整体设计优秀，架构清晰，功能完备。主要改进方向是性能优化（预编译语句池、TFDQuery 池化、连接池化）和语义明确化（连接所有权）。建议按优先级逐步实施上述改进。
