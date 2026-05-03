unit UniBase.Social.OAuth;

{*******************************************************************************
  UniBase OAuth 2.0 Generic Client

  Supports standard OAuth 2.0 providers:
    - GitHub
    - Google
    - Facebook
    - Twitter (OAuth 2.0)
    - Generic OAuth 2.0

  Reference: https://oauth.net/2/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Social;

type
  /// <summary>OAuth 2.0 provider presets</summary>
  TOAuthProvider = (
    opCustom,     // Custom provider
    opGitHub,
    opGoogle,
    opFacebook,
    opTwitter,
    opMicrosoft,
    opLinkedIn
  );

  /// <summary>OAuth 2.0 configuration</summary>
  TOAuthConfig = class(TSocialConfig)
  private
    FOAuthProvider: TOAuthProvider;
    FAuthorizationEndpoint: string;
    FTokenEndpoint: string;
    FUserInfoEndpoint: string;
    FRevokeEndpoint: string;
  public
    constructor Create(AProvider: TOAuthProvider = opCustom); reintroduce;

    procedure SetupForGitHub;
    procedure SetupForGoogle;
    procedure SetupForFacebook;
    procedure SetupForTwitter;
    procedure SetupForMicrosoft;

    property OAuthProvider: TOAuthProvider read FOAuthProvider write FOAuthProvider;
    property AuthorizationEndpoint: string read FAuthorizationEndpoint write FAuthorizationEndpoint;
    property TokenEndpoint: string read FTokenEndpoint write FTokenEndpoint;
    property UserInfoEndpoint: string read FUserInfoEndpoint write FUserInfoEndpoint;
    property RevokeEndpoint: string read FRevokeEndpoint write FRevokeEndpoint;
  end;

  /// <summary>Generic OAuth 2.0 client</summary>
  TOAuthClient = class(TSocialClient)
  private
    function GetOAuthConfig: TOAuthConfig;
    function ParseTokenResponse(const AJson: string): TSocialToken;
  public
    constructor Create(AConfig: TOAuthConfig); reintroduce;

    // ISocialClient
    function GetAuthUrl(const AState: string = ''): string; override;
    function ExchangeCode(const ACode: string): TSocialToken; overload; override;
    function RefreshToken(const ARefreshToken: string): TSocialToken; override;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;

    // Additional
    function RevokeToken(const AToken: string): Boolean;

    property OAuthConfig: TOAuthConfig read GetOAuthConfig;
  end;

  /// <summary>GitHub specific client</summary>
  TGitHubClient = class(TOAuthClient)
  public
    constructor Create(const AClientId, AClientSecret, ARedirectUri: string);
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;
    function GetUserEmails(const AAccessToken: string): TArray<string>;
  end;

  /// <summary>Google specific client</summary>
  TGoogleClient = class(TOAuthClient)
  public
    constructor Create(const AClientId, AClientSecret, ARedirectUri: string);
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;
  end;

implementation

const
  // GitHub OAuth endpoints
  GITHUB_AUTH_URL = 'https://github.com/login/oauth/authorize';
  GITHUB_TOKEN_URL = 'https://github.com/login/oauth/access_token';
  GITHUB_USER_URL = 'https://api.github.com/user';
  GITHUB_EMAILS_URL = 'https://api.github.com/user/emails';

  // Google OAuth endpoints
  GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
  GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
  GOOGLE_USER_URL = 'https://www.googleapis.com/oauth2/v3/userinfo';
  GOOGLE_REVOKE_URL = 'https://oauth2.googleapis.com/revoke';

  // Facebook OAuth endpoints
  FACEBOOK_AUTH_URL = 'https://www.facebook.com/v18.0/dialog/oauth';
  FACEBOOK_TOKEN_URL = 'https://graph.facebook.com/v18.0/oauth/access_token';
  FACEBOOK_USER_URL = 'https://graph.facebook.com/me';

  // Microsoft OAuth endpoints
  MICROSOFT_AUTH_URL = 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  MICROSOFT_TOKEN_URL = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  MICROSOFT_USER_URL = 'https://graph.microsoft.com/v1.0/me';

{ TOAuthConfig }

constructor TOAuthConfig.Create(AProvider: TOAuthProvider);
begin
  inherited Create(spGitHub);
  FOAuthProvider := AProvider;

  case AProvider of
    opGitHub: SetupForGitHub;
    opGoogle: SetupForGoogle;
    opFacebook: SetupForFacebook;
    opMicrosoft: SetupForMicrosoft;
  end;
end;

procedure TOAuthConfig.SetupForGitHub;
begin
  FProvider := spGitHub;
  FAuthorizationEndpoint := GITHUB_AUTH_URL;
  FTokenEndpoint := GITHUB_TOKEN_URL;
  FUserInfoEndpoint := GITHUB_USER_URL;
  FScope := 'user:email';
end;

procedure TOAuthConfig.SetupForGoogle;
begin
  FProvider := spGoogle;
  FAuthorizationEndpoint := GOOGLE_AUTH_URL;
  FTokenEndpoint := GOOGLE_TOKEN_URL;
  FUserInfoEndpoint := GOOGLE_USER_URL;
  FRevokeEndpoint := GOOGLE_REVOKE_URL;
  FScope := 'openid email profile';
end;

procedure TOAuthConfig.SetupForFacebook;
begin
  FProvider := spFacebook;
  FAuthorizationEndpoint := FACEBOOK_AUTH_URL;
  FTokenEndpoint := FACEBOOK_TOKEN_URL;
  FUserInfoEndpoint := FACEBOOK_USER_URL;
  FScope := 'email,public_profile';
end;

procedure TOAuthConfig.SetupForTwitter;
begin
  FProvider := spTwitter;
  // Twitter uses OAuth 2.0 with PKCE
  FAuthorizationEndpoint := 'https://twitter.com/i/oauth2/authorize';
  FTokenEndpoint := 'https://api.twitter.com/2/oauth2/token';
  FUserInfoEndpoint := 'https://api.twitter.com/2/users/me';
  FScope := 'tweet.read users.read';
end;

procedure TOAuthConfig.SetupForMicrosoft;
begin
  FProvider := spMicrosoft;
  FAuthorizationEndpoint := MICROSOFT_AUTH_URL;
  FTokenEndpoint := MICROSOFT_TOKEN_URL;
  FUserInfoEndpoint := MICROSOFT_USER_URL;
  FScope := 'openid email profile User.Read';
end;

{ TOAuthClient }

constructor TOAuthClient.Create(AConfig: TOAuthConfig);
begin
  inherited Create(AConfig);
end;

function TOAuthClient.GetOAuthConfig: TOAuthConfig;
begin
  Result := TOAuthConfig(FConfig);
end;

function TOAuthClient.GetAuthUrl(const AState: string): string;
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

    // Google specific: access_type for refresh token
    if OAuthConfig.OAuthProvider = opGoogle then
      Params.Add('access_type', 'offline');

    Result := OAuthConfig.AuthorizationEndpoint + '?' +
      TSocialHelper.BuildQueryString(Params);
  finally
    Params.Free;
  end;
end;

function TOAuthClient.ExchangeCode(const ACode: string): TSocialToken;
var
  Params: TDictionary<string, string>;
  PostData, Response: string;
begin
  Result.Clear;

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('code', ACode);
    Params.Add('redirect_uri', FConfig.RedirectUri);
    Params.Add('grant_type', 'authorization_code');
    AddPKCETokenParams(Params);

    PostData := TSocialHelper.BuildQueryString(Params);

    // GitHub needs Accept header for JSON response
    if OAuthConfig.OAuthProvider = opGitHub then
      FHttpClient.CustomHeaders['Accept'] := 'application/json';

    Response := DoPost(OAuthConfig.TokenEndpoint, PostData);
    Result := ParseTokenResponse(Response);
  finally
    Params.Free;
  end;
end;

function TOAuthClient.RefreshToken(const ARefreshToken: string): TSocialToken;
var
  Params: TDictionary<string, string>;
  PostData, Response: string;
begin
  Result.Clear;

  if ARefreshToken = '' then
    raise ESocialAuthError.Create('Refresh token is empty', 'NO_REFRESH_TOKEN', FConfig.Provider);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', FConfig.AppId);
    Params.Add('client_secret', FConfig.AppSecret);
    Params.Add('refresh_token', ARefreshToken);
    Params.Add('grant_type', 'refresh_token');

    PostData := TSocialHelper.BuildQueryString(Params);
    Response := DoPost(OAuthConfig.TokenEndpoint, PostData);
    Result := ParseTokenResponse(Response);

    // Keep original refresh token if not returned
    if Result.RefreshToken = '' then
      Result.RefreshToken := ARefreshToken;
  finally
    Params.Free;
  end;
end;

function TOAuthClient.ParseTokenResponse(const AJson: string): TSocialToken;
var
  JsonObj: TJSONObject;
  ErrCode, ErrMsg: string;
begin
  Result.Clear;

  JsonObj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(JsonObj) then
    raise ESocialNetworkError.Create('Invalid token response', 'INVALID_JSON', FConfig.Provider);

  try
    // Check for error
    if JsonObj.TryGetValue<string>('error', ErrCode) then
    begin
      JsonObj.TryGetValue<string>('error_description', ErrMsg);
      raise ESocialAuthError.Create(ErrMsg, ErrCode, FConfig.Provider);
    end;

    JsonObj.TryGetValue<string>('access_token', Result.AccessToken);
    JsonObj.TryGetValue<string>('refresh_token', Result.RefreshToken);
    JsonObj.TryGetValue<Integer>('expires_in', Result.ExpiresIn);
    JsonObj.TryGetValue<string>('token_type', Result.TokenType);
    JsonObj.TryGetValue<string>('scope', Result.Scope);

    if Result.ExpiresIn > 0 then
      Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

    if Result.AccessToken = '' then
      raise ESocialAuthError.Create('No access token in response', 'NO_TOKEN', FConfig.Provider);
  finally
    JsonObj.Free;
  end;
end;

function TOAuthClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Response: string;
  JsonObj: TJSONObject;
begin
  Result.Clear;
  Result.Provider := FConfig.Provider;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AToken.AccessToken;

  try
    Response := DoGet(OAuthConfig.UserInfoEndpoint);
    Result.RawJson := Response;

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
    begin
      Result := TSocialUserInfo.Fail('INVALID_JSON', 'Invalid user info response');
      Exit;
    end;

    try
      // Generic mapping - subclasses override for specific providers
      JsonObj.TryGetValue<string>('id', Result.OpenId);
      JsonObj.TryGetValue<string>('name', Result.Nickname);
      JsonObj.TryGetValue<string>('email', Result.Email);
      JsonObj.TryGetValue<string>('picture', Result.Avatar);

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

function TOAuthClient.RevokeToken(const AToken: string): Boolean;
var
  PostData: string;
begin
  Result := False;
  if OAuthConfig.RevokeEndpoint = '' then
    Exit;

  try
    PostData := 'token=' + TSocialHelper.UrlEncode(AToken);
    DoPost(OAuthConfig.RevokeEndpoint, PostData);
    Result := True;
  except
    Result := False;
  end;
end;

{ TGitHubClient }

constructor TGitHubClient.Create(const AClientId, AClientSecret, ARedirectUri: string);
var
  Config: TOAuthConfig;
begin
  Config := TOAuthConfig.Create(opGitHub);
  Config.AppId := AClientId;
  Config.AppSecret := AClientSecret;
  Config.RedirectUri := ARedirectUri;
  inherited Create(Config);
end;

function TGitHubClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Response: string;
  JsonObj: TJSONObject;
  Emails: TArray<string>;
begin
  Result.Clear;
  Result.Provider := spGitHub;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AToken.AccessToken;
  FHttpClient.CustomHeaders['Accept'] := 'application/vnd.github+json';
  FHttpClient.CustomHeaders['X-GitHub-Api-Version'] := '2022-11-28';

  try
    Response := DoGet(GITHUB_USER_URL);
    Result.RawJson := Response;

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
    begin
      Result := TSocialUserInfo.Fail('INVALID_JSON', 'Invalid user info response');
      Exit;
    end;

    try
      Result.OpenId := JsonObj.GetValue<Integer>('id', 0).ToString;
      JsonObj.TryGetValue<string>('login', Result.Nickname);
      JsonObj.TryGetValue<string>('avatar_url', Result.Avatar);
      JsonObj.TryGetValue<string>('email', Result.Email);

      // If email is not public, fetch from emails API
      if Result.Email = '' then
      begin
        Emails := GetUserEmails(AToken.AccessToken);
        if Length(Emails) > 0 then
          Result.Email := Emails[0];
      end;

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

function TGitHubClient.GetUserEmails(const AAccessToken: string): TArray<string>;
var
  Response: string;
  JsonArr: TJSONArray;
  I: Integer;
  Email: TJSONObject;
  EmailStr: string;
  IsPrimary: Boolean;
begin
  SetLength(Result, 0);

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AAccessToken;
  FHttpClient.CustomHeaders['Accept'] := 'application/vnd.github+json';

  try
    Response := DoGet(GITHUB_EMAILS_URL);

    JsonArr := TJSONObject.ParseJSONValue(Response) as TJSONArray;
    if not Assigned(JsonArr) then Exit;

    try
      SetLength(Result, JsonArr.Count);
      for I := 0 to JsonArr.Count - 1 do
      begin
        Email := JsonArr.Items[I] as TJSONObject;
        Email.TryGetValue<string>('email', EmailStr);
        Email.TryGetValue<Boolean>('primary', IsPrimary);

        if IsPrimary then
        begin
          // Put primary email first
          Result[0] := EmailStr;
        end
        else
          Result[I] := EmailStr;
      end;
    finally
      JsonArr.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

{ TGoogleClient }

constructor TGoogleClient.Create(const AClientId, AClientSecret, ARedirectUri: string);
var
  Config: TOAuthConfig;
begin
  Config := TOAuthConfig.Create(opGoogle);
  Config.AppId := AClientId;
  Config.AppSecret := AClientSecret;
  Config.RedirectUri := ARedirectUri;
  inherited Create(Config);
end;

function TGoogleClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Response: string;
  JsonObj: TJSONObject;
begin
  Result.Clear;
  Result.Provider := spGoogle;

  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AToken.AccessToken;

  try
    Response := DoGet(GOOGLE_USER_URL);
    Result.RawJson := Response;

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
    begin
      Result := TSocialUserInfo.Fail('INVALID_JSON', 'Invalid user info response');
      Exit;
    end;

    try
      JsonObj.TryGetValue<string>('sub', Result.OpenId);
      JsonObj.TryGetValue<string>('name', Result.Nickname);
      JsonObj.TryGetValue<string>('picture', Result.Avatar);
      JsonObj.TryGetValue<string>('email', Result.Email);
      JsonObj.TryGetValue<string>('locale', Result.Language);

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
