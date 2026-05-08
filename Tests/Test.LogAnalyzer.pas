{ ============================================================================
  Test.LogAnalyzer - LogAnalyzer 工具单元测试

  测试覆盖:
    - LogAnalyzer.Data: 日志数据�?
    - LogAnalyzer.Stats: 日志统计模块
    - LogAnalyzer.Export: 日志导出模块
  ============================================================================ }

unit Test.LogAnalyzer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.DateUtils,
  System.JSON,
  DUnitX.TestFramework,
  LogAnalyzer.Data,
  LogAnalyzer.Stats,
  LogAnalyzer.Export;

type
  // ============================================================================
  // LogAnalyzer.Data Tests
  // ============================================================================

  [TestFixture]
  TLogDataTests = class
  public
    [Test]
    procedure Test_TLogLevel_Values;

    [Test]
    procedure Test_TLogEntry_DefaultValues;

    [Test]
    procedure Test_TLogQuery_DefaultValues;

    [Test]
    procedure Test_TLogLevels_Set;
  end;

  // ============================================================================
  // LogAnalyzer.Stats Tests
  // ============================================================================

  [TestFixture]
  TLogStatsTests = class
  private
    FTestLogs: TArray<TLogEntry>;
    procedure CreateTestLogs;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_TLogStats_Clear;

    [Test]
    procedure Test_TLogStats_Calculate_Empty;

    [Test]
    procedure Test_TLogStats_Calculate_SingleLog;

    [Test]
    procedure Test_TLogStats_Calculate_MultipleLogs;

    [Test]
    procedure Test_TLogStats_CountByLevel;

    [Test]
    procedure Test_TLogStats_UniqueSources;

    [Test]
    procedure Test_TLogStats_TimeRange;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetBasicStats;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetStatsBySource;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetHourlyStats;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetDailyStats;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetTopErrorSources;

    [Test]
    procedure Test_TLogStatsAnalyzer_GetTopActiveSources;
  end;

  // ============================================================================
  // LogAnalyzer.Export Tests
  // ============================================================================

  [TestFixture]
  TLogExportTests = class
  private
    FTestLogs: TArray<TLogEntry>;
    FTestDir: string;
    procedure CreateTestLogs;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ExportToCSV_Creates_File;

    [Test]
    procedure Test_ExportToCSV_Header;

    [Test]
    procedure Test_ExportToCSV_Data_Rows;

    [Test]
    procedure Test_ExportToCSV_Escape_Comma;

    [Test]
    procedure Test_ExportToCSV_Escape_Quote;

    [Test]
    procedure Test_ExportToJSON_Creates_File;

    [Test]
    procedure Test_ExportToJSON_Valid_JSON;

    [Test]
    procedure Test_ExportToJSON_Array_Count;

    [Test]
    procedure Test_ExportToJSON_Fields;

    [Test]
    procedure Test_ExportToHTML_Creates_File;

    [Test]
    procedure Test_ExportToHTML_Contains_Table;

    [Test]
    procedure Test_ExportToHTML_Contains_Title;

    [Test]
    procedure Test_ExportToHTML_Escape_HTML;

    [Test]
    procedure Test_ExportToText_Creates_File;

    [Test]
    procedure Test_ExportToText_Contains_Data;

    [Test]
    procedure Test_Export_Empty_Logs;
  end;

implementation

{ TLogDataTests }

procedure TLogDataTests.Test_TLogLevel_Values;
begin
  Assert.AreEqual(0, Ord(llTrace));
  Assert.AreEqual(1, Ord(llDebug));
  Assert.AreEqual(2, Ord(llInfo));
  Assert.AreEqual(3, Ord(llWarn));
  Assert.AreEqual(4, Ord(llError));
  Assert.AreEqual(5, Ord(llFatal));
end;

procedure TLogDataTests.Test_TLogEntry_DefaultValues;
var
  Entry: TLogEntry;
begin
  Entry := Default(TLogEntry);
  Assert.AreEqual<Int64>(0, Entry.Id);
  Assert.AreEqual<TDateTime>(0, Entry.Timestamp);
  Assert.AreEqual(llTrace, Entry.Level);
  Assert.AreEqual('', Entry.Source);
  Assert.AreEqual('', Entry.Message);
  Assert.AreEqual('', Entry.Details);
end;

procedure TLogDataTests.Test_TLogQuery_DefaultValues;
var
  Query: TLogQuery;
begin
  Query := Default(TLogQuery);
  Assert.AreEqual<TDateTime>(0, Query.FromTime);
  Assert.AreEqual<TDateTime>(0, Query.ToTime);
  Assert.AreEqual('', Query.SourceKeyword);
  Assert.AreEqual('', Query.MessageKeyword);
end;

procedure TLogDataTests.Test_TLogLevels_Set;
var
  Levels: TLogLevels;
begin
  Levels := [llInfo, llWarn, llError];
  Assert.IsTrue(llInfo in Levels);
  Assert.IsTrue(llWarn in Levels);
  Assert.IsTrue(llError in Levels);
  Assert.IsFalse(llTrace in Levels);
  Assert.IsFalse(llDebug in Levels);
  Assert.IsFalse(llFatal in Levels);
end;

{ TLogStatsTests }

procedure TLogStatsTests.Setup;
begin
  CreateTestLogs;
end;

procedure TLogStatsTests.CreateTestLogs;
var
  I: Integer;
begin
  SetLength(FTestLogs, 20);

  for I := 0 to 19 do
  begin
    FTestLogs[I].Id := I + 1;
    FTestLogs[I].Timestamp := IncHour(Now, -20 + I);  // 过去 20 小时分布
    FTestLogs[I].Source := 'Source' + IntToStr((I mod 4) + 1);  // 4 个不同来�?

    case I mod 6 of
      0: FTestLogs[I].Level := llTrace;
      1: FTestLogs[I].Level := llDebug;
      2: FTestLogs[I].Level := llInfo;
      3: FTestLogs[I].Level := llWarn;
      4: FTestLogs[I].Level := llError;
      5: FTestLogs[I].Level := llFatal;
    end;

    FTestLogs[I].Message := Format('Test message %d', [I + 1]);
    FTestLogs[I].Details := '';
  end;
end;

procedure TLogStatsTests.Test_TLogStats_Clear;
var
  Stats: TLogStats;
begin
  Stats.TotalCount := 100;
  Stats.CountByLevel[llError] := 50;
  Stats.UniqueSources := 10;
  Stats.FirstTime := Now;
  Stats.LastTime := Now;

  Stats.Clear;

  Assert.AreEqual(0, Stats.TotalCount);
  Assert.AreEqual(0, Stats.CountByLevel[llError]);
  Assert.AreEqual(0, Stats.UniqueSources);
  Assert.AreEqual<TDateTime>(0, Stats.FirstTime);
  Assert.AreEqual<TDateTime>(0, Stats.LastTime);
end;

procedure TLogStatsTests.Test_TLogStats_Calculate_Empty;
var
  Stats: TLogStats;
  EmptyLogs: TArray<TLogEntry>;
begin
  SetLength(EmptyLogs, 0);
  Stats := TLogStats.Calculate(EmptyLogs);

  Assert.AreEqual(0, Stats.TotalCount);
  Assert.AreEqual(0, Stats.UniqueSources);
end;

procedure TLogStatsTests.Test_TLogStats_Calculate_SingleLog;
var
  Stats: TLogStats;
  Logs: TArray<TLogEntry>;
begin
  SetLength(Logs, 1);
  Logs[0].Id := 1;
  Logs[0].Timestamp := Now;
  Logs[0].Level := llInfo;
  Logs[0].Source := 'TestSource';
  Logs[0].Message := 'Test';

  Stats := TLogStats.Calculate(Logs);

  Assert.AreEqual(1, Stats.TotalCount);
  Assert.AreEqual(1, Stats.UniqueSources);
  Assert.AreEqual(1, Stats.CountByLevel[llInfo]);
end;

procedure TLogStatsTests.Test_TLogStats_Calculate_MultipleLogs;
var
  Stats: TLogStats;
begin
  Stats := TLogStats.Calculate(FTestLogs);
  Assert.AreEqual(20, Stats.TotalCount);
end;

procedure TLogStatsTests.Test_TLogStats_CountByLevel;
var
  Stats: TLogStats;
  Total: Integer;
  L: TLogLevel;
begin
  Stats := TLogStats.Calculate(FTestLogs);

  // 验证各级别计数总和等于总数
  Total := 0;
  for L := Low(TLogLevel) to High(TLogLevel) do
    Inc(Total, Stats.CountByLevel[L]);

  Assert.AreEqual(Stats.TotalCount, Total);
end;

procedure TLogStatsTests.Test_TLogStats_UniqueSources;
var
  Stats: TLogStats;
begin
  Stats := TLogStats.Calculate(FTestLogs);
  Assert.AreEqual(4, Stats.UniqueSources);  // Source1, Source2, Source3, Source4
end;

procedure TLogStatsTests.Test_TLogStats_TimeRange;
var
  Stats: TLogStats;
begin
  Stats := TLogStats.Calculate(FTestLogs);
  Assert.IsTrue(Stats.FirstTime < Stats.LastTime);
  Assert.IsTrue(Stats.FirstTime > 0);
  Assert.IsTrue(Stats.LastTime > 0);
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetBasicStats;
var
  Analyzer: TLogStatsAnalyzer;
  Stats: TLogStats;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    Stats := Analyzer.GetBasicStats;
    Assert.AreEqual(20, Stats.TotalCount);
  finally
    Analyzer.Free;
  end;
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetStatsBySource;
var
  Analyzer: TLogStatsAnalyzer;
  SourceStats: TArray<TSourceStats>;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    SourceStats := Analyzer.GetStatsBySource;
    Assert.AreEqual(Integer(4), Integer(Length(SourceStats)));

    // 验证按数量降序排�?
    if Length(SourceStats) > 1 then
      Assert.IsTrue(SourceStats[0].Count >= SourceStats[1].Count);
  finally
    Analyzer.Free;
  end;
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetHourlyStats;
var
  Analyzer: TLogStatsAnalyzer;
  HourlyStats: TArray<TTimeSlotStats>;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    HourlyStats := Analyzer.GetHourlyStats;
    Assert.IsTrue(Length(HourlyStats) > 0);

    // 验证按时间升序排�?
    if Length(HourlyStats) > 1 then
      Assert.IsTrue(HourlyStats[0].SlotTime <= HourlyStats[1].SlotTime);
  finally
    Analyzer.Free;
  end;
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetDailyStats;
var
  Analyzer: TLogStatsAnalyzer;
  DailyStats: TArray<TTimeSlotStats>;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    DailyStats := Analyzer.GetDailyStats;
    Assert.IsTrue(Length(DailyStats) > 0);
  finally
    Analyzer.Free;
  end;
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetTopErrorSources;
var
  Analyzer: TLogStatsAnalyzer;
  TopErrors: TArray<TSourceStats>;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    TopErrors := Analyzer.GetTopErrorSources(5);
    // 可能没有错误，所以只检查不会崩�?
    Assert.IsTrue(Length(TopErrors) <= 5);
  finally
    Analyzer.Free;
  end;
end;

procedure TLogStatsTests.Test_TLogStatsAnalyzer_GetTopActiveSources;
var
  Analyzer: TLogStatsAnalyzer;
  TopActive: TArray<TSourceStats>;
begin
  Analyzer := TLogStatsAnalyzer.Create(FTestLogs);
  try
    TopActive := Analyzer.GetTopActiveSources(3);
    Assert.AreEqual(Integer(3), Integer(Length(TopActive)));
  finally
    Analyzer.Free;
  end;
end;

{ TLogExportTests }

procedure TLogExportTests.Setup;
begin
  FTestDir := TPath.Combine(TPath.GetTempPath, 'LogAnalyzer_Test_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(FTestDir);
  CreateTestLogs;
end;

procedure TLogExportTests.TearDown;
begin
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
end;

procedure TLogExportTests.CreateTestLogs;
begin
  SetLength(FTestLogs, 5);

  FTestLogs[0].Id := 1;
  FTestLogs[0].Timestamp := EncodeDateTime(2025, 12, 19, 10, 0, 0, 0);
  FTestLogs[0].Level := llInfo;
  FTestLogs[0].Source := 'App.Main';
  FTestLogs[0].Message := 'Application started';
  FTestLogs[0].Details := '';

  FTestLogs[1].Id := 2;
  FTestLogs[1].Timestamp := EncodeDateTime(2025, 12, 19, 10, 1, 0, 0);
  FTestLogs[1].Level := llWarn;
  FTestLogs[1].Source := 'App.Config';
  FTestLogs[1].Message := 'Config file not found, using defaults';
  FTestLogs[1].Details := 'Path: C:\config.ini';

  FTestLogs[2].Id := 3;
  FTestLogs[2].Timestamp := EncodeDateTime(2025, 12, 19, 10, 2, 0, 0);
  FTestLogs[2].Level := llError;
  FTestLogs[2].Source := 'App.Database';
  FTestLogs[2].Message := 'Connection failed';
  FTestLogs[2].Details := 'Timeout after 30s';

  FTestLogs[3].Id := 4;
  FTestLogs[3].Timestamp := EncodeDateTime(2025, 12, 19, 10, 3, 0, 0);
  FTestLogs[3].Level := llInfo;
  FTestLogs[3].Source := 'App.Main';
  FTestLogs[3].Message := 'Message with, comma';
  FTestLogs[3].Details := '';

  FTestLogs[4].Id := 5;
  FTestLogs[4].Timestamp := EncodeDateTime(2025, 12, 19, 10, 4, 0, 0);
  FTestLogs[4].Level := llDebug;
  FTestLogs[4].Source := 'App.Main';
  FTestLogs[4].Message := 'Message with "quotes"';
  FTestLogs[4].Details := '';
end;

procedure TLogExportTests.Test_ExportToCSV_Creates_File;
var
  FileName: string;
begin
  FileName := TPath.Combine(FTestDir, 'test.csv');
  TLogExporter.ExportToCSV(FTestLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));
end;

procedure TLogExportTests.Test_ExportToCSV_Header;
var
  FileName: string;
  Lines: TStringList;
begin
  FileName := TPath.Combine(FTestDir, 'test_header.csv');
  TLogExporter.ExportToCSV(FTestLogs, FileName);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    Assert.IsTrue(Lines.Count > 0);
    Assert.IsTrue(Pos('ID', Lines[0]) > 0);
    Assert.IsTrue(Pos('时间', Lines[0]) > 0);
    Assert.IsTrue(Pos('级别', Lines[0]) > 0);
  finally
    Lines.Free;
  end;
end;

procedure TLogExportTests.Test_ExportToCSV_Data_Rows;
var
  FileName: string;
  Lines: TStringList;
begin
  FileName := TPath.Combine(FTestDir, 'test_data.csv');
  TLogExporter.ExportToCSV(FTestLogs, FileName);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName, TEncoding.UTF8);
    Assert.AreEqual(6, Integer(Lines.Count));  // 1 header + 5 data rows
  finally
    Lines.Free;
  end;
end;

procedure TLogExportTests.Test_ExportToCSV_Escape_Comma;
var
  FileName: string;
  Content: string;
begin
  FileName := TPath.Combine(FTestDir, 'test_comma.csv');
  TLogExporter.ExportToCSV(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  // 包含逗号的字段应该被引号包围
  Assert.IsTrue(Pos('"Message with, comma"', Content) > 0);
end;

procedure TLogExportTests.Test_ExportToCSV_Escape_Quote;
var
  FileName: string;
  Content: string;
begin
  FileName := TPath.Combine(FTestDir, 'test_quote.csv');
  TLogExporter.ExportToCSV(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  // 包含引号的字段应该转�?
  Assert.IsTrue(Pos('""quotes""', Content) > 0);
end;

procedure TLogExportTests.Test_ExportToJSON_Creates_File;
var
  FileName: string;
begin
  FileName := TPath.Combine(FTestDir, 'test.json');
  TLogExporter.ExportToJSON(FTestLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));
end;

procedure TLogExportTests.Test_ExportToJSON_Valid_JSON;
var
  FileName: string;
  Content: string;
  JValue: TJSONValue;
begin
  FileName := TPath.Combine(FTestDir, 'test_valid.json');
  TLogExporter.ExportToJSON(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  JValue := TJSONObject.ParseJSONValue(Content);
  try
    Assert.IsNotNull(JValue);
    Assert.IsTrue(JValue is TJSONArray);
  finally
    JValue.Free;
  end;
end;

procedure TLogExportTests.Test_ExportToJSON_Array_Count;
var
  FileName: string;
  Content: string;
  JArray: TJSONArray;
begin
  FileName := TPath.Combine(FTestDir, 'test_count.json');
  TLogExporter.ExportToJSON(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  JArray := TJSONObject.ParseJSONValue(Content) as TJSONArray;
  try
    Assert.AreEqual(5, Integer(JArray.Count));
  finally
    JArray.Free;
  end;
end;

procedure TLogExportTests.Test_ExportToJSON_Fields;
var
  FileName: string;
  Content: string;
  JArray: TJSONArray;
  JObj: TJSONObject;
begin
  FileName := TPath.Combine(FTestDir, 'test_fields.json');
  TLogExporter.ExportToJSON(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  JArray := TJSONObject.ParseJSONValue(Content) as TJSONArray;
  try
    JObj := JArray.Items[0] as TJSONObject;
    Assert.IsNotNull(JObj.GetValue('id'));
    Assert.IsNotNull(JObj.GetValue('timestamp'));
    Assert.IsNotNull(JObj.GetValue('level'));
    Assert.IsNotNull(JObj.GetValue('source'));
    Assert.IsNotNull(JObj.GetValue('message'));
  finally
    JArray.Free;
  end;
end;

procedure TLogExportTests.Test_ExportToHTML_Creates_File;
var
  FileName: string;
begin
  FileName := TPath.Combine(FTestDir, 'test.html');
  TLogExporter.ExportToHTML(FTestLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));
end;

procedure TLogExportTests.Test_ExportToHTML_Contains_Table;
var
  FileName: string;
  Content: string;
begin
  FileName := TPath.Combine(FTestDir, 'test_table.html');
  TLogExporter.ExportToHTML(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Assert.IsTrue(Pos('<table>', Content) > 0);
  Assert.IsTrue(Pos('</table>', Content) > 0);
  Assert.IsTrue(Pos('<thead>', Content) > 0);
  Assert.IsTrue(Pos('<tbody>', Content) > 0);
end;

procedure TLogExportTests.Test_ExportToHTML_Contains_Title;
var
  FileName: string;
  Content: string;
begin
  FileName := TPath.Combine(FTestDir, 'test_title.html');
  TLogExporter.ExportToHTML(FTestLogs, FileName, 'My Log Export');

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Assert.IsTrue(Pos('My Log Export', Content) > 0);
end;

procedure TLogExportTests.Test_ExportToHTML_Escape_HTML;
var
  FileName: string;
  Content: string;
  Logs: TArray<TLogEntry>;
begin
  SetLength(Logs, 1);
  Logs[0].Id := 1;
  Logs[0].Timestamp := Now;
  Logs[0].Level := llInfo;
  Logs[0].Source := 'Test';
  Logs[0].Message := '<script>alert("xss")</script>';

  FileName := TPath.Combine(FTestDir, 'test_escape.html');
  TLogExporter.ExportToHTML(Logs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  // 应该被转义，不应该包含原�?script 标签
  Assert.IsTrue(Pos('&lt;script&gt;', Content) > 0);
  Assert.IsFalse(Pos('<script>', Content) > 0);
end;

procedure TLogExportTests.Test_ExportToText_Creates_File;
var
  FileName: string;
begin
  FileName := TPath.Combine(FTestDir, 'test.txt');
  TLogExporter.ExportToText(FTestLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));
end;

procedure TLogExportTests.Test_ExportToText_Contains_Data;
var
  FileName: string;
  Content: string;
begin
  FileName := TPath.Combine(FTestDir, 'test_data.txt');
  TLogExporter.ExportToText(FTestLogs, FileName);

  Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  Assert.IsTrue(Pos('Application started', Content) > 0);
  Assert.IsTrue(Pos('App.Main', Content) > 0);
  Assert.IsTrue(Pos('INFO', Content) > 0);
end;

procedure TLogExportTests.Test_Export_Empty_Logs;
var
  FileName: string;
  EmptyLogs: TArray<TLogEntry>;
begin
  SetLength(EmptyLogs, 0);

  FileName := TPath.Combine(FTestDir, 'empty.csv');
  TLogExporter.ExportToCSV(EmptyLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));

  FileName := TPath.Combine(FTestDir, 'empty.json');
  TLogExporter.ExportToJSON(EmptyLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));

  FileName := TPath.Combine(FTestDir, 'empty.html');
  TLogExporter.ExportToHTML(EmptyLogs, FileName);
  Assert.IsTrue(TFile.Exists(FileName));
end;

initialization
  TDUnitX.RegisterTestFixture(TLogDataTests);
  TDUnitX.RegisterTestFixture(TLogStatsTests);
  TDUnitX.RegisterTestFixture(TLogExportTests);

end.
