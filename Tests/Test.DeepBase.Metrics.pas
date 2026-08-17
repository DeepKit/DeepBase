unit Test.DeepBase.Metrics;

{*******************************************************************************
  Unit Tests for DeepBase.Metrics
  Tests counters, gauges, histograms, timers and metrics registry
*******************************************************************************}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestDeepBaseMetrics = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TCounter Tests
    [Test]
    procedure TestCounterCreate;
    [Test]
    procedure TestCounterInc;
    [Test]
    procedure TestCounterIncAmount;
    [Test]
    procedure TestCounterReset;
    [Test]
    procedure TestCounterToJSON;
    [Test]
    procedure TestCounterToPrometheus;

    // TGauge Tests
    [Test]
    procedure TestGaugeCreate;
    [Test]
    procedure TestGaugeSetValue;
    [Test]
    procedure TestGaugeIncDec;
    [Test]
    procedure TestGaugeToJSON;
    [Test]
    procedure TestGaugeToPrometheus;

    // THistogram Tests
    [Test]
    procedure TestHistogramCreate;
    [Test]
    procedure TestHistogramObserve;
    [Test]
    procedure TestHistogramStats;
    [Test]
    procedure TestHistogramBuckets;
    [Test]
    procedure TestHistogramDefaultBuckets;
    [Test]
    procedure TestHistogramLinearBuckets;
    [Test]
    procedure TestHistogramExponentialBuckets;
    [Test]
    procedure TestHistogramToPrometheus;

    // TTimer Tests
    [Test]
    procedure TestTimerCreate;
    [Test]
    procedure TestTimerRecordDuration;
    [Test]
    procedure TestTimerTime;
    [Test]
    procedure TestTimerStart;

    // TSummary Tests
    [Test]
    procedure TestSummaryCreate;
    [Test]
    procedure TestSummaryObserve;
    [Test]
    procedure TestSummaryQuantiles;

    // TMetricFamily Tests
    [Test]
    procedure TestMetricFamilyCreate;
    [Test]
    procedure TestMetricFamilyWithLabels;

    // TMetricsRegistry Tests
    [Test]
    procedure TestRegistryCreate;
    [Test]
    procedure TestRegistryCounter;
    [Test]
    procedure TestRegistryGauge;
    [Test]
    procedure TestRegistryHistogram;
    [Test]
    procedure TestRegistryGetAll;
    [Test]
    procedure TestRegistryToJSON;
    [Test]
    procedure TestRegistryToPrometheus;
    [Test]
    procedure TestRegistryToInfluxLines;

    // Thread Safety Tests
    [Test]
    procedure TestCounterThreadSafety;
    [Test]
    procedure TestGaugeThreadSafety;

    // TMetrics Static Helper Tests
    [Test]
    procedure TestMetricsStaticCounter;
    [Test]
    procedure TestMetricsStaticGauge;
    [Test]
    procedure TestMetricsStaticRegistryConcurrent;
  end;

implementation

uses
  System.SysUtils, System.Classes, System.JSON, System.SyncObjs,
  DeepBase.Metrics;

const
  EPSILON = 1E-9;

procedure TTestDeepBaseMetrics.Setup;
begin
end;

procedure TTestDeepBaseMetrics.TearDown;
begin
end;

// TCounter Tests

procedure TTestDeepBaseMetrics.TestCounterCreate;
var
  Counter: TCounter;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Assert.AreEqual('test_counter', Counter.Name);
    Assert.AreEqual('Test counter', Counter.Description);
    Assert.AreEqual(Int64(0), Counter.Value);
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestCounterInc;
var
  Counter: TCounter;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Counter.Inc;
    Assert.AreEqual(Int64(1), Counter.Value);
    Counter.Inc;
    Assert.AreEqual(Int64(2), Counter.Value);
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestCounterIncAmount;
var
  Counter: TCounter;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Counter.Inc(5);
    Assert.AreEqual(Int64(5), Counter.Value);
    Counter.Inc(10);
    Assert.AreEqual(Int64(15), Counter.Value);
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestCounterReset;
var
  Counter: TCounter;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Counter.Inc(100);
    Assert.AreEqual(Int64(100), Counter.Value);
    Counter.Reset;
    Assert.AreEqual(Int64(0), Counter.Value);
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestCounterToJSON;
var
  Counter: TCounter;
  JSON: TJSONObject;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Counter.Inc(42);
    JSON := Counter.ToJSON;
    try
      Assert.AreEqual('test_counter', JSON.GetValue<string>('name'));
      Assert.AreEqual(Int64(42), JSON.GetValue<Int64>('value'));
    finally
      JSON.Free;
    end;
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestCounterToPrometheus;
var
  Counter: TCounter;
  S: string;
begin
  Counter := TCounter.Create('test_counter', 'Test counter', []);
  try
    Counter.Inc(42);
    S := Counter.ToPrometheus;
    Assert.IsTrue(S.Contains('test_counter'));
    Assert.IsTrue(S.Contains('42'));
  finally
    Counter.Free;
  end;
end;

// TGauge Tests

procedure TTestDeepBaseMetrics.TestGaugeCreate;
var
  Gauge: TGauge;
begin
  Gauge := TGauge.Create('test_gauge', 'Test gauge', []);
  try
    Assert.AreEqual('test_gauge', Gauge.Name);
    Assert.AreEqual(0.0, Gauge.Value, EPSILON);
  finally
    Gauge.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestGaugeSetValue;
var
  Gauge: TGauge;
begin
  Gauge := TGauge.Create('test_gauge', 'Test gauge', []);
  try
    Gauge.SetValue(42.5);
    Assert.AreEqual(42.5, Gauge.Value, EPSILON);
    Gauge.SetValue(-10.0);
    Assert.AreEqual(-10.0, Gauge.Value, EPSILON);
  finally
    Gauge.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestGaugeIncDec;
var
  Gauge: TGauge;
begin
  Gauge := TGauge.Create('test_gauge', 'Test gauge', []);
  try
    Gauge.Inc;
    Assert.AreEqual(1.0, Gauge.Value, EPSILON);
    Gauge.Inc(5.0);
    Assert.AreEqual(6.0, Gauge.Value, EPSILON);
    Gauge.Dec;
    Assert.AreEqual(5.0, Gauge.Value, EPSILON);
    Gauge.Dec(3.0);
    Assert.AreEqual(2.0, Gauge.Value, EPSILON);
  finally
    Gauge.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestGaugeToJSON;
var
  Gauge: TGauge;
  JSON: TJSONObject;
begin
  Gauge := TGauge.Create('test_gauge', 'Test gauge', []);
  try
    Gauge.SetValue(3.14);
    JSON := Gauge.ToJSON;
    try
      Assert.AreEqual('test_gauge', JSON.GetValue<string>('name'));
      Assert.AreEqual(3.14, JSON.GetValue<Double>('value'), EPSILON);
    finally
      JSON.Free;
    end;
  finally
    Gauge.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestGaugeToPrometheus;
var
  Gauge: TGauge;
  S: string;
begin
  Gauge := TGauge.Create('test_gauge', 'Test gauge', []);
  try
    Gauge.SetValue(99.9);
    S := Gauge.ToPrometheus;
    Assert.IsTrue(S.Contains('test_gauge'));
  finally
    Gauge.Free;
  end;
end;

// THistogram Tests

procedure TTestDeepBaseMetrics.TestHistogramCreate;
var
  Histogram: THistogram;
begin
  Histogram := THistogram.Create('test_histogram', 'Test histogram', [],
    THistogram.DefaultBuckets);
  try
    Assert.AreEqual('test_histogram', Histogram.Name);
    Assert.AreEqual(Int64(0), Histogram.Count);
  finally
    Histogram.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestHistogramObserve;
var
  Histogram: THistogram;
begin
  Histogram := THistogram.Create('test_histogram', 'Test histogram', [],
    [1.0, 5.0, 10.0]);
  try
    Histogram.Observe(0.5);
    Histogram.Observe(3.0);
    Histogram.Observe(7.0);
    Assert.AreEqual(Int64(3), Histogram.Count);
    Assert.AreEqual(10.5, Histogram.Sum, EPSILON);
  finally
    Histogram.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestHistogramStats;
var
  Histogram: THistogram;
begin
  Histogram := THistogram.Create('test_histogram', 'Test histogram', [],
    [1.0, 5.0, 10.0]);
  try
    Histogram.Observe(2.0);
    Histogram.Observe(4.0);
    Histogram.Observe(6.0);
    Assert.AreEqual(2.0, Histogram.Min, EPSILON);
    Assert.AreEqual(6.0, Histogram.Max, EPSILON);
    Assert.AreEqual(4.0, Histogram.Mean, EPSILON);
  finally
    Histogram.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestHistogramBuckets;
var
  Histogram: THistogram;
  Buckets: TArray<THistogramBucket>;
begin
  Histogram := THistogram.Create('test_histogram', 'Test histogram', [],
    [1.0, 5.0, 10.0]);
  try
    Histogram.Observe(0.5);  // <= 1.0
    Histogram.Observe(3.0);  // <= 5.0
    Histogram.Observe(7.0);  // <= 10.0
    Histogram.Observe(15.0); // > 10.0

    Buckets := Histogram.Buckets;
    Assert.AreEqual<Integer>(4, Length(Buckets));
    Assert.AreEqual(Int64(1), Buckets[0].Count);
    Assert.AreEqual(Int64(2), Buckets[1].Count);
    Assert.AreEqual(Int64(3), Buckets[2].Count);
    Assert.AreEqual(Int64(4), Buckets[3].Count);
  finally
    Histogram.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestHistogramDefaultBuckets;
var
  Buckets: TArray<Double>;
begin
  Buckets := THistogram.DefaultBuckets;
  Assert.IsTrue(Length(Buckets) > 0);
  Assert.AreEqual(0.005, Buckets[0], EPSILON);
end;

procedure TTestDeepBaseMetrics.TestHistogramLinearBuckets;
var
  Buckets: TArray<Double>;
begin
  Buckets := THistogram.LinearBuckets(0.0, 1.0, 5);
  Assert.AreEqual<Integer>(5, Length(Buckets));
  Assert.AreEqual(0.0, Buckets[0], EPSILON);
  Assert.AreEqual(1.0, Buckets[1], EPSILON);
  Assert.AreEqual(4.0, Buckets[4], EPSILON);
end;

procedure TTestDeepBaseMetrics.TestHistogramExponentialBuckets;
var
  Buckets: TArray<Double>;
begin
  Buckets := THistogram.ExponentialBuckets(1.0, 2.0, 4);
  Assert.AreEqual<Integer>(4, Length(Buckets));
  Assert.AreEqual(1.0, Buckets[0], EPSILON);
  Assert.AreEqual(2.0, Buckets[1], EPSILON);
  Assert.AreEqual(4.0, Buckets[2], EPSILON);
  Assert.AreEqual(8.0, Buckets[3], EPSILON);
end;

procedure TTestDeepBaseMetrics.TestHistogramToPrometheus;
var
  Histogram: THistogram;
  S: string;
begin
  Histogram := THistogram.Create('test_histogram', 'Test histogram', [],
    [1.0, 5.0]);
  try
    Histogram.Observe(0.5);
    S := Histogram.ToPrometheus;
    Assert.IsTrue(S.Contains('test_histogram'));
    Assert.IsTrue(S.Contains('bucket'));
  finally
    Histogram.Free;
  end;
end;

// TTimer Tests

procedure TTestDeepBaseMetrics.TestTimerCreate;
var
  Timer: TTimer;
begin
  Timer := TTimer.Create('test_timer', 'Test timer', [], THistogram.DefaultBuckets);
  try
    Assert.AreEqual('test_timer', Timer.Name);
  finally
    Timer.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestTimerRecordDuration;
var
  Timer: TTimer;
begin
  Timer := TTimer.Create('test_timer', 'Test timer', [], [0.1, 0.5, 1.0]);
  try
    Timer.RecordDuration(0.25);
    Timer.RecordMs(500);
    Assert.AreEqual(Int64(2), Timer.Histogram.Count);
  finally
    Timer.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestTimerTime;
var
  Timer: TTimer;
begin
  Timer := TTimer.Create('test_timer', 'Test timer', [], [0.01, 0.1, 1.0]);
  try
    Timer.Time(procedure
    begin
      Sleep(10);
    end);
    Assert.AreEqual(Int64(1), Timer.Histogram.Count);
    Assert.IsTrue(Timer.Histogram.Sum > 0);
  finally
    Timer.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestTimerStart;
var
  Timer: TTimer;
  StopTimer: TProc;
begin
  Timer := TTimer.Create('test_timer', 'Test timer', [], [0.01, 0.1, 1.0]);
  try
    StopTimer := Timer.Start();
    Sleep(10);
    StopTimer();
    Assert.AreEqual(Int64(1), Timer.Histogram.Count);
    Assert.IsTrue(Timer.Histogram.Sum > 0);
  finally
    Timer.Free;
  end;
end;

// TSummary Tests

procedure TTestDeepBaseMetrics.TestSummaryCreate;
var
  Summary: TSummary;
begin
  Summary := TSummary.Create('test_summary', 'Test summary', [], [0.5, 0.9, 0.99]);
  try
    Assert.AreEqual('test_summary', Summary.Name);
  finally
    Summary.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestSummaryObserve;
var
  Summary: TSummary;
begin
  Summary := TSummary.Create('test_summary', 'Test summary', [], [0.5, 0.9, 0.99]);
  try
    Summary.Observe(1.0);
    Summary.Observe(2.0);
    Summary.Observe(3.0);
    Assert.AreEqual(Int64(3), Summary.Count);
    Assert.AreEqual(6.0, Summary.Sum, EPSILON);
  finally
    Summary.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestSummaryQuantiles;
var
  Summary: TSummary;
  Quantiles: TArray<TSummaryQuantile>;
  I: Integer;
begin
  Summary := TSummary.Create('test_summary', 'Test summary', [], [0.5, 0.9, 0.99]);
  try
    for I := 1 to 100 do
      Summary.Observe(I);
    Quantiles := Summary.GetQuantiles;
    Assert.IsTrue(Length(Quantiles) > 0);
  finally
    Summary.Free;
  end;
end;

// TMetricFamily Tests

procedure TTestDeepBaseMetrics.TestMetricFamilyCreate;
var
  Family: TMetricFamily<TCounter>;
begin
  Family := TMetricFamily<TCounter>.Create('test_family', 'Test family');
  try
    Assert.AreEqual('test_family', Family.Name);
  finally
    Family.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestMetricFamilyWithLabels;
var
  Family: TMetricFamily<TCounter>;
  Counter: TCounter;
begin
  Family := TMetricFamily<TCounter>.Create('http_requests', 'HTTP requests');
  try
    Counter := Family.WithLabels(['method', 'status'], ['GET', '200']);
    Counter.Inc;
    Assert.AreEqual(Int64(1), Counter.Value);

    Counter := Family.WithLabels(['method', 'status'], ['POST', '201']);
    Counter.Inc(5);
    Assert.AreEqual(Int64(5), Counter.Value);
  finally
    Family.Free;
  end;
end;

// TMetricsRegistry Tests

procedure TTestDeepBaseMetrics.TestRegistryCreate;
var
  Registry: TMetricsRegistry;
begin
  Registry := TMetricsRegistry.Create;
  try
    Assert.IsNotNull(Registry);
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryCounter;
var
  Registry: TMetricsRegistry;
  Counter: TCounter;
begin
  Registry := TMetricsRegistry.Create;
  try
    Counter := Registry.Counter('test_counter', 'Test counter');
    Assert.IsNotNull(Counter);
    Counter.Inc;
    Assert.AreEqual(Int64(1), Counter.Value);

    // Same name returns same counter
    Assert.AreSame(Counter, Registry.Counter('test_counter', ''));
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryGauge;
var
  Registry: TMetricsRegistry;
  Gauge: TGauge;
begin
  Registry := TMetricsRegistry.Create;
  try
    Gauge := Registry.Gauge('test_gauge', 'Test gauge');
    Assert.IsNotNull(Gauge);
    Gauge.SetValue(42.0);
    Assert.AreEqual(42.0, Gauge.Value, EPSILON);
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryHistogram;
var
  Registry: TMetricsRegistry;
  Histogram: THistogram;
begin
  Registry := TMetricsRegistry.Create;
  try
    Histogram := Registry.Histogram('test_histogram', 'Test histogram', []);
    Assert.IsNotNull(Histogram);
    Histogram.Observe(1.0);
    Assert.AreEqual(Int64(1), Histogram.Count);
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryGetAll;
var
  Registry: TMetricsRegistry;
  Metrics: TArray<IMetric>;
begin
  Registry := TMetricsRegistry.Create;
  try
    Registry.Counter('counter1', '');
    Registry.Gauge('gauge1', '');
    Metrics := Registry.GetAll;
    Assert.AreEqual<Integer>(2, Length(Metrics));
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryToJSON;
var
  Registry: TMetricsRegistry;
  JSON: TJSONObject;
begin
  Registry := TMetricsRegistry.Create;
  try
    Registry.Counter('test_counter', '').Inc(10);
    JSON := Registry.ToJSON;
    try
      Assert.IsTrue(JSON.Count > 0);
    finally
      JSON.Free;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryToPrometheus;
var
  Registry: TMetricsRegistry;
  S: string;
begin
  Registry := TMetricsRegistry.Create;
  try
    Registry.Counter('test_counter', 'Test').Inc;
    S := Registry.ToPrometheus;
    Assert.IsTrue(S.Contains('test_counter'));
  finally
    Registry.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestRegistryToInfluxLines;
var
  Registry: TMetricsRegistry;
  S: string;
begin
  Registry := TMetricsRegistry.Create;
  try
    Registry.Counter('test_counter', '').Inc;
    S := Registry.ToInfluxLines;
    Assert.IsTrue(Length(S) > 0);
  finally
    Registry.Free;
  end;
end;

// Thread Safety Tests

procedure TTestDeepBaseMetrics.TestCounterThreadSafety;
var
  Counter: TCounter;
  Threads: array[0..9] of TThread;
  I: Integer;
begin
  Counter := TCounter.Create('thread_counter', '', []);
  try
    for I := 0 to 9 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(procedure
      var
        J: Integer;
      begin
        for J := 1 to 1000 do
          Counter.Inc;
      end);
      Threads[I].FreeOnTerminate := False;
      Threads[I].Start;
    end;

    for I := 0 to 9 do
    begin
      Threads[I].WaitFor;
      Threads[I].Free;
    end;

    Assert.AreEqual(Int64(10000), Counter.Value);
  finally
    Counter.Free;
  end;
end;

procedure TTestDeepBaseMetrics.TestGaugeThreadSafety;
var
  Gauge: TGauge;
  Threads: array[0..9] of TThread;
  I: Integer;
begin
  Gauge := TGauge.Create('thread_gauge', '', []);
  try
    for I := 0 to 9 do
    begin
      Threads[I] := TThread.CreateAnonymousThread(procedure
      var
        J: Integer;
      begin
        for J := 1 to 1000 do
        begin
          Gauge.Inc;
          Gauge.Dec;
        end;
      end);
      Threads[I].FreeOnTerminate := False;
      Threads[I].Start;
    end;

    for I := 0 to 9 do
    begin
      Threads[I].WaitFor;
      Threads[I].Free;
    end;

    Assert.AreEqual(0.0, Gauge.Value, EPSILON);
  finally
    Gauge.Free;
  end;
end;

// TMetrics Static Helper Tests

procedure TTestDeepBaseMetrics.TestMetricsStaticCounter;
begin
  TMetrics.Counter('static_counter').Inc;
  Assert.IsTrue(TMetrics.Counter('static_counter').Value >= 1);
end;

procedure TTestDeepBaseMetrics.TestMetricsStaticGauge;
begin
  TMetrics.Gauge('static_gauge').SetValue(100.0);
  Assert.AreEqual(100.0, TMetrics.Gauge('static_gauge').Value, EPSILON);
end;

procedure TTestDeepBaseMetrics.TestMetricsStaticRegistryConcurrent;
const
  THREAD_COUNT = 16;
  ITERATIONS = 100;
var
  Threads: array[0..THREAD_COUNT - 1] of TThread;
  I: Integer;
  MetricName: string;
begin
  MetricName := 'static_concurrent_' + FormatDateTime('hhnnsszzz', Now);

  for I := 0 to THREAD_COUNT - 1 do
  begin
    Threads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        J: Integer;
      begin
        for J := 1 to ITERATIONS do
          TMetrics.Counter(MetricName).Inc;
      end);
    Threads[I].FreeOnTerminate := False;
    Threads[I].Start;
  end;

  for I := 0 to THREAD_COUNT - 1 do
  begin
    Threads[I].WaitFor;
    Threads[I].Free;
  end;

  Assert.AreEqual<Int64>(THREAD_COUNT * ITERATIONS,
    TMetrics.Counter(MetricName).Value);
end;
initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseMetrics);
end.
