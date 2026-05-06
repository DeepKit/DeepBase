unit UniBase.Metrics;

{*******************************************************************************
  UniBase Metrics
  Application metrics collection system with:
  - Counter: Monotonically increasing values (requests, errors)
  - Gauge: Point-in-time values (memory usage, queue size)
  - Histogram: Distribution of values (response times)
  - Timer: Duration measurements with statistics
  - Summary: Quantile calculations
  - Labels: Dimensional metrics
  - Multiple exporters: Prometheus, JSON, InfluxDB line protocol
  
  Author: UniBase Team
  Created: 2025-11-28
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.SyncObjs, System.Math, System.DateUtils, System.JSON,
  UniBase.Constants;

type
  EMetricsException = class(Exception);

  /// <summary>Metric types</summary>
  TMetricType = (mtCounter, mtGauge, mtHistogram, mtTimer, mtSummary);

  /// <summary>Label pair for dimensional metrics</summary>
  TMetricLabel = record
    Name: string;
    Value: string;
    constructor Create(const AName, AValue: string);
  end;

  TMetricLabels = TArray<TMetricLabel>;

  /// <summary>Base metric interface</summary>
  IMetric = interface
    ['{B1C2D3E4-5678-9ABC-DEF0-123456789ABC}']
    function GetName: string;
    function GetDescription: string;
    function GetMetricType: TMetricType;
    function GetLabels: TMetricLabels;
    function ToJSON: TJSONObject;
    function ToPrometheus: string;
    function ToInfluxLine(const AMeasurement: string = ''): string;
    
    property Name: string read GetName;
    property Description: string read GetDescription;
    property MetricType: TMetricType read GetMetricType;
    property Labels: TMetricLabels read GetLabels;
  end;

  /// <summary>Base metric class</summary>
  TMetricBase = class(TInterfacedObject, IMetric)
  protected
    FName: string;
    FDescription: string;
    FMetricType: TMetricType;
    FLabels: TMetricLabels;
    FLock: TCriticalSection;
    FCreatedAt: TDateTime;
    
    function GetName: string;
    function GetDescription: string;
    function GetMetricType: TMetricType;
    function GetLabels: TMetricLabels;
    function LabelsToString: string;
    function LabelsToPrometheus: string;
    function LabelsToInflux: string;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels);
    destructor Destroy; override;
    
    function ToJSON: TJSONObject; virtual; abstract;
    function ToPrometheus: string; virtual; abstract;
    function ToInfluxLine(const AMeasurement: string = ''): string; virtual; abstract;
    
    property Name: string read GetName;
    property Description: string read GetDescription;
    property MetricType: TMetricType read GetMetricType;
    property Labels: TMetricLabels read GetLabels;
  end;

  /// <summary>Counter metric - monotonically increasing</summary>
  TCounter = class(TMetricBase)
  private
    FValue: Int64;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels);
    
    /// <summary>Increment counter by 1</summary>
    procedure Inc; overload;
    /// <summary>Increment counter by amount</summary>
    procedure Inc(AAmount: Int64); overload;
    /// <summary>Get current value</summary>
    function Value: Int64;
    /// <summary>Reset counter (use with caution)</summary>
    procedure Reset;
    
    function ToJSON: TJSONObject; override;
    function ToPrometheus: string; override;
    function ToInfluxLine(const AMeasurement: string = ''): string; override;
  end;

  /// <summary>Gauge metric - point-in-time value</summary>
  TGauge = class(TMetricBase)
  private
    FValue: Double;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels);
    
    /// <summary>Set gauge value</summary>
    procedure SetValue(AValue: Double);
    /// <summary>Get current value</summary>
    function Value: Double;
    /// <summary>Increment gauge by 1</summary>
    procedure Inc; overload;
    /// <summary>Increment gauge by amount</summary>
    procedure Inc(AAmount: Double); overload;
    /// <summary>Decrement gauge by 1</summary>
    procedure Dec; overload;
    /// <summary>Decrement gauge by amount</summary>
    procedure Dec(AAmount: Double); overload;
    /// <summary>Set to current timestamp</summary>
    procedure SetToCurrentTime;
    
    function ToJSON: TJSONObject; override;
    function ToPrometheus: string; override;
    function ToInfluxLine(const AMeasurement: string = ''): string; override;
  end;

  /// <summary>Histogram bucket</summary>
  THistogramBucket = record
    UpperBound: Double;
    Count: Int64;
  end;

  /// <summary>Histogram metric - distribution of values</summary>
  THistogram = class(TMetricBase)
  private
    FBuckets: TArray<THistogramBucket>;
    FSum: Double;
    FCount: Int64;
    FMin: Double;
    FMax: Double;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels;
      const ABuckets: TArray<Double>);
    
    /// <summary>Observe a value</summary>
    procedure Observe(AValue: Double);
    /// <summary>Get bucket counts</summary>
    function Buckets: TArray<THistogramBucket>;
    /// <summary>Get sum of all observed values</summary>
    function Sum: Double;
    /// <summary>Get count of observations</summary>
    function Count: Int64;
    /// <summary>Get minimum observed value</summary>
    function Min: Double;
    /// <summary>Get maximum observed value</summary>
    function Max: Double;
    /// <summary>Get mean of observed values</summary>
    function Mean: Double;
    /// <summary>Reset histogram</summary>
    procedure Reset;
    
    function ToJSON: TJSONObject; override;
    function ToPrometheus: string; override;
    function ToInfluxLine(const AMeasurement: string = ''): string; override;
    
    /// <summary>Default HTTP request duration buckets (in seconds)</summary>
    class function DefaultBuckets: TArray<Double>; static;
    /// <summary>Linear buckets</summary>
    class function LinearBuckets(AStart, AWidth: Double; ACount: Integer): TArray<Double>; static;
    /// <summary>Exponential buckets</summary>
    class function ExponentialBuckets(AStart, AFactor: Double; ACount: Integer): TArray<Double>; static;
  end;

  /// <summary>Timer metric - measures duration</summary>
  TTimer = class(TMetricBase)
  private
    FHistogram: THistogram;
    FActiveTimers: Integer;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels;
      const ABuckets: TArray<Double>);
    destructor Destroy; override;
    
    /// <summary>Start timing - returns a stop action</summary>
    function Start: TProc;
    /// <summary>Record a duration in seconds</summary>
    procedure RecordDuration(ADurationSeconds: Double);
    /// <summary>Record a duration in milliseconds</summary>
    procedure RecordMs(ADurationMs: Double);
    /// <summary>Time a procedure</summary>
    procedure Time(AProc: TProc);
    /// <summary>Time a function</summary>
    function TimeFunc<T>(AFunc: TFunc<T>): T;
    
    /// <summary>Get underlying histogram</summary>
    property Histogram: THistogram read FHistogram;
    /// <summary>Get count of active timers</summary>
    property ActiveTimers: Integer read FActiveTimers;
    
    function ToJSON: TJSONObject; override;
    function ToPrometheus: string; override;
    function ToInfluxLine(const AMeasurement: string = ''): string; override;
  end;

  /// <summary>Summary quantile</summary>
  TSummaryQuantile = record
    Quantile: Double;
    Value: Double;
    Error: Double;
  end;

  /// <summary>Summary metric - calculates quantiles</summary>
  TSummary = class(TMetricBase)
  private
    FValues: TList<Double>;
    FMaxSamples: Integer;
    FQuantiles: TArray<Double>;
    FSum: Double;
    FCount: Int64;
  public
    constructor Create(const AName, ADescription: string; const ALabels: TMetricLabels;
      const AQuantiles: TArray<Double>; AMaxSamples: Integer = DEFAULT_BATCH_SIZE);
    destructor Destroy; override;
    
    /// <summary>Observe a value</summary>
    procedure Observe(AValue: Double);
    /// <summary>Get calculated quantiles</summary>
    function GetQuantiles: TArray<TSummaryQuantile>;
    /// <summary>Get sum of all values</summary>
    function Sum: Double;
    /// <summary>Get count of observations</summary>
    function Count: Int64;
    /// <summary>Reset summary</summary>
    procedure Reset;
    
    function ToJSON: TJSONObject; override;
    function ToPrometheus: string; override;
    function ToInfluxLine(const AMeasurement: string = ''): string; override;
    
    /// <summary>Default quantiles (50th, 90th, 95th, 99th percentiles)</summary>
    class function DefaultQuantiles: TArray<Double>; static;
  end;

  /// <summary>Metric family - holds labeled variants of a metric</summary>
  TMetricFamily<T: TMetricBase> = class
  private
    FName: string;
    FDescription: string;
    FMetrics: TObjectDictionary<string, T>;
    FLock: TCriticalSection;
    FBuckets: TArray<Double>;
    FQuantiles: TArray<Double>;
    
    function LabelsToKey(const ALabels: TMetricLabels): string;
  public
    constructor Create(const AName, ADescription: string);
    destructor Destroy; override;
    
    /// <summary>Get or create metric with labels</summary>
    function WithLabels(const ALabels: array of TMetricLabel): T; overload;
    function WithLabels(const ALabelNames: array of string; const ALabelValues: array of string): T; overload;
    
    /// <summary>Get all metrics in family</summary>
    function GetAll: TArray<T>;
    
    /// <summary>Remove metric with labels</summary>
    procedure Remove(const ALabels: TMetricLabels);
    
    /// <summary>Clear all metrics</summary>
    procedure Clear;
    
    property Name: string read FName;
    property Description: string read FDescription;
    property Buckets: TArray<Double> read FBuckets write FBuckets;
    property Quantiles: TArray<Double> read FQuantiles write FQuantiles;
  end;

  /// <summary>Metrics registry</summary>
  TMetricsRegistry = class
  private
    FMetrics: TDictionary<string, IMetric>;
    FFamilies: TObjectDictionary<string, TObject>;
    FLock: TCriticalSection;
    FPrefix: string;
  public
    constructor Create(const APrefix: string = '');
    destructor Destroy; override;
    
    /// <summary>Create and register a counter</summary>
    function Counter(const AName, ADescription: string): TCounter; overload;
    function Counter(const AName, ADescription: string; const ALabels: TMetricLabels): TCounter; overload;
    
    /// <summary>Create and register a gauge</summary>
    function Gauge(const AName, ADescription: string): TGauge; overload;
    function Gauge(const AName, ADescription: string; const ALabels: TMetricLabels): TGauge; overload;
    
    /// <summary>Create and register a histogram</summary>
    function Histogram(const AName, ADescription: string; 
      const ABuckets: TArray<Double>): THistogram; overload;
    function Histogram(const AName, ADescription: string; const ALabels: TMetricLabels;
      const ABuckets: TArray<Double>): THistogram; overload;
    
    /// <summary>Create and register a timer</summary>
    function Timer(const AName, ADescription: string): TTimer; overload;
    function Timer(const AName, ADescription: string; const ALabels: TMetricLabels): TTimer; overload;
    
    /// <summary>Create and register a summary</summary>
    function Summary(const AName, ADescription: string): TSummary; overload;
    function Summary(const AName, ADescription: string; const ALabels: TMetricLabels): TSummary; overload;
    
    /// <summary>Get metric by name</summary>
    function Get(const AName: string): IMetric;
    
    /// <summary>Check if metric exists</summary>
    function Exists(const AName: string): Boolean;
    
    /// <summary>Unregister a metric</summary>
    procedure Unregister(const AName: string);
    
    /// <summary>Get all registered metrics</summary>
    function GetAll: TArray<IMetric>;
    
    /// <summary>Export all metrics as JSON</summary>
    function ToJSON: TJSONObject;
    
    /// <summary>Export all metrics in Prometheus format</summary>
    function ToPrometheus: string;
    
    /// <summary>Export all metrics in InfluxDB line protocol</summary>
    function ToInfluxLines: string;
    
    /// <summary>Clear all metrics</summary>
    procedure Clear;
    
    property Prefix: string read FPrefix write FPrefix;
  end;

  /// <summary>Scoped timer helper</summary>
  IScopedTimer = interface
    ['{C3D4E5F6-7890-ABCD-EF12-345678901234}']
    procedure Stop;
  end;

  TScopedTimer = class(TInterfacedObject, IScopedTimer)
  private
    FTimer: TTimer;
    FStartTime: TDateTime;
    FStopped: Boolean;
  public
    constructor Create(ATimer: TTimer);
    destructor Destroy; override;
    procedure Stop;
  end;

  /// <summary>Global metrics helper</summary>
  TMetrics = class
  private
    class var FRegistry: TMetricsRegistry;
    class function GetRegistry: TMetricsRegistry; static;
  public
    class destructor Destroy;
    
    /// <summary>Get global registry</summary>
    class property Registry: TMetricsRegistry read GetRegistry;
    
    /// <summary>Quick counter access</summary>
    class function Counter(const AName, ADescription: string): TCounter; overload;
    class function Counter(const AName: string): TCounter; overload;
    
    /// <summary>Quick gauge access</summary>
    class function Gauge(const AName, ADescription: string): TGauge; overload;
    class function Gauge(const AName: string): TGauge; overload;
    
    /// <summary>Quick histogram access</summary>
    class function Histogram(const AName, ADescription: string): THistogram;
    
    /// <summary>Quick timer access</summary>
    class function Timer(const AName, ADescription: string): TTimer;
    
    /// <summary>Start scoped timing</summary>
    class function StartTimer(const AName: string): IScopedTimer;
    
    /// <summary>Increment counter</summary>
    class procedure Inc(const AName: string; AAmount: Int64 = 1);
    
    /// <summary>Set gauge value</summary>
    class procedure SetGauge(const AName: string; AValue: Double);
    
    /// <summary>Observe histogram value</summary>
    class procedure Observe(const AName: string; AValue: Double);
  end;

/// <summary>Create label</summary>
function MakeLabel(const AName, AValue: string): TMetricLabel;

/// <summary>Create labels array</summary>
function MakeLabels(const APairs: array of TMetricLabel): TMetricLabels;

/// <summary>Global metrics registry</summary>
function Metrics: TMetricsRegistry;

implementation

uses
  System.Diagnostics;

var
  GMetricsRegistry: TMetricsRegistry = nil;
  GRegistryLock: TCriticalSection = nil;

function MakeLabel(const AName, AValue: string): TMetricLabel;
begin
  Result := TMetricLabel.Create(AName, AValue);
end;

function MakeLabels(const APairs: array of TMetricLabel): TMetricLabels;
var
  I: Integer;
begin
  SetLength(Result, Length(APairs));
  for I := 0 to High(APairs) do
    Result[I] := APairs[I];
end;

function Metrics: TMetricsRegistry;
begin
  if not Assigned(GMetricsRegistry) then
  begin
    GRegistryLock.Enter;
    try
      if not Assigned(GMetricsRegistry) then
        GMetricsRegistry := TMetricsRegistry.Create;
    finally
      GRegistryLock.Leave;
    end;
  end;
  Result := GMetricsRegistry;
end;

{ TMetricLabel }

constructor TMetricLabel.Create(const AName, AValue: string);
begin
  Name := AName;
  Value := AValue;
end;

{ TMetricBase }

constructor TMetricBase.Create(const AName, ADescription: string; const ALabels: TMetricLabels);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FLabels := ALabels;
  FLock := TCriticalSection.Create;
  FCreatedAt := Now;
end;

destructor TMetricBase.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TMetricBase.GetName: string;
begin
  Result := FName;
end;

function TMetricBase.GetDescription: string;
begin
  Result := FDescription;
end;

function TMetricBase.GetMetricType: TMetricType;
begin
  Result := FMetricType;
end;

function TMetricBase.GetLabels: TMetricLabels;
begin
  Result := FLabels;
end;

function TMetricBase.LabelsToString: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLabels) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + FLabels[I].Name + '=' + FLabels[I].Value;
  end;
end;

function TMetricBase.LabelsToPrometheus: string;
var
  I: Integer;
begin
  if Length(FLabels) = 0 then
    Exit('');
    
  Result := '{';
  for I := 0 to High(FLabels) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + FLabels[I].Name + '="' + 
      StringReplace(FLabels[I].Value, '"', '\"', [rfReplaceAll]) + '"';
  end;
  Result := Result + '}';
end;

function TMetricBase.LabelsToInflux: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLabels) do
  begin
    Result := Result + ',' + FLabels[I].Name + '=' + 
      StringReplace(FLabels[I].Value, ' ', '\ ', [rfReplaceAll]);
  end;
end;

{ TCounter }

constructor TCounter.Create(const AName, ADescription: string; const ALabels: TMetricLabels);
begin
  inherited Create(AName, ADescription, ALabels);
  FMetricType := mtCounter;
  FValue := 0;
end;

procedure TCounter.Inc;
begin
  Inc(1);
end;

procedure TCounter.Inc(AAmount: Int64);
begin
  if AAmount < 0 then
    raise EMetricsException.Create('Counter can only be incremented with positive values');
    
  FLock.Enter;
  try
    FValue := FValue + AAmount;
  finally
    FLock.Leave;
  end;
end;

function TCounter.Value: Int64;
begin
  FLock.Enter;
  try
    Result := FValue;
  finally
    FLock.Leave;
  end;
end;

procedure TCounter.Reset;
begin
  FLock.Enter;
  try
    FValue := 0;
  finally
    FLock.Leave;
  end;
end;

function TCounter.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('type', 'counter');
  Result.AddPair('description', FDescription);
  Result.AddPair('value', TJSONNumber.Create(Value));
end;

function TCounter.ToPrometheus: string;
begin
  Result := Format('# HELP %s %s'#10, [FName, FDescription]);
  Result := Result + Format('# TYPE %s counter'#10, [FName]);
  Result := Result + Format('%s%s %d'#10, [FName, LabelsToPrometheus, Value]);
end;

function TCounter.ToInfluxLine(const AMeasurement: string): string;
var
  LMeasurement: string;
begin
  if AMeasurement <> '' then
    LMeasurement := AMeasurement
  else
    LMeasurement := FName;
  Result := Format('%s%s value=%di', [LMeasurement, LabelsToInflux, Value]);
end;

{ TGauge }

constructor TGauge.Create(const AName, ADescription: string; const ALabels: TMetricLabels);
begin
  inherited Create(AName, ADescription, ALabels);
  FMetricType := mtGauge;
  FValue := 0;
end;

procedure TGauge.SetValue(AValue: Double);
begin
  FLock.Enter;
  try
    FValue := AValue;
  finally
    FLock.Leave;
  end;
end;

function TGauge.Value: Double;
begin
  FLock.Enter;
  try
    Result := FValue;
  finally
    FLock.Leave;
  end;
end;

procedure TGauge.Inc;
begin
  Inc(1);
end;

procedure TGauge.Inc(AAmount: Double);
begin
  FLock.Enter;
  try
    FValue := FValue + AAmount;
  finally
    FLock.Leave;
  end;
end;

procedure TGauge.Dec;
begin
  Dec(1);
end;

procedure TGauge.Dec(AAmount: Double);
begin
  FLock.Enter;
  try
    FValue := FValue - AAmount;
  finally
    FLock.Leave;
  end;
end;

procedure TGauge.SetToCurrentTime;
begin
  SetValue(DateTimeToUnix(Now, False));
end;

function TGauge.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('type', 'gauge');
  Result.AddPair('description', FDescription);
  Result.AddPair('value', TJSONNumber.Create(Value));
end;

function TGauge.ToPrometheus: string;
begin
  Result := Format('# HELP %s %s'#10, [FName, FDescription]);
  Result := Result + Format('# TYPE %s gauge'#10, [FName]);
  Result := Result + Format('%s%s %g'#10, [FName, LabelsToPrometheus, Value]);
end;

function TGauge.ToInfluxLine(const AMeasurement: string): string;
var
  LMeasurement: string;
begin
  if AMeasurement <> '' then
    LMeasurement := AMeasurement
  else
    LMeasurement := FName;
  Result := Format('%s%s value=%g', [LMeasurement, LabelsToInflux, Value]);
end;

{ THistogram }

constructor THistogram.Create(const AName, ADescription: string; const ALabels: TMetricLabels;
  const ABuckets: TArray<Double>);
var
  I: Integer;
  LSorted: TArray<Double>;
begin
  inherited Create(AName, ADescription, ALabels);
  FMetricType := mtHistogram;
  
  // Sort and set up buckets
  LSorted := Copy(ABuckets);
  TArray.Sort<Double>(LSorted);
  
  SetLength(FBuckets, Length(LSorted) + 1); // +1 for +Inf
  for I := 0 to High(LSorted) do
  begin
    FBuckets[I].UpperBound := LSorted[I];
    FBuckets[I].Count := 0;
  end;
  FBuckets[High(FBuckets)].UpperBound := Infinity;
  FBuckets[High(FBuckets)].Count := 0;
  
  FSum := 0;
  FCount := 0;
  FMin := Infinity;
  FMax := NegInfinity;
end;

procedure THistogram.Observe(AValue: Double);
var
  I: Integer;
begin
  FLock.Enter;
  try
    FSum := FSum + AValue;
    System.Inc(FCount);
    
    if AValue < FMin then
      FMin := AValue;
    if AValue > FMax then
      FMax := AValue;
    
    // Increment all buckets where value <= upper bound
    for I := 0 to High(FBuckets) do
    begin
      if AValue <= FBuckets[I].UpperBound then
        System.Inc(FBuckets[I].Count);
    end;
  finally
    FLock.Leave;
  end;
end;

function THistogram.Buckets: TArray<THistogramBucket>;
begin
  FLock.Enter;
  try
    Result := Copy(FBuckets);
  finally
    FLock.Leave;
  end;
end;

function THistogram.Sum: Double;
begin
  FLock.Enter;
  try
    Result := FSum;
  finally
    FLock.Leave;
  end;
end;

function THistogram.Count: Int64;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Leave;
  end;
end;

function THistogram.Min: Double;
begin
  FLock.Enter;
  try
    if IsInfinite(FMin) then
      Result := 0
    else
      Result := FMin;
  finally
    FLock.Leave;
  end;
end;

function THistogram.Max: Double;
begin
  FLock.Enter;
  try
    if IsInfinite(FMax) then
      Result := 0
    else
      Result := FMax;
  finally
    FLock.Leave;
  end;
end;

function THistogram.Mean: Double;
begin
  FLock.Enter;
  try
    if FCount > 0 then
      Result := FSum / FCount
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

procedure THistogram.Reset;
var
  I: Integer;
begin
  FLock.Enter;
  try
    FSum := 0;
    FCount := 0;
    FMin := Infinity;
    FMax := NegInfinity;
    for I := 0 to High(FBuckets) do
      FBuckets[I].Count := 0;
  finally
    FLock.Leave;
  end;
end;

function THistogram.ToJSON: TJSONObject;
var
  LBuckets: TJSONArray;
  LBucket: TJSONObject;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('type', 'histogram');
  Result.AddPair('description', FDescription);
  Result.AddPair('count', TJSONNumber.Create(Count));
  Result.AddPair('sum', TJSONNumber.Create(Sum));
  Result.AddPair('min', TJSONNumber.Create(Min));
  Result.AddPair('max', TJSONNumber.Create(Max));
  Result.AddPair('mean', TJSONNumber.Create(Mean));
  
  LBuckets := TJSONArray.Create;
  FLock.Enter;
  try
    for I := 0 to High(FBuckets) do
    begin
      LBucket := TJSONObject.Create;
      if IsInfinite(FBuckets[I].UpperBound) then
        LBucket.AddPair('le', '+Inf')
      else
        LBucket.AddPair('le', TJSONNumber.Create(FBuckets[I].UpperBound));
      LBucket.AddPair('count', TJSONNumber.Create(FBuckets[I].Count));
      LBuckets.AddElement(LBucket);
    end;
  finally
    FLock.Leave;
  end;
  Result.AddPair('buckets', LBuckets);
end;

function THistogram.ToPrometheus: string;
var
  I: Integer;
  LLabels: string;
begin
  Result := Format('# HELP %s %s'#10, [FName, FDescription]);
  Result := Result + Format('# TYPE %s histogram'#10, [FName]);
  
  FLock.Enter;
  try
    for I := 0 to High(FBuckets) do
    begin
      if Length(FLabels) > 0 then
        LLabels := Copy(LabelsToPrometheus, 1, Length(LabelsToPrometheus) - 1) + ','
      else
        LLabels := '{';
        
      if IsInfinite(FBuckets[I].UpperBound) then
        Result := Result + Format('%s_bucket%sle="+Inf"} %d'#10, [FName, LLabels, FBuckets[I].Count])
      else
        Result := Result + Format('%s_bucket%sle="%g"} %d'#10, [FName, LLabels, FBuckets[I].UpperBound, FBuckets[I].Count]);
    end;
    
    Result := Result + Format('%s_sum%s %g'#10, [FName, LabelsToPrometheus, FSum]);
    Result := Result + Format('%s_count%s %d'#10, [FName, LabelsToPrometheus, FCount]);
  finally
    FLock.Leave;
  end;
end;

function THistogram.ToInfluxLine(const AMeasurement: string): string;
var
  LMeasurement: string;
begin
  if AMeasurement <> '' then
    LMeasurement := AMeasurement
  else
    LMeasurement := FName;
  Result := Format('%s%s count=%di,sum=%g,min=%g,max=%g,mean=%g', 
    [LMeasurement, LabelsToInflux, Count, Sum, Min, Max, Mean]);
end;

class function THistogram.DefaultBuckets: TArray<Double>;
begin
  Result := TArray<Double>.Create(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10);
end;

class function THistogram.LinearBuckets(AStart, AWidth: Double; ACount: Integer): TArray<Double>;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := AStart + (I * AWidth);
end;

class function THistogram.ExponentialBuckets(AStart, AFactor: Double; ACount: Integer): TArray<Double>;
var
  I: Integer;
begin
  if AStart <= 0 then
    raise EMetricsException.Create('ExponentialBuckets start must be positive');
  if AFactor <= 1 then
    raise EMetricsException.Create('ExponentialBuckets factor must be greater than 1');
    
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
    Result[I] := AStart * Power(AFactor, I);
end;

{ TTimer }

constructor TTimer.Create(const AName, ADescription: string; const ALabels: TMetricLabels;
  const ABuckets: TArray<Double>);
begin
  inherited Create(AName, ADescription, ALabels);
  FMetricType := mtTimer;
  FHistogram := THistogram.Create(AName, ADescription, ALabels, ABuckets);
  FActiveTimers := 0;
end;

destructor TTimer.Destroy;
begin
  FreeAndNil(FHistogram);
  inherited;
end;

function TTimer.Start: TProc;
var
  LStartTime: TDateTime;
begin
  LStartTime := Now;
  
  FLock.Enter;
  try
    System.Inc(FActiveTimers);
  finally
    FLock.Leave;
  end;
  
  Result := procedure
  begin
    Self.RecordDuration(SecondSpan(LStartTime, Now));
    Self.FLock.Enter;
    try
      System.Dec(Self.FActiveTimers);
    finally
      Self.FLock.Leave;
    end;
  end;
end;

procedure TTimer.RecordDuration(ADurationSeconds: Double);
begin
  FHistogram.Observe(ADurationSeconds);
end;

procedure TTimer.RecordMs(ADurationMs: Double);
begin
  FHistogram.Observe(ADurationMs / 1000);
end;

procedure TTimer.Time(AProc: TProc);
var
  LStart: TDateTime;
begin
  LStart := Now;
  
  FLock.Enter;
  try
    System.Inc(FActiveTimers);
  finally
    FLock.Leave;
  end;
  
  try
    AProc;
  finally
    RecordDuration(SecondSpan(LStart, Now));
    FLock.Enter;
    try
      System.Dec(FActiveTimers);
    finally
      FLock.Leave;
    end;
  end;
end;

function TTimer.TimeFunc<T>(AFunc: TFunc<T>): T;
var
  LStart: TDateTime;
begin
  LStart := Now;
  
  FLock.Enter;
  try
    System.Inc(FActiveTimers);
  finally
    FLock.Leave;
  end;
  
  try
    Result := AFunc;
  finally
    RecordDuration(SecondSpan(LStart, Now));
    FLock.Enter;
    try
      System.Dec(FActiveTimers);
    finally
      FLock.Leave;
    end;
  end;
end;

function TTimer.ToJSON: TJSONObject;
begin
  Result := FHistogram.ToJSON;
  Result.AddPair('activeTimers', TJSONNumber.Create(FActiveTimers));
end;

function TTimer.ToPrometheus: string;
begin
  Result := FHistogram.ToPrometheus;
end;

function TTimer.ToInfluxLine(const AMeasurement: string): string;
begin
  Result := FHistogram.ToInfluxLine(AMeasurement);
end;

{ TSummary }

constructor TSummary.Create(const AName, ADescription: string; const ALabels: TMetricLabels;
  const AQuantiles: TArray<Double>; AMaxSamples: Integer);
begin
  inherited Create(AName, ADescription, ALabels);
  FMetricType := mtSummary;
  FValues := TList<Double>.Create;
  FQuantiles := Copy(AQuantiles);
  FMaxSamples := AMaxSamples;
  FSum := 0;
  FCount := 0;
end;

destructor TSummary.Destroy;
begin
  FreeAndNil(FValues);
  inherited;
end;

procedure TSummary.Observe(AValue: Double);
begin
  FLock.Enter;
  try
    FValues.Add(AValue);
    FSum := FSum + AValue;
    System.Inc(FCount);
    
    // 添加数据点数量限制和定期清理机制
    if FValues.Count > FMaxSamples then
    begin
      // 清理最旧的一半数据点，防止内存无限增长
      while FValues.Count > FMaxSamples div 2 do
        FValues.Delete(0);
    end;
    
    // 定期清理：每1000次观测清理一次旧数据
    if FCount mod 1000 = 0 then
    begin
      while FValues.Count > FMaxSamples div 2 do
        FValues.Delete(0);
    end;
  finally
    FLock.Leave;
  end;
end;

function TSummary.GetQuantiles: TArray<TSummaryQuantile>;
var
  I, LIdx: Integer;
  LSorted: TArray<Double>;
begin
  FLock.Enter;
  try
    if FValues.Count = 0 then
    begin
      SetLength(Result, Length(FQuantiles));
      for I := 0 to High(FQuantiles) do
      begin
        Result[I].Quantile := FQuantiles[I];
        Result[I].Value := 0;
        Result[I].Error := 0;
      end;
      Exit;
    end;
    
    LSorted := FValues.ToArray;
    TArray.Sort<Double>(LSorted);
    
    SetLength(Result, Length(FQuantiles));
    for I := 0 to High(FQuantiles) do
    begin
      Result[I].Quantile := FQuantiles[I];
      LIdx := Trunc(FQuantiles[I] * (Length(LSorted) - 1));
      Result[I].Value := LSorted[LIdx];
      Result[I].Error := 0.001; // Fixed error for now
    end;
  finally
    FLock.Leave;
  end;
end;

function TSummary.Sum: Double;
begin
  FLock.Enter;
  try
    Result := FSum;
  finally
    FLock.Leave;
  end;
end;

function TSummary.Count: Int64;
begin
  FLock.Enter;
  try
    Result := FCount;
  finally
    FLock.Leave;
  end;
end;

procedure TSummary.Reset;
begin
  FLock.Enter;
  try
    FValues.Clear;
    FSum := 0;
    FCount := 0;
  finally
    FLock.Leave;
  end;
end;

function TSummary.ToJSON: TJSONObject;
var
  LQuantiles: TJSONArray;
  LQuantile: TJSONObject;
  LQ: TSummaryQuantile;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('type', 'summary');
  Result.AddPair('description', FDescription);
  Result.AddPair('count', TJSONNumber.Create(Count));
  Result.AddPair('sum', TJSONNumber.Create(Sum));
  
  LQuantiles := TJSONArray.Create;
  for LQ in GetQuantiles do
  begin
    LQuantile := TJSONObject.Create;
    LQuantile.AddPair('quantile', TJSONNumber.Create(LQ.Quantile));
    LQuantile.AddPair('value', TJSONNumber.Create(LQ.Value));
    LQuantiles.AddElement(LQuantile);
  end;
  Result.AddPair('quantiles', LQuantiles);
end;

function TSummary.ToPrometheus: string;
var
  LQ: TSummaryQuantile;
  LLabels: string;
begin
  Result := Format('# HELP %s %s'#10, [FName, FDescription]);
  Result := Result + Format('# TYPE %s summary'#10, [FName]);
  
  for LQ in GetQuantiles do
  begin
    if Length(FLabels) > 0 then
      LLabels := Copy(LabelsToPrometheus, 1, Length(LabelsToPrometheus) - 1) + ','
    else
      LLabels := '{';
    Result := Result + Format('%s%squantile="%g"} %g'#10, [FName, LLabels, LQ.Quantile, LQ.Value]);
  end;
  
  Result := Result + Format('%s_sum%s %g'#10, [FName, LabelsToPrometheus, Sum]);
  Result := Result + Format('%s_count%s %d'#10, [FName, LabelsToPrometheus, Count]);
end;

function TSummary.ToInfluxLine(const AMeasurement: string): string;
var
  LMeasurement: string;
  LQ: TSummaryQuantile;
begin
  if AMeasurement <> '' then
    LMeasurement := AMeasurement
  else
    LMeasurement := FName;
    
  Result := Format('%s%s count=%di,sum=%g', [LMeasurement, LabelsToInflux, Count, Sum]);
  
  for LQ in GetQuantiles do
    Result := Result + Format(',p%d=%g', [Round(LQ.Quantile * 100), LQ.Value]);
end;

class function TSummary.DefaultQuantiles: TArray<Double>;
begin
  Result := TArray<Double>.Create(0.5, 0.9, 0.95, 0.99);
end;

{ TMetricFamily<T> }

constructor TMetricFamily<T>.Create(const AName, ADescription: string);
begin
  inherited Create;
  FName := AName;
  FDescription := ADescription;
  FMetrics := TObjectDictionary<string, T>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
end;

destructor TMetricFamily<T>.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FMetrics);
  inherited;
end;

function TMetricFamily<T>.LabelsToKey(const ALabels: TMetricLabels): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ALabels) do
  begin
    if Result <> '' then
      Result := Result + ',';
    Result := Result + ALabels[I].Name + '=' + ALabels[I].Value;
  end;
end;

function TMetricFamily<T>.WithLabels(const ALabels: array of TMetricLabel): T;
var
  LLabels: TMetricLabels;
  LKey: string;
  I: Integer;
begin
  SetLength(LLabels, Length(ALabels));
  for I := 0 to High(ALabels) do
    LLabels[I] := ALabels[I];
    
  LKey := LabelsToKey(LLabels);
  
  FLock.Enter;
  try
    if not FMetrics.TryGetValue(LKey, Result) then
    begin
      // Create new metric based on type
      if TypeInfo(T) = TypeInfo(TCounter) then
        Result := T(TCounter.Create(FName, FDescription, LLabels))
      else if TypeInfo(T) = TypeInfo(TGauge) then
        Result := T(TGauge.Create(FName, FDescription, LLabels))
      else if TypeInfo(T) = TypeInfo(THistogram) then
        Result := T(THistogram.Create(FName, FDescription, LLabels, FBuckets))
      else if TypeInfo(T) = TypeInfo(TTimer) then
        Result := T(TTimer.Create(FName, FDescription, LLabels, FBuckets))
      else if TypeInfo(T) = TypeInfo(TSummary) then
        Result := T(TSummary.Create(FName, FDescription, LLabels, FQuantiles));
        
      FMetrics.Add(LKey, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricFamily<T>.WithLabels(const ALabelNames: array of string; 
  const ALabelValues: array of string): T;
var
  LLabels: TMetricLabels;
  I: Integer;
begin
  if Length(ALabelNames) <> Length(ALabelValues) then
    raise EMetricsException.Create('Label names and values must have same length');
    
  SetLength(LLabels, Length(ALabelNames));
  for I := 0 to High(ALabelNames) do
    LLabels[I] := TMetricLabel.Create(ALabelNames[I], ALabelValues[I]);
    
  Result := WithLabels(LLabels);
end;

function TMetricFamily<T>.GetAll: TArray<T>;
var
  LList: TList<T>;
  LPair: TPair<string, T>;
begin
  LList := TList<T>.Create;
  try
    FLock.Enter;
    try
      for LPair in FMetrics do
        LList.Add(LPair.Value);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

procedure TMetricFamily<T>.Remove(const ALabels: TMetricLabels);
var
  LKey: string;
begin
  LKey := LabelsToKey(ALabels);
  FLock.Enter;
  try
    FMetrics.Remove(LKey);
  finally
    FLock.Leave;
  end;
end;

procedure TMetricFamily<T>.Clear;
begin
  FLock.Enter;
  try
    FMetrics.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TMetricsRegistry }

constructor TMetricsRegistry.Create(const APrefix: string);
begin
  inherited Create;
  FMetrics := TDictionary<string, IMetric>.Create;
  FFamilies := TObjectDictionary<string, TObject>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FPrefix := APrefix;
end;

destructor TMetricsRegistry.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FFamilies);
  FreeAndNil(FMetrics);
  inherited;
end;

function TMetricsRegistry.Counter(const AName, ADescription: string): TCounter;
begin
  Result := Counter(AName, ADescription, nil);
end;

function TMetricsRegistry.Counter(const AName, ADescription: string; 
  const ALabels: TMetricLabels): TCounter;
var
  LName: string;
begin
  LName := FPrefix + AName;
  
  FLock.Enter;
  try
    if FMetrics.ContainsKey(LName) then
      Result := FMetrics[LName] as TCounter
    else
    begin
      Result := TCounter.Create(LName, ADescription, ALabels);
      FMetrics.Add(LName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Gauge(const AName, ADescription: string): TGauge;
begin
  Result := Gauge(AName, ADescription, nil);
end;

function TMetricsRegistry.Gauge(const AName, ADescription: string;
  const ALabels: TMetricLabels): TGauge;
var
  LName: string;
begin
  LName := FPrefix + AName;
  
  FLock.Enter;
  try
    if FMetrics.ContainsKey(LName) then
      Result := FMetrics[LName] as TGauge
    else
    begin
      Result := TGauge.Create(LName, ADescription, ALabels);
      FMetrics.Add(LName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Histogram(const AName, ADescription: string;
  const ABuckets: TArray<Double>): THistogram;
begin
  Result := Histogram(AName, ADescription, nil, ABuckets);
end;

function TMetricsRegistry.Histogram(const AName, ADescription: string;
  const ALabels: TMetricLabels; const ABuckets: TArray<Double>): THistogram;
var
  LName: string;
  LBuckets: TArray<Double>;
begin
  LName := FPrefix + AName;
  
  if Length(ABuckets) = 0 then
    LBuckets := THistogram.DefaultBuckets
  else
    LBuckets := ABuckets;
  
  FLock.Enter;
  try
    if FMetrics.ContainsKey(LName) then
      Result := FMetrics[LName] as THistogram
    else
    begin
      Result := THistogram.Create(LName, ADescription, ALabels, LBuckets);
      FMetrics.Add(LName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Timer(const AName, ADescription: string): TTimer;
begin
  Result := Timer(AName, ADescription, nil);
end;

function TMetricsRegistry.Timer(const AName, ADescription: string;
  const ALabels: TMetricLabels): TTimer;
var
  LName: string;
begin
  LName := FPrefix + AName;
  
  FLock.Enter;
  try
    if FMetrics.ContainsKey(LName) then
      Result := FMetrics[LName] as TTimer
    else
    begin
      Result := TTimer.Create(LName, ADescription, ALabels, THistogram.DefaultBuckets);
      FMetrics.Add(LName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Summary(const AName, ADescription: string): TSummary;
begin
  Result := Summary(AName, ADescription, nil);
end;

function TMetricsRegistry.Summary(const AName, ADescription: string;
  const ALabels: TMetricLabels): TSummary;
var
  LName: string;
begin
  LName := FPrefix + AName;
  
  FLock.Enter;
  try
    if FMetrics.ContainsKey(LName) then
      Result := FMetrics[LName] as TSummary
    else
    begin
      Result := TSummary.Create(LName, ADescription, ALabels, TSummary.DefaultQuantiles);
      FMetrics.Add(LName, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Get(const AName: string): IMetric;
begin
  FLock.Enter;
  try
    if not FMetrics.TryGetValue(FPrefix + AName, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.Exists(const AName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FMetrics.ContainsKey(FPrefix + AName);
  finally
    FLock.Leave;
  end;
end;

procedure TMetricsRegistry.Unregister(const AName: string);
begin
  FLock.Enter;
  try
    FMetrics.Remove(FPrefix + AName);
  finally
    FLock.Leave;
  end;
end;

function TMetricsRegistry.GetAll: TArray<IMetric>;
var
  LList: TList<IMetric>;
  LPair: TPair<string, IMetric>;
begin
  LList := TList<IMetric>.Create;
  try
    FLock.Enter;
    try
      for LPair in FMetrics do
        LList.Add(LPair.Value);
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TMetricsRegistry.ToJSON: TJSONObject;
var
  LMetrics: TJSONArray;
  LMetric: IMetric;
begin
  Result := TJSONObject.Create;
  LMetrics := TJSONArray.Create;
  
  FLock.Enter;
  try
    for LMetric in FMetrics.Values do
      LMetrics.AddElement(LMetric.ToJSON);
  finally
    FLock.Leave;
  end;
  
  Result.AddPair('metrics', LMetrics);
  Result.AddPair('timestamp', DateTimeToStr(Now));
end;

function TMetricsRegistry.ToPrometheus: string;
var
  LBuilder: TStringBuilder;
  LMetric: IMetric;
begin
  LBuilder := TStringBuilder.Create;
  try
    FLock.Enter;
    try
      for LMetric in FMetrics.Values do
        LBuilder.Append(LMetric.ToPrometheus);
    finally
      FLock.Leave;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TMetricsRegistry.ToInfluxLines: string;
var
  LBuilder: TStringBuilder;
  LMetric: IMetric;
  LTimestamp: Int64;
begin
  LBuilder := TStringBuilder.Create;
  try
    LTimestamp := DateTimeToUnix(Now, False) * 1000000000; // nanoseconds
    
    FLock.Enter;
    try
      for LMetric in FMetrics.Values do
      begin
        LBuilder.Append(LMetric.ToInfluxLine);
        LBuilder.AppendFormat(' %d', [LTimestamp]);
        LBuilder.AppendLine;
      end;
    finally
      FLock.Leave;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TMetricsRegistry.Clear;
begin
  FLock.Enter;
  try
    FMetrics.Clear;
    FFamilies.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TScopedTimer }

constructor TScopedTimer.Create(ATimer: TTimer);
begin
  inherited Create;
  FTimer := ATimer;
  FStartTime := Now;
  FStopped := False;
end;

destructor TScopedTimer.Destroy;
begin
  if not FStopped then
    Stop;
  inherited;
end;

procedure TScopedTimer.Stop;
begin
  if not FStopped then
  begin
    FStopped := True;
    FTimer.RecordDuration(SecondSpan(FStartTime, Now));
  end;
end;

{ TMetrics }

class destructor TMetrics.Destroy;
begin
  FreeAndNil(FRegistry);
end;

class function TMetrics.GetRegistry: TMetricsRegistry;
begin
  if not Assigned(FRegistry) then
    FRegistry := TMetricsRegistry.Create;
  Result := FRegistry;
end;

class function TMetrics.Counter(const AName, ADescription: string): TCounter;
begin
  Result := Registry.Counter(AName, ADescription);
end;

class function TMetrics.Counter(const AName: string): TCounter;
begin
  Result := Registry.Counter(AName, '');
end;

class function TMetrics.Gauge(const AName, ADescription: string): TGauge;
begin
  Result := Registry.Gauge(AName, ADescription);
end;

class function TMetrics.Gauge(const AName: string): TGauge;
begin
  Result := Registry.Gauge(AName, '');
end;

class function TMetrics.Histogram(const AName, ADescription: string): THistogram;
begin
  Result := Registry.Histogram(AName, ADescription, nil);
end;

class function TMetrics.Timer(const AName, ADescription: string): TTimer;
begin
  Result := Registry.Timer(AName, ADescription);
end;

class function TMetrics.StartTimer(const AName: string): IScopedTimer;
var
  LTimer: TTimer;
begin
  LTimer := Registry.Timer(AName, '');
  Result := TScopedTimer.Create(LTimer);
end;

class procedure TMetrics.Inc(const AName: string; AAmount: Int64);
begin
  Counter(AName).Inc(AAmount);
end;

class procedure TMetrics.SetGauge(const AName: string; AValue: Double);
begin
  Gauge(AName).SetValue(AValue);
end;

class procedure TMetrics.Observe(const AName: string; AValue: Double);
begin
  Histogram(AName, '').Observe(AValue);
end;

initialization
  GRegistryLock := TCriticalSection.Create;
  
finalization
  FreeAndNil(GMetricsRegistry);
  FreeAndNil(GRegistryLock);
  
end.
