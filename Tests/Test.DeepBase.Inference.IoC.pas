{ ============================================================================
  Test.DeepBase.Inference.IoC
  ---------------------------------------------------------------------------
  Description : DUnitX tests for TInferenceIoCRegistration.
                Tests that RegisterAll validates input and that the types
                and interfaces are correctly wired. Does not call RegisterAll
                directly (it requires onnxruntime.dll), but tests the wiring
                patterns and validation.
  ============================================================================ }

unit Test.DeepBase.Inference.IoC;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Inference.Types,
  DeepBase.IoC;

type
  [TestFixture]
  TTestInferenceIoC = class
  private
    FContainer: TIoCContainer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    { Validation }
    [Test] procedure Test_RegisterAll_NilContainer_RaisesArgNil;

    { Interface resolvability (manual registration) }
    [Test] procedure Test_ManualRegister_Runtime_Singleton;
    [Test] procedure Test_ManualRegister_Factory_Singleton;
    [Test] procedure Test_ManualRegister_ResolveFactory;
    [Test] procedure Test_ManualRegister_ResolveRuntime;

    { Service wiring }
    [Test] procedure Test_Service_SetRuntime_WiresCorrectly;
    [Test] procedure Test_Service_SetFactory_WiresCorrectly;

    { Config }
    [Test] procedure Test_Config_Default_ProviderIsCPU;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.Inference.Runtime,
  DeepBase.Inference.Session,
  DeepBase.Inference.Service,
  DeepBase.Inference.IoC;

{ --- Fake IInferenceRuntime ---------------------------------------------- }

type
  TFakeRuntime = class(TInterfacedObject, IInferenceRuntime)
  public
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;
  end;

  TFakeSessionFactory = class(TInterfacedObject, IInferenceSessionFactory)
  public
    function CreateSession(const AModelPath: string): IInferenceSession; overload;
    function CreateSession(const AModelData: TBytes): IInferenceSession; overload;
  end;

  TFakeSession = class(TInterfacedObject, IInferenceSession)
  public
    function GetSessionId: string;
    function GetState: TInferenceSessionState;
    function GetModelInfo: TInferenceModelInfo;
    function Run(const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
    function GetCustomMetadata(const AKey: string): string;
    procedure Dispose;
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

{ TFakeSession }

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
  Result := TInferenceOutput.Succeeded(1.0, nil);
end;

procedure TFakeSession.Dispose;
begin
  // no-op
end;

{ --- Setup / TearDown ---------------------------------------------------- }

procedure TTestInferenceIoC.Setup;
begin
  FContainer := TIoCContainer.Create;
  TInferenceService.Shutdown;
end;

procedure TTestInferenceIoC.TearDown;
begin
  TInferenceService.Shutdown;
  FContainer.Free;
end;

{ --- Validation ---------------------------------------------------------- }

procedure TTestInferenceIoC.Test_RegisterAll_NilContainer_RaisesArgNil;
begin
  Assert.WillRaise(
    procedure
    begin
      TInferenceIoCRegistration.RegisterAll(nil);
    end,
    EArgumentNilException);
end;

{ --- Manual registration (IoC container patterns) ----------------------- }

procedure TTestInferenceIoC.Test_ManualRegister_Runtime_Singleton;
var
  LRuntime: IInferenceRuntime;
begin
  LRuntime := TFakeRuntime.Create;
  FContainer.RegisterSingleton<IInferenceRuntime>(LRuntime);
  Assert.IsTrue(FContainer.IsRegistered<IInferenceRuntime>);
end;

procedure TTestInferenceIoC.Test_ManualRegister_Factory_Singleton;
var
  LFactory: IInferenceSessionFactory;
begin
  LFactory := TFakeSessionFactory.Create;
  FContainer.RegisterSingleton<IInferenceSessionFactory>(LFactory);
  Assert.IsTrue(FContainer.IsRegistered<IInferenceSessionFactory>);
end;

procedure TTestInferenceIoC.Test_ManualRegister_ResolveFactory;
var
  LFactory: IInferenceSessionFactory;
begin
  LFactory := TFakeSessionFactory.Create;
  FContainer.RegisterSingleton<IInferenceSessionFactory>(LFactory);
  var LResolved: IInferenceSessionFactory;
  Assert.IsTrue(FContainer.TryResolve<IInferenceSessionFactory>(LResolved));
  Assert.IsNotNull(LResolved);
end;

procedure TTestInferenceIoC.Test_ManualRegister_ResolveRuntime;
var
  LRuntime: IInferenceRuntime;
begin
  LRuntime := TFakeRuntime.Create;
  FContainer.RegisterSingleton<IInferenceRuntime>(LRuntime);
  var LResolved: IInferenceRuntime;
  Assert.IsTrue(FContainer.TryResolve<IInferenceRuntime>(LResolved));
  Assert.AreEqual(ipCPU, LResolved.GetProvider);
end;

{ --- Service wiring ------------------------------------------------------ }

procedure TTestInferenceIoC.Test_Service_SetRuntime_WiresCorrectly;
begin
  var LRuntime: IInferenceRuntime := TFakeRuntime.Create;
  TInferenceService.SetRuntime(LRuntime);
  Assert.IsNotNull(TInferenceService.Runtime);
  Assert.AreEqual(ipCPU, TInferenceService.Runtime.GetProvider);
end;

procedure TTestInferenceIoC.Test_Service_SetFactory_WiresCorrectly;
begin
  var LFactory: IInferenceSessionFactory := TFakeSessionFactory.Create;
  TInferenceService.SetSessionFactory(LFactory);
  Assert.IsTrue(TInferenceService.IsReady);
end;

{ --- Config -------------------------------------------------------------- }

procedure TTestInferenceIoC.Test_Config_Default_ProviderIsCPU;
begin
  var LConfig := TInferenceConfig.Default;
  Assert.AreEqual(ipCPU, LConfig.Provider);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInferenceIoC);

end.
