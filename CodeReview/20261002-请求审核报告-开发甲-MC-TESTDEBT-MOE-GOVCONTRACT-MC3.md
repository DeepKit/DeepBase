# 请求审核报告 · 开发 AI 甲 · MC-20261002 四单批次

> **批次**：2026-10-02 主控「全仓缺口清点」新派 4 单
> **执行**：开发 AI 甲 · 2026-10-02 01:0x – **01:46:56**
> **基线 HEAD**：`41b580a` → **交付 HEAD**：`c6be63f`（+ 本报告 1 笔）
> **改动面**：63 文件 / +21527 / −1；**零 `.pas` / 零 `.dpr` / 零 `.dpk` / 零 `.dproj`**（本批四单全为清点/转派/治理/验收类，无一条是生产代码单）
> **纪律**：8 笔 H15 原子提交（逐单一笔 + 1 笔门禁缺陷修正），显式 pathspec，**未 push**；台账状态槽**未改**（逐单给出建议措辞交主控回填）
> **四门**：eol 1662 / encoding 1017+798 / mojibake 1015·丙-B 0 / evidence-encoding 1234·E3=240，**四道 EXIT=0**；contract-gate 单列，EXIT=1 且归因完毕

---

## 〇、一页速览（老板只看这一段）

| 单 | 优先级 | 承接的缺口 | 本轮交付 | 结论 |
|---|---|---|---|---|
| **WO-20261002-MC-甲-TESTDEBT-R01** | P1 | 账外单在派单总表四处零登记、账外 4 天无人开工无人验收；双红灯（HB Gate6 / Timeout PBT AV） | 双跑读数 + 转绿归因三选一 + F2 根因代码级定位 + 重锚差异表 | **F1 绿、归因「环境伪影」；F2 仍红、根因是「用例的 TTask 观察机制与生产 TManagedWorker 脱节」的确定性空指针，不是竞态**。双红灯**未闭环**（本单只清点不修） |
| **WO-20261002-MC-甲-MOE** | P3 | 讨论包落盘 7 天仍 `??` 未跟踪、工单目录零命中（连单子都没有） | 41 条三态标注 + 6 项工单族 + 5 个决策点 + 依赖序与争用面 + 3 份派生工单草案 | **决策点 5 个全部上交老板未自决**；3 张取证单可现在开工；实现单 MOE-06 被 5 项前置阻塞 |
| **WO-20261002-MC-MC3** 项 1 | P1 | A5 / A8 交付数日未验收（甲线完成度最大悬空） | 两棵隔离树、12 探针亲跑、反事实双向留档、复跑驱动入库 | **A5 ACCEPTED 8/8（R02 已由 A16 另单验收）+ A8 ACCEPTED 1/1** |
| **WO-20261002-MC-MC3** 项 2 | P1 | CI runner 两次 cancelled，集成跑录从未真跑 | `gh` 原文取证 + 三选一方案书 + 决策点 | **工单前提低估了**：不是「集成没跑」，是**整条 CI 零 step 执行**；且 yml 的 Delphi 版本口径与仓内不符 |
| **WO-20261002-MC-MC3** 项 3 | P1 | DB4 三件函件全停在「待发函」、无一件有草稿 | 三封问题清单化草稿 + 呈报件 | **三封在盘、一封未发**；COS 那件顺带坐实「全仓零代码引用 COS」⇒ 不配的兜底零代价 |
| **WO-20261002-MC-MC3** 项 4 | P1 | `git status` 60 条卫生未收 | 60 条逐条三分归位 + 前后取证 | **60 → 20**，`≤40` 达成且**零掩盖** |
| **WO-20261002-MC-主控-GOVCONTRACT** | P3 | `DeepBase.DataBinding` 未入约 ⇒ A16 的 breaking change 门禁看不见 | 契约格式亲读 + 消费者面亲核 + 裁定件 + 修前/修后读数 | **裁「登记」**（`stable` + `critical`），**不建基线**；代价是一条有信息量的记账性红；并亲验出 contract-gate 的**通用结构盲区** |

---

## 一、四份交付件（绝对路径）

```
D:\_Progs\02Business\DeepBase\CodeReview\20261002-请求审核报告-开发甲-MC-TESTDEBT-MOE-GOVCONTRACT-MC3.md   ← 本文件
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-甲-TESTDEBT-R01-交付回执.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-甲-MOE-交付回执.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-GOVCONTRACT-裁定.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-A5A8-验收结论.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-MC3-项2-CI方案书与决策点.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-MC3-项3-发函呈报件.md
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-MC3-项4-工作树卫生.md
```

**证据目录**

```
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-甲-TESTDEBT-R01-证据\      （6 件）
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-甲-MOE-证据\              （2 件）
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-GOVCONTRACT-证据\     （2 件）
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-A5A8-证据\           （7 件，含可复跑的复跑驱动脚本）
D:\_Progs\02Business\DeepBase\CodeReview\20261002-AUDIT-主控-MC3-项4-证据\        （4 件）
D:\_Progs\02Business\DeepBase\CodeReview\20261002-请求审核报告-开发甲-MC-TESTDEBT-MOE-GOVCONTRACT-MC3-证据\四门-跑录.txt
```

**派生工单草案（新建于工单目录）**

```
D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20261002-MC-甲-MOE-EV-外部标杆事实取证.md
D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20261002-MC-甲-MOE-JOBS-调度面复用裁定.md
D:\_Progs\02Business\DeepBase\docs\ui\work-orders\WO-20261002-MC-甲-MOE-DP-决策点包.md
```

**DB4 函件草稿（未发送）**

```
D:\_Progs\02Business\DeepBase\docs\DB4-20261002-试用到期签发协议确认-草稿.md
D:\_Progs\02Business\DeepBase\docs\DB4-20261002-可观测性诉求回执催办-草稿.md
D:\_Progs\02Business\DeepBase\docs\DB4-20261002-COS未配置决策材料-草稿.md
```

---

## 二、逐单结论与判据读数

### 2.1 WO-20261002-MC-甲-TESTDEBT-R01（P1）

**交付件**：`CodeReview/20261002-AUDIT-甲-TESTDEBT-R01-交付回执.md` + 证据 6 件 · 提交 `47d4fd1`

**F1（HB Gate #6 USER handle 基准）现状 = 绿，归因「环境伪影」**

- 隔离树 `D:/_ProgData/DeepBase-TDR01/wt-41b580a` @ `41b580a`，`Scripts/run_tests.ps1 -Type Unit -Run "Test.DeepBase.HB.Benchmark"` **三次连跑**：`7 found / 7 passed / 0 failed / 0 errored / RUN_EXIT=0`，Gate#6 读数**三次逐字相同**（`GDI 42->42` / `USER 37->36` / `USER 36->36`）。
- 三选一归属：**环境伪影**。排除「修复」：窗口 `59a1a24..41b580a` 内该基准文件**零 diff**、`VCL/` 与 `FMX/` **全域零 diff** ⇒ 没有代码变过。排除「断言被弱化」（红线专项）：该文件自 `4d818af`(2026-09-21) 未改且 `merge-base --is-ancestor 4d818af 59a1a24 = 0` ⇒ 审计方 2026-09-28 跑的那份断言与今天**逐字相同**，`:728/:731/:734` 的 `delta ≤ 0` 硬阈值未动分毫。机制：`GetGuiResources(GetCurrentProcess, …)` 取进程级全局计数，断言要求 delta ≤ 0，全量进程里任一其他夹具在两次取样间新建 USER 对象即产生伪增量。

**F2（Timeout PBT `Property6` AV @ nil）现状 = 仍红，根因「用例断言机制随生产重构失效」，竞态假说被证伪**

- 复现：`2 found / 1 passed / 0 failed / **1 errored**`，`AV + Read of address 0000000000000000`，`RUN_EXIT=1`，与审计方签名逐项相同（仅地址/偏移随二进制不同）。
- 四步链：生产 `TTimeoutPolicy.Execute` 走 `TManagedWorker`（`Core/DeepBase.Resilience.Timeout.pas:98-112`）⇒ `TCoreThread = class(TThread)`（`Core/DeepBase.ManagedWorker.pas:37`）**不是 `TTask`** ⇒ 用例 `:240` 的 `TTask.CurrentTask` 在纯 `TThread` 上**恒为 nil** ⇒ `nil.CheckCanceled`。
- **时序反证**：循环体 `Sleep(10)` 后立刻 `CheckCanceled`，首次迭代 t≈10 ms 即崩，而超时预算 `CTimeoutMs = 50`（`:215`）⇒ **AV 早于 Cancel 40 ms** ⇒ 竞态假说要求的「Cancel 与回调竞争」时间窗**不存在**。
- 窗口内三件（用例 / `Resilience.Timeout.pas` / `ManagedWorker.pas`）**零 diff**，最后改动均 2026-09-19 ⇒ 非区间内回归，是自 `649b1e0` 起的既存缺陷。
- 修法建议案 (a)（用例改 `TThread.CurrentThread.CheckTerminated` + 订正 `:33-41` 的前提注释，**零生产改动**），**不在本单执行**。

**重锚**：`59a1a24 → 41b580a` = 96 笔 / 435 文件 / +34866 / −222，按 14 个目录逐条列出对两灯判读的影响，结论**零影响**。

| 判据 | 读数 | 结论 |
|---|---|---|
| 1 F1 现状读数（主树与隔离树双跑一致） | 隔离树侧三次全绿、读数逐字相同；**主树未跑**——A13 §五 已坐实主树陈旧 DCU 污染（45316 `.dcu` + 67 `.dcp`）致编译必红 E2251，属既存环境债。**如实登记取得条件，未以推测顶替读数** | **部分成立（诚实收窄）** |
| 2 F1 转绿归因三选一有证据 | 「环境伪影」；排除另两项各有独立硬证据 | 成立 |
| 3 F2 复现 | 隔离树仍 AV，稳定复现，无需环境差异解释 | 成立 |
| 4 F2 诊断结论有调用栈/线程时序证据 | 竞态假说不成立；四步代码链 + t≈10 ms < 50 ms 的时序反证 | 成立 |
| 5 红线自查 | 零 `.pas`、零测试改动、零断言改动、零删跳 | 成立 |
| 6 重锚记录逐条 | 435 文件按 14 目录 + 两灯涉及面逐件 diff（4 件全空 + VCL/FMX 全域空） | 成立 |
| 7 四门逐道门名 + EXIT | 见 §四 | 成立 |
| 8 单笔 H15 / 显式 pathspec / 未 push | `47d4fd1` | 成立 |

---

### 2.2 WO-20261002-MC-甲-MOE（P3 · 清点单 · 零生产代码）

**交付件**：`CodeReview/20261002-AUDIT-甲-MOE-交付回执.md` + 证据 2 件 + 3 份工单草案 · 提交 `5ce7d52`

- **三态标注**：41 条逐条有态 —— **已证 10 / 待证 14 / 纯提案 17**，无未标注节。外部标杆 `FareedKhan-dev/kimi-k3-in-c` 的 8 项关键数字本仓零镜像零 vendored 源码，**全部维持「待证」**，未因「写得详细」而默认其正确。
- **亲验 5 处「已证但讨论包表述有缺口」**：G1 ONNX 依赖是 `{$IFDEF HAS_ONNX}`、未装即抛 not available（复用面在默认构建里是空的）；G2 `Inference.MoE.*` 四键**零读取面**；G3 `TInferenceProvider` 是枚举、扩位移动 ordinal ⇒ 属契约变更；G4 `Libs/Native/` **不存在**；G5 仓内已有三套作业/调度面 ⇒ §5 Phase3 新建第四套撞它自己的 G5。
- **亲验 3 处内部自相矛盾**：C1「与 PyTorch 字节级一致」vs G3「零依赖无 Python」（且浮点 GEMM 字节级一致工程上不可达）；C2 Phase3 新建队列 vs G5 禁分叉；C3 场景 B 8~32 GB vs §1.2 的 8.24 GB。
- **工单族 6 项**（六要素齐）：MOE-01 外部标杆事实取证(S) / MOE-02 HB 延迟与断网降级取证(S) / MOE-05 调度面能力矩阵与复用裁定(M) / MOE-03 MoE ABI 纳入既有契约面(S) / MOE-06 Phase-1 原生内核探针(M) / MOE-04 决策点包(S)。**可现在开工 3 张**（MOE-01/02/05，授权面只有 `CodeReview/**` 与 `docs/`，零禁动区触碰）。
- **决策点 5 个全部上交老板未自决**：DP-1 路线批准 / DP-2 选型重心 / DP-3 源码落地位置（讨论包原三项）+ **DP-4 MoE ABI 是否进既有治理面**（新增）+ **DP-5 Phase 1 判据如何订正**（新增）。每条给了「不给建议的拍板理由」。
- **争用面** 7 个拟触及面逐件与在途单比对，3 处有重叠并各给规避或排序：`contract/consumer-contract.json` 与本轮 GOVCONTRACT **直接争用**（MOE-03 必须等其落笔）、`Core/DeepBase.Manager.pas` 经 MC3 项 1（只读无实际争用）、`09_工程脚本/contract-gate/**` 经 CONTRACTGATE（MOE-03 不动判定逻辑故可并行）。
- **首批建议**：MOE-01 + MOE-05。MOE-02 排批外 —— 其定位类结论属 HB 线既有工单链，**不由 MoE 族代裁**。

| 判据 | 读数 | 结论 |
|---|---|---|
| 1 三态标注 + 汇总 + 无未标注节 | 41 条全有态，逐条给取证命令或依据行号 | 成立 |
| 2 工单族六要素齐、判据可复算 | 6 项齐；每项判据含负样本/反事实要求与「零 `.pas`」自证项 | 成立 |
| 3 决策点逐条标注「上交」 | 5 个全上交；另给「取证单 or 决策点」逐条裁定（3 取证 / 5 决策） | 成立 |
| 4 争用面清单 + 规避或排序 | 7 面逐件比对；3 处重叠各给处置 | 成立 |
| 5 零代码 | `git diff --cached` 亲核四类工程文件（pas / dpr / dpk / dproj）命中 **0** | 成立 |
| 6 台账 | 未改；建议措辞见回执 §六 | 成立 |
| 7 四门 | 见 §四 | 成立 |
| 8 单笔 H15 / 显式 pathspec / 未 push | `5ce7d52` | 成立 |

---

### 2.3 WO-20261002-MC-MC3 项 1 · A5 / A8 零信任验收

**交付件**：`CodeReview/20261002-AUDIT-主控-A5A8-验收结论.md` + 证据 7 件（含可复跑的复跑驱动脚本） · 提交 `375ec8f`，门禁修正笔 `c6be63f`

- **隔离树两棵**：`wt-post-a68264a` @ `a68264a`（修后）/ `wt-preA8-3c8a6a7` @ `3c8a6a7`（A8 缺陷态）。12 个探针**全部取自交付树本体**的 `CodeReview/**/附件/*.dpr.template` —— 零信任的第一条就是不用主树的附件。
- **A5 修后侧**：12 探针编译全 `EXIT=0`，运行 **11 绿 + 1 红**。唯一红是 `A5R03Wide` 的 4 例失败，且**修前侧逐条逐字相同**（两份 `run.log` diff = 0）⇒ **既存红、非本轮引入**；失败集合全在 `Test.Regression.BUG007_WhenReadyDeadlock`，不在 A5 任何一项授权面内。
- **A8 反事实双向成立**：修前 `ENoTestsRegistered / RUN_EXIT=2`（红侧带 B2 模板三道 fail-closed「0 用例不算绿」，不是靠退出码猜）→ 修后 `2 found / 2 pass / RUNNER_VERDICT: PASSED / RUN_EXIT=0`。两树差集**恰为两处**：`A5R09Verify` `78→80` found、编译 `43899→43902` 行 ⇒ 与甲自报逐字吻合。
- **与甲回执逐项对照 9 项**：三处差异全部落在「口径差 / 被 A8 叠加」，**零真偏差**；另发现一处申报不完整（R04 两个 Serialization 探针各 3 例 `[Ignore]`，Failed/Errored 同为 0，非缺陷但未单列）。**甲的申报诚实度可采信** —— 其自报的每一处不利读数（宽集 4 红、编译行数）本轮都独立复现。
- **裁定**：**A5 ACCEPTED 8/8**（R01/R03/R04/R05/R06/R07/R08/R09）；**R02 不复裁定**（已由 `WO-20261002-MC-甲-A16` 于 2026-10-01 ACCEPTED 1/1），本轮只确认 R01 与 R02 同文件叠加无相互破坏（`A5R01Verify` 71/71）；**A8 ACCEPTED 1/1**。建议主控把 A5 行整体转 ✅。

**新登记 4 项（按「清点出无单承接的面就要有单」当场落账）**

| # | 发现 | 归属建议 |
|---|---|---|
| N1 | `Test.Regression.BUG007_WhenReadyDeadlock` 4 例既存红，`git grep BUG007 docs/ui/work-orders/` **零命中** ⇒ 至今无单承接 | **建议主控立单**（`DeepBase.Manager` 生命周期域，排在 A5 结项后、A12 前） |
| N2 | R04 两探针各 3 例 `[Ignore]`，甲回执未单列 | 登记（非缺陷）；建议把 ignored 例清单纳入 Serialization 面交付申报模板 |
| N3 | DUnitX ConsoleLogger 中文断言消息落 GBK 乱码 | 登记；受影响面是「从日志读失败原因」，取证应附 XML 或定向复跑 |
| N4 | A5/A8 判据的可执行载体是 `CodeReview/**/附件/*.dpr.template` 13 份 | 登记；建议入台账，避免归档证据时被当附件清掉 |

| 判据 | 读数 | 结论 |
|---|---|---|
| 1 隔离树复跑 A5 九项，不引用甲方数字 | 两树 12 探针亲跑留档；甲数字只在对照列 | 成立 |
| 2 A8 反事实双向留档 | 修前 `ENoTestsRegistered/RUN_EXIT=2`（带 fail-closed）；修后 `2/2 PASSED/RUN_EXIT=0` | 成立 |
| 3 与甲回执差异逐条归因、无「未核」 | 9 项逐条；3 处差异全部归因；零真偏差 | 成立 |
| 4 四门 | 见 §四 | 成立 |
| 5 显式 pathspec、未 push | `375ec8f` + `c6be63f` | 成立 |

---

### 2.4 WO-20261002-MC-MC3 项 2 · CI runner 方案书与决策点

**交付件**：`CodeReview/20261002-AUDIT-主控-MC3-项2-CI方案书与决策点.md` · 提交 `d4e7b13`

**`gh` 原文取证（判据 1）**

- `33701496844`：`createdAt 2026-09-03T00:54:57Z → updatedAt 2026-09-04T00:55:00Z`（**24h0m3s**）；`32099652781`：`2026-08-18T04:34:37Z → 2026-08-19T04:34:39Z`（**24h0m2s**）⇒ 均撞 GitHub 对排队中 job 的 24 小时上限。
- 两次 run 的**全部 job 逐条**列出：6 条 `package-gate` 的 `startedAt` 与 run 的 `createdAt` **相差 1 秒**、`completedAt` 恰好 `+24h`、**`steps` 为空**；其余 5 条 `skipped`。
- 归因三步排除：不是失败（失败会跑完 step）；不是拿到 runner 后超时（拿到才会分配 `steps[].startedAt`）；是**无可用 runner**。

**两条对工单前提的订正（必须记，否则方案书会照着错前提写）**

| # | 工单/台账原文 | 订正 |
|---|---|---|
| **C1** | 「`integration-tests` job 依赖 self-hosted ⇒ 集成跑录在 CI 从未真正执行」 | **低估**。yml 中 **7 个 job 全部** `runs-on: [self-hosted, delphi-windows]`，含 `encoding-gate`（六道静态门禁 + `contract-gate`）⇒ **整条 Delphi CI 自建库以来零 step 执行**。「CI 绿」在这条流水线上的含义是**零信号**，不是通过 |
| **C2** | 隐含「yml 本身可用，只是缺机器」 | **不成立**。yml `env.DELPHI_PATH` 指向 Studio **23.0**，而仓内与本机实际工具链是 **37.0**；实测 `Test-Path '…\Studio\23.0'` = **False** ⇒ **即使明天接上 runner，也会在「Verify Delphi environment」步骤 `Write-Error` 退出 1**。方案 (a)/(b) 都必须先修版本口径，否则是接一台跑不出结果的机器 |

**三选一方案书（判据 2）**：(a) 接通 self-hosted runner（老板的机器与时间；接通即红须与 CONTRACTGATE 时序对齐）/ (b) 改托管 Windows runner（**许可路径未解决前不成立**，不是「改一行 yml」的成本）/ (c) 正式 DEFERRED + 双处明示「从未执行」。

**遵守工单中止线**：老板拍板前不动 `.github/workflows/**` ⇒ **连方案 (c) 的 yml 文案也未写**，只把改什么/改在哪一行逐条列出，并备好台账替换文案（§四）。

**TimeGuard 非 Windows `raise` 分支（判据：是否必须等 runner）**：**不必须等 Windows self-hosted runner，但必须等某个 Linux 执行环境 —— 两者不是一件事**。`SecretStore.pas:99` 的 `raise` 位于 `{$ELSE}` 分支（已逐行亲读 `{$IF DEFINED(MSWINDOWS)}` 三处分界）；本机 `dcclinux64.exe` 存在可**交叉编译验语法但不能验运行期行为**；`wsl --status` 在本机会话内挂起未返回（超时 120 s）⇒ **如实登记为「未取证」，不假装有**。该项**不并入** CI runner 决策，另立「Linux 执行环境」前置。

---

### 2.5 WO-20261002-MC-MC3 项 3 · DB4 发函三件

**交付件**：`CodeReview/20261002-AUDIT-主控-MC3-项3-发函呈报件.md` + 3 封草稿 · 提交 `b59cd0e`

| 件 | 收件人 | 事实依据 | 问句数 | 兜底条数 |
|---|---|---|---|---|
| ① 试用到期签发协议确认 | 王维 | 6（`git grep` 可复算：`CFG_TRIAL_EXPIRES` 全仓唯一读点 `:710`、**零写方** ⇒ 试用到期是死路径） | **7**（Q1–Q7，含「贵侧短期做不了」的**兜底对齐题** Q7） | 5（默认 Q1=否、15 工作日，逐条标风险方向：多给许可=宽松 / 提前 8h 到期=偏严 / 误判过期=收紧 / 离线试用敞口敞开） |
| ② 可观测性诉求回执催办 | 王维 / 运维 | 4 | **7**（Q1 为**勾选式**：「前两次函是否收到：已收（人+日期+结论）/ 未收（正确收件人+渠道）」） | 5（10 工作日；**直书代价**「跨端时间框架争议无客观仲裁依据，今后每次都要靠双方各测一次，不是可持续做法」） |
| ③ COS 未配置决策材料 | **老板（付毅）** | 6 | **3**（D1–D3，「本件不代答」） | 4（默认「D1 无书面需求 / D2 桶在 DB4 侧 / D3 不涉及出境涉密 / 逾期不答 = 维持现状不配」） |

**为什么拆三封**：三件事的收件对象、决策人、答复周期、阻塞的下游都不同。合并会让 ① 的协议问题把 ② 的催办压成「一并等」，把 ③ 的不可逆决策（桶在谁名下）淹没在一堆技术问句里。

**③ 的诚实收窄 + 补强**：台账记「COS 从未配过（NXDOMAIN）」**本轮无法复证** —— 唯一配置记录在 `docs/66.backend.DB4后端交接说明-db4-backend-handoff.md:397-400` 且 bucket/region 均脱敏为 `******`，全仓无可比对域名。但补了一条更有价值的实证：**全仓零代码引用 `COS_BUCKET`/`COS_REGION`/`COS_SECRET_ID`/`COS_SECRET_KEY`** ⇒ DeepBase 侧无功能硬绑 COS ⇒ 「不配」的兜底**零功能代价**（这使 A4 敢设成安全默认）。

**发送纪律（判据 3）**：三封头部均标「状态：草稿 · 未发送」；发函日期字段留「待呈报批准后填」、渠道字段留「待定」；**发送动作 0 次**；**全文零「已发 / 已寄 / 已通知」表述**。B11 维持 blocked。

---

### 2.6 WO-20261002-MC-MC3 项 4 · C0-02 工作树卫生

**交付件**：`CodeReview/20261002-AUDIT-主控-MC3-项4-工作树卫生.md` + 证据 4 件 · 提交 `9d20d2d`

**60 条逐条三分归位，无「待定」**

| 组 | 件数 | 归属 | 执行 |
|---|---|---|---|
| A · `CodeReview/**` | 27 | ① **入账提交** | ✅ 完成 |
| B · `.workbuddy/**` | 10 | ② **入 `.gitignore`**（`:127` 新增） | ✅ 完成 |
| C · 根目录 0 字节 | 3 | ③ **删除** | ✅ 完成，前后取证各一件 |
| D · `docs/**` | 20 | ④ **分类登记待主控裁定** | ⏸ 不擅动 |

- **A 组入账而非忽略的理由**：23 个 `.log` 正是 `.gitignore:118` 反向规则（`!CodeReview/**/*.log`）的设计意图 —— 忽略它们等于把设计意图作废。2 份 `.xml` 各约 976 KB，但仓内已有 **22 份**同族 `.xml` 在库、其中 5 份 **950–1021 KB** 与本批同量级 ⇒ **不另立 XML 排除规则**（否则同族两种口径）。
- **B 组**：派单口径「应入 gitignore 而非入账」成立，但**实测部分推翻** —— 该目录下**已有 5 件在库**（MEMORY 与 MEMORY-ARCHIVE 两份，以及 2026-09-19 / 09-20 / 09-21 三份日记），`gitignore` 不回溯已跟踪文件 ⇒ 现状「5 在库 + 10 忽略」两口径并存；**是否 `git rm --cached` 那 5 件属索引删除，超出本单授权面，留主控裁定**。
- **C 组删除取证**：三件 `Length` 全 0、内容指纹全 `e69de29…`（Git 空 blob）、时间戳全 `2026-09-24 17:12:34` 与本机封版 `v1.1.0` 同日同期；**第二件「版本：」文件名末尾含两个 `U+F02A` 私用区码位 ⇒ 文件名本身即事故产物**；`git ls-files` 查同名 = 空 ⇒ **从未入库，删除不产生任何历史变更**；封版正文在 `CodeReview/20260924-AUDIT-主控-封版记录.md`。删除后目录枚举复查 = 0 残留。
- **D 组分类**：D1 MoE 讨论包（**在寿命期**，本轮已派 3 份工单草案）建议入账；D4 两条 dcc64 编译证据建议入账；D2（8 月 HB 轮交付报告与裁决 13 件，各自有最终裁决）+ D3（已完成工单 brief 3 件）建议归档或删除；D5 `docs/ui/HB-HACI-Visual-Alignment.md` 待 HB 线确认是否仍生效。

**`.gitignore:118` 反向规则复验（判据 3、5）**：新造 `CodeReview/zz-probe-reverse-rule.log` → **仍出现在 `git status`**（`check-ignore -v` 输出 `.gitignore:118:!CodeReview/**/*.log`）⇒ 反向规则**未被误伤**；新增 `.workbuddy/` 规则生效（该目录下新造的探测件不出现在 status，命中 `.gitignore:127`）。**探针已清理。**

**status 条目**：60 → 删 3 件 → 57 → 忽略 10 件 → 47 → 扣除本轮各单自身新增入库件 → **20 ≤ 40** 达成。**降数零掩盖**：10 件来自忽略工具本地现场、3 件来自已证零信息损失的删除、27 件来自证据件**入账**，无一件是把在寿命期的证据件塞进忽略规则。`.tmp/wt_a2_head` 按既有裁定**维持保留未动**。

**另登记**：仓内现存 **18 棵 worktree**（15 棵 `D:/_ProgData/DeepBase-*` + 2 棵 `E:/temp/` + 主树）。A13 验收结论 §十 已记「`D:/ProgData/DeepBase-*` 全部隔离树曾在验收过程中被外部清理」⇒ 建议主控逐棵确认锚点后主动收口。

---

### 2.7 WO-20261002-MC-主控-GOVCONTRACT

**交付件**：`CodeReview/20261002-AUDIT-主控-GOVCONTRACT-裁定.md` + 证据 2 件 + `contract/consumer-contract.json` 改动 1 件 · 提交 `ef19eb7`

**判据 1 · 契约格式亲读**（工单要求的「字段语义有出处」逐字段给了出处）

- 路径实况是 `contract/consumer-contract.json`（**单数**，18 单元）。**工单 §二-4 写的 `contracts/…`（复数）是笔误** —— `contracts/` 是另一套（T0/T1 契约清单），已在裁定件订正。
- 18 单元**全为 `stable`**；`check_contract.js:48` 允许 `stable | internal | deprecated`，**仓内 `internal`/`deprecated` 各 0 条** ⇒ 定级先例只有 `stable` 一种。
- 字段语义：`unit`/`subdir`/`stability`/`consumers`/`breaking_change_policy` 是必填（`:82-84`）；**`consumers`/`critical`/`why` 仅文档性，不参与任何判定**；`stability=stable` 才进签名漂移检测（`:223`）。

**判据 2 · 消费者面亲核（禁凭回执转述）**

- 仓内：`DeepBase.DataBinding` 引用面 = 生产 `Core/DeepBase.MVVM.pas` + `VCL/DeepBase.VCL.BindableControls.pas` + `VCL/DeepBase.VCL.MVVMControls.pas`（3）+ `Examples` 2 + 测试 4 + 包登记 2。
- **`TBindingManager.Bind` 的生产面调用点 = 0** —— `:15-16` 的 `FBindings.Bind(...)` 只出现在**单元头注释的示例代码**里；真实调用点全在 `Examples/`。⇒ A16 的 breaking change 对仓内生产代码**零影响**（独立复核成立）。
- 外部：**DeepSync 源码树两次 grep 零引用**（唯一字样在二进制 `.rsm` 本地化资源内，非源码引用）。

**裁定两问**

| 问 | 结论 | 要点 |
|---|---|---|
| 是否登记 | **登记** | 它是 Core 单元、在 DeepBaseCore 包工程的 contains 面登记、有 3 生产消费点；不登记的后果已被实测坐实（一次 breaking change 已发生而门禁连「不在检测面内」都不会说）。工单判据 5 要求「若裁不登记须写明盲区由何种别的手段覆盖」—— 本单**逐条搜寻仓内是否存在可替代的人工审阅清单，结论为不存在** ⇒ 裁「不登记」会落到工单明令禁止的「不登记且无覆盖」 |
| 定何级 | **`stability=stable` + `critical=true`**，`consumers=5` + 新增 `consumers_basis` 字段 | **不裁 `internal`**：`internal` 只进存在性/唯一性检查（`:223` 只 filter `stable`），裁 `internal` 等于把这次登记做成「登记了但仍然看不见」，是本单要消灭的状态换了个词。`consumers_basis` 是为消歧——不加它，仓内既有 1…54 的兄弟项目计数与这个 5 会被读成同一把尺子 |
| 基线取法 | **本单不取；发版时按发布 ref 的 HEAD 快照取** | 四条理由：①`signature-baseline.json` 的 `generatedFrom` 自述「随每次发布重新生成并提交」，是发版快照不是随手可重录的配置；②**按 HEAD 建基线 = 把已发生的收窄洗成「从未存在」= 洗白**，正是工单禁止的；③取 A16 前旧签名 = 让门禁永远报一条已处置项，噪声掩盖真发现；④不建基线的代价**可量化且可接受**（见下） |

**判据 4 · contract-gate 修前 / 修后读数（未用 `--emit-baseline`）**

| | 修前 | 修后 |
|---|---|---|
| 扫描单元数 | 18 | **19** |
| 破坏性变更项 | **1**（含 2 条签名明细） | **2**（含 2 条签名明细 + 1 条新登记提示） |
| EXIT | 1 | 1 |

新增项 = `stable 单元 DeepBase.DataBinding 不在基线内（新纳入稳定的单元须发版时写入基线）` —— **记账性红**：三件事同时成立（已入约 / 尚未进入比对面 / 补齐动作 = 发版）。**这条红不是缺陷，是发版待办的显式挂账**；优于裁 `internal` 造成的静默失明。`signature-baseline.json` **零改动**，未执行 `--emit-baseline`。

**亲验出的结构盲区（须归 CONTRACTGATE，不另立单）**

> 任何「新纳入 `stability=stable`」的单元，**在发版重建基线之前都不在签名检测面内**；而门禁只以一行「不在基线内」提示这件事。无人逐行读那行 stderr 时，**登记 = 宣示检测已覆盖，实际未覆盖** —— 正是本单要消灭的盲区以更隐蔽的形式回归。
> 现存 18 单元与基线 18 条**恰好一一对应** ⇒ 盲区**潜伏未爆**，本单是第一次触发。
> 修法方向：把「纳入 stable」与「进入比对面」**解耦**，不再靠发版这个外部事件顺带完成（候选：契约上加可机读登记态字段 + 门禁分通道，让破坏性通道只装真破坏）。

**零 `.pas` 亲核**：`git diff --stat 41b580a -- '*.pas' '*.dpr' '*.dproj' '*.dpk'` = **空**。

---

## 三、本轮共性发现（三条同族病灶的第四层）

主控 2026-10-02 清点出的三条同族病灶是「**把写下来当成交出去**」（单子在账外 / 连单子都没有 / 派了无推进机制）。本轮四单办结后，暴露出**第四层：把「跑出来的读数」当成「测过的面」**：

1. **CI 全线零 step 执行**（MC3 项 2）：台账记「集成跑录没跑」，实为整条流水线零信号。连「零信号」都被表述成了「局部缺失」。
2. **`contract-gate` 既存红 3 天无人披露**（台账 §三 已记）：根因是「四门」这个词从未枚举，乙 B7 的提交说明自证「四门不含 contract-gate」于是没人看见。**口径未枚举 = 门禁缺口**。
3. **F2 的「竞态」定性**（TESTDEBT-R01）：前置单凭症状（AV @ nil）推定了病因（并发竞态），四天后本轮用四步代码链证明是确定性空指针。**症状推病因是过宣称的一种，本轮把它降级成了读数。**
4. **`DELPHI_VERSION 23.0` vs 实际 37.0**：这是第三条的实体 —— 就算 runner 接通，yml 也跑不出结果。**「接上机器」不等于「能跑」**。

⇒ 建议主控把「**凡四门 / 全量 / CI 类读数，工单与回执必须显式枚举门名与环境，并标注「零信号」与「局部红」的区别**」立为一条登记纪律。本批四份交付件已按此口径书写。

---

## 四、四门（逐道门名 + EXIT）

门名口径依 `WO-20261001-MC-A16` 验收结论 §八 的订正：**四门 = eol / encoding / mojibake / evidence-encoding，**不含 contract-gate**。

原始件：`CodeReview/20261002-请求审核报告-开发甲-MC-TESTDEBT-MOE-GOVCONTRACT-MC3-证据/四门-跑录.txt`

| 门禁 | 入口 | EXIT | 结论行 |
|---|---|---|---|
| **行尾门禁** | `09_工程脚本/eol-gate/check_eol.js` | **0** | 行尾门禁通过：检查了 **1662** 个文件（.pas CRLF / .md LF），跳过目录 11 |
| **编码门禁** | `09_工程脚本/encoding-gate/check_pas_encoding.js` | **0** | 编码门禁通过：**1017** 个 .pas + **798** 个扩展面文件（基线残留U+FFFD文件 18，BOM例外 45，孤立CR基线文件 0，双重编码基线文件 50，扩展面存量损坏豁免 13，跳过目录 11） |
| **丙类损坏门禁** | `09_工程脚本/mojibake-gate/check_mojibake.js` | **0** | 丙类损坏门禁通过：扫描 **1015** 个 .pas，丙-B 命中 **0** 处（0 件），全部在存量清单 17 件 / 343 处封顶内（只减不增） |
| **证据编码门禁** | `09_工程脚本/evidence-encoding-gate/check_evidence_encoding.js` | **0** | 证据编码门禁通过：扫描 **1234** 个 CodeReview 证据文件，NUL 违规 **0**，全部为合法 UTF-8；E3 命中 **240** 行，均在存量清单 21 件的封顶内 |

**单列（不在四门口径内）**：消费者契约门禁 `09_工程脚本/contract-gate/check_contract.js` → **EXIT=1**，3 项红，逐条归因见 §2.7。

**本轮这道门真的咬到人了（必须留档）**：四门复跑时 evidence-encoding 门禁 **EXIT=1**，报 E1 证据含 NUL 字节 4 项，全部指向本轮新入库的 `CodeReview/20261002-AUDIT-主控-A5A8-证据/*.log`（NUL=44/274/1014/1014，首偏移均 =3）。成因是复跑驱动脚本用 PowerShell 的 `*>` 重定向写盘，**PS 5.1 对本机输出的重定向默认落 UTF-16LE** ⇒ 文件带 `FF FE` BOM 且正文含 NUL。已按 UTF-16LE 读出、UTF-8（无 BOM）写回（`c6be63f`），复跑 **EXIT=0**。
**若不做四门复跑，这 4 件验收证据会以 UTF-16 落库**，下游任何按 UTF-8 读该证据的脚本都会拿到乱码或直接失败，而提交时的 EXIT 码看不出任何问题。

**读数增量归因**（依 `09_工程脚本/README-门禁覆盖面.md` §二：四门为工作树口径，只看目录名 SKIP 集）：`.pas` 计数 **1017 未变** ⇒ 本轮零 `.pas` 改动，与各回执自述一致；增量全部来自本轮新增入库的交付件与证据件（`CodeReview/**` 41 件入库、`docs/**` 9 件、`contract` 1 件、`.gitignore` 1 件）。

---

## 五、提交清单（8 笔 H15，逐单一笔 + 1 笔门禁缺陷修正）

| # | 提交 | 主题 | 文件数 |
|---|---|---|---|
| 1 | `47d4fd1` | `docs(TESTDEBT-R01)` 双红灯清点 —— F1 判为环境伪影 / F2 根因是 TTask 观察机制与 TManagedWorker 脱节 | 7 |
| 2 | `5ce7d52` | `docs(MOE)` 讨论包 41 条三态标注 + 工单族 6 项 + 5 个决策点全部上交 | 6 |
| 3 | `ef19eb7` | `fix(contract)` `DeepBase.DataBinding` 显式登记消费者契约（stable + critical），不建签名基线 | 4 |
| 4 | `375ec8f` | `docs(A5A8)` 零信任验收 A5 8/8 + A8 1/1 —— 两棵隔离树 12 探针亲跑 | 7 |
| 5 | `d4e7b13` | `docs(MC3-2)` CI 取证升级 —— 零 step 执行而非「集成没跑」；三选一方案书 + 决策点 | 1 |
| 6 | `b59cd0e` | `docs(MC3-3)` DB4 三件函件草稿成稿（问题清单化 + 兜底明示）—— 一封未发 | 4 |
| 7 | `9d20d2d` | `chore(C0-02)` 工作树卫生 60 → 20 —— 27 入账 / 10 入 .gitignore / 3 件 0 字节垃圾删除 | 33 |
| 8 | `c6be63f` | `fix(A5A8)` 4 件验收证据 `.log` 由 UTF-16LE 重落 UTF-8（evidence-encoding E1 命中） | 4 |

**并集亲核**：`git diff --stat 41b580a c6be63f -- '*.pas' '*.dpr' '*.dpk' '*.dproj' '*.dfm' '*.fmx'` → **空**（零生产代码）。
**未 push**（`git log origin/master..HEAD` 未执行；本批 8 笔全部在本地 master 领先）。

---

## 六、需要主控/老板处理的事项（本单无权自决）

| # | 事项 | 所属 | 期望处置 |
|---|---|---|---|
| 1 | **TESTDEBT 前置单补台账行**：`WO-20260928-TESTDEBT-甲-001` 至今仍零登记 | 主控 | 台账 §二补一行「已被 TESTDEBT-R01 重锚承接」；措辞见 TESTDEBT 回执 §六 |
| 2 | **F2 根因修复**（建议采案 a：用例改 `TThread.CurrentThread.CheckTerminated` + 订正前提注释，零生产改动） | 前置单 T2 | 派单执行；同时**订正 T2 的「并发竞态」定性** |
| 3 | **HB Gate6 长期环境口径**（无头/交互双环境对照、预热取样/中位数） | 前置单 T1/T3 | 本轮三次均在交互会话，**无头对照未取**（需另起无头环境），如实登记 |
| 4 | **主树陈旧 DCU 清理**：45316 `.dcu` + 67 `.dcp` 致主树编译必红 ⇒ **任何「主树跑录」类判据在清理前不可取得** | 主控 | **建议派单**（MC2 只收口了门禁口径，未清产物） |
| 5 | **contract-gate 通用结构盲区**：新纳入 stable 的单元在发版重建基线前不在比对面内 | CONTRACTGATE | 与抽取器一并处置（**不另立单**，避免同一文件被两笔并改） |
| 6 | **CI 决策点 DP-MC3-2**：三选一（接通 runner / 改托管 runner / 正式 DEFERRED + 双处明示从未执行） | **老板** | 拍板前不动 `.github/workflows/**`；方案书 §三 已备好拍板后四步最小动作集 |
| 7 | **`DELPHI_PATH` 23.0 vs 实际 37.0** | 主控 | 无论选 (a) 还是 (b) 都必须先修，否则接通即红 |
| 8 | **DB4 三封函件发送批准** | **老板** | 未呈报不得发送；草稿日期与渠道字段留空待填 |
| 9 | **COS 桶在谁名下**（唯一不可逆的一步） | **老板** | 三选项 × 六维代价对照见 ③；逾期不答的默认是「不配」，功能零风险 |
| 10 | **MoE 决策点 DP-1…DP-5** | **老板** | 见 `docs/ui/work-orders/WO-20261002-MC-甲-MOE-DP-决策点包.md` |
| 11 | **MoE 首批派单批准**（MOE-01 + MOE-05） | 主控 | 两张取证单零禁动区触碰，可即刻开工 |
| 12 | **BUG007 4 例既存红立单**（`Test.Regression.BUG007_WhenReadyDeadlock`） | 主控 | 排在 A5 结项后、A12 前 |
| 13 | **`docs/**` 20 件归位裁定**（D1/D4 建议入账；D2/D3 建议归档或删除；D5 待 HB 线确认） | 主控 | 见 MC3 项 4 结论件 §四 |
| 14 | **`.workbuddy/memory/` 已跟踪 5 件的处置**（`git rm --cached` 或维持） | 主控 | 索引删除不可逆，超出本单授权面 |
| 15 | **仓内 18 棵 worktree 锚点收口** | 主控 | 逐棵确认后 `worktree remove --force` + `prune`；A13 §十 已记这批树曾被外部清理 |
| 16 | **TimeGuard 非 Windows `raise` 分支的 Linux 复证** | 主控 | 另立「Linux 执行环境」前置，**不并入** CI runner 决策 |

---

## 七、结束时间

```
2026-10-02 01:46:56
```

（本报告与四门跑录件的最后一次写入时间。批次自 2026-10-02 派单起，全程未停等、未中途挂起。）

---

*开发 AI 甲 · 2026-10-02 · 本批零生产代码；台账状态槽未改（逐单给出建议措辞交主控回填）；未 push；甲方自报不作为验收依据*