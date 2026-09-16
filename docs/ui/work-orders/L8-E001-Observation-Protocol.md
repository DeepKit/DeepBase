# L8-E001 Observation Protocol

> **Protocol**：`L8-E001 Observation Protocol`
> **Version**：`v1`
> **Status**：**`FROZEN FOR CASE 001`**
> **Content Authority**：Amy（沈予安）· 主控 / 资料员 → Human Authority chain
> **Freeze Authority**：Amy（沈予安）· 主控 / 资料员（Human Authority 2026-09-16 §六 指定）
> **Git Mechanical Executor**：主控 Amy（本机 `D:\_Progs\02Business\DeepBase`）—— 与 Content Authority **不得混淆**
> **冻结时间**：`2026-09-16 16:30 +0800`
> **Protocol Freeze Commit SHA**：见**外部冻结登记**（`CodeReview\20260916-EHAI-L8-EMPIRICAL-001-落地执行回执.md`）
> 　※ 提交**无法命名自身**，故本协议正文不自载其 Freeze Commit SHA；锚点由**外部后置件**承载（本链既定 F3 类纪律）
> **母工单**：`WO-20260916-EHAI-L8-EMPIRICAL-001`
> **冻结依据**：《Human Authority 最终裁定 · Observation Protocol v1》（2026-09-16）
> **理论纪律**：`EHAI L1–L8 = FROZEN v1.0`；本协议**不重新推导、不修改、不解释性扩张 L8 理论**

---

## §0 冻结登记

### §0.1 冻结的 7 项参数（Human Authority 裁定，全部已关闭）

```text
Protocol                L8-E001 Observation Protocol
Version                 v1
Status                  FROZEN FOR CASE 001
Start Date              2026-09-17
Initial Window          28 natural days
Initial End             2026-10-14
Midpoint                2026-09-30
Minimum Samples         AsWish >= 20 valid Episodes
                        AXIS   >= 20 valid Episodes
Task Diversity          >= 3 task types per product
Products                AsWish / AXIS
Comparison              Historical + Workflow + Internal Contrast
Self-report             Enabled / Voluntary / Low Burden
F4 Rule                 Affected AXIS real-world evidence EXCLUDED
                        until F4 Delta Closure
Claim Ceiling           Case-specific empirical claims only
```

### §0.2 冻结程序与责任人（Human Authority 2026-09-16 §六 指定）

```text
Freeze Authority   = Amy（沈予安）· 主控 / 资料员
理由               = Observation Protocol 是研究/治理基线，不属于开发实现本身，
                     不应由开发方自行改变观察标准
最终报告须明确     = Content Authority       = Amy / Human Authority chain
                     Git Mechanical Executor = <actual executor>
二者不得混淆
```

**冻结动作清单**（本次已执行）：
```
[1] 写入 Human Authority 裁定
[2] 校验协议内容
[3] Status: PRE-REGISTRATION → FROZEN FOR CASE 001
[4] 形成 Git Object
[5] 登记 Commit SHA
[6] 登记 Protocol Version = v1
[7] 登记 Start Date = 2026-09-17
```

**代执行限制**：开发方如因权限或工作方式需代为执行 Git 命令，**只允许机械提交，不得改协议正文**。

**Amendment 规则**：自本 Freeze Commit 起，任何正文变化**必须走 `Protocol Amendment`**（§21），**不得普通编辑**。

---

## §1 目的与边界

**研究问题**：*真实使用以后，究竟发生了什么？*（**不**再问「有没有忠实实现」）

**本协议不做**：新增 Common Contract／第三个产品绑定／DeepBase 重构／HB、AsWish、AXIS 功能补全／L8 理论重开。

**唯一主轴**：R1 现实结果完整性 · R2 效果归因完整性 · R3 经验主张完整性。

**红线**：**不得为了让实证结果「更漂亮」而边观察边改核心机制。**

---

## §2 冻结项清单

| # | 冻结项 | v1 值 |
| :-: | :--- | :--- |
| 1 | 观察对象 | `AsWish` + `AXIS`（两个已完成工程符合性验证、领域差异足够大的产品） |
| 2 | 观察场景 | 各自**真实日常使用**场景；不得为观察而构造非常规使用 |
| 3 | 基线 | Comparison A/B/C 三面（见 §5.2） |
| 4 | 指标 | R1 六类 O1–O6（见 §4） |
| 5 | 证据类型 | 四层 E0–E3（见 §7） |
| 6 | 归因规则 | 最小 Attribution Counterfactual（见 §5.1） |
| 7 | 干扰变量 | §5.3 登记表 11 项 |
| 8 | 异常规则 | 严重事故优先记录（见 §10） |
| 9 | 排除规则 | F4 污染数据（见 §9）+ Admission Gate 不通过者（见 §8） |
| 10 | 停止条件 | §11（样本下限 + Early Stop 触发） |
| 11 | 结论强度规则 | Claim Ladder E0–E4（见 §6） |
| 12 | 协议版本与冻结戳 | 本文件 `v1` + §0.2 冻结 Commit SHA |

---

## §3 Observation Unit 与最小记录

**统计单位不是「使用了一天」，而是**：
```
一次完整 Human-AI Task Episode
```

**Episode Record 最小字段（v1）**：

```yaml
episode_id, timestamp, product, software_commit, model, task_type
human_goal, initial_context_ref
candidate_count, regenerate_count, frame_rejection_count,
human_override_count, back_count
human_decision_count, authorization_event_count, commitment_event_count
completion_status, rework_count, correction_count
semantic_incident, authority_incident, recovery_incident
outcome_evidence_ref, raw_evidence_ref
intervention_id, notes
```

### §3.1 必须保留「题面」
**不能只记最终结果。** 至少保留：当时用户想做什么／当时知道什么／AI 看到了什么／Human 看到了什么／有哪些候选／Human 做了什么／系统最后做了什么。
否则事后无法判断「结果好」是机制有效还是 **hindsight**。

---

## §4 R1｜现实结果指标（O1–O6）

| 编号 | 指标 | 采集口径 |
| :-: | :--- | :--- |
| **O1** | 任务完成 | `Completed / Partially Completed / Abandoned / Failed`；**必须有现实完成标准**，不得以「AI 说完成了」替代实际完成 |
| **O2** | 返工 | 是否返工 / 次数 / 发生在哪一层 / 原因分类：需求理解差异·Human 判断改变·AI 实现偏差·上下文缺失·权限问题·工程故障·外部条件变化 |
| **O3** | Human Attention Burden | 客观计数：主动输入次数 / 必须确认次数 / **重复确认次数** / 候选重生成次数 / Frame Rejection 次数 / 人工纠错次数 / 返回次数。核心问题：**机器有没有把不必要的人类操作真正拿走** |
| **O4** | Human Judgment Preservation | 哪些关键节点必须 Human 判断 / Human 是否真看到可判断对象 / 是否发生**未经 Human Decision 的 Commitment** / 是否发生 **Authority 越界**。目标不是「操作越少越好」，而是「**不必要操作越少越好，必要判断不能丢**」 |
| **O5** | Semantic Integrity | Human Source / AI Interpretation / Preference / Judgment / Authorization / Commitment 是否仍可区分。**特别记录负面结果**：语义被压扁、来源丢失、AI 推断被误记成人类原话、选择被误升格为授权 |
| **O6** | Recovery / Traceability | 出问题后能否回答：发生了什么 / 差异在哪里进入 / Human 当时看到什么 / AI 为什么那么做 / 谁授权了什么 / 最终状态为何形成。**只能靠猜 = `Recovery Failure`** |

### §4.1 不得把工程指标冒充现实指标
`Test Pass` / `Build Pass` / `Gate Pass` / `Commit Exists` / `Contract Conformance` 全部属于 **Engineering Evidence**，**不是 Real-world Outcome**。它们只能证明观察基础设施可信，**不能证明现实效果优秀**。

---

## §5 R2｜归因规则

### §5.1 强制反事实提问
每一个重要效果都必须至少问：
> **如果没有这套机制，结果可能会不会一样？**

```
当前机制下 Human 只确认 2 次
  ✗ 不能直接推出「EHAI 减少了 Human 负担」
  ✓ 至少还需知道：类似任务过去约需几次？同类非 EHAI 流程怎样？
     是否只是模型这次特别聪明？任务本身是否更简单？
```

### §5.2 三种比较面（**Comparison B 已由 Human Authority 定义，禁止人为制造劣化对照**）

> **正式原则**：
> ```
> Comparison 必须是真实可比流程
> ≠ 为了证明 EHAI 人工制造一个明显更差的对照
> ```

**Comparison A｜Historical Baseline**：同一个人、相似任务**过去**如何完成。

**Comparison B｜Workflow Baseline**（**不新开发「去 EHAI 模式」；禁止为了实验专门造劣化版本**）：

- **AsWish B** — 真实存在的**传统自由式 AI 软件开发流程**：
  ```
  Human 自由描述需求 → AI 自由文本理解/建议 → Human 自由文本修改
  → AI 实现 → Human 查看结果 → 继续自由文本返工
  ```
  不要求具备：`0–9 Choice Grammar` / 显式 Decision Surface / Candidate-first / 结构化 Commitment Boundary / Recoverable Lineage。
  优先使用**历史真实开发 Episode**，或观察期内真实发生但**未使用完整 EHAI 机制**的自然任务。

- **AXIS B** — 现实中已存在的**普通人工 / 普通 AI 辅助关系经营流程**：
  ```
  Human 找联系人 → Human/普通 AI 自由判断 → Human 决定下一步
  → Human 手工执行或普通工具辅助 → 事后人工回忆/记录结果
  ```
  不专门引入：EHAI CandidateSpace / 显式 Authorization Grammar / HB Choice / Structured Lineage。
  同样优先使用**历史真实工作样本**。

**红线**：**不得人为关闭安全机制来制造对照。**

**Comparison C｜Internal Contrast**：同一系统内 —— 候选先行 vs 自由聊天式探索／明确 Human Decision vs 模糊自然语言确认／Recoverable Lineage vs 事后人工追忆。

### §5.3 干扰变量登记表（Confounders）
```
模型版本 | Prompt/Agent 变化 | 软件版本 | 产品版本 | Human 熟练度
任务复杂度 | 任务类型 | 上下文规模 | 外部服务状态 | 工程环境变化
+ 其它明显影响结果的因素
```

### §5.4 模型变化必须单独登记
`Day N 普通模型 → Day N+k 切强模型` **不得**把切换后的提升全部归因给 EHAI。必须记录 `Model Change Event`，归因时**单独处理**。

### §5.5 工程变化必须形成 Intervention Event
```
Intervention ID | Commit | Reason | Affected Behavior | Expected Effect | Effective Time
```
数据必须分成 `Before Intervention` / `After Intervention`，**禁止混成一个统计池**。

---

## §6 R3｜Claim Ladder 与结论强度规则

| Level | 允许的表述 | Case 001 可用 |
| :--- | :--- | :---: |
| **E0** 事件事实 | 在 Episode X 发生了…… | ✅ |
| **E1** Case 内观察 | 在 Case 001 当前样本中观察到…… | ✅ |
| **E2** 重复模式 | 在多个 Episode 中重复出现…… | ✅ |
| **E3** 带归因支持的 Case 结论 | 现有证据支持：该机制可能与该效果存在稳定关联 | ✅ |
| **E4** 跨 Case 经验主张 | 需后续多个独立 Empirical Case | ❌ **单靠 Case 001 不得到达** |

**Case 001 禁止使用**：
```
EHAI 已证明有效 / EHAI 普遍有效 / 这是人机交互最优方案 / EHAI 导致了全部改善
```
**强制不等式**：`Claim Strength ≤ Available Empirical Evidence`

---

## §7 Evidence Set 分层与追溯

```
E0 Raw Evidence → E1 Normalized Episode Record → E2 Analysis Dataset → E3 Empirical Claim
```
**强制追溯链**：`E3 → E2 → E1 → E0`（断链即该主张不可成立）。

---

## §8 ⭐ Reality Evidence Admission Gate（准入门）

**任何证据进入 `R1 Outcome Dataset` 之前必须先过此门**：

```
[ ] 1. Evidence mode 可以机器读取
[ ] 2. Real / Mock / Simulation 可以机器区分
[ ] 3. Evidence provenance 可恢复
[ ] 4. Real-world outcome 不依赖自然语言免责来解释
[ ] 5. 没有已知 Reality Classification Defect
```

**强制原则**：
```
Human-readable Note  ≠  Evidence Classification
Machine-readable Reality Claim  ≤  Real-world Evidence
Disclaimer  cannot downgrade  a false machine claim  into a true claim
```
> **机器字段如果说「真的发生了」，那就必须真的发生了。**

---

## §9 F4 规则（**永久，非临时**）

### §9.1 Case 001 可以启动，**不必等待 F4**
自 `2026-09-17` 起：`AsWish` 可进入正式 Episode Observation；`AXIS` 可记录 Episode。
**但**涉及 Real Delivery / Real-device Outcome 的证据，在 **F4 CLOSED 前不得通过 Admission Gate**。

```
Episode 可以记录
Raw Evidence 可以保留
但：受 F4 污染的数据 不得晋级为 Real-world Outcome Evidence
```

### §9.2 永久排除清单
```
D:\_Progs\02Business\DeepAxis\docs\DA-131-Delivery\flight-receipt.json
D:\_Progs\02Business\DeepAxis\runtime\flight-receipt.json
D:\_Progs\02Business\DeepAxis\runtime\flight-receipt-dryrun.json
（以及任何 mode="real" 而实际为 mock-injection / engine-level verification 的产物）
```
**永久分类** = `Engineering / Defect Evidence`。
**不得**作为：`Real-world Outcome Evidence` / `Real-device First-flight Evidence` / `L8 R1 Empirical Evidence`。

### §9.3 F4 CLOSED 后
必须登记：
```
F4 Fix Commit | F4 Delta Review Verdict | Evidence Semantics Version | Effective Time
```
从该有效点之后，**新证据重新接受 Admission Gate 审查**。
**历史 F4 receipt 永久不得洗白成 real evidence。**

---

## §10 严重事故优先记录（异常规则）

```
Human Authority 越界 | 错误 Commitment | 错误执行 | 语义误导 | 证据丢失
恢复失败 | 重要返工 | 用户放弃 | Frame Rejection | AI 反复误解
```
> **失败不是污染数据，隐瞒失败才污染数据。**

---

## §11 周期、样本下限与 Early Stop

- **观察周期**：`28 natural days`，`2026-09-17 → 2026-10-14`（**仅工程观察参数，非理论要求**）
- **样本下限**：`AsWish ≥ 20` + `AXIS ≥ 20 valid Episodes`，且每产品**至少覆盖 3 种 Task Type**
  - **正式解释**：`20+20` 是 **Case 001 的最低分析门槛**，**不是统计学充分性证明，也不是理论要求**
  - 窗口结束时不足 → **不得降低样本门槛迁就结果**；应延长 Observation Window，或由 Human Authority 明确裁定 `Insufficient Evidence`
- **不得**为了赶 28 天终点而降低 Evidence Admission 标准
- **自动转 Extended Observation** 的情形：`20+20 未达到` ／ `关键 Evidence 缺失` ／ `F4 导致 AXIS 有效观察起点明显滞后` → 须登记延长原因
- **Early Stop 触发条件**（任一）：
  ```
  严重 Authority 越界 | 未经 Human 的高影响 Commitment
  反复出现同类 Semantic Collapse | 不可恢复的关键 Evidence Loss | 系统性错误执行
  ```
  **`Early Stop ≠ Case 失败`** —— 而是触发**安全 / 机制专项审查**

---

## §12 中期检查（只设一次）

`Midpoint Integrity Review = 2026-09-30`（首轮 28 天窗口不变的前提下）。
**只允许检查**：
```
数据有没有采到 | 证据是否可恢复 | 是否大量缺字段
是否发生 Intervention | 是否有严重事故 | F4 是否已 CLOSED
```
**禁止**：提前宣布 EHAI 有效/无效；根据初步趋势修改指标；删除不利 Episode。

---

## §13 冻结程序（Observation Freeze Point）

已在 **§0.2** 完成。此后所有数据必须引用本 Protocol Version。

---

## §14 主观数据边界与 Self-report（已启用）

**模式**：`VOLUNTARY` + `LOW-BURDEN`。**不要求每个 Episode 强制填写完整问卷。**

**默认触发**：关键 Episode ／ 出现明显返工·Frame Rejection·Authority Incident ／ Human 主动愿意反馈时。

**四问**：
```
1. 这次是否达到了你的目的？
2. 哪一步让你觉得多余？
3. 有没有哪一步系统替你做了你认为应该由你决定的事情？
4. 如果再做一次，你最希望哪里不同？
```
允许简单回答：`无 / 没有 / 达到 / 不确定`。
**不得为了研究完整性增加 Human 的额外操作负担。**

**强制区分**：
```
Observed Behavior  ≠  Human Subjective Judgment
```
AI **不得**从「用户没抱怨 / 点击速度 / 使用次数」推断满意度、信任感或轻松程度。须登记为 `Human Self-report`。

---

## §15 隐私纪律

**默认「最小必要采集」。** 真实业务内容若与分析无关 → **不进入研究数据集**。
优先保存：`结构 / 事件 / 状态 / 差异 / 指标 / 证据引用`，而非完整私人内容。

---

## §16 Observation Gap Assessment（Protocol 冻结后的下一任务）

**开发方下一任务不是立即增加埋点**，而是先做 Gap Assessment。分别调查 `AsWish` / `AXIS` 现有系统**已经能够自然产生**哪些数据：

```
Episode | Decision | Candidate | Regenerate | HumanOverride | FrameRejection
Authorization | Commitment | Lineage | Rework | Outcome | Evidence
```

形成三类：
```
A. Already Observable
B. Recoverable With Existing Evidence
C. Not Observable
```

**只有 C 类中「直接阻断 R1 / R2 / R3 判断的项目」** 才允许形成 `Observation Blocking Gap`。之后再决定是否开发。

**默认原则**：
```
No Gap        → No Code
Small Gap     → Small Instrumentation
Nice-to-have  → Do Not Build
```

### §16.1 严禁为了 L8 重造产品
禁止：`大数据平台` / `统一埋点平台` / `EHAI Analytics Engine` / `实验管理中心` / `完整遥测系统`——**除非后续多个真实 Case 证明必要**。
Case 001 应尽量使用现有 `Git / Decision / Evidence / Logs / Snapshot / Lineage / Audit Trail` 完成。

---

## §17 分析顺序（观察结束后依次执行，禁止倒序）

```
Step 1  Evidence Integrity Review
Step 2  Outcome Analysis / R1
Step 3  Confounder Review
Step 4  Attribution Analysis / R2
Step 5  Counterexample Review
Step 6  Claim Strength Review / R3
Step 7  Human Authority Review
```
**禁止**：先写结论 → 再找证据。

### §17.1 Counterexample 强制单独成章
最终报告**必须**含 `Evidence Against the Hypothesis`：哪些 Episode 没有改善／哪些情况反而更麻烦／哪些机制没起作用／哪些结果可能与 EHAI 无关／哪些数据反驳原有期待。
**缺此章 → Empirical Case 不得 CLOSED。**

---

## §18 允许出现的最终结果（不要求正面）

```
Positive Evidence | Mixed Evidence | No Observable Effect
Negative Effect | Attribution Not Established | Insufficient Evidence
```
**全部都是有效研究结果。**

### §18.1 禁止单一合成分数
允许计算：`completion rate` / `rework frequency` / `human intervention count` / `correction frequency` / `authority incident rate` / `semantic incident rate`。
**禁止**构造无理论依据的 `EHAI Score = 92` 或 `整体有效率 87%`。

---

## §19 三个出口（Case 001 结束后）

| 出口 | 触发条件 | 去向 |
| :--- | :--- | :--- |
| **A｜工程问题** | 现实证据 → Implementation Finding | 产品 / DeepBase 正常工程流程；**不得修改冻结理论** |
| **B｜公共契约问题** | **强证据**支持「多个产品共同出现 且 产品层无法合理处理」 | `Common Contract Revision Candidate`（仍需 Human Authority） |
| **C｜理论挑战** | 真实经验与冻结 EHAI 命题发生**实质冲突** | `New Evidence / New Theory Finding → Revision Candidate → Human Authority Review → Explicit Reopen`；**禁止直接编辑 L1–L8** |

---

## §20 DA-131B Evidence Gap 处理

原始基准件灭失 = `Permanent Evidence Gap`。
**Case 001 中不得**通过现实运行结果反向声称「原始源码已经被正确恢复」。
现实运行**只能支持**：`当前版本在当前环境中的行为表现`。**这是不同命题。**

---

## §21 Protocol Amendment 规则

自 Freeze Commit 起，任何正文变化**必须**：
```
1. 记录：为什么改 / 什么时候改
2. 记录：改之前已有多少数据
3. 记录：受影响数据有哪些
4. 受影响数据不得与新标准混算
5. 形成新的 Protocol Version，重新冻结为 Git Object
```
**禁止静默修改、禁止普通编辑。**

---

## §22 成功标准（总）

```
成功 ≠ 证明 EHAI 好用

成功 =  能够可信回答「真实发生了什么」
      + 能够区分「哪些效果可能来自 EHAI、哪些不能归给 EHAI」
      + 最后的结论没有超过证据
```
即 `Outcome Integrity + Attribution Integrity + Empirical Claim Integrity` **三者同时成立**。

---

## §23 并行任务：F4 整改（旁路，不阻断 Case 001）

**F4 Owner** = 当前串行多仓开发 AI（开发甲）｜**Owner Repo** = `DeepAxis`
**立即进入 `WO-20260916-DEEPAXIS-F4`**；在 F4 CLOSED 前**禁止其它非必要 DeepAxis 功能开发**。

**执行顺序**：
```
Step 1  保护现有 F4 原件 / SHA256 / provenance   ← ✓ 主控已完成，不得破坏
Step 2  修 mode machine semantics
Step 3  修 terminal_state
Step 4  修 audit_trail reality semantics
Step 5  检查 / 修正 dispatch_success 定义
Step 6  隔离 mock clock / TimestampGetter，不得跨入 real delivery path
Step 7  增加 Machine Consumer Test
Step 8  全量相关 regression
Step 9  isolated commit
Step 10 独立 F4 Delta Review
```

**判定权**：开发甲**不得**自己宣布 `F4 = CLOSED`，**只能提交 `READY FOR F4 DELTA REVIEW`**；由主控 / 独立审计判定。

---

## §24 请示纪律

本裁定后，**不得继续向 Human Authority 请示 Protocol 基本参数**，按既定协议继续执行。

**仅当发现以下情形**才需再请示：
```
严重 Authority Incident | 现实证据真实性问题
Protocol 内在矛盾 | 无法进行有效观察的 Blocking Gap
```

---

## §25 当前状态

```
EHAI L1-L8                        FROZEN v1.0
        ↓
Engineering Conformance           CLOSED
        ↓
Cross-product Reuse Evidence      ESTABLISHED
        ↓
L8 Empirical Case 001             AUTHORIZED
        ↓
Observation Protocol v1           FROZEN NOW
        ↓
Observation START                 2026-09-17
```
旁路：`DeepAxis F4 → REMEDIATION NOW → Delta Review`

> **不要再问「我们是不是把 EHAI 做出来了」。**
> Case 001 问的是：**人真正使用以后，哪些麻烦少了，哪些判断被保护住了，哪些问题仍然存在，以及这些变化究竟能不能归因给 EHAI。**
