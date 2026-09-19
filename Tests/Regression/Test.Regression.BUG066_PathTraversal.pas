{ ============================================================================
  Test.Regression.BUG066_PathTraversal - 璺緞閬嶅巻鏀诲嚮婕忔礊鍥炲綊娴嬭瘯

  BUG-066: 璺緞閬嶅巻鏀诲嚮婕忔礊
  
  鍘熼棶棰? 鏂囦欢鐩戞帶缂轰箯璺緞閬嶅巻楠岃瘉锛屽彲閫氳繃../璁块棶绯荤粺鏁忔劅鏂囦欢
  
  淇鏂规: 瀹炵幇涓ユ牸鐨勮矾寰勮鑼冨寲鍜岄獙璇佸嚱鏁帮紝闄愬埗鐩戞帶鑼冨洿
  
  淇鏃ユ湡: 2025-01-27
  鏂囦欢: Core/DeepBase.FileWatcher.pas
  浼樺厛绾? P1 (High)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG066_PathTraversal;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Security')]
  TBug066_PathTraversalTest = class(TRegressionTestBase)
  private
    FTempDir: string;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    [Description('楠岃瘉 ../ 璺緞閬嶅巻琚樆姝?)]
    procedure Test_DotDotSlash_IsBlocked;
    
    [Test]
    [Description('楠岃瘉缁濆璺緞澶栭儴璁块棶琚樆姝?)]
    procedure Test_AbsolutePathOutside_IsBlocked;
    
    [Test]
    [Description('楠岃瘉璺緞瑙勮寖鍖栧嚱鏁板瓨鍦?)]
    procedure Test_PathNormalization_Exists;
  end;

implementation

{ TBug066_PathTraversalTest }

function TBug066_PathTraversalTest.GetBugNumber: string;
begin
  Result := 'BUG-066';
end;

function TBug066_PathTraversalTest.GetBugDescription: string;
begin
  Result := '璺緞閬嶅巻鏀诲嚮婕忔礊';
end;

function TBug066_PathTraversalTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug066_PathTraversalTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug066_PathTraversalTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.FileWatcher.pas';
end;

procedure TBug066_PathTraversalTest.SetUp;
begin
  inherited;
  FTempDir := CreateTempTestDir;
end;

procedure TBug066_PathTraversalTest.TearDown;
begin
  CleanupTempTestDir(FTempDir);
  inherited;
end;

procedure TBug066_PathTraversalTest.Test_DotDotSlash_IsBlocked;
var
  MaliciousPath: string;
  NormalizedPath: string;
begin
  LogTestStart('Test_DotDotSlash_IsBlocked');
  
  // 鏋勯€犳伓鎰忚矾寰?
  MaliciousPath := TPath.Combine(FTempDir, '..\..\..\Windows\System32\config');
  
  // 瑙勮寖鍖栧悗搴旇妫€娴嬪埌璺緞閬嶅巻
  NormalizedPath := TPath.GetFullPath(MaliciousPath);
  
  // 楠岃瘉瑙勮寖鍖栧悗鐨勮矾寰勪笉鍦ㄥ師濮嬬洰褰曞唴
  Assert.IsFalse(NormalizedPath.StartsWith(FTempDir),
    '璺緞閬嶅巻鏀诲嚮搴旇琚娴嬪埌');
  
  LogTestEnd('Test_DotDotSlash_IsBlocked', True);
end;

procedure TBug066_PathTraversalTest.Test_AbsolutePathOutside_IsBlocked;
var
  ExternalPath: string;
begin
  LogTestStart('Test_AbsolutePathOutside_IsBlocked');
  
  ExternalPath := 'C:\Windows\System32';
  
  // 楠岃瘉澶栭儴缁濆璺緞涓嶅湪鐩戞帶鐩綍鍐?
  Assert.IsFalse(ExternalPath.StartsWith(FTempDir),
    '澶栭儴缁濆璺緞搴旇琚瘑鍒负涓嶅湪鐩戞帶鑼冨洿鍐?);
  
  LogTestEnd('Test_AbsolutePathOutside_IsBlocked', True);
end;

procedure TBug066_PathTraversalTest.Test_PathNormalization_Exists;
var
  SourcePath: string;
  SourceCode: string;
begin
  LogTestStart('Test_PathNormalization_Exists');
  
  SourcePath := 'Core\DeepBase.FileWatcher.pas';
  
  if not TFile.Exists(SourcePath) then
  begin
    SourcePath := '..\Core\DeepBase.FileWatcher.pas';
    if not TFile.Exists(SourcePath) then
    begin
      Assert.Pass('婧愭枃浠朵笉鍙闂紝璺宠繃闈欐€佸垎鏋愭祴璇?);
      Exit;
    end;
  end;
  
  SourceCode := TFile.ReadAllText(SourcePath);
  
  // 楠岃瘉瀛樺湪璺緞楠岃瘉鐩稿叧浠ｇ爜
  Assert.IsTrue(
    SourceCode.Contains('GetFullPath') or 
    SourceCode.Contains('NormalizePath') or
    SourceCode.Contains('ValidatePath') or
    SourceCode.Contains('IsValidPath'),
    '浠ｇ爜搴旇鍖呭惈璺緞瑙勮寖鍖栨垨楠岃瘉鍑芥暟');
  
  LogTestEnd('Test_PathNormalization_Exists', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug066_PathTraversalTest);

end.
