unit DeepBase.IntentClarification.Anticipation;

interface

uses
  System.SysUtils,
  System.Math,
  System.DateUtils,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  /// <summary>
  /// 预判引擎 - 基于四个信号源（时间模式、操作序列、上下文状态、历史模式）计算预测。
  /// 使用简单启发式实现（无 ML）。
  /// Implements IAnticipationEngine.
  /// Property 27: Evidence 字段始终非空。
  /// Requirements: 9.1-9.5
  /// </summary>
  TAnticipationEngine = class(TInterfacedObject, IAnticipationEngine)
  private
    type
      TFeedbackRecord = record
        PredictionId: string;
        Positive: Boolean;
      end;
    var
      FFeedback: TList<TFeedbackRecord>;
      FPredictionCounter: Integer;

    function GeneratePredictionId: string;
    function AnalyzeTemporal(const AContext: TAnticipationContext): Double;
    function AnalyzeOperationSequence(const AContext: TAnticipationContext): Double;
    function AnalyzeContextual(const AContext: TAnticipationContext): Double;
    function AnalyzeHistorical(const AContext: TAnticipationContext): Double;
    function BuildEvidence(const AContext: TAnticipationContext;
      const ASources: TArray<TAnticipationSource>): string;
    function BuildSource(const ASourceType, ASignal: string;
      AConfidence: Double; const AEvidence: string): TAnticipationSource;
    function DetermineIntent(const AContext: TAnticipationContext): string;
  public
    constructor Create;
    destructor Destroy; override;

    { IAnticipationEngine }
    function Predict(const AContext: TAnticipationContext): TAnticipationResult;
    procedure FeedbackPositive(const APredictionId: string);
    procedure FeedbackNegative(const APredictionId: string);
  end;

implementation

{ TAnticipationEngine }

constructor TAnticipationEngine.Create;
begin
  inherited Create;
  FFeedback := TList<TFeedbackRecord>.Create;
  FPredictionCounter := 0;
end;

destructor TAnticipationEngine.Destroy;
begin
  FFeedback.Free;
  inherited;
end;

function TAnticipationEngine.GeneratePredictionId: string;
begin
  Inc(FPredictionCounter);
  Result := Format('pred_%d_%s', [FPredictionCounter,
    FormatDateTime('hhnnsszzz', Now)]);
end;

function TAnticipationEngine.AnalyzeTemporal(
  const AContext: TAnticipationContext): Double;
var
  LHour: Word;
  LMin, LSec, LMSec: Word;
begin
  // Simple time-of-day heuristic: certain hours suggest certain activities
  DecodeTime(Now, LHour, LMin, LSec, LMSec);

  // Morning (8-10): likely starting work tasks
  // Afternoon (14-16): likely continuing tasks
  // Evening (18-22): likely wrapping up or personal tasks
  if (LHour >= 8) and (LHour <= 10) then
    Result := 0.3
  else if (LHour >= 14) and (LHour <= 16) then
    Result := 0.2
  else
    Result := 0.1;
end;

function TAnticipationEngine.AnalyzeOperationSequence(
  const AContext: TAnticipationContext): Double;
begin
  // If there's recent history, the sequence provides some signal
  if Length(AContext.RecentHistory) >= 3 then
    Result := 0.3
  else if Length(AContext.RecentHistory) >= 1 then
    Result := 0.15
  else
    Result := 0.0;
end;

function TAnticipationEngine.AnalyzeContextual(
  const AContext: TAnticipationContext): Double;
begin
  // Domain context provides signal if we have an active intent
  if AContext.DomainContext.ActiveIntent <> '' then
    Result := 0.3
  else if AContext.DomainContext.DomainName <> '' then
    Result := 0.15
  else
    Result := 0.0;
end;

function TAnticipationEngine.AnalyzeHistorical(
  const AContext: TAnticipationContext): Double;
begin
  // Rapport familiarity indicates historical pattern strength
  if AContext.RapportProfile.Familiarity > 0.7 then
    Result := 0.3
  else if AContext.RapportProfile.Familiarity > 0.3 then
    Result := 0.15
  else
    Result := 0.05;
end;

function TAnticipationEngine.BuildEvidence(const AContext: TAnticipationContext;
  const ASources: TArray<TAnticipationSource>): string;
var
  LParts: TList<string>;
  LSource: TAnticipationSource;
begin
  LParts := TList<string>.Create;
  try
    for LSource in ASources do
      if Trim(LSource.Evidence) <> '' then
        LParts.Add(LSource.Evidence)
      else if Trim(LSource.SourceType) <> '' then
        LParts.Add('基于' + LSource.SourceType + '信号');

    if LParts.Count > 0 then
      Result := String.Join('；', LParts.ToArray)
    else
      Result := '基于综合分析推测';

    // Property 27: Evidence always non-empty
    if Result = '' then
      Result := '基于综合分析推测';
  finally
    LParts.Free;
  end;
end;

function TAnticipationEngine.BuildSource(const ASourceType, ASignal: string;
  AConfidence: Double; const AEvidence: string): TAnticipationSource;
begin
  Result.SourceType := ASourceType;
  Result.Signal := ASignal;
  Result.Confidence := EnsureRange(AConfidence, 0.0, 1.0);
  Result.Evidence := AEvidence;
end;

function TAnticipationEngine.DetermineIntent(
  const AContext: TAnticipationContext): string;
begin
  // Simple heuristic: use domain context or current input to guess intent
  if AContext.DomainContext.ActiveIntent <> '' then
    Result := AContext.DomainContext.ActiveIntent
  else if AContext.CurrentInput <> '' then
    Result := '继续: ' + Copy(AContext.CurrentInput, 1, 30)
  else if Length(AContext.RecentHistory) > 0 then
    Result := '延续上次操作'
  else
    Result := '开始新任务';
end;

function TAnticipationEngine.Predict(
  const AContext: TAnticipationContext): TAnticipationResult;
var
  LTemporal, LSequence, LContextual, LHistorical: Double;
  LTotalConfidence: Double;
  LSources: TList<TAnticipationSource>;
begin
  Result := Default(TAnticipationResult);
  Result.PredictionId := GeneratePredictionId;

  // Analyze each signal source
  LTemporal := AnalyzeTemporal(AContext);
  LSequence := AnalyzeOperationSequence(AContext);
  LContextual := AnalyzeContextual(AContext);
  LHistorical := AnalyzeHistorical(AContext);

  // Combine confidences (weighted average, capped at 1.0)
  LTotalConfidence := EnsureRange(
    LTemporal * 0.15 + LSequence * 0.30 + LContextual * 0.35 + LHistorical * 0.20,
    0.0, 1.0);
  Result.Confidence := LTotalConfidence;

  // Determine which sources contributed significantly
  LSources := TList<TAnticipationSource>.Create;
  try
    if LTemporal > 0.1 then
      LSources.Add(BuildSource('temporal', FormatDateTime('hh', Now),
        LTemporal, '基于当前时间段的使用模式'));
    if LSequence > 0.1 then
      LSources.Add(BuildSource('operation_sequence', 'recent_history',
        LSequence, '基于最近的操作序列'));
    if LContextual > 0.1 then
      LSources.Add(BuildSource('contextual', AContext.DomainContext.DomainName,
        LContextual, '基于当前上下文状态'));
    if LHistorical > 0.1 then
      LSources.Add(BuildSource('historical', AContext.UserId,
        LHistorical, '基于历史使用模式'));

    // Ensure at least one source
    if LSources.Count = 0 then
      LSources.Add(BuildSource('contextual', 'fallback', 0.05,
        '基于综合分析推测'));

    Result.Sources := LSources.ToArray;
    Result.Evidence := BuildEvidence(AContext, Result.Sources);
  finally
    LSources.Free;
  end;

  Result.IntentName := DetermineIntent(AContext);

  // Property 27: final guarantee
  if Result.Evidence = '' then
    Result.Evidence := '基于综合分析推测';
end;

procedure TAnticipationEngine.FeedbackPositive(const APredictionId: string);
var
  LRecord: TFeedbackRecord;
begin
  LRecord.PredictionId := APredictionId;
  LRecord.Positive := True;
  FFeedback.Add(LRecord);
end;

procedure TAnticipationEngine.FeedbackNegative(const APredictionId: string);
var
  LRecord: TFeedbackRecord;
begin
  LRecord.PredictionId := APredictionId;
  LRecord.Positive := False;
  FFeedback.Add(LRecord);
end;

end.
