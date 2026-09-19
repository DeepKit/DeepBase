# WO-20260915-EHAI-DOWNSTREAM-001-B-R1 · AXIS 复审结论

- **审核对象**：`docs/WO-20260915-EHAI-DOWNSTREAM-001-B-AXIS-Gate-C-交付报告.md`（R1 收口版）+ 提交 `c0f466fc5664718640fc531e95f32ad25405d7d4`
- **上游基准**：DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`（FROZEN，已核未碰）
- **送审工单**：`CodeReview/20260915-EHAI-DOWNSTREAM-001-B-AXIS独立审核结论.md`（前轮 HOLD）+ `WO-20260915-EHAI-DOWNSTREAM-001-B-R1-AXIS最小整改工单.md`
- **复审方法**：git 对象级追溯（含 `-S` 全历史符号追溯、reflog、不可达对象）、源码原文核对、日志逐行验算、跨仓影响面扫描
- **复审人**：主控（Amy）
- **复审时间**：2026-09-16

---

## 一、结论（先行）

**B-R1 = HOLD。**

| 维度 | 结果 |
| :--- | :--- |
| 前轮 2 项阻断（B-B1 / B-B2）**技术目标** | ✅ **均已达成** |
| 整改过程合规性 | 🔴 **不合规——执行了未经授权的销毁性操作** |
| 被销毁交付的当前状态 | ⚠️ **已于 2026-09-16 11:24 被外部重建（未提交、保真度未验证）**——见 §三 |
| 报告自述与事实一致性 | ⚠️ 基本一致，但**未披露销毁行为造成的连带破损** |
| 新增阻断 | **1 项（BLOCK-B-R1-1，交付物生命周期无保障）** |

> **Verdict = HOLD ／ Integration Ready = NO ／ Phase C 维持 LOCKED**
> 阻断原因**不是**前轮问题未修好，而是：
> ① 整改手段本身销毁了一份已过审交付（虽事后被重建）；
> ② 重建版本**未提交**，同一脆弱性原样保留；
> ③ 重建的**保真度未经任何验证**，且无 git 基线可与之比对。
>
> ⚠️ **本文件于 2026-09-16 11:30 做过一次订正**：11:24 之前，被销毁的源码经全树扫描确认无法恢复；11:24 出现外部重建版本。§三 已按事实重写，不保留旧结论。

---

## 二、逐项闭合核对（前轮问题）

### B-R1-1｜让 HJF0 72/72 可由 Git 单独复现 → ✅ **技术目标达成**

- `src/governance/DeepAxis.Governance.HJF0.Capability.pas` 现 `git diff HEAD` **为空**（工作区与 HEAD 一致）；
- `ci-logs/ehaibinding002-gatec-r1-hjf0.log` 末行 `[SUMMARY] pass=72 fail=0` + `HJF0_ALL_CHECKS_PASSED` + `Exit Code: 0`；
- 因此 72/72 现确由**已提交的干净基线**产出，`Canonical Claim ≤ Git Evidence` 不等式恢复成立。

**该 build 日志为真实原始编译器转录**（非摘要），含逐 Hint 的文件行号，证据质量优于 Phase A：

```text
src\governance\DeepAxis.Governance.HJF0.Audit.pas(141) Hint: H2077 …
src\governance\DeepAxis.Governance.HJF0.PolicyGate.pas(226) Hint: H2164 …
5466 lines, 0.58 seconds, …        Exit Code: 0
Compiler Warnings: 0, Compiler Errors: 0, Compiler Hints: 1 (H2077 in HJF0.Audit.pas:141)
```

### B-R1-2｜AXIS-N2 结论与代码矛盾 → ✅ **已闭合**

- `src/core/DeepAxis.Binding.EHAI.pas:85` 起实装 `TAXISConvergenceTrace`（含 `OriginalCount` / `RetainedCount` / `DiscardedCandidates`），`:166-206` 挂 `FConvergenceTraces` / `FLastConvergenceTrace` 及只读属性；
- `tests/AxisBindingTests.dpr` 含新断言 `AXIS-V-002-ConvergenceTraceRecorded` / `AXIS-V-002-ConvergenceAuditEventAppended`（各 1 处）；
- `ci-logs/ehaibinding002-gatec-r1-tierc.log` 两行均 PASS，且全文恰为 29 项 / `29 checks passed, 0 checks failed`，与报告 §八 一致。

### B-R1-N1 ~ N4（非阻断项）

| # | 项 | 判定 |
| :---: | :--- | :---: |
| N1 | 「`CreateWildcard`」改为「以 `CreateStanding(…,'*',…)` 表达通配」 | ✅ 报告 §四 已改写 |
| N2 | `FContactDB1` 幻影符号 | ✅ 报告已改引可 grep 的真实路径 |
| N3 | 编译 Hint 如实标注 | ✅ 报告 §八 已注「1 Hint (H2077)」，与日志一致 |
| N4 | 补 worktree 台账 | ✅ 报告 §九 已补，与 `git status` 实测吻合 |

---

## 三、新增阻断：BLOCK-B-R1-1（已过审交付先被销毁、后被重建，生命周期仍无保障）

> ⚠️ **本节经历了复审期间的动态事实变更**，按时间线记录，不掩盖先前的判断。

### 3.0 事件时间线（2026-09-16）

| 时刻 | 事件 | 证据 |
| :--- | :--- | :--- |
| 10:45:27 | 开发方执行 `git checkout HEAD`，`Capability.pas` 被写回 HEAD 版本（**240 行，`HJValidateAndExecuteUiaPaste` 消失**） | 文件 mtime；`git diff HEAD` 为空 |
| ~11:14 | 主控复审读取该文件：命中数 **0** | `grep -c` = 0 |
| 11:24:15 | **出现外部重建版本**：`Capability.pas` 变为 **311 行**，`HJValidateAndExecuteUiaPaste` 重新出现；同目录 `.dcu` 同时更新 → **重建后经过重新编译** | mtime `.pas`/`.dcu` 均为 11:24；`git diff HEAD` = **+84 / −13** |
| ~11:27:55 | 全树扫描（`02Business` 递归，17m53s）结束，**未列出该 `.pas`**（扫描途经该目录时早于 11:24） | 扫描输出 |
| ~11:20 至 11:30 | 主控据「未恢复」事实撰写了本文件初版 | — |
| 11:30 | 主控发现重建版本，**订正本文件**（本节重写） | 本文件 |

**重建来源不明**（非主控所为；无 stash、无新提交、HEAD 仍为 `c0f466f`）。须由老板确认是**从备份忠实还原**还是**依据归档报告重新实现**——两者可信等级不同。

### 3.1 事实链（销毁侧）

报告 §九 B-R1-1 自述：

> `Capability.pas` 未提交修改（+82 行，**系前序 DA-131B 残留**）已通过 `git checkout HEAD` **彻底恢复为纯净版本**

**该「残留」的定性是错误的。** 被销毁的内容是 **DA-131B 阶段 B 的 AC1 核心交付**：

| 证据 | 内容 |
| :--- | :--- |
| `docs/_archive/DA-131-Delivery/主控审核结论-DA-131-阶段B.md` §2.2 | 「`src\governance\…HJF0.Capability.pas`：治理校验器 `HJValidateAndExecuteUiaPaste` **真实存在**……✅」 |
| 同上 §三 | `AC1 能力落地` = **PASS**；`AC3 fail-closed 三件套` = **PASS**；整体 = **CONDITIONAL PASS** |
| 同上 §三 | 「真机首飞 **不单独返工**」——即明确**未要求废弃任何代码** |
| `187-DA-131B-阶段B端到端首飞工单.md` / `188-…交付与请求审核报告-开发AI.md` | 交付日期 2026-09-02，审核 2026-09-04 |

即：**一个主控已判 PASS、且明确「不返工」的产品能力实现，被整改方以「残留」为名删除。**

### 3.2 不可恢复性（全路径排查）

| 恢复源 | 结果 |
| :--- | :--- |
| `git log --all -S "HJValidateAndExecuteUiaPaste"` | **空** → 该符号**从未进入任何提交** |
| stash / 不可达对象 | 无 |
| `docs/_archive/DA-120-F0-Delivery/staging/.../HJF0.Capability.pas`（F0 快照） | `HJValidateAndExecuteUiaPaste` 命中 **0** |
| `candidate.diff`（DA-131 归档 diff） | 命中 **0**（系阶段 A 的 Config/Evidence/Radar 差分） |
| 归档阶段 B 报告 | 仅文字描述**行为**，`begin/end` 块 **0 处** → 无代码可复原 |
| 现存 `.pas` / `.dpr` | 仅 `tests/PhaseBTests.dpr` 引用（见 3.3） |
| 编译产物 | `dcu/…Capability.dcu`、`src/governance/…Capability.dcu`、`tests/PhaseBTests.map` 保留符号**名字**，**不含源码文本** |
| **全树扫描（`/d/_Progs/02Business` 递归，全文件类型，历时 17m53s）** | 全部命中仅 9 处，**无任何 `.pas` 源码副本**——其余为：2 个 `.dcu` + 1 个 `.map`（编译产物）、`tests/PhaseBTests.dpr`（调用方）、归档报告 ×3（文字）、主控自身的审核结论与记忆文件 ×2 |

**结论（截至 11:24 前）：源码不可恢复。** 全树扫描已排除「副本藏在其他目录」这一可能。

> **订正**：上表结论在 **11:24 之后不再成立**——出现外部重建版本。但上表仍然成立的是：**这些恢复源中没有一条能复原原实现**。故 11:24 的版本**只能是「外部另存副本」或「重新实现」**，二者都无法与原始实现做字节级比对。这一点是保真度风险的根源（见 §3.5）。

### 3.3 连带破损（报告未披露）

| 项 | 事实 | 影响 |
| :--- | :--- | :--- |
| `tests/PhaseBTests.dpr:135-145` | 曾调用已不存在的 `HJValidateAndExecuteUiaPaste`（4 处）→ 销毁窗口内**该测试工程不可编译**。11:24 函数重建后**应已恢复可编译，但尚未复验** | 悬空引用风险暂解，**待重跑确认**（见 §5.1 第 3 项） |
| `tests/PhaseBTests.exe` / `.map` | 残留旧二进制（代码存在时编译） | 悬空产物，无法重建 |
| `src/f2b/DeepAxis.F2B.Engine.pas:664` | 仍发 `f2b_uia_paste_executed` 审计事件，但该文件**未跟踪**（`??`） | 阶段 B 特性链仅存于工作树 |
| `f2b_send` / `f2b_receipt` / `hj-f2b-capability-manifest` | `git log -S` 全为 **0 次提交** | 阶段 B 整条特性**零 git 保障** |

> 即：DA-131B 阶段 B 的交付**从未被提交过**——这是损失的**根因**；「判为残留」只是**近因**。

### 3.4 责任划分（须双方各记一笔）

| 责任方 | 事实 | 定性 |
| :--- | :--- | :--- |
| **开发方** | 工单 B-R1-1 的 `改法` 原文为「**（推荐）** 在干净工作区重跑（`git stash` 或临时 worktree checkout 到 `HEAD`）」——两种手段**均保全工作区改动**。实际执行 `git checkout HEAD` 直接覆写文件，**既未 stash 也未用临时 worktree**，是全选项中**唯一不可逆**的一种 | **执行偏离授权手段，造成不可逆后果**（非主观恶意，属手段误选） |
| **主控（Amy）** | 本方工单**硬前置**表原话：「DeepAxis 既有脏区（**含 `HJF0.Capability.pas`**）已核实为开工前既有，**与本次承接无关**；**不得**卷入本工单提交」。此句把**已过审交付**错误归类为「无关既有脏区」，为「残留」定性提供了依据；且工单**未显式禁止 `git checkout --`／`git restore` 等销毁性操作** | **工单设计缺陷：误标已过审交付 + 未列销毁性操作禁令** |

> 本方不把责任单方面推给开发方。整改工单若只写「保持干净工作区」而不写「禁止销毁性复原」，本身就留下了这条通道——这是主控必须吸收的教训（见 §六）。

### 3.5 对重建版本的独立核验（主控 11:30 起）

**✅ 已核验成立的部分**（源码级）：

| 项 | 事实 |
| :--- | :--- |
| 函数签名与调用方一致 | 现声明 `(AManifest; AAccountId, AContactId, AMessageText: string; out AError: string): Boolean` ↔ `tests/PhaseBTests.dpr:136-145` 的 5 参调用形态一致 |
| fail-closed 四路齐备 | 未声明→`HJ_ERR_CAPABILITY_NOT_DECLARED`；`csNotImplemented`→`CAPABILITY_NOT_IMPLEMENTED`；`csDisabled`→`HJ_ERR_CAPABILITY_DISABLED`；错号→`HJ_ERR_AUTH_ACCOUNT_MISMATCH`；空联系人→`HJ_ERR_IDENTITY_UNCERTAIN`；空消息→`HJ_ERR_COMMAND_INVALID`；否则 `True` |
| 与归档阶段 B 规格吻合 | 归档报告 AC1 要求「对**错号、空联系人、空消息**严格 fail-closed」，重建版本三路齐备且错误码语义对应 |
| 依赖符号全部解析 | `CAP_SEND_UIA_PASTE`（`Types.pas:60`）、`HJ_ERR_AUTH_ACCOUNT_MISMATCH`（`:33`）、`HJ_ERR_IDENTITY_UNCERTAIN`（`:23`）、`HJ_ERR_COMMAND_INVALID`（`:21`）均存在 |
| 编译产物已刷新 | `.dcu`（117KB）与 `.pas` 同为 11:24 → **重建后确实编译过** |

**🔴 未能核验的部分（构成本阻断成立的依据）**：

| 风险 | 说明 |
| :--- | :--- |
| **未提交** | `git status` = ` M`，HEAD 仍 `c0f466f`。⇒ 「工作树单副本」脆弱性**原样保留**，同一事故可再度发生 |
| **保真度不可验证** | 无 git 基线可比对；重建版 `+84 / −13`，归档报告记为 `+82` 行——**增量不一致**，无法判定是版本漂移还是重建差异 |
| **来源不明** | 无法确认是备份还原（可信）还是据报告重新实现（需完整复核） |
| **行为等效未验证** | 主控仅做**静态**核验；`tests/PhaseBTests.exe` 未重跑，且该工程此前因悬空引用不可编译——重建后是否恢复可编译**尚未复验** |

> **判定**：重建把「不可逆灭失」降级为「可控风险」，但**四条未核验项任一条未清，都不能给出 Integration Ready = YES**。上方「已核验成立」仅支撑「重建在语义上像是那么回事」，**不等于**「等价于原实现」。

---

## 四、其他观察（非阻塞）

| 项 | 事实 | 判定 |
| :--- | :--- | :--- |
| 编译 Hint | `HJF0.Audit.pas(141) H2077`（另有多条 H2443/H2164 未在报告汇总行体现，日志正文完整） | 报告如实披露主要一条，**可接受**；汇总行与日志正文的 Hint 计数口径建议统一 |
| 工作树脏度 | 401 `D` + 268 `??` + 16 `M` = **685** 项 | 报告已声明「既有脏区绝对隔离，未执行跨边界 `git add .`」，与实测一致 → **合规**。但 P-1（脏基线快照）风险仍挂账未清 |
| 跨仓 | DeepBase `HEAD = fc213b4` 未变；AsWish 未碰 | ✅ |

---

## 五、裁定与前置动作

```text
AXIS B-R1 复审裁定：
  B-R1-1 技术目标：达成（72/72 现由干净已提交基线产出）
  B-R1-2 技术目标：达成（TAXISConvergenceTrace + 审计事件 + 29/29）
  新增阻断 BLOCK-B-R1-1：已过审交付先被未授权销毁性操作清除；
                        11:24 出现外部重建版本，但未提交、保真度未验证

  Verdict            = HOLD
  Integration Ready  = NO
  Phase C            = LOCKED（须双仓 IR = YES）
```

### 5.1 前置动作（按序）

| # | 动作 | 责任 | 阻塞 |
| :---: | :--- | :--- | :---: |
| 1 | **确认重建来源**：说明 11:24 的 `Capability.pas` 是**备份忠实还原**还是**据归档报告重新实现**（并附副本出处）。两者决定后续验证强度 | 老板 / 开发方 | ✅ 阻塞 |
| 2 | **立即提交重建版本**：以独立 commit 固化，消除「工作树单副本」。**先提交再验证**——这是本次事故最直接的教训 | 开发甲 | ✅ 阻塞 |
| 3 | 复验 `tests/PhaseBTests.dpr` 可编译 + 重跑 `PhaseBTests.exe`，归档原始日志（行为等效验证） | 开发甲 | ✅ 阻塞 |
| 4 | 将 F2B 特性链关键文件纳入版本控制（`DeepAxis.F2B.Engine.pas`、manifest、`FirstFlightPhaseB.dpr`），消除同类脆弱性 | 开发甲 | ✅ 阻塞 |
| 5 | **裁定销毁性操作的性质与追责口径**：属手段误选（无主观恶意）还是流程违规；是否需补强工单模板为强制项 | 老板 | 非阻塞（但须留痕） |
| 6 | 报告补登 §九 台账：如实披露本次销毁动作及其后果（现报告仅称「恢复为纯净版本」） | 开发甲 | 非阻塞 |

> 主控建议：**接受重建版本，但须经第 2、3 步「先提交、后验证」才认账**；同时把本次事故登记为「**未提交即未交付**」流程缺陷样本。AC1/AC3 能力在真机首飞（并入 DA-132）前仍属必要，故不主张作废。

---

## 六、纪律补强（本次事故的可复用产出）

`Canonical Claim ≤ Git Evidence ≤ Runtime Evidence` 之外，本条事故揭示**第二条不等式**：

```text
交付的生命周期保障  ≤  该交付是否进入版本控制
```

即：**未提交的交付 = 未交付**。无论测试多绿、审核多过，工作树单副本随时可灭。

**整改工单模板须新增两行硬约束（写入工单骨架）**：

1. **禁止销毁性 git 操作**：整改期间不得使用 `git checkout --` / `git restore` / `git clean` / `git reset --hard` 处置**非本工单产出**的工作区改动；需让渡基线时必须用 `git stash`（可恢复）或临时 worktree（不动原树）。
2. **脏区定性须区分三类**，不得笼统称「既有脏区、与本次无关」：
   - (a) 纯噪声（工具产物、临时文件）——可忽略；
   - (b) 未提交的**历史已过审交付**——**不可销毁**，须先提交或经主控裁定；
   - (c) 本工单范围内的改动——正常提交。

---

## 七、审核纠偏记录（主控自省）

本轮中途曾据「`src/core/DeepAxis.Governance.HJF0.Capability.pas`」路径检索，得「文件不存在」结论，一度指向「整文件灭失」这一更严重的判断。经复核，真实路径为 **`src/governance/…`**（无 `core/` 段），文件**存在且受 git 跟踪**（240 行）。

| 中途判断 | 实情 |
| :--- | :--- |
| 「整个 Capability.pas 文件被删除」 | **错**。文件在、已跟踪、`HEAD` 版本完整；被销毁的仅是**+82 行的未提交增量** |
| 「`ScopeBoundary` 字段在 AsWish 不存在」 | **错**。该字段定义于公共层 `Core/DeepBase.EHAI.Types.pas:126/148`，AsWish 经继承使用 |

> 教训：**跨仓审计的路径必须从 `git ls-files` / 实际 `find` 结果取得，不得沿用记忆中的路径**。路径错一格，结论会从「增量丢失」夸大为「整文件灭失」——量级差一个数量级。
