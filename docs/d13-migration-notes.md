# DeepBase Delphi 13.1 Migration Notes

## 2026-05-09 Stage 0 Baseline

- Branch: `upgrade/delphi-13`
- Pre-migration tag: `pre-d13-deepbase`
- Delphi 12.3 baseline compiler: BDS 23.0 / compiler 36.0
- Runtime package baseline command: `Scripts/build_packages_win64.ps1 -Profile All`
- Runtime package baseline result: passed for `DeepBaseCore.dpk`, `DeepBaseServices.dpk`, `DeepBasePersistence.dpk`, `DeepBaseFeatures.dpk`, `DeepBaseFMX.dpk`, `DeepBaseVCL.dpk`
- Runtime package warning baseline: `136`
- Runtime package error baseline: `0`
- Test baseline command: `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`
- Unit test baseline: `3240/3243 passed`, `3 ignored`, `0 failed`, `0 errored`, `0 leaked`
- Integration test baseline: `10/10 passed`, `0 failed`, `0 errored`, `0 leaked`
- Project/package backup: 18 `.dproj` / `.dpk` / `.groupproj` files copied to `.12.bak` local backups

## Current Constraints

- The repository already had substantial uncommitted work before the migration started. Migration commits must stage only files produced by this migration pass.
- `.dproj` format upgrade, DFM/FMX 96 DPI save, design-time package install, and IDE component palette checks require Delphi 13.1 IDE/manual operation.

## 2026-05-09 Stage 1 CLI Environment Switch

- Verified global environment script: `D:\_Progs\02Business\scripts\env\delphi-13.1.bat`
- Updated root build scripts to call the 13.1 environment entrypoint:
  - `do_rebuild.bat`
  - `build_test.bat`
  - `compile_test.bat`
  - `rebuild_test.bat`
- Updated PowerShell build/test gates to default to BDS 37.0 while still allowing `BDS` environment override:
  - `Scripts/build_packages_win64.ps1`
  - `Scripts/build_examples_win64.ps1`
  - `Scripts/run_architecture_checks.ps1`
  - `Scripts/run_tests.ps1`
- Scanned `.bat`, `.ps1`, `.cmd`, `.dproj`, `.dpk`, and `.groupproj` files for `Studio\23.0` / `BDS\23.0`; no active build configuration residue remains.

## 2026-05-09 Delphi 13.1 Build Results

- Runtime package command: `Scripts/build_packages_win64.ps1 -Profile All`
- Runtime package result: passed with BDS 37.0 / compiler 37.0 for:
  - `DeepBaseCore.dpk`
  - `DeepBaseServices.dpk`
  - `DeepBasePersistence.dpk`
  - `DeepBaseFeatures.dpk`
  - `DeepBaseFMX.dpk`
  - `DeepBaseVCL.dpk`
- Runtime package warning count: `136`, equal to the 12.3 baseline.
- Runtime package errors: `0`
- Test command: `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI`
- Test result: Unit `3240/3243 passed, 3 ignored`; Integration `10/10 passed`.
- Architecture check command: `Scripts/run_architecture_checks.ps1`
- Architecture check result: `18/18 passed`.

## 2026-05-09 Win32/IDE Package Fix

- Fixed a package membership omission: `Features\DeepBase.LLM.Proxy.pas` is used by `DeepBase.LLM.Service` but was not listed in `DeepBaseFeatures.dpk`.
- Added `DeepBase.LLM.Proxy` to `DeepBaseFeatures.dpk` so Win32/IDE builds no longer fail with `F2613 Unit 'DeepBase.LLM.Proxy' not found`.
- Moved `DeepBase.Persistence.LLM.FireDAC` out of `DeepBasePersistence.dpk` and into `DeepBaseFeatures.dpk`, because it depends on `DeepBase.LLM` / `DeepBase.LLM.Manager`, which are part of the LLM feature package.
- Removed `DeepBase.Persistence.TestHelper.FireDAC` from `DeepBasePersistence.dpk`; it depends on `DeepBase.TestHelper` and should not be part of the runtime Persistence package.
- Kept Delphi 13.1 IDE-generated package condition blocks and made implicit dependencies explicit where the IDE surfaced them (`RESTComponents` for Features and `fmxFireDAC` for FMX).
- Corrected `pgDeepBase.groupproj` Build/Make order to build runtime dependencies before design-time packages: Core, Services, Persistence, Features, FMX/VCL, then dcl packages.
- Verification:
  - `msbuild DeepBaseFeatures.dproj /t:Build /p:Config=Debug /p:Platform=Win32` passed with local package outputs.
  - `msbuild DeepBaseVCL.dproj /t:Build /p:Config=Debug /p:Platform=Win32` passed with local package outputs and `TestResults\dcp32` on the unit/package search path.
  - `pgDeepBase.groupproj` Build passed for Win32 and Win64 with local package outputs.
  - `Scripts/build_packages_win64.ps1 -Profile All` passed.

## 2026-05-09 IDE Local Package Output Fix

- Added explicit local package outputs to all 6 runtime and 3 design-time `.dproj` files:
  - Win32: `TestResults\dcu32`, `TestResults\bpl32`, `TestResults\dcp32`
  - Win64 / Win64x: `TestResults\dcu64`, `TestResults\bpl64`, `TestResults\dcp64`
- Added the platform-matched `TestResults\dcp*` directory to `DCC_UnitSearchPath` in every package project so IDE/MSBuild package builds can resolve project-local runtime dependencies such as `DeepBaseFeatures.dcp`.
- Fix target: Delphi IDE / dcc64 error `DeepBaseVCL.dpk(15): E2202 Required package 'DeepBaseFeatures' not found`.
- Verification:
  - `msbuild DeepBaseFeatures.dproj /t:Build /p:Config=Debug /p:Platform=Win64` passed without output-path overrides.
  - `msbuild DeepBaseVCL.dproj /t:Build /p:Config=Debug /p:Platform=Win64` passed without output-path overrides.
  - `msbuild pgDeepBase.groupproj /t:Build /p:Config=Debug /p:Platform=Win64` passed without output-path overrides.
  - `msbuild pgDeepBase.groupproj /t:Build /p:Config=Debug /p:Platform=Win32` passed without output-path overrides.

## 2026-05-09 Design-Time Package Build Fixes

- `dclDeepBaseCore.dpk`: removed the invalid empty `contains` section. Delphi 13.1 command-line package build reported `E2029 Identifier expected but ';' found`.
- `dclDeepBaseCore.dpk`: removed `{$R *.res}` because no `dclDeepBaseCore.res` exists and the package currently has no resource payload.
- `DeepBaseVCL.dpk`: added explicit `vclimg`, `vclFireDAC`, and `VclSmp` runtime package dependencies so design-time package builds do not duplicate VCL image units.
- Command-line design-time package build passed for:
  - `dclDeepBaseCore.dpk`
  - `dclDeepBaseVCL.dpk`
  - `dclDeepBaseFMX.dpk`
- IDE Install and component palette verification remain manual/IDE steps.

## 2026-05-09 Stage 4 UniBase VCL Cleanup

- Confirmed every tracked `VCL/UniBase.VCL.*` legacy unit/form had an existing `VCL/DeepBase.VCL.*` replacement.
- Removed 34 tracked legacy files matching `VCL/UniBase.VCL.*`, including `.pas` units and `.dfm` resources.
- Scanned `.pas`, `.dpk`, `.dproj`, and `.groupproj` files for `UniBase.VCL` and `UniBase.`; no active references remain in the repository.
- Post-cleanup runtime package command: `Scripts/build_packages_win64.ps1 -Profile All`
- Post-cleanup runtime package result: passed for all 6 runtime packages with BDS 37.0.

## 2026-05-09 Stage 7 Steering Files

- Created `.kiro/steering/delphi-13-global.md` with BDS 37.0, compiler 37.0, package, compatibility, and manual-step rules.
- Created `.kiro/steering/delphi-13-syntax.md` with Delphi 13.1 syntax mappings and before/after samples.
- Created `.kiro/steering/skia-7.1-conventions.md` with fileMatch `**/*Skia*.pas,**/FMX/*.pas`.
- Created `.kiro/steering/sse-streaming-pattern.md` with fileMatch `**/LLM*.pas,**/Stream*.pas`.
- No package build was required for this documentation-only stage.

## 2026-05-09 Stage 6 Syntax Samples

- Core sample: `Core/DeepBase.Collections.pas`
  - `TSortedList<T>.BinarySearch` now uses inline local variables and Delphi 13.1 conditional expressions.
  - `Core/DeepBase.Config.pas` was not used as the sample because it contains non-UTF-8 bytes and should not be rewritten only for syntax modernization.
- Persistence sample: `Persistence/DeepBase.DB.Pool.pas`
  - `SplitConnStrRight` now uses inline locals for the remaining connection-string segment, loop index, and separator position.
  - The file contains non-UTF-8 bytes, so the change was limited to ASCII byte-level replacement.
- Features sample: `Features/DeepBase.LLM.Service.pas`
  - `ChatWithHistory` default token and temperature selection now uses Delphi 13.1 conditional expressions.
  - SSE evaluation: current Features streaming still goes through `TLLMHttpClient` and the transport abstraction returns a buffered response for parsing. Native Delphi 13.1 SSE replacement should wait until the IDE API and fake transport regression tests are pinned down.
- VCL sample: `VCL/DeepBase.VCL.Controls.pas`
  - Component palette name now uses an inline local variable.
- FMX sample: `FMX/DeepBase.FMX.Controls.pas`
  - Component palette name now uses an inline local variable.
  - No Skia 7.1 API replacement was needed in this unit because it does not use Skia APIs.
- Validation:
  - `Scripts/build_packages_win64.ps1 -Profile All` passed.
  - `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` passed: Unit `3240/3243 passed, 3 ignored`; Integration `10/10 passed`.

## 2026-05-09 Stage 8 LLM Proxy Verification

- Started `Tests/mock_proxy_server.py` on `127.0.0.1:8089`.
- Compiled `Tests/TestLLMProxyClient.dpr` with BDS 37.0 / `dcc64`.
- Ran all 6 proxy client scenarios successfully:
  - Probe
  - Unreachable port
  - Chat
  - Chat with system prompt
  - Streaming
  - Image generation
- Console checkmark glyphs displayed incorrectly under the current code page, but the process returned exit code `0`.

## 2026-05-09 Stage 2 ThirdParty Compatibility

- Ran Delphi 13.1 `dcc64` over every `.pas` unit under `ThirdParty/`.
- Initial failures:
  - `ThirdParty/DB/DeepBase.DB.MySQL.pas`: generic scalar result assigned directly from `Variant`.
  - `ThirdParty/DB/DeepBase.DB.PostgreSQL.pas`: same generic scalar issue plus obsolete/unavailable `TFDPhysPgEventMessage` reference.
  - `ThirdParty/Payment/DeepBase.Payment.Core.pas`: legacy provider factory mixed incompatible payment type systems, used unavailable `TMultipartFormData`, and called 13.1 `THTTPClient.Delete` with an obsolete signature.
- Fixes:
  - Converted MySQL/PostgreSQL `ExecuteScalar<T>` to `TValue.FromVariant(...).AsType<T>` with null fallback.
  - Removed the unused PostgreSQL notify message handler that referenced `TFDPhysPgEventMessage`.
  - Changed `DeepBase.Payment.Core` provider factory to fail fast instead of returning incompatible provider clients.
  - Replaced legacy multipart form POST with URL-encoded `TStringStream` form POST and updated `Delete` to the 13.1 signature.
- Validation:
  - All `ThirdParty/` units compile with BDS 37.0.
  - `Scripts/build_packages_win64.ps1 -Profile All` passed.
  - `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` passed: Unit `3240/3243 passed, 3 ignored`; Integration `10/10 passed`.
- Updated the global compatibility matrix at `D:\_Progs\02Business\docs\delphi-13-migration\COMPATIBILITY.md` for DeepBase-related FireDAC/System.Net status. Skia remains marked as pending because IDE installation still requires manual confirmation.

## 2026-05-09 Stage 9 Downstream Verification

- DeepLLM build verification was attempted with Delphi 13.1. The build currently fails inside the downstream repository at `D:\_Progs\02Business\DeepLLM\src\core\proxy\ProxyConfig.pas`, around line 217, with parser/scope errors such as `E2023 Function needs result type` and undeclared `AEndIdx` / `AStartIdx` / `ALines` / `ABaseIndent`. This is a downstream source issue, not a DeepBase export/API break.
- DeepDev FMX build verification was attempted with Delphi 13.1. The build fails at `DeepDev.vrc(63,15): unable to open file 'Progee.ico': FileNotFound`. This is a downstream resource file issue, not a DeepBase break.
- DeepStory VCL build verification was attempted with Delphi 13.1. The build reaches DeepBase dependency compilation, then fails in downstream third-party SynEdit at `D:\ProgramData\delphi\SynEdit-master\Source\SynUnicode.pas(36): error F2613: Unit 'Windows' not found`. This is a SynEdit/downstream compatibility issue, not a DeepBase export/API break.
- No Stage 9 failure currently requires returning to DeepBase Stage 3. The DoD item requiring 3 downstream projects to compile remains open until those downstream blockers are fixed.

## 2026-05-09 Stage 10 Partial Closeout

- Updated `CHANGELOG.md` with Delphi 13.1 migration entries.
- Confirmed migration notes now cover baseline, build/test gates, design-time package command-line fixes, UniBase cleanup, steering, syntax samples, LLM proxy verification, ThirdParty compatibility, and downstream verification blockers.
- Remaining closeout steps depend on human/IDE/downstream validation: branch merge, final tag, and downstream group notification.
