{ ============================================================================
  UniBase.Cache - Generic Caching System
  
  A flexible caching system with multiple eviction strategies.
  
  Features:
  - Generic key-value storage
  - LRU (Least Recently Used) eviction
  - TTL (Time To Live) expiration
  - Size-based limits
  - Thread-safe operations
  - Cache statistics
  - Event callbacks (OnEvict, OnExpire)
  
  Usage:
    var Cache := TCache<string, TObject>.Create;
    try
      Cache.MaxItems := 1000;
      Cache.DefaultTTL := 300;  // 5 minutes
      Cache.EvictionPolicy := cepLRU;
      
      Cache.Put('key1', MyObject);
      
      if Cache.TryGet('key1', Value) then
        // Use Value
      else
        // Not in cache
    finally
      Cache.Free;
    end;
  ============================================================================ }

unit UniBase.Cache;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.SyncObjs,
  System.DateUtils,
  System.TimeSpan,
  System.Math,
  System.TypInfo,
  UniBase.Constants;

type
  /// <summary>缓存相关异常</summary>
  ECacheException = class(Exception);
  
  // ============================================================================
  // Eviction Policies
  // ============================================================================
  
  TCacheEvictionPolicy = (
    cepNone,       // No eviction (manual only)
    cepLRU,        // Least Recently Used
    cepLFU,        // Least Frequently Used
    cepFIFO,       // First In First Out
    cepTTL         // Time To Live only
  );
  
  // ============================================================================
  // Cache Entry
  // ============================================================================
  
  TCacheEntry<V> = record
    Value: V;
    CreatedAt: TDateTime;
    LastAccessedAt: TDateTime;
    ExpiresAt: TDateTime;
    AccessCount: Int64;
    SizeBytes: Int64;
    
    function IsExpired: Boolean;
  end;
  
  // ============================================================================
  // Cache Statistics
  // ============================================================================
  
  TCacheStats = record
    Hits: Int64;
    Misses: Int64;
    Evictions: Int64;
    Expirations: Int64;
    CurrentItems: Integer;
    TotalSizeBytes: Int64;
    
    function HitRate: Double;
    function MissRate: Double;
    procedure Reset;
    function ToString: string;
  end;
  
  // ============================================================================
  // Cache Events
  // ============================================================================
  
  TCacheEvictEvent<K, V> = reference to procedure(const Key: K; const Value: V);
  TCacheExpireEvent<K, V> = reference to procedure(const Key: K; const Value: V);
  TCacheLoadEvent<K, V> = reference to function(const Key: K): V;
  
  // ============================================================================
  // Generic Cache
  // ============================================================================
  
  /// <summary>
  /// Thread-safe generic cache with configurable eviction policies
  /// </summary>
  TCache<K, V> = class
  private type
    TEntry = TCacheEntry<V>;
    TEntryDict = TDictionary<K, TEntry>;
    TAccessList = TList<K>;
  private
    FEntries: TEntryDict;
    FAccessOrder: TAccessList;     // For LRU
    FInsertOrder: TQueue<K>;       // For FIFO
    FLock: TCriticalSection;
    
    FMaxItems: Integer;
    FMaxSizeBytes: Int64;
    FDefaultTTL: Integer;          // Seconds, 0 = no expiration
    FEvictionPolicy: TCacheEvictionPolicy;
    FStats: TCacheStats;
    
    FOnEvict: TCacheEvictEvent<K, V>;
    FOnExpire: TCacheExpireEvent<K, V>;
    FOnLoad: TCacheLoadEvent<K, V>;
    FOwnValues: Boolean;
    
    procedure Evict(Count: Integer = 1);
    procedure EvictLRU;
    procedure EvictLFU;
    procedure EvictFIFO;
    procedure RemoveExpired;
    procedure UpdateAccessOrder(const Key: K);
    procedure DoEvict(const Key: K; const Entry: TEntry);
    procedure DoExpire(const Key: K; const Entry: TEntry);
    procedure FreeValueIfOwned(const Value: V);
    function GetCount: Integer;
    function GetKeys: TArray<K>;
  public
    constructor Create(AComparer: IEqualityComparer<K> = nil);
    destructor Destroy; override;
    
    // ========================================================================
    // Core Operations
    // ========================================================================
    
    /// <summary>Add or update item</summary>
    procedure Put(const Key: K; const Value: V); overload;
    procedure Put(const Key: K; const Value: V; TTLSeconds: Integer); overload;
    procedure Put(const Key: K; const Value: V; TTLSeconds: Integer; SizeBytes: Int64); overload;
    
    /// <summary>Get item (returns Default if not found)</summary>
    function Get(const Key: K): V; overload;
    function Get(const Key: K; const Default: V): V; overload;
    
    /// <summary>Try to get item</summary>
    function TryGet(const Key: K; out Value: V): Boolean;
    
    /// <summary>Get or load item using OnLoad callback</summary>
    function GetOrLoad(const Key: K): V;
    
    /// <summary>Check if key exists (and not expired)</summary>
    function Contains(const Key: K): Boolean;
    
    /// <summary>Remove item</summary>
    function Remove(const Key: K): Boolean;
    
    /// <summary>Clear all items</summary>
    procedure Clear;
    
    /// <summary>Remove all expired items</summary>
    procedure Cleanup;
    
    // ========================================================================
    // Batch Operations
    // ========================================================================
    
    /// <summary>Get multiple items</summary>
    function GetMany(const Keys: TArray<K>): TDictionary<K, V>;
    
    /// <summary>Put multiple items</summary>
    procedure PutMany(const Items: TArray<TPair<K, V>>);
    
    /// <summary>Remove multiple items</summary>
    procedure RemoveMany(const Keys: TArray<K>);
    
    // ========================================================================
    // Utility
    // ========================================================================
    
    /// <summary>Get time until expiration (seconds)</summary>
    function GetTTL(const Key: K): Integer;
    
    /// <summary>Update expiration time</summary>
    procedure SetTTL(const Key: K; TTLSeconds: Integer);
    
    /// <summary>Touch item (reset last access time)</summary>
    procedure Touch(const Key: K);
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property MaxItems: Integer read FMaxItems write FMaxItems;
    property MaxSizeBytes: Int64 read FMaxSizeBytes write FMaxSizeBytes;
    property DefaultTTL: Integer read FDefaultTTL write FDefaultTTL;
    property EvictionPolicy: TCacheEvictionPolicy read FEvictionPolicy write FEvictionPolicy;
    property Stats: TCacheStats read FStats;
    property Count: Integer read GetCount;
    property Keys: TArray<K> read GetKeys;
    property OwnValues: Boolean read FOwnValues write FOwnValues;
    
    property OnEvict: TCacheEvictEvent<K, V> read FOnEvict write FOnEvict;
    property OnExpire: TCacheExpireEvent<K, V> read FOnExpire write FOnExpire;
    property OnLoad: TCacheLoadEvent<K, V> read FOnLoad write FOnLoad;
  end;
  
  // ============================================================================
  // Specialized Caches
  // ============================================================================
  
  /// <summary>String-keyed object cache</summary>
  TObjectCache = TCache<string, TObject>;
  
  /// <summary>String-keyed string cache</summary>
  TStringCache = TCache<string, string>;
  
  // ============================================================================
  // Memory Cache (Singleton)
  // ============================================================================
  
  /// <summary>
  /// Global memory cache with string keys and variant values
  /// </summary>
  TMemoryCache = class
  private
    class var FInstance: TCache<string, Variant>;
    class var FLock: TCriticalSection;
    class function GetInstance: TCache<string, Variant>; static;
  public
    class constructor Create;
    class destructor Destroy;
    
    class property Instance: TCache<string, Variant> read GetInstance;
    
    // Convenience methods
    class procedure Put(const Key: string; const Value: Variant; TTLSeconds: Integer = 0);
    class function Get(const Key: string): Variant; overload;
    class function Get(const Key: string; const Default: Variant): Variant; overload;
    class function TryGet(const Key: string; out Value: Variant): Boolean;
    class function Contains(const Key: string): Boolean;
    class procedure Remove(const Key: string);
    class procedure Clear;
  end;

implementation

// ============================================================================
// TCacheEntry<V>
// ============================================================================

function TCacheEntry<V>.IsExpired: Boolean;
begin
  Result := (ExpiresAt > 0) and (Now > ExpiresAt);
end;

// ============================================================================
// TCacheStats
// ============================================================================

function TCacheStats.HitRate: Double;
var
  Total: Int64;
begin
  Total := Hits + Misses;
  if Total > 0 then
    Result := Hits / Total
  else
    Result := 0;
end;

function TCacheStats.MissRate: Double;
begin
  Result := 1 - HitRate;
end;

procedure TCacheStats.Reset;
begin
  Hits := 0;
  Misses := 0;
  Evictions := 0;
  Expirations := 0;
end;

function TCacheStats.ToString: string;
begin
  Result := Format('Items: %d, Hits: %d, Misses: %d, Hit Rate: %.2f%%, ' +
    'Evictions: %d, Expirations: %d, Size: %d bytes',
    [CurrentItems, Hits, Misses, HitRate * 100, Evictions, Expirations, TotalSizeBytes]);
end;

// ============================================================================
// TCache<K, V>
// ============================================================================

constructor TCache<K, V>.Create(AComparer: IEqualityComparer<K>);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  
  if AComparer <> nil then
    FEntries := TEntryDict.Create(AComparer)
  else
    FEntries := TEntryDict.Create;
  
  FAccessOrder := TAccessList.Create;
  FInsertOrder := TQueue<K>.Create;
  
  FMaxItems := DEFAULT_CACHE_MAX_ITEMS;
  FMaxSizeBytes := DEFAULT_CACHE_MAX_SIZE_BYTES;
  FDefaultTTL := 0;    // No expiration
  FEvictionPolicy := cepLRU;
  FOwnValues := False;
  
  FStats.Reset;
end;

destructor TCache<K, V>.Destroy;
begin
  // BUG-047 FIX: 清理回调引用，防止循环引用导致内存泄漏
  FOnEvict := nil;
  FOnExpire := nil;
  FOnLoad := nil;
  
  Clear;
  FreeAndNil(FInsertOrder);
  FreeAndNil(FAccessOrder);
  FreeAndNil(FEntries);
  FreeAndNil(FLock);
  inherited;
end;

function TCache<K, V>.GetCount: Integer;
begin
  FLock.Enter;
  try
    Result := FEntries.Count;
  finally
    FLock.Leave;
  end;
end;

function TCache<K, V>.GetKeys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FEntries.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.Put(const Key: K; const Value: V);
begin
  Put(Key, Value, FDefaultTTL, 0);
end;

procedure TCache<K, V>.Put(const Key: K; const Value: V; TTLSeconds: Integer);
begin
  Put(Key, Value, TTLSeconds, 0);
end;

procedure TCache<K, V>.Put(const Key: K; const Value: V; TTLSeconds: Integer;
  SizeBytes: Int64);
var
  Entry: TEntry;
  OldEntry: TEntry;
begin
  FLock.Enter;
  try
    // 检查单个项目大小限制（防止单个大对象占用过多内存）
    if (FMaxSizeBytes > 0) and (SizeBytes > FMaxSizeBytes div 10) then
      raise ECacheException.CreateFmt('Single item too large: %d bytes (max: %d)', 
        [SizeBytes, FMaxSizeBytes div 10]);
    
    // Check if key already exists
    if FEntries.TryGetValue(Key, OldEntry) then
    begin
      // Update size tracking
      FStats.TotalSizeBytes := FStats.TotalSizeBytes - OldEntry.SizeBytes;
      
      // Free old value if owned
      if FOwnValues then
        FreeValueIfOwned(OldEntry.Value);
    end
    else
    begin
      // New item - check limits
      if (FMaxItems > 0) and (FEntries.Count >= FMaxItems) then
        Evict(1);
      
      // Add to insert order for FIFO
      FInsertOrder.Enqueue(Key);
    end;
    
    // Check memory limit with more aggressive eviction
    if (FMaxSizeBytes > 0) and (FStats.TotalSizeBytes + SizeBytes > FMaxSizeBytes) then
    begin
      // Try to free space by evicting more aggressively
      while (FStats.TotalSizeBytes + SizeBytes > FMaxSizeBytes) and (FEntries.Count > 0) do
        Evict(Max(1, FEntries.Count div 10)); // 每次清理10%的条目
      
      // If still over limit, reject
      if FStats.TotalSizeBytes + SizeBytes > FMaxSizeBytes then
        raise ECacheException.Create('Cache memory limit exceeded');
    end;
    
    // Create entry
    Entry.Value := Value;
    Entry.CreatedAt := Now;
    Entry.LastAccessedAt := Now;
    Entry.AccessCount := 0;
    Entry.SizeBytes := SizeBytes;
    
    if TTLSeconds > 0 then
      Entry.ExpiresAt := IncSecond(Now, TTLSeconds)
    else
      Entry.ExpiresAt := 0;
    
    FEntries.AddOrSetValue(Key, Entry);
    FStats.TotalSizeBytes := FStats.TotalSizeBytes + SizeBytes;
    FStats.CurrentItems := FEntries.Count;
    
    // Update access order for LRU
    UpdateAccessOrder(Key);
      
  finally
    FLock.Leave;
  end;
end;

function TCache<K, V>.Get(const Key: K): V;
begin
  if not TryGet(Key, Result) then
    Result := Default(V);
end;

function TCache<K, V>.Get(const Key: K; const Default: V): V;
begin
  if not TryGet(Key, Result) then
    Result := Default;
end;

function TCache<K, V>.TryGet(const Key: K; out Value: V): Boolean;
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      // Check expiration
      if Entry.IsExpired then
      begin
        DoExpire(Key, Entry);
        FEntries.Remove(Key);
        Inc(FStats.Misses);
        Inc(FStats.Expirations);
        FStats.CurrentItems := FEntries.Count;
        Result := False;
        Exit;
      end;
      
      // Update access info
      Entry.LastAccessedAt := Now;
      Inc(Entry.AccessCount);
      FEntries[Key] := Entry;
      
      UpdateAccessOrder(Key);
      
      Value := Entry.Value;
      Inc(FStats.Hits);
      Result := True;
    end
    else
    begin
      Inc(FStats.Misses);
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

function TCache<K, V>.GetOrLoad(const Key: K): V;
begin
  if not TryGet(Key, Result) then
  begin
    if Assigned(FOnLoad) then
    begin
      Result := FOnLoad(Key);
      Put(Key, Result);
    end
    else
      Result := Default(V);
  end;
end;

function TCache<K, V>.Contains(const Key: K): Boolean;
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      if Entry.IsExpired then
      begin
        DoExpire(Key, Entry);
        FEntries.Remove(Key);
        Inc(FStats.Expirations);
        FStats.CurrentItems := FEntries.Count;
        Result := False;
      end
      else
        Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

function TCache<K, V>.Remove(const Key: K): Boolean;
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      FStats.TotalSizeBytes := FStats.TotalSizeBytes - Entry.SizeBytes;
      
      if FOwnValues then
        FreeValueIfOwned(Entry.Value);
      
      FEntries.Remove(Key);
      FAccessOrder.Remove(Key);
      FStats.CurrentItems := FEntries.Count;
      Result := True;
    end
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.Clear;
var
  Pair: TPair<K, TEntry>;
begin
  FLock.Enter;
  try
    if FOwnValues then
    begin
      for Pair in FEntries do
        FreeValueIfOwned(Pair.Value.Value);
    end;
    
    FEntries.Clear;
    FAccessOrder.Clear;
    FInsertOrder.Clear;
    FStats.CurrentItems := 0;
    FStats.TotalSizeBytes := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.Cleanup;
begin
  FLock.Enter;
  try
    RemoveExpired;
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.Evict(Count: Integer);
var
  I: Integer;
begin
  // Called within lock
  for I := 1 to Count do
  begin
    case FEvictionPolicy of
      cepLRU: EvictLRU;
      cepLFU: EvictLFU;
      cepFIFO: EvictFIFO;
      cepTTL: RemoveExpired;
    else
      EvictLRU;  // Default to LRU
    end;
    
    if FEntries.Count = 0 then
      Break;
  end;
end;

procedure TCache<K, V>.EvictLRU;
var
  Key: K;
  Entry: TEntry;
begin
  if FAccessOrder.Count > 0 then
  begin
    Key := FAccessOrder[0];
    if FEntries.TryGetValue(Key, Entry) then
    begin
      DoEvict(Key, Entry);
      FStats.TotalSizeBytes := FStats.TotalSizeBytes - Entry.SizeBytes;
      
      if FOwnValues then
        FreeValueIfOwned(Entry.Value);
      
      FEntries.Remove(Key);
      Inc(FStats.Evictions);
    end;
    FAccessOrder.Delete(0);
    FStats.CurrentItems := FEntries.Count;
  end;
end;

procedure TCache<K, V>.EvictLFU;
var
  MinKey: K;
  MinCount: Int64;
  Pair: TPair<K, TEntry>;
  Entry: TEntry;
  Found: Boolean;
begin
  MinCount := High(Int64);
  Found := False;
  MinKey := Default(K);
  
  for Pair in FEntries do
  begin
    if Pair.Value.AccessCount < MinCount then
    begin
      MinCount := Pair.Value.AccessCount;
      MinKey := Pair.Key;
      Found := True;
    end;
  end;
  
  if Found and FEntries.TryGetValue(MinKey, Entry) then
  begin
    DoEvict(MinKey, Entry);
    FStats.TotalSizeBytes := FStats.TotalSizeBytes - Entry.SizeBytes;
    
    if FOwnValues then
      FreeValueIfOwned(Entry.Value);
    
    FEntries.Remove(MinKey);
    FAccessOrder.Remove(MinKey);
    Inc(FStats.Evictions);
    FStats.CurrentItems := FEntries.Count;
  end;
end;

procedure TCache<K, V>.EvictFIFO;
var
  Key: K;
  Entry: TEntry;
begin
  while FInsertOrder.Count > 0 do
  begin
    Key := FInsertOrder.Dequeue;
    if FEntries.TryGetValue(Key, Entry) then
    begin
      DoEvict(Key, Entry);
      FStats.TotalSizeBytes := FStats.TotalSizeBytes - Entry.SizeBytes;
      
      if FOwnValues then
        FreeValueIfOwned(Entry.Value);
      
      FEntries.Remove(Key);
      FAccessOrder.Remove(Key);
      Inc(FStats.Evictions);
      FStats.CurrentItems := FEntries.Count;
      Break;
    end;
  end;
end;

procedure TCache<K, V>.RemoveExpired;
var
  Pair: TPair<K, TEntry>;
  ExpiredKeys: TList<K>;
  Key: K;
  Entry: TEntry;
begin
  ExpiredKeys := TList<K>.Create;
  try
    for Pair in FEntries do
      if Pair.Value.IsExpired then
        ExpiredKeys.Add(Pair.Key);
    
    for Key in ExpiredKeys do
    begin
      if FEntries.TryGetValue(Key, Entry) then
      begin
        DoExpire(Key, Entry);
        FStats.TotalSizeBytes := FStats.TotalSizeBytes - Entry.SizeBytes;
        
        if FOwnValues then
          FreeValueIfOwned(Entry.Value);
        
        FEntries.Remove(Key);
        FAccessOrder.Remove(Key);
        Inc(FStats.Expirations);
      end;
    end;
    
    FStats.CurrentItems := FEntries.Count;
  finally
    ExpiredKeys.Free;
  end;
end;

procedure TCache<K, V>.UpdateAccessOrder(const Key: K);
var
  Idx: Integer;
begin
  // Called within lock
  Idx := FAccessOrder.IndexOf(Key);
  if Idx >= 0 then
    FAccessOrder.Delete(Idx);
  FAccessOrder.Add(Key);
end;

procedure TCache<K, V>.DoEvict(const Key: K; const Entry: TEntry);
begin
  if Assigned(FOnEvict) then
    FOnEvict(Key, Entry.Value);
end;

procedure TCache<K, V>.DoExpire(const Key: K; const Entry: TEntry);
begin
  if Assigned(FOnExpire) then
    FOnExpire(Key, Entry.Value);
end;

procedure TCache<K, V>.FreeValueIfOwned(const Value: V);
var
  LObj: TObject;
begin
  // Safely free object values in generic context
  // Only process class types to avoid invalid memory access
  if GetTypeKind(V) = tkClass then
  begin
    // Use PPointer for safe type punning in generics
    LObj := PPointer(@Value)^;
    if LObj <> nil then
      LObj.Free;
  end;
end;

function TCache<K, V>.GetMany(const Keys: TArray<K>): TDictionary<K, V>;
var
  Key: K;
  Value: V;
begin
  Result := TDictionary<K, V>.Create;
  for Key in Keys do
    if TryGet(Key, Value) then
      Result.Add(Key, Value);
end;

procedure TCache<K, V>.PutMany(const Items: TArray<TPair<K, V>>);
var
  Item: TPair<K, V>;
begin
  for Item in Items do
    Put(Item.Key, Item.Value);
end;

procedure TCache<K, V>.RemoveMany(const Keys: TArray<K>);
var
  Key: K;
begin
  for Key in Keys do
    Remove(Key);
end;

function TCache<K, V>.GetTTL(const Key: K): Integer;
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      if Entry.ExpiresAt > 0 then
        Result := SecondsBetween(Now, Entry.ExpiresAt)
      else
        Result := -1;  // No expiration
    end
    else
      Result := 0;  // Not found
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.SetTTL(const Key: K; TTLSeconds: Integer);
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      if TTLSeconds > 0 then
        Entry.ExpiresAt := IncSecond(Now, TTLSeconds)
      else
        Entry.ExpiresAt := 0;
      FEntries[Key] := Entry;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCache<K, V>.Touch(const Key: K);
var
  Entry: TEntry;
begin
  FLock.Enter;
  try
    if FEntries.TryGetValue(Key, Entry) then
    begin
      Entry.LastAccessedAt := Now;
      FEntries[Key] := Entry;
      UpdateAccessOrder(Key);
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TMemoryCache
// ============================================================================

class constructor TMemoryCache.Create;
begin
  FLock := TCriticalSection.Create;
  FInstance := nil;
end;

class destructor TMemoryCache.Destroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FLock);
end;

class function TMemoryCache.GetInstance: TCache<string, Variant>;
begin
  if FInstance = nil then
  begin
    FLock.Enter;
    try
      if FInstance = nil then
      begin
        FInstance := TCache<string, Variant>.Create;
        FInstance.MaxItems := DEFAULT_CACHE_MAX_ITEMS;
        FInstance.DefaultTTL := DEFAULT_CACHE_TTL_SECONDS;
        FInstance.EvictionPolicy := cepLRU;
      end;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TMemoryCache.Put(const Key: string; const Value: Variant;
  TTLSeconds: Integer);
begin
  Instance.Put(Key, Value, TTLSeconds);
end;

class function TMemoryCache.Get(const Key: string): Variant;
begin
  Result := Instance.Get(Key);
end;

class function TMemoryCache.Get(const Key: string; const Default: Variant): Variant;
begin
  Result := Instance.Get(Key, Default);
end;

class function TMemoryCache.TryGet(const Key: string; out Value: Variant): Boolean;
begin
  Result := Instance.TryGet(Key, Value);
end;

class function TMemoryCache.Contains(const Key: string): Boolean;
begin
  Result := Instance.Contains(Key);
end;

class procedure TMemoryCache.Remove(const Key: string);
begin
  Instance.Remove(Key);
end;

class procedure TMemoryCache.Clear;
begin
  Instance.Clear;
end;

end.
