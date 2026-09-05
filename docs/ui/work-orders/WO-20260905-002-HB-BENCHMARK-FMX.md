# 工单 WO-20260905-002 · HB 视觉性能门禁基准 1–6 实施 + FMX 行为层生命周期对齐（罗辑）

> **指派对象**：罗辑（software-tools 人格 / 主编码代理）
> **性质**：综合工单（Task A 性能基准优先 → Task B FMX 对齐，两个独立精确 commit）
> **基线**：Delphi 13.1 (Athens) · Win64 · dcc64 = `D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe`
> **规范法源**：`docs\31.hb-test.md` v1.1（门禁矩阵）· `docs\29.ui-runtime.md` v2.0（7 步生命周期）· `docs\30.touchpoint.md` v2.0（触点分级）

---

## 背景（现状，主控已核实）

1. HB 视觉层（Core/VCL/FMX 约 75 控件）与 VCL 行为层（7 步生命周期 / 触点引擎 / 遥测持久化 / 会话快照 / 表面色 SSOT）已闭环（WO-20260904-001/002R/003/004/005R、WO-20260905-001 全部 CLOSED）。
2. `31.hb-test` v1.1 第 1 节明示：除 Gate #7（触点写入延迟，已实施）外，**门禁 1–6 为"待实施项"**——这是任何产品正式发布前的硬门禁缺口。
3. FMX 行为层为零：`BindToken` / `AttachTouchpoint` / `EHbLifecycleViolation` 在 `FMX\` 全目录零命中；FMX 18 个 HB 单元仅有视觉层。FMX 产品接入 HB 行为体系前必须对齐。

## Task A · 视觉性能门禁基准 1–6 实施（优先）

目标：把 31.hb-test v1.1 门禁矩阵 1–6 从纸面变成 DUnitX 自动化基准（可进 CI、可出 junit XML 证据）。

**落地位置**：扩展 `Tests\Test.DeepBase.HB.Benchmark.pas`（现含 Gate #7，命名符合规范 `Test.DeepBase.Benchmark.*` 模式）。Gate #1 需新建最小探针程序 `Examples\HbColdStartProbe\`（本单唯一允许新建的源码目录）。

**各门禁的可测实现口径**（阈值与规范原文一字不差，测量机制可自主设计）：

| # | 门禁 | 阈值（规范原文） | 可测口径 |
|---|---|---|---|
| 1 | 首次窗口冷启动显示 | **P95 ≤ 800 ms** | 探针 exe 子进程启动 → 首帧绘制信号（首个 WM_PAINT 完成即写 stdout 标记），≥20 次冷启采样取 P95 |
| 2 | 10 万级网格滚动 | **稳定 ≥60fps（单帧 ≤16.6ms）** | THbDataGrid 装载 100,000 行，视口滚动 ≥500 帧离屏采样，断言全部单帧 ≤16.6ms |
| 3 | 全局动态主题切换 | **≤ 100 ms** | 10 套调色板实时切换 × 重绘广播（代表性复合卡片容器），每次全链 ≤100ms |
| 4 | 跨屏 DPI 动态切换 | **0 闪烁，0 毛边，重算 ≤ 30 ms** | 模拟 100%⇄175%：布局重算 ≤30ms；0 闪烁 = 断言全部绘制走双缓冲路径（禁止裸屏绘制）；0 毛边 = DPI 变更后控件边界/度量与 Token 缩放期望值全等；100%/175% 双档截图存证 |
| 5 | 窗口交互拉伸拖拽 | **无 Resize 阻塞卡顿** | 复合卡片 + 瀑布流容器连续 Resize ≥500 步，每步事件→重绘 ≤16.6ms |
| 6 | 10,000 实例压力 | **0 GDI 句柄泄漏，0 内存泄漏** | 10,000 实例创建→Dispose ≥2 轮，FastMM 泄漏报告 0 + GetGuiResources 句柄增量 0 |

**要求**：
- 全部无人值守可跑（无人工目测依赖）；断言确定性，不许"截图人审"充当门禁
- 单机噪声不得成为放宽阈值的理由；若实测超限，如实报 FAIL 并在交付报告给根因分析与修复建议，**禁止调阈值迁就**
- 证据存档 `TestResults\WO-20260905-002\`：junit XML + 各门禁原始计时数据 + G4 双档截图
- 现有 92 项测试零回归

## Task B · FMX 端 7 步生命周期对齐

目标：FMX 基类接入与 VCL 等价的行为层契约，消灭"FMX 只有视觉层"的架构分叉。

1. `FMX\DeepBase.FMX.HB.Controls.pas` FMX 基类接入 7 步生命周期（Create → BindToken → BindState → AttachTouchpoint → Render → EmitTelemetry → Dispose），失败契约（OnLifecycleError → 无条件 Dispose，Dispose 幂等）与 VCL 一致
2. FMX Paint 前置断言：未 BindToken 即绘制 → raise `EHbLifecycleViolation`（与 VCL THbCustomControl 同级 Enforcement）
3. 触点分级接入：FMX 试点控件（按钮 = tlStandard 轻量证据、对话框确认 = tlCritical 全量证据），**复用 Core 触点引擎**（DeepBase.HB.Touchpoint.Engine），禁止 FMX 侧复制引擎逻辑
4. 状态槽：FMX 基类支持 IHbStateSlotProvider 注册链（复用 THbRuntime.RegisterStateSlot）
5. **SSOT 纪律**：生命周期步骤推进等共享逻辑能沉 Core 则沉 Core（如步骤推进器），VCL/FMX 只留框架钩子；禁止把 VCL 生命周期代码复制进 FMX 形成第二真相源。若为此需小规模重构 VCL 侧，允许，但须全量回归证明零行为变化，并在交付报告说明取舍
6. 新增 `Tests\Test.DeepBase.FMX.HB.Lifecycle.pas`：镜像 VCL 生命周期测试（7 步推进 / Paint 断言真实抛出 / Dispose 幂等 / 两个试点控件证据断言）
7. 现有 FMX HB 测试零回归（含 Test.DeepBase.FMX.HB.Dialogs）

**本单边界（禁止蔓延）**：FMX 表面色 IHbSurfaceProvider 对齐、FMX 侧性能基准、SQLite 持久化扩展、DEBT-20260905-001 GUID 治理均不在本单。基准 1–6 针对当前 VCL 主栈（规范 G2 明示 GDI+ 视口）；FMX 基准待 FMX 产品立项另立工单。

## 提交纪律

- **commit 1（Task A）**：基准测试 + 探针程序 + 证据目录
- **commit 2（Task B）**：FMX 行为层 + 测试 +（如做了 Core 下沉）Core 改动
- 每次 commit 前 `git status` 核对暂存清单并附交付报告；禁止 `git add -A`；禁止搭车

## 总验收准则

1. 门禁 1–6 全部有 DUnitX 自动化断言 + junit XML 实数；当前参考机全部 PASS，或如实 FAIL 附根因分析
2. 三包编译 0 Error、HB/FMX 单元 0 新增 Warning，原始日志存档 `TestResults\WO-20260905-002\build-*.log`
3. 全量套件（92 + 新增）全绿，0 泄漏
4. 主控复核：亲自重跑基准 exe 复核数字、grep FMX Enforcement 命中、核对暂存清单
5. 异族模型终审（必做）
6. 交付报告 `CodeReview\20260905-HB-BENCHMARK-FMX-交付报告.md`：生产部署状态时间链（构建/测试/提交）、逐门禁实测数字、SSOT 下沉决策说明、债务节
