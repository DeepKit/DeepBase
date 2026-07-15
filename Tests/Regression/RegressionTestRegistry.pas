{ ============================================================================
  RegressionTestRegistry - 回归测试注册�?

  此文件列出所有回归测试，用于�?
  1. 快速查找特�?Bug 的测�?
  2. 验证所有已修复 Bug 都有对应测试
  3. CI 报告生成
  4. 测试覆盖率统�?

  更新说明�?
  - 添加新的回归测试时，请同时更新此文件
  - 保持 Bug 编号�?docs/bugFixed.md 一�?
  ============================================================================ }

unit RegressionTestRegistry;

interface

type
  TBugPriority = (bpP0, bpP1, bpP2, bpP3);
  TBugCategory = (bcSecurity, bcMemory, bcConcurrency, bcValidation, bcCrypto, bcUI, bcOther);

  TBugTestInfo = record
    BugNumber: string;
    Priority: TBugPriority;
    Category: TBugCategory;
    TestUnit: string;
    SourceFile: string;
    Description: string;
    FixDate: string;
  end;

const
  /// <summary>回归测试总数</summary>
  REGRESSION_TEST_COUNT = 72;

  // ============================================================================
  // P0 级别测试 (Critical) - 9 �?  // ============================================================================

  P0_TEST_COUNT = 9;

  P0_TESTS: array[0..P0_TEST_COUNT - 1] of TBugTestInfo = (
    (BugNumber: 'BUG-058'; Priority: bpP0; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG058_XOREncryption';
     SourceFile: 'Core/DeepBase.Config.pas';
     Description: '配置XOR加密安全缺陷';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-062'; Priority: bpP0; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG062_PluginSandbox';
     SourceFile: 'Core/DeepBase.PluginManager.pas';
     Description: '插件沙箱逃逸风�?;
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-063'; Priority: bpP0; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG063_PluginConfigBypass';
     SourceFile: 'Core/DeepBase.PluginManager.pas';
     Description: '插件配置权限绕过';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-013'; Priority: bpP0; Category: bcCrypto;
     TestUnit: 'Test.Regression.BUG013_RSASignature';
     SourceFile: 'ThirdParty/Payment/DeepBase.Payment.Alipay.pas';
     Description: '支付模块RSA签名未实�?;
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-035'; Priority: bpP0; Category: bcCrypto;
     TestUnit: 'Test.Regression.BUG035_InsecureRandom';
     SourceFile: 'Core/DeepBase.Crypto.pas';
     Description: '不安全随机数生成';
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-007'; Priority: bpP0; Category: bcConcurrency;
     TestUnit: 'Test.Regression.BUG007_WhenReadyDeadlock';
     SourceFile: 'Core/DeepBase.Manager.pas';
     Description: '死锁风险-WhenReady方法';
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-014'; Priority: bpP0; Category: bcCrypto;
     TestUnit: 'Test.Regression.BUG014_WeChatPaySignature';
     SourceFile: 'ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas';
     Description: '微信支付签名验证缺失';
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-033'; Priority: bpP0; Category: bcCrypto;
     TestUnit: 'Test.Regression.BUG033_WeakEncryption';
     SourceFile: 'Features/DeepBase.AntiTamper.pas';
     Description: '弱加密算法使�?;
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-034'; Priority: bpP0; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG034_HardcodedKeys';
     SourceFile: 'Features/DeepBase.Protection.pas';
     Description: '硬编码密钥漏�?;
     FixDate: '2025-12-16')
  );

  // ============================================================================
  // P1 级别测试 (High) - 31 个（部分列出�?  // ============================================================================

  P1_TEST_COUNT = 15;

  P1_TESTS: array[0..P1_TEST_COUNT - 1] of TBugTestInfo = (
    // 内存泄漏相关
    (BugNumber: 'BUG-001'; Priority: bpP1; Category: bcMemory;
     TestUnit: 'Test.Regression.BUG001_AnimationMemoryLeak';
     SourceFile: 'VCL/DeepBase.VCL.WaitForm.pas';
     Description: '动画对象内存泄漏';
     FixDate: '2025-01-27'),

    // 序列化安全相�?    (BugNumber: 'BUG-059'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG059_JsonDeserializationType';
     SourceFile: 'Core/DeepBase.Serialization.pas';
     Description: 'JSON反序列化类型验证缺失';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-060'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG060_SerializationDepth';
     SourceFile: 'Core/DeepBase.Serialization.pas';
     Description: '序列化深度限制过�?;
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-018'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG018_DeserializationSecurity';
     SourceFile: 'Core/DeepBase.Serialization.pas';
     Description: '反序列化安全漏洞';
     FixDate: '2025-01-27'),

    // 路径遍历相关
    (BugNumber: 'BUG-066'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG066_PathTraversal';
     SourceFile: 'Core/DeepBase.FileWatcher.pas';
     Description: '路径遍历攻击漏洞';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-027'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG027_FileWatcherPathTraversal';
     SourceFile: 'Core/DeepBase.FileWatcher.pas';
     Description: '文件监控路径遍历';
     FixDate: '2025-01-27'),

    // 注入攻击相关
    (BugNumber: 'BUG-070'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG070_LogInjection';
     SourceFile: 'Core/DeepBase.Logging.pas';
     Description: '日志注入攻击风险';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-073'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG073_EventTypeInjection';
     SourceFile: 'Core/DeepBase.EventBus.pas';
     Description: '事件类型注入风险';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-019'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG019_LogInjectionAttack';
     SourceFile: 'Core/DeepBase.Logging.pas';
     Description: '日志注入攻击';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-039'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG039_HTTPHeaderInjection';
     SourceFile: 'Core/DeepBase.Net.pas';
     Description: 'HTTP请求头注入风�?;
     FixDate: '2025-01-27'),

    // 密码学相�?
    (BugNumber: 'BUG-037'; Priority: bpP1; Category: bcCrypto;
     TestUnit: 'Test.Regression.BUG037_KeyDerivation';
     SourceFile: 'Features/DeepBase.AntiTamper.pas';
     Description: '密钥派生不当';
     FixDate: '2025-01-27'),

    (BugNumber: 'BUG-020'; Priority: bpP1; Category: bcSecurity;
     TestUnit: 'Test.Regression.BUG020_KeyNameValidation';
     SourceFile: 'Core/DeepBase.Security.pas';
     Description: '密钥名称验证缺失';
     FixDate: '2025-01-27'),

    // 并发相关
    (BugNumber: 'BUG-010'; Priority: bpP1; Category: bcConcurrency;
     TestUnit: 'Test.Regression.BUG010_WorkerQueueRace';
     SourceFile: 'Core/DeepBase.WorkerQueue.pas';
     Description: '工作队列状态竞�?;
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-054'; Priority: bpP1; Category: bcConcurrency;
     TestUnit: 'Test.Regression.BUG054_SemaphoreLeak';
     SourceFile: 'Core/DeepBase.Resilience.pas';
     Description: '弹性模式信号量泄漏';
     FixDate: '2025-12-16'),

    (BugNumber: 'BUG-009'; Priority: bpP1; Category: bcConcurrency;
     TestUnit: 'Test.Regression.BUG009_LoggingRace';
     SourceFile: 'Core/DeepBase.Logging.pas';
     Description: '日志系统竞态条�?;
     FixDate: '2025-12-16')
  );

/// <summary>获取所�?P0 测试单元名称</summary>
function GetP0TestUnits: TArray<string>;

/// <summary>获取所�?P1 测试单元名称</summary>
function GetP1TestUnits: TArray<string>;

/// <summary>根据 Bug 编号查找测试信息</summary>
function FindBugTestInfo(const BugNumber: string): TBugTestInfo;

/// <summary>检查是否所�?Bug 都有对应测试</summary>
function ValidateTestCoverage: Boolean;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections;

function GetP0TestUnits: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, P0_TEST_COUNT);
  for I := 0 to P0_TEST_COUNT - 1 do
    Result[I] := P0_TESTS[I].TestUnit;
end;

function GetP1TestUnits: TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, P1_TEST_COUNT);
  for I := 0 to P1_TEST_COUNT - 1 do
    Result[I] := P1_TESTS[I].TestUnit;
end;

function FindBugTestInfo(const BugNumber: string): TBugTestInfo;
var
  I: Integer;
begin
  // 搜索 P0 测试
  for I := 0 to P0_TEST_COUNT - 1 do
    if SameText(P0_TESTS[I].BugNumber, BugNumber) then
      Exit(P0_TESTS[I]);

  // 搜索 P1 测试
  for I := 0 to P1_TEST_COUNT - 1 do
    if SameText(P1_TESTS[I].BugNumber, BugNumber) then
      Exit(P1_TESTS[I]);

  // 未找�?
  Result := Default(TBugTestInfo);
  Result.BugNumber := '';
end;

function ValidateTestCoverage: Boolean;
var
  I: Integer;
  LActualP0Count: Integer;
  LActualP1Count: Integer;
  LMissingFiles: TList<string>;
  LFilePath: string;
begin
  // REVIEW5-GOV-005: Validate regression test registry consistency
  Result := False;

  LMissingFiles := TList<string>.Create;
  try
    // Check 1: Verify P0 test count matches actual registrations
    LActualP0Count := 0;
    for I := 0 to High(P0_TESTS) do
      if P0_TESTS[I].BugNumber <> '' then
        Inc(LActualP0Count);

    if LActualP0Count <> P0_TEST_COUNT then
      Exit(False); // Count mismatch

    // Check 2: Verify P1 test count matches actual registrations
    LActualP1Count := 0;
    for I := 0 to High(P1_TESTS) do
      if P1_TESTS[I].BugNumber <> '' then
        Inc(LActualP1Count);

    if LActualP1Count <> P1_TEST_COUNT then
      Exit(False); // Count mismatch

    // Check 3: Verify total count matches sum of P0 + P1
    if (P0_TEST_COUNT + P1_TEST_COUNT) <> REGRESSION_TEST_COUNT then
      Exit(False); // Total mismatch

    // Check 4: Verify all registered test files exist on disk
    for I := 0 to P0_TEST_COUNT - 1 do
    begin
      if P0_TESTS[I].TestFile <> '' then
      begin
        LFilePath := 'Tests\Regression\' + P0_TESTS[I].TestFile;
        if not TFile.Exists(LFilePath) then
          LMissingFiles.Add(P0_TESTS[I].TestFile);
      end;
    end;

    for I := 0 to P1_TEST_COUNT - 1 do
    begin
      if P1_TESTS[I].TestFile <> '' then
      begin
        LFilePath := 'Tests\Regression\' + P1_TESTS[I].TestFile;
        if not TFile.Exists(LFilePath) then
          LMissingFiles.Add(P1_TESTS[I].TestFile);
      end;
    end;

    // If any files are missing, validation fails
    if LMissingFiles.Count > 0 then
      Exit(False);

    // All checks passed
    Result := True;
  finally
    LMissingFiles.Free;
  end;
end;

end.
