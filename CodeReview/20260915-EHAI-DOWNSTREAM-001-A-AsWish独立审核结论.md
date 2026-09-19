# WO-20260915-EHAI-DOWNSTREAM-001-A · AsWish Gate C 独立审核结论

- **审核方**：主控 AI（独立审核，不采信开发结论）
- **审核对象**：`WO-20260915-EHAI-DOWNSTREAM-001-A` / Owner Repo = `AsWish`
- **审核基准**：DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`（未变，已复核）
- **审核方式**：Git 对象 + 源码 + 原始日志 + grep 独立取证（开发报告仅作导航）
- **审核时间**：2026-09-15

---

## 〇、裁定

```text
AsWish Verdict            = HOLD
AsWish Integration Ready  = NO
Blocking Findings         = 3（全部属 Evidence 维度）
Non-Blocking Findings     = 2
```

> 依据工单 §二十五：Blocking 判定条件含 **Evidence**；`Tests PASS ≠ Integration Ready`（§二十四）

---

## 一、已独立证成的事实（✅）

| # | 声明 | 我的取证 | 结论 |
|---|---|---|---|
| 1 | Starting HEAD `d5fce9b9…` → Ending `7af59e4e…` | `git log`：`7af59e4e` ← `618508f3` ← `d5fce9b9` 父子链逐字吻合 | ✅ |
| 2 | 核心测试提交 `618508f3`、报告归档 `7af59e4e` | 两个对象均存在，`git cat-file -t` = commit | ✅ |
| 3 | 3 files changed / +2425 / −1 | `git show --stat` 完全一致 | ✅ |
| 4 | **跨仓隔离** | 两提交仅触碰 `WO/`、`tests/` —— 零 DeepBase、零 AXIS 路径 | ✅ |
| 5 | DeepBase 未被修改 | HEAD 仍为 `fc213b4…`，与声明基线一致 | ✅ |
| 6 | isolated commit（不夹带既有脏区） | 开工前 11 条 untracked 至今仍 untracked，**未被卷入提交** | ✅ |
| 7 | 回归 236/236 PASS | 原始日志尾部：`Tests Found 236 / Ignored 0 / Passed 236 / Leaked 0 / Failed 0 / Errored 0` | ✅ 从原始日志证实 |
| 8 | ASWISH-V-001～012 全部执行 | 12 个用例名各出现 4 次（声明/Setup/执行/Teardown） | ✅ 真实跑过 |
| 9 | 语义矩阵 10 行的 Test Evidence 指针 | 逐条比对，10 行指向的用例名均真实存在且语义相符 | ✅ |
| 10 | N-4 结论「AsWish 内部不调用 `Covers()`」 | `git grep "Covers("` 全仓 `.pas` **零命中** | ✅ 源码级证实 |
| 11 | N-5 结论「无 Contact List 概念」 | 全仓 grep 仅命中报告自身文本，代码零命中 | ✅ 源码级证实 |
| 12 | N-1 结论「通配 `'*'` NOT USED」 | 全仓仅命中一处**注释**，无 `AuthorityBasis` 类型、无 `'*'` 赋值 | ✅ 结论为真 |

---

## 二、Blocking Findings（阻断：Evidence 维度）

### A-B1｜`ASWISH_V_012` 的 N-1 断言是**恒真式**，不构成任何断言

**位置**：`tests/Test.AsWish.EHAI.Binding.pas`（`ASWISH_V_012_GateB_N1_To_N6_Invariants`）

```pascal
// N-1: Wildcard Authority Scope '*' is NOT USED in AsWish.
Assert.AreEqual('AsWish', 'AsWish',
  'AsWish does not model external execution dispatch; TEhaiAuthorityScope wildcard is NOT USED');
```

**问题**：`Assert.AreEqual` 的两个实参是**同一个字符串字面量** `'AsWish'` → 恒真。该断言的**通过与他要证明的命题（通配未使用）之间没有任何逻辑关系**。第三个参数只是失败时的消息文本，不参与判定。

**而交付报告 §六 AsWish-N1 写的是**：

> 结论：**NOT USED**（通过 `ASWISH_V_012` **实测断言**）

→ **报告援引的"实测断言"不存在。** 「NOT USED」这个结论本身为真（我已用 grep 源码级证实，见 §一 第 12 项），但**支撑它的证据是空的**。

**改法**：把该行替换为真实断言，二选一：
- **（推荐）源码级断言**：新增一个断言验证 AsWish 公共消费路径不存在 `'*'` 或等价全授权构造（例如断言业务工厂产出的 `ScopeBoundary` 恒为具体 ID、且不等于 `'*'`）；或
- **工件级证据**：把 `git grep -n "'\*'"` 的原始输出归档为证据文件，并在报告中改为「源码级检索证实（见证据 §X）」——**不得**再声称有测试断言

**验收标准**：`ASWISH_V_012` 中不存在任何"实参相等"的自反断言；N-1 的证据形态与声明一致
**证据要求**：修正后的测试源码 + 重跑原始日志（含该用例）+ 报告对应段落改写
**是否阻塞他仓**：否（纯 AsWish 仓内）

---

### A-B2｜`ASWISH_V_012` 的 N-2 / N-3 / N-4 / N-6 断言与标签不符

**位置**：同上（`ASWISH_V_012` 函数体）

| 报告声称 | 测试里实际的断言 | 问题 |
|---|---|---|
| N-2「无未记录的静默丢弃」 | **无断言**，仅一行注释 | 无证据 |
| N-3「Key 冲突免疫（`ASWISH_V_012` 实测通过）」 | `Assert.IsTrue(LCSId.StartsWith('cs-'))` | 只证了 **ID 前缀格式**，与「选 A 执行 B 免疫」无关 |
| N-4「基于内容 SHA256、不依赖实时时钟（`Deterministic = YES`）」 | `Assert.IsTrue(FController.AcceptChangeSet(LCSId, 'Deterministic commitment test'))` | 断言的是**承诺动作成功**，与确定性/时钟/SHA256 **无关** |
| N-6「未设期限语义恒为 Never Expires（`ASWISH_V_012` 实测通过）」 | `Assert.IsTrue(FController.VerifyBaseline(...))` | 断言的是**基线可验证**，未涉及任何 `ExpiresAt` 语义 |

**问题**：报告 §六 结论「N-1～N-6 全部澄清」与测试实体不符。这是典型的**用标签代替断言**——注释写了 N-x，断言的却是别的东西。

**改法**：
1. **N-3**：改为对同一 `ChangeSetId` 并发/重复绑定做断言，验证不会因 Key 冲突而错绑；或如实改写报告为「AsWish 以 `ChangeSetId` 而非瞬时 Key 寻址（源码位置：xxx），故不适用」
2. **N-4**：补一条真实确定性断言（**同一输入重复执行，Trace 指纹逐字节相等**）
3. **N-6**：AsWish 无 `ExpiresAt` 字段时，如实改写为 `NOT APPLICABLE（AsWish 无期限字段）` —— 而不是假装测过
4. **N-2**：见 A-B3

**验收标准**：每个 N-x 的断言与其标题语义直接对应；无法测的项**如实标注 NOT APPLICABLE**，不得挂测试名
**证据要求**：修正源码 + 重跑原始日志
**是否阻塞他仓**：否

---

### A-B3｜AsWish-N2 结论**无任何证据**，违反工单 §十二 明文禁令

**位置**：交付报告 §六 `AsWish-N2｜超过 7 个候选静默丢弃`

报告全文：

> AsWish 的候选方案由具体的 ChangeSet 驱动，交互 Deck 严格限定在 1..7 槽位；AsWish 内部接收到具体 Key 操作后定向审阅目标 ChangeSet，不存在未记录的候选在进入界面前被静默丢弃导致人类产生"只有这些"认知偏差的路径。

**问题**：
1. **零文件:行、零测试指针、零产物** —— 纯文字
2. 工单 §十二 A-6 对 N 系列明文规定：「不得只写'应该没有'」。此段正是标准形态的「应该没有」
3. §三十一 明文：「报告文字本身：**永远不是 PASS 证据**」

**改法**：二选一
- 给出 AsWish 侧「候选生成 → 进入 Deck」全路径的**源码位置**，证明不存在 >7 截断点；或
- 若确实存在截断点，按 N-2 要求实现**可恢复的收敛痕迹**并在报告中给出位置

**验收标准**：N-2 结论附源码位置或产物证据；无法证明时明确写 `NOT ESTABLISHED`
**证据要求**：源码引用 + 原始输出
**是否阻塞他仓**：否

---

## 三、Non-Blocking Findings（不阻断）

| # | 发现 | 影响 | 建议 |
|---|---|---|---|
| A-N1 | 编译证据 `build-ehai-downstream-001-A.txt` 仅 3 行，**无显式 exit code、无 Warning 计数行**；报告称「0 Error, 0 Warning」实为**缺席推断** | 可读性 / 证据完整性 | 归档时补一行 exit code；措辞改为「日志中无 Error/Warning 行」更严谨 |
| A-N2 | 语义矩阵把覆写三态（`eokNone` / `eokCandidateReject` / `eokAlternativeExpression` / `eokFrameRejection`）**压缩为 HumanOverride + FrameRejection 两行**，未单独验证三态互斥 | 可能遗漏语义边界 | 留待 **Phase C 跨产品复核**判断是否需要独立展开（非本阶段阻断项） |

---

## 四、整改要求（最小）

见独立子工单：`WO-20260915-EHAI-DOWNSTREAM-001-A-R1`（AsWish 最小整改工单）

```text
AsWish 整改完成
→ 重跑回归 + 归档新原始日志
→ 提交 isolated commit
→ 重新提交 DEV COMPLETE — READY FOR INDEPENDENT REVIEW
→ 主控复审（复审通过前 Integration Ready 维持 NO）
```

---

## 五、给上级 AI 的一句话

```text
AsWish 承接事实成立（提交链 / 隔离 / 236 回归 / 语义矩阵指针 均已独立证实）
但 N-1～N-6 专项的证据链存在 3 处阻断缺陷：
  恒真断言冒充实测断言 / 断言与标签不符 / N-2 纯文字无证据
→ HOLD，Integration Ready = NO，已开最小整改工单
```
