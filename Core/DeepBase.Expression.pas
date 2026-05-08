{ ============================================================================
  DeepBase.Expression - Expression Parser and Evaluator
  
  A mathematical and logical expression parser with variable support.
  
  Features:
  - Mathematical operations: +, -, *, /, %, ^
  - Comparison: =, <>, <, >, <=, >=
  - Logical: AND, OR, NOT, XOR
  - Built-in functions: sin, cos, tan, sqrt, abs, min, max, etc.
  - Variables and constants
  - String operations
  - Custom function support
  - Compiled expression caching
  
  Usage:
    // Simple expression
    var Result := TExpression.Evaluate('2 + 3 * 4');  // 14
    
    // With variables
    var Ctx := TExpressionContext.Create;
    Ctx.SetVariable('x', 10);
    Ctx.SetVariable('y', 5);
    var Result := TExpression.Evaluate('x * y + 2', Ctx);  // 52
    
    // Compiled for repeated evaluation
    var Expr := TExpression.Compile('sin(x) + cos(y)');
    for i := 1 to 100 do
    begin
      Ctx.SetVariable('x', i);
      WriteLn(Expr.Evaluate(Ctx));
    end;
    
    // Logical expressions
    var IsValid := TExpression.Evaluate('age >= 18 AND status = "active"', Ctx).AsBoolean;
  ============================================================================ }

unit DeepBase.Expression;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.Variants,
  System.StrUtils;

type
  TExpressionValue = record
  private
    FValue: Variant;
  public
    class operator Implicit(const V: Double): TExpressionValue;
    class operator Implicit(const V: Integer): TExpressionValue;
    class operator Implicit(const V: Int64): TExpressionValue;
    class operator Implicit(const V: Boolean): TExpressionValue;
    class operator Implicit(const V: string): TExpressionValue;
    class operator Implicit(const V: TExpressionValue): Double;
    class operator Implicit(const V: TExpressionValue): Boolean;
    class operator Implicit(const V: TExpressionValue): string;
    class operator Implicit(const V: Variant): TExpressionValue;
    class operator Implicit(const V: TExpressionValue): Variant;
    
    function AsDouble: Double;
    function AsInteger: Integer;
    function AsInt64: Int64;
    function AsBoolean: Boolean;
    function AsString: string;
    function IsNull: Boolean;
    function IsNumeric: Boolean;
    function IsString: Boolean;
    
    class function Null: TExpressionValue; static;
    
    property Value: Variant read FValue write FValue;
  end;
  
  // Forward declarations
  TExpressionContext = class;
  TCompiledExpression = class;
  
  // Custom function type
  TExpressionFunc = reference to function(const Args: array of TExpressionValue;
    Context: TExpressionContext): TExpressionValue;
  
  // ============================================================================
  // Expression Context
  // ============================================================================
  
  TExpressionContext = class
  private
    FVariables: TDictionary<string, TExpressionValue>;
    FFunctions: TDictionary<string, TExpressionFunc>;
    FParent: TExpressionContext;
    FCaseSensitive: Boolean;
    
    function NormalizeName(const Name: string): string;
    procedure RegisterBuiltInFunctions;
  public
    constructor Create(AParent: TExpressionContext = nil);
    destructor Destroy; override;
    
    // Variables
    procedure SetVariable(const Name: string; const Value: TExpressionValue);
    function GetVariable(const Name: string): TExpressionValue;
    function TryGetVariable(const Name: string; out Value: TExpressionValue): Boolean;
    function HasVariable(const Name: string): Boolean;
    procedure ClearVariables;
    
    // Functions
    procedure RegisterFunction(const Name: string; Func: TExpressionFunc);
    function GetFunction(const Name: string): TExpressionFunc;
    function HasFunction(const Name: string): Boolean;
    
    // Configuration
    property CaseSensitive: Boolean read FCaseSensitive write FCaseSensitive;
    property Parent: TExpressionContext read FParent write FParent;
  end;
  
  // ============================================================================
  // Token Types
  // ============================================================================
  
  TTokenType = (
    ttNumber, ttString, ttIdentifier, ttOperator, ttFunction,
    ttLeftParen, ttRightParen, ttComma, ttEOF
  );
  
  TToken = record
    TokenType: TTokenType;
    Value: string;
    NumValue: Double;
    Position: Integer;
  end;
  
  // ============================================================================
  // AST Node Types
  // ============================================================================
  
  TASTNode = class;
  TASTNodeClass = class of TASTNode;
  
  TASTNode = class
  public
    function Evaluate(Context: TExpressionContext): TExpressionValue; virtual; abstract;
    function Clone: TASTNode; virtual; abstract;
  end;
  
  TNumberNode = class(TASTNode)
  private
    FValue: Double;
  public
    constructor Create(AValue: Double);
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TStringNode = class(TASTNode)
  private
    FValue: string;
  public
    constructor Create(const AValue: string);
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TBooleanNode = class(TASTNode)
  private
    FValue: Boolean;
  public
    constructor Create(AValue: Boolean);
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TVariableNode = class(TASTNode)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TBinaryOpNode = class(TASTNode)
  private
    FOperator: string;
    FLeft: TASTNode;
    FRight: TASTNode;
  public
    constructor Create(const AOp: string; ALeft, ARight: TASTNode);
    destructor Destroy; override;
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TUnaryOpNode = class(TASTNode)
  private
    FOperator: string;
    FOperand: TASTNode;
  public
    constructor Create(const AOp: string; AOperand: TASTNode);
    destructor Destroy; override;
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TFunctionCallNode = class(TASTNode)
  private
    FName: string;
    FArgs: TObjectList<TASTNode>;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    procedure AddArg(Arg: TASTNode);
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  TConditionalNode = class(TASTNode)
  private
    FCondition: TASTNode;
    FTrueExpr: TASTNode;
    FFalseExpr: TASTNode;
  public
    constructor Create(ACondition, ATrueExpr, AFalseExpr: TASTNode);
    destructor Destroy; override;
    function Evaluate(Context: TExpressionContext): TExpressionValue; override;
    function Clone: TASTNode; override;
  end;
  
  // ============================================================================
  // Lexer
  // ============================================================================
  
  TExpressionLexer = class
  private
    FExpression: string;
    FPosition: Integer;
    FCurrentChar: Char;
    
    procedure Advance;
    procedure SkipWhitespace;
    function PeekChar: Char;
    function ReadNumber: TToken;
    function ReadString: TToken;
    function ReadIdentifier: TToken;
    function ReadOperator: TToken;
  public
    constructor Create(const AExpression: string);
    function GetNextToken: TToken;
  end;
  
  // ============================================================================
  // Parser
  // ============================================================================
  
  EExpressionError = class(Exception)
  private
    FPosition: Integer;
  public
    constructor Create(const AMessage: string; APosition: Integer);
    property Position: Integer read FPosition;
  end;
  
  TExpressionParser = class
  private
    FLexer: TExpressionLexer;
    FCurrentToken: TToken;
    
    procedure Consume(TokenType: TTokenType);
    function ParseExpression: TASTNode;
    function ParseOr: TASTNode;
    function ParseXor: TASTNode;
    function ParseAnd: TASTNode;
    function ParseEquality: TASTNode;
    function ParseComparison: TASTNode;
    function ParseAdditive: TASTNode;
    function ParseMultiplicative: TASTNode;
    function ParsePower: TASTNode;
    function ParseUnary: TASTNode;
    function ParsePrimary: TASTNode;
    function ParseFunctionCall(const Name: string): TASTNode;
  public
    constructor Create(const Expression: string);
    destructor Destroy; override;
    function Parse: TASTNode;
  end;
  
  // ============================================================================
  // Compiled Expression
  // ============================================================================
  
  TCompiledExpression = class
  private
    FAST: TASTNode;
    FExpression: string;
  public
    constructor Create(const AExpression: string);
    destructor Destroy; override;
    
    function Evaluate(Context: TExpressionContext = nil): TExpressionValue;
    function Clone: TCompiledExpression;
    
    property Expression: string read FExpression;
  end;
  
  // ============================================================================
  // Expression Helper
  // ============================================================================
  
  TExpression = class
  private
    class var FCache: TDictionary<string, TCompiledExpression>;
    class var FCacheLock: TObject;
    class var FGlobalContext: TExpressionContext;
    class function CompileCached(const Expression: string): TCompiledExpression; static;
  public
    class constructor Create;
    class destructor Destroy;
    
    // Quick evaluation
    class function Evaluate(const Expression: string;
      Context: TExpressionContext = nil): TExpressionValue; static;
    
    // Compile for repeated use
    class function Compile(const Expression: string): TCompiledExpression; static;
    
    // Global context for default variables/functions
    class property GlobalContext: TExpressionContext read FGlobalContext;
    
    // Cache management
    class procedure ClearCache; static;
    class procedure EnableCache(Enable: Boolean); static;
  end;

implementation

// ============================================================================
// TExpressionValue
// ============================================================================

class operator TExpressionValue.Implicit(const V: Double): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: Integer): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: Int64): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: Boolean): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: string): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: TExpressionValue): Double;
begin
  Result := V.AsDouble;
end;

class operator TExpressionValue.Implicit(const V: TExpressionValue): Boolean;
begin
  Result := V.AsBoolean;
end;

class operator TExpressionValue.Implicit(const V: TExpressionValue): string;
begin
  Result := V.AsString;
end;

class operator TExpressionValue.Implicit(const V: Variant): TExpressionValue;
begin
  Result.FValue := V;
end;

class operator TExpressionValue.Implicit(const V: TExpressionValue): Variant;
begin
  Result := V.FValue;
end;

function TExpressionValue.AsDouble: Double;
begin
  if VarIsNull(FValue) then
    Result := 0
  else if VarIsStr(FValue) then
    Result := StrToFloatDef(FValue, 0)
  else
    Result := FValue;
end;

function TExpressionValue.AsInteger: Integer;
begin
  Result := Round(AsDouble);
end;

function TExpressionValue.AsInt64: Int64;
var
  LValue: Double;
begin
  LValue := AsDouble;
  if LValue >= 0 then
    Result := Trunc(LValue + 0.5)
  else
    Result := Trunc(LValue - 0.5);
end;

function TExpressionValue.AsBoolean: Boolean;
begin
  if VarIsNull(FValue) then
    Result := False
  else if VarIsStr(FValue) then
    Result := SameText(FValue, 'true') or (FValue = '1')
  else if VarIsNumeric(FValue) then
    Result := FValue <> 0
  else
    Result := FValue;
end;

function TExpressionValue.AsString: string;
begin
  if VarIsNull(FValue) then
    Result := ''
  else
    Result := VarToStr(FValue);
end;

function TExpressionValue.IsNull: Boolean;
begin
  Result := VarIsNull(FValue) or VarIsEmpty(FValue);
end;

function TExpressionValue.IsNumeric: Boolean;
begin
  Result := VarIsNumeric(FValue);
end;

function TExpressionValue.IsString: Boolean;
begin
  Result := VarIsStr(FValue);
end;

class function TExpressionValue.Null: TExpressionValue;
begin
  Result.FValue := System.Variants.Null;
end;

// ============================================================================
// TExpressionContext
// ============================================================================

constructor TExpressionContext.Create(AParent: TExpressionContext);
begin
  inherited Create;
  FParent := AParent;
  FVariables := TDictionary<string, TExpressionValue>.Create;
  FFunctions := TDictionary<string, TExpressionFunc>.Create;
  FCaseSensitive := False;
  RegisterBuiltInFunctions;
end;

destructor TExpressionContext.Destroy;
begin
  FreeAndNil(FVariables);
  FreeAndNil(FFunctions);
  inherited;
end;

function TExpressionContext.NormalizeName(const Name: string): string;
begin
  if FCaseSensitive then
    Result := Name
  else
    Result := LowerCase(Name);
end;

procedure TExpressionContext.RegisterBuiltInFunctions;
begin
  // Math functions
  RegisterFunction('abs', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Abs(Args[0].AsDouble);
    end);
  
  RegisterFunction('sqrt', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Sqrt(Args[0].AsDouble);
    end);
  
  RegisterFunction('sin', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Sin(Args[0].AsDouble);
    end);
  
  RegisterFunction('cos', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Cos(Args[0].AsDouble);
    end);
  
  RegisterFunction('tan', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Tan(Args[0].AsDouble);
    end);
  
  RegisterFunction('exp', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Exp(Args[0].AsDouble);
    end);
  
  RegisterFunction('ln', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Ln(Args[0].AsDouble);
    end);
  
  RegisterFunction('log', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Log10(Args[0].AsDouble);
    end);
  
  RegisterFunction('log2', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Log2(Args[0].AsDouble);
    end);
  
  RegisterFunction('floor', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Floor(Args[0].AsDouble);
    end);
  
  RegisterFunction('ceil', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Ceil(Args[0].AsDouble);
    end);
  
  RegisterFunction('round', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Round(Args[0].AsDouble);
    end);
  
  RegisterFunction('trunc', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Trunc(Args[0].AsDouble);
    end);
  
  RegisterFunction('min', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Min(Args[0].AsDouble, Args[1].AsDouble);
    end);
  
  RegisterFunction('max', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Max(Args[0].AsDouble, Args[1].AsDouble);
    end);
  
  RegisterFunction('pow', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Power(Args[0].AsDouble, Args[1].AsDouble);
    end);
  
  RegisterFunction('mod', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].AsInt64 mod Args[1].AsInt64;
    end);
  
  // String functions
  RegisterFunction('len', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Length(Args[0].AsString);
    end);
  
  RegisterFunction('upper', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := UpperCase(Args[0].AsString);
    end);
  
  RegisterFunction('lower', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := LowerCase(Args[0].AsString);
    end);
  
  RegisterFunction('trim', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Trim(Args[0].AsString);
    end);
  
  RegisterFunction('left', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := LeftStr(Args[0].AsString, Args[1].AsInteger);
    end);
  
  RegisterFunction('right', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := RightStr(Args[0].AsString, Args[1].AsInteger);
    end);
  
  RegisterFunction('substr', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      if Length(Args) >= 3 then
        Result := Copy(Args[0].AsString, Args[1].AsInteger, Args[2].AsInteger)
      else
        Result := Copy(Args[0].AsString, Args[1].AsInteger, MaxInt);
    end);
  
  RegisterFunction('concat', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    var
      S: string;
      I: Integer;
    begin
      S := '';
      for I := 0 to High(Args) do
        S := S + Args[I].AsString;
      Result := S;
    end);
  
  RegisterFunction('contains', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := ContainsText(Args[0].AsString, Args[1].AsString);
    end);
  
  RegisterFunction('replace', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := StringReplace(Args[0].AsString, Args[1].AsString, Args[2].AsString, [rfReplaceAll]);
    end);
  
  // Conditional functions
  RegisterFunction('if', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      if Args[0].AsBoolean then
        Result := Args[1]
      else if Length(Args) > 2 then
        Result := Args[2]
      else
        Result := TExpressionValue.Null;
    end);
  
  RegisterFunction('isnull', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].IsNull;
    end);
  
  RegisterFunction('coalesce', function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    var
      I: Integer;
    begin
      for I := 0 to High(Args) do
        if not Args[I].IsNull then
          Exit(Args[I]);
      Result := TExpressionValue.Null;
    end);
  
  // Constants
  SetVariable('pi', Pi);
  SetVariable('e', Exp(1));
  SetVariable('true', True);
  SetVariable('false', False);
  SetVariable('null', TExpressionValue.Null);
end;

procedure TExpressionContext.SetVariable(const Name: string; const Value: TExpressionValue);
begin
  FVariables.AddOrSetValue(NormalizeName(Name), Value);
end;

function TExpressionContext.GetVariable(const Name: string): TExpressionValue;
var
  NormalizedName: string;
begin
  NormalizedName := NormalizeName(Name);
  
  if FVariables.TryGetValue(NormalizedName, Result) then
    Exit;
  
  if Assigned(FParent) then
    Result := FParent.GetVariable(Name)
  else
    raise EExpressionError.Create(Format('Unknown variable: %s', [Name]), 0);
end;

function TExpressionContext.TryGetVariable(const Name: string;
  out Value: TExpressionValue): Boolean;
var
  NormalizedName: string;
begin
  NormalizedName := NormalizeName(Name);
  
  Result := FVariables.TryGetValue(NormalizedName, Value);
  
  if not Result and Assigned(FParent) then
    Result := FParent.TryGetVariable(Name, Value);
end;

function TExpressionContext.HasVariable(const Name: string): Boolean;
var
  V: TExpressionValue;
begin
  Result := TryGetVariable(Name, V);
end;

procedure TExpressionContext.ClearVariables;
begin
  FVariables.Clear;
end;

procedure TExpressionContext.RegisterFunction(const Name: string; Func: TExpressionFunc);
begin
  FFunctions.AddOrSetValue(NormalizeName(Name), Func);
end;

function TExpressionContext.GetFunction(const Name: string): TExpressionFunc;
var
  NormalizedName: string;
begin
  NormalizedName := NormalizeName(Name);
  
  if FFunctions.TryGetValue(NormalizedName, Result) then
    Exit;
  
  if Assigned(FParent) then
    Result := FParent.GetFunction(Name)
  else
    raise EExpressionError.Create(Format('Unknown function: %s', [Name]), 0);
end;

function TExpressionContext.HasFunction(const Name: string): Boolean;
var
  NormalizedName: string;
  F: TExpressionFunc;
begin
  NormalizedName := NormalizeName(Name);
  Result := FFunctions.TryGetValue(NormalizedName, F);
  
  if not Result and Assigned(FParent) then
    Result := FParent.HasFunction(Name);
end;

// ============================================================================
// AST Nodes
// ============================================================================

constructor TNumberNode.Create(AValue: Double);
begin
  inherited Create;
  FValue := AValue;
end;

function TNumberNode.Evaluate(Context: TExpressionContext): TExpressionValue;
begin
  Result := FValue;
end;

function TNumberNode.Clone: TASTNode;
begin
  Result := TNumberNode.Create(FValue);
end;

constructor TStringNode.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

function TStringNode.Evaluate(Context: TExpressionContext): TExpressionValue;
begin
  Result := FValue;
end;

function TStringNode.Clone: TASTNode;
begin
  Result := TStringNode.Create(FValue);
end;

constructor TBooleanNode.Create(AValue: Boolean);
begin
  inherited Create;
  FValue := AValue;
end;

function TBooleanNode.Evaluate(Context: TExpressionContext): TExpressionValue;
begin
  Result := FValue;
end;

function TBooleanNode.Clone: TASTNode;
begin
  Result := TBooleanNode.Create(FValue);
end;

constructor TVariableNode.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TVariableNode.Evaluate(Context: TExpressionContext): TExpressionValue;
begin
  Result := Context.GetVariable(FName);
end;

function TVariableNode.Clone: TASTNode;
begin
  Result := TVariableNode.Create(FName);
end;

constructor TBinaryOpNode.Create(const AOp: string; ALeft, ARight: TASTNode);
begin
  inherited Create;
  FOperator := AOp;
  FLeft := ALeft;
  FRight := ARight;
end;

destructor TBinaryOpNode.Destroy;
begin
  FreeAndNil(FLeft);
  FreeAndNil(FRight);
  inherited;
end;

function TBinaryOpNode.Evaluate(Context: TExpressionContext): TExpressionValue;
var
  L, R: TExpressionValue;
begin
  L := FLeft.Evaluate(Context);
  R := FRight.Evaluate(Context);
  
  if FOperator = '+' then
  begin
    if L.IsString or R.IsString then
      Result := L.AsString + R.AsString
    else
      Result := L.AsDouble + R.AsDouble;
  end
  else if FOperator = '-' then
    Result := L.AsDouble - R.AsDouble
  else if FOperator = '*' then
    Result := L.AsDouble * R.AsDouble
  else if FOperator = '/' then
    Result := L.AsDouble / R.AsDouble
  else if FOperator = '%' then
    Result := L.AsInt64 mod R.AsInt64
  else if FOperator = '^' then
    Result := Power(L.AsDouble, R.AsDouble)
  else if (FOperator = '=') or (FOperator = '==') then
    Result := L.AsString = R.AsString
  else if (FOperator = '<>') or (FOperator = '!=') then
    Result := L.AsString <> R.AsString
  else if FOperator = '<' then
    Result := L.AsDouble < R.AsDouble
  else if FOperator = '>' then
    Result := L.AsDouble > R.AsDouble
  else if FOperator = '<=' then
    Result := L.AsDouble <= R.AsDouble
  else if FOperator = '>=' then
    Result := L.AsDouble >= R.AsDouble
  else if SameText(FOperator, 'AND') or (FOperator = '&&') then
    Result := L.AsBoolean and R.AsBoolean
  else if SameText(FOperator, 'OR') or (FOperator = '||') then
    Result := L.AsBoolean or R.AsBoolean
  else if SameText(FOperator, 'XOR') then
    Result := L.AsBoolean xor R.AsBoolean
  else
    raise EExpressionError.Create(Format('Unknown operator: %s', [FOperator]), 0);
end;

function TBinaryOpNode.Clone: TASTNode;
begin
  Result := TBinaryOpNode.Create(FOperator, FLeft.Clone, FRight.Clone);
end;

constructor TUnaryOpNode.Create(const AOp: string; AOperand: TASTNode);
begin
  inherited Create;
  FOperator := AOp;
  FOperand := AOperand;
end;

destructor TUnaryOpNode.Destroy;
begin
  FreeAndNil(FOperand);
  inherited;
end;

function TUnaryOpNode.Evaluate(Context: TExpressionContext): TExpressionValue;
var
  V: TExpressionValue;
begin
  V := FOperand.Evaluate(Context);
  
  if FOperator = '-' then
    Result := -V.AsDouble
  else if FOperator = '+' then
    Result := V.AsDouble
  else if SameText(FOperator, 'NOT') or (FOperator = '!') then
    Result := not V.AsBoolean
  else
    raise EExpressionError.Create(Format('Unknown unary operator: %s', [FOperator]), 0);
end;

function TUnaryOpNode.Clone: TASTNode;
begin
  Result := TUnaryOpNode.Create(FOperator, FOperand.Clone);
end;

constructor TFunctionCallNode.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FArgs := TObjectList<TASTNode>.Create(True);
end;

destructor TFunctionCallNode.Destroy;
begin
  FreeAndNil(FArgs);
  inherited;
end;

procedure TFunctionCallNode.AddArg(Arg: TASTNode);
begin
  FArgs.Add(Arg);
end;

function TFunctionCallNode.Evaluate(Context: TExpressionContext): TExpressionValue;
var
  Func: TExpressionFunc;
  ArgValues: array of TExpressionValue;
  I: Integer;
begin
  Func := Context.GetFunction(FName);
  
  SetLength(ArgValues, FArgs.Count);
  for I := 0 to FArgs.Count - 1 do
    ArgValues[I] := FArgs[I].Evaluate(Context);
  
  Result := Func(ArgValues, Context);
end;

function TFunctionCallNode.Clone: TASTNode;
var
  NewNode: TFunctionCallNode;
  I: Integer;
begin
  NewNode := TFunctionCallNode.Create(FName);
  for I := 0 to FArgs.Count - 1 do
    NewNode.AddArg(FArgs[I].Clone);
  Result := NewNode;
end;

constructor TConditionalNode.Create(ACondition, ATrueExpr, AFalseExpr: TASTNode);
begin
  inherited Create;
  FCondition := ACondition;
  FTrueExpr := ATrueExpr;
  FFalseExpr := AFalseExpr;
end;

destructor TConditionalNode.Destroy;
begin
  FreeAndNil(FCondition);
  FreeAndNil(FTrueExpr);
  FreeAndNil(FFalseExpr);
  inherited;
end;

function TConditionalNode.Evaluate(Context: TExpressionContext): TExpressionValue;
begin
  if FCondition.Evaluate(Context).AsBoolean then
    Result := FTrueExpr.Evaluate(Context)
  else if Assigned(FFalseExpr) then
    Result := FFalseExpr.Evaluate(Context)
  else
    Result := TExpressionValue.Null;
end;

function TConditionalNode.Clone: TASTNode;
begin
  Result := TConditionalNode.Create(
    FCondition.Clone,
    FTrueExpr.Clone,
    FFalseExpr.Clone);
end;

// ============================================================================
// Lexer
// ============================================================================

constructor TExpressionLexer.Create(const AExpression: string);
begin
  inherited Create;
  FExpression := AExpression;
  FPosition := 1;
  if FExpression <> '' then
    FCurrentChar := FExpression[1]
  else
    FCurrentChar := #0;
end;

procedure TExpressionLexer.Advance;
begin
  Inc(FPosition);
  if FPosition <= Length(FExpression) then
    FCurrentChar := FExpression[FPosition]
  else
    FCurrentChar := #0;
end;

function TExpressionLexer.PeekChar: Char;
begin
  if FPosition + 1 <= Length(FExpression) then
    Result := FExpression[FPosition + 1]
  else
    Result := #0;
end;

procedure TExpressionLexer.SkipWhitespace;
begin
  while CharInSet(FCurrentChar, [' ', #9, #10, #13]) do
    Advance;
end;

function TExpressionLexer.ReadNumber: TToken;
var
  Start: Integer;
  S: string;
begin
  Result.TokenType := ttNumber;
  Result.Position := FPosition;
  Start := FPosition;
  
  while CharInSet(FCurrentChar, ['0'..'9']) do
    Advance;
  
  if FCurrentChar = '.' then
  begin
    Advance;
    while CharInSet(FCurrentChar, ['0'..'9']) do
      Advance;
  end;
  
  // Scientific notation
  if CharInSet(FCurrentChar, ['e', 'E']) then
  begin
    Advance;
    if CharInSet(FCurrentChar, ['+', '-']) then
      Advance;
    while CharInSet(FCurrentChar, ['0'..'9']) do
      Advance;
  end;
  
  S := Copy(FExpression, Start, FPosition - Start);
  Result.Value := S;
  Result.NumValue := StrToFloat(S);
end;

function TExpressionLexer.ReadString: TToken;
var
  Quote: Char;
  S: string;
begin
  Result.TokenType := ttString;
  Result.Position := FPosition;
  Quote := FCurrentChar;
  Advance; // Skip opening quote
  
  S := '';
  while (FCurrentChar <> #0) and (FCurrentChar <> Quote) do
  begin
    if FCurrentChar = '\' then
    begin
      Advance;
      case FCurrentChar of
        'n': S := S + #10;
        'r': S := S + #13;
        't': S := S + #9;
        '\': S := S + '\';
        '''': S := S + '''';
        '"': S := S + '"';
      else
        S := S + FCurrentChar;
      end;
    end
    else
      S := S + FCurrentChar;
    Advance;
  end;
  
  if FCurrentChar = Quote then
    Advance; // Skip closing quote
  
  Result.Value := S;
end;

function TExpressionLexer.ReadIdentifier: TToken;
var
  Start: Integer;
  S: string;
begin
  Result.Position := FPosition;
  Start := FPosition;
  
  while CharInSet(FCurrentChar, ['a'..'z', 'A'..'Z', '0'..'9', '_']) do
    Advance;
  
  S := Copy(FExpression, Start, FPosition - Start);
  Result.Value := S;
  
  if SameText(S, 'AND') or SameText(S, 'OR') or SameText(S, 'NOT') or
     SameText(S, 'XOR') or SameText(S, 'TRUE') or SameText(S, 'FALSE') then
    Result.TokenType := ttOperator
  else
    Result.TokenType := ttIdentifier;
end;

function TExpressionLexer.ReadOperator: TToken;
begin
  Result.Position := FPosition;
  Result.TokenType := ttOperator;
  
  case FCurrentChar of
    '+', '-', '*', '/', '%', '^':
    begin
      Result.Value := FCurrentChar;
      Advance;
    end;
    
    '=':
    begin
      Advance;
      if FCurrentChar = '=' then
      begin
        Result.Value := '==';
        Advance;
      end
      else
        Result.Value := '=';
    end;
    
    '<':
    begin
      Advance;
      if FCurrentChar = '=' then
      begin
        Result.Value := '<=';
        Advance;
      end
      else if FCurrentChar = '>' then
      begin
        Result.Value := '<>';
        Advance;
      end
      else
        Result.Value := '<';
    end;
    
    '>':
    begin
      Advance;
      if FCurrentChar = '=' then
      begin
        Result.Value := '>=';
        Advance;
      end
      else
        Result.Value := '>';
    end;
    
    '!':
    begin
      Advance;
      if FCurrentChar = '=' then
      begin
        Result.Value := '!=';
        Advance;
      end
      else
        Result.Value := '!';
    end;
    
    '&':
    begin
      Advance;
      if FCurrentChar = '&' then
      begin
        Result.Value := '&&';
        Advance;
      end
      else
        Result.Value := '&';
    end;
    
    '|':
    begin
      Advance;
      if FCurrentChar = '|' then
      begin
        Result.Value := '||';
        Advance;
      end
      else
        Result.Value := '|';
    end;
  end;
end;

function TExpressionLexer.GetNextToken: TToken;
begin
  SkipWhitespace;
  
  if FCurrentChar = #0 then
  begin
    Result.TokenType := ttEOF;
    Result.Position := FPosition;
    Exit;
  end;
  
  if CharInSet(FCurrentChar, ['0'..'9']) then
    Exit(ReadNumber);
  
  if CharInSet(FCurrentChar, ['''', '"']) then
    Exit(ReadString);
  
  if CharInSet(FCurrentChar, ['a'..'z', 'A'..'Z', '_']) then
    Exit(ReadIdentifier);
  
  if FCurrentChar = '(' then
  begin
    Result.TokenType := ttLeftParen;
    Result.Position := FPosition;
    Result.Value := '(';
    Advance;
    Exit;
  end;
  
  if FCurrentChar = ')' then
  begin
    Result.TokenType := ttRightParen;
    Result.Position := FPosition;
    Result.Value := ')';
    Advance;
    Exit;
  end;
  
  if FCurrentChar = ',' then
  begin
    Result.TokenType := ttComma;
    Result.Position := FPosition;
    Result.Value := ',';
    Advance;
    Exit;
  end;
  
  if CharInSet(FCurrentChar, ['+', '-', '*', '/', '%', '^', '=', '<', '>', '!', '&', '|']) then
    Exit(ReadOperator);
  
  raise EExpressionError.Create(Format('Unexpected character: %s', [FCurrentChar]), FPosition);
end;

// ============================================================================
// Parser
// ============================================================================

constructor EExpressionError.Create(const AMessage: string; APosition: Integer);
begin
  inherited Create(AMessage);
  FPosition := APosition;
end;

constructor TExpressionParser.Create(const Expression: string);
begin
  inherited Create;
  FLexer := TExpressionLexer.Create(Expression);
  FCurrentToken := FLexer.GetNextToken;
end;

destructor TExpressionParser.Destroy;
begin
  FreeAndNil(FLexer);
  inherited;
end;

procedure TExpressionParser.Consume(TokenType: TTokenType);
begin
  if FCurrentToken.TokenType <> TokenType then
    raise EExpressionError.Create(Format('Unexpected token: %s', [FCurrentToken.Value]),
      FCurrentToken.Position);
  FCurrentToken := FLexer.GetNextToken;
end;

function TExpressionParser.Parse: TASTNode;
begin
  Result := ParseExpression;
  if FCurrentToken.TokenType <> ttEOF then
    raise EExpressionError.Create('Unexpected token after expression', FCurrentToken.Position);
end;

function TExpressionParser.ParseExpression: TASTNode;
begin
  Result := ParseOr;
end;

function TExpressionParser.ParseOr: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseXor;
  
  while (FCurrentToken.TokenType = ttOperator) and
        (SameText(FCurrentToken.Value, 'OR') or (FCurrentToken.Value = '||')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseXor);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseXor: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseAnd;
  
  while (FCurrentToken.TokenType = ttOperator) and SameText(FCurrentToken.Value, 'XOR') do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseAnd);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseAnd: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseEquality;
  
  while (FCurrentToken.TokenType = ttOperator) and
        (SameText(FCurrentToken.Value, 'AND') or (FCurrentToken.Value = '&&')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseEquality);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseEquality: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseComparison;
  
  while (FCurrentToken.TokenType = ttOperator) and
        ((FCurrentToken.Value = '=') or (FCurrentToken.Value = '==') or
         (FCurrentToken.Value = '<>') or (FCurrentToken.Value = '!=')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseComparison);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseComparison: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseAdditive;
  
  while (FCurrentToken.TokenType = ttOperator) and
        ((FCurrentToken.Value = '<') or (FCurrentToken.Value = '>') or
         (FCurrentToken.Value = '<=') or (FCurrentToken.Value = '>=')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseAdditive);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseAdditive: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParseMultiplicative;
  
  while (FCurrentToken.TokenType = ttOperator) and
        ((FCurrentToken.Value = '+') or (FCurrentToken.Value = '-')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParseMultiplicative);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseMultiplicative: TASTNode;
var
  Op: string;
  LLeft: TASTNode;
begin
  Result := ParsePower;
  
  while (FCurrentToken.TokenType = ttOperator) and
        ((FCurrentToken.Value = '*') or (FCurrentToken.Value = '/') or
         (FCurrentToken.Value = '%')) do
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create(Op, LLeft, ParsePower);
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParsePower: TASTNode;
var
  LLeft: TASTNode;
begin
  Result := ParseUnary;
  
  if (FCurrentToken.TokenType = ttOperator) and (FCurrentToken.Value = '^') then
  begin
    Consume(ttOperator);
    LLeft := Result;
    try
      Result := TBinaryOpNode.Create('^', LLeft, ParsePower); // Right associative
    except
      LLeft.Free;
      raise;
    end;
  end;
end;

function TExpressionParser.ParseUnary: TASTNode;
var
  Op: string;
  LOperand: TASTNode;
begin
  if (FCurrentToken.TokenType = ttOperator) and
     ((FCurrentToken.Value = '-') or (FCurrentToken.Value = '+') or
      (FCurrentToken.Value = '!') or SameText(FCurrentToken.Value, 'NOT')) then
  begin
    Op := FCurrentToken.Value;
    Consume(ttOperator);
    LOperand := ParseUnary;
    try
      Result := TUnaryOpNode.Create(Op, LOperand);
    except
      LOperand.Free;
      raise;
    end;
  end
  else
    Result := ParsePrimary;
end;

function TExpressionParser.ParsePrimary: TASTNode;
var
  Name: string;
  LNumber: Double;
  LString: string;
begin
  case FCurrentToken.TokenType of
    ttNumber:
    begin
      LNumber := FCurrentToken.NumValue;
      Consume(ttNumber);
      Result := TNumberNode.Create(LNumber);
    end;
    
    ttString:
    begin
      LString := FCurrentToken.Value;
      Consume(ttString);
      Result := TStringNode.Create(LString);
    end;
    
    ttIdentifier:
    begin
      Name := FCurrentToken.Value;
      Consume(ttIdentifier);
      
      if FCurrentToken.TokenType = ttLeftParen then
        Result := ParseFunctionCall(Name)
      else if SameText(Name, 'true') then
        Result := TBooleanNode.Create(True)
      else if SameText(Name, 'false') then
        Result := TBooleanNode.Create(False)
      else
        Result := TVariableNode.Create(Name);
    end;
    
    ttOperator:
    begin
      if SameText(FCurrentToken.Value, 'TRUE') then
      begin
        Consume(ttOperator);
        Result := TBooleanNode.Create(True);
      end
      else if SameText(FCurrentToken.Value, 'FALSE') then
      begin
        Consume(ttOperator);
        Result := TBooleanNode.Create(False);
      end
      else
        raise EExpressionError.Create('Unexpected operator', FCurrentToken.Position);
    end;
    
    ttLeftParen:
    begin
      Consume(ttLeftParen);
      Result := ParseExpression;
      try
        Consume(ttRightParen);
      except
        Result.Free;
        raise;
      end;
    end;
  else
    raise EExpressionError.Create('Unexpected token', FCurrentToken.Position);
  end;
end;

function TExpressionParser.ParseFunctionCall(const Name: string): TASTNode;
var
  FuncNode: TFunctionCallNode;
begin
  FuncNode := TFunctionCallNode.Create(Name);
  try
    Consume(ttLeftParen);
    
    if FCurrentToken.TokenType <> ttRightParen then
    begin
      FuncNode.AddArg(ParseExpression);
      
      while FCurrentToken.TokenType = ttComma do
      begin
        Consume(ttComma);
        FuncNode.AddArg(ParseExpression);
      end;
    end;
    
    Consume(ttRightParen);
    Result := FuncNode;
  except
    FuncNode.Free;
    raise;
  end;
end;

// ============================================================================
// TCompiledExpression
// ============================================================================

constructor TCompiledExpression.Create(const AExpression: string);
var
  Parser: TExpressionParser;
begin
  inherited Create;
  FExpression := AExpression;
  Parser := TExpressionParser.Create(AExpression);
  try
    FAST := Parser.Parse;
  finally
    Parser.Free;
  end;
end;

destructor TCompiledExpression.Destroy;
begin
  FreeAndNil(FAST);
  inherited;
end;

function TCompiledExpression.Evaluate(Context: TExpressionContext): TExpressionValue;
var
  ActualContext: TExpressionContext;
begin
  if Assigned(Context) then
    ActualContext := Context
  else
    ActualContext := TExpression.GlobalContext;
  
  Result := FAST.Evaluate(ActualContext);
end;

function TCompiledExpression.Clone: TCompiledExpression;
begin
  Result := TCompiledExpression.Create(FExpression);
end;

// ============================================================================
// TExpression
// ============================================================================

class constructor TExpression.Create;
begin
  FCache := TDictionary<string, TCompiledExpression>.Create;
  FCacheLock := TObject.Create;
  FGlobalContext := TExpressionContext.Create;
end;

class destructor TExpression.Destroy;
begin
  ClearCache;
  FreeAndNil(FCache);
  FreeAndNil(FCacheLock);
  FreeAndNil(FGlobalContext);
end;

class function TExpression.Evaluate(const Expression: string;
  Context: TExpressionContext): TExpressionValue;
var
  Compiled: TCompiledExpression;
begin
  Compiled := CompileCached(Expression);
  Result := Compiled.Evaluate(Context);
end;

class function TExpression.Compile(const Expression: string): TCompiledExpression;
begin
  Result := TCompiledExpression.Create(Expression);
end;

class function TExpression.CompileCached(const Expression: string): TCompiledExpression;
begin
  TMonitor.Enter(FCacheLock);
  try
    if not FCache.TryGetValue(Expression, Result) then
    begin
      Result := TCompiledExpression.Create(Expression);
      FCache.Add(Expression, Result);
    end;
  finally
    TMonitor.Exit(FCacheLock);
  end;
end;

class procedure TExpression.ClearCache;
var
  Pair: TPair<string, TCompiledExpression>;
begin
  TMonitor.Enter(FCacheLock);
  try
    for Pair in FCache do
      Pair.Value.Free;
    FCache.Clear;
  finally
    TMonitor.Exit(FCacheLock);
  end;
end;

class procedure TExpression.EnableCache(Enable: Boolean);
begin
  if not Enable then
    ClearCache;
end;

end.
