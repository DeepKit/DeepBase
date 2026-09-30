# WO-20260929-AUDIT-乙-B12 超时/TTL 墙钟测量改单调计时源（P3 · 2 项）

> 签发：主控 · 2026-09-29（原 1 项）· 2026-09-29 由 B10 验收结论 §三 扩为 2 项（新增 B12-02，源自 B10 回执 §五.4）
> 排队态：**待乙 B13 验收后方可开工**（乙线不并发两单；B10 已 ACCEPTED，B13 是 B10 的派生收口）
> 基线锚点：开工时 HEAD（以 `git log -1` 为准，主控在派工消息中重锚）
> 派工对象：**开发 AI 乙**
> 缺陷来源：《20260929-AUDIT-主控-乙-B7-验收结论》§四派生表第 3 行（B12-01）+ 《20260929-AUDIT-主控-乙-B10-验收结论》§三（B12-02）

## 〇、开工纪律

1. **H15 原子提交**：message 带 `B12`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **禁动区维持**：`v1.1.0` / EHAI 冻结面 / `TestResults/**` / 旧新插件轨 / `Core/**` / `contracts/**` / `noise-baseline.json` / `Tests/DeepBaseTests.dpr|.dproj`（归主控）/ `Features/DeepBase.TimeGuard.pas`（甲 A11 域）。
3. **范围收敛为 `Features/DeepBase.Licensing.pas` 的 `ConfirmPurchase` 一个过程**，只把「墙上时钟测耗时」换成单调计时源；不得顺手重构该过程其他部分。
4. fail-closed / fail-open 语义不变：超时即退出轮询、返回当前 tier 判定的既存行为必须保持。

## 一、B12-01：`ConfirmPurchase` 超时测量改单调计时源

### 代码事实

`Features/DeepBase.Licensing.pas` 的 `ConfirmPurchase`：`var StartTime := Now;` 与 `if SecondsBetween(StartTime, Now) >= TimeoutSec then Break;`（按符号定位，交付树实测 `:1011`/`:1017`）。这是**同一进程内的耗时测量**，不参与任何许可/试用有效性判定 ⇒ 不属于 B7 清单里的「判时点」，B7 按纪律留用墙钟并登记。

### 缺陷

轮询期间一旦发生时钟回拨，`SecondsBetween` 为负 ⇒ 该轮**永不触发超时**（把「最多等 TimeoutSec」变成「无限等」）；前跳则可能提前放弃。墙钟是用户/系统可改的量，用它测量**时长**本身就是错的框架。

### 修法

- 换 `System.Diagnostics.TStopwatch`（仓内既有用法优先——先 `rg -n "TStopwatch" --glob '*.pas'` 找惯例样本，照仓内同形写；若该单元文件头注释需补 uses，按本仓现有模式加）。
- 语义保持：`LWatch.Elapsed.TotalSeconds >= TimeoutSec` 即 Break；`Sleep` 间隔不变。

### 判据

1. **静态自证**：改后 `rg -n "\bNow\b" Features/DeepBase.Licensing.pas` 命中数不变（`ConfirmPurchase` 两处归零；`:722`/`:882` 的 `TDeepBaseTimeSource.Shared.Now` 与被测超时无关，不许为「清零」动它们）。
2. **单测（新单元或既有 `Tests/Test.DeepBase.LicensingTimeSource.pas` 增补——若增补既有单元须整单元复跑 7+N 条全绿）**：注入一个「时间对但墙钟会跳」的场景不现实，故改用反事实判据——把 `TStopwatch` 换成墙钟的变异必须让新用例红（证明用例真的在测时长框架而非别的）。
3. **不回归**：`Test.DeepBase.LicensingTimeSource`（7/0）、`Test.DeepBase.License`（16/0）、`Test.DeepBase.Commerce`（62/0）全限定复跑，零新增红。
4. **编译/门禁**：隔离 `--detach` 树 T0 manifest EXIT=0；Hint 按码不超 `noise-baseline.json`；四门 EXIT=0。

### 输出物（B12-01）

`Features/DeepBase.Licensing.pas`（只 `ConfirmPurchase`）+ 可能的测试增补；下游（VCL/FMX/Studio/Unlock）只读不碰——若修法迫使签名变更 ⇒ 停机上报。

回执 `CodeReview/20260929-AUDIT-乙-B12-交付回执.md` + 证据 `CodeReview/20260929-AUDIT-乙-B12-证据/`；验收：主控亲跑 + 亲读 diff + 反事实复跑；乙自报不作为依据。

## 二、B12-02：`Idempotency.PurgeExpired` 的 TTL 判定改单调计时源

> 本项由 B10 验收结论 §三 从 B10 回执 §五.4 转派而来；B10 已认定该点**不属时区框架混用**（`PurgeExpired` 两侧同为进程内裸墙钟读数，`CompletedAt` 由同文件写入），真缺陷是「**用墙钟测时长**」——与本单 B12-01 同族同因同向，故并入本单而非另派。

### 代码事实

`Features/DeepBase.Commerce.Idempotency.pas` 的 `PurgeExpired`（按符号定位；修前行号线索 `:119`）：以 `TTimeZone.Local.ToUniversalTime(Now)` 为「现在」与 `CompletedAt`（同文件 `:170` 以同一函数写入）比 TTL。

### 缺陷

时钟回拨期间 TTL 计算为负 ⇒ 该轮不清理（缓存/幂等记录驻留超期）；前跳则提前清理。与 B12-01 同一框架错误：墙钟是用户/系统可改的量，不该用于测时长。

### 修法

- **先 rg 仓内 `TStopwatch` 惯例样本**（B12-01 也要做，两处共用同一结论），照仓内同形写。
- `PurgeExpired` 的性质是「**进程启动以来**」的清理：把 `CompletedAt` 的**绝对时刻**比较改为与**单调时钟**配套的形态（如启动时记 `TStopwatch` 基线、记录里存 elapsed 值；或若仓内惯例是记录墙钟 + 单调兜底，照惯例写）。选型理由写进回执，**不得**引入第二套计时抽象。
- `Idempotency:150/170` 的 `CreatedAt/CompletedAt` 留痕字段若维持墙钟（自留值、只做留痕），须在回执说明为何不需要改；若要改，一并申报。

### 判据

1. **静态自证**：改后 `rg -n "TTimeZone\.Local\.ToUniversalTime\(Now\)" Features/DeepBase.Commerce.Idempotency.pas` 命中数按申报值下降（留痕点保留须逐点给理由）。
2. **单测**：`Test.DeepBase.Commerce.Idempotency`（若无该 fixture ⇒ 新建于既有单元，全限定）注入/构造「已完成超过 TTL」的记录 ⇒ 清理发生；时钟回拨场景下**不得**把未到期记录提前清理、也不得让到期记录永驻。
3. **反事实**：换回墙钟比较必须让新用例红（证明测的是时长框架）。
4. **不回归**：`Test.DeepBase.Commerce` 68/68 与 Commerce 邻接 fixture 零新增红（B10 已把 Commerce 面从 62 抬到 68，基线以 `3a5e8ae` 为准）。

## 三、破坏面与输出物

`Features/DeepBase.Licensing.pas`（只 `ConfirmPurchase`）+ `Features/DeepBase.Commerce.Idempotency.pas`（只 TTL/清理相关）+ 可能的测试增补；下游 VCL/FMX/Studio/Unlock 只读不碰——若修法迫使签名变更 ⇒ 停机上报。两项 = **两笔 H15**（一笔一项）。

回执 `CodeReview/20260929-AUDIT-乙-B12-交付回执.md` + 证据 `CodeReview/20260929-AUDIT-乙-B12-证据/`；验收：主控亲跑 + 亲读 diff + 反事实复跑 + 隔离树 T0；乙自报不作为依据。

*主控 · 2026-09-29 签发 · 排队项，B13 未验收不得开工；本单 2 项两笔提交，禁合并*
