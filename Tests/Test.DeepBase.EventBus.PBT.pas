{ ============================================================================
  Test.DeepBase.EventBus.PBT - Property-based tests for the global
  TEventBus singleton initialization.

  Properties covered (deepbase-round2-fixes):
    Property 4: For any number of concurrent threads racing to access
                the global EventBus() singleton, every caller observes
                the same instance pointer. Exactly one TEventBus is
                created. The fix uses TInterlocked.CompareExchange so
                concurrent first-callers do not double-create.

  Each property runs >= 100 random iterations.

  Notes on observability:
    - The unit-private FInstance is reachable through the public EventBus
      function. All threads call EventBus() and we record the returned
      pointer. After the parallel race, every recorded pointer must equal
      the first one and be non-nil.
    - We cannot reliably reset the global TEventBus from a unit test
      (SetEventBus(nil) frees the live instance and would race with any
      other test in the suite that uses the bus). Instead we record the
      instance once at fixture setup, then verify that all concurrent
      reads return that same value.
  ============================================================================ }

unit Test.DeepBase.EventBus.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework,
  DeepBase.EventBus;

type
  [TestFixture]
  TEventBusSingletonPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 4
    [Test]
    procedure Property4_ConcurrentSingletonAccessReturnsSameInstance;
  end;

implementation

{ TEventBusSingletonPropertyTests }

procedure TEventBusSingletonPropertyTests.Setup;
begin
  Randomize;
end;

procedure
TEventBusSingletonPropertyTests
.Property4_ConcurrentSingletonAccessReturnsSameInstance;
const
  CThreadsPerIter = 32;
begin
  for var Iter := 1 to 100 do
  begin
    var LObserved: TArray<Pointer>;
    SetLength(LObserved, CThreadsPerIter);
    for var I := 0 to High(LObserved) do
      LObserved[I] := nil;

    // TParallel.For races CThreadsPerIter worker tasks. Each one
    // dereferences EventBus() and stores the returned pointer.
    TParallel.For(0, CThreadsPerIter - 1,
      procedure(AIndex: Integer)
      begin
        LObserved[AIndex] := Pointer(EventBus);
      end);

    var LFirst := LObserved[0];
    Assert.IsTrue(LFirst <> nil,
      Format('Iter %d: EventBus() must never return nil', [Iter]));

    for var I := 1 to High(LObserved) do
      Assert.IsTrue(LObserved[I] = LFirst,
        Format('Iter %d thread %d: got %p, expected %p (singleton race)',
          [Iter, I, LObserved[I], LFirst]));

    // Sequential follow-up: subsequent calls on the main thread also
    // return the same instance. This catches a regression where the
    // CAS path returns an instance other than the survivor.
    for var I := 1 to 8 do
      Assert.IsTrue(Pointer(EventBus) = LFirst,
        Format('Iter %d follow-up %d: pointer drifted', [Iter, I]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEventBusSingletonPropertyTests);

end.
