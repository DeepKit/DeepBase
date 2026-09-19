{ ============================================================================
  Test.Regression.BUG063_PluginConfigBypass - 鎻掍欢閰嶇疆鏉冮檺缁曡繃鍥炲綊娴嬭瘯

  BUG-063: 鎻掍欢閰嶇疆鏉冮檺缁曡繃
  
  鍘熼棶棰? 鎻掍欢鍙互閫氳繃SetConfig淇敼浠绘剰閰嶇疆锛屽寘鎷郴缁熺骇鍜屽畨鍏ㄧ浉鍏抽厤缃紝
          瀛樺湪鏉冮檺鎻愬崌椋庨櫓銆?
  
  淇鏂规: 瀹炵幇鍩轰簬瑙掕壊鐨勯厤缃闂帶鍒讹紝闄愬埗鎻掍欢鍙兘淇敼 Plugin. 鍓嶇紑鐨勯厤缃紝
            骞剁姝慨鏀瑰寘鍚畨鍏ㄥ叧閿瓧鐨勯厤缃」銆?
  
  淇鏃ユ湡: 2025-01-27
  鏂囦欢: Core/DeepBase.PluginManager.pas
  浼樺厛绾? P0 (Critical)
  鍒嗙被: Security
  ============================================================================ }

unit Test.Regression.BUG063_PluginConfigBypass;

interface

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug063_PluginConfigBypassTest = class(TRegressionTestBase)
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
    [Description('楠岃瘉鎻掍欢鏃犳硶淇敼绯荤粺绾ч厤缃?)]
    procedure Test_PluginCannotModifySystemConfig;
    
    [Test]
    [Description('楠岃瘉鎻掍欢鏃犳硶淇敼瀹夊叏鐩稿叧閰嶇疆 - password')]
    procedure Test_PluginCannotModifyPasswordConfig;
    
    [Test]
    [Description('楠岃瘉鎻掍欢鏃犳硶淇敼瀹夊叏鐩稿叧閰嶇疆 - secret')]
    procedure Test_PluginCannotModifySecretConfig;
    
    [Test]
    [Description('楠岃瘉鎻掍欢鏃犳硶淇敼瀹夊叏鐩稿叧閰嶇疆 - token')]
    procedure Test_PluginCannotModifyTokenConfig;
    
    [Test]
    [Description('楠岃瘉鎻掍欢鏃犳硶淇敼瀹夊叏鐩稿叧閰嶇疆 - key')]
    procedure Test_PluginCannotModifyKeyConfig;
    
    [Test]
    [Description('楠岃瘉鎻掍欢鍙互淇敼鑷繁鐨勯厤缃?(Plugin.鍓嶇紑)')]
    procedure Test_PluginCanModifyOwnConfig;
    
    [Test]
    [Description('楠岃瘉閰嶇疆鍓嶇紑妫€鏌ュ尯鍒嗗ぇ灏忓啓')]
    procedure Test_ConfigPrefixIsCaseSensitive;
  end;

implementation

uses
  DeepBase.PluginManager;

{ TBug063_PluginConfigBypassTest }

function TBug063_PluginConfigBypassTest.GetBugNumber: string;
begin
  Result := 'BUG-063';
end;

function TBug063_PluginConfigBypassTest.GetBugDescription: string;
begin
  Result := '鎻掍欢閰嶇疆鏉冮檺缁曡繃';
end;

function TBug063_PluginConfigBypassTest.GetFixDate: string;
begin
  Result := '2025-01-27';
end;

function TBug063_PluginConfigBypassTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug063_PluginConfigBypassTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.PluginManager.pas';
end;

procedure TBug063_PluginConfigBypassTest.SetUp;
begin
  inherited;
  FTempDir := CreateTempTestDir;
end;

procedure TBug063_PluginConfigBypassTest.TearDown;
begin
  CleanupTempTestDir(FTempDir);
  inherited;
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifySystemConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
  ExceptionType: string;
begin
  LogTestStart('Test_PluginCannotModifySystemConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    ExceptionType := '';
    
    try
      // 灏濊瘯淇敼绯荤粺绾ч厤缃?
      Context.SetConfig('System.Language', 'zh-CN');
    except
      on E: EArgumentException do
      begin
        ExceptionRaised := True;
        ExceptionType := 'EArgumentException';
      end;
      on E: Exception do
      begin
        ExceptionRaised := True;
        ExceptionType := E.ClassName;
      end;
    end;
    
    Assert.IsTrue(ExceptionRaised, '鎻掍欢淇敼绯荤粺閰嶇疆搴旇鎶涘嚭寮傚父');
    Assert.AreEqual('EArgumentException', ExceptionType, 
      '搴旇鎶涘嚭 EArgumentException 琛ㄧず鍙傛暟鏃犳晥');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifySystemConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyPasswordConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyPasswordConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      // 灏濊瘯淇敼鍖呭惈 password 鐨勯厤缃?
      Context.SetConfig('Plugin.MyPlugin.password', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '鎻掍欢淇敼鍖呭惈 password 鐨勯厤缃簲璇ユ姏鍑?EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyPasswordConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifySecretConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifySecretConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.api_secret', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '鎻掍欢淇敼鍖呭惈 secret 鐨勯厤缃簲璇ユ姏鍑?EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifySecretConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyTokenConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyTokenConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.access_token', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '鎻掍欢淇敼鍖呭惈 token 鐨勯厤缃簲璇ユ姏鍑?EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyTokenConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCannotModifyKeyConfig;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_PluginCannotModifyKeyConfig');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    ExceptionRaised := False;
    
    try
      Context.SetConfig('Plugin.MyPlugin.api_key', 'stolen');
    except
      on E: EInvalidOpException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '鎻掍欢淇敼鍖呭惈 key 鐨勯厤缃簲璇ユ姏鍑?EInvalidOpException');
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCannotModifyKeyConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_PluginCanModifyOwnConfig;
var
  Context: TPluginContext;
  ConfigSet: Boolean;
  SetValue: string;
begin
  LogTestStart('Test_PluginCanModifyOwnConfig');
  
  ConfigSet := False;
  SetValue := '';
  
  Context := TPluginContext.Create(
    nil,
    procedure(const Key, Value: string)
    begin
      ConfigSet := True;
      SetValue := Value;
    end,
    nil, nil, FTempDir);
  try
    // 璁剧疆鍚堟硶鐨勬彃浠堕厤缃?
    Context.SetConfig('Plugin.MyPlugin.DisplayName', 'Test Plugin');
    
    Assert.IsTrue(ConfigSet, '鍚堟硶鐨勬彃浠堕厤缃簲璇ヨ璁剧疆');
    Assert.AreEqual('Test Plugin', SetValue, '閰嶇疆鍊煎簲璇ユ纭紶閫?);
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_PluginCanModifyOwnConfig', True);
end;

procedure TBug063_PluginConfigBypassTest.Test_ConfigPrefixIsCaseSensitive;
var
  Context: TPluginContext;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_ConfigPrefixIsCaseSensitive');
  
  Context := TPluginContext.Create(nil, nil, nil, nil, FTempDir);
  try
    // 娴嬭瘯灏忓啓 plugin. 鍓嶇紑锛堝簲璇ュけ璐ワ紝鍥犱负瑕佹眰 Plugin.锛?
    ExceptionRaised := False;
    try
      Context.SetConfig('plugin.MyPlugin.Setting', 'value');
    except
      on E: EArgumentException do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 
      '灏忓啓 plugin. 鍓嶇紑搴旇琚嫆缁濓紙瑕佹眰 Plugin.锛?);
  finally
    Context.Free;
  end;
  
  LogTestEnd('Test_ConfigPrefixIsCaseSensitive', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug063_PluginConfigBypassTest);

end.
