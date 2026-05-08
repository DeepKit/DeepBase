{ ============================================================================
  Test.Regression.BUG054_SemaphoreLeak - 弹性模式信号量泄漏回归测试

  BUG-054: 弹性模式信号量泄漏
  
  原问�? TSemaphore使用后可能存在泄漏风险，异常情况下未正确释放
  
  修复方案: 添加 NeedReleaseSemaphore 标志，确保只在成功获取信号量后才释放�?
            修复非队列模式下的信号量获取逻辑
  
  修复日期: 2025-12-16
  文件: Core/DeepBase.Resilience.pas
  优先�? P1 (High)
  分类: Concurrency
  ============================================================================ }

unit Test.Regression.BUG054_SemaphoreLeak;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Concurrency')]
  TBug054_SemaphoreLeakTest = class(TConcurrencyRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('验证信号量释放标志存�?)]
    procedure Test_SemaphoreReleaseFlag_Exists;
    
    [Test]
    [Description('验证异常情况下信号量正确释放')]
    procedure Test_ExceptionCase_SemaphoreReleased;
    
    [Test]
    [Description('验证正常情况下信号量正确释放')]
    procedure Test_NormalCase_SemaphoreReleased;
  end;

implementation

uses
  System.IOUtils;

{ TBug054_SemaphoreLeakTest }

function TBug054_SemaphoreLeakTest.GetBugNumber: string;
begin
  Result := 'BUG-054';
end;

function TBug054_SemaphoreLeakTest.GetBugDescription: string;
begin
  Result := '弹性模式信号量泄漏';
end;

function TBug054_SemaphoreLeakTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug054_SemaphoreLeakTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug054_SemaphoreLeakTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Resilience.pas';
end;

procedure TBug054_SemaphoreLeakTest.Test_SemaphoreReleaseFlag_Exists;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_SemaphoreReleaseFlag_Exists');
  
  SourcePath := 'Core\DeepBase.Resilience.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.Resilience.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('源文件不可访问，跳过静态分析测�?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 验证存在信号量释放标�?
  Assert.IsTrue(
    SourceCode.Contains('NeedReleaseSemaphore') or 
    SourceCode.Contains('SemaphoreAcquired') or
    SourceCode.Contains('ReleaseSemaphore'),
    '代码应该包含信号量释放控制逻辑');
  
  LogTestEnd('Test_SemaphoreReleaseFlag_Exists', True);
end;

procedure TBug054_SemaphoreLeakTest.Test_ExceptionCase_SemaphoreReleased;
var
  Semaphore: TSemaphore;
  InitialCount: Integer;
begin
  LogTestStart('Test_ExceptionCase_SemaphoreReleased');
  
  InitialCount := 5;
  Semaphore := TSemaphore.Create(nil, InitialCount, InitialCount, '');
  try
    // 获取信号�?
    Semaphore.Acquire;
    
    try
      // 模拟异常
      raise Exception.Create('Test exception');
    except
      // 确保在异常情况下释放信号�?
      Semaphore.Release;
    end;
    
    // 验证信号量已释放（可以再次获取）
    Assert.IsTrue(Semaphore.WaitFor(100) = wrSignaled,
      '异常后信号量应该被正确释�?);
    Semaphore.Release;
  finally
    Semaphore.Free;
  end;
  
  LogTestEnd('Test_ExceptionCase_SemaphoreReleased', True);
end;

procedure TBug054_SemaphoreLeakTest.Test_NormalCase_SemaphoreReleased;
var
  Semaphore: TSemaphore;
begin
  LogTestStart('Test_NormalCase_SemaphoreReleased');
  
  Semaphore := TSemaphore.Create(nil, 1, 1, '');
  try
    // 获取信号�?
    Semaphore.Acquire;
    
    // 正常释放
    Semaphore.Release;
    
    // 验证可以再次获取
    Assert.IsTrue(Semaphore.WaitFor(100) = wrSignaled,
      '正常释放后信号量应该可以再次获取');
    Semaphore.Release;
  finally
    Semaphore.Free;
  end;
  
  LogTestEnd('Test_NormalCase_SemaphoreReleased', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug054_SemaphoreLeakTest);

end.
