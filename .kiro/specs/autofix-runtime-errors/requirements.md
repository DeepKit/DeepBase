# Requirements Document

## Introduction

DeepBase AutoFix 是一个 AI 驱动的运行时错误自动修复系统。核心循环为：启动 Delphi EXE → 捕获运行时错误 → 终止进程 → AI 修复源码 → 编译 → 重新运行，直到无错误或达到退出条件。

系统分为两部分：
1. **DeepBase 内置**（EXE 进程内）：ErrorRecorder、SelfTerminator、HealthSignal、ScenarioRunner
2. **外部工具**（跨进程编排）：PowerShell 脚本 + AI agent 集成

本文档基于 v1 方案及第二轮审阅的 12 项强制变更编写。

## Glossary

- **ErrorRecorder**: 运行时异常捕获与结构化日志记录单元
- **SelfTerminator**: Fatal 异常检测与进程自杀单元
- **HealthSignal**: EXE 启动就绪信号写入单元
- **ScenarioRunner**: 命令行场景解析与执行单元
- **AutoFix_Loop**: 外部 PowerShell 主循环编排脚本 (autofix.ps1)
- **Runner**: EXE 启动、健康检查、超时终止脚本 (runner.ps1)
- **MapParser**: Delphi .map 文件地址解析脚本 (map-parser.ps1)
- **Compiler**: MSBuild 编译包装脚本 (compiler.ps1)
- **GitCheckpoint**: Git 隔离工作区管理脚本 (git-checkpoint.ps1)
- **RVA**: Relative Virtual Address，模块内相对虚拟地址
- **run_id**: 每次 EXE 启动时生成的唯一标识，防止读取过期日志
- **scenario-results.json**: 场景执行结果文件
- **Fix_Cache**: 修复方案缓存，命中时跳过 AI 调用直接 apply patch
- **preimage_hash**: 修复前源文件内容的 hash 值，用于验证 patch 适用性
- **Isolated_Workspace**: 隔离工作区（git worktree 或临时分支），替代 reset --hard

## Requirements

### Requirement 1: 运行时异常捕获与结构化记录

**User Story:** As a AI agent, I want the EXE to capture all runtime exceptions with structured data including RVA addresses and stack traces, so that I can precisely locate and fix the source of errors.

#### Acceptance Criteria

1. WHEN a runtime exception occurs on the main thread, THE ErrorRecorder SHALL write a JSON line to `runtime-errors.jsonl` containing fields: ts, level, class, msg, module_name, module_base, rva, stack (top 10-20 frames), context, params, state, thread, run_id, iteration
2. WHEN a runtime exception occurs on a background thread, THE ErrorRecorder SHALL capture it via System.ExceptProc and write to the same `runtime-errors.jsonl` with the thread field set to the thread ID
3. WHEN the EXE starts in autofix-mode, THE ErrorRecorder SHALL generate a unique run_id (UUID v4) and include it in every log entry and in health-signal.json
4. WHEN writing stack frames, THE ErrorRecorder SHALL record each frame as an object with module_name, module_base, and rva fields (not absolute addresses)
5. WHEN the stack trace exceeds 20 frames, THE ErrorRecorder SHALL truncate to the top 20 frames and set a truncated flag to true
6. THE ErrorRecorder SHALL use System.ExceptProc and ExceptAddr for exception capture without depending on JCL or MadExcept

### Requirement 2: Fatal 异常检测与进程自杀

**User Story:** As a AutoFix_Loop, I want the EXE to terminate itself on fatal exceptions and write structured exit information, so that I can detect failure and proceed with the fix cycle.

#### Acceptance Criteria

1. WHEN a fatal exception (EAccessViolation, EOutOfMemory, EStackOverflow) is detected, THE SelfTerminator SHALL write exit-reason.json and call Halt(2) within 3 seconds
2. WHEN writing exit-reason.json, THE SelfTerminator SHALL include fields: exit_code, reason, fatal_class, fatal_msg, module_name, rva, stack (top 10-20 frames), total_errors, run_id, timestamp
3. WHEN the scenario execution completes without fatal errors, THE SelfTerminator SHALL exit with code 0 (no errors) or code 1 (non-fatal errors recorded)
4. WHEN a scenario exceeds its timeout, THE SelfTerminator SHALL exit with code 3 and reason "timeout"

### Requirement 3: 启动就绪信号

**User Story:** As a Runner, I want to know when the EXE has fully initialized, so that I can begin monitoring for errors and enforce timeouts correctly.

#### Acceptance Criteria

1. WHEN the application shell is fully shown (AfterShellShown), THE HealthSignal SHALL write health-signal.json containing: ready, pid, timestamp, version, autofix_mode, run_id, scenarios
2. WHEN the Runner polls health-signal.json and finds a matching run_id, THE Runner SHALL consider the EXE ready and start the scenario timeout clock
3. IF health-signal.json is not written within the startup timeout, THEN THE Runner SHALL terminate the EXE process and report a startup failure

### Requirement 4: 场景执行与结果记录

**User Story:** As a developer, I want to define test scenarios that the AutoFix system executes automatically, so that runtime errors are triggered in a reproducible way.

#### Acceptance Criteria

1. WHEN the EXE receives --autofix-scenario command line parameter, THE ScenarioRunner SHALL parse and execute the listed scenarios in order
2. WHEN each scenario completes (success or exception), THE ScenarioRunner SHALL write an entry to scenario-results.json with fields: scenario_name, status (pass/fail/error), duration_ms, error_class, error_msg, run_id
3. WHEN all scenarios have executed, THE ScenarioRunner SHALL trigger process exit via SelfTerminator
4. THE ScenarioRunner SHALL accept scenario registration via a simple callback API that requires no try/except in application code

### Requirement 5: 错误去重与根因聚合

**User Story:** As a AI agent, I want duplicate errors grouped by root cause, so that I fix each unique problem once rather than processing redundant entries.

#### Acceptance Criteria

1. WHEN multiple errors share the same class + message + top_stack_rva + scenario combination, THE AutoFix_Loop SHALL group them as a single unique error
2. WHEN presenting errors to the AI agent, THE AutoFix_Loop SHALL provide the deduplicated error list sorted by priority (fatal > error > warning, then by stack depth ascending)
3. WHEN an error group contains multiple occurrences, THE AutoFix_Loop SHALL include the occurrence count and first/last timestamps in the group summary

### Requirement 6: 地址解析（RVA 方案）

**User Story:** As a AI agent, I want runtime error addresses resolved to source file and line number, so that I can locate the exact code to fix.

#### Acceptance Criteria

1. WHEN a .map file is available, THE MapParser SHALL resolve RVA + module_name to source_file:line_number
2. WHEN exact line resolution fails, THE MapParser SHALL fall back to function name, then segment/module name, then raw RVA
3. WHEN resolving stack frames, THE MapParser SHALL resolve all frames in the stack array (up to 20) and return an array of source locations
4. THE MapParser SHALL accept RVA values (not absolute addresses) and use module_base only for validation

### Requirement 7: Git 隔离工作区管理

**User Story:** As a developer, I want AutoFix changes isolated from my working tree, so that failed fixes never corrupt my development state.

#### Acceptance Criteria

1. WHEN an AutoFix session starts, THE GitCheckpoint SHALL create an isolated workspace using git worktree or a temporary branch (not reset --hard on the main working tree)
2. WHEN a fix iteration succeeds (compiles and reduces errors), THE GitCheckpoint SHALL commit the changes in the isolated workspace with a descriptive message
3. WHEN a fix iteration fails (compile failure or error regression), THE GitCheckpoint SHALL discard the failed changes in the isolated workspace without affecting the main working tree
4. WHEN the AutoFix session completes successfully, THE GitCheckpoint SHALL offer to merge the fix branch back to the original branch
5. IF the isolated workspace cannot be created, THEN THE GitCheckpoint SHALL report the failure and abort the AutoFix session

### Requirement 8: AI 修改边界机器检查

**User Story:** As a developer, I want machine-enforced boundaries on what the AI can modify, so that framework code and critical paths are protected from unintended changes.

#### Acceptance Criteria

1. THE AutoFix_Loop SHALL enforce an allowed_paths list that restricts AI modifications to specified directories/files only
2. THE AutoFix_Loop SHALL enforce a blocked_paths list that prevents AI modifications to specified directories/files regardless of allowed_paths
3. WHEN the AI produces a diff, THE AutoFix_Loop SHALL verify that all changed files are within allowed_paths and not in blocked_paths before applying
4. WHEN the AI produces a diff exceeding max_diff_lines (configurable, default 200), THE AutoFix_Loop SHALL reject the diff and request a smaller change
5. IF a diff violates the modification boundary, THEN THE AutoFix_Loop SHALL reject the diff, log the violation, and request the AI to retry within bounds

### Requirement 9: 修复缓存（含 preimage_hash 与 git apply check）

**User Story:** As a AutoFix_Loop, I want to cache successful fixes and reuse them when the same error recurs, so that repeated AI calls are avoided and fix speed improves.

#### Acceptance Criteria

1. WHEN a fix successfully resolves an error, THE Fix_Cache SHALL store the fix with key = (error_class + message_prefix_80 + top_stack_rva + scenario) and value = (diff_patch + preimage_hash + metadata)
2. WHEN a cached fix is found for a current error, THE Fix_Cache SHALL verify that preimage_hash matches the current source file content before applying
3. WHEN applying a cached fix, THE Fix_Cache SHALL run git apply --check to verify the patch applies cleanly before actual application
4. IF preimage_hash does not match OR git apply --check fails, THEN THE Fix_Cache SHALL discard the cached entry and fall back to AI-based fixing
5. THE Fix_Cache SHALL expire entries older than 7 days or when manually cleared

### Requirement 10: 编译包装与错误捕获

**User Story:** As a AutoFix_Loop, I want compilation wrapped with structured error output, so that compile failures can be fed back to the AI for correction.

#### Acceptance Criteria

1. WHEN compiling the project, THE Compiler SHALL invoke MSBuild with the correct BDS 37.0 environment and capture stdout/stderr
2. WHEN compilation fails, THE Compiler SHALL parse error output into structured records (file, line, column, error_code, message) and write to compile-errors.json
3. WHEN compilation succeeds, THE Compiler SHALL report success with duration and warning count
4. IF compilation fails after AI fix attempt, THEN THE AutoFix_Loop SHALL provide compile-errors.json to the AI for a second fix attempt before rolling back

### Requirement 11: 主循环编排与退出条件

**User Story:** As a developer, I want the AutoFix loop to run autonomously with clear termination conditions, so that it either fixes all errors or stops gracefully with a report.

#### Acceptance Criteria

1. THE AutoFix_Loop SHALL execute the cycle: run EXE → collect errors → deduplicate → resolve addresses → AI fix → compile → repeat
2. WHEN no runtime errors are found in an iteration, THE AutoFix_Loop SHALL declare success and exit with code 0
3. WHEN the maximum iteration count is reached, THE AutoFix_Loop SHALL stop and report remaining unfixed errors
4. WHEN oscillation is detected (same error fixed and reintroduced 3 times), THE AutoFix_Loop SHALL stop fixing that error and report it as unfixable
5. THE AutoFix_Loop SHALL write iteration-summary.jsonl with per-iteration metrics: iteration, errors_found, errors_fixed, compile_success, duration_sec, ai_calls, rollback, result

### Requirement 12: PowerShell 脚本严格模式

**User Story:** As a developer, I want all PowerShell scripts to use strict mode, so that silent failures are caught early and debugging is easier.

#### Acceptance Criteria

1. THE AutoFix_Loop SHALL begin every PowerShell script with `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
2. WHEN a PowerShell command fails unexpectedly, THE AutoFix_Loop SHALL catch the error, log it with context, and exit with a non-zero code
3. THE AutoFix_Loop SHALL validate all required parameters at script entry and report missing parameters with clear error messages

### Requirement 13: 非异常崩溃回退（Minidump/WER）

**User Story:** As a AutoFix_Loop, I want to detect crashes that bypass Delphi exception handling, so that hard crashes (AV in system code, stack corruption) are still captured and reported.

#### Acceptance Criteria

1. WHEN the EXE process terminates with a non-zero exit code and no exit-reason.json is written, THE Runner SHALL check for Windows Error Reporting (WER) crash dumps or minidump files
2. WHEN a minidump is found, THE Runner SHALL extract the crash address and basic stack information and write a synthetic error entry to runtime-errors.jsonl
3. IF no structured error information is available for a crash, THEN THE Runner SHALL report the crash with exit code and process runtime as a "hard_crash" entry

### Requirement 14: 开发者集成接口（低负担）

**User Story:** As a application developer, I want to integrate AutoFix into my project with minimal code changes, so that I can benefit from automatic error fixing without restructuring my application.

#### Acceptance Criteria

1. THE ErrorRecorder SHALL be activatable with a single `TAutoFixErrorRecorder.Install` call in the .dpr file
2. THE ScenarioRunner SHALL provide a simple `AutoFix.RegisterScenario(name, callback)` API for scenario registration
3. WHEN autofix-mode is not active (no --autofix-mode flag), THE ErrorRecorder SHALL remain dormant and impose no runtime overhead
4. THE ErrorRecorder SHALL coexist with DeepBase.AIErrorHandler without conflict (AutoFix mode suppresses AIErrorHandler dialog boxes, both write to their respective outputs)

### Requirement 15: 文档版本统一与变更日志

**User Story:** As a team member, I want a single authoritative version number and changelog for the AutoFix specification, so that review history is traceable.

#### Acceptance Criteria

1. THE design document SHALL carry a single version number (v2.0) in the document header
2. THE design document SHALL include a changelog section listing all changes from v1 with their review item numbers
3. WHEN the specification is updated, THE changelog SHALL record the date, version increment, and summary of changes
