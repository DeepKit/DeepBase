unit Test.DeepBase.Speech;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  System.Net.URLClient,
  DUnitX.TestFramework,
  DeepBase.Commerce.Backend.Http,
  DeepBase.Commerce.SafeClient,
  DeepBase.Commerce.Permissions,
  DeepBase.Net.Transport,
  DeepBase.Speech.ASR.Baidu,
  DeepBase.Speech.Service,
  DeepBase.Speech.Types,
  DeepBase.Speech.VAD;

type
  [TestFixture]
  TSpeechTests = class
  public
    [Test]
    procedure Test_PCM16ToFloat_AndDuration;

    [Test]
    procedure Test_VAD_StopsAfterSpeechThenSilence;

    [Test]
    procedure Test_BaiduRecognizer_RequestsTokenAndParsesResult;

    [Test]
    procedure Test_BaiduRecognizer_ReturnsServiceError;

    [Test]
    procedure Test_UnifiedTransport_BridgesSpeechRequestAndResponse;

    [Test]
    procedure Test_Service_StopAndRecognize_UsesCaptureAndRecognizer;

    [Test]
    procedure Test_Service_WithPermissionClient_ChecksAndConsumesQuota;
  end;

implementation

uses
  System.Math,
  System.StrUtils;

type
  TSpeechHttpRequest = record
    Method: string;
    Url: string;
    Body: string;
    Headers: TNetHeaders;
  end;

  TSpeechCommerceRequest = record
    Method: string;
    Url: string;
    Body: string;
    Headers: TNetHeaders;
  end;

  TFakeSpeechTransport = class(TInterfacedObject, ISpeechHttpTransport)
  private
    FRequests: TList<TSpeechHttpRequest>;
    FResponses: TQueue<TSpeechHttpResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string);
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TSpeechHttpRequest;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TSpeechHttpResponse;
  end;

  TFakeSpeechCommerceTransport = class(TInterfacedObject, ICommerceBackendHttpTransport)
  private
    FRequests: TList<TSpeechCommerceRequest>;
    FResponses: TQueue<TCommerceBackendHttpResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string);
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TSpeechCommerceRequest;
    function Send(const AMethod, AUrl, ABody: string;
      const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
  end;

  TFakeDeepBaseHttpTransport = class(TInterfacedObject, IDeepBaseHttpTransport)
  private
    FRequests: TList<TDeepBaseHttpTransportRequest>;
    FResponses: TQueue<TDeepBaseHttpTransportResponse>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure QueueResponse(AStatusCode: Integer; const ABody: string;
      const AStatusText: string = '');
    function RequestCount: Integer;
    function RequestAt(AIndex: Integer): TDeepBaseHttpTransportRequest;
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
  end;

  TFakeCapture = class(TInterfacedObject, ISpeechAudioCapture)
  private
    FAudio: TSpeechAudioData;
    FIsRecording: Boolean;
  public
    constructor Create(const AAudio: TSpeechAudioData);
    function StartRecording: Boolean;
    procedure StopRecording;
    function GetAudioData: TSpeechAudioData;
    function GetPCMData: TBytes;
    function GetFloatSamples: TArray<Single>;
    function IsRecording: Boolean;
    function LastError: string;
    function SampleRate: Integer;
  end;

  TFakeRecognizer = class(TInterfacedObject, ISpeechRecognizer)
  public
    LastAudio: TSpeechAudioData;
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
  end;

function HeaderValue(const AHeaders: TNetHeaders; const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AHeaders) do
    if SameText(AHeaders[I].Name, AName) then
      Exit(AHeaders[I].Value);
end;

function MakePcmBytes(AByteCount: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, AByteCount);
  for I := 0 to High(Result) do
    Result[I] := Byte(I mod 251);
end;

constructor TFakeSpeechCommerceTransport.Create;
begin
  inherited Create;
  FRequests := TList<TSpeechCommerceRequest>.Create;
  FResponses := TQueue<TCommerceBackendHttpResponse>.Create;
end;

destructor TFakeSpeechCommerceTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TFakeSpeechCommerceTransport.QueueResponse(AStatusCode: Integer;
  const ABody: string);
begin
  FResponses.Enqueue(TCommerceBackendHttpResponse.Create(AStatusCode, ABody));
end;

function TFakeSpeechCommerceTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TFakeSpeechCommerceTransport.RequestAt(
  AIndex: Integer): TSpeechCommerceRequest;
begin
  Result := FRequests[AIndex];
end;

function TFakeSpeechCommerceTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TCommerceBackendHttpResponse;
var
  Request: TSpeechCommerceRequest;
begin
  Request.Method := AMethod;
  Request.Url := AUrl;
  Request.Body := ABody;
  Request.Headers := AHeaders;
  FRequests.Add(Request);

  if FResponses.Count = 0 then
    Exit(TCommerceBackendHttpResponse.Create(500, '{"error":"missing fake response"}'));
  Result := FResponses.Dequeue;
end;

constructor TFakeSpeechTransport.Create;
begin
  inherited Create;
  FRequests := TList<TSpeechHttpRequest>.Create;
  FResponses := TQueue<TSpeechHttpResponse>.Create;
end;

destructor TFakeSpeechTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TFakeSpeechTransport.QueueResponse(AStatusCode: Integer;
  const ABody: string);
begin
  FResponses.Enqueue(TSpeechHttpResponse.Create(AStatusCode, ABody));
end;

function TFakeSpeechTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TFakeSpeechTransport.RequestAt(AIndex: Integer): TSpeechHttpRequest;
begin
  Result := FRequests[AIndex];
end;

function TFakeSpeechTransport.Send(const AMethod, AUrl, ABody: string;
  const AHeaders: TNetHeaders): TSpeechHttpResponse;
var
  Request: TSpeechHttpRequest;
begin
  Request.Method := AMethod;
  Request.Url := AUrl;
  Request.Body := ABody;
  Request.Headers := AHeaders;
  FRequests.Add(Request);

  if FResponses.Count = 0 then
    Exit(TSpeechHttpResponse.Create(500, '{"error":"missing fake response"}'));
  Result := FResponses.Dequeue;
end;

constructor TFakeDeepBaseHttpTransport.Create;
begin
  inherited Create;
  FRequests := TList<TDeepBaseHttpTransportRequest>.Create;
  FResponses := TQueue<TDeepBaseHttpTransportResponse>.Create;
end;

destructor TFakeDeepBaseHttpTransport.Destroy;
begin
  FResponses.Free;
  FRequests.Free;
  inherited;
end;

procedure TFakeDeepBaseHttpTransport.QueueResponse(AStatusCode: Integer;
  const ABody, AStatusText: string);
begin
  FResponses.Enqueue(TDeepBaseHttpTransportResponse.Create(AStatusCode, ABody,
    AStatusText));
end;

function TFakeDeepBaseHttpTransport.RequestCount: Integer;
begin
  Result := FRequests.Count;
end;

function TFakeDeepBaseHttpTransport.RequestAt(
  AIndex: Integer): TDeepBaseHttpTransportRequest;
begin
  Result := FRequests[AIndex];
end;

function TFakeDeepBaseHttpTransport.Send(
  const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
begin
  FRequests.Add(ARequest);
  if FResponses.Count = 0 then
    Exit(TDeepBaseHttpTransportResponse.Create(500,
      '{"error":"missing fake response"}', 'missing fake response'));
  Result := FResponses.Dequeue;
end;

constructor TFakeCapture.Create(const AAudio: TSpeechAudioData);
begin
  inherited Create;
  FAudio := AAudio;
  FIsRecording := False;
end;

function TFakeCapture.StartRecording: Boolean;
begin
  FIsRecording := True;
  Result := True;
end;

procedure TFakeCapture.StopRecording;
begin
  FIsRecording := False;
end;

function TFakeCapture.GetAudioData: TSpeechAudioData;
begin
  Result := FAudio;
end;

function TFakeCapture.GetPCMData: TBytes;
begin
  Result := Copy(FAudio.PCMData);
end;

function TFakeCapture.GetFloatSamples: TArray<Single>;
begin
  Result := TSpeechAudioUtils.PCM16ToFloat(FAudio.PCMData);
end;

function TFakeCapture.IsRecording: Boolean;
begin
  Result := FIsRecording;
end;

function TFakeCapture.LastError: string;
begin
  Result := '';
end;

function TFakeCapture.SampleRate: Integer;
begin
  Result := FAudio.Format.SampleRate;
end;

function TFakeRecognizer.CheckStatus(out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeRecognizer.Recognize(const AAudio: TSpeechAudioData;
  const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
begin
  LastAudio := AAudio;
  Result := TSpeechRecognitionResult.Succeeded('recognized text', '{"ok":true}');
end;

procedure TSpeechTests.Test_PCM16ToFloat_AndDuration;
var
  Audio: TSpeechAudioData;
  Floats: TArray<Single>;
  PCM: TBytes;
begin
  SetLength(PCM, 32000);
  PSmallInt(@PCM[0])^ := -32768;
  PSmallInt(@PCM[2])^ := 32767;

  Audio := TSpeechAudioData.FromPCM16(PCM, 16000);
  Floats := TSpeechAudioUtils.PCM16ToFloat(PCM);

  Assert.AreEqual(1000, Audio.DurationMs);
  Assert.IsTrue(Abs(Floats[0] + 1.0) < 0.0001);
  Assert.IsTrue(Abs(Floats[1] - (32767 / 32768)) < 0.0001);
end;

procedure TSpeechTests.Test_VAD_StopsAfterSpeechThenSilence;
var
  Frame: TArray<Single>;
  I: Integer;
  VAD: TDeepBaseSpeechVAD;
begin
  VAD := TDeepBaseSpeechVAD.Create(-40, 100, 16000, 0.2);
  try
    SetLength(Frame, VAD.FrameSize);
    for I := 0 to High(Frame) do
      Frame[I] := 0.1;
    Assert.IsFalse(VAD.ProcessFrame(@Frame[0], Length(Frame)));

    for I := 0 to High(Frame) do
      Frame[I] := 0;
    Assert.IsFalse(VAD.ProcessFrame(@Frame[0], Length(Frame)));
    Assert.IsTrue(VAD.ProcessFrame(@Frame[0], Length(Frame)));
  finally
    VAD.Free;
  end;
end;

procedure TSpeechTests.Test_BaiduRecognizer_RequestsTokenAndParsesResult;
var
  Audio: TSpeechAudioData;
  Recognizer: ISpeechRecognizer;
  Result: TSpeechRecognitionResult;
  Transport: TFakeSpeechTransport;
begin
  Transport := TFakeSpeechTransport.Create;
  Transport.QueueResponse(200, '{"access_token":"tok_001","expires_in":7200}');
  Transport.QueueResponse(200, '{"err_no":0,"result":["hello speech"]}');

  Recognizer := TDeepBaseBaiduSpeechRecognizer.Create(
    TSpeechBaiduConfig.Create('api_key', 'secret_key', 'unit-test-cuid'),
    Transport as ISpeechHttpTransport);
  Audio := TSpeechAudioData.FromPCM16(MakePcmBytes(4000), 16000);

  Result := Recognizer.Recognize(Audio, TSpeechRecognitionOptions.Default);

  Assert.IsTrue(Result.Success);
  Assert.AreEqual('hello speech', Result.Text);
  Assert.AreEqual(2, Transport.RequestCount);
  Assert.AreEqual('GET', Transport.RequestAt(0).Method);
  Assert.AreEqual('POST', Transport.RequestAt(1).Method);
  Assert.AreEqual('application/json',
    HeaderValue(Transport.RequestAt(1).Headers, 'Content-Type'));
  Assert.IsTrue(ContainsText(Transport.RequestAt(1).Body, '"token":"tok_001"'));
  Assert.IsTrue(ContainsText(Transport.RequestAt(1).Body, '"len":4000'));
  Assert.IsTrue(ContainsText(Transport.RequestAt(1).Body, '"pid":1537'));
end;

procedure TSpeechTests.Test_BaiduRecognizer_ReturnsServiceError;
var
  Audio: TSpeechAudioData;
  Recognizer: ISpeechRecognizer;
  Result: TSpeechRecognitionResult;
  Transport: TFakeSpeechTransport;
begin
  Transport := TFakeSpeechTransport.Create;
  Transport.QueueResponse(200, '{"access_token":"tok_001","expires_in":7200}');
  Transport.QueueResponse(200, '{"err_no":3301,"err_msg":"audio quality error"}');

  Recognizer := TDeepBaseBaiduSpeechRecognizer.Create(
    TSpeechBaiduConfig.Create('api_key', 'secret_key'),
    Transport as ISpeechHttpTransport);
  Audio := TSpeechAudioData.FromPCM16(MakePcmBytes(4000), 16000);

  Result := Recognizer.Recognize(Audio, TSpeechRecognitionOptions.Default);

  Assert.IsFalse(Result.Success);
  Assert.AreEqual(srsServiceError, Result.Status);
  Assert.AreEqual('3301', Result.ErrorCode);
end;

procedure TSpeechTests.Test_UnifiedTransport_BridgesSpeechRequestAndResponse;
var
  BaseTransport: TFakeDeepBaseHttpTransport;
  Headers: TNetHeaders;
  Request: TDeepBaseHttpTransportRequest;
  Response: TSpeechHttpResponse;
  Transport: ISpeechHttpTransport;
begin
  BaseTransport := TFakeDeepBaseHttpTransport.Create;
  BaseTransport.QueueResponse(200, '{"ok":true}', 'OK');
  Transport := TSpeechUnifiedHttpTransport.Create(
    BaseTransport as IDeepBaseHttpTransport, 12000);

  SetLength(Headers, 1);
  Headers[0] := TNetHeader.Create('Content-Type', 'application/json');

  Response := Transport.Send('POST', 'https://asr.example.test/recognize',
    '{"speech":"base64"}', Headers);

  Assert.AreEqual(200, Response.StatusCode);
  Assert.AreEqual('{"ok":true}', Response.Body);
  Assert.AreEqual('OK', Response.StatusText);
  Assert.AreEqual(1, BaseTransport.RequestCount);

  Request := BaseTransport.RequestAt(0);
  Assert.AreEqual(dbhmPost, Request.Method);
  Assert.AreEqual('https://asr.example.test/recognize', Request.Url);
  Assert.AreEqual('{"speech":"base64"}', Request.Body);
  Assert.AreEqual(12000, Request.TimeoutMs);
  Assert.AreEqual('application/json', Request.ContentType);
  Assert.AreEqual('application/json',
    HeaderValue(Request.Headers, 'Content-Type'));
end;

procedure TSpeechTests.Test_Service_StopAndRecognize_UsesCaptureAndRecognizer;
var
  Audio: TSpeechAudioData;
  Capture: ISpeechAudioCapture;
  RecognizerObj: TFakeRecognizer;
  Result: TSpeechRecognitionResult;
  Service: TDeepBaseSpeechService;
begin
  Audio := TSpeechAudioData.FromPCM16(MakePcmBytes(4000), 16000);
  Capture := TFakeCapture.Create(Audio);
  RecognizerObj := TFakeRecognizer.Create;
  Service := TDeepBaseSpeechService.Create(RecognizerObj as ISpeechRecognizer,
    Capture);
  try
    Assert.IsTrue(Service.StartRecording);
    Assert.IsTrue(Capture.IsRecording);

    Result := Service.StopAndRecognize;

    Assert.IsFalse(Capture.IsRecording);
    Assert.IsTrue(Result.Success);
    Assert.AreEqual('recognized text', Result.Text);
    Assert.AreEqual(Length(Audio.PCMData), Length(RecognizerObj.LastAudio.PCMData));
  finally
    Service.Free;
  end;
end;

procedure TSpeechTests.Test_Service_WithPermissionClient_ChecksAndConsumesQuota;
var
  Audio: TSpeechAudioData;
  Capture: ISpeechAudioCapture;
  RecognizerObj: TFakeRecognizer;
  Result: TSpeechRecognitionResult;
  Service: TDeepBaseSpeechService;
  CommerceTransport: TFakeSpeechCommerceTransport;
  SafeClient: TDeepKitSafeClient;
  Permissions: TDeepKitPermissionClient;
begin
  Audio := TSpeechAudioData.FromPCM16(MakePcmBytes(4000), 16000);
  Capture := TFakeCapture.Create(Audio);
  RecognizerObj := TFakeRecognizer.Create;

  CommerceTransport := TFakeSpeechCommerceTransport.Create;
  CommerceTransport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"speech.asr","status":"active","remaining_quota":3}]}');
  CommerceTransport.QueueResponse(200,
    '{"items":[{"entitlement_id":"ent_001","user_id":"usr_001","app_id":"deepbase_desktop","product_id":"pro_monthly","code":"speech.asr","status":"active","remaining_quota":3}]}');
  CommerceTransport.QueueResponse(200,
    '{"ok":true,"entitlement_code":"speech.asr","remaining_quota":2,"consumed_quantity":1}');

  SafeClient := TDeepKitSafeClient.Create(
    TDeepKitSafeClientConfig.CreateDeepKit('https://api.example.test',
      'atk_001'),
    CommerceTransport);
  Permissions := TDeepKitPermissionClient.Create(SafeClient,
    'deepbase_desktop', 'dev_001', True);
  Service := TDeepBaseSpeechService.Create(RecognizerObj as ISpeechRecognizer,
    Capture);
  try
    Service.PermissionClient := Permissions;
    Service.PermissionFeatureCode := 'speech.asr';

    Result := Service.RecognizeCaptured;

    Assert.IsTrue(Result.Success);
    Assert.AreEqual<Integer>(3, CommerceTransport.RequestCount);
    Assert.AreEqual('GET', CommerceTransport.RequestAt(0).Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/entitlements?app_id=deepbase_desktop',
      CommerceTransport.RequestAt(0).Url);
    Assert.AreEqual('POST', CommerceTransport.RequestAt(2).Method);
    Assert.AreEqual('https://api.example.test/dk/commerce/entitlements/consume',
      CommerceTransport.RequestAt(2).Url);
    Assert.IsTrue(ContainsText(CommerceTransport.RequestAt(2).Body,
      '"feature_code":"speech.asr"'));
  finally
    Service.Free;
    Permissions.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSpeechTests);

end.
