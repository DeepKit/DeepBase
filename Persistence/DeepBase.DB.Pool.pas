unit DeepBase.DB.Pool;

{*******************************************************************************
  DeepBase.DB.Pool - 高级数据库连接池

  版本: 2.0
  所属包: DeepBasePersistence
  功能:
  - 官方 profile 路径支持 SQLite + PostgreSQL 双数据库并存
  - 保留�?DatabaseType/ConnectionString 兼容入口
  - 连接健康检�?
  - 空闲连接回收
  - 连接泄漏检�?
  - 详细统计监控
  - 连接预热
  - 自动重连

  线程安全: 所有公共方法都是线程安全的

  用法:
    // 创建连接�?
    Pool := TUniConnectionPool.Create;
    Pool.DatabaseType := dbSQLite;
    Pool.ConnectionString := 'path/to/db.sqlite';
    Pool.MinSize := 2;
    Pool.MaxSize := 10;
    Pool.Initialize;

    // 获取连接 (推荐使用 with 语句)
    with Pool.GetConnection do
    try
      // 使用 Connection
      Connection.ExecSQL('INSERT INTO Log(Msg) VALUES(:Msg)', ['test']);
    finally
      Release; // 或自动释�?
    end;

    // 或使用作用域连接
    Pool.Execute(procedure(Conn: TFDConnection)
    begin
      Conn.ExecSQL('INSERT INTO ...');
    end);
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.DateUtils,
  System.Generics.Collections, System.Diagnostics, System.TimeSpan,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.Stan.Option, FireDAC.Stan.Error,
  FireDAC.Phys.Intf, FireDAC.Stan.Pool, DeepBase.Exceptions,
  DeepBase.RuntimeContext;

type
  /// <summary>支持的数据库类型</summary>
  TDatabaseType = (
    dbSQLite,
    dbMySQL,
    dbPostgreSQL,
    dbSQLServer,
    dbOracle,
    dbFirebird,
    dbInterBase
  );

  /// <summary>Explicit database connection profile for app-level named pools.</summary>
  TDBConnectionProfile = record
    DatabaseType: TDatabaseType;
    Database: string;
    Host: string;
    Port: Integer;
    Username: string;
    Password: string;
    CharacterSet: string;
    ApplicationName: string;
    SSLMode: string;
    VendorLib: string;
    SQLiteLockingMode: string;
    SQLiteSynchronous: string;
    SQLiteJournalMode: string;
    SQLiteOpenMode: string;
    ConnectTimeoutSec: Integer;
    CommandTimeoutSec: Integer;
    Pooled: Boolean;
    PoolMaxItems: Integer;
    ExtraParams: string;

    class function SQLite(const DatabasePath: string): TDBConnectionProfile; static;
    class function PostgreSQL(const Host, Database, Username,
      Password: string; Port: Integer = 5432): TDBConnectionProfile; static;
    procedure Validate;
    function SameConnectionAs(const Other: TDBConnectionProfile): Boolean;
  end;

  /// <summary>连接状�?/summary>
  TConnectionState = (
    csIdle,       // 空闲可用
    csInUse,      // 正在使用
    csInvalid,    // 无效需移除
    csValidating  // 正在验证
  );

  /// <summary>连接池事件类�?/summary>
  TPoolEventType = (
    peConnectionCreated,
    peConnectionDestroyed,
    peConnectionAcquired,
    peConnectionReleased,
    peConnectionValidated,
    peConnectionInvalidated,
    peConnectionLeakDetected,
    pePoolExhausted
  );

  /// <summary>连接池事�?/summary>
  TPoolEvent = procedure(Sender: TObject; EventType: TPoolEventType;
    const Message: string) of object;

  /// <summary>连接池统计信�?/summary>
  TPoolStatistics = record
    TotalConnections: Integer;
    ActiveConnections: Integer;
    IdleConnections: Integer;
    WaitingRequests: Integer;
    TotalAcquires: Int64;
    TotalReleases: Int64;
    TotalCreates: Int64;
    TotalDestroys: Int64;
    TotalTimeouts: Int64;
    TotalValidations: Int64;
    TotalInvalidations: Int64;
    AverageWaitTimeMs: Double;
    MaxWaitTimeMs: Int64;
    LeaksDetected: Integer;
    PoolUptime: TTimeSpan;
    function ToString: string;
  end;

  TUniConnectionPool = class;

  /// <summary>池化连接包装�?/summary>
  TPooledConnection = class
  private
    FPool: TUniConnectionPool;
    FConnection: TFDConnection;
    FState: TConnectionState;
    FCreatedAt: TDateTime;
    FLastUsedAt: TDateTime;
    FLastValidatedAt: TDateTime;
    FAcquiredAt: TDateTime;
    FAcquireCount: Int64;
    FOwnerThreadId: TThreadId;
    FLeakWarned: Boolean;
    function GetIsValid: Boolean;
    function GetIdleTime: TTimeSpan;
    function GetUseTime: TTimeSpan;
    /// <summary>归还前复位脏事务/隔离级别 (DATA-R3-001 / BUG-431)</summary>
    procedure ResetConnectionState;
  public
    constructor Create(APool: TUniConnectionPool; AConnection: TFDConnection);
    destructor Destroy; override;

    /// <summary>释放回连接池</summary>
    procedure Release;

    /// <summary>标记为无�?/summary>
    procedure Invalidate;

    /// <summary>验证连接有效�?/summary>
    function Validate: Boolean;

    /// <summary>Set connection state (for unit-test regression scenarios only).</summary>
    /// <remarks>REVIEW5-DATA-004: Required by BUG-333 regression test to simulate
    /// csValidating without triggering a real validation query.</remarks>
    procedure SetStateForTest(AState: TConnectionState);

    property Connection: TFDConnection read FConnection;
    property State: TConnectionState read FState;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastUsedAt: TDateTime read FLastUsedAt;
    property IdleTime: TTimeSpan read GetIdleTime;
    property UseTime: TTimeSpan read GetUseTime;
    property IsValid: Boolean read GetIsValid;
    property AcquireCount: Int64 read FAcquireCount;
  end;

  /// <summary>连接池配�?/summary>
  TPoolConfig = record
    MinSize: Integer;
    MaxSize: Integer;
    AcquireTimeoutMs: Cardinal;
    IdleTimeoutSec: Integer;
    MaxLifetimeSec: Integer;
    ValidationIntervalSec: Integer;
    LeakDetectionThresholdSec: Integer;
    ValidationQuery: string;
    AutoCommit: Boolean;
    class function Default: TPoolConfig; static;
  end;

  /// <summary>高级数据库连接池</summary>
  TUniConnectionPool = class
  private
    FDatabaseType: TDatabaseType;
    FConnectionString: string;
    FProfile: TDBConnectionProfile;
    FUseProfile: Boolean;
    FConfig: TPoolConfig;
    FInitialized: Boolean;

    FPool: TObjectList<TPooledConnection>;
    FLock: TCriticalSection;
    FAvailableEvent: TEvent;
    FMaintenanceThread: TThread;
    FMaintenanceWakeEvent: TEvent;
    /// <summary>DATA2-060: Integer flag accessed via TInterlocked for cross-thread visibility.</summary>
    FShutdown: Integer;

    FStatistics: TPoolStatistics;
    FStatsLock: TCriticalSection;
    FStartTime: TDateTime;

    FOnPoolEvent: TPoolEvent;

    // FireDAC 组件
    FFDManager: TFDManager;
    FFDDriverLink: TComponent;

    function GetIsShuttingDown: Boolean; inline;
    procedure SetIsShuttingDown(Value: Boolean); inline;

    function CreateConnection: TFDConnection;
    function FindAvailableConnection: TPooledConnection;
    procedure ConfigureConnection(Conn: TFDConnection);
    procedure ConfigureConnectionFromProfile(Conn: TFDConnection);
    procedure ApplyExtraParams(Conn: TFDConnection; const ExtraParams: string);
    procedure DoPoolEvent(EventType: TPoolEventType; const Msg: string);
    procedure DoWarmup(Count: Integer);
    procedure MaintenanceLoop;
    procedure PerformMaintenance;
    procedure ValidateIdleConnections;
    procedure RemoveExpiredConnections;
    procedure DetectLeaks;
    procedure EnsureMinConnections;
    function GetDriverName: string;
    procedure SetDatabaseType(const Value: TDatabaseType);
    procedure SetConnectionString(const Value: string);

  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>初始化连接池</summary>
    procedure Initialize;

    /// <summary>Configure pool from explicit profile. Must be called before Initialize.</summary>
    procedure Configure(const AProfile: TDBConnectionProfile);

    /// <summary>关闭连接�?/summary>
    procedure Shutdown;

    /// <summary>获取一个连�?/summary>
    function GetConnection: TPooledConnection;

    /// <summary>Create a configured FireDAC connection without opening it.</summary>
    function CreateUnopenedConnection: TFDConnection;

    /// <summary>获取连接（带超时�?/summary>
    function TryGetConnection(TimeoutMs: Cardinal; out Conn: TPooledConnection): Boolean;

    /// <summary>执行操作（自动获取和释放连接�?/summary>
    procedure Execute(Proc: TProc<TFDConnection>);

    /// <summary>执行查询（自动获取和释放连接�?/summary>
    function Query<T>(Func: TFunc<TFDConnection, T>): T;

    /// <summary>清空所有空闲连�?/summary>
    procedure ClearIdleConnections;

    /// <summary>强制回收所有连�?/summary>
    procedure RecycleAllConnections;

    /// <summary>获取统计信息</summary>
    function GetStatistics: TPoolStatistics;

    /// <summary>重置统计信息</summary>
    procedure ResetStatistics;

    /// <summary>预热连接�?/summary>
    procedure Warmup(Count: Integer = 0);

    // 属�?
    property DatabaseType: TDatabaseType read FDatabaseType write SetDatabaseType;
    property ConnectionString: string read FConnectionString write SetConnectionString;
    property Profile: TDBConnectionProfile read FProfile;
    property UsesProfile: Boolean read FUseProfile;
    property Config: TPoolConfig read FConfig write FConfig;
    property Initialized: Boolean read FInitialized;

    // 快捷属�?
    property MinSize: Integer read FConfig.MinSize write FConfig.MinSize;
    property MaxSize: Integer read FConfig.MaxSize write FConfig.MaxSize;
    property AcquireTimeoutMs: Cardinal read FConfig.AcquireTimeoutMs write FConfig.AcquireTimeoutMs;
    property IdleTimeoutSec: Integer read FConfig.IdleTimeoutSec write FConfig.IdleTimeoutSec;
    property MaxLifetimeSec: Integer read FConfig.MaxLifetimeSec write FConfig.MaxLifetimeSec;
    property ValidationIntervalSec: Integer read FConfig.ValidationIntervalSec write FConfig.ValidationIntervalSec;
    property LeakDetectionThresholdSec: Integer read FConfig.LeakDetectionThresholdSec write FConfig.LeakDetectionThresholdSec;

    // 事件
    property OnPoolEvent: TPoolEvent read FOnPoolEvent write FOnPoolEvent;
  end;

  /// <summary>全局连接池管理器</summary>
  TPoolManager = class
  private
    class var FPools: TObjectDictionary<string, TUniConnectionPool>;
    class var FLock: TCriticalSection;
    class procedure ValidatePoolName(const Name: string); static;
    class procedure EnsureExistingPoolMatches(const Name: string;
      Pool: TUniConnectionPool; const Profile: TDBConnectionProfile;
      const Config: TPoolConfig); static;
  public
    class constructor Create;
    class destructor Destroy;

    /// <summary>获取或创建命名连接池</summary>
    class function GetPool(const Name: string): TUniConnectionPool;

    /// <summary>Get existing pool or create a named pool from profile.</summary>
    class function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;

    /// <summary>Get existing pool or create a named pool from profile and config.</summary>
    class function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile; const Config: TPoolConfig;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;

    /// <summary>注册连接�?/summary>
    class procedure RegisterPool(const Name: string; Pool: TUniConnectionPool);

    /// <summary>移除连接�?/summary>
    class procedure RemovePool(const Name: string);

    /// <summary>获取所有池名称</summary>
    class function GetPoolNames: TArray<string>;

    /// <summary>关闭所有连接池</summary>
    class procedure ShutdownAll;
  end;

  /// <summary>
  /// Facade for named database pool management.
  /// Prefer this interface in new code to avoid hard dependencies on static
  /// TPoolManager calls and to simplify test substitution.
  /// </summary>
  IDBPoolProvider = interface
    ['{C0F2B78E-BC5A-4FD1-85D8-B7FD38BB6A43}']
    function GetPool(const Name: string): TUniConnectionPool;
    function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;
    function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile; const Config: TPoolConfig;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;
    procedure RegisterPool(const Name: string; Pool: TUniConnectionPool);
    procedure RemovePool(const Name: string);
    function GetPoolNames: TArray<string>;
    procedure ShutdownAll;
  end;

/// <summary>获取默认连接�?/summary>
function DefaultPool: TUniConnectionPool;

/// <summary>设置默认连接�?/summary>
procedure SetDefaultPool(Pool: TUniConnectionPool);

/// <summary>Get the default DB pool provider facade.</summary>
function DBPoolProvider: IDBPoolProvider;

/// <summary>Override DB pool provider facade (mainly for tests).</summary>
procedure SetDBPoolProvider(const Provider: IDBPoolProvider);

/// <summary>
/// Create a RuntimeContext component for TPoolManager lifecycle.
/// Start records lifecycle ownership; Shutdown closes and clears all named
/// pools only if the component has been started.
/// </summary>
function CreateDBPoolManagerRuntimeComponent: IRuntimeComponent;

implementation

uses
  System.Math,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  DeepBase.DB.DoQry;

var
  GDefaultPool: TUniConnectionPool = nil;
  GDBPoolProvider: IDBPoolProvider = nil;
  GDBPoolProviderLock: TObject = nil;

type
  TDefaultDBPoolProvider = class(TInterfacedObject, IDBPoolProvider)
  public
    function GetPool(const Name: string): TUniConnectionPool;
    function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;
    function GetOrCreatePool(const Name: string;
      const Profile: TDBConnectionProfile; const Config: TPoolConfig;
      AutoInitialize: Boolean = False): TUniConnectionPool; overload;
    procedure RegisterPool(const Name: string; Pool: TUniConnectionPool);
    procedure RemovePool(const Name: string);
    function GetPoolNames: TArray<string>;
    procedure ShutdownAll;
  end;

  TDBPoolManagerRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FStarted: Boolean;
  public
    constructor Create; reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

function DefaultPool: TUniConnectionPool;
begin
  // Use atomic read via CompareExchange(current, nil, nil) for memory visibility
  Result := TUniConnectionPool(TInterlocked.CompareExchange(Pointer(GDefaultPool), nil, nil));
end;

procedure SetDefaultPool(Pool: TUniConnectionPool);
begin
  TInterlocked.Exchange(Pointer(GDefaultPool), Pointer(Pool));
end;

function DBPoolProvider: IDBPoolProvider;
begin
  if GDBPoolProvider = nil then
  begin
    TMonitor.Enter(GDBPoolProviderLock);
    try
      if GDBPoolProvider = nil then
        GDBPoolProvider := TDefaultDBPoolProvider.Create;
    finally
      TMonitor.Exit(GDBPoolProviderLock);
    end;
  end;

  Result := GDBPoolProvider;
end;

procedure SetDBPoolProvider(const Provider: IDBPoolProvider);
begin
  TMonitor.Enter(GDBPoolProviderLock);
  try
    GDBPoolProvider := Provider;
  finally
    TMonitor.Exit(GDBPoolProviderLock);
  end;
end;

{ TDefaultDBPoolProvider }

function TDefaultDBPoolProvider.GetPool(const Name: string): TUniConnectionPool;
begin
  Result := TPoolManager.GetPool(Name);
end;

function TDefaultDBPoolProvider.GetOrCreatePool(const Name: string;
  const Profile: TDBConnectionProfile;
  AutoInitialize: Boolean): TUniConnectionPool;
begin
  Result := TPoolManager.GetOrCreatePool(Name, Profile, AutoInitialize);
end;

function TDefaultDBPoolProvider.GetOrCreatePool(const Name: string;
  const Profile: TDBConnectionProfile; const Config: TPoolConfig;
  AutoInitialize: Boolean): TUniConnectionPool;
begin
  Result := TPoolManager.GetOrCreatePool(Name, Profile, Config, AutoInitialize);
end;

procedure TDefaultDBPoolProvider.RegisterPool(const Name: string;
  Pool: TUniConnectionPool);
begin
  TPoolManager.RegisterPool(Name, Pool);
end;

procedure TDefaultDBPoolProvider.RemovePool(const Name: string);
begin
  TPoolManager.RemovePool(Name);
end;

function TDefaultDBPoolProvider.GetPoolNames: TArray<string>;
begin
  Result := TPoolManager.GetPoolNames;
end;

procedure TDefaultDBPoolProvider.ShutdownAll;
begin
  TPoolManager.ShutdownAll;
end;

{ TDBPoolManagerRuntimeComponent }

constructor TDBPoolManagerRuntimeComponent.Create;
begin
  inherited Create('DB.PoolManager');
  FStarted := False;
end;

procedure TDBPoolManagerRuntimeComponent.Start;
begin
  FStarted := True;
end;

procedure TDBPoolManagerRuntimeComponent.Stop;
begin
  // Pool shutdown belongs to Shutdown phase after async stop and logger flush.
end;

procedure TDBPoolManagerRuntimeComponent.Shutdown;
begin
  if not FStarted then
    Exit;

  TPoolManager.ShutdownAll;
  FStarted := False;
end;

function CreateDBPoolManagerRuntimeComponent: IRuntimeComponent;
begin
  Result := TDBPoolManagerRuntimeComponent.Create;
end;

{ TPoolStatistics }

function TPoolStatistics.ToString: string;
begin
  Result := Format(
    'Connection pool statistics' + sLineBreak +
    '  Total connections: %d' + sLineBreak +
    '  Active connections: %d' + sLineBreak +
    '  Idle connections: %d' + sLineBreak +
    '  Waiting requests: %d' + sLineBreak +
    '  Total acquires: %d' + sLineBreak +
    '  Total releases: %d' + sLineBreak +
    '  Total creates: %d' + sLineBreak +
    '  Total destroys: %d' + sLineBreak +
    '  Timeouts: %d' + sLineBreak +
    '  Validations: %d' + sLineBreak +
    '  Invalidations: %d' + sLineBreak +
    '  Average wait: %.2f ms' + sLineBreak +
    '  Max wait: %d ms' + sLineBreak +
    '  Leaks detected: %d' + sLineBreak +
    '  Uptime: %s',
    [TotalConnections, ActiveConnections, IdleConnections, WaitingRequests,
     TotalAcquires, TotalReleases, TotalCreates, TotalDestroys,
     TotalTimeouts, TotalValidations, TotalInvalidations,
     AverageWaitTimeMs, MaxWaitTimeMs, LeaksDetected,
     Format('%d days %d hours %d minutes',
       [Trunc(PoolUptime.TotalDays), PoolUptime.Hours, PoolUptime.Minutes])]);
end;
{ TDBConnectionProfile }
{ TDBConnectionProfile }

function DatabaseTypeToText(DatabaseType: TDatabaseType): string;
begin
  case DatabaseType of
    dbSQLite: Result := 'SQLite';
    dbMySQL: Result := 'MySQL';
    dbPostgreSQL: Result := 'PostgreSQL';
    dbSQLServer: Result := 'SQLServer';
    dbOracle: Result := 'Oracle';
    dbFirebird: Result := 'Firebird';
    dbInterBase: Result := 'InterBase';
  else
    Result := 'Unknown';
  end;
end;

class function TDBConnectionProfile.SQLite(
  const DatabasePath: string): TDBConnectionProfile;
begin
  Result := Default(TDBConnectionProfile);
  Result.DatabaseType := dbSQLite;
  Result.Database := DatabasePath;
  Result.SQLiteLockingMode := 'Normal';
  Result.SQLiteSynchronous := 'Normal';
  Result.SQLiteJournalMode := 'WAL';
  Result.SQLiteOpenMode := 'CreateUTF8';
  Result.CharacterSet := 'UTF8';
  Result.ApplicationName := 'DeepBase';
  Result.ConnectTimeoutSec := 30;
  Result.CommandTimeoutSec := 0;
  Result.Pooled := False;
  Result.PoolMaxItems := 0;
end;

class function TDBConnectionProfile.PostgreSQL(const Host, Database, Username,
  Password: string; Port: Integer): TDBConnectionProfile;
begin
  Result := Default(TDBConnectionProfile);
  Result.DatabaseType := dbPostgreSQL;
  Result.Host := Host;
  Result.Port := Port;
  Result.Database := Database;
  Result.Username := Username;
  Result.Password := Password;
  Result.CharacterSet := 'UTF8';
  Result.ApplicationName := 'DeepBase';
  Result.SSLMode := 'prefer';
  Result.ConnectTimeoutSec := 30;
  Result.CommandTimeoutSec := 0;
  Result.Pooled := False;
  Result.PoolMaxItems := 0;
end;

procedure TDBConnectionProfile.Validate;
begin
  case DatabaseType of
    dbSQLite:
      begin
        if Trim(Database) = '' then
          raise EDatabaseException.Create('SQLite profile requires a database path');
      end;

    dbPostgreSQL:
      begin
        if Trim(Host) = '' then
          raise EDatabaseException.Create('PostgreSQL profile requires a host');
        if (Port <= 0) or (Port > 65535) then
          raise EDatabaseException.CreateFmt('PostgreSQL profile has invalid port: %d', [Port]);
        if Trim(Database) = '' then
          raise EDatabaseException.Create('PostgreSQL profile requires a database name');
        if Trim(Username) = '' then
          raise EDatabaseException.Create('PostgreSQL profile requires a username');
      end;
  else
    raise EDatabaseException.CreateFmt(
      'Explicit connection profiles currently support SQLite and PostgreSQL only, not %s',
      [DatabaseTypeToText(DatabaseType)]);
  end;

  if ConnectTimeoutSec < 0 then
    raise EDatabaseException.Create('Connection profile connect timeout must be >= 0');
  if CommandTimeoutSec < 0 then
    raise EDatabaseException.Create('Connection profile command timeout must be >= 0');
  if PoolMaxItems < 0 then
    raise EDatabaseException.Create('Connection profile pool max items must be >= 0');
end;

function TDBConnectionProfile.SameConnectionAs(
  const Other: TDBConnectionProfile): Boolean;
begin
  Result :=
    (DatabaseType = Other.DatabaseType) and
    (Database = Other.Database) and
    SameText(Host, Other.Host) and
    (Port = Other.Port) and
    (Username = Other.Username) and
    (Password = Other.Password) and
    (CharacterSet = Other.CharacterSet) and
    (ApplicationName = Other.ApplicationName) and
    (SSLMode = Other.SSLMode) and
    (VendorLib = Other.VendorLib) and
    (SQLiteLockingMode = Other.SQLiteLockingMode) and
    (SQLiteSynchronous = Other.SQLiteSynchronous) and
    (SQLiteJournalMode = Other.SQLiteJournalMode) and
    (SQLiteOpenMode = Other.SQLiteOpenMode) and
    (ConnectTimeoutSec = Other.ConnectTimeoutSec) and
    (CommandTimeoutSec = Other.CommandTimeoutSec) and
    (Pooled = Other.Pooled) and
    (PoolMaxItems = Other.PoolMaxItems) and
    (ExtraParams = Other.ExtraParams);
end;

{ TPoolConfig }

class function TPoolConfig.Default: TPoolConfig;
begin
  Result.MinSize := 2;
  Result.MaxSize := 10;
  Result.AcquireTimeoutMs := 30000;  // 30�?
  Result.IdleTimeoutSec := 300;      // 5分钟
  Result.MaxLifetimeSec := 3600;     // 1小时
  Result.ValidationIntervalSec := 60; // 1分钟
  Result.LeakDetectionThresholdSec := 120; // 2分钟
  Result.ValidationQuery := 'SELECT 1';
  Result.AutoCommit := True;
end;

{ TPooledConnection }

constructor TPooledConnection.Create(APool: TUniConnectionPool; AConnection: TFDConnection);
begin
  inherited Create;
  FPool := APool;
  FConnection := AConnection;
  FState := csIdle;
  FCreatedAt := Now;
  FLastUsedAt := Now;
  FLastValidatedAt := Now;
  FAcquireCount := 0;
  FOwnerThreadId := 0;
  FLeakWarned := False;
end;

destructor TPooledConnection.Destroy;
var
  Conn: TFDConnection;
begin
  // DATA2-062: atomically take ownership of FConnection so that no other
  // code path (e.g. pool sweep, concurrent invalidation) can free it twice.
  Conn := TFDConnection(TInterlocked.Exchange(Pointer(FConnection), nil));
  if Assigned(Conn) then
  begin
    // BASIC-014/FR-008: sweep DoQry prepared-statement cache so that
    // address reuse on the next TFDConnection allocation cannot return
    // stale prepared queries pointing at the freed connection.
    try
      UniDbSweepConnectionFromPool(Conn);
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.DB.Pool: prepared sweep failed: ' + E.Message));
        {$ENDIF}
    end;

    try
      if Conn.Connected then
        Conn.Close;
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.DB.Pool: Connection close failed: ' + E.Message));
        {$ENDIF}
    end;
    Conn.Free;
  end;
  inherited;
end;

procedure TPooledConnection.Release;
begin
  if Assigned(FPool) then
  begin
    var LUseTime := UseTime;
    // DATA-R3-001 (BUG-431): 归还前必须复位连接状态, 否则下个借用者继承脏连接
    // —— 残留未提交事务 (SQLite: "cannot start a transaction within a transaction";
    //   PG/MySQL: 可能读到上一调用方未提交的中间数据甚至把别人的 DML 一起提交)
    //   以及隔离级别泄漏. 必须在持 FPool.FLock 前做事务复位 (复位本身是连接级操作,
    //   不涉及池状态), 然后再持锁置 csIdle, 保证复位与空闲可见性原子.
    ResetConnectionState;
    FPool.FLock.Enter;
    try
      FState := csIdle;
      FLastUsedAt := Now;
      FOwnerThreadId := 0;
      FLeakWarned := False;
      // BUG EXP-P1-014 fix: signal availability WHILE holding the pool lock.
      // If SetEvent were called outside the lock, a concurrent waiter could
      // (a) acquire the lock, find this connection csIdle + in-use it, and
      // then (b) see SetEvent fire afterwards - the signal would be wasted
      // because no idle connection remains (lost-wakeup / missed-signal).
      // Holding the lock during SetEvent ensures the waiter that observes
      // csIdle also observes the corresponding signal, and vice-versa.
      FPool.FAvailableEvent.SetEvent;
    finally
      FPool.FLock.Leave;
    end;
    FPool.DoPoolEvent(peConnectionReleased, Format('Connection released, use time: %.2f sec',
      [LUseTime.TotalSeconds]));
    FPool.FStatsLock.Enter;
    try
      Inc(FPool.FStatistics.TotalReleases);
    finally
      FPool.FStatsLock.Leave;
    end;
  end;
end;
procedure TPooledConnection.Invalidate;
begin
  FState := csInvalid;
  if Assigned(FPool) then
    FPool.DoPoolEvent(peConnectionInvalidated, 'Connection marked invalid');
end;

// DATA-R3-001 (BUG-431): 归还连接前复位脏状态. 回滚调用方残留的未提交事务,
// 防止下个借用者继承脏事务 (SQLite 报 "cannot start a transaction within a
// transaction"; PG/MySQL 可能读到中间数据或连带提交他人 DML). 同时重置隔离级别到
// 连接配置默认值, 防止调用方临时提升隔离级别后泄漏给后续借用者.
// 异常容忍: 任一步失败不阻断归还 (连接仍置空闲/失效由 IsValid 探活兜底),
// 仅记录事件, 避免复位失败导致连接泄漏 (卡在 csInUse).
procedure TPooledConnection.ResetConnectionState;
begin
  if not Assigned(FConnection) then
    Exit;
  try
    // 1. 回滚残留事务 —— 最关键. 不 Commit 是因为残留事务几乎都是异常路径
    //    遗留的未完成工作, 提交会把脏数据落库.
    if FConnection.InTransaction then
    begin
      FConnection.Rollback;
      if Assigned(FPool) then
        FPool.DoPoolEvent(peConnectionReleased,
          'Rolled back leftover transaction on release');
    end;
    // 2. 重置事务隔离级别到读取当前配置 (FireDAC 在下次 BeginTransaction 时按
    //    TxOptions 应用; 此处确保 TxOptions 反映池配置, 调用方临时改隔离级别后复位).
    FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit;
  except
    on E: Exception do
      if Assigned(FPool) then
        FPool.DoPoolEvent(peConnectionInvalidated,
          'ResetConnectionState failed: ' + E.Message);
  end;
end;
function TPooledConnection.Validate: Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    FState := csInvalid;
    Exit;
  end;

  // State should already be csValidating when called from maintenance.
  // If called directly, set it now.
  if FState <> csValidating then
    FState := csValidating;

  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := FPool.FConfig.ValidationQuery;
      // DATA2-055 fix: apply a bounded timeout to the validation query.
      // Without this, a network-partitioned DB or blocked socket keeps
      // Query.Open waiting indefinitely while FState = csValidating,
      // permanently shrinking the usable pool and potentially wedging the
      // maintenance thread. We prefer the profile-level command timeout;
      // if none is configured we fall back to 5s, which is long enough for
      // any "SELECT 1"-style probe but short enough that a hung connection
      // is invalidated promptly.
      if Assigned(FPool) and (FPool.FProfile.CommandTimeoutSec > 0) then
        Query.ResourceOptions.CmdExecTimeout := FPool.FProfile.CommandTimeoutSec * 1000
      else
        Query.ResourceOptions.CmdExecTimeout := 5000;
      Query.Open;
      Query.Close;
      Result := True;
      FLastValidatedAt := Now;
      FState := csIdle;
      if Assigned(FPool) then
      begin
        FPool.DoPoolEvent(peConnectionValidated, 'Connection validated');
        FPool.FStatsLock.Enter;
        try
          Inc(FPool.FStatistics.TotalValidations);
        finally
          FPool.FStatsLock.Leave;
        end;
      end;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FState := csInvalid;
      if Assigned(FPool) then
        FPool.DoPoolEvent(peConnectionInvalidated, 'Connection validation failed: ' + E.Message);
    end;
  end;
end;

procedure TPooledConnection.SetStateForTest(AState: TConnectionState);
begin
  FState := AState;
end;

function TPooledConnection.GetIsValid: Boolean;
begin
  Result := (FState <> csInvalid) and Assigned(FConnection) and FConnection.Connected;
end;

function TPooledConnection.GetIdleTime: TTimeSpan;
begin
  if FState = csIdle then
    Result := TTimeSpan.FromSeconds(SecondsBetween(Now, FLastUsedAt))
  else
    Result := TTimeSpan.Zero;
end;

function TPooledConnection.GetUseTime: TTimeSpan;
begin
  if FState = csInUse then
    Result := TTimeSpan.FromSeconds(SecondsBetween(Now, FAcquiredAt))
  else
    Result := TTimeSpan.Zero;
end;

{ TUniConnectionPool }

constructor TUniConnectionPool.Create;
begin
  inherited Create;
  FDatabaseType := dbSQLite;
  FConnectionString := '';
  FProfile := TDBConnectionProfile.SQLite('');
  FUseProfile := False;
  FConfig := TPoolConfig.Default;
  FInitialized := False;
  SetIsShuttingDown(False);
  FStartTime := Now;

  FPool := TObjectList<TPooledConnection>.Create(True);
  FLock := TCriticalSection.Create;
  FStatsLock := TCriticalSection.Create;
  FAvailableEvent := TEvent.Create(nil, True, True, '');
  FMaintenanceWakeEvent := TEvent.Create(nil, True, False, '');

  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

destructor TUniConnectionPool.Destroy;
begin
  Shutdown;

  FreeAndNil(FPool);
  FreeAndNil(FLock);
  FreeAndNil(FStatsLock);
  FreeAndNil(FAvailableEvent);
  FreeAndNil(FMaintenanceWakeEvent);

  if Assigned(FFDDriverLink) then
    FreeAndNil(FFDDriverLink);
  if Assigned(FFDManager) then
    FreeAndNil(FFDManager);

  inherited;
end;

procedure TUniConnectionPool.Configure(const AProfile: TDBConnectionProfile);
begin
  if FInitialized then
    raise EInvalidOperationException.Create('Cannot configure pool after initialization');

  AProfile.Validate;
  FProfile := AProfile;
  FUseProfile := True;
  FDatabaseType := AProfile.DatabaseType;

  case AProfile.DatabaseType of
    dbSQLite:
      FConnectionString := AProfile.Database;
    dbPostgreSQL:
      FConnectionString := Format('%s;%d;%s;%s;%s',
        [AProfile.Host, AProfile.Port, AProfile.Database,
         AProfile.Username, AProfile.Password]);
  else
    FConnectionString := AProfile.Database;
  end;

  case AProfile.DatabaseType of
    dbSQLite, dbMySQL, dbPostgreSQL, dbSQLServer:
      FConfig.ValidationQuery := 'SELECT 1';
    dbOracle:
      FConfig.ValidationQuery := 'SELECT 1 FROM DUAL';
    dbFirebird, dbInterBase:
      FConfig.ValidationQuery := 'SELECT 1 FROM RDB$DATABASE';
  end;
end;

procedure TUniConnectionPool.Initialize;
begin
  if FInitialized then
    Exit;

  FLock.Enter;
  try
    if FInitialized then
      Exit;

    SetIsShuttingDown(False);
    if Assigned(FMaintenanceWakeEvent) then
      FMaintenanceWakeEvent.ResetEvent;

    // Use FireDAC global manager.
    // Creating a dedicated TFDManager alongside existing app-level FireDAC components
    // can cause unstable manager state in multi-module apps.
    FFDManager := nil;

    // 创建驱动链接
    case FDatabaseType of
      dbSQLite:
        FFDDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
      dbPostgreSQL:
        FFDDriverLink := TFDPhysPgDriverLink.Create(nil);
    else
      FFDDriverLink := nil;
    end;

    // 预热最小连接数
    DoWarmup(FConfig.MinSize);

    FInitialized := True;
    FStartTime := Now;

    // 启动维护线程
    FMaintenanceThread := TThread.CreateAnonymousThread(MaintenanceLoop);
    FMaintenanceThread.FreeOnTerminate := False;
    FMaintenanceThread.Start;

    DoPoolEvent(peConnectionCreated, Format('Connection pool initialized, warmed up %d connection(s)', [FConfig.MinSize]));
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.Shutdown;
var
  I: Integer;
  DrainStart: TDateTime;
  HasActive: Boolean;
  SkippedInUse: Integer;
  ToRemove: TList<Integer>;
begin
  if not FInitialized then
    Exit;

  SetIsShuttingDown(True);

  // Stop maintenance thread
  if Assigned(FMaintenanceThread) then
  begin
    FMaintenanceThread.Terminate;
    if Assigned(FMaintenanceWakeEvent) then
      FMaintenanceWakeEvent.SetEvent;
    // DATA2-057: bounded wait so a stuck/suspended maintenance thread
    // cannot hang Shutdown indefinitely.
    {$IFDEF MSWINDOWS}
    if Winapi.Windows.WaitForSingleObject(FMaintenanceThread.Handle, 5000) = WAIT_TIMEOUT then
    begin
      {$IFDEF DEBUG}
      Winapi.Windows.OutputDebugString('DeepBase.DB.Pool: maintenance thread did not exit within 5 s during shutdown');
      {$ENDIF}
    end
    else
      FMaintenanceThread.WaitFor;
    {$ELSE}
    FMaintenanceThread.WaitFor;
    {$ENDIF}
    FreeAndNil(FMaintenanceThread);
  end;

  // Drain: wait up to AcquireTimeoutMs for active connections to be released.
  DrainStart := Now;
  repeat
    HasActive := False;
    FLock.Enter;
    try
      for I := 0 to FPool.Count - 1 do
        if FPool[I].State = csInUse then
        begin
          HasActive := True;
          Break;
        end;
    finally
      FLock.Leave;
    end;

    if HasActive then
      Sleep(50);
  until (not HasActive) or
        (MilliSecondsBetween(Now, DrainStart) >= FConfig.AcquireTimeoutMs);

  // WO-20260902 FIX-1: release only non-in-use connections. Leaking an
  // in-use TPooledConnection at shutdown is preferable to freeing it while
  // the borrower still holds a reference (UAF / heap corruption).
  ToRemove := TList<Integer>.Create;
  try
    FLock.Enter;
    try
      FInitialized := False;
      SkippedInUse := 0;
      for I := FPool.Count - 1 downto 0 do
      begin
        if FPool[I].State = csInUse then
        begin
          Inc(SkippedInUse);
          {$IFDEF DEBUG}
          OutputDebugString(PChar(Format(
            'DeepBase.DB.Pool: Shutdown skipped csInUse connection (AcquireCount=%d) — intentional leak to avoid UAF',
            [FPool[I].AcquireCount])));
          {$ENDIF}
        end
        else
          ToRemove.Add(I);
      end;

      for I in ToRemove do
        FPool.Delete(I);

      if SkippedInUse > 0 then
        DoPoolEvent(peConnectionDestroyed,
          Format('Connection pool shut down; %d csInUse connection(s) deliberately retained (leak > UAF)',
            [SkippedInUse]))
      else
        DoPoolEvent(peConnectionDestroyed, 'Connection pool shut down');
    finally
      FLock.Leave;
    end;
  finally
    ToRemove.Free;
  end;
end;

{ TUniConnectionPool }

function TUniConnectionPool.GetIsShuttingDown: Boolean;
begin
  // DATA2-060: atomic read with full memory barrier for cross-thread visibility.
  Result := TInterlocked.CompareExchange(FShutdown, 0, 0) <> 0;
end;

procedure TUniConnectionPool.SetIsShuttingDown(Value: Boolean);
begin
  // DATA2-060: atomic write with full memory barrier.
  TInterlocked.Exchange(FShutdown, Ord(Value));
end;

function TUniConnectionPool.GetDriverName: string;
begin
  case FDatabaseType of
    dbSQLite:     Result := 'SQLite';
    dbMySQL:      Result := 'MySQL';
    dbPostgreSQL: Result := 'PG';
    dbSQLServer:  Result := 'MSSQL';
    dbOracle:     Result := 'Ora';
    dbFirebird:   Result := 'FB';
    dbInterBase:  Result := 'IB';
  else
    Result := 'SQLite';
  end;
end;

procedure TUniConnectionPool.SetDatabaseType(const Value: TDatabaseType);
begin
  if FInitialized then
    raise EInvalidOperationException.Create('Cannot change database type after initialization');
  FDatabaseType := Value;
  FProfile.DatabaseType := Value;
  FUseProfile := False;

  // 设置默认验证查询
  case Value of
    dbSQLite, dbMySQL, dbPostgreSQL, dbSQLServer:
      FConfig.ValidationQuery := 'SELECT 1';
    dbOracle:
      FConfig.ValidationQuery := 'SELECT 1 FROM DUAL';
    dbFirebird, dbInterBase:
      FConfig.ValidationQuery := 'SELECT 1 FROM RDB$DATABASE';
  end;
end;

procedure TUniConnectionPool.SetConnectionString(const Value: string);
begin
  if FInitialized then
    raise EInvalidOperationException.Create('Cannot change connection string after initialization');
  FConnectionString := Value;
  FUseProfile := False;
end;

function TUniConnectionPool.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
    Result.Open;
    FStatsLock.Enter;
    try
      Inc(FStatistics.TotalCreates);
    finally
      FStatsLock.Leave;
    end;
    DoPoolEvent(peConnectionCreated, 'Created new connection');
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDatabaseException.CreateFmt('Failed to create database connection: %s', [E.Message]);
    end;
  end;
end;

function TUniConnectionPool.CreateUnopenedConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
  except
    Result.Free;
    raise;
  end;
end;

function SplitConnStrRight(const S: string; FieldCount: Integer): TArray<string>;
begin
  SetLength(Result, FieldCount);
  var Remaining := S;
  for var I := FieldCount - 1 downto 1 do
  begin
    var Sep := Remaining.LastDelimiter(';');
    if Sep < 0 then
    begin
      Result[I] := Remaining;
      SetLength(Result, I + 1);
      Exit;
    end;
    Result[I] := Remaining.Substring(Sep + 1);
    Remaining := Remaining.Substring(0, Sep);
  end;
  Result[0] := Remaining;
end;

procedure TUniConnectionPool.ApplyExtraParams(Conn: TFDConnection;
  const ExtraParams: string);
var
  Items: TArray<string>;
  Item: string;
  Sep: Integer;
  Key, Value: string;
begin
  if ExtraParams = '' then
    Exit;

  Items := ExtraParams.Split([';']);
  for Item in Items do
  begin
    if Trim(Item) = '' then
      Continue;

    Sep := Item.IndexOf('=');
    if Sep <= 0 then
      Continue;

    Key := Trim(Item.Substring(0, Sep));
    Value := Trim(Item.Substring(Sep + 1));
    if Key <> '' then
      Conn.Params.Values[Key] := Value;
  end;
end;

procedure TUniConnectionPool.ConfigureConnectionFromProfile(Conn: TFDConnection);
begin
  Conn.DriverName := GetDriverName;

  case FProfile.DatabaseType of
    dbSQLite:
      begin
        Conn.Params.Database := FProfile.Database;
        Conn.Params.Values['LockingMode'] := FProfile.SQLiteLockingMode;
        Conn.Params.Values['Synchronous'] := FProfile.SQLiteSynchronous;
        Conn.Params.Values['JournalMode'] := FProfile.SQLiteJournalMode;
        Conn.Params.Values['OpenMode'] := FProfile.SQLiteOpenMode;
      end;

    dbPostgreSQL:
      begin
        Conn.Params.Values['Server'] := FProfile.Host;
        Conn.Params.Values['Port'] := IntToStr(FProfile.Port);
        Conn.Params.Database := FProfile.Database;
        Conn.Params.UserName := FProfile.Username;
        Conn.Params.Password := FProfile.Password;
        Conn.Params.Values['CharacterSet'] := FProfile.CharacterSet;
        Conn.Params.Values['ApplicationName'] := FProfile.ApplicationName;
        if FProfile.SSLMode <> '' then
          Conn.Params.Values['PGAdvanced'] := 'sslmode=' + FProfile.SSLMode;
        if FProfile.ConnectTimeoutSec > 0 then
          Conn.Params.Values['LoginTimeout'] := IntToStr(FProfile.ConnectTimeoutSec);
        if FProfile.VendorLib <> '' then
          Conn.Params.Values['VendorLib'] := FProfile.VendorLib;
        if FProfile.Pooled then
        begin
          Conn.Params.Values['Pooled'] := 'True';
          if FProfile.PoolMaxItems > 0 then
            Conn.Params.Values['POOL_MaximumItems'] := IntToStr(FProfile.PoolMaxItems);
        end;
      end;
  else
    begin
      Conn.Params.Database := FProfile.Database;
      if FProfile.Host <> '' then
        Conn.Params.Values['Server'] := FProfile.Host;
      if FProfile.Port > 0 then
        Conn.Params.Values['Port'] := IntToStr(FProfile.Port);
      if FProfile.Username <> '' then
        Conn.Params.UserName := FProfile.Username;
      if FProfile.Password <> '' then
        Conn.Params.Password := FProfile.Password;
    end;
  end;

  ApplyExtraParams(Conn, FProfile.ExtraParams);
end;

procedure TUniConnectionPool.ConfigureConnection(Conn: TFDConnection);
begin
  if FUseProfile then
  begin
    ConfigureConnectionFromProfile(Conn);
    Conn.LoginPrompt := False;
    Conn.TxOptions.AutoCommit := FConfig.AutoCommit;
    Conn.ResourceOptions.AutoReconnect := True;
    Conn.ResourceOptions.KeepConnection := True;
    if FProfile.CommandTimeoutSec > 0 then
      Conn.ResourceOptions.CmdExecTimeout := FProfile.CommandTimeoutSec * 1000;
    Exit;
  end;

  Conn.DriverName := GetDriverName;

  case FDatabaseType of
    dbSQLite:
      begin
        Conn.Params.Database := FConnectionString;
        Conn.Params.Values['LockingMode'] := 'Normal';
        Conn.Params.Values['Synchronous'] := 'Normal';
        Conn.Params.Values['JournalMode'] := 'WAL';
        Conn.Params.Values['OpenMode'] := 'CreateUTF8';
      end;

    dbMySQL:
      begin
        // 格式: server;port;database;user;password (password last, may contain ';')
        var Parts := SplitConnStrRight(FConnectionString, 5);
        if Length(Parts) >= 5 then
        begin
          Conn.Params.Values['Server'] := Parts[0];
          Conn.Params.Values['Port'] := Parts[1];
          Conn.Params.Database := Parts[2];
          Conn.Params.UserName := Parts[3];
          Conn.Params.Password := Parts[4];
        end
        else
          Conn.Params.Database := FConnectionString;
        Conn.Params.Values['CharacterSet'] := 'utf8mb4';
      end;

    dbPostgreSQL:
      begin
        var Parts := SplitConnStrRight(FConnectionString, 5);
        if Length(Parts) >= 5 then
        begin
          Conn.Params.Values['Server'] := Parts[0];
          Conn.Params.Values['Port'] := Parts[1];
          Conn.Params.Database := Parts[2];
          Conn.Params.UserName := Parts[3];
          Conn.Params.Password := Parts[4];
        end
        else
          Conn.Params.Database := FConnectionString;
        Conn.Params.Values['CharacterSet'] := 'UTF8';
      end;

    dbSQLServer:
      begin
        var Parts := SplitConnStrRight(FConnectionString, 4);
        if Length(Parts) >= 4 then
        begin
          Conn.Params.Values['Server'] := Parts[0];
          Conn.Params.Database := Parts[1];
          Conn.Params.UserName := Parts[2];
          Conn.Params.Password := Parts[3];
        end
        else
          Conn.Params.Database := FConnectionString;
      end;

    dbOracle:
      begin
        var Parts := SplitConnStrRight(FConnectionString, 3);
        if Length(Parts) >= 3 then
        begin
          Conn.Params.Database := Parts[0];
          Conn.Params.UserName := Parts[1];
          Conn.Params.Password := Parts[2];
        end
        else
          Conn.Params.Database := FConnectionString;
      end;

    dbFirebird, dbInterBase:
      begin
        var Parts := SplitConnStrRight(FConnectionString, 4);
        if Length(Parts) >= 4 then
        begin
          Conn.Params.Database := Parts[0];
          Conn.Params.UserName := Parts[1];
          Conn.Params.Password := Parts[2];
          Conn.Params.Values['CharacterSet'] := 'UTF8';
        end
        else
          Conn.Params.Database := FConnectionString;
      end;
  end;

  // 通用设置
  Conn.LoginPrompt := False;
  Conn.TxOptions.AutoCommit := FConfig.AutoCommit;
  Conn.ResourceOptions.AutoReconnect := True;
  Conn.ResourceOptions.KeepConnection := True;
end;

function TUniConnectionPool.FindAvailableConnection: TPooledConnection;
var
  I: Integer;
  Pooled: TPooledConnection;
begin
  Result := nil;

  for I := 0 to FPool.Count - 1 do
  begin
    Pooled := FPool[I];
    if Pooled.State = csIdle then
    begin
      if Pooled.IsValid then
      begin
        Result := Pooled;
        Exit;
      end
      else
      begin
        // 无效连接，标记移�?
        Pooled.Invalidate;
      end;
    end;
  end;
end;

function TUniConnectionPool.GetConnection: TPooledConnection;
begin
  if not TryGetConnection(FConfig.AcquireTimeoutMs, Result) then
  begin
    FStatsLock.Enter;
    try
      Inc(FStatistics.TotalTimeouts);
    finally
      FStatsLock.Leave;
    end;
    DoPoolEvent(pePoolExhausted, 'Connection pool exhausted; acquisition timed out');
    raise EConnectionTimeoutException.Create('Database connection acquisition timeout');
  end;
end;

function TUniConnectionPool.TryGetConnection(TimeoutMs: Cardinal;
  out Conn: TPooledConnection): Boolean;
var
  Stopwatch: TStopwatch;
  ElapsedMs: Int64;
  Pooled: TPooledConnection;
begin
  Result := False;
  Conn := nil;

  if not FInitialized then
    raise EPoolNotInitializedException.Create('Connection pool not initialized');

  Stopwatch := TStopwatch.StartNew;

  while not GetIsShuttingDown do
  begin
    FLock.Enter;
    try
      // 查找可用连接
      Pooled := FindAvailableConnection;

      if Pooled <> nil then
      begin
        Pooled.FState := csInUse;
        Pooled.FAcquiredAt := Now;
        Pooled.FOwnerThreadId := TThread.CurrentThread.ThreadID;
        Inc(Pooled.FAcquireCount);
        Conn := Pooled;
        Result := True;

        // 更新统计
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalAcquires);
          var WaitMs := Stopwatch.ElapsedMilliseconds;
          if WaitMs > FStatistics.MaxWaitTimeMs then
            FStatistics.MaxWaitTimeMs := WaitMs;
          // 计算移动平均
          FStatistics.AverageWaitTimeMs :=
            (FStatistics.AverageWaitTimeMs * (FStatistics.TotalAcquires - 1) + WaitMs)
            / FStatistics.TotalAcquires;
        finally
          FStatsLock.Leave;
        end;

        DoPoolEvent(peConnectionAcquired, Format('连接获取成功, 等待 %d ms', [Stopwatch.ElapsedMilliseconds]));
        Exit;
      end;

      // 无可用连接，尝试创建新连�?
      if FPool.Count < FConfig.MaxSize then
      begin
        try
          Pooled := TPooledConnection.Create(Self, CreateConnection);
          Pooled.FState := csInUse;
          Pooled.FAcquiredAt := Now;
          Pooled.FOwnerThreadId := TThread.CurrentThread.ThreadID;
          Inc(Pooled.FAcquireCount);
          FPool.Add(Pooled);
          Conn := Pooled;
          Result := True;

          FStatsLock.Enter;
          try
            Inc(FStatistics.TotalAcquires);
          finally
            FStatsLock.Leave;
          end;

          DoPoolEvent(peConnectionAcquired, '创建新连接并获取');
          Exit;
        except
          on E: Exception do
            DoPoolEvent(peConnectionInvalidated, '创建连接失败: ' + E.Message);
        end;
      end;

      // 连接池已满，重置等待事件
      FAvailableEvent.ResetEvent;
    finally
      FLock.Leave;
    end;

    // 检查超�?
    ElapsedMs := Stopwatch.ElapsedMilliseconds;
    if ElapsedMs >= TimeoutMs then
      Exit(False);

    // 等待连接释放
    FAvailableEvent.WaitFor(Min(1000, TimeoutMs - Cardinal(ElapsedMs)));
  end;
end;

procedure TUniConnectionPool.Execute(Proc: TProc<TFDConnection>);
var
  Conn: TPooledConnection;
begin
  Conn := GetConnection;
  try
    Proc(Conn.Connection);
  finally
    Conn.Release;
  end;
end;

function TUniConnectionPool.Query<T>(Func: TFunc<TFDConnection, T>): T;
var
  Conn: TPooledConnection;
begin
  Conn := GetConnection;
  try
    Result := Func(Conn.Connection);
  finally
    Conn.Release;
  end;
end;

procedure TUniConnectionPool.ClearIdleConnections;
var
  I: Integer;
begin
  FLock.Enter;
  try
    for I := FPool.Count - 1 downto 0 do
    begin
      if FPool[I].State = csIdle then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalDestroys);
        finally
          FStatsLock.Leave;
        end;
        DoPoolEvent(peConnectionDestroyed, 'Connection destroyed');
        FPool.Delete(I);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.RecycleAllConnections;
var
  I: Integer;
begin
  FLock.Enter;
  try
    // Only recycle idle and invalid connections.
    // csValidating connections are currently being validated by the
    // maintenance thread outside of FLock (see ValidateIdleConnections);
    // freeing them here would cause a use-after-free on that thread.
    // REVIEW5-DATA-004
    for I := FPool.Count - 1 downto 0 do
    begin
      if FPool[I].State in [csIdle, csInvalid] then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalDestroys);
        finally
          FStatsLock.Leave;
        end;
        FPool.Delete(I);
      end;
    end;
  finally
    FLock.Leave;
  end;

  DoPoolEvent(peConnectionDestroyed, 'Idle connections recycled');

  // Replenish minimum connections
  Warmup(FConfig.MinSize);
end;

function TUniConnectionPool.GetStatistics: TPoolStatistics;
begin
  // CR-013: 锁序必须与其余路径一致（FLock → FStatsLock）。
  // 原实现反向嵌套（FStatsLock → FLock）与 TryGetConnection/Recycle 等
  // 形成 ABBA 死锁。
  FLock.Enter;
  try
    FStatsLock.Enter;
    try
      Result := FStatistics;
      // 更新实时数据
      Result.TotalConnections := FPool.Count;
      Result.ActiveConnections := 0;
      Result.IdleConnections := 0;
      for var I := 0 to FPool.Count - 1 do
      begin
        if FPool[I].State = csInUse then
          Inc(Result.ActiveConnections)
        else if FPool[I].State = csIdle then
          Inc(Result.IdleConnections);
      end;
      Result.PoolUptime := TTimeSpan.FromSeconds(SecondsBetween(Now, FStartTime));
    finally
      FStatsLock.Leave;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.ResetStatistics;
begin
  FStatsLock.Enter;
  try
    FillChar(FStatistics, SizeOf(FStatistics), 0);
    FStartTime := Now;
  finally
    FStatsLock.Leave;
  end;
end;

procedure TUniConnectionPool.DoWarmup(Count: Integer);
var
  I, Target, CurrentCount, ToCreate: Integer;
  Pooled: TPooledConnection;
  NewConns: array of TFDConnection;
begin
  if Count <= 0 then
    Target := FConfig.MinSize
  else
    Target := Min(Count, FConfig.MaxSize);

  // DATA2-058: determine how many connections are needed under lock, then
  // release it before doing the network I/O of connection setup.
  FLock.Enter;
  try
    CurrentCount := FPool.Count;
    if CurrentCount >= Target then
      ToCreate := 0
    else
      ToCreate := Target - CurrentCount;
  finally
    FLock.Leave;
  end;

  if ToCreate <= 0 then
    Exit;

  // Create connections outside the lock to avoid blocking pool operations.
  SetLength(NewConns, ToCreate);
  for I := 0 to ToCreate - 1 do
  begin
    try
      NewConns[I] := CreateConnection;
    except
      on E: Exception do
      begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.DB.Pool: Warmup connection creation failed: ' + E.Message));
        {$ENDIF}
        Break;
      end;
    end;
  end;

  // Re-acquire lock to add new connections to the pool.
  FLock.Enter;
  try
    for I := 0 to High(NewConns) do
    begin
      if NewConns[I] = nil then
        Continue;
      if GetIsShuttingDown then
      begin
        FreeAndNil(NewConns[I]);
        Continue;
      end;
      Pooled := TPooledConnection.Create(Self, NewConns[I]);
      FPool.Add(Pooled);
      NewConns[I] := nil;
    end;
  finally
    FLock.Leave;
  end;

  // Free any leftover connections that couldn't be added.
  for I := 0 to High(NewConns) do
    if NewConns[I] <> nil then
      NewConns[I].Free;
end;

procedure TUniConnectionPool.Warmup(Count: Integer);
begin
  // DATA2-058: DoWarmup manages its own locking internally.
  DoWarmup(Count);
end;

procedure TUniConnectionPool.DoPoolEvent(EventType: TPoolEventType;
  const Msg: string);
begin
  if Assigned(FOnPoolEvent) then
  begin
    try
      FOnPoolEvent(Self, EventType, Msg);
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.DB.Pool: OnPoolEvent handler error: ' + E.Message));
        {$ENDIF}
    end;
  end;
end;

procedure TUniConnectionPool.MaintenanceLoop;
begin
  while not GetIsShuttingDown and not TThread.Current.CheckTerminated do
  begin
    if Assigned(FMaintenanceWakeEvent) then
      FMaintenanceWakeEvent.WaitFor(10000)
    else
      Sleep(10000); // fallback if construction failed before the event was created

    if GetIsShuttingDown or TThread.Current.CheckTerminated then
      Break;

    PerformMaintenance;
  end;
end;

procedure TUniConnectionPool.PerformMaintenance;
begin
  ValidateIdleConnections;
  RemoveExpiredConnections;
  DetectLeaks;
  EnsureMinConnections;
end;

procedure TUniConnectionPool.ValidateIdleConnections;
var
  I: Integer;
  Pooled: TPooledConnection;
  ToValidate: TList<TPooledConnection>;
begin
  ToValidate := TList<TPooledConnection>.Create;
  try
    FLock.Enter;
    try
      for I := 0 to FPool.Count - 1 do
      begin
        Pooled := FPool[I];
        if Pooled.State = csIdle then
        begin
          if SecondsBetween(Now, Pooled.FLastValidatedAt) >= FConfig.ValidationIntervalSec then
          begin
            // Transition to csValidating under lock so no other thread can
            // acquire this connection while we validate it outside the lock.
            Pooled.FState := csValidating;
            ToValidate.Add(Pooled);
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;

    // Validate outside lock (may involve network I/O).
    for Pooled in ToValidate do
    begin
      if not Pooled.Validate then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalInvalidations);
        finally
          FStatsLock.Leave;
        end;
        // State already set to csInvalid by Validate on failure.
      end;
      // On success, Validate sets state back to csIdle.
    end;
  finally
    ToValidate.Free;
  end;
end;

procedure TUniConnectionPool.RemoveExpiredConnections;
var
  I: Integer;
  Pooled: TPooledConnection;
begin
  FLock.Enter;
  try
    for I := FPool.Count - 1 downto 0 do
    begin
      Pooled := FPool[I];

      // 移除无效连接
      if Pooled.State = csInvalid then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalDestroys);
        finally
          FStatsLock.Leave;
        end;
        FPool.Delete(I);
        Continue;
      end;

      // 移除超过最大生命周期的连接
      if (Pooled.State = csIdle) and
         (SecondsBetween(Now, Pooled.CreatedAt) >= FConfig.MaxLifetimeSec) then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalDestroys);
        finally
          FStatsLock.Leave;
        end;
        DoPoolEvent(peConnectionDestroyed, 'Connection destroyed');
        FPool.Delete(I);
        Continue;
      end;

      // 移除空闲超时的连接（保持最小连接数）
      if (FPool.Count > FConfig.MinSize) and
         (Pooled.State = csIdle) and
         (SecondsBetween(Now, Pooled.LastUsedAt) >= FConfig.IdleTimeoutSec) then
      begin
        FStatsLock.Enter;
        try
          Inc(FStatistics.TotalDestroys);
        finally
          FStatsLock.Leave;
        end;
        DoPoolEvent(peConnectionDestroyed, 'Connection destroyed');
        FPool.Delete(I);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.DetectLeaks;
var
  I: Integer;
  Pooled: TPooledConnection;
begin
  FLock.Enter;
  try
    for I := 0 to FPool.Count - 1 do
    begin
      Pooled := FPool[I];
      if (Pooled.State = csInUse) and
         (not Pooled.FLeakWarned) and
         (SecondsBetween(Now, Pooled.FAcquiredAt) >= FConfig.LeakDetectionThresholdSec) then
      begin
        Pooled.FLeakWarned := True;
        FStatsLock.Enter;
        try
          Inc(FStatistics.LeaksDetected);
        finally
          FStatsLock.Leave;
        end;
        DoPoolEvent(peConnectionLeakDetected,
          Format('Possible connection leak detected. Thread: %d, held for: %d sec',
            [Pooled.FOwnerThreadId, SecondsBetween(Now, Pooled.FAcquiredAt)]));
      end;
    end;
  finally
    FLock.Leave;
  end;
end;
procedure TUniConnectionPool.EnsureMinConnections;
var
  NeedCount: Integer;
  I: Integer;
  NewConnections: array of TFDConnection;
begin
  NeedCount := 0;
  FLock.Enter;
  try
    if FPool.Count < FConfig.MinSize then
      NeedCount := FConfig.MinSize - FPool.Count;
  finally
    FLock.Leave;
  end;

  if NeedCount <= 0 then
    Exit;

  // DATA2-059: create connections outside the lock, then re-validate pool
  // state before adding. Between releasing and re-acquiring the lock another
  // thread may have added connections or shutdown may have started.
  SetLength(NewConnections, NeedCount);
  for I := 0 to NeedCount - 1 do
  begin
    try
      NewConnections[I] := CreateConnection;
    except
      on E: Exception do
      begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar('DeepBase.DB.Pool: EnsureMin connection creation failed: ' + E.Message));
        {$ENDIF}
        Break;
      end;
    end;
  end;

  FLock.Enter;
  try
    for I := 0 to High(NewConnections) do
    begin
      if NewConnections[I] = nil then
        Continue;

      // DATA2-059 TOCTOU re-check: discard if shutdown started or pool
      // already at/above minimum.
      if (not GetIsShuttingDown) and (FPool.Count < FConfig.MinSize) then
        FPool.Add(TPooledConnection.Create(Self, NewConnections[I]))
      else
        NewConnections[I].Free;

      NewConnections[I] := nil;
    end;
  finally
    FLock.Leave;
  end;

  // Free any connections that were not adopted (e.g. lock acquisition failed).
  for I := 0 to High(NewConnections) do
    if NewConnections[I] <> nil then
      NewConnections[I].Free;
end;

{ TPoolManager }

function SamePoolConfig(const Left, Right: TPoolConfig): Boolean;
begin
  Result :=
    (Left.MinSize = Right.MinSize) and
    (Left.MaxSize = Right.MaxSize) and
    (Left.AcquireTimeoutMs = Right.AcquireTimeoutMs) and
    (Left.IdleTimeoutSec = Right.IdleTimeoutSec) and
    (Left.MaxLifetimeSec = Right.MaxLifetimeSec) and
    (Left.ValidationIntervalSec = Right.ValidationIntervalSec) and
    (Left.LeakDetectionThresholdSec = Right.LeakDetectionThresholdSec) and
    (Left.ValidationQuery = Right.ValidationQuery) and
    (Left.AutoCommit = Right.AutoCommit);
end;

class constructor TPoolManager.Create;
begin
  FPools := TObjectDictionary<string, TUniConnectionPool>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

class destructor TPoolManager.Destroy;
begin
  ShutdownAll;
  FreeAndNil(FPools);
  FreeAndNil(FLock);
end;

class function TPoolManager.GetPool(const Name: string): TUniConnectionPool;
begin
  ValidatePoolName(Name);

  FLock.Enter;
  try
    if not FPools.TryGetValue(Name, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

class function TPoolManager.GetOrCreatePool(const Name: string;
  const Profile: TDBConnectionProfile;
  AutoInitialize: Boolean): TUniConnectionPool;
begin
  Result := GetOrCreatePool(Name, Profile, TPoolConfig.Default,
    AutoInitialize);
end;

class function TPoolManager.GetOrCreatePool(const Name: string;
  const Profile: TDBConnectionProfile; const Config: TPoolConfig;
  AutoInitialize: Boolean): TUniConnectionPool;
var
  ShouldInitialize: Boolean;
begin
  ValidatePoolName(Name);
  Profile.Validate;

  FLock.Enter;
  try
    if not FPools.TryGetValue(Name, Result) then
    begin
      Result := TUniConnectionPool.Create;
      try
        Result.Configure(Profile);
        Result.Config := Config;
        FPools.Add(Name, Result);
        ShouldInitialize := AutoInitialize;
      except
        Result.Free;
        raise;
      end;
    end
    else
    begin
      EnsureExistingPoolMatches(Name, Result, Profile, Config);
      ShouldInitialize := AutoInitialize and not Result.Initialized;
    end;
  finally
    FLock.Leave;
  end;

  if ShouldInitialize then
    Result.Initialize;
end;

class procedure TPoolManager.RegisterPool(const Name: string;
  Pool: TUniConnectionPool);
begin
  ValidatePoolName(Name);
  if not Assigned(Pool) then
    raise EInvalidOperationException.Create('Cannot register a nil database pool');

  FLock.Enter;
  try
    FPools.AddOrSetValue(Name, Pool);
  finally
    FLock.Leave;
  end;
end;

class procedure TPoolManager.RemovePool(const Name: string);
var
  Pool: TUniConnectionPool;
begin
  ValidatePoolName(Name);

  FLock.Enter;
  try
    if FPools.TryGetValue(Name, Pool) then
    begin
      if GDefaultPool = Pool then
        TInterlocked.Exchange(Pointer(GDefaultPool), nil);
      FPools.Remove(Name);
    end;
  finally
    FLock.Leave;
  end;
end;

class function TPoolManager.GetPoolNames: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FPools.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

class procedure TPoolManager.ShutdownAll;
var
  Pool: TUniConnectionPool;
begin
  FLock.Enter;
  try
    for Pool in FPools.Values do
      Pool.Shutdown;
    FPools.Clear;
    TInterlocked.Exchange(Pointer(GDefaultPool), nil);
  finally
    FLock.Leave;
  end;
end;

class procedure TPoolManager.ValidatePoolName(const Name: string);
begin
  if Trim(Name) = '' then
    raise EInvalidOperationException.Create('Database pool name cannot be empty');
end;

class procedure TPoolManager.EnsureExistingPoolMatches(const Name: string;
  Pool: TUniConnectionPool; const Profile: TDBConnectionProfile;
  const Config: TPoolConfig);
begin
  if not Pool.UsesProfile then
    raise EInvalidOperationException.CreateFmt(
      'Database pool "%s" already exists without an explicit profile', [Name]);

  if not Pool.Profile.SameConnectionAs(Profile) then
    raise EInvalidOperationException.CreateFmt(
      'Database pool "%s" already exists with a different connection profile', [Name]);

  if not SamePoolConfig(Pool.Config, Config) then
    raise EInvalidOperationException.CreateFmt(
      'Database pool "%s" already exists with a different pool configuration', [Name]);
end;

initialization
  GDBPoolProviderLock := TObject.Create;

finalization
  GDBPoolProvider := nil;
  FreeAndNil(GDBPoolProviderLock);

end.
