// AI-GENERATED
unit Test.DeepBase.Governance.Validation.SkeletonRules;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Governance.Types,
  DeepBase.Governance.Model,
  DeepBase.Governance.KeyResolver,
  DeepBase.Governance.Validation;

type
  [TestFixture]
  TSkeletonRuleTests = class
  private
    FKeyResolver: TKeyResolver;
    FEngine: TGateValidationEngine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>
    /// REVIEW5-GOV-004: Verify that skeleton rules (INV-8..INV-15) are NOT registered.
    /// Empty rules should not participate in release gate judgment.
    /// </summary>
    [Test]
    procedure SkeletonRules_AreNotRegistered;
    [Test]
    procedure OnlyP0Rules_AreActive;
    [Test]
    procedure CanRelease_WorksWithOnlyP0Rules;
  end;

implementation

{ TSkeletonRuleTests }

procedure TSkeletonRuleTests.Setup;
begin
  FKeyResolver := TKeyResolver.Create;
  FEngine := TGateValidationEngine.Create(FKeyResolver);
end;

procedure TSkeletonRuleTests.TearDown;
begin
  FEngine.Free;
  FKeyResolver.Free;
end;

procedure TSkeletonRuleTests.SkeletonRules_AreNotRegistered;
var
  LIssues: TArray<TValidationIssue>;
  LIssue: TValidationIssue;
  LHasSkeletonRule: Boolean;
begin
  // Add a simple action to trigger validation
  FKeyResolver.RegisterAction(TAction.Create('test_action', 'Test', rlL0, '', '', ''));

  LIssues := FEngine.Validate;
  LHasSkeletonRule := False;

  for LIssue in LIssues do
  begin
    // INV-8 through INV-15 should NOT appear in validation results
    if LIssue.RuleId.StartsWith('INV-') then
    begin
      if (LIssue.RuleId = 'INV-8') or (LIssue.RuleId = 'INV-9') or
         (LIssue.RuleId = 'INV-10') or (LIssue.RuleId = 'INV-11') or
         (LIssue.RuleId = 'INV-12') or (LIssue.RuleId = 'INV-13') or
         (LIssue.RuleId = 'INV-14') or (LIssue.RuleId = 'INV-15') then
      begin
        LHasSkeletonRule := True;
        Break;
      end;
    end;
  end;

  Assert.IsFalse(LHasSkeletonRule,
    'Skeleton rules (INV-8..INV-15) should not be registered in validation engine');
end;

procedure TSkeletonRuleTests.OnlyP0Rules_AreActive;
var
  LIssues: TArray<TValidationIssue>;
  LIssue: TValidationIssue;
  LP0RuleCount: Integer;
  LSkeletonRuleCount: Integer;
begin
  // Add a naked action to trigger INV-1 (P0 rule)
  FKeyResolver.RegisterAction(TAction.Create('naked_action', 'Naked', rlL1, '', '', ''));

  LIssues := FEngine.Validate;
  LP0RuleCount := 0;
  LSkeletonRuleCount := 0;

  for LIssue in LIssues do
  begin
    if LIssue.RuleId.StartsWith('INV-') then
    begin
      if (LIssue.RuleId >= 'INV-1') and (LIssue.RuleId <= 'INV-7') then
        Inc(LP0RuleCount)
      else if (LIssue.RuleId >= 'INV-8') and (LIssue.RuleId <= 'INV-15') then
        Inc(LSkeletonRuleCount);
    end;
  end;

  // Should have P0 rules active
  Assert.IsTrue(LP0RuleCount > 0, 'P0 rules (INV-1..INV-7) should be active');

  // Should NOT have skeleton rules active
  Assert.AreEqual(0, LSkeletonRuleCount,
    'Skeleton rules (INV-8..INV-15) should not produce any issues');
end;

procedure TSkeletonRuleTests.CanRelease_WorksWithOnlyP0Rules;
var
  LAction: TAction;
begin
  // Add a valid action (with DueRef and GateKey)
  LAction := TAction.Create('valid_action', 'Valid', rlL2, 'valid_gate', 'due_ref', 'purpose');
  FKeyResolver.RegisterAction(LAction);

  // Add a valid gate
  FKeyResolver.RegisterGate(TAccessGate.Create('valid_gate', 'Valid Gate', gtAction, '', ''));

  // CanRelease should work with only P0 rules
  // Since we have a valid action with all required fields, it should pass
  Assert.IsTrue(FEngine.CanRelease,
    'CanRelease should work correctly with only P0 rules registered');
end;

end.
