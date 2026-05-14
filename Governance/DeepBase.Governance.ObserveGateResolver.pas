// AI-GENERATED
// DeepBase.Governance.ObserveGateResolver.pas
// IGateResolver decorator that implements observe/enforce mode switching.
//   - observe mode: non-open inner resolutions are logged as blocked evidence
//     and then forced to gsOpen so the action proceeds (no user-visible block).
//   - enforce mode: pure pass-through to the inner resolver.
// Depends on Types + Interfaces only. Does NOT declare its own TGovernanceMode
// enum — the caller passes a simple boolean provider so higher-level units
// (Lifecycle) can own the canonical governance-mode enum without circular deps.

unit DeepBase.Governance.ObserveGateResolver;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// Returns True when governance is in OBSERVE mode (log only, never block),
  /// False when in ENFORCE mode (pass through inner resolver unchanged).
  /// Evaluated on every Resolve/GetState call so mode flips take effect
  /// without recreating the resolver.
  TObserveModeProvider = reference to function: Boolean;

  /// IGateResolver decorator. Wraps an inner resolver. When the provider
  /// reports observe mode and the inner resolver returns a non-open state,
  /// the decorator logs the would-have-been-blocked evidence and overrides
  /// the resolution to gsOpen. In enforce mode it pass-throughs unchanged.
  TObserveGateResolver = class(TInterfacedObject, IGateResolver)
  private
    FInner: IGateResolver;
    FEvidenceRecorder: IEvidenceRecorder;
    FModeProvider: TObserveModeProvider;
    function IsObserveMode: Boolean;
  public
    constructor Create(AInner: IGateResolver;
      AEvidenceRecorder: IEvidenceRecorder;
      AModeProvider: TObserveModeProvider);

    // IGateResolver
    function Resolve(const AGateKey: string;
      AContext: TJSONObject): TGateResolution;
    function GetState(const AGateKey: string;
      AContext: TJSONObject): TGateState;
  end;

implementation

{ TObserveGateResolver }

constructor TObserveGateResolver.Create(AInner: IGateResolver;
  AEvidenceRecorder: IEvidenceRecorder;
  AModeProvider: TObserveModeProvider);
begin
  if AInner = nil then
    raise EArgumentNilException.Create(
      'TObserveGateResolver: inner resolver must not be nil');
  inherited Create;
  FInner := AInner;
  FEvidenceRecorder := AEvidenceRecorder;
  FModeProvider := AModeProvider;
end;

function TObserveGateResolver.IsObserveMode: Boolean;
begin
  if Assigned(FModeProvider) then
    Result := FModeProvider
  else
    // No provider configured → fail-closed (enforce).
    Result := False;
end;

function TObserveGateResolver.Resolve(const AGateKey: string;
  AContext: TJSONObject): TGateResolution;
begin
  Result := FInner.Resolve(AGateKey, AContext);

  if IsObserveMode and (Result.State <> gsOpen) then
  begin
    // Record what would have been blocked so operators can see the impact
    // of switching to enforce mode later.
    if FEvidenceRecorder <> nil then
    begin
      try
        FEvidenceRecorder.LogBlocked(AGateKey, Result.BlockedReason, AContext);
      except
        // Evidence logging must never break the caller path in observe mode.
        // The recorder has its own failure queue + callback for diagnostics.
      end;
    end;

    // Override to open so downstream EnterGate proceeds.
    Result.State := gsOpen;
    Result.BlockedReason := '';
  end;
  // Enforce mode: pass-through unchanged.
end;

function TObserveGateResolver.GetState(const AGateKey: string;
  AContext: TJSONObject): TGateState;
var
  LResolution: TGateResolution;
begin
  // Route through Resolve so the observe-mode override (and evidence
  // logging) applies here too. This keeps Resolve / GetState consistent.
  LResolution := Resolve(AGateKey, AContext);
  Result := LResolution.State;
end;

end.
