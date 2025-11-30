unit Analysis.Engine;

{*******************************************************************************
  Data Analyzer Template - Analysis Engine
  
  Provides statistical analysis functions for data processing.
  
  Features demonstrated:
  - Statistical calculations (mean, median, stddev, etc.)
  - Data aggregation
  - Trend analysis
  - Caching for performance
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults;

type
  /// <summary>
  /// Statistical summary of a dataset
  /// </summary>
  TStatsSummary = record
    Count: Integer;
    Sum: Double;
    Mean: Double;
    Median: Double;
    Min: Double;
    Max: Double;
    Range: Double;
    StdDev: Double;
    Variance: Double;
    Q1: Double;        // First quartile (25th percentile)
    Q3: Double;        // Third quartile (75th percentile)
    IQR: Double;       // Interquartile range
    
    function ToString: string;
  end;

  /// <summary>
  /// Time series data point
  /// </summary>
  TTimeSeriesPoint = record
    Timestamp: TDateTime;
    Value: Double;
    Label: string;
  end;

  TTimeSeriesData = TArray<TTimeSeriesPoint>;

  /// <summary>
  /// Trend analysis result
  /// </summary>
  TTrendResult = record
    Slope: Double;
    Intercept: Double;
    RSquared: Double;
    Trend: string;  // 'Up', 'Down', 'Stable'
    
    function Predict(X: Double): Double;
    function ToString: string;
  end;

  /// <summary>
  /// Group aggregation result
  /// </summary>
  TGroupResult = record
    GroupKey: string;
    Count: Integer;
    Sum: Double;
    Average: Double;
    Min: Double;
    Max: Double;
  end;

  TGroupResults = TArray<TGroupResult>;

  /// <summary>
  /// Data analysis engine
  /// </summary>
  TAnalysisEngine = class
  private
    class function QuickSelect(var Arr: TArray<Double>; Left, Right, K: Integer): Double;
  public
    // Basic statistics
    class function CalculateStats(const Values: TArray<Double>): TStatsSummary;
    class function Mean(const Values: TArray<Double>): Double;
    class function Median(const Values: TArray<Double>): Double;
    class function StdDev(const Values: TArray<Double>): Double;
    class function Variance(const Values: TArray<Double>): Double;
    class function Percentile(const Values: TArray<Double>; P: Double): Double;
    
    // Aggregation
    class function Sum(const Values: TArray<Double>): Double;
    class function Min(const Values: TArray<Double>): Double;
    class function Max(const Values: TArray<Double>): Double;
    class function Count(const Values: TArray<Double>): Integer;
    
    // Trend analysis
    class function LinearRegression(const X, Y: TArray<Double>): TTrendResult;
    class function AnalyzeTrend(const TimeSeries: TTimeSeriesData): TTrendResult;
    class function MovingAverage(const Values: TArray<Double>; WindowSize: Integer): TArray<Double>;
    
    // Grouping
    class function GroupBy<T>(const Data: TArray<T>;
      KeySelector: TFunc<T, string>;
      ValueSelector: TFunc<T, Double>): TGroupResults;
    
    // Correlation
    class function Correlation(const X, Y: TArray<Double>): Double;
    class function Covariance(const X, Y: TArray<Double>): Double;
    
    // Data transformation
    class function Normalize(const Values: TArray<Double>): TArray<Double>;
    class function ZScore(const Values: TArray<Double>): TArray<Double>;
  end;

implementation

uses
  UniBase.Logging;

{ TStatsSummary }

function TStatsSummary.ToString: string;
begin
  Result := Format(
    'Count: %d, Mean: %.2f, Median: %.2f, StdDev: %.2f, Min: %.2f, Max: %.2f',
    [Count, Mean, Median, StdDev, Min, Max]);
end;

{ TTrendResult }

function TTrendResult.Predict(X: Double): Double;
begin
  Result := Slope * X + Intercept;
end;

function TTrendResult.ToString: string;
begin
  Result := Format('Trend: %s, Slope: %.4f, R²: %.4f', [Trend, Slope, RSquared]);
end;

{ TAnalysisEngine }

class function TAnalysisEngine.CalculateStats(const Values: TArray<Double>): TStatsSummary;
var
  SortedValues: TArray<Double>;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  if Length(Values) = 0 then
    Exit;
  
  Result.Count := Length(Values);
  Result.Sum := Self.Sum(Values);
  Result.Mean := Result.Sum / Result.Count;
  Result.Min := Self.Min(Values);
  Result.Max := Self.Max(Values);
  Result.Range := Result.Max - Result.Min;
  Result.Variance := Self.Variance(Values);
  Result.StdDev := Sqrt(Result.Variance);
  
  // Calculate median and quartiles
  SortedValues := Copy(Values);
  TArray.Sort<Double>(SortedValues);
  
  Result.Median := Self.Median(Values);
  Result.Q1 := Self.Percentile(Values, 0.25);
  Result.Q3 := Self.Percentile(Values, 0.75);
  Result.IQR := Result.Q3 - Result.Q1;
end;

class function TAnalysisEngine.Mean(const Values: TArray<Double>): Double;
begin
  if Length(Values) = 0 then
    Exit(0);
  Result := Sum(Values) / Length(Values);
end;

class function TAnalysisEngine.Median(const Values: TArray<Double>): Double;
var
  SortedValues: TArray<Double>;
  N: Integer;
begin
  N := Length(Values);
  if N = 0 then
    Exit(0);
  
  SortedValues := Copy(Values);
  TArray.Sort<Double>(SortedValues);
  
  if N mod 2 = 0 then
    Result := (SortedValues[N div 2 - 1] + SortedValues[N div 2]) / 2
  else
    Result := SortedValues[N div 2];
end;

class function TAnalysisEngine.StdDev(const Values: TArray<Double>): Double;
begin
  Result := Sqrt(Variance(Values));
end;

class function TAnalysisEngine.Variance(const Values: TArray<Double>): Double;
var
  M: Double;
  V: Double;
  SumSq: Double;
begin
  if Length(Values) < 2 then
    Exit(0);
  
  M := Mean(Values);
  SumSq := 0;
  
  for V in Values do
    SumSq := SumSq + Sqr(V - M);
  
  Result := SumSq / (Length(Values) - 1);  // Sample variance
end;

class function TAnalysisEngine.Percentile(const Values: TArray<Double>; P: Double): Double;
var
  SortedValues: TArray<Double>;
  N: Integer;
  K: Double;
  F, C: Integer;
begin
  if Length(Values) = 0 then
    Exit(0);
  
  if P < 0 then P := 0;
  if P > 1 then P := 1;
  
  SortedValues := Copy(Values);
  TArray.Sort<Double>(SortedValues);
  
  N := Length(SortedValues);
  K := P * (N - 1);
  F := Floor(K);
  C := Ceil(K);
  
  if F = C then
    Result := SortedValues[F]
  else
    Result := SortedValues[F] * (C - K) + SortedValues[C] * (K - F);
end;

class function TAnalysisEngine.Sum(const Values: TArray<Double>): Double;
var
  V: Double;
begin
  Result := 0;
  for V in Values do
    Result := Result + V;
end;

class function TAnalysisEngine.Min(const Values: TArray<Double>): Double;
var
  V: Double;
begin
  if Length(Values) = 0 then
    Exit(0);
  
  Result := Values[0];
  for V in Values do
    if V < Result then
      Result := V;
end;

class function TAnalysisEngine.Max(const Values: TArray<Double>): Double;
var
  V: Double;
begin
  if Length(Values) = 0 then
    Exit(0);
  
  Result := Values[0];
  for V in Values do
    if V > Result then
      Result := V;
end;

class function TAnalysisEngine.Count(const Values: TArray<Double>): Integer;
begin
  Result := Length(Values);
end;

class function TAnalysisEngine.QuickSelect(var Arr: TArray<Double>; Left, Right, K: Integer): Double;
var
  Pivot, Temp: Double;
  I, J, PivotIndex: Integer;
begin
  if Left = Right then
    Exit(Arr[Left]);
  
  PivotIndex := Left + Random(Right - Left + 1);
  Pivot := Arr[PivotIndex];
  
  // Move pivot to end
  Temp := Arr[PivotIndex];
  Arr[PivotIndex] := Arr[Right];
  Arr[Right] := Temp;
  
  I := Left;
  for J := Left to Right - 1 do
  begin
    if Arr[J] < Pivot then
    begin
      Temp := Arr[I];
      Arr[I] := Arr[J];
      Arr[J] := Temp;
      Inc(I);
    end;
  end;
  
  // Move pivot to final position
  Temp := Arr[I];
  Arr[I] := Arr[Right];
  Arr[Right] := Temp;
  
  if K = I then
    Result := Arr[I]
  else if K < I then
    Result := QuickSelect(Arr, Left, I - 1, K)
  else
    Result := QuickSelect(Arr, I + 1, Right, K);
end;

class function TAnalysisEngine.LinearRegression(const X, Y: TArray<Double>): TTrendResult;
var
  N: Integer;
  SumX, SumY, SumXY, SumX2, SumY2: Double;
  I: Integer;
  MeanX, MeanY: Double;
  SSTotal, SSResidual: Double;
  Predicted: Double;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  N := Length(X);
  if (N < 2) or (N <> Length(Y)) then
    Exit;
  
  // Calculate sums
  SumX := 0;
  SumY := 0;
  SumXY := 0;
  SumX2 := 0;
  SumY2 := 0;
  
  for I := 0 to N - 1 do
  begin
    SumX := SumX + X[I];
    SumY := SumY + Y[I];
    SumXY := SumXY + X[I] * Y[I];
    SumX2 := SumX2 + Sqr(X[I]);
    SumY2 := SumY2 + Sqr(Y[I]);
  end;
  
  // Calculate slope and intercept
  Result.Slope := (N * SumXY - SumX * SumY) / (N * SumX2 - Sqr(SumX));
  Result.Intercept := (SumY - Result.Slope * SumX) / N;
  
  // Calculate R-squared
  MeanY := SumY / N;
  SSTotal := 0;
  SSResidual := 0;
  
  for I := 0 to N - 1 do
  begin
    Predicted := Result.Slope * X[I] + Result.Intercept;
    SSTotal := SSTotal + Sqr(Y[I] - MeanY);
    SSResidual := SSResidual + Sqr(Y[I] - Predicted);
  end;
  
  if SSTotal > 0 then
    Result.RSquared := 1 - (SSResidual / SSTotal)
  else
    Result.RSquared := 0;
  
  // Determine trend direction
  if Abs(Result.Slope) < 0.001 then
    Result.Trend := 'Stable'
  else if Result.Slope > 0 then
    Result.Trend := 'Up'
  else
    Result.Trend := 'Down';
end;

class function TAnalysisEngine.AnalyzeTrend(const TimeSeries: TTimeSeriesData): TTrendResult;
var
  X, Y: TArray<Double>;
  I: Integer;
  BaseTime: TDateTime;
begin
  SetLength(X, Length(TimeSeries));
  SetLength(Y, Length(TimeSeries));
  
  if Length(TimeSeries) > 0 then
    BaseTime := TimeSeries[0].Timestamp
  else
    BaseTime := 0;
  
  for I := 0 to High(TimeSeries) do
  begin
    X[I] := TimeSeries[I].Timestamp - BaseTime;  // Days from start
    Y[I] := TimeSeries[I].Value;
  end;
  
  Result := LinearRegression(X, Y);
end;

class function TAnalysisEngine.MovingAverage(const Values: TArray<Double>; 
  WindowSize: Integer): TArray<Double>;
var
  I, J, StartIdx: Integer;
  WindowSum: Double;
  ValidCount: Integer;
begin
  if (Length(Values) = 0) or (WindowSize <= 0) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  SetLength(Result, Length(Values));
  
  for I := 0 to High(Values) do
  begin
    WindowSum := 0;
    ValidCount := 0;
    StartIdx := System.Math.Max(0, I - WindowSize + 1);
    
    for J := StartIdx to I do
    begin
      WindowSum := WindowSum + Values[J];
      Inc(ValidCount);
    end;
    
    Result[I] := WindowSum / ValidCount;
  end;
end;

class function TAnalysisEngine.GroupBy<T>(const Data: TArray<T>;
  KeySelector: TFunc<T, string>;
  ValueSelector: TFunc<T, Double>): TGroupResults;
var
  Groups: TDictionary<string, TList<Double>>;
  Item: T;
  Key: string;
  ValueList: TList<Double>;
  I: Integer;
  Values: TArray<Double>;
begin
  Groups := TDictionary<string, TList<Double>>.Create;
  try
    // Group values by key
    for Item in Data do
    begin
      Key := KeySelector(Item);
      if not Groups.TryGetValue(Key, ValueList) then
      begin
        ValueList := TList<Double>.Create;
        Groups.Add(Key, ValueList);
      end;
      ValueList.Add(ValueSelector(Item));
    end;
    
    // Build results
    SetLength(Result, Groups.Count);
    I := 0;
    for Key in Groups.Keys do
    begin
      ValueList := Groups[Key];
      Values := ValueList.ToArray;
      
      Result[I].GroupKey := Key;
      Result[I].Count := Length(Values);
      Result[I].Sum := Self.Sum(Values);
      Result[I].Average := Self.Mean(Values);
      Result[I].Min := Self.Min(Values);
      Result[I].Max := Self.Max(Values);
      Inc(I);
    end;
  finally
    for ValueList in Groups.Values do
      ValueList.Free;
    Groups.Free;
  end;
end;

class function TAnalysisEngine.Correlation(const X, Y: TArray<Double>): Double;
var
  N: Integer;
  MeanX, MeanY: Double;
  SumXY, SumX2, SumY2: Double;
  I: Integer;
begin
  N := Length(X);
  if (N < 2) or (N <> Length(Y)) then
    Exit(0);
  
  MeanX := Mean(X);
  MeanY := Mean(Y);
  
  SumXY := 0;
  SumX2 := 0;
  SumY2 := 0;
  
  for I := 0 to N - 1 do
  begin
    SumXY := SumXY + (X[I] - MeanX) * (Y[I] - MeanY);
    SumX2 := SumX2 + Sqr(X[I] - MeanX);
    SumY2 := SumY2 + Sqr(Y[I] - MeanY);
  end;
  
  if (SumX2 = 0) or (SumY2 = 0) then
    Result := 0
  else
    Result := SumXY / Sqrt(SumX2 * SumY2);
end;

class function TAnalysisEngine.Covariance(const X, Y: TArray<Double>): Double;
var
  N: Integer;
  MeanX, MeanY: Double;
  SumXY: Double;
  I: Integer;
begin
  N := Length(X);
  if (N < 2) or (N <> Length(Y)) then
    Exit(0);
  
  MeanX := Mean(X);
  MeanY := Mean(Y);
  
  SumXY := 0;
  for I := 0 to N - 1 do
    SumXY := SumXY + (X[I] - MeanX) * (Y[I] - MeanY);
  
  Result := SumXY / (N - 1);
end;

class function TAnalysisEngine.Normalize(const Values: TArray<Double>): TArray<Double>;
var
  MinVal, MaxVal, Range: Double;
  V: Double;
  I: Integer;
begin
  if Length(Values) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  MinVal := Min(Values);
  MaxVal := Max(Values);
  Range := MaxVal - MinVal;
  
  SetLength(Result, Length(Values));
  
  if Range = 0 then
  begin
    for I := 0 to High(Values) do
      Result[I] := 0.5;  // All values are the same
  end
  else
  begin
    for I := 0 to High(Values) do
      Result[I] := (Values[I] - MinVal) / Range;
  end;
end;

class function TAnalysisEngine.ZScore(const Values: TArray<Double>): TArray<Double>;
var
  M, S: Double;
  I: Integer;
begin
  if Length(Values) < 2 then
  begin
    SetLength(Result, Length(Values));
    for I := 0 to High(Values) do
      Result[I] := 0;
    Exit;
  end;
  
  M := Mean(Values);
  S := StdDev(Values);
  
  SetLength(Result, Length(Values));
  
  if S = 0 then
  begin
    for I := 0 to High(Values) do
      Result[I] := 0;
  end
  else
  begin
    for I := 0 to High(Values) do
      Result[I] := (Values[I] - M) / S;
  end;
end;

end.
