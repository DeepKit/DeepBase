{ ============================================================================
  DeepBase.Inference.Types
  ---------------------------------------------------------------------------
  Description : Type definitions for the DeepBase Inference framework.
                Pure type declarations -- interfaces, records, enums,
                exceptions. No implementation logic beyond record helpers.
                No dependency on onnxruntime units.
  ============================================================================ }

unit DeepBase.Inference.Types;

interface

uses
  System.SysUtils,
  System.Classes;

const
  INFERENCE_API_LEVEL = 1;

type
  { --- Exceptions ---------------------------------------------------------- }

  EInferenceError = class(Exception);
  EInferenceSessionError = class(EInferenceError);
  EInferenceProviderError = class(EInferenceError);
  EInferenceModelError = class(EInferenceError);

  { --- Execution provider -------------------------------------------------- }

  TInferenceProvider = (
    ipCPU,
    ipDirectML,
    ipCUDA
  );

  { --- Session lifecycle --------------------------------------------------- }

  TInferenceSessionState = (
    issUninitialized,
    issReady,
    issDisposed
  );

  { --- Configuration record ------------------------------------------------ }

  TInferenceConfig = record
    Provider: TInferenceProvider;
    DeviceId: Integer;
    IntraOpThreads: Integer;
    InterOpThreads: Integer;
    GraphOptLevel: Integer;
    class function Default: TInferenceConfig; static;
    class function FromConfig: TInferenceConfig; static;
  end;

  { --- Model metadata ------------------------------------------------------ }

  TInferenceModelInfo = record
    InputCount: Integer;
    OutputCount: Integer;
    ProducerName: string;
    GraphName: string;
    Description: string;
    class function Empty: TInferenceModelInfo; static;
  end;

  { --- Inference output ---------------------------------------------------- }

  TInferenceOutput = record
    Success: Boolean;
    ErrorMessage: string;
    DurationMs: Double;
    OutputNames: TArray<string>;
    class function Failed(const AError: string): TInferenceOutput; static;
    class function Succeeded(ADurationMs: Double;
      const ANames: TArray<string>): TInferenceOutput; static;
  end;

  { --- Interfaces ---------------------------------------------------------- }

  IInferenceRuntime = interface
    ['{F1A2B3C4-D5E6-4F7A-8B9C-0D1E2F3A4B5C}']
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;
    property Provider: TInferenceProvider read GetProvider;
  end;

  IInferenceSession = interface
    ['{A2B3C4D5-E6F7-4A8B-9C0D-1E2F3A4B5C6D}']
    function GetSessionId: string;
    function GetState: TInferenceSessionState;
    function GetModelInfo: TInferenceModelInfo;
    function Run(const AInputNames: TArray<string>;
      const AInputValues: TArray<TBytes>;
      const AInputShapes: TArray<TArray<Int64>>): TInferenceOutput;
    procedure Dispose;
    property SessionId: string read GetSessionId;
    property State: TInferenceSessionState read GetState;
    property ModelInfo: TInferenceModelInfo read GetModelInfo;
  end;

  IInferenceSessionFactory = interface
    ['{B3C4D5E6-F7A8-4B9C-0D1E-2F3A4B5C6D7E}']
    function CreateSession(const AModelPath: string): IInferenceSession; overload;
    function CreateSession(const AModelData: TBytes): IInferenceSession; overload;
  end;

{ --- Helper functions ----------------------------------------------------- }

function InferenceProviderToString(AValue: TInferenceProvider): string;
function InferenceSessionStateToString(AValue: TInferenceSessionState): string;

implementation

uses
  DeepBase.Config;

{ --- TInferenceConfig ---------------------------------------------------- }

class function TInferenceConfig.Default: TInferenceConfig;
begin
  Result.Provider := ipCPU;
  Result.DeviceId := 0;
  Result.IntraOpThreads := 0;
  Result.InterOpThreads := 0;
  Result.GraphOptLevel := 99; // ORT_ENABLE_ALL
end;

class function TInferenceConfig.FromConfig: TInferenceConfig;
var
  LProvider: string;
begin
  Result := Default;
  LProvider := LowerCase(GetConfig('Inference.Provider', 'cpu'));
  if LProvider = 'dml' then
    Result.Provider := ipDirectML
  else if LProvider = 'cuda' then
    Result.Provider := ipCUDA
  else
    Result.Provider := ipCPU;
  Result.DeviceId := GetConfigInt('Inference.DeviceId', 0);
  Result.IntraOpThreads := GetConfigInt('Inference.IntraOpThreads', 0);
  Result.InterOpThreads := GetConfigInt('Inference.InterOpThreads', 0);
  Result.GraphOptLevel := GetConfigInt('Inference.GraphOptLevel', 99);
end;

{ --- TInferenceModelInfo ------------------------------------------------- }

class function TInferenceModelInfo.Empty: TInferenceModelInfo;
begin
  Result.InputCount := 0;
  Result.OutputCount := 0;
  Result.ProducerName := '';
  Result.GraphName := '';
  Result.Description := '';
end;

{ --- TInferenceOutput ---------------------------------------------------- }

class function TInferenceOutput.Failed(
  const AError: string): TInferenceOutput;
begin
  Result.Success := False;
  Result.ErrorMessage := AError;
  Result.DurationMs := 0;
  Result.OutputNames := nil;
end;

class function TInferenceOutput.Succeeded(ADurationMs: Double;
  const ANames: TArray<string>): TInferenceOutput;
begin
  Result.Success := True;
  Result.ErrorMessage := '';
  Result.DurationMs := ADurationMs;
  Result.OutputNames := ANames;
end;

{ --- Helper functions ---------------------------------------------------- }

function InferenceProviderToString(AValue: TInferenceProvider): string;
begin
  case AValue of
    ipCPU:      Result := 'cpu';
    ipDirectML: Result := 'dml';
    ipCUDA:     Result := 'cuda';
  else
    Result := 'unknown';
  end;
end;

function InferenceSessionStateToString(
  AValue: TInferenceSessionState): string;
begin
  case AValue of
    issUninitialized: Result := 'Uninitialized';
    issReady:         Result := 'Ready';
    issDisposed:      Result := 'Disposed';
  else
    Result := 'Unknown';
  end;
end;

end.
