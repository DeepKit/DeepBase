unit UniBase.LogAlert;

{*******************************************************************************
  UniBase Log Alert System
  Rule-based alerting engine for log monitoring:
  - Multiple condition types (error count, error rate, pattern match)
  - Multiple action types (webhook, email, callback)
  - Alert evaluation with configurable intervals
  - Alert history and deduplication
  
  Author: UniBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  System.JSON, System.DateUtils, System.RegularExpressions, System.Rtti,
  UniBase.Types, UniBase.LogAggregator, UniBase.LogQuery;

type
  EAlertException = class(Exception);

  /// <summary>Alert severity level</summary>
  TAlertSeverity = (asInfo, asWarning, asCritical);

  /// <summary>Alert condition type</summary>
  TAlertConditionType = (
    actErrorCount,       // Error count exceeds threshold
    actErrorRate,        // Error rate exceeds threshold
    actPatternMatch,     // Message matches pattern
    actNoLogs,           // No logs received in time window
    actAnomalyDetected,  // Statistical anomaly detected
    actCustom            // Custom condition
  );

  /// <summary>Alert action type</summary>
  TAlertActionType = (
    aatWebhook,          // HTTP webhook callback
    aatEmail,            // Email notification (interface)
    aatCallback,         // Local callback procedure
    aatLog               // Log the alert
  );

  /// <summary>Alert state</summary>
  TAlertState = (
    asIdle,              // No active alert
    asFiring,            // Alert condition met
    asRecovering,        // Alert recovering
    asResolved           // Alert resolved
  );

  /// <summary>Alert condition configuration</summary>
  TAlertCondition = record
    ConditionType: TAlertConditionType;
    
    // For error count/rate
    Threshold: Double;
    
    // For pattern match
    Pattern: string;
    
    // Time window (minutes)
    TimeWindowMinutes: Integer;
    
    // Log levels to consider
    Levels: TArray<TLogLevel>;
    
    // Source filter (optional)
    SourceFilter: string;
    
    class function ErrorCount(AThreshold: Integer; AWindowMinutes: Integer = 5): TAlertCondition; static;
    class function ErrorRate(AThreshold: Double; AWindowMinutes: Integer = 5): TAlertCondition; static;
    class function PatternMatch(const APattern: string): TAlertCondition; static;
    class function NoLogs(AWindowMinutes: Integer): TAlertCondition; static;
  end;

  /// <summary>Alert action configuration</summary>
  TAlertAction = record
    ActionType: TAlertActionType;
    
    // For webhook
    WebhookUrl: string;
    WebhookMethod: string;
    WebhookHeaders: TArray<TPair<string, string>>;
    
    // For email (interface only)
    EmailTo: TArray<string>;
    EmailSubject: string;
    
    // For callback
    Callback: TProc<TJSONObject>;
    
    class function Webhook(const AUrl: string): TAlertAction; static;
    class function Email(const ATo: string; const ASubject: string = ''): TAlertAction; static;
    class function LogAction: TAlertAction; static;
  end;

  /// <summary>Alert rule definition</summary>
  TAlertRule = class
  private
    FId: string;
    FName: string;
    FDescription: string;
    FEnabled: Boolean;
    FCondition: TAlertCondition;
    FActions: TList<TAlertAction>;
    FSeverity: TAlertSeverity;
    FState: TAlertState;
    FLastEvaluated: TDateTime;
    FLastFired: TDateTime;
    FFireCount: Int64;
    FCooldownMinutes: Integer;
    FTags: TArray<string>;
  public
    constructor Create(const AId, AName: string);
    destructor Destroy; override;
    
    function AddAction(const AAction: TAlertAction): TAlertRule;
    function WithCondition(const ACondition: TAlertCondition): TAlertRule;
    function WithSeverity(ASeverity: TAlertSeverity): TAlertRule;
    function WithCooldown(AMinutes: Integer): TAlertRule;
    function WithTags(const ATags: TArray<string>): TAlertRule;
    function Enable: TAlertRule;
    function Disable: TAlertRule;
    
    function ToJSON: TJSONObject;
    class function FromJSON(AJson: TJSONObject): TAlertRule; static;
    
    property Id: string read FId;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Enabled: Boolean read FEnabled write FEnabled;
    property Condition: TAlertCondition read FCondition write FCondition;
    property Actions: TList<TAlertAction> read FActions;
    property Severity: TAlertSeverity read FSeverity write FSeverity;
    property State: TAlertState read FState write FState;
    property LastEvaluated: TDateTime read FLastEvaluated write FLastEvaluated;
    property LastFired: TDateTime read FLastFired write FLastFired;
    property FireCount: Int64 read FFireCount write FFireCount;
    property CooldownMinutes: Integer read FCooldownMinutes write FCooldownMinutes;
    property Tags: TArray<string> read FTags write FTags;
  end;

  /// <summary>Alert event record</summary>
  TAlertEvent = record
    AlertId: string;
    RuleName: string;
    Severity: TAlertSeverity;
    State: TAlertState;
    Timestamp: TDateTime;
    Message: string;
    MatchedLogs: Integer;
    Details: TJSONObject;
    
    function ToJSON: TJSONObject;
    function ToString: string;
  end;

  /// <summary>Alert history entry</summary>
  TAlertHistoryEntry = record
    Event: TAlertEvent;
    ActionsTaken: TArray<string>;
    ActionsSucceeded: Integer;
    ActionsFailed: Integer;
  end;

  /// <summary>Alert evaluation context</summary>
  TAlertContext = class
  private
    FLogs: TList<TAggregatedLog>;
    FAnalyzer: TLogAnalyzer;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure SetLogs(ALogs: TList<TAggregatedLog>);
    procedure SetTimeRange(AStart, AEnd: TDateTime);
    
    property Logs: TList<TAggregatedLog> read FLogs;
    property Analyzer: TLogAnalyzer read FAnalyzer;
    property StartTime: TDateTime read FStartTime;
    property EndTime: TDateTime read FEndTime;
  end;

  /// <summary>Alert manager - main class</summary>
  TAlertManager = class
  private
    FRules: TDictionary<string, TAlertRule>;
    FHistory: TList<TAlertHistoryEntry>;
    FLock: TCriticalSection;
    
    // Evaluation thread
    FEvalThread: TThread;
    FStopEvent: TEvent;
    FEvalIntervalMs: Integer;
    FRunning: Boolean;
    
    // Log buffer for evaluation
    FLogBuffer: TList<TAggregatedLog>;
    FLogBufferLock: TCriticalSection;
    FMaxBufferSize: Integer;
    
    // Events
    FOnAlert: TProc<TAlertEvent>;
    FOnAlertResolved: TProc<TAlertEvent>;
    FOnActionFailed: TProc<string, TAlertAction, Exception>;
    
    procedure EvaluationProc;
    procedure EvaluateRule(ARule: TAlertRule; AContext: TAlertContext);
    function CheckCondition(ARule: TAlertRule; AContext: TAlertContext): Boolean;
    function CheckErrorCountCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
    function CheckErrorRateCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
    function CheckPatternCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
    function CheckNoLogsCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
    procedure ExecuteActions(ARule: TAlertRule; const AEvent: TAlertEvent);
    procedure ExecuteWebhook(const AAction: TAlertAction; const AEvent: TAlertEvent);
    function BuildAlertMessage(ARule: TAlertRule; AContext: TAlertContext): string;
    procedure AddHistoryEntry(const AEvent: TAlertEvent; const AActions: TArray<string>; ASucceeded, AFailed: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Start alert evaluation</summary>
    procedure Start;
    /// <summary>Stop alert evaluation</summary>
    procedure Stop;
    /// <summary>Force immediate evaluation</summary>
    procedure Evaluate;
    
    /// <summary>Add a rule</summary>
    procedure AddRule(ARule: TAlertRule);
    /// <summary>Remove a rule</summary>
    procedure RemoveRule(const AId: string);
    /// <summary>Get a rule by ID</summary>
    function GetRule(const AId: string): TAlertRule;
    /// <summary>Check if rule exists</summary>
    function HasRule(const AId: string): Boolean;
    /// <summary>Get all rule IDs</summary>
    function GetRuleIds: TArray<string>;
    /// <summary>Get rules by tag</summary>
    function GetRulesByTag(const ATag: string): TArray<TAlertRule>;
    
    /// <summary>Push log for evaluation</summary>
    procedure PushLog(const ALog: TAggregatedLog);
    /// <summary>Push multiple logs</summary>
    procedure PushLogs(const ALogs: TArray<TAggregatedLog>);
    
    /// <summary>Get alert history</summary>
    function GetHistory(ALimit: Integer = 100): TArray<TAlertHistoryEntry>;
    /// <summary>Clear history</summary>
    procedure ClearHistory;
    
    /// <summary>Get active alerts (firing rules)</summary>
    function GetActiveAlerts: TArray<TAlertRule>;
    /// <summary>Acknowledge alert</summary>
    procedure AcknowledgeAlert(const ARuleId: string);
    /// <summary>Resolve alert manually</summary>
    procedure ResolveAlert(const ARuleId: string);
    
    /// <summary>Export rules to JSON</summary>
    function ExportRules: TJSONArray;
    /// <summary>Import rules from JSON</summary>
    procedure ImportRules(ARules: TJSONArray);
    
    // Configuration
    property EvalIntervalMs: Integer read FEvalIntervalMs write FEvalIntervalMs;
    property MaxBufferSize: Integer read FMaxBufferSize write FMaxBufferSize;
    
    // Events
    property OnAlert: TProc<TAlertEvent> read FOnAlert write FOnAlert;
    property OnAlertResolved: TProc<TAlertEvent> read FOnAlertResolved write FOnAlertResolved;
    property OnActionFailed: TProc<string, TAlertAction, Exception> read FOnActionFailed write FOnActionFailed;
  end;

/// <summary>Global alert manager singleton</summary>
function AlertManager: TAlertManager;
/// <summary>Set global alert manager</summary>
procedure SetAlertManager(AManager: TAlertManager);

/// <summary>Helper to create rules</summary>
function CreateAlertRule(const AId, AName: string): TAlertRule;

implementation

uses
  System.Net.HttpClient, System.Net.URLClient, System.StrUtils, Winapi.Windows;

var
  GAlertManager: TAlertManager = nil;
  GAlertManagerLock: TCriticalSection = nil;

function AlertManager: TAlertManager;
begin
  if GAlertManager = nil then
  begin
    GAlertManagerLock.Enter;
    try
      if GAlertManager = nil then
        GAlertManager := TAlertManager.Create;
    finally
      GAlertManagerLock.Leave;
    end;
  end;
  Result := GAlertManager;
end;

procedure SetAlertManager(AManager: TAlertManager);
begin
  GAlertManagerLock.Enter;
  try
    if Assigned(GAlertManager) and (GAlertManager <> AManager) then
      FreeAndNil(GAlertManager);
    GAlertManager := AManager;
  finally
    GAlertManagerLock.Leave;
  end;
end;

function CreateAlertRule(const AId, AName: string): TAlertRule;
begin
  Result := TAlertRule.Create(AId, AName);
end;

{ TAlertCondition }

class function TAlertCondition.ErrorCount(AThreshold: Integer; AWindowMinutes: Integer): TAlertCondition;
begin
  Result.ConditionType := actErrorCount;
  Result.Threshold := AThreshold;
  Result.TimeWindowMinutes := AWindowMinutes;
  Result.Pattern := '';
  Result.Levels := [llError, llFatal];
  Result.SourceFilter := '';
end;

class function TAlertCondition.ErrorRate(AThreshold: Double; AWindowMinutes: Integer): TAlertCondition;
begin
  Result.ConditionType := actErrorRate;
  Result.Threshold := AThreshold;
  Result.TimeWindowMinutes := AWindowMinutes;
  Result.Pattern := '';
  Result.Levels := [llError, llFatal];
  Result.SourceFilter := '';
end;

class function TAlertCondition.PatternMatch(const APattern: string): TAlertCondition;
begin
  Result.ConditionType := actPatternMatch;
  Result.Threshold := 1;
  Result.TimeWindowMinutes := 5;
  Result.Pattern := APattern;
  SetLength(Result.Levels, 0);
  Result.SourceFilter := '';
end;

class function TAlertCondition.NoLogs(AWindowMinutes: Integer): TAlertCondition;
begin
  Result.ConditionType := actNoLogs;
  Result.Threshold := 0;
  Result.TimeWindowMinutes := AWindowMinutes;
  Result.Pattern := '';
  SetLength(Result.Levels, 0);
  Result.SourceFilter := '';
end;

{ TAlertAction }

class function TAlertAction.Webhook(const AUrl: string): TAlertAction;
begin
  Result.ActionType := aatWebhook;
  Result.WebhookUrl := AUrl;
  Result.WebhookMethod := 'POST';
  SetLength(Result.WebhookHeaders, 0);
  SetLength(Result.EmailTo, 0);
  Result.EmailSubject := '';
  Result.Callback := nil;
end;

class function TAlertAction.Email(const ATo: string; const ASubject: string): TAlertAction;
begin
  Result.ActionType := aatEmail;
  Result.WebhookUrl := '';
  Result.WebhookMethod := '';
  SetLength(Result.WebhookHeaders, 0);
  SetLength(Result.EmailTo, 1);
  Result.EmailTo[0] := ATo;
  Result.EmailSubject := ASubject;
  Result.Callback := nil;
end;

class function TAlertAction.LogAction: TAlertAction;
begin
  Result.ActionType := aatLog;
  Result.WebhookUrl := '';
  Result.WebhookMethod := '';
  SetLength(Result.WebhookHeaders, 0);
  SetLength(Result.EmailTo, 0);
  Result.EmailSubject := '';
  Result.Callback := nil;
end;

{ TAlertEvent }

function TAlertEvent.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('alertId', AlertId);
  Result.AddPair('ruleName', RuleName);
  Result.AddPair('severity', TRttiEnumerationType.GetName(Severity));
  Result.AddPair('state', TRttiEnumerationType.GetName(State));
  Result.AddPair('timestamp', DateToISO8601(Timestamp, False));
  Result.AddPair('message', Message);
  Result.AddPair('matchedLogs', TJSONNumber.Create(MatchedLogs));
  
  if Assigned(Details) then
    Result.AddPair('details', Details.Clone as TJSONObject);
end;

function TAlertEvent.ToString: string;
begin
  Result := Format('[%s] %s - %s: %s (matched: %d)', [
    TRttiEnumerationType.GetName(Severity),
    DateTimeToStr(Timestamp),
    RuleName,
    Message,
    MatchedLogs
  ]);
end;

{ TAlertRule }

constructor TAlertRule.Create(const AId, AName: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
  FDescription := '';
  FEnabled := True;
  FActions := TList<TAlertAction>.Create;
  FSeverity := asWarning;
  FState := asIdle;
  FLastEvaluated := 0;
  FLastFired := 0;
  FFireCount := 0;
  FCooldownMinutes := 5;
  SetLength(FTags, 0);
end;

destructor TAlertRule.Destroy;
begin
  FActions.Free;
  inherited;
end;

function TAlertRule.AddAction(const AAction: TAlertAction): TAlertRule;
begin
  FActions.Add(AAction);
  Result := Self;
end;

function TAlertRule.WithCondition(const ACondition: TAlertCondition): TAlertRule;
begin
  FCondition := ACondition;
  Result := Self;
end;

function TAlertRule.WithSeverity(ASeverity: TAlertSeverity): TAlertRule;
begin
  FSeverity := ASeverity;
  Result := Self;
end;

function TAlertRule.WithCooldown(AMinutes: Integer): TAlertRule;
begin
  FCooldownMinutes := AMinutes;
  Result := Self;
end;

function TAlertRule.WithTags(const ATags: TArray<string>): TAlertRule;
begin
  FTags := ATags;
  Result := Self;
end;

function TAlertRule.Enable: TAlertRule;
begin
  FEnabled := True;
  Result := Self;
end;

function TAlertRule.Disable: TAlertRule;
begin
  FEnabled := False;
  Result := Self;
end;

function TAlertRule.ToJSON: TJSONObject;
var
  ActionsArr, TagsArr: TJSONArray;
  Action: TAlertAction;
  ActionObj: TJSONObject;
  Tag: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('name', FName);
  Result.AddPair('description', FDescription);
  Result.AddPair('enabled', TJSONBool.Create(FEnabled));
  Result.AddPair('severity', TRttiEnumerationType.GetName(FSeverity));
  Result.AddPair('cooldownMinutes', TJSONNumber.Create(FCooldownMinutes));
  Result.AddPair('fireCount', TJSONNumber.Create(FFireCount));
  
  if FLastEvaluated > 0 then
    Result.AddPair('lastEvaluated', DateToISO8601(FLastEvaluated, False));
  if FLastFired > 0 then
    Result.AddPair('lastFired', DateToISO8601(FLastFired, False));
  
  // Condition
  var CondObj := TJSONObject.Create;
  CondObj.AddPair('type', TRttiEnumerationType.GetName(FCondition.ConditionType));
  CondObj.AddPair('threshold', TJSONNumber.Create(FCondition.Threshold));
  CondObj.AddPair('timeWindowMinutes', TJSONNumber.Create(FCondition.TimeWindowMinutes));
  if FCondition.Pattern <> '' then
    CondObj.AddPair('pattern', FCondition.Pattern);
  if FCondition.SourceFilter <> '' then
    CondObj.AddPair('sourceFilter', FCondition.SourceFilter);
  Result.AddPair('condition', CondObj);
  
  // Actions
  ActionsArr := TJSONArray.Create;
  for Action in FActions do
  begin
    ActionObj := TJSONObject.Create;
    ActionObj.AddPair('type', TRttiEnumerationType.GetName(Action.ActionType));
    if Action.WebhookUrl <> '' then
      ActionObj.AddPair('webhookUrl', Action.WebhookUrl);
    if Length(Action.EmailTo) > 0 then
      ActionObj.AddPair('emailTo', Action.EmailTo[0]);
    ActionsArr.AddElement(ActionObj);
  end;
  Result.AddPair('actions', ActionsArr);
  
  // Tags
  TagsArr := TJSONArray.Create;
  for Tag in FTags do
    TagsArr.Add(Tag);
  Result.AddPair('tags', TagsArr);
end;

class function TAlertRule.FromJSON(AJson: TJSONObject): TAlertRule;
begin
  Result := TAlertRule.Create(
    AJson.GetValue<string>('id'),
    AJson.GetValue<string>('name')
  );
  Result.Description := AJson.GetValue<string>('description', '');
  Result.Enabled := AJson.GetValue<Boolean>('enabled', True);
  Result.CooldownMinutes := AJson.GetValue<Integer>('cooldownMinutes', 5);
  // Additional parsing would go here
end;

{ TAlertContext }

constructor TAlertContext.Create;
begin
  inherited Create;
  FLogs := TList<TAggregatedLog>.Create;
  FAnalyzer := TLogAnalyzer.Create;
  FStartTime := 0;
  FEndTime := 0;
end;

destructor TAlertContext.Destroy;
begin
  FAnalyzer.Free;
  FLogs.Free;
  inherited;
end;

procedure TAlertContext.SetLogs(ALogs: TList<TAggregatedLog>);
begin
  FLogs.Clear;
  FLogs.AddRange(ALogs);
  FAnalyzer.SetDataSource(FLogs, False);
end;

procedure TAlertContext.SetTimeRange(AStart, AEnd: TDateTime);
begin
  FStartTime := AStart;
  FEndTime := AEnd;
end;

{ TAlertManager }

constructor TAlertManager.Create;
begin
  inherited Create;
  FRules := TDictionary<string, TAlertRule>.Create;
  FHistory := TList<TAlertHistoryEntry>.Create;
  FLock := TCriticalSection.Create;
  
  FLogBuffer := TList<TAggregatedLog>.Create;
  FLogBufferLock := TCriticalSection.Create;
  
  FStopEvent := TEvent.Create;
  FRunning := False;
  FEvalIntervalMs := 60000; // 1 minute default
  FMaxBufferSize := 10000;
end;

destructor TAlertManager.Destroy;
var
  Rule: TAlertRule;
begin
  Stop;
  
  for Rule in FRules.Values do
    Rule.Free;
  FRules.Free;
  
  FHistory.Free;
  FLogBuffer.Free;
  FLogBufferLock.Free;
  FLock.Free;
  FStopEvent.Free;
  inherited;
end;

procedure TAlertManager.Start;
begin
  if FRunning then Exit;
  
  FRunning := True;
  FStopEvent.ResetEvent;
  
  FEvalThread := TThread.CreateAnonymousThread(EvaluationProc);
  FEvalThread.FreeOnTerminate := False;
  FEvalThread.Start;
end;

procedure TAlertManager.Stop;
begin
  if not FRunning then Exit;
  
  FRunning := False;
  FStopEvent.SetEvent;
  
  if Assigned(FEvalThread) then
  begin
    FEvalThread.WaitFor;
    FreeAndNil(FEvalThread);
  end;
end;

procedure TAlertManager.Evaluate;
var
  Context: TAlertContext;
  Rule: TAlertRule;
  LogsCopy: TList<TAggregatedLog>;
begin
  Context := TAlertContext.Create;
  LogsCopy := TList<TAggregatedLog>.Create;
  try
    // Copy logs from buffer
    FLogBufferLock.Enter;
    try
      LogsCopy.AddRange(FLogBuffer);
    finally
      FLogBufferLock.Leave;
    end;
    
    Context.SetLogs(LogsCopy);
    Context.SetTimeRange(IncMinute(Now, -60), Now);
    
    // Evaluate each rule
    FLock.Enter;
    try
      for Rule in FRules.Values do
      begin
        if Rule.Enabled then
          EvaluateRule(Rule, Context);
      end;
    finally
      FLock.Leave;
    end;
  finally
    LogsCopy.Free;
    Context.Free;
  end;
end;

procedure TAlertManager.EvaluationProc;
begin
  while FRunning do
  begin
    if FStopEvent.WaitFor(Cardinal(FEvalIntervalMs)) = wrSignaled then
      Break;
    
    try
      Evaluate;
    except
      on E: Exception do
      begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar('Alert evaluation error: ' + E.Message));
        {$ENDIF}
      end;
    end;
  end;
end;

procedure TAlertManager.EvaluateRule(ARule: TAlertRule; AContext: TAlertContext);
var
  ConditionMet: Boolean;
  Event: TAlertEvent;
  CooldownEnd: TDateTime;
begin
  ARule.LastEvaluated := Now;
  ConditionMet := CheckCondition(ARule, AContext);
  
  if ConditionMet then
  begin
    // Check cooldown
    if ARule.LastFired > 0 then
    begin
      CooldownEnd := IncMinute(ARule.LastFired, ARule.CooldownMinutes);
      if Now < CooldownEnd then
        Exit; // Still in cooldown
    end;
    
    // Fire alert
    ARule.State := asFiring;
    ARule.LastFired := Now;
    Inc(ARule.FFireCount);
    
    Event.AlertId := ARule.Id;
    Event.RuleName := ARule.Name;
    Event.Severity := ARule.Severity;
    Event.State := asFiring;
    Event.Timestamp := Now;
    Event.Message := BuildAlertMessage(ARule, AContext);
    Event.MatchedLogs := AContext.Logs.Count;
    Event.Details := nil;
    
    // Notify
    if Assigned(FOnAlert) then
      FOnAlert(Event);
    
    // Execute actions
    ExecuteActions(ARule, Event);
  end
  else
  begin
    // Check for recovery
    if ARule.State = asFiring then
    begin
      ARule.State := asResolved;
      
      Event.AlertId := ARule.Id;
      Event.RuleName := ARule.Name;
      Event.Severity := ARule.Severity;
      Event.State := asResolved;
      Event.Timestamp := Now;
      Event.Message := Format('Alert resolved: %s', [ARule.Name]);
      Event.MatchedLogs := 0;
      Event.Details := nil;
      
      if Assigned(FOnAlertResolved) then
        FOnAlertResolved(Event);
    end;
  end;
end;

function TAlertManager.CheckCondition(ARule: TAlertRule; AContext: TAlertContext): Boolean;
begin
  case ARule.Condition.ConditionType of
    actErrorCount:
      Result := CheckErrorCountCondition(ARule.Condition, AContext);
    actErrorRate:
      Result := CheckErrorRateCondition(ARule.Condition, AContext);
    actPatternMatch:
      Result := CheckPatternCondition(ARule.Condition, AContext);
    actNoLogs:
      Result := CheckNoLogsCondition(ARule.Condition, AContext);
  else
    Result := False;
  end;
end;

function TAlertManager.CheckErrorCountCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
var
  Log: TAggregatedLog;
  Count: Int64;
  WindowStart: TDateTime;
  Level: TLogLevel;
  LevelMatch: Boolean;
begin
  Count := 0;
  WindowStart := IncMinute(Now, -ACondition.TimeWindowMinutes);
  
  for Log in AContext.Logs do
  begin
    if Log.Timestamp < WindowStart then
      Continue;
      
    // Check level
    if Length(ACondition.Levels) > 0 then
    begin
      LevelMatch := False;
      for Level in ACondition.Levels do
        if Log.Level = Level then
        begin
          LevelMatch := True;
          Break;
        end;
      if not LevelMatch then
        Continue;
    end;
    
    // Check source filter
    if (ACondition.SourceFilter <> '') and not ContainsText(Log.Source, ACondition.SourceFilter) then
      Continue;
    
    Inc(Count);
  end;
  
  Result := Count >= ACondition.Threshold;
end;

function TAlertManager.CheckErrorRateCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
var
  Log: TAggregatedLog;
  TotalCount, ErrorCount: Int64;
  WindowStart: TDateTime;
  Rate: Double;
begin
  TotalCount := 0;
  ErrorCount := 0;
  WindowStart := IncMinute(Now, -ACondition.TimeWindowMinutes);
  
  for Log in AContext.Logs do
  begin
    if Log.Timestamp < WindowStart then
      Continue;
    
    Inc(TotalCount);
    if Log.Level in [llError, llFatal] then
      Inc(ErrorCount);
  end;
  
  if TotalCount > 0 then
    Rate := ErrorCount / TotalCount * 100
  else
    Rate := 0;
  
  Result := Rate >= ACondition.Threshold;
end;

function TAlertManager.CheckPatternCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
var
  Log: TAggregatedLog;
  Regex: TRegEx;
begin
  Result := False;
  
  if ACondition.Pattern = '' then
    Exit;
  
  try
    Regex := TRegEx.Create(ACondition.Pattern, [roIgnoreCase]);
    for Log in AContext.Logs do
    begin
      if Regex.IsMatch(Log.Message) then
      begin
        Result := True;
        Break;
      end;
    end;
  except
    // Invalid regex
  end;
end;

function TAlertManager.CheckNoLogsCondition(const ACondition: TAlertCondition; AContext: TAlertContext): Boolean;
var
  Log: TAggregatedLog;
  WindowStart: TDateTime;
  Count: Int64;
begin
  Count := 0;
  WindowStart := IncMinute(Now, -ACondition.TimeWindowMinutes);
  
  for Log in AContext.Logs do
    if Log.Timestamp >= WindowStart then
      Inc(Count);
  
  Result := Count = 0;
end;

procedure TAlertManager.ExecuteActions(ARule: TAlertRule; const AEvent: TAlertEvent);
var
  Action: TAlertAction;
  ActionsTaken: TList<string>;
  Succeeded, Failed: Integer;
begin
  ActionsTaken := TList<string>.Create;
  try
    Succeeded := 0;
    Failed := 0;
    
    for Action in ARule.Actions do
    begin
      try
        case Action.ActionType of
          aatWebhook:
          begin
            ExecuteWebhook(Action, AEvent);
            ActionsTaken.Add('Webhook: ' + Action.WebhookUrl);
            Inc(Succeeded);
          end;
          aatEmail:
          begin
            // Email would be implemented via interface
            ActionsTaken.Add('Email: ' + String.Join(', ', Action.EmailTo));
            Inc(Succeeded);
          end;
          aatCallback:
          begin
            if Assigned(Action.Callback) then
              Action.Callback(AEvent.ToJSON);
            ActionsTaken.Add('Callback');
            Inc(Succeeded);
          end;
          aatLog:
          begin
            {$IFDEF DEBUG}
            OutputDebugString(PChar('ALERT: ' + AEvent.ToString));
            {$ENDIF}
            ActionsTaken.Add('Log');
            Inc(Succeeded);
          end;
        end;
      except
        on E: Exception do
        begin
          Inc(Failed);
          if Assigned(FOnActionFailed) then
            FOnActionFailed(ARule.Id, Action, E);
        end;
      end;
    end;
    
    AddHistoryEntry(AEvent, ActionsTaken.ToArray, Succeeded, Failed);
  finally
    ActionsTaken.Free;
  end;
end;

procedure TAlertManager.ExecuteWebhook(const AAction: TAlertAction; const AEvent: TAlertEvent);
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  Content: TStringStream;
  Json: TJSONObject;
begin
  HttpClient := THTTPClient.Create;
  try
    HttpClient.ConnectionTimeout := 30000;
    HttpClient.ResponseTimeout := 30000;
    
    Json := AEvent.ToJSON;
    try
      Content := TStringStream.Create(Json.ToString, TEncoding.UTF8);
      try
        Response := HttpClient.Post(AAction.WebhookUrl, Content, nil,
          [TNameValuePair.Create('Content-Type', 'application/json')]);
        
        if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
          raise EAlertException.CreateFmt('Webhook failed: %d %s',
            [Response.StatusCode, Response.StatusText]);
      finally
        Content.Free;
      end;
    finally
      Json.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

function TAlertManager.BuildAlertMessage(ARule: TAlertRule; AContext: TAlertContext): string;
var
  Stats: TLogStats;
begin
  Stats := AContext.Analyzer.GetStats;
  
  case ARule.Condition.ConditionType of
    actErrorCount:
      Result := Format('%s: %d errors in last %d minutes (threshold: %.0f)', [
        ARule.Name, Stats.ErrorCount + Stats.FatalCount,
        ARule.Condition.TimeWindowMinutes, ARule.Condition.Threshold
      ]);
    actErrorRate:
      Result := Format('%s: %.1f%% error rate in last %d minutes (threshold: %.1f%%)', [
        ARule.Name, Stats.ErrorRate * 100,
        ARule.Condition.TimeWindowMinutes, ARule.Condition.Threshold
      ]);
    actPatternMatch:
      Result := Format('%s: Pattern "%s" matched', [ARule.Name, ARule.Condition.Pattern]);
    actNoLogs:
      Result := Format('%s: No logs received in last %d minutes', [
        ARule.Name, ARule.Condition.TimeWindowMinutes
      ]);
  else
    Result := Format('%s: Alert triggered', [ARule.Name]);
  end;
end;

procedure TAlertManager.AddHistoryEntry(const AEvent: TAlertEvent; const AActions: TArray<string>;
  ASucceeded, AFailed: Integer);
var
  Entry: TAlertHistoryEntry;
begin
  Entry.Event := AEvent;
  Entry.ActionsTaken := AActions;
  Entry.ActionsSucceeded := ASucceeded;
  Entry.ActionsFailed := AFailed;
  
  FLock.Enter;
  try
    FHistory.Add(Entry);
    
    // Keep last 1000 entries
    while FHistory.Count > 1000 do
      FHistory.Delete(0);
  finally
    FLock.Leave;
  end;
end;

procedure TAlertManager.AddRule(ARule: TAlertRule);
begin
  FLock.Enter;
  try
    if FRules.ContainsKey(ARule.Id) then
      FRules[ARule.Id].Free;
    FRules.AddOrSetValue(ARule.Id, ARule);
  finally
    FLock.Leave;
  end;
end;

procedure TAlertManager.RemoveRule(const AId: string);
var
  Rule: TAlertRule;
begin
  FLock.Enter;
  try
    if FRules.TryGetValue(AId, Rule) then
    begin
      FRules.Remove(AId);
      Rule.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.GetRule(const AId: string): TAlertRule;
begin
  FLock.Enter;
  try
    if not FRules.TryGetValue(AId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.HasRule(const AId: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FRules.ContainsKey(AId);
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.GetRuleIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FRules.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.GetRulesByTag(const ATag: string): TArray<TAlertRule>;
var
  Rule: TAlertRule;
  Results: TList<TAlertRule>;
  Tag: string;
begin
  Results := TList<TAlertRule>.Create;
  try
    FLock.Enter;
    try
      for Rule in FRules.Values do
        for Tag in Rule.Tags do
          if SameText(Tag, ATag) then
          begin
            Results.Add(Rule);
            Break;
          end;
    finally
      FLock.Leave;
    end;
    Result := Results.ToArray;
  finally
    Results.Free;
  end;
end;

procedure TAlertManager.PushLog(const ALog: TAggregatedLog);
begin
  FLogBufferLock.Enter;
  try
    if FLogBuffer.Count < FMaxBufferSize then
      FLogBuffer.Add(ALog);
  finally
    FLogBufferLock.Leave;
  end;
end;

procedure TAlertManager.PushLogs(const ALogs: TArray<TAggregatedLog>);
var
  Log: TAggregatedLog;
begin
  FLogBufferLock.Enter;
  try
    for Log in ALogs do
      if FLogBuffer.Count < FMaxBufferSize then
        FLogBuffer.Add(Log);
  finally
    FLogBufferLock.Leave;
  end;
end;

function TAlertManager.GetHistory(ALimit: Integer): TArray<TAlertHistoryEntry>;
var
  I, StartIdx: Integer;
begin
  FLock.Enter;
  try
    StartIdx := FHistory.Count - ALimit;
    if StartIdx < 0 then
      StartIdx := 0;
    
    SetLength(Result, FHistory.Count - StartIdx);
    for I := StartIdx to FHistory.Count - 1 do
      Result[I - StartIdx] := FHistory[I];
  finally
    FLock.Leave;
  end;
end;

procedure TAlertManager.ClearHistory;
begin
  FLock.Enter;
  try
    FHistory.Clear;
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.GetActiveAlerts: TArray<TAlertRule>;
var
  Rule: TAlertRule;
  Results: TList<TAlertRule>;
begin
  Results := TList<TAlertRule>.Create;
  try
    FLock.Enter;
    try
      for Rule in FRules.Values do
        if Rule.State = asFiring then
          Results.Add(Rule);
    finally
      FLock.Leave;
    end;
    Result := Results.ToArray;
  finally
    Results.Free;
  end;
end;

procedure TAlertManager.AcknowledgeAlert(const ARuleId: string);
var
  Rule: TAlertRule;
begin
  FLock.Enter;
  try
    if FRules.TryGetValue(ARuleId, Rule) then
      Rule.State := asRecovering;
  finally
    FLock.Leave;
  end;
end;

procedure TAlertManager.ResolveAlert(const ARuleId: string);
var
  Rule: TAlertRule;
begin
  FLock.Enter;
  try
    if FRules.TryGetValue(ARuleId, Rule) then
      Rule.State := asResolved;
  finally
    FLock.Leave;
  end;
end;

function TAlertManager.ExportRules: TJSONArray;
var
  Rule: TAlertRule;
begin
  Result := TJSONArray.Create;
  FLock.Enter;
  try
    for Rule in FRules.Values do
      Result.AddElement(Rule.ToJSON);
  finally
    FLock.Leave;
  end;
end;

procedure TAlertManager.ImportRules(ARules: TJSONArray);
var
  I: Integer;
  RuleJson: TJSONObject;
  Rule: TAlertRule;
begin
  for I := 0 to ARules.Count - 1 do
  begin
    RuleJson := ARules.Items[I] as TJSONObject;
    Rule := TAlertRule.FromJSON(RuleJson);
    AddRule(Rule);
  end;
end;

initialization
  GAlertManagerLock := TCriticalSection.Create;

finalization
  FreeAndNil(GAlertManager);
  FreeAndNil(GAlertManagerLock);

end.
