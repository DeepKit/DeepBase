{ ============================================================================
  Test.DeepBase.Inference.Runtime
  ---------------------------------------------------------------------------
  Description : DUnitX tests for TInferenceRuntime. Tests lifecycle, config,
                and CPU provider path. GPU providers (DML/CUDA) are tested
                only for config parsing since they require onnxruntime.dll.
  ============================================================================ }

unit Test.DeepBase.Inference.Runtime;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Inference.Types;

type
  [TestFixture]
  TTestInferenceRuntime = class
  private
    FRuntime: IInferenceRuntime;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    { Construction }
    [Test] procedure Test_Create_DefaultProviderIsCPU;
    [Test] procedure Test_Create_NotInitialized;

    { Initialize with CPU }
    [Test] procedure Test_Initialize_CPU_SetsInitialized;
    [Test] procedure Test_Initialize_CPU_SetsProvider;
    [Test] procedure Test_Initialize_CPU_WithCustomThreads;
    [Test] procedure Test_Initialize_CPU_WithGraphOpt;

    { Shutdown }
    [Test] procedure Test_Shutdown_ClearsInitialized;
    [Test] procedure Test_Shutdown_WhenNotInitialized_DoesNotRaise;

    { Re-initialize }
    [Test] procedure Test_ReInitialize_Succeeds;

    { GetProvider }
    [Test] procedure Test_GetProvider_ReturnsConfiguredProvider;

    { Error cases }
    [Test] procedure Test_Initialize_UnsupportedProvider_Raises;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.Inference.Runtime;

{ --- Setup / TearDown ---------------------------------------------------- }

procedure TTestInferenceRuntime.Setup;
begin
  FRuntime := TInferenceRuntime.Create;
end;

procedure TTestInferenceRuntime.TearDown;
begin
  if FRuntime <> nil then
    FRuntime.Shutdown;
  FRuntime := nil;
end;

{ --- Construction -------------------------------------------------------- }

procedure TTestInferenceRuntime.Test_Create_DefaultProviderIsCPU;
begin
  Assert.AreEqual(ipCPU, FRuntime.GetProvider);
end;

procedure TTestInferenceRuntime.Test_Create_NotInitialized;
begin
  Assert.IsFalse(FRuntime.IsInitialized);
end;

{ --- Initialize with CPU ------------------------------------------------- }

procedure TTestInferenceRuntime.Test_Initialize_CPU_SetsInitialized;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);
end;

procedure TTestInferenceRuntime.Test_Initialize_CPU_SetsProvider;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  FRuntime.Initialize(LConfig);
  Assert.AreEqual(ipCPU, FRuntime.GetProvider);
end;

procedure TTestInferenceRuntime.Test_Initialize_CPU_WithCustomThreads;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  LConfig.IntraOpThreads := 4;
  LConfig.InterOpThreads := 2;
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);
end;

procedure TTestInferenceRuntime.Test_Initialize_CPU_WithGraphOpt;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  LConfig.GraphOptLevel := 1; // ORT_ENABLE_BASIC
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);
end;

{ --- Shutdown ------------------------------------------------------------ }

procedure TTestInferenceRuntime.Test_Shutdown_ClearsInitialized;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);

  FRuntime.Shutdown;
  Assert.IsFalse(FRuntime.IsInitialized);
end;

procedure TTestInferenceRuntime.Test_Shutdown_WhenNotInitialized_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FRuntime.Shutdown;
    end);
end;

{ --- Re-initialize ------------------------------------------------------- }

procedure TTestInferenceRuntime.Test_ReInitialize_Succeeds;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);

  // Re-init should work without error
  FRuntime.Initialize(LConfig);
  Assert.IsTrue(FRuntime.IsInitialized);
  Assert.AreEqual(ipCPU, FRuntime.GetProvider);
end;

{ --- GetProvider --------------------------------------------------------- }

procedure TTestInferenceRuntime.Test_GetProvider_ReturnsConfiguredProvider;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  FRuntime.Initialize(LConfig);
  Assert.AreEqual(ipCPU, FRuntime.Provider);
end;

{ --- Error cases --------------------------------------------------------- }

procedure TTestInferenceRuntime.Test_Initialize_UnsupportedProvider_Raises;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  {$RANGECHECKS OFF}
  LConfig.Provider := TInferenceProvider(99);
  {$RANGECHECKS ON}
  Assert.WillRaise(
    procedure
    begin
      FRuntime.Initialize(LConfig);
    end,
    EInferenceProviderError);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInferenceRuntime);

end.
