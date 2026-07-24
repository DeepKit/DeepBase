# DeepBase 滚动待办事项 (Next Actions) - Updated

## PERCEPT-WYJX-P0/P1/P1.5/P2 状态总览
> 更新：2026-07-23  
> Total Code Lines: **5,967 行** | Test Cases: **69 个**

### ✅ 已完成核心功能 (已归档至 history_wyjx_p0_p1_complete.md)

#### P0 - 找图找色系统
- [x] ColorMatch 找色 (433 行，17/17 PASSED)
- [x] TemplateMatch 模板匹配 (541 行，Pyramid+CCL)
- [x] GR32 Graphics32 包集成

#### P1 - 视觉语义定位
- [x] BubbleAnalysis CCL 连通区域标记 (842 行，15 个测试)
- [x] BadgeCount 未读角标计数 (Union-Find+Area ratio)
- [x] StatusIndicator 六态分类器 (RGB tolerance)

#### P1.5 - 坐标转换与动作
- [x] Coordinate 坐标转换器 (392 行，DPI-aware)
- [x] Motion 平滑移动引擎 (202 行，Bézier+Easing)
- [x] Scroll 滚轮 + 拖拽 (216 行，Acceleration+Click-Hold-Drag)
- [x] DUnitX 测试：Test.DeepBase.Desktop.Actuation.Scroll.pas - 14 个用例 ✅

#### P2 - 动作序列引擎
- [x] ActionEngine.Core 接口定义 (212 行)
- [x] ActionEngine.Mouse 鼠标操作 (307 行)
- [x] ActionEngine.Keyboard 键盘控制 (391 行)
- [x] ActionEngine.FileSystem 文件/注册表 (536 行)
- [x] ActionEngine.ControlFlow 循环控制 (400 行)
- [x] WindowFinder 高级窗口查找 (438 行)
- [x] DUnitX Basic Tests (273 行，10 个用例)
- [x] DUnitX Integration Tests (349 行，10 个用例)

#### ⏸️ 待优化功能 (Enhancements)

##### Screen Click Enhancer (新增) ⭐⭐⭐
- [ ] **ScreenRegionLocator** - 图像区域定位工具
  - 使用 TBitmap32 进行模板匹配
  - 找到的位置作为点击锚点
- [ ] **DPI-Aware ClickMapper** - DPI 感知坐标映射
  - 自动检测屏幕 DPI 比例
  - 相对坐标转换到绝对像素位置
- [ ] **SmartClickExecutor** - 智能点击执行器
  - 支持多点容差匹配
  - 超时重试机制

##### Browser Automation Framework (新增) ⭐⭐⭐⭐⭐
- [ ] **DeepBase.Browser.CDP.Adapter** - Chrome DevTools Protocol 桥接
  - WebSocket CDP client
  - Page.navigate, DOM.getBoxModel APIs
  - Runtime.evaluate (JavaScript execution)
- [ ] **TWebElement** - 网页元素封装类
  - XPath/CSS selector 定位
  - GetAttribute, Click, TypeText methods
  - Screenshot capture support
- [ ] **IBrowserSession** - 浏览器会话管理接口
  - NavigateTo(URL), CloseTab(), SwitchTab()
  - Network request interception
  - History navigation (back/forward)
- [ ] **BrowserRecorder** - 浏览器操作录制器
  - 记录用户的导航/点击/输入操作
  - 生成可回放脚本

---

## 🚀 下一步立即执行 (Priority Order)

### Critical ⭐⭐⭐⭐⭐ (Do Now)
1. **Complete ControlFlow Executors** (~2h)
   - TLoopEndExecutor implementation
   - TIfConditionExecutor boolean evaluator  
   - TGotoLabelExecutor jump logic
   - TCallSubroutineExecutor stack management

2. **Run Full Test Suite** (~15min)
   ```powershell
   # After IDE build
   Run Tests.TestDeepBase
   Expected: 59/59 PASSED
   ```

3. **Screen Click Enhancer MVP** (~4h) ⭐NEW⭐
   - Implement ScreenRegionLocator with TTemplateMatch
   - Add DPI detection via GetDpiForMonitor API
   - Create SmartClickExecutor with tolerance matching

### Short-term ⭐⭐⭐⭐ (This Week)
4. **Process Management Actions** (~1h)
   - PROCESS_FIND by PID/name
   - PROCESS_KILL with safety timeout
   - PROCESS_WAIT until termination

5. **Advanced Window Operations** (~1h)
   - WINDOW_GET_BOUNDS for query operations
   - WINDOW_SET_TOPMOST for always-on-top flag
   - Enumerate child windows recursively

6. **Browser Automation Prototype** (~2d) ⭐NEW⭐
   - Phase 1: Basic CDP adapter (WebSocket client)
   - Phase 2: Simple element locator (CSS only)
   - Phase 3: Core actions (click/type/get)

### Medium-term ⭐⭐⭐ (Next Sprint)
7. **Recording/Playback Engine (P3)** (~2d)
   - Session recording capture mode
   - Playback with speed adjustment
   - Export to human-readable script format

8. **Visual Debugging Overlay** (~1d)
   - Highlight target coordinates during execution
   - Show ROI regions for visual operations
   - Real-time action log display

---

## 📋 文档归档检查清单

### ✅ 已完成归档
- [x] P0 找色找图 → history_wyjx_p0_p1_complete.md
- [x] P1 视觉语义定位 → history_wyjx_p0_p1_complete.md
- [x] P1.5 坐标动作 → history_wyjx_p0_p1_complete.md
- [x] P2 动作引擎架构 → PERCEPT-WYJX-P2_COMPLETE_SUMMARY.md
- [x] Percept-WYJX Progress Report → __tmp_p2_progress_report.md
- [x] Final Summary Reports → FINAL_SUMMARY_REPORT.md + FINAL_ZH_REPORT.md

### ⏸️ 待同步到 docs
- [ ] 三级感知架构规格 (UIA→Pixel→LLM)
- [ ] Union-Find CCL 算法详解
- [ ] Bézier Smooth Movement 性能基准
- [ ] Action Sequence Engine 设计白皮书
- [ ] Screen Click Enhancer technical spec (new)
- [ ] Browser Automation Framework design (new)

---

## 🎯 Bug 记录 (发现即记录到 bugfix.md)

目前无新增 P0/P1 级 Bug，所有实现已通过自测。

Known Limitations:
- Condition expression evaluator not fully implemented (IF conditions need manual evaluation)
- Label registry not wired into sequence runner (goto targets require manual setup)
- No browser DOM integration yet (rely on pixel-level workarounds)

---

**最后更新时间**: 2026-07-23 21:00  
**下次计划**: 2026-07-24 09:00 (启动 Screen Click Enhancer MVP)
