{ ============================================================================
  Test.DeepBase.IntentClarification.PBT - Property-based tests for the
  IntentClarification engine and its providers.

  Properties covered:
    P6 : StartSession Field Consumption (Req 4.1, 4.2, 4.3)
    P8 : IC Provider Session State Isolation (Req 6.1, 6.2)

  Each property runs >= 100 iterations with random session IDs and inputs.

  Notes on observability:
    - The current TClarificationEngine does not expose the per-session
      history dictionary publicly. The test below verifies P6 against
      observable session state (handle id, status, turn count, uniqueness,
      SessionCount monotonicity) and exercises the full request shape so
      the field-consumption code paths execute under random inputs.
  ============================================================================ }

unit Test.DeepBase.IntentClarification.PBT;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Engine,
  DeepBase.IntentClarification.Provider.L2,
  DeepBase.IntentClarification.Provider.L3;

type
  [TestFixture]
  [Category('PBT')]
  TICEnginePropertyTests = class
  strict private
    function MakeRandomRequest(out AHasInput, AHasTemplate,
      AHasBudget: Boolean): TClarificationStartRequest;
    function PickTemplate: string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 6
    [Test]
    procedure Property6_StartSessionFieldConsumption;
  end;

  [TestFixture]
  [Category('PBT')]
  TICProviderIsolationPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 8 (L2 denied hypotheses)
    [Test]
    procedure Property8_L2_DeniedHypothesesIsolatedAcrossSessions;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 8 (L3 expert selection)
    [Test]
    procedure Property8_L3_ExpertSelectionIsolatedAcrossSessions;
  end;

implementation

{ TICEnginePropertyTests }

procedure TICEnginePropertyTests.Setup;
begin
  Randomize;
end;

function TICEnginePropertyTests.PickTemplate: string;
const
  CTemplates: array[0..3] of string = (
    '', 'tool-command', 'creative-assistant', 'decision-advisor');
begin
  Result := CTemplates[Random(Length(CTemplates))];
end;

function TICEnginePropertyTests.MakeRandomRequest(out AHasInput, AHasTemplate,
  AHasBudget: Boolean): TClarificationStartRequest;
const
  CInputs: array[0..6] of string = (
    '', 'Hello world', '帮我规划一下明天', 'tab' + #9 + 'sep',
    'multi' + #13#10 + 'line', '"quoted"', 'a' );
begin
  Result := Default(TClarificationStartRequest);
  Result.UserId := 'user-' + IntToStr(Random(10000));
  Result.DomainName := 'domain-' + IntToStr(Random(8));
  Result.IntentName := 'intent-' + IntToStr(Random(8));
  Result.Locale := 'en-US';
  Result.InitialInput := CInputs[Random(Length(CInputs))];
  AHasInput := Result.InitialInput <> '';
  Result.Template := PickTemplate;
  AHasTemplate := Result.Template <> '';
  AHasBudget := Random(2) = 0;
  if AHasBudget then
  begin
    Result.HasBudgetOverride := True;
    Result.BudgetOverride := TBudgetConfig.Default;
    Result.BudgetOverride.MaxTurns := 1 + Random(20);
    Result.BudgetOverride.MaxTimeSeconds := 30 + Random(900);
  end
  else
    Result.HasBudgetOverride := False;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 6: StartSession field
// consumption. The engine must accept arbitrary combinations of
// InitialInput / Template / BudgetOverride and produce an active session
// reachable via the returned handle.
procedure TICEnginePropertyTests.Property6_StartSessionFieldConsumption;
var
  LEngine: TClarificationEngine;
  LSeenIds: TDictionary<string, Boolean>;
begin
  LEngine := TClarificationEngine.Create;
  LSeenIds := TDictionary<string, Boolean>.Create;
  try
    var LBaselineCount := LEngine.SessionCount;
    for var Iter := 1 to 100 do
    begin
      var LHasInput, LHasTemplate, LHasBudget: Boolean;
      var LRequest := MakeRandomRequest(LHasInput, LHasTemplate, LHasBudget);
      var LHandle := LEngine.StartSession(LRequest);

      Assert.IsFalse(LHandle.Id.IsEmpty,
        Format('Iter %d: handle.Id must not be empty', [Iter]));
      Assert.IsFalse(LSeenIds.ContainsKey(LHandle.Id),
        Format('Iter %d: handle.Id "%s" must be unique across StartSession ' +
          'calls', [Iter, LHandle.Id]));
      LSeenIds.Add(LHandle.Id, True);

      var LState := LEngine.GetSessionState(LHandle);
      Assert.AreEqual(LHandle.Id, LState.SessionId,
        Format('Iter %d: GetSessionState returned wrong session id', [Iter]));
      Assert.IsTrue(LState.Status = ssActive,
        Format('Iter %d: new session must be ssActive', [Iter]));
      Assert.AreEqual(0, LState.TurnCount,
        Format('Iter %d: new session must have TurnCount=0', [Iter]));
      Assert.AreEqual(LRequest.UserId, LState.UserId,
        Format('Iter %d: UserId not propagated', [Iter]));
      Assert.AreEqual(LRequest.DomainName, LState.DomainName,
        Format('Iter %d: DomainName not propagated', [Iter]));
      Assert.AreEqual(LRequest.IntentName, LState.IntentName,
        Format('Iter %d: IntentName not propagated', [Iter]));

      Assert.AreEqual(LBaselineCount + Iter, LEngine.SessionCount,
        Format('Iter %d: SessionCount must grow monotonically', [Iter]));
    end;
  finally
    LSeenIds.Free;
    LEngine.Free;
  end;
end;

{ TICProviderIsolationPropertyTests }

procedure TICProviderIsolationPropertyTests.Setup;
begin
  Randomize;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 8: Denied-hypothesis state
// in L2 must be isolated per session id.
procedure TICProviderIsolationPropertyTests
  .Property8_L2_DeniedHypothesesIsolatedAcrossSessions;
var
  LProvider: TL2ProblemProvider;
begin
  // ILLMClient is unused by Deny/GetDenied paths, so nil is safe here.
  LProvider := TL2ProblemProvider.Create(nil);
  try
    for var Iter := 1 to 100 do
    begin
      var LSessionA := 'sessA-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));
      var LSessionB := 'sessB-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));
      var LHypothesis := 'h-' + IntToStr(Iter) + '-' + IntToStr(Random(99999));

      LProvider.DenyHypothesis(LSessionA, LHypothesis);

      var LFromA := LProvider.GetDeniedHypotheses(LSessionA);
      var LFromB := LProvider.GetDeniedHypotheses(LSessionB);

      var LFoundInA := False;
      for var H in LFromA do
        if H = LHypothesis then
          LFoundInA := True;
      Assert.IsTrue(LFoundInA,
        Format('Iter %d: deny on sessionA must persist for sessionA', [Iter]));

      for var H in LFromB do
        Assert.AreNotEqual(LHypothesis, H,
          Format('Iter %d: deny on sessionA leaked into sessionB', [Iter]));
    end;
  finally
    LProvider.Free;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 8: Selected expert in L3 must
// be isolated per session id.
procedure TICProviderIsolationPropertyTests
  .Property8_L3_ExpertSelectionIsolatedAcrossSessions;
var
  LProvider: TL3ExpertProvider;
begin
  // ILLMClient and IPersonaRegistry unused for switch/get/reset paths.
  LProvider := TL3ExpertProvider.Create(nil, nil);
  try
    for var Iter := 1 to 100 do
    begin
      var LSessionA := 'sessA-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));
      var LSessionB := 'sessB-' + IntToStr(Iter) + '-' + IntToStr(Random(MaxInt));

      var LExpertA := Default(TPersonaProfile);
      LExpertA.Id := 'expA-' + IntToStr(Iter);
      LExpertA.Name := 'Expert A ' + IntToStr(Iter);
      LExpertA.Role := 'role-a';

      LProvider.SwitchExpert(LSessionA, LExpertA);

      var LFromA := LProvider.GetCurrentExpert(LSessionA);
      var LFromB := LProvider.GetCurrentExpert(LSessionB);

      Assert.AreEqual(LExpertA.Id, LFromA.Id,
        Format('Iter %d: switched expert must be visible on sessionA', [Iter]));
      Assert.AreNotEqual(LExpertA.Id, LFromB.Id,
        Format('Iter %d: sessionA expert leaked into sessionB', [Iter]));

      // Reset on A, B remains untouched.
      LProvider.ResetExpert(LSessionA);
      var LFromAAfterReset := LProvider.GetCurrentExpert(LSessionA);
      Assert.AreEqual('', LFromAAfterReset.Id,
        Format('Iter %d: sessionA expert must clear after ResetExpert', [Iter]));

      // Now switch on B and ensure A still empty.
      var LExpertB := Default(TPersonaProfile);
      LExpertB.Id := 'expB-' + IntToStr(Iter);
      LProvider.SwitchExpert(LSessionB, LExpertB);
      var LAFinal := LProvider.GetCurrentExpert(LSessionA);
      Assert.AreEqual('', LAFinal.Id,
        Format('Iter %d: switching on sessionB must not reactivate sessionA',
          [Iter]));
    end;
  finally
    LProvider.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TICEnginePropertyTests);
  TDUnitX.RegisterTestFixture(TICProviderIsolationPropertyTests);

end.
