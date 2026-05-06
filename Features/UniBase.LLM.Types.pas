unit UniBase.LLM.Types;

{ UniBase LLM Types — 统一类型定义，无外部依赖
  消费程序可独立引用此单元定义消息数组 }

interface

type
  // 模型层级 (type string 可扩展，内置五个常量)
  TModelTier = type string;
  TModelTierHelper = record helper for TModelTier
    function DisplayName: string;
  end;

const
  TierSmart          : TModelTier = 'smart';
  TierBalanced       : TModelTier = 'balanced';
  TierFast           : TModelTier = 'fast';
  TierVision         : TModelTier = 'vision';
  TierVisionFallback : TModelTier = 'vision_fallback';

type
  TChatMessage = record
    Role: string;     // 'system' | 'user' | 'assistant'
    Content: string;
    class function System(const AContent: string): TChatMessage; static;
    class function User(const AContent: string): TChatMessage; static;
    class function Assistant(const AContent: string): TChatMessage; static;
  end;

  TChatResult = record
    Success: Boolean;
    Content: string;
    ReasoningContent: string;
    FinishReason: string;
    ModelUsed: string;
    PromptTokens: Integer;
    CompletionTokens: Integer;
    TotalTokens: Integer;
    DurationMs: Integer;
    ErrorCode: string;
    ErrorMessage: string;
  end;

  TProviderConfig = record
    Name: string;       // 'ModelScope' / 'OpenAI' / ...
    Endpoint: string;   // 'https://api-inference.modelscope.cn/v1'
    ApiFormat: string;  // 'openai' | 'anthropic'
    Priority: Integer;  // 0 = highest priority
  end;

  TModelInfo = record
    ModelId: string;
    Tier: TModelTier;
    MaxTokens: Integer;
    Temperature: Double;
    SupportsThinking: Boolean;
    SupportsVision: Boolean;
  end;

implementation

{ TModelTierHelper }

function TModelTierHelper.DisplayName: string;
begin
  if Self = TierSmart then Result := 'Smart'
  else if Self = TierBalanced then Result := 'Balanced'
  else if Self = TierFast then Result := 'Fast'
  else if Self = TierVision then Result := 'Vision'
  else if Self = TierVisionFallback then Result := 'Vision Fallback'
  else Result := string(Self);
end;

{ TChatMessage }

class function TChatMessage.System(const AContent: string): TChatMessage;
begin
  Result.Role := 'system';
  Result.Content := AContent;
end;

class function TChatMessage.User(const AContent: string): TChatMessage;
begin
  Result.Role := 'user';
  Result.Content := AContent;
end;

class function TChatMessage.Assistant(const AContent: string): TChatMessage;
begin
  Result.Role := 'assistant';
  Result.Content := AContent;
end;

end.
