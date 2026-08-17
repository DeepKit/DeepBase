{*******************************************************}
{                                                       }
{       DeepBase Framework                               }
{       Web API Observability                           }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit DeepBase.WebAPI.Observability;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.SyncObjs,
  System.DateUtils,
  DeepBase.WebAPI.Core;

type
  // Web API 健康检查状态
  TWebHealthStatus = (whsHealthy, whsDegraded, whsUnhealthy);

  // Web API 单项健康检查结果
  TWebHealthCheckResult = record
    Name: string;
    Status: TWebHealthStatus;
    DurationMs: Double;
    Message: string;
  public
    class function Healthy(const AName: string; const AMessage: string = '';
      ADurationMs: Double = 0): TWebHealthCheckResult; static;
    class function Degraded(const AName: string; const AMessage: string = '';
      ADurationMs: Double = 0): TWebHealthCheckResult; static;
    class function Unhealthy(const AName: string; const AMessage: string = '';
      ADurationMs: Double = 0): TWebHealthCheckResult; static;
    function ToJSON: TJSONObject;
  end;

  // Web API 健康检查函数类型
  TWebHealthCheckFunc = reference to function: TWebHealthCheckResult;

  // Web API 健康检查注册表
  TWebHealthCheckRegistry = class
  private
    FLock: TCriticalSection;
    FChecks: TList<TPair<string, TWebHealthCheckFunc>>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>注册一个健康检查</summary>
    procedure Register(const AName: string; ACheck: TWebHealthCheckFunc);

    /// <summary>运行所有健康检查，返回汇总 JSON</summary>
    function RunAll: TJSONObject;
  end;

  // 度量类型
  TMetricType = (mtCounter, mtGauge, mtHistogram);

  // 度量标签
  TMetricLabels = TDictionary<string, string>;

  // 直方图桶
  THistogramBucket = record
    UpperBound: Double;
    Count: Int64;
  end;

  // 单个度量系列
  TMetricSeries = class
  private
    FType: TMetricType;
    FName: string;
    FHelp: string;
    FLock: TCriticalSection;
    FValues: TDictionary<string, Double>;
    FHistograms: TDictionary<string, TPair<TArray<THistogramBucket>, Int64>>;
    FBuckets: TArray<Double>;
  public
    constructor Create(const AName, AHelp: string; AType: TMetricType;
      const ABuckets: array of Double);
    destructor Destroy; override;

    procedure Increment(const ALabels: TMetricLabels; AValue: Double = 1);
    procedure SetGauge(const ALabels: TMetricLabels; AValue: Double);
    procedure Observe(const ALabels: TMetricLabels; AValue: Double);
    function ToPrometheus: string;
  end;

  // 度量收集器
  TMetricsCollector = class
  private
    FLock: TCriticalSection;
    FMetrics: TObjectDictionary<string, TMetricSeries>;
    FStartTime: TDateTime;
    procedure EnsureMetric(const AName, AHelp: string; AType: TMetricType;
      const ABuckets: array of Double);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>计数器递增</summary>
    procedure Counter(const AName, AHelp: string;
      const ALabels: TMetricLabels; AValue: Double = 1);

    /// <summary>设置仪表值</summary>
    procedure Gauge(const AName, AHelp: string;
      const ALabels: TMetricLabels; AValue: Double);

    /// <summary>直方图观测</summary>
    procedure Histogram(const AName, AHelp: string;
      const ALabels: TMetricLabels; AValue: Double;
      const ABuckets: array of Double);

    /// <summary>输出 Prometheus 纯文本格式</summary>
    function ToPrometheus: string;

    /// <summary>服务器启动以来的秒数</summary>
    function UptimeSeconds: Double;
  end;

  // 可观测性中间件 + 端点注册
  TObservability = class
  public
    /// <summary>注册 GET /health 端点</summary>
    class procedure RegisterHealthEndpoint(AServer: TApiServer;
      ARegistry: TWebHealthCheckRegistry);

    /// <summary>注册 GET /metrics 端点 (Prometheus 格式)</summary>
    class procedure RegisterMetricsEndpoint(AServer: TApiServer;
      ACollector: TMetricsCollector);

    /// <summary>创建请求度量中间件 (计数 + 延迟直方图)</summary>
    class function CreateRequestMetricsMiddleware(ACollector: TMetricsCollector;
      const ABuckets: array of Double): TMiddlewareFunc;

    /// <summary>默认直方图桶 (秒)</summary>
    class function DefaultDurationBuckets: TArray<Double>;

    /// <summary>TWebHealthStatus → 字符串</summary>
    class function StatusToString(AStatus: TWebHealthStatus): string;

    /// <summary>THttpMethod → 字符串</summary>
    class function HttpMethodToString(AMethod: THttpMethod): string;
  end;

implementation

uses
  System.Math;

{ 辅助函数 }

function FormatLabels(const ALabels: TMetricLabels): string;
var
  LPair: TPair<string, string>;
  LFirst: Boolean;
begin
  if (ALabels = nil) or (ALabels.Count = 0) then
  begin
    Result := '';
    Exit;
  end;
  Result := '{';
  LFirst := True;
  for LPair in ALabels do
  begin
    if not LFirst then
      Result := Result + ',';
    Result := Result + LPair.Key + '="' + LPair.Value + '"';
    LFirst := False;
  end;
  Result := Result + '}';
end;

function FormatMetricValue(AValue: Double): string;
begin
  if Trunc(AValue) = AValue then
    Result := IntToStr(Trunc(AValue))
  else
    Result := FloatToStr(AValue);
end;

function FormatBucketBound(AValue: Double): string;
begin
  if IsInfinite(AValue) then
    Result := '+Inf'
  else
    Result := FloatToStr(AValue);
end;

{ TWebHealthCheckResult }

class function TWebHealthCheckResult.Healthy(const AName, AMessage: string;
  ADurationMs: Double): TWebHealthCheckResult;
begin
  Result.Name := AName;
  Result.Status := whsHealthy;
  Result.DurationMs := ADurationMs;
  Result.Message := AMessage;
end;

class function TWebHealthCheckResult.Degraded(const AName, AMessage: string;
  ADurationMs: Double): TWebHealthCheckResult;
begin
  Result.Name := AName;
  Result.Status := whsDegraded;
  Result.DurationMs := ADurationMs;
  Result.Message := AMessage;
end;

class function TWebHealthCheckResult.Unhealthy(const AName, AMessage: string;
  ADurationMs: Double): TWebHealthCheckResult;
begin
  Result.Name := AName;
  Result.Status := whsUnhealthy;
  Result.DurationMs := ADurationMs;
  Result.Message := AMessage;
end;

function TWebHealthCheckResult.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('status',
    TObservability.StatusToString(Status));
  Result.AddPair('duration_ms', TJSONNumber.Create(DurationMs));
  if Message <> '' then
    Result.AddPair('message', Message);
end;

{ TWebHealthCheckRegistry }

constructor TWebHealthCheckRegistry.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FChecks := TList<TPair<string, TWebHealthCheckFunc>>.Create;
end;

destructor TWebHealthCheckRegistry.Destroy;
begin
  FChecks.Free;
  FLock.Free;
  inherited;
end;

procedure TWebHealthCheckRegistry.Register(const AName: string;
  ACheck: TWebHealthCheckFunc);
begin
  FLock.Enter;
  try
    FChecks.Add(TPair<string, TWebHealthCheckFunc>.Create(AName, ACheck));
  finally
    FLock.Leave;
  end;
end;

function TWebHealthCheckRegistry.RunAll: TJSONObject;
var
  LStart, LEnd: TDateTime;
  LItem: TPair<string, TWebHealthCheckFunc>;
  LCheckFunc: TWebHealthCheckFunc;
  LResult: TWebHealthCheckResult;
  LChecksArr: TJSONArray;
  LHighest: TWebHealthStatus;
  LChecks: TArray<TPair<string, TWebHealthCheckFunc>>;
  I: Integer;
begin
  // Snapshot the list under lock, run checks outside lock to avoid deadlock
  FLock.Enter;
  try
    LChecks := FChecks.ToArray;
  finally
    FLock.Leave;
  end;

  LChecksArr := TJSONArray.Create;
  try
    LHighest := whsHealthy;
    for I := 0 to High(LChecks) do
    begin
      LItem := LChecks[I];
      LCheckFunc := LItem.Value;
      LStart := Now;
      try
        LResult := LCheckFunc();
        LEnd := Now;
        if LResult.Name = '' then
          LResult.Name := LItem.Key;
        LResult.DurationMs := MilliSecondsBetween(LEnd, LStart);
      except
        on E: Exception do
        begin
          LEnd := Now;
          LResult := TWebHealthCheckResult.Unhealthy(LItem.Key, E.Message,
            MilliSecondsBetween(LEnd, LStart));
        end;
      end;
      LChecksArr.AddElement(LResult.ToJSON);
      if Ord(LResult.Status) > Ord(LHighest) then
        LHighest := LResult.Status;
    end;

    Result := TJSONObject.Create;
    Result.AddPair('status', TObservability.StatusToString(LHighest));
    Result.AddPair('timestamp',
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now));
    Result.AddPair('checks', LChecksArr);
  except
    LChecksArr.Free;
    raise;
  end;
end;

{ TMetricSeries }

constructor TMetricSeries.Create(const AName, AHelp: string;
  AType: TMetricType; const ABuckets: array of Double);
var
  I: Integer;
begin
  inherited Create;
  FName := AName;
  FHelp := AHelp;
  FType := AType;
  FLock := TCriticalSection.Create;
  FValues := TDictionary<string, Double>.Create;
  FHistograms := TDictionary<string,
    TPair<TArray<THistogramBucket>, Int64>>.Create;
  SetLength(FBuckets, Length(ABuckets));
  for I := 0 to High(ABuckets) do
    FBuckets[I] := ABuckets[I];
end;

destructor TMetricSeries.Destroy;
begin
  FHistograms.Free;
  FValues.Free;
  FLock.Free;
  inherited;
end;

function LabelsKey(const ALabels: TMetricLabels): string;
var
  LPair: TPair<string, string>;
  LFirst: Boolean;
begin
  if (ALabels = nil) or (ALabels.Count = 0) then
  begin
    Result := '';
    Exit;
  end;
  Result := '';
  LFirst := True;
  for LPair in ALabels do
  begin
    if not LFirst then
      Result := Result + ',';
    Result := Result + LPair.Key + '="' + LPair.Value + '"';
    LFirst := False;
  end;
end;

procedure TMetricSeries.Increment(const ALabels: TMetricLabels;
  AValue: Double);
var
  LKey: string;
  LCur: Double;
begin
  FLock.Enter;
  try
    LKey := LabelsKey(ALabels);
    if FValues.TryGetValue(LKey, LCur) then
      FValues[LKey] := LCur + AValue
    else
      FValues.Add(LKey, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TMetricSeries.SetGauge(const ALabels: TMetricLabels; AValue: Double);
var
  LKey: string;
begin
  FLock.Enter;
  try
    LKey := LabelsKey(ALabels);
    FValues.AddOrSetValue(LKey, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure TMetricSeries.Observe(const ALabels: TMetricLabels; AValue: Double);
var
  LKey: string;
  LBuckets: TArray<THistogramBucket>;
  LTotal: Int64;
  LEntry: TPair<TArray<THistogramBucket>, Int64>;
  I: Integer;
  LNew: TPair<TArray<THistogramBucket>, Int64>;
begin
  FLock.Enter;
  try
    LKey := LabelsKey(ALabels);
    if not FHistograms.TryGetValue(LKey, LEntry) then
    begin
      SetLength(LBuckets, Length(FBuckets));
      for I := 0 to High(FBuckets) do
      begin
        LBuckets[I].UpperBound := FBuckets[I];
        LBuckets[I].Count := 0;
      end;
      LTotal := 0;
    end
    else
    begin
      LBuckets := LEntry.Key;
      LTotal := LEntry.Value;
    end;
    for I := 0 to High(LBuckets) do
      if AValue <= LBuckets[I].UpperBound then
        Inc(LBuckets[I].Count);
    Inc(LTotal);
    LNew := TPair<TArray<THistogramBucket>, Int64>.Create(LBuckets, LTotal);
    if FHistograms.ContainsKey(LKey) then
      FHistograms[LKey] := LNew
    else
      FHistograms.Add(LKey, LNew);
  finally
    FLock.Leave;
  end;
end;

function TMetricSeries.ToPrometheus: string;
var
  LPair: TPair<string, Double>;
  LHisto: TPair<string, TPair<TArray<THistogramBucket>, Int64>>;
  LLines: TStringList;
  I: Integer;
  LSum: Double;
  LBuckets: TArray<THistogramBucket>;
  LTotal: Int64;
  LLabelBase: string;
begin
  LLines := TStringList.Create;
  try
    LLines.Add(Format('# HELP %s %s', [FName, FHelp]));
    case FType of
      mtCounter:
      begin
        LLines.Add(Format('# TYPE %s counter', [FName]));
        for LPair in FValues do
          LLines.Add(Format('%s{%s} %s',
            [FName, LPair.Key, FormatMetricValue(LPair.Value)]));
      end;
      mtGauge:
      begin
        LLines.Add(Format('# TYPE %s gauge', [FName]));
        for LPair in FValues do
          LLines.Add(Format('%s{%s} %s',
            [FName, LPair.Key, FormatMetricValue(LPair.Value)]));
      end;
      mtHistogram:
      begin
        LLines.Add(Format('# TYPE %s histogram', [FName]));
        for LHisto in FHistograms do
        begin
          LBuckets := LHisto.Value.Key;
          LTotal := LHisto.Value.Value;
          LLabelBase := LHisto.Key;
          LSum := 0;
          for I := 0 to High(LBuckets) do
          begin
            if LLabelBase <> '' then
              LLines.Add(Format('%s_bucket{%s,le="%s"} %d',
                [FName, LLabelBase,
                FormatBucketBound(LBuckets[I].UpperBound),
                LBuckets[I].Count]))
            else
              LLines.Add(Format('%s_bucket{le="%s"} %d',
                [FName, FormatBucketBound(LBuckets[I].UpperBound),
                LBuckets[I].Count]));
          end;
          // +Inf bucket
          if LLabelBase <> '' then
          begin
            LLines.Add(Format('%s_bucket{%s,le="+Inf"} %d',
              [FName, LLabelBase, LTotal]));
            LLines.Add(Format('%s_count{%s} %d',
              [FName, LLabelBase, LTotal]));
          end
          else
          begin
            LLines.Add(Format('%s_bucket{le="+Inf"} %d',
              [FName, LTotal]));
            LLines.Add(Format('%s_count %d', [FName, LTotal]));
          end;
          // Compute approximate sum
          for I := 0 to High(LBuckets) do
            LSum := LSum + LBuckets[I].Count * LBuckets[I].UpperBound;
          if LLabelBase <> '' then
            LLines.Add(Format('%s_sum{%s} %s',
              [FName, LLabelBase, FormatMetricValue(LSum)]))
          else
            LLines.Add(Format('%s_sum %s',
              [FName, FormatMetricValue(LSum)]));
        end;
      end;
    end;
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

{ TMetricsCollector }

constructor TMetricsCollector.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FMetrics := TObjectDictionary<string, TMetricSeries>.Create([doOwnsValues]);
  FStartTime := Now;
end;

destructor TMetricsCollector.Destroy;
begin
  FMetrics.Free;
  FLock.Free;
  inherited;
end;

procedure TMetricsCollector.EnsureMetric(const AName, AHelp: string;
  AType: TMetricType; const ABuckets: array of Double);
var
  LSeries: TMetricSeries;
begin
  // Caller already holds FLock in Counter/Gauge/Histogram paths,
  // but EnsureMetric is also called without lock from public methods.
  // We use a simple pattern: double-check under lock.
  if not FMetrics.TryGetValue(AName, LSeries) then
  begin
    LSeries := TMetricSeries.Create(AName, AHelp, AType, ABuckets);
    FMetrics.Add(AName, LSeries);
  end;
end;

procedure TMetricsCollector.Counter(const AName, AHelp: string;
  const ALabels: TMetricLabels; AValue: Double);
var
  LSeries: TMetricSeries;
begin
  FLock.Enter;
  try
    EnsureMetric(AName, AHelp, mtCounter, []);
    LSeries := FMetrics.Items[AName];
  finally
    FLock.Leave;
  end;
  LSeries.Increment(ALabels, AValue);
end;

procedure TMetricsCollector.Gauge(const AName, AHelp: string;
  const ALabels: TMetricLabels; AValue: Double);
var
  LSeries: TMetricSeries;
begin
  FLock.Enter;
  try
    EnsureMetric(AName, AHelp, mtGauge, []);
    LSeries := FMetrics.Items[AName];
  finally
    FLock.Leave;
  end;
  LSeries.SetGauge(ALabels, AValue);
end;

procedure TMetricsCollector.Histogram(const AName, AHelp: string;
  const ALabels: TMetricLabels; AValue: Double;
  const ABuckets: array of Double);
var
  LSeries: TMetricSeries;
begin
  FLock.Enter;
  try
    EnsureMetric(AName, AHelp, mtHistogram, ABuckets);
    LSeries := FMetrics.Items[AName];
  finally
    FLock.Leave;
  end;
  LSeries.Observe(ALabels, AValue);
end;

function TMetricsCollector.ToPrometheus: string;
var
  LSeries: TMetricSeries;
  LLines: TStringList;
  LSnapshot: TArray<TMetricSeries>;
begin
  LLines := TStringList.Create;
  try
    FLock.Enter;
    try
      LLines.Add('# HELP process_uptime_seconds Server uptime in seconds');
      LLines.Add('# TYPE process_uptime_seconds gauge');
      LLines.Add(Format('process_uptime_seconds %s',
        [FormatMetricValue(UptimeSeconds)]));
      // Snapshot to avoid holding lock during serialization
      SetLength(LSnapshot, FMetrics.Count);
      LSnapshot := FMetrics.Values.ToArray;
    finally
      FLock.Leave;
    end;
    for LSeries in LSnapshot do
      LLines.Add(LSeries.ToPrometheus);
    Result := LLines.Text;
  finally
    LLines.Free;
  end;
end;

function TMetricsCollector.UptimeSeconds: Double;
begin
  Result := (Now - FStartTime) * SecsPerDay;
end;

{ TObservability }

class function TObservability.DefaultDurationBuckets: TArray<Double>;
begin
  SetLength(Result, 9);
  Result[0] := 0.005;
  Result[1] := 0.01;
  Result[2] := 0.025;
  Result[3] := 0.05;
  Result[4] := 0.1;
  Result[5] := 0.25;
  Result[6] := 0.5;
  Result[7] := 1.0;
  Result[8] := 5.0;
end;

class function TObservability.StatusToString(
  AStatus: TWebHealthStatus): string;
begin
  case AStatus of
    whsHealthy:   Result := 'healthy';
    whsDegraded:  Result := 'degraded';
    whsUnhealthy: Result := 'unhealthy';
  else
    Result := 'unknown';
  end;
end;

class function TObservability.HttpMethodToString(
  AMethod: THttpMethod): string;
begin
  case AMethod of
    hmGet:     Result := 'GET';
    hmPost:    Result := 'POST';
    hmPut:     Result := 'PUT';
    hmPatch:   Result := 'PATCH';
    hmDelete:  Result := 'DELETE';
    hmOptions: Result := 'OPTIONS';
    hmHead:    Result := 'HEAD';
  else
    Result := 'UNKNOWN';
  end;
end;

class procedure TObservability.RegisterHealthEndpoint(AServer: TApiServer;
  ARegistry: TWebHealthCheckRegistry);
begin
  AServer.Get('/health',
    procedure(AContext: TApiContext)
    var
      LJson: TJSONObject;
    begin
      LJson := ARegistry.RunAll;
      try
        AContext.Response.SetHeader('Content-Type', TContentType.JSON);
        AContext.Response.SendJSON(LJson);
      except
        LJson.Free;
        raise;
      end;
    end);
end;

class procedure TObservability.RegisterMetricsEndpoint(AServer: TApiServer;
  ACollector: TMetricsCollector);
begin
  AServer.Get('/metrics',
    procedure(AContext: TApiContext)
    var
      LText: string;
    begin
      LText := ACollector.ToPrometheus;
      AContext.Response.SetHeader('Content-Type',
        'text/plain; version=0.0.4; charset=utf-8');
      AContext.Response.Send(LText);
    end);
end;

class function TObservability.CreateRequestMetricsMiddleware(
  ACollector: TMetricsCollector;
  const ABuckets: array of Double): TMiddlewareFunc;
var
  LBuckets: TArray<Double>;
  I: Integer;
begin
  // Copy open array to dynamic array so the closure can capture it
  SetLength(LBuckets, Length(ABuckets));
  for I := 0 to High(ABuckets) do
    LBuckets[I] := ABuckets[I];
  Result :=
    procedure(AContext: TApiContext; ANext: TProc)
    var
      LLabels: TMetricLabels;
      LStart: TDateTime;
      LDuration: Double;
      LStatusClass: string;
    begin
      LStart := Now;
      LLabels := TMetricLabels.Create;
      try
        LLabels.Add('method',
          TObservability.HttpMethodToString(AContext.Request.Method));
        LLabels.Add('path', AContext.Request.Path);
        ACollector.Counter('http_requests_total',
          'Total HTTP requests', LLabels);
        try
          ANext;
        finally
          LDuration := (Now - LStart) * SecsPerDay;
          ACollector.Histogram('http_request_duration_seconds',
            'HTTP request duration in seconds', LLabels, LDuration, LBuckets);
          if AContext.Response.Sent then
          begin
            LStatusClass := IntToStr(AContext.Response.StatusCode div 100)
              + 'xx';
            LLabels.Add('status', LStatusClass);
            ACollector.Counter('http_responses_total',
              'Total HTTP responses by status class', LLabels);
          end;
        end;
      finally
        LLabels.Free;
      end;
    end;
end;

end.
