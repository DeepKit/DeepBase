unit DeepBase.LogAggregator;

{*******************************************************************************
  DeepBase Log Aggregator
  Centralized log aggregation with multiple backend support:
  - ElasticSearch 7.x+ (Bulk API)
  - Grafana Loki (Push API)
  - Generic HTTP Webhook
  - Fluentd (Forward protocol)
  
  Features:
  - Async batch push with background thread
  - Local buffer queue for reliability
  - Retry with exponential backoff
  - Health check and auto-reconnect
  - Multiple backends simultaneously
  
  Author: DeepBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  System.JSON, System.DateUtils, System.NetEncoding, System.Net.HttpClient,
  System.Net.URLClient, System.Threading,
  DeepBase.Types, DeepBase.Logging;

type
  ELogAggregatorException = class(Exception);

  /// <summary>Log backend types</summary>
  TLogBackendType = (
    lbtElasticSearch,  // ElasticSearch 7.x+
    lbtLoki,           // Grafana Loki
    lbtFluentd,        // Fluentd forward
    lbtHttp            // Generic HTTP webhook
  );

  /// <summary>Backend connection state</summary>
  TBackendState = (bsDisconnected, bsConnecting, bsConnected, bsError);

  /// <summary>Log entry for aggregation (extended from TLogEntry)</summary>
  TAggregatedLog = record
    Timestamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    Source: string;
    ThreadId: TThreadID;
    StackTrace: string;
    Extra: string;
    // Extended fields
    AppName: string;
    AppVersion: string;
    Hostname: string;
    Environment: string;
    Tags: TArray<TPair<string, string>>;
    
    function ToJSON: TJSONObject;
    function ToElasticSearchDoc: string;
    function ToLokiEntry: TJSONObject;
    class function FromLogEntry(const AEntry: TLogEntry): TAggregatedLog; static;
  end;

  /// <summary>Batch of logs for bulk operations</summary>
  TLogBatch = class
  private
    FLogs: TList<TAggregatedLog>;
    FCreatedAt: TDateTime;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure Add(const ALog: TAggregatedLog);
    procedure AddRange(const ALogs: TArray<TAggregatedLog>);
    procedure Clear;
    function Count: Integer;
    function ToArray: TArray<TAggregatedLog>;
    function IsEmpty: Boolean;
    function Age: Integer; // milliseconds since creation
    
    property CreatedAt: TDateTime read FCreatedAt;
  end;

  /// <summary>Log filter for queries</summary>
  TLogFilter = record
    Levels: TArray<TLogLevel>;
    Sources: TArray<string>;
    StartTime: TDateTime;
    EndTime: TDateTime;
    Keywords: TArray<string>;
    ExcludeKeywords: TArray<string>;
    Limit: Integer;
    Offset: Integer;
    
    class function All: TLogFilter; static;
    function WithLevel(ALevel: TLogLevel): TLogFilter;
    function WithLevels(const ALevels: TArray<TLogLevel>): TLogFilter;
    function WithSource(const ASource: string): TLogFilter;
    function WithTimeRange(AStart, AEnd: TDateTime): TLogFilter;
    function WithKeyword(const AKeyword: string): TLogFilter;
    function WithLimit(ALimit: Integer): TLogFilter;
    function WithOffset(AOffset: Integer): TLogFilter;
  end;

  /// <summary>Backend configuration</summary>
  TBackendConfig = record
    BackendType: TLogBackendType;
    Url: string;
    Username: string;
    Password: string;
    ApiKey: string;
    IndexName: string;        // ES: index name, Loki: job label
    TimeoutMs: Integer;
    RetryCount: Integer;
    RetryDelayMs: Integer;
    BatchSize: Integer;
    FlushIntervalMs: Integer;
    Enabled: Boolean;
    
    class function ElasticSearch(const AUrl: string; const AIndex: string = 'logs'): TBackendConfig; static;
    class function Loki(const AUrl: string; const AJob: string = 'DeepBase'): TBackendConfig; static;
    class function HttpWebhook(const AUrl: string): TBackendConfig; static;
  end;

  /// <summary>Push result</summary>
  TPushResult = record
    Success: Boolean;
    StatusCode: Integer;
    Message: string;
    ItemsProcessed: Integer;
    ItemsFailed: Integer;
    ElapsedMs: Integer;
  end;

  /// <summary>Log backend interface</summary>
  ILogBackend = interface
    ['{A1B2C3D4-5678-9ABC-DEF0-111111111111}']
    function GetName: string;
    function GetBackendType: TLogBackendType;
    function GetState: TBackendState;
    function GetConfig: TBackendConfig;
    
    function Connect: Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    function HealthCheck: Boolean;
    
    function Push(const ALogs: TArray<TAggregatedLog>): TPushResult;
    function PushBatch(ABatch: TLogBatch): TPushResult;
    
    property Name: string read GetName;
    property BackendType: TLogBackendType read GetBackendType;
    property State: TBackendState read GetState;
    property Config: TBackendConfig read GetConfig;
  end;

  /// <summary>Base backend implementation</summary>
  TLogBackendBase = class(TInterfacedObject, ILogBackend)
  protected
    FName: string;
    FConfig: TBackendConfig;
    FState: TBackendState;
    FLock: TCriticalSection;
    FLastError: string;
    FHttpClient: THTTPClient;
    
    function GetName: string;
    function GetBackendType: TLogBackendType;
    function GetState: TBackendState;
    function GetConfig: TBackendConfig;
    
    procedure SetState(AState: TBackendState);
    function DoRequest(const AMethod, AUrl: string; const ABody: string = ''): TPushResult;
  public
    constructor Create(const AName: string; const AConfig: TBackendConfig);
    destructor Destroy; override;
    
    function Connect: Boolean; virtual;
    procedure Disconnect; virtual;
    function IsConnected: Boolean;
    function HealthCheck: Boolean; virtual; abstract;
    
    function Push(const ALogs: TArray<TAggregatedLog>): TPushResult; virtual; abstract;
    function PushBatch(ABatch: TLogBatch): TPushResult;
    
    property Name: string read GetName;
    property BackendType: TLogBackendType read GetBackendType;
    property State: TBackendState read GetState;
    property Config: TBackendConfig read GetConfig;
    property LastError: string read FLastError;
  end;

  /// <summary>ElasticSearch backend (7.x+)</summary>
  TElasticSearchBackend = class(TLogBackendBase)
  private
    FIndexTemplate: string;
    function BuildBulkBody(const ALogs: TArray<TAggregatedLog>): string;
    function GetIndexName: string;
    procedure EnsureIndexTemplate;
  public
    constructor Create(const AName: string; const AConfig: TBackendConfig);
    
    function Connect: Boolean; override;
    function HealthCheck: Boolean; override;
    function Push(const ALogs: TArray<TAggregatedLog>): TPushResult; override;
    
    /// <summary>Create index with proper mappings</summary>
    function CreateIndex: Boolean;
    /// <summary>Delete index</summary>
    function DeleteIndex: Boolean;
  end;

  /// <summary>Grafana Loki backend</summary>
  TLokiBackend = class(TLogBackendBase)
  private
    FLabels: TDictionary<string, string>;
    function BuildPushBody(const ALogs: TArray<TAggregatedLog>): string;
  public
    constructor Create(const AName: string; const AConfig: TBackendConfig);
    destructor Destroy; override;
    
    function HealthCheck: Boolean; override;
    function Push(const ALogs: TArray<TAggregatedLog>): TPushResult; override;
    
    /// <summary>Add static label for all logs</summary>
    procedure AddLabel(const AName, AValue: string);
    /// <summary>Remove label</summary>
    procedure RemoveLabel(const AName: string);
  end;

  /// <summary>Generic HTTP webhook backend</summary>
  THttpWebhookBackend = class(TLogBackendBase)
  private
    FHeaders: TDictionary<string, string>;
    function BuildPayload(const ALogs: TArray<TAggregatedLog>): string;
  public
    constructor Create(const AName: string; const AConfig: TBackendConfig);
    destructor Destroy; override;
    
    function HealthCheck: Boolean; override;
    function Push(const ALogs: TArray<TAggregatedLog>): TPushResult; override;
    
    /// <summary>Add custom header</summary>
    procedure AddHeader(const AName, AValue: string);
  end;

  /// <summary>Aggregator statistics</summary>
  TAggregatorStats = record
    TotalReceived: Int64;
    TotalPushed: Int64;
    TotalFailed: Int64;
    TotalRetried: Int64;
    CurrentQueueSize: Integer;
    LastPushTime: TDateTime;
    LastErrorTime: TDateTime;
    LastError: string;
    BackendStats: TArray<TPair<string, TPushResult>>;
    
    function ToString: string;
  end;

  /// <summary>Log aggregator - main class</summary>
  TLogAggregator = class
  private
    FBackends: TDictionary<string, ILogBackend>;
    FBuffer: TThreadList<TAggregatedLog>;
    FLock: TCriticalSection;
    
    // Worker thread
    FWorkerThread: TThread;
    FStopEvent: TEvent;
    FFlushEvent: TEvent;
    FRunning: Boolean;
    
    // Configuration
    FBatchSize: Integer;
    FFlushIntervalMs: Integer;
    FMaxBufferSize: Integer;
    FRetryCount: Integer;
    FRetryDelayMs: Integer;
    
    // Statistics
    FStats: TAggregatorStats;
    FStatsLock: TCriticalSection;
    
    // App metadata
    FAppName: string;
    FAppVersion: string;
    FHostname: string;
    FEnvironment: string;
    
    // Events
    FOnError: TProc<string, Exception>;
    FOnPushComplete: TProc<string, TPushResult>;
    
    procedure WorkerProc;
    procedure FlushBuffer;
    procedure PushToBackends(const ALogs: TArray<TAggregatedLog>);
    procedure UpdateStats(const ABackendName: string; const AResult: TPushResult; ACount: Integer);
    function EnrichLog(const ALog: TAggregatedLog): TAggregatedLog;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Start the aggregator worker</summary>
    procedure Start;
    /// <summary>Stop the aggregator worker</summary>
    procedure Stop;
    /// <summary>Force flush pending logs</summary>
    procedure Flush;
    
    /// <summary>Add a backend</summary>
    procedure AddBackend(ABackend: ILogBackend);
    /// <summary>Remove a backend</summary>
    procedure RemoveBackend(const AName: string);
    /// <summary>Get a backend by name</summary>
    function GetBackend(const AName: string): ILogBackend;
    /// <summary>Check if backend exists</summary>
    function HasBackend(const AName: string): Boolean;
    /// <summary>Get all backend names</summary>
    function GetBackendNames: TArray<string>;
    
    /// <summary>Push a single log entry</summary>
    procedure Push(const ALog: TAggregatedLog); overload;
    /// <summary>Push from TLogEntry</summary>
    procedure Push(const AEntry: TLogEntry); overload;
    /// <summary>Push multiple logs</summary>
    procedure Push(const ALogs: TArray<TAggregatedLog>); overload;
    
    /// <summary>Get current statistics</summary>
    function GetStats: TAggregatorStats;
    /// <summary>Reset statistics</summary>
    procedure ResetStats;
    
    /// <summary>Check all backends health</summary>
    function HealthCheck: TArray<TPair<string, Boolean>>;
    
    // Configuration properties
    property BatchSize: Integer read FBatchSize write FBatchSize;
    property FlushIntervalMs: Integer read FFlushIntervalMs write FFlushIntervalMs;
    property MaxBufferSize: Integer read FMaxBufferSize write FMaxBufferSize;
    property RetryCount: Integer read FRetryCount write FRetryCount;
    property RetryDelayMs: Integer read FRetryDelayMs write FRetryDelayMs;
    
    // App metadata
    property AppName: string read FAppName write FAppName;
    property AppVersion: string read FAppVersion write FAppVersion;
    property Hostname: string read FHostname write FHostname;
    property Environment: string read FEnvironment write FEnvironment;
    
    // Events
    property OnError: TProc<string, Exception> read FOnError write FOnError;
    property OnPushComplete: TProc<string, TPushResult> read FOnPushComplete write FOnPushComplete;
  end;

/// <summary>Global log aggregator singleton</summary>
function LogAggregator: TLogAggregator;
/// <summary>Set global log aggregator</summary>
procedure SetLogAggregator(AAggregator: TLogAggregator);
/// <summary>Check if aggregator is initialized</summary>
function IsAggregatorInitialized: Boolean;

/// <summary>Helper to create backends</summary>
function CreateElasticSearchBackend(const AUrl: string; const AIndex: string = 'logs'): ILogBackend;
function CreateLokiBackend(const AUrl: string; const AJob: string = 'DeepBase'): ILogBackend;
function CreateHttpWebhookBackend(const AUrl: string): ILogBackend;

implementation

uses
  System.StrUtils, Winapi.Windows;

var
  GAggregator: TLogAggregator = nil;
  GAggregatorLock: TCriticalSection = nil;

function LogAggregator: TLogAggregator;
begin
  if GAggregator = nil then
  begin
    GAggregatorLock.Enter;
    try
      if GAggregator = nil then
        GAggregator := TLogAggregator.Create;
    finally
      GAggregatorLock.Leave;
    end;
  end;
  Result := GAggregator;
end;

procedure SetLogAggregator(AAggregator: TLogAggregator);
begin
  GAggregatorLock.Enter;
  try
    if Assigned(GAggregator) and (GAggregator <> AAggregator) then
      FreeAndNil(GAggregator);
    GAggregator := AAggregator;
  finally
    GAggregatorLock.Leave;
  end;
end;

function IsAggregatorInitialized: Boolean;
begin
  Result := GAggregator <> nil;
end;

function CreateElasticSearchBackend(const AUrl: string; const AIndex: string): ILogBackend;
begin
  Result := TElasticSearchBackend.Create('elasticsearch', TBackendConfig.ElasticSearch(AUrl, AIndex));
end;

function CreateLokiBackend(const AUrl: string; const AJob: string): ILogBackend;
begin
  Result := TLokiBackend.Create('loki', TBackendConfig.Loki(AUrl, AJob));
end;

function CreateHttpWebhookBackend(const AUrl: string): ILogBackend;
begin
  Result := THttpWebhookBackend.Create('webhook', TBackendConfig.HttpWebhook(AUrl));
end;

{ TAggregatedLog }

function TAggregatedLog.ToJSON: TJSONObject;
var
  TagsArr: TJSONArray;
  TagObj: TJSONObject;
  Tag: TPair<string, string>;
begin
  Result := TJSONObject.Create;
  Result.AddPair('timestamp', DateToISO8601(Timestamp, False));
  Result.AddPair('level', LogLevelToStr(Level));
  Result.AddPair('message', Message);
  
  if Source <> '' then
    Result.AddPair('source', Source);
  if ThreadId <> 0 then
    Result.AddPair('threadId', TJSONNumber.Create(ThreadId));
  if StackTrace <> '' then
    Result.AddPair('stackTrace', StackTrace);
  if Extra <> '' then
    Result.AddPair('extra', Extra);
  if AppName <> '' then
    Result.AddPair('appName', AppName);
  if AppVersion <> '' then
    Result.AddPair('appVersion', AppVersion);
  if Hostname <> '' then
    Result.AddPair('hostname', Hostname);
  if Environment <> '' then
    Result.AddPair('environment', Environment);
    
  if Length(Tags) > 0 then
  begin
    TagsArr := TJSONArray.Create;
    for Tag in Tags do
    begin
      TagObj := TJSONObject.Create;
      TagObj.AddPair(Tag.Key, Tag.Value);
      TagsArr.AddElement(TagObj);
    end;
    Result.AddPair('tags', TagsArr);
  end;
end;

function TAggregatedLog.ToElasticSearchDoc: string;
var
  Json: TJSONObject;
begin
  Json := ToJSON;
  try
    // ES uses @timestamp convention
    Json.RemovePair('timestamp');
    Json.AddPair('@timestamp', DateToISO8601(Timestamp, False));
    Result := Json.ToString;
  finally
    Json.Free;
  end;
end;

function TAggregatedLog.ToLokiEntry: TJSONObject;
var
  ValuesArr: TJSONArray;
  EntryArr: TJSONArray;
  NanoTs: Int64;
begin
  // Loki expects timestamp in nanoseconds as string
  NanoTs := DateTimeToUnix(Timestamp, False) * 1000000000;
  
  Result := TJSONObject.Create;
  ValuesArr := TJSONArray.Create;
  
  EntryArr := TJSONArray.Create;
  EntryArr.Add(IntToStr(NanoTs));
  EntryArr.Add(Format('[%s] %s', [LogLevelToStr(Level), Message]));
  
  ValuesArr.AddElement(EntryArr);
  Result.AddPair('values', ValuesArr);
end;

class function TAggregatedLog.FromLogEntry(const AEntry: TLogEntry): TAggregatedLog;
begin
  Result.Timestamp := AEntry.Timestamp;
  Result.Level := AEntry.Level;
  Result.Message := AEntry.Msg;
  Result.Source := AEntry.Source;
  Result.ThreadId := AEntry.ThreadId;
  Result.StackTrace := AEntry.StackTrace;
  Result.Extra := AEntry.Extra;
  Result.AppName := '';
  Result.AppVersion := '';
  Result.Hostname := '';
  Result.Environment := '';
  SetLength(Result.Tags, 0);
end;

{ TLogBatch }

constructor TLogBatch.Create;
begin
  inherited Create;
  FLogs := TList<TAggregatedLog>.Create;
  FCreatedAt := Now;
  FLock := TCriticalSection.Create;
end;

destructor TLogBatch.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FLogs);
  inherited;
end;

procedure TLogBatch.Add(const ALog: TAggregatedLog);
begin
  FLock.Enter;
  try
    FLogs.Add(ALog);
  finally
    FLock.Leave;
  end;
end;

procedure TLogBatch.AddRange(const ALogs: TArray<TAggregatedLog>);
var
  Log: TAggregatedLog;
begin
  FLock.Enter;
  try
    for Log in ALogs do
      FLogs.Add(Log);
  finally
    FLock.Leave;
  end;
end;

procedure TLogBatch.Clear;
begin
  FLock.Enter;
  try
    FLogs.Clear;
    FCreatedAt := Now;
  finally
    FLock.Leave;
  end;
end;

function TLogBatch.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FLogs.Count;
  finally
    FLock.Leave;
  end;
end;

function TLogBatch.ToArray: TArray<TAggregatedLog>;
begin
  FLock.Enter;
  try
    Result := FLogs.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TLogBatch.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TLogBatch.Age: Integer;
begin
  Result := MilliSecondsBetween(Now, FCreatedAt);
end;

{ TLogFilter }

class function TLogFilter.All: TLogFilter;
begin
  SetLength(Result.Levels, 0);
  SetLength(Result.Sources, 0);
  Result.StartTime := 0;
  Result.EndTime := 0;
  SetLength(Result.Keywords, 0);
  SetLength(Result.ExcludeKeywords, 0);
  Result.Limit := 100;
  Result.Offset := 0;
end;

function TLogFilter.WithLevel(ALevel: TLogLevel): TLogFilter;
var
  I: Integer;
begin
  Result := Self;
  // CR-281b(Owner 决策A): 链式调用改追加语义(与 WithSource 一致)，
  // WhereLevel(Warn).WhereLevel(Error) 现在表示两者皆收；去重防重复条件
  for I := 0 to High(Result.Levels) do
    if Result.Levels[I] = ALevel then
      Exit;
  SetLength(Result.Levels, Length(Result.Levels) + 1);
  Result.Levels[High(Result.Levels)] := ALevel;
end;

function TLogFilter.WithLevels(const ALevels: TArray<TLogLevel>): TLogFilter;
var
  I: Integer;
begin
  Result := Self;
  // CR-281b(Owner 决策A): 追加而非覆盖
  for I := 0 to High(ALevels) do
    Result := Result.WithLevel(ALevels[I]);
end;

function TLogFilter.WithSource(const ASource: string): TLogFilter;
begin
  Result := Self;
  SetLength(Result.Sources, Length(Result.Sources) + 1);
  Result.Sources[High(Result.Sources)] := ASource;
end;

function TLogFilter.WithTimeRange(AStart, AEnd: TDateTime): TLogFilter;
begin
  Result := Self;
  Result.StartTime := AStart;
  Result.EndTime := AEnd;
end;

function TLogFilter.WithKeyword(const AKeyword: string): TLogFilter;
begin
  Result := Self;
  SetLength(Result.Keywords, Length(Result.Keywords) + 1);
  Result.Keywords[High(Result.Keywords)] := AKeyword;
end;

function TLogFilter.WithLimit(ALimit: Integer): TLogFilter;
begin
  Result := Self;
  Result.Limit := ALimit;
end;

function TLogFilter.WithOffset(AOffset: Integer): TLogFilter;
begin
  Result := Self;
  Result.Offset := AOffset;
end;

{ TBackendConfig }

class function TBackendConfig.ElasticSearch(const AUrl: string; const AIndex: string): TBackendConfig;
begin
  Result.BackendType := lbtElasticSearch;
  Result.Url := AUrl;
  Result.Username := '';
  Result.Password := '';
  Result.ApiKey := '';
  Result.IndexName := AIndex;
  Result.TimeoutMs := 30000;
  Result.RetryCount := 3;
  Result.RetryDelayMs := 1000;
  Result.BatchSize := 100;
  Result.FlushIntervalMs := 5000;
  Result.Enabled := True;
end;

class function TBackendConfig.Loki(const AUrl: string; const AJob: string): TBackendConfig;
begin
  Result.BackendType := lbtLoki;
  Result.Url := AUrl;
  Result.Username := '';
  Result.Password := '';
  Result.ApiKey := '';
  Result.IndexName := AJob;
  Result.TimeoutMs := 30000;
  Result.RetryCount := 3;
  Result.RetryDelayMs := 1000;
  Result.BatchSize := 100;
  Result.FlushIntervalMs := 5000;
  Result.Enabled := True;
end;

class function TBackendConfig.HttpWebhook(const AUrl: string): TBackendConfig;
begin
  Result.BackendType := lbtHttp;
  Result.Url := AUrl;
  Result.Username := '';
  Result.Password := '';
  Result.ApiKey := '';
  Result.IndexName := '';
  Result.TimeoutMs := 30000;
  Result.RetryCount := 3;
  Result.RetryDelayMs := 1000;
  Result.BatchSize := 100;
  Result.FlushIntervalMs := 5000;
  Result.Enabled := True;
end;

{ TAggregatorStats }

function TAggregatorStats.ToString: string;
begin
  Result := Format(
    'Received: %d, Pushed: %d, Failed: %d, Retried: %d, Queue: %d',
    [TotalReceived, TotalPushed, TotalFailed, TotalRetried, CurrentQueueSize]
  );
end;

{ TLogBackendBase }

constructor TLogBackendBase.Create(const AName: string; const AConfig: TBackendConfig);
begin
  inherited Create;
  FName := AName;
  FConfig := AConfig;
  FState := bsDisconnected;
  FLock := TCriticalSection.Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := AConfig.TimeoutMs;
  FHttpClient.ResponseTimeout := AConfig.TimeoutMs;
end;

destructor TLogBackendBase.Destroy;
begin
  Disconnect;
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

function TLogBackendBase.GetName: string;
begin
  Result := FName;
end;

function TLogBackendBase.GetBackendType: TLogBackendType;
begin
  Result := FConfig.BackendType;
end;

function TLogBackendBase.GetState: TBackendState;
begin
  FLock.Enter;
  try
    Result := FState;
  finally
    FLock.Leave;
  end;
end;

function TLogBackendBase.GetConfig: TBackendConfig;
begin
  Result := FConfig;
end;

procedure TLogBackendBase.SetState(AState: TBackendState);
begin
  FLock.Enter;
  try
    FState := AState;
  finally
    FLock.Leave;
  end;
end;

function TLogBackendBase.DoRequest(const AMethod, AUrl: string; const ABody: string): TPushResult;
var
  Response: IHTTPResponse;
  StartTime: TDateTime;
  Content: TStringStream;
  Headers: TNetHeaders;
begin
  Result.Success := False;
  Result.StatusCode := 0;
  Result.ItemsProcessed := 0;
  Result.ItemsFailed := 0;
  
  StartTime := Now;
  Content := nil;
  
  try
    SetLength(Headers, 1);
    Headers[0] := TNameValuePair.Create('Content-Type', 'application/json');
    
    // Add auth headers if configured
    if FConfig.ApiKey <> '' then
    begin
      SetLength(Headers, Length(Headers) + 1);
      Headers[High(Headers)] := TNameValuePair.Create('Authorization', 'ApiKey ' + FConfig.ApiKey);
    end
    else if (FConfig.Username <> '') and (FConfig.Password <> '') then
    begin
      SetLength(Headers, Length(Headers) + 1);
      Headers[High(Headers)] := TNameValuePair.Create('Authorization',
        'Basic ' + TNetEncoding.Base64.Encode(FConfig.Username + ':' + FConfig.Password));
    end;
    
    if ABody <> '' then
      Content := TStringStream.Create(ABody, TEncoding.UTF8);
    
    try
      if SameText(AMethod, 'GET') then
        Response := FHttpClient.Get(AUrl, nil, Headers)
      else if SameText(AMethod, 'POST') then
        Response := FHttpClient.Post(AUrl, Content, nil, Headers)
      else if SameText(AMethod, 'PUT') then
        Response := FHttpClient.Put(AUrl, Content, nil, Headers)
      else if SameText(AMethod, 'DELETE') then
        Response := FHttpClient.Delete(AUrl, nil, Headers)
      else
        raise ELogAggregatorException.CreateFmt('Unsupported HTTP method: %s', [AMethod]);
      
      Result.StatusCode := Response.StatusCode;
      Result.Message := Response.ContentAsString;
      Result.Success := (Response.StatusCode >= 200) and (Response.StatusCode < 300);
      Result.ElapsedMs := MilliSecondsBetween(Now, StartTime);
      
      if not Result.Success then
        FLastError := Format('HTTP %d: %s', [Response.StatusCode, Response.StatusText]);
    finally
      Content.Free;
    end;
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.Message := E.Message;
      Result.ElapsedMs := MilliSecondsBetween(Now, StartTime);
      FLastError := E.Message;
    end;
  end;
end;

function TLogBackendBase.Connect: Boolean;
begin
  SetState(bsConnecting);
  Result := HealthCheck;
  if Result then
    SetState(bsConnected)
  else
    SetState(bsError);
end;

procedure TLogBackendBase.Disconnect;
begin
  SetState(bsDisconnected);
end;

function TLogBackendBase.IsConnected: Boolean;
begin
  Result := GetState = bsConnected;
end;

function TLogBackendBase.PushBatch(ABatch: TLogBatch): TPushResult;
begin
  Result := Push(ABatch.ToArray);
end;

{ TElasticSearchBackend }

constructor TElasticSearchBackend.Create(const AName: string; const AConfig: TBackendConfig);
begin
  inherited Create(AName, AConfig);
  FIndexTemplate := '';
end;

function TElasticSearchBackend.GetIndexName: string;
begin
  // Use date-based index: logs-2025.12.02
  Result := FConfig.IndexName + '-' + FormatDateTime('yyyy.mm.dd', Now);
end;

procedure TElasticSearchBackend.EnsureIndexTemplate;
var
  TemplateBody: TJSONObject;
  Mappings, Properties: TJSONObject;
  Timestamp, Level, Message, Source: TJSONObject;
  Result: TPushResult;
begin
  if FIndexTemplate <> '' then Exit;
  
  // Create index template for proper field types
  TemplateBody := TJSONObject.Create;
  try
    TemplateBody.AddPair('index_patterns', TJSONArray.Create.Add(FConfig.IndexName + '-*'));
    
    Mappings := TJSONObject.Create;
    Properties := TJSONObject.Create;
    
    Timestamp := TJSONObject.Create;
    Timestamp.AddPair('type', 'date');
    Properties.AddPair('@timestamp', Timestamp);
    
    Level := TJSONObject.Create;
    Level.AddPair('type', 'keyword');
    Properties.AddPair('level', Level);
    
    Message := TJSONObject.Create;
    Message.AddPair('type', 'text');
    Properties.AddPair('message', Message);
    
    Source := TJSONObject.Create;
    Source.AddPair('type', 'keyword');
    Properties.AddPair('source', Source);
    
    Mappings.AddPair('properties', Properties);
    TemplateBody.AddPair('mappings', Mappings);
    
    Result := DoRequest('PUT', FConfig.Url + '/_index_template/' + FConfig.IndexName, TemplateBody.ToString);
    if Result.Success then
      FIndexTemplate := FConfig.IndexName;
  finally
    TemplateBody.Free;
  end;
end;

function TElasticSearchBackend.BuildBulkBody(const ALogs: TArray<TAggregatedLog>): string;
var
  Builder: TStringBuilder;
  Log: TAggregatedLog;
  IndexName: string;
  ActionLine: TJSONObject;
  IndexObj: TJSONObject;
begin
  IndexName := GetIndexName;
  Builder := TStringBuilder.Create;
  try
    for Log in ALogs do
    begin
      // Action line
      ActionLine := TJSONObject.Create;
      try
        IndexObj := TJSONObject.Create;
        IndexObj.AddPair('_index', IndexName);
        ActionLine.AddPair('index', IndexObj);
        Builder.Append(ActionLine.ToString);
        Builder.AppendLine;
      finally
        ActionLine.Free;
      end;
      
      // Document line
      Builder.Append(Log.ToElasticSearchDoc);
      Builder.AppendLine;
    end;
    
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TElasticSearchBackend.Connect: Boolean;
begin
  EnsureIndexTemplate;
  Result := inherited Connect;
end;

function TElasticSearchBackend.HealthCheck: Boolean;
var
  PushResult: TPushResult;
begin
  PushResult := DoRequest('GET', FConfig.Url + '/_cluster/health');
  Result := PushResult.Success;
end;

function TElasticSearchBackend.Push(const ALogs: TArray<TAggregatedLog>): TPushResult;
var
  BulkBody: string;
  Response: TJSONObject;
  Errors: Boolean;
begin
  if Length(ALogs) = 0 then
  begin
    Result.Success := True;
    Result.ItemsProcessed := 0;
    Exit;
  end;
  
  BulkBody := BuildBulkBody(ALogs);
  Result := DoRequest('POST', FConfig.Url + '/_bulk', BulkBody);
  
  if Result.Success then
  begin
    // Parse response to check for item-level errors
    try
      Response := TJSONObject.ParseJSONValue(Result.Message) as TJSONObject;
      try
        if Response <> nil then
        begin
          Errors := Response.GetValue<Boolean>('errors', False);
          if Errors then
          begin
            Result.ItemsFailed := 1; // Simplified - would need to count actual errors
            Result.ItemsProcessed := Length(ALogs) - Result.ItemsFailed;
          end
          else
          begin
            Result.ItemsProcessed := Length(ALogs);
            Result.ItemsFailed := 0;
          end;
        end;
      finally
        Response.Free;
      end;
    except
      Result.ItemsProcessed := Length(ALogs);
    end;
  end
  else
  begin
    Result.ItemsFailed := Length(ALogs);
  end;
end;

function TElasticSearchBackend.CreateIndex: Boolean;
var
  PushResult: TPushResult;
begin
  PushResult := DoRequest('PUT', FConfig.Url + '/' + GetIndexName);
  Result := PushResult.Success;
end;

function TElasticSearchBackend.DeleteIndex: Boolean;
var
  PushResult: TPushResult;
begin
  PushResult := DoRequest('DELETE', FConfig.Url + '/' + GetIndexName);
  Result := PushResult.Success;
end;

{ TLokiBackend }

constructor TLokiBackend.Create(const AName: string; const AConfig: TBackendConfig);
begin
  inherited Create(AName, AConfig);
  FLabels := TDictionary<string, string>.Create;
  FLabels.Add('job', AConfig.IndexName);
end;

destructor TLokiBackend.Destroy;
begin
  FreeAndNil(FLabels);
  inherited;
end;


function TLokiBackend.BuildPushBody(const ALogs: TArray<TAggregatedLog>): string;
var
  Root, StreamObj, Labels: TJSONObject;
  Streams, Values, Entry: TJSONArray;
  Log: TAggregatedLog;
  LabelPair: TPair<string, string>;
  NanoTs: Int64;
begin
  Root := TJSONObject.Create;
  try
    Streams := TJSONArray.Create;
    
    // Group logs by level for better labeling
    StreamObj := TJSONObject.Create;
    
    // Build labels
    Labels := TJSONObject.Create;
    for LabelPair in FLabels do
      Labels.AddPair(LabelPair.Key, LabelPair.Value);
    StreamObj.AddPair('stream', Labels);
    
    // Build values
    Values := TJSONArray.Create;
    for Log in ALogs do
    begin
      NanoTs := DateTimeToUnix(Log.Timestamp, False) * 1000000000;
      Entry := TJSONArray.Create;
      Entry.Add(IntToStr(NanoTs));
      Entry.Add(Format('[%s] [%s] %s', [LogLevelToStr(Log.Level), Log.Source, Log.Message]));
      Values.AddElement(Entry);
    end;
    
    StreamObj.AddPair('values', Values);
    Streams.AddElement(StreamObj);
    Root.AddPair('streams', Streams);
    
    Result := Root.ToString;
  finally
    Root.Free;
  end;
end;

function TLokiBackend.HealthCheck: Boolean;
var
  PushResult: TPushResult;
begin
  PushResult := DoRequest('GET', FConfig.Url + '/ready');
  Result := PushResult.Success;
end;

function TLokiBackend.Push(const ALogs: TArray<TAggregatedLog>): TPushResult;
var
  Body: string;
begin
  if Length(ALogs) = 0 then
  begin
    Result.Success := True;
    Result.ItemsProcessed := 0;
    Exit;
  end;
  
  Body := BuildPushBody(ALogs);
  Result := DoRequest('POST', FConfig.Url + '/loki/api/v1/push', Body);
  
  if Result.Success then
  begin
    Result.ItemsProcessed := Length(ALogs);
    Result.ItemsFailed := 0;
  end
  else
  begin
    Result.ItemsFailed := Length(ALogs);
  end;
end;

procedure TLokiBackend.AddLabel(const AName, AValue: string);
begin
  FLock.Enter;
  try
    FLabels.AddOrSetValue(AName, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TLokiBackend.RemoveLabel(const AName: string);
begin
  FLock.Enter;
  try
    FLabels.Remove(AName);
  finally
    FLock.Leave;
  end;
end;

{ THttpWebhookBackend }

constructor THttpWebhookBackend.Create(const AName: string; const AConfig: TBackendConfig);
begin
  inherited Create(AName, AConfig);
  FHeaders := TDictionary<string, string>.Create;
end;

destructor THttpWebhookBackend.Destroy;
begin
  FreeAndNil(FHeaders);
  inherited;
end;

function THttpWebhookBackend.BuildPayload(const ALogs: TArray<TAggregatedLog>): string;
var
  Root: TJSONObject;
  LogsArr: TJSONArray;
  Log: TAggregatedLog;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('timestamp', DateToISO8601(Now, False));
    Root.AddPair('count', TJSONNumber.Create(Length(ALogs)));
    
    LogsArr := TJSONArray.Create;
    for Log in ALogs do
      LogsArr.AddElement(Log.ToJSON);
    Root.AddPair('logs', LogsArr);
    
    Result := Root.ToString;
  finally
    Root.Free;
  end;
end;

function THttpWebhookBackend.HealthCheck: Boolean;
begin
  // For webhooks, assume healthy if URL is set
  Result := FConfig.Url <> '';
end;

function THttpWebhookBackend.Push(const ALogs: TArray<TAggregatedLog>): TPushResult;
var
  Body: string;
begin
  if Length(ALogs) = 0 then
  begin
    Result.Success := True;
    Result.ItemsProcessed := 0;
    Exit;
  end;
  
  Body := BuildPayload(ALogs);
  Result := DoRequest('POST', FConfig.Url, Body);
  
  if Result.Success then
  begin
    Result.ItemsProcessed := Length(ALogs);
    Result.ItemsFailed := 0;
  end
  else
  begin
    Result.ItemsFailed := Length(ALogs);
  end;
end;

procedure THttpWebhookBackend.AddHeader(const AName, AValue: string);
begin
  FLock.Enter;
  try
    FHeaders.AddOrSetValue(AName, AValue);
  finally
    FLock.Leave;
  end;
end;

{ TLogAggregator }

constructor TLogAggregator.Create;
var
  ComputerName: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  Size: DWORD;
begin
  inherited Create;
  FBackends := TDictionary<string, ILogBackend>.Create;
  FBuffer := TThreadList<TAggregatedLog>.Create;
  FLock := TCriticalSection.Create;
  FStatsLock := TCriticalSection.Create;
  
  FStopEvent := TEvent.Create;
  FFlushEvent := TEvent.Create;
  FRunning := False;
  
  // Defaults
  FBatchSize := 100;
  FFlushIntervalMs := 5000;
  FMaxBufferSize := 10000;
  FRetryCount := 3;
  FRetryDelayMs := 1000;
  
  // Get hostname
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  if GetComputerName(ComputerName, Size) then
    FHostname := ComputerName
  else
    FHostname := 'unknown';
    
  FAppName := ExtractFileName(ParamStr(0));
  FAppVersion := '';
  FEnvironment := 'production';
  
  // Initialize stats
  FillChar(FStats, SizeOf(FStats), 0);
end;

destructor TLogAggregator.Destroy;
begin
  Stop;
  
  FreeAndNil(FFlushEvent);
  FreeAndNil(FStopEvent);
  FreeAndNil(FStatsLock);
  FreeAndNil(FLock);
  FreeAndNil(FBuffer);
  FreeAndNil(FBackends);
  inherited;
end;

procedure TLogAggregator.Start;
begin
  if FRunning then Exit;
  
  FRunning := True;
  FStopEvent.ResetEvent;
  
  FWorkerThread := TThread.CreateAnonymousThread(WorkerProc);
  FWorkerThread.FreeOnTerminate := False;
  FWorkerThread.Start;
end;

procedure TLogAggregator.Stop;
begin
  if not FRunning then Exit;
  
  FRunning := False;
  FStopEvent.SetEvent;
  
  if Assigned(FWorkerThread) then
  begin
    FWorkerThread.WaitFor;
    FreeAndNil(FWorkerThread);
  end;
  
  // Final flush
  FlushBuffer;
end;

procedure TLogAggregator.Flush;
begin
  FFlushEvent.SetEvent;
end;

procedure TLogAggregator.WorkerProc;
var
  Events: array[0..1] of THandle;
  WaitResult: DWORD;
begin
  Events[0] := FStopEvent.Handle;
  Events[1] := FFlushEvent.Handle;
  
  while FRunning do
  begin
    WaitResult := WaitForMultipleObjects(2, @Events, False, Cardinal(FFlushIntervalMs));
    
    if WaitResult = WAIT_OBJECT_0 then
      Break; // Stop requested
      
    FFlushEvent.ResetEvent;
    FlushBuffer;
  end;
end;

procedure TLogAggregator.FlushBuffer;
var
  List: TList<TAggregatedLog>;
  Logs: TArray<TAggregatedLog>;
  BatchCount, I: Integer;
begin
  List := FBuffer.LockList;
  try
    if List.Count = 0 then Exit;
    
    BatchCount := List.Count;
    if BatchCount > FBatchSize then
      BatchCount := FBatchSize;
      
    SetLength(Logs, BatchCount);
    for I := 0 to BatchCount - 1 do
      Logs[I] := List[I];
    List.DeleteRange(0, BatchCount);
  finally
    FBuffer.UnlockList;
  end;
  
  if Length(Logs) > 0 then
    PushToBackends(Logs);
end;

procedure TLogAggregator.PushToBackends(const ALogs: TArray<TAggregatedLog>);
var
  Backend: ILogBackend;
  PushResult: TPushResult;
  RetryDelay: Integer;
  I: Integer;
begin
  FLock.Enter;
  try
    for Backend in FBackends.Values do
    begin
      if not Backend.Config.Enabled then Continue;
      
      // Retry loop
      for I := 0 to FRetryCount - 1 do
      begin
        try
          if not Backend.IsConnected then
            Backend.Connect;
            
          PushResult := Backend.Push(ALogs);
          UpdateStats(Backend.Name, PushResult, Length(ALogs));
          
          if Assigned(FOnPushComplete) then
            FOnPushComplete(Backend.Name, PushResult);
            
          if PushResult.Success then
            Break;
            
          // Exponential backoff
          RetryDelay := FRetryDelayMs * (1 shl I);
          Sleep(RetryDelay);
          
          FStatsLock.Enter;
          try
            Inc(FStats.TotalRetried);
          finally
            FStatsLock.Leave;
          end;
        except
          on E: Exception do
          begin
            if Assigned(FOnError) then
              FOnError(Backend.Name, E);
          end;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLogAggregator.UpdateStats(const ABackendName: string; const AResult: TPushResult; ACount: Integer);
begin
  FStatsLock.Enter;
  try
    if AResult.Success then
    begin
      Inc(FStats.TotalPushed, AResult.ItemsProcessed);
      FStats.LastPushTime := Now;
    end
    else
    begin
      Inc(FStats.TotalFailed, AResult.ItemsFailed);
      FStats.LastErrorTime := Now;
      FStats.LastError := AResult.Message;
    end;
  finally
    FStatsLock.Leave;
  end;
end;

function TLogAggregator.EnrichLog(const ALog: TAggregatedLog): TAggregatedLog;
begin
  Result := ALog;
  if Result.AppName = '' then Result.AppName := FAppName;
  if Result.AppVersion = '' then Result.AppVersion := FAppVersion;
  if Result.Hostname = '' then Result.Hostname := FHostname;
  if Result.Environment = '' then Result.Environment := FEnvironment;
end;

procedure TLogAggregator.AddBackend(ABackend: ILogBackend);
begin
  FLock.Enter;
  try
    FBackends.AddOrSetValue(ABackend.Name, ABackend);
  finally
    FLock.Leave;
  end;
end;

procedure TLogAggregator.RemoveBackend(const AName: string);
begin
  FLock.Enter;
  try
    FBackends.Remove(AName);
  finally
    FLock.Leave;
  end;
end;

function TLogAggregator.GetBackend(const AName: string): ILogBackend;
begin
  FLock.Enter;
  try
    if not FBackends.TryGetValue(AName, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TLogAggregator.HasBackend(const AName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FBackends.ContainsKey(AName);
  finally
    FLock.Leave;
  end;
end;

function TLogAggregator.GetBackendNames: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FBackends.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TLogAggregator.Push(const ALog: TAggregatedLog);
var
  List: TList<TAggregatedLog>;
  EnrichedLog: TAggregatedLog;
begin
  EnrichedLog := EnrichLog(ALog);
  
  List := FBuffer.LockList;
  try
    if List.Count < FMaxBufferSize then
    begin
      List.Add(EnrichedLog);
      
      FStatsLock.Enter;
      try
        Inc(FStats.TotalReceived);
        FStats.CurrentQueueSize := List.Count;
      finally
        FStatsLock.Leave;
      end;
    end;
    
    // Trigger flush if batch size reached
    if List.Count >= FBatchSize then
      FFlushEvent.SetEvent;
  finally
    FBuffer.UnlockList;
  end;
end;

procedure TLogAggregator.Push(const AEntry: TLogEntry);
begin
  Push(TAggregatedLog.FromLogEntry(AEntry));
end;

procedure TLogAggregator.Push(const ALogs: TArray<TAggregatedLog>);
var
  Log: TAggregatedLog;
begin
  for Log in ALogs do
    Push(Log);
end;

function TLogAggregator.GetStats: TAggregatorStats;
begin
  FStatsLock.Enter;
  try
    Result := FStats;
  finally
    FStatsLock.Leave;
  end;
end;

procedure TLogAggregator.ResetStats;
begin
  FStatsLock.Enter;
  try
    FillChar(FStats, SizeOf(FStats), 0);
  finally
    FStatsLock.Leave;
  end;
end;

function TLogAggregator.HealthCheck: TArray<TPair<string, Boolean>>;
var
  Backend: ILogBackend;
  Results: TList<TPair<string, Boolean>>;
begin
  Results := TList<TPair<string, Boolean>>.Create;
  try
    FLock.Enter;
    try
      for Backend in FBackends.Values do
        Results.Add(TPair<string, Boolean>.Create(Backend.Name, Backend.HealthCheck));
    finally
      FLock.Leave;
    end;
    
    Result := Results.ToArray;
  finally
    Results.Free;
  end;
end;

initialization
  GAggregatorLock := TCriticalSection.Create;

finalization
  FreeAndNil(GAggregator);
  FreeAndNil(GAggregatorLock);

end.
