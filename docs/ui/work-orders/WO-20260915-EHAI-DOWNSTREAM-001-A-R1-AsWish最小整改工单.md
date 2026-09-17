# WO-20260915-EHAI-DOWNSTREAM-001-A-R1 · AsWish 最小整改工单

> **来源**：主控独立审核裁定 `AsWish Verdict = HOLD / Integration Ready = NO`
> **审核结论全文**：`CodeReview/20260915-EHAI-DOWNSTREAM-001-A-AsWish独立审核结论.md`
> **Owner Repo**：`AsWish`（`D:\_Progs\02Business\AsWish`）——**本工单只动 AsWish**
> **禁止**：修改 DeepBase / EHAI SSOT / AXIS；借机重构；扩充范围
> **基线**：承接提交 `618508f39c5dce7e7bc1de29a2eafb18f73c5af8`，DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`

---

## 一、整改项（3 项，全部属 Evidence 维度）

### A-R1-1｜消除恒真断言，让 N-1 的证据与其声明同形态

- **文件:行**：`tests/Test.AsWish.EHAI.Binding.pas` → `ASWISH_V_012_GateB_N1_To_N6_Invariants` 内 `// N-1:` 下方一行
- **现状**：
  ```pascal
  Assert.AreEqual('AsWish', 'AsWish', '...TEhaiAuthorityScope wildcard is NOT USED');
  ```
  实参自反 → 恒真 → 不构成断言
- **改法**（二选一）：
  - **(推荐)** 替换为**实质断言**：验证 AsWish 公共消费路径产出的授权作用域恒为具体标识（非 `'*'`、非空），并对空/通配两种输入断言被拒绝；或
  - 删除该行，改以**工件证据**呈现：归档 `git grep -n "'\*'"` 原始输出为证据文件，报告段落改写为「源码级检索证实（见证据 §X）」，**不再声称有测试断言**
- **验收标准**：`ASWISH_V_012` 中不存在任何实参自反的 `Assert`；N-1 的证据形态与报告声明一致
- **证据要求**：修正后源码 + 重跑原始日志（含该用例）+ 报告 §六 AsWish-N1 段落改写
- **阻塞他仓**：否

### A-R1-2｜四个 N 项的断言与标签对齐

- **文件:行**：同上，`ASWISH_V_012` 函数体
- **现状与改法**：

  | 项 | 现状断言 | 问题 | 改法 |
  |---|---|---|---|
  | N-2 | 无断言（仅注释） | 无证据 | 见 A-R1-3 |
  | N-3 | `Assert.IsTrue(LCSId.StartsWith('cs-'))` | 只证 ID 前缀格式 | 改为对重复/并发绑定同一 `ChangeSetId` 的**错绑免疫**断言；或如实改写为「AsWish 以 `ChangeSetId` 而非瞬时 Key 寻址（源码位置：____），该风险不适用」 |
  | N-4 | `Assert.IsTrue(FController.AcceptChangeSet(...))` | 断言的是承诺成功，与确定性无关 | 改为**真实确定性断言**：同一输入重复执行 → Trace / 基线指纹逐字节相等 |
  | N-6 | `Assert.IsTrue(FController.VerifyBaseline(...))` | 未涉及 `ExpiresAt` 语义 | AsWish 无期限字段时**如实标注 `NOT APPLICABLE`**，不得挂测试名 |

- **验收标准**：每个 N-x 的断言与其标题语义**直接对应**；无法测的项标 `NOT APPLICABLE`
- **证据要求**：修正源码 + 重跑原始日志
- **阻塞他仓**：否

### A-R1-3｜AsWish-N2 补证据（或如实降级）

- **文件:行**：交付报告 `WO/WO-20260915-EHAI-DOWNSTREAM-001-A-AsWish-Gate-C-交付报告.md` §六 `AsWish-N2`
- **现状**：整段为纯文字，无文件:行、无测试指针、无产物 —— 违反工单 §十二「不得只写'应该没有'」
- **改法**（二选一）：
  - 给出「候选生成 → 进入 Choice Deck」全路径的**源码位置**，证明不存在 >7 截断点；或
  - 若存在截断点，按 N-2 要求实现**可恢复的收敛痕迹**并给出位置
  - 若两者皆难，**如实写 `NOT ESTABLISHED`** 并登记为待办
- **验收标准**：N-2 结论附源码位置或产物证据，或明确标 `NOT ESTABLISHED`
- **证据要求**：源码引用 + 原始输出（grep / 运行日志）
- **阻塞他仓**：否

---

## 二、非阻断项（建议同批处理，不强制）

| # | 项 | 建议 |
|---|---|---|
| A-R1-N1 | 编译证据仅 3 行，无 exit code / Warning 计数行 | 归档时补 exit code；措辞改为「日志中无 Error/Warning 行」 |
| A-R1-N2 | 语义矩阵未单独展开覆写三态（`eokNone`/`eokCandidateReject`/`eokAlternativeExpression`/`eokFrameRejection`）互斥 | 留待 Phase C 判断，**本工单不要求** |

---

## 三、交付与复审

```text
1. 完成上述整改
2. 重跑：全量回归 + Gate C 定向用例
3. 归档新原始日志（build / test 各一）
4. isolated commit（仅 AsWish 仓，不得夹带既有 11 条 untracked）
5. 提交：DEV COMPLETE — READY FOR INDEPENDENT REVIEW
6. 主控复审 → 复审通过前 AsWish Integration Ready 维持 NO
```

**交付必须含**：Commit SHA / Parent SHA / Changed Files / ±行数 / 新原始日志路径 / 逐项整改对照表

---

## 四、硬前置

| 项 | 状态 |
|---|---|
| DeepBase `fc213b4` 冻结 | ✅ 已核实未变，本工单**不得**触碰 |
| AsWish 既有 11 条 untracked | 已核实为开工前既有，**不得**卷入提交 |
