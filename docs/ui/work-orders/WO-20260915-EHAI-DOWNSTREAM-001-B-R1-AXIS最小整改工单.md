# WO-20260915-EHAI-DOWNSTREAM-001-B-R1 · AXIS 最小整改工单

> **来源**：主控独立审核裁定 `AXIS Verdict = HOLD / Integration Ready = NO`
> **审核结论全文**：`CodeReview/20260915-EHAI-DOWNSTREAM-001-B-AXIS独立审核结论.md`
> **Owner Repo**：`DeepAxis`（`D:\_Progs\02Business\DeepAxis`）——**本工单只动 DeepAxis**
> **禁止**：修改 DeepBase / EHAI SSOT / AsWish；借机重构；扩充范围
> **基线**：承接提交 `eec8462ca31e428937c3adbc45d32adf53270837`，DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`

---

## 一、整改项（2 项阻断）

### B-R1-1｜让 HJF0 72/72 可由 Git 单独复现

- **文件:行**：`src/governance/DeepAxis.Governance.HJF0.Capability.pas`（工作区 `M`，+82 行未提交）
- **事实链**：
  ```text
  tests/HjF0Tests.dpr:33
    DeepAxis.Governance.HJF0.Capability in '..\src\governance\DeepAxis.Governance.HJF0.Capability.pas'
  ```
  而该 `.pas` 处于**已修改未提交**状态 → `ci-logs/ehaibinding002-gatec-hjf0.log`（72/72）由**未提交源码**编译产出
  → 违反 `Canonical Claim ≤ Git Evidence ≤ Runtime Evidence`（工单 §三十一）
- **改法**（二选一）：
  - **(推荐)** 在**干净工作区**重跑 HJF0 回归（`git stash` 或临时 worktree checkout 到 `HEAD`）→ 用新日志替换 `ci-logs/ehaibinding002-gatec-hjf0.log`；或
  - 若该 Capability 改动必须保留：**先将其作为独立 commit 提交**（属 AXIS 自有工作流），再重跑并归档
- **验收标准**：HJF0 日志可由 `HEAD` 的干净 checkout **单独复现**；报告工作区台账与实际一致
- **证据要求**：新原始日志 + `git status --porcelain` 原始输出 + 提交对象 SHA
- **阻塞他仓**：否

### B-R1-2｜AXIS-N2 结论与代码矛盾，须实现痕迹或如实降级

- **文件:行**：`src/core/DeepAxis.Binding.EHAI.pas:299` 起（`BuildContactCandidateSpace`）
- **现状**：
  ```pascal
  BoundedCount := Length(ACandidates);
  if BoundedCount > 7 then BoundedCount := 7;   // 纯静默截断
  ```
  全文 grep `log|queue|pending|truncat|discard|收敛` → **零命中**
  调用点仅 `tests/AxisBindingTests.dpr:125` / `:139` → **无生产调用点**
  而报告 §七 `AXIS-N2` 称「收敛前后数量在**业务层日志可查**，未入选的联系人**留在待办队列中**」
- **语义依据**：Gate B N-2（工单 §五）要求「原始候选数量 → 收敛动作 → 最终候选集合」**存在可恢复痕迹**
- **改法**（二选一）：
  - **A（实现侧，推荐）**：在收敛处产出可恢复痕迹——记录 `original_count` / `retained_count` / 被裁项标识，接入现有 Evidence / 审计通道（如 `THJAuditLog`）；报告给出位置
  - **B（如实降级）**：本阶段不做则报告改写为 `N-2 = NOT ESTABLISHED` 并登记待办，**不得**声称「日志可查 / 留待办队列」
- **验收标准**：N-2 结论与代码一致；若保留原结论，代码中须存在可验证的痕迹产出点
- **证据要求**：源码位置 + 覆盖该收敛的原始运行日志
- **阻塞他仓**：否

---

## 二、非阻断项（建议同批处理）

| # | 项 | 事实 | 改法 |
|---|---|---|---|
| B-R1-N1 | 报告 §四 称「公共层提供的 `CreateWildcard`」 | **该 API 不存在**。公共层 `TEhaiAuthorityBasis` 只有 `CreateExplicit`/`CreateStanding`/`CreateRuleDerived`（DeepBase `Core/DeepBase.EHAI.Types.pas:131/132/134`）；通配经 `ScopeBoundary = '*'` 表达（`:357`） | 改写为「公共层以 `CreateStanding(...,'*',...)` 表达通配；AXIS 未以 `'*'` 调用任一构造器」 |
| B-R1-N2 | 报告 §七 称 `FContactDB1` | 该符号在所有 `.pas` **零命中**（仅存在于报告自身） | 改引真实符号或以可 grep 的模块路径表述 |
| B-R1-N3 | 报告 §八「0 Error, 0 Warning」 | 编译日志实含 1 条 Hint：`HJF0.Audit.pas(141) Hint: H2077 Value assigned to 'THJAuditLog.Append' never used` | 注明「1 Hint（H2077）」；后续清理该无用赋值 |
| B-R1-N4 | 未登记 `working tree status` 台账（工单 §三 要求） | 报告仅一句「0 dirty」 | 补齐台账（与 B-R1-1 一并修正） |

---

## 三、交付与复审

```text
1. 完成上述整改
2. 干净工作区重跑：HJF0 回归 + Tier C 专项
3. 归档新原始日志（build / hjf0 / tierc 各一）
4. isolated commit（仅 DeepAxis 仓，不得夹带既有 686 条脏区）
5. 提交：DEV COMPLETE — READY FOR INDEPENDENT REVIEW
6. 主控复审 → 复审通过前 AXIS Integration Ready 维持 NO
```

**交付必须含**：Commit SHA / Parent SHA / Changed Files / ±行数 / 三份新日志路径 / 逐项整改对照表

---

## 四、硬前置

| 项 | 状态 |
|---|---|
| DeepBase `fc213b4` 冻结 | ✅ 已核实未变，本工单**不得**触碰 |
| DeepAxis 既有 686 条脏区（含 `HJF0.Capability.pas`、`DeepAxisTestRunner.dpr`、`DeepAxis.Tests.Commerce.pas`） | 已核实为**开工前既有**，与本次承接无关；**不得**卷入本工单提交 |
| `src/core/DeepAxis.Binding.EHAI.pas` / `HJF0.Authorization.pas` | ✅ 已核实干净，与产出日志对应 |
