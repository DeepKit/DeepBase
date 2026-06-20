unit Test.DeepBase.Net;

{*******************************************************************************
  Unit Tests for DeepBase.Net
  Tests HTTP client, DNS resolver, IP utilities and network functions
*******************************************************************************}

interface
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestDeepBaseNet = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // THttpResponse Tests
    [Test]
    procedure TestHttpResponseIsSuccess;
    [Test]
    procedure TestHttpResponseIsRedirect;
    [Test]
    procedure TestHttpResponseIsClientError;
    [Test]
    procedure TestHttpResponseIsServerError;

    // THttpRequest Tests
    [Test]
    procedure TestHttpRequestCreate;
    [Test]
    procedure TestHttpRequestHeaders;
    [Test]
    procedure TestHttpRequestQueryParams;
    [Test]
    procedure TestHttpRequestBasicAuth;
    [Test]
    procedure TestHttpRequestBearerToken;

    // THttpClient_ Tests
    [Test]
    procedure TestHttpClientCreate;
    [Test]
    procedure TestHttpClientDefaultHeaders;
    [Test]
    procedure TestHttpClientRequest;

    // TWebSocketClient Tests
    [Test]
    procedure TestWebSocketCreate;
    [Test]
    procedure TestWebSocketState;

    // TDnsRecord Tests
    [Test]
    procedure TestDnsRecordToString;

    // TDnsResolver_ Tests
    [Test]
    procedure TestDnsResolverCreate;

    // TIPv4Address Tests
    [Test]
    procedure TestIPv4Parse;
    [Test]
    procedure TestIPv4ToString;
    [Test]
    procedure TestIPv4ToInteger;
    [Test]
    procedure TestIPv4IsPrivate;
    [Test]
    procedure TestIPv4IsLoopback;
    [Test]
    procedure TestIPv4IsMulticast;
    [Test]
    procedure TestIPv4Operators;

    // TIPv4Subnet Tests
    [Test]
    procedure TestIPv4SubnetParse;
    [Test]
    procedure TestIPv4SubnetContains;
    [Test]
    procedure TestIPv4SubnetBroadcast;
    [Test]
    procedure TestIPv4SubnetHostCount;

    // TNetworkUtils Tests
    [Test]
    procedure TestUrlEncode;
    [Test]
    procedure TestUrlDecode;
    [Test]
    procedure TestBuildUrl;
    [Test]
    procedure TestParseUrl;
    [Test]
    procedure TestJoinUrl;
    [Test]
    procedure TestIsValidIPv4;
    [Test]
    procedure TestIsValidHostname;
    [Test]
    procedure TestIsValidPort;
    [Test]
    procedure TestIsSafeUrl;
    [Test]
    procedure TestGetServiceName;
    [Test]
    procedure TestGetServicePort;

    // TIPUtils Tests
    [Test]
    procedure TestIPv4ToInteger2;
    [Test]
    procedure TestIntegerToIPv4;
    [Test]
    procedure TestIsInSubnet;
    [Test]
    procedure TestIsPrivateIP;
    [Test]
    procedure TestIsLoopbackIP;
    [Test]
    procedure TestCompareIPv4;
  end;
implementation
uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.Net;

procedure TTestDeepBaseNet.Setup;
begin
end;

procedure TTestDeepBaseNet.TearDown;
begin
end;

// THttpResponse Tests

procedure TTestDeepBaseNet.TestHttpResponseIsSuccess;
var
  Response: THttpResponse;
begin
  Response.StatusCode := 200;
  Assert.IsTrue(Response.IsSuccess);

  Response.StatusCode := 201;
  Assert.IsTrue(Response.IsSuccess);

  Response.StatusCode := 204;
  Assert.IsTrue(Response.IsSuccess);

  Response.StatusCode := 400;
  Assert.IsFalse(Response.IsSuccess);
end;

procedure TTestDeepBaseNet.TestHttpResponseIsRedirect;
var
  Response: THttpResponse;
begin
  Response.StatusCode := 301;
  Assert.IsTrue(Response.IsRedirect);

  Response.StatusCode := 302;
  Assert.IsTrue(Response.IsRedirect);

  Response.StatusCode := 200;
  Assert.IsFalse(Response.IsRedirect);
end;

procedure TTestDeepBaseNet.TestHttpResponseIsClientError;
var
  Response: THttpResponse;
begin
  Response.StatusCode := 400;
  Assert.IsTrue(Response.IsClientError);

  Response.StatusCode := 404;
  Assert.IsTrue(Response.IsClientError);

  Response.StatusCode := 200;
  Assert.IsFalse(Response.IsClientError);
end;

procedure TTestDeepBaseNet.TestHttpResponseIsServerError;
var
  Response: THttpResponse;
begin
  Response.StatusCode := 500;
  Assert.IsTrue(Response.IsServerError);

  Response.StatusCode := 503;
  Assert.IsTrue(Response.IsServerError);

  Response.StatusCode := 200;
  Assert.IsFalse(Response.IsServerError);
end;

// THttpRequest Tests

procedure TTestDeepBaseNet.TestHttpRequestCreate;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create('https://example.com/api');
  try
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpRequestHeaders;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create('https://example.com');
  try
    Request.Header('X-Custom', 'Value1');
    Request.Header('Accept', 'application/json');
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpRequestQueryParams;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create('https://example.com');
  try
    Request.QueryParam('page', '1');
    Request.QueryParam('limit', '10');
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpRequestBasicAuth;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create('https://example.com');
  try
    Request.BasicAuth('user', 'pass');
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpRequestBearerToken;
var
  Request: THttpRequest;
begin
  Request := THttpRequest.Create('https://example.com');
  try
    Request.BearerToken('my-token-123');
    Assert.IsNotNull(Request);
  finally
    Request.Free;
  end;
end;

// THttpClient_ Tests

procedure TTestDeepBaseNet.TestHttpClientCreate;
var
  Client: THttpClient_;
begin
  Client := THttpClient_.Create('https://api.example.com');
  try
    Assert.AreEqual('https://api.example.com', Client.BaseUrl);
  finally
    Client.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpClientDefaultHeaders;
var
  Client: THttpClient_;
begin
  Client := THttpClient_.Create;
  try
    Client.SetDefaultHeader('Authorization', 'Bearer token');
    Client.SetDefaultHeader('Accept', 'application/json');
    Assert.IsNotNull(Client);
  finally
    Client.Free;
  end;
end;

procedure TTestDeepBaseNet.TestHttpClientRequest;
var
  Client: THttpClient_;
  Request: THttpRequest;
begin
  Client := THttpClient_.Create('https://api.example.com');
  try
    Request := Client.Request('/users');
    Assert.IsNotNull(Request);
    Request.Free;
  finally
    Client.Free;
  end;
end;

// TWebSocketClient Tests

procedure TTestDeepBaseNet.TestWebSocketCreate;
var
  WS: TWebSocketClient;
begin
  WS := TWebSocketClient.Create('ws://localhost:8080');
  try
    Assert.AreEqual('ws://localhost:8080', WS.Url);
  finally
    WS.Free;
  end;
end;

procedure TTestDeepBaseNet.TestWebSocketState;
var
  WS: TWebSocketClient;
begin
  WS := TWebSocketClient.Create('ws://localhost:8080');
  try
    Assert.AreEqual(wssClosed, WS.State);
  finally
    WS.Free;
  end;
end;

// TDnsRecord Tests

procedure TTestDeepBaseNet.TestDnsRecordToString;
var
  Rec: TDnsRecord;
begin
  Rec.RecordType := drtA;
  Rec.Name := 'example.com';
  Rec.Value := '93.184.216.34';
  Rec.TTL := 3600;
  Assert.IsTrue(Length(Rec.ToString) > 0);
end;

// TDnsResolver_ Tests

procedure TTestDeepBaseNet.TestDnsResolverCreate;
var
  Resolver: TDnsResolver_;
begin
  Resolver := TDnsResolver_.Create('8.8.8.8');
  try
    Assert.IsNotNull(Resolver);
  finally
    Resolver.Free;
  end;
end;

// TIPv4Address Tests

procedure TTestDeepBaseNet.TestIPv4Parse;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('192.168.1.1');
  Assert.AreEqual('192.168.1.1', IP.ToString);
end;

procedure TTestDeepBaseNet.TestIPv4ToString;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('10.0.0.1');
  Assert.AreEqual('10.0.0.1', IP.ToString);
end;

procedure TTestDeepBaseNet.TestIPv4ToInteger;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('0.0.0.1');
  Assert.AreEqual(Cardinal(1), IP.ToInteger);

  IP := TIPv4Address.Parse('0.0.1.0');
  Assert.AreEqual(Cardinal(256), IP.ToInteger);
end;

procedure TTestDeepBaseNet.TestIPv4IsPrivate;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('192.168.1.1');
  Assert.IsTrue(IP.IsPrivate);

  IP := TIPv4Address.Parse('10.0.0.1');
  Assert.IsTrue(IP.IsPrivate);

  IP := TIPv4Address.Parse('172.16.0.1');
  Assert.IsTrue(IP.IsPrivate);

  IP := TIPv4Address.Parse('8.8.8.8');
  Assert.IsFalse(IP.IsPrivate);
end;

procedure TTestDeepBaseNet.TestIPv4IsLoopback;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('127.0.0.1');
  Assert.IsTrue(IP.IsLoopback);

  IP := TIPv4Address.Parse('127.255.255.255');
  Assert.IsTrue(IP.IsLoopback);

  IP := TIPv4Address.Parse('192.168.1.1');
  Assert.IsFalse(IP.IsLoopback);
end;

procedure TTestDeepBaseNet.TestIPv4IsMulticast;
var
  IP: TIPv4Address;
begin
  IP := TIPv4Address.Parse('224.0.0.1');
  Assert.IsTrue(IP.IsMulticast);

  IP := TIPv4Address.Parse('239.255.255.255');
  Assert.IsTrue(IP.IsMulticast);

  IP := TIPv4Address.Parse('192.168.1.1');
  Assert.IsFalse(IP.IsMulticast);
end;

procedure TTestDeepBaseNet.TestIPv4Operators;
var
  IP1, IP2: TIPv4Address;
begin
  IP1 := TIPv4Address.Parse('192.168.1.1');
  IP2 := TIPv4Address.Parse('192.168.1.1');
  Assert.IsTrue(IP1 = IP2);

  IP2 := TIPv4Address.Parse('192.168.1.2');
  Assert.IsTrue(IP1 <> IP2);
end;

// TIPv4Subnet Tests

procedure TTestDeepBaseNet.TestIPv4SubnetParse;
var
  Subnet: TIPv4Subnet;
begin
  Subnet := TIPv4Subnet.Parse('192.168.1.0/24');
  Assert.AreEqual(24, Subnet.PrefixLength);
end;

procedure TTestDeepBaseNet.TestIPv4SubnetContains;
var
  Subnet: TIPv4Subnet;
  IP: TIPv4Address;
begin
  Subnet := TIPv4Subnet.Parse('192.168.1.0/24');

  IP := TIPv4Address.Parse('192.168.1.1');
  Assert.IsTrue(Subnet.Contains(IP));

  IP := TIPv4Address.Parse('192.168.1.254');
  Assert.IsTrue(Subnet.Contains(IP));

  IP := TIPv4Address.Parse('192.168.2.1');
  Assert.IsFalse(Subnet.Contains(IP));
end;

procedure TTestDeepBaseNet.TestIPv4SubnetBroadcast;
var
  Subnet: TIPv4Subnet;
begin
  Subnet := TIPv4Subnet.Parse('192.168.1.0/24');
  Assert.AreEqual('192.168.1.255', Subnet.GetBroadcast.ToString);
end;

procedure TTestDeepBaseNet.TestIPv4SubnetHostCount;
var
  Subnet: TIPv4Subnet;
begin
  Subnet := TIPv4Subnet.Parse('192.168.1.0/24');
  Assert.AreEqual(Cardinal(254), Subnet.GetHostCount);

  Subnet := TIPv4Subnet.Parse('10.0.0.0/8');
  Assert.AreEqual(Cardinal(16777214), Subnet.GetHostCount);
end;

// TNetworkUtils Tests

procedure TTestDeepBaseNet.TestUrlEncode;
begin
  Assert.AreEqual('hello+world', TNetworkUtils.UrlEncode('hello world'));
  Assert.AreEqual('test%26value', TNetworkUtils.UrlEncode('test&value'));
  Assert.AreEqual('abc123', TNetworkUtils.UrlEncode('abc123'));
end;

procedure TTestDeepBaseNet.TestUrlDecode;
begin
  Assert.AreEqual('hello world', TNetworkUtils.UrlDecode('hello%20world'));
  Assert.AreEqual('test&value', TNetworkUtils.UrlDecode('test%26value'));
  Assert.AreEqual('abc123', TNetworkUtils.UrlDecode('abc123'));
end;

procedure TTestDeepBaseNet.TestBuildUrl;
begin
  Assert.IsTrue(TNetworkUtils.BuildUrl('https://api.example.com/users',
    [TPair<string, string>.Create('page', '1'),
     TPair<string, string>.Create('limit', '10')]).Contains('page=1'));
end;

procedure TTestDeepBaseNet.TestParseUrl;
var
  Scheme, Host, Path: string;
  Port: Integer;
begin
  TNetworkUtils.ParseUrl('https://example.com:8080/api/users', Scheme, Host, Path, Port);
  Assert.AreEqual('https', Scheme);
  Assert.AreEqual('example.com', Host);
  Assert.AreEqual('/api/users', Path);
  Assert.AreEqual(8080, Port);
end;

procedure TTestDeepBaseNet.TestJoinUrl;
begin
  Assert.AreEqual('https://example.com/api/users',
    TNetworkUtils.JoinUrl('https://example.com', 'api/users'));
  Assert.AreEqual('https://example.com/api/users',
    TNetworkUtils.JoinUrl('https://example.com/', '/api/users'));
end;

procedure TTestDeepBaseNet.TestIsValidIPv4;
begin
  Assert.IsTrue(TNetworkUtils.IsValidIPv4('192.168.1.1'));
  Assert.IsTrue(TNetworkUtils.IsValidIPv4('0.0.0.0'));
  Assert.IsTrue(TNetworkUtils.IsValidIPv4('255.255.255.255'));
  Assert.IsFalse(TNetworkUtils.IsValidIPv4('256.1.1.1'));
  Assert.IsFalse(TNetworkUtils.IsValidIPv4('1.1.1'));
  Assert.IsFalse(TNetworkUtils.IsValidIPv4('invalid'));
end;

procedure TTestDeepBaseNet.TestIsValidHostname;
begin
  Assert.IsTrue(TNetworkUtils.IsValidHostname('example.com'));
  Assert.IsTrue(TNetworkUtils.IsValidHostname('sub.example.com'));
  Assert.IsTrue(TNetworkUtils.IsValidHostname('localhost'));
  Assert.IsFalse(TNetworkUtils.IsValidHostname('-invalid.com'));
  Assert.IsFalse(TNetworkUtils.IsValidHostname(''));
end;

procedure TTestDeepBaseNet.TestIsValidPort;
begin
  Assert.IsTrue(TNetworkUtils.IsValidPort(80));
  Assert.IsTrue(TNetworkUtils.IsValidPort(443));
  Assert.IsTrue(TNetworkUtils.IsValidPort(1));
  Assert.IsTrue(TNetworkUtils.IsValidPort(65535));
  Assert.IsFalse(TNetworkUtils.IsValidPort(0));
  Assert.IsFalse(TNetworkUtils.IsValidPort(65536));
  Assert.IsFalse(TNetworkUtils.IsValidPort(-1));
end;

procedure TTestDeepBaseNet.TestIsSafeUrl;
begin
  Assert.IsTrue(TNetworkUtils.IsSafeUrl('https://example.com/api'));
  Assert.IsFalse(TNetworkUtils.IsSafeUrl('ftp://example.com/resource'));
  Assert.IsFalse(TNetworkUtils.IsSafeUrl('http://169.254.169.254/latest/meta-data'));
end;

procedure TTestDeepBaseNet.TestGetServiceName;
begin
  Assert.AreEqual('http', TNetworkUtils.GetServiceName(80));
  Assert.AreEqual('https', TNetworkUtils.GetServiceName(443));
  Assert.AreEqual('ftp', TNetworkUtils.GetServiceName(21));
  Assert.AreEqual('ssh', TNetworkUtils.GetServiceName(22));
end;

procedure TTestDeepBaseNet.TestGetServicePort;
begin
  Assert.AreEqual(80, TNetworkUtils.GetServicePort('http'));
  Assert.AreEqual(443, TNetworkUtils.GetServicePort('https'));
  Assert.AreEqual(21, TNetworkUtils.GetServicePort('ftp'));
  Assert.AreEqual(22, TNetworkUtils.GetServicePort('ssh'));
end;

// TIPUtils Tests

procedure TTestDeepBaseNet.TestIPv4ToInteger2;
begin
  Assert.AreEqual(Cardinal(1), TIPUtils.IPv4ToInteger('0.0.0.1'));
  Assert.AreEqual(Cardinal($C0A80101), TIPUtils.IPv4ToInteger('192.168.1.1'));
end;

procedure TTestDeepBaseNet.TestIntegerToIPv4;
begin
  Assert.AreEqual('0.0.0.1', TIPUtils.IntegerToIPv4(1));
  Assert.AreEqual('192.168.1.1', TIPUtils.IntegerToIPv4(Cardinal($C0A80101)));
end;

procedure TTestDeepBaseNet.TestIsInSubnet;
begin
  Assert.IsTrue(TIPUtils.IsInSubnet('192.168.1.100', '192.168.1.0', 24));
  Assert.IsFalse(TIPUtils.IsInSubnet('192.168.2.100', '192.168.1.0', 24));
end;

procedure TTestDeepBaseNet.TestIsPrivateIP;
begin
  Assert.IsTrue(TIPUtils.IsPrivateIP('192.168.1.1'));
  Assert.IsTrue(TIPUtils.IsPrivateIP('10.0.0.1'));
  Assert.IsTrue(TIPUtils.IsPrivateIP('172.16.0.1'));
  Assert.IsFalse(TIPUtils.IsPrivateIP('8.8.8.8'));
end;

procedure TTestDeepBaseNet.TestIsLoopbackIP;
begin
  Assert.IsTrue(TIPUtils.IsLoopbackIP('127.0.0.1'));
  Assert.IsTrue(TIPUtils.IsLoopbackIP('127.255.255.255'));
  Assert.IsFalse(TIPUtils.IsLoopbackIP('192.168.1.1'));
end;

procedure TTestDeepBaseNet.TestCompareIPv4;
begin
  Assert.AreEqual(0, TIPUtils.CompareIPv4('192.168.1.1', '192.168.1.1'));
  Assert.IsTrue(TIPUtils.CompareIPv4('192.168.1.1', '192.168.1.2') < 0);
  Assert.IsTrue(TIPUtils.CompareIPv4('192.168.1.2', '192.168.1.1') > 0);
end;
initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseNet);
end.
