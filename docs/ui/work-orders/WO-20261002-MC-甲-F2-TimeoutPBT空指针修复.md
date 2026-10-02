# WO-20261002-MC-甲-F2 TimeoutPBT 确定性空指针修复（主控派单 · P1）

**单号**：`WO-20261002-MC-甲-F2`
**派单**：主控（2026-10-02，`WO-20261002-MC-甲-TESTDEBT-R01` ACCEPTED 派生）
**优先级**：**P1**（全量套件现存红，主套件即红）
**前置**：`CodeReview/20261002-AUDIT-主控-四单验收结论.md` §三.1
**授权面**：`Tests/Test.DeepBase.Resilience.Timeout.PBT.pas`、`Core/DeepBase.Resilience.Timeout.pas`、`Core/DeepBase.ManagedWorker.pas`
**禁动区**：`contracts/**`、`noise-baseline.json`、`Scripts/**`

---

## 〇、纪律与口径

1. 零信任：判据全部主控在隔离 `--detach` 树亲跑留档。
2. 一笔 H15 原子提交，message 带单号，显式 pathspec，选项在 `--` 前，禁 push。
3. 台账状态槽改写权归主控。
4. **先取证后修**（DA-131B 教训）：修前留档当前红读数，再动代码。

---

## 一、现象与主控亲验根因（已逐行亲读，0 号推断）

`Tests/Test.DeepBase.Resilience.Timeout.PBT.pas` 在全量套件下红。

**代码链（主控逐行亲读）**：

| 步 | 位置 | 内容 |
|---|---|---|
| 1 | `Core/DeepBase.Resilience.Timeout.pas:98-112` | `Worker := TManagedWorker.Create(...)`；`Worker.Start`；`Worker.Wait(FTimeoutMs)` |
| 2 | `Core/DeepBase.ManagedWorker.pas:37` | `TCoreThread = class(TThread)` —— **不是 `TTask`** |
| 3 | `Tests/Test.DeepBase.Resilience.Timeout.PBT.pas:240` | `TTask.CurrentTask.CheckCanceled;` |
| 4 | 同文件 `:33-38` | 前提注释自证「`TTimeoutPolicy` is purely Delphi RTL: `TTask` + `ITask.Cancel`…」 |

**根因**：`:240` 用 `TTask.CurrentTask` 观察取消，但被测路径跑的 worker 是
`TCoreThread = class(TThread)`。在 `TTask` 之外的线程上下文里 `TTask.CurrentTask`
返回 nil ⇒ `CheckCanceled` 打空指针。这是**确定性**缺陷，非竞态噪声
（超时常量 `:215` `CTimeoutMs = 50`）。

---

## 二、判据（主控验收用，逐条亲跑）

| # | 判据 | 达成标准 |
|---|---|---|
| 1 | 修前取证 | 隔离树 `--detach` 跑该 fixture，留档当前红读数（含堆栈/错误码） |
| 2 | 该 fixture 转绿 | `Tests Failed: 0` 且 `Tests Errored: 0`，`RUN_EXIT=0` |
| 3 | 零回归 | `Tests/Test.DeepBase.Resilience.pas`、`Tests/Test.DeepBase.Resilience.CircuitBreaker.PBT.pas`、`Tests/Test.DeepBase.MVVM.pas` 读数不劣于修前 |
| 4 | 全量套件 | `Scripts/run_tests.ps1 -Type Unit -CI -Platform Win64` 无新增红 |
| 5 | 修法取向 | 优先在夹具侧改观察机制（对 `TCoreThread` 用其自身取消接缝）；**只有当确无接缝可依时**才动 `Core/DeepBase.ManagedWorker.pas` 公开签名，动则须另立契约登记 |
| 6 | 四门 | eol / encoding / mojibake / evidence-encoding 全 EXIT=0，噪声不劣于 `noise-baseline.json` |
| 7 | 交付纪律 | 一笔 H15，显式 pathspec，未 push |

**验收前置**：判据 1 必须先于判据 2，否则视为无红绿对照，不予验收。

---

## 三、不在本单

1. `A5R03Wide` 那 4 例既存红 —— 归 `WO-20261002-MC-甲-A5R03`，两单不得并改同一文件时合并。
2. 主树陈旧 DCU 清理 —— 归 `WO-20261002-MC-主控-DCU`。
3. 噪声基线抬升 —— 非本单目标；确需抬升须单独立项并说明理由。
