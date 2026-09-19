# WO-20260915-EHAI-DOWNSTREAM-001-A-R1 · AsWish 复审结论

- **审核对象**：`WO-20260915-EHAI-DOWNSTREAM-001-A-AsWish-Gate-C-交付报告.md`（R1 收口版）+ 提交 `bb7462c8079fca1ea63224e2af14a63fe23974e1`
- **上游基准**：DeepBase `fc213b4696d92bc8a836ef644abaeb74f0daa79e`（FROZEN，已核未碰）
- **送审工单**：`CodeReview/20260915-EHAI-DOWNSTREAM-001-A-AsWish独立审核结论.md`（前轮 HOLD）
- **复审方法**：不采信开发报告自述；逐项以 git 对象、源码原文、日志文件、公共层类型定义**独立取证**；对报告声称的 Commit SHA 做可解析性验证
- **复审人**：主控（Amy）
- **复审时间**：2026-09-16

---

## 一、结论（先行）

**A-R1 = CONDITIONAL PASS。**

- 前轮 3 项阻断（A-B1 / A-B2 / A-B3）**全部实质闭合**，非措辞替代；
- 新增断言经主控**类型级独立验证**可编译、语义成立；
- **未发生越界改动、未发生销毁性操作**（与 Phase B 形成对照），隔离纪律合规；
- 遗留 **1 项必改勘误**（E-1：证据锚点不可解析）+ 3 项登记性勘误。

> **Integration Ready = YES（待 E-1 勘误落地后生效）**
> E-1 属单行文档修正，不构成代码或证据缺陷，故不判 HOLD。

---

## 二、逐项闭合核对

| 前轮阻断项 | 判定 | 独立取证 |
| :--- | :---: | :--- |
| **A-B1** 恒真断言 `Assert.AreEqual('AsWish','AsWish')` | ✅ **已消除** | `git show bb7462c8 -- tests/Test.AsWish.EHAI.Binding.pas`：该行在 diff 中为删除态（`-`），替换为 `Assert.IsFalse(FBinding.ExecuteCommitmentGate('*',…))` / `('',…)` 等实质断言 |
| **A-B2** N-2/3/4/6 断言与标题语义错配 | ✅ **已闭合** | 现断言逐条对位：N-2 → 8 项 ChangeSet 往返断言 `Length=8`；N-3 → 双 ChangeSet 同 Key(1) 隔离断言；N-4 → `ReviewChangeSet` 逐字节相等 + Trace 五字段恒等；N-6 → 如实标 `NOT APPLICABLE` 且挂哈希完整性断言 |
| **A-B3** AsWish-N2 无证据（纯文字） | ✅ **已闭合** | 报告 §六 AsWish-N2 已给出全链路源码定位：`AsWish.Services.CandidateIngest.pas:216-310` / `AsWish.Controller.pas:1150-1285` / `AsWish.Binding.HB.pas:195-208`；并附 8 项实测 |

### 2.1 新增断言的类型级独立验证（主控自验，不依赖开发日志）

R1 的 build 日志为**摘要式**（7 行，非原始编译转录），不足以佐证编译。主控改为**逐符号核对**，确认新代码与公共层类型契约一致：

| R1 新代码使用的符号 | 公共层/绑定层定义位置 | 判定 |
| :--- | :--- | :---: |
| `THbChoiceAction.Create` 9 参重载 | DeepBase `Core/DeepBase.HB.Choice.Types.pas:144-150` | ✅ 存在 |
| `…Action.Context.ScopeBoundary` | DeepBase `Core/DeepBase.EHAI.Types.pas:126 / 148`（公共层继承，非 AsWish 私有） | ✅ 存在 |
| `ExecuteCommitmentGate` fail-closed 守卫 | AsWish `src/services/AsWish.Binding.HB.pas:274 / 297` | ✅ 已加 |
| `TAsWishCandidateIngest` / `SaveChangeSet` / `LoadChangeSet` | AsWish `src/services/AsWish.Services.CandidateIngest.pas` | ✅ 存在 |

> 结论：新断言**语义成立且类型可编译**。日志无法绑定到 R1 修订（见 E-3），故「236/236 PASS」不作为新断言有效的证据，改由源码审读 + 类型核对独立确认。

### 2.2 通配检索证据复核

`WO/evidence/git-grep-wildcard-aswish.txt` 实测 4 处命中，逐条良性：

| 命中位置 | 内容 | 判定 |
| :--- | :--- | :---: |
| `AsWish.SettingsProvider.pas:109` | `PasswordChar := '*'`（密码掩码） | 无关 |
| `AsWish.Binding.HB.pas:274` | 新增 fail-closed 守卫 | 防御性 |
| `AsWish.Binding.HB.pas:297` | 新增 fail-closed 守卫 | 防御性 |
| `AsWish.Services.Snapshot.pas:75` | `UnsafeChars` 集合含 `'*'`（路径非法字符） | 无关 |

报告 §六 line 88「全仓源码仅 4 处命中……零通配构造与调用」**陈述与证据完全一致**。

### 2.3 隔离纪律

| 项 | 报告声明 | 独立核实 | 判定 |
| :--- | :--- | :--- | :---: |
| R1 提交 | — | `bb7462c8`，6 files，+2483 / −39 | ✅ |
| Parent | `7af59e4e` | `git log` 父链 `bb7462c8 ← 7af59e4e ← 618508f` | ✅ |
| 夹带 | 未夹带 11 条 untracked | `git status --porcelain` 计 11 条 `??`，提交清单无一条 | ✅ |
| 跨仓 | 未碰 DeepBase / AXIS | DeepBase `HEAD = fc213b4` 未变 | ✅ |

---

## 三、勘误项

| # | 项 | 事实 | 处置 |
| :---: | :--- | :--- | :--- |
| **E-1** | 报告 §九 声明 `R1 Commit SHA: 41471c8b974030c041e281d9e1bdf9466998a43d` | 该 SHA **不是 `main` 上的 R1 提交**。经 `git reflog` 证实其为 **amend 前提交**（`commit (amend)` 覆盖为 `bb7462c8`），`git branch -a --contains 41471c8b` **为空**（不可达，仅存 reflog，`gc` 后即失）。实际 R1 提交 = `bb7462c8` | **必改**：改为 `bb7462c8…`，或补注「本报告随 `bb7462c8` 交付」 |
| E-2 | 报告 §九 `2480 insertions(+), 39 deletions(-)` | 实际 `2483 / 39`（差 3 行） | 登记修正（amend 自指伪影） |
| E-3 | 测试日志 `tests-ehai-downstream-001-A-R1.txt` | 与前轮 `tests-ehai-downstream-001-A.txt` **逐字节相同，仅追加 3 行**（空行 ×2 + `Exit Code: 0`）。DUnitX 日志无时间戳、测试名集合未变（均 236），字节相同**属正常**；但该日志因此**无法自证新断言被执行** | **登记说明**：报告不得以「236/236 PASS」宣称新断言通过执行验证 |
| E-4 | build 日志为 7 行摘要 | 无编译命令行、无逐单元输出，非原始转录；对比 AsWish 前轮日志（4 行，无 exit code），R1 已补 exit code 与 0/0/0 计数，属**改进** | 登记（下轮起要求存档原始编译器 stdout） |

---

## 四、审核纠偏记录（主控自省）

本轮中途曾形成两项假设，经复核**被证伪**，如实登记以免误导后续审计：

| 中途假设 | 证伪依据 |
| :--- | :--- |
| 「报告声称通配命中 **0 处**，与证据 4 处矛盾」 | **误读**。报告 §六 line 88 原文即写「仅 4 处命中」并逐条解释，二者一致 |
| 「报告引用了不存在的路径 `src/services/CandidateIngest.pas` 等」 | **误读**。报告原文路径带 `AsWish.` 前缀且目录正确（`src/services/AsWish.Services.CandidateIngest.pas`） |

> 教训：审计中「报告声明 × 证据」比对必须**逐字取自 git blob**，不可凭记忆或摘要转述结论——本轮两处误判均源于对报告的转述记忆而非原文。

---

## 五、裁定与下一步

```text
AsWish A-R1 复审裁定：
  前轮 3 项阻断：全部实质闭合（源码级独立验证）
  类型可编译性：主控独立核对通过
  隔离纪律：合规（未越界、未夹带、未销毁）
  遗留勘误：E-1 必改；E-2/E-3/E-4 登记

  Verdict            = CONDITIONAL PASS
  Integration Ready  = YES（E-1 勘误提交后生效）
```

**前置动作（开发甲）**：仅需对报告 §九 提交一行勘误（E-1），可随 Phase C 前的任一提交附带，不单开工单。

**Phase C（跨产品抽象复核）**：待 AXIS B-R1 一并转正后解锁——**现仍 LOCKED**（见 B-R1 复审结论）。
