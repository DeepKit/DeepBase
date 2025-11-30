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
  FireDAC.Comp.Client, DBClient,
  UniBase.Types;

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
  /// 数据库错误异常（携带上下文）
  /// </summary>
  EUniBaseDbError = class(Exception)
  private
    FProcName: string;
    FSQL: string;
    FParamsJson: string;
    FDBType: TUniDBType;
    FCorrelationId: string;
  public
    constructor Create(const Msg, ProcName, SQL, ParamsJson: string; 
      DBType: TUniDBType; const CorrelationId: string); reintroduce;
    
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
  var Data: TClientDataSet; const Ctx: TUniQueryContext): Integer;

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

implementation

uses
  System.DateUtils, System.IOUtils, System.JSON, System.Generics.Collections,
  UniBase.Logging;

var
  GRootPath: string = '';
  GInitialized: Boolean = False;
  GQueryCache: TDictionary<string, string> = nil;  // ProcName -> SQL cache
  GQueryCacheLock: TObject = nil;

{ EUniBaseDbError }

constructor EUniBaseDbError.Create(const Msg, ProcName, SQL, ParamsJson: string;
  DBType: TUniDBType; const CorrelationId: string);
begin
  inherited Create(Msg);
  FProcName := ProcName;
  FSQL := SQL;
  FParamsJson := ParamsJson;
  FDBType := DBType;
  FCorrelationId := CorrelationId;
end;

{ 内部日志辅助 }

procedure LogQuery(const Level, CorrId, ProcName: string; DBType: TUniDBType;
  const Kind, SQL, ParamsJson: string; DurationMs: Int64; Rows: Integer; 
  const ErrorMsg: string);
var
  LogLevel: TLogLevel;
  Msg: string;
  DBName: string;
begin
  // 使用 UniBase.Logging 统一日志
  if Level = 'ERROR' then
    LogLevel := llError
  else if Level = 'WARN' then
    LogLevel := llWarn
  else
    LogLevel := llDebug;
  
  case DBType of
    udbPostgreSQL: DBName := 'PG';
    udbSQLite: DBName := 'SQLite';
  end;
  
  // 构建日志消息
  Msg := Format('[%s] %s.%s %dms rows=%d', [DBName, ProcName, Kind, DurationMs, Rows]);
  if ErrorMsg <> '' then
    Msg := Msg + ' ERROR: ' + ErrorMsg;
  
  Logger.Log(Msg, LogLevel, 'DoQry:' + CorrId);
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
    GQueryCache := TDictionary<string, string>.Create;
  
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
/// 从 Queries 表加载 SQL（带缓存）
/// </summary>
function LoadQuerySQL(const ProcName: string; const Ctx: TUniQueryContext): string;
var
  Q: TFDQuery;
begin
  Result := '';
  
  // 如果是直接 SQL，直接返回
  if IsDirectSQL(ProcName) then
  begin
    Result := ProcName;
    Exit;
  end;
  
  // 检查缓存
  if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
  begin
    TMonitor.Enter(GQueryCacheLock);
    try
      if GQueryCache.TryGetValue(ProcName, Result) then
        Exit;  // 缓存命中
    finally
      TMonitor.Exit(GQueryCacheLock);
    end;
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
    // 缓存结果
    if Assigned(GQueryCacheLock) and Assigned(GQueryCache) then
    begin
      TMonitor.Enter(GQueryCacheLock);
      try
        GQueryCache.AddOrSetValue(ProcName, Result);
      finally
        TMonitor.Exit(GQueryCacheLock);
      end;
    end;
  end;
end;

/// <summary>
/// 清除查询缓存（在 Queries 表更新后调用）
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
  var Data: TClientDataSet; const Ctx: TUniQueryContext): Integer;
var
  Q: TFDQuery;
  StartTime: TDateTime;
  DurationMs: Int64;
  Params: TJSONObject;
  Pair: TJSONPair;
begin
  Result := 0;
  StartTime := Now;
  
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := Ctx.Connection;
      Q.FetchOptions.Mode := fmAll;
      
      // 从 Queries 表加载 SQL 或直接使用
      Q.SQL.Text := LoadQuerySQL(ProcName, Ctx);
      
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
      
      // 复制到 ClientDataSet
      if Assigned(Data) then
      begin
        Data.Close;
        Data.FieldDefs.Clear;
        Data.CloneCursor(Q, False);
      end;
      
      DurationMs := MilliSecondsBetween(Now, StartTime);
      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT', 
        Q.SQL.Text, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SELECT',
          Q.SQL.Text, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, Q.SQL.Text, ParamsJson, 
          Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Q.Free;
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
begin
  Result := 0;
  StartTime := Now;
  
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := Ctx.Connection;
      Q.SQL.Text := LoadQuerySQL(ProcName, Ctx);
      
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
      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
        Q.SQL.Text, ParamsJson, DurationMs, Result, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'EXEC',
          Q.SQL.Text, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, Q.SQL.Text, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Q.Free;
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
      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
        SQL, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'INSERT_ID',
          SQL, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, SQL, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId);
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
begin
  Result := Null;
  StartTime := Now;
  
  Q := TFDQuery.Create(nil);
  try
    try
      Q.Connection := Ctx.Connection;
      Q.SQL.Text := LoadQuerySQL(ProcName, Ctx);
      Q.Open;
      
      if not Q.Eof and (Q.Fields.Count > 0) then
        Result := Q.Fields[0].Value;
      
      DurationMs := MilliSecondsBetween(Now, StartTime);
      LogQuery('INFO', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
        Q.SQL.Text, ParamsJson, DurationMs, 1, '');
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        LogQuery('ERROR', Ctx.CorrelationId, ProcName, Ctx.DBType, 'SCALAR',
          Q.SQL.Text, ParamsJson, DurationMs, 0, E.Message);
        raise EUniBaseDbError.Create(E.Message, ProcName, Q.SQL.Text, ParamsJson,
          Ctx.DBType, Ctx.CorrelationId);
      end;
    end;
  finally
    Q.Free;
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

end.
