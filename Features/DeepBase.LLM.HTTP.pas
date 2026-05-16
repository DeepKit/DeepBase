unit DeepBase.LLM.HTTP;

{ DeepBase LLM HTTP Transport �� OpenAI/Anthropic format adapter }

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
      AMaxTokens, ATemperature: Double): string;
    function BuildAnthropicRequest(const AModelId: string; const AMessages: TArray<TChatMessage>;
      AMaxTokens, ATemperature: Double): string;
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

    function FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>;

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
  const AMessages: TArray<TChatMessage>; AMaxTokens, ATemperature: Double): string;
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
  const AMessages: TArray<TChatMessage>; AMaxTokens, ATemperature: Double): string;
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
  Json, ContentArr, TextObj, ImageObj, ImageUrlObj: TJSONObject;
  MessagesArr, MsgContent: TJSONArray;
  I: Integer;
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
begin
  Result := False;
  AResult := Default(TChatResult);
  Obj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Obj = nil then Exit;
  try
    var Choices := Obj.GetValue('choices') as TJSONArray;
    if (Choices <> nil) and (Choices.Count > 0) then
    begin
      var MsgObj := (Choices.Items[0] as TJSONObject).GetValue('message') as TJSONObject;
      if MsgObj <> nil then
      begin
        AResult.Content := MsgObj.GetValue('content', '');
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
begin
  Result := False;
  AResult := Default(TChatResult);
  Obj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Obj = nil then Exit;
  try
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
    Body := BuildAnthropicRequest(AModelId, AMessages, AMaxTokens, ATemperature)
  else
    Body := BuildOpenAIRequest(AModelId, AMessages, AMaxTokens, ATemperature);

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
  Body, URL, Line, Data: string;
  Response: TDeepBaseHttpTransportResponse;
  Lines: TStringList;
  LineIndex: Integer;
  Done: Boolean;
begin
  Result := False;
  FillChar(AResult, SizeOf(AResult), 0);
  AResult.ModelUsed := AModelId;

  // Build streaming request (add stream:true)
  if SameText(AApiFormat, 'anthropic') then
    Body := BuildAnthropicRequest(AModelId, AMessages, AMaxTokens, ATemperature)
  else
  begin
    // Inject stream:true into OpenAI request
    var MsgJson := BuildOpenAIRequest(AModelId, AMessages, AMaxTokens, ATemperature);
    var Obj := TJSONObject.ParseJSONValue(MsgJson) as TJSONObject;
    try
      if Obj <> nil then
      begin
        Obj.AddPair('stream', TJSONBool.Create(True));
        Body := Obj.ToJSON;
      end
      else
        Body := MsgJson;
    finally
      Obj.Free;
    end;
  end;

  // Build URL
  URL := AEndpoint;
  if not URL.EndsWith('/') then URL := URL + '/';
  URL := URL + 'chat/completions';

  try
    Response := PostJson(URL, Body, BuildHeaders(AApiKey, AApiFormat, True));

    if Response.StatusCode <> 200 then
    begin
      AResult.ErrorMessage := Format('HTTP %d: %s',
        [Response.StatusCode, Copy(Response.Body, 1, 200)]);
      AResult.ErrorCode := MapErrorToCode(Response.StatusCode, Response.Body);
      if Assigned(AOnError) then AOnError(AResult.ErrorMessage);
      Exit;
    end;

    // The transport abstraction returns the body after completion; parse SSE lines
    // from the buffered response until a real streaming callback is added.
    Lines := TStringList.Create;
    try
      Lines.Text := Response.Body;
      Data := '';
      Done := False;
      for LineIndex := 0 to Lines.Count - 1 do
      begin
        if Done then
          Break;
        Line := Lines[LineIndex];
        if Line = '' then Continue;
        if Line.StartsWith('data: ') then
        begin
          Data := Line.Substring(6);
          if Data = '[DONE]' then
          begin
            Done := True;
            Break;
          end;

          // Parse chunk JSON
          var Chunk := TJSONObject.ParseJSONValue(Data) as TJSONObject;
          if Chunk <> nil then
          try
            var Choices := Chunk.GetValue('choices') as TJSONArray;
            if (Choices <> nil) and (Choices.Count > 0) then
            begin
              var Delta := ((Choices.Items[0] as TJSONObject).GetValue('delta') as TJSONObject);
              if Delta <> nil then
              begin
                var Token := Delta.GetValue('content', '');
                if Token <> '' then
                begin
                  AResult.Content := AResult.Content + Token;
                  if Assigned(AOnChunk) then AOnChunk(Token);
                end;
              end;
            end;
          finally
            Chunk.Free;
          end;
        end;
      end;
    finally
      Lines.Free;
    end;

    AResult.Success := True;
    Result := True;
  except
    on E: Exception do
    begin
      AResult.ErrorMessage := E.Message;
      AResult.ErrorCode := 'stream_error';
      if Assigned(AOnError) then AOnError(E.Message);
    end;
  end;
end;

function TLLMHttpClient.FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>;
begin
  SetLength(Result, 0);
end;

end.
