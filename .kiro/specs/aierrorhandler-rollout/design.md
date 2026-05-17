# Design: AIErrorHandler Rollout

**版本**: v1.0
**适用 requirements**: `.kiro/specs/aierrorhandler-rollout/requirements.md`

## 1. 概览

本特性扩展现有的 `Core/DeepBase.AIErrorHandler.pas`（VCL 弹窗型 OnException handler），新增两个分层单元，使得整个 AIErrorHandler 子系统能在测试 / CI / 服务端等非交互式场景下安全运行：

```
   ┌─────────────────────────────────────────────────────────────┐
   │ Application code (.dpr)                                     │
   │   InstallAIErrorHandler(bmAuto);   // one-line entry        │
   └─────────────────────┬───────────────────────────────────────┘
                         │
   ┌─────────────────────▼─────────┐    ┌──────────────────────┐
   │ DeepBase.AIErrorHandler       │    │ DeepBase.AIErrorHandl│
   │ .Bootstrap   (façade)         │    │ er.LLMBridge (adapter│
   │   - Mode detection            │    │   - SetAICallback to │
   │   - SilentMode resolution     │────►   LLM.Chat(TierFast) │
   │   - InstallLLMBridge call     │    │   - Never raises     │
   │   - Idempotency               │    └──────────┬───────────┘
   └────────────┬──────────────────┘               │
                │                                  │
                ▼                                  ▼
   ┌────────────────────────────┐   ┌─────────────────────────┐
   │ DeepBase.AIErrorHandler    │   │ DeepBase.LLM.Service    │
   │ (existing core)            │   │ (Features package)      │
   │   - +SilentMode field      │   │   - LLM(): ILLMClient   │
   │   - +FOldAppException      │   │   - Chat(TierFast, ...) │
   │   - elFatal silent path    │   └─────────────────────────┘
   │   - Logger.Warn/Error/Fatal│
   └────────────────────────────┘
```

## 2. 模块设计

### 2.1 DeepBase.AIErrorHandler.pas（已存在，本特性增改）

**新增字段**：
- `TAIErrorConfig.SilentMode: Boolean = False`
- `TAIErrorHandler.FOldAppException: TExceptionEvent`（class var）

**修改的方法**：

| 方法 | 改动 |
| --- | --- |
| `TAIErrorConfig.Default` | 设置 `Result.SilentMode := False` |
| `Install(AConfig)` | 在覆盖 `Application.OnException` 前保存到 `FOldAppException` |
| `Handle.elAutoFix` | 把 `DeepBase.Logging.Log(ltWarning, ...)` 替换为 `Logger.Warn(...)` |
| `Handle.elAIAnalyze` | `MessageDlg` 调用包在 `if not FConfig.SilentMode then`；logging 升级为 `Logger.Error(...)` |
| `Handle.elFatal` | 升级到 `Logger.Fatal(...)`；分支：`if SilentMode then ExitCode := 1; Halt(1) else MessageDlg + Application.Terminate` |
| `DoApplicationException` | （未来扩展点）调 `Self.Handle` 后链式调用 `FOldAppException` |

### 2.2 DeepBase.AIErrorHandler.Bootstrap.pas（新单元）

**位置**：`Core/`（filesystem only，不入 dpk）

**导出**：
```pascal
type TAIErrorBootstrapMode = (bmAuto, bmProduction, bmTest);

function InstallAIErrorHandler(AMode: TAIErrorBootstrapMode = bmAuto): Boolean; overload;
function InstallAIErrorHandler(const AConfig: TAIErrorConfig;
  AMode: TAIErrorBootstrapMode = bmAuto): Boolean; overload;
function InstallAIErrorHandlerForTests: Boolean;  // sugar = bmTest
function IsTestMode: Boolean;
```

**关键逻辑**：

```
  GInstalled (unit-level guard)
  ┌──────────────────────────────────────────────┐
  │ if GInstalled then Exit(False);              │
  │ try                                          │
  │   LConfig := AConfig;                        │
  │   if ResolveSilent(AMode) then               │
  │     LConfig.SilentMode := True;              │
  │   TAIErrorHandler.Install(LConfig);          │
  │   try InstallLLMBridge except DebugOut end;  │
  │   GInstalled := True;                        │
  │   Result := True;                            │
  │ except                                       │
  │   on E do DebugOut(E.Message);               │
  │ end;                                         │
  └──────────────────────────────────────────────┘

  ResolveSilent(mode):
    bmTest       -> True
    bmProduction -> False
    bmAuto       -> IsTestMode()

  IsTestMode():
    env DEEP_AIEH_MODE='test' (case-insensitive)  OR
    {$IFDEF DEEPBASE_AIEH_TEST}
```

### 2.3 DeepBase.AIErrorHandler.LLMBridge.pas（新单元）

**位置**：`Core/`（filesystem only，不入 dpk；使用者需 link Features）

**契约**：
1. `InstallLLMBridge` 一行注册：`TAIErrorHandler.SetAICallback(closure)`
2. closure 调 `LLM.Chat(TierFast, prompt)`
3. 任何异常 → 返回空字符串
4. `LResult.Success = False` → 返回空字符串
5. tier 固定 `TierFast`（错误诊断 prompt 短、对延迟敏感）

## 3. 包归属决策

| 单元 | 物理位置 | 入 dpk | 调用方需要 |
| --- | --- | --- | --- |
| AIErrorHandler.pas | Core/ | ❌（仅源文件） | VCL.Forms |
| AIErrorHandler.Bootstrap.pas | Core/ | ❌（仅源文件） | AIErrorHandler.pas |
| AIErrorHandler.LLMBridge.pas | Core/ | ❌（仅源文件） | AIErrorHandler.pas + LLM.Service.pas（Features） |

## 4. Properties（PBT 设计要点）

按 Bootstrap.pas 注释中提到的 "Property 7..9"：

| # | 名称 | 验证 Requirement |
| --- | --- | --- |
| P1 | Bootstrap.Install 幂等 | Req 4.6 |
| P2 | bmTest 强制 SilentMode | Req 4.3 |
| P3 | bmAuto 正确读取 env DEEP_AIEH_MODE | Req 4.4 |
| P4 | InstallAIErrorHandlerForTests = bmTest | Req 4.5 |
| P5 | SilentMode 下 elAIAnalyze 不弹框 | Req 1.2 |
| P6 | SilentMode 下 elFatal 用 Halt(1) | Req 1.3 |
| P7 | LLMBridge callback never raises | Req 5.5 |
| P8 | LLMBridge LLM 异常返回空字符串 | Req 5.3 |
| P9 | LLMBridge LLM Success=False 返回空字符串 | Req 5.4 |

PBT 在本 spec 实施阶段标记为 `[ ]*`（可选），与项目其他 spec 保持一致。

## 5. 不在范围内
- 跨进程 / IPC 错误传递
- AI 模型选择（始终 TierFast）
- 异常分级规则的修改（保留现有 `ClassifyError`）
- 缓存策略修改（保留现有 50 entry LRU-on-overflow）
