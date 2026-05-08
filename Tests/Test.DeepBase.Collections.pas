/// <summary>
/// Unit tests for DeepBase.Collections module
/// Tests: TSortedList, TCircularBuffer, TLRUCache, TBidiDictionary,
///        TMultiMap, TOrderedDictionary, TDeque, TCountingSet
/// </summary>
unit Test.DeepBase.Collections;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Collections;

type
  /// <summary>
  /// Tests for TSortedList
  /// </summary>
  [TestFixture]
  TSortedListTests = class
  private
    FList: TSortedList<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Add_SortsAutomatically;
    [Test]
    procedure Test_Add_MultipleItems;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_IndexOf;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_Delete;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_IsEmpty;
    [Test]
    procedure Test_First;
    [Test]
    procedure Test_Last;
    [Test]
    procedure Test_ToArray;
    [Test]
    procedure Test_GetRange;
    [Test]
    procedure Test_Duplicates_Ignore;
    [Test]
    procedure Test_Duplicates_Accept;
  end;

  /// <summary>
  /// Tests for TCircularBuffer
  /// </summary>
  [TestFixture]
  TCircularBufferTests = class
  private
    FBuffer: TCircularBuffer<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Push;
    [Test]
    procedure Test_Pop;
    [Test]
    procedure Test_TryPop_Success;
    [Test]
    procedure Test_TryPop_Empty;
    [Test]
    procedure Test_Peek;
    [Test]
    procedure Test_IsFull;
    [Test]
    procedure Test_IsEmpty;
    [Test]
    procedure Test_Wrap_Around;
    [Test]
    procedure Test_Overwrite_Oldest;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_ToArray;
    [Test]
    procedure Test_Count;
  end;

  /// <summary>
  /// Tests for TLRUCache
  /// </summary>
  [TestFixture]
  TLRUCacheTests = class
  private
    FCache: TLRUCache<string, Integer>;
    FEvictedKey: string;
    FEvictedValue: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Put_Get;
    [Test]
    procedure Test_TryGet_Found;
    [Test]
    procedure Test_TryGet_NotFound;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_IsFull;
    [Test]
    procedure Test_Eviction_LRU;
    [Test]
    procedure Test_OnEvict_Called;
    [Test]
    procedure Test_Get_UpdatesRecency;
    [Test]
    procedure Test_Keys;
  end;

  /// <summary>
  /// Tests for TBidiDictionary
  /// </summary>
  [TestFixture]
  TBidiDictionaryTests = class
  private
    FDict: TBidiDictionary<string, Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Add;
    [Test]
    procedure Test_GetValue;
    [Test]
    procedure Test_GetKey;
    [Test]
    procedure Test_TryGetValue;
    [Test]
    procedure Test_TryGetKey;
    [Test]
    procedure Test_ContainsKey;
    [Test]
    procedure Test_ContainsValue;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_RemoveValue;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_Keys;
    [Test]
    procedure Test_Values;
  end;

  /// <summary>
  /// Tests for TMultiMap
  /// </summary>
  [TestFixture]
  TMultiMapTests = class
  private
    FMap: TMultiMap<string, Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Add;
    [Test]
    procedure Test_AddRange;
    [Test]
    procedure Test_GetValues;
    [Test]
    procedure Test_TryGetValues;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_ContainsKey;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_RemoveKey;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_KeyCount;
    [Test]
    procedure Test_ValueCount;
    [Test]
    procedure Test_ValueCountFor;
    [Test]
    procedure Test_Keys;
    [Test]
    procedure Test_AllValues;
  end;

  /// <summary>
  /// Tests for TOrderedDictionary
  /// </summary>
  [TestFixture]
  TOrderedDictionaryTests = class
  private
    FDict: TOrderedDictionary<string, Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Add;
    [Test]
    procedure Test_PreservesOrder;
    [Test]
    procedure Test_GetItem;
    [Test]
    procedure Test_SetItem;
    [Test]
    procedure Test_TryGetValue;
    [Test]
    procedure Test_ContainsKey;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_GetKeyAt;
    [Test]
    procedure Test_GetValueAt;
  end;

  /// <summary>
  /// Tests for TDeque
  /// </summary>
  [TestFixture]
  TDequeTests = class
  private
    FDeque: TDeque<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_PushFront;
    [Test]
    procedure Test_PushBack;
    [Test]
    procedure Test_PopFront;
    [Test]
    procedure Test_PopBack;
    [Test]
    procedure Test_PeekFront;
    [Test]
    procedure Test_PeekBack;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_IsEmpty;
    [Test]
    procedure Test_ToArray;
  end;

  /// <summary>
  /// Tests for TCountingSet
  /// </summary>
  [TestFixture]
  TCountingSetTests = class
  private
    FSet: TCountingSet<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Add;
    [Test]
    procedure Test_Add_Multiple;
    [Test]
    procedure Test_Remove;
    [Test]
    procedure Test_GetCount;
    [Test]
    procedure Test_Contains;
    [Test]
    procedure Test_Clear;
    [Test]
    procedure Test_MostCommon;
    [Test]
    procedure Test_TotalCount;
  end;

  /// <summary>
  /// Tests for TBlockingQueue
  /// </summary>
  [TestFixture]
  TBlockingQueueTests = class
  private
    FQueue: TBlockingQueue<Integer>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Create;
    [Test]
    procedure Test_Enqueue;
    [Test]
    procedure Test_Dequeue;
    [Test]
    procedure Test_TryDequeue_Success;
    [Test]
    procedure Test_TryDequeue_Timeout;
    [Test]
    procedure Test_Count;
    [Test]
    procedure Test_Clear;
  end;

implementation

// ============================================================================
// TSortedListTests
// ============================================================================

procedure TSortedListTests.Setup;
begin
  FList := TSortedList<Integer>.Create;
end;

procedure TSortedListTests.TearDown;
begin
  FList.Free;
end;

procedure TSortedListTests.Test_Create;
begin
  Assert.IsNotNull(FList);
  Assert.AreEqual(0, Integer(FList.Count));
end;

procedure TSortedListTests.Test_Add_SortsAutomatically;
begin
  FList.Add(5);
  FList.Add(2);
  FList.Add(8);
  FList.Add(1);
  
  Assert.AreEqual(1, FList[0]);
  Assert.AreEqual(2, FList[1]);
  Assert.AreEqual(5, FList[2]);
  Assert.AreEqual(8, FList[3]);
end;

procedure TSortedListTests.Test_Add_MultipleItems;
begin
  FList.Add(10);
  FList.Add(20);
  FList.Add(30);
  Assert.AreEqual(3, Integer(FList.Count));
end;

procedure TSortedListTests.Test_Contains;
begin
  FList.Add(5);
  FList.Add(10);
  Assert.IsTrue(FList.Contains(5));
  Assert.IsTrue(FList.Contains(10));
  Assert.IsFalse(FList.Contains(7));
end;

procedure TSortedListTests.Test_IndexOf;
begin
  FList.Add(5);
  FList.Add(10);
  FList.Add(15);
  Assert.AreEqual(0, FList.IndexOf(5));
  Assert.AreEqual(1, FList.IndexOf(10));
  Assert.AreEqual(2, FList.IndexOf(15));
  Assert.AreEqual(-1, FList.IndexOf(100));
end;

procedure TSortedListTests.Test_Remove;
begin
  FList.Add(5);
  FList.Add(10);
  Assert.IsTrue(FList.Remove(5));
  Assert.AreEqual(1, Integer(FList.Count));
  Assert.IsFalse(FList.Contains(5));
end;

procedure TSortedListTests.Test_Delete;
begin
  FList.Add(5);
  FList.Add(10);
  FList.Add(15);
  FList.Delete(1);
  Assert.AreEqual(2, Integer(FList.Count));
  Assert.AreEqual(5, FList[0]);
  Assert.AreEqual(15, FList[1]);
end;

procedure TSortedListTests.Test_Clear;
begin
  FList.Add(1);
  FList.Add(2);
  FList.Clear;
  Assert.AreEqual(0, Integer(FList.Count));
end;

procedure TSortedListTests.Test_Count;
begin
  Assert.AreEqual(0, Integer(FList.Count));
  FList.Add(1);
  Assert.AreEqual(1, Integer(FList.Count));
  FList.Add(2);
  Assert.AreEqual(2, Integer(FList.Count));
end;

procedure TSortedListTests.Test_IsEmpty;
begin
  Assert.IsTrue(FList.IsEmpty);
  FList.Add(1);
  Assert.IsFalse(FList.IsEmpty);
end;

procedure TSortedListTests.Test_First;
begin
  FList.Add(10);
  FList.Add(5);
  FList.Add(15);
  Assert.AreEqual(5, FList.First);
end;

procedure TSortedListTests.Test_Last;
begin
  FList.Add(10);
  FList.Add(5);
  FList.Add(15);
  Assert.AreEqual(15, FList.Last);
end;

procedure TSortedListTests.Test_ToArray;
var
  Arr: TArray<Integer>;
begin
  FList.Add(3);
  FList.Add(1);
  FList.Add(2);
  Arr := FList.ToArray;
  Assert.AreEqual(3, Integer(Length(Arr)));
  Assert.AreEqual(1, Arr[0]);
  Assert.AreEqual(2, Arr[1]);
  Assert.AreEqual(3, Arr[2]);
end;

procedure TSortedListTests.Test_GetRange;
var
  Arr: TArray<Integer>;
begin
  FList.Add(1);
  FList.Add(2);
  FList.Add(3);
  FList.Add(4);
  FList.Add(5);
  Arr := FList.GetRange(1, 3);
  Assert.AreEqual(3, Integer(Length(Arr)));
  Assert.AreEqual(2, Arr[0]);
  Assert.AreEqual(3, Arr[1]);
  Assert.AreEqual(4, Arr[2]);
end;

procedure TSortedListTests.Test_Duplicates_Ignore;
begin
  FList.Duplicates := dupIgnore;
  FList.Add(5);
  FList.Add(5);
  Assert.AreEqual(1, Integer(FList.Count));
end;

procedure TSortedListTests.Test_Duplicates_Accept;
begin
  FList.Duplicates := dupAccept;
  FList.Add(5);
  FList.Add(5);
  Assert.AreEqual(2, Integer(FList.Count));
end;

// ============================================================================
// TCircularBufferTests
// ============================================================================

procedure TCircularBufferTests.Setup;
begin
  FBuffer := TCircularBuffer<Integer>.Create(5);
end;

procedure TCircularBufferTests.TearDown;
begin
  FBuffer.Free;
end;

procedure TCircularBufferTests.Test_Create;
begin
  Assert.IsNotNull(FBuffer);
  Assert.AreEqual(5, FBuffer.Capacity);
  Assert.AreEqual(0, Integer(FBuffer.Count));
end;

procedure TCircularBufferTests.Test_Push;
begin
  FBuffer.Push(10);
  Assert.AreEqual(1, Integer(FBuffer.Count));
end;

procedure TCircularBufferTests.Test_Pop;
begin
  FBuffer.Push(10);
  FBuffer.Push(20);
  Assert.AreEqual(10, FBuffer.Pop);
  Assert.AreEqual(20, FBuffer.Pop);
end;

procedure TCircularBufferTests.Test_TryPop_Success;
var
  Value: Integer;
begin
  FBuffer.Push(10);
  Assert.IsTrue(FBuffer.TryPop(Value));
  Assert.AreEqual(10, Value);
end;

procedure TCircularBufferTests.Test_TryPop_Empty;
var
  Value: Integer;
begin
  Assert.IsFalse(FBuffer.TryPop(Value));
end;

procedure TCircularBufferTests.Test_Peek;
begin
  FBuffer.Push(10);
  FBuffer.Push(20);
  Assert.AreEqual(10, FBuffer.Peek);
  Assert.AreEqual(2, Integer(FBuffer.Count)); // Peek doesn't remove
end;

procedure TCircularBufferTests.Test_IsFull;
begin
  Assert.IsFalse(FBuffer.IsFull);
  for var I := 1 to 5 do
    FBuffer.Push(I);
  Assert.IsTrue(FBuffer.IsFull);
end;

procedure TCircularBufferTests.Test_IsEmpty;
begin
  Assert.IsTrue(FBuffer.IsEmpty);
  FBuffer.Push(1);
  Assert.IsFalse(FBuffer.IsEmpty);
end;

procedure TCircularBufferTests.Test_Wrap_Around;
begin
  // Fill buffer
  for var I := 1 to 5 do
    FBuffer.Push(I);
  
  // Pop some
  FBuffer.Pop;
  FBuffer.Pop;
  
  // Push more (should wrap)
  FBuffer.Push(6);
  FBuffer.Push(7);
  
  Assert.AreEqual(5, Integer(FBuffer.Count));
end;

procedure TCircularBufferTests.Test_Overwrite_Oldest;
begin
  for var I := 1 to 5 do
    FBuffer.Push(I);
  
  // Push one more, should overwrite oldest
  FBuffer.Push(6);
  
  Assert.AreEqual(5, Integer(FBuffer.Count));
  Assert.AreEqual(2, FBuffer.Peek); // 1 was overwritten
end;

procedure TCircularBufferTests.Test_Clear;
begin
  FBuffer.Push(1);
  FBuffer.Push(2);
  FBuffer.Clear;
  Assert.AreEqual(0, Integer(FBuffer.Count));
  Assert.IsTrue(FBuffer.IsEmpty);
end;

procedure TCircularBufferTests.Test_ToArray;
var
  Arr: TArray<Integer>;
begin
  FBuffer.Push(1);
  FBuffer.Push(2);
  FBuffer.Push(3);
  Arr := FBuffer.ToArray;
  Assert.AreEqual(3, Integer(Length(Arr)));
end;

procedure TCircularBufferTests.Test_Count;
begin
  Assert.AreEqual(0, Integer(FBuffer.Count));
  FBuffer.Push(1);
  Assert.AreEqual(1, Integer(FBuffer.Count));
  FBuffer.Push(2);
  Assert.AreEqual(2, Integer(FBuffer.Count));
  FBuffer.Pop;
  Assert.AreEqual(1, Integer(FBuffer.Count));
end;

// ============================================================================
// TLRUCacheTests
// ============================================================================

procedure TLRUCacheTests.Setup;
begin
  FCache := TLRUCache<string, Integer>.Create(3);
  FEvictedKey := '';
  FEvictedValue := 0;
end;

procedure TLRUCacheTests.TearDown;
begin
  FCache.Free;
end;

procedure TLRUCacheTests.Test_Create;
begin
  Assert.IsNotNull(FCache);
  Assert.AreEqual(3, FCache.Capacity);
end;

procedure TLRUCacheTests.Test_Put_Get;
begin
  FCache.Put('a', 1);
  Assert.AreEqual(1, FCache.Get('a'));
end;

procedure TLRUCacheTests.Test_TryGet_Found;
var
  Value: Integer;
begin
  FCache.Put('key', 42);
  Assert.IsTrue(FCache.TryGet('key', Value));
  Assert.AreEqual(42, Value);
end;

procedure TLRUCacheTests.Test_TryGet_NotFound;
var
  Value: Integer;
begin
  Assert.IsFalse(FCache.TryGet('nonexistent', Value));
end;

procedure TLRUCacheTests.Test_Contains;
begin
  FCache.Put('key', 1);
  Assert.IsTrue(FCache.Contains('key'));
  Assert.IsFalse(FCache.Contains('other'));
end;

procedure TLRUCacheTests.Test_Remove;
begin
  FCache.Put('key', 1);
  FCache.Remove('key');
  Assert.IsFalse(FCache.Contains('key'));
end;

procedure TLRUCacheTests.Test_Clear;
begin
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  FCache.Clear;
  Assert.AreEqual(0, Integer(FCache.Count));
end;

procedure TLRUCacheTests.Test_Count;
begin
  Assert.AreEqual(0, Integer(FCache.Count));
  FCache.Put('a', 1);
  Assert.AreEqual(1, Integer(FCache.Count));
  FCache.Put('b', 2);
  Assert.AreEqual(2, Integer(FCache.Count));
end;

procedure TLRUCacheTests.Test_IsFull;
begin
  Assert.IsFalse(FCache.IsFull);
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  FCache.Put('c', 3);
  Assert.IsTrue(FCache.IsFull);
end;

procedure TLRUCacheTests.Test_Eviction_LRU;
begin
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  FCache.Put('c', 3);
  
  // Access 'a' to make it recent
  FCache.Get('a');
  
  // Add 'd', should evict 'b' (least recently used)
  FCache.Put('d', 4);
  
  Assert.IsFalse(FCache.Contains('b'));
  Assert.IsTrue(FCache.Contains('a'));
  Assert.IsTrue(FCache.Contains('c'));
  Assert.IsTrue(FCache.Contains('d'));
end;

procedure TLRUCacheTests.Test_OnEvict_Called;
begin
  FCache.OnEvict := procedure(K: string; V: Integer)
    begin
      FEvictedKey := K;
      FEvictedValue := V;
    end;
  
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  FCache.Put('c', 3);
  FCache.Put('d', 4); // Evicts 'a'
  
  Assert.AreEqual('a', FEvictedKey);
  Assert.AreEqual(1, FEvictedValue);
end;

procedure TLRUCacheTests.Test_Get_UpdatesRecency;
begin
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  FCache.Put('c', 3);
  
  // Get 'a' makes it most recent
  FCache.Get('a');
  
  // Add two more, should evict 'b' then 'c'
  FCache.Put('d', 4);
  Assert.IsFalse(FCache.Contains('b'));
  
  FCache.Put('e', 5);
  Assert.IsFalse(FCache.Contains('c'));
  
  Assert.IsTrue(FCache.Contains('a')); // 'a' still there
end;

procedure TLRUCacheTests.Test_Keys;
var
  K: TArray<string>;
begin
  FCache.Put('a', 1);
  FCache.Put('b', 2);
  K := FCache.Keys;
  Assert.AreEqual(2, Integer(Length(K)));
end;

// ============================================================================
// TBidiDictionaryTests
// ============================================================================

procedure TBidiDictionaryTests.Setup;
begin
  FDict := TBidiDictionary<string, Integer>.Create;
end;

procedure TBidiDictionaryTests.TearDown;
begin
  FDict.Free;
end;

procedure TBidiDictionaryTests.Test_Create;
begin
  Assert.IsNotNull(FDict);
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_Add;
begin
  FDict.Add('one', 1);
  Assert.AreEqual(1, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_GetValue;
begin
  FDict.Add('two', 2);
  Assert.AreEqual(2, FDict.GetValue('two'));
end;

procedure TBidiDictionaryTests.Test_GetKey;
begin
  FDict.Add('three', 3);
  Assert.AreEqual('three', FDict.GetKey(3));
end;

procedure TBidiDictionaryTests.Test_TryGetValue;
var
  V: Integer;
begin
  FDict.Add('test', 42);
  Assert.IsTrue(FDict.TryGetValue('test', V));
  Assert.AreEqual(42, V);
  Assert.IsFalse(FDict.TryGetValue('missing', V));
end;

procedure TBidiDictionaryTests.Test_TryGetKey;
var
  K: string;
begin
  FDict.Add('test', 42);
  Assert.IsTrue(FDict.TryGetKey(42, K));
  Assert.AreEqual('test', K);
  Assert.IsFalse(FDict.TryGetKey(999, K));
end;

procedure TBidiDictionaryTests.Test_ContainsKey;
begin
  FDict.Add('key', 1);
  Assert.IsTrue(FDict.ContainsKey('key'));
  Assert.IsFalse(FDict.ContainsKey('other'));
end;

procedure TBidiDictionaryTests.Test_ContainsValue;
begin
  FDict.Add('key', 100);
  Assert.IsTrue(FDict.ContainsValue(100));
  Assert.IsFalse(FDict.ContainsValue(200));
end;

procedure TBidiDictionaryTests.Test_Remove;
begin
  FDict.Add('key', 1);
  FDict.Remove('key');
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_RemoveValue;
begin
  FDict.Add('key', 1);
  FDict.RemoveValue(1);
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_Clear;
begin
  FDict.Add('a', 1);
  FDict.Add('b', 2);
  FDict.Clear;
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_Count;
begin
  FDict.Add('a', 1);
  FDict.Add('b', 2);
  Assert.AreEqual(2, Integer(FDict.Count));
end;

procedure TBidiDictionaryTests.Test_Keys;
var
  K: TArray<string>;
begin
  FDict.Add('x', 1);
  FDict.Add('y', 2);
  K := FDict.Keys;
  Assert.AreEqual(2, Integer(Length(K)));
end;

procedure TBidiDictionaryTests.Test_Values;
var
  V: TArray<Integer>;
begin
  FDict.Add('x', 1);
  FDict.Add('y', 2);
  V := FDict.Values;
  Assert.AreEqual(2, Integer(Length(V)));
end;

// ============================================================================
// TMultiMapTests
// ============================================================================

procedure TMultiMapTests.Setup;
begin
  FMap := TMultiMap<string, Integer>.Create;
end;

procedure TMultiMapTests.TearDown;
begin
  FMap.Free;
end;

procedure TMultiMapTests.Test_Create;
begin
  Assert.IsNotNull(FMap);
end;

procedure TMultiMapTests.Test_Add;
begin
  FMap.Add('key', 1);
  FMap.Add('key', 2);
  Assert.AreEqual(2, FMap.ValueCountFor('key'));
end;

procedure TMultiMapTests.Test_AddRange;
begin
  FMap.AddRange('key', [1, 2, 3]);
  Assert.AreEqual(3, FMap.ValueCountFor('key'));
end;

procedure TMultiMapTests.Test_GetValues;
var
  V: TArray<Integer>;
begin
  FMap.Add('key', 10);
  FMap.Add('key', 20);
  V := FMap.GetValues('key');
  Assert.AreEqual(2, Integer(Length(V)));
end;

procedure TMultiMapTests.Test_TryGetValues;
var
  V: TArray<Integer>;
begin
  FMap.Add('key', 1);
  Assert.IsTrue(FMap.TryGetValues('key', V));
  Assert.IsFalse(FMap.TryGetValues('missing', V));
end;

procedure TMultiMapTests.Test_Contains;
begin
  FMap.Add('key', 1);
  FMap.Add('key', 2);
  Assert.IsTrue(FMap.Contains('key', 1));
  Assert.IsTrue(FMap.Contains('key', 2));
  Assert.IsFalse(FMap.Contains('key', 3));
end;

procedure TMultiMapTests.Test_ContainsKey;
begin
  FMap.Add('key', 1);
  Assert.IsTrue(FMap.ContainsKey('key'));
  Assert.IsFalse(FMap.ContainsKey('other'));
end;

procedure TMultiMapTests.Test_Remove;
begin
  FMap.Add('key', 1);
  FMap.Add('key', 2);
  FMap.Remove('key', 1);
  Assert.AreEqual(1, FMap.ValueCountFor('key'));
  Assert.IsFalse(FMap.Contains('key', 1));
end;

procedure TMultiMapTests.Test_RemoveKey;
begin
  FMap.Add('key', 1);
  FMap.Add('key', 2);
  FMap.RemoveKey('key');
  Assert.IsFalse(FMap.ContainsKey('key'));
end;

procedure TMultiMapTests.Test_Clear;
begin
  FMap.Add('a', 1);
  FMap.Add('b', 2);
  FMap.Clear;
  Assert.AreEqual(0, FMap.KeyCount);
end;

procedure TMultiMapTests.Test_KeyCount;
begin
  FMap.Add('a', 1);
  FMap.Add('b', 2);
  FMap.Add('a', 3);
  Assert.AreEqual(2, FMap.KeyCount);
end;

procedure TMultiMapTests.Test_ValueCount;
begin
  FMap.Add('a', 1);
  FMap.Add('a', 2);
  FMap.Add('b', 3);
  Assert.AreEqual(3, FMap.ValueCount);
end;

procedure TMultiMapTests.Test_ValueCountFor;
begin
  FMap.Add('key', 1);
  FMap.Add('key', 2);
  FMap.Add('key', 3);
  Assert.AreEqual(3, FMap.ValueCountFor('key'));
  Assert.AreEqual(0, FMap.ValueCountFor('missing'));
end;

procedure TMultiMapTests.Test_Keys;
var
  K: TArray<string>;
begin
  FMap.Add('x', 1);
  FMap.Add('y', 2);
  K := FMap.Keys;
  Assert.AreEqual(2, Integer(Length(K)));
end;

procedure TMultiMapTests.Test_AllValues;
var
  V: TArray<Integer>;
begin
  FMap.Add('a', 1);
  FMap.Add('a', 2);
  FMap.Add('b', 3);
  V := FMap.AllValues;
  Assert.AreEqual(3, Integer(Length(V)));
end;

// ============================================================================
// TOrderedDictionaryTests
// ============================================================================

procedure TOrderedDictionaryTests.Setup;
begin
  FDict := TOrderedDictionary<string, Integer>.Create;
end;

procedure TOrderedDictionaryTests.TearDown;
begin
  FDict.Free;
end;

procedure TOrderedDictionaryTests.Test_Create;
begin
  Assert.IsNotNull(FDict);
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TOrderedDictionaryTests.Test_Add;
begin
  FDict.Add('key', 1);
  Assert.AreEqual(1, Integer(FDict.Count));
end;

procedure TOrderedDictionaryTests.Test_PreservesOrder;
begin
  FDict.Add('c', 3);
  FDict.Add('a', 1);
  FDict.Add('b', 2);
  
  // Should preserve insertion order
  Assert.AreEqual('c', FDict.ItemsByIndex[0].Key);
  Assert.AreEqual('a', FDict.ItemsByIndex[1].Key);
  Assert.AreEqual('b', FDict.ItemsByIndex[2].Key);
end;

procedure TOrderedDictionaryTests.Test_GetItem;
begin
  FDict.Add('key', 42);
  Assert.AreEqual(42, FDict['key']);
end;

procedure TOrderedDictionaryTests.Test_SetItem;
begin
  FDict.Add('key', 1);
  FDict['key'] := 100;
  Assert.AreEqual(100, FDict['key']);
end;

procedure TOrderedDictionaryTests.Test_TryGetValue;
var
  V: Integer;
begin
  FDict.Add('key', 1);
  Assert.IsTrue(FDict.TryGetValue('key', V));
  Assert.IsFalse(FDict.TryGetValue('missing', V));
end;

procedure TOrderedDictionaryTests.Test_ContainsKey;
begin
  FDict.Add('key', 1);
  Assert.IsTrue(FDict.ContainsKey('key'));
  Assert.IsFalse(FDict.ContainsKey('other'));
end;

procedure TOrderedDictionaryTests.Test_Remove;
begin
  FDict.Add('key', 1);
  FDict.Remove('key');
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TOrderedDictionaryTests.Test_Clear;
begin
  FDict.Add('a', 1);
  FDict.Add('b', 2);
  FDict.Clear;
  Assert.AreEqual(0, Integer(FDict.Count));
end;

procedure TOrderedDictionaryTests.Test_Count;
begin
  FDict.Add('a', 1);
  FDict.Add('b', 2);
  Assert.AreEqual(2, Integer(FDict.Count));
end;

procedure TOrderedDictionaryTests.Test_GetKeyAt;
begin
  FDict.Add('first', 1);
  FDict.Add('second', 2);
  Assert.AreEqual('first', FDict.ItemsByIndex[0].Key);
  Assert.AreEqual('second', FDict.ItemsByIndex[1].Key);
end;

procedure TOrderedDictionaryTests.Test_GetValueAt;
begin
  FDict.Add('first', 100);
  FDict.Add('second', 200);
  Assert.AreEqual(100, FDict.ItemsByIndex[0].Value);
  Assert.AreEqual(200, FDict.ItemsByIndex[1].Value);
end;

// ============================================================================
// TDequeTests
// ============================================================================

procedure TDequeTests.Setup;
begin
  FDeque := TDeque<Integer>.Create;
end;

procedure TDequeTests.TearDown;
begin
  FDeque.Free;
end;

procedure TDequeTests.Test_Create;
begin
  Assert.IsNotNull(FDeque);
  Assert.AreEqual(0, Integer(FDeque.Count));
end;

procedure TDequeTests.Test_PushFront;
begin
  FDeque.PushFront(1);
  FDeque.PushFront(2);
  Assert.AreEqual(2, FDeque.PeekFront);
end;

procedure TDequeTests.Test_PushBack;
begin
  FDeque.PushBack(1);
  FDeque.PushBack(2);
  Assert.AreEqual(2, FDeque.PeekBack);
end;

procedure TDequeTests.Test_PopFront;
begin
  FDeque.PushBack(1);
  FDeque.PushBack(2);
  FDeque.PushBack(3);
  Assert.AreEqual(1, FDeque.PopFront);
  Assert.AreEqual(2, FDeque.PopFront);
end;

procedure TDequeTests.Test_PopBack;
begin
  FDeque.PushBack(1);
  FDeque.PushBack(2);
  FDeque.PushBack(3);
  Assert.AreEqual(3, FDeque.PopBack);
  Assert.AreEqual(2, FDeque.PopBack);
end;

procedure TDequeTests.Test_PeekFront;
begin
  FDeque.PushBack(10);
  FDeque.PushBack(20);
  Assert.AreEqual(10, FDeque.PeekFront);
  Assert.AreEqual(2, Integer(FDeque.Count)); // Peek doesn't remove
end;

procedure TDequeTests.Test_PeekBack;
begin
  FDeque.PushBack(10);
  FDeque.PushBack(20);
  Assert.AreEqual(20, FDeque.PeekBack);
  Assert.AreEqual(2, Integer(FDeque.Count));
end;

procedure TDequeTests.Test_Clear;
begin
  FDeque.PushBack(1);
  FDeque.PushBack(2);
  FDeque.Clear;
  Assert.AreEqual(0, Integer(FDeque.Count));
end;

procedure TDequeTests.Test_Count;
begin
  Assert.AreEqual(0, Integer(FDeque.Count));
  FDeque.PushBack(1);
  Assert.AreEqual(1, Integer(FDeque.Count));
  FDeque.PushFront(2);
  Assert.AreEqual(2, Integer(FDeque.Count));
end;

procedure TDequeTests.Test_IsEmpty;
begin
  Assert.IsTrue(FDeque.IsEmpty);
  FDeque.PushBack(1);
  Assert.IsFalse(FDeque.IsEmpty);
end;

procedure TDequeTests.Test_ToArray;
var
  Arr: TArray<Integer>;
begin
  FDeque.PushBack(1);
  FDeque.PushBack(2);
  FDeque.PushBack(3);
  Arr := FDeque.ToArray;
  Assert.AreEqual(3, Integer(Length(Arr)));
  Assert.AreEqual(1, Arr[0]);
  Assert.AreEqual(3, Arr[2]);
end;

// ============================================================================
// TCountingSetTests
// ============================================================================

procedure TCountingSetTests.Setup;
begin
  FSet := TCountingSet<string>.Create;
end;

procedure TCountingSetTests.TearDown;
begin
  FSet.Free;
end;

procedure TCountingSetTests.Test_Create;
begin
  Assert.IsNotNull(FSet);
end;

procedure TCountingSetTests.Test_Add;
begin
  FSet.Add('apple');
  Assert.IsTrue(FSet.Contains('apple'));
end;

procedure TCountingSetTests.Test_Add_Multiple;
begin
  FSet.Add('apple');
  FSet.Add('apple');
  FSet.Add('apple');
  Assert.AreEqual(3, FSet.CountOf('apple'));
end;

procedure TCountingSetTests.Test_Remove;
begin
  FSet.Add('apple');
  FSet.Add('apple');
  FSet.Remove('apple');
  Assert.AreEqual(1, FSet.CountOf('apple'));
  FSet.Remove('apple');
  Assert.IsFalse(FSet.Contains('apple'));
end;

procedure TCountingSetTests.Test_GetCount;
begin
  FSet.Add('a');
  FSet.Add('a');
  FSet.Add('b');
  Assert.AreEqual(2, FSet.CountOf('a'));
  Assert.AreEqual(1, FSet.CountOf('b'));
  Assert.AreEqual(0, FSet.CountOf('c'));
end;

procedure TCountingSetTests.Test_Contains;
begin
  FSet.Add('x');
  Assert.IsTrue(FSet.Contains('x'));
  Assert.IsFalse(FSet.Contains('y'));
end;

procedure TCountingSetTests.Test_Clear;
begin
  FSet.Add('a');
  FSet.Add('b');
  FSet.Clear;
  Assert.IsFalse(FSet.Contains('a'));
  Assert.IsFalse(FSet.Contains('b'));
end;

procedure TCountingSetTests.Test_MostCommon;
var
  Items: TArray<TPair<string, Integer>>;
begin
  FSet.Add('apple');
  FSet.Add('banana');
  FSet.Add('banana');
  FSet.Add('cherry');
  FSet.Add('cherry');
  FSet.Add('cherry');

  Items := FSet.MostCommon(2);
  Assert.AreEqual(2, Integer(Length(Items)));
  Assert.AreEqual('cherry', Items[0].Key);
  Assert.AreEqual('banana', Items[1].Key);
end;

procedure TCountingSetTests.Test_TotalCount;
begin
  FSet.Add('a');
  FSet.Add('a');
  FSet.Add('b');
  Assert.AreEqual(3, FSet.TotalCount);
end;

// ============================================================================
// TBlockingQueueTests
// ============================================================================

procedure TBlockingQueueTests.Setup;
begin
  FQueue := TBlockingQueue<Integer>.Create;
end;

procedure TBlockingQueueTests.TearDown;
begin
  FQueue.Free;
end;

procedure TBlockingQueueTests.Test_Create;
begin
  Assert.IsNotNull(FQueue);
  Assert.AreEqual(0, Integer(FQueue.Count));
end;

procedure TBlockingQueueTests.Test_Enqueue;
begin
  FQueue.Enqueue(10);
  Assert.AreEqual(1, Integer(FQueue.Count));
end;

procedure TBlockingQueueTests.Test_Dequeue;
begin
  FQueue.Enqueue(10);
  FQueue.Enqueue(20);
  Assert.AreEqual(10, FQueue.Dequeue);
  Assert.AreEqual(20, FQueue.Dequeue);
end;

procedure TBlockingQueueTests.Test_TryDequeue_Success;
var
  Value: Integer;
begin
  FQueue.Enqueue(42);
  Assert.IsTrue(FQueue.TryDequeue(Value, 100));
  Assert.AreEqual(42, Value);
end;

procedure TBlockingQueueTests.Test_TryDequeue_Timeout;
var
  Value: Integer;
begin
  Assert.IsFalse(FQueue.TryDequeue(Value, 50));
end;

procedure TBlockingQueueTests.Test_Count;
begin
  FQueue.Enqueue(1);
  FQueue.Enqueue(2);
  Assert.AreEqual(2, Integer(FQueue.Count));
  FQueue.Dequeue;
  Assert.AreEqual(1, Integer(FQueue.Count));
end;

procedure TBlockingQueueTests.Test_Clear;
begin
  FQueue.Enqueue(1);
  FQueue.Enqueue(2);
  FQueue.Clear;
  Assert.AreEqual(0, Integer(FQueue.Count));
end;

initialization
  TDUnitX.RegisterTestFixture(TSortedListTests);
  TDUnitX.RegisterTestFixture(TCircularBufferTests);
  TDUnitX.RegisterTestFixture(TLRUCacheTests);
  TDUnitX.RegisterTestFixture(TBidiDictionaryTests);
  TDUnitX.RegisterTestFixture(TMultiMapTests);
  TDUnitX.RegisterTestFixture(TOrderedDictionaryTests);
  TDUnitX.RegisterTestFixture(TDequeTests);
  TDUnitX.RegisterTestFixture(TCountingSetTests);
  TDUnitX.RegisterTestFixture(TBlockingQueueTests);

end.
