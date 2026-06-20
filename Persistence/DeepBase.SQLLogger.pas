{ ============================================================================
  DeepBase.SQLLogger - SQL Execution Logging
  
  Version: 1.0.0
  Description: Provides SQL execution logging with timing, slow query alerts,
               and optional persistence to database or file.
  
  Features:
    - Log SQL execution time and results
    - Slow query detection and alerts
    - Configurable log levels and destinations
    - Session-based log correlation
    - Memory-efficient circular buffer
    - Thread-safe operations
  
  Usage:
    // Enable logging
    TSQLLogger.Enabled := True;
    TSQLLogger.SlowQueryThresholdMs := 500;
    
    // Log a query
    var StartTime := TSQLLogger.StartTiming;
    Query.Open;
    TSQLLogger.LogSQL(Query.SQL.Text, StartTime, True);
    
    // Or use the auto-timing wrapper
    TSQLLogger.Execute(Query, 
      procedure begin Query.Open; end,
      'Loading user list');
  ============================================================================ }

unit DeepBase.SQLLogger;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  System.StrUtils;

type
  TSQLLogLevel = (sllDebug, sllInfo, sllWarn, sllError);
  
  TSQLLogEntry = record
    Id: Int64;
    Timestamp: TDateTime;
    SessionId: string;
    SQL: string;
    Operation: string;
    DurationMs: Integer;
    Success: Boolean;
    ErrorMessage: string;
    LogLevel: TSQLLogLevel;
    RowsAffected: Integer;
  end;
  
  TSQLLogEntries = TArray<TSQLLogEntry>;
  
  TLogDestination = (ldMemory, ldFile, ldDatabase, ldCallback);
  TLogDestinations = set of TLogDestination;
  
  /// <summary>
  /// SQL execution logger with timing and slow query detection
  /// </summary>
  TSQLLogger = class
  private
    class var FEnabled: Boolean;
    class var FSlowQueryThresholdMs: Integer;
    class var FLogLevel: TSQLLogLevel;
    class var FDestinations: TLogDestinations;
    class var FLogFilePath: string;
    class var FMaxMemoryEntries: Integer;
    class var FMemoryLog: TList<TSQLLogEntry>;
    class var FLock: TCriticalSection;
    class var FNextId: Int64;
    class var FSessionId: string;
    class var FOnLog: TProc<TSQLLogEntry>;
    class var FOnSlowQuery: TProc<TSQLLogEntry>;
    class var FDBConnection: TObject;
    class var FTotalQueries: Int64;
    class var FTotalDurationMs: Int64;
    class var FSlowQueryCount: Int64;
    class var FErrorCount: Int64;
    
    class procedure Initialize;
    class procedure Finalize;
    class procedure WriteToFile(const AEntry: TSQLLogEntry);
    class procedure WriteToDatabase(const AEntry: TSQLLogEntry);
    class procedure TrimMemoryLog;
    class function FormatLogEntry(const AEntry: TSQLLogEntry): string;
  public
    /// <summary>
    /// Format a dictionary of key-value pairs as a JSON string using TJSONObject.
    /// Prevents JSON injection by proper escaping of all values.
    /// </summary>
    class function FormatExtra(const AExtra: TDictionary<string, string>): string;

    /// <summary>
    /// Start timing for a SQL execution
    /// </summary>
    class function StartTiming: TDateTime;
    
    /// <summary>
    /// Calculate duration from start time
    /// </summary>
    class function GetDurationMs(AStartTime: TDateTime): Integer;
    
    /// <summary>
    /// Log a SQL execution
    /// </summary>
    class procedure LogSQL(const ASQL: string; AStartTime: TDateTime; 
      ASuccess: Boolean; const AOperation: string = ''; 
      const AErrorMessage: string = ''; ARowsAffected: Integer = -1);
      
    /// <summary>
    /// Log a SQL execution with explicit duration
    /// </summary>
    class procedure LogSQLEx(const ASQL: string; ADurationMs: Integer;
      ASuccess: Boolean; const AOperation: string = '';
      const AErrorMessage: string = ''; ARowsAffected: Integer = -1);
    
    /// <summary>
    /// Execute a query with automatic logging
    /// </summary>
    class procedure Execute(AQuery: TObject; AProc: TProc;
      const AOperation: string = '');
    
    /// <summary>
    /// Execute a custom database operation with logging
    /// </summary>
    class procedure ExecuteCustom(const ASQL, AOperation: string; AProc: TProc);
    
    /// <summary>
    /// Get recent log entries from memory
    /// </summary>
    class function GetRecentLogs(ACount: Integer = 100): TSQLLogEntries;
    
    /// <summary>
    /// Get slow queries from memory
    /// </summary>
    class function GetSlowQueries(ACount: Integer = 50): TSQLLogEntries;
    
    /// <summary>
    /// Get failed queries from memory
    /// </summary>
    class function GetFailedQueries(ACount: Integer = 50): TSQLLogEntries;
    
    /// <summary>
    /// Clear memory log
    /// </summary>
    class procedure ClearMemoryLog;
    
    /// <summary>
    /// Generate statistics report
    /// </summary>
    class function GetStatistics: string;
    
    /// <summary>
    /// Reset statistics counters
    /// </summary>
    class procedure ResetStatistics;
    
    /// <summary>
    /// Export logs to file
    /// </summary>
    class procedure ExportToFile(const AFilePath: string; 
      AEntries: TSQLLogEntries);
    
    /// <summary>
    /// Set database connection for database logging
    /// </summary>
    class procedure SetDBConnection(AConnection: TObject);
    
    /// <summary>
    /// Generate new session ID
    /// </summary>
    class procedure NewSession;
    
    // Properties
    class property Enabled: Boolean read FEnabled write FEnabled;
    class property SlowQueryThresholdMs: Integer read FSlowQueryThresholdMs write FSlowQueryThresholdMs;
    class property LogLevel: TSQLLogLevel read FLogLevel write FLogLevel;
    class property Destinations: TLogDestinations read FDestinations write FDestinations;
    class property LogFilePath: string read FLogFilePath write FLogFilePath;
    class property MaxMemoryEntries: Integer read FMaxMemoryEntries write FMaxMemoryEntries;
    class property SessionId: string read FSessionId;
    class property OnLog: TProc<TSQLLogEntry> read FOnLog write FOnLog;
    class property OnSlowQuery: TProc<TSQLLogEntry> read FOnSlowQuery write FOnSlowQuery;
    
    // Statistics (read-only)
    class property TotalQueries: Int64 read FTotalQueries;
    class property TotalDurationMs: Int64 read FTotalDurationMs;
    class property SlowQueryCount: Int64 read FSlowQueryCount;
    class property ErrorCount: Int64 read FErrorCount;
  end;

implementation

uses
  System.DateUtils, System.IOUtils, System.JSON,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FireDAC.Comp.Client;

{ TSQLLogger }

class procedure TSQLLogger.Initialize;
var
  GUID: TGUID;
begin
  FEnabled := False;  // Disabled by default
  FSlowQueryThresholdMs := 500;  // 500ms threshold
  FLogLevel := sllInfo;
  FDestinations := [ldMemory];
  FLogFilePath := '';
  FMaxMemoryEntries := 1000;
  FMemoryLog := TList<TSQLLogEntry>.Create;
  FLock := TCriticalSection.Create;
  FNextId := 1;
  FTotalQueries := 0;
  FTotalDurationMs := 0;
  FSlowQueryCount := 0;
  FErrorCount := 0;
  FDBConnection := nil;
  FOnLog := nil;
  FOnSlowQuery := nil;
  
  // Generate initial session ID
  CreateGUID(GUID);
  FSessionId := Copy(GUIDToString(GUID), 2, 8);  // Short session ID
end;

class procedure TSQLLogger.Finalize;
begin
  FreeAndNil(FMemoryLog);
  FreeAndNil(FLock);
end;

class procedure TSQLLogger.NewSession;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  FSessionId := Copy(GUIDToString(GUID), 2, 8);
end;

class function TSQLLogger.StartTiming: TDateTime;
begin
  Result := Now;
end;

class function TSQLLogger.GetDurationMs(AStartTime: TDateTime): Integer;
begin
  Result := MilliSecondsBetween(Now, AStartTime);
end;

class procedure TSQLLogger.LogSQL(const ASQL: string; AStartTime: TDateTime;
  ASuccess: Boolean; const AOperation: string; const AErrorMessage: string;
  ARowsAffected: Integer);
begin
  LogSQLEx(ASQL, GetDurationMs(AStartTime), ASuccess, AOperation, 
    AErrorMessage, ARowsAffected);
end;

class procedure TSQLLogger.LogSQLEx(const ASQL: string; ADurationMs: Integer;
  ASuccess: Boolean; const AOperation: string; const AErrorMessage: string;
  ARowsAffected: Integer);
var
  Entry: TSQLLogEntry;
  DoFile, DoDatabase, DoCallback, DoSlowAlert: Boolean;
begin
  if not FEnabled then Exit;
  

  FLock.Enter;
  try
    // Create log entry
    Entry.Id := FNextId;
    Inc(FNextId);
    Entry.Timestamp := Now;
    Entry.SessionId := FSessionId;
    Entry.SQL := ASQL;
    Entry.Operation := AOperation;
    Entry.DurationMs := ADurationMs;
    Entry.Success := ASuccess;
    Entry.ErrorMessage := AErrorMessage;
    Entry.RowsAffected := ARowsAffected;
    
    // Determine log level
    if not ASuccess then
      Entry.LogLevel := sllError
    else if ADurationMs >= FSlowQueryThresholdMs then
      Entry.LogLevel := sllWarn
    else
      Entry.LogLevel := sllInfo;
    
    // Skip if below log level threshold
    if Entry.LogLevel < FLogLevel then Exit;
    
    // Update statistics
    Inc(FTotalQueries);
    Inc(FTotalDurationMs, ADurationMs);
    if ADurationMs >= FSlowQueryThresholdMs then
      Inc(FSlowQueryCount);
    if not ASuccess then
      Inc(FErrorCount);
    
    // Memory log (fast, stays under lock)
    if ldMemory in FDestinations then
    begin
      FMemoryLog.Add(Entry);
      TrimMemoryLog;
    end;
    
    // Determine which I/O destinations to write (outside lock)
    DoFile := ldFile in FDestinations;
    DoDatabase := (ldDatabase in FDestinations) and Assigned(FDBConnection);
    DoCallback := (ldCallback in FDestinations) and Assigned(FOnLog);
    DoSlowAlert := (ADurationMs >= FSlowQueryThresholdMs) and Assigned(FOnSlowQuery);
  finally
    FLock.Leave;
  end;

  // Perform I/O outside the lock (producer-consumer pattern)
  if DoFile then
    WriteToFile(Entry);
  if DoDatabase then
    WriteToDatabase(Entry);
  if DoCallback then
    FOnLog(Entry);
  if DoSlowAlert then
    FOnSlowQuery(Entry);
end;

class procedure TSQLLogger.Execute(AQuery: TObject; AProc: TProc;
  const AOperation: string);
var
  FDQuery: TFDQuery;
  StartTime: TDateTime;
  SQL: string;
  Success: Boolean;
  ErrorMsg: string;
  RowsAffected: Integer;
begin
  if Assigned(AQuery) and (AQuery is TFDQuery) then
    FDQuery := TFDQuery(AQuery)
  else
    FDQuery := nil;

  if not FEnabled then
  begin
    AProc;
    Exit;
  end;
  
  StartTime := StartTiming;
  if Assigned(FDQuery) then
    SQL := FDQuery.SQL.Text
  else
    SQL := '';
  Success := True;
  ErrorMsg := '';
  RowsAffected := -1;
  
  try
    AProc;
    if Assigned(FDQuery) then
    begin
      if FDQuery.Active then
        RowsAffected := FDQuery.RecordCount
      else
        RowsAffected := FDQuery.RowsAffected;
    end;
  except
    on E: Exception do
    begin
      Success := False;
      ErrorMsg := E.Message;
      LogSQL(SQL, StartTime, Success, AOperation, ErrorMsg, RowsAffected);
      raise;
    end;
  end;
  
  LogSQL(SQL, StartTime, Success, AOperation, ErrorMsg, RowsAffected);
end;

class procedure TSQLLogger.ExecuteCustom(const ASQL, AOperation: string; 
  AProc: TProc);
var
  StartTime: TDateTime;
  Success: Boolean;
  ErrorMsg: string;
begin
  if not FEnabled then
  begin
    AProc;
    Exit;
  end;
  
  StartTime := StartTiming;
  Success := True;
  ErrorMsg := '';
  
  try
    AProc;
  except
    on E: Exception do
    begin
      Success := False;
      ErrorMsg := E.Message;
      LogSQL(ASQL, StartTime, Success, AOperation, ErrorMsg, -1);
      raise;
    end;
  end;
  
  LogSQL(ASQL, StartTime, Success, AOperation, ErrorMsg, -1);
end;

class procedure TSQLLogger.TrimMemoryLog;
begin
  while FMemoryLog.Count > FMaxMemoryEntries do
    FMemoryLog.Delete(0);
end;

class function TSQLLogger.FormatLogEntry(const AEntry: TSQLLogEntry): string;
const
  LevelNames: array[TSQLLogLevel] of string = ('DEBUG', 'INFO', 'WARN', 'ERROR');
var
  StatusStr: string;
begin
  if AEntry.Success then
    StatusStr := 'OK'
  else
    StatusStr := 'FAIL';
    
  Result := Format('%s [%s] [%s] %dms %s | %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
     AEntry.SessionId,
     LevelNames[AEntry.LogLevel],
     AEntry.DurationMs,
     StatusStr,
     Copy(AEntry.SQL, 1, 200)]);  // Truncate long SQL
     
  if AEntry.Operation <> '' then
    Result := Result + ' | Op: ' + AEntry.Operation;
    
  if not AEntry.Success then
    Result := Result + ' | Error: ' + AEntry.ErrorMessage;
end;

class function TSQLLogger.FormatExtra(const AExtra: TDictionary<string, string>): string;
begin
  var LObj := TJSONObject.Create;
  try
    for var LPair in AExtra do
      LObj.AddPair(LPair.Key, LPair.Value);
    Result := LObj.ToJSON;
  finally
    LObj.Free;
  end;
end;

class procedure TSQLLogger.WriteToFile(const AEntry: TSQLLogEntry);
var
  LogLine: string;
  LogFile: TextFile;
begin
  if FLogFilePath = '' then Exit;
  
  LogLine := FormatLogEntry(AEntry);
  
  try
    AssignFile(LogFile, FLogFilePath);
    if FileExists(FLogFilePath) then
      Append(LogFile)
    else
      Rewrite(LogFile);
    try
      WriteLn(LogFile, LogLine);
    finally
      CloseFile(LogFile);
    end;
  except
    // Ignore file write errors
  end;
end;

class procedure TSQLLogger.WriteToDatabase(const AEntry: TSQLLogEntry);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  if Assigned(FDBConnection) and (FDBConnection is TFDConnection) then
    Conn := TFDConnection(FDBConnection)
  else
    Conn := nil;

  if not Assigned(Conn) then Exit;
  if not Conn.Connected then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := Conn;
      Query.SQL.Text := 
        'INSERT INTO Logs (LogLevel, Source, Message, LogTime, SessionId, MachineName, Extra) ' +
        'VALUES (:LogLevel, :Source, :Message, :LogTime, :SessionId, :MachineName, :Extra)';
      
      case AEntry.LogLevel of
        sllDebug: Query.ParamByName('LogLevel').AsString := 'DEBUG';
        sllInfo:  Query.ParamByName('LogLevel').AsString := 'INFO';
        sllWarn:  Query.ParamByName('LogLevel').AsString := 'WARN';
        sllError: Query.ParamByName('LogLevel').AsString := 'ERROR';
      end;
      
      Query.ParamByName('Source').AsString := 'SQL';
      Query.ParamByName('Message').AsString := Copy(AEntry.SQL, 1, 500);
      Query.ParamByName('LogTime').AsDateTime := AEntry.Timestamp;
      Query.ParamByName('SessionId').AsString := AEntry.SessionId;
      Query.ParamByName('MachineName').AsString := '';
      
      // Store extra info as JSON using FormatExtra
      var LExtraDict := TDictionary<string, string>.Create;
      try
        LExtraDict.Add('duration_ms', IntToStr(AEntry.DurationMs));
        LExtraDict.Add('success', AEntry.Success.ToString(TUseBoolStrs.True));
        LExtraDict.Add('operation', AEntry.Operation);
        LExtraDict.Add('rows_affected', IntToStr(AEntry.RowsAffected));
        LExtraDict.Add('error', AEntry.ErrorMessage);
        Query.ParamByName('Extra').AsString := FormatExtra(LExtraDict);
      finally
        LExtraDict.Free;
      end;
      
      Query.ExecSQL;
    except
      on E: Exception do
      begin
        {$IFDEF MSWINDOWS}
        OutputDebugString(PChar('DeepBase.SQLLogger database write failed: ' + E.Message));
        {$ENDIF}
      end;
    end;
  finally
    Query.Free;
  end;
end;

class function TSQLLogger.GetRecentLogs(ACount: Integer): TSQLLogEntries;
var
  StartIdx, I: Integer;
begin
  FLock.Enter;
  try
    if ACount >= FMemoryLog.Count then
      StartIdx := 0
    else
      StartIdx := FMemoryLog.Count - ACount;
    
    SetLength(Result, FMemoryLog.Count - StartIdx);
    for I := StartIdx to FMemoryLog.Count - 1 do
      Result[I - StartIdx] := FMemoryLog[I];
  finally
    FLock.Leave;
  end;
end;

class function TSQLLogger.GetSlowQueries(ACount: Integer): TSQLLogEntries;
var
  I: Integer;
  TempList: TList<TSQLLogEntry>;
begin
  TempList := TList<TSQLLogEntry>.Create;
  try
    FLock.Enter;
    try
      // Iterate from newest to oldest
      for I := FMemoryLog.Count - 1 downto 0 do
      begin
        if FMemoryLog[I].DurationMs >= FSlowQueryThresholdMs then
        begin
          TempList.Add(FMemoryLog[I]);
          if TempList.Count >= ACount then
            Break;
        end;
      end;
    finally
      FLock.Leave;
    end;
    
    Result := TempList.ToArray;
  finally
    TempList.Free;
  end;
end;

class function TSQLLogger.GetFailedQueries(ACount: Integer): TSQLLogEntries;
var
  I: Integer;
  TempList: TList<TSQLLogEntry>;
begin
  TempList := TList<TSQLLogEntry>.Create;
  try
    FLock.Enter;
    try
      for I := FMemoryLog.Count - 1 downto 0 do
      begin
        if not FMemoryLog[I].Success then
        begin
          TempList.Add(FMemoryLog[I]);
          if TempList.Count >= ACount then
            Break;
        end;
      end;
    finally
      FLock.Leave;
    end;
    
    Result := TempList.ToArray;
  finally
    TempList.Free;
  end;
end;

class procedure TSQLLogger.ClearMemoryLog;
begin
  FLock.Enter;
  try
    FMemoryLog.Clear;
  finally
    FLock.Leave;
  end;
end;

class function TSQLLogger.GetStatistics: string;
var
  AvgDuration: Double;
begin
  if FTotalQueries > 0 then
    AvgDuration := FTotalDurationMs / FTotalQueries
  else
    AvgDuration := 0;

  Result := Format(
    'SQL Logger Statistics' + sLineBreak +
    '----------------------------------------' + sLineBreak +
    'Session ID: %s' + sLineBreak +
    'Total Queries: %d' + sLineBreak +
    'Total Duration: %d ms' + sLineBreak +
    'Average Duration: %.2f ms' + sLineBreak +
    'Slow Queries (>%dms): %d' + sLineBreak +
    'Failed Queries: %d' + sLineBreak +
    'Memory Log Entries: %d / %d' + sLineBreak +
    '----------------------------------------',
    [FSessionId, FTotalQueries, FTotalDurationMs, AvgDuration,
     FSlowQueryThresholdMs, FSlowQueryCount, FErrorCount,
     FMemoryLog.Count, FMaxMemoryEntries]);
end;
class procedure TSQLLogger.ResetStatistics;
begin
  FLock.Enter;
  try
    FTotalQueries := 0;
    FTotalDurationMs := 0;
    FSlowQueryCount := 0;
    FErrorCount := 0;
  finally
    FLock.Leave;
  end;
end;

class procedure TSQLLogger.ExportToFile(const AFilePath: string;
  AEntries: TSQLLogEntries);
var
  SL: TStringList;
  Entry: TSQLLogEntry;
begin
  SL := TStringList.Create;
  try
    SL.Add('DeepBase SQL Log Export');
    SL.Add('Generated: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    SL.Add('------------------------------------------------------------------');
    SL.Add('');

    for Entry in AEntries do
      SL.Add(FormatLogEntry(Entry));

    SL.SaveToFile(AFilePath, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;
class procedure TSQLLogger.SetDBConnection(AConnection: TObject);
begin
  FDBConnection := AConnection;
end;

initialization
  TSQLLogger.Initialize;

finalization
  TSQLLogger.Finalize;

end.
