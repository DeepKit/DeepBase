# Implementation Plan: DeepBase Bug Fixes P0/P1/P2

## Overview

按优先级和依赖关系实现 15 项修复。P0 LLM 架构先行（其他模块可能依赖 SecretStore），然后 P1 并发/正确性修复，最后 P2 可维护性。每个任务通过 `compile_test.bat` 验证编译。

## Tasks

- [x] 1. LLM Schema 统一 (P0)
  - [x] 1.1 将 `sql/llm_prompts_init.sql` 中的表定义合并到 `Core/DeepBase.Schema.pas` 的 `EnsureLLMSchema` 过程中
    - 新增 `EnsureLLMSchema(const AConnection: IInterface)` 过程
    - 使用 `CREATE TABLE IF NOT EXISTS` 创建所有 canonical LLM 表
    - 包含 Prompts, PromptVersions, PromptMeta, PromptMetaBinding 表
    - _Requirements: 1.1_
  - [x] 1.2 修改 `Core/DeepBase.LLM.Manager.pas` 的 `Initialize` 方法调用 `EnsureLLMSchema`
    - 移除对外部 SQL 脚本的假设
    - 统一 LLMCalls 字段写入为 canonical 字段集 (model, provider, prompt_id, input_tokens, output_tokens, duration_ms, status, error, created_at)
    - 移除旧版字段写入路径
    - _Requirements: 1.1, 1.3, 1.4_
  - [ ]* 1.3 Write property tests for LLM Schema
    - **Property 1: LLM Schema Initialization Completeness**
    - **Property 2: LLMCalls Canonical Field Set**
    - **Validates: Requirements 1.1, 1.4**

- [x] 2. Cross-Platform SecretStore (P0)
  - [x] 2.1 Create `Core/DeepBase.Security.SecretStore.pas` with `ISecretStore` interface and `TSecretStoreFactory`
    - Define `ISecretStore` interface (TryGet, Put, Delete, IsAvailable)
    - Implement Windows backend using `CredWrite`/`CredRead`/`CredDelete`
    - Implement fail-closed fallback (raises `ESecretStoreUnavailable`)
    - Add `DEEPBASE_INSECURE_DEV_MODE` environment variable check for explicit plaintext mode
    - _Requirements: 2.1, 2.2, 2.5, 2.6_
  - [x] 2.2 Implement macOS and Linux SecretStore backends
    - macOS: `{$IF DEFINED(MACOS)}` using Security framework
    - Linux: `{$IF DEFINED(LINUX)}` using libsecret
    - Both fail-closed if platform API unavailable
    - _Requirements: 2.3, 2.4_
  - [x] 2.3 Integrate SecretStore into `Features/DeepBase.LLM.Config.pas`
    - Remove `TSimpleCrypto.Encrypt/Decrypt(..., '@DeepBase.LLM.Key')` usage
    - Replace with `ISecretStore.Put`/`TryGet` calls
    - Remove hardcoded encryption key constant
    - _Requirements: 2.1_
  - [ ]* 2.4 Write unit tests for SecretStore
    - Test Windows Credential Manager round-trip (Put then TryGet)
    - Test fail-closed behavior when no backend available
    - Test dev mode explicit opt-in
    - _Requirements: 2.2, 2.5, 2.6_

- [x] 3. Checkpoint - Compile and verify P0 LLM fixes
  - Ensure all tests pass, ask the user if questions arise.
  - Run `cmd /c compile_test.bat` to verify compilation

- [x] 4. LLM Streaming Transport (P0)
  - [x] 4.1 Extend `Features/DeepBase.Net.Transport.pas` with streaming interface
    - Add `TStreamChunkEvent` callback type
    - Add `ICancellationToken` interface and `TCancellationToken` implementation
    - Add `IDeepBaseStreamingTransport` interface extending `IDeepBaseHttpTransport`
    - _Requirements: 3.1, 3.3_
  - [x] 4.2 Implement `SendStreaming` in `TDeepBaseSystemNetTransport`
    - Use `THTTPClient.OnReceiveData` to split SSE lines and invoke chunk callback
    - Check `ICancellationToken.IsCancelled` between chunks
    - Record `FirstTokenMs` timestamp on first chunk
    - Abort HTTP connection when cancelled
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_
  - [x] 4.3 Update `Features/DeepBase.LLM.HTTP.pas` to use streaming transport
    - Modify `SendStream` to call `IDeepBaseStreamingTransport.SendStreaming`
    - Parse each SSE `data:` line as it arrives via callback
    - Rename old buffered method to `SendBuffered` with `deprecated` directive
    - _Requirements: 3.2, 3.6_
  - [ ]* 4.4 Write property tests for streaming transport
    - **Property 3: Streaming Chunk Delivery**
    - **Property 4: Streaming Cancellation**
    - **Property 5: Streaming FirstTokenMs**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5**

- [x] 5. IntentClarification StartSession Contract (P1)
  - [x] 5.1 Modify `Features/DeepBase.IntentClarification.Engine.pas` StartSession to consume all request fields
    - Inject InitialInput into first turn of session history
    - Apply Template max level, posture, and configuration to session
    - Use BudgetOverride when HasBudgetOverride is true, else use defaults
    - _Requirements: 4.1, 4.2, 4.3, 4.4_
  - [ ]* 5.2 Write property test for StartSession field consumption
    - **Property 6: StartSession Field Consumption**
    - **Validates: Requirements 4.1, 4.2, 4.3**

- [x] 6. IntentClarification Engine Concurrency (P1)
  - [x] 6.1 Add synchronization to `Features/DeepBase.IntentClarification.Engine.pas`
    - Add `FGlobalLock: TCriticalSection` protecting FSessions and FProviders
    - Add `FSessionLocks: TDictionary<string, TCriticalSection>` for per-session serialization
    - Wrap FHistory and FTokenUsage access with lock
    - Add `FProvidersFrozen: Boolean` - reject RegisterProvider after first SubmitInput
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  - [ ]* 6.2 Write property test for concurrent turn serialization
    - **Property 7: IC Engine Concurrent Turn Serialization**
    - **Validates: Requirements 5.1, 5.2, 5.3**

- [x] 7. IntentClarification Provider State Isolation (P1)
  - [x] 7.1 Refactor `Features/DeepBase.IntentClarification.Provider.L2.pas` to use session context for state
    - Remove `FDeniedHypotheses` instance field
    - Read/write denied hypotheses from session context keyed by session ID
    - _Requirements: 6.1_
  - [x] 7.2 Refactor `Features/DeepBase.IntentClarification.Provider.L3.pas` to use session context for state
    - Remove `FCurrentExpert` and `FExpertSelected` instance fields
    - Read/write expert state from session context keyed by session ID
    - _Requirements: 6.2_
  - [ ]* 7.3 Write property test for provider session isolation
    - **Property 8: IC Provider Session State Isolation**
    - **Validates: Requirements 6.1, 6.2**

- [x] 8. Checkpoint - Compile and verify IntentClarification fixes
  - Ensure all tests pass, ask the user if questions arise.
  - Run `cmd /c compile_test.bat` to verify compilation

- [x] 9. BrowserAutomation ResponseWaiter Fix (P1)
  - [x] 9.1 Fix message parsing in `Features/DeepBase.Browser.ResponseWaiter.pas`
    - Handle `Get_WebMessageAsJson` returning JSON string literal (unwrap before parsing)
    - Handle direct JSON object payloads
    - Move waiting flag set to before ExecuteScript (rollback on failure)
    - Add waiter ID field to postMessage payload for multiplexing
    - Dispatch messages to correct waiter by ID
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  - [ ]* 9.2 Write property tests for ResponseWaiter
    - **Property 9: ResponseWaiter Message Parsing**
    - **Property 10: ResponseWaiter Multi-Waiter Isolation**
    - **Validates: Requirements 7.1, 7.2, 7.4**

- [x] 10. BrowserAutomation Registry Lock Granularity (P1)
  - [x] 10.1 Refactor `Features/DeepBase.Browser.Registry.pas` lock scope
    - Discover: copy backend snapshot inside lock, execute availability checks outside lock, write results back inside lock
    - CreateSession: retrieve factory reference inside lock, call factory outside lock
    - Prevent deadlock on re-entrant factory/availability calls
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 11. DeepShell EventBus Lifecycle (P1)
  - [x] 11.1 Add Shutdown and OnDispatchError to `VCL/DeepBase.VCL.DeepShell.Events.pas`
    - Add `FShutdown: Boolean` field
    - Add `FOnDispatchError: TProc<Exception, string>` field
    - Implement `Shutdown` method: set FShutdown, process remaining queued items via `Application.ProcessMessages`
    - Modify `Publish` to raise exception when FShutdown is true
    - Modify `DispatchInline` to call FOnDispatchError on handler exception instead of swallowing
    - Update `IShellEventBus` interface in `VCL/DeepBase.VCL.DeepShell.Intf.pas`
    - _Requirements: 9.1, 9.2, 9.3_
  - [ ]* 11.2 Write property tests for EventBus lifecycle
    - **Property 11: EventBus Shutdown Drains Queue**
    - **Property 12: EventBus Rejects After Shutdown**
    - **Property 13: EventBus Error Callback**
    - **Validates: Requirements 9.1, 9.2, 9.3**

- [x] 12. DeepShell Theme/Localization Thread Safety (P1/P2)
  - [x] 12.1 Add main-thread dispatch to `VCL/DeepBase.VCL.DeepShell.Theme.pas` ApplyTheme
    - Check `TThread.CurrentThread.ThreadID = MainThreadID`
    - If background thread: use `TThread.Queue` to dispatch subscriber callbacks on main thread
    - If main thread: invoke subscribers synchronously (existing behavior)
    - _Requirements: 10.1, 10.2_
  - [x] 12.2 Apply same pattern to `VCL/DeepBase.VCL.DeepShell.Localization.pas` SetLocale
    - Same thread-check and dispatch logic as Theme
    - _Requirements: 10.1, 10.2_
  - [ ]* 12.3 Write property test for thread-correct dispatch
    - **Property 14: Theme/Locale Thread-Correct Dispatch**
    - **Validates: Requirements 10.1, 10.2**

- [x] 13. Checkpoint - Compile and verify P1 fixes
  - Ensure all tests pass, ask the user if questions arise.
  - Run `cmd /c compile_test.bat` to verify compilation

- [x] 14. Graph Dijkstra Negative Weight and Neighbor Snapshot (P1)
  - [x] 14.1 Add negative weight rejection to `Features/DeepBase.Graph.pas` ShortestPath
    - Scan all edges before running Dijkstra
    - Raise `EGraphNegativeWeight` if any edge has weight < 0
    - _Requirements: 11.1_
  - [x] 14.2 Fix GetNeighbors to return array copy
    - Return `TArray<T>` via `.ToArray` instead of internal list reference
    - Wrap access in lock for thread safety
    - _Requirements: 11.2_
  - [ ]* 14.3 Write property tests for Graph correctness
    - **Property 15: Dijkstra Rejects Negative Weights**
    - **Property 16: GetNeighbors Returns Independent Snapshot**
    - **Validates: Requirements 11.1, 11.2**

- [x] 15. Comment Encoding Corruption Fix (P2)
  - [x] 15.1 Create encoding fix script and apply to corrupted files
    - Scan all `.pas` and `.md` files for mojibake patterns (锟斤拷, U+FFFD sequences)
    - Attempt GBK re-decode to recover original Chinese text
    - Replace unrecoverable text with `// TODO: restore original comment`
    - Save as UTF-8 with BOM (for .pas) or UTF-8 (for .md)
    - _Requirements: 12.1, 12.2, 12.3_
  - [ ]* 15.2 Write property test for encoding fix
    - **Property 17: Encoding Fix Produces Valid UTF-8**
    - **Validates: Requirements 12.2**

- [x] 16. DeepFlow Pause/Resume and Priority Queue (P2)
  - [x] 16.1 Implement Pause/Resume in `Features/DeepBase.DeepFlow.Engine.pas`
    - Add `FPaused: Boolean` and `FPauseEvent: TEvent` fields
    - Implement `Pause`: set FPaused, running tasks complete but no new tasks start
    - Implement `Resume`: clear FPaused, signal FPauseEvent to wake scheduler
    - Task scheduler loop checks FPaused before dequeuing next task
    - _Requirements: 13.1, 13.2_
  - [x] 16.2 Replace linear InsertSorted with binary search insertion
    - Use binary search to find insertion point (O(log N))
    - Maintain descending priority order
    - _Requirements: 13.3_
  - [ ]* 16.3 Write property tests for DeepFlow
    - **Property 18: DeepFlow Pause/Resume Round-Trip**
    - **Property 19: DeepFlow Priority Queue Sort Invariant**
    - **Validates: Requirements 13.1, 13.2, 13.3**

- [x] 17. DeepShell Settings Notification Abstraction (P2)
  - [x] 17.1 Add `IShellNotification` interface to `VCL/DeepBase.VCL.DeepShell.Intf.pas`
    - Define ShowInfo, ShowError, Confirm methods
    - _Requirements: 14.1, 14.2_
  - [x] 17.2 Refactor `VCL/DeepBase.VCL.DeepShell.Settings.pas` to use IShellNotification
    - Replace all `ShowMessage` calls with notification interface calls
    - Fall back to EventBus status event when no notification interface injected
    - _Requirements: 14.1, 14.2, 14.3_
  - [ ]* 17.3 Write property test for settings error routing
    - **Property 20: Settings Error Routing**
    - **Validates: Requirements 14.2**

- [x] 18. DeepShell Menu State Runtime Refresh (P2)
  - [x] 18.1 Add `sekCommandStateChanged` event kind to `VCL/DeepBase.VCL.DeepShell.Intf.pas`
    - Add new enum value to `TDeepShellEventKind`
    - _Requirements: 15.1_
  - [x] 18.2 Modify `VCL/DeepBase.VCL.DeepShell.Commands.pas` UpdateCommandState to publish event
    - After updating command dictionary, publish `sekCommandStateChanged` with command ID in Data field
    - _Requirements: 15.1_
  - [x] 18.3 Add incremental menu refresh handler in `VCL/DeepBase.VCL.DeepShell.MainForm.pas`
    - Subscribe to `sekCommandStateChanged`
    - Find menu item by command ID and update Enabled/Visible properties
    - _Requirements: 15.2_
  - [ ]* 18.4 Write property tests for menu state refresh
    - **Property 21: Command State Change Event**
    - **Property 22: Menu Item Reflects State**
    - **Validates: Requirements 15.1, 15.2**

- [x] 19. Final checkpoint - Compile and run all tests
  - Ensure all tests pass, ask the user if questions arise.
  - Run `cmd /c compile_test.bat` to verify full compilation
  - Run unit tests to verify no regressions

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation after each priority group
- Property tests validate universal correctness properties using DUnitX + custom PBT harness
- Unit tests validate specific examples and edge cases
- All code uses Delphi 13.1 syntax (inline var, conditional expressions, `{$IF CompilerVersion >= 37}`)
- No `with` statements, no `VER340` style conditionals, Unicode string + explicit encodings
