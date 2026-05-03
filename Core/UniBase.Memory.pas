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
  System.TypInfo, System.Rtti, UniBase.Logging, UniBase.ObjectPool,
  UniBase.Cache;

type
  /// <summary>内存相关异常基类</summary>
  EMemoryException = class(Exception);

  /// <summary>对象池耗尽或配置错误时抛出的异常</summary>
  EMemoryPoolException = class(EMemoryException);

  /// <summary>智能缓存相关异常</summary>
  EMemoryCacheException = class(EMemoryException);

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
    CreatedTicks: Int64;  // BUG-120 FIX: 使用单调时钟时间戳，不受系统时间调整影响
  end;

  /// <summary>
  /// 智能缓存
  /// </summary>
  TSmartCache<K, V> = class
  private type
    TEntry = TCacheEntry<V>;
    PEntry = ^TEntry;
  private
    FInnerCache: UniBase.Cache.TCache<K, V>;
    FMaxSize: Integer;
    FMaxMemory: Int64;
    FEvictionPolicy: TEvictionPolicy;
    FDefaultTTL: Integer;
    FOnEvict: TProc<K, V>;
    FStatsBaseline: UniBase.Cache.TCacheStats;
    FPutCount: Int64;

    class function ToCacheEvictionPolicy(const Value: TEvictionPolicy): UniBase.Cache.TCacheEvictionPolicy; static;
    procedure SyncLimitsToInner;
    procedure SyncPolicyToInner;
    procedure HandleInnerEvict(const Key: K; const Value: V);
    function EffectiveTTL(TTLSeconds: Integer): Integer;
    function EstimateSize(const Value: V): Integer;

    function GetCount: Integer;
    function GetMaxSize: Integer;
    procedure SetMaxSize(const Value: Integer);
    function GetMaxMemory: Int64;
    procedure SetMaxMemory(const Value: Int64);
    function GetEvictionPolicy: TEvictionPolicy;
    procedure SetEvictionPolicy(const Value: TEvictionPolicy);
    function GetDefaultTTL: Integer;
    procedure SetDefaultTTL(const Value: Integer);
    procedure SetOnEvict(const Value: TProc<K, V>);
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
    property MaxSize: Integer read GetMaxSize write SetMaxSize;
    property MaxMemory: Int64 read GetMaxMemory write SetMaxMemory;
    property EvictionPolicy: TEvictionPolicy read GetEvictionPolicy write SetEvictionPolicy;
    property DefaultTTL: Integer read GetDefaultTTL write SetDefaultTTL;
    property OnEvict: TProc<K, V> read FOnEvict write SetOnEvict;
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
  private class var
    FInstance: TMemoryTracker;
    FLock: TCriticalSection;
  private
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
    raise EMemoryPoolException.Create('对象池已耗尽');
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
  LPoolable: IPoolable;
  IsValid: Boolean;
begin
  if Obj = nil then
    Exit;

  FLock.Enter;
  try
    Index := FInUse.IndexOf(Obj);
    if Index >= 0 then
    begin
      FInUse.Delete(Index);

      // BUG-110 FIX: 改进对象重置异常处理
      // 验证对象状态，防止损坏的对象进入池
      IsValid := True;
      try
        // 重置对象
        if Assigned(FResetProc) then
          FResetProc(Obj)
        else if Supports(Obj, IPoolable, LPoolable) then
          LPoolable.Reset;
      except
        on E: Exception do
        begin
          IsValid := False;
          // 记录对象重置失败
          if Assigned(UniBase.Logging.Logger) then
            UniBase.Logging.Logger.Warning('Object reset failed, destroying object: ' + E.Message);
        end;
      end;

      // BUG-110 FIX: 重置失败的对象必须被销毁，不能重新入池
      if IsValid and (FPool.Count < FMaxSize) then
        FPool.Add(Obj)
      else
      begin
        // 无论是重置失败还是池已满，都需要销毁对象
        try
          Obj.Free;
        except
          // 忽略销毁时的异常，但记录日志
          on E: Exception do
            if Assigned(UniBase.Logging.Logger) then
              UniBase.Logging.Logger.Warning('Object destruction failed: ' + E.Message);
        end;
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
  FInnerCache := UniBase.Cache.TCache<K, V>.Create;
  FMaxSize := 1000;
  FMaxMemory := 100 * 1024 * 1024; // 100MB
  FEvictionPolicy := epLRU;
  FDefaultTTL := 0; // 不过期
  FPutCount := 0;
  SyncLimitsToInner;
  SyncPolicyToInner;
  FInnerCache.OnEvict := HandleInnerEvict;
  FStatsBaseline := FInnerCache.Stats;
end;

destructor TSmartCache<K, V>.Destroy;
begin
  FInnerCache.Free;
  inherited;
end;

class function TSmartCache<K, V>.ToCacheEvictionPolicy(
  const Value: TEvictionPolicy): UniBase.Cache.TCacheEvictionPolicy;
begin
  case Value of
    epNone: Result := cepNone;
    epLRU: Result := cepLRU;
    epLFU: Result := cepLFU;
    epFIFO: Result := cepFIFO;
    epTTL: Result := cepTTL;
  else
    // epRandom does not have a direct equivalent in UniBase.Cache.
    Result := cepLRU;
  end;
end;

procedure TSmartCache<K, V>.SyncLimitsToInner;
begin
  FInnerCache.MaxItems := FMaxSize;
  FInnerCache.MaxSizeBytes := FMaxMemory;
  FInnerCache.DefaultTTL := FDefaultTTL;
end;

procedure TSmartCache<K, V>.SyncPolicyToInner;
begin
  FInnerCache.EvictionPolicy := ToCacheEvictionPolicy(FEvictionPolicy);
end;

procedure TSmartCache<K, V>.HandleInnerEvict(const Key: K; const Value: V);
begin
  if Assigned(FOnEvict) then
    FOnEvict(Key, Value);
end;

function TSmartCache<K, V>.EffectiveTTL(TTLSeconds: Integer): Integer;
begin
  if TTLSeconds >= 0 then
    Result := TTLSeconds
  else
    Result := FDefaultTTL;
end;

function TSmartCache<K, V>.EstimateSize(const Value: V): Integer;
begin
  Result := SizeOf(V);
  if SizeOf(V) = SizeOf(Pointer) then
    Result := 100;
end;

function TSmartCache<K, V>.GetCount: Integer;
begin
  Result := FInnerCache.Count;
end;

function TSmartCache<K, V>.GetMaxSize: Integer;
begin
  Result := FMaxSize;
end;

procedure TSmartCache<K, V>.SetMaxSize(const Value: Integer);
begin
  if Value < 0 then
    FMaxSize := 0
  else
    FMaxSize := Value;
  SyncLimitsToInner;
end;

function TSmartCache<K, V>.GetMaxMemory: Int64;
begin
  Result := FMaxMemory;
end;

procedure TSmartCache<K, V>.SetMaxMemory(const Value: Int64);
begin
  if Value < 0 then
    FMaxMemory := 0
  else
    FMaxMemory := Value;
  SyncLimitsToInner;
end;

function TSmartCache<K, V>.GetEvictionPolicy: TEvictionPolicy;
begin
  Result := FEvictionPolicy;
end;

procedure TSmartCache<K, V>.SetEvictionPolicy(const Value: TEvictionPolicy);
begin
  FEvictionPolicy := Value;
  SyncPolicyToInner;
end;

function TSmartCache<K, V>.GetDefaultTTL: Integer;
begin
  Result := FDefaultTTL;
end;

procedure TSmartCache<K, V>.SetDefaultTTL(const Value: Integer);
begin
  if Value < 0 then
    FDefaultTTL := 0
  else
    FDefaultTTL := Value;
  SyncLimitsToInner;
end;

procedure TSmartCache<K, V>.SetOnEvict(const Value: TProc<K, V>);
begin
  FOnEvict := Value;
end;

procedure TSmartCache<K, V>.Put(const Key: K; const Value: V; TTLSeconds: Integer);
var
  ItemSize: Int64;
  Keys: TArray<K>;
  Chosen: Integer;
  Stats: UniBase.Cache.TCacheStats;
begin
  try
    ItemSize := EstimateSize(Value);

    if FEvictionPolicy = epNone then
    begin
      if (FMaxSize > 0) and (not FInnerCache.Contains(Key)) and
         (FInnerCache.Count >= FMaxSize) then
        raise EMemoryCacheException.Create('缓存已满');
      if FMaxMemory > 0 then
      begin
        Stats := FInnerCache.Stats;
        if (Stats.TotalSizeBytes + ItemSize > FMaxMemory) and
           (not FInnerCache.Contains(Key)) then
          raise EMemoryCacheException.Create('缓存已满');
      end;
    end;

    if FEvictionPolicy = epRandom then
    begin
      if (FMaxSize > 0) and (not FInnerCache.Contains(Key)) then
      begin
        while FInnerCache.Count >= FMaxSize do
        begin
          Keys := FInnerCache.Keys;
          if Length(Keys) = 0 then
            Break;
          Chosen := Random(Length(Keys));
          FInnerCache.Remove(Keys[Chosen]);
        end;
      end;

      if FMaxMemory > 0 then
      begin
        Stats := FInnerCache.Stats;
        while (Stats.TotalSizeBytes + ItemSize > FMaxMemory) and
              (FInnerCache.Count > 0) do
        begin
          Keys := FInnerCache.Keys;
          if Length(Keys) = 0 then
            Break;
          Chosen := Random(Length(Keys));
          FInnerCache.Remove(Keys[Chosen]);
          Stats := FInnerCache.Stats;
        end;
      end;
    end;
    FInnerCache.Put(Key, Value, EffectiveTTL(TTLSeconds), ItemSize);
    Inc(FPutCount);
  except
    on E: ECacheException do
      raise EMemoryCacheException.Create(E.Message);
  end;
end;

function TSmartCache<K, V>.Get(const Key: K): V;
begin
  if not TryGet(Key, Result) then
    raise EMemoryCacheException.Create('缓存键不存在');
end;

function TSmartCache<K, V>.TryGet(const Key: K; out Value: V): Boolean;
begin
  Result := FInnerCache.TryGet(Key, Value);
end;

function TSmartCache<K, V>.Contains(const Key: K): Boolean;
begin
  Result := FInnerCache.Contains(Key);
end;

function TSmartCache<K, V>.Remove(const Key: K): Boolean;
begin
  Result := FInnerCache.Remove(Key);
end;

procedure TSmartCache<K, V>.Clear;
begin
  FInnerCache.Clear;
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
  Result := FInnerCache.Keys;
end;

function TSmartCache<K, V>.GetStats: TMemoryStats;
var
  Current: UniBase.Cache.TCacheStats;
begin
  Result := Default(TMemoryStats);
  Current := FInnerCache.Stats;

  Result.CacheHits := Current.Hits - FStatsBaseline.Hits;
  Result.CacheMisses := Current.Misses - FStatsBaseline.Misses;
  Result.CurrentUsage := Current.TotalSizeBytes;
  Result.PeakUsage := Current.TotalSizeBytes;
  Result.TotalAllocated := Current.TotalSizeBytes;
  Result.AllocationCount := FPutCount;
  Result.FreeCount :=
    (Current.Evictions + Current.Expirations) -
    (FStatsBaseline.Evictions + FStatsBaseline.Expirations);
end;

procedure TSmartCache<K, V>.ResetStats;
begin
  FStatsBaseline := FInnerCache.Stats;
  FPutCount := 0;
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
var
  NewLock: TCriticalSection;
begin
  // BUG-108 FIX: 修复单例初始化竞态条件
  // 使用双重检查锁定模式，但需要确保锁的创建是线程安全的
  if FInstance = nil then
  begin
    // 使用原子操作确保锁只被创建一次
    if FLock = nil then
    begin
      NewLock := TCriticalSection.Create;
      if TInterlocked.CompareExchange(Pointer(FLock), Pointer(NewLock), nil) <> nil then
        NewLock.Free; // 另一个线程已经创建了锁
    end;

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
  // BUG-102 FIX: 改进弱引用实现 - 添加有效性检查和更清晰的错误处理
  // 注意：这是一个简化的弱引用实现，真正的弱引用需要与对象生命周期管理集成
  if FRef = nil then
    raise EMemoryException.Create('Weak reference target is no longer alive');
  Result := T(FRef);
end;

function TWeakRef<T>.GetIsAlive: Boolean;
begin
  // BUG-102 FIX: 改进弱引用有效性检查
  // 简单的nil检查，实际实现需要更复杂的生命周期跟踪
  Result := FRef <> nil;
  
  // 警告：这是一个简化实现，存在以下限制：
  // 1. 无法检测目标对象是否已被释放（悬空指针风险）
  // 2. 需要与对象的生命周期管理集成才能实现真正的弱引用
  // 3. 建议使用Delphi内置的[weak]属性（如果支持）或实现通知模式
  // 
  // 使用建议：
  // - 在使用Target之前始终调用TryGetTarget
  // - 确保在对象释放时手动清理弱引用
end;

function TWeakRef<T>.TryGetTarget(out Target: T): Boolean;
begin
  Result := FRef <> nil;
  if Result then
    Target := T(FRef)
  else
    Target := Default(T);
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
    // BUG-049 FIX: 加强边界检查，防止索引越界
    if (FCount >= FCapacity) or (FCapacity <= 0) then
      Exit;

    // 确保 FTail 在有效范围内
    if (FTail < 0) or (FTail >= FCapacity) then
      FTail := 0;
      
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
    // BUG-049 FIX: 加强边界检查
    if (FCount = 0) or (FCapacity <= 0) then
      Exit;

    // 确保 FHead 在有效范围内
    if (FHead < 0) or (FHead >= FCapacity) then
      FHead := 0;
      
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
  
  // 防止映射过大的文件（限制为1GB）
  if FFileSize > 1024 * 1024 * 1024 then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
    raise EMemoryException.Create('File too large for memory mapping (max 1GB)');
  end;

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
