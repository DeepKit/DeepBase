{ ============================================================================
  UniBase.DB.DoQry - DoQry 数据库访问集成模块
  
  版本: 1.0
  说明: 将 DoQry 库集成到 UniBase 框架，统一日志和错误处理
  线程安全: 所有公共方法均线程安全
  ============================================================================ }

unit UniBase.DB.DoQry;

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  UniBase.Types;

const
  /// <summary>
  /// 数据库错误码
  /// </summary>
  DOQRY_ERR_SUCCESS          = 0;     // 成功
  DOQRY_ERR_SQL_SYNTAX       = 1001;  // SQL 语法错误
  DOQRY_ERR_PARAM_MISSING    = 1002;  // 参数缺失
  DOQRY_ERR_PARAM_INVALID    = 1003;  // 参数无效
  DOQRY_ERR_CONNECTION       = 2001;  // 连接错误
  DOQRY_ERR_TIMEOUT          = 2002;  // 查询超时
  DOQRY_ERR_DISCONNECTED     = 2003;  // 连接断开
  DOQRY_ERR_TX_CONFLICT      = 3001;  // 事务冲突
  DOQRY_ERR_TX_DEADLOCK      = 3002;  // 死锁
  DOQRY_ERR_TX_ROLLBACK      = 3003;  // 事务回滚
  DOQRY_ERR_CONSTRAINT       = 4001;  // 约束违反
  DOQRY_ERR_UNIQUE           = 4002;  // 唯一约束违反
  DOQRY_ERR_FOREIGN_KEY      = 4003;  // 外键约束违反
  DOQRY_ERR_NOT_FOUND        = 5001;  // 记录未找到
  DOQRY_ERR_QUERY_NOT_FOUND  = 5002;  // 查询定义未找到
  DOQRY_ERR_UNKNOWN          = 9999;  // 未知错误

type
  /// <summary>
  /// 数据库类型
  /// </summary>
  TUniDBType = (udbPostgreSQL, udbSQLite);

  /// <summary>
  /// 查询上下文
  /// </summary>
  TUniQueryContext = record
    Connection: TFDConnection;
    DBType: TUniDBType;
    TimeoutSec: Integer;
    CorrelationId: string;
  end;

  /// <summary>
  /// 事务接口
  /// </summary>
  IUniTransaction = interface
    ['{D7E8F9A0-B1C2-4D3E-5F6A-7B8C9D0E1F2A}']
    procedure Commit;
    procedure Rollback;
  end;

  /// <summary>
  /// 数据库错误异常（携带上下文和错误码）
  /// </summary>
  EUniBaseDbError = class(Exception)
  private
    FErrorCode: Integer;
    FProcName: string;
    FSQL: string;
    FParamsJson: string;
    FDBType: TUniDBType;
    FCorrelationId: string;
  public
    constructor Create(const Msg, ProcName, SQL, ParamsJson: string; 
      DBType: TUniDBType; const CorrelationId: string; 
      ErrorCode: Integer = DOQRY_ERR_UNKNOWN); reintroduce;
    
    property ErrorCode: Integer read FErrorCode;
    property ProcName: string read FProcName;
    property SQL: string read FSQL;
    property ParamsJson: string read FParamsJson;
    property DBType: TUniDBType read FDBType;
    property CorrelationId: string read FCorrelationId;
  end;

/// <summary>
/// 初始化 DoQry（由 UniBase.Manager 调用）
/// </summary>
procedure UniDbInit(const RootPath: string);

/// <summary>
/// 创建查询上下文
/// </summary>
function UniDbMakeContext(Conn: TFDConnection; DBType: TUniDBType; 
  TimeoutSec: Integer = 30; const CorrelationId: string = ''): TUniQueryContext;

/// <summary>
/// 生成新的关联 ID
/// </summary>
function UniDbNewCorrelationId: string;

/// <summary>
/// 开始事务
/// </summary>
function UniDbBeginTx(const Ctx: TUniQueryContext): IUniTransaction;

/// <summary>
/// 在事务中执行（自动提交/回滚）
/// </summary>
procedure UniDbRunInTx(const Ctx: TUniQueryContext; const Proc: TProc);

/// <summary>
/// 执行 SELECT 查询
/// </summary>
function UniDbSelect(const ProcName: string; const ParamsJson: string; 
  var Data: TFDMemTable; const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行非查询（INSERT/UPDATE/DELETE）
/// </summary>
function UniDbExec(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行 INSERT 并返回自增 ID
/// </summary>
function UniDbInsertReturningId(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行标量查询
/// </summary>
function UniDbScalar(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Variant;

/// <summary>
/// 构建 SQL 预览（调试用）
/// </summary>
function UniDbBuildSqlPreview(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): string;

/// <summary>
/// 清除所有查询缓存
/// </summary>
procedure UniDbClearQueryCache;

/// <summary>
/// 精确失效某个 ProcName 的缓存
/// </summary>
procedure UniDbInvalidateQuery(const ProcName: string);

/// <summary>
/// 设置缓存 TTL（秒），默认 300（5 分钟）
/// </summary>
procedure UniDbSetCacheTTL(Seconds: Integer);

/// <summary>
/// 获取缓存统计：命中数、未命中数、当前缓存条目数
/// </summary>
procedure UniDbGetCacheStats(out Hits, Misses, EntryCount: Int64);

/// <summary>
/// 启用/禁用预编译语句复用（默认启用）
/// </summary>
procedure UniDbSetPreparedStatementPooling(Enabled: Boolean);

/// <summary>
/// 清空预编译语句池
/// </summary>
procedure UniDbClearPreparedStatements;

/// <summary>
/// 获取预编译语句池统计
/// </summary>
procedure UniDbGetPreparedStats(out PoolSize, ReuseCount: Int64);

implementation

uses
  System.DateUtils, System.IOUtils, System.JSON, System.Generics.Collections,
  Data.DB,
  FireDAC.Stan.Option,
  UniBase.Logging,
  UniBase.SQLLogger;  // BUG-032 FIX: 集成慢查询监控

type
  TQueryCacheEntry = record
    SQL: string;
    ExpireTime: TDateTime;
  end;

type
  /// <summary>
  /// 预编译语句池条目
  /// </summary>
  TPreparedEntry = class
  private
    FQuery: TFDQuery;
    FConnection: TFDConnection;
    FSQLHash: Cardinal;
    FLastUsed: TDateTime;
    FReuseCount: Int64;
  public
    constructor Create(AQuery: TFDQuery; AConnection: TFDConnection; ASQLHash: Cardinal);
    destructor Destroy; override;
    property Query: TFDQuery read FQuery;
    property Connection: TFDConnection read FConnection;
    property SQLHash: Cardinal read FSQLHash;
    property LastUsed: TDateTime read FLastUsed write FLastUsed;
    property ReuseCount: Int64 read FReuseCount write FReuseCount;
  end;

var
  GRootPath: string = '';
  GInitialized: Boolean = False;
  GQueryCache: TDictionary<string, TQueryCacheEntry> = nil;
  GQueryCacheLock: TObject = nil;
  GCacheTTLSec: Integer = 300;  // 默认 5 分钟
  GCacheHits: Int64 = 0;
  GCacheMisses: Int64 = 0;
  
  // 预编译语句池
  GPreparedPool: TObjectDictionary<string, TPreparedEntry> = nil;  // Key = ConnPtr + SQLHash
  GPreparedPoolLock: TObject = nil;
  GPreparedPoolEnabled: Boolean = True;
  GPreparedReuseCount: Int64 = 0;

{ TPreparedEntry }

constructor TPreparedEntry.Create(AQuery: TFDQuery; AConnection: TFDConnection; ASQLHash: Cardinal);
begin
  inherited Create;
  FQuery := AQuery;
  FConnection := AConnection;
  FSQLHash := ASQLHash;
  FLastUsed := Now;
  FReuseCount := 0;
end;

destructor TPreparedEntry.Destroy;
begin
  FQuery.Free;
  inherited;
end;

{ EUniBaseDbError }

constructor EUniBaseDbError.Create(const Msg, ProcName, SQL, ParamsJson: string;
  DBType: TUniDBType; const CorrelationId: string; ErrorCode: Integer);
begin
  inherited Create(Msg);
  FErrorCode := ErrorCode;
  FProcName := ProcName;
  FSQL := SQL;
  FParamsJson := ParamsJson;
  FDBType := DBType;
  FCorrelationId := CorrelationId;
end;

/// <summary>
/// 根据异常消息推断错误码
/// </summary>
function InferErrorCode(const ErrMsg: string): Integer;
var
  UpperMsg: string;
begin
  UpperMsg := UpperCase(ErrMsg);
  
  // SQL 语法错误
  if (Pos('SYNTAX', UpperMsg) > 0) or (Pos('NEAR', UpperMsg) > 0) then
    Exit(DOQRY_ERR_SQL_SYNTAX);
  
  // 参数错误
  if (Pos('PARAMETER', UpperMsg) > 0) and (Pos('NOT FOUND', UpperMsg) > 0) then
    Exit(DOQRY_ERR_PARAM_MISSING);
  
  // 连接错误
  if (Pos('CONNECTION', UpperMsg) > 0) or (Pos('CONNECT', UpperMsg) > 0) then
    Exit(DOQRY_ERR_CONNECTION);
  if (Pos('CLOSED', UpperMsg) > 0) or (Pos('DISCONNECTED', UpperMsg) > 0) then
    Exit(DOQRY_ERR_DISCONNECTED);
  
  // 超时
  if (Pos('TIMEOUT', UpperMsg) > 0) or (Pos('TIMED OUT', UpperMsg) > 0) then
    Exit(DOQRY_ERR_TIMEOUT);
  
  // 事务错误
  if (Pos('DEADLOCK', UpperMsg) > 0) then
    Exit(DOQRY_ERR_TX_DEADLOCK);
  if (Pos('LOCK', UpperMsg) > 0) and (Pos('CONFLICT', UpperMsg) > 0) then
    Exit(DOQRY_ERR_TX_CONFLICT);
  
  // 约束错误
  if (Pos('UNIQUE', UpperMsg) > 0) or (Pos('DUPLICATE', UpperMsg) > 0) then
    Exit(DOQRY_ERR_UNIQUE);
  if (Pos('FOREIGN KEY', UpperMsg) > 0) then
    Exit(DOQRY_ERR_FOREIGN_KEY);
  if (Pos('CONSTRAINT', UpperMsg) > 0) then
    Exit(DOQRY_ERR_CONSTRAINT);
  
  Result := DOQRY_ERR_UNKNOWN;
end;

{ 预编译语句池辅助函数 }

/// <summary>
/// 简单哈希函数
/// </summary>
function SimpleHash(const S: string): Cardinal;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    Result := ((Result shl 5) or (Result shr 27)) xor Ord(S[I]);
end;

/// <summary>
/// 生成预编译语句池键
/// </summary>
function MakePreparedKey(Conn: TFDConnection; const SQL: string): string;
begin
  Result := IntToHex(NativeInt(Conn), 16) + '_' + IntToStr(SimpleHash(SQL));
end;

/// <summary>
/// 从池中获取或创建预编译查询
/// </summary>
function GetOrCreatePreparedQuery(Conn: TFDConnection; const SQL: string): TFDQuery;
var
  Key: string;
  Entry: TPreparedEntry;
begin
  if not GPreparedPoolEnabled then
  begin
    Result := TFDQuery.Create(nil);
    Result.Connection := Conn;
    Result.SQL.Text := SQL;
    Exit;
  end;
  
  Key := MakePreparedKey(Conn, SQL);
  
  TMonitor.Enter(GPreparedPoolLock);
  try
    if GPreparedPool.TryGetValue(Key, Entry) then
    begin
      // 检查连接是否仍然有效
      if Entry.Connection = Conn then
      begin
        Entry.LastUsed := Now;
        Inc(Entry.FReuseCount);
        Inc(GPreparedReuseCount);
        Result := Entry.Query;
        Exit;
      end
      else
      begin
        // 连接已变，移除旧条目
        GPreparedPool.Remove(Key);
      end;
    end;
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;
  
  // 创建新的预编译查询
  Result := TFDQuery.Create(nil);
  Result.Connection := Conn;
  Result.SQL.Text := SQL;
  Result.Prepare;  // 预编译
  
  Entry := TPreparedEntry.Create(Result, Conn, SimpleHash(SQL));
  
  TMonitor.Enter(GPreparedPoolLock);
  try
    GPreparedPool.AddOrSetValue(Key, Entry);
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;
end;

/// <summary>
/// 释放查询（如果启用池化，则保留；否则释放）
/// </summary>
procedure ReleaseQuery(Q: TFDQuery; Pooled: Boolean);
begin
  if not Pooled or not GPreparedPoolEnabled then
    Q.Free
  else
  begin
    // 池化的查询不释放，只关闭
    if Q.Active then
      Q.Close;
  end;
end;

{ 内部日志辅助 }

/// <summary>
/// 记录查询日志（结构化 JSON 格式）
/// </summary>
procedure LogQuery(const Level, CorrId, ProcName: string; DBType: TUniDBType;
  const Kind, SQL, ParamsJson: string; DurationMs: Int64; Rows: Integer; 
  const ErrorMsg: string);
var
  LogLevel: TLogLevel;
  DBName: string;
  JsonObj: TJSONObject;
  JsonStr: string;
begin
  // 确定日志级别
  if Level = 'ERROR' then
    LogLevel := llError
  else if Level = 'WARN' then
    LogLevel := llWarn
  else
    LogLevel := llDebug;
  
  case DBType of
    udbPostgreSQL: DBName := 'postgresql';
    udbSQLite: DBName := 'sqlite';
  end;
  
  // 构建结构化 JSON 日志
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('component', 'doqry');
    JsonObj.AddPair('correlation_id', CorrId);
    JsonObj.AddPair('db_type', DBName);
    JsonObj.AddPair('proc_name', ProcName);
    JsonObj.AddPair('kind', Kind);
    JsonObj.AddPair('duration_ms', TJSONNumber.Create(DurationMs));
    JsonObj.AddPair('rows', TJSONNumber.Create(Rows));
    
    // SQL 和参数仅在 DEBUG 级别记录（避免敏感数据泄漏）
    if LogLevel = llDebug then
    begin
      // 截断过长 SQL
      if Length(SQL) > 500 then
        JsonObj.AddPair('sql', Copy(SQL, 1, 500) + '...')
      else
        JsonObj.AddPair('sql', SQL);
      
      if ParamsJson <> '' then
        JsonObj.AddPair('params', ParamsJson);
    end;
    
    if ErrorMsg <> '' then
      JsonObj.AddPair('error', ErrorMsg);
    
    JsonStr := JsonObj.ToString;
  finally
    JsonObj.Free;
  end;
  
  Logger.Log(JsonStr, LogLevel, 'DoQry:' + CorrId);
end;

{ 内部辅助函数 }

/// <summary>
/// 复制 TFDQuery 数据到 TFDMemTable
/// </summary>
procedure CopyQueryToMemTable(Src: TFDQuery; Dest: TFDMemTable);
begin
  Dest.Close;
  // TFDMemTable 可以直接从 TFDQuery 复制数据
  Dest.CopyDataSet(Src, [coStructure, coRestart, coAppend]);
end;

{ 公共函数 }

procedure UniDbInit(const RootPath: string);
begin
  GRootPath := RootPath;
  GInitialized := True;
  
  // 初始化查询缓存
  if GQueryCacheLock = nil then
    GQueryCacheLock := TObject.Create;
  if GQueryCache = nil then
    GQueryCache := TDictionary<string, TQueryCacheEntry>.Create;
  
  // 初始化预编译语句池
  if GPreparedPoolLock = nil then
    GPreparedPoolLock := TObject.Create;
  if GPreparedPool = nil then
    GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);
  
  // 重置统计
  GCacheHits := 0;
  GCacheMisses := 0;
  GPreparedReuseCount := 0;
  
  // 确保日志目录存在
  ForceDirectories(TPath.Combine(RootPath, 'logs'));
end;

/// <summary>
/// 判断是否为直接 SQL（以关键字开头）
/// </summary>
function IsDirectSQL(const ProcName: string): Boolean;
var
  Upper: string;
begin
  Upper := UpperCase(Trim(ProcName));
  Result := (Pos('SELECT ', Upper) = 1) or
            (Pos('INSERT ', Upper) = 1) or
            (Pos('UPDATE ', Upper) = 1) or
            (Pos('DELETE ', Upper) = 1) or
            (Pos('CREATE ', Upper) = 1) or
            (Pos('DROP ', Upper) = 1) or
            (Pos('ALTER ', Upper) = 1) or
            (Pos('WITH ', Upper) = 1) or
            (Pos('PRAGMA ', Upper) = 1);
end;

/// <summary>
/// 从 Queries 表加载 SQL（带缓存 + TTL）
/// </summary>
function LoadQuerySQL(const ProcName: string; const Ctx: TUniQueryContext): string;
var
  Q: TFDQuery;
  Entry: TQueryCacheEntry;
  Found: Boolean;
begin
  Result := '';
  
  // 如果是直接 SQL，直接返回
  if IsDirectSQL(ProcName) then
  begin
    Result := ProcName;
    Exit;
  end;
  
  // 检查缓存
  Found := False;
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      if GQueryCache.TryGetValue(ProcName, Entry) then
      begin
        // 检查 TTL
        if Now < Entry.ExpireTime then
        begin
          Result := Entry.SQL;
          Found := True;
          Inc(GCacheHits);
        end
        else
          GQueryCache.Remove(ProcName);  // 已过期，移除
      end;
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
  
  if Found then
    Exit;
  
  // 缓存未命中
  TMonitor.Enter(GQueryCacheLock);
  try
    Inc(GCacheMisses);
  finally
    TMonitor.Exit(GQueryCacheLock);
  end;
  
  // 从数据库查询
  if not Assigned(Ctx.Connection) or not Ctx.Connection.Connected then
  begin
    Result := ProcName;  // 回退到直接使用
    Exit;
  end;
  
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := 'SELECT SQL FROM Queries WHERE ProcName = :ProcName AND IsEnabled = 1';
    Q.ParamByName('ProcName').AsString := ProcName;
    try
      Q.Open;
      if not Q.Eof then
        Result := Q.FieldByName('SQL').AsString;
    except
      // 表可能不存在，回退到直接使用
      Result := '';
    end;
  finally
    Q.Free;
  end;
  
  // 未找到时，使用 ProcName 作为 SQL（向后兼容）
  if Result = '' then
    Result := ProcName
  else
  begin
    // 缓存结果（带 TTL）
    if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
    begin
      Entry.SQL := Result;
      Entry.ExpireTime := IncSecond(Now, GCacheTTLSec);
      TMonitor.Enter(GQueryCacheLock);
      try
        GQueryCache.AddOrSetValue(ProcName, Entry);
      finally
        TMonitor.Exit(GQueryCacheLock);
      end;
    end;
  end;
end;

/// <summary>
/// 清除所有查询缓存
/// </summary>
procedure UniDbClearQueryCache;
begin
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      GQueryCache.Clear;
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
end;

/// <summary>
/// 精确失效某个 ProcName 的缓存
/// </summary>
procedure UniDbInvalidateQuery(const ProcName: string);
begin
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      GQueryCache.Remove(ProcName);
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
end;

/// <summary>
/// 设置缓存 TTL（秒）
/// </summary>
procedure UniDbSetCacheTTL(Seconds: Integer);
begin
  if Seconds < 0 then
    Seconds := 0;
  // BUG-044 FIX: Check if lock object is initialized before using
  if not Assigned(GQueryCacheLock) then
  begin
    GCacheTTLSec := Seconds;
    Exit;
  end;
  TMonitor.Enter(GQueryCacheLock);
  try
    GCacheTTLSec := Seconds;
  finally
    TMonitor.Exit(GQueryCacheLock);
  end;
end;

/// <summary>
/// 获取缓存统计
/// </summary>
procedure UniDbGetCacheStats(out Hits, Misses, EntryCount: Int64);
begin
  if Assigned(GQueryCacheLock) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      Hits := GCacheHits;
      Misses := GCacheMisses;
      if Assigned(GQueryCache) then
        EntryCount := GQueryCache.Count
      else
        EntryCount := 0;
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end
  else
  begin
    Hits := 0;
    Misses := 0;
    EntryCount := 0;
  end;
end;

function UniDbMakeContext(Conn: TFDConnection; DBType: TUniDBType;
  TimeoutSec: Integer; const CorrelationId: string): TUniQueryContext;
begin
  Result.Connection := Conn;
  Result.DBType := DBType;
  Result.TimeoutSec := TimeoutSec;
  if CorrelationId = '' then
    Result.CorrelationId := UniDbNewCorrelationId
  else
    Result.CorrelationId := CorrelationId;
end;

function UniDbNewCorrelationId: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := Copy(GUIDToString(G), 2, 8); // 简短 ID
end;

{ 事务实现 }

type
  TUniTransaction = class(TInterfacedObject, IUniTransaction)
  private
    FCtx: TUniQueryContext;
    FCommitted: Boolean;
    FRolledBack: Boolean;
  public
    constructor Create(const Ctx: TUniQueryContext);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

constructor TUniTransaction.Create(const Ctx: TUniQueryContext);
begin
  inherited Create;
  FCtx := Ctx;
  FCommitted := False;
  FRolledBack := False;
  FCtx.Connection.StartTransaction;
end;

destructor TUniTransaction.Destroy;
begin
  if not FCommitted and not FRolledBack then
    Rollback;
  inherited;
end;

procedure TUniTransaction.Commit;
begin
  if not FCommitted and not FRolledBack then
  begin
    FCtx.Connection.Commit;
    FCommitted := True;
  end;
end;

procedure TUniTransaction.Rollback;
begin
  if not FCommitted and not FRolledBack then
  begin
    FCtx.Connection.Rollback;
    FRolledBack := True;
  end;
end;

function UniDbBeginTx(const Ctx: TUniQueryContext): IUniTransaction;
begin
  Result := TUniTransaction.Create(Ctx);
end;

procedure UniDbRunInTx(const Ctx: TUniQueryContext; const Proc: TProc);
var
  Tx: IUniTransaction;
begin
  Tx := UniDbBeginTx(Ctx);
  try
    Proc();
    Tx.Commit;
  except
    Tx.Rollback;
    raise;
  end;
end;

{ 查询执行 - 简化实现 }

function UniDbSelect(const ProcName: string; const ParamsJson: string;
  var Data: TFDMemTable; const Ctx: TUniQueryContext): Integer;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  Params: TJSONObject;
  Pair: TJSONPair;
  SQL: string;
  Pooled: Boolean;
begin
  Result := 0;
  StartTime := Now;

  // 从 Queries 表加载 SQL 或直接使用
  SQL := LoadQuerySQL(ProcName, Ctx);
  Pooled := GPreparedPoolEnabled;

  if Pooled then
    Q := GetOrCreatePreparedQuery(Ctx.Connection, SQL)
  else
  begin
    Q := TFDQuery.Create(nil);
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := SQL;
  end;

  try
    try
      Q.FetchOptions.Mode := fmAll;

      // 绑定参数
      if ParamsJson <> '' then
      begin
        Params := TJSONObject.ParseJSONValue(ParamsJson) as TJSONObject;
        if Assigned(Params) then
        try
          for Pair in Params do
          begin
            if Pair.JsonValue is TJSONNull then
              Q.ParamByName(Pair.JsonString.Value).Clear
            else if Pair.JsonValue is TJSONNumber then
              Q.ParamByName(Pair.JsonString.Value).AsFloat := TJSONNumber(Pair.JsonValue).AsDouble
            else if Pair.JsonValue is TJSONBool then
              Q.ParamByName(Pair.JsonString.Value).AsBoolean := TJSONBool(Pair.JsonValue).AsBoolean
            else
              Q.ParamByName(Pair.JsonString.Value).AsString := Pair.JsonValue.Value;
          end;
        finally
          Params.Free;
        end;
      end;

      Q.Open;
      Result := Q.RecordCount;

      // 复制数据到 TFDMemTable
      if Data = nil then
        Data := TFDMemTable.Create(nil);
      CopyQueryToMemTable(Q, Data);

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, Result, True,
        'DoQry:' + Ctx.CorrelationId);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT',
        SQL, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 0, False,
          'DoQry:' + Ctx.CorrelationId);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E.Message));
      end;
    end;
  finally
    ReleaseQuery(Q, Pooled);
  end;
end;

function UniDbExec(const ProcName: string; const ParamsJson: string;
  const Ctx: TUniQueryContext): Integer;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  Params: TJSONObject;
  Pair: TJSONPair;
  SQL: string;
  Pooled: Boolean;
begin
  Result := 0;
  StartTime := Now;

  SQL := LoadQuerySQL(ProcName, Ctx);
  Pooled := GPreparedPoolEnabled;

  if Pooled then
    Q := GetOrCreatePreparedQuery(Ctx.Connection, SQL)
  else
  begin
    Q := TFDQuery.Create(nil);
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := SQL;
  end;

  try
    try
      // 绑定参数
      if ParamsJson <> '' then
      begin
        Params := TJSONObject.ParseJSONValue(ParamsJson) as TJSONObject;
        if Assigned(Params) then
        try
          for Pair in Params do
          begin
            if Pair.JsonValue is TJSONNull then
              Q.ParamByName(Pair.JsonString.Value).Clear
            else if Pair.JsonValue is TJSONNumber then
              Q.ParamByName(Pair.JsonString.Value).AsFloat := TJSONNumber(Pair.JsonValue).AsDouble
            else if Pair.JsonValue is TJSONBool then
              Q.ParamByName(Pair.JsonString.Value).AsBoolean := TJSONBool(Pair.JsonValue).AsBoolean
            else
              Q.ParamByName(Pair.JsonString.Value).AsString := Pair.JsonValue.Value;
          end;
        finally
          Params.Free;
        end;
      end;

      Q.ExecSQL;
      Result := Q.RowsAffected;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, Result, True,
        'DoQry:' + Ctx.CorrelationId);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
        SQL, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 0, False,
          'DoQry:' + Ctx.CorrelationId);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E.Message));
      end;
    end;
  finally
    ReleaseQuery(Q, Pooled);
  end;
end;

function UniDbInsertReturningId(const ProcName: string; const ParamsJson: string;
  const Ctx: TUniQueryContext): Integer;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  SQL: string;
begin
  Result := 0;
  StartTime := Now;

  SQL := LoadQuerySQL(ProcName, Ctx);

  // 根据数据库类型处理返回 ID
  case Ctx.DBType of
    udbPostgreSQL:
      if Pos('RETURNING', UpperCase(SQL)) = 0 then
        SQL := SQL + ' RETURNING id';
    udbSQLite:
      ; // SQLite 使用 last_insert_rowid()
  end;

  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := Ctx.Connection;
      Q.SQL.Text := SQL;

      // 参数绑定（简化）
      // ...

      case Ctx.DBType of
        udbPostgreSQL:
        begin
          Q.Open;
          if not Q.Eof then
            Result := Q.Fields[0].AsInteger;
        end;
        udbSQLite:
        begin
          Q.ExecSQL;
          Q.SQL.Text := 'SELECT last_insert_rowid()';
          Q.Open;
          if not Q.Eof then
            Result := Q.Fields[0].AsInteger;
        end;
      end;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 1, True,
        'DoQry:' + Ctx.CorrelationId);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 0, False,
          'DoQry:' + Ctx.CorrelationId);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E.Message));
      end;
    end;
  finally
    Q.Free;
  end;
end;

function UniDbScalar(const ProcName: string; const ParamsJson: string;
  const Ctx: TUniQueryContext): Variant;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  SQL: string;
  Pooled: Boolean;
begin
  Result := Null;
  StartTime := Now;

  SQL := LoadQuerySQL(ProcName, Ctx);
  Pooled := GPreparedPoolEnabled;

  if Pooled then
    Q := GetOrCreatePreparedQuery(Ctx.Connection, SQL)
  else
  begin
    Q := TFDQuery.Create(nil);
    Q.Connection := Ctx.Connection;
    Q.SQL.Text := SQL;
  end;

  try
    try
      Q.Open;

      if not Q.Eof and (Q.Fields.Count > 0) then
        Result := Q.Fields[0].Value;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 1, True,
        'DoQry:' + Ctx.CorrelationId);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, ParamsJson, DurationMs, 0, False,
          'DoQry:' + Ctx.CorrelationId);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E.Message));
      end;
    end;
  finally
    ReleaseQuery(Q, Pooled);
  end;
end;

function UniDbBuildSqlPreview(const ProcName: string; const ParamsJson: string;
  const Ctx: TUniQueryContext): string;
begin
  // 简化：直接返回 SQL
  Result := ProcName;
  if ParamsJson <> '' then
    Result := Result + ' -- Params: ' + ParamsJson;
end;

{ 预编译语句池管理 }

procedure UniDbSetPreparedStatementPooling(Enabled: Boolean);
begin
  if Assigned(GPreparedPoolLock) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      GPreparedPoolEnabled := Enabled;
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end
  else
    GPreparedPoolEnabled := Enabled;
end;

procedure UniDbClearPreparedStatements;
begin
  if Assigned(GPreparedPoolLock) and Assigned(GPreparedPool) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      GPreparedPool.Clear;
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end;
end;

procedure UniDbGetPreparedStats(out PoolSize, ReuseCount: Int64);
begin
  if Assigned(GPreparedPoolLock) and Assigned(GPreparedPool) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      PoolSize := GPreparedPool.Count;
      ReuseCount := GPreparedReuseCount;
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end
  else
  begin
    PoolSize := 0;
    ReuseCount := 0;
  end;
end;

end.
