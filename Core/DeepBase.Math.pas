unit DeepBase.Math;

{*******************************************************************************
  DeepBase Math Utilities — Core Facade
  Foundational math types and utilities:
  - EMathException: math-specific exception base class
  - IsFinite: floating-point finiteness check
  - TMathConst: mathematical constants (PI, E, etc.)
  - TMathUtils / TMath: numerical utility functions (clamp, wrap, trig, log,
    GCD/LCM, factorial, prime check, Fibonacci, etc.)

  Extended functionality lives in focused sub-modules (import as needed):
  - DeepBase.Math.Geometry      — TVector2, TVector3, TMatrix2, TMatrix3
  - DeepBase.Math.Statistics    — TStatistics, TInterpolation
  - DeepBase.Math.Interpolation — TEasing
  - DeepBase.Math.Random        — TRandomDist, TSecureRandom

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, DeepBase.Exceptions;

type
  EMathException = class(EDeepBaseException);

  /// <summary>Numerical utilities</summary>
  TMathUtils = class
  public
    /// <summary>Clamping</summary>
    class function Clamp(AValue, AMin, AMax: Double): Double; overload; static;
    class function Clamp(AValue, AMin, AMax: Integer): Integer; overload; static;
    class function Clamp01(AValue: Double): Double; static;

    /// <summary>Wrapping</summary>
    class function Wrap(AValue, AMin, AMax: Double): Double; static;
    class function WrapAngle(AAngle: Double): Double; static;

    /// <summary>Sign and absolute</summary>
    class function Sign(AValue: Double): Integer; static;
    class function Abs(AValue: Double): Double; static;

    /// <summary>Rounding</summary>
    class function Round(AValue: Double): Int64; static;
    class function RoundTo(AValue: Double; ADigits: Integer): Double; static;
    class function Floor(AValue: Double): Int64; static;
    class function Ceil(AValue: Double): Int64; static;
    class function Trunc(AValue: Double): Int64; static;
    class function Frac(AValue: Double): Double; static;

    /// <summary>Comparison</summary>
    class function Approximately(A, B: Double; AEpsilon: Double = 1E-10): Boolean; static;
    class function IsZero(AValue: Double; AEpsilon: Double = 1E-10): Boolean; static;
    class function IsNaN(AValue: Double): Boolean; static;
    class function IsInfinity(AValue: Double): Boolean; static;

    /// <summary>Power and roots</summary>
    class function Pow(ABase, AExponent: Double): Double; static;
    class function Sqrt(AValue: Double): Double; static;
    class function Cbrt(AValue: Double): Double; static;
    class function NthRoot(AValue: Double; N: Integer): Double; static;

    /// <summary>Logarithms</summary>
    class function Log(AValue: Double): Double; static;
    class function Log10(AValue: Double): Double; static;
    class function Log2(AValue: Double): Double; static;
    class function LogN(ABase, AValue: Double): Double; static;
    class function Exp(AValue: Double): Double; static;

    /// <summary>Trigonometry (radians)</summary>
    class function Sin(AAngle: Double): Double; static;
    class function Cos(AAngle: Double): Double; static;
    class function Tan(AAngle: Double): Double; static;
    class function ASin(AValue: Double): Double; static;
    class function ACos(AValue: Double): Double; static;
    class function ATan(AValue: Double): Double; static;
    class function ATan2(AY, AX: Double): Double; static;

    /// <summary>Hyperbolic</summary>
    class function Sinh(AValue: Double): Double; static;
    class function Cosh(AValue: Double): Double; static;
    class function Tanh(AValue: Double): Double; static;

    /// <summary>Angle conversion</summary>
    class function DegToRad(ADegrees: Double): Double; static;
    class function RadToDeg(ARadians: Double): Double; static;

    /// <summary>GCD and LCM</summary>
    class function GCD(A, B: Int64): Int64; static;
    class function LCM(A, B: Int64): Int64; static;

    /// <summary>Factorial and combinations</summary>
    class function Factorial(N: Integer): Int64; static;
    class function Permutations(N, R: Integer): Int64; static;
    class function Combinations(N, R: Integer): Int64; static;

    /// <summary>Prime check</summary>
    class function IsPrime(N: Int64): Boolean; static;
    class function NextPrime(N: Int64): Int64; static;

    /// <summary>Fibonacci</summary>
    class function Fibonacci(N: Integer): Int64; static;

    /// <summary>Map value between ranges</summary>
    class function Map(AValue, AFromMin, AFromMax, AToMin, AToMax: Double): Double; static;

    /// <summary>Step function</summary>
    class function Step(AEdge, AValue: Double): Double; static;

    /// <summary>Ping-pong (oscillates between 0 and length)</summary>
    class function PingPong(T, ALength: Double): Double; static;

    /// <summary>Move towards target</summary>
    class function MoveTowards(ACurrent, ATarget, AMaxDelta: Double): Double; static;

    /// <summary>Delta angle (shortest rotation)</summary>
    class function DeltaAngle(ACurrent, ATarget: Double): Double; static;
  end;

  /// <summary>Constants</summary>
  TMathConst = class
  public
    const PI = 3.14159265358979323846;
    const TwoPI = 6.28318530717958647692;
    const HalfPI = 1.57079632679489661923;
    const E = 2.71828182845904523536;
    const GoldenRatio = 1.61803398874989484820;
    const Sqrt2 = 1.41421356237309504880;
    const Sqrt3 = 1.73205080756887729352;
    const DegToRadFactor = PI / 180;
    const RadToDegFactor = 180 / PI;
    const Epsilon = 1E-10;
  end;

  /// <summary>Static helper shortcut</summary>
  TMath = TMathUtils;

/// <summary>Check for finite value (not NaN or Infinite)</summary>
function IsFinite(const Value: Double): Boolean; inline;

implementation

{ IsFinite }

function IsFinite(const Value: Double): Boolean;
begin
  Result := not (IsNaN(Value) or IsInfinite(Value));
end;

{ TMathUtils }

class function TMathUtils.Clamp(AValue, AMin, AMax: Double): Double;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

class function TMathUtils.Clamp(AValue, AMin, AMax: Integer): Integer;
begin
  if AValue < AMin then
    Result := AMin
  else if AValue > AMax then
    Result := AMax
  else
    Result := AValue;
end;

class function TMathUtils.Clamp01(AValue: Double): Double;
begin
  Result := Clamp(AValue, 0, 1);
end;

class function TMathUtils.Wrap(AValue, AMin, AMax: Double): Double;
var
  LRange: Double;
begin
  LRange := AMax - AMin;
  if IsZero(LRange) then
    Exit(AMin);

  Result := AValue - System.Trunc((AValue - AMin) / LRange) * LRange;
  if Result < AMin then
    Result := Result + LRange
  else if Result >= AMax then
    Result := Result - LRange;
end;

class function TMathUtils.WrapAngle(AAngle: Double): Double;
begin
  Result := Wrap(AAngle, -TMathConst.PI, TMathConst.PI);
end;

class function TMathUtils.Sign(AValue: Double): Integer;
begin
  if AValue > 0 then
    Result := 1
  else if AValue < 0 then
    Result := -1
  else
    Result := 0;
end;

class function TMathUtils.Abs(AValue: Double): Double;
begin
  Result := System.Abs(AValue);
end;

class function TMathUtils.Round(AValue: Double): Int64;
begin
  Result := System.Round(AValue);
end;

class function TMathUtils.RoundTo(AValue: Double; ADigits: Integer): Double;
begin
  Result := System.Math.RoundTo(AValue, -ADigits);
end;

class function TMathUtils.Floor(AValue: Double): Int64;
begin
  Result := System.Trunc(System.Math.Floor(AValue));
end;

class function TMathUtils.Ceil(AValue: Double): Int64;
begin
  Result := System.Trunc(System.Math.Ceil(AValue));
end;

class function TMathUtils.Trunc(AValue: Double): Int64;
begin
  Result := System.Trunc(AValue);
end;

class function TMathUtils.Frac(AValue: Double): Double;
begin
  Result := System.Frac(AValue);
end;

class function TMathUtils.Approximately(A, B: Double; AEpsilon: Double): Boolean;
begin
  Result := System.Abs(A - B) < AEpsilon;
end;

class function TMathUtils.IsZero(AValue: Double; AEpsilon: Double): Boolean;
begin
  Result := System.Abs(AValue) < AEpsilon;
end;

class function TMathUtils.IsNaN(AValue: Double): Boolean;
begin
  Result := System.Math.IsNaN(AValue);
end;

class function TMathUtils.IsInfinity(AValue: Double): Boolean;
begin
  Result := System.Math.IsInfinite(AValue);
end;

class function TMathUtils.Pow(ABase, AExponent: Double): Double;
begin
  Result := Power(ABase, AExponent);
end;

class function TMathUtils.Sqrt(AValue: Double): Double;
begin
  Result := System.Sqrt(AValue);
end;

class function TMathUtils.Cbrt(AValue: Double): Double;
begin
  if AValue >= 0 then
    Result := Power(AValue, 1/3)
  else
    Result := -Power(-AValue, 1/3);
end;

class function TMathUtils.NthRoot(AValue: Double; N: Integer): Double;
begin
  if (AValue < 0) and (N mod 2 = 0) then
    raise EMathException.Create('Even root of negative number');

  if AValue >= 0 then
    Result := Power(AValue, 1/N)
  else
    Result := -Power(-AValue, 1/N);
end;

class function TMathUtils.Log(AValue: Double): Double;
begin
  Result := Ln(AValue);
end;

class function TMathUtils.Log10(AValue: Double): Double;
begin
  Result := System.Math.Log10(AValue);
end;

class function TMathUtils.Log2(AValue: Double): Double;
begin
  Result := System.Math.Log2(AValue);
end;

class function TMathUtils.LogN(ABase, AValue: Double): Double;
begin
  Result := System.Math.LogN(ABase, AValue);
end;

class function TMathUtils.Exp(AValue: Double): Double;
begin
  Result := System.Exp(AValue);
end;

class function TMathUtils.Sin(AAngle: Double): Double;
begin
  Result := System.Sin(AAngle);
end;

class function TMathUtils.Cos(AAngle: Double): Double;
begin
  Result := System.Cos(AAngle);
end;

class function TMathUtils.Tan(AAngle: Double): Double;
begin
  Result := System.Math.Tan(AAngle);
end;

class function TMathUtils.ASin(AValue: Double): Double;
begin
  Result := ArcSin(AValue);
end;

class function TMathUtils.ACos(AValue: Double): Double;
begin
  Result := ArcCos(AValue);
end;

class function TMathUtils.ATan(AValue: Double): Double;
begin
  Result := ArcTan(AValue);
end;

class function TMathUtils.ATan2(AY, AX: Double): Double;
begin
  Result := ArcTan2(AY, AX);
end;

class function TMathUtils.Sinh(AValue: Double): Double;
begin
  Result := System.Math.Sinh(AValue);
end;

class function TMathUtils.Cosh(AValue: Double): Double;
begin
  Result := System.Math.Cosh(AValue);
end;

class function TMathUtils.Tanh(AValue: Double): Double;
begin
  Result := System.Math.Tanh(AValue);
end;

class function TMathUtils.DegToRad(ADegrees: Double): Double;
begin
  Result := ADegrees * TMathConst.DegToRadFactor;
end;

class function TMathUtils.RadToDeg(ARadians: Double): Double;
begin
  Result := ARadians * TMathConst.RadToDegFactor;
end;

class function TMathUtils.GCD(A, B: Int64): Int64;
begin
  A := System.Abs(A);
  B := System.Abs(B);
  while B <> 0 do
  begin
    Result := B;
    B := A mod B;
    A := Result;
  end;
  Result := A;
end;

class function TMathUtils.LCM(A, B: Int64): Int64;
begin
  if (A = 0) or (B = 0) then
    Exit(0);
  Result := (System.Abs(A) div GCD(A, B)) * System.Abs(B);
end;

class function TMathUtils.Factorial(N: Integer): Int64;
begin
  if N < 0 then
    raise EMathException.Create('Factorial undefined for negative numbers');
  if N > 20 then
    raise EMathException.Create('Factorial overflow for N > 20');

  Result := 1;
  while N > 1 do
  begin
    Result := Result * N;
    Dec(N);
  end;
end;

class function TMathUtils.Permutations(N, R: Integer): Int64;
begin
  if (R < 0) or (R > N) then
    raise EMathException.Create('Invalid permutation parameters');
  Result := Factorial(N) div Factorial(N - R);
end;

class function TMathUtils.Combinations(N, R: Integer): Int64;
begin
  if (R < 0) or (R > N) then
    raise EMathException.Create('Invalid combination parameters');
  Result := Factorial(N) div (Factorial(R) * Factorial(N - R));
end;

class function TMathUtils.IsPrime(N: Int64): Boolean;
var
  I: Int64;
begin
  if N < 2 then
    Exit(False);
  if N = 2 then
    Exit(True);
  if N mod 2 = 0 then
    Exit(False);

  I := 3;
  while I <= N div I do
  begin
    if N mod I = 0 then
      Exit(False);
    Inc(I, 2);
  end;
  Result := True;
end;

class function TMathUtils.NextPrime(N: Int64): Int64;
begin
  if N < 2 then
    Exit(2);

  Result := N + 1;
  if Result mod 2 = 0 then
    Inc(Result);

  while not IsPrime(Result) do
    Inc(Result, 2);
end;

class function TMathUtils.Fibonacci(N: Integer): Int64;
var
  A, B, Temp: Int64;
  I: Integer;
begin
  if N < 0 then
    raise EMathException.Create('Fibonacci undefined for negative numbers');
  if N <= 1 then
    Exit(N);

  A := 0;
  B := 1;
  for I := 2 to N do
  begin
    Temp := A + B;
    A := B;
    B := Temp;
  end;
  Result := B;
end;

class function TMathUtils.Map(AValue, AFromMin, AFromMax, AToMin, AToMax: Double): Double;
var
  LRange: Double;
begin
  LRange := AFromMax - AFromMin;
  if IsZero(LRange) then
    Result := AToMin
  else
    Result := AToMin + (AValue - AFromMin) * (AToMax - AToMin) / LRange;
end;

class function TMathUtils.Step(AEdge, AValue: Double): Double;
begin
  if AValue < AEdge then
    Result := 0
  else
    Result := 1;
end;

class function TMathUtils.PingPong(T, ALength: Double): Double;
begin
  T := Wrap(T, 0, ALength * 2);
  if T < ALength then
    Result := T
  else
    Result := ALength * 2 - T;
end;

class function TMathUtils.MoveTowards(ACurrent, ATarget, AMaxDelta: Double): Double;
var
  LDiff: Double;
begin
  LDiff := ATarget - ACurrent;
  if System.Abs(LDiff) <= AMaxDelta then
    Result := ATarget
  else
    Result := ACurrent + Sign(LDiff) * AMaxDelta;
end;

class function TMathUtils.DeltaAngle(ACurrent, ATarget: Double): Double;
begin
  Result := WrapAngle(ATarget - ACurrent);
end;

end.
