# Evidence Manifest · WO-20260914-EHAI-001R2

This manifest records the authority relationships, provenance, and cryptographic fingerprints for artifacts in `TestResults/WO-20260914-EHAI-001R2/`.

## Principle
Authority Uniqueness ≠ Physical File Uniqueness
Evidence directory files serve as immutable raw test and regression execution evidence snapshots for independent audit and replay verification.

## Test Evidence Records

### `tests-full-r2.xml`
- **Role**: A-2 FULL REGRESSION TEST SUITE RAW XML EVIDENCE (50/50 PASS)
- **Source Commit**: `66ba6f62641c19c60d4f9e8abcdabf84f3d0b143`
- **SHA256**: `677e95829b19ecd5760fa809d1e17838d4bae0b8152a14ca9056299c7355a2f1`
- **Size**: 10,317 bytes
- **Results**: 50/50 Tests OK, 0 Errors, 0 Failures, 0 Skipped, 0 Ignored
  - `TTestEhaiConformanceTierA`: 8 tests, result=Success
  - `TTestHbSurfaceVectorsTierB`: 5 tests, result=Success
  - `TTestHbSuite`: 37 tests, result=Success

### `tests-full-r2.txt`
- **Role**: A-2 FULL REGRESSION TEST CONSOLE OUTPUT EVIDENCE
- **Source Commit**: `66ba6f62641c19c60d4f9e8abcdabf84f3d0b143`
- **SHA256**: `3998fda32b2233d715935634679fd43037cb40edd699aad4076788daee15613b`
- **Size**: 632 bytes
- **Results**: Tests Found: 50, Ignored: 0, Passed: 50, Leaked: 0, Failed: 0, Errored: 0
