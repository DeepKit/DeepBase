# Implementation Plan: Services/Crypto/Config Refactor

## Overview

This plan executes three coupled refactorings in dependency order: (1) crypto primitive unification, (2) config interface cleanup, (3) services package boundary split. Each phase ends with a compilation checkpoint to catch regressions early.

## Tasks

- [x] 1. Unify crypto primitives in DeepBase.Crypto
  - [x] 1.1 Extract shared BCrypt/CNG types and constants into a dedicated internal section of DeepBase.Crypto.pas
    - Ensure `TRandomGenerator.RandomBytes` is publicly accessible as the canonical random byte source
    - Ensure all BCrypt external declarations (`BCryptOpenAlgorithmProvider`, `BCryptGenRandom`, `BCryptEncrypt`, `BCryptDecrypt`, `BCryptGenerateSymmetricKey`, `BCryptDestroyKey`, `BCryptCloseAlgorithmProvider`) are declared only in `DeepBase.Crypto.pas`
    - Add a public `CryptoRandomBytes(ALength: Integer): TBytes` standalone function if `TRandomGenerator.RandomBytes` is not already accessible without instantiation
    - _Requirements: 6.1, 6.4, 7.1_

  - [x] 1.2 Refactor DeepBase.Random.pas to remove local CryptoAPI externals
    - Remove the local declarations of `CryptAcquireContext`, `CryptReleaseContext`, `CryptGenRandom` and associated types/constants
    - Add `DeepBase.Crypto` to the implementation `uses` clause
    - Rewrite `TSecureRandom.NextBytes` to delegate to `TRandomGenerator.RandomBytes`
    - Verify all other methods (`NextInt`, `NextIntRange`, `NextDouble`, `NextString`, `NextGuid`) still work via `NextBytes`
    - _Requirements: 6.2, 6.5_

  - [x] 1.3 Refactor DeepBase.Protection.pas to remove local BCrypt externals
    - Remove all BCrypt type declarations (`BCRYPT_ALG_HANDLE`, `BCRYPT_KEY_HANDLE`, `NTSTATUS`, `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO`)
    - Remove all BCrypt constant declarations (`BCRYPT_AES_ALGORITHM`, `BCRYPT_CHAIN_MODE_GCM`, etc.)
    - Remove all BCrypt external function declarations
    - Remove all CryptoAPI external function declarations (`CryptAcquireContext`, `CryptGenRandom`, etc.)
    - Add `DeepBase.Crypto` to the implementation `uses` clause
    - Rewrite `GenerateRandomBytes` to call `TRandomGenerator.RandomBytes`
    - Rewrite `EncryptGcmBytes`/`DecryptGcmBytes` to use `TAESCrypto` or internal helpers from `DeepBase.Crypto`
    - Keep `EncryptCbcBytes`/`DecryptCbcBytes` for legacy payload decryption — delegate to `DeepBase.Crypto` internals
    - _Requirements: 6.3, 6.5_

  - [ ]* 1.4 Write property tests for crypto layer (Properties 3, 4, 5)
    - **Property 3: RandomBytes Length Correctness**
    - **Validates: Requirements 7.1**
    - **Property 4: AES-256-GCM Round-Trip**
    - **Validates: Requirements 7.2**
    - **Property 5: HMAC-SHA256 Determinism and Length**
    - **Validates: Requirements 7.3**
    - Create test unit `Tests/Test.DeepBase.Crypto.Properties.pas`
    - Use DUnitX with randomized inputs, minimum 100 iterations per property
    - Tag: `Feature: services-crypto-config-refactor, Property 3/4/5`

- [x] 2. Checkpoint - Crypto unification compilation
  - Ensure all tests pass, ask the user if questions arise.
  - Compile `DeepBaseCore.dpk` and `DeepBaseServices.dpk` cleanly
  - Verify no new warnings above 12.3 baseline

- [x] 3. Remove deprecated config encryption methods
  - [x] 3.1 Remove GetConfigEncrypted/SetConfigEncrypted from IDeepBaseConfig
    - In `Core/DeepBase.Interfaces.pas`, delete the two method declarations and their doc comments
    - Change the `IDeepBaseConfig` GUID to `'{A1B2C3D4-E5F6-4A5B-8C9D-0E1F2A3B4C5E}'` (last char D→E)
    - _Requirements: 8.1, 8.2_

  - [x] 3.2 Remove GetConfigEncrypted/SetConfigEncrypted from TDeepBaseConfig
    - In `Core/DeepBase.Config.pas`, remove the method implementations
    - Remove any private helper methods used exclusively by the encrypted config methods
    - _Requirements: 8.4_

  - [x] 3.3 Fix any compilation errors from removed methods
    - Search codebase for calls to `GetConfigEncrypted` or `SetConfigEncrypted`
    - Replace each call with the equivalent `ISecuritySecretStorage.LoadSecret` / `.SaveSecret` pattern
    - Add `DeepBase.Storage.Interfaces` or `DeepBase.Security` to uses clauses where needed
    - _Requirements: 8.3, 9.1, 9.2, 9.3_

  - [ ]* 3.4 Write unit tests for config interface cleanup
    - Verify `IDeepBaseConfig` GUID has changed
    - Verify `TDeepBaseConfig` compiles without encrypted config methods
    - Verify `ISecuritySecretStorage` exposes `SaveSecret`, `LoadSecret`, `SecretExists`, `DeleteSecret`
    - _Requirements: 8.1, 8.2, 8.4, 9.1, 9.2, 9.3_

- [x] 4. Checkpoint - Config cleanup compilation
  - Ensure all tests pass, ask the user if questions arise.
  - Compile full `pgDeepBase.groupproj` to catch any downstream breakage from interface change

- [x] 5. Relocate DeepBase.Feedback to VCL package
  - [x] 5.1 Move DeepBase.Feedback from DeepBaseServices.dpk to DeepBaseVCL.dpk
    - Remove `DeepBase.Feedback in 'Core\DeepBase.Feedback.pas'` from `DeepBaseServices.dpk` contains clause
    - Add `DeepBase.Feedback in 'Core\DeepBase.Feedback.pas'` to `DeepBaseVCL.dpk` contains clause
    - File stays in `Core/` directory (no physical move needed — VCL package can reference Core/ paths)
    - _Requirements: 2.1, 2.2, 2.3_

- [x] 6. Relocate DeepBase.ORM to Persistence package
  - [x] 6.1 Move DeepBase.ORM from DeepBaseServices.dpk to DeepBasePersistence.dpk
    - Remove `DeepBase.ORM in 'Core\DeepBase.ORM.pas'` from `DeepBaseServices.dpk` contains clause
    - Add `DeepBase.ORM in 'Core\DeepBase.ORM.pas'` to `DeepBasePersistence.dpk` contains clause
    - Verify `DeepBasePersistence.dpk` already has `dbrtl` in requires (it does)
    - _Requirements: 3.1, 3.2, 3.3_

- [x] 7. Relocate DeepBase.Net to Features package
  - [x] 7.1 Move DeepBase.Net from DeepBaseServices.dpk to DeepBaseFeatures.dpk
    - Remove `DeepBase.Net in 'Core\DeepBase.Net.pas'` from `DeepBaseServices.dpk` contains clause
    - Add `DeepBase.Net in 'Core\DeepBase.Net.pas'` to `DeepBaseFeatures.dpk` contains clause
    - Verify `DeepBaseFeatures.dpk` already has `IndySystem`, `IndyCore`, `IndyProtocols` in requires (it does)
    - _Requirements: 4.1, 4.2, 4.3_

- [x] 8. Remove FireDAC references from DeepBase.License
  - [x] 8.1 Clean DeepBase.License.pas of FireDAC dependencies
    - Search for any `FireDAC.*` references in uses clauses and remove them
    - Replace any FireDAC type references in error messages or string formatting with plain string literals
    - Verify the unit compiles with only `rtl` and `DeepBaseCore` dependencies
    - _Requirements: 5.1, 5.2, 5.3_

- [x] 9. Finalize DeepBaseServices.dpk requires clause
  - [x] 9.1 Strip DeepBaseServices.dpk requires to rtl + DeepBaseCore only
    - Remove `vcl`, `IndySystem`, `IndyCore`, `IndyProtocols`, `dbrtl`, `FireDAC`, `FireDACCommonDriver`, `FireDACSqliteDriver` from the `requires` clause
    - Final requires: `rtl, DeepBaseCore`
    - Verify no remaining unit in the contains clause needs any of the removed packages
    - _Requirements: 1.1, 1.2_

- [ ]* 10. Write structural property tests (Properties 1, 2, 6, 7)
  - **Property 1: Services Package Interface Purity**
  - **Validates: Requirements 1.3, 1.4, 1.5**
  - **Property 2: No Duplicate Crypto Externals**
  - **Validates: Requirements 6.1, 6.5**
  - **Property 6: Crypto Consumer Independence**
  - **Validates: Requirements 7.4**
  - **Property 7: Package Contains Path Integrity**
  - **Validates: Requirements 10.3**
  - Create test unit `Tests/Test.DeepBase.PackageStructure.Properties.pas`
  - Parse .dpk and .pas files to verify structural constraints
  - Tag: `Feature: services-crypto-config-refactor, Property 1/2/6/7`

- [x] 11. Final checkpoint - Full project group compilation
  - Ensure all tests pass, ask the user if questions arise.
  - Compile `pgDeepBase.groupproj` with zero errors and no new warnings
  - Verify package load order: Core → Services → Persistence → Features → FMX → VCL
  - _Requirements: 10.1, 10.2, 10.4_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Physical file locations do NOT change — only package membership (contains clauses) changes
- The `.dproj` files for each package will need IDE-open/save to update internal references (manual step per steering rules)
- Crypto unification must complete before package split because `DeepBase.Protection` needs `DeepBase.Crypto` and both are in Services
- The config interface GUID change is intentionally breaking — it forces compile-time detection of stale references
