# WO-20260921-AUDIT-乙-P1 — cwd 路径依赖裂缝与存量失败收口

- **工单号**：WO-20260921-AUDIT-乙-P1
- **发出时间**：2026-09-21 23:0x +0800
- **发出人**：主控 AI
- **承接方**：开发 AI 乙
- **取证基线**：DeepBase HEAD = `20493c6`
- **工单性质**：**新开发（测试基础设施 + 存量缺陷收口）**，源自《主控对乙 P0（HEAD 编译断裂修复）的独立取证与验收结论》§三-3 / §六。
- **前置依赖**：**无**（乙 P0 已 ACCEPTED，全量套件已恢复可跑）。
- **上游依据**：`CodeReview\20260921-AUDIT-主控-乙-P0-验收结论.md`｜`CodeReview\20260921-AUDIT-乙-P0-HEAD编译断裂修复-请求审核报告.md` §四-3/§六｜`TestResults\head-tests.log`（错误 cwd）/`head-tests-repo.log`（仓库根 cwd）

---

## 一、任务

### P1【cwd 路径依赖裂缝收口 —— 15 处】

**实测证据（主控逐名核验，非采信乙自述）**：

同一 exe、同一二进制，仅改 cwd：

| 运行 cwd | Found | Passed | Failed | Errored | 证据 |
| :--- | ---: | ---: | ---: | ---: | :--- |
| `.tmp/head-archive/Tests/`（错误） | 4625 | 4603 | **6** | **12** | `TestResults/head-tests.log` |
| 仓库根（正确） | 4625 | 4617 | **3** | **1** | `TestResults/head-tests-repo.log` |

**错误 cwd 独有 = 15 项**（与代码回归无关，纯 cwd 依赖）：

- `Test.DeepBase.DesignTime.Registration.TDesignTimeRegistrationTests.*`（失败 3 + 报错 4 = **7**）
- `Test.DeepBase.HB.Benchmark.TTestHbBenchmark.*`（报错 **7**：Gate1–6 + `BenchmarkTouchpointAggregation`）
- `Test.DeepBase.Performance.TTestConfigPerformance.Benchmark_ConfigWrite`（失败 **1**）

**根因**：测试用 `GetCurrentDirectory` / `TPath.GetFullPath` 解析**仓库内相对路径**（如 `Examples\HbColdStartProbe\`、`VCL\DeepBase.VCL.Controls.pas`），仅在「exe 位于仓库根」时成立。

**改法（唯一定稿）**：
1. 统一改为**基于可执行文件位置**（`ParamStr(0)` / `TPath.GetDirectoryName(ParamStr(0))`）或**仓库根探测**（向上找 `.git` / 标志文件）解析，**禁**依赖进程 cwd；
2. 收敛为**单一 helper**（避免 15 处各写一份）；若已有同类 helper，复用之；
3. `Tests/Examples/HbColdStartProbe/` 与仓库中实际存在的**根级** `Examples/` 路径映射须一并对齐。

**验收判据**：把 exe 放在**任意 cwd**（含 `.tmp/…/Tests/` 与仓库根两处）运行，**两者 Failed/Errored 集合一致**；且不再出现 `Probe build.ps1 missing` 类报错。附两处 cwd 的完整 stdout + NUnit XML。

### P2【存量失败收口 —— 3 项（1 项可移植既有修复）】

**P2-a｜`Desktop.Perception.BitmapSource` 2 红（★ 优先复用既有修复，禁从零诊断）**

- 失败项：`TBitmapSourceTests.StaticPair_InjectedReplay_Unchanged`、`TBitmapSourceTests.InjectedBitmap_FlowsThroughFrameDifferGate`。
- **主控已定位既有修复**：commit **`de8d989`**「fix(perception): BUG-449 FrameDiffer FLast/LLastShot 双状态解耦 — L0 闸门首帧外显 seed」（2026-07-23），改 `Features\DeepBase.Desktop.Perception.Engine.pas`（+10/−2），**仅在分支 `feat/wyjx-colormatch-canary`，未并入 master**。
- 已记录根因：`Engine.CaptureScreen` 闸门把首帧隔离在 `IsChanged` 外 ⇒ `TFrameDiffer.FLast` 永 Empty ⇒ 次帧 seed 恒判 changed。
- **要求**：先**读 `de8d989` diff**，判断可否直接移植（cherry-pick / 等价改写）；若可，按同语义在 master 落一处最小修复并复跑该 fixture；若发现 master 侧上下文已漂移不可直接移植，**报主控**说明差异，**禁**为绿灯改断言或改生产语义。

**P2-b｜`Resilience.Timeout.PBT` AV（独立诊断）**

- 失败项：`TTimeoutPolicyPropertyTests.Property6_TimeoutCancelsBackgroundTask`，症状 `Access violation … Read of address 0x0`（空指针读）。
- 本项**无既有修复线索**，须独立诊断根因（线性定位到具体行），给出「是测试自身缺陷 还是 生产缺陷」的判断。
- **红线**：不得为绿灯删测试 / 降断言 / 加 `{$IFDEF}`。若判为生产真缺陷，**报主控**另单，不在本单擅改生产语义。

---

## 二、禁止项

1. **禁**为「编过/跑绿」加 `{$IFDEF}` 开关、注释测试、降级断言（H8）。
2. **禁**触碰他方未跟踪件与甲域在途文件（`.workbuddy/*`、`Crypto.*`、`HB.*` 等）。
3. **禁**用 `checkout --` / `restore` / `reset --hard` 处置非本单改动。
4. **禁**在 `Tests/DeepBaseTests.dpr` 上与他方并发改动（甲 R8-P2 亦改该文件）⇒ **改 `.dpr` 前须报主控**，由主控串行化（H16）。

---

## 三、随单收口（乙 R7 剩余项，不单列阻塞）

1. **C3/C4 澄清**：R7 回执结束时间（00:20 vs 04:05）、基线（`0c1b00b` vs `ef1b414`）各一句如实说明。
2. **归档删除口径对齐**：3 件归档重复删除现为**未暂存工作树删除**（` D`）；README 为 ` M`。物已合格（老板授权、零内容损失），提交时按 **P1（守卫）/ P2（删除）分次原子提交**，每次 `--only` + 前后 `git diff --cached --name-only` 双空。

---

## 四、交付物

1. 精确 pathspec 的 commit（P1 / P2 / 随单收口分次）。
2. 回执：`CodeReview\20260921-AUDIT-乙-P1-交付回执.md`。
3. 证据：`CodeReview\20260921-AUDIT-乙-P1-证据\`（两处 cwd 复跑日志 + NUnit XML + 门禁 EXIT 输出）。

---

## 五、是否阻塞他仓

**否**（本仓测试基础设施 + 存量缺陷）。但 P1 完成后，「同一 exe 在任何 cwd 下结论一致」成为硬保证，可移除后续所有验收的 cwd 前提交互成本。

---

## 六、排队（主控自决）

- **乙队列**：本单 → Top20-08（Commerce 权益消费，资金类）⇒ 解锁 **#08**。
- **H16**：开工前若发现他方暂存，停写报主控。

---

*主控 沈予安 ｜ 2026-09-21 23:0x 建单 ｜ 基线 HEAD `20493c6`*
