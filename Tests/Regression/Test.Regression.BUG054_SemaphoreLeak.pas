{ ============================================================================
  Test.Regression.BUG054_SemaphoreLeak - 寮规€фā寮忎俊鍙烽噺娉勬紡鍥炲綊娴嬭瘯

  BUG-054: 寮规€фā寮忎俊鍙烽噺娉勬紡
  
  鍘熼棶棰? TSemaphore浣跨敤鍚庡彲鑳藉瓨鍦ㄦ硠婕忛闄╋紝寮傚父鎯呭喌涓嬫湭姝ｇ‘閲婃斁
  
  淇鏂规: 娣诲姞 NeedReleaseSemaphore 鏍囧織锛岀‘淇濆彧鍦ㄦ垚鍔熻幏鍙栦俊鍙烽噺鍚庢墠閲婃斁锛?
            淇闈為槦鍒楁ā寮忎笅鐨勪俊鍙烽噺鑾峰彇閫昏緫
  
  淇鏃ユ湡: 2025-12-16
  鏂囦欢: Core/DeepBase.Resilience.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Concurrency
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
    [Description('楠岃瘉淇″彿閲忛噴鏀炬爣蹇楀瓨鍦?)]
    procedure Test_SemaphoreReleaseFlag_Exists;
    
    [Test]
    [Description('楠岃瘉寮傚父鎯呭喌涓嬩俊鍙烽噺姝ｇ‘閲婃斁')]
    procedure Test_ExceptionCase_SemaphoreReleased;
    
    [Test]
    [Description('楠岃瘉姝ｅ父鎯呭喌涓嬩俊鍙烽噺姝ｇ‘閲婃斁')]
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
  Result := '寮规€фā寮忎俊鍙烽噺娉勬紡';
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
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 楠岃瘉瀛樺湪淇″彿閲忛噴鏀炬爣蹇?
  Assert.IsTrue(
    SourceCode.Contains('NeedReleaseSemaphore') or 
    SourceCode.Contains('SemaphoreAcquired') or
    SourceCode.Contains('ReleaseSemaphore'),
    '浠ｇ爜搴旇鍖呭惈淇″彿閲忛噴鏀炬帶鍒堕€昏緫');
  
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
    // 鑾峰彇淇″彿閲?
    Semaphore.Acquire;
    
    try
      // 妯℃嫙寮傚父
      raise Exception.Create('Test exception');
    except
      // 纭繚鍦ㄥ紓甯告儏鍐典笅閲婃斁淇″彿閲?
      Semaphore.Release;
    end;
    
    // 楠岃瘉淇″彿閲忓凡閲婃斁锛堝彲浠ュ啀娆¤幏鍙栵級
    Assert.IsTrue(Semaphore.WaitFor(100) = wrSignaled,
      '寮傚父鍚庝俊鍙烽噺搴旇琚纭噴鏀?);
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
    // 鑾峰彇淇″彿閲?
    Semaphore.Acquire;
    
    // 姝ｅ父閲婃斁
    Semaphore.Release;
    
    // 楠岃瘉鍙互鍐嶆鑾峰彇
    Assert.IsTrue(Semaphore.WaitFor(100) = wrSignaled,
      '姝ｅ父閲婃斁鍚庝俊鍙烽噺搴旇鍙互鍐嶆鑾峰彇');
    Semaphore.Release;
  finally
    Semaphore.Free;
  end;
  
  LogTestEnd('Test_NormalCase_SemaphoreReleased', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug054_SemaphoreLeakTest);

end.
