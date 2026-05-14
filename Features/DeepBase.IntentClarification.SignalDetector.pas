unit DeepBase.IntentClarification.SignalDetector;

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// 信号检测器 - 每轮次运行，检测用户行为中的五种信号。
  /// 使用启发式规则（无 LLM 依赖）。
  /// Property 22: 所有信号置信度在 [0.0, 1.0] 范围内。
  /// Requirements: 8.1-8.6
  /// </summary>
  TSignalDetector = class
  private
    function DetectHesitation(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TDetectedSignal;
    function DetectContradiction(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TDetectedSignal;
    function DetectFrustration(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TDetectedSignal;
    function DetectAvoidance(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TDetectedSignal;
    function DetectBreakthrough(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TDetectedSignal;
    function ClampConfidence(AValue: Double): Double;
  public
    /// <summary>
    /// Detects behavioral signals from user input and conversation history.
    /// Runs every turn. Returns only signals with confidence > 0.
    /// </summary>
    function Detect(const AInput: string;
      const AHistory: TArray<TTurnRecord>): TArray<TDetectedSignal>;
  end;

implementation

function CountToken(const AText, AToken: string): Integer;
var
  LPos: Integer;
  LStart: Integer;
begin
  Result := 0;
  if (AText = '') or (AToken = '') then
    Exit;

  LStart := 1;
  repeat
    LPos := Pos(AToken, Copy(AText, LStart, MaxInt));
    if LPos <= 0 then
      Break;
    Inc(Result);
    Inc(LStart, LPos + Length(AToken) - 1);
  until LStart > Length(AText);
end;

{ TSignalDetector }

function TSignalDetector.ClampConfidence(AValue: Double): Double;
begin
  Result := EnsureRange(AValue, 0.0, 1.0);
end;

function TSignalDetector.Detect(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TArray<TDetectedSignal>;
var
  LSignals: TList<TDetectedSignal>;
  LSig: TDetectedSignal;
begin
  LSignals := TList<TDetectedSignal>.Create;
  try
    LSig := DetectHesitation(AInput, AHistory);
    if LSig.Confidence > 0.0 then
      LSignals.Add(LSig);

    LSig := DetectContradiction(AInput, AHistory);
    if LSig.Confidence > 0.0 then
      LSignals.Add(LSig);

    LSig := DetectFrustration(AInput, AHistory);
    if LSig.Confidence > 0.0 then
      LSignals.Add(LSig);

    LSig := DetectAvoidance(AInput, AHistory);
    if LSig.Confidence > 0.0 then
      LSignals.Add(LSig);

    LSig := DetectBreakthrough(AInput, AHistory);
    if LSig.Confidence > 0.0 then
      LSignals.Add(LSig);

    Result := LSignals.ToArray;

    // Phase 2 Logging: report detected signals
    if LSignals.Count > 0 then
      Log(ltDebug, Format('IC.Signal: Detected %d signals', [LSignals.Count]));
  finally
    LSignals.Free;
  end;
end;

function TSignalDetector.DetectHesitation(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TDetectedSignal;
var
  LConfidence: Double;
  LEvidence: string;
  LTrimmed: string;
begin
  Result := Default(TDetectedSignal);
  Result.Kind := skHesitation;
  Result.DetectedAt := Now;
  LConfidence := 0.0;
  LEvidence := '';
  LTrimmed := Trim(AInput);

  // Hesitation markers: "嗯", "呃", "不确定", question marks
  if LTrimmed.Contains('嗯') or LTrimmed.Contains('呃') then
  begin
    LConfidence := LConfidence + 0.4;
    LEvidence := 'filler_words';
  end;

  if LTrimmed.Contains('不确定') or LTrimmed.Contains('不太清楚') then
  begin
    LConfidence := LConfidence + 0.3;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'uncertainty_expression';
  end;

  // Multiple question marks suggest uncertainty
  if (CountToken(LTrimmed, '?') + CountToken(LTrimmed, '？')) >= 2 then
  begin
    LConfidence := LConfidence + 0.2;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'multiple_questions';
  end;

  // Short input after longer history entries suggests hesitation
  if (Length(AHistory) > 0) and (Length(LTrimmed) < 5) and
     (Length(AHistory[High(AHistory)].UserInput) > 20) then
  begin
    LConfidence := LConfidence + 0.3;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'short_after_long';
  end;

  Result.Confidence := ClampConfidence(LConfidence);
  Result.Evidence := LEvidence;

  if Result.Confidence > 0 then
    Log(ltDebug, Format('IC.Signal: Hesitation detected (conf=%.2f, evidence=%s)',
      [Result.Confidence, LEvidence]));
end;

function TSignalDetector.DetectContradiction(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TDetectedSignal;
var
  LConfidence: Double;
  LEvidence: string;
  LTrimmed: string;
  I: Integer;
begin
  Result := Default(TDetectedSignal);
  Result.Kind := skContradiction;
  Result.DetectedAt := Now;
  LConfidence := 0.0;
  LEvidence := '';
  LTrimmed := Trim(AInput).ToLower;

  // Contradiction keywords
  if LTrimmed.Contains('不是') or LTrimmed.Contains('不对') or
     LTrimmed.Contains('错了') or LTrimmed.Contains('相反') then
  begin
    LConfidence := LConfidence + 0.3;
    LEvidence := 'negation_keywords';
  end;

  // "其实" or "实际上" often precedes a correction
  if LTrimmed.Contains('其实') or LTrimmed.Contains('实际上') then
  begin
    LConfidence := LConfidence + 0.3;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'correction_markers';
  end;

  // Check if input directly negates a recent history entry (simple keyword overlap)
  if Length(AHistory) > 0 then
  begin
    for I := Max(0, Length(AHistory) - 3) to High(AHistory) do
    begin
      if LTrimmed.Contains('不要') and
         AHistory[I].UserInput.ToLower.Contains('要') then
      begin
        LConfidence := LConfidence + 0.3;
        if LEvidence <> '' then LEvidence := LEvidence + ',';
        LEvidence := LEvidence + 'negates_previous';
        Break;
      end;
    end;
  end;

  Result.Confidence := ClampConfidence(LConfidence);
  Result.Evidence := LEvidence;

  if Result.Confidence > 0 then
    Log(ltDebug, Format('IC.Signal: Contradiction detected (conf=%.2f, evidence=%s)',
      [Result.Confidence, LEvidence]));
end;

function TSignalDetector.DetectFrustration(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TDetectedSignal;
var
  LConfidence: Double;
  LEvidence: string;
  LTrimmed: string;
  I, LSimilarCount: Integer;
begin
  Result := Default(TDetectedSignal);
  Result.Kind := skFrustration;
  Result.DetectedAt := Now;
  LConfidence := 0.0;
  LEvidence := '';
  LTrimmed := Trim(AInput);

  // Frustration keywords
  if LTrimmed.Contains('算了') or LTrimmed.Contains('不管了') or
     LTrimmed.Contains('烦') or LTrimmed.Contains('够了') then
  begin
    LConfidence := LConfidence + 0.5;
    LEvidence := 'frustration_keywords';
  end;

  // Very short response after longer previous inputs
  if (Length(AHistory) > 1) and (Length(LTrimmed) <= 3) and
     (Length(AHistory[High(AHistory)].UserInput) > 15) then
  begin
    LConfidence := LConfidence + 0.2;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'terse_response';
  end;

  // Repeated similar inputs (user keeps saying the same thing)
  if Length(AHistory) >= 2 then
  begin
    LSimilarCount := 0;
    for I := Max(0, Length(AHistory) - 3) to High(AHistory) do
    begin
      if AHistory[I].UserInput.ToLower = LTrimmed.ToLower then
        Inc(LSimilarCount);
    end;
    if LSimilarCount >= 1 then
    begin
      LConfidence := LConfidence + 0.4;
      if LEvidence <> '' then LEvidence := LEvidence + ',';
      LEvidence := LEvidence + 'repeated_input';
    end;
  end;

  Result.Confidence := ClampConfidence(LConfidence);
  Result.Evidence := LEvidence;

  if Result.Confidence > 0 then
    Log(ltDebug, Format('IC.Signal: Frustration detected (conf=%.2f, evidence=%s)',
      [Result.Confidence, LEvidence]));
end;

function TSignalDetector.DetectAvoidance(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TDetectedSignal;
var
  LConfidence: Double;
  LEvidence: string;
  LTrimmed: string;
  LLastQuestion: string;
begin
  Result := Default(TDetectedSignal);
  Result.Kind := skAvoidance;
  Result.DetectedAt := Now;
  LConfidence := 0.0;
  LEvidence := '';
  LTrimmed := Trim(AInput).ToLower;

  // Topic change markers
  if LTrimmed.Contains('换个') or LTrimmed.Contains('别的') or
     LTrimmed.Contains('另外') or LTrimmed.Contains('先不说这个') then
  begin
    LConfidence := LConfidence + 0.5;
    LEvidence := 'topic_change_markers';
  end;

  // Ignoring previous question: if last turn had a question and user
  // responds with something completely unrelated (very short or off-topic)
  if Length(AHistory) > 0 then
  begin
    LLastQuestion := AHistory[High(AHistory)].Question;
    if (LLastQuestion <> '') and (Length(LTrimmed) > 0) then
    begin
      // Simple heuristic: if the response doesn't share any significant
      // words with the question, it might be avoidance
      if (Length(LTrimmed) < 4) and (not LTrimmed.Contains('是'))
         and (not LTrimmed.Contains('好')) then
      begin
        LConfidence := LConfidence + 0.2;
        if LEvidence <> '' then LEvidence := LEvidence + ',';
        LEvidence := LEvidence + 'ignoring_question';
      end;
    end;
  end;

  Result.Confidence := ClampConfidence(LConfidence);
  Result.Evidence := LEvidence;

  if Result.Confidence > 0 then
    Log(ltDebug, Format('IC.Signal: Avoidance detected (conf=%.2f, evidence=%s)',
      [Result.Confidence, LEvidence]));
end;

function TSignalDetector.DetectBreakthrough(const AInput: string;
  const AHistory: TArray<TTurnRecord>): TDetectedSignal;
var
  LConfidence: Double;
  LEvidence: string;
  LTrimmed: string;
begin
  Result := Default(TDetectedSignal);
  Result.Kind := skBreakthrough;
  Result.DetectedAt := Now;
  LConfidence := 0.0;
  LEvidence := '';
  LTrimmed := Trim(AInput);

  // Breakthrough keywords
  if LTrimmed.Contains('对！') or LTrimmed.Contains('对!') or
     LTrimmed.Contains('就是这个') or LTrimmed.Contains('明白了') or
     LTrimmed.Contains('懂了') then
  begin
    LConfidence := LConfidence + 0.6;
    LEvidence := 'breakthrough_keywords';
  end;

  // Exclamation + positive keywords
  if (LTrimmed.Contains('！') or LTrimmed.Contains('!')) and
     (LTrimmed.Contains('好') or LTrimmed.Contains('对') or
      LTrimmed.Contains('是') or LTrimmed.Contains('行')) then
  begin
    LConfidence := LConfidence + 0.3;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'exclamation_positive';
  end;

  // "原来" suggests realization
  if LTrimmed.Contains('原来') then
  begin
    LConfidence := LConfidence + 0.2;
    if LEvidence <> '' then LEvidence := LEvidence + ',';
    LEvidence := LEvidence + 'realization_marker';
  end;

  Result.Confidence := ClampConfidence(LConfidence);
  Result.Evidence := LEvidence;

  if Result.Confidence > 0 then
    Log(ltDebug, Format('IC.Signal: Breakthrough detected (conf=%.2f, evidence=%s)',
      [Result.Confidence, LEvidence]));
end;

end.
