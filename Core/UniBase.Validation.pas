{ ============================================================================
  UniBase.Validation - Data Validation Framework
  
  A fluent validation framework for validating data and objects.
  
  Features:
  - Fluent API for building validation rules
  - Built-in validators (Required, Length, Range, Email, Regex, etc.)
  - Custom validator support
  - Validation context and error collection
  - Conditional validation
  - Object graph validation
  - Localized error messages
  
  Usage:
    // Simple validation
    var Validator := TValidator<TUserDto>.Create
      .RuleFor('Username',
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Username);
        end)
        .Required
        .MinLength(3)
        .MaxLength(50)
      .RuleFor('Email',
        function(const U: TUserDto): TValue
        begin
          Result := TValue.From<string>(U.Email);
        end)
        .Required
        .Email;
    
    var Result := Validator.Validate(User);
    if not Result.IsValid then
      ShowErrors(Result.Errors);
  ============================================================================ }

unit UniBase.Validation;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.RegularExpressions,
  System.TypInfo,
  System.StrUtils,
  System.Threading,
  System.DateUtils,
  System.Math;

type
  // ============================================================================
  // Validation Error
  // ============================================================================
  
  TValidationError = record
    PropertyName: string;
    ErrorMessage: string;
    AttemptedValue: TValue;
    ErrorCode: string;
    
    function ToString: string;
  end;
  
  TValidationErrors = TList<TValidationError>;
  
  // ============================================================================
  // Validation Result
  // ============================================================================
  
  TValidationResult = record
  private
    FErrors: TArray<TValidationError>;
    function GetIsValid: Boolean;
    function GetErrorCount: Integer;
  public
    class function Valid: TValidationResult; static;
    class function Invalid(const Errors: TArray<TValidationError>): TValidationResult; static;
    
    procedure AddError(const Error: TValidationError);
    procedure AddErrors(const Errors: TArray<TValidationError>);
    function GetErrors(const PropertyName: string): TArray<TValidationError>;
    function GetFirstError: string;
    function ToString: string;
    
    property IsValid: Boolean read GetIsValid;
    property Errors: TArray<TValidationError> read FErrors;
    property ErrorCount: Integer read GetErrorCount;
  end;
  
  // ============================================================================
  // Validation Context
  // ============================================================================
  
  TValidationContext = class
  private
    FPropertyName: string;
    FDisplayName: string;
    FParentContext: TValidationContext;
    FRootInstance: TValue;
    FCustomData: TDictionary<string, TValue>;
  public
    constructor Create(const APropertyName: string; const ARootInstance: TValue);
    destructor Destroy; override;
    
    property PropertyName: string read FPropertyName write FPropertyName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property ParentContext: TValidationContext read FParentContext write FParentContext;
    property RootInstance: TValue read FRootInstance;
    property CustomData: TDictionary<string, TValue> read FCustomData;
  end;
  
  // ============================================================================
  // Rule Builder (Forward declaration)
  // ============================================================================
  
  TRuleBuilder<T> = class;
  TValidator<T> = class;
  
  // ============================================================================
  // Validation Rule
  // ============================================================================
  
  TValidationRule = class
  private
    FPropertyName: string;
    FErrorMessage: string;
    FErrorCode: string;
    FWhen: TFunc<Boolean>;
  protected
    function GetDefaultMessage: string; virtual; abstract;
  public
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; virtual; abstract;
    
    property PropertyName: string read FPropertyName write FPropertyName;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property ErrorCode: string read FErrorCode write FErrorCode;
    property When: TFunc<Boolean> read FWhen write FWhen;
  end;
  
  // ============================================================================
  // Built-in Rules
  // ============================================================================
  
  TRequiredRule = class(TValidationRule)
  protected
    function GetDefaultMessage: string; override;
  public
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TNotEmptyRule = class(TValidationRule)
  protected
    function GetDefaultMessage: string; override;
  public
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TMinLengthRule = class(TValidationRule)
  private
    FMinLength: Integer;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AMinLength: Integer);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
    property MinLength: Integer read FMinLength;
  end;
  
  TMaxLengthRule = class(TValidationRule)
  private
    FMaxLength: Integer;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AMaxLength: Integer);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
    property MaxLength: Integer read FMaxLength;
  end;
  
  TLengthRule = class(TValidationRule)
  private
    FMinLength: Integer;
    FMaxLength: Integer;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AMinLength, AMaxLength: Integer);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TRangeRule = class(TValidationRule)
  private
    FMin: Double;
    FMax: Double;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AMin, AMax: Double);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TGreaterThanRule = class(TValidationRule)
  private
    FValue: Double;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AValue: Double);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TLessThanRule = class(TValidationRule)
  private
    FValue: Double;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(AValue: Double);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TEmailRule = class(TValidationRule)
  protected
    function GetDefaultMessage: string; override;
  public
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TRegexRule = class(TValidationRule)
  private
    FPattern: string;
    FTimeoutMs: Integer;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(const APattern: string; ATimeoutMs: Integer = 1000);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
    property Pattern: string read FPattern;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;
  
  TMatchesRule = class(TValidationRule)
  private
    FOtherPropertyName: string;
    FOtherValue: TFunc<TValue>;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(const AOtherPropertyName: string; AOtherValue: TFunc<TValue>);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TCustomRule = class(TValidationRule)
  private
    FPredicate: TFunc<TValue, Boolean>;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(APredicate: TFunc<TValue, Boolean>; const AMessage: string);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  TInRule = class(TValidationRule)
  private
    FAllowedValues: TArray<TValue>;
  protected
    function GetDefaultMessage: string; override;
  public
    constructor Create(const AAllowedValues: array of TValue);
    function Validate(const Value: TValue; Context: TValidationContext): TValidationError; override;
  end;
  
  // ============================================================================
  // Rule Builder
  // ============================================================================
  
  /// <summary>
  /// Fluent builder for validation rules
  /// </summary>
  TRuleBuilder<T> = class
  private
    FValidator: TValidator<T>;
    FPropertyName: string;
    FValueGetter: TFunc<T, TValue>;
    FRules: TObjectList<TValidationRule>;
    FDisplayName: string;
  public
    constructor Create(AValidator: TValidator<T>; const APropertyName: string;
      AValueGetter: TFunc<T, TValue>);
    destructor Destroy; override;
    
    // Basic rules
    function Required: TRuleBuilder<T>;
    function NotEmpty: TRuleBuilder<T>;
    function MinLength(Len: Integer): TRuleBuilder<T>;
    function MaxLength(Len: Integer): TRuleBuilder<T>;
    function Length(MinLen, MaxLen: Integer): TRuleBuilder<T>;
    function Range(Min, Max: Double): TRuleBuilder<T>;
    function GreaterThan(Value: Double): TRuleBuilder<T>;
    function LessThan(Value: Double): TRuleBuilder<T>;
    function Email: TRuleBuilder<T>;
    function Matches(const Pattern: string): TRuleBuilder<T>;
    function MatchesProperty(const OtherPropertyName: string;
      OtherValue: TFunc<TValue>): TRuleBuilder<T>;
    function IsIn(const Values: array of TValue): TRuleBuilder<T>;
    
    // Custom rule
    function Must(Predicate: TFunc<TValue, Boolean>;
      const ErrorMessage: string): TRuleBuilder<T>;
    
    // Configuration
    function WithMessage(const Message: string): TRuleBuilder<T>;
    function WithErrorCode(const Code: string): TRuleBuilder<T>;
    function WithDisplayName(const Name: string): TRuleBuilder<T>;
    function When(Condition: TFunc<Boolean>): TRuleBuilder<T>;
    
    // Chain to another property
    function RuleFor(const PropertyName: string;
      ValueGetter: TFunc<T, TValue>): TRuleBuilder<T>;
    
    // Access validator
    property Validator: TValidator<T> read FValidator;
    property Rules: TObjectList<TValidationRule> read FRules;
    property PropertyName: string read FPropertyName;
    property ValueGetter: TFunc<T, TValue> read FValueGetter;
    property DisplayName: string read FDisplayName;
  end;
  
  // ============================================================================
  // Validator
  // ============================================================================
  
  /// <summary>
  /// Main validator class
  /// </summary>
  TValidator<T> = class
  private
    FRuleBuilders: TObjectList<TRuleBuilder<T>>;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Define validation rules for a property</summary>
    function RuleFor(const PropertyName: string;
      ValueGetter: TFunc<T, TValue>): TRuleBuilder<T>;
    
    /// <summary>Validate instance</summary>
    function Validate(const Instance: T): TValidationResult;
    
    /// <summary>Validate and throw exception if invalid</summary>
    procedure ValidateAndThrow(const Instance: T);
  end;
  
  // ============================================================================
  // Validation Exception
  // ============================================================================
  
  EValidationException = class(Exception)
  private
    FErrors: TArray<TValidationError>;
  public
    constructor Create(const AResult: TValidationResult);
    property Errors: TArray<TValidationError> read FErrors;
  end;
  
  // ============================================================================
  // Quick Validators (Static helpers)
  // ============================================================================
  
  TValidate = class
  public
    class function Required(const Value: string; const FieldName: string = 'Value'): TValidationResult; static;
    class function NotEmpty(const Value: string; const FieldName: string = 'Value'): TValidationResult; static;
    class function Email(const Value: string; const FieldName: string = 'Email'): TValidationResult; static;
    class function MinLength(const Value: string; Len: Integer;
      const FieldName: string = 'Value'): TValidationResult; static;
    class function MaxLength(const Value: string; Len: Integer;
      const FieldName: string = 'Value'): TValidationResult; static;
    class function Range(Value: Double; Min, Max: Double;
      const FieldName: string = 'Value'): TValidationResult; static;
    class function Regex(const Value, Pattern: string;
      const FieldName: string = 'Value'): TValidationResult; static;
    
    /// <summary>Combine multiple validation results</summary>
    class function Combine(const Results: array of TValidationResult): TValidationResult; static;
  end;

implementation

// ============================================================================
// TValidationError
// ============================================================================

function TValidationError.ToString: string;
begin
  Result := Format('%s: %s', [PropertyName, ErrorMessage]);
end;

// ============================================================================
// TValidationResult
// ============================================================================

function TValidationResult.GetIsValid: Boolean;
begin
  Result := Length(FErrors) = 0;
end;

function TValidationResult.GetErrorCount: Integer;
begin
  Result := Length(FErrors);
end;

class function TValidationResult.Valid: TValidationResult;
begin
  SetLength(Result.FErrors, 0);
end;

class function TValidationResult.Invalid(const Errors: TArray<TValidationError>): TValidationResult;
begin
  Result.FErrors := Errors;
end;

procedure TValidationResult.AddError(const Error: TValidationError);
var
  Len: Integer;
begin
  Len := Length(FErrors);
  SetLength(FErrors, Len + 1);
  FErrors[Len] := Error;
end;

procedure TValidationResult.AddErrors(const Errors: TArray<TValidationError>);
var
  I, Len: Integer;
begin
  Len := Length(FErrors);
  SetLength(FErrors, Len + Length(Errors));
  for I := 0 to High(Errors) do
    FErrors[Len + I] := Errors[I];
end;

function TValidationResult.GetErrors(const PropertyName: string): TArray<TValidationError>;
var
  List: TList<TValidationError>;
  Error: TValidationError;
begin
  List := TList<TValidationError>.Create;
  try
    for Error in FErrors do
      if Error.PropertyName = PropertyName then
        List.Add(Error);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TValidationResult.GetFirstError: string;
begin
  if Length(FErrors) > 0 then
    Result := FErrors[0].ErrorMessage
  else
    Result := '';
end;

function TValidationResult.ToString: string;
var
  SB: TStringBuilder;
  Error: TValidationError;
begin
  if IsValid then
    Exit('Validation passed');
  
  SB := TStringBuilder.Create;
  try
    SB.AppendFormat('Validation failed with %d error(s):', [Length(FErrors)]).AppendLine;
    for Error in FErrors do
      SB.AppendFormat('  - %s', [Error.ToString]).AppendLine;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// ============================================================================
// TValidationContext
// ============================================================================

constructor TValidationContext.Create(const APropertyName: string;
  const ARootInstance: TValue);
begin
  inherited Create;
  FPropertyName := APropertyName;
  FDisplayName := APropertyName;
  FRootInstance := ARootInstance;
  FCustomData := TDictionary<string, TValue>.Create;
end;

destructor TValidationContext.Destroy;
begin
  FreeAndNil(FCustomData);
  inherited;
end;

// ============================================================================
// TRequiredRule
// ============================================================================

function TRequiredRule.GetDefaultMessage: string;
begin
  Result := '%s is required';
end;

function TRequiredRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  IsInvalid: Boolean;
begin
  Result := Default(TValidationError);
  
  IsInvalid := Value.IsEmpty;
  
  if not IsInvalid and (Value.Kind in [tkString, tkLString, tkWString, tkUString]) then
    IsInvalid := Value.AsString = '';
  
  if IsInvalid then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'REQUIRED');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
  end;
end;

// ============================================================================
// TNotEmptyRule
// ============================================================================

function TNotEmptyRule.GetDefaultMessage: string;
begin
  Result := '%s must not be empty';
end;

function TNotEmptyRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  IsInvalid: Boolean;
begin
  Result := Default(TValidationError);
  IsInvalid := False;
  
  if Value.Kind in [tkString, tkLString, tkWString, tkUString] then
    IsInvalid := Value.AsString.Trim = ''
  else if Value.IsArray then
    IsInvalid := Value.GetArrayLength = 0;
  
  if IsInvalid then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'NOT_EMPTY');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
  end;
end;

// ============================================================================
// TMinLengthRule
// ============================================================================

constructor TMinLengthRule.Create(AMinLength: Integer);
begin
  inherited Create;
  FMinLength := AMinLength;
end;

function TMinLengthRule.GetDefaultMessage: string;
begin
  Result := '%s must be at least %d characters';
end;

function TMinLengthRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  Len: Integer;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkString, tkLString, tkWString, tkUString] then
    Len := Length(Value.AsString)
  else if Value.IsArray then
    Len := Value.GetArrayLength
  else
    Exit;
  
  if Len < FMinLength then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'MIN_LENGTH');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FMinLength]);
  end;
end;

// ============================================================================
// TMaxLengthRule
// ============================================================================

constructor TMaxLengthRule.Create(AMaxLength: Integer);
begin
  inherited Create;
  FMaxLength := AMaxLength;
end;

function TMaxLengthRule.GetDefaultMessage: string;
begin
  Result := '%s must not exceed %d characters';
end;

function TMaxLengthRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  Len: Integer;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkString, tkLString, tkWString, tkUString] then
    Len := Length(Value.AsString)
  else if Value.IsArray then
    Len := Value.GetArrayLength
  else
    Exit;
  
  if Len > FMaxLength then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'MAX_LENGTH');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FMaxLength]);
  end;
end;

// ============================================================================
// TLengthRule
// ============================================================================

constructor TLengthRule.Create(AMinLength, AMaxLength: Integer);
begin
  inherited Create;
  FMinLength := AMinLength;
  FMaxLength := AMaxLength;
end;

function TLengthRule.GetDefaultMessage: string;
begin
  Result := '%s must be between %d and %d characters';
end;

function TLengthRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  Len: Integer;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkString, tkLString, tkWString, tkUString] then
    Len := Length(Value.AsString)
  else if Value.IsArray then
    Len := Value.GetArrayLength
  else
    Exit;
  
  if (Len < FMinLength) or (Len > FMaxLength) then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'LENGTH');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FMinLength, FMaxLength]);
  end;
end;

// ============================================================================
// TRangeRule
// ============================================================================

constructor TRangeRule.Create(AMin, AMax: Double);
begin
  inherited Create;
  FMin := AMin;
  FMax := AMax;
end;

function TRangeRule.GetDefaultMessage: string;
begin
  Result := '%s must be between %.2f and %.2f';
end;

function TRangeRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  NumValue: Double;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkInteger, tkInt64] then
    NumValue := Value.AsInt64
  else if Value.Kind = tkFloat then
    NumValue := Value.AsExtended
  else
    Exit;
  
  if (NumValue < FMin) or (NumValue > FMax) then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'RANGE');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FMin, FMax]);
  end;
end;

// ============================================================================
// TGreaterThanRule
// ============================================================================

constructor TGreaterThanRule.Create(AValue: Double);
begin
  inherited Create;
  FValue := AValue;
end;

function TGreaterThanRule.GetDefaultMessage: string;
begin
  Result := '%s must be greater than %.2f';
end;

function TGreaterThanRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  NumValue: Double;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkInteger, tkInt64] then
    NumValue := Value.AsInt64
  else if Value.Kind = tkFloat then
    NumValue := Value.AsExtended
  else
    Exit;
  
  if NumValue <= FValue then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'GREATER_THAN');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FValue]);
  end;
end;

// ============================================================================
// TLessThanRule
// ============================================================================

constructor TLessThanRule.Create(AValue: Double);
begin
  inherited Create;
  FValue := AValue;
end;

function TLessThanRule.GetDefaultMessage: string;
begin
  Result := '%s must be less than %.2f';
end;

function TLessThanRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  NumValue: Double;
begin
  Result := Default(TValidationError);
  
  if Value.Kind in [tkInteger, tkInt64] then
    NumValue := Value.AsInt64
  else if Value.Kind = tkFloat then
    NumValue := Value.AsExtended
  else
    Exit;
  
  if NumValue >= FValue then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'LESS_THAN');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FValue]);
  end;
end;

// ============================================================================
// TEmailRule
// ============================================================================

function TEmailRule.GetDefaultMessage: string;
begin
  Result := '%s is not a valid email address';
end;

function TEmailRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
const
  EmailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
var
  S: string;
begin
  Result := Default(TValidationError);
  
  if not (Value.Kind in [tkString, tkLString, tkWString, tkUString]) then
    Exit;
  
  S := Value.AsString;
  if (S <> '') and not TRegEx.IsMatch(S, EmailPattern) then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'EMAIL');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
  end;
end;

// ============================================================================
// TRegexRule
// ============================================================================

constructor TRegexRule.Create(const APattern: string; ATimeoutMs: Integer = 1000);
begin
  inherited Create;
  FPattern := APattern;
  FTimeoutMs := Max(ATimeoutMs, 100); // 最小100ms超时
end;

function TRegexRule.GetDefaultMessage: string;
begin
  Result := '%s has an invalid format';
end;

function TRegexRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  S: string;
  Regex: TRegEx;
  StartTime: TDateTime;
  Task: ITask;
  IsMatched: Boolean;
  TaskCompleted: Boolean;
begin
  Result := Default(TValidationError);
  
  if not (Value.Kind in [tkString, tkLString, tkWString, tkUString]) then
    Exit;
  
  S := Value.AsString;
  if S <> '' then
  begin
    try
      // 使用异步任务执行正则表达式，防止ReDoS攻击
      IsMatched := False;
      TaskCompleted := False;
      
      Task := TTask.Run(
        procedure
        begin
          try
            Regex := TRegEx.Create(FPattern, [roCompiled]);
            IsMatched := Regex.IsMatch(S);
            TaskCompleted := True;
          except
            TaskCompleted := True; // 即使出错也标记为完成
          end;
        end);
      
      // 等待任务完成或超时
      StartTime := Now;
      while not TaskCompleted and (MilliSecondsBetween(Now, StartTime) < FTimeoutMs) do
      begin
        Sleep(10); // 短暂休眠避免CPU占用过高
      end;
      
      if not TaskCompleted then
      begin
        // 超时，认为是ReDoS攻击
        Result.PropertyName := Context.PropertyName;
        Result.AttemptedValue := Value;
        Result.ErrorCode := 'REGEX_TIMEOUT';
        Result.ErrorMessage := 'Regular expression validation timeout (possible ReDoS attack)';
        Exit;
      end;
        
      if not IsMatched then
      begin
        Result.PropertyName := Context.PropertyName;
        Result.AttemptedValue := Value;
        Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'REGEX');
        if ErrorMessage <> '' then
          Result.ErrorMessage := ErrorMessage
        else
          Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
      end;
    except
      on E: Exception do
      begin
        Result.PropertyName := Context.PropertyName;
        Result.AttemptedValue := Value;
        Result.ErrorCode := 'REGEX_ERROR';
        Result.ErrorMessage := 'Regular expression error: ' + E.Message;
      end;
    end;
  end;
end;

// ============================================================================
// TMatchesRule
// ============================================================================

constructor TMatchesRule.Create(const AOtherPropertyName: string;
  AOtherValue: TFunc<TValue>);
begin
  inherited Create;
  FOtherPropertyName := AOtherPropertyName;
  FOtherValue := AOtherValue;
end;

function TMatchesRule.GetDefaultMessage: string;
begin
  Result := '%s must match %s';
end;

function TMatchesRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  OtherVal: TValue;
begin
  Result := Default(TValidationError);
  
  if not Assigned(FOtherValue) then
    Exit;
  
  OtherVal := FOtherValue();
  
  // Compare as strings since TValue.Equals may not exist in all Delphi versions
  if Value.ToString <> OtherVal.ToString then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'MATCHES');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName, FOtherPropertyName]);
  end;
end;

// ============================================================================
// TCustomRule
// ============================================================================

constructor TCustomRule.Create(APredicate: TFunc<TValue, Boolean>;
  const AMessage: string);
begin
  inherited Create;
  FPredicate := APredicate;
  ErrorMessage := AMessage;
end;

function TCustomRule.GetDefaultMessage: string;
begin
  Result := '%s is invalid';
end;

function TCustomRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
begin
  Result := Default(TValidationError);
  
  if not Assigned(FPredicate) then
    Exit;
  
  if not FPredicate(Value) then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'CUSTOM');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
  end;
end;

// ============================================================================
// TInRule
// ============================================================================

constructor TInRule.Create(const AAllowedValues: array of TValue);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FAllowedValues, Length(AAllowedValues));
  for I := 0 to High(AAllowedValues) do
    FAllowedValues[I] := AAllowedValues[I];
end;

function TInRule.GetDefaultMessage: string;
begin
  Result := '%s has an invalid value';
end;

function TInRule.Validate(const Value: TValue; Context: TValidationContext): TValidationError;
var
  AllowedVal: TValue;
  Found: Boolean;
begin
  Result := Default(TValidationError);
  Found := False;
  
  for AllowedVal in FAllowedValues do
  begin
    if Value.ToString = AllowedVal.ToString then
    begin
      Found := True;
      Break;
    end;
  end;
  
  if not Found then
  begin
    Result.PropertyName := Context.PropertyName;
    Result.AttemptedValue := Value;
    Result.ErrorCode := IfThen(ErrorCode <> '', ErrorCode, 'IN');
    if ErrorMessage <> '' then
      Result.ErrorMessage := ErrorMessage
    else
      Result.ErrorMessage := Format(GetDefaultMessage, [Context.DisplayName]);
  end;
end;

// ============================================================================
// TRuleBuilder<T>
// ============================================================================

constructor TRuleBuilder<T>.Create(AValidator: TValidator<T>;
  const APropertyName: string; AValueGetter: TFunc<T, TValue>);
begin
  inherited Create;
  FValidator := AValidator;
  FPropertyName := APropertyName;
  FDisplayName := APropertyName;
  FValueGetter := AValueGetter;
  FRules := TObjectList<TValidationRule>.Create(True);
end;

destructor TRuleBuilder<T>.Destroy;
begin
  FreeAndNil(FRules);
  inherited;
end;

function TRuleBuilder<T>.Required: TRuleBuilder<T>;
var
  Rule: TRequiredRule;
begin
  Rule := TRequiredRule.Create;
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.NotEmpty: TRuleBuilder<T>;
var
  Rule: TNotEmptyRule;
begin
  Rule := TNotEmptyRule.Create;
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.MinLength(Len: Integer): TRuleBuilder<T>;
var
  Rule: TMinLengthRule;
begin
  Rule := TMinLengthRule.Create(Len);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.MaxLength(Len: Integer): TRuleBuilder<T>;
var
  Rule: TMaxLengthRule;
begin
  Rule := TMaxLengthRule.Create(Len);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.Length(MinLen, MaxLen: Integer): TRuleBuilder<T>;
var
  Rule: TLengthRule;
begin
  Rule := TLengthRule.Create(MinLen, MaxLen);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.Range(Min, Max: Double): TRuleBuilder<T>;
var
  Rule: TRangeRule;
begin
  Rule := TRangeRule.Create(Min, Max);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.GreaterThan(Value: Double): TRuleBuilder<T>;
var
  Rule: TGreaterThanRule;
begin
  Rule := TGreaterThanRule.Create(Value);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.LessThan(Value: Double): TRuleBuilder<T>;
var
  Rule: TLessThanRule;
begin
  Rule := TLessThanRule.Create(Value);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.Email: TRuleBuilder<T>;
var
  Rule: TEmailRule;
begin
  Rule := TEmailRule.Create;
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.Matches(const Pattern: string): TRuleBuilder<T>;
var
  Rule: TRegexRule;
begin
  Rule := TRegexRule.Create(Pattern);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.MatchesProperty(const OtherPropertyName: string;
  OtherValue: TFunc<TValue>): TRuleBuilder<T>;
var
  Rule: TMatchesRule;
begin
  Rule := TMatchesRule.Create(OtherPropertyName, OtherValue);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.IsIn(const Values: array of TValue): TRuleBuilder<T>;
var
  Rule: TInRule;
begin
  Rule := TInRule.Create(Values);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.Must(Predicate: TFunc<TValue, Boolean>;
  const ErrorMessage: string): TRuleBuilder<T>;
var
  Rule: TCustomRule;
begin
  Rule := TCustomRule.Create(Predicate, ErrorMessage);
  Rule.PropertyName := FPropertyName;
  FRules.Add(Rule);
  Result := Self;
end;

function TRuleBuilder<T>.WithMessage(const Message: string): TRuleBuilder<T>;
begin
  if FRules.Count > 0 then
    FRules.Last.ErrorMessage := Message;
  Result := Self;
end;

function TRuleBuilder<T>.WithErrorCode(const Code: string): TRuleBuilder<T>;
begin
  if FRules.Count > 0 then
    FRules.Last.ErrorCode := Code;
  Result := Self;
end;

function TRuleBuilder<T>.WithDisplayName(const Name: string): TRuleBuilder<T>;
begin
  FDisplayName := Name;
  Result := Self;
end;

function TRuleBuilder<T>.When(Condition: TFunc<Boolean>): TRuleBuilder<T>;
begin
  if FRules.Count > 0 then
    FRules.Last.When := Condition;
  Result := Self;
end;

function TRuleBuilder<T>.RuleFor(const PropertyName: string;
  ValueGetter: TFunc<T, TValue>): TRuleBuilder<T>;
begin
  Result := FValidator.RuleFor(PropertyName, ValueGetter);
end;

// ============================================================================
// TValidator<T>
// ============================================================================

constructor TValidator<T>.Create;
begin
  inherited Create;
  FRuleBuilders := TObjectList<TRuleBuilder<T>>.Create(True);
end;

destructor TValidator<T>.Destroy;
begin
  FreeAndNil(FRuleBuilders);
  inherited;
end;

function TValidator<T>.RuleFor(const PropertyName: string;
  ValueGetter: TFunc<T, TValue>): TRuleBuilder<T>;
begin
  Result := TRuleBuilder<T>.Create(Self, PropertyName, ValueGetter);
  FRuleBuilders.Add(Result);
end;

function TValidator<T>.Validate(const Instance: T): TValidationResult;
var
  Builder: TRuleBuilder<T>;
  Rule: TValidationRule;
  Context: TValidationContext;
  Value: TValue;
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  
  for Builder in FRuleBuilders do
  begin
    Value := Builder.ValueGetter(Instance);
    
    Context := TValidationContext.Create(Builder.PropertyName, TValue.From<T>(Instance));
    try
      Context.DisplayName := Builder.DisplayName;
      
      for Rule in Builder.Rules do
      begin
        // Check condition
        if Assigned(Rule.When) and not Rule.When() then
          Continue;
        
        Error := Rule.Validate(Value, Context);
        if Error.ErrorMessage <> '' then
          Result.AddError(Error);
      end;
    finally
      Context.Free;
    end;
  end;
end;

procedure TValidator<T>.ValidateAndThrow(const Instance: T);
var
  R: TValidationResult;
begin
  R := Validate(Instance);
  if not R.IsValid then
    raise EValidationException.Create(R);
end;

// ============================================================================
// EValidationException
// ============================================================================

constructor EValidationException.Create(const AResult: TValidationResult);
begin
  inherited Create(AResult.ToString);
  FErrors := AResult.Errors;
end;

// ============================================================================
// TValidate
// ============================================================================

class function TValidate.Required(const Value: string;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if Value = '' then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s is required', [FieldName]);
    Error.ErrorCode := 'REQUIRED';
    Result.AddError(Error);
  end;
end;

class function TValidate.NotEmpty(const Value: string;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if Value.Trim = '' then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s must not be empty', [FieldName]);
    Error.ErrorCode := 'NOT_EMPTY';
    Result.AddError(Error);
  end;
end;

class function TValidate.Email(const Value: string;
  const FieldName: string): TValidationResult;
const
  EmailPattern = '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if (Value <> '') and not TRegEx.IsMatch(Value, EmailPattern) then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s is not a valid email', [FieldName]);
    Error.ErrorCode := 'EMAIL';
    Result.AddError(Error);
  end;
end;

class function TValidate.MinLength(const Value: string; Len: Integer;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if Length(Value) < Len then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s must be at least %d characters', [FieldName, Len]);
    Error.ErrorCode := 'MIN_LENGTH';
    Result.AddError(Error);
  end;
end;

class function TValidate.MaxLength(const Value: string; Len: Integer;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if Length(Value) > Len then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s must not exceed %d characters', [FieldName, Len]);
    Error.ErrorCode := 'MAX_LENGTH';
    Result.AddError(Error);
  end;
end;

class function TValidate.Range(Value: Double; Min, Max: Double;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if (Value < Min) or (Value > Max) then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s must be between %.2f and %.2f', [FieldName, Min, Max]);
    Error.ErrorCode := 'RANGE';
    Result.AddError(Error);
  end;
end;

class function TValidate.Regex(const Value, Pattern: string;
  const FieldName: string): TValidationResult;
var
  Error: TValidationError;
begin
  Result := TValidationResult.Valid;
  if (Value <> '') and not TRegEx.IsMatch(Value, Pattern) then
  begin
    Error.PropertyName := FieldName;
    Error.ErrorMessage := Format('%s has an invalid format', [FieldName]);
    Error.ErrorCode := 'REGEX';
    Result.AddError(Error);
  end;
end;

class function TValidate.Combine(const Results: array of TValidationResult): TValidationResult;
var
  R: TValidationResult;
begin
  Result := TValidationResult.Valid;
  for R in Results do
    Result.AddErrors(R.Errors);
end;

end.
