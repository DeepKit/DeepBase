{ ============================================================================
  Test.UniBase.Memory - Memory Management Unit Tests
  
  Version: 1.0
  Description: Unit tests for advanced memory management utilities
  
  Test Coverage:
  - TObjectPool<T>: Generic object pooling
  - TMemoryBlockPool: Fixed-size memory block pool
  - TSmartCache<K,V>: Smart caching with eviction policies
  - TMemoryStats: Memory statistics
  ============================================================================ }

unit Test.UniBase.Memory;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Threading,
  DUnitX.TestFramework;

type
  /// <summary>Test object for pooling</summary>
  TTestPoolObject = class
  private
    FValue: Integer;
    FResetCalled: Boolean;
  public
    constructor Create;
    procedure Reset;
    property Value: Integer read FValue write FValue;
    property ResetCalled: Boolean read FResetCalled;
  end;
  
  /// <summary>
  /// Test fixture for TObjectPool<T>
  /// </summary>
  [TestFixture]
  TTestObjectPool = class
  public
    [Test]
    procedure Test_Create_InitializesPool;
    
    [Test]
    procedure Test_Acquire_ReturnsObject;
    
    [Test]
    procedure Test_Release_ReturnsToPool;
    
    [Test]
    procedure Test_Acquire_ReusesReleased;
    
    [Test]
    procedure Test_TryAcquire_ReturnsTrueWhenAvailable;
    
    [Test]
    procedure Test_TryAcquire_ReturnsFalseWhenExhausted;
    
    [Test]
    procedure Test_AvailableCount_DecreasesOnAcquire;
    
    [Test]
    procedure Test_InUseCount_IncreasesOnAcquire;
    
    [Test]
    procedure Test_Clear_ReleasesAllObjects;
    
    [Test]
    procedure Test_Warmup_PreallocatesObjects;
    
    [Test]
    procedure Test_Compact_ShrinksTOMinSize;
    
    [Test]
    procedure Test_SetResetProc_CallsOnRelease;

    [Test]
    procedure Test_ResetProcException_DiscardsObject;
    
    [Test]
    procedure Test_GetStats_ReturnsStatistics;
    
    [Test]
    procedure Test_MaxSize_LimitsPoolGrowth;
    
    [Test]
    procedure Test_ThreadSafety_ConcurrentAccess;
  end;
  
  /// <summary>
  /// Test fixture for TMemoryBlockPool
  /// </summary>
  [TestFixture]
  TTestMemoryBlockPool = class
  public
    [Test]
    procedure Test_Create_WithBlockSize;
    
    [Test]
    procedure Test_Allocate_ReturnsPointer;
    
    [Test]
    procedure Test_Deallocate_ReturnsToPool;
    
    [Test]
    procedure Test_Allocate_ReusesBlocks;
    
    [Test]
    procedure Test_AllocatedCount_Increases;
    
    [Test]
    procedure Test_FreeCount_Changes;
    
    [Test]
    procedure Test_Clear_FreesAllBlocks;
    
    [Test]
    procedure Test_BlockSize_MatchesSpecified;
    
    [Test]
    procedure Test_MultipleAllocations;
  end;
  
  /// <summary>
  /// Test fixture for TSmartCache<K,V>
  /// </summary>
  [TestFixture]
  TTestSmartCache = class
  public
    [Test]
    procedure Test_Create_InitializesCache;
    
    [Test]
    procedure Test_Put_AddsEntry;
    
    [Test]
    procedure Test_Get_ReturnsValue;
    
    [Test]
    procedure Test_TryGet_ReturnsTrueWhenExists;
    
    [Test]
    procedure Test_TryGet_ReturnsFalseWhenMissing;
    
    [Test]
    procedure Test_Contains_ReturnsTrue;
    
    [Test]
    procedure Test_Contains_ReturnsFalse;
    
    [Test]
    procedure Test_Remove_RemovesEntry;
    
    [Test]
    procedure Test_Clear_RemovesAllEntries;
    
    [Test]
    procedure Test_GetOrAdd_ReturnsExisting;
    
    [Test]
    procedure Test_GetOrAdd_CreatesNew;
    
    [Test]
    procedure Test_MaxSize_TriggersEviction;

    [Test]
    procedure Test_EvictionPolicy_None_RaisesWhenFull;
    
    [Test]
    procedure Test_EvictionPolicy_LRU;
    
    [Test]
    procedure Test_EvictionPolicy_FIFO;
    
    [Test]
    procedure Test_TTL_ExpiresEntries;
    
    [Test]
    procedure Test_OnEvict_CalledOnEviction;
    
    [Test]
    procedure Test_Stats_TracksHitsMisses;
  end;
  
  /// <summary>
  /// Test fixture for TMemoryStats
  /// </summary>
  [TestFixture]
  TTestMemoryStats = class
  public
    [Test]
    procedure Test_ToString_FormatsCorrectly;
    
    [Test]
    procedure Test_DefaultValues_AreZero;
  end;

implementation

uses
  UniBase.Memory;

{ TTestPoolObject }

constructor TTestPoolObject.Create;
begin
  inherited;
  FValue := 0;
  FResetCalled := False;
end;

procedure TTestPoolObject.Reset;
begin
  FValue := 0;
  FResetCalled := True;
end;

{ TTestObjectPool }

procedure TTestObjectPool.Test_Create_InitializesPool;
var
  Pool: TObjectPool<TTestPoolObject>;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    5, 20);
  try
    Assert.IsNotNull(Pool);
    Assert.AreEqual(5, Pool.MinSize);
    Assert.AreEqual(20, Pool.MaxSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Acquire_ReturnsObject;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Obj := Pool.Acquire;
    Assert.IsNotNull(Obj);
    Pool.Release(Obj);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Release_ReturnsToPool;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  AvailBefore, AvailAfter: Integer;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Obj := Pool.Acquire;
    AvailBefore := Pool.AvailableCount;
    Pool.Release(Obj);
    AvailAfter := Pool.AvailableCount;
    Assert.AreEqual(AvailBefore + 1, AvailAfter);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Acquire_ReusesReleased;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj1, Obj2: TTestPoolObject;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    1, 1);
  try
    Obj1 := Pool.Acquire;
    Obj1.Value := 42;
    Pool.Release(Obj1);
    
    Obj2 := Pool.Acquire;
    // Should be same object (reused)
    Assert.AreSame(Obj1, Obj2);
    Pool.Release(Obj2);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_TryAcquire_ReturnsTrueWhenAvailable;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  Success: Boolean;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Success := Pool.TryAcquire(Obj);
    Assert.IsTrue(Success);
    Assert.IsNotNull(Obj);
    Pool.Release(Obj);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_TryAcquire_ReturnsFalseWhenExhausted;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj, Obj2: TTestPoolObject;
  Success: Boolean;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    1, 1);
  try
    Obj := Pool.Acquire;
    Success := Pool.TryAcquire(Obj2);
    Assert.IsFalse(Success);
    Pool.Release(Obj);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_AvailableCount_DecreasesOnAcquire;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  CountBefore, CountAfter: Integer;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    5, 10);
  try
    Pool.Warmup(5);
    CountBefore := Pool.AvailableCount;
    Obj := Pool.Acquire;
    CountAfter := Pool.AvailableCount;
    Assert.AreEqual(CountBefore - 1, CountAfter);
    Pool.Release(Obj);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_InUseCount_IncreasesOnAcquire;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Assert.AreEqual(0, Pool.InUseCount);
    Obj := Pool.Acquire;
    Assert.AreEqual(1, Pool.InUseCount);
    Pool.Release(Obj);
    Assert.AreEqual(0, Pool.InUseCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Clear_ReleasesAllObjects;
var
  Pool: TObjectPool<TTestPoolObject>;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Pool.Warmup(10);
    Assert.IsTrue(Pool.AvailableCount > 0);
    Pool.Clear;
    Assert.AreEqual(0, Pool.AvailableCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Warmup_PreallocatesObjects;
var
  Pool: TObjectPool<TTestPoolObject>;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    0, 100);
  try
    Assert.AreEqual(0, Pool.AvailableCount);
    Pool.Warmup(10);
    Assert.AreEqual(10, Pool.AvailableCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_Compact_ShrinksTOMinSize;
var
  Pool: TObjectPool<TTestPoolObject>;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    5, 100);
  try
    Pool.Warmup(50);
    Assert.AreEqual(50, Pool.AvailableCount);
    Pool.Compact;
    Assert.IsTrue(Pool.AvailableCount <= Pool.MinSize + 5);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_SetResetProc_CallsOnRelease;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  ResetCalled: Boolean;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    ResetCalled := False;
    Pool.SetResetProc(
      procedure(O: TTestPoolObject)
      begin
        O.Reset;
        ResetCalled := True;
      end);
    
    Obj := Pool.Acquire;
    Obj.Value := 100;
    Pool.Release(Obj);
    
    Assert.IsTrue(ResetCalled);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_ResetProcException_DiscardsObject;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  Replacement: TTestPoolObject;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    0, 1);
  try
    Pool.SetResetProc(
      procedure(O: TTestPoolObject)
      begin
        raise Exception.Create('reset failed');
      end);

    Obj := Pool.Acquire;
    Pool.Release(Obj);

    Assert.AreEqual(0, Pool.InUseCount);
    Assert.AreEqual(0, Pool.AvailableCount);

    Pool.SetResetProc(nil);
    Assert.IsTrue(Pool.TryAcquire(Replacement));
    Pool.Release(Replacement);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_GetStats_ReturnsStatistics;
var
  Pool: TObjectPool<TTestPoolObject>;
  Obj: TTestPoolObject;
  Stats: TMemoryStats;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end);
  try
    Obj := Pool.Acquire;
    Pool.Release(Obj);
    Stats := Pool.GetStats;
    Assert.IsTrue(Stats.AllocationCount > 0);
  finally
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_MaxSize_LimitsPoolGrowth;
var
  Pool: TObjectPool<TTestPoolObject>;
  Objs: TList<TTestPoolObject>;
  I: Integer;
  ExtraObj: TTestPoolObject;
  Success: Boolean;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    1, 5);
  Objs := TList<TTestPoolObject>.Create;
  try
    // Acquire all from pool
    for I := 1 to 5 do
      Objs.Add(Pool.Acquire);
    
    // Try to acquire one more - should fail
    Success := Pool.TryAcquire(ExtraObj);
    Assert.IsFalse(Success);
    
    // Release all
    for I := 0 to Objs.Count - 1 do
      Pool.Release(Objs[I]);
  finally
    Objs.Free;
    Pool.Free;
  end;
end;

procedure TTestObjectPool.Test_ThreadSafety_ConcurrentAccess;
var
  Pool: TObjectPool<TTestPoolObject>;
  Tasks: array[0..9] of ITask;
  I: Integer;
  ErrorCount: Integer;
begin
  Pool := TObjectPool<TTestPoolObject>.Create(
    function: TTestPoolObject begin Result := TTestPoolObject.Create; end,
    10, 50);
  try
    ErrorCount := 0;
    
    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          Obj: TTestPoolObject;
          J: Integer;
        begin
          try
            for J := 1 to 100 do
            begin
              Obj := Pool.Acquire;
              Obj.Value := J;
              Sleep(1);
              Pool.Release(Obj);
            end;
          except
            TInterlocked.Increment(ErrorCount);
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    Assert.AreEqual(0, ErrorCount);
  finally
    Pool.Free;
  end;
end;

{ TTestMemoryBlockPool }

procedure TTestMemoryBlockPool.Test_Create_WithBlockSize;
var
  Pool: TMemoryBlockPool;
begin
  Pool := TMemoryBlockPool.Create(256);
  try
    Assert.AreEqual(256, Pool.BlockSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_Allocate_ReturnsPointer;
var
  Pool: TMemoryBlockPool;
  P: Pointer;
begin
  Pool := TMemoryBlockPool.Create(128);
  try
    P := Pool.Allocate;
    Assert.IsTrue(P <> nil);
    Pool.Deallocate(P);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_Deallocate_ReturnsToPool;
var
  Pool: TMemoryBlockPool;
  P: Pointer;
  FreeBefore, FreeAfter: Integer;
begin
  Pool := TMemoryBlockPool.Create(128);
  try
    P := Pool.Allocate;
    FreeBefore := Pool.FreeCount;
    Pool.Deallocate(P);
    FreeAfter := Pool.FreeCount;
    Assert.AreEqual(FreeBefore + 1, FreeAfter);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_Allocate_ReusesBlocks;
var
  Pool: TMemoryBlockPool;
  P1, P2: Pointer;
begin
  Pool := TMemoryBlockPool.Create(128, 1, 1);
  try
    P1 := Pool.Allocate;
    Pool.Deallocate(P1);
    P2 := Pool.Allocate;
    Assert.AreEqual(P1, P2);
    Pool.Deallocate(P2);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_AllocatedCount_Increases;
var
  Pool: TMemoryBlockPool;
  P: Pointer;
begin
  Pool := TMemoryBlockPool.Create(128, 0, 1);
  try
    Assert.AreEqual(0, Pool.AllocatedCount);
    P := Pool.Allocate;
    Assert.IsTrue(Pool.AllocatedCount > 0);
    Pool.Deallocate(P);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_FreeCount_Changes;
var
  Pool: TMemoryBlockPool;
  P: Pointer;
  InitFree: Integer;
begin
  Pool := TMemoryBlockPool.Create(128, 10, 5);
  try
    InitFree := Pool.FreeCount;
    P := Pool.Allocate;
    Assert.AreEqual(InitFree - 1, Pool.FreeCount);
    Pool.Deallocate(P);
    Assert.AreEqual(InitFree, Pool.FreeCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_Clear_FreesAllBlocks;
var
  Pool: TMemoryBlockPool;
begin
  Pool := TMemoryBlockPool.Create(128, 10, 5);
  try
    Pool.Clear;
    Assert.AreEqual(0, Pool.FreeCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_BlockSize_MatchesSpecified;
var
  Pool: TMemoryBlockPool;
begin
  Pool := TMemoryBlockPool.Create(512);
  try
    Assert.AreEqual(512, Pool.BlockSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestMemoryBlockPool.Test_MultipleAllocations;
var
  Pool: TMemoryBlockPool;
  Ptrs: array[0..9] of Pointer;
  I, InitFree: Integer;
begin
  Pool := TMemoryBlockPool.Create(64, 20, 10);
  try
    InitFree := Pool.FreeCount;

    for I := 0 to 9 do
      Ptrs[I] := Pool.Allocate;
    
    Assert.AreEqual(10, Pool.AllocatedCount);
    
    for I := 0 to 9 do
      Pool.Deallocate(Ptrs[I]);
      
    Assert.AreEqual(InitFree, Pool.FreeCount);
  finally
    Pool.Free;
  end;
end;

{ TTestSmartCache }

procedure TTestSmartCache.Test_Create_InitializesCache;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Assert.IsNotNull(Cache);
    Assert.AreEqual(0, Integer(Cache.Count));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Put_AddsEntry;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 100);
    Assert.AreEqual(1, Integer(Cache.Count));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Get_ReturnsValue;
var
  Cache: TSmartCache<string, Integer>;
  Value: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 42);
    Value := Cache.Get('key1');
    Assert.AreEqual(42, Value);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_TryGet_ReturnsTrueWhenExists;
var
  Cache: TSmartCache<string, Integer>;
  Value: Integer;
  Found: Boolean;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 100);
    Found := Cache.TryGet('key1', Value);
    Assert.IsTrue(Found);
    Assert.AreEqual(100, Value);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_TryGet_ReturnsFalseWhenMissing;
var
  Cache: TSmartCache<string, Integer>;
  Value: Integer;
  Found: Boolean;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Found := Cache.TryGet('nonexistent', Value);
    Assert.IsFalse(Found);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Contains_ReturnsTrue;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 1);
    Assert.IsTrue(Cache.Contains('key1'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Contains_ReturnsFalse;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Assert.IsFalse(Cache.Contains('missing'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Remove_RemovesEntry;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 1);
    Assert.IsTrue(Cache.Remove('key1'));
    Assert.IsFalse(Cache.Contains('key1'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Clear_RemovesAllEntries;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 1);
    Cache.Put('key2', 2);
    Cache.Put('key3', 3);
    Cache.Clear;
    Assert.AreEqual(0, Integer(Cache.Count));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_GetOrAdd_ReturnsExisting;
var
  Cache: TSmartCache<string, Integer>;
  Value: Integer;
  FactoryCalled: Boolean;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    FactoryCalled := False;
    Cache.Put('key1', 100);
    
    Value := Cache.GetOrAdd('key1',
      function: Integer
      begin
        FactoryCalled := True;
        Result := 999;
      end);
    
    Assert.AreEqual(100, Value);
    Assert.IsFalse(FactoryCalled);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_GetOrAdd_CreatesNew;
var
  Cache: TSmartCache<string, Integer>;
  Value: Integer;
  FactoryCalled: Boolean;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    FactoryCalled := False;
    
    Value := Cache.GetOrAdd('newkey',
      function: Integer
      begin
        FactoryCalled := True;
        Result := 42;
      end);
    
    Assert.AreEqual(42, Value);
    Assert.IsTrue(FactoryCalled);
    Assert.IsTrue(Cache.Contains('newkey'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_MaxSize_TriggersEviction;
var
  Cache: TSmartCache<string, Integer>;
  I: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.MaxSize := 5;
    Cache.EvictionPolicy := epLRU;
    
    for I := 1 to 10 do
      Cache.Put('key' + I.ToString, I);
    
    Assert.IsTrue(Cache.Count <= 5);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_EvictionPolicy_None_RaisesWhenFull;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.MaxSize := 2;
    Cache.EvictionPolicy := epNone;
    Cache.Put('A', 1);
    Cache.Put('B', 2);

    Assert.WillRaise(
      procedure
      begin
        Cache.Put('C', 3);
      end,
      EMemoryCacheException);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_EvictionPolicy_LRU;
var
  Cache: TSmartCache<string, Integer>;
  Val: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.MaxSize := 3;
    Cache.EvictionPolicy := epLRU;
    
    Cache.Put('A', 1);
    Cache.Put('B', 2);
    Cache.Put('C', 3);
    
    // Access A to make it recently used
    Cache.TryGet('A', Val);
    
    // Add D - should evict B (least recently used)
    Cache.Put('D', 4);
    
    Assert.IsTrue(Cache.Contains('A'));
    Assert.IsFalse(Cache.Contains('B'));
    Assert.IsTrue(Cache.Contains('C'));
    Assert.IsTrue(Cache.Contains('D'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_EvictionPolicy_FIFO;
var
  Cache: TSmartCache<string, Integer>;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.MaxSize := 3;
    Cache.EvictionPolicy := epFIFO;
    
    Cache.Put('A', 1);
    Cache.Put('B', 2);
    Cache.Put('C', 3);
    
    // Add D - should evict A (first in)
    Cache.Put('D', 4);
    
    Assert.IsFalse(Cache.Contains('A'));
    Assert.IsTrue(Cache.Contains('B'));
    Assert.IsTrue(Cache.Contains('C'));
    Assert.IsTrue(Cache.Contains('D'));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_TTL_ExpiresEntries;
var
  Cache: TSmartCache<string, Integer>;
  Val: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.DefaultTTL := 1; // 1 second TTL
    Cache.Put('short', 100, 1);
    
    Assert.IsTrue(Cache.TryGet('short', Val));
    
    Sleep(1500); // Wait for expiration
    
    Assert.IsFalse(Cache.TryGet('short', Val));
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_OnEvict_CalledOnEviction;
var
  Cache: TSmartCache<string, Integer>;
  EvictedKey: string;
  EvictedValue: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.MaxSize := 2;
    Cache.EvictionPolicy := epFIFO;
    
    EvictedKey := '';
    EvictedValue := 0;
    
    Cache.OnEvict := 
      procedure(K: string; V: Integer)
      begin
        EvictedKey := K;
        EvictedValue := V;
      end;
    
    Cache.Put('A', 1);
    Cache.Put('B', 2);
    Cache.Put('C', 3); // Should trigger eviction of A
    
    Assert.AreEqual('A', EvictedKey);
    Assert.AreEqual(1, EvictedValue);
  finally
    Cache.Free;
  end;
end;

procedure TTestSmartCache.Test_Stats_TracksHitsMisses;
var
  Cache: TSmartCache<string, Integer>;
  Stats: TMemoryStats;
  Val: Integer;
begin
  Cache := TSmartCache<string, Integer>.Create;
  try
    Cache.Put('key1', 100);
    
    // Hit
    Cache.TryGet('key1', Val);
    // Miss
    Cache.TryGet('missing', Val);
    
    Stats := Cache.GetStats;
    Assert.IsTrue(Stats.CacheHits > 0);
    Assert.IsTrue(Stats.CacheMisses > 0);
  finally
    Cache.Free;
  end;
end;

{ TTestMemoryStats }

procedure TTestMemoryStats.Test_ToString_FormatsCorrectly;
var
  Stats: TMemoryStats;
  S: string;
begin
  Stats := Default(TMemoryStats);
  Stats.TotalAllocated := 1000;
  Stats.CurrentUsage := 500;
  S := Stats.ToString;
  Assert.IsTrue(S.Contains('1000') or S.Contains('500'));
end;

procedure TTestMemoryStats.Test_DefaultValues_AreZero;
var
  Stats: TMemoryStats;
begin
  Stats := Default(TMemoryStats);
  Assert.AreEqual(Int64(0), Stats.TotalAllocated);
  Assert.AreEqual(Int64(0), Stats.CurrentUsage);
  Assert.AreEqual(Int64(0), Stats.AllocationCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestObjectPool);
  TDUnitX.RegisterTestFixture(TTestMemoryBlockPool);
  TDUnitX.RegisterTestFixture(TTestSmartCache);
  TDUnitX.RegisterTestFixture(TTestMemoryStats);

end.
