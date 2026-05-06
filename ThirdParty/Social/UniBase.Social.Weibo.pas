unit UniBase.Social.Weibo;

{*******************************************************************************
  UniBase Weibo (微博) Social Integration

  Supports:
    - 微博 OAuth2 登录
    - 获取用户信息
    - Token 刷新

  Official Docs: https://open.weibo.com/wiki/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Social;

type
  /// <summary>Key storage mode for sensitive data</summary>
  TKeyStorageMode = (
    ksmPlainText,      // Not recommended: store as plain text (legacy)
    ksmDPAPI,          // Windows DPAPI encryption (recommended)
    ksmCredential      // Windows Credential Manager
  );

  /// <summary>Weibo configuration</summary>
  TWeiboConfig = class(TSocialConfig)
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

    // BUG-019 FIX: 密钥安全存储属性
    property KeyStorageMode: TKeyStorageMode read FKeyStorageMode write FKeyStorageMode;
    property CredentialTarget: string read FCredentialTarget write FCredentialTarget;

    /// <summary>Weibo AppKey (same as AppId for OAuth)</summary>
    property AppKey: string read FAppId write FAppId;
    /// <summary>Weibo AppSecret (same as AppSecret for OAuth)</summary>
    property AppSecret: string read FAppSecret write FAppSecret;
    /// <summary>Redirect URI</summary>
    property RedirectUri: string read FRedirectUri write FRedirectUri;
  end;

  /// <summary>Weibo OAuth2 client</summary>
  TWeiboClient = class(TSocialClient)
  private
    function GetWeiboConfig: TWeiboConfig;
    function ParseWeiboGender(const AValue: string): TSocialGender;
  public
    constructor Create(AConfig: TWeiboConfig); reintroduce;

    // ISocialClient
    function GetAuthUrl(const AState: string = ''): string; override;
    function ExchangeCode(const ACode: string): TSocialToken; overload; override;
    function RefreshToken(const ARefreshToken: string): TSocialToken; override;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;

    property WeiboConfig: TWeiboConfig read GetWeiboConfig;
  end;

implementation

uses
  UniBase.Security.DPAPI;  // BUG-019 FIX: 安全密钥存储支持

const
  // Weibo OAuth2 endpoints
  WEIBO_AUTH_URL    = 'https://api.weibo.com/oauth2/authorize';
  WEIBO_TOKEN_URL   = 'https://api.weibo.com/oauth2/access_token';
  WEIBO_USER_URL    = 'https://api.weibo.com/2/users/show.json';

{ TWeiboConfig }

constructor TWeiboConfig.Create;
begin
  inherited Create(spWeibo);
  FScope := 'all';
  // BUG-019 FIX: 初始化安全存储设置
  FKeyStorageMode := ksmDPAPI;
  FCredentialTarget := 'UniBase.Social.Weibo';
end;

{ BUG-019 FIX: TWeiboConfig 安全存储方法实现 }

function TWeiboConfig.ProtectKey(const APlainKey: string): string;
begin
  if APlainKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.ProtectString(APlainKey);
    ksmCredential:
      // Credential Manager 模式下不需要额外加密
      Result := APlainKey;
  else
    // ksmPlainText - 不推荐，但保持兼容性
    Result := APlainKey;
  end;
end;

function TWeiboConfig.UnprotectKey(const AEncryptedKey: string): string;
begin
  if AEncryptedKey = '' then
    Exit('');

  case FKeyStorageMode of
    ksmDPAPI:
      Result := TDPAPIHelper.UnprotectString(AEncryptedKey);
    ksmCredential:
      // Credential Manager 模式下数据已经安全存储
      Result := AEncryptedKey;
  else
    // ksmPlainText
    Result := AEncryptedKey;
  end;
end;

function TWeiboConfig.GetCredentialKey(const AKeyName: string): string;
var
  TargetName: string;
begin
  Result := '';
  if FKeyStorageMode <> ksmCredential then
    Exit;

  TargetName := FCredentialTarget + '.' + AKeyName;
  Result := TCredentialManager.GetCredential(TargetName, '');
end;

procedure TWeiboConfig.SetCredentialKey(const AKeyName, AValue: string);
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

procedure TWeiboConfig.LoadKeysFromCredentialManager;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  FAppId := GetCredentialKey('AppKey');
  FAppSecret := GetCredentialKey('AppSecret');
end;

procedure TWeiboConfig.SaveKeysToCredentialManager;
begin
  if FKeyStorageMode <> ksmCredential then
    Exit;

  SetCredentialKey('AppKey', FAppId);
  SetCredentialKey('AppSecret', FAppSecret);
end;

{ TWeiboClient }

constructor TWeiboClient.Create(AConfig: TWeiboConfig);
begin
  inherited Create(AConfig);
end;

function TWeiboClient.GetWeiboConfig: TWeiboConfig;
begin
  Result := TWeiboConfig(FConfig);
end;

function TWeiboClient.GetAuthUrl(const AState: string): string;
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

    Result := WEIBO_AUTH_URL + '?' + TSocialHelper.BuildQueryString(Params);
  finally
    FreeAndNil(Params);
  end;
end;

function TWeiboClient.ExchangeCode(const ACode: string): TSocialToken;
var
  Params: TDictionary<string, string>;
  PostData, Response: string;
  JsonObj: TJSONObject;
  ErrCode: string;
  ErrMsg: string;
begin
  Result.Clear;

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('grant_type', 'authorization_code');
    Params.Add('code', ACode);
    Params.Add('redirect_uri', FConfig.RedirectUri);
    AddPKCETokenParams(Params);

    PostData := TSocialHelper.BuildQueryString(Params);
    Response := DoPost(WEIBO_TOKEN_URL, PostData);

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
      raise ESocialNetworkError.Create('Invalid token response', 'INVALID_JSON', spWeibo);

    try
      // Check for error (Weibo uses "error" field)
      if JsonObj.TryGetValue<string>('error', ErrCode) and (ErrCode <> '') then
      begin
        JsonObj.TryGetValue<string>('error_description', ErrMsg);
        raise ESocialAuthError.Create(ErrMsg, ErrCode, spWeibo);
      end;

      // Weibo also uses "error_code" for some error responses
      if JsonObj.TryGetValue<string>('error_code', ErrCode) and (ErrCode <> '') then
      begin
        JsonObj.TryGetValue<string>('error_description', ErrMsg);
        raise ESocialAuthError.Create(ErrMsg, ErrCode, spWeibo);
      end;

      JsonObj.TryGetValue<string>('access_token', Result.AccessToken);
      JsonObj.TryGetValue<Integer>('expires_in', Result.ExpiresIn);
      JsonObj.TryGetValue<string>('uid', Result.OpenId);

      if Result.ExpiresIn > 0 then
        Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

      if Result.AccessToken = '' then
        raise ESocialAuthError.Create('No access token in response', 'NO_TOKEN', spWeibo);
    finally
      JsonObj.Free;
    end;
  finally
    FreeAndNil(Params);
  end;
end;

function TWeiboClient.RefreshToken(const ARefreshToken: string): TSocialToken;
var
  Params: TDictionary<string, string>;
  PostData, Response: string;
  JsonObj: TJSONObject;
  ErrCode, ErrMsg: string;
begin
  Result.Clear;

  if ARefreshToken = '' then
    raise ESocialAuthError.Create('Refresh token is empty', 'NO_REFRESH_TOKEN', spWeibo);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('grant_type', 'refresh_token');
    Params.Add('refresh_token', ARefreshToken);

    PostData := TSocialHelper.BuildQueryString(Params);
    Response := DoPost(WEIBO_TOKEN_URL, PostData);

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
      raise ESocialNetworkError.Create('Invalid token response', 'INVALID_JSON', spWeibo);

    try
      if JsonObj.TryGetValue<string>('error', ErrCode) and (ErrCode <> '') then
      begin
        JsonObj.TryGetValue<string>('error_description', ErrMsg);
        raise ESocialAuthError.Create(ErrMsg, ErrCode, spWeibo);
      end;

      JsonObj.TryGetValue<string>('access_token', Result.AccessToken);
      JsonObj.TryGetValue<Integer>('expires_in', Result.ExpiresIn);
      JsonObj.TryGetValue<string>('uid', Result.OpenId);

      if Result.ExpiresIn > 0 then
        Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

      // Keep original refresh token if not returned
      if Result.RefreshToken = '' then
        Result.RefreshToken := ARefreshToken;
    finally
      JsonObj.Free;
    end;
  finally
    FreeAndNil(Params);
  end;
end;

function TWeiboClient.ParseWeiboGender(const AValue: string): TSocialGender;
var
  Lower: string;
begin
  Lower := LowerCase(AValue);
  if (Lower = 'm') or (Lower = 'male') then
    Result := sgMale
  else if (Lower = 'f') or (Lower = 'female') then
    Result := sgFemale
  else
    Result := sgUnknown;
end;

function TWeiboClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  GenderStr, Location: string;
  ErrCode: Integer;
  ErrMsg: string;
begin
  Result.Clear;
  Result.Provider := spWeibo;

  // Weibo requires access_token and uid as query parameters
  Url := Format('%s?access_token=%s&uid=%s',
    [WEIBO_USER_URL, AToken.AccessToken, AToken.OpenId]);

  try
    Response := DoGet(Url);
    Result.RawJson := Response;

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
    begin
      Result := TSocialUserInfo.Fail('INVALID_JSON', 'Invalid user info response');
      Exit;
    end;

    try
      // Check for error
      if JsonObj.TryGetValue<Integer>('error_code', ErrCode) and (ErrCode <> 0) then
      begin
        JsonObj.TryGetValue<string>('error_description', ErrMsg);
        Result := TSocialUserInfo.Fail(IntToStr(ErrCode), ErrMsg);
        Exit;
      end;

      // Map Weibo fields to TSocialUserInfo
      // Note: Weibo 'description' (bio) has no dedicated field in TSocialUserInfo;
      //       it is preserved in RawJson for consumers who need it.
      JsonObj.TryGetValue<string>('id', Result.OpenId);
      JsonObj.TryGetValue<string>('screen_name', Result.Nickname);
      JsonObj.TryGetValue<string>('avatar_hd', Result.Avatar);

      // Gender: m=Male, f=Female
      if JsonObj.TryGetValue<string>('gender', GenderStr) then
        Result.Gender := ParseWeiboGender(GenderStr);

      // Location format: "Province City" - split into province and city
      if JsonObj.TryGetValue<string>('location', Location) and (Location <> '') then
      begin
        if Pos(' ', Location) > 0 then
        begin
          Result.Province := Copy(Location, 1, Pos(' ', Location) - 1);
          Result.City := Copy(Location, Pos(' ', Location) + 1, MaxInt);
        end
        else
          Result.Province := Location;
      end;

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
