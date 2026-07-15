unit DeepBase.Math.Interpolation;

{*******************************************************************************
  DeepBase Math — Easing Functions
  Extracted from DeepBase.Math to keep the facade under 800 lines.

  Contains:
  - TEasing: animation easing functions (quadratic, cubic, quartic, quintic,
    sine, exponential, circular, elastic, back, bounce)

  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Math, DeepBase.Math;

type
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

implementation

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

end.
