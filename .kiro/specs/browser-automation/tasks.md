# DeepBase.BrowserAutomation - 任务总览

## 当前状态

✅ **Phase 1** — 基础抽象层
✅ **Phase 2a** — BUG-BA-001 ~ BUG-BA-007 修复
✅ **Phase 2b** — 能力升级 + BUG-BA-008/009 + 接入指南
✅ **Phase 3** — 5 专家圆桌评审 + ScriptStore + 19/19 bug
✅ **Phase 4** — 第二轮深度评审，C/H/M 共 28 项发现，关闭 21 项

详细历史见 `history.md`，bug 状态见 `bugfix.md`。

---

## Phase 4 完成情况

### Critical（7/7 全部关闭）

- [x] C1 RecordHeartbeat 持锁调 GetHealthStatus
- [x] C2 DoRecovery 持锁调 GetRetryCount/ResetRetryCount
- [x] C3 WebView2.EvaluateScript TJSONString.Create 泄漏
- [x] C4 Vision.TryVisionInput TJSONString.Create 泄漏
- [x] C5 Registry FactoryFunc 为 nil
- [x] C6 ResponseWaiter postMessage 没人接收
- [x] C7 *Async 后台线程触发 STA

### High（10 项中 9 项关闭，1 项部分）

- [x] H1 DoRecovery Success := True 掩盖失败
- [x] H2 CDP.SendCommand 在锁外读 FSession
- [x] H3 WebView2 共享 FNavigationEvent 并发干扰
- [x] H4 WebView2 共享 FScreenshotStream 并发干扰
- [x] H5 CDP.WaitForSelector COM 安全（取消 token 留 P3）
- [x] H6 Registry.EnsureInit TOCTOU
- [x] H7 Vision.FloatToStr 本地化
- [x] H8 GlobalWebView2Loader 没 finalization
- [x] H9 CDP 测试空白
- [x] H10 Service 测试空白

### Medium（11 项中 5 项关闭，6 项留 P3）

- [ ] M1 TBrowserAutomationSessionAdapter 困在 WebView2 单元 — P3
- [ ] M2 IBrowserSession ↔ IBrowserAutomationSession 重复 — P3
- [x] M3 IBrowserRecovery 加 ClearSnapshot
- [ ] M4 IoC.WireServiceToRecovery 硬转换 — P3
- [x] M5 TVisionCache FMaxAgeMs 实现过期
- [ ] M6 BrowserAutomation.Scripts vs ScriptStore 双源 — P3
- [x] M7 WindowPool.Release 改用 betWindowReleased
- [x] M8 Layout 工厂校验除数
- [x] M9 ResponseWaiter.FWaiting 原子化
- [ ] M10 Selectors 测试覆盖率 — P3
- [ ] M11 Recovery.DoRecovery 路径测试 — P3

---

## 下一阶段（Phase 5 候选）

清理留尾的 6 项 Medium + 1 项 High（H5 取消 token），都是结构性 / 测试覆盖性工作：

- M1/M2 — 把 TBrowserAutomationSessionAdapter 从 WebView2 提到独立单元（DeepBase.Browser.AutomationAdapter.pas），同时考虑合并 IBrowserSession 与 IBrowserAutomationSession（最大动作）
- M4 — 提取 IRecoveryEvents 接口，IoC 不再硬转换
- M6 — TBrowserAutomationScripts.BuildXxxScript 全部代理到 ScriptStore.Render
- M10/M11 — 给 Selectors / Recovery 写带 fake session 的端到端测试
- H5 — 给 CDP.WaitForSelector 加取消 token

不做的（已记录）：

- CEF / Chromium 引擎实现
- 录制回放（Codegen）
- 高保真 MutationObserver 增量 diff

---

## 验收

- ✅ Phase 1-4 所有 Critical 和 P0/P1 bug 关闭
- ✅ 16 个 Browser .pas 文件 + 6 个测试文件，getDiagnostics 零错误
- ✅ ScriptStore 已注册 dpk + dpr，20+ 测试用例
- ✅ IoC 一行注册可用
- ✅ ResponseWaiter postMessage 完整闭环（C6）
- ✅ COM 线程安全（C7）
- ✅ Recovery 重建闭环（BUG-BA-025）
- ✅ 所有 JS 拼接走 ScriptStore.Render / TJSTemplate.Render（无 QuotedStr/Format 注入面）
- ✅ 接入指南示例代码可直接复制即用
