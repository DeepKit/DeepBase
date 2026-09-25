unit Test.DeepBase.LLM.HTTP.Stream;

{ ============================================================================
  B2-10 回归：流式开关由调用方决定，且两种方言对称。
  判据对位：
    - 非流式请求构造体不得带 stream 键
    - 流式请求可显式开启（OpenAI 与 Anthropic 都要有）
    - 双方言 SSE 增量往返可用（Anthropic content_block_delta 此前被静默丢弃）
    - HTTP 200 但没有任何增量文本 ⇒ fail-closed，不报成功
  传输契约（DeepBase.Net.Transport）：流式回调只收到已剥掉 `data: ` 前缀的载荷，
  `[DONE]` 在传输层断流、永不下发；缓冲回退分支才看到原始 SSE 文本。
  ========================================================================== }

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.LLM.Types,
  DeepBase.LLM.HTTP,
  DeepBase.Net.Transport;

type
  /// 两个替身共用的请求记录面：断言只看"发出去的 body"，不依赖具体传输形态。
  TRecordingTransport = class(TInterfacedObject)
  private
    FLastBody: string;
    FLastUrl: string;
  protected
    procedure RecordRequest(const ARequest: TDeepBaseHttpTransportRequest);
  public
    property LastBody: string read FLastBody;
    property LastUrl: string read FLastUrl;
  end;

  /// 只实现 IDeepBaseHttpTransport ⇒ Supports(..., IDeepBaseStreamingTransport) 失败，
  /// 用来驱动 SendStream 的缓冲回退分支（body 为原始 SSE 文本）。
  TBufferedSseTransport = class(TRecordingTransport, IDeepBaseHttpTransport)
  private
    FResponseBody: string;
    FStatusCode: Integer;
  public
    constructor Create(const AResponseBody: string; AStatusCode: Integer = 200);
    function Send(const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
  end;

  /// 实现 IDeepBaseStreamingTransport，按真实契约逐个下发剥前缀后的增量载荷。
  TChunkPumpTransport = class(TRecordingTransport, IDeepBaseHttpTransport, IDeepBaseStreamingTransport)
  private
    FChunks: TArray<string>;
  public
    constructor Create(const AChunks: array of string);
    function Send(const ARequest: TDeepBaseHttpTransportRequest): TDeepBaseHttpTransportResponse;
    function SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
      AOnChunk: TStreamChunkEvent;
      const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
  end;

  [TestFixture]
  TTestLLMStreamSwitch = class
  private
    FClient: TLLMHttpClient;
    FChunkText: string;
    FChunkCount: Integer;
    FErrorText: string;
    function RunSend(const ATransport: IDeepBaseHttpTransport;
      const AApiFormat: string; out AResult: TChatResult): Boolean;
    function RunSendStream(const ATransport: IDeepBaseHttpTransport;
      const AApiFormat: string; out AResult: TChatResult): Boolean;
  public
    [Setup] procedure SetUp;
    [TearDown] procedure TearDown;

    [Test] procedure Test_OpenAI_NonStreaming_Body_HasNoStreamKey;
    [Test] procedure Test_Anthropic_NonStreaming_Body_HasNoStreamKey;
    [Test] procedure Test_OpenAI_Streaming_Body_CarriesStreamTrue;
    [Test] procedure Test_Anthropic_Streaming_Body_CarriesStreamTrue;
    [Test] procedure Test_OpenAI_Streaming_RoundTrip_AccumulatesDeltas;
    [Test] procedure Test_Anthropic_Streaming_RoundTrip_AccumulatesDeltas;
    [Test] procedure Test_Anthropic_Streaming_BufferedFallback_RoundTrip;
    [Test] procedure Test_Streaming_WithoutAnyDelta_FailsClosed;
  end;

implementation

{ TRecordingTransport }

procedure TRecordingTransport.RecordRequest(const ARequest: TDeepBaseHttpTransportRequest);
begin
  FLastBody := ARequest.Body;
  FLastUrl := ARequest.Url;
end;

{ TBufferedSseTransport }

constructor TBufferedSseTransport.Create(const AResponseBody: string; AStatusCode: Integer);
begin
  inherited Create;
  FResponseBody := AResponseBody;
  FStatusCode := AStatusCode;
end;

function TBufferedSseTransport.Send(const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  RecordRequest(ARequest);
  Result := TDeepBaseHttpTransportResponse.Create(FStatusCode, FResponseBody);
end;

{ TChunkPumpTransport }

constructor TChunkPumpTransport.Create(const AChunks: array of string);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FChunks, Length(AChunks));
  for I := 0 to High(AChunks) do
    FChunks[I] := AChunks[I];
end;

function TChunkPumpTransport.Send(const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  RecordRequest(ARequest);
  Result := TDeepBaseHttpTransportResponse.Create(200, '');
end;

function TChunkPumpTransport.SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
  AOnChunk: TStreamChunkEvent;
  const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
var
  I: Integer;
  Cancel: Boolean;
begin
  RecordRequest(ARequest);
  Result := TDeepBaseHttpTransportResponse.Create(200, '');
  for I := 0 to High(FChunks) do
  begin
    Cancel := False;
    AOnChunk(FChunks[I], Cancel);
    if Cancel then
      Exit;
  end;
end;

{ TTestLLMStreamSwitch }

procedure TTestLLMStreamSwitch.SetUp;
begin
  FClient := TLLMHttpClient.Create(30);
  FChunkText := '';
  FChunkCount := 0;
  FErrorText := '';
end;

procedure TTestLLMStreamSwitch.TearDown;
begin
  FreeAndNil(FClient);
end;

function TTestLLMStreamSwitch.RunSend(const ATransport: IDeepBaseHttpTransport;
  const AApiFormat: string; out AResult: TChatResult): Boolean;
begin
  FClient.SetHttpTransport(ATransport);
  Result := FClient.Send('https://llm.test.invalid/v1', 'sk-test', AApiFormat, 'test-model',
    [TChatMessage.User('Say hello')], 256, 0.7, AResult);
end;

function TTestLLMStreamSwitch.RunSendStream(const ATransport: IDeepBaseHttpTransport;
  const AApiFormat: string; out AResult: TChatResult): Boolean;
var
  LOnChunk: TProc<string>;
  LOnError: TProc<string>;
begin
  FClient.SetHttpTransport(ATransport);
  // 形参不能写 const：TProc<T> 的签名不带 const，写了会报 E2010
  // （'TProc<string>' and 'Procedure'）。
  LOnChunk :=
    procedure(AToken: string)
    begin
      FChunkText := FChunkText + AToken;
      Inc(FChunkCount);
    end;
  LOnError :=
    procedure(AMessage: string)
    begin
      FErrorText := FErrorText + AMessage;
    end;
  Result := FClient.SendStream('https://llm.test.invalid/v1', 'sk-test', AApiFormat,
    'test-model', [TChatMessage.User('Say hello')], 256, 0.7,
    LOnChunk, LOnError, AResult);
end;

procedure TTestLLMStreamSwitch.Test_OpenAI_NonStreaming_Body_HasNoStreamKey;
var
  Transport: TBufferedSseTransport;
  LResult: TChatResult;
begin
  Transport := TBufferedSseTransport.Create(
    '{"choices":[{"message":{"role":"assistant","content":"Hello"}}]}');
  RunSend(Transport, 'openai', LResult);
  Assert.IsTrue(Pos('"stream"', Transport.LastBody) = 0,
    'non-streaming OpenAI body must not carry a stream key: ' + Transport.LastBody);
end;

procedure TTestLLMStreamSwitch.Test_Anthropic_NonStreaming_Body_HasNoStreamKey;
var
  Transport: TBufferedSseTransport;
  LResult: TChatResult;
begin
  Transport := TBufferedSseTransport.Create(
    '{"content":[{"type":"text","text":"Hello"}]}');
  RunSend(Transport, 'anthropic', LResult);
  Assert.IsTrue(Pos('"stream"', Transport.LastBody) = 0,
    'non-streaming Anthropic body must not carry a stream key: ' + Transport.LastBody);
end;

procedure TTestLLMStreamSwitch.Test_OpenAI_Streaming_Body_CarriesStreamTrue;
var
  Transport: TChunkPumpTransport;
  LResult: TChatResult;
begin
  Transport := TChunkPumpTransport.Create(
    ['{"choices":[{"delta":{"content":"Hello"}}]}']);
  RunSendStream(Transport, 'openai', LResult);
  Assert.IsTrue(Pos('"stream":true', Transport.LastBody) > 0,
    'streaming OpenAI body must carry stream:true: ' + Transport.LastBody);
end;

procedure TTestLLMStreamSwitch.Test_Anthropic_Streaming_Body_CarriesStreamTrue;
var
  Transport: TChunkPumpTransport;
  LResult: TChatResult;
begin
  Transport := TChunkPumpTransport.Create(
    ['{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}']);
  RunSendStream(Transport, 'anthropic', LResult);
  // 改前事实：Anthropic 分支不注 stream，流式调用发出的是非流式请求
  Assert.IsTrue(Pos('"stream":true', Transport.LastBody) > 0,
    'streaming Anthropic body must carry stream:true: ' + Transport.LastBody);
  Assert.IsTrue(Pos('messages', Transport.LastUrl) > 0,
    'anthropic streaming must target /messages: ' + Transport.LastUrl);
end;

procedure TTestLLMStreamSwitch.Test_OpenAI_Streaming_RoundTrip_AccumulatesDeltas;
var
  Transport: TChunkPumpTransport;
  LResult: TChatResult;
begin
  Transport := TChunkPumpTransport.Create([
    '{"choices":[{"delta":{"content":"Hello"}}]}',
    '{"choices":[{"delta":{"role":"assistant"}}]}',
    '{"choices":[{"delta":{"content":" World"}}]}']);
  Assert.IsTrue(RunSendStream(Transport, 'openai', LResult),
    'OpenAI streaming round trip must succeed');
  Assert.AreEqual('Hello World', LResult.Content);
  Assert.AreEqual(2, FChunkCount, 'only events carrying a text delta reach the callback');
  Assert.AreEqual('Hello World', FChunkText, 'callback text must equal accumulated content');
end;

procedure TTestLLMStreamSwitch.Test_Anthropic_Streaming_RoundTrip_AccumulatesDeltas;
var
  Transport: TChunkPumpTransport;
  LResult: TChatResult;
begin
  Transport := TChunkPumpTransport.Create([
    '{"type":"message_start","message":{"id":"x"}}',
    '{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}',
    '{"type":"content_block_delta","delta":{"type":"text_delta","text":" World"}}',
    '{"type":"message_stop"}']);
  Assert.IsTrue(RunSendStream(Transport, 'anthropic', LResult),
    'Anthropic streaming round trip must succeed');
  Assert.AreEqual('Hello World', LResult.Content);
  Assert.AreEqual(2, FChunkCount,
    'control events must not be reported as tokens');
end;

procedure TTestLLMStreamSwitch.Test_Anthropic_Streaming_BufferedFallback_RoundTrip;
var
  Transport: TBufferedSseTransport;
  LResult: TChatResult;
begin
  Transport := TBufferedSseTransport.Create(
    'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Hello"}}' + sLineBreak +
    sLineBreak +
    'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":" World"}}' + sLineBreak +
    sLineBreak +
    'data: [DONE]' + sLineBreak);
  Assert.IsTrue(RunSendStream(Transport, 'anthropic', LResult),
    'buffered SSE fallback must parse anthropic deltas too');
  Assert.AreEqual('Hello World', LResult.Content);
  Assert.AreEqual(2, FChunkCount);
end;

procedure TTestLLMStreamSwitch.Test_Streaming_WithoutAnyDelta_FailsClosed;
var
  Transport: TChunkPumpTransport;
  LResult: TChatResult;
begin
  Transport := TChunkPumpTransport.Create([
    '{"type":"ping"}',
    '{"type":"message_stop"}']);
  Assert.IsFalse(RunSendStream(Transport, 'anthropic', LResult),
    'HTTP 200 with no content tokens must not be reported as success');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('empty_stream', LResult.ErrorCode);
  Assert.IsTrue(FErrorText <> '', 'the error callback must fire on an empty stream');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLLMStreamSwitch);

end.
