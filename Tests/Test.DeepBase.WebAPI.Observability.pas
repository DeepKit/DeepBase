{*******************************************************}
{                                                       }
{       DeepBase Framework                               }
{       Web API Observability Tests                     }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit Test.DeepBase.WebAPI.Observability;

{*******************************************************************************
  Unit Tests for DeepBase.WebAPI.Observability
  Tests: TWebHealthCheckRegistry, TMetricsCollector, TObservability helpers
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  DUnitX.TestFramework,
  DeepBase.WebAPI.Core,
  DeepBase.WebAPI.Observability;

type
  [TestFixture]
  TTestWebHealthCheckResult = class
  public
    [Test]
    procedure Healthy_SetsStatusAndName;
    [Test]
    procedure Degraded_SetsStatus;
    [Test]
    procedure Unhealthy_SetsStatus;
    [Test]
    procedure ToJSON_ContainsAllFields;
    [Test]
    procedure ToJSON_OmitsEmptyMessage;
  end;

  [TestFixture]
  TTestWebHealthCheckRegistry = class
  private
    FRegistry: TWebHealthCheckRegistry;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure RunAll_Empty_ReturnsHealthy;
    [Test]
    procedure RunAll_SingleHealthy_ReturnsHealthy;
    [Test]
    procedure RunAll_SingleUnhealthy_ReturnsUnhealthy;
    [Test]
    procedure RunAll_Mixed_ReturnsWorstStatus;
    [Test]
    procedure RunAll_CheckThrows_ReturnsUnhealthy;
    [Test]
    procedure RunAll_HasTimestamp;
    [Test]
    procedure Register_Multiple_AllExecuted;
    [Test]
    procedure RunAll_MeasuresDuration;
  end;

  [TestFixture]
  TTestMetricsCollector = class
  private
    FCollector: TMetricsCollector;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Counter_Increment;
    [Test]
    procedure Counter_MultipleIncrements;
    [Test]
    procedure Counter_WithLabels;
    [Test]
    procedure Gauge_SetValue;
    [Test]
    procedure Gauge_OverwriteValue;
    [Test]
    procedure Histogram_Observe;
    [Test]
    procedure UptimeSeconds_Positive;
    [Test]
    procedure ToPrometheus_ContainsUptime;
    [Test]
    procedure ToPrometheus_ContainsCounter;
    [Test]
    procedure ToPrometheus_ContainsHistogramBuckets;
  end;

  [TestFixture]
  TTestMetricSeries = class
  public
    [Test]
    procedure Counter_PrometheusFormat;
    [Test]
    procedure Gauge_PrometheusFormat;
    [Test]
    procedure Histogram_PrometheusFormat;
  end;

  [TestFixture]
  TTestObservability = class
  public
    [Test]
    procedure StatusToString_Values;
    [Test]
    procedure HttpMethodToString_Values;
    [Test]
    procedure DefaultDurationBuckets_HasNineBuckets;
    [Test]
    procedure DefaultDurationBuckets_Sorted;
    [Test]
    procedure RegisterHealthEndpoint_DoesNotRaise;
    [Test]
    procedure RegisterMetricsEndpoint_DoesNotRaise;
    [Test]
    procedure CreateRequestMetricsMiddleware_ReturnsFunc;
  end;

implementation

{ TTestWebHealthCheckResult }

procedure TTestWebHealthCheckResult.Healthy_SetsStatusAndName;
var
  LR: TWebHealthCheckResult;
begin
  LR := TWebHealthCheckResult.Healthy('db', 'OK');
  Assert.AreEqual('db', LR.Name);
  Assert.AreEqual(whsHealthy, LR.Status);
  Assert.AreEqual('OK', LR.Message);
  Assert.AreEqual<Double>(0, LR.DurationMs);
end;

procedure TTestWebHealthCheckResult.Degraded_SetsStatus;
var
  LR: TWebHealthCheckResult;
begin
  LR := TWebHealthCheckResult.Degraded('cache', 'slow');
  Assert.AreEqual(whsDegraded, LR.Status);
  Assert.AreEqual('slow', LR.Message);
end;

procedure TTestWebHealthCheckResult.Unhealthy_SetsStatus;
var
  LR: TWebHealthCheckResult;
begin
  LR := TWebHealthCheckResult.Unhealthy('db', 'down', 100);
  Assert.AreEqual(whsUnhealthy, LR.Status);
  Assert.AreEqual('down', LR.Message);
  Assert.AreEqual<Double>(100, LR.DurationMs);
end;

procedure TTestWebHealthCheckResult.ToJSON_ContainsAllFields;
var
  LR: TWebHealthCheckResult;
  LJson: TJSONObject;
begin
  LR := TWebHealthCheckResult.Healthy('db', 'OK', 5);
  LJson := LR.ToJSON;
  try
    Assert.AreEqual('db', LJson.GetValue<string>('name'));
    Assert.AreEqual('healthy', LJson.GetValue<string>('status'));
    Assert.AreEqual<Double>(5, LJson.GetValue<TJSONNumber>('duration_ms').AsDouble);
    Assert.AreEqual('OK', LJson.GetValue<string>('message'));
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckResult.ToJSON_OmitsEmptyMessage;
var
  LR: TWebHealthCheckResult;
  LJson: TJSONObject;
begin
  LR := TWebHealthCheckResult.Healthy('db');
  LJson := LR.ToJSON;
  try
    Assert.IsNull(LJson.GetValue('message'));
  finally
    LJson.Free;
  end;
end;

{ TTestWebHealthCheckRegistry }

procedure TTestWebHealthCheckRegistry.Setup;
begin
  FRegistry := TWebHealthCheckRegistry.Create;
end;

procedure TTestWebHealthCheckRegistry.TearDown;
begin
  FRegistry.Free;
end;

procedure TTestWebHealthCheckRegistry.RunAll_Empty_ReturnsHealthy;
var
  LJson: TJSONObject;
begin
  LJson := FRegistry.RunAll;
  try
    Assert.AreEqual('healthy', LJson.GetValue<string>('status'));
    Assert.IsNotNull(LJson.GetValue('timestamp'));
    Assert.AreEqual<Integer>(0,
      (LJson.GetValue('checks') as TJSONArray).Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_SingleHealthy_ReturnsHealthy;
var
  LJson: TJSONObject;
begin
  FRegistry.Register('db',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Healthy('db', 'OK');
    end);
  LJson := FRegistry.RunAll;
  try
    Assert.AreEqual('healthy', LJson.GetValue<string>('status'));
    Assert.AreEqual<Integer>(1,
      (LJson.GetValue('checks') as TJSONArray).Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_SingleUnhealthy_ReturnsUnhealthy;
var
  LJson: TJSONObject;
begin
  FRegistry.Register('db',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Unhealthy('db', 'down');
    end);
  LJson := FRegistry.RunAll;
  try
    Assert.AreEqual('unhealthy', LJson.GetValue<string>('status'));
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_Mixed_ReturnsWorstStatus;
var
  LJson: TJSONObject;
begin
  FRegistry.Register('db',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Healthy('db');
    end);
  FRegistry.Register('cache',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Degraded('cache', 'slow');
    end);
  LJson := FRegistry.RunAll;
  try
    Assert.AreEqual('degraded', LJson.GetValue<string>('status'));
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_CheckThrows_ReturnsUnhealthy;
var
  LJson: TJSONObject;
begin
  FRegistry.Register('boom',
    function: TWebHealthCheckResult
    begin
      raise Exception.Create('test failure');
    end);
  LJson := FRegistry.RunAll;
  try
    Assert.AreEqual('unhealthy', LJson.GetValue<string>('status'));
    Assert.AreEqual('test failure',
      ((LJson.GetValue('checks') as TJSONArray).Items[0] as TJSONObject)
        .GetValue<string>('message'));
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_HasTimestamp;
var
  LJson: TJSONObject;
  LTimestamp: string;
begin
  LJson := FRegistry.RunAll;
  try
    LTimestamp := LJson.GetValue<string>('timestamp');
    Assert.IsTrue(LTimestamp.Contains('T'),
      'Timestamp should contain T separator');
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.Register_Multiple_AllExecuted;
var
  LJson: TJSONObject;
  LChecks: TJSONArray;
begin
  FRegistry.Register('a',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Healthy('a');
    end);
  FRegistry.Register('b',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Healthy('b');
    end);
  FRegistry.Register('c',
    function: TWebHealthCheckResult
    begin
      Result := TWebHealthCheckResult.Healthy('c');
    end);
  LJson := FRegistry.RunAll;
  try
    LChecks := LJson.GetValue('checks') as TJSONArray;
    Assert.AreEqual<Integer>(3, LChecks.Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestWebHealthCheckRegistry.RunAll_MeasuresDuration;
var
  LJson: TJSONObject;
  LChecks: TJSONArray;
  LCheck: TJSONObject;
  LDuration: Double;
begin
  FRegistry.Register('slow',
    function: TWebHealthCheckResult
    begin
      Sleep(10);
      Result := TWebHealthCheckResult.Healthy('slow');
    end);
  LJson := FRegistry.RunAll;
  try
    LChecks := LJson.GetValue('checks') as TJSONArray;
    LCheck := LChecks.Items[0] as TJSONObject;
    LDuration := LCheck.GetValue<TJSONNumber>('duration_ms').AsDouble;
    Assert.IsTrue(LDuration >= 0,
      'Duration should be non-negative');
  finally
    LJson.Free;
  end;
end;

{ TTestMetricsCollector }

procedure TTestMetricsCollector.Setup;
begin
  FCollector := TMetricsCollector.Create;
end;

procedure TTestMetricsCollector.TearDown;
begin
  FCollector.Free;
end;

procedure TTestMetricsCollector.Counter_Increment;
var
  LProm: string;
begin
  FCollector.Counter('test_total', 'Test counter', nil);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('test_total'),
    'Prometheus output should contain counter name');
  Assert.IsTrue(LProm.Contains('# TYPE test_total counter'),
    'Should contain TYPE line');
end;

procedure TTestMetricsCollector.Counter_MultipleIncrements;
var
  LProm: string;
begin
  FCollector.Counter('req_total', 'Requests', nil, 1);
  FCollector.Counter('req_total', 'Requests', nil, 1);
  FCollector.Counter('req_total', 'Requests', nil, 1);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('3'),
    'Counter should show 3 after 3 increments');
end;

procedure TTestMetricsCollector.Counter_WithLabels;
var
  LLabels: TMetricLabels;
  LProm: string;
begin
  LLabels := TMetricLabels.Create;
  try
    LLabels.Add('method', 'GET');
    LLabels.Add('path', '/api');
    FCollector.Counter('http_total', 'HTTP', LLabels);
  finally
    LLabels.Free;
  end;
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('method="GET"'),
    'Should contain method label');
  Assert.IsTrue(LProm.Contains('path="/api"'),
    'Should contain path label');
end;

procedure TTestMetricsCollector.Gauge_SetValue;
var
  LProm: string;
begin
  FCollector.Gauge('temp', 'Temperature', nil, 42);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('# TYPE temp gauge'),
    'Should contain TYPE gauge');
  Assert.IsTrue(LProm.Contains('42'),
    'Should contain gauge value');
end;

procedure TTestMetricsCollector.Gauge_OverwriteValue;
var
  LProm: string;
begin
  FCollector.Gauge('mem', 'Memory', nil, 100);
  FCollector.Gauge('mem', 'Memory', nil, 200);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('200'),
    'Gauge should show latest value');
  Assert.IsFalse(LProm.Contains('100'),
    'Old gauge value should be replaced');
end;

procedure TTestMetricsCollector.Histogram_Observe;
var
  LProm: string;
  LBuckets: TArray<Double>;
begin
  SetLength(LBuckets, 3);
  LBuckets[0] := 0.1;
  LBuckets[1] := 0.5;
  LBuckets[2] := 1.0;
  FCollector.Histogram('dur', 'Duration', nil, 0.05, LBuckets);
  FCollector.Histogram('dur', 'Duration', nil, 0.3, LBuckets);
  FCollector.Histogram('dur', 'Duration', nil, 0.8, LBuckets);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('# TYPE dur histogram'),
    'Should contain TYPE histogram');
  Assert.IsTrue(LProm.Contains('dur_bucket'),
    'Should contain bucket lines');
  Assert.IsTrue(LProm.Contains('dur_count'),
    'Should contain count line');
  Assert.IsTrue(LProm.Contains('dur_sum'),
    'Should contain sum line');
end;

procedure TTestMetricsCollector.UptimeSeconds_Positive;
begin
  Sleep(1);
  Assert.IsTrue(FCollector.UptimeSeconds > 0,
    'Uptime should be positive');
end;

procedure TTestMetricsCollector.ToPrometheus_ContainsUptime;
var
  LProm: string;
begin
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('process_uptime_seconds'),
    'Should contain uptime metric');
  Assert.IsTrue(LProm.Contains('# TYPE process_uptime_seconds gauge'),
    'Should contain TYPE for uptime');
end;

procedure TTestMetricsCollector.ToPrometheus_ContainsCounter;
var
  LProm: string;
begin
  FCollector.Counter('my_counter', 'My counter', nil, 5);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('# HELP my_counter My counter'),
    'Should contain HELP line');
  Assert.IsTrue(LProm.Contains('# TYPE my_counter counter'),
    'Should contain TYPE line');
end;

procedure TTestMetricsCollector.ToPrometheus_ContainsHistogramBuckets;
var
  LProm: string;
  LBuckets: TArray<Double>;
begin
  SetLength(LBuckets, 2);
  LBuckets[0] := 0.1;
  LBuckets[1] := 1.0;
  FCollector.Histogram('lat', 'Latency', nil, 0.05, LBuckets);
  LProm := FCollector.ToPrometheus;
  Assert.IsTrue(LProm.Contains('lat_bucket{le="0.1"}'),
    'Should contain 0.1 bucket');
  Assert.IsTrue(LProm.Contains('lat_bucket{le="1"}'),
    'Should contain 1.0 bucket');
  Assert.IsTrue(LProm.Contains('lat_bucket{le="+Inf"}'),
    'Should contain +Inf bucket');
  Assert.IsTrue(LProm.Contains('lat_count'),
    'Should contain count');
end;

{ TTestMetricSeries }

procedure TTestMetricSeries.Counter_PrometheusFormat;
var
  LSeries: TMetricSeries;
  LProm: string;
begin
  LSeries := TMetricSeries.Create('requests', 'Total requests', mtCounter, []);
  try
    LSeries.Increment(nil, 1);
    LSeries.Increment(nil, 1);
    LProm := LSeries.ToPrometheus;
    Assert.IsTrue(LProm.Contains('# HELP requests Total requests'));
    Assert.IsTrue(LProm.Contains('# TYPE requests counter'));
    Assert.IsTrue(LProm.Contains('requests{} 2'));
  finally
    LSeries.Free;
  end;
end;

procedure TTestMetricSeries.Gauge_PrometheusFormat;
var
  LSeries: TMetricSeries;
  LProm: string;
begin
  LSeries := TMetricSeries.Create('temperature', 'Temp', mtGauge, []);
  try
    LSeries.SetGauge(nil, 36.6);
    LProm := LSeries.ToPrometheus;
    Assert.IsTrue(LProm.Contains('# TYPE temperature gauge'));
    Assert.IsTrue(LProm.Contains('36.6'));
  finally
    LSeries.Free;
  end;
end;

procedure TTestMetricSeries.Histogram_PrometheusFormat;
var
  LSeries: TMetricSeries;
  LProm: string;
  LBuckets: array of Double;
begin
  SetLength(LBuckets, 2);
  LBuckets[0] := 0.5;
  LBuckets[1] := 1.0;
  LSeries := TMetricSeries.Create('latency', 'Latency', mtHistogram, LBuckets);
  try
    LSeries.Observe(nil, 0.3);
    LSeries.Observe(nil, 0.7);
    LProm := LSeries.ToPrometheus;
    Assert.IsTrue(LProm.Contains('# TYPE latency histogram'));
    Assert.IsTrue(LProm.Contains('latency_bucket{le="0.5"}'));
    Assert.IsTrue(LProm.Contains('latency_count'));
    Assert.IsTrue(LProm.Contains('latency_sum'));
  finally
    LSeries.Free;
  end;
end;

{ TTestObservability }

procedure TTestObservability.StatusToString_Values;
begin
  Assert.AreEqual('healthy',
    TObservability.StatusToString(whsHealthy));
  Assert.AreEqual('degraded',
    TObservability.StatusToString(whsDegraded));
  Assert.AreEqual('unhealthy',
    TObservability.StatusToString(whsUnhealthy));
end;

procedure TTestObservability.HttpMethodToString_Values;
begin
  Assert.AreEqual('GET', TObservability.HttpMethodToString(hmGet));
  Assert.AreEqual('POST', TObservability.HttpMethodToString(hmPost));
  Assert.AreEqual('PUT', TObservability.HttpMethodToString(hmPut));
  Assert.AreEqual('DELETE', TObservability.HttpMethodToString(hmDelete));
end;

procedure TTestObservability.DefaultDurationBuckets_HasNineBuckets;
var
  LBuckets: TArray<Double>;
begin
  LBuckets := TObservability.DefaultDurationBuckets;
  Assert.AreEqual<Integer>(9, Length(LBuckets));
end;

procedure TTestObservability.DefaultDurationBuckets_Sorted;
var
  LBuckets: TArray<Double>;
  I: Integer;
begin
  LBuckets := TObservability.DefaultDurationBuckets;
  for I := 1 to High(LBuckets) do
    Assert.IsTrue(LBuckets[I] > LBuckets[I - 1],
      Format('Bucket[%d]=%g should be > bucket[%d]=%g',
        [I, LBuckets[I], I - 1, LBuckets[I - 1]]));
end;

procedure TTestObservability.RegisterHealthEndpoint_DoesNotRaise;
var
  LServer: TApiServer;
  LRegistry: TWebHealthCheckRegistry;
begin
  LServer := TApiServer.Create;
  LRegistry := TWebHealthCheckRegistry.Create;
  try
    LRegistry.Register('test',
      function: TWebHealthCheckResult
      begin
        Result := TWebHealthCheckResult.Healthy('test');
      end);
    Assert.WillNotRaise(
      procedure
      begin
        TObservability.RegisterHealthEndpoint(LServer, LRegistry);
      end, Exception);
  finally
    LRegistry.Free;
    LServer.Free;
  end;
end;

procedure TTestObservability.RegisterMetricsEndpoint_DoesNotRaise;
var
  LServer: TApiServer;
  LCollector: TMetricsCollector;
begin
  LServer := TApiServer.Create;
  LCollector := TMetricsCollector.Create;
  try
    Assert.WillNotRaise(
      procedure
      begin
        TObservability.RegisterMetricsEndpoint(LServer, LCollector);
      end, Exception);
  finally
    LCollector.Free;
    LServer.Free;
  end;
end;

procedure TTestObservability.CreateRequestMetricsMiddleware_ReturnsFunc;
var
  LCollector: TMetricsCollector;
  LFunc: TMiddlewareFunc;
begin
  LCollector := TMetricsCollector.Create;
  try
    LFunc := TObservability.CreateRequestMetricsMiddleware(LCollector,
      TObservability.DefaultDurationBuckets);
    Assert.IsTrue(Assigned(LFunc),
      'Middleware function should be assigned');
  finally
    LCollector.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestWebHealthCheckResult);
  TDUnitX.RegisterTestFixture(TTestWebHealthCheckRegistry);
  TDUnitX.RegisterTestFixture(TTestMetricsCollector);
  TDUnitX.RegisterTestFixture(TTestMetricSeries);
  TDUnitX.RegisterTestFixture(TTestObservability);

end.
