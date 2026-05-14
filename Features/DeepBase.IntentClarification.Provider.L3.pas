unit DeepBase.IntentClarification.Provider.L3;

interface

uses
  System.SysUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types;

type
  /// <summary>
  /// L3 单专家指导处理器 - 从 IPersonaRegistry 选择专家角色，
  /// 以该角色的知识背景和沟通风格生成响应。
  /// 维持角色一致性直到用户请求切换或会话结束。
  /// Property 18: 同一专家跨连续轮次保持一致（除非请求切换）。
  /// Requirements: 6.1-6.4
  /// </summary>
  TL3ExpertProvider = class(TInterfacedObject, ILevelProvider)
  private
    const
      CDepthLow = 0.6;
      CDepthHigh = 0.8;
    var
      FLLM: ILLMClient;
      FModelTier: TModelTier;
      FPersonaRegistry: IPersonaRegistry;
      FCurrentExpert: TPersonaProfile;
      FExpertSelected: Boolean;

    function SelectExpert(const AContext: TProcessingContext): TPersonaProfile;
    function BuildSystemPrompt(const AExpert: TPersonaProfile): string;
    function BuildUserPrompt(const AContext: TProcessingContext): string;
    function IsExpertSwitchRequested(const AInput: string): Boolean;
    function ProcessWithLLM(const AContext: TProcessingContext): TProviderResult;
    function BuildDegradedResult(const AContext: TProcessingContext;
      const AErrorMsg: string): TProviderResult;
    function ParseOptions(const AContent: string): TArray<TOptionItem>;
  public
    constructor Create(const ALLM: ILLMClient;
      const APersonaRegistry: IPersonaRegistry); overload;
    constructor Create(const ALLM: ILLMClient;
      const APersonaRegistry: IPersonaRegistry;
      ATier: TModelTier); overload;

    { ILevelProvider }
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;

    /// <summary>Returns the currently selected expert persona.</summary>
    function GetCurrentExpert: TPersonaProfile;
    /// <summary>Forces a switch to a different expert.</summary>
    procedure SwitchExpert(const ANewExpert: TPersonaProfile);
    /// <summary>Resets expert selection so next Process call picks a new one.</summary>
    procedure ResetExpert;
  end;

implementation

uses
  System.Math,
  System.Generics.Collections;

{ TL3ExpertProvider }

constructor TL3ExpertProvider.Create(const ALLM: ILLMClient;
  const APersonaRegistry: IPersonaRegistry);
begin
  Create(ALLM, APersonaRegistry, TierBalanced);
end;

constructor TL3ExpertProvider.Create(const ALLM: ILLMClient;
  const APersonaRegistry: IPersonaRegistry; ATier: TModelTier);
begin
  inherited Create;
  FLLM := ALLM;
  FModelTier := ATier;
  FPersonaRegistry := APersonaRegistry;
  FExpertSelected := False;
  FCurrentExpert := Default(TPersonaProfile);
end;

function TL3ExpertProvider.GetLevel: TClarificationLevel;
begin
  Result := clL3;
end;

function TL3ExpertProvider.RequiresLLM: Boolean;
begin
  Result := True;
end;

function TL3ExpertProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  // L3 handles when context depth is in [0.6, 0.8)
  Result := (AContext.Depth >= CDepthLow) and (AContext.Depth < CDepthHigh);
end;

function TL3ExpertProvider.IsExpertSwitchRequested(const AInput: string): Boolean;
var
  LLower: string;
begin
  LLower := LowerCase(Trim(AInput));
  Result := LLower.Contains('换专家') or
            LLower.Contains('switch expert') or
            LLower.Contains('换一个') or
            LLower.Contains('other expert') or
            LLower.Contains('另一位');
end;

function TL3ExpertProvider.SelectExpert(
  const AContext: TProcessingContext): TPersonaProfile;
begin
  // Property 18: maintain same expert across consecutive turns
  if FExpertSelected and (not IsExpertSwitchRequested(AContext.UserInput)) then
  begin
    Result := FCurrentExpert;
    Exit;
  end;

  // Select a new expert from the registry
  if FPersonaRegistry <> nil then
    Result := FPersonaRegistry.FindBestMatch(AContext.DomainContext)
  else
  begin
    // Fallback: create a generic expert profile
    Result := Default(TPersonaProfile);
    Result.Id := 'generic-expert';
    Result.Name := '通用顾问';
    Result.Role := '综合分析';
    Result.Style := 'professional';
    Result.Description := '提供专业分析和建议的通用顾问';
  end;

  FCurrentExpert := Result;
  FExpertSelected := True;
end;

function TL3ExpertProvider.BuildSystemPrompt(const AExpert: TPersonaProfile): string;
begin
  Result :=
    'You are ' + AExpert.Name + ', an expert in ' + AExpert.Role + '. ' +
    'Communication style: ' + AExpert.Style + '. ' +
    AExpert.Description + sLineBreak +
    'Provide expert guidance on the user''s question. ' +
    'Offer actionable suggestions as bullet points prefixed with "- ". ' +
    'End with a follow-up question to deepen understanding.';
end;

function TL3ExpertProvider.BuildUserPrompt(const AContext: TProcessingContext): string;
var
  I: Integer;
begin
  Result := AContext.UserInput;

  // Add recent history for context continuity
  if Length(AContext.History) > 0 then
  begin
    Result := 'Context from previous turns:' + sLineBreak;
    for I := Max(0, Length(AContext.History) - 3) to High(AContext.History) do
      Result := Result + '- ' + AContext.History[I].UserInput + sLineBreak;
    Result := Result + sLineBreak + 'Current question: ' + AContext.UserInput;
  end;
end;

function TL3ExpertProvider.ParseOptions(const AContent: string): TArray<TOptionItem>;
var
  LLines: TArray<string>;
  LLine: string;
  LOptions: TList<TOptionItem>;
  LOption: TOptionItem;
  LNum: Integer;
begin
  LOptions := TList<TOptionItem>.Create;
  try
    LNum := 0;
    LLines := AContent.Split([sLineBreak, #10, #13]);
    for LLine in LLines do
    begin
      if (LLine.TrimLeft.StartsWith('- ') or LLine.TrimLeft.StartsWith('* ')) and
         (LNum < 8) then
      begin
        Inc(LNum);
        LOption.Number := LNum;
        LOption.Text := LLine.TrimLeft.Substring(2).Trim;
        LOption.Value := LOption.Text;
        LOption.IsRecommended := (LNum = 1);
        LOptions.Add(LOption);
      end;
    end;

    // Ensure at least one option
    if LOptions.Count = 0 then
    begin
      LOption.Number := 1;
      LOption.Text := '请继续深入分析';
      LOption.Value := LOption.Text;
      LOption.IsRecommended := True;
      LOptions.Add(LOption);
    end;

    Result := LOptions.ToArray;
  finally
    LOptions.Free;
  end;
end;

function TL3ExpertProvider.ProcessWithLLM(
  const AContext: TProcessingContext): TProviderResult;
var
  LExpert: TPersonaProfile;
  LChatResult: TChatResult;
begin
  Result := Default(TProviderResult);
  Result.Source := 'llm';

  LExpert := SelectExpert(AContext);

  LChatResult := FLLM.Chat(FModelTier,
    BuildSystemPrompt(LExpert),
    BuildUserPrompt(AContext));

  if not LChatResult.Success then
  begin
    Result := BuildDegradedResult(AContext, LChatResult.ErrorMessage);
    Exit;
  end;

  Result.Success := True;
  Result.Question := LExpert.Name + ' 的建议：' + sLineBreak + LChatResult.Content;
  Result.Options := ParseOptions(LChatResult.Content);
  Result.RecommendedOption := 1;
  Result.Scaffolds := []; // L3 uses direct expert guidance, not scaffolds
end;

function TL3ExpertProvider.BuildDegradedResult(
  const AContext: TProcessingContext;
  const AErrorMsg: string): TProviderResult;
var
  LOption: TOptionItem;
begin
  Result := Default(TProviderResult);
  Result.Success := False;
  Result.Source := 'llm';
  Result.ErrorMessage := AErrorMsg;
  Result.Question := '专家服务暂时不可用，请尝试简化您的问题。';

  LOption.Number := 1;
  LOption.Text := '简化问题重试';
  LOption.Value := LOption.Text;
  LOption.IsRecommended := True;
  Result.Options := [LOption];
  Result.RecommendedOption := 1;
end;

function TL3ExpertProvider.Process(const AContext: TProcessingContext): TProviderResult;
begin
  // If LLM is nil, return degraded result
  if FLLM = nil then
  begin
    Result := BuildDegradedResult(AContext, 'LLM client not available');
    Exit;
  end;

  // Check if user wants to switch expert
  if FExpertSelected and IsExpertSwitchRequested(AContext.UserInput) then
    FExpertSelected := False;

  Result := ProcessWithLLM(AContext);
end;

function TL3ExpertProvider.GetCurrentExpert: TPersonaProfile;
begin
  Result := FCurrentExpert;
end;

procedure TL3ExpertProvider.SwitchExpert(const ANewExpert: TPersonaProfile);
begin
  FCurrentExpert := ANewExpert;
  FExpertSelected := True;
end;

procedure TL3ExpertProvider.ResetExpert;
begin
  FExpertSelected := False;
  FCurrentExpert := Default(TPersonaProfile);
end;

end.
