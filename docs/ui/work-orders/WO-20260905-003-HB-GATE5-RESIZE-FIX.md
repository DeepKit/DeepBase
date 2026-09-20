# 工单 WO-20260905-003 · HB Gate #5 Resize 性能修复 + 异常路径强制 Dispose 债务清偿（开发甲）

> **指派对象**：开发甲（software-tools / 主编码代理）  
> **性质**：专项性能修复与架构债务清偿工单（Task A 性能修复 + Task B 债务清偿）  
> **基线**：Delphi 13.1 (Athens) · Win64 · `dcc64.exe` · DUnitX  
> **规范法源**：`docs\31.hb-test.md` v1.1（门禁矩阵）· `docs\29.ui-runtime.md` v2.0（§2.2 生命周期失败路径契约）  

---

## 背景与问题定义

1. **Gate #5 真实 FAIL**：WO-20260905-002 实施了门禁 1–6，其中 Gate #5（窗口交互拉伸拖拽，阈值 $\le 16.6\text{ ms}$）在 500 步 Resize 实测中出现最大 167.2ms 的耗时峰值（`TestResults/WO-20260905-002/gate5-resize-timings.csv`）。根据工程纪律，严禁调大阈值迁就，必须从渲染路径定位根因并优化（Waterfall 脏矩形裁剪、双缓冲与背景擦除抑制）。
2. **29.ui-runtime §2.2 异常路径强制 Dispose 债务**：规范 §2.2 明确规定在生命周期任一步骤抛出未捕获异常时，必须触发 `OnLifecycleError` 记录上下文并无条件进入 `Dispose` 步骤执行幂等清理。当前 VCL 与 FMX 仅触发事件但未强制调用 `DoDispose`。

---

## Task A · Gate #5 Resize 性能修复（禁止调阈值）

1. **定位根因**：
   - `THbFacetWaterfall` 与 `THbCard` 在窗体连续 Resize 时触发了多余的背景擦除与全量重绘；
   - 优化 `THbFacetWaterfall` 窗口样式（`WS_CLIPCHILDREN`, `WS_CLIPSIBLINGS`）、`WMEraseBkgnd` 抑制与布局测量；
   - 优化 `THbCard` 与 `THbCustomControl` 绘制路径，确保 500 步 Resize 连续拖拽中每步 $\le 16.6\text{ ms}$。
2. **验收**：
   - 重新运行 `Tests/Test.DeepBase.HB.Benchmark.pas` 中的 `Gate5_ResizeDrag_Composite_EachStepUnder16_6ms`；
   - 500 步单帧耗时全部 $\le 16.6\text{ ms}$，Gate #5 测试 PASS。

---

## Task B · 清偿 29.ui-runtime §2.2 异常路径强制 Dispose 债务

1. **Core SSOT 下沉**：
   - 在 `Core/DeepBase.HB.Lifecycle.pas` / `THbLifecycleState` 或基类体系中统一提供异常失败后的强制 Dispose 保证；
2. **VCL & FMX 对齐**：
   - `THbCustomControl.HandleLifecycleError` 与 `THbFmxControl.HandleLifecycleError` 在触发 `OnLifecycleError` 后无条件执行 `DoDispose`；
3. **新增回归测试**：
   - 编写单元测试验证当控件在生命周期中触发异常时，`IsDisposed` 状态被确切置为 `True`，且后续重复调用 `Dispose` 具备完全幂等性。

---

## 交付与门禁要求

1. 21 个 Win64 运行时包编译 0 Error / 0 Warning；
2. HB 全量测试套件（含 Gate 1–7 基准）全绿通过，Gate #5 真实 PASS；
3. 证据存档于 `TestResults/WO-20260905-003/`；
4. 交付报告 `CodeReview/20260905-HB-GATE5-RESIZE-FIX-交付报告.md`。
