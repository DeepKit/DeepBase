# tasks.md（uDoQry 库）

> **状态更�?*: 2025-12-12
> 
> - uDoQry 的核心能力已�?DeepBase 中形成统一入口：`Core/DeepBase.DB.DoQry.pas`
> - 对外文档�?DeepBase 文档为准：`docs/05.03.DeepBase-4AI-DoQry指南-v1.0.md`
> - 本目录更多作为历史实�?对照参考；后续优化方向�?`.kiro/specs/doqry-optimization/`

状态标记：
- [ ] 未开�? [~] 进行�? [x] 已完�?
---

## 1. 核心�?
- [~] 门面单元 uDoQry（唯一对外�?- [ ] uDoQryTypes（TDBType、TDoQryContext、IDoQryTx�?- [ ] uDoQryDialect（PG/SQLite：Limit/Offset、Returning/last_insert_rowid、标识符转义�?- [ ] uDoQryJsonParams（JSON 解析、Schema 校验、默认值填充、日期与数组�?- [ ] uDoQryParamPool（按 proc+DBType 缓存参数模板，失效与刷新�?- [ ] uDoQryTxManager（Start/Commit/Rollback、SAVEPOINT 嵌套、RunInTx�?- [ ] uDoQryExecutor（模板编译、IN 展开、参数绑定、超时、执行、结果转换）
- [ ] 集成 DeepBase.Logging：提�?DoQry 专用日志通道（替�?uDoQryLogger�?- [ ] 集成 DeepBase 错误类型：统一使用 EDeepBaseDbError 携带上下文（替代 EDoQryError�?
---

## 2. API 暴露（由 uDoQry 提供�?
- [ ] DoQryInit(ProjectRoot)
- [ ] DoQryMakeContext(Conn, DBType, TimeoutSec, CorrelationId)
- [ ] DoQryNewCorrelationId
- [ ] DoQryBeginTx / DoQryRunInTx
- [ ] DoQryExecSelect
- [ ] DoQryExecNonQuery
- [ ] DoQryExecInsertReturningId
- [ ] DoQryExecScalar
- [ ] DoQryBuildSqlPreview

---

## 3. 数据库与配置

- [ ] `queries` 表新增列：`sql_template`、`param_schema_json`、`timeout_sec`、`default_limit`、`allow_full_scan`
- [ ] 删除旧表 `query_parameters`，全部使�?`queries.param_schema_json` 维护参数 Schema
- [ ] `queries.proc_name` 索引
- [ ] 预热与缓存策略（加载/刷新�?
---

## 4. GUI 支持

- [ ] 选择“项目根目录”（决定 logs\query.log 位置�?- [ ] 日志查看面板（过滤：level/proc/corrId/时间范围�?
---

## 5. 测试矩阵

- [ ] JSON 参数解析/校验/默认�?- [ ] IN 展开/数组绑定
- [ ] 日期解析（时�?UTC�?- [ ] 方言差异（PG/SQLite�?- [ ] 事务嵌套与回滚（SAVEPOINT�?- [ ] 超时/错误模型/日志落盘
- [ ] 并发与连接池
- [ ] 性能（批处理、分页）

---

## 6. 文档与交�?
- [x] DeepBase 文档（对�?使用指南）：`docs/05.03.DeepBase-4AI-DoQry指南-v1.0.md`
- [x] tasks.md（本文件，保留为历史/对照�?
---

## 7. 默认策略（可覆盖�?
- 默认超时�?0s（per-query 可覆盖）
- SELECT 默认 LIMIT�?000（per-query 可覆盖）
- 禁止�?WHERE �?UPDATE/DELETE（per-query 可例外）
- 仅参数化；拒绝字符串拼接
- 日志：由 DeepBase.Logging 输出 JSONL�?0MB x 5，路�?= `ProjectRoot\\logs\\query.log`

---

## 8. 里程�?
- M1：最小可用（PG/SQLite、参数化、事务与日志�?- M2：参数池与缓存、SQL 预览、GUI 日志
- M3：并发与性能优化、扩展校验与治理

---

## 9. 优化�?DeepBase 集成

- [ ] 优化与重�?doQry 核心（Executor / Dialect / JsonParams / TxManager / ParamPool / Query 池）
- [ ] �?doQry 收编�?DeepBase.DB.DoQry 模块，由 DeepBase.Manager 初始化（RootPath + ConfigDB + Logging�?- [ ] �?DeepBase 文档中补�?doQry 集成与使用规范（以后所�?Delphi 程序统一使用 DeepBase + DoQry�?