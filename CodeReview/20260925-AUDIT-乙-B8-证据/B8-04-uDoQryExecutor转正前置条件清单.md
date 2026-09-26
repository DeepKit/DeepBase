# B8-04 uDoQryExecutor 新轨转正 —— 前置条件登记（只登记，不改代码）

> 工单：WO-20260925-AUDIT-乙-B8 §二 B8-04 · 派生自乙 B2-13 路线①结转（`CodeReview/20260925-AUDIT-乙-B2-证据/B2-13-修后-编译与用例.txt` §四 R1）
> 本文只产出「前置条件清单 + 破坏面 + 排期建议」，本笔 commit 零 `.pas`（判据：`git show --name-only` 无生产代码）。
> 实测锚点：隔离 `--detach` 工作树 @`caed2b0`，原件见同目录 `隔离树复跑/`。
> **转正方向本身不在本文裁定范围**：§三 的 P0 是本项最重要的产出，选路权在主控。

## 〇、登记前置必须先读的发现：仓内已有一套同名不同源的参数化执行器

`doQry/src/uDoQry*`（下称 **doQry 轨**）与 `Persistence/DeepBase.DB.DoQry.pas`（下称 **Persistence 轨**）
是同一能力的两套实现，API 逐条对应：

| doQry 轨（facade `uDoQry.pas`，101 行） | Persistence 轨（`DeepBase.DB.DoQry.pas`，1996 行） |
|---|---|
| `DoQryInit(Root)` | `UniDbInit(RootPath)` |
| `DoQryMakeContext(Conn, TDBType, TimeoutSec, CorrelationId)` | `UniDbMakeContext(Conn, TUniDBType, …)` |
| `DoQryNewCorrelationId` | `UniDbNewCorrelationId` |
| `DoQryBeginTx / DoQryRunInTx` | `UniDbBeginTx / UniDbRunInTx` |
| `DoQryExecSelect / NonQuery / InsertReturningId / Scalar / BuildSqlPreview` | `UniDbSelect / UniDbExec / UniDbInsertReturningId / UniDbScalar / UniDbBuildSqlPreview` |
| `TDBType = (dbPostgreSQL, dbSQLite)`（`uDoQryTypes.pas:10`） | `TUniDBType = (udbPostgreSQL, udbSQLite)`（:44） |

同一组事实决定了「转正」这个词的真实含义不是"把绿面铺上"，而是"选一套留一套"：

| 维度 | doQry 轨 | Persistence 轨 |
|---|---|---|
| 单元数/行数 | 9 个 / 1234 行 | 1 个 / 1996 行 |
| 包归属 | 无（`doQry/examples/DoQryDemo.dpr` 直连源码路径） | `DeepBasePersistence.dpk` + `.dproj`（T0 生产契约面） |
| 测试 | 0 个（`git grep -lE "uDoQryExecutor\|DoQryExec" -- 'Tests/**'` 空） | `Test.DeepBase.DB.DoQry.pas` + 3 件回归夹具（BUG338/339/347），已并网 `Tests/DeepBaseTests.dpr/.dproj` |
| 额外能力 | 无 | 查询缓存/TTL、prepared statement 池、连接池清扫 `UniDbSweepConnectionFromPool`、`UniDbShutdown`、直连 SQL 开关 |
| 可编译性 | 绿（F2，但载体不在契约面，见 F3） | 绿（随 T0 的 25/25 DPK） |

⇒ AGENTS.md 的 SSOT/警惕架构分叉条直接命中：若照 B2-13 R1 的字面「新轨转正」把 doQry 轨升面，
  仓内就有两套参数化执行器与两份 `queries` 模板解析口径。因此本登记的 P0 是**选路**，不是排期。

## 一、现状事实（全部现查，不引 B2 转述）

| # | 事实 | 取证 |
|---|---|---|
| F1 | doQry 轨 9 个单元在 `doQry/src/`：`uDoQry`(facade)/Types/Errors/Logger/Dialect/ParamPool/TxManager/JsonParams/Executor | `git ls-files 'doQry/src/*'` |
| F2 | doQry 轨**编译是绿的**（B2 期「从未编译绿」的登记已过期）：`DoQryDemo.dpr` 单编 BUILD_EXIT=0（B8-03 原件），`uDoQryExecutor.pas`/`uDoQry.pas` 补 `doQry/src` 搜索路径后各 BUILD_EXIT=0 | `B8-03-单编-DoQryDemo-@7adfba5.txt`、`B8-04-单件编译-新轨executor与facade-@caed2b0.txt` |
| F3 | 但这份绿不在契约面上：DoQryDemo 只在 `contracts/T1-观测面.txt`（编且记录、红不阻断），且该工程**无 .dproj** ⇒ 门禁 `CONFIG=default`、命名空间回落 DEFAULT_NS（T1 旧注释记的红因即此） | `git ls-files 'doQry/examples/**'` = 1 件 .dpr |
| F4 | 真实生产入口 `doQry/prjDoQry.dpr`/`.dproj` 只含 `doQryMain.pas` + `uDoQryLegacy.pas`，不含任何新轨单元 | `sed -n '1,10p' doQry/prjDoQry.dpr` |
| F5 | 旧轨 `doQry/uDoQryLegacy.pas`（1283 行）接口 = 15 个函数，ADO 型（`TAdoQuery`），入口 `doQry(ProcName, aQry, ParamString)` 以 `k=v;k=v` 传参 | interface 段计数 |
| F6 | 旧轨生产调用点 = **3 处**，都在 `doQry/doQryMain.pas`：`doQry(...)` :113、`BuildSQL(aQry,p)` :131、`ShowCurrRecord(aQry, sEdtFieldsNum.Value)` :160；uses 位 :12 | grep 行号 |
| F7 | 旧轨测试调用点 = 1 处：`Tests/Test.DeepBase.DoQry.Literal.pas`（B2-13 的 4 例钉 `QuoteValue`），已随主控并网进 `Tests/DeepBaseTests.dpr`；`Tests/*DoQry*` 其余 4 件测的是 Persistence 轨（`DeepBase.DB.DoQry`），与旧轨无关 | `git grep -lE "uDoQryLegacy\|TDoQryLegacy"` |
| F8 | 仓内其他模块不引用旧轨符号；`Persistence/DeepBase.ORM.pas` 的 `BuildSelectSQL/BuildInsertSQL/…` 是 ORM 自己的同名方法（不同物）⇒ 迁移禁止按符号名全局替换 | `git grep -nE … -- ':!doQry/*'` |

## 二、能力对照（旧轨三处调用点的落点）

| 旧轨调用（F6） | doQry 轨 | Persistence 轨 | 结论 |
|---|---|---|---|
| `doQry(ProcName, aQry, ParamString): Integer` | `DoQryExecSelect/NonQuery/InsertReturningId/Scalar` | `UniDbSelect/Exec/InsertReturningId/Scalar` | 两套都存在但契约不同：参数 `k=v;k=v`→JSON；出口由调用方持 `TAdoQuery` 变 `out TClientDataSet`；需 Context |
| `BuildSQL(aQry, p): string` | `DoQryBuildSqlPreview` | `UniDbBuildSqlPreview` | 等价可迁 |
| `ShowCurrRecord(aDataset, field_num): string` | 无（`git grep -i CurrRecord -- doQry/src` 空） | 无 | **真缺口**，且与执行器无关：建议抽独立 UI helper 供三侧共用，不要塞进任一执行器（否则执行器长出第二职责） |

## 三、前置条件（P0→P7，按依赖顺序，每条给可机检判据）

- **P0 选路（主控裁定项，后续全部依赖它）**
  两条可执行路径，事实面见 §〇 对照表：
  - 路径甲：doQry 轨转正，Persistence 轨保持现状 ⇒ **两套参数化执行器并存**（SSOT 冲突，需说明为何可接受）。
  - 路径乙：doQry 轨退役，`doQryMain` 三处调用改指 Persistence 轨 ⇒ 单一真源、复用已测面；
    代价是 doQry 轨 1234 行与 `DoQryDemo.dpr` 的 demo 面退役，且 DoQryDemo 用到的
    `:memory:` SQLite 演示在 Persistence 轨需以 `UniDbMakeContext(udbSQLite)` 重写。
  判据：无（这是裁定，不是实测项）。乙不代主控选定。
- **P1 先修测试并网的编译断裂（硬阻塞，两条路径都要）**
  现状：`Tests/DeepBaseTests.dpr` 在 `--all` 与 T0 面都红 —— `Test.DeepBase.DoQry.Literal.pas(27) Fatal: F2613 Unit 'uDoQryLegacy' not found`
  （B8-01 实测：@`da846fa` 与 @`41783dc` 逐字一致 ⇒ 属主控并网笔的 doQry 搜索路径缺口，非本单引入）。
  判据：`node 09_工程脚本/build-gate/check_build.js --manifest 09_工程脚本/build-gate/contracts/T0-生产契约面.txt` DPR 面 BUILD_EXIT=0。
- **P2 给被选中的那一套一个契约面上的工程载体**
  路径甲：为 `doQry/src` 九单元选宿主（`prjDoQry.dproj` 加 contains + `DCC_U32`；或给 DoQryDemo 补 `.dproj` 并显式归面——新增 .dpr 须显式归面是 `T1-观测面.txt:8` 的既有规则）。
  路径乙：无此需求（Persistence 轨已在 `DeepBasePersistence.dpk`，T0 25/25 绿）。
  判据：宿主工程出现在 T0/T1 清单行上且 BUILD_EXIT=0，`CONFIG` 不再为 `default`。
  归属：改 `contracts/**` 清单行是主控的归面权（B8-03 也只动注释行）。
- **P3 补齐被选中轨的回归用例**
  路径甲：doQry 轨当前 0 测试（F7/§〇），至少要覆盖五个执行入口的参数绑定路径（真库或内存 SQLite，按 AGENTS.md 真实环境测试），并用一次性 runner 出 Found≠0 原件。
  路径乙：已有 4 件夹具，只需为 `doQryMain` 的三条 UI 路径补 1 件端到端夹具。
- **P4 迁移 F6 三处调用点（含数据层换型）**
  `doQryMain.pas` 从 `TAdoQuery` 换到 FireDAC（`TFDConnection` + `TClientDataSet`）牵动 `doQryMain.dfm` 的组件树与连接配置 UI —— 这是转正最大的真实破坏面，不是文本替换。
  判据：`prjDoQry.dpr` 单编 BUILD_EXIT=0 + 手工跑通「执行查询/生成 SQL/查看当前行」三条路径（对应 F6 三个入口）。
- **P5 安置 `ShowCurrRecord`**（§二 的真缺口，两条路径都要做）
- **P6 删除落选的那一套（最后一步，需兼容性评估）**
  路径乙的判据：`git grep -lE "uDoQryExecutor|DoQryExec"` 命中只剩 `doQry/src/**` 自身 ⇒ 才允许删 9 个单元 + `DoQryDemo.dpr` 面（删 .dpr 属不可逆，须主控授权，同甲-D6 §判据6 的先例）。
  路径甲的判据镜像：旧轨符号命中只剩 `uDoQryLegacy.pas` 自身 ⇒ 才删单元 + 撤 `prjDoQry.dproj` contains + 退役 `Test.DeepBase.DoQry.Literal.pas`（并同步 `Tests/DeepBaseTests.dpr` 的 uses，归主控）。
  共同注意：B2-13 修的 `QuoteValue` 语义（空串/`'NULL'` 置空约定，B2-13 §四 R2）在用例退役前必须先在执行侧有等价的"值不改 SQL 语义"用例（参数绑定本身就是该保证的结构性版本）。
- **P7 方言收口随 P0/P6 自然消解**
  B2-13 R1 否决的"给 legacy 加方言开关"不会因为任何一条路径复活：两条路径都以参数绑定取代文本拼接。

## 四、破坏面估计（按文件）

| 文件 | 改动性质 | 风险 | 适用路径 |
|---|---|---|---|
| `doQry/doQryMain.pas` | 3 处调用 + uses + 数据层类型 | 高（三条 UI 行为路径） | 甲/乙 |
| `doQry/doQryMain.dfm` | 组件类型与连接配置 | 高（随上行联动，二进制差异不可 diff 审） | 甲/乙 |
| `doQry/prjDoQry.dpr`/`.dproj` | contains/搜索路径增删 | 中（IDE 与门禁面一致性） | 甲/乙 |
| `doQry/src/*`（9 件 1234 行） | 升面或整体退役 | 高 | 甲=升，乙=删 |
| `doQry/examples/DoQryDemo/DoQryDemo.dpr` | 补 .dproj 归面或删除 | 中 | 甲=补，乙=删 |
| `doQry/uDoQryLegacy.pas`（1283 行/15 函数） | 最终删除 | 高（契约面消失） | 甲/乙终局 |
| `Tests/Test.DeepBase.DoQry.Literal.pas` | 退役或改指执行轨 | 中（B2-13 反事实用例是安全锚，删前必须有替代） | 甲/乙 |
| `Tests/DeepBaseTests.dpr`、`contracts/**` | uses 行 / 归面行 | 中（均归主控，乙不改，§〇-5） | 甲/乙 |

## 五、建议排期

1. 主控先裁 **P0**（甲/乙），并单独修 **P1**（门禁搜索路径，属测试基础设施，可与 D3/CI 矩阵单并单）。
2. 若走乙：直接 P4+P5（迁移三处调用），然后 P6 删 doQry 轨与旧轨——两步各自原子，中间态是"新迁移完成、旧轨仍在册"。
3. 若走甲：P2+P3 先行（建立契约面与用例），风险最低；再 P4+P5；最后 P6。并存期必须写明两套执行器的真相源分工，否则即为架构分叉。
4. 两条路径都不建议把 P6 与 P4 合在一笔：删面与改面分开，回滚半径才可控。

## 六、本项没做的事（申报）

- 未改任何 `.pas/.dpr/.dproj/.dfm`；未改 `contracts/**` 清单行；未创建转正工单本身（签发与选路权在主控）。
- B2-13 R1 原文「真正的收口是新轨转正 + 三处迁移」在本登记中被**事实修正**为「先选路，再迁移」：
  当时 §六 的取证面只看了 doQry 轨与 legacy，未把 `Persistence/DeepBase.DB.DoQry.pas` 纳入对照，
  因而把"唯一现存参数化执行器"认成了 doQry 轨。此处按实测更正，原始证据文件不改写。
