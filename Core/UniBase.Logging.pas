{ ============================================================================
  UniBase.Logging - Logging Module
  
  Version: 1.0
  Description: Multi-level, multi-target (Database/File) logging.
  Thread Safety: Uses async queue, write operations are non-blocking.
  Performance: 10000 log entries write < 5 seconds.
  ============================================================================ }

unit UniBase.Logging;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// Log storage mode
  /// </summary>
  TLogStorageMode = (lsmDatabase, lsmFile, lsmBoth);

  /// <summary>
  /// Log entry
  /// </summary>
  TLogEntry = record
    Level: TLogLevel;
    Msg: string;
    Source: string;
    Timestamp: TDateTime;
    ThreadId: TThreadID;
    StackTrace: string;
    Extra: string;
  end;

  /// <summary>
  /// Log manager
  /// </summary>
  TUniBaseLogger = class
  private
    // Write thread has its own connection for thread safety
    FWriteConnection: TFDConnection;
    FDBPath: string;
    
    // Cached prepared query for high-frequency WriteToDB (single-threaded write)
    FInsertLogQuery: TFDQuery;
    
    FLogQueue: TThreadList<TLogEntry>;
    FWriteThread: TThread;
    FStopEvent: TEvent;
    FLogEvent: TEvent;
    
    FStorageMode: TLogStorageMode;
    FMinLevel: TLogLevel;
    FLogFileDir: string;
    
    // File-logging settings
    FMaxLogFileSizeBytes: Int64; // rotate when exceeded (default 10 MB)
    FMaxRollFiles: Integer;      // reserved for retention (not enforced yet)
    
    procedure WriteLogThread;
    procedure WriteToDB(const Entry: TLogEntry);
    procedure WriteToFile(const Entry: TLogEntry);
    procedure EnsureWriteConnection;
    procedure EnsureInsertQuery;
    function GetMaxLogFileSizeMB: Integer;
    procedure SetMaxLogFileSizeMB(const Value: Integer);
    function NextRotatedFileName(const BaseFile: string): string;
    function PickLogFileForWrite(const BaseFile: string; NewBytes: Integer): string;
    
  public
    constructor Create(const DBPath: string);
    destructor Destroy; override;
    
    /// <summary>Max log file size in MB (default 10)</summary>
    property MaxLogFileSizeMB: Integer read GetMaxLogFileSizeMB write SetMaxLogFileSizeMB;
    
    /// <summary>
    /// Log message
    /// </summary>
    procedure Log(const Msg: string; Level: TLogLevel = llInfo; const Source: string = ''); overload;
    procedure Log(const Msg: string; const Args: array of const; Level: TLogLevel = llInfo); overload;
    
    /// <summary>
    /// Log exception
    /// </summary>
    procedure LogException(E: Exception; const Msg: string = ''; Level: TLogLevel = llError);
    
    // Shortcut methods
    procedure Debug(const Msg: string; const Source: string = '');
    procedure Info(const Msg: string; const Source: string = '');
    procedure Warn(const Msg: string; const Source: string = '');
    procedure Error(const Msg: string; const Source: string = '');
    procedure Fatal(const Msg: string; const Source: string = '');
    
    /// <summary>Formatted log (LogFmt)</summary>
    procedure DebugFmt(const Fmt: string; const Args: array of const; const Source: string = '');
    procedure InfoFmt(const Fmt: string; const Args: array of const; const Source: string = '');
    procedure WarnFmt(const Fmt: string; const Args: array of const; const Source: string = '');
    procedure ErrorFmt(const Fmt: string; const Args: array of const; const Source: string = '');
    procedure FatalFmt(const Fmt: string; const Args: array of const; const Source: string = '');
    
    /// <summary>Clear old logs</summary>
    procedure ClearOldLogs(DaysToKeep: Integer);
    
    /// <summary>Get log count</summary>
    function GetLogCount(Level: TLogLevel): Int64;
    function GetTotalLogCount: Int64;
    
    /// <summary>Storage mode</summary>
    property StorageMode: TLogStorageMode read FStorageMode write FStorageMode;
    
    /// <summary>Minimum log level</summary>
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
  end;

/// <summary>
/// Global logger singleton.
/// IMPORTANT: For database logging, call SetGlobalLogger first (done by TUniBaseManager).
/// If not initialized, returns a file-only logger to ensure logging never fails.
/// </summary>
function Logger: TUniBaseLogger;

/// <summary>
/// Set the global logger instance (called by TUniBaseManager during initialization).
/// This allows the logger to use the correct database path.
/// </summary>
procedure SetGlobalLogger(ALogger: TUniBaseLogger);

/// <summary>
/// Check if global logger has been initialized by Manager.
/// </summary>
function IsLoggerInitialized: Boolean;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  Winapi.Windows,
  FireDAC.Stan.Def,
  FireDAC.Phys.SQLite,
  FireDAC.DApt;

var
  GLogger: TUniBaseLogger = nil;
  GLoggerLock: TObject = nil;
  GLoggerInitializedByManager: Boolean = False;

function Logger: TUniBaseLogger;
begin
  // 单例模式，按需创建
  // 注意：应由 Manager 调用 SetGlobalLogger 初始化
  // 如果未初始化，创建一个仅支持文件日志的实例（确保日志不会失败）
  if GLogger = nil then
  begin
    TMonitor.Enter(GLoggerLock);
    try
      if GLogger = nil then
      begin
        // 创建临时的文件日志实例
        GLogger := TUniBaseLogger.Create('');
        GLogger.StorageMode := lsmFile;  // 强制文件模式，因为没有 DB
        GLoggerInitializedByManager := False;
        {$IFDEF DEBUG}
        OutputDebugString('UniBase.Logger: Created fallback file-only logger. Call SetGlobalLogger for database logging.');
        {$ENDIF}
      end;
    finally
      TMonitor.Exit(GLoggerLock);
    end;
  end;
  Result := GLogger;
end;

procedure SetGlobalLogger(ALogger: TUniBaseLogger);
begin
  TMonitor.Enter(GLoggerLock);
  try
    // 释放旧的临时 Logger（如果有）
    if Assigned(GLogger) and (GLogger <> ALogger) and (not GLoggerInitializedByManager) then
      FreeAndNil(GLogger);
    
    GLogger := ALogger;
    GLoggerInitializedByManager := True;
  finally
    TMonitor.Exit(GLoggerLock);
  end;
end;

function IsLoggerInitialized: Boolean;
begin
  Result := GLoggerInitializedByManager;
end;

{ TUniBaseLogger }

constructor TUniBaseLogger.Create(const DBPath: string);
begin
  inherited Create;
  FDBPath := DBPath;
  FStorageMode := lsmDatabase; // 默认
  FMinLevel := llDebug;
  FLogFileDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Logs');
  
  // Defaults for file rotation
  FMaxLogFileSizeBytes := 10 * 1024 * 1024; // 10 MB
  FMaxRollFiles := 10; // reserved
  
  FLogQueue := TThreadList<TLogEntry>.Create;
  FStopEvent := TEvent.Create;
  FLogEvent := TEvent.Create;
  
  // 启动写入线程
  FWriteThread := TThread.CreateAnonymousThread(WriteLogThread);
  FWriteThread.FreeOnTerminate := False;
  FWriteThread.Start;
end;

destructor TUniBaseLogger.Destroy;
begin
  // Stop write thread
  FStopEvent.SetEvent;
  FWriteThread.WaitFor;
  FWriteThread.Free;
  
  FStopEvent.Free;
  FLogEvent.Free;
  FLogQueue.Free;
  
  // Free cached query before connection
  FreeAndNil(FInsertLogQuery);
  FreeAndNil(FWriteConnection);
    
  inherited;
end;

procedure TUniBaseLogger.EnsureWriteConnection;
begin
  if (FWriteConnection = nil) and (FDBPath <> '') then
  begin
    try
      FWriteConnection := TFDConnection.Create(nil);
      FWriteConnection.DriverName := 'SQLite';
      FWriteConnection.Params.Database := FDBPath;
      FWriteConnection.Params.Values['LockingMode'] := 'Normal';
      FWriteConnection.Params.Values['Synchronous'] := 'Normal'; // Faster writes
      FWriteConnection.Params.Values['JournalMode'] := 'WAL';
      FWriteConnection.Open;
    except
      // Connection failed, WriteToDB will check Connected and fallback
    end;
  end;
end;

procedure TUniBaseLogger.EnsureInsertQuery;
begin
  if (FInsertLogQuery = nil) and (FWriteConnection <> nil) and FWriteConnection.Connected then
  begin
    FInsertLogQuery := TFDQuery.Create(nil);
    FInsertLogQuery.Connection := FWriteConnection;
    FInsertLogQuery.SQL.Text := 
      'INSERT INTO Logs (LogTime, LogLevel, Source, Message, StackTrace, ThreadId) ' +
      'VALUES (:Time, :Level, :Source, :Msg, :Stack, :TID)';
    FInsertLogQuery.Prepare;  // Compile SQL once
  end;
end;

procedure TUniBaseLogger.WriteLogThread;
var
  List: TList<TLogEntry>;
  Entry: TLogEntry;
  WaitResult: DWORD;
  Events: array[0..1] of THandle;
begin
  Events[0] := FStopEvent.Handle;
  Events[1] := FLogEvent.Handle;
  
  EnsureWriteConnection;
  
  while FStopEvent.WaitFor(0) = wrTimeout do
  begin
    WaitResult := WaitForMultipleObjects(2, @Events, False, INFINITE);
    
    if WaitResult = WAIT_OBJECT_0 then
      Break; // Stop event
      
    // Log event or Timeout (if we used timeout)
    // Reset event BEFORE processing to avoid race condition:
    // If Reset happens AFTER processing, a new log added between
    // queue-empty check and Reset would be lost until next SetEvent
    FLogEvent.ResetEvent;
    
    List := FLogQueue.LockList;
    try
      // Process all queued logs
      while List.Count > 0 do
      begin
        Entry := List[0];
        List.Delete(0);
        
        // Unlock for time-consuming I/O operations
        FLogQueue.UnlockList;
        try
          if (FStorageMode in [lsmDatabase, lsmBoth]) then
            WriteToDB(Entry);
            
          if (FStorageMode in [lsmFile, lsmBoth]) then
            WriteToFile(Entry);
        finally
          List := FLogQueue.LockList;
        end;
      end;
    finally
      FLogQueue.UnlockList;
    end;
  end;
end;

procedure TUniBaseLogger.WriteToDB(const Entry: TLogEntry);
begin
  if (FWriteConnection = nil) or (not FWriteConnection.Connected) then
    Exit;
    
  try
    // Use cached prepared query for better performance
    EnsureInsertQuery;
    
    if FInsertLogQuery = nil then
      Exit;
    
    // ISO8601 format
    FInsertLogQuery.ParamByName('Time').AsString := DateToISO8601(Entry.Timestamp);
    FInsertLogQuery.ParamByName('Level').AsString := LogLevelToStr(Entry.Level);
    FInsertLogQuery.ParamByName('Source').AsString := Entry.Source;
    FInsertLogQuery.ParamByName('Msg').AsString := Entry.Msg;
    FInsertLogQuery.ParamByName('Stack').AsString := Entry.StackTrace;
    FInsertLogQuery.ParamByName('TID').AsInteger := Entry.ThreadId;
    
    FInsertLogQuery.ExecSQL;
  except
    // DB write failed, fallback to file mode
    if FStorageMode = lsmDatabase then
      WriteToFile(Entry);
  end;
end;

procedure TUniBaseLogger.WriteToFile(const Entry: TLogEntry);
var
  BaseFile, TargetFile: string;
  Line: string;
  Builder: TStringBuilder;
  NewBytes: Integer;
begin
  try
    if not DirectoryExists(FLogFileDir) then
      ForceDirectories(FLogFileDir);
      
    BaseFile := TPath.Combine(FLogFileDir, Format('Log_%s.txt', [FormatDateTime('yyyy-MM-dd', Entry.Timestamp)]));
    
    Builder := TStringBuilder.Create;
    try
      Builder.AppendFormat('[%s] [%s] [%d]', [
        FormatDateTime('HH:mm:ss.zzz', Entry.Timestamp),
        LogLevelToStr(Entry.Level),
        Entry.ThreadId
      ]);
      
      if Entry.Source <> '' then
        Builder.AppendFormat(' [%s]', [Entry.Source]);
        
      Builder.Append(' ');
      Builder.Append(Entry.Msg);
      
      if Entry.StackTrace <> '' then
      begin
        Builder.AppendLine;
        Builder.Append('  StackTrace: ');
        Builder.Append(Entry.StackTrace);
      end;
      
      Line := Builder.ToString;
    finally
      Builder.Free;
    end;
    
    NewBytes := TEncoding.UTF8.GetByteCount(Line + sLineBreak);
    TargetFile := PickLogFileForWrite(BaseFile, NewBytes);
      
    TFile.AppendAllText(TargetFile, Line + sLineBreak, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      // 文件写入失败时输出到调试器（避免递归日志）
      {$IFDEF DEBUG}
      OutputDebugString(PChar('UniBase.Logger WriteToFile failed: ' + E.Message));
      {$ENDIF}
    end;
  end;
end;

function TUniBaseLogger.GetMaxLogFileSizeMB: Integer;
begin
  Result := Round(FMaxLogFileSizeBytes / 1024.0 / 1024.0);
end;

procedure TUniBaseLogger.SetMaxLogFileSizeMB(const Value: Integer);
begin
  if Value <= 0 then
    FMaxLogFileSizeBytes := 10 * 1024 * 1024
  else
    FMaxLogFileSizeBytes := Int64(Value) * 1024 * 1024;
end;

function TUniBaseLogger.NextRotatedFileName(const BaseFile: string): string;
var
  idx: Integer;
  Candidate: string;
begin
  idx := 1;
  while True do
  begin
    Candidate := ChangeFileExt(BaseFile, Format('.%d%s', [idx, ExtractFileExt(BaseFile)]));
    if not TFile.Exists(Candidate) then
      Exit(Candidate);
    Inc(idx);
  end;
end;

function TUniBaseLogger.PickLogFileForWrite(const BaseFile: string; NewBytes: Integer): string;
var
  Candidate: string;
  idx: Integer;
  Size: Int64;
begin
  // If base file fits, use it
  if TFile.Exists(BaseFile) then
  begin
    Size := TFile.GetSize(BaseFile);
    if Size + NewBytes <= FMaxLogFileSizeBytes then
      Exit(BaseFile);
  end
  else
    Exit(BaseFile); // base doesn't exist yet
  
  // Try existing rotated files to append if space remains
  idx := 1;
  while True do
  begin
    Candidate := ChangeFileExt(BaseFile, Format('.%d%s', [idx, ExtractFileExt(BaseFile)]));
    if not TFile.Exists(Candidate) then
      Exit(Candidate); // first missing rotated file
    Size := TFile.GetSize(Candidate);
    if Size + NewBytes <= FMaxLogFileSizeBytes then
      Exit(Candidate);
    Inc(idx);
  end;
end;

procedure TUniBaseLogger.Log(const Msg: string; Level: TLogLevel; const Source: string);
var
  Entry: TLogEntry;
  List: TList<TLogEntry>;
begin
  if Level < FMinLevel then Exit;
  
  Entry.Level := Level;
  Entry.Msg := Msg;
  Entry.Source := Source;
  Entry.Timestamp := Now;
  Entry.ThreadId := TThread.CurrentThread.ThreadID;
  Entry.StackTrace := '';
  Entry.Extra := '';
  
  List := FLogQueue.LockList;
  try
    List.Add(Entry);
  finally
    FLogQueue.UnlockList;
  end;
  
  FLogEvent.SetEvent;
end;

procedure TUniBaseLogger.Log(const Msg: string; const Args: array of const; Level: TLogLevel);
begin
  Log(Format(Msg, Args), Level);
end;

procedure TUniBaseLogger.LogException(E: Exception; const Msg: string; Level: TLogLevel);
var
  Entry: TLogEntry;
  List: TList<TLogEntry>;
  FinalMsg: string;
begin
  if Level < FMinLevel then Exit;
  
  Entry.Level := Level;
  
  // 构建完整消息
  if Msg <> '' then
    FinalMsg := Msg + ' - [' + E.ClassName + '] ' + E.Message
  else
    FinalMsg := '[' + E.ClassName + '] ' + E.Message;
  Entry.Msg := FinalMsg;
    
  Entry.Source := 'Exception';
  Entry.Timestamp := Now;
  Entry.ThreadId := TThread.CurrentThread.ThreadID;
  Entry.StackTrace := E.StackTrace; // 获取堆栈（如果可用）
  Entry.Extra := '';
  
  List := FLogQueue.LockList;
  try
    List.Add(Entry);
  finally
    FLogQueue.UnlockList;
  end;
  
  FLogEvent.SetEvent;
end;

procedure TUniBaseLogger.Debug(const Msg, Source: string);
begin
  Log(Msg, llDebug, Source);
end;

procedure TUniBaseLogger.Info(const Msg, Source: string);
begin
  Log(Msg, llInfo, Source);
end;

procedure TUniBaseLogger.Warn(const Msg, Source: string);
begin
  Log(Msg, llWarn, Source);
end;

procedure TUniBaseLogger.Error(const Msg, Source: string);
begin
  Log(Msg, llError, Source);
end;

procedure TUniBaseLogger.Fatal(const Msg, Source: string);
begin
  Log(Msg, llFatal, Source);
end;

procedure TUniBaseLogger.DebugFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llDebug, Source);
end;

procedure TUniBaseLogger.InfoFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llInfo, Source);
end;

procedure TUniBaseLogger.WarnFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llWarn, Source);
end;

procedure TUniBaseLogger.ErrorFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llError, Source);
end;

procedure TUniBaseLogger.FatalFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llFatal, Source);
end;

procedure TUniBaseLogger.ClearOldLogs(DaysToKeep: Integer);
var
  Query: TFDQuery;
  CutoffDate: string;
  LogFiles: TArray<string>;
  LogFile: string;
  FileDate: TDateTime;
  FileName: string;
begin
  // 清理数据库日志
  if (FWriteConnection <> nil) and FWriteConnection.Connected then
  begin
    CutoffDate := DateToISO8601(IncDay(Now, -DaysToKeep));
    
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FWriteConnection;
        Query.SQL.Text := 'DELETE FROM Logs WHERE LogTime < :Time';
        Query.ParamByName('Time').AsString := CutoffDate;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    except
      // ignore
    end;
  end;
  
  // 清理旧日志文件
  if DirectoryExists(FLogFileDir) then
  begin
    try
      LogFiles := TDirectory.GetFiles(FLogFileDir, 'Log_*.txt');
      for LogFile in LogFiles do
      begin
        FileName := ExtractFileName(LogFile);
        // 解析日期: Log_yyyy-MM-dd.txt
        if Length(FileName) >= 14 then
        begin
          try
            FileDate := EncodeDate(
              StrToInt(Copy(FileName, 5, 4)),
              StrToInt(Copy(FileName, 10, 2)),
              StrToInt(Copy(FileName, 13, 2))
            );
            if FileDate < IncDay(Now, -DaysToKeep) then
              TFile.Delete(LogFile);
          except
            // 跳过解析失败的文件
          end;
        end;
      end;
    except
      // ignore
    end;
  end;
end;

function TUniBaseLogger.GetLogCount(Level: TLogLevel): Int64;
var
  Query: TFDQuery;
begin
  Result := 0;
  if (FWriteConnection = nil) or (not FWriteConnection.Connected) then
    Exit;
    
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FWriteConnection;
      Query.SQL.Text := 'SELECT COUNT(*) FROM Logs WHERE Level = :Level';
      Query.ParamByName('Level').AsInteger := Ord(Level);
      Query.Open;
      Result := Query.Fields[0].AsLargeInt;
    finally
      Query.Free;
    end;
  except
    // ignore
  end;
end;

function TUniBaseLogger.GetTotalLogCount: Int64;
var
  Query: TFDQuery;
begin
  Result := 0;
  if (FWriteConnection = nil) or (not FWriteConnection.Connected) then
    Exit;
    
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FWriteConnection;
      Query.SQL.Text := 'SELECT COUNT(*) FROM Logs';
      Query.Open;
      Result := Query.Fields[0].AsLargeInt;
    finally
      Query.Free;
    end;
  except
    // ignore
  end;
end;

initialization
  GLoggerLock := TObject.Create;

finalization
  if GLogger <> nil then
    FreeAndNil(GLogger);
  FreeAndNil(GLoggerLock);

end.
