unit UniBase.Social.WeChat;

{*******************************************************************************
  UniBase WeChat (微信) Social Integration

  Supports:
    - 微信开放平台登录 (网站应用)
    - 微信公众号登录 (网页授权)
    - 获取用户信息
    - 分享到微信

  Official Docs: https://developers.weixin.qq.com/doc/oplatform/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Social;

type
  /// <summary>WeChat login type</summary>
  TWeChatLoginType = (
    wltOpen,      // 开放平台 (网站/APP)
    wltMP         // 公众号网页授权
  );

  /// <summary>WeChat configuration</summary>
  TWeChatConfig = class(TSocialConfig)
  private
    FLoginType: TWeChatLoginType;
  public
    constructor Create(ALoginType: TWeChatLoginType = wltOpen); reintroduce;

    property LoginType: TWeChatLoginType read FLoginType write FLoginType;
  end;

  /// <summary>WeChat OAuth client</summary>
  TWeChatClient = class(TSocialClient)
  private
    function GetWeChatConfig: TWeChatConfig;
    function GetAuthBaseUrl: string;
    function GetApiBaseUrl: string;
  public
    constructor Create(AConfig: TWeChatConfig); reintroduce;

    // ISocialClient
    function GetAuthUrl(const AState: string = ''): string; override;
    function ExchangeCode(const ACode: string): TSocialToken; overload; override;
    function RefreshToken(const ARefreshToken: string): TSocialToken; override;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; override;
    function Share(const AContent: TSocialShare;
      ATarget: TSocialShareTarget = stDefault): TSocialShareResult; override;
    function CanShare: Boolean; override;

    // WeChat specific
    function CheckAccessToken(const AAccessToken, AOpenId: string): Boolean;
    function GetJsApiTicket(const AAccessToken: string): string;
    function GetJsApiSignature(const ATicket, ANonceStr, AUrl: string;
      ATimestamp: Int64): string;

    property WeChatConfig: TWeChatConfig read GetWeChatConfig;
  end;

implementation

uses
  System.Hash;

const
  // WeChat Open Platform (开放平台)
  WECHAT_OPEN_AUTH_URL = 'https://open.weixin.qq.com/connect/qrconnect';
  WECHAT_OPEN_API_URL = 'https://api.weixin.qq.com/sns';

  // WeChat MP (公众号)
  WECHAT_MP_AUTH_URL = 'https://open.weixin.qq.com/connect/oauth2/authorize';
  WECHAT_MP_API_URL = 'https://api.weixin.qq.com/sns';

  // Common API
  WECHAT_CGI_URL = 'https://api.weixin.qq.com/cgi-bin';

{ TWeChatConfig }

constructor TWeChatConfig.Create(ALoginType: TWeChatLoginType);
begin
  inherited Create(spWeChat);
  FLoginType := ALoginType;

  case ALoginType of
    wltOpen: FScope := 'snsapi_login';
    wltMP: FScope := 'snsapi_userinfo';
  end;
end;

{ TWeChatClient }

constructor TWeChatClient.Create(AConfig: TWeChatConfig);
begin
  inherited Create(AConfig);
end;

function TWeChatClient.GetWeChatConfig: TWeChatConfig;
begin
  Result := TWeChatConfig(FConfig);
end;

function TWeChatClient.GetAuthBaseUrl: string;
begin
  case WeChatConfig.LoginType of
    wltOpen: Result := WECHAT_OPEN_AUTH_URL;
    wltMP: Result := WECHAT_MP_AUTH_URL;
  else
    Result := WECHAT_OPEN_AUTH_URL;
  end;
end;

function TWeChatClient.GetApiBaseUrl: string;
begin
  Result := WECHAT_OPEN_API_URL;
end;

function TWeChatClient.GetAuthUrl(const AState: string): string;
var
  Params: TDictionary<string, string>;
  State: string;
begin
  State := PrepareOAuthState(AState);

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('appid', FConfig.AppId);
    Params.Add('redirect_uri', FConfig.RedirectUri);
    Params.Add('response_type', 'code');
    Params.Add('scope', FConfig.Scope);
    Params.Add('state', State);
    AddPKCEAuthParams(Params);

    Result := GetAuthBaseUrl + '?' + TSocialHelper.BuildQueryString(Params);

    // WeChat requires #wechat_redirect suffix
    Result := Result + '#wechat_redirect';
  finally
    Params.Free;
  end;
end;

function TWeChatClient.ExchangeCode(const ACode: string): TSocialToken;
var
  Params: TDictionary<string, string>;
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode: Integer;
  ErrMsg: string;
begin
  Result.Clear;

  Params := TDictionary<string, string>.Create;
  try
    Params.Add('appid', FConfig.AppId);
    Params.Add('secret', FConfig.AppSecret);
    Params.Add('code', ACode);
    Params.Add('grant_type', 'authorization_code');
    AddPKCETokenParams(Params);

    Url := GetApiBaseUrl + '/oauth2/access_token?' +
      TSocialHelper.BuildQueryString(Params);
    Response := DoGet(Url);

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonObj) then
      raise ESocialNetworkError.Create('Invalid token response', 'INVALID_JSON', spWeChat);

    try
      // Check for error
      if JsonObj.TryGetValue<Integer>('errcode', ErrCode) and (ErrCode <> 0) then
      begin
        JsonObj.TryGetValue<string>('errmsg', ErrMsg);
        raise ESocialAuthError.Create(ErrMsg, IntToStr(ErrCode), spWeChat);
      end;

      JsonObj.TryGetValue<string>('access_token', Result.AccessToken);
      JsonObj.TryGetValue<string>('refresh_token', Result.RefreshToken);
      JsonObj.TryGetValue<Integer>('expires_in', Result.ExpiresIn);
      JsonObj.TryGetValue<string>('openid', Result.OpenId);
      JsonObj.TryGetValue<string>('unionid', Result.UnionId);
      JsonObj.TryGetValue<string>('scope', Result.Scope);

      if Result.ExpiresIn > 0 then
        Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

      if Result.AccessToken = '' then
        raise ESocialAuthError.Create('No access token in response', 'NO_TOKEN', spWeChat);
    finally
      JsonObj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function TWeChatClient.RefreshToken(const ARefreshToken: string): TSocialToken;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode: Integer;
  ErrMsg: string;
begin
  Result.Clear;

  if ARefreshToken = '' then
    raise ESocialAuthError.Create('Refresh token is empty', 'NO_REFRESH_TOKEN', spWeChat);

  Url := Format('%s/oauth2/refresh_token?appid=%s&grant_type=refresh_token&refresh_token=%s',
    [GetApiBaseUrl, FConfig.AppId, ARefreshToken]);

  Response := DoGet(Url);

  JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(JsonObj) then
    raise ESocialNetworkError.Create('Invalid token response', 'INVALID_JSON', spWeChat);

  try
    if JsonObj.TryGetValue<Integer>('errcode', ErrCode) and (ErrCode <> 0) then
    begin
      JsonObj.TryGetValue<string>('errmsg', ErrMsg);
      raise ESocialAuthError.Create(ErrMsg, IntToStr(ErrCode), spWeChat);
    end;

    JsonObj.TryGetValue<string>('access_token', Result.AccessToken);
    JsonObj.TryGetValue<string>('refresh_token', Result.RefreshToken);
    JsonObj.TryGetValue<Integer>('expires_in', Result.ExpiresIn);
    JsonObj.TryGetValue<string>('openid', Result.OpenId);
    JsonObj.TryGetValue<string>('scope', Result.Scope);

    if Result.ExpiresIn > 0 then
      Result.ExpiresAt := Now + Result.ExpiresIn / 86400;

    // Keep original refresh token if not returned
    if Result.RefreshToken = '' then
      Result.RefreshToken := ARefreshToken;
  finally
    JsonObj.Free;
  end;
end;

function TWeChatClient.GetUserInfo(const AToken: TSocialToken): TSocialUserInfo;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode, Sex: Integer;
  ErrMsg: string;
begin
  Result.Clear;
  Result.Provider := spWeChat;

  Url := Format('%s/userinfo?access_token=%s&openid=%s&lang=zh_CN',
    [GetApiBaseUrl, AToken.AccessToken, AToken.OpenId]);

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
      if JsonObj.TryGetValue<Integer>('errcode', ErrCode) and (ErrCode <> 0) then
      begin
        JsonObj.TryGetValue<string>('errmsg', ErrMsg);
        Result := TSocialUserInfo.Fail(IntToStr(ErrCode), ErrMsg);
        Exit;
      end;

      JsonObj.TryGetValue<string>('openid', Result.OpenId);
      JsonObj.TryGetValue<string>('unionid', Result.UnionId);
      JsonObj.TryGetValue<string>('nickname', Result.Nickname);
      JsonObj.TryGetValue<string>('headimgurl', Result.Avatar);
      JsonObj.TryGetValue<string>('country', Result.Country);
      JsonObj.TryGetValue<string>('province', Result.Province);
      JsonObj.TryGetValue<string>('city', Result.City);
      JsonObj.TryGetValue<string>('language', Result.Language);

      if JsonObj.TryGetValue<Integer>('sex', Sex) then
        Result.Gender := TSocialHelper.IntToGender(Sex);

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

function TWeChatClient.CheckAccessToken(const AAccessToken, AOpenId: string): Boolean;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode: Integer;
begin
  Result := False;

  Url := Format('%s/auth?access_token=%s&openid=%s',
    [GetApiBaseUrl, AAccessToken, AOpenId]);

  try
    Response := DoGet(Url);

    JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if Assigned(JsonObj) then
    try
      if JsonObj.TryGetValue<Integer>('errcode', ErrCode) then
        Result := (ErrCode = 0);
    finally
      JsonObj.Free;
    end;
  except
    Result := False;
  end;
end;

function TWeChatClient.Share(const AContent: TSocialShare;
  ATarget: TSocialShareTarget): TSocialShareResult;
begin
  // WeChat sharing requires native SDK integration
  // This is a placeholder for web-based sharing via JS-SDK
  Result := TSocialShareResult.Fail('NOT_IMPLEMENTED',
    'WeChat sharing requires native SDK or JS-SDK integration');
end;

function TWeChatClient.CanShare: Boolean;
begin
  Result := True;  // WeChat supports sharing
end;

function TWeChatClient.GetJsApiTicket(const AAccessToken: string): string;
var
  Url, Response: string;
  JsonObj: TJSONObject;
  ErrCode: Integer;
  ErrMsg: string;
begin
  Result := '';

  // This requires a separate access_token (not user's OAuth token)
  // Get via: https://api.weixin.qq.com/cgi-bin/token
  Url := Format('%s/ticket/getticket?access_token=%s&type=jsapi',
    [WECHAT_CGI_URL, AAccessToken]);

  Response := DoGet(Url);

  JsonObj := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(JsonObj) then
    raise ESocialNetworkError.Create('Invalid ticket response', 'INVALID_JSON', spWeChat);

  try
    if JsonObj.TryGetValue<Integer>('errcode', ErrCode) and (ErrCode <> 0) then
    begin
      JsonObj.TryGetValue<string>('errmsg', ErrMsg);
      raise ESocialAuthError.Create(ErrMsg, IntToStr(ErrCode), spWeChat);
    end;

    JsonObj.TryGetValue<string>('ticket', Result);
  finally
    JsonObj.Free;
  end;
end;

function TWeChatClient.GetJsApiSignature(const ATicket, ANonceStr, AUrl: string;
  ATimestamp: Int64): string;
var
  SignStr: string;
begin
  // JS-SDK signature calculation
  SignStr := Format('jsapi_ticket=%s&noncestr=%s&timestamp=%d&url=%s',
    [ATicket, ANonceStr, ATimestamp, AUrl]);

  Result := THashSHA1.GetHashString(SignStr).ToLower;
end;

end.
