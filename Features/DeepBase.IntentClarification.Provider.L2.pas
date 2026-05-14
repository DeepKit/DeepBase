unit DeepBase.IntentClarification.Provider.L2;

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
  /// L2 问题识别处理器 - 通过 LLM 分析用户请求背后的真实问题。
  /// 生成假设（Scaffold）供用户确认/否认，维护否认约束列表。
  /// Property 15: 始终产生至少 1 个 scaffold。
  /// Requirements: 5.1-5.5
  /// </summary>
  TL2ProblemProvider = class(TInterfacedObject, ILevelProvider)
  private
    const
      CDepthLow = 0.4;
      CDepthHigh = 0.6;
    var
      FLLM: ILLMClient;
      FModelTier: TModelTier;
      FDeniedHypotheses: TList<string>;

    function BuildSystemPrompt: string;
    function BuildUserPrompt(const AContext: TProcessingContext): string;
    function ParseScaffolds(const AContent: string): TArray<string>;
    function BuildConstraintsText: string;
    function ProcessWithLLM(const AContext: TProcessingContext): TProviderResult;
    function BuildDegradedResult(const AContext: TProcessingContext;
      const AErrorMsg: string): TProviderResult;
  public
    constructor Create(const ALLM: ILLMClient); overload;
    constructor Create(const ALLM: ILLMClient; ATier: TModelTier); overload;
    destructor Destroy; override;

    { ILevelProvider }
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;

    /// <summary>Records a denied hypothesis as a constraint for future analysis.</summary>
    procedure DenyHypothesis(const AHypothesisText: string);
    /// <summary>Returns the current list of denied hypotheses.</summary>
    function GetDeniedHypotheses: TArray<string>;
  end;

implementation

uses
  System.Math;

{ TL2ProblemProvider }

constructor TL2ProblemProvider.Create(const ALLM: ILLMClient);
begin
  Create(ALLM, TierFast);
end;

constructor TL2ProblemProvider.Create(const ALLM: ILLMClient; ATier: TModelTier);
begin
  inherited Create;
  FLLM := ALLM;
  FModelTier := ATier;
  FDeniedHypotheses := TList<string>.Create;
end;

destructor TL2ProblemProvider.Destroy;
begin
  FDeniedHypotheses.Free;
  inherited;
end;

function TL2ProblemProvider.GetLevel: TClarificationLevel;
begin
  Result := clL2;
end;

function TL2ProblemProvider.RequiresLLM: Boolean;
begin
  Result := True;
end;

function TL2ProblemProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  // L2 handles when context depth is in [0.4, 0.6)
  Result := (AContext.Depth >= CDepthLow) and (AContext.Depth < CDepthHigh);
end;

function TL2ProblemProvider.BuildSystemPrompt: string;
begin
  Result :=
    'You are a problem analyst. Your task is to identify the real problem ' +
    'behind the user''s request. Generate hypotheses about what the user ' +
    'truly needs. Output each hypothesis on a separate line prefixed with "- ". ' +
    'Then ask a clarifying question to narrow down the problem.';
end;

function TL2ProblemProvider.BuildUserPrompt(const AContext: TProcessingContext): string;
var
  LConstraints: string;
  I: Integer;
begin
  Result := 'User request: ' + AContext.UserInput + sLineBreak;

  // Add context from history
  if Length(AContext.History) > 0 then
  begin
    Result := Result + sLineBreak + 'Previous turns:' + sLineBreak;
    for I := Max(0, Length(AContext.History) - 3) to High(AContext.History) do
      Result := Result + '- ' + AContext.History[I].UserInput + sLineBreak;
  end;

  // Add denied hypotheses as constraints
  LConstraints := BuildConstraintsText;
  if LConstraints <> '' then
    Result := Result + sLineBreak + 'Constraints (already denied): ' + LConstraints;

  Result := Result + sLineBreak +
    'Generate hypotheses about the real problem and ask a clarifying question.';
end;

function TL2ProblemProvider.BuildConstraintsText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FDeniedHypotheses.Count - 1 do
  begin
    if I > 0 then
      Result := Result + '; ';
    Result := Result + FDeniedHypotheses[I];
  end;
end;

function TL2ProblemProvider.ParseScaffolds(const AContent: string): TArray<string>;
var
  LLines: TArray<string>;
  LLine: string;
  LResult: TList<string>;
begin
  LResult := TList<string>.Create;
  try
    LLines := AContent.Split([sLineBreak, #10, #13]);
    for LLine in LLines do
    begin
      if LLine.TrimLeft.StartsWith('- ') then
        LResult.Add(LLine.TrimLeft.Substring(2).Trim)
      else if LLine.TrimLeft.StartsWith('* ') then
        LResult.Add(LLine.TrimLeft.Substring(2).Trim);
    end;

    // Property 15: always produce at least 1 scaffold
    if LResult.Count = 0 then
    begin
      // If parsing found no bullet items, use the first non-empty line as scaffold
      for LLine in LLines do
      begin
        if Trim(LLine) <> '' then
        begin
          LResult.Add(Trim(LLine));
          Break;
        end;
      end;
      // Ultimate fallback: use the entire content as a single scaffold
      if LResult.Count = 0 then
        LResult.Add(Trim(AContent));
    end;

    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

function TL2ProblemProvider.ProcessWithLLM(
  const AContext: TProcessingContext): TProviderResult;
var
  LChatResult: TChatResult;
  LScaffolds: TArray<string>;
  LOption: TOptionItem;
  LOptions: TList<TOptionItem>;
  I: Integer;
begin
  Result := Default(TProviderResult);
  Result.Source := 'llm';

  LChatResult := FLLM.Chat(FModelTier, BuildSystemPrompt, BuildUserPrompt(AContext));

  if not LChatResult.Success then
  begin
    Result := BuildDegradedResult(AContext, LChatResult.ErrorMessage);
    Exit;
  end;

  // Parse scaffolds from LLM response
  LScaffolds := ParseScaffolds(LChatResult.Content);
  Result.Scaffolds := LScaffolds;
  Result.Success := True;

  // Build options from scaffolds
  LOptions := TList<TOptionItem>.Create;
  try
    for I := 0 to Min(High(LScaffolds), 7) do  // Max 8 options
    begin
      LOption.Number := I + 1;
      LOption.Text := LScaffolds[I];
      LOption.Value := LScaffolds[I];
      LOption.IsRecommended := (I = 0);
      LOptions.Add(LOption);
    end;
    Result.Options := LOptions.ToArray;
  finally
    LOptions.Free;
  end;

  Result.RecommendedOption := 1;

  // Extract question (last non-bullet line or generate default)
  Result.Question := '您的真实需求是以下哪个方向？';
end;

function TL2ProblemProvider.BuildDegradedResult(
  const AContext: TProcessingContext;
  const AErrorMsg: string): TProviderResult;
var
  LOption: TOptionItem;
begin
  Result := Default(TProviderResult);
  Result.Success := False;
  Result.Source := 'llm';
  Result.ErrorMessage := AErrorMsg;

  // Property 15: even in degraded mode, produce at least 1 scaffold
  Result.Scaffolds := [AContext.UserInput];

  // Provide a minimal option set
  LOption.Number := 1;
  LOption.Text := AContext.UserInput;
  LOption.Value := AContext.UserInput;
  LOption.IsRecommended := True;
  Result.Options := [LOption];
  Result.RecommendedOption := 1;
  Result.Question := '请进一步描述您的需求。';
end;

function TL2ProblemProvider.Process(const AContext: TProcessingContext): TProviderResult;
begin
  // If LLM is nil, return degraded result
  if FLLM = nil then
  begin
    Result := BuildDegradedResult(AContext, 'LLM client not available');
    Exit;
  end;

  // Sync denied hypotheses from context
  // (Context hypotheses marked as Denied are added to our constraint list)
  if Length(AContext.Hypotheses) > 0 then
  begin
    var LHyp: THypothesis;
    for LHyp in AContext.Hypotheses do
    begin
      if LHyp.Denied and (not FDeniedHypotheses.Contains(LHyp.Text)) then
        FDeniedHypotheses.Add(LHyp.Text);
    end;
  end;

  Result := ProcessWithLLM(AContext);
end;

procedure TL2ProblemProvider.DenyHypothesis(const AHypothesisText: string);
begin
  if not FDeniedHypotheses.Contains(AHypothesisText) then
    FDeniedHypotheses.Add(AHypothesisText);
end;

function TL2ProblemProvider.GetDeniedHypotheses: TArray<string>;
begin
  Result := FDeniedHypotheses.ToArray;
end;

end.
