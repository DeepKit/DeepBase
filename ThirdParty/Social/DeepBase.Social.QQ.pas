unit DeepBase.Social.QQ;

{*******************************************************************************
  DeepBase QQ Social Integration

  Supports:
    - QQ OAuth2 登录
    - OpenID 获取
    - 获取用户信息
    - Token 刷新

  Note: QQ OAuth2 has special characteristics:
    - Token endpoint may return a callback JSON wrapper instead of standard JSON
    - Requires OpenID step (exchange token for openid before user info)
    - Uses GET for token endpoint (unlike standard OAuth2 POST)

  Official Docs: https://wiki.connect.qq.com/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  DeepBase.Social;

type
  /// <summary>QQ configuration</summary>
  TQQConfig = class(TSocialConfig)
  private
    FKeyStorageMode: TKeyStorageMode;
    FCredentialTarget: string;
  protected
    // BUG-019 FIX: 安全存储/读取密钥
    function ProtectKey(const APlainKey: string): string;
    function UnprotectKey(const AEncryptedKey: string): string;
    function GetCredentialKey(const AKeyName: string): string;
    procedure SetCredentialKey(const AKeyName, AValue: string);
  public
    constructor Create; reintroduce;

    /// <summary>Load keys from secure storage (Credential Manager)</summary>
    procedure LoadKeysFromCredentialManager; virtual;
    /// <summary>Save keys to secure storage (Credential Manager)</summary>
    procedure SaveKeysToCredentialManager; virtual;

    // BUG-019 FIX: 密钥安全存储属�?    property KeyStorageMode: TKeyStorageMode read FKeyStorageMode write FKeyStorageMode;
    property CredentialTarget: string read FCredentialTarget write FCredentialTarget;

    /// <summary>QQ AppId (oauth_consumer_key in API calls)</summary>
    property AppId: string read FAppId write FAppId;
    /// <summary>QQ AppKey (same as AppSecret for OAuth)</summary>
    property AppKey: string read FAppSecret write FAppSecret;
    /// <summary>Redirect URI</summary>
    property RedirectUri: string read FRedirectUri write FRedirectUri;
  end;

  /// <summary>QQ OAuth2 client</summary>
  TQQClient = class(TSocialClient)
  private
    FOpenId: string;
    function GetQQConfig: TQQConfig;
    function ParseCallbackJson(const ARawResponse: string): TJSONObject;
    function ParseQQGender(const AValue: string): TSocialGender;
  public
    constructor Create(AConfig: TQQConfig); reintroduce;

    // ISocialClient
    function GetAuthUrl(const AState: string = ''): string; override;
    function ExchangeCode(const ACode: string): TSocialToken; overload; override;
    function RefreshToken(const ARefreshToken: string): TSocialToken; override;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;

    /// <summary>Exchange access_token for OpenID (QQ-specific step)</summary>
    function GetOpenId(const AAccessToken: string): string;

    property QQConfig: TQQConfig read GetQQConfig;
    /// <summary>Cached OpenID from last GetOpenId call</summary>
    property OpenId: string read FOpenId;
  end;

implementation

uses
  DeepBase.Security.DPAPI;  // BUG-019 FIX: 安全密钥存储支持

const
  // QQ OAuth2 endpoints
  QQ_AUTH_URL    = 'https://graph.qq.com/oauth2.0/authorize';
  QQ_TOKEN_URL   = 'https://graph.qq.com/oauth2.0/token';
  QQ_OPENID_URL  = 'https://graph.qq.com/oauth2.0/me';
  QQ_USER_URL    = 'https://graph.qq.com/user/get_user_info';

{ TQQConfig }

constructor TQQConfig.Create;
begin
  inherited Create(spQQ);
  FScope := 'get_user_info';
  // BUG-019 FIX: 初始化安全存储设�?  FKeyStorageMode := ksmDPAPI;
  FCredentialTarget := 'DeepBase.Social.QQ';
end;

{ BUG-019 FIX: TQQConfig 安全存储方法实现 }

function TQQConfig.ProtectKey(const APlainKey: string): string;
begin
  if APlainKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.ProtectString(APlainKey);
    ksmCredential:
      Result := APlainKey;
  else
    Result := APlainKey;
  end;
end;

function TQQConfig.UnprotectKey(const AEncryptedKey: string): string;
begin
  if AEncryptedKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.UnprotectString(AEncryptedKey);
    ksmCredential:
      Result := AEncryptedKey;
  else
    Result := AEncryptedKey;
  end;
end;

function TQQConfig.GetCredentialKey(const AKeyName: string): string;
var
  TargetName: string;
begin
  Result := '';
  if FKeyStorageMode <> ksmCredential then
    Exit;

  TargetName := FCredentialTarget + '.' + AKeyName;
  Result := TCredentialManager.GetCredential(TargetName, '');
end;

procedure TQQConfig.SetCredentialKey(const AKeyName, AValue: string);
var
  TargetName: string;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  TargetName := FCredentialTarget + '.' + AKeyName;
  if AValue <> '' then
    TCredentialManager.SaveCredential(TargetName, '', AValue)
  else
    TCredentialManager.DeleteCredential(TargetName);
end;

procedure TQQConfig.LoadKeysFromCredentialManager;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  FAppId := GetCredentialKey('AppId');
  FAppSecret := GetCredentialKey('AppKey');
end;

procedure TQQConfig.SaveKeysToCredentialManager;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  SetCredentialKey('AppId', FAppId);
  SetCredentialKey('AppKey', FAppSecret);
end;

{ TQQClient }

constructor TQQClient.Create(AConfig: TQQConfig);
begin
  inherited Create(AConfig);
end;

function TQQClient.GetQQConfig: TQQConfig;
begin
  Result := TQQConfig(FConfig);
end;

/// <summary>
/// Parse QQ callback({...}) format response into a TJSONObject.
/// QQ OAuth2 endpoints return data wrapped in callback(...) instead of raw JSON.
/// </summary>
function TQQClient.ParseCallbackJson(const ARawResponse: string): TJSONObject;
var
  JsonStr: string;
  StartPos, EndPos, Depth, I: Integer;
begin
  Result := nil;

  // Try parsing as plain JSON first (some error responses are plain JSON)
  Result := TJSONObject.ParseJSONValue(ARawResponse) as TJSONObject;
  if Assigned(Result) then
    Exit;

  // Parse callback({...}) format
  StartPos := Pos('callback(', ARawResponse);
  if StartPos = 0 then
    StartPos := Pos('Callback(', ARawResponse);
  if StartPos = 0 then
    Exit;

  // Find the opening brace after "callback("
  StartPos := Pos('{', ARawResponse, StartPos);
  if StartPos = 0 then
    Exit;

  // Find the matching closing brace by bracket counting (handles nested JSON)
  Depth := 0;
  EndPos := 0;
  for I := StartPos to Length(ARawResponse) do
  begin
    if ARawResponse[I] = '{' then
      Inc(Depth)
    else if ARawResponse[I] = '}' then
    begin
      Dec(Depth);
      if Depth = 0 then
      begin
        EndPos := I;
        Break;
      end;
    end;
  end;

  if EndPos <= StartPos then
    Exit;

  JsonStr := Copy(ARawResponse, StartPos, EndPos - StartPos + 1);
  Result := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
end;

function TQQClient.GetAuthUrl(const AState: string): string;
var
  Params: TDictionary<string, string>;
  State: string;
begin
  State := PrepareOAuthState(AState);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', FConfig.AppId);
    Params.Add('redirect_uri', FConfig.RedirectUri);
    Params.Add('response_type', 'code');
    Params.Add('state', State);

    if FConfig.Scope <> '' then
      Params.Add('scope', FConfig.Scope);

    AddPKCEAuthParams(Params);

    Result := QQ_AUTH_URL + '?' + TSocialHelper.BuildQueryString(Params);
  finally
    FreeAndNil(Params);
  end;
end;

function TQQClient.ExchangeCode(const ACode: string): TSocialToken;
var
  Url, Response, PostData: string;
  Params: TDictionary<string, string>;
  ParsedParams: TDictionary<string, string>;
  Value: string;
begin
  Result.Clear;

  // Prefer POST body to avoid exposing client_secret in URL logs/hiDeepStory.
  // Keep GET fallback for legacy endpoint compatibility.
  Params := TDictionary<string, string>.Create;
  try
    Params.Add('grant_type', 'authorization_code');
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('code', ACode);
    Params.Add('redirect_uri', FConfig.RedirectUri);
    AddPKCETokenParams(Params);

    PostData := TSocialHelper.BuildQueryString(Params);
    try
      Response := DoPost(QQ_TOKEN_URL, PostData);
    except
      on ESocialNetworkError do
      begin
        Url := QQ_TOKEN_URL + '?' + PostData;
        Response := DoGet(Url);
      end;
    end;
  finally
    Params.Free;
  end;

  // QQ token response is in callback({...}) format
  // Try parsing as URL-encoded first (some QQ responses use this format)
  if (Pos('callback(', Response) = 0) and (Pos('Callback(', Response) = 0) then
  begin
    // Standard URL-encoded response: access_token=xxx&expires_in=xxx&refresh_token=xxx
    ParsedParams := TSocialHelper.ParseQueryString(Response);
    try
      ParsedParams.TryGetValue('access_token', Result.AccessToken);
      ParsedParams.TryGetValue('refresh_token', Result.RefreshToken);

      if ParsedParams.TryGetValue('expires_in', Value) then
        TryStrToInt(Value, Result.ExpiresIn);

      if Result.ExpiresIn > 0 then
        Result.ExpiresAt := Now + Result.ExpiresIn / 86400;
    finally
      FreeAndNil(ParsedParams);
    end;
  end
  else
  begin
    // callback({...}) format - should not normally happen for token endpoint,
    // but handle defensively
    raise ESocialNetworkError.Create(
      'Unexpected callback format in token response', 'UNEXPECTED_FORMAT', spQQ);
  end;

  if Result.AccessToken = '' then
    raise ESocialAuthError.Create('No access token in response', 'NO_TOKEN', spQQ);
end;

function TQQClient.GetOpenId(const AAccessToken: string): string;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode: string;
  ErrMsg: string;
begin
  Result := '';

  // QQ OpenID API requires access_token as a query parameter per their spec.
  // This exposes the token to server-side logs; acceptable because QQ has no
  // header-based alternative and the token scope is limited to OpenID retrieval.
  Url := Format('%s?access_token=%s', [QQ_OPENID_URL,
    TSocialHelper.UrlEncode(AAccessToken)]);

  Response := DoGet(Url);

  JsonObj := ParseCallbackJson(Response);
  if not Assigned(JsonObj) then
    raise ESocialNetworkError.Create(
      'Invalid OpenID response: failed to parse callback JSON', 'INVALID_JSON', spQQ);

  try
    // Check for error
    if JsonObj.TryGetValue<string>('error', ErrCode) then
    begin
      JsonObj.TryGetValue<string>('error_description', ErrMsg);
      raise ESocialAuthError.Create(
        Format('Failed to get OpenID: %s', [ErrMsg]), ErrCode, spQQ);
    end;

    Result := JsonObj.GetValue<string>('openid', '');
    if Result = '' then
      raise ESocialAuthError.Create('No openid in response', 'NO_OPENID', spQQ);

    // Cache for later use
    FOpenId := Result;
  finally
    JsonObj.Free;
  end;
end;

function TQQClient.RefreshToken(const ARefreshToken: string): TSocialToken;
var
  Url, Response, PostData: string;
  Params: TDictionary<string, string>;
  ParsedParams: TDictionary<string, string>;
  Value: string;
begin
  Result.Clear;

  if ARefreshToken = '' then
    raise ESocialAuthError.Create('Refresh token is empty', 'NO_REFRESH_TOKEN', spQQ);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('grant_type', 'refresh_token');
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('refresh_token', ARefreshToken);

    PostData := TSocialHelper.BuildQueryString(Params);
    try
      Response := DoPost(QQ_TOKEN_URL, PostData);
    except
      on ESocialNetworkError do
      begin
        Url := QQ_TOKEN_URL + '?' + PostData;
        Response := DoGet(Url);
      end;
    end;
  finally
    Params.Free;
  end;

  // Parse URL-encoded response
  ParsedParams := TSocialHelper.ParseQueryString(Response);
  try
    ParsedParams.TryGetValue('access_token', Result.AccessToken);
    ParsedParams.TryGetValue('refresh_token', Result.RefreshToken);

    if ParsedParams.TryGetValue('expires_in', Value) then
      TryStrToInt(Value, Result.ExpiresIn);

    if Result.ExpiresIn > 0 then
      Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

    // Keep original refresh token if not returned
    if Result.RefreshToken = '' then
      Result.RefreshToken := ARefreshToken;
  finally
    FreeAndNil(ParsedParams);
  end;
end;

function TQQClient.ParseQQGender(const AValue: string): TSocialGender;
var
  Lower: string;
begin
  Lower := LowerCase(AValue);
  if (Lower = 'm') or (Lower = 'male') or (AValue = #30007) then
    Result := sgMale
  else if (Lower = 'f') or (Lower = 'female') or (AValue = #22899) then
    Result := sgFemale
  else
    Result := sgUnknown;
end;

function TQQClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  GenderStr: string;
  RetCode: Integer;
  ErrMsg: string;
  OpenIdToUse: string;
begin
  Result.Clear;
  Result.Provider := spQQ;

  // Determine OpenID: use token's OpenId, or cached value, or fetch it
  OpenIdToUse := AToken.OpenId;
  if OpenIdToUse = '' then
    OpenIdToUse := FOpenId;
  if OpenIdToUse = '' then
    OpenIdToUse := GetOpenId(AToken.AccessToken);

  // QQ user info requires: access_token, openid, oauth_consumer_key (AppId)
  Url := Format('%s?access_token=%s&openid=%s&oauth_consumer_key=%s',
    [QQ_USER_URL,
     TSocialHelper.UrlEncode(AToken.AccessToken),
     TSocialHelper.UrlEncode(OpenIdToUse),
     TSocialHelper.UrlEncode(FConfig.AppId)]);

  try
    Response := DoGet(Url);
    Result.RawJson := Response;

    // QQ user info response is standard JSON (not callback format)
    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
    begin
      Result := TSocialUserInfo.Fail('INVALID_JSON', 'Invalid user info response');
      Exit;
    end;

    try
      // Check for error (ret < 0 means error)
      if JsonObj.TryGetValue<Integer>('ret', RetCode) and (RetCode <> 0) then
      begin
        JsonObj.TryGetValue<string>('msg', ErrMsg);
        Result := TSocialUserInfo.Fail(IntToStr(RetCode), ErrMsg);
        Exit;
      end;

      // Map QQ fields to TSocialUserInfo
      Result.OpenId := OpenIdToUse;
      JsonObj.TryGetValue<string>('nickname', Result.Nickname);
      JsonObj.TryGetValue<string>('figureurl_qq_2', Result.Avatar);

      // Fallback avatar sizes
      if Result.Avatar = '' then
        JsonObj.TryGetValue<string>('figureurl_qq_1', Result.Avatar);
      if Result.Avatar = '' then
        JsonObj.TryGetValue<string>('figureurl', Result.Avatar);

      // Gender
      if JsonObj.TryGetValue<string>('gender', GenderStr) then
        Result.Gender := ParseQQGender(GenderStr);

      JsonObj.TryGetValue<string>('city', Result.City);
      JsonObj.TryGetValue<string>('province', Result.Province);

      Result.Country := 'CN';
      Result.Success := True;
    finally
      JsonObj.Free;
    end;
  except
    on E: ESocialError do
    begin
      Result.ErrorCode := E.ErrorCode;
      Result.ErrorMessage := E.Message;
    end;
    on E: Exception do
    begin
      Result.ErrorCode := 'ERROR';
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

end.
