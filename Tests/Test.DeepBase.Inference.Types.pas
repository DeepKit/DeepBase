{ ============================================================================
  Test.DeepBase.Inference.Types
  ---------------------------------------------------------------------------
  Description : DUnitX tests for DeepBase.Inference.Types -- enums, records,
                exceptions, helper functions. No onnxruntime dependency.
  ============================================================================ }

unit Test.DeepBase.Inference.Types;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Inference.Types;

type
  [TestFixture]
  TTestInferenceTypes = class
  public
    { TInferenceConfig }
    [Test] procedure Test_Config_Default_ProviderIsCPU;
    [Test] procedure Test_Config_Default_DeviceIdIsZero;
    [Test] procedure Test_Config_Default_ThreadsAreZero;
    [Test] procedure Test_Config_Default_GraphOptIsAll;

    { TInferenceModelInfo }
    [Test] procedure Test_ModelInfo_Empty_AllZeroOrBlank;

    { TInferenceOutput }
    [Test] procedure Test_Output_Failed_SetsFields;
    [Test] procedure Test_Output_Succeeded_SetsFields;
    [Test] procedure Test_Output_Failed_HasNoOutputNames;

    { TInferenceProvider enum & helper }
    [Test] procedure Test_ProviderToString_CPU;
    [Test] procedure Test_ProviderToString_DML;
    [Test] procedure Test_ProviderToString_CUDA;
    [Test] procedure Test_ProviderToString_Unknown;

    { TInferenceSessionState enum & helper }
    [Test] procedure Test_SessionStateToString_Uninitialized;
    [Test] procedure Test_SessionStateToString_Ready;
    [Test] procedure Test_SessionStateToString_Disposed;
    [Test] procedure Test_SessionStateToString_Unknown;

    { Exception hierarchy }
    [Test] procedure Test_EInferenceError_InheritsException;
    [Test] procedure Test_EInferenceSessionError_InheritsInferenceError;
    [Test] procedure Test_EInferenceProviderError_InheritsInferenceError;
    [Test] procedure Test_EInferenceModelError_InheritsInferenceError;

    { API level constant }
    [Test] procedure Test_ApiLevel_IsOne;

    { Interface GUIDs are non-empty }
    [Test] procedure Test_Interface_IInferenceRuntime_HasGUID;
    [Test] procedure Test_Interface_IInferenceSession_HasGUID;
    [Test] procedure Test_Interface_IInferenceSessionFactory_HasGUID;
  end;

implementation

uses
  System.SysUtils;

{ --- TInferenceConfig ---------------------------------------------------- }

procedure TTestInferenceTypes.Test_Config_Default_ProviderIsCPU;
begin
  Assert.AreEqual(ipCPU, TInferenceConfig.Default.Provider);
end;

procedure TTestInferenceTypes.Test_Config_Default_DeviceIdIsZero;
begin
  Assert.AreEqual(0, TInferenceConfig.Default.DeviceId);
end;

procedure TTestInferenceTypes.Test_Config_Default_ThreadsAreZero;
var
  LConfig: TInferenceConfig;
begin
  LConfig := TInferenceConfig.Default;
  Assert.AreEqual(0, LConfig.IntraOpThreads);
  Assert.AreEqual(0, LConfig.InterOpThreads);
end;

procedure TTestInferenceTypes.Test_Config_Default_GraphOptIsAll;
begin
  Assert.AreEqual(99, TInferenceConfig.Default.GraphOptLevel);
end;

{ --- TInferenceModelInfo ------------------------------------------------- }

procedure TTestInferenceTypes.Test_ModelInfo_Empty_AllZeroOrBlank;
var
  LInfo: TInferenceModelInfo;
begin
  LInfo := TInferenceModelInfo.Empty;
  Assert.AreEqual(0, LInfo.InputCount);
  Assert.AreEqual(0, LInfo.OutputCount);
  Assert.AreEqual('', LInfo.ProducerName);
  Assert.AreEqual('', LInfo.GraphName);
  Assert.AreEqual('', LInfo.Description);
end;

{ --- TInferenceOutput ---------------------------------------------------- }

procedure TTestInferenceTypes.Test_Output_Failed_SetsFields;
var
  LOutput: TInferenceOutput;
begin
  LOutput := TInferenceOutput.Failed('some error');
  Assert.IsFalse(LOutput.Success);
  Assert.AreEqual('some error', LOutput.ErrorMessage);
  Assert.AreEqual(Double(0), LOutput.DurationMs);
end;

procedure TTestInferenceTypes.Test_Output_Succeeded_SetsFields;
var
  LOutput: TInferenceOutput;
begin
  LOutput := TInferenceOutput.Succeeded(123.4,
    TArray<string>.Create('boxes', 'scores'));
  Assert.IsTrue(LOutput.Success);
  Assert.AreEqual('', LOutput.ErrorMessage);
  Assert.AreEqual(Double(123.4), LOutput.DurationMs, 0.001);
  Assert.AreEqual(2, Integer(Length(LOutput.OutputNames)));
  Assert.AreEqual('boxes', LOutput.OutputNames[0]);
  Assert.AreEqual('scores', LOutput.OutputNames[1]);
end;

procedure TTestInferenceTypes.Test_Output_Failed_HasNoOutputNames;
begin
  var LOutput := TInferenceOutput.Failed('err');
  Assert.AreEqual(0, Integer(Length(LOutput.OutputNames)));
end;

{ --- TInferenceProvider helpers ------------------------------------------ }

procedure TTestInferenceTypes.Test_ProviderToString_CPU;
begin
  Assert.AreEqual('cpu', InferenceProviderToString(ipCPU));
end;

procedure TTestInferenceTypes.Test_ProviderToString_DML;
begin
  Assert.AreEqual('dml', InferenceProviderToString(ipDirectML));
end;

procedure TTestInferenceTypes.Test_ProviderToString_CUDA;
begin
  Assert.AreEqual('cuda', InferenceProviderToString(ipCUDA));
end;

procedure TTestInferenceTypes.Test_ProviderToString_Unknown;
begin
  Assert.AreEqual('unknown', InferenceProviderToString(TInferenceProvider(99)));
end;

{ --- TInferenceSessionState helpers -------------------------------------- }

procedure TTestInferenceTypes.Test_SessionStateToString_Uninitialized;
begin
  Assert.AreEqual('Uninitialized', InferenceSessionStateToString(issUninitialized));
end;

procedure TTestInferenceTypes.Test_SessionStateToString_Ready;
begin
  Assert.AreEqual('Ready', InferenceSessionStateToString(issReady));
end;

procedure TTestInferenceTypes.Test_SessionStateToString_Disposed;
begin
  Assert.AreEqual('Disposed', InferenceSessionStateToString(issDisposed));
end;

procedure TTestInferenceTypes.Test_SessionStateToString_Unknown;
begin
  Assert.AreEqual('Unknown', InferenceSessionStateToString(TInferenceSessionState(99)));
end;

{ --- Exception hierarchy ------------------------------------------------- }

procedure TTestInferenceTypes.Test_EInferenceError_InheritsException;
begin
  Assert.InheritsFrom(EInferenceError, Exception);
end;

procedure TTestInferenceTypes.Test_EInferenceSessionError_InheritsInferenceError;
begin
  Assert.InheritsFrom(EInferenceSessionError, EInferenceError);
end;

procedure TTestInferenceTypes.Test_EInferenceProviderError_InheritsInferenceError;
begin
  Assert.InheritsFrom(EInferenceProviderError, EInferenceError);
end;

procedure TTestInferenceTypes.Test_EInferenceModelError_InheritsInferenceError;
begin
  Assert.InheritsFrom(EInferenceModelError, EInferenceError);
end;

{ --- API level ----------------------------------------------------------- }

procedure TTestInferenceTypes.Test_ApiLevel_IsOne;
begin
  Assert.AreEqual(1, INFERENCE_API_LEVEL);
end;

{ --- Interface GUIDs ----------------------------------------------------- }

procedure TTestInferenceTypes.Test_Interface_IInferenceRuntime_HasGUID;
var
  LGUID: TGUID;
begin
  LGUID := IInferenceRuntime;
  Assert.AreNotEqual(TGUID.Empty, LGUID);
end;

procedure TTestInferenceTypes.Test_Interface_IInferenceSession_HasGUID;
var
  LGUID: TGUID;
begin
  LGUID := IInferenceSession;
  Assert.AreNotEqual(TGUID.Empty, LGUID);
end;

procedure TTestInferenceTypes.Test_Interface_IInferenceSessionFactory_HasGUID;
var
  LGUID: TGUID;
begin
  LGUID := IInferenceSessionFactory;
  Assert.AreNotEqual(TGUID.Empty, LGUID);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestInferenceTypes);

end.
