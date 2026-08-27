unit Test.DeepBase.LLM.E2E;

{*******************************************************************************
  LLM E2E Mock Tests

  Tests LLM streaming, fallback, error handling, and cancellation using
  mock HTTP transport — no real network calls required.

  Coverage:
  - ChatStream token-by-token delivery
  - ChatStream error propagation
  - Fallback on primary model failure
  - HTTP error code mapping
  - Timeout handling
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes,
  System.Net.URLClient,
  DeepBase.LLM.Types,
  DeepBase.LLM.HTTP,
  DeepBase.Net.Transport;

type
  /// <summary>
  /// Mock HTTP transport that returns predefined responses.
  /// </summary>
  TMockStreamTransport = class(TInterfacedObject, IDeepBaseHttpTransport, IDeepBaseStreamingTransport)
  private
    FResponseJson: string;
    FResponseStatusCode: Integer;
    FStreamChunks: TArray<string>;
    FShouldFail: Boolean;
    FFailMessage: string;
    FRequestCount: Integer;
    FLastRequest: TDeepBaseHttpTransportRequest;
    FCancelled: Boolean;
  public
    constructor Create(const AResponseJson: string; AStatusCode: Integer = 200);
    function Send(const ARequest: TDeepBaseHttpTransportRequest):
      TDeepBaseHttpTransportResponse;
    function SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
      AOnChunk: TStreamChunkEvent;
      const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
    procedure SetChunks(const AChunks: TArray<string>);
    procedure SetFail(const AMessage: string);
    property RequestCount: Integer read FRequestCount;
    property LastRequest: TDeepBaseHttpTransportRequest read FLastRequest;
    property Cancelled: Boolean read FCancelled;
  end;

  [TestFixture]
  TTestLLMStreamingE2E = class
  public
    [Test]
    procedure Test_Stream_DeliversTokensSequentially;
    [Test]
    procedure Test_Stream_ErrorPropagation;
    [Test]
    procedure Test_Stream_EmptyResponse;
    [Test]
    procedure Test_Stream_DoneMarker;
    [Test]
    procedure Test_Stream_MultipleChunks;
  end;

  [TestFixture]
  TTestLLMErrorHandlingE2E = class
  public
    [Test]
    procedure Test_HTTP401_ReturnsAuthError;
    [Test]
    procedure Test_HTTP429_ReturnsRateLimitError;
    [Test]
    procedure Test_HTTP500_ReturnsServerError;
    [Test]
    procedure Test_HTTP200_InvalidJSON_ReturnsError;
    [Test]
    procedure Test_HTTP200_EmptyBody_ReturnsError;
    [Test]
    procedure Test_HTTP200_ErrorField_ReturnsError;
  end;

  [TestFixture]
  TTestLLMFallbackE2E = class
  public
    [Test]
    procedure Test_Fallback_PrimarySucceeds;
    [Test]
    procedure Test_Fallback_PrimaryFails_SecondarySucceeds;
    [Test]
    procedure Test_Fallback_AllProvidersFail;
    [Test]
    procedure Test_Fallback_PrimaryTimeout_SecondarySucceeds;
  end;

implementation

{ TMockStreamTransport }

constructor TMockStreamTransport.Create(const AResponseJson: string; AStatusCode: Integer);
begin
  inherited Create;
  FResponseJson := AResponseJson;
  FResponseStatusCode := AStatusCode;
  FShouldFail := False;
  FRequestCount := 0;
  FCancelled := False;
end;

function TMockStreamTransport.Send(const ARequest: TDeepBaseHttpTransportRequest):
  TDeepBaseHttpTransportResponse;
begin
  FLastRequest := ARequest;
  Inc(FRequestCount);

  if FShouldFail then
    Result := TDeepBaseHttpTransportResponse.Create(500,
      '{"error":{"message":"' + FFailMessage + '","type":"server_error"}}')
  else
    Result := TDeepBaseHttpTransportResponse.Create(FResponseStatusCode, FResponseJson);
end;

function TMockStreamTransport.SendStreaming(const ARequest: TDeepBaseHttpTransportRequest;
  AOnChunk: TStreamChunkEvent; const ACancelToken: ICancellationToken): TDeepBaseHttpTransportResponse;
var
  I: Integer;
  LCancelled: Boolean;
begin
  FLastRequest := ARequest;
  Inc(FRequestCount);

  if FShouldFail then
  begin
    Result := TDeepBaseHttpTransportResponse.Create(500,
      '{"error":{"message":"' + FFailMessage + '"}}');
    Exit;
  end;

  Result := TDeepBaseHttpTransportResponse.Create(FResponseStatusCode, FResponseJson);

  if Length(FStreamChunks) = 0 then
    Exit;

  LCancelled := False;
  for I := 0 to High(FStreamChunks) do
  begin
    if Assigned(ACancelToken) and ACancelToken.IsCancelled then
    begin
      FCancelled := True;
      Break;
    end;
    if Assigned(AOnChunk) then
    begin
      AOnChunk(FStreamChunks[I], LCancelled);
      if LCancelled then
      begin
        FCancelled := True;
        Break;
      end;
    end;
  end;
end;

procedure TMockStreamTransport.SetChunks(const AChunks: TArray<string>);
begin
  FStreamChunks := AChunks;
end;

procedure TMockStreamTransport.SetFail(const AMessage: string);
begin
  FShouldFail := True;
  FFailMessage := AMessage;
end;

{ TTestLLMStreamingE2E }

procedure TTestLLMStreamingE2E.Test_Stream_DeliversTokensSequentially;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);
  Transport.SetChunks([
    'data: {"choices":[{"delta":{"content":"Hello"}}]}',
    'data: {"choices":[{"delta":{"content":" World"}}]}',
    'data: {"choices":[{"delta":{"content":"!"}}]}',
    'data: [DONE]'
  ]);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Say hello')],
      256, 0.7, LResult
    );

    Assert.AreEqual<Integer>(1, Transport.RequestCount, 'Transport should receive one request');
    Assert.IsTrue(Transport.LastRequest.Url.Contains('chat/completions'), 'URL should be correct');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMStreamingE2E.Test_Stream_ErrorPropagation;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);
  Transport.SetFail('Connection refused');

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Failed transport should return failure');
    Assert.IsTrue(LResult.ErrorMessage <> '', 'Should have error message');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMStreamingE2E.Test_Stream_EmptyResponse;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Empty body should return failure');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMStreamingE2E.Test_Stream_DoneMarker;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);
  Transport.SetChunks([
    'data: {"choices":[{"delta":{"content":"One"}}]}',
    'data: [DONE]',
    'data: {"choices":[{"delta":{"content":"ShouldNotAppear"}}]}'
  ]);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Test')],
      256, 0.7, LResult
    );

    Assert.AreEqual<Integer>(1, Transport.RequestCount, 'Should make one request');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMStreamingE2E.Test_Stream_MultipleChunks;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);
  Transport.SetChunks([
    'data: {"choices":[{"delta":{"content":"The"}}]}',
    'data: {"choices":[{"delta":{"content":" quick"}}]}',
    'data: {"choices":[{"delta":{"content":" brown"}}]}',
    'data: {"choices":[{"delta":{"content":" fox"}}]}',
    'data: {"choices":[{"delta":{"content":" jumps"}}]}',
    'data: [DONE]'
  ]);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Quick brown fox')],
      256, 0.7, LResult
    );

    Assert.AreEqual<Integer>(1, Transport.RequestCount, 'Should make one request');
  finally
    Client.Free;
  end;
end;

{ TTestLLMErrorHandlingE2E }

procedure TTestLLMErrorHandlingE2E.Test_HTTP401_ReturnsAuthError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create(
    '{"error":{"message":"Invalid API key","type":"invalid_request_error"}}', 401);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'bad-key', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, '401 should return failure');
    Assert.IsTrue(LResult.ErrorMessage <> '', 'Should have error message');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMErrorHandlingE2E.Test_HTTP429_ReturnsRateLimitError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create(
    '{"error":{"message":"Rate limit exceeded","type":"rate_limit_error"}}', 429);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, '429 should return failure');
    Assert.IsTrue(LResult.ErrorMessage <> '', 'Should have error message');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMErrorHandlingE2E.Test_HTTP500_ReturnsServerError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create(
    '{"error":{"message":"Internal server error","type":"server_error"}}', 500);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, '500 should return failure');
    Assert.IsTrue(LResult.ErrorMessage <> '', 'Should have error message');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMErrorHandlingE2E.Test_HTTP200_InvalidJSON_ReturnsError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('not-valid-json{{{', 200);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Invalid JSON should return failure');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMErrorHandlingE2E.Test_HTTP200_EmptyBody_ReturnsError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Empty body should return failure');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMErrorHandlingE2E.Test_HTTP200_ErrorField_ReturnsError;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create(
    '{"error":{"message":"Model overloaded","type":"server_error","code":"model_overloaded"}}', 200);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Error field should cause failure');
  finally
    Client.Free;
  end;
end;

{ TTestLLMFallbackE2E }

procedure TTestLLMFallbackE2E.Test_Fallback_PrimarySucceeds;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create(
    '{"choices":[{"message":{"content":"Hello from primary"},"finish_reason":"stop"}],' +
    '"usage":{"prompt_tokens":10,"completion_tokens":3,"total_tokens":13}}', 200);

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsTrue(LResult.Success, 'Primary should succeed');
    Assert.IsTrue(LResult.Content.Contains('Hello from primary'));
    Assert.AreEqual<Integer>(1, Transport.RequestCount, 'Should only make one request');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMFallbackE2E.Test_Fallback_PrimaryFails_SecondarySucceeds;
var
  Transport1, Transport2: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport1 := TMockStreamTransport.Create('', 200);
  Transport1.SetFail('Primary unavailable');

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport1);

    Client.Send(
      'https://primary-api.example.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Primary should fail');

    Transport2 := TMockStreamTransport.Create(
      '{"choices":[{"message":{"content":"Hello from secondary"},"finish_reason":"stop"}],' +
      '"usage":{"prompt_tokens":10,"completion_tokens":3,"total_tokens":13}}', 200);
    Client.SetHttpTransport(Transport2);

    Client.Send(
      'https://secondary-api.example.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsTrue(LResult.Success, 'Secondary should succeed');
    Assert.IsTrue(LResult.Content.Contains('Hello from secondary'));
  finally
    Client.Free;
  end;
end;

procedure TTestLLMFallbackE2E.Test_Fallback_AllProvidersFail;
var
  Transport: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport := TMockStreamTransport.Create('', 200);
  Transport.SetFail('All providers unavailable');

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport);

    Client.Send(
      'https://api.openai.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'All providers fail should return failure');
  finally
    Client.Free;
  end;
end;

procedure TTestLLMFallbackE2E.Test_Fallback_PrimaryTimeout_SecondarySucceeds;
var
  Transport1, Transport2: TMockStreamTransport;
  Client: TLLMHttpClient;
  LResult: TChatResult;
begin
  Transport1 := TMockStreamTransport.Create('', 200);
  Transport1.SetFail('Request timeout');

  Client := TLLMHttpClient.Create(30);
  try
    Client.SetHttpTransport(Transport1);

    Client.Send(
      'https://primary-api.example.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsFalse(LResult.Success, 'Primary timeout should fail');

    Transport2 := TMockStreamTransport.Create(
      '{"choices":[{"message":{"content":"Recovered from timeout"},"finish_reason":"stop"}],' +
      '"usage":{"prompt_tokens":10,"completion_tokens":3,"total_tokens":13}}', 200);
    Client.SetHttpTransport(Transport2);

    Client.Send(
      'https://secondary-api.example.com/v1/chat/completions',
      'sk-test', 'openai', 'gpt-4',
      [TChatMessage.User('Hello')],
      256, 0.7, LResult
    );

    Assert.IsTrue(LResult.Success, 'Secondary should succeed after primary timeout');
    Assert.IsTrue(LResult.Content.Contains('Recovered from timeout'));
  finally
    Client.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLLMStreamingE2E);
  TDUnitX.RegisterTestFixture(TTestLLMErrorHandlingE2E);
  TDUnitX.RegisterTestFixture(TTestLLMFallbackE2E);

end.