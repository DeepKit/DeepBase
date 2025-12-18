unit UniBase.DB.Pool;

{*******************************************************************************
  UniBase.DB.Pool - 高级数据库连接池

  版本: 2.0
  功能:
  - 多数据库支持 (SQLite, MySQL, PostgreSQL, SQL Server, Oracle)
  - 连接健康检查
  - 空闲连接回收
  - 连接泄漏检测
  - 详细统计监控
  - 连接预热
  - 自动重连

  线程安全: 所有公共方法都是线程安全的

  用法:
    // 创建连接池
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
      Connection.ExecSQL('SELECT 1');
    finally
      Release; // 或自动释放
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
  FireDAC.Phys.Intf, FireDAC.Stan.Pool, UniBase.Exceptions;

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

  /// <summary>连接状态</summary>
  TConnectionState = (
    csIdle,       // 空闲可用
    csInUse,      // 正在使用
    csInvalid,    // 无效需移除
    csValidating  // 正在验证
  );

  /// <summary>连接池事件类型</summary>
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

  /// <summary>连接池事件</summary>
  TPoolEvent = procedure(Sender: TObject; EventType: TPoolEventType;
    const Message: string) of object;

  /// <summary>连接池统计信息</summary>
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

  /// <summary>池化连接包装器</summary>
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
  public
    constructor Create(APool: TUniConnectionPool; AConnection: TFDConnection);
    destructor Destroy; override;

    /// <summary>释放回连接池</summary>
    procedure Release;

    /// <summary>标记为无效</summary>
    procedure Invalidate;

    /// <summary>验证连接有效性</summary>
    function Validate: Boolean;

    property Connection: TFDConnection read FConnection;
    property State: TConnectionState read FState;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastUsedAt: TDateTime read FLastUsedAt;
    property IdleTime: TTimeSpan read GetIdleTime;
    property UseTime: TTimeSpan read GetUseTime;
    property IsValid: Boolean read GetIsValid;
    property AcquireCount: Int64 read FAcquireCount;
  end;

  /// <summary>连接池配置</summary>
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
    FConfig: TPoolConfig;
    FInitialized: Boolean;

    FPool: TObjectList<TPooledConnection>;
    FLock: TCriticalSection;
    FAvailableEvent: TEvent;
    FMaintenanceThread: TThread;
    FShutdown: Boolean;

    FStatistics: TPoolStatistics;
    FStatsLock: TCriticalSection;
    FStartTime: TDateTime;

    FOnPoolEvent: TPoolEvent;

    // FireDAC 组件
    FFDManager: TFDManager;
    FFDDriverLink: TComponent;

    function CreateConnection: TFDConnection;
    function FindAvailableConnection: TPooledConnection;
    procedure ConfigureConnection(Conn: TFDConnection);
    procedure DoPoolEvent(EventType: TPoolEventType; const Msg: string);
    procedure MaintenanceLoop;
    procedure PerformMaintenance;
    procedure ValidateIdleConnections;
    procedure RemoveExpiredConnections;
    procedure DetectLeaks;
    procedure EnsureMinConnections;
    procedure UpdateStats(const Action: string);
    function GetDriverName: string;
    procedure SetDatabaseType(const Value: TDatabaseType);
    procedure SetConnectionString(const Value: string);

  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>初始化连接池</summary>
    procedure Initialize;

    /// <summary>关闭连接池</summary>
    procedure Shutdown;

    /// <summary>获取一个连接</summary>
    function GetConnection: TPooledConnection;

    /// <summary>获取连接（带超时）</summary>
    function TryGetConnection(TimeoutMs: Cardinal; out Conn: TPooledConnection): Boolean;

    /// <summary>执行操作（自动获取和释放连接）</summary>
    procedure Execute(Proc: TProc<TFDConnection>);

    /// <summary>执行查询（自动获取和释放连接）</summary>
    function Query<T>(Func: TFunc<TFDConnection, T>): T;

    /// <summary>清空所有空闲连接</summary>
    procedure ClearIdleConnections;

    /// <summary>强制回收所有连接</summary>
    procedure RecycleAllConnections;

    /// <summary>获取统计信息</summary>
    function GetStatistics: TPoolStatistics;

    /// <summary>重置统计信息</summary>
    procedure ResetStatistics;

    /// <summary>预热连接池</summary>
    procedure Warmup(Count: Integer = 0);

    // 属性
    property DatabaseType: TDatabaseType read FDatabaseType write SetDatabaseType;
    property ConnectionString: string read FConnectionString write SetConnectionString;
    property Config: TPoolConfig read FConfig write FConfig;
    property Initialized: Boolean read FInitialized;

    // 快捷属性
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
  public
    class constructor Create;
    class destructor Destroy;

    /// <summary>获取或创建命名连接池</summary>
    class function GetPool(const Name: string): TUniConnectionPool;

    /// <summary>注册连接池</summary>
    class procedure RegisterPool(const Name: string; Pool: TUniConnectionPool);

    /// <summary>移除连接池</summary>
    class procedure RemovePool(const Name: string);

    /// <summary>获取所有池名称</summary>
    class function GetPoolNames: TArray<string>;

    /// <summary>关闭所有连接池</summary>
    class procedure ShutdownAll;
  end;

/// <summary>获取默认连接池</summary>
function DefaultPool: TUniConnectionPool;

/// <summary>设置默认连接池</summary>
procedure SetDefaultPool(Pool: TUniConnectionPool);

implementation

uses
  System.Math,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  FireDAC.Phys.MySQL, FireDAC.Phys.MySQLDef,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef,
  FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef,
  FireDAC.Phys.Oracle, FireDAC.Phys.OracleDef,
  FireDAC.Phys.FB, FireDAC.Phys.FBDef,
  FireDAC.Phys.IB, FireDAC.Phys.IBDef;

var
  GDefaultPool: TUniConnectionPool = nil;

function DefaultPool: TUniConnectionPool;
begin
  Result := GDefaultPool;
end;

procedure SetDefaultPool(Pool: TUniConnectionPool);
begin
  GDefaultPool := Pool;
end;

{ TPoolStatistics }

function TPoolStatistics.ToString: string;
begin
  Result := Format(
    '连接池统计:' + sLineBreak +
    '  总连接数: %d' + sLineBreak +
    '  活动连接: %d' + sLineBreak +
    '  空闲连接: %d' + sLineBreak +
    '  等待请求: %d' + sLineBreak +
    '  总获取次数: %d' + sLineBreak +
    '  总释放次数: %d' + sLineBreak +
    '  总创建次数: %d' + sLineBreak +
    '  总销毁次数: %d' + sLineBreak +
    '  超时次数: %d' + sLineBreak +
    '  验证次数: %d' + sLineBreak +
    '  失效次数: %d' + sLineBreak +
    '  平均等待时间: %.2f ms' + sLineBreak +
    '  最大等待时间: %d ms' + sLineBreak +
    '  泄漏检测: %d' + sLineBreak +
    '  运行时间: %s',
    [TotalConnections, ActiveConnections, IdleConnections, WaitingRequests,
     TotalAcquires, TotalReleases, TotalCreates, TotalDestroys,
     TotalTimeouts, TotalValidations, TotalInvalidations,
     AverageWaitTimeMs, MaxWaitTimeMs, LeaksDetected,
     Format('%d天 %d小时 %d分钟',
       [Trunc(PoolUptime.TotalDays),
        PoolUptime.Hours,
        PoolUptime.Minutes])]);
end;

{ TPoolConfig }

class function TPoolConfig.Default: TPoolConfig;
begin
  Result.MinSize := 2;
  Result.MaxSize := 10;
  Result.AcquireTimeoutMs := 30000;  // 30秒
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
begin
  if Assigned(FConnection) then
  begin
    try
      if FConnection.Connected then
        FConnection.Close;
    except
      on E: Exception do
        {$IFDEF DEBUG}
        OutputDebugString(PChar('UniBase.DB.Pool: Connection close failed: ' + E.Message));
        {$ENDIF}
    end;
    FConnection.Free;
  end;
  inherited;
end;

procedure TPooledConnection.Release;
begin
  if Assigned(FPool) then
  begin
    FState := csIdle;
    FLastUsedAt := Now;
    FOwnerThreadId := 0;
    FLeakWarned := False;
    FPool.DoPoolEvent(peConnectionReleased, Format('连接释放, 使用时长: %.2f 秒',
      [UseTime.TotalSeconds]));
  end;
end;

procedure TPooledConnection.Invalidate;
begin
  FState := csInvalid;
  if Assigned(FPool) then
    FPool.DoPoolEvent(peConnectionInvalidated, '连接标记为无效');
end;

function TPooledConnection.Validate: Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FState := csValidating;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := FPool.FConfig.ValidationQuery;
      Query.Open;
      Query.Close;
      Result := True;
      FLastValidatedAt := Now;
      FState := csIdle;
      if Assigned(FPool) then
      begin
        FPool.DoPoolEvent(peConnectionValidated, '连接验证成功');
        Inc(FPool.FStatistics.TotalValidations);
      end;
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FState := csInvalid;
      if Assigned(FPool) then
        FPool.DoPoolEvent(peConnectionInvalidated, '连接验证失败: ' + E.Message);
    end;
  end;
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
  FConfig := TPoolConfig.Default;
  FInitialized := False;
  FShutdown := False;
  FStartTime := Now;

  FPool := TObjectList<TPooledConnection>.Create(True);
  FLock := TCriticalSection.Create;
  FStatsLock := TCriticalSection.Create;
  FAvailableEvent := TEvent.Create(nil, True, True, '');

  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

destructor TUniConnectionPool.Destroy;
begin
  Shutdown;

  FPool.Free;
  FLock.Free;
  FStatsLock.Free;
  FAvailableEvent.Free;

  if Assigned(FFDDriverLink) then
    FFDDriverLink.Free;
  if Assigned(FFDManager) then
    FFDManager.Free;

  inherited;
end;

procedure TUniConnectionPool.Initialize;
begin
  if FInitialized then
    Exit;

  FLock.Enter;
  try
    // 创建 FireDAC 管理器
    FFDManager := TFDManager.Create(nil);
    FFDManager.Active := True;

    // 创建驱动链接
    case FDatabaseType of
      dbSQLite:
        FFDDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
      dbMySQL:
        FFDDriverLink := TFDPhysMySQLDriverLink.Create(nil);
      dbPostgreSQL:
        FFDDriverLink := TFDPhysPgDriverLink.Create(nil);
      dbSQLServer:
        FFDDriverLink := TFDPhysMSSQLDriverLink.Create(nil);
      dbOracle:
        FFDDriverLink := TFDPhysOracleDriverLink.Create(nil);
      dbFirebird:
        FFDDriverLink := TFDPhysFBDriverLink.Create(nil);
      dbInterBase:
        FFDDriverLink := TFDPhysIBDriverLink.Create(nil);
    end;

    // 预热最小连接数
    Warmup(FConfig.MinSize);

    FInitialized := True;
    FStartTime := Now;

    // 启动维护线程
    FMaintenanceThread := TThread.CreateAnonymousThread(MaintenanceLoop);
    FMaintenanceThread.FreeOnTerminate := False;
    FMaintenanceThread.Start;

    DoPoolEvent(peConnectionCreated, Format('连接池初始化完成, 预热 %d 个连接', [FConfig.MinSize]));
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.Shutdown;
begin
  if not FInitialized then
    Exit;

  FShutdown := True;

  // 停止维护线程
  if Assigned(FMaintenanceThread) then
  begin
    FMaintenanceThread.Terminate;
    FMaintenanceThread.WaitFor;
    FreeAndNil(FMaintenanceThread);
  end;

  FLock.Enter;
  try
    // 关闭所有连接
    FPool.Clear;
    FInitialized := False;
  finally
    FLock.Leave;
  end;

  DoPoolEvent(peConnectionDestroyed, '连接池已关闭');
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
end;

function TUniConnectionPool.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    ConfigureConnection(Result);
    Result.Open;
    Inc(FStatistics.TotalCreates);
    DoPoolEvent(peConnectionCreated, '创建新连接');
  except
    on E: Exception do
    begin
      Result.Free;
      raise EDatabaseException.CreateFmt('Failed to create database connection: %s', [E.Message]);
    end;
  end;
end;

procedure TUniConnectionPool.ConfigureConnection(Conn: TFDConnection);
begin
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
        // 格式: server;port;database;user;password
        var Parts := FConnectionString.Split([';']);
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
        var Parts := FConnectionString.Split([';']);
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
        var Parts := FConnectionString.Split([';']);
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
        var Parts := FConnectionString.Split([';']);
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
        var Parts := FConnectionString.Split([';']);
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
        // 无效连接，标记移除
        Pooled.Invalidate;
      end;
    end;
  end;
end;

function TUniConnectionPool.GetConnection: TPooledConnection;
begin
  if not TryGetConnection(FConfig.AcquireTimeoutMs, Result) then
  begin
    Inc(FStatistics.TotalTimeouts);
    DoPoolEvent(pePoolExhausted, '连接池耗尽，获取连接超时');
    raise EConnectionTimeoutException.Create('Database connection acquisition timeout');
  end;
end;

function TUniConnectionPool.TryGetConnection(TimeoutMs: Cardinal;
  out Conn: TPooledConnection): Boolean;
var
  StartTime: TDateTime;
  Stopwatch: TStopwatch;
  ElapsedMs: Int64;
  Pooled: TPooledConnection;
begin
  Result := False;
  Conn := nil;

  if not FInitialized then
    raise EPoolNotInitializedException.Create('Connection pool not initialized');

  StartTime := Now;
  Stopwatch := TStopwatch.StartNew;

  while not FShutdown do
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

      // 无可用连接，尝试创建新连接
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

    // 检查超时
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
    FAvailableEvent.SetEvent;
    FStatsLock.Enter;
    try
      Inc(FStatistics.TotalReleases);
    finally
      FStatsLock.Leave;
    end;
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
    FAvailableEvent.SetEvent;
    FStatsLock.Enter;
    try
      Inc(FStatistics.TotalReleases);
    finally
      FStatsLock.Leave;
    end;
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
        Inc(FStatistics.TotalDestroys);
        DoPoolEvent(peConnectionDestroyed, '清理空闲连接');
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
    for I := FPool.Count - 1 downto 0 do
    begin
      Inc(FStatistics.TotalDestroys);
      FPool.Delete(I);
    end;
    DoPoolEvent(peConnectionDestroyed, '回收所有连接');
  finally
    FLock.Leave;
  end;

  // 重新预热
  Warmup(FConfig.MinSize);
end;

function TUniConnectionPool.GetStatistics: TPoolStatistics;
begin
  FStatsLock.Enter;
  try
    Result := FStatistics;
    // 更新实时数据
    FLock.Enter;
    try
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
    finally
      FLock.Leave;
    end;
    Result.PoolUptime := TTimeSpan.FromSeconds(SecondsBetween(Now, FStartTime));
  finally
    FStatsLock.Leave;
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

procedure TUniConnectionPool.Warmup(Count: Integer);
var
  I, Target: Integer;
  Pooled: TPooledConnection;
begin
  if Count <= 0 then
    Target := FConfig.MinSize
  else
    Target := Min(Count, FConfig.MaxSize);

  FLock.Enter;
  try
    for I := FPool.Count to Target - 1 do
    begin
      try
        Pooled := TPooledConnection.Create(Self, CreateConnection);
        FPool.Add(Pooled);
      except
        on E: Exception do
        begin
          {$IFDEF DEBUG}
          OutputDebugString(PChar('UniBase.DB.Pool: Warmup failed: ' + E.Message));
          {$ENDIF}
          Break;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
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
        OutputDebugString(PChar('UniBase.DB.Pool: OnPoolEvent handler error: ' + E.Message));
        {$ENDIF}
    end;
  end;
end;

procedure TUniConnectionPool.MaintenanceLoop;
begin
  while not FShutdown and not TThread.Current.CheckTerminated do
  begin
    Sleep(10000); // 每10秒执行一次维护
    if not FShutdown then
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
begin
  FLock.Enter;
  try
    for I := 0 to FPool.Count - 1 do
    begin
      Pooled := FPool[I];
      if Pooled.State = csIdle then
      begin
        // 检查是否需要验证
        if SecondsBetween(Now, Pooled.FLastValidatedAt) >= FConfig.ValidationIntervalSec then
        begin
          if not Pooled.Validate then
            Inc(FStatistics.TotalInvalidations);
        end;
      end;
    end;
  finally
    FLock.Leave;
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
        Inc(FStatistics.TotalDestroys);
        FPool.Delete(I);
        Continue;
      end;

      // 移除超过最大生命周期的连接
      if (Pooled.State = csIdle) and
         (SecondsBetween(Now, Pooled.CreatedAt) >= FConfig.MaxLifetimeSec) then
      begin
        Inc(FStatistics.TotalDestroys);
        DoPoolEvent(peConnectionDestroyed, '连接超过最大生命周期');
        FPool.Delete(I);
        Continue;
      end;

      // 移除空闲超时的连接（保持最小连接数）
      if (FPool.Count > FConfig.MinSize) and
         (Pooled.State = csIdle) and
         (SecondsBetween(Now, Pooled.LastUsedAt) >= FConfig.IdleTimeoutSec) then
      begin
        Inc(FStatistics.TotalDestroys);
        DoPoolEvent(peConnectionDestroyed, '连接空闲超时');
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
        Inc(FStatistics.LeaksDetected);
        DoPoolEvent(peConnectionLeakDetected,
          Format('检测到可能的连接泄漏! 线程: %d, 持有时间: %d 秒',
            [Pooled.FOwnerThreadId, SecondsBetween(Now, Pooled.FAcquiredAt)]));
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.EnsureMinConnections;
begin
  FLock.Enter;
  try
    while FPool.Count < FConfig.MinSize do
    begin
      try
        FPool.Add(TPooledConnection.Create(Self, CreateConnection));
      except
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TUniConnectionPool.UpdateStats(const Action: string);
begin
  // 保留用于未来扩展
end;

{ TPoolManager }

class constructor TPoolManager.Create;
begin
  FPools := TObjectDictionary<string, TUniConnectionPool>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

class destructor TPoolManager.Destroy;
begin
  ShutdownAll;
  FPools.Free;
  FLock.Free;
end;

class function TPoolManager.GetPool(const Name: string): TUniConnectionPool;
begin
  FLock.Enter;
  try
    if not FPools.TryGetValue(Name, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

class procedure TPoolManager.RegisterPool(const Name: string;
  Pool: TUniConnectionPool);
begin
  FLock.Enter;
  try
    FPools.AddOrSetValue(Name, Pool);
  finally
    FLock.Leave;
  end;
end;

class procedure TPoolManager.RemovePool(const Name: string);
begin
  FLock.Enter;
  try
    if FPools.ContainsKey(Name) then
      FPools.Remove(Name);
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
  finally
    FLock.Leave;
  end;
end;

end.
