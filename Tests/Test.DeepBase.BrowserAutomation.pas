unit Test.DeepBase.BrowserAutomation;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.BrowserAutomation;

type
  [TestFixture]
  TBrowserAutomationTests = class
  public
    [Test]
    procedure Test_Selectors_JsonRoundTrip;

    [Test]
    procedure Test_Selectors_NonObjectJsonIgnored;

    [Test]
    procedure Test_Scripts_EscapeSelectorAndText;

    [Test]
    procedure Test_Runner_ExecutesDomPlan;

    [Test]
    procedure Test_Runner_WaitForSelectorRetriesUntilFound;

    [Test]
    procedure Test_Runner_CallsDevToolsProtocol;

    [Test]
    procedure Test_Runner_CapturesScreenshotBytes;

    [Test]
    procedure Test_Runner_StopOnError;
  end;

implementation

type
  TFakeBrowserSession = class(TInterfacedObject, IBrowserAutomationSession)
  public
    Ready: Boolean;
    CurrentUrl: string;
    LastError: string;
    LastUrl: string;
    LastScript: string;
    LastCDPMethod: string;
    LastCDPParams: string;
    NavigateCalls: Integer;
    ExecuteCalls: Integer;
    EvaluateCalls: Integer;
    CDPCalls: Integer;
    ScreenshotCalls: Integer;
    EvaluateFalseCount: Integer;
    EvaluateShouldFail: Boolean;

    function IsReady: Boolean;
    function GetCurrentUrl: string;
    function GetLastError: string;
    function Navigate(const AUrl: string; ATimeoutMs: Integer;
      out AError: string): Boolean;
    function ExecuteScript(const AScript: string; out AError: string): Boolean;
    function EvaluateScript(const AScript: string; ATimeoutMs: Integer;
      out AJsonResult, AError: string): Boolean;
    function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CaptureScreenshot(out AImage: TBytes; out AError: string): Boolean;
  end;

{ TFakeBrowserSession }

function TFakeBrowserSession.IsReady: Boolean;
begin
  Result := Ready;
end;

function TFakeBrowserSession.GetCurrentUrl: string;
begin
  Result := CurrentUrl;
end;

function TFakeBrowserSession.GetLastError: string;
begin
  Result := LastError;
end;

function TFakeBrowserSession.Navigate(const AUrl: string; ATimeoutMs: Integer;
  out AError: string): Boolean;
begin
  Inc(NavigateCalls);
  LastUrl := AUrl;
  CurrentUrl := AUrl;
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.ExecuteScript(const AScript: string;
  out AError: string): Boolean;
begin
  Inc(ExecuteCalls);
  LastScript := AScript;
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
begin
  Inc(EvaluateCalls);
  LastScript := AScript;
  AError := '';

  if EvaluateShouldFail then
  begin
    AError := 'eval failed';
    AJsonResult := '';
    Exit(False);
  end;

  if Pos('success:true', AScript) > 0 then
    AJsonResult := '{"success":true,"exists":true,"value":true}'
  else if Pos('querySelectorAll', AScript) > 0 then
    AJsonResult := '{"found":true,"text":"latest answer"}'
  else if (Pos('textContent', AScript) > 0) or (Pos('innerText', AScript) > 0) then
    AJsonResult := '{"found":true,"text":"latest answer"}'
  else if EvaluateFalseCount > 0 then
  begin
    Dec(EvaluateFalseCount);
    AJsonResult := 'false';
  end
  else
    AJsonResult := '{"success":true,"exists":true,"value":true}';

  Result := True;
end;

function TFakeBrowserSession.CallDevToolsProtocol(const AMethod,
  AParams: string; ATimeoutMs: Integer; out AJsonResult,
  AError: string): Boolean;
begin
  Inc(CDPCalls);
  LastCDPMethod := AMethod;
  LastCDPParams := AParams;
  AJsonResult := '{"ok":true}';
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.CaptureScreenshot(out AImage: TBytes;
  out AError: string): Boolean;
begin
  Inc(ScreenshotCalls);
  AImage := [1, 2, 3];
  AError := '';
  Result := True;
end;

{ TBrowserAutomationTests }

procedure TBrowserAutomationTests.Test_Selectors_JsonRoundTrip;
var
  Selectors: TBrowserAutomationSelectors;
  Loaded: TBrowserAutomationSelectors;
begin
  Selectors.Init;
  Selectors.Input := 'textarea';
  Selectors.Send := 'button.send';
  Selectors.Assistant := '.message.assistant';
  Selectors.Loading := '.loading';
  Selectors.LoginCheck := '.login';
  Selectors.NewChat := '.new-chat';

  Loaded.LoadFromJson(Selectors.ToJson);

  Assert.AreEqual(Selectors.Input, Loaded.Input);
  Assert.AreEqual(Selectors.Send, Loaded.Send);
  Assert.AreEqual(Selectors.Assistant, Loaded.Assistant);
  Assert.AreEqual(Selectors.Loading, Loaded.Loading);
  Assert.AreEqual(Selectors.LoginCheck, Loaded.LoginCheck);
  Assert.AreEqual(Selectors.NewChat, Loaded.NewChat);
end;

procedure TBrowserAutomationTests.Test_Selectors_NonObjectJsonIgnored;
var
  Selectors: TBrowserAutomationSelectors;
begin
  Selectors.Input := 'textarea';

  Selectors.LoadFromJson('[]');

  Assert.AreEqual('textarea', Selectors.Input);
end;

procedure TBrowserAutomationTests.Test_Scripts_EscapeSelectorAndText;
var
  Script: string;
begin
  Script := TBrowserAutomationScripts.BuildInputTextScript(
    'textarea[data-name="prompt"]', 'hello "quoted" text');

  Assert.IsTrue(Pos('"textarea[data-name=\"prompt\"]"', Script) > 0);
  Assert.IsTrue(Pos('"hello \"quoted\" text"', Script) > 0);
end;

procedure TBrowserAutomationTests.Test_Runner_ExecutesDomPlan;
var
  Fake: TFakeBrowserSession;
  Runner: TBrowserAutomationRunner;
  Results: TArray<TBrowserAutomationResult>;
begin
  Fake := TFakeBrowserSession.Create;
  Fake.Ready := True;

  Runner := TBrowserAutomationRunner.Create(Fake as IBrowserAutomationSession);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.Navigate('https://example.test'),
      TBrowserAutomationAction.InputText('textarea', 'prompt'),
      TBrowserAutomationAction.Click('button.send'),
      TBrowserAutomationAction.GetText('.assistant')
    ]);

    Assert.AreEqual<Integer>(4, Length(Results));
    Assert.IsTrue(Results[0].Success);
    Assert.IsTrue(Results[1].Success);
    Assert.IsTrue(Results[2].Success);
    Assert.IsTrue(Results[3].Success);
    Assert.AreEqual('latest answer', Results[3].Value);
    Assert.AreEqual<Integer>(1, Fake.NavigateCalls);
    Assert.AreEqual<Integer>(3, Fake.EvaluateCalls);
  finally
    Runner.Free;
  end;
end;

procedure TBrowserAutomationTests.Test_Runner_WaitForSelectorRetriesUntilFound;
var
  Fake: TFakeBrowserSession;
  Runner: TBrowserAutomationRunner;
  Policy: TBrowserAutomationPolicy;
  Results: TArray<TBrowserAutomationResult>;
begin
  Fake := TFakeBrowserSession.Create;
  Fake.Ready := True;
  Fake.EvaluateFalseCount := 1;

  Policy := TBrowserAutomationPolicy.Default;
  Policy.Wait.TimeoutMs := 200;
  Policy.Wait.CheckIntervalMs := 1;

  Runner := TBrowserAutomationRunner.Create(Fake as IBrowserAutomationSession,
    Policy);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.WaitForSelector('.ready')
    ]);

    Assert.AreEqual<Integer>(1, Length(Results));
    Assert.IsTrue(Results[0].Success);
    Assert.AreEqual<Integer>(2, Fake.EvaluateCalls);
  finally
    Runner.Free;
  end;
end;

procedure TBrowserAutomationTests.Test_Runner_CallsDevToolsProtocol;
var
  Fake: TFakeBrowserSession;
  Runner: TBrowserAutomationRunner;
  Results: TArray<TBrowserAutomationResult>;
begin
  Fake := TFakeBrowserSession.Create;
  Fake.Ready := True;

  Runner := TBrowserAutomationRunner.Create(Fake as IBrowserAutomationSession);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.CallDevToolsProtocol(
        'Accessibility.getFullAXTree', '{}')
    ]);

    Assert.AreEqual<Integer>(1, Length(Results));
    Assert.IsTrue(Results[0].Success);
    Assert.AreEqual('Accessibility.getFullAXTree', Fake.LastCDPMethod);
    Assert.AreEqual('{}', Fake.LastCDPParams);
  finally
    Runner.Free;
  end;
end;

procedure TBrowserAutomationTests.Test_Runner_CapturesScreenshotBytes;
var
  Fake: TFakeBrowserSession;
  Runner: TBrowserAutomationRunner;
  Results: TArray<TBrowserAutomationResult>;
begin
  Fake := TFakeBrowserSession.Create;
  Fake.Ready := True;

  Runner := TBrowserAutomationRunner.Create(Fake as IBrowserAutomationSession);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.CaptureScreenshot
    ]);

    Assert.AreEqual<Integer>(1, Length(Results));
    Assert.IsTrue(Results[0].Success);
    Assert.AreEqual('3', Results[0].Value);
    Assert.AreEqual<Integer>(3, Length(Results[0].BinaryData));
    Assert.AreEqual<Integer>(1, Integer(Results[0].BinaryData[0]));
    Assert.AreEqual<Integer>(1, Fake.ScreenshotCalls);
  finally
    Runner.Free;
  end;
end;

procedure TBrowserAutomationTests.Test_Runner_StopOnError;
var
  Fake: TFakeBrowserSession;
  Runner: TBrowserAutomationRunner;
  Results: TArray<TBrowserAutomationResult>;
begin
  Fake := TFakeBrowserSession.Create;
  Fake.Ready := True;
  Fake.EvaluateShouldFail := True;

  Runner := TBrowserAutomationRunner.Create(Fake as IBrowserAutomationSession);
  try
    Results := Runner.Run([
      TBrowserAutomationAction.Click('button.send'),
      TBrowserAutomationAction.Navigate('https://example.test/next')
    ]);

    Assert.AreEqual<Integer>(1, Length(Results));
    Assert.IsFalse(Results[0].Success);
    Assert.AreEqual('click_failed', Results[0].ErrorCode);
    Assert.AreEqual<Integer>(0, Fake.NavigateCalls);
  finally
    Runner.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserAutomationTests);

end.
