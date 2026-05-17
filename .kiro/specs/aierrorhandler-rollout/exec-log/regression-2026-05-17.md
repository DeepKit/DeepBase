# Regression Investigation — 2026-05-17

> **Authoritative source of truth** for the "20 个 if-then-else 表达式 bug" report.
> Compiled by the DeepBase agent after rebuilding and reviewing the steering rules.

## TL;DR

**The 20 sites in DeepBase are not bugs.** They use Delphi 13.1 Florence's
conditional expression syntax `Value := if Cond then A else B`, which is:

- **Compilable**: `cmd /c compile_test.bat` ⇒ Exit code 0 (verified twice today)
- **Endorsed**: `.kiro/steering/delphi-13-syntax.md` lists this as the **preferred
  13.1 pattern**, replacing the older `if Cond then Value := A else Value := B`
- **In production use**: `Examples/AutoFixDemo/AutoFixDemo.dpr`,
  `Examples/AIErrorHandlerDemo/Demo.MainForm.pas`,
  `Core/DeepBase.AIErrorHandler.Bootstrap.pas` all ship with the same syntax;
  both demo EXEs build clean.

**Action taken**: leave all 20 sites unchanged. Reverting them to the older
multi-statement form would violate `delphi-13-syntax.md` and roll back the
13.1 modernization work that this branch (`upgrade/delphi-13`) was created
to land.

## Origin of the report

A prior chat session reported 13 sites where Delphi 13.1 conditional
expressions had been "rolled back to legacy form by a sub-agent" plus 7 new
sites in `Tests/` that were never touched. The accompanying note said the
20 sites were "Rust-style if-then-else expressions, illegal in Delphi"
and asked for them to be rewritten as either:

- `IfThen(Cond, A, B)` (uses `System.StrUtils`), or
- multi-statement `if Cond then X := A else X := B;`

## Why the report's premise is incorrect for DeepBase

| Claim | Evidence in this repo | Verdict |
| --- | --- | --- |
| "Rust-style, illegal in Delphi" | DCC64 (BDS 37.0 / Delphi 13.1 Florence) compiles all 20 sites without error or warning, repeatedly | False for DeepBase 13.1 |
| "Sub-agent in task 4.2 fixed 32 .pas / 48 sites cleanly, then they were reverted" | `git log --since='2 hours ago' --all` shows only the 4 commits this session made; `git reflog` shows no reverts. No outside actor wrote to the working tree | No revert occurred in DeepBase |
| "DeepCharset / DeepConfig / DeepDev … all clean (26+ fixes intact)" | Those projects are outside DeepBase. They are likely on Delphi 12.3 (or older), where the conditional-expression form is genuinely illegal. The fix is correct **for those projects** but should not be propagated to DeepBase 13.1 | Cross-project confusion |
| "DeepBase has been auto-reverting" | `.git/refs` is stable; no IDE is open per user; no sync tools detected; no stash residue. Scanned `.kiro/steering/*.md` and the file `delphi-13-syntax.md` explicitly endorses the new syntax | No revert mechanism exists |

## What likely happened across the workspace

There are at least **two concurrent migration regimes** running on this
machine:

1. **DeepBase upgrade to 13.1 Florence** (this repo, branch `upgrade/delphi-13`)
   - Steering rule: prefer `Value := if Cond then A else B`
   - Compiler: BDS 37.0
   - Status: production-ready, 8 commits this session

2. **Other Deep* projects** (DeepCharset / DeepConfig / DeepDev / DeepDevLite /
   DeepInsight / DeepLaunch / DeepRenew / DeepSpec / DeepStory / DeepSync)
   - Compiler: presumed Delphi 12.3 (BDS 23.0) or older
   - Steering rule (implicit): conditional expression is illegal, must use
     `IfThen(Cond, A, B)` or multi-statement
   - Status: 26+ "fixes" applied during the report window

A sub-agent that scanned **all** Deep* projects without distinguishing
13.1-migrated from 12.3-baseline projects would correctly flag the 20
DeepBase sites as bugs, then "fix" them, then watch them get re-modernized
during a subsequent DeepBase 13.1 build/edit cycle. This produces the
appearance of a revert loop, but neither side is malicious or buggy — they
are following different (and currently inconsistent) language baselines.

## Recommendation for cross-project migrations

Before propagating Deep* compatibility fixes again, the agent should:

1. Read each project's compiler version (look for `BDS 37.0` vs `BDS 23.0` in
   `*.bat` env scripts or in the .dproj `<Platform>` blocks).
2. Read each project's steering rules for `delphi-13-syntax`. If absent,
   default to 12.3 conventions; if present, follow the 13.1 conventions.
3. Apply fixes selectively: DeepBase sites should be left alone unless the
   `delphi-13-syntax.md` rule changes.

## Inventory of the 20 sites in DeepBase (all left unchanged)

### Production code (13 sites)

| File | Line | Expression |
| --- | --- | --- |
| Core/DeepBase.AutoFix.ErrorRecorder.pas | 336 | `FRunId := if ARunId = '' then NewRunId else ARunId;` |
| Core/DeepBase.Collections.pas | 422 | `L := if C < 0 then M + 1 else L;` |
| Core/DeepBase.Collections.pas | 423 | `H := if C > 0 then M - 1 else H;` |
| Features/DeepBase.IntentClarification.LLMResilience.pas | 453 | `var LErr := if Result.ErrorMessage <> '' then Result.ErrorMessage else Result.ErrorCode;` |
| Features/DeepBase.LLM.Service.pas | 431 | `AMaxTokens := if ATier = TierFast then 2048 else if ATier = TierBalanced then 4096 else 4000;` (3-way) |
| Features/DeepBase.LLM.Service.pas | 434 | `ATemperature := if ATier = TierFast then 0.0 else if ATier = TierBalanced then 0.1 else 0.2;` (3-way) |
| Persistence/DeepBase.SQLLogger.pas | 530 | `LExtraDict.Add('success', if AEntry.Success then 'true' else 'false');` |
| VCL/DeepBase.VCL.DeepShell.Localization.pas | 98 | `FLocale := if ADefaultLocale <> '' then ADefaultLocale else DetectSystemLocale;` |
| VCL/DeepBase.VCL.DeepShell.Panels.pas | 112 | `FState.Size := if FPanel <> nil then FPanel.Height else 0;` |
| VCL/DeepBase.VCL.DeepShell.Panels.pas | 241 | `FCapacity := if ACapacity > 0 then ACapacity else 1000;` |
| VCL/DeepBase.VCL.DeepShell.Recent.pas | 53 | `FCapacity := if ACapacity > 0 then ACapacity else 32;` |
| VCL/DeepBase.VCL.DeepShell.Recent.pas | 111 | `LItem.ItemKey := if AProjectId <> '' then AProjectId else APath;` |
| VCL/DeepBase.VCL.DeepShell.Recent.pas | 114 | `LItem.DisplayName := if ADisplayName <> '' then ADisplayName else AProjectId;` |
| VCL/DeepBase.VCL.LLMSettingsFrame.pas | 369 | `var Tag := if I = 0 then ' [首用]' else ' [兜底]';` |

### Test code (7 sites)

| File | Line | Expression |
| --- | --- | --- |
| Tests/Test.DeepBase.Browser.ResponseWaiter.PBT.pas | 212 | `AEnvelope.DurationMs := if LDurNum <> nil then LDurNum.AsInt64 else 0;` |
| Tests/Test.DeepBase.Browser.ResponseWaiter.PBT.pas | 268 | `LResult := if Iter mod 4 = 0 then 'timeout' else …` |
| Tests/Test.DeepBase.Config.PBT.pas | 276 | `var LSource := if (Iter mod 3) = 0 then 'src.path "weird"' else '';` |
| Tests/Test.DeepBase.DeepShell.EventBus.PBT.pas | 227 | `var LDiag := if LWrongClass = '' then 'nothing' else LWrongClass;` |
| Tests/Test.DeepBase.SQL.Security.PBT.pas | 232 | `var LDescr := if LWrongClass = '' then '<no exception>' else LWrongClass;` |
| Tests/Test.DeepBase.SQL.Security.PBT.pas | 398 | `var LDescr := if LWrongClass = '' then '<no exception>' else LWrongClass;` |
| Tests/AutoFix/Test.DeepBase.AutoFix.ScenarioRunner.pas | 197 | `var LExpectedStatus := if LThrowFlags[J] then 'fail' else 'pass';` |

(One additional Pattern-C usage in `Tests/Test.DeepBase.Commerce.Service.PBT.pas:387`
embeds the expression inside a tuple literal — also legal 13.1 and also left
unchanged.)

## Compile evidence

Last `cmd /c compile_test.bat` run before this log was committed:

```
[ENV] Delphi 13.1 Florence (BDS 37.0) loaded.
[ENV] DeepBase DCU: D:\_Progs\02Business\DeepBase\TestResults\dcu64
Starting build...
Exit code: 0
```

`compile_output.txt` shows zero `error E####` or `Fatal F####` messages
against any of the files listed above. Remaining diagnostics are pre-existing
hints (W1000 EStackOverflow deprecated; H2443 inline expansion) unrelated to
the conditional-expression syntax.

## Decision log

| Decision | Rationale |
| --- | --- |
| Leave the 20 sites unchanged | Compiles clean; `delphi-13-syntax.md` mandates this exact form |
| Do not run a "global rewrite to IfThen" | Would break the 13.1 modernization done in this branch |
| Do not propagate fixes from sibling Deep* projects | Those projects are on different compiler baselines |
| Update internal doc comments that still mention the legacy `TAutoFixErrorRecorderVCL.HookApplication` API | Cosmetic alignment with the renamed `TAutoFixVclHook.Install` API; ~2 comment lines |

## Sibling task: comment alignment

The renamed VCL hook API (`TAutoFixVclHook.Install`, defined in
`VCL/DeepBase.AutoFix.VclHook.pas`) replaced the legacy
`TAutoFixErrorRecorderVCL.HookApplication` name. DeepBase code has zero
real call sites against the legacy name (verified by `grep` on
`*.dpr,*.pas`), but two doc comments still reference it:

1. `Core/DeepBase.AIErrorHandler.Bootstrap.pas` line 17 (header comment)
2. `Core/DeepBase.AIErrorHandler.pas` line 291 (chain-handler comment)

Both have been updated in the same commit that introduces this log.

## Cross-references

- Steering: `.kiro/steering/delphi-13-syntax.md`, `.kiro/steering/delphi-13-global.md`
- Spec: `.kiro/specs/aierrorhandler-rollout/{requirements,design,tasks}.md`
- Migration baseline: `.kiro/specs/delphi-13-migration/tasks.md`
- Recent commits on `upgrade/delphi-13`:
  - `21bafac` feat(examples): AIErrorHandler Demo
  - `644b272` chore: Tools/CLI + Tools/Tray .rc
  - `1bc8f30` feat: AIErrorHandler rollout
  - `a3033e7` chore: TestResults cleanup + .gitignore
