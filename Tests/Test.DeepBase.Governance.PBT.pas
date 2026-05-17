{ ============================================================================
  Test.DeepBase.Governance.PBT - Property tests for Round-2 governance fixes
  (deepbase-round2-fixes, sub-task 20.9).

  Properties covered:
    Property 33: Governance RouteResolver 无 Stale Fallback
                 After ReloadRules, FFallbacks must only contain entries
                 from the current rule set (GOV-019).
                 Validates: Requirements 13.1
    Property 34: Governance ActionGrid Noop Without Bridge
                 Running an Action with no registered bridge must produce
                 a noop / dry-run result, NOT arsSuccess (GOV-021).
                 Validates: Requirements 13.3
    Property 35: Governance ValidationEngine 缓存一致性
                 Cached Validate() output must equal a freshly computed
                 result. ResetCache must propagate underlying changes
                 (GOV-023).
                 Validates: Requirements 13.5

  Strategy:
    - DUnitX TestFixture, every property runs at least 100 iterations.
    - P33 uses a stub IRouteStore that returns a configurable rule list and
      drives ReloadRules through the public API; observation is via
      GetFallback (FFallbacks is private).
    - P34 uses a real TActionGrid with a stub IDueChecker. Each iteration
      registers a randomised action with zero bridge keys and asserts the
      result.Status is arsDryRun.
    - P35 uses a real TGateValidationEngine + TKeyResolver and calls
      Validate twice without changing the resolver; the second call must
      return the same array. Then it mutates the resolver and ResetCache,
      asserting the new Validate sees the change.
  ============================================================================ }

unit Test.DeepBase.Governance.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.RouteResolver,
  DeepBase.Governance.ActionGrid,
  DeepBase.Governance.Validation;

type
  [TestFixture]
  TGovernanceRound2PropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 33.
    [Test]
    procedure Property33_RouteResolver_NoStaleFallbackAfterReload;

    // Feature: deepbase-round2-fixes, Property 34.
    [Test]
    procedure Property34_ActionGrid_NoopWithoutBridge;

    // Feature: deepbase-round2-fixes, Property 35.
    [Test]
    procedure Property35_ValidationEngine_CacheConsistency;
  end;

implementation

{ ---------- Stubs ---------------------------------------------------------- }

type
  // Stub IRouteStore that returns a configurable owned-rule list.
  TStubRouteStore = class(TInterfacedObject, IRouteStore)
  private
    FRules: TList<TRouteRule>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearRules;
    procedure AddRule(const AId, ASource, ATargetKey, AFallback: string);
    function LoadBySource(const ASourceGateKey: string): TObjectList<TRouteRule>;
    function LoadAll: TObjectList<TRouteRule>;
  end;

  // Stub IDueChecker that always passes; we don't exercise due checks here.
  TStubDueChecker = class(TInterfacedObject, IDueChecker)
  public
    function Check(const AActionKey: string;
      AContext: TJSONObject): TDueResult;
    function GetReason(const AActionKey: string): string;
  end;

constructor TStubRouteStore.Create;
begin
  inherited;
  FRules := TList<TRouteRule>.Create;
end;

destructor TStubRouteStore.Destroy;
var
  LRule: TRouteRule;
begin
  for LRule in FRules do
    LRule.Free;
  FRules.Free;
  inherited;
end;

procedure TStubRouteStore.ClearRules;
var
  LRule: TRouteRule;
begin
  for LRule in FRules do
    LRule.Free;
  FRules.Clear;
end;

procedure TStubRouteStore.AddRule(const AId, ASource, ATargetKey,
  AFallback: string);
var
  LRule: TRouteRule;
begin
  // Trivial JsonLogic expression that always evaluates true: {"==":[1,1]}
  LRule := TRouteRule.Create(AId, ASource, '{"==":[1,1]}',
    rttAction, ATargetKey, 0);
  LRule.Enabled := True;
  LRule.FallbackTarget := AFallback;
  FRules.Add(LRule);
end;

function TStubRouteStore.LoadBySource(
  const ASourceGateKey: string): TObjectList<TRouteRule>;
var
  LRule: TRouteRule;
  LCopy: TRouteRule;
begin
  Result := TObjectList<TRouteRule>.Create(True);
  for LRule in FRules do
    if LRule.SourceGateKey = ASourceGateKey then
    begin
      LCopy := TRouteRule.Create(LRule.Id, LRule.SourceGateKey,
        LRule.ConditionExpr, LRule.TargetType, LRule.TargetKey, LRule.Priority);
      LCopy.Enabled := LRule.Enabled;
      LCopy.FallbackTarget := LRule.FallbackTarget;
      Result.Add(LCopy);
    end;
end;

function TStubRouteStore.LoadAll: TObjectList<TRouteRule>;
var
  LRule: TRouteRule;
  LCopy: TRouteRule;
begin
  // RouteResolver.ReloadRules takes ownership of the returned list (frees it
  // in a try/finally) so we must hand back a brand-new owning list every call.
  Result := TObjectList<TRouteRule>.Create(True);
  for LRule in FRules do
  begin
    LCopy := TRouteRule.Create(LRule.Id, LRule.SourceGateKey,
      LRule.ConditionExpr, LRule.TargetType, LRule.TargetKey, LRule.Priority);
    LCopy.Enabled := LRule.Enabled;
    LCopy.FallbackTarget := LRule.FallbackTarget;
    Result.Add(LCopy);
  end;
end;

function TStubDueChecker.Check(const AActionKey: string;
  AContext: TJSONObject): TDueResult;
begin
  Result := TDueResult.Pass;
end;

function TStubDueChecker.GetReason(const AActionKey: string): string;
begin
  Result := '';
end;

{ ---------- TGovernanceRound2PropertyTests -------------------------------- }

procedure TGovernanceRound2PropertyTests.Setup;
begin
  Randomize;
end;

// ---------------------------------------------------------------------------
// Property 33 - After ReloadRules, fallbacks from a previous load must not
// survive. We populate a stub store with a fallback for source S, do a
// reload (resolver picks it up), then mutate the store to a new rule set
// without S's fallback and reload again. Querying GetFallback(S) must
// return '' since FFallbacks should have been cleared.
// ---------------------------------------------------------------------------
procedure TGovernanceRound2PropertyTests.Property33_RouteResolver_NoStaleFallbackAfterReload;
const
  CIterations = 100;
var
  Iter: Integer;
  LStore: TStubRouteStore;
  LStoreIntf: IRouteStore;
  LResolver: TRouteResolver;
  LSource: string;
  LFb: string;
begin
  for Iter := 1 to CIterations do
  begin
    LStore := TStubRouteStore.Create;
    LStoreIntf := LStore;
    try
      LSource := 'gate.' + IntToStr(Iter);

      // First load: stale fallback present.
      LStore.AddRule('rule-' + IntToStr(Iter),
        LSource, 'action.target.A', 'action.fallback.A');

      LResolver := TRouteResolver.Create(LStoreIntf);
      try
        LFb := LResolver.GetFallback(LSource);
        Assert.AreEqual('action.fallback.A', LFb,
          Format('Iter %d: initial fallback must be the rule''s FallbackTarget',
            [Iter]));

        // Mutate store: drop the rule-with-fallback and replace it with a
        // rule that has no fallback. The reload MUST clear the previous
        // fallback entry.
        LStore.ClearRules;
        if Random(2) = 0 then
          LStore.AddRule('rule-2-' + IntToStr(Iter),
            LSource, 'action.target.B', '')
        else
          ; // intentionally empty - no rules at all for this source

        LResolver.ReloadRules;

        LFb := LResolver.GetFallback(LSource);
        Assert.AreEqual('', LFb,
          Format('Iter %d: stale fallback survived ReloadRules - GOV-019 broken; '
            + 'GetFallback returned %s', [Iter, LFb]));
      finally
        LResolver.Free;
      end;
    finally
      LStoreIntf := nil;
      // LStore is freed via the interface ref-count when LStoreIntf goes nil
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 34 - Action without registered bridge keys must yield arsDryRun.
// We register a random action key, do not register any bridge for it, and
// run with rmDryRun (a non-preview mode). The status must be arsDryRun.
// ---------------------------------------------------------------------------
procedure TGovernanceRound2PropertyTests.Property34_ActionGrid_NoopWithoutBridge;
const
  CIterations = 100;
var
  Iter: Integer;
  LGrid: TActionGrid;
  LDue: IDueChecker;
  LCtx: TJSONObject;
  LRes: TActionResult;
  LKey: string;
  LRisk: TRiskLevel;
  LMode: TRunMode;
begin
  LDue := TStubDueChecker.Create;
  for Iter := 1 to CIterations do
  begin
    LGrid := TActionGrid.Create(LDue);
    LCtx := TJSONObject.Create;
    try
      LKey := 'noop.action.' + IntToStr(Iter);
      LRisk := TRiskLevel(Random(Ord(High(TRiskLevel)) + 1));

      LGrid.RegisterAction(LKey, 'Noop ' + IntToStr(Iter), LRisk);
      // Intentionally NO RegisterBridge calls and the action's BridgeKeys
      // list stays empty.

      // Pick rmDryRun / rmCommit at random; rmPreview would short-circuit
      // before the bridge check so we exclude it. The TRunMode enum is
      // rmPreview, rmDryRun, rmCommit.
      if Random(2) = 0 then
        LMode := rmDryRun
      else
        LMode := rmCommit;

      // Must NOT raise.
      try
        LRes := LGrid.Run(LKey, LCtx, LMode);
      except
        on E: Exception do
          Assert.Fail(Format('Iter %d: ActionGrid.Run raised %s: %s',
            [Iter, E.ClassName, E.Message]));
      end;

      Assert.AreEqual(LKey, LRes.ActionKey,
        Format('Iter %d: ActionKey must round-trip', [Iter]));
      Assert.AreEqual(Ord(arsDryRun), Ord(LRes.Status),
        Format('Iter %d: action without bridge must yield arsDryRun (got %d). '
          + 'GOV-021 broken: arsSuccess hides the noop.',
          [Iter, Ord(LRes.Status)]));
    finally
      LCtx.Free;
      LGrid.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 35 - TGateValidationEngine.Validate must return identical content
// across consecutive calls (cache hit). After ResetCache, a new call must
// pick up changes to the underlying KeyResolver.
// ---------------------------------------------------------------------------
procedure TGovernanceRound2PropertyTests.Property35_ValidationEngine_CacheConsistency;
const
  CIterations = 100;

  function IssuesEqual(const A, B: TArray<TValidationIssue>): Boolean;
  var
    I: Integer;
  begin
    if Length(A) <> Length(B) then
      Exit(False);
    for I := 0 to High(A) do
    begin
      if A[I].RuleId <> B[I].RuleId then Exit(False);
      if A[I].Severity <> B[I].Severity then Exit(False);
      if A[I].TargetKey <> B[I].TargetKey then Exit(False);
      if A[I].Message <> B[I].Message then Exit(False);
    end;
    Result := True;
  end;

var
  Iter, I, LActions: Integer;
  LResolver: TKeyResolver;
  LEngine: TGateValidationEngine;
  LFirst, LSecond, LThird: TArray<TValidationIssue>;
  LKey: string;
begin
  for Iter := 1 to CIterations do
  begin
    LResolver := TKeyResolver.Create;
    LEngine := TGateValidationEngine.Create(LResolver);
    try
      // Register a random number of "naked" actions (no GateKey, no DueRef,
      // varying RiskLevel) so the validation rules produce a non-trivial
      // issue list.
      LActions := 1 + Random(6);
      for I := 1 to LActions do
      begin
        LKey := Format('act_%d_%d', [Iter, I]);
        LResolver.RegisterAction(
          TAction.Create(LKey, 'Naked Action ' + IntToStr(I),
            TRiskLevel(Random(Ord(High(TRiskLevel)) + 1))));
      end;

      // First call: cold cache.
      LFirst := LEngine.Validate;
      // Second call: must hit cache and return the SAME content.
      LSecond := LEngine.Validate;

      Assert.IsTrue(IssuesEqual(LFirst, LSecond),
        Format('Iter %d: cached Validate() must match first call. '
          + 'First=%d issues, Second=%d issues. GOV-023 broken.',
          [Iter, Length(LFirst), Length(LSecond)]));

      // Mutate resolver and reset cache; the new result must reflect the
      // change. Use a high-risk action with no DueRef so INV-2 fires for
      // sure on top of INV-1, growing the issue list.
      LResolver.RegisterAction(
        TAction.Create(Format('extra_%d', [Iter]), 'Extra L3', rlL3));

      LEngine.ResetCache;
      LThird := LEngine.Validate;

      Assert.IsTrue(Length(LThird) > Length(LFirst),
        Format('Iter %d: after ResetCache + new high-risk action, issue '
          + 'count must grow (was %d, now %d).',
          [Iter, Length(LFirst), Length(LThird)]));
    finally
      LEngine.Free;
      LResolver.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGovernanceRound2PropertyTests);

end.
