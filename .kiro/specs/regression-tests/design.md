# Design Document: Regression Tests System

## Overview

本设计文档描述 UniBase 框架回归测试系统的技术实现方案。该系统将为已修复的 74 个 Bug 建立系统化的回归测试，并集成到 CI 流程中。

## Architecture

```
Tests/
├── Regression/                          # 回归测试目录
│   ├── README.md                        # 说明文档
│   ├── RegressionTestRegistry.pas       # 测试注册表
│   ├── Test.Regression.BUG058_XOREncryption.pas
│   ├── Test.Regression.BUG062_PluginSandbox.pas
│   ├── ...
│   └── BugTestMapping.md                # Bug-测试映射文档
├── UniBaseTests.dpr                     # 主测试工程（包含回归测试）
└── ...

Scripts/
├── run_tests.ps1                        # 更新：支持 -Type Regression
└── coverage_check.ps1                   # 新增：覆盖率检查脚本
```

## Components and Interfaces

### 1. 回归测试基类

```pascal
unit Test.Regression.Base;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>
  /// 回归测试基类，提供通用的测试辅助方法
  /// </summary>
  [TestFixture]
  TRegressionTestBase = class
  protected
    /// <summary>获取 Bug 编号</summary>
    function GetBugNumber: string; virtual; abstract;
    /// <summary>获取 Bug 描述</summary>
    function GetBugDescription: string; virtual; abstract;
    /// <summary>获取修复日期</summary>
    function GetFixDate: string; virtual; abstract;
  public
    [SetUp]
    procedure SetUp; virtual;
    [TearDown]
    procedure TearDown; virtual;
  end;

implementation

procedure TRegressionTestBase.SetUp;
begin
  // 通用设置
end;

procedure TRegressionTestBase.TearDown;
begin
  // 通用清理
end;

end.
```

### 2. P0 级别回归测试示例

```pascal
unit Test.Regression.BUG058_XOREncryption;

interface

uses
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  /// <summary>
  /// BUG-058: 配置XOR加密安全缺陷
  /// 
  /// 原问题: GetConfigEncrypted和SetConfigEncrypted使用XOR混淆而非真正加密
  /// 修复方案: 完全移除XOR实现，强制抛出异常引导用户使用UniBase.Security.SaveSecret()
  /// 修复日期: 2025-01-27
  /// 文件: Core/UniBase.Config.pas
  /// </summary>
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug058_XOREncryptionTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
  public
    [Test]
    [Description('验证 GetConfigEncrypted 已被禁用并抛出异常')]
    procedure Test_GetConfigEncrypted_ShouldRaiseException;
    
    [Test]
    [Description('验证 SetConfigEncrypted 已被禁用并抛出异常')]
    procedure Test_SetConfigEncrypted_ShouldRaiseException;
    
    [Test]
    [Description('验证推荐使用 Security.SaveSecret 替代')]
    procedure Test_SecuritySaveSecret_ShouldWork;
  end;

implementation

uses
  System.SysUtils,
  UniBase.Config,
  UniBase.Security;

function TBug058_XOREncryptionTest.GetBugNumber: string;
begin
  Result := 'BUG-058';
end;

function TBug058_XOREncryptionTest.GetBugDescription: string;
begin
  Result := '配置XOR加密安全缺陷';
end;

function TBug058_XOREncryptionTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

procedure TBug058_XOREncryptionTest.Test_GetConfigEncrypted_ShouldRaiseException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUniBaseConfig.GetConfigEncrypted('test_key');
    end,
    ENotSupportedException,
    '不安全的加密方法应该抛出异常'
  );
end;

procedure TBug058_XOREncryptionTest.Test_SetConfigEncrypted_ShouldRaiseException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUniBaseConfig.SetConfigEncrypted('test_key', 'test_value');
    end,
    ENotSupportedException,
    '不安全的加密方法应该抛出异常'
  );
end;

procedure TBug058_XOREncryptionTest.Test_SecuritySaveSecret_ShouldWork;
var
  SecretName: string;
  SecretValue: string;
  RetrievedValue: string;
begin
  SecretName := 'test_secret_' + IntToStr(GetTickCount);
  SecretValue := 'my_secure_password';
  
  // 使用安全的 DPAPI 存储
  TUniBaseSecurity.SaveSecret(SecretName, SecretValue);
  RetrievedValue := TUniBaseSecurity.LoadSecret(SecretName);
  
  Assert.AreEqual(SecretValue, RetrievedValue, '安全存储应该正确保存和读取密钥');
  
  // 清理
  TUniBaseSecurity.DeleteSecret(SecretName);
end;

end.
```

### 3. 测试注册表

```pascal
unit RegressionTestRegistry;

interface

/// <summary>
/// 回归测试注册表
/// 
/// 此文件列出所有回归测试，用于：
/// 1. 快速查找特定 Bug 的测试
/// 2. 验证所有已修复 Bug 都有对应测试
/// 3. CI 报告生成
/// </summary>

const
  REGRESSION_TEST_COUNT = 74;
  
  // P0 级别测试 (Critical)
  P0_TESTS: array[0..9] of string = (
    'Test.Regression.BUG058_XOREncryption',
    'Test.Regression.BUG062_PluginSandbox',
    'Test.Regression.BUG063_PluginConfigBypass',
    'Test.Regression.BUG013_RSASignature',
    'Test.Regression.BUG035_InsecureRandom',
    'Test.Regression.BUG007_WhenReadyDeadlock',
    'Test.Regression.BUG014_WeChatPaySignature',
    'Test.Regression.BUG033_WeakEncryption',
    'Test.Regression.BUG034_HardcodedKeys',
    'Test.Regression.BUG008_UIThreadRace'
  );
  
  // P1 级别测试 (High)
  P1_TESTS: array[0..15] of string = (
    'Test.Regression.BUG001_AnimationMemoryLeak',
    'Test.Regression.BUG002_DanglingPointer',
    'Test.Regression.BUG059_JsonDeserializationType',
    'Test.Regression.BUG060_SerializationDepth',
    'Test.Regression.BUG066_PathTraversal',
    'Test.Regression.BUG070_LogInjection',
    'Test.Regression.BUG073_EventTypeInjection',
    'Test.Regression.BUG037_KeyDerivation',
    'Test.Regression.BUG039_HTTPHeaderInjection',
    'Test.Regression.BUG040_SSRF',
    'Test.Regression.BUG010_WorkerQueueRace',
    'Test.Regression.BUG054_SemaphoreLeak',
    'Test.Regression.BUG009_LoggingRace',
    'Test.Regression.BUG018_DeserializationSecurity',
    'Test.Regression.BUG019_LogInjectionAttack',
    'Test.Regression.BUG020_KeyNameValidation'
  );

implementation

end.
```

### 4. CI 脚本更新

```powershell
# run_tests.ps1 更新部分

param(
    [ValidateSet('Unit', 'Integration', 'Regression', 'All')]
    [string]$Type = 'All',
    # ... 其他参数
)

# 运行回归测试
if ($Type -eq 'Regression' -or $Type -eq 'All') {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "        Regression Tests"
    Write-Host "=============================================="
    
    $regProject = Join-Path $TestsDir "UniBaseTests.dpr"
    $regExe = Join-Path $TestsDir "UniBaseTests.exe"
    $regXml = Join-Path $OutputPath "RegressionTestResults.xml"
    
    if (Test-Path $regProject) {
        if (Compile-TestProject -ProjectFile $regProject -ProjectName "Regression Tests") {
            # 只运行 Regression 分类的测试
            $Results.RegressionTests = Run-TestProject `
                -ExePath $regExe `
                -TestName "Regression Tests" `
                -XmlOutput $regXml `
                -ExtraArgs @("--include:Regression")
        }
    }
}
```

## Data Models

### Bug-Test 映射结构

```pascal
type
  TBugTestMapping = record
    BugNumber: string;      // 如 'BUG-058'
    Priority: string;       // P0, P1, P2, P3
    Category: string;       // Security, Memory, Concurrency, etc.
    TestUnit: string;       // 测试单元名
    SourceFile: string;     // 原始修复文件
    FixDate: TDate;         // 修复日期
    Description: string;    // Bug 描述
  end;
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: 回归测试文件命名规范

*For any* file in the `Tests/Regression/` directory with `.pas` extension, the filename SHALL match the pattern `Test.Regression.BUG\d+_\w+\.pas` (e.g., `Test.Regression.BUG058_XOREncryption.pas`).

**Validates: Requirements 1.2**

### Property 2: 回归测试注释规范

*For any* regression test file, the test class SHALL contain a documentation comment block that includes: Bug number, original problem description, fix solution, fix date, and affected source file.

**Validates: Requirements 6.2**

## Error Handling

### 测试失败处理

1. **单个测试失败**: 记录详细错误信息，继续执行其他测试
2. **测试超时**: 默认 30 秒超时，超时视为失败
3. **环境问题**: 如数据库连接失败，跳过相关测试并标记为 Skipped

### CI 失败处理

1. **任何回归测试失败**: CI 构建失败，阻止合并
2. **覆盖率低于阈值**: 
   - < 80%: 警告，允许合并
   - < 70%: 失败，阻止合并

## Testing Strategy

### 测试分层

| 层级 | 类型 | 目的 |
|------|------|------|
| 单元测试 | 回归测试 | 验证特定 Bug 修复 |
| 集成测试 | 模块交互 | 验证修复不影响其他模块 |
| 压力测试 | 并发/内存 | 验证并发和内存相关修复 |

### 测试执行策略

1. **每次提交**: 运行所有 P0 回归测试（约 10 个，< 1 分钟）
2. **每次 PR**: 运行所有回归测试（约 74 个，< 5 分钟）
3. **每日构建**: 运行回归测试 + 覆盖率检查
4. **每周**: 运行压力测试 + 48 小时内存测试

### Property-Based Testing

对于并发相关的回归测试（如 BUG-010, BUG-054, BUG-009），使用多线程随机测试：

```pascal
[Test]
[RepeatTest(100)]  // 运行 100 次以捕获竞态条件
procedure Test_WorkerQueue_ConcurrentAccess;
```
