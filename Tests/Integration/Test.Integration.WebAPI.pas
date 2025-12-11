{ ============================================================================
  Test.Integration.WebAPI - WebAPI Core/Auth/OpenAPI Integration Tests

  覆盖范围:
    - TApiServer/TApiRouter 基本路由 & 中间件链
    - HTTP 请求解析: 路径参数 / 查询参数 / JSON Body
    - CORS 预检 OPTIONS 请求
    - JWT Bearer 认证中间件 (TAuthMiddleware + TJWTManager)
    - OpenAPI 文档生成器 (TOpenApiGenerator)
    - WebSocket 消息路由器 (TWebSocketMessageRouter)
  ============================================================================ }

unit Test.Integration.WebAPI;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework,
  UniBase.IntegrationTest,
  UniBase.WebAPI.Core,
  UniBase.WebAPI.Auth,
  UniBase.WebAPI.OpenAPI,
  UniBase.WebAPI.WebSocket,
  UniBase.Net;

type
  { ============================================================================
    TWebApiIntegrationTest
    - 针对 HTTP/WebAPI Core + Auth + OpenAPI 的端到端测试
    - 通过实际启动 TApiServer 并使用 UniBase.Net HTTP 客户端发起请求
    ============================================================================ }

  [TestFixture]
  TWebApiIntegrationTest = class(TIntegrationTestBase)
  private
    FServer: TApiServer;
    FClient: THttpClient_;
    FJWTManager: TJWTManager;
    FAuthMiddleware: TAuthMiddleware;
    FBaseUrl: string;

    function GetJsonObject(const AResponse: THttpResponse): TJSONObject;
  protected
    procedure InitializeTestData; override;
    procedure CleanupTestData; override;
  public
    [SetupFixture]
    procedure SetupFixture; override;

    [TearDownFixture]
    procedure TearDownFixture; override;

    [Test]
    procedure Test_BasicGetRoute_ReturnsJson;

    [Test]
    procedure Test_PostJson_EchoesRequestBody;

    [Test]
    procedure Test_RouteParams_And_QueryParams_Parsed;

    [Test]
    procedure Test_CORS_Preflight_Options_ReturnsHeaders;

    [Test]
    procedure Test_Auth_JwtBearer_Succeeds;

    [Test]
    procedure Test_Auth_MissingToken_Returns401;

    [Test]
    procedure Test_OpenApiGenerator_Includes_RegisteredRoutes;
  end;

  { ============================================================================
    TWebSocketRouterIntegrationTest
    - 重点验证 WebSocket 消息路由器的事件分发逻辑
    - 不进行真实网络握手, 仅在内存中构造 TWebSocketMessage
    ============================================================================ }

  [TestFixture]
  TWebSocketRouterIntegrationTest = class(TIntegrationTestBase)
  public
    [Test]
    procedure Test_MessageRouter_RoutesByEventName;

    [Test]
    procedure Test_MessageRouter_UsesDefaultHandler_ForNonJsonOrUnknown;
  end;

implementation

{ TWebApiIntegrationTest }

procedure TWebApiIntegrationTest.SetupFixture;
var
  LSecureGroup: TRouteGroup;
begin
  inherited;

  // 启动独立的 WebAPI 服务器 (监听 127.0.0.1:18080)
  FServer := TApiServer.Create;
  FServer.Config.Host := '127.0.0.1';
  FServer.Config.Port := 18080;
  FServer.Config.CORSEnabled := True;
  FServer.Config.CORSOrigins := '*';
  FServer.Config.CORSMethods := 'GET, POST, PUT, PATCH, DELETE, OPTIONS';
  FServer.Config.CORSHeaders := 'Content-Type, Authorization, X-Requested-With';
  FServer.Config.LogRequests := False;

  // 基本路由: /api/ping
  FServer.Get('/api/ping',
    procedure (AContext: TApiContext)
    var
      LObj: TJSONObject;
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('message', 'pong');
      AContext.Response.SendJSON(LObj, True);
    end
  );

  // JSON Echo: /api/echo
  FServer.Post('/api/echo',
    procedure (AContext: TApiContext)
    var
      LJson: TJSONValue;
    begin
      LJson := AContext.Request.BodyAsJSON;
      if LJson = nil then
      begin
        AContext.Response.BadRequest('Invalid JSON');
        Exit;
      end;
      AContext.Response.SendJSON(LJson, True);
    end
  );

  // 路径参数 + 查询参数: /api/users/:id?verbose=1
  FServer.Get('/api/users/:id',
    procedure (AContext: TApiContext)
    var
      LObj: TJSONObject;
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('id', AContext.Request.GetRouteParam('id'));
      LObj.AddPair('verbose', AContext.Request.GetQueryParam('verbose'));
      AContext.Response.SendJSON(LObj, True);
    end
  );

  // JWT 管理器 & 认证中间件 (仅对 /secure/* 路由生效)
  FJWTManager := TJWTManager.Create('test_secret');

  FAuthMiddleware := TAuthMiddleware.Create;
  FAuthMiddleware.JWTManager := FJWTManager;
  FAuthMiddleware.RequireAuth := True;

  LSecureGroup := FServer.Group('/secure');
  LSecureGroup.Use(FAuthMiddleware.GetMiddleware());

  // /secure/profile - 返回当前认证用户信息
  LSecureGroup.Get('/profile',
    procedure (AContext: TApiContext)
    var
      LUser: TAuthenticatedUser;
      LObj: TJSONObject;
    begin
      LUser := GetAuthenticatedUser(AContext);
      if LUser = nil then
      begin
        AContext.Response.Unauthorized('No user');
        Exit;
      end;

      LObj := TJSONObject.Create;
      LObj.AddPair('userId', LUser.UserId);
      LObj.AddPair('username', LUser.Username);
      AContext.Response.SendJSON(LObj, True);
    end
  );

  // 启动服务器
  FServer.Start;

  FBaseUrl := Format('http://%s:%d', [FServer.Config.Host, FServer.Config.Port]);
  FClient := THttpClient_.Create(FBaseUrl);
  FClient.DefaultTimeout := 5000;
end;

procedure TWebApiIntegrationTest.TearDownFixture;
begin
  if Assigned(FClient) then
    FClient.Free;

  if Assigned(FServer) then
  begin
    FServer.Stop;
    FServer.Free;
  end;

  if Assigned(FAuthMiddleware) then
    FAuthMiddleware.Free;

  if Assigned(FJWTManager) then
    FJWTManager.Free;

  inherited;
end;

procedure TWebApiIntegrationTest.InitializeTestData;
begin
  inherited;
  // 当前 WebAPI 测试不依赖数据库, 无需额外数据准备
end;

procedure TWebApiIntegrationTest.CleanupTestData;
begin
  // 同上, 无需清理数据库数据
  inherited;
end;

function TWebApiIntegrationTest.GetJsonObject(const AResponse: THttpResponse): TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(AResponse.Body) as TJSONObject;
  Assert.IsNotNull(Result, 'Response should be valid JSON');
end;

procedure TWebApiIntegrationTest.Test_BasicGetRoute_ReturnsJson;
var
  LResp: THttpResponse;
  LJson: TJSONObject;
begin
  LResp := FClient.Get('/api/ping');
  try
    Assert.AreEqual(200, LResp.StatusCode, 'GET /api/ping should return 200');
    Assert.IsTrue(LResp.ContentType.ToLower.Contains('application/json'),
      'Content-Type should be application/json');

    LJson := GetJsonObject(LResp);
    try
      Assert.AreEqual('pong', LJson.GetValue<string>('message'),
        'message field should be "pong"');
    finally
      LJson.Free;
    end;
  finally
    LResp.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_PostJson_EchoesRequestBody;
var
  LReq: THttpRequest;
  LResp: THttpResponse;
  LJson, LEcho: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('name', 'Alice');
    LJson.AddPair('age', TJSONNumber.Create(30));

    LReq := FClient.Request('/api/echo').JsonBody(LJson);
  finally
    LJson.Free; // JsonBody 已经序列化为字符串, 不再需要原对象
  end;

  LResp := LReq.Post;
  try
    Assert.AreEqual(200, LResp.StatusCode, 'POST /api/echo should return 200');

    LEcho := GetJsonObject(LResp);
    try
      Assert.AreEqual('Alice', LEcho.GetValue<string>('name'));
      Assert.AreEqual(30, LEcho.GetValue<Integer>('age'));
    finally
      LEcho.Free;
    end;
  finally
    LResp.Free;
    LReq.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_RouteParams_And_QueryParams_Parsed;
var
  LResp: THttpResponse;
  LJson: TJSONObject;
begin
  LResp := FClient.Get('/api/users/42?verbose=1');
  try
    Assert.AreEqual(200, LResp.StatusCode);

    LJson := GetJsonObject(LResp);
    try
      Assert.AreEqual('42', LJson.GetValue<string>('id'));
      Assert.AreEqual('1', LJson.GetValue<string>('verbose'));
    finally
      LJson.Free;
    end;
  finally
    LResp.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_CORS_Preflight_Options_ReturnsHeaders;
var
  LReq: THttpRequest;
  LResp: THttpResponse;
begin
  LReq := FClient.Request('/api/ping')
    .Method(THttpMethod.hmOptions)
    .Header('Origin', 'http://example.com')
    .Header('Access-Control-Request-Method', 'GET');

  LResp := LReq.Execute;
  try
    Assert.AreEqual(200, LResp.StatusCode, 'OPTIONS should return 200 for CORS preflight');

    Assert.AreEqual('*',
      LResp.Headers['Access-Control-Allow-Origin'],
      'Access-Control-Allow-Origin should be "*"');

    Assert.IsTrue(LResp.Headers.ContainsKey('Access-Control-Allow-Methods'),
      'Access-Control-Allow-Methods header missing');
    Assert.IsTrue(LResp.Headers.ContainsKey('Access-Control-Allow-Headers'),
      'Access-Control-Allow-Headers header missing');
  finally
    LResp.Free;
    LReq.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_Auth_JwtBearer_Succeeds;
var
  LToken: string;
  LReq: THttpRequest;
  LResp: THttpResponse;
  LJson: TJSONObject;
begin
  // 生成简单的访问令牌 (subject = "user123")
  LToken := FJWTManager.GenerateToken('user123', ['admin']);

  LReq := FClient.Request('/secure/profile')
    .Header('Authorization', 'Bearer ' + LToken);

  LResp := LReq.Get;
  try
    Assert.AreEqual(200, LResp.StatusCode, 'Authorized request should succeed');

    LJson := GetJsonObject(LResp);
    try
      Assert.AreEqual('user123', LJson.GetValue<string>('userId'));
      // username 默认为 subject 或 username 声明, 这里只验证存在即可
      Assert.IsTrue(LJson.GetValue<string>('username') <> '', 'username should not be empty');
    finally
      LJson.Free;
    end;
  finally
    LResp.Free;
    LReq.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_Auth_MissingToken_Returns401;
var
  LResp: THttpResponse;
  LJson: TJSONObject;
begin
  // 未携带任何认证信息访问 /secure/profile
  LResp := FClient.Get('/secure/profile');
  try
    Assert.AreEqual(401, LResp.StatusCode, 'Missing token should return 401');

    LJson := GetJsonObject(LResp);
    try
      Assert.AreEqual('Authentication required', LJson.GetValue<string>('error'));
      Assert.AreEqual(401, LJson.GetValue<Integer>('code'));
    finally
      LJson.Free;
    end;
  finally
    LResp.Free;
  end;
end;

procedure TWebApiIntegrationTest.Test_OpenApiGenerator_Includes_RegisteredRoutes;
var
  LGen: TOpenApiGenerator;
  LSpec: string;
  LRoot, LPaths, LPathObj, LOp: TJSONObject;
  LValue: TJSONValue;
  LParams: TJSONArray;
begin
  LGen := TOpenApiGenerator.Create(FServer.Router);
  try
    LGen.SetInfo('UniBase Test API', 'WebAPI integration test spec', '1.0.0');
    LGen.AddServer(FBaseUrl, 'Local test server');
    LGen.Generate;

    LSpec := LGen.GetJSON;
    LRoot := TJSONObject.ParseJSONValue(LSpec) as TJSONObject;
    Assert.IsNotNull(LRoot, 'OpenAPI spec should be valid JSON');
    try
      // 基本字段
      Assert.AreEqual('3.0.3', LRoot.GetValue<string>('openapi'));

      LPaths := LRoot.GetValue('paths') as TJSONObject;
      Assert.IsNotNull(LPaths, 'paths section should exist');

      // /api/ping 路由存在且包含 GET 操作
      Assert.IsTrue(LPaths.TryGetValue('/api/ping', LValue), 'paths should contain /api/ping');
      LPathObj := LValue as TJSONObject;
      Assert.IsNotNull(LPathObj.GetValue('get') as TJSONObject,
        'GET operation for /api/ping should exist');

      // /api/users/{id} 路由存在且包含路径参数 id
      Assert.IsTrue(LPaths.TryGetValue('/api/users/{id}', LValue),
        'paths should contain /api/users/{id}');
      LPathObj := LValue as TJSONObject;
      LOp := LPathObj.GetValue('get') as TJSONObject;
      Assert.IsNotNull(LOp, 'GET operation for /api/users/{id} should exist');

      LParams := LOp.GetValue('parameters') as TJSONArray;
      Assert.IsNotNull(LParams, 'GET /api/users/{id} should declare path parameter');
      Assert.IsTrue(LParams.Count > 0, 'parameters array should not be empty');
    finally
      LRoot.Free;
    end;
  finally
    LGen.Free;
  end;
end;

{ TWebSocketRouterIntegrationTest }

procedure TWebSocketRouterIntegrationTest.Test_MessageRouter_RoutesByEventName;
var
  LRouter: TWebSocketMessageRouter;
  LMsg: TWebSocketMessage;
  LChatCalled, LDefaultCalled: Boolean;
  LLastText: string;
begin
  LRouter := TWebSocketMessageRouter.Create;
  try
    LChatCalled := False;
    LDefaultCalled := False;
    LLastText := '';

    LRouter.On('chat.message',
      procedure(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage)
      begin
        LChatCalled := True;
        LLastText := AMessage.Text;
      end
    );

    LRouter.SetDefault(
      procedure(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage)
      begin
        LDefaultCalled := True;
      end
    );

    // 发送具有 event = chat.message 的 JSON 文本消息
    LMsg := TWebSocketMessage.Create;
    try
      LMsg.Opcode := TWebSocketOpcode.wocText;
      LMsg.Text := '{"event":"chat.message","payload":{"text":"hello"}}';

      LRouter.HandleMessage(nil, LMsg);

      Assert.IsTrue(LChatCalled, 'chat.message handler should be invoked');
      Assert.IsFalse(LDefaultCalled, 'default handler should not be invoked for known event');
      Assert.IsTrue(LLastText.Contains('"chat.message"'));
    finally
      LMsg.Free;
    end;
  finally
    LRouter.Free;
  end;
end;

procedure TWebSocketRouterIntegrationTest.Test_MessageRouter_UsesDefaultHandler_ForNonJsonOrUnknown;
var
  LRouter: TWebSocketMessageRouter;
  LMsg: TWebSocketMessage;
  LDefaultCount: Integer;
begin
  LRouter := TWebSocketMessageRouter.Create;
  try
    LDefaultCount := 0;

    LRouter.SetDefault(
      procedure(AConnection: TWebSocketConnection; AMessage: TWebSocketMessage)
      begin
        Inc(LDefaultCount);
      end
    );

    // 非 JSON 文本消息
    LMsg := TWebSocketMessage.Create;
    try
      LMsg.Opcode := TWebSocketOpcode.wocText;
      LMsg.Text := 'plain text';
      LRouter.HandleMessage(nil, LMsg);
    finally
      LMsg.Free;
    end;

    // JSON 但没有 event 字段
    LMsg := TWebSocketMessage.Create;
    try
      LMsg.Opcode := TWebSocketOpcode.wocText;
      LMsg.Text := '{"foo":"bar"}';
      LRouter.HandleMessage(nil, LMsg);
    finally
      LMsg.Free;
    end;

    Assert.AreEqual(2, LDefaultCount,
      'Default handler should be invoked for non-JSON or unknown event messages');
  finally
    LRouter.Free;
  end;
end;

end.
