{ ============================================================================
  DeepBase.IntentClarification.Validation - Declarative Template Validation

  Replaces manual if-checks in Templates.ValidateTemplate with a declarative
  validation approach using DeepBase.Validation patterns.

  Phase 2 Task 27: Validation Framework Integration
    - Declarative rules for TPresetTemplate validation
    - Reports missing/invalid fields with descriptive messages
    - Extensible for future record types

  Requirements: 27.1
  ============================================================================ }

unit DeepBase.IntentClarification.Validation;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>A single validation error</summary>
  TICValidationError = record
    FieldName: string;
    Message: string;
    constructor Create(const AField, AMessage: string);
  end;

  /// <summary>Result of a validation operation</summary>
  TICValidationResult = record
    IsValid: Boolean;
    Errors: TArray<TICValidationError>;
    function GetMissingFields: TArray<string>;
    function ToString: string;
  end;

  /// <summary>
  /// A single validation rule (declarative)
  /// </summary>
  TICValidationRule = record
    FieldName: string;
    Description: string;
    Validator: TFunc<TPresetTemplate, Boolean>;
    ErrorMessage: string;
  end;

  /// <summary>
  /// Declarative template validator.
  /// Rules are defined once and applied to any TPresetTemplate instance.
  ///
  /// Usage:
  ///   var V := TICTemplateValidator.Create;
  ///   var Result := V.Validate(MyTemplate);
  ///   if not Result.IsValid then
  ///     // handle Result.Errors
  /// </summary>
  TICTemplateValidator = class
  private
    FRules: TList<TICValidationRule>;
    procedure BuildDefaultRules;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Add a custom validation rule.
    /// </summary>
    procedure AddRule(const AFieldName, ADescription: string;
      AValidator: TFunc<TPresetTemplate, Boolean>;
      const AErrorMessage: string);

    /// <summary>
    /// Validate a template against all registered rules.
    /// Returns a result with IsValid and any errors found.
    /// </summary>
    function Validate(const ATemplate: TPresetTemplate): TICValidationResult;

    /// <summary>
    /// Convenience: returns just the list of missing/invalid field names.
    /// Compatible with existing TPresetTemplateManager.ValidateTemplate signature.
    /// </summary>
    function ValidateToFieldNames(const ATemplate: TPresetTemplate): TArray<string>;
  end;

implementation

{ TICValidationError }

constructor TICValidationError.Create(const AField, AMessage: string);
begin
  FieldName := AField;
  Message := AMessage;
end;

{ TICValidationResult }

function TICValidationResult.GetMissingFields: TArray<string>;
var
  LFields: TList<string>;
  LErr: TICValidationError;
begin
  LFields := TList<string>.Create;
  try
    for LErr in Errors do
      if not LFields.Contains(LErr.FieldName) then
        LFields.Add(LErr.FieldName);
    Result := LFields.ToArray;
  finally
    LFields.Free;
  end;
end;

function TICValidationResult.ToString: string;
var
  LSB: TStringBuilder;
  LErr: TICValidationError;
begin
  if IsValid then
    Exit('Valid');

  LSB := TStringBuilder.Create;
  try
    LSB.Append(Format('Invalid (%d errors): ', [Length(Errors)]));
    for LErr in Errors do
      LSB.AppendFormat('[%s: %s] ', [LErr.FieldName, LErr.Message]);
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

{ TICTemplateValidator }

constructor TICTemplateValidator.Create;
begin
  inherited Create;
  FRules := TList<TICValidationRule>.Create;
  BuildDefaultRules;
end;

destructor TICTemplateValidator.Destroy;
begin
  FRules.Free;
  inherited;
end;

procedure TICTemplateValidator.BuildDefaultRules;
begin
  // Rule: Name is required (non-empty)
  AddRule('Name', 'Template name must not be empty',
    function(T: TPresetTemplate): Boolean
    begin
      Result := Trim(T.Name) <> '';
    end,
    'Name is required');

  // Rule: Style is required (non-empty)
  AddRule('Style', 'Style must not be empty',
    function(T: TPresetTemplate): Boolean
    begin
      Result := Trim(T.Style) <> '';
    end,
    'Style is required');

  // Rule: Style must be a known value
  AddRule('Style', 'Style must be direct, exploratory, or empathetic',
    function(T: TPresetTemplate): Boolean
    begin
      Result := (Trim(T.Style) = '') or  // empty is caught by previous rule
        SameText(T.Style, 'direct') or
        SameText(T.Style, 'exploratory') or
        SameText(T.Style, 'empathetic');
    end,
    'Style must be one of: direct, exploratory, empathetic');

  // Rule: BudgetConfig.MaxTurns > 0
  AddRule('BudgetConfig.MaxTurns', 'MaxTurns must be positive',
    function(T: TPresetTemplate): Boolean
    begin
      Result := T.BudgetConfig.MaxTurns > 0;
    end,
    'BudgetConfig.MaxTurns must be greater than 0');

  // Rule: BudgetConfig.MaxTimeSeconds > 0
  AddRule('BudgetConfig.MaxTimeSeconds', 'MaxTimeSeconds must be positive',
    function(T: TPresetTemplate): Boolean
    begin
      Result := T.BudgetConfig.MaxTimeSeconds > 0;
    end,
    'BudgetConfig.MaxTimeSeconds must be greater than 0');

  // Rule: MaxLevel in valid range
  AddRule('MaxLevel', 'MaxLevel must be in valid range',
    function(T: TPresetTemplate): Boolean
    begin
      Result := (Ord(T.MaxLevel) >= Ord(clL0)) and (Ord(T.MaxLevel) <= Ord(clL4));
    end,
    'MaxLevel must be between L0 and L4');
end;

procedure TICTemplateValidator.AddRule(const AFieldName, ADescription: string;
  AValidator: TFunc<TPresetTemplate, Boolean>; const AErrorMessage: string);
var
  LRule: TICValidationRule;
begin
  LRule.FieldName := AFieldName;
  LRule.Description := ADescription;
  LRule.Validator := AValidator;
  LRule.ErrorMessage := AErrorMessage;
  FRules.Add(LRule);
end;

function TICTemplateValidator.Validate(
  const ATemplate: TPresetTemplate): TICValidationResult;
var
  LErrors: TList<TICValidationError>;
  LRule: TICValidationRule;
begin
  LErrors := TList<TICValidationError>.Create;
  try
    for LRule in FRules do
    begin
      try
        if not LRule.Validator(ATemplate) then
          LErrors.Add(TICValidationError.Create(LRule.FieldName, LRule.ErrorMessage));
      except
        on E: Exception do
          LErrors.Add(TICValidationError.Create(LRule.FieldName,
            Format('Validation error: %s', [E.Message])));
      end;
    end;

    Result.IsValid := LErrors.Count = 0;
    Result.Errors := LErrors.ToArray;

    if not Result.IsValid then
      Log(ltDebug, Format('IC.Validation: Template "%s" has %d errors',
        [ATemplate.Name, LErrors.Count]));
  finally
    LErrors.Free;
  end;
end;

function TICTemplateValidator.ValidateToFieldNames(
  const ATemplate: TPresetTemplate): TArray<string>;
var
  LResult: TICValidationResult;
begin
  LResult := Validate(ATemplate);
  Result := LResult.GetMissingFields;
end;

end.
