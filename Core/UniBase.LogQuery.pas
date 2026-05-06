unit UniBase.LogQuery;

{*******************************************************************************
  UniBase Log Query and Analysis
  Query builder and analyzer for centralized log analysis:
  - Fluent query API for filtering logs
  - Statistical analysis (counts, rates, distributions)
  - Time series data generation
  - Pattern detection
  - Top errors analysis
  
  Author: UniBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs,
  System.JSON, System.DateUtils, System.RegularExpressions, System.Math,
  System.Rtti, UniBase.Types, UniBase.LogAggregator;

type
  ELogQueryException = class(Exception);

  /// <summary>Sort direction</summary>
  TSortDirection = (sdAscending, sdDescending);

  /// <summary>Aggregation type</summary>
  TAggregationType = (atCount, atSum, atAvg, atMin, atMax);

  /// <summary>Time bucket size for time series</summary>
  TTimeBucket = (tbMinute, tbHour, tbDay, tbWeek, tbMonth);

  /// <summary>Log query result item</summary>
  TLogQueryItem = record
    Timestamp: TDateTime;
    Level: TLogLevel;
    Message: string;
    Source: string;
    ThreadId: TThreadID;
    StackTrace: string;
    Extra: string;
    AppName: string;
    Hostname: string;
    Environment: string;
    
    function ToJSON: TJSONObject;
    class function FromAggregatedLog(const ALog: TAggregatedLog): TLogQueryItem; static;
  end;

  /// <summary>Query result</summary>
  TLogQueryResult = class
  private
    FItems: TList<TLogQueryItem>;
    FTotalCount: Int64;
    FQueryTimeMs: Integer;
    FHasMore: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddItem(const AItem: TLogQueryItem);
    procedure Clear;
    
    function ToJSON: TJSONObject;
    function ToCSV(AIncludeHeader: Boolean = True): string;
    
    property Items: TList<TLogQueryItem> read FItems;
    property TotalCount: Int64 read FTotalCount write FTotalCount;
    property QueryTimeMs: Integer read FQueryTimeMs write FQueryTimeMs;
    property HasMore: Boolean read FHasMore write FHasMore;
  end;

  /// <summary>Count by category result</summary>
  TCountResult = record
    Category: string;
    Count: Int64;
    Percentage: Double;
  end;

  /// <summary>Time series data point</summary>
  TTimeSeriesPoint = record
    Timestamp: TDateTime;
    Value: Double;
    Label_: string;
  end;

  /// <summary>Time series result</summary>
  TLogTimeSeries = class
  private
    FName: string;
    FPoints: TList<TTimeSeriesPoint>;
    FBucket: TTimeBucket;
  public
    constructor Create(const AName: string; ABucket: TTimeBucket);
    destructor Destroy; override;
    
    procedure AddPoint(ATimestamp: TDateTime; AValue: Double; const ALabel: string = '');
    procedure Clear;
    
    function ToJSON: TJSONObject;
    function ToCSV: string;
    
    property Name: string read FName write FName;
    property Points: TList<TTimeSeriesPoint> read FPoints;
    property Bucket: TTimeBucket read FBucket;
  end;

  /// <summary>Statistics result</summary>
  TLogStats = record
    TotalCount: Int64;
    DebugCount: Int64;
    InfoCount: Int64;
    WarnCount: Int64;
    ErrorCount: Int64;
    FatalCount: Int64;
    ErrorRate: Double;          // Errors / Total
    FatalRate: Double;          // Fatal / Total
    UniqueSourceCount: Integer;
    UniqueHostCount: Integer;
    TimeRangeStart: TDateTime;
    TimeRangeEnd: TDateTime;
    
    function ToJSON: TJSONObject;
    function ToString: string;
  end;

  /// <summary>Pattern match result</summary>
  TPatternMatch = record
    Pattern: string;
    MatchCount: Int64;
    FirstOccurrence: TDateTime;
    LastOccurrence: TDateTime;
    SampleMessages: TArray<string>;
  end;

  /// <summary>Top error result</summary>
  TTopError = record
    Message: string;
    Count: Int64;
    FirstSeen: TDateTime;
    LastSeen: TDateTime;
    Sources: TArray<string>;
  end;

  /// <summary>Log query builder - fluent API</summary>
  TLogQueryBuilder = class
  private
    FFilter: TLogFilter;
    FSortField: string;
    FSortDirection: TSortDirection;
    FGroupByField: string;
    FAggregationType: TAggregationType;
    FDistinctField: string;
    FDataSource: TList<TAggregatedLog>;
    FOwnsDataSource: Boolean;
    
    function MatchesFilter(const ALog: TAggregatedLog): Boolean;
    function CompareByField(const A, B: TAggregatedLog): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Set data source (in-memory logs)</summary>
    function From(ADataSource: TList<TAggregatedLog>): TLogQueryBuilder; overload;
    function From(const ALogs: TArray<TAggregatedLog>): TLogQueryBuilder; overload;
    
    /// <summary>Filter by log level</summary>
    function WhereLevel(ALevel: TLogLevel): TLogQueryBuilder; overload;
    function WhereLevels(const ALevels: TArray<TLogLevel>): TLogQueryBuilder; overload;
    function WhereLevelAtLeast(ALevel: TLogLevel): TLogQueryBuilder;
    
    /// <summary>Filter by source</summary>
    function WhereSource(const ASource: string): TLogQueryBuilder;
    function WhereSourceLike(const APattern: string): TLogQueryBuilder;
    
    /// <summary>Filter by message content</summary>
    function WhereMessageContains(const AKeyword: string): TLogQueryBuilder;
    function WhereMessageMatches(const APattern: string): TLogQueryBuilder;
    function WhereMessageNotContains(const AKeyword: string): TLogQueryBuilder;
    
    /// <summary>Filter by time range</summary>
    function WhereBetween(AStart, AEnd: TDateTime): TLogQueryBuilder;
    function WhereSince(AStart: TDateTime): TLogQueryBuilder;
    function WhereUntil(AEnd: TDateTime): TLogQueryBuilder;
    function WhereLastMinutes(AMinutes: Integer): TLogQueryBuilder;
    function WhereLastHours(AHours: Integer): TLogQueryBuilder;
    function WhereLastDays(ADays: Integer): TLogQueryBuilder;
    function WhereToday: TLogQueryBuilder;
    
    /// <summary>Filter by app/environment</summary>
    function WhereApp(const AAppName: string): TLogQueryBuilder;
    function WhereHost(const AHostname: string): TLogQueryBuilder;
    function WhereEnvironment(const AEnvironment: string): TLogQueryBuilder;
    
    /// <summary>Sorting</summary>
    function OrderBy(const AField: string; ADirection: TSortDirection = sdDescending): TLogQueryBuilder;
    function OrderByTimestamp(ADirection: TSortDirection = sdDescending): TLogQueryBuilder;
    function OrderByLevel(ADirection: TSortDirection = sdDescending): TLogQueryBuilder;
    
    /// <summary>Pagination</summary>
    function Skip(AOffset: Integer): TLogQueryBuilder;
    function Take(ALimit: Integer): TLogQueryBuilder;
    
    /// <summary>Grouping</summary>
    function GroupBy(const AField: string): TLogQueryBuilder;
    function Distinct(const AField: string): TLogQueryBuilder;
    
    /// <summary>Execute query and return results</summary>
    function Execute: TLogQueryResult;
    function ExecuteCount: Int64;
    function ExecuteFirst: TLogQueryItem;
    function ExecuteExists: Boolean;
    
    /// <summary>Get filter for external use</summary>
    function GetFilter: TLogFilter;
  end;

  /// <summary>Log analyzer for statistics and insights</summary>
  TLogAnalyzer = class
  private
    FDataSource: TList<TAggregatedLog>;
    FOwnsDataSource: Boolean;
    
    function NormalizeBucket(ATimestamp: TDateTime; ABucket: TTimeBucket): TDateTime;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Set data source</summary>
    procedure SetDataSource(ADataSource: TList<TAggregatedLog>; AOwns: Boolean = False);
    procedure SetDataSourceArray(const ALogs: TArray<TAggregatedLog>);
    
    /// <summary>Basic statistics</summary>
    function GetStats: TLogStats; overload;
    function GetStats(const AFilter: TLogFilter): TLogStats; overload;
    
    /// <summary>Count by category</summary>
    function CountByLevel: TArray<TCountResult>;
    function CountBySource(ATopN: Integer = 10): TArray<TCountResult>;
    function CountByHost(ATopN: Integer = 10): TArray<TCountResult>;
    function CountByApp(ATopN: Integer = 10): TArray<TCountResult>;
    function CountByEnvironment: TArray<TCountResult>;
    
    /// <summary>Time series</summary>
    function CountByTime(ABucket: TTimeBucket): TLogTimeSeries;
    function CountByTimeAndLevel(ABucket: TTimeBucket): TArray<TLogTimeSeries>;
    function ErrorRateByTime(ABucket: TTimeBucket): TLogTimeSeries;
    
    /// <summary>Error analysis</summary>
    function TopErrors(ATopN: Integer = 10): TArray<TTopError>;
    function TopExceptions(ATopN: Integer = 10): TArray<TTopError>;
    function ErrorRate: Double;
    function ErrorRateBySource: TArray<TCountResult>;
    
    /// <summary>Pattern detection</summary>
    function FindPatterns(const APatterns: TArray<string>): TArray<TPatternMatch>;
    function FindAnomalies(AThreshold: Double = 2.0): TArray<TLogQueryItem>;
    
    /// <summary>Trend analysis</summary>
    function IsErrorRateIncreasing(AWindowMinutes: Integer = 60): Boolean;
    function GetTrend(ABucket: TTimeBucket): Double;  // positive = increasing
  end;

/// <summary>Create a new query builder</summary>
function LogQuery: TLogQueryBuilder;

implementation

uses
  System.StrUtils, System.Generics.Defaults;

function LogQuery: TLogQueryBuilder;
begin
  Result := TLogQueryBuilder.Create;
end;

{ TLogQueryItem }

function TLogQueryItem.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('timestamp', DateToISO8601(Timestamp, False));
  Result.AddPair('level', LogLevelToStr(Level));
  Result.AddPair('message', Message);
  
  if Source <> '' then
    Result.AddPair('source', Source);
  if ThreadId <> 0 then
    Result.AddPair('threadId', TJSONNumber.Create(ThreadId));
  if StackTrace <> '' then
    Result.AddPair('stackTrace', StackTrace);
  if AppName <> '' then
    Result.AddPair('appName', AppName);
  if Hostname <> '' then
    Result.AddPair('hostname', Hostname);
  if Environment <> '' then
    Result.AddPair('environment', Environment);
end;

class function TLogQueryItem.FromAggregatedLog(const ALog: TAggregatedLog): TLogQueryItem;
begin
  Result.Timestamp := ALog.Timestamp;
  Result.Level := ALog.Level;
  Result.Message := ALog.Message;
  Result.Source := ALog.Source;
  Result.ThreadId := ALog.ThreadId;
  Result.StackTrace := ALog.StackTrace;
  Result.Extra := ALog.Extra;
  Result.AppName := ALog.AppName;
  Result.Hostname := ALog.Hostname;
  Result.Environment := ALog.Environment;
end;

{ TLogQueryResult }

constructor TLogQueryResult.Create;
begin
  inherited Create;
  FItems := TList<TLogQueryItem>.Create;
  FTotalCount := 0;
  FQueryTimeMs := 0;
  FHasMore := False;
end;

destructor TLogQueryResult.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TLogQueryResult.AddItem(const AItem: TLogQueryItem);
begin
  FItems.Add(AItem);
end;

procedure TLogQueryResult.Clear;
begin
  FItems.Clear;
  FTotalCount := 0;
end;

function TLogQueryResult.ToJSON: TJSONObject;
var
  ItemsArr: TJSONArray;
  Item: TLogQueryItem;
begin
  Result := TJSONObject.Create;
  Result.AddPair('totalCount', TJSONNumber.Create(FTotalCount));
  Result.AddPair('queryTimeMs', TJSONNumber.Create(FQueryTimeMs));
  Result.AddPair('hasMore', TJSONBool.Create(FHasMore));
  Result.AddPair('count', TJSONNumber.Create(FItems.Count));
  
  ItemsArr := TJSONArray.Create;
  for Item in FItems do
    ItemsArr.AddElement(Item.ToJSON);
  Result.AddPair('items', ItemsArr);
end;

function TLogQueryResult.ToCSV(AIncludeHeader: Boolean): string;
var
  Builder: TStringBuilder;
  Item: TLogQueryItem;
begin
  Builder := TStringBuilder.Create;
  try
    if AIncludeHeader then
      Builder.AppendLine('timestamp,level,source,message,appName,hostname,environment');
    
    for Item in FItems do
    begin
      Builder.AppendFormat('"%s","%s","%s","%s","%s","%s","%s"', [
        DateToISO8601(Item.Timestamp, False),
        LogLevelToStr(Item.Level),
        Item.Source.Replace('"', '""'),
        Item.Message.Replace('"', '""'),
        Item.AppName,
        Item.Hostname,
        Item.Environment
      ]);
      Builder.AppendLine;
    end;
    
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

{ TLogTimeSeries }

constructor TLogTimeSeries.Create(const AName: string; ABucket: TTimeBucket);
begin
  inherited Create;
  FName := AName;
  FBucket := ABucket;
  FPoints := TList<TTimeSeriesPoint>.Create;
end;

destructor TLogTimeSeries.Destroy;
begin
  FreeAndNil(FPoints);
  inherited;
end;

procedure TLogTimeSeries.AddPoint(ATimestamp: TDateTime; AValue: Double; const ALabel: string);
var
  Point: TTimeSeriesPoint;
begin
  Point.Timestamp := ATimestamp;
  Point.Value := AValue;
  Point.Label_ := ALabel;
  FPoints.Add(Point);
end;

procedure TLogTimeSeries.Clear;
begin
  FPoints.Clear;
end;

function TLogTimeSeries.ToJSON: TJSONObject;
var
  PointsArr: TJSONArray;
  PointObj: TJSONObject;
  Point: TTimeSeriesPoint;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', FName);
  Result.AddPair('bucket', TRttiEnumerationType.GetName(FBucket));
  
  PointsArr := TJSONArray.Create;
  for Point in FPoints do
  begin
    PointObj := TJSONObject.Create;
    PointObj.AddPair('timestamp', DateToISO8601(Point.Timestamp, False));
    PointObj.AddPair('value', TJSONNumber.Create(Point.Value));
    if Point.Label_ <> '' then
      PointObj.AddPair('label', Point.Label_);
    PointsArr.AddElement(PointObj);
  end;
  Result.AddPair('points', PointsArr);
end;

function TLogTimeSeries.ToCSV: string;
var
  Builder: TStringBuilder;
  Point: TTimeSeriesPoint;
begin
  Builder := TStringBuilder.Create;
  try
    Builder.AppendLine('timestamp,value,label');
    for Point in FPoints do
    begin
      Builder.AppendFormat('"%s",%g,"%s"', [
        DateToISO8601(Point.Timestamp, False),
        Point.Value,
        Point.Label_
      ]);
      Builder.AppendLine;
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

{ TLogStats }

function TLogStats.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('totalCount', TJSONNumber.Create(TotalCount));
  Result.AddPair('debugCount', TJSONNumber.Create(DebugCount));
  Result.AddPair('infoCount', TJSONNumber.Create(InfoCount));
  Result.AddPair('warnCount', TJSONNumber.Create(WarnCount));
  Result.AddPair('errorCount', TJSONNumber.Create(ErrorCount));
  Result.AddPair('fatalCount', TJSONNumber.Create(FatalCount));
  Result.AddPair('errorRate', TJSONNumber.Create(ErrorRate));
  Result.AddPair('fatalRate', TJSONNumber.Create(FatalRate));
  Result.AddPair('uniqueSourceCount', TJSONNumber.Create(UniqueSourceCount));
  Result.AddPair('uniqueHostCount', TJSONNumber.Create(UniqueHostCount));
  
  if TimeRangeStart > 0 then
    Result.AddPair('timeRangeStart', DateToISO8601(TimeRangeStart, False));
  if TimeRangeEnd > 0 then
    Result.AddPair('timeRangeEnd', DateToISO8601(TimeRangeEnd, False));
end;

function TLogStats.ToString: string;
begin
  Result := Format(
    'Total: %d (D:%d I:%d W:%d E:%d F:%d) ErrorRate: %.2f%%',
    [TotalCount, DebugCount, InfoCount, WarnCount, ErrorCount, FatalCount, ErrorRate * 100]
  );
end;

{ TLogQueryBuilder }

constructor TLogQueryBuilder.Create;
begin
  inherited Create;
  FFilter := TLogFilter.All;
  FSortField := 'timestamp';
  FSortDirection := sdDescending;
  FGroupByField := '';
  FAggregationType := atCount;
  FDistinctField := '';
  FDataSource := nil;
  FOwnsDataSource := False;
end;

destructor TLogQueryBuilder.Destroy;
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
  inherited;
end;

function TLogQueryBuilder.From(ADataSource: TList<TAggregatedLog>): TLogQueryBuilder;
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
  FDataSource := ADataSource;
  FOwnsDataSource := False;
  Result := Self;
end;

function TLogQueryBuilder.From(const ALogs: TArray<TAggregatedLog>): TLogQueryBuilder;
var
  Log: TAggregatedLog;
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
    
  FDataSource := TList<TAggregatedLog>.Create;
  FOwnsDataSource := True;
  
  for Log in ALogs do
    FDataSource.Add(Log);
    
  Result := Self;
end;

function TLogQueryBuilder.MatchesFilter(const ALog: TAggregatedLog): Boolean;
var
  Level: TLogLevel;
  Source, Keyword: string;
  LevelMatch, SourceMatch, TimeMatch, KeywordMatch: Boolean;
begin
  Result := True;
  
  // Level filter
  if Length(FFilter.Levels) > 0 then
  begin
    LevelMatch := False;
    for Level in FFilter.Levels do
      if ALog.Level = Level then
      begin
        LevelMatch := True;
        Break;
      end;
    if not LevelMatch then
      Exit(False);
  end;
  
  // Source filter
  if Length(FFilter.Sources) > 0 then
  begin
    SourceMatch := False;
    for Source in FFilter.Sources do
      if ContainsText(ALog.Source, Source) then
      begin
        SourceMatch := True;
        Break;
      end;
    if not SourceMatch then
      Exit(False);
  end;
  
  // Time range filter
  if FFilter.StartTime > 0 then
    if ALog.Timestamp < FFilter.StartTime then
      Exit(False);
  if FFilter.EndTime > 0 then
    if ALog.Timestamp > FFilter.EndTime then
      Exit(False);
  
  // Keyword filter
  if Length(FFilter.Keywords) > 0 then
  begin
    KeywordMatch := False;
    for Keyword in FFilter.Keywords do
      if ContainsText(ALog.Message, Keyword) then
      begin
        KeywordMatch := True;
        Break;
      end;
    if not KeywordMatch then
      Exit(False);
  end;
  
  // Exclude keywords filter
  for Keyword in FFilter.ExcludeKeywords do
    if ContainsText(ALog.Message, Keyword) then
      Exit(False);
end;

function TLogQueryBuilder.CompareByField(const A, B: TAggregatedLog): Integer;
var
  Multiplier: Integer;
begin
  if FSortDirection = sdDescending then
    Multiplier := -1
  else
    Multiplier := 1;
    
  if SameText(FSortField, 'timestamp') then
    Result := Multiplier * CompareDateTime(A.Timestamp, B.Timestamp)
  else if SameText(FSortField, 'level') then
    Result := Multiplier * (Ord(A.Level) - Ord(B.Level))
  else if SameText(FSortField, 'source') then
    Result := Multiplier * CompareText(A.Source, B.Source)
  else if SameText(FSortField, 'message') then
    Result := Multiplier * CompareText(A.Message, B.Message)
  else
    Result := Multiplier * CompareDateTime(A.Timestamp, B.Timestamp);
end;

function TLogQueryBuilder.WhereLevel(ALevel: TLogLevel): TLogQueryBuilder;
begin
  FFilter := FFilter.WithLevel(ALevel);
  Result := Self;
end;

function TLogQueryBuilder.WhereLevels(const ALevels: TArray<TLogLevel>): TLogQueryBuilder;
begin
  FFilter := FFilter.WithLevels(ALevels);
  Result := Self;
end;

function TLogQueryBuilder.WhereLevelAtLeast(ALevel: TLogLevel): TLogQueryBuilder;
var
  Levels: TArray<TLogLevel>;
  L: TLogLevel;
begin
  SetLength(Levels, 0);
  for L := ALevel to High(TLogLevel) do
  begin
    SetLength(Levels, Length(Levels) + 1);
    Levels[High(Levels)] := L;
  end;
  FFilter := FFilter.WithLevels(Levels);
  Result := Self;
end;

function TLogQueryBuilder.WhereSource(const ASource: string): TLogQueryBuilder;
begin
  FFilter := FFilter.WithSource(ASource);
  Result := Self;
end;

function TLogQueryBuilder.WhereSourceLike(const APattern: string): TLogQueryBuilder;
begin
  // Store as source filter, matching will use ContainsText
  FFilter := FFilter.WithSource(APattern);
  Result := Self;
end;

function TLogQueryBuilder.WhereMessageContains(const AKeyword: string): TLogQueryBuilder;
begin
  FFilter := FFilter.WithKeyword(AKeyword);
  Result := Self;
end;

function TLogQueryBuilder.WhereMessageMatches(const APattern: string): TLogQueryBuilder;
begin
  // For regex, store as keyword - matching will need regex handling
  FFilter := FFilter.WithKeyword(APattern);
  Result := Self;
end;

function TLogQueryBuilder.WhereMessageNotContains(const AKeyword: string): TLogQueryBuilder;
begin
  SetLength(FFilter.ExcludeKeywords, Length(FFilter.ExcludeKeywords) + 1);
  FFilter.ExcludeKeywords[High(FFilter.ExcludeKeywords)] := AKeyword;
  Result := Self;
end;

function TLogQueryBuilder.WhereBetween(AStart, AEnd: TDateTime): TLogQueryBuilder;
begin
  FFilter := FFilter.WithTimeRange(AStart, AEnd);
  Result := Self;
end;

function TLogQueryBuilder.WhereSince(AStart: TDateTime): TLogQueryBuilder;
begin
  FFilter.StartTime := AStart;
  Result := Self;
end;

function TLogQueryBuilder.WhereUntil(AEnd: TDateTime): TLogQueryBuilder;
begin
  FFilter.EndTime := AEnd;
  Result := Self;
end;

function TLogQueryBuilder.WhereLastMinutes(AMinutes: Integer): TLogQueryBuilder;
begin
  FFilter.StartTime := IncMinute(Now, -AMinutes);
  FFilter.EndTime := Now;
  Result := Self;
end;

function TLogQueryBuilder.WhereLastHours(AHours: Integer): TLogQueryBuilder;
begin
  FFilter.StartTime := IncHour(Now, -AHours);
  FFilter.EndTime := Now;
  Result := Self;
end;

function TLogQueryBuilder.WhereLastDays(ADays: Integer): TLogQueryBuilder;
begin
  FFilter.StartTime := IncDay(Now, -ADays);
  FFilter.EndTime := Now;
  Result := Self;
end;

function TLogQueryBuilder.WhereToday: TLogQueryBuilder;
begin
  FFilter.StartTime := DateOf(Now);
  FFilter.EndTime := Now;
  Result := Self;
end;

function TLogQueryBuilder.WhereApp(const AAppName: string): TLogQueryBuilder;
begin
  // Store in keywords for now - would need dedicated field
  FFilter := FFilter.WithKeyword(AAppName);
  Result := Self;
end;

function TLogQueryBuilder.WhereHost(const AHostname: string): TLogQueryBuilder;
begin
  FFilter := FFilter.WithKeyword(AHostname);
  Result := Self;
end;

function TLogQueryBuilder.WhereEnvironment(const AEnvironment: string): TLogQueryBuilder;
begin
  FFilter := FFilter.WithKeyword(AEnvironment);
  Result := Self;
end;

function TLogQueryBuilder.OrderBy(const AField: string; ADirection: TSortDirection): TLogQueryBuilder;
begin
  FSortField := AField;
  FSortDirection := ADirection;
  Result := Self;
end;

function TLogQueryBuilder.OrderByTimestamp(ADirection: TSortDirection): TLogQueryBuilder;
begin
  Result := OrderBy('timestamp', ADirection);
end;

function TLogQueryBuilder.OrderByLevel(ADirection: TSortDirection): TLogQueryBuilder;
begin
  Result := OrderBy('level', ADirection);
end;

function TLogQueryBuilder.Skip(AOffset: Integer): TLogQueryBuilder;
begin
  FFilter := FFilter.WithOffset(AOffset);
  Result := Self;
end;

function TLogQueryBuilder.Take(ALimit: Integer): TLogQueryBuilder;
begin
  FFilter := FFilter.WithLimit(ALimit);
  Result := Self;
end;

function TLogQueryBuilder.GroupBy(const AField: string): TLogQueryBuilder;
begin
  FGroupByField := AField;
  Result := Self;
end;

function TLogQueryBuilder.Distinct(const AField: string): TLogQueryBuilder;
begin
  FDistinctField := AField;
  Result := Self;
end;

function TLogQueryBuilder.Execute: TLogQueryResult;
var
  FilteredLogs: TList<TAggregatedLog>;
  Log: TAggregatedLog;
  I, StartIdx, EndIdx: Integer;
  StartTime: TDateTime;
begin
  Result := TLogQueryResult.Create;
  StartTime := Now;
  
  if FDataSource = nil then
    Exit;
  
  FilteredLogs := TList<TAggregatedLog>.Create;
  try
    // Filter
    for Log in FDataSource do
      if MatchesFilter(Log) then
        FilteredLogs.Add(Log);
    
    Result.TotalCount := FilteredLogs.Count;
    
    // Sort
    FilteredLogs.Sort(TComparer<TAggregatedLog>.Construct(
      function(const A, B: TAggregatedLog): Integer
      begin
        Result := CompareByField(A, B);
      end
    ));
    
    // Pagination
    StartIdx := FFilter.Offset;
    if StartIdx >= FilteredLogs.Count then
      StartIdx := FilteredLogs.Count;
      
    EndIdx := StartIdx + FFilter.Limit;
    if EndIdx > FilteredLogs.Count then
      EndIdx := FilteredLogs.Count;
    
    Result.HasMore := EndIdx < FilteredLogs.Count;
    
    // Build result
    for I := StartIdx to EndIdx - 1 do
      Result.AddItem(TLogQueryItem.FromAggregatedLog(FilteredLogs[I]));
  finally
    FilteredLogs.Free;
  end;
  
  Result.QueryTimeMs := MilliSecondsBetween(Now, StartTime);
end;

function TLogQueryBuilder.ExecuteCount: Int64;
var
  Log: TAggregatedLog;
begin
  Result := 0;
  if FDataSource = nil then Exit;
  
  for Log in FDataSource do
    if MatchesFilter(Log) then
      Inc(Result);
end;

function TLogQueryBuilder.ExecuteFirst: TLogQueryItem;
var
  QueryResult: TLogQueryResult;
begin
  FFilter.Limit := 1;
  QueryResult := Execute;
  try
    if QueryResult.Items.Count > 0 then
      Result := QueryResult.Items[0]
    else
      FillChar(Result, SizeOf(Result), 0);
  finally
    QueryResult.Free;
  end;
end;

function TLogQueryBuilder.ExecuteExists: Boolean;
begin
  Result := ExecuteCount > 0;
end;

function TLogQueryBuilder.GetFilter: TLogFilter;
begin
  Result := FFilter;
end;

{ TLogAnalyzer }

constructor TLogAnalyzer.Create;
begin
  inherited Create;
  FDataSource := nil;
  FOwnsDataSource := False;
end;

destructor TLogAnalyzer.Destroy;
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
  inherited;
end;

procedure TLogAnalyzer.SetDataSource(ADataSource: TList<TAggregatedLog>; AOwns: Boolean);
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
  FDataSource := ADataSource;
  FOwnsDataSource := AOwns;
end;

procedure TLogAnalyzer.SetDataSourceArray(const ALogs: TArray<TAggregatedLog>);
var
  Log: TAggregatedLog;
begin
  if FOwnsDataSource and Assigned(FDataSource) then
    FreeAndNil(FDataSource);
    
  FDataSource := TList<TAggregatedLog>.Create;
  FOwnsDataSource := True;
  
  for Log in ALogs do
    FDataSource.Add(Log);
end;

function TLogAnalyzer.NormalizeBucket(ATimestamp: TDateTime; ABucket: TTimeBucket): TDateTime;
var
  Y, M, D, H, Mi, S, Ms: Word;
begin
  DecodeDateTime(ATimestamp, Y, M, D, H, Mi, S, Ms);
  
  case ABucket of
    tbMinute:
      Result := EncodeDateTime(Y, M, D, H, Mi, 0, 0);
    tbHour:
      Result := EncodeDateTime(Y, M, D, H, 0, 0, 0);
    tbDay:
      Result := EncodeDate(Y, M, D);
    tbWeek:
      Result := StartOfTheWeek(ATimestamp);
    tbMonth:
      Result := EncodeDate(Y, M, 1);
  else
    Result := ATimestamp;
  end;
end;

function TLogAnalyzer.GetStats: TLogStats;
begin
  Result := GetStats(TLogFilter.All);
end;

function TLogAnalyzer.GetStats(const AFilter: TLogFilter): TLogStats;
var
  Log: TAggregatedLog;
  Sources, Hosts: TDictionary<string, Boolean>;
  MinTime, MaxTime: TDateTime;
begin
  FillChar(Result, SizeOf(Result), 0);
  
  if FDataSource = nil then Exit;
  if FDataSource.Count = 0 then Exit;
  
  Sources := TDictionary<string, Boolean>.Create;
  Hosts := TDictionary<string, Boolean>.Create;
  try
    MinTime := MaxDateTime;
    MaxTime := MinDateTime;
    
    for Log in FDataSource do
    begin
      Inc(Result.TotalCount);
      
      case Log.Level of
        llDebug: Inc(Result.DebugCount);
        llInfo: Inc(Result.InfoCount);
        llWarn: Inc(Result.WarnCount);
        llError: Inc(Result.ErrorCount);
        llFatal: Inc(Result.FatalCount);
      end;
      
      if Log.Source <> '' then
        Sources.AddOrSetValue(Log.Source, True);
      if Log.Hostname <> '' then
        Hosts.AddOrSetValue(Log.Hostname, True);
        
      if Log.Timestamp < MinTime then
        MinTime := Log.Timestamp;
      if Log.Timestamp > MaxTime then
        MaxTime := Log.Timestamp;
    end;
    
    Result.UniqueSourceCount := Sources.Count;
    Result.UniqueHostCount := Hosts.Count;
    Result.TimeRangeStart := MinTime;
    Result.TimeRangeEnd := MaxTime;
    
    if Result.TotalCount > 0 then
    begin
      Result.ErrorRate := (Result.ErrorCount + Result.FatalCount) / Result.TotalCount;
      Result.FatalRate := Result.FatalCount / Result.TotalCount;
    end;
  finally
    Hosts.Free;
    Sources.Free;
  end;
end;

function TLogAnalyzer.CountByLevel: TArray<TCountResult>;
var
  Stats: TLogStats;
  Results: TArray<TCountResult>;
begin
  Stats := GetStats;
  SetLength(Results, 5);
  
  Results[0].Category := 'DEBUG';
  Results[0].Count := Stats.DebugCount;
  
  Results[1].Category := 'INFO';
  Results[1].Count := Stats.InfoCount;
  
  Results[2].Category := 'WARN';
  Results[2].Count := Stats.WarnCount;
  
  Results[3].Category := 'ERROR';
  Results[3].Count := Stats.ErrorCount;
  
  Results[4].Category := 'FATAL';
  Results[4].Count := Stats.FatalCount;
  
  // Calculate percentages
  if Stats.TotalCount > 0 then
    for var I := 0 to High(Results) do
      Results[I].Percentage := Results[I].Count / Stats.TotalCount * 100;
  
  Result := Results;
end;

function TLogAnalyzer.CountBySource(ATopN: Integer): TArray<TCountResult>;
var
  Counts: TDictionary<string, Int64>;
  Log: TAggregatedLog;
  Pair: TPair<string, Int64>;
  Results: TList<TCountResult>;
  CR: TCountResult;
  Total: Int64;
begin
  if FDataSource = nil then Exit;
  
  Counts := TDictionary<string, Int64>.Create;
  Results := TList<TCountResult>.Create;
  try
    Total := 0;
    for Log in FDataSource do
    begin
      if Log.Source <> '' then
      begin
        if Counts.ContainsKey(Log.Source) then
          Counts[Log.Source] := Counts[Log.Source] + 1
        else
          Counts.Add(Log.Source, 1);
        Inc(Total);
      end;
    end;
    
    for Pair in Counts do
    begin
      CR.Category := Pair.Key;
      CR.Count := Pair.Value;
      if Total > 0 then
        CR.Percentage := Pair.Value / Total * 100
      else
        CR.Percentage := 0;
      Results.Add(CR);
    end;
    
    // Sort by count descending
    Results.Sort(TComparer<TCountResult>.Construct(
      function(const A, B: TCountResult): Integer
      begin
        Result := B.Count - A.Count;
      end
    ));
    
    // Take top N
    if Results.Count > ATopN then
      Results.Count := ATopN;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    Counts.Free;
  end;
end;

function TLogAnalyzer.CountByHost(ATopN: Integer): TArray<TCountResult>;
var
  Counts: TDictionary<string, Int64>;
  Log: TAggregatedLog;
  Pair: TPair<string, Int64>;
  Results: TList<TCountResult>;
  CR: TCountResult;
  Total: Int64;
begin
  if FDataSource = nil then Exit;
  
  Counts := TDictionary<string, Int64>.Create;
  Results := TList<TCountResult>.Create;
  try
    Total := 0;
    for Log in FDataSource do
    begin
      if Log.Hostname <> '' then
      begin
        if Counts.ContainsKey(Log.Hostname) then
          Counts[Log.Hostname] := Counts[Log.Hostname] + 1
        else
          Counts.Add(Log.Hostname, 1);
        Inc(Total);
      end;
    end;
    
    for Pair in Counts do
    begin
      CR.Category := Pair.Key;
      CR.Count := Pair.Value;
      if Total > 0 then
        CR.Percentage := Pair.Value / Total * 100
      else
        CR.Percentage := 0;
      Results.Add(CR);
    end;
    
    Results.Sort(TComparer<TCountResult>.Construct(
      function(const A, B: TCountResult): Integer
      begin
        Result := B.Count - A.Count;
      end
    ));
    
    if Results.Count > ATopN then
      Results.Count := ATopN;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    Counts.Free;
  end;
end;

function TLogAnalyzer.CountByApp(ATopN: Integer): TArray<TCountResult>;
var
  Counts: TDictionary<string, Int64>;
  Log: TAggregatedLog;
  Pair: TPair<string, Int64>;
  Results: TList<TCountResult>;
  CR: TCountResult;
  Total: Int64;
begin
  if FDataSource = nil then Exit;
  
  Counts := TDictionary<string, Int64>.Create;
  Results := TList<TCountResult>.Create;
  try
    Total := 0;
    for Log in FDataSource do
    begin
      if Log.AppName <> '' then
      begin
        if Counts.ContainsKey(Log.AppName) then
          Counts[Log.AppName] := Counts[Log.AppName] + 1
        else
          Counts.Add(Log.AppName, 1);
        Inc(Total);
      end;
    end;
    
    for Pair in Counts do
    begin
      CR.Category := Pair.Key;
      CR.Count := Pair.Value;
      if Total > 0 then
        CR.Percentage := Pair.Value / Total * 100
      else
        CR.Percentage := 0;
      Results.Add(CR);
    end;
    
    Results.Sort(TComparer<TCountResult>.Construct(
      function(const A, B: TCountResult): Integer
      begin
        Result := B.Count - A.Count;
      end
    ));
    
    if Results.Count > ATopN then
      Results.Count := ATopN;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    Counts.Free;
  end;
end;

function TLogAnalyzer.CountByEnvironment: TArray<TCountResult>;
var
  Counts: TDictionary<string, Int64>;
  Log: TAggregatedLog;
  Pair: TPair<string, Int64>;
  Results: TList<TCountResult>;
  CR: TCountResult;
  Total: Int64;
begin
  if FDataSource = nil then Exit;
  
  Counts := TDictionary<string, Int64>.Create;
  Results := TList<TCountResult>.Create;
  try
    Total := 0;
    for Log in FDataSource do
    begin
      if Log.Environment <> '' then
      begin
        if Counts.ContainsKey(Log.Environment) then
          Counts[Log.Environment] := Counts[Log.Environment] + 1
        else
          Counts.Add(Log.Environment, 1);
        Inc(Total);
      end;
    end;
    
    for Pair in Counts do
    begin
      CR.Category := Pair.Key;
      CR.Count := Pair.Value;
      if Total > 0 then
        CR.Percentage := Pair.Value / Total * 100
      else
        CR.Percentage := 0;
      Results.Add(CR);
    end;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    Counts.Free;
  end;
end;

function TLogAnalyzer.CountByTime(ABucket: TTimeBucket): TLogTimeSeries;
var
  Counts: TDictionary<TDateTime, Int64>;
  Log: TAggregatedLog;
  BucketTime: TDateTime;
  Pair: TPair<TDateTime, Int64>;
  SortedKeys: TList<TDateTime>;
begin
  Result := TLogTimeSeries.Create('count', ABucket);
  
  if FDataSource = nil then Exit;
  
  Counts := TDictionary<TDateTime, Int64>.Create;
  SortedKeys := TList<TDateTime>.Create;
  try
    for Log in FDataSource do
    begin
      BucketTime := NormalizeBucket(Log.Timestamp, ABucket);
      if Counts.ContainsKey(BucketTime) then
        Counts[BucketTime] := Counts[BucketTime] + 1
      else
        Counts.Add(BucketTime, 1);
    end;
    
    // Sort by timestamp
    for Pair in Counts do
      SortedKeys.Add(Pair.Key);
    SortedKeys.Sort;
    
    for BucketTime in SortedKeys do
      Result.AddPoint(BucketTime, Counts[BucketTime]);
  finally
    SortedKeys.Free;
    Counts.Free;
  end;
end;

function TLogAnalyzer.CountByTimeAndLevel(ABucket: TTimeBucket): TArray<TLogTimeSeries>;
var
  Level: TLogLevel;
  LevelSeries: array[TLogLevel] of TDictionary<TDateTime, Int64>;
  Log: TAggregatedLog;
  BucketTime: TDateTime;
  TimePair: TPair<TDateTime, Boolean>;
  AllTimes: TDictionary<TDateTime, Boolean>;
  SortedTimes: TList<TDateTime>;
  Results: TArray<TLogTimeSeries>;
begin
  if FDataSource = nil then Exit;
  
  // Initialize dictionaries for each level
  for Level := Low(TLogLevel) to High(TLogLevel) do
    LevelSeries[Level] := TDictionary<TDateTime, Int64>.Create;
    
  AllTimes := TDictionary<TDateTime, Boolean>.Create;
  SortedTimes := TList<TDateTime>.Create;
  try
    // Count by level and time
    for Log in FDataSource do
    begin
      BucketTime := NormalizeBucket(Log.Timestamp, ABucket);
      AllTimes.AddOrSetValue(BucketTime, True);
      
      if LevelSeries[Log.Level].ContainsKey(BucketTime) then
        LevelSeries[Log.Level][BucketTime] := LevelSeries[Log.Level][BucketTime] + 1
      else
        LevelSeries[Log.Level].Add(BucketTime, 1);
    end;
    
    // Sort times
    for TimePair in AllTimes do
      SortedTimes.Add(TimePair.Key);
    SortedTimes.Sort;
    
    // Build result series
    SetLength(Results, Ord(High(TLogLevel)) + 1);
    for Level := Low(TLogLevel) to High(TLogLevel) do
    begin
      Results[Ord(Level)] := TLogTimeSeries.Create(LogLevelToStr(Level), ABucket);
      for BucketTime in SortedTimes do
      begin
        if LevelSeries[Level].ContainsKey(BucketTime) then
          Results[Ord(Level)].AddPoint(BucketTime, LevelSeries[Level][BucketTime])
        else
          Results[Ord(Level)].AddPoint(BucketTime, 0);
      end;
    end;
    
    Result := Results;
  finally
    SortedTimes.Free;
    AllTimes.Free;
    for Level := Low(TLogLevel) to High(TLogLevel) do
      LevelSeries[Level].Free;
  end;
end;

function TLogAnalyzer.ErrorRateByTime(ABucket: TTimeBucket): TLogTimeSeries;
var
  TotalCounts, ErrorCounts: TDictionary<TDateTime, Int64>;
  Log: TAggregatedLog;
  BucketTime: TDateTime;
  SortedTimes: TList<TDateTime>;
  Total, Errors: Int64;
begin
  Result := TLogTimeSeries.Create('error_rate', ABucket);
  
  if FDataSource = nil then Exit;
  
  TotalCounts := TDictionary<TDateTime, Int64>.Create;
  ErrorCounts := TDictionary<TDateTime, Int64>.Create;
  SortedTimes := TList<TDateTime>.Create;
  try
    for Log in FDataSource do
    begin
      BucketTime := NormalizeBucket(Log.Timestamp, ABucket);
      
      if TotalCounts.ContainsKey(BucketTime) then
        TotalCounts[BucketTime] := TotalCounts[BucketTime] + 1
      else
        TotalCounts.Add(BucketTime, 1);
        
      if Log.Level in [llError, llFatal] then
      begin
        if ErrorCounts.ContainsKey(BucketTime) then
          ErrorCounts[BucketTime] := ErrorCounts[BucketTime] + 1
        else
          ErrorCounts.Add(BucketTime, 1);
      end;
    end;
    
    // Sort times
    for BucketTime in TotalCounts.Keys do
      SortedTimes.Add(BucketTime);
    SortedTimes.Sort;
    
    // Calculate rates
    for BucketTime in SortedTimes do
    begin
      Total := TotalCounts[BucketTime];
      if ErrorCounts.ContainsKey(BucketTime) then
        Errors := ErrorCounts[BucketTime]
      else
        Errors := 0;
        
      if Total > 0 then
        Result.AddPoint(BucketTime, Errors / Total * 100)
      else
        Result.AddPoint(BucketTime, 0);
    end;
  finally
    SortedTimes.Free;
    ErrorCounts.Free;
    TotalCounts.Free;
  end;
end;

function TLogAnalyzer.TopErrors(ATopN: Integer): TArray<TTopError>;
var
  ErrorMap: TDictionary<string, TTopError>;
  Log: TAggregatedLog;
  Key: string;
  Err: TTopError;
  Pair: TPair<string, TTopError>;
  Results: TList<TTopError>;
  SourceSet: TDictionary<string, Boolean>;
begin
  if FDataSource = nil then Exit;
  
  ErrorMap := TDictionary<string, TTopError>.Create;
  Results := TList<TTopError>.Create;
  try
    for Log in FDataSource do
    begin
      if not (Log.Level in [llError, llFatal]) then Continue;
      
      // Use first 100 chars as key to group similar errors
      Key := Copy(Log.Message, 1, 100);
      
      if ErrorMap.TryGetValue(Key, Err) then
      begin
        Inc(Err.Count);
        if Log.Timestamp < Err.FirstSeen then
          Err.FirstSeen := Log.Timestamp;
        if Log.Timestamp > Err.LastSeen then
          Err.LastSeen := Log.Timestamp;
        ErrorMap[Key] := Err;
      end
      else
      begin
        Err.Message := Log.Message;
        Err.Count := 1;
        Err.FirstSeen := Log.Timestamp;
        Err.LastSeen := Log.Timestamp;
        SetLength(Err.Sources, 0);
        ErrorMap.Add(Key, Err);
      end;
    end;
    
    for Pair in ErrorMap do
      Results.Add(Pair.Value);
    
    // Sort by count descending
    Results.Sort(TComparer<TTopError>.Construct(
      function(const A, B: TTopError): Integer
      begin
        Result := B.Count - A.Count;
      end
    ));
    
    if Results.Count > ATopN then
      Results.Count := ATopN;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    ErrorMap.Free;
  end;
end;

function TLogAnalyzer.TopExceptions(ATopN: Integer): TArray<TTopError>;
var
  Log: TAggregatedLog;
  ExceptionLogs: TList<TAggregatedLog>;
begin
  if FDataSource = nil then Exit;
  
  ExceptionLogs := TList<TAggregatedLog>.Create;
  try
    for Log in FDataSource do
      if Log.StackTrace <> '' then
        ExceptionLogs.Add(Log);
    
    // Use same logic as TopErrors but on filtered list
    SetDataSource(ExceptionLogs, False);
    Result := TopErrors(ATopN);
    SetDataSource(FDataSource, FOwnsDataSource);
  finally
    ExceptionLogs.Free;
  end;
end;

function TLogAnalyzer.ErrorRate: Double;
var
  Stats: TLogStats;
begin
  Stats := GetStats;
  Result := Stats.ErrorRate;
end;

function TLogAnalyzer.ErrorRateBySource: TArray<TCountResult>;
var
  TotalBySource, ErrorBySource: TDictionary<string, Int64>;
  Log: TAggregatedLog;
  Pair: TPair<string, Int64>;
  Results: TList<TCountResult>;
  CR: TCountResult;
  Total, Errors: Int64;
begin
  if FDataSource = nil then Exit;
  
  TotalBySource := TDictionary<string, Int64>.Create;
  ErrorBySource := TDictionary<string, Int64>.Create;
  Results := TList<TCountResult>.Create;
  try
    for Log in FDataSource do
    begin
      if Log.Source = '' then Continue;
      
      if TotalBySource.ContainsKey(Log.Source) then
        TotalBySource[Log.Source] := TotalBySource[Log.Source] + 1
      else
        TotalBySource.Add(Log.Source, 1);
        
      if Log.Level in [llError, llFatal] then
      begin
        if ErrorBySource.ContainsKey(Log.Source) then
          ErrorBySource[Log.Source] := ErrorBySource[Log.Source] + 1
        else
          ErrorBySource.Add(Log.Source, 1);
      end;
    end;
    
    for Pair in TotalBySource do
    begin
      Total := Pair.Value;
      if ErrorBySource.ContainsKey(Pair.Key) then
        Errors := ErrorBySource[Pair.Key]
      else
        Errors := 0;
        
      CR.Category := Pair.Key;
      CR.Count := Errors;
      if Total > 0 then
        CR.Percentage := Errors / Total * 100
      else
        CR.Percentage := 0;
      Results.Add(CR);
    end;
    
    // Sort by error rate descending
    Results.Sort(TComparer<TCountResult>.Construct(
      function(const A, B: TCountResult): Integer
      begin
        if A.Percentage > B.Percentage then
          Result := -1
        else if A.Percentage < B.Percentage then
          Result := 1
        else
          Result := 0;
      end
    ));
    
    Result := Results.ToArray;
  finally
    Results.Free;
    ErrorBySource.Free;
    TotalBySource.Free;
  end;
end;

function TLogAnalyzer.FindPatterns(const APatterns: TArray<string>): TArray<TPatternMatch>;
var
  Pattern: string;
  Matches: TDictionary<string, TPatternMatch>;
  Log: TAggregatedLog;
  Match: TPatternMatch;
  Regex: TRegEx;
  Results: TArray<TPatternMatch>;
  I: Integer;
begin
  if FDataSource = nil then Exit;
  
  Matches := TDictionary<string, TPatternMatch>.Create;
  try
    // Initialize patterns
    for Pattern in APatterns do
    begin
      Match.Pattern := Pattern;
      Match.MatchCount := 0;
      Match.FirstOccurrence := 0;
      Match.LastOccurrence := 0;
      SetLength(Match.SampleMessages, 0);
      Matches.Add(Pattern, Match);
    end;
    
    // Search logs
    for Log in FDataSource do
    begin
      for Pattern in APatterns do
      begin
        try
          Regex := TRegEx.Create(Pattern, [roIgnoreCase]);
          if Regex.IsMatch(Log.Message) then
          begin
            Match := Matches[Pattern];
            Inc(Match.MatchCount);
            
            if (Match.FirstOccurrence = 0) or (Log.Timestamp < Match.FirstOccurrence) then
              Match.FirstOccurrence := Log.Timestamp;
            if Log.Timestamp > Match.LastOccurrence then
              Match.LastOccurrence := Log.Timestamp;
              
            // Keep up to 5 sample messages
            if Length(Match.SampleMessages) < 5 then
            begin
              SetLength(Match.SampleMessages, Length(Match.SampleMessages) + 1);
              Match.SampleMessages[High(Match.SampleMessages)] := Log.Message;
            end;
            
            Matches[Pattern] := Match;
          end;
        except
          // Invalid regex - skip
        end;
      end;
    end;
    
    // Build result array
    SetLength(Results, Matches.Count);
    I := 0;
    for Match in Matches.Values do
    begin
      Results[I] := Match;
      Inc(I);
    end;
    
    Result := Results;
  finally
    Matches.Free;
  end;
end;

function TLogAnalyzer.FindAnomalies(AThreshold: Double): TArray<TLogQueryItem>;
var
  HourlyCounts: TDictionary<TDateTime, Int64>;
  Log: TAggregatedLog;
  BucketTime: TDateTime;
  Counts: TArray<Int64>;
  Mean, StdDev, Sum, SumSq: Double;
  Count: Int64;
  Pair: TPair<TDateTime, Int64>;
  AnomalyTimes: TDictionary<TDateTime, Boolean>;
  Results: TList<TLogQueryItem>;
begin
  if FDataSource = nil then Exit;
  
  HourlyCounts := TDictionary<TDateTime, Int64>.Create;
  AnomalyTimes := TDictionary<TDateTime, Boolean>.Create;
  Results := TList<TLogQueryItem>.Create;
  try
    // Count errors by hour
    for Log in FDataSource do
    begin
      if not (Log.Level in [llError, llFatal]) then Continue;
      
      BucketTime := NormalizeBucket(Log.Timestamp, tbHour);
      if HourlyCounts.ContainsKey(BucketTime) then
        HourlyCounts[BucketTime] := HourlyCounts[BucketTime] + 1
      else
        HourlyCounts.Add(BucketTime, 1);
    end;
    
    if HourlyCounts.Count < 2 then
      Exit; // Not enough data
    
    // Calculate mean and stddev
    Sum := 0;
    SumSq := 0;
    for Count in HourlyCounts.Values do
    begin
      Sum := Sum + Count;
      SumSq := SumSq + (Count * Count);
    end;
    
    Mean := Sum / HourlyCounts.Count;
    StdDev := Sqrt((SumSq / HourlyCounts.Count) - (Mean * Mean));
    
    if StdDev < 0.001 then
      Exit; // No variance
    
    // Find anomalous hours
    for Pair in HourlyCounts do
    begin
      if Abs(Pair.Value - Mean) > (AThreshold * StdDev) then
        AnomalyTimes.Add(Pair.Key, True);
    end;
    
    // Collect logs from anomalous hours
    for Log in FDataSource do
    begin
      BucketTime := NormalizeBucket(Log.Timestamp, tbHour);
      if AnomalyTimes.ContainsKey(BucketTime) then
        Results.Add(TLogQueryItem.FromAggregatedLog(Log));
    end;
    
    Result := Results.ToArray;
  finally
    Results.Free;
    AnomalyTimes.Free;
    HourlyCounts.Free;
  end;
end;

function TLogAnalyzer.IsErrorRateIncreasing(AWindowMinutes: Integer): Boolean;
var
  Now_: TDateTime;
  HalfWindow: TDateTime;
  FirstHalfTotal, FirstHalfErrors: Int64;
  SecondHalfTotal, SecondHalfErrors: Int64;
  Log: TAggregatedLog;
  FirstRate, SecondRate: Double;
begin
  Result := False;
  if FDataSource = nil then Exit;
  
  Now_ := Now;
  HalfWindow := IncMinute(Now_, -AWindowMinutes div 2);
  
  FirstHalfTotal := 0;
  FirstHalfErrors := 0;
  SecondHalfTotal := 0;
  SecondHalfErrors := 0;
  
  for Log in FDataSource do
  begin
    if Log.Timestamp < IncMinute(Now_, -AWindowMinutes) then
      Continue;
      
    if Log.Timestamp < HalfWindow then
    begin
      Inc(FirstHalfTotal);
      if Log.Level in [llError, llFatal] then
        Inc(FirstHalfErrors);
    end
    else
    begin
      Inc(SecondHalfTotal);
      if Log.Level in [llError, llFatal] then
        Inc(SecondHalfErrors);
    end;
  end;
  
  if FirstHalfTotal > 0 then
    FirstRate := FirstHalfErrors / FirstHalfTotal
  else
    FirstRate := 0;
    
  if SecondHalfTotal > 0 then
    SecondRate := SecondHalfErrors / SecondHalfTotal
  else
    SecondRate := 0;
  
  Result := SecondRate > FirstRate * 1.5; // 50% increase threshold
end;

function TLogAnalyzer.GetTrend(ABucket: TTimeBucket): Double;
var
  TimeSeries: TLogTimeSeries;
  N: Integer;
  SumX, SumY, SumXY, SumX2: Double;
  I: Integer;
  Slope: Double;
begin
  Result := 0;
  
  TimeSeries := CountByTime(ABucket);
  try
    N := TimeSeries.Points.Count;
    if N < 2 then Exit;
    
    // Linear regression slope
    SumX := 0;
    SumY := 0;
    SumXY := 0;
    SumX2 := 0;
    
    for I := 0 to N - 1 do
    begin
      SumX := SumX + I;
      SumY := SumY + TimeSeries.Points[I].Value;
      SumXY := SumXY + (I * TimeSeries.Points[I].Value);
      SumX2 := SumX2 + (I * I);
    end;
    
    // Slope = (N*SumXY - SumX*SumY) / (N*SumX2 - SumX*SumX)
    if (N * SumX2 - SumX * SumX) <> 0 then
      Slope := (N * SumXY - SumX * SumY) / (N * SumX2 - SumX * SumX)
    else
      Slope := 0;
    
    Result := Slope;
  finally
    TimeSeries.Free;
  end;
end;

end.
