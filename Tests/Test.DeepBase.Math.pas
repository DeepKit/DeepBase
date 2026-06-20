unit Test.DeepBase.Math;

{*******************************************************************************
  Unit Tests for DeepBase.Math
  Tests vector, matrix, statistics, interpolation and math utilities
*******************************************************************************}

interface
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestDeepBaseMath = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TVector2 Tests
    [Test]
    procedure TestVector2Create;
    [Test]
    procedure TestVector2Length;
    [Test]
    procedure TestVector2Normalize;
    [Test]
    procedure TestVector2Dot;
    [Test]
    procedure TestVector2Cross;
    [Test]
    procedure TestVector2Distance;
    [Test]
    procedure TestVector2Operators;
    [Test]
    procedure TestVector2Lerp;
    [Test]
    procedure TestVector2Rotate;

    // TVector3 Tests
    [Test]
    procedure TestVector3Create;
    [Test]
    procedure TestVector3Length;
    [Test]
    procedure TestVector3Normalize;
    [Test]
    procedure TestVector3Dot;
    [Test]
    procedure TestVector3Cross;
    [Test]
    procedure TestVector3Operators;

    // TMatrix2 Tests
    [Test]
    procedure TestMatrix2Identity;
    [Test]
    procedure TestMatrix2Determinant;
    [Test]
    procedure TestMatrix2Inverse;
    [Test]
    procedure TestMatrix2Rotation;
    [Test]
    procedure TestMatrix2Transform;

    // TMatrix3 Tests
    [Test]
    procedure TestMatrix3Identity;
    [Test]
    procedure TestMatrix3Determinant;
    [Test]
    procedure TestMatrix3Multiply;

    // TStatistics Tests
    [Test]
    procedure TestStatisticsMean;
    [Test]
    procedure TestStatisticsMedian;
    [Test]
    procedure TestStatisticsMode;
    [Test]
    procedure TestStatisticsVariance;
    [Test]
    procedure TestStatisticsStdDev;
    [Test]
    procedure TestStatisticsMinMax;
    [Test]
    procedure TestStatisticsPercentile;
    [Test]
    procedure TestStatisticsCorrelation;
    [Test]
    procedure TestStatisticsLinearRegression;

    // TInterpolation Tests
    [Test]
    procedure TestInterpolationLinear;
    [Test]
    procedure TestInterpolationCosine;
    [Test]
    procedure TestInterpolationCubic;
    [Test]
    procedure TestInterpolationSmoothstep;

    // TEasing Tests
    [Test]
    procedure TestEasingLinear;
    [Test]
    procedure TestEasingQuadIn;
    [Test]
    procedure TestEasingQuadOut;
    [Test]
    procedure TestEasingSineIn;

    // TRandomDist Tests
    [Test]
    procedure TestRandomUniform;
    [Test]
    procedure TestRandomNormal;
    [Test]
    procedure TestRandomShuffle;

    // TMathUtils Tests
    [Test]
    procedure TestMathClamp;
    [Test]
    procedure TestMathWrap;
    [Test]
    procedure TestMathApproximately;
    [Test]
    procedure TestMathGCD;
    [Test]
    procedure TestMathLCM;
    [Test]
    procedure TestMathFactorial;
    [Test]
    procedure TestMathIsPrime;
    [Test]
    procedure TestMathFibonacci;
    [Test]
    procedure TestMathDegRad;
  end;
implementation
uses
  System.SysUtils, System.Math,
  DeepBase.Math;

const
  EPSILON = 1E-9;

procedure TTestDeepBaseMath.Setup;
begin
end;

procedure TTestDeepBaseMath.TearDown;
begin
end;

// TVector2 Tests

procedure TTestDeepBaseMath.TestVector2Create;
var
  V: TVector2;
begin
  V := TVector2.Create(3.0, 4.0);
  Assert.AreEqual(3.0, V.X, EPSILON);
  Assert.AreEqual(4.0, V.Y, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Length;
var
  V: TVector2;
begin
  V := TVector2.Create(3.0, 4.0);
  Assert.AreEqual(5.0, V.Length, EPSILON);
  Assert.AreEqual(25.0, V.LengthSquared, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Normalize;
var
  V, N: TVector2;
begin
  V := TVector2.Create(3.0, 4.0);
  N := V.Normalize;
  Assert.AreEqual(1.0, N.Length, EPSILON);
  Assert.AreEqual(0.6, N.X, EPSILON);
  Assert.AreEqual(0.8, N.Y, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Dot;
var
  V1, V2: TVector2;
begin
  V1 := TVector2.Create(1.0, 2.0);
  V2 := TVector2.Create(3.0, 4.0);
  Assert.AreEqual(11.0, V1.Dot(V2), EPSILON); // 1*3 + 2*4 = 11
end;

procedure TTestDeepBaseMath.TestVector2Cross;
var
  V1, V2: TVector2;
begin
  V1 := TVector2.Create(1.0, 0.0);
  V2 := TVector2.Create(0.0, 1.0);
  Assert.AreEqual(1.0, V1.Cross(V2), EPSILON); // 1*1 - 0*0 = 1
end;

procedure TTestDeepBaseMath.TestVector2Distance;
var
  V1, V2: TVector2;
begin
  V1 := TVector2.Create(0.0, 0.0);
  V2 := TVector2.Create(3.0, 4.0);
  Assert.AreEqual(5.0, V1.Distance(V2), EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Operators;
var
  V1, V2, R: TVector2;
begin
  V1 := TVector2.Create(1.0, 2.0);
  V2 := TVector2.Create(3.0, 4.0);

  R := V1 + V2;
  Assert.AreEqual(4.0, R.X, EPSILON);
  Assert.AreEqual(6.0, R.Y, EPSILON);

  R := V2 - V1;
  Assert.AreEqual(2.0, R.X, EPSILON);
  Assert.AreEqual(2.0, R.Y, EPSILON);

  R := V1 * 2.0;
  Assert.AreEqual(2.0, R.X, EPSILON);
  Assert.AreEqual(4.0, R.Y, EPSILON);

  R := V2 / 2.0;
  Assert.AreEqual(1.5, R.X, EPSILON);
  Assert.AreEqual(2.0, R.Y, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Lerp;
var
  V1, V2, R: TVector2;
begin
  V1 := TVector2.Create(0.0, 0.0);
  V2 := TVector2.Create(10.0, 20.0);

  R := V1.Lerp(V2, 0.0);
  Assert.AreEqual(0.0, R.X, EPSILON);
  Assert.AreEqual(0.0, R.Y, EPSILON);

  R := V1.Lerp(V2, 0.5);
  Assert.AreEqual(5.0, R.X, EPSILON);
  Assert.AreEqual(10.0, R.Y, EPSILON);

  R := V1.Lerp(V2, 1.0);
  Assert.AreEqual(10.0, R.X, EPSILON);
  Assert.AreEqual(20.0, R.Y, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector2Rotate;
var
  V, R: TVector2;
begin
  V := TVector2.Create(1.0, 0.0);
  R := V.Rotate(Pi / 2); // 90 degrees
  Assert.AreEqual(0.0, R.X, EPSILON);
  Assert.AreEqual(1.0, R.Y, EPSILON);
end;

// TVector3 Tests

procedure TTestDeepBaseMath.TestVector3Create;
var
  V: TVector3;
begin
  V := TVector3.Create(1.0, 2.0, 3.0);
  Assert.AreEqual(1.0, V.X, EPSILON);
  Assert.AreEqual(2.0, V.Y, EPSILON);
  Assert.AreEqual(3.0, V.Z, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector3Length;
var
  V: TVector3;
begin
  V := TVector3.Create(1.0, 2.0, 2.0);
  Assert.AreEqual(3.0, V.Length, EPSILON); // sqrt(1+4+4) = 3
end;

procedure TTestDeepBaseMath.TestVector3Normalize;
var
  V, N: TVector3;
begin
  V := TVector3.Create(0.0, 0.0, 5.0);
  N := V.Normalize;
  Assert.AreEqual(1.0, N.Length, EPSILON);
  Assert.AreEqual(0.0, N.X, EPSILON);
  Assert.AreEqual(0.0, N.Y, EPSILON);
  Assert.AreEqual(1.0, N.Z, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector3Dot;
var
  V1, V2: TVector3;
begin
  V1 := TVector3.Create(1.0, 2.0, 3.0);
  V2 := TVector3.Create(4.0, 5.0, 6.0);
  Assert.AreEqual(32.0, V1.Dot(V2), EPSILON); // 1*4 + 2*5 + 3*6 = 32
end;

procedure TTestDeepBaseMath.TestVector3Cross;
var
  V1, V2, R: TVector3;
begin
  V1 := TVector3.Create(1.0, 0.0, 0.0);
  V2 := TVector3.Create(0.0, 1.0, 0.0);
  R := V1.Cross(V2);
  Assert.AreEqual(0.0, R.X, EPSILON);
  Assert.AreEqual(0.0, R.Y, EPSILON);
  Assert.AreEqual(1.0, R.Z, EPSILON);
end;

procedure TTestDeepBaseMath.TestVector3Operators;
var
  V1, V2, R: TVector3;
begin
  V1 := TVector3.Create(1.0, 2.0, 3.0);
  V2 := TVector3.Create(4.0, 5.0, 6.0);

  R := V1 + V2;
  Assert.AreEqual(5.0, R.X, EPSILON);
  Assert.AreEqual(7.0, R.Y, EPSILON);
  Assert.AreEqual(9.0, R.Z, EPSILON);

  R := V1 * 2.0;
  Assert.AreEqual(2.0, R.X, EPSILON);
  Assert.AreEqual(4.0, R.Y, EPSILON);
  Assert.AreEqual(6.0, R.Z, EPSILON);
end;

// TMatrix2 Tests

procedure TTestDeepBaseMath.TestMatrix2Identity;
var
  M: TMatrix2;
begin
  M := TMatrix2.Identity;
  Assert.AreEqual(1.0, M.M[0,0], EPSILON);
  Assert.AreEqual(0.0, M.M[0,1], EPSILON);
  Assert.AreEqual(0.0, M.M[1,0], EPSILON);
  Assert.AreEqual(1.0, M.M[1,1], EPSILON);
end;

procedure TTestDeepBaseMath.TestMatrix2Determinant;
var
  M: TMatrix2;
begin
  M := TMatrix2.Create(1.0, 2.0, 3.0, 4.0);
  Assert.AreEqual(-2.0, M.Determinant, EPSILON); // 1*4 - 2*3 = -2
end;

procedure TTestDeepBaseMath.TestMatrix2Inverse;
var
  M, Inv, Result: TMatrix2;
begin
  M := TMatrix2.Create(4.0, 7.0, 2.0, 6.0);
  Inv := M.Inverse;
  Result := M * Inv;
  Assert.AreEqual(1.0, Result.M[0,0], EPSILON);
  Assert.AreEqual(0.0, Result.M[0,1], EPSILON);
  Assert.AreEqual(0.0, Result.M[1,0], EPSILON);
  Assert.AreEqual(1.0, Result.M[1,1], EPSILON);
end;

procedure TTestDeepBaseMath.TestMatrix2Rotation;
var
  M: TMatrix2;
  V, R: TVector2;
begin
  M := TMatrix2.Rotation(Pi / 2); // 90 degrees
  V := TVector2.Create(1.0, 0.0);
  R := M.Transform(V);
  Assert.AreEqual(0.0, R.X, EPSILON);
  Assert.AreEqual(1.0, R.Y, EPSILON);
end;

procedure TTestDeepBaseMath.TestMatrix2Transform;
var
  M: TMatrix2;
  V, R: TVector2;
begin
  M := TMatrix2.Scale(2.0, 3.0);
  V := TVector2.Create(1.0, 1.0);
  R := M.Transform(V);
  Assert.AreEqual(2.0, R.X, EPSILON);
  Assert.AreEqual(3.0, R.Y, EPSILON);
end;

// TMatrix3 Tests

procedure TTestDeepBaseMath.TestMatrix3Identity;
var
  M: TMatrix3;
begin
  M := TMatrix3.Identity;
  Assert.AreEqual(1.0, M.M[0,0], EPSILON);
  Assert.AreEqual(1.0, M.M[1,1], EPSILON);
  Assert.AreEqual(1.0, M.M[2,2], EPSILON);
end;

procedure TTestDeepBaseMath.TestMatrix3Determinant;
var
  M: TMatrix3;
begin
  M := TMatrix3.Identity;
  Assert.AreEqual(1.0, M.Determinant, EPSILON);
end;

procedure TTestDeepBaseMath.TestMatrix3Multiply;
var
  A, B, R: TMatrix3;
begin
  A := TMatrix3.Identity;
  B := TMatrix3.Identity;
  R := A * B;
  Assert.AreEqual(1.0, R.M[0,0], EPSILON);
  Assert.AreEqual(1.0, R.M[1,1], EPSILON);
  Assert.AreEqual(1.0, R.M[2,2], EPSILON);
end;

// TStatistics Tests

procedure TTestDeepBaseMath.TestStatisticsMean;
var
  Values: array of Double;
begin
  Values := [1.0, 2.0, 3.0, 4.0, 5.0];
  Assert.AreEqual(3.0, TStatistics.Mean(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsMedian;
var
  Values: array of Double;
begin
  Values := [1.0, 2.0, 3.0, 4.0, 5.0];
  Assert.AreEqual(3.0, TStatistics.Median(Values), EPSILON);

  Values := [1.0, 2.0, 3.0, 4.0];
  Assert.AreEqual(2.5, TStatistics.Median(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsMode;
var
  Values: array of Double;
begin
  Values := [1.0, 2.0, 2.0, 3.0, 4.0];
  Assert.AreEqual(2.0, TStatistics.Mode(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsVariance;
var
  Values: array of Double;
begin
  Values := [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
  Assert.AreEqual(4.0, TStatistics.PopulationVariance(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsStdDev;
var
  Values: array of Double;
begin
  Values := [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0];
  Assert.AreEqual(2.0, TStatistics.PopulationStdDev(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsMinMax;
var
  Values: array of Double;
begin
  Values := [3.0, 1.0, 4.0, 1.0, 5.0, 9.0, 2.0, 6.0];
  Assert.AreEqual(1.0, TStatistics.Min(Values), EPSILON);
  Assert.AreEqual(9.0, TStatistics.Max(Values), EPSILON);
  Assert.AreEqual(8.0, TStatistics.Range(Values), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsPercentile;
var
  Values: array of Double;
begin
  Values := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
  Assert.AreEqual(5.5, TStatistics.Percentile(Values, 50), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsCorrelation;
var
  X, Y: array of Double;
begin
  X := [1.0, 2.0, 3.0, 4.0, 5.0];
  Y := [2.0, 4.0, 6.0, 8.0, 10.0];
  Assert.AreEqual(1.0, TStatistics.Correlation(X, Y), EPSILON);
end;

procedure TTestDeepBaseMath.TestStatisticsLinearRegression;
var
  X, Y: array of Double;
  Slope, Intercept, R2: Double;
begin
  X := [1.0, 2.0, 3.0, 4.0, 5.0];
  Y := [2.0, 4.0, 6.0, 8.0, 10.0];
  TStatistics.LinearRegression(X, Y, Slope, Intercept, R2);
  Assert.AreEqual(2.0, Slope, EPSILON);
  Assert.AreEqual(0.0, Intercept, EPSILON);
  Assert.AreEqual(1.0, R2, EPSILON);
end;

// TInterpolation Tests

procedure TTestDeepBaseMath.TestInterpolationLinear;
begin
  Assert.AreEqual(0.0, TInterpolation.Linear(0.0, 10.0, 0.0), EPSILON);
  Assert.AreEqual(5.0, TInterpolation.Linear(0.0, 10.0, 0.5), EPSILON);
  Assert.AreEqual(10.0, TInterpolation.Linear(0.0, 10.0, 1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestInterpolationCosine;
begin
  Assert.AreEqual(0.0, TInterpolation.Cosine(0.0, 10.0, 0.0), EPSILON);
  Assert.AreEqual(10.0, TInterpolation.Cosine(0.0, 10.0, 1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestInterpolationCubic;
begin
  Assert.AreEqual(0.0, TInterpolation.Cubic(0.0, 0.0, 10.0, 10.0, 0.0), EPSILON);
  Assert.AreEqual(10.0, TInterpolation.Cubic(0.0, 0.0, 10.0, 10.0, 1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestInterpolationSmoothstep;
begin
  Assert.AreEqual(0.0, TInterpolation.Smoothstep(0.0, 10.0, 0.0), EPSILON);
  Assert.AreEqual(0.5, TInterpolation.Smoothstep(0.0, 10.0, 5.0), EPSILON);
  Assert.AreEqual(1.0, TInterpolation.Smoothstep(0.0, 10.0, 10.0), EPSILON);
end;

// TEasing Tests

procedure TTestDeepBaseMath.TestEasingLinear;
begin
  Assert.AreEqual(0.0, TEasing.Linear(0.0), EPSILON);
  Assert.AreEqual(0.5, TEasing.Linear(0.5), EPSILON);
  Assert.AreEqual(1.0, TEasing.Linear(1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestEasingQuadIn;
begin
  Assert.AreEqual(0.0, TEasing.QuadIn(0.0), EPSILON);
  Assert.AreEqual(0.25, TEasing.QuadIn(0.5), EPSILON);
  Assert.AreEqual(1.0, TEasing.QuadIn(1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestEasingQuadOut;
begin
  Assert.AreEqual(0.0, TEasing.QuadOut(0.0), EPSILON);
  Assert.AreEqual(0.75, TEasing.QuadOut(0.5), EPSILON);
  Assert.AreEqual(1.0, TEasing.QuadOut(1.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestEasingSineIn;
begin
  Assert.AreEqual(0.0, TEasing.SineIn(0.0), EPSILON);
  Assert.AreEqual(1.0, TEasing.SineIn(1.0), EPSILON);
end;

// TRandomDist Tests

procedure TTestDeepBaseMath.TestRandomUniform;
var
  I: Integer;
  V: Double;
begin
  for I := 1 to 100 do
  begin
    V := TRandomDist.Uniform(0.0, 1.0);
    Assert.IsTrue((V >= 0.0) and (V <= 1.0), 'Uniform value out of range');
  end;
end;

procedure TTestDeepBaseMath.TestRandomNormal;
var
  I: Integer;
  Values: array of Double;
  Mean, StdDev: Double;
begin
  SetLength(Values, 1000);
  for I := 0 to High(Values) do
    Values[I] := TRandomDist.Normal(0.0, 1.0);

  Mean := TStatistics.Mean(Values);
  StdDev := TStatistics.StdDev(Values);

  Assert.IsTrue(Abs(Mean) < 0.1, 'Normal mean not close to 0');
  Assert.IsTrue(Abs(StdDev - 1.0) < 0.1, 'Normal stddev not close to 1');
end;

procedure TTestDeepBaseMath.TestRandomShuffle;
var
  Arr: TArray<Integer>;
  I: Integer;
  AllSame: Boolean;
begin
  SetLength(Arr, 10);
  for I := 0 to 9 do
    Arr[I] := I;

  TRandomDist.Shuffle<Integer>(Arr);

  AllSame := True;
  for I := 0 to 9 do
    if Arr[I] <> I then
    begin
      AllSame := False;
      Break;
    end;

  Assert.IsFalse(AllSame, 'Shuffle did not change array');
end;

// TMathUtils Tests

procedure TTestDeepBaseMath.TestMathClamp;
begin
  Assert.AreEqual(5.0, TMathUtils.Clamp(5.0, 0.0, 10.0), EPSILON);
  Assert.AreEqual(0.0, TMathUtils.Clamp(-5.0, 0.0, 10.0), EPSILON);
  Assert.AreEqual(10.0, TMathUtils.Clamp(15.0, 0.0, 10.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestMathWrap;
begin
  Assert.AreEqual(0.0, TMathUtils.Wrap(0.0, 0.0, 10.0), EPSILON);
  Assert.AreEqual(5.0, TMathUtils.Wrap(5.0, 0.0, 10.0), EPSILON);
  Assert.AreEqual(2.0, TMathUtils.Wrap(12.0, 0.0, 10.0), EPSILON);
end;

procedure TTestDeepBaseMath.TestMathApproximately;
begin
  Assert.IsTrue(TMathUtils.Approximately(1.0, 1.0));
  Assert.IsTrue(TMathUtils.Approximately(1.0, 1.0 + 5E-11));
  Assert.IsFalse(TMathUtils.Approximately(1.0, 2.0));
end;

procedure TTestDeepBaseMath.TestMathGCD;
begin
  Assert.AreEqual(Int64(6), TMathUtils.GCD(12, 18));
  Assert.AreEqual(Int64(1), TMathUtils.GCD(17, 23));
  Assert.AreEqual(Int64(5), TMathUtils.GCD(0, 5));
end;

procedure TTestDeepBaseMath.TestMathLCM;
begin
  Assert.AreEqual(Int64(36), TMathUtils.LCM(12, 18));
  Assert.AreEqual(Int64(12), TMathUtils.LCM(4, 6));
end;

procedure TTestDeepBaseMath.TestMathFactorial;
begin
  Assert.AreEqual(Int64(1), TMathUtils.Factorial(0));
  Assert.AreEqual(Int64(1), TMathUtils.Factorial(1));
  Assert.AreEqual(Int64(120), TMathUtils.Factorial(5));
  Assert.AreEqual(Int64(3628800), TMathUtils.Factorial(10));
end;

procedure TTestDeepBaseMath.TestMathIsPrime;
begin
  Assert.IsFalse(TMathUtils.IsPrime(1));
  Assert.IsTrue(TMathUtils.IsPrime(2));
  Assert.IsTrue(TMathUtils.IsPrime(3));
  Assert.IsFalse(TMathUtils.IsPrime(4));
  Assert.IsTrue(TMathUtils.IsPrime(17));
  Assert.IsFalse(TMathUtils.IsPrime(100));
end;

procedure TTestDeepBaseMath.TestMathFibonacci;
begin
  Assert.AreEqual(Int64(0), TMathUtils.Fibonacci(0));
  Assert.AreEqual(Int64(1), TMathUtils.Fibonacci(1));
  Assert.AreEqual(Int64(1), TMathUtils.Fibonacci(2));
  Assert.AreEqual(Int64(55), TMathUtils.Fibonacci(10));
end;

procedure TTestDeepBaseMath.TestMathDegRad;
begin
  Assert.AreEqual(Pi, TMathUtils.DegToRad(180.0), EPSILON);
  Assert.AreEqual(180.0, TMathUtils.RadToDeg(Pi), EPSILON);
end;
initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseMath);
end.
