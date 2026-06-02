unit DeepBase.IntentClarification.Provider.L4;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types;

type
  /// <summary>
  /// 圆桌专家观点记录 - 每位专家的发言内容和身份标识。
  /// </summary>
  TExpertViewpoint = record
    Speaker: string;           // 发言者身份标识（非空）
    Role: string;              // 专家领域
    Content: string;           // 观点内容
  end;

  /// <summary>
  /// L4 多专家圆桌处理器 - 从 IPersonaRegistry 选择 2-4 个互补专家，
  /// 生成带发言者标识的多观点输出，综合共识与分歧。
  /// Property 19: 面板规模在 [2, 4] 范围内。
  /// Property 20: 每个观点有非空发言者标识。
  /// Requirements: 7.1-7.4
  /// </summary>
  TL4RoundtableProvider = class(TInterfacedObject, ILevelProvider)
  private
    const
      CDepthThreshold = 0.8;
      CMinPanelSize = 2;
      CMaxPanelSize = 4;
    var
      FLLM: ILLMClient;
      FPersonaRegistry: IPersonaRegistry;
      FExpertTier: TModelTier;
      FSynthesisTier: TModelTier;

    function SelectPanel(const AContext: TProcessingContext): TArray<TPersonaProfile>;
    function BuildExpertPrompt(const AExpert: TPersonaProfile;
      const AContext: TProcessingContext): string;
    function GenerateViewpoints(const APanel: TArray<TPersonaProfile>;
      const AContext: TProcessingContext): TArray<TExpertViewpoint>;
    function SynthesizeConsensus(const AViewpoints: TArray<TExpertViewpoint>;
      const AContext: TProcessingContext): string;
    function BuildResultFromViewpoints(const AViewpoints: TArray<TExpertViewpoint>;
      const ASynthesis: string): TProviderResult;
    function BuildDegradedResult(const AContext: TProcessingContext;
      const AErrorMsg: string): TProviderResult;
    function ClampPanelSize(ACount: Integer): Integer;
  public
    constructor Create(const ALLM: ILLMClient;
      const APersonaRegistry: IPersonaRegistry); overload;
    constructor Create(const ALLM: ILLMClient;
      const APersonaRegistry: IPersonaRegistry;
      AExpertTier, ASynthesisTier: TModelTier); overload;

    { ILevelProvider }
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;
  end;

implementation

uses
  System.Math;

{ TL4RoundtableProvider }

constructor TL4RoundtableProvider.Create(const ALLM: ILLMClient;
  const APersonaRegistry: IPersonaRegistry);
begin
  Create(ALLM, APersonaRegistry, TierBalanced, TierSmart);
end;

constructor TL4RoundtableProvider.Create(const ALLM: ILLMClient;
  const APersonaRegistry: IPersonaRegistry;
  AExpertTier, ASynthesisTier: TModelTier);
begin
  inherited Create;
  FLLM := ALLM;
  FPersonaRegistry := APersonaRegistry;
  FExpertTier := AExpertTier;
  FSynthesisTier := ASynthesisTier;
end;

function TL4RoundtableProvider.GetLevel: TClarificationLevel;
begin
  Result := clL4;
end;

function TL4RoundtableProvider.RequiresLLM: Boolean;
begin
  Result := True;
end;

function TL4RoundtableProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  // L4 handles when context depth >= 0.8
  Result := AContext.Depth >= CDepthThreshold;
end;

function TL4RoundtableProvider.ClampPanelSize(ACount: Integer): Integer;
begin
  // Property 19: panel size in [2, 4]
  Result := EnsureRange(ACount, CMinPanelSize, CMaxPanelSize);
end;

function TL4RoundtableProvider.SelectPanel(
  const AContext: TProcessingContext): TArray<TPersonaProfile>;
var
  LDesiredCount: Integer;
  LPanel: TArray<TPersonaProfile>;
  LFallback: TPersonaProfile;
  I: Integer;
begin
  LDesiredCount := ClampPanelSize(3); // Default to 3 experts

  if FPersonaRegistry <> nil then
  begin
    LPanel := FPersonaRegistry.FindComplementaryPanel(
      AContext.DomainContext, LDesiredCount);

    // Ensure panel size is within bounds
    if Length(LPanel) < CMinPanelSize then
    begin
      // Pad with generic experts if registry returned too few
      SetLength(LPanel, CMinPanelSize);
      for I := 0 to High(LPanel) do
      begin
        if LPanel[I].Id = '' then
        begin
          LPanel[I].Id := 'generic-' + IntToStr(I + 1);
          LPanel[I].Name := '顾问 ' + IntToStr(I + 1);
          LPanel[I].Role := '综合分析';
          LPanel[I].Style := 'analytical';
          LPanel[I].Description := '提供多角度分析的通用顾问';
        end;
      end;
    end
    else if Length(LPanel) > CMaxPanelSize then
      SetLength(LPanel, CMaxPanelSize);

    Result := LPanel;
  end
  else
  begin
    // Fallback: create a minimal panel of generic experts
    SetLength(Result, CMinPanelSize);
    for I := 0 to CMinPanelSize - 1 do
    begin
      LFallback := Default(TPersonaProfile);
      LFallback.Id := 'fallback-' + IntToStr(I + 1);
      case I of
        0: begin
          LFallback.Name := '实践派顾问';
          LFallback.Role := '实施与执行';
          LFallback.Style := 'pragmatic';
          LFallback.Description := '关注可行性和实施路径';
        end;
        1: begin
          LFallback.Name := '战略派顾问';
          LFallback.Role := '战略规划';
          LFallback.Style := 'strategic';
          LFallback.Description := '关注长期影响和全局视角';
        end;
      end;
      Result[I] := LFallback;
    end;
  end;
end;

function TL4RoundtableProvider.BuildExpertPrompt(
  const AExpert: TPersonaProfile;
  const AContext: TProcessingContext): string;
begin
  Result :=
    'You are ' + AExpert.Name + ' (' + AExpert.Role + '). ' +
    'Style: ' + AExpert.Style + '. ' + AExpert.Description + sLineBreak +
    'Provide your perspective on the following question. ' +
    'Be concise (2-3 sentences). Focus on your area of expertise.' + sLineBreak +
    sLineBreak +
    'Question: ' + AContext.UserInput;
end;

function TL4RoundtableProvider.GenerateViewpoints(
  const APanel: TArray<TPersonaProfile>;
  const AContext: TProcessingContext): TArray<TExpertViewpoint>;
var
  I: Integer;
  LChatResult: TChatResult;
  LViewpoint: TExpertViewpoint;
begin
  SetLength(Result, Length(APanel));

  for I := 0 to High(APanel) do
  begin
    LViewpoint := Default(TExpertViewpoint);
    // Property 20: each viewpoint has non-empty speaker identity
    LViewpoint.Speaker := APanel[I].Name;
    LViewpoint.Role := APanel[I].Role;

    // Ensure speaker is never empty
    if Trim(LViewpoint.Speaker) = '' then
      LViewpoint.Speaker := '专家 ' + IntToStr(I + 1);

    LChatResult := FLLM.Chat(FExpertTier,
      BuildExpertPrompt(APanel[I], AContext),
      AContext.UserInput);

    if LChatResult.Success then
      LViewpoint.Content := LChatResult.Content
    else
      LViewpoint.Content := '（该专家暂时无法提供观点）';

    Result[I] := LViewpoint;
  end;
end;

function TL4RoundtableProvider.SynthesizeConsensus(
  const AViewpoints: TArray<TExpertViewpoint>;
  const AContext: TProcessingContext): string;
var
  LSynthesisPrompt: string;
  I: Integer;
  LChatResult: TChatResult;
begin
  // Build a synthesis prompt with all viewpoints
  LSynthesisPrompt := '以下是多位专家对问题的观点：' + sLineBreak + sLineBreak;
  for I := 0 to High(AViewpoints) do
  begin
    LSynthesisPrompt := LSynthesisPrompt +
      '[' + AViewpoints[I].Speaker + ' - ' + AViewpoints[I].Role + ']' + sLineBreak +
      AViewpoints[I].Content + sLineBreak + sLineBreak;
  end;
  LSynthesisPrompt := LSynthesisPrompt +
    '请综合以上观点，指出共识和分歧，给出综合建议。';

  LChatResult := FLLM.Chat(FSynthesisTier,
    '你是一位圆桌讨论主持人，负责综合多位专家的观点。',
    LSynthesisPrompt);

  if LChatResult.Success then
    Result := LChatResult.Content
  else
    Result := '综合分析暂时不可用，请参考各专家的独立观点。';
end;

function TL4RoundtableProvider.BuildResultFromViewpoints(
  const AViewpoints: TArray<TExpertViewpoint>;
  const ASynthesis: string): TProviderResult;
var
  LQuestion: string;
  LOptions: TList<TOptionItem>;
  LOption: TOptionItem;
  LScaffolds: TList<string>;
  I: Integer;
begin
  Result := Default(TProviderResult);
  Result.Success := True;
  Result.Source := 'llm';

  // Build the question with all viewpoints and synthesis
  LQuestion := '【圆桌讨论】' + sLineBreak;
  for I := 0 to High(AViewpoints) do
  begin
    LQuestion := LQuestion + sLineBreak +
      '▶ ' + AViewpoints[I].Speaker + '（' + AViewpoints[I].Role + '）：' + sLineBreak +
      '  ' + AViewpoints[I].Content + sLineBreak;
  end;
  LQuestion := LQuestion + sLineBreak + '【综合分析】' + sLineBreak + ASynthesis;
  Result.Question := LQuestion;

  // Build options from expert viewpoints
  LOptions := TList<TOptionItem>.Create;
  try
    for I := 0 to Min(High(AViewpoints), 7) do
    begin
      LOption.Number := I + 1;
      LOption.Text := '采纳 ' + AViewpoints[I].Speaker + ' 的建议';
      LOption.Value := AViewpoints[I].Speaker;
      LOption.IsRecommended := (I = 0);
      LOptions.Add(LOption);
    end;

    // Add a "综合方案" option if there's room
    if LOptions.Count < 8 then
    begin
      LOption.Number := LOptions.Count + 1;
      LOption.Text := '采纳综合方案';
      LOption.Value := 'synthesis';
      LOption.IsRecommended := False;
      LOptions.Add(LOption);
    end;

    Result.Options := LOptions.ToArray;
  finally
    LOptions.Free;
  end;

  Result.RecommendedOption := 1;

  // Scaffolds contain each expert's key insight
  LScaffolds := TList<string>.Create;
  try
    for I := 0 to High(AViewpoints) do
      LScaffolds.Add(AViewpoints[I].Speaker + ': ' + AViewpoints[I].Content);
    Result.Scaffolds := LScaffolds.ToArray;
  finally
    LScaffolds.Free;
  end;
end;

function TL4RoundtableProvider.BuildDegradedResult(
  const AContext: TProcessingContext;
  const AErrorMsg: string): TProviderResult;
var
  LOption: TOptionItem;
begin
  Result := Default(TProviderResult);
  Result.Success := False;
  Result.Source := 'llm';
  Result.ErrorMessage := AErrorMsg;
  Result.Question := '圆桌讨论服务暂时不可用，请稍后重试或降低讨论深度。';

  LOption.Number := 1;
  LOption.Text := '降低深度重试';
  LOption.Value := LOption.Text;
  LOption.IsRecommended := True;
  Result.Options := [LOption];
  Result.RecommendedOption := 1;
  Result.Scaffolds := [AContext.UserInput];
end;

function TL4RoundtableProvider.Process(const AContext: TProcessingContext): TProviderResult;
var
  LPanel: TArray<TPersonaProfile>;
  LViewpoints: TArray<TExpertViewpoint>;
  LSynthesis: string;
  LSynthesisFailed: Boolean;
  LAllViewpointsFailed: Boolean;
  I: Integer;
  LFailedCount: Integer;
  LChatResult: TChatResult;
begin
  if FLLM = nil then
  begin
    Result := BuildDegradedResult(AContext, 'LLM client not available');
    Exit;
  end;

  LPanel := SelectPanel(AContext);
  LViewpoints := GenerateViewpoints(LPanel, AContext);

  LFailedCount := 0;
  for I := 0 to High(LViewpoints) do
    if LViewpoints[I].Content = '（该专家暂时无法提供观点）' then
      Inc(LFailedCount);
  LAllViewpointsFailed := (Length(LViewpoints) > 0) and (LFailedCount = Length(LViewpoints));

  LSynthesis := '';
  LSynthesisFailed := False;
  if not LAllViewpointsFailed then
  begin
    LSynthesis := SynthesizeConsensus(LViewpoints, AContext);
    LSynthesisFailed := (LSynthesis = '综合分析暂时不可用，请参考各专家的独立观点。');
  end
  else
  begin
    LChatResult := FLLM.Chat(FSynthesisTier,
      '你是一位圆桌讨论主持人，负责综合多位专家的观点。',
      '所有专家均无法提供观点，请给出降级建议。');
    LSynthesisFailed := not LChatResult.Success;
  end;

  if LAllViewpointsFailed and LSynthesisFailed then
  begin
    Result := BuildDegradedResult(AContext,
      'L4 roundtable: all ' + IntToStr(Length(LPanel)) + ' expert calls and synthesis failed');
    Exit;
  end;

  Result := BuildResultFromViewpoints(LViewpoints, LSynthesis);
  if LSynthesisFailed then
    Result.ErrorMessage := 'Synthesis unavailable, individual viewpoints shown';
end;

end.
