{ ============================================================================
  DeepBase.Governance.JsonLogicEvaluator
  ---------------------------------------------------------------------------
  Wires the existing TJsonLogicEngine into the gate-condition evaluator
  contract. One-line opt-in API for downstream projects:

      EnableJsonLogicEvaluators;

  Once called, every TGateCondition whose Expression is a JsonLogic
  expression (e.g. `{"==":[{"var":"user.has_pay"}, true]}`) will be
  evaluated against the context JSON passed to EnterGate / Resolve.

  The engine is owned by this unit and freed on finalisation. Evaluators
  take closure refs so they stay valid for the lifetime of the GateResolver.

  Thread-safety: TJsonLogicEngine uses an internal managed-objects list
  that is cleared on every top-level ApplyStr call, so concurrent calls
  from multiple threads are unsafe. This matches the rest of the governance
  stack, which is single-threaded by convention (UI/main thread).
  ============================================================================ }

unit DeepBase.Governance.JsonLogicEvaluator;

interface

uses
  DeepBase.Governance.Types,
  DeepBase.Governance.GateResolver;

/// <summary>
/// Installs a JsonLogic-backed evaluator for every TGateConditionKind on
/// the given resolver. The evaluator pulls the condition's Expression
/// string, applies it to the request context, and returns the boolean
/// result. Safe to call multiple times — later installs overwrite.
/// </summary>
procedure InstallJsonLogicEvaluators(AResolver: TGateResolver);

/// <summary>
/// Convenience wrapper that installs on GovernanceLifecycle.GateResolver.
/// Requires GovernanceLifecycle to be non-nil (call after RegisterGovernance).
/// </summary>
procedure EnableJsonLogicEvaluators;

implementation

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Governance.Model,
  DeepBase.Governance.JsonLogic,
  DeepBase.Governance.Lifecycle;

var
  GEngine: TJsonLogicEngine = nil;

function GetEngine: TJsonLogicEngine;
begin
  if GEngine = nil then
    GEngine := TJsonLogicEngine.Create;
  Result := GEngine;
end;

procedure InstallJsonLogicEvaluators(AResolver: TGateResolver);
var
  LKind: TGateConditionKind;
  LEngine: TJsonLogicEngine;
begin
  if AResolver = nil then
    Exit;
  LEngine := GetEngine;

  for LKind := Low(TGateConditionKind) to High(TGateConditionKind) do
    AResolver.RegisterEvaluator(LKind,
      function(ACondition: TGateCondition; AContext: TJSONObject): Boolean
      begin
        // Empty expression means "no constraint expressed" — fail-closed
        // to mirror the default TGateResolver semantics when no evaluator
        // is registered. A condition with no expression can't meaningfully
        // be "satisfied" so we treat it as false.
        if (ACondition = nil) or (ACondition.Expression = '') then
          Exit(False);

        try
          Result := LEngine.ApplyStr(ACondition.Expression, AContext);
        except
          on E: Exception do
            // Invalid JsonLogic or runtime error → fail-closed.
            // Production should have validated expressions at registration
            // time, so this path is for defence only.
            Result := False;
        end;
      end);
end;

procedure EnableJsonLogicEvaluators;
begin
  if (GovernanceLifecycle = nil) or (GovernanceLifecycle.GateResolver = nil) then
    raise Exception.Create(
      'EnableJsonLogicEvaluators called before RegisterGovernance');
  InstallJsonLogicEvaluators(GovernanceLifecycle.GateResolver);
end;

initialization

finalization
  FreeAndNil(GEngine);

end.
