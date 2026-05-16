# DeepBase AutoFix：AI 自动修复运行时错误方案

> 日期：2026-05-15  
> 版本：v2.4-simple  
> 状态：核心方案简化版  
> 加固项：见 `AutoFix-Hardening.md`

目标：用尽量少的基础设施跑通一个可靠闭环：

```text
运行场景 → 记录运行时错误 → 退出 → AI 修改源码 → 编译 → 再运行
```

本文件只描述 MVP 必须实现的内容。安全、审计、外部模型、dump、CI、精确调用栈等增强项放到 `AutoFix-Hardening.md`，避免第一版过度工程化。

---

## 1. MVP 边界

### 做

- 支持本地开发机运行。
- 支持一个项目、一个 AutoFix 会话。
- 默认不自动 merge，只生成修复分支。
- AI 只修改应用层源码。
- 以场景是否通过和运行时错误是否为 0 作为成功标准。

### 暂不做

- 不做无人值守外部模型外发。
- 不做 CI 自动合并。
- 不做 VEH 精确异常栈。
- 不做 full dump 自动分析。
- 不做复杂补丁缓存。

---

## 2. 核心流程

```text
1. 创建临时 git worktree
2. 编译项目到 build-out
3. 启动 EXE，传入 --autofix-run-id 和 --autofix-scenario
4. EXE 写入：
   - runtime-errors.jsonl
   - scenario-results.jsonl
   - exit-reason.json
5. 外部脚本判断结果：
   - exit_code = 0
   - 所有场景 pass
   - 当前 run_id 无 runtime error
6. 如果失败：
   - 取第一个去重后的错误
   - 用 .map 定位源码
   - 调 AI 修改 worktree 内源码
   - 编译
   - 编译通过后提交到修复分支
7. 重新运行，直到成功或达到上限
```

成功后输出修复分支名，由开发者 review 后手动 merge。

---

## 3. EXE 内置能力

### 3.1 ErrorRecorder

职责：在 AutoFix mode 下记录异常到 `runtime-errors.jsonl`。

Phase 1 只要求三层捕获：

| 层 | 机制 | 说明 |
|----|------|------|
| L1 | `Application.OnException` | VCL 主线程异常 |
| L2 | `System.ExceptProc` | 未处理 Delphi 异常，链式调用旧 handler |
| L3 | `SafeRun` / 线程包装 | DeepBase 管理的后台线程 |

不承诺覆盖所有 native crash。进程直接崩溃时由 runner 视为 crash。

最小记录格式：

```jsonl
{"run_id":"...","ts":"...","level":"fatal","class":"EAccessViolation","msg":"...","module":"DeepSpec.exe","rva":"$00005A2F","context":"scan","thread":"main","dedup_key":"EAccessViolation|scan|DeepSpec.exe:$00005A2F"}
```

注意：记录 module + rva（相对虚拟地址），不记录绝对地址。ASLR 下绝对地址每次不同，会导致 dedup_key 失效。RVA = addr - GetModuleHandle(module)。

实现要求：

- 写入必须加锁。
- 每行写完立即 flush。
- handler 内部异常必须吞掉，不能递归崩溃。
- `Application.OnException` 和 `ExceptProc` 必须保存并调用旧 handler。

### 3.2 ScenarioRunner

职责：按命令行场景顺序执行，并增量写 `scenario-results.jsonl`。

```jsonl
{"run_id":"...","name":"open-project","status":"running","ts":"..."}
{"run_id":"...","name":"open-project","status":"pass","duration_ms":1200}
{"run_id":"...","name":"scan","status":"running","ts":"..."}
{"run_id":"...","name":"scan","status":"fatal","class":"EAccessViolation"}
```

终态只认这些值：

```text
pass / fail / fatal / timeout / crashed / startup_failed
```

成功必须是所有请求场景最后状态均为 `pass`。

### 3.3 SelfTerminator

Fatal 异常时：

1. 尝试把当前场景写成 `fatal`。
2. flush 日志。
3. 写 `exit-reason.json`。
4. `Halt(2)`。

```json
{"run_id":"...","exit_code":2,"reason":"fatal_exception","class":"EAccessViolation","msg":"..."}
```

### 3.4 HealthSignal

启动完成后写 `health-signal.json`：

```json
{"run_id":"...","ready":true,"pid":12345,"scenarios":["open-project","scan"]}
```

runner 必须校验 `run_id`，不匹配视为旧文件。

---

## 4. 外部工具

### 4.1 autofix.ps1

主循环职责：

- 创建 worktree。
- 调 compiler。
- 调 runner。
- 判断成功/失败。
- 调 AI。
- 做最小边界检查。
- 成功后 commit 到修复分支。

关键规则：

- 默认 `MaxIterations = 10`。
- 默认 `MaxCompileFixAttempts = 2`。
- 默认不 merge。
- 任意 native command 失败必须检查 exit code。
- 所有 JSONL 写入使用单行 JSON。

### 4.2 runner.ps1

职责：启动 EXE，并返回结构化状态。

状态集合：

```text
normal / timeout / crash / startup_failed
```

runner 必须做三件事：

- health 超时：写所有未完成场景为 `startup_failed`。
- 运行超时：kill 进程，写所有未完成场景为 `timeout`。
- 异常退出：写所有未完成场景为 `crashed`。

### 4.3 compiler.ps1

职责：编译 worktree 内项目，输出到 worktree 外的 build-out。

要求：

- 编译产物不写入 worktree。
- 编译错误写到 output 目录。
- 脚本本身不要直接 `exit` 当前主循环；返回 `{ success, exit_code, log_path }`。

### 4.4 map-resolver.ps1

Phase 1 只要求解析主 EXE 的 `.map`。

解析失败时不要阻断流程，直接把 map 路径 + 原始地址 + 异常类名传给 AI，让 AI 自己 grep 源码定位。不引入额外搜索逻辑。

BPL/DLL、多模块精确匹配放到 hardening。

### 4.5 boundary-check.ps1

MVP 只做最小强约束：

- `boundary.json` 缺失则停止。
- 只允许修改 `allowed_paths`。
- 强制禁止修改：
  - DeepBase 框架源码
  - `.dproj` / `.dpr`
  - `.ps1` / `.bat` / `.cmd`
  - `bin/` / `dcu/` / build 输出
  - `boundary.json`
- 检查 tracked + untracked 文件。

示例：

```json
{
  "allowed_paths": ["src/"],
  "blocked_paths": ["DeepBase/", "*.dproj", "*.dpr", "*.ps1", "*.bat", "*.cmd", "bin/", "dcu/"],
  "max_changed_files": 5,
  "max_diff_lines": 200
}
```

---

## 5. 成功与失败判定

一次运行成功必须同时满足：

1. runner 状态为 `normal`。
2. 进程退出码为 `0`。
3. 所有请求场景最后状态均为 `pass`（runner 内部已校验 health run_id）。
4. 当前 `run_id` 下 `runtime-errors.jsonl` 为空。

以下情况立即停止，交给人工：

- 同一 `dedup_key` 修复 3 次仍失败。
- 连续 2 次 crash。
- boundary check 失败。
- 编译修复达到上限仍失败。
- scenario 没有错误但连续 2 次不能全 pass。

---

## 6. AI 调用原则

MVP 默认使用当前本地 AI agent 会话，不做外部模型无人值守外发。

Prompt 只包含：

- 异常类型和消息。
- 场景名。
- `.map` 定位结果或原始地址。
- 相关源码文件路径。
- 编译错误摘要。

必须明确约束：

```text
只修改 boundary.json 允许的应用层源码。
不要修改 DeepBase 框架、工程文件、脚本、二进制、生成物。
修改要最小化。
```

Phase 1 不做修复缓存，每次都调 AI。

---

## 7. 开发者接入

最小接入：

```pascal
uses DeepBase.AutoFix.ErrorRecorder;

begin
  TAutoFixErrorRecorder.Install;
  ...
end.
```

推荐再注册场景：

```pascal
AutoFix.RegisterScenario('open-project', procedure
begin
  Controller.OpenProject(TestProjectPath);
end);

AutoFix.RegisterScenario('scan', procedure
begin
  Controller.RunScan;
end);
```

项目需要：

- 开启 detailed map：`DCC_MapFile=3`。
- 提供 `boundary.json`。
- 后台线程尽量用 `SafeRun` 或 DeepBase 线程包装器。

---

## 8. 实施计划

### Phase 1：可运行 MVP

- [ ] `ErrorRecorder`：L1/L2/L3 捕获、JSONL、flush、旧 handler 链式调用
- [ ] `ScenarioRunner`：running/pass/fail/fatal 增量 JSONL
- [ ] `SelfTerminator`：fatal 退出
- [ ] `HealthSignal`
- [ ] `runner.ps1`：normal/timeout/crash/startup_failed 结构化状态 + 场景终态补齐
- [ ] `compiler.ps1`
- [ ] `map-resolver.ps1`：主 EXE map
- [ ] `boundary-check.ps1`
- [ ] `autofix.ps1` 主循环
- [ ] DeepSpec 项目 `boundary.json` 初始配置

### Phase 2：可靠性补齐

- [ ] 去重与简单震荡检测
- [ ] 编译失败 AI 修复内循环
- [ ] 审计 artifact 最小输出
- [ ] timeout/crash/startup_failed 回归测试
- [ ] DeepSpec 注入错误验证

### Phase 3：加固增强

见 `AutoFix-Hardening.md`。

---

## 9. 最小验收标准

用 DeepSpec 做一次端到端验证：

1. 人为注入一个稳定运行时错误。
2. `autofix.ps1` 能运行场景并捕获错误。
3. AI 修改只发生在 allowed paths。
4. 编译通过。
5. 再运行后所有场景 pass。
6. 生成修复分支，不自动 merge。

---

*文档版本：v2.4-simple · 2026-05-15*
