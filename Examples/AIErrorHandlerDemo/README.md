# AIErrorHandlerDemo

A minimal VCL demo that shows the `aierrorhandler-rollout` spec end to end.

> Spec: [`.kiro/specs/aierrorhandler-rollout`](../../.kiro/specs/aierrorhandler-rollout)

## What it shows

Four buttons trigger one exception each, exercising every classification path:

| Button | Exception | Path | Production behaviour | Test (silent) behaviour |
| --- | --- | --- | --- | --- |
| `1) elIgnore` | `EAbort` | silent drop | nothing visible | nothing visible |
| `2) elAutoFix` | `EConvertError` | log only | `Logger.Warn` line | `Logger.Warn` line |
| `3) elAIAnalyze` | generic `Exception` | LLM friendly message | `MessageDlg` shown | dialog suppressed |
| `4) elFatal` | `EAccessViolation` | terminate | `MessageDlg` + `Application.Terminate` | `ExitCode := 1; Halt(1)` |

Status banner at the top shows the resolved mode (`PRODUCTION` or `TEST`) plus the active `DEEP_AIEH_MODE` env value.

## Run modes

The Bootstrap façade resolves the mode automatically:

```text
bmAuto =>
   IsTestMode() ? bmTest : bmProduction

IsTestMode() =>
   env DEEP_AIEH_MODE = 'test' (case-insensitive)
   OR compile-time {$DEFINE DEEPBASE_AIEH_TEST}
```

### Try production mode

```cmd
Examples\AIErrorHandlerDemo\AIErrorHandlerDemo.exe
```

`elAIAnalyze` and `elFatal` will pop up a `MessageDlg`; `elFatal` exits via `Application.Terminate`.

### Try test / silent mode

```cmd
set DEEP_AIEH_MODE=test
Examples\AIErrorHandlerDemo\AIErrorHandlerDemo.exe
```

No dialogs. `elFatal` exits with `ExitCode := 1; Halt(1)`. Useful for CI / automation.

## Build

```cmd
cd D:\_Progs\02Business\DeepBase
Examples\AIErrorHandlerDemo\build.bat
```

Builds with BDS 37.0 / Win64 / Debug. Output: `Examples\AIErrorHandlerDemo\AIErrorHandlerDemo.exe`.

## Notes

- The demo brings in `DeepBase.AIErrorHandler.Bootstrap`, which transitively pulls `DeepBase.AIErrorHandler.LLMBridge` and the `Features` LLM stack. If your DeepBase configuration does not have an LLM provider configured, the bridge silently returns an empty string and `elAIAnalyze` falls back to a friendly generic message — there is no crash.
- The bootstrap call is idempotent: a second `InstallAIErrorHandler` returns `False` and is a no-op.
- All bootstrap-internal failures are reported via `OutputDebugString` (visible in DebugView) and never propagate.
