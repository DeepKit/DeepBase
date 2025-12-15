unit Test.UniBase.Social;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  UniBase.Social;

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
    procedure Test_UrlEncode_SpecialChars;

    [Test]
    procedure Test_UrlDecode_EncodedChars;

    [Test]
    procedure Test_BuildQueryString;

    [Test]
    procedure Test_ParseQueryString;
  end;

implementation

uses
  System.DateUtils;

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
  Assert.AreEqual(0, Length(Share.ImageData));
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
  Assert.AreEqual(spApple, TSocialHelper.StringToProvider('apple'));
end;

procedure TSocialHelperTests.Test_StringToProvider_CaseInsensitive;
begin
  Assert.AreEqual(spGitHub, TSocialHelper.StringToProvider('GITHUB'));
  Assert.AreEqual(spGoogle, TSocialHelper.StringToProvider('Google'));
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
  Assert.AreEqual(16, Length(S));

  S := TSocialHelper.GenerateState(32);
  Assert.AreEqual(32, Length(S));

  S := TSocialHelper.GenerateState; // Default 16
  Assert.AreEqual(16, Length(S));
end;

procedure TSocialHelperTests.Test_GenerateState_Unique;
var
  S1, S2: string;
begin
  S1 := TSocialHelper.GenerateState(32);
  S2 := TSocialHelper.GenerateState(32);
  Assert.AreNotEqual(S1, S2, 'Generated states should be unique');
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
    Assert.AreEqual(2, Params.Count);
    Assert.AreEqual('abc123', Params['code']);
    Assert.AreEqual('xyz', Params['state']);
  finally
    Params.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSocialTokenTests);
  TDUnitX.RegisterTestFixture(TSocialUserInfoTests);
  TDUnitX.RegisterTestFixture(TSocialShareTests);
  TDUnitX.RegisterTestFixture(TSocialShareResultTests);
  TDUnitX.RegisterTestFixture(TSocialConfigTests);
  TDUnitX.RegisterTestFixture(TSocialHelperTests);

end.
