unit DeepBase.Payment.WeChatPay;

{*******************************************************************************
  DeepBase WeChat Pay (微信支付) Integration

  Supports:
    - Native支付 (扫码支付)
    - JSAPI支付 // TODO: restore original comment (encoding corruption)
    - H5支付 (手机网页)
    - APP支付
    - // TODO: restore original comment (encoding corruption)

  Official Docs: https://pay.weixin.qq.com/wiki/doc/apiv3/
  API Version: V3
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Payment;

type
  /// <summary>WeChat Pay trade type</summary>
  TWeChatTradeType = (wttNative, wttJSAPI, wttApp, wttH5, wttMiniProgram);

  /// <summary>WeChat Pay configuration</summary>
  TWeChatPayConfig = class(TPaymentConfig)
  private
    FAppId: string;           // TODO: restore original comment (encoding corruption)
    FMchId: string;           // TODO: restore original comment (encoding corruption)
    FApiKeyV3: string;        // APIv3 密钥
    FSerialNo: string;        // TODO: restore original comment (encoding corruption)
    FPrivateKey: string;      // 商户私钥 (PEM)
    FCertPath: string;        // 证书路径 (退款用)
    FSubAppId: string;        // TODO: restore original comment (encoding corruption)
    FSubMchId: string;        // TODO: restore original comment (encoding corruption)
    FWeChatPublicKey: string; // BUG-014 FIX: 微信平台公钥 (用于验签)
  public
    constructor Create; reintroduce;

    // BUG-019 FIX: 安全密钥存储方法重写
    procedure LoadKeysFromCredentialManager; override;
    procedure SaveKeysToCredentialManager; override;
    /// <summary>设置API密钥（自动使用安全存储）</summary>
    procedure SetApiKeyV3Secure(const AKey: string);
    /// <summary>获取API密钥（自动解密）</summary>
    function GetApiKeyV3Secure: string;
    /// <summary>设置私钥（自动使用安全存储）</summary>
    procedure SetPrivateKeySecure(const AKey: string);
    /// <summary>获取私钥（自动解密）</summary>
    function GetPrivateKeySecure: string;

    property AppId: string read FAppId write FAppId;
    property MchId: string read FMchId write FMchId;
    property ApiKeyV3: string read GetApiKeyV3Secure write SetApiKeyV3Secure;
    property SerialNo: string read FSerialNo write FSerialNo;
    property PrivateKey: string read GetPrivateKeySecure write SetPrivateKeySecure;
    property CertPath: string read FCertPath write FCertPath;
    property SubAppId: string read FSubAppId write FSubAppId;
    property SubMchId: string read FSubMchId write FSubMchId;
    property WeChatPublicKey: string read FWeChatPublicKey write FWeChatPublicKey; // BUG-014 FIX
  end;

  /// <summary>WeChat Pay client implementation (API V3)</summary>
  TWeChatPayClient = class(TPaymentClient)
  private
    function GetApiUrl: string;
    function BuildAuthorizationHeader(const AMethod, AUrl, ABody: string): string;
    function GenerateNonceStr: string;
    function DoWeChatPost(const AEndpoint: string; ABody: TJSONObject): TJSONObject;
    function DoWeChatGet(const AEndpoint: string): TJSONObject;
    function RSASign(const AContent: string): string;
    function ParseWeChatStatus(const AState: string): TPaymentStatus;
  protected
    function SignRequest(const AParams: TDictionary<string, string>): string; override;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; override;
  public
    constructor Create(AConfig: TWeChatPayConfig); reintroduce;

    // IPaymentClient
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; override;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; override;
    function CloseOrder(const AOrderNo: string): Boolean; override;
    function Refund(const ARequest: TRefundRequest): TRefundResult; override;
    function QueryRefund(const ARefundNo: string): TRefundResult; override;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; override;
    /// <summary>Verify notification with HTTP-level signature check</summary>
    function VerifyNotificationWithSignature(const ARawData, ATimestamp,
      ANonce, ASignature: string;
      out ANotification: TPaymentNotification): Boolean;
    function GetNotificationResponse(ASuccess: Boolean): string; override;

    // WeChat specific
    function CreateNativeOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateJSAPIOrder(const AOrder: TPaymentOrder; const AOpenId: string): TPaymentResult;
    function CreateH5Order(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateAppOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function BuildJSAPIPayParams(const APrepayId: string): string;
    function BuildAppPayParams(const APrepayId: string): string;
  end;

implementation

uses
  System.Hash, System.StrUtils, DeepBase.Crypto;

const
  WECHAT_API_URL = 'https://api.mch.weixin.qq.com';

{$IFDEF MSWINDOWS}
const
  BCRYPT_RSAPRIVATE_BLOB = 'RSAPRIVATEBLOB';
  BCRYPT_RSAFULLPRIVATE_BLOB = 'RSAFULLPRIVATEBLOB';
  BCRYPT_RSAPRIVATE_MAGIC = $32415352;   // 'RSA2'
  BCRYPT_RSAFULLPRIVATE_MAGIC = $33415352; // 'RSA3'

function BCryptSignHash(hKey: BCRYPT_KEY_HANDLE; pPaddingInfo: Pointer;
  pbInput: PByte; cbInput: ULONG; pbOutput: PByte; cbOutput: ULONG;
  out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

type
  TRSAPrivateKeyParts = record
    Modulus: TBytes;
    PublicExponent: TBytes;
    PrivateExponent: TBytes;
    Prime1: TBytes;
    Prime2: TBytes;
    Exponent1: TBytes;   // dp = d mod (p-1)
    Exponent2: TBytes;   // dq = d mod (q-1)
    Coefficient: TBytes; // qInv = q^-1 mod p
  end;

function TrimIntegerBytes(const AValue: TBytes): TBytes;
var
  I: Integer;
begin
  if Length(AValue) = 0 then
    Exit(nil);

  I := 0;
  while (I < Length(AValue) - 1) and (AValue[I] = 0) do
    Inc(I);

  Result := Copy(AValue, I, Length(AValue) - I);
end;

function ReadDerLength(const AData: TBytes; var APos: Integer): Integer;
var
  First, Count, I: Integer;
begin
  if APos >= Length(AData) then
    raise EPaymentSignError.Create('Invalid DER length', 'INVALID_PRIVATE_KEY', ppWeChatPay);

  First := AData[APos];
  Inc(APos);

  if (First and $80) = 0 then
    Exit(First);

  Count := First and $7F;
  if Count = 0 then
    raise EPaymentSignError.Create('Unsupported DER length form', 'INVALID_PRIVATE_KEY', ppWeChatPay);
  if APos + Count > Length(AData) then
    raise EPaymentSignError.Create('Truncated DER length', 'INVALID_PRIVATE_KEY', ppWeChatPay);

  Result := 0;
  for I := 1 to Count do
  begin
    Result := (Result shl 8) or AData[APos];
    Inc(APos);
  end;
end;

procedure ExpectDerTag(const AData: TBytes; var APos: Integer; ATag: Byte);
begin
  if APos >= Length(AData) then
    raise EPaymentSignError.Create('Unexpected DER end', 'INVALID_PRIVATE_KEY', ppWeChatPay);
  if AData[APos] <> ATag then
    raise EPaymentSignError.Create('Unexpected DER tag', 'INVALID_PRIVATE_KEY', ppWeChatPay);
  Inc(APos);
end;

function ReadDerInteger(const AData: TBytes; var APos: Integer): TBytes;
var
  LLen: Integer;
begin
  ExpectDerTag(AData, APos, $02); // INTEGER
  LLen := ReadDerLength(AData, APos);
  if (LLen < 0) or (APos + LLen > Length(AData)) then
    raise EPaymentSignError.Create('Invalid DER integer length', 'INVALID_PRIVATE_KEY', ppWeChatPay);
  Result := Copy(AData, APos, LLen);
  Inc(APos, LLen);
  Result := TrimIntegerBytes(Result);
end;

function ParsePemToDer(const APem: string): TBytes;
var
  Normalized: string;
  Lines: TArray<string>;
  L: string;
  LineText: string;
  Capture: Boolean;
  Base64Data: TStringBuilder;
begin
  Capture := False;
  Base64Data := TStringBuilder.Create;
  try
    Normalized := StringReplace(APem, #13, #10, [rfReplaceAll]);
    Lines := Normalized.Split([#10], TStringSplitOptions.ExcludeEmpty);
    for L in Lines do
    begin
      LineText := Trim(L);
      if LineText = '' then
        Continue;

      if StartsText('-----BEGIN ', LineText) then
      begin
        if (Pos('PRIVATE KEY', UpperCase(LineText)) > 0) then
          Capture := True;
        Continue;
      end;

      if StartsText('-----END ', LineText) then
      begin
        if Capture then
          Break;
        Continue;
      end;

      if Capture then
        Base64Data.Append(LineText);
    end;

    // fallback: allow plain base64 content without PEM header
    if Base64Data.Length = 0 then
      Base64Data.Append(StringReplace(StringReplace(Trim(APem), #13, '', [rfReplaceAll]), #10, '', [rfReplaceAll]));

    if Base64Data.Length = 0 then
      raise EPaymentSignError.Create('Empty private key', 'INVALID_PRIVATE_KEY', ppWeChatPay);

    Result := TEncodingUtils.Base64Decode(Base64Data.ToString);
  finally
    Base64Data.Free;
  end;
end;

function ExtractPkcs1PrivateKey(const ADer: TBytes): TBytes;
var
  Pos, Len: Integer;
begin
  Result := nil;
  if Length(ADer) = 0 then
    Exit;

  Pos := 0;
  ExpectDerTag(ADer, Pos, $30); // SEQUENCE
  Len := ReadDerLength(ADer, Pos);
  if Pos + Len > Length(ADer) then
    raise EPaymentSignError.Create('Invalid PKCS#8 sequence length', 'INVALID_PRIVATE_KEY', ppWeChatPay);

  // version
  ReadDerInteger(ADer, Pos);

  if (Pos < Length(ADer)) and (ADer[Pos] = $30) then
  begin
    // PKCS#8: skip algorithm identifier sequence
    Inc(Pos);
    Len := ReadDerLength(ADer, Pos);
    Inc(Pos, Len);

    // privateKey OCTET STRING
    ExpectDerTag(ADer, Pos, $04);
    Len := ReadDerLength(ADer, Pos);
    if Pos + Len > Length(ADer) then
      raise EPaymentSignError.Create('Invalid PKCS#8 privateKey length', 'INVALID_PRIVATE_KEY', ppWeChatPay);

    Result := Copy(ADer, Pos, Len);
    Exit;
  end;

  // already PKCS#1
  Result := ADer;
end;

function ParseRsaPrivateKey(const APkcs1Der: TBytes): TRSAPrivateKeyParts;
var
  Pos, Len: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Pos := 0;

  ExpectDerTag(APkcs1Der, Pos, $30); // SEQUENCE
  Len := ReadDerLength(APkcs1Der, Pos);
  if Pos + Len > Length(APkcs1Der) then
    raise EPaymentSignError.Create('Invalid PKCS#1 sequence length', 'INVALID_PRIVATE_KEY', ppWeChatPay);

  ReadDerInteger(APkcs1Der, Pos);             // version
  Result.Modulus := ReadDerInteger(APkcs1Der, Pos);           // n
  Result.PublicExponent := ReadDerInteger(APkcs1Der, Pos);    // e
  Result.PrivateExponent := ReadDerInteger(APkcs1Der, Pos);   // d
  Result.Prime1 := ReadDerInteger(APkcs1Der, Pos);            // p
  Result.Prime2 := ReadDerInteger(APkcs1Der, Pos);            // q
  Result.Exponent1 := ReadDerInteger(APkcs1Der, Pos);         // dp
  Result.Exponent2 := ReadDerInteger(APkcs1Der, Pos);         // dq
  Result.Coefficient := ReadDerInteger(APkcs1Der, Pos);       // qInv
end;

function BuildRsaPrivateBlob(const AParts: TRSAPrivateKeyParts): TBytes;
var
  Header: BCRYPT_RSAKEY_BLOB;
  Pos: Integer;
  BlobSize: Integer;
begin
  if (Length(AParts.Modulus) = 0) or
     (Length(AParts.PublicExponent) = 0) or
     (Length(AParts.PrivateExponent) = 0) or
     (Length(AParts.Prime1) = 0) or
     (Length(AParts.Prime2) = 0) then
    raise EPaymentSignError.Create('Incomplete RSA private key', 'INVALID_PRIVATE_KEY', ppWeChatPay);

  Header.Magic := BCRYPT_RSAFULLPRIVATE_MAGIC;
  Header.BitLength := Length(AParts.Modulus) * 8;
  Header.cbPublicExp := Length(AParts.PublicExponent);
  Header.cbModulus := Length(AParts.Modulus);
  Header.cbPrime1 := Length(AParts.Prime1);
  Header.cbPrime2 := Length(AParts.Prime2);

  // Layout: header | exp | mod | prime1 | prime2 | exp1 | exp2 | coeff | privateExp
  BlobSize := SizeOf(BCRYPT_RSAKEY_BLOB) + Header.cbPublicExp + Header.cbModulus +
    Header.cbPrime1 + Header.cbPrime2 +
    Length(AParts.Exponent1) + Length(AParts.Exponent2) +
    Length(AParts.Coefficient) + Length(AParts.PrivateExponent);

  SetLength(Result, BlobSize);
  Pos := 0;

  Move(Header, Result[Pos], SizeOf(BCRYPT_RSAKEY_BLOB));
  Inc(Pos, SizeOf(BCRYPT_RSAKEY_BLOB));

  Move(AParts.PublicExponent[0], Result[Pos], Header.cbPublicExp);
  Inc(Pos, Header.cbPublicExp);
  Move(AParts.Modulus[0], Result[Pos], Header.cbModulus);
  Inc(Pos, Header.cbModulus);
  Move(AParts.Prime1[0], Result[Pos], Header.cbPrime1);
  Inc(Pos, Header.cbPrime1);
  Move(AParts.Prime2[0], Result[Pos], Header.cbPrime2);
  Inc(Pos, Header.cbPrime2);
  Move(AParts.Exponent1[0], Result[Pos], Length(AParts.Exponent1));
  Inc(Pos, Length(AParts.Exponent1));
  Move(AParts.Exponent2[0], Result[Pos], Length(AParts.Exponent2));
  Inc(Pos, Length(AParts.Exponent2));
  Move(AParts.Coefficient[0], Result[Pos], Length(AParts.Coefficient));
  Inc(Pos, Length(AParts.Coefficient));
  Move(AParts.PrivateExponent[0], Result[Pos], Length(AParts.PrivateExponent));
end;

function SignWithPrivateKeyPem(const AData, APrivateKeyPem: string): string;
var
  Der, Pkcs1Der, PrivateBlob: TBytes;
  Parts: TRSAPrivateKeyParts;
  AlgHandle, KeyHandle, HashAlgHandle: BCRYPT_ALG_HANDLE;
  Hash: TBytes;
  Padding: BCRYPT_PKCS1_PADDING_INFO;
  Status: NTSTATUS;
  SigLen: ULONG;
  SigBytes: TBytes;
  AlgId: WideString;
  DataBytes: TBytes;
begin
  Result := '';
  AlgHandle := 0;
  KeyHandle := 0;
  HashAlgHandle := 0;

  Der := ParsePemToDer(APrivateKeyPem);
  Pkcs1Der := ExtractPkcs1PrivateKey(Der);
  Parts := ParseRsaPrivateKey(Pkcs1Der);
  PrivateBlob := BuildRsaPrivateBlob(Parts);

  Status := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_RSA_ALGORITHM, nil, 0);
  if Status <> STATUS_SUCCESS then
    raise EPaymentSignError.Create(Format('BCryptOpenAlgorithmProvider(RSA) failed: $%x',
      [Status]), 'SIGN_INIT_FAILED', ppWeChatPay);

  try
    Status := BCryptImportKeyPair(AlgHandle, 0, BCRYPT_RSAFULLPRIVATE_BLOB,
      KeyHandle, @PrivateBlob[0], Length(PrivateBlob), 0);
    if Status <> STATUS_SUCCESS then
      raise EPaymentSignError.Create(Format('BCryptImportKeyPair(private) failed: $%x',
        [Status]), 'SIGN_KEY_IMPORT_FAILED', ppWeChatPay);

    Status := BCryptOpenAlgorithmProvider(HashAlgHandle, BCRYPT_SHA256_ALGORITHM, nil, 0);
    if Status <> STATUS_SUCCESS then
      raise EPaymentSignError.Create(Format('BCryptOpenAlgorithmProvider(SHA256) failed: $%x',
        [Status]), 'SIGN_HASH_INIT_FAILED', ppWeChatPay);

    SetLength(Hash, 32);
    DataBytes := TEncoding.UTF8.GetBytes(AData);
    if Length(DataBytes) > 0 then
      Status := BCryptHash(HashAlgHandle, nil, 0, @DataBytes[0], Length(DataBytes), @Hash[0], 32)
    else
      Status := BCryptHash(HashAlgHandle, nil, 0, nil, 0, @Hash[0], 32);

    if Status <> STATUS_SUCCESS then
      raise EPaymentSignError.Create(Format('BCryptHash failed: $%x',
        [Status]), 'SIGN_HASH_FAILED', ppWeChatPay);

    AlgId := BCRYPT_SHA256_ALGORITHM;
    Padding.pszAlgId := PWideChar(AlgId);

    SigLen := 0;
    Status := BCryptSignHash(KeyHandle, @Padding, @Hash[0], Length(Hash),
      nil, 0, SigLen, BCRYPT_PAD_PKCS1);
    if Status <> STATUS_SUCCESS then
      raise EPaymentSignError.Create(Format('BCryptSignHash(size) failed: $%x',
        [Status]), 'SIGN_FAILED', ppWeChatPay);

    SetLength(SigBytes, SigLen);
    Status := BCryptSignHash(KeyHandle, @Padding, @Hash[0], Length(Hash),
      @SigBytes[0], Length(SigBytes), SigLen, BCRYPT_PAD_PKCS1);
    if Status <> STATUS_SUCCESS then
      raise EPaymentSignError.Create(Format('BCryptSignHash failed: $%x',
        [Status]), 'SIGN_FAILED', ppWeChatPay);

    SetLength(SigBytes, SigLen);
    Result := TNetEncoding.Base64.EncodeBytesToString(SigBytes);
  finally
    if HashAlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(HashAlgHandle, 0);
    if KeyHandle <> 0 then
      BCryptDestroyKey(KeyHandle);
    if AlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;
end;
{$ENDIF}

{ TWeChatPayConfig }

constructor TWeChatPayConfig.Create;
begin
  inherited Create(ppWeChatPay);
end;

// BUG-019 FIX: 安全密钥存储方法实现
procedure TWeChatPayConfig.LoadKeysFromCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    ApiKeyV3 := GetCredentialKey('ApiKeyV3');
    PrivateKey := GetCredentialKey('PrivateKey');
    FWeChatPublicKey := GetCredentialKey('WeChatPublicKey');
  end;
end;

procedure TWeChatPayConfig.SaveKeysToCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    SetCredentialKey('ApiKeyV3', FApiKeyV3);
    SetCredentialKey('PrivateKey', FPrivateKey);
    SetCredentialKey('WeChatPublicKey', FWeChatPublicKey);
  end;
end;

procedure TWeChatPayConfig.SetApiKeyV3Secure(const AKey: string);
begin
  FApiKeyV3 := ProtectKey(AKey);
end;

function TWeChatPayConfig.GetApiKeyV3Secure: string;
begin
  Result := UnprotectKey(FApiKeyV3);
end;

procedure TWeChatPayConfig.SetPrivateKeySecure(const AKey: string);
begin
  FPrivateKey := ProtectKey(AKey);
end;

function TWeChatPayConfig.GetPrivateKeySecure: string;
begin
  Result := UnprotectKey(FPrivateKey);
end;

{ TWeChatPayClient }

constructor TWeChatPayClient.Create(AConfig: TWeChatPayConfig);
begin
  inherited Create(AConfig);
end;

function TWeChatPayClient.GetApiUrl: string;
begin
  Result := WECHAT_API_URL;
end;

function TWeChatPayClient.GenerateNonceStr: string;
begin
  Result := TPaymentHelper.GenerateNonceStr(32);
end;

function TWeChatPayClient.RSASign(const AContent: string): string;
var
  Cfg: TWeChatPayConfig;
begin
  Cfg := TWeChatPayConfig(FConfig);
  if Trim(Cfg.PrivateKey) = '' then
    raise EPaymentSignError.Create(
      'Missing WeChat merchant private key.',
      'MISSING_PRIVATE_KEY', ppWeChatPay);

  {$IFDEF MSWINDOWS}
  Result := SignWithPrivateKeyPem(AContent, Cfg.PrivateKey);
  {$ELSE}
  raise EPaymentSignError.Create(
    'RSA signing is unavailable in this build. Use provider SDK signing flow.',
    'SIGN_NOT_IMPLEMENTED', ppWeChatPay);
  {$ENDIF}
end;

function TWeChatPayClient.BuildAuthorizationHeader(const AMethod, AUrl, ABody: string): string;
var
  Cfg: TWeChatPayConfig;
  Timestamp: Int64;
  NonceStr: string;
  SignContent: string;
  Signature: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Build sign content: HTTP请求方法\nURL\n时间戳\n随机字符串\n请求报文主体\n
  SignContent := AMethod + #10 +
                 AUrl + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 ABody + #10;

  Signature := RSASign(SignContent);

  // WECHATPAY2-SHA256-RSA2048 authorization
  Result := Format('WECHATPAY2-SHA256-RSA2048 mchid="%s",nonce_str="%s",signature="%s",timestamp="%d",serial_no="%s"',
    [Cfg.MchId, NonceStr, Signature, Timestamp, Cfg.SerialNo]);
end;

function TWeChatPayClient.SignRequest(const AParams: TDictionary<string, string>): string;
begin
  // WeChat V3 uses HTTP Authorization header, not query string signing
  Result := '';
end;

function TWeChatPayClient.VerifySignature(const AParams: TDictionary<string, string>;
  const ASign: string): Boolean;
var
  Cfg: TWeChatPayConfig;
  SignContent: string;
  Key: string;
  SortedKeys: TArray<string>;
  I: Integer;
{$IFDEF MSWINDOWS}
  Verifier: TRSAVerifier;
  NormalizedKey: string;
{$ENDIF}
begin
  // BUG-014 FIX: Implement actual signature verification
  Cfg := TWeChatPayConfig(FConfig);
  
  // Validate public key is configured
  if Cfg.WeChatPublicKey = '' then
  begin
    Result := False;
    Exit;
  end;
  if Trim(ASign) = '' then
    Exit(False);
  
  // Build sign content from sorted parameters
  SortedKeys := AParams.Keys.ToArray;
  TArray.Sort<string>(SortedKeys);
  
  SignContent := '';
  for I := 0 to High(SortedKeys) do
  begin
    Key := SortedKeys[I];
    if (Key <> 'sign') and (AParams[Key] <> '') then
    begin
      if SignContent <> '' then
        SignContent := SignContent + '&';
      SignContent := SignContent + Key + '=' + AParams[Key];
    end;
  end;
  
  // Verify using RSA-SHA256
  {$IFDEF MSWINDOWS}
  NormalizedKey := Trim(Cfg.WeChatPublicKey);
  if Pos('BEGIN PUBLIC KEY', UpperCase(NormalizedKey)) = 0 then
    NormalizedKey := '-----BEGIN PUBLIC KEY-----' + sLineBreak +
      NormalizedKey + sLineBreak +
      '-----END PUBLIC KEY-----';

  Verifier := TRSAVerifier.Create;
  try
    if not Verifier.LoadPublicKeyPEM(NormalizedKey) then
      Exit(False);
    Result := Verifier.VerifySignature(SignContent, ASign);
  finally
    Verifier.Free;
  end;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function TWeChatPayClient.DoWeChatPost(const AEndpoint: string; ABody: TJSONObject): TJSONObject;
var
  AuthHeader, BodyStr, Response: string;
begin
  Result := nil;

  if Assigned(ABody) then
    BodyStr := ABody.ToString
  else
    BodyStr := '';

  AuthHeader := BuildAuthorizationHeader('POST', AEndpoint, BodyStr);
  FHttpClient.CustomHeaders['Authorization'] := AuthHeader;
  FHttpClient.CustomHeaders['Accept'] := 'application/json';
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';

  Response := DoPost(GetApiUrl + AEndpoint, BodyStr, 'application/json');

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppWeChatPay);

  // Check for error
  if Result.GetValue('code') <> nil then
  begin
    var ErrCode := Result.GetValue<string>('code', '');
    var ErrMsg := Result.GetValue<string>('message', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppWeChatPay);
  end;
end;

function TWeChatPayClient.DoWeChatGet(const AEndpoint: string): TJSONObject;
var
  AuthHeader, Response: string;
begin
  Result := nil;

  AuthHeader := BuildAuthorizationHeader('GET', AEndpoint, '');
  FHttpClient.CustomHeaders['Authorization'] := AuthHeader;
  FHttpClient.CustomHeaders['Accept'] := 'application/json';

  Response := DoGet(GetApiUrl + AEndpoint);

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppWeChatPay);

  if Result.GetValue('code') <> nil then
  begin
    var ErrCode := Result.GetValue<string>('code', '');
    var ErrMsg := Result.GetValue<string>('message', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppWeChatPay);
  end;
end;

function TWeChatPayClient.ParseWeChatStatus(const AState: string): TPaymentStatus;
begin
  if AState = 'SUCCESS' then
    Result := psSuccess
  else if AState = 'NOTPAY' then
    Result := psPending
  else if AState = 'CLOSED' then
    Result := psClosed
  else if AState = 'REVOKED' then
    Result := psClosed
  else if AState = 'USERPAYING' then
    Result := psPending
  else if AState = 'PAYERROR' then
    Result := psFailed
  else if AState = 'REFUND' then
    Result := psRefunded
  else
    Result := psUnknown;
end;

function TWeChatPayClient.CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
begin
  case AOrder.PaymentMethod of
    pmQRCode: Result := CreateNativeOrder(AOrder);
    pmH5: Result := CreateH5Order(AOrder);
    pmApp: Result := CreateAppOrder(AOrder);
  else
    // Default to Native (QR code)
    Result := CreateNativeOrder(AOrder);
  end;
end;

function TWeChatPayClient.CreateNativeOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  try
    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));
    ReqBody.AddPair('amount', AmountObj);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    if AOrder.ExpireMinutes > 0 then
      ReqBody.AddPair('time_expire', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"+08:00"',
        Now + AOrder.ExpireMinutes / 1440));

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/native', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.QRCodeData := RespObj.GetValue<string>('code_url', '');
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateJSAPIOrder(const AOrder: TPaymentOrder;
  const AOpenId: string): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj, PayerObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  if AOpenId = '' then
  begin
    Result := TPaymentResult.Fail('MISSING_OPENID', 'OpenId is required for JSAPI payment');
    Exit;
  end;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  try
    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));
    ReqBody.AddPair('amount', AmountObj);

    PayerObj := TJSONObject.Create;
    PayerObj.AddPair('openid', AOpenId);
    ReqBody.AddPair('payer', PayerObj);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/jsapi', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PrepayId := RespObj.GetValue<string>('prepay_id', '');
        Result.AppPayParams := BuildJSAPIPayParams(Result.PrepayId);
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateH5Order(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj, SceneInfoObj, H5InfoObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  try
    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));
    ReqBody.AddPair('amount', AmountObj);

    SceneInfoObj := TJSONObject.Create;
    H5InfoObj := TJSONObject.Create;
    H5InfoObj.AddPair('type', 'Wap');
    SceneInfoObj.AddPair('payer_client_ip', IfThen(AOrder.ClientIP <> '', AOrder.ClientIP, '127.0.0.1'));
    SceneInfoObj.AddPair('h5_info', H5InfoObj);
    ReqBody.AddPair('scene_info', SceneInfoObj);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/h5', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PayUrl := RespObj.GetValue<string>('h5_url', '');
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateAppOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  try
    AmountObj := TJSONObject.Create;
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));
    ReqBody.AddPair('amount', AmountObj);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/app', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PrepayId := RespObj.GetValue<string>('prepay_id', '');
        Result.AppPayParams := BuildAppPayParams(Result.PrepayId);
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.BuildJSAPIPayParams(const APrepayId: string): string;
var
  Cfg: TWeChatPayConfig;
  Params: TJSONObject;
  Timestamp: Int64;
  NonceStr, SignContent, PaySign: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Sign content for JSAPI
  SignContent := Cfg.AppId + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 'prepay_id=' + APrepayId + #10;
  PaySign := RSASign(SignContent);

  Params := TJSONObject.Create;
  try
    Params.AddPair('appId', Cfg.AppId);
    Params.AddPair('timeStamp', IntToStr(Timestamp));
    Params.AddPair('nonceStr', NonceStr);
    Params.AddPair('package', 'prepay_id=' + APrepayId);
    Params.AddPair('signType', 'RSA');
    Params.AddPair('paySign', PaySign);
    Result := Params.ToString;
  finally
    Params.Free;
  end;
end;

function TWeChatPayClient.BuildAppPayParams(const APrepayId: string): string;
var
  Cfg: TWeChatPayConfig;
  Params: TJSONObject;
  Timestamp: Int64;
  NonceStr, SignContent, PaySign: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Sign content for APP
  SignContent := Cfg.AppId + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 APrepayId + #10;
  PaySign := RSASign(SignContent);

  Params := TJSONObject.Create;
  try
    Params.AddPair('appid', Cfg.AppId);
    Params.AddPair('partnerid', Cfg.MchId);
    Params.AddPair('prepayid', APrepayId);
    Params.AddPair('package', 'Sign=WXPay');
    Params.AddPair('noncestr', NonceStr);
    Params.AddPair('timestamp', IntToStr(Timestamp));
    Params.AddPair('sign', PaySign);
    Result := Params.ToString;
  finally
    Params.Free;
  end;
end;

function TWeChatPayClient.QueryOrder(const AOrderNo: string): TPaymentQueryResult;
var
  Cfg: TWeChatPayConfig;
  RespObj, AmountObj: TJSONObject;
begin
  Result.Clear;
  Cfg := TWeChatPayConfig(FConfig);

  try
    RespObj := DoWeChatGet('/v3/pay/transactions/out-trade-no/' +
      TNetEncoding.URL.Encode(AOrderNo) + '?mchid=' + Cfg.MchId);
    try
      Result.Success := True;
      Result.OrderNo := RespObj.GetValue<string>('out_trade_no', '');
      Result.TradeNo := RespObj.GetValue<string>('transaction_id', '');
      Result.Status := ParseWeChatStatus(RespObj.GetValue<string>('trade_state', ''));

      AmountObj := RespObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountObj) then
      begin
        Result.Amount := AmountObj.GetValue<Int64>('total', 0) / 100;
        Result.PaidAmount := AmountObj.GetValue<Int64>('payer_total', 0) / 100;
      end;

      Result.RawResponse := RespObj.ToString;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
    begin
      Result.ErrorCode := E.ErrorCode;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TWeChatPayClient.CloseOrder(const AOrderNo: string): Boolean;
var
  Cfg: TWeChatPayConfig;
  ReqBody: TJSONObject;
  AuthHeader, BodyStr, Response: string;
begin
  Result := False;
  Cfg := TWeChatPayConfig(FConfig);

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('mchid', Cfg.MchId);
    BodyStr := ReqBody.ToString;

    AuthHeader := BuildAuthorizationHeader('POST',
      '/v3/pay/transactions/out-trade-no/' + AOrderNo + '/close', BodyStr);
    FHttpClient.CustomHeaders['Authorization'] := AuthHeader;
    FHttpClient.CustomHeaders['Accept'] := 'application/json';
    FHttpClient.CustomHeaders['Content-Type'] := 'application/json';

    try
      Response := DoPost(GetApiUrl + '/v3/pay/transactions/out-trade-no/' +
        AOrderNo + '/close', BodyStr, 'application/json');
      // WeChat close-order returns 204 No Content on success — empty body is OK.
      Result := True;
    except
      on E: EPaymentError do
        Result := False;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.Refund(const ARequest: TRefundRequest): TRefundResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  RefundFen, TotalFen: Int64;
begin
  Result.Clear;
  ARequest.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  RefundFen := Round(ARequest.RefundAmount * 100);
  TotalFen := Round(ARequest.TotalAmount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  try
    AmountObj.AddPair('refund', TJSONNumber.Create(RefundFen));
    AmountObj.AddPair('total', TJSONNumber.Create(TotalFen));
    AmountObj.AddPair('currency', 'CNY');

    ReqBody.AddPair('out_trade_no', ARequest.OrderNo);
    ReqBody.AddPair('out_refund_no', ARequest.RefundNo);
    if ARequest.Reason <> '' then
      ReqBody.AddPair('reason', ARequest.Reason);
    ReqBody.AddPair('amount', AmountObj);

    if ARequest.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', ARequest.NotifyUrl);

    try
      RespObj := DoWeChatPost('/v3/refund/domestic/refunds', ReqBody);
      try
        Result.Success := True;
        Result.RefundNo := RespObj.GetValue<string>('out_refund_no', '');
        Result.RefundTradeNo := RespObj.GetValue<string>('refund_id', '');

        var RefundStatus := RespObj.GetValue<string>('status', '');
        if RefundStatus = 'SUCCESS' then
          Result.Status := psRefunded
        else if RefundStatus = 'PROCESSING' then
          Result.Status := psRefunding
        else
          Result.Status := psFailed;

        var AmountInfo := RespObj.GetValue<TJSONObject>('amount');
        if Assigned(AmountInfo) then
          Result.RefundAmount := AmountInfo.GetValue<Int64>('refund', 0) / 100;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.QueryRefund(const ARefundNo: string): TRefundResult;
var
  RespObj: TJSONObject;
begin
  Result.Clear;

  try
    RespObj := DoWeChatGet('/v3/refund/domestic/refunds/' + ARefundNo);
    try
      Result.Success := True;
      Result.RefundNo := RespObj.GetValue<string>('out_refund_no', '');
      Result.RefundTradeNo := RespObj.GetValue<string>('refund_id', '');

      var RefundStatus := RespObj.GetValue<string>('status', '');
      if RefundStatus = 'SUCCESS' then
        Result.Status := psRefunded
      else if RefundStatus = 'PROCESSING' then
        Result.Status := psRefunding
      else if RefundStatus = 'ABNORMAL' then
        Result.Status := psFailed
      else
        Result.Status := psUnknown;

      var AmountInfo := RespObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountInfo) then
        Result.RefundAmount := AmountInfo.GetValue<Int64>('refund', 0) / 100;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
      Result := TRefundResult.Fail(E.ErrorCode, E.Message);
  end;
end;

function TWeChatPayClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
begin
  Result := VerifyNotificationWithSignature(ARawData, '', '', '', ANotification);
end;

function TWeChatPayClient.VerifyNotificationWithSignature(const ARawData, ATimestamp,
  ANonce, ASignature: string;
  out ANotification: TPaymentNotification): Boolean;
var
  JsonObj, ResourceObj, AmountObj, DecryptedObj: TJSONObject;
  EventType, Ciphertext, Nonce, AssociatedData, DecryptedData: string;
  Cfg: TWeChatPayConfig;
{$IFDEF MSWINDOWS}
  SignContent: string;
  Verifier: TRSAVerifier;
  NormalizedKey: string;
{$ENDIF}
begin
  Result := False;
  ANotification.Clear;
  ANotification.Provider := ppWeChatPay;
  ANotification.RawData := ARawData;

  Cfg := TWeChatPayConfig(FConfig);

  // Verify HTTP-level signature when headers are provided
  {$IFDEF MSWINDOWS}
  if (ATimestamp <> '') and (ANonce <> '') and (ASignature <> '') then
  begin
    if Cfg.WeChatPublicKey = '' then
      Exit;
    NormalizedKey := Cfg.WeChatPublicKey;
    if Pos('BEGIN PUBLIC KEY', UpperCase(NormalizedKey)) = 0 then
      NormalizedKey := '-----BEGIN PUBLIC KEY-----' + sLineBreak +
        NormalizedKey + sLineBreak +
        '-----END PUBLIC KEY-----';
    SignContent := ATimestamp + #10 + ANonce + #10 + ARawData + #10;
    Verifier := TRSAVerifier.Create;
    try
      if not Verifier.LoadPublicKeyPEM(NormalizedKey) then
        Exit;
      if not Verifier.VerifySignature(SignContent, ASignature) then
        Exit;
    finally
      Verifier.Free;
    end;
  end;
  {$ELSE}
  if (ATimestamp <> '') and (ANonce <> '') and (ASignature <> '') then
    Exit; // Cannot verify RSA signature on non-Windows; reject
  {$ENDIF}
  JsonObj := nil;
  DecryptedObj := nil;

  try
    JsonObj := TJSONObject.ParseJSONValue(ARawData) as TJSONObject;
    if not Assigned(JsonObj) then
      Exit;

    EventType := JsonObj.GetValue<string>('event_type', '');
    ResourceObj := JsonObj.GetValue<TJSONObject>('resource');
    if not Assigned(ResourceObj) then
      Exit;

    Ciphertext := ResourceObj.GetValue<string>('ciphertext', '');
    Nonce := ResourceObj.GetValue<string>('nonce', '');
    AssociatedData := ResourceObj.GetValue<string>('associated_data', '');

    if Ciphertext = '' then
      Exit;
    if (Cfg.ApiKeyV3 = '') or (Nonce = '') then
      Exit;

    DecryptedData := TPaymentHelper.AES256GCMDecrypt(
      Ciphertext, Cfg.ApiKeyV3, Nonce, AssociatedData);
    if DecryptedData = '' then
      Exit;

    DecryptedObj := TJSONObject.ParseJSONValue(DecryptedData) as TJSONObject;
    if not Assigned(DecryptedObj) then
      Exit;
    ResourceObj := DecryptedObj;

    if EventType = 'TRANSACTION.SUCCESS' then
    begin
      ANotification.OrderNo := ResourceObj.GetValue<string>('out_trade_no', '');
      ANotification.TradeNo := ResourceObj.GetValue<string>('transaction_id', '');
      ANotification.Status := psSuccess;

      AmountObj := ResourceObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountObj) then
        ANotification.Amount := AmountObj.GetValue<Int64>('total', 0) / 100;

      Result := (ANotification.OrderNo <> '') and
        (ANotification.TradeNo <> '');
    end
    else if EventType = 'REFUND.SUCCESS' then
    begin
      ANotification.OrderNo := ResourceObj.GetValue<string>('out_trade_no', '');
      ANotification.RefundNo := ResourceObj.GetValue<string>('out_refund_no', '');
      ANotification.RefundTradeNo := ResourceObj.GetValue<string>('refund_id', '');
      ANotification.RefundStatus := psRefunded;

      AmountObj := ResourceObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountObj) then
        ANotification.RefundAmount := AmountObj.GetValue<Int64>('refund', 0) / 100;

      Result := (ANotification.OrderNo <> '') and
        (ANotification.RefundNo <> '');
    end;
  except
    Result := False;
  end;

  DecryptedObj.Free;
  JsonObj.Free;
end;
function TWeChatPayClient.GetNotificationResponse(ASuccess: Boolean): string;
var
  Resp: TJSONObject;
begin
  Resp := TJSONObject.Create;
  try
    if ASuccess then
    begin
      Resp.AddPair('code', 'SUCCESS');
      Resp.AddPair('message', '');
    end
    else
    begin
      Resp.AddPair('code', 'FAIL');
      Resp.AddPair('message', 'Processing failed');
    end;
    Result := Resp.ToString;
  finally
    Resp.Free;
  end;
end;

end.
