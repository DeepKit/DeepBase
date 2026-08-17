unit DeepBase.Config.Upload;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.URLClient,
  DeepBase.Net.Transport;

type
  EConfigUploadError = class(Exception)
  private
    FStatusCode: Integer;
    FResponseBody: string;
  public
    constructor Create(AStatusCode: Integer; const AMessage,
      AResponseBody: string);
    property StatusCode: Integer read FStatusCode;
    property ResponseBody: string read FResponseBody;
  end;

  TConfigUploadResult = record
    StatusCode: Integer;
    ResponseBody: string;
    ProviderId: Int64;
    ProviderKey: string;
    Version: string;
    WasPublished: Boolean;
    Idempotent: Boolean;
    IdempotencyKey: string;
    ConfigSha256: string;
    ExistingSha256: string;
    Attempts: Integer;
    function IsSuccess: Boolean;
  end;

  TConfigUploadSleepProc = reference to procedure(AMilliseconds: Cardinal);

  TConfigUploader = class
  private
    FBaseUrl: string;
    FApiKey: string;
    FTimeoutMs: Integer;
    FMaxRetries: Integer;
    FTransport: IDeepBaseHttpTransport;
    FSleepProc: TConfigUploadSleepProc;
    function BuildUrl: string;
    function NewIdempotencyKey: string;
    function BuildRequestBody(const AProviderKey, AVersion,
      ACanonicalConfig, AConfigSha256, ANote: string;
      APublish: Boolean): string;
    procedure ParseResponse(var AResult: TConfigUploadResult);
    function RetryDelayMs(AAttempt: Integer;
      const AResponse: TDeepBaseHttpTransportResponse): Cardinal;
  public
    constructor Create(const ABaseUrl, AApiKey: string;
      const ATransport: IDeepBaseHttpTransport = nil);
    class function CreateFromEnvironment(const ABaseUrl: string;
      const AEnvironmentName: string = 'DK_PUBLISH_KEY';
      const ATransport: IDeepBaseHttpTransport = nil): TConfigUploader; static;
    function Upload(const AProviderKey, AVersion: string;
      AConfigJson: TJSONObject; const ANote: string; APublish: Boolean;
      out AResponse: string): Boolean; overload;
    function Upload(const AProviderKey, AVersion: string;
      AConfigJson: TJSONObject; const ANote: string; APublish: Boolean;
      out AResult: TConfigUploadResult;
      const AIdempotencyKey: string = ''): Boolean; overload;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
    property SleepProc: TConfigUploadSleepProc read FSleepProc write FSleepProc;
  end;

  TJsonCanonicalizer = class sealed
  private
    class function CanonicalizeValue(AValue: TJSONValue): string; static;
  public
    class function Canonicalize(AValue: TJSONValue): string; static;
    class function Sha256(AValue: TJSONValue): string; static;
  end;

implementation

uses
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Character,
  DeepBase.Crypto.Hash;

const
  SConfigUploadPath = '/dk/providers/configs';
  SJsonContentType = 'application/json';
  CMaxConfigBytes = 512 * 1024;

function HeaderValue(const AHeaders: TNetHeaders; const AName: string): string;
var
  Header: TNameValuePair;
begin
  Result := '';
  for Header in AHeaders do
    if SameText(Header.Name, AName) then
      Exit(Header.Value);
end;

procedure AddHeader(var AHeaders: TNetHeaders; const AName, AValue: string);
var
  Index: Integer;
begin
  if AValue = '' then
    Exit;
  Index := Length(AHeaders);
  SetLength(AHeaders, Index + 1);
  AHeaders[Index] := TNameValuePair.Create(AName, AValue);
end;

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

{ EConfigUploadError }

constructor EConfigUploadError.Create(AStatusCode: Integer;
  const AMessage, AResponseBody: string);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
  FResponseBody := AResponseBody;
end;

{ TConfigUploadResult }

function TConfigUploadResult.IsSuccess: Boolean;
begin
  Result := (StatusCode >= 200) and (StatusCode < 300);
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

{ TConfigUploader }

constructor TConfigUploader.Create(const ABaseUrl, AApiKey: string;
  const ATransport: IDeepBaseHttpTransport);
begin
  inherited Create;
  FBaseUrl := ABaseUrl.TrimRight(['/']);
  FApiKey := AApiKey.Trim;
  if FBaseUrl = '' then
    raise EArgumentException.Create('Config uploader base URL is required');
  if not FBaseUrl.StartsWith('https://', True) and
     not FBaseUrl.StartsWith('http://localhost', True) and
     not FBaseUrl.StartsWith('http://127.0.0.1', True) then
    raise EArgumentException.Create('Config uploader requires HTTPS (except localhost tests)');
  if FApiKey = '' then
    raise EArgumentException.Create('Config uploader API key is required');
  FTimeoutMs := 30000;
  FMaxRetries := 3;
  if ATransport <> nil then
    FTransport := ATransport
  else
    FTransport := TDeepBaseSystemNetTransport.Create;
  FSleepProc :=
    procedure(AMilliseconds: Cardinal)
    begin
      TThread.Sleep(AMilliseconds);
    end;
end;

class function TConfigUploader.CreateFromEnvironment(const ABaseUrl,
  AEnvironmentName: string; const ATransport: IDeepBaseHttpTransport): TConfigUploader;
var
  ApiKey: string;
begin
  ApiKey := GetEnvironmentVariable(AEnvironmentName);
  if ApiKey.Trim = '' then
    raise EConfigUploadError.Create(0,
      Format('Required environment variable %s is empty', [AEnvironmentName]), '');
  Result := TConfigUploader.Create(ABaseUrl, ApiKey, ATransport);
end;

function TConfigUploader.BuildUrl: string;
begin
  Result := FBaseUrl + SConfigUploadPath;
end;

function TConfigUploader.NewIdempotencyKey: string;
var
  Guid: TGUID;
begin
  if CreateGUID(Guid) <> S_OK then
    raise EConfigUploadError.Create(0, 'Failed to generate Idempotency-Key', '');
  Result := GUIDToString(Guid).Trim(['{', '}']).ToLower;
end;

function TConfigUploader.BuildRequestBody(const AProviderKey, AVersion,
  ACanonicalConfig, AConfigSha256, ANote: string; APublish: Boolean): string;
begin
  Result := '{' +
    '"provider_key":' + JsonString(AProviderKey) + ',' +
    '"version":' + JsonString(AVersion) + ',' +
    '"config_json":' + ACanonicalConfig + ',' +
    '"sha256":' + JsonString(AConfigSha256) + ',' +
    '"note":' + JsonString(ANote) + ',' +
    '"publish":' + LowerCase(BoolToStr(APublish, True)) + '}';
end;

procedure TConfigUploader.ParseResponse(var AResult: TConfigUploadResult);
var
  Value: TJSONValue;
  Obj: TJSONObject;
begin
  if AResult.ResponseBody.Trim = '' then Exit;
  Value := TJSONObject.ParseJSONValue(AResult.ResponseBody);
  try
    if not (Value is TJSONObject) then Exit;
    Obj := TJSONObject(Value);
    if Obj.Values['id'] is TJSONNumber then
      AResult.ProviderId := TJSONNumber(Obj.Values['id']).AsInt64;
    if Obj.Values['provider_key'] <> nil then
      AResult.ProviderKey := Obj.Values['provider_key'].Value;
    if Obj.Values['version'] <> nil then
      AResult.Version := Obj.Values['version'].Value;
    if Obj.Values['published'] is TJSONBool then
      AResult.WasPublished := TJSONBool(Obj.Values['published']).AsBoolean;
    if Obj.Values['idempotent'] is TJSONBool then
      AResult.Idempotent := TJSONBool(Obj.Values['idempotent']).AsBoolean;
    if Obj.Values['existing_sha256'] <> nil then
      AResult.ExistingSha256 := Obj.Values['existing_sha256'].Value;
  finally
    Value.Free;
  end;
end;

function TConfigUploader.RetryDelayMs(AAttempt: Integer;
  const AResponse: TDeepBaseHttpTransportResponse): Cardinal;
var
  RetryAfter: string;
  Seconds: Integer;
begin
  RetryAfter := HeaderValue(AResponse.Headers, 'Retry-After');
  if TryStrToInt(RetryAfter, Seconds) and (Seconds >= 0) then
    Exit(Cardinal(Seconds) * 1000);
  Result := Cardinal(1 shl AAttempt) * 2000;
end;

function TConfigUploader.Upload(const AProviderKey, AVersion: string;
  AConfigJson: TJSONObject; const ANote: string; APublish: Boolean;
  out AResponse: string): Boolean;
var
  UploadResult: TConfigUploadResult;
begin
  Result := Upload(AProviderKey, AVersion, AConfigJson, ANote, APublish,
    UploadResult);
  AResponse := UploadResult.ResponseBody;
end;

function TConfigUploader.Upload(const AProviderKey, AVersion: string;
  AConfigJson: TJSONObject; const ANote: string; APublish: Boolean;
  out AResult: TConfigUploadResult; const AIdempotencyKey: string): Boolean;
var
  Canonical, Body, Key: string;
  Request: TDeepBaseHttpTransportRequest;
  Response: TDeepBaseHttpTransportResponse;
  Attempt: Integer;
begin
  AResult := Default(TConfigUploadResult);
  if AProviderKey.Trim = '' then
    raise EArgumentException.Create('provider_key is required');
  if AVersion.Trim = '' then
    raise EArgumentException.Create('version is required');
  if AConfigJson = nil then
    raise EArgumentNilException.Create('config_json is required');

  Canonical := TJsonCanonicalizer.Canonicalize(AConfigJson);
  if Length(TEncoding.UTF8.GetBytes(Canonical)) > CMaxConfigBytes then
    raise EConfigUploadError.Create(413, 'config_json exceeds 512KB', '');
  AResult.ConfigSha256 := THashUtils.SHA256(Canonical);
  Key := AIdempotencyKey.Trim;
  if Key = '' then Key := NewIdempotencyKey;
  AResult.IdempotencyKey := Key;
  Body := BuildRequestBody(AProviderKey, AVersion, Canonical,
    AResult.ConfigSha256, ANote, APublish);

  for Attempt := 0 to FMaxRetries do
  begin
    AResult.Attempts := Attempt + 1;
    Request := TDeepBaseHttpTransportRequest.Create(dbhmPost, BuildUrl);
    Request.Body := Body;
    Request.BodyBytes := TEncoding.UTF8.GetBytes(Body);
    Request.ContentType := SJsonContentType;
    Request.TimeoutMs := FTimeoutMs;
    AddHeader(Request.Headers, 'Authorization', 'Bearer ' + FApiKey);
    AddHeader(Request.Headers, 'Idempotency-Key', Key);
    AddHeader(Request.Headers, 'Content-Type', SJsonContentType);
    try
      Response := FTransport.Send(Request);
    except
      on E: EDeepBaseNetTransportError do
      begin
        if Attempt >= FMaxRetries then
          raise EConfigUploadError.Create(0,
            Format('Config upload failed after %d attempts: %s',
              [Attempt + 1, E.Message]), '');
        FSleepProc(RetryDelayMs(Attempt, Default(TDeepBaseHttpTransportResponse)));
        Continue;
      end;
    end;

    AResult.StatusCode := Response.StatusCode;
    AResult.ResponseBody := Response.Body;
    ParseResponse(AResult);
    if AResult.IsSuccess then Exit(True);

    if ((Response.StatusCode = 429) or (Response.StatusCode >= 500)) and
       (Attempt < FMaxRetries) then
    begin
      FSleepProc(RetryDelayMs(Attempt, Response));
      Continue;
    end;

    if Response.StatusCode = 409 then
      raise EConfigUploadError.Create(409,
        Format('Config version conflict (existing_sha256=%s)',
          [AResult.ExistingSha256]), Response.Body);
    raise EConfigUploadError.Create(Response.StatusCode,
      Format('Config upload rejected with HTTP %d', [Response.StatusCode]),
      Response.Body);
  end;
  Result := False;
end;

end.
















