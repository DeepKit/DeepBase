{ ============================================================================
  Stress.Memory48h - 48-Hour Memory Leak Detection Tests

  Extended duration memory tests for detecting subtle leaks:
  - Long-running memory allocation patterns
  - Object lifecycle monitoring
  - Memory trend analysis
  - Handle and resource leak detection
  - Memory fragmentation tracking
  ============================================================================ }

unit Stress.Memory48h;

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
  // TMemoryTrendRecord - Tracks memory usage at specific points
  // ============================================================================

  TMemoryTrendRecord = record
    Timestamp: TDateTime;
    HeapAllocated: Int64;
    HeapUsed: Int64;
    HandleCount: Cardinal;
    ThreadCount: Integer;
    ObjectCount: Int64;
  end;

  // ============================================================================
  // T48HourMemoryLeakTest - Main 48-hour memory test
  // ============================================================================

  T48HourMemoryLeakTest = class(TStressTest)
  private
    FMemoryTrend: TList<TMemoryTrendRecord>;
    FSampleIntervalSec: Integer;
    FLastSample: TDateTime;
    FOperationCount: Int64;
    FInitialMemory: Int64;
    FFinalMemory: Int64;
    FPeakMemory: Int64;
    FLeakThresholdMB: Double;
    FLeakDetected: Boolean;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure TakeSample;
    function AnalyzeMemoryTrend: Double;  // Returns leak rate in bytes/hour
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property SampleIntervalSec: Integer read FSampleIntervalSec write FSampleIntervalSec;
    property LeakThresholdMB: Double read FLeakThresholdMB write FLeakThresholdMB;
  end;

  // ============================================================================
  // TObjectLifecycleMonitorTest - Object creation/destruction monitoring
  // ============================================================================

  TObjectLifecycleMonitorTest = class(TStressTest)
  private
    FObjectsCreated: Int64;
    FObjectsDestroyed: Int64;
    FPeakLiveObjects: Int64;
    FCurrentLiveObjects: Int64;
    FOrphanedObjects: Int64;
    FObjectTypes: TDictionary<string, Int64>;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure CreateTestObject;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

  // ============================================================================
  // TMemoryFragmentationTest - Memory fragmentation tracking
  // ============================================================================

  TMemoryFragmentationTest = class(TStressTest)
  private
    FAllocations: TList<TBytes>;
    FFragmentationSamples: TList<Double>;
    FAllocationPatterns: Integer;  // 0=random, 1=sequential, 2=interleaved
    FMinAllocSize: Integer;
    FMaxAllocSize: Integer;
    FOperationCount: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    function CalculateFragmentation: Double;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property AllocationPatterns: Integer read FAllocationPatterns write FAllocationPatterns;
    property MinAllocSize: Integer read FMinAllocSize write FMinAllocSize;
    property MaxAllocSize: Integer read FMaxAllocSize write FMaxAllocSize;
  end;

  // ============================================================================
  // THandleLeakTest - System handle leak detection
  // ============================================================================

  THandleLeakTest = class(TStressTest)
  private
    FInitialHandleCount: Cardinal;
    FPeakHandleCount: Cardinal;
    FHandlesSamples: TList<Cardinal>;
    FSampleIntervalSec: Integer;
    FLastSample: TDateTime;
    FHandleLeakThreshold: Integer;
    FLeakDetected: Boolean;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure TakeSample;
    function GetCurrentHandleCount: Cardinal;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property SampleIntervalSec: Integer read FSampleIntervalSec write FSampleIntervalSec;
    property HandleLeakThreshold: Integer read FHandleLeakThreshold write FHandleLeakThreshold;
  end;

  // ============================================================================
  // TGDIResourceLeakTest - GDI resource leak detection (Windows)
  // ============================================================================

  TGDIResourceLeakTest = class(TStressTest)
  private
    FInitialGDICount: Cardinal;
    FPeakGDICount: Cardinal;
    FGDISamples: TList<Cardinal>;
    FSampleIntervalSec: Integer;
    FLastSample: TDateTime;
    FGDILeakThreshold: Integer;
    FLeakDetected: Boolean;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure TakeSample;
    function GetCurrentGDICount: Cardinal;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property SampleIntervalSec: Integer read FSampleIntervalSec write FSampleIntervalSec;
    property GDILeakThreshold: Integer read FGDILeakThreshold write FGDILeakThreshold;
  end;

  // ============================================================================
  // TStringLeakTest - String memory leak detection
  // ============================================================================

  TStringLeakTest = class(TStressTest)
  private
    FStringsCreated: Int64;
    FStringsReleased: Int64;
    FPeakStringMemory: Int64;
    FCurrentStringMemory: Int64;
    FStringPool: TList<string>;
    FMaxPoolSize: Integer;
    FOperationCount: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property MaxPoolSize: Integer read FMaxPoolSize write FMaxPoolSize;
  end;

  // ============================================================================
  // TInterfaceLeakTest - Interface reference leak detection
  // ============================================================================

  TInterfaceLeakTest = class(TStressTest)
  private
    FInterfacesCreated: Int64;
    FInterfacesReleased: Int64;
    FPeakRefCount: Int64;
    FRefCountSamples: TList<Int64>;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  end;

  // ============================================================================
  // TMemoryStressWithGCTest - Memory stress with garbage collection patterns
  // ============================================================================

  TMemoryStressWithGCTest = class(TStressTest)
  private
    FAllocationCycles: Int64;
    FMemoryAllocated: Int64;
    FMemoryFreed: Int64;
    FCycleSize: Integer;  // Objects per cycle
    FObjectSizeKB: Integer;
    FGCIntervalOps: Integer;  // Force cleanup every N operations
    FOperationCount: Int64;
    FLock: TCriticalSection;
  protected
    procedure Setup; override;
    procedure Teardown; override;
    procedure Execute; override;
    procedure ForceGarbageCollection;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    property CycleSize: Integer read FCycleSize write FCycleSize;
    property ObjectSizeKB: Integer read FObjectSizeKB write FObjectSizeKB;
    property GCIntervalOps: Integer read FGCIntervalOps write FGCIntervalOps;
  end;

  // ============================================================================
  // Helper functions
  // ============================================================================

  /// <summary>Run 48-hour memory leak test</summary>
  function Run48HourMemoryLeakTest(ThreadCount: Integer = 8): TStressTestReport;

  /// <summary>Run quick memory leak check (1 hour)</summary>
  function RunQuickMemoryLeakCheck: TStressTestReport;

  /// <summary>Run all memory stress tests (configurable duration)</summary>
  function RunAllMemoryStressTests(DurationSec: Integer = 3600;
    ThreadCount: Integer = 8): TStressTestReport;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.PsAPI,
  {$ENDIF}
  System.DateUtils,
  System.Math;

function GetProcessMemoryInfo: Int64;
{$IFDEF MSWINDOWS}
var
  MemCounters: TProcessMemoryCounters;
begin
  MemCounters.cb := SizeOf(MemCounters);
  if Winapi.PsAPI.GetProcessMemoryInfo(GetCurrentProcess, @MemCounters, SizeOf(MemCounters)) then
    Result := MemCounters.WorkingSetSize
  else
    Result := 0;
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

function GetProcessHandleCount: Cardinal;
{$IFDEF MSWINDOWS}
var
  HandleCount: DWORD;
begin
  if Winapi.Windows.GetProcessHandleCount(GetCurrentProcess, HandleCount) then
    Result := HandleCount
  else
    Result := 0;
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

function GetProcessGDICount: Cardinal;
{$IFDEF MSWINDOWS}
begin
  Result := GetGuiResources(GetCurrentProcess, GR_GDIOBJECTS);
end;
{$ELSE}
begin
  Result := 0;
end;
{$ENDIF}

// ============================================================================
// T48HourMemoryLeakTest
// ============================================================================

constructor T48HourMemoryLeakTest.Create;
begin
  inherited Create('Memory48h.LeakDetection', '48-hour memory leak detection test');
  FSampleIntervalSec := 60;  // Sample every minute
  FLeakThresholdMB := 50.0;  // Alert if leak > 50MB over test duration
  FLock := TCriticalSection.Create;
  FMemoryTrend := TList<TMemoryTrendRecord>.Create;
end;

destructor T48HourMemoryLeakTest.Destroy;
begin
  FMemoryTrend.Free;
  FLock.Free;
  inherited;
end;

procedure T48HourMemoryLeakTest.Setup;
begin
  FOperationCount := 0;
  FInitialMemory := GetProcessMemoryInfo;
  FFinalMemory := FInitialMemory;
  FPeakMemory := FInitialMemory;
  FLeakDetected := False;
  FLastSample := Now;
  FMemoryTrend.Clear;

  // Take initial sample
  TakeSample;
end;

procedure T48HourMemoryLeakTest.Teardown;
var
  LeakRate: Double;
begin
  FFinalMemory := GetProcessMemoryInfo;

  AddCustomMetric('InitialMemoryMB', FInitialMemory / (1024 * 1024));
  AddCustomMetric('FinalMemoryMB', FFinalMemory / (1024 * 1024));
  AddCustomMetric('PeakMemoryMB', FPeakMemory / (1024 * 1024));
  AddCustomMetric('MemoryDeltaMB', (FFinalMemory - FInitialMemory) / (1024 * 1024));
  AddCustomMetric('TotalOperations', FOperationCount);
  AddCustomMetric('SampleCount', FMemoryTrend.Count);

  LeakRate := AnalyzeMemoryTrend;
  AddCustomMetric('LeakRateBytesPerHour', LeakRate);
  AddCustomMetric('LeakDetected', Ord(FLeakDetected));
end;

procedure T48HourMemoryLeakTest.TakeSample;
var
  Sample: TMemoryTrendRecord;
begin
  Sample.Timestamp := Now;
  Sample.HeapAllocated := GetProcessMemoryInfo;
  Sample.HeapUsed := Sample.HeapAllocated;  // Simplified
  Sample.HandleCount := GetProcessHandleCount;
  Sample.ThreadCount := 0;  // Would need TlHelp32 to get this accurately
  Sample.ObjectCount := FOperationCount;

  FMemoryTrend.Add(Sample);

  if Sample.HeapAllocated > FPeakMemory then
    FPeakMemory := Sample.HeapAllocated;
end;

function T48HourMemoryLeakTest.AnalyzeMemoryTrend: Double;
var
  I: Integer;
  FirstSample, LastSample: TMemoryTrendRecord;
  TotalHours: Double;
begin
  Result := 0;

  if FMemoryTrend.Count < 2 then Exit;

  FirstSample := FMemoryTrend[0];
  LastSample := FMemoryTrend[FMemoryTrend.Count - 1];

  TotalHours := HourSpan(LastSample.Timestamp, FirstSample.Timestamp);
  if TotalHours < 0.001 then Exit;

  Result := (LastSample.HeapAllocated - FirstSample.HeapAllocated) / TotalHours;

  // Check if leak exceeds threshold
  if (LastSample.HeapAllocated - FirstSample.HeapAllocated) > (FLeakThresholdMB * 1024 * 1024) then
    FLeakDetected := True;
end;

procedure T48HourMemoryLeakTest.Execute;
var
  SW: TStopwatch;
  TempList: TList<Integer>;
  I: Integer;
begin
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FOperationCount);

    // Perform memory operations
    TempList := TList<Integer>.Create;
    try
      for I := 1 to Random(100) + 50 do
        TempList.Add(I);

      // Some work
      TempList.Sort;
    finally
      TempList.Free;
    end;

    // Periodic sampling
    if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
    begin
      FLock.Enter;
      try
        if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
        begin
          TakeSample;
          FLastSample := Now;
        end;
      finally
        FLock.Leave;
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
      ReportError('Memory test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TObjectLifecycleMonitorTest
// ============================================================================

type
  TTestObject = class
  private
    FData: TBytes;
    FID: Integer;
  public
    constructor Create(AID: Integer; Size: Integer);
    destructor Destroy; override;
  end;

var
  GObjectCounter: Int64 = 0;

constructor TTestObject.Create(AID: Integer; Size: Integer);
begin
  inherited Create;
  FID := AID;
  SetLength(FData, Size);
  FillChar(FData[0], Size, $AA);
  TInterlocked.Increment(GObjectCounter);
end;

destructor TTestObject.Destroy;
begin
  SetLength(FData, 0);
  TInterlocked.Decrement(GObjectCounter);
  inherited;
end;

constructor TObjectLifecycleMonitorTest.Create;
begin
  inherited Create('Memory48h.ObjectLifecycle', 'Object creation/destruction monitoring');
  FLock := TCriticalSection.Create;
  FObjectTypes := TDictionary<string, Int64>.Create;
end;

destructor TObjectLifecycleMonitorTest.Destroy;
begin
  FObjectTypes.Free;
  FLock.Free;
  inherited;
end;

procedure TObjectLifecycleMonitorTest.Setup;
begin
  FObjectsCreated := 0;
  FObjectsDestroyed := 0;
  FPeakLiveObjects := 0;
  FCurrentLiveObjects := 0;
  FOrphanedObjects := 0;
  FObjectTypes.Clear;
end;

procedure TObjectLifecycleMonitorTest.Teardown;
begin
  AddCustomMetric('ObjectsCreated', FObjectsCreated);
  AddCustomMetric('ObjectsDestroyed', FObjectsDestroyed);
  AddCustomMetric('PeakLiveObjects', FPeakLiveObjects);
  AddCustomMetric('OrphanedObjects', FObjectsCreated - FObjectsDestroyed);
  AddCustomMetric('GlobalObjectCounter', GObjectCounter);
end;

procedure TObjectLifecycleMonitorTest.CreateTestObject;
var
  Obj: TTestObject;
  LiveCount: Int64;
begin
  Obj := TTestObject.Create(TInterlocked.Increment(FObjectsCreated), Random(1024) + 100);
  try
    LiveCount := TInterlocked.Increment(FCurrentLiveObjects);

    FLock.Enter;
    try
      if LiveCount > FPeakLiveObjects then
        FPeakLiveObjects := LiveCount;
    finally
      FLock.Leave;
    end;

    // Simulate work
    Sleep(1);
  finally
    TInterlocked.Decrement(FCurrentLiveObjects);
    TInterlocked.Increment(FObjectsDestroyed);
    Obj.Free;
  end;
end;

procedure TObjectLifecycleMonitorTest.Execute;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    CreateTestObject;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Object lifecycle error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TMemoryFragmentationTest
// ============================================================================

constructor TMemoryFragmentationTest.Create;
begin
  inherited Create('Memory48h.Fragmentation', 'Memory fragmentation tracking');
  FMinAllocSize := 100;
  FMaxAllocSize := 10000;
  FAllocationPatterns := 0;  // Random
  FLock := TCriticalSection.Create;
  FAllocations := TList<TBytes>.Create;
  FFragmentationSamples := TList<Double>.Create;
end;

destructor TMemoryFragmentationTest.Destroy;
begin
  FFragmentationSamples.Free;
  FAllocations.Free;
  FLock.Free;
  inherited;
end;

procedure TMemoryFragmentationTest.Setup;
begin
  FOperationCount := 0;
  FAllocations.Clear;
  FFragmentationSamples.Clear;
end;

procedure TMemoryFragmentationTest.Teardown;
var
  AvgFrag: Double;
  I: Integer;
begin
  AddCustomMetric('TotalOperations', FOperationCount);
  AddCustomMetric('RemainingAllocations', FAllocations.Count);
  AddCustomMetric('FragmentationSamples', FFragmentationSamples.Count);

  if FFragmentationSamples.Count > 0 then
  begin
    AvgFrag := 0;
    for I := 0 to FFragmentationSamples.Count - 1 do
      AvgFrag := AvgFrag + FFragmentationSamples[I];
    AvgFrag := AvgFrag / FFragmentationSamples.Count;
    AddCustomMetric('AvgFragmentation', AvgFrag);
  end;

  // Clean up
  FAllocations.Clear;
end;

function TMemoryFragmentationTest.CalculateFragmentation: Double;
var
  TotalSize, MaxSize: Int64;
  I: Integer;
begin
  // Simple fragmentation metric based on allocation size distribution
  TotalSize := 0;
  MaxSize := 0;

  for I := 0 to FAllocations.Count - 1 do
  begin
    TotalSize := TotalSize + Length(FAllocations[I]);
    if Length(FAllocations[I]) > MaxSize then
      MaxSize := Length(FAllocations[I]);
  end;

  if TotalSize > 0 then
    Result := 1.0 - (MaxSize / TotalSize)  // Higher = more fragmented
  else
    Result := 0;
end;

procedure TMemoryFragmentationTest.Execute;
var
  SW: TStopwatch;
  Buffer: TBytes;
  Size: Integer;
  ShouldAllocate: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FOperationCount);

    FLock.Enter;
    try
      ShouldAllocate := (FAllocations.Count < 1000) and (Random > 0.3);

      if ShouldAllocate then
      begin
        // Allocate with varying patterns
        case FAllocationPatterns of
          0: Size := Random(FMaxAllocSize - FMinAllocSize) + FMinAllocSize;
          1: Size := FMinAllocSize + (FOperationCount mod 100) * 10;
          2: Size := IfThen(FOperationCount mod 2 = 0, FMinAllocSize, FMaxAllocSize);
        else
          Size := Random(FMaxAllocSize - FMinAllocSize) + FMinAllocSize;
        end;

        SetLength(Buffer, Size);
        FillChar(Buffer[0], Size, $BB);
        FAllocations.Add(Buffer);
      end
      else if FAllocations.Count > 0 then
      begin
        // Free random allocation
        FAllocations.Delete(Random(FAllocations.Count));
      end;

      // Sample fragmentation periodically
      if FOperationCount mod 100 = 0 then
        FFragmentationSamples.Add(CalculateFragmentation);
    finally
      FLock.Leave;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Fragmentation test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// THandleLeakTest
// ============================================================================

constructor THandleLeakTest.Create;
begin
  inherited Create('Memory48h.HandleLeak', 'System handle leak detection');
  FSampleIntervalSec := 30;
  FHandleLeakThreshold := 100;
  FLock := TCriticalSection.Create;
  FHandlesSamples := TList<Cardinal>.Create;
end;

destructor THandleLeakTest.Destroy;
begin
  FHandlesSamples.Free;
  FLock.Free;
  inherited;
end;

procedure THandleLeakTest.Setup;
begin
  FInitialHandleCount := GetCurrentHandleCount;
  FPeakHandleCount := FInitialHandleCount;
  FLeakDetected := False;
  FLastSample := Now;
  FHandlesSamples.Clear;
  FHandlesSamples.Add(FInitialHandleCount);
end;

procedure THandleLeakTest.Teardown;
var
  FinalCount: Cardinal;
begin
  FinalCount := GetCurrentHandleCount;

  AddCustomMetric('InitialHandles', FInitialHandleCount);
  AddCustomMetric('FinalHandles', FinalCount);
  AddCustomMetric('PeakHandles', FPeakHandleCount);
  AddCustomMetric('HandleDelta', Integer(FinalCount) - Integer(FInitialHandleCount));
  AddCustomMetric('LeakDetected', Ord(FLeakDetected));
  AddCustomMetric('SampleCount', FHandlesSamples.Count);
end;

function THandleLeakTest.GetCurrentHandleCount: Cardinal;
begin
  Result := GetProcessHandleCount;
end;

procedure THandleLeakTest.TakeSample;
var
  CurrentCount: Cardinal;
begin
  CurrentCount := GetCurrentHandleCount;
  FHandlesSamples.Add(CurrentCount);

  if CurrentCount > FPeakHandleCount then
    FPeakHandleCount := CurrentCount;

  if Integer(CurrentCount) - Integer(FInitialHandleCount) > FHandleLeakThreshold then
    FLeakDetected := True;
end;

procedure THandleLeakTest.Execute;
var
  SW: TStopwatch;
  H: THandle;
begin
  SW := TStopwatch.StartNew;
  try
    // Create and properly release handles
    H := CreateEvent(nil, False, False, nil);
    if H <> 0 then
    begin
      Sleep(1);
      CloseHandle(H);
    end;

    // Periodic sampling
    if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
    begin
      FLock.Enter;
      try
        if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
        begin
          TakeSample;
          FLastSample := Now;
        end;
      finally
        FLock.Leave;
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
      ReportError('Handle leak test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TGDIResourceLeakTest
// ============================================================================

constructor TGDIResourceLeakTest.Create;
begin
  inherited Create('Memory48h.GDILeak', 'GDI resource leak detection');
  FSampleIntervalSec := 30;
  FGDILeakThreshold := 50;
  FLock := TCriticalSection.Create;
  FGDISamples := TList<Cardinal>.Create;
end;

destructor TGDIResourceLeakTest.Destroy;
begin
  FGDISamples.Free;
  FLock.Free;
  inherited;
end;

procedure TGDIResourceLeakTest.Setup;
begin
  FInitialGDICount := GetCurrentGDICount;
  FPeakGDICount := FInitialGDICount;
  FLeakDetected := False;
  FLastSample := Now;
  FGDISamples.Clear;
  FGDISamples.Add(FInitialGDICount);
end;

procedure TGDIResourceLeakTest.Teardown;
var
  FinalCount: Cardinal;
begin
  FinalCount := GetCurrentGDICount;

  AddCustomMetric('InitialGDI', FInitialGDICount);
  AddCustomMetric('FinalGDI', FinalCount);
  AddCustomMetric('PeakGDI', FPeakGDICount);
  AddCustomMetric('GDIDelta', Integer(FinalCount) - Integer(FInitialGDICount));
  AddCustomMetric('LeakDetected', Ord(FLeakDetected));
  AddCustomMetric('SampleCount', FGDISamples.Count);
end;

function TGDIResourceLeakTest.GetCurrentGDICount: Cardinal;
begin
  Result := GetProcessGDICount;
end;

procedure TGDIResourceLeakTest.TakeSample;
var
  CurrentCount: Cardinal;
begin
  CurrentCount := GetCurrentGDICount;
  FGDISamples.Add(CurrentCount);

  if CurrentCount > FPeakGDICount then
    FPeakGDICount := CurrentCount;

  if Integer(CurrentCount) - Integer(FInitialGDICount) > FGDILeakThreshold then
    FLeakDetected := True;
end;

procedure TGDIResourceLeakTest.Execute;
var
  SW: TStopwatch;
begin
  SW := TStopwatch.StartNew;
  try
    // GDI operations would go here if testing GUI components
    // For non-GUI test, just sample
    Sleep(1);

    // Periodic sampling
    if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
    begin
      FLock.Enter;
      try
        if SecondSpan(Now, FLastSample) >= FSampleIntervalSec then
        begin
          TakeSample;
          FLastSample := Now;
        end;
      finally
        FLock.Leave;
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
      ReportError('GDI leak test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TStringLeakTest
// ============================================================================

constructor TStringLeakTest.Create;
begin
  inherited Create('Memory48h.StringLeak', 'String memory leak detection');
  FMaxPoolSize := 500;
  FLock := TCriticalSection.Create;
  FStringPool := TList<string>.Create;
end;

destructor TStringLeakTest.Destroy;
begin
  FStringPool.Free;
  FLock.Free;
  inherited;
end;

procedure TStringLeakTest.Setup;
begin
  FStringsCreated := 0;
  FStringsReleased := 0;
  FPeakStringMemory := 0;
  FCurrentStringMemory := 0;
  FOperationCount := 0;
  FStringPool.Clear;
end;

procedure TStringLeakTest.Teardown;
begin
  AddCustomMetric('StringsCreated', FStringsCreated);
  AddCustomMetric('StringsReleased', FStringsReleased);
  AddCustomMetric('PeakStringMemoryKB', FPeakStringMemory / 1024);
  AddCustomMetric('RemainingStrings', FStringPool.Count);

  FStringPool.Clear;
end;

procedure TStringLeakTest.Execute;
var
  SW: TStopwatch;
  S: string;
  StrLen: Integer;
  ShouldAdd: Boolean;
begin
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FOperationCount);

    FLock.Enter;
    try
      ShouldAdd := (FStringPool.Count < FMaxPoolSize) and (Random > 0.4);

      if ShouldAdd then
      begin
        StrLen := Random(1000) + 100;
        S := StringOfChar('X', StrLen);
        FStringPool.Add(S);
        TInterlocked.Increment(FStringsCreated);
        FCurrentStringMemory := FCurrentStringMemory + StrLen * SizeOf(Char);

        if FCurrentStringMemory > FPeakStringMemory then
          FPeakStringMemory := FCurrentStringMemory;
      end
      else if FStringPool.Count > 0 then
      begin
        StrLen := Length(FStringPool[0]);
        FStringPool.Delete(0);
        TInterlocked.Increment(FStringsReleased);
        FCurrentStringMemory := FCurrentStringMemory - StrLen * SizeOf(Char);
      end;
    finally
      FLock.Leave;
    end;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('String leak test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TInterfaceLeakTest
// ============================================================================

type
  ITestInterface = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure DoSomething;
  end;

  TTestInterfaceImpl = class(TInterfacedObject, ITestInterface)
  public
    procedure DoSomething;
  end;

procedure TTestInterfaceImpl.DoSomething;
begin
  // Empty
end;

constructor TInterfaceLeakTest.Create;
begin
  inherited Create('Memory48h.InterfaceLeak', 'Interface reference leak detection');
  FLock := TCriticalSection.Create;
  FRefCountSamples := TList<Int64>.Create;
end;

destructor TInterfaceLeakTest.Destroy;
begin
  FRefCountSamples.Free;
  FLock.Free;
  inherited;
end;

procedure TInterfaceLeakTest.Setup;
begin
  FInterfacesCreated := 0;
  FInterfacesReleased := 0;
  FPeakRefCount := 0;
  FRefCountSamples.Clear;
end;

procedure TInterfaceLeakTest.Teardown;
begin
  AddCustomMetric('InterfacesCreated', FInterfacesCreated);
  AddCustomMetric('InterfacesReleased', FInterfacesReleased);
  AddCustomMetric('PeakRefCount', FPeakRefCount);
  AddCustomMetric('Balance', FInterfacesCreated - FInterfacesReleased);
end;

procedure TInterfaceLeakTest.Execute;
var
  SW: TStopwatch;
  Intf: ITestInterface;
  RefCount: Int64;
begin
  SW := TStopwatch.StartNew;
  try
    Intf := TTestInterfaceImpl.Create;
    TInterlocked.Increment(FInterfacesCreated);

    RefCount := TInterlocked.Increment(FPeakRefCount);
    FLock.Enter;
    try
      if RefCount > FPeakRefCount then
        FPeakRefCount := RefCount;
    finally
      FLock.Leave;
    end;

    Intf.DoSomething;

    Intf := nil;  // Release
    TInterlocked.Increment(FInterfacesReleased);

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('Interface leak test error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// TMemoryStressWithGCTest
// ============================================================================

constructor TMemoryStressWithGCTest.Create;
begin
  inherited Create('Memory48h.GCStress', 'Memory stress with garbage collection');
  FCycleSize := 50;
  FObjectSizeKB := 10;
  FGCIntervalOps := 1000;
  FLock := TCriticalSection.Create;
end;

destructor TMemoryStressWithGCTest.Destroy;
begin
  FLock.Free;
  inherited;
end;

procedure TMemoryStressWithGCTest.Setup;
begin
  FAllocationCycles := 0;
  FMemoryAllocated := 0;
  FMemoryFreed := 0;
  FOperationCount := 0;
end;

procedure TMemoryStressWithGCTest.Teardown;
begin
  AddCustomMetric('AllocationCycles', FAllocationCycles);
  AddCustomMetric('MemoryAllocatedMB', FMemoryAllocated / (1024 * 1024));
  AddCustomMetric('MemoryFreedMB', FMemoryFreed / (1024 * 1024));
  AddCustomMetric('NetMemoryMB', (FMemoryAllocated - FMemoryFreed) / (1024 * 1024));
  AddCustomMetric('TotalOperations', FOperationCount);
end;

procedure TMemoryStressWithGCTest.ForceGarbageCollection;
begin
  // In Delphi, there's no explicit GC, but we can hint to free unused memory
  // by ensuring all references are nil and memory manager can reclaim
end;

procedure TMemoryStressWithGCTest.Execute;
var
  SW: TStopwatch;
  Objects: TObjectList<TTestObject>;
  I: Integer;
  BytesAllocated: Int64;
begin
  SW := TStopwatch.StartNew;
  try
    TInterlocked.Increment(FOperationCount);

    Objects := TObjectList<TTestObject>.Create(True);
    try
      BytesAllocated := 0;

      // Allocate objects
      for I := 1 to FCycleSize do
      begin
        Objects.Add(TTestObject.Create(I, FObjectSizeKB * 1024));
        BytesAllocated := BytesAllocated + FObjectSizeKB * 1024;
      end;

      TInterlocked.Add(FMemoryAllocated, BytesAllocated);
      TInterlocked.Increment(FAllocationCycles);

      // Simulate work
      Sleep(5);
    finally
      Objects.Free;
      TInterlocked.Add(FMemoryFreed, BytesAllocated);
    end;

    // Periodic GC hint
    if FOperationCount mod FGCIntervalOps = 0 then
      ForceGarbageCollection;

    SW.Stop;
    ReportLatency(SW.Elapsed.TotalMilliseconds);
    ReportSuccess;
  except
    on E: Exception do
    begin
      SW.Stop;
      ReportLatency(SW.Elapsed.TotalMilliseconds);
      ReportError('GC stress error: ' + E.Message);
    end;
  end;
end;

// ============================================================================
// Helper functions
// ============================================================================

function Run48HourMemoryLeakTest(ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  LeakTest: T48HourMemoryLeakTest;
begin
  Runner := TStressTestRunner.Create;
  try
    // 48 hours = 172800 seconds
    Runner.Config.DurationSec := 48 * 60 * 60;
    Runner.Config.ThreadCount := ThreadCount;

    LeakTest := T48HourMemoryLeakTest.Create;
    LeakTest.SampleIntervalSec := 60;  // Sample every minute
    LeakTest.LeakThresholdMB := 100.0;  // Alert if > 100MB leak
    Runner.AddTest(LeakTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

function RunQuickMemoryLeakCheck: TStressTestReport;
begin
  // 1 hour quick check
  Result := RunAllMemoryStressTests(3600, 8);
end;

function RunAllMemoryStressTests(DurationSec: Integer;
  ThreadCount: Integer): TStressTestReport;
var
  Runner: TStressTestRunner;
  LeakTest: T48HourMemoryLeakTest;
  ObjectTest: TObjectLifecycleMonitorTest;
  FragTest: TMemoryFragmentationTest;
  HandleTest: THandleLeakTest;
  GDITest: TGDIResourceLeakTest;
  StringTest: TStringLeakTest;
  IntfTest: TInterfaceLeakTest;
  GCTest: TMemoryStressWithGCTest;
begin
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := DurationSec;
    Runner.Config.ThreadCount := ThreadCount;

    // Memory leak detection
    LeakTest := T48HourMemoryLeakTest.Create;
    LeakTest.SampleIntervalSec := DurationSec div 60;
    Runner.AddTest(LeakTest);

    // Object lifecycle
    ObjectTest := TObjectLifecycleMonitorTest.Create;
    Runner.AddTest(ObjectTest);

    // Fragmentation
    FragTest := TMemoryFragmentationTest.Create;
    FragTest.MinAllocSize := 100;
    FragTest.MaxAllocSize := 5000;
    Runner.AddTest(FragTest);

    // Handle leak
    HandleTest := THandleLeakTest.Create;
    HandleTest.SampleIntervalSec := DurationSec div 30;
    Runner.AddTest(HandleTest);

    // GDI leak
    GDITest := TGDIResourceLeakTest.Create;
    GDITest.SampleIntervalSec := DurationSec div 30;
    Runner.AddTest(GDITest);

    // String leak
    StringTest := TStringLeakTest.Create;
    StringTest.MaxPoolSize := 300;
    Runner.AddTest(StringTest);

    // Interface leak
    IntfTest := TInterfaceLeakTest.Create;
    Runner.AddTest(IntfTest);

    // GC stress
    GCTest := TMemoryStressWithGCTest.Create;
    GCTest.CycleSize := 30;
    GCTest.ObjectSizeKB := 5;
    Runner.AddTest(GCTest);

    Runner.Run;

    Result := Runner.Report.Clone;
  finally
    Runner.Free;
  end;
end;

end.
