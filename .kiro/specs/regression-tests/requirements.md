# Requirements Document

## Introduction

为 UniBase 框架已修复的 74 个 Bug 建立系统化的回归测试体系，确保这些问题不会再次出现，同时建立 CI 集成机制以持续监控代码质量。

## Glossary

- **Regression_Test_System**: 回归测试系统，负责管理和执行针对已修复 Bug 的测试用例
- **Test_Runner**: 测试运行器，DUnitX 框架的测试执行组件
- **CI_Pipeline**: 持续集成流水线，自动化构建和测试流程
- **Coverage_Monitor**: 覆盖率监控器，跟踪代码测试覆盖率

## Requirements

### Requirement 1: 回归测试目录结构

**User Story:** As a developer, I want a dedicated regression test directory, so that I can easily find and maintain bug-specific tests.

#### Acceptance Criteria

1. THE Regression_Test_System SHALL create a `Tests/Regression/` directory for all regression tests
2. WHEN a new regression test is added, THE Regression_Test_System SHALL follow naming convention `Test.Regression.BUG{number}_{ShortDescription}.pas`
3. THE Regression_Test_System SHALL include a registry file `Tests/Regression/RegressionTestRegistry.pas` that lists all regression tests

### Requirement 2: P0 级别 Bug 回归测试

**User Story:** As a security engineer, I want regression tests for all Critical (P0) bugs, so that security vulnerabilities don't reappear.

#### Acceptance Criteria

1. THE Regression_Test_System SHALL have tests for BUG-058 (XOR加密安全缺陷)
2. THE Regression_Test_System SHALL have tests for BUG-062 (插件沙箱逃逸风险)
3. THE Regression_Test_System SHALL have tests for BUG-063 (插件配置权限绕过)
4. THE Regression_Test_System SHALL have tests for BUG-013 (支付模块RSA签名)
5. THE Regression_Test_System SHALL have tests for BUG-035 (不安全随机数生成)
6. THE Regression_Test_System SHALL have tests for BUG-007 (死锁风险-WhenReady)
7. THE Regression_Test_System SHALL have tests for BUG-014 (微信支付签名验证)
8. THE Regression_Test_System SHALL have tests for BUG-033 (弱加密算法)
9. THE Regression_Test_System SHALL have tests for BUG-034 (硬编码密钥)
10. THE Regression_Test_System SHALL have tests for BUG-008 (UI线程竞态条件)

### Requirement 3: P1 级别 Bug 回归测试（高优先级）

**User Story:** As a developer, I want regression tests for High priority bugs, so that important functionality remains stable.

#### Acceptance Criteria

1. THE Regression_Test_System SHALL have tests for memory leak bugs (BUG-001, BUG-002)
2. THE Regression_Test_System SHALL have tests for serialization security bugs (BUG-059, BUG-060, BUG-018)
3. THE Regression_Test_System SHALL have tests for path traversal bugs (BUG-066, BUG-027)
4. THE Regression_Test_System SHALL have tests for injection attack bugs (BUG-070, BUG-073, BUG-019, BUG-039)
5. THE Regression_Test_System SHALL have tests for cryptographic bugs (BUG-037, BUG-020)
6. THE Regression_Test_System SHALL have tests for concurrency bugs (BUG-010, BUG-054, BUG-009)

### Requirement 4: CI 集成

**User Story:** As a DevOps engineer, I want regression tests integrated into CI, so that regressions are caught automatically.

#### Acceptance Criteria

1. WHEN the CI pipeline runs, THE Test_Runner SHALL execute all regression tests
2. IF any regression test fails, THEN THE CI_Pipeline SHALL fail the build
3. THE CI_Pipeline SHALL generate a regression test report in XML format
4. THE CI_Pipeline SHALL support running regression tests independently via `-Type Regression` parameter

### Requirement 5: 覆盖率阈值

**User Story:** As a quality engineer, I want coverage thresholds enforced, so that test coverage doesn't degrade.

#### Acceptance Criteria

1. THE Coverage_Monitor SHALL track code coverage for Core modules
2. IF coverage drops below 80%, THEN THE CI_Pipeline SHALL issue a warning
3. IF coverage drops below 70%, THEN THE CI_Pipeline SHALL fail the build
4. THE Coverage_Monitor SHALL generate coverage trend reports

### Requirement 6: 测试文档

**User Story:** As a new team member, I want clear documentation for regression tests, so that I can understand and contribute.

#### Acceptance Criteria

1. THE Regression_Test_System SHALL include a README.md in `Tests/Regression/` explaining the structure
2. WHEN a regression test is created, THE test file SHALL include a comment block referencing the original bug
3. THE Regression_Test_System SHALL maintain a mapping document linking bugs to their tests
