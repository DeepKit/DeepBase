{ ============================================================================
  DeepBase.TimeGuard.SecretStore - Last-known-good persistence adapter

  Version: 1.0
  Description:
    Implements TTimeGuard's persistence port (ITimeGuardSecretStore) on top of
    the Core secret storage abstraction (DeepBase.Security.SecretStore), so the
    last-known-good clock watermark survives process restarts on a machine that
    has a credential backend (Windows Credential Manager; other platforms only
    when one exists).

    Place in the trust model: this watermark is defence in depth, not the
    boundary. The primary anti-rewind boundary is the monotonic Core watermark
    (TDeepBaseTimeSource.SeedWatermark, persisted by DeepBase.License); TimeGuard
    only adds a second, independently persisted signal. A machine without a
    credential backend therefore keeps "no watermark" — exactly the pre-wiring
    reading — instead of turning an environment gap into a licence refusal.

  Usage:
    // Production: TTimeGuard falls back to this adapter on its own.
    // Tests: TTimeGuard.SetSecretStore(<fake>) overrides the platform backend.
  ============================================================================ }

unit DeepBase.TimeGuard.SecretStore;

interface

uses
  System.SysUtils,
  DeepBase.Security.SecretStore,
  DeepBase.TimeGuard;

type
  /// <summary>
  /// ITimeGuardSecretStore backed by an ISecretStore. Keys pass through
  /// unchanged, so the watermark one build wrote is the watermark the next
  /// build reads.
  /// </summary>
  TTimeGuardSecretStore = class(TInterfacedObject, ITimeGuardSecretStore)
  private
    FStore: ISecretStore;
  public
    constructor Create(const AStore: ISecretStore);
    procedure SaveSecret(const AKey, AValue: string);
    function LoadSecret(const AKey: string): string;
  end;

  /// <summary>
  /// Platform-backed watermark store, or nil when this machine offers no
  /// credential backend. Never raises: an absent backend must leave the clock
  /// reading honest, not refused.
  /// </summary>
  function CreateTimeGuardSecretStore: ITimeGuardSecretStore;

implementation

{ TTimeGuardSecretStore }

constructor TTimeGuardSecretStore.Create(const AStore: ISecretStore);
begin
  inherited Create;
  FStore := AStore;
end;

procedure TTimeGuardSecretStore.SaveSecret(const AKey, AValue: string);
begin
  FStore.Put(AKey, AValue);
end;

function TTimeGuardSecretStore.LoadSecret(const AKey: string): string;
begin
  if not FStore.TryGet(AKey, Result) then
    Result := '';
end;

{ CreateTimeGuardSecretStore }

function CreateTimeGuardSecretStore: ITimeGuardSecretStore;
begin
  Result := nil;
  try
    Result := TTimeGuardSecretStore.Create(TSecretStoreFactory.CreatePlatformStore);
  except
    on ESecretStoreUnavailable do
      // Fail-soft by design (WO-20260929-AUDIT-甲-A11 §一-2): the absence of a
      // credential backend is an environment gap, and the boundary against
      // clock rewind is the monotonic Core watermark, not this one.
      Result := nil;
  end;
end;

end.
