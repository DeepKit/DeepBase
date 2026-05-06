{ ============================================================================
  UniBase.Services.Math - Mathematical Service Implementations

  Version: 1.0
  Description: Implements IStatisticsService, IMathUtilsService,
               IInterpolationService, IEasingService, IRandomDistributionService
               interfaces. These implementations wrap the existing static
               methods from UniBase.Math module.
  ============================================================================ }

unit UniBase.Services.Math;

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  UniBase.Services.Interfaces,
  UniBase.Math;

type
  // ============================================================================
  // Statistics Service Implementation
  // ============================================================================

  TStatisticsServiceImpl = class(TInterfacedObject, IStatisticsService)
  public
    function Mean(const Values: TArray<Double>): Double;
    function Median(const Values: TArray<Double>): Double;
    function Mode(const Values: TArray<Double>): Double;

    function Variance(const Values: TArray<Double>): Double;
    function StdDev(const Values: TArray<Double>): Double;
    function PopulationVariance(const Values: TArray<Double>): Double;
    function PopulationStdDev(const Values: TArray<Double>): Double;

    function Min(const Values: TArray<Double>): Double;
    function Max(const Values: TArray<Double>): Double;
    function Range(const Values: TArray<Double>): Double;
    function Sum(const Values: TArray<Double>): Double;

    function Percentile(const Values: TArray<Double>; P: Double): Double;
    function Quartile1(const Values: TArray<Double>): Double;
    function Quartile3(const Values: TArray<Double>): Double;
    function IQR(const Values: TArray<Double>): Double;

    function Skewness(const Values: TArray<Double>): Double;
    function Kurtosis(const Values: TArray<Double>): Double;

    function Covariance(const X, Y: TArray<Double>): Double;
    function Correlation(const X, Y: TArray<Double>): Double;

    function LinearRegression(const X, Y: TArray<Double>): TLinearRegressionResult;

    function ZScore(Value, Mean, StdDev: Double): Double;
    function ZScores(const Values: TArray<Double>): TArray<Double>;
  end;

  // ============================================================================
  // Math Utils Service Implementation
  // ============================================================================

  TMathUtilsServiceImpl = class(TInterfacedObject, IMathUtilsService)
  public
    function Clamp(Value, Min, Max: Double): Double;
    function Clamp01(Value: Double): Double;

    function Wrap(Value, Min, Max: Double): Double;
    function WrapAngle(Angle: Double): Double;

    function Sign(Value: Double): Integer;
    function Abs(Value: Double): Double;

    function Round(Value: Double): Int64;
    function RoundTo(Value: Double; Digits: Integer): Double;
    function Floor(Value: Double): Int64;
    function Ceil(Value: Double): Int64;
    function Trunc(Value: Double): Int64;
    function Frac(Value: Double): Double;

    function Approximately(A, B: Double; Epsilon: Double = 1E-10): Boolean;
    function IsZero(Value: Double; Epsilon: Double = 1E-10): Boolean;
    function IsNaN(Value: Double): Boolean;
    function IsInfinity(Value: Double): Boolean;

    function Pow(Base, Exponent: Double): Double;
    function Sqrt(Value: Double): Double;
    function Cbrt(Value: Double): Double;
    function NthRoot(Value: Double; N: Integer): Double;

    function Log(Value: Double): Double;
    function Log10(Value: Double): Double;
    function Log2(Value: Double): Double;
    function LogN(Value, Base: Double): Double;
    function Exp(Value: Double): Double;

    function Sin(Value: Double): Double;
    function Cos(Value: Double): Double;
    function Tan(Value: Double): Double;
    function ASin(Value: Double): Double;
    function ACos(Value: Double): Double;
    function ATan(Value: Double): Double;
    function ATan2(Y, X: Double): Double;

    function DegToRad(Degrees: Double): Double;
    function RadToDeg(Radians: Double): Double;

    function GCD(A, B: Int64): Int64;
    function LCM(A, B: Int64): Int64;
    function Factorial(N: Integer): Int64;
    function IsPrime(N: Int64): Boolean;
    function NextPrime(N: Int64): Int64;

    function Map(Value, InMin, InMax, OutMin, OutMax: Double): Double;
    function Lerp(A, B, T: Double): Double;
    function InverseLerp(A, B, Value: Double): Double;
  end;

  // ============================================================================
  // Interpolation Service Implementation
  // ============================================================================

  TInterpolationServiceImpl = class(TInterfacedObject, IInterpolationService)
  public
    function Linear(A, B, T: Double): Double;
    function Cosine(A, B, T: Double): Double;
    function Cubic(Y0, Y1, Y2, Y3, T: Double): Double;
    function Hermite(Y0, Y1, Y2, Y3, T, Tension, Bias: Double): Double;

    function QuadraticBezier(P0, P1, P2, T: Double): Double;
    function CubicBezier(P0, P1, P2, P3, T: Double): Double;

    function CatmullRom(P0, P1, P2, P3, T: Double): Double;

    function Smoothstep(Edge0, Edge1, X: Double): Double;
    function Smootherstep(Edge0, Edge1, X: Double): Double;

    function Bilinear(Q11, Q21, Q12, Q22, X, Y: Double): Double;

    function Remap(Value, InMin, InMax, OutMin, OutMax: Double): Double;
  end;

  // ============================================================================
  // Easing Service Implementation
  // ============================================================================

  TEasingServiceImpl = class(TInterfacedObject, IEasingService)
  public
    function Ease(T: Double; EasingType: TEasingType): Double;

    function Linear(T: Double): Double;

    function QuadIn(T: Double): Double;
    function QuadOut(T: Double): Double;
    function QuadInOut(T: Double): Double;

    function CubicIn(T: Double): Double;
    function CubicOut(T: Double): Double;
    function CubicInOut(T: Double): Double;

    function ElasticIn(T: Double): Double;
    function ElasticOut(T: Double): Double;
    function ElasticInOut(T: Double): Double;

    function BounceIn(T: Double): Double;
    function BounceOut(T: Double): Double;
    function BounceInOut(T: Double): Double;
  end;

  // ============================================================================
  // Random Distribution Service Implementation
  // ============================================================================

  TRandomDistributionServiceImpl = class(TInterfacedObject, IRandomDistributionService)
  public
    function Uniform(Min, Max: Double): Double;
    function UniformInt(Min, Max: Integer): Integer;

    function Normal(Mean, StdDev: Double): Double;
    function StandardNormal: Double;

    function Exponential(Lambda: Double): Double;
    function Poisson(Lambda: Double): Integer;
    function Bernoulli(P: Double): Boolean;
    function Binomial(N: Integer; P: Double): Integer;
    function Geometric(P: Double): Integer;
    function Triangular(Min, Max, Mode: Double): Double;

    procedure PointInCircle(Radius: Double; out X, Y: Double);
    procedure PointOnCircle(Radius: Double; out X, Y: Double);
    procedure PointInSphere(Radius: Double; out X, Y, Z: Double);
    procedure PointOnSphere(Radius: Double; out X, Y, Z: Double);

    procedure ShuffleDoubles(var Values: TArray<Double>);
    function WeightedChoiceIndex(const Weights: TArray<Double>): Integer;
  end;

implementation

// ============================================================================
// TStatisticsServiceImpl
// ============================================================================

function TStatisticsServiceImpl.Mean(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Mean(Values);
end;

function TStatisticsServiceImpl.Median(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Median(Values);
end;

function TStatisticsServiceImpl.Mode(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Mode(Values);
end;

function TStatisticsServiceImpl.Variance(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Variance(Values);
end;

function TStatisticsServiceImpl.StdDev(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.StdDev(Values);
end;

function TStatisticsServiceImpl.PopulationVariance(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.PopulationVariance(Values);
end;

function TStatisticsServiceImpl.PopulationStdDev(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.PopulationStdDev(Values);
end;

function TStatisticsServiceImpl.Min(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Min(Values);
end;

function TStatisticsServiceImpl.Max(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Max(Values);
end;

function TStatisticsServiceImpl.Range(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Range(Values);
end;

function TStatisticsServiceImpl.Sum(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Sum(Values);
end;

function TStatisticsServiceImpl.Percentile(const Values: TArray<Double>; P: Double): Double;
begin
  Result := TStatistics.Percentile(Values, P);
end;

function TStatisticsServiceImpl.Quartile1(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Quartile1(Values);
end;

function TStatisticsServiceImpl.Quartile3(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Quartile3(Values);
end;

function TStatisticsServiceImpl.IQR(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.IQR(Values);
end;

function TStatisticsServiceImpl.Skewness(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Skewness(Values);
end;

function TStatisticsServiceImpl.Kurtosis(const Values: TArray<Double>): Double;
begin
  Result := TStatistics.Kurtosis(Values);
end;

function TStatisticsServiceImpl.Covariance(const X, Y: TArray<Double>): Double;
begin
  Result := TStatistics.Covariance(X, Y);
end;

function TStatisticsServiceImpl.Correlation(const X, Y: TArray<Double>): Double;
begin
  Result := TStatistics.Correlation(X, Y);
end;

function TStatisticsServiceImpl.LinearRegression(const X, Y: TArray<Double>): TLinearRegressionResult;
begin
  TStatistics.LinearRegression(X, Y, Result.Slope, Result.Intercept, Result.RSquared);
end;

function TStatisticsServiceImpl.ZScore(Value, Mean, StdDev: Double): Double;
begin
  Result := TStatistics.ZScore(Value, Mean, StdDev);
end;

function TStatisticsServiceImpl.ZScores(const Values: TArray<Double>): TArray<Double>;
begin
  Result := TStatistics.ZScores(Values);
end;

// ============================================================================
// TMathUtilsServiceImpl
// ============================================================================

function TMathUtilsServiceImpl.Clamp(Value, Min, Max: Double): Double;
begin
  Result := TMathUtils.Clamp(Value, Min, Max);
end;

function TMathUtilsServiceImpl.Clamp01(Value: Double): Double;
begin
  Result := TMathUtils.Clamp01(Value);
end;

function TMathUtilsServiceImpl.Wrap(Value, Min, Max: Double): Double;
begin
  Result := TMathUtils.Wrap(Value, Min, Max);
end;

function TMathUtilsServiceImpl.WrapAngle(Angle: Double): Double;
begin
  Result := TMathUtils.WrapAngle(Angle);
end;

function TMathUtilsServiceImpl.Sign(Value: Double): Integer;
begin
  Result := TMathUtils.Sign(Value);
end;

function TMathUtilsServiceImpl.Abs(Value: Double): Double;
begin
  Result := TMathUtils.Abs(Value);
end;

function TMathUtilsServiceImpl.Round(Value: Double): Int64;
begin
  Result := TMathUtils.Round(Value);
end;

function TMathUtilsServiceImpl.RoundTo(Value: Double; Digits: Integer): Double;
begin
  Result := TMathUtils.RoundTo(Value, Digits);
end;

function TMathUtilsServiceImpl.Floor(Value: Double): Int64;
begin
  Result := TMathUtils.Floor(Value);
end;

function TMathUtilsServiceImpl.Ceil(Value: Double): Int64;
begin
  Result := TMathUtils.Ceil(Value);
end;

function TMathUtilsServiceImpl.Trunc(Value: Double): Int64;
begin
  Result := TMathUtils.Trunc(Value);
end;

function TMathUtilsServiceImpl.Frac(Value: Double): Double;
begin
  Result := TMathUtils.Frac(Value);
end;

function TMathUtilsServiceImpl.Approximately(A, B: Double; Epsilon: Double): Boolean;
begin
  Result := TMathUtils.Approximately(A, B, Epsilon);
end;

function TMathUtilsServiceImpl.IsZero(Value: Double; Epsilon: Double): Boolean;
begin
  Result := TMathUtils.IsZero(Value, Epsilon);
end;

function TMathUtilsServiceImpl.IsNaN(Value: Double): Boolean;
begin
  Result := TMathUtils.IsNaN(Value);
end;

function TMathUtilsServiceImpl.IsInfinity(Value: Double): Boolean;
begin
  Result := TMathUtils.IsInfinity(Value);
end;

function TMathUtilsServiceImpl.Pow(Base, Exponent: Double): Double;
begin
  Result := TMathUtils.Pow(Base, Exponent);
end;

function TMathUtilsServiceImpl.Sqrt(Value: Double): Double;
begin
  Result := TMathUtils.Sqrt(Value);
end;

function TMathUtilsServiceImpl.Cbrt(Value: Double): Double;
begin
  Result := TMathUtils.Cbrt(Value);
end;

function TMathUtilsServiceImpl.NthRoot(Value: Double; N: Integer): Double;
begin
  Result := TMathUtils.NthRoot(Value, N);
end;

function TMathUtilsServiceImpl.Log(Value: Double): Double;
begin
  Result := TMathUtils.Log(Value);
end;

function TMathUtilsServiceImpl.Log10(Value: Double): Double;
begin
  Result := TMathUtils.Log10(Value);
end;

function TMathUtilsServiceImpl.Log2(Value: Double): Double;
begin
  Result := TMathUtils.Log2(Value);
end;

function TMathUtilsServiceImpl.LogN(Value, Base: Double): Double;
begin
  Result := TMathUtils.LogN(Base, Value);
end;

function TMathUtilsServiceImpl.Exp(Value: Double): Double;
begin
  Result := TMathUtils.Exp(Value);
end;

function TMathUtilsServiceImpl.Sin(Value: Double): Double;
begin
  Result := TMathUtils.Sin(Value);
end;

function TMathUtilsServiceImpl.Cos(Value: Double): Double;
begin
  Result := TMathUtils.Cos(Value);
end;

function TMathUtilsServiceImpl.Tan(Value: Double): Double;
begin
  Result := TMathUtils.Tan(Value);
end;

function TMathUtilsServiceImpl.ASin(Value: Double): Double;
begin
  Result := TMathUtils.ASin(Value);
end;

function TMathUtilsServiceImpl.ACos(Value: Double): Double;
begin
  Result := TMathUtils.ACos(Value);
end;

function TMathUtilsServiceImpl.ATan(Value: Double): Double;
begin
  Result := TMathUtils.ATan(Value);
end;

function TMathUtilsServiceImpl.ATan2(Y, X: Double): Double;
begin
  Result := TMathUtils.ATan2(Y, X);
end;

function TMathUtilsServiceImpl.DegToRad(Degrees: Double): Double;
begin
  Result := TMathUtils.DegToRad(Degrees);
end;

function TMathUtilsServiceImpl.RadToDeg(Radians: Double): Double;
begin
  Result := TMathUtils.RadToDeg(Radians);
end;

function TMathUtilsServiceImpl.GCD(A, B: Int64): Int64;
begin
  Result := TMathUtils.GCD(A, B);
end;

function TMathUtilsServiceImpl.LCM(A, B: Int64): Int64;
begin
  Result := TMathUtils.LCM(A, B);
end;

function TMathUtilsServiceImpl.Factorial(N: Integer): Int64;
begin
  Result := TMathUtils.Factorial(N);
end;

function TMathUtilsServiceImpl.IsPrime(N: Int64): Boolean;
begin
  Result := TMathUtils.IsPrime(N);
end;

function TMathUtilsServiceImpl.NextPrime(N: Int64): Int64;
begin
  Result := TMathUtils.NextPrime(N);
end;

function TMathUtilsServiceImpl.Map(Value, InMin, InMax, OutMin, OutMax: Double): Double;
begin
  Result := TMathUtils.Map(Value, InMin, InMax, OutMin, OutMax);
end;

function TMathUtilsServiceImpl.Lerp(A, B, T: Double): Double;
begin
  Result := TInterpolation.Linear(A, B, T);
end;

function TMathUtilsServiceImpl.InverseLerp(A, B, Value: Double): Double;
begin
  if TMathUtils.IsZero(B - A) then
    Result := 0
  else
    Result := (Value - A) / (B - A);
end;

// ============================================================================
// TInterpolationServiceImpl
// ============================================================================

function TInterpolationServiceImpl.Linear(A, B, T: Double): Double;
begin
  Result := TInterpolation.Linear(A, B, T);
end;

function TInterpolationServiceImpl.Cosine(A, B, T: Double): Double;
begin
  Result := TInterpolation.Cosine(A, B, T);
end;

function TInterpolationServiceImpl.Cubic(Y0, Y1, Y2, Y3, T: Double): Double;
begin
  Result := TInterpolation.Cubic(Y0, Y1, Y2, Y3, T);
end;

function TInterpolationServiceImpl.Hermite(Y0, Y1, Y2, Y3, T, Tension, Bias: Double): Double;
begin
  Result := TInterpolation.Hermite(Y0, Y1, Y2, Y3, T, Tension, Bias);
end;

function TInterpolationServiceImpl.QuadraticBezier(P0, P1, P2, T: Double): Double;
begin
  Result := TInterpolation.QuadraticBezier(P0, P1, P2, T);
end;

function TInterpolationServiceImpl.CubicBezier(P0, P1, P2, P3, T: Double): Double;
begin
  Result := TInterpolation.CubicBezier(P0, P1, P2, P3, T);
end;

function TInterpolationServiceImpl.CatmullRom(P0, P1, P2, P3, T: Double): Double;
begin
  Result := TInterpolation.CatmullRom(P0, P1, P2, P3, T);
end;

function TInterpolationServiceImpl.Smoothstep(Edge0, Edge1, X: Double): Double;
begin
  Result := TInterpolation.Smoothstep(Edge0, Edge1, X);
end;

function TInterpolationServiceImpl.Smootherstep(Edge0, Edge1, X: Double): Double;
begin
  Result := TInterpolation.Smootherstep(Edge0, Edge1, X);
end;

function TInterpolationServiceImpl.Bilinear(Q11, Q21, Q12, Q22, X,
  Y: Double): Double;
begin
  Result := TInterpolation.Bilinear(Q11, Q21, Q12, Q22, X, Y);
end;

function TInterpolationServiceImpl.Remap(Value, InMin, InMax, OutMin, OutMax: Double): Double;
begin
  Result := TInterpolation.Remap(Value, InMin, InMax, OutMin, OutMax);
end;

// ============================================================================
// TEasingServiceImpl
// ============================================================================

function TEasingServiceImpl.Ease(T: Double; EasingType: TEasingType): Double;
begin
  case EasingType of
    etLinear: Result := Linear(T);
    etQuadIn: Result := QuadIn(T);
    etQuadOut: Result := QuadOut(T);
    etQuadInOut: Result := QuadInOut(T);
    etCubicIn: Result := CubicIn(T);
    etCubicOut: Result := CubicOut(T);
    etCubicInOut: Result := CubicInOut(T);
    etQuartIn: Result := TEasing.QuartIn(T);
    etQuartOut: Result := TEasing.QuartOut(T);
    etQuartInOut: Result := TEasing.QuartInOut(T);
    etQuintIn: Result := TEasing.QuintIn(T);
    etQuintOut: Result := TEasing.QuintOut(T);
    etQuintInOut: Result := TEasing.QuintInOut(T);
    etSineIn: Result := TEasing.SineIn(T);
    etSineOut: Result := TEasing.SineOut(T);
    etSineInOut: Result := TEasing.SineInOut(T);
    etExpoIn: Result := TEasing.ExpoIn(T);
    etExpoOut: Result := TEasing.ExpoOut(T);
    etExpoInOut: Result := TEasing.ExpoInOut(T);
    etCircIn: Result := TEasing.CircIn(T);
    etCircOut: Result := TEasing.CircOut(T);
    etCircInOut: Result := TEasing.CircInOut(T);
    etElasticIn: Result := ElasticIn(T);
    etElasticOut: Result := ElasticOut(T);
    etElasticInOut: Result := ElasticInOut(T);
    etBackIn: Result := TEasing.BackIn(T);
    etBackOut: Result := TEasing.BackOut(T);
    etBackInOut: Result := TEasing.BackInOut(T);
    etBounceIn: Result := BounceIn(T);
    etBounceOut: Result := BounceOut(T);
    etBounceInOut: Result := BounceInOut(T);
  else
    Result := T;
  end;
end;

function TEasingServiceImpl.Linear(T: Double): Double;
begin
  Result := TEasing.Linear(T);
end;

function TEasingServiceImpl.QuadIn(T: Double): Double;
begin
  Result := TEasing.QuadIn(T);
end;

function TEasingServiceImpl.QuadOut(T: Double): Double;
begin
  Result := TEasing.QuadOut(T);
end;

function TEasingServiceImpl.QuadInOut(T: Double): Double;
begin
  Result := TEasing.QuadInOut(T);
end;

function TEasingServiceImpl.CubicIn(T: Double): Double;
begin
  Result := TEasing.CubicIn(T);
end;

function TEasingServiceImpl.CubicOut(T: Double): Double;
begin
  Result := TEasing.CubicOut(T);
end;

function TEasingServiceImpl.CubicInOut(T: Double): Double;
begin
  Result := TEasing.CubicInOut(T);
end;

function TEasingServiceImpl.ElasticIn(T: Double): Double;
begin
  Result := TEasing.ElasticIn(T);
end;

function TEasingServiceImpl.ElasticOut(T: Double): Double;
begin
  Result := TEasing.ElasticOut(T);
end;

function TEasingServiceImpl.ElasticInOut(T: Double): Double;
begin
  Result := TEasing.ElasticInOut(T);
end;

function TEasingServiceImpl.BounceIn(T: Double): Double;
begin
  Result := TEasing.BounceIn(T);
end;

function TEasingServiceImpl.BounceOut(T: Double): Double;
begin
  Result := TEasing.BounceOut(T);
end;

function TEasingServiceImpl.BounceInOut(T: Double): Double;
begin
  Result := TEasing.BounceInOut(T);
end;

// ============================================================================
// TRandomDistributionServiceImpl
// ============================================================================

function TRandomDistributionServiceImpl.Uniform(Min, Max: Double): Double;
begin
  Result := TRandomDist.Uniform(Min, Max);
end;

function TRandomDistributionServiceImpl.UniformInt(Min, Max: Integer): Integer;
begin
  Result := TRandomDist.UniformInt(Min, Max);
end;

function TRandomDistributionServiceImpl.Normal(Mean, StdDev: Double): Double;
begin
  Result := TRandomDist.Normal(Mean, StdDev);
end;

function TRandomDistributionServiceImpl.StandardNormal: Double;
begin
  Result := TRandomDist.StandardNormal;
end;

function TRandomDistributionServiceImpl.Exponential(Lambda: Double): Double;
begin
  Result := TRandomDist.Exponential(Lambda);
end;

function TRandomDistributionServiceImpl.Poisson(Lambda: Double): Integer;
begin
  Result := TRandomDist.Poisson(Lambda);
end;

function TRandomDistributionServiceImpl.Bernoulli(P: Double): Boolean;
begin
  Result := TRandomDist.Bernoulli(P);
end;

function TRandomDistributionServiceImpl.Binomial(N: Integer; P: Double): Integer;
begin
  Result := TRandomDist.Binomial(N, P);
end;

function TRandomDistributionServiceImpl.Geometric(P: Double): Integer;
begin
  Result := TRandomDist.Geometric(P);
end;

function TRandomDistributionServiceImpl.Triangular(Min, Max, Mode: Double): Double;
begin
  Result := TRandomDist.Triangular(Min, Max, Mode);
end;

procedure TRandomDistributionServiceImpl.PointInCircle(Radius: Double; out X, Y: Double);
var
  Point: TVector2;
begin
  Point := TRandomDist.PointInCircle(Radius);
  X := Point.X;
  Y := Point.Y;
end;

procedure TRandomDistributionServiceImpl.PointOnCircle(Radius: Double; out X, Y: Double);
var
  Point: TVector2;
begin
  Point := TRandomDist.PointOnCircle(Radius);
  X := Point.X;
  Y := Point.Y;
end;

procedure TRandomDistributionServiceImpl.PointInSphere(Radius: Double; out X, Y, Z: Double);
var
  Point: TVector3;
begin
  Point := TRandomDist.PointInSphere(Radius);
  X := Point.X;
  Y := Point.Y;
  Z := Point.Z;
end;

procedure TRandomDistributionServiceImpl.PointOnSphere(Radius: Double; out X, Y, Z: Double);
var
  Point: TVector3;
begin
  Point := TRandomDist.PointOnSphere(Radius);
  X := Point.X;
  Y := Point.Y;
  Z := Point.Z;
end;

procedure TRandomDistributionServiceImpl.ShuffleDoubles(
  var Values: TArray<Double>);
begin
  TRandomDist.Shuffle<Double>(Values);
end;

function TRandomDistributionServiceImpl.WeightedChoiceIndex(
  const Weights: TArray<Double>): Integer;
begin
  Result := TRandomDist.WeightedChoice(Weights);
end;

end.
