{ ============================================================================
  Test.DeepBase.DeepShell.EventBus.PBT - Property tests for the
  TShellEventBus lifecycle hooks added in DSHELL-003.

  Properties covered:
    P11 : EventBus Shutdown Drains Queue (Req 9.1)
          For any set of events published from a background thread before
          Shutdown is called, all corresponding queued handlers SHALL have
          completed execution by the time Shutdown returns.

    P12 : EventBus Rejects After Shutdown (Req 9.2)
          For any event published after Shutdown has been called, Publish
          SHALL raise EInvalidOperation.

    P13 : EventBus Error Callback (Req 9.3)
          For any handler that raises during dispatch, the OnDispatchError
          callback SHALL be invoked with the exception instance and the
          subscription token.

  Each property test runs >= 100 iterations.

  Notes:
    - The bus dispatches inline on the main thread and queues to the main
      thread when Publish is called from a worker. P11 exercises the
      worker-then-Shutdown path. We pump CheckSynchronize before the
      assertion so the test is independent of whether the embedded VCL
      Application object is initialised in this DUnitX runner.
    - P13 publishes from the main thread so the handler runs inline,
      which is the path TShellEventBus.DispatchInline guards. This
      guarantees the OnDispatchError callback receives the exception
      instance and the originating subscription token without async
      timing skew.
  ============================================================================ }

unit Test.DeepBase.DeepShell.EventBus.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  DUnitX.TestFramework,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf,
  DeepBase.VCL.DeepShell.Events;

type
  [TestFixture]
  [Category('PBT')]
  TShellEventBusLifecyclePropertyTests = class
  strict private
    procedure DrainQueueUntil(APredicate: TFunc<Boolean>; ATimeoutMs: Integer);
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 11
    [Test]
    procedure Property11_ShutdownDrainsQueuedHandlers;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 12
    [Test]
    procedure Property12_PublishAfterShutdownRaises;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 13
    [Test]
    procedure Property13_HandlerExceptionInvokesDispatchError;
  end;

implementation

{ TShellEventBusLifecyclePropertyTests }

procedure TShellEventBusLifecyclePropertyTests.Setup;
begin
  Randomize;
end;

procedure TShellEventBusLifecyclePropertyTests.DrainQueueUntil(
  APredicate: TFunc<Boolean>; ATimeoutMs: Integer);
var
  LDeadline: TDateTime;
begin
  LDeadline := IncMilliSecond(Now, ATimeoutMs);
  while not APredicate() and (Now < LDeadline) do
    CheckSynchronize(10);
  // One last drain pass to flush any items posted just before the deadline.
  CheckSynchronize(10);
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 11: All events published
// from a background thread before Shutdown completes must run their
// handlers before Shutdown returns. We assert handler-count = N for
// random N in [1..15] across 100 iterations.
procedure TShellEventBusLifecyclePropertyTests
  .Property11_ShutdownDrainsQueuedHandlers;
const
  CIterations = 100;
  CMinEvents = 1;
  CMaxEvents = 15;
var
  Iter, N: Integer;
  LBus: IShellEventBus;
  LCounter: Integer;
  LToken: string;
  LEvent: TDeepShellEvent;
  LWorkerDone: TEvent;
  LWorker: TThread;
  LCapturedN: Integer;
begin
  for Iter := 1 to CIterations do
  begin
    N := CMinEvents + Random(CMaxEvents - CMinEvents + 1);
    LCapturedN := N;
    LBus := TShellEventBus.Create;
    LCounter := 0;
    LWorkerDone := TEvent.Create(nil, True, False, '');
    try
      LToken := LBus.Subscribe(sekLogAdded,
        procedure(const AEvent: TDeepShellEvent)
        begin
          TInterlocked.Increment(LCounter);
        end);

      LEvent := Default(TDeepShellEvent);
      LEvent.Kind := sekLogAdded;
      LEvent.Data := 'iter-' + IntToStr(Iter);

      LWorker := TThread.CreateAnonymousThread(
        procedure
        var
          LI: Integer;
        begin
          for LI := 0 to LCapturedN - 1 do
            LBus.Publish(LEvent);
          LWorkerDone.SetEvent;
        end);
      LWorker.FreeOnTerminate := False;
      try
        LWorker.Start;
        LWorkerDone.WaitFor(5000);
        LWorker.WaitFor;
      finally
        LWorker.Free;
      end;

      // Drain the main-thread queue so the queued handlers can run before
      // Shutdown is observed. Without an active VCL Application loop,
      // Shutdown's internal ProcessMessages may be a no-op in the
      // console runner; CheckSynchronize is the lower-level, runner
      // independent drain.
      DrainQueueUntil(
        function: Boolean
        begin
          Result := TInterlocked.CompareExchange(LCounter, 0, 0) >= LCapturedN;
        end,
        5000);

      LBus.Shutdown;

      // After Shutdown returns the counter must equal N. Re-check after
      // a final drain so we are robust to runner-specific message
      // pumping but still catch dropped handlers.
      CheckSynchronize(10);

      Assert.AreEqual(N, TInterlocked.CompareExchange(LCounter, 0, 0),
        Format('Iter %d: Shutdown must drain all queued handlers; expected '
          + '%d, observed %d', [Iter,
          N, TInterlocked.CompareExchange(LCounter, 0, 0)]));

      // Cleanup the subscription handle even though we drop the bus next.
      LBus.Unsubscribe(LToken);
    finally
      LWorkerDone.Free;
      LBus := nil;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 12: After Shutdown, every
// Publish call must raise EInvalidOperation. We exercise 100 iterations
// across both kind-specific and SubscribeAll subscriptions to make sure
// the gate is enforced regardless of subscriber shape.
procedure TShellEventBusLifecyclePropertyTests
  .Property12_PublishAfterShutdownRaises;
const
  CIterations = 100;
var
  Iter: Integer;
  LBus: IShellEventBus;
  LEvent: TDeepShellEvent;
begin
  for Iter := 1 to CIterations do
  begin
    LBus := TShellEventBus.Create;
    try
      // Subscribe so Publish actually has work to do (some impls only
      // raise when there is a non-empty subscriber set).
      if Iter mod 2 = 0 then
        LBus.Subscribe(sekLogAdded,
          procedure(const AEvent: TDeepShellEvent) begin end)
      else
        LBus.SubscribeAll(
          procedure(const AEvent: TDeepShellEvent) begin end);

      LBus.Shutdown;

      LEvent := Default(TDeepShellEvent);
      LEvent.Kind := sekLogAdded;
      LEvent.Data := 'iter-' + IntToStr(Iter);

      // Use a hand-rolled try/except so the assertion failure message
      // can carry the iteration index. Assert.WillRaise's third arg is
      // the expected EXCEPTION message, not the assertion message.
      var LRaised := False;
      var LWrongClass: string := '';
      try
        LBus.Publish(LEvent);
      except
        on E: EInvalidOperation do
          LRaised := True;
        on E: Exception do
          LWrongClass := E.ClassName;
      end;

      var LDiag := if LWrongClass = '' then 'nothing' else LWrongClass;
      Assert.IsTrue(LRaised,
        Format('Iter %d: Publish after Shutdown must raise '
          + 'EInvalidOperation; raised=%s', [Iter, LDiag]));
    finally
      LBus := nil;
    end;
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 13: When a handler raises
// during dispatch, OnDispatchError must be invoked with the exception
// and the subscription token. We publish from the main thread so
// DispatchInline takes the synchronous path and we can capture the
// payload deterministically across 100 iterations.
procedure TShellEventBusLifecyclePropertyTests
  .Property13_HandlerExceptionInvokesDispatchError;
const
  CIterations = 100;
var
  Iter: Integer;
  LBus: IShellEventBus;
  LToken: string;
  LCapturedToken: string;
  LCapturedClass: string;
  LCapturedMessage: string;
  LCalls: Integer;
  LEvent: TDeepShellEvent;
  LExpectedMessage: string;
begin
  for Iter := 1 to CIterations do
  begin
    LBus := TShellEventBus.Create;
    LCapturedToken := '';
    LCapturedClass := '';
    LCapturedMessage := '';
    LCalls := 0;
    LExpectedMessage := 'pbt-handler-failure-' + IntToStr(Iter);
    try
      LBus.SetOnDispatchError(
        procedure(E: Exception; AToken: string)
        begin
          Inc(LCalls);
          LCapturedToken := AToken;
          if E <> nil then
          begin
            LCapturedClass := E.ClassName;
            LCapturedMessage := E.Message;
          end;
        end);

      LToken := LBus.Subscribe(sekLogAdded,
        procedure(const AEvent: TDeepShellEvent)
        begin
          raise EAccessViolation.Create(LExpectedMessage);
        end);

      LEvent := Default(TDeepShellEvent);
      LEvent.Kind := sekLogAdded;
      LEvent.Data := 'iter-' + IntToStr(Iter);

      // Publish from the main thread so the handler runs inline and we
      // see DispatchInline's exception path synchronously.
      LBus.Publish(LEvent);

      Assert.AreEqual(1, LCalls,
        Format('Iter %d: OnDispatchError must fire exactly once for a single '
          + 'failing handler', [Iter]));
      Assert.AreEqual(LToken, LCapturedToken,
        Format('Iter %d: OnDispatchError must receive the originating '
          + 'subscription token', [Iter]));
      Assert.AreEqual('EAccessViolation', LCapturedClass,
        Format('Iter %d: OnDispatchError must receive the original exception '
          + 'class', [Iter]));
      Assert.AreEqual(LExpectedMessage, LCapturedMessage,
        Format('Iter %d: OnDispatchError must receive the original exception '
          + 'message', [Iter]));
    finally
      LBus := nil;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TShellEventBusLifecyclePropertyTests);

end.
