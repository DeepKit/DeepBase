unit UniBase.LLM.HTTP;

{ UniBase LLM HTTP Transport — OpenAI/Anthropic format adapter }

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.Net.HttpClient,
  System.Net.URLClient, System.JSON, UniBase.LLM.Types;

type
  TLLMHttpClient = class
  private
    FHttpClient: THTTPClient;
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
  public
    constructor Create(ATimeoutSec: Integer = 120);
    destructor Destroy; override;

    function Send(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
      ATemperature: Double; out AResult: TChatResult): Boolean;

    function SendVision(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AImageBase64: string; const AImageMimeType: string;
      const ASystemPrompt, AUserPrompt: string;
      AMaxTokens: Integer; ATemperature: Double; out AResult: TChatResult): Boolean;

    function SendStream(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
      const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
      ATemperature: Double; AOnChunk: TProc<string>; AOnError: TProc<string>;
      out AResult: TChatResult): Boolean;

    function FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>;

    property HttpClient: THTTPClient read FHttpClient;
  end;

implementation

{ TLLMHttpClient }

constructor TLLMHttpClient.Create(ATimeoutSec: Integer);
begin
  inherited Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := ATimeoutSec * 1000;
  FHttpClient.ResponseTimeout := ATimeoutSec * 1000;
end;

destructor TLLMHttpClient.Destroy;
begin
  FreeAndNil(FHttpClient);
  inherited;
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

function TLLMHttpClient.Send(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double; out AResult: TChatResult): Boolean;
var
  Body, RespStr: string;
  Response: IHTTPResponse;
  Stream: TStringStream;
begin
  Result := False;
  AResult := Default(TChatResult);

  if SameText(AApiFormat, 'anthropic') then
    Body := BuildAnthropicRequest(AModelId, AMessages, AMaxTokens, ATemperature)
  else
    Body := BuildOpenAIRequest(AModelId, AMessages, AMaxTokens, ATemperature);

  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    try
      FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AApiKey;
      FHttpClient.CustomHeaders['Content-Type'] := 'application/json';

      if SameText(AApiFormat, 'anthropic') then
      begin
        FHttpClient.CustomHeaders['x-api-key'] := AApiKey;
        FHttpClient.CustomHeaders['anthropic-version'] := '2023-06-01';
      end;

      Response := FHttpClient.Post(AEndpoint + '/chat/completions', Stream);

      if Response.StatusCode = 200 then
      begin
        RespStr := Response.ContentAsString(TEncoding.UTF8);
        if SameText(AApiFormat, 'anthropic') then
          Result := ParseAnthropicResponse(RespStr, AResult)
        else
          Result := ParseOpenAIResponse(RespStr, AResult);
      end
      else
      begin
        AResult.ErrorMessage := Format('HTTP %d: %s',
          [Response.StatusCode, Copy(Response.ContentAsString(TEncoding.UTF8), 1, 200)]);
        AResult.ErrorCode := MapErrorToCode(Response.StatusCode,
          Response.ContentAsString(TEncoding.UTF8));
      end;
    except
      on E: Exception do
      begin
        AResult.ErrorMessage := E.Message;
        AResult.ErrorCode := 'network_error';
      end;
    end;
  finally
    Stream.Free;
  end;
end;

function TLLMHttpClient.SendVision(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AImageBase64: string; const AImageMimeType: string;
  const ASystemPrompt, AUserPrompt: string;
  AMaxTokens: Integer; ATemperature: Double; out AResult: TChatResult): Boolean;
var
  Body, RespStr, URL: string;
  Response: IHTTPResponse;
  Stream: TStringStream;
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

  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    try
      FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AApiKey;
      FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
      if SameText(AApiFormat, 'anthropic') then
      begin
        FHttpClient.CustomHeaders['x-api-key'] := AApiKey;
        FHttpClient.CustomHeaders['anthropic-version'] := '2023-06-01';
      end;

      Response := FHttpClient.Post(URL, Stream);

      if Response.StatusCode = 200 then
      begin
        RespStr := Response.ContentAsString(TEncoding.UTF8);
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
          [Response.StatusCode, Copy(Response.ContentAsString(TEncoding.UTF8), 1, 200)]);
        AResult.ErrorCode := MapErrorToCode(Response.StatusCode,
          Response.ContentAsString(TEncoding.UTF8));
      end;
    except
      on E: Exception do
      begin
        AResult.ErrorMessage := 'Vision: ' + E.Message;
        AResult.ErrorCode := 'vision_network_error';
      end;
    end;
  finally
    Stream.Free;
  end;
end;

function TLLMHttpClient.SendStream(const AEndpoint, AApiKey, AApiFormat, AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double; AOnChunk: TProc<string>; AOnError: TProc<string>;
  out AResult: TChatResult): Boolean;
var
  Body, URL, Line, Data: string;
  Stream: TStringStream;
  Response: IHTTPResponse;
  Reader: TStreamReader;
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

  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    try
      FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + AApiKey;
      FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
      FHttpClient.CustomHeaders['Accept'] := 'text/event-stream';

      Response := FHttpClient.Post(URL, Stream);

      if Response.StatusCode <> 200 then
      begin
        AResult.ErrorMessage := Format('HTTP %d: %s',
          [Response.StatusCode, Copy(Response.ContentAsString(TEncoding.UTF8), 1, 200)]);
        AResult.ErrorCode := MapErrorToCode(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
        if Assigned(AOnError) then AOnError(AResult.ErrorMessage);
        Exit;
      end;

      // Parse SSE stream
      Reader := TStreamReader.Create(Response.ContentStream, TEncoding.UTF8);
      try
        Data := '';
        Done := False;
        while not Reader.EndOfStream and not Done do
        begin
          Line := Reader.ReadLine;
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
        Reader.Free;
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
  finally
    Stream.Free;
  end;
end;

function TLLMHttpClient.FetchModels(const AEndpoint, AApiKey, AApiFormat: string): TArray<string>;
begin
  SetLength(Result, 0);
end;

end.
