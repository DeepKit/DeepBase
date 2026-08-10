{ ============================================================================
  DeepBase.Speech.ASR.SAPIAdapter
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Adapter wrapping the plain TDeepBaseSAPIASR class so it can be
                fed into TSpeechService as an ISpeechRecognizerEx backend.
                TDeepBaseSAPIASR is event/stream-driven (Start -> SetOnFinal
                -> Stop) and exposes CheckStatus: string, which does not match
                the ISpeechRecognizerEx contract — this adapter bridges those
                gaps so SAPI can serve as the always-on-Windows ASR fallback.

                Scope note (Stage 0 wiring): the adapter makes SAPI injectable
                so FASR <> nil (no more NO_ASR on a SAPI-only box). Batch
                Recognize() is NOT supported by SAPI and returns
                srsNotImplemented — callers should use the streaming path. A
                full SAPI batch/streaming adapter is a later milestone.
  Thread Safety: SAPI calls are serialized by the inner TDeepBaseSAPIASR lock.
  ============================================================================ }

unit DeepBase.Speech.ASR.SAPIAdapter;

interface

uses
  System.SysUtils,
  DeepBase.Speech.Types,
  DeepBase.Speech.ASR.SAPI;

type
  TDeepBaseSAPIASRAdapter = class(TInterfacedObject, ISpeechRecognizerEx)
  private
    FInner: TDeepBaseSAPIASR;
    FOwnsInner: Boolean;
  public
    // AInner = nil => lazily create and own a fresh TDeepBaseSAPIASR.
    // AInner <> nil => hold a weak reference (caller owns the lifetime, e.g.
    // the GlobalSAPIASR singleton), destructor does NOT free it.
    constructor Create(AInner: TDeepBaseSAPIASR = nil);
    destructor Destroy; override;

    { ISpeechRecognizer }
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;

    { ISpeechRecognizerEx }
    function IsAvailable: Boolean;
    function Kind: TASRBackendKind;
    function SupportsBatch: Boolean;
    function SupportsStreaming: Boolean;
    procedure LoadGrammar(const AWords: TArray<string>);
  end;

implementation

{ TDeepBaseSAPIASRAdapter }

constructor TDeepBaseSAPIASRAdapter.Create(AInner: TDeepBaseSAPIASR);
begin
  inherited Create;
  if AInner <> nil then
  begin
    FInner := AInner;
    FOwnsInner := False;
  end
  else
  begin
    FInner := TDeepBaseSAPIASR.Create;
    FOwnsInner := True;
  end;
end;

destructor TDeepBaseSAPIASRAdapter.Destroy;
begin
  // Only free an inner we created ourselves; a borrowed singleton (GlobalSAPIASR)
  // is owned by its declaring unit and outlives this adapter.
  if FOwnsInner then
    FreeAndNil(FInner);
  inherited;
end;

{ ISpeechRecognizer }

function TDeepBaseSAPIASRAdapter.CheckStatus(out AError: string): Boolean;
begin
  // TDeepBaseSAPIASR.CheckStatus returns a status string; expose it via the
  // out param. The backend is considered healthy as long as it exists — SAPI
  // has no separate liveness probe, IsAvailable covers readiness.
  AError := FInner.CheckStatus;
  Result := True;
end;

function TDeepBaseSAPIASRAdapter.Recognize(const AAudio: TSpeechAudioData;
  const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
begin
  // SAPI is event/stream-driven and has no synchronous batch Recognize entry.
  // Rather than fake a result, surface the limitation so callers route through
  // the streaming path. This keeps the wiring honest and the failure explicit.
  Result := TSpeechRecognitionResult.Failed(srsProviderNotReady,
    'SAPI_BATCH_UNSUPPORTED',
    'SAPI ASR does not support synchronous batch Recognize; use the streaming path');
end;

{ ISpeechRecognizerEx }

function TDeepBaseSAPIASRAdapter.IsAvailable: Boolean;
begin
  Result := FInner.IsAvailable;
end;

function TDeepBaseSAPIASRAdapter.Kind: TASRBackendKind;
begin
  Result := abkSAPI;
end;

function TDeepBaseSAPIASRAdapter.SupportsBatch: Boolean;
begin
  // SAPI CAN do batch internally (record -> recognize), but this adapter does
  // not expose it — Recognize returns srsNotImplemented above. Advertise False
  // so the resolver/registry do not pick SAPI for a batch-only use case.
  Result := False;
end;

function TDeepBaseSAPIASRAdapter.SupportsStreaming: Boolean;
begin
  Result := True;
end;

procedure TDeepBaseSAPIASRAdapter.LoadGrammar(const AWords: TArray<string>);
begin
  FInner.LoadGrammar(AWords);
end;

end.
