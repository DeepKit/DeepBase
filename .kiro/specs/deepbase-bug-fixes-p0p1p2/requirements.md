# Requirements Document

## Introduction

本文档定义 DeepBase Delphi 13.1 架构库剩余 P0/P1/P2 缺陷修复与架构改进的需求。涵盖 LLM 架构重构、IntentClarification 引擎修复、BrowserAutomation 修复、DeepShell 生命周期与 UI 模式修复、Graph/Math 正确性修复，以及跨模块可维护性治理。所有修复必须通过 `compile_test.bat` 编译门禁（Exit code: 0）。

## Glossary

- **LLM_Manager**: `Core/DeepBase.LLM.Manager.pas` 中的 LLM 管理器，负责 prompt 管理、调用记录和 schema 操作
- **LLM_Config**: `Features/DeepBase.LLM.Config.pas` 中的 LLM 配置存储
- **LLM_HTTP**: `Features/DeepBase.LLM.HTTP.pas` 中的 HTTP transport adapter
- **IDeepBaseHttpTransport**: 公共 HTTP 传输接口，定义于 `Features/DeepBase.Net.Transport.pas`
- **SecretStore**: `ISecretStore` / `ISecuritySecretStorage` 安全密钥存储抽象
- **IC_Engine**: `Features/DeepBase.IntentClarification.Engine.pas` 中的意图澄清引擎
- **IC_Provider**: IntentClarification 的 L0-L4 分层 provider 实现
- **IC_Session**: IntentClarification 会话管理，含 FSM 和历史
- **ResponseWaiter**: `Features/DeepBase.Browser.ResponseWaiter.pas` 中的浏览器消息等待器
- **BrowserRegistry**: `Features/DeepBase.Browser.Registry.pas` 中的浏览器后端注册表
- **DeepShell_EventBus**: `VCL/DeepBase.VCL.DeepShell.Events.pas` 中的 Shell 事件总线
- **DeepShell_Commands**: `VCL/DeepBase.VCL.DeepShell.Commands.pas` 中的命令管理器
- **Graph**: `Features/DeepBase.Graph.pas` 中的图数据结构与算法
- **DeepFlow_Engine**: `Features/DeepBase.DeepFlow.Engine.pas` 中的流程引擎
- **Mojibake**: 编码损坏导致的乱码字符（如 锟斤拷）

## Requirements

### Requirement 1: LLM Schema 统一

**User Story:** As a developer, I want a single canonical LLM schema model, so that LLM_Manager does not assume external SQL scripts were manually executed and all LLM tables are created through one migration path.

#### Acceptance Criteria

1. WHEN LLM_Manager initializes with a database that only has the Core schema (tier2), THE LLM_Manager SHALL create all required LLM tables (LLMConfig, LLMCalls, LLMPrompts, LLMApiKeys, Prompts, PromptVersions, PromptMeta, PromptMetaBinding) through a single unified migration path
2. WHEN a legacy database with the old prompt-manager schema exists, THE LLM_Manager SHALL migrate it to the canonical schema without data loss
3. THE LLM_Manager SHALL NOT directly query tables that are not guaranteed to exist by its own initialization path
4. WHEN LLMCalls records are written, THE LLM_Manager SHALL use a single canonical field set (not two generations of field layouts)

### Requirement 2: LLM 跨平台 Secret Store

**User Story:** As a developer, I want LLM API keys stored securely on all platforms, so that non-Windows environments do not fall back to plaintext storage.

#### Acceptance Criteria

1. THE LLM_Config SHALL store API keys exclusively through the SecretStore abstraction (not through hardcoded encryption keys like `@DeepBase.LLM.Key`)
2. WHEN running on Windows, THE SecretStore SHALL use Windows Credential Manager for API key storage
3. WHEN running on macOS, THE SecretStore SHALL use macOS Keychain for API key storage
4. WHEN running on Linux, THE SecretStore SHALL use libsecret/Secret Service for API key storage
5. IF no secure backend is available, THEN THE SecretStore SHALL fail closed (return error) rather than storing keys in plaintext
6. WHERE an explicit insecure dev mode is configured, THE SecretStore SHALL allow plaintext storage with a logged warning

### Requirement 3: LLM Streaming 重设计

**User Story:** As a developer, I want true streaming LLM responses, so that I can receive tokens incrementally and reduce time-to-first-token latency.

#### Acceptance Criteria

1. THE IDeepBaseHttpTransport SHALL provide a streaming API that delivers response chunks via callback before the full response is received
2. WHEN a streaming LLM request is made, THE LLM_HTTP SHALL invoke the chunk callback for each SSE event as it arrives from the server
3. THE IDeepBaseHttpTransport streaming API SHALL support a cancellation token that aborts the HTTP connection mid-stream
4. WHEN the streaming API is used, THE LLM_HTTP SHALL record FirstTokenMs (time from request to first chunk received)
5. WHILE a streaming response is in progress, THE LLM_HTTP SHALL allow the caller to cancel the request and receive a cancellation acknowledgment
6. THE existing buffered replay methods SHALL be renamed or documented to clearly indicate they are not true streaming

### Requirement 4: IntentClarification StartSession 契约

**User Story:** As a developer, I want StartSession to honor all request fields, so that initial input, templates, and budget overrides take effect on the session.

#### Acceptance Criteria

1. WHEN StartSession is called with an InitialInput field, THE IC_Engine SHALL inject that input into the first turn of the session history
2. WHEN StartSession is called with a Template field, THE IC_Engine SHALL apply the template's max level, posture, and configuration to the session
3. WHEN StartSession is called with a BudgetOverride field, THE IC_Engine SHALL use the overridden budget limits instead of defaults for that session
4. WHEN StartSession is called without a BudgetOverride, THE IC_Engine SHALL use the default budget configuration

### Requirement 5: IntentClarification 引擎并发安全

**User Story:** As a developer, I want the IC Engine to be thread-safe, so that concurrent sessions and submissions do not corrupt shared state.

#### Acceptance Criteria

1. WHILE multiple threads submit input to the same session, THE IC_Engine SHALL serialize turns for that session (no lost or reordered turns)
2. WHILE multiple threads access FProviders, THE IC_Engine SHALL protect the provider list with synchronization (lock or copy-on-write)
3. WHILE multiple threads access FHistory and FTokenUsage, THE IC_Engine SHALL protect these collections with synchronization
4. WHEN a provider is registered after the engine has started processing sessions, THE IC_Engine SHALL either reject the registration or safely snapshot the provider list

### Requirement 6: IntentClarification Provider 状态隔离

**User Story:** As a developer, I want provider instances to not share state across sessions, so that one session's denied hypotheses or selected expert do not pollute another session.

#### Acceptance Criteria

1. WHEN two sessions run concurrently on the same IC_Engine, THE IC_Provider L2 SHALL maintain separate denied hypothesis lists per session
2. WHEN two sessions run concurrently on the same IC_Engine, THE IC_Provider L3 SHALL maintain separate current expert selections per session
3. THE IC_Provider SHALL store per-session state in the session context (not in provider instance fields)

### Requirement 7: BrowserAutomation ResponseWaiter 消息匹配

**User Story:** As a developer, I want ResponseWaiter to correctly parse WebView2 messages, so that postMessage string payloads are not misinterpreted as JSON objects.

#### Acceptance Criteria

1. WHEN JavaScript calls `postMessage` with a string value, THE ResponseWaiter SHALL correctly unwrap the JSON string literal returned by `Get_WebMessageAsJson` before parsing
2. WHEN JavaScript calls `postMessage` with an object value, THE ResponseWaiter SHALL parse it directly as a JSON object
3. WHEN the waiting flag is set, THE ResponseWaiter SHALL set it before executing the script (not after), to avoid missing fast callbacks
4. WHEN multiple waiters are active on the same session, THE ResponseWaiter SHALL multiplex messages by waiter ID without mutual interference

### Requirement 8: BrowserAutomation Registry 锁粒度

**User Story:** As a developer, I want the browser registry to not hold locks during slow operations, so that availability checks and factory calls do not block other registry operations.

#### Acceptance Criteria

1. WHEN BrowserRegistry.Discover is called, THE BrowserRegistry SHALL copy the backend snapshot inside the lock and execute availability checks outside the lock
2. WHEN BrowserRegistry.CreateSession specifies a backend, THE BrowserRegistry SHALL retrieve the factory reference inside the lock and call the factory outside the lock
3. IF a factory or availability check re-enters the registry, THEN THE BrowserRegistry SHALL NOT deadlock

### Requirement 9: DeepShell EventBus 生命周期

**User Story:** As a developer, I want the DeepShell EventBus to support drain/shutdown semantics, so that queued handlers complete before shutdown and handler exceptions are diagnosable.

#### Acceptance Criteria

1. THE DeepShell_EventBus SHALL provide a Drain or Shutdown method that processes all queued handlers before returning
2. WHEN Shutdown has been called, THE DeepShell_EventBus SHALL reject new Publish calls (return failure or raise exception)
3. WHEN a handler raises an exception during dispatch, THE DeepShell_EventBus SHALL invoke an OnDispatchError callback (not silently swallow the exception)

### Requirement 10: DeepShell Theme/Localization 线程安全

**User Story:** As a developer, I want theme and localization changes to dispatch UI subscriber callbacks on the main thread, so that background thread calls do not risk VCL thread affinity violations.

#### Acceptance Criteria

1. WHEN ApplyTheme or SetLocale is called from a background thread, THE Theme/Localization service SHALL dispatch UI subscriber callbacks on the main VCL thread
2. WHEN ApplyTheme or SetLocale is called from the main thread, THE Theme/Localization service SHALL invoke subscribers synchronously without extra dispatch overhead

### Requirement 11: Graph Dijkstra 负权拒绝与邻居快照

**User Story:** As a developer, I want Graph.ShortestPath to reject negative edge weights and GetNeighbors to return a safe snapshot, so that algorithms produce correct results and concurrent access does not corrupt traversal.

#### Acceptance Criteria

1. WHEN ShortestPath (Dijkstra) is called on a graph containing negative edge weights, THE Graph SHALL raise an exception or return an error indicating negative weights are not supported
2. WHEN GetNeighbors is called, THE Graph SHALL return an array copy (snapshot) of the neighbor list, not a reference to the internal mutable list
3. IF a caller needs shortest paths with negative weights, THEN THE Graph SHALL provide an alternative algorithm (e.g., Bellman-Ford) or document the limitation

### Requirement 12: 注释编码损坏修复

**User Story:** As a developer, I want source files free of mojibake/encoding corruption, so that comments are readable and maintainable.

#### Acceptance Criteria

1. THE build process SHALL identify all `.pas` and `.md` files containing mojibake sequences (锟斤拷 or other GBK-to-UTF8 corruption artifacts)
2. WHEN a corrupted file is identified, THE fix process SHALL convert it to valid UTF-8 with BOM (Delphi standard) with correct Chinese characters restored where possible
3. IF the original text cannot be recovered, THEN THE fix process SHALL replace the corrupted comment with a `// TODO: restore original comment` placeholder

### Requirement 13: DeepFlow Pause/Resume 与优先队列

**User Story:** As a developer, I want DeepFlow Engine Pause/Resume to function and the priority queue to use efficient insertion, so that flow execution can be suspended/resumed and task scheduling scales.

#### Acceptance Criteria

1. WHEN Pause is called on a running DeepFlow_Engine, THE DeepFlow_Engine SHALL suspend execution of pending tasks (no new tasks start, running tasks complete)
2. WHEN Resume is called on a paused DeepFlow_Engine, THE DeepFlow_Engine SHALL continue executing pending tasks from where it left off
3. THE DeepFlow_Engine priority queue SHALL use an O(log N) insertion algorithm (e.g., binary heap or binary search insertion) instead of O(N) linear scan

### Requirement 14: DeepShell Settings 通知抽象

**User Story:** As a developer, I want DeepShell Settings to use an injected notification interface instead of direct ShowMessage calls, so that the shell can be tested headlessly and hosts can customize error display.

#### Acceptance Criteria

1. THE DeepShell Settings module SHALL NOT call `ShowMessage` or any direct VCL dialog function
2. THE DeepShell Settings module SHALL use an injected `IUserNotification` interface (or equivalent) for all user-facing messages
3. WHEN no notification interface is injected, THE DeepShell Settings module SHALL fall back to a status event or logged warning (not a modal dialog)

### Requirement 15: DeepShell 菜单状态运行时刷新

**User Story:** As a developer, I want menu items to reflect command state changes at runtime, so that Enable/Visible changes are immediately visible without requiring a full menu rebuild.

#### Acceptance Criteria

1. WHEN UpdateCommandState changes a command's Enabled or Visible property, THE DeepShell_Commands SHALL publish a state-changed event
2. WHEN a state-changed event is received, THE MainForm SHALL update the corresponding menu item's Enabled and Visible properties without rebuilding the entire menu
