{ ============================================================================
  Test.DeepBase.Resilience.Timeout.PBT - Property-based tests for
  TTimeoutPolicy result consistency and background-task cancellation.

  Properties covered (deepbase-round2-fixes):
    Property 5: For any timeout execution (completed or timed-out),
                reading the propagated result/exception after Execute
                returns yields a CONSISTENT value:
                   (a) if the action ran to completion within the
                       budget, Execute returns its result and raises
                       no exception,
                   (b) if the action raised an exception within the
                       budget, Execute re-raises an exception of the
                       SAME class with the SAME message,
                   (c) if the budget elapsed before completion,
                       Execute raises ETimeoutException whose
                       TimeoutMs equals the configured budget,
                   (d) only ONE of (a/b/c) ever fires per call: there
                       is no torn state where a value AND a timeout
                       are both observed (the fix protects FResult
                       with TMonitor + Task.Cancel).
    Property 6: For any action that exceeds the timeout budget, the
                background TTask must be canceled by Execute. We
                observe this by polling TTask.CurrentTask.CheckCanceled
                inside the action and signalling a TCountdownEvent
                from the proc's finally; after Execute returns with
                ETimeoutException the proc must exit within a few
                seconds (the cancel was effective) and must NOT have
                fallen through its workload to "completed normally".

  Each property runs >= 100 random iterations.

  Notes on observability:
    - TTimeoutPolicy is purely Delphi RTL: TTask + ITask.Cancel +
      ITask.Wait. We can drive it from a single-threaded test thread
      and observe results via the public Execute / Execute<T> API.
    - For Property 6 we need TTask.CurrentTask.CheckCanceled to react
      to the policy's Cancel call. The action proc loops with short
      Sleep slices; without cancellation it runs >= 5 seconds. With
      cancellation it should exit on the next CheckCanceled.
  ============================================================================ }

unit Test.DeepBase.Resilience.Timeout.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Diagnostics,
  DUnitX.TestFramework,
  DeepBase.Resilience.Timeout;

type
  ESyntheticInner = class(Exception);

  [TestFixture]
  [Category('PBT')]
  TTimeoutPolicyPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 5
    [Test]
    procedure Property5_ResultIsConsistent;

    // Feature: deepbase-round2-fixes, Property 6
    [Test]
    procedure Property6_TimeoutCancelsBackgroundTask;
  end;

implementation

{ TTimeoutPolicyPropertyTests }

procedure TTimeoutPolicyPropertyTests.Setup;
begin
  Randomize;
end;

procedure TTimeoutPolicyPropertyTests.Property5_ResultIsConsistent;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    // Pick a scenario per iteration:
    //   0 -> action returns a value within budget (Execute<T>)
    //   1 -> action raises an inner exception within budget
    //   2 -> action exceeds the budget (timeout)
    var LScenario: Integer := Iter mod 3;
    var LExpected: Integer := Random(MaxInt);
    var LBudgetMs: Int64 := 200 + Random(200);      // 200..399
    var LSleepMs: Cardinal :=
      if LScenario = 2 then Cardinal(LBudgetMs * 4) else Cardinal(5);
    var LMessage: string := Format('synthetic-%d', [Iter]);

    var LPolicy := TTimeoutPolicy.Create(LBudgetMs);
    try
      case LScenario of
        0:
          begin
            var LRaised := False;
            var LValue: Integer := -1;
            try
              LValue := LPolicy.Execute<Integer>(
                function: Integer
                begin
                  Sleep(LSleepMs);
                  Result := LExpected;
                end);
            except
              on E: Exception do
                LRaised := True;
            end;
            Assert.IsFalse(LRaised,
              Format('Iter %d (success): Execute must not raise', [Iter]));
            Assert.AreEqual(LExpected, LValue,
              Format('Iter %d (success): result must equal action return',
                [Iter]));
          end;

        1:
          begin
            var LRaised := False;
            var LRaisedClass: TClass := nil;
            var LRaisedMsg := '';
            try
              LPolicy.Execute(
                procedure
                begin
                  Sleep(LSleepMs);
                  raise ESyntheticInner.Create(LMessage);
                end);
            except
              on E: Exception do
              begin
                LRaised := True;
                LRaisedClass := E.ClassType;
                LRaisedMsg := E.Message;
              end;
            end;
            Assert.IsTrue(LRaised,
              Format('Iter %d (inner-exception): Execute must re-raise',
                [Iter]));
            // Property 5 (b): same class, same message. In particular,
            // we MUST NOT see ETimeoutException here — the action
            // completed within budget but with an exception.
            Assert.IsFalse(LRaisedClass = ETimeoutException,
              Format('Iter %d (inner-exception): must not surface as ' +
                     'ETimeoutException (torn state)', [Iter]));
            Assert.AreEqual('ESyntheticInner', LRaisedClass.ClassName,
              Format('Iter %d (inner-exception): class mismatch', [Iter]));
            Assert.AreEqual(LMessage, LRaisedMsg,
              Format('Iter %d (inner-exception): message mismatch', [Iter]));
          end;

        2:
          begin
            var LRaised := False;
            var LRaisedClass: TClass := nil;
            var LReportedBudget: Int64 := -1;
            var LSw := TStopwatch.StartNew;
            try
              LPolicy.Execute(
                procedure
                begin
                  Sleep(LSleepMs);
                end);
            except
              on E: ETimeoutException do
              begin
                LRaised := True;
                LRaisedClass := E.ClassType;
                LReportedBudget := E.TimeoutMs;
              end;
              on E: Exception do
              begin
                LRaised := True;
                LRaisedClass := E.ClassType;
              end;
            end;
            LSw.Stop;
            Assert.IsTrue(LRaised,
              Format('Iter %d (timeout): Execute must raise', [Iter]));
            Assert.IsTrue(LRaisedClass = ETimeoutException,
              Format('Iter %d (timeout): expected ETimeoutException, ' +
                     'got %s', [Iter,
                       (if LRaisedClass <> nil then LRaisedClass.ClassName
                       else '<nil>')]));
            Assert.AreEqual(LBudgetMs, LReportedBudget,
              Format('Iter %d (timeout): TimeoutMs mismatch', [Iter]));
            // Property 5 (d): Execute must not block much past the
            // budget (otherwise it would not be returning timeout
            // promptly). Allow generous headroom for thread scheduling.
            Assert.IsTrue(LSw.ElapsedMilliseconds < LBudgetMs * 8,
              Format('Iter %d (timeout): Execute took %d ms for budget %d',
                [Iter, LSw.ElapsedMilliseconds, LBudgetMs]));
          end;
      end;
    finally
      LPolicy.Free;
    end;
  end;
end;

procedure
TTimeoutPolicyPropertyTests
.Property6_TimeoutCancelsBackgroundTask;
const
  CIters = 100;
  CTimeoutMs = 50;
  CMaxWaitMs = 3000;
begin
  for var Iter := 1 to CIters do
  begin
    var LExited := TCountdownEvent.Create(1);
    try
      var LCompletedNormally := 0;
      var LObservedCancel := 0;
      var LPolicy := TTimeoutPolicy.Create(CTimeoutMs);
      try
        var LTimeoutRaised := False;
        try
          LPolicy.Execute(
            procedure
            begin
              try
                try
                  // Long-running cooperative work. Without cancel,
                  // this runs for ~5 seconds. With cancel, the next
                  // CheckCanceled raises EOperationCancelled and the
                  // outer except clause records the observation.
                  for var I := 1 to 500 do
                  begin
                    Sleep(10);
                    TTask.CurrentTask.CheckCanceled;
                  end;
                  TInterlocked.Increment(LCompletedNormally);
                except
                  on EOperationCancelled do
                    TInterlocked.Increment(LObservedCancel);
                end;
              finally
                LExited.Signal;
              end;
            end);
        except
          on E: ETimeoutException do
            LTimeoutRaised := True;
        end;

        Assert.IsTrue(LTimeoutRaised,
          Format('Iter %d: Execute must raise ETimeoutException', [Iter]));

        // After timeout, the policy must have called Task.Cancel and
        // the proc must exit within a few seconds (else Cancel did
        // not propagate and the background task would leak).
        Assert.IsTrue(LExited.WaitFor(CMaxWaitMs) = wrSignaled,
          Format('Iter %d: background task did not exit within %d ms; ' +
                 'Cancel was not effective', [Iter, CMaxWaitMs]));

        // Property 6: the action must NOT have fallen through to its
        // "completed normally" branch — Cancel had to interrupt it.
        Assert.AreEqual<Integer>(0,
          TInterlocked.CompareExchange(LCompletedNormally, 0, 0),
          Format('Iter %d: action completed normally despite timeout',
            [Iter]));

        // And we expect the proc to have observed the cancellation
        // signal (TInterlocked.Increment is the visibility barrier).
        Assert.AreEqual<Integer>(1,
          TInterlocked.CompareExchange(LObservedCancel, 0, 0),
          Format('Iter %d: action did not observe EOperationCancelled',
            [Iter]));
      finally
        LPolicy.Free;
      end;
    finally
      LExited.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTimeoutPolicyPropertyTests);

end.
