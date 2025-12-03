{ ============================================================================
  Test.UniBase.ObjectPool - Object Pool Unit Tests
  
  Version: 1.0
  Description: Unit tests for the generic object pooling system
  
  Test Coverage:
  - TObjectPool<T>: Core pool functionality
  - TPooledObject<T>: Pooled object wrapper
  - TPoolConfig: Pool configuration
  - TPoolStats: Pool statistics
  - TKeyedObjectPool<K,T>: Keyed pools
  - TScopedPoolObject<T>: Scoped access
  - Factory interfaces
  ============================================================================ }

unit Test.UniBase.ObjectPool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading,
  DUnitX.TestFramework;

type
  /// <summary>Simple test class for pooling</summary>
  TPoolTestItem = class
  private
    FId: Integer;
    FData: string;
  public
    constructor Create;
    property Id: Integer read FId write FId;
    property Data: string read FData write FData;
  end;
  
  /// <summary>
  /// Test fixture for TPoolConfig
  /// </summary>
  [TestFixture]
  TTestPoolConfig = class
  public
    [Test]
    procedure Test_Default_ReturnsConfig;
    
    [Test]
    procedure Test_Default_HasReasonableValues;
  end;
  
  /// <summary>
  /// Test fixture for TPoolStats
  /// </summary>
  [TestFixture]
  TTestPoolStats = class
  public
    [Test]
    procedure Test_Reset_ClearsValues;
    
    [Test]
    procedure Test_DefaultValues;
  end;
  
  /// <summary>
  /// Test fixture for TPooledObject<T>
  /// </summary>
  [TestFixture]
  TTestPooledObject = class
  public
    [Test]
    procedure Test_Create_StoresObject;
    
    [Test]
    procedure Test_MarkUsed_UpdatesState;
    
    [Test]
    procedure Test_MarkReturned_UpdatesState;
    
    [Test]
    procedure Test_UseCount_Increments;
    
    [Test]
    procedure Test_LastUsedAt_Updates;
  end;
  
  /// <summary>
  /// Test fixture for TDefaultObjectFactory<T>
  /// </summary>
  [TestFixture]
  TTestDefaultObjectFactory = class
  public
    [Test]
    procedure Test_CreateObject_ReturnsInstance;
    
    [Test]
    procedure Test_DestroyObject_FreesInstance;
    
    [Test]
    procedure Test_ValidateObject_ReturnsTrue;
    
    [Test]
    procedure Test_ResetObject_DoesNotThrow;
  end;
  
  /// <summary>
  /// Test fixture for TCallbackObjectFactory<T>
  /// </summary>
  [TestFixture]
  TTestCallbackObjectFactory = class
  public
    [Test]
    procedure Test_Create_WithCallbacks;
    
    [Test]
    procedure Test_CreateObject_CallsFactory;
    
    [Test]
    procedure Test_DestroyObject_CallsCallback;
    
    [Test]
    procedure Test_ValidateObject_CallsCallback;
    
    [Test]
    procedure Test_ResetObject_CallsCallback;
  end;
  
  /// <summary>
  /// Test fixture for TObjectPool<T>
  /// </summary>
  [TestFixture]
  TTestAdvancedObjectPool = class
  public
    [Test]
    procedure Test_Create_WithFactory;
    
    [Test]
    procedure Test_Create_WithConfig;
    
    [Test]
    procedure Test_Acquire_ReturnsObject;
    
    [Test]
    procedure Test_Acquire_WithTimeout;
    
    [Test]
    procedure Test_TryAcquire_Success;
    
    [Test]
    procedure Test_TryAcquire_Failure;
    
    [Test]
    procedure Test_TryAcquire_WithTimeout;
    
    [Test]
    procedure Test_Release_ReturnsToPool;
    
    [Test]
    procedure Test_Clear_RemovesAllObjects;
    
    [Test]
    procedure Test_Shrink_ReducesToMinSize;
    
    [Test]
    procedure Test_Warm_PreallocatesObjects;
    
    [Test]
    procedure Test_GetStats_ReturnsStatistics;
    
    [Test]
    procedure Test_ResetStats_ClearsStatistics;
    
    [Test]
    procedure Test_CurrentSize_ReturnsTotal;
    
    [Test]
    procedure Test_IdleCount_ReturnsAvailable;
    
    [Test]
    procedure Test_InUseCount_ReturnsActive;
    
    [Test]
    procedure Test_OnObjectCreated_Event;
    
    [Test]
    procedure Test_OnObjectAcquired_Event;
    
    [Test]
    procedure Test_OnObjectReleased_Event;
    
    [Test]
    procedure Test_ConcurrentAccess_ThreadSafe;
  end;
  
  /// <summary>
  /// Test fixture for TKeyedObjectPool<K,T>
  /// </summary>
  [TestFixture]
  TTestKeyedObjectPool = class
  public
    [Test]
    procedure Test_Create_WithFactory;
    
    [Test]
    procedure Test_Acquire_ByKey;
    
    [Test]
    procedure Test_Release_ByKey;
    
    [Test]
    procedure Test_GetPool_ReturnsPoolForKey;
    
    [Test]
    procedure Test_ClearKey_ClearsSpecificPool;
    
    [Test]
    procedure Test_ClearAll_ClearsAllPools;
    
    [Test]
    procedure Test_MultipleKeys_SeparatePools;
  end;
  
  /// <summary>
  /// Test fixture for TScopedPoolObject<T>
  /// </summary>
  [TestFixture]
  TTestScopedPoolObject = class
  public
    [Test]
    procedure Test_Create_HoldsObject;
    
    [Test]
    procedure Test_Destroy_ReleasesToPool;
    
    [Test]
    procedure Test_GetObject_ReturnsObject;
  end;

implementation

uses
  UniBase.ObjectPool;

{ TPoolTestItem }

constructor TPoolTestItem.Create;
begin
  inherited;
  FId := Random(10000);
  FData := '';
end;

{ TTestPoolConfig }

procedure TTestPoolConfig.Test_Default_ReturnsConfig;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.MinSize >= 0);
end;

procedure TTestPoolConfig.Test_Default_HasReasonableValues;
var
  Config: TPoolConfig;
begin
  Config := TPoolConfig.Default;
  Assert.IsTrue(Config.MinSize >= 0);
  Assert.IsTrue(Config.MaxSize > Config.MinSize);
  Assert.IsTrue(Config.AcquireTimeoutMs > 0);
end;

{ TTestPoolStats }

procedure TTestPoolStats.Test_Reset_ClearsValues;
var
  Stats: TPoolStats;
begin
  Stats.TotalCreated := 100;
  Stats.TotalAcquires := 50;
  Stats.Reset;
  Assert.AreEqual(0, Stats.TotalCreated);
  Assert.AreEqual(Int64(0), Stats.TotalAcquires);
end;

procedure TTestPoolStats.Test_DefaultValues;
var
  Stats: TPoolStats;
begin
  Stats := Default(TPoolStats);
  Assert.AreEqual(0, Stats.TotalCreated);
  Assert.AreEqual(0, Stats.CurrentPoolSize);
end;

{ TTestPooledObject }

procedure TTestPooledObject.Test_Create_StoresObject;
var
  Item: TPoolTestItem;
  Pooled: TPooledObject<TPoolTestItem>;
begin
  Item := TPoolTestItem.Create;
  Pooled := TPooledObject<TPoolTestItem>.Create(Item);
  try
    Assert.AreSame(Item, Pooled.Obj);
  finally
    Pooled.Free;
  end;
end;

procedure TTestPooledObject.Test_MarkUsed_UpdatesState;
var
  Item: TPoolTestItem;
  Pooled: TPooledObject<TPoolTestItem>;
begin
  Item := TPoolTestItem.Create;
  Pooled := TPooledObject<TPoolTestItem>.Create(Item);
  try
    Assert.IsFalse(Pooled.InUse);
    Pooled.MarkUsed;
    Assert.IsTrue(Pooled.InUse);
  finally
    Pooled.Free;
  end;
end;

procedure TTestPooledObject.Test_MarkReturned_UpdatesState;
var
  Item: TPoolTestItem;
  Pooled: TPooledObject<TPoolTestItem>;
begin
  Item := TPoolTestItem.Create;
  Pooled := TPooledObject<TPoolTestItem>.Create(Item);
  try
    Pooled.MarkUsed;
    Pooled.MarkReturned;
    Assert.IsFalse(Pooled.InUse);
  finally
    Pooled.Free;
  end;
end;

procedure TTestPooledObject.Test_UseCount_Increments;
var
  Item: TPoolTestItem;
  Pooled: TPooledObject<TPoolTestItem>;
begin
  Item := TPoolTestItem.Create;
  Pooled := TPooledObject<TPoolTestItem>.Create(Item);
  try
    Assert.AreEqual(0, Pooled.UseCount);
    Pooled.MarkUsed;
    Assert.AreEqual(1, Pooled.UseCount);
    Pooled.MarkReturned;
    Pooled.MarkUsed;
    Assert.AreEqual(2, Pooled.UseCount);
  finally
    Pooled.Free;
  end;
end;

procedure TTestPooledObject.Test_LastUsedAt_Updates;
var
  Item: TPoolTestItem;
  Pooled: TPooledObject<TPoolTestItem>;
  BeforeUse: TDateTime;
begin
  Item := TPoolTestItem.Create;
  Pooled := TPooledObject<TPoolTestItem>.Create(Item);
  try
    BeforeUse := Now;
    Sleep(10);
    Pooled.MarkUsed;
    Assert.IsTrue(Pooled.LastUsedAt >= BeforeUse);
  finally
    Pooled.Free;
  end;
end;

{ TTestDefaultObjectFactory }

procedure TTestDefaultObjectFactory.Test_CreateObject_ReturnsInstance;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Item := Factory.CreateObject;
  try
    Assert.IsNotNull(Item);
  finally
    Factory.DestroyObject(Item);
  end;
end;

procedure TTestDefaultObjectFactory.Test_DestroyObject_FreesInstance;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Item := Factory.CreateObject;
  Factory.DestroyObject(Item);
  // No exception means success - object was freed
  Assert.Pass;
end;

procedure TTestDefaultObjectFactory.Test_ValidateObject_ReturnsTrue;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Item := Factory.CreateObject;
  try
    Assert.IsTrue(Factory.ValidateObject(Item));
  finally
    Factory.DestroyObject(Item);
  end;
end;

procedure TTestDefaultObjectFactory.Test_ResetObject_DoesNotThrow;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Item := Factory.CreateObject;
  try
    Factory.ResetObject(Item);
    Assert.Pass;
  finally
    Factory.DestroyObject(Item);
  end;
end;

{ TTestCallbackObjectFactory }

procedure TTestCallbackObjectFactory.Test_Create_WithCallbacks;
var
  Factory: IObjectFactory<TPoolTestItem>;
begin
  Factory := TCallbackObjectFactory<TPoolTestItem>.Create(
    function: TPoolTestItem begin Result := TPoolTestItem.Create; end);
  Assert.IsNotNull(Factory);
end;

procedure TTestCallbackObjectFactory.Test_CreateObject_CallsFactory;
var
  Factory: IObjectFactory<TPoolTestItem>;
  FactoryCalled: Boolean;
  Item: TPoolTestItem;
begin
  FactoryCalled := False;
  Factory := TCallbackObjectFactory<TPoolTestItem>.Create(
    function: TPoolTestItem 
    begin 
      FactoryCalled := True;
      Result := TPoolTestItem.Create; 
    end);
  
  Item := Factory.CreateObject;
  try
    Assert.IsTrue(FactoryCalled);
  finally
    Factory.DestroyObject(Item);
  end;
end;

procedure TTestCallbackObjectFactory.Test_DestroyObject_CallsCallback;
var
  Factory: IObjectFactory<TPoolTestItem>;
  DestroyCalled: Boolean;
  Item: TPoolTestItem;
begin
  DestroyCalled := False;
  Factory := TCallbackObjectFactory<TPoolTestItem>.Create(
    function: TPoolTestItem begin Result := TPoolTestItem.Create; end,
    procedure(O: TPoolTestItem) begin DestroyCalled := True; O.Free; end);
  
  Item := Factory.CreateObject;
  Factory.DestroyObject(Item);
  Assert.IsTrue(DestroyCalled);
end;

procedure TTestCallbackObjectFactory.Test_ValidateObject_CallsCallback;
var
  Factory: IObjectFactory<TPoolTestItem>;
  ValidateCalled: Boolean;
  Item: TPoolTestItem;
begin
  ValidateCalled := False;
  Factory := TCallbackObjectFactory<TPoolTestItem>.Create(
    function: TPoolTestItem begin Result := TPoolTestItem.Create; end,
    nil,
    function(O: TPoolTestItem): Boolean begin ValidateCalled := True; Result := True; end);
  
  Item := Factory.CreateObject;
  try
    Factory.ValidateObject(Item);
    Assert.IsTrue(ValidateCalled);
  finally
    Factory.DestroyObject(Item);
  end;
end;

procedure TTestCallbackObjectFactory.Test_ResetObject_CallsCallback;
var
  Factory: IObjectFactory<TPoolTestItem>;
  ResetCalled: Boolean;
  Item: TPoolTestItem;
begin
  ResetCalled := False;
  Factory := TCallbackObjectFactory<TPoolTestItem>.Create(
    function: TPoolTestItem begin Result := TPoolTestItem.Create; end,
    nil,
    nil,
    procedure(O: TPoolTestItem) begin ResetCalled := True; end);
  
  Item := Factory.CreateObject;
  try
    Factory.ResetObject(Item);
    Assert.IsTrue(ResetCalled);
  finally
    Factory.DestroyObject(Item);
  end;
end;

{ TTestAdvancedObjectPool }

procedure TTestAdvancedObjectPool.Test_Create_WithFactory;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Assert.IsNotNull(Pool);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Create_WithConfig;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Config: TPoolConfig;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Config := TPoolConfig.Default;
  Config.MinSize := 5;
  Config.MaxSize := 20;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory, Config);
  try
    Assert.AreEqual(5, Pool.Config.MinSize);
    Assert.AreEqual(20, Pool.Config.MaxSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Acquire_ReturnsObject;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    Assert.IsNotNull(Item);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Acquire_WithTimeout;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire(5000);
    Assert.IsNotNull(Item);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_TryAcquire_Success;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Assert.IsTrue(Pool.TryAcquire(Item));
    Assert.IsNotNull(Item);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_TryAcquire_Failure;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Config: TPoolConfig;
  Item1, Item2: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Config := TPoolConfig.Default;
  Config.MinSize := 1;
  Config.MaxSize := 1;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory, Config);
  try
    Item1 := Pool.Acquire;
    Assert.IsFalse(Pool.TryAcquire(Item2));
    Pool.Release(Item1);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_TryAcquire_WithTimeout;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Assert.IsTrue(Pool.TryAcquire(Item, 1000));
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Release_ReturnsToPool;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
  IdleBefore, IdleAfter: Integer;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    IdleBefore := Pool.IdleCount;
    Pool.Release(Item);
    IdleAfter := Pool.IdleCount;
    Assert.AreEqual(IdleBefore + 1, IdleAfter);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Clear_RemovesAllObjects;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Pool.Warm(10);
    Assert.IsTrue(Pool.CurrentSize > 0);
    Pool.Clear;
    Assert.AreEqual(0, Pool.CurrentSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Shrink_ReducesToMinSize;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Config: TPoolConfig;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Config := TPoolConfig.Default;
  Config.MinSize := 2;
  Config.MaxSize := 50;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory, Config);
  try
    Pool.Warm(20);
    Assert.IsTrue(Pool.IdleCount >= 20);
    Pool.Shrink;
    Assert.IsTrue(Pool.IdleCount <= Config.MinSize + 5);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_Warm_PreallocatesObjects;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Assert.AreEqual(0, Pool.CurrentSize);
    Pool.Warm(10);
    Assert.AreEqual(10, Pool.CurrentSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_GetStats_ReturnsStatistics;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Stats: TPoolStats;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    Pool.Release(Item);
    Stats := Pool.GetStats;
    Assert.IsTrue(Stats.TotalCreated > 0);
    Assert.IsTrue(Stats.TotalAcquires > 0);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_ResetStats_ClearsStatistics;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Stats: TPoolStats;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    Pool.Release(Item);
    Pool.ResetStats;
    Stats := Pool.GetStats;
    Assert.AreEqual(Int64(0), Stats.TotalAcquires);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_CurrentSize_ReturnsTotal;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Pool.Warm(5);
    Assert.AreEqual(5, Pool.CurrentSize);
    Item := Pool.Acquire;
    Assert.AreEqual(5, Pool.CurrentSize);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_IdleCount_ReturnsAvailable;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Pool.Warm(5);
    Assert.AreEqual(5, Pool.IdleCount);
    Item := Pool.Acquire;
    Assert.AreEqual(4, Pool.IdleCount);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_InUseCount_ReturnsActive;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Assert.AreEqual(0, Pool.InUseCount);
    Item := Pool.Acquire;
    Assert.AreEqual(1, Pool.InUseCount);
    Pool.Release(Item);
    Assert.AreEqual(0, Pool.InUseCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_OnObjectCreated_Event;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  EventCalled: Boolean;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    EventCalled := False;
    Pool.OnObjectCreated := 
      procedure(Sender: TObject; AObject: TPoolTestItem)
      begin
        EventCalled := True;
      end;
    
    Item := Pool.Acquire;
    Assert.IsTrue(EventCalled);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_OnObjectAcquired_Event;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  EventCalled: Boolean;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    EventCalled := False;
    Pool.OnObjectAcquired := 
      procedure(Sender: TObject; AObject: TPoolTestItem)
      begin
        EventCalled := True;
      end;
    
    Item := Pool.Acquire;
    Assert.IsTrue(EventCalled);
    Pool.Release(Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_OnObjectReleased_Event;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  EventCalled: Boolean;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    EventCalled := False;
    Pool.OnObjectReleased := 
      procedure(Sender: TObject; AObject: TPoolTestItem)
      begin
        EventCalled := True;
      end;
    
    Item := Pool.Acquire;
    Pool.Release(Item);
    Assert.IsTrue(EventCalled);
  finally
    Pool.Free;
  end;
end;

procedure TTestAdvancedObjectPool.Test_ConcurrentAccess_ThreadSafe;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Config: TPoolConfig;
  Tasks: array[0..9] of ITask;
  I: Integer;
  ErrorCount: Integer;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Config := TPoolConfig.Default;
  Config.MinSize := 10;
  Config.MaxSize := 50;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory, Config);
  try
    ErrorCount := 0;
    
    for I := 0 to High(Tasks) do
    begin
      Tasks[I] := TTask.Run(
        procedure
        var
          Item: TPoolTestItem;
          J: Integer;
        begin
          try
            for J := 1 to 50 do
            begin
              Item := Pool.Acquire;
              Item.Data := 'Thread ' + TTask.CurrentTask.Id.ToString;
              Sleep(1);
              Pool.Release(Item);
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

{ TTestKeyedObjectPool }

procedure TTestKeyedObjectPool.Test_Create_WithFactory;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Assert.IsNotNull(Pool);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_Acquire_ByKey;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire('key1');
    Assert.IsNotNull(Item);
    Pool.Release('key1', Item);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_Release_ByKey;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item: TPoolTestItem;
  P: TObjectPool<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire('key1');
    Pool.Release('key1', Item);
    P := Pool.GetPool('key1');
    Assert.AreEqual(1, P.IdleCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_GetPool_ReturnsPoolForKey;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item: TPoolTestItem;
  P: TObjectPool<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire('testkey');
    Pool.Release('testkey', Item);
    
    P := Pool.GetPool('testkey');
    Assert.IsNotNull(P);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_ClearKey_ClearsSpecificPool;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item1, Item2: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item1 := Pool.Acquire('key1');
    Item2 := Pool.Acquire('key2');
    Pool.Release('key1', Item1);
    Pool.Release('key2', Item2);
    
    Pool.ClearKey('key1');
    
    Assert.AreEqual(0, Pool.GetPool('key1').CurrentSize);
    Assert.AreEqual(1, Pool.GetPool('key2').CurrentSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_ClearAll_ClearsAllPools;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item1, Item2: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item1 := Pool.Acquire('key1');
    Item2 := Pool.Acquire('key2');
    Pool.Release('key1', Item1);
    Pool.Release('key2', Item2);
    
    Pool.ClearAll;
    
    // After ClearAll, pools should be empty
    Assert.AreEqual(0, Pool.GetPool('key1').CurrentSize);
  finally
    Pool.Free;
  end;
end;

procedure TTestKeyedObjectPool.Test_MultipleKeys_SeparatePools;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TKeyedObjectPool<string, TPoolTestItem>;
  Item1, Item2, Item3: TPoolTestItem;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TKeyedObjectPool<string, TPoolTestItem>.Create(Factory);
  try
    Item1 := Pool.Acquire('poolA');
    Item2 := Pool.Acquire('poolA');
    Item3 := Pool.Acquire('poolB');
    
    Pool.Release('poolA', Item1);
    Pool.Release('poolA', Item2);
    Pool.Release('poolB', Item3);
    
    Assert.AreEqual(2, Pool.GetPool('poolA').IdleCount);
    Assert.AreEqual(1, Pool.GetPool('poolB').IdleCount);
  finally
    Pool.Free;
  end;
end;

{ TTestScopedPoolObject }

procedure TTestScopedPoolObject.Test_Create_HoldsObject;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
  Scoped: IScopedPoolObject<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    Scoped := TScopedPoolObject<TPoolTestItem>.Create(Pool, Item);
    Assert.AreSame(Item, Scoped.Obj);
  finally
    Pool.Free;
  end;
end;

procedure TTestScopedPoolObject.Test_Destroy_ReleasesToPool;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
  IdleBefore: Integer;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Pool.Warm(5);
    Item := Pool.Acquire;
    IdleBefore := Pool.IdleCount;
    
    // Create scoped object in a nested procedure
    (procedure
    var
      Scoped: IScopedPoolObject<TPoolTestItem>;
    begin
      Scoped := TScopedPoolObject<TPoolTestItem>.Create(Pool, Item);
      // Scoped goes out of scope here
    end)();
    
    Assert.AreEqual(IdleBefore + 1, Pool.IdleCount);
  finally
    Pool.Free;
  end;
end;

procedure TTestScopedPoolObject.Test_GetObject_ReturnsObject;
var
  Factory: IObjectFactory<TPoolTestItem>;
  Pool: TObjectPool<TPoolTestItem>;
  Item: TPoolTestItem;
  Scoped: IScopedPoolObject<TPoolTestItem>;
begin
  Factory := TDefaultObjectFactory<TPoolTestItem>.Create;
  Pool := TObjectPool<TPoolTestItem>.Create(Factory);
  try
    Item := Pool.Acquire;
    Item.Data := 'Test';
    Scoped := TScopedPoolObject<TPoolTestItem>.Create(Pool, Item);
    Assert.AreEqual('Test', Scoped.Obj.Data);
  finally
    Pool.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPoolConfig);
  TDUnitX.RegisterTestFixture(TTestPoolStats);
  TDUnitX.RegisterTestFixture(TTestPooledObject);
  TDUnitX.RegisterTestFixture(TTestDefaultObjectFactory);
  TDUnitX.RegisterTestFixture(TTestCallbackObjectFactory);
  TDUnitX.RegisterTestFixture(TTestAdvancedObjectPool);
  TDUnitX.RegisterTestFixture(TTestKeyedObjectPool);
  TDUnitX.RegisterTestFixture(TTestScopedPoolObject);

end.
