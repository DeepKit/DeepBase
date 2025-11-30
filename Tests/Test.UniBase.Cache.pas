unit Test.UniBase.Cache;

{*******************************************************************************
  UniBase Cache Module Unit Tests
  
  Test Coverage:
  - Basic CRUD operations (Put/Get/Remove/Clear)
  - Eviction policies (LRU, LFU, FIFO, TTL)
  - TTL expiration
  - Size limits and eviction
  - Cache statistics (Hits/Misses/HitRate)
  - Thread safety
  - Batch operations
  - Event callbacks (OnEvict, OnExpire, OnLoad)
  - TMemoryCache singleton
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  System.DateUtils,
  UniBase.Cache;

type
  [TestFixture]
  TTestUniBaseCache = class
  private
    FCache: TCache<string, string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Basic Operations
    [Test]
    procedure Test_Put_And_Get_String;
    
    [Test]
    procedure Test_Put_And_Get_Integer_Keys;
    
    [Test]
    procedure Test_Get_NonExistent_ReturnsDefault;
    
    [Test]
    procedure Test_TryGet_ExistingKey_ReturnsTrue;
    
    [Test]
    procedure Test_TryGet_NonExistent_ReturnsFalse;
    
    [Test]
    procedure Test_Contains_ExistingKey;
    
    [Test]
    procedure Test_Contains_NonExistent;
    
    [Test]
    procedure Test_Remove_ExistingKey;
    
    [Test]
    procedure Test_Remove_NonExistent_ReturnsFalse;
    
    [Test]
    procedure Test_Clear_RemovesAllItems;
    
    [Test]
    procedure Test_Count_Property;
    
    [Test]
    procedure Test_Keys_Property;
    
    // Eviction Policies
    [Test]
    procedure Test_LRU_EvictsLeastRecentlyUsed;
    
    [Test]
    procedure Test_LFU_EvictsLeastFrequentlyUsed;
    
    [Test]
    procedure Test_FIFO_EvictsFirstInserted;
    
    // TTL Expiration
    [Test]
    procedure Test_TTL_ItemExpiresAfterTimeout;
    
    [Test]
    procedure Test_TTL_GetExpiredItem_ReturnsFalse;
    
    [Test]
    procedure Test_SetTTL_UpdatesExpiration;
    
    [Test]
    procedure Test_GetTTL_ReturnsRemainingTime;
    
    [Test]
    procedure Test_Cleanup_RemovesExpiredItems;
    
    // Size Limits
    [Test]
    procedure Test_MaxItems_EvictsWhenFull;
    
    [Test]
    procedure Test_Put_UpdateExisting_NoEviction;
    
    // Statistics
    [Test]
    procedure Test_Stats_HitIncrementsOnGet;
    
    [Test]
    procedure Test_Stats_MissIncrementsOnMiss;
    
    [Test]
    procedure Test_Stats_HitRate_Calculation;
    
    [Test]
    procedure Test_Stats_EvictionCount;
    
    // Batch Operations
    [Test]
    procedure Test_GetMany_ReturnsMatchingItems;
    
    [Test]
    procedure Test_PutMany_InsertsMultipleItems;
    
    [Test]
    procedure Test_RemoveMany_RemovesMultipleItems;
    
    // Events
    [Test]
    procedure Test_OnEvict_CalledOnEviction;
    
    [Test]
    procedure Test_OnLoad_CalledOnGetOrLoad;
    
    // Thread Safety
    [Test]
    procedure Test_ThreadSafety_ConcurrentReadWrite;
  end;

  [TestFixture]
  TTestMemoryCache = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Put_And_Get;
    
    [Test]
    procedure Test_TryGet_ExistingKey;
    
    [Test]
    procedure Test_Contains;
    
    [Test]
    procedure Test_Remove;
    
    [Test]
    procedure Test_Clear;
  end;

  [TestFixture]
  TTestCacheStats = class
  public
    [Test]
    procedure Test_HitRate_NoAccesses_ReturnsZero;
    
    [Test]
    procedure Test_HitRate_AllHits_ReturnsOne;
    
    [Test]
    procedure Test_HitRate_HalfHits_ReturnsHalf;
    
    [Test]
    procedure Test_MissRate_ComplementOfHitRate;
    
    [Test]
    procedure Test_Reset_ClearsAllCounters;
    
    [Test]
    procedure Test_ToString_FormatsCorrectly;
  end;

implementation

{ TTestUniBaseCache }

procedure TTestUniBaseCache.Setup;
begin
  FCache := TCache<string, string>.Create;
end;

procedure TTestUniBaseCache.TearDown;
begin
  FCache.Free;
  FCache := nil;
end;

procedure TTestUniBaseCache.Test_Put_And_Get_String;
begin
  FCache.Put('key1', 'value1');
  Assert.AreEqual('value1', FCache.Get('key1'));
end;

procedure TTestUniBaseCache.Test_Put_And_Get_Integer_Keys;
var
  IntCache: TCache<Integer, string>;
begin
  IntCache := TCache<Integer, string>.Create;
  try
    IntCache.Put(1, 'one');
    IntCache.Put(2, 'two');
    IntCache.Put(3, 'three');
    
    Assert.AreEqual('one', IntCache.Get(1));
    Assert.AreEqual('two', IntCache.Get(2));
    Assert.AreEqual('three', IntCache.Get(3));
  finally
    IntCache.Free;
  end;
end;

procedure TTestUniBaseCache.Test_Get_NonExistent_ReturnsDefault;
begin
  Assert.AreEqual('default', FCache.Get('nonexistent', 'default'));
end;

procedure TTestUniBaseCache.Test_TryGet_ExistingKey_ReturnsTrue;
var
  Value: string;
begin
  FCache.Put('key1', 'value1');
  Assert.IsTrue(FCache.TryGet('key1', Value));
  Assert.AreEqual('value1', Value);
end;

procedure TTestUniBaseCache.Test_TryGet_NonExistent_ReturnsFalse;
var
  Value: string;
begin
  Assert.IsFalse(FCache.TryGet('nonexistent', Value));
end;

procedure TTestUniBaseCache.Test_Contains_ExistingKey;
begin
  FCache.Put('key1', 'value1');
  Assert.IsTrue(FCache.Contains('key1'));
end;

procedure TTestUniBaseCache.Test_Contains_NonExistent;
begin
  Assert.IsFalse(FCache.Contains('nonexistent'));
end;

procedure TTestUniBaseCache.Test_Remove_ExistingKey;
begin
  FCache.Put('key1', 'value1');
  Assert.IsTrue(FCache.Remove('key1'));
  Assert.IsFalse(FCache.Contains('key1'));
end;

procedure TTestUniBaseCache.Test_Remove_NonExistent_ReturnsFalse;
begin
  Assert.IsFalse(FCache.Remove('nonexistent'));
end;

procedure TTestUniBaseCache.Test_Clear_RemovesAllItems;
begin
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  Assert.AreEqual(3, FCache.Count);
  
  FCache.Clear;
  
  Assert.AreEqual(0, FCache.Count);
  Assert.IsFalse(FCache.Contains('key1'));
end;

procedure TTestUniBaseCache.Test_Count_Property;
begin
  Assert.AreEqual(0, FCache.Count);
  
  FCache.Put('key1', 'value1');
  Assert.AreEqual(1, FCache.Count);
  
  FCache.Put('key2', 'value2');
  Assert.AreEqual(2, FCache.Count);
  
  FCache.Remove('key1');
  Assert.AreEqual(1, FCache.Count);
end;

procedure TTestUniBaseCache.Test_Keys_Property;
var
  Keys: TArray<string>;
begin
  FCache.Put('apple', 'fruit');
  FCache.Put('carrot', 'vegetable');
  FCache.Put('banana', 'fruit');
  
  Keys := FCache.Keys;
  
  Assert.AreEqual(3, Length(Keys));
end;

procedure TTestUniBaseCache.Test_LRU_EvictsLeastRecentlyUsed;
var
  Value: string;
begin
  FCache.MaxItems := 3;
  FCache.EvictionPolicy := cepLRU;
  
  // Add 3 items
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  // Access key1 and key3, making key2 least recently used
  FCache.Get('key1');
  FCache.Get('key3');
  
  // Add new item, should evict key2
  FCache.Put('key4', 'value4');
  
  Assert.IsTrue(FCache.Contains('key1'), 'key1 should still exist');
  Assert.IsFalse(FCache.Contains('key2'), 'key2 should be evicted (LRU)');
  Assert.IsTrue(FCache.Contains('key3'), 'key3 should still exist');
  Assert.IsTrue(FCache.Contains('key4'), 'key4 should exist');
end;

procedure TTestUniBaseCache.Test_LFU_EvictsLeastFrequentlyUsed;
var
  I: Integer;
begin
  FCache.MaxItems := 3;
  FCache.EvictionPolicy := cepLFU;
  
  // Add 3 items
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  // Access key1 5 times, key3 3 times, key2 1 time
  for I := 1 to 5 do FCache.Get('key1');
  for I := 1 to 3 do FCache.Get('key3');
  FCache.Get('key2');
  
  // Add new item, should evict key2 (least frequently used)
  FCache.Put('key4', 'value4');
  
  Assert.IsTrue(FCache.Contains('key1'), 'key1 should still exist (most accessed)');
  Assert.IsFalse(FCache.Contains('key2'), 'key2 should be evicted (LFU)');
  Assert.IsTrue(FCache.Contains('key3'), 'key3 should still exist');
  Assert.IsTrue(FCache.Contains('key4'), 'key4 should exist');
end;

procedure TTestUniBaseCache.Test_FIFO_EvictsFirstInserted;
begin
  FCache.MaxItems := 3;
  FCache.EvictionPolicy := cepFIFO;
  
  // Add 3 items
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  // Add new item, should evict key1 (first in)
  FCache.Put('key4', 'value4');
  
  Assert.IsFalse(FCache.Contains('key1'), 'key1 should be evicted (FIFO)');
  Assert.IsTrue(FCache.Contains('key2'), 'key2 should still exist');
  Assert.IsTrue(FCache.Contains('key3'), 'key3 should still exist');
  Assert.IsTrue(FCache.Contains('key4'), 'key4 should exist');
end;

procedure TTestUniBaseCache.Test_TTL_ItemExpiresAfterTimeout;
var
  Value: string;
begin
  FCache.Put('key1', 'value1', 1); // 1 second TTL
  
  Assert.IsTrue(FCache.TryGet('key1', Value), 'Item should exist immediately');
  
  Sleep(1500); // Wait for expiration
  
  Assert.IsFalse(FCache.TryGet('key1', Value), 'Item should be expired');
end;

procedure TTestUniBaseCache.Test_TTL_GetExpiredItem_ReturnsFalse;
var
  Value: string;
begin
  FCache.Put('key1', 'value1', 1); // 1 second TTL
  Sleep(1500);
  
  Assert.IsFalse(FCache.TryGet('key1', Value));
end;

procedure TTestUniBaseCache.Test_SetTTL_UpdatesExpiration;
var
  Value: string;
begin
  FCache.Put('key1', 'value1', 1); // 1 second TTL
  
  // Extend TTL
  FCache.SetTTL('key1', 10);
  
  Sleep(1500); // Wait past original TTL
  
  Assert.IsTrue(FCache.TryGet('key1', Value), 'Item should still exist with extended TTL');
end;

procedure TTestUniBaseCache.Test_GetTTL_ReturnsRemainingTime;
var
  TTL: Integer;
begin
  FCache.Put('key1', 'value1', 10); // 10 second TTL
  
  TTL := FCache.GetTTL('key1');
  
  Assert.IsTrue((TTL >= 8) and (TTL <= 10), 'TTL should be approximately 10 seconds');
end;

procedure TTestUniBaseCache.Test_Cleanup_RemovesExpiredItems;
begin
  FCache.Put('key1', 'value1', 1); // 1 second TTL
  FCache.Put('key2', 'value2', 0); // No TTL
  FCache.Put('key3', 'value3', 1); // 1 second TTL
  
  Sleep(1500);
  
  FCache.Cleanup;
  
  Assert.IsFalse(FCache.Contains('key1'), 'Expired key1 should be removed');
  Assert.IsTrue(FCache.Contains('key2'), 'Non-expiring key2 should remain');
  Assert.IsFalse(FCache.Contains('key3'), 'Expired key3 should be removed');
end;

procedure TTestUniBaseCache.Test_MaxItems_EvictsWhenFull;
begin
  FCache.MaxItems := 5;
  
  // Add 10 items
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  FCache.Put('key4', 'value4');
  FCache.Put('key5', 'value5');
  FCache.Put('key6', 'value6');
  FCache.Put('key7', 'value7');
  FCache.Put('key8', 'value8');
  FCache.Put('key9', 'value9');
  FCache.Put('key10', 'value10');
  
  Assert.AreEqual(5, FCache.Count, 'Cache should maintain MaxItems limit');
end;

procedure TTestUniBaseCache.Test_Put_UpdateExisting_NoEviction;
begin
  FCache.MaxItems := 3;
  
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  // Update existing key
  FCache.Put('key1', 'updated_value1');
  
  Assert.AreEqual(3, FCache.Count, 'Count should remain 3');
  Assert.AreEqual('updated_value1', FCache.Get('key1'));
  Assert.IsTrue(FCache.Contains('key2'), 'key2 should not be evicted');
  Assert.IsTrue(FCache.Contains('key3'), 'key3 should not be evicted');
end;

procedure TTestUniBaseCache.Test_Stats_HitIncrementsOnGet;
var
  Value: string;
  InitialHits: Int64;
begin
  FCache.Put('key1', 'value1');
  InitialHits := FCache.Stats.Hits;
  
  FCache.TryGet('key1', Value);
  
  Assert.AreEqual(InitialHits + 1, FCache.Stats.Hits);
end;

procedure TTestUniBaseCache.Test_Stats_MissIncrementsOnMiss;
var
  Value: string;
  InitialMisses: Int64;
begin
  InitialMisses := FCache.Stats.Misses;
  
  FCache.TryGet('nonexistent', Value);
  
  Assert.AreEqual(InitialMisses + 1, FCache.Stats.Misses);
end;

procedure TTestUniBaseCache.Test_Stats_HitRate_Calculation;
var
  Value: string;
begin
  FCache.Put('key1', 'value1');
  
  // 2 hits
  FCache.TryGet('key1', Value);
  FCache.TryGet('key1', Value);
  
  // 2 misses
  FCache.TryGet('miss1', Value);
  FCache.TryGet('miss2', Value);
  
  // 2 hits out of 4 = 50%
  Assert.AreEqual(Double(0.5), FCache.Stats.HitRate, 0.001);
end;

procedure TTestUniBaseCache.Test_Stats_EvictionCount;
var
  InitialEvictions: Int64;
begin
  FCache.MaxItems := 2;
  InitialEvictions := FCache.Stats.Evictions;
  
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3'); // Should trigger eviction
  
  Assert.AreEqual(InitialEvictions + 1, FCache.Stats.Evictions);
end;

procedure TTestUniBaseCache.Test_GetMany_ReturnsMatchingItems;
var
  Results: TDictionary<string, string>;
  Keys: TArray<string>;
begin
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  
  Keys := TArray<string>.Create('key1', 'key3', 'nonexistent');
  Results := FCache.GetMany(Keys);
  try
    Assert.AreEqual(2, Results.Count);
    Assert.AreEqual('value1', Results['key1']);
    Assert.AreEqual('value3', Results['key3']);
    Assert.IsFalse(Results.ContainsKey('nonexistent'));
  finally
    Results.Free;
  end;
end;

procedure TTestUniBaseCache.Test_PutMany_InsertsMultipleItems;
var
  Items: TArray<TPair<string, string>>;
begin
  SetLength(Items, 3);
  Items[0] := TPair<string, string>.Create('key1', 'value1');
  Items[1] := TPair<string, string>.Create('key2', 'value2');
  Items[2] := TPair<string, string>.Create('key3', 'value3');
  
  FCache.PutMany(Items);
  
  Assert.AreEqual(3, FCache.Count);
  Assert.AreEqual('value1', FCache.Get('key1'));
  Assert.AreEqual('value2', FCache.Get('key2'));
  Assert.AreEqual('value3', FCache.Get('key3'));
end;

procedure TTestUniBaseCache.Test_RemoveMany_RemovesMultipleItems;
var
  Keys: TArray<string>;
begin
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3');
  FCache.Put('key4', 'value4');
  
  Keys := TArray<string>.Create('key1', 'key3');
  FCache.RemoveMany(Keys);
  
  Assert.AreEqual(2, FCache.Count);
  Assert.IsFalse(FCache.Contains('key1'));
  Assert.IsTrue(FCache.Contains('key2'));
  Assert.IsFalse(FCache.Contains('key3'));
  Assert.IsTrue(FCache.Contains('key4'));
end;

procedure TTestUniBaseCache.Test_OnEvict_CalledOnEviction;
var
  EvictedKey: string;
  EvictedValue: string;
  EvictCalled: Boolean;
begin
  EvictCalled := False;
  FCache.MaxItems := 2;
  FCache.OnEvict := procedure(const Key: string; const Value: string)
  begin
    EvictedKey := Key;
    EvictedValue := Value;
    EvictCalled := True;
  end;
  
  FCache.Put('key1', 'value1');
  FCache.Put('key2', 'value2');
  FCache.Put('key3', 'value3'); // Should trigger eviction
  
  Assert.IsTrue(EvictCalled, 'OnEvict should be called');
  Assert.AreEqual('value1', EvictedValue, 'First item should be evicted');
end;

procedure TTestUniBaseCache.Test_OnLoad_CalledOnGetOrLoad;
var
  LoadCalled: Boolean;
begin
  LoadCalled := False;
  FCache.OnLoad := function(const Key: string): string
  begin
    LoadCalled := True;
    Result := 'loaded_' + Key;
  end;
  
  // Key doesn't exist, should call OnLoad
  Assert.AreEqual('loaded_newkey', FCache.GetOrLoad('newkey'));
  Assert.IsTrue(LoadCalled, 'OnLoad should be called');
  
  // Value should now be cached
  LoadCalled := False;
  Assert.AreEqual('loaded_newkey', FCache.GetOrLoad('newkey'));
  Assert.IsFalse(LoadCalled, 'OnLoad should not be called for cached value');
end;

procedure TTestUniBaseCache.Test_ThreadSafety_ConcurrentReadWrite;
var
  Tasks: TArray<ITask>;
  I: Integer;
  ErrorCount: Integer;
  Lock: TCriticalSection;
const
  THREAD_COUNT = 10;
  ITERATIONS = 100;
begin
  ErrorCount := 0;
  Lock := TCriticalSection.Create;
  try
    SetLength(Tasks, THREAD_COUNT);
    
    for I := 0 to THREAD_COUNT - 1 do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          J: Integer;
          Key, Value: string;
          ThreadId: Integer;
        begin
          ThreadId := TThread.CurrentThread.ThreadID;
          for J := 1 to ITERATIONS do
          begin
            try
              Key := Format('key_%d_%d', [ThreadId, J]);
              Value := Format('value_%d_%d', [ThreadId, J]);
              
              FCache.Put(Key, Value);
              
              if FCache.Get(Key, '') <> Value then
              begin
                Lock.Enter;
                try
                  Inc(ErrorCount);
                finally
                  Lock.Leave;
                end;
              end;
              
              FCache.Remove(Key);
            except
              Lock.Enter;
              try
                Inc(ErrorCount);
              finally
                Lock.Leave;
              end;
            end;
          end;
        end);
    end;
    
    TTask.WaitForAll(Tasks);
    
    Assert.AreEqual(0, ErrorCount, 'No errors should occur in concurrent access');
  finally
    Lock.Free;
  end;
end;

{ TTestMemoryCache }

procedure TTestMemoryCache.Setup;
begin
  TMemoryCache.Clear;
end;

procedure TTestMemoryCache.TearDown;
begin
  TMemoryCache.Clear;
end;

procedure TTestMemoryCache.Test_Put_And_Get;
begin
  TMemoryCache.Put('test_key', 'test_value');
  Assert.AreEqual('test_value', string(TMemoryCache.Get('test_key')));
end;

procedure TTestMemoryCache.Test_TryGet_ExistingKey;
var
  Value: Variant;
begin
  TMemoryCache.Put('test_key', 123);
  Assert.IsTrue(TMemoryCache.TryGet('test_key', Value));
  Assert.AreEqual(123, Integer(Value));
end;

procedure TTestMemoryCache.Test_Contains;
begin
  TMemoryCache.Put('test_key', 'value');
  Assert.IsTrue(TMemoryCache.Contains('test_key'));
  Assert.IsFalse(TMemoryCache.Contains('nonexistent'));
end;

procedure TTestMemoryCache.Test_Remove;
begin
  TMemoryCache.Put('test_key', 'value');
  TMemoryCache.Remove('test_key');
  Assert.IsFalse(TMemoryCache.Contains('test_key'));
end;

procedure TTestMemoryCache.Test_Clear;
begin
  TMemoryCache.Put('key1', 'value1');
  TMemoryCache.Put('key2', 'value2');
  TMemoryCache.Clear;
  Assert.IsFalse(TMemoryCache.Contains('key1'));
  Assert.IsFalse(TMemoryCache.Contains('key2'));
end;

{ TTestCacheStats }

procedure TTestCacheStats.Test_HitRate_NoAccesses_ReturnsZero;
var
  Stats: TCacheStats;
begin
  Stats.Reset;
  Assert.AreEqual(Double(0), Stats.HitRate, 0.001);
end;

procedure TTestCacheStats.Test_HitRate_AllHits_ReturnsOne;
var
  Stats: TCacheStats;
begin
  Stats.Reset;
  Stats.Hits := 100;
  Stats.Misses := 0;
  Assert.AreEqual(Double(1), Stats.HitRate, 0.001);
end;

procedure TTestCacheStats.Test_HitRate_HalfHits_ReturnsHalf;
var
  Stats: TCacheStats;
begin
  Stats.Reset;
  Stats.Hits := 50;
  Stats.Misses := 50;
  Assert.AreEqual(Double(0.5), Stats.HitRate, 0.001);
end;

procedure TTestCacheStats.Test_MissRate_ComplementOfHitRate;
var
  Stats: TCacheStats;
begin
  Stats.Reset;
  Stats.Hits := 75;
  Stats.Misses := 25;
  Assert.AreEqual(Double(0.25), Stats.MissRate, 0.001);
end;

procedure TTestCacheStats.Test_Reset_ClearsAllCounters;
var
  Stats: TCacheStats;
begin
  Stats.Hits := 100;
  Stats.Misses := 50;
  Stats.Evictions := 10;
  Stats.Expirations := 5;
  
  Stats.Reset;
  
  Assert.AreEqual(Int64(0), Stats.Hits);
  Assert.AreEqual(Int64(0), Stats.Misses);
  Assert.AreEqual(Int64(0), Stats.Evictions);
  Assert.AreEqual(Int64(0), Stats.Expirations);
end;

procedure TTestCacheStats.Test_ToString_FormatsCorrectly;
var
  Stats: TCacheStats;
  S: string;
begin
  Stats.Reset;
  Stats.CurrentItems := 10;
  Stats.Hits := 100;
  Stats.Misses := 25;
  
  S := Stats.ToString;
  
  Assert.IsTrue(S.Contains('100'), 'Should contain hits');
  Assert.IsTrue(S.Contains('25'), 'Should contain misses');
  Assert.IsTrue(S.Contains('10'), 'Should contain item count');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseCache);
  TDUnitX.RegisterTestFixture(TTestMemoryCache);
  TDUnitX.RegisterTestFixture(TTestCacheStats);

end.
