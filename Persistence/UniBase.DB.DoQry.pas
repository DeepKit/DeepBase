{ ============================================================================
  UniBase.DB.DoQry - DoQry 数据库访问集成模块
  
  版本: 1.0
  所属包: UniBasePersistence
  说明: 将 DoQry 库集成到 UniBase 框架，统一日志和错误处理
  线程安全: 所有公共方法均线程安全
  ============================================================================ }

unit UniBase.DB.DoQry;

interface

uses
  System.SysUtils, System.Classes, System.Variants,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet,
  UniBase.Types, UniBase.Exceptions;

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
  EUniBaseDbError = class(EUniBaseException)
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

  /// <summary>DoQry service implementation — delegates to global functions</summary>
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

procedure UniDbShutdown;
begin
  // 清理查询缓存；锁对象由 initialization/finalization 管理。
  if Assigned(GQueryCacheLock) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      FreeAndNil(GQueryCache);
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end
  else
    FreeAndNil(GQueryCache);

  // 清理预编译语句池；锁对象由 initialization/finalization 管理。
  if Assigned(GPreparedPoolLock) then
  begin
    TMonitor.Enter(GPreparedPoolLock);
    try
      FreeAndNil(GPreparedPool);
    finally
      TMonitor.Exit(GPreparedPoolLock);
    end;
  end
  else
    FreeAndNil(GPreparedPool);
end;

destructor TPreparedEntry.Destroy;
begin
  FreeAndNil(FQuery);
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
/// 根据异常消息推断错误码（兼容回退）
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
/// 根据异常对象推断错误码（优先使用 FireDAC 原生错误类型）
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
    if GPreparedPool = nil then
      GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);

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
  // 不在此处预编译：参数值未绑定时会导致类型未知错误
  
  Entry := TPreparedEntry.Create(Result, Conn, SimpleHash(SQL));
  
  TMonitor.Enter(GPreparedPoolLock);
  try
    if GPreparedPool = nil then
      GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);

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

/// <summary>
/// 绑定 JSON 参数到查询（自动识别 GUID）
/// </summary>
procedure BindJsonParams(Q: TFDQuery; const ParamsJson: string);
var
  Params: TJSONObject;
  Pair: TJSONPair;
  P: TFDParam;
  S: string;
  G: TGUID;

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
        P.Clear
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
        if (S <> '') then
        begin
          // Try GUID detection: {xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx}
          if (Length(S) = 38) and (S[1] = '{') and (S[Length(S)] = '}') then
          begin
            if TryParseGuid(S, G) then
            begin
              P.DataType := ftGuid;
              P.AsGUID := G;
              Continue;
            end;
          end
          // Try GUID without braces: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
          else if (Length(S) = 36) and (S[9] = '-') and IsHexWithDashes(S, 1, 36) then
          begin
            if TryParseGuid('{' + S + '}', G) then
            begin
              P.DataType := ftGuid;
              P.AsGUID := G;
              Continue;
            end;
          end
          // Try compact GUID: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx (32 hex chars)
          else if (Length(S) = 32) and IsHexWithDashes(S, 1, 32) then
          begin
            if TryParseGuid('{' + Copy(S,1,8) + '-' + Copy(S,9,4) + '-' +
               Copy(S,13,4) + '-' + Copy(S,17,4) + '-' + Copy(S,21,12) + '}', G) then
            begin
              P.DataType := ftGuid;
              P.AsGUID := G;
              Continue;
            end;
          end;
        end;
        if S = '' then
          P.AsString := S
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
    GCacheHits := 0;
    GCacheMisses := 0;
  finally
    TMonitor.Exit(GQueryCacheLock);
  end;

  TMonitor.Enter(GPreparedPoolLock);
  try
    if GPreparedPool = nil then
      GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);
    GPreparedReuseCount := 0;
  finally
    TMonitor.Exit(GPreparedPoolLock);
  end;

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
            (Pos('WITH ', Upper) = 1);
end;

/// <summary>
/// 从 Queries 表加载 SQL（带缓存 + TTL）
/// </summary>
function LoadQuerySQL(const ProcName: string; const Ctx: TUniQueryContext): string;
var
  Q: TFDQuery;
  Entry: TQueryCacheEntry;
  Found: Boolean;
  LoadedSQL: string;

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
  if Assigned(GQueryCacheLock) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      Inc(GCacheMisses);
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
  end;
  
  // 从数据库查询
  if not Assigned(Ctx.Connection) or not Ctx.Connection.Connected then
  begin
    raise EUniBaseDbError.Create(
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
    raise EUniBaseDbError.Create(
      Format('Query definition not found: %s', [ProcName]),
      ProcName, '', '', Ctx.DBType, Ctx.CorrelationId, DOQRY_ERR_QUERY_NOT_FOUND);

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
  SQL: string;
  Pooled: Boolean;
begin
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
      if Q.Prepared then
        Q.Unprepare;
      Q.Params.ClearValues;
      Q.FetchOptions.Mode := fmAll;

      // 绑定参数
      BindJsonParams(Q, ParamsJson);

      Q.Open;
      Result := Q.RecordCount;

      // 复制数据到 TFDMemTable
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
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
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
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
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

      BindJsonParams(Q, ParamsJson);

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
      TSQLLogger.LogSQL(SQL, StartTime, True, 'DoQry:' + Ctx.CorrelationId, '', 1);

      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);

        // BUG-032 FIX: 记录失败的查询到SQLLogger
        TSQLLogger.LogSQL(SQL, StartTime, False, 'DoQry:' + Ctx.CorrelationId, E.Message, 0);

        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId, InferErrorCode(E));
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
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
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
  GPreparedPoolLock := TObject.Create;
  GPreparedPool := TObjectDictionary<string, TPreparedEntry>.Create([doOwnsValues]);

finalization
  UniDbShutdown;
  FreeAndNil(GPreparedPoolLock);
  FreeAndNil(GQueryCacheLock);

end.

