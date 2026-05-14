{*******************************************************}
{                                                       }
{       DeepBase Framework                               }
{       Web API Authentication & Authorization          }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit DeepBase.WebAPI.Auth;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.NetEncoding,
  System.DateUtils,
  System.Hash,
  System.SyncObjs,
  System.Rtti,
  System.StrUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.WebAPI.Core;

{$IFDEF MSWINDOWS}
// Windows CryptoAPI 声明用于安全随机数生成
const
  PROV_RSA_FULL = 1;
  CRYPT_VERIFYCONTEXT = $F0000000;

function CryptAcquireContext(phProv: PNativeUInt; pszContainer: PChar;
  pszProvider: PChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall;
  external advapi32 name {$IFDEF UNICODE}'CryptAcquireContextW'{$ELSE}'CryptAcquireContextA'{$ENDIF};

function CryptReleaseContext(hProv: NativeUInt; dwFlags: DWORD): BOOL; stdcall;
  external advapi32;

function CryptGenRandom(hProv: NativeUInt; dwLen: DWORD; pbBuffer: PByte): BOOL; stdcall;
  external advapi32;
{$ENDIF}

type
  // 认证类型
  TAuthType = (atNone, atBasic, atBearer, atApiKey, atOAuth2);

  // 令牌类型
  TTokenType = (ttAccess, ttRefresh);

  // 用户角色
  TUserRole = string;
  TUserRoles = TArray<TUserRole>;

  // 前置声明
  TAuthenticatedUser = class;
  TJWTToken = class;
  TJWTManager = class;
  TApiKeyManager = class;
  TRateLimiter = class;

  // 已认证用户
  TAuthenticatedUser = class
  private
    FUserId: string;
    FUsername: string;
    FEmail: string;
    FRoles: TStringList;
    FClaims: TDictionary<string, string>;
    FAuthType: TAuthType;
    FAuthenticatedAt: TDateTime;
    FExpiresAt: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;

    property UserId: string read FUserId write FUserId;
    property Username: string read FUsername write FUsername;
    property Email: string read FEmail write FEmail;
    property Roles: TStringList read FRoles;
    property Claims: TDictionary<string, string> read FClaims;
    property AuthType: TAuthType read FAuthType write FAuthType;
    property AuthenticatedAt: TDateTime read FAuthenticatedAt write FAuthenticatedAt;
    property ExpiresAt: TDateTime read FExpiresAt write FExpiresAt;

    function HasRole(const ARole: string): Boolean;
    function HasAnyRole(const ARoles: array of string): Boolean;
    function HasAllRoles(const ARoles: array of string): Boolean;
    function GetClaim(const AKey: string; const ADefault: string = ''): string;
    function IsExpired: Boolean;
  end;

  // JWT 头部
  TJWTHeader = record
    Alg: string;  // 算法
    Typ: string;  // 类型
  end;

  // JWT 载荷
  TJWTPayload = class
  private
    FIssuer: string;        // iss
    FSubject: string;       // sub
    FAudience: string;      // aud
    FExpiresAt: TDateTime;  // exp
    FNotBefore: TDateTime;  // nbf
    FIssuedAt: TDateTime;   // iat
    FJwtId: string;         // jti
    FClaims: TDictionary<string, TJSONValue>;
  public
    constructor Create;
    destructor Destroy; override;

    property Issuer: string read FIssuer write FIssuer;
    property Subject: string read FSubject write FSubject;
    property Audience: string read FAudience write FAudience;
    property ExpiresAt: TDateTime read FExpiresAt write FExpiresAt;
    property NotBefore: TDateTime read FNotBefore write FNotBefore;
    property IssuedAt: TDateTime read FIssuedAt write FIssuedAt;
    property JwtId: string read FJwtId write FJwtId;
    property Claims: TDictionary<string, TJSONValue> read FClaims;

    procedure SetClaim(const AKey: string; AValue: TJSONValue);
    procedure SetStringClaim(const AKey, AValue: string);
    procedure SetIntegerClaim(const AKey: string; AValue: Int64);
    procedure SetBooleanClaim(const AKey: string; AValue: Boolean);
    procedure SetArrayClaim(const AKey: string; const AValues: TArray<string>);
    function GetStringClaim(const AKey: string; const ADefault: string = ''): string;
    function GetIntegerClaim(const AKey: string; ADefault: Int64 = 0): Int64;
    function GetBooleanClaim(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetArrayClaim(const AKey: string): TArray<string>;

    function ToJSON: TJSONObject;
    procedure FromJSON(AJson: TJSONObject);
    function IsExpired: Boolean;
    function IsValid: Boolean;
  end;

  // JWT 令牌
  TJWTToken = class
  private
    FHeader: TJWTHeader;
    FPayload: TJWTPayload;
    FSignature: string;
    FRawToken: string;
  public
    constructor Create;
    destructor Destroy; override;

    property Header: TJWTHeader read FHeader write FHeader;
    property Payload: TJWTPayload read FPayload;
    property Signature: string read FSignature write FSignature;
    property RawToken: string read FRawToken write FRawToken;
  end;

  // JWT 验证结果
  TJWTValidationResult = record
    Valid: Boolean;
    Error: string;
    Token: TJWTToken;
  end;

  // JWT 管理器
  TJWTManager = class
  private
    FSecret: string;
    FIssuer: string;
    FAudience: string;
    FAccessTokenExpiry: Integer;   // 秒
    FRefreshTokenExpiry: Integer;  // 秒
    FAlgorithm: string;

    function Base64URLEncode(const AData: TBytes): string;
    function Base64URLDecode(const AData: string): TBytes;
    function Sign(const AData: string): string;
    function Verify(const AData, ASignature: string): Boolean;
  public
    constructor Create(const ASecret: string);
    destructor Destroy; override;

    property Secret: string read FSecret write FSecret;
    property Issuer: string read FIssuer write FIssuer;
    property Audience: string read FAudience write FAudience;
    property AccessTokenExpiry: Integer read FAccessTokenExpiry write FAccessTokenExpiry;
    property RefreshTokenExpiry: Integer read FRefreshTokenExpiry write FRefreshTokenExpiry;
    property Algorithm: string read FAlgorithm write FAlgorithm;

    // 生成令牌
    function GenerateToken(const ASubject: string;
      const ARoles: TArray<string> = nil;
      const AClaims: TDictionary<string, string> = nil;
      ATokenType: TTokenType = ttAccess): string;

    // 验证令牌
    function ValidateToken(const AToken: string): TJWTValidationResult;

    // 解析令牌（不验证签名）
    function ParseToken(const AToken: string): TJWTToken;

    // 刷新令牌
    function RefreshToken(const ARefreshToken: string): string;

    // 从令牌获取用户
    function GetUserFromToken(const AToken: string): TAuthenticatedUser;
  end;

  // API Key 信息
  TApiKeyInfo = class
  private
    FKey: string;
    FName: string;
    FUserId: string;
    FRoles: TStringList;
    FScopes: TStringList;
    FCreatedAt: TDateTime;
    FExpiresAt: TDateTime;
    FLastUsedAt: TDateTime;
    FUsageCount: Int64;
    FRateLimit: Integer;
    FEnabled: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    property Key: string read FKey write FKey;
    property Name: string read FName write FName;
    property UserId: string read FUserId write FUserId;
    property Roles: TStringList read FRoles;
    property Scopes: TStringList read FScopes;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ExpiresAt: TDateTime read FExpiresAt write FExpiresAt;
    property LastUsedAt: TDateTime read FLastUsedAt write FLastUsedAt;
    property UsageCount: Int64 read FUsageCount write FUsageCount;
    property RateLimit: Integer read FRateLimit write FRateLimit;
    property Enabled: Boolean read FEnabled write FEnabled;

    function IsExpired: Boolean;
    function IsValid: Boolean;
    function HasScope(const AScope: string): Boolean;
  end;

  // API Key 存储接口
  IApiKeyStore = interface
    ['{A8F4C1D2-B3E5-4F6A-8C9D-0E1F2A3B4C5D}']
    function GetKey(const AKey: string): TApiKeyInfo;
    procedure SaveKey(AKeyInfo: TApiKeyInfo);
    procedure DeleteKey(const AKey: string);
    function ListKeys(const AUserId: string = ''): TArray<TApiKeyInfo>;
  end;

  // 内存 API Key 存储
  TMemoryApiKeyStore = class(TInterfacedObject, IApiKeyStore)
  private
    FKeys: TObjectDictionary<string, TApiKeyInfo>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    function GetKey(const AKey: string): TApiKeyInfo;
    procedure SaveKey(AKeyInfo: TApiKeyInfo);
    procedure DeleteKey(const AKey: string);
    function ListKeys(const AUserId: string = ''): TArray<TApiKeyInfo>;
  end;

  // API Key 管理器
  TApiKeyManager = class
  private
    FStore: IApiKeyStore;
    FKeyPrefix: string;
    FKeyLength: Integer;

    function GenerateKeyString: string;
  public
    constructor Create(AStore: IApiKeyStore);
    destructor Destroy; override;

    property Store: IApiKeyStore read FStore;
    property KeyPrefix: string read FKeyPrefix write FKeyPrefix;
    property KeyLength: Integer read FKeyLength write FKeyLength;

    // 创建新 API Key
    function CreateKey(const AName, AUserId: string;
      const ARoles: array of string;
      AExpiresAt: TDateTime = 0;
      ARateLimit: Integer = 0): TApiKeyInfo;

    // 验证 API Key
    function ValidateKey(const AKey: string): TApiKeyInfo;

    // 撤销 API Key
    procedure RevokeKey(const AKey: string);

    // 更新使用统计
    procedure UpdateUsage(const AKey: string);

    // 从请求获取用户
    function GetUserFromKey(const AKey: string): TAuthenticatedUser;
  end;

  // 速率限制记录
  TRateLimitRecord = record
    Key: string;
    Count: Integer;
    WindowStart: TDateTime;
    WindowEnd: TDateTime;
  end;

  // 速率限制结果
  TRateLimitResult = record
    Allowed: Boolean;
    Limit: Integer;
    Remaining: Integer;
    ResetAt: TDateTime;
    RetryAfter: Integer;  // 秒
  end;

  // 速率限制策略
  TRateLimitStrategy = (rlsFixedWindow, rlsSlidingWindow, rlsTokenBucket);

  // 速率限制器
  TRateLimiter = class
  private
    FRecords: TDictionary<string, TRateLimitRecord>;
    FLock: TCriticalSection;
    FDefaultLimit: Integer;
    FWindowSeconds: Integer;
    FStrategy: TRateLimitStrategy;

    function GetKey(AContext: TApiContext): string;
    procedure CleanupExpired;
  public
    constructor Create;
    destructor Destroy; override;

    property DefaultLimit: Integer read FDefaultLimit write FDefaultLimit;
    property WindowSeconds: Integer read FWindowSeconds write FWindowSeconds;
    property Strategy: TRateLimitStrategy read FStrategy write FStrategy;

    // 检查并消费配额
    function Check(AContext: TApiContext; ALimit: Integer = 0): TRateLimitResult;

    // 重置某个 Key 的计数
    procedure Reset(const AKey: string);

    // 设置响应头
    procedure SetHeaders(AContext: TApiContext; const AResult: TRateLimitResult);
  end;

  // 认证回调
  TAuthCallback = reference to function(const AUsername, APassword: string): TAuthenticatedUser;
  TApiKeyCallback = reference to function(const AKey: string): TAuthenticatedUser;

  // 认证中间件
  TAuthMiddleware = class
  private
    FJWTManager: TJWTManager;
    FApiKeyManager: TApiKeyManager;
    FBasicAuthCallback: TAuthCallback;
    FApiKeyCallback: TApiKeyCallback;
    FApiKeyHeaderName: string;
    FApiKeyQueryParam: string;
    FRequireAuth: Boolean;

    function ExtractBearerToken(AContext: TApiContext): string;
    function ExtractBasicCredentials(AContext: TApiContext; out AUsername, APassword: string): Boolean;
    function ExtractApiKey(AContext: TApiContext): string;
  public
    constructor Create;
    destructor Destroy; override;

    property JWTManager: TJWTManager read FJWTManager write FJWTManager;
    property ApiKeyManager: TApiKeyManager read FApiKeyManager write FApiKeyManager;
    property BasicAuthCallback: TAuthCallback read FBasicAuthCallback write FBasicAuthCallback;
    property ApiKeyCallback: TApiKeyCallback read FApiKeyCallback write FApiKeyCallback;
    property ApiKeyHeaderName: string read FApiKeyHeaderName write FApiKeyHeaderName;
    property ApiKeyQueryParam: string read FApiKeyQueryParam write FApiKeyQueryParam;
    property RequireAuth: Boolean read FRequireAuth write FRequireAuth;

    // 获取中间件函数
    function GetMiddleware: TMiddlewareFunc;

    // 获取可选认证中间件（不强制要求认证）
    function GetOptionalMiddleware: TMiddlewareFunc;
  end;

  // 授权中间件
  TAuthorizationMiddleware = class
  private
    FRequiredRoles: TStringList;
    FAnyRole: Boolean;  // True = 任一角色, False = 所有角色
  public
    constructor Create;
    destructor Destroy; override;

    property RequiredRoles: TStringList read FRequiredRoles;
    property AnyRole: Boolean read FAnyRole write FAnyRole;

    // 获取中间件函数
    function GetMiddleware: TMiddlewareFunc;

    // 快捷方法
    class function RequireRoles(const ARoles: array of string;
      AAnyRole: Boolean = True): TMiddlewareFunc;
    class function RequireRole(const ARole: string): TMiddlewareFunc;
  end;

  // 上下文扩展常量
  TAuthContextKeys = class
  public
    const User = 'auth.user';
    const Token = 'auth.token';
    const ApiKey = 'auth.apikey';
    const AuthType = 'auth.type';
  end;

  // 辅助函数
  function GetAuthenticatedUser(AContext: TApiContext): TAuthenticatedUser;
  function IsAuthenticated(AContext: TApiContext): Boolean;
  function HasRole(AContext: TApiContext; const ARole: string): Boolean;

implementation

{ 辅助函数 }

function GetAuthenticatedUser(AContext: TApiContext): TAuthenticatedUser;
var
  LValue: TValue;
begin
  if AContext.TryGetItem(TAuthContextKeys.User, LValue) then
    Result := LValue.AsObject as TAuthenticatedUser
  else
    Result := nil;
end;

function IsAuthenticated(AContext: TApiContext): Boolean;
begin
  Result := GetAuthenticatedUser(AContext) <> nil;
end;

function HasRole(AContext: TApiContext; const ARole: string): Boolean;
var
  LUser: TAuthenticatedUser;
begin
  LUser := GetAuthenticatedUser(AContext);
  Result := (LUser <> nil) and LUser.HasRole(ARole);
end;

{ TAuthenticatedUser }

constructor TAuthenticatedUser.Create;
begin
  inherited;
  FRoles := TStringList.Create;
  FRoles.Duplicates := dupIgnore;
  FClaims := TDictionary<string, string>.Create;
  FAuthenticatedAt := Now;
end;

destructor TAuthenticatedUser.Destroy;
begin
  FRoles.Free;
  FClaims.Free;
  inherited;
end;

function TAuthenticatedUser.HasRole(const ARole: string): Boolean;
begin
  Result := FRoles.IndexOf(ARole) >= 0;
end;

function TAuthenticatedUser.HasAnyRole(const ARoles: array of string): Boolean;
var
  LRole: string;
begin
  for LRole in ARoles do
    if HasRole(LRole) then
      Exit(True);
  Result := False;
end;

function TAuthenticatedUser.HasAllRoles(const ARoles: array of string): Boolean;
var
  LRole: string;
begin
  for LRole in ARoles do
    if not HasRole(LRole) then
      Exit(False);
  Result := True;
end;

function TAuthenticatedUser.GetClaim(const AKey: string; const ADefault: string): string;
begin
  if not FClaims.TryGetValue(AKey, Result) then
    Result := ADefault;
end;

function TAuthenticatedUser.IsExpired: Boolean;
begin
  Result := (FExpiresAt > 0) and (Now > FExpiresAt);
end;

{ TJWTPayload }

constructor TJWTPayload.Create;
begin
  inherited;
  FClaims := TDictionary<string, TJSONValue>.Create;
  FIssuedAt := Now;
end;

destructor TJWTPayload.Destroy;
var
  LPair: TPair<string, TJSONValue>;
begin
  for LPair in FClaims do
    LPair.Value.Free;
  FClaims.Free;
  inherited;
end;

procedure TJWTPayload.SetClaim(const AKey: string; AValue: TJSONValue);
var
  LOld: TJSONValue;
begin
  if FClaims.TryGetValue(AKey, LOld) then
    LOld.Free;
  FClaims.AddOrSetValue(AKey, AValue);
end;

procedure TJWTPayload.SetStringClaim(const AKey, AValue: string);
begin
  SetClaim(AKey, TJSONString.Create(AValue));
end;

procedure TJWTPayload.SetIntegerClaim(const AKey: string; AValue: Int64);
begin
  SetClaim(AKey, TJSONNumber.Create(AValue));
end;

procedure TJWTPayload.SetBooleanClaim(const AKey: string; AValue: Boolean);
begin
  SetClaim(AKey, TJSONBool.Create(AValue));
end;

procedure TJWTPayload.SetArrayClaim(const AKey: string; const AValues: TArray<string>);
var
  LArray: TJSONArray;
  LValue: string;
begin
  LArray := TJSONArray.Create;
  for LValue in AValues do
    LArray.Add(LValue);
  SetClaim(AKey, LArray);
end;

function TJWTPayload.GetStringClaim(const AKey: string; const ADefault: string): string;
var
  LValue: TJSONValue;
begin
  if FClaims.TryGetValue(AKey, LValue) and (LValue is TJSONString) then
    Result := TJSONString(LValue).Value
  else
    Result := ADefault;
end;

function TJWTPayload.GetIntegerClaim(const AKey: string; ADefault: Int64): Int64;
var
  LValue: TJSONValue;
begin
  if FClaims.TryGetValue(AKey, LValue) and (LValue is TJSONNumber) then
    Result := TJSONNumber(LValue).AsInt64
  else
    Result := ADefault;
end;

function TJWTPayload.GetBooleanClaim(const AKey: string; ADefault: Boolean): Boolean;
var
  LValue: TJSONValue;
begin
  if FClaims.TryGetValue(AKey, LValue) and (LValue is TJSONBool) then
    Result := TJSONBool(LValue).AsBoolean
  else
    Result := ADefault;
end;

function TJWTPayload.GetArrayClaim(const AKey: string): TArray<string>;
var
  LValue: TJSONValue;
  LArray: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  if FClaims.TryGetValue(AKey, LValue) and (LValue is TJSONArray) then
  begin
    LArray := TJSONArray(LValue);
    SetLength(Result, LArray.Count);
    for I := 0 to LArray.Count - 1 do
      Result[I] := LArray.Items[I].Value;
  end;
end;

function TJWTPayload.ToJSON: TJSONObject;
var
  LPair: TPair<string, TJSONValue>;
begin
  Result := TJSONObject.Create;
  try
    if FIssuer <> '' then
      Result.AddPair('iss', FIssuer);
    if FSubject <> '' then
      Result.AddPair('sub', FSubject);
    if FAudience <> '' then
      Result.AddPair('aud', FAudience);
    if FExpiresAt > 0 then
      Result.AddPair('exp', TJSONNumber.Create(DateTimeToUnix(FExpiresAt, False)));
    if FNotBefore > 0 then
      Result.AddPair('nbf', TJSONNumber.Create(DateTimeToUnix(FNotBefore, False)));
    if FIssuedAt > 0 then
      Result.AddPair('iat', TJSONNumber.Create(DateTimeToUnix(FIssuedAt, False)));
    if FJwtId <> '' then
      Result.AddPair('jti', FJwtId);

    for LPair in FClaims do
      Result.AddPair(LPair.Key, LPair.Value.Clone as TJSONValue);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJWTPayload.FromJSON(AJson: TJSONObject);
var
  LValue: TJSONValue;
  LPair: TJSONPair;
begin
  if AJson.TryGetValue('iss', LValue) then
    FIssuer := LValue.Value;
  if AJson.TryGetValue('sub', LValue) then
    FSubject := LValue.Value;
  if AJson.TryGetValue('aud', LValue) then
    FAudience := LValue.Value;
  if AJson.TryGetValue('exp', LValue) and (LValue is TJSONNumber) then
    FExpiresAt := UnixToDateTime(TJSONNumber(LValue).AsInt64, False);
  if AJson.TryGetValue('nbf', LValue) and (LValue is TJSONNumber) then
    FNotBefore := UnixToDateTime(TJSONNumber(LValue).AsInt64, False);
  if AJson.TryGetValue('iat', LValue) and (LValue is TJSONNumber) then
    FIssuedAt := UnixToDateTime(TJSONNumber(LValue).AsInt64, False);
  if AJson.TryGetValue('jti', LValue) then
    FJwtId := LValue.Value;

  // 加载自定义声明
  for LPair in AJson do
  begin
    if not MatchStr(LPair.JsonString.Value, ['iss', 'sub', 'aud', 'exp', 'nbf', 'iat', 'jti']) then
      SetClaim(LPair.JsonString.Value, LPair.JsonValue.Clone as TJSONValue);
  end;
end;

function TJWTPayload.IsExpired: Boolean;
begin
  Result := (FExpiresAt > 0) and (Now > FExpiresAt);
end;

function TJWTPayload.IsValid: Boolean;
begin
  Result := not IsExpired;
  if Result and (FNotBefore > 0) then
    Result := Now >= FNotBefore;
end;

{ TJWTToken }

constructor TJWTToken.Create;
begin
  inherited;
  FPayload := TJWTPayload.Create;
  FHeader.Alg := 'HS256';
  FHeader.Typ := 'JWT';
end;

destructor TJWTToken.Destroy;
begin
  FPayload.Free;
  inherited;
end;

{ TJWTManager }

constructor TJWTManager.Create(const ASecret: string);
begin
  inherited Create;
  if Length(ASecret) < 16 then
    raise EArgumentException.Create('JWT secret must be at least 16 characters');
  FSecret := ASecret;
  FAlgorithm := 'HS256';
  FAccessTokenExpiry := 3600;      // 1小时
  FRefreshTokenExpiry := 604800;   // 7天
end;

destructor TJWTManager.Destroy;
begin
  // BUG-113 FIX: 安全清理JWT密钥内存
  // 使用安全的内存清理方式，防止密钥在内存中残留
  if FSecret <> '' then
  begin
    // 用随机数据覆盖密钥内存
    UniqueString(FSecret);
    FillChar(FSecret[1], Length(FSecret) * SizeOf(Char), 0);
    FSecret := '';
  end;
  inherited;
end;

function TJWTManager.Base64URLEncode(const AData: TBytes): string;
begin
  // 标准 Base64 编码可能会插入换行符，这在 HTTP 头部（Authorization: Bearer ...）中是非法的，
  // 也会导致客户端/服务器解析异常。这里显式去除所有 CR/LF，再做 URL 安全转换。
  Result := TNetEncoding.Base64.EncodeBytesToString(AData);

  // 注意：不同实现/平台可能插入 CRLF 或单独的 LF/CR。
  Result := Result.Replace(#13, '', [rfReplaceAll]);
  Result := Result.Replace(#10, '', [rfReplaceAll]);

  Result := Result.Replace('+', '-').Replace('/', '_').TrimRight(['=']);
end;

function TJWTManager.Base64URLDecode(const AData: string): TBytes;
var
  LData: string;
begin
  LData := AData.Replace('-', '+').Replace('_', '/');
  case Length(LData) mod 4 of
    2: LData := LData + '==';
    3: LData := LData + '=';
  end;
  Result := TNetEncoding.Base64.DecodeStringToBytes(LData);
end;

function TJWTManager.Sign(const AData: string): string;
var
  LBytes: TBytes;
begin
  LBytes := THashSHA2.GetHMACAsBytes(
    TEncoding.UTF8.GetBytes(AData),
    TEncoding.UTF8.GetBytes(FSecret),
    SHA256
  );
  Result := Base64URLEncode(LBytes);
end;

function TJWTManager.Verify(const AData, ASignature: string): Boolean;
var
  LExpected: string;
  LMaxLen: Integer;
  I: Integer;
  LDiff: Integer;
  LExpectedChar: Char;
  LSignatureChar: Char;
begin
  LExpected := Sign(AData);
  LMaxLen := Length(LExpected);
  if Length(ASignature) > LMaxLen then
    LMaxLen := Length(ASignature);

  LDiff := Length(LExpected) xor Length(ASignature);
  for I := 1 to LMaxLen do
  begin
    LExpectedChar := #0;
    LSignatureChar := #0;
    if I <= Length(LExpected) then
      LExpectedChar := LExpected[I];
    if I <= Length(ASignature) then
      LSignatureChar := ASignature[I];
    LDiff := LDiff or (Ord(LExpectedChar) xor Ord(LSignatureChar));
  end;

  Result := LDiff = 0;
end;

function TJWTManager.GenerateToken(const ASubject: string;
  const ARoles: TArray<string>;
  const AClaims: TDictionary<string, string>;
  ATokenType: TTokenType): string;
var
  LHeader: TJSONObject;
  LPayload: TJSONObject;
  LRolesArray: TJSONArray;
  LHeaderStr: string;
  LPayloadStr: string;
  LRole: string;
  LPair: TPair<string, string>;
  LExpiry: Integer;
begin
  // 构建头部
  LHeader := TJSONObject.Create;
  try
    LHeader.AddPair('alg', FAlgorithm);
    LHeader.AddPair('typ', 'JWT');
    LHeaderStr := Base64URLEncode(TEncoding.UTF8.GetBytes(LHeader.ToJSON));
  finally
    LHeader.Free;
  end;

  // 构建载荷
  LPayload := TJSONObject.Create;
  try
    if FIssuer <> '' then
      LPayload.AddPair('iss', FIssuer);
    LPayload.AddPair('sub', ASubject);
    if FAudience <> '' then
      LPayload.AddPair('aud', FAudience);
    LPayload.AddPair('iat', TJSONNumber.Create(DateTimeToUnix(Now, False)));

    // 设置过期时间
    if ATokenType = ttAccess then
      LExpiry := FAccessTokenExpiry
    else
      LExpiry := FRefreshTokenExpiry;
    LPayload.AddPair('exp', TJSONNumber.Create(DateTimeToUnix(IncSecond(Now, LExpiry), False)));

    // 令牌类型
    if ATokenType = ttRefresh then
      LPayload.AddPair('type', 'refresh')
    else
      LPayload.AddPair('type', 'access');

    // 添加角色
    if Length(ARoles) > 0 then
    begin
      LRolesArray := TJSONArray.Create;
      for LRole in ARoles do
        LRolesArray.Add(LRole);
      LPayload.AddPair('roles', LRolesArray);
    end;

    // 添加自定义声明
    if AClaims <> nil then
    begin
      for LPair in AClaims do
        LPayload.AddPair(LPair.Key, LPair.Value);
    end;

    LPayloadStr := Base64URLEncode(TEncoding.UTF8.GetBytes(LPayload.ToJSON));
  finally
    LPayload.Free;
  end;

  // 生成签名
  Result := LHeaderStr + '.' + LPayloadStr + '.' + Sign(LHeaderStr + '.' + LPayloadStr);
end;

function TJWTManager.ValidateToken(const AToken: string): TJWTValidationResult;
var
  LParts: TArray<string>;
  LToken: TJWTToken;
begin
  Result.Valid := False;
  Result.Token := nil;
  Result.Error := '';

  LParts := AToken.Split(['.']);
  if Length(LParts) <> 3 then
  begin
    Result.Error := 'Invalid token format';
    Exit;
  end;

  // 验证签名
  if not Verify(LParts[0] + '.' + LParts[1], LParts[2]) then
  begin
    Result.Error := 'Invalid signature';
    Exit;
  end;

  // 解析令牌
  LToken := ParseToken(AToken);
  if LToken = nil then
  begin
    Result.Error := 'Failed to parse token';
    Exit;
  end;

  // 验证过期
  if LToken.Payload.IsExpired then
  begin
    LToken.Free;
    Result.Error := 'Token expired';
    Exit;
  end;

  // 验证有效性
  if not LToken.Payload.IsValid then
  begin
    LToken.Free;
    Result.Error := 'Token not yet valid';
    Exit;
  end;

  // 验证发行者
  if (FIssuer <> '') and (LToken.Payload.Issuer <> FIssuer) then
  begin
    LToken.Free;
    Result.Error := 'Invalid issuer';
    Exit;
  end;

  // 验证受众
  if (FAudience <> '') and (LToken.Payload.Audience <> FAudience) then
  begin
    LToken.Free;
    Result.Error := 'Invalid audience';
    Exit;
  end;

  Result.Valid := True;
  Result.Token := LToken;
end;

function TJWTManager.ParseToken(const AToken: string): TJWTToken;
var
  LParts: TArray<string>;
  LHeaderJson: TJSONObject;
  LPayloadJson: TJSONObject;
  LHeaderBytes: TBytes;
  LPayloadBytes: TBytes;
begin
  Result := nil;
  LHeaderJson := nil;
  LPayloadJson := nil;

  LParts := AToken.Split(['.']);
  if Length(LParts) <> 3 then
    Exit;

  try
    try
      LHeaderBytes := Base64URLDecode(LParts[0]);
      LPayloadBytes := Base64URLDecode(LParts[1]);

      LHeaderJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LHeaderBytes)) as TJSONObject;
      if LHeaderJson = nil then
        Exit;

      LPayloadJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LPayloadBytes)) as TJSONObject;
      if LPayloadJson = nil then
        Exit;

      Result := TJWTToken.Create;
      try
        // 直接写入记录字段，避免对记录属性赋值导致的编译器限制
        Result.FHeader.Alg := LHeaderJson.GetValue<string>('alg', 'HS256');
        Result.FHeader.Typ := LHeaderJson.GetValue<string>('typ', 'JWT');
        Result.Payload.FromJSON(LPayloadJson);
        Result.Signature := LParts[2];
        Result.RawToken := AToken;
      except
        FreeAndNil(Result);
      end;
    except
      // 任意解析/解码异常都视为无效 token
      FreeAndNil(Result);
    end;
  finally
    LPayloadJson.Free;
    LHeaderJson.Free;
  end;
end;

function TJWTManager.RefreshToken(const ARefreshToken: string): string;
var
  LResult: TJWTValidationResult;
  LRoles: TArray<string>;
begin
  Result := '';
  LResult := ValidateToken(ARefreshToken);
  if not LResult.Valid then
    Exit;

  try
    // 确保是刷新令牌
    if LResult.Token.Payload.GetStringClaim('type') <> 'refresh' then
      Exit;

    // 获取角色
    LRoles := LResult.Token.Payload.GetArrayClaim('roles');

    // 生成新的访问令牌
    Result := GenerateToken(LResult.Token.Payload.Subject, LRoles, nil, ttAccess);
  finally
    LResult.Token.Free;
  end;
end;

function TJWTManager.GetUserFromToken(const AToken: string): TAuthenticatedUser;
var
  LResult: TJWTValidationResult;
  LRoles: TArray<string>;
  LRole: string;
  LPair: TPair<string, TJSONValue>;
begin
  Result := nil;
  LResult := ValidateToken(AToken);
  if not LResult.Valid then
    Exit;

  try
    Result := TAuthenticatedUser.Create;
    Result.UserId := LResult.Token.Payload.Subject;
    Result.Username := LResult.Token.Payload.GetStringClaim('username', Result.UserId);
    Result.Email := LResult.Token.Payload.GetStringClaim('email');
    Result.AuthType := atBearer;
    Result.ExpiresAt := LResult.Token.Payload.ExpiresAt;

    // 复制角色
    LRoles := LResult.Token.Payload.GetArrayClaim('roles');
    for LRole in LRoles do
      Result.Roles.Add(LRole);

    // 复制声明
    for LPair in LResult.Token.Payload.Claims do
    begin
      if LPair.Value is TJSONString then
        Result.Claims.AddOrSetValue(LPair.Key, TJSONString(LPair.Value).Value);
    end;
  finally
    LResult.Token.Free;
  end;
end;

{ TApiKeyInfo }

constructor TApiKeyInfo.Create;
begin
  inherited;
  FRoles := TStringList.Create;
  FScopes := TStringList.Create;
  FCreatedAt := Now;
  FEnabled := True;
  FRateLimit := 1000;  // 默认每小时1000次
end;

destructor TApiKeyInfo.Destroy;
begin
  FRoles.Free;
  FScopes.Free;
  inherited;
end;

function TApiKeyInfo.IsExpired: Boolean;
begin
  Result := (FExpiresAt > 0) and (Now > FExpiresAt);
end;

function TApiKeyInfo.IsValid: Boolean;
begin
  Result := FEnabled and not IsExpired;
end;

function TApiKeyInfo.HasScope(const AScope: string): Boolean;
begin
  Result := (FScopes.Count = 0) or (FScopes.IndexOf(AScope) >= 0);
end;

{ TMemoryApiKeyStore }

constructor TMemoryApiKeyStore.Create;
begin
  inherited;
  FKeys := TObjectDictionary<string, TApiKeyInfo>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TMemoryApiKeyStore.Destroy;
begin
  FKeys.Free;
  FLock.Free;
  inherited;
end;

function TMemoryApiKeyStore.GetKey(const AKey: string): TApiKeyInfo;
var
  LInfo: TApiKeyInfo;
begin
  Result := nil;
  FLock.Enter;
  try
    if FKeys.TryGetValue(AKey, LInfo) then
    begin
      // 返回副本
      Result := TApiKeyInfo.Create;
      Result.Key := LInfo.Key;
      Result.Name := LInfo.Name;
      Result.UserId := LInfo.UserId;
      Result.Roles.Assign(LInfo.Roles);
      Result.Scopes.Assign(LInfo.Scopes);
      Result.CreatedAt := LInfo.CreatedAt;
      Result.ExpiresAt := LInfo.ExpiresAt;
      Result.LastUsedAt := LInfo.LastUsedAt;
      Result.UsageCount := LInfo.UsageCount;
      Result.RateLimit := LInfo.RateLimit;
      Result.Enabled := LInfo.Enabled;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryApiKeyStore.SaveKey(AKeyInfo: TApiKeyInfo);
var
  LInfo: TApiKeyInfo;
begin
  FLock.Enter;
  try
    // 创建副本存储
    LInfo := TApiKeyInfo.Create;
    LInfo.Key := AKeyInfo.Key;
    LInfo.Name := AKeyInfo.Name;
    LInfo.UserId := AKeyInfo.UserId;
    LInfo.Roles.Assign(AKeyInfo.Roles);
    LInfo.Scopes.Assign(AKeyInfo.Scopes);
    LInfo.CreatedAt := AKeyInfo.CreatedAt;
    LInfo.ExpiresAt := AKeyInfo.ExpiresAt;
    LInfo.LastUsedAt := AKeyInfo.LastUsedAt;
    LInfo.UsageCount := AKeyInfo.UsageCount;
    LInfo.RateLimit := AKeyInfo.RateLimit;
    LInfo.Enabled := AKeyInfo.Enabled;
    FKeys.AddOrSetValue(AKeyInfo.Key, LInfo);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryApiKeyStore.DeleteKey(const AKey: string);
begin
  FLock.Enter;
  try
    FKeys.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

function TMemoryApiKeyStore.ListKeys(const AUserId: string): TArray<TApiKeyInfo>;
var
  LList: TList<TApiKeyInfo>;
  LPair: TPair<string, TApiKeyInfo>;
  LInfo: TApiKeyInfo;
begin
  LList := TList<TApiKeyInfo>.Create;
  try
    FLock.Enter;
    try
      for LPair in FKeys do
      begin
        if (AUserId = '') or (LPair.Value.UserId = AUserId) then
        begin
          LInfo := TApiKeyInfo.Create;
          LInfo.Key := LPair.Value.Key;
          LInfo.Name := LPair.Value.Name;
          LInfo.UserId := LPair.Value.UserId;
          LInfo.Roles.Assign(LPair.Value.Roles);
          LInfo.Scopes.Assign(LPair.Value.Scopes);
          LInfo.CreatedAt := LPair.Value.CreatedAt;
          LInfo.ExpiresAt := LPair.Value.ExpiresAt;
          LInfo.LastUsedAt := LPair.Value.LastUsedAt;
          LInfo.UsageCount := LPair.Value.UsageCount;
          LInfo.RateLimit := LPair.Value.RateLimit;
          LInfo.Enabled := LPair.Value.Enabled;
          LList.Add(LInfo);
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

{ TApiKeyManager }

constructor TApiKeyManager.Create(AStore: IApiKeyStore);
begin
  inherited Create;
  FStore := AStore;
  FKeyPrefix := 'sk_';
  FKeyLength := 32;
end;

destructor TApiKeyManager.Destroy;
begin
  inherited;
end;

function TApiKeyManager.GenerateKeyString: string;
var
  LGUID: TGUID;
  LHash: string;
  LRandomBytes: TBytes;
  I: Integer;
  {$IFDEF MSWINDOWS}
  hProv: NativeUInt;
  {$ENDIF}
begin
  // BUG-114 FIX: 使用更安全的随机数生成方式
  // 组合多个熵源以增加随机性
  CreateGUID(LGUID);

  // 添加额外的随机熵
  SetLength(LRandomBytes, 32);
  {$IFDEF MSWINDOWS}
  // 在Windows上使用CryptGenRandom获取密码学安全的随机数
  hProv := 0;
  if CryptAcquireContext(@hProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) then
  begin
    try
      CryptGenRandom(hProv, Length(LRandomBytes), @LRandomBytes[0]);
    finally
      CryptReleaseContext(hProv, 0);
    end;
  end
  else
  begin
    // 回退方案：使用GUID和时间戳
    for I := 0 to High(LRandomBytes) do
      LRandomBytes[I] := Random(256);
  end;
  {$ELSE}
  // 非Windows平台使用Random（注意：这不是密码学安全的）
  Randomize;
  for I := 0 to High(LRandomBytes) do
    LRandomBytes[I] := Random(256);
  {$ENDIF}
  
  // 组合GUID、时间戳和随机字节生成最终密钥
  LHash := THashSHA2.GetHashString(
    GUIDToString(LGUID) + 
    FloatToStr(Now) + 
    TNetEncoding.Base64.EncodeBytesToString(LRandomBytes), 
    SHA256
  );
  Result := FKeyPrefix + Copy(LHash, 1, FKeyLength);
end;

function TApiKeyManager.CreateKey(const AName, AUserId: string;
  const ARoles: array of string;
  AExpiresAt: TDateTime;
  ARateLimit: Integer): TApiKeyInfo;
var
  LRole: string;
begin
  Result := TApiKeyInfo.Create;
  Result.Key := GenerateKeyString;
  Result.Name := AName;
  Result.UserId := AUserId;
  Result.CreatedAt := Now;
  Result.ExpiresAt := AExpiresAt;
  if ARateLimit > 0 then
    Result.RateLimit := ARateLimit;

  for LRole in ARoles do
    Result.Roles.Add(LRole);

  FStore.SaveKey(Result);
end;

function TApiKeyManager.ValidateKey(const AKey: string): TApiKeyInfo;
begin
  Result := FStore.GetKey(AKey);
  if Result <> nil then
  begin
    if not Result.IsValid then
    begin
      FreeAndNil(Result);
      Exit;
    end;
    // 更新使用统计
    UpdateUsage(AKey);
  end;
end;

procedure TApiKeyManager.RevokeKey(const AKey: string);
var
  LInfo: TApiKeyInfo;
begin
  LInfo := FStore.GetKey(AKey);
  if LInfo <> nil then
  begin
    try
      LInfo.Enabled := False;
      FStore.SaveKey(LInfo);
    finally
      LInfo.Free;
    end;
  end;
end;

procedure TApiKeyManager.UpdateUsage(const AKey: string);
var
  LInfo: TApiKeyInfo;
begin
  LInfo := FStore.GetKey(AKey);
  if LInfo <> nil then
  begin
    try
      LInfo.LastUsedAt := Now;
      Inc(LInfo.FUsageCount);
      FStore.SaveKey(LInfo);
    finally
      LInfo.Free;
    end;
  end;
end;

function TApiKeyManager.GetUserFromKey(const AKey: string): TAuthenticatedUser;
var
  LInfo: TApiKeyInfo;
  I: Integer;
begin
  Result := nil;
  LInfo := ValidateKey(AKey);
  if LInfo = nil then
    Exit;

  try
    Result := TAuthenticatedUser.Create;
    Result.UserId := LInfo.UserId;
    Result.Username := LInfo.Name;
    Result.AuthType := atApiKey;
    Result.ExpiresAt := LInfo.ExpiresAt;

    for I := 0 to LInfo.Roles.Count - 1 do
      Result.Roles.Add(LInfo.Roles[I]);

    Result.Claims.AddOrSetValue('api_key_name', LInfo.Name);
  finally
    LInfo.Free;
  end;
end;

{ TRateLimiter }

constructor TRateLimiter.Create;
begin
  inherited;
  FRecords := TDictionary<string, TRateLimitRecord>.Create;
  FLock := TCriticalSection.Create;
  FDefaultLimit := 100;
  FWindowSeconds := 60;
  FStrategy := rlsFixedWindow;
end;

destructor TRateLimiter.Destroy;
begin
  FRecords.Free;
  FLock.Free;
  inherited;
end;

function TRateLimiter.GetKey(AContext: TApiContext): string;
var
  LUser: TAuthenticatedUser;
begin
  LUser := GetAuthenticatedUser(AContext);
  if LUser <> nil then
    Result := 'user:' + LUser.UserId
  else
    Result := 'ip:' + AContext.Request.RemoteIP;
end;

procedure TRateLimiter.CleanupExpired;
var
  LKeysToRemove: TList<string>;
  LPair: TPair<string, TRateLimitRecord>;
begin
  LKeysToRemove := TList<string>.Create;
  try
    for LPair in FRecords do
      if Now > LPair.Value.WindowEnd then
        LKeysToRemove.Add(LPair.Key);

    for var LKey in LKeysToRemove do
      FRecords.Remove(LKey);
  finally
    LKeysToRemove.Free;
  end;
end;

function TRateLimiter.Check(AContext: TApiContext; ALimit: Integer): TRateLimitResult;
var
  LKey: string;
  LRecord: TRateLimitRecord;
  LNow: TDateTime;
  LLimit: Integer;
begin
  if ALimit > 0 then
    LLimit := ALimit
  else
    LLimit := FDefaultLimit;

  LKey := GetKey(AContext);
  LNow := Now;

  FLock.Enter;
  try
    // 定期清理
    if Random(10) = 0 then
      CleanupExpired;

    if FRecords.TryGetValue(LKey, LRecord) then
    begin
      // 检查窗口是否过期
      if LNow > LRecord.WindowEnd then
      begin
        // 开始新窗口
        LRecord.Count := 1;
        LRecord.WindowStart := LNow;
        LRecord.WindowEnd := IncSecond(LNow, FWindowSeconds);
      end
      else
      begin
        Inc(LRecord.Count);
      end;
    end
    else
    begin
      // 新记录
      LRecord.Key := LKey;
      LRecord.Count := 1;
      LRecord.WindowStart := LNow;
      LRecord.WindowEnd := IncSecond(LNow, FWindowSeconds);
    end;

    FRecords.AddOrSetValue(LKey, LRecord);

    Result.Limit := LLimit;
    Result.Remaining := LLimit - LRecord.Count;
    if Result.Remaining < 0 then
      Result.Remaining := 0;
    Result.ResetAt := LRecord.WindowEnd;
    Result.RetryAfter := SecondsBetween(LNow, LRecord.WindowEnd);
    Result.Allowed := LRecord.Count <= LLimit;
  finally
    FLock.Leave;
  end;
end;

procedure TRateLimiter.Reset(const AKey: string);
begin
  FLock.Enter;
  try
    FRecords.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TRateLimiter.SetHeaders(AContext: TApiContext; const AResult: TRateLimitResult);
begin
  AContext.Response.SetHeader('X-RateLimit-Limit', IntToStr(AResult.Limit));
  AContext.Response.SetHeader('X-RateLimit-Remaining', IntToStr(AResult.Remaining));
  AContext.Response.SetHeader('X-RateLimit-Reset', IntToStr(DateTimeToUnix(AResult.ResetAt, False)));
  if not AResult.Allowed then
    AContext.Response.SetHeader('Retry-After', IntToStr(AResult.RetryAfter));
end;

{ TAuthMiddleware }

constructor TAuthMiddleware.Create;
begin
  inherited;
  FApiKeyHeaderName := 'X-API-Key';
  FApiKeyQueryParam := '';
  FRequireAuth := True;
end;

destructor TAuthMiddleware.Destroy;
begin
  inherited;
end;

function TAuthMiddleware.ExtractBearerToken(AContext: TApiContext): string;
var
  LAuth: string;
begin
  Result := '';

  // BUG-043 FIX: 优先使用标准 Authorization 头部
  // 标准 Bearer Token 认证应使用 "Authorization: Bearer <token>" 格式
  // 同时保留 X-Authorization 作为兼容入口（用于某些代理或框架限制的情况）
  LAuth := AContext.Request.GetHeader('Authorization');
  
  // 如果标准头部为空，尝试自定义头部（向后兼容）
  if LAuth = '' then
    LAuth := AContext.Request.GetHeader('X-Authorization');

  if LAuth.StartsWith('Bearer ', True) then
    Result := Copy(LAuth, 8, Length(LAuth)).Trim
  else if LAuth.StartsWith('Token ', True) then
    // 支持 "Token <token>" 格式（某些 API 客户端使用）
    Result := Copy(LAuth, 7, Length(LAuth)).Trim;
end;

function TAuthMiddleware.ExtractBasicCredentials(AContext: TApiContext;
  out AUsername, APassword: string): Boolean;
var
  LAuth: string;
  LDecoded: string;
  LPos: Integer;
begin
  Result := False;
  AUsername := '';
  APassword := '';

  LAuth := AContext.Request.GetHeader('Authorization');
  if LAuth.StartsWith('Basic ', True) then
  begin
    LDecoded := TEncoding.UTF8.GetString(
      TNetEncoding.Base64.DecodeStringToBytes(Copy(LAuth, 7, Length(LAuth)))
    );
    LPos := Pos(':', LDecoded);
    if LPos > 0 then
    begin
      AUsername := Copy(LDecoded, 1, LPos - 1);
      APassword := Copy(LDecoded, LPos + 1, Length(LDecoded));
      Result := True;
    end;
  end;
end;

function TAuthMiddleware.ExtractApiKey(AContext: TApiContext): string;
begin
  // 先从头部获取
  Result := AContext.Request.GetHeader(FApiKeyHeaderName);
  // URL query API keys are unsafe by default; enable only by explicit opt-in.
  if (Result = '') and (FApiKeyQueryParam <> '') then
    Result := AContext.Request.GetQueryParam(FApiKeyQueryParam);
end;

function TAuthMiddleware.GetMiddleware: TMiddlewareFunc;
begin
  Result := procedure(AContext: TApiContext; ANext: TProc)
  var
    LToken: string;
    LApiKey: string;
    LUsername, LPassword: string;
    LUser: TAuthenticatedUser;
  begin
    LUser := nil;

    // 尝试 Bearer 令牌认证
    if (LUser = nil) and (FJWTManager <> nil) then
    begin
      LToken := ExtractBearerToken(AContext);
      if LToken <> '' then
      begin
        LUser := FJWTManager.GetUserFromToken(LToken);
        if LUser <> nil then
          AContext.SetItem(TAuthContextKeys.Token, LToken);
      end;
    end;

    // 尝试 API Key 认证
    if LUser = nil then
    begin
      LApiKey := ExtractApiKey(AContext);
      if LApiKey <> '' then
      begin
        if Assigned(FApiKeyCallback) then
          LUser := FApiKeyCallback(LApiKey)
        else if FApiKeyManager <> nil then
          LUser := FApiKeyManager.GetUserFromKey(LApiKey);
        if LUser <> nil then
          AContext.SetItem(TAuthContextKeys.ApiKey, LApiKey);
      end;
    end;

    // 尝试 Basic 认证
    if (LUser = nil) and Assigned(FBasicAuthCallback) then
    begin
      if ExtractBasicCredentials(AContext, LUsername, LPassword) then
        LUser := FBasicAuthCallback(LUsername, LPassword);
    end;

    // 设置用户
    if LUser <> nil then
    begin
      AContext.SetItem(TAuthContextKeys.User, LUser);
      AContext.SetItem(TAuthContextKeys.AuthType, TValue.From<TAuthType>(LUser.AuthType));
    end
    else if FRequireAuth then
    begin
      AContext.Response.Unauthorized('Authentication required');
      AContext.Abort;
      Exit;
    end;

    try
      ANext();
    finally
      // 当前中间件创建/持有的用户对象生命周期仅限本次请求，避免泄漏。
      // 如果应用层希望复用/缓存用户对象，应自行在回调中管理生命周期。
      if LUser <> nil then
        LUser.Free;
    end;
  end;
end;

function TAuthMiddleware.GetOptionalMiddleware: TMiddlewareFunc;
begin
  // 兼容性版本：当前返回 nil，中间件链会直接继续执行 ANext。
  // 如果调用方需要真正的“可选认证”逻辑，可以在应用侧手动组合
  // GetMiddleware 结果和其他中间件。
  Result := nil;
end;

{ TAuthorizationMiddleware }

constructor TAuthorizationMiddleware.Create;
begin
  inherited;
  FRequiredRoles := TStringList.Create;
  FAnyRole := True;
end;

destructor TAuthorizationMiddleware.Destroy;
begin
  FRequiredRoles.Free;
  inherited;
end;

function TAuthorizationMiddleware.GetMiddleware: TMiddlewareFunc;
var
  LRoles: TStringList;
  LAnyRole: Boolean;
begin
  LRoles := FRequiredRoles;
  LAnyRole := FAnyRole;

  Result := procedure(AContext: TApiContext; ANext: TProc)
  var
    LUser: TAuthenticatedUser;
    I: Integer;
    LHasRole: Boolean;
  begin
    LUser := GetAuthenticatedUser(AContext);
    if LUser = nil then
    begin
      AContext.Response.Unauthorized('Authentication required');
      AContext.Abort;
      Exit;
    end;

    if LRoles.Count > 0 then
    begin
      if LAnyRole then
      begin
        // 任一角色匹配
        LHasRole := False;
        for I := 0 to LRoles.Count - 1 do
        begin
          if LUser.HasRole(LRoles[I]) then
          begin
            LHasRole := True;
            Break;
          end;
        end;
      end
      else
      begin
        // 所有角色都要匹配
        LHasRole := True;
        for I := 0 to LRoles.Count - 1 do
        begin
          if not LUser.HasRole(LRoles[I]) then
          begin
            LHasRole := False;
            Break;
          end;
        end;
      end;

      if not LHasRole then
      begin
        AContext.Response.Forbidden('Insufficient permissions');
        AContext.Abort;
        Exit;
      end;
    end;

    ANext();
  end;
end;

class function TAuthorizationMiddleware.RequireRoles(const ARoles: array of string;
  AAnyRole: Boolean): TMiddlewareFunc;
var
  LRolesCopy: TArray<string>;
  I: Integer;
begin
  // 复制角色列表到闭包可捕获的动态数组，避免依赖实例对象生命周期。
  SetLength(LRolesCopy, Length(ARoles));
  for I := 0 to High(ARoles) do
    LRolesCopy[I] := ARoles[I];

  Result := procedure(AContext: TApiContext; ANext: TProc)
  var
    LUser: TAuthenticatedUser;
    LHasRole: Boolean;
    LRole: string;
  begin
    LUser := GetAuthenticatedUser(AContext);
    if LUser = nil then
    begin
      AContext.Response.Unauthorized('Authentication required');
      AContext.Abort;
      Exit;
    end;

    if Length(LRolesCopy) > 0 then
    begin
      if AAnyRole then
      begin
        // 任一角色匹配
        LHasRole := False;
        for LRole in LRolesCopy do
        begin
          if LUser.HasRole(LRole) then
          begin
            LHasRole := True;
            Break;
          end;
        end;
      end
      else
      begin
        // 所有角色都要匹配
        LHasRole := True;
        for LRole in LRolesCopy do
        begin
          if not LUser.HasRole(LRole) then
          begin
            LHasRole := False;
            Break;
          end;
        end;
      end;

      if not LHasRole then
      begin
        AContext.Response.Forbidden('Insufficient permissions');
        AContext.Abort;
        Exit;
      end;
    end;

    ANext();
  end;
end;

class function TAuthorizationMiddleware.RequireRole(const ARole: string): TMiddlewareFunc;
begin
  Result := RequireRoles([ARole], True);
end;

{ BUG-044 FIX: CSRF 防护中间件 }

function CreateCSRFMiddleware(const ASecret: string; ATokenExpiry: Integer = 3600): TMiddlewareFunc;
var
  LSecret: string;
  LExpiry: Integer;
begin
  LSecret := ASecret;
  LExpiry := ATokenExpiry;
  
  Result := procedure(AContext: TApiContext; ANext: TProc)
  var
    LMethod: THttpMethod;
    LCSRFToken: string;
    LCookieToken: string;
    LExpectedToken: string;
    LTimestamp: Int64;
    LNow: Int64;
  begin
    LMethod := AContext.Request.Method;
    
    // 只对修改数据的请求验证 CSRF
    if LMethod in [hmPost, hmPut, hmPatch, hmDelete] then
    begin
      // 从请求头或表单获取 CSRF Token
      LCSRFToken := AContext.Request.GetHeader('X-CSRF-Token');
      if LCSRFToken = '' then
        LCSRFToken := AContext.Request.GetFormField('_csrf');
      
      // 从 Cookie 获取 Token
      LCookieToken := AContext.Request.GetHeader('Cookie');
      // 简化处理：实际应解析 Cookie
      
      if LCSRFToken = '' then
      begin
        AContext.Response.Forbidden('CSRF token missing');
        AContext.Abort;
        Exit;
      end;
      
      // 验证 Token 格式和签名
      // Token 格式: timestamp.signature
      var Parts := LCSRFToken.Split(['.']);
      if Length(Parts) <> 2 then
      begin
        AContext.Response.Forbidden('Invalid CSRF token format');
        AContext.Abort;
        Exit;
      end;
      
      // 验证时间戳
      if not TryStrToInt64(Parts[0], LTimestamp) then
      begin
        AContext.Response.Forbidden('Invalid CSRF token');
        AContext.Abort;
        Exit;
      end;
      
      LNow := DateTimeToUnix(Now, False);
      if (LNow - LTimestamp) > LExpiry then
      begin
        AContext.Response.Forbidden('CSRF token expired');
        AContext.Abort;
        Exit;
      end;
      
      // 验证签名
      LExpectedToken := THashSHA2.GetHashString(Parts[0] + LSecret, SHA256);
      if not SameText(Parts[1], LExpectedToken) then
      begin
        AContext.Response.Forbidden('Invalid CSRF token signature');
        AContext.Abort;
        Exit;
      end;
    end;
    
    ANext();
  end;
end;

function GenerateCSRFToken(const ASecret: string): string;
var
  LTimestamp: string;
  LSignature: string;
begin
  LTimestamp := IntToStr(DateTimeToUnix(Now, False));
  LSignature := THashSHA2.GetHashString(LTimestamp + ASecret, SHA256);
  Result := LTimestamp + '.' + LSignature;
end;

end.
