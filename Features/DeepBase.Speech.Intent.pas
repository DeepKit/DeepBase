{ ============================================================================
  DeepBase.Speech.Intent
  ---------------------------------------------------------------------------
  Version     : 1.1
  Description : Rule-based intent parser with injectable LLM fallback.
                Matches user text against registered patterns, extracts slots.
                If no rule matches and an LLM backend has been registered via
                RegisterLLMBackend, delegates to it with a timeout.
  Thread Safety: RegisterRule / Parse / RegisterLLMBackend are thread-safe.
  ============================================================================ }

unit DeepBase.Speech.Intent;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs,
  System.Generics.Collections, System.Generics.Defaults,
  System.RegularExpressions;

type
  TIntentSlot = record
    Name: string;
    Value: string;
  end;

  TIntentResult = record
    Intent: string;          // e.g. 'open_app', 'play_music', 'unknown'
    Confidence: Double;      // 0.0 - 1.0
    Slots: TArray<TIntentSlot>;
    Source: string;          // 'rule' | 'llm' | 'llm_unsupported' | 'llm_unavailable'
    Reason: string;          // Optional explanation from LLM
  end;

  TSlotExtractor = reference to function(const AText: string): TArray<TIntentSlot>;

  TIntentRule = record
    Pattern: string;         // Regex pattern
    Intent: string;          // Intent name to return on match
    SlotExtractor: TSlotExtractor;
    Priority: Integer;       // Lower = higher priority
  end;

  /// <summary>
  /// Pluggable LLM fallback callback. Receives the user text, locale,
  /// timeout budget and a hint of already-registered rule intents.
  /// Must return a JSON object of the shape:
  ///   {"intent": string, "confidence": 0..1, "slots": [{"name":..,"value":..}], "reason": string}
  /// On error raise an exception — Parse will catch it and return llm_unavailable.
  /// </summary>
  TIntentLLMBackend = reference to function(const AText, ALocale: string;
    ATimeoutMs: Integer; const ARegisteredIntents: TArray<string>): string;

  TDeepBaseIntentParser = class
  private
    FLock: TCriticalSection;
    FRules: TList<TIntentRule>;
    FLLMEnabled: Boolean;
    FLLMTimeoutMs: Integer;
    FLLMBackend: TIntentLLMBackend;
    class var FGlobalLock: TCriticalSection;
    class var FGlobalBackend: TIntentLLMBackend;
  public
    constructor Create;
    destructor Destroy; override;
    class constructor Create;
    class destructor Destroy;

    /// <summary>
    /// Register a pattern-based intent rule.
    /// Pattern is a Delphi regex. If matched, returns the specified intent.
    /// SlotExtractor is optional — extracts named slots from the matched text.
    /// </summary>
    procedure RegisterRule(const APattern, AIntent: string;
      ASlotExtractor: TSlotExtractor = nil; APriority: Integer = 100);

    /// <summary>
    /// Parse user text and return intent + slots.
    /// First tries rule matching (by priority). If no match and LLM enabled
    /// with a registered backend, delegates to the backend with timeout.
    /// Source returned:
    ///   'rule'             — matched a registered rule
    ///   'llm'              — backend returned a result
    ///   'llm_unsupported'  — LLMEnabled set but no backend registered
    ///   'llm_unavailable'  — backend raised or timed out
    ///   ''                 — input empty
    /// </summary>
    function Parse(const AText: string; const ALocale: string = 'zh-CN'): TIntentResult;

    /// <summary>
    /// Clear all registered rules.
    /// </summary>
    procedure ClearRules;

    /// <summary>Number of registered rules.</summary>
    function RuleCount: Integer;

    /// <summary>
    /// Register an LLM backend for fallback on this instance.
    /// Pass nil to unregister.
    /// </summary>
    procedure RegisterLLMBackend(const ABackend: TIntentLLMBackend);

    /// <summary>
    /// Register a default LLM backend shared by all new parser instances.
    /// Instance-level RegisterLLMBackend overrides the global backend.
    /// </summary>
    class procedure RegisterGlobalLLMBackend(const ABackend: TIntentLLMBackend);

    /// <summary>
    /// True iff an LLM backend is available (instance or global).
    /// </summary>
    function HasLLMBackend: Boolean;

    /// <summary>
    /// Controls whether Parse attempts LLM fallback. Setting True without
    /// a registered backend simply makes Parse return Source='llm_unsupported'.
    /// </summary>
    property LLMEnabled: Boolean read FLLMEnabled write FLLMEnabled;
    property LLMTimeoutMs: Integer read FLLMTimeoutMs write FLLMTimeoutMs;
  end;

var
  GlobalIntentParser: TDeepBaseIntentParser;

implementation

uses
  DeepBase.Speech.Policy;

function ExtractJsonString(const AJson, AKey: string): string;
var
  LKey, LRest: string;
  LStart, LEnd: Integer;
  LInStr: Boolean;
  LCh: Char;
  LBuf: TStringBuilder;
begin
  Result := '';
  LKey := '"' + AKey + '"';
  LStart := Pos(LKey, AJson);
  if LStart = 0 then Exit;
  LRest := Copy(AJson, LStart + Length(LKey), Length(AJson));
  LStart := Pos(':', LRest);
  if LStart = 0 then Exit;
  LRest := Copy(LRest, LStart + 1, Length(LRest));
  LStart := Pos('"', LRest);
  if LStart = 0 then Exit;
  LBuf := TStringBuilder.Create;
  try
    LInStr := False;
    LEnd := LStart;
    while LEnd <= Length(LRest) do
    begin
      LCh := LRest[LEnd];
      if not LInStr then
      begin
        if LCh = '"' then LInStr := True;
        Inc(LEnd);
        Continue;
      end;
      if LCh = '\' then
      begin
        if LEnd < Length(LRest) then
        begin
          case LRest[LEnd + 1] of
            '"', '\', '/': LBuf.Append(LRest[LEnd + 1]);
            'n': LBuf.Append(#10);
            'r': LBuf.Append(#13);
            't': LBuf.Append(#9);
          else
            LBuf.Append(LRest[LEnd + 1]);
          end;
          Inc(LEnd, 2);
        end
        else Inc(LEnd);
        Continue;
      end;
      if LCh = '"' then Break;
      LBuf.Append(LCh);
      Inc(LEnd);
    end;
    Result := LBuf.ToString;
  finally
    LBuf.Free;
  end;
end;

function ExtractJsonNumber(const AJson, AKey: string): Double;
var
  LKey, LRest, LNum: string;
  LStart, LEnd: Integer;
  LFmt: TFormatSettings;
begin
  Result := -1;
  LKey := '"' + AKey + '"';
  LStart := Pos(LKey, AJson);
  if LStart = 0 then Exit;
  LRest := Copy(AJson, LStart + Length(LKey), Length(AJson));
  LStart := Pos(':', LRest);
  if LStart = 0 then Exit;
  LRest := Copy(LRest, LStart + 1, Length(LRest));
  LStart := 1;
  while (LStart <= Length(LRest)) and CharInSet(LRest[LStart], [' ', #9, #10, #13]) do
    Inc(LStart);
  if LStart > Length(LRest) then Exit;
  if LRest[LStart] = '"' then
  begin
    Inc(LStart);
    LEnd := LStart;
    while (LEnd <= Length(LRest)) and (LRest[LEnd] <> '"') do
      Inc(LEnd);
    LNum := Copy(LRest, LStart, LEnd - LStart);
  end
  else
  begin
    LEnd := LStart;
    while (LEnd <= Length(LRest)) and
      not CharInSet(LRest[LEnd], [',', '}', ']', ' ', #9, #10, #13]) do
      Inc(LEnd);
    LNum := Copy(LRest, LStart, LEnd - LStart);
  end;
  LFmt := TFormatSettings.Invariant;
  if not TryStrToFloat(LNum, Result, LFmt) then
    Result := -1;
end;

{ TDeepBaseIntentParser }

class constructor TDeepBaseIntentParser.Create;
begin
  FGlobalLock := TCriticalSection.Create;
end;

class destructor TDeepBaseIntentParser.Destroy;
begin
  FreeAndNil(FGlobalLock);
end;

constructor TDeepBaseIntentParser.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FRules := TList<TIntentRule>.Create;
  FLLMEnabled := False;
  FLLMTimeoutMs := 5000;
  FLLMBackend := nil;
end;

destructor TDeepBaseIntentParser.Destroy;
begin
  // Clear backend reference outside the lock (it may hold a reference to us)
  FLLMBackend := nil;
  FreeAndNil(FRules);
  FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseIntentParser.RegisterRule(const APattern, AIntent: string;
  ASlotExtractor: TSlotExtractor; APriority: Integer);
var
  LRule: TIntentRule;
begin
  LRule.Pattern := APattern;
  LRule.Intent := AIntent;
  LRule.SlotExtractor := ASlotExtractor;
  LRule.Priority := APriority;

  FLock.Enter;
  try
    FRules.Add(LRule);
    // Sort by priority (stable sort preserves insertion order for equal priority)
    FRules.Sort(TComparer<TIntentRule>.Construct(
      function(const L, R: TIntentRule): Integer
      begin
        Result := L.Priority - R.Priority;
      end));
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseIntentParser.RegisterLLMBackend(const ABackend: TIntentLLMBackend);
begin
  FLock.Enter;
  try
    FLLMBackend := ABackend;
  finally
    FLock.Leave;
  end;
end;

class procedure TDeepBaseIntentParser.RegisterGlobalLLMBackend(
  const ABackend: TIntentLLMBackend);
begin
  FGlobalLock.Enter;
  try
    FGlobalBackend := ABackend;
  finally
    FGlobalLock.Leave;
  end;
end;

function TDeepBaseIntentParser.HasLLMBackend: Boolean;
begin
  FLock.Enter;
  try
    Result := Assigned(FLLMBackend);
    if not Result then
    begin
      FGlobalLock.Enter;
      try
        Result := Assigned(FGlobalBackend);
      finally
        FGlobalLock.Leave;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseIntentParser.Parse(const AText: string; const ALocale: string): TIntentResult;
var
  LRule: TIntentRule;
  LMatch: TMatch;
  LBackend: TIntentLLMBackend;
  LSnapshotIntents: TArray<string>;
  LIntentCount, I: Integer;
  LJson, LReason: string;
  LConf: Double;
begin
  Result.Intent := 'unknown';
  Result.Confidence := 0;
  Result.Slots := nil;
  Result.Source := '';
  Result.Reason := '';

  if Trim(AText) = '' then Exit;

  FLock.Enter;
  try
    for LRule in FRules do
    begin
      LMatch := TRegEx.Match(AText, LRule.Pattern, [roIgnoreCase]);
      if LMatch.Success then
      begin
        Result.Intent := LRule.Intent;
        Result.Confidence := 0.9; // Rule match = high confidence
        Result.Source := 'rule';
        if Assigned(LRule.SlotExtractor) then
          Result.Slots := LRule.SlotExtractor(AText);
        Exit;
      end;
    end;

    // No rule matched. Snapshot state needed for LLM fallback.
    LBackend := FLLMBackend;
    if not Assigned(LBackend) then
    begin
      FGlobalLock.Enter;
      try
        LBackend := FGlobalBackend;
      finally
        FGlobalLock.Leave;
      end;
    end;
    LIntentCount := FRules.Count;
    SetLength(LSnapshotIntents, LIntentCount);
    for I := 0 to LIntentCount - 1 do
      LSnapshotIntents[I] := FRules[I].Intent;
  finally
    FLock.Leave;
  end;

  // No rule matched — try LLM fallback
  if FLLMEnabled and TSpeechPolicy.IsAllowed(SPEECH_GATE_INTENT_LLM) then
  begin
    if not Assigned(LBackend) then
    begin
      Result.Source := 'llm_unsupported';
      Exit;
    end;

    try
      LJson := LBackend(AText, ALocale, FLLMTimeoutMs, LSnapshotIntents);
    except
      on E: Exception do
      begin
        Result.Source := 'llm_unavailable';
        Result.Reason := E.Message;
        Exit;
      end;
    end;

    // Minimal JSON extraction — tolerant to missing fields.
    Result.Source := 'llm';
    Result.Intent := ExtractJsonString(LJson, 'intent');
    if Result.Intent = '' then Result.Intent := 'unknown';
    LReason := ExtractJsonString(LJson, 'reason');
    Result.Reason := LReason;
    LConf := ExtractJsonNumber(LJson, 'confidence');
    if LConf < 0 then LConf := 0
    else if LConf > 1 then LConf := 1;
    Result.Confidence := LConf;
    // Slots are not parsed here; applications that need them can register
    // a SlotExtractor on the matched rule, or parse the raw JSON via Reason.
  end;
end;

procedure TDeepBaseIntentParser.ClearRules;
begin
  FLock.Enter;
  try
    FRules.Clear;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseIntentParser.RuleCount: Integer;
begin
  FLock.Enter;
  try
    Result := FRules.Count;
  finally
    FLock.Leave;
  end;
end;

initialization
  GlobalIntentParser := TDeepBaseIntentParser.Create;

finalization
  FreeAndNil(GlobalIntentParser);

end.
