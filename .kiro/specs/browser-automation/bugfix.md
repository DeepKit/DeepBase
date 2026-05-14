# DeepBase.BrowserAutomation - Bug/问题记录

## 状态总览

### Phase 2a / 2b 已修复（9/9）

| ID | 严重度 | 标题 | 状态 |
|---|---|---|---|
| BUG-BA-001 | 🔴 高 | WaitForSelector 把 CheckIntervalMs 当作 EvaluateScript 的超时 | ✅ Phase 2a |
| BUG-BA-002 | 🔴 高 | 失败时 JS payload 的 error 字段没传出来 | ✅ Phase 2a |
| BUG-BA-003 | 🟡 中 | BuildGetTextScript 三种情况返回值都是空字符串 | ✅ Phase 2a |
| BUG-BA-004 | 🟡 中 | WaitForSelector 时序不准 | ✅ Phase 2a |
| BUG-BA-005 | 🟡 中 | TBrowserAutomationSelectors.LoadFromJson 行为与测试名不符 | ✅ Phase 2a |
| BUG-BA-006 | 🟡 中 | TryJsonBool 与 JsonValueAsBool 行为不一致 | ✅ Phase 2a |
| BUG-BA-007 | 🟡 中 | TryJsonString 把 JSON null 当字符串 "null" | ✅ Phase 2a |
| BUG-BA-008 | 🟢 小 | EffectiveTimeout 不支持"无限超时" | ✅ Phase 2b |
| BUG-BA-009 | 🟢 小 | Delay 动作的 Value 字段语义混乱 | ✅ Phase 2b |

### Phase 3 已修复（19/19）

| ID | 严重度 | 标题 | 状态 | 来源 |
|---|---|---|---|---|
| BUG-BA-010 | 🔴 高 | ResponseWaiter 用 QuotedStr 生成非法 JS | ✅ Phase 3 (TJSTemplate.Render + ScriptStore) | Anna |
| BUG-BA-011 | 🟡 中 | SelectorManager.ValidateAgainstBrowser 解析不到 CDP 标准布尔 | ✅ Phase 3 (复用 TryJsonBool) | Anna |
| BUG-BA-012 | 🟢 低 | TryHealSelector 自愈选择器没做 JS 转义 | ✅ Phase 3 (切到 ScriptStore + CSS.escape) | Anna |
| BUG-BA-013 | 🔴 高 | Recovery 持锁 Sleep 阻塞 | ✅ Phase 3 (decision-then-execute) | Igor |
| BUG-BA-014 | 🔴 高 | WebView2 CallCDPSync 不是线程安全 | ✅ Phase 3 (per-call dictionary) | Igor |
| BUG-BA-015 | 🟡 中 | WindowPool.ShutdownAll 持锁释放会话 | ✅ Phase 3 (snapshot-then-dispose) | Igor |
| BUG-BA-016 | 🟢 低 | SelectorManager.ToConfig 持锁序列化 | ✅ Phase 3 (snapshot-then-serialize) | Igor |
| BUG-BA-017 | — | Vision.pas 缺 uses | ❌ 误报（实际已有） | Marcus |
| BUG-BA-018 | 🔴 高 | Test.ResponseWaiter 把实例方法当类方法调 | ✅ Phase 3 (BuildWaiterJS class function) | Marcus |
| BUG-BA-019 | 🟡 中 | TryVisionClick 把 LError 同时当两个 out 参数 | ✅ Phase 3 (拆 LResult/LError) | Marcus |
| BUG-BA-020 | 🟢 低 | Registry 排序减法整型溢出 | ✅ Phase 3 (CompareValue) | Marcus |
| BUG-BA-021 | 🔴 高 | WebView2.Navigate 不等 NavigationCompleted | ✅ Phase 3 (FNavigationEvent) | Sarah |
| BUG-BA-022 | 🟡 中 | bssRecovering 没处理 bstError/bstCrash | ✅ Phase 3 (加 Permit) | Sarah |
| BUG-BA-023 | 🟡 中 | bssDisposed.OnEntry 发的事件 from = to | ✅ Phase 3 (改用 OnStateChanged) | Sarah |
| BUG-BA-024 | 🟢 低 | AsAutomationSession 返回 IInterface | ✅ Phase 3 (移 IBrowserAutomationSession 到 Browser.Types + 类型别名保兼容) | Sarah |
| BUG-BA-025 | 🔴 高 | Recovery 没真正重建会话闭环 | ✅ Phase 3 (IBrowserSessionFactory + OnSessionRebuilt) | Jamal |
| BUG-BA-026 | 🟢 低 | TBrowserService.FLock 创建了不用 | ✅ Phase 3 (所有方法加锁) | Jamal |
| BUG-BA-027 | 🟡 中 | 接入指南 OnResult 示例用错回调类型 | ✅ Phase 3 (TResponseWaiterEvent 改 reference to procedure) | Jamal |
| BUG-BA-028 | 🟢 低 | 缺 IoC 一行注册门面 | ✅ Phase 3 (DeepBase.Browser.IoC.pas) | Jamal |

### 架构议题

| ID | 类型 | 标题 | 状态 |
|---|---|---|---|
| ISSUE-BA-101 | 架构 | JS 脚本写在数据库里，不能拼接在 Delphi 代码里 | ✅ Phase 3（ScriptStore + 全模块切换） |

---

## 当前状态

**Phase 3 全部 19 个 bug 关闭**（含 1 个误报）。

模块编译通过、零诊断、单元测试 20+ 用例覆盖核心模板渲染路径。生产部署前请按接入指南"健康检查清单"逐项核对。


---

## Phase 4 评审（28 个新发现）

### Critical（已全部修复 7/7）

| ID | 严重度 | 标题 | 状态 |
|---|---|---|---|
| C1 | 🔴 高 | Recovery.RecordHeartbeat 持锁调 GetHealthStatus 风险 | ✅ 加 InternalGetHealthStatus 无锁 helper |
| C2 | 🔴 高 | Recovery.DoRecovery 持锁调 GetRetryCount 风险 | ✅ 加 InternalGetRetryCount，DoRecovery 全部无锁路径 |
| C3 | 🔴 高 | WebView2.EvaluateScript 内联 TJSONString.Create 泄漏 | ✅ 改用 Browser.Types.JsStringLiteral helper |
| C4 | 🔴 高 | Vision.TryVisionInput 内联 TJSONString.Create 泄漏 | ✅ 同上 |
| C5 | 🔴 高 | Registry.RegisterWebView2Backend FactoryFunc 为 nil | ✅ 加 SetWebView2OwnerProvider + 真实 factory |
| C6 | 🔴 高 | ResponseWaiter postMessage 没人接收 | ✅ 加 IBrowserMessageReceiver + WebView2 实现 + ResponseWaiter 订阅 + JSON 路由 |
| C7 | 🔴 高 | WebView2 *Async 后台线程触发 STA 违规 | ✅ 加 OnMainThread + WaitForEventSafe；所有 COM 调用走主线程 |

### High（已修复 9/10，1 项标注遗留）

| ID | 严重度 | 标题 | 状态 |
|---|---|---|---|
| H1 | 🟡 中 | DoRecovery 设 Success := True 掩盖失败 | ✅ 拆 LFactorySuccess / LCallbackOk / LFinalSuccess |
| H2 | 🟡 中 | CDP.SendCommand 在锁外读 FSession 竞态 | ✅ 锁内 snapshot 本地 LSession |
| H3 | 🟡 中 | WebView2.Navigate 共享 FNavigationEvent 并发干扰 | ✅ FNavigateMutex 序列化 |
| H4 | 🟡 中 | WebView2.CaptureScreenshot 共享流并发干扰 | ✅ FScreenshotMutex 序列化 |
| H5 | 🟡 中 | CDP.WaitForSelector 无法取消 / 后台 COM | 🟡 COM 安全已通过 C7 解决；取消 token 留 P3 |
| H6 | 🟡 中 | Registry.EnsureInit TOCTOU 竞态 | ✅ 改用 class constructor + class destructor |
| H7 | 🟡 中 | Vision.FloatToStr 本地化小数分隔符 | ✅ 加 Browser.Types.JsFloat 用 Invariant locale |
| H8 | 🟡 中 | GlobalWebView2Loader 没 finalization | ✅ Engine.WebView2 加 finalization 块 |
| H9 | 🟡 中 | CDP.pas 无测试 | ✅ Test.DeepBase.Browser.CDP.pas（8 个用例） |
| H10 | 🟡 中 | Service.pas 无测试 | ✅ Test.DeepBase.Browser.Service.pas（7 个用例） |

### Medium（已修复 5/11，剩下 6 项已记录）

| ID | 严重度 | 标题 | 状态 |
|---|---|---|---|
| M1 | 🟢 低 | TBrowserAutomationSessionAdapter 困在 WebView2 单元 | ⏳ 留 P3 |
| M2 | 🟢 低 | IBrowserSession ↔ IBrowserAutomationSession 90% 重复 | ⏳ 留 P3（结构性合并） |
| M3 | 🟢 低 | IBrowserRecovery 缺 ClearSnapshot | ✅ 加到接口 |
| M4 | 🟢 低 | IoC.WireServiceToRecovery 硬转换 | ⏳ 留 P3（需独立 IRecoveryEvents 接口） |
| M5 | 🟢 低 | TVisionCache 没实现 FMaxAgeMs 过期 | ✅ 加 FTimestamps + Get 时检查 |
| M6 | 🟢 低 | JS 模板在 BrowserAutomation.pas 与 ScriptStore.pas 双份 | ⏳ 留 P3（彻底切到 ScriptStore） |
| M7 | 🟢 低 | WindowPool.Release 发 betWindowClosed 语义错 | ✅ 加 betWindowReleased / betWindowAcquired，Release 改用前者 |
| M8 | 🟢 低 | Layout 工厂未验证除数为零 | ✅ 三个 CreateXxx 加 ACount<=0 守卫 |
| M9 | 🟢 低 | ResponseWaiter.FWaiting 跨线程无同步 | ✅ 改 Integer + TInterlocked.Read/Exchange |
| M10 | 🟢 低 | Selectors 测试只用 nil session | ⏳ 留 P3 |
| M11 | 🟢 低 | Recovery.DoRecovery 路径未测试 | ⏳ 留 P3 |

---

## Phase 4 总结

- Critical 7 个全部关闭
- High 9 个修复 + 1 个部分修复
- Medium 5 个修复 + 6 个标注遗留
- 16 个 .pas 文件 + 6 个测试文件 全模块零诊断
