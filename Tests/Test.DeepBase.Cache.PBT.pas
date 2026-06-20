{ ============================================================================
  Test.DeepBase.Cache.PBT - Property-based tests for TCache FIFO eviction.

  Properties covered (deepbase-round2-fixes):
    Property 25: For any sequence of Put operations (including repeated
                 keys), TCache with EvictionPolicy = cepFIFO must:
                   (a) never let Count exceed MaxItems,
                   (b) Get always returns the most recent value for a key,
                   (c) once an existing key is re-Put, the FIFO ordering
                       does NOT promote it to "most recently inserted"
                       (the fix prevents duplicate enqueues),
                   (d) when overflow happens, the oldest *distinct*
                       inserted key is evicted first.

  Each property runs >= 100 random iterations.

  Notes on observability:
    - FInsertOrder is private; we verify the no-duplicate-FIFO invariant
      indirectly via the eviction order it implies. Specifically: insert
      N distinct keys, re-Put one of them many times, then drive
      additional new keys to force evictions, and assert that the
      evicted keys come out in the original insertion order. If the
      private queue had duplicates the implementation could still pass
      because EvictFIFO loops over stale entries; the OnEvict callback
      observes the actually-removed key, which is what callers care
      about.
  ============================================================================ }

unit Test.DeepBase.Cache.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Cache;

type
  [TestFixture]
  [Category('PBT')]
  TCacheFIFOPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 25
    [Test]
    procedure Property25_FIFONoDuplicatesAndCorrectOrder;
  end;

implementation

{ TCacheFIFOPropertyTests }

procedure TCacheFIFOPropertyTests.Setup;
begin
  Randomize;
end;

procedure
TCacheFIFOPropertyTests
.Property25_FIFONoDuplicatesAndCorrectOrder;
const
  CMaxItems = 5;
var
  LCache: TCache<string, string>;
  LEvictedOrder: TList<string>;
  LDupTarget: string;
  LDupTimes, LExtra: Integer;
  LValue: string;
begin
  for var Iter := 1 to 100 do
  begin
    LCache := TCache<string, string>.Create;
    try
      LCache.MaxItems := CMaxItems;
      LCache.EvictionPolicy := cepFIFO;
      LCache.DefaultTTL := 0;  // no TTL eviction; we only test FIFO

      LEvictedOrder := TList<string>.Create;
      try
        LCache.OnEvict :=
          procedure(const AKey, AValue: string)
          begin
            LEvictedOrder.Add(AKey);
          end;

        // 1. Fill the cache up to capacity with distinct keys k0..k(N-1).
        for var I := 0 to CMaxItems - 1 do
          LCache.Put('k' + IntToStr(I), 'v' + IntToStr(I));

        Assert.AreEqual<Integer>(CMaxItems, LCache.Count,
          Format('Iter %d: cache should be at capacity after fill', [Iter]));

        // 2. Re-Put one existing key many times. With the fix this MUST
        //    NOT enqueue the key again; it must only update the value.
        //    Choose a target other than k0 so we can verify k0 still
        //    evicts first (claim d).
        LDupTarget := 'k' + IntToStr(1 + Random(CMaxItems - 1));
        LDupTimes := 5 + Random(20);
        for var I := 0 to LDupTimes - 1 do
          LCache.Put(LDupTarget, 'updated-' + IntToStr(I));

        // Cache size unchanged.
        Assert.AreEqual<Integer>(CMaxItems, LCache.Count,
          Format('Iter %d: re-put must not change Count', [Iter]));
        // No evictions yet.
        Assert.AreEqual<Integer>(0, LEvictedOrder.Count,
          Format('Iter %d: re-put must not trigger evictions', [Iter]));

        // Latest value must be observable for the duplicated key.
        Assert.IsTrue(LCache.TryGet(LDupTarget, LValue),
          Format('Iter %d: duplicate key must remain in cache', [Iter]));
        Assert.AreEqual('updated-' + IntToStr(LDupTimes - 1), LValue,
          Format('Iter %d: Get must return most recent value', [Iter]));

        // 3. Drive more new keys to force evictions. We add CMaxItems
        //    new keys, which should evict the original k0..k(N-1) in
        //    the original insertion order. If duplicate FIFO entries
        //    were leaking the eviction sequence would still be correct
        //    because EvictFIFO drains stale entries until it finds a
        //    live key, but Count and OnEvict must report exactly one
        //    eviction per overflowing Put.
        LExtra := CMaxItems;
        for var I := 0 to LExtra - 1 do
          LCache.Put('n' + IntToStr(I), 'nv' + IntToStr(I));

        Assert.AreEqual<Integer>(CMaxItems, LCache.Count,
          Format('Iter %d: Count must stay <= MaxItems', [Iter]));
        Assert.AreEqual<Integer>(LExtra, LEvictedOrder.Count,
          Format('Iter %d: each overflowing Put must evict exactly once',
            [Iter]));

        // The evicted keys must be the original k0..k(N-1) in order.
        // This holds even though the duplicate target was re-Put many
        // times; with the fix it never moves in the FIFO queue.
        for var I := 0 to LExtra - 1 do
          Assert.AreEqual('k' + IntToStr(I), LEvictedOrder[I],
            Format('Iter %d: eviction %d should be k%d but was %s',
              [Iter, I, I, LEvictedOrder[I]]));

        // The duplicated key has now been evicted as well; the
        // surviving keys are exactly the n* set we inserted last.
        for var I := 0 to LExtra - 1 do
        begin
          Assert.IsTrue(LCache.TryGet('n' + IntToStr(I), LValue),
            Format('Iter %d: n%d must remain in cache', [Iter, I]));
          Assert.AreEqual('nv' + IntToStr(I), LValue,
            Format('Iter %d: n%d value mismatch', [Iter, I]));
        end;

        // The duplicated original key must NOT be in the cache anymore.
        Assert.IsFalse(LCache.TryGet(LDupTarget, LValue),
          Format('Iter %d: duplicated original key %s should be evicted',
            [Iter, LDupTarget]));
      finally
        LEvictedOrder.Free;
      end;
    finally
      LCache.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCacheFIFOPropertyTests);

end.
