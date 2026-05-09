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
