# WO-20260928-AUDIT-乙-B10 Commerce 过期判定时区框架混用修复（1 项）

> 签发：主控 · 2026-09-28
> 基线锚点：HEAD `a68264a`
> 派工对象：**开发 AI 乙**
> 来源：乙 B9 回执 §四.1 停机上报项（B9 按工单 §边界「诊断中发现生产侧缺陷 ⇒ 停机上报不顺手改」上交）+ 主控派发前零漂移核查（`git diff 098eeb3..a68264a -- Features/DeepBase.Commerce.SafeClient.pas Features/DeepBase.Commerce.Types.pas Features/DeepBase.Commerce.Permissions.pas` = 空，缺陷形态仍在）。
> 与甲 A9（`Tests/**` 假覆盖收口）、乙 B7（Licensing 域）、TESTDEBT-甲-001 零重叠；与乙 B9 同族不同动作（B9 只诊断不动生产，本单是 B9 建议的「 Commerce 域修复单」落地）。
> 状态：🟡 **待排**——乙线串行，**B7 交付验收通过后**开工（B7 前置②已于今日由主控复核解门，B7 未交付前本单不动；排期口径同 B9 先例：若届时乙线实无并发且文件零重叠，主控可直派提前并登记）。

## 〇、开工纪律（违者整单打回）

1. **H15 原子提交**：单笔提交，message 带 `B10`；显式 pathspec；前后 `git diff --cached --name-only` == 申报清单；**禁 push**。
2. **禁动区维持**：`Features/DeepBase.Licensing.pas`（B7 域，本单不碰）、`Features/DeepBase.TimeGuard.pas`（B9 回执点名只读，只读不碰）、`contracts/**`、`Tests/DeepBaseTests.dpr`/`.dproj`、`Tests/Integration/**`（B9 域）、`TestResults/**`、`v1.1.0` 标签 / EHAI 冻结面 / 新旧 PluginManager 轨。
3. **fail-closed + 先基线后修**：SafeClient 快照校验是许可热路径，动前必须先留既有 Commerce fixture 全限定基线跑录；修后既有断言红 ⇒ 停机上报，**不许改既有断言「修绿」**；修法若要求改既有断言语义 ⇒ 先停机。
4. **测试纪律**：全量 run 崩 216 是既存问题，禁止全量当判据；一律全限定 `<单元>.<Fixture>` 子集。
5. **符号/路径以开工 HEAD 实测为准**：§一 行号冻结于 `a68264a`（主控已验零漂移），开工重定位为准，找不到 ⇒ 报「已不成立」附 `git log -1`。
6. **时钟纪律**：不散着改其他域时钟（Core 的 Cache/DateTime 裸 Now 等已登记待派，不属本单）；「现在」一侧的取值形态见 §一。

## 一、修单：B10-01 [待修] Commerce 过期判定时区框架混用

- **代码事实（主控已核，乙 B9 独立同判，含 B9-2 探针原始输出留档）**：`Features/DeepBase.Commerce.SafeClient.pas:749-752`——
  - 解析侧 `TryISO8601ToDate(ASnapshot.ExpiresAtISO, ExpiresAt, False)`：对带 `Z` 输入，RTL 即使 `AReturnUTC=False` 仍做 UTC→本地换算，返回**本地裸值**（RTL 实测输入 `2026-09-28T14:29:25Z`、UTC+8 机器 ⇒ `22:29:25`；仓内同源结论 `Core/DeepBase.Serialization.pas:411-413` CR-016 已记「往返漂移 8 小时」）；
  - 墙钟侧 `TTimeZone.Local.ToUniversalTime(Now)`：**UTC 裸值**（同输入 ⇒ `14:29:25`）；
  - 两侧框架混用直接比较 ⇒ B9 阈值扫描实测：真实到期 H=−8h 之前才判过期、H=−7h（**已过期 7 小时**）仍判未过期 ⇒ UTC+8 机器上放行窗口被放宽约 8 小时（可白拿 ~8h 许可）；UTC 负偏移机器上同一段代码**提前**误拒合法许可。方向随时区变号，是**正确性缺陷**，非保守性问题。
- **枚举先行（不得只改工单点名处）**：开工先 rg 全 Commerce 域两侧清单并逐点分类，回执给全表：
  - 解析侧：`rg -n "TryISO8601ToDate" Features/DeepBase.Commerce.*.pas`
  - 墙钟侧：`rg -n "TTimeZone\.Local\.ToUniversalTime\(Now\)" Features/DeepBase.Commerce.*.pas`（主控 @`a68264a` 命中：`SafeClient:752`、`Permissions:300`、`Types:248` / `484` / `501` / `508`——注意主控命中点数多于 B9 回执点名三处，逐点过）
  - 每点分类：**判时点**（过期/宽限/可用性判定）vs **非判时点**（记录、超时测量等），判时点本次统一修，非判时点不改但逐条说明理由（B7 工单 `:968`/`:974` 同款口径）。
- **修法**：判时点两侧统一 **UTC 裸值框架**（比较成立的最小正确形态）；「现在」一侧取自甲 A5-R09 交付的 `TDeepBaseTimeSource.Shared.Now`（HEAD 在册：`Core/DeepBase.TimeSource.pas`，package `DeepBaseServices`，Features 可见；带 last-seen 单调水位 + `SetNowFunc` 可注入，与 B7 对 Licensing 的接线同范），经 `TTimeZone.Local.ToUniversalTime` 转换后与 UTC 裸值解析值比较。实现细节由乙定；判据是**混用归零 + 可注入 + 两侧同框架 rg 自证**。
- **回归（固定偏移、不随真实日期/真实时区漂移）**：在**已注册** fixture `Tests/Test.DeepBase.Commerce.pas`（`TDUnitX.RegisterTestFixture(TCommerceServiceTests)`，`:2210`）内新增断言，设计约束：
  - 固定 naive instant（如 `EncodeDate(2026,6,8)+EncodeTime(10,0,0)`），到期 ISO 由测试用**与生产侧同一 RTL 换算**（`TTimeZone.Local.ToUniversalTime`）从该 instant 推算 `±1s` 两向 ⇒ 断言对称：`now−1s` 必拒（`EDeepBaseCommerceValidationError` + 消息逐字 `License snapshot has expired`）、`now+1s` 必收；
  - 「现在」经 `TDeepBaseTimeSource.Shared.SetNowFunc` 注入该 instant，**用后 `try/finally` + `Reset`（或 `SetNowFunc(nil)`）还原**——共享单例，泄漏污染同进程其余用例，零容忍；
  - 该两向断言对「混用形态」在**任何时区偏移符号下都会咬人**（代数性质：`now−1s` 向只在 offset ≤ +1s 时混用才拒、`now+1s` 向只在 offset ≤ −1s 时混用才收，两向合取覆盖正负偏移）：本机 UTC+8 实测 + 必要时以 B9 的 `附件/B9TzProbe.dpr.template` 探针对推验；
  - 若既有 fixture 结构上无法构造该场景（拿不到 SafeClient/快照构造入口）⇒ 停机上报给替代方案，**不许自建不注册单元**（那是制造新的假覆盖，A9 正在收这种债）。
- **判据**：
  1. 修前基线：既有 `Test.DeepBase.Commerce` 全限定 fixture 跑录留档（纪律 3）；
  2. 修后同面全绿 + 结果集差异 = 新增用例（既有零回归）；
  3. **反事实**：把修好的任一侧换回混用形态 ⇒ 新负向断言**真变红**，还原后回绿，三步判定 EXIT=0（B9 `B9-4-反事实-step1/2/3` 同款留档）；
  4. `rg` 自证判时点无框架混用残留（两侧同框架清单进回执）；
  5. 集成面不回退：`run_tests.ps1 -Type Integration` 同面仍 11/11（CommerceE2E 基准，B9 注册的是第二面，别把它跑红）；
  6. `git diff` 自证只动申报的 `Features/DeepBase.Commerce.*` 生产面 + `Tests/Test.DeepBase.Commerce.pas`；
  7. 四门（encoding / eol / mojibake / evidence-encoding）EXIT=0。
- **边界**：`TimeGuard.pas:387` 只读；Commerce 域外点位（如 Core `Serialization` CR-016 同类）只登记回执不顺手改；修复不得改变对外错误消息语义（既有断言依赖逐字消息）。

## 二、输出物与验收

- 回执：`CodeReview/20260928-AUDIT-乙-B10-交付回执.md`（枚举全表、修法、修前/修后跑录、反事实三步、rg 自证、共享单例还原证明）。
- 证据：`CodeReview/20260928-AUDIT-乙-B10-证据/`。
- 验收（主控，零信任）：全限定复跑（不信自报）+ 亲读 diff + 反事实复核 + 禁动区 grep + 四门；台账 B10 行回填。
- 乙自报不作为验收依据。

*主控 · 2026-09-28 · 签发即生效、待排（B7 后）；本单是生产侧正确性缺陷，零容忍「先这样以后换」*
