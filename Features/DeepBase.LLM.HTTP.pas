unit DeepBase.LLM.HTTP;

{ DeepBase LLM HTTP Transport 支持 OpenAI/Anthropic format adapter }

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.Net.URLClient,
  System.JSON, DeepBase.LLM.Types, DeepBase.Net.Transport;

type
  TLLMHttpClient = class
  private
    FTransport: IDeepBaseHttpTransport;
    FTimeoutMs: Integer;
    function BuildOpenAIRequest(const AModelId: string; const AMessages: TArray<TChatMessage>;
      AMaxTokens, ATemperature: Double; AStream: Boolean): string;
    function BuildAnthropicRequest(const AModelId: string; const AMessages: TArray<TChatMessage>;
      AMaxTokens, ATemperature: Double; AStream: Boolean): string;
    /// <summary>Promote one SSE data payload into the text token it carries for
    /// either dialect (OpenAI choices[].delta.content, Anthropic
    /// content_block_delta.delta.text). Returns '' when the event has no token.</summary>
    function ExtractStreamDelta(const AData: string): string;
    function BuildOpenAIVisionRequest(const AModelId: string; const AImageBase64: string;
      const AImageMimeType: string; const ASystemPrompt, AUserPrompt: string;
      AMaxTokens, ATemperature: Double): string;
    function BuildAnthropicVisionRequest(const AModelId: string; const AImageBase64: string;
      const AImageMimeType: string; const ASystemPrompt, AUserPrompt: string;
      AMaxTokens, ATemperature: Double): string;
    function ParseOpenAIResponse(const AJson: string; out AResult: TChatResult): Boolean;
    function ParseAnthropicResponse(const AJson: string; out AResult: TChatResult): Boolean;
    function MapErrorToCode(AHttpStatus: Integer; const AResponseBody: string): string;
    function BuildHeaders(const AApiKey, AApiFormat: string;
      AStreaming: Boolean = False): TNetHeaders;
    function PostJson(const AUrl, ABody: string; const AHeaders: TNetHeaders):
      TDeepBaseHttpTransportResponse;
  public
    constructor Create(ATimeoutSec: Integer = 120);
    destructor Destroy; override;

    procedure SetHttpTransport(const ATransport: IDeepBaseHttpTransport);

    function Send(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
      ATemperature: Double; out AResult: TChatResult): Boolean;

    function SendVision(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AImageBase64: string; const AImageMimeType: string;
      const ASystemPrompt, AUserPrompt: string;
      AMaxTokens: Integer; ATemperature: Double; out AResult: TChatResult): Boolean;

    function GenerateImage(const AEndpoint, AApiKey, AApiFormat, AModelId,
      APrompt, ASize: string; out AResult: TImageGenerationResult): Boolean;

    function SendStream(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
      ATemperature: Double; AOnChunk: TProc<string>; AOnError: TProc<string>;
      out AResult: TChatResult): Boolean;

    function FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>; overload;
    /// <summary>Fetch the provider's model list. On failure returns an empty
    /// array and a human-readable reason in AErrorMsg — callers must not
    /// present an empty list as "provider has no models".</summary>
    function FetchModels(const AEndpoint, AApiKey, AApiFormat: string;
      out AErrorMsg: string): TArray<string>; overload;

    property HttpTransport: IDeepBaseHttpTransport read FTransport write SetHttpTransport;
  end;

implementation

{ TLLMHttpClient }

constructor TLLMHttpClient.Create(ATimeoutSec: Integer);
begin
  inherited Create;
  FTimeoutMs := ATimeoutSec * 1000;
  FTransport := TDeepBaseSystemNetTransport.Create;
end;

destructor TLLMHttpClient.Destroy;
begin
  FTransport := nil;
  inherited;
end;

procedure TLLMHttpClient.SetHttpTransport(
  const ATransport: IDeepBaseHttpTransport);
begin
  if ATransport = nil then
    FTransport := TDeepBaseSystemNetTransport.Create
  else
    FTransport := ATransport;
end;

function TLLMHttpClient.BuildOpenAIRequest(const AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens, ATemperature: Double;
  AStream: Boolean): string;
var
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('model', AModelId);
    Json.AddPair('max_tokens', TJSONNumber.Create(Round(AMaxTokens)));
    Json.AddPair('temperature', TJSONNumber.Create(ATemperature));
    // B2-10: stream 只有一个写入口，且由调用方决定。非流式体不得带这个键——
    // 发出 stream:true 会让服务端返回 SSE，而调用方按整体 JSON 解析。
    if AStream then
      Json.AddPair('stream', TJSONBool.Create(True));
    Arr := TJSONArray.Create;
    for I := 0 to High(AMessages) do
    begin
      var Msg := TJSONObject.Create;
      Msg.AddPair('role', AMessages[I].Role);
      Msg.AddPair('content', AMessages[I].Content);
      Arr.AddElement(Msg);
    end;
    Json.AddPair('messages', Arr);
    Result := Json.ToJSON;
  finally
    Json.Free;
  end;
end;

function TLLMHttpClient.BuildAnthropicRequest(const AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens, ATemperature: Double;
  AStream: Boolean): string;
var
  Json: TJSONObject;
  Arr: TJSONArray;
  I: Integer;
  SystemPrompt: string;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('model', AModelId);
    Json.AddPair('max_tokens', TJSONNumber.Create(Round(AMaxTokens)));
    // B2-10: 与 OpenAI 分支同构的 stream 写入口。旧实现只在 OpenAI 侧硬注 stream，
    // Anthropic 流式调用发出的是非流式请求，却按 SSE 解析，永远收不到增量。
    if AStream then
      Json.AddPair('stream', TJSONBool.Create(True));

    SystemPrompt := '';
    for I := 0 to High(AMessages) do
      if AMessages[I].Role = 'system' then SystemPrompt := AMessages[I].Content;

    if SystemPrompt <> '' then
      Json.AddPair('system', SystemPrompt);

    Arr := TJSONArray.Create;
    for I := 0 to High(AMessages) do
    begin
      if AMessages[I].Role = 'system' then Continue;
      var Msg := TJSONObject.Create;
      Msg.AddPair('role', AMessages[I].Role);
      Msg.AddPair('content', AMessages[I].Content);
      Arr.AddElement(Msg);
    end;
    Json.AddPair('messages', Arr);
    Result := Json.ToJSON;
  finally
    Json.Free;
  end;
end;

function TLLMHttpClient.BuildOpenAIVisionRequest(const AModelId: string;
  const AImageBase64: string; const AImageMimeType: string;
  const ASystemPrompt, AUserPrompt: string; AMaxTokens, ATemperature: Double): string;
var
  Json, TextObj, ImageObj, ImageUrlObj: TJSONObject;
  MessagesArr, MsgContent: TJSONArray;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('model', AModelId);
    Json.AddPair('max_tokens', TJSONNumber.Create(Round(AMaxTokens)));
    Json.AddPair('temperature', TJSONNumber.Create(ATemperature));

    MessagesArr := TJSONArray.Create;

    // System message (if provided)
    if ASystemPrompt <> '' then
    begin
      var SysMsg := TJSONObject.Create;
      SysMsg.AddPair('role', 'system');
      SysMsg.AddPair('content', ASystemPrompt);
      MessagesArr.AddElement(SysMsg);
    end;

    // User message with vision content
    var UserMsg := TJSONObject.Create;
    UserMsg.AddPair('role', 'user');
    MsgContent := TJSONArray.Create;

    // Text part
    TextObj := TJSONObject.Create;
    TextObj.AddPair('type', 'text');
    TextObj.AddPair('text', AUserPrompt);
    MsgContent.AddElement(TextObj);

    // Image part
    ImageObj := TJSONObject.Create;
    ImageObj.AddPair('type', 'image_url');
    ImageUrlObj := TJSONObject.Create;
    ImageUrlObj.AddPair('url', Format('data:%s;base64,%s', [AImageMimeType, AImageBase64]));
    ImageObj.AddPair('image_url', ImageUrlObj);
    MsgContent.AddElement(ImageObj);

    UserMsg.AddPair('content', MsgContent);
    MessagesArr.AddElement(UserMsg);

    Json.AddPair('messages', MessagesArr);
    Result := Json.ToJSON;
  finally
    Json.Free;
  end;
end;

function TLLMHttpClient.BuildAnthropicVisionRequest(const AModelId: string;
  const AImageBase64: string; const AImageMimeType: string;
  const ASystemPrompt, AUserPrompt: string; AMaxTokens, ATemperature: Double): string;
var
  Json, ImageSource: TJSONObject;
  ContentArr, MessagesArr: TJSONArray;
begin
  Json := TJSONObject.Create;
  try
    Json.AddPair('model', AModelId);
    Json.AddPair('max_tokens', TJSONNumber.Create(Round(AMaxTokens)));
    Json.AddPair('temperature', TJSONNumber.Create(ATemperature));

    // System prompt
    if ASystemPrompt <> '' then
      Json.AddPair('system', ASystemPrompt);

    MessagesArr := TJSONArray.Create;
    var UserMsg := TJSONObject.Create;
    UserMsg.AddPair('role', 'user');

    // Anthropic uses content array with text + image blocks
    ContentArr := TJSONArray.Create;

    // Text block
    var TextBlock := TJSONObject.Create;
    TextBlock.AddPair('type', 'text');
    TextBlock.AddPair('text', AUserPrompt);
    ContentArr.AddElement(TextBlock);

    // Image block
    var ImageBlock := TJSONObject.Create;
    ImageBlock.AddPair('type', 'image');
    ImageSource := TJSONObject.Create;
    ImageSource.AddPair('type', 'base64');
    ImageSource.AddPair('media_type', AImageMimeType);
    ImageSource.AddPair('data', AImageBase64);
    ImageBlock.AddPair('source', ImageSource);
    ContentArr.AddElement(ImageBlock);

    UserMsg.AddPair('content', ContentArr);
    MessagesArr.AddElement(UserMsg);
    Json.AddPair('messages', MessagesArr);
    Result := Json.ToJSON;
  finally
    Json.Free;
  end;
end;

function TLLMHttpClient.ParseOpenAIResponse(const AJson: string;
  out AResult: TChatResult): Boolean;
var
  Obj: TJSONObject;
  ErrorObj: TJSONObject;
begin
  Result := False;
  AResult := Default(TChatResult);
  Obj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Obj = nil then Exit;
  try
    // REVIEW5-FEAT-006: Check for error envelope in HTTP 200 responses
    ErrorObj := Obj.GetValue('error') as TJSONObject;
    if ErrorObj <> nil then
    begin
      AResult.ErrorMessage := ErrorObj.GetValue('message', 'Unknown error');
      AResult.ErrorCode := ErrorObj.GetValue('code', 'api_error');
      AResult.Success := False;
      Exit;
    end;

    var Choices := Obj.GetValue('choices') as TJSONArray;
    if (Choices <> nil) and (Choices.Count > 0) then
    begin
      var MsgObj := (Choices.Items[0] as TJSONObject).GetValue('message') as TJSONObject;
      if MsgObj <> nil then
      begin
        AResult.Content := MsgObj.GetValue('content', '');
        // Extract reasoning_content (Agnes/GPT-5/DeepSeek/o1-style models put
        // chain-of-thought here). Falls back to 'reasoning' alias.
        AResult.ReasoningContent := MsgObj.GetValue('reasoning_content',
          MsgObj.GetValue('reasoning', ''));
        // If content is empty but reasoning produced output, surface reasoning
        // as content so callers still get usable text (matches DeepFrames
        // historical reasoning fallback, see memory deepbase-crypto-rsa-blocking).
        if (AResult.Content = '') and (AResult.ReasoningContent <> '') then
          AResult.Content := AResult.ReasoningContent;
        AResult.Success := True;
        Result := True;
      end;
    end;
    var Usage := Obj.GetValue('usage') as TJSONObject;
    if Usage <> nil then
    begin
      AResult.PromptTokens := Usage.GetValue('prompt_tokens', 0);
      AResult.CompletionTokens := Usage.GetValue('completion_tokens', 0);
      AResult.TotalTokens := Usage.GetValue('total_tokens', 0);
    end;
  finally
    Obj.Free;
  end;
end;

function TLLMHttpClient.ParseAnthropicResponse(const AJson: string;
  out AResult: TChatResult): Boolean;
var
  Obj: TJSONObject;
  ErrorObj: TJSONObject;
begin
  Result := False;
  AResult := Default(TChatResult);
  Obj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Obj = nil then Exit;
  try
    // REVIEW5-FEAT-006: Check for error envelope in HTTP 200 responses
    ErrorObj := Obj.GetValue('error') as TJSONObject;
    if ErrorObj <> nil then
    begin
      AResult.ErrorMessage := ErrorObj.GetValue('message', 'Unknown error');
      AResult.ErrorCode := ErrorObj.GetValue('type', 'api_error');
      AResult.Success := False;
      Exit;
    end;

    var Content := Obj.GetValue('content') as TJSONArray;
    if (Content <> nil) and (Content.Count > 0) then
    begin
      var Block := Content.Items[0] as TJSONObject;
      AResult.Content := Block.GetValue('text', '');
      AResult.Success := True;
      Result := True;
    end;
    var Usage := Obj.GetValue('usage') as TJSONObject;
    if Usage <> nil then
    begin
      AResult.PromptTokens := Usage.GetValue('input_tokens', 0);
      AResult.CompletionTokens := Usage.GetValue('output_tokens', 0);
    end;
  finally
    Obj.Free;
  end;
end;

function TLLMHttpClient.ExtractStreamDelta(const AData: string): string;
var
  Event, FirstChoice, Delta: TJSONObject;
  Choices: TJSONArray;
begin
  // B2-10：SSE 增量解析此前是 SendStream 里两份重复的 OpenAI 专用代码，
  // Anthropic 的流式事件被静默丢弃。合并为单一入口并按方言分派。
  Result := '';
  Event := TJSONObject.ParseJSONValue(AData) as TJSONObject;
  if Event = nil then Exit;
  try
    // OpenAI: {"choices":[{"delta":{"content":"..."}}]}
    if Event.GetValue('choices') is TJSONArray then
    begin
      Choices := TJSONArray(Event.GetValue('choices'));
      if Choices.Count = 0 then Exit;
      if not (Choices.Items[0] is TJSONObject) then Exit;
      FirstChoice := TJSONObject(Choices.Items[0]);
      if FirstChoice.GetValue('delta') is TJSONObject then
      begin
        Delta := TJSONObject(FirstChoice.GetValue('delta'));
        Result := Delta.GetValue('content', '');
      end;
      Exit;
    end;

    // Anthropic: {"type":"content_block_delta","delta":{"type":"text_delta","text":"..."}}
    // 其余事件（message_start/content_block_start/ping/message_stop）不带文本增量。
    if Event.GetValue('type', '') = 'content_block_delta' then
      if Event.GetValue('delta') is TJSONObject then
        Result := TJSONObject(Event.GetValue('delta')).GetValue('text', '');
  finally
    Event.Free;
  end;
end;

function TLLMHttpClient.MapErrorToCode(AHttpStatus: Integer;
  const AResponseBody: string): string;
begin
  case AHttpStatus of
    401: Result := 'auth_error';
    429: Result := 'rate_limited';
    500..599: Result := 'server_error';
  else
    Result := 'http_' + IntToStr(AHttpStatus);
  end;
end;

function TLLMHttpClient.BuildHeaders(const AApiKey, AApiFormat: string;
  AStreaming: Boolean): TNetHeaders;

  procedure AddHeader(const AName, AValue: string);
  begin
    if AValue = '' then
      Exit;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := TNameValuePair.Create(AName, AValue);
  end;

begin
  SetLength(Result, 0);
  if Trim(AApiKey) <> '' then
    AddHeader('Authorization', 'Bearer ' + AApiKey);
  AddHeader('Content-Type', 'application/json');
  if AStreaming then
    AddHeader('Accept', 'text/event-stream');
  if SameText(AApiFormat, 'anthropic') then
  begin
    AddHeader('x-api-key', AApiKey);
    AddHeader('anthropic-version', '2023-06-01');
  end;
end;

function TLLMHttpClient.PostJson(const AUrl, ABody: string;
  const AHeaders: TNetHeaders): TDeepBaseHttpTransportResponse;
var
  Request: TDeepBaseHttpTransportRequest;
begin
  if FTransport = nil then
    FTransport := TDeepBaseSystemNetTransport.Create;

  Request := TDeepBaseHttpTransportRequest.Create(dbhmPost, AUrl);
  Request.Body := ABody;
  Request.ContentType := 'application/json';
  Request.Headers := AHeaders;
  Request.TimeoutMs := FTimeoutMs;
  Request.FollowRedirects := True;
  Result := FTransport.Send(Request);
end;

function TLLMHttpClient.Send(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double; out AResult: TChatResult): Boolean;
var
  Body, RespStr: string;
  Response: TDeepBaseHttpTransportResponse;
begin
  Result := False;
  AResult := Default(TChatResult);

  if SameText(AApiFormat, 'anthropic') then
    Body := BuildAnthropicRequest(AModelId, AMessages, AMaxTokens, ATemperature, False)
  else
    Body := BuildOpenAIRequest(AModelId, AMessages, AMaxTokens, ATemperature, False);

  try
    // LLM-005 fix: Anthropic uses /messages endpoint, not /chat/completions
    if SameText(AApiFormat, 'anthropic') then
      Response := PostJson(AEndpoint + '/messages', Body,
        BuildHeaders(AApiKey, AApiFormat))
    else
      Response := PostJson(AEndpoint + '/chat/completions', Body,
        BuildHeaders(AApiKey, AApiFormat));

    if Response.StatusCode = 200 then
    begin
      RespStr := Response.Body;
      if SameText(AApiFormat, 'anthropic') then
        Result := ParseAnthropicResponse(RespStr, AResult)
      else
        Result := ParseOpenAIResponse(RespStr, AResult);
    end
    else
    begin
      AResult.ErrorMessage := Format('HTTP %d: %s',
        [Response.StatusCode, Copy(Response.Body, 1, 200)]);
      AResult.ErrorCode := MapErrorToCode(Response.StatusCode,
        Response.Body);
    end;
  except
    on E: Exception do
    begin
      AResult.ErrorMessage := E.Message;
      AResult.ErrorCode := 'network_error';
    end;
  end;
end;

function TLLMHttpClient.SendVision(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AImageBase64: string; const AImageMimeType: string;
  const ASystemPrompt, AUserPrompt: string;
  AMaxTokens: Integer; ATemperature: Double; out AResult: TChatResult): Boolean;
var
  Body, RespStr, URL: string;
  Response: TDeepBaseHttpTransportResponse;
begin
  Result := False;
  AResult := Default(TChatResult);
  AResult.ModelUsed := AModelId;

  if SameText(AApiFormat, 'anthropic') then
    Body := BuildAnthropicVisionRequest(AModelId, AImageBase64, AImageMimeType,
      ASystemPrompt, AUserPrompt, AMaxTokens, ATemperature)
  else
    Body := BuildOpenAIVisionRequest(AModelId, AImageBase64, AImageMimeType,
      ASystemPrompt, AUserPrompt, AMaxTokens, ATemperature);

  // Build endpoint URL
  URL := AEndpoint;
  if not URL.EndsWith('/') then URL := URL + '/';
  if SameText(AApiFormat, 'anthropic') then
    URL := URL + 'messages'
  else
    URL := URL + 'chat/completions';

  try
    Response := PostJson(URL, Body, BuildHeaders(AApiKey, AApiFormat));

    if Response.StatusCode = 200 then
    begin
      RespStr := Response.Body;
      if SameText(AApiFormat, 'anthropic') then
        Result := ParseAnthropicResponse(RespStr, AResult)
      else
        Result := ParseOpenAIResponse(RespStr, AResult);
      if Result then
        AResult.Success := True;
    end
    else
    begin
      AResult.ErrorMessage := Format('Vision HTTP %d: %s',
        [Response.StatusCode, Copy(Response.Body, 1, 200)]);
      AResult.ErrorCode := MapErrorToCode(Response.StatusCode,
        Response.Body);
    end;
  except
    on E: Exception do
    begin
      AResult.ErrorMessage := 'Vision: ' + E.Message;
      AResult.ErrorCode := 'vision_network_error';
    end;
  end;
end;

function TLLMHttpClient.GenerateImage(const AEndpoint, AApiKey, AApiFormat,
  AModelId, APrompt, ASize: string; out AResult: TImageGenerationResult): Boolean;
var
  Json, Item: TJSONObject;
  Data: TJSONArray;
  Url: string;
  Response: TDeepBaseHttpTransportResponse;
  StartedAt: TDateTime;
begin
  Result := False;
  AResult := Default(TImageGenerationResult);
  AResult.ModelUsed := AModelId;
  AResult.MimeType := 'image/png';
  StartedAt := Now;

  if SameText(AApiFormat, 'anthropic') then
  begin
    AResult.ErrorCode := 'unsupported_provider';
    AResult.ErrorMessage := 'Anthropic image generation is not supported by this adapter';
    Exit;
  end;

  Url := AEndpoint;
  if not Url.EndsWith('/') then
    Url := Url + '/';
  Url := Url + 'images/generations';

  Json := TJSONObject.Create;
  try
    Json.AddPair('model', AModelId);
    Json.AddPair('prompt', APrompt);
    Json.AddPair('size', ASize);
    Json.AddPair('response_format', 'b64_json');
    try
      Response := PostJson(Url, Json.ToJSON, BuildHeaders(AApiKey, AApiFormat));
      AResult.DurationMs := MilliSecondsBetween(Now, StartedAt);
      if Response.StatusCode <> 200 then
      begin
        AResult.ErrorCode := MapErrorToCode(Response.StatusCode, Response.Body);
        AResult.ErrorMessage := Format('Image HTTP %d: %s',
          [Response.StatusCode, Copy(Response.Body, 1, 200)]);
        Exit;
      end;

      Item := TJSONObject.ParseJSONValue(Response.Body) as TJSONObject;
      try
        if (Item <> nil) and Item.TryGetValue<TJSONArray>('data', Data) and
           (Data.Count > 0) and (Data.Items[0] is TJSONObject) then
        begin
          AResult.ImageBase64 := (Data.Items[0] as TJSONObject).GetValue<string>('b64_json', '');
          AResult.ImageUrl := (Data.Items[0] as TJSONObject).GetValue<string>('url', '');
          AResult.Success := (AResult.ImageBase64 <> '') or (AResult.ImageUrl <> '');
          Result := AResult.Success;
          if not Result then
          begin
            AResult.ErrorCode := 'empty_image';
            AResult.ErrorMessage := 'Image generation response did not include b64_json or url';
          end;
        end
        else
        begin
          AResult.ErrorCode := 'bad_response';
          AResult.ErrorMessage := 'Invalid image generation response';
        end;
      finally
        Item.Free;
      end;
    except
      on E: Exception do
      begin
        AResult.DurationMs := MilliSecondsBetween(Now, StartedAt);
        AResult.ErrorCode := 'image_network_error';
        AResult.ErrorMessage := E.Message;
      end;
    end;
  finally
    Json.Free;
  end;
end;

function TLLMHttpClient.SendStream(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double; AOnChunk: TProc<string>; AOnError: TProc<string>;
  out AResult: TChatResult): Boolean;
var
  Body, URL: string;
  Req: TDeepBaseHttpTransportRequest;
  Response: TDeepBaseHttpTransportResponse;
  StreamingTransport: IDeepBaseStreamingTransport;
  LResult: TChatResult;  // local copy — 'out' params cannot be captured by anonymous methods
begin
  Result := False;
  LResult := Default(TChatResult);
  LResult.ModelUsed := AModelId;

  // Build streaming request — stream:true comes from the builder, for both dialects
  if SameText(AApiFormat, 'anthropic') then
    Body := BuildAnthropicRequest(AModelId, AMessages, AMaxTokens, ATemperature, True)
  else
    Body := BuildOpenAIRequest(AModelId, AMessages, AMaxTokens, ATemperature, True);

  // Build URL — Anthropic uses /messages, OpenAI-compatible uses /chat/completions
  URL := AEndpoint;
  if not URL.EndsWith('/') then URL := URL + '/';
  if SameText(AApiFormat, 'anthropic') then
    URL := URL + 'messages'
  else
    URL := URL + 'chat/completions';

  try
    // Build transport request record
    Req := TDeepBaseHttpTransportRequest.Create(dbhmPost, URL);
    Req.Body := Body;
    Req.ContentType := 'application/json';
    Req.Headers := BuildHeaders(AApiKey, AApiFormat, True);
    Req.TimeoutMs := FTimeoutMs;

    // Try streaming transport first (true incremental SSE pipe)
    if Supports(FTransport, IDeepBaseStreamingTransport, StreamingTransport) then
    begin
      Response := StreamingTransport.SendStreaming(Req,
        procedure(const AChunk: string; var ACancel: Boolean)
        begin
          // AChunk 已被传输层剥掉 `data: ` 前缀，且 [DONE] 在传输层就断流；
          // 这里只判断"这个事件是否携带文本增量"。
          var Token := ExtractStreamDelta(AChunk);
          if Token <> '' then
          begin
            LResult.Content := LResult.Content + Token;
            if Assigned(AOnChunk) then AOnChunk(Token);
          end;
        end, nil);

      if Response.StatusCode <> 200 then
      begin
        LResult.ErrorMessage := Format('HTTP %d: %s',
          [Response.StatusCode, Copy(Response.Body, 1, 200)]);
        LResult.ErrorCode := MapErrorToCode(Response.StatusCode, Response.Body);
        if Assigned(AOnError) then AOnError(LResult.ErrorMessage);
        AResult := LResult;
        Exit;
      end;
    end
    else
    begin
      // Fallback: buffered transport — post and parse SSE from buffered body
      Response := FTransport.Send(Req);

      if Response.StatusCode <> 200 then
      begin
        LResult.ErrorMessage := Format('HTTP %d: %s',
          [Response.StatusCode, Copy(Response.Body, 1, 200)]);
        LResult.ErrorCode := MapErrorToCode(Response.StatusCode, Response.Body);
        if Assigned(AOnError) then AOnError(LResult.ErrorMessage);
        AResult := LResult;
        Exit;
      end;

      // Parse SSE from buffered body using TStreamReader (no TStringList copy)
      var BodyStream := TStringStream.Create(Response.Body, TEncoding.UTF8);
      var Reader := TStreamReader.Create(BodyStream, TEncoding.UTF8, True);
      try
        while not Reader.EndOfStream do
        begin
          var LLine := TrimRight(Reader.ReadLine);
          if not LLine.StartsWith('data: ') then
            Continue;
          var Data := LLine.Substring(6);
          if Data = '[DONE]' then
            Break;
          var Token := ExtractStreamDelta(Data);
          if Token <> '' then
          begin
            LResult.Content := LResult.Content + Token;
            if Assigned(AOnChunk) then AOnChunk(Token);
          end;
        end;
      finally
        Reader.Free;
      end;
    end;

    // B2-10：HTTP 200 不等于拿到了生成内容。空增量流一律判失败，
    // 否则上游会把"一个字都没吐"当作成功（旧实现在这里无条件 Result := True）。
    if LResult.Content = '' then
    begin
      LResult.ErrorCode := 'empty_stream';
      LResult.ErrorMessage := 'stream returned no content';
      if Assigned(AOnError) then AOnError(LResult.ErrorMessage);
      AResult := LResult;
      Exit;
    end;

    LResult.Success := True;
    Result := True;
  except
    on E: Exception do
    begin
      LResult.ErrorMessage := E.Message;
      LResult.ErrorCode := 'stream_error';
      if Assigned(AOnError) then AOnError(E.Message);
    end;
  end;
  AResult := LResult;
end;

function TLLMHttpClient.FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>;
var
  LErr: string;
begin
  Result := FetchModels(AEndpoint, AApiKey, AApiFormat, LErr);
end;

function TLLMHttpClient.FetchModels(const AEndpoint, AApiKey, AApiFormat: string;
  out AErrorMsg: string): TArray<string>;

  function TryParseModelIds(const ABody: string; out AIds: TArray<string>): Boolean;
  var
    Obj: TJSONObject;
    Arr: TJSONArray;
    Item: TJSONObject;
    I: Integer;
    LId: string;
  begin
    SetLength(AIds, 0);
    Obj := TJSONObject.ParseJSONValue(ABody) as TJSONObject;
    if Obj = nil then
      Exit(False);
    try
      // OpenAI / Anthropic: {"data":[{"id":...}]}; Ollama native: {"models":[{"name":...}]}
      Arr := Obj.GetValue('data') as TJSONArray;
      if Arr = nil then
        Arr := Obj.GetValue('models') as TJSONArray;
      if Arr = nil then
        Exit(False);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        if Item = nil then
          Continue;
        LId := Item.GetValue<string>('id');
        if LId = '' then
          LId := Item.GetValue<string>('name');
        if LId <> '' then
        begin
          SetLength(AIds, Length(AIds) + 1);
          AIds[High(AIds)] := LId;
        end;
      end;
      Result := True;
    finally
      Obj.Free;
    end;
  end;

  function GetModelsOnce(const AUrl: string; out AIds: TArray<string>;
    out AStatusErr: string): Boolean;
  var
    Request: TDeepBaseHttpTransportRequest;
    Response: TDeepBaseHttpTransportResponse;
  begin
    Result := False;
    AStatusErr := '';
    Request := TDeepBaseHttpTransportRequest.Create(dbhmGet, AUrl);
    Request.Headers := BuildHeaders(AApiKey, AApiFormat);
    Request.TimeoutMs := FTimeoutMs;
    Request.FollowRedirects := True;
    try
      Response := FTransport.Send(Request);
    except
      on E: Exception do
      begin
        AStatusErr := E.Message;
        Exit;
      end;
    end;
    if Response.StatusCode = 200 then
    begin
      if not TryParseModelIds(Response.Body, AIds) then
      begin
        AStatusErr := 'unrecognized models response format';
        Exit(False);
      end;
      Result := True;
    end
    else
      AStatusErr := Format('HTTP %d: %s',
        [Response.StatusCode, Copy(Response.Body, 1, 200)]);
  end;

var
  LUrl: string;
  LStatusErr: string;
begin
  SetLength(Result, 0);
  AErrorMsg := '';
  try
    if Trim(AEndpoint) = '' then
    begin
      AErrorMsg := 'endpoint is empty';
      Exit;
    end;

    // OpenAI-compatible (also Anthropic GET /v1/models and Ollama's /v1 shim)
    LUrl := AEndpoint + '/models';
    if not GetModelsOnce(LUrl, Result, LStatusErr) then
    begin
      SetLength(Result, 0);
      // Ollama native listing when the OpenAI-compatible route is unavailable
      if SameText(AApiFormat, 'ollama') and
        GetModelsOnce(AEndpoint + '/api/tags', Result, LStatusErr) then
      begin
        if Length(Result) = 0 then
          AErrorMsg := LStatusErr;
        Exit;
      end;
      AErrorMsg := LStatusErr;
    end
    else if Length(Result) = 0 then
      AErrorMsg := 'models list is empty';
  except
    on E: Exception do
    begin
      SetLength(Result, 0);
      AErrorMsg := E.Message;
    end;
  end;
end;

end.
