# DeepBase.BrowserAutomation - 任务总览

## 当前状态

✅ **Phase 1** — 基础抽象层
✅ **Phase 2a** — BUG-BA-001 ~ BUG-BA-007 修复
✅ **Phase 2b** — 能力升级 + BUG-BA-008/009 + 接入指南
✅ **Phase 3** — 5 专家圆桌评审 + ScriptStore + 19/19 bug
✅ **Phase 4** — 第二轮深度评审，C/H/M 共 28 项发现，关闭 21 项
✅ **Phase 5** — 第三轮评审，11 个 High 问题，全部关闭
✅ **Phase 6** — Medium 收尾，M1/M4/M6/M10/M11 全部关闭
✅ **Phase 7** — PageDriver 自然语言驱动（集成 Alibaba page-agent）

详细历史见 `history.md`，bug 状态见 `bugfix.md`。

---

## Phase 6 完成情况

### Medium 收尾（5/6 关闭，1 项标注 P5）

- [x] M1 TBrowserAutomationSessionAdapter 提到独立单元 `Features/DeepBase.Browser.AutomationAdapter.pas`
- [ ] M2 IBrowserSession ↔ IBrowserAutomationSession 合并 — P5（结构性，BUG-BA-024 修复后已无重复实现）
- [x] M4 IoC.WireServiceToRecovery 改用 `IBrowserRecoveryEvents` capability + Supports()
- [x] M6 BrowserAutomation.Build*Script 全部 ScriptStore-first（fallback 到内联）
- [x] M10 Selectors 端到端测试（`Test.DeepBase.Browser.Selectors.Integration.pas`）
- [x] M11 Recovery 真实路径测试（`Test.DeepBase.Browser.Recovery.Integration.pas`）

---

## 模块完整性清单

### Features 单元（17 个）

```
DeepBase.BrowserAutomation.pas              -- 抽象 + Runner + Scripts + Selectors（Phase 1）
DeepBase.Browser.Types.pas                  -- 共享类型 / 接口
DeepBase.Browser.Registry.pas               -- 引擎注册中心
DeepBase.Browser.Service.pas                -- 主入口门面
DeepBase.Browser.Session.pas                -- Session 状态机
DeepBase.Browser.Recovery.pas               -- 心跳 / 健康检查 / 自动恢复
DeepBase.Browser.ResponseWaiter.pas         -- MutationObserver 稳定性等待
DeepBase.Browser.Selectors.pas              -- 选择器管理 + 自愈
DeepBase.Browser.Events.pas                 -- 事件总线
DeepBase.Browser.WindowPool.pas             -- 多窗口池化
DeepBase.Browser.Vision.pas                 -- 视觉识别（StepFun 等）
DeepBase.Browser.CDP.pas                    -- DevTools Protocol 包装
DeepBase.Browser.Engine.WebView2.pas        -- WebView2 引擎实现
DeepBase.Browser.ScriptStore.pas            -- JS 模板入库（SQLite + 内置默认）
DeepBase.Browser.AutomationAdapter.pas      -- IBrowserSession → IBrowserAutomationSession 通用适配（Phase 6/M1）
DeepBase.Browser.PageDriver.pas             -- 自然语言驱动 NL→DOM→Action（Phase 7）
DeepBase.Browser.IoC.pas                    -- 一行注册门面
```

### 测试单元（15 个）

```
Test.DeepBase.BrowserAutomation.pas
Test.DeepBase.Browser.Types.pas
Test.DeepBase.Browser.Registry.pas
Test.DeepBase.Browser.Recovery.pas
Test.DeepBase.Browser.Recovery.Integration.pas      -- M11 新建
Test.DeepBase.Browser.ResponseWaiter.pas
Test.DeepBase.Browser.Session.pas
Test.DeepBase.Browser.Events.pas
Test.DeepBase.Browser.Selectors.pas
Test.DeepBase.Browser.Selectors.Integration.pas     -- M10 新建
Test.DeepBase.Browser.Async.pas
Test.DeepBase.Browser.WindowPool.pas
Test.DeepBase.Browser.Vision.pas
Test.DeepBase.Browser.ScriptStore.pas
Test.DeepBase.Browser.CDP.pas
Test.DeepBase.Browser.Service.pas
Test.DeepBase.Browser.PageDriver.pas                -- Phase 7 新建
```

---

## 留尾（P5 / 不做）

- **M2** — IBrowserSession ↔ IBrowserAutomationSession 接口合并
- **H5** — CDP.WaitForSelector 取消 token

不做的（已记录）：

- CEF / Chromium 引擎实现
- 录制回放（Codegen）
- 高保真 MutationObserver 增量 diff

---

## 验收

- ✅ Phase 1-6 全部 Critical / High / 大部分 Medium bug 关闭
- ✅ 17 个 Browser .pas 文件 + 16 个测试单元
- ✅ getDiagnostics 全模块零诊断
- ✅ ScriptStore 是所有 JS 模板的唯一权威源（M6）
- ✅ Recovery / Selectors 真实执行路径有端到端测试覆盖（M10/M11）
- ✅ TBrowserSession2AutomationAdapter 引擎无关化（M1）
- ✅ IoC 不再硬转换为具体实现类型（M4）
- ✅ 接入指南示例代码可直接复制即用

---

## Phase 8 — 第三轮 5 专家评审（PageDriver 集成后）

### 发现（10 项）

#### HIGH

- [x] H1 PageDriver Load lock escape — 重构为三阶段模式（locked→unlocked→locked），消除嵌套 Leave/Enter
- [x] H2 Recovery delegate 无同步 — DoRecovery 入口在 FLock 内快照 FOnRecovery/FOnSessionRebuilt/FSessionFactory 到局部变量
- [x] H3 TAutomationCDP 裸指针 — 添加 FDetached 标志 + Detach 方法，所有方法添加 nil guard，WaitForSelector 线程本地捕获 FCDP

#### MEDIUM

- [x] M1 PageDriver FSession 无锁访问 — Execute 在 FLock 内快照 FSession 到局部变量，卸载不阻断正在执行的调用
- [x] M2 PageDriver FStatus TOCTOU — Execute 结束时仅在状态仍为 pdsExecuting 时才回退，避免覆盖 Unload
- [ ] M4 ResponseWaiter stale result — 快速连续 StartWaiting 时前一个结果可被新 handler 接收（设计级，需 waiter ID 方案，P5）
- [x] M6 Vision DPI 缩放 — 添加 GetDpiScale 使用 GetDeviceCaps(LOGPIXELSX)，点击/输入坐标乘以 DPI 缩放因子
- [x] M7 Vision 无线程安全 — TBrowserVisionFallback 添加 FLock，FProvider/FEnabled 通过 getter/setter 访问
- [x] M8 WaitForSelector 析构悬空 — WaitForSelector 线程本地捕获 LCDP，循环中检查 nil 后退出
- [x] M10 ScriptStore JsonStringLiteral 重复 — 移除 ScriptStore 本地副本，改用 DeepBase.Browser.Types.JsStringLiteral

### 已关闭（Round 2 H1-H12 全部修复）

- ✅ M3 ExecuteScript fire-and-forget — 设计如此，ResponseWaiter 通过 IBrowserMessageReceiver 接收结果
- ✅ M5 Selectors inline fallback — 当前代码 `[data-testid],[aria-label],[name]` CSS 语法正确
- ✅ M9 Registry CreateSession — 工厂已移至锁外调用（Round 2 H11 修复）

---

## Phase 9 — 第四轮 5 专家评审（Round 3 修复后）

### 发现（4 Critical + 7 High + 5 Medium）

#### CRITICAL

- [x] C1 Vision DPI 缩放方向反转 — device-pixel → CSS pixel 应除以 DPI scale 而非乘以
- [x] C2 PageDriver.WaitForReady 读 FSession 无快照 — 并发 Unload 可致 AV，改用 LSession 参数传入
- [x] C3 Engine.WebView2 Runtime.evaluate 缺少 awaitPromise:true — PageDriver Promise 返回 null，所有 NL 指令永远失败
- [x] C4 Session.pas 匿名线程泄漏 — TThread.CreateAnonymousThread 无 FreeOnTerminate

#### HIGH

- [x] H1 TVisionCache.Destroy 析构顺序 — FLock 在字典之前释放，修正为先释放字典
- [x] H2 TBrowserSelectorManager.Destroy 析构顺序 — 同上
- [x] H3 RunHealthCheck 双重触发恢复 — 添加 bhsRecovering 状态跳过检查
- [x] H4 ResponseWaiter.Destroy 安全 — 先置 FSession := nil 再 CancelWaiting
- [x] H5 CDP Scroll 缺少 x/y 参数 — 滚动始终在 (0,0)，已添加
- [x] H6 MutationObserver 缺少 attributes:true — style/class/hidden 变化不触发，ResponseWaiter + ScriptStore 已修复
- [x] H7 Recovery delegate setter 无锁 — SetOnRecovery/SetOnSessionRebuilt/SetSessionFactory 添加 FLock

#### MEDIUM（全部修复）

- [x] M1 Session GetCurrentState/CanFire/GetPermittedTriggers 无锁 — 添加 FLock
- [x] M2 CDP PressKey 缺少 code/windowsVirtualKeyCode — 添加 KeyCodeFor/VkCodeFor 映射
- [x] M3 ScriptStore+Selectors placeholder 查询但不提取 — 添加 else if (ph) 分支
- [x] M4 ResponseWaiter FOnResult 无锁回调执行 — HandleWaitResult 快照 FOnResult 到局部变量
- [x] M5 Selectors ResolveSelector TOCTOU — 写回前检查 Selector 未被并发修改

---

## Phase 7 — PageDriver 自然语言驱动

### 概述

集成 Alibaba [page-agent](https://github.com/alibaba/page-agent) JS 库，新增 `dbasPageDriver` 策略和 `baatDriveInstruction` 动作类型，实现 NL→DOM→Action。page-agent 在页面内解析 DOM 树，调用文本 LLM，将自然语言指令映射到具体的点击/输入/导航操作。

### 交付

- [x] `Features/DeepBase.Browser.PageDriver.pas` — TPageDriver、TPageDriverJS、IPageDriver、TPageDriverConfig
- [x] `BrowserAutomation.pas` — 新增 dbasPageDriver 策略、baatDriveInstruction 动作类型、TDriveCallback、DriveInstruction() 工厂、DriveCallback 属性
- [x] `Browser.IoC.pas` — 注册 IPageDriver 单例，支持自定义配置重载
- [x] `Tests/Test.DeepBase.Browser.PageDriver.pas` — 24 个 DUnitX 测试
- [x] 接入指南新增 PageDriver 章节

### 验收

- ✅ 17 个 Browser .pas 特性单元 + 1 个 PageDriver 测试文件
- ✅ 确定性动作与 NL 指令可在同一 Runner 中混编
- ✅ IoC 支持 RegisterAll 重载传入自定义 PageDriverConfig
