# 实施计划：DeepBase AutoFix 运行时错误自动修复系统

**适用 design**: `.kiro/specs/autofix-runtime-errors/design.md` (v2.0)
**适用 requirements**: `.kiro/specs/autofix-runtime-errors/requirements.md` (v2.0)
**目标编译器**: Delphi 13.1 Florence (BDS 37.0)
**编译门禁**: `cmd /c compile_test.bat` ⇒ exit code 0
**实现语言**:
- Pascal (Delphi 13.1) — Core/、VCL/ 包内单元
- PowerShell 7+ — `scripts/autofix/*.ps1`

> Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## 概览

实施分 6 个阶段，每个父任务下拆为 3-7 个子任务。`*` 标记的子任务为可选 PBT/单元测试，可跳过以加速 MVP。所有 `*` 子任务实施时**禁止**被自动执行，必须用户显式选择。

目录约定：
- 已有骨架 6 个：`Core/DeepBase.AutoFix.{ErrorRecorder|SelfTerminator|HealthSignal|ScenarioRunner}.pas`
- 新增 Pascal：`Core/DeepBase.AutoFix.pas`、`Core/DeepBase.AutoFix.StackWalker.pas`、`VCL/DeepBase.AutoFix.VclHook.pas`
- 新增脚本：`scripts/autofix/*.ps1`（共 10 个）
- 测试：`Tests/AutoFix/Test.DeepBase.AutoFix.<Unit>.pas` 与 `Tests/AutoFix/<script>.Tests.ps1`

---

## Tasks

- [x] 1. Phase 1: 内置 Pascal 单元校对与补齐
  - [x] 1.1 新增 StackWalker 单元（多帧 RVA 抓取）
    - 创建 `Core/DeepBase.AutoFix.StackWalker.pas`
    - 公开 `TStackFrame` 记录与 `CaptureStack(ASkip, AMaxFrames, out ATruncated)` 函数
    - 内部用 `Winapi.Windows.RtlCaptureStackBackTrace` 抓最多 64 帧
    - 对每帧调 `GetModuleHandleEx(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, …)` 得到模块基址与名称
    - 使用 inline var、Delphi 13.1 条件表达式风格；不引入 with；不依赖 JCL/MadExcept
    - 加入 `DeepBaseCore.dpk` 的 `contains` 列表（运行时包顺序：Core 第一）
    - 编译门禁：`cmd /c compile_test.bat` 必须返回 0
    - _Requirements: 1.4, 1.5, 1.6_

  - [x] 1.2 补齐 ErrorRecorder：module_base + 多帧 stack + truncated + params/state
    - 修改 `Core/DeepBase.AutoFix.ErrorRecorder.pas`
    - `ResolveModule` 增加 out 参数 `AModuleBase: NativeUInt`
    - `WriteRecord` 增加可选参数 `const AParams: string = ''; const AState: string = ''`
    - 调用 `DeepBase.AutoFix.StackWalker.CaptureStack` 抓栈，把数组序列化进 JSON 的 `stack` 字段，附加 `stack_truncated`
    - JSON 字段更新为 design §4.2 schema：`module_name`, `module_base`, `rva`, `stack`(array of {module_name,module_base,rva}), `stack_truncated`, `params`, `state`, `iteration`, `scenario`
    - 增加 `class property TotalErrors: Integer`，每次 WriteRecord 成功后线程安全 Inc
    - run_id 缺失时通过 `CreateGUID` + `GUIDToString` 生成 UUID v4 字符串（去掉花括号，转小写）
    - 严格使用 `TEncoding.UTF8`；不使用 `TEncoding.ANSI`
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 1.3 新增 VclHook 单元（L1 Application.OnException）
    - 创建 `VCL/DeepBase.AutoFix.VclHook.pas`，归属 `DeepBaseVCL.dpk`
    - 公开 `TAutoFixVclHook = class` 含 `class procedure Install / Uninstall`
    - 保存原 `Application.OnException` 到字段，安装新 handler 转调 `TAutoFixErrorRecorder.WriteRecord(E, ExceptAddr, '<vcl-onexception>', 'main')` 然后链式调用旧 handler
    - 与 AIErrorHandler 的共存：仅当 `TAutoFixErrorRecorder.Active` 为 true 时旁路其对话框（通过 `Application.ShowException` 抑制或保留——具体策略：autofix 模式下不调 inherited，AIErrorHandler 写自己的输出文件不受影响）
    - 注意 VCL 包顺序在 Core 之后；Uses 仅引用 Core 单元
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 1.1, 14.4_

  - [x] 1.4 补齐 SelfTerminator：total_errors + stack 数组 + 字段命名修订
    - 修改 `Core/DeepBase.AutoFix.SelfTerminator.pas`
    - 增加 `EStackOverflow` 到 `IsFatal` 判定
    - 调用 `StackWalker.CaptureStack` 抓栈，写入 exit-reason.json 的 `stack` 字段
    - 字段重命名：`class` → `fatal_class`，`msg` → `fatal_msg`，`module` → `module_name`
    - 增加 `total_errors` 字段（读 `TAutoFixErrorRecorder.TotalErrors`）
    - 增加 `scenario` 字段（读 `TAutoFixScenarioRunner.CurrentScenario`）
    - 严格 3 秒内完成写入 + Halt(2)（将文件写操作放在最早，stack 抓取放在 try/except 内防止再次崩溃）
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 2.1, 2.2_

  - [x] 1.5 补齐 ScenarioRunner：退出码区分 0/1 + 当前 scenario 写入 ErrorRecorder
    - 修改 `Core/DeepBase.AutoFix.ScenarioRunner.pas`
    - `Run` 末尾的 `Halt(0)` 改为：`var LCode := if TAutoFixErrorRecorder.TotalErrors > 0 then 1 else 0;` 然后 `Halt(LCode)`
    - 增加场景执行前后向 ErrorRecorder 写入当前 scenario 标识（通过新增 `class property CurrentScenario` 读取）
    - WriteStatus 在 fail/fatal 时增加 `error_msg` 字段（取异常消息前 200 字符）
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 2.3, 4.1, 4.2, 4.3, 4.4_

  - [x] 1.6 补齐 HealthSignal：version 字段（读 EXE VersionInfo）
    - 修改 `Core/DeepBase.AutoFix.HealthSignal.pas`
    - 通过 `GetFileVersionInfoSize` + `GetFileVersionInfo` + `VerQueryValue` 读取自身 EXE 的 `FileVersion` 或 `ProductVersion`
    - 失败时填 `"unknown"`
    - 加入 design §4.1 全部 7 个字段
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 3.1_

  - [x] 1.7 新增 facade 单元 DeepBase.AutoFix
    - 创建 `Core/DeepBase.AutoFix.pas`
    - 公开 `AutoFix` sealed class 含 `Install / RegisterScenario / NotifyShellShown / Active`（class methods）
    - `Install` → 调用 `TAutoFixErrorRecorder.Install` + `TAutoFixScenarioRunner.Initialize`
    - `NotifyShellShown` → 调用 `TAutoFixHealthSignal.Emit` + `TAutoFixScenarioRunner.Run`（在新线程或异步队列以避免阻塞 UI 线程，具体策略：用 `TThread.ForceQueue(nil, …)` 投递到下一帧）
    - 加入 `DeepBaseCore.dpk` contains 列表
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 14.1, 14.2_

  - [x]* 1.8 写 Pascal 属性测试 - ErrorRecorder JSONL 字段完整性
    - 创建 `Tests/AutoFix/Test.DeepBase.AutoFix.ErrorRecorder.pas`（DUnitX）
    - **Property 1: ErrorRecorder JSONL 字段完整性**
    - 标记：`// Feature: autofix-runtime-errors, Property 1: ErrorRecorder JSONL 字段完整性`
    - ≥ 100 次随机异常类（含派生）+ 随机消息（含特殊字符）+ 随机 context，触发 `WriteRecord`，解析最后一行 JSON 断言全部字段存在且类型/取值正确
    - **Validates: Requirements 1.1, 1.2, 1.6**

  - [x]* 1.9 写 Pascal 属性测试 - run_id UUID 与跨文件一致
    - 同测试单元
    - **Property 2: run_id UUID v4 + 跨文件一致**
    - ≥ 100 次模拟启动（清空 + 重新 Install），断言 RunId 是合法 UUID v4 形（`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`），且互不相同
    - 触发一条 WriteRecord、一次 Emit、一次 ScenarioRunner WriteStatus，解析所有文件 run_id 字段一致
    - **Validates: Requirements 1.3, 3.1, 3.2**

  - [x]* 1.10 写 Pascal 属性测试 - 栈 RVA 与截断
    - 创建 `Tests/AutoFix/Test.DeepBase.AutoFix.StackWalker.pas`
    - **Property 3 + Property 4: 栈帧 RVA 正确 + 截断标志**
    - ≥ 100 次随机递归深度 D ∈ [1, 50]，触发异常并 capture，断言 `forall frame: GetModuleHandleEx(addr) == frame.module_name` 且 `len(stack) == min(D, 20)`，`truncated == (D > 20)`
    - **Validates: Requirements 1.4, 1.5**

- [x] 2. Checkpoint - 阶段 1 编译与基础测试
  - 运行 `cmd /c compile_test.bat`，确认 exit code 0
  - 运行 DUnitX `Tests/DeepBaseTests.dproj`，跑 `Tests/AutoFix/*` 测试
  - Ensure all tests pass, ask the user if questions arise.

- [x] 3. Phase 2: 外部脚本骨架（每个脚本可独立运行）
  - [x] 3.1 创建 scripts/autofix/ 目录并加入仓库
    - 在仓库根创建 `scripts/autofix/`
    - 在 `scripts/autofix/` 下创建 `_common.ps1` 公共 helper（StrictMode/Stop pref/JSON IO/Logging）：
      ```
      Set-StrictMode -Version Latest
      $ErrorActionPreference = 'Stop'
      function Read-JsonFile { ... }
      function Write-JsonFile { ... }
      function Write-Jsonl { ... }
      function Read-Jsonl { ... }
      function Write-AutoFixLog { param($Level,$Msg,$Ctx) ... }
      ```
    - 所有后续脚本第一行 `. "$PSScriptRoot/_common.ps1"`
    - _Requirements: 12.1, 12.2_

  - [x] 3.2 实现 map-parser.ps1
    - 创建 `scripts/autofix/map-parser.ps1`
    - 入参：`-MapFile <path> -ModuleName <name> -Rva <hex>` 或 `-Frames <json-array>`
    - 解析 .map 三段：Detailed map of segments / public symbols / Line numbers
    - 给定 RVA → 查 line numbers 段精确匹配 → file:line；失败回退 function name → segment → raw
    - 输出 JSON：`{file, line, function, segment, level: "exact|function|segment|raw"}`
    - 多帧入口：`-Frames` 时输入数组，输出同长度结果数组
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x]* 3.3 写 PowerShell 属性测试 - .map 解析正确性
    - 创建 `Tests/AutoFix/map-parser.Tests.ps1` (Pester 5)
    - **Property 10: .map 解析正确性 + 回退 + RVA 输入不变性**
    - 标记：`# Feature: autofix-runtime-errors, Property 10: .map 解析正确性`
    - ≥ 100 次随机生成的最小 .map 文本（用 `New-RandomMap` helper），随机选 line numbers 中的条目，断言解析 round-trip；额外随机 RVA 验证回退链 level 单调
    - **Validates: Requirements 6.1, 6.2, 6.4**

  - [x] 3.4 实现 dedup.ps1
    - 创建 `scripts/autofix/dedup.ps1`
    - 入参：`-ErrorsFile <jsonl-path>` 或 `-Errors <json>`
    - 计算 `dedup_key = class + '|' + msg.Substring(0, 80) + '|' + top_stack_rva + '|' + scenario`
    - 按 key 分组，输出 group 数组（含 design §3.8.8 全部字段）
    - 排序：level 优先级 → stack_depth → count（design §3.8.8）
    - _Requirements: 5.1, 5.2, 5.3_

  - [x]* 3.5 写 PowerShell 属性测试 - dedup 分组完整性
    - 创建 `Tests/AutoFix/dedup.Tests.ps1`
    - **Property 9: dedup 分组完整性与排序**
    - ≥ 100 次随机错误列表，断言 `Σ count == |E|`、key 唯一、排序不变量、first/last_ts 正确
    - **Validates: Requirements 5.1, 5.2, 5.3**

  - [x] 3.6 实现 compiler.ps1
    - 创建 `scripts/autofix/compiler.ps1`
    - 入参：`-Project <dproj> -Config Debug -Platform Win64`
    - 先 `& "$env:DELPHI_ENV_BAT"` 或调用 `D:\_Progs\02Business\scripts\env\delphi-13.1.bat`
    - `msbuild ... /v:normal 2>&1` 收集输出
    - 用正则 `'^(.+?)\((\d+),(\d+)\)\s+(Error|Fatal|Warning|Hint)\s+([EFWH]\d+):\s+(.+)$'` 解析每行
    - 写 `compile-errors.json` 含 design §4.6 schema
    - 退出码：编译成功 0，编译失败 1，环境失败 102
    - _Requirements: 10.1, 10.2, 10.3_

  - [x]* 3.7 写 PowerShell 属性测试 - 编译错误解析
    - 创建 `Tests/AutoFix/compiler.Tests.ps1`
    - **Property 13: 编译错误解析结构化**
    - ≥ 100 次随机生成的错误行（合法格式 + 噪音行），断言解析仅提取合法行，字段类型/取值正确
    - **Validates: Requirements 10.2**

  - [x] 3.8 实现 git-checkpoint.ps1
    - 创建 `scripts/autofix/git-checkpoint.ps1`
    - 子命令：`-Action create|commit|discard|merge-back|cleanup`
    - `create`：`git worktree add <path> -b <branch>`，输出 worktree 路径；不在主工作树执行任何修改
    - `commit`：在 worktree 内 `git add -A` + `git commit -m`
    - `discard`：在 worktree 内 `git reset --hard HEAD` + `git clean -fd`（仅作用于 worktree，主树不受影响）
    - `merge-back`：在主树 `git merge --ff-only <branch>`（fail 时不强制）
    - `cleanup`：`git worktree remove` + `git branch -d`
    - 失败时退出 101 并写日志
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 3.9 实现 diff-guard.ps1
    - 创建 `scripts/autofix/diff-guard.ps1`
    - 入参：`-DiffFile <path> -AllowedPaths <glob-list-file> -BlockedPaths <glob-list-file> -MaxDiffLines 200`
    - 解析 unified diff 提取所有 `+++ b/<path>` 文件名
    - 校验顺序：blocked 先于 allowed；blocked 命中即拒；allowed 不命中即拒；行数超限即拒
    - 拒绝时退出 1 + 写违规记录到 `autofix-output/diff-violations.jsonl`
    - 通过时退出 0
    - 默认 BlockedPaths 内置（design §3.8.6）
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x]* 3.10 写 PowerShell 属性测试 - diff-guard 边界
    - 创建 `Tests/AutoFix/diff-guard.Tests.ps1`
    - **Property 11: diff-guard 边界守卫**
    - ≥ 100 次随机生成的 diff（随机文件路径 + 随机行数）+ 随机 allowed/blocked 配置，断言通过/拒绝判定与定义一致；拒绝时无副作用
    - **Validates: Requirements 8.1, 8.2, 8.3, 8.4, 8.5**

  - [x] 3.11 实现 fix-cache.ps1
    - 创建 `scripts/autofix/fix-cache.ps1`
    - 子命令：`-Action store|lookup|prune|clear`
    - 缓存目录：`autofix-output/.fix-cache/<sha1(key)>.json`
    - `store`：写 design §3.8.7 条目结构，对 preimage_files 数组中每个 path 计算 SHA-256
    - `lookup`：依次校验 (a) created 在 7 天内 (b) 每个 preimage 文件当前 SHA-256 == 记录值 (c) `git apply --check <patch>` exit 0；任一失败立刻删除条目并 return miss
    - `prune`：扫描所有条目，删除 created < now - 7d
    - `clear`：删除整个 .fix-cache/ 目录
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [x]* 3.12 写 PowerShell 属性测试 - Fix_Cache 失败即作废
    - 创建 `Tests/AutoFix/fix-cache.Tests.ps1`
    - **Property 12: Fix_Cache 失败即作废**
    - ≥ 100 次：随机 store + 随机修改其中一个 preimage 文件 → 断言 lookup miss + 条目消失；伪造 created 8 天前 → 断言 miss
    - **Validates: Requirements 9.1, 9.2, 9.3, 9.4, 9.5**

  - [x] 3.13 实现 wer-collector.ps1
    - 创建 `scripts/autofix/wer-collector.ps1`
    - 入参：`-ExeName <name> -Pid <int> -ExitCode <int> -RunId <uuid>`
    - 检查 `$env:LOCALAPPDATA\CrashDumps\<exe>.<pid>.dmp`
    - 存在时尝试 `cdb.exe -z <dmp> -c "!analyze -v;q"` 提取 ExceptionAddress + 模块；失败时回退
    - 始终至少写一条到 `runtime-errors.jsonl`：`class = "HardCrash" | "WerExtracted"`，含 `exit_code` 与运行时长
    - _Requirements: 13.1, 13.2, 13.3_

- [x] 4. Checkpoint - 阶段 2 单脚本编译与测试
  - 运行所有 PowerShell 测试：`Invoke-Pester Tests/AutoFix/*.Tests.ps1`
  - 运行 `cmd /c compile_test.bat` 确认 Pascal 改动仍编译通过
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Phase 3: 主循环 + AI 集成 + lint
  - [x] 5.1 实现 runner.ps1
    - 创建 `scripts/autofix/runner.ps1`
    - 入参：`-Exe <path> -RunId <uuid> -Iteration <int> -Scenarios <csv> -StartupTimeout 30 -ScenarioTimeout 600 -OutputDir <dir>`
    - `Start-Process -FilePath $Exe -ArgumentList @('--autofix-mode', "--autofix-run-id=$RunId", "--autofix-iteration=$Iteration", "--autofix-scenario=$Scenarios", "--autofix-output=$OutputDir") -PassThru`
    - 轮询 `health-signal.json`：直到 `run_id == 期望` 或超过 StartupTimeout（每 200ms 一次）
    - StartupTimeout 触发 → `Stop-Process` + 写合成 hard_crash 记录 + 退出 3
    - ready 后启动 ScenarioTimeout 计时；超过则 `Stop-Process -Force` + 写合成超时 exit-reason.json + 退出 3
    - 进程正常退出后返回真实 exit_code
    - _Requirements: 2.4, 3.1, 3.2, 3.3_

  - [x] 5.2 实现 ai-call.ps1（含 backend 抽象）
    - 创建 `scripts/autofix/ai-call.ps1`
    - 入参：`-Backend claude|openai|cli -Error <json> -Context <text> -AllowedPaths <list>`
    - Backend 实现可插拔：每种 backend 写为同目录的 `ai-call.<backend>.ps1` 子模块
    - 系统 prompt 模板包含：错误结构化描述、解析后的源码片段（仅 AllowedPaths 内 ±50 行）、AllowedPaths 与 BlockedPaths 文字描述
    - 输出：标准 unified diff 文本（写入临时文件 + 返回路径）
    - 任何 backend 失败 → 退出 103
    - 禁止硬编码密钥；从环境变量读：`AUTOFIX_AI_KEY` / `AUTOFIX_AI_ENDPOINT`
    - _Requirements: 8.5_

  - [x] 5.3 实现 lint 脚本三件套
    - 创建 `scripts/autofix/lint-pascal-deps.ps1`
      - grep 所有 `Core/DeepBase.AutoFix.*.pas` 与 `VCL/DeepBase.AutoFix.VclHook.pas` 的 `uses` 子句不含 `Jcl*` / `MadExcept*`
    - 创建 `scripts/autofix/lint-powershell-strict.ps1`
      - 检查 `scripts/autofix/*.ps1`（除 `_common.ps1` 自身）前 3 行通过 dot-source 加载 `_common.ps1` 或显式包含 `Set-StrictMode -Version Latest` + `$ErrorActionPreference = 'Stop'`
    - 创建 `scripts/autofix/lint-no-reset-hard.ps1`
      - grep `git-checkpoint.ps1` 仅在 `discard` 分支内含 `git reset --hard`，且作用域参数指向 worktree
    - 三个脚本失败时 exit 1 + stderr 描述违规
    - _Requirements: 1.6, 7.1, 12.1_

  - [x] 5.4 实现 autofix.ps1 主循环（核心）
    - 创建 `scripts/autofix/autofix.ps1`
    - 入参：`-Project -Scenarios -MaxIterations 10 -ScenarioTimeout 600 -AllowedPaths -BlockedPaths -AiBackend -OutputDir`
    - 在循环开始前调用三件 lint 脚本，任一失败则中止
    - 调用 `git-checkpoint.ps1 -Action create` 创建 worktree
    - 主循环：按 design §3.8.1 / §2.2 时序图实现
      - 每轮生成新 `[guid]::NewGuid()` 作为 RunId
      - 执行 runner.ps1 → 读 jsonl 时按 `run_id == $expectedRunId` 过滤
      - 无错误且 exit_code 0 → 标记成功并 break
      - 无 exit-reason 且 exit_code 非 0 → wer-collector
      - dedup → map-parser → 振荡检测（`@history` 数组追踪每个 dedup_key 的修复-再现次数 ≥ 3）
      - fix-cache lookup → 命中直接 git apply；未命中 → ai-call → diff-guard → git apply
      - compiler.ps1 失败 → ai-call 重试一次 → 仍失败 → discard
      - commit / discard 视编译结果
      - append iteration-summary.jsonl
    - 退出码按 design §4.8 错误码表
    - _Requirements: 5.1, 5.2, 6.1, 7.2, 7.3, 7.4, 8.3, 9.1, 10.4, 11.1, 11.2, 11.3, 11.4, 11.5_

  - [x]* 5.5 写 PowerShell 属性测试 - max-iter 与振荡终止
    - 创建 `Tests/AutoFix/autofix-loop.Tests.ps1`
    - **Property 14: max-iter 不变量与振荡终止**
    - mock runner / ai-call / compiler 为可控函数；≥ 100 次：随机 max_iter ∈ [1, 30] + 随机 dedup_key 出现模式 → 断言迭代不超额；强制让某 key 反复 ≥ 3 次 → 断言被标记 unfixable
    - **Validates: Requirements 11.3, 11.4**

  - [x]* 5.6 写 PowerShell 属性测试 - iteration-summary 完整性
    - 同测试文件
    - **Property 15: iteration-summary 完整性**
    - ≥ 100 次随机循环结果，断言 jsonl 行数 == 已完成迭代次数；每行字段齐全；iteration 单调递增无缺号
    - **Validates: Requirements 11.5**

  - [x]* 5.7 写 PowerShell 属性测试 - 严格模式失败传播
    - 创建 `Tests/AutoFix/strict-mode.Tests.ps1`
    - **Property 16: PowerShell 严格模式失败传播**
    - ≥ 100 次：在每个 ps1 内插入一条故意失败的命令，断言脚本退出码非零
    - **Validates: Requirements 12.2**

- [x] 6. Checkpoint - 阶段 3 主循环干跑
  - 运行所有 lint 脚本，全部 exit 0
  - 运行所有 Pester 测试
  - 用 mock backend 跑一次 autofix.ps1（无真实 AI 调用），验证 jsonl 文件 schema 正确
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Phase 4: 集成入口与跨模块属性
  - [x] 7.1 集成 facade 到 DeepBaseRun.dpr 示例
    - 修改 `DeepBaseRun/<dpr-file>.dpr`（确认实际 dpr 路径，可能为 `DeepBaseRun.dpr` 或 `DeepBase.dpr`）
    - 在 `Application.Initialize` 之前增加：
      ```
      AutoFix.Install;
      {$IFDEF MSWINDOWS}
      TAutoFixVclHook.Install;
      {$ENDIF}
      ```
    - 在主窗体的 `AfterShellShown` / `OnShow` 增加 `AutoFix.NotifyShellShown`
    - 注册若干示例 scenario：`AutoFix.RegisterScenario('scan', procedure begin … end);`
    - 编译门禁：`cmd /c compile_test.bat` 返回 0
    - _Requirements: 14.1, 14.2_

  - [x] 7.2 校验包间依赖与构建顺序
    - 确认 `DeepBaseCore.dpk` contains 列表新增：`DeepBase.AutoFix`、`DeepBase.AutoFix.StackWalker`、`DeepBase.AutoFix.ErrorRecorder`、`DeepBase.AutoFix.SelfTerminator`、`DeepBase.AutoFix.HealthSignal`、`DeepBase.AutoFix.ScenarioRunner`
    - 确认 `DeepBaseVCL.dpk` contains 新增：`DeepBase.AutoFix.VclHook`，requires 含 `DeepBaseCore`
    - 确认 `dclDeepBaseCore.dpk` 不重复 contains 这些运行时单元（仅 requires DeepBaseCore）
    - 编译门禁：`cmd /c compile_test.bat` 与 `cmd /c rebuild_test.bat`（如存在）均返回 0
    - _Requirements: 14.4_

  - [ ]* 7.3 写跨模块属性测试 - 退出码与错误状态一致性
    - 创建 `Tests/AutoFix/Test.DeepBase.AutoFix.ExitCodes.pas`
    - **Property 5: 退出码与错误状态一致性**
    - 这个属性需要 spawn 真实子进程；在测试中调用 `CreateProcess` 启动测试用 EXE（用 `Tests/AutoFix/Fixtures/AutoFixHarness.dpr` 编译而成），传不同 scenario 触发 0/1/2 三种路径，断言 ExitCode 符合预期
    - ≥ 100 次随机组合（场景列表、是否触发 fatal、TotalErrors）
    - **Validates: Requirements 2.3, 4.3, 11.2**

  - [ ]* 7.4 写跨模块属性测试 - fatal 路径完整性
    - 同测试单元
    - **Property 6: Fatal 路径完整性**
    - ≥ 100 次：fixture EXE 中触发不同 fatal 异常类，子进程退出后解析 exit-reason.json 断言 10 个字段齐全
    - **Validates: Requirements 2.1, 2.2**

  - [x]* 7.5 写属性测试 - HealthSignal 字段与一致性
    - 创建 `Tests/AutoFix/Test.DeepBase.AutoFix.HealthSignal.pas`
    - **Property 7: HealthSignal 字段与 RunId 一致性**
    - ≥ 100 次模拟 Emit，断言字段齐全 + run_id == ErrorRecorder.RunId
    - **Validates: Requirements 3.1**

  - [x]* 7.6 写属性测试 - ScenarioRunner 顺序与结果
    - 创建 `Tests/AutoFix/Test.DeepBase.AutoFix.ScenarioRunner.pas`
    - **Property 8: ScenarioRunner 顺序与结果记录**
    - ≥ 100 次随机注册 + 命令行序列 + 抛/不抛异常的 callback；断言执行顺序与终态记录一致
    - **Validates: Requirements 4.1, 4.2, 4.4**

  - [x]* 7.7 写属性测试 - WER 保底
    - 创建 `Tests/AutoFix/wer-collector.Tests.ps1`
    - **Property 17: WER/合成记录保底**
    - mock CrashDumps 目录与 cdb.exe；≥ 100 次：随机有/无 dmp + 随机 exit_code → 断言 jsonl 至少一条合成记录且字段正确
    - **Validates: Requirements 13.1, 13.3**

  - [x]* 7.8 写属性测试 - Install 幂等与零开销
    - 在 `Test.DeepBase.AutoFix.ErrorRecorder.pas` 增加
    - **Property 18 + Property 19**
    - 18: ≥ 100 次重复 Install + RegisterScenario，断言 ExceptProc 仅替换一次 + 同名 scenario 仅最后一次有效
    - 19: 不带 `--autofix-mode` 启动后触发异常 + 注册场景，断言 `autofix-output/` 目录无任何写入
    - **Validates: Requirements 14.1, 14.2, 14.3**

- [x] 8. Phase 5: 端到端 dry-run 验证
  - [x] 8.1 创建 e2e fixture 项目
    - 创建 `Tests/AutoFix/Fixtures/AutoFixHarness.dpr` 与配套 dproj
    - 内含 3 个 scenario：`pass`（成功）、`error`（抛 EConvertError）、`fatal`（抛 EAccessViolation）
    - 用 `AutoFix.Install` + `TAutoFixVclHook.Install`（控制台 EXE 模式可不挂 VCL hook，仅依赖 L2 ExceptProc）
    - 编译门禁：`cmd /c compile_test.bat` 通过（如需新增 dproj 到 Tests 群组）
    - _Requirements: 14.1_

  - [x] 8.2 写 e2e dry-run 主脚本
    - 创建 `Tests/AutoFix/e2e-dry-run.ps1`
    - 步骤：
      1. 调三件 lint，要求全 0
      2. mock ai-call.ps1 返回固定 diff（修复 fixture 中故意的 bug）
      3. 调 autofix.ps1 跑 1 轮（max_iter=1），针对 fixture
      4. 断言 5 类文件结构正确：health-signal.json / runtime-errors.jsonl / scenario-results.jsonl / exit-reason.json / iteration-summary.jsonl
      5. 断言 worktree 已清理（`git worktree list` 不含临时分支）
    - 失败时输出全部产物路径供人工查看
    - _Requirements: 11.1, 11.5_

  - [x] 8.3 写文档版本一致性验证脚本
    - 创建 `scripts/autofix/lint-doc-version.ps1`
    - 校验 `design.md` 头部 `**版本**: v2.0`、`Changelog` 段存在且至少 2 条记录
    - 失败 exit 1
    - _Requirements: 15.1, 15.2, 15.3_

- [x] 9. Final Checkpoint - 完整门禁
  - 运行 `cmd /c compile_test.bat` ⇒ exit 0
  - 运行所有 lint：`pascal-deps`, `powershell-strict`, `no-reset-hard`, `doc-version`
  - 运行所有 DUnitX 测试（`Tests/AutoFix/*`）
  - 运行所有 Pester 测试（`Tests/AutoFix/*.Tests.ps1`）
  - 运行 `Tests/AutoFix/e2e-dry-run.ps1`
  - 全部通过即视为 v2.0 实施完成
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- 标记 `*` 的子任务为可选 PBT 测试，可跳过以加速 MVP；核心实现任务**不带** `*` 的必须完成
- 每个父任务结束都通过编译门禁 `cmd /c compile_test.bat`
- Pascal 代码必须遵循 Delphi 13.1 规范：inline var、条件表达式、不引入 with、不用 VER340、显式 `TEncoding.UTF8`、`{$IF CompilerVersion >= 37}`
- PowerShell 脚本必须 dot-source `_common.ps1` 或显式 StrictMode + Stop pref
- 所有任务严格指明涉及文件路径与对应 requirements 编号；实施时按顺序逐任务推进
- 19 条 design properties 与对应 PBT 测试一一映射：P1→1.8, P2→1.9, P3+P4→1.10, P5→7.3, P6→7.4, P7→7.5, P8→7.6, P9→3.5, P10→3.3, P11→3.10, P12→3.12, P13→3.7, P14→5.5, P15→5.6, P16→5.7, P17→7.7, P18+P19→7.8
- 实施完成后用户可在 `tasks.md` 中点击「Start task」逐项执行
