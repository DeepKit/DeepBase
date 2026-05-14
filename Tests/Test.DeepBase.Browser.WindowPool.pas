unit Test.DeepBase.Browser.WindowPool;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.WindowPool;

type
  [TestFixture]
  TBrowserWindowPoolTests = class
  private
    FCreatedCount: Integer;
    function CreateFakeSession(
      const AConfig: TBrowserWindowConfig): IBrowserSession;
  public
    [Test]
    procedure Test_Acquire_ReturnsSession;

    [Test]
    procedure Test_Acquire_MultipleUnderLimit;

    [Test]
    procedure Test_Acquire_ExceedsPoolLimit_ReturnsFalse;

    [Test]
    procedure Test_Release_AllowsReuse;

    [Test]
    procedure Test_ReleaseAll;

    [Test]
    procedure Test_GetSession_FoundAndNotFound;

    [Test]
    procedure Test_ShutdownAll_ClearsEverything;

    [Test]
    procedure Test_WindowConfig_Default;

    [Test]
    procedure Test_Layout_GridCreatesRects;

    [Test]
    procedure Test_Layout_HorizontalCreatesRects;

    [Test]
    procedure Test_Layout_VerticalCreatesRects;
  end;

implementation

uses
  System.SysUtils,
  System.Types,
  System.SyncObjs,
  DeepBase.BrowserAutomation;

type
  TFakePoolSession = class(TInterfacedObject, IBrowserSession)
  private
    FId: string;
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

{ TFakePoolSession }

constructor TFakePoolSession.Create;
begin
  FId := TGUID.NewGuid.ToString;
end;

function TFakePoolSession.GetSessionId: TBrowserSessionId;
begin
  Result := FId;
end;

function TFakePoolSession.GetState: TBrowserSessionState;
begin
  Result := bssReady;
end;

function TFakePoolSession.GetCurrentUrl: string;
begin
  Result := '';
end;

function TFakePoolSession.GetLastError: string;
begin
  Result := '';
end;

function TFakePoolSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakePoolSession.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakePoolSession.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := 'true';
  AError := '';
  Result := True;
end;

function TFakePoolSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '{"ok":true}';
  AError := '';
  Result := True;
end;

function TFakePoolSession.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  AImage := [];
  AError := '';
  Result := True;
end;

function TFakePoolSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

{ TBrowserWindowPoolTests }

function TBrowserWindowPoolTests.CreateFakeSession(
  const AConfig: TBrowserWindowConfig): IBrowserSession;
begin
  Inc(FCreatedCount);
  Result := TFakePoolSession.Create;
end;

procedure TBrowserWindowPoolTests.Test_Acquire_ReturnsSession;
var
  LPool: TBrowserWindowPool;
  LId: TBrowserSessionId;
  LSession: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 4);
  try
    Assert.IsTrue(LPool.Acquire(LId, LSession));
    Assert.AreNotEqual('', LId);
    Assert.IsNotNull(LSession);
    Assert.AreEqual(1, FCreatedCount);
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_Acquire_MultipleUnderLimit;
var
  LPool: TBrowserWindowPool;
  LId1, LId2, LId3: TBrowserSessionId;
  LS1, LS2, LS3: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 4);
  try
    Assert.IsTrue(LPool.Acquire(LId1, LS1));
    Assert.IsTrue(LPool.Acquire(LId2, LS2));
    Assert.IsTrue(LPool.Acquire(LId3, LS3));
    Assert.AreEqual(3, FCreatedCount);
    Assert.AreNotEqual(LId1, LId2);
    Assert.AreNotEqual(LId2, LId3);
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_Acquire_ExceedsPoolLimit_ReturnsFalse;
var
  LPool: TBrowserWindowPool;
  LId: TBrowserSessionId;
  LS: IBrowserSession;
  I: Integer;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 2);
  try
    Assert.IsTrue(LPool.Acquire(LId, LS));
    Assert.IsTrue(LPool.Acquire(LId, LS));
    Assert.IsFalse(LPool.Acquire(LId, LS));
    Assert.AreEqual(2, FCreatedCount);
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_Release_AllowsReuse;
var
  LPool: TBrowserWindowPool;
  LId1: TBrowserSessionId;
  LS1: IBrowserSession;
  LId2: TBrowserSessionId;
  LS2: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 2);
  try
    LPool.Acquire(LId1, LS1);
    LPool.Release(LId1);
    // Re-acquire should reuse, not create new
    Assert.IsTrue(LPool.Acquire(LId2, LS2));
    Assert.AreEqual(1, FCreatedCount);
    Assert.AreEqual(LId1, LId2);
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_ReleaseAll;
var
  LPool: TBrowserWindowPool;
  LId: TBrowserSessionId;
  LS: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 4);
  try
    LPool.Acquire(LId, LS);
    LPool.Acquire(LId, LS);
    LPool.ReleaseAll;
    Assert.AreEqual<Integer>(0, Length(LPool.GetActiveIds));
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_GetSession_FoundAndNotFound;
var
  LPool: TBrowserWindowPool;
  LId: TBrowserSessionId;
  LS: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 4);
  try
    LPool.Acquire(LId, LS);
    Assert.IsNotNull(LPool.GetSession(LId));
    Assert.IsNull(LPool.GetSession('nonexistent'));
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_ShutdownAll_ClearsEverything;
var
  LPool: TBrowserWindowPool;
  LId: TBrowserSessionId;
  LS: IBrowserSession;
begin
  FCreatedCount := 0;
  LPool := TBrowserWindowPool.Create(
    CreateFakeSession, TBrowserWindowConfig.Default, 4);
  try
    LPool.Acquire(LId, LS);
    LPool.Acquire(LId, LS);
    LPool.ShutdownAll;
    Assert.IsFalse(LPool.Acquire(LId, LS));
  finally
    LPool.Free;
  end;
end;

procedure TBrowserWindowPoolTests.Test_WindowConfig_Default;
var
  LConfig: TBrowserWindowConfig;
begin
  LConfig := TBrowserWindowConfig.Default;
  Assert.AreEqual(800, LConfig.Width);
  Assert.AreEqual(600, LConfig.Height);
  Assert.IsTrue(LConfig.Visible);
end;

procedure TBrowserWindowPoolTests.Test_Layout_GridCreatesRects;
var
  LLayout: TWindowLayout;
begin
  LLayout := TWindowLayout.CreateGrid(4, 2, 2,
    Rect(0, 0, 1000, 800));
  Assert.AreEqual<Integer>(4, Length(LLayout.Rects));
  Assert.AreEqual(lmGrid, LLayout.Mode);
end;

procedure TBrowserWindowPoolTests.Test_Layout_HorizontalCreatesRects;
var
  LLayout: TWindowLayout;
begin
  LLayout := TWindowLayout.CreateHorizontal(3,
    Rect(0, 0, 900, 600));
  Assert.AreEqual<Integer>(3, Length(LLayout.Rects));
  Assert.AreEqual(lmHorizontal, LLayout.Mode);
end;

procedure TBrowserWindowPoolTests.Test_Layout_VerticalCreatesRects;
var
  LLayout: TWindowLayout;
begin
  LLayout := TWindowLayout.CreateVertical(2,
    Rect(0, 0, 800, 1000));
  Assert.AreEqual<Integer>(2, Length(LLayout.Rects));
  Assert.AreEqual(lmVertical, LLayout.Mode);
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserWindowPoolTests);

end.
