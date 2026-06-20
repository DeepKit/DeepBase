unit DeepBase.Math;

{*******************************************************************************
  DeepBase Math Utilities
  A comprehensive math module with:
  - Vector and matrix operations
  - Statistical functions
  - Interpolation algorithms
  - Random distributions
  - Numerical utilities
  
  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, System.SyncObjs, System.Generics.Collections,
  System.Generics.Defaults, Winapi.Windows, DeepBase.Exceptions;

// ������ֵ�ȶ��Լ�麯��
function IsFinite(const Value: Double): Boolean; inline;

type
  EMathException = class(EDeepBaseException);

  /// <summary>2D Vector</summary>
  TVector2 = record
    X, Y: Double;
    
    constructor Create(AX, AY: Double);
    
    function Length: Double;
    function LengthSquared: Double;
    function Normalize: TVector2;
    function Dot(const AOther: TVector2): Double;
    function Cross(const AOther: TVector2): Double;
    function Distance(const AOther: TVector2): Double;
    function Angle: Double;
    function AngleTo(const AOther: TVector2): Double;
    function Rotate(AAngle: Double): TVector2;
    function Lerp(const AOther: TVector2; T: Double): TVector2;
    function Reflect(const ANormal: TVector2): TVector2;
    function Perpendicular: TVector2;
    function Negate: TVector2;
    
    function ToString: string;
    
    class function Zero: TVector2; static;
    class function One: TVector2; static;
    class function UnitX: TVector2; static;
    class function UnitY: TVector2; static;
    
    class operator Add(const A, B: TVector2): TVector2;
    class operator Subtract(const A, B: TVector2): TVector2;
    class operator Multiply(const A: TVector2; B: Double): TVector2;
    class operator Multiply(A: Double; const B: TVector2): TVector2;
    class operator Divide(const A: TVector2; B: Double): TVector2;
    class operator Negative(const A: TVector2): TVector2;
    class operator Equal(const A, B: TVector2): Boolean;
    class operator NotEqual(const A, B: TVector2): Boolean;
  end;

  /// <summary>3D Vector</summary>
  TVector3 = record
    X, Y, Z: Double;
    
    constructor Create(AX, AY, AZ: Double);
    
    function Length: Double;
    function LengthSquared: Double;
    function Normalize: TVector3;
    function Dot(const AOther: TVector3): Double;
    function Cross(const AOther: TVector3): TVector3;
    function Distance(const AOther: TVector3): Double;
    function Lerp(const AOther: TVector3; T: Double): TVector3;
    function Reflect(const ANormal: TVector3): TVector3;
    function Negate: TVector3;
    
    function ToString: string;
    
    class function Zero: TVector3; static;
    class function One: TVector3; static;
    class function UnitX: TVector3; static;
    class function UnitY: TVector3; static;
    class function UnitZ: TVector3; static;
    
    class operator Add(const A, B: TVector3): TVector3;
    class operator Subtract(const A, B: TVector3): TVector3;
    class operator Multiply(const A: TVector3; B: Double): TVector3;
    class operator Multiply(A: Double; const B: TVector3): TVector3;
    class operator Divide(const A: TVector3; B: Double): TVector3;
    class operator Negative(const A: TVector3): TVector3;
    class operator Equal(const A, B: TVector3): Boolean;
    class operator NotEqual(const A, B: TVector3): Boolean;
  end;

  /// <summary>2x2 Matrix</summary>
  TMatrix2 = record
    M: array[0..1, 0..1] of Double;
    
    constructor Create(AM00, AM01, AM10, AM11: Double);
    
    function Determinant: Double;
    function Transpose: TMatrix2;
    function Inverse: TMatrix2;
    function Transform(const AVector: TVector2): TVector2;
    
    class function Identity: TMatrix2; static;
    class function Zero: TMatrix2; static;
    class function Rotation(AAngle: Double): TMatrix2; static;
    class function Scale(ASx, ASy: Double): TMatrix2; static;
    
    class operator Add(const A, B: TMatrix2): TMatrix2;
    class operator Subtract(const A, B: TMatrix2): TMatrix2;
    class operator Multiply(const A, B: TMatrix2): TMatrix2;
    class operator Multiply(const A: TMatrix2; B: Double): TMatrix2;
  end;

  /// <summary>3x3 Matrix</summary>
  TMatrix3 = record
    M: array[0..2, 0..2] of Double;
    
    constructor Create(const AValues: array of Double);
    
    function Determinant: Double;
    function Transpose: TMatrix3;
    function Inverse: TMatrix3;
    function Transform(const AVector: TVector3): TVector3;
    
    class function Identity: TMatrix3; static;
    class function Zero: TMatrix3; static;
    class function RotationX(AAngle: Double): TMatrix3; static;
    class function RotationY(AAngle: Double): TMatrix3; static;
    class function RotationZ(AAngle: Double): TMatrix3; static;
    class function Scale(ASx, ASy, ASz: Double): TMatrix3; static;
    
    class operator Add(const A, B: TMatrix3): TMatrix3;
    class operator Subtract(const A, B: TMatrix3): TMatrix3;
    class operator Multiply(const A, B: TMatrix3): TMatrix3;
    class operator Multiply(const A: TMatrix3; B: Double): TMatrix3;
  end;

  /// <summary>Secure random number generator using system entropy</summary>
  TSecureRandom = class
  private
    class var FInstance: TSecureRandom;
    class var FLock: TObject;
    class constructor Create;
    class destructor Destroy;
  public
    class function Instance: TSecureRandom;
    function NextBytes(const ALength: Integer): TBytes;
    function NextInt(const AMax: Integer): Integer;
    function NextDouble: Double;
    function NextString(const ALength: Integer): string;
  end;

  /// <summary>Statistical functions</summary>
  TStatistics = class
  public
    /// <summary>Basic statistics</summary>
    class function Mean(const AValues: array of Double): Double; static;
    class function Median(const AValues: array of Double): Double; static;
    class function Mode(const AValues: array of Double): Double; static;
    
    /// <summary>Variance and standard deviation</summary>
    class function Variance(const AValues: array of Double; ASample: Boolean = True): Double; static;
    class function StdDev(const AValues: array of Double; ASample: Boolean = True): Double; static;
    class function PopulationVariance(const AValues: array of Double): Double; static;
    class function PopulationStdDev(const AValues: array of Double): Double; static;
    
    /// <summary>Range statistics</summary>
    class function Min(const AValues: array of Double): Double; static;
    class function Max(const AValues: array of Double): Double; static;
    class function Range(const AValues: array of Double): Double; static;
    class function Sum(const AValues: array of Double): Double; static;
    class function Product(const AValues: array of Double): Double; static;
    
    /// <summary>Percentiles and quartiles</summary>
    class function Percentile(const AValues: array of Double; APercentile: Double): Double; static;
    class function Quartile1(const AValues: array of Double): Double; static;
    class function Quartile3(const AValues: array of Double): Double; static;
    class function IQR(const AValues: array of Double): Double; static;
    
    /// <summary>Distribution measures</summary>
    class function Skewness(const AValues: array of Double): Double; static;
    class function Kurtosis(const AValues: array of Double): Double; static;
    
    /// <summary>Correlation and covariance</summary>
    class function Covariance(const AX, AY: array of Double): Double; static;
    class function Correlation(const AX, AY: array of Double): Double; static;
    
    /// <summary>Geometric and harmonic means</summary>
    class function GeometricMean(const AValues: array of Double): Double; static;
    class function HarmonicMean(const AValues: array of Double): Double; static;
    
    /// <summary>Root mean square</summary>
    class function RMS(const AValues: array of Double): Double; static;
    
    /// <summary>Z-score normalization</summary>
    class function ZScore(AValue, AMean, AStdDev: Double): Double; static;
    class function ZScores(const AValues: array of Double): TArray<Double>; static;
    
    /// <summary>Linear regression</summary>
    class procedure LinearRegression(const AX, AY: array of Double; 
      out ASlope, AIntercept, AR2: Double); static;
  end;

  /// <summary>Interpolation methods</summary>
  TInterpolation = class
  public
    /// <summary>Linear interpolation</summary>
    class function Linear(A, B, T: Double): Double; static;
    class function LinearArray(const AValues: array of Double; T: Double): Double; static;
    
    /// <summary>Cosine interpolation</summary>
    class function Cosine(A, B, T: Double): Double; static;
    
    /// <summary>Cubic interpolation</summary>
    class function Cubic(Y0, Y1, Y2, Y3, T: Double): Double; static;
    
    /// <summary>Hermite interpolation</summary>
    class function Hermite(Y0, Y1, Y2, Y3, T, ATension, ABias: Double): Double; static;
    
    /// <summary>Bezier curves</summary>
    class function QuadraticBezier(P0, P1, P2, T: Double): Double; static;
    class function CubicBezier(P0, P1, P2, P3, T: Double): Double; static;
    class function QuadraticBezier2D(const P0, P1, P2: TVector2; T: Double): TVector2; static;
    class function CubicBezier2D(const P0, P1, P2, P3: TVector2; T: Double): TVector2; static;
    
    /// <summary>Catmull-Rom spline</summary>
    class function CatmullRom(Y0, Y1, Y2, Y3, T: Double): Double; static;
    
    /// <summary>Smoothstep functions</summary>
    class function Smoothstep(AEdge0, AEdge1, X: Double): Double; static;
    class function Smootherstep(AEdge0, AEdge1, X: Double): Double; static;
    
    /// <summary>Bilinear interpolation</summary>
    class function Bilinear(Q11, Q21, Q12, Q22, X, Y: Double): Double; static;
    
    /// <summary>Remap value</summary>
    class function Remap(AValue, AInMin, AInMax, AOutMin, AOutMax: Double): Double; static;
  end;

  /// <summary>Easing functions</summary>
  TEasing = class
  public
    // Linear
    class function Linear(T: Double): Double; static;
    
    // Quadratic
    class function QuadIn(T: Double): Double; static;
    class function QuadOut(T: Double): Double; static;
    class function QuadInOut(T: Double): Double; static;
    
    // Cubic
    class function CubicIn(T: Double): Double; static;
    class function CubicOut(T: Double): Double; static;
    class function CubicInOut(T: Double): Double; static;
    
    // Quartic
    class function QuartIn(T: Double): Double; static;
    class function QuartOut(T: Double): Double; static;
    class function QuartInOut(T: Double): Double; static;
    
    // Quintic
    class function QuintIn(T: Double): Double; static;
    class function QuintOut(T: Double): Double; static;
    class function QuintInOut(T: Double): Double; static;
    
    // Sine
    class function SineIn(T: Double): Double; static;
    class function SineOut(T: Double): Double; static;
    class function SineInOut(T: Double): Double; static;
    
    // Exponential
    class function ExpoIn(T: Double): Double; static;
    class function ExpoOut(T: Double): Double; static;
    class function ExpoInOut(T: Double): Double; static;
    
    // Circular
    class function CircIn(T: Double): Double; static;
    class function CircOut(T: Double): Double; static;
    class function CircInOut(T: Double): Double; static;
    
    // Elastic
    class function ElasticIn(T: Double): Double; static;
    class function ElasticOut(T: Double): Double; static;
    class function ElasticInOut(T: Double): Double; static;
    
    // Back
    class function BackIn(T: Double): Double; static;
    class function BackOut(T: Double): Double; static;
    class function BackInOut(T: Double): Double; static;
    
    // Bounce
    class function BounceIn(T: Double): Double; static;
    class function BounceOut(T: Double): Double; static;
    class function BounceInOut(T: Double): Double; static;
  end;

  /// <summary>Random distribution generators</summary>
  TRandomDist = class
  private
    class var FSpareNormal: Double;
    class var FHasSpareNormal: Boolean;
    class var FLock: TCriticalSection;
    class constructor Create;
    class destructor Destroy;
  public
    /// <summary>Uniform distribution</summary>
    class function Uniform(AMin, AMax: Double): Double; static;
    class function UniformInt(AMin, AMax: Integer): Integer; static;
    
    /// <summary>Normal (Gaussian) distribution</summary>
    class function Normal(AMean, AStdDev: Double): Double; static;
    class function StandardNormal: Double; static;
    
    /// <summary>Exponential distribution</summary>
    class function Exponential(ALambda: Double): Double; static;
    
    /// <summary>Poisson distribution</summary>
    class function Poisson(ALambda: Double): Integer; static;
    
    /// <summary>Bernoulli distribution</summary>
    class function Bernoulli(AProbability: Double): Boolean; static;
    
    /// <summary>Binomial distribution</summary>
    class function Binomial(AN: Integer; AP: Double): Integer; static;
    
    /// <summary>Geometric distribution</summary>
    class function Geometric(AP: Double): Integer; static;
    
    /// <summary>Triangular distribution</summary>
    class function Triangular(AMin, AMax, AMode: Double): Double; static;
    
    /// <summary>Log-normal distribution</summary>
    class function LogNormal(AMu, ASigma: Double): Double; static;
    
    /// <summary>Beta distribution</summary>
    class function Beta(AAlpha, ABeta: Double): Double; static;
    
    /// <summary>Gamma distribution</summary>
    class function Gamma(AShape, AScale: Double): Double; static;
    
    /// <summary>Chi-squared distribution</summary>
    class function ChiSquared(ADegreesOfFreedom: Integer): Double; static;
    
    /// <summary>Random point in circle/sphere</summary>
    class function PointInCircle(ARadius: Double): TVector2; static;
    class function PointOnCircle(ARadius: Double): TVector2; static;
    class function PointInSphere(ARadius: Double): TVector3; static;
    class function PointOnSphere(ARadius: Double): TVector3; static;
    
    /// <summary>Shuffle array</summary>
    class procedure Shuffle<T>(var AArray: TArray<T>); static;
    
    /// <summary>Weighted random selection</summary>
    class function WeightedChoice(const AWeights: array of Double): Integer; static;
  end;

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

implementation

const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

function BCryptGenRandom(hAlgorithm: THandle; pbBuffer: PByte;
  cbBuffer: Cardinal; dwFlags: Cardinal): Integer; stdcall;
  external 'bcrypt.dll';

function IsFinite(const Value: Double): Boolean;
begin
  Result := not (IsNaN(Value) or IsInfinite(Value));
end;

{ TVector2 }

constructor TVector2.Create(AX, AY: Double);
begin
  X := AX;
  Y := AY;
end;

function TVector2.Length: Double;
begin
  Result := Sqrt(X * X + Y * Y);
end;

function TVector2.LengthSquared: Double;
begin
  Result := X * X + Y * Y;
end;

function TVector2.Normalize: TVector2;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen > 0 then
    Result := TVector2.Create(X / LLen, Y / LLen)
  else
    Result := TVector2.Zero;
end;

function TVector2.Dot(const AOther: TVector2): Double;
begin
  Result := X * AOther.X + Y * AOther.Y;
end;

function TVector2.Cross(const AOther: TVector2): Double;
begin
  Result := X * AOther.Y - Y * AOther.X;
end;

function TVector2.Distance(const AOther: TVector2): Double;
begin
  Result := (Self - AOther).Length;
end;

function TVector2.Angle: Double;
begin
  Result := ArcTan2(Y, X);
end;

function TVector2.AngleTo(const AOther: TVector2): Double;
begin
  Result := ArcTan2(AOther.Y - Y, AOther.X - X);
end;

function TVector2.Rotate(AAngle: Double): TVector2;
var
  LCos, LSin: Double;
begin
  LCos := System.Cos(AAngle);
  LSin := System.Sin(AAngle);
  Result := TVector2.Create(X * LCos - Y * LSin, X * LSin + Y * LCos);
end;

function TVector2.Lerp(const AOther: TVector2; T: Double): TVector2;
begin
  Result := TVector2.Create(X + (AOther.X - X) * T, Y + (AOther.Y - Y) * T);
end;

function TVector2.Reflect(const ANormal: TVector2): TVector2;
var
  LDot: Double;
begin
  LDot := 2 * Dot(ANormal);
  Result := TVector2.Create(X - LDot * ANormal.X, Y - LDot * ANormal.Y);
end;

function TVector2.Perpendicular: TVector2;
begin
  Result := TVector2.Create(-Y, X);
end;

function TVector2.Negate: TVector2;
begin
  Result := TVector2.Create(-X, -Y);
end;

function TVector2.ToString: string;
begin
  Result := Format('(%.4f, %.4f)', [X, Y]);
end;

class function TVector2.Zero: TVector2;
begin
  Result := TVector2.Create(0, 0);
end;

class function TVector2.One: TVector2;
begin
  Result := TVector2.Create(1, 1);
end;

class function TVector2.UnitX: TVector2;
begin
  Result := TVector2.Create(1, 0);
end;

class function TVector2.UnitY: TVector2;
begin
  Result := TVector2.Create(0, 1);
end;

class operator TVector2.Add(const A, B: TVector2): TVector2;
begin
  Result := TVector2.Create(A.X + B.X, A.Y + B.Y);
end;

class operator TVector2.Subtract(const A, B: TVector2): TVector2;
begin
  Result := TVector2.Create(A.X - B.X, A.Y - B.Y);
end;

class operator TVector2.Multiply(const A: TVector2; B: Double): TVector2;
begin
  Result := TVector2.Create(A.X * B, A.Y * B);
end;

class operator TVector2.Multiply(A: Double; const B: TVector2): TVector2;
begin
  Result := TVector2.Create(A * B.X, A * B.Y);
end;

class operator TVector2.Divide(const A: TVector2; B: Double): TVector2;
begin
  // BUG-026 FIX: ���ӳ�����
  if TMathUtils.IsZero(B) then
    raise EMathException.Create('Division by zero in TVector2.Divide');
  Result := TVector2.Create(A.X / B, A.Y / B);
end;

class operator TVector2.Negative(const A: TVector2): TVector2;
begin
  Result := TVector2.Create(-A.X, -A.Y);
end;

class operator TVector2.Equal(const A, B: TVector2): Boolean;
begin
  Result := TMathUtils.Approximately(A.X, B.X) and TMathUtils.Approximately(A.Y, B.Y);
end;

class operator TVector2.NotEqual(const A, B: TVector2): Boolean;
begin
  Result := not (A = B);
end;

{ TVector3 }

constructor TVector3.Create(AX, AY, AZ: Double);
begin
  X := AX;
  Y := AY;
  Z := AZ;
end;

function TVector3.Length: Double;
begin
  Result := Sqrt(X * X + Y * Y + Z * Z);
end;

function TVector3.LengthSquared: Double;
begin
  Result := X * X + Y * Y + Z * Z;
end;

function TVector3.Normalize: TVector3;
var
  LLen: Double;
begin
  LLen := Length;
  if LLen > 0 then
    Result := TVector3.Create(X / LLen, Y / LLen, Z / LLen)
  else
    Result := TVector3.Zero;
end;

function TVector3.Dot(const AOther: TVector3): Double;
begin
  Result := X * AOther.X + Y * AOther.Y + Z * AOther.Z;
end;

function TVector3.Cross(const AOther: TVector3): TVector3;
begin
  Result := TVector3.Create(
    Y * AOther.Z - Z * AOther.Y,
    Z * AOther.X - X * AOther.Z,
    X * AOther.Y - Y * AOther.X
  );
end;

function TVector3.Distance(const AOther: TVector3): Double;
begin
  Result := (Self - AOther).Length;
end;

function TVector3.Lerp(const AOther: TVector3; T: Double): TVector3;
begin
  Result := TVector3.Create(
    X + (AOther.X - X) * T,
    Y + (AOther.Y - Y) * T,
    Z + (AOther.Z - Z) * T
  );
end;

function TVector3.Reflect(const ANormal: TVector3): TVector3;
var
  LDot: Double;
begin
  LDot := 2 * Dot(ANormal);
  Result := TVector3.Create(
    X - LDot * ANormal.X,
    Y - LDot * ANormal.Y,
    Z - LDot * ANormal.Z
  );
end;

function TVector3.Negate: TVector3;
begin
  Result := TVector3.Create(-X, -Y, -Z);
end;

function TVector3.ToString: string;
begin
  Result := Format('(%.4f, %.4f, %.4f)', [X, Y, Z]);
end;

class function TVector3.Zero: TVector3;
begin
  Result := TVector3.Create(0, 0, 0);
end;

class function TVector3.One: TVector3;
begin
  Result := TVector3.Create(1, 1, 1);
end;

class function TVector3.UnitX: TVector3;
begin
  Result := TVector3.Create(1, 0, 0);
end;

class function TVector3.UnitY: TVector3;
begin
  Result := TVector3.Create(0, 1, 0);
end;

class function TVector3.UnitZ: TVector3;
begin
  Result := TVector3.Create(0, 0, 1);
end;

class operator TVector3.Add(const A, B: TVector3): TVector3;
begin
  Result := TVector3.Create(A.X + B.X, A.Y + B.Y, A.Z + B.Z);
end;

class operator TVector3.Subtract(const A, B: TVector3): TVector3;
begin
  Result := TVector3.Create(A.X - B.X, A.Y - B.Y, A.Z - B.Z);
end;

class operator TVector3.Multiply(const A: TVector3; B: Double): TVector3;
begin
  Result := TVector3.Create(A.X * B, A.Y * B, A.Z * B);
end;

class operator TVector3.Multiply(A: Double; const B: TVector3): TVector3;
begin
  Result := TVector3.Create(A * B.X, A * B.Y, A * B.Z);
end;

class operator TVector3.Divide(const A: TVector3; B: Double): TVector3;
begin
  // BUG-026 FIX: ���ӳ�����
  if TMathUtils.IsZero(B) then
    raise EMathException.Create('Division by zero in TVector3.Divide');
  Result := TVector3.Create(A.X / B, A.Y / B, A.Z / B);
end;

class operator TVector3.Negative(const A: TVector3): TVector3;
begin
  Result := TVector3.Create(-A.X, -A.Y, -A.Z);
end;

class operator TVector3.Equal(const A, B: TVector3): Boolean;
begin
  Result := TMathUtils.Approximately(A.X, B.X) and 
            TMathUtils.Approximately(A.Y, B.Y) and
            TMathUtils.Approximately(A.Z, B.Z);
end;

class operator TVector3.NotEqual(const A, B: TVector3): Boolean;
begin
  Result := not (A = B);
end;

{ TMatrix2 }

constructor TMatrix2.Create(AM00, AM01, AM10, AM11: Double);
begin
  M[0, 0] := AM00; M[0, 1] := AM01;
  M[1, 0] := AM10; M[1, 1] := AM11;
end;

function TMatrix2.Determinant: Double;
begin
  Result := M[0, 0] * M[1, 1] - M[0, 1] * M[1, 0];
end;

function TMatrix2.Transpose: TMatrix2;
begin
  Result := TMatrix2.Create(M[0, 0], M[1, 0], M[0, 1], M[1, 1]);
end;

function TMatrix2.Inverse: TMatrix2;
var
  LDet: Double;
const
  MIN_DETERMINANT = 1e-15; // ��С����ʽֵ����ֹ��ֵ���ȶ�
begin
  LDet := Determinant;
  
  // �Ľ��������Լ�飬ʹ�ø��ϸ����ֵ
  if Abs(LDet) < MIN_DETERMINANT then
    raise EMathException.CreateFmt('Matrix is singular or near-singular (det=%.2e)', [LDet]);
    
  // �����ֵ�ȶ���
  var InvDet := 1.0 / LDet;
  if not IsFinite(InvDet) then
    raise EMathException.Create('Matrix inversion resulted in infinite values');
    
  Result := TMatrix2.Create(
    M[1, 1] * InvDet, 
    -M[0, 1] * InvDet, 
    -M[1, 0] * InvDet, 
    M[0, 0] * InvDet
  );
  
  // ��֤�������ֵ�ȶ���
  if not (IsFinite(Result.M[0,0]) and IsFinite(Result.M[0,1]) and 
          IsFinite(Result.M[1,0]) and IsFinite(Result.M[1,1])) then
    raise EMathException.Create('Matrix inversion produced invalid results');
end;

function TMatrix2.Transform(const AVector: TVector2): TVector2;
begin
  Result := TVector2.Create(
    M[0, 0] * AVector.X + M[0, 1] * AVector.Y,
    M[1, 0] * AVector.X + M[1, 1] * AVector.Y
  );
end;

class function TMatrix2.Identity: TMatrix2;
begin
  Result := TMatrix2.Create(1, 0, 0, 1);
end;

class function TMatrix2.Zero: TMatrix2;
begin
  Result := TMatrix2.Create(0, 0, 0, 0);
end;

class function TMatrix2.Rotation(AAngle: Double): TMatrix2;
var
  LCos, LSin: Double;
begin
  LCos := System.Cos(AAngle);
  LSin := System.Sin(AAngle);
  Result := TMatrix2.Create(LCos, -LSin, LSin, LCos);
end;

class function TMatrix2.Scale(ASx, ASy: Double): TMatrix2;
begin
  Result := TMatrix2.Create(ASx, 0, 0, ASy);
end;

class operator TMatrix2.Add(const A, B: TMatrix2): TMatrix2;
begin
  Result := TMatrix2.Create(
    A.M[0, 0] + B.M[0, 0], A.M[0, 1] + B.M[0, 1],
    A.M[1, 0] + B.M[1, 0], A.M[1, 1] + B.M[1, 1]
  );
end;

class operator TMatrix2.Subtract(const A, B: TMatrix2): TMatrix2;
begin
  Result := TMatrix2.Create(
    A.M[0, 0] - B.M[0, 0], A.M[0, 1] - B.M[0, 1],
    A.M[1, 0] - B.M[1, 0], A.M[1, 1] - B.M[1, 1]
  );
end;

class operator TMatrix2.Multiply(const A, B: TMatrix2): TMatrix2;
begin
  Result := TMatrix2.Create(
    A.M[0, 0] * B.M[0, 0] + A.M[0, 1] * B.M[1, 0],
    A.M[0, 0] * B.M[0, 1] + A.M[0, 1] * B.M[1, 1],
    A.M[1, 0] * B.M[0, 0] + A.M[1, 1] * B.M[1, 0],
    A.M[1, 0] * B.M[0, 1] + A.M[1, 1] * B.M[1, 1]
  );
end;

class operator TMatrix2.Multiply(const A: TMatrix2; B: Double): TMatrix2;
begin
  Result := TMatrix2.Create(
    A.M[0, 0] * B, A.M[0, 1] * B,
    A.M[1, 0] * B, A.M[1, 1] * B
  );
end;

{ TMatrix3 }

constructor TMatrix3.Create(const AValues: array of Double);
var
  I, J, K: Integer;
begin
  K := 0;
  for I := 0 to 2 do
    for J := 0 to 2 do
    begin
      if K < Length(AValues) then
        M[I, J] := AValues[K]
      else
        M[I, J] := 0;
      Inc(K);
    end;
end;

function TMatrix3.Determinant: Double;
begin
  Result := M[0, 0] * (M[1, 1] * M[2, 2] - M[1, 2] * M[2, 1]) -
            M[0, 1] * (M[1, 0] * M[2, 2] - M[1, 2] * M[2, 0]) +
            M[0, 2] * (M[1, 0] * M[2, 1] - M[1, 1] * M[2, 0]);
end;

function TMatrix3.Transpose: TMatrix3;
var
  I, J: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
      Result.M[I, J] := M[J, I];
end;

function TMatrix3.Inverse: TMatrix3;
var
  LDet, InvDet: Double;
  I, J: Integer;
const
  MIN_DETERMINANT = 1e-15; // BUG-026 FIX: ��С����ʽֵ����ֹ��ֵ���ȶ�
begin
  LDet := Determinant;

  // BUG-026 FIX: �Ľ��������Լ�飬ʹ�ø��ϸ����ֵ
  if Abs(LDet) < MIN_DETERMINANT then
    raise EMathException.CreateFmt('Matrix is singular or near-singular (det=%.2e)', [LDet]);

  // �����ֵ�ȶ���
  InvDet := 1.0 / LDet;
  if not IsFinite(InvDet) then
    raise EMathException.Create('Matrix inversion resulted in infinite values');

  Result.M[0, 0] := (M[1, 1] * M[2, 2] - M[1, 2] * M[2, 1]) * InvDet;
  Result.M[0, 1] := (M[0, 2] * M[2, 1] - M[0, 1] * M[2, 2]) * InvDet;
  Result.M[0, 2] := (M[0, 1] * M[1, 2] - M[0, 2] * M[1, 1]) * InvDet;
  Result.M[1, 0] := (M[1, 2] * M[2, 0] - M[1, 0] * M[2, 2]) * InvDet;
  Result.M[1, 1] := (M[0, 0] * M[2, 2] - M[0, 2] * M[2, 0]) * InvDet;
  Result.M[1, 2] := (M[0, 2] * M[1, 0] - M[0, 0] * M[1, 2]) * InvDet;
  Result.M[2, 0] := (M[1, 0] * M[2, 1] - M[1, 1] * M[2, 0]) * InvDet;
  Result.M[2, 1] := (M[0, 1] * M[2, 0] - M[0, 0] * M[2, 1]) * InvDet;
  Result.M[2, 2] := (M[0, 0] * M[1, 1] - M[0, 1] * M[1, 0]) * InvDet;

  // BUG-026 FIX: ��֤�������ֵ�ȶ���
  for I := 0 to 2 do
    for J := 0 to 2 do
      if not IsFinite(Result.M[I, J]) then
        raise EMathException.Create('Matrix inversion produced invalid results');
end;

function TMatrix3.Transform(const AVector: TVector3): TVector3;
begin
  Result := TVector3.Create(
    M[0, 0] * AVector.X + M[0, 1] * AVector.Y + M[0, 2] * AVector.Z,
    M[1, 0] * AVector.X + M[1, 1] * AVector.Y + M[1, 2] * AVector.Z,
    M[2, 0] * AVector.X + M[2, 1] * AVector.Y + M[2, 2] * AVector.Z
  );
end;

class function TMatrix3.Identity: TMatrix3;
begin
  Result := TMatrix3.Create([1, 0, 0, 0, 1, 0, 0, 0, 1]);
end;

class function TMatrix3.Zero: TMatrix3;
begin
  Result := TMatrix3.Create([0, 0, 0, 0, 0, 0, 0, 0, 0]);
end;

class function TMatrix3.RotationX(AAngle: Double): TMatrix3;
var
  C, S: Double;
begin
  C := System.Cos(AAngle);
  S := System.Sin(AAngle);
  Result := TMatrix3.Create([1, 0, 0, 0, C, -S, 0, S, C]);
end;

class function TMatrix3.RotationY(AAngle: Double): TMatrix3;
var
  C, S: Double;
begin
  C := System.Cos(AAngle);
  S := System.Sin(AAngle);
  Result := TMatrix3.Create([C, 0, S, 0, 1, 0, -S, 0, C]);
end;

class function TMatrix3.RotationZ(AAngle: Double): TMatrix3;
var
  C, S: Double;
begin
  C := System.Cos(AAngle);
  S := System.Sin(AAngle);
  Result := TMatrix3.Create([C, -S, 0, S, C, 0, 0, 0, 1]);
end;

class function TMatrix3.Scale(ASx, ASy, ASz: Double): TMatrix3;
begin
  Result := TMatrix3.Create([ASx, 0, 0, 0, ASy, 0, 0, 0, ASz]);
end;

class operator TMatrix3.Add(const A, B: TMatrix3): TMatrix3;
var
  I, J: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
      Result.M[I, J] := A.M[I, J] + B.M[I, J];
end;

class operator TMatrix3.Subtract(const A, B: TMatrix3): TMatrix3;
var
  I, J: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
      Result.M[I, J] := A.M[I, J] - B.M[I, J];
end;

class operator TMatrix3.Multiply(const A, B: TMatrix3): TMatrix3;
var
  I, J, K: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
    begin
      Result.M[I, J] := 0;
      for K := 0 to 2 do
        Result.M[I, J] := Result.M[I, J] + A.M[I, K] * B.M[K, J];
    end;
end;

class operator TMatrix3.Multiply(const A: TMatrix3; B: Double): TMatrix3;
var
  I, J: Integer;
begin
  for I := 0 to 2 do
    for J := 0 to 2 do
      Result.M[I, J] := A.M[I, J] * B;
end;

{ TStatistics }

class function TStatistics.Mean(const AValues: array of Double): Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
  Result := Sum(AValues) / Length(AValues);
end;

class function TStatistics.Median(const AValues: array of Double): Double;
var
  LSorted: TArray<Double>;
  LLen: Integer;
begin
  LLen := Length(AValues);
  if LLen = 0 then
    raise EMathException.Create('Empty array');
    
  SetLength(LSorted, LLen);
  Move(AValues[0], LSorted[0], LLen * SizeOf(Double));
  TArray.Sort<Double>(LSorted);
  
  if LLen mod 2 = 0 then
    Result := (LSorted[LLen div 2 - 1] + LSorted[LLen div 2]) / 2
  else
    Result := LSorted[LLen div 2];
end;

class function TStatistics.Mode(const AValues: array of Double): Double;
var
  LCounts: TDictionary<Double, Integer>;
  LValue: Double;
  LCount, LMaxCount: Integer;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  LCounts := TDictionary<Double, Integer>.Create;
  try
    for LValue in AValues do
    begin
      if LCounts.ContainsKey(LValue) then
        LCounts[LValue] := LCounts[LValue] + 1
      else
        LCounts.Add(LValue, 1);
    end;
    
    Result := AValues[0];
    LMaxCount := 0;
    for LValue in LCounts.Keys do
    begin
      LCount := LCounts[LValue];
      if LCount > LMaxCount then
      begin
        LMaxCount := LCount;
        Result := LValue;
      end;
    end;
  finally
    LCounts.Free;
  end;
end;

class function TStatistics.Variance(const AValues: array of Double; ASample: Boolean): Double;
var
  LMean: Double;
  LSum: Double;
  LValue: Double;
  LN: Integer;
begin
  LN := Length(AValues);
  if LN < 2 then
    raise EMathException.Create('Need at least 2 values');
    
  LMean := Mean(AValues);
  LSum := 0;
  for LValue in AValues do
    LSum := LSum + Sqr(LValue - LMean);
    
  if ASample then
    Result := LSum / (LN - 1)
  else
    Result := LSum / LN;
end;

class function TStatistics.StdDev(const AValues: array of Double; ASample: Boolean): Double;
begin
  Result := Sqrt(Variance(AValues, ASample));
end;

class function TStatistics.PopulationVariance(const AValues: array of Double): Double;
begin
  Result := Variance(AValues, False);
end;

class function TStatistics.PopulationStdDev(const AValues: array of Double): Double;
begin
  Result := Sqrt(PopulationVariance(AValues));
end;

class function TStatistics.Min(const AValues: array of Double): Double;
var
  LValue: Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  Result := AValues[0];
  for LValue in AValues do
    if LValue < Result then
      Result := LValue;
end;

class function TStatistics.Max(const AValues: array of Double): Double;
var
  LValue: Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  Result := AValues[0];
  for LValue in AValues do
    if LValue > Result then
      Result := LValue;
end;

class function TStatistics.Range(const AValues: array of Double): Double;
begin
  Result := Max(AValues) - Min(AValues);
end;

class function TStatistics.Sum(const AValues: array of Double): Double;
var
  LValue: Double;
begin
  Result := 0;
  for LValue in AValues do
    Result := Result + LValue;
end;

class function TStatistics.Product(const AValues: array of Double): Double;
var
  LValue: Double;
begin
  if Length(AValues) = 0 then
    Exit(0);
  Result := 1;
  for LValue in AValues do
    Result := Result * LValue;
end;

class function TStatistics.Percentile(const AValues: array of Double; APercentile: Double): Double;
var
  LSorted: TArray<Double>;
  LIndex: Double;
  LLower, LUpper: Integer;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  if (APercentile < 0) or (APercentile > 100) then
    raise EMathException.Create('Percentile must be 0-100');
    
  SetLength(LSorted, Length(AValues));
  Move(AValues[0], LSorted[0], Length(AValues) * SizeOf(Double));
  TArray.Sort<Double>(LSorted);
  
  LIndex := APercentile / 100 * (Length(LSorted) - 1);
  LLower := System.Trunc(LIndex);
  LUpper := System.Math.Min(LLower + 1, Length(LSorted) - 1);
  
  Result := LSorted[LLower] + (LSorted[LUpper] - LSorted[LLower]) * (LIndex - LLower);
end;

class function TStatistics.Quartile1(const AValues: array of Double): Double;
begin
  Result := Percentile(AValues, 25);
end;

class function TStatistics.Quartile3(const AValues: array of Double): Double;
begin
  Result := Percentile(AValues, 75);
end;

class function TStatistics.IQR(const AValues: array of Double): Double;
begin
  Result := Quartile3(AValues) - Quartile1(AValues);
end;

class function TStatistics.Skewness(const AValues: array of Double): Double;
var
  LMean, LStdDev: Double;
  LSum: Double;
  LValue: Double;
  LN: Integer;
begin
  LN := Length(AValues);
  if LN < 3 then
    raise EMathException.Create('Need at least 3 values');

  LMean := Mean(AValues);
  LStdDev := StdDev(AValues);

  // BUG-026 FIX: ����׼���Ƿ�Ϊ�㣨����������ͬʱ��
  if TMathUtils.IsZero(LStdDev) then
    raise EMathException.Create('Cannot compute skewness: standard deviation is zero');

  LSum := 0;
  for LValue in AValues do
    LSum := LSum + Power((LValue - LMean) / LStdDev, 3);

  Result := LSum * LN / ((LN - 1) * (LN - 2));
end;

class function TStatistics.Kurtosis(const AValues: array of Double): Double;
var
  LMean, LStdDev: Double;
  LSum: Double;
  LValue: Double;
  LN: Integer;
begin
  LN := Length(AValues);
  if LN < 4 then
    raise EMathException.Create('Need at least 4 values');

  LMean := Mean(AValues);
  LStdDev := StdDev(AValues);

  // BUG-026 FIX: ����׼���Ƿ�Ϊ�㣨����������ͬʱ��
  if TMathUtils.IsZero(LStdDev) then
    raise EMathException.Create('Cannot compute kurtosis: standard deviation is zero');

  LSum := 0;
  for LValue in AValues do
    LSum := LSum + Power((LValue - LMean) / LStdDev, 4);

  Result := (LSum * LN * (LN + 1)) / ((LN - 1) * (LN - 2) * (LN - 3)) -
            (3 * Sqr(LN - 1)) / ((LN - 2) * (LN - 3));
end;

class function TStatistics.Covariance(const AX, AY: array of Double): Double;
var
  LMeanX, LMeanY: Double;
  LSum: Double;
  I, LN: Integer;
begin
  LN := Length(AX);
  if LN <> Length(AY) then
    raise EMathException.Create('Arrays must have same length');
  if LN < 2 then
    raise EMathException.Create('Need at least 2 values');
    
  LMeanX := Mean(AX);
  LMeanY := Mean(AY);
  
  LSum := 0;
  for I := 0 to LN - 1 do
    LSum := LSum + (AX[I] - LMeanX) * (AY[I] - LMeanY);
    
  Result := LSum / (LN - 1);
end;

class function TStatistics.Correlation(const AX, AY: array of Double): Double;
var
  LStdDevX, LStdDevY: Double;
begin
  LStdDevX := StdDev(AX);
  LStdDevY := StdDev(AY);
  
  if TMathUtils.IsZero(LStdDevX) or TMathUtils.IsZero(LStdDevY) then
    Result := 0
  else
    Result := Covariance(AX, AY) / (LStdDevX * LStdDevY);
end;

class function TStatistics.GeometricMean(const AValues: array of Double): Double;
var
  LSum: Double;
  LValue: Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  LSum := 0;
  for LValue in AValues do
  begin
    if LValue <= 0 then
      raise EMathException.Create('All values must be positive');
    LSum := LSum + Ln(LValue);
  end;
  
  Result := Exp(LSum / Length(AValues));
end;

class function TStatistics.HarmonicMean(const AValues: array of Double): Double;
var
  LSum: Double;
  LValue: Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  LSum := 0;
  for LValue in AValues do
  begin
    if TMathUtils.IsZero(LValue) then
      raise EMathException.Create('Values cannot be zero');
    LSum := LSum + 1 / LValue;
  end;
  
  Result := Length(AValues) / LSum;
end;

class function TStatistics.RMS(const AValues: array of Double): Double;
var
  LSum: Double;
  LValue: Double;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
    
  LSum := 0;
  for LValue in AValues do
    LSum := LSum + Sqr(LValue);
    
  Result := Sqrt(LSum / Length(AValues));
end;

class function TStatistics.ZScore(AValue, AMean, AStdDev: Double): Double;
begin
  if TMathUtils.IsZero(AStdDev) then
    raise EMathException.Create('Standard deviation cannot be zero');
  Result := (AValue - AMean) / AStdDev;
end;

class function TStatistics.ZScores(const AValues: array of Double): TArray<Double>;
var
  LMean, LStdDev: Double;
  I: Integer;
begin
  LMean := Mean(AValues);
  LStdDev := StdDev(AValues);
  
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := ZScore(AValues[I], LMean, LStdDev);
end;

class procedure TStatistics.LinearRegression(const AX, AY: array of Double;
  out ASlope, AIntercept, AR2: Double);
var
  LMeanX, LMeanY: Double;
  LSumXY, LSumX2: Double;
  I, LN: Integer;
  LPredicted: Double;
  LSSRes, LSSTot: Double;
begin
  LN := Length(AX);
  if LN <> Length(AY) then
    raise EMathException.Create('Arrays must have same length');
  if LN < 2 then
    raise EMathException.Create('Need at least 2 values');
    
  LMeanX := Mean(AX);
  LMeanY := Mean(AY);
  
  LSumXY := 0;
  LSumX2 := 0;
  for I := 0 to LN - 1 do
  begin
    LSumXY := LSumXY + (AX[I] - LMeanX) * (AY[I] - LMeanY);
    LSumX2 := LSumX2 + Sqr(AX[I] - LMeanX);
  end;
  
  if TMathUtils.IsZero(LSumX2) then
    raise EMathException.Create('X values have zero variance');
    
  ASlope := LSumXY / LSumX2;
  AIntercept := LMeanY - ASlope * LMeanX;
  
  // Calculate R-squared
  LSSRes := 0;
  LSSTot := 0;
  for I := 0 to LN - 1 do
  begin
    LPredicted := ASlope * AX[I] + AIntercept;
    LSSRes := LSSRes + Sqr(AY[I] - LPredicted);
    LSSTot := LSSTot + Sqr(AY[I] - LMeanY);
  end;
  
  if TMathUtils.IsZero(LSSTot) then
    AR2 := 1
  else
    AR2 := 1 - LSSRes / LSSTot;
end;

{ TInterpolation }

class function TInterpolation.Linear(A, B, T: Double): Double;
begin
  Result := A + (B - A) * T;
end;

class function TInterpolation.LinearArray(const AValues: array of Double; T: Double): Double;
var
  LIndex: Double;
  LLower, LUpper: Integer;
begin
  if Length(AValues) = 0 then
    raise EMathException.Create('Empty array');
  if Length(AValues) = 1 then
    Exit(AValues[0]);
    
  T := TMathUtils.Clamp01(T);
  LIndex := T * (Length(AValues) - 1);
  LLower := System.Trunc(LIndex);
  LUpper := System.Math.Min(LLower + 1, Length(AValues) - 1);
  
  Result := Linear(AValues[LLower], AValues[LUpper], LIndex - LLower);
end;

class function TInterpolation.Cosine(A, B, T: Double): Double;
var
  LT: Double;
begin
  LT := (1 - System.Cos(T * TMathConst.PI)) / 2;
  Result := A + (B - A) * LT;
end;

class function TInterpolation.Cubic(Y0, Y1, Y2, Y3, T: Double): Double;
var
  A0, A1, A2, A3, T2: Double;
begin
  T2 := T * T;
  A0 := Y3 - Y2 - Y0 + Y1;
  A1 := Y0 - Y1 - A0;
  A2 := Y2 - Y0;
  A3 := Y1;
  Result := A0 * T * T2 + A1 * T2 + A2 * T + A3;
end;

class function TInterpolation.Hermite(Y0, Y1, Y2, Y3, T, ATension, ABias: Double): Double;
var
  M0, M1, T2, T3: Double;
  A0, A1, A2, A3: Double;
begin
  T2 := T * T;
  T3 := T2 * T;
  
  M0 := (Y1 - Y0) * (1 + ABias) * (1 - ATension) / 2 +
        (Y2 - Y1) * (1 - ABias) * (1 - ATension) / 2;
  M1 := (Y2 - Y1) * (1 + ABias) * (1 - ATension) / 2 +
        (Y3 - Y2) * (1 - ABias) * (1 - ATension) / 2;
        
  A0 := 2 * T3 - 3 * T2 + 1;
  A1 := T3 - 2 * T2 + T;
  A2 := T3 - T2;
  A3 := -2 * T3 + 3 * T2;
  
  Result := A0 * Y1 + A1 * M0 + A2 * M1 + A3 * Y2;
end;

class function TInterpolation.QuadraticBezier(P0, P1, P2, T: Double): Double;
var
  LT1: Double;
begin
  LT1 := 1 - T;
  Result := LT1 * LT1 * P0 + 2 * LT1 * T * P1 + T * T * P2;
end;

class function TInterpolation.CubicBezier(P0, P1, P2, P3, T: Double): Double;
var
  LT1, LT12, LT2: Double;
begin
  LT1 := 1 - T;
  LT12 := LT1 * LT1;
  LT2 := T * T;
  Result := LT12 * LT1 * P0 + 3 * LT12 * T * P1 + 3 * LT1 * LT2 * P2 + LT2 * T * P3;
end;

class function TInterpolation.QuadraticBezier2D(const P0, P1, P2: TVector2; T: Double): TVector2;
begin
  Result := TVector2.Create(
    QuadraticBezier(P0.X, P1.X, P2.X, T),
    QuadraticBezier(P0.Y, P1.Y, P2.Y, T)
  );
end;

class function TInterpolation.CubicBezier2D(const P0, P1, P2, P3: TVector2; T: Double): TVector2;
begin
  Result := TVector2.Create(
    CubicBezier(P0.X, P1.X, P2.X, P3.X, T),
    CubicBezier(P0.Y, P1.Y, P2.Y, P3.Y, T)
  );
end;

class function TInterpolation.CatmullRom(Y0, Y1, Y2, Y3, T: Double): Double;
var
  T2, T3: Double;
begin
  T2 := T * T;
  T3 := T2 * T;
  Result := 0.5 * ((2 * Y1) +
            (-Y0 + Y2) * T +
            (2 * Y0 - 5 * Y1 + 4 * Y2 - Y3) * T2 +
            (-Y0 + 3 * Y1 - 3 * Y2 + Y3) * T3);
end;

class function TInterpolation.Smoothstep(AEdge0, AEdge1, X: Double): Double;
var
  T, LRange: Double;
begin
  LRange := AEdge1 - AEdge0;
  if TMathUtils.IsZero(LRange) then
    T := 1
  else
    T := TMathUtils.Clamp01((X - AEdge0) / LRange);
  Result := T * T * (3 - 2 * T);
end;

class function TInterpolation.Smootherstep(AEdge0, AEdge1, X: Double): Double;
var
  T, LRange: Double;
begin
  LRange := AEdge1 - AEdge0;
  if TMathUtils.IsZero(LRange) then
    T := 1
  else
    T := TMathUtils.Clamp01((X - AEdge0) / LRange);
  Result := T * T * T * (T * (T * 6 - 15) + 10);
end;

class function TInterpolation.Bilinear(Q11, Q21, Q12, Q22, X, Y: Double): Double;
begin
  Result := Q11 * (1 - X) * (1 - Y) + 
            Q21 * X * (1 - Y) + 
            Q12 * (1 - X) * Y + 
            Q22 * X * Y;
end;

class function TInterpolation.Remap(AValue, AInMin, AInMax, AOutMin, AOutMax: Double): Double;
var
  LRange: Double;
begin
  LRange := AInMax - AInMin;
  if TMathUtils.IsZero(LRange) then
    Result := AOutMin
  else
    Result := AOutMin + (AValue - AInMin) * (AOutMax - AOutMin) / LRange;
end;

{ TEasing }

class function TEasing.Linear(T: Double): Double;
begin
  Result := T;
end;

class function TEasing.QuadIn(T: Double): Double;
begin
  Result := T * T;
end;

class function TEasing.QuadOut(T: Double): Double;
begin
  Result := T * (2 - T);
end;

class function TEasing.QuadInOut(T: Double): Double;
begin
  if T < 0.5 then
    Result := 2 * T * T
  else
    Result := -1 + (4 - 2 * T) * T;
end;

class function TEasing.CubicIn(T: Double): Double;
begin
  Result := T * T * T;
end;

class function TEasing.CubicOut(T: Double): Double;
var
  F: Double;
begin
  F := T - 1;
  Result := F * F * F + 1;
end;

class function TEasing.CubicInOut(T: Double): Double;
begin
  if T < 0.5 then
    Result := 4 * T * T * T
  else
    Result := (T - 1) * (2 * T - 2) * (2 * T - 2) + 1;
end;

class function TEasing.QuartIn(T: Double): Double;
begin
  Result := T * T * T * T;
end;

class function TEasing.QuartOut(T: Double): Double;
var
  F: Double;
begin
  F := T - 1;
  Result := 1 - F * F * F * F;
end;

class function TEasing.QuartInOut(T: Double): Double;
var
  F: Double;
begin
  if T < 0.5 then
    Result := 8 * T * T * T * T
  else
  begin
    F := T - 1;
    Result := 1 - 8 * F * F * F * F;
  end;
end;

class function TEasing.QuintIn(T: Double): Double;
begin
  Result := T * T * T * T * T;
end;

class function TEasing.QuintOut(T: Double): Double;
var
  F: Double;
begin
  F := T - 1;
  Result := F * F * F * F * F + 1;
end;

class function TEasing.QuintInOut(T: Double): Double;
var
  F: Double;
begin
  if T < 0.5 then
    Result := 16 * T * T * T * T * T
  else
  begin
    F := 2 * T - 2;
    Result := 0.5 * F * F * F * F * F + 1;
  end;
end;

class function TEasing.SineIn(T: Double): Double;
begin
  Result := 1 - System.Cos(T * TMathConst.HalfPI);
end;

class function TEasing.SineOut(T: Double): Double;
begin
  Result := System.Sin(T * TMathConst.HalfPI);
end;

class function TEasing.SineInOut(T: Double): Double;
begin
  Result := 0.5 * (1 - System.Cos(TMathConst.PI * T));
end;

class function TEasing.ExpoIn(T: Double): Double;
begin
  if T = 0 then
    Result := 0
  else
    Result := Power(2, 10 * (T - 1));
end;

class function TEasing.ExpoOut(T: Double): Double;
begin
  if T = 1 then
    Result := 1
  else
    Result := 1 - Power(2, -10 * T);
end;

class function TEasing.ExpoInOut(T: Double): Double;
begin
  if T = 0 then
    Exit(0);
  if T = 1 then
    Exit(1);
  if T < 0.5 then
    Result := 0.5 * Power(2, 20 * T - 10)
  else
    Result := 1 - 0.5 * Power(2, -20 * T + 10);
end;

class function TEasing.CircIn(T: Double): Double;
begin
  Result := 1 - Sqrt(1 - T * T);
end;

class function TEasing.CircOut(T: Double): Double;
begin
  Result := Sqrt((2 - T) * T);
end;

class function TEasing.CircInOut(T: Double): Double;
begin
  if T < 0.5 then
    Result := 0.5 * (1 - Sqrt(1 - 4 * T * T))
  else
    Result := 0.5 * (Sqrt(-((2 * T - 3) * (2 * T - 1))) + 1);
end;

class function TEasing.ElasticIn(T: Double): Double;
begin
  if T = 0 then
    Exit(0);
  if T = 1 then
    Exit(1);
  Result := -Power(2, 10 * T - 10) * System.Sin((T * 10 - 10.75) * TMathConst.TwoPI / 3);
end;

class function TEasing.ElasticOut(T: Double): Double;
begin
  if T = 0 then
    Exit(0);
  if T = 1 then
    Exit(1);
  Result := Power(2, -10 * T) * System.Sin((T * 10 - 0.75) * TMathConst.TwoPI / 3) + 1;
end;

class function TEasing.ElasticInOut(T: Double): Double;
begin
  if T = 0 then
    Exit(0);
  if T = 1 then
    Exit(1);
  if T < 0.5 then
    Result := -0.5 * Power(2, 20 * T - 10) * System.Sin((20 * T - 11.125) * TMathConst.TwoPI / 4.5)
  else
    Result := 0.5 * Power(2, -20 * T + 10) * System.Sin((20 * T - 11.125) * TMathConst.TwoPI / 4.5) + 1;
end;

class function TEasing.BackIn(T: Double): Double;
const
  C1 = 1.70158;
  C3 = C1 + 1;
begin
  Result := C3 * T * T * T - C1 * T * T;
end;

class function TEasing.BackOut(T: Double): Double;
const
  C1 = 1.70158;
  C3 = C1 + 1;
var
  F: Double;
begin
  F := T - 1;
  Result := 1 + C3 * F * F * F + C1 * F * F;
end;

class function TEasing.BackInOut(T: Double): Double;
const
  C1 = 1.70158;
  C2 = C1 * 1.525;
var
  F: Double;
begin
  if T < 0.5 then
    Result := (Sqr(2 * T) * ((C2 + 1) * 2 * T - C2)) / 2
  else
  begin
    F := 2 * T - 2;
    Result := (Sqr(F) * ((C2 + 1) * F + C2) + 2) / 2;
  end;
end;

class function TEasing.BounceIn(T: Double): Double;
begin
  Result := 1 - BounceOut(1 - T);
end;

class function TEasing.BounceOut(T: Double): Double;
const
  N1 = 7.5625;
  D1 = 2.75;
begin
  if T < 1 / D1 then
    Result := N1 * T * T
  else if T < 2 / D1 then
  begin
    T := T - 1.5 / D1;
    Result := N1 * T * T + 0.75;
  end
  else if T < 2.5 / D1 then
  begin
    T := T - 2.25 / D1;
    Result := N1 * T * T + 0.9375;
  end
  else
  begin
    T := T - 2.625 / D1;
    Result := N1 * T * T + 0.984375;
  end;
end;

class function TEasing.BounceInOut(T: Double): Double;
begin
  if T < 0.5 then
    Result := (1 - BounceOut(1 - 2 * T)) / 2
  else
    Result := (1 + BounceOut(2 * T - 1)) / 2;
end;

{ TRandomDist }

class function TRandomDist.Uniform(AMin, AMax: Double): Double;
begin
  Result := AMin + Random * (AMax - AMin);
end;

class function TRandomDist.UniformInt(AMin, AMax: Integer): Integer;
begin
  Result := AMin + Random(AMax - AMin + 1);
end;

class constructor TRandomDist.Create;
begin
  FLock := TCriticalSection.Create;
  FHasSpareNormal := False;
end;

class destructor TRandomDist.Destroy;
begin
  FreeAndNil(FLock);
end;

class function TRandomDist.StandardNormal: Double;
var
  U1, U2, S: Double;
begin
  FLock.Enter;
  try
    if FHasSpareNormal then
    begin
      FHasSpareNormal := False;
      Result := FSpareNormal;
    end
    else
    begin
      repeat
        U1 := 2 * Random - 1;
        U2 := 2 * Random - 1;
        S := U1 * U1 + U2 * U2;
      until (S > 0) and (S < 1);
      
      S := Sqrt(-2 * Ln(S) / S);
      FSpareNormal := U2 * S;
      FHasSpareNormal := True;
      Result := U1 * S;
    end;
  finally
    FLock.Leave;
  end;
end;

class function TRandomDist.Normal(AMean, AStdDev: Double): Double;
begin
  Result := AMean + StandardNormal * AStdDev;
end;

class function TRandomDist.Exponential(ALambda: Double): Double;
var
  U: Double;
begin
  if ALambda <= 0 then
    raise EMathException.Create('Lambda must be positive');
  // Avoid Ln(0) when Random returns exactly 1
  repeat
    U := Random;
  until U < 1;
  Result := -Ln(1 - U) / ALambda;
end;

class function TRandomDist.Poisson(ALambda: Double): Integer;
var
  L, P: Double;
begin
  if ALambda <= 0 then
    raise EMathException.Create('Lambda must be positive');
  L := Exp(-ALambda);
  Result := 0;
  P := 1;
  repeat
    Inc(Result);
    P := P * Random;
  until P <= L;
  Dec(Result);
end;

class function TRandomDist.Bernoulli(AProbability: Double): Boolean;
begin
  Result := Random < AProbability;
end;

class function TRandomDist.Binomial(AN: Integer; AP: Double): Integer;
var
  I: Integer;
begin
  if AN < 0 then
    raise EMathException.Create('N must be non-negative');
  if (AP < 0) or (AP > 1) then
    raise EMathException.Create('Probability must be in [0, 1]');
  Result := 0;
  for I := 1 to AN do
    if Bernoulli(AP) then
      Inc(Result);
end;

class function TRandomDist.Geometric(AP: Double): Integer;
var
  U: Double;
begin
  if (AP <= 0) or (AP >= 1) then
    raise EMathException.Create('Probability must be in (0, 1)');
  // Avoid Ln(0) when Random returns exactly 0
  repeat
    U := Random;
  until U > 0;
  Result := System.Trunc(Ln(U) / Ln(1 - AP)) + 1;
end;

class function TRandomDist.Triangular(AMin, AMax, AMode: Double): Double;
var
  U, F, LRange: Double;
begin
  LRange := AMax - AMin;
  if TMathUtils.IsZero(LRange) then
    Exit(AMin);
  if (AMode < AMin) or (AMode > AMax) then
    raise EMathException.Create('Mode must be between Min and Max');
  U := Random;
  F := (AMode - AMin) / LRange;
  if U < F then
    Result := AMin + Sqrt(U * LRange * (AMode - AMin))
  else
    Result := AMax - Sqrt((1 - U) * LRange * (AMax - AMode));
end;

class function TRandomDist.LogNormal(AMu, ASigma: Double): Double;
begin
  if ASigma < 0 then
    raise EMathException.Create('Sigma must be non-negative');
  Result := Exp(Normal(AMu, ASigma));
end;

class function TRandomDist.Beta(AAlpha, ABeta: Double): Double;
var
  X, Y, LSum: Double;
begin
  if (AAlpha <= 0) or (ABeta <= 0) then
    raise EMathException.Create('Alpha and Beta must be positive');
  X := Gamma(AAlpha, 1);
  Y := Gamma(ABeta, 1);
  LSum := X + Y;
  if TMathUtils.IsZero(LSum) then
    Result := 0.5  // Edge case: return middle value
  else
    Result := X / LSum;
end;

class function TRandomDist.Gamma(AShape, AScale: Double): Double;
var
  D, C, X, V, U: Double;
begin
  if (AShape <= 0) or (AScale <= 0) then
    raise EMathException.Create('Shape and Scale must be positive');
  if AShape >= 1 then
  begin
    D := AShape - 1/3;
    C := 1 / Sqrt(9 * D);
    repeat
      repeat
        X := StandardNormal;
        V := 1 + C * X;
      until V > 0;
      V := V * V * V;
      U := Random;
    until (U < 1 - 0.0331 * Sqr(Sqr(X))) or (Ln(U) < 0.5 * Sqr(X) + D * (1 - V + Ln(V)));
    Result := D * V * AScale;
  end
  else
  begin
    // Avoid Power(0, x) issue
    repeat
      U := Random;
    until U > 0;
    Result := Gamma(AShape + 1, AScale) * Power(U, 1 / AShape);
  end;
end;

class function TRandomDist.ChiSquared(ADegreesOfFreedom: Integer): Double;
begin
  if ADegreesOfFreedom <= 0 then
    raise EMathException.Create('Degrees of freedom must be positive');
  Result := Gamma(ADegreesOfFreedom / 2, 2);
end;

class function TRandomDist.PointInCircle(ARadius: Double): TVector2;
var
  LR, LTheta: Double;
begin
  LR := ARadius * Sqrt(Random);
  LTheta := Random * TMathConst.TwoPI;
  Result := TVector2.Create(LR * System.Cos(LTheta), LR * System.Sin(LTheta));
end;

class function TRandomDist.PointOnCircle(ARadius: Double): TVector2;
var
  LTheta: Double;
begin
  LTheta := Random * TMathConst.TwoPI;
  Result := TVector2.Create(ARadius * System.Cos(LTheta), ARadius * System.Sin(LTheta));
end;

class function TRandomDist.PointInSphere(ARadius: Double): TVector3;
var
  LR, LTheta, LPhi, LSinPhi: Double;
begin
  LR := ARadius * Power(Random, 1/3);
  LTheta := Random * TMathConst.TwoPI;
  LPhi := ArcCos(2 * Random - 1);
  LSinPhi := System.Sin(LPhi);
  Result := TVector3.Create(
    LR * LSinPhi * System.Cos(LTheta),
    LR * LSinPhi * System.Sin(LTheta),
    LR * System.Cos(LPhi)
  );
end;

class function TRandomDist.PointOnSphere(ARadius: Double): TVector3;
var
  LTheta, LPhi, LSinPhi: Double;
begin
  LTheta := Random * TMathConst.TwoPI;
  LPhi := ArcCos(2 * Random - 1);
  LSinPhi := System.Sin(LPhi);
  Result := TVector3.Create(
    ARadius * LSinPhi * System.Cos(LTheta),
    ARadius * LSinPhi * System.Sin(LTheta),
    ARadius * System.Cos(LPhi)
  );
end;

class procedure TRandomDist.Shuffle<T>(var AArray: TArray<T>);
var
  I, J: Integer;
  LTemp: T;
begin
  for I := High(AArray) downto 1 do
  begin
    J := Random(I + 1);
    LTemp := AArray[I];
    AArray[I] := AArray[J];
    AArray[J] := LTemp;
  end;
end;

class function TRandomDist.WeightedChoice(const AWeights: array of Double): Integer;
var
  LTotal, LRandom: Double;
  I: Integer;
begin
  if Length(AWeights) = 0 then
    raise EMathException.Create('Weights array cannot be empty');
    
  // ��ǿ�߽��������
  for I := 0 to High(AWeights) do
  begin
    if (AWeights[I] < 0) or IsNaN(AWeights[I]) or IsInfinite(AWeights[I]) then
      raise EMathException.CreateFmt('Invalid weight at index %d: %g', [I, AWeights[I]]);
  end;
  
  LTotal := TStatistics.Sum(AWeights);
  if TMathUtils.IsZero(LTotal) or (LTotal < 0) then
    raise EMathException.Create('Sum of weights must be positive');
    
  LRandom := Random * LTotal;
  
  for I := 0 to High(AWeights) do
  begin
    LRandom := LRandom - AWeights[I];
    if LRandom <= 0 then
      Exit(I);
  end;
  
  Result := High(AWeights);
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

{ TSecureRandom }

class constructor TSecureRandom.Create;
begin
  FLock := TObject.Create;
end;

class destructor TSecureRandom.Destroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FLock);
end;

class function TSecureRandom.Instance: TSecureRandom;
begin
  if not Assigned(FInstance) then
  begin
    TMonitor.Enter(FLock);
    try
      if not Assigned(FInstance) then
        FInstance := TSecureRandom.Create;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
  Result := FInstance;
end;

function TSecureRandom.NextBytes(const ALength: Integer): TBytes;
begin
  if ALength <= 0 then
    raise EArgumentException.Create('Length must be positive');
  SetLength(Result, ALength);
  if BCryptGenRandom(0, @Result[0], Cardinal(ALength),
       BCRYPT_USE_SYSTEM_PREFERRED_RNG) <> 0 then
    raise EDeepBaseException.Create('BCryptGenRandom failed — OS CSPRNG unavailable');
end;

function TSecureRandom.NextInt(const AMax: Integer): Integer;
var
  Bytes: TBytes;
  Value: Cardinal;
begin
  if AMax <= 0 then
    raise EArgumentException.Create('Max must be positive');
    
  Bytes := NextBytes(4);
  Value := (Cardinal(Bytes[0]) shl 24) or (Cardinal(Bytes[1]) shl 16) or 
           (Cardinal(Bytes[2]) shl 8) or Cardinal(Bytes[3]);
  Result := Integer(Value mod Cardinal(AMax));
end;

function TSecureRandom.NextDouble: Double;
var
  Bytes: TBytes;
  Value: UInt64;
begin
  Bytes := NextBytes(8);
  Value := (UInt64(Bytes[0]) shl 56) or (UInt64(Bytes[1]) shl 48) or
           (UInt64(Bytes[2]) shl 40) or (UInt64(Bytes[3]) shl 32) or
           (UInt64(Bytes[4]) shl 24) or (UInt64(Bytes[5]) shl 16) or
           (UInt64(Bytes[6]) shl 8) or UInt64(Bytes[7]);
  Result := (Value shr 11) * (1.0 / (1 shl 53));
end;

function TSecureRandom.NextString(const ALength: Integer): string;
const
  CHARSET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  I: Integer;
begin
  if ALength <= 0 then
    raise EArgumentException.Create('Length must be positive');
    
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := CHARSET[NextInt(Length(CHARSET)) + 1];
end;

initialization
  // TSecureRandom now uses BCryptGenRandom (OS CSPRNG).
  // No global Randomize needed.

end.
