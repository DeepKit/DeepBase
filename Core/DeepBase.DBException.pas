{ ============================================================================
  DeepBase.DBException - Unified Database Exception Handling

  Version: 1.0.0
  Description: Provides user-friendly database error handling with detailed
               logging for debugging. Sanitizes technical details for end users.
  ============================================================================ }

unit DeepBase.DBException;

interface

uses
  System.SysUtils, System.Classes;

type
  EDeepBaseDB = class(Exception)
  private
    FSQL: string;
    FOperation: string;
    FOriginalError: string;
    FErrorCode: string;
    FSuggestion: string;
    FTimestamp: TDateTime;
    FSessionId: string;
    class var FOnException: TProc<EDeepBaseDB>;
    class var FLogEnabled: Boolean;
    class var FSessionIdProvider: TFunc<string>;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AErrorCode, AMessage, ASuggestion: string); overload;

    class function Wrap(E: Exception; const ASQL, AOperation: string): EDeepBaseDB;
    class function FromCode(const AErrorCode: string; const ADetail: string = ''): EDeepBaseDB;

    function UserMessage: string;
    function DetailedMessage: string;
    procedure LogException;

    class property LogEnabled: Boolean read FLogEnabled write FLogEnabled;
    class property OnException: TProc<EDeepBaseDB> read FOnException write FOnException;
    class property SessionIdProvider: TFunc<string> read FSessionIdProvider write FSessionIdProvider;

    property SQL: string read FSQL;
    property Operation: string read FOperation;
    property OriginalError: string read FOriginalError;
    property ErrorCode: string read FErrorCode;
    property Suggestion: string read FSuggestion;
    property Timestamp: TDateTime read FTimestamp;
    property SessionId: string read FSessionId;
  end;

const
  ERR_DB_CONNECTION_FAILED    = 'DB-1001';
  ERR_DB_CONNECTION_LOST      = 'DB-1002';
  ERR_DB_CONNECTION_TIMEOUT   = 'DB-1003';
  ERR_DB_DATABASE_NOT_FOUND   = 'DB-1004';
  ERR_DB_ACCESS_DENIED        = 'DB-1005';
  ERR_DB_DATABASE_LOCKED      = 'DB-1006';

  ERR_DB_QUERY_FAILED         = 'DB-2001';
  ERR_DB_SYNTAX_ERROR         = 'DB-2002';
  ERR_DB_TABLE_NOT_FOUND      = 'DB-2003';
  ERR_DB_COLUMN_NOT_FOUND     = 'DB-2004';
  ERR_DB_QUERY_TIMEOUT        = 'DB-2005';
  ERR_DB_INVALID_PARAMETER    = 'DB-2006';

  ERR_DB_UNIQUE_VIOLATION     = 'DB-3001';
  ERR_DB_FOREIGN_KEY          = 'DB-3002';
  ERR_DB_NOT_NULL_VIOLATION   = 'DB-3003';
  ERR_DB_CHECK_VIOLATION      = 'DB-3004';
  ERR_DB_PRIMARY_KEY          = 'DB-3005';

  ERR_DB_TYPE_MISMATCH        = 'DB-4001';
  ERR_DB_OVERFLOW             = 'DB-4002';
  ERR_DB_INVALID_DATE         = 'DB-4003';
  ERR_DB_STRING_TOO_LONG      = 'DB-4004';

  ERR_DB_SCHEMA_MISMATCH      = 'DB-5001';
  ERR_DB_MIGRATION_FAILED     = 'DB-5002';
  ERR_DB_TABLE_EXISTS         = 'DB-5003';

  ERR_DB_UNKNOWN              = 'DB-9001';

function GetErrorMessage(const AErrorCode: string): string;
function GetErrorSuggestion(const AErrorCode: string): string;
function AnalyzeException(E: Exception): string;

implementation

uses
  System.StrUtils;

function GetErrorMessage(const AErrorCode: string): string;
begin
  if AErrorCode = ERR_DB_CONNECTION_FAILED then Result := '无法连接到数据库'
  else if AErrorCode = ERR_DB_CONNECTION_LOST then Result := '数据库连接已断开'
  else if AErrorCode = ERR_DB_CONNECTION_TIMEOUT then Result := '数据库连接超时'
  else if AErrorCode = ERR_DB_DATABASE_NOT_FOUND then Result := '数据库文件不存在'
  else if AErrorCode = ERR_DB_ACCESS_DENIED then Result := '数据库访问被拒绝'
  else if AErrorCode = ERR_DB_DATABASE_LOCKED then Result := '数据库被其他进程锁定'
  else if AErrorCode = ERR_DB_QUERY_FAILED then Result := '数据库查询失败'
  else if AErrorCode = ERR_DB_SYNTAX_ERROR then Result := 'SQL 语法错误'
  else if AErrorCode = ERR_DB_TABLE_NOT_FOUND then Result := '数据库表不存在'
  else if AErrorCode = ERR_DB_COLUMN_NOT_FOUND then Result := '数据库字段不存在'
  else if AErrorCode = ERR_DB_QUERY_TIMEOUT then Result := '数据库查询超时'
  else if AErrorCode = ERR_DB_INVALID_PARAMETER then Result := '数据库查询参数无效'
  else if AErrorCode = ERR_DB_UNIQUE_VIOLATION then Result := '数据已存在，不能重复添加'
  else if AErrorCode = ERR_DB_FOREIGN_KEY then Result := '关联数据缺失或不能删除'
  else if AErrorCode = ERR_DB_NOT_NULL_VIOLATION then Result := '必填字段不能为空'
  else if AErrorCode = ERR_DB_CHECK_VIOLATION then Result := '数据不符合数据库约束'
  else if AErrorCode = ERR_DB_PRIMARY_KEY then Result := '主键冲突'
  else if AErrorCode = ERR_DB_TYPE_MISMATCH then Result := '数据类型不匹配'
  else if AErrorCode = ERR_DB_OVERFLOW then Result := '数值超出范围'
  else if AErrorCode = ERR_DB_INVALID_DATE then Result := '日期值无效'
  else if AErrorCode = ERR_DB_STRING_TOO_LONG then Result := '文本长度超出限制'
  else if AErrorCode = ERR_DB_SCHEMA_MISMATCH then Result := '数据库结构版本不匹配'
  else if AErrorCode = ERR_DB_MIGRATION_FAILED then Result := '数据库迁移失败'
  else if AErrorCode = ERR_DB_TABLE_EXISTS then Result := '数据库表已存在'
  else Result := '数据库操作失败';
end;

function GetErrorSuggestion(const AErrorCode: string): string;
begin
  if AErrorCode = ERR_DB_CONNECTION_FAILED then Result := 'Check database path, server address, and network connectivity'
  else if AErrorCode = ERR_DB_CONNECTION_LOST then Result := 'Check the network connection and retry'
  else if AErrorCode = ERR_DB_CONNECTION_TIMEOUT then Result := 'The database server may be busy; retry later'
  else if AErrorCode = ERR_DB_DATABASE_NOT_FOUND then Result := 'Confirm the database path or name is correct'
  else if AErrorCode = ERR_DB_ACCESS_DENIED then Result := 'Check file permissions or run with sufficient privileges'
  else if AErrorCode = ERR_DB_DATABASE_LOCKED then Result := 'Close other programs using this database and retry'
  else if AErrorCode = ERR_DB_QUERY_FAILED then Result := 'Check input data and retry; contact support if the issue persists'
  else if AErrorCode = ERR_DB_SYNTAX_ERROR then Result := 'Internal SQL error; contact support with code ' + AErrorCode
  else if AErrorCode = ERR_DB_TABLE_NOT_FOUND then Result := 'Database schema may be damaged; run diagnostics or migration'
  else if AErrorCode = ERR_DB_COLUMN_NOT_FOUND then Result := 'Database version may be outdated; run migration'
  else if AErrorCode = ERR_DB_QUERY_TIMEOUT then Result := 'Narrow the query scope and retry'
  else if AErrorCode = ERR_DB_INVALID_PARAMETER then Result := 'Check the supplied parameter values'
  else if AErrorCode = ERR_DB_UNIQUE_VIOLATION then Result := 'Check whether the same record already exists'
  else if AErrorCode = ERR_DB_FOREIGN_KEY then Result := 'Create or keep related records before this operation'
  else if AErrorCode = ERR_DB_NOT_NULL_VIOLATION then Result := 'Fill all required fields and retry'
  else if AErrorCode = ERR_DB_CHECK_VIOLATION then Result := 'Check whether the input data meets database rules'
  else if AErrorCode = ERR_DB_PRIMARY_KEY then Result := 'Refresh the data and retry'
  else if AErrorCode = ERR_DB_TYPE_MISMATCH then Result := 'Check the input data format'
  else if AErrorCode = ERR_DB_OVERFLOW then Result := 'Enter a smaller numeric value'
  else if AErrorCode = ERR_DB_INVALID_DATE then Result := 'Use a valid date format, for example 2026-05-07'
  else if AErrorCode = ERR_DB_STRING_TOO_LONG then Result := 'Shorten the input text'
  else if AErrorCode = ERR_DB_SCHEMA_MISMATCH then Result := 'Run the database migration tool'
  else if AErrorCode = ERR_DB_MIGRATION_FAILED then Result := 'Back up the database and contact support'
  else if AErrorCode = ERR_DB_TABLE_EXISTS then Result := 'The table already exists; no action is required'
  else Result := 'Contact support with code ' + AErrorCode;
end;

function AnalyzeException(E: Exception): string;
var
  Msg: string;
begin
  if E = nil then
    Exit(ERR_DB_UNKNOWN);

  Msg := UpperCase(E.Message);

  if ContainsText(Msg, 'UNIQUE CONSTRAINT') or ContainsText(Msg, 'UNIQUE_VIOLATION') or
     ContainsText(Msg, 'DUPLICATE KEY') or ContainsText(Msg, 'ALREADY EXISTS') then
    Result := ERR_DB_UNIQUE_VIOLATION
  else if ContainsText(Msg, 'FOREIGN KEY') or ContainsText(Msg, 'REFERENCES') then
    Result := ERR_DB_FOREIGN_KEY
  else if ContainsText(Msg, 'NOT NULL') or ContainsText(Msg, 'NULL_VIOLATION') then
    Result := ERR_DB_NOT_NULL_VIOLATION
  else if ContainsText(Msg, 'CHECK CONSTRAINT') then
    Result := ERR_DB_CHECK_VIOLATION
  else if ContainsText(Msg, 'PRIMARY KEY') then
    Result := ERR_DB_PRIMARY_KEY
  else if ContainsText(Msg, 'NO SUCH TABLE') or ContainsText(Msg, 'TABLE_NOT_FOUND') then
    Result := ERR_DB_TABLE_NOT_FOUND
  else if ContainsText(Msg, 'NO SUCH COLUMN') or ContainsText(Msg, 'COLUMN_NOT_FOUND') then
    Result := ERR_DB_COLUMN_NOT_FOUND
  else if ContainsText(Msg, 'SYNTAX ERROR') or ContainsText(Msg, 'SYNTAX_ERROR') then
    Result := ERR_DB_SYNTAX_ERROR
  else if ContainsText(Msg, 'DATABASE IS LOCKED') or ContainsText(Msg, 'SQLITE_BUSY') then
    Result := ERR_DB_DATABASE_LOCKED
  else if ContainsText(Msg, 'UNABLE TO OPEN') or ContainsText(Msg, 'FILE NOT FOUND') or
          ContainsText(Msg, 'DATABASE NOT FOUND') then
    Result := ERR_DB_DATABASE_NOT_FOUND
  else if ContainsText(Msg, 'ACCESS DENIED') or ContainsText(Msg, 'PERMISSION DENIED') then
    Result := ERR_DB_ACCESS_DENIED
  else if ContainsText(Msg, 'TIMEOUT') or ContainsText(Msg, 'TIMED OUT') then
    Result := ERR_DB_QUERY_TIMEOUT
  else if ContainsText(Msg, 'CONNECTION') and
          (ContainsText(Msg, 'LOST') or ContainsText(Msg, 'CLOSED') or ContainsText(Msg, 'TERMINATED')) then
    Result := ERR_DB_CONNECTION_LOST
  else if ContainsText(Msg, 'CONNECT') and ContainsText(Msg, 'FAIL') then
    Result := ERR_DB_CONNECTION_FAILED
  else if ContainsText(Msg, 'TYPE MISMATCH') or ContainsText(Msg, 'DATATYPE') then
    Result := ERR_DB_TYPE_MISMATCH
  else if ContainsText(Msg, 'OVERFLOW') or ContainsText(Msg, 'OUT OF RANGE') then
    Result := ERR_DB_OVERFLOW
  else
    Result := ERR_DB_UNKNOWN;
end;

constructor EDeepBaseDB.Create(const AMessage: string);
begin
  inherited Create(AMessage);
  FErrorCode := ERR_DB_UNKNOWN;
  FSuggestion := GetErrorSuggestion(FErrorCode);
  FTimestamp := Now;
  if Assigned(FSessionIdProvider) then
    FSessionId := FSessionIdProvider()
  else
    FSessionId := '';
end;

constructor EDeepBaseDB.Create(const AErrorCode, AMessage, ASuggestion: string);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FSuggestion := ASuggestion;
  FTimestamp := Now;
  if Assigned(FSessionIdProvider) then
    FSessionId := FSessionIdProvider()
  else
    FSessionId := '';
end;

class function EDeepBaseDB.Wrap(E: Exception; const ASQL, AOperation: string): EDeepBaseDB;
var
  Code: string;
begin
  Code := AnalyzeException(E);
  Result := EDeepBaseDB.Create(Code, GetErrorMessage(Code), GetErrorSuggestion(Code));
  Result.FSQL := ASQL;
  Result.FOperation := AOperation;
  if Assigned(E) then
    Result.FOriginalError := E.Message
  else
    Result.FOriginalError := '';

  if Assigned(FOnException) then
    FOnException(Result);

  if FLogEnabled then
    Result.LogException;
end;

class function EDeepBaseDB.FromCode(const AErrorCode: string; const ADetail: string): EDeepBaseDB;
var
  Msg: string;
begin
  Msg := GetErrorMessage(AErrorCode);
  if ADetail <> '' then
    Msg := Msg + ': ' + ADetail;

  Result := EDeepBaseDB.Create(AErrorCode, Msg, GetErrorSuggestion(AErrorCode));

  if Assigned(FOnException) then
    FOnException(Result);

  if FLogEnabled then
    Result.LogException;
end;

function EDeepBaseDB.UserMessage: string;
begin
  if FOperation <> '' then
    Result := Message + ' (Operation: ' + FOperation + ')'
  else
    Result := Message;

  if FSuggestion <> '' then
    Result := Result + #13#10 + FSuggestion;
end;

function EDeepBaseDB.DetailedMessage: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('--------------------------------------------------');
    SB.AppendLine('DeepBase Database Exception');
    SB.AppendLine('--------------------------------------------------');
    SB.AppendFormat('Error Code: %s', [FErrorCode]);
    SB.AppendLine;
    SB.AppendFormat('Time: %s', [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', FTimestamp)]);
    SB.AppendLine;
    if FSessionId <> '' then
    begin
      SB.AppendFormat('Session: %s', [FSessionId]);
      SB.AppendLine;
    end;
    SB.AppendLine;
    SB.AppendFormat('Operation: %s', [FOperation]);
    SB.AppendLine;
    SB.AppendFormat('Message: %s', [Message]);
    SB.AppendLine;
    SB.AppendLine;
    SB.AppendLine('Original Error:');
    SB.AppendLine(FOriginalError);
    SB.AppendLine;
    if FSQL <> '' then
    begin
      SB.AppendLine('SQL Statement:');
      SB.AppendLine(FSQL);
      SB.AppendLine;
    end;
    SB.AppendLine('Suggestion:');
    SB.AppendLine(FSuggestion);
    SB.AppendLine('--------------------------------------------------');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure EDeepBaseDB.LogException;
begin
  {$IFDEF DEBUG}
  System.Writeln(DetailedMessage);
  {$ENDIF}
end;

initialization
  EDeepBaseDB.FLogEnabled := True;
  EDeepBaseDB.FOnException := nil;
  EDeepBaseDB.FSessionIdProvider := nil;

end.
