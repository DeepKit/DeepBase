unit DeepBase.FeatureFlags;

{*******************************************************************************
  DeepBase Feature Flags
  A flexible feature flag/toggle system with:
  - Simple boolean flags
  - Percentage-based rollouts
  - User/group targeting
  - A/B testing variants
  - Time-based activation
  - Flag dependencies
  - Multiple storage backends (memory, file, database)
  - Real-time flag updates
  - Evaluation context
  
  Author: DeepBase Team
  Created: 2025-11-28
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.JSON, System.IOUtils, System.DateUtils,
  System.Hash, System.Variants, System.RegularExpressions;

type
  EFeatureFlagException = class(Exception);
  
  /// <summary>Days of week set for scheduling</summary>
  TDaysOfWeekSet = set of 0..6;

  /// <summary>Flag state</summary>
  TFlagState = (fsDisabled, fsEnabled, fsRollout, fsTargeted, fsScheduled, fsVariant);

  /// <summary>Targeting operator</summary>
  TTargetOperator = (
    toEquals,           // =
    toNotEquals,        // <>
    toContains,         // contains
    toNotContains,      // not contains
    toStartsWith,       // starts with
    toEndsWith,         // ends with
    toIn,               // in list
    toNotIn,            // not in list
    toGreaterThan,      // >
    toLessThan,         // <
    toGreaterOrEqual,   // >=
    toLessOrEqual,      // <=
    toRegex,            // regex match
    toSemVerGT,         // semantic version >
    toSemVerLT,         // semantic version <
    toSemVerEQ          // semantic version =
  );

  /// <summary>Evaluation context for feature flags</summary>
  TFlagContext = class
  private
    FAttributes: TDictionary<string, Variant>;
    FUserId: string;
    FGroupIds: TArray<string>;
    FEnvironment: string;
    FAppVersion: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Set user ID</summary>
    function WithUserId(const AUserId: string): TFlagContext;
    /// <summary>Set group IDs</summary>
    function WithGroups(const AGroupIds: array of string): TFlagContext;
    /// <summary>Set environment</summary>
    function WithEnvironment(const AEnvironment: string): TFlagContext;
    /// <summary>Set app version</summary>
    function WithAppVersion(const AVersion: string): TFlagContext;
    /// <summary>Set custom attribute</summary>
    function WithAttribute(const AName: string; const AValue: Variant): TFlagContext;
    /// <summary>Get attribute value</summary>
    function GetAttribute(const AName: string): Variant;
    /// <summary>Check if attribute exists</summary>
    function HasAttribute(const AName: string): Boolean;
    
    property UserId: string read FUserId write FUserId;
    property GroupIds: TArray<string> read FGroupIds write FGroupIds;
    property Environment: string read FEnvironment write FEnvironment;
    property AppVersion: string read FAppVersion write FAppVersion;
    property Attributes: TDictionary<string, Variant> read FAttributes;
  end;

  /// <summary>Targeting rule</summary>
  TTargetingRule = class
  private
    FAttribute: string;
    FOperator: TTargetOperator;
    FValue: Variant;
    FValues: TArray<string>;
  public
    constructor Create(const AAttribute: string; AOperator: TTargetOperator; const AValue: Variant); overload;
    constructor Create(const AAttribute: string; AOperator: TTargetOperator; const AValue: string); overload;
    constructor Create(const AAttribute: string; AOperator: TTargetOperator; const AValues: array of string); overload;
    
    /// <summary>Evaluate rule against context</summary>
    function Evaluate(const AContext: TFlagContext): Boolean;
    
    /// <summary>Create from JSON</summary>
    class function FromJSON(AJSON: TJSONObject): TTargetingRule;
    /// <summary>Export to JSON</summary>
    function ToJSON: TJSONObject;
    
    property Attribute: string read FAttribute write FAttribute;
    property Operator: TTargetOperator read FOperator write FOperator;
    property Value: Variant read FValue write FValue;
    property Values: TArray<string> read FValues write FValues;
  end;

  /// <summary>Variant definition for A/B testing</summary>
  TFlagVariant = class
  private
    FName: string;
    FWeight: Integer;
    FValue: Variant;
    FPayload: TJSONObject;
  public
    constructor Create(const AName: string; AWeight: Integer);
    destructor Destroy; override;
    
    property Name: string read FName write FName;
    property Weight: Integer read FWeight write FWeight;
    property Value: Variant read FValue write FValue;
    property Payload: TJSONObject read FPayload write FPayload;
  end;

  /// <summary>Schedule definition</summary>
  TFlagSchedule = class
  private
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FTimezone: string;
    FDaysOfWeek: TDaysOfWeekSet;
    FStartHour: Integer;
    FEndHour: Integer;
  public
    constructor Create;
    
    /// <summary>Check if schedule is active now</summary>
    function IsActive: Boolean;
    
    property StartTime: TDateTime read FStartTime write FStartTime;
    property EndTime: TDateTime read FEndTime write FEndTime;
    property Timezone: string read FTimezone write FTimezone;
    property DaysOfWeek: TDaysOfWeekSet read FDaysOfWeek write FDaysOfWeek;
    property StartHour: Integer read FStartHour write FStartHour;
    property EndHour: Integer read FEndHour write FEndHour;
  end;

  /// <summary>Feature flag definition</summary>
  TFeatureFlag = class
  private
    FKey: string;
    FName: string;
    FDescription: string;
    FState: TFlagState;
    FDefaultValue: Boolean;
    FRolloutPercentage: Integer;
    FTargetingRules: TObjectList<TTargetingRule>;
    FVariants: TObjectList<TFlagVariant>;
    FSchedule: TFlagSchedule;
    FDependencies: TArray<string>;
    FTags: TArray<string>;
    FMetadata: TDictionary<string, string>;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FVersion: Integer;
    
    function EvaluateTargeting(const AContext: TFlagContext): Boolean;
    function EvaluateRollout(const AContext: TFlagContext): Boolean;
    function SelectVariant(const AContext: TFlagContext): TFlagVariant;
  public
    constructor Create(const AKey: string);
    destructor Destroy; override;
    
    /// <summary>Evaluate flag for given context</summary>
    function Evaluate(const AContext: TFlagContext; const AFlagManager: TObject): Boolean;
    
    /// <summary>Get variant for given context</summary>
    function GetVariant(const AContext: TFlagContext): TFlagVariant;
    
    /// <summary>Add targeting rule</summary>
    function AddRule(ARule: TTargetingRule): TFeatureFlag;
    
    /// <summary>Add variant</summary>
    function AddVariant(AVariant: TFlagVariant): TFeatureFlag;
    
    /// <summary>Set rollout percentage</summary>
    function WithRollout(APercentage: Integer): TFeatureFlag;
    
    /// <summary>Set schedule</summary>
    function WithSchedule(ASchedule: TFlagSchedule): TFeatureFlag;
    
    /// <summary>Add dependency</summary>
    function DependsOn(const AFlagKey: string): TFeatureFlag;
    
    /// <summary>Add tag</summary>
    function WithTag(const ATag: string): TFeatureFlag;
    
    /// <summary>Set metadata</summary>
    function WithMetadata(const AKey, AValue: string): TFeatureFlag;
    
    /// <summary>Create from JSON</summary>
    class function FromJSON(AJSON: TJSONObject): TFeatureFlag;
    /// <summary>Export to JSON</summary>
    function ToJSON: TJSONObject;
    
    property Key: string read FKey;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property State: TFlagState read FState write FState;
    property DefaultValue: Boolean read FDefaultValue write FDefaultValue;
    property RolloutPercentage: Integer read FRolloutPercentage write FRolloutPercentage;
    property TargetingRules: TObjectList<TTargetingRule> read FTargetingRules;
    property Variants: TObjectList<TFlagVariant> read FVariants;
    property Schedule: TFlagSchedule read FSchedule write FSchedule;
    property Dependencies: TArray<string> read FDependencies write FDependencies;
    property Tags: TArray<string> read FTags write FTags;
    property Metadata: TDictionary<string, string> read FMetadata;
    property CreatedAt: TDateTime read FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt;
    property Version: Integer read FVersion;
  end;

  /// <summary>Flag evaluation result</summary>
  TFlagEvaluationResult = record
    Key: string;
    Enabled: Boolean;
    Reason: string;
    VariantKey: string;
    VariantValue: Variant;
    EvaluationTime: TDateTime;
    
    class function Create(const AKey: string; AEnabled: Boolean; const AReason: string): TFlagEvaluationResult; static;
  end;

  /// <summary>Flag change event</summary>
  TFlagChangedEvent = procedure(Sender: TObject; const AFlagKey: string; const AOldValue, ANewValue: Boolean) of object;

  /// <summary>Feature flag storage interface</summary>
  IFeatureFlagStorage = interface
    ['{D1E2F3A4-5678-9ABC-DEF0-123456789ABC}']
    function Load: TObjectList<TFeatureFlag>;
    procedure Save(const AFlags: TObjectList<TFeatureFlag>);
    procedure SaveFlag(const AFlag: TFeatureFlag);
    procedure DeleteFlag(const AKey: string);
    function GetFlag(const AKey: string): TFeatureFlag;
  end;

  /// <summary>In-memory storage</summary>
  TMemoryFlagStorage = class(TInterfacedObject, IFeatureFlagStorage)
  private
    FFlags: TObjectDictionary<string, TFeatureFlag>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    function Load: TObjectList<TFeatureFlag>;
    procedure Save(const AFlags: TObjectList<TFeatureFlag>);
    procedure SaveFlag(const AFlag: TFeatureFlag);
    procedure DeleteFlag(const AKey: string);
    function GetFlag(const AKey: string): TFeatureFlag;
  end;

  /// <summary>JSON file storage</summary>
  TFileFlagStorage = class(TInterfacedObject, IFeatureFlagStorage)
  private
    FFilePath: string;
    FLock: TCriticalSection;
  public
    constructor Create(const AFilePath: string);
    destructor Destroy; override;
    
    function Load: TObjectList<TFeatureFlag>;
    procedure Save(const AFlags: TObjectList<TFeatureFlag>);
    procedure SaveFlag(const AFlag: TFeatureFlag);
    procedure DeleteFlag(const AKey: string);
    function GetFlag(const AKey: string): TFeatureFlag;
  end;

  /// <summary>Feature flag manager</summary>
  TFeatureFlagManager = class
  private
    FFlags: TObjectDictionary<string, TFeatureFlag>;
    FStorage: IFeatureFlagStorage;
    FLock: TCriticalSection;
    FDefaultContext: TFlagContext;
    FOnFlagChanged: TFlagChangedEvent;
    FEvaluationHistory: TList<TFlagEvaluationResult>;
    FMaxHistorySize: Integer;
    FOverrides: TDictionary<string, Boolean>;
    
    procedure AddToHistory(const AResult: TFlagEvaluationResult);
  public
    constructor Create(AStorage: IFeatureFlagStorage = nil);
    destructor Destroy; override;
    
    /// <summary>Check if flag is enabled</summary>
    function IsEnabled(const AKey: string): Boolean; overload;
    function IsEnabled(const AKey: string; const AContext: TFlagContext): Boolean; overload;
    function IsEnabled(const AKey: string; ADefaultValue: Boolean): Boolean; overload;
    
    /// <summary>Evaluate flag with full result</summary>
    function Evaluate(const AKey: string): TFlagEvaluationResult; overload;
    function Evaluate(const AKey: string; const AContext: TFlagContext): TFlagEvaluationResult; overload;
    
    /// <summary>Get variant for A/B testing</summary>
    function GetVariant(const AKey: string): TFlagVariant; overload;
    function GetVariant(const AKey: string; const AContext: TFlagContext): TFlagVariant; overload;
    
    /// <summary>Get variant value</summary>
    function GetVariantValue(const AKey: string; const ADefaultValue: Variant): Variant; overload;
    function GetVariantValue(const AKey: string; const AContext: TFlagContext; const ADefaultValue: Variant): Variant; overload;
    
    /// <summary>Register a new flag</summary>
    function RegisterFlag(const AKey: string; ADefaultValue: Boolean = False): TFeatureFlag;
    
    /// <summary>Get flag by key</summary>
    function GetFlag(const AKey: string): TFeatureFlag;
    
    /// <summary>Check if flag exists</summary>
    function HasFlag(const AKey: string): Boolean;
    
    /// <summary>Get all flags</summary>
    function GetAllFlags: TArray<TFeatureFlag>;
    
    /// <summary>Get flags by tag</summary>
    function GetFlagsByTag(const ATag: string): TArray<TFeatureFlag>;
    
    /// <summary>Delete a flag</summary>
    procedure DeleteFlag(const AKey: string);
    
    /// <summary>Enable flag globally</summary>
    procedure EnableFlag(const AKey: string);
    
    /// <summary>Disable flag globally</summary>
    procedure DisableFlag(const AKey: string);
    
    /// <summary>Set override for testing</summary>
    procedure SetOverride(const AKey: string; AValue: Boolean);
    
    /// <summary>Clear override</summary>
    procedure ClearOverride(const AKey: string);
    
    /// <summary>Clear all overrides</summary>
    procedure ClearAllOverrides;
    
    /// <summary>Load flags from storage</summary>
    procedure LoadFlags;
    
    /// <summary>Save flags to storage</summary>
    procedure SaveFlags;
    
    /// <summary>Import flags from JSON</summary>
    procedure ImportFromJSON(const AJSON: string);
    
    /// <summary>Export flags to JSON</summary>
    function ExportToJSON: string;
    
    /// <summary>Get evaluation hiDeepStory</summary>
    function GetHistory: TArray<TFlagEvaluationResult>;
    
    /// <summary>Clear evaluation hiDeepStory</summary>
    procedure ClearHistory;
    
    property DefaultContext: TFlagContext read FDefaultContext write FDefaultContext;
    property OnFlagChanged: TFlagChangedEvent read FOnFlagChanged write FOnFlagChanged;
    property MaxHistorySize: Integer read FMaxHistorySize write FMaxHistorySize;
    property Storage: IFeatureFlagStorage read FStorage write FStorage;
  end;

  /// <summary>Feature flag builder</summary>
  TFeatureFlagBuilder = class
  private
    FFlag: TFeatureFlag;
  public
    constructor Create(const AKey: string);
    
    function WithName(const AName: string): TFeatureFlagBuilder;
    function WithDescription(const ADescription: string): TFeatureFlagBuilder;
    function Enabled: TFeatureFlagBuilder;
    function Disabled: TFeatureFlagBuilder;
    function WithDefault(AValue: Boolean): TFeatureFlagBuilder;
    function WithRollout(APercentage: Integer): TFeatureFlagBuilder;
    function TargetUsers(const AUserIds: array of string): TFeatureFlagBuilder;
    function TargetGroups(const AGroupIds: array of string): TFeatureFlagBuilder;
    function TargetEnvironment(const AEnvironment: string): TFeatureFlagBuilder;
    function TargetAttribute(const AAttribute: string; AOperator: TTargetOperator; const AValue: Variant): TFeatureFlagBuilder;
    function WithVariant(const AName: string; AWeight: Integer; const AValue: Variant): TFeatureFlagBuilder;
    function ScheduleFrom(AStartTime: TDateTime): TFeatureFlagBuilder;
    function ScheduleUntil(AEndTime: TDateTime): TFeatureFlagBuilder;
    function DependsOn(const AFlagKey: string): TFeatureFlagBuilder;
    function WithTag(const ATag: string): TFeatureFlagBuilder;
    function WithMetadata(const AKey, AValue: string): TFeatureFlagBuilder;
    
    function Build: TFeatureFlag;
  end;

  /// <summary>Global feature flags helper</summary>
  TFeatureFlags = class
  private
    class var FManager: TFeatureFlagManager;
    class function GetManager: TFeatureFlagManager; static;
  public
    class destructor Destroy;
    
    /// <summary>Check if flag is enabled</summary>
    class function IsEnabled(const AKey: string): Boolean; overload;
    class function IsEnabled(const AKey: string; ADefaultValue: Boolean): Boolean; overload;
    
    /// <summary>Register a flag</summary>
    class function Register(const AKey: string; ADefaultValue: Boolean = False): TFeatureFlag;
    
    /// <summary>Create flag builder</summary>
    class function Flag(const AKey: string): TFeatureFlagBuilder;
    
    /// <summary>Enable flag</summary>
    class procedure Enable(const AKey: string);
    
    /// <summary>Disable flag</summary>
    class procedure Disable(const AKey: string);
    
    /// <summary>Set override for testing</summary>
    class procedure SetOverride(const AKey: string; AValue: Boolean);
    
    /// <summary>Clear override</summary>
    class procedure ClearOverride(const AKey: string);
    
    /// <summary>Get manager instance</summary>
    class property Manager: TFeatureFlagManager read GetManager;
  end;

/// <summary>Global feature flag manager</summary>
function FeatureFlags: TFeatureFlagManager;

implementation

var
  GFeatureFlagManager: TFeatureFlagManager = nil;
  GManagerLock: TCriticalSection = nil;

function FeatureFlags: TFeatureFlagManager;
begin
  GManagerLock.Enter;
  try
    if not Assigned(GFeatureFlagManager) then
      GFeatureFlagManager := TFeatureFlagManager.Create;
    Result := GFeatureFlagManager;
  finally
    GManagerLock.Leave;
  end;
end;

{ TFlagContext }

constructor TFlagContext.Create;
begin
  inherited;
  FAttributes := TDictionary<string, Variant>.Create;
end;

destructor TFlagContext.Destroy;
begin
  FreeAndNil(FAttributes);
  inherited;
end;

function TFlagContext.WithUserId(const AUserId: string): TFlagContext;
begin
  FUserId := AUserId;
  FAttributes.AddOrSetValue('userId', AUserId);
  Result := Self;
end;

function TFlagContext.WithGroups(const AGroupIds: array of string): TFlagContext;
var
  I: Integer;
begin
  SetLength(FGroupIds, Length(AGroupIds));
  for I := 0 to High(AGroupIds) do
    FGroupIds[I] := AGroupIds[I];
  Result := Self;
end;

function TFlagContext.WithEnvironment(const AEnvironment: string): TFlagContext;
begin
  FEnvironment := AEnvironment;
  FAttributes.AddOrSetValue('environment', AEnvironment);
  Result := Self;
end;

function TFlagContext.WithAppVersion(const AVersion: string): TFlagContext;
begin
  FAppVersion := AVersion;
  FAttributes.AddOrSetValue('appVersion', AVersion);
  Result := Self;
end;

function TFlagContext.WithAttribute(const AName: string; const AValue: Variant): TFlagContext;
begin
  FAttributes.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function TFlagContext.GetAttribute(const AName: string): Variant;
begin
  if not FAttributes.TryGetValue(AName, Result) then
    Result := Null;
end;

function TFlagContext.HasAttribute(const AName: string): Boolean;
begin
  Result := FAttributes.ContainsKey(AName);
end;

{ TTargetingRule }

constructor TTargetingRule.Create(const AAttribute: string; AOperator: TTargetOperator; const AValue: Variant);
begin
  inherited Create;
  FAttribute := AAttribute;
  FOperator := AOperator;
  FValue := AValue;
end;

constructor TTargetingRule.Create(const AAttribute: string; AOperator: TTargetOperator; const AValue: string);
begin
  inherited Create;
  FAttribute := AAttribute;
  FOperator := AOperator;
  FValue := AValue;
end;

constructor TTargetingRule.Create(const AAttribute: string; AOperator: TTargetOperator; const AValues: array of string);
var
  I: Integer;
begin
  inherited Create;
  FAttribute := AAttribute;
  FOperator := AOperator;
  SetLength(FValues, Length(AValues));
  for I := 0 to High(AValues) do
    FValues[I] := AValues[I];
end;

function TTargetingRule.Evaluate(const AContext: TFlagContext): Boolean;
var
  LAttrValue: Variant;
  LStrValue, LAttrStr: string;
  I: Integer;
begin
  Result := False;
  
  if not AContext.HasAttribute(FAttribute) then
    Exit;
    
  LAttrValue := AContext.GetAttribute(FAttribute);
  LAttrStr := VarToStr(LAttrValue);
  LStrValue := VarToStr(FValue);
  
  case FOperator of
    toEquals:
      Result := LAttrStr = LStrValue;
      
    toNotEquals:
      Result := LAttrStr <> LStrValue;
      
    toContains:
      Result := Pos(LStrValue, LAttrStr) > 0;
      
    toNotContains:
      Result := Pos(LStrValue, LAttrStr) = 0;
      
    toStartsWith:
      Result := Copy(LAttrStr, 1, Length(LStrValue)) = LStrValue;
      
    toEndsWith:
      if Length(LStrValue) > Length(LAttrStr) then
        Result := False
      else
        Result := Copy(LAttrStr, Length(LAttrStr) - Length(LStrValue) + 1, Length(LStrValue)) = LStrValue;
      
    toIn:
      begin
        for I := 0 to High(FValues) do
        begin
          if LAttrStr = FValues[I] then
          begin
            Result := True;
            Break;
          end;
        end;
      end;
      
    toNotIn:
      begin
        Result := True;
        for I := 0 to High(FValues) do
        begin
          if LAttrStr = FValues[I] then
          begin
            Result := False;
            Break;
          end;
        end;
      end;
      
    toGreaterThan:
      begin
        if VarIsNumeric(LAttrValue) and VarIsNumeric(FValue) then
          Result := Double(LAttrValue) > Double(FValue)
        else
          Result := LAttrStr > LStrValue;
      end;
      
    toLessThan:
      begin
        if VarIsNumeric(LAttrValue) and VarIsNumeric(FValue) then
          Result := Double(LAttrValue) < Double(FValue)
        else
          Result := LAttrStr < LStrValue;
      end;
      
    toGreaterOrEqual:
      begin
        if VarIsNumeric(LAttrValue) and VarIsNumeric(FValue) then
          Result := Double(LAttrValue) >= Double(FValue)
        else
          Result := LAttrStr >= LStrValue;
      end;
      
    toLessOrEqual:
      begin
        if VarIsNumeric(LAttrValue) and VarIsNumeric(FValue) then
          Result := Double(LAttrValue) <= Double(FValue)
        else
          Result := LAttrStr <= LStrValue;
      end;
      
    toRegex:
      begin
        try
          Result := TRegEx.IsMatch(LAttrStr, LStrValue);
        except
          Result := False;
        end;
      end;
      
    toSemVerGT, toSemVerLT, toSemVerEQ:
      begin
        // Simplified semantic version comparison
        Result := LAttrStr >= LStrValue;
      end;
  end;
end;

class function TTargetingRule.FromJSON(AJSON: TJSONObject): TTargetingRule;
var
  LOpStr: string;
  LOperator: TTargetOperator;
  LValues: TJSONArray;
  LValueStrings: TArray<string>;
  I: Integer;
begin
  LOpStr := AJSON.GetValue<string>('operator', 'equals');
  
  if LOpStr = 'equals' then LOperator := toEquals
  else if LOpStr = 'notEquals' then LOperator := toNotEquals
  else if LOpStr = 'contains' then LOperator := toContains
  else if LOpStr = 'notContains' then LOperator := toNotContains
  else if LOpStr = 'startsWith' then LOperator := toStartsWith
  else if LOpStr = 'endsWith' then LOperator := toEndsWith
  else if LOpStr = 'in' then LOperator := toIn
  else if LOpStr = 'notIn' then LOperator := toNotIn
  else if LOpStr = 'gt' then LOperator := toGreaterThan
  else if LOpStr = 'lt' then LOperator := toLessThan
  else if LOpStr = 'gte' then LOperator := toGreaterOrEqual
  else if LOpStr = 'lte' then LOperator := toLessOrEqual
  else if LOpStr = 'regex' then LOperator := toRegex
  else LOperator := toEquals;
  
  if AJSON.TryGetValue<TJSONArray>('values', LValues) then
  begin
    SetLength(LValueStrings, LValues.Count);
    for I := 0 to LValues.Count - 1 do
      LValueStrings[I] := LValues.Items[I].Value;
    Result := TTargetingRule.Create(
      AJSON.GetValue<string>('attribute', ''),
      LOperator,
      LValueStrings
    );
  end
  else
  begin
    Result := TTargetingRule.Create(
      AJSON.GetValue<string>('attribute', ''),
      LOperator,
      AJSON.GetValue<string>('value', '')
    );
  end;
end;

function TTargetingRule.ToJSON: TJSONObject;
var
  LOpStr: string;
  LValues: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('attribute', FAttribute);
  
  case FOperator of
    toEquals: LOpStr := 'equals';
    toNotEquals: LOpStr := 'notEquals';
    toContains: LOpStr := 'contains';
    toNotContains: LOpStr := 'notContains';
    toStartsWith: LOpStr := 'startsWith';
    toEndsWith: LOpStr := 'endsWith';
    toIn: LOpStr := 'in';
    toNotIn: LOpStr := 'notIn';
    toGreaterThan: LOpStr := 'gt';
    toLessThan: LOpStr := 'lt';
    toGreaterOrEqual: LOpStr := 'gte';
    toLessOrEqual: LOpStr := 'lte';
    toRegex: LOpStr := 'regex';
    toSemVerGT: LOpStr := 'semverGt';
    toSemVerLT: LOpStr := 'semverLt';
    toSemVerEQ: LOpStr := 'semverEq';
  else
    LOpStr := 'equals';
  end;
  Result.AddPair('operator', LOpStr);
  
  if Length(FValues) > 0 then
  begin
    LValues := TJSONArray.Create;
    for I := 0 to High(FValues) do
      LValues.Add(FValues[I]);
    Result.AddPair('values', LValues);
  end
  else
    Result.AddPair('value', VarToStr(FValue));
end;

{ TFlagVariant }

constructor TFlagVariant.Create(const AName: string; AWeight: Integer);
begin
  inherited Create;
  FName := AName;
  FWeight := AWeight;
end;

destructor TFlagVariant.Destroy;
begin
  FreeAndNil(FPayload);
  inherited;
end;

{ TFlagSchedule }

constructor TFlagSchedule.Create;
begin
  inherited;
  FStartTime := 0;
  FEndTime := 0;
  FTimezone := 'UTC';
  FDaysOfWeek := [0, 1, 2, 3, 4, 5, 6];
  FStartHour := 0;
  FEndHour := 24;
end;

function TFlagSchedule.IsActive: Boolean;
var
  LNow: TDateTime;
  LDayOfWeek: Integer;
  LHour: Integer;
begin
  LNow := Now;
  
  // Check date range
  if (FStartTime > 0) and (LNow < FStartTime) then
    Exit(False);
  if (FEndTime > 0) and (LNow > FEndTime) then
    Exit(False);
    
  // Check day of week (0 = Sunday)
  LDayOfWeek := DayOfTheWeek(LNow) mod 7;
  if not (LDayOfWeek in FDaysOfWeek) then
    Exit(False);
    
  // Check hour range
  LHour := HourOf(LNow);
  if (FStartHour <> 0) or (FEndHour <> 24) then
  begin
    if (LHour < FStartHour) or (LHour >= FEndHour) then
      Exit(False);
  end;
  
  Result := True;
end;

{ TFeatureFlag }

constructor TFeatureFlag.Create(const AKey: string);
begin
  inherited Create;
  FKey := AKey;
  FState := fsDisabled;
  FDefaultValue := False;
  FRolloutPercentage := 0;
  FTargetingRules := TObjectList<TTargetingRule>.Create(True);
  FVariants := TObjectList<TFlagVariant>.Create(True);
  FMetadata := TDictionary<string, string>.Create;
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FVersion := 1;
end;

destructor TFeatureFlag.Destroy;
begin
  FreeAndNil(FMetadata);
  FreeAndNil(FVariants);
  FreeAndNil(FTargetingRules);
  FreeAndNil(FSchedule);
  inherited;
end;

function TFeatureFlag.Evaluate(const AContext: TFlagContext; const AFlagManager: TObject): Boolean;
var
  LManager: TFeatureFlagManager;
  LDep: string;
begin
  // Check dependencies first
  if (Length(FDependencies) > 0) and Assigned(AFlagManager) then
  begin
    LManager := AFlagManager as TFeatureFlagManager;
    for LDep in FDependencies do
    begin
      if not LManager.IsEnabled(LDep, AContext) then
        Exit(False);
    end;
  end;
  
  case FState of
    fsDisabled:
      Result := False;
      
    fsEnabled:
      Result := True;
      
    fsRollout:
      Result := EvaluateRollout(AContext);
      
    fsTargeted:
      Result := EvaluateTargeting(AContext);
      
    fsScheduled:
      begin
        if Assigned(FSchedule) then
          Result := FSchedule.IsActive and FDefaultValue
        else
          Result := FDefaultValue;
      end;
      
    fsVariant:
      Result := FDefaultValue;
  else
    Result := FDefaultValue;
  end;
end;

function TFeatureFlag.EvaluateTargeting(const AContext: TFlagContext): Boolean;
var
  LRule: TTargetingRule;
begin
  Result := False;
  
  // All rules must match (AND logic)
  if FTargetingRules.Count = 0 then
    Exit(FDefaultValue);
    
  for LRule in FTargetingRules do
  begin
    if not LRule.Evaluate(AContext) then
      Exit(False);
  end;
  
  Result := True;
end;

function TFeatureFlag.EvaluateRollout(const AContext: TFlagContext): Boolean;
var
  LHash: Int64;
  LBucket: Integer;
  LKey: string;
begin
  // Use consistent hashing based on user ID or flag key
  if AContext.UserId <> '' then
    LKey := FKey + ':' + AContext.UserId
  else
    LKey := FKey;
    
  LHash := THashBobJenkins.GetHashValue(LKey);
  if LHash < 0 then
    Inc(LHash, Int64(High(Cardinal)) + 1);
  LBucket := Integer(LHash mod Int64(100));
  
  Result := LBucket < FRolloutPercentage;
end;

function TFeatureFlag.SelectVariant(const AContext: TFlagContext): TFlagVariant;
var
  LTotalWeight, LBucket, LRunning: Integer;
  LHash: Int64;
  LKey: string;
  LVariant: TFlagVariant;
begin
  Result := nil;
  
  if FVariants.Count = 0 then
    Exit;
    
  // Calculate total weight
  LTotalWeight := 0;
  for LVariant in FVariants do
    Inc(LTotalWeight, LVariant.Weight);
    
  if LTotalWeight = 0 then
    Exit(FVariants[0]);
    
  // Consistent hashing for variant selection
  if AContext.UserId <> '' then
    LKey := FKey + ':variant:' + AContext.UserId
  else
    LKey := FKey + ':variant';
    
  LHash := THashBobJenkins.GetHashValue(LKey);
  if LHash < 0 then
    Inc(LHash, Int64(High(Cardinal)) + 1);
  LBucket := Integer(LHash mod Int64(LTotalWeight));
  
  // Select variant based on weight
  LRunning := 0;
  for LVariant in FVariants do
  begin
    Inc(LRunning, LVariant.Weight);
    if LBucket < LRunning then
      Exit(LVariant);
  end;
  
  Result := FVariants[FVariants.Count - 1];
end;

function TFeatureFlag.GetVariant(const AContext: TFlagContext): TFlagVariant;
begin
  Result := SelectVariant(AContext);
end;

function TFeatureFlag.AddRule(ARule: TTargetingRule): TFeatureFlag;
begin
  FTargetingRules.Add(ARule);
  FState := fsTargeted;
  FUpdatedAt := Now;
  Inc(FVersion);
  Result := Self;
end;

function TFeatureFlag.AddVariant(AVariant: TFlagVariant): TFeatureFlag;
begin
  FVariants.Add(AVariant);
  FState := fsVariant;
  FUpdatedAt := Now;
  Inc(FVersion);
  Result := Self;
end;

function TFeatureFlag.WithRollout(APercentage: Integer): TFeatureFlag;
begin
  FRolloutPercentage := APercentage;
  if APercentage > 0 then
    FState := fsRollout;
  FUpdatedAt := Now;
  Inc(FVersion);
  Result := Self;
end;

function TFeatureFlag.WithSchedule(ASchedule: TFlagSchedule): TFeatureFlag;
begin
  FreeAndNil(FSchedule);
  FSchedule := ASchedule;
  FState := fsScheduled;
  FUpdatedAt := Now;
  Inc(FVersion);
  Result := Self;
end;

function TFeatureFlag.DependsOn(const AFlagKey: string): TFeatureFlag;
begin
  SetLength(FDependencies, Length(FDependencies) + 1);
  FDependencies[High(FDependencies)] := AFlagKey;
  FUpdatedAt := Now;
  Inc(FVersion);
  Result := Self;
end;

function TFeatureFlag.WithTag(const ATag: string): TFeatureFlag;
begin
  SetLength(FTags, Length(FTags) + 1);
  FTags[High(FTags)] := ATag;
  FUpdatedAt := Now;
  Result := Self;
end;

function TFeatureFlag.WithMetadata(const AKey, AValue: string): TFeatureFlag;
begin
  FMetadata.AddOrSetValue(AKey, AValue);
  FUpdatedAt := Now;
  Result := Self;
end;

class function TFeatureFlag.FromJSON(AJSON: TJSONObject): TFeatureFlag;
var
  LStateStr: string;
  LRules, LVariants, LDeps, LTags: TJSONArray;
  I: Integer;
  LRule: TTargetingRule;
  LVariant: TFlagVariant;
  LSchedule: TJSONObject;
  LMetadata: TJSONObject;
  LPair: TJSONPair;
begin
  Result := TFeatureFlag.Create(AJSON.GetValue<string>('key', ''));
  
  Result.FName := AJSON.GetValue<string>('name', '');
  Result.FDescription := AJSON.GetValue<string>('description', '');
  Result.FDefaultValue := AJSON.GetValue<Boolean>('defaultValue', False);
  Result.FRolloutPercentage := AJSON.GetValue<Integer>('rolloutPercentage', 0);
  
  LStateStr := AJSON.GetValue<string>('state', 'disabled');
  if LStateStr = 'enabled' then Result.FState := fsEnabled
  else if LStateStr = 'rollout' then Result.FState := fsRollout
  else if LStateStr = 'targeted' then Result.FState := fsTargeted
  else if LStateStr = 'scheduled' then Result.FState := fsScheduled
  else if LStateStr = 'variant' then Result.FState := fsVariant
  else Result.FState := fsDisabled;
  
  // Load rules
  if AJSON.TryGetValue<TJSONArray>('rules', LRules) then
  begin
    for I := 0 to LRules.Count - 1 do
    begin
      LRule := TTargetingRule.FromJSON(LRules.Items[I] as TJSONObject);
      Result.FTargetingRules.Add(LRule);
    end;
  end;
  
  // Load variants
  if AJSON.TryGetValue<TJSONArray>('variants', LVariants) then
  begin
    for I := 0 to LVariants.Count - 1 do
    begin
      var LVarObj := LVariants.Items[I] as TJSONObject;
      LVariant := TFlagVariant.Create(
        LVarObj.GetValue<string>('name', ''),
        LVarObj.GetValue<Integer>('weight', 1)
      );
      LVariant.Value := LVarObj.GetValue<string>('value', '');
      Result.FVariants.Add(LVariant);
    end;
  end;
  
  // Load schedule
  if AJSON.TryGetValue<TJSONObject>('schedule', LSchedule) then
  begin
    Result.FSchedule := TFlagSchedule.Create;
    Result.FSchedule.FStartTime := ISO8601ToDate(LSchedule.GetValue<string>('startTime', ''), False);
    Result.FSchedule.FEndTime := ISO8601ToDate(LSchedule.GetValue<string>('endTime', ''), False);
  end;
  
  // Load dependencies
  if AJSON.TryGetValue<TJSONArray>('dependencies', LDeps) then
  begin
    SetLength(Result.FDependencies, LDeps.Count);
    for I := 0 to LDeps.Count - 1 do
      Result.FDependencies[I] := LDeps.Items[I].Value;
  end;
  
  // Load tags
  if AJSON.TryGetValue<TJSONArray>('tags', LTags) then
  begin
    SetLength(Result.FTags, LTags.Count);
    for I := 0 to LTags.Count - 1 do
      Result.FTags[I] := LTags.Items[I].Value;
  end;
  
  // Load metadata
  if AJSON.TryGetValue<TJSONObject>('metadata', LMetadata) then
  begin
    for LPair in LMetadata do
      Result.FMetadata.AddOrSetValue(LPair.JsonString.Value, LPair.JsonValue.Value);
  end;
  
  Result.FVersion := AJSON.GetValue<Integer>('version', 1);
end;

function TFeatureFlag.ToJSON: TJSONObject;
var
  LStateStr: string;
  LRules, LVariants, LDeps, LTags: TJSONArray;
  LRule: TTargetingRule;
  LVariant: TFlagVariant;
  LSchedule, LMetadata: TJSONObject;
  LPair: TPair<string, string>;
  I: Integer;
begin
  Result := TJSONObject.Create;
  
  Result.AddPair('key', FKey);
  Result.AddPair('name', FName);
  Result.AddPair('description', FDescription);
  Result.AddPair('defaultValue', TJSONBool.Create(FDefaultValue));
  Result.AddPair('rolloutPercentage', TJSONNumber.Create(FRolloutPercentage));
  
  case FState of
    fsDisabled: LStateStr := 'disabled';
    fsEnabled: LStateStr := 'enabled';
    fsRollout: LStateStr := 'rollout';
    fsTargeted: LStateStr := 'targeted';
    fsScheduled: LStateStr := 'scheduled';
    fsVariant: LStateStr := 'variant';
  else
    LStateStr := 'disabled';
  end;
  Result.AddPair('state', LStateStr);
  
  // Export rules
  LRules := TJSONArray.Create;
  for LRule in FTargetingRules do
    LRules.AddElement(LRule.ToJSON);
  Result.AddPair('rules', LRules);
  
  // Export variants
  LVariants := TJSONArray.Create;
  for LVariant in FVariants do
  begin
    var LVarObj := TJSONObject.Create;
    LVarObj.AddPair('name', LVariant.Name);
    LVarObj.AddPair('weight', TJSONNumber.Create(LVariant.Weight));
    LVarObj.AddPair('value', VarToStr(LVariant.Value));
    LVariants.AddElement(LVarObj);
  end;
  Result.AddPair('variants', LVariants);
  
  // Export schedule
  if Assigned(FSchedule) then
  begin
    LSchedule := TJSONObject.Create;
    if FSchedule.StartTime > 0 then
      LSchedule.AddPair('startTime', DateToISO8601(FSchedule.StartTime, False));
    if FSchedule.EndTime > 0 then
      LSchedule.AddPair('endTime', DateToISO8601(FSchedule.EndTime, False));
    Result.AddPair('schedule', LSchedule);
  end;
  
  // Export dependencies
  LDeps := TJSONArray.Create;
  for I := 0 to High(FDependencies) do
    LDeps.Add(FDependencies[I]);
  Result.AddPair('dependencies', LDeps);
  
  // Export tags
  LTags := TJSONArray.Create;
  for I := 0 to High(FTags) do
    LTags.Add(FTags[I]);
  Result.AddPair('tags', LTags);
  
  // Export metadata
  LMetadata := TJSONObject.Create;
  for LPair in FMetadata do
    LMetadata.AddPair(LPair.Key, LPair.Value);
  Result.AddPair('metadata', LMetadata);
  
  Result.AddPair('version', TJSONNumber.Create(FVersion));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt, False));
  Result.AddPair('updatedAt', DateToISO8601(FUpdatedAt, False));
end;

{ TFlagEvaluationResult }

class function TFlagEvaluationResult.Create(const AKey: string; AEnabled: Boolean;
  const AReason: string): TFlagEvaluationResult;
begin
  Result.Key := AKey;
  Result.Enabled := AEnabled;
  Result.Reason := AReason;
  Result.EvaluationTime := Now;
end;

{ TMemoryFlagStorage }

constructor TMemoryFlagStorage.Create;
begin
  inherited;
  FFlags := TObjectDictionary<string, TFeatureFlag>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TMemoryFlagStorage.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FFlags);
  inherited;
end;

function TMemoryFlagStorage.Load: TObjectList<TFeatureFlag>;
var
  LPair: TPair<string, TFeatureFlag>;
begin
  Result := TObjectList<TFeatureFlag>.Create(False); // Don't own, storage owns
  FLock.Enter;
  try
    for LPair in FFlags do
      Result.Add(LPair.Value);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryFlagStorage.Save(const AFlags: TObjectList<TFeatureFlag>);
var
  LFlag: TFeatureFlag;
begin
  FLock.Enter;
  try
    FFlags.Clear;
    for LFlag in AFlags do
      FFlags.AddOrSetValue(LFlag.Key, LFlag);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryFlagStorage.SaveFlag(const AFlag: TFeatureFlag);
begin
  FLock.Enter;
  try
    FFlags.AddOrSetValue(AFlag.Key, AFlag);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryFlagStorage.DeleteFlag(const AKey: string);
begin
  FLock.Enter;
  try
    FFlags.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

function TMemoryFlagStorage.GetFlag(const AKey: string): TFeatureFlag;
begin
  FLock.Enter;
  try
    if not FFlags.TryGetValue(AKey, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

{ TFileFlagStorage }

constructor TFileFlagStorage.Create(const AFilePath: string);
begin
  inherited Create;
  FFilePath := AFilePath;
  FLock := TCriticalSection.Create;
end;

destructor TFileFlagStorage.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TFileFlagStorage.Load: TObjectList<TFeatureFlag>;
var
  LJSON: TJSONObject;
  LFlags: TJSONArray;
  I: Integer;
  LContent: string;
begin
  Result := TObjectList<TFeatureFlag>.Create(True);
  
  FLock.Enter;
  try
    if not TFile.Exists(FFilePath) then
      Exit;
      
    LContent := TFile.ReadAllText(FFilePath, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
    
    if not Assigned(LJSON) then
      Exit;
      
    try
      if LJSON.TryGetValue<TJSONArray>('flags', LFlags) then
      begin
        for I := 0 to LFlags.Count - 1 do
          Result.Add(TFeatureFlag.FromJSON(LFlags.Items[I] as TJSONObject));
      end;
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFileFlagStorage.Save(const AFlags: TObjectList<TFeatureFlag>);
var
  LJSON: TJSONObject;
  LFlagsArray: TJSONArray;
  LFlag: TFeatureFlag;
begin
  FLock.Enter;
  try
    LJSON := TJSONObject.Create;
    try
      LFlagsArray := TJSONArray.Create;
      for LFlag in AFlags do
        LFlagsArray.AddElement(LFlag.ToJSON);
      LJSON.AddPair('flags', LFlagsArray);
      LJSON.AddPair('version', '1.0');
      LJSON.AddPair('savedAt', DateToISO8601(Now, False));
      
      TFile.WriteAllText(FFilePath, LJSON.Format(2), TEncoding.UTF8);
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFileFlagStorage.SaveFlag(const AFlag: TFeatureFlag);
var
  LFlags: TObjectList<TFeatureFlag>;
  LFound: Boolean;
  I: Integer;
begin
  LFlags := Load;
  try
    LFound := False;
    for I := 0 to LFlags.Count - 1 do
    begin
      if LFlags[I].Key = AFlag.Key then
      begin
        LFlags[I] := AFlag;
        LFound := True;
        Break;
      end;
    end;
    
    if not LFound then
      LFlags.Add(AFlag);
      
    Save(LFlags);
  finally
    LFlags.Free;
  end;
end;

procedure TFileFlagStorage.DeleteFlag(const AKey: string);
var
  LFlags: TObjectList<TFeatureFlag>;
  I: Integer;
begin
  LFlags := Load;
  try
    for I := LFlags.Count - 1 downto 0 do
    begin
      if LFlags[I].Key = AKey then
      begin
        LFlags.Delete(I);
        Break;
      end;
    end;
    Save(LFlags);
  finally
    LFlags.Free;
  end;
end;

function TFileFlagStorage.GetFlag(const AKey: string): TFeatureFlag;
var
  LFlags: TObjectList<TFeatureFlag>;
  LFlag: TFeatureFlag;
begin
  Result := nil;
  LFlags := Load;
  try
    for LFlag in LFlags do
    begin
      if LFlag.Key = AKey then
      begin
        Result := LFlag;
        LFlags.Extract(LFlag); // Don't free this one
        Break;
      end;
    end;
  finally
    LFlags.Free;
  end;
end;

{ TFeatureFlagManager }

constructor TFeatureFlagManager.Create(AStorage: IFeatureFlagStorage);
begin
  inherited Create;
  FFlags := TObjectDictionary<string, TFeatureFlag>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FEvaluationHistory := TList<TFlagEvaluationResult>.Create;
  FOverrides := TDictionary<string, Boolean>.Create;
  FMaxHistorySize := 1000;
  
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TMemoryFlagStorage.Create;
end;

destructor TFeatureFlagManager.Destroy;
begin
  FreeAndNil(FOverrides);
  FreeAndNil(FEvaluationHistory);
  FreeAndNil(FDefaultContext);
  FreeAndNil(FLock);
  FreeAndNil(FFlags);
  inherited;
end;

procedure TFeatureFlagManager.AddToHistory(const AResult: TFlagEvaluationResult);
begin
  FLock.Enter;
  try
    FEvaluationHistory.Add(AResult);
    while FEvaluationHistory.Count > FMaxHistorySize do
      FEvaluationHistory.Delete(0);
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.IsEnabled(const AKey: string): Boolean;
begin
  Result := IsEnabled(AKey, FDefaultContext);
end;

function TFeatureFlagManager.IsEnabled(const AKey: string; const AContext: TFlagContext): Boolean;
var
  LResult: TFlagEvaluationResult;
begin
  LResult := Evaluate(AKey, AContext);
  Result := LResult.Enabled;
end;

function TFeatureFlagManager.IsEnabled(const AKey: string; ADefaultValue: Boolean): Boolean;
var
  LFlag: TFeatureFlag;
  LOverride: Boolean;
begin
  // Check override first
  FLock.Enter;
  try
    if FOverrides.TryGetValue(AKey, LOverride) then
      Exit(LOverride);
      
    if FFlags.TryGetValue(AKey, LFlag) then
      Result := LFlag.Evaluate(FDefaultContext, Self)
    else
      Result := ADefaultValue;
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.Evaluate(const AKey: string): TFlagEvaluationResult;
begin
  Result := Evaluate(AKey, FDefaultContext);
end;

function TFeatureFlagManager.Evaluate(const AKey: string; const AContext: TFlagContext): TFlagEvaluationResult;
var
  LFlag: TFeatureFlag;
  LEnabled: Boolean;
  LReason: string;
  LOverride: Boolean;
  LActualContext: TFlagContext;
begin
  LActualContext := AContext;
  if not Assigned(LActualContext) then
    LActualContext := FDefaultContext;
    
  FLock.Enter;
  try
    // Check override first
    if FOverrides.TryGetValue(AKey, LOverride) then
    begin
      Result := TFlagEvaluationResult.Create(AKey, LOverride, 'Override');
      AddToHistory(Result);
      Exit;
    end;
    
    // Find flag
    if not FFlags.TryGetValue(AKey, LFlag) then
    begin
      Result := TFlagEvaluationResult.Create(AKey, False, 'Flag not found');
      AddToHistory(Result);
      Exit;
    end;
    
    // Evaluate flag
    LEnabled := LFlag.Evaluate(LActualContext, Self);
    
    case LFlag.State of
      fsDisabled: LReason := 'Disabled';
      fsEnabled: LReason := 'Enabled';
      fsRollout: LReason := 'Rollout: ' + IntToStr(LFlag.RolloutPercentage) + '%';
      fsTargeted: LReason := 'Targeting rules';
      fsScheduled: LReason := 'Scheduled';
      fsVariant: LReason := 'Variant';
    else
      LReason := 'Default';
    end;
    
    Result := TFlagEvaluationResult.Create(AKey, LEnabled, LReason);
    
    // Add variant info if applicable
    if LFlag.Variants.Count > 0 then
    begin
      var LVariant := LFlag.GetVariant(LActualContext);
      if Assigned(LVariant) then
      begin
        Result.VariantKey := LVariant.Name;
        Result.VariantValue := LVariant.Value;
      end;
    end;
    
    AddToHistory(Result);
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.GetVariant(const AKey: string): TFlagVariant;
begin
  Result := GetVariant(AKey, FDefaultContext);
end;

function TFeatureFlagManager.GetVariant(const AKey: string; const AContext: TFlagContext): TFlagVariant;
var
  LFlag: TFeatureFlag;
begin
  Result := nil;
  
  FLock.Enter;
  try
    if FFlags.TryGetValue(AKey, LFlag) then
      Result := LFlag.GetVariant(AContext);
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.GetVariantValue(const AKey: string; const ADefaultValue: Variant): Variant;
begin
  Result := GetVariantValue(AKey, FDefaultContext, ADefaultValue);
end;

function TFeatureFlagManager.GetVariantValue(const AKey: string; const AContext: TFlagContext;
  const ADefaultValue: Variant): Variant;
var
  LVariant: TFlagVariant;
begin
  LVariant := GetVariant(AKey, AContext);
  if Assigned(LVariant) then
    Result := LVariant.Value
  else
    Result := ADefaultValue;
end;

function TFeatureFlagManager.RegisterFlag(const AKey: string; ADefaultValue: Boolean): TFeatureFlag;
begin
  FLock.Enter;
  try
    if not FFlags.TryGetValue(AKey, Result) then
    begin
      Result := TFeatureFlag.Create(AKey);
      Result.DefaultValue := ADefaultValue;
      if ADefaultValue then
        Result.State := fsEnabled
      else
        Result.State := fsDisabled;
      FFlags.Add(AKey, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.GetFlag(const AKey: string): TFeatureFlag;
begin
  FLock.Enter;
  try
    if not FFlags.TryGetValue(AKey, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.HasFlag(const AKey: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FFlags.ContainsKey(AKey);
  finally
    FLock.Leave;
  end;
end;

function TFeatureFlagManager.GetAllFlags: TArray<TFeatureFlag>;
var
  LList: TList<TFeatureFlag>;
  LPair: TPair<string, TFeatureFlag>;
begin
  LList := TList<TFeatureFlag>.Create;
  try
    FLock.Enter;
    try
      for LPair in FFlags do
        LList.Add(LPair.Value);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TFeatureFlagManager.GetFlagsByTag(const ATag: string): TArray<TFeatureFlag>;
var
  LList: TList<TFeatureFlag>;
  LPair: TPair<string, TFeatureFlag>;
  LTagItem: string;
begin
  LList := TList<TFeatureFlag>.Create;
  try
    FLock.Enter;
    try
      for LPair in FFlags do
      begin
        for LTagItem in LPair.Value.Tags do
        begin
          if LTagItem = ATag then
          begin
            LList.Add(LPair.Value);
            Break;
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TFeatureFlagManager.DeleteFlag(const AKey: string);
begin
  FLock.Enter;
  try
    FFlags.Remove(AKey);
    if Assigned(FStorage) then
      FStorage.DeleteFlag(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.EnableFlag(const AKey: string);
var
  LFlag: TFeatureFlag;
  LOldValue: Boolean;
begin
  FLock.Enter;
  try
    if FFlags.TryGetValue(AKey, LFlag) then
    begin
      LOldValue := LFlag.State = fsEnabled;
      LFlag.State := fsEnabled;
      
      if Assigned(FOnFlagChanged) and (not LOldValue) then
        FOnFlagChanged(Self, AKey, False, True);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.DisableFlag(const AKey: string);
var
  LFlag: TFeatureFlag;
  LOldValue: Boolean;
begin
  FLock.Enter;
  try
    if FFlags.TryGetValue(AKey, LFlag) then
    begin
      LOldValue := LFlag.State = fsEnabled;
      LFlag.State := fsDisabled;
      
      if Assigned(FOnFlagChanged) and LOldValue then
        FOnFlagChanged(Self, AKey, True, False);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.SetOverride(const AKey: string; AValue: Boolean);
begin
  FLock.Enter;
  try
    FOverrides.AddOrSetValue(AKey, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.ClearOverride(const AKey: string);
begin
  FLock.Enter;
  try
    FOverrides.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.ClearAllOverrides;
begin
  FLock.Enter;
  try
    FOverrides.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.LoadFlags;
var
  LFlags: TObjectList<TFeatureFlag>;
  LFlag: TFeatureFlag;
begin
  if not Assigned(FStorage) then
    Exit;
    
  LFlags := FStorage.Load;
  try
    FLock.Enter;
    try
      FFlags.Clear;
      for LFlag in LFlags do
        FFlags.AddOrSetValue(LFlag.Key, LFlag);
    finally
      FLock.Leave;
    end;
  finally
    LFlags.OwnsObjects := False; // Manager now owns them
    LFlags.Free;
  end;
end;

procedure TFeatureFlagManager.SaveFlags;
var
  LFlags: TObjectList<TFeatureFlag>;
  LPair: TPair<string, TFeatureFlag>;
begin
  if not Assigned(FStorage) then
    Exit;
    
  LFlags := TObjectList<TFeatureFlag>.Create(False);
  try
    FLock.Enter;
    try
      for LPair in FFlags do
        LFlags.Add(LPair.Value);
    finally
      FLock.Leave;
    end;
    FStorage.Save(LFlags);
  finally
    LFlags.Free;
  end;
end;

procedure TFeatureFlagManager.ImportFromJSON(const AJSON: string);
var
  LJSONObj: TJSONObject;
  LFlags: TJSONArray;
  I: Integer;
  LFlag: TFeatureFlag;
begin
  LJSONObj := TJSONObject.ParseJSONValue(AJSON) as TJSONObject;
  if not Assigned(LJSONObj) then
    raise EFeatureFlagException.Create('Invalid JSON');
    
  try
    FLock.Enter;
    try
      if LJSONObj.TryGetValue<TJSONArray>('flags', LFlags) then
      begin
        for I := 0 to LFlags.Count - 1 do
        begin
          LFlag := TFeatureFlag.FromJSON(LFlags.Items[I] as TJSONObject);
          FFlags.AddOrSetValue(LFlag.Key, LFlag);
        end;
      end;
    finally
      FLock.Leave;
    end;
  finally
    LJSONObj.Free;
  end;
end;

function TFeatureFlagManager.ExportToJSON: string;
var
  LJSONObj: TJSONObject;
  LFlags: TJSONArray;
  LPair: TPair<string, TFeatureFlag>;
begin
  LJSONObj := TJSONObject.Create;
  try
    LFlags := TJSONArray.Create;
    
    FLock.Enter;
    try
      for LPair in FFlags do
        LFlags.AddElement(LPair.Value.ToJSON);
    finally
      FLock.Leave;
    end;
    
    LJSONObj.AddPair('flags', LFlags);
    LJSONObj.AddPair('exportedAt', DateToISO8601(Now, False));
    
    Result := LJSONObj.Format(2);
  finally
    LJSONObj.Free;
  end;
end;

function TFeatureFlagManager.GetHistory: TArray<TFlagEvaluationResult>;
begin
  FLock.Enter;
  try
    Result := FEvaluationHistory.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TFeatureFlagManager.ClearHistory;
begin
  FLock.Enter;
  try
    FEvaluationHistory.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TFeatureFlagBuilder }

constructor TFeatureFlagBuilder.Create(const AKey: string);
begin
  inherited Create;
  FFlag := TFeatureFlag.Create(AKey);
end;

function TFeatureFlagBuilder.WithName(const AName: string): TFeatureFlagBuilder;
begin
  FFlag.Name := AName;
  Result := Self;
end;

function TFeatureFlagBuilder.WithDescription(const ADescription: string): TFeatureFlagBuilder;
begin
  FFlag.Description := ADescription;
  Result := Self;
end;

function TFeatureFlagBuilder.Enabled: TFeatureFlagBuilder;
begin
  FFlag.State := fsEnabled;
  FFlag.DefaultValue := True;
  Result := Self;
end;

function TFeatureFlagBuilder.Disabled: TFeatureFlagBuilder;
begin
  FFlag.State := fsDisabled;
  FFlag.DefaultValue := False;
  Result := Self;
end;

function TFeatureFlagBuilder.WithDefault(AValue: Boolean): TFeatureFlagBuilder;
begin
  FFlag.DefaultValue := AValue;
  Result := Self;
end;

function TFeatureFlagBuilder.WithRollout(APercentage: Integer): TFeatureFlagBuilder;
begin
  FFlag.WithRollout(APercentage);
  Result := Self;
end;

function TFeatureFlagBuilder.TargetUsers(const AUserIds: array of string): TFeatureFlagBuilder;
begin
  FFlag.AddRule(TTargetingRule.Create('userId', toIn, AUserIds));
  Result := Self;
end;

function TFeatureFlagBuilder.TargetGroups(const AGroupIds: array of string): TFeatureFlagBuilder;
begin
  FFlag.AddRule(TTargetingRule.Create('groupId', toIn, AGroupIds));
  Result := Self;
end;

function TFeatureFlagBuilder.TargetEnvironment(const AEnvironment: string): TFeatureFlagBuilder;
begin
  FFlag.AddRule(TTargetingRule.Create('environment', toEquals, AEnvironment));
  Result := Self;
end;

function TFeatureFlagBuilder.TargetAttribute(const AAttribute: string; AOperator: TTargetOperator;
  const AValue: Variant): TFeatureFlagBuilder;
begin
  FFlag.AddRule(TTargetingRule.Create(AAttribute, AOperator, AValue));
  Result := Self;
end;

function TFeatureFlagBuilder.WithVariant(const AName: string; AWeight: Integer;
  const AValue: Variant): TFeatureFlagBuilder;
var
  LVariant: TFlagVariant;
begin
  LVariant := TFlagVariant.Create(AName, AWeight);
  LVariant.Value := AValue;
  FFlag.AddVariant(LVariant);
  Result := Self;
end;

function TFeatureFlagBuilder.ScheduleFrom(AStartTime: TDateTime): TFeatureFlagBuilder;
begin
  if not Assigned(FFlag.Schedule) then
    FFlag.FSchedule := TFlagSchedule.Create;
  FFlag.Schedule.StartTime := AStartTime;
  FFlag.State := fsScheduled;
  Result := Self;
end;

function TFeatureFlagBuilder.ScheduleUntil(AEndTime: TDateTime): TFeatureFlagBuilder;
begin
  if not Assigned(FFlag.Schedule) then
    FFlag.FSchedule := TFlagSchedule.Create;
  FFlag.Schedule.EndTime := AEndTime;
  FFlag.State := fsScheduled;
  Result := Self;
end;

function TFeatureFlagBuilder.DependsOn(const AFlagKey: string): TFeatureFlagBuilder;
begin
  FFlag.DependsOn(AFlagKey);
  Result := Self;
end;

function TFeatureFlagBuilder.WithTag(const ATag: string): TFeatureFlagBuilder;
begin
  FFlag.WithTag(ATag);
  Result := Self;
end;

function TFeatureFlagBuilder.WithMetadata(const AKey, AValue: string): TFeatureFlagBuilder;
begin
  FFlag.WithMetadata(AKey, AValue);
  Result := Self;
end;

function TFeatureFlagBuilder.Build: TFeatureFlag;
begin
  Result := FFlag;
  FFlag := nil; // Transfer ownership
end;

{ TFeatureFlags }

class destructor TFeatureFlags.Destroy;
begin
  FreeAndNil(FManager);
end;

class function TFeatureFlags.GetManager: TFeatureFlagManager;
begin
  Result := FeatureFlags;
end;

class function TFeatureFlags.IsEnabled(const AKey: string): Boolean;
begin
  Result := Manager.IsEnabled(AKey);
end;

class function TFeatureFlags.IsEnabled(const AKey: string; ADefaultValue: Boolean): Boolean;
begin
  Result := Manager.IsEnabled(AKey, ADefaultValue);
end;

class function TFeatureFlags.Register(const AKey: string; ADefaultValue: Boolean): TFeatureFlag;
begin
  Result := Manager.RegisterFlag(AKey, ADefaultValue);
end;

class function TFeatureFlags.Flag(const AKey: string): TFeatureFlagBuilder;
begin
  Result := TFeatureFlagBuilder.Create(AKey);
end;

class procedure TFeatureFlags.Enable(const AKey: string);
begin
  Manager.EnableFlag(AKey);
end;

class procedure TFeatureFlags.Disable(const AKey: string);
begin
  Manager.DisableFlag(AKey);
end;

class procedure TFeatureFlags.SetOverride(const AKey: string; AValue: Boolean);
begin
  Manager.SetOverride(AKey, AValue);
end;

class procedure TFeatureFlags.ClearOverride(const AKey: string);
begin
  Manager.ClearOverride(AKey);
end;

initialization
  GManagerLock := TCriticalSection.Create;
  
finalization
  FreeAndNil(GFeatureFlagManager);
  FreeAndNil(GManagerLock);

end.
