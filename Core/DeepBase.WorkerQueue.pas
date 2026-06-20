unit DeepBase.WorkerQueue;

{*******************************************************************************
  DeepBase Worker Queue
  A background job processing system with:
  - Priority-based job scheduling
  - Configurable retry policies with exponential backoff
  - Concurrency control (max workers, job limits)
  - Job persistence (memory, file, database)
  - Job dependencies and chaining
  - Delayed/scheduled jobs
  - Dead letter queue for failed jobs
  - Progress tracking and callbacks
  - Graceful shutdown and job recovery
  
  Author: DeepBase Team
  Created: 2025-11-28
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Generics.Defaults, System.SyncObjs, System.JSON, System.IOUtils,
  System.DateUtils, System.Variants, System.Threading,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Constants;

type
  EWorkerQueueException = class(Exception);

  TJobId = string;
  
  /// <summary>Job status</summary>
  TJobStatus = (
    jsPending,      // Waiting to be processed
    jsScheduled,    // Scheduled for future execution
    jsRunning,      // Currently being processed
    jsCompleted,    // Successfully completed
    jsFailed,       // Failed after all retries
    jsCancelled,    // Cancelled by user
    jsRetrying,     // Waiting for retry
    jsDeadLetter    // Moved to dead letter queue
  );

  /// <summary>Job priority</summary>
  TJobPriority = (jpLowest, jpLow, jpNormal, jpHigh, jpHighest, jpCritical);

  /// <summary>Retry strategy</summary>
  TRetryStrategy = (
    rsNone,           // No retry
    rsImmediate,      // Retry immediately
    rsFixed,          // Fixed delay between retries
    rsExponential,    // Exponential backoff
    rsLinear          // Linear backoff
  );

  TJobData = TJSONObject;
  
  TJob = class;
  TWorkerQueue = class;
  
  /// <summary>Job handler procedure</summary>
  TJobHandler = reference to procedure(const AJob: TJob);
  
  /// <summary>Job progress callback</summary>
  TJobProgressCallback = reference to procedure(const AJobId: TJobId; AProgress: Integer; const AMessage: string);
  
  /// <summary>Job completion callback</summary>
  TJobCompletionCallback = reference to procedure(const AJobId: TJobId; ASuccess: Boolean; const AResult: string);

  /// <summary>Retry policy configuration</summary>
  TRetryPolicy = class
  private
    FStrategy: TRetryStrategy;
    FMaxRetries: Integer;
    FInitialDelay: Integer;  // milliseconds
    FMaxDelay: Integer;      // milliseconds
    FMultiplier: Double;
    FJitterFactor: Double;
  public
    constructor Create;
    
    /// <summary>Calculate delay for given attempt</summary>
    function GetDelay(AAttempt: Integer): Integer;
    
    /// <summary>Create no retry policy</summary>
    class function None: TRetryPolicy;
    /// <summary>Create immediate retry policy</summary>
    class function Immediate(AMaxRetries: Integer): TRetryPolicy;
    /// <summary>Create fixed delay policy</summary>
    class function Fixed(AMaxRetries: Integer; ADelayMs: Integer): TRetryPolicy;
    /// <summary>Create exponential backoff policy</summary>
    class function Exponential(AMaxRetries: Integer; AInitialDelayMs: Integer; AMaxDelayMs: Integer = 60000): TRetryPolicy;
    /// <summary>Create linear backoff policy</summary>
    class function Linear(AMaxRetries: Integer; ADelayIncrementMs: Integer): TRetryPolicy;
    
    property Strategy: TRetryStrategy read FStrategy write FStrategy;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
    property InitialDelay: Integer read FInitialDelay write FInitialDelay;
    property MaxDelay: Integer read FMaxDelay write FMaxDelay;
    property Multiplier: Double read FMultiplier write FMultiplier;
    property JitterFactor: Double read FJitterFactor write FJitterFactor;
  end;

  /// <summary>Job execution result</summary>
  TJobResult = record
    Success: Boolean;
    ResultData: string;
    ErrorMessage: string;
    ExecutionTime: Integer;  // milliseconds
    
    class function CreateSuccess(const AResult: string = ''): TJobResult; static;
    class function CreateFailure(const AError: string): TJobResult; static;
  end;

  /// <summary>Job definition</summary>
  TJob = class
  private
    FId: TJobId;
    FJobType: string;
    FData: TJobData;
    FPriority: TJobPriority;
    FStatus: TJobStatus;
    FProgress: Integer;
    FProgressMessage: string;
    FRetryPolicy: TRetryPolicy;
    FAttempt: Integer;
    FMaxAttempts: Integer;
    FCreatedAt: TDateTime;
    FScheduledAt: TDateTime;
    FStartedAt: TDateTime;
    FCompletedAt: TDateTime;
    FNextRetryAt: TDateTime;
    FTimeout: Integer;
    FResult: TJobResult;
    FTags: TArray<string>;
    FDependencies: TArray<TJobId>;
    FMetadata: TDictionary<string, string>;
    FQueue: TWorkerQueue;
    FOnProgress: TJobProgressCallback;
    FOnCompletion: TJobCompletionCallback;
    
    function GetDataValue(const AKey: string): Variant;
    procedure SetDataValue(const AKey: string; const AValue: Variant);
  public
    constructor Create(const AJobType: string);
    destructor Destroy; override;
    
    /// <summary>Generate unique job ID</summary>
    class function GenerateId: TJobId;
    
    /// <summary>Set job data</summary>
    function WithData(const AKey: string; const AValue: Variant): TJob; overload;
    function WithData(AData: TJobData): TJob; overload;
    
    /// <summary>Set priority</summary>
    function WithPriority(APriority: TJobPriority): TJob;
    
    /// <summary>Set retry policy</summary>
    function WithRetryPolicy(APolicy: TRetryPolicy): TJob;
    
    /// <summary>Schedule for future execution</summary>
    function ScheduleAt(ATime: TDateTime): TJob;
    function DelayFor(ASeconds: Integer): TJob;
    
    /// <summary>Set timeout</summary>
    function WithTimeout(ATimeoutMs: Integer): TJob;
    
    /// <summary>Add tag</summary>
    function WithTag(const ATag: string): TJob;
    
    /// <summary>Add dependency</summary>
    function DependsOn(const AJobId: TJobId): TJob;
    
    /// <summary>Set metadata</summary>
    function WithMetadata(const AKey, AValue: string): TJob;
    
    /// <summary>Set progress callback</summary>
    function OnProgress(ACallback: TJobProgressCallback): TJob;
    
    /// <summary>Set completion callback</summary>
    function OnComplete(ACallback: TJobCompletionCallback): TJob;
    
    /// <summary>Report progress</summary>
    procedure ReportProgress(AProgress: Integer; const AMessage: string = '');
    
    /// <summary>Check if can retry</summary>
    function CanRetry: Boolean;
    
    /// <summary>Prepare for retry</summary>
    procedure PrepareRetry;
    
    /// <summary>Create from JSON</summary>
    class function FromJSON(AJSON: TJSONObject): TJob;
    /// <summary>Export to JSON</summary>
    function ToJSON: TJSONObject;
    
    property Id: TJobId read FId;
    property JobType: string read FJobType;
    property Data: TJobData read FData;
    property DataValue[const AKey: string]: Variant read GetDataValue write SetDataValue;
    property Priority: TJobPriority read FPriority write FPriority;
    property Status: TJobStatus read FStatus write FStatus;
    property Progress: Integer read FProgress;
    property ProgressMessage: string read FProgressMessage;
    property RetryPolicy: TRetryPolicy read FRetryPolicy;
    property Attempt: Integer read FAttempt;
    property MaxAttempts: Integer read FMaxAttempts write FMaxAttempts;
    property CreatedAt: TDateTime read FCreatedAt;
    property ScheduledAt: TDateTime read FScheduledAt write FScheduledAt;
    property StartedAt: TDateTime read FStartedAt write FStartedAt;
    property CompletedAt: TDateTime read FCompletedAt write FCompletedAt;
    property NextRetryAt: TDateTime read FNextRetryAt write FNextRetryAt;
    property Timeout: Integer read FTimeout write FTimeout;
    property Result: TJobResult read FResult write FResult;
    property Tags: TArray<string> read FTags;
    property Dependencies: TArray<TJobId> read FDependencies;
    property Metadata: TDictionary<string, string> read FMetadata;
    property Queue: TWorkerQueue read FQueue write FQueue;
  end;

  /// <summary>Worker thread</summary>
  TWorkerThread = class(TThread)
  private
    FQueue: TWorkerQueue;
    FCurrentJob: TJob;
    FWorkerId: Integer;
    FIdle: Boolean;
    FProcessedCount: Integer;
    FErrorCount: Integer;
    FStartedAt: TDateTime;
  protected
    procedure Execute; override;
  public
    constructor Create(AQueue: TWorkerQueue; AWorkerId: Integer);
    
    property WorkerId: Integer read FWorkerId;
    property CurrentJob: TJob read FCurrentJob;
    property IsIdle: Boolean read FIdle;
    property ProcessedCount: Integer read FProcessedCount;
    property ErrorCount: Integer read FErrorCount;
    property StartedAt: TDateTime read FStartedAt;
  end;

  /// <summary>Queue statistics</summary>
  TQueueStats = record
    TotalJobs: Integer;
    PendingJobs: Integer;
    RunningJobs: Integer;
    CompletedJobs: Integer;
    FailedJobs: Integer;
    DeadLetterJobs: Integer;
    ActiveWorkers: Integer;
    IdleWorkers: Integer;
    TotalProcessed: Integer;
    TotalErrors: Integer;
    AverageProcessingTime: Double;
    Uptime: TDateTime;
  end;

  /// <summary>Job storage interface</summary>
  IJobStorage = interface
    ['{A1B2C3D4-5678-9ABC-DEF0-123456789ABC}']
    procedure SaveJob(const AJob: TJob);
    procedure DeleteJob(const AJobId: TJobId);
    function LoadJob(const AJobId: TJobId): TJob;
    function LoadPendingJobs: TObjectList<TJob>;
    function LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
    procedure Clear;
  end;

  /// <summary>Memory job storage</summary>
  TMemoryJobStorage = class(TInterfacedObject, IJobStorage)
  private
    FJobs: TObjectDictionary<TJobId, TJob>;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure SaveJob(const AJob: TJob);
    procedure DeleteJob(const AJobId: TJobId);
    function LoadJob(const AJobId: TJobId): TJob;
    function LoadPendingJobs: TObjectList<TJob>;
    function LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
    procedure Clear;
  end;

  /// <summary>File-based job storage</summary>
  TFileJobStorage = class(TInterfacedObject, IJobStorage)
  private
    FDirectory: string;
    FLock: TCriticalSection;
    FLockFilePath: string;  // BUG-117 FIX: ���̼��ļ���·��

    function GetJobPath(const AJobId: TJobId): string;
    function AcquireFileLock: THandle;  // BUG-117 FIX: ��ȡ���̼��ļ���
    procedure ReleaseFileLock(AHandle: THandle);  // BUG-117 FIX: �ͷŽ��̼��ļ���
  public
    constructor Create(const ADirectory: string);
    destructor Destroy; override;
    
    procedure SaveJob(const AJob: TJob);
    procedure DeleteJob(const AJobId: TJobId);
    function LoadJob(const AJobId: TJobId): TJob;
    function LoadPendingJobs: TObjectList<TJob>;
    function LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
    procedure Clear;
  end;

  /// <summary>Queue event</summary>
  TQueueEvent = procedure(Sender: TObject; const AJob: TJob) of object;
  
  /// <summary>Queue error event</summary>
  TQueueErrorEvent = procedure(Sender: TObject; const AJob: TJob; const AError: Exception) of object;

  /// <summary>Worker queue</summary>
  TWorkerQueue = class
  private
    FName: string;
    FHandlers: TDictionary<string, TJobHandler>;
    FJobs: TObjectDictionary<TJobId, TJob>;
    FPendingQueue: TList<TJob>;
    FWorkers: TObjectList<TWorkerThread>;
    FStorage: IJobStorage;
    FLock: TCriticalSection;
    FJobAvailable: TEvent;
    FShutdownEvent: TEvent;
    FMaxWorkers: Integer;
    FMinWorkers: Integer;  // BUG-056 FIX: ��С�����߳���
    FMaxPendingJobs: Integer;
    FDefaultRetryPolicy: TRetryPolicy;
    FDefaultTimeout: Integer;
    FPaused: Boolean;
    FShuttingDown: Boolean;
    FStartedAt: TDateTime;
    FTotalProcessed: Int64;
    FTotalErrors: Int64;
    FTotalProcessingTime: Int64;
    // BUG-056 FIX: ��̬�̳߳ص�������ֶ�
    FAutoScale: Boolean;
    FScaleUpThreshold: Double;    // ���б��Ͷȳ�����ֵʱ�����߳�
    FScaleDownThreshold: Double;  // �����ʳ�����ֵʱ�����߳�
    FLastScaleTime: TDateTime;
    FScaleCooldownMs: Integer;    // ������ȴʱ��(����)
    
    FOnJobQueued: TQueueEvent;
    FOnJobStarted: TQueueEvent;
    FOnJobCompleted: TQueueEvent;
    FOnJobFailed: TQueueEvent;
    FOnJobRetrying: TQueueEvent;
    FOnError: TQueueErrorEvent;
    
    function GetNextJob: TJob;
    procedure ProcessJob(AJob: TJob);
    procedure MoveToDeadLetter(AJob: TJob);
    function AreDependenciesMet(const AJob: TJob): Boolean;
    procedure SortPendingQueue;
    procedure CheckAutoScale;  // BUG-056 FIX: ��鲢ִ���Զ�����

    function GetStats: TQueueStats;
    function GetActiveWorkerCount: Integer;
  public
    constructor Create(const AName: string = 'default'; AMaxWorkers: Integer = 4);
    destructor Destroy; override;
    
    /// <summary>Register job handler</summary>
    procedure RegisterHandler(const AJobType: string; AHandler: TJobHandler);
    
    /// <summary>Unregister job handler</summary>
    procedure UnregisterHandler(const AJobType: string);
    
    /// <summary>Create a new job</summary>
    function CreateJob(const AJobType: string): TJob;
    
    /// <summary>Enqueue a job</summary>
    function Enqueue(AJob: TJob): TJobId;
    
    /// <summary>Enqueue job with data</summary>
    function EnqueueJob(const AJobType: string; AData: TJobData = nil): TJobId;
    
    /// <summary>Schedule job for later</summary>
    function Schedule(AJob: TJob; ATime: TDateTime): TJobId;
    
    /// <summary>Get job by ID</summary>
    function GetJob(const AJobId: TJobId): TJob;
    
    /// <summary>Get job status</summary>
    function GetJobStatus(const AJobId: TJobId): TJobStatus;
    
    /// <summary>Cancel a job</summary>
    function CancelJob(const AJobId: TJobId): Boolean;
    
    /// <summary>Retry a failed job</summary>
    function RetryJob(const AJobId: TJobId): Boolean;
    
    /// <summary>Get jobs by status</summary>
    function GetJobsByStatus(AStatus: TJobStatus): TArray<TJob>;
    
    /// <summary>Get jobs by tag</summary>
    function GetJobsByTag(const ATag: string): TArray<TJob>;
    
    /// <summary>Get pending job count</summary>
    function GetPendingCount: Integer;
    
    /// <summary>Clear completed jobs</summary>
    procedure ClearCompletedJobs;
    
    /// <summary>Clear all jobs</summary>
    procedure ClearAllJobs;
    
    /// <summary>Start processing</summary>
    procedure Start;
    
    /// <summary>Stop processing.
    /// AWaitForCompletion=True waits for worker threads to exit (default).
    /// Note: this terminates workers immediately and DOES NOT drain pending jobs.
    /// To drain pending jobs first, call DrainAndStop instead.</summary>
    procedure Stop(AWaitForCompletion: Boolean = True);

    /// <summary>Drain pending jobs then stop. Waits for queued jobs to be
    /// processed (up to ATimeoutMs), then stops worker threads.
    /// Returns True if all jobs drained, False if timed out.
    /// ATimeoutMs = -1 means wait indefinitely.</summary>
    function DrainAndStop(ATimeoutMs: Integer = 30000): Boolean;
    
    /// <summary>Pause processing</summary>
    procedure Pause;
    
    /// <summary>Resume processing</summary>
    procedure Resume;
    
    /// <summary>Wait for all jobs to complete</summary>
    procedure WaitForCompletion(ATimeoutMs: Integer = -1);
    
    /// <summary>Scale workers</summary>
    procedure SetWorkerCount(ACount: Integer);
    
    /// <summary>Load jobs from storage</summary>
    procedure LoadFromStorage;
    
    /// <summary>Save jobs to storage</summary>
    procedure SaveToStorage;
    
    property Name: string read FName;
    property MaxWorkers: Integer read FMaxWorkers write FMaxWorkers;
    property MinWorkers: Integer read FMinWorkers write FMinWorkers;  // BUG-056 FIX
    property MaxPendingJobs: Integer read FMaxPendingJobs write FMaxPendingJobs;
    property DefaultRetryPolicy: TRetryPolicy read FDefaultRetryPolicy write FDefaultRetryPolicy;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
    property Storage: IJobStorage read FStorage write FStorage;
    property IsPaused: Boolean read FPaused;
    property IsShuttingDown: Boolean read FShuttingDown;
    property Stats: TQueueStats read GetStats;
    property ActiveWorkerCount: Integer read GetActiveWorkerCount;
    // BUG-056 FIX: ��̬�̳߳ص�������
    property AutoScale: Boolean read FAutoScale write FAutoScale;
    property ScaleUpThreshold: Double read FScaleUpThreshold write FScaleUpThreshold;
    property ScaleDownThreshold: Double read FScaleDownThreshold write FScaleDownThreshold;
    property ScaleCooldownMs: Integer read FScaleCooldownMs write FScaleCooldownMs;
    
    property OnJobQueued: TQueueEvent read FOnJobQueued write FOnJobQueued;
    property OnJobStarted: TQueueEvent read FOnJobStarted write FOnJobStarted;
    property OnJobCompleted: TQueueEvent read FOnJobCompleted write FOnJobCompleted;
    property OnJobFailed: TQueueEvent read FOnJobFailed write FOnJobFailed;
    property OnJobRetrying: TQueueEvent read FOnJobRetrying write FOnJobRetrying;
    property OnError: TQueueErrorEvent read FOnError write FOnError;
  end;

  /// <summary>Job builder</summary>
  TJobBuilder = class
  private
    FJob: TJob;
  public
    constructor Create(const AJobType: string);
    
    function Data(const AKey: string; const AValue: Variant): TJobBuilder; overload;
    function Data(AData: TJobData): TJobBuilder; overload;
    function Priority(APriority: TJobPriority): TJobBuilder;
    function Retry(AMaxRetries: Integer): TJobBuilder;
    function RetryPolicy(APolicy: TRetryPolicy): TJobBuilder;
    function ScheduleAt(ATime: TDateTime): TJobBuilder;
    function DelayFor(ASeconds: Integer): TJobBuilder;
    function Timeout(ATimeoutMs: Integer): TJobBuilder;
    function Tag(const ATag: string): TJobBuilder;
    function DependsOn(const AJobId: TJobId): TJobBuilder;
    function Metadata(const AKey, AValue: string): TJobBuilder;
    function OnProgress(ACallback: TJobProgressCallback): TJobBuilder;
    function OnComplete(ACallback: TJobCompletionCallback): TJobBuilder;
    
    function Build: TJob;
  end;

  /// <summary>Global worker queue helper</summary>
  TWorkerQueues = class
  private
    class var FQueues: TObjectDictionary<string, TWorkerQueue>;
    class var FDefaultQueue: TWorkerQueue;
    class var FLock: TCriticalSection;
  public
    class constructor Create;
    class destructor Destroy;
    
    /// <summary>Get or create queue by name</summary>
    class function GetQueue(const AName: string = 'default'): TWorkerQueue;
    
    /// <summary>Register job handler on default queue</summary>
    class procedure RegisterHandler(const AJobType: string; AHandler: TJobHandler);
    
    /// <summary>Enqueue job on default queue</summary>
    class function Enqueue(AJob: TJob): TJobId; overload;
    class function Enqueue(const AJobType: string; AData: TJobData = nil): TJobId; overload;
    
    /// <summary>Create job builder</summary>
    class function Job(const AJobType: string): TJobBuilder;
    
    /// <summary>Start all queues</summary>
    class procedure StartAll;
    
    /// <summary>Stop all queues</summary>
    class procedure StopAll(AWaitForCompletion: Boolean = True);
    
    /// <summary>Default queue</summary>
    class property Default: TWorkerQueue read FDefaultQueue;
  end;

/// <summary>Global worker queue</summary>
function WorkerQueue(const AName: string = 'default'): TWorkerQueue;

implementation

uses
  System.Math;

var
  GDefaultQueue: TWorkerQueue = nil;
  GQueueLock: TCriticalSection = nil;

function WorkerQueue(const AName: string): TWorkerQueue;
begin
  Result := TWorkerQueues.GetQueue(AName);
end;

{ TRetryPolicy }

constructor TRetryPolicy.Create;
begin
  inherited;
  FStrategy := rsNone;
  FMaxRetries := 0;
  FInitialDelay := 1000;
  FMaxDelay := 60000;
  FMultiplier := 2.0;
  FJitterFactor := 0.1;
end;

function TRetryPolicy.GetDelay(AAttempt: Integer): Integer;
var
  LDelay: Double;
  LJitter: Double;
begin
  case FStrategy of
    rsNone:
      Result := 0;
      
    rsImmediate:
      Result := 0;
      
    rsFixed:
      Result := FInitialDelay;
      
    rsExponential:
      begin
        LDelay := FInitialDelay * Power(FMultiplier, AAttempt - 1);
        Result := Min(Round(LDelay), FMaxDelay);
      end;
      
    rsLinear:
      begin
        LDelay := FInitialDelay * AAttempt;
        Result := Min(Round(LDelay), FMaxDelay);
      end;
  else
    Result := 0;
  end;
  
  // Add jitter
  if (Result > 0) and (FJitterFactor > 0) then
  begin
    LJitter := Result * FJitterFactor * (Random - 0.5) * 2;
    Result := Max(0, Result + Round(LJitter));
  end;
end;

class function TRetryPolicy.None: TRetryPolicy;
begin
  Result := TRetryPolicy.Create;
  Result.FStrategy := rsNone;
  Result.FMaxRetries := 0;
end;

class function TRetryPolicy.Immediate(AMaxRetries: Integer): TRetryPolicy;
begin
  Result := TRetryPolicy.Create;
  Result.FStrategy := rsImmediate;
  Result.FMaxRetries := AMaxRetries;
end;

class function TRetryPolicy.Fixed(AMaxRetries: Integer; ADelayMs: Integer): TRetryPolicy;
begin
  Result := TRetryPolicy.Create;
  Result.FStrategy := rsFixed;
  Result.FMaxRetries := AMaxRetries;
  Result.FInitialDelay := ADelayMs;
  Result.FJitterFactor := 0;
end;

class function TRetryPolicy.Exponential(AMaxRetries: Integer; AInitialDelayMs: Integer;
  AMaxDelayMs: Integer): TRetryPolicy;
begin
  Result := TRetryPolicy.Create;
  Result.FStrategy := rsExponential;
  Result.FMaxRetries := AMaxRetries;
  Result.FInitialDelay := AInitialDelayMs;
  Result.FMaxDelay := AMaxDelayMs;
end;

class function TRetryPolicy.Linear(AMaxRetries: Integer; ADelayIncrementMs: Integer): TRetryPolicy;
begin
  Result := TRetryPolicy.Create;
  Result.FStrategy := rsLinear;
  Result.FMaxRetries := AMaxRetries;
  Result.FInitialDelay := ADelayIncrementMs;
end;

{ TJobResult }

class function TJobResult.CreateSuccess(const AResult: string): TJobResult;
begin
  Result.Success := True;
  Result.ResultData := AResult;
  Result.ErrorMessage := '';
end;

class function TJobResult.CreateFailure(const AError: string): TJobResult;
begin
  Result.Success := False;
  Result.ResultData := '';
  Result.ErrorMessage := AError;
end;

{ TJob }

constructor TJob.Create(const AJobType: string);
begin
  inherited Create;
  FId := GenerateId;
  FJobType := AJobType;
  FData := TJSONObject.Create;
  FPriority := jpNormal;
  FStatus := jsPending;
  FProgress := 0;
  FRetryPolicy := TRetryPolicy.Create;
  FAttempt := 0;
  FMaxAttempts := 1;
  FCreatedAt := Now;
  FScheduledAt := 0;
  FTimeout := 0;
  FMetadata := TDictionary<string, string>.Create;
end;

destructor TJob.Destroy;
begin
  FreeAndNil(FMetadata);
  FreeAndNil(FRetryPolicy);
  FreeAndNil(FData);
  inherited;
end;

class function TJob.GenerateId: TJobId;
var
  LGUID: TGUID;
begin
  CreateGUID(LGUID);
  Result := 'job_' + Copy(GUIDToString(LGUID), 2, 36).Replace('-', '', [rfReplaceAll]).ToLower;
end;

function TJob.GetDataValue(const AKey: string): Variant;
var
  LValue: TJSONValue;
begin
  if FData.TryGetValue(AKey, LValue) then
  begin
    if LValue is TJSONNumber then
      Result := TJSONNumber(LValue).AsDouble
    else if LValue is TJSONBool then
      Result := TJSONBool(LValue).AsBoolean
    else
      Result := LValue.Value;
  end
  else
    Result := Null;
end;

procedure TJob.SetDataValue(const AKey: string; const AValue: Variant);
begin
  if VarIsNull(AValue) then
    FData.RemovePair(AKey)
  else if VarIsNumeric(AValue) then
    FData.AddPair(AKey, TJSONNumber.Create(Double(AValue)))
  else if VarIsType(AValue, varBoolean) then
    FData.AddPair(AKey, TJSONBool.Create(Boolean(AValue)))
  else
    FData.AddPair(AKey, VarToStr(AValue));
end;

function TJob.WithData(const AKey: string; const AValue: Variant): TJob;
begin
  SetDataValue(AKey, AValue);
  Result := Self;
end;

function TJob.WithData(AData: TJobData): TJob;
var
  LPair: TJSONPair;
begin
  if Assigned(AData) then
  begin
    for LPair in AData do
      FData.AddPair(TJSONPair(LPair.Clone));
  end;
  Result := Self;
end;

function TJob.WithPriority(APriority: TJobPriority): TJob;
begin
  FPriority := APriority;
  Result := Self;
end;

function TJob.WithRetryPolicy(APolicy: TRetryPolicy): TJob;
begin
  FreeAndNil(FRetryPolicy);
  FRetryPolicy := APolicy;
  FMaxAttempts := APolicy.MaxRetries + 1;
  Result := Self;
end;

function TJob.ScheduleAt(ATime: TDateTime): TJob;
begin
  FScheduledAt := ATime;
  FStatus := jsScheduled;
  Result := Self;
end;

function TJob.DelayFor(ASeconds: Integer): TJob;
begin
  Result := ScheduleAt(IncSecond(Now, ASeconds));
end;

function TJob.WithTimeout(ATimeoutMs: Integer): TJob;
begin
  FTimeout := ATimeoutMs;
  Result := Self;
end;

function TJob.WithTag(const ATag: string): TJob;
begin
  SetLength(FTags, Length(FTags) + 1);
  FTags[High(FTags)] := ATag;
  Result := Self;
end;

function TJob.DependsOn(const AJobId: TJobId): TJob;
begin
  SetLength(FDependencies, Length(FDependencies) + 1);
  FDependencies[High(FDependencies)] := AJobId;
  Result := Self;
end;

function TJob.WithMetadata(const AKey, AValue: string): TJob;
begin
  FMetadata.AddOrSetValue(AKey, AValue);
  Result := Self;
end;

function TJob.OnProgress(ACallback: TJobProgressCallback): TJob;
begin
  FOnProgress := ACallback;
  Result := Self;
end;

function TJob.OnComplete(ACallback: TJobCompletionCallback): TJob;
begin
  FOnCompletion := ACallback;
  Result := Self;
end;

procedure TJob.ReportProgress(AProgress: Integer; const AMessage: string);
begin
  FProgress := AProgress;
  FProgressMessage := AMessage;
  
  if Assigned(FOnProgress) then
    FOnProgress(FId, AProgress, AMessage);
end;

function TJob.CanRetry: Boolean;
begin
  Result := (FAttempt < FMaxAttempts) and (FRetryPolicy.Strategy <> rsNone);
end;

procedure TJob.PrepareRetry;
var
  LDelay: Integer;
begin
  Inc(FAttempt);
  FStatus := jsRetrying;
  FProgress := 0;
  FProgressMessage := '';
  
  LDelay := FRetryPolicy.GetDelay(FAttempt);
  if LDelay > 0 then
    FNextRetryAt := IncMilliSecond(Now, LDelay)
  else
    FNextRetryAt := Now;
end;

class function TJob.FromJSON(AJSON: TJSONObject): TJob;
var
  LPriorityStr, LStatusStr, LJobType, LJobId: string;
  LTags, LDeps: TJSONArray;
  I: Integer;
  LData: TJSONObject;
  LMetadata: TJSONObject;
  LPair: TJSONPair;
begin
  // BUG-107 FIX: ����������֤
  if AJSON = nil then
    raise EWorkerQueueException.Create('Invalid JSON: nil object');
  
  // ��֤��Ҫ�ֶ�
  LJobType := AJSON.GetValue<string>('jobType', '');
  if LJobType = '' then
    raise EWorkerQueueException.Create('Invalid JSON: missing jobType');
  
  // ��֤jobType���ȣ���ֹ����������
  if Length(LJobType) > 256 then
    raise EWorkerQueueException.Create('Invalid JSON: jobType too long');
  
  Result := TJob.Create(LJobType);
  
  // ��֤������ID
  LJobId := AJSON.GetValue<string>('id', Result.FId);
  if Length(LJobId) > 256 then
  begin
    Result.Free;
    raise EWorkerQueueException.Create('Invalid JSON: id too long');
  end;
  Result.FId := LJobId;
  
  if AJSON.TryGetValue<TJSONObject>('data', LData) then
  begin
    FreeAndNil(Result.FData);
    Result.FData := LData.Clone as TJSONObject;
  end;
    
  LPriorityStr := AJSON.GetValue<string>('priority', 'normal');
  if LPriorityStr = 'lowest' then Result.FPriority := jpLowest
  else if LPriorityStr = 'low' then Result.FPriority := jpLow
  else if LPriorityStr = 'high' then Result.FPriority := jpHigh
  else if LPriorityStr = 'highest' then Result.FPriority := jpHighest
  else if LPriorityStr = 'critical' then Result.FPriority := jpCritical
  else Result.FPriority := jpNormal;
  
  LStatusStr := AJSON.GetValue<string>('status', 'pending');
  if LStatusStr = 'scheduled' then Result.FStatus := jsScheduled
  else if LStatusStr = 'running' then Result.FStatus := jsRunning
  else if LStatusStr = 'completed' then Result.FStatus := jsCompleted
  else if LStatusStr = 'failed' then Result.FStatus := jsFailed
  else if LStatusStr = 'cancelled' then Result.FStatus := jsCancelled
  else if LStatusStr = 'retrying' then Result.FStatus := jsRetrying
  else if LStatusStr = 'deadletter' then Result.FStatus := jsDeadLetter
  else Result.FStatus := jsPending;
  
  Result.FAttempt := AJSON.GetValue<Integer>('attempt', 0);
  Result.FMaxAttempts := AJSON.GetValue<Integer>('maxAttempts', 1);
  Result.FTimeout := AJSON.GetValue<Integer>('timeout', 0);
  Result.FProgress := AJSON.GetValue<Integer>('progress', 0);
  
  Result.FCreatedAt := ISO8601ToDate(AJSON.GetValue<string>('createdAt', DateToISO8601(Now, False)), False);
  
  if AJSON.TryGetValue<TJSONArray>('tags', LTags) then
  begin
    SetLength(Result.FTags, LTags.Count);
    for I := 0 to LTags.Count - 1 do
      Result.FTags[I] := LTags.Items[I].Value;
  end;
  
  if AJSON.TryGetValue<TJSONArray>('dependencies', LDeps) then
  begin
    SetLength(Result.FDependencies, LDeps.Count);
    for I := 0 to LDeps.Count - 1 do
      Result.FDependencies[I] := LDeps.Items[I].Value;
  end;
  
  if AJSON.TryGetValue<TJSONObject>('metadata', LMetadata) then
  begin
    for LPair in LMetadata do
      Result.FMetadata.AddOrSetValue(LPair.JsonString.Value, LPair.JsonValue.Value);
  end;
end;

function TJob.ToJSON: TJSONObject;
var
  LPriorityStr, LStatusStr: string;
  LTags, LDeps: TJSONArray;
  LMetadata: TJSONObject;
  LPair: TPair<string, string>;
  I: Integer;
begin
  Result := TJSONObject.Create;
  
  Result.AddPair('id', FId);
  Result.AddPair('jobType', FJobType);
  Result.AddPair('data', FData.Clone as TJSONObject);
  
  case FPriority of
    jpLowest: LPriorityStr := 'lowest';
    jpLow: LPriorityStr := 'low';
    jpHigh: LPriorityStr := 'high';
    jpHighest: LPriorityStr := 'highest';
    jpCritical: LPriorityStr := 'critical';
  else
    LPriorityStr := 'normal';
  end;
  Result.AddPair('priority', LPriorityStr);
  
  case FStatus of
    jsPending: LStatusStr := 'pending';
    jsScheduled: LStatusStr := 'scheduled';
    jsRunning: LStatusStr := 'running';
    jsCompleted: LStatusStr := 'completed';
    jsFailed: LStatusStr := 'failed';
    jsCancelled: LStatusStr := 'cancelled';
    jsRetrying: LStatusStr := 'retrying';
    jsDeadLetter: LStatusStr := 'deadletter';
  else
    LStatusStr := 'pending';
  end;
  Result.AddPair('status', LStatusStr);
  
  Result.AddPair('attempt', TJSONNumber.Create(FAttempt));
  Result.AddPair('maxAttempts', TJSONNumber.Create(FMaxAttempts));
  Result.AddPair('timeout', TJSONNumber.Create(FTimeout));
  Result.AddPair('progress', TJSONNumber.Create(FProgress));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt, False));
  
  if FScheduledAt > 0 then
    Result.AddPair('scheduledAt', DateToISO8601(FScheduledAt, False));
  if FStartedAt > 0 then
    Result.AddPair('startedAt', DateToISO8601(FStartedAt, False));
  if FCompletedAt > 0 then
    Result.AddPair('completedAt', DateToISO8601(FCompletedAt, False));
    
  LTags := TJSONArray.Create;
  for I := 0 to High(FTags) do
    LTags.Add(FTags[I]);
  Result.AddPair('tags', LTags);
  
  LDeps := TJSONArray.Create;
  for I := 0 to High(FDependencies) do
    LDeps.Add(FDependencies[I]);
  Result.AddPair('dependencies', LDeps);
  
  LMetadata := TJSONObject.Create;
  for LPair in FMetadata do
    LMetadata.AddPair(LPair.Key, LPair.Value);
  Result.AddPair('metadata', LMetadata);
end;

{ TWorkerThread }

constructor TWorkerThread.Create(AQueue: TWorkerQueue; AWorkerId: Integer);
begin
  inherited Create(True);
  FQueue := AQueue;
  FWorkerId := AWorkerId;
  FIdle := True;
  FProcessedCount := 0;
  FErrorCount := 0;
  FStartedAt := Now;
  FreeOnTerminate := False;
end;

procedure TWorkerThread.Execute;
var
  LJob: TJob;
begin
  while not Terminated do
  begin
    if FQueue.FPaused then
    begin
      Sleep(100);
      Continue;
    end;
    
    // Wait for job or shutdown
    case FQueue.FJobAvailable.WaitFor(100) of
      wrSignaled, wrTimeout:
        begin
          if Terminated or FQueue.FShuttingDown then
            Break;
            
          LJob := FQueue.GetNextJob;
          if Assigned(LJob) then
          begin
            FIdle := False;
            FCurrentJob := LJob;
            try
              FQueue.ProcessJob(LJob);
              Inc(FProcessedCount);
            except
              on E: Exception do
                Inc(FErrorCount);
            end;
            FCurrentJob := nil;
            FIdle := True;
          end;
        end;

      wrAbandoned, wrError:
        Break;
    end;
  end;
end;

{ TMemoryJobStorage }

constructor TMemoryJobStorage.Create;
begin
  inherited;
  // Storage snapshots references; TWorkerQueue.FJobs owns job instances.
  FJobs := TObjectDictionary<TJobId, TJob>.Create([]);
  FLock := TCriticalSection.Create;
end;

destructor TMemoryJobStorage.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FJobs);
  inherited;
end;

procedure TMemoryJobStorage.SaveJob(const AJob: TJob);
begin
  FLock.Enter;
  try
    FJobs.AddOrSetValue(AJob.Id, AJob);
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryJobStorage.DeleteJob(const AJobId: TJobId);
begin
  FLock.Enter;
  try
    FJobs.Remove(AJobId);
  finally
    FLock.Leave;
  end;
end;

function TMemoryJobStorage.LoadJob(const AJobId: TJobId): TJob;
begin
  FLock.Enter;
  try
    if not FJobs.TryGetValue(AJobId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TMemoryJobStorage.LoadPendingJobs: TObjectList<TJob>;
var
  LPair: TPair<TJobId, TJob>;
begin
  Result := TObjectList<TJob>.Create(False);
  FLock.Enter;
  try
    for LPair in FJobs do
    begin
      if LPair.Value.Status in [jsPending, jsScheduled, jsRetrying] then
        Result.Add(LPair.Value);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMemoryJobStorage.LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
var
  LPair: TPair<TJobId, TJob>;
begin
  Result := TObjectList<TJob>.Create(False);
  FLock.Enter;
  try
    for LPair in FJobs do
    begin
      if LPair.Value.Status = AStatus then
        Result.Add(LPair.Value);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TMemoryJobStorage.Clear;
begin
  FLock.Enter;
  try
    FJobs.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TFileJobStorage }

constructor TFileJobStorage.Create(const ADirectory: string);
begin
  inherited Create;
  FDirectory := ADirectory;
  FLock := TCriticalSection.Create;

  if not TDirectory.Exists(FDirectory) then
    TDirectory.CreateDirectory(FDirectory);

  // BUG-117 FIX: ��ʼ�����̼����ļ�·��
  FLockFilePath := TPath.Combine(FDirectory, '.lock');
end;

destructor TFileJobStorage.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TFileJobStorage.GetJobPath(const AJobId: TJobId): string;
begin
  Result := TPath.Combine(FDirectory, AJobId + '.json');
end;

// BUG-117 FIX: ʵ�ֽ��̼��ļ���
function TFileJobStorage.AcquireFileLock: THandle;
{$IFDEF MSWINDOWS}
var
  LRetries: Integer;
begin
  Result := INVALID_HANDLE_VALUE;
  LRetries := 0;

  // ���Ի�ȡ�ļ������������50�Σ�5�룩
  while LRetries < 50 do
  begin
    Result := CreateFile(
      PChar(FLockFilePath),
      GENERIC_READ or GENERIC_WRITE,
      0,  // ����������ռ����
      nil,
      CREATE_ALWAYS,
      FILE_ATTRIBUTE_HIDDEN or FILE_FLAG_DELETE_ON_CLOSE,
      0
    );

    if Result <> INVALID_HANDLE_VALUE then
      Exit;

    Inc(LRetries);
    Sleep(100);  // �ȴ�100ms������
  end;

  // ��ʱ�����޷���ȡ������¼���浫����ִ��
  // �ڵ����̻������ⲻ���Ϊ����
end;
{$ELSE}
begin
  // ��Windowsƽ̨�ݲ�֧�ֽ��̼���
  Result := 0;
end;
{$ENDIF}

procedure TFileJobStorage.ReleaseFileLock(AHandle: THandle);
begin
  {$IFDEF MSWINDOWS}
  if AHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(AHandle);
  {$ENDIF}
end;

procedure TFileJobStorage.SaveJob(const AJob: TJob);
var
  LPath: string;
  LJSON: TJSONObject;
  LFileLock: THandle;
begin
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      LPath := GetJobPath(AJob.Id);
      LJSON := AJob.ToJSON;
      try
        TFile.WriteAllText(LPath, LJSON.Format(2), TEncoding.UTF8);
      finally
        LJSON.Free;
      end;
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

procedure TFileJobStorage.DeleteJob(const AJobId: TJobId);
var
  LPath: string;
  LFileLock: THandle;
begin
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      LPath := GetJobPath(AJobId);
      if TFile.Exists(LPath) then
        TFile.Delete(LPath);
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

function TFileJobStorage.LoadJob(const AJobId: TJobId): TJob;
var
  LPath, LContent: string;
  LJSON: TJSONObject;
  LFileLock: THandle;
begin
  Result := nil;
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      LPath := GetJobPath(AJobId);
      if not TFile.Exists(LPath) then
        Exit;

      LContent := TFile.ReadAllText(LPath, TEncoding.UTF8);
      LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
      if Assigned(LJSON) then
      begin
        try
          Result := TJob.FromJSON(LJSON);
        finally
          LJSON.Free;
        end;
      end;
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

function TFileJobStorage.LoadPendingJobs: TObjectList<TJob>;
var
  LFiles: TArray<string>;
  LFile, LContent: string;
  LJSON: TJSONObject;
  LJob: TJob;
  LFileLock: THandle;
begin
  Result := TObjectList<TJob>.Create(True);
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      if not TDirectory.Exists(FDirectory) then
        Exit;

      LFiles := TDirectory.GetFiles(FDirectory, '*.json');
      for LFile in LFiles do
      begin
        LContent := TFile.ReadAllText(LFile, TEncoding.UTF8);
        LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
        if Assigned(LJSON) then
        begin
          try
            LJob := TJob.FromJSON(LJSON);
            if LJob.Status in [jsPending, jsScheduled, jsRetrying] then
              Result.Add(LJob)
            else
              LJob.Free;
          finally
            LJSON.Free;
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

function TFileJobStorage.LoadJobsByStatus(AStatus: TJobStatus): TObjectList<TJob>;
var
  LFiles: TArray<string>;
  LFile, LContent: string;
  LJSON: TJSONObject;
  LJob: TJob;
  LFileLock: THandle;
begin
  Result := TObjectList<TJob>.Create(True);
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      if not TDirectory.Exists(FDirectory) then
        Exit;

      LFiles := TDirectory.GetFiles(FDirectory, '*.json');
      for LFile in LFiles do
      begin
        LContent := TFile.ReadAllText(LFile, TEncoding.UTF8);
        LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
        if Assigned(LJSON) then
        begin
          try
            LJob := TJob.FromJSON(LJSON);
            if LJob.Status = AStatus then
              Result.Add(LJob)
            else
              LJob.Free;
          finally
            LJSON.Free;
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

procedure TFileJobStorage.Clear;
var
  LFiles: TArray<string>;
  LFile: string;
  LFileLock: THandle;
begin
  // BUG-117 FIX: ʹ�ý��̼��ļ�������
  LFileLock := AcquireFileLock;
  try
    FLock.Enter;
    try
      if TDirectory.Exists(FDirectory) then
      begin
        LFiles := TDirectory.GetFiles(FDirectory, '*.json');
        for LFile in LFiles do
          TFile.Delete(LFile);
      end;
    finally
      FLock.Leave;
    end;
  finally
    ReleaseFileLock(LFileLock);
  end;
end;

{ TWorkerQueue }

constructor TWorkerQueue.Create(const AName: string; AMaxWorkers: Integer);
begin
  inherited Create;
  FName := AName;
  FMaxWorkers := AMaxWorkers;
  FMinWorkers := 1;  // BUG-056 FIX: Ĭ����С1�������߳�
  FMaxPendingJobs := 10000;
  FDefaultTimeout := 300000; // 5 minutes
  FHandlers := TDictionary<string, TJobHandler>.Create;
  FJobs := TObjectDictionary<TJobId, TJob>.Create([doOwnsValues]);
  FPendingQueue := TList<TJob>.Create;
  FWorkers := TObjectList<TWorkerThread>.Create(True);
  FLock := TCriticalSection.Create;
  // BUG-055 FIX: ��Ϊ�ֶ������¼�����ֹ���̳߳������źŶ�ʧ
  // �Զ������¼�(ManualReset=False)ֻ����һ���̺߳�����ã�
  // ���¶������ж����ҵʱ������ҵ�޷�����ʱ����
  FJobAvailable := TEvent.Create(nil, True, False, '');
  FShutdownEvent := TEvent.Create(nil, True, False, '');
  FDefaultRetryPolicy := TRetryPolicy.Exponential(3, 1000, 60000);
  FStorage := TMemoryJobStorage.Create;
  // BUG-056 FIX: ��ʼ����̬�̳߳ص�������ֶ�
  FAutoScale := False;  // Ĭ�Ϲر��Զ�����
  FScaleUpThreshold := 0.8;    // ���б��Ͷȳ���80%ʱ�����߳�
  FScaleDownThreshold := 0.2;  // �����ʳ���80%(�������ʵ���20%)ʱ�����߳�
  FLastScaleTime := 0;
  FScaleCooldownMs := 5000;    // 5����ȴʱ��
end;

destructor TWorkerQueue.Destroy;
begin
  Stop(True);
  FreeAndNil(FDefaultRetryPolicy);
  FreeAndNil(FShutdownEvent);
  FreeAndNil(FJobAvailable);
  FreeAndNil(FLock);
  FreeAndNil(FWorkers);
  FreeAndNil(FPendingQueue);
  FreeAndNil(FJobs);
  FreeAndNil(FHandlers);
  inherited;
end;

procedure TWorkerQueue.RegisterHandler(const AJobType: string; AHandler: TJobHandler);
begin
  FLock.Enter;
  try
    FHandlers.AddOrSetValue(AJobType, AHandler);
  finally
    FLock.Leave;
  end;
end;

procedure TWorkerQueue.UnregisterHandler(const AJobType: string);
begin
  FLock.Enter;
  try
    FHandlers.Remove(AJobType);
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.CreateJob(const AJobType: string): TJob;
begin
  Result := TJob.Create(AJobType);
  Result.FQueue := Self;
  Result.WithRetryPolicy(TRetryPolicy.Create);
  Result.FRetryPolicy.FStrategy := FDefaultRetryPolicy.Strategy;
  Result.FRetryPolicy.FMaxRetries := FDefaultRetryPolicy.MaxRetries;
  Result.FRetryPolicy.FInitialDelay := FDefaultRetryPolicy.InitialDelay;
  Result.FRetryPolicy.FMaxDelay := FDefaultRetryPolicy.MaxDelay;
  Result.FRetryPolicy.FMultiplier := FDefaultRetryPolicy.Multiplier;
  Result.FMaxAttempts := FDefaultRetryPolicy.MaxRetries + 1;
  Result.FTimeout := FDefaultTimeout;
end;

function TWorkerQueue.Enqueue(AJob: TJob): TJobId;
begin
  FLock.Enter;
  try
    if FPendingQueue.Count >= FMaxPendingJobs then
      raise EWorkerQueueException.Create('Queue is full');
      
    AJob.FQueue := Self;
    if AJob.FStatus <> jsScheduled then
      AJob.FStatus := jsPending;
    FJobs.AddOrSetValue(AJob.Id, AJob);
    FPendingQueue.Add(AJob);
    SortPendingQueue;
    
    if Assigned(FStorage) then
      FStorage.SaveJob(AJob);
      
    if Assigned(FOnJobQueued) then
      FOnJobQueued(Self, AJob);
      
    Result := AJob.Id;
    FJobAvailable.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.EnqueueJob(const AJobType: string; AData: TJobData): TJobId;
var
  LJob: TJob;
begin
  LJob := CreateJob(AJobType);
  if Assigned(AData) then
    LJob.WithData(AData);
  Result := Enqueue(LJob);
end;

function TWorkerQueue.Schedule(AJob: TJob; ATime: TDateTime): TJobId;
begin
  AJob.ScheduleAt(ATime);
  Result := Enqueue(AJob);
end;

function TWorkerQueue.GetJob(const AJobId: TJobId): TJob;
begin
  FLock.Enter;
  try
    if not FJobs.TryGetValue(AJobId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.GetJobStatus(const AJobId: TJobId): TJobStatus;
var
  LJob: TJob;
begin
  LJob := GetJob(AJobId);
  if Assigned(LJob) then
    Result := LJob.Status
  else
    Result := jsFailed;
end;

function TWorkerQueue.CancelJob(const AJobId: TJobId): Boolean;
var
  LJob: TJob;
begin
  Result := False;
  FLock.Enter;
  try
    if FJobs.TryGetValue(AJobId, LJob) then
    begin
      if LJob.Status in [jsPending, jsScheduled, jsRetrying] then
      begin
        LJob.FStatus := jsCancelled;
        FPendingQueue.Remove(LJob);
        Result := True;
        
        if Assigned(FStorage) then
          FStorage.SaveJob(LJob);
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.RetryJob(const AJobId: TJobId): Boolean;
var
  LJob: TJob;
begin
  Result := False;
  FLock.Enter;
  try
    if FJobs.TryGetValue(AJobId, LJob) then
    begin
      if LJob.Status in [jsFailed, jsDeadLetter] then
      begin
        LJob.FStatus := jsPending;
        LJob.FAttempt := 0;
        FPendingQueue.Add(LJob);
        SortPendingQueue;
        Result := True;
        
        if Assigned(FStorage) then
          FStorage.SaveJob(LJob);
          
        FJobAvailable.SetEvent;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.GetJobsByStatus(AStatus: TJobStatus): TArray<TJob>;
var
  LList: TList<TJob>;
  LPair: TPair<TJobId, TJob>;
begin
  LList := TList<TJob>.Create;
  try
    FLock.Enter;
    try
      for LPair in FJobs do
      begin
        if LPair.Value.Status = AStatus then
          LList.Add(LPair.Value);
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TWorkerQueue.GetJobsByTag(const ATag: string): TArray<TJob>;
var
  LList: TList<TJob>;
  LPair: TPair<TJobId, TJob>;
  LTagItem: string;
begin
  LList := TList<TJob>.Create;
  try
    FLock.Enter;
    try
      for LPair in FJobs do
      begin
        for LTagItem in LPair.Value.Tags do
        begin
          if LTagItem = ATag then
          begin
            LList.Add(LPair.Value);
            Break;
          end;
        end;
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TWorkerQueue.GetPendingCount: Integer;
begin
  FLock.Enter;
  try
    Result := FPendingQueue.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkerQueue.ClearCompletedJobs;
var
  LToRemove: TList<TJobId>;
  LPair: TPair<TJobId, TJob>;
  LJobId: TJobId;
begin
  LToRemove := TList<TJobId>.Create;
  try
    FLock.Enter;
    try
      for LPair in FJobs do
      begin
        if LPair.Value.Status in [jsCompleted, jsCancelled] then
          LToRemove.Add(LPair.Key);
      end;
      
      for LJobId in LToRemove do
      begin
        FJobs.Remove(LJobId);
        if Assigned(FStorage) then
          FStorage.DeleteJob(LJobId);
      end;
    finally
      FLock.Leave;
    end;
  finally
    LToRemove.Free;
  end;
end;

procedure TWorkerQueue.ClearAllJobs;
begin
  FLock.Enter;
  try
    FPendingQueue.Clear;
    FJobs.Clear;
    if Assigned(FStorage) then
      FStorage.Clear;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.GetNextJob: TJob;
var
  I: Integer;
  LJob: TJob;
  LHasAvailableJobs: Boolean;

  function IsAvailableJob(AJob: TJob): Boolean;
  begin
    Result := False;

    if (AJob.Status = jsScheduled) and (AJob.ScheduledAt > Now) then
      Exit;

    if (AJob.Status = jsRetrying) and (AJob.NextRetryAt > Now) then
      Exit;

    if not AreDependenciesMet(AJob) then
      Exit;

    Result := True;
  end;
begin
  Result := nil;
  FLock.Enter;
  try
    I := 0;
    while I < FPendingQueue.Count do
    begin
      LJob := FPendingQueue[I];

      if IsAvailableJob(LJob) then
      begin
        Result := LJob;
        FPendingQueue.Delete(I);
        Break;
      end;

      Inc(I);
    end;

    LHasAvailableJobs := False;
    for I := 0 to FPendingQueue.Count - 1 do
    begin
      if IsAvailableJob(FPendingQueue[I]) then
      begin
        LHasAvailableJobs := True;
        Break;
      end;
    end;

    // BUG-055 FIX: �ֶ������¼�������
    // ɾ����ǰ job �����¼��ʣ����У�����ɾ���ڼ�Խ���ȡ��
    if LHasAvailableJobs then
      FJobAvailable.SetEvent
    else
      FJobAvailable.ResetEvent;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.AreDependenciesMet(const AJob: TJob): Boolean;
var
  LDepId: TJobId;
  LDepJob: TJob;
begin
  Result := True;
  for LDepId in AJob.Dependencies do
  begin
    if FJobs.TryGetValue(LDepId, LDepJob) then
    begin
      if LDepJob.Status <> jsCompleted then
      begin
        Result := False;
        Break;
      end;
    end;
  end;
end;

procedure TWorkerQueue.SortPendingQueue;
begin
  FPendingQueue.Sort(TComparer<TJob>.Construct(
    function(const Left, Right: TJob): Integer
    begin
      // Higher priority first
      Result := Ord(Right.Priority) - Ord(Left.Priority);
      if Result = 0 then
        // Earlier created first
        Result := CompareDateTime(Left.CreatedAt, Right.CreatedAt);
    end
  ));
end;

procedure TWorkerQueue.ProcessJob(AJob: TJob);
var
  LHandler: TJobHandler;
  LStartTime: TDateTime;
  LElapsed: Integer;
begin
  FLock.Enter;
  try
    if not FHandlers.TryGetValue(AJob.JobType, LHandler) then
    begin
      AJob.FResult := TJobResult.CreateFailure('No handler registered for job type: ' + AJob.JobType);
      AJob.FStatus := jsFailed;
      Exit;
    end;
    
    // BUG-010 FIX: Protect status changes with lock to prevent race conditions
    AJob.FStatus := jsRunning;
    AJob.FStartedAt := Now;
    Inc(AJob.FAttempt);
  finally
    FLock.Leave;
  end;
  
  if Assigned(FOnJobStarted) then
    FOnJobStarted(Self, AJob);
    
  if Assigned(FStorage) then
    FStorage.SaveJob(AJob);
    
  LStartTime := Now;
  
  try
    LHandler(AJob);
    
    LElapsed := MilliSecondsBetween(Now, LStartTime);
    
    // BUG-010 FIX: Protect status changes with lock
    FLock.Enter;
    try
      AJob.FResult := TJobResult.CreateSuccess;
      AJob.FResult.ExecutionTime := LElapsed;
      AJob.FStatus := jsCompleted;
      AJob.FCompletedAt := Now;
    finally
      FLock.Leave;
    end;
    
    AtomicIncrement(FTotalProcessed);
    // BUG-047 FIX: Use proper atomic addition for total processing time
    TInterlocked.Add(FTotalProcessingTime, LElapsed);
    
    if Assigned(FOnJobCompleted) then
      FOnJobCompleted(Self, AJob);
      
    if Assigned(AJob.FOnCompletion) then
      AJob.FOnCompletion(AJob.Id, True, AJob.Result.ResultData);
      
  except
    on E: Exception do
    begin
      LElapsed := MilliSecondsBetween(Now, LStartTime);
      AJob.FResult := TJobResult.CreateFailure(E.Message);
      AJob.FResult.ExecutionTime := LElapsed;
      
      AtomicIncrement(FTotalErrors);
      
      if Assigned(FOnError) then
        FOnError(Self, AJob, E);
        
      // Handle retry
      if AJob.CanRetry then
      begin
        AJob.PrepareRetry;
        
        FLock.Enter;
        try
          FPendingQueue.Add(AJob);
          SortPendingQueue;
        finally
          FLock.Leave;
        end;
        
        if Assigned(FOnJobRetrying) then
          FOnJobRetrying(Self, AJob);
      end
      else
      begin
        // BUG-010 FIX: Protect status changes with lock
        FLock.Enter;
        try
          AJob.FStatus := jsFailed;
          AJob.FCompletedAt := Now;
        finally
          FLock.Leave;
        end;
        MoveToDeadLetter(AJob);
        
        if Assigned(FOnJobFailed) then
          FOnJobFailed(Self, AJob);
          
        if Assigned(AJob.FOnCompletion) then
          AJob.FOnCompletion(AJob.Id, False, E.Message);
      end;
    end;
  end;
  
  if Assigned(FStorage) then
    FStorage.SaveJob(AJob);

  FLock.Enter;
  try
    if FPendingQueue.Count > 0 then
      FJobAvailable.SetEvent;
  finally
    FLock.Leave;
  end;

  // BUG-056 FIX: ��ҵ������ɺ����Ƿ���Ҫ��̬�����̳߳�
  CheckAutoScale;
end;

procedure TWorkerQueue.MoveToDeadLetter(AJob: TJob);
begin
  // BUG-010 FIX: Protect status changes with lock
  FLock.Enter;
  try
    AJob.FStatus := jsDeadLetter;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkerQueue.Start;
var
  I: Integer;
  LWorker: TWorkerThread;
begin
  FLock.Enter;
  try
    if FWorkers.Count > 0 then
      Exit;
      
    FShuttingDown := False;
    FStartedAt := Now;
    FShutdownEvent.ResetEvent;
    
    for I := 1 to FMaxWorkers do
    begin
      LWorker := TWorkerThread.Create(Self, I);
      FWorkers.Add(LWorker);
      LWorker.Start;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkerQueue.Stop(AWaitForCompletion: Boolean);
var
  LWorker: TWorkerThread;
begin
  FShuttingDown := True;
  FShutdownEvent.SetEvent;
  FJobAvailable.SetEvent;
  
  if AWaitForCompletion then
  begin
    for LWorker in FWorkers do
    begin
      LWorker.Terminate;
      LWorker.WaitFor;
    end;
  end
  else
  begin
    for LWorker in FWorkers do
      LWorker.Terminate;
  end;
  
  FLock.Enter;
  try
    FWorkers.Clear;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.DrainAndStop(ATimeoutMs: Integer): Boolean;
var
  LStartTime: TDateTime;
  LStats: TQueueStats;
begin
  // BASIC-007: drain semantics — wait for pending+running jobs to clear,
  // then stop workers. Different from Stop(True) which terminates immediately.
  Result := True;
  if FShuttingDown then
    Exit;

  LStartTime := Now;
  while not FShuttingDown do
  begin
    LStats := GetStats;
    if (LStats.PendingJobs = 0) and (LStats.RunningJobs = 0) then
      Break;

    if (ATimeoutMs >= 0) and
       (MilliSecondsBetween(Now, LStartTime) >= ATimeoutMs) then
    begin
      Result := False;
      Break;
    end;

    Sleep(50);
  end;

  // Stop workers regardless of drain result.
  Stop(True);
end;

procedure TWorkerQueue.Pause;
begin
  FPaused := True;
end;

procedure TWorkerQueue.Resume;
begin
  FPaused := False;
  FJobAvailable.SetEvent;
end;

procedure TWorkerQueue.WaitForCompletion(ATimeoutMs: Integer);
var
  LStartTime: TDateTime;
  LStats: TQueueStats;
begin
  LStartTime := Now;
  
  // �ȴ����й���������е���ҵ���
  repeat
    LStats := GetStats;
    if (LStats.PendingJobs = 0) and (LStats.RunningJobs = 0) then
      Break;
      
    Sleep(50); // ������ѯ����������Ӧ��
    if (ATimeoutMs >= 0) and (MilliSecondsBetween(Now, LStartTime) > ATimeoutMs) then
      raise EWorkerQueueException.Create('Timeout waiting for job completion');
  until False;
end;

// BUG-056 FIX: ʵ���̳߳ض�̬����
procedure TWorkerQueue.CheckAutoScale;
var
  LStats: TQueueStats;
  LSaturation: Double;
  LIdleRate: Double;
  LNewCount: Integer;
  LElapsedMs: Int64;
begin
  // ����Ƿ������Զ�����
  if not FAutoScale then
    Exit;

  // ����Ƿ����ڹر�
  if FShuttingDown or FPaused then
    Exit;

  // �����ȴʱ��
  if FLastScaleTime > 0 then
  begin
    LElapsedMs := MilliSecondsBetween(Now, FLastScaleTime);
    if LElapsedMs < FScaleCooldownMs then
      Exit;
  end;

  // ��ȡ��ǰͳ����Ϣ������������ΪGetStats�ڲ��������
  LStats := GetStats;

  // ���û�й����̣߳������е���
  if LStats.ActiveWorkers + LStats.IdleWorkers = 0 then
    Exit;

  LNewCount := FWorkers.Count;

  // ������б��Ͷ� = ��������ҵ�� / ����������
  if FMaxPendingJobs > 0 then
    LSaturation := LStats.PendingJobs / FMaxPendingJobs
  else
    LSaturation := 0;

  // ��������� = �����߳��� / ���߳���
  if LStats.ActiveWorkers + LStats.IdleWorkers > 0 then
    LIdleRate := LStats.IdleWorkers / (LStats.ActiveWorkers + LStats.IdleWorkers)
  else
    LIdleRate := 1;

  // �ж��Ƿ���Ҫ����
  // ���������б��Ͷȳ�����ֵ �� ��ǰ�߳���δ������
  if (LSaturation > FScaleUpThreshold) and (LNewCount < FMaxWorkers) then
  begin
    // ���ݣ����� 1 ���̣߳����߸��ݱ��Ͷ����Ӹ���
    LNewCount := Min(LNewCount + Max(1, Round((LSaturation - FScaleUpThreshold) * 5)), FMaxWorkers);
  end
  // �ж��Ƿ���Ҫ����
  // �����������ʳ�����ֵ���������ʵͣ��� ��ǰ�߳���������Сֵ
  else if (LIdleRate > (1 - FScaleDownThreshold)) and (LNewCount > FMinWorkers) then
  begin
    // ���ݣ����� 1 ���߳�
    LNewCount := Max(LNewCount - 1, FMinWorkers);
  end;

  // �����Ҫ������ִ�е���
  if LNewCount <> FWorkers.Count then
  begin
    FLastScaleTime := Now;
    SetWorkerCount(LNewCount);
  end;
end;

procedure TWorkerQueue.SetWorkerCount(ACount: Integer);
var
  LWorker: TWorkerThread;
begin
  FLock.Enter;
  try
    // Remove excess workers
    while FWorkers.Count > ACount do
    begin
      LWorker := FWorkers[FWorkers.Count - 1];
      LWorker.Terminate;
      FWorkers.Delete(FWorkers.Count - 1);
    end;
    
    // Add new workers
    while FWorkers.Count < ACount do
    begin
      LWorker := TWorkerThread.Create(Self, FWorkers.Count + 1);
      FWorkers.Add(LWorker);
      LWorker.Start;
    end;
    
    FMaxWorkers := ACount;
  finally
    FLock.Leave;
  end;
end;

procedure TWorkerQueue.LoadFromStorage;
var
  LJobs: TObjectList<TJob>;
  LJob: TJob;
begin
  if not Assigned(FStorage) then
    Exit;
    
  LJobs := FStorage.LoadPendingJobs;
  try
    FLock.Enter;
    try
      for LJob in LJobs do
      begin
        LJob.FQueue := Self;
        FJobs.AddOrSetValue(LJob.Id, LJob);
        if LJob.Status in [jsPending, jsScheduled, jsRetrying] then
          FPendingQueue.Add(LJob);
      end;
      LJobs.OwnsObjects := False;
      SortPendingQueue;
    finally
      FLock.Leave;
    end;
  finally
    LJobs.Free;
  end;
  
  if FPendingQueue.Count > 0 then
    FJobAvailable.SetEvent;
end;

procedure TWorkerQueue.SaveToStorage;
var
  LPair: TPair<TJobId, TJob>;
begin
  if not Assigned(FStorage) then
    Exit;
    
  FLock.Enter;
  try
    for LPair in FJobs do
      FStorage.SaveJob(LPair.Value);
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.GetStats: TQueueStats;
var
  LPair: TPair<TJobId, TJob>;
  LWorker: TWorkerThread;
begin
  FLock.Enter;
  try
    Result.TotalJobs := FJobs.Count;
    Result.PendingJobs := 0;
    Result.RunningJobs := 0;
    Result.CompletedJobs := 0;
    Result.FailedJobs := 0;
    Result.DeadLetterJobs := 0;
    
    for LPair in FJobs do
    begin
      case LPair.Value.Status of
        jsPending, jsScheduled, jsRetrying: Inc(Result.PendingJobs);
        jsRunning: Inc(Result.RunningJobs);
        jsCompleted: Inc(Result.CompletedJobs);
        jsFailed: Inc(Result.FailedJobs);
        jsDeadLetter: Inc(Result.DeadLetterJobs);
      end;
    end;
    
    Result.ActiveWorkers := 0;
    Result.IdleWorkers := 0;
    Result.TotalProcessed := FTotalProcessed;
    Result.TotalErrors := FTotalErrors;
    
    for LWorker in FWorkers do
    begin
      if LWorker.IsIdle then
        Inc(Result.IdleWorkers)
      else
        Inc(Result.ActiveWorkers);
    end;
    
    if FTotalProcessed > 0 then
      Result.AverageProcessingTime := FTotalProcessingTime / FTotalProcessed
    else
      Result.AverageProcessingTime := 0;
      
    Result.Uptime := FStartedAt;
  finally
    FLock.Leave;
  end;
end;

function TWorkerQueue.GetActiveWorkerCount: Integer;
var
  LWorker: TWorkerThread;
begin
  Result := 0;
  FLock.Enter;
  try
    for LWorker in FWorkers do
    begin
      if not LWorker.IsIdle then
        Inc(Result);
    end;
  finally
    FLock.Leave;
  end;
end;

{ TJobBuilder }

constructor TJobBuilder.Create(const AJobType: string);
begin
  inherited Create;
  FJob := TJob.Create(AJobType);
end;

function TJobBuilder.Data(const AKey: string; const AValue: Variant): TJobBuilder;
begin
  FJob.WithData(AKey, AValue);
  Result := Self;
end;

function TJobBuilder.Data(AData: TJobData): TJobBuilder;
begin
  FJob.WithData(AData);
  Result := Self;
end;

function TJobBuilder.Priority(APriority: TJobPriority): TJobBuilder;
begin
  FJob.WithPriority(APriority);
  Result := Self;
end;

function TJobBuilder.Retry(AMaxRetries: Integer): TJobBuilder;
begin
  FJob.WithRetryPolicy(TRetryPolicy.Exponential(AMaxRetries, DEFAULT_RETRY_DELAY_MS, DEFAULT_WORKER_TIMEOUT_MS));
  Result := Self;
end;

function TJobBuilder.RetryPolicy(APolicy: TRetryPolicy): TJobBuilder;
begin
  FJob.WithRetryPolicy(APolicy);
  Result := Self;
end;

function TJobBuilder.ScheduleAt(ATime: TDateTime): TJobBuilder;
begin
  FJob.ScheduleAt(ATime);
  Result := Self;
end;

function TJobBuilder.DelayFor(ASeconds: Integer): TJobBuilder;
begin
  FJob.DelayFor(ASeconds);
  Result := Self;
end;

function TJobBuilder.Timeout(ATimeoutMs: Integer): TJobBuilder;
begin
  FJob.WithTimeout(ATimeoutMs);
  Result := Self;
end;

function TJobBuilder.Tag(const ATag: string): TJobBuilder;
begin
  FJob.WithTag(ATag);
  Result := Self;
end;

function TJobBuilder.DependsOn(const AJobId: TJobId): TJobBuilder;
begin
  FJob.DependsOn(AJobId);
  Result := Self;
end;

function TJobBuilder.Metadata(const AKey, AValue: string): TJobBuilder;
begin
  FJob.WithMetadata(AKey, AValue);
  Result := Self;
end;

function TJobBuilder.OnProgress(ACallback: TJobProgressCallback): TJobBuilder;
begin
  FJob.OnProgress(ACallback);
  Result := Self;
end;

function TJobBuilder.OnComplete(ACallback: TJobCompletionCallback): TJobBuilder;
begin
  FJob.OnComplete(ACallback);
  Result := Self;
end;

function TJobBuilder.Build: TJob;
begin
  Result := FJob;
  FJob := nil;
end;

{ TWorkerQueues }

class constructor TWorkerQueues.Create;
begin
  FQueues := TObjectDictionary<string, TWorkerQueue>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

class destructor TWorkerQueues.Destroy;
begin
  StopAll(True);
  FreeAndNil(FLock);
  FreeAndNil(FQueues);
end;

class function TWorkerQueues.GetQueue(const AName: string): TWorkerQueue;
begin
  FLock.Enter;
  try
    if not FQueues.TryGetValue(AName, Result) then
    begin
      Result := TWorkerQueue.Create(AName);
      FQueues.Add(AName, Result);
      
      if AName = 'default' then
        FDefaultQueue := Result;
    end;
  finally
    FLock.Leave;
  end;
end;

class procedure TWorkerQueues.RegisterHandler(const AJobType: string; AHandler: TJobHandler);
begin
  GetQueue('default').RegisterHandler(AJobType, AHandler);
end;

class function TWorkerQueues.Enqueue(AJob: TJob): TJobId;
begin
  Result := GetQueue('default').Enqueue(AJob);
end;

class function TWorkerQueues.Enqueue(const AJobType: string; AData: TJobData): TJobId;
begin
  Result := GetQueue('default').EnqueueJob(AJobType, AData);
end;

class function TWorkerQueues.Job(const AJobType: string): TJobBuilder;
begin
  Result := TJobBuilder.Create(AJobType);
end;

class procedure TWorkerQueues.StartAll;
var
  LPair: TPair<string, TWorkerQueue>;
begin
  FLock.Enter;
  try
    for LPair in FQueues do
      LPair.Value.Start;
  finally
    FLock.Leave;
  end;
end;

class procedure TWorkerQueues.StopAll(AWaitForCompletion: Boolean);
var
  LPair: TPair<string, TWorkerQueue>;
begin
  FLock.Enter;
  try
    for LPair in FQueues do
      LPair.Value.Stop(AWaitForCompletion);
  finally
    FLock.Leave;
  end;
end;

initialization
  GQueueLock := TCriticalSection.Create;
  Randomize;
  
finalization
  FreeAndNil(GDefaultQueue);
  FreeAndNil(GQueueLock);

end.
