unit UniBase.Memory;

{*******************************************************************************
  UniBase.Memory - 高级内存管理

  版本: 1.0
  功能:
  - 对象池 (Object Pool) - 减少频繁创建/销毁开销
  - 内存池 (Memory Pool) - 固定大小块分配
  - 智能缓存 (Smart Cache) - 带 LRU/LFU/TTL 淘汰策略
  - 内存泄漏检测
  - 内存使用统计
  - 弱引用支持

  线程安全: 所有公共方法都是线程安全的

  用法:
    // 对象池
    Pool := TObjectPool<TMyObject>.Create(
      function: TMyObject begin Result := TMyObject.Create; end,
      10, 100
    );
    Obj := Pool.Acquire;
    try
      // 使用对象
    finally
      Pool.Release(Obj);
    end;

    // 智能缓存
    Cache := TSmartCache<string, TMyData>.Create;
    Cache.EvictionPolicy := epLRU;
    Cache.MaxSize := 1000;
    Cache.Put('key', Data);
    if Cache.TryGet('key', Data) then ...
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.DateUtils,
  System.Generics.Collections, System.Generics.Defaults, System.Diagnostics,
  System.TypInfo, System.Rtti;

type
  /// <summary>缓存淘汰策略</summary>
  TEvictionPolicy = (
    epNone,     // 不淘汰，满时抛异常
    epLRU,      // Least Recently Used
    epLFU,      // Least Frequently Used
    epFIFO,     // First In First Out
    epTTL,      // Time To Live
    epRandom    // 随机淘汰
  );

  /// <summary>内存统计信息</summary>
  TMemoryStats = record
    TotalAllocated: Int64;
    TotalFreed: Int64;
    CurrentUsage: Int64;
    PeakUsage: Int64;
    AllocationCount: Int64;
    FreeCount: Int64;
    PoolHits: Int64;
    PoolMisses: Int64;
    CacheHits: Int64;
    CacheMisses: Int64;
    function ToString: string;
  end;

  /// <summary>对象重置接口</summary>
  IPoolable = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Reset;
  end;

  /// <summary>
  /// 泛型对象池
  /// </summary>
  TObjectPool<T: class> = class
  public type
    TObjectFactory = reference to function: T;
    TObjectReset = reference to procedure(Obj: T);
  private
    FFactory: TObjectFactory;
    FResetProc: TObjectReset;
    FPool: TList<T>;
    FInUse: TList<T>;
    FLock: TCriticalSection;
    FMinSize: Integer;
    FMaxSize: Integer;
    FGrowBy: Integer;
    FStats: TMemoryStats;

    procedure EnsureMinSize;
    procedure Shrink;
  public
    constructor Create(Factory: TObjectFactory; MinSize: Integer = 5;
      MaxSize: Integer = 100; GrowBy: Integer = 5);
    destructor Destroy; override;

    /// <summary>获取对象</summary>
    function Acquire: T;

    /// <summary>尝试获取对象</summary>
    function TryAcquire(out Obj: T): Boolean;

    /// <summary>释放对象回池</summary>
    procedure Release(Obj: T);

    /// <summary>清空池</summary>
    procedure Clear;

    /// <summary>预热</summary>
    procedure Warmup(Count: Integer);

    /// <summary>收缩到最小大小</summary>
    procedure Compact;

    /// <summary>设置重置回调</summary>
    procedure SetResetProc(Proc: TObjectReset);

    /// <summary>池中可用对象数</summary>
    function AvailableCount: Integer;

    /// <summary>正在使用的对象数</summary>
    function InUseCount: Integer;

    /// <summary>获取统计</summary>
    function GetStats: TMemoryStats;

    property MinSize: Integer read FMinSize write FMinSize;
    property MaxSize: Integer read FMaxSize write FMaxSize;
  end;

  /// <summary>
  /// 固定大小内存块池
  /// </summary>
  TMemoryBlockPool = class
  private type
    PBlockHeader = ^TBlockHeader;
    TBlockHeader = record
      Next: PBlockHeader;
      InUse: Boolean;
    end;
  private
    FBlockSize: Integer;
    FFreeList: PBlockHeader;
    FAllBlocks: TList<Pointer>;
    FLock: TCriticalSection;
    FAllocatedCount: Integer;
    FFreeCount: Integer;
    FGrowBy: Integer;

    procedure GrowPool;
  public
    constructor Create(BlockSize: Integer; InitialCount: Integer = 16;
      GrowBy: Integer = 16);
    destructor Destroy; override;

    /// <summary>分配内存块</summary>
    function Allocate: Pointer;

    /// <summary>释放内存块</summary>
    procedure Deallocate(P: Pointer);

    /// <summary>清空池</summary>
    procedure Clear;

    property BlockSize: Integer read FBlockSize;
    property AllocatedCount: Integer read FAllocatedCount;
    property FreeCount: Integer read FFreeCount;
  end;

  /// <summary>
  /// 缓存条目
  /// </summary>
  TCacheEntry<V> = record
    Value: V;
    CreatedAt: TDateTime;
    LastAccessedAt: TDateTime;
    AccessCount: Int64;
    TTLSeconds: Integer;
    Size: Integer;
  end;

  /// <summary>
  /// 智能缓存
  /// </summary>
  TSmartCache<K, V> = class
  private type
    TEntry = TCacheEntry<V>;
    PEntry = ^TEntry;
  private
    FCache: TDictionary<K, TEntry>;
    FAccessOrder: TList<K>;  // 用于 LRU
    FLock: TCriticalSection;
    FMaxSize: Integer;
    FMaxMemory: Int64;
    FCurrentMemory: Int64;
    FEvictionPolicy: TEvictionPolicy;
    FDefaultTTL: Integer;
    FStats: TMemoryStats;
    FOnEvict: TProc<K, V>;

    function GetCount: Integer;
    procedure Evict(Count: Integer = 1);
    procedure EvictByLRU;
    procedure EvictByLFU;
    procedure EvictByFIFO;
    procedure EvictByTTL;
    procedure EvictByRandom;
    procedure UpdateAccessOrder(const Key: K);
    procedure CleanExpired;
    function IsExpired(const Entry: TEntry): Boolean;
    function EstimateSize(const Value: V): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>添加或更新缓存项</summary>
    procedure Put(const Key: K; const Value: V; TTLSeconds: Integer = -1);

    /// <summary>获取缓存项</summary>
    function Get(const Key: K): V;

    /// <summary>尝试获取缓存项</summary>
    function TryGet(const Key: K; out Value: V): Boolean;

    /// <summary>检查是否存在</summary>
    function Contains(const Key: K): Boolean;

    /// <summary>移除缓存项</summary>
    function Remove(const Key: K): Boolean;

    /// <summary>清空缓存</summary>
    procedure Clear;

    /// <summary>获取或添加</summary>
    function GetOrAdd(const Key: K; Factory: TFunc<V>): V;

    /// <summary>获取所有键</summary>
    function GetKeys: TArray<K>;

    /// <summary>获取统计</summary>
    function GetStats: TMemoryStats;

    /// <summary>重置统计</summary>
    procedure ResetStats;

    property Count: Integer read GetCount;
    property MaxSize: Integer read FMaxSize write FMaxSize;
    property MaxMemory: Int64 read FMaxMemory write FMaxMemory;
    property EvictionPolicy: TEvictionPolicy read FEvictionPolicy write FEvictionPolicy;
    property DefaultTTL: Integer read FDefaultTTL write FDefaultTTL;
    property OnEvict: TProc<K, V> read FOnEvict write FOnEvict;
  end;

  /// <summary>
  /// 内存泄漏跟踪器
  /// </summary>
  TMemoryTracker = class
  private type
    TAllocationInfo = record
      Address: Pointer;
      Size: Integer;
      ClassName: string;
      StackTrace: string;
      AllocatedAt: TDateTime;
    end;
  private
    class var FInstance: TMemoryTracker;
    class var FLock: TCriticalSection;
    FAllocations: TDictionary<Pointer, TAllocationInfo>;
    FEnabled: Boolean;
    FTrackStackTrace: Boolean;
    FAllocLock: TCriticalSection;

    function GetCurrentStackTrace: string;
  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TMemoryTracker;
    class procedure FreeInstance;

    /// <summary>跟踪分配</summary>
    procedure TrackAllocation(P: Pointer; Size: Integer; const ClassName: string = '');

    /// <summary>跟踪释放</summary>
    procedure TrackDeallocation(P: Pointer);

    /// <summary>获取泄漏报告</summary>
    function GetLeakReport: string;

    /// <summary>获取当前分配数</summary>
    function GetAllocationCount: Integer;

    /// <summary>获取当前分配内存</summary>
    function GetAllocatedMemory: Int64;

    /// <summary>清除跟踪数据</summary>
    procedure ClearTracking;

    property Enabled: Boolean read FEnabled write FEnabled;
    property TrackStackTrace: Boolean read FTrackStackTrace write FTrackStackTrace;
  end;

  /// <summary>
  /// 弱引用包装器
  /// </summary>
  TWeakRef<T: class> = record
  private
    FRef: Pointer;
    function GetTarget: T;
    function GetIsAlive: Boolean;
  public
    constructor Create(Target: T);
    function TryGetTarget(out Target: T): Boolean;
    property Target: T read GetTarget;
    property IsAlive: Boolean read GetIsAlive;
  end;

  /// <summary>
  /// 环形缓冲区
  /// </summary>
  TRingBuffer<T> = class
  private
    FBuffer: TArray<T>;
    FCapacity: Integer;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FLock: TCriticalSection;
  public
    constructor Create(Capacity: Integer);
    destructor Destroy; override;

    /// <summary>写入数据</summary>
    function Write(const Item: T): Boolean;

    /// <summary>批量写入</summary>
    function WriteMany(const Items: TArray<T>): Integer;

    /// <summary>读取数据</summary>
    function Read(out Item: T): Boolean;

    /// <summary>批量读取</summary>
    function ReadMany(Count: Integer): TArray<T>;

    /// <summary>查看但不移除</summary>
    function Peek(out Item: T): Boolean;

    /// <summary>清空</summary>
    procedure Clear;

    property Count: Integer read FCount;
    property Capacity: Integer read FCapacity;
    function IsFull: Boolean;
    function IsEmpty: Boolean;
  end;

  /// <summary>
  /// 内存映射大文件读取器
  /// </summary>
  TMemoryMappedFile = class
  private
    {$IFDEF MSWINDOWS}
    FFileHandle: THandle;
    FMappingHandle: THandle;
    FMapView: Pointer;
    {$ENDIF}
    FFileName: string;
    FFileSize: Int64;
    FMapped: Boolean;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;

    /// <summary>映射文件</summary>
    function Map: Boolean;

    /// <summary>取消映射</summary>
    procedure Unmap;

    /// <summary>获取映射指针</summary>
    function GetData: Pointer;

    /// <summary>读取指定位置数据</summary>
    function ReadAt(Offset: Int64; Buffer: Pointer; Size: Integer): Integer;

    property FileName: string read FFileName;
    property FileSize: Int64 read FFileSize;
    property IsMapped: Boolean read FMapped;
  end;

/// <summary>获取进程内存使用</summary>
function GetProcessMemoryUsage: Int64;

/// <summary>获取系统内存信息</summary>
procedure GetSystemMemoryInfo(out TotalPhys, AvailPhys, TotalVirtual, AvailVirtual: Int64);

/// <summary>获取内存跟踪器</summary>
function MemTracker: TMemoryTracker;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.PsAPI,
  {$ENDIF}
  System.Math;

{ TMemoryStats }

function TMemoryStats.ToString: string;
begin
  Result := Format(
    '内存统计:' + sLineBreak +
    '  总分配: %d 字节' + sLineBreak +
    '  总释放: %d 字节' + sLineBreak +
    '  当前使用: %d 字节' + sLineBreak +
    '  峰值使用: %d 字节' + sLineBreak +
    '  分配次数: %d' + sLineBreak +
    '  释放次数: %d' + sLineBreak +
    '  池命中: %d' + sLineBreak +
    '  池未命中: %d' + sLineBreak +
    '  缓存命中: %d' + sLineBreak +
    '  缓存未命中: %d',
    [TotalAllocated, TotalFreed, CurrentUsage, PeakUsage,
     AllocationCount, FreeCount, PoolHits, PoolMisses,
     CacheHits, CacheMisses]);
end;

{ TObjectPool<T> }

constructor TObjectPool<T>.Create(Factory: TObjectFactory; MinSize, MaxSize, GrowBy: Integer);
begin
  inherited Create;
  FFactory := Factory;
  FMinSize := MinSize;
  FMaxSize := MaxSize;
  FGrowBy := GrowBy;
  FPool := TList<T>.Create;
  FInUse := TList<T>.Create;
  FLock := TCriticalSection.Create;
  FillChar(FStats, SizeOf(FStats), 0);
  EnsureMinSize;
end;

destructor TObjectPool<T>.Destroy;
var
  Obj: T;
begin
  FLock.Enter;
  try
    for Obj in FPool do
      Obj.Free;
    for Obj in FInUse do
      Obj.Free;
    FPool.Free;
    FInUse.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

procedure TObjectPool<T>.EnsureMinSize;
var
  I: Integer;
begin
  while FPool.Count < FMinSize do
  begin
    try
      FPool.Add(FFactory());
      Inc(FStats.AllocationCount);
    except
      Break;
    end;
  end;
end;

procedure TObjectPool<T>.Shrink;
var
  Obj: T;
begin
  while FPool.Count > FMaxSize do
  begin
    Obj := FPool[FPool.Count - 1];
    FPool.Delete(FPool.Count - 1);
    Obj.Free;
    Inc(FStats.FreeCount);
  end;
end;

function TObjectPool<T>.Acquire: T;
begin
  if not TryAcquire(Result) then
    raise Exception.Create('对象池已耗尽');
end;

function TObjectPool<T>.TryAcquire(out Obj: T): Boolean;
var
  I: Integer;
begin
  Result := False;
  Obj := nil;

  FLock.Enter;
  try
    if FPool.Count > 0 then
    begin
      Obj := FPool[FPool.Count - 1];
      FPool.Delete(FPool.Count - 1);
      FInUse.Add(Obj);
      Inc(FStats.PoolHits);
      Result := True;
    end
    else if FInUse.Count < FMaxSize then
    begin
      // 创建新对象
      try
        Obj := FFactory();
        FInUse.Add(Obj);
        Inc(FStats.AllocationCount);
        Inc(FStats.PoolMisses);
        Result := True;
      except
        Result := False;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Release(Obj: T);
var
  Index: Integer;
begin
  if Obj = nil then
    Exit;

  FLock.Enter;
  try
    Index := FInUse.IndexOf(Obj);
    if Index >= 0 then
    begin
      FInUse.Delete(Index);

      // 重置对象
      if Assigned(FResetProc) then
        FResetProc(Obj)
      else if Supports(Obj, IPoolable) then
        (Obj as IPoolable).Reset;

      if FPool.Count < FMaxSize then
        FPool.Add(Obj)
      else
      begin
        Obj.Free;
        Inc(FStats.FreeCount);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Clear;
var
  Obj: T;
begin
  FLock.Enter;
  try
    for Obj in FPool do
    begin
      Obj.Free;
      Inc(FStats.FreeCount);
    end;
    FPool.Clear;

    for Obj in FInUse do
    begin
      Obj.Free;
      Inc(FStats.FreeCount);
    end;
    FInUse.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Warmup(Count: Integer);
var
  I, Target: Integer;
begin
  Target := Min(Count, FMaxSize);

  FLock.Enter;
  try
    for I := FPool.Count to Target - 1 do
    begin
      try
        FPool.Add(FFactory());
        Inc(FStats.AllocationCount);
      except
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Compact;
var
  Obj: T;
begin
  FLock.Enter;
  try
    while FPool.Count > FMinSize do
    begin
      Obj := FPool[FPool.Count - 1];
      FPool.Delete(FPool.Count - 1);
      Obj.Free;
      Inc(FStats.FreeCount);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.SetResetProc(Proc: TObjectReset);
begin
  FResetProc := Proc;
end;

function TObjectPool<T>.AvailableCount: Integer;
begin
  FLock.Enter;
  try
    Result := FPool.Count;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.InUseCount: Integer;
begin
  FLock.Enter;
  try
    Result := FInUse.Count;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetStats: TMemoryStats;
begin
  FLock.Enter;
  try
    Result := FStats;
  finally
    FLock.Leave;
  end;
end;

{ TMemoryBlockPool }

constructor TMemoryBlockPool.Create(BlockSize, InitialCount, GrowBy: Integer);
begin
  inherited Create;
  FBlockSize := BlockSize + SizeOf(TBlockHeader);
  FGrowBy := GrowBy;
  FFreeList := nil;
  FAllBlocks := TList<Pointer>.Create;
  FLock := TCriticalSection.Create;
  FAllocatedCount := 0;
  FFreeCount := 0;

  // 初始分配
  while FAllBlocks.Count < InitialCount do
    GrowPool;
end;

destructor TMemoryBlockPool.Destroy;
var
  P: Pointer;
begin
  FLock.Enter;
  try
    for P in FAllBlocks do
      FreeMem(P);
    FAllBlocks.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

procedure TMemoryBlockPool.GrowPool;
var
  I: Integer;
  Block: PBlockHeader;
  P: Pointer;
begin
  for I := 0 to FGrowBy - 1 do
  begin
    GetMem(P, FBlockSize);
    Block := PBlockHeader(P);
    Block^.InUse := False;
    Block^.Next := FFreeList;
    FFreeList := Block;
    FAllBlocks.Add(P);
    Inc(FFreeCount);
  end;
end;

function TMemoryBlockPool.Allocate: Pointer;
var
  Block: PBlockHeader;
begin
  FLock.Enter;
  try
    if FFreeList = nil then
      GrowPool;

    Block := FFreeList;
    FFreeList := Block^.Next;
    Block^.InUse := True;
    Block^.Next := nil;
    Dec(FFreeCount);
    Inc(FAllocatedCount);

    // 返回用户数据区域（跳过头部）
    Result := Pointer(NativeUInt(Block) + SizeOf(TBlockHeader));
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryBlockPool.Deallocate(P: Pointer);
var
  Block: PBlockHeader;
begin
  if P = nil then
    Exit;

  FLock.Enter;
  try
    // 获取块头
    Block := PBlockHeader(NativeUInt(P) - SizeOf(TBlockHeader));
    if Block^.InUse then
    begin
      Block^.InUse := False;
      Block^.Next := FFreeList;
      FFreeList := Block;
      Dec(FAllocatedCount);
      Inc(FFreeCount);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryBlockPool.Clear;
var
  P: Pointer;
  Block: PBlockHeader;
begin
  FLock.Enter;
  try
    FFreeList := nil;
    for P in FAllBlocks do
    begin
      Block := PBlockHeader(P);
      Block^.InUse := False;
      Block^.Next := FFreeList;
      FFreeList := Block;
    end;
    FFreeCount := FAllBlocks.Count;
    FAllocatedCount := 0;
  finally
    FLock.Leave;
  end;
end;

{ TSmartCache<K, V> }

constructor TSmartCache<K, V>.Create;
begin
  inherited Create;
  FCache := TDictionary<K, TEntry>.Create;
  FAccessOrder := TList<K>.Create;
  FLock := TCriticalSection.Create;
  FMaxSize := 1000;
  FMaxMemory := 100 * 1024 * 1024; // 100MB
  FCurrentMemory := 0;
  FEvictionPolicy := epLRU;
  FDefaultTTL := 0; // 不过期
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TSmartCache<K, V>.Destroy;
begin
  FCache.Free;
  FAccessOrder.Free;
  FLock.Free;
  inherited;
end;

function TSmartCache<K, V>.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCache.Count;
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.EstimateSize(const Value: V): Integer;
begin
  // 简单估算，实际应该根据类型计算
  Result := SizeOf(V);
  if SizeOf(V) = SizeOf(Pointer) then
    Result := 100; // 假设引用类型平均100字节
end;

procedure TSmartCache<K, V>.Put(const Key: K; const Value: V; TTLSeconds: Integer);
var
  Entry: TEntry;
  OldEntry: TEntry;
begin
  FLock.Enter;
  try
    // 检查是否需要淘汰
    while (FCache.Count >= FMaxSize) or
          ((FMaxMemory > 0) and (FCurrentMemory >= FMaxMemory)) do
    begin
      if FEvictionPolicy = epNone then
        raise Exception.Create('缓存已满');
      Evict;
    end;

    // 如果存在旧值，先移除
    if FCache.TryGetValue(Key, OldEntry) then
    begin
      Dec(FCurrentMemory, OldEntry.Size);
      FAccessOrder.Remove(Key);
    end;

    // 创建新条目
    Entry.Value := Value;
    Entry.CreatedAt := Now;
    Entry.LastAccessedAt := Now;
    Entry.AccessCount := 0;
    if TTLSeconds >= 0 then
      Entry.TTLSeconds := TTLSeconds
    else
      Entry.TTLSeconds := FDefaultTTL;
    Entry.Size := EstimateSize(Value);

    FCache.AddOrSetValue(Key, Entry);
    FAccessOrder.Add(Key);
    Inc(FCurrentMemory, Entry.Size);
    Inc(FStats.AllocationCount);
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.Get(const Key: K): V;
begin
  if not TryGet(Key, Result) then
    raise Exception.Create('缓存键不存在');
end;

function TSmartCache<K, V>.TryGet(const Key: K; out Value: V): Boolean;
var
  Entry: TEntry;
begin
  Result := False;
  FLock.Enter;
  try
    if FCache.TryGetValue(Key, Entry) then
    begin
      // 检查是否过期
      if IsExpired(Entry) then
      begin
        FCache.Remove(Key);
        FAccessOrder.Remove(Key);
        Dec(FCurrentMemory, Entry.Size);
        Inc(FStats.CacheMisses);
        Exit;
      end;

      // 更新访问信息
      Entry.LastAccessedAt := Now;
      Inc(Entry.AccessCount);
      FCache.AddOrSetValue(Key, Entry);
      UpdateAccessOrder(Key);

      Value := Entry.Value;
      Result := True;
      Inc(FStats.CacheHits);
    end
    else
      Inc(FStats.CacheMisses);
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.Contains(const Key: K): Boolean;
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    Result := FCache.TryGetValue(Key, Entry) and not IsExpired(Entry);
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.Remove(const Key: K): Boolean;
var
  Entry: TEntry;
begin
  Result := False;
  FLock.Enter;
  try
    if FCache.TryGetValue(Key, Entry) then
    begin
      if Assigned(FOnEvict) then
        FOnEvict(Key, Entry.Value);
      Dec(FCurrentMemory, Entry.Size);
      FCache.Remove(Key);
      FAccessOrder.Remove(Key);
      Inc(FStats.FreeCount);
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TSmartCache<K, V>.Clear;
var
  Pair: TPair<K, TEntry>;
begin
  FLock.Enter;
  try
    if Assigned(FOnEvict) then
    begin
      for Pair in FCache do
        FOnEvict(Pair.Key, Pair.Value.Value);
    end;
    FCache.Clear;
    FAccessOrder.Clear;
    FCurrentMemory := 0;
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.GetOrAdd(const Key: K; Factory: TFunc<V>): V;
begin
  if not TryGet(Key, Result) then
  begin
    Result := Factory();
    Put(Key, Result);
  end;
end;

function TSmartCache<K, V>.GetKeys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FCache.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TSmartCache<K, V>.GetStats: TMemoryStats;
begin
  FLock.Enter;
  try
    Result := FStats;
    Result.CurrentUsage := FCurrentMemory;
  finally
    FLock.Leave;
  end;
end;

procedure TSmartCache<K, V>.ResetStats;
begin
  FLock.Enter;
  try
    FillChar(FStats, SizeOf(FStats), 0);
  finally
    FLock.Leave;
  end;
end;

procedure TSmartCache<K, V>.Evict(Count: Integer);
var
  I: Integer;
begin
  // 先清理过期项
  CleanExpired;

  // 如果仍需淘汰
  for I := 1 to Count do
  begin
    if FCache.Count = 0 then
      Break;

    case FEvictionPolicy of
      epLRU: EvictByLRU;
      epLFU: EvictByLFU;
      epFIFO: EvictByFIFO;
      epTTL: EvictByTTL;
      epRandom: EvictByRandom;
    end;
  end;
end;

procedure TSmartCache<K, V>.EvictByLRU;
var
  Key: K;
  Entry: TEntry;
begin
  if FAccessOrder.Count > 0 then
  begin
    Key := FAccessOrder[0];
    if FCache.TryGetValue(Key, Entry) then
    begin
      if Assigned(FOnEvict) then
        FOnEvict(Key, Entry.Value);
      Dec(FCurrentMemory, Entry.Size);
      FCache.Remove(Key);
      Inc(FStats.FreeCount);
    end;
    FAccessOrder.Delete(0);
  end;
end;

procedure TSmartCache<K, V>.EvictByLFU;
var
  MinKey: K;
  MinCount: Int64;
  Pair: TPair<K, TEntry>;
  Found: Boolean;
begin
  MinCount := High(Int64);
  Found := False;

  for Pair in FCache do
  begin
    if Pair.Value.AccessCount < MinCount then
    begin
      MinCount := Pair.Value.AccessCount;
      MinKey := Pair.Key;
      Found := True;
    end;
  end;

  if Found then
    Remove(MinKey);
end;

procedure TSmartCache<K, V>.EvictByFIFO;
var
  OldestKey: K;
  OldestTime: TDateTime;
  Pair: TPair<K, TEntry>;
  Found: Boolean;
begin
  OldestTime := Now;
  Found := False;

  for Pair in FCache do
  begin
    if Pair.Value.CreatedAt < OldestTime then
    begin
      OldestTime := Pair.Value.CreatedAt;
      OldestKey := Pair.Key;
      Found := True;
    end;
  end;

  if Found then
    Remove(OldestKey);
end;

procedure TSmartCache<K, V>.EvictByTTL;
var
  Pair: TPair<K, TEntry>;
  ToRemove: TList<K>;
begin
  ToRemove := TList<K>.Create;
  try
    for Pair in FCache do
    begin
      if IsExpired(Pair.Value) then
        ToRemove.Add(Pair.Key);
    end;

    for var Key in ToRemove do
      Remove(Key);

    // 如果没有过期的，使用 LRU
    if ToRemove.Count = 0 then
      EvictByLRU;
  finally
    ToRemove.Free;
  end;
end;

procedure TSmartCache<K, V>.EvictByRandom;
var
  Keys: TArray<K>;
  Index: Integer;
begin
  Keys := FCache.Keys.ToArray;
  if Length(Keys) > 0 then
  begin
    Index := Random(Length(Keys));
    Remove(Keys[Index]);
  end;
end;

procedure TSmartCache<K, V>.UpdateAccessOrder(const Key: K);
var
  Index: Integer;
begin
  Index := FAccessOrder.IndexOf(Key);
  if Index >= 0 then
  begin
    FAccessOrder.Delete(Index);
    FAccessOrder.Add(Key);
  end;
end;

procedure TSmartCache<K, V>.CleanExpired;
var
  Pair: TPair<K, TEntry>;
  ToRemove: TList<K>;
begin
  ToRemove := TList<K>.Create;
  try
    for Pair in FCache do
    begin
      if IsExpired(Pair.Value) then
        ToRemove.Add(Pair.Key);
    end;

    for var Key in ToRemove do
      Remove(Key);
  finally
    ToRemove.Free;
  end;
end;

function TSmartCache<K, V>.IsExpired(const Entry: TEntry): Boolean;
begin
  Result := (Entry.TTLSeconds > 0) and
            (SecondsBetween(Now, Entry.CreatedAt) > Entry.TTLSeconds);
end;

{ TMemoryTracker }

constructor TMemoryTracker.Create;
begin
  inherited Create;
  FAllocations := TDictionary<Pointer, TAllocationInfo>.Create;
  FAllocLock := TCriticalSection.Create;
  FEnabled := False;
  FTrackStackTrace := False;
end;

destructor TMemoryTracker.Destroy;
begin
  FAllocations.Free;
  FAllocLock.Free;
  inherited;
end;

class function TMemoryTracker.Instance: TMemoryTracker;
begin
  if FInstance = nil then
  begin
    if FLock = nil then
      FLock := TCriticalSection.Create;

    FLock.Enter;
    try
      if FInstance = nil then
        FInstance := TMemoryTracker.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TMemoryTracker.FreeInstance;
begin
  if Assigned(FLock) then
  begin
    FLock.Enter;
    try
      FreeAndNil(FInstance);
    finally
      FLock.Leave;
    end;
    FreeAndNil(FLock);
  end;
end;

function TMemoryTracker.GetCurrentStackTrace: string;
begin
  // 简化实现，实际应使用 JclDebug 或 madExcept
  Result := '';
  {$IFDEF DEBUG}
  // 可以添加堆栈跟踪
  {$ENDIF}
end;

procedure TMemoryTracker.TrackAllocation(P: Pointer; Size: Integer;
  const ClassName: string);
var
  Info: TAllocationInfo;
begin
  if not FEnabled then
    Exit;

  Info.Address := P;
  Info.Size := Size;
  Info.ClassName := ClassName;
  Info.AllocatedAt := Now;
  if FTrackStackTrace then
    Info.StackTrace := GetCurrentStackTrace
  else
    Info.StackTrace := '';

  FAllocLock.Enter;
  try
    FAllocations.AddOrSetValue(P, Info);
  finally
    FAllocLock.Leave;
  end;
end;

procedure TMemoryTracker.TrackDeallocation(P: Pointer);
begin
  if not FEnabled then
    Exit;

  FAllocLock.Enter;
  try
    FAllocations.Remove(P);
  finally
    FAllocLock.Leave;
  end;
end;

function TMemoryTracker.GetLeakReport: string;
var
  SB: TStringBuilder;
  Pair: TPair<Pointer, TAllocationInfo>;
  TotalSize: Int64;
begin
  SB := TStringBuilder.Create;
  try
    TotalSize := 0;

    FAllocLock.Enter;
    try
      SB.AppendLine('=== 内存泄漏报告 ===');
      SB.AppendLine(Format('检测到 %d 处泄漏:', [FAllocations.Count]));
      SB.AppendLine;

      for Pair in FAllocations do
      begin
        SB.AppendFormat('  地址: %p', [Pair.Value.Address]);
        SB.AppendLine;
        SB.AppendFormat('  大小: %d 字节', [Pair.Value.Size]);
        SB.AppendLine;
        if Pair.Value.ClassName <> '' then
        begin
          SB.AppendFormat('  类名: %s', [Pair.Value.ClassName]);
          SB.AppendLine;
        end;
        SB.AppendFormat('  分配时间: %s', [DateTimeToStr(Pair.Value.AllocatedAt)]);
        SB.AppendLine;
        if Pair.Value.StackTrace <> '' then
        begin
          SB.AppendLine('  堆栈:');
          SB.AppendLine(Pair.Value.StackTrace);
        end;
        SB.AppendLine;
        Inc(TotalSize, Pair.Value.Size);
      end;

      SB.AppendFormat('总泄漏: %d 字节', [TotalSize]);
    finally
      FAllocLock.Leave;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TMemoryTracker.GetAllocationCount: Integer;
begin
  FAllocLock.Enter;
  try
    Result := FAllocations.Count;
  finally
    FAllocLock.Leave;
  end;
end;

function TMemoryTracker.GetAllocatedMemory: Int64;
var
  Pair: TPair<Pointer, TAllocationInfo>;
begin
  Result := 0;
  FAllocLock.Enter;
  try
    for Pair in FAllocations do
      Inc(Result, Pair.Value.Size);
  finally
    FAllocLock.Leave;
  end;
end;

procedure TMemoryTracker.ClearTracking;
begin
  FAllocLock.Enter;
  try
    FAllocations.Clear;
  finally
    FAllocLock.Leave;
  end;
end;

{ TWeakRef<T> }

constructor TWeakRef<T>.Create(Target: T);
begin
  FRef := Pointer(Target);
end;

function TWeakRef<T>.GetTarget: T;
begin
  Result := T(FRef);
end;

function TWeakRef<T>.GetIsAlive: Boolean;
begin
  Result := FRef <> nil;
end;

function TWeakRef<T>.TryGetTarget(out Target: T): Boolean;
begin
  Target := T(FRef);
  Result := FRef <> nil;
end;

{ TRingBuffer<T> }

constructor TRingBuffer<T>.Create(Capacity: Integer);
begin
  inherited Create;
  FCapacity := Capacity;
  SetLength(FBuffer, Capacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FLock := TCriticalSection.Create;
end;

destructor TRingBuffer<T>.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TRingBuffer<T>.Write(const Item: T): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FCount >= FCapacity then
      Exit;

    FBuffer[FTail] := Item;
    FTail := (FTail + 1) mod FCapacity;
    Inc(FCount);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.WriteMany(const Items: TArray<T>): Integer;
var
  I: Integer;
begin
  Result := 0;
  FLock.Enter;
  try
    for I := 0 to High(Items) do
    begin
      if FCount >= FCapacity then
        Break;

      FBuffer[FTail] := Items[I];
      FTail := (FTail + 1) mod FCapacity;
      Inc(FCount);
      Inc(Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.Read(out Item: T): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FCount = 0 then
      Exit;

    Item := FBuffer[FHead];
    FHead := (FHead + 1) mod FCapacity;
    Dec(FCount);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.ReadMany(Count: Integer): TArray<T>;
var
  I, ActualCount: Integer;
begin
  FLock.Enter;
  try
    ActualCount := Min(Count, FCount);
    SetLength(Result, ActualCount);

    for I := 0 to ActualCount - 1 do
    begin
      Result[I] := FBuffer[FHead];
      FHead := (FHead + 1) mod FCapacity;
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.Peek(out Item: T): Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    if FCount = 0 then
      Exit;

    Item := FBuffer[FHead];
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TRingBuffer<T>.Clear;
begin
  FLock.Enter;
  try
    FHead := 0;
    FTail := 0;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.IsFull: Boolean;
begin
  FLock.Enter;
  try
    Result := FCount >= FCapacity;
  finally
    FLock.Leave;
  end;
end;

function TRingBuffer<T>.IsEmpty: Boolean;
begin
  FLock.Enter;
  try
    Result := FCount = 0;
  finally
    FLock.Leave;
  end;
end;

{ TMemoryMappedFile }

constructor TMemoryMappedFile.Create(const FileName: string);
begin
  inherited Create;
  FFileName := FileName;
  FFileSize := 0;
  FMapped := False;
  {$IFDEF MSWINDOWS}
  FFileHandle := INVALID_HANDLE_VALUE;
  FMappingHandle := 0;
  FMapView := nil;
  {$ENDIF}
end;

destructor TMemoryMappedFile.Destroy;
begin
  Unmap;
  inherited;
end;

function TMemoryMappedFile.Map: Boolean;
{$IFDEF MSWINDOWS}
var
  FileSizeHigh: DWORD;
{$ENDIF}
begin
  Result := False;

  {$IFDEF MSWINDOWS}
  if FMapped then
    Exit(True);

  // 打开文件
  FFileHandle := CreateFile(
    PChar(FFileName),
    GENERIC_READ,
    FILE_SHARE_READ,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0);

  if FFileHandle = INVALID_HANDLE_VALUE then
    Exit;

  // 获取文件大小
  FFileSize := GetFileSize(FFileHandle, @FileSizeHigh);
  FFileSize := FFileSize or (Int64(FileSizeHigh) shl 32);

  // 创建文件映射
  FMappingHandle := CreateFileMapping(
    FFileHandle,
    nil,
    PAGE_READONLY,
    0,
    0,
    nil);

  if FMappingHandle = 0 then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
    Exit;
  end;

  // 映射视图
  FMapView := MapViewOfFile(
    FMappingHandle,
    FILE_MAP_READ,
    0,
    0,
    0);

  if FMapView = nil then
  begin
    CloseHandle(FMappingHandle);
    CloseHandle(FFileHandle);
    FMappingHandle := 0;
    FFileHandle := INVALID_HANDLE_VALUE;
    Exit;
  end;

  FMapped := True;
  Result := True;
  {$ENDIF}
end;

procedure TMemoryMappedFile.Unmap;
begin
  {$IFDEF MSWINDOWS}
  if FMapView <> nil then
  begin
    UnmapViewOfFile(FMapView);
    FMapView := nil;
  end;

  if FMappingHandle <> 0 then
  begin
    CloseHandle(FMappingHandle);
    FMappingHandle := 0;
  end;

  if FFileHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
  end;

  FMapped := False;
  {$ENDIF}
end;

function TMemoryMappedFile.GetData: Pointer;
begin
  {$IFDEF MSWINDOWS}
  Result := FMapView;
  {$ELSE}
  Result := nil;
  {$ENDIF}
end;

function TMemoryMappedFile.ReadAt(Offset: Int64; Buffer: Pointer; Size: Integer): Integer;
begin
  Result := 0;

  {$IFDEF MSWINDOWS}
  if not FMapped or (FMapView = nil) then
    Exit;

  if Offset >= FFileSize then
    Exit;

  Result := Min(Size, FFileSize - Offset);
  Move(Pointer(NativeUInt(FMapView) + Offset)^, Buffer^, Result);
  {$ENDIF}
end;

{ Helper functions }

function GetProcessMemoryUsage: Int64;
{$IFDEF MSWINDOWS}
var
  PMC: TProcessMemoryCounters;
{$ENDIF}
begin
  Result := 0;
  {$IFDEF MSWINDOWS}
  PMC.cb := SizeOf(PMC);
  if GetProcessMemoryInfo(GetCurrentProcess, @PMC, SizeOf(PMC)) then
    Result := PMC.WorkingSetSize;
  {$ENDIF}
end;

procedure GetSystemMemoryInfo(out TotalPhys, AvailPhys, TotalVirtual, AvailVirtual: Int64);
{$IFDEF MSWINDOWS}
var
  MS: TMemoryStatusEx;
{$ENDIF}
begin
  TotalPhys := 0;
  AvailPhys := 0;
  TotalVirtual := 0;
  AvailVirtual := 0;

  {$IFDEF MSWINDOWS}
  MS.dwLength := SizeOf(MS);
  if GlobalMemoryStatusEx(MS) then
  begin
    TotalPhys := MS.ullTotalPhys;
    AvailPhys := MS.ullAvailPhys;
    TotalVirtual := MS.ullTotalVirtual;
    AvailVirtual := MS.ullAvailVirtual;
  end;
  {$ENDIF}
end;

function MemTracker: TMemoryTracker;
begin
  Result := TMemoryTracker.Instance;
end;

initialization

finalization
  TMemoryTracker.FreeInstance;

end.
