{ ============================================================================
  Test.Regression.BUG328_MetricsConcurrentInit - REVIEW5-CORE-006

  Verifies that TMetrics global registry handles concurrent first access:
  - Multiple threads calling TMetrics.Counter simultaneously don't crash
  - Each thread gets a valid counter reference
  - The registry is initialized exactly once (singleton)
  ============================================================================ }

unit Test.Regression.BUG328_MetricsConcurrentInit;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Metrics;

type
  [TestFixture]
  [Category('regression')]
  TBUG328_MetricsConcurrentInitTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_ConcurrentCounter_FirstAccess;

    [Test]
    procedure Test_ConcurrentGauge_FirstAccess;

    [Test]
    procedure Test_Registry_Singleton;
  end;

implementation

type
  TCounterWorker = class(TThread)
  private
    FIndex: Integer;
    FCounter: TCounter;
    FError: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AIndex: Integer);
    property Counter: TCounter read FCounter;
    property HadError: Boolean read FError;
  end;

  TGaugeWorker = class(TThread)
  private
    FIndex: Integer;
    FGauge: TGauge;
    FError: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AIndex: Integer);
    property Gauge: TGauge read FGauge;
    property HadError: Boolean read FError;
  end;

constructor TCounterWorker.Create(AIndex: Integer);
begin
  inherited Create(True); // suspended; Start called after all are created
  FreeOnTerminate := False;
  FIndex := AIndex;
  FCounter := nil;
  FError := False;
end;

procedure TCounterWorker.Execute;
begin
  try
    FCounter := TMetrics.Counter(
      'concurrent_test_counter_' + IntToStr(FIndex),
      'Concurrent test counter');
  except
    FError := True;
  end;
end;

constructor TGaugeWorker.Create(AIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FIndex := AIndex;
  FGauge := nil;
  FError := False;
end;

procedure TGaugeWorker.Execute;
begin
  try
    FGauge := TMetrics.Gauge(
      'concurrent_test_gauge_' + IntToStr(FIndex),
      'Concurrent test gauge');
  except
    FError := True;
  end;
end;

{ TBUG328_MetricsConcurrentInitTest }

function TBUG328_MetricsConcurrentInitTest.GetBugNumber: string;
begin
  Result := 'BUG-328';
end;

function TBUG328_MetricsConcurrentInitTest.GetBugDescription: string;
begin
  Result := 'TMetrics global registry concurrent first access race condition';
end;

function TBUG328_MetricsConcurrentInitTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG328_MetricsConcurrentInitTest.GetPriority: string;
begin
  Result := 'P2';
end;

function TBUG328_MetricsConcurrentInitTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Metrics.pas';
end;

procedure TBUG328_MetricsConcurrentInitTest.Test_ConcurrentCounter_FirstAccess;
const
  CThreadCount = 4;
var
  LThreads: array of TCounterWorker;
  I: Integer;
  LErrors: Integer;
begin
  LErrors := 0;
  SetLength(LThreads, CThreadCount);

  // Create all threads suspended
  for I := 0 to CThreadCount - 1 do
    LThreads[I] := TCounterWorker.Create(I);

  // Start all threads; they'll naturally run concurrently
  for I := 0 to CThreadCount - 1 do
    LThreads[I].Start;

  // Wait for completion
  for I := 0 to CThreadCount - 1 do
  begin
    LThreads[I].WaitFor;
    if LThreads[I].HadError then
      Inc(LErrors);
  end;

  Assert.AreEqual(0, LErrors, 'No errors should occur during concurrent Counter access');

  for I := 0 to CThreadCount - 1 do
  try
    Assert.IsTrue(Assigned(LThreads[I].Counter),
      'Counter ' + IntToStr(I) + ' should be assigned');
  finally
    LThreads[I].Free;
  end;
end;

procedure TBUG328_MetricsConcurrentInitTest.Test_ConcurrentGauge_FirstAccess;
const
  CThreadCount = 4;
var
  LThreads: array of TGaugeWorker;
  I: Integer;
  LErrors: Integer;
begin
  LErrors := 0;
  SetLength(LThreads, CThreadCount);

  for I := 0 to CThreadCount - 1 do
    LThreads[I] := TGaugeWorker.Create(I);

  for I := 0 to CThreadCount - 1 do
    LThreads[I].Start;

  for I := 0 to CThreadCount - 1 do
  begin
    LThreads[I].WaitFor;
    if LThreads[I].HadError then
      Inc(LErrors);
  end;

  Assert.AreEqual(0, LErrors, 'No errors should occur during concurrent Gauge access');

  for I := 0 to CThreadCount - 1 do
  try
    Assert.IsTrue(Assigned(LThreads[I].Gauge),
      'Gauge ' + IntToStr(I) + ' should be assigned');
  finally
    LThreads[I].Free;
  end;
end;

procedure TBUG328_MetricsConcurrentInitTest.Test_Registry_Singleton;
var
  LReg1, LReg2: TMetricsRegistry;
begin
  LReg1 := TMetrics.Registry;
  LReg2 := TMetrics.Registry;

  Assert.IsTrue(Assigned(LReg1), 'Registry should be assigned');
  Assert.AreEqual(NativeInt(LReg1), NativeInt(LReg2),
    'Registry should return the same instance (singleton)');
end;

end.
