unit DeepBase.Math.Geometry;

{*******************************************************************************
  DeepBase Math — Vector & Matrix Geometry
  Extracted from DeepBase.Math to keep the facade lean.

  Contains:
  - TVector2: 2D vector with arithmetic, normalization, rotation, reflection
  - TVector3: 3D vector with arithmetic, normalization, rotation, reflection
  - TMatrix2: 2x2 matrix with determinant, transpose, inverse, transform
  - TMatrix3: 3x3 matrix with determinant, transpose, inverse, transform

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, DeepBase.Math;

type
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

implementation

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
  MIN_DETERMINANT = 1e-15;
begin
  LDet := Determinant;

  if Abs(LDet) < MIN_DETERMINANT then
    raise EMathException.CreateFmt('Matrix is singular or near-singular (det=%.2e)', [LDet]);

  var InvDet := 1.0 / LDet;
  if not IsFinite(InvDet) then
    raise EMathException.Create('Matrix inversion resulted in infinite values');

  Result := TMatrix2.Create(
    M[1, 1] * InvDet,
    -M[0, 1] * InvDet,
    -M[1, 0] * InvDet,
    M[0, 0] * InvDet
  );

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
  MIN_DETERMINANT = 1e-15;
begin
  LDet := Determinant;

  if Abs(LDet) < MIN_DETERMINANT then
    raise EMathException.CreateFmt('Matrix is singular or near-singular (det=%.2e)', [LDet]);

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

end.
