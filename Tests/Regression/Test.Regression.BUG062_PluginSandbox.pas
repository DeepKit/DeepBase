{ ============================================================================
  Test.Regression.BUG062_PluginSandbox - 鎻掍欢娌欑閫冮€搁闄╁洖褰掓祴璇?

  BUG-062: 鎻掍欢娌欑閫冮€搁闄?
  
  鍘熼棶棰? 鎻掍欢鍔犺浇缂轰箯瀹夊叏楠岃瘉锛屽瓨鍦ㄨ矾寰勯亶鍘嗗拰浠ｇ爜瀹屾暣鎬ч闄┿€?
          鎭舵剰鎻掍欢鍙兘閫氳繃 ../.. 璺緞璁块棶绯荤粺鏁忔劅鏂囦欢銆?
  
  淇鏂规: 娣诲姞鎻掍欢璺緞楠岃瘉 (IsValidPluginPath) 鍜屾暟瀛楃鍚嶉獙璇佹満鍒?
            (VerifyPluginSignature)锛岀‘淇濇彃浠跺彧鑳戒粠鎸囧畾鐩綍鍔犺浇銆?
  
  淇鏃ユ湡: 2025-01-27
  鏂囦欢: Core/DeepBase.PluginManager.pas
  浼樺厛绾? P0 (Critical)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG062_PluginSandbox;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Plugin;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug062_PluginSandboxTest = class(TRegressionTestBase)
  private
    FTempPluginsDir: string;
    FErrorFired: Boolean;
    FLastErrorMessage: string;
    procedure HandlePluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
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
    [Description('楠岃瘉璺緞閬嶅巻鏀诲嚮琚樆姝?- 浣跨敤 ../ 灏濊瘯閫冮€?)]
    procedure Test_PathTraversal_WithDotDot_ShouldBeBlocked;
    
    [Test]
    [Description('楠岃瘉缁濆璺緞鏀诲嚮琚樆姝?)]
    procedure Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked;
    
    [Test]
    [Description('楠岃瘉鍚堟硶鎻掍欢璺緞琚厑璁?)]
    procedure Test_ValidPluginPath_ShouldBeAllowed;
    
    [Test]
    [Description('楠岃瘉闈?BPL 鏂囦欢琚嫆缁?)]
    procedure Test_NonBPLFile_ShouldBeRejected;
    
    [Test]
    [Description('楠岃瘉鎻掍欢閰嶇疆璁块棶鎺у埗 - 鍙兘淇敼 Plugin. 鍓嶇紑鐨勯厤缃?)]
    procedure Test_PluginConfigAccess_ShouldBeLimited;
  end;

implementation

uses
  DeepBase.PluginManager;

{ TBug062_PluginSandboxTest }

function TBug062_PluginSandboxTest.GetBugNumber: string;
begin
  Result := 'BUG-062';
end;

function TBug062_PluginSandboxTest.GetBugDescription: string;
begin
  Result := '鎻掍欢娌欑閫冮€搁闄?;
end;

function TBug062_PluginSandboxTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug062_PluginSandboxTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug062_PluginSandboxTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.PluginManager.pas';
end;

procedure TBug062_PluginSandboxTest.SetUp;
begin
  inherited;
  // 鍒涘缓涓存椂鎻掍欢鐩綍
  FTempPluginsDir := TPath.Combine(TPath.GetTempPath, 'DeepBasePluginTest_' + IntToStr(TThread.GetTickCount));
  TDirectory.CreateDirectory(FTempPluginsDir);
end;

procedure TBug062_PluginSandboxTest.TearDown;
begin
  // 娓呯悊涓存椂鐩綍
  if TDirectory.Exists(FTempPluginsDir) then
  begin
    try
      TDirectory.Delete(FTempPluginsDir, True);
    except
      // 蹇界暐娓呯悊閿欒
    end;
  end;
  inherited;
end;

procedure TBug062_PluginSandboxTest.HandlePluginError(Sender: TObject; const Args: TPluginErrorEventArgs);
begin
  FErrorFired := True;
  FLastErrorMessage := Args.ErrorMessage;
end;

procedure TBug062_PluginSandboxTest.Test_PathTraversal_WithDotDot_ShouldBeBlocked;
var
  PluginManager: TDeepBasePluginManager;
  MaliciousPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_PathTraversal_WithDotDot_ShouldBeBlocked');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    FErrorFired := False;
    FLastErrorMessage := '';
    
    // 璁剧疆閿欒浜嬩欢澶勭悊鍣?
    PluginManager.OnPluginError := HandlePluginError;
    
    // 灏濊瘯浣跨敤璺緞閬嶅巻鏀诲嚮
    MaliciousPath := TPath.Combine(FTempPluginsDir, '..\..\..\Windows\System32\malicious.bpl');
    
    LoadResult := PluginManager.LoadPlugin(MaliciousPath);
    
    Assert.IsFalse(LoadResult, '璺緞閬嶅巻鏀诲嚮搴旇琚樆姝紝LoadPlugin 搴旇繑鍥?False');
    Assert.IsTrue(FErrorFired, '搴旇瑙﹀彂閿欒浜嬩欢');
    if FErrorFired then
      Assert.IsTrue(FLastErrorMessage.Contains('path') or FLastErrorMessage.Contains('Invalid'),
        '閿欒娑堟伅搴旇鎸囩ず璺緞闂');
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_PathTraversal_WithDotDot_ShouldBeBlocked', True);
end;

procedure TBug062_PluginSandboxTest.Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked;
var
  PluginManager: TDeepBasePluginManager;
  MaliciousPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    // 灏濊瘯鍔犺浇鎻掍欢鐩綍澶栫殑缁濆璺緞
    MaliciousPath := 'C:\Windows\System32\kernel32.dll';
    
    LoadResult := PluginManager.LoadPlugin(MaliciousPath);
    
    Assert.IsFalse(LoadResult, '鎻掍欢鐩綍澶栫殑缁濆璺緞搴旇琚樆姝?);
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_AbsolutePath_OutsidePluginsDir_ShouldBeBlocked', True);
end;

procedure TBug062_PluginSandboxTest.Test_ValidPluginPath_ShouldBeAllowed;
var
  PluginManager: TDeepBasePluginManager;
  ValidPath: string;
  DummyBPLPath: string;
begin
  LogTestStart('Test_ValidPluginPath_ShouldBeAllowed');
  
  // 鍒涘缓涓€涓櫄鎷熺殑 BPL 鏂囦欢锛堝彧鏄负浜嗘祴璇曡矾寰勯獙璇侊級
  DummyBPLPath := TPath.Combine(FTempPluginsDir, 'TestPlugin.bpl');
  TFile.WriteAllText(DummyBPLPath, 'dummy');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    ValidPath := DummyBPLPath;
    
    // 娉ㄦ剰锛氳繖閲屼細鍥犱负鏂囦欢涓嶆槸鐪熸鐨?BPL 鑰屽け璐ワ紝
    // 浣嗚矾寰勯獙璇佸簲璇ラ€氳繃锛堥敊璇簲璇ユ槸 "Failed to load BPL" 鑰屼笉鏄?"Invalid path"锛?
    FErrorFired := False;
    FLastErrorMessage := '';
    PluginManager.OnPluginError := HandlePluginError;
    
    // 灏濊瘯鍔犺浇锛堜細鍥犱负涓嶆槸鐪熸鐨?BPL 鑰屽け璐ワ紝浣嗚矾寰勯獙璇佸簲璇ラ€氳繃锛?
    PluginManager.LoadPlugin(ValidPath);
    
    if FErrorFired then
      Assert.IsFalse(FLastErrorMessage.Contains('Invalid plugin path'),
        '鍚堟硶璺緞涓嶅簲璇ヨЕ鍙戣矾寰勯獙璇侀敊璇?);
    
    // 濡傛灉鍒拌揪杩欓噷锛岃鏄庤矾寰勯獙璇侀€氳繃浜?
    Assert.Pass('鍚堟硶鎻掍欢璺緞楠岃瘉閫氳繃');
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_ValidPluginPath_ShouldBeAllowed', True);
end;

procedure TBug062_PluginSandboxTest.Test_NonBPLFile_ShouldBeRejected;
var
  PluginManager: TDeepBasePluginManager;
  NonBPLPath: string;
  LoadResult: Boolean;
begin
  LogTestStart('Test_NonBPLFile_ShouldBeRejected');
  
  // 鍒涘缓涓€涓潪 BPL 鏂囦欢
  NonBPLPath := TPath.Combine(FTempPluginsDir, 'malicious.exe');
  TFile.WriteAllText(NonBPLPath, 'dummy');
  
  PluginManager := TDeepBasePluginManager.Create(FTempPluginsDir, nil);
  try
    LoadResult := PluginManager.LoadPlugin(NonBPLPath);
    
    Assert.IsFalse(LoadResult, '闈?BPL 鏂囦欢搴旇琚嫆缁?);
  finally
    PluginManager.Free;
  end;
  
  LogTestEnd('Test_NonBPLFile_ShouldBeRejected', True);
end;

procedure TBug062_PluginSandboxTest.Test_PluginConfigAccess_ShouldBeLimited;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginConfigAccess_ShouldBeLimited');
  
  // 鍒涘缓鎻掍欢涓婁笅鏂?
  Context := TPluginContext.Create(
    function(const Key, Default: string): string
    begin
      Result := Default;
    end,
    procedure(const Key, Value: string)
    begin
      // 杩欎釜涓嶅簲璇ヨ璋冪敤锛屽洜涓哄簲璇ュ湪 SetConfig 涓姏鍑哄紓甯?
    end,
    nil,
    nil,
    FTempPluginsDir
  );
  
  try
    // 娴嬭瘯 1: 灏濊瘯璁剧疆闈?Plugin. 鍓嶇紑鐨勯厤缃簲璇ュけ璐?
    ExceptionRaised := False;
    try
      Context.SetConfig('System.DangerousSetting', 'malicious_value');
    except
      on E: EArgumentException do
        ExceptionRaised := True;
    end;
    Assert.IsTrue(ExceptionRaised, '璁剧疆闈?Plugin. 鍓嶇紑鐨勯厤缃簲璇ユ姏鍑哄紓甯?);
    
    // 娴嬭瘯 2: 灏濊瘯璁剧疆瀹夊叏鐩稿叧閰嶇疆搴旇澶辫触
    ExceptionRaised := False;
    try
      Context.SetConfig('Plugin.password', 'stolen_password');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    Assert.IsTrue(ExceptionRaised, '璁剧疆瀹夊叏鐩稿叧閰嶇疆搴旇鎶涘嚭寮傚父');
    
    // 娴嬭瘯 3: 璁剧疆鍚堟硶鐨?Plugin. 閰嶇疆搴旇鎴愬姛
    ExceptionRaised := False;
    try
      Context.SetConfig('Plugin.MyPlugin.Setting', 'valid_value');
    except
      ExceptionRaised := True;
    end;
    Assert.IsFalse(ExceptionRaised, '璁剧疆鍚堟硶鐨?Plugin. 閰嶇疆搴旇鎴愬姛');
    
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginConfigAccess_ShouldBeLimited', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug062_PluginSandboxTest);

end.
