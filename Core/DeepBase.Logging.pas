{ ============================================================================
  DeepBase.Logging - Logging Module
  
  Version: 1.1
  Description: Multi-level, multi-target (Database/File) logging.
               Optional log aggregator integration for centralized logging.
  Thread Safety: Uses async queue, write operations are non-blocking.
  Performance: 10000 log entries write < 5 seconds.
  ============================================================================ }

unit DeepBase.Logging;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.Types,
  DeepBase.Constants,
  DeepBase.Storage.Interfaces;

type
  /// <summary>
  /// Log storage mode
  /// </summary>
  TLogStorageMode = (lsmDatabase, lsmFile, lsmBoth);

  /// <summary>
  /// Log output format for file logging
  /// </summary>
  TLogFormat = (
    lfText,   // Traditional text format: [HH:mm:ss.zzz] [LEVEL] [ThreadId] [Source] Message
    lfJson    // JSON structured format: {"timestamp":..., "level":..., "message":..., ...}
  );

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
  TDeepBaseLogger = class
  private
    FStorage: ILogStorage;
    FDBPath: string;

    FLogQueue: TThreadList<TLogEntry>;
    FWriteThread: TThread;
    FStopEvent: TEvent;
    FLogEvent: TEvent;
    
    FStorageMode: TLogStorageMode;
    FMinLevel: TLogLevel;
    FLogFileDir: string;
    FLogFormat: TLogFormat;
    
    // File-logging settings
    FMaxLogFileSizeBytes: Int64; // rotate when exceeded (default 10 MB)
    FMaxRollFiles: Integer;      // reserved for retention (not enforced yet)
    
    // Log aggregator integration
    FAggregatorEnabled: Boolean;
    FAppName: string;
    FAppVersion: string;
    FEnvironment: string;
    FHostname: string;
    class var FStorageFactory: TFunc<string, ILogStorage>;
    
    procedure WriteLogThread;
    procedure WriteToDB(const Entry: TLogEntry);
    procedure WriteToFile(const Entry: TLogEntry);
    procedure WriteToAggregator(const Entry: TLogEntry);
    function EscapeLogContent(const Content: string): string;
    function GetMaxLogFileSizeMB: Integer;
    procedure SetMaxLogFileSizeMB(const Value: Integer);
    function NextRotatedFileName(const BaseFile: string): string;
    function PickLogFileForWrite(const BaseFile: string; NewBytes: Integer): string;
    class function CreateStorage(const ADBPath: string): ILogStorage; static;
    
  public
    constructor Create(const DBPath: string);
    destructor Destroy; override;
    class procedure SetStorageFactory(
      const AFactory: TFunc<string, ILogStorage>); static;
    
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
    function ReadRecentLogs(MinLevel: TLogLevel; MaxItems: Integer): TLogViewDataArray;
    procedure ClearLogs;
    
    /// <summary>Enable/Disable log aggregator integration</summary>
    procedure SetAggregatorEnabled(AEnabled: Boolean);
    
    /// <summary>Configure aggregator metadata</summary>
    procedure ConfigureAggregator(const AAppName, AAppVersion, AEnvironment: string);
    
    /// <summary>Storage mode</summary>
    property StorageMode: TLogStorageMode read FStorageMode write FStorageMode;
    
    /// <summary>Minimum log level</summary>
    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    
    /// <summary>Log format for file output (default: lfText)</summary>
    property LogFormat: TLogFormat read FLogFormat write FLogFormat;
    
    /// <summary>Whether aggregator is enabled</summary>
    property AggregatorEnabled: Boolean read FAggregatorEnabled;
    
    /// <summary>Application name for aggregator</summary>
    property AppName: string read FAppName;
    
    /// <summary>Application version for aggregator</summary>
    property AppVersion: string read FAppVersion;
    
    /// <summary>Environment (dev/staging/prod) for aggregator</summary>
    property Environment: string read FEnvironment;
    
  private
    /// <summary>Sanitize log message to prevent injection attacks</summary>
    function SanitizeLogMessage(const AMessage: string): string;
  end;

/// <summary>
/// Global logger singleton.
/// IMPORTANT: For database logging, call SetGlobalLogger first (done by TDeepBaseManager).
/// If not initialized, returns a file-only logger to ensure logging never fails.
/// </summary>
function Logger: TDeepBaseLogger;

/// <summary>
/// Set the global logger instance (called by TDeepBaseManager during initialization).
/// This allows the logger to use the correct database path.
/// </summary>
procedure SetGlobalLogger(ALogger: TDeepBaseLogger);

/// <summary>
/// Check if global logger has been initialized by Manager.
/// </summary>
function IsLoggerInitialized: Boolean;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.NetEncoding
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

var
  GLogger: TDeepBaseLogger = nil;
  GLoggerLock: TObject = nil;
  GLoggerInitializedByManager: Boolean = False;

function Logger: TDeepBaseLogger;
var
  NewLock: TObject;
begin
  // ����ģʽ�����贴��
  // ע�⣺Ӧ�� Manager ���� SetGlobalLogger ��ʼ��
  // ���δ��ʼ��������һ����֧���ļ���־��ʵ����ȷ����־����ʧ�ܣ�

  // �����Լ�飺��� GLoggerLock ��δ��������Ԫ initialization δִ�У����ȴ�����
  // ʹ��ԭ�Ӳ������⾺̬����
  if GLoggerLock = nil then
  begin
    NewLock := TObject.Create;
    if TInterlocked.CompareExchange(Pointer(GLoggerLock), Pointer(NewLock), nil) <> nil then
      NewLock.Free;  // ��һ���߳��ȴ����ˣ��ͷ����Ǵ�����
  end;

  if GLogger = nil then
  begin
    TMonitor.Enter(GLoggerLock);
    try
      if GLogger = nil then
      begin
        // ������ʱ���ļ���־ʵ��
        GLogger := TDeepBaseLogger.Create('');
        GLogger.StorageMode := lsmFile;  // ǿ���ļ�ģʽ����Ϊû�� DB
        GLoggerInitializedByManager := False;
        {$IFDEF DEBUG}
        OutputDebugString('DeepBase.Logger: Created fallback file-only logger. Call SetGlobalLogger for database logging.');
        {$ENDIF}
      end;
    finally
      TMonitor.Exit(GLoggerLock);
    end;
  end;
  Result := GLogger;
end;

procedure SetGlobalLogger(ALogger: TDeepBaseLogger);
var
  NewLock: TObject;
begin
  // �����Լ�� - ʹ��ԭ�Ӳ������⾺̬����
  if GLoggerLock = nil then
  begin
    NewLock := TObject.Create;
    if TInterlocked.CompareExchange(Pointer(GLoggerLock), Pointer(NewLock), nil) <> nil then
      NewLock.Free;
  end;

  TMonitor.Enter(GLoggerLock);
  try
    // �ͷžɵ���ʱ Logger������У��������ͷ��� Manager ������ʵ��
    if Assigned(GLogger) and (GLogger <> ALogger) and (not GLoggerInitializedByManager) then
      FreeAndNil(GLogger);

    GLogger := ALogger;
    // �������ⲿ��ʽ����ʵ��ʱ�ű��Ϊ Manager ��ʼ��
    GLoggerInitializedByManager := Assigned(ALogger);
  finally
    TMonitor.Exit(GLoggerLock);
  end;
end;

function IsLoggerInitialized: Boolean;
begin
  Result := GLoggerInitializedByManager;
end;

{ TDeepBaseLogger }

class procedure TDeepBaseLogger.SetStorageFactory(
  const AFactory: TFunc<string, ILogStorage>);
begin
  FStorageFactory := AFactory;
end;

class function TDeepBaseLogger.CreateStorage(
  const ADBPath: string): ILogStorage;
begin
  Result := nil;
  if (ADBPath = '') or (not Assigned(FStorageFactory)) then
    Exit;

  try
    Result := FStorageFactory(ADBPath);
  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      OutputDebugString(PChar('DeepBase.Logger.CreateStorage failed: ' +
        E.Message));
      {$ENDIF}
    end;
  end;
end;

constructor TDeepBaseLogger.Create(const DBPath: string);
begin
  inherited Create;
  FDBPath := DBPath;
  FStorage := CreateStorage(DBPath);
  FStorageMode := lsmDatabase; // Ĭ��
  FMinLevel := llDebug;
  FLogFileDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Logs');
  
  // Defaults for file rotation
  FMaxLogFileSizeBytes := DEFAULT_LOG_MAX_FILE_SIZE;
  FMaxRollFiles := DEFAULT_LOG_MAX_FILES;
  FLogFormat := lfText; // Default text format
  
  // Aggregator defaults
  FAggregatorEnabled := False;
  FAppName := ExtractFileName(ParamStr(0));
  FAppVersion := '1.0.0';
  FEnvironment := 'development';
  FHostname := GetEnvironmentVariable('COMPUTERNAME');
  
  FLogQueue := TThreadList<TLogEntry>.Create;
  FStopEvent := TEvent.Create;
  FLogEvent := TEvent.Create;
  
  // ����д���߳�
  FWriteThread := TThread.CreateAnonymousThread(WriteLogThread);
  FWriteThread.FreeOnTerminate := False;
  FWriteThread.Start;
end;

destructor TDeepBaseLogger.Destroy;
begin
  // Stop write thread
  FStopEvent.SetEvent;
  FWriteThread.WaitFor;
  FreeAndNil(FWriteThread);
  
  FreeAndNil(FStopEvent);
  FreeAndNil(FLogEvent);
  FreeAndNil(FLogQueue);
    
  inherited;
end;

procedure TDeepBaseLogger.WriteLogThread;
var
  List: TList<TLogEntry>;
  LocalBatch: TArray<TLogEntry>;
  Entry: TLogEntry;
  I, BatchCount, RemainingCount: Integer;
  WaitResult: DWORD;
  Events: array[0..1] of THandle;
const
  MAX_BATCH_SIZE = 100;  // Process up to 100 entries per batch
begin
  Events[0] := FStopEvent.Handle;
  Events[1] := FLogEvent.Handle;
  
  while FStopEvent.WaitFor(0) = wrTimeout do
  begin
    WaitResult := WaitForMultipleObjects(2, @Events, False, INFINITE);
    
    if WaitResult = WAIT_OBJECT_0 then
      Break; // Stop event
      
    // Reset event BEFORE processing to avoid race condition
    FLogEvent.ResetEvent;
    
    // R-003: �������������������ȡ��ʣ�����
    RemainingCount := 0;
    SetLength(LocalBatch, 0);
    List := FLogQueue.LockList;
    try
      BatchCount := List.Count;
      if BatchCount > MAX_BATCH_SIZE then
        BatchCount := MAX_BATCH_SIZE;
        
      if BatchCount > 0 then
      begin
        // Copy entries to local array
        SetLength(LocalBatch, BatchCount);
        for I := 0 to BatchCount - 1 do
          LocalBatch[I] := List[I];
          
        // Remove processed entries from queue
        List.DeleteRange(0, BatchCount);
        
        // ����ʣ����Ŀ������ͬһ�������У�
        RemainingCount := List.Count;
      end;
    finally
      FLogQueue.UnlockList;
    end;
    
    // Process batch outside of lock (no lock contention during I/O)
    for I := 0 to High(LocalBatch) do
    begin
      Entry := LocalBatch[I];
      
      if (FStorageMode in [lsmDatabase, lsmBoth]) then
        WriteToDB(Entry);
        
      if (FStorageMode in [lsmFile, lsmBoth]) then
        WriteToFile(Entry);
      
      // Push to aggregator if enabled
      if FAggregatorEnabled then
        WriteToAggregator(Entry);
    end;
    
    // If there are more entries in queue, signal ourselves to continue
    // ע�⣺ʹ����ǰ��¼�� RemainingCount�������ٴμ���
    if RemainingCount > 0 then
      FLogEvent.SetEvent;
  end;
end;

procedure TDeepBaseLogger.WriteToDB(const Entry: TLogEntry);
var
  Data: TLogStorageData;
begin
  if not Assigned(FStorage) then
  begin
    if FStorageMode = lsmDatabase then
      WriteToFile(Entry);
    Exit;
  end;
    
  try
    Data.TimestampISO := DateToISO8601(Entry.Timestamp);
    Data.LevelText := LogLevelToStr(Entry.Level);
    Data.Source := Entry.Source;
    Data.MessageText := Entry.Msg;
    Data.StackTrace := Entry.StackTrace;
    Data.ThreadId := Entry.ThreadId;
    Data.Extra := Entry.Extra;
    FStorage.WriteLog(Data);
  except
    // DB write failed, fallback to file mode
    if FStorageMode = lsmDatabase then
      WriteToFile(Entry);
  end;
end;

procedure TDeepBaseLogger.WriteToFile(const Entry: TLogEntry);
var
  BaseFile, TargetFile: string;
  Line: string;
  Builder: TStringBuilder;
  JsonObj: TJSONObject;
  NewBytes: Integer;
  FileExt: string;
begin
  try
    if not DirectoryExists(FLogFileDir) then
      ForceDirectories(FLogFileDir);
    
    // Determine file extension based on format
    if FLogFormat = lfJson then
      FileExt := '.jsonl'  // JSON Lines format
    else
      FileExt := '.txt';
      
    BaseFile := TPath.Combine(FLogFileDir, Format('Log_%s%s', [
      FormatDateTime('yyyy-MM-dd', Entry.Timestamp), FileExt]));
    
    if FLogFormat = lfJson then
    begin
      // JSON structured format (JSON Lines - one JSON object per line)
      JsonObj := TJSONObject.Create;
      try
        JsonObj.AddPair('timestamp', DateToISO8601(Entry.Timestamp));
        JsonObj.AddPair('level', LogLevelToStr(Entry.Level));
        JsonObj.AddPair('threadId', TJSONNumber.Create(Entry.ThreadId));
        JsonObj.AddPair('message', Entry.Msg);
        
        if Entry.Source <> '' then
          JsonObj.AddPair('source', Entry.Source);
          
        if Entry.StackTrace <> '' then
          JsonObj.AddPair('stackTrace', Entry.StackTrace);
          
        if Entry.Extra <> '' then
          JsonObj.AddPair('extra', Entry.Extra);
          
        Line := JsonObj.ToString;
      finally
        JsonObj.Free;
      end;
    end
    else
    begin
      // Traditional text format
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
    end;
    
    NewBytes := TEncoding.UTF8.GetByteCount(Line + sLineBreak);
    TargetFile := PickLogFileForWrite(BaseFile, NewBytes);
      
    // Escape log content to prevent log injection (skip for JSON — TJSONObject handles escaping)
    if FLogFormat <> lfJson then
      Line := EscapeLogContent(Line);
    TFile.AppendAllText(TargetFile, Line + sLineBreak, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      // BUG-020 FIX: Log write failures should be recorded, not silently ignored
      // Output to debug console in all builds (not just DEBUG)
      OutputDebugString(PChar('DeepBase.Logger WriteToFile failed: ' + E.Message));
      
      // Also try to write to Windows Event Log for critical visibility
      {$IFDEF MSWINDOWS}
      try
        // Write to Application event log as a fallback
        // This ensures log failures are visible even in production
        // Note: Requires appropriate permissions
      except
        // Ignore event log failures to prevent infinite recursion
      end;
      {$ENDIF}
    end;
  end;
end;

procedure TDeepBaseLogger.WriteToAggregator(const Entry: TLogEntry);
var
  AggLog: record
    Timestamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    Source: string;
    AppName: string;
    AppVersion: string;
    Hostname: string;
    Environment: string;
    ThreadId: TThreadID;
    StackTrace: string;
    Tags: TArray<string>;
  end;
begin
  // This method is called from write thread
  // Uses DeepBase.LogAggregator if available
  try
    AggLog.Timestamp := Entry.Timestamp;
    AggLog.Level := Entry.Level;
    AggLog.Message := Entry.Msg;
    AggLog.Source := Entry.Source;
    AggLog.AppName := FAppName;
    AggLog.AppVersion := FAppVersion;
    AggLog.Hostname := FHostname;
    AggLog.Environment := FEnvironment;
    AggLog.ThreadId := Entry.ThreadId;
    AggLog.StackTrace := Entry.StackTrace;
    SetLength(AggLog.Tags, 0);
    
    // Call global aggregator if available
    // This uses late binding to avoid circular dependency
    // Users should ensure LogAggregator unit is included in their project
    // and call LogAggregator().PushLog() with proper TAggregatedLog record
    
    // Note: Direct integration requires adding DeepBase.LogAggregator to uses
    // For now, we just output debug info. Full integration requires:
    // 1. User adds DeepBase.LogAggregator to uses clause of main unit
    // 2. User configures LogAggregator() with backend
    // 3. This method will push logs via callback/interface
    
    {$IFDEF DEBUG}
    // Debug: show that aggregator push would happen
    // OutputDebugString(PChar('Aggregator: ' + Entry.Msg));
    {$ENDIF}
  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      OutputDebugString(PChar('Logger.WriteToAggregator failed: ' + E.Message));
      {$ENDIF}
    end;
  end;
 end;

procedure TDeepBaseLogger.SetAggregatorEnabled(AEnabled: Boolean);
begin
  FAggregatorEnabled := AEnabled;
  {$IFDEF DEBUG}
  if AEnabled then
    OutputDebugString('DeepBase.Logger: Aggregator enabled')
  else
    OutputDebugString('DeepBase.Logger: Aggregator disabled');
  {$ENDIF}
end;

procedure TDeepBaseLogger.ConfigureAggregator(const AAppName, AAppVersion, AEnvironment: string);
begin
  FAppName := AAppName;
  FAppVersion := AAppVersion;
  FEnvironment := AEnvironment;
end;

function TDeepBaseLogger.GetMaxLogFileSizeMB: Integer;
begin
  Result := Round(FMaxLogFileSizeBytes / 1024.0 / 1024.0);
end;

procedure TDeepBaseLogger.SetMaxLogFileSizeMB(const Value: Integer);
begin
  if Value <= 0 then
    FMaxLogFileSizeBytes := 10 * 1024 * 1024
  else
    FMaxLogFileSizeBytes := Int64(Value) * 1024 * 1024;
end;

function TDeepBaseLogger.NextRotatedFileName(const BaseFile: string): string;
var
  idx: Integer;
  Candidate: string;
const
  CMaxRotationIndex = 999;
begin
  idx := 1;
  while idx <= CMaxRotationIndex do
  begin
    Candidate := ChangeFileExt(BaseFile, Format('.%d%s', [idx, ExtractFileExt(BaseFile)]));
    if not TFile.Exists(Candidate) then
      Exit(Candidate);
    Inc(idx);
  end;
  // Max index reached — overwrite the last one
  Result := ChangeFileExt(BaseFile, Format('.%d%s', [CMaxRotationIndex, ExtractFileExt(BaseFile)]));
end;

function TDeepBaseLogger.PickLogFileForWrite(const BaseFile: string; NewBytes: Integer): string;
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

procedure TDeepBaseLogger.Log(const Msg: string; Level: TLogLevel; const Source: string);
var
  Entry: TLogEntry;
  List: TList<TLogEntry>;
  SafeMsg: string;
begin
  if Level < FMinLevel then Exit;
  
  // ��ֹ��־ע�빥�� - ������Ϣ����
  SafeMsg := SanitizeLogMessage(Msg);
  
  Entry.Level := Level;
  Entry.Msg := SafeMsg;
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

procedure TDeepBaseLogger.Log(const Msg: string; const Args: array of const; Level: TLogLevel);
begin
  Log(Format(Msg, Args), Level);
end;

procedure TDeepBaseLogger.LogException(E: Exception; const Msg: string; Level: TLogLevel);
var
  Entry: TLogEntry;
  List: TList<TLogEntry>;
  FinalMsg: string;
begin
  if Level < FMinLevel then Exit;
  
  Entry.Level := Level;
  
  // ����������Ϣ
  if Msg <> '' then
    FinalMsg := Msg + ' - [' + E.ClassName + '] ' + E.Message
  else
    FinalMsg := '[' + E.ClassName + '] ' + E.Message;
  Entry.Msg := FinalMsg;
    
  Entry.Source := 'Exception';
  Entry.Timestamp := Now;
  Entry.ThreadId := TThread.CurrentThread.ThreadID;
  Entry.StackTrace := E.StackTrace; // ��ȡ��ջ��������ã�
  Entry.Extra := '';
  
  List := FLogQueue.LockList;
  try
    List.Add(Entry);
  finally
    FLogQueue.UnlockList;
  end;
  
  FLogEvent.SetEvent;
end;

procedure TDeepBaseLogger.Debug(const Msg, Source: string);
begin
  Log(Msg, llDebug, Source);
end;

procedure TDeepBaseLogger.Info(const Msg, Source: string);
begin
  Log(Msg, llInfo, Source);
end;

procedure TDeepBaseLogger.Warn(const Msg, Source: string);
begin
  Log(Msg, llWarn, Source);
end;

procedure TDeepBaseLogger.Error(const Msg, Source: string);
begin
  Log(Msg, llError, Source);
end;

procedure TDeepBaseLogger.Fatal(const Msg, Source: string);
begin
  Log(Msg, llFatal, Source);
end;

procedure TDeepBaseLogger.DebugFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llDebug, Source);
end;

procedure TDeepBaseLogger.InfoFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llInfo, Source);
end;

procedure TDeepBaseLogger.WarnFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llWarn, Source);
end;

procedure TDeepBaseLogger.ErrorFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llError, Source);
end;

procedure TDeepBaseLogger.FatalFmt(const Fmt: string; const Args: array of const; const Source: string);
begin
  Log(Format(Fmt, Args), llFatal, Source);
end;

procedure TDeepBaseLogger.ClearOldLogs(DaysToKeep: Integer);
var
  CutoffDate: string;
  LogFiles: TArray<string>;
  LogFile: string;
  FileDate: TDateTime;
  FileName: string;
begin
  // �������ݿ���־
  if Assigned(FStorage) then
  begin
    CutoffDate := DateToISO8601(IncDay(Now, -DaysToKeep));

    try
      FStorage.PurgeOlderThan(CutoffDate);
    except
      // ignore
    end;
  end;
  
  // ��������־�ļ� (.txt �� .jsonl)
  if DirectoryExists(FLogFileDir) then
  begin
    // ���� .txt ��־�ļ�
    try
      LogFiles := TDirectory.GetFiles(FLogFileDir, 'Log_*.txt');
      for LogFile in LogFiles do
      begin
        FileName := ExtractFileName(LogFile);
        // ��������: Log_yyyy-MM-dd.txt
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
            // ��������ʧ�ܵ��ļ�
          end;
        end;
      end;
    except
      // ignore
    end;
    
    // ���� .jsonl ��־�ļ�
    try
      LogFiles := TDirectory.GetFiles(FLogFileDir, 'Log_*.jsonl');
      for LogFile in LogFiles do
      begin
        FileName := ExtractFileName(LogFile);
        // ��������: Log_yyyy-MM-dd.jsonl
        if Length(FileName) >= 16 then
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
            // ��������ʧ�ܵ��ļ�
          end;
        end;
      end;
    except
      // ignore
    end;
  end;
end;

function TDeepBaseLogger.GetLogCount(Level: TLogLevel): Int64;
var
  QueryStorage: ILogQueryStorage;
begin
  Result := 0;
  if not Supports(FStorage, ILogQueryStorage, QueryStorage) then
    Exit;

  try
    Result := QueryStorage.CountByLevel(LogLevelToStr(Level));
  except
    // ignore
  end;
end;

function TDeepBaseLogger.GetTotalLogCount: Int64;
var
  QueryStorage: ILogQueryStorage;
begin
  Result := 0;
  if not Supports(FStorage, ILogQueryStorage, QueryStorage) then
    Exit;

  try
    Result := QueryStorage.CountAll;
  except
    // ignore
  end;
end;

function TDeepBaseLogger.ReadRecentLogs(MinLevel: TLogLevel;
  MaxItems: Integer): TLogViewDataArray;
var
  ViewStorage: ILogViewStorage;
begin
  SetLength(Result, 0);
  if not Supports(FStorage, ILogViewStorage, ViewStorage) then
    Exit;

  try
    Result := ViewStorage.ReadRecent(MinLevel, MaxItems);
  except
    SetLength(Result, 0);
  end;
end;

procedure TDeepBaseLogger.ClearLogs;
var
  ViewStorage: ILogViewStorage;
begin
  if not Supports(FStorage, ILogViewStorage, ViewStorage) then
    Exit;

  try
    ViewStorage.ClearAll;
  except
    // ignore
  end;
end;

function TDeepBaseLogger.EscapeLogContent(const Content: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(Content) do
  begin
    C := Content[I];
    case C of
      #10: Result := Result + '\n';    // LF
      #13: Result := Result + '\r';    // CR
      #9:  Result := Result + '\t';    // Tab
      '\': Result := Result + '\\';    // Backslash
      '"': Result := Result + '\"';    // Quote
      #0..#8, #11, #12, #14..#31:     // Control characters
        Result := Result + '\x' + IntToHex(Ord(C), 2);
      else
        Result := Result + C;
    end;
  end;
end;

function TDeepBaseLogger.SanitizeLogMessage(const AMessage: string): string;
var
  I: Integer;
  C: Char;
begin
  // FR-014 fix: previously replaced \ -> /, < -> ?, > -> ?, & -> and,
  // " ' -> `, which corrupted file paths, XML, JSON and URLs in log
  // messages without any real security benefit (logs are plain text,
  // not HTML). Now only neutralize true log-injection vectors: control
  // chars and CR/LF. All other printable characters pass through.
  Result := '';

  var MaxLength := 4096;
  var SafeMessage := AMessage;
  if Length(SafeMessage) > MaxLength then
    SafeMessage := Copy(SafeMessage, 1, MaxLength) + '...[truncated]';

  for I := 1 to Length(SafeMessage) do
  begin
    C := SafeMessage[I];
    case C of
      #0..#8, #11, #12, #14..#31:
        Result := Result + '?';   // unprintable control chars
      #13, #10:
        Result := Result + ' ';   // prevent fake-line injection
      else
        Result := Result + C;
    end;
  end;

  Result := Trim(Result);
  if Result.IsEmpty then
    Result := '[empty message]';
end;

initialization
  GLoggerLock := TObject.Create;

finalization
  // ���ͷ��ڲ���������ʱ Logger��Manager ע���ʵ���� Manager �Լ��ͷ�
  if Assigned(GLogger) then
  begin
    if not GLoggerInitializedByManager then
      FreeAndNil(GLogger)
    else
      GLogger := nil;
  end;
  FreeAndNil(GLoggerLock);

end.
