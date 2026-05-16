# AutoFix AI CLI 使用指南

> 本文档说明如何配置不同 AI CLI 工具与 AutoFix 外部脚本配合使用。

---

## 1. 支持的 AI CLI

| CLI | 模式 | 适用场景 |
|-----|------|----------|
| Kiro（当前 IDE） | 交互式会话 | 开发者在场，手动触发 |
| Claude Code CLI | 无人值守 | 本地后台运行 |
| Aider | 无人值守 | 开源替代 |

---

## 2. 通用 Prompt 模板

所有 AI CLI 调用时使用以下 prompt 结构：

```text
【安全约束 — 不可违反】
- 只修改以下目录内的 .pas/.dfm 文件：src/
- 禁止修改：DeepBase 框架、.dproj、.dpr、脚本、二进制、boundary.json
- 修改必须最小化，只修复报告的错误
- 不得引入新依赖

【运行时错误】
- 异常类型：{class}
- 异常消息：{msg}
- 模块：{module}
- RVA：{rva}
- 场景：{context}
- 出现次数：{occurrence_count}

【源码定位】
{map_resolved_lines}

【如果 map 解析失败】
- Map 文件：{map_path}
- 原始地址：{module}:{rva}
- 请在 src/ 目录下搜索相关代码自行定位

【要求】
1. 修复上述运行时错误
2. 确保修改后能通过 msbuild 编译
3. 不要修改不相关的代码
```

编译错误修复时使用：

```text
【安全约束 — 同上】

【编译错误】
{compile_errors_content}

【要求】
1. 修复编译错误
2. 不要引入新的运行时问题
3. 修改最小化
```

---

## 3. Claude Code CLI 配置

### 安装

```powershell
npm install -g @anthropic-ai/claude-code
```

### 在 autofix.ps1 中调用

```powershell
# 设置工作目录为 worktree
$env:ANTHROPIC_API_KEY = "..."  # 或从安全存储读取

$promptFile = Join-Path $OutputDir "fix-prompt.txt"
$prompt | Out-File $promptFile -Encoding UTF8

# 调用 Claude Code（单次执行，非交互）
$result = claude -p $prompt --output-format json --max-turns 3 2>&1

# 检查是否有文件修改
$changed = git -C $WorktreePath status --porcelain
if (-not $changed) {
    Write-Host "⚠ AI 未做任何修改"
}
```

### 关键参数

| 参数 | 说明 |
|------|------|
| `-p` | 传入 prompt（非交互模式） |
| `--max-turns 3` | 限制对话轮次 |
| `--allowedTools` | 限制可用工具（只允许文件编辑） |
| `--disallowedTools` | 禁止 shell 执行等危险操作 |

---

## 4. Aider 配置

### 安装

```powershell
pip install aider-chat
```

### 在 autofix.ps1 中调用

```powershell
# Aider 需要指定要编辑的文件
$filesToEdit = $sourceLines | ForEach-Object {
    # 从 map 解析结果提取文件路径
    if ($_ -match '→\s+(.+\.pas):\d+') { $Matches[1] }
} | Select-Object -Unique

$fileArgs = $filesToEdit | ForEach-Object { "--file $_" }

aider --message $prompt $fileArgs --no-auto-commits --yes-always 2>&1
```

### 关键参数

| 参数 | 说明 |
|------|------|
| `--message` | 单次 prompt |
| `--no-auto-commits` | 不自动 commit（由 autofix 控制） |
| `--yes-always` | 自动确认修改 |
| `--file` | 指定可编辑文件（配合 boundary） |

---

## 5. Kiro（当前 IDE 会话）

Kiro 作为当前会话内的 AI，不需要 CLI 调用。autofix.ps1 在这种模式下：

1. 输出错误摘要到控制台
2. 暂停等待用户在 Kiro 中完成修复
3. 用户确认后继续下一轮

```powershell
if ($AIMode -eq 'kiro') {
    Write-Host "=== 请在 Kiro 中修复以下错误 ==="
    Write-Host $fixPrompt
    Write-Host "=== 修复完成后按 Enter 继续 ==="
    Read-Host
}
```

---

## 6. AI 模式选择

autofix.ps1 通过 `-AIMode` 参数选择：

```powershell
param(
    [ValidateSet('kiro', 'claude-code', 'aider', 'dry-run')]
    [string]$AIMode = 'kiro'
)
```

| 模式 | 行为 |
|------|------|
| `kiro` | 暂停等待人工在 IDE 中修复 |
| `claude-code` | 调用 Claude Code CLI 自动修复 |
| `aider` | 调用 Aider 自动修复 |
| `dry-run` | 只输出 prompt，不调用 AI（调试用） |

---

## 7. 安全注意事项

- **API Key 管理**：不要硬编码在脚本中。使用环境变量或 Windows Credential Manager。
- **外部模型默认禁用**：`claude-code` 和 `aider` 模式需要显式 `-AIMode` 参数才启用。
- **Prompt 脱敏**：异常消息中可能含敏感数据（连接串、路径），传给外部 AI 前需脱敏。
- **网络隔离**：如果项目含敏感代码，建议只用 `kiro` 模式（本地会话，不外发）。

---

## 8. 快速开始

```powershell
# 最简单的用法：手动模式，Kiro 辅助
.\autofix.ps1 -ProjectName DeepSpec -Scenarios "open-project,scan"

# 无人值守：Claude Code
.\autofix.ps1 -ProjectName DeepSpec -Scenarios "open-project,scan" -AIMode claude-code

# 调试：只看 prompt 不调 AI
.\autofix.ps1 -ProjectName DeepSpec -Scenarios "open-project,scan" -AIMode dry-run
```

---

*文档版本：v1.0 · 2026-05-15*
