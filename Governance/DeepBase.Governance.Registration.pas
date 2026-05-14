{ ============================================================================
  DeepBase.Governance.Registration
  ---------------------------------------------------------------------------
  Version     : 2.2
  Description : One-call entry point to bring up Governance. Two overloads:
                1) Legacy — in-memory only, no ConfigDB persistence.
                2) ConfigDB-backed — persists to governance_* tables.
  ============================================================================ }

unit DeepBase.Governance.Registration;

interface

uses
  FireDAC.Comp.Client,
  DeepBase.Governance.Lifecycle,
  DeepBase.Governance.ConfigRegistrar;

/// Legacy overload (no ConfigDB persistence).
procedure RegisterGovernance(AMode: TGovernanceMode;
  ASetupProc: TGovernanceSetupProc); overload;

/// ConfigDB-backed overload. Persists gates/actions/purposes/mode.
procedure RegisterGovernance(AMode: TGovernanceMode;
  AConfigDB: TFDConnection;
  ASetupProc: TGovernanceConfigSetupProc); overload;

/// Shutdown governance. Safe to call multiple times.
procedure ShutdownGovernance;

/// Access the ConfigRegistrar (nil if legacy overload was used).
function GovernanceRegistrar: TConfigRegistrar;

implementation

uses
  System.SysUtils;

procedure RegisterGovernance(AMode: TGovernanceMode;
  ASetupProc: TGovernanceSetupProc);
begin
  if Assigned(GovernanceLifecycle) then
    Exit;
  GovernanceLifecycle := TGovernanceLifecycle.Create;
  GovernanceLifecycle.Configure(AMode, ASetupProc);
  GovernanceLifecycle.Initialize;
  GovernanceLifecycle.Start;
end;

procedure RegisterGovernance(AMode: TGovernanceMode;
  AConfigDB: TFDConnection;
  ASetupProc: TGovernanceConfigSetupProc);
begin
  if Assigned(GovernanceLifecycle) then
    Exit;
  GovernanceLifecycle := TGovernanceLifecycle.Create;
  GovernanceLifecycle.ConfigureEx(AMode, AConfigDB, ASetupProc);
  GovernanceLifecycle.Initialize;
  GovernanceLifecycle.Start;
end;

procedure ShutdownGovernance;
begin
  if Assigned(GovernanceLifecycle) then
  begin
    GovernanceLifecycle.Shutdown;
    FreeAndNil(GovernanceLifecycle);
  end;
end;

function GovernanceRegistrar: TConfigRegistrar;
begin
  if Assigned(GovernanceLifecycle) then
    Result := GovernanceLifecycle.ConfigRegistrar
  else
    Result := nil;
end;

end.
