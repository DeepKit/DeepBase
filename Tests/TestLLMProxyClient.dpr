program TestLLMProxyClient;

/// <summary>
/// 测试 TProxyLLMClient 是否能正确通过 DeepLLMProxy 调用 LLM
/// 使用 mock_proxy_server.py 作为测试服务器
/// </summary>

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DeepBase.LLM.Types in '..\Features\DeepBase.LLM.Types.pas',
  DeepBase.LLM.Client in '..\Features\DeepBase.LLM.Client.pas',
  DeepBase.LLM.Proxy in '..\Features\DeepBase.LLM.Proxy.pas';

procedure TestProbe;
begin
  Writeln('--- Test 1: Probe ---');
  if TProxyLLMClient.Probe('127.0.0.1', 8089, 500) then
    Writeln('  ✓ Probe succeeded - proxy is online')
  else
  begin
    Writeln('  ✗ Probe failed - is the mock server running?');
    Halt(1);
  end;
end;

procedure TestNonProxy;
begin
  Writeln('--- Test 2: Probe non-existent port ---');
  if not TProxyLLMClient.Probe('127.0.0.1', 9999, 200) then
    Writeln('  ✓ Correctly returns false for unreachable port')
  else
    Writeln('  ✗ Should have returned false');
end;

procedure TestChat;
var
  Config: TProxyConfig;
  Client: ILLMClient;
  Result: TChatResult;
begin
  Writeln('--- Test 3: Chat call ---');
  Config.Init;
  Config.Host := '127.0.0.1';
  Config.Port := 8089;
  Client := TProxyLLMClient.Create(Config);

  Result := Client.Chat(TierBalanced, 'Hello world');
  if Result.Success then
  begin
    Writeln('  ✓ Chat call succeeded');
    Writeln('    Content: ' + Result.Content);
    Writeln('    Model: ' + Result.ModelUsed);
    Writeln(Format('    Tokens: prompt=%d completion=%d total=%d',
      [Result.PromptTokens, Result.CompletionTokens, Result.TotalTokens]));
    Writeln(Format('    Duration: %d ms', [Result.DurationMs]));
  end
  else
  begin
    Writeln('  ✗ Chat call failed: ' + Result.ErrorCode + ' - ' + Result.ErrorMessage);
  end;
end;

procedure TestChatSystemPrompt;
var
  Config: TProxyConfig;
  Client: ILLMClient;
  Result: TChatResult;
begin
  Writeln('--- Test 4: Chat with system prompt ---');
  Config.Init;
  Client := TProxyLLMClient.Create(Config);
  Result := Client.Chat(TierSmart, 'You are a helpful assistant.', 'What is 2+2?');
  if Result.Success then
    Writeln('  ✓ Got reply: ' + Result.Content)
  else
    Writeln('  ✗ Failed: ' + Result.ErrorMessage);
end;

procedure TestStream;
var
  Config: TProxyConfig;
  Client: ILLMClient;
  Messages: TArray<TChatMessage>;
  Buffer: string;
  OnChunk: TProc<string>;
  OnError: TProc<string>;
begin
  Writeln('--- Test 5: Streaming ---');
  Config.Init;
  Client := TProxyLLMClient.Create(Config);

  SetLength(Messages, 1);
  Messages[0] := TChatMessage.User('Tell me a story');

  Buffer := '';
  OnChunk :=
    procedure(Chunk: string)
    begin
      Buffer := Buffer + Chunk;
      Write(Chunk);
    end;
  OnError :=
    procedure(Err: string)
    begin
      Writeln('  ✗ Stream error: ' + Err);
    end;

  Client.ChatStream(TierFast, Messages, OnChunk, OnError);

  Writeln;
  if Buffer <> '' then
    Writeln('  ✓ Stream received (total ' + IntToStr(Length(Buffer)) + ' chars)')
  else
    Writeln('  ✗ No stream data received');
end;

procedure TestImage;
var
  Config: TProxyConfig;
  Client: ILLMClient;
  Result: TImageGenerationResult;
begin
  Writeln('--- Test 6: Image generation ---');
  Config.Init;
  Client := TProxyLLMClient.Create(Config);
  Result := Client.GenerateImage('a cat sitting on a mat', '512x512');
  if Result.Success then
  begin
    Writeln('  ✓ Image generated');
    Writeln('    URL: ' + Result.ImageUrl);
    Writeln('    Model: ' + Result.ModelUsed);
  end
  else
    Writeln('  ✗ Failed: ' + Result.ErrorMessage);
end;

begin
  try
    TestProbe;
    TestNonProxy;
    TestChat;
    TestChatSystemPrompt;
    TestStream;
    TestImage;
    Writeln;
    Writeln('All tests completed.');
  except
    on E: Exception do
      Writeln('FATAL: ' + E.ClassName + ': ' + E.Message);
  end;
end.
