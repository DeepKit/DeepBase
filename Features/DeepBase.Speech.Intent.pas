{ ============================================================================
  DeepBase.Speech.Intent
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Rule-based intent parser with optional LLM fallback.
                Matches user text against registered patterns, extracts slots.
                If no rule matches and LLM is enabled, delegates to DeepLLM.
  Thread Safety: RegisterRule is thread-safe. Parse is thread-safe.
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
    Source: string;          // 'rule' or 'llm'
  end;

  TSlotExtractor = reference to function(const AText: string): TArray<TIntentSlot>;

  TIntentRule = record
    Pattern: string;         // Regex pattern
    Intent: string;          // Intent name to return on match
    SlotExtractor: TSlotExtractor;
    Priority: Integer;       // Lower = higher priority
  end;

  TDeepBaseIntentParser = class
  private
    FLock: TCriticalSection;
    FRules: TList<TIntentRule>;
    FLLMEnabled: Boolean;
    FLLMTimeoutMs: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    /// Register a pattern-based intent rule.
    /// Pattern is a Delphi regex. If matched, returns the specified intent.
    /// SlotExtractor is optional — extracts named slots from the matched text.
    /// </summary>
    procedure RegisterRule(const APattern, AIntent: string;
      ASlotExtractor: TSlotExtractor = nil; APriority: Integer = 100);

    /// <summary>
    /// Parse user text and return intent + slots.
    /// First tries rule matching (by priority). If no match and LLM enabled,
    /// falls back to LLM (not implemented in v1 — returns 'unknown').
    /// </summary>
    function Parse(const AText: string; const ALocale: string = 'zh-CN'): TIntentResult;

    /// <summary>
    /// Clear all registered rules.
    /// </summary>
    procedure ClearRules;

    /// <summary>Number of registered rules.</summary>
    function RuleCount: Integer;

    property LLMEnabled: Boolean read FLLMEnabled write FLLMEnabled;
    property LLMTimeoutMs: Integer read FLLMTimeoutMs write FLLMTimeoutMs;
  end;

var
  GlobalIntentParser: TDeepBaseIntentParser;

implementation

uses
  DeepBase.Speech.Policy;

constructor TDeepBaseIntentParser.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FRules := TList<TIntentRule>.Create;
  FLLMEnabled := False;
  FLLMTimeoutMs := 5000;
end;

destructor TDeepBaseIntentParser.Destroy;
begin
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

function TDeepBaseIntentParser.Parse(const AText: string; const ALocale: string): TIntentResult;
var
  LRule: TIntentRule;
  LMatch: TMatch;
begin
  Result.Intent := 'unknown';
  Result.Confidence := 0;
  Result.Slots := nil;
  Result.Source := '';

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
  finally
    FLock.Leave;
  end;

  // No rule matched — try LLM fallback
  if FLLMEnabled and TSpeechPolicy.IsAllowed(SPEECH_GATE_INTENT_LLM) then
  begin
    // TODO: Call DeepBase.LLM.Client with timeout FLLMTimeoutMs
    // For v1, just return unknown
    Result.Intent := 'unknown';
    Result.Confidence := 0;
    Result.Source := 'llm_unavailable';
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
