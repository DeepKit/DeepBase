unit DeepBase.LLM.Proxy;

/// <summary>
/// DeepBase LLM Proxy Client
/// 通过 DeepLLMProxy 共享服务调用 LLM，实现 ILLMClient 接口。
/// 下游产品无需管理 API Key，只需 proxy 在线即可使用全部 AI 能力。
///
/// 调用方式：标准 OpenAI 兼容 API
///   POST http://127.0.0.1:port/v1/chat/completions
///   model 字段传等级别名：smart / balanced / fast / image_gen / vision
/// </summary>

interface

uses
  System.SysUtils, System.Classes, System.Threading, System.JSON,
  System.Net.HttpClient, System.Net.URLClient, System.Diagnostics,
  DeepBase.LLM.Client, DeepBase.LLM.Types;

type
  TProxyConfig = record
    Host: string;
    Port: Word;
    TimeoutMs: Integer;
    ClientToken: string;  // X-Client-Token header (optional)

    procedure Init;
    function BaseUrl: string;
  end;

  /// <summary>
  /// 代理模式 LLM 客户端 — 通过 DeepLLMProxy 调用
  /// </summary>
  TProxyLLMClient = class(TInterfacedObject, ILLMClient)
  private
    FConfig: TProxyConfig;
    FCallCount: Integer;
    FLastDurationMs: Integer;

    function DoPost(const APath: string; ABody: TJSONObject;
      out AResponse: string; out AStatusCode: Integer): Boolean;
    function ParseChatResponse(const AJson: string): TChatResult;
    function ParseImageResponse(const AJson: string): TImageGenerationResult;
    function BuildMessages(const AMessages: TArray<TChatMessage>): TJSONArray;
  public
    constructor Create(const AConfig: TProxyConfig);

    /// <summary>探测 proxy 是否在线</summary>
    class function Probe(const AHost: string; APort: Word;
      ATimeoutMs: Integer = 200): Boolean; static;

    // ILLMClient
    function Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;
    function GenerateImage(const APrompt: string;
      const ASize: string = '1024x1024'): TImageGenerationResult;
    procedure GenerateImageStream(const APrompt: string;
      const AOnProgress: TImageProgressCallback;
      const AOnResult: TProc<TImageGenerationResult>;
      const AOnError: TProc<string>;
      const ASize: string = '1024x1024');
    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;
  end;

implementation

uses
  System.DateUtils, System.NetEncoding;

{ TProxyConfig }

procedure TProxyConfig.Init;
begin
  Host := '127.0.0.1';
  Port := 8089;
  TimeoutMs := 30000;
  ClientToken := '';
end;

function TProxyConfig.BaseUrl: string;
begin
  Result := Format('http://%s:%d', [Host, Port]);
end;

{ TProxyLLMClient }

constructor TProxyLLMClient.Create(const AConfig: TProxyConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FCallCount := 0;
  FLastDurationMs := 0;
end;

class function TProxyLLMClient.Probe(const AHost: string; APort: Word;
  ATimeoutMs: Integer): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
begin
  Result := False;
  Http := THTTPClient.Create;
  try
    Http.ConnectionTimeout := ATimeoutMs;
    Http.ResponseTimeout := ATimeoutMs;
    try
      Resp := Http.Get(Format('http://%s:%d/health', [AHost, APort]));
      Result := (Resp.StatusCode = 200);
    except
      Result := False;
    end;
  finally
    Http.Free;
  end;
end;

function TProxyLLMClient.DoPost(const APath: string; ABody: TJSONObject;
  out AResponse: string; out AStatusCode: Integer): Boolean;
var
  Http: THTTPClient;
  Resp: IHTTPResponse;
  Content: TStringStream;
  SW: TStopwatch;
begin
  Result := False;
  AResponse := '';
  AStatusCode := 0;

  Http := THTTPClient.Create;
  Content := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  try
    Http.ConnectionTimeout := FConfig.TimeoutMs;
    Http.ResponseTimeout := FConfig.TimeoutMs;
    Http.ContentType := 'application/json';

    if FConfig.ClientToken <> '' then
      Http.CustomHeaders['X-Client-Token'] := FConfig.ClientToken;

    SW := TStopwatch.StartNew;
    try
      Resp := Http.Post(FConfig.BaseUrl + APath, Content);
      SW.Stop;
      FLastDurationMs := SW.ElapsedMilliseconds;
      AStatusCode := Resp.StatusCode;
      AResponse := Resp.ContentAsString(TEncoding.UTF8);
      Result := (AStatusCode >= 200) and (AStatusCode < 300);
    except
      on E: Exception do
      begin
        SW.Stop;
        FLastDurationMs := SW.ElapsedMilliseconds;
        AResponse := E.Message;
        AStatusCode := 0;
      end;
    end;
  finally
    Content.Free;
    Http.Free;
  end;
end;

function TProxyLLMClient.BuildMessages(const AMessages: TArray<TChatMessage>): TJSONArray;
var
  Msg: TChatMessage;
  Obj: TJSONObject;
begin
  Result := TJSONArray.Create;
  for Msg in AMessages do
  begin
    Obj := TJSONObject.Create;
    Obj.AddPair('role', Msg.Role);
    Obj.AddPair('content', Msg.Content);
    Result.AddElement(Obj);
  end;
end;

function TProxyLLMClient.ParseChatResponse(const AJson: string): TChatResult;
var
  Root, Choice, Msg, Usage: TJSONObject;
  Choices: TJSONArray;
begin
  Result := Default(TChatResult);  // Safe: properly initializes managed string fields
  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Root = nil then
  begin
    Result.ErrorCode := 'PARSE_ERROR';
    Result.ErrorMessage := 'Invalid JSON response';
    Exit;
  end;
  try
    // Check for error
    if Root.GetValue('error') <> nil then
    begin
      var ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
      begin
        Result.ErrorCode := ErrObj.GetValue<string>('type', 'PROXY_ERROR');
        Result.ErrorMessage := ErrObj.GetValue<string>('message', AJson);
      end;
      Exit;
    end;

    Result.ModelUsed := Root.GetValue<string>('model', '');

    Choices := Root.GetValue('choices') as TJSONArray;
    if (Choices <> nil) and (Choices.Count > 0) then
    begin
      Choice := Choices.Items[0] as TJSONObject;
      Result.FinishReason := Choice.GetValue<string>('finish_reason', '');
      Msg := Choice.GetValue('message') as TJSONObject;
      if Msg <> nil then
        Result.Content := Msg.GetValue<string>('content', '');
    end;

    Usage := Root.GetValue('usage') as TJSONObject;
    if Usage <> nil then
    begin
      Result.PromptTokens := Usage.GetValue<Integer>('prompt_tokens', 0);
      Result.CompletionTokens := Usage.GetValue<Integer>('completion_tokens', 0);
      Result.TotalTokens := Usage.GetValue<Integer>('total_tokens', 0);
    end;

    Result.Success := Result.Content <> '';
    Result.DurationMs := FLastDurationMs;
  finally
    Root.Free;
  end;
end;

function TProxyLLMClient.ParseImageResponse(const AJson: string): TImageGenerationResult;
var
  Root: TJSONObject;
  Data: TJSONArray;
  Item: TJSONObject;
begin
  Result := Default(TImageGenerationResult);
  Root := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Root = nil then
  begin
    Result.ErrorCode := 'PARSE_ERROR';
    Result.ErrorMessage := 'Invalid JSON response';
    Exit;
  end;
  try
    if Root.GetValue('error') <> nil then
    begin
      var ErrObj := Root.GetValue('error') as TJSONObject;
      if ErrObj <> nil then
      begin
        Result.ErrorCode := ErrObj.GetValue<string>('type', 'PROXY_ERROR');
        Result.ErrorMessage := ErrObj.GetValue<string>('message', AJson);
      end;
      Exit;
    end;

    Data := Root.GetValue('data') as TJSONArray;
    if (Data <> nil) and (Data.Count > 0) then
    begin
      Item := Data.Items[0] as TJSONObject;
      Result.ImageUrl := Item.GetValue<string>('url', '');
      Result.ImageBase64 := Item.GetValue<string>('b64_json', '');
      Result.Success := (Result.ImageUrl <> '') or (Result.ImageBase64 <> '');
    end;

    Result.ModelUsed := Root.GetValue<string>('model', '');
    Result.DurationMs := FLastDurationMs;
  finally
    Root.Free;
  end;
end;

// ── ILLMClient 实现 ──────────────────────────────────────────────────────────

function TProxyLLMClient.Chat(const ATier: TModelTier;
  const AUserPrompt: string): TChatResult;
begin
  Result := Chat(ATier, '', AUserPrompt);
end;

function TProxyLLMClient.Chat(const ATier: TModelTier;
  const ASystemPrompt, AUserPrompt: string): TChatResult;
var
  Messages: TArray<TChatMessage>;
begin
  if ASystemPrompt <> '' then
  begin
    SetLength(Messages, 2);
    Messages[0] := TChatMessage.System(ASystemPrompt);
    Messages[1] := TChatMessage.User(AUserPrompt);
  end
  else
  begin
    SetLength(Messages, 1);
    Messages[0] := TChatMessage.User(AUserPrompt);
  end;
  Result := ChatWithHistory(ATier, Messages);
end;

function TProxyLLMClient.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AMaxTokens: Integer; ATemperature: Double): TChatResult;
var
  Body: TJSONObject;
  Resp: string;
  Code: Integer;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('model', string(ATier));
    Body.AddPair('messages', BuildMessages(AMessages));
    Body.AddPair('stream', TJSONBool.Create(False));
    if AMaxTokens > 0 then
      Body.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));
    if ATemperature >= 0 then
      Body.AddPair('temperature', TJSONNumber.Create(ATemperature));

    if DoPost('/v1/chat/completions', Body, Resp, Code) then
      Result := ParseChatResponse(Resp)
    else
    begin
      Result := Default(TChatResult);  // Safe: properly initializes managed string fields
      Result.ErrorCode := 'PROXY_UNREACHABLE';
      Result.ErrorMessage := Format('Proxy returned %d: %s', [Code, Resp]);
      Result.DurationMs := FLastDurationMs;
    end;
  finally
    Body.Free;
  end;
  Inc(FCallCount);
end;

procedure TProxyLLMClient.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
var
  Http: THTTPClient;
  Content: TStringStream;
  Body: TJSONObject;
  Resp: IHTTPResponse;
  RespStream: TStream;
  Reader: TStreamReader;
  Line, Data: string;
  SW: TStopwatch;
  Obj, Delta: TJSONObject;
  Choices: TJSONArray;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('model', string(ATier));
    Body.AddPair('messages', BuildMessages(AMessages));
    Body.AddPair('stream', TJSONBool.Create(True));
    if AMaxTokens > 0 then
      Body.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));

    Http := THTTPClient.Create;
    Content := TStringStream.Create(Body.ToJSON, TEncoding.UTF8);
    try
      Http.ConnectionTimeout := FConfig.TimeoutMs;
      Http.ResponseTimeout := FConfig.TimeoutMs;
      Http.ContentType := 'application/json';
      if FConfig.ClientToken <> '' then
        Http.CustomHeaders['X-Client-Token'] := FConfig.ClientToken;

      SW := TStopwatch.StartNew;
      try
        Resp := Http.Post(FConfig.BaseUrl + '/v1/chat/completions', Content);
      except
        on E: Exception do
        begin
          if Assigned(AOnError) then
            AOnError('Proxy connection failed: ' + E.Message);
          Exit;
        end;
      end;
      SW.Stop;
      FLastDurationMs := SW.ElapsedMilliseconds;
      Inc(FCallCount);

      if Resp.StatusCode <> 200 then
      begin
        if Assigned(AOnError) then
          AOnError(Format('Proxy returned %d', [Resp.StatusCode]));
        Exit;
      end;

      // Parse SSE stream
      RespStream := Resp.ContentStream;
      Reader := TStreamReader.Create(RespStream, TEncoding.UTF8);
      try
        while not Reader.EndOfStream do
        begin
          Line := Reader.ReadLine;
          if Line.StartsWith('data: ') then
          begin
            Data := Line.Substring(6);
            if Data = '[DONE]' then
              Break;
            Obj := TJSONObject.ParseJSONValue(Data) as TJSONObject;
            if Obj <> nil then
            try
              Choices := Obj.GetValue('choices') as TJSONArray;
              if (Choices <> nil) and (Choices.Count > 0) then
              begin
                Delta := (Choices.Items[0] as TJSONObject).GetValue('delta') as TJSONObject;
                if (Delta <> nil) and (Delta.GetValue('content') <> nil) then
                begin
                  var Chunk := Delta.GetValue<string>('content', '');
                  if (Chunk <> '') and Assigned(AOnChunk) then
                    AOnChunk(Chunk);
                end;
              end;
            finally
              Obj.Free;
            end;
          end;
        end;
      finally
        Reader.Free;
      end;
    finally
      Content.Free;
      Http.Free;
    end;
  finally
    Body.Free;
  end;
end;

function TProxyLLMClient.ChatVision(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string): TChatResult;
var
  Body, MsgObj, ContentPart, ImageUrl: TJSONObject;
  Messages, ContentArr: TJSONArray;
  Resp: string;
  Code: Integer;
begin
  // Build multimodal message (OpenAI vision format)
  Body := TJSONObject.Create;
  try
    Body.AddPair('model', string(ATier));
    Body.AddPair('stream', TJSONBool.Create(False));

    Messages := TJSONArray.Create;
    if ASystemPrompt <> '' then
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', 'system');
      MsgObj.AddPair('content', ASystemPrompt);
      Messages.AddElement(MsgObj);
    end;

    // User message with image
    MsgObj := TJSONObject.Create;
    MsgObj.AddPair('role', 'user');
    ContentArr := TJSONArray.Create;

    // Image part
    ContentPart := TJSONObject.Create;
    ContentPart.AddPair('type', 'image_url');
    ImageUrl := TJSONObject.Create;
    ImageUrl.AddPair('url', Format('data:%s;base64,%s', [AImageMimeType, AImageBase64]));
    ContentPart.AddPair('image_url', ImageUrl);
    ContentArr.AddElement(ContentPart);

    // Text part
    ContentPart := TJSONObject.Create;
    ContentPart.AddPair('type', 'text');
    ContentPart.AddPair('text', AUserPrompt);
    ContentArr.AddElement(ContentPart);

    MsgObj.AddPair('content', ContentArr);
    Messages.AddElement(MsgObj);
    Body.AddPair('messages', Messages);

    if DoPost('/v1/chat/completions', Body, Resp, Code) then
      Result := ParseChatResponse(Resp)
    else
    begin
      Result := Default(TChatResult);  // Safe: properly initializes managed string fields
      Result.ErrorCode := 'PROXY_UNREACHABLE';
      Result.ErrorMessage := Format('Proxy returned %d: %s', [Code, Resp]);
      Result.DurationMs := FLastDurationMs;
    end;
  finally
    Body.Free;
  end;
  Inc(FCallCount);
end;

function TProxyLLMClient.GenerateImage(const APrompt, ASize: string): TImageGenerationResult;
var
  Body: TJSONObject;
  Resp: string;
  Code: Integer;
begin
  Body := TJSONObject.Create;
  try
    Body.AddPair('model', string(TierImageGen));
    Body.AddPair('prompt', APrompt);
    Body.AddPair('size', ASize);
    Body.AddPair('n', TJSONNumber.Create(1));

    if DoPost('/v1/images/generations', Body, Resp, Code) then
      Result := ParseImageResponse(Resp)
    else
    begin
      Result := Default(TImageGenerationResult);
      Result.ErrorCode := 'PROXY_UNREACHABLE';
      Result.ErrorMessage := Format('Proxy returned %d: %s', [Code, Resp]);
      Result.DurationMs := FLastDurationMs;
    end;
  finally
    Body.Free;
  end;
  Inc(FCallCount);
end;

procedure TProxyLLMClient.GenerateImageStream(const APrompt: string;
  const AOnProgress: TImageProgressCallback;
  const AOnResult: TProc<TImageGenerationResult>;
  const AOnError: TProc<string>;
  const ASize: string);
begin
  TTask.Run(
    procedure
    var
      LResult: TImageGenerationResult;
    begin
      try
        if Assigned(AOnProgress) then
          AOnProgress(0.0, 'Starting image generation...', False);

        LResult := GenerateImage(APrompt, ASize);

        if Assigned(AOnProgress) then
          AOnProgress(1.0, 'Complete', True);

        if LResult.Success and Assigned(AOnResult) then
          TThread.ForceQueue(nil, procedure begin AOnResult(LResult); end)
        else if not LResult.Success and Assigned(AOnError) then
          TThread.ForceQueue(nil, procedure begin AOnError(LResult.ErrorMessage); end);
      except
        on E: Exception do
          if Assigned(AOnError) then
            TThread.ForceQueue(nil, procedure begin AOnError(E.Message); end);
      end;
    end);
end;

procedure TProxyLLMClient.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string;
  AOnChunk: TProc<string>; AOnError: TProc<string>; AMaxTokens: Integer);
var
  Messages: TArray<TChatMessage>;
begin
  // For streaming vision, encode image in message content
  // Proxy will handle the multimodal format conversion
  if ASystemPrompt <> '' then
  begin
    SetLength(Messages, 2);
    Messages[0] := TChatMessage.System(ASystemPrompt);
    Messages[1] := TChatMessage.User(
      Format('[image:%s;base64,%s] %s', [AImageMimeType, AImageBase64, AUserPrompt]));
  end
  else
  begin
    SetLength(Messages, 1);
    Messages[0] := TChatMessage.User(
      Format('[image:%s;base64,%s] %s', [AImageMimeType, AImageBase64, AUserPrompt]));
  end;
  ChatStream(ATier, Messages, AOnChunk, AOnError, AMaxTokens);
end;

function TProxyLLMClient.GetModelForTier(const ATier: TModelTier): string;
begin
  // Proxy handles tier→model mapping, we just return the tier name
  Result := string(ATier);
end;

function TProxyLLMClient.CallCount: Integer;
begin
  Result := FCallCount;
end;

function TProxyLLMClient.LastDurationMs: Integer;
begin
  Result := FLastDurationMs;
end;

end.
