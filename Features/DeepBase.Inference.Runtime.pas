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
  {$IFDEF HAS_ONNX}
  onnxruntime,
  onnxruntime_pas_api,
  onnxruntime.dml,
  {$ENDIF}
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
  FLock.Enter;
  try
    Result := FProvider;
  finally
    FLock.Leave;
  end;
end;

function TInferenceRuntime.IsInitialized: Boolean;
begin
  FLock.Enter;
  try
    Result := FInitialized;
  finally
    FLock.Leave;
  end;
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

    {$IFDEF HAS_ONNX}
    // INFER-002 / INFER-003: onnxruntime-pas exposes a process-global
    // DefaultSessionOptions singleton; the underlying ONNX C API does not
    // offer a public reset for already-attached execution providers. We
    // therefore (re)apply the explicit knobs on every Initialize so a
    // re-Initialize after Shutdown lands on the configuration the caller
    // asked for, instead of inheriting whatever was last set.

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
    {$ELSE}
    case AConfig.Provider of
      ipCPU: AttachProviderCPU;
    else
      raise EInferenceProviderError.CreateFmt(
        'ONNX runtime not available. Provider %s not supported.',
        [InferenceProviderToString(AConfig.Provider)]);
    end;
    {$ENDIF}

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

  // INFER-001: Reset wrapper state so re-Initialize works cleanly.
  // The onnxruntime-pas library exposes a process-global DefaultSessionOptions
  // singleton; the underlying ONNX C API does not offer a public way to
  // detach an already-attached execution provider. Instead of dangerous
  // hand-rolled releases of someone else's globals, we reset our own state
  // and ensure that any later Initialize re-applies the knobs we care about
  // (thread counts, optimisation level, provider). Existing sessions hold
  // their own internal options copy, so they are unaffected by this reset.
  FProvider := ipCPU;
  FOptionsBuilt := False;
  FInitialized := False;

  Logger.Info('Inference.Runtime: shutdown complete', 'Inference');
end;

{ --- Provider attachment ------------------------------------------------- }

procedure TInferenceRuntime.AttachProviderCPU;
begin
  // CPU is the default; no provider attachment needed
  Logger.Info('Inference.Runtime: using CPU provider', 'Inference');
end;



end.
