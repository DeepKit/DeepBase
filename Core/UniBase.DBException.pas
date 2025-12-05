{ ============================================================================
  UniBase.DBException - Unified Database Exception Handling
  
  Version: 1.0.0
  Description: Provides user-friendly database error handling with detailed
               logging for debugging. Sanitizes technical details for end users.
  
  Features:
    - User-friendly error messages (no raw SQL exposed)
    - Detailed logging for developers
    - Error code system for easy lookup
    - Original exception preservation
    - Suggestion hints for common errors
  
  Usage:
    try
      Query.ExecSQL;
    except
      on E: Exception do
        raise EUniBaseDB.Wrap(E, Query.SQL.Text, 'Saving user profile');
    end;
    
  Error Codes:
    DB-1xxx: Connection errors
    DB-2xxx: Query/SQL errors
    DB-3xxx: Constraint violations
    DB-4xxx: Data type errors
    DB-5xxx: Schema errors
    DB-9xxx: Unknown/Other errors
  ============================================================================ }

unit UniBase.DBException;

interface

uses
  System.SysUtils, System.Classes;

type
  /// <summary>
  /// Unified database exception with user-friendly messages and detailed logging
  /// </summary>
  EUniBaseDB = class(Exception)
  private
    FSQL: string;
    FOperation: string;
    FOriginalError: string;
    FErrorCode: string;
    FSuggestion: string;
    FTimestamp: TDateTime;
    FSessionId: string;
    class var FOnException: TProc<EUniBaseDB>;
    class var FLogEnabled: Boolean;
    class var FSessionIdProvider: TFunc<string>;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AErrorCode, AMessage, ASuggestion: string); overload;
    
    /// <summary>
    /// Wrap an existing exception with UniBase context
    /// </summary>
    class function Wrap(E: Exception; const ASQL, AOperation: string): EUniBaseDB;
    
    /// <summary>
    /// Create from a specific error code
    /// </summary>
    class function FromCode(const AErrorCode: string; const ADetail: string = ''): EUniBaseDB;
    
    /// <summary>
    /// Generate user-friendly message (no SQL/technical details)
    /// </summary>
    function UserMessage: string;
    
    /// <summary>
    /// Generate detailed message for logging/debugging
    /// </summary>
    function DetailedMessage: string;
    
    /// <summary>
    /// Log this exception (if logging is enabled)
    /// </summary>
    procedure LogException;
    
    /// <summary>
    /// Enable/disable automatic exception logging
    /// </summary>
    class property LogEnabled: Boolean read FLogEnabled write FLogEnabled;
    
    /// <summary>
    /// Set callback for exception handling (e.g., for custom logging)
    /// </summary>
    class property OnException: TProc<EUniBaseDB> read FOnException write FOnException;
    
    /// <summary>
    /// Provider function for session ID (for log correlation)
    /// </summary>
    class property SessionIdProvider: TFunc<string> read FSessionIdProvider write FSessionIdProvider;
    
    /// <summary>
    /// Original SQL statement (for debugging only - do not expose to user)
    /// </summary>
    property SQL: string read FSQL;
    
    /// <summary>
    /// Description of the operation being performed
    /// </summary>
    property Operation: string read FOperation;
    
    /// <summary>
    /// Original exception message
    /// </summary>
    property OriginalError: string read FOriginalError;
    
    /// <summary>
    /// Error code for lookup (e.g., DB-1001)
    /// </summary>
    property ErrorCode: string read FErrorCode;
    
    /// <summary>
    /// Suggestion for resolving the error
    /// </summary>
    property Suggestion: string read FSuggestion;
    
    /// <summary>
    /// When the exception occurred
    /// </summary>
    property Timestamp: TDateTime read FTimestamp;
    
    /// <summary>
    /// Session ID for log correlation
    /// </summary>
    property SessionId: string read FSessionId;
  end;

/// <summary>
/// Error code constants
/// </summary>
const
  // Connection errors (DB-1xxx)
  ERR_DB_CONNECTION_FAILED    = 'DB-1001';
  ERR_DB_CONNECTION_LOST      = 'DB-1002';
  ERR_DB_CONNECTION_TIMEOUT   = 'DB-1003';
  ERR_DB_DATABASE_NOT_FOUND   = 'DB-1004';
  ERR_DB_ACCESS_DENIED        = 'DB-1005';
  ERR_DB_DATABASE_LOCKED      = 'DB-1006';
  
  // Query errors (DB-2xxx)
  ERR_DB_QUERY_FAILED         = 'DB-2001';
  ERR_DB_SYNTAX_ERROR         = 'DB-2002';
  ERR_DB_TABLE_NOT_FOUND      = 'DB-2003';
  ERR_DB_COLUMN_NOT_FOUND     = 'DB-2004';
  ERR_DB_QUERY_TIMEOUT        = 'DB-2005';
  ERR_DB_INVALID_PARAMETER    = 'DB-2006';
  
  // Constraint errors (DB-3xxx)
  ERR_DB_UNIQUE_VIOLATION     = 'DB-3001';
  ERR_DB_FOREIGN_KEY          = 'DB-3002';
  ERR_DB_NOT_NULL_VIOLATION   = 'DB-3003';
  ERR_DB_CHECK_VIOLATION      = 'DB-3004';
  ERR_DB_PRIMARY_KEY          = 'DB-3005';
  
  // Data type errors (DB-4xxx)
  ERR_DB_TYPE_MISMATCH        = 'DB-4001';
  ERR_DB_OVERFLOW             = 'DB-4002';
  ERR_DB_INVALID_DATE         = 'DB-4003';
  ERR_DB_STRING_TOO_LONG      = 'DB-4004';
  
  // Schema errors (DB-5xxx)
  ERR_DB_SCHEMA_MISMATCH      = 'DB-5001';
  ERR_DB_MIGRATION_FAILED     = 'DB-5002';
  ERR_DB_TABLE_EXISTS         = 'DB-5003';
  
  // Unknown errors (DB-9xxx)
  ERR_DB_UNKNOWN              = 'DB-9001';

/// <summary>
/// Get user-friendly message for an error code
/// </summary>
function GetErrorMessage(const AErrorCode: string): string;

/// <summary>
/// Get suggestion for an error code
/// </summary>
function GetErrorSuggestion(const AErrorCode: string): string;

/// <summary>
/// Analyze exception message and determine error code
/// </summary>
function AnalyzeException(E: Exception): string;

implementation

uses
  System.StrUtils;

// ============================================================================
// Error message and suggestion lookup
// ============================================================================

function GetErrorMessage(const AErrorCode: string): string;
begin
  // Connection errors
  if AErrorCode = ERR_DB_CONNECTION_FAILED then Result := '无法连接到数据库'
  else if AErrorCode = ERR_DB_CONNECTION_LOST then Result := '数据库连接已断开'
  else if AErrorCode = ERR_DB_CONNECTION_TIMEOUT then Result := '连接数据库超时'
  else if AErrorCode = ERR_DB_DATABASE_NOT_FOUND then Result := '数据库文件未找到'
  else if AErrorCode = ERR_DB_ACCESS_DENIED then Result := '数据库访问被拒绝'
  else if AErrorCode = ERR_DB_DATABASE_LOCKED then Result := '数据库正被其他程序使用'
  // Query errors
  else if AErrorCode = ERR_DB_QUERY_FAILED then Result := '数据库查询失败'
  else if AErrorCode = ERR_DB_SYNTAX_ERROR then Result := '数据库语法错误'
  else if AErrorCode = ERR_DB_TABLE_NOT_FOUND then Result := '数据表不存在'
  else if AErrorCode = ERR_DB_COLUMN_NOT_FOUND then Result := '数据字段不存在'
  else if AErrorCode = ERR_DB_QUERY_TIMEOUT then Result := '查询执行超时'
  else if AErrorCode = ERR_DB_INVALID_PARAMETER then Result := '查询参数无效'
  // Constraint errors
  else if AErrorCode = ERR_DB_UNIQUE_VIOLATION then Result := '数据已存在，不能重复添加'
  else if AErrorCode = ERR_DB_FOREIGN_KEY then Result := '关联数据不存在或无法删除'
  else if AErrorCode = ERR_DB_NOT_NULL_VIOLATION then Result := '必填字段不能为空'
  else if AErrorCode = ERR_DB_CHECK_VIOLATION then Result := '数据值不符合规则'
  else if AErrorCode = ERR_DB_PRIMARY_KEY then Result := '主键冲突'
  // Data type errors
  else if AErrorCode = ERR_DB_TYPE_MISMATCH then Result := '数据类型不匹配'
  else if AErrorCode = ERR_DB_OVERFLOW then Result := '数值超出允许范围'
  else if AErrorCode = ERR_DB_INVALID_DATE then Result := '日期格式无效'
  else if AErrorCode = ERR_DB_STRING_TOO_LONG then Result := '文本长度超出限制'
  // Schema errors
  else if AErrorCode = ERR_DB_SCHEMA_MISMATCH then Result := '数据库结构版本不匹配'
  else if AErrorCode = ERR_DB_MIGRATION_FAILED then Result := '数据库升级失败'
  else if AErrorCode = ERR_DB_TABLE_EXISTS then Result := '数据表已存在'
  // Default
  else Result := '数据库操作失败';
end;

function GetErrorSuggestion(const AErrorCode: string): string;
begin
  // Connection errors
  if AErrorCode = ERR_DB_CONNECTION_FAILED then Result := '请检查数据库文件是否存在，或网络连接是否正常'
  else if AErrorCode = ERR_DB_CONNECTION_LOST then Result := '请检查网络连接，然后重试'
  else if AErrorCode = ERR_DB_CONNECTION_TIMEOUT then Result := '数据库服务器可能繁忙，请稍后重试'
  else if AErrorCode = ERR_DB_DATABASE_NOT_FOUND then Result := '请确认数据库路径是否正确'
  else if AErrorCode = ERR_DB_ACCESS_DENIED then Result := '请检查文件权限或以管理员身份运行'
  else if AErrorCode = ERR_DB_DATABASE_LOCKED then Result := '请关闭其他使用该数据库的程序后重试'
  // Query errors
  else if AErrorCode = ERR_DB_QUERY_FAILED then Result := '请检查输入数据后重试，如问题持续请联系技术支持'
  else if AErrorCode = ERR_DB_SYNTAX_ERROR then Result := '程序内部错误，请联系技术支持 [错误码: ' + AErrorCode + ']'
  else if AErrorCode = ERR_DB_TABLE_NOT_FOUND then Result := '数据库结构可能损坏，建议运行诊断工具'
  else if AErrorCode = ERR_DB_COLUMN_NOT_FOUND then Result := '数据库版本可能过旧，请运行数据库升级'
  else if AErrorCode = ERR_DB_QUERY_TIMEOUT then Result := '查询时间过长，请尝试缩小查询范围'
  else if AErrorCode = ERR_DB_INVALID_PARAMETER then Result := '请检查输入的参数值是否正确'
  // Constraint errors
  else if AErrorCode = ERR_DB_UNIQUE_VIOLATION then Result := '请检查是否已存在相同数据，或修改后重试'
  else if AErrorCode = ERR_DB_FOREIGN_KEY then Result := '请先处理关联数据后再进行此操作'
  else if AErrorCode = ERR_DB_NOT_NULL_VIOLATION then Result := '请填写所有必填字段后重试'
  else if AErrorCode = ERR_DB_CHECK_VIOLATION then Result := '请检查输入数据是否符合要求'
  else if AErrorCode = ERR_DB_PRIMARY_KEY then Result := '记录ID冲突，请刷新后重试'
  // Data type errors
  else if AErrorCode = ERR_DB_TYPE_MISMATCH then Result := '请检查输入数据的格式是否正确'
  else if AErrorCode = ERR_DB_OVERFLOW then Result := '请输入较小的数值'
  else if AErrorCode = ERR_DB_INVALID_DATE then Result := '请使用正确的日期格式（如 2025-01-01）'
  else if AErrorCode = ERR_DB_STRING_TOO_LONG then Result := '请缩短输入的文本长度'
  // Schema errors
  else if AErrorCode = ERR_DB_SCHEMA_MISMATCH then Result := '请运行数据库升级工具'
  else if AErrorCode = ERR_DB_MIGRATION_FAILED then Result := '请备份数据库后联系技术支持'
  else if AErrorCode = ERR_DB_TABLE_EXISTS then Result := '表已存在，无需重复创建'
  // Default
  else Result := '如问题持续，请联系技术支持 [错误码: ' + AErrorCode + ']';
end;

function AnalyzeException(E: Exception): string;
var
  Msg: string;
begin
  Msg := UpperCase(E.Message);
  
  // SQLite specific patterns
  if ContainsText(Msg, 'UNIQUE CONSTRAINT') or ContainsText(Msg, 'UNIQUE_VIOLATION') or
     ContainsText(Msg, 'DUPLICATE KEY') or ContainsText(Msg, 'already exists') then
    Result := ERR_DB_UNIQUE_VIOLATION
  else if ContainsText(Msg, 'FOREIGN KEY') or ContainsText(Msg, 'REFERENCES') then
    Result := ERR_DB_FOREIGN_KEY
  else if ContainsText(Msg, 'NOT NULL') or ContainsText(Msg, 'NULL_VIOLATION') then
    Result := ERR_DB_NOT_NULL_VIOLATION
  else if ContainsText(Msg, 'CHECK CONSTRAINT') then
    Result := ERR_DB_CHECK_VIOLATION
  else if ContainsText(Msg, 'PRIMARY KEY') then
    Result := ERR_DB_PRIMARY_KEY
  else if ContainsText(Msg, 'no such table') or ContainsText(Msg, 'TABLE_NOT_FOUND') then
    Result := ERR_DB_TABLE_NOT_FOUND
  else if ContainsText(Msg, 'no such column') or ContainsText(Msg, 'COLUMN_NOT_FOUND') then
    Result := ERR_DB_COLUMN_NOT_FOUND
  else if ContainsText(Msg, 'syntax error') or ContainsText(Msg, 'SYNTAX_ERROR') then
    Result := ERR_DB_SYNTAX_ERROR
  else if ContainsText(Msg, 'database is locked') or ContainsText(Msg, 'SQLITE_BUSY') then
    Result := ERR_DB_DATABASE_LOCKED
  else if ContainsText(Msg, 'unable to open') or ContainsText(Msg, 'file not found') or
          ContainsText(Msg, 'database not found') then
    Result := ERR_DB_DATABASE_NOT_FOUND
  else if ContainsText(Msg, 'access denied') or ContainsText(Msg, 'permission denied') then
    Result := ERR_DB_ACCESS_DENIED
  else if ContainsText(Msg, 'timeout') or ContainsText(Msg, 'timed out') then
    Result := ERR_DB_QUERY_TIMEOUT
  else if ContainsText(Msg, 'connection') and (ContainsText(Msg, 'lost') or 
          ContainsText(Msg, 'closed') or ContainsText(Msg, 'terminated')) then
    Result := ERR_DB_CONNECTION_LOST
  else if ContainsText(Msg, 'connect') and ContainsText(Msg, 'fail') then
    Result := ERR_DB_CONNECTION_FAILED
  else if ContainsText(Msg, 'type mismatch') or ContainsText(Msg, 'datatype') then
    Result := ERR_DB_TYPE_MISMATCH
  else if ContainsText(Msg, 'overflow') or ContainsText(Msg, 'out of range') then
    Result := ERR_DB_OVERFLOW
  else
    Result := ERR_DB_UNKNOWN;
end;

// ============================================================================
// EUniBaseDB implementation
// ============================================================================

constructor EUniBaseDB.Create(const AMessage: string);
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

constructor EUniBaseDB.Create(const AErrorCode, AMessage, ASuggestion: string);
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

class function EUniBaseDB.Wrap(E: Exception; const ASQL, AOperation: string): EUniBaseDB;
var
  Code: string;
begin
  Code := AnalyzeException(E);
  Result := EUniBaseDB.Create(Code, GetErrorMessage(Code), GetErrorSuggestion(Code));
  Result.FSQL := ASQL;
  Result.FOperation := AOperation;
  Result.FOriginalError := E.Message;
  
  // Trigger callback if set
  if Assigned(FOnException) then
    FOnException(Result);
    
  // Auto-log if enabled
  if FLogEnabled then
    Result.LogException;
end;

class function EUniBaseDB.FromCode(const AErrorCode: string; const ADetail: string): EUniBaseDB;
var
  Msg: string;
begin
  Msg := GetErrorMessage(AErrorCode);
  if ADetail <> '' then
    Msg := Msg + ': ' + ADetail;
    
  Result := EUniBaseDB.Create(AErrorCode, Msg, GetErrorSuggestion(AErrorCode));
  
  if Assigned(FOnException) then
    FOnException(Result);
    
  if FLogEnabled then
    Result.LogException;
end;

function EUniBaseDB.UserMessage: string;
begin
  // User-friendly message - no SQL or technical details
  if FOperation <> '' then
    Result := Format('%s（%s）', [Message, FOperation])
  else
    Result := Message;
    
  if FSuggestion <> '' then
    Result := Result + #13#10 + FSuggestion;
end;

function EUniBaseDB.DetailedMessage: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('═══════════════════════════════════════════════════');
    SB.AppendLine('UniBase Database Exception');
    SB.AppendLine('═══════════════════════════════════════════════════');
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
    SB.AppendLine('═══════════════════════════════════════════════════');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure EUniBaseDB.LogException;
begin
  // Default implementation - write to debug output
  // In production, this should be connected to the actual logging system
  {$IFDEF DEBUG}
  System.Writeln(DetailedMessage);
  {$ENDIF}
  
  // The actual logging should be done via OnException callback
  // which connects to UniBase.SQLLogger or other logging infrastructure
end;

initialization
  EUniBaseDB.FLogEnabled := True;
  EUniBaseDB.FOnException := nil;
  EUniBaseDB.FSessionIdProvider := nil;

end.
