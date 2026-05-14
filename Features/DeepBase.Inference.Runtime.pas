{ ============================================================================
  DeepBase.Inference.Runtime
  ---------------------------------------------------------------------------
  Description : Wraps TONNXRuntime environment initialization and session
                options with provider configuration (CPU / DirectML / CUDA).
  ============================================================================ }

unit DeepBase.Inference.Runtime;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  DeepBase.Inference.Types;

type
  TInferenceRuntime = class(TInterfacedObject, IInferenceRuntime)
  private
    FProvider: TInferenceProvider;
    FInitialized: Boolean;
    FLock: TCriticalSection;
    FOptionsBuilt: Boolean;
    procedure AttachProviderCPU;
    procedure AttachProviderDML(ADeviceId: Integer);
    procedure AttachProviderCUDA;
    procedure ShutdownInternal;
  public
    constructor Create;
    destructor Destroy; override;

    { IInferenceRuntime }
    function GetProvider: TInferenceProvider;
    function IsInitialized: Boolean;
    procedure Initialize(const AConfig: TInferenceConfig);
    procedure Shutdown;

    property Provider: TInferenceProvider read GetProvider;
  end;

implementation

uses
  onnxruntime,
  onnxruntime_pas_api,
  onnxruntime.dml,
  DeepBase.Logging;

{ --- TInferenceRuntime --------------------------------------------------- }

constructor TInferenceRuntime.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FProvider := ipCPU;
  FInitialized := False;
  FOptionsBuilt := False;
end;

destructor TInferenceRuntime.Destroy;
begin
  Shutdown;
  FreeAndNil(FLock);
  inherited;
end;

function TInferenceRuntime.GetProvider: TInferenceProvider;
begin
  Result := FProvider;
end;

function TInferenceRuntime.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

procedure TInferenceRuntime.Initialize(const AConfig: TInferenceConfig);
begin
  FLock.Enter;
  try
    if FInitialized then
    begin
      Logger.Warn('Inference.Runtime: already initialized, shutting down first',
        'Inference');
      ShutdownInternal;
    end;

    FProvider := AConfig.Provider;

    // Configure thread counts on global DefaultSessionOptions
    if AConfig.IntraOpThreads > 0 then
      DefaultSessionOptions.SetIntraOpNumThreads(AConfig.IntraOpThreads);
    if AConfig.InterOpThreads > 0 then
      DefaultSessionOptions.SetInterOpNumThreads(AConfig.InterOpThreads);

    // Set graph optimization level
    DefaultSessionOptions.SetGraphOptimizationLevel(
      GraphOptimizationLevel(AConfig.GraphOptLevel));

    // Attach execution provider to DefaultSessionOptions
    case AConfig.Provider of
      ipCPU:      AttachProviderCPU;
      ipDirectML: AttachProviderDML(AConfig.DeviceId);
      ipCUDA:     AttachProviderCUDA;
    else
      raise EInferenceProviderError.CreateFmt(
        'Unsupported execution provider: %s',
        [InferenceProviderToString(AConfig.Provider)]);
    end;

    FOptionsBuilt := True;
    FInitialized := True;

    Logger.InfoFmt('Inference.Runtime: initialized (provider=%s)',
      [InferenceProviderToString(FProvider)], 'Inference');
  finally
    FLock.Leave;
  end;
end;

procedure TInferenceRuntime.Shutdown;
begin
  FLock.Enter;
  try
    ShutdownInternal;
  finally
    FLock.Leave;
  end;
end;

procedure TInferenceRuntime.ShutdownInternal;
begin
  if not FInitialized then
    Exit;
  FInitialized := False;
  FOptionsBuilt := False;
  Logger.Info('Inference.Runtime: shutdown complete', 'Inference');
end;

{ --- Provider attachment ------------------------------------------------- }

procedure TInferenceRuntime.AttachProviderCPU;
begin
  // CPU is the default; no provider attachment needed
  Logger.Info('Inference.Runtime: using CPU provider', 'Inference');
end;

procedure TInferenceRuntime.AttachProviderDML(ADeviceId: Integer);
var
  LDMLProv: POrtDmlApi;
begin
  // DML requires sequential execution and disabled memory patterns
  DefaultSessionOptions.DisableMemPattern;
  DefaultSessionOptions.SetExecutionMode(ORT_SEQUENTIAL);

  // Resolve the DML extension API
  ThrowOnError(
    GetApi.GetExecutionProviderApi('DML', ORT_API_VERSION, @LDMLProv));

  if LDMLProv = nil then
    raise EInferenceProviderError.Create(
      'Failed to resolve DirectML provider API. ' +
      'Ensure onnxruntime.dll with DirectML support is available.');

  ThrowOnError(
    LDMLProv.SessionOptionsAppendExecutionProvider_DML(
      DefaultSessionOptions.p_, ADeviceId));

  Logger.InfoFmt('Inference.Runtime: DirectML attached (device %d)',
    [ADeviceId], 'Inference');
end;

procedure TInferenceRuntime.AttachProviderCUDA;
var
  LCUDAOpts: OrtCUDAProviderOptionsV2;
begin
  FillChar(LCUDAOpts, SizeOf(LCUDAOpts), 0);
  ThrowOnError(GetApi.CreateCUDAProviderOptions(@LCUDAOpts));
  try
    ThrowOnError(
      GetApi.SessionOptionsAppendExecutionProvider_CUDA_V2(
        DefaultSessionOptions.p_, @LCUDAOpts));
  finally
    GetApi.ReleaseCUDAProviderOptions(@LCUDAOpts);
  end;

  Logger.Info('Inference.Runtime: CUDA provider attached', 'Inference');
end;

end.
