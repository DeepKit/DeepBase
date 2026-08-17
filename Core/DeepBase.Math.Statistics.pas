unit DeepBase.Math.Statistics;

{*******************************************************************************
  DeepBase Math — Statistics & Interpolation
  Extracted from DeepBase.Math to keep the facade under 800 lines.

  Contains:
  - TStatistics: statistical functions (mean, median, stddev, percentiles,
    correlation, regression, distribution measures)
  - TInterpolation: interpolation algorithms (linear, cosine, cubic, Hermite,
    Bezier, Catmull-Rom, smoothstep, bilinear, remap)

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, System.Generics.Collections,
  System.Generics.Defaults, DeepBase.Math, DeepBase.Math.Geometry;

type
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

implementation

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

  // BUG-026 FIX: Check for zero std dev (all values identical)
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

  // BUG-026 FIX: Check for zero std dev (all values identical)
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

end.
