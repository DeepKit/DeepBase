{ ============================================================================
  LogAnalyzer.Stats - 日志统计模块

  版本: 1.0
  功能:
    - 按级别统计日志数量
    - 按来源统计日志数量
    - 时间范围分析
    - 趋势分析
  ============================================================================ }

unit LogAnalyzer.Stats;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.DateUtils,
  LogAnalyzer.Data;

type
  /// <summary>
  /// 日志统计结果
  /// </summary>
  TLogStats = record
    TotalCount: Integer;
    CountByLevel: array[TLogLevel] of Integer;
    UniqueSources: Integer;
    FirstTime: TDateTime;
    LastTime: TDateTime;

    class function Calculate(const ALogs: TArray<TLogEntry>): TLogStats; static;
    procedure Clear;
  end;

  /// <summary>
  /// 按来源分组的统计
  /// </summary>
  TSourceStats = record
    Source: string;
    Count: Integer;
    ErrorCount: Integer;
    WarnCount: Integer;
  end;

  /// <summary>
  /// 时间段统计 (用于趋势图)
  /// </summary>
  TTimeSlotStats = record
    SlotTime: TDateTime;
    Count: Integer;
    ErrorCount: Integer;
  end;

  /// <summary>
  /// 日志统计分析器
  /// </summary>
  TLogStatsAnalyzer = class
  private
    FLogs: TArray<TLogEntry>;
  public
    constructor Create(const ALogs: TArray<TLogEntry>);

    /// <summary>
    /// 获取基本统计信息
    /// </summary>
    function GetBasicStats: TLogStats;

    /// <summary>
    /// 按来源分组统计
    /// </summary>
    function GetStatsBySource: TArray<TSourceStats>;

    /// <summary>
    /// 按小时分组统计 (用于趋势图)
    /// </summary>
    function GetHourlyStats: TArray<TTimeSlotStats>;

    /// <summary>
    /// 按天分组统计
    /// </summary>
    function GetDailyStats: TArray<TTimeSlotStats>;

    /// <summary>
    /// 获取错误最多的来源 (Top N)
    /// </summary>
    function GetTopErrorSources(ACount: Integer = 10): TArray<TSourceStats>;

    /// <summary>
    /// 获取最活跃的来源 (Top N)
    /// </summary>
    function GetTopActiveSources(ACount: Integer = 10): TArray<TSourceStats>;

    property Logs: TArray<TLogEntry> read FLogs;
  end;

implementation

{ TLogStats }

class function TLogStats.Calculate(const ALogs: TArray<TLogEntry>): TLogStats;
var
  I: Integer;
  Sources: TDictionary<string, Boolean>;
begin
  Result.Clear;
  Result.TotalCount := Length(ALogs);

  if Result.TotalCount = 0 then
    Exit;

  Sources := TDictionary<string, Boolean>.Create;
  try
    Result.FirstTime := ALogs[0].Timestamp;
    Result.LastTime := ALogs[0].Timestamp;

    for I := 0 to High(ALogs) do
    begin
      // 按级别计数
      Inc(Result.CountByLevel[ALogs[I].Level]);

      // 唯一来源
      if not Sources.ContainsKey(ALogs[I].Source) then
        Sources.Add(ALogs[I].Source, True);

      // 时间范围
      if ALogs[I].Timestamp < Result.FirstTime then
        Result.FirstTime := ALogs[I].Timestamp;
      if ALogs[I].Timestamp > Result.LastTime then
        Result.LastTime := ALogs[I].Timestamp;
    end;

    Result.UniqueSources := Sources.Count;
  finally
    Sources.Free;
  end;
end;

procedure TLogStats.Clear;
var
  L: TLogLevel;
begin
  TotalCount := 0;
  for L := Low(TLogLevel) to High(TLogLevel) do
    CountByLevel[L] := 0;
  UniqueSources := 0;
  FirstTime := 0;
  LastTime := 0;
end;

{ TLogStatsAnalyzer }

constructor TLogStatsAnalyzer.Create(const ALogs: TArray<TLogEntry>);
begin
  inherited Create;
  FLogs := ALogs;
end;

function TLogStatsAnalyzer.GetBasicStats: TLogStats;
begin
  Result := TLogStats.Calculate(FLogs);
end;

function TLogStatsAnalyzer.GetStatsBySource: TArray<TSourceStats>;
var
  Dict: TDictionary<string, TSourceStats>;
  I: Integer;
  Stats: TSourceStats;
  Pair: TPair<string, TSourceStats>;
  List: TList<TSourceStats>;
begin
  Dict := TDictionary<string, TSourceStats>.Create;
  List := TList<TSourceStats>.Create;
  try
    for I := 0 to High(FLogs) do
    begin
      if Dict.TryGetValue(FLogs[I].Source, Stats) then
      begin
        Inc(Stats.Count);
        if FLogs[I].Level = llError then
          Inc(Stats.ErrorCount);
        if FLogs[I].Level = llWarn then
          Inc(Stats.WarnCount);
        Dict[FLogs[I].Source] := Stats;
      end
      else
      begin
        Stats.Source := FLogs[I].Source;
        Stats.Count := 1;
        Stats.ErrorCount := Ord(FLogs[I].Level = llError);
        Stats.WarnCount := Ord(FLogs[I].Level = llWarn);
        Dict.Add(FLogs[I].Source, Stats);
      end;
    end;

    for Pair in Dict do
      List.Add(Pair.Value);

    // 按数量降序排序
    List.Sort(TComparer<TSourceStats>.Construct(
      function(const L, R: TSourceStats): Integer
      begin
        Result := R.Count - L.Count;
      end));

    Result := List.ToArray;
  finally
    List.Free;
    Dict.Free;
  end;
end;

function TLogStatsAnalyzer.GetHourlyStats: TArray<TTimeSlotStats>;
var
  Dict: TDictionary<TDateTime, TTimeSlotStats>;
  I: Integer;
  SlotTime: TDateTime;
  Stats: TTimeSlotStats;
  Pair: TPair<TDateTime, TTimeSlotStats>;
  List: TList<TTimeSlotStats>;
begin
  Dict := TDictionary<TDateTime, TTimeSlotStats>.Create;
  List := TList<TTimeSlotStats>.Create;
  try
    for I := 0 to High(FLogs) do
    begin
      // 截断到小时
      SlotTime := RecodeMinute(RecodeSecond(RecodeMilliSecond(FLogs[I].Timestamp, 0), 0), 0);

      if Dict.TryGetValue(SlotTime, Stats) then
      begin
        Inc(Stats.Count);
        if FLogs[I].Level in [llError, llFatal] then
          Inc(Stats.ErrorCount);
        Dict[SlotTime] := Stats;
      end
      else
      begin
        Stats.SlotTime := SlotTime;
        Stats.Count := 1;
        Stats.ErrorCount := Ord(FLogs[I].Level in [llError, llFatal]);
        Dict.Add(SlotTime, Stats);
      end;
    end;

    for Pair in Dict do
      List.Add(Pair.Value);

    // 按时间升序排序
    List.Sort(TComparer<TTimeSlotStats>.Construct(
      function(const L, R: TTimeSlotStats): Integer
      begin
        if L.SlotTime < R.SlotTime then
          Result := -1
        else if L.SlotTime > R.SlotTime then
          Result := 1
        else
          Result := 0;
      end));

    Result := List.ToArray;
  finally
    List.Free;
    Dict.Free;
  end;
end;

function TLogStatsAnalyzer.GetDailyStats: TArray<TTimeSlotStats>;
var
  Dict: TDictionary<TDateTime, TTimeSlotStats>;
  I: Integer;
  SlotTime: TDateTime;
  Stats: TTimeSlotStats;
  Pair: TPair<TDateTime, TTimeSlotStats>;
  List: TList<TTimeSlotStats>;
begin
  Dict := TDictionary<TDateTime, TTimeSlotStats>.Create;
  List := TList<TTimeSlotStats>.Create;
  try
    for I := 0 to High(FLogs) do
    begin
      // 截断到天
      SlotTime := DateOf(FLogs[I].Timestamp);

      if Dict.TryGetValue(SlotTime, Stats) then
      begin
        Inc(Stats.Count);
        if FLogs[I].Level in [llError, llFatal] then
          Inc(Stats.ErrorCount);
        Dict[SlotTime] := Stats;
      end
      else
      begin
        Stats.SlotTime := SlotTime;
        Stats.Count := 1;
        Stats.ErrorCount := Ord(FLogs[I].Level in [llError, llFatal]);
        Dict.Add(SlotTime, Stats);
      end;
    end;

    for Pair in Dict do
      List.Add(Pair.Value);

    // 按时间升序排序
    List.Sort(TComparer<TTimeSlotStats>.Construct(
      function(const L, R: TTimeSlotStats): Integer
      begin
        if L.SlotTime < R.SlotTime then
          Result := -1
        else if L.SlotTime > R.SlotTime then
          Result := 1
        else
          Result := 0;
      end));

    Result := List.ToArray;
  finally
    List.Free;
    Dict.Free;
  end;
end;

function TLogStatsAnalyzer.GetTopErrorSources(ACount: Integer): TArray<TSourceStats>;
var
  AllStats: TArray<TSourceStats>;
  List: TList<TSourceStats>;
  I: Integer;
begin
  AllStats := GetStatsBySource;

  // 按错误数降序排序
  List := TList<TSourceStats>.Create;
  try
    for I := 0 to High(AllStats) do
      if AllStats[I].ErrorCount > 0 then
        List.Add(AllStats[I]);

    List.Sort(TComparer<TSourceStats>.Construct(
      function(const L, R: TSourceStats): Integer
      begin
        Result := R.ErrorCount - L.ErrorCount;
      end));

    if List.Count > ACount then
      List.Count := ACount;

    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLogStatsAnalyzer.GetTopActiveSources(ACount: Integer): TArray<TSourceStats>;
var
  AllStats: TArray<TSourceStats>;
  I, Cnt: Integer;
begin
  AllStats := GetStatsBySource;

  Cnt := Length(AllStats);
  if Cnt > ACount then
    Cnt := ACount;

  SetLength(Result, Cnt);
  for I := 0 to Cnt - 1 do
    Result[I] := AllStats[I];
end;

end.
