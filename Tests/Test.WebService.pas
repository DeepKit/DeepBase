{ ============================================================================
  Test.WebService - WebService 工具单元测试

  测试覆盖:
    - DeepBase.WebAPI.Core: 核心路由和请求处�?
    - DeepBase.WebAPI.Auth: 认证中间�?
    - DeepBase.WebAPI.OpenAPI: OpenAPI 文档生成
    - DeepBase.WebAPI.WebSocket: WebSocket 支持
  ============================================================================ }

unit Test.WebService;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DUnitX.TestFramework;

type
  // ============================================================================
  // HTTP Status/ContentType Tests
  // ============================================================================

  [TestFixture]
  THttpConstantsTests = class
  public
    [Test]
    procedure Test_HttpStatus_OK;

    [Test]
    procedure Test_HttpStatus_Created;

    [Test]
    procedure Test_HttpStatus_BadRequest;

    [Test]
    procedure Test_HttpStatus_Unauthorized;

    [Test]
    procedure Test_HttpStatus_NotFound;

    [Test]
    procedure Test_HttpStatus_InternalServerError;

    [Test]
    procedure Test_ContentType_JSON;

    [Test]
    procedure Test_ContentType_HTML;

    [Test]
    procedure Test_ContentType_Plain;

    [Test]
    procedure Test_ApiServerConfig_DefaultCorsIsClosed;
  end;

  // ============================================================================
  // API Router Tests
  // ============================================================================

  [TestFixture]
  TApiRouterTests = class
  public
    [Test]
    procedure Test_Router_Create;

    [Test]
    procedure Test_Router_AddRoute_Get;

    [Test]
    procedure Test_Router_AddRoute_Post;

    [Test]
    procedure Test_Router_AddRoute_Multiple;

    [Test]
    procedure Test_Router_Group;

    [Test]
    procedure Test_Router_Middleware;

    [Test]
    procedure Test_Router_Match_ExtractsRouteParams;
  end;

  // ============================================================================
  // API Request Tests
  // ============================================================================

  [TestFixture]
  TApiRequestTests = class
  public
    [Test]
    procedure Test_Request_Create;

    [Test]
    procedure Test_Request_ParseQueryString;

    [Test]
    procedure Test_Request_GetHeader;

    [Test]
    procedure Test_Request_GetQueryParam;

    [Test]
    procedure Test_Request_ParseJSON;
  end;

  // ============================================================================
  // API Response Tests
  // ============================================================================

  [TestFixture]
  TApiResponseTests = class
  public
    [Test]
    procedure Test_Response_Create;

    [Test]
    procedure Test_Response_SetStatus;

    [Test]
    procedure Test_Response_SetContentType;

    [Test]
    procedure Test_Response_JSON;

    [Test]
    procedure Test_Response_Text;

    [Test]
    procedure Test_Response_Redirect;

    [Test]
    procedure Test_Response_SetHeader;

    [Test]
    procedure Test_Response_ErrorEscapesJSONPayload;
  end;

  // ============================================================================
  // Auth Middleware Example Tests
  // ============================================================================

  [TestFixture]
  TAuthMiddlewareExampleTests = class
  public
    [Test]
    procedure Test_JWT_Middleware_Example_DeniesMissingToken;

    [Test]
    procedure Test_ApiKey_Middleware_Example_AllowsValidKey;
  end;

  // ============================================================================
  // WebSocket Tests
  // ============================================================================

  [TestFixture]
  TWebSocketTests = class
  public
    [Test]
    procedure Test_WebSocketOpcode_Values;

    [Test]
    procedure Test_WebSocketCloseCode_Values;

    [Test]
    procedure Test_WebSocketMessage_Create;

    [Test]
    procedure Test_WebSocketRoom_Create;
  end;

  // ============================================================================
  // OpenAPI Tests
  // ============================================================================

  [TestFixture]
  TOpenAPITests = class
  public
    [Test]
    procedure Test_OpenAPIInfo_Create;

    [Test]
    procedure Test_OpenAPIPath_Create;

    [Test]
    procedure Test_OpenAPIDocument_Generate;

    [Test]
    procedure Test_OpenAPIDocument_ToJSON;
  end;

implementation

uses
  DeepBase.WebAPI.Core,
  DeepBase.WebAPI.Auth,
  DeepBase.WebAPI.WebSocket,
  DeepBase.WebAPI.OpenAPI;

{ THttpConstantsTests }

procedure THttpConstantsTests.Test_HttpStatus_OK;
begin
  Assert.AreEqual(200, THttpStatus.OK);
end;

procedure THttpConstantsTests.Test_HttpStatus_Created;
begin
  Assert.AreEqual(201, THttpStatus.Created);
end;

procedure THttpConstantsTests.Test_HttpStatus_BadRequest;
begin
  Assert.AreEqual(400, THttpStatus.BadRequest);
end;

procedure THttpConstantsTests.Test_HttpStatus_Unauthorized;
begin
  Assert.AreEqual(401, THttpStatus.Unauthorized);
end;

procedure THttpConstantsTests.Test_HttpStatus_NotFound;
begin
  Assert.AreEqual(404, THttpStatus.NotFound);
end;

procedure THttpConstantsTests.Test_HttpStatus_InternalServerError;
begin
  Assert.AreEqual(500, THttpStatus.InternalServerError);
end;

procedure THttpConstantsTests.Test_ContentType_JSON;
begin
  Assert.AreEqual('application/json', TContentType.JSON);
end;

procedure THttpConstantsTests.Test_ContentType_HTML;
begin
  Assert.AreEqual('text/html', TContentType.HTML);
end;

procedure THttpConstantsTests.Test_ContentType_Plain;
begin
  Assert.AreEqual('text/plain', TContentType.Plain);
end;

procedure THttpConstantsTests.Test_ApiServerConfig_DefaultCorsIsClosed;
var
  Config: TApiServerConfig;
begin
  Config := TApiServerConfig.Create;
  try
    Assert.IsFalse(Config.CORSEnabled, 'CORS should be disabled by default');
    Assert.AreEqual('', Config.CORSOrigins, 'CORS origins should be empty by default');
  finally
    Config.Free;
  end;
end;

{ TApiRouterTests }

procedure TApiRouterTests.Test_Router_Create;
var
  Router: TApiRouter;
begin
  Router := TApiRouter.Create;
  try
    Assert.IsNotNull(Router);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_AddRoute_Get;
var
  Router: TApiRouter;
  Called: Boolean;
begin
  Router := TApiRouter.Create;
  try
    Called := False;
    Router.Get('/test', procedure(Ctx: TApiContext) begin Called := True; end);
    Assert.IsNotNull(Router);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_AddRoute_Post;
var
  Router: TApiRouter;
begin
  Router := TApiRouter.Create;
  try
    Router.Post('/users', procedure(Ctx: TApiContext) begin end);
    Assert.IsNotNull(Router);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_AddRoute_Multiple;
var
  Router: TApiRouter;
begin
  Router := TApiRouter.Create;
  try
    Router.Get('/users', procedure(Ctx: TApiContext) begin end);
    Router.Post('/users', procedure(Ctx: TApiContext) begin end);
    Router.Put('/users/:id', procedure(Ctx: TApiContext) begin end);
    Router.Delete('/users/:id', procedure(Ctx: TApiContext) begin end);
    Assert.IsNotNull(Router);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_Group;
var
  Router: TApiRouter;
  ApiGroup: TRouteGroup;
begin
  Router := TApiRouter.Create;
  try
    ApiGroup := Router.Group('/api/v1');
    Assert.IsNotNull(ApiGroup);
    ApiGroup.Get('/users', procedure(Ctx: TApiContext) begin end);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_Middleware;
var
  Router: TApiRouter;
begin
  Router := TApiRouter.Create;
  try
    Router.Use(procedure(Ctx: TApiContext; Next: TProc) begin Next(); end);
    Assert.IsNotNull(Router);
  finally
    Router.Free;
  end;
end;

procedure TApiRouterTests.Test_Router_Match_ExtractsRouteParams;
var
  Router: TApiRouter;
  Params: TRouteParams;
  Route: TRouteDefinition;
begin
  Router := TApiRouter.Create;
  Params := TRouteParams.Create;
  try
    Router.Get('/users/:id', procedure(Ctx: TApiContext) begin end);

    Route := Router.Match(hmGet, '/users/42', Params);
    Assert.IsNotNull(Route, 'Route should match');
    Assert.IsTrue(Params.ContainsKey('id'));
    Assert.AreEqual('42', Params['id']);
  finally
    Params.Free;
    Router.Free;
  end;
end;

{ TApiRequestTests }

procedure TApiRequestTests.Test_Request_Create;
var
  Request: TApiRequest;
begin
  Request := TApiRequest.Create;
  try
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

procedure TApiRequestTests.Test_Request_ParseQueryString;
var
  Request: TApiRequest;
begin
  Request := TApiRequest.Create;
  try
    Request.QueryString := 'name=John&age=30';
    Request.Initialize;
    Assert.AreEqual('John', Request.QueryParams['name']);
    Assert.AreEqual('30', Request.QueryParams['age']);
  finally
    Request.Free;
  end;
end;

procedure TApiRequestTests.Test_Request_GetHeader;
var
  Request: TApiRequest;
begin
  Request := TApiRequest.Create;
  try
    Request.Headers.AddOrSetValue('content-type', 'application/json');
    Request.Headers.AddOrSetValue('authorization', 'Bearer token123');

    Assert.AreEqual('application/json', Request.GetHeader('Content-Type'));
    Assert.AreEqual('Bearer token123', Request.GetHeader('Authorization'));
  finally
    Request.Free;
  end;
end;

procedure TApiRequestTests.Test_Request_GetQueryParam;
var
  Request: TApiRequest;
begin
  Request := TApiRequest.Create;
  try
    Request.QueryString := 'page=1&limit=10';
    Request.Initialize;
    Assert.AreEqual('1', Request.GetQueryParam('page', ''));
    Assert.AreEqual('10', Request.GetQueryParam('limit', ''));
    Assert.AreEqual('default', Request.GetQueryParam('missing', 'default'));
  finally
    Request.Free;
  end;
end;

procedure TApiRequestTests.Test_Request_ParseJSON;
var
  Request: TApiRequest;
  JSONValue: TJSONValue;
  JSONObject: TJSONObject;
begin
  Request := TApiRequest.Create;
  try
    Request.Body := TEncoding.UTF8.GetBytes('{"name":"Test","value":123}');
    JSONValue := Request.BodyAsJSON;
    try
      Assert.IsNotNull(JSONValue);
      JSONObject := JSONValue as TJSONObject;
      Assert.IsNotNull(JSONObject);
      Assert.AreEqual('Test', JSONObject.GetValue<string>('name'));
      Assert.AreEqual(123, JSONObject.GetValue<Integer>('value'));
    finally
      JSONValue.Free;
    end;
  finally
    Request.Free;
  end;
end;

{ TApiResponseTests }

procedure TApiResponseTests.Test_Response_Create;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Assert.IsNotNull(Response);
    Assert.AreEqual(200, Response.StatusCode);  // Default status
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_SetStatus;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Response.StatusCode := 404;
    Assert.AreEqual(404, Response.StatusCode);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_SetContentType;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Response.ContentType := TContentType.JSON;
    Assert.AreEqual(TContentType.JSON, Response.ContentType);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_JSON;
var
  Response: TApiResponse;
  JSON: TJSONObject;
begin
  Response := TApiResponse.Create;
  try
    JSON := TJSONObject.Create;
    JSON.AddPair('status', 'ok');
    Response.SendJSON(JSON, True);
    Assert.AreEqual(TContentType.JSON, Response.ContentType);
    Assert.IsTrue(Pos('ok', Response.BodyAsString) > 0);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_Text;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Response.ContentType := TContentType.Plain;
    Response.Send('Hello World');
    Assert.AreEqual('Hello World', Response.BodyAsString);
    Assert.AreEqual(TContentType.Plain, Response.ContentType);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_Redirect;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Response.Redirect('/new-location');
    Assert.AreEqual(302, Response.StatusCode);
    Assert.AreEqual('/new-location', Response.Headers['Location']);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_SetHeader;
var
  Response: TApiResponse;
begin
  Response := TApiResponse.Create;
  try
    Response.SetHeader('X-Custom-Header', 'CustomValue');
    Assert.AreEqual('CustomValue', Response.Headers['X-Custom-Header']);
  finally
    Response.Free;
  end;
end;

procedure TApiResponseTests.Test_Response_ErrorEscapesJSONPayload;
var
  Response: TApiResponse;
  JsonValue: TJSONValue;
  JsonObj: TJSONObject;
  Msg: string;
begin
  Response := TApiResponse.Create;
  try
    Msg := 'bad "input" {' + #10 + '}';
    Response.BadRequest(Msg);

    JsonValue := TJSONObject.ParseJSONValue(Response.BodyAsString);
    try
      Assert.IsNotNull(JsonValue, 'Error response should be valid JSON');
      Assert.IsTrue(JsonValue is TJSONObject);
      JsonObj := JsonValue as TJSONObject;
      Assert.AreEqual(Msg, JsonObj.GetValue<string>('error'));
      Assert.AreEqual(THttpStatus.BadRequest, JsonObj.GetValue<Integer>('code'));
    finally
      JsonValue.Free;
    end;
  finally
    Response.Free;
  end;
end;

{ TAuthMiddlewareExampleTests }

procedure TAuthMiddlewareExampleTests.Test_JWT_Middleware_Example_DeniesMissingToken;
var
  Server: TApiServer;
  Context: TApiContext;
  JwtManager: TJWTManager;
  AuthMiddleware: TAuthMiddleware;
  Middleware: TMiddlewareFunc;
  NextCalled: Boolean;
begin
  Server := TApiServer.Create;
  Context := TApiContext.Create(Server);
  JwtManager := TJWTManager.Create('unit-test-secret');
  AuthMiddleware := TAuthMiddleware.Create;
  try
    AuthMiddleware.JWTManager := JwtManager;
    AuthMiddleware.RequireAuth := True;
    Middleware := AuthMiddleware.GetMiddleware;

    NextCalled := False;
    Middleware(Context,
      procedure
      begin
        NextCalled := True;
      end);

    Assert.IsFalse(NextCalled, 'Request without token should be blocked');
    Assert.IsTrue(Context.Aborted, 'Context should be aborted on auth failure');
    Assert.AreEqual(THttpStatus.Unauthorized, Context.Response.StatusCode);
  finally
    AuthMiddleware.Free;
    JwtManager.Free;
    Context.Free;
    Server.Free;
  end;
end;

procedure TAuthMiddlewareExampleTests.Test_ApiKey_Middleware_Example_AllowsValidKey;
var
  Server: TApiServer;
  Context: TApiContext;
  Store: IApiKeyStore;
  ApiKeyManager: TApiKeyManager;
  AuthMiddleware: TAuthMiddleware;
  Middleware: TMiddlewareFunc;
  KeyInfo: TApiKeyInfo;
  ApiKey: string;
  NextCalled: Boolean;
begin
  Server := TApiServer.Create;
  Context := TApiContext.Create(Server);
  Store := TMemoryApiKeyStore.Create;
  ApiKeyManager := TApiKeyManager.Create(Store);
  AuthMiddleware := TAuthMiddleware.Create;
  KeyInfo := nil;
  try
    KeyInfo := ApiKeyManager.CreateKey('svc-test', 'user-1', ['admin']);
    ApiKey := KeyInfo.Key;

    AuthMiddleware.ApiKeyManager := ApiKeyManager;
    AuthMiddleware.RequireAuth := True;
    Middleware := AuthMiddleware.GetMiddleware;

    Context.Request.Headers.AddOrSetValue('x-api-key', ApiKey);
    NextCalled := False;
    Middleware(Context,
      procedure
      begin
        NextCalled := True;
      end);

    Assert.IsTrue(NextCalled, 'Valid API key should pass middleware');
    Assert.IsFalse(Context.Aborted, 'Context should not be aborted on successful auth');
    Assert.AreEqual(THttpStatus.OK, Context.Response.StatusCode);
  finally
    KeyInfo.Free;
    AuthMiddleware.Free;
    ApiKeyManager.Free;
    Context.Free;
    Server.Free;
  end;
end;

{ TWebSocketTests }

procedure TWebSocketTests.Test_WebSocketOpcode_Values;
begin
  Assert.AreEqual(0, Ord(wocContinuation));
  Assert.AreEqual(1, Ord(wocText));
  Assert.AreEqual(2, Ord(wocBinary));
  Assert.AreEqual(8, Ord(wocClose));
  Assert.AreEqual(9, Ord(wocPing));
  Assert.AreEqual(10, Ord(wocPong));
end;

procedure TWebSocketTests.Test_WebSocketCloseCode_Values;
begin
  Assert.AreEqual(1000, Ord(wsccNormal));
  Assert.AreEqual(1001, Ord(wsccGoingAway));
  Assert.AreEqual(1002, Ord(wsccProtocolError));
end;

procedure TWebSocketTests.Test_WebSocketMessage_Create;
var
  Msg: TWebSocketMessage;
begin
  Msg := TWebSocketMessage.Create;
  try
    Assert.IsNotNull(Msg);
    Msg.Opcode := wocText;
    Msg.Text := 'Hello';
    Assert.AreEqual<TWebSocketOpcode>(wocText, Msg.Opcode);
    Assert.AreEqual('Hello', Msg.Text);
  finally
    Msg.Free;
  end;
end;

procedure TWebSocketTests.Test_WebSocketRoom_Create;
var
  Room: TWebSocketRoom;
begin
  Room := TWebSocketRoom.Create('test-room');
  try
    Assert.IsNotNull(Room);
    Assert.AreEqual('test-room', Room.Name);
    Assert.AreEqual<Integer>(0, Room.Count);
  finally
    Room.Free;
  end;
end;

{ TOpenAPITests }

procedure TOpenAPITests.Test_OpenAPIInfo_Create;
var
  Info: TOpenAPIInfo;
begin
  Info := TOpenAPIInfo.Create;
  try
    Info.Title := 'Test API';
    Info.Version := '1.0.0';
    Info.Description := 'Test API Description';

    Assert.AreEqual('Test API', Info.Title);
    Assert.AreEqual('1.0.0', Info.Version);
    Assert.AreEqual('Test API Description', Info.Description);
  finally
    Info.Free;
  end;
end;

procedure TOpenAPITests.Test_OpenAPIPath_Create;
var
  Doc: TOpenApiDocument;
  PathItem: TOpenApiPathItem;
begin
  Doc := TOpenApiDocument.Create;
  try
    PathItem := Doc.AddPath('/users');
    Assert.IsNotNull(PathItem);
    Assert.IsTrue(Doc.Paths.ContainsKey('/users'));
  finally
    Doc.Free;
  end;
end;

procedure TOpenAPITests.Test_OpenAPIDocument_Generate;
var
  Doc: TOpenAPIDocument;
begin
  Doc := TOpenAPIDocument.Create;
  try
    Doc.Info.Title := 'My API';
    Doc.Info.Version := '1.0.0';

    Assert.IsNotNull(Doc);
    Assert.AreEqual('My API', Doc.Info.Title);
  finally
    Doc.Free;
  end;
end;

procedure TOpenAPITests.Test_OpenAPIDocument_ToJSON;
var
  Doc: TOpenAPIDocument;
  JSON: TJSONObject;
begin
  Doc := TOpenAPIDocument.Create;
  try
    Doc.Info.Title := 'Test API';
    Doc.Info.Version := '1.0.0';

    JSON := Doc.ToJSON;
    try
      Assert.IsNotNull(JSON);
      Assert.IsTrue(Pos('openapi', JSON.ToString) > 0);
      Assert.IsTrue(Pos('Test API', JSON.ToString) > 0);
    finally
      JSON.Free;
    end;
  finally
    Doc.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THttpConstantsTests);
  TDUnitX.RegisterTestFixture(TApiRouterTests);
  TDUnitX.RegisterTestFixture(TApiRequestTests);
  TDUnitX.RegisterTestFixture(TApiResponseTests);
  TDUnitX.RegisterTestFixture(TAuthMiddlewareExampleTests);
  TDUnitX.RegisterTestFixture(TWebSocketTests);
  TDUnitX.RegisterTestFixture(TOpenAPITests);

end.
