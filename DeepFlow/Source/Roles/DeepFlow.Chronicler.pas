unit DeepFlow.Chronicler;

{*******************************************************************************
  DeepFlow.Chronicler - 记录员角色 (L1 基础层)
  
  描述：
    负责审计日志、事件记录和日志查询。
    所有重要操作都会被记录以供审计和调试。
    
  职责：
    - 结构化日志记录
    - 审计事件记录
    - 日志查询
    - SQLite 持久化
    
  信任级别：完全信任
    
  作者：仙儿（安全专家）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Generics.Collections, System.SyncObjs,
  DeepFlow.Message, DeepFlow.Role, DeepFlow.Config;

type
  /// <summary>日志级别</summary>
  TChroniclerLogLevel = (
    clDebug,
    clInfo,
    clWarn,
    clError,
    clFatal,
    clAudit  // 特殊级别：审计日志
  );

  /// <summary>日志条目</summary>
  TLogEntry = record
    Timestamp: TDateTime;
    Level: TChroniclerLogLevel;
    Component: string;
    Message: string;
    Details: TJSONObject;
    TraceId: string;
    SessionId: string;
  end;

  /// <summary>审计事件</summary>
  TAuditEvent = record
    EventId: string;
    Timestamp: TDateTime;
    EventType: string;
    Actor: string;        // 执行者（角色/用户）
    Action: string;       // 动作
    Resource: string;     // 资源
    Outcome: string;      // 结果 (success/failure)
    Details: TJSONObject;
    TraceId: string;
    SessionId: string;
  end;

  /// <summary>Chronicler 角色</summary>
  TChronicler = class(TDeepFlowRoleBase, IChronicler)
  private
    FConfig: TDeepFlowConfig;
    FLogPath: string;
    FCurrentLogFile: string;
    FLogFileStream: TStreamWriter;
    FLogLock: TCriticalSection;
    
    // 内存缓存（用于查询）
    FRecentLogs: TList<TLogEntry>;
    FAuditEvents: TList<TAuditEvent>;
    FMaxCacheSize: Integer;
    
    procedure EnsureLogFile;
    procedure WriteToFile(const AEntry: TLogEntry);
    procedure WriteAuditToFile(const AEvent: TAuditEvent);
    function LogLevelToString(ALevel: TChroniclerLogLevel): string;
    function StringToLogLevel(const ALevel: string): TChroniclerLogLevel;
    function GenerateEventId: string;
  protected
    procedure DoInitialize; override;
    procedure DoStart; override;
    procedure DoStop; override;
    function DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage; override;
  public
    constructor Create; overload;
    constructor Create(const AConfig: TDeepFlowConfig); overload;
    destructor Destroy; override;
    
    // IChronicler 实现
    /// <summary>记录日志</summary>
    procedure Log(const ALevel: string; const AComponent, AMessage: string; 
      const ADetails: TJSONObject = nil);
    /// <summary>记录审计事件</summary>
    procedure AuditLog(const AEvent: TJSONObject);
    /// <summary>查询日志</summary>
    function QueryLogs(const AFilter: TJSONObject): TJSONArray;
    
    // 便捷方法
    procedure Debug(const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    procedure Info(const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    procedure Warn(const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    procedure Error(const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    procedure Fatal(const AComponent, AMessage: string; const ADetails: TJSONObject = nil);
    
    /// <summary>记录审计事件（便捷方法）</summary>
    procedure Audit(const AEventType, AActor, AAction, AResource, AOutcome: string;
      const ADetails: TJSONObject = nil; const ATraceId: string = ''; const ASessionId: string = '');
    
    /// <summary>获取最近的日志</summary>
    function GetRecentLogs(ACount: Integer = 100): TJSONArray;
    /// <summary>获取最近的审计事件</summary>
    function GetRecentAuditEvents(ACount: Integer = 100): TJSONArray;
    
    function CanHandle(const AMsgType: string): Boolean; override;
  end;

implementation

uses
  System.DateUtils, System.StrUtils, System.Math;

{ TChronicler }

constructor TChronicler.Create;
begin
  Create(GlobalConfig);
end;

constructor TChronicler.Create(const AConfig: TDeepFlowConfig);
var
  Meta: TRoleMetaInfo;
begin
  Meta.Name := 'Chronicler';
  Meta.DisplayName := '记录员';
  Meta.Level := rlFoundation;
  Meta.TrustLevel := tlFullTrust;
  Meta.Description := '负责审计日志、事件记录';
  Meta.Version := '1.0';
  
  inherited Create(Meta);
  
  FConfig := AConfig;
  FLogLock := TCriticalSection.Create;
  FRecentLogs := TList<TLogEntry>.Create;
  FAuditEvents := TList<TAuditEvent>.Create;
  FMaxCacheSize := 1000;
end;

destructor TChronicler.Destroy;
begin
  if Assigned(FLogFileStream) then
  begin
    FLogFileStream.Flush;
    FLogFileStream.Free;
  end;
  
  FRecentLogs.Free;
  FAuditEvents.Free;
  FLogLock.Free;
  
  inherited;
end;

procedure TChronicler.DoInitialize;
begin
  FLogPath := FConfig.LogPath;
  
  // 确保日志目录存在
  if not TDirectory.Exists(FLogPath) then
    TDirectory.CreateDirectory(FLogPath);
end;

procedure TChronicler.DoStart;
begin
  EnsureLogFile;
  Info('Chronicler', 'Chronicler started');
end;

procedure TChronicler.DoStop;
begin
  Info('Chronicler', 'Chronicler stopping');
  
  FLogLock.Enter;
  try
    if Assigned(FLogFileStream) then
    begin
      FLogFileStream.Flush;
      FLogFileStream.Free;
      FLogFileStream := nil;
    end;
  finally
    FLogLock.Leave;
  end;
end;

procedure TChronicler.EnsureLogFile;
var
  LogFileName: string;
begin
  LogFileName := FLogPath + PathDelim + 'DeepFlow_' + FormatDateTime('yyyymmdd', Now) + '.log';
  
  if LogFileName <> FCurrentLogFile then
  begin
    FLogLock.Enter;
    try
      if Assigned(FLogFileStream) then
      begin
        FLogFileStream.Flush;
        FLogFileStream.Free;
      end;
      
      FCurrentLogFile := LogFileName;
      FLogFileStream := TStreamWriter.Create(FCurrentLogFile, True, TEncoding.UTF8);
    finally
      FLogLock.Leave;
    end;
  end;
end;

function TChronicler.LogLevelToString(ALevel: TChroniclerLogLevel): string;
begin
  case ALevel of
    clDebug: Result := 'DEBUG';
    clInfo: Result := 'INFO';
    clWarn: Result := 'WARN';
    clError: Result := 'ERROR';
    clFatal: Result := 'FATAL';
    clAudit: Result := 'AUDIT';
  else
    Result := 'UNKNOWN';
  end;
end;

function TChronicler.StringToLogLevel(const ALevel: string): TChroniclerLogLevel;
begin
  if SameText(ALevel, 'DEBUG') then Result := clDebug
  else if SameText(ALevel, 'INFO') then Result := clInfo
  else if SameText(ALevel, 'WARN') or SameText(ALevel, 'WARNING') then Result := clWarn
  else if SameText(ALevel, 'ERROR') then Result := clError
  else if SameText(ALevel, 'FATAL') then Result := clFatal
  else if SameText(ALevel, 'AUDIT') then Result := clAudit
  else Result := clInfo;
end;

function TChronicler.GenerateEventId: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := 'evt_' + Copy(GUIDToString(GUID), 2, 12);
end;

procedure TChronicler.WriteToFile(const AEntry: TLogEntry);
var
  LogLine: string;
  DetailsStr: string;
begin
  if AEntry.Details <> nil then
    DetailsStr := AEntry.Details.ToJSON
  else
    DetailsStr := '{}';
  
  LogLine := Format('%s [%s] [%s] %s | %s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp),
     LogLevelToString(AEntry.Level),
     AEntry.Component,
     AEntry.Message,
     DetailsStr]);
  
  EnsureLogFile;
  
  FLogLock.Enter;
  try
    if Assigned(FLogFileStream) then
    begin
      FLogFileStream.WriteLine(LogLine);
      FLogFileStream.Flush;
    end;
  finally
    FLogLock.Leave;
  end;
end;

procedure TChronicler.WriteAuditToFile(const AEvent: TAuditEvent);
var
  AuditJSON: TJSONObject;
  AuditFileName: string;
  AuditStream: TStreamWriter;
begin
  AuditJSON := TJSONObject.Create;
  try
    AuditJSON.AddPair('event_id', AEvent.EventId);
    AuditJSON.AddPair('timestamp', DateToISO8601(AEvent.Timestamp));
    AuditJSON.AddPair('event_type', AEvent.EventType);
    AuditJSON.AddPair('actor', AEvent.Actor);
    AuditJSON.AddPair('action', AEvent.Action);
    AuditJSON.AddPair('resource', AEvent.Resource);
    AuditJSON.AddPair('outcome', AEvent.Outcome);
    AuditJSON.AddPair('trace_id', AEvent.TraceId);
    AuditJSON.AddPair('session_id', AEvent.SessionId);
    
    if AEvent.Details <> nil then
      AuditJSON.AddPair('details', AEvent.Details.Clone as TJSONObject)
    else
      AuditJSON.AddPair('details', TJSONObject.Create);
    
    // 写入审计日志文件
    AuditFileName := FLogPath + PathDelim + 'audit_' + FormatDateTime('yyyymmdd', Now) + '.jsonl';
    
    FLogLock.Enter;
    try
      AuditStream := TStreamWriter.Create(AuditFileName, True, TEncoding.UTF8);
      try
        AuditStream.WriteLine(AuditJSON.ToJSON);
      finally
        AuditStream.Free;
      end;
    finally
      FLogLock.Leave;
    end;
  finally
    AuditJSON.Free;
  end;
end;

procedure TChronicler.Log(const ALevel: string; const AComponent, AMessage: string;
  const ADetails: TJSONObject);
var
  Entry: TLogEntry;
  LogLevel: TChroniclerLogLevel;
begin
  LogLevel := StringToLogLevel(ALevel);
  
  // 检查日志级别
  if Ord(LogLevel) < Ord(FConfig.LogLevel) then
    Exit;
  
  Entry.Timestamp := Now;
  Entry.Level := LogLevel;
  Entry.Component := AComponent;
  Entry.Message := AMessage;
  
  if ADetails <> nil then
    Entry.Details := ADetails.Clone as TJSONObject
  else
    Entry.Details := nil;
  
  // 写入文件
  WriteToFile(Entry);
  
  // 缓存到内存
  FLogLock.Enter;
  try
    FRecentLogs.Add(Entry);
    
    // 限制缓存大小
    while FRecentLogs.Count > FMaxCacheSize do
    begin
      if FRecentLogs[0].Details <> nil then
        FRecentLogs[0].Details.Free;
      FRecentLogs.Delete(0);
    end;
  finally
    FLogLock.Leave;
  end;
end;

procedure TChronicler.AuditLog(const AEvent: TJSONObject);
var
  Event: TAuditEvent;
begin
  Event.EventId := GenerateEventId;
  Event.Timestamp := Now;
  
  AEvent.TryGetValue<string>('event_type', Event.EventType);
  AEvent.TryGetValue<string>('actor', Event.Actor);
  AEvent.TryGetValue<string>('action', Event.Action);
  AEvent.TryGetValue<string>('resource', Event.Resource);
  AEvent.TryGetValue<string>('outcome', Event.Outcome);
  AEvent.TryGetValue<string>('trace_id', Event.TraceId);
  AEvent.TryGetValue<string>('session_id', Event.SessionId);
  
  var Details: TJSONObject;
  if AEvent.TryGetValue<TJSONObject>('details', Details) then
    Event.Details := Details.Clone as TJSONObject
  else
    Event.Details := nil;
  
  // 写入文件
  WriteAuditToFile(Event);
  
  // 同时写入普通日志
  Log('AUDIT', Event.Actor, Format('%s %s %s: %s', 
    [Event.EventType, Event.Action, Event.Resource, Event.Outcome]), Event.Details);
  
  // 缓存到内存
  FLogLock.Enter;
  try
    FAuditEvents.Add(Event);
    
    while FAuditEvents.Count > FMaxCacheSize do
    begin
      if FAuditEvents[0].Details <> nil then
        FAuditEvents[0].Details.Free;
      FAuditEvents.Delete(0);
    end;
  finally
    FLogLock.Leave;
  end;
end;

function TChronicler.QueryLogs(const AFilter: TJSONObject): TJSONArray;
var
  I: Integer;
  Entry: TLogEntry;
  EntryJSON: TJSONObject;
  LevelFilter: string;
  ComponentFilter: string;
  StartTime, EndTime: TDateTime;
  MaxResults: Integer;
begin
  Result := TJSONArray.Create;
  
  // 解析过滤条件
  LevelFilter := '';
  ComponentFilter := '';
  StartTime := 0;
  EndTime := Now;
  MaxResults := 100;
  
  if AFilter <> nil then
  begin
    AFilter.TryGetValue<string>('level', LevelFilter);
    AFilter.TryGetValue<string>('component', ComponentFilter);
    AFilter.TryGetValue<Integer>('max_results', MaxResults);
    
    var StartTimeStr: string;
    if AFilter.TryGetValue<string>('start_time', StartTimeStr) then
      StartTime := ISO8601ToDate(StartTimeStr);
    
    var EndTimeStr: string;
    if AFilter.TryGetValue<string>('end_time', EndTimeStr) then
      EndTime := ISO8601ToDate(EndTimeStr);
  end;
  
  FLogLock.Enter;
  try
    // 从最新的日志开始遍历
    for I := FRecentLogs.Count - 1 downto 0 do
    begin
      if Result.Count >= MaxResults then
        Break;
      
      Entry := FRecentLogs[I];
      
      // 应用过滤条件
      if (LevelFilter <> '') and not SameText(LogLevelToString(Entry.Level), LevelFilter) then
        Continue;
      
      if (ComponentFilter <> '') and (Pos(UpperCase(ComponentFilter), UpperCase(Entry.Component)) = 0) then
        Continue;
      
      if (StartTime > 0) and (Entry.Timestamp < StartTime) then
        Continue;
      
      if Entry.Timestamp > EndTime then
        Continue;
      
      // 构建 JSON
      EntryJSON := TJSONObject.Create;
      EntryJSON.AddPair('timestamp', DateToISO8601(Entry.Timestamp));
      EntryJSON.AddPair('level', LogLevelToString(Entry.Level));
      EntryJSON.AddPair('component', Entry.Component);
      EntryJSON.AddPair('message', Entry.Message);
      
      if Entry.Details <> nil then
        EntryJSON.AddPair('details', Entry.Details.Clone as TJSONObject)
      else
        EntryJSON.AddPair('details', TJSONObject.Create);
      
      Result.Add(EntryJSON);
    end;
  finally
    FLogLock.Leave;
  end;
end;

procedure TChronicler.Debug(const AComponent, AMessage: string; const ADetails: TJSONObject);
begin
  Log('DEBUG', AComponent, AMessage, ADetails);
end;

procedure TChronicler.Info(const AComponent, AMessage: string; const ADetails: TJSONObject);
begin
  Log('INFO', AComponent, AMessage, ADetails);
end;

procedure TChronicler.Warn(const AComponent, AMessage: string; const ADetails: TJSONObject);
begin
  Log('WARN', AComponent, AMessage, ADetails);
end;

procedure TChronicler.Error(const AComponent, AMessage: string; const ADetails: TJSONObject);
begin
  Log('ERROR', AComponent, AMessage, ADetails);
end;

procedure TChronicler.Fatal(const AComponent, AMessage: string; const ADetails: TJSONObject);
begin
  Log('FATAL', AComponent, AMessage, ADetails);
end;

procedure TChronicler.Audit(const AEventType, AActor, AAction, AResource, AOutcome: string;
  const ADetails: TJSONObject; const ATraceId, ASessionId: string);
var
  EventJSON: TJSONObject;
begin
  EventJSON := TJSONObject.Create;
  try
    EventJSON.AddPair('event_type', AEventType);
    EventJSON.AddPair('actor', AActor);
    EventJSON.AddPair('action', AAction);
    EventJSON.AddPair('resource', AResource);
    EventJSON.AddPair('outcome', AOutcome);
    EventJSON.AddPair('trace_id', ATraceId);
    EventJSON.AddPair('session_id', ASessionId);
    
    if ADetails <> nil then
      EventJSON.AddPair('details', ADetails.Clone as TJSONObject);
    
    AuditLog(EventJSON);
  finally
    EventJSON.Free;
  end;
end;

function TChronicler.GetRecentLogs(ACount: Integer): TJSONArray;
var
  I, StartIdx: Integer;
  Entry: TLogEntry;
  EntryJSON: TJSONObject;
begin
  Result := TJSONArray.Create;
  
  FLogLock.Enter;
  try
    StartIdx := Max(0, FRecentLogs.Count - ACount);
    
    for I := FRecentLogs.Count - 1 downto StartIdx do
    begin
      Entry := FRecentLogs[I];
      
      EntryJSON := TJSONObject.Create;
      EntryJSON.AddPair('timestamp', DateToISO8601(Entry.Timestamp));
      EntryJSON.AddPair('level', LogLevelToString(Entry.Level));
      EntryJSON.AddPair('component', Entry.Component);
      EntryJSON.AddPair('message', Entry.Message);
      
      Result.Add(EntryJSON);
    end;
  finally
    FLogLock.Leave;
  end;
end;

function TChronicler.GetRecentAuditEvents(ACount: Integer): TJSONArray;
var
  I, StartIdx: Integer;
  Event: TAuditEvent;
  EventJSON: TJSONObject;
begin
  Result := TJSONArray.Create;
  
  FLogLock.Enter;
  try
    StartIdx := Max(0, FAuditEvents.Count - ACount);
    
    for I := FAuditEvents.Count - 1 downto StartIdx do
    begin
      Event := FAuditEvents[I];
      
      EventJSON := TJSONObject.Create;
      EventJSON.AddPair('event_id', Event.EventId);
      EventJSON.AddPair('timestamp', DateToISO8601(Event.Timestamp));
      EventJSON.AddPair('event_type', Event.EventType);
      EventJSON.AddPair('actor', Event.Actor);
      EventJSON.AddPair('action', Event.Action);
      EventJSON.AddPair('resource', Event.Resource);
      EventJSON.AddPair('outcome', Event.Outcome);
      
      Result.Add(EventJSON);
    end;
  finally
    FLogLock.Leave;
  end;
end;

function TChronicler.DoHandleMessage(const AMessage: TDeepFlowMessage): TDeepFlowMessage;
var
  Level, Component, Msg: string;
  Details, Filter: TJSONObject;
  QueryResult: TJSONArray;
begin
  Result := nil;
  
  if AMessage.MsgType = 'chronicler.log' then
  begin
    // 记录日志
    if AMessage.Payload.TryGetValue<string>('level', Level) and
       AMessage.Payload.TryGetValue<string>('component', Component) and
       AMessage.Payload.TryGetValue<string>('message', Msg) then
    begin
      AMessage.Payload.TryGetValue<TJSONObject>('details', Details);
      Log(Level, Component, Msg, Details);
      
      Result := TResponseMessage.Create(AMessage);
      TResponseMessage(Result).Success := True;
    end;
  end
  else if AMessage.MsgType = 'chronicler.audit' then
  begin
    // 记录审计事件
    AuditLog(AMessage.Payload);
    
    Result := TResponseMessage.Create(AMessage);
    TResponseMessage(Result).Success := True;
  end
  else if AMessage.MsgType = 'chronicler.query' then
  begin
    // 查询日志
    AMessage.Payload.TryGetValue<TJSONObject>('filter', Filter);
    QueryResult := QueryLogs(Filter);
    
    Result := TResponseMessage.Create(AMessage);
    TResponseMessage(Result).Success := True;
    TResponseMessage(Result).Payload.Free;
    TResponseMessage(Result).Payload := TJSONObject.Create;
    TResponseMessage(Result).Payload.AddPair('logs', QueryResult);
  end
  else if AMessage.MsgType = 'chronicler.recent' then
  begin
    // 获取最近日志
    var Count: Integer := 100;
    AMessage.Payload.TryGetValue<Integer>('count', Count);
    
    Result := TResponseMessage.Create(AMessage);
    TResponseMessage(Result).Success := True;
    TResponseMessage(Result).Payload.Free;
    TResponseMessage(Result).Payload := TJSONObject.Create;
    TResponseMessage(Result).Payload.AddPair('logs', GetRecentLogs(Count));
    TResponseMessage(Result).Payload.AddPair('audit_events', GetRecentAuditEvents(Count));
  end;
end;

function TChronicler.CanHandle(const AMsgType: string): Boolean;
begin
  Result := AMsgType.StartsWith('chronicler.');
end;

end.
