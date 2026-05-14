{ ============================================================================
  Test.DeepBase.Inference.Session
  ---------------------------------------------------------------------------
  Description : DUnitX tests for TInferenceSessionFactory and TInferenceSession.
                Uses a fake IInferenceRuntime to avoid onnxruntime.dll dependency.
                Tests construction validation, error handling, and session state
                without requiring actual ONNX models.
  ============================================================================ }

unit Test.DeepBase.Inference.Session;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Inference.Types;

type
  [TestFixture]
  TTestInferenceSessionFactory = class
  public
    { Construction }
    [Test] procedure Test_Create_NilRuntime_RaisesArgNil;
    [Test] procedure Test_Create_ValidRuntime_Succeeds;

    { CreateSession from file }
    [Test] procedure Test_CreateSession_NonExistentFile_RaisesModelError;

    { CreateSession from bytes }
    [Test] procedure Test_CreateSession_EmptyData_RaisesModelError;
  end;

  [TestFixture]
  TTestInferenceSessionState = class
  public
    { TInferenceOutput }
    [Test] procedure Test_Output_Failed_IsNotSuccess;
    [Test] procedure Test_Output_Succeeded_IsSuccess;
    [Test] procedure Test_Output_Succeeded_TracksDuration;
    [Test] procedure Test_Output_Succeeded_TracksNames;

    { TInferenceModelInfo }
    [Test] procedure Test_ModelInfo_Empty_HasZeroCounts;
    [Test] procedure Test_ModelInfo_Empty_HasBlankStrings;

    { Config round-trip }
    [Test] procedure Test_Config_Default_MatchesExpected;
    [Test] procedure Test_Config_RecordAssignment;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.Inference.Session;

{ --- Fake IInferenceRuntime ---------------------------------------------- }

type
  TFakeRuntime = class(TInterfacedObject, IInferenceRuntime)
  private
    FProvider: TInferenceProvider;
    FInitialized: Boolean;
  public
    constructor Create;
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;
    property Provider: TInferenceProvider read GetProvider;
  end;

constructor TFakeRuntime.Create;
begin
  inherited Create;
  FProvider := ipCPU;
  FInitialized := False;
end;

function TFakeRuntime.GetProvider: TInferenceProvider;
begin
  Result := FProvider;
end;

function TFakeRuntime.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

procedure TFakeRuntime.Initialize(const AConfig: TInferenceConfig);
begin
  FProvider := AConfig.Provider;
  FInitialized := True;
end;

procedure TFakeRuntime.Shutdown;
begin
  FInitialized := False;
end;

{ --- TTestInferenceSessionFactory ---------------------------------------- }

procedure TTestInferenceSessionFactory.Test_Create_NilRuntime_RaisesArgNil;
begin
  Assert.WillRaise(
    procedure
    begin
      TInferenceSessionFactory.Create(nil);
    end,
    EArgumentNilException);
end;

procedure TTestInferenceSessionFactory.Test_Create_ValidRuntime_Succeeds;
var
  LFactory: IInferenceSessionFactory;
begin
  var LRuntime: IInferenceRuntime := TFakeRuntime.Create;
  LRuntime.Initialize(TInferenceConfig.Default);
  Assert.WillNotRaise(
    procedure
    begin
      LFactory := TInferenceSessionFactory.Create(LRuntime);
    end);
  Assert.IsNotNull(LFactory);
end;

procedure TTestInferenceSessionFactory.Test_CreateSession_NonExistentFile_RaisesModelError;
var
  LFactory: IInferenceSessionFactory;
begin
  var LRuntime: IInferenceRuntime := TFakeRuntime.Create;
  LRuntime.Initialize(TInferenceConfig.Default);
  LFactory := TInferenceSessionFactory.Create(LRuntime);

  Assert.WillRaise(
    procedure
    begin
      LFactory.CreateSession('C:\nonexistent\model.onnx');
    end,
    EInferenceModelError);
end;

procedure TTestInferenceSessionFactory.Test_CreateSession_EmptyData_RaisesModelError;
var
  LFactory: IInferenceSessionFactory;
begin
  var LRuntime: IInferenceRuntime := TFakeRuntime.Create;
  LRuntime.Initialize(TInferenceConfig.Default);
  LFactory := TInferenceSessionFactory.Create(LRuntime);

  Assert.WillRaise(
    procedure
    begin
      LFactory.CreateSession(TArray<Byte>(nil));
    end,
    EInferenceModelError);
end;

{ --- TTestInferenceSessionState ------------------------------------------ }

procedure TTestInferenceSessionState.Test_Output_Failed_IsNotSuccess;
begin
  var LOut := TInferenceOutput.Failed('error');
  Assert.IsFalse(LOut.Success);
  Assert.AreEqual('error', LOut.ErrorMessage);
end;

procedure TTestInferenceSessionState.Test_Output_Succeeded_IsSuccess;
begin
  var LOut := TInferenceOutput.Succeeded(10.0, nil);
  Assert.IsTrue(LOut.Success);
end;

procedure TTestInferenceSessionState.Test_Output_Succeeded_TracksDuration;
begin
  var LOut := TInferenceOutput.Succeeded(42.5, nil);
  Assert.AreEqual(Double(42.5), LOut.DurationMs, 0.01);
end;

procedure TTestInferenceSessionState.Test_Output_Succeeded_TracksNames;
begin
  var LNames: TArray<string> := TArray<string>.Create('a', 'b', 'c');
  var LOut := TInferenceOutput.Succeeded(1.0, LNames);
  Assert.AreEqual(3, Integer(Length(LOut.OutputNames)));
  Assert.AreEqual('a', LOut.OutputNames[0]);
  Assert.AreEqual('b', LOut.OutputNames[1]);
  Assert.AreEqual('c', LOut.OutputNames[2]);
end;

procedure TTestInferenceSessionState.Test_ModelInfo_Empty_HasZeroCounts;
begin
  var LInfo := TInferenceModelInfo.Empty;
  Assert.AreEqual(0, LInfo.InputCount);
  Assert.AreEqual(0, LInfo.OutputCount);
end;

procedure TTestInferenceSessionState.Test_ModelInfo_Empty_HasBlankStrings;
begin
  var LInfo := TInferenceModelInfo.Empty;
  Assert.AreEqual('', LInfo.ProducerName);
  Assert.AreEqual('', LInfo.GraphName);
  Assert.AreEqual('', LInfo.Description);
end;

procedure TTestInferenceSessionState.Test_Config_Default_MatchesExpected;
begin
  var LConfig := TInferenceConfig.Default;
  Assert.AreEqual(ipCPU, LConfig.Provider);
  Assert.AreEqual(0, LConfig.DeviceId);
  Assert.AreEqual(0, LConfig.IntraOpThreads);
  Assert.AreEqual(0, LConfig.InterOpThreads);
  Assert.AreEqual(99, LConfig.GraphOptLevel);
end;

procedure TTestInferenceSessionState.Test_Config_RecordAssignment;
var
  LConfigA, LConfigB: TInferenceConfig;
begin
  LConfigA := TInferenceConfig.Default;
  LConfigA.Provider := ipCUDA;
  LConfigA.DeviceId := 2;

  LConfigB := LConfigA;
  Assert.AreEqual(ipCUDA, LConfigB.Provider);
  Assert.AreEqual(2, LConfigB.DeviceId);

  // Modifying B should not affect A (value type copy)
  LConfigB.Provider := ipCPU;
  Assert.AreEqual(ipCUDA, LConfigA.Provider);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInferenceSessionFactory);
  TDUnitX.RegisterTestFixture(TTestInferenceSessionState);

end.
