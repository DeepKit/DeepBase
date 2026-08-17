{ ============================================================================
  Test.DeepBase.Config.Upload - RFC 8785 canonical JSON and config upload tests
  ============================================================================ }
unit Test.DeepBase.Config.Upload;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.Net.URLClient,
  DeepBase.Net.Transport,
  DeepBase.Config.Upload;

type
  TFakeConfigTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  private
    FResponses: TQueue<TDeepBaseHttpTransportResponse>;
    FRequests: TList<TDeepBaseHttpTransportRequest>;
    FExceptionsRemaining: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Enqueue(AStatusCode: Integer; const ABody: string;
      const ARetryAfter: string = '');
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
    property ExceptionsRemaining: Integer read FExceptionsRemaining
      write FExceptionsRemaining;
    property Requests: TList<TDeepBaseHttpTransportRequest> read FRequests;
  end;

  [TestFixture]
  TConfigUploadTests = class
  private
    FTransport: TFakeConfigTransport;
    FTransportIntf: IDeepBaseHttpTransport;
    FUploader: TConfigUploader;
    FSleeps: TList<Cardinal>;
    function NewConfig: TJSONObject;
    function HeaderValue(const AHeaders: TNetHeaders;
      const AName: string): string;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [Test] procedure Canonicalize_SortsKeysAndEscapes;
    [Test] procedure Canonicalize_Rfc8785NumberVector;
    [Test] procedure Canonicalize_RejectsInvalidUnicode;
    [Test] procedure Sha256_KnownVector;
    [Test] procedure Upload_UsesCanonicalBodyAndStableIdempotencyKey;
    [Test] procedure Upload_Retries429AndHonorsRetryAfter;
    [Test] procedure Upload_RetriesNetworkFailureWithSameKey;
    [Test] procedure Upload_409RaisesConflictWithExistingHash;
    [Test] procedure Upload_RejectsInsecureRemoteHttp;
  end;

implementation

{ TFakeConfigTransport }

constructor TFakeConfigTransport.Create;
begin
  inherited;
  FResponses := TQueue<TDeepBaseHttpTransportResponse>.Create;
  FRequests := TList<TDeepBaseHttpTransportRequest>.Create;
end;

destructor TFakeConfigTransport.Destroy;
begin
  FRequests.Free;
  FResponses.Free;
  inherited;
end;

procedure TFakeConfigTransport.Enqueue(AStatusCode: Integer; const ABody,
  ARetryAfter: string);
var
  Response: TDeepBaseHttpTransportResponse;
begin
  Response := Default(TDeepBaseHttpTransportResponse);
  Response.StatusCode := AStatusCode;
  Response.Body := ABody;
  if ARetryAfter <> '' then
  begin
    SetLength(Response.Headers, 1);
    Response.Headers[0] := TNameValuePair.Create('Retry-After', ARetryAfter);
  end;
  FResponses.Enqueue(Response);
end;

function TFakeConfigTransport.Send(const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  FRequests.Add(ARequest);
  if FExceptionsRemaining > 0 then
  begin
    Dec(FExceptionsRemaining);
    raise EDeepBaseNetTransportError.Create('simulated timeout');
  end;
  if FResponses.Count = 0 then
    raise EDeepBaseNetTransportError.Create('missing fake response');
  Result := FResponses.Dequeue;
end;

{ TConfigUploadTests }

procedure TConfigUploadTests.Setup;
begin
  FSleeps := TList<Cardinal>.Create;
  FTransport := TFakeConfigTransport.Create;
  FTransportIntf := FTransport;
  FUploader := TConfigUploader.Create('https://deepkit.test', 'secret-key',
    FTransportIntf);
  FUploader.SleepProc :=
    procedure(AMilliseconds: Cardinal)
    begin
      FSleeps.Add(AMilliseconds);
    end;
end;

procedure TConfigUploadTests.TearDown;
begin
  FUploader.Free;
  FTransportIntf := nil;
  FTransport := nil;
  FSleeps.Free;
end;

function TConfigUploadTests.NewConfig: TJSONObject;
var
  Selectors: TJSONObject;
  Actions: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('url', 'https://example.test');
  Selectors := TJSONObject.Create;
  Selectors.AddPair('submit', '#send');
  Result.AddPair('selectors', Selectors);
  Actions := TJSONArray.Create;
  Actions.Add('click');
  Result.AddPair('actions', Actions);
  Result.AddPair('engine', 'webview2');
end;

function TConfigUploadTests.HeaderValue(const AHeaders: TNetHeaders;
  const AName: string): string;
var
  Header: TNameValuePair;
begin
  Result := '';
  for Header in AHeaders do
    if SameText(Header.Name, AName) then Exit(Header.Value);
end;

procedure TConfigUploadTests.Canonicalize_SortsKeysAndEscapes;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('z', 'line'#10'quote"slash\');
    Obj.AddPair('a', TJSONNumber.Create(1));
    Assert.AreEqual('{"a":1,"z":"line\nquote\"slash\\"}',
      TJsonCanonicalizer.Canonicalize(Obj));
  finally
    Obj.Free;
  end;
end;

procedure TConfigUploadTests.Canonicalize_Rfc8785NumberVector;
var
  Arr: TJSONArray;
begin
  Arr := TJSONArray.Create;
  try
    Arr.AddElement(TJSONNumber.Create(333333333.33333329));
    Arr.AddElement(TJSONNumber.Create(1E30));
    Arr.AddElement(TJSONNumber.Create(4.50));
    Arr.AddElement(TJSONNumber.Create(2E-3));
    Arr.AddElement(TJSONNumber.Create(0.000000000000000000000000001));
    Assert.AreEqual('[1e+30,4.5,0.002,1e-27]',
      TJsonCanonicalizer.Canonicalize(Arr));
  finally
    Arr.Free;
  end;
end;

procedure TConfigUploadTests.Canonicalize_RejectsInvalidUnicode;
var
  Obj: TJSONObject;
  Invalid: string;
begin
  Invalid := Char($D800);
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('bad', Invalid);
    Assert.WillRaise(
      procedure begin TJsonCanonicalizer.Canonicalize(Obj); end,
      EArgumentException);
  finally
    Obj.Free;
  end;
end;

procedure TConfigUploadTests.Sha256_KnownVector;
var
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('b', TJSONNumber.Create(2));
    Obj.AddPair('a', TJSONNumber.Create(1));
    Assert.AreEqual('43258cff783fe7036d8a43033f830adfc60ec037382473548ac742b888292777',
      TJsonCanonicalizer.Sha256(Obj));
  finally
    Obj.Free;
  end;
end;

procedure TConfigUploadTests.Upload_UsesCanonicalBodyAndStableIdempotencyKey;
var
  Config: TJSONObject;
  UploadResult: TConfigUploadResult;
  Request: TDeepBaseHttpTransportRequest;
begin
  FTransport.Enqueue(201,
    '{"id":7,"provider_key":"demo","version":"2026.08.12","published":true,"idempotent":false}');
  Config := NewConfig;
  try
    Assert.IsTrue(FUploader.Upload('demo', '2026.08.12', Config, 'note', True,
      UploadResult, 'fixed-key'));
  finally
    Config.Free;
  end;
  Assert.AreEqual<Integer>(1, FTransport.Requests.Count);
  Request := FTransport.Requests[0];
  Assert.AreEqual('https://deepkit.test/dk/providers/configs', Request.Url);
  Assert.AreEqual('Bearer secret-key', HeaderValue(Request.Headers, 'Authorization'));
  Assert.AreEqual('fixed-key', HeaderValue(Request.Headers, 'Idempotency-Key'));
  Assert.IsTrue(Request.Body.Contains('"config_json":{"actions":["click"],"engine":"webview2","selectors":{"submit":"#send"},"url":"https://example.test"}'));
  Assert.AreEqual('demo', UploadResult.ProviderKey);
  Assert.AreEqual(Int64(7), UploadResult.ProviderId);
end;

procedure TConfigUploadTests.Upload_Retries429AndHonorsRetryAfter;
var
  Config: TJSONObject;
  UploadResult: TConfigUploadResult;
begin
  FTransport.Enqueue(429, '{"error":"rate limited"}', '1');
  FTransport.Enqueue(201,
    '{"id":8,"provider_key":"demo","version":"2026.08.12","published":false,"idempotent":false}');
  Config := NewConfig;
  try
    Assert.IsTrue(FUploader.Upload('demo', '2026.08.12', Config, '', False,
      UploadResult, 'retry-key'));
  finally
    Config.Free;
  end;
  Assert.AreEqual<Integer>(2, FTransport.Requests.Count);
  Assert.AreEqual<Integer>(1, FSleeps.Count);
  Assert.AreEqual(Cardinal(1000), FSleeps[0]);
  Assert.AreEqual('retry-key', HeaderValue(FTransport.Requests[0].Headers, 'Idempotency-Key'));
  Assert.AreEqual('retry-key', HeaderValue(FTransport.Requests[1].Headers, 'Idempotency-Key'));
end;

procedure TConfigUploadTests.Upload_RetriesNetworkFailureWithSameKey;
var
  Config: TJSONObject;
  UploadResult: TConfigUploadResult;
begin
  FTransport.ExceptionsRemaining := 1;
  FTransport.Enqueue(201,
    '{"id":9,"provider_key":"demo","version":"2026.08.12","published":false,"idempotent":false}');
  Config := NewConfig;
  try
    Assert.IsTrue(FUploader.Upload('demo', '2026.08.12', Config, '', False,
      UploadResult, 'network-key'));
  finally
    Config.Free;
  end;
  Assert.AreEqual<Integer>(2, FTransport.Requests.Count);
  Assert.AreEqual(Cardinal(2000), FSleeps[0]);
  Assert.AreEqual('network-key', HeaderValue(FTransport.Requests[1].Headers,
    'Idempotency-Key'));
end;

procedure TConfigUploadTests.Upload_409RaisesConflictWithExistingHash;
var
  Config: TJSONObject;
begin
  FTransport.Enqueue(409, '{"existing_sha256":"abc123"}');
  Config := NewConfig;
  try
    Assert.WillRaiseWithMessage(
      procedure
      var R: TConfigUploadResult;
      begin
        FUploader.Upload('demo', '2026.08.12', Config, '', False, R, 'conflict-key');
      end,
      EConfigUploadError);
  finally
    Config.Free;
  end;
end;

procedure TConfigUploadTests.Upload_RejectsInsecureRemoteHttp;
begin
  Assert.WillRaise(
    procedure
    var U: TConfigUploader;
    begin
      U := TConfigUploader.Create('http://deepkit.test', 'key', FTransportIntf);
      U.Free;
    end,
    EArgumentException);
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigUploadTests);

end.



