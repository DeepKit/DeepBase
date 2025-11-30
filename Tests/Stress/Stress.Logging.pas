{ ============================================================================
  Stress.Logging - Logging Module Stress Tests
  
  Tests large-scale log writing scenarios:
  - High-volume concurrent log writes
  - Different log levels stress
  - Large message handling
  - Log rotation under load
  - File vs database logging comparison
  ============================================================================ }

unit Stress.Logging;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.Diagnostics,
  UniBase.StressTest,
  UniBase.Types;

type
  // ============================================================================
  // TLogWriteStressTest - High-volume log writes
  // ============================================================================
  
  TLogWriteStressTest = class(TStressTest)
  private
    FMessageSize: Integer;
    FLogLevel: TLogLevel;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property MessageSize: Integer read FMessageSize write FMessageSize;
    property LogLevel: TLogLevel read FLogLevel write FLogLevel;
  end;
  
  // ============================================================================
  // TLogLevelMixStressTest - Different log levels
  // ============================================================================
  
  TLogLevelMixStressTest = class(TStressTest)
  private
    FDebugRatio: Double;
    FInfoRatio: Double;
    FWarnRatio: Double;
    FErrorRatio: Double;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property DebugRatio: Double read FDebugRatio write FDebugRatio;
    property InfoRatio: Double read FInfoRatio write FInfoRatio;
    property WarnRatio: Double read FWarnRatio write FWarnRatio;
    property ErrorRatio: Double read FErrorRatio write FErrorRatio;
  end;
  
  // ============================================================================
  // TLogLargeMessageStressTest - Large log messages
  // ============================================================================
  
  TLogLargeMessageStressTest = class(TStressTest)
  private
    FMessageSizeKB: Integer;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property MessageSizeKB: Integer read FMessageSizeKB write FMessageSizeKB;
  end;
  
  // ============================================================================
  // TLogFormattedStressTest - Formatted log messages
  // ============================================================================
  
  TLogFormattedStressTest = class(TStressTest)
  private
    FArgCount: Integer;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property ArgCount: Integer read FArgCount write FArgCount;
  end;
  
  // ============================================================================
  // TLogExceptionStressTest - Exception logging
  // ============================================================================
  
  TLogExceptionStressTest = class(TStressTest)
  private
    FIncludeStackTrace: Boolean;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property IncludeStackTrace: Boolean read FIncludeStackTrace write FIncludeStackTrace;
  end;
  
  // ============================================================================
  // TLogSourceFilterStressTest - Source-based filtering
  // ============================================================================
  
  TLogSourceFilterStressTest = class(TStressTest)
  private
    FSources: TArray<string>;
    FSourceCount: Integer;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property SourceCount: Integer read FSourceCount write FSourceCount;
  end;
  
  // ============================================================================
  // TLogThroughputStressTest - Maximum throughput test
  // ============================================================================
  
  TLogThroughputStressTest = class(TStressTest)
  private
    FBatchSize: Integer;
    FLogCounter: Int64;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    property BatchSize: Integer read FBatchSize write FBatchSize;
  end;
  
  // ============================================================================
  // Helper functions
  // ============================================================================
  
  /// <summary>Run all logging stress tests</summary>
  function RunAllLoggingStressTests(DurationSec: Integer = 30; 
    ThreadCount: Integer = 10): TStressTestReport;

implementation

uses
  UniBase.Logging;

// ============================================================================
// TLogWriteStressTest
// ============================================================================

constructor TLogWriteStressTest.Create;
begin
  inherited Create('Logging.Write', 'High-volume concurrent log writes');
  FMessageSize := 100;
  FLogLevel := llInfo;
end;

procedure TLogWriteStressTest.Setup;
begin
  FLogCounter := 0;
  // Ensure logger is available
  if not IsLoggerInitialized then
    raise Exception.Create('Logger not initialized - requires UniBase.Manager');
end;

procedure TLogWriteStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
end;

procedure TLogWriteStressTest.Execute;
var
  Msg: string;
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  Msg := Format('Stress test message #%d: %s', [Counter, StringOfChar('X', FMessageSize)]);
  
  SW := TStopwatch.StartNew;
  try
    Logger.Log(Msg, FLogLevel, 'StressTest');
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Log write failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLogLevelMixStressTest
// ============================================================================

constructor TLogLevelMixStressTest.Create;
begin
  inherited Create('Logging.LevelMix', 'Mixed log level stress test');
  // Realistic distribution
  FDebugRatio := 0.40;  // 40% debug
  FInfoRatio := 0.35;   // 35% info
  FWarnRatio := 0.15;   // 15% warning
  FErrorRatio := 0.10;  // 10% error
end;

procedure TLogLevelMixStressTest.Setup;
begin
  FLogCounter := 0;
end;

procedure TLogLevelMixStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
end;

procedure TLogLevelMixStressTest.Execute;
var
  Msg: string;
  Counter: Int64;
  R: Double;
  Level: TLogLevel;
  LevelName: string;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  
  // Select level based on distribution
  R := Random;
  if R < FDebugRatio then
  begin
    Level := llDebug;
    LevelName := 'DEBUG';
  end
  else if R < FDebugRatio + FInfoRatio then
  begin
    Level := llInfo;
    LevelName := 'INFO';
  end
  else if R < FDebugRatio + FInfoRatio + FWarnRatio then
  begin
    Level := llWarn;
    LevelName := 'WARN';
  end
  else
  begin
    Level := llError;
    LevelName := 'ERROR';
  end;
  
  Msg := Format('[%s] Stress test message #%d from thread %d', 
    [LevelName, Counter, TThread.CurrentThread.ThreadID]);
  
  SW := TStopwatch.StartNew;
  try
    Logger.Log(Msg, Level, 'StressTest');
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    AddCustomMetric('Level_' + LevelName, 1);
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Log write failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLogLargeMessageStressTest
// ============================================================================

constructor TLogLargeMessageStressTest.Create;
begin
  inherited Create('Logging.LargeMessage', 'Large log message handling');
  FMessageSizeKB := 10;
end;

procedure TLogLargeMessageStressTest.Setup;
begin
  FLogCounter := 0;
end;

procedure TLogLargeMessageStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
  AddCustomMetric('MessageSizeKB', FMessageSizeKB);
end;

procedure TLogLargeMessageStressTest.Execute;
var
  Msg: string;
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  
  // Create large message
  Msg := Format('Large message #%d: %s', [Counter, StringOfChar('L', FMessageSizeKB * 1024)]);
  
  SW := TStopwatch.StartNew;
  try
    Logger.Log(Msg, llInfo, 'StressTest.LargeMsg');
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    AddCustomMetric('BytesWritten', Length(Msg));
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Large message write failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLogFormattedStressTest
// ============================================================================

constructor TLogFormattedStressTest.Create;
begin
  inherited Create('Logging.Formatted', 'Formatted log message stress test');
  FArgCount := 5;
end;

procedure TLogFormattedStressTest.Setup;
begin
  FLogCounter := 0;
end;

procedure TLogFormattedStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
end;

procedure TLogFormattedStressTest.Execute;
var
  Counter: Int64;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  
  SW := TStopwatch.StartNew;
  try
    // Use formatted logging with multiple arguments
    case FArgCount of
      1: Logger.InfoFmt('Message #%d', [Counter], 'StressTest.Fmt');
      2: Logger.InfoFmt('Message #%d at %s', [Counter, FormatDateTime('hh:nn:ss.zzz', Now)], 'StressTest.Fmt');
      3: Logger.InfoFmt('Message #%d at %s from thread %d', 
           [Counter, FormatDateTime('hh:nn:ss.zzz', Now), TThread.CurrentThread.ThreadID], 'StressTest.Fmt');
      4: Logger.InfoFmt('Message #%d at %s from thread %d with value %.2f', 
           [Counter, FormatDateTime('hh:nn:ss.zzz', Now), TThread.CurrentThread.ThreadID, Random * 100], 'StressTest.Fmt');
    else
      Logger.InfoFmt('Message #%d at %s from thread %d with value %.2f and flag %s', 
           [Counter, FormatDateTime('hh:nn:ss.zzz', Now), TThread.CurrentThread.ThreadID, 
            Random * 100, BoolToStr(Random > 0.5, True)], 'StressTest.Fmt');
    end;
    
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Formatted log failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLogExceptionStressTest
// ============================================================================

constructor TLogExceptionStressTest.Create;
begin
  inherited Create('Logging.Exception', 'Exception logging stress test');
  FIncludeStackTrace := True;
end;

procedure TLogExceptionStressTest.Setup;
begin
  FLogCounter := 0;
end;

procedure TLogExceptionStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
end;

procedure TLogExceptionStressTest.Execute;
var
  Counter: Int64;
  SW: TStopwatch;
  TestEx: Exception;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  
  // Create a test exception
  TestEx := Exception.CreateFmt('Stress test exception #%d', [Counter]);
  try
    SW := TStopwatch.StartNew;
    try
      Logger.LogException(TestEx, Format('Context for exception #%d', [Counter]), llError);
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportSuccess;
    except
      on E: Exception do
      begin
        SW.Stop;
        ReportLatency(SW.Elapsed.TotalMilliseconds);
        ReportError('Exception log failed: ' + E.Message);
      end;
    end;
  finally
    TestEx.Free;
  end;
end;

// ============================================================================
// TLogSourceFilterStressTest
// ============================================================================

constructor TLogSourceFilterStressTest.Create;
begin
  inherited Create('Logging.SourceFilter', 'Source-based logging stress test');
  FSourceCount := 10;
end;

procedure TLogSourceFilterStressTest.Setup;
var
  I: Integer;
begin
  FLogCounter := 0;
  
  // Create source names
  SetLength(FSources, FSourceCount);
  for I := 0 to FSourceCount - 1 do
    FSources[I] := Format('StressSource_%d', [I]);
end;

procedure TLogSourceFilterStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
end;

procedure TLogSourceFilterStressTest.Execute;
var
  Counter: Int64;
  SourceIndex: Integer;
  Source, Msg: string;
  SW: TStopwatch;
begin
  Counter := TInterlocked.Increment(FLogCounter);
  SourceIndex := Random(FSourceCount);
  Source := FSources[SourceIndex];
  Msg := Format('Message #%d from source %s', [Counter, Source]);
  
  SW := TStopwatch.StartNew;
  try
    Logger.Info(Msg, Source);
    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
    
    AddCustomMetric('Source_' + IntToStr(SourceIndex), 1);
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Source filter log failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TLogThroughputStressTest
// ============================================================================

constructor TLogThroughputStressTest.Create;
begin
  inherited Create('Logging.Throughput', 'Maximum logging throughput test');
  FBatchSize := 100;
end;

procedure TLogThroughputStressTest.Setup;
begin
  FLogCounter := 0;
end;

procedure TLogThroughputStressTest.Teardown;
begin
  AddCustomMetric('TotalLogsWritten', FLogCounter);
  AddCustomMetric('BatchSize', FBatchSize);
end;

procedure TLogThroughputStressTest.Execute;
var
  I: Integer;
  Counter: Int64;
  BatchStart: Int64;
  SW: TStopwatch;
begin
  BatchStart := FLogCounter;
  
  SW := TStopwatch.StartNew;
  try
    // Write batch of logs as fast as possible
    for I := 0 to FBatchSize - 1 do
    begin
      Counter := TInterlocked.Increment(FLogCounter);
      Logger.Debug(Format('Throughput test #%d', [Counter]), 'StressTest.Throughput');
    end;
    
    SW.Stop;
    
    // Report average latency per log
    ReportLatency(SW.Elapsed.TotalMilliseconds / FBatchSize);
    ReportSuccess;
    
    AddCustomMetric('BatchTimeMs', SW.Elapsed.TotalMilliseconds);
    AddCustomMetric('LogsPerSecond', FBatchSize / SW.Elapsed.TotalSeconds);
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Throughput test failed: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function RunAllLoggingStressTests(DurationSec: Integer; 
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  WriteTest: TLogWriteStressTest;
  LevelTest: TLogLevelMixStressTest;
  LargeTest: TLogLargeMessageStressTest;
  FmtTest: TLogFormattedStressTest;
  ExTest: TLogExceptionStressTest;
  SourceTest: TLogSourceFilterStressTest;
  ThroughputTest: TLogThroughputStressTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;
    
    // Basic write test
    WriteTest := TLogWriteStressTest.Create;
    WriteTest.MessageSize := 100;
    WriteTest.LogLevel := llInfo;
    Runner.AddTest(WriteTest);
    
    // Level mix test
    LevelTest := TLogLevelMixStressTest.Create;
    Runner.AddTest(LevelTest);
    
    // Large message test
    LargeTest := TLogLargeMessageStressTest.Create;
    LargeTest.MessageSizeKB := 5;
    Runner.AddTest(LargeTest);
    
    // Formatted message test
    FmtTest := TLogFormattedStressTest.Create;
    FmtTest.ArgCount := 5;
    Runner.AddTest(FmtTest);
    
    // Exception logging test
    ExTest := TLogExceptionStressTest.Create;
    Runner.AddTest(ExTest);
    
    // Source filter test
    SourceTest := TLogSourceFilterStressTest.Create;
    SourceTest.SourceCount := 10;
    Runner.AddTest(SourceTest);
    
    // Throughput test
    ThroughputTest := TLogThroughputStressTest.Create;
    ThroughputTest.BatchSize := 50;
    Runner.AddTest(ThroughputTest);
    
    Runner.Run;
    
    Result := Runner.Report;
  finally
    Runner.Free;
  end;
end;

end.
