# WO-20261002-MC-甲-TESTDEBT-R01 交付回执 —— 全量套件双红灯现状清点与账外单重锚

> 执行：开发 AI 甲 · 2026-10-02
> 工单：docs/ui/work-orders/WO-20261002-MC-甲-TESTDEBT-R01-全量套件双红灯现状清点与重锚.md
> 前置单：WO-20260928-TESTDEBT-甲-001（2026-09-28 签发，P1，法源 HACI-MVP F-NB-03，基线 59a1a24）
> 开工 HEAD：`41b580a`；隔离树：`D:/_ProgData/DeepBase-TDR01/wt-41b580a`（`git worktree add --detach @41b580a`）
> **本单只清点与重锚，不修任何测试债务**。前置单 T1/T2/T3 任务未撤销，**双红灯未闭环**。
> 结论一句话：**F1 现状为绿且归因为「环境伪影」（非修复、非断言弱化）；F2 仍红，根因为「用例的 TTask 取消观察机制与生产执行载体 TManagedWorker 脱节」的确定性空指针，不是竞态。前置单 T2 的竞态假说不成立。**

---

## 一、账外单事实确认（判据：现象复述 + 本单新增的记账缺口）

| 事实 | 取证 |
|---|---|
| `WO-20260928-TESTDEBT-甲-001` 在台账四处零登记 | `docs/ui/work-orders/00-主控派单总表.md` §一乙线（12 项）、§二甲线、§三主控线、§四在途全景全文检索该单号 = 0 命中（2026-10-02 开工时） |
| 该单法源与状态 | 工单原文 §法源「HACI-MVP 独立审计报告 F-NB-03」、§当前状态 `READY FOR DEV`、§优先级 P1 |
| 该单基线已过期 | 基线 `59a1a24`（2026-09-28）→ 本单重锚至 `41b580a`，区间 **96 笔提交 / 435 文件 / +34866 / −222** |

**本单新增的记账缺口登记（不是本单造成的，但必须记）**：本单工单（`WO-20261002-MC-甲-TESTDEBT-R01`）在台账 §二甲线已有行（2026-10-02 派单时补登，状态「🔵 可开工」）——**即台账这一处已经补上，前置单仍无行**。建议主控在台账 §二为前置单补一行「已被 TESTDEBT-R01 重锚承接」，措辞见 §六。

---

## 二、F1 清点（HB Gate #6 万实例句柄基准）

### 2.1 现状读数：隔离树 @ `41b580a` 三次连跑（判据 1）

命令（三次相同，run2/run3 加 `-SkipCompile` 复用同一 exe）：

```
powershell -NoProfile -ExecutionPolicy Bypass -File <隔离树>\Scripts\run_tests.ps1 `
  -Type Unit -Run "Test.DeepBase.HB.Benchmark"
```

| 轮次 | Gate#6 round1 | Gate#6 round2 | Tests Found/Passed/Failed/Errored | RUNNER_EXIT |
|---|---|---|---|---|
| run1（含编译） | `GDI 42->42 USER 37->36 Heap 0->0` | `GDI 42->42 USER 36->36 Heap 0->0` | 7 / 7 / 0 / 0 | **0** |
| run2（-SkipCompile） | `GDI 42->42 USER 37->36 Heap 0->0` | `GDI 42->42 USER 36->36 Heap 0->0` | 7 / 7 / 0 / 0 | **0** |
| run3（-SkipCompile） | `GDI 42->42 USER 37->36 Heap 0->0` | `GDI 42->42 USER 36->36 Heap 0->0` | 7 / 7 / 0 / 0 | **0** |

原始输出存档：`CodeReview/20261002-AUDIT-甲-TESTDEBT-R01-证据/F1-隔离树-run{1,2,3}-原始输出.txt`。
编译读数：`404467 lines, 25.69 seconds`，`SUCCESS: Unit Tests compiled`。

### 2.2 主树口径：未取，理由如实登记（判据 1 的诚实收窄）

判据 1 原文要求「主树与隔离树双跑一致」。**本单主树未跑**，原因不是偷懒而是可复现的机制性阻断：

- 台账 §三已登记（A13 验收 §五发现）：**主工作树跑编译门必红 19/25**，红源是 `Core/DeepBase.Security.DPAPI.pas:554` E2251（`SecureZeroMemory` 两个同名重载），机制为**主树 45316 个 `.dcu` + 67 个 `.dcp` 提交前陈旧产物污染**，`check_build.js:619` 的搜索顺序把 `TestResults\dcu32/dcu64`（dproj config 联合声明）排在 `Core` 之前。
- `WO-20261001-MC-MC2` 已办（`130e5f8`）把门禁口径收口到隔离树，但**陈旧 DCU 仍在主树**，主树编译面未因此转绿。

⇒ **主树跑录在陈旧 DCU 清理前不可取得，这是既存环境债不是本单能顺手清的**（`TestResults/**` 与 `.tmp/**` 属他域/禁动面）。本单按 MC2 确立的「门禁与测试结论一律走隔离工作树」口径交付，并把「主树跑录取得条件」登记给主控（§六 建议措辞）。

### 2.3 转绿归因：三选一 → **环境伪影**（判据 2）

排除法，三条独立取证：

| 候选 | 判定 | 取证 |
|---|---|---|
| **修复** | **排除** | 窗口 `59a1a24..41b580a` 内，`Tests/Test.DeepBase.HB.Benchmark.pas` **零改动**（`git diff --stat` 空，`git log --oneline 59a1a24..HEAD -- <该文件>` 空）；HB 生产面（`VCL/` + `FMX/` + `Core/DeepBase.HB*`）**全域零改动**（同上 diff 空）。窗口内 `Core/` 只动 10 件、`Features/` 只动 8 件，与 HB 基准判读面无交集（差异表见 `重锚-59a1a24..41b580a-差异表.txt`）。**没有代码变过 ⇒ 不可能是「代码修好了」** |
| **断言被弱化** | **排除（红线项专项核查）** | 同上：该基准文件自 `4d818af`（2026-09-21）起未再改动，且 `git merge-base --is-ancestor 4d818af 59a1a24` = 0 ⇒ **审计方 2026-09-28 跑的那份断言与今天的逐字相同**。断言本体 `:728/731/734` 为 `GdiAfter <= GdiBefore` / `UserAfter <= UserBefore` / `HeapAfter <= HeapBefore`，**硬阈值 delta ≤ 0 未动分毫**；commit/阈值/跳过/`Category` 四种粉饰手法均无空间 |
| **环境伪影** | **成立** | 由上两条排除后仅剩此项。且机制可指认：`GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS/GR_USEROBJECTS)`（`:676-677`）取的是**进程级全局计数**，不是本控件的私有计数；断言要求 delta ≤ **0**（只许持平或下降）。在审计方的**全量进程**里（`Found 4679 / Ignored 4`，同进程跑 300+ 夹具，含 UI、线程、浏览器自动化夹具），任一其他夹具在两次取样之间新建 USER 对象即产生 `+1` 的**伪增量**；在**单夹具隔离进程**里该噪声源不存在。三次隔离跑全部为 `USER 37->36 / 36->36`（round1 甚至下降 1），与审计方 `before=34 after=35 delta=1` 的形态完全一致于噪声解释 |

**机制坐实的补强证据**：三次隔离跑的 Gate#6 读数**逐字相同**（`42->42 / 37->36 / 36->36`），方差为 0；这说明该基准在**单一测量源**下是稳定的，红灯不是「今天碰巧好」，而是「进程里有多少个别的 USER 对象创建者」这件事在变。

### 2.4 残留风险登记（交给前置单 T1/T3，不在本单处置）

1. **该基准在本仓仍是 process-global 计数器 + 硬阈值 delta ≤ 0 的组合**，只要跑在多夹具同进程里就具备复红能力。前置单 T1 提的「预热取样 / 多次中位数 / 显式环境前提断言」三案本单不预判。
2. 前置单 T3 要求「无头/交互双环境对照数据」：本单三次均在**交互会话**下跑（`GetGuiResources` 返回有效值即证明有 USER 对象计数面），无头会话对照未取（需另起无头环境，超出本单环境面）。**如实登记为未取，不假装已取。**

---

## 三、F2 清点（Timeout PBT `Property6_TimeoutCancelsBackgroundTask` AV @ nil）

### 3.1 复现（判据 3）：成立，仍红

隔离树 @ `41b580a` 单跑 `Test.DeepBase.Resilience.Timeout.PBT`：

```
Tests Found   : 2
Tests Ignored : 0
Tests Passed  : 1
Tests Leaked  : 0
Tests Failed  : 0
Tests Errored : 1
  Message: Access violation at address 00007FF681EBCC5A in module 'DeepBaseTests.exe'
           (offset 233CC5A). Read of address 0000000000000000
RUNNER_EXIT=1
```

原始输出：`F2-隔离树-TimeoutPBT-原始输出.txt`。与审计方 2026-09-28 读数（`00007FF79B1F7A1A` / offset `2217A1A` / `Read of address 0000000000000000`）**签名逐项相同**，地址与偏移不同仅因二进制不同。`Property5_ResultIsConsistent` 通过、`Property6` 报错 ⇒ 与审计方「Errored 1」一致。**无需环境差异解释**：不是「不再复现」，是稳定复现。

### 3.2 诊断结论（判据 4）：**竞态假说不成立**，根因代码级定位

代码级取证全文：`CodeReview/20261002-AUDIT-甲-TESTDEBT-R01-证据/根因-F2-代码级定位.txt`。四步链：

1. **用例侧假设**：`Tests/Test.DeepBase.Resilience.Timeout.PBT.pas:33-41` 单元头明写前提「`TTimeoutPolicy` is purely Delphi RTL: **TTask + ITask.Cancel + ITask.Wait**」；`:240` 工作体内调 `TTask.CurrentTask.CheckCanceled`，`:244-245` 捕 `EOperationCancelled` 计入 `LObservedCancel`。
2. **生产侧实际载体**：`Core/DeepBase.Resilience.Timeout.pas:98-112` 用 `TManagedWorker.Create(匿名 proc)` 起工作体，超时走 `Worker.Evacuate`（`:118`）后 `raise ETimeoutException`（`:121`）。
3. **`TManagedWorker` 的线程类型**：`Core/DeepBase.ManagedWorker.pas:37` —— `TCoreThread = class(TThread)`，**不是 `TTask`**；`:264-272` 构造 `inherited Create(True)` + `FreeOnTerminate := False`；`:224-228` `Cancel` = `FCancelEvent.SetEvent` + `FThread.Terminate`。
4. **推断**：`TTask.CurrentTask` 读线程局部 `TTask.CurrentThreadTask`，只有 `TTask` 自己的工作线程才置位该 TLS；**纯 `TThread` 线程上恒为 nil** ⇒ `:240` 的 `TTask.CurrentTask.CheckCanceled` 就是 `nil.CheckCanceled` ⇒ **Read of address 0**，与观测签名逐字吻合。

**「不是竞态」的时序反证**：用例循环体 `:237-241` 是 `Sleep(10)` 后立刻 `CheckCanceled`；**第 1 次迭代即在 t≈10 ms 命中 nil 解引用**，而超时预算是 `CTimeoutMs = 50`（`:215`）。**AV 时刻早于 Cancel 发出时刻 40 ms** ⇒ 竞态假说要求的「Cancel 与回调竞争」的时间窗在本例中根本不存在。

**时序面零变更（排除「区间内引入的回归」）**：三件（用例 / `Resilience.Timeout.pas` / `ManagedWorker.pas`）在 `59a1a24..41b580a` 窗口内**零改动**，最后改动均为 **2026-09-19**（`649b1e0` / `ed50cfd`），**早于**审计基线 ⇒ `TManagedWorker` 重构发生在审计之前，本缺陷自 2026-09-19 起既存，**不是这 4 天任何一笔提交引入的**。

**结论**：F2 是**测试断言机制随生产重构失效**（用例仍按 TTask 语义观察取消），**不是产品竞态缺陷**，也不是产品缺陷本身。故：前置单 T2 写的「属并发竞态疑似真缺陷」这一定性**应订正**。

### 3.3 修复方案（前置单执行面，本单只出方案，见判据「本单只出诊断结论 + 修复方案，不要求修完」）

| 案 | 修法 | 生产代码改动 | 评价 |
|---|---|---|---|
| **(a) 采纳** | 用例 `:240` 改 `TThread.CurrentThread.CheckTerminated`，`:244-245` 改捕 `EThreadTerminated`，`:275-278` 的断言随观测口径同步 | **零** | 与 `ManagedWorker.pas:13-14` 自述的协作取消纪律**同语言**（注释原文：「工作体用 `CancelEvent.WaitFor(ms)` 替代 `Sleep` 即可协作退出（`TThread.CheckTerminated` 亦可）」）。改动面 = 一个测试单元，且把用例的**前提注释 `:33-41` 一并订正为 `TManagedWorker`**（否则下一个维护者会再踩同一个坑） |
| (b) | `TTimeoutPolicy.Execute` 给工作体注入 `TEvent`/`ITask` 句柄，让用例按 TTask 语义观察 | 需扩 `TTimeoutPolicy` 公开面 | **不采纳**：为迁就一个已过时的用例而扩生产 API，方向反了；且 A16 刚因收窄 `Bind` 契约登记过 breaking change，不宜同一窗口再给 `TTimeoutPolicy` 开口子 |
| (c) | 删/跳 Property6 | — | **红线禁止**（前置单 §四-1）。且会让「超时后后台任务是否真被取消」这条安全属性彻底失守 |

⇒ 建议前置单采 (a)，并按 §3.2 订正 T2 的定性（竞态 → 断言机制失效）。

---

## 四、重锚记录（判据 6）：`59a1a24` → `41b580a` 逐条

窗口规模：**96 笔提交 / 435 文件 / +34866 / −222**。改动面分布：

| 目录 | 文件数 | 对两灯判读的影响 |
|---|---|---|
| `CodeReview/` | 342 | 证据与回执文档，**零编译/运行影响** |
| `docs/` | 32 | 同上 |
| `Tests/` | 30 | **逐件核对过**：无一件触及 `Test.DeepBase.HB.Benchmark.pas` 或 `Test.DeepBase.Resilience.Timeout.PBT.pas`（两文件在窗口内 `git log` 皆空）⇒ 对 F1/F2 判读零影响 |
| `Core/` | 10 | 逐件核对：`DataBinding.pas`（A16 源侧析构登记）/ `Exceptions.pas` / `Serialization.pas` / `IoC.pas` / `LogQuery.pas` / `Export.PDF.pas` / `Export.DOCX.pas` / `Manager.pas` / `License.pas` / `KeyManager.pas`（A5）—— **无一件在 HB 基准判读面或 Timeout/ManagedWorker 判读面** ⇒ 零影响 |
| `Features/` | 8 | `Licensing.pas` / `Commerce.SafeClient.pas` / `TimeGuard.pas` / `Speech.ASR.SenseVoice.pas` 等 ⇒ 零影响 |
| `09_工程脚本/` | 4 | 门禁脚本，不参与测试运行 |
| `Scripts/` | 2 | `run_tests.ps1`（MC1 项 1 修搜索面 + 加 `-NS`）/ `check_doc_links.ps1`（MC1 项 2 修崩溃）—— **这两笔是「让本单能跑起来」的前置**：修前 runner 会 F2613 中断在 `Governance`/`doQry`/`ADODB` 三层 ⇒ 本单的隔离树跑录依赖它们 |
| `ThirdParty/` | 2 | 支付适配器（B13）⇒ 零影响 |
| `.github/` | 1 | `delphi-ci.yml`（tzutil 固定时区，MC1 项 3）⇒ 零影响（CI 未接通，见 `WO-20261002-MC-MC3` 项 2） |
| `CHANGELOG.md` / `*.dpk` / `DeepFlow` | 5 | A16 的 CHANGELOG 登记 + `DeepBaseServices.dpk`（TimeSource）+ `DeepBaseCommerce.dpk`（A11 适配单元）⇒ 零影响 |

**逐条影响结论**：窗口内 435 个文件的改动，**对 F1、F2 两灯的判读影响为零**。这不是结论的补丁，而是两灯各自的「最后改动提交」都比窗口起点早（2026-09-19 / 2026-09-21）这一事实的直接后果。

---

## 五、红线自查（判据 5）

`git diff --cached --name-only` 亲核（详见 §七 提交清单）：

- **未删任何测试**、**未跳任何测试**（无 `Exclude`/`Ignore`/`Category` 改动）、**未降任何断言**（F1 断言 `:728/731/734` 逐字未动，见 §2.3）。
- **未改任何 `.pas`**：本单改动面为 0 个生产文件、0 个测试文件（`Tests/**` 在授权面内但本单零改动，因为清点单不修债）。
- **未超 2000 行不拆**：本单零代码。
- 本单 `Tests/**` 授权面**主动零使用**，如实登记。

---

## 六、给主控的台账建议措辞（甲不得自行改台账，见判据 6 / 工单 §三-4）

1. **台账 §二甲线**：把 `TESTDEBT-R01` 行状态由「🔵 可开工」改为 **「🟡 清点已交付，诊断结论见回执；两灯均未闭环」**，并在其后补一行前置单登记：
   > `TESTDEBT-001`（原单 `WO-20260928-TESTDEBT-甲-001`，2026-09-28 签发，P1）｜ **账外 4 天已重锚** ｜ 承接单 `WO-20261002-MC-甲-TESTDEBT-R01` ｜ 现状：**F1 绿（环境伪影，非修复非弱化）、F2 红（用例 TTask 观察机制与 TManagedWorker 脱节，非竞态）** ｜ 剩余执行面回前置单 T1/T2(方案 a)/T3
2. **台账 §三主控线新增一条既存债**：
   > `主树跑录不可取得`｜根因：A13 §五 发现的**主树陈旧 DCU 污染**（45316 `.dcu` + 67 `.dcp`），`check_build.js:619` 搜索顺序把 `TestResults\dcu32/dcu64` 排在 `Core` 前 ⇒ 主树编译必红 E2251 ｜ 后果：**任何「主树跑录」类判据在清理前不可取得**（MC2 只收口了门禁口径，未清产物）｜ 建议派单：清理陈旧 DCU + 将主树编译面纳入 T0 常态判定
3. **台账 §四在途全景**：F2 仍为「全量唯一 Errored」，定性由「P2-b Timeout PBT AV（并发竞态疑似）」**订正为**「P2-b Timeout PBT AV（用例断言机制随 TManagedWorker 重构失效，确定性非竞态）」。

---

## 七、四门（判据 7：逐道写门名 + EXIT）

见本轮统一四门跑录：`CodeReview/20261002-请求审核报告-开发甲-MC-TESTDEBT-MOE-GOVCONTRACT-MC3-证据/四门-跑录.txt`。逐道结论行与 EXIT 见该件与最终请求审核报告 §五。门名口径按 A16 验收 §八 的订正执行：**「四门」= eol / encoding / mojibake / evidence-encoding 四道静态门禁**，**不含 contract-gate**（contract-gate 自 2026-09-29 起一直红而无一笔披露，单列于 GOVCONTRACT 件）。

---

## 八、纪律（判据 8）

- **H15 原子提交**：本单**单笔**，显式 pathspec，**未 push**（见 §九 提交清单）。
- 隔离树 `D:/_ProgData/DeepBase-TDR01/wt-41b580a` 为取证用，产物全在仓外 `D:/_ProgData/DeepBase-TDR01/`，不入库。
- 台账状态槽**未改**（甲无权）。

---

## 九、提交清单

| # | 路径 | 性质 |
|---|---|---|
| 1 | `CodeReview/20261002-AUDIT-甲-TESTDEBT-R01-交付回执.md` | 本回执 |
| 2 | `CodeReview/20261002-AUDIT-甲-TESTDEBT-R01-证据/`（6 件） | 原始输出 + 重锚差异表 + 根因定位 |

`git diff --cached --name-only` 与上表逐件相等（主树 `Tests/**`、`Core/**`、`Scripts/**`、`09_工程脚本/**` 零改动）。

---

## 十、不在本单（已登记，不重复认领）

- **F2 的根因修复与回归断言**：归前置单 T2，建议采 §3.3 的案 (a)（本单**未修**）。
- **HB Gate6 的长期环境口径**（无头/交互双环境对照、预热取样/中位数）：归前置单 T1/T3。
- **主树陈旧 DCU 清理**：本单新登记，建议另派（§六-2）。
- **`contracts/**` 治理**：另单 `WO-20261002-MC-主控-GOVCONTRACT`（已同日办结）。
- 甲线 🔵 可开工的 A14 / A15、⚪ 排队的 A1 / A12 / A3(S2) / D11：调度不在本单范围。

---

## 十一、判据逐条读数（fail-closed）

| # | 判据 | 读数 | 结论 |
|---|---|---|---|
| 1 | F1 现状读数，主树与隔离树双跑一致 | 隔离树 @41b580a 三次跑全绿 7/7/0/0 RUN_EXIT=0，Gate#6 读数逐字相同；**主树未跑**（陈旧 DCU 阻断，已如实登记并给出取得条件） | **部分成立（诚实收窄）**：隔离树侧完整达成，主树侧因既存环境债不可取得，理由与机制已坐实，未以推测顶替读数 |
| 2 | F1 转绿归因三选一有证据，禁「未归因即记已修」 | 三选一 → **环境伪影**；排除「修复」靠窗口内基准文件与 HB 生产面零 diff；排除「断言弱化」靠基准文件自 `4d818af` 起未改 + `is-ancestor 4d818af 59a1a24`=0 + 断言硬阈值 delta≤0 逐字未动 | **成立** |
| 3 | F2 复现 | 隔离树 @41b580a 单跑仍 AV，Errored 1，RUN_EXIT=1，与审计方签名逐项相同 | **成立** |
| 4 | F2 诊断结论，竞态假说成立与否有调用栈/线程时序证据 | 竞态假说**不成立**；根因为 `TTask.CurrentTask` 在 `TManagedWorker` 的纯 `TThread` 上恒 nil 的确定性空指针；时序反证：AV@t≈10 ms < 预算 50 ms ⇒ Cancel 尚未发出 | **成立** |
| 5 | 红线自查（`git diff --cached` 亲核） | 零 `.pas`、零测试改动、零断言改动、零删跳 | **成立** |
| 6 | 重锚记录，三处提交差异逐条说明对两灯判读的影响 | 435 文件按 14 个目录逐条列表 + 两灯涉及面逐件 diff（4 件全空 + VCL/FMX 全域空）⇒ 影响为零 | **成立** |
| 7 | 四门逐道写门名 + EXIT | 见 §七 与统一四门跑录件 | **成立** |
| 8 | 纪律：单笔 H15、显式 pathspec、未 push | 单笔；pathspec 见 §九；未 push | **成立** |

---

*开发 AI 甲 · 2026-10-02 · 本单为清点单，零生产代码，双红灯未闭环；甲自报不作为验收依据*