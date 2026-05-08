unit DeepBase.Social;

{*******************************************************************************
  DeepBase Social Integration

  Unified interface for social platforms:
    - OAuth 2.0 Login
    - User Info Retrieval
    - Social Sharing

  Supported Platforms:
    - WeChat (微信)
    - Weibo (微博)
    - QQ
    - GitHub
    - Google
    - Twitter/X
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient, System.JSON,
  System.DateUtils, System.NetEncoding;

type
  /// <summary>Social platform type</summary>
  TSocialProvider = (
    spWeChat,     // 微信
    spWeibo,      // 微博
    spQQ,         // QQ
    spGitHub,     // GitHub
    spGoogle,     // Google
    spTwitter,    // Twitter/X
    spFacebook,   // Facebook
    spMicrosoft,  // Microsoft
    spApple       // Apple
  );

  /// <summary>Share target for platforms that support multiple targets</summary>
  TSocialShareTarget = (
    stDefault,    // Platform default
    stSession,    // WeChat: 好友
    stTimeline,   // WeChat: 朋友�?
    stFavorite    // WeChat: 收藏
  );

  /// <summary>Share content type</summary>
  TSocialShareType = (
    sstText,      // Text only
    sstImage,     // Image
    sstLink,      // Web link
    sstVideo,     // Video
    sstMusic,     // Music
    sstMiniApp    // Mini program (WeChat)
  );

  /// <summary>Gender enumeration</summary>
  TSocialGender = (sgUnknown, sgMale, sgFemale);

  ESocialError = class(Exception)
  public
    ErrorCode: string;
    Provider: TSocialProvider;
    constructor Create(const AMessage: string; const AErrorCode: string = '';
      AProvider: TSocialProvider = spWeChat); reintroduce;
  end;

  ESocialAuthError = class(ESocialError);
  ESocialNetworkError = class(ESocialError);
  ESocialConfigError = class(ESocialError);

  /// <summary>OAuth token response</summary>
  TSocialToken = record
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: Integer;       // Seconds until expiration
    ExpiresAt: TDateTime;     // Calculated expiration time
    TokenType: string;
    Scope: string;
    OpenId: string;           // WeChat/QQ specific
    UnionId: string;          // WeChat specific

    procedure Clear;
    function IsExpired: Boolean;
  end;

  /// <summary>User information from social platform</summary>
  TSocialUserInfo = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;

    Provider: TSocialProvider;
    OpenId: string;           // Platform-specific user ID
    UnionId: string;          // Cross-app user ID (WeChat)
    Nickname: string;
    Avatar: string;           // Avatar URL
    Email: string;
    Phone: string;
    Gender: TSocialGender;
    Country: string;
    Province: string;
    City: string;
    Language: string;

    RawJson: string;          // Original JSON response

    procedure Clear;
    class function Fail(const AErrorCode, AErrorMessage: string): TSocialUserInfo; static;
  end;

  /// <summary>Share content</summary>
  TSocialShare = record
    ShareType: TSocialShareType;
    Title: string;
    Description: string;
    Url: string;              // Link URL
    ImageUrl: string;         // Image URL or thumbnail
    ImageData: TBytes;        // Image binary data
    VideoUrl: string;
    MusicUrl: string;
    MiniAppId: string;        // WeChat mini program
    MiniAppPath: string;

    procedure Clear;
  end;

  /// <summary>Share result</summary>
  TSocialShareResult = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;
    ShareId: string;          // Platform share ID if available

    procedure Clear;
    class function Fail(const AErrorCode, AErrorMessage: string): TSocialShareResult; static;
  end;

  /// <summary>Base social configuration</summary>
  TSocialConfig = class
  protected
    FProvider: TSocialProvider;
    FAppId: string;
    FAppSecret: string;
    FRedirectUri: string;
    FScope: string;
    FTimeout: Integer;
    FEnablePKCE: Boolean;
  public
    constructor Create(AProvider: TSocialProvider); virtual;

    property Provider: TSocialProvider read FProvider;
    property AppId: string read FAppId write FAppId;
    property AppSecret: string read FAppSecret write FAppSecret;
    property RedirectUri: string read FRedirectUri write FRedirectUri;
    property Scope: string read FScope write FScope;
    property Timeout: Integer read FTimeout write FTimeout;
    property EnablePKCE: Boolean read FEnablePKCE write FEnablePKCE;
  end;

  /// <summary>Unified social client interface</summary>
  ISocialClient = interface
    ['{B1C2D3E4-F5A6-7890-BCDE-F12345678901}']
    function GetProvider: TSocialProvider;

    // OAuth flow
    function GetAuthUrl(const AState: string = ''): string;
    function ExchangeCode(const ACode: string): TSocialToken;
    function RefreshToken(const ARefreshToken: string): TSocialToken;

    // User info
    function GetUserInfo(const ACode: string): TSocialUserInfo; overload;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; overload;

    // Sharing (not all platforms support)
    function Share(const AContent: TSocialShare;
      ATarget: TSocialShareTarget = stDefault): TSocialShareResult;
    function CanShare: Boolean;

    property Provider: TSocialProvider read GetProvider;
  end;

  /// <summary>Base social client implementation</summary>
  TSocialClient = class(TInterfacedObject, ISocialClient)
  protected
    FConfig: TSocialConfig;
    FHttpClient: THTTPClient;
    FLastState: string;
    FLastCodeVerifier: string;

    function DoGet(const AUrl: string): string; virtual;
    function DoPost(const AUrl: string; const AData: string;
      const AContentType: string = 'application/x-www-form-urlencoded'): string; virtual;
    function DoPostJson(const AUrl: string; AJson: TJSONObject): string; virtual;
    function GenerateState: string; virtual;
    function PrepareOAuthState(const AState: string = ''): string; virtual;
    procedure AddPKCEAuthParams(AParams: TDictionary<string, string>); virtual;
    procedure AddPKCETokenParams(AParams: TDictionary<string, string>); virtual;
    procedure RequireValidState(const AState: string); virtual;
  public
    constructor Create(AConfig: TSocialConfig); virtual;
    destructor Destroy; override;

    // ISocialClient
    function GetProvider: TSocialProvider;
    function GetAuthUrl(const AState: string = ''): string; virtual; abstract;
    function ExchangeCode(const ACode: string): TSocialToken; overload; virtual; abstract;
    function ExchangeCode(const ACode, AState: string): TSocialToken; overload; virtual;
    function RefreshToken(const ARefreshToken: string): TSocialToken; virtual; abstract;
    function GetUserInfo(const ACode: string): TSocialUserInfo; overload; virtual;
    function GetUserInfo(const AToken: TSocialToken): TSocialUserInfo; overload; virtual; abstract;
    function Share(const AContent: TSocialShare;
      ATarget: TSocialShareTarget = stDefault): TSocialShareResult; virtual;
    function CanShare: Boolean; virtual;
    function ValidateState(const AState: string): Boolean; virtual;

    property Config: TSocialConfig read FConfig;
    property LastState: string read FLastState;
    property LastCodeVerifier: string read FLastCodeVerifier;
  end;

  /// <summary>Helper functions</summary>
  TSocialHelper = class
  public
    class function ProviderToString(AProvider: TSocialProvider): string;
    class function StringToProvider(const AStr: string): TSocialProvider;
    class function GenderToString(AGender: TSocialGender): string;
    class function IntToGender(AValue: Integer): TSocialGender;
    class function GenerateState(ALength: Integer = 16): string;
    class function GenerateCodeVerifier(ALength: Integer = 64): string;
    class function GenerateCodeChallengeS256(const AVerifier: string): string;
    class function ConstantTimeEquals(const A, B: string): Boolean;
    class function BuildQueryString(const AParams: TDictionary<string, string>): string;
    class function ParseQueryString(const AQueryStr: string): TDictionary<string, string>;
    class function UrlEncode(const AValue: string): string;
    class function UrlDecode(const AValue: string): string;
  end;

implementation

uses
  System.Hash,
  DeepBase.Random,
  DeepBase.Security;

const
  STATE_CHARSET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  PKCE_CHARSET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

function Base64UrlEncodeBytes(const ABytes: TBytes): string;
begin
  Result := TNetEncoding.Base64.EncodeBytesToString(ABytes);
  Result := Result.Replace(#13, '', [rfReplaceAll]);
  Result := Result.Replace(#10, '', [rfReplaceAll]);
  Result := Result.Replace('+', '-').Replace('/', '_').TrimRight(['=']);
end;

{ ESocialError }

constructor ESocialError.Create(const AMessage: string; const AErrorCode: string;
  AProvider: TSocialProvider);
begin
  inherited Create(AMessage);
  ErrorCode := AErrorCode;
  Provider := AProvider;
end;

{ TSocialToken }

procedure TSocialToken.Clear;
begin
  if AccessToken <> '' then
    DeepBase.Security.SecureZeroMemory(AccessToken);
  if RefreshToken <> '' then
    DeepBase.Security.SecureZeroMemory(RefreshToken);
  if TokenType <> '' then
    DeepBase.Security.SecureZeroMemory(TokenType);
  if Scope <> '' then
    DeepBase.Security.SecureZeroMemory(Scope);
  if OpenId <> '' then
    DeepBase.Security.SecureZeroMemory(OpenId);
  if UnionId <> '' then
    DeepBase.Security.SecureZeroMemory(UnionId);

  AccessToken := '';
  RefreshToken := '';
  ExpiresIn := 0;
  ExpiresAt := 0;
  TokenType := '';
  Scope := '';
  OpenId := '';
  UnionId := '';
end;

function TSocialToken.IsExpired: Boolean;
begin
  if ExpiresAt = 0 then
    Result := False  // No expiration info
  else
    Result := Now > ExpiresAt;
end;

{ TSocialUserInfo }

procedure TSocialUserInfo.Clear;
begin
  Success := False;
  ErrorCode := '';
  ErrorMessage := '';
  Provider := spWeChat;
  OpenId := '';
  UnionId := '';
  Nickname := '';
  Avatar := '';
  Email := '';
  Phone := '';
  Gender := sgUnknown;
  Country := '';
  Province := '';
  City := '';
  Language := '';
  RawJson := '';
end;

class function TSocialUserInfo.Fail(const AErrorCode, AErrorMessage: string): TSocialUserInfo;
begin
  Result.Clear;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
end;

{ TSocialShare }

procedure TSocialShare.Clear;
begin
  ShareType := sstLink;
  Title := '';
  Description := '';
  Url := '';
  ImageUrl := '';
  SetLength(ImageData, 0);
  VideoUrl := '';
  MusicUrl := '';
  MiniAppId := '';
  MiniAppPath := '';
end;

{ TSocialShareResult }

procedure TSocialShareResult.Clear;
begin
  Success := False;
  ErrorCode := '';
  ErrorMessage := '';
  ShareId := '';
end;

class function TSocialShareResult.Fail(const AErrorCode, AErrorMessage: string): TSocialShareResult;
begin
  Result.Clear;
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
end;

{ TSocialConfig }

constructor TSocialConfig.Create(AProvider: TSocialProvider);
begin
  inherited Create;
  FProvider := AProvider;
  FTimeout := 30000;
  FEnablePKCE := True;
end;

{ TSocialClient }

constructor TSocialClient.Create(AConfig: TSocialConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FConfig.Timeout;
  FHttpClient.ResponseTimeout := FConfig.Timeout;
end;

destructor TSocialClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TSocialClient.GetProvider: TSocialProvider;
begin
  Result := FConfig.Provider;
end;

function TSocialClient.DoGet(const AUrl: string): string;
var
  Response: IHTTPResponse;
begin
  Response := FHttpClient.Get(AUrl);
  Result := Response.ContentAsString(TEncoding.UTF8);

  if Response.StatusCode >= 400 then
    raise ESocialNetworkError.Create(
      Format('HTTP Error %d: %s', [Response.StatusCode, Result]),
      IntToStr(Response.StatusCode), FConfig.Provider);
end;

function TSocialClient.DoPost(const AUrl: string; const AData: string;
  const AContentType: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  Content := TStringStream.Create(AData, TEncoding.UTF8);
  try
    FHttpClient.CustomHeaders['Content-Type'] := AContentType;
    Response := FHttpClient.Post(AUrl, Content);
    Result := Response.ContentAsString(TEncoding.UTF8);

    if Response.StatusCode >= 400 then
      raise ESocialNetworkError.Create(
        Format('HTTP Error %d: %s', [Response.StatusCode, Result]),
        IntToStr(Response.StatusCode), FConfig.Provider);
  finally
    Content.Free;
  end;
end;

function TSocialClient.DoPostJson(const AUrl: string; AJson: TJSONObject): string;
begin
  Result := DoPost(AUrl, AJson.ToString, 'application/json');
end;

function TSocialClient.GenerateState: string;
begin
  Result := TSocialHelper.GenerateState;
end;

function TSocialClient.PrepareOAuthState(const AState: string): string;
begin
  Result := AState;
  if Result = '' then
    Result := GenerateState;
  FLastState := Result;
end;

procedure TSocialClient.AddPKCEAuthParams(AParams: TDictionary<string, string>);
var
  Challenge: string;
begin
  if (AParams = nil) or (FConfig = nil) or not FConfig.EnablePKCE then
    Exit;

  FLastCodeVerifier := TSocialHelper.GenerateCodeVerifier;
  Challenge := TSocialHelper.GenerateCodeChallengeS256(FLastCodeVerifier);
  AParams.AddOrSetValue('code_challenge', Challenge);
  AParams.AddOrSetValue('code_challenge_method', 'S256');
end;

procedure TSocialClient.AddPKCETokenParams(AParams: TDictionary<string, string>);
begin
  if (AParams = nil) or (FConfig = nil) or not FConfig.EnablePKCE then
    Exit;
  if FLastCodeVerifier = '' then
    Exit;

  AParams.AddOrSetValue('code_verifier', FLastCodeVerifier);
end;

function TSocialClient.ValidateState(const AState: string): Boolean;
begin
  Result := (FLastState <> '') and TSocialHelper.ConstantTimeEquals(FLastState, AState);
end;

procedure TSocialClient.RequireValidState(const AState: string);
begin
  if not ValidateState(AState) then
    raise ESocialAuthError.Create('Invalid OAuth state', 'INVALID_STATE', FConfig.Provider);

  FLastState := '';
end;

function TSocialClient.ExchangeCode(const ACode, AState: string): TSocialToken;
begin
  RequireValidState(AState);
  Result := ExchangeCode(ACode);
end;

function TSocialClient.GetUserInfo(const ACode: string): TSocialUserInfo;
var
  Token: TSocialToken;
begin
  Token := ExchangeCode(ACode);
  try
    Result := GetUserInfo(Token);
  finally
    Token.Clear;
  end;
end;

function TSocialClient.Share(const AContent: TSocialShare;
  ATarget: TSocialShareTarget): TSocialShareResult;
begin
  Result := TSocialShareResult.Fail('NOT_SUPPORTED',
    'Sharing is not supported for this provider');
end;

function TSocialClient.CanShare: Boolean;
begin
  Result := False;
end;

{ TSocialHelper }

class function TSocialHelper.ProviderToString(AProvider: TSocialProvider): string;
begin
  case AProvider of
    spWeChat: Result := 'wechat';
    spWeibo: Result := 'weibo';
    spQQ: Result := 'qq';
    spGitHub: Result := 'github';
    spGoogle: Result := 'google';
    spTwitter: Result := 'twitter';
    spFacebook: Result := 'facebook';
    spMicrosoft: Result := 'microsoft';
    spApple: Result := 'apple';
  else
    Result := 'unknown';
  end;
end;

class function TSocialHelper.StringToProvider(const AStr: string): TSocialProvider;
var
  S: string;
begin
  S := LowerCase(AStr);
  if S = 'wechat' then Result := spWeChat
  else if S = 'weibo' then Result := spWeibo
  else if S = 'qq' then Result := spQQ
  else if S = 'github' then Result := spGitHub
  else if S = 'google' then Result := spGoogle
  else if S = 'twitter' then Result := spTwitter
  else if S = 'facebook' then Result := spFacebook
  else if S = 'microsoft' then Result := spMicrosoft
  else if S = 'apple' then Result := spApple
  else Result := spWeChat;
end;

class function TSocialHelper.GenderToString(AGender: TSocialGender): string;
begin
  case AGender of
    sgMale: Result := 'male';
    sgFemale: Result := 'female';
  else
    Result := 'unknown';
  end;
end;

class function TSocialHelper.IntToGender(AValue: Integer): TSocialGender;
begin
  case AValue of
    1: Result := sgMale;
    2: Result := sgFemale;
  else
    Result := sgUnknown;
  end;
end;

class function TSocialHelper.GenerateState(ALength: Integer): string;
begin
  Result := SecureRandom.NextString(ALength, STATE_CHARSET);
end;

class function TSocialHelper.GenerateCodeVerifier(ALength: Integer): string;
begin
  if (ALength < 43) or (ALength > 128) then
    raise EArgumentException.Create('PKCE code verifier length must be between 43 and 128');

  Result := SecureRandom.NextString(ALength, PKCE_CHARSET);
end;

class function TSocialHelper.GenerateCodeChallengeS256(const AVerifier: string): string;
var
  Hash: THashSHA2;
begin
  if AVerifier = '' then
    raise EArgumentException.Create('PKCE code verifier cannot be empty');

  Hash := THashSHA2.Create(THashSHA2.TSHA2Version.SHA256);
  Hash.Update(TEncoding.ASCII.GetBytes(AVerifier));
  Result := Base64UrlEncodeBytes(Hash.HashAsBytes);
end;

class function TSocialHelper.ConstantTimeEquals(const A, B: string): Boolean;
var
  I, MaxLen, Diff: Integer;
  AChar, BChar: Integer;
begin
  if Length(A) > Length(B) then
    MaxLen := Length(A)
  else
    MaxLen := Length(B);

  Diff := Length(A) xor Length(B);
  for I := 1 to MaxLen do
  begin
    if I <= Length(A) then
      AChar := Ord(A[I])
    else
      AChar := 0;

    if I <= Length(B) then
      BChar := Ord(B[I])
    else
      BChar := 0;

    Diff := Diff or (AChar xor BChar);
  end;

  Result := Diff = 0;
end;

class function TSocialHelper.BuildQueryString(
  const AParams: TDictionary<string, string>): string;
var
  Key: string;
  SB: TStringBuilder;
begin
  if (AParams = nil) or (AParams.Count = 0) then
    Exit('');

  SB := TStringBuilder.Create;
  try
    for Key in AParams.Keys do
    begin
      if AParams[Key] = '' then Continue;

      if SB.Length > 0 then
        SB.Append('&');
      SB.Append(UrlEncode(Key));
      SB.Append('=');
      SB.Append(UrlEncode(AParams[Key]));
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TSocialHelper.ParseQueryString(const AQueryStr: string): TDictionary<string, string>;
var
  Pairs: TArray<string>;
  Pair: string;
  EqPos: Integer;
begin
  Result := TDictionary<string, string>.Create;
  if AQueryStr = '' then Exit;

  Pairs := AQueryStr.Split(['&']);
  for Pair in Pairs do
  begin
    EqPos := Pos('=', Pair);
    if EqPos > 0 then
      Result.AddOrSetValue(
        UrlDecode(Copy(Pair, 1, EqPos - 1)),
        UrlDecode(Copy(Pair, EqPos + 1, MaxInt))
      );
  end;
end;

class function TSocialHelper.UrlEncode(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Encode(AValue);
end;

class function TSocialHelper.UrlDecode(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Decode(AValue);
end;

end.
