# Requirements Document

## Introduction

This specification covers three related architectural refactoring tasks in the DeepBase framework that address package boundary violations, crypto primitive duplication, and deprecated config API removal. These three issues (BASIC-001, BASIC-016, BASIC-026) are tightly coupled: the crypto unification enables the config API cleanup, and both feed into the services package boundary split. Executing them together avoids intermediate broken states.

## Glossary

- **Services_Package**: The `DeepBaseServices.dpk` runtime package, which should depend only on `rtl` and `DeepBaseCore`
- **Core_Package**: The `DeepBaseCore.dpk` runtime package, which depends only on `rtl`
- **Persistence_Package**: The `DeepBasePersistence.dpk` runtime package for database adapters
- **VCL_Package**: The `DeepBaseVCL.dpk` runtime package for VCL-dependent units
- **Crypto_Layer**: The canonical cryptographic primitive layer consisting of `DeepBase.Crypto` and `DeepBase.Security.*` units
- **CryptoAPI**: The legacy Windows `advapi32.dll` cryptographic functions (CryptAcquireContext, CryptGenRandom, etc.)
- **CNG**: Windows Cryptography Next Generation API via `bcrypt.dll` (BCryptGenRandom, BCryptEncrypt, etc.)
- **ISecretStore**: The canonical interface for secure secret storage, currently implemented as `ISecuritySecretStorage`
- **IDeepBaseConfig**: The configuration management interface defined in `DeepBase.Interfaces.pas`
- **DPAPI**: Windows Data Protection API used for user-scope encryption of secrets
- **Package_Boundary**: The set of `requires` clauses in a `.dpk` file that define allowed inter-package dependencies

## Requirements

### Requirement 1: Services Package Dependency Reduction

**User Story:** As a framework maintainer, I want the Services package to depend only on `rtl` and `DeepBaseCore`, so that it remains a lightweight L1 package usable without VCL, database, or network library dependencies.

#### Acceptance Criteria

1. THE Services_Package SHALL require only `rtl` and `DeepBaseCore` in its `requires` clause
2. WHEN the Services_Package is compiled, THE compiler SHALL produce zero errors without `vcl`, `dbrtl`, `IndySystem`, `IndyCore`, `IndyProtocols`, `FireDAC`, `FireDACCommonDriver`, or `FireDACSqliteDriver` in the search path
3. WHEN a unit references VCL types in its interface section, THE Services_Package SHALL NOT contain that unit
4. WHEN a unit references `Data.DB` in its interface section, THE Services_Package SHALL NOT contain that unit
5. WHEN a unit references Indy units in its interface section, THE Services_Package SHALL NOT contain that unit

### Requirement 2: Feedback Unit Relocation

**User Story:** As a framework maintainer, I want the Feedback unit moved out of the Services package, so that VCL screenshot capture does not force a VCL dependency on Services.

#### Acceptance Criteria

1. WHEN `DeepBase.Feedback.pas` is compiled, THE VCL_Package SHALL contain it instead of the Services_Package
2. THE Services_Package SHALL NOT contain `DeepBase.Feedback` in its `contains` clause
3. WHEN existing code references `DeepBase.Feedback`, THE compiler SHALL resolve it from the VCL_Package without source changes to the consuming unit

### Requirement 3: ORM Unit Relocation

**User Story:** As a framework maintainer, I want the ORM unit moved to the Persistence package, so that `Data.DB` interface-level dependency does not pollute the Services package.

#### Acceptance Criteria

1. WHEN `DeepBase.ORM.pas` is compiled, THE Persistence_Package SHALL contain it instead of the Services_Package
2. THE Services_Package SHALL NOT contain `DeepBase.ORM` in its `contains` clause
3. WHEN existing code references `DeepBase.ORM`, THE compiler SHALL resolve it from the Persistence_Package without source changes to the consuming unit

### Requirement 4: Net Unit Relocation

**User Story:** As a framework maintainer, I want the Net unit moved to a package that already requires Indy, so that Indy dependencies do not pollute the Services package.

#### Acceptance Criteria

1. WHEN `DeepBase.Net.pas` is compiled, THE Features_Package SHALL contain it instead of the Services_Package
2. THE Services_Package SHALL NOT contain `DeepBase.Net` in its `contains` clause
3. WHEN existing code references `DeepBase.Net`, THE compiler SHALL resolve it from the Features_Package without source changes to the consuming unit

### Requirement 5: License Unit Decoupling

**User Story:** As a framework maintainer, I want the License unit to have no FireDAC dependency, so that it can remain in the Services package.

#### Acceptance Criteria

1. WHEN `DeepBase.License.pas` is compiled, THE unit SHALL NOT reference any FireDAC unit in its interface or implementation section
2. THE Services_Package SHALL retain `DeepBase.License` in its `contains` clause
3. IF `DeepBase.License` previously referenced FireDAC types in error messages, THEN THE unit SHALL use string literals or a logging interface instead

### Requirement 6: Crypto Primitive Unification

**User Story:** As a framework maintainer, I want a single canonical crypto primitive layer, so that Windows CryptoAPI/CNG externals are declared in exactly one place and other units consume them through interfaces or wrappers.

#### Acceptance Criteria

1. THE Crypto_Layer SHALL be the sole unit declaring Windows CNG external functions (BCryptOpenAlgorithmProvider, BCryptGenRandom, BCryptEncrypt, BCryptDecrypt, BCryptGenerateSymmetricKey, BCryptDestroyKey)
2. WHEN `DeepBase.Random.pas` requires cryptographic random bytes, THE unit SHALL call the Crypto_Layer instead of declaring its own CryptoAPI externals
3. WHEN `DeepBase.Protection.pas` requires AES-GCM or random byte generation, THE unit SHALL call the Crypto_Layer instead of declaring its own CNG externals
4. THE Crypto_Layer SHALL expose a `GenerateRandomBytes` function usable by other Core units without requiring additional package dependencies
5. WHEN the refactoring is complete, THE codebase SHALL contain zero duplicate declarations of `BCryptGenRandom`, `BCryptEncrypt`, or `CryptGenRandom` outside the Crypto_Layer

### Requirement 7: Crypto Layer Public Interface

**User Story:** As a framework developer, I want the crypto layer to expose clean public interfaces for random generation, hashing, and symmetric encryption, so that consuming units do not need to understand Windows API details.

#### Acceptance Criteria

1. THE Crypto_Layer SHALL expose a `TRandomGenerator.RandomBytes` class function that returns cryptographically secure random bytes
2. THE Crypto_Layer SHALL expose AES-256-GCM encryption and decryption through `TSimpleCrypto` or equivalent class methods
3. THE Crypto_Layer SHALL expose HMAC-SHA256 computation through `THashUtils.HMAC`
4. WHEN a consuming unit needs cryptographic operations, THE unit SHALL depend only on `DeepBase.Crypto` and not on any Windows API unit directly

### Requirement 8: Config Interface Cleanup

**User Story:** As a framework maintainer, I want the deprecated `GetConfigEncrypted`/`SetConfigEncrypted` methods removed from `IDeepBaseConfig`, so that callers are forced to use the canonical `ISecuritySecretStorage` for secret management.

#### Acceptance Criteria

1. THE IDeepBaseConfig interface SHALL NOT declare `GetConfigEncrypted` or `SetConfigEncrypted` methods
2. WHEN the interface is updated, THE IDeepBaseConfig GUID SHALL change to signal a breaking interface revision
3. WHEN existing code calls `GetConfigEncrypted` or `SetConfigEncrypted`, THE compiler SHALL produce an error directing the developer to use `ISecuritySecretStorage`
4. THE `TDeepBaseConfig` implementation class SHALL NOT contain `GetConfigEncrypted` or `SetConfigEncrypted` method bodies

### Requirement 9: ISecretStore as Canonical Replacement

**User Story:** As a framework developer, I want `ISecuritySecretStorage` clearly documented and accessible as the canonical secret store, so that migrating away from deprecated config encryption is straightforward.

#### Acceptance Criteria

1. THE `ISecuritySecretStorage` interface SHALL provide `SaveSecret` and `LoadSecret` methods for storing and retrieving encrypted values
2. THE `ISecuritySecretStorage` interface SHALL provide a `SecretExists` method for checking existence without decryption
3. THE `ISecuritySecretStorage` interface SHALL provide a `DeleteSecret` method for removing stored secrets
4. WHEN a developer needs to store sensitive configuration, THE framework documentation comments SHALL direct them to `DeepBase.Security` and `ISecuritySecretStorage`

### Requirement 10: Compilation Integrity

**User Story:** As a framework maintainer, I want the entire package group to compile cleanly after refactoring, so that no downstream packages are broken by the changes.

#### Acceptance Criteria

1. WHEN the refactoring is complete, THE `pgDeepBase.groupproj` SHALL compile with zero errors
2. WHEN the refactoring is complete, THE compiler SHALL produce no new warnings above the Delphi 12.3 baseline
3. WHEN a unit is moved between packages, THE unit's file path in the `contains` clause SHALL reflect its actual location on disk
4. WHEN a unit is moved between packages, THE receiving package SHALL add any required `requires` entries for that unit's dependencies
