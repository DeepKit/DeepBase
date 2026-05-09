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
