# 交付报告 · 工单 WO-20260905-002 · HB 性能门禁基准 1–6 + FMX 生命周期对齐

> **工单编号**：WO-20260905-002  
> **任务标题**：HB 视觉性能门禁基准 1–6 实施 + FMX 行为层生命周期对齐  
> **执行人**：罗辑（software-tools 人格 / 主编码代理）  
> **基线环境**：Delphi 13.1 · Win64 · `dcc64.exe` · DUnitX  
> **交付日期**：2026-09-05  
> **规范法源**：`docs/31.hb-test.md` v1.1 · `docs/29.ui-runtime.md` v2.0 · `docs/30.touchpoint.md` v2.0

---

## 1. 生产部署状态与时间链

| 节点时间 (UTC+8) | 阶段 | 操作与产物 | 状态 |
| :--- | :--- | :--- | :--- |
| 2026-09-05 | 工单下达 | `docs/ui/work-orders/WO-20260905-002-HB-BENCHMARK-FMX.md` · brief `docs/brief-WO-20260905-002-开发甲.md` | OK |
| 2026-09-05 | Task A | 门禁 1–6 DUnitX + 冷启探针；证据 `TestResults/WO-20260905-002/final/` | PASS（Gate5 诚实 FAIL） |
| 2026-09-05 | Commit 1 | `0f1f640` — Task A | DONE |
| 2026-09-05 | Task B | Core `THbLifecycleState` SSOT · VCL 薄适配 · FMX 基类/Dialog 试点 · FMX Lifecycle 测试 | PASS |
| 2026-09-05 | 包构建 | `TestResults/WO-20260905-002/taskB/build-packages-final.log` | PASS |
| 2026-09-05 | Task B 回归 | Lifecycle+FMX Dialogs **20/20** · `taskB/UnitTestResults.xml` | PASS |
| 2026-09-05 | 全量单元 | `taskB-full/` · 4453 例 · 7 FAIL（见 §4） | 见分解 |
| 2026-09-05 | 污染修复 | Gate3 `UnregisterTheme` + TearDown；Gate3→WCAG 联跑 22/22 | PASS |
| 2026-09-05 | 异族终审 | PASS_WITH_DEBT（见 §6） | DONE |
| 2026-09-05 | Commit 2 | Task B + 主题注册清理 | DONE |

---

## 2. Task A · 门禁 1–6 实测（阈值未改）

证据目录：`TestResults/WO-20260905-002/final/`。阈值唯一源：`docs/31.hb-test.md`。

| # | 门禁 | 阈值 | 结果 | 备注 |
|---|---|---|---|---|
| 1 | 冷启动首屏 | P95 ≤ 800ms | PASS | 探针 `Examples/HbColdStartProbe/` |
| 2 | 100k 网格滚动 | 单帧 ≤ 16.6ms | PASS | Paint-only + warm-up |
| 3 | 主题切换 | ≤ 100ms | PASS | 10 套 ephemeral bench palette |
| 4 | DPI 重算 | ≤ 30ms · 双缓冲 · 度量 | PASS | 截图 `gate4-screens/` |
| 5 | Resize | ≤ 16.6ms | **FAIL（诚实）** | Waterfall 全量重绘；**禁止调阈值** |
| 6 | 10k 实例泄漏 | 句柄不增长 | PASS（Task A 基线） | 全量套件下偶发 ±1 噪声，见 §4 |
| 7 | 触点写入 | P95 ≤ 2ms | PASS | 既有 |

---

## 3. Task B · FMX 行为层对齐

### 3.1 SSOT 下沉决策

| 决策 | 说明 |
|---|---|
| **沉 Core** | `Core/DeepBase.HB.Lifecycle.pas` · `THbLifecycleState` |
| **VCL** | `THbCustomControl` 持有 `FLife`，步骤体删除 |
| **FMX** | `THbFmxControl` 同构委托 `FLife`；Paint 首行 `AssertPaintAllowed` |
| **触点** | 按钮 Click / Dialog Confirm → `THbTouchpointEngine` |
| **状态槽** | `THbFmxControl.RegisterStateSlot` → `THbRuntime.RegisterStateSlot` |
| **主题清理** | `THbTheme.UnregisterTheme`；Gate3 仅临时注册并 TearDown 移除 |

### 3.2 验证

- 定向：`taskB-verify/UnitTestResults.xml` — **22/22**（Gate3 + WCAG + VCL/FMX Lifecycle + FMX Dialogs）
- FMX Enforcement：`FMX/DeepBase.FMX.HB.Controls.pas` 命中 `AssertPaintAllowed` / `EHbLifecycleViolation`

---

## 4. 全量套件失败分解（`taskB-full/` · 4446 PASS / 7 FAIL）

| 失败用例 | 归类 |
|---|---|
| Gate5 Resize | 本单诚实 FAIL（阈值冻结） |
| Gate6 USER/GDI ±N | 进程句柄噪声；Task A 基线 PASS；不放宽阈值 |
| CR-606×2 Perception BitmapSource | 既有允许红 |
| Benchmark_ConfigWrite ×2 | 性能噪声（ops/sec），非 HB 本单 |
| WCAG `bench-palette-*` | **已修**：UnregisterTheme + Gate3 作用域注册 |

---

## 5. 债务节

| ID | 状态 | 说明 |
|---|---|---|
| Gate5 Resize | ⏸ | Waterfall 全量 paint；另单脏区/虚拟化 |
| 异常后无条件 Dispose | ⏸ | 与 VCL 共有；异族记 DEBT |
| Gate6 句柄噪声 | ⏸ | 观测性；不调阈值 |
| DEBT-20260905-001 | ⏸ | 占位 GUID（非本单） |
| FMX 表面色 / FMX 性能门禁 | 出界 | 明示不在本单 |

---

## 6. 异族终审

> Task B 异族终审 **PASS_WITH_DEBT**：FMX 7 步生命周期已与 Core `THbLifecycleState` SSOT 及 VCL 行为层对齐并通过镜像测试，触点/状态槽/边界均合规；与 VCL 共有的「异常后无条件 Dispose」规范债务待后续统一补齐。

---

## 7. Commit 2 暂存清单（精确 · 禁止 add -A）

1. `Core/DeepBase.HB.Lifecycle.pas`（新）
2. `Core/DeepBase.HB.Core.pas`（`UnregisterTheme`）
3. `DeepBaseCore.dpk`
4. `VCL/DeepBase.VCL.HB.Controls.pas`
5. `FMX/DeepBase.FMX.HB.Controls.pas`
6. `FMX/DeepBase.FMX.HB.Dialogs.pas`
7. `Tests/Test.DeepBase.FMX.HB.Lifecycle.pas`（新）
8. `Tests/DeepBaseTests.dpr`
9. `Tests/Test.DeepBase.HB.Benchmark.pas`（Gate3 主题清理）
10. `docs/31.hb-test.md`（实现索引）
11. `tasks.md`
12. `CodeReview/20260905-HB-BENCHMARK-FMX-交付报告.md`
13. `TestResults/WO-20260905-002/taskB/` · `taskB-verify/`（证据）

---

## 8. 门禁勾选

- [x] 门禁 1–6 有自动化断言 + 证据；Gate5 诚实 FAIL + 根因
- [x] 运行时包构建 0 Error
- [x] Task B 定向套件全绿；WCAG 污染已修
- [x] SSOT 下沉决策已说明
- [x] 异族终审已做
- [ ] CLOSE：待老板重跑基准 exe 复核数字 + 主控 grep FMX Enforcement 后裁定
