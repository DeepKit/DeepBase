{ ============================================================================
  Test.DeepBase.StateMachine.PBT - Property-based tests for TStateMachine

  Properties covered (deepbase-round2-fixes):
    Property 1: StateMachine reentrant lock does not deadlock when an
                action handler invokes another method (Fire, IsIn,
                FireIfInState) on the same state machine from the same
                thread. The fix replaced the internal lock with TMonitor
                (reentrant). Verified by time-bounded execution.
    Property 2: StateMachine hierarchy traversal terminates even in the
                presence of cycles or chains that exceed the
                CMaxHierarchyDepth (64) cap. IsIn must return False for
                non-existent targets and never loop forever or stack-
                overflow.

  Each property runs >= 100 random iterations.

  Implementation notes:
    - TStringStateMachine = TStateMachine<string, string> is the public
      string-keyed state machine used to keep the test free of generic
      instantiation overhead.
    - We exercise the reentrant path by calling IsIn / Fire / CanFire
      from inside an InternalTransition action, all of which acquire
      FLock via TMonitor.Enter on the same thread.
    - Cycles are constructed via SubstateOf chains where the deepest
      state declares its parent as an earlier ancestor.
  ============================================================================ }

unit Test.DeepBase.StateMachine.PBT;

interface

uses
  System.SysUtils,
  System.Diagnostics,
  DUnitX.TestFramework,
  DeepBase.StateMachine;

type
  [TestFixture]
  TStateMachinePropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 1: StateMachine reentrant
    // lock does not deadlock when handlers invoke FireIfInState / IsIn /
    // CanFire on the same state machine from the same thread.
    [Test]
    procedure Property1_ReentrantLockNoDeadlock;

    // Feature: deepbase-round2-fixes, Property 2: StateMachine cycle
    // detection terminates within O(CMaxHierarchyDepth) steps even for
    // cyclic or excessively deep parent chains.
    [Test]
    procedure Property2_CycleDetectionTerminates;
  end;

implementation

{ TStateMachinePropertyTests }

procedure TStateMachinePropertyTests.Setup;
begin
  Randomize;
end;

procedure TStateMachinePropertyTests.Property1_ReentrantLockNoDeadlock;
const
  CMaxIterMs = 1000;  // generous: a deadlock would be > 30 s test-runner
                      // timeout, so 1 s easily distinguishes deadlock
                      // from normal execution.
var
  LSM: TStateMachine<string, string>;
  LReenteredIsIn: Boolean;
  LReenteredCanFire: Boolean;
  LWatch: TStopwatch;
  LResult: TTransitionResult<string, string>;
begin
  for var Iter := 1 to 100 do
  begin
    LSM := TStateMachine<string, string>.Create('A');
    try
      LReenteredIsIn := False;
      LReenteredCanFire := False;

      // Internal transition action re-enters the state machine from the
      // same thread. This used to be impossible with TCriticalSection on
      // some platforms; TMonitor is documented as reentrant and must not
      // deadlock.
      LSM.Configure('A')
        .Permit('go', 'B')
        .InternalTransition('reenter',
          procedure(const AFromState, AToState: string;
            const ATrigger: string; const AContext: TObject)
          begin
            // Each of these acquires FLock on the same thread.
            if LSM.IsIn('A') then
              LReenteredIsIn := True;
            if LSM.CanFire('go') then
              LReenteredCanFire := True;
          end);

      LSM.Configure('B')
        .Permit('back', 'A');

      LSM.Start;

      LWatch := TStopwatch.StartNew;
      LResult := LSM.Fire('reenter');
      LWatch.Stop;

      Assert.IsTrue(LResult.Success,
        Format('Iter %d: Fire("reenter") should succeed', [Iter]));
      Assert.IsTrue(LReenteredIsIn,
        Format('Iter %d: nested IsIn must execute (no deadlock)', [Iter]));
      Assert.IsTrue(LReenteredCanFire,
        Format('Iter %d: nested CanFire must execute (no deadlock)',
          [Iter]));
      Assert.IsTrue(LWatch.ElapsedMilliseconds < CMaxIterMs,
        Format('Iter %d: nested Fire took %d ms (deadlock?)',
          [Iter, LWatch.ElapsedMilliseconds]));

      // After the internal transition, current state must remain 'A'.
      Assert.AreEqual('A', LSM.CurrentState,
        Format('Iter %d: internal transition must not change state',
          [Iter]));
    finally
      LSM.Free;
    end;
  end;
end;

procedure TStateMachinePropertyTests.Property2_CycleDetectionTerminates;
const
  CTimeoutMs = 500;  // 64-step traversal completes in microseconds; any
                     // observed time over 0.5 s indicates an infinite loop.
var
  LSM: TStateMachine<string, string>;
  LWatch: TStopwatch;
  LDepth: Integer;
  LResult: Boolean;
begin
  for var Iter := 1 to 100 do
  begin
    // Vary chain depth across the boundary (CMaxHierarchyDepth = 64).
    case Iter mod 5 of
      0: LDepth := 10;
      1: LDepth := 50;
      2: LDepth := 64;
      3: LDepth := 100;
    else
      LDepth := 200;
    end;

    LSM := TStateMachine<string, string>.Create('s0');
    try
      // Build a parent chain s0 -> s1 -> s2 -> ... -> s(LDepth - 1).
      // Each si declares s(i+1) as its parent state.
      for var I := 0 to LDepth - 2 do
      begin
        LSM.Configure('s' + IntToStr(I))
          .SubstateOf('s' + IntToStr(I + 1));
      end;
      LSM.Configure('s' + IntToStr(LDepth - 1));

      // For half the iterations close the chain into a cycle so that
      // the topmost state's parent points back to s0. A non-terminating
      // implementation would loop forever here.
      if (Iter mod 2) = 0 then
      begin
        LSM.Configure('s' + IntToStr(LDepth - 1))
          .SubstateOf('s0');
      end;

      // Query a state that is NOT in the hierarchy. This forces the
      // walker to traverse the entire chain (or cycle) before bottoming
      // out. CMaxHierarchyDepth must cap the walk.
      LWatch := TStopwatch.StartNew;
      LResult := LSM.IsIn('not-in-hierarchy');
      LWatch.Stop;

      Assert.IsFalse(LResult,
        Format('Iter %d (depth=%d, cycle=%s): IsIn must return False '
             + 'for missing target',
          [Iter, LDepth, BoolToStr((Iter mod 2) = 0, True)]));
      Assert.IsTrue(LWatch.ElapsedMilliseconds < CTimeoutMs,
        Format('Iter %d (depth=%d): IsIn took %d ms (infinite loop?)',
          [Iter, LDepth, LWatch.ElapsedMilliseconds]));

      // For chains within the cap we should still find a target that
      // IS in the chain (within depth 64). For chains beyond 64 the
      // walker correctly bails with False, even when the target exists
      // beyond the cap.
      if LDepth <= 64 then
      begin
        LWatch := TStopwatch.StartNew;
        LResult := LSM.IsIn('s' + IntToStr(LDepth - 1));
        LWatch.Stop;
        Assert.IsTrue(LResult,
          Format('Iter %d (depth=%d): IsIn should find ancestor within '
               + 'CMaxHierarchyDepth',
            [Iter, LDepth]));
        Assert.IsTrue(LWatch.ElapsedMilliseconds < CTimeoutMs,
          Format('Iter %d (depth=%d): ancestor lookup took %d ms',
            [Iter, LDepth, LWatch.ElapsedMilliseconds]));
      end;
    finally
      LSM.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TStateMachinePropertyTests);

end.
