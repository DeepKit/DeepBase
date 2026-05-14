unit Test.DeepBase.Browser.Session;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Session;

type
  [TestFixture]
  TBrowserSessionTests = class
  public
    [Test]
    procedure Test_Initial_State_Is_Uninitialized;

    [Test]
    procedure Test_Initialize_Transitions_To_Initializing;

    [Test]
    procedure Test_CanFire_Initialize_From_Uninitialized;

    [Test]
    procedure Test_CannotFire_Ready_From_Uninitialized;

    [Test]
    procedure Test_Dispose_From_Any_State;

    [Test]
    procedure Test_NotifyReady_Transitions_To_Ready;

    [Test]
    procedure Test_FullLifecycle_Uninitialized_Ready_Busy_Done;

    [Test]
    procedure Test_Crash_And_Restart;

    [Test]
    procedure Test_Error_To_Unresponsive_To_Recovery;
  end;

implementation

uses
  DeepBase.BrowserAutomation;

type
  TFakeBrowserSession = class(TInterfacedObject, IBrowserSession)
  private
    FSessionId: TBrowserSessionId;
    FState: TBrowserSessionState;
    FCurrentUrl: string;
    FLastError: string;
  public
    constructor Create;
    function GetSessionId: TBrowserSessionId;
    function GetState: TBrowserSessionState;
    function GetCurrentUrl: string;
    function GetLastError: string;
    function Navigate(const AUrl: string; ATimeoutMs: Integer;
      out AError: string): Boolean;
    function ExecuteScript(const AScript: string;
      out AError: string): Boolean;
    function EvaluateScript(const AScript: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CaptureScreenshot(out AImage: TBytes;
      out AError: string): Boolean;
    function AsAutomationSession: IBrowserAutomationSession;
  end;

{ TFakeBrowserSession }

constructor TFakeBrowserSession.Create;
begin
  FSessionId := TGUID.NewGuid.ToString;
  FState := bssInitializing;
end;

function TFakeBrowserSession.GetSessionId: TBrowserSessionId;
begin
  Result := FSessionId;
end;

function TFakeBrowserSession.GetState: TBrowserSessionState;
begin
  Result := FState;
end;

function TFakeBrowserSession.GetCurrentUrl: string;
begin
  Result := FCurrentUrl;
end;

function TFakeBrowserSession.GetLastError: string;
begin
  Result := FLastError;
end;

function TFakeBrowserSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  FCurrentUrl := AUrl;
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := 'true';
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '{"ok":true}';
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  AImage := [1, 2, 3];
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

{ TBrowserSessionTests }

procedure TBrowserSessionTests.Test_Initial_State_Is_Uninitialized;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    Assert.AreEqual(bssUninitialized, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_Initialize_Transitions_To_Initializing;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    Assert.IsTrue(LManager.Initialize);
    Assert.AreEqual(bssInitializing, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_CanFire_Initialize_From_Uninitialized;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    Assert.IsTrue(LManager.CanFire(bstInitialize));
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_CannotFire_Ready_From_Uninitialized;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    Assert.IsFalse(LManager.CanFire(bstReady));
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_Dispose_From_Any_State;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    LManager.Dispose;
    Assert.AreEqual(bssDisposed, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_NotifyReady_Transitions_To_Ready;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    LManager.Initialize;
    LManager.NotifyReady;
    Assert.AreEqual(bssReady, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_FullLifecycle_Uninitialized_Ready_Busy_Done;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    Assert.AreEqual(bssUninitialized, LManager.GetCurrentState);
    LManager.Initialize;
    Assert.AreEqual(bssInitializing, LManager.GetCurrentState);
    LManager.NotifyReady;
    Assert.AreEqual(bssReady, LManager.GetCurrentState);
    LManager.NotifyBusy;
    Assert.AreEqual(bssBusy, LManager.GetCurrentState);
    LManager.NotifyComplete;
    Assert.AreEqual(bssReady, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_Crash_And_Restart;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    LManager.Initialize;
    LManager.NotifyReady;
    LManager.NotifyCrashed;
    Assert.AreEqual(bssCrashed, LManager.GetCurrentState);
    // Restart from crashed
    Assert.IsTrue(LManager.CanFire(bstInitialize));
    LManager.Initialize;
    Assert.AreEqual(bssInitializing, LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

procedure TBrowserSessionTests.Test_Error_To_Unresponsive_To_Recovery;
var
  LSession: TFakeBrowserSession;
  LManager: TBrowserSessionManager;
begin
  LSession := TFakeBrowserSession.Create;
  LManager := TBrowserSessionManager.Create(LSession);
  try
    LManager.Initialize;
    LManager.NotifyReady;
    LManager.NotifyError;
    Assert.AreEqual(bssUnresponsive,
      LManager.GetCurrentState);
  finally
    LManager.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserSessionTests);

end.
