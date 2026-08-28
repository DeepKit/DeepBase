{ ============================================================================
  DeepBase.DB.DoQry - DoQry 数据库访问集成模�?
  
  版本: 1.0
  所属包: DeepBasePersistence
  说明: �?DoQry 库集成到 DeepBase 框架，统一日志和错误处�?
  线程安全: 所有公共方法均线程安全
  ============================================================================ }

unit DeepBase.DB.DoQry;

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  DeepBase.Types, DeepBase.Exceptions;

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
  DOQRY_ERR_NOT_FOUND        = 5001;  // 记录未找�?
  DOQRY_ERR_QUERY_NOT_FOUND  = 5002;  // 查询定义未找�?
  DOQRY_ERR_UNKNOWN          = 9999;  // 未知错误

type
  /// <summary>
  /// 数据库类�?
  /// </summary>
  TUniDBType = (udbPostgreSQL, udbSQLite);

  /// <summary>
  /// 查询上下�?
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
  EDeepBaseDbError = class(EDeepBaseException)
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
/// 初始�?DoQry（由 DeepBase.Manager 调用�?
/// </summary>
procedure UniDbInit(const RootPath: string);

/// <summary>
/// 创建查询上下�?
/// </summary>
function UniDbMakeContext(Conn: TFDConnection; DBType: TUniDBType; 
  TimeoutSec: Integer = 30; const CorrelationId: string = ''): TUniQueryContext;

/// <summary>
/// 生成新的关联 ID
/// </summary>
function UniDbNewCorrelationId: string;

/// <summary>
/// 开始事�?
/// </summary>
function UniDbBeginTx(const Ctx: TUniQueryContext): IUniTransaction;

/// <summary>
/// 在事务中执行（自动提�?回滚�?
/// </summary>
procedure UniDbRunInTx(const Ctx: TUniQueryContext; const Proc: TProc);

/// <summary>
/// 执行 SELECT 查询
/// </summary>
function UniDbSelect(const ProcName: string; const ParamsJson: string; 
  var Data: TFDMemTable; const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行非查询（INSERT/UPDATE/DELETE�?
/// </summary>
function UniDbExec(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行 INSERT 并返回自�?ID
/// </summary>
function UniDbInsertReturningId(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Integer;

/// <summary>
/// 执行标量查询
/// </summary>
function UniDbScalar(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): Variant;

/// <summary>
/// 构建 SQL 预览（调试用�?
/// </summary>
function UniDbBuildSqlPreview(const ProcName: string; const ParamsJson: string; 
  const Ctx: TUniQueryContext): string;

/// <summary>
/// 清除所有查询缓�?
/// </summary>
procedure UniDbClearQueryCache;

/// <summary>
/// DATA2-028: Enable or disable the direct-SQL escape hatch.
/// When disabled (default), IsDirectSQL always returns False and every
/// statement must be loaded from the whitelisted Queries table. Only turn
/// this on for legacy/migration callers that cannot be parameterized yet.
/// Every direct-SQL execution is audit-logged at WARN level.
/// </summary>
procedure UniDbSetDirectSQLAllowed(Enabled: Boolean);

/// <summary>
/// 精确失效某个 ProcName 的缓�?
/// </summary>
procedure UniDbInvalidateQuery(const ProcName: string);

/// <summary>
/// 设置缓存 TTL（秒），默认 300�? 分钟�?
/// </summary>
procedure UniDbSetCacheTTL(Seconds: Integer);

/// <summary>
/// 获取缓存统计：命中数、未命中数、当前缓存条目数
/// </summary>
procedure UniDbGetCacheStats(out Hits, Misses, EntryCount: Int64);

/// <summary>
/// 启用/禁用预编译语句复用（默认启用�?
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

/// <summary>
/// 设置预编译语句池容量上限（默�?500�?
/// </summary>
procedure UniDbSetPreparedPoolMaxSize(MaxSize: Integer);

/// <summary>
/// BASIC-014/FR-008: Sweep all prepared-statement pool entries that reference
/// the given connection. Call this BEFORE destroying a TFDConnection to
/// prevent stale entries (whose pointer key would become invalid as soon as
/// the address is reused). Connection pools should call this on connection
/// release/recycle/destroy.
/// </summary>
procedure UniDbSweepConnectionFromPool(Conn: TFDConnection);

/// <summary>
/// 释放全局缓存与预编译语句池（用于测试或程序退出）
/// </summary>
procedure UniDbShutdown;

type
  /// <summary>DoQry service interface for IoC injection and testing</summary>
  IDoQryService = interface
    ['{B1C2D3E4-F5A6-4B7C-8D9E-0F1A2B3C4D5E}']
    function Select(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    function Exec(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    function Scalar(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    procedure RunInTx(const Ctx: TUniQueryContext; const Proc: TProc);
    procedure ClearCache;
    procedure Shutdown;
  end;

  /// <summary>DoQry service implementation �?delegates to global functions</summary>
  TDoQryService = class(TInterfacedObject, IDoQryService)
  public
    function Select(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    function Exec(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    function Scalar(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
    procedure RunInTx(const Ctx: TUniQueryContext; const Proc: TProc);
    procedure ClearCache;
    procedure Shutdown;
  end;

implementation

uses
  System.DateUtils, System.IOUtils, System.JSON, System.Generics.Collections,
  Data.DB,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.Phys.PG,
  FireDAC.Phys.PGDef,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DeepBase.Logging,
  DeepBase.SQLLogger;  // BUG-032 FIX: 集成慢查询监?

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
    FInUseCount: Integer;
  public
    constructor Create(AQuery: TFDQuery; AConnection: TFDConnection; ASQLHash: Cardinal);
    destructor Destroy; override;
    procedure IncrementUse;
    procedure DecrementUse;
    property Query: TFDQuery read FQuery;
    property Connection: TFDConnection read FConnection;
    property SQLHash: Cardinal read FSQLHash;
    property LastUsed: TDateTime read FLastUsed write FLastUsed;
    property ReuseCount: Int64 read FReuseCount write FReuseCount;
    property InUseCount: Integer read FInUseCount;
  end;

var
  GRootPath: string = '';
  GInitialized: Boolean = False;
  GQueryCache: TDictionary<string, TQueryCacheEntry> = nil;
  GQueryCacheLoading: TDictionary<string, Byte> = nil;
  GQueryCacheLock: TObject = nil;
  GCacheTTLSec: Integer = 300;  // 默认 5 分钟
  GCacheHits: Int64 = 0;
  GCacheMisses: Int64 = 0;

  // DATA2-028 FIX: direct-SQL escape hatch is opt-in. When False (default),
  // IsDirectSQL always returns False so every statement must come from the
  // whitelisted Queries table. Enable only for legacy/migration callers that
  // cannot be parameterized yet, and audit-log every execution.
  GDirectSQLAllowed: Boolean = False;
  
  // 预编译语句池
  GPreparedPool: TObjectDictionary<string, TPreparedEntry> = nil;  // Key = SQLLen + SQLHash64 + SQLText
  GPreparedQueryIndex: TDictionary<TFDQuery, TPreparedEntry> = nil; // Query -> Entry
  GPreparedPoolLock: TObject = nil;
  GPreparedPoolEnabled: Boolean = False;
  GPreparedPoolMaxSize: Integer = 500;
  GPreparedReuseCount: Int64 = 0;
  GPreparedUseTick: Int64 = 0;

function NextPreparedLastUsed: TDateTime;
begin
  Inc(GPreparedUseTick);
  Result := EncodeDate(2000, 1, 1) + (GPreparedUseTick / 86400000.0);
end;

{ TPreparedEntry }

constructor TPreparedEntry.Create(AQuery: TFDQuery; AConnection: TFDConnection; ASQLHash: Cardinal);
begin
  inherited Create;
  FQuery := AQuery;
  FConnection := AConnection;
  FSQLHash := ASQLHash;
  FLastUsed := NextPreparedLastUsed;
  FReuseCount := 0;
  FInUseCount := 0;
end;

procedure TPreparedEntry.IncrementUse;
begin
  Inc(FInUseCount);
end;

procedure TPreparedEntry.DecrementUse;
begin
  if FInUseCount > 0 then
    Dec(FInUseCount);
end;

procedure UniDbShutdown;
begin
  // 清理查询缓存；锁对象�?initialization/finalization 管理�?
  if Assigned(GQueryCacheLock) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      FreeAndNil(GQueryCacheLoading);
      FreeAndNil(GQueryCache);
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end
  else
  begin
    FreeAndNil(GQueryCacheLoading);
    FreeAndNil(GQueryCache);
  end;

  // 清理预编译语句池；锁对象�?initialization/finalization 管理�?
  if Assigned(GPreparedPoolLock) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      FreeAndNil(GPreparedQueryIndex);
      FreeAndNil(GPreparedPool);
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end
  else
  begin
    FreeAndNil(GPreparedQueryIndex);
    FreeAndNil(GPreparedPool);
  end;
end;

destructor TPreparedEntry.Destroy;
begin
  FreeAndNil(FQuery);
  inherited;
end;

{ EDeepBaseDbError }

constructor EDeepBaseDbError.Create(const Msg, ProcName, SQL, ParamsJson: string;
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
/// 根据异常消息推断错误码（兼容回退�?
/// </summary>
function InferErrorCodeFromMessage(const ErrMsg: string): Integer;
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
  if (Pos('DATABASE IS LOCKED', UpperMsg) > 0) or
     (Pos('SQLITE_BUSY', UpperMsg) > 0) or
     (Pos('BUSY', UpperMsg) > 0) or
     (Pos('LOCKED', UpperMsg) > 0) then
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

/// <summary>
/// 根据异常对象推断错误码（优先使用 FireDAC 原生错误类型�?
/// </summary>
function InferErrorCode(E: Exception): Integer;
var
  DbError: EFDDBEngineException;
  NativeCode: Integer;
begin
  if E is EFDDBEngineException then
  begin
    DbError := EFDDBEngineException(E);

    case DbError.Kind of
      ekUKViolated: Exit(DOQRY_ERR_UNIQUE);
      ekFKViolated: Exit(DOQRY_ERR_FOREIGN_KEY);
      ekRecordLocked: Exit(DOQRY_ERR_TX_CONFLICT);
      ekInvalidParams: Exit(DOQRY_ERR_PARAM_INVALID);
      ekCmdAborted: Exit(DOQRY_ERR_TIMEOUT);
      ekServerGone, ekUserPwdInvalid, ekUserPwdExpired, ekUserPwdWillExpire:
        Exit(DOQRY_ERR_CONNECTION);
    end;

    try
      NativeCode := Abs(DbError.Errors[0].ErrorCode);
      case NativeCode of
        1: Exit(DOQRY_ERR_SQL_SYNTAX);     // SQLite: SQL error
        5, 6: Exit(DOQRY_ERR_TX_CONFLICT); // SQLite: BUSY/LOCKED
        19: Exit(DOQRY_ERR_CONSTRAINT);    // SQLite: constraint
        787: Exit(DOQRY_ERR_FOREIGN_KEY);  // SQLite: FK constraint failed
        2067: Exit(DOQRY_ERR_UNIQUE);      // SQLite: UNIQUE constraint failed
      end;
    except
      // Fall through to message-based inference below.
    end;
  end;

  Result := InferErrorCodeFromMessage(E.Message);
end;

{ 预编译语句池辅助函数 }

/// <summary>
///   32 位哈希（保持向后兼容，仅用于非关键路径）
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
///   64 位哈希：采用 FNV-1a 变体，碰撞率远低于 SimpleHash。
/// </summary>
function SimpleHash64(const S: string): UInt64;
var
  I: Integer;
begin
  Result := 14695981039346656037; // FNV offset basis
  for I := 1 to Length(S) do
  begin
    Result := Result xor Ord(S[I]);
    Result := Result * UInt64(1099511628211); // FNV prime
  end;
end;

/// <summary>
///   生成预编译语句池键值。
///   包含 SQL 长度、64 位哈希以及完整 SQL 文本，消除纯指针 + 弱哈希
///   带来的碰撞问题。连接身份由 TPreparedEntry.Connection 字段在查询时
///   单独校验，不再参与键值构成，避免连接对象地址被复用后误命中旧缓存。
/// </summary>
function MakePreparedKey(Conn: TFDConnection; const SQL: string): string;
begin
  Result := IntToStr(Length(SQL)) + '_' +
            IntToHex(SimpleHash64(SQL), 16) + '_' +
            SQL;
end;

procedure EnsurePreparedPoolStructures;
begin
  if GPreparedPool = nil then
    GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);
  if GPreparedQueryIndex = nil then
    GPreparedQueryIndex := TDictionary<TFDQuery, TPreparedEntry>.Create;
end;

function EvictOnePreparedLruEntry(const ExcludeEntry: TPreparedEntry): Boolean;
var
  Pair: TPair<string, TPreparedEntry>;
  EvictKey: string;
  EvictEntry: TPreparedEntry;
  Found: Boolean;
begin
  Result := False;
  if (GPreparedPool = nil) or (GPreparedPool.Count = 0) then
    Exit;

  Found := False;
  EvictKey := '';
  EvictEntry := nil;

  for Pair in GPreparedPool do
  begin
    if (Pair.Value = nil) or (Pair.Value = ExcludeEntry) then
      Continue;
    if Pair.Value.InUseCount > 0 then
      Continue;

    if (not Found) or (Pair.Value.LastUsed < EvictEntry.LastUsed) then
    begin
      Found := True;
      EvictKey := Pair.Key;
      EvictEntry := Pair.Value;
    end;
  end;

  if not Found then
    Exit;

  if Assigned(GPreparedQueryIndex) and Assigned(EvictEntry.Query) then
    GPreparedQueryIndex.Remove(EvictEntry.Query);
  GPreparedPool.Remove(EvictKey);
  Result := True;
end;

procedure EnforcePreparedPoolLimit(const ExcludeEntry: TPreparedEntry);
begin
  if GPreparedPoolMaxSize < 1 then
    GPreparedPoolMaxSize := 1;

  while Assigned(GPreparedPool) and (GPreparedPool.Count > GPreparedPoolMaxSize) do
  begin
    if not EvictOnePreparedLruEntry(ExcludeEntry) then
      Break;
  end;
end;

/// <summary>
/// 从池中获取或创建预编译查�?
/// </summary>
function GetOrCreatePreparedQuery(Conn: TFDConnection; const SQL: string): TFDQuery;
var
  Key: string;
  Entry: TPreparedEntry;
  NewQuery: TFDQuery;
  NewEntry: TPreparedEntry;
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
    EnsurePreparedPoolStructures;

    if GPreparedPool.TryGetValue(Key, Entry) then
    begin
      if Assigned(Entry) and Assigned(Entry.Query) and Assigned(Conn) and
         (Entry.Connection = Conn) and (Entry.Query.Connection = Conn) and
         Conn.Connected then
      begin
        // REVIEW5-DATA-007: a pooled TFDQuery is a single live cursor — its
        // Params/Active state are mutable. Reusing it while another caller is
        // still mid-execution (InUseCount > 0) would let the two callers clobber
        // each other's bound parameters and result sets. Hand out a fresh,
        // untracked query instead; ReleaseQuery frees it because it is absent
        // from GPreparedQueryIndex.
        if Entry.InUseCount > 0 then
        begin
          Result := TFDQuery.Create(nil);
          Result.Connection := Conn;
          Result.SQL.Text := SQL;
          Exit;
        end;

        Entry.LastUsed := NextPreparedLastUsed;
        Entry.IncrementUse;
        Inc(Entry.FReuseCount);
        Inc(GPreparedReuseCount);
        Result := Entry.Query;
        Exit;
      end;

      // The pool key contains a raw connection pointer. Delphi may reuse that
      // address after a TFDConnection is freed, so stale entries must be dropped.
      if Assigned(GPreparedQueryIndex) and Assigned(Entry) and Assigned(Entry.Query) then
        GPreparedQueryIndex.Remove(Entry.Query);
      GPreparedPool.Remove(Key);
    end;

    NewQuery := nil;
    NewEntry := nil;
    try
      NewQuery := TFDQuery.Create(nil);
      NewQuery.Connection := Conn;
      NewQuery.SQL.Text := SQL;
      // 不在此处预编译：参数值未绑定时会导致类型未知错误

      NewEntry := TPreparedEntry.Create(NewQuery, Conn, SimpleHash(SQL));
      NewEntry.IncrementUse;
      NewQuery := nil; // ownership transferred to entry

      GPreparedPool.AddOrSetValue(Key, NewEntry);
      if Assigned(GPreparedQueryIndex) then
        GPreparedQueryIndex.AddOrSetValue(NewEntry.Query, NewEntry);
      EnforcePreparedPoolLimit(NewEntry);
      Result := NewEntry.Query;
      NewEntry := nil; // ownership transferred to pool
    except
      NewEntry.Free;
      NewQuery.Free;
      raise;
    end;
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;
end;

/// <summary>
/// 释放查询（如果启用池化，则保留；否则释放�?
/// </summary>
procedure ReleaseQuery(Q: TFDQuery; Pooled: Boolean);
var
  Entry: TPreparedEntry;
begin
  if Q = nil then
    Exit;

  if not Pooled then
    Q.Free
  else
  begin
    // 池化的查询不释放，只关闭
    if Q.Active then
      Q.Close;

    Entry := nil;
    if Assigned(GPreparedPoolLock) and Assigned(GPreparedQueryIndex) then
    begin
      TMonitor.Enter(GPreparedPoolLock);
      try
        if GPreparedQueryIndex.TryGetValue(Q, Entry) then
        begin
          Entry.DecrementUse;
          Entry.LastUsed := NextPreparedLastUsed;
        end;
      finally
        TMonitor.Exit(GPreparedPoolLock);
      end;
    end;

    // 安全兜底：若未追踪到池条目，按非池化释放，避免泄�?
    if Entry = nil then
      Q.Free;
  end;
end;

{ 内部日志辅助 }

/// <summary>
/// 记录查询日志（结构化 JSON 格式�?
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
  
  // 构建结构�?JSON 日志
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('component', 'doqry');
    JsonObj.AddPair('correlation_id', CorrId);
    JsonObj.AddPair('db_type', DBName);
    JsonObj.AddPair('proc_name', ProcName);
    JsonObj.AddPair('kind', Kind);
    JsonObj.AddPair('duration_ms', TJSONNumber.Create(DurationMs));
    JsonObj.AddPair('rows', TJSONNumber.Create(Rows));
    
    // SQL 和参数仅�?DEBUG 级别记录（避免敏感数据泄漏）
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
/// 复制 TFDQuery 数据�?TFDMemTable
/// </summary>
procedure CopyQueryToMemTable(Src: TFDQuery; Dest: TFDMemTable);
begin
  Dest.Close;
  // TFDMemTable 可以直接�?TFDQuery 复制数据
  Dest.CopyDataSet(Src, [coStructure, coRestart, coAppend]);
end;

/// <summary>
/// 绑定 JSON 参数到查询（自动识别 GUID�?
/// </summary>
procedure BindJsonParams(Q: TFDQuery; const ParamsJson: string);
var
  Params: TJSONObject;
  Pair: TJSONPair;
  P: TFDParam;
  S: string;

  // Check if a string contains only hex digits and dashes (GUID characters)
  function IsHexWithDashes(const Value: string; Start, Len: Integer): Boolean;
  var
    I: Integer;
    C: Char;
  begin
    Result := True;
    for I := Start to Start + Len - 1 do
    begin
      C := Value[I];
      if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F', '-']) then
        Exit(False);
    end;
  end;

  // Validate GUID format before calling StringToGUID (avoids exception-based flow control)
  function TryParseGuid(const Value: string; out Guid: TGUID): Boolean;
  begin
    Result := False;
    // Value must be in {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx} format
    if (Length(Value) <> 38) or (Value[1] <> '{') or (Value[38] <> '}') then
      Exit;
    // Quick check: positions of dashes
    if (Value[10] <> '-') or (Value[15] <> '-') or
       (Value[20] <> '-') or (Value[25] <> '-') then
      Exit;
    // Check hex characters (skip braces and dashes)
    if not IsHexWithDashes(Value, 2, 36) then
      Exit;
    try
      Guid := StringToGUID(Value);
      Result := True;
    except
      Result := False;
    end;
  end;

begin
  if ParamsJson = '' then
    Exit;

  Params := TJSONObject.ParseJSONValue(ParamsJson) as TJSONObject;
  if not Assigned(Params) then
    Exit;
  try
    for Pair in Params do
    begin
      P := Q.ParamByName(Pair.JsonString.Value);
      if Pair.JsonValue is TJSONNull then
      begin
        P.DataType := ftWideString;
        P.Clear;
      end
      else if Pair.JsonValue is TJSONNumber then
      begin
        if (Pos('.', Pair.JsonValue.Value) > 0) or
           (Pos('e', LowerCase(Pair.JsonValue.Value)) > 0) then
          P.AsFloat := TJSONNumber(Pair.JsonValue).AsDouble
        else
          P.AsLargeInt := TJSONNumber(Pair.JsonValue).AsInt64;
      end
      else if Pair.JsonValue is TJSONBool then
        P.AsBoolean := TJSONBool(Pair.JsonValue).AsBoolean
      else
      begin
        S := Trim(Pair.JsonValue.Value);
        if S = '' then
          P.AsString := S
        else
        begin
          // UUID auto-detection: 36-char hex string with 4 dashes at correct positions.
          // Binds as ftGuid instead of ftWideString to avoid PG "uuid = character varying" errors.
          if (Length(S) = 36) and
             (S[9] = '-') and (S[14] = '-') and (S[19] = '-') and (S[24] = '-') then
          begin
            P.DataType := ftGuid;
            P.AsGuid := StringToGUID('{' + S + '}');
          end
          else
          begin
            if Length(S) > 4000 then
              P.DataType := ftWideMemo
            else
              P.DataType := ftWideString;
            P.AsWideString := S;
          end;
        end;
      end;
    end;
  finally
    Params.Free;
  end;
end;

{ 公共函数 }

procedure UniDbInit(const RootPath: string);
begin
  GRootPath := RootPath;
  GInitialized := True;

  TMonitor.Enter(GQueryCacheLock);
  try
    if GQueryCache = nil then
      GQueryCache := TDictionary<string, TQueryCacheEntry>.Create;
    if GQueryCacheLoading = nil then
      GQueryCacheLoading := TDictionary<string, Byte>.Create;
    GQueryCacheLoading.Clear;
    GCacheHits := 0;
    GCacheMisses := 0;
  finally
    TMonitor.Exit(GQueryCacheLock);
  end;

  TMonitor.Enter(GPreparedPoolLock);
  try
    EnsurePreparedPoolStructures;
    if Assigned(GPreparedPool) then
      GPreparedPool.Clear;
    if Assigned(GPreparedQueryIndex) then
      GPreparedQueryIndex.Clear;
    if GPreparedPoolMaxSize < 1 then
      GPreparedPoolMaxSize := 500;
    GPreparedPoolEnabled := False;
    GPreparedReuseCount := 0;
    GPreparedUseTick := 0;
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;

  // 确保日志目录存在
  ForceDirectories(TPath.Combine(RootPath, 'logs'));
end;

/// <summary>
/// 判断是否为直�?SQL（以关键字开头）
/// </summary>
function IsReadOnlyPragma(const Body: string): Boolean;
const
  // Pragmas that perform work / mutate database state even without an explicit
  // `=value` assignment. Bare `PRAGMA wal_checkpoint;` / `PRAGMA optimize;`
  // act; they must be whitelisted through the Queries table, not run as
  // ad-hoc direct SQL. Configuration knobs (journal_mode, synchronous, ...) are
  // NOT listed here because their bare form is a read; their `=value` form is
  // already rejected by the `=` check below.
  SideEffectPragmas: array[0..4] of string = (
    'WAL_CHECKPOINT', 'OPTIMIZE', 'INCREMENTAL_VACUUM', 'SHRINK_MEMORY',
    'WAL_FLUSH'
  );
var
  Name: string;
  I: Integer;
  P: Integer;
begin
  Result := False;

  // Reject any PRAGMA that assigns a value: `PRAGMA journal_mode=WAL`,
  // `PRAGMA foreign_keys=ON`, `PRAGMA cache_size=-2000`. These always mutate
  // state and must be whitelisted via the Queries table.
  if Pos('=', Body) > 0 then
    Exit;

  // Extract the pragma name token: everything after PRAGMA up to the first
  // whitespace or `(` (e.g. `table_info(x)` -> `table_info`).
  Name := Trim(Body);
  P := Pos('(', Name);
  if P > 0 then
    Name := Copy(Name, 1, P - 1);
  P := Pos(#9, Name);
  if P > 0 then
    Name := Copy(Name, 1, P - 1);
  P := Pos(' ', Name);
  if P > 0 then
    Name := Copy(Name, 1, P - 1);
  Name := UpperCase(Trim(Name));
  if Name = '' then
    Exit;

  // Reject pragmas that are inherently side-effecting even when bare.
  for I := Low(SideEffectPragmas) to High(SideEffectPragmas) do
    if Name = SideEffectPragmas[I] then
      Exit;

  Result := True;
end;

function IsDirectSQL(const ProcName: string): Boolean;
var
  Upper: string;
  PragmaBody: string;

  function StartsWithKeyword(const Keyword: string): Boolean;
  var
    L: Integer;
  begin
    L := Length(Keyword);
    Result := (Upper = Keyword) or
      ((Length(Upper) > L) and (Copy(Upper, 1, L) = Keyword) and
       CharInSet(Upper[L + 1], [#9, #10, #13, ' ']));
  end;

begin
  Result := False;

  // DATA2-028 FIX: direct SQL is an opt-in escape hatch. When the global flag
  // is off (default), every statement must be loaded from the Queries table so
  // it is DBA-whitelisted and parameterized. Callers that truly need raw SQL
  // (e.g. migration scripts) must call UniDbSetDirectSQLAllowed(True) first.
  if not GDirectSQLAllowed then
    Exit;

  Upper := UpperCase(Trim(ProcName));
  // Direct SQL: DML + read-only PRAGMA only. DDL (CREATE/ALTER/DROP) and
  // write-type PRAGMAs must go through the Queries table so they are
  // explicitly whitelisted by the DBA.
  Result := StartsWithKeyword('SELECT') or
            StartsWithKeyword('INSERT') or
            StartsWithKeyword('UPDATE') or
            StartsWithKeyword('DELETE') or
            StartsWithKeyword('WITH') or
            StartsWithKeyword('REPLACE');

  if Result then
  begin
    // DATA2-028 FIX: audit every direct-SQL execution so security reviewers
    // can detect misuse of the escape hatch.
    Logger.Log(Format('DoQry direct-SQL allowed (caller opt-in): %s',
      [Copy(ProcName, 1, 200)]), llWarn, 'DoQry:DirectSQL');
    Exit;
  end;

  // REVIEW5-DATA-008: tighten the PRAGMA direct-SQL whitelist. Only read-only
  // pragmas (no `=value`, no inherently side-effecting name) may run as direct
  // SQL; write-type pragmas fall through to the Queries table lookup and are
  // rejected with DOQRY_ERR_QUERY_NOT_FOUND unless whitelisted there.
  if StartsWithKeyword('PRAGMA') then
  begin
    PragmaBody := Trim(Copy(Upper, Length('PRAGMA') + 1, MaxInt));
    if IsReadOnlyPragma(PragmaBody) then
    begin
      Logger.Log(Format('DoQry direct-SQL PRAGMA allowed: %s',
        [Copy(ProcName, 1, 200)]), llWarn, 'DoQry:DirectSQL');
      Result := True;
    end;
  end;
end;

/// <summary>
/// �?Queries 表加�?SQL（带缓存 + TTL�?
/// </summary>
function LoadQuerySQL(const ProcName: string; const Ctx: TUniQueryContext): string;
var
  Q: TFDQuery;
  Entry: TQueryCacheEntry;
  LoadedSQL: string;
  LoadSucceeded: Boolean;
  CacheKey: string;

  function DbIdOfConn: string;
  begin
    // CR-226: 缓存键必须携带连接标识，否则多库场景下同名 ProcName
    // 会交叉污染（A 库的 SQL 被用于 B 库）
    if not Assigned(Ctx.Connection) then
      Exit('');
    Result := Ctx.Connection.ConnectionName;
    if Result = '' then
      Result := Ctx.Connection.Params.Database;
    if Result = '' then
      Result := Ctx.Connection.ConnectionString;
  end;

  function TryLoadQueryDef(const QuerySQL, ParamName, FieldName: string): Boolean;
  begin
    Result := False;
    Q.Close;
    Q.SQL.Text := QuerySQL;
    Q.ParamByName(ParamName).AsString := ProcName;
    try
      Q.Open;
      if not Q.Eof then
      begin
        Result := True;
        LoadedSQL := Q.FieldByName(FieldName).AsString;
      end;
    except
      Result := False;
    end;
  end;
begin
  Result := '';
  LoadedSQL := '';
  LoadSucceeded := False;
  
  // 如果是直连SQL，直接返回
  if IsDirectSQL(ProcName) then
  begin
    Result := ProcName;
    Exit;
  end;

  CacheKey := DbIdOfConn + '|' + ProcName;

  // 检查缓存并协调并发加载（同一 ProcName 只允许一个线程查库）
  if Assigned(GQueryCacheLock) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      if GQueryCache = nil then
        GQueryCache := TDictionary<string, TQueryCacheEntry>.Create;
      if GQueryCacheLoading = nil then
        GQueryCacheLoading := TDictionary<string, Byte>.Create;

      while True do
      begin
        if GQueryCache.TryGetValue(CacheKey, Entry) then
        begin
          // 检�?TTL
          if Now < Entry.ExpireTime then
          begin
            Result := Entry.SQL;
            Inc(GCacheHits);
            Exit;
          end
          else
            GQueryCache.Remove(CacheKey);  // 已过期，移除
        end;

        if GQueryCacheLoading.ContainsKey(CacheKey) then
        begin
          TMonitor.Wait(GQueryCacheLock, 1000);
          Continue;
        end;

        Inc(GCacheMisses);
        GQueryCacheLoading.AddOrSetValue(CacheKey, 1);
        Break;
      end;
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;

  try
    // 从数据库查询
    if not Assigned(Ctx.Connection) or not Ctx.Connection.Connected then
    begin
      raise EDeepBaseDbError.Create(
        Format('Query definition "%s" requires an active connection', [ProcName]),
        ProcName, '', '', Ctx.DBType, Ctx.CorrelationId, DOQRY_ERR_QUERY_NOT_FOUND);
    end;

    Q := TFDQuery.Create(nil);
    try
      Q.Connection := Ctx.Connection;
      if not TryLoadQueryDef(
        'SELECT SqlText FROM Queries WHERE Name = :Name AND IsEnabled = 1',
        'Name', 'SqlText') then
        TryLoadQueryDef(
          'SELECT SQL FROM Queries WHERE ProcName = :ProcName AND IsEnabled = 1',
          'ProcName', 'SQL');
      Result := LoadedSQL;
    finally
      Q.Free;
    end;

    if Result = '' then
      raise EDeepBaseDbError.Create(
        Format('Query definition not found: %s', [ProcName]),
        ProcName, '', '', Ctx.DBType, Ctx.CorrelationId, DOQRY_ERR_QUERY_NOT_FOUND);

    LoadSucceeded := True;
  finally
    if Assigned(GQueryCacheLock) then
    begin
      TMonitor.Enter(GQueryCacheLock);
      try
        if Assigned(GQueryCacheLoading) then
          GQueryCacheLoading.Remove(CacheKey);

        if LoadSucceeded and Assigned(GQueryCache) then
        begin
          Entry.SQL := Result;
          Entry.ExpireTime := IncSecond(Now, GCacheTTLSec);
          GQueryCache.AddOrSetValue(CacheKey, Entry);
        end;

        TMonitor.PulseAll(GQueryCacheLock);
      finally
        TMonitor.Exit(GQueryCacheLock);
      end;
    end;
  end;
end;

procedure UniDbSetDirectSQLAllowed(Enabled: Boolean);
begin
  // DATA2-028 FIX: opt-in escape hatch for direct SQL. Default is False,
  // which forces every statement through the Queries table. When enabled,
  // IsDirectSQL may return True for DML/PRAGMA and each execution is
  // audit-logged.
  GDirectSQLAllowed := Enabled;
end;

/// <summary>
/// 清除所有查询缓�?
/// </summary>
procedure UniDbClearQueryCache;
begin
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      GQueryCache.Clear;
      if Assigned(GQueryCacheLoading) then
      begin
        GQueryCacheLoading.Clear;
        TMonitor.PulseAll(GQueryCacheLock);
      end;
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
end;

/// <summary>
/// 精确失效某个 ProcName 的缓�?
/// </summary>
procedure UniDbInvalidateQuery(const ProcName: string);
var
  K: string;
  Keys: TArray<string>;
begin
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      // CR-226: 键含连接前缀，按后缀匹配失效所有连接上的同名查询
      Keys := GQueryCache.Keys.ToArray;
      for K in Keys do
        if K.EndsWith('|' + ProcName) then
          GQueryCache.Remove(K);
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
end;

/// <summary>
/// 设置缓存 TTL（秒�?
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
  Result := Copy(GUIDToString(G), 2, 8); // 简�?ID
end;

{ 事务实现 }

type
  TUniTransaction = class(TInterfacedObject, IUniTransaction)
  private
    FCtx: TUniQueryContext;
    FCommitted: Boolean;
    FRolledBack: Boolean;
    FUseSavepoint: Boolean;
    FSavepointName: string;
    procedure ExecTxSql(const ASQL: string);
    class function NewSavepointName: string; static;
  public
    constructor Create(const Ctx: TUniQueryContext);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

procedure TUniTransaction.ExecTxSql(const ASQL: string);
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FCtx.Connection;
    Q.SQL.Text := ASQL;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

class function TUniTransaction.NewSavepointName: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := 'sp_' + StringReplace(StringReplace(Copy(GuidToString(G), 2, 36),
    '-', '', [rfReplaceAll]), '}', '', [rfReplaceAll]);
end;

constructor TUniTransaction.Create(const Ctx: TUniQueryContext);
begin
  inherited Create;
  FCtx := Ctx;
  FCommitted := False;
  FRolledBack := False;
  FUseSavepoint := Assigned(FCtx.Connection) and FCtx.Connection.InTransaction;
  FSavepointName := '';

  if FUseSavepoint then
  begin
    FSavepointName := NewSavepointName;
    ExecTxSql('SAVEPOINT ' + FSavepointName);
  end
  else
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
    if FUseSavepoint then
      ExecTxSql('RELEASE SAVEPOINT ' + FSavepointName)
    else
      FCtx.Connection.Commit;
    FCommitted := True;
  end;
end;

procedure TUniTransaction.Rollback;
begin
  if not FCommitted and not FRolledBack then
  begin
    if FUseSavepoint then
    begin
      ExecTxSql('ROLLBACK TO SAVEPOINT ' + FSavepointName);
      ExecTxSql('RELEASE SAVEPOINT ' + FSavepointName);
    end
    else
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

{ 查询执行 - 简化实�?}

function UniDbSelect(const ProcName: string; const ParamsJson: string;
  var Data: TFDMemTable; const Ctx: TUniQueryContext): Integer;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  SQL: string;
  Pooled: Boolean;
begin
  StartTime := Now;

  // �?Queries 表加�?SQL 或直接使�?
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
      if Q.Prepared then
        Q.Unprepare;
      Q.Params.ClearValues;
      Q.FetchOptions.Mode := fmAll;

      // 绑定参数
      BindJsonParams(Q, ParamsJson);

      Q.Open;
      Result := Q.RecordCount;

      // 复制数据�?TFDMemTable
      if Data = nil then
        Data := TFDMemTable.Create(nil);
      CopyQueryToMemTable(Q, Data);

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, StartTime, True, 'DoQry:' + Ctx.CorrelationId, '', Result);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT',
        SQL, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, StartTime, False, 'DoQry:' + Ctx.CorrelationId, E.Message, 0);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EDeepBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E));
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
  SQL: string;
  Pooled: Boolean;
begin
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
      if Q.Prepared then
        Q.Unprepare;
      Q.Params.ClearValues;
      // 绑定参数
      BindJsonParams(Q, ParamsJson);

      Q.ExecSQL;
      Result := Q.RowsAffected;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, StartTime, True, 'DoQry:' + Ctx.CorrelationId, '', Result);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
        SQL, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, StartTime, False, 'DoQry:' + Ctx.CorrelationId, E.Message, 0);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EDeepBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E));
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
  IdQuery: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  SQL: string;
  Pooled: Boolean;

  function TrimStatementTerminator(const RawSQL: string): string;
  begin
    Result := Trim(RawSQL);
    while (Result <> '') and (Result[Length(Result)] = ';') do
    begin
      Delete(Result, Length(Result), 1);
      Result := Trim(Result);
    end;
  end;

  function EnsureReturningId(const RawSQL: string): string;
  begin
    Result := TrimStatementTerminator(RawSQL);
    if Pos('RETURNING', UpperCase(Result)) = 0 then
      Result := Result + ' RETURNING id';
  end;

  function StripReturningClause(const RawSQL: string): string;
  var
    P: Integer;
    Upper: string;
  begin
    Result := TrimStatementTerminator(RawSQL);
    Upper := UpperCase(Result);
    P := Pos(' RETURNING ', Upper);
    if P > 0 then
      Result := Trim(Copy(Result, 1, P - 1));
  end;

begin
  Result := 0;
  StartTime := Now;

  SQL := LoadQuerySQL(ProcName, Ctx);

  // PERSIST-020: rewrite SQL up-front so the pool key matches the actual
  // statement we are going to execute. Without this, the pool would key on
  // the un-rewritten SQL and we would re-prepare on every call.
  case Ctx.DBType of
    udbPostgreSQL: SQL := EnsureReturningId(SQL);
    udbSQLite:     SQL := StripReturningClause(SQL);
  end;

  // PERSIST-020: use the same prepared-statement pool that
  // UniDbSelect/UniDbExec/UniDbScalar already use. This keeps INSERT plans
  // hot across repeated calls (especially relevant for tight commerce /
  // logging insert loops).
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
      if Q.Prepared then
        Q.Unprepare;
      Q.Params.ClearValues;

      case Ctx.DBType of
        udbPostgreSQL:
        begin
          BindJsonParams(Q, ParamsJson);
          Q.Open;
          if not Q.Eof then
            Result := Q.Fields[0].AsInteger;
        end;

        udbSQLite:
        begin
          BindJsonParams(Q, ParamsJson);
          Q.ExecSQL;

          // SQLite returns the inserted rowid on a separate query. Use a
          // disposable, non-pooled TFDQuery so we never rewrite the SQL on
          // the pooled INSERT statement (which would defeat the pool).
          IdQuery := TFDQuery.Create(nil);
          try
            IdQuery.Connection := Ctx.Connection;
            IdQuery.SQL.Text := 'SELECT last_insert_rowid()';
            IdQuery.Open;
            if not IdQuery.Eof then
              Result := IdQuery.Fields[0].AsInteger;
          finally
            IdQuery.Free;
          end;
        end;
      end;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      TSQLLogger.LogSQL(SQL, StartTime, True, 'DoQry:' + Ctx.CorrelationId, '', 1);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        TSQLLogger.LogSQL(SQL, StartTime, False, 'DoQry:' + Ctx.CorrelationId, E.Message, 0);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EDeepBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E));
      end;
    end;
  finally
    ReleaseQuery(Q, Pooled);
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
      if Q.Prepared then
        Q.Unprepare;
      Q.Params.ClearValues;
      // 绑定参数（与 UniDbSelect/UniDbExec 一致）
      BindJsonParams(Q, ParamsJson);

      Q.Open;

      if not Q.Eof and (Q.Fields.Count > 0) then
        Result := Q.Fields[0].Value;

      DurationMs := MilliSecondsBetween(Now, StartTime);

      // BUG-032 FIX: 集成TSQLLogger进行慢查询监控和统计
      TSQLLogger.LogSQL(SQL, StartTime, True, 'DoQry:' + Ctx.CorrelationId, '', 1);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, StartTime, False, 'DoQry:' + Ctx.CorrelationId, E.Message, 0);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EDeepBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E));
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
  if Assigned(GPreparedPoolLock) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      if Assigned(GPreparedPool) then
        GPreparedPool.Clear;
      if Assigned(GPreparedQueryIndex) then
        GPreparedQueryIndex.Clear;
      GPreparedReuseCount := 0;
      GPreparedUseTick := 0;
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

procedure UniDbSweepConnectionFromPool(Conn: TFDConnection);
var
  Pair: TPair<string, TPreparedEntry>;
  KeysToRemove: TList<string>;
  Key: string;
  Entry: TPreparedEntry;
begin
  if (Conn = nil) or not Assigned(GPreparedPoolLock) then
    Exit;

  TMonitor.Enter(GPreparedPoolLock);
  try
    if (GPreparedPool = nil) or (GPreparedPool.Count = 0) then
      Exit;

    KeysToRemove := TList<string>.Create;
    try
      for Pair in GPreparedPool do
        if Assigned(Pair.Value) and (Pair.Value.Connection = Conn) then
          KeysToRemove.Add(Pair.Key);

      for Key in KeysToRemove do
      begin
        if GPreparedPool.TryGetValue(Key, Entry) and Assigned(Entry) then
        begin
          if Assigned(GPreparedQueryIndex) and Assigned(Entry.Query) then
            GPreparedQueryIndex.Remove(Entry.Query);
        end;
        GPreparedPool.Remove(Key);
      end;
    finally
      KeysToRemove.Free;
    end;
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;
end;

procedure UniDbSetPreparedPoolMaxSize(MaxSize: Integer);
begin
  if MaxSize < 1 then
    MaxSize := 1;

  if Assigned(GPreparedPoolLock) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      GPreparedPoolMaxSize := MaxSize;
      if Assigned(GPreparedPool) then
        EnforcePreparedPoolLimit(nil);
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end
  else
    GPreparedPoolMaxSize := MaxSize;
end;

{ TDoQryService }

function TDoQryService.Select(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
var
  Data: TFDMemTable;
begin
  Data := TFDMemTable.Create(nil);
  try
    Result := IntToStr(UniDbSelect(ProcName, ParamsJson, Data, Ctx));
  finally
    Data.Free;
  end;
end;

function TDoQryService.Exec(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
begin
  Result := IntToStr(UniDbExec(ProcName, ParamsJson, Ctx));
end;

function TDoQryService.Scalar(const ProcName, ParamsJson: string; const Ctx: TUniQueryContext): string;
begin
  Result := VarToStr(UniDbScalar(ProcName, ParamsJson, Ctx));
end;

procedure TDoQryService.RunInTx(const Ctx: TUniQueryContext; const Proc: TProc);
begin
  UniDbRunInTx(Ctx, Proc);
end;

procedure TDoQryService.ClearCache;
begin
  UniDbClearQueryCache;
end;

procedure TDoQryService.Shutdown;
begin
  UniDbShutdown;
end;

initialization
  GQueryCacheLock := TObject.Create;
  GQueryCache := TDictionary<string, TQueryCacheEntry>.Create;
  GQueryCacheLoading := TDictionary<string, Byte>.Create;
  GPreparedPoolLock := TObject.Create;
  GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);
  GPreparedQueryIndex := TDictionary<TFDQuery, TPreparedEntry>.Create;

finalization
  UniDbShutdown;
  FreeAndNil(GPreparedPoolLock);
  FreeAndNil(GQueryCacheLock);

end.

