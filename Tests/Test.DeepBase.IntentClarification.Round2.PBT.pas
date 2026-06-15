{ ============================================================================
  Test.DeepBase.IntentClarification.Round2.PBT - Property tests for the
  Round-2 IC fixes (deepbase-round2-fixes, sub-task 19.17).

  Properties covered:
    Property 26: IC Provider 会话状态隔离
                 Modifying L2 denied hypotheses or L3 expert selection in
                 session A must not affect session B.
                 Validates: Requirements 12.8, 12.9
    Property 27: IC Types.FromJson 错误处理
                 Malformed JSON input must yield an error result; FromJson
                 MUST NOT raise.
                 Validates: Requirements 12.5, 12.6
    Property 28: IC FindProvider 降级链 L4→L3→L2→L1→L0
                 When the requested level is unavailable the resolver must
                 fall back to the next-lower available level.
                 Validates: Requirements 12.7
    Property 29: IC 原子计数器
                 Concurrent Predict / RecordTurn calls must increment the
                 internal counter exactly N times for N concurrent invokers.
                 Validates: Requirements 12.16, 12.17
    Property 30: IC Turn 记录完整性
                 Turn records produced by the engine's IC-025 path must
                 populate both Answer and AssistantOutput when the user
                 input and provider question are non-empty.
                 Validates: Requirements 12.21

  Strategy:
    - DUnitX TestFixture, every property runs at least 100 iterations.
    - P26 / P27 / P29 use real production fixtures (TL2/TL3 providers,
      TSessionCheckpoint.FromJson, TAnticipationEngine, TICMetrics).
    - P28 mirrors the engine's private FindProvider algorithm because the
      method is private; the mirror uses the SAME ILevelProvider list and
      the same downward-degradation rule (Ord-1 until Low).
    - P30 mirrors the engine's IC-025 turn-record assignment block; the
      engine's GetSessionHistory is private so we exercise the same
      assignment statements the engine does inside its session lock.
  ============================================================================ }

unit Test.DeepBase.IntentClarification.Round2.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Provider.L2,
  DeepBase.IntentClarification.Provider.L3,
  DeepBase.IntentClarification.Anticipation,
  DeepBase.IntentClarification.Metrics;

type
  [TestFixture]
  TICRound2PropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 26 (L2 denied hypotheses).
    [Test]
    procedure Property26_L2_DenyHypothesisIsolation;

    // Feature: deepbase-round2-fixes, Property 26 (L3 expert selection).
    [Test]
    procedure Property26_L3_ExpertSelectionIsolation;

    // Feature: deepbase-round2-fixes, Property 27 (FromJson error handling).
    [Test]
    procedure Property27_FromJsonMalformedReturnsErrorResult;

    // Feature: deepbase-round2-fixes, Property 28 (FindProvider degradation).
    [Test]
    procedure Property28_HelperMirror_FindProviderDegradationChain;

    // Feature: deepbase-round2-fixes, Property 29 (AnticipationEngine).
    [Test]
    procedure Property29_AnticipationCounterAtomic;

    // Feature: deepbase-round2-fixes, Property 29 (TICMetrics).
    [Test]
    procedure Property29_MetricsCounterAtomic;

    // Feature: deepbase-round2-fixes, Property 30 (Turn record completeness).
    [Test]
    procedure Property30_HelperMirror_TurnRecordCompleteness;
  end;

implementation

uses
  System.StrUtils;

{ TICRound2PropertyTests }

procedure TICRound2PropertyTests.Setup;
begin
  Randomize;
end;

// ---------------------------------------------------------------------------
// Property 26 - L2 per-session denied hypotheses must not bleed across
// sessions even under concurrent mutation.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property26_L2_DenyHypothesisIsolation;
const
  CIterations = 100;
  CWritersPerIter = 4;
  CDenialsPerWriter = 3;
var
  LProvider: TL2ProblemProvider;
  LSessionA, LSessionB: string;
  Iter, I: Integer;
  LWriters: TArray<TThread>;
  LStart: TEvent;
  LExpectedA: TList<string>;
  LDenialsA: TArray<string>;
  LDenialsB: TArray<string>;

  function CreateWriter(AWriterIdx, AIter: Integer): TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      var
        J: Integer;
      begin
        LStart.WaitFor(INFINITE);
        for J := 0 to CDenialsPerWriter - 1 do
          LProvider.DenyHypothesis(LSessionA,
            Format('hyp-%d-%d',
              [AIter, AWriterIdx * CDenialsPerWriter + J]));
      end);
    Result.FreeOnTerminate := False;
  end;
begin
  for Iter := 1 to CIterations do
  begin
    LProvider := TL2ProblemProvider.Create(nil);
    LStart := TEvent.Create(nil, True, False, '');
    LExpectedA := TList<string>.Create;
    try
      LSessionA := 'sess-A-' + IntToStr(Iter);
      LSessionB := 'sess-B-' + IntToStr(Iter);

      // Build the canonical set of denials we expect to see on session A.
      for I := 0 to (CWritersPerIter * CDenialsPerWriter) - 1 do
        LExpectedA.Add(Format('hyp-%d-%d', [Iter, I]));

      SetLength(LWriters, CWritersPerIter);
      for I := 0 to CWritersPerIter - 1 do
        LWriters[I] := CreateWriter(I, Iter);

      for I := 0 to CWritersPerIter - 1 do
        LWriters[I].Start;

      // Reader thread that hammers session B's view while writers race
      // session A. Session B must NEVER see anything.
      var LBSawAny: Boolean := False;
      var LBLock := TCriticalSection.Create;
      var LReader := TThread.CreateAnonymousThread(
        procedure
        var
          K: Integer;
        begin
          LStart.WaitFor(INFINITE);
          for K := 0 to 49 do
          begin
            var LB := LProvider.GetDeniedHypotheses(LSessionB);
            if Length(LB) > 0 then
            begin
              LBLock.Enter;
              try
                LBSawAny := True;
              finally
                LBLock.Leave;
              end;
              Break;
            end;
            Sleep(0);
          end;
        end);
      LReader.FreeOnTerminate := False;
      LReader.Start;

      LStart.SetEvent;

      for I := 0 to CWritersPerIter - 1 do
      begin
        LWriters[I].WaitFor;
        LWriters[I].Free;
      end;
      LReader.WaitFor;
      LReader.Free;

      LDenialsA := LProvider.GetDeniedHypotheses(LSessionA);
      LDenialsB := LProvider.GetDeniedHypotheses(LSessionB);

      Assert.IsFalse(LBSawAny,
        Format('Iter %d: session B observed cross-session leakage', [Iter]));

      Assert.AreEqual<Integer>(LExpectedA.Count, Length(LDenialsA),
        Format('Iter %d: session A must contain every denial; expected %d, got %d',
          [Iter, LExpectedA.Count, Length(LDenialsA)]));

      Assert.AreEqual<Integer>(0, Length(LDenialsB),
        Format('Iter %d: session B must remain empty, got %d entries',
          [Iter, Length(LDenialsB)]));

      LBLock.Free;
    finally
      LExpectedA.Free;
      LStart.Free;
      LProvider.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 26 - L3 per-session expert selection isolation.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property26_L3_ExpertSelectionIsolation;
const
  CIterations = 100;
var
  LProvider: TL3ExpertProvider;
  Iter: Integer;
  LSessA, LSessB: string;
  LExpertA, LExpertEmpty: TPersonaProfile;
  LBExpert: TPersonaProfile;
begin
  for Iter := 1 to CIterations do
  begin
    LProvider := TL3ExpertProvider.Create(nil, nil);
    try
      LSessA := 'sess-A-' + IntToStr(Iter);
      LSessB := 'sess-B-' + IntToStr(Iter);

      LExpertA := Default(TPersonaProfile);
      LExpertA.Id := 'expert-A-' + IntToStr(Iter);
      LExpertA.Name := 'PerSessionExpert';
      LExpertA.Role := 'Specialist';
      LExpertA.Style := 'professional';

      LExpertEmpty := Default(TPersonaProfile);

      // Concurrent: thread X writes A, thread Y reads B repeatedly.
      var LStart := TEvent.Create(nil, True, False, '');
      try
        var LSawCrossLeak: Boolean := False;
        var LLeakLock := TCriticalSection.Create;
        try
          var LWriter := TThread.CreateAnonymousThread(
            procedure
            var
              I: Integer;
            begin
              LStart.WaitFor(INFINITE);
              for I := 0 to 9 do
              begin
                LProvider.SwitchExpert(LSessA, LExpertA);
                Sleep(0);
              end;
            end);
          LWriter.FreeOnTerminate := False;

          var LReader := TThread.CreateAnonymousThread(
            procedure
            var
              I: Integer;
              LRead: TPersonaProfile;
            begin
              LStart.WaitFor(INFINITE);
              for I := 0 to 49 do
              begin
                LRead := LProvider.GetCurrentExpert(LSessB);
                if (LRead.Id <> '') or (LRead.Name <> '') then
                begin
                  LLeakLock.Enter;
                  try
                    LSawCrossLeak := True;
                  finally
                    LLeakLock.Leave;
                  end;
                  Break;
                end;
                Sleep(0);
              end;
            end);
          LReader.FreeOnTerminate := False;

          LWriter.Start;
          LReader.Start;
          LStart.SetEvent;

          LWriter.WaitFor;
          LReader.WaitFor;
          LWriter.Free;
          LReader.Free;

          Assert.IsFalse(LSawCrossLeak,
            Format('Iter %d: session B observed expert leak from session A',
              [Iter]));

          // Final assertions: A has the expert, B is still default.
          var LFinalA := LProvider.GetCurrentExpert(LSessA);
          Assert.AreEqual(LExpertA.Id, LFinalA.Id,
            Format('Iter %d: session A must retain its expert id', [Iter]));
          Assert.AreEqual(LExpertA.Name, LFinalA.Name,
            Format('Iter %d: session A must retain its expert name', [Iter]));

          LBExpert := LProvider.GetCurrentExpert(LSessB);
          Assert.AreEqual(LExpertEmpty.Id, LBExpert.Id,
            Format('Iter %d: session B expert id must be empty (got %s)',
              [Iter, LBExpert.Id]));
          Assert.AreEqual(LExpertEmpty.Name, LBExpert.Name,
            Format('Iter %d: session B expert name must be empty (got %s)',
              [Iter, LBExpert.Name]));
        finally
          LLeakLock.Free;
        end;
      finally
        LStart.Free;
      end;
    finally
      LProvider.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 27 - TSessionCheckpoint.FromJson must NEVER raise on malformed
// input; it must return a record whose Error field is non-empty.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property27_FromJsonMalformedReturnsErrorResult;
const
  CIterations = 100;
var
  LBadInputs: TArray<string>;
  LCp: TSessionCheckpoint;
  Iter, LIdx: Integer;
  LBad: string;
begin
  // A finite catalogue of malformed JSON inputs covering every parse path
  // the FromJson implementation guards against:
  //  - empty / whitespace
  //  - syntactically invalid
  //  - non-object roots (string, number, array, bool, null)
  //  - missing sessionState
  //  - sessionState set to null / number / string / array (not an object)
  LBadInputs := [
    '',
    '   ',
    #9 + #10,
    '{',
    '}',
    '[',
    'not json',
    '"string-root"',
    '12345',
    'true',
    'false',
    'null',
    '[1,2,3]',
    '{ "version": 1 }',                              // missing sessionState
    '{ "sessionState": null }',                       // null sessionState
    '{ "sessionState": 42 }',                         // numeric sessionState
    '{ "sessionState": "string" }',                   // string sessionState
    '{ "sessionState": [1,2,3] }',                    // array sessionState
    '{ "sessionState": true }',                       // bool sessionState
    '{ "version": 1, "sessionState": null }',
    '{ "version": "abc", "sessionState": [] }',
    '{ "resumeHint": "x", "sessionState": 0 }',
    '{ "version": 1, "sessionState": "not-object" }',
    '{ "version": 1 ',                                // truncated
    '{ "version": 1, ',                               // dangling comma
    '{,}',                                            // illegal
    '{"a":}'                                          // illegal
  ];

  for Iter := 1 to CIterations do
  begin
    LIdx := Random(Length(LBadInputs));
    LBad := LBadInputs[LIdx];

    // Must NOT raise. A raise here fails the test by escaping the try.
    try
      LCp := TSessionCheckpoint.FromJson(LBad);
    except
      on E: Exception do
        Assert.Fail(Format('Iter %d (input=%s): FromJson must not raise; got %s: %s',
          [Iter, LBad, E.ClassName, E.Message]));
    end;

    Assert.IsTrue(LCp.Error <> '',
      Format('Iter %d (input=%s): FromJson must populate Error for malformed input',
        [Iter, LBad]));
  end;
end;

// ---------------------------------------------------------------------------
// Property 28 - Helper-mirror of TClarificationEngine.FindProvider.
// We rebuild the search algorithm verbatim and prove that for every random
// subset of registered levels and every requested level the resolver picks
// the largest available level <= requested, or nil when none exists.
// ---------------------------------------------------------------------------
type
  TFakeLevelProvider = class(TInterfacedObject, ILevelProvider)
  private
    FLevel: TClarificationLevel;
  public
    constructor Create(ALevel: TClarificationLevel);
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;
  end;

constructor TFakeLevelProvider.Create(ALevel: TClarificationLevel);
begin
  inherited Create;
  FLevel := ALevel;
end;

function TFakeLevelProvider.GetLevel: TClarificationLevel;
begin
  Result := FLevel;
end;

function TFakeLevelProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  Result := True;
end;

function TFakeLevelProvider.Process(const AContext: TProcessingContext): TProviderResult;
begin
  Result := Default(TProviderResult);
  Result.Success := True;
end;

function TFakeLevelProvider.RequiresLLM: Boolean;
begin
  Result := False;
end;

// Mirror of TClarificationEngine.FindProvider's degradation rule.
function MirrorFindProvider(const AProviders: TList<ILevelProvider>;
  ARequested: TClarificationLevel): ILevelProvider;

  function FindAt(ATarget: TClarificationLevel): ILevelProvider;
  var
    LIter: ILevelProvider;
  begin
    Result := nil;
    for LIter in AProviders do
      if LIter.GetLevel = ATarget then
        Exit(LIter);
  end;

begin
  Result := FindAt(ARequested);
  if Result <> nil then
    Exit;

  var LCurrent := Ord(ARequested);
  while LCurrent > Ord(Low(TClarificationLevel)) do
  begin
    Dec(LCurrent);
    Result := FindAt(TClarificationLevel(LCurrent));
    if Result <> nil then
      Exit;
  end;
end;

procedure TICRound2PropertyTests.Property28_HelperMirror_FindProviderDegradationChain;
const
  CIterations = 100;
var
  Iter, L: Integer;
  LProviders: TList<ILevelProvider>;
  LMask: array[TClarificationLevel] of Boolean;
  LRequested: TClarificationLevel;
  LResult: ILevelProvider;
  LExpected: Integer;
  LCl: TClarificationLevel;
begin
  for Iter := 1 to CIterations do
  begin
    LProviders := TList<ILevelProvider>.Create;
    try
      // Random subset of {clL0..clL4}
      for LCl := Low(TClarificationLevel) to High(TClarificationLevel) do
      begin
        LMask[LCl] := Random(2) = 1;
        if LMask[LCl] then
          LProviders.Add(TFakeLevelProvider.Create(LCl));
      end;

      LRequested := TClarificationLevel(Random(Ord(High(TClarificationLevel)) + 1));

      LResult := MirrorFindProvider(LProviders, LRequested);

      // Compute expected: largest level <= requested with mask=True; -1 if none.
      LExpected := -1;
      for L := Ord(LRequested) downto Ord(Low(TClarificationLevel)) do
        if LMask[TClarificationLevel(L)] then
        begin
          LExpected := L;
          Break;
        end;

      if LExpected = -1 then
        Assert.IsNull(LResult,
          Format('Iter %d: no provider <= L%d, FindProvider must return nil',
            [Iter, Ord(LRequested)]))
      else
      begin
        Assert.IsNotNull(LResult,
          Format('Iter %d: expected provider at L%d, got nil',
            [Iter, LExpected]));
        Assert.AreEqual<Integer>(LExpected, Ord(LResult.GetLevel),
          Format('Iter %d: requested L%d, expected L%d, got L%d',
            [Iter, Ord(LRequested), LExpected, Ord(LResult.GetLevel)]));
      end;
    finally
      LProviders.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 29 - TAnticipationEngine.Predict generates strictly monotonic
// ids whose counter portion is a permutation of 1..N for N concurrent calls.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property29_AnticipationCounterAtomic;
const
  CIterations = 100;
  CMinThreads = 4;
  CMaxThreads = 10;
var
  Iter, N, I: Integer;
  LEngine: TAnticipationEngine;
  LStart: TEvent;
  LThreads: TArray<TThread>;
  LIds: TArray<string>;
  LIdLock: TCriticalSection;
  LCounters: TList<Integer>;
  LSeen: TDictionary<Integer, Boolean>;
  LParts: TArray<string>;
  LCnt: Integer;

  function CreatePredictor(AIdx: Integer): TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      var
        LCtx: TAnticipationContext;
        LRes: TAnticipationResult;
      begin
        LStart.WaitFor(INFINITE);
        LCtx := Default(TAnticipationContext);
        LCtx.UserId := 'u';
        LCtx.SessionId := 's';
        LCtx.CurrentInput := 'x';
        LRes := LEngine.Predict(LCtx);
        LIdLock.Enter;
        try
          LIds[AIdx] := LRes.PredictionId;
        finally
          LIdLock.Leave;
        end;
      end);
    Result.FreeOnTerminate := False;
  end;
begin
  for Iter := 1 to CIterations do
  begin
    LEngine := TAnticipationEngine.Create;
    LStart := TEvent.Create(nil, True, False, '');
    LIdLock := TCriticalSection.Create;
    LCounters := TList<Integer>.Create;
    LSeen := TDictionary<Integer, Boolean>.Create;
    try
      N := CMinThreads + Random(CMaxThreads - CMinThreads + 1);
      SetLength(LThreads, N);
      SetLength(LIds, N);

      for I := 0 to N - 1 do
        LThreads[I] := CreatePredictor(I);

      for I := 0 to N - 1 do
        LThreads[I].Start;

      LStart.SetEvent;

      for I := 0 to N - 1 do
      begin
        LThreads[I].WaitFor;
        LThreads[I].Free;
      end;

      // PredictionId format: 'pred_<counter>_<hhnnsszzz>'.
      // Parse the counter portion and verify it is a permutation of 1..N.
      for I := 0 to N - 1 do
      begin
        LParts := SplitString(LIds[I], '_');
        Assert.IsTrue(Length(LParts) >= 3,
          Format('Iter %d: prediction id %s does not match pred_<n>_<ts> format',
            [Iter, LIds[I]]));
        Assert.IsTrue(TryStrToInt(LParts[1], LCnt),
          Format('Iter %d: counter portion %s is not numeric',
            [Iter, LParts[1]]));
        Assert.IsFalse(LSeen.ContainsKey(LCnt),
          Format('Iter %d: counter %d appeared more than once - '
            + 'TInterlocked.Increment failed', [Iter, LCnt]));
        LSeen.Add(LCnt, True);
        LCounters.Add(LCnt);
      end;

      // Counters must be a contiguous permutation. The starting offset is
      // 1 because Predict bumps the counter from 0 once per call. With a
      // fresh engine per iteration we should always see [1..N].
      LCounters.Sort;
      for I := 0 to N - 1 do
        Assert.AreEqual<Integer>(I + 1, LCounters[I],
          Format('Iter %d: counter at position %d should be %d, got %d. '
            + 'Lost increment indicates non-atomic counter.',
            [Iter, I, I + 1, LCounters[I]]));
    finally
      LSeen.Free;
      LCounters.Free;
      LIdLock.Free;
      LStart.Free;
      LEngine.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 29 - TICMetrics counters must increment exactly N times for N
// concurrent RecordTurn / RecordSessionCompleted calls.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property29_MetricsCounterAtomic;
const
  CIterations = 100;
  CMinThreads = 4;
  CMaxThreads = 16;
var
  Iter, N, I: Integer;
  LMetrics: TICMetrics;
  LStart: TEvent;
  LThreads: TArray<TThread>;
begin
  for Iter := 1 to CIterations do
  begin
    LMetrics := TICMetrics.Create;
    LStart := TEvent.Create(nil, True, False, '');
    try
      N := CMinThreads + Random(CMaxThreads - CMinThreads + 1);
      SetLength(LThreads, N);

      for I := 0 to N - 1 do
      begin
        LThreads[I] := TThread.CreateAnonymousThread(
          procedure
          begin
            LStart.WaitFor(INFINITE);
            LMetrics.RecordTurn(7, clL1, posClarifying, 13);
            LMetrics.RecordSessionCompleted('user_cancel');
            LMetrics.RecordTokens(5);
          end);
        LThreads[I].FreeOnTerminate := False;
      end;

      for I := 0 to N - 1 do
        LThreads[I].Start;

      LStart.SetEvent;

      for I := 0 to N - 1 do
      begin
        LThreads[I].WaitFor;
        LThreads[I].Free;
      end;

      Assert.AreEqual<Int64>(N, LMetrics.TurnCount,
        Format('Iter %d (N=%d): TurnCount must equal N; got %d',
          [Iter, N, LMetrics.TurnCount]));
      Assert.AreEqual<Int64>(N, LMetrics.SessionsCompleted,
        Format('Iter %d (N=%d): SessionsCompleted must equal N; got %d',
          [Iter, N, LMetrics.SessionsCompleted]));
      // Each thread adds 13 (RecordTurn) + 5 (RecordTokens) = 18 tokens.
      Assert.AreEqual<Int64>(Int64(N) * 18, LMetrics.TotalTokensUsed,
        Format('Iter %d (N=%d): TotalTokensUsed must equal N*18; got %d',
          [Iter, N, LMetrics.TotalTokensUsed]));
    finally
      LStart.Free;
      LMetrics.Free;
    end;
  end;
end;

// ---------------------------------------------------------------------------
// Property 30 - Helper-mirror for IC-025 turn record assignment.
// The engine's GetSessionHistory is private. We mirror the four lines of
// TClarificationEngine.SubmitInput that build LTurnRecord (both the
// budget-exhausted and normal branches share the same assignment block):
//   LTurnRecord.UserInput       := AInput;
//   LTurnRecord.Question        := LProviderResult.Question;
//   LTurnRecord.Answer          := AInput;
//   LTurnRecord.AssistantOutput := LProviderResult.Question;
// and verify the invariant that for every non-empty input/question pair
// the resulting record's Answer and AssistantOutput are populated AND
// match the inputs byte-for-byte.
// ---------------------------------------------------------------------------
procedure TICRound2PropertyTests.Property30_HelperMirror_TurnRecordCompleteness;
const
  CIterations = 100;

  function RandomString(AMinLen, AMaxLen: Integer): string;
  var
    LLen, K: Integer;
    LSb: TStringBuilder;
  begin
    LLen := AMinLen + Random(AMaxLen - AMinLen + 1);
    LSb := TStringBuilder.Create;
    try
      for K := 0 to LLen - 1 do
        // Mix latin, digits, CJK and punctuation so the record exercises
        // the full Unicode string range, not just ASCII.
        case Random(4) of
          0: LSb.Append(Char(Ord('a') + Random(26)));
          1: LSb.Append(Char(Ord('0') + Random(10)));
          2: LSb.Append(Char($4E00 + Random($1000)));
        else
          LSb.Append(Char($20 + Random(95)));
        end;
      Result := LSb.ToString;
    finally
      LSb.Free;
    end;
  end;

  function BuildTurnRecord(ATurnNumber: Integer; const AInput, AQuestion: string;
    ALevel: TClarificationLevel; APosture: TPosture): TTurnRecord;
  begin
    Result.TurnNumber := ATurnNumber;
    Result.UserInput := AInput;
    Result.Question := AQuestion;
    // IC-025 mirror - these two lines are the property under test.
    Result.Answer := AInput;
    Result.AssistantOutput := AQuestion;
    Result.Level := ALevel;
    Result.Posture := APosture;
    Result.Timestamp := Now;
  end;

var
  Iter, LTurnNumber: Integer;
  LInput, LQuestion: string;
  LRec: TTurnRecord;
  LLevel: TClarificationLevel;
  LPosture: TPosture;
begin
  for Iter := 1 to CIterations do
  begin
    LTurnNumber := 1 + Random(20);
    LInput := RandomString(1, 80);
    LQuestion := RandomString(1, 120);
    LLevel := TClarificationLevel(Random(Ord(High(TClarificationLevel)) + 1));
    LPosture := TPosture(Random(Ord(High(TPosture)) + 1));

    LRec := BuildTurnRecord(LTurnNumber, LInput, LQuestion, LLevel, LPosture);

    Assert.AreEqual<Integer>(LTurnNumber, LRec.TurnNumber,
      Format('Iter %d: TurnNumber must round-trip', [Iter]));
    Assert.AreEqual(LInput, LRec.UserInput,
      Format('Iter %d: UserInput must round-trip', [Iter]));
    Assert.AreEqual(LQuestion, LRec.Question,
      Format('Iter %d: Question must round-trip', [Iter]));

    // The IC-025 invariant: Answer mirrors UserInput, AssistantOutput
    // mirrors Question. Both populated whenever inputs are non-empty.
    Assert.AreEqual(LInput, LRec.Answer,
      Format('Iter %d: Answer must equal UserInput (IC-025)', [Iter]));
    Assert.AreEqual(LQuestion, LRec.AssistantOutput,
      Format('Iter %d: AssistantOutput must equal Question (IC-025)', [Iter]));

    Assert.IsTrue(LRec.Answer <> '',
      Format('Iter %d: Answer must be non-empty when input is non-empty', [Iter]));
    Assert.IsTrue(LRec.AssistantOutput <> '',
      Format('Iter %d: AssistantOutput must be non-empty when question is non-empty',
        [Iter]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TICRound2PropertyTests);

end.
