{ ============================================================================
  DeepBase.VCL.DeepShell.Governance

  Default IGovernanceService implementations bundled with the shell core.
  These are NOT the real OCGS / governance integration - they only provide
  the contract and a safe-by-default observer so the shell behaves
  predictably before a real governance adapter is wired up.

    - TShellAllowAllGovernanceService: legacy null behaviour, always allows.
    - TShellAuditOnlyGovernanceService: gmObserve-style default; allows
      everything but writes a diagnostic entry through IShellStatusManager
      for L2 / L3 commands so audit trail is visible even without OCGS.

  See docs/75.vcl.DeepShell-Command-Governance集成.md
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Governance;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  /// <summary>
  /// Strict null governance: always allows, never logs. Use only in tests
  /// or when downstream explicitly opts out of audit visibility.
  /// </summary>
  TShellAllowAllGovernanceService = class(TInterfacedObject, IGovernanceService)
  public
    function IsEnabled: Boolean;
    function EnterGate(const AGateKey, AContextJson: string;
      out AResult: TShellGateResult): Boolean;
  end;

  /// <summary>
  /// Default governance for development / pre-OCGS rollout. Does not block,
  /// but writes a diagnostic for medium / high risk commands so the audit
  /// trail is non-empty during gmObserve. Risk level is parsed out of the
  /// context JSON injected by TShellCommandManager.BuildContextJson.
  /// </summary>
  TShellAuditOnlyGovernanceService = class(TInterfacedObject, IGovernanceService)
  private
    FStatus: IShellStatusManager;
    FMinRiskLevel: TShellRiskLevel;
  public
    constructor Create(const AStatus: IShellStatusManager;
      AMinRiskLevel: TShellRiskLevel = rlMedium);
    destructor Destroy; override;
    function IsEnabled: Boolean;
    function EnterGate(const AGateKey, AContextJson: string;
      out AResult: TShellGateResult): Boolean;
  end;

implementation

// ---------------------------------------------------------------------------
// TShellAllowAllGovernanceService
// ---------------------------------------------------------------------------

function TShellAllowAllGovernanceService.IsEnabled: Boolean;
begin
  // Returning False keeps TShellCommandManager.Execute on the early-out path
  // and avoids the JSON build cost when nobody actually consumes evidence.
  Result := False;
end;

function TShellAllowAllGovernanceService.EnterGate(const AGateKey, AContextJson: string;
  out AResult: TShellGateResult): Boolean;
begin
  AResult := TShellGateResult.AllowedDefault;
  Result := True;
end;

// ---------------------------------------------------------------------------
// TShellAuditOnlyGovernanceService
// ---------------------------------------------------------------------------

constructor TShellAuditOnlyGovernanceService.Create(const AStatus: IShellStatusManager;
  AMinRiskLevel: TShellRiskLevel);
begin
  inherited Create;
  FStatus := AStatus;
  FMinRiskLevel := AMinRiskLevel;
end;

destructor TShellAuditOnlyGovernanceService.Destroy;
begin
  FStatus := nil;
  inherited;
end;

function TShellAuditOnlyGovernanceService.IsEnabled: Boolean;
begin
  Result := True;
end;

function TShellAuditOnlyGovernanceService.EnterGate(const AGateKey, AContextJson: string;
  out AResult: TShellGateResult): Boolean;
var
  LRoot: TJSONValue;
  LObj: TJSONObject;
  LRiskLevel: Integer;
  LCommandId: string;
  LMessage: string;
begin
  AResult := TShellGateResult.AllowedDefault;
  Result := True;

  if (FStatus = nil) or (AContextJson = '') then
    Exit;

  LRiskLevel := 0;
  LCommandId := '';
  LRoot := TJSONObject.ParseJSONValue(AContextJson);
  if (LRoot <> nil) and (LRoot is TJSONObject) then
  try
    LObj := TJSONObject(LRoot);
    LRiskLevel := LObj.GetValue<Integer>('risk_level', 0);
    LCommandId := LObj.GetValue<string>('command_id', '');
  finally
    LRoot.Free;
  end
  else if LRoot <> nil then
    LRoot.Free;

  if LRiskLevel < FMinRiskLevel then
    Exit;

  if LCommandId = '' then
    LMessage := Format('audit-only governance allowed gate %s (L%d)',
      [AGateKey, LRiskLevel])
  else
    LMessage := Format('audit-only governance allowed %s via gate %s (L%d)',
      [LCommandId, AGateKey, LRiskLevel]);
  FStatus.Diagnostic('shell.governance', LMessage);
end;

end.
