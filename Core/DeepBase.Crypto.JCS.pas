unit DeepBase.Crypto.JCS;

{ ============================================================================
  DeepBase.Crypto.JCS - RFC 8785 JSON Canonicalization Scheme (JCS)

  79.protocol §13：所有制品（参数、规则、DSL、JS、DLL、PluginHost、EXE）
  的统一 Manifest 使用同一 JCS 规范化后再签名/哈希，保证跨实现一致性。

  本单元由 Features/DeepBase.Config.Upload.pas 的 TJsonCanonicalizer 及辅助
  函数 1:1 抽离而来，保持行为不变（勿在本单元做行为重构；如需修改请先改
  测试基线）。
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Crypto.Hash;

type
  { RFC 8785 JCS 规范化器：输入 TJSONValue，输出规范 JSON 字符串。 }
  TJsonCanonicalizer = class sealed
  private
    class function CanonicalizeValue(AValue: TJSONValue): string; static;
  public
    class function Canonicalize(AValue: TJSONValue): string; static;
    class function Sha256(AValue: TJSONValue): string; static;
  end;

  { RFC 8785 §3.2.2.2 JSON 字符串转义（JCS 公开组件，供制品统一复用）。 }
  function JsonString(const AValue: string): string;

implementation

uses
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Character;

function JsonString(const AValue: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '"';
  I := 1;
  while I <= Length(AValue) do
  begin
    C := AValue[I];
    case Ord(C) of
      $08: Result := Result + '\b';
      $09: Result := Result + '\t';
      $0A: Result := Result + '\n';
      $0C: Result := Result + '\f';
      $0D: Result := Result + '\r';
      $22: Result := Result + '\"';
      $5C: Result := Result + '\\';
      $00..$07, $0B, $0E..$1F:
        Result := Result + '\u' + LowerCase(IntToHex(Ord(C), 4));
      $D800..$DBFF:
        begin
          if (I = Length(AValue)) or
             (Ord(AValue[I + 1]) < $DC00) or (Ord(AValue[I + 1]) > $DFFF) then
            raise EArgumentException.Create('JCS rejects an unpaired high surrogate');
          Result := Result + C + AValue[I + 1];
          Inc(I);
        end;
      $DC00..$DFFF:
        raise EArgumentException.Create('JCS rejects an unpaired low surrogate');
    else
      Result := Result + C;
    end;
    Inc(I);
  end;
  Result := Result + '"';
end;

function SameDoubleBits(A, B: Double): Boolean;
var
  Fmt: TFormatSettings;
begin
  Result := FloatToStrF(A, ffGeneral, 17, 0, Fmt) =
    FloatToStrF(B, ffGeneral, 17, 0, Fmt);
    FloatToStrF(B, ffGeneral, 16, 0, Fmt);
end;
function NormalizeExponent(const AValue: string): string;
var
  P, Exponent: Integer;
  Mantissa, ExpText: string;
begin
  Result := LowerCase(AValue);
  P := Pos('e', Result);
  if P = 0 then
    Exit;
  Mantissa := Copy(Result, 1, P - 1);
  ExpText := Copy(Result, P + 1, MaxInt);
  Exponent := StrToInt(ExpText);
  if Exponent >= 0 then
    Result := Mantissa + 'e+' + IntToStr(Exponent)
  else
    Result := Mantissa + 'e' + IntToStr(Exponent);
end;

function ScientificToDecimal(const AValue: string): string;
var
  EPos, DotPos, Exponent, DecimalPos: Integer;
  Mantissa, Digits: string;
  Negative: Boolean;
begin
  EPos := Pos('e', LowerCase(AValue));
  if EPos = 0 then
    Exit(AValue);
  Mantissa := Copy(AValue, 1, EPos - 1);
  Exponent := StrToInt(Copy(AValue, EPos + 1, MaxInt));
  Negative := (Mantissa <> '') and (Mantissa[1] = '-');
  if Negative then
    Delete(Mantissa, 1, 1);
  DotPos := Pos('.', Mantissa);
  if DotPos = 0 then
    DotPos := Length(Mantissa) + 1;
  Digits := StringReplace(Mantissa, '.', '', []);
  DecimalPos := DotPos - 1 + Exponent;
  if DecimalPos <= 0 then
    Result := '0.' + StringOfChar('0', -DecimalPos) + Digits
  else if DecimalPos >= Length(Digits) then
    Result := Digits + StringOfChar('0', DecimalPos - Length(Digits))
  else
    Result := Copy(Digits, 1, DecimalPos) + '.' +
      Copy(Digits, DecimalPos + 1, MaxInt);
  if Negative then
    Result := '-' + Result;
end;

function DecimalToScientific(const AValue: string): string;
var
  S, Digits: string;
  Negative: Boolean;
  DotPos, FirstNonZero, Exponent: Integer;
begin
  S := AValue;
  Negative := (S <> '') and (S[1] = '-');
  if Negative then
    Delete(S, 1, 1);
  DotPos := Pos('.', S);
  if DotPos = 0 then
    DotPos := Length(S) + 1;
  Digits := StringReplace(S, '.', '', []);
  FirstNonZero := 1;
  while (FirstNonZero <= Length(Digits)) and (Digits[FirstNonZero] = '0') do
    Inc(FirstNonZero);
  if FirstNonZero > Length(Digits) then
    Exit('0');
  Exponent := (DotPos - 1) - FirstNonZero;
  Delete(Digits, 1, FirstNonZero - 1);
  while (Length(Digits) > 1) and (Digits[Length(Digits)] = '0') do
    Delete(Digits, Length(Digits), 1);
  if Length(Digits) > 1 then
    Result := Digits[1] + '.' + Copy(Digits, 2, MaxInt)
  else
    Result := Digits;
  if Negative then
    Result := '-' + Result;
  if Exponent >= 0 then
    Result := Result + 'e+' + IntToStr(Exponent)
  else
    Result := Result + 'e' + IntToStr(Exponent);
end;

function CanonicalNumber(ANumber: TJSONNumber): string;
var
  Value, Parsed: Double;
  Precision, EPos, Exponent: Integer;
  Candidate, Best: string;
  Fmt: TFormatSettings;
begin
  Fmt := TFormatSettings.Invariant;
  Value := Double(StrToFloat(ANumber.Value, Fmt));
  if IsNan(Value) or IsInfinite(Value) then
    raise EArgumentException.Create('JCS rejects NaN and Infinity');
  if Value = 0 then
    Exit('0');

  Best := FloatToStrF(Value, ffGeneral, 17, 0, Fmt);
  // Select the first (most precise) spelling that round-trips to the same
  // IEEE-754 binary64 value. Delphi may round its 17-digit seed away by one
  // ULP, while the 16-digit form is the ECMAScript/JCS representation.
  for Precision := 1 to 17 do
  begin
    Candidate := FloatToStrF(Value, ffGeneral, Precision, 0, Fmt);
    if TryStrToFloat(Candidate, Parsed, Fmt) and SameDoubleBits(Value, Parsed) then
    begin
      Best := Candidate;
      Break;
    end;
  end;
  Best := LowerCase(Best);
  EPos := Pos('e', Best);
  if EPos > 0 then
  begin
    Exponent := StrToInt(Copy(Best, EPos + 1, MaxInt));
    if (Exponent >= -6) and (Exponent < 21) then
      Best := ScientificToDecimal(Best)
    else
      Best := NormalizeExponent(Best);
  end
  else
  begin
    if (Abs(Value) >= 1E21) or (Abs(Value) < 1E-6) then
      Best := DecimalToScientific(Best);
  end;
  Result := Best;
end;

function CompareUtf16(const Left, Right: string): Integer;
var
  I, L: Integer;
begin
  L := Min(Length(Left), Length(Right));
  for I := 1 to L do
  begin
    if Ord(Left[I]) < Ord(Right[I]) then Exit(-1);
    if Ord(Left[I]) > Ord(Right[I]) then Exit(1);
  end;
  Result := Length(Left) - Length(Right);
end;

{ TJsonCanonicalizer }

class function TJsonCanonicalizer.CanonicalizeValue(
  AValue: TJSONValue): string;
var
  Obj: TJSONObject;
  Arr: TJSONArray;
  Names: TList<string>;
  Pair: TJSONPair;
  Name: string;
  I: Integer;
begin
  if AValue = nil then
    raise EArgumentNilException.Create('JSON value is required');
  if AValue is TJSONObject then
  begin
    Obj := TJSONObject(AValue);
    Names := TList<string>.Create(TComparer<string>.Construct(
      function(const Left, Right: string): Integer
      begin
        Result := CompareUtf16(Left, Right);
      end));
    try
      for Pair in Obj do
      begin
        if Names.Contains(Pair.JsonString.Value) then
          raise EArgumentException.CreateFmt('JCS rejects duplicate key: %s',
            [Pair.JsonString.Value]);
        Names.Add(Pair.JsonString.Value);
      end;
      Names.Sort;
      Result := '{';
      for I := 0 to Names.Count - 1 do
      begin
        if I > 0 then Result := Result + ',';
        Name := Names[I];
        Result := Result + JsonString(Name) + ':' +
          CanonicalizeValue(Obj.Values[Name]);
      end;
      Result := Result + '}';
    finally
      Names.Free;
    end;
  end
  else if AValue is TJSONArray then
  begin
    Arr := TJSONArray(AValue);
    Result := '[';
    for I := 0 to Arr.Count - 1 do
    begin
      if I > 0 then Result := Result + ',';
      Result := Result + CanonicalizeValue(Arr.Items[I]);
    end;
    Result := Result + ']';
  end
  else if AValue is TJSONString then
    Result := JsonString(TJSONString(AValue).Value)
  else if AValue is TJSONNumber then
    Result := CanonicalNumber(TJSONNumber(AValue))
  else if AValue is TJSONTrue then
    Result := 'true'
  else if AValue is TJSONFalse then
    Result := 'false'
  else if AValue is TJSONNull then
    Result := 'null'
  else
    raise EArgumentException.CreateFmt('Unsupported JSON type: %s',
      [AValue.ClassName]);
end;

class function TJsonCanonicalizer.Canonicalize(AValue: TJSONValue): string;
begin
  Result := CanonicalizeValue(AValue);
end;

class function TJsonCanonicalizer.Sha256(AValue: TJSONValue): string;
begin
  Result := THashUtils.SHA256(Canonicalize(AValue));
end;

end.
