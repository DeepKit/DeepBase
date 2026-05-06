{ ============================================================================
  UniBase.DB.ConnectionPool - Database Connection Pool
  
  Version: 1.0
  Package: UniBasePersistence
  Description: Simple connection pool for SQLite database.
  Thread Safety: All public methods are thread-safe.
  
  Usage:
    Pool := TDBConnectionPool.Create('path/to/db.sqlite', 5);
    try
      Conn := Pool.Acquire;
      try
        // use Conn
      finally
        Pool.Release(Conn);
      end;
    finally
      Pool.Free;
    end;
  ============================================================================ }

unit UniBase.DB.ConnectionPool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

type
  /// <summary>
  /// Base exception for connection pool errors
  /// </summary>
  EConnectionPoolException = class(Exception);

  /// <summary>
  /// Raised when acquiring a connection times out
  /// </summary>
  EConnectionPoolTimeout = class(EConnectionPoolException);

  /// <summary>
  /// Connection wrapper with metadata
  /// </summary>
  TPooledConnection = class
  private
    FConnection: TFDConnection;
    FInUse: Boolean;
    FLastUsed: TDateTime;
    FCreatedAt: TDateTime;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    
    property Connection: TFDConnection read FConnection;
    property InUse: Boolean read FInUse write FInUse;
    property LastUsed: TDateTime read FLastUsed write FLastUsed;
    property CreatedAt: TDateTime read FCreatedAt;
  end;
  
  /// <summary>
  /// Database connection pool
  /// </summary>
  TDBConnectionPool = class
  private
    FDBPath: string;
    FMaxPoolSize: Integer;
    FMinPoolSize: Integer;
    FConnectionTimeout: Integer; // seconds
    
    FPool: TObjectList<TPooledConnection>;
    FLock: TCriticalSection;
    FAvailableEvent: TEvent;
    
    function CreateConnection: TFDConnection;
    function FindAvailableConnection: TPooledConnection;
    procedure ConfigureConnection(Conn: TFDConnection);
    
  public
    constructor Create(const ADBPath: string; AMaxPoolSize: Integer = 5);
    destructor Destroy; override;
    
    /// <summary>
    /// Acquire a connection from the pool (blocks if none available)
    /// </summary>
    function Acquire: TFDConnection;
    
    /// <summary>
    /// Acquire with timeout (returns nil if timeout)
    /// </summary>
    function AcquireTimeout(TimeoutMs: Cardinal): TFDConnection;
    
    /// <summary>
    /// Release a connection back to the pool
    /// </summary>
    procedure Release(AConnection: TFDConnection);
    
    /// <summary>
    /// Get current pool statistics
    /// </summary>
    function GetPoolStats: string;
    
    /// <summary>
    /// Number of connections currently in use
    /// </summary>
    function GetActiveCount: Integer;
    
    /// <summary>
    /// Number of available connections
    /// </summary>
    function GetAvailableCount: Integer;
    
    /// <summary>
    /// Total connections in pool
    /// </summary>
    function GetTotalCount: Integer;
    
    /// <summary>Database path</summary>
    property DBPath: string read FDBPath;
    
    /// <summary>Maximum pool size</summary>
    property MaxPoolSize: Integer read FMaxPoolSize write FMaxPoolSize;
    
    /// <summary>Minimum pool size (pre-created)</summary>
    property MinPoolSize: Integer read FMinPoolSize write FMinPoolSize;
    
    /// <summary>Connection acquisition timeout (seconds)</summary>
    property ConnectionTimeout: Integer read FConnectionTimeout write FConnectionTimeout;
  end deprecated 'Use TUniConnectionPool from UniBase.DB.Pool with DatabaseType := dbSQLite';

implementation

uses
  System.Math,
  System.DateUtils,
  UniBase.Logging;

{ TPooledConnection }

constructor TPooledConnection.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FInUse := False;
  FLastUsed := Now;
  FCreatedAt := Now;
end;

destructor TPooledConnection.Destroy;
begin
  if Assigned(FConnection) then
  begin
    if FConnection.Connected then
      FConnection.Close;
    FreeAndNil(FConnection);
  end;
  inherited;
end;

{ TDBConnectionPool }

constructor TDBConnectionPool.Create(const ADBPath: string; AMaxPoolSize: Integer);
var
  i: Integer;
begin
  inherited Create;
  FDBPath := ADBPath;
  FMaxPoolSize := AMaxPoolSize;
  FMinPoolSize := 1;
  FConnectionTimeout := 30; // 30 seconds default
  
  FPool := TObjectList<TPooledConnection>.Create(True); // owns objects
  FLock := TCriticalSection.Create;
  FAvailableEvent := TEvent.Create(nil, True, True, ''); // manual reset, initially signaled
  
  // Pre-create minimum connections
  for i := 1 to FMinPoolSize do
  begin
    try
      FPool.Add(TPooledConnection.Create(CreateConnection));
    except
      on E: Exception do
      begin
        // R-006: 初始池创建失败时输出调试信息
        {$IFDEF DEBUG}
        OutputDebugString(PChar('UniBase.ConnectionPool pre-create failed: ' + E.Message));
        {$ENDIF}
      end;
    end;
  end;
end;

destructor TDBConnectionPool.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FPool);
  finally
    FLock.Leave;
  end;
  
  FreeAndNil(FLock);
  FreeAndNil(FAvailableEvent);
  inherited;
end;

function TDBConnectionPool.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

procedure TDBConnectionPool.ConfigureConnection(Conn: TFDConnection);
begin
  Conn.DriverName := 'SQLite';
  Conn.Params.Database := FDBPath;
  Conn.Params.Values['LockingMode'] := 'Normal';
  Conn.Params.Values['Synchronous'] := 'Normal';
  Conn.Params.Values['JournalMode'] := 'WAL';
  Conn.Params.Values['OpenMode'] := 'CreateUTF8';
end;

function TDBConnectionPool.FindAvailableConnection: TPooledConnection;
var
  i: Integer;
  Pooled: TPooledConnection;
begin
  Result := nil;
  
  for i := 0 to FPool.Count - 1 do
  begin
    Pooled := FPool[i];
    if not Pooled.InUse then
    begin
      // Check if connection is still valid
      if Pooled.Connection.Connected then
      begin
        Result := Pooled;
        Exit;
      end
      else
      begin
        // Try to reconnect
        try
          Pooled.Connection.Open;
          Result := Pooled;
          Exit;
        except
          on E: Exception do
          begin
            // BUG-076+079 FIX: Logger.Warning → Warn; FPool.Delete (OwnsObjects=True) auto-frees
            if UniBase.Logging.Logger <> nil then
              UniBase.Logging.Logger.Warn('Connection pool reconnect failed: ' + E.Message);
            FPool.Delete(i);
            Exit;
          end;
        end;
      end;
    end;
  end;
end;

function TDBConnectionPool.Acquire: TFDConnection;
begin
  Result := AcquireTimeout(Cardinal(FConnectionTimeout) * 1000);
  if Result = nil then
    raise EConnectionPoolTimeout.Create('Connection pool timeout: no available connections');
end;

function TDBConnectionPool.AcquireTimeout(TimeoutMs: Cardinal): TFDConnection;
var
  StartTime: TDateTime;
  Pooled: TPooledConnection;
  ElapsedMs: Int64;
begin
  Result := nil;
  StartTime := Now;
  
  while True do
  begin
    FLock.Enter;
    try
      // Try to find available connection
      Pooled := FindAvailableConnection;
      
      if Pooled <> nil then
      begin
        Pooled.InUse := True;
        Pooled.LastUsed := Now;
        Result := Pooled.Connection;
        Exit;
      end;
      
      // No available connection, can we create new?
      if FPool.Count < FMaxPoolSize then
      begin
        try
          Pooled := TPooledConnection.Create(CreateConnection);
          Pooled.InUse := True;
          FPool.Add(Pooled);
          Result := Pooled.Connection;
          Exit;
        except
          on E: Exception do
          begin
            // 新连接创建失败，记录日志
            if UniBase.Logging.Logger <> nil then
              UniBase.Logging.Logger.Error('Connection pool new connection failed: ' + E.Message);
          end;
        end;
      end;
      
      // Pool full and all in use - need to wait
      FAvailableEvent.ResetEvent;
    finally
      FLock.Leave;
    end;
    
    // Check timeout
    ElapsedMs := MilliSecondsBetween(Now, StartTime);
    if ElapsedMs >= TimeoutMs then
      Exit(nil);
    
    // Wait for a connection to become available
    FAvailableEvent.WaitFor(Min(1000, TimeoutMs - Cardinal(ElapsedMs)));
  end;
end;

procedure TDBConnectionPool.Release(AConnection: TFDConnection);
var
  i: Integer;
  Pooled: TPooledConnection;
begin
  if AConnection = nil then
    Exit;
    
  FLock.Enter;
  try
    for i := 0 to FPool.Count - 1 do
    begin
      Pooled := FPool[i];
      if Pooled.Connection = AConnection then
      begin
        Pooled.InUse := False;
        Pooled.LastUsed := Now;
        FAvailableEvent.SetEvent; // Signal that a connection is available
        Exit;
      end;
    end;
    
    // Connection not found in pool - might be externally created
    // BUG-076 FIX: Logger.Warning → Warn
    if UniBase.Logging.Logger <> nil then
      UniBase.Logging.Logger.Warn('Attempting to release connection not in pool - possible connection leak');
  finally
    FLock.Leave;
  end;
end;

function TDBConnectionPool.GetPoolStats: string;
begin
  FLock.Enter;
  try
    Result := Format('Pool: %d total, %d active, %d available, max %d',
      [GetTotalCount, GetActiveCount, GetAvailableCount, FMaxPoolSize]);
  finally
    FLock.Leave;
  end;
end;

function TDBConnectionPool.GetActiveCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  // Assumes caller has lock or is in GetPoolStats
  for i := 0 to FPool.Count - 1 do
    if FPool[i].InUse then
      Inc(Result);
end;

function TDBConnectionPool.GetAvailableCount: Integer;
begin
  Result := FPool.Count - GetActiveCount;
end;

function TDBConnectionPool.GetTotalCount: Integer;
begin
  Result := FPool.Count;
end;

end.
