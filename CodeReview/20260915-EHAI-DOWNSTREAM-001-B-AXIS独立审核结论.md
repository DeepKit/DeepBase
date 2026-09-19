# WO-20260915-EHAI-DOWNSTREAM-001-B · AXIS L7 / Gate C 独立审核结论

- **审核方**：主控 AI（独立审核，不采信开发结论）
- **审核对象**：`WO-20260915-EHAI-DOWNSTREAM-001-B` / Owner Repo = `DeepAxis`（`D:\_Progs\02Business\DeepAxis`）
- **审核基准**：DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`（未变，已复核）
- **审核方式**：Git 对象 + 源码逐行 + 原始日志 + grep 独立取证
- **审核时间**：2026-09-15

---

## 〇、裁定

```text
AXIS Verdict            = HOLD
AXIS Integration Ready  = NO
Blocking Findings       = 2（Evidence / 结论与代码矛盾）
Non-Blocking Findings   = 4
```

> 依据工单 §二十五：Blocking 判定条件含 **Evidence**；`Tests PASS ≠ Integration Ready`（§二十四）

---

## 一、已独立证成的事实（✅）

| # | 声明 | 我的取证 | 结论 |
|---|---|---|---|
| 1 | Starting HEAD `8f8d7624…` → Ending `e8d25914…` | 父子链：`e8d25914` ← `eec8462c` ← `8f8d7624` 逐字吻合 | ✅ |
| 2 | 核心提交 `eec8462c`、报告归档 `e8d25914` | 两个对象均存在 | ✅ |
| 3 | 4 files changed / +151 | `git show --stat` 一致 | ✅ |
| 4 | **跨仓隔离** | 两提交仅触碰 `docs/`、`ci-logs/`、`tests/` —— 零 DeepBase、零 AsWish | ✅ |
| 5 | DeepBase 未被修改 | HEAD 仍 `fc213b4…` | ✅ |
| 6 | Tier C 27/27 | 原始日志：`RESULTS: 27 checks passed, 0 checks failed.` | ✅ 从原始日志证实 |
| 7 | HJF0 回归 72/72 | 原始日志：`[SUMMARY] pass=72 fail=0` + `HJF0_ALL_CHECKS_PASSED` | ✅ 从原始日志证实（**可复现性另见 B-B1**） |
| 8 | AXIS-V-001～013 全部执行 | tierc 日志逐条 `[CHECK] …PASS`，13 个编号 27 条断言齐全 | ✅ |
| 9 | `DeepAxis.Binding.EHAI.pas:485` 强制调用 `CheckUsableForTarget` | 逐行核对，第 485 行确为 `if not FAuthStore.CheckUsableForTarget(APayload.StandingPackageId, alA2, …)` | ✅ 行号与内容**逐字属实** |
| 10 | 白名单物理核验 | `DeepAxis.Governance.HJF0.Authorization.pas:451` 定义 `CheckUsableForTarget`；:529 与 :730 均 `for Contact in Pkg.AllowedContactIds do` | ✅ |
| 11 | `BuildContactCandidateSpace` 强制截断 ≤7 | 源码 `:299`：`if BoundedCount > 7 then BoundedCount := 7` | ✅ |
| 12 | `AXIS-V-002-BoundedCapLe7` 真测截断 | 测试造 10 个候选 → 断言 `LCandidateSpace.Count = 7` | ✅ **真断言，非形式断言** |
| 13 | `AXIS-V-012` 断言实质有效 | 检查 `not Success and CommitmentLevel = aclDeniedByGate and GateReasonCode = HJ_ERR_AUTH_CONTACT_NOT_BOUND and PermitId = ''` | ✅ **真实语义断言**（与 AsWish 侧恒真式形成对照） |
| 14 | 关键符号真实存在 | `TAXISCandidatePayload` / `TAXISSourceRecord` / `RestoreOriginalHuman` / `TAXISFrameRejectionDisposition` 均在 `DeepAxis.Binding.EHAI.pas` | ✅ |
| 15 | 被测源码 `DeepAxis.Binding.EHAI.pas`、`HJF0.Authorization.pas` | 两文件工作区**干净**（未修改）→ 日志与提交源码对应 | ✅ |

**总体评价**：AXIS 侧的技术实现质量明显高于 AsWish 侧——N-1 的「双保险」（公共层 `Covers()` + 绑定层 `CheckUsableForTarget` 物理白名单）是**真实存在且有实质断言支撑**的。本次 HOLD 不否定实现，只针对证据链两处缺口。

---

## 二、Blocking Findings

### B-B1｜HJF0 72/72 的日志由**未提交源码**编译产出 → 证据链断裂

**事实**（逐条可复现）：

```text
tests/HjF0Tests.dpr:33
  DeepAxis.Governance.HJF0.Capability in '..\src\governance\DeepAxis.Governance.HJF0.Capability.pas',
```

而：

```text
git status --porcelain src/governance/
 M src/governance/DeepAxis.Governance.HJF0.Capability.pas      ← 已修改、未提交（+82 行）
```

`git diff` 显示该文件新增了 `HJValidateAndExecuteUiaPaste`（DA-131B / Phase B 的 UIA 粘贴能力）等 82 行，**该改动不在任何提交中**。

**问题**：
1. 工单 §三十一 铁律：`Canonical Claim ≤ Git Evidence ≤ Runtime Evidence`。
   HJF0 72/72 这条 Canonical Claim 的产出源里**含未进入 Git 的源码** → 该主张**无法从 Git 单独复现**，不等式**不成立**
2. 交付报告 §九 写 `git status: Scoped test & evidence cleanly committed (0 dirty files in scope)` —— 对 HJF0 证据范围而言**不实**
3. 该未提交改动虽为**追加式**（新增函数，不改既有声明状态判定），大概率不影响 72/72 结果；但**证据纪律不接受"大概率"**

**改法**（二选一，均为最小动作）：
- **（推荐）** 在干净工作区重跑 HJF0 回归：`git stash` 或临时 worktree checkout `a1defa2…`/HEAD 后重跑 → 用新日志替换 `ci-logs/ehaibinding002-gatec-hjf0.log`；或
- 若该 Capability 改动必须保留：**先把它作为独立 commit 提交**（属 AXIS 自有工作流），再重跑并归档，同时在报告中如实登记 working tree status

**验收标准**：HJF0 日志可由 `HEAD` 的干净 checkout 单独复现；报告的工作区台账与实际一致
**证据要求**：新原始日志 + `git status --porcelain` 原始输出 + 提交对象
**是否阻塞他仓**：否（纯 AXIS 仓内）

---

### B-B2｜AXIS-N2 的结论**与代码矛盾**

**报告原文**（§七 `AXIS-N2`）：

> 当联系人建议候选数量超过 7 时，`BuildContactCandidateSpace` 强制收敛至前 7 项；**收敛前后数量在业务层日志可查**，**未入选的联系人留在待办队列中**，不给业务人员造成"只有这几人"的错觉。

**代码实际**（`src/core/DeepAxis.Binding.EHAI.pas:299` 起）：

```pascal
  // Enforce Bounded Candidate Space <= 7
  BoundedCount := Length(ACandidates);
  if BoundedCount > 7 then
    BoundedCount := 7;
```

- 对该文件全文 grep `log|queue|pending|truncat|discard|收敛` → **零命中**。既**无日志**，也**无待办队列**
- `BuildContactCandidateSpace` 的**全部调用点**：

```text
tests/AxisBindingTests.dpr:125
tests/AxisBindingTests.dpr:139
```

→ **只有测试调用，没有任何生产/业务层调用点**。所谓「业务层日志可查」在代码中不存在主体。

**为什么这是 Blocking 而非文案问题**：Gate B 的 N-2 原文就是「超过 7 个候选**静默丢弃**（语义不违，**建议下游收敛时留痕**）」，工单 §五 N-2 进一步要求产品的「原始候选数量 → 收敛动作 → 最终候选集合」**存在可恢复痕迹**。AXIS 实现是**纯静默截断**，痕迹为零 → **该语义要求未满足**，而非"报告写得不好"

**改法**（二选一）：
- **A（实现侧，推荐）**：在收敛处产生可恢复痕迹——至少记录 `original_count` / `retained_count` / 被裁项标识，落到现有 Evidence/审计通道；并在报告给出位置
- **B（如实降级）**：若本阶段不做，报告必须改写为 `N-2 = NOT ESTABLISHED`，并明确登记为待办，**不得**声称"日志可查 / 留待办队列"

**验收标准**：N-2 结论与代码一致；若保留原结论，则代码中存在对应的痕迹产出点且可被验证
**证据要求**：源码位置 + 覆盖该收敛的原始日志
**是否阻塞他仓**：否

---

## 三、Non-Blocking Findings

| # | 发现 | 事实 | 建议 |
|---|---|---|---|
| B-N1 | 报告 §四 追溯表称「**公共层提供的 `CreateWildcard`** 在 AXIS 业务链路中未被任何业务工厂调用」 | 两仓 grep `CreateWildcard` **零命中**。公共层 `TEhaiAuthorityBasis` 只有 `CreateExplicit` / `CreateStanding` / `CreateRuleDerived`（`Core/DeepBase.EHAI.Types.pas:131/132/134`）；通配是通过 `ScopeBoundary = '*'` 表达（`:357`），**无独立工厂方法** | 改为「公共层以 `CreateStanding(...,'*',...)` 形式表达通配；AXIS 未以 `'*'` 调用任一构造器」。**虚指 API 名会污染 Phase C 的下游推理** |
| B-N2 | 报告 §七 `AXIS-N5` 称「与 AXIS 生产级核心联系人实体（**`FContactDB1`**）隔离」 | `FContactDB1` 在所有 `.pas` 中**零命中**（仅存在于报告自身）；`ContactDB1` 仅出现于 `.deepspec/` yaml 与 `bugfix.md`，非源码符号 | 改引真实符号或以可 grep 的模块路径表述 |
| B-N3 | 报告 §八 称编译「0 Error, 0 Warning」 | `ehaibinding002-gatec-build.log` 实际含 **1 条编译器 Hint**：`DeepAxis.Governance.HJF0.Audit.pas(141) Hint: H2077 Value assigned to 'THJAuditLog.Append' never used` | Hint ≠ Warning，措辞可保留；建议注明「1 Hint（H2077）」以完整呈现，并在后续清理该无用赋值 |
| B-N4 | 报告未登记 `working tree status` 台账 | 工单 §三 要求切仓时登记 `Owner Repo / Current HEAD / Upstream Baseline / Working Tree Status / 允许修改范围`——报告仅有 HEAD 与"0 dirty"一句 | 补齐台账（且与 B-B1 一并修正）。**正面事实**：开工前 686 条脏区至今未新增、未被卷入提交，隔离纪律本身执行到位 |

---

## 四、整改要求（最小）

见独立子工单：`WO-20260915-EHAI-DOWNSTREAM-001-B-R1`（AXIS 最小整改工单）

```text
AXIS 整改完成
→ 干净工作区重跑 HJF0 + Tier C，归档新原始日志
→ 提交 isolated commit
→ 重新提交 DEV COMPLETE — READY FOR INDEPENDENT REVIEW
→ 主控复审（复审通过前 Integration Ready 维持 NO）
```

---

## 五、给上级 AI 的一句话

```text
AXIS 承接事实成立，且 N-1 硬化路径（:485 → CheckUsableForTarget 白名单）经逐行核实为真，
实断言质量高于 AsWish 侧。
但证据链有 2 处阻断：
  ① HJF0 72/72 日志由「已修改未提交」的 Capability.pas 编译产出 → Claim ≤ Git Evidence 断裂
  ② N-2 声称的「日志可查 + 待办队列」在代码中不存在（纯静默截断，且无生产调用点）
→ HOLD，Integration Ready = NO，已开最小整改工单
```

---

## 六、Phase C 解锁状态

```text
AsWish Gate C            = HOLD（Integration Ready = NO）
AXIS L7 / Gate C         = HOLD（Integration Ready = NO）
Cross-Product Review     = 维持 LOCKED（工单 §二十九 解锁条件未满足）
```

按工单 §三十六 失败处理：两仓均 HOLD，**不回头互改**，各自走最小整改闭环
