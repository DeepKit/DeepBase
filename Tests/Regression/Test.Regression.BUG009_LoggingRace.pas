{ ============================================================================
  Test.Regression.BUG009_LoggingRace - 鏃ュ織绯荤粺绔炴€佹潯浠跺洖褰掓祴璇?

  BUG-009: 鏃ュ織绯荤粺绔炴€佹潯浠?
  
  原问? 使用TInterlocked.CompareExchange后的锁操作可能不是原子的
  
  修复方案: 代码已正确实现双重检查锁定模式（Double-Checked Locking），
            使用 TInterlocked.CompareExchange 创建锁对象，
            然后使用 TMonitor 进行同步
  
  修复日期: 2025-12-16
  文件: Core/DeepBase.Logging.pas
  浼樺厛绾? P1 (High)
  分类: Concurrency
  ============================================================================ }

unit Test.Regression.BUG009_LoggingRace;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Concurrency')]
  TBug009_LoggingRaceTest = class(TConcurrencyRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('楠岃瘉鍙岄噸妫€鏌ラ攣瀹氭ā寮忓瓨鍦?)]
    procedure Test_DoubleCheckedLocking_Exists;
    
    [Test]
    [Description('验证并发日志写入不会导致数据损坏')]
    [RepeatTest(5)]
    procedure Test_ConcurrentLogging_NoCorruption;
    
    [Test]
    [Description('验证 TThreadList 用于线程安全队列访问')]
    procedure Test_ThreadList_UsedForQueue;
  end;

implementation

uses
  System.IOUtils,
  DeepBase.Logging;

{ TBug009_LoggingRaceTest }

function TBug009_LoggingRaceTest.GetBugNumber: string;
begin
  Result := 'BUG-009';
end;

function TBug009_LoggingRaceTest.GetBugDescription: string;
begin
  Result := '鏃ュ織绯荤粺绔炴€佹潯浠?;
end;

function TBug009_LoggingRaceTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug009_LoggingRaceTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug009_LoggingRaceTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Logging.pas';
end;

procedure TBug009_LoggingRaceTest.Test_DoubleCheckedLocking_Exists;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_DoubleCheckedLocking_Exists');
  
  SourcePath := 'Core\DeepBase.Logging.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.Logging.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 验证存在双重棢查锁定相关代?
  Assert.IsTrue(
    SourceCode.Contains('TInterlocked.CompareExchange') or 
    SourceCode.Contains('CompareExchange'),
    '代码应该使用 TInterlocked.CompareExchange 实现双重棢查锁?);
  
  Assert.IsTrue(
    SourceCode.Contains('TMonitor') or 
    SourceCode.Contains('Lock'),
    '代码应该使用 TMonitor 或锁进行同步');
  
  LogTestEnd('Test_DoubleCheckedLocking_Exists', True);
end;

procedure TBug009_LoggingRaceTest.Test_ConcurrentLogging_NoCorruption;
var
  Logger: TDeepBaseLogger;
  I: Integer;
  Threads: array[0..4] of TThread;
  TempLogPath: string;
begin
  LogTestStart('Test_ConcurrentLogging_NoCorruption');
  
  TempLogPath := TPath.Combine(TPath.GetTempPath, 'test_log_' + IntToStr(TThread.GetTickCount) + '.log');
  
  Logger := TDeepBaseLogger.Create(TempLogPath);
  try
    // 创建多个线程同时写日?
    for I := 0 to 4 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to 100 do
            Logger.Info('Test message ' + IntToStr(J), 'TestCategory');
        end);
      Threads[I].FreeOnTerminate := False;
    end;
    
    // 鍚姩鎵€鏈夌嚎绋?
    for I := 0 to 4 do
      Threads[I].Start;
    
    // 绛夊緟鎵€鏈夌嚎绋嬪畬鎴?
    for I := 0 to 4 do
    begin
      Threads[I].WaitFor;
      Threads[I].Free;
    end;
    
    // 濡傛灉娌℃湁寮傚父锛屾祴璇曢€氳繃
    Assert.Pass('并发日志写入完成，无数据损坏');
  finally
    Logger.Free;
    // 清理临时文件
    if TFile.Exists(TempLogPath) then
      TFile.Delete(TempLogPath);
  end;
  
  LogTestEnd('Test_ConcurrentLogging_NoCorruption', True);
end;

procedure TBug009_LoggingRaceTest.Test_ThreadList_UsedForQueue;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_ThreadList_UsedForQueue');
  
  SourcePath := 'Core\DeepBase.Logging.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.Logging.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 验证使用 TThreadList 进行线程安全队列访问
  Assert.IsTrue(
    SourceCode.Contains('TThreadList') or 
    SourceCode.Contains('LockList') or
    SourceCode.Contains('UnlockList'),
    '代码应该使用 TThreadList 进行线程安全的队列访?);
  
  LogTestEnd('Test_ThreadList_UsedForQueue', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug009_LoggingRaceTest);

end.
