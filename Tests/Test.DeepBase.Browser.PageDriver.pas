unit Test.DeepBase.Browser.PageDriver;

interface

uses
  System.SysUtils,
  System.JSON,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.BrowserAutomation,
  DeepBase.Browser.PageDriver;

type
  [TestFixture]
  TPageDriverConfigTests = class
  public
    [Test]
    procedure Test_DefaultConfig_Values;

    [Test]
    procedure Test_DefaultConfig_NoExternalBundle;
  end;

  [TestFixture]
  TPageDriverJSTests = class
  public
    [Test]
    procedure Test_BuildLoaderScript_ContainsNativeBridge;

    [Test]
    procedure Test_BuildLoaderScript_DoesNotLoadExternalBundle;

    [Test]
    procedure Test_BuildLoaderScript_SetsStatus;

    [Test]
    procedure Test_BuildExecuteScript_ContainsActionJson;

    [Test]
    procedure Test_BuildExecuteScript_ChecksDriverLoaded;

    [Test]
    procedure Test_BuildExecuteScript_CallsNativeBridge;

    [Test]
    procedure Test_BuildStatusScript_ReturnsStatus;

    [Test]
    procedure Test_BuildUnloadScript_CleansUp;

    [Test]
    procedure Test_ParseResult_Success;

    [Test]
    procedure Test_ParseResult_WebView2StringLiteral;

    [Test]
    procedure Test_ParseResult_NestedRawFailure;

    [Test]
    procedure Test_ParseResult_Failure;

    [Test]
    procedure Test_ParseResult_InvalidJson;

    [Test]
    procedure Test_ParseResult_EmptyString;
  end;

  [TestFixture]
  TPageDriverTests = class
  public
    [Test]
    procedure Test_Create_DefaultConfig;

    [Test]
    procedure Test_Create_CustomConfig;

    [Test]
    procedure Test_Status_NotLoadedAfterCreate;

    [Test]
    procedure Test_IsReady_FalseAfterCreate;

    [Test]
    procedure Test_Execute_NotReady_ReturnsFalse;

    [Test]
    procedure Test_Unload_NoErrorWhenNotLoaded;
  end;

  [TestFixture]
  TStrategyEnumTests = class
  public
    [Test]
    procedure Test_Enum_dbasPageDriver_Exists;

    [Test]
    procedure Test_ActionType_DriveInstruction_Exists;
  end;

  [TestFixture]
  TDriveRunnerTests = class
  public
    [Test]
    procedure Test_Runner_DriveInstruction_NoCallback_Fails;

    [Test]
    procedure Test_Runner_DriveInstruction_WithCallback_Succeeds;
  end;

implementation

{ --- Fakes --------------------------------------------------------------- }

type
  TFakeAutomationSession = class(TInterfacedObject, IBrowserAutomationSession)
  public
    Ready: Boolean;
    LastScript: string;
    LastEvalResult: string;
    LastEvalError: string;
    EvalShouldFail: Boolean;

    function IsReady: Boolean;
    function GetCurrentUrl: string;
    function GetLastError: string;
    function Navigate(const AUrl: string; ATimeoutMs: Integer;
      out AError: string): Boolean;
    function ExecuteScript(const AScript: string;
      out AError: string): Boolean;
    function EvaluateScript(const AScript: string; ATimeoutMs: Integer;
      out AJsonResult, AError: string): Boolean;
    function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CaptureScreenshot(out AImage: TBytes;
      out AError: string): Boolean;
  end;

function TFakeAutomationSession.IsReady: Boolean;
begin
  Result := Ready;
end;

function TFakeAutomationSession.GetCurrentUrl: string;
begin
  Result := 'https://example.com';
end;

function TFakeAutomationSession.GetLastError: string;
begin
  Result := '';
end;

function TFakeAutomationSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  Result := True;
end;

function TFakeAutomationSession.ExecuteScript(const AScript: string;
  out AError: string): Boolean;
begin
  LastScript := AScript;
  AError := '';
  Result := not EvalShouldFail;
end;

function TFakeAutomationSession.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
begin
  LastScript := AScript;
  AJsonResult := LastEvalResult;
  AError := LastEvalError;
  Result := not EvalShouldFail;
end;

function TFakeAutomationSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  Result := True;
end;

function TFakeAutomationSession.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  Result := True;
end;

{ TPageDriverConfigTests }

procedure TPageDriverConfigTests.Test_DefaultConfig_Values;
var
  LConfig: TPageDriverConfig;
begin
  LConfig := TPageDriverConfig.Default;
  Assert.AreEqual('qwen3.5-plus', LConfig.Model);
  Assert.AreEqual('en-US', LConfig.Language);
  Assert.AreEqual(10, LConfig.MaxSteps);
  Assert.AreEqual(120000, LConfig.TimeoutMs);
end;

procedure TPageDriverConfigTests.Test_DefaultConfig_NoExternalBundle;
var
  LConfig: TPageDriverConfig;
begin
  LConfig := TPageDriverConfig.Default;
  Assert.AreEqual('', LConfig.BundleUrl);
end;

{ TPageDriverJSTests }

procedure TPageDriverJSTests.Test_BuildLoaderScript_ContainsNativeBridge;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildLoaderScript(TPageDriverConfig.Default);
  Assert.Contains(LScript, '__dbPageDriverNative');
  Assert.Contains(LScript, 'deepbase-native-1');
end;

procedure TPageDriverJSTests.Test_BuildLoaderScript_DoesNotLoadExternalBundle;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildLoaderScript(TPageDriverConfig.Default);
  Assert.IsFalse(LScript.Contains('page-agent'));
  Assert.IsFalse(LScript.Contains('cdn.jsdelivr'));
  Assert.IsFalse(LScript.Contains('createElement("script")'));
end;

procedure TPageDriverJSTests.Test_BuildLoaderScript_SetsStatus;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildLoaderScript(TPageDriverConfig.Default);
  Assert.Contains(LScript, '__dbPageDriverStatus');
  Assert.Contains(LScript, '"ready"');
end;

procedure TPageDriverJSTests.Test_BuildExecuteScript_ContainsActionJson;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildExecuteScript('{"action":"click","index":1}');
  Assert.Contains(LScript, 'action');
  Assert.Contains(LScript, 'click');
end;

procedure TPageDriverJSTests.Test_BuildExecuteScript_ChecksDriverLoaded;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildExecuteScript('test');
  Assert.Contains(LScript, '__dbPageDriverNative');
  Assert.Contains(LScript, 'driver_not_loaded');
end;

procedure TPageDriverJSTests.Test_BuildExecuteScript_CallsNativeBridge;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildExecuteScript('test');
  Assert.Contains(LScript, '__dbPageDriverNative.execute');
  Assert.IsFalse(LScript.Contains('.then('));
end;

procedure TPageDriverJSTests.Test_BuildStatusScript_ReturnsStatus;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildStatusScript;
  Assert.Contains(LScript, '__dbPageDriverStatus');
  Assert.Contains(LScript, 'JSON.stringify');
end;

procedure TPageDriverJSTests.Test_BuildUnloadScript_CleansUp;
var
  LScript: string;
begin
  LScript := TPageDriverJS.BuildUnloadScript;
  Assert.Contains(LScript, '__dbPageDriverNative');
  Assert.Contains(LScript, '__dbPageDriverStatus');
end;

procedure TPageDriverJSTests.Test_ParseResult_Success;
var
  LResult: TPageDriverResult;
begin
  Assert.IsTrue(
    TPageDriverJS.ParseResult(
      '{"success":true,"action":"execute","description":"click",' +
      '"rawResponse":"done"}',
      LResult));
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual('execute', LResult.Action);
  Assert.AreEqual('click', LResult.Description);
  Assert.AreEqual('done', LResult.RawResponse);
end;

procedure TPageDriverJSTests.Test_ParseResult_WebView2StringLiteral;
var
  LResult: TPageDriverResult;
begin
  Assert.IsTrue(
    TPageDriverJS.ParseResult(
      '"{\"success\":true,\"action\":\"execute\",\"description\":\"click\"}"',
      LResult));
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual('execute', LResult.Action);
  Assert.AreEqual('click', LResult.Description);
end;

procedure TPageDriverJSTests.Test_ParseResult_NestedRawFailure;
var
  LResult: TPageDriverResult;
begin
  Assert.IsTrue(
    TPageDriverJS.ParseResult(
      '{"success":true,"action":"execute","description":"click",' +
      '"rawResponse":"{\"success\":false,\"data\":\"InvokeError\"}"}',
      LResult));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('InvokeError', LResult.ErrorMessage);
end;

procedure TPageDriverJSTests.Test_ParseResult_Failure;
var
  LResult: TPageDriverResult;
begin
  Assert.IsTrue(
    TPageDriverJS.ParseResult(
      '{"success":false,"error":"element not found"}',
      LResult));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('element not found', LResult.ErrorMessage);
end;

procedure TPageDriverJSTests.Test_ParseResult_InvalidJson;
var
  LResult: TPageDriverResult;
begin
  Assert.IsFalse(
    TPageDriverJS.ParseResult('not json at all', LResult));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('Invalid JSON response', LResult.ErrorMessage);
end;

procedure TPageDriverJSTests.Test_ParseResult_EmptyString;
var
  LResult: TPageDriverResult;
begin
  Assert.IsFalse(
    TPageDriverJS.ParseResult('', LResult));
  Assert.IsFalse(LResult.Success);
end;

{ TPageDriverTests }

procedure TPageDriverTests.Test_Create_DefaultConfig;
var
  LDriver: TPageDriver;
begin
  LDriver := TPageDriver.Create;
  try
    Assert.AreEqual('qwen3.5-plus', LDriver.Config.Model);
  finally
    LDriver.Free;
  end;
end;

procedure TPageDriverTests.Test_Create_CustomConfig;
var
  LConfig: TPageDriverConfig;
  LDriver: TPageDriver;
begin
  LConfig := TPageDriverConfig.Default;
  LConfig.Model := 'gpt-4o';
  LConfig.Language := 'zh-CN';
  LDriver := TPageDriver.Create(LConfig);
  try
    Assert.AreEqual('gpt-4o', LDriver.Config.Model);
    Assert.AreEqual('zh-CN', LDriver.Config.Language);
  finally
    LDriver.Free;
  end;
end;

procedure TPageDriverTests.Test_Status_NotLoadedAfterCreate;
var
  LDriver: TPageDriver;
begin
  LDriver := TPageDriver.Create;
  try
    Assert.AreEqual(Integer(pdsNotLoaded), Integer(LDriver.Status));
  finally
    LDriver.Free;
  end;
end;

procedure TPageDriverTests.Test_IsReady_FalseAfterCreate;
var
  LDriver: TPageDriver;
begin
  LDriver := TPageDriver.Create;
  try
    Assert.IsFalse(LDriver.IsReady);
  finally
    LDriver.Free;
  end;
end;

procedure TPageDriverTests.Test_Execute_NotReady_ReturnsFalse;
var
  LDriver: TPageDriver;
  LResult: TPageDriverResult;
begin
  LDriver := TPageDriver.Create;
  try
    Assert.IsFalse(LDriver.Execute('click button', LResult));
    Assert.IsFalse(LResult.Success);
    Assert.Contains(LResult.ErrorMessage, 'not ready');
  finally
    LDriver.Free;
  end;
end;

procedure TPageDriverTests.Test_Unload_NoErrorWhenNotLoaded;
var
  LDriver: TPageDriver;
begin
  LDriver := TPageDriver.Create;
  try
    LDriver.Unload;
    Assert.AreEqual(Integer(pdsNotLoaded), Integer(LDriver.Status));
  finally
    LDriver.Free;
  end;
end;

{ TStrategyEnumTests }

procedure TStrategyEnumTests.Test_Enum_dbasPageDriver_Exists;
begin
  Assert.AreEqual(Integer(dbasPageDriver), Integer(dbasPageDriver));
  Assert.IsTrue(Integer(dbasPageDriver) > Integer(dbasCdp));
end;

procedure TStrategyEnumTests.Test_ActionType_DriveInstruction_Exists;
begin
  Assert.IsTrue(Integer(baatDriveInstruction) > Integer(baatCaptureScreenshot));
  Assert.AreEqual('drive_instruction',
    BrowserAutomationActionTypeToString(baatDriveInstruction));
end;

{ TDriveRunnerTests }

procedure TDriveRunnerTests.Test_Runner_DriveInstruction_NoCallback_Fails;
var
  LFake: TFakeAutomationSession;
  LSession: IBrowserAutomationSession;
  LRunner: TBrowserAutomationRunner;
  LResults: TArray<TBrowserAutomationResult>;
begin
  LFake := TFakeAutomationSession.Create;
  LFake.Ready := True;
  LSession := LFake as IBrowserAutomationSession;
  LRunner := TBrowserAutomationRunner.Create(LSession);
  try
    LResults := LRunner.Run([
      TBrowserAutomationAction.DriveInstruction('Click the login button')
    ]);
    Assert.AreEqual<Integer>(1, Length(LResults));
    Assert.IsFalse(LResults[0].Success);
    Assert.AreEqual('no_driver', LResults[0].ErrorCode);
  finally
    LRunner.Free;
  end;
end;

procedure TDriveRunnerTests.Test_Runner_DriveInstruction_WithCallback_Succeeds;
var
  LFake: TFakeAutomationSession;
  LSession: IBrowserAutomationSession;
  LRunner: TBrowserAutomationRunner;
  LResults: TArray<TBrowserAutomationResult>;
begin
  LFake := TFakeAutomationSession.Create;
  LFake.Ready := True;
  LSession := LFake as IBrowserAutomationSession;
  LRunner := TBrowserAutomationRunner.Create(LSession);
  try
    LRunner.DriveCallback :=
      function(const AInstruction: string;
        out AValue: string; out AError: string): Boolean
      begin
        AValue := '{"done":true}';
        AError := '';
        Result := True;
      end;

    LResults := LRunner.Run([
      TBrowserAutomationAction.DriveInstruction('Click the login button', 'login')
    ]);
    Assert.AreEqual<Integer>(1, Length(LResults));
    Assert.IsTrue(LResults[0].Success);
    Assert.AreEqual('login', LResults[0].ActionName);
    Assert.AreEqual('{"done":true}', LResults[0].Value);
  finally
    LRunner.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPageDriverConfigTests);
  TDUnitX.RegisterTestFixture(TPageDriverJSTests);
  TDUnitX.RegisterTestFixture(TPageDriverTests);
  TDUnitX.RegisterTestFixture(TStrategyEnumTests);
  TDUnitX.RegisterTestFixture(TDriveRunnerTests);

end.
