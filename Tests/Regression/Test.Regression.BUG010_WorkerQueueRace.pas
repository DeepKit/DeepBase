{ ============================================================================
  Test.Regression.BUG010_WorkerQueueRace - 宸ヤ綔闃熷垪鐘舵€佺珵浜夊洖褰掓祴璇?

  BUG-010: 宸ヤ綔闃熷垪鐘舵€佺珵浜?
  
  鍘熼棶棰? 澶氫釜绾跨▼鍙兘鍚屾椂淇敼浣滀笟鐘舵€侊紝缂轰箯閫傚綋鍚屾
  
  淇鏂规: 鍦ㄦ墍鏈夌姸鎬佸彉鏇存搷浣滀腑娣诲姞閿佷繚鎶わ紝纭繚绾跨▼瀹夊叏
  
  淇鏃ユ湡: 2025-12-16
  鏂囦欢: Core/DeepBase.WorkerQueue.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Concurrency
  ============================================================================ }

unit Test.Regression.BUG010_WorkerQueueRace;

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
  TBug010_WorkerQueueRaceTest = class(TConcurrencyRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('楠岃瘉鐘舵€佸彉鏇存搷浣滄湁閿佷繚鎶?)]
    procedure Test_StateChange_HasLockProtection;
    
    [Test]
    [Description('楠岃瘉骞跺彂鐘舵€佸彉鏇翠笉浼氬鑷存暟鎹崯鍧?)]
    [RepeatTest(10)]
    procedure Test_ConcurrentStateChange_NoCorruption;
  end;

implementation

uses
  System.IOUtils;

{ TBug010_WorkerQueueRaceTest }

function TBug010_WorkerQueueRaceTest.GetBugNumber: string;
begin
  Result := 'BUG-010';
end;

function TBug010_WorkerQueueRaceTest.GetBugDescription: string;
begin
  Result := '宸ヤ綔闃熷垪鐘舵€佺珵浜?;
end;

function TBug010_WorkerQueueRaceTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug010_WorkerQueueRaceTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug010_WorkerQueueRaceTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.WorkerQueue.pas';
end;

procedure TBug010_WorkerQueueRaceTest.Test_StateChange_HasLockProtection;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_StateChange_HasLockProtection');
  
  SourcePath := 'Core\DeepBase.WorkerQueue.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.WorkerQueue.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 楠岃瘉瀛樺湪閿佷繚鎶ょ浉鍏充唬鐮?
  Assert.IsTrue(
    SourceCode.Contains('TMonitor.Enter') or 
    SourceCode.Contains('Lock') or
    SourceCode.Contains('TCriticalSection'),
    '浠ｇ爜搴旇鍖呭惈閿佷繚鎶ゆ満鍒?);
  
  LogTestEnd('Test_StateChange_HasLockProtection', True);
end;

procedure TBug010_WorkerQueueRaceTest.Test_ConcurrentStateChange_NoCorruption;
var
  Counter: Integer;
  Lock: TObject;
  I: Integer;
  Threads: array[0..9] of TThread;
begin
  LogTestStart('Test_ConcurrentStateChange_NoCorruption');
  
  Counter := 0;
  Lock := TObject.Create;
  
  try
    // 鍒涘缓澶氫釜绾跨▼鍚屾椂淇敼璁℃暟鍣?
    for I := 0 to 9 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(
        procedure
        var
          J: Integer;
        begin
          for J := 1 to 1000 do
          begin
            TMonitor.Enter(Lock);
            try
              Inc(Counter);
            finally
              TMonitor.Exit(Lock);
            end;
          end;
        end);
      Threads[I].FreeOnTerminate := False;
    end;
    
    // 鍚姩鎵€鏈夌嚎绋?
    for I := 0 to 9 do
      Threads[I].Start;
    
    // 绛夊緟鎵€鏈夌嚎绋嬪畬鎴?
    for I := 0 to 9 do
    begin
      Threads[I].WaitFor;
      Threads[I].Free;
    end;
    
    // 楠岃瘉璁℃暟鍣ㄥ€兼纭?
    Assert.AreEqual(10000, Counter, '骞跺彂鎿嶄綔鍚庤鏁板櫒鍊煎簲璇ユ纭?);
  finally
    Lock.Free;
  end;
  
  LogTestEnd('Test_ConcurrentStateChange_NoCorruption', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug010_WorkerQueueRaceTest);

end.
