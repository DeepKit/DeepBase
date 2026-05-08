# DeepBase Social Integration

社交媒体集成模块，支�?OAuth 登录和社交分享�?

## 支持的平�?

| 平台 | OAuth 登录 | 分享 | 状�?|
|------|-----------|------|------|
| 微信 (WeChat) | �?| �?| �?|
| 微博 (Weibo) | �?| �?| �?|
| QQ | �?| �?| �?|
| Twitter/X | �?| �?| �?|
| GitHub | �?| - | �?|
| Google | �?| - | �?|

## 核心文件

- `DeepBase.Social.pas` - 统一社交接口和基�?
- `DeepBase.Social.WeChat.pas` - 微信实现
- `DeepBase.Social.Weibo.pas` - 微博实现
- `DeepBase.Social.QQ.pas` - QQ 实现
- `DeepBase.Social.OAuth.pas` - OAuth 2.0 通用实现

## 快速开�?

### 微信登录示例

```pascal
uses
  DeepBase.Social, DeepBase.Social.WeChat;

var
  Config: TWeChatConfig;
  Client: ISocialClient;
  AuthUrl: string;
begin
  Config := TWeChatConfig.Create;
  Config.AppId := 'your_app_id';
  Config.AppSecret := 'your_app_secret';
  Config.RedirectUri := 'https://your-site.com/callback/wechat';

  Client := TWeChatClient.Create(Config);
  
  // 1. 获取授权 URL，重定向用户
  AuthUrl := Client.GetAuthUrl(['snsapi_login']);
  ShellExecute(0, 'open', PChar(AuthUrl), nil, nil, SW_SHOW);
  
  // 2. 用户授权后，�?code 换取用户信息
  // 在回调处理中:
  var UserInfo := Client.GetUserInfo(Code);
  if UserInfo.Success then
  begin
    ShowMessage('欢迎 ' + UserInfo.Nickname);
    // 保存用户信息，创建本地账�?
  end;
end;
```

### GitHub 登录示例

```pascal
uses
  DeepBase.Social, DeepBase.Social.OAuth;

var
  Config: TOAuthConfig;
  Client: TOAuthClient;
begin
  Config := TOAuthConfig.Create;
  Config.Provider := opGitHub;
  Config.ClientId := 'your_client_id';
  Config.ClientSecret := 'your_client_secret';
  Config.RedirectUri := 'https://your-site.com/callback/github';
  Config.Scope := 'user:email';

  Client := TOAuthClient.Create(Config);
  
  // 获取授权 URL
  var AuthUrl := Client.GetAuthUrl;
  
  // 回调处理
  var Token := Client.ExchangeCode(Code);
  var UserInfo := Client.GetUserInfo(Token.AccessToken);
end;
```

### 微信分享示例

```pascal
uses
  DeepBase.Social, DeepBase.Social.WeChat;

var
  Client: TWeChatClient;
  Share: TSocialShare;
begin
  Share.Clear;
  Share.Title := '分享标题';
  Share.Description := '分享描述';
  Share.Url := 'https://your-site.com/article/123';
  Share.ImageUrl := 'https://your-site.com/images/cover.jpg';
  Share.ShareType := stLink;
  
  // 分享到微信朋友圈
  Client.Share(Share, swTimeline);
  
  // 分享给微信好�?
  Client.Share(Share, swSession);
end;
```

## 回调处理

### Web 应用

```pascal
// �?Web 服务器回调端点中
procedure HandleOAuthCallback(const Provider, Code, State: string);
var
  Client: ISocialClient;
  UserInfo: TSocialUserInfo;
begin
  Client := GetSocialClient(Provider);
  
  // 验证 state 防止 CSRF
  if not ValidateState(State) then
    raise Exception.Create('Invalid state');
  
  UserInfo := Client.GetUserInfo(Code);
  if UserInfo.Success then
  begin
    // 查找或创建用�?
    var User := FindOrCreateUser(Provider, UserInfo.OpenId, UserInfo);
    // 登录用户
    LoginUser(User);
  end;
end;
```

### 桌面应用

```pascal
// 使用本地 HTTP 服务器接收回�?
uses
  DeepBase.Social.LocalServer;

var
  Server: TLocalOAuthServer;
begin
  Server := TLocalOAuthServer.Create(8888);  // 本地端口
  try
    Server.OnCallback := procedure(Code, State: string)
    begin
      // 处理回调
      ProcessOAuthCallback(Code, State);
    end;
    
    // 打开授权页面
    var AuthUrl := Client.GetAuthUrl + '&redirect_uri=http://localhost:8888/callback';
    ShellExecute(0, 'open', PChar(AuthUrl), nil, nil, SW_SHOW);
    
    // 等待回调
    Server.WaitForCallback(60000);  // 60 秒超�?
  finally
    Server.Free;
  end;
end;
```

## 配置说明

### 微信开放平�?

| 参数 | 说明 |
|------|------|
| AppId | 应用 ID |
| AppSecret | 应用密钥 |
| RedirectUri | 回调地址 |

申请地址: https://open.weixin.qq.com/

### 微博开放平�?

| 参数 | 说明 |
|------|------|
| AppKey | 应用 Key |
| AppSecret | 应用 Secret |
| RedirectUri | 回调地址 |

申请地址: https://open.weibo.com/

### GitHub

| 参数 | 说明 |
|------|------|
| ClientId | OAuth App Client ID |
| ClientSecret | OAuth App Client Secret |
| RedirectUri | 回调地址 |

申请地址: https://github.com/settings/developers

### Google

| 参数 | 说明 |
|------|------|
| ClientId | OAuth 2.0 Client ID |
| ClientSecret | Client Secret |
| RedirectUri | 回调地址 |

申请地址: https://console.cloud.google.com/

## 用户信息映射

不同平台返回的用户信息字段不同，统一映射�?`TSocialUserInfo`:

| 字段 | 微信 | 微博 | GitHub | Google |
|------|------|------|--------|--------|
| OpenId | openid | uid | id | sub |
| UnionId | unionid | - | - | - |
| Nickname | nickname | screen_name | login | name |
| Avatar | headimgurl | avatar_large | avatar_url | picture |
| Email | - | - | email | email |
| Gender | sex | gender | - | - |

## 安全建议

1. **密钥保护**: 使用 `DeepBase.Security.DPAPI` 加密存储 AppSecret
2. **CSRF 防护**: 使用随机 state 参数并验�?3. **HTTPS**: 回调地址必须使用 HTTPS（本地开发除外）
4. **Token 存储**: Access Token 应安全存储，不要明文保存
5. **微信 Token 交换**: 微信 `oauth2/access_token` �?`oauth2/refresh_token` 接口要求�?`secret` 放在 URL 查询参数。生产环境建议通过服务端代理中转（客户端仅�?`code`/`refresh_token`），避免 AppSecret 出现在网关日志、反向代理日志或监控链路中�?6. **QQ Token 交换**: 优先使用 `application/x-www-form-urlencoded` POST body 传输 `client_secret`。仅在第三方端点兼容性要求下再回退 GET 查询参数，并确保日志脱敏�?7. **最小暴露面**: AppSecret 仅允许存在于后端进程内存，不下发到前端、移动端或桌面端配置文件�?
## 相关文档

- [微信开放平台文档](https://developers.weixin.qq.com/doc/oplatform/)
- [微博开放平台文档](https://open.weibo.com/wiki/)
- [GitHub OAuth Apps](https://docs.github.com/en/developers/apps/building-oauth-apps)
- [Google OAuth 2.0](https://developers.google.com/identity/protocols/oauth2)
