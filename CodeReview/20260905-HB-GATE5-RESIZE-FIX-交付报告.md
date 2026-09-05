# WO-20260905-003 交付报告：HB Gate #5 连续缩放性能根因修复与生命周期异常清偿

- **工单编号**：WO-20260905-003
- **配套契约 Brief**：`docs/brief-WO-20260905-003-开发甲.md`
- **执行角色**：开发甲 (`software-tools`)
- **交付时间**：2026-09-06
- **版本要求**：Delphi 13.1 on Win64

---

## 1. 任务背景与核心目标

1. **Task A (P0 · HB Gate #5 连续缩放性能根因修复)**：
   - Gate #5（500 步连续交互复合缩放 `THbCard` + `THbFacetWaterfall`）基准测试在历史基线曾达到 167.2 ms，严重超出 60 fps（$\le 16.6\text{ ms}$）硬预算。
   - **严格纪律**：**严禁修改 16.6 ms 阈值常量 `C_GATE5_STEP_MS`**。必须通过底层渲染优化与脏矩形/GDI DC 重绘路径根因消除。
2. **Task B (P1 · `29.ui-runtime` §2.2 异常路径强制 Dispose 债务清偿)**：
   - 贯彻《29.ui-runtime.md》§2.2 规范与 WO-20260905-002 遗留要求，对生命周期管线中的异常处理分支实施无条件、幂等的 `Dispose` / `DoDispose` 强制收尾（`try ... finally Dispose; end;`），确保生命周期状态进入 `lpDisposed`，杜绝任何未析构资源与状态悬挂。

---

## 2. 根因分析与技术实现

### 2.1 Task A 性能根因定位与手术刀式优化

1. **GDI+ COM 对象分配瓶颈消除**：
   - 原 `THbButton.Paint` 在每次重绘时实例化 `TGPGraphics`、`TGPGraphicsPath`、`TGPFont`、`TGPSolidBrush` 等 COM/GDI+ 托管对象，在高频连续缩放（500 次 `Form.Update`）下频繁触发堆分配与 GDI+ 句柄分配。
   - **优化**：将 `THbButton.Paint`、`THbCard.Paint`（非 ckHero 分支）与 `THbWaterfallSubPanel.Paint`、`THbWaterfallScrollBox.PaintWindow` 全面重构为 Win32 原生 GDI `DC_BRUSH` (`GetStockObject(DC_BRUSH)`) 与 `DC_PEN` (`GetStockObject(DC_PEN)`) 路径，配合 `SetDCBrushColor` / `SetDCPenColor` / `Winapi.Windows.RoundRect` / `DrawTextW`。零 GDI 对象泄漏、零堆内存反复分配。
2. **容器与子面板分层结构优化**：
   - `THbWaterfallSubPanel` 与 `THbFacetWaterfall` 统一定义并继承自 `THbCustomControl, IHbSurfaceProvider`。
   - 在 `GetContainerBgColor` 中通过 `P is THbCustomControl` 提供单指令 RTTI 快速通道，避免在控件树遍历中产生昂贵的 `QueryInterface` 开销。
   - 子面板与滚动宿主（`THbWaterfallScrollBox`）默认设定 `DoubleBuffered := False`，统一由根级容器提供单一显存 Backbuffer，根除多层嵌套 DoubleBuffered 导致的冗余 Bitmap 频繁重分配与内存 BitBlt 放大效应。
3. **滚动宿主重绘优化**：
   - `THbWaterfallScrollBox` 继承自 `TScrollBox`，重写 `PaintWindow(DC: HDC)` 直接调用 Win32 GDI `FillRect(DC, R, GetStockObject(DC_BRUSH))`，拦截 `WM_ERASEBKGND` 避免 VCL 默认滚动背景擦除闪烁与双重开销。

### 2.2 Task B 异常路径强制 Dispose 实现

1. **Core SSOT (`Core/DeepBase.HB.Lifecycle.pas`)**：
   - `THbLifecycleState.HandleError` 在调用全局与实例级错误回调前包裹 `try ... finally Dispose; end;`，确保无论上层是否抛出异常，`IsDisposed` 状态均确定置为 `True`，且 `Dispose` 保持完全幂等。
2. **VCL 基类 (`VCL/DeepBase.VCL.HB.Controls.pas`)**：
   - `THbCustomControl.HandleLifecycleError` 包裹 `try ... finally DoDispose; end;`，保证 VCL 控件在生命周期出错时立即释放监听与触点引用。
3. **FMX 基类 (`FMX/DeepBase.FMX.HB.Controls.pas`)**：
   - `THbFmxControl.HandleLifecycleError` 包裹 `try ... finally DoDispose; end;`，与 VCL 基类行为完全对称一致。

---

## 3. 五项轻量门禁（G1–G5）验收证据

### G1: 21 Win64 Packages 纯净编译 (0 Error, 0 Warning)
- **编译命令**：`powershell -ExecutionPolicy Bypass -File .\Scripts\build_packages_win64.ps1 -Profile All`
- **验证结果**：**21/21 Win64 Packages 编译通过，HB 单元 0 Error, 0 Warning, 0 Hint**。
- **输出截选**：
  ```
  Compiling DeepBaseVCL.dpk ...
  Embarcadero Delphi for Win64 compiler version 37.0
  5666 lines, 1.45 seconds, 1880316 bytes code, 177604 bytes data.
  Checking source directories for leaked .dcu ...
  Win64 package build gate passed.
  ```

### G2: Gate #5 连续缩放 500 步 $\le 16.6\text{ ms}$（及全部 Gates 1–7）
- **测试命令**：`powershell -ExecutionPolicy Bypass -File .\Scripts\run_tests.ps1 -Type Unit -Platform Win64 -CI -AllowFilteredCI -Module HB -OutputDir "TestResults/WO-20260905-003/HBModule"`
- **验证结果**：**7/7 Gates 全部通过（100% Green）**。
- **详细度量台账**：
  | Gate 指标项 | 规范阈值 | 实测表现 | 判定 |
  | :--- | :--- | :--- | :--- |
  | **Gate #1: 冷启动首帧** | P95 $\le 800\text{ ms}$ | **P95: 86.61 ms** (Max: 98.36 ms) | ✅ PASS |
  | **Gate #2: 100k 数据网格滚动** | Worst $\le 16.6\text{ ms}$ | **Worst: 1.631 ms** (P95: 1.124 ms) | ✅ PASS |
  | **Gate #3: 主题广播切换 (10色盘)** | Each $\le 100\text{ ms}$ | **Worst: 2.803 ms** (Avg: 0.98 ms) | ✅ PASS |
  | **Gate #4: DPI 切换重排布局** | Relayout $\le 30\text{ ms}$ | **Step 1: 0.001 ms, Step 2: 1.958 ms** | ✅ PASS |
  | **Gate #5: 500步连续交互缩放** | **Worst $\le 16.6\text{ ms}$** | **Worst: 12.549 ms** (Avg: ~1.3 ms) | ✅ **PASS** |
  | **Gate #6: 10,000 实例内存/GDI泄漏** | 0 GDI / 0 USER / 0 Heap | **GDI: 68 $\to$ 68, USER: 70 $\to$ 68, Heap: 0** | ✅ PASS |
  | **Gate #7: 100k 触点证据写入延迟** | P95 $\le 2.0\text{ ms}$ | **P95: 0.0026 ms** (Max: 0.0502 ms) | ✅ PASS |
- **原始证据落盘路径**：`TestResults/WO-20260905-003/gate5-resize-timings.csv`

### G3: 生命周期异常强制 Dispose 回归测试
- **VCL 生命周期测试 (`Test.DeepBase.HB.Lifecycle.TTestHbLifecycle`)**：
  - `TestFailurePath_CustomControl_HandleLifecycleError_EnforcesDispose` ✅ PASS
  - `TestDispose_Idempotent_MultipleCallsNoError` ✅ PASS
  - 8/8 tests 100% Passed.
- **FMX 生命周期测试 (`Test.DeepBase.FMX.HB.Lifecycle.TTestFmxHbLifecycle`)**：
  - `TestFailurePath_FmxControl_HandleLifecycleError_EnforcesDispose` ✅ PASS
  - `TestDispose_Idempotent_MultipleCallsNoError` ✅ PASS
  - 8/8 tests 100% Passed.

### G4: 字体治理回归测试
- **测试单元**：`Test.DeepBase.HB.Font.TTestHbFont`
- **验证结果**：9/9 tests 100% Passed. 验证 YaHei UI 首选解析与三级降级链路。

### G5: 全量单元测试套件通过
- **测试结果**：HB 模块套件 `90/90` 单元测试全部通过（0 Ignored, 0 Leaked, 0 Failed, 0 Errored）。

---

## 4. 变更文件清单

1. `Core/DeepBase.HB.Lifecycle.pas`：`THbLifecycleState.HandleError` 增加 `try ... finally Dispose; end;` 强制幂等析构
2. `VCL/DeepBase.VCL.HB.Controls.pas`：
   - `THbCustomControl.HandleLifecycleError` 增加 `try ... finally DoDispose; end;`
   - `THbButton.Paint` 切换至 Win32 GDI `DC_BRUSH` / `DC_PEN` / `DrawTextW` 原生快速路径
   - `GetContainerBgColor` 增加 `THbCustomControl` RTTI 快速匹配
3. `VCL/DeepBase.VCL.HB.Cards.pas`：`THbCard.Paint`（非 ckHero 分支）重构为 Win32 GDI `DC_BRUSH` / `DC_PEN` 快速路径
4. `VCL/DeepBase.VCL.HB.Waterfall.pas`：
   - `THbWaterfallSubPanel` / `THbFacetWaterfall` 继承并重构为 `IHbSurfaceProvider`
   - `THbWaterfallSubPanel.Paint` 与 `THbWaterfallScrollBox.PaintWindow` 优化为无堆分配 GDI 绘制
5. `FMX/DeepBase.FMX.HB.Controls.pas`：`THbFmxControl.HandleLifecycleError` 增加 `try ... finally DoDispose; end;`
6. `Tests/Test.DeepBase.HB.Benchmark.pas`：证据输出目录指针更新至 `TestResults/WO-20260905-003`
7. `Tests/Test.DeepBase.HB.Lifecycle.pas`：增加异常强制 Dispose 契约断言
8. `Tests/Test.DeepBase.FMX.HB.Lifecycle.pas`：增加 FMX 异常强制 Dispose 契约断言
