{ ============================================================================
  DeepBase.LLM.Providers - Provider-specific request/response formatting

  Contains HTTP request body builders and response parsers for each
  supported LLM provider (OpenAI, Anthropic, etc.).
  ============================================================================ }

unit DeepBase.LLM.Providers;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.LLM.Types;

const
  URL_OPENAI = 'https://api.openai.com/v1';
  URL_ANTHROPIC = 'https://api.anthropic.com/v1';

/// <summary>Get default base URL for a provider</summary>
function GetDefaultBaseUrl(Provider: TLLMProvider): string;

/// <summary>Build OpenAI-format request body</summary>
function BuildOpenAIRequestBody(const Config: TLLMConfig;
  const Messages: TLLMMessages): string;

/// <summary>Build Anthropic-format request body</summary>
function BuildAnthropicRequestBody(const Config: TLLMConfig;
  const Messages: TLLMMessages): string;

/// <summary>Parse OpenAI-format response</summary>
function ParseOpenAIResponse(const JsonResponse: string;
  out Response: TLLMChatResponse): Boolean;

/// <summary>Parse Anthropic-format response</summary>
function ParseAnthropicResponse(const JsonResponse: string;
  out Response: TLLMChatResponse): Boolean;

implementation

function GetDefaultBaseUrl(Provider: TLLMProvider): string;
begin
  case Provider of
    lpOpenAI:    Result := URL_OPENAI;
    lpAnthropic: Result := URL_ANTHROPIC;
    lpAzure:     Result := ''; // Must be configured
    lpLiteLLM:   Result := 'http://localhost:4000';
    lpOllama:    Result := 'http://localhost:11434';
    lpCustom:    Result := '';
  else
    Result := URL_OPENAI;
  end;
end;

function BuildOpenAIRequestBody(const Config: TLLMConfig;
  const Messages: TLLMMessages): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TLLMMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', Config.Model);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(Config.MaxTokens));
    JsonObj.AddPair('temperature', TJSONNumber.Create(Config.Temperature));

    MsgArray := TJSONArray.Create;

    // Add system prompt if exists
    if Config.SystemPrompt <> '' then
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', 'system');
      MsgObj.AddPair('content', Config.SystemPrompt);
      MsgArray.Add(MsgObj);
    end;

    // Add messages
    for Msg in Messages do
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', Msg.Role);
      MsgObj.AddPair('content', Msg.Content);
      MsgArray.Add(MsgObj);
    end;

    JsonObj.AddPair('messages', MsgArray);

    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

function BuildAnthropicRequestBody(const Config: TLLMConfig;
  const Messages: TLLMMessages): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TLLMMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', Config.Model);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(Config.MaxTokens));

    if Config.Temperature >= 0 then
      JsonObj.AddPair('temperature', TJSONNumber.Create(Config.Temperature));

    // Anthropic uses system as a separate field
    if Config.SystemPrompt <> '' then
      JsonObj.AddPair('system', Config.SystemPrompt);

    MsgArray := TJSONArray.Create;

    for Msg in Messages do
    begin
      // Skip system messages for Anthropic (handled above)
      if Msg.Role = 'system' then
        Continue;

      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', Msg.Role);
      MsgObj.AddPair('content', Msg.Content);
      MsgArray.Add(MsgObj);
    end;

    JsonObj.AddPair('messages', MsgArray);

    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

function ParseOpenAIResponse(const JsonResponse: string;
  out Response: TLLMChatResponse): Boolean;
var
  JsonObj, ChoiceObj, MsgObj, UsageObj, ErrorObj: TJSONObject;
  ChoicesArray: TJSONArray;
begin
  Result := False;
  Response.Init;

  try
    JsonObj := TJSONObject.ParseJSONValue(JsonResponse) as TJSONObject;
    if JsonObj = nil then
    begin
      Response.ErrorMessage := 'Invalid JSON response';
      Exit;
    end;

    try
      // Check for error
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
      begin
        Response.ErrorMessage := ErrorObj.GetValue<string>('message', 'Unknown error');
        Response.ErrorCode := ErrorObj.GetValue<string>('type', '');
        Exit;
      end;

      // Parse choices
      if not JsonObj.TryGetValue<TJSONArray>('choices', ChoicesArray) then
      begin
        Response.ErrorMessage := 'No choices in response';
        Exit;
      end;

      if ChoicesArray.Count = 0 then
      begin
        Response.ErrorMessage := 'Empty choices array';
        Exit;
      end;

      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      Response.FinishReason := ChoiceObj.GetValue<string>('finish_reason', '');

      if ChoiceObj.TryGetValue<TJSONObject>('message', MsgObj) then
        Response.Content := MsgObj.GetValue<string>('content', '');

      // Parse usage
      if JsonObj.TryGetValue<TJSONObject>('usage', UsageObj) then
      begin
        Response.InputTokens := UsageObj.GetValue<Integer>('prompt_tokens', 0);
        Response.OutputTokens := UsageObj.GetValue<Integer>('completion_tokens', 0);
        Response.TotalTokens := UsageObj.GetValue<Integer>('total_tokens', 0);
      end;

      Response.Success := True;
      Result := True;
    finally
      JsonObj.Free;
    end;
  except
    on E: Exception do
    begin
      Response.ErrorMessage := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function ParseAnthropicResponse(const JsonResponse: string;
  out Response: TLLMChatResponse): Boolean;
var
  JsonObj, ContentObj, UsageObj, ErrorObj: TJSONObject;
  ContentArray: TJSONArray;
begin
  Result := False;
  Response.Init;

  try
    JsonObj := TJSONObject.ParseJSONValue(JsonResponse) as TJSONObject;
    if JsonObj = nil then
    begin
      Response.ErrorMessage := 'Invalid JSON response';
      Exit;
    end;

    try
      // Check for error
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
      begin
        Response.ErrorMessage := ErrorObj.GetValue<string>('message', 'Unknown error');
        Response.ErrorCode := ErrorObj.GetValue<string>('type', '');
        Exit;
      end;

      // Parse content
      if JsonObj.TryGetValue<TJSONArray>('content', ContentArray) and (ContentArray.Count > 0) then
      begin
        ContentObj := ContentArray.Items[0] as TJSONObject;
        Response.Content := ContentObj.GetValue<string>('text', '');
      end;

      Response.FinishReason := JsonObj.GetValue<string>('stop_reason', '');

      // Parse usage
      if JsonObj.TryGetValue<TJSONObject>('usage', UsageObj) then
      begin
        Response.InputTokens := UsageObj.GetValue<Integer>('input_tokens', 0);
        Response.OutputTokens := UsageObj.GetValue<Integer>('output_tokens', 0);
        Response.TotalTokens := Response.InputTokens + Response.OutputTokens;
      end;

      Response.Success := True;
      Result := True;
    finally
      JsonObj.Free;
    end;
  except
    on E: Exception do
    begin
      Response.ErrorMessage := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
