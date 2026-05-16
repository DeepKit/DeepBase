{ ============================================================================
  Test.DeepBase.Inference.Service
  ---------------------------------------------------------------------------
  Description : DUnitX tests for TInferenceService static facade.
                Tests SetRuntime, SetSessionFactory, Shutdown, IsReady,
                CreateSession delegation, and Run convenience method.
                Uses fake implementations to avoid onnxruntime.dll.
  ============================================================================ }

unit Test.DeepBase.Inference.Service;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Inference.Types;

type
  [TestFixture]
  TTestInferenceService = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    { IsReady }
    [Test] procedure Test_IsReady_WhenNotInitialized_ReturnsFalse;
    [Test] procedure Test_IsReady_AfterSetup_ReturnsTrue;
    [Test] procedure Test_IsReady_AfterShutdown_ReturnsFalse;

    { SetRuntime }
    [Test] procedure Test_SetRuntime_AccessibleViaRuntime;
    [Test] procedure Test_Runtime_WhenNil_ReturnsNil;

    { SetSessionFactory }
    [Test] procedure Test_SetSessionFactory_AccessibleViaSessionFactory;

    { Shutdown }
    [Test] procedure Test_Shutdown_ClearsRuntime;
    [Test] procedure Test_Shutdown_ClearsSessionFactory;

    { CreateSession delegation }
    [Test] procedure Test_CreateSession_WhenNotReady_Raises;

    { Run convenience }
    [Test] procedure Test_Run_NilSession_ReturnsFailed;
    [Test] procedure Test_Run_DelegatesToSession;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.Inference.Service;

{ --- Fake implementations ------------------------------------------------ }

type
  TFakeRuntime = class(TInterfacedObject, IInferenceRuntime)
  public
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;
  end;

  TFakeSession = class(TInterfacedObject, IInferenceSession)
  private
    FRunCalled: Boolean;
  public
    constructor Create;
    function GetSessionId: string;
    function GetState: TInferenceSessionState;
    function GetModelInfo: TInferenceModelInfo;
    function Run(const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
    function GetCustomMetadata(const AKey: string): string;
    procedure Dispose;
    property RunCalled: Boolean read FRunCalled;
  end;

  TFakeSessionFactory = class(TInterfacedObject, IInferenceSessionFactory)
  public
    function CreateSession(const AModelPath: string): IInferenceSession; overload;
    function CreateSession(const AModelData: TBytes): IInferenceSession; overload;
  end;

{ TFakeRuntime }

function TFakeRuntime.GetProvider: TInferenceProvider;
begin
  Result := ipCPU;
end;

function TFakeRuntime.IsInitialized: Boolean;
begin
  Result := True;
end;

procedure TFakeRuntime.Initialize(const AConfig: TInferenceConfig);
begin
  // no-op
end;

procedure TFakeRuntime.Shutdown;
begin
  // no-op
end;

{ TFakeSession }

constructor TFakeSession.Create;
begin
  inherited Create;
  FRunCalled := False;
end;

function TFakeSession.GetSessionId: string;
begin
  Result := 'fake-1';
end;

function TFakeSession.GetState: TInferenceSessionState;
begin
  Result := issReady;
end;

function TFakeSession.GetModelInfo: TInferenceModelInfo;
begin
  Result := TInferenceModelInfo.Empty;
end;

function TFakeSession.GetCustomMetadata(const AKey: string): string;
begin
  Result := '';
end;

function TFakeSession.Run(const AInputNames: TArray<string>;
  const AInputValues: TArray<TBytes>;
  const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
begin
  FRunCalled := True;
  Result := TInferenceOutput.Succeeded(5.0,
    TArray<string>.Create('output'));
end;

procedure TFakeSession.Dispose;
begin
  // no-op
end;

{ TFakeSessionFactory }

function TFakeSessionFactory.CreateSession(
  const AModelPath: string): IInferenceSession;
begin
  Result := TFakeSession.Create;
end;

function TFakeSessionFactory.CreateSession(
  const AModelData: TBytes): IInferenceSession;
begin
  Result := TFakeSession.Create;
end;

{ --- Setup / TearDown ---------------------------------------------------- }

procedure TTestInferenceService.Setup;
begin
  TInferenceService.Shutdown;
end;

procedure TTestInferenceService.TearDown;
begin
  TInferenceService.Shutdown;
end;

{ --- IsReady ------------------------------------------------------------- }

procedure TTestInferenceService.Test_IsReady_WhenNotInitialized_ReturnsFalse;
begin
  Assert.IsFalse(TInferenceService.IsReady);
end;

procedure TTestInferenceService.Test_IsReady_AfterSetup_ReturnsTrue;
begin
  TInferenceService.SetSessionFactory(TFakeSessionFactory.Create);
  Assert.IsTrue(TInferenceService.IsReady);
end;

procedure TTestInferenceService.Test_IsReady_AfterShutdown_ReturnsFalse;
begin
  TInferenceService.SetSessionFactory(TFakeSessionFactory.Create);
  TInferenceService.Shutdown;
  Assert.IsFalse(TInferenceService.IsReady);
end;

{ --- SetRuntime ---------------------------------------------------------- }

procedure TTestInferenceService.Test_SetRuntime_AccessibleViaRuntime;
var
  LRuntime: IInferenceRuntime;
begin
  LRuntime := TFakeRuntime.Create;
  TInferenceService.SetRuntime(LRuntime);
  Assert.IsNotNull(TInferenceService.Runtime);
  Assert.AreEqual(ipCPU, TInferenceService.Runtime.GetProvider);
end;

procedure TTestInferenceService.Test_Runtime_WhenNil_ReturnsNil;
begin
  Assert.IsTrue(TInferenceService.Runtime = nil);
end;

{ --- SetSessionFactory --------------------------------------------------- }

procedure TTestInferenceService.Test_SetSessionFactory_AccessibleViaSessionFactory;
begin
  var LFactory: IInferenceSessionFactory := TFakeSessionFactory.Create;
  TInferenceService.SetSessionFactory(LFactory);
  Assert.IsNotNull(TInferenceService.SessionFactory);
end;

{ --- Shutdown ------------------------------------------------------------ }

procedure TTestInferenceService.Test_Shutdown_ClearsRuntime;
begin
  TInferenceService.SetRuntime(TFakeRuntime.Create);
  TInferenceService.Shutdown;
  Assert.IsTrue(TInferenceService.Runtime = nil);
end;

procedure TTestInferenceService.Test_Shutdown_ClearsSessionFactory;
begin
  TInferenceService.SetSessionFactory(TFakeSessionFactory.Create);
  TInferenceService.Shutdown;
  Assert.IsTrue(TInferenceService.SessionFactory = nil);
end;

{ --- CreateSession delegation -------------------------------------------- }

procedure TTestInferenceService.Test_CreateSession_WhenNotReady_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TInferenceService.CreateSession('test.onnx');
    end,
    EInferenceError);
end;

{ --- Run convenience ----------------------------------------------------- }

procedure TTestInferenceService.Test_Run_NilSession_ReturnsFailed;
begin
  var LResult := TInferenceService.Run(nil, nil, nil, nil);
  Assert.IsFalse(LResult.Success);
end;

procedure TTestInferenceService.Test_Run_DelegatesToSession;
var
  LSession: IInferenceSession;
  LResult: TInferenceOutput;
begin
  LSession := TFakeSession.Create;
  LResult := TInferenceService.Run(LSession,
    TArray<string>.Create('input'),
    TArray<TBytes>.Create(TBytes.Create(0, 0, 0, 0)),
    TArray<TArray<Int64>>.Create(TArray<Int64>.Create(1)));
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(Double(5.0), LResult.DurationMs, 0.01);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInferenceService);

end.
