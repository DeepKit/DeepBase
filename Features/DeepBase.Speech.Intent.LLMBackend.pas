{ ============================================================================
  DeepBase.Speech.Intent.LLMBackend
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Production adapter that wraps any LLM chat function into a
                TIntentLLMBackend callback for TDeepBaseIntentParser.

                Usage (downstream composition root):

                  var
                    LChatFunc: TIntentChatFunc :=
                      function(const APrompt: string; ATimeoutMs: Integer): string
                      var LResp: TLLMChatResponse;
                      begin
                        LLM.DefaultTimeout := ATimeoutMs;
                        if LLM.Chat(APrompt, LResp) and LResp.Success then
                          Result := LResp.Content
                        else
                          raise Exception.Create('LLM error: ' + LResp.ErrorMessage);
                      end;
                  TDeepBaseIntentParser.RegisterGlobalLLMBackend(
                    CreateIntentLLMBackend(LChatFunc));

                Why a chat function instead of a direct TDeepBaseLLM reference:
                DeepBaseSpeechCore.dpk does NOT require DeepBaseLLM, so this
                unit cannot reference TDeepBaseLLM directly. The chat function
                delegate lets downstream code (which has access to both packages)
                bind the appropriate LLM client.

                BuildIntentPrompt is a pure function exposed for unit testing
                and for callers that want to inspect or log the constructed
                prompt before dispatch.
  ============================================================================ }

unit DeepBase.Speech.Intent.LLMBackend;

interface

uses
  System.SysUtils,
  DeepBase.Speech.Intent;

type
  /// <summary>Any function that takes a prompt string and a timeout in
  /// milliseconds, and returns the LLM's text response. Compatible with
  /// wrappers around TDeepBaseLLM.Chat, TBillingClient.Chat, or
  /// TProxyLLMClient.Chat.</summary>
  TIntentChatFunc = reference to function(const APrompt: string;
    ATimeoutMs: Integer): string;

const
  /// <summary>Default timeout for the intent classification LLM call.
  /// Intent classification is a small, fast prompt — 5 seconds is generous.</summary>
  INTENT_LLM_DEFAULT_TIMEOUT_MS = 5000;

/// <summary>Build a prompt that asks the LLM to classify the user's text into
/// one of the registered intents. Returns a multi-turn prompt suitable for
/// passing to a chat API (system message + user message in text form).</summary>
function BuildIntentPrompt(const AText, ALocale: string;
  const ARegisteredIntents: TArray<string>): string;

/// <summary>Wrap a chat function into a TIntentLLMBackend that can be
/// registered with TDeepBaseIntentParser.RegisterLLMBackend or
/// RegisterGlobalLLMBackend. AChatFunc must not be nil.</summary>
function CreateIntentLLMBackend(const AChatFunc: TIntentChatFunc;
  ADefaultTimeoutMs: Integer = INTENT_LLM_DEFAULT_TIMEOUT_MS): TIntentLLMBackend;

implementation

uses
  System.StrUtils;

function BuildIntentPrompt(const AText, ALocale: string;
  const ARegisteredIntents: TArray<string>): string;
var
  LIntents: string;
  I: Integer;
begin
  if Length(ARegisteredIntents) = 0 then
    LIntents := 'none'
  else
  begin
    LIntents := ARegisteredIntents[0];
    for I := 1 to High(ARegisteredIntents) do
      LIntents := LIntents + ', ' + ARegisteredIntents[I];
  end;

  Result :=
    'System: You are an intent classifier. Given the user''s text, determine ' +
    'which of the available intents it best matches.' + sLineBreak +
    'Respond with a JSON object only: ' +
    '{"intent":"<name>","confidence":0.0,"reason":"<brief explanation>"}' + sLineBreak +
    'confidence must be between 0.0 and 1.0.' + sLineBreak +
    'Available intents: ' + LIntents + sLineBreak +
    'If no intent matches, return ' +
    '{"intent":"unknown","confidence":0.0,"reason":"no matching intent"}' + sLineBreak +
    sLineBreak +
    'User: Text: "' + AText + '"' + sLineBreak +
    'Locale: ' + ALocale;
end;

function CreateIntentLLMBackend(const AChatFunc: TIntentChatFunc;
  ADefaultTimeoutMs: Integer): TIntentLLMBackend;
begin
  if not Assigned(AChatFunc) then
    raise EArgumentException.Create(
      'CreateIntentLLMBackend: AChatFunc must not be nil');

  Result :=
    function(const AText, ALocale: string; ATimeoutMs: Integer;
      const ARegisteredIntents: TArray<string>): string
    var
      LPrompt: string;
      LTimeout: Integer;
    begin
      LPrompt := BuildIntentPrompt(AText, ALocale, ARegisteredIntents);
      if ATimeoutMs > 0 then
        LTimeout := ATimeoutMs
      else
        LTimeout := ADefaultTimeoutMs;
      // Delegate to the injected chat function.
      // If it raises, TDeepBaseIntentParser.Parse catches the exception and
      // returns Source='llm_unavailable' — we let the exception propagate.
      Result := AChatFunc(LPrompt, LTimeout);
    end;
end;

end.
