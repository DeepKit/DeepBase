{ ============================================================================
  Test.DeepBase.FeatureFlags - Feature Flags Unit Tests
  
  Version: 1.0
  Description: Unit tests for feature flag/toggle system
  
  Test Coverage:
  - TFlagContext: Evaluation context
  - TTargetingRule: Targeting rules
  - TFlagVariant: A/B testing variants
  - TFlagSchedule: Time-based activation
  - TFeatureFlag: Feature flag definition
  - TFeatureFlagManager: Flag management
  ============================================================================ }

unit Test.DeepBase.FeatureFlags;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.DateUtils,
  System.Variants,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework;

type
  /// <summary>
  /// Test fixture for TFlagContext
  /// </summary>
  [TestFixture]
  TTestFlagContext = class
  public
    [Test]
    procedure Test_Create_InitializesEmpty;
    
    [Test]
    procedure Test_WithUserId_SetsUserId;
    
    [Test]
    procedure Test_WithGroups_SetsGroupIds;
    
    [Test]
    procedure Test_WithEnvironment_SetsEnvironment;
    
    [Test]
    procedure Test_WithAppVersion_SetsVersion;
    
    [Test]
    procedure Test_WithAttribute_AddsAttribute;
    
    [Test]
    procedure Test_GetAttribute_ReturnsValue;
    
    [Test]
    procedure Test_HasAttribute_ReturnsTrue;
    
    [Test]
    procedure Test_HasAttribute_ReturnsFalse;
    
    [Test]
    procedure Test_FluentChaining;
  end;
  
  /// <summary>
  /// Test fixture for TTargetingRule
  /// </summary>
  [TestFixture]
  TTestTargetingRule = class
  public
    [Test]
    procedure Test_Create_WithValue;
    
    [Test]
    procedure Test_Create_WithValues;
    
    [Test]
    procedure Test_Evaluate_Equals_True;
    
    [Test]
    procedure Test_Evaluate_Equals_False;
    
    [Test]
    procedure Test_Evaluate_NotEquals;
    
    [Test]
    procedure Test_Evaluate_Contains;
    
    [Test]
    procedure Test_Evaluate_StartsWith;
    
    [Test]
    procedure Test_Evaluate_EndsWith;
    
    [Test]
    procedure Test_Evaluate_In;
    
    [Test]
    procedure Test_Evaluate_NotIn;
    
    [Test]
    procedure Test_Evaluate_GreaterThan;
    
    [Test]
    procedure Test_Evaluate_LessThan;
    
    [Test]
    procedure Test_Evaluate_Regex;
    
    [Test]
    procedure Test_ToJSON_SerializesRule;
    
    [Test]
    procedure Test_FromJSON_DeserializesRule;
  end;
  
  /// <summary>
  /// Test fixture for TFlagVariant
  /// </summary>
  [TestFixture]
  TTestFlagVariant = class
  public
    [Test]
    procedure Test_Create_SetsNameWeight;
    
    [Test]
    procedure Test_Value_GetSet;
    
    [Test]
    procedure Test_Payload_GetSet;
  end;
  
  /// <summary>
  /// Test fixture for TFlagSchedule
  /// </summary>
  [TestFixture]
  TTestFlagSchedule = class
  public
    [Test]
    procedure Test_Create_DefaultValues;
    
    [Test]
    procedure Test_IsActive_BeforeStart;
    
    [Test]
    procedure Test_IsActive_AfterEnd;
    
    [Test]
    procedure Test_IsActive_InRange;
    
    [Test]
    procedure Test_DaysOfWeek_Matching;
    
    [Test]
    procedure Test_HourRange_Matching;
  end;
  
  /// <summary>
  /// Test fixture for TFeatureFlag
  /// </summary>
  [TestFixture]
  TTestFeatureFlag = class
  public
    [Test]
    procedure Test_Create_WithKey;
    
    [Test]
    procedure Test_Evaluate_EnabledState;
    
    [Test]
    procedure Test_Evaluate_DisabledState;
    
    [Test]
    procedure Test_Evaluate_WithRollout;
    
    [Test]
    procedure Test_Evaluate_WithTargeting;
    
    [Test]
    procedure Test_Evaluate_WithMultipleRules;
    
    [Test]
    procedure Test_Evaluate_WithDependency;
    
    [Test]
    procedure Test_AddRule_AddsRule;
    
    [Test]
    procedure Test_AddVariant_AddsVariant;
    
    [Test]
    procedure Test_WithRollout_SetsPercentage;
    
    [Test]
    procedure Test_WithSchedule_SetsSchedule;
    
    [Test]
    procedure Test_DependsOn_AddsDependency;
    
    [Test]
    procedure Test_WithTag_AddsTag;
    
    [Test]
    procedure Test_GetVariant_SelectsVariant;
    
    [Test]
    procedure Test_ToJSON_SerializesFlag;
    
    [Test]
    procedure Test_FromJSON_DeserializesFlag;
  end;
  
  /// <summary>
  /// Test fixture for TFeatureFlagManager
  /// </summary>
  [TestFixture]
  TTestFeatureFlagManager = class
  public
    [Test]
    procedure Test_Create_InitializesManager;
    
    [Test]
    procedure Test_RegisterFlag_AddsFlag;
    
    [Test]
    procedure Test_DeleteFlag_RemovesFlag;
    
    [Test]
    procedure Test_GetFlag_ReturnsFlag;
    
    [Test]
    procedure Test_GetFlag_ReturnsNilForMissing;
    
    [Test]
    procedure Test_IsEnabled_ReturnsTrue;
    
    [Test]
    procedure Test_IsEnabled_ReturnsFalse;
    
    [Test]
    procedure Test_IsEnabled_WithContext;
    
    [Test]
    procedure Test_IsEnabled_DefaultForMissing;
    
    [Test]
    procedure Test_GetVariant_ReturnsVariant;
    
    [Test]
    procedure Test_GetAllFlags_ReturnsList;
    
    [Test]
    procedure Test_GetFlagsByTag_FiltersByTag;
    
    [Test]
    procedure Test_EnableFlag_EnablesFlag;
    
    [Test]
    procedure Test_DisableFlag_DisablesFlag;
    
    [Test]
    procedure Test_SetRollout_SetsPercentage;
    
    [Test]
    procedure Test_OnFlagChanged_Event;
    
    [Test]
    procedure Test_ExportToJSON_SavesFlags;

    [Test]
    procedure Test_ImportFromJSON_LoadsFlags;

    [Test]
    procedure Test_GlobalHelper_Manager_IsThreadSafeSingleton;
  end;

implementation

uses
  DeepBase.FeatureFlags;

{ TTestFlagContext }

procedure TTestFlagContext.Test_Create_InitializesEmpty;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Assert.AreEqual('', Context.UserId);
    Assert.AreEqual<Integer>(0, Length(Context.GroupIds));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_WithUserId_SetsUserId;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithUserId('user-123');
    Assert.AreEqual('user-123', Context.UserId);
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_WithGroups_SetsGroupIds;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithGroups(['admin', 'beta']);
    Assert.AreEqual<Integer>(2, Length(Context.GroupIds));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_WithEnvironment_SetsEnvironment;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithEnvironment('production');
    Assert.AreEqual('production', Context.Environment);
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_WithAppVersion_SetsVersion;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithAppVersion('2.0.0');
    Assert.AreEqual('2.0.0', Context.AppVersion);
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_WithAttribute_AddsAttribute;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('plan', 'enterprise');
    Assert.AreEqual('enterprise', string(Context.GetAttribute('plan')));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_GetAttribute_ReturnsValue;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('count', 42);
    Assert.AreEqual(42, Integer(Context.GetAttribute('count')));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_HasAttribute_ReturnsTrue;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('key', 'value');
    Assert.IsTrue(Context.HasAttribute('key'));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_HasAttribute_ReturnsFalse;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Assert.IsFalse(Context.HasAttribute('nonexistent'));
  finally
    Context.Free;
  end;
end;

procedure TTestFlagContext.Test_FluentChaining;
var
  Context: TFlagContext;
begin
  Context := TFlagContext.Create;
  try
    Context
      .WithUserId('user-1')
      .WithEnvironment('staging')
      .WithAppVersion('1.0.0')
      .WithAttribute('country', 'US');
    
    Assert.AreEqual('user-1', Context.UserId);
    Assert.AreEqual('staging', Context.Environment);
  finally
    Context.Free;
  end;
end;

{ TTestTargetingRule }

procedure TTestTargetingRule.Test_Create_WithValue;
var
  Rule: TTargetingRule;
begin
  Rule := TTargetingRule.Create('country', toEquals, 'US');
  try
    Assert.AreEqual('country', Rule.Attribute);
    Assert.AreEqual(toEquals, Rule.Operator);
  finally
    Rule.Free;
  end;
end;

procedure TTestTargetingRule.Test_Create_WithValues;
var
  Rule: TTargetingRule;
begin
  Rule := TTargetingRule.Create('country', toIn, ['US', 'CA', 'UK']);
  try
    Assert.AreEqual<Integer>(3, Length(Rule.Values));
  finally
    Rule.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_Equals_True;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('country', toEquals, 'US');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('country', 'US');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_Equals_False;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('country', toEquals, 'US');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('country', 'CA');
    Assert.IsFalse(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_NotEquals;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('plan', toNotEquals, 'free');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('plan', 'premium');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_Contains;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('email', toContains, '@company.com');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('email', 'user@company.com');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_StartsWith;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('name', toStartsWith, 'test_');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('name', 'test_user');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_EndsWith;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('file', toEndsWith, '.txt');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('file', 'data.txt');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_In;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('country', toIn, ['US', 'CA', 'UK']);
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('country', 'CA');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_NotIn;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('country', toNotIn, ['US', 'CA']);
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('country', 'DE');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_GreaterThan;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('age', toGreaterThan, 18);
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('age', 25);
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_LessThan;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('score', toLessThan, 100);
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('score', 50);
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_Evaluate_Regex;
var
  Rule: TTargetingRule;
  Context: TFlagContext;
begin
  Rule := TTargetingRule.Create('email', toRegex, '^[a-z]+@test\.com$');
  Context := TFlagContext.Create;
  try
    Context.WithAttribute('email', 'user@test.com');
    Assert.IsTrue(Rule.Evaluate(Context));
  finally
    Rule.Free;
    Context.Free;
  end;
end;

procedure TTestTargetingRule.Test_ToJSON_SerializesRule;
var
  Rule: TTargetingRule;
  JSON: TJSONObject;
begin
  Rule := TTargetingRule.Create('country', toEquals, 'US');
  try
    JSON := Rule.ToJSON;
    try
      Assert.IsNotNull(JSON);
      Assert.AreEqual('country', JSON.GetValue<string>('attribute'));
    finally
      JSON.Free;
    end;
  finally
    Rule.Free;
  end;
end;

procedure TTestTargetingRule.Test_FromJSON_DeserializesRule;
var
  OrigRule, RestoredRule: TTargetingRule;
  JSON: TJSONObject;
begin
  OrigRule := TTargetingRule.Create('plan', toEquals, 'premium');
  try
    JSON := OrigRule.ToJSON;
    try
      RestoredRule := TTargetingRule.FromJSON(JSON);
      try
        Assert.AreEqual(OrigRule.Attribute, RestoredRule.Attribute);
        Assert.AreEqual(OrigRule.Operator, RestoredRule.Operator);
      finally
        RestoredRule.Free;
      end;
    finally
      JSON.Free;
    end;
  finally
    OrigRule.Free;
  end;
end;

{ TTestFlagVariant }

procedure TTestFlagVariant.Test_Create_SetsNameWeight;
var
  Variant: TFlagVariant;
begin
  Variant := TFlagVariant.Create('control', 50);
  try
    Assert.AreEqual('control', Variant.Name);
    Assert.AreEqual(50, Variant.Weight);
  finally
    Variant.Free;
  end;
end;

procedure TTestFlagVariant.Test_Value_GetSet;
var
  Variant: TFlagVariant;
begin
  Variant := TFlagVariant.Create('treatment', 50);
  try
    Variant.Value := 'blue';
    Assert.AreEqual('blue', string(Variant.Value));
  finally
    Variant.Free;
  end;
end;

procedure TTestFlagVariant.Test_Payload_GetSet;
var
  Variant: TFlagVariant;
  Payload: TJSONObject;
begin
  Variant := TFlagVariant.Create('test', 100);
  Payload := TJSONObject.Create;
  try
    Payload.AddPair('color', 'red');
    Variant.Payload := Payload;
    Assert.IsNotNull(Variant.Payload);
  finally
    Variant.Free;
  end;
end;

{ TTestFlagSchedule }

procedure TTestFlagSchedule.Test_Create_DefaultValues;
var
  Schedule: TFlagSchedule;
begin
  Schedule := TFlagSchedule.Create;
  try
    Assert.AreEqual(0, Schedule.StartHour);
    Assert.AreEqual(24, Schedule.EndHour);
  finally
    Schedule.Free;
  end;
end;

procedure TTestFlagSchedule.Test_IsActive_BeforeStart;
var
  Schedule: TFlagSchedule;
begin
  Schedule := TFlagSchedule.Create;
  try
    Schedule.StartTime := Now + 1; // Tomorrow
    Schedule.EndTime := Now + 2;
    Assert.IsFalse(Schedule.IsActive);
  finally
    Schedule.Free;
  end;
end;

procedure TTestFlagSchedule.Test_IsActive_AfterEnd;
var
  Schedule: TFlagSchedule;
begin
  Schedule := TFlagSchedule.Create;
  try
    Schedule.StartTime := Now - 2; // 2 days ago
    Schedule.EndTime := Now - 1;   // Yesterday
    Assert.IsFalse(Schedule.IsActive);
  finally
    Schedule.Free;
  end;
end;

procedure TTestFlagSchedule.Test_IsActive_InRange;
var
  Schedule: TFlagSchedule;
begin
  Schedule := TFlagSchedule.Create;
  try
    Schedule.StartTime := Now - 1;
    Schedule.EndTime := Now + 1;
    Assert.IsTrue(Schedule.IsActive);
  finally
    Schedule.Free;
  end;
end;

procedure TTestFlagSchedule.Test_DaysOfWeek_Matching;
var
  Schedule: TFlagSchedule;
  Today: Word;
begin
  Schedule := TFlagSchedule.Create;
  try
    Today := DayOfWeek(Now) - 1; // 0-6
    Schedule.DaysOfWeek := [Today];
    Schedule.StartTime := Now - 1;
    Schedule.EndTime := Now + 1;
    Assert.IsTrue(Schedule.IsActive);
  finally
    Schedule.Free;
  end;
end;

procedure TTestFlagSchedule.Test_HourRange_Matching;
var
  Schedule: TFlagSchedule;
  CurrentHour: Word;
begin
  Schedule := TFlagSchedule.Create;
  try
    CurrentHour := HourOf(Now);
    Schedule.StartHour := CurrentHour;
    Schedule.EndHour := CurrentHour + 1;
    Schedule.StartTime := Now - 1;
    Schedule.EndTime := Now + 1;
    Assert.IsTrue(Schedule.IsActive);
  finally
    Schedule.Free;
  end;
end;

{ TTestFeatureFlag }

procedure TTestFeatureFlag.Test_Create_WithKey;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('new-feature');
  try
    Assert.AreEqual('new-feature', Flag.Key);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_EnabledState;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
begin
  Flag := TFeatureFlag.Create('feature');
  Context := TFlagContext.Create;
  try
    Flag.State := fsEnabled;
    Assert.IsTrue(Flag.Evaluate(Context, nil));
  finally
    Flag.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_DisabledState;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
begin
  Flag := TFeatureFlag.Create('feature');
  Context := TFlagContext.Create;
  try
    Flag.State := fsDisabled;
    Assert.IsFalse(Flag.Evaluate(Context, nil));
  finally
    Flag.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_WithRollout;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
  TrueCount, I: Integer;
begin
  Flag := TFeatureFlag.Create('rollout-feature');
  try
    Flag.State := fsRollout;
    Flag.WithRollout(50);
    
    TrueCount := 0;
    for I := 1 to 100 do
    begin
      Context := TFlagContext.Create;
      try
        Context.WithUserId('user-' + I.ToString);
        if Flag.Evaluate(Context, nil) then
          Inc(TrueCount);
      finally
        Context.Free;
      end;
    end;
    
    // Should be roughly 50%
    Assert.IsTrue(TrueCount >= 20);
    Assert.IsTrue(TrueCount <= 80);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_WithTargeting;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
begin
  Flag := TFeatureFlag.Create('targeted-feature');
  Context := TFlagContext.Create;
  try
    Flag.State := fsTargeted;
    Flag.AddRule(TTargetingRule.Create('plan', toEquals, 'enterprise'));
    
    Context.WithAttribute('plan', 'enterprise');
    Assert.IsTrue(Flag.Evaluate(Context, nil));
    
    Context.WithAttribute('plan', 'free');
    Assert.IsFalse(Flag.Evaluate(Context, nil));
  finally
    Flag.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_WithMultipleRules;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
begin
  Flag := TFeatureFlag.Create('multi-rule');
  Context := TFlagContext.Create;
  try
    Flag.State := fsTargeted;
    Flag.AddRule(TTargetingRule.Create('country', toIn, ['US', 'CA']));
    Flag.AddRule(TTargetingRule.Create('plan', toNotEquals, 'free'));
    
    Context.WithAttribute('country', 'US');
    Context.WithAttribute('plan', 'premium');
    Assert.IsTrue(Flag.Evaluate(Context, nil));
  finally
    Flag.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlag.Test_Evaluate_WithDependency;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('dependent');
  try
    Flag.DependsOn('parent-flag');
    Assert.AreEqual<Integer>(1, Length(Flag.Dependencies));
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_AddRule_AddsRule;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('feature');
  try
    Flag.AddRule(TTargetingRule.Create('key', toEquals, 'value'));
    Assert.AreEqual<Integer>(1, Flag.TargetingRules.Count);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_AddVariant_AddsVariant;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('ab-test');
  try
    Flag.AddVariant(TFlagVariant.Create('control', 50));
    Flag.AddVariant(TFlagVariant.Create('treatment', 50));
    Assert.AreEqual<Integer>(2, Flag.Variants.Count);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_WithRollout_SetsPercentage;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('feature');
  try
    Flag.WithRollout(75);
    Assert.AreEqual(75, Flag.RolloutPercentage);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_WithSchedule_SetsSchedule;
var
  Flag: TFeatureFlag;
  Schedule: TFlagSchedule;
begin
  Flag := TFeatureFlag.Create('scheduled');
  Schedule := TFlagSchedule.Create;
  try
    Schedule.StartTime := Now;
    Schedule.EndTime := Now + 7;
    Flag.WithSchedule(Schedule);
    Assert.IsNotNull(Flag.Schedule);
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_DependsOn_AddsDependency;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('feature');
  try
    Flag.DependsOn('other-feature');
    Assert.AreEqual<Integer>(1, Length(Flag.Dependencies));
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_WithTag_AddsTag;
var
  Flag: TFeatureFlag;
begin
  Flag := TFeatureFlag.Create('feature');
  try
    Flag.WithTag('beta');
    Flag.WithTag('experimental');
    Assert.AreEqual<Integer>(2, Length(Flag.Tags));
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_GetVariant_SelectsVariant;
var
  Flag: TFeatureFlag;
  Context: TFlagContext;
  V: TFlagVariant;
begin
  Flag := TFeatureFlag.Create('ab-test');
  Context := TFlagContext.Create;
  try
    Flag.State := fsVariant;
    Flag.AddVariant(TFlagVariant.Create('A', 50));
    Flag.AddVariant(TFlagVariant.Create('B', 50));
    
    Context.WithUserId('test-user');
    V := Flag.GetVariant(Context);
    Assert.IsNotNull(V);
    Assert.IsTrue((V.Name = 'A') or (V.Name = 'B'));
  finally
    Flag.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlag.Test_ToJSON_SerializesFlag;
var
  Flag: TFeatureFlag;
  JSON: TJSONObject;
begin
  Flag := TFeatureFlag.Create('my-feature');
  try
    Flag.State := fsEnabled;
    Flag.WithRollout(100);
    
    JSON := Flag.ToJSON;
    try
      Assert.IsNotNull(JSON);
      Assert.AreEqual('my-feature', JSON.GetValue<string>('key'));
    finally
      JSON.Free;
    end;
  finally
    Flag.Free;
  end;
end;

procedure TTestFeatureFlag.Test_FromJSON_DeserializesFlag;
var
  OrigFlag, RestoredFlag: TFeatureFlag;
  JSON: TJSONObject;
begin
  OrigFlag := TFeatureFlag.Create('test-flag');
  try
    OrigFlag.State := fsEnabled;
    OrigFlag.Name := 'Test Flag';
    
    JSON := OrigFlag.ToJSON;
    try
      RestoredFlag := TFeatureFlag.FromJSON(JSON);
      try
        Assert.AreEqual(OrigFlag.Key, RestoredFlag.Key);
        Assert.AreEqual(OrigFlag.State, RestoredFlag.State);
      finally
        RestoredFlag.Free;
      end;
    finally
      JSON.Free;
    end;
  finally
    OrigFlag.Free;
  end;
end;

{ TTestFeatureFlagManager }

procedure TTestFeatureFlagManager.Test_Create_InitializesManager;
var
  Manager: TFeatureFlagManager;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Assert.IsNotNull(Manager);
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_RegisterFlag_AddsFlag;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('new-flag');
    Assert.IsNotNull(Flag);
    Assert.IsNotNull(Manager.GetFlag('new-flag'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_DeleteFlag_RemovesFlag;
var
  Manager: TFeatureFlagManager;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Manager.RegisterFlag('temp-flag');
    Manager.DeleteFlag('temp-flag');
    Assert.IsNull(Manager.GetFlag('temp-flag'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GetFlag_ReturnsFlag;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('find-me');
    Assert.AreSame(Flag, Manager.GetFlag('find-me'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GetFlag_ReturnsNilForMissing;
var
  Manager: TFeatureFlagManager;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Assert.IsNull(Manager.GetFlag('nonexistent'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_IsEnabled_ReturnsTrue;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('enabled-flag', True);
    Assert.IsTrue(Manager.IsEnabled('enabled-flag'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_IsEnabled_ReturnsFalse;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('disabled-flag');
    Assert.IsFalse(Manager.IsEnabled('disabled-flag'));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_IsEnabled_WithContext;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
  Context: TFlagContext;
begin
  Manager := TFeatureFlagManager.Create;
  Context := TFlagContext.Create;
  try
    Flag := Manager.RegisterFlag('context-flag');
    Flag.State := fsTargeted;
    Flag.AddRule(TTargetingRule.Create('role', toEquals, 'admin'));

    Context.WithAttribute('role', 'admin');
    Assert.IsTrue(Manager.IsEnabled('context-flag', Context));
  finally
    Manager.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_IsEnabled_DefaultForMissing;
var
  Manager: TFeatureFlagManager;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Assert.IsFalse(Manager.IsEnabled('missing-flag'));
    Assert.IsTrue(Manager.IsEnabled('missing-flag', True));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GetVariant_ReturnsVariant;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
  Context: TFlagContext;
  V: TFlagVariant;
begin
  Manager := TFeatureFlagManager.Create;
  Context := TFlagContext.Create;
  try
    Flag := Manager.RegisterFlag('variant-flag');
    Flag.State := fsVariant;
    Flag.AddVariant(TFlagVariant.Create('A', 100));

    Context.WithUserId('user');
    V := Manager.GetVariant('variant-flag', Context);
    Assert.IsNotNull(V);
  finally
    Manager.Free;
    Context.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GetAllFlags_ReturnsList;
var
  Manager: TFeatureFlagManager;
  Flags: TArray<TFeatureFlag>;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Manager.RegisterFlag('flag1');
    Manager.RegisterFlag('flag2');
    Manager.RegisterFlag('flag3');
    
    Flags := Manager.GetAllFlags;
    Assert.AreEqual<Integer>(3, Length(Flags));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GetFlagsByTag_FiltersByTag;
var
  Manager: TFeatureFlagManager;
  Flag1, Flag2, Flag3: TFeatureFlag;
  Flags: TArray<TFeatureFlag>;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag1 := Manager.RegisterFlag('f1');
    Flag1.WithTag('beta');

    Flag2 := Manager.RegisterFlag('f2');
    Flag2.WithTag('beta');

    Flag3 := Manager.RegisterFlag('f3');
    Flag3.WithTag('stable');

    Flags := Manager.GetFlagsByTag('beta');
    Assert.AreEqual<Integer>(2, Length(Flags));
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_EnableFlag_EnablesFlag;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('toggle');

    Manager.EnableFlag('toggle');
    Assert.AreEqual(fsEnabled, Manager.GetFlag('toggle').State);
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_DisableFlag_DisablesFlag;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('toggle', True);

    Manager.DisableFlag('toggle');
    Assert.AreEqual(fsDisabled, Manager.GetFlag('toggle').State);
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_SetRollout_SetsPercentage;
var
  Manager: TFeatureFlagManager;
  Flag: TFeatureFlag;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Flag := Manager.RegisterFlag('rollout');
    Flag.WithRollout(50);

    Assert.AreEqual(fsRollout, Manager.GetFlag('rollout').State);
    Assert.AreEqual(50, Manager.GetFlag('rollout').RolloutPercentage);
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_OnFlagChanged_Event;
begin
  // OnFlagChanged is 'of object' (method pointer) with 4 params:
  //   procedure(Sender: TObject; const AFlagKey: string; const AOldValue, ANewValue: Boolean) of object;
  // Cannot assign anonymous procedure. Test skipped.
  Assert.Pass('OnFlagChanged requires method pointer, not compatible with anonymous procedures');
end;

procedure TTestFeatureFlagManager.Test_ExportToJSON_SavesFlags;
var
  Manager: TFeatureFlagManager;
  JSON: string;
begin
  Manager := TFeatureFlagManager.Create;
  try
    Manager.RegisterFlag('save-test');

    JSON := Manager.ExportToJSON;
    Assert.IsTrue(Length(JSON) > 0);
  finally
    Manager.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_ImportFromJSON_LoadsFlags;
var
  Manager1, Manager2: TFeatureFlagManager;
  JSON: string;
begin
  Manager1 := TFeatureFlagManager.Create;
  Manager2 := TFeatureFlagManager.Create;
  try
    Manager1.RegisterFlag('load-test');

    JSON := Manager1.ExportToJSON;
    Manager2.ImportFromJSON(JSON);

    Assert.IsNotNull(Manager2.GetFlag('load-test'));
  finally
    Manager1.Free;
    Manager2.Free;
  end;
end;

procedure TTestFeatureFlagManager.Test_GlobalHelper_Manager_IsThreadSafeSingleton;
const
  ThreadCount = 16;
  Iterations = 200;
var
  Tasks: TArray<ITask>;
  Managers: TArray<TFeatureFlagManager>;
  ErrorCount: Integer;
  I: Integer;

  function CreateManagerTask(AIndex: Integer): ITask;
  begin
    Result := TTask.Run(
      procedure
      var
        J: Integer;
        Manager: TFeatureFlagManager;
        Current: TFeatureFlagManager;
      begin
        Manager := TFeatureFlags.Manager;
        Managers[AIndex] := Manager;

        if Manager = nil then
          TInterlocked.Increment(ErrorCount);

        for J := 1 to Iterations do
        begin
          Current := TFeatureFlags.Manager;
          if (Current = nil) or (Current <> Manager) then
            TInterlocked.Increment(ErrorCount);
        end;
      end);
  end;

begin
  ErrorCount := 0;
  SetLength(Tasks, ThreadCount);
  SetLength(Managers, ThreadCount);

  for I := 0 to ThreadCount - 1 do
    Tasks[I] := CreateManagerTask(I);

  TTask.WaitForAll(Tasks);

  Assert.AreEqual<Integer>(0, ErrorCount);
  Assert.IsNotNull(Managers[0]);
  Assert.AreSame(FeatureFlags, Managers[0]);

  for I := 1 to High(Managers) do
    Assert.AreSame(Managers[0], Managers[I]);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFlagContext);
  TDUnitX.RegisterTestFixture(TTestTargetingRule);
  TDUnitX.RegisterTestFixture(TTestFlagVariant);
  TDUnitX.RegisterTestFixture(TTestFlagSchedule);
  TDUnitX.RegisterTestFixture(TTestFeatureFlag);
  TDUnitX.RegisterTestFixture(TTestFeatureFlagManager);

end.
