{ ============================================================================
  LogAnalyzer.Stats - 鏃ュ織缁熻妯″潡

  鐗堟湰: 1.0
  鍔熻兘:
    - 鎸夌骇鍒粺璁℃棩蹇楁暟閲?
    - 鎸夋潵婧愮粺璁℃棩蹇楁暟閲?
    - 鏃堕棿鑼冨洿鍒嗘瀽
    - 瓒嬪娍鍒嗘瀽
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
  /// 鏃ュ織缁熻缁撴灉
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
  /// 鎸夋潵婧愬垎缁勭殑缁熻
  /// </summary>
  TSourceStats = record
    Source: string;
    Count: Integer;
    ErrorCount: Integer;
    WarnCount: Integer;
  end;

  /// <summary>
  /// 鏃堕棿娈电粺璁?(鐢ㄤ簬瓒嬪娍鍥?
  /// </summary>
  TTimeSlotStats = record
    SlotTime: TDateTime;
    Count: Integer;
    ErrorCount: Integer;
  end;

  /// <summary>
  /// 鏃ュ織缁熻鍒嗘瀽鍣?
  /// </summary>
  TLogStatsAnalyzer = class
  private
    FLogs: TArray<TLogEntry>;
  public
    constructor Create(const ALogs: TArray<TLogEntry>);

    /// <summary>
    /// 鑾峰彇鍩烘湰缁熻淇℃伅
    /// </summary>
    function GetBasicStats: TLogStats;

    /// <summary>
    /// 鎸夋潵婧愬垎缁勭粺璁?
    /// </summary>
    function GetStatsBySource: TArray<TSourceStats>;

    /// <summary>
    /// 鎸夊皬鏃跺垎缁勭粺璁?(鐢ㄤ簬瓒嬪娍鍥?
    /// </summary>
    function GetHourlyStats: TArray<TTimeSlotStats>;

    /// <summary>
    /// 鎸夊ぉ鍒嗙粍缁熻
    /// </summary>
    function GetDailyStats: TArray<TTimeSlotStats>;

    /// <summary>
    /// 鑾峰彇閿欒鏈€澶氱殑鏉ユ簮 (Top N)
    /// </summary>
    function GetTopErrorSources(ACount: Integer = 10): TArray<TSourceStats>;

    /// <summary>
    /// 鑾峰彇鏈€娲昏穬鐨勬潵婧?(Top N)
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
      // 鎸夌骇鍒鏁?
      Inc(Result.CountByLevel[ALogs[I].Level]);

      // 鍞竴鏉ユ簮
      if not Sources.ContainsKey(ALogs[I].Source) then
        Sources.Add(ALogs[I].Source, True);

      // 鏃堕棿鑼冨洿
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

    // 鎸夋暟閲忛檷搴忔帓搴?
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
      // 鎴柇鍒板皬鏃?
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

    // 鎸夋椂闂村崌搴忔帓搴?
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
      // 鎴柇鍒板ぉ
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

    // 鎸夋椂闂村崌搴忔帓搴?
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

  // 鎸夐敊璇暟闄嶅簭鎺掑簭
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
