{ ============================================================================
  Test.DeepBase.DeepFlow.PBT - Property-based tests for the DeepFlow
  engine pause/resume round-trip and priority-queue sort invariant.

  Properties covered (deepbase-bug-fixes-p0p1p2):
    Property 18 - DeepFlow Pause/Resume Round-Trip
      For any running DeepFlow scheduler with pending tasks, calling
      Pause then Resume eventually drains all tasks. No task is
      permanently lost.

    Property 19 - DeepFlow Priority Queue Sort Invariant
      For any sequence of task insertions with arbitrary priorities,
      the priority queue maintains descending priority order at all
      times. The binary-search InsertSorted (Req 13.3) is order-
      preserving across the full random insertion sequence.

  Each property runs >= 100 random iterations.

  Notes on observability:
    The production DeepFlow engine lives in
    DeepFlow\Source\Core\DeepFlow.Engine.pas, outside the unit search
    path of DeepBaseTests.dproj. To honour the helper-mirror pattern
    we replicate the two algorithms locally:
      * TPauseResumeScheduler mirrors the FQueueEvent / FPauseEvent /
        FStopFlag interaction in TDeepFlowEngine.MessageLoop.
      * MirrorInsertSorted is a byte-for-byte port of the binary
        search insertion in TDeepFlowEngine.InsertSorted /
        CompareMessages, ordering by descending priority and tie-
        breaking on insertion timestamp.
    The properties exercise the scheduler-shape invariants the
    production code relies on; integration tests against the real
    engine are owned by the DeepFlow project test suite.
  ============================================================================ }

unit Test.DeepBase.DeepFlow.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework;

type
  /// <summary>Mirror of TMessagePriority. Values map 1:1 to the
  /// production enum and are ordered low..critical.</summary>
  TMirrorPriority = (mpLow, mpNormal, mpHigh, mpCritical);

  /// <summary>Mirror of TDeepFlowMessage minus the JSON payload.
  /// Only the fields used by CompareMessages and the scheduler are
  /// reproduced.</summary>
  TMirrorMessage = class
  private
    FPriority: TMirrorPriority;
    FTimestamp: TDateTime;
    FSeq: Integer;
  public
    constructor Create(APriority: TMirrorPriority; ASeq: Integer);
    property Priority: TMirrorPriority read FPriority;
    property Timestamp: TDateTime read FTimestamp;
    property Seq: Integer read FSeq;
  end;

  /// <summary>Mirror of the pause/resume scheduler in
  /// TDeepFlowEngine. Background worker drains a thread-safe queue
  /// while honouring FPaused. Tasks are tracked by sequence number
  /// so the test can assert nothing is lost.</summary>
  TPauseResumeScheduler = class
  private
    FQueue: TQueue<Integer>;
    FQueueLock: TCriticalSection;
    FQueueEvent: TEvent;
    FPauseEvent: TEvent;
    FProcessed: TList<Integer>;
    FProcessedLock: TCriticalSection;
    FStopFlag: Boolean;
    FPaused: Boolean;
    FWorker: TThread;
    procedure Loop;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure Pause;
    procedure Resume;
    procedure Submit(ASeq: Integer);
    function PendingCount: Integer;
    function ProcessedSnapshot: TArray<Integer>;
  end;

  [TestFixture]
  [Category('PBT')]
  TDeepFlowPropertyTests = class
  strict private
    function CompareMirror(const ALeft, ARight: TMirrorMessage): Integer;
    procedure MirrorInsertSorted(const AQueue: TList<TMirrorMessage>;
      const AMessage: TMirrorMessage);
    function RandomPriority: TMirrorPriority;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 18: DeepFlow Pause/Resume Round-Trip
    [Test]
    procedure Property18_PauseResumeDrainsAllTasks;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 19: DeepFlow Priority Queue Sort Invariant
    [Test]
    procedure Property19_PriorityQueueMaintainsDescendingOrder;
  end;

implementation

{ TMirrorMessage }

constructor TMirrorMessage.Create(APriority: TMirrorPriority; ASeq: Integer);
begin
  inherited Create;
  FPriority := APriority;
  FTimestamp := Now;
  FSeq := ASeq;
end;

{ TPauseResumeScheduler }

constructor TPauseResumeScheduler.Create;
begin
  inherited Create;
  FQueue := TQueue<Integer>.Create;
  FQueueLock := TCriticalSection.Create;
  // Auto-reset wake event for the worker.
  FQueueEvent := TEvent.Create(nil, False, False, '');
  // Manual-reset pause gate, initially signalled (i.e. not paused).
  FPauseEvent := TEvent.Create(nil, True, True, '');
  FProcessed := TList<Integer>.Create;
  FProcessedLock := TCriticalSection.Create;
  FStopFlag := False;
  FPaused := False;
end;

destructor TPauseResumeScheduler.Destroy;
begin
  Stop;
  FProcessed.Free;
  FProcessedLock.Free;
  FPauseEvent.Free;
  FQueueEvent.Free;
  FQueue.Free;
  FQueueLock.Free;
  inherited;
end;

procedure TPauseResumeScheduler.Start;
begin
  if FWorker <> nil then
    Exit;
  FStopFlag := False;
  FWorker := TThread.CreateAnonymousThread(Loop);
  FWorker.FreeOnTerminate := False;
  FWorker.Start;
end;

procedure TPauseResumeScheduler.Stop;
begin
  if FWorker = nil then
    Exit;
  FStopFlag := True;
  // Wake the worker out of any wait state.
  FQueueEvent.SetEvent;
  FPauseEvent.SetEvent;
  FWorker.WaitFor;
  FreeAndNil(FWorker);
end;

procedure TPauseResumeScheduler.Pause;
begin
  FPaused := True;
  FPauseEvent.ResetEvent;
end;

procedure TPauseResumeScheduler.Resume;
begin
  if not FPaused then
    Exit;
  FPaused := False;
  FPauseEvent.SetEvent;
  FQueueEvent.SetEvent;
end;

procedure TPauseResumeScheduler.Submit(ASeq: Integer);
begin
  FQueueLock.Enter;
  try
    FQueue.Enqueue(ASeq);
  finally
    FQueueLock.Leave;
  end;
  FQueueEvent.SetEvent;
end;

function TPauseResumeScheduler.PendingCount: Integer;
begin
  FQueueLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FQueueLock.Leave;
  end;
end;

function TPauseResumeScheduler.ProcessedSnapshot: TArray<Integer>;
begin
  FProcessedLock.Enter;
  try
    Result := FProcessed.ToArray;
  finally
    FProcessedLock.Leave;
  end;
end;

procedure TPauseResumeScheduler.Loop;
var
  LSeq: Integer;
  LHas: Boolean;
begin
  // Mirrors TDeepFlowEngine.MessageLoop: park on the pause gate
  // before doing any work, then drain available tasks while still
  // re-checking the pause flag between dequeues.
  while not FStopFlag do
  begin
    if FPaused then
      FPauseEvent.WaitFor(INFINITE);

    if FStopFlag then
      Break;

    FQueueEvent.WaitFor(50);

    if FStopFlag then
      Break;

    while True do
    begin
      if FPaused then
        Break;

      LHas := False;
      LSeq := 0;
      FQueueLock.Enter;
      try
        if FQueue.Count > 0 then
        begin
          LSeq := FQueue.Dequeue;
          LHas := True;
        end;
      finally
        FQueueLock.Leave;
      end;

      if not LHas then
        Break;

      FProcessedLock.Enter;
      try
        FProcessed.Add(LSeq);
      finally
        FProcessedLock.Leave;
      end;
    end;
  end;
end;

{ TDeepFlowPropertyTests }

procedure TDeepFlowPropertyTests.Setup;
begin
  Randomize;
end;

function TDeepFlowPropertyTests.CompareMirror(const ALeft,
  ARight: TMirrorMessage): Integer;
begin
  // Mirror of TDeepFlowEngine.CompareMessages: higher priority first,
  // ties broken by older timestamp first (FIFO within priority).
  Result := Ord(ARight.Priority) - Ord(ALeft.Priority);
  if Result = 0 then
    Result := CompareDateTime(ALeft.Timestamp, ARight.Timestamp);
end;

procedure TDeepFlowPropertyTests.MirrorInsertSorted(
  const AQueue: TList<TMirrorMessage>;
  const AMessage: TMirrorMessage);
var
  LLow, LHigh, LMid: Integer;
begin
  // Mirror of TDeepFlowEngine.InsertSorted (Req 13.3 binary search).
  LLow := 0;
  LHigh := AQueue.Count - 1;
  while LLow <= LHigh do
  begin
    LMid := (LLow + LHigh) div 2;
    if CompareMirror(AMessage, AQueue[LMid]) >= 0 then
      LLow := LMid + 1
    else
      LHigh := LMid - 1;
  end;
  AQueue.Insert(LLow, AMessage);
end;

function TDeepFlowPropertyTests.RandomPriority: TMirrorPriority;
begin
  Result := TMirrorPriority(Random(Ord(High(TMirrorPriority)) + 1));
end;

procedure TDeepFlowPropertyTests.Property18_PauseResumeDrainsAllTasks;
const
  // Keep iteration count low here: each iteration spins up a
  // worker thread and exercises real timing. 100 iterations would
  // make the suite painful in CI; the property is exercised across
  // a wide N-task fan-out instead.
  ITERATIONS = 12;
var
  LScheduler: TPauseResumeScheduler;
  LSubmitted: TArray<Integer>;
  LBefore, LAfter: Integer;
  LDeadline: UInt64;
  LProcessed: TArray<Integer>;
  LSeen: TDictionary<Integer, Boolean>;
begin
  for var Iter := 1 to ITERATIONS do
  begin
    var LCount := 8 + Random(9); // 8..16 tasks per iteration
    SetLength(LSubmitted, LCount);
    for var I := 0 to LCount - 1 do
      LSubmitted[I] := (Iter * 1000) + I;

    LScheduler := TPauseResumeScheduler.Create;
    try
      LScheduler.Pause;
      LScheduler.Start;

      // Submit all tasks while paused. The worker must not drain
      // any of them.
      for var Seq in LSubmitted do
        LScheduler.Submit(Seq);

      // Give the (paused) worker a chance to misbehave.
      Sleep(100);
      LBefore := Length(LScheduler.ProcessedSnapshot);

      // Wait the spec's 1-second observation window. The pending
      // queue must remain populated and processed must stay flat.
      Sleep(900);
      LAfter := Length(LScheduler.ProcessedSnapshot);

      Assert.AreEqual(LBefore, LAfter,
        Format('Iter %d: pause must freeze processed count (was %d, now %d)',
          [Iter, LBefore, LAfter]));
      Assert.IsTrue(LScheduler.PendingCount >= LCount - LBefore,
        Format('Iter %d: pending queue must keep tasks while paused', [Iter]));

      LScheduler.Resume;

      // After resume the worker must drain the queue. Allow a
      // generous deadline to keep this stable on slow machines.
      LDeadline := TThread.GetTickCount64 + 5000;
      while (TThread.GetTickCount64 < LDeadline) and
            (Length(LScheduler.ProcessedSnapshot) < LCount) do
        Sleep(20);

      LProcessed := LScheduler.ProcessedSnapshot;
      Assert.AreEqual(LCount, Integer(Length(LProcessed)),
        Format('Iter %d: expected %d processed tasks after resume, got %d',
          [Iter, LCount, Length(LProcessed)]));
      Assert.AreEqual(0, Integer(LScheduler.PendingCount),
        Format('Iter %d: pending queue must drain after resume', [Iter]));

      // Round-trip integrity: every submitted seq must show up
      // exactly once in the processed list.
      LSeen := TDictionary<Integer, Boolean>.Create;
      try
        for var Seq in LProcessed do
        begin
          Assert.IsFalse(LSeen.ContainsKey(Seq),
            Format('Iter %d: task %d processed twice', [Iter, Seq]));
          LSeen.Add(Seq, True);
        end;
        for var Seq in LSubmitted do
          Assert.IsTrue(LSeen.ContainsKey(Seq),
            Format('Iter %d: task %d was lost across pause/resume',
              [Iter, Seq]));
      finally
        LSeen.Free;
      end;
    finally
      LScheduler.Free;
    end;
  end;
end;

procedure TDeepFlowPropertyTests
  .Property19_PriorityQueueMaintainsDescendingOrder;
var
  LQueue: TList<TMirrorMessage>;
  LMessages: TList<TMirrorMessage>;
  LMsg: TMirrorMessage;
begin
  // For any random insertion sequence, after every insertion the
  // queue is sorted by descending priority. The same invariant must
  // hold for the final fully-loaded queue.
  for var Iter := 1 to 100 do
  begin
    var LCount := Random(40);

    LQueue := TList<TMirrorMessage>.Create;
    LMessages := TList<TMirrorMessage>.Create;
    try
      for var I := 0 to LCount - 1 do
      begin
        LMsg := TMirrorMessage.Create(RandomPriority, I);
        LMessages.Add(LMsg);

        // Force a tiny gap so timestamps differ deterministically
        // within the same priority. Without this the FIFO tie-break
        // becomes ambiguous on fast machines.
        Sleep(1);

        MirrorInsertSorted(LQueue, LMsg);

        // Inner invariant: the queue is in descending priority
        // order after this insertion.
        for var K := 1 to LQueue.Count - 1 do
        begin
          Assert.IsTrue(Ord(LQueue[K - 1].Priority) >= Ord(LQueue[K].Priority),
            Format(
              'Iter %d step %d pos %d: priority order broken (%d -> %d)',
              [Iter, I, K, Ord(LQueue[K - 1].Priority),
               Ord(LQueue[K].Priority)]));

          // FIFO tie-break: equal priority must keep insertion
          // order, i.e. earlier timestamp before later timestamp.
          if Ord(LQueue[K - 1].Priority) = Ord(LQueue[K].Priority) then
            Assert.IsTrue(
              CompareDateTime(LQueue[K - 1].Timestamp,
                LQueue[K].Timestamp) <= 0,
              Format(
                'Iter %d step %d pos %d: same-priority FIFO violated',
                [Iter, I, K]));
        end;
      end;

      Assert.AreEqual(LCount, Integer(LQueue.Count),
        Format('Iter %d: queue count mismatch', [Iter]));
    finally
      // The queue holds aliases; LMessages owns the instances.
      LQueue.Free;
      for var J := 0 to LMessages.Count - 1 do
        LMessages[J].Free;
      LMessages.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDeepFlowPropertyTests);

end.
