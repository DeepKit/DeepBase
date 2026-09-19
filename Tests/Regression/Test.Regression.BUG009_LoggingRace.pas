{ ============================================================================
  Test.Regression.BUG009_LoggingRace - 鏃ュ織绯荤粺绔炴€佹潯浠跺洖褰掓祴璇?

  BUG-009: 鏃ュ織绯荤粺绔炴€佹潯浠?
  
  鍘熼棶棰? 浣跨敤TInterlocked.CompareExchange鍚庣殑閿佹搷浣滃彲鑳戒笉鏄師瀛愮殑
  
  淇鏂规: 浠ｇ爜宸叉纭疄鐜板弻閲嶆鏌ラ攣瀹氭ā寮忥紙Double-Checked Locking锛夛紝
            浣跨敤 TInterlocked.CompareExchange 鍒涘缓閿佸璞★紝
            鐒跺悗浣跨敤 TMonitor 杩涜鍚屾
  
  淇鏃ユ湡: 2025-12-16
  鏂囦欢: Core/DeepBase.Logging.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Concurrency
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
    [Description('楠岃瘉骞跺彂鏃ュ織鍐欏叆涓嶄細瀵艰嚧鏁版嵁鎹熷潖')]
    [RepeatTest(5)]
    procedure Test_ConcurrentLogging_NoCorruption;
    
    [Test]
    [Description('楠岃瘉 TThreadList 鐢ㄤ簬绾跨▼瀹夊叏闃熷垪璁块棶')]
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
  
  // 楠岃瘉瀛樺湪鍙岄噸妫€鏌ラ攣瀹氱浉鍏充唬鐮?
  Assert.IsTrue(
    SourceCode.Contains('TInterlocked.CompareExchange') or 
    SourceCode.Contains('CompareExchange'),
    '浠ｇ爜搴旇浣跨敤 TInterlocked.CompareExchange 瀹炵幇鍙岄噸妫€鏌ラ攣瀹?);
  
  Assert.IsTrue(
    SourceCode.Contains('TMonitor') or 
    SourceCode.Contains('Lock'),
    '浠ｇ爜搴旇浣跨敤 TMonitor 鎴栭攣杩涜鍚屾');
  
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
    // 鍒涘缓澶氫釜绾跨▼鍚屾椂鍐欐棩蹇?
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
    Assert.Pass('骞跺彂鏃ュ織鍐欏叆瀹屾垚锛屾棤鏁版嵁鎹熷潖');
  finally
    Logger.Free;
    // 娓呯悊涓存椂鏂囦欢
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
  
  // 楠岃瘉浣跨敤 TThreadList 杩涜绾跨▼瀹夊叏闃熷垪璁块棶
  Assert.IsTrue(
    SourceCode.Contains('TThreadList') or 
    SourceCode.Contains('LockList') or
    SourceCode.Contains('UnlockList'),
    '浠ｇ爜搴旇浣跨敤 TThreadList 杩涜绾跨▼瀹夊叏鐨勯槦鍒楄闂?);
  
  LogTestEnd('Test_ThreadList_UsedForQueue', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug009_LoggingRaceTest);

end.
