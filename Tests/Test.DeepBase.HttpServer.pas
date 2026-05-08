unit Test.DeepBase.HttpServer;

{*******************************************************************************
  Unit Tests for DeepBase.HttpServer
  Tests HTTP server, routing, middleware and request/response handling
*******************************************************************************}

interface

{$IFDEF TESTDeepInsight}
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestDeepBaseHttpServer = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // THttpResponse Tests
    [Test]
    procedure TestHttpResponseCreate;
    [Test]
    procedure TestHttpResponseStatus;
    [Test]
    procedure TestHttpResponseHeaders;
    [Test]
    procedure TestHttpResponseJSON;
    [Test]
    procedure TestHttpResponseText;
    [Test]
    procedure TestHttpResponseBytes;

    // THttpRequest Tests
    [Test]
    procedure TestHttpRequestParseQuery;
    [Test]
    procedure TestHttpRequestParseHeaders;
    [Test]
    procedure TestHttpRequestParseBody;

    // TRoute Tests
    [Test]
    procedure TestRouteCreate;
    [Test]
    procedure TestRouteMatch;
    [Test]
    procedure TestRouteMatchWithParams;
    [Test]
    procedure TestRouteMatchWildcard;

    // TRouter Tests
    [Test]
    procedure TestRouterCreate;
    [Test]
    procedure TestRouterGet;
    [Test]
    procedure TestRouterPost;
    [Test]
    procedure TestRouterPut;
    [Test]
    procedure TestRouterDelete;
    [Test]
    procedure TestRouterAny;
    [Test]
    procedure TestRouterGroup;

    // THttpServer Tests
    [Test]
    procedure TestHttpServerCreate;
    [Test]
    procedure TestHttpServerConfigure;
    [Test]
    procedure TestHttpServerRoutes;

    // Middleware Tests
    [Test]
    procedure TestLoggingMiddleware;
    [Test]
    procedure TestCorsMiddleware;
    [Test]
    procedure TestBasicAuthMiddleware;
    [Test]
    procedure TestStaticFileMiddleware;

    // Path Params Tests
    [Test]
    procedure TestPathParamSingle;
    [Test]
    procedure TestPathParamMultiple;
    [Test]
    procedure TestPathParamOptional;

    // Content Type Tests
    [Test]
    procedure TestContentTypeJSON;
    [Test]
    procedure TestContentTypeHTML;
    [Test]
    procedure TestContentTypePlain;
  end;
{$ENDIF}

implementation

{$IFDEF TESTDeepInsight}
uses
  System.SysUtils, System.Classes, System.JSON,
  DeepBase.HttpServer;

procedure TTestDeepBaseHttpServer.Setup;
begin
end;

procedure TTestDeepBaseHttpServer.TearDown;
begin
end;

// THttpResponse Tests

procedure TTestDeepBaseHttpServer.TestHttpResponseCreate;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Assert.AreEqual(200, Response.StatusCode);
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpResponseStatus;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.Status(404, 'Not Found');
    Assert.AreEqual(404, Response.StatusCode);
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpResponseHeaders;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.Header('X-Custom', 'Value');
    Response.Header('Content-Type', 'application/json');
    Assert.IsNotNull(Response);
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpResponseJSON;
var
  Response: THttpResponse;
  JSON: TJSONObject;
begin
  Response := THttpResponse.Create;
  try
    JSON := TJSONObject.Create;
    try
      JSON.AddPair('status', 'ok');
      Response.JSON(JSON);
      Assert.IsTrue(Response.Body.Contains('ok'));
    finally
      JSON.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpResponseText;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.Text('Hello World');
    Assert.AreEqual('Hello World', Response.Body);
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpResponseBytes;
var
  Response: THttpResponse;
  Data: TBytes;
begin
  Response := THttpResponse.Create;
  try
    Data := TEncoding.UTF8.GetBytes('Binary Data');
    Response.Bytes(Data, 'application/octet-stream');
    Assert.IsTrue(Response.IsBinary);
  finally
    Response.Free;
  end;
end;

// THttpRequest Tests

procedure TTestDeepBaseHttpServer.TestHttpRequestParseQuery;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create;
  try
    Request.RawUri := '/api/users?page=1&limit=10';
    Request.ParseQueryString;
    Assert.AreEqual('1', Request.Query('page'));
    Assert.AreEqual('10', Request.Query('limit'));
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpRequestParseHeaders;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create;
  try
    Request.SetHeader('Content-Type', 'application/json');
    Request.SetHeader('Authorization', 'Bearer token123');
    Assert.AreEqual('application/json', Request.Header('Content-Type'));
    Assert.AreEqual('Bearer token123', Request.Header('Authorization'));
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpRequestParseBody;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create;
  try
    Request.Body := '{"name": "test"}';
    Assert.IsTrue(Request.Body.Contains('test'));
  finally
    Request.Free;
  end;
end;

// TRoute Tests

procedure TTestDeepBaseHttpServer.TestRouteCreate;
var
  Route: TRoute;
begin
  Route := TRoute.Create('/api/users', rmGet, nil);
  try
    Assert.AreEqual('/api/users', Route.Path);
    Assert.AreEqual(rmGet, Route.Method);
  finally
    Route.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouteMatch;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/api/users', rmGet, nil);
  try
    Assert.IsTrue(Route.Match('/api/users', Params));
    Assert.IsFalse(Route.Match('/api/posts', Params));
  finally
    Route.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouteMatchWithParams;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/api/users/:id', rmGet, nil);
  try
    Assert.IsTrue(Route.Match('/api/users/123', Params));
    Assert.AreEqual('123', Params['id']);

    Assert.IsTrue(Route.Match('/api/users/abc', Params));
    Assert.AreEqual('abc', Params['id']);
  finally
    Route.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouteMatchWildcard;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/static/*', rmGet, nil);
  try
    Assert.IsTrue(Route.Match('/static/css/style.css', Params));
    Assert.IsTrue(Route.Match('/static/js/app.js', Params));
  finally
    Route.Free;
  end;
end;

// TRouter Tests

procedure TTestDeepBaseHttpServer.TestRouterCreate;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Assert.IsNotNull(Router);
    Assert.AreEqual(0, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterGet;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Get('/users', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('Users list');
    end);
    Assert.AreEqual(1, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterPost;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Post('/users', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('User created');
    end);
    Assert.AreEqual(1, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterPut;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Put('/users/:id', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('User updated');
    end);
    Assert.AreEqual(1, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterDelete;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Delete('/users/:id', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('User deleted');
    end);
    Assert.AreEqual(1, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterAny;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Any('/health', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('OK');
    end);
    Assert.IsTrue(Router.RouteCount > 0);
  finally
    Router.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestRouterGroup;
var
  Router: TRouter;
begin
  Router := TRouter.Create;
  try
    Router.Group('/api/v1', procedure(R: TRouter)
    begin
      R.Get('/users', nil);
      R.Get('/posts', nil);
    end);
    Assert.AreEqual(2, Router.RouteCount);
  finally
    Router.Free;
  end;
end;

// THttpServer Tests

procedure TTestDeepBaseHttpServer.TestHttpServerCreate;
var
  Server: THttpServer;
begin
  Server := THttpServer.Create;
  try
    Assert.IsNotNull(Server);
    Assert.AreEqual(8080, Server.Port);
  finally
    Server.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpServerConfigure;
var
  Server: THttpServer;
begin
  Server := THttpServer.Create;
  try
    Server.Port := 3000;
    Server.Host := '0.0.0.0';
    Assert.AreEqual(3000, Server.Port);
    Assert.AreEqual('0.0.0.0', Server.Host);
  finally
    Server.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestHttpServerRoutes;
var
  Server: THttpServer;
begin
  Server := THttpServer.Create;
  try
    Server.Get('/test', procedure(Req: THttpRequest; Res: THttpResponse)
    begin
      Res.Text('Test');
    end);
    Assert.IsTrue(Server.RouteCount > 0);
  finally
    Server.Free;
  end;
end;

// Middleware Tests

procedure TTestDeepBaseHttpServer.TestLoggingMiddleware;
var
  Middleware: TLoggingMiddleware;
begin
  Middleware := TLoggingMiddleware.Create;
  try
    Assert.IsNotNull(Middleware);
  finally
    Middleware.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestCorsMiddleware;
var
  Middleware: TCorsMiddleware;
begin
  Middleware := TCorsMiddleware.Create;
  try
    Middleware.AllowOrigins := ['*'];
    Middleware.AllowMethods := ['GET', 'POST', 'PUT', 'DELETE'];
    Middleware.AllowHeaders := ['Content-Type', 'Authorization'];
    Assert.IsNotNull(Middleware);
  finally
    Middleware.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestBasicAuthMiddleware;
var
  Middleware: TBasicAuthMiddleware;
begin
  Middleware := TBasicAuthMiddleware.Create('admin', 'password');
  try
    Assert.IsNotNull(Middleware);
  finally
    Middleware.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestStaticFileMiddleware;
var
  Middleware: TStaticFileMiddleware;
begin
  Middleware := TStaticFileMiddleware.Create('/static', 'C:\www\static');
  try
    Assert.AreEqual('/static', Middleware.UrlPath);
  finally
    Middleware.Free;
  end;
end;

// Path Params Tests

procedure TTestDeepBaseHttpServer.TestPathParamSingle;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/users/:id', rmGet, nil);
  try
    Route.Match('/users/42', Params);
    Assert.AreEqual('42', Params['id']);
  finally
    Route.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestPathParamMultiple;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/users/:userId/posts/:postId', rmGet, nil);
  try
    Route.Match('/users/1/posts/2', Params);
    Assert.AreEqual('1', Params['userId']);
    Assert.AreEqual('2', Params['postId']);
  finally
    Route.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestPathParamOptional;
var
  Route: TRoute;
  Params: TRouteParams;
begin
  Route := TRoute.Create('/users/:id?', rmGet, nil);
  try
    Assert.IsTrue(Route.Match('/users/42', Params));
    Assert.IsTrue(Route.Match('/users', Params));
  finally
    Route.Free;
  end;
end;

// Content Type Tests

procedure TTestDeepBaseHttpServer.TestContentTypeJSON;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.ContentType := 'application/json';
    Assert.AreEqual('application/json', Response.ContentType);
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestContentTypeHTML;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.HTML('<html><body>Test</body></html>');
    Assert.IsTrue(Response.ContentType.Contains('text/html'));
  finally
    Response.Free;
  end;
end;

procedure TTestDeepBaseHttpServer.TestContentTypePlain;
var
  Response: THttpResponse;
begin
  Response := THttpResponse.Create;
  try
    Response.Text('Plain text');
    Assert.IsTrue(Response.ContentType.Contains('text/plain'));
  finally
    Response.Free;
  end;
end;

{$ENDIF}

end.
