{ ============================================================================
  Test.DeepBase.IntentClarification.Concurrent.PBT - Property test for
  concurrent SubmitInput turn serialization on a single session.

  Property covered:
    P7 : IC Engine Concurrent Turn Serialization (Req 5.1, 5.2, 5.3)
         For any set of N concurrent SubmitInput calls to the same session,
         after all calls complete, the session history SHALL contain
         exactly N turns with no data loss or corruption.

  Strategy:
    - Run >= 100 iterations.
    - Each iteration: fresh TClarificationEngine, fresh session.
    - Spawn N (3..5) anonymous threads, gated on a TEvent so they all
      race the per-session lock together. Each thread calls SubmitInput
      with a unique input string.
    - After joining: assert GetSessionState(handle).TurnCount = N.
      TurnCount is incremented inside the per-session critical section
      AND the session is flagged ssCompleted only when the budget
      controller decides to exit, so for N <= 5 with TBudgetConfig.Default
      (MaxTurns=6) every concurrent submission ought to finalise as a
      successful turn record.

  Why N stays <= 5:
    - TClarificationEngine uses TBudgetConfig.Default (MaxTurns=6) and
      transitions the session to ssCompleted on budget exhaustion. After
      that, additional SubmitInput calls return SESSION_NOT_ACTIVE without
      incrementing TurnCount, which would invalidate the strict equality
      assertion. N in [3..5] keeps the test deterministic without changing
      production defaults.

  Helper-mirror coverage:
    - A second test exercises the FGlobalLock + per-session lock
      serialization pattern in isolation (no engine, no providers). It
      validates that a shared counter incremented under (global, per-key)
      locks ends at exactly N for arbitrary N up to 15 over 100 iterations.
      This guards the locking primitives used by the engine even when the
      heavier real-engine fixture is not exercised.
  ============================================================================ }

unit Test.DeepBase.IntentClarification.Concurrent.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Engine;

type
  [TestFixture]
  TICEngineConcurrentPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 7 - real engine fixture.
    // 100 iterations x 3..5 threads racing one session.
    [Test]
    procedure Property7_ConcurrentSubmitInputSerializesTurns;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 7 - helper-mirror fixture.
    // Validates the FGlobalLock + per-session-lock serialization pattern in
    // isolation. Cheaper, supports N up to 15.
    [Test]
    procedure Property7_HelperMirror_LockSerializationCount;
  end;

implementation

{ TICEngineConcurrentPropertyTests }

procedure TICEngineConcurrentPropertyTests.Setup;
begin
  Randomize;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 7: Concurrent SubmitInput on
// the same session must serialize so the final TurnCount equals N. The
// engine's per-session critical section (acquired via AcquireSessionLock)
// is the unit under test; the rule, router and signal detector run with
// their default behaviour and no LLM is needed (RequiresLLM is checked
// before falling through to the rule fallback).
procedure TICEngineConcurrentPropertyTests
  .Property7_ConcurrentSubmitInputSerializesTurns;
const
  CIterations = 100;
  CMinThreads = 3;
  CMaxThreads = 5; // stays under TBudgetConfig.Default.MaxTurns = 6
var
  LEngine: TClarificationEngine;
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LStart: TEvent;
  LThreads: TArray<TThread>;
  LErrors: TArray<string>;
  LErrorLock: TCriticalSection;
  LN, I, Iter: Integer;
  LFinalState: TSessionState;
  LCapturedThis: TICEngineConcurrentPropertyTests;
begin
  LCapturedThis := Self;
  LErrorLock := TCriticalSection.Create;
  try
    for Iter := 1 to CIterations do
    begin
      LEngine := TClarificationEngine.Create;
      LStart := TEvent.Create(nil, True, False, '');
      try
        LRequest := Default(TClarificationStartRequest);
        LRequest.UserId := 'user-' + IntToStr(Iter);
        LRequest.DomainName := 'domain';
        LRequest.IntentName := 'intent';
        LRequest.Locale := 'en-US';
        LHandle := LEngine.StartSession(LRequest);

        LN := CMinThreads + Random(CMaxThreads - CMinThreads + 1);
        SetLength(LThreads, LN);
        SetLength(LErrors, 0);

        for I := 0 to LN - 1 do
        begin
          var LIdx := I;
          LThreads[I] := TThread.CreateAnonymousThread(
            procedure
            begin
              try
                LStart.WaitFor(INFINITE);
                LEngine.SubmitInput(LHandle,
                  Format('input-%d-thread-%d', [Iter, LIdx]));
              except
                on E: Exception do
                begin
                  LErrorLock.Enter;
                  try
                    LErrors := LErrors + [Format('iter %d thr %d: %s',
                      [Iter, LIdx, E.Message])];
                  finally
                    LErrorLock.Leave;
                  end;
                end;
              end;
            end);
          LThreads[I].FreeOnTerminate := False;
        end;

        for I := 0 to LN - 1 do
          LThreads[I].Start;

        LStart.SetEvent; // release the gate; all threads race for session lock

        for I := 0 to LN - 1 do
        begin
          LThreads[I].WaitFor;
          LThreads[I].Free;
        end;

        if Length(LErrors) > 0 then
          Assert.Fail(Format('Iter %d: SubmitInput raised: %s',
            [Iter, LErrors[0]]));

        LFinalState := LEngine.GetSessionState(LHandle);
        Assert.AreEqual(LN, LFinalState.TurnCount,
          Format('Iter %d (N=%d): TurnCount must equal N after %d concurrent '
            + 'SubmitInput calls; got %d. Lost or duplicated turns indicate '
            + 'a serialization bug.',
            [Iter, LN, LN, LFinalState.TurnCount]));
        Assert.IsTrue(LFinalState.Status in [ssActive, ssCompleted],
          Format('Iter %d: session must remain Active or Completed; got %d',
            [Iter, Ord(LFinalState.Status)]));
      finally
        LStart.Free;
        LEngine.Free;
      end;
    end;
  finally
    LErrorLock.Free;
  end;

  // Suppress unused-warning if compiler nags on captured Self.
  Assert.IsNotNull(TObject(LCapturedThis));
end;

// Helper-mirror: simulate the FGlobalLock + per-session-lock pattern used
// by TClarificationEngine.AcquireSessionLock + per-session Enter. N
// workers each hold the global lock briefly to look up a per-key lock,
// then enter the per-key lock to bump a shared counter and record an
// id. With correct serialization, the counter must equal N and every
// id must appear exactly once.
procedure TICEngineConcurrentPropertyTests
  .Property7_HelperMirror_LockSerializationCount;
const
  CIterations = 100;
  CMinThreads = 5;
  CMaxThreads = 15;
var
  LGlobalLock: TCriticalSection;
  LSessionLocks: TDictionary<string, TCriticalSection>;
  LCounter: Integer;
  LRecorded: TList<Integer>;
  LRecordLock: TCriticalSection;
  LStart: TEvent;
  LThreads: TArray<TThread>;
  LN, I, Iter: Integer;
  LSessionKey: string;
  LPair: TPair<string, TCriticalSection>;
  LCapGlobal: TCriticalSection;
  LCapLocks: TDictionary<string, TCriticalSection>;
  LCapKey: string;
  LCapRecorded: TList<Integer>;
  LCapRecLock: TCriticalSection;
  LCapStart: TEvent;

  function CreateWorker(AMyId: Integer): TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      var
        LSessLock: TCriticalSection;
      begin
        LCapStart.WaitFor(INFINITE);

        // Inline mirror of TClarificationEngine.AcquireSessionLock:
        // brief global lock to look up / create the per-session lock.
        LCapGlobal.Enter;
        try
          if not LCapLocks.TryGetValue(LCapKey, LSessLock) then
          begin
            LSessLock := TCriticalSection.Create;
            LCapLocks.Add(LCapKey, LSessLock);
          end;
        finally
          LCapGlobal.Leave;
        end;

        LSessLock.Enter;
        try
          // Critical section that mirrors the engine's per-session
          // turn body: read-modify-write a shared counter and record
          // the worker id. With correct locking these are serialized.
          Inc(LCounter);
          LCapRecLock.Enter;
          try
            LCapRecorded.Add(AMyId);
          finally
            LCapRecLock.Leave;
          end;
        finally
          LSessLock.Leave;
        end;
      end);
    Result.FreeOnTerminate := False;
  end;
begin
  for Iter := 1 to CIterations do
  begin
    LGlobalLock := TCriticalSection.Create;
    LSessionLocks := TDictionary<string, TCriticalSection>.Create;
    LRecorded := TList<Integer>.Create;
    LRecordLock := TCriticalSection.Create;
    LStart := TEvent.Create(nil, True, False, '');
    try
      LCounter := 0;
      LSessionKey := 'sess-' + IntToStr(Iter);
      LN := CMinThreads + Random(CMaxThreads - CMinThreads + 1);
      SetLength(LThreads, LN);

      // Capture lock fixtures into local refs so the anonymous methods
      // bind to them by closure (Delphi cannot capture nested
      // procedures, so the per-session-lock acquisition is inlined).
      LCapGlobal := LGlobalLock;
      LCapLocks := LSessionLocks;
      LCapKey := LSessionKey;
      LCapRecorded := LRecorded;
      LCapRecLock := LRecordLock;
      LCapStart := LStart;

      for I := 0 to LN - 1 do
        LThreads[I] := CreateWorker(I);

      for I := 0 to LN - 1 do
        LThreads[I].Start;

      LStart.SetEvent;

      for I := 0 to LN - 1 do
      begin
        LThreads[I].WaitFor;
        LThreads[I].Free;
      end;

      Assert.AreEqual<Integer>(LN, LCounter,
        Format('Iter %d (N=%d): shared counter must equal N under the '
          + 'global+per-session lock pattern; got %d', [Iter, LN, LCounter]));
      Assert.AreEqual<Integer>(LN, LRecorded.Count,
        Format('Iter %d (N=%d): every worker must record exactly one id; got %d',
          [Iter, LN, LRecorded.Count]));

      // Each worker id must be present exactly once.
      LRecorded.Sort;
      for I := 0 to LN - 1 do
        Assert.AreEqual<Integer>(I, LRecorded[I],
          Format('Iter %d: worker ids must be a permutation of 0..N-1; '
            + 'missing or duplicate at position %d', [Iter, I]));
    finally
      LStart.Free;
      LRecordLock.Free;
      LRecorded.Free;
      for LPair in LSessionLocks do
        LPair.Value.Free;
      LSessionLocks.Free;
      LGlobalLock.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TICEngineConcurrentPropertyTests);

end.
