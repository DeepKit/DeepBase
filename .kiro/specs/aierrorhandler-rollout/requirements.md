# Requirements: AIErrorHandler Rollout

**目的**：把现有的 `DeepBase.AIErrorHandler` 从单一交互式 VCL 弹窗组件，扩展成可在测试 / CI / 服务端等非交互式上下文中安全运行的运行时错误处理框架，并把可选的 LLM 解释能力封装为独立 adapter，避免 Core 直接耦合 LLM。

**反向补 spec**：本特性已有 WIP 代码（stash@{0}），本文档梳理意图。

## Glossary
- **AIErrorHandler**：DeepBase 全局 `Application.OnException` 处理器，按异常分级（Ignore / AutoFix / AIAnalyze / Fatal）做不同动作。
- **SilentMode**：禁用 `MessageDlg`，将 `elFatal` 从 `Application.Terminate` 切换为 `ExitCode := 1; Halt(1)`。
- **Bootstrap**：单一入口 façade，负责按模式（auto / production / test）一次性安装 AIErrorHandler + LLMBridge。
- **LLMBridge**：把 `TAIErrorHandler.SetAICallback` 接到 `DeepBase.LLM.Service.LLM().Chat(TierFast, …)` 的 thin adapter；任何 LLM 失败都返回空字符串而不抛异常。

## Requirements

### Requirement 1：SilentMode 字段

**用户故事**：作为测试 / CI 用例编写者，我希望在 AIErrorHandler 触发 fatal 路径时拿到非零退出码而不是被弹窗阻塞，这样自动化测试才能正常完成。

#### 验收标准
1. `TAIErrorConfig` SHALL 增加 `SilentMode: Boolean` 字段，默认 `False`
2. WHEN `SilentMode = True` AND 异常被分级为 `elAIAnalyze`，THE handler SHALL NOT 调用 `MessageDlg`
3. WHEN `SilentMode = True` AND 异常被分级为 `elFatal`，THE handler SHALL 设置 `ExitCode := 1` 并调用 `Halt(1)` 而不是 `Application.Terminate`
4. `TAIErrorConfig.Default` 返回的实例 `SilentMode` 值必须是 `False`（不破坏现有行为）

### Requirement 2：与既有 OnException 链式共存

**用户故事**：作为同时使用 AIErrorHandler 和 AutoFixErrorRecorderVCL 的应用开发者，我希望两个 handler 都能收到异常通知，互不抢占。

#### 验收标准
1. `TAIErrorHandler.Install` SHALL 保存 `Application.OnException` 的原始值到 `FOldAppException`（类字段）
2. WHEN `DoApplicationException` 被调用，IF `Self.Handle` 决定不终结进程，THE handler SHALL 链式调用 `FOldAppException`（如果非 nil）
3. `TAIErrorHandler.Install` MUST 是幂等的（重复调用第二次起返回不做实际动作，避免无限链）

### Requirement 3：Logger 现代化

**用户故事**：作为日志系统维护者，我希望 AIErrorHandler 通过 `Logger.Warn/Error/Fatal` 走结构化路径，而不是已弃用的 `DeepBase.Logging.Log(ltWarning, ...)` 旧 API。

#### 验收标准
1. `elAutoFix` 分支 SHALL 调用 `Logger.Warn(msg, 'AIErrorHandler')`
2. `elAIAnalyze` 分支 SHALL 调用 `Logger.Error(msg, 'AIErrorHandler')`
3. `elFatal` 分支 SHALL 调用 `Logger.Fatal(msg, 'AIErrorHandler')`
4. 不得保留旧的 `DeepBase.Logging.Log(ltWarning/ltError, ...)` 调用

### Requirement 4：Bootstrap 入口

**用户故事**：作为 Deep* 项目的 .dpr 维护者，我希望一行代码就能完成 AIErrorHandler + LLM 桥接的安装，并按 "production / test" 模式自动选档。

#### 验收标准
1. SHALL 提供 `function InstallAIErrorHandler(AMode: TAIErrorBootstrapMode = bmAuto): Boolean`
2. `TAIErrorBootstrapMode` SHALL 包含 `bmAuto`、`bmProduction`、`bmTest`
3. WHEN `bmTest`，SHALL 强制 `SilentMode := True`
4. WHEN `bmAuto`，SHALL 通过环境变量 `DEEP_AIEH_MODE='test'` 或编译开关 `{$DEFINE DEEPBASE_AIEH_TEST}` 检测测试模式
5. SHALL 提供 `InstallAIErrorHandlerForTests`（等价 `bmTest`）便捷入口
6. Install 必须幂等：第二次起返回 `False` 不重复安装
7. Install 内部任何失败 MUST NOT raise exception；改用 `OutputDebugString` 上报内部错误

### Requirement 5：LLMBridge Adapter

**用户故事**：作为不希望 Core 直接依赖 LLM 单元的开发者，我希望 LLM 接入由独立的 adapter 单元提供，且 adapter 在 LLM 失败/未配置时静默降级。

#### 验收标准
1. SHALL 提供独立单元 `DeepBase.AIErrorHandler.LLMBridge`，导出 `procedure InstallLLMBridge`
2. `InstallLLMBridge` SHALL 通过 `TAIErrorHandler.SetAICallback` 注册一个调用 `LLM.Chat(TierFast, prompt)` 的 closure
3. WHEN LLM 调用抛异常，THE callback SHALL 返回空字符串
4. WHEN LLM 返回 `Success = False`，THE callback SHALL 返回空字符串
5. THE callback MUST NOT 让任何异常逃出（`AIErrorHandler` 与 LLMBridge 之间是 never-raise 契约）
6. tier 选择 SHALL 是 `TierFast`（成本敏感，错误诊断 prompt 短）

### Requirement 6：包归属

**用户故事**：作为包结构维护者，我希望新单元落在正确的运行时包，不引入循环依赖。

#### 验收标准
1. `DeepBase.AIErrorHandler.Bootstrap` SHALL 隶属于 Core 包（与 AIErrorHandler 同包）
2. `DeepBase.AIErrorHandler.LLMBridge` SHALL 依赖 `DeepBase.LLM.Service`，因此**不能**放在 Core；建议放在 Features 包或独立小包，至少 require Features
3. 新单元 MUST NOT 被 Services / Persistence 包间接依赖
