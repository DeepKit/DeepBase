unit DeepBase.Collections;

{*******************************************************************************
  DeepBase Extended Collections
  A comprehensive collection of advanced data structures:
  - TSortedList<T> - Sorted list with binary search
  - TCircularBuffer<T> - Fixed-size circular/ring buffer
  - TLRUCache<K,V> - Least Recently Used cache
  - TBidiDictionary<K,V> - Bidirectional dictionary
  - TMultiMap<K,V> - Dictionary with multiple values per key
  - TOrderedDictionary<K,V> - Insertion-order preserving dictionary
  - TDeque<T> - Double-ended queue
  - TCountingSet<T> - Set with element counts
  
  Author: DeepBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Generics.Defaults, System.SyncObjs, System.Math;

type
  ECollectionException = class(Exception);

  /// <summary>Sorted list with binary search</summary>
  TSortedList<T> = class
  private
    FItems: TList<T>;
    FComparer: IComparer<T>;
    FDuplicates: TDuplicates;
    
    function BinarySearch(const AItem: T; out AIndex: Integer): Boolean;
    function GetItem(AIndex: Integer): T;
  public
    constructor Create; overload;
    constructor Create(AComparer: IComparer<T>); overload;
    destructor Destroy; override;
    
    function Add(const AItem: T): Integer;
    procedure Delete(AIndex: Integer);
    function Remove(const AItem: T): Boolean;
    function Contains(const AItem: T): Boolean;
    function IndexOf(const AItem: T): Integer;
    procedure Clear;
    
    function First: T;
    function Last: T;
    function GetRange(AStart, ACount: Integer): TArray<T>;
    
    function ToArray: TArray<T>;
    function GetEnumerator: TEnumerator<T>;
    
    function Count: Integer;
    function IsEmpty: Boolean;
    
    property Items[AIndex: Integer]: T read GetItem; default;
    property Duplicates: TDuplicates read FDuplicates write FDuplicates;
  end;

  /// <summary>Fixed-size circular buffer</summary>
  TCircularBuffer<T> = class
  private
    FItems: array of T;
    FCapacity: Integer;
    FHead: Integer;
    FTail: Integer;
    FCount: Integer;
    FLock: TCriticalSection;
    
    function GetItem(AIndex: Integer): T;
  public
    constructor Create(ACapacity: Integer);
    destructor Destroy; override;
    
    procedure Push(const AItem: T);
    function Pop: T;
    function TryPop(out AItem: T): Boolean;
    function Peek: T;
    function TryPeek(out AItem: T): Boolean;
    
    procedure Clear;
    function ToArray: TArray<T>;
    
    function IsFull: Boolean;
    function IsEmpty: Boolean;
    
    property Items[AIndex: Integer]: T read GetItem; default;
    property Count: Integer read FCount;
    property Capacity: Integer read FCapacity;
  end;

  /// <summary>LRU cache entry</summary>
  TLRUCacheEntry<K,V> = record
    Key: K;
    Value: V;
    Prev: ^TLRUCacheEntry<K,V>;
    Next: ^TLRUCacheEntry<K,V>;
  end;

  /// <summary>Least Recently Used cache</summary>
  TLRUCache<K,V> = class
  private
    FCapacity: Integer;
    FMap: TDictionary<K, V>;
    FKeys: TList<K>;  // Order list (most recent at end)
    FLock: TCriticalSection;
    FOnEvict: TProc<K, V>;
    
    procedure MoveToEnd(const AKey: K);
    procedure Evict;
  public
    constructor Create(ACapacity: Integer);
    destructor Destroy; override;
    
    procedure Put(const AKey: K; const AValue: V);
    function Get(const AKey: K): V;
    function TryGet(const AKey: K; out AValue: V): Boolean;
    function Contains(const AKey: K): Boolean;
    procedure Remove(const AKey: K);
    procedure Clear;
    
    function Count: Integer;
    function IsFull: Boolean;
    function Keys: TArray<K>;
    
    property Capacity: Integer read FCapacity;
    property OnEvict: TProc<K, V> read FOnEvict write FOnEvict;
  end;

  /// <summary>Bidirectional dictionary (key-value and value-key lookup)</summary>
  TBidiDictionary<K,V> = class
  private
    FForward: TDictionary<K, V>;
    FReverse: TDictionary<V, K>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Add(const AKey: K; const AValue: V);
    procedure Remove(const AKey: K);
    procedure RemoveValue(const AValue: V);
    procedure Clear;
    
    function ContainsKey(const AKey: K): Boolean;
    function ContainsValue(const AValue: V): Boolean;
    
    function GetValue(const AKey: K): V;
    function GetKey(const AValue: V): K;
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function TryGetKey(const AValue: V; out AKey: K): Boolean;
    
    function Count: Integer;
    function Keys: TArray<K>;
    function Values: TArray<V>;
  end;

  /// <summary>Dictionary with multiple values per key</summary>
  TMultiMap<K,V> = class
  private
    FMap: TDictionary<K, TList<V>>;
    FKeyComparer: IEqualityComparer<K>;
    FLock: TCriticalSection;
  public
    constructor Create; overload;
    constructor Create(AKeyComparer: IEqualityComparer<K>); overload;
    destructor Destroy; override;
    
    procedure Add(const AKey: K; const AValue: V);
    procedure AddRange(const AKey: K; const AValues: array of V);
    procedure Remove(const AKey: K; const AValue: V);
    procedure RemoveKey(const AKey: K);
    procedure Clear;
    
    function Contains(const AKey: K; const AValue: V): Boolean;
    function ContainsKey(const AKey: K): Boolean;
    
    function GetValues(const AKey: K): TArray<V>;
    function TryGetValues(const AKey: K; out AValues: TArray<V>): Boolean;
    
    function KeyCount: Integer;
    function ValueCount: Integer;
    function ValueCountFor(const AKey: K): Integer;
    
    function Keys: TArray<K>;
    function AllValues: TArray<V>;
  end;

  /// <summary>Insertion-order preserving dictionary</summary>
  TOrderedDictionary<K,V> = class
  private
    FMap: TDictionary<K, V>;
    FKeys: TList<K>;
    FLock: TCriticalSection;
    
    function GetItem(const AKey: K): V;
    procedure SetItem(const AKey: K; const AValue: V);
    function GetItemByIndex(AIndex: Integer): TPair<K, V>;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Add(const AKey: K; const AValue: V);
    procedure AddOrSet(const AKey: K; const AValue: V);
    procedure Remove(const AKey: K);
    procedure Clear;
    
    function ContainsKey(const AKey: K): Boolean;
    function TryGetValue(const AKey: K; out AValue: V): Boolean;
    function IndexOf(const AKey: K): Integer;
    
    function First: TPair<K, V>;
    function Last: TPair<K, V>;
    
    function Count: Integer;
    function Keys: TArray<K>;
    function Values: TArray<V>;
    function ToArray: TArray<TPair<K, V>>;
    
    property Items[const AKey: K]: V read GetItem write SetItem; default;
    property ItemsByIndex[AIndex: Integer]: TPair<K, V> read GetItemByIndex;
  end;

  /// <summary>Double-ended queue</summary>
  TDeque<T> = class
  private
    FItems: TList<T>;
    FLock: TCriticalSection;
    
    function GetItem(AIndex: Integer): T;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure PushFront(const AItem: T);
    procedure PushBack(const AItem: T);
    function PopFront: T;
    function PopBack: T;
    function TryPopFront(out AItem: T): Boolean;
    function TryPopBack(out AItem: T): Boolean;
    
    function PeekFront: T;
    function PeekBack: T;
    function TryPeekFront(out AItem: T): Boolean;
    function TryPeekBack(out AItem: T): Boolean;
    
    procedure Clear;
    function ToArray: TArray<T>;
    
    function Count: Integer;
    function IsEmpty: Boolean;
    
    property Items[AIndex: Integer]: T read GetItem; default;
  end;

  /// <summary>Set with element counts (multiset/bag)</summary>
  TCountingSet<T> = class
  private
    FCounts: TDictionary<T, Integer>;
    FTotalCount: Integer;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Add(const AItem: T; ACount: Integer = 1);
    procedure Remove(const AItem: T; ACount: Integer = 1);
    procedure RemoveAll(const AItem: T);
    procedure Clear;
    
    function Contains(const AItem: T): Boolean;
    function CountOf(const AItem: T): Integer;
    
    function UniqueCount: Integer;
    function TotalCount: Integer;
    
    function MostCommon(ACount: Integer = 10): TArray<TPair<T, Integer>>;
    function Items: TArray<T>;
    function ToArray: TArray<TPair<T, Integer>>;
  end;

  /// <summary>Stack with min/max tracking</summary>
  TMinMaxStack<T> = class
  private
    FItems: TStack<T>;
    FMinStack: TStack<T>;
    FMaxStack: TStack<T>;
    FComparer: IComparer<T>;
    FLock: TCriticalSection;
  public
    constructor Create; overload;
    constructor Create(AComparer: IComparer<T>); overload;
    destructor Destroy; override;
    
    procedure Push(const AItem: T);
    function Pop: T;
    function Peek: T;
    function TryPop(out AItem: T): Boolean;
    function TryPeek(out AItem: T): Boolean;
    
    function Min: T;
    function Max: T;
    function TryGetMin(out AItem: T): Boolean;
    function TryGetMax(out AItem: T): Boolean;
    
    procedure Clear;
    function Count: Integer;
    function IsEmpty: Boolean;
  end;

  /// <summary>Thread-safe blocking queue</summary>
  TBlockingQueue<T> = class
  private
    FItems: TList<T>;
    FLock: TCriticalSection;
    FNotEmpty: TEvent;
    FMaxSize: Integer;
  public
    constructor Create(AMaxSize: Integer = 0);
    destructor Destroy; override;
    
    procedure Enqueue(const AItem: T);
    function Dequeue: T;
    function TryDequeue(out AItem: T; ATimeoutMs: Cardinal = 0): Boolean;
    function Peek: T;
    function TryPeek(out AItem: T): Boolean;
    
    procedure Clear;
    function Count: Integer;
    function IsEmpty: Boolean;
    function IsFull: Boolean;
    
    property MaxSize: Integer read FMaxSize;
  end;

  /// <summary>Interval/Range</summary>
  TInterval<T> = record
    Start: T;
    Stop: T;
    
    constructor Create(AStart, AStop: T);
    function Contains(const AValue: T; AComparer: IComparer<T>): Boolean;
    function Overlaps(const AOther: TInterval<T>; AComparer: IComparer<T>): Boolean;
  end;

  /// <summary>Collections static helper</summary>
  TCollections = class
  public
    /// <summary>Create sorted list</summary>
    class function SortedList<T>: TSortedList<T>; static;
    
    /// <summary>Create circular buffer</summary>
    class function CircularBuffer<T>(ACapacity: Integer): TCircularBuffer<T>; static;
    
    /// <summary>Create LRU cache</summary>
    class function LRUCache<K,V>(ACapacity: Integer): TLRUCache<K,V>; static;
    
    /// <summary>Create bidirectional dictionary</summary>
    class function BidiDict<K,V>: TBidiDictionary<K,V>; static;
    
    /// <summary>Create multi-map</summary>
    class function MultiMap<K,V>: TMultiMap<K,V>; static;
    
    /// <summary>Create ordered dictionary</summary>
    class function OrderedDict<K,V>: TOrderedDictionary<K,V>; static;
    
    /// <summary>Create deque</summary>
    class function Deque<T>: TDeque<T>; static;
    
    /// <summary>Create counting set</summary>
    class function CountingSet<T>: TCountingSet<T>; static;
    
    /// <summary>Create blocking queue</summary>
    class function BlockingQueue<T>(AMaxSize: Integer = 0): TBlockingQueue<T>; static;
  end;

implementation

{ TSortedList<T> }

constructor TSortedList<T>.Create;
begin
  Create(TComparer<T>.Default);
end;

constructor TSortedList<T>.Create(AComparer: IComparer<T>);
begin
  inherited Create;
  FItems := TList<T>.Create;
  FComparer := AComparer;
  FDuplicates := dupAccept;
end;

destructor TSortedList<T>.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

function TSortedList<T>.BinarySearch(const AItem: T; out AIndex: Integer): Boolean;
var
  L, H: Integer;
begin
  Result := False;
  L := 0;
  H := FItems.Count - 1;
  
  while L <= H do
  begin
    var M := (L + H) shr 1;
    var C := FComparer.Compare(FItems[M], AItem);

    if C = 0 then
    begin
      AIndex := M;
      Exit(True);
    end;

    L := if C < 0 then M + 1 else L;
    H := if C > 0 then M - 1 else H;
  end;
  
  AIndex := L;
end;

function TSortedList<T>.GetItem(AIndex: Integer): T;
begin
  Result := FItems[AIndex];
end;

function TSortedList<T>.Add(const AItem: T): Integer;
var
  LIndex: Integer;
begin
  if BinarySearch(AItem, LIndex) then
  begin
    case FDuplicates of
      dupIgnore: Exit(LIndex);
      dupError: raise ECollectionException.Create('Duplicate item');
    end;
  end;
  
  FItems.Insert(LIndex, AItem);
  Result := LIndex;
end;

procedure TSortedList<T>.Delete(AIndex: Integer);
begin
  FItems.Delete(AIndex);
end;

function TSortedList<T>.Remove(const AItem: T): Boolean;
var
  LIndex: Integer;
begin
  Result := BinarySearch(AItem, LIndex);
  if Result then
    FItems.Delete(LIndex);
end;

function TSortedList<T>.Contains(const AItem: T): Boolean;
var
  LIndex: Integer;
begin
  Result := BinarySearch(AItem, LIndex);
end;

function TSortedList<T>.IndexOf(const AItem: T): Integer;
begin
  if not BinarySearch(AItem, Result) then
    Result := -1;
end;

procedure TSortedList<T>.Clear;
begin
  FItems.Clear;
end;

function TSortedList<T>.First: T;
begin
  if FItems.Count = 0 then
    raise ECollectionException.Create('List is empty');
  Result := FItems[0];
end;

function TSortedList<T>.Last: T;
begin
  if FItems.Count = 0 then
    raise ECollectionException.Create('List is empty');
  Result := FItems[FItems.Count - 1];
end;

function TSortedList<T>.GetRange(AStart, ACount: Integer): TArray<T>;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := FItems[AStart + I];
end;

function TSortedList<T>.ToArray: TArray<T>;
begin
  Result := FItems.ToArray;
end;

function TSortedList<T>.GetEnumerator: TEnumerator<T>;
begin
  Result := FItems.GetEnumerator;
end;

function TSortedList<T>.Count: Integer;
begin
  Result := FItems.Count;
end;

function TSortedList<T>.IsEmpty: Boolean;
begin
  Result := FItems.Count = 0;
end;

{ TCircularBuffer<T> }

constructor TCircularBuffer<T>.Create(ACapacity: Integer);
begin
  inherited Create;
  FCapacity := ACapacity;
  SetLength(FItems, ACapacity);
  FHead := 0;
  FTail := 0;
  FCount := 0;
  FLock := TCriticalSection.Create;
end;

destructor TCircularBuffer<T>.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TCircularBuffer<T>.GetItem(AIndex: Integer): T;
begin
  FLock.Enter;
  try
    if (AIndex < 0) or (AIndex >= FCount) then
      raise ECollectionException.Create('Index out of bounds');
    Result := FItems[(FHead + AIndex) mod FCapacity];
  finally
    FLock.Leave;
  end;
end;

procedure TCircularBuffer<T>.Push(const AItem: T);
begin
  FLock.Enter;
  try
    FItems[FTail] := AItem;
    FTail := (FTail + 1) mod FCapacity;
    
    if FCount = FCapacity then
      // Overwrite oldest
      FHead := (FHead + 1) mod FCapacity
    else
      Inc(FCount);
  finally
    FLock.Leave;
  end;
end;

function TCircularBuffer<T>.Pop: T;
begin
  if not TryPop(Result) then
    raise ECollectionException.Create('Buffer is empty');
end;

function TCircularBuffer<T>.TryPop(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FCount > 0;
    if Result then
    begin
      AItem := FItems[FHead];
      FHead := (FHead + 1) mod FCapacity;
      Dec(FCount);
    end;
  finally
    FLock.Leave;
  end;
end;

function TCircularBuffer<T>.Peek: T;
begin
  if not TryPeek(Result) then
    raise ECollectionException.Create('Buffer is empty');
end;

function TCircularBuffer<T>.TryPeek(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FCount > 0;
    if Result then
      AItem := FItems[FHead];
  finally
    FLock.Leave;
  end;
end;

procedure TCircularBuffer<T>.Clear;
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

function TCircularBuffer<T>.ToArray: TArray<T>;
var
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FCount);
    for I := 0 to FCount - 1 do
      Result[I] := FItems[(FHead + I) mod FCapacity];
  finally
    FLock.Leave;
  end;
end;

function TCircularBuffer<T>.IsFull: Boolean;
begin
  FLock.Enter;
  try
    Result := FCount = FCapacity;
  finally
    FLock.Leave;
  end;
end;

function TCircularBuffer<T>.IsEmpty: Boolean;
begin
  FLock.Enter;
  try
    Result := FCount = 0;
  finally
    FLock.Leave;
  end;
end;

{ TLRUCache<K,V> }

constructor TLRUCache<K,V>.Create(ACapacity: Integer);
begin
  inherited Create;
  FCapacity := ACapacity;
  FMap := TDictionary<K, V>.Create;
  FKeys := TList<K>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TLRUCache<K,V>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FKeys);
  FreeAndNil(FMap);
  inherited;
end;

procedure TLRUCache<K,V>.MoveToEnd(const AKey: K);
var
  I: Integer;
begin
  for I := 0 to FKeys.Count - 1 do
  begin
    if TComparer<K>.Default.Compare(FKeys[I], AKey) = 0 then
    begin
      FKeys.Delete(I);
      FKeys.Add(AKey);
      Exit;
    end;
  end;
end;

procedure TLRUCache<K,V>.Evict;
var
  LKey: K;
  LValue: V;
begin
  if FKeys.Count > 0 then
  begin
    LKey := FKeys[0];
    if FMap.TryGetValue(LKey, LValue) then
    begin
      FMap.Remove(LKey);
      FKeys.Delete(0);
      
      if Assigned(FOnEvict) then
        FOnEvict(LKey, LValue);
    end;
  end;
end;

procedure TLRUCache<K,V>.Put(const AKey: K; const AValue: V);
begin
  FLock.Enter;
  try
    if FMap.ContainsKey(AKey) then
    begin
      FMap[AKey] := AValue;
      MoveToEnd(AKey);
    end
    else
    begin
      if FMap.Count >= FCapacity then
        Evict;
        
      FMap.Add(AKey, AValue);
      FKeys.Add(AKey);
    end;
  finally
    FLock.Leave;
  end;
end;

function TLRUCache<K,V>.Get(const AKey: K): V;
begin
  if not TryGet(AKey, Result) then
    raise ECollectionException.Create('Key not found');
end;

function TLRUCache<K,V>.TryGet(const AKey: K; out AValue: V): Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.TryGetValue(AKey, AValue);
    if Result then
      MoveToEnd(AKey);
  finally
    FLock.Leave;
  end;
end;

function TLRUCache<K,V>.Contains(const AKey: K): Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.ContainsKey(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TLRUCache<K,V>.Remove(const AKey: K);
var
  I: Integer;
begin
  FLock.Enter;
  try
    FMap.Remove(AKey);
    for I := FKeys.Count - 1 downto 0 do
    begin
      if TComparer<K>.Default.Compare(FKeys[I], AKey) = 0 then
      begin
        FKeys.Delete(I);
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLRUCache<K,V>.Clear;
begin
  FLock.Enter;
  try
    FMap.Clear;
    FKeys.Clear;
  finally
    FLock.Leave;
  end;
end;

function TLRUCache<K,V>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FMap.Count;
  finally
    FLock.Leave;
  end;
end;

function TLRUCache<K,V>.IsFull: Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.Count >= FCapacity;
  finally
    FLock.Leave;
  end;
end;

function TLRUCache<K,V>.Keys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FKeys.ToArray;
  finally
    FLock.Leave;
  end;
end;

{ TBidiDictionary<K,V> }

constructor TBidiDictionary<K,V>.Create;
begin
  inherited Create;
  FForward := TDictionary<K, V>.Create;
  FReverse := TDictionary<V, K>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TBidiDictionary<K,V>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FReverse);
  FreeAndNil(FForward);
  inherited;
end;

procedure TBidiDictionary<K,V>.Add(const AKey: K; const AValue: V);
begin
  FLock.Enter;
  try
    if FForward.ContainsKey(AKey) then
      raise ECollectionException.Create('Duplicate key');
    if FReverse.ContainsKey(AValue) then
      raise ECollectionException.Create('Duplicate value');
      
    FForward.Add(AKey, AValue);
    FReverse.Add(AValue, AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TBidiDictionary<K,V>.Remove(const AKey: K);
var
  LValue: V;
begin
  FLock.Enter;
  try
    if FForward.TryGetValue(AKey, LValue) then
    begin
      FForward.Remove(AKey);
      FReverse.Remove(LValue);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TBidiDictionary<K,V>.RemoveValue(const AValue: V);
var
  LKey: K;
begin
  FLock.Enter;
  try
    if FReverse.TryGetValue(AValue, LKey) then
    begin
      FReverse.Remove(AValue);
      FForward.Remove(LKey);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TBidiDictionary<K,V>.Clear;
begin
  FLock.Enter;
  try
    FForward.Clear;
    FReverse.Clear;
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.ContainsKey(const AKey: K): Boolean;
begin
  FLock.Enter;
  try
    Result := FForward.ContainsKey(AKey);
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.ContainsValue(const AValue: V): Boolean;
begin
  FLock.Enter;
  try
    Result := FReverse.ContainsKey(AValue);
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.GetValue(const AKey: K): V;
begin
  FLock.Enter;
  try
    Result := FForward[AKey];
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.GetKey(const AValue: V): K;
begin
  FLock.Enter;
  try
    Result := FReverse[AValue];
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.TryGetValue(const AKey: K; out AValue: V): Boolean;
begin
  FLock.Enter;
  try
    Result := FForward.TryGetValue(AKey, AValue);
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.TryGetKey(const AValue: V; out AKey: K): Boolean;
begin
  FLock.Enter;
  try
    Result := FReverse.TryGetValue(AValue, AKey);
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FForward.Count;
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.Keys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FForward.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TBidiDictionary<K,V>.Values: TArray<V>;
begin
  FLock.Enter;
  try
    Result := FForward.Values.ToArray;
  finally
    FLock.Leave;
  end;
end;

{ TMultiMap<K,V> }

constructor TMultiMap<K,V>.Create;
begin
  Create(nil);
end;

constructor TMultiMap<K,V>.Create(AKeyComparer: IEqualityComparer<K>);
begin
  inherited Create;
  FKeyComparer := AKeyComparer;
  if FKeyComparer = nil then
    FMap := TDictionary<K, TList<V>>.Create
  else
    FMap := TDictionary<K, TList<V>>.Create(FKeyComparer);
  FLock := TCriticalSection.Create;
end;

destructor TMultiMap<K,V>.Destroy;
var
  LList: TList<V>;
begin
  for LList in FMap.Values do
    LList.Free;
  FreeAndNil(FMap);
  FreeAndNil(FLock);
  inherited;
end;

procedure TMultiMap<K,V>.Add(const AKey: K; const AValue: V);
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    if not FMap.TryGetValue(AKey, LList) then
    begin
      LList := TList<V>.Create;
      FMap.Add(AKey, LList);
    end;
    LList.Add(AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TMultiMap<K,V>.AddRange(const AKey: K; const AValues: array of V);
var
  LValue: V;
begin
  for LValue in AValues do
    Add(AKey, LValue);
end;

procedure TMultiMap<K,V>.Remove(const AKey: K; const AValue: V);
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AKey, LList) then
    begin
      LList.Remove(AValue);
      if LList.Count = 0 then
      begin
        LList.Free;
        FMap.Remove(AKey);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMultiMap<K,V>.RemoveKey(const AKey: K);
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AKey, LList) then
    begin
      LList.Free;
      FMap.Remove(AKey);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMultiMap<K,V>.Clear;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    for LList in FMap.Values do
      LList.Free;
    FMap.Clear;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.Contains(const AKey: K; const AValue: V): Boolean;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    Result := FMap.TryGetValue(AKey, LList) and LList.Contains(AValue);
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.ContainsKey(const AKey: K): Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.ContainsKey(AKey);
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.GetValues(const AKey: K): TArray<V>;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AKey, LList) then
      Result := LList.ToArray
    else
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.TryGetValues(const AKey: K; out AValues: TArray<V>): Boolean;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    Result := FMap.TryGetValue(AKey, LList);
    if Result then
      AValues := LList.ToArray
    else
      AValues := nil;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.KeyCount: Integer;
begin
  FLock.Enter;
  try
    Result := FMap.Count;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.ValueCount: Integer;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    Result := 0;
    for LList in FMap.Values do
      Inc(Result, LList.Count);
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.ValueCountFor(const AKey: K): Integer;
var
  LList: TList<V>;
begin
  FLock.Enter;
  try
    if FMap.TryGetValue(AKey, LList) then
      Result := LList.Count
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.Keys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FMap.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TMultiMap<K,V>.AllValues: TArray<V>;
var
  LResult: TList<V>;
  LList: TList<V>;
begin
  FLock.Enter;
  try
    LResult := TList<V>.Create;
    try
      for LList in FMap.Values do
        LResult.AddRange(LList.ToArray);
      Result := LResult.ToArray;
    finally
      LResult.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TOrderedDictionary<K,V> }

constructor TOrderedDictionary<K,V>.Create;
begin
  inherited Create;
  FMap := TDictionary<K, V>.Create;
  FKeys := TList<K>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TOrderedDictionary<K,V>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FKeys);
  FreeAndNil(FMap);
  inherited;
end;

function TOrderedDictionary<K,V>.GetItem(const AKey: K): V;
begin
  FLock.Enter;
  try
    Result := FMap[AKey];
  finally
    FLock.Leave;
  end;
end;

procedure TOrderedDictionary<K,V>.SetItem(const AKey: K; const AValue: V);
begin
  AddOrSet(AKey, AValue);
end;

function TOrderedDictionary<K,V>.GetItemByIndex(AIndex: Integer): TPair<K, V>;
begin
  FLock.Enter;
  try
    Result.Key := FKeys[AIndex];
    Result.Value := FMap[Result.Key];
  finally
    FLock.Leave;
  end;
end;

procedure TOrderedDictionary<K,V>.Add(const AKey: K; const AValue: V);
begin
  FLock.Enter;
  try
    if FMap.ContainsKey(AKey) then
      raise ECollectionException.Create('Duplicate key');
    FMap.Add(AKey, AValue);
    FKeys.Add(AKey);
  finally
    FLock.Leave;
  end;
end;

procedure TOrderedDictionary<K,V>.AddOrSet(const AKey: K; const AValue: V);
begin
  FLock.Enter;
  try
    if not FMap.ContainsKey(AKey) then
      FKeys.Add(AKey);
    FMap.AddOrSetValue(AKey, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TOrderedDictionary<K,V>.Remove(const AKey: K);
var
  I: Integer;
begin
  FLock.Enter;
  try
    FMap.Remove(AKey);
    for I := FKeys.Count - 1 downto 0 do
    begin
      if TComparer<K>.Default.Compare(FKeys[I], AKey) = 0 then
      begin
        FKeys.Delete(I);
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TOrderedDictionary<K,V>.Clear;
begin
  FLock.Enter;
  try
    FMap.Clear;
    FKeys.Clear;
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.ContainsKey(const AKey: K): Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.ContainsKey(AKey);
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.TryGetValue(const AKey: K; out AValue: V): Boolean;
begin
  FLock.Enter;
  try
    Result := FMap.TryGetValue(AKey, AValue);
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.IndexOf(const AKey: K): Integer;
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := 0 to FKeys.Count - 1 do
    begin
      if TComparer<K>.Default.Compare(FKeys[I], AKey) = 0 then
        Exit(I);
    end;
    Result := -1;
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.First: TPair<K, V>;
begin
  FLock.Enter;
  try
    if FKeys.Count = 0 then
      raise ECollectionException.Create('Dictionary is empty');
    Result.Key := FKeys[0];
    Result.Value := FMap[Result.Key];
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.Last: TPair<K, V>;
begin
  FLock.Enter;
  try
    if FKeys.Count = 0 then
      raise ECollectionException.Create('Dictionary is empty');
    Result.Key := FKeys[FKeys.Count - 1];
    Result.Value := FMap[Result.Key];
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FMap.Count;
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.Keys: TArray<K>;
begin
  FLock.Enter;
  try
    Result := FKeys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.Values: TArray<V>;
var
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FKeys.Count);
    for I := 0 to FKeys.Count - 1 do
      Result[I] := FMap[FKeys[I]];
  finally
    FLock.Leave;
  end;
end;

function TOrderedDictionary<K,V>.ToArray: TArray<TPair<K, V>>;
var
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FKeys.Count);
    for I := 0 to FKeys.Count - 1 do
    begin
      Result[I].Key := FKeys[I];
      Result[I].Value := FMap[FKeys[I]];
    end;
  finally
    FLock.Leave;
  end;
end;

{ TDeque<T> }

constructor TDeque<T>.Create;
begin
  inherited Create;
  FItems := TList<T>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TDeque<T>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FItems);
  inherited;
end;

function TDeque<T>.GetItem(AIndex: Integer): T;
begin
  FLock.Enter;
  try
    Result := FItems[AIndex];
  finally
    FLock.Leave;
  end;
end;

procedure TDeque<T>.PushFront(const AItem: T);
begin
  FLock.Enter;
  try
    FItems.Insert(0, AItem);
  finally
    FLock.Leave;
  end;
end;

procedure TDeque<T>.PushBack(const AItem: T);
begin
  FLock.Enter;
  try
    FItems.Add(AItem);
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.PopFront: T;
begin
  if not TryPopFront(Result) then
    raise ECollectionException.Create('Deque is empty');
end;

function TDeque<T>.PopBack: T;
begin
  if not TryPopBack(Result) then
    raise ECollectionException.Create('Deque is empty');
end;

function TDeque<T>.TryPopFront(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
    begin
      AItem := FItems[0];
      FItems.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.TryPopBack(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
    begin
      AItem := FItems[FItems.Count - 1];
      FItems.Delete(FItems.Count - 1);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.PeekFront: T;
begin
  if not TryPeekFront(Result) then
    raise ECollectionException.Create('Deque is empty');
end;

function TDeque<T>.PeekBack: T;
begin
  if not TryPeekBack(Result) then
    raise ECollectionException.Create('Deque is empty');
end;

function TDeque<T>.TryPeekFront(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
      AItem := FItems[0];
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.TryPeekBack(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
      AItem := FItems[FItems.Count - 1];
  finally
    FLock.Leave;
  end;
end;

procedure TDeque<T>.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.ToArray: TArray<T>;
begin
  FLock.Enter;
  try
    Result := FItems.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FItems.Count;
  finally
    FLock.Leave;
  end;
end;

function TDeque<T>.IsEmpty: Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count = 0;
  finally
    FLock.Leave;
  end;
end;

{ TCountingSet<T> }

constructor TCountingSet<T>.Create;
begin
  inherited Create;
  FCounts := TDictionary<T, Integer>.Create;
  FTotalCount := 0;
  FLock := TCriticalSection.Create;
end;

destructor TCountingSet<T>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FCounts);
  inherited;
end;

procedure TCountingSet<T>.Add(const AItem: T; ACount: Integer);
var
  LCurrent: Integer;
begin
  FLock.Enter;
  try
    if FCounts.TryGetValue(AItem, LCurrent) then
      FCounts[AItem] := LCurrent + ACount
    else
      FCounts.Add(AItem, ACount);
    Inc(FTotalCount, ACount);
  finally
    FLock.Leave;
  end;
end;

procedure TCountingSet<T>.Remove(const AItem: T; ACount: Integer);
var
  LCurrent: Integer;
begin
  FLock.Enter;
  try
    if FCounts.TryGetValue(AItem, LCurrent) then
    begin
      if LCurrent <= ACount then
      begin
        Dec(FTotalCount, LCurrent);
        FCounts.Remove(AItem);
      end
      else
      begin
        FCounts[AItem] := LCurrent - ACount;
        Dec(FTotalCount, ACount);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCountingSet<T>.RemoveAll(const AItem: T);
var
  LCurrent: Integer;
begin
  FLock.Enter;
  try
    if FCounts.TryGetValue(AItem, LCurrent) then
    begin
      Dec(FTotalCount, LCurrent);
      FCounts.Remove(AItem);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCountingSet<T>.Clear;
begin
  FLock.Enter;
  try
    FCounts.Clear;
    FTotalCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.Contains(const AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FCounts.ContainsKey(AItem);
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.CountOf(const AItem: T): Integer;
begin
  FLock.Enter;
  try
    if not FCounts.TryGetValue(AItem, Result) then
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.UniqueCount: Integer;
begin
  FLock.Enter;
  try
    Result := FCounts.Count;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.TotalCount: Integer;
begin
  FLock.Enter;
  try
    Result := FTotalCount;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.MostCommon(ACount: Integer): TArray<TPair<T, Integer>>;
var
  LList: TList<TPair<T, Integer>>;
  LPair: TPair<T, Integer>;
begin
  FLock.Enter;
  try
    LList := TList<TPair<T, Integer>>.Create;
    try
      for LPair in FCounts do
        LList.Add(LPair);
        
      LList.Sort(TComparer<TPair<T, Integer>>.Construct(
        function(const A, B: TPair<T, Integer>): Integer
        begin
          Result := B.Value - A.Value; // Descending
        end));
        
      if ACount > LList.Count then
        ACount := LList.Count;
        
      SetLength(Result, ACount);
      for var I := 0 to ACount - 1 do
        Result[I] := LList[I];
    finally
      LList.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.Items: TArray<T>;
begin
  FLock.Enter;
  try
    Result := FCounts.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TCountingSet<T>.ToArray: TArray<TPair<T, Integer>>;
var
  LList: TList<TPair<T, Integer>>;
  LPair: TPair<T, Integer>;
begin
  FLock.Enter;
  try
    LList := TList<TPair<T, Integer>>.Create;
    try
      for LPair in FCounts do
        LList.Add(LPair);
      Result := LList.ToArray;
    finally
      LList.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TMinMaxStack<T> }

constructor TMinMaxStack<T>.Create;
begin
  Create(TComparer<T>.Default);
end;

constructor TMinMaxStack<T>.Create(AComparer: IComparer<T>);
begin
  inherited Create;
  FComparer := AComparer;
  FItems := TStack<T>.Create;
  FMinStack := TStack<T>.Create;
  FMaxStack := TStack<T>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TMinMaxStack<T>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FMaxStack);
  FreeAndNil(FMinStack);
  FreeAndNil(FItems);
  inherited;
end;

procedure TMinMaxStack<T>.Push(const AItem: T);
begin
  FLock.Enter;
  try
    FItems.Push(AItem);
    
    if (FMinStack.Count = 0) or (FComparer.Compare(AItem, FMinStack.Peek) <= 0) then
      FMinStack.Push(AItem);
      
    if (FMaxStack.Count = 0) or (FComparer.Compare(AItem, FMaxStack.Peek) >= 0) then
      FMaxStack.Push(AItem);
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.Pop: T;
begin
  if not TryPop(Result) then
    raise ECollectionException.Create('Stack is empty');
end;

function TMinMaxStack<T>.Peek: T;
begin
  if not TryPeek(Result) then
    raise ECollectionException.Create('Stack is empty');
end;

function TMinMaxStack<T>.TryPop(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
    begin
      AItem := FItems.Pop;
      
      if FComparer.Compare(AItem, FMinStack.Peek) = 0 then
        FMinStack.Pop;
        
      if FComparer.Compare(AItem, FMaxStack.Peek) = 0 then
        FMaxStack.Pop;
    end;
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.TryPeek(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
      AItem := FItems.Peek;
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.Min: T;
begin
  if not TryGetMin(Result) then
    raise ECollectionException.Create('Stack is empty');
end;

function TMinMaxStack<T>.Max: T;
begin
  if not TryGetMax(Result) then
    raise ECollectionException.Create('Stack is empty');
end;

function TMinMaxStack<T>.TryGetMin(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FMinStack.Count > 0;
    if Result then
      AItem := FMinStack.Peek;
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.TryGetMax(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FMaxStack.Count > 0;
    if Result then
      AItem := FMaxStack.Peek;
  finally
    FLock.Leave;
  end;
end;

procedure TMinMaxStack<T>.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    FMinStack.Clear;
    FMaxStack.Clear;
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FItems.Count;
  finally
    FLock.Leave;
  end;
end;

function TMinMaxStack<T>.IsEmpty: Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count = 0;
  finally
    FLock.Leave;
  end;
end;

{ TBlockingQueue<T> }

constructor TBlockingQueue<T>.Create(AMaxSize: Integer);
begin
  inherited Create;
  FMaxSize := AMaxSize;
  FItems := TList<T>.Create;
  FLock := TCriticalSection.Create;
  FNotEmpty := TEvent.Create(nil, True, False, '');
end;

destructor TBlockingQueue<T>.Destroy;
begin
  FreeAndNil(FNotEmpty);
  FreeAndNil(FLock);
  FreeAndNil(FItems);
  inherited;
end;

procedure TBlockingQueue<T>.Enqueue(const AItem: T);
begin
  FLock.Enter;
  try
    if (FMaxSize > 0) and (FItems.Count >= FMaxSize) then
      raise ECollectionException.Create('Queue is full');
      
    FItems.Add(AItem);
    FNotEmpty.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TBlockingQueue<T>.Dequeue: T;
begin
  if not TryDequeue(Result, INFINITE) then
    raise ECollectionException.Create('Queue is empty');
end;

function TBlockingQueue<T>.TryDequeue(out AItem: T; ATimeoutMs: Cardinal): Boolean;
var
  LDeadline: TDateTime;
  LRemainingMs: Cardinal;
begin
  LDeadline := 0;
  if (ATimeoutMs > 0) and (ATimeoutMs <> INFINITE) then
    LDeadline := Now + (ATimeoutMs / MSecsPerDay);

  while True do
  begin
    FLock.Enter;
    try
      if FItems.Count > 0 then
      begin
        AItem := FItems[0];
        FItems.Delete(0);
        if FItems.Count = 0 then
          FNotEmpty.ResetEvent;
        Exit(True);
      end;

      // Queue empty — exit if timeout already elapsed
      if ATimeoutMs = 0 then
        Exit(False);

      if ATimeoutMs <> INFINITE then
      begin
        LRemainingMs := Max(1, Cardinal(Round((LDeadline - Now) * MSecsPerDay)));
        if LRemainingMs = 0 then
          Exit(False);
      end;
    finally
      FLock.Leave;
    end;

    // Wait outside the lock for producer signal
    if ATimeoutMs = INFINITE then
      FNotEmpty.WaitFor(INFINITE)
    else
      FNotEmpty.WaitFor(LRemainingMs);
  end;
end;

function TBlockingQueue<T>.Peek: T;
begin
  if not TryPeek(Result) then
    raise ECollectionException.Create('Queue is empty');
end;

function TBlockingQueue<T>.TryPeek(out AItem: T): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count > 0;
    if Result then
      AItem := FItems[0];
  finally
    FLock.Leave;
  end;
end;

procedure TBlockingQueue<T>.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    FNotEmpty.ResetEvent;
  finally
    FLock.Leave;
  end;
end;

function TBlockingQueue<T>.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FItems.Count;
  finally
    FLock.Leave;
  end;
end;

function TBlockingQueue<T>.IsEmpty: Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.Count = 0;
  finally
    FLock.Leave;
  end;
end;

function TBlockingQueue<T>.IsFull: Boolean;
begin
  FLock.Enter;
  try
    Result := (FMaxSize > 0) and (FItems.Count >= FMaxSize);
  finally
    FLock.Leave;
  end;
end;

{ TInterval<T> }

constructor TInterval<T>.Create(AStart, AStop: T);
begin
  Start := AStart;
  Stop := AStop;
end;

function TInterval<T>.Contains(const AValue: T; AComparer: IComparer<T>): Boolean;
begin
  Result := (AComparer.Compare(AValue, Start) >= 0) and (AComparer.Compare(AValue, Stop) <= 0);
end;

function TInterval<T>.Overlaps(const AOther: TInterval<T>; AComparer: IComparer<T>): Boolean;
begin
  Result := (AComparer.Compare(Start, AOther.Stop) <= 0) and (AComparer.Compare(Stop, AOther.Start) >= 0);
end;

{ TCollections }

class function TCollections.SortedList<T>: TSortedList<T>;
begin
  Result := TSortedList<T>.Create;
end;

class function TCollections.CircularBuffer<T>(ACapacity: Integer): TCircularBuffer<T>;
begin
  Result := TCircularBuffer<T>.Create(ACapacity);
end;

class function TCollections.LRUCache<K,V>(ACapacity: Integer): TLRUCache<K,V>;
begin
  Result := TLRUCache<K,V>.Create(ACapacity);
end;

class function TCollections.BidiDict<K,V>: TBidiDictionary<K,V>;
begin
  Result := TBidiDictionary<K,V>.Create;
end;

class function TCollections.MultiMap<K,V>: TMultiMap<K,V>;
begin
  Result := TMultiMap<K,V>.Create;
end;

class function TCollections.OrderedDict<K,V>: TOrderedDictionary<K,V>;
begin
  Result := TOrderedDictionary<K,V>.Create;
end;

class function TCollections.Deque<T>: TDeque<T>;
begin
  Result := TDeque<T>.Create;
end;

class function TCollections.CountingSet<T>: TCountingSet<T>;
begin
  Result := TCountingSet<T>.Create;
end;

class function TCollections.BlockingQueue<T>(AMaxSize: Integer): TBlockingQueue<T>;
begin
  Result := TBlockingQueue<T>.Create(AMaxSize);
end;

end.
