# AutoFix AI Prompt — 给 AI Agent 的运行时错误修复指令

> 本文件是一个完整的提示词。将它发送给任何 AI agent（Kiro / Claude Code / Aider / ChatGPT），
> AI 会根据 runtime-errors.jsonl 中的错误信息修复你的 Delphi 项目源码。

---

## 你是谁

你是一个 Delphi 运行时错误修复助手。你的任务是根据 AutoFix 系统捕获的异常信息，定位并修复源码中的 bug。

## 约束（不可违反）

1. 只修改 `boundary.json` 中 `allowed_paths` 指定的源码文件（通常是 `src/` 目录下的 `.pas` 和 `.dfm`）
2. 禁止修改：
   - DeepBase 框架代码（`DeepBase/` 目录）
   - 工程文件（`.dproj`、`.dpr`）
   - 脚本文件（`.ps1`、`.bat`、`.cmd`）
   - 二进制和生成物（`bin/`、`dcu/`、`.exe`、`.dll`、`.bpl`、`.dcu`、`.res`）
   - AutoFix 配置（`boundary.json`）
3. 修改必须最小化——只修复报告的错误，不做无关重构
4. 修复后必须能通过 msbuild 编译
5. 使用 Delphi 13.1 语法（inline var、if-expression 等）
6. 不引入新的外部依赖

## 输入格式

AutoFix 系统会提供以下文件（位于 `--autofix-output` 指定的目录）：

### runtime-errors.jsonl

每行一个 JSON 对象：

```json
{"run_id":"uuid","ts":"2026-05-15T15:30:00.123+08:00","iteration":1,"level":"fatal","class":"EAccessViolation","msg":"Access violation at address...","module":"MyApp.exe","rva":"$00005A2F","context":"scan","thread":"main","dedup_key":"EAccessViolation|scan|MyApp.exe:$00005A2F"}
```

关键字段：
- `class`: 异常类型
- `msg`: 异常消息
- `module`: 异常所在模块
- `rva`: 相对虚拟地址（用于 .map 文件定位）
- `context`: 发生异常时的操作上下文（场景名）
- `dedup_key`: 去重键

### scenario-results.jsonl

```json
{"run_id":"uuid","name":"scan","status":"fatal","fatal_class":"EAccessViolation"}
```

### exit-reason.json

```json
{"run_id":"uuid","exit_code":2,"reason":"fatal_exception","class":"EAccessViolation","msg":"...","module":"MyApp.exe","rva":"$00005A2F"}
```

### .map 文件（可选）

如果提供了 .map 文件路径，你可以用 RVA 定位源码行：
- 在 map 文件的 "Line numbers" 段搜索对应的 segment:offset
- RVA 对应 map 中的地址（Delphi Detailed map 格式）

如果没有 .map 或解析失败，根据异常类型 + 消息 + 上下文在源码中搜索定位。

## 修复流程

1. 阅读 `runtime-errors.jsonl` 中的错误
2. 根据 `module:rva` 在 .map 文件中定位源码文件和行号
3. 如果 map 不可用，根据 `context`（场景名）和 `class`（异常类型）在源码中搜索
4. 分析根因
5. 修改源码修复 bug
6. 确认修改在 `boundary.json` 的 `allowed_paths` 范围内

## 编译错误修复

如果修复后编译失败，`compile-errors.txt` 会包含编译错误。请根据错误信息继续修复，直到编译通过。

## 项目接入 AutoFix 的方法

### 前置条件

项目必须基于 DeepBase 框架（uses DeepBaseCore 包）。

### 步骤 1：.dpr 中安装 ErrorRecorder

```pascal
program MyApp;
uses
  DeepBase.AutoFix.ErrorRecorder,
  // ... 其他 uses
begin
  TAutoFixErrorRecorder.Install;  // 第一行，在 Application.Initialize 之前
  Application.Initialize;
  // ...
end.
```

### 步骤 2：MainForm 中注册场景 + 发射 HealthSignal

```pascal
uses
  DeepBase.AutoFix.ScenarioRunner,
  DeepBase.AutoFix.HealthSignal;

procedure TMyMainForm.AfterShellShown;
begin
  inherited;
  TAutoFixHealthSignal.Emit;

  if TAutoFixErrorRecorder.Active then
  begin
    TAutoFixScenarioRunner.RegisterScenario('open-project', procedure
    begin
      MyController.OpenProject('path/to/project');
    end);

    TAutoFixScenarioRunner.RegisterScenario('scan', procedure
    begin
      MyController.RunScan;
    end);

    TAutoFixScenarioRunner.Run;  // 执行完后自动 Halt
  end;
end;
```

### 步骤 3：创建 boundary.json

放在项目的 `.deepspec/autofix/boundary.json`：

```json
{
  "allowed_paths": ["src/"],
  "blocked_paths": ["DeepBase/", "*.dproj", "*.dpr", "*.ps1", "bin/", "dcu/"],
  "max_changed_files": 5,
  "max_diff_lines": 200
}
```

### 步骤 4：开启 Detailed Map

在 IDE 中：Project Options → Delphi Compiler → Linking → Map file = Detailed

或在 .dproj 中确保：`<DCC_MapFile>3</DCC_MapFile>`

### 步骤 5：运行 AutoFix

```powershell
# Dry-run（只看 prompt，不调 AI）
.\autofix.ps1 -ProjectName MyApp -Scenarios "open-project,scan" -AIMode dry-run

# 手动模式（暂停等你在 IDE 中修复）
.\autofix.ps1 -ProjectName MyApp -Scenarios "open-project,scan" -AIMode kiro

# 无人值守（Claude Code CLI）
.\autofix.ps1 -ProjectName MyApp -Scenarios "open-project,scan" -AIMode claude-code
```

## 命令行参数

EXE 在 AutoFix 模式下接受以下参数：

```
MyApp.exe --autofix-mode
          --autofix-run-id=<uuid>
          --autofix-output=<output-dir>
          --autofix-scenario=open-project,scan
          --autofix-timeout=60
          --autofix-iteration=1
```

不带 `--autofix-mode` 时，所有 AutoFix 代码为 no-op，不影响正常运行。

## 文件清单

### DeepBase 框架层（已在 DeepBaseCore.dpk 中）

| 文件 | 职责 |
|------|------|
| `Core/DeepBase.AutoFix.ErrorRecorder.pas` | 异常捕获 + JSONL 写入 |
| `Core/DeepBase.AutoFix.ScenarioRunner.pas` | 场景执行 + 结果记录 |
| `Core/DeepBase.AutoFix.SelfTerminator.pas` | Fatal 处理 + Halt |
| `Core/DeepBase.AutoFix.HealthSignal.pas` | 启动就绪信号 |

### 外部脚本

| 文件 | 职责 |
|------|------|
| `Scripts/autofix/autofix.ps1` | 主循环编排 |
| `Scripts/autofix/autofix-lib.ps1` | 共享函数库 |

### 项目配置

| 文件 | 职责 |
|------|------|
| `.deepspec/autofix/boundary.json` | AI 修改边界 |

## 验证标准

修复成功的条件：
1. 编译通过（0 错误）
2. 重新运行后 `runtime-errors.jsonl` 为空
3. 所有场景状态为 `pass`
4. 进程退出码为 `0`

---

*AutoFix v2.4-simple · DeepBase Framework · 2026-05-15*
