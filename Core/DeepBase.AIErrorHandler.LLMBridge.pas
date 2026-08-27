{ ============================================================================
  DeepBase.AIErrorHandler.LLMBridge

  Bridges TAIErrorHandler.SetAICallback to DeepBase.LLM.Service.LLM().Chat.

  Design intent (see aierrorhandler-rollout/design.md, Property 7..9):
    - On success path: pass through TChatResult.Content
    - On any failure (exception, Success=False, empty content, service missing):
      return empty string so AIErrorHandler walks its fallback message branch
    - Never raise an exception out of the callback
    - Use TierFast (small / latency-sensitive tier) for error diagnosis prompts

  This unit is a thin adapter; it does not own LLM lifecycle, configuration,
  retries, or caching. Those concerns live in DeepBase.LLM.Service.
  ============================================================================ }

unit DeepBase.AIErrorHandler.LLMBridge;

interface

/// <summary>
/// Wire AIErrorHandler's AICallback to LLM().Chat. Idempotent and safe to
/// call multiple times; the most recent call wins.
/// </summary>
procedure InstallLLMBridge;

implementation

uses
  System.SysUtils,
  DeepBase.AIErrorHandler,
  DeepBase.LLM.Types,
  DeepBase.LLM.Service;

// Tier rationale: error diagnosis prompts are short, latency-sensitive, and
// not worth the cost of large models. TierFast maps to the cheapest /
// smallest configured model in DeepBase.LLM.

function CallLLM(const APrompt: string): string;
var
  LResult: TChatResult;
begin
  Result := '';
  try
    LResult := LLM.Chat(TierFast, APrompt);
    if LResult.Success then
      Result := LResult.Content;
  except
    // Swallow everything: the contract with AIErrorHandler is "empty string
    // means fall back". An LLM bridge must never crash the host.
    Result := '';
  end;
end;

procedure InstallLLMBridge;
begin
  TAIErrorHandler.SetAICallback(
    function(const APrompt: string): string
    begin
      Result := CallLLM(APrompt);
    end);
end;

end.
