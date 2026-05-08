unit Test.DeepBase.Social;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Social;

type
  /// <summary>
  /// Tests for TSocialToken record.
  /// </summary>
  [TestFixture]
  TSocialTokenTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_IsExpired_ReturnsFalseWhenNoExpiration;

    [Test]
    procedure Test_IsExpired_ReturnsTrueWhenPastExpiration;

    [Test]
    procedure Test_IsExpired_ReturnsFalseWhenNotExpired;
  end;

  /// <summary>
  /// Tests for TSocialUserInfo record.
  /// </summary>
  [TestFixture]
  TSocialUserInfoTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_Fail_SetsErrorFields;
  end;

  /// <summary>
  /// Tests for TSocialShare record.
  /// </summary>
  [TestFixture]
  TSocialShareTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;
  end;

  /// <summary>
  /// Tests for TSocialShareResult record.
  /// </summary>
  [TestFixture]
  TSocialShareResultTests = class
  public
    [Test]
    procedure Test_Clear_Sets_Defaults;

    [Test]
    procedure Test_Fail_SetsErrorFields;
  end;

  /// <summary>
  /// Tests for TSocialConfig class.
  /// </summary>
  [TestFixture]
  TSocialConfigTests = class
  public
    [Test]
    procedure Test_Create_SetsProvider;

    [Test]
    procedure Test_Create_SetsDefaultTimeout;

    [Test]
    procedure Test_Properties_ReadWrite;
  end;

  /// <summary>
  /// Tests for TSocialHelper.
  /// </summary>
  [TestFixture]
  TSocialHelperTests = class
  public
    [Test]
    procedure Test_ProviderToString_AllValues;

    [Test]
    procedure Test_StringToProvider_AllValues;

    [Test]
    procedure Test_StringToProvider_CaseInsensitive;

    [Test]
    procedure Test_GenderToString_AllValues;

    [Test]
    procedure Test_IntToGender_AllValues;

    [Test]
    procedure Test_GenerateState_CorrectLength;

    [Test]
    procedure Test_GenerateState_Unique;

    [Test]
    procedure Test_GenerateCodeVerifier_UsesPKCECharset;

    [Test]
    procedure Test_GenerateCodeChallengeS256_RFC7636Vector;

    [Test]
    procedure Test_UrlEncode_SpecialChars;

    [Test]
    procedure Test_UrlDecode_EncodedChars;

    [Test]
    procedure Test_BuildQueryString;

    [Test]
    procedure Test_ParseQueryString;
  end;

  /// <summary>
  /// Tests for OAuth2 state validation and PKCE support.
  /// </summary>
  [TestFixture]
  TOAuthClientPKCETests = class
  public
    [Test]
    procedure Test_GetAuthUrl_StoresStateAndAddsPKCE;

    [Test]
    procedure Test_ValidateState_ReturnsExpectedResult;

    [Test]
    procedure Test_ExchangeCode_WithInvalidState_RaisesBeforeNetwork;

    [Test]
    procedure Test_MicrosoftPreset_UsesMicrosoftProvider;
  end;

implementation

uses
  System.DateUtils,
  DeepBase.Social.OAuth;

function ExtractUrlQueryParams(const AUrl: string): TDictionary<string, string>;
var
  Query: string;
  QueryStart, FragmentStart: Integer;
begin
  QueryStart := Pos('?', AUrl);
  if QueryStart = 0 then
    Exit(TDictionary<string, string>.Create);

  Query := Copy(AUrl, QueryStart + 1, MaxInt);
  FragmentStart := Pos('#', Query);
  if FragmentStart > 0 then
    Query := Copy(Query, 1, FragmentStart - 1);

  Result := TSocialHelper.ParseQueryString(Query);
end;

{ TSocialTokenTests }

procedure TSocialTokenTests.Test_Clear_Sets_Defaults;
var
  Token: TSocialToken;
begin
  Token.AccessToken := 'test';
  Token.ExpiresIn := 3600;

  Token.Clear;

  Assert.AreEqual('', Token.AccessToken);
  Assert.AreEqual('', Token.RefreshToken);
  Assert.AreEqual(0, Token.ExpiresIn);
  Assert.AreEqual<TDateTime>(0, Token.ExpiresAt);
  Assert.AreEqual('', Token.TokenType);
  Assert.AreEqual('', Token.Scope);
  Assert.AreEqual('', Token.OpenId);
  Assert.AreEqual('', Token.UnionId);
end;

procedure TSocialTokenTests.Test_IsExpired_ReturnsFalseWhenNoExpiration;
var
  Token: TSocialToken;
begin
  Token.Clear;
  // ExpiresAt = 0 means no expiration info
  Assert.IsFalse(Token.IsExpired);
end;

procedure TSocialTokenTests.Test_IsExpired_ReturnsTrueWhenPastExpiration;
var
  Token: TSocialToken;
begin
  Token.Clear;
  Token.ExpiresAt := IncHour(Now, -1); // 1 hour ago
  Assert.IsTrue(Token.IsExpired);
end;

procedure TSocialTokenTests.Test_IsExpired_ReturnsFalseWhenNotExpired;
var
  Token: TSocialToken;
begin
  Token.Clear;
  Token.ExpiresAt := IncHour(Now, 1); // 1 hour from now
  Assert.IsFalse(Token.IsExpired);
end;

{ TSocialUserInfoTests }

procedure TSocialUserInfoTests.Test_Clear_Sets_Defaults;
var
  Info: TSocialUserInfo;
begin
  Info.Success := True;
  Info.Nickname := 'Test';

  Info.Clear;

  Assert.IsFalse(Info.Success);
  Assert.AreEqual('', Info.ErrorCode);
  Assert.AreEqual('', Info.ErrorMessage);
  Assert.AreEqual(spWeChat, Info.Provider);
  Assert.AreEqual('', Info.OpenId);
  Assert.AreEqual('', Info.UnionId);
  Assert.AreEqual('', Info.Nickname);
  Assert.AreEqual('', Info.Avatar);
  Assert.AreEqual('', Info.Email);
  Assert.AreEqual('', Info.Phone);
  Assert.AreEqual(sgUnknown, Info.Gender);
  Assert.AreEqual('', Info.Country);
  Assert.AreEqual('', Info.Province);
  Assert.AreEqual('', Info.City);
  Assert.AreEqual('', Info.Language);
  Assert.AreEqual('', Info.RawJson);
end;

procedure TSocialUserInfoTests.Test_Fail_SetsErrorFields;
var
  Info: TSocialUserInfo;
begin
  Info := TSocialUserInfo.Fail('AUTH_FAIL', 'Authentication failed');

  Assert.IsFalse(Info.Success);
  Assert.AreEqual('AUTH_FAIL', Info.ErrorCode);
  Assert.AreEqual('Authentication failed', Info.ErrorMessage);
end;

{ TSocialShareTests }

procedure TSocialShareTests.Test_Clear_Sets_Defaults;
var
  Share: TSocialShare;
begin
  Share.Title := 'Test';
  Share.Url := 'http://test.com';

  Share.Clear;

  Assert.AreEqual(sstLink, Share.ShareType);
  Assert.AreEqual('', Share.Title);
  Assert.AreEqual('', Share.Description);
  Assert.AreEqual('', Share.Url);
  Assert.AreEqual('', Share.ImageUrl);
  Assert.AreEqual(Integer(0), Integer(Length(Share.ImageData)));
  Assert.AreEqual('', Share.VideoUrl);
  Assert.AreEqual('', Share.MusicUrl);
  Assert.AreEqual('', Share.MiniAppId);
  Assert.AreEqual('', Share.MiniAppPath);
end;

{ TSocialShareResultTests }

procedure TSocialShareResultTests.Test_Clear_Sets_Defaults;
var
  Res: TSocialShareResult;
begin
  Res.Success := True;
  Res.ShareId := '123';

  Res.Clear;

  Assert.IsFalse(Res.Success);
  Assert.AreEqual('', Res.ErrorCode);
  Assert.AreEqual('', Res.ErrorMessage);
  Assert.AreEqual('', Res.ShareId);
end;

procedure TSocialShareResultTests.Test_Fail_SetsErrorFields;
var
  Res: TSocialShareResult;
begin
  Res := TSocialShareResult.Fail('SHARE_FAIL', 'Share failed');

  Assert.IsFalse(Res.Success);
  Assert.AreEqual('SHARE_FAIL', Res.ErrorCode);
  Assert.AreEqual('Share failed', Res.ErrorMessage);
end;

{ TSocialConfigTests }

procedure TSocialConfigTests.Test_Create_SetsProvider;
var
  Config: TSocialConfig;
begin
  Config := TSocialConfig.Create(spGitHub);
  try
    Assert.AreEqual(spGitHub, Config.Provider);
  finally
    Config.Free;
  end;
end;

procedure TSocialConfigTests.Test_Create_SetsDefaultTimeout;
var
  Config: TSocialConfig;
begin
  Config := TSocialConfig.Create(spWeChat);
  try
    Assert.AreEqual(30000, Config.Timeout);
  finally
    Config.Free;
  end;
end;

procedure TSocialConfigTests.Test_Properties_ReadWrite;
var
  Config: TSocialConfig;
begin
  Config := TSocialConfig.Create(spGoogle);
  try
    Config.AppId := 'test-app-id';
    Config.AppSecret := 'test-secret';
    Config.RedirectUri := 'http://localhost/callback';
    Config.Scope := 'email profile';
    Config.Timeout := 60000;

    Assert.AreEqual('test-app-id', Config.AppId);
    Assert.AreEqual('test-secret', Config.AppSecret);
    Assert.AreEqual('http://localhost/callback', Config.RedirectUri);
    Assert.AreEqual('email profile', Config.Scope);
    Assert.AreEqual(60000, Config.Timeout);
  finally
    Config.Free;
  end;
end;

{ TSocialHelperTests }

procedure TSocialHelperTests.Test_ProviderToString_AllValues;
begin
  Assert.AreEqual('wechat', TSocialHelper.ProviderToString(spWeChat));
  Assert.AreEqual('weibo', TSocialHelper.ProviderToString(spWeibo));
  Assert.AreEqual('qq', TSocialHelper.ProviderToString(spQQ));
  Assert.AreEqual('github', TSocialHelper.ProviderToString(spGitHub));
  Assert.AreEqual('google', TSocialHelper.ProviderToString(spGoogle));
  Assert.AreEqual('twitter', TSocialHelper.ProviderToString(spTwitter));
  Assert.AreEqual('facebook', TSocialHelper.ProviderToString(spFacebook));
  Assert.AreEqual('microsoft', TSocialHelper.ProviderToString(spMicrosoft));
  Assert.AreEqual('apple', TSocialHelper.ProviderToString(spApple));
end;

procedure TSocialHelperTests.Test_StringToProvider_AllValues;
begin
  Assert.AreEqual(spWeChat, TSocialHelper.StringToProvider('wechat'));
  Assert.AreEqual(spWeibo, TSocialHelper.StringToProvider('weibo'));
  Assert.AreEqual(spQQ, TSocialHelper.StringToProvider('qq'));
  Assert.AreEqual(spGitHub, TSocialHelper.StringToProvider('github'));
  Assert.AreEqual(spGoogle, TSocialHelper.StringToProvider('google'));
  Assert.AreEqual(spTwitter, TSocialHelper.StringToProvider('twitter'));
  Assert.AreEqual(spFacebook, TSocialHelper.StringToProvider('facebook'));
  Assert.AreEqual(spMicrosoft, TSocialHelper.StringToProvider('microsoft'));
  Assert.AreEqual(spApple, TSocialHelper.StringToProvider('apple'));
end;

procedure TSocialHelperTests.Test_StringToProvider_CaseInsensitive;
begin
  Assert.AreEqual(spGitHub, TSocialHelper.StringToProvider('GITHUB'));
  Assert.AreEqual(spGoogle, TSocialHelper.StringToProvider('Google'));
  Assert.AreEqual(spMicrosoft, TSocialHelper.StringToProvider('MICROSOFT'));
  Assert.AreEqual(spWeChat, TSocialHelper.StringToProvider('WECHAT'));
end;

procedure TSocialHelperTests.Test_GenderToString_AllValues;
begin
  Assert.AreEqual('unknown', TSocialHelper.GenderToString(sgUnknown));
  Assert.AreEqual('male', TSocialHelper.GenderToString(sgMale));
  Assert.AreEqual('female', TSocialHelper.GenderToString(sgFemale));
end;

procedure TSocialHelperTests.Test_IntToGender_AllValues;
begin
  Assert.AreEqual(sgUnknown, TSocialHelper.IntToGender(0));
  Assert.AreEqual(sgMale, TSocialHelper.IntToGender(1));
  Assert.AreEqual(sgFemale, TSocialHelper.IntToGender(2));
  Assert.AreEqual(sgUnknown, TSocialHelper.IntToGender(99)); // Invalid value
end;

procedure TSocialHelperTests.Test_GenerateState_CorrectLength;
var
  S: string;
begin
  S := TSocialHelper.GenerateState(16);
  Assert.AreEqual(16, Integer(Length(S)));

  S := TSocialHelper.GenerateState(32);
  Assert.AreEqual(32, Integer(Length(S)));

  S := TSocialHelper.GenerateState; // Default 16
  Assert.AreEqual(16, Integer(Length(S)));
end;

procedure TSocialHelperTests.Test_GenerateState_Unique;
var
  S1, S2: string;
begin
  S1 := TSocialHelper.GenerateState(32);
  S2 := TSocialHelper.GenerateState(32);
  Assert.AreNotEqual(S1, S2, 'Generated states should be unique');
end;

procedure TSocialHelperTests.Test_GenerateCodeVerifier_UsesPKCECharset;
const
  Allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
var
  Verifier: string;
  I: Integer;
begin
  Verifier := TSocialHelper.GenerateCodeVerifier;

  Assert.AreEqual(64, Integer(Length(Verifier)));
  for I := 1 to Length(Verifier) do
    Assert.IsTrue(Pos(Verifier[I], Allowed) > 0,
      'Verifier contains a character outside the RFC 7636 charset');
end;

procedure TSocialHelperTests.Test_GenerateCodeChallengeS256_RFC7636Vector;
const
  Verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
  Challenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
begin
  Assert.AreEqual(Challenge, TSocialHelper.GenerateCodeChallengeS256(Verifier));
end;

procedure TSocialHelperTests.Test_UrlEncode_SpecialChars;
begin
  // Delphi TNetEncoding.URL.Encode uses + for spaces (form encoding)
  Assert.AreEqual('hello+world', TSocialHelper.UrlEncode('hello world'));
  Assert.AreEqual('a%3D', TSocialHelper.UrlEncode('a=').Substring(0, 4));
  Assert.IsTrue(TSocialHelper.UrlEncode('a&b').Contains('%26'));
end;

procedure TSocialHelperTests.Test_UrlDecode_EncodedChars;
begin
  Assert.AreEqual('hello world', TSocialHelper.UrlDecode('hello%20world'));
  Assert.AreEqual('a=b', TSocialHelper.UrlDecode('a%3Db'));
  Assert.AreEqual('a&b', TSocialHelper.UrlDecode('a%26b'));
end;

procedure TSocialHelperTests.Test_BuildQueryString;
var
  Params: TDictionary<string, string>;
  QueryStr: string;
begin
  Params := TDictionary<string, string>.Create;
  try
    Params.Add('client_id', 'test123');
    Params.Add('redirect_uri', 'http://localhost');
    Params.Add('scope', 'email profile');

    QueryStr := TSocialHelper.BuildQueryString(Params);

    // Check that all params are present (order may vary)
    Assert.IsTrue(QueryStr.Contains('client_id=test123'));
    Assert.IsTrue(QueryStr.Contains('redirect_uri='));
    Assert.IsTrue(QueryStr.Contains('scope='));
  finally
    Params.Free;
  end;
end;

procedure TSocialHelperTests.Test_ParseQueryString;
var
  Params: TDictionary<string, string>;
begin
  Params := TSocialHelper.ParseQueryString('code=abc123&state=xyz');
  try
    Assert.AreEqual(Integer(2), Integer(Params.Count));
    Assert.AreEqual('abc123', Params['code']);
    Assert.AreEqual('xyz', Params['state']);
  finally
    Params.Free;
  end;
end;

{ TOAuthClientPKCETests }

procedure TOAuthClientPKCETests.Test_GetAuthUrl_StoresStateAndAddsPKCE;
var
  Config: TOAuthConfig;
  Client: TOAuthClient;
  AuthUrl: string;
  Params: TDictionary<string, string>;
begin
  Config := TOAuthConfig.Create(opGitHub);
  Client := TOAuthClient.Create(Config);
  try
    Config.AppId := 'client-id';
    Config.AppSecret := 'client-secret';
    Config.RedirectUri := 'http://localhost/callback';

    AuthUrl := Client.GetAuthUrl('fixed-state');
    Params := ExtractUrlQueryParams(AuthUrl);
    try
      Assert.AreEqual('fixed-state', Client.LastState);
      Assert.AreEqual('fixed-state', Params['state']);
      Assert.AreEqual('S256', Params['code_challenge_method']);
      Assert.IsTrue(Params.ContainsKey('code_challenge'));
      Assert.AreEqual(64, Integer(Length(Client.LastCodeVerifier)));
      Assert.AreEqual(
        TSocialHelper.GenerateCodeChallengeS256(Client.LastCodeVerifier),
        Params['code_challenge']);
    finally
      Params.Free;
    end;
  finally
    Client.Free;
    Config.Free;
  end;
end;

procedure TOAuthClientPKCETests.Test_ValidateState_ReturnsExpectedResult;
var
  Config: TOAuthConfig;
  Client: TOAuthClient;
begin
  Config := TOAuthConfig.Create(opGoogle);
  Client := TOAuthClient.Create(Config);
  try
    Config.AppId := 'client-id';
    Config.RedirectUri := 'http://localhost/callback';

    Client.GetAuthUrl('state-ok');

    Assert.IsTrue(Client.ValidateState('state-ok'));
    Assert.IsFalse(Client.ValidateState('state-bad'));
  finally
    Client.Free;
    Config.Free;
  end;
end;

procedure TOAuthClientPKCETests.Test_ExchangeCode_WithInvalidState_RaisesBeforeNetwork;
var
  Config: TOAuthConfig;
  Client: TOAuthClient;
begin
  Config := TOAuthConfig.Create(opGitHub);
  Client := TOAuthClient.Create(Config);
  try
    Config.AppId := 'client-id';
    Config.AppSecret := 'client-secret';
    Config.RedirectUri := 'http://localhost/callback';

    Client.GetAuthUrl('state-ok');

    Assert.WillRaise(
      procedure begin Client.ExchangeCode('auth-code', 'state-bad'); end,
      ESocialAuthError
    );
  finally
    Client.Free;
    Config.Free;
  end;
end;

procedure TOAuthClientPKCETests.Test_MicrosoftPreset_UsesMicrosoftProvider;
var
  Config: TOAuthConfig;
begin
  Config := TOAuthConfig.Create(opMicrosoft);
  try
    Assert.AreEqual(spMicrosoft, Config.Provider);
    Assert.IsTrue(Config.AuthorizationEndpoint.Contains('microsoftonline.com'));
    Assert.IsTrue(Config.TokenEndpoint.Contains('microsoftonline.com'));
    Assert.IsTrue(Config.UserInfoEndpoint.Contains('graph.microsoft.com'));
  finally
    Config.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSocialTokenTests);
  TDUnitX.RegisterTestFixture(TSocialUserInfoTests);
  TDUnitX.RegisterTestFixture(TSocialShareTests);
  TDUnitX.RegisterTestFixture(TSocialShareResultTests);
  TDUnitX.RegisterTestFixture(TSocialConfigTests);
  TDUnitX.RegisterTestFixture(TSocialHelperTests);
  TDUnitX.RegisterTestFixture(TOAuthClientPKCETests);

end.
