unit DeepBase.Math.Random;

{*******************************************************************************
  DeepBase Math — Random Distribution Generators & Secure Random
  Extracted from DeepBase.Math to keep the facade under 800 lines.

  Contains:
  - TRandomDist: random distribution generators (uniform, normal, exponential,
    Poisson, binomial, geometric, triangular, log-normal, beta, gamma,
    chi-squared, shuffle, weighted choice)
  - TSecureRandom: CSPRNG backed by BCryptGenRandom (OS entropy)

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, System.SyncObjs, Winapi.Windows,
  DeepBase.Exceptions,
  DeepBase.Math, DeepBase.Math.Geometry, DeepBase.Math.Statistics;

type
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

implementation

const
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;

function BCryptGenRandom(hAlgorithm: THandle; pbBuffer: PByte;
  cbBuffer: Cardinal; dwFlags: Cardinal): Integer; stdcall;
  external 'bcrypt.dll';

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

  // ܱ߽
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

end.
