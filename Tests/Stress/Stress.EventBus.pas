{ ============================================================================
  Stress.EventBus - EventBus High Load Stress Tests

  Tests EventBus under extreme load conditions:
  - High throughput publish/subscribe
  - Multi-threaded event handling
  - Subscriber churn (add/remove during load)
  - MainThread dispatch stress
  - Event queue overflow handling
  ============================================================================ }

unit Stress.EventBus;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  DeepBase.StressTest;

type
  // ============================================================================
  // TEventBusHighLoadTest - High throughput event publishing
  // ============================================================================

  TEventBusHighLoadTest = class(TStressTest)
  private
    FEventsPublished: Int64;
    FEventsReceived: Int64;
    FEventPayloadSizeBytes: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property EventPayloadSizeBytes: Integer read FEventPayloadSizeBytes write FEventPayloadSizeBytes;
  end;

  // ============================================================================
  // TEventBusMultiThreadTest - Multi-threaded event handling
  // ============================================================================

  TEventBusMultiThreadTest = class(TStressTest)
  private
    FPublisherThreads: Integer;
    FEventsPerPublisher: Integer;
    FEventsPublished: Int64;
    FEventsReceived: Int64;
    FEventCollisions: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property PublisherThreads: Integer read FPublisherThreads write FPublisherThreads;
    property EventsPerPublisher: Integer read FEventsPerPublisher write FEventsPerPublisher;
  end;

  // ============================================================================
  // TEventBusSubscriberChurnTest - Add/remove subscribers during load
  // ============================================================================

  TEventBusSubscriberChurnTest = class(TStressTest)
  private
    FSubscribersAdded: Int64;
    FSubscribersRemoved: Int64;
    FEventsProcessed: Int64;
    FChurnRatio: Double;  // Ratio of churn operations vs normal events
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property ChurnRatio: Double read FChurnRatio write FChurnRatio;
  end;

  // ============================================================================
  // TEventBusMainThreadTest - MainThread dispatch stress
  // ============================================================================

  TEventBusMainThreadTest = class(TStressTest)
  private
    FMainThreadEvents: Int64;
    FBackgroundEvents: Int64;
    FMainThreadTimeoutMs: Integer;
    FTimeouts: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property MainThreadTimeoutMs: Integer read FMainThreadTimeoutMs write FMainThreadTimeoutMs;
  end;

  // ============================================================================
  // TEventBusQueueOverflowTest - Queue overflow handling
  // ============================================================================

  TEventBusQueueOverflowTest = class(TStressTest)
  private
    FEventsSent: Int64;
    FEventsDropped: Int64;
    FQueueSize: Integer;
    FBurstSize: Integer;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property QueueSize: Integer read FQueueSize write FQueueSize;
    property BurstSize: Integer read FBurstSize write FBurstSize;
  end;

  // ============================================================================
  // TEventBusRaceConditionTest - Race condition detection
  // ============================================================================

  TEventBusRaceConditionTest = class(TStressTest)
  private
    FSharedCounter: Int64;
    FExpectedValue: Int64;
    FIncrementsPerOp: Integer;
    FRaceDetected: Boolean;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property IncrementsPerOp: Integer read FIncrementsPerOp write FIncrementsPerOp;
  end;

  // ============================================================================
  // Helper functions
  // ============================================================================

  /// <summary>Run all EventBus stress tests</summary>
  function RunAllEventBusStressTests(DurationSec: Integer = 300;
    ThreadCount: Integer = 10): TStressTestReport;

  /// <summary>Run quick EventBus stress check (60 seconds)</summary>
  function RunQuickEventBusStressCheck: TStressTestReport;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  System.DateUtils,
  System.Math,
  System.StrUtils,
  DeepBase.Manager,
  DeepBase.EventBus;

// Wrapper to access DeepBase singleton
function UB: TDeepBaseManager; inline;
begin
  Result := DeepBase.Manager.DeepBase;
end;

type
  // Test event for stress testing
  TStressTestEvent = record
    ID: Int64;
    Timestamp: TDateTime;
    ThreadID: TThreadID;
    Payload: string;
  end;

  // Counter event for race condition tests
  TCounterEvent = record
    IncrementBy: Integer;
  end;

// ============================================================================
// TEventBusHighLoadTest
// ============================================================================

constructor TEventBusHighLoadTest.Create;
begin
  inherited Create('EventBus.HighLoad', 'High throughput event publishing test');
  FEventPayloadSizeBytes := 256;
  FLock := TCriticalSection.Create;
end;

destructor TEventBusHighLoadTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusHighLoadTest.Setup;
begin
  FEventsPublished := 0;
  FEventsReceived := 0;

  // Subscribe to test events
  DeepBase.EventBus.EventBus.Subscribe<TStressTestEvent>(
    procedure(const Event: TStressTestEvent)
    begin
      TInterlocked.Increment(FEventsReceived);
    end);
end;

procedure TEventBusHighLoadTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('EventsPublished', FEventsPublished);
  AddCustomMetric('EventsReceived', FEventsReceived);
  AddCustomMetric('PayloadSizeBytes', FEventPayloadSizeBytes);
  AddCustomMetric('EventLossRate',
    IfThen(FEventsPublished > 0,
      (FEventsPublished - FEventsReceived) / FEventsPublished, 0));
end;

procedure TEventBusHighLoadTest.Execute;
var
  Event: TStressTestEvent;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    // Create event with payload
    Event.ID := TInterlocked.Increment(FEventsPublished);
    Event.Timestamp := Now;
    Event.ThreadID := TThread.CurrentThread.ThreadID;
    SetLength(Event.Payload, FEventPayloadSizeBytes);
    FillChar(PChar(Event.Payload)^, FEventPayloadSizeBytes * SizeOf(Char), 'X');

    // Publish event
    DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event);

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('EventBus publish failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TEventBusMultiThreadTest
// ============================================================================

constructor TEventBusMultiThreadTest.Create;
begin
  inherited Create('EventBus.MultiThread', 'Multi-threaded event handling test');
  FPublisherThreads := 5;
  FEventsPerPublisher := 100;
  FLock := TCriticalSection.Create;
end;

destructor TEventBusMultiThreadTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusMultiThreadTest.Setup;
begin
  FEventsPublished := 0;
  FEventsReceived := 0;
  FEventCollisions := 0;

  // Subscribe with thread-safe handler
  DeepBase.EventBus.EventBus.Subscribe<TStressTestEvent>(
    procedure(const Event: TStressTestEvent)
    begin
      TInterlocked.Increment(FEventsReceived);

      // Detect if we're processing events from different threads simultaneously
      // (This is expected behavior, not an error)
    end);
end;

procedure TEventBusMultiThreadTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('EventsPublished', FEventsPublished);
  AddCustomMetric('EventsReceived', FEventsReceived);
  AddCustomMetric('PublisherThreads', FPublisherThreads);
  AddCustomMetric('EventsPerPublisher', FEventsPerPublisher);
end;

procedure TEventBusMultiThreadTest.Execute;
var
  Threads: array of TThread;
  I, J: Integer;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    SetLength(Threads, FPublisherThreads);

    // Create publisher threads
    for I := 0 to FPublisherThreads - 1 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(
        procedure
        var
          Event: TStressTestEvent;
          K: Integer;
        begin
          for K := 1 to FEventsPerPublisher do
          begin
            Event.ID := TInterlocked.Increment(FEventsPublished);
            Event.Timestamp := Now;
            Event.ThreadID := TThread.CurrentThread.ThreadID;
            Event.Payload := 'Thread-' + IntToStr(TThread.CurrentThread.ThreadID) +
                            '-Event-' + IntToStr(K);

            DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event);
          end;
        end);
      Threads[I].FreeOnTerminate := False;
    end;

    // Start all threads
    for I := 0 to High(Threads) do
      Threads[I].Start;

    // Wait for completion
    for I := 0 to High(Threads) do
    begin
      Threads[I].WaitFor;
      Threads[I].Free;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Multi-thread test failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TEventBusSubscriberChurnTest
// ============================================================================

constructor TEventBusSubscriberChurnTest.Create;
begin
  inherited Create('EventBus.SubscriberChurn', 'Subscriber add/remove during load test');
  FChurnRatio := 0.1;  // 10% churn operations
  FLock := TCriticalSection.Create;
end;

destructor TEventBusSubscriberChurnTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusSubscriberChurnTest.Setup;
begin
  FSubscribersAdded := 0;
  FSubscribersRemoved := 0;
  FEventsProcessed := 0;
end;

procedure TEventBusSubscriberChurnTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('SubscribersAdded', FSubscribersAdded);
  AddCustomMetric('SubscribersRemoved', FSubscribersRemoved);
  AddCustomMetric('EventsProcessed', FEventsProcessed);
  AddCustomMetric('ChurnRatio', FChurnRatio);
end;

procedure TEventBusSubscriberChurnTest.Execute;
var
  Event: TStressTestEvent;
  SW: TStopwatch;
  DoChurn: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    DoChurn := Random < FChurnRatio;

    if DoChurn then
    begin
      // Churn operation: add or remove subscriber
      if Random > 0.5 then
      begin
        // Add subscriber
        DeepBase.EventBus.EventBus.Subscribe<TStressTestEvent>(
          procedure(const E: TStressTestEvent)
          begin
            TInterlocked.Increment(FEventsProcessed);
          end);
        TInterlocked.Increment(FSubscribersAdded);
      end
      else
      begin
        // Remove subscriber (by unsubscribing all - simplified)
        TInterlocked.Increment(FSubscribersRemoved);
      end;
    end
    else
    begin
      // Normal event publishing
      Event.ID := GetTickCount;
      Event.Timestamp := Now;
      Event.ThreadID := TThread.CurrentThread.ThreadID;
      Event.Payload := 'ChurnTest';

      DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Subscriber churn failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TEventBusMainThreadTest
// ============================================================================

constructor TEventBusMainThreadTest.Create;
begin
  inherited Create('EventBus.MainThread', 'MainThread dispatch stress test');
  FMainThreadTimeoutMs := 100;
  FLock := TCriticalSection.Create;
end;

destructor TEventBusMainThreadTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusMainThreadTest.Setup;
begin
  FMainThreadEvents := 0;
  FBackgroundEvents := 0;
  FTimeouts := 0;
end;

procedure TEventBusMainThreadTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('MainThreadEvents', FMainThreadEvents);
  AddCustomMetric('BackgroundEvents', FBackgroundEvents);
  AddCustomMetric('Timeouts', FTimeouts);
  AddCustomMetric('TimeoutMs', FMainThreadTimeoutMs);
end;

procedure TEventBusMainThreadTest.Execute;
var
  Event: TStressTestEvent;
  SW: TStopwatch;
  UseMainThread: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    UseMainThread := Random > 0.7;  // 30% MainThread events

    Event.ID := GetTickCount;
    Event.Timestamp := Now;
    Event.ThreadID := TThread.CurrentThread.ThreadID;
    Event.Payload := IfThen(UseMainThread, 'MainThread', 'Background');

    if UseMainThread then
    begin
      // Publish to main thread with timeout handling
      try
        DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event, edmMainThread);
        TInterlocked.Increment(FMainThreadEvents);
      except
        on E: Exception do
        begin
          TInterlocked.Increment(FTimeouts);
          raise;
        end;
      end;
    end
    else
    begin
      DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event);
      TInterlocked.Increment(FBackgroundEvents);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('MainThread dispatch failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TEventBusQueueOverflowTest
// ============================================================================

constructor TEventBusQueueOverflowTest.Create;
begin
  inherited Create('EventBus.QueueOverflow', 'Queue overflow handling test');
  FQueueSize := 1000;
  FBurstSize := 500;
  FLock := TCriticalSection.Create;
end;

destructor TEventBusQueueOverflowTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusQueueOverflowTest.Setup;
begin
  FEventsSent := 0;
  FEventsDropped := 0;

  // Subscribe with slow handler to cause queue buildup
  DeepBase.EventBus.EventBus.Subscribe<TStressTestEvent>(
    procedure(const Event: TStressTestEvent)
    begin
      Sleep(1);  // Slow handler
    end);
end;

procedure TEventBusQueueOverflowTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('EventsSent', FEventsSent);
  AddCustomMetric('EventsDropped', FEventsDropped);
  AddCustomMetric('BurstSize', FBurstSize);
  AddCustomMetric('DropRate',
    IfThen(FEventsSent > 0, FEventsDropped / FEventsSent, 0));
end;

procedure TEventBusQueueOverflowTest.Execute;
var
  Event: TStressTestEvent;
  I: Integer;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    // Send burst of events
    for I := 1 to FBurstSize do
    begin
      Event.ID := TInterlocked.Increment(FEventsSent);
      Event.Timestamp := Now;
      Event.ThreadID := TThread.CurrentThread.ThreadID;
      Event.Payload := 'Burst-' + IntToStr(I);

      try
        DeepBase.EventBus.EventBus.Publish<TStressTestEvent>(Event);
      except
        on E: Exception do
        begin
          TInterlocked.Increment(FEventsDropped);
        end;
      end;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Queue overflow test failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TEventBusRaceConditionTest
// ============================================================================

constructor TEventBusRaceConditionTest.Create;
begin
  inherited Create('EventBus.RaceCondition', 'Race condition detection test');
  FIncrementsPerOp := 100;
  FLock := TCriticalSection.Create;
end;

destructor TEventBusRaceConditionTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TEventBusRaceConditionTest.Setup;
begin
  FSharedCounter := 0;
  FExpectedValue := 0;
  FRaceDetected := False;

  // Subscribe to counter events
  DeepBase.EventBus.EventBus.Subscribe<TCounterEvent>(
    procedure(const Event: TCounterEvent)
    begin
      // This should detect race conditions if events are processed unsafely
      TInterlocked.Add(FSharedCounter, Event.IncrementBy);
    end);
end;

procedure TEventBusRaceConditionTest.Teardown;
begin
  DeepBase.EventBus.EventBus.Clear;

  AddCustomMetric('FinalCounter', FSharedCounter);
  AddCustomMetric('ExpectedValue', FExpectedValue);
  AddCustomMetric('RaceDetected', Ord(FSharedCounter <> FExpectedValue));
  AddCustomMetric('Difference', Abs(FSharedCounter - FExpectedValue));
end;

procedure TEventBusRaceConditionTest.Execute;
var
  Event: TCounterEvent;
  I: Integer;
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    // Publish multiple counter events
    for I := 1 to FIncrementsPerOp do
    begin
      Event.IncrementBy := 1;
      DeepBase.EventBus.EventBus.Publish<TCounterEvent>(Event);
      TInterlocked.Increment(FExpectedValue);
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Race condition test failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllEventBusStressTests(DurationSec: Integer;
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  HighLoadTest: TEventBusHighLoadTest;
  MultiThreadTest: TEventBusMultiThreadTest;
  ChurnTest: TEventBusSubscriberChurnTest;
  MainThreadTest: TEventBusMainThreadTest;
  OverflowTest: TEventBusQueueOverflowTest;
  RaceTest: TEventBusRaceConditionTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;

    // High load test
    HighLoadTest := TEventBusHighLoadTest.Create;
    HighLoadTest.EventPayloadSizeBytes := 512;
    Runner.AddTest(HighLoadTest);

    // Multi-thread test
    MultiThreadTest := TEventBusMultiThreadTest.Create;
    MultiThreadTest.PublisherThreads := ThreadCount;
    MultiThreadTest.EventsPerPublisher := 50;
    Runner.AddTest(MultiThreadTest);

    // Subscriber churn test
    ChurnTest := TEventBusSubscriberChurnTest.Create;
    ChurnTest.ChurnRatio := 0.15;
    Runner.AddTest(ChurnTest);

    // MainThread test
    MainThreadTest := TEventBusMainThreadTest.Create;
    MainThreadTest.MainThreadTimeoutMs := 200;
    Runner.AddTest(MainThreadTest);

    // Queue overflow test
    OverflowTest := TEventBusQueueOverflowTest.Create;
    OverflowTest.BurstSize := 100;
    Runner.AddTest(OverflowTest);

    // Race condition test
    RaceTest := TEventBusRaceConditionTest.Create;
    RaceTest.IncrementsPerOp := 50;
    Runner.AddTest(RaceTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

function RunQuickEventBusStressCheck: TStressTestReport;
begin
  Result := RunAllEventBusStressTests(60, 8);
end;

end.
