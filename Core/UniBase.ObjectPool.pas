unit UniBase.ObjectPool;

{*******************************************************************************
  UniBase Object Pool
  A generic object pooling system with:
  - Type-safe generic pool
  - Configurable min/max pool size
  - Idle object timeout and cleanup
  - Factory pattern for object creation
  - Validation before reuse
  - Pool statistics and monitoring
  - Thread-safe operations
  - Automatic pool expansion/shrinking
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.DateUtils, System.Threading, System.Math;

type
  EObjectPoolException = class(Exception);

  /// <summary>Pool statistics</summary>
  TPoolStats = record
    TotalCreated: Integer;
    TotalDestroyed: Integer;
    CurrentPoolSize: Integer;
    CurrentInUse: Integer;
    CurrentIdle: Integer;
    TotalAcquires: Int64;
    TotalReleases: Int64;
    TotalTimeouts: Int64;
    TotalValidationFails: Int64;
    AverageWaitTimeMs: Double;
    PeakUsage: Integer;
    
    procedure Reset;
  end;

  /// <summary>Pooled object wrapper</summary>
  TPooledObject<T: class> = class
  private
    FObject: T;
    FCreatedAt: TDateTime;
    FLastUsedAt: TDateTime;
    FUseCount: Integer;
    FInUse: Boolean;
  public
    constructor Create(AObject: T);
    destructor Destroy; override;
    
    procedure MarkUsed;
    procedure MarkReturned;
    
    property Obj: T read FObject;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastUsedAt: TDateTime read FLastUsedAt;
    property UseCount: Integer read FUseCount;
    property InUse: Boolean read FInUse;
  end;

  /// <summary>Object factory interface</summary>
  IObjectFactory<T: class> = interface
    ['{E1F2A3B4-5678-9ABC-DEF0-123456789ABC}']
    function CreateObject: T;
    procedure DestroyObject(AObject: T);
    function ValidateObject(AObject: T): Boolean;
    procedure ResetObject(AObject: T);
  end;

  /// <summary>Default factory using parameterless constructor</summary>
  TDefaultObjectFactory<T: class, constructor> = class(TInterfacedObject, IObjectFactory<T>)
  public
    function CreateObject: T;
    procedure DestroyObject(AObject: T);
    function ValidateObject(AObject: T): Boolean;
    procedure ResetObject(AObject: T);
  end;

  /// <summary>Callback-based factory</summary>
  TCallbackObjectFactory<T: class> = class(TInterfacedObject, IObjectFactory<T>)
  private
    FOnCreate: TFunc<T>;
    FOnDestroy: TProc<T>;
    FOnValidate: TFunc<T, Boolean>;
    FOnReset: TProc<T>;
  public
    constructor Create(
      AOnCreate: TFunc<T>;
      AOnDestroy: TProc<T> = nil;
      AOnValidate: TFunc<T, Boolean> = nil;
      AOnReset: TProc<T> = nil
    );
    
    function CreateObject: T;
    procedure DestroyObject(AObject: T);
    function ValidateObject(AObject: T): Boolean;
    procedure ResetObject(AObject: T);
  end;

  /// <summary>Pool configuration</summary>
  TPoolConfig = record
    MinSize: Integer;
    MaxSize: Integer;
    IdleTimeoutSec: Integer;
    AcquireTimeoutMs: Integer;
    ValidationOnAcquire: Boolean;
    ValidationOnRelease: Boolean;
    CleanupIntervalSec: Integer;
    GrowthFactor: Double;
    
    class function Default: TPoolConfig; static;
  end;

  /// <summary>Pool events</summary>
  TPoolEvent<T: class> = reference to procedure(Sender: TObject; AObject: T);
  TPoolValidationEvent<T: class> = reference to procedure(Sender: TObject; AObject: T; var AValid: Boolean);

  /// <summary>Generic object pool</summary>
  TObjectPool<T: class> = class
  private
    FFactory: IObjectFactory<T>;
    FConfig: TPoolConfig;
    FPool: TObjectList<TPooledObject<T>>;
    FLock: TCriticalSection;
    FAvailable: TEvent;
    FShutdownEvent: TEvent;
    FStats: TPoolStats;
    FShutdown: Boolean;
    FCleanupTask: ITask;
    
    FOnObjectCreated: TPoolEvent<T>;
    FOnObjectDestroyed: TPoolEvent<T>;
    FOnObjectAcquired: TPoolEvent<T>;
    FOnObjectReleased: TPoolEvent<T>;
    FOnValidation: TPoolValidationEvent<T>;
    
    procedure Initialize;
    procedure CleanupIdleObjects;
    procedure EnsureMinSize;
    function FindAvailableObject: TPooledObject<T>;
    function CreatePooledObject: TPooledObject<T>;
    procedure DestroyPooledObject(APooled: TPooledObject<T>);
    function GetCurrentSize: Integer;
    function GetIdleCount: Integer;
    function GetInUseCount: Integer;
  public
    constructor Create(AFactory: IObjectFactory<T>); overload;
    constructor Create(AFactory: IObjectFactory<T>; const AConfig: TPoolConfig); overload;
    destructor Destroy; override;
    
    /// <summary>Acquire object from pool</summary>
    function Acquire: T; overload;
    function Acquire(ATimeoutMs: Integer): T; overload;
    
    /// <summary>Try to acquire object</summary>
    function TryAcquire(out AObject: T): Boolean; overload;
    function TryAcquire(out AObject: T; ATimeoutMs: Integer): Boolean; overload;
    
    /// <summary>Release object back to pool</summary>
    procedure Release(AObject: T);

    /// <summary>Discard a broken object from the pool</summary>
    procedure Discard(AObject: T);
    
    /// <summary>Clear all objects from pool</summary>
    procedure Clear;
    
    /// <summary>Shrink pool to minimum size</summary>
    procedure Shrink;
    
    /// <summary>Pre-warm pool with objects</summary>
    procedure Warm(ACount: Integer);
    
    /// <summary>Get pool statistics</summary>
    function GetStats: TPoolStats;
    
    /// <summary>Reset statistics</summary>
    procedure ResetStats;
    
    property Config: TPoolConfig read FConfig write FConfig;
    property CurrentSize: Integer read GetCurrentSize;
    property IdleCount: Integer read GetIdleCount;
    property InUseCount: Integer read GetInUseCount;
    property Factory: IObjectFactory<T> read FFactory;
    
    property OnObjectCreated: TPoolEvent<T> read FOnObjectCreated write FOnObjectCreated;
    property OnObjectDestroyed: TPoolEvent<T> read FOnObjectDestroyed write FOnObjectDestroyed;
    property OnObjectAcquired: TPoolEvent<T> read FOnObjectAcquired write FOnObjectAcquired;
    property OnObjectReleased: TPoolEvent<T> read FOnObjectReleased write FOnObjectReleased;
    property OnValidation: TPoolValidationEvent<T> read FOnValidation write FOnValidation;
  end;

  /// <summary>Scoped pool object - automatically returns to pool</summary>
  IScopedPoolObject<T: class> = interface
    ['{F1E2D3C4-5678-9ABC-DEF0-123456789ABC}']
    function GetObject: T;
    property Obj: T read GetObject;
  end;

  TScopedPoolObject<T: class> = class(TInterfacedObject, IScopedPoolObject<T>)
  private
    FPool: TObjectPool<T>;
    FObject: T;
    function GetObject: T;
  public
    constructor Create(APool: TObjectPool<T>; AObject: T);
    destructor Destroy; override;
    property Obj: T read GetObject;
  end;

  /// <summary>Keyed object pool - multiple pools by key</summary>
  TKeyedObjectPool<TKey; T: class> = class
  private
    FPools: TObjectDictionary<TKey, TObjectPool<T>>;
    FFactory: IObjectFactory<T>;
    FConfig: TPoolConfig;
    FLock: TCriticalSection;
  public
    constructor Create(AFactory: IObjectFactory<T>); overload;
    constructor Create(AFactory: IObjectFactory<T>; const AConfig: TPoolConfig); overload;
    destructor Destroy; override;
    
    /// <summary>Acquire object for key</summary>
    function Acquire(const AKey: TKey): T;
    
    /// <summary>Release object for key</summary>
    procedure Release(const AKey: TKey; AObject: T);
    
    /// <summary>Get pool for key</summary>
    function GetPool(const AKey: TKey): TObjectPool<T>;
    
    /// <summary>Clear specific key pool</summary>
    procedure ClearKey(const AKey: TKey);
    
    /// <summary>Clear all pools</summary>
    procedure ClearAll;
    
    property Config: TPoolConfig read FConfig write FConfig;
  end;

  /// <summary>Pool manager for named pools</summary>
  TPoolManager = class
  private
    class var FInstance: TPoolManager;
    class var FLock: TCriticalSection;
    
    FPools: TDictionary<string, TObject>;
    FPoolLock: TCriticalSection;
  public
    class constructor Create;
    class destructor Destroy;
    class function Instance: TPoolManager;
    
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Register a pool</summary>
    procedure RegisterPool<T: class>(const AName: string; APool: TObjectPool<T>);
    
    /// <summary>Get pool by name</summary>
    function GetPool<T: class>(const AName: string): TObjectPool<T>;
    
    /// <summary>Check if pool exists</summary>
    function HasPool(const AName: string): Boolean;
    
    /// <summary>Unregister pool</summary>
    procedure UnregisterPool(const AName: string);
    
    /// <summary>Clear all pools</summary>
    procedure ClearAll;
  end;

  /// <summary>Pool builder</summary>
  TPoolBuilder<T: class> = class
  private
    FFactory: IObjectFactory<T>;
    FConfig: TPoolConfig;
    FOnCreate: TFunc<T>;
    FOnDestroy: TProc<T>;
    FOnValidate: TFunc<T, Boolean>;
    FOnReset: TProc<T>;
  public
    constructor Create;
    
    function WithFactory(AFactory: IObjectFactory<T>): TPoolBuilder<T>;
    function WithCreator(AOnCreate: TFunc<T>): TPoolBuilder<T>;
    function WithDestructor(AOnDestroy: TProc<T>): TPoolBuilder<T>;
    function WithValidator(AOnValidate: TFunc<T, Boolean>): TPoolBuilder<T>;
    function WithReset(AOnReset: TProc<T>): TPoolBuilder<T>;
    function WithMinSize(ASize: Integer): TPoolBuilder<T>;
    function WithMaxSize(ASize: Integer): TPoolBuilder<T>;
    function WithIdleTimeout(ASeconds: Integer): TPoolBuilder<T>;
    function WithAcquireTimeout(AMilliseconds: Integer): TPoolBuilder<T>;
    function WithValidationOnAcquire(AEnabled: Boolean = True): TPoolBuilder<T>;
    function WithValidationOnRelease(AEnabled: Boolean = True): TPoolBuilder<T>;
    function WithCleanupInterval(ASeconds: Integer): TPoolBuilder<T>;
    function WithGrowthFactor(AFactor: Double): TPoolBuilder<T>;
    
    function Build: TObjectPool<T>;
  end;

  /// <summary>Static helper class</summary>
  TObjectPools = class
  public
    /// <summary>Create pool with default factory</summary>
    class function CreatePool<T: class, constructor>: TObjectPool<T>; overload;
    class function CreatePool<T: class, constructor>(const AConfig: TPoolConfig): TObjectPool<T>; overload;
    
    /// <summary>Create pool with custom creator</summary>
    class function CreatePool<T: class>(ACreator: TFunc<T>): TObjectPool<T>; overload;
    
    /// <summary>Create pool builder</summary>
    class function Pool<T: class>: TPoolBuilder<T>;
    
    /// <summary>Global pool manager</summary>
    class function Manager: TPoolManager;
  end;

implementation

{ TPoolStats }

procedure TPoolStats.Reset;
begin
  TotalCreated := 0;
  TotalDestroyed := 0;
  CurrentPoolSize := 0;
  CurrentInUse := 0;
  CurrentIdle := 0;
  TotalAcquires := 0;
  TotalReleases := 0;
  TotalTimeouts := 0;
  TotalValidationFails := 0;
  AverageWaitTimeMs := 0;
  PeakUsage := 0;
end;

{ TPooledObject<T> }

constructor TPooledObject<T>.Create(AObject: T);
begin
  inherited Create;
  FObject := AObject;
  FCreatedAt := Now;
  FLastUsedAt := Now;
  FUseCount := 0;
  FInUse := False;
end;

destructor TPooledObject<T>.Destroy;
begin
  // Object is destroyed by the pool
  inherited;
end;

procedure TPooledObject<T>.MarkUsed;
begin
  FLastUsedAt := Now;
  Inc(FUseCount);
  FInUse := True;
end;

procedure TPooledObject<T>.MarkReturned;
begin
  FLastUsedAt := Now;
  FInUse := False;
end;

{ TDefaultObjectFactory<T> }

function TDefaultObjectFactory<T>.CreateObject: T;
begin
  Result := T.Create;
end;

procedure TDefaultObjectFactory<T>.DestroyObject(AObject: T);
begin
  AObject.Free;
end;

function TDefaultObjectFactory<T>.ValidateObject(AObject: T): Boolean;
begin
  Result := Assigned(AObject);
end;

procedure TDefaultObjectFactory<T>.ResetObject(AObject: T);
begin
  // Default implementation does nothing
end;

{ TCallbackObjectFactory<T> }

constructor TCallbackObjectFactory<T>.Create(
  AOnCreate: TFunc<T>;
  AOnDestroy: TProc<T>;
  AOnValidate: TFunc<T, Boolean>;
  AOnReset: TProc<T>
);
begin
  inherited Create;
  FOnCreate := AOnCreate;
  FOnDestroy := AOnDestroy;
  FOnValidate := AOnValidate;
  FOnReset := AOnReset;
end;

function TCallbackObjectFactory<T>.CreateObject: T;
begin
  if Assigned(FOnCreate) then
    Result := FOnCreate()
  else
    raise EObjectPoolException.Create('No creator callback defined');
end;

procedure TCallbackObjectFactory<T>.DestroyObject(AObject: T);
begin
  if Assigned(FOnDestroy) then
    FOnDestroy(AObject)
  else
    AObject.Free;
end;

function TCallbackObjectFactory<T>.ValidateObject(AObject: T): Boolean;
begin
  if Assigned(FOnValidate) then
    Result := FOnValidate(AObject)
  else
    Result := Assigned(AObject);
end;

procedure TCallbackObjectFactory<T>.ResetObject(AObject: T);
begin
  if Assigned(FOnReset) then
    FOnReset(AObject);
end;

{ TPoolConfig }

class function TPoolConfig.Default: TPoolConfig;
begin
  Result.MinSize := 0;
  Result.MaxSize := 20;
  Result.IdleTimeoutSec := 300; // 5 minutes
  Result.AcquireTimeoutMs := 30000; // 30 seconds
  Result.ValidationOnAcquire := True;
  Result.ValidationOnRelease := False;
  Result.CleanupIntervalSec := 60; // 1 minute
  Result.GrowthFactor := 2.0;
end;

{ TObjectPool<T> }

constructor TObjectPool<T>.Create(AFactory: IObjectFactory<T>);
begin
  Create(AFactory, TPoolConfig.Default);
end;

constructor TObjectPool<T>.Create(AFactory: IObjectFactory<T>; const AConfig: TPoolConfig);
begin
  inherited Create;
  FFactory := AFactory;
  FConfig := AConfig;
  FPool := TObjectList<TPooledObject<T>>.Create(True);
  FLock := TCriticalSection.Create;
  FAvailable := TEvent.Create(nil, True, False, '');
  FShutdownEvent := TEvent.Create(nil, True, False, '');
  FStats.Reset;
  FShutdown := False;
  
  Initialize;
end;

destructor TObjectPool<T>.Destroy;
begin
  FShutdown := True;
  if Assigned(FShutdownEvent) then
    FShutdownEvent.SetEvent;
  
  // Wait for cleanup task
  if Assigned(FCleanupTask) then
  begin
    FCleanupTask.Cancel;
    try
      FCleanupTask.Wait;
    except
      // Shutdown must continue even if a background cleanup task is cancelled.
    end;
    FCleanupTask := nil;
  end;
  
  Clear;
  
  FreeAndNil(FShutdownEvent);
  FreeAndNil(FAvailable);
  FreeAndNil(FLock);
  FreeAndNil(FPool);
  inherited;
end;

procedure TObjectPool<T>.Initialize;
begin
  // Create minimum objects
  EnsureMinSize;
  
  // Start cleanup task
  if FConfig.CleanupIntervalSec > 0 then
  begin
    FCleanupTask := TTask.Create(
      procedure
      var
        LWaitResult: TWaitResult;
      begin
        while not FShutdown do
        begin
          LWaitResult := FShutdownEvent.WaitFor(FConfig.CleanupIntervalSec * 1000);
          if (LWaitResult = wrTimeout) and not FShutdown then
            CleanupIdleObjects;
        end;
      end
    );
    FCleanupTask.Start;
  end;
end;

procedure TObjectPool<T>.EnsureMinSize;
var
  LCount: Integer;
begin
  FLock.Enter;
  try
    LCount := FPool.Count;
    while LCount < FConfig.MinSize do
    begin
      FPool.Add(CreatePooledObject);
      Inc(LCount);
    end;
    
    if FPool.Count > 0 then
      FAvailable.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.CreatePooledObject: TPooledObject<T>;
var
  LObj: T;
begin
  LObj := FFactory.CreateObject;
  Result := TPooledObject<T>.Create(LObj);
  
  Inc(FStats.TotalCreated);
  Inc(FStats.CurrentPoolSize);
  Inc(FStats.CurrentIdle);
  
  if Assigned(FOnObjectCreated) then
    FOnObjectCreated(Self, LObj);
end;

procedure TObjectPool<T>.DestroyPooledObject(APooled: TPooledObject<T>);
begin
  if Assigned(FOnObjectDestroyed) then
    FOnObjectDestroyed(Self, APooled.Obj);
    
  FFactory.DestroyObject(APooled.Obj);
  
  Inc(FStats.TotalDestroyed);
  Dec(FStats.CurrentPoolSize);
  if not APooled.InUse then
    Dec(FStats.CurrentIdle)
  else
    Dec(FStats.CurrentInUse);
end;

function TObjectPool<T>.FindAvailableObject: TPooledObject<T>;
var
  I: Integer;
  LPooled: TPooledObject<T>;
  LValid: Boolean;
begin
  Result := nil;
  
  for I := 0 to FPool.Count - 1 do
  begin
    LPooled := FPool[I];
    if not LPooled.InUse then
    begin
      // Validate if configured
      if FConfig.ValidationOnAcquire then
      begin
        LValid := FFactory.ValidateObject(LPooled.Obj);
        
        if Assigned(FOnValidation) then
          FOnValidation(Self, LPooled.Obj, LValid);
          
        if not LValid then
        begin
          Inc(FStats.TotalValidationFails);
          // Remove invalid object
          DestroyPooledObject(LPooled);
          FPool.Delete(I);
          Continue;
        end;
      end;
      
      Result := LPooled;
      Break;
    end;
  end;
end;

function TObjectPool<T>.Acquire: T;
begin
  Result := Acquire(FConfig.AcquireTimeoutMs);
end;

function TObjectPool<T>.Acquire(ATimeoutMs: Integer): T;
begin
  if not TryAcquire(Result, ATimeoutMs) then
    raise EObjectPoolException.Create('Failed to acquire object from pool: timeout');
end;

function TObjectPool<T>.TryAcquire(out AObject: T): Boolean;
begin
  Result := TryAcquire(AObject, FConfig.AcquireTimeoutMs);
end;

function TObjectPool<T>.TryAcquire(out AObject: T; ATimeoutMs: Integer): Boolean;
var
  LPooled: TPooledObject<T>;
  LStartTime: TDateTime;
  LWaitResult: TWaitResult;
  LElapsedMs: Int64;
begin
  Result := False;
  AObject := nil;
  LStartTime := Now;
  
  while True do
  begin
    FLock.Enter;
    try
      // Try to find available object
      LPooled := FindAvailableObject;
      
      if Assigned(LPooled) then
      begin
        LPooled.MarkUsed;
        FFactory.ResetObject(LPooled.Obj);
        AObject := LPooled.Obj;
        
        Inc(FStats.TotalAcquires);
        Dec(FStats.CurrentIdle);
        Inc(FStats.CurrentInUse);
        
        if FStats.CurrentInUse > FStats.PeakUsage then
          FStats.PeakUsage := FStats.CurrentInUse;
        
        // Update average wait time
        LElapsedMs := MilliSecondsBetween(Now, LStartTime);
        FStats.AverageWaitTimeMs := 
          (FStats.AverageWaitTimeMs * (FStats.TotalAcquires - 1) + LElapsedMs) / FStats.TotalAcquires;
        
        if Assigned(FOnObjectAcquired) then
          FOnObjectAcquired(Self, AObject);
          
        Result := True;
        Exit;
      end;
      
      // Try to create new object if under max
      if FPool.Count < FConfig.MaxSize then
      begin
        LPooled := CreatePooledObject;
        FPool.Add(LPooled);
        
        LPooled.MarkUsed;
        Dec(FStats.CurrentIdle);
        Inc(FStats.CurrentInUse);
        
        FFactory.ResetObject(LPooled.Obj);
        AObject := LPooled.Obj;
        
        Inc(FStats.TotalAcquires);
        
        if FStats.CurrentInUse > FStats.PeakUsage then
          FStats.PeakUsage := FStats.CurrentInUse;
          
        LElapsedMs := MilliSecondsBetween(Now, LStartTime);
        FStats.AverageWaitTimeMs := 
          (FStats.AverageWaitTimeMs * (FStats.TotalAcquires - 1) + LElapsedMs) / FStats.TotalAcquires;
        
        if Assigned(FOnObjectAcquired) then
          FOnObjectAcquired(Self, AObject);
          
        Result := True;
        Exit;
      end;
      
      // No available objects, need to wait
      FAvailable.ResetEvent;
    finally
      FLock.Leave;
    end;
    
    // Check timeout
    LElapsedMs := MilliSecondsBetween(Now, LStartTime);
    if LElapsedMs >= ATimeoutMs then
    begin
      Inc(FStats.TotalTimeouts);
      Exit;
    end;
    
    // Wait for object to become available
    LWaitResult := FAvailable.WaitFor(ATimeoutMs - LElapsedMs);
    if LWaitResult <> wrSignaled then
    begin
      Inc(FStats.TotalTimeouts);
      Exit;
    end;
  end;
end;

procedure TObjectPool<T>.Release(AObject: T);
var
  I: Integer;
  LPooled: TPooledObject<T>;
  LFound: Boolean;
  LValid: Boolean;
begin
  LFound := False;
  
  FLock.Enter;
  try
    for I := 0 to FPool.Count - 1 do
    begin
      LPooled := FPool[I];
      if LPooled.Obj = AObject then
      begin
        LFound := True;
        
        // Validate if configured
        if FConfig.ValidationOnRelease then
        begin
          LValid := FFactory.ValidateObject(AObject);
          
          if Assigned(FOnValidation) then
            FOnValidation(Self, AObject, LValid);
            
          if not LValid then
          begin
            Inc(FStats.TotalValidationFails);
            DestroyPooledObject(LPooled);
            FPool.Delete(I);
            EnsureMinSize;
            Break;
          end;
        end;
        
        LPooled.MarkReturned;
        
        Inc(FStats.TotalReleases);
        Inc(FStats.CurrentIdle);
        Dec(FStats.CurrentInUse);
        
        if Assigned(FOnObjectReleased) then
          FOnObjectReleased(Self, AObject);
          
        FAvailable.SetEvent;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
  
  if not LFound then
    raise EObjectPoolException.Create('Object not found in pool');
end;

procedure TObjectPool<T>.Discard(AObject: T);
var
  I: Integer;
  LPooled: TPooledObject<T>;
begin
  if AObject = nil then
    Exit;

  FLock.Enter;
  try
    for I := 0 to FPool.Count - 1 do
    begin
      LPooled := FPool[I];
      if LPooled.Obj = AObject then
      begin
        DestroyPooledObject(LPooled);
        FPool.Delete(I);
        EnsureMinSize;
        Exit;
      end;
    end;
  finally
    FLock.Leave;
  end;

  raise EObjectPoolException.Create('Object not found in pool');
end;

procedure TObjectPool<T>.CleanupIdleObjects;
var
  I: Integer;
  LPooled: TPooledObject<T>;
  LNow: TDateTime;
  LIdleSeconds: Int64;
  LToRemove: TList<Integer>;
begin
  if FConfig.IdleTimeoutSec <= 0 then
    Exit;
    
  LNow := Now;
  LToRemove := TList<Integer>.Create;
  try
    FLock.Enter;
    try
      // Find idle objects to remove (keep minimum)
      for I := FPool.Count - 1 downto 0 do
      begin
        if FPool.Count - LToRemove.Count <= FConfig.MinSize then
          Break;
          
        LPooled := FPool[I];
        if not LPooled.InUse then
        begin
          LIdleSeconds := SecondsBetween(LNow, LPooled.LastUsedAt);
          if LIdleSeconds >= FConfig.IdleTimeoutSec then
            LToRemove.Add(I);
        end;
      end;
      
      // Remove idle objects
      for I := 0 to LToRemove.Count - 1 do
      begin
        LPooled := FPool[LToRemove[I]];
        DestroyPooledObject(LPooled);
        FPool.Delete(LToRemove[I]);
      end;
    finally
      FLock.Leave;
    end;
  finally
    LToRemove.Free;
  end;
end;

procedure TObjectPool<T>.Clear;
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := FPool.Count - 1 downto 0 do
      DestroyPooledObject(FPool[I]);
    FPool.Clear;
    FStats.CurrentPoolSize := 0;
    FStats.CurrentIdle := 0;
    FStats.CurrentInUse := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Shrink;
var
  I: Integer;
  LPooled: TPooledObject<T>;
begin
  FLock.Enter;
  try
    for I := FPool.Count - 1 downto 0 do
    begin
      if FPool.Count <= FConfig.MinSize then
        Break;
        
      LPooled := FPool[I];
      if not LPooled.InUse then
      begin
        DestroyPooledObject(LPooled);
        FPool.Delete(I);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.Warm(ACount: Integer);
var
  LTarget: Integer;
begin
  FLock.Enter;
  try
    LTarget := Min(ACount, FConfig.MaxSize);
    while FPool.Count < LTarget do
      FPool.Add(CreatePooledObject);
      
    if FPool.Count > 0 then
      FAvailable.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetStats: TPoolStats;
begin
  FLock.Enter;
  try
    Result := FStats;
  finally
    FLock.Leave;
  end;
end;

procedure TObjectPool<T>.ResetStats;
begin
  FLock.Enter;
  try
    FStats.TotalAcquires := 0;
    FStats.TotalReleases := 0;
    FStats.TotalTimeouts := 0;
    FStats.TotalValidationFails := 0;
    FStats.AverageWaitTimeMs := 0;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetCurrentSize: Integer;
begin
  FLock.Enter;
  try
    Result := FPool.Count;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetIdleCount: Integer;
begin
  FLock.Enter;
  try
    Result := FStats.CurrentIdle;
  finally
    FLock.Leave;
  end;
end;

function TObjectPool<T>.GetInUseCount: Integer;
begin
  FLock.Enter;
  try
    Result := FStats.CurrentInUse;
  finally
    FLock.Leave;
  end;
end;

{ TScopedPoolObject<T> }

constructor TScopedPoolObject<T>.Create(APool: TObjectPool<T>; AObject: T);
begin
  inherited Create;
  FPool := APool;
  FObject := AObject;
end;

destructor TScopedPoolObject<T>.Destroy;
begin
  if Assigned(FPool) and Assigned(FObject) then
    FPool.Release(FObject);
  inherited;
end;

function TScopedPoolObject<T>.GetObject: T;
begin
  Result := FObject;
end;

{ TKeyedObjectPool<TKey, T> }

constructor TKeyedObjectPool<TKey, T>.Create(AFactory: IObjectFactory<T>);
begin
  Create(AFactory, TPoolConfig.Default);
end;

constructor TKeyedObjectPool<TKey, T>.Create(AFactory: IObjectFactory<T>; const AConfig: TPoolConfig);
begin
  inherited Create;
  FFactory := AFactory;
  FConfig := AConfig;
  FPools := TObjectDictionary<TKey, TObjectPool<T>>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TKeyedObjectPool<TKey, T>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FPools);
  inherited;
end;

function TKeyedObjectPool<TKey, T>.GetPool(const AKey: TKey): TObjectPool<T>;
begin
  FLock.Enter;
  try
    if not FPools.TryGetValue(AKey, Result) then
    begin
      Result := TObjectPool<T>.Create(FFactory, FConfig);
      FPools.Add(AKey, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TKeyedObjectPool<TKey, T>.Acquire(const AKey: TKey): T;
begin
  Result := GetPool(AKey).Acquire;
end;

procedure TKeyedObjectPool<TKey, T>.Release(const AKey: TKey; AObject: T);
var
  LPool: TObjectPool<T>;
begin
  FLock.Enter;
  try
    if FPools.TryGetValue(AKey, LPool) then
      LPool.Release(AObject)
    else
      raise EObjectPoolException.Create('Pool not found for key');
  finally
    FLock.Leave;
  end;
end;

procedure TKeyedObjectPool<TKey, T>.ClearKey(const AKey: TKey);
var
  LPool: TObjectPool<T>;
begin
  FLock.Enter;
  try
    if FPools.TryGetValue(AKey, LPool) then
      LPool.Clear;
  finally
    FLock.Leave;
  end;
end;

procedure TKeyedObjectPool<TKey, T>.ClearAll;
var
  LPair: TPair<TKey, TObjectPool<T>>;
begin
  FLock.Enter;
  try
    for LPair in FPools do
      LPair.Value.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TPoolManager }

class constructor TPoolManager.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TPoolManager.Destroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FLock);
end;

class function TPoolManager.Instance: TPoolManager;
begin
  if not Assigned(FInstance) then
  begin
    FLock.Enter;
    try
      if not Assigned(FInstance) then
        FInstance := TPoolManager.Create;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

constructor TPoolManager.Create;
begin
  inherited;
  FPools := TDictionary<string, TObject>.Create;
  FPoolLock := TCriticalSection.Create;
end;

destructor TPoolManager.Destroy;
var
  LPair: TPair<string, TObject>;
begin
  for LPair in FPools do
    LPair.Value.Free;
  FreeAndNil(FPools);
  FreeAndNil(FPoolLock);
  inherited;
end;

procedure TPoolManager.RegisterPool<T>(const AName: string; APool: TObjectPool<T>);
begin
  FPoolLock.Enter;
  try
    if FPools.ContainsKey(AName) then
      raise EObjectPoolException.CreateFmt('Pool "%s" already registered', [AName]);
    FPools.Add(AName, APool);
  finally
    FPoolLock.Leave;
  end;
end;

function TPoolManager.GetPool<T>(const AName: string): TObjectPool<T>;
var
  LPool: TObject;
begin
  FPoolLock.Enter;
  try
    if FPools.TryGetValue(AName, LPool) then
      Result := TObjectPool<T>(LPool)
    else
      raise EObjectPoolException.CreateFmt('Pool "%s" not found', [AName]);
  finally
    FPoolLock.Leave;
  end;
end;

function TPoolManager.HasPool(const AName: string): Boolean;
begin
  FPoolLock.Enter;
  try
    Result := FPools.ContainsKey(AName);
  finally
    FPoolLock.Leave;
  end;
end;

procedure TPoolManager.UnregisterPool(const AName: string);
var
  LPool: TObject;
begin
  FPoolLock.Enter;
  try
    if FPools.TryGetValue(AName, LPool) then
    begin
      FPools.Remove(AName);
      LPool.Free;
    end;
  finally
    FPoolLock.Leave;
  end;
end;

procedure TPoolManager.ClearAll;
var
  LPair: TPair<string, TObject>;
begin
  FPoolLock.Enter;
  try
    for LPair in FPools do
      LPair.Value.Free;
    FPools.Clear;
  finally
    FPoolLock.Leave;
  end;
end;

{ TPoolBuilder<T> }

constructor TPoolBuilder<T>.Create;
begin
  inherited;
  FConfig := TPoolConfig.Default;
end;

function TPoolBuilder<T>.WithFactory(AFactory: IObjectFactory<T>): TPoolBuilder<T>;
begin
  FFactory := AFactory;
  Result := Self;
end;

function TPoolBuilder<T>.WithCreator(AOnCreate: TFunc<T>): TPoolBuilder<T>;
begin
  FOnCreate := AOnCreate;
  Result := Self;
end;

function TPoolBuilder<T>.WithDestructor(AOnDestroy: TProc<T>): TPoolBuilder<T>;
begin
  FOnDestroy := AOnDestroy;
  Result := Self;
end;

function TPoolBuilder<T>.WithValidator(AOnValidate: TFunc<T, Boolean>): TPoolBuilder<T>;
begin
  FOnValidate := AOnValidate;
  Result := Self;
end;

function TPoolBuilder<T>.WithReset(AOnReset: TProc<T>): TPoolBuilder<T>;
begin
  FOnReset := AOnReset;
  Result := Self;
end;

function TPoolBuilder<T>.WithMinSize(ASize: Integer): TPoolBuilder<T>;
begin
  FConfig.MinSize := ASize;
  Result := Self;
end;

function TPoolBuilder<T>.WithMaxSize(ASize: Integer): TPoolBuilder<T>;
begin
  FConfig.MaxSize := ASize;
  Result := Self;
end;

function TPoolBuilder<T>.WithIdleTimeout(ASeconds: Integer): TPoolBuilder<T>;
begin
  FConfig.IdleTimeoutSec := ASeconds;
  Result := Self;
end;

function TPoolBuilder<T>.WithAcquireTimeout(AMilliseconds: Integer): TPoolBuilder<T>;
begin
  FConfig.AcquireTimeoutMs := AMilliseconds;
  Result := Self;
end;

function TPoolBuilder<T>.WithValidationOnAcquire(AEnabled: Boolean): TPoolBuilder<T>;
begin
  FConfig.ValidationOnAcquire := AEnabled;
  Result := Self;
end;

function TPoolBuilder<T>.WithValidationOnRelease(AEnabled: Boolean): TPoolBuilder<T>;
begin
  FConfig.ValidationOnRelease := AEnabled;
  Result := Self;
end;

function TPoolBuilder<T>.WithCleanupInterval(ASeconds: Integer): TPoolBuilder<T>;
begin
  FConfig.CleanupIntervalSec := ASeconds;
  Result := Self;
end;

function TPoolBuilder<T>.WithGrowthFactor(AFactor: Double): TPoolBuilder<T>;
begin
  FConfig.GrowthFactor := AFactor;
  Result := Self;
end;

function TPoolBuilder<T>.Build: TObjectPool<T>;
var
  LFactory: IObjectFactory<T>;
begin
  if Assigned(FFactory) then
    LFactory := FFactory
  else if Assigned(FOnCreate) then
    LFactory := TCallbackObjectFactory<T>.Create(FOnCreate, FOnDestroy, FOnValidate, FOnReset)
  else
    raise EObjectPoolException.Create('No factory or creator specified');
    
  Result := TObjectPool<T>.Create(LFactory, FConfig);
end;

{ TObjectPools }

class function TObjectPools.CreatePool<T>: TObjectPool<T>;
begin
  Result := TObjectPool<T>.Create(TDefaultObjectFactory<T>.Create);
end;

class function TObjectPools.CreatePool<T>(const AConfig: TPoolConfig): TObjectPool<T>;
begin
  Result := TObjectPool<T>.Create(TDefaultObjectFactory<T>.Create, AConfig);
end;

class function TObjectPools.CreatePool<T>(ACreator: TFunc<T>): TObjectPool<T>;
begin
  Result := TObjectPool<T>.Create(TCallbackObjectFactory<T>.Create(ACreator));
end;

class function TObjectPools.Pool<T>: TPoolBuilder<T>;
begin
  Result := TPoolBuilder<T>.Create;
end;

class function TObjectPools.Manager: TPoolManager;
begin
  Result := TPoolManager.Instance;
end;

end.
