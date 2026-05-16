# Requirements Document

## Introduction

本文档覆盖 DeepBase 第二轮代码审阅（better2.md）发现的 139 项问题修复需求，涵盖 8 个模块：Core、Persistence、Features、VCL/FMX、Governance、Browser、IntentClarification、Inference。按 P0/P1/P2 优先级分组，按功能领域组织为 15 个需求组。

## Glossary

- **System**: DeepBase 框架整体
- **StateMachine**: `DeepBase.StateMachine` 状态机组件
- **ConnectionPool**: `DeepBase.DB.ConnectionPool` 数据库连接池
- **UniPool**: `DeepBase.DB.Pool` 通用连接池
- **Cache**: `DeepBase.Cache` 缓存组件
- **Scheduler**: `DeepBase.Scheduler` 任务调度器
- **CircuitBreaker**: `DeepBase.Resilience.CircuitBreaker` 熔断器
- **Timeout**: `DeepBase.Resilience.Timeout` 超时组件
- **Crypto**: `DeepBase.Crypto` 加密组件
- **Config**: `DeepBase.Config` 配置组件
- **Logging**: `DeepBase.Logging` 日志组件
- **EventBus**: `DeepBase.EventBus` 事件总线
- **Guardian**: `DeepBase.DB.Guardian` 数据库守护组件
- **SQLLogger**: `DeepBase.SQLLogger` SQL 日志组件
- **CommerceService**: `DeepBase.Commerce.Service` 商务服务
- **SupabaseAdapter**: `DeepBase.Commerce.Adapter.Supabase` Supabase 适配器
- **FirebaseAdapter**: `DeepBase.Commerce.Adapter.Firebase` Firebase 适配器
- **SpeechService**: `DeepBase.Speech.Service` 语音服务
- **WinMMAudio**: `DeepBase.Speech.Audio.WinMM` WinMM 音频组件
- **LLMChatFrame**: `DeepBase.VCL.LLMChatFrame` LLM 聊天框架
- **BrowserAutomation**: `DeepBase.BrowserAutomation` 浏览器自动化
- **ScriptStore**: `DeepBase.Browser.ScriptStore` 脚本存储
- **WindowPool**: `DeepBase.Browser.WindowPool` 窗口池
- **ICEngine**: `DeepBase.IntentClarification.Engine` 意图澄清引擎
- **InferenceRuntime**: `DeepBase.Inference.Runtime` 推理运行时
- **InferenceSession**: `DeepBase.Inference.Session` 推理会话
- **TCriticalSection**: Delphi RTL 不可重入临界区
- **TMonitor**: Delphi RTL 可重入监视器
- **TInterlocked**: Delphi RTL 原子操作类
- **UAF**: Use-After-Free，使用已释放内存

## Requirements

### Requirement 1: Core 并发与死锁修复

**User Story:** As a developer, I want the Core module's concurrency primitives to be deadlock-free and thread-safe, so that the application does not hang or produce undefined behavior under concurrent access.

#### Acceptance Criteria

1. WHEN StateMachine.FireIfInState is called, THE StateMachine SHALL NOT attempt to re-acquire the same non-reentrant TCriticalSection, preventing deadlock (NEW-008)
2. WHEN multiple threads access Timeout result variables (Completed, ErrorClass, ErrorMsg), THE Timeout SHALL synchronize access using TInterlocked or TMonitor (NEW-015)
3. WHEN CircuitBreaker.Execute is called concurrently, THE CircuitBreaker SHALL perform AllowRequest and RecordSuccess/RecordFailure within a single lock acquisition to prevent state transition races (NEW-018)
4. WHEN EventBus global instance is accessed from multiple threads, THE System SHALL use TInterlocked.CompareExchange for safe lazy initialization with proper memory barriers (NEW-020)
5. WHEN StateMachine.IsInState traverses parent-child hierarchy, THE StateMachine SHALL detect cycles and terminate traversal within a maximum depth limit (NEW-009)
6. WHEN Timeout exceeds the configured duration, THE Timeout SHALL cancel the background TTask to prevent resource leaks (NEW-016)
7. WHEN ObjectPool background cleanup reads FShutdown across threads, THE ObjectPool SHALL use TInterlocked for memory visibility guarantees (NEW-012)
8. WHEN Scheduler.Stop is called while async tasks are running, THE Scheduler SHALL ensure task references remain valid until background TTask completes (NEW-013)
9. WHEN Scheduler async task fails, THE Scheduler SHALL invoke FOnFailed callback outside the lock to prevent deadlock (NEW-014)

### Requirement 2: Core 加密与安全修复

**User Story:** As a security engineer, I want cryptographic operations to follow best practices, so that encrypted data is properly protected and random number generation is unbiased.

#### Acceptance Criteria

1. WHEN TSimpleCrypto.EncryptBytes is called, THE Crypto SHALL generate a cryptographically random salt and prepend it to the ciphertext, rather than deriving salt deterministically from the password (NEW-005)
2. WHEN SetKeyFromPassword derives a key, THE Crypto SHALL use at least 100000 PBKDF2 iterations (NEW-006)
3. WHEN Crypto.RandomInt generates a random integer in a range, THE Crypto SHALL use rejection sampling to eliminate modulo bias (NEW-017)
4. WHEN Crypto.VerifyPassword encounters a malformed hash, THE Crypto SHALL validate hash format before comparison rather than relying on try/except, to prevent timing side-channels (NEW-019)
5. WHEN Crypto.ParseDERPublicKey reads length fields, THE Crypto SHALL validate that the declared length does not exceed remaining data, preventing buffer over-read (NEW-021)
6. WHEN EncryptStream/DecryptStream processes large data, THE Crypto SHALL process data in chunks rather than loading the entire stream into memory (NEW-007)

### Requirement 3: Core 日志与配置修复

**User Story:** As a developer, I want logging and configuration to behave correctly across platforms and not corrupt data, so that diagnostics are reliable.

#### Acceptance Criteria

1. WHEN Config.GetConfig returns a default value because the key was not found in storage, THE Config SHALL NOT cache that default value (NEW-001)
2. WHEN Logging outputs in JSON format, THE Logging SHALL skip the EscapeLogContent step to avoid double-escaping (NEW-003)
3. WHEN NextRotatedFileName searches for an available filename, THE Logging SHALL enforce a maximum index limit of 999 to prevent infinite loops (NEW-004)
4. WHEN Logging is compiled for non-Windows targets, THE Logging SHALL conditionally include Winapi.Windows only under MSWINDOWS (NEW-002)
5. WHEN Config.FOnConfigChanged fires, THE Config SHALL trigger the callback outside the lock to prevent blocking (NEW-022)

### Requirement 4: Core 缓存与池修复

**User Story:** As a developer, I want cache and pool data structures to maintain correctness under repeated operations, so that memory does not grow unbounded and eviction works correctly.

#### Acceptance Criteria

1. WHEN Cache.Put replaces an existing key, THE Cache SHALL NOT append a duplicate entry to the FIFO insert-order queue (NEW-010)
2. WHEN Cache LRU UpdateAccessOrder is called, THE Cache SHALL perform access-order updates in better than O(n) time complexity (NEW-011)

### Requirement 5: Persistence 死锁与竞态修复

**User Story:** As a developer, I want database pool and connection operations to be free of deadlocks and race conditions, so that database initialization and connection management are reliable.

#### Acceptance Criteria

1. WHEN UniPool.Initialize calls Warmup internally, THE UniPool SHALL NOT re-acquire the same non-reentrant lock, preventing deadlock (PERSIST-004)
2. WHEN ConnectionPool signals availability, THE ConnectionPool SHALL call both ResetEvent and SetEvent within the same lock acquisition to prevent lost wakeups (PERSIST-001)
3. WHEN ConnectionPool.FindAvailableConnection iterates and removes items, THE ConnectionPool SHALL iterate in reverse (downto) to avoid skipping entries (PERSIST-001)
4. WHEN UniPool statistics counters are incremented, THE UniPool SHALL hold FStatsLock for all counter modifications (PERSIST-002, PERSIST-021)
5. WHEN GDefaultPool is read or written from multiple threads, THE System SHALL use TInterlocked or a lock for synchronization (PERSIST-022)
6. WHEN ConnectionPool.GetActiveCount/GetAvailableCount are called, THE ConnectionPool SHALL acquire the lock internally rather than requiring callers to hold it (PERSIST-023)

### Requirement 6: Persistence SQL 安全修复

**User Story:** As a security engineer, I want all SQL operations to be injection-safe, so that untrusted input cannot compromise the database.

#### Acceptance Criteria

1. WHEN Guardian.Checkpoint receives an AMode parameter, THE Guardian SHALL validate it against a whitelist of ['PASSIVE','FULL','RESTART','TRUNCATE'] before use (PERSIST-005)
2. WHEN Diagnose.FireDAC methods receive table/column identifiers, THE System SHALL validate identifiers or restrict method visibility to prevent SQL injection (PERSIST-014)
3. WHEN Manager.FireDAC SQLite path constructs queries with table/column names, THE System SHALL use parameterized queries or validate identifiers (PERSIST-015)
4. WHEN SQLLogger formats the Extra JSON field, THE SQLLogger SHALL use TJSONObject to construct JSON rather than string formatting, preventing JSON injection (PERSIST-019)

### Requirement 7: Persistence 原子性与 I/O 修复

**User Story:** As a developer, I want persistence operations to be atomic and non-blocking, so that data integrity is maintained and performance is acceptable.

#### Acceptance Criteria

1. WHEN License/Security/Manager/Factory perform UPSERT operations, THE System SHALL use INSERT OR REPLACE or ON CONFLICT DO UPDATE for atomicity instead of UPDATE-then-INSERT (PERSIST-012)
2. WHEN Manager.FireDAC.UpdateSchemaInfo updates version and timestamp, THE System SHALL wrap both statements in a transaction (PERSIST-016)
3. WHEN AutoRefreshConfig.EnsureCacheFresh performs database I/O, THE System SHALL NOT hold the main lock during I/O operations (PERSIST-009)
4. WHEN SQLLogger writes to file or database, THE SQLLogger SHALL NOT hold the main lock during I/O; use a producer-consumer pattern instead (PERSIST-018)
5. WHEN Logging.FireDAC public methods (PurgeOlderThan, CountByLevel, CountAll) access the connection, THE System SHALL acquire FLock to prevent concurrent connection creation (PERSIST-011)
6. WHEN Guardian.BackupTo creates a backup, THE Guardian SHALL write to a temporary file first then rename, to prevent data loss on crash (PERSIST-024)

### Requirement 8: Features 商务逻辑修复

**User Story:** As a product owner, I want commerce operations to be correct and safe, so that payments are not duplicated, entitlements are not over-consumed, and data is not corrupted.

#### Acceptance Criteria

1. WHEN SupabaseAdapter.SingleOrNull extracts a JSON object from an array, THE SupabaseAdapter SHALL use Arr.Extract(0) before freeing the array to prevent use-after-free (FEAT-001)
2. WHEN FirebaseAdapter parses JSON responses, THE FirebaseAdapter SHALL check for nil before type-casting TJSONObject.ParseJSONValue results (FEAT-002)
3. WHEN SupabaseAdapter serializes entitlement or payment status enums to JSON, THE SupabaseAdapter SHALL convert enum values to their string representations rather than writing empty strings (FEAT-003)
4. WHEN SDKGateway.Order.Metadata is freed in a finally block, THE System SHALL use FreeAndNil and check for nil to prevent freeing an uninitialized pointer (FEAT-004)
5. WHEN CommerceService.BeginPayment checks order status, THE CommerceService SHALL reject orders in cosFailed, cosClosed, and cosRefunded states in addition to cosPaid (FEAT-005)
6. WHEN ConsumeEntitlement decrements remaining_quota, THE System SHALL use an atomic database operation (UPDATE WHERE remaining_quota >= N) to prevent over-consumption under concurrency (FEAT-006)
7. WHEN CommerceBackendHttpTransport.Send is called concurrently, THE System SHALL synchronize access to the shared THTTPClient or use per-request clients (FEAT-014)

### Requirement 9: Features 语音线程安全修复

**User Story:** As a developer, I want speech components to be thread-safe and properly manage COM object lifetimes, so that audio recording and TTS do not crash.

#### Acceptance Criteria

1. WHEN SpeechService class variables (FASR, FTTS, FWakeWord, FVoiceprint) are registered, THE SpeechService SHALL synchronize access with a lock (FEAT-007)
2. WHEN SAPI TTS SpeakAsync uses a background thread, THE System SHALL use a dedicated STA worker thread for COM access and properly synchronize Stop with the worker (FEAT-008)
3. WHEN global speech singletons are lazily created, THE System SHALL use atomic initialization (TInterlocked.CompareExchange) to prevent double-creation (FEAT-009)
4. WHEN SAPI ASR Stop is called, THE System SHALL WaitFor the worker thread to exit before releasing COM objects, and NOT use FreeOnTerminate (FEAT-010)
5. WHEN WinMM FIsRecording is accessed from both the WaveInProc callback and public methods, THE WinMMAudio SHALL use TInterlocked for thread-safe access (FEAT-011)
6. WHEN WinMM StopRecording is called while WaveInProc callback may be executing, THE WinMMAudio SHALL acquire FLock to ensure the callback is not mid-execution before freeing buffers (FEAT-012)
7. WHEN SpeechRegistry.EnsureInit creates the lock object, THE System SHALL use atomic initialization or the initialization section to prevent race conditions (FEAT-013)

### Requirement 10: VCL/FMX 线程安全与 UAF 修复

**User Story:** As a developer, I want VCL/FMX UI components to safely interact with background threads, so that closing windows or switching views does not crash the application.

#### Acceptance Criteria

1. WHEN LLMChatFrame spawns a background thread, THE LLMChatFrame SHALL capture interface references (not Self) to extend lifetime, and assign FCurrentTask for cancellation support (VCL-001)
2. WHEN LLMChatFrame background thread accesses FHistory, THE System SHALL capture necessary data before thread start or protect FHistory with a lock (VCL-002)
3. WHEN LLMSettingsFrame spawns a background thread that needs VCL control values, THE System SHALL capture string values into local variables before thread creation (VCL-003)
4. WHEN LLMSettingsFrame.RefreshTierList selects a provider, THE System SHALL match against the actual model rather than unconditionally selecting the first provider (VCL-004)
5. WHEN LLMSettingsFrame.SwapTierItems reorders items, THE System SHALL persist the new order via LLMAdmin.SetTierModels (VCL-005)
6. WHEN WaitForm is constructed via different Create paths, THE WaitForm SHALL ensure CreateControls is called exactly once (VCL-006)
7. WHEN FMX/VCL NotificationBar.CheckCancelled is called, THE System SHALL only return FCancelled without calling ProcessMessages to prevent reentrancy (FMX-001, VCL-007)
8. WHEN LLMChatFrame EnableStreaming property exists but is non-functional, THE System SHALL either implement streaming or remove the dead fields and property (FMX-002)

### Requirement 11: Browser 契约与安全修复

**User Story:** As a developer, I want browser automation scripts to return data in the format consumers expect, so that operations succeed in production.

#### Acceptance Criteria

1. WHEN ScriptStore provides the browser.get_text template, THE ScriptStore SHALL return a JSON object with {found, text, error} structure matching the consumer's TryJsonGetText expectations (BROWSER-001)
2. WHEN ScriptStore provides browser.click and browser.input_text templates, THE ScriptStore SHALL return a JSON object with {success, error} structure matching the consumer's TryJsonBool expectations (BROWSER-002)
3. WHEN WindowPool.Acquire reuses a pooled window, THE WindowPool SHALL publish betWindowAcquired; when creating a new window, publish betWindowOpened (BROWSER-003)
4. WHEN ResponseWaiter reads the durationMs field from JSON, THE System SHALL check for nil before type-casting to TJSONNumber (BROWSER-004)
5. WHEN Selectors test validates non-object JSON handling, THE test SHALL assert that original values are preserved (matching BUG-BA-005 fix behavior) (BROWSER-005)
6. WHEN Engine.WebView2 contains dead TBrowserAutomationSessionAdapter code, THE System SHALL remove it to prevent nil-session AV (BROWSER-006)
7. WHEN WindowPool.ShutdownAll restores OwnsObjects, THE WindowPool SHALL restore it within the same lock acquisition as the clear operation (BROWSER-007)
8. WHEN Browser Session reads FStateMachine state, THE Session SHALL acquire FLock consistent with other state-accessing methods (BROWSER-008)
9. WHEN Selectors constructs event JSON, THE System SHALL use TJSONObject rather than string concatenation to prevent invalid JSON from special characters (BROWSER-009)
10. WHEN CDP.WaitForSelector creates an anonymous thread, THE System SHALL set FreeOnTerminate := True to prevent thread object leaks (BROWSER-010)

### Requirement 12: IntentClarification 并发与正确性修复

**User Story:** As a developer, I want the IntentClarification engine to handle concurrent sessions correctly and not lose data, so that clarification workflows complete reliably.

#### Acceptance Criteria

1. WHEN ICEngine.HandleRegenerate or budget-exhaustion path writes to FSessions, THE ICEngine SHALL acquire FLock before modification (IC-001)
2. WHEN ICEngine.HandleExit modifies session state, THE ICEngine SHALL re-read the session within the lock before writing back to prevent read-modify-write races (IC-002)
3. WHEN ICEngine budget is exhausted, THE ICEngine SHALL record the current turn to history before marking the session as completed (IC-003)
4. WHEN Session.SuspendIdleSessions iterates FSessions, THE System SHALL collect keys to update first, then modify the dictionary outside the iteration (IC-004)
5. WHEN Types.FromJson receives invalid JSON, THE System SHALL return a descriptive error result rather than throwing an exception (IC-005)
6. WHEN Types.FromJson reads sessionState from JSON, THE System SHALL check for nil and validate the type before casting (IC-006)
7. WHEN ICEngine.FindProvider returns nil, THE ICEngine SHALL attempt lower-level providers (L4→L3→L2→L1→L0) through TDegradationHandler before generating a generic message (IC-007)
8. WHEN Provider L2 FDeniedHypotheses is accessed as a shared singleton, THE System SHALL use a thread-safe collection (TDictionary with lock) and bound its growth (IC-008)
9. WHEN Provider L3 FCurrentExpert/FExpertSelected is accessed concurrently, THE System SHALL use per-session state or a lock to prevent cross-session interference (IC-009)
10. WHEN LLMResilience timeout is exceeded, THE System SHALL actually abort the inner call (e.g., via TTask timeout) rather than only logging a warning (IC-010)
11. WHEN LLMResilience.MakeFailureResult is called with an error message, THE System SHALL populate Result.ErrorMessage with the provided error string (IC-011)
12. WHEN LLMResilience.GenerateImage is called, THE System SHALL apply the same resilience wrapping (retry, circuit-breaker) as other LLM operations (IC-012)
13. WHEN Storage.JsonToRapport reads JSON fields, THE System SHALL check for nil values before accessing .Value to prevent AV (IC-013, IC-014)
14. WHEN Templates.ApplyOverride converts a string to TClarificationLevel, THE System SHALL validate the integer is within the valid enum range (IC-015)
15. WHEN Templates.ApplyOverride receives an unknown field name, THE System SHALL signal an error rather than silently ignoring the override (IC-016)
16. WHEN Anticipation FPredictionCounter is incremented concurrently, THE System SHALL use TInterlocked.Increment; FFeedback list access SHALL be protected by a lock (IC-017)
17. WHEN Metrics counters are incremented, THE System SHALL use TInterlocked.Increment for thread safety (IC-018)
18. WHEN RegisterLLM creates L3/L4 providers, THE System SHALL ensure persona registry is available to providers (via lazy creation or deferred injection) (IC-021)
19. WHEN Rapport FProfiles dictionary is accessed concurrently, THE System SHALL protect it with TCriticalSection (IC-022)
20. WHEN SessionFSM references session status values, THE System SHALL use named enum constants rather than hardcoded ordinal values (IC-023)
21. WHEN ICEngine records a turn, THE System SHALL populate Answer and AssistantOutput fields (IC-025)

### Requirement 13: Governance 运行时修复

**User Story:** As a developer, I want governance components to correctly manage state and resources, so that routing, evidence recording, and validation work reliably.

#### Acceptance Criteria

1. WHEN RouteResolver.ReloadRules clears rules, THE RouteResolver SHALL also clear FFallbacks to prevent stale fallback routes (GOV-019)
2. WHEN EvidenceRecorder is destroyed, THE EvidenceRecorder SHALL flush the remaining queue before stopping the worker thread (GOV-020)
3. WHEN ActionGrid executes an action with no bridge configured, THE ActionGrid SHALL return a noop/dry-run status rather than Success (GOV-021)
4. WHEN ConfigRegistrar.RegisterPurpose/RegisterGate/RegisterAction fails after object creation, THE System SHALL free the created object to prevent leaks (GOV-022)
5. WHEN ValidationEngine.Validate results are needed by both CountBySeverity and CanRelease, THE System SHALL cache validation results to avoid redundant O(n^2) execution (GOV-023)
6. WHEN LLMConfigPanel.SetLLM frees the LLM instance, THE System SHALL use FreeAndNil to prevent dangling pointer access (GOV-024)
7. WHEN ActionGrid dictionaries are accessed at runtime, THE ActionGrid SHALL protect all dictionary operations with TCriticalSection (GOV-026)
8. WHEN DBInitWizard.ValidateStep uses the default path, THE System SHALL verify the path is writable before returning success (GOV-027)

### Requirement 14: Inference 模块修复

**User Story:** As a developer, I want the ONNX inference engine to correctly manage runtime lifecycle, session resources, and metadata encoding, so that model inference is reliable and re-initialization works correctly.

#### Acceptance Criteria

1. WHEN InferenceRuntime.Shutdown is called, THE InferenceRuntime SHALL detach execution providers and reset session options so that re-Initialize works cleanly (INFER-001)
2. WHEN InferenceRuntime.Initialize is called, THE InferenceRuntime SHALL create fresh session options rather than modifying stale global state (INFER-002, INFER-003)
3. WHEN InferenceRuntime.GetProvider/IsInitialized is read from another thread, THE System SHALL synchronize access with the same lock used by Initialize (INFER-004)
4. WHEN InferenceSession reads model metadata strings, THE System SHALL use UTF8ToString or TEncoding.UTF8.GetString rather than AnsiString conversion to preserve non-ASCII characters (INFER-005)
5. WHEN InferenceSession.Run receives input data, THE System SHALL validate that the shape dimension product equals the element count before calling ONNX (INFER-006)
6. WHEN InferenceSession construction partially fails, THE System SHALL release any already-allocated ONNX resources in the exception path (INFER-008)
7. WHEN InferenceSession is accessed concurrently (Dispose vs reference-count release), THE System SHALL use a lock or document the type as non-thread-safe (INFER-009)
8. WHEN InferenceService.IsReady is queried, THE System SHALL also check FRuntime.IsInitialized in addition to FSessionFactory existence (INFER-010)
9. WHEN IoC.RegisterAll fails after Runtime initialization, THE System SHALL call LRuntime.Shutdown in the exception handler to prevent ONNX resource leaks (INFER-012)

### Requirement 15: Persistence 与 Features 优化项

**User Story:** As a developer, I want performance bottlenecks and resource inefficiencies to be addressed, so that the system performs well under load.

#### Acceptance Criteria

1. WHEN Migrations calculates file checksums, THE System SHALL open files with fmShareDenyWrite to prevent concurrent modification during checksum (PERSIST-006)
2. WHEN JobQueue performs database operations, THE System SHALL use pooled/shared connections rather than creating a new connection per operation (PERSIST-007)
3. WHEN Protection.FireDAC performs database operations, THE System SHALL cache or pool the connection rather than creating/destroying per call (PERSIST-017)
4. WHEN DoQry.UniDbInsertReturningId creates queries, THE System SHALL use the prepared statement pool consistent with Select/Exec/Scalar (PERSIST-020)
5. WHEN MFCC computes the DFT, THE System SHALL use an O(N log N) FFT algorithm rather than O(N^2) DFT (FEAT-015)
6. WHEN SpeechService.ShouldAutoStop analyzes audio, THE System SHALL process only new samples incrementally rather than re-processing all audio from the beginning (FEAT-016)
7. WHEN SignalDetector.CountToken searches for tokens, THE System SHALL use PosEx with a start index rather than Copy to avoid O(n^2) string allocation (IC-019)
8. WHEN LLMChatFrame.AppendToChat measures text length, THE System SHALL use EM_GETTEXTLENGTH or a cached position rather than recomposing all content (VCL-010)
9. WHEN LLMConfigPanel.TestButtonClick tests the connection, THE System SHALL execute the test on a background thread to avoid freezing the UI (VCL-011)
