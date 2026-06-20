/// <summary>
/// Unit tests for DeepBase.Expression module
/// Tests: TExpressionValue, TExpressionContext, TExpression, TCompiledExpression,
///        Math/String/Logic operations, Built-in functions, Error handling
/// </summary>
unit Test.DeepBase.Expression;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  System.Math,
  DUnitX.TestFramework,
  DeepBase.Expression;

type
  /// <summary>
  /// Tests for TExpressionValue
  /// </summary>
  [TestFixture]
  TExpressionValueTests = class
  public
    // Implicit conversion tests
    [Test]
    procedure Test_Implicit_FromDouble;
    [Test]
    procedure Test_Implicit_FromInteger;
    [Test]
    procedure Test_Implicit_FromInt64;
    [Test]
    procedure Test_Implicit_FromBoolean;
    [Test]
    procedure Test_Implicit_FromString;
    [Test]
    procedure Test_Implicit_ToDouble;
    [Test]
    procedure Test_Implicit_ToBoolean;
    [Test]
    procedure Test_Implicit_ToString;

    // AsXxx conversion tests
    [Test]
    procedure Test_AsDouble;
    [Test]
    procedure Test_AsDouble_FromString;
    [Test]
    procedure Test_AsDouble_FromNull;
    [Test]
    procedure Test_AsInteger;
    [Test]
    procedure Test_AsInt64;
    [Test]
    procedure Test_AsBoolean_FromTrue;
    [Test]
    procedure Test_AsBoolean_FromFalse;
    [Test]
    procedure Test_AsBoolean_FromString;
    [Test]
    procedure Test_AsBoolean_FromNumber;
    [Test]
    procedure Test_AsBoolean_FromNull;
    [Test]
    procedure Test_AsString;
    [Test]
    procedure Test_AsString_FromNull;

    // Type check tests
    [Test]
    procedure Test_IsNull;
    [Test]
    procedure Test_IsNumeric;
    [Test]
    procedure Test_IsString;
    [Test]
    procedure Test_Null_StaticMethod;
  end;

  /// <summary>
  /// Tests for TExpressionContext
  /// </summary>
  [TestFixture]
  TExpressionContextTests = class
  private
    FContext: TExpressionContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // Variable tests
    [Test]
    procedure Test_SetVariable_GetVariable;
    [Test]
    procedure Test_SetVariable_Overwrite;
    [Test]
    procedure Test_TryGetVariable_Exists;
    [Test]
    procedure Test_TryGetVariable_NotExists;
    [Test]
    procedure Test_HasVariable_True;
    [Test]
    procedure Test_HasVariable_False;
    [Test]
    procedure Test_ClearVariables;
    [Test]
    procedure Test_GetVariable_NotFound_RaisesException;

    // Function tests
    [Test]
    procedure Test_RegisterFunction;
    [Test]
    procedure Test_GetFunction;
    [Test]
    procedure Test_HasFunction_BuiltIn;
    [Test]
    procedure Test_HasFunction_Custom;
    [Test]
    procedure Test_HasFunction_NotExists;

    // Case sensitivity tests
    [Test]
    procedure Test_CaseInsensitive_Default;
    [Test]
    procedure Test_CaseSensitive_Variables;

    // Parent context tests
    [Test]
    procedure Test_ParentContext_Variables;
    [Test]
    procedure Test_ParentContext_Functions;

    // Built-in constants tests
    [Test]
    procedure Test_BuiltIn_Pi;
    [Test]
    procedure Test_BuiltIn_E;
    [Test]
    procedure Test_BuiltIn_True;
    [Test]
    procedure Test_BuiltIn_False;
  end;

  /// <summary>
  /// Tests for TExpression - Math operations
  /// </summary>
  [TestFixture]
  TExpressionMathTests = class
  public
    // Basic arithmetic
    [Test]
    procedure Test_Addition;
    [Test]
    procedure Test_Subtraction;
    [Test]
    procedure Test_Multiplication;
    [Test]
    procedure Test_Division;
    [Test]
    procedure Test_Modulo;
    [Test]
    procedure Test_Power;
    [Test]
    procedure Test_Negation;
    [Test]
    procedure Test_UnaryPlus;

    // Order of operations
    [Test]
    procedure Test_OrderOfOperations_AddMul;
    [Test]
    procedure Test_OrderOfOperations_Parentheses;
    [Test]
    procedure Test_OrderOfOperations_Complex;

    // Decimal numbers
    [Test]
    procedure Test_DecimalNumbers;
    [Test]
    procedure Test_ScientificNotation;

    // Built-in math functions
    [Test]
    procedure Test_Func_Abs;
    [Test]
    procedure Test_Func_Sqrt;
    [Test]
    procedure Test_Func_Sin;
    [Test]
    procedure Test_Func_Cos;
    [Test]
    procedure Test_Func_Tan;
    [Test]
    procedure Test_Func_Exp;
    [Test]
    procedure Test_Func_Ln;
    [Test]
    procedure Test_Func_Log;
    [Test]
    procedure Test_Func_Log2;
    [Test]
    procedure Test_Func_Floor;
    [Test]
    procedure Test_Func_Ceil;
    [Test]
    procedure Test_Func_Round;
    [Test]
    procedure Test_Func_Trunc;
    [Test]
    procedure Test_Func_Min;
    [Test]
    procedure Test_Func_Max;
    [Test]
    procedure Test_Func_Pow;
    [Test]
    procedure Test_Func_Mod;
  end;

  /// <summary>
  /// Tests for TExpression - String operations
  /// </summary>
  [TestFixture]
  TExpressionStringTests = class
  public
    // String literals
    [Test]
    procedure Test_StringLiteral_DoubleQuotes;
    [Test]
    procedure Test_StringLiteral_SingleQuotes;
    [Test]
    procedure Test_StringLiteral_EscapeSequences;

    // String concatenation
    [Test]
    procedure Test_StringConcat_PlusOperator;
    [Test]
    procedure Test_StringConcat_Function;

    // Built-in string functions
    [Test]
    procedure Test_Func_Len;
    [Test]
    procedure Test_Func_Upper;
    [Test]
    procedure Test_Func_Lower;
    [Test]
    procedure Test_Func_Trim;
    [Test]
    procedure Test_Func_Left;
    [Test]
    procedure Test_Func_Right;
    [Test]
    procedure Test_Func_Substr_TwoArgs;
    [Test]
    procedure Test_Func_Substr_ThreeArgs;
    [Test]
    procedure Test_Func_Contains;
    [Test]
    procedure Test_Func_Replace;
  end;

  /// <summary>
  /// Tests for TExpression - Comparison operations
  /// </summary>
  [TestFixture]
  TExpressionComparisonTests = class
  public
    [Test]
    procedure Test_Equal;
    [Test]
    procedure Test_Equal_DoubleEquals;
    [Test]
    procedure Test_NotEqual;
    [Test]
    procedure Test_NotEqual_BangEquals;
    [Test]
    procedure Test_LessThan;
    [Test]
    procedure Test_GreaterThan;
    [Test]
    procedure Test_LessThanOrEqual;
    [Test]
    procedure Test_GreaterThanOrEqual;
    [Test]
    procedure Test_StringComparison;
  end;

  /// <summary>
  /// Tests for TExpression - Logical operations
  /// </summary>
  [TestFixture]
  TExpressionLogicTests = class
  public
    [Test]
    procedure Test_And_TrueTrue;
    [Test]
    procedure Test_And_TrueFalse;
    [Test]
    procedure Test_And_Operator;
    [Test]
    procedure Test_Or_TrueTrue;
    [Test]
    procedure Test_Or_FalseFalse;
    [Test]
    procedure Test_Or_Operator;
    [Test]
    procedure Test_Not;
    [Test]
    procedure Test_Not_Operator;
    [Test]
    procedure Test_Xor;
    [Test]
    procedure Test_Complex_LogicalExpression;
  end;

  /// <summary>
  /// Tests for TExpression - Variables
  /// </summary>
  [TestFixture]
  TExpressionVariableTests = class
  private
    FContext: TExpressionContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SimpleVariable;
    [Test]
    procedure Test_MultipleVariables;
    [Test]
    procedure Test_VariableInExpression;
    [Test]
    procedure Test_VariableOverwrite;
    [Test]
    procedure Test_UndefinedVariable_RaisesException;
    [Test]
    procedure Test_CaseInsensitiveVariables;
  end;

  /// <summary>
  /// Tests for TExpression - Conditional functions
  /// </summary>
  [TestFixture]
  TExpressionConditionalTests = class
  public
    [Test]
    procedure Test_If_True;
    [Test]
    procedure Test_If_False;
    [Test]
    procedure Test_If_WithoutElse;
    [Test]
    procedure Test_IsNull_True;
    [Test]
    procedure Test_IsNull_False;
    [Test]
    procedure Test_Coalesce_FirstNonNull;
    [Test]
    procedure Test_Coalesce_AllNull;
  end;

  /// <summary>
  /// Tests for TCompiledExpression
  /// </summary>
  [TestFixture]
  TCompiledExpressionTests = class
  private
    FContext: TExpressionContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Compile_SimpleExpression;
    [Test]
    procedure Test_Compile_ReusableExpression;
    [Test]
    procedure Test_Compile_WithVariables;
    [Test]
    procedure Test_Clone;
    [Test]
    procedure Test_Expression_Property;
  end;

  /// <summary>
  /// Tests for TExpression static methods
  /// </summary>
  [TestFixture]
  TExpressionStaticTests = class
  public
    [Test]
    procedure Test_Evaluate_NoContext;
    [Test]
    procedure Test_Evaluate_WithContext;
    [Test]
    procedure Test_Compile;
    [Test]
    procedure Test_GlobalContext;
    [Test]
    procedure Test_ClearCache;
  end;

  /// <summary>
  /// Tests for EExpressionError
  /// </summary>
  [TestFixture]
  TExpressionErrorTests = class
  public
    [Test]
    procedure Test_SyntaxError_UnknownOperator;
    [Test]
    procedure Test_Error_UnknownVariable;
    [Test]
    procedure Test_Error_UnknownFunction;
    [Test]
    procedure Test_Error_Position;
  end;

  /// <summary>
  /// Tests for custom functions
  /// </summary>
  [TestFixture]
  TExpressionCustomFunctionTests = class
  private
    FContext: TExpressionContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_CustomFunction_NoArgs;
    [Test]
    procedure Test_CustomFunction_SingleArg;
    [Test]
    procedure Test_CustomFunction_MultipleArgs;
    [Test]
    procedure Test_CustomFunction_UsingContext;
  end;

implementation

// ============================================================================
// TExpressionValueTests
// ============================================================================

procedure TExpressionValueTests.Test_Implicit_FromDouble;
var
  V: TExpressionValue;
begin
  V := Double(3.14);
  Assert.AreEqual(3.14, V.AsDouble, 0.001);
end;

procedure TExpressionValueTests.Test_Implicit_FromInteger;
var
  V: TExpressionValue;
begin
  V := Integer(42);
  Assert.AreEqual(42, V.AsInteger);
end;

procedure TExpressionValueTests.Test_Implicit_FromInt64;
var
  V: TExpressionValue;
begin
  V := Int64(9876543210);
  Assert.AreEqual(Int64(9876543210), V.AsInt64);
end;

procedure TExpressionValueTests.Test_Implicit_FromBoolean;
var
  V: TExpressionValue;
begin
  V := True;
  Assert.IsTrue(V.AsBoolean);
end;

procedure TExpressionValueTests.Test_Implicit_FromString;
var
  V: TExpressionValue;
begin
  V := 'Hello';
  Assert.AreEqual('Hello', V.AsString);
end;

procedure TExpressionValueTests.Test_Implicit_ToDouble;
var
  V: TExpressionValue;
  D: Double;
begin
  V := 3.14;
  D := V;
  Assert.AreEqual(3.14, D, 0.001);
end;

procedure TExpressionValueTests.Test_Implicit_ToBoolean;
var
  V: TExpressionValue;
  B: Boolean;
begin
  V := True;
  B := V;
  Assert.IsTrue(B);
end;

procedure TExpressionValueTests.Test_Implicit_ToString;
var
  V: TExpressionValue;
  S: string;
begin
  V := 'Test';
  S := V;
  Assert.AreEqual('Test', S);
end;

procedure TExpressionValueTests.Test_AsDouble;
var
  V: TExpressionValue;
begin
  V := 123.456;
  Assert.AreEqual(123.456, V.AsDouble, 0.001);
end;

procedure TExpressionValueTests.Test_AsDouble_FromString;
var
  V: TExpressionValue;
begin
  V := '42.5';
  Assert.AreEqual(42.5, V.AsDouble, 0.001);
end;

procedure TExpressionValueTests.Test_AsDouble_FromNull;
var
  V: TExpressionValue;
begin
  V := TExpressionValue.Null;
  Assert.AreEqual(Double(0), V.AsDouble, 0.001);
end;

procedure TExpressionValueTests.Test_AsInteger;
var
  V: TExpressionValue;
begin
  V := 42.7;
  Assert.AreEqual(43, V.AsInteger); // Round
end;

procedure TExpressionValueTests.Test_AsInt64;
var
  V: TExpressionValue;
begin
  V := 9876543210.5;
  Assert.AreEqual(Int64(9876543211), V.AsInt64); // Round
end;

procedure TExpressionValueTests.Test_AsBoolean_FromTrue;
var
  V: TExpressionValue;
begin
  V := True;
  Assert.IsTrue(V.AsBoolean);
end;

procedure TExpressionValueTests.Test_AsBoolean_FromFalse;
var
  V: TExpressionValue;
begin
  V := False;
  Assert.IsFalse(V.AsBoolean);
end;

procedure TExpressionValueTests.Test_AsBoolean_FromString;
var
  V1, V2, V3: TExpressionValue;
begin
  V1 := 'true';
  V2 := 'TRUE';
  V3 := '1';
  Assert.IsTrue(V1.AsBoolean);
  Assert.IsTrue(V2.AsBoolean);
  Assert.IsTrue(V3.AsBoolean);
end;

procedure TExpressionValueTests.Test_AsBoolean_FromNumber;
var
  V1, V2: TExpressionValue;
begin
  V1 := 1;
  V2 := 0;
  Assert.IsTrue(V1.AsBoolean);
  Assert.IsFalse(V2.AsBoolean);
end;

procedure TExpressionValueTests.Test_AsBoolean_FromNull;
var
  V: TExpressionValue;
begin
  V := TExpressionValue.Null;
  Assert.IsFalse(V.AsBoolean);
end;

procedure TExpressionValueTests.Test_AsString;
var
  V: TExpressionValue;
begin
  V := 42;
  Assert.AreEqual('42', V.AsString);
end;

procedure TExpressionValueTests.Test_AsString_FromNull;
var
  V: TExpressionValue;
begin
  V := TExpressionValue.Null;
  Assert.AreEqual('', V.AsString);
end;

procedure TExpressionValueTests.Test_IsNull;
var
  V1, V2: TExpressionValue;
begin
  V1 := TExpressionValue.Null;
  V2 := 42;
  Assert.IsTrue(V1.IsNull);
  Assert.IsFalse(V2.IsNull);
end;

procedure TExpressionValueTests.Test_IsNumeric;
var
  V1, V2: TExpressionValue;
begin
  V1 := 42;
  V2 := 'test';
  Assert.IsTrue(V1.IsNumeric);
  Assert.IsFalse(V2.IsNumeric);
end;

procedure TExpressionValueTests.Test_IsString;
var
  V1, V2: TExpressionValue;
begin
  V1 := 'test';
  V2 := 42;
  Assert.IsTrue(V1.IsString);
  Assert.IsFalse(V2.IsString);
end;

procedure TExpressionValueTests.Test_Null_StaticMethod;
var
  V: TExpressionValue;
begin
  V := TExpressionValue.Null;
  Assert.IsTrue(V.IsNull);
end;

// ============================================================================
// TExpressionContextTests
// ============================================================================

procedure TExpressionContextTests.Setup;
begin
  FContext := TExpressionContext.Create;
end;

procedure TExpressionContextTests.TearDown;
begin
  FContext.Free;
end;

procedure TExpressionContextTests.Test_SetVariable_GetVariable;
begin
  FContext.SetVariable('x', 42);
  Assert.AreEqual(42, FContext.GetVariable('x').AsInteger);
end;

procedure TExpressionContextTests.Test_SetVariable_Overwrite;
begin
  FContext.SetVariable('x', 10);
  FContext.SetVariable('x', 20);
  Assert.AreEqual(20, FContext.GetVariable('x').AsInteger);
end;

procedure TExpressionContextTests.Test_TryGetVariable_Exists;
var
  Value: TExpressionValue;
begin
  FContext.SetVariable('x', 42);
  Assert.IsTrue(FContext.TryGetVariable('x', Value));
  Assert.AreEqual(42, Value.AsInteger);
end;

procedure TExpressionContextTests.Test_TryGetVariable_NotExists;
var
  Value: TExpressionValue;
begin
  Assert.IsFalse(FContext.TryGetVariable('nonexistent', Value));
end;

procedure TExpressionContextTests.Test_HasVariable_True;
begin
  FContext.SetVariable('x', 42);
  Assert.IsTrue(FContext.HasVariable('x'));
end;

procedure TExpressionContextTests.Test_HasVariable_False;
begin
  Assert.IsFalse(FContext.HasVariable('nonexistent'));
end;

procedure TExpressionContextTests.Test_ClearVariables;
begin
  FContext.SetVariable('x', 42);
  FContext.ClearVariables;
  Assert.IsFalse(FContext.HasVariable('x'));
end;

procedure TExpressionContextTests.Test_GetVariable_NotFound_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FContext.GetVariable('nonexistent');
    end, EExpressionError);
end;

procedure TExpressionContextTests.Test_RegisterFunction;
begin
  FContext.RegisterFunction('double',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].AsDouble * 2;
    end);
  Assert.IsTrue(FContext.HasFunction('double'));
end;

procedure TExpressionContextTests.Test_GetFunction;
var
  Func: TExpressionFunc;
  Args: array of TExpressionValue;
begin
  FContext.RegisterFunction('triple',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].AsDouble * 3;
    end);

  Func := FContext.GetFunction('triple');
  SetLength(Args, 1);
  Args[0] := 10;
  Assert.AreEqual(Double(30), Func(Args, FContext).AsDouble, 0.001);
end;

procedure TExpressionContextTests.Test_HasFunction_BuiltIn;
begin
  Assert.IsTrue(FContext.HasFunction('sin'));
  Assert.IsTrue(FContext.HasFunction('cos'));
  Assert.IsTrue(FContext.HasFunction('abs'));
end;

procedure TExpressionContextTests.Test_HasFunction_Custom;
begin
  FContext.RegisterFunction('myFunc',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := 0;
    end);
  Assert.IsTrue(FContext.HasFunction('myFunc'));
end;

procedure TExpressionContextTests.Test_HasFunction_NotExists;
begin
  Assert.IsFalse(FContext.HasFunction('nonexistent'));
end;

procedure TExpressionContextTests.Test_CaseInsensitive_Default;
begin
  FContext.SetVariable('MyVar', 42);
  Assert.AreEqual(42, FContext.GetVariable('myvar').AsInteger);
  Assert.AreEqual(42, FContext.GetVariable('MYVAR').AsInteger);
end;

procedure TExpressionContextTests.Test_CaseSensitive_Variables;
begin
  FContext.CaseSensitive := True;
  FContext.SetVariable('MyVar', 42);
  Assert.IsTrue(FContext.HasVariable('MyVar'));
  Assert.IsFalse(FContext.HasVariable('myvar'));
end;

procedure TExpressionContextTests.Test_ParentContext_Variables;
var
  ParentCtx, ChildCtx: TExpressionContext;
begin
  ParentCtx := TExpressionContext.Create;
  ChildCtx := TExpressionContext.Create(ParentCtx);
  try
    ParentCtx.SetVariable('parentVar', 100);
    Assert.AreEqual(100, ChildCtx.GetVariable('parentVar').AsInteger);
  finally
    ChildCtx.Free;
    ParentCtx.Free;
  end;
end;

procedure TExpressionContextTests.Test_ParentContext_Functions;
var
  ParentCtx, ChildCtx: TExpressionContext;
begin
  ParentCtx := TExpressionContext.Create;
  ChildCtx := TExpressionContext.Create(ParentCtx);
  try
    ParentCtx.RegisterFunction('parentFunc',
      function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
      begin
        Result := 999;
      end);
    Assert.IsTrue(ChildCtx.HasFunction('parentFunc'));
  finally
    ChildCtx.Free;
    ParentCtx.Free;
  end;
end;

procedure TExpressionContextTests.Test_BuiltIn_Pi;
begin
  Assert.AreEqual(Pi, FContext.GetVariable('pi').AsDouble, 0.00001);
end;

procedure TExpressionContextTests.Test_BuiltIn_E;
begin
  Assert.AreEqual(Exp(1), FContext.GetVariable('e').AsDouble, 0.00001);
end;

procedure TExpressionContextTests.Test_BuiltIn_True;
begin
  Assert.IsTrue(FContext.GetVariable('true').AsBoolean);
end;

procedure TExpressionContextTests.Test_BuiltIn_False;
begin
  Assert.IsFalse(FContext.GetVariable('false').AsBoolean);
end;

// ============================================================================
// TExpressionMathTests
// ============================================================================

procedure TExpressionMathTests.Test_Addition;
begin
  Assert.AreEqual(Double(5), TExpression.Evaluate('2 + 3').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Subtraction;
begin
  Assert.AreEqual(Double(7), TExpression.Evaluate('10 - 3').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Multiplication;
begin
  Assert.AreEqual(Double(24), TExpression.Evaluate('6 * 4').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Division;
begin
  Assert.AreEqual(Double(5), TExpression.Evaluate('20 / 4').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Modulo;
begin
  Assert.AreEqual(Double(1), TExpression.Evaluate('10 % 3').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Power;
begin
  Assert.AreEqual(Double(8), TExpression.Evaluate('2 ^ 3').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Negation;
begin
  Assert.AreEqual(Double(-5), TExpression.Evaluate('-5').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_UnaryPlus;
begin
  Assert.AreEqual(Double(5), TExpression.Evaluate('+5').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_OrderOfOperations_AddMul;
begin
  // 2 + 3 * 4 = 2 + 12 = 14
  Assert.AreEqual(Double(14), TExpression.Evaluate('2 + 3 * 4').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_OrderOfOperations_Parentheses;
begin
  // (2 + 3) * 4 = 5 * 4 = 20
  Assert.AreEqual(Double(20), TExpression.Evaluate('(2 + 3) * 4').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_OrderOfOperations_Complex;
begin
  // 2 + 3 * 4 - 5 / 5 = 2 + 12 - 1 = 13
  Assert.AreEqual(Double(13), TExpression.Evaluate('2 + 3 * 4 - 5 / 5').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_DecimalNumbers;
begin
  Assert.AreEqual(Double(4.6), TExpression.Evaluate('1.5 + 3.1').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_ScientificNotation;
begin
  Assert.AreEqual(Double(1500), TExpression.Evaluate('1.5e3').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Abs;
begin
  Assert.AreEqual(Double(5), TExpression.Evaluate('abs(-5)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Sqrt;
begin
  Assert.AreEqual(Double(4), TExpression.Evaluate('sqrt(16)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Sin;
begin
  Assert.AreEqual(Sin(0), TExpression.Evaluate('sin(0)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Cos;
begin
  Assert.AreEqual(Cos(0), TExpression.Evaluate('cos(0)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Tan;
begin
  Assert.AreEqual(Tan(0), TExpression.Evaluate('tan(0)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Exp;
begin
  Assert.AreEqual(Exp(1), TExpression.Evaluate('exp(1)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Ln;
begin
  Assert.AreEqual(Double(0), TExpression.Evaluate('ln(1)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Log;
begin
  Assert.AreEqual(Double(2), TExpression.Evaluate('log(100)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Log2;
begin
  Assert.AreEqual(Double(3), TExpression.Evaluate('log2(8)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Floor;
begin
  Assert.AreEqual(Double(3), TExpression.Evaluate('floor(3.7)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Ceil;
begin
  Assert.AreEqual(Double(4), TExpression.Evaluate('ceil(3.1)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Round;
begin
  Assert.AreEqual(Double(4), TExpression.Evaluate('round(3.5)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Trunc;
begin
  Assert.AreEqual(Double(3), TExpression.Evaluate('trunc(3.9)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Min;
begin
  Assert.AreEqual(Double(2), TExpression.Evaluate('min(5, 2)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Max;
begin
  Assert.AreEqual(Double(5), TExpression.Evaluate('max(5, 2)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Pow;
begin
  Assert.AreEqual(Double(8), TExpression.Evaluate('pow(2, 3)').AsDouble, 0.001);
end;

procedure TExpressionMathTests.Test_Func_Mod;
begin
  Assert.AreEqual(Double(1), TExpression.Evaluate('mod(10, 3)').AsDouble, 0.001);
end;

// ============================================================================
// TExpressionStringTests
// ============================================================================

procedure TExpressionStringTests.Test_StringLiteral_DoubleQuotes;
begin
  Assert.AreEqual('hello', TExpression.Evaluate('"hello"').AsString);
end;

procedure TExpressionStringTests.Test_StringLiteral_SingleQuotes;
begin
  Assert.AreEqual('world', TExpression.Evaluate('''world''').AsString);
end;

procedure TExpressionStringTests.Test_StringLiteral_EscapeSequences;
begin
  Assert.AreEqual('line1'#10'line2', TExpression.Evaluate('"line1\nline2"').AsString);
end;

procedure TExpressionStringTests.Test_StringConcat_PlusOperator;
begin
  Assert.AreEqual('hello world', TExpression.Evaluate('"hello" + " " + "world"').AsString);
end;

procedure TExpressionStringTests.Test_StringConcat_Function;
begin
  Assert.AreEqual('abc', TExpression.Evaluate('concat("a", "b", "c")').AsString);
end;

procedure TExpressionStringTests.Test_Func_Len;
begin
  Assert.AreEqual(5, TExpression.Evaluate('len("hello")').AsInteger);
end;

procedure TExpressionStringTests.Test_Func_Upper;
begin
  Assert.AreEqual('HELLO', TExpression.Evaluate('upper("hello")').AsString);
end;

procedure TExpressionStringTests.Test_Func_Lower;
begin
  Assert.AreEqual('hello', TExpression.Evaluate('lower("HELLO")').AsString);
end;

procedure TExpressionStringTests.Test_Func_Trim;
begin
  Assert.AreEqual('hello', TExpression.Evaluate('trim("  hello  ")').AsString);
end;

procedure TExpressionStringTests.Test_Func_Left;
begin
  Assert.AreEqual('hel', TExpression.Evaluate('left("hello", 3)').AsString);
end;

procedure TExpressionStringTests.Test_Func_Right;
begin
  Assert.AreEqual('llo', TExpression.Evaluate('right("hello", 3)').AsString);
end;

procedure TExpressionStringTests.Test_Func_Substr_TwoArgs;
begin
  Assert.AreEqual('ello', TExpression.Evaluate('substr("hello", 2)').AsString);
end;

procedure TExpressionStringTests.Test_Func_Substr_ThreeArgs;
begin
  Assert.AreEqual('ell', TExpression.Evaluate('substr("hello", 2, 3)').AsString);
end;

procedure TExpressionStringTests.Test_Func_Contains;
begin
  Assert.IsTrue(TExpression.Evaluate('contains("hello world", "world")').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('contains("hello world", "xyz")').AsBoolean);
end;

procedure TExpressionStringTests.Test_Func_Replace;
begin
  Assert.AreEqual('hello universe', TExpression.Evaluate('replace("hello world", "world", "universe")').AsString);
end;

// ============================================================================
// TExpressionComparisonTests
// ============================================================================

procedure TExpressionComparisonTests.Test_Equal;
begin
  Assert.IsTrue(TExpression.Evaluate('5 = 5').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('5 = 3').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_Equal_DoubleEquals;
begin
  Assert.IsTrue(TExpression.Evaluate('5 == 5').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_NotEqual;
begin
  Assert.IsTrue(TExpression.Evaluate('5 <> 3').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('5 <> 5').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_NotEqual_BangEquals;
begin
  Assert.IsTrue(TExpression.Evaluate('5 != 3').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_LessThan;
begin
  Assert.IsTrue(TExpression.Evaluate('3 < 5').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('5 < 3').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_GreaterThan;
begin
  Assert.IsTrue(TExpression.Evaluate('5 > 3').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('3 > 5').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_LessThanOrEqual;
begin
  Assert.IsTrue(TExpression.Evaluate('3 <= 5').AsBoolean);
  Assert.IsTrue(TExpression.Evaluate('5 <= 5').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('6 <= 5').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_GreaterThanOrEqual;
begin
  Assert.IsTrue(TExpression.Evaluate('5 >= 3').AsBoolean);
  Assert.IsTrue(TExpression.Evaluate('5 >= 5').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('4 >= 5').AsBoolean);
end;

procedure TExpressionComparisonTests.Test_StringComparison;
begin
  Assert.IsTrue(TExpression.Evaluate('"abc" = "abc"').AsBoolean);
  Assert.IsTrue(TExpression.Evaluate('"abc" <> "xyz"').AsBoolean);
end;

// ============================================================================
// TExpressionLogicTests
// ============================================================================

procedure TExpressionLogicTests.Test_And_TrueTrue;
begin
  Assert.IsTrue(TExpression.Evaluate('true AND true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_And_TrueFalse;
begin
  Assert.IsFalse(TExpression.Evaluate('true AND false').AsBoolean);
end;

procedure TExpressionLogicTests.Test_And_Operator;
begin
  Assert.IsTrue(TExpression.Evaluate('true && true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Or_TrueTrue;
begin
  Assert.IsTrue(TExpression.Evaluate('true OR true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Or_FalseFalse;
begin
  Assert.IsFalse(TExpression.Evaluate('false OR false').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Or_Operator;
begin
  Assert.IsTrue(TExpression.Evaluate('false || true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Not;
begin
  Assert.IsTrue(TExpression.Evaluate('NOT false').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('NOT true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Not_Operator;
begin
  Assert.IsTrue(TExpression.Evaluate('!false').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Xor;
begin
  Assert.IsTrue(TExpression.Evaluate('true XOR false').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('true XOR true').AsBoolean);
end;

procedure TExpressionLogicTests.Test_Complex_LogicalExpression;
begin
  Assert.IsTrue(TExpression.Evaluate('(5 > 3) AND (10 < 20)').AsBoolean);
  Assert.IsFalse(TExpression.Evaluate('(5 > 3) AND (10 > 20)').AsBoolean);
end;

// ============================================================================
// TExpressionVariableTests
// ============================================================================

procedure TExpressionVariableTests.Setup;
begin
  FContext := TExpressionContext.Create;
end;

procedure TExpressionVariableTests.TearDown;
begin
  FContext.Free;
end;

procedure TExpressionVariableTests.Test_SimpleVariable;
begin
  FContext.SetVariable('x', 42);
  Assert.AreEqual(42, TExpression.Evaluate('x', FContext).AsInteger);
end;

procedure TExpressionVariableTests.Test_MultipleVariables;
begin
  FContext.SetVariable('x', 10);
  FContext.SetVariable('y', 20);
  Assert.AreEqual(30, TExpression.Evaluate('x + y', FContext).AsInteger);
end;

procedure TExpressionVariableTests.Test_VariableInExpression;
begin
  FContext.SetVariable('price', 100);
  FContext.SetVariable('tax', 0.1);
  Assert.AreEqual(Double(110), TExpression.Evaluate('price * (1 + tax)', FContext).AsDouble, 0.001);
end;

procedure TExpressionVariableTests.Test_VariableOverwrite;
begin
  FContext.SetVariable('x', 10);
  Assert.AreEqual(10, TExpression.Evaluate('x', FContext).AsInteger);
  FContext.SetVariable('x', 20);
  Assert.AreEqual(20, TExpression.Evaluate('x', FContext).AsInteger);
end;

procedure TExpressionVariableTests.Test_UndefinedVariable_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TExpression.Evaluate('undefined_var', FContext);
    end, EExpressionError);
end;

procedure TExpressionVariableTests.Test_CaseInsensitiveVariables;
begin
  FContext.SetVariable('MyVar', 42);
  Assert.AreEqual(42, TExpression.Evaluate('myvar', FContext).AsInteger);
  Assert.AreEqual(42, TExpression.Evaluate('MYVAR', FContext).AsInteger);
end;

// ============================================================================
// TExpressionConditionalTests
// ============================================================================

procedure TExpressionConditionalTests.Test_If_True;
begin
  Assert.AreEqual('yes', TExpression.Evaluate('if(true, "yes", "no")').AsString);
end;

procedure TExpressionConditionalTests.Test_If_False;
begin
  Assert.AreEqual('no', TExpression.Evaluate('if(false, "yes", "no")').AsString);
end;

procedure TExpressionConditionalTests.Test_If_WithoutElse;
begin
  Assert.AreEqual('yes', TExpression.Evaluate('if(true, "yes")').AsString);
  Assert.IsTrue(TExpression.Evaluate('if(false, "yes")').IsNull);
end;

procedure TExpressionConditionalTests.Test_IsNull_True;
begin
  Assert.IsTrue(TExpression.Evaluate('isnull(null)').AsBoolean);
end;

procedure TExpressionConditionalTests.Test_IsNull_False;
begin
  Assert.IsFalse(TExpression.Evaluate('isnull(42)').AsBoolean);
end;

procedure TExpressionConditionalTests.Test_Coalesce_FirstNonNull;
var
  Ctx: TExpressionContext;
begin
  Ctx := TExpressionContext.Create;
  try
    Ctx.SetVariable('a', TExpressionValue.Null);
    Ctx.SetVariable('b', 10);
    Ctx.SetVariable('c', 20);
    Assert.AreEqual(10, TExpression.Evaluate('coalesce(a, b, c)', Ctx).AsInteger);
  finally
    Ctx.Free;
  end;
end;

procedure TExpressionConditionalTests.Test_Coalesce_AllNull;
begin
  Assert.IsTrue(TExpression.Evaluate('coalesce(null, null)').IsNull);
end;

// ============================================================================
// TCompiledExpressionTests
// ============================================================================

procedure TCompiledExpressionTests.Setup;
begin
  FContext := TExpressionContext.Create;
end;

procedure TCompiledExpressionTests.TearDown;
begin
  FContext.Free;
end;

procedure TCompiledExpressionTests.Test_Compile_SimpleExpression;
var
  Expr: TCompiledExpression;
begin
  Expr := TExpression.Compile('2 + 3');
  try
    Assert.AreEqual(Double(5), Expr.Evaluate.AsDouble, 0.001);
  finally
    Expr.Free;
  end;
end;

procedure TCompiledExpressionTests.Test_Compile_ReusableExpression;
var
  Expr: TCompiledExpression;
  I: Integer;
begin
  FContext.SetVariable('x', 0);
  Expr := TExpression.Compile('x * x');
  try
    for I := 1 to 5 do
    begin
      FContext.SetVariable('x', I);
      Assert.AreEqual(Double(I * I), Expr.Evaluate(FContext).AsDouble, 0.001);
    end;
  finally
    Expr.Free;
  end;
end;

procedure TCompiledExpressionTests.Test_Compile_WithVariables;
var
  Expr: TCompiledExpression;
begin
  FContext.SetVariable('a', 10);
  FContext.SetVariable('b', 5);
  Expr := TExpression.Compile('a + b');
  try
    Assert.AreEqual(Double(15), Expr.Evaluate(FContext).AsDouble, 0.001);
  finally
    Expr.Free;
  end;
end;

procedure TCompiledExpressionTests.Test_Clone;
var
  Expr1, Expr2: TCompiledExpression;
begin
  Expr1 := TExpression.Compile('2 + 3');
  try
    Expr2 := Expr1.Clone;
    try
      Assert.AreEqual(Expr1.Evaluate.AsDouble, Expr2.Evaluate.AsDouble, 0.001);
    finally
      Expr2.Free;
    end;
  finally
    Expr1.Free;
  end;
end;

procedure TCompiledExpressionTests.Test_Expression_Property;
var
  Expr: TCompiledExpression;
begin
  Expr := TExpression.Compile('1 + 2 + 3');
  try
    Assert.AreEqual('1 + 2 + 3', Expr.Expression);
  finally
    Expr.Free;
  end;
end;

// ============================================================================
// TExpressionStaticTests
// ============================================================================

procedure TExpressionStaticTests.Test_Evaluate_NoContext;
begin
  Assert.AreEqual(Double(10), TExpression.Evaluate('5 + 5').AsDouble, 0.001);
end;

procedure TExpressionStaticTests.Test_Evaluate_WithContext;
var
  Ctx: TExpressionContext;
begin
  Ctx := TExpressionContext.Create;
  try
    Ctx.SetVariable('n', 7);
    Assert.AreEqual(Double(14), TExpression.Evaluate('n * 2', Ctx).AsDouble, 0.001);
  finally
    Ctx.Free;
  end;
end;

procedure TExpressionStaticTests.Test_Compile;
var
  Expr: TCompiledExpression;
begin
  Expr := TExpression.Compile('3 * 4');
  try
    Assert.IsNotNull(Expr);
    Assert.AreEqual(Double(12), Expr.Evaluate.AsDouble, 0.001);
  finally
    Expr.Free;
  end;
end;

procedure TExpressionStaticTests.Test_GlobalContext;
begin
  Assert.IsNotNull(TExpression.GlobalContext);
end;

procedure TExpressionStaticTests.Test_ClearCache;
begin
  // Should not raise exception
  TExpression.ClearCache;
  Assert.IsTrue(True);
end;

// ============================================================================
// TExpressionErrorTests
// ============================================================================

procedure TExpressionErrorTests.Test_SyntaxError_UnknownOperator;
begin
  Assert.WillRaise(
    procedure
    begin
      TExpression.Evaluate('5 @ 3');
    end, EExpressionError);
end;

procedure TExpressionErrorTests.Test_Error_UnknownVariable;
begin
  Assert.WillRaise(
    procedure
    begin
      TExpression.Evaluate('unknownVar');
    end, EExpressionError);
end;

procedure TExpressionErrorTests.Test_Error_UnknownFunction;
begin
  Assert.WillRaise(
    procedure
    begin
      TExpression.Evaluate('unknownFunc(1)');
    end, EExpressionError);
end;

procedure TExpressionErrorTests.Test_Error_Position;
begin
  try
    TExpression.Evaluate('x');
    Assert.Fail('Expected exception');
  except
    on Ex: EExpressionError do
    begin
      Assert.IsTrue(True); // Exception caught
    end;
  end;
end;

// ============================================================================
// TExpressionCustomFunctionTests
// ============================================================================

procedure TExpressionCustomFunctionTests.Setup;
begin
  FContext := TExpressionContext.Create;
end;

procedure TExpressionCustomFunctionTests.TearDown;
begin
  FContext.Free;
end;

procedure TExpressionCustomFunctionTests.Test_CustomFunction_NoArgs;
begin
  FContext.RegisterFunction('getAnswer',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := 42;
    end);

  Assert.AreEqual(42, TExpression.Evaluate('getAnswer()', FContext).AsInteger);
end;

procedure TExpressionCustomFunctionTests.Test_CustomFunction_SingleArg;
begin
  FContext.RegisterFunction('double',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].AsDouble * 2;
    end);

  Assert.AreEqual(Double(20), TExpression.Evaluate('double(10)', FContext).AsDouble, 0.001);
end;

procedure TExpressionCustomFunctionTests.Test_CustomFunction_MultipleArgs;
begin
  FContext.RegisterFunction('sum3',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    begin
      Result := Args[0].AsDouble + Args[1].AsDouble + Args[2].AsDouble;
    end);

  Assert.AreEqual(Double(60), TExpression.Evaluate('sum3(10, 20, 30)', FContext).AsDouble, 0.001);
end;

procedure TExpressionCustomFunctionTests.Test_CustomFunction_UsingContext;
begin
  FContext.SetVariable('multiplier', 5);
  FContext.RegisterFunction('multiply',
    function(const Args: array of TExpressionValue; Context: TExpressionContext): TExpressionValue
    var
      M: TExpressionValue;
    begin
      if Context.TryGetVariable('multiplier', M) then
        Result := Args[0].AsDouble * M.AsDouble
      else
        Result := Args[0];
    end);

  Assert.AreEqual(Double(50), TExpression.Evaluate('multiply(10)', FContext).AsDouble, 0.001);
end;

initialization
  TDUnitX.RegisterTestFixture(TExpressionValueTests);
  TDUnitX.RegisterTestFixture(TExpressionContextTests);
  TDUnitX.RegisterTestFixture(TExpressionMathTests);
  TDUnitX.RegisterTestFixture(TExpressionStringTests);
  TDUnitX.RegisterTestFixture(TExpressionComparisonTests);
  TDUnitX.RegisterTestFixture(TExpressionLogicTests);
  TDUnitX.RegisterTestFixture(TExpressionVariableTests);
  TDUnitX.RegisterTestFixture(TExpressionConditionalTests);
  TDUnitX.RegisterTestFixture(TCompiledExpressionTests);
  TDUnitX.RegisterTestFixture(TExpressionStaticTests);
  TDUnitX.RegisterTestFixture(TExpressionErrorTests);
  TDUnitX.RegisterTestFixture(TExpressionCustomFunctionTests);

end.
