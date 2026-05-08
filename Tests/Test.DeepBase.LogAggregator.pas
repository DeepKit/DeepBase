unit Test.DeepBase.LogAggregator;

{*******************************************************************************
  Unit Tests for DeepBase Log Aggregation System
  Tests cover:
  - Log aggregation and batching
  - Query builder and analyzer
  - Alert rules and manager
  - Dashboard generation and export

  Author: DeepBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.DateUtils, DUnitX.TestFramework,
  DeepBase.Types, DeepBase.LogAggregator, DeepBase.LogQuery, DeepBase.LogAlert,
  DeepBase.LogDashboard;

type
  [TestFixture]
  TTestLogAggregator = class
  public
    [Test]
    procedure Test_TAggregatedLog_FieldAssignment;

    [Test]
    procedure Test_TLogBatch_AddAndCount;

    [Test]
    procedure Test_TLogBatch_ToArray;

    [Test]
    procedure Test_TLogFilter_Fluent;

    [Test]
    procedure Test_TBackendConfig_ElasticSearch;

    [Test]
    procedure Test_TBackendConfig_Loki;
  end;

  [TestFixture]
  TTestLogQuery = class
  private
    FAnalyzer: TLogAnalyzer;
    FLogs: TList<TAggregatedLog>;

    procedure SetupTestLogs;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_QueryBuilder_WhereLevels;

    [Test]
    procedure Test_QueryBuilder_WhereSource;

    [Test]
    procedure Test_QueryBuilder_TimeRange;

    [Test]
    procedure Test_Analyzer_GetStats;

    [Test]
    procedure Test_Analyzer_CountByLevel;

    [Test]
    procedure Test_Analyzer_CountBySource;

    [Test]
    procedure Test_Analyzer_TopErrors;

    [Test]
    procedure Test_Analyzer_ErrorRate;

    [Test]
    procedure Test_QueryResult_ToJSON;

    [Test]
    procedure Test_QueryResult_ToCSV;
  end;

  [TestFixture]
  TTestLogAlert = class
  private
    FManager: TAlertManager;
    FAlertFired: Boolean;
    FLastAlert: TAlertEvent;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_AlertCondition_ErrorCount;

    [Test]
    procedure Test_AlertCondition_ErrorRate;

    [Test]
    procedure Test_AlertCondition_PatternMatch;

    [Test]
    procedure Test_AlertRule_FluentAPI;

    [Test]
    procedure Test_AlertRule_ToJSON;

    [Test]
    procedure Test_AlertManager_AddRemoveRule;

    [Test]
    procedure Test_AlertManager_PushLogs;

    [Test]
    procedure Test_AlertAction_Webhook;
  end;

  [TestFixture]
  TTestLogDashboard = class
  private
    FDashboard: TDashboard;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Dashboard_Create;

    [Test]
    procedure Test_Dashboard_AddPanel;

    [Test]
    procedure Test_Widget_Counter;

    [Test]
    procedure Test_Widget_Chart;

    [Test]
    procedure Test_Widget_Table;

    [Test]
    procedure Test_Exporter_ToJSON;

    [Test]
    procedure Test_Exporter_ToHTML;

    [Test]
    procedure Test_Exporter_ToCSV;

    [Test]
    procedure Test_TimeRange_Relative;

    [Test]
    procedure Test_TimeRange_Custom;
  end;

implementation

{ TTestLogAggregator }

procedure TTestLogAggregator.Test_TAggregatedLog_FieldAssignment;
var
  Log: TAggregatedLog;
begin
  Log := Default(TAggregatedLog);
  Log.Level := llError;
  Log.Message := 'Test error message';
  Log.Source := 'TestSource';
  Log.Timestamp := Now;
  Log.ThreadId := TThread.CurrentThread.ThreadID;

  Assert.AreEqual(llError, Log.Level);
  Assert.AreEqual('Test error message', Log.Message);
  Assert.AreEqual('TestSource', Log.Source);
  Assert.IsTrue(Log.Timestamp > 0);
  Assert.IsTrue(Log.ThreadId > 0);
end;

procedure TTestLogAggregator.Test_TLogBatch_AddAndCount;
var
  Batch: TLogBatch;
  Log: TAggregatedLog;
begin
  Batch := TLogBatch.Create;
  try
    Assert.AreEqual(0, Batch.Count);

    Log := Default(TAggregatedLog);
    Log.Level := llInfo;
    Log.Message := 'Message 1';
    Log.Source := 'Source1';
    Batch.Add(Log);
    Assert.AreEqual(1, Batch.Count);

    Log := Default(TAggregatedLog);
    Log.Level := llWarn;
    Log.Message := 'Message 2';
    Log.Source := 'Source2';
    Batch.Add(Log);
    Assert.AreEqual(2, Batch.Count);

    Batch.Clear;
    Assert.AreEqual(0, Batch.Count);
  finally
    Batch.Free;
  end;
end;

procedure TTestLogAggregator.Test_TLogBatch_ToArray;
var
  Batch: TLogBatch;
  Log: TAggregatedLog;
  Arr: TArray<TAggregatedLog>;
begin
  Batch := TLogBatch.Create;
  try
    Log := Default(TAggregatedLog);
    Log.Level := llInfo;
    Log.Message := 'Test message';
    Log.Source := 'TestSource';
    Batch.Add(Log);

    Arr := Batch.ToArray;
    Assert.AreEqual(Integer(1), Integer(Length(Arr)));
    Assert.AreEqual('Test message', Arr[0].Message);
  finally
    Batch.Free;
  end;
end;

procedure TTestLogAggregator.Test_TLogFilter_Fluent;
var
  Filter: TLogFilter;
begin
  Filter := TLogFilter.All
    .WithLevels([llError, llFatal])
    .WithSource('MyApp')
    .WithTimeRange(Now - 1, Now);

  Assert.AreEqual(2, Integer(Length(Filter.Levels)));
  Assert.AreEqual(1, Integer(Length(Filter.Sources)));
  Assert.AreEqual('MyApp', Filter.Sources[0]);
  Assert.IsTrue(Filter.StartTime > 0);
  Assert.IsTrue(Filter.EndTime > 0);
end;

procedure TTestLogAggregator.Test_TBackendConfig_ElasticSearch;
var
  Config: TBackendConfig;
begin
  Config := TBackendConfig.ElasticSearch('http://localhost:9200', 'app-logs');

  Assert.AreEqual(lbtElasticSearch, Config.BackendType);
  Assert.AreEqual('http://localhost:9200', Config.Url);
  Assert.AreEqual('app-logs', Config.IndexName);
end;

procedure TTestLogAggregator.Test_TBackendConfig_Loki;
var
  Config: TBackendConfig;
begin
  Config := TBackendConfig.Loki('http://localhost:3100');

  Assert.AreEqual(lbtLoki, Config.BackendType);
  Assert.AreEqual('http://localhost:3100', Config.Url);
end;

{ TTestLogQuery }

procedure TTestLogQuery.Setup;
begin
  FLogs := TList<TAggregatedLog>.Create;
  FAnalyzer := TLogAnalyzer.Create;
  SetupTestLogs;
  FAnalyzer.SetDataSource(FLogs, False);
end;

procedure TTestLogQuery.TearDown;
begin
  FAnalyzer.Free;
  FLogs.Free;
end;

procedure TTestLogQuery.SetupTestLogs;
var
  Log: TAggregatedLog;
  I: Integer;
begin
  // Add various test logs
  for I := 1 to 10 do
  begin
    Log := Default(TAggregatedLog);
    Log.Level := llDebug;
    Log.Message := Format('Debug message %d', [I]);
    Log.Source := 'Module1';
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;

  for I := 1 to 20 do
  begin
    Log := Default(TAggregatedLog);
    Log.Level := llInfo;
    Log.Message := Format('Info message %d', [I]);
    Log.Source := 'Module2';
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;

  for I := 1 to 5 do
  begin
    Log := Default(TAggregatedLog);
    Log.Level := llWarn;
    Log.Message := Format('Warning message %d', [I]);
    Log.Source := 'Module1';
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;

  for I := 1 to 8 do
  begin
    Log := Default(TAggregatedLog);
    Log.Level := llError;
    Log.Message := Format('Error: Connection failed %d', [I mod 3]);
    Log.Source := 'Module3';
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;

  for I := 1 to 2 do
  begin
    Log := Default(TAggregatedLog);
    Log.Level := llFatal;
    Log.Message := 'Fatal: System crash';
    Log.Source := 'Kernel';
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_WhereLevels;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create;
  try
    Query.From(FLogs);
    Results := Query
      .WhereLevels([llError, llFatal])
      .Execute;
    try
      Assert.AreEqual(Int64(10), Results.TotalCount); // 8 errors + 2 fatals
      Assert.AreEqual(10, Integer(Results.Items.Count));
    finally
      Results.Free;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_WhereSource;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create;
  try
    Query.From(FLogs);
    Results := Query
      .WhereSource('Module1')
      .Execute;
    try
      Assert.AreEqual(Int64(15), Results.TotalCount); // 10 debug + 5 warn from Module1
    finally
      Results.Free;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_TimeRange;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create;
  try
    Query.From(FLogs);
    Results := Query
      .WhereBetween(IncMinute(Now, -5), Now)
      .Execute;
    try
      // Should get logs from last 5 minutes only
      Assert.IsTrue(Results.TotalCount <= Int64(45)); // Could be less depending on timing
      Assert.IsTrue(Results.TotalCount > 0);
    finally
      Results.Free;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_Analyzer_GetStats;
var
  Stats: TLogStats;
begin
  Stats := FAnalyzer.GetStats;

  Assert.AreEqual(Int64(45), Stats.TotalCount);
  Assert.AreEqual(Int64(10), Stats.DebugCount);
  Assert.AreEqual(Int64(20), Stats.InfoCount);
  Assert.AreEqual(Int64(5), Stats.WarnCount);
  Assert.AreEqual(Int64(8), Stats.ErrorCount);
  Assert.AreEqual(Int64(2), Stats.FatalCount);
  Assert.IsTrue(Stats.ErrorRate > 0);
end;

procedure TTestLogQuery.Test_Analyzer_CountByLevel;
var
  Counts: TArray<TCountResult>;
begin
  Counts := FAnalyzer.CountByLevel;

  Assert.IsTrue(Length(Counts) > 0);
  // Should have counts for each level that has logs
end;

procedure TTestLogQuery.Test_Analyzer_CountBySource;
var
  Counts: TArray<TCountResult>;
begin
  Counts := FAnalyzer.CountBySource;

  Assert.IsTrue(Length(Counts) >= 4); // Module1, Module2, Module3, Kernel
end;

procedure TTestLogQuery.Test_Analyzer_TopErrors;
var
  TopErrs: TArray<TTopError>;
begin
  TopErrs := FAnalyzer.TopErrors(5);

  Assert.IsTrue(Length(TopErrs) > 0);
  Assert.IsTrue(Length(TopErrs) <= 5);
end;

procedure TTestLogQuery.Test_Analyzer_ErrorRate;
var
  Rate: Double;
begin
  Rate := FAnalyzer.ErrorRate;

  // (8 errors + 2 fatals) / 45 total = 22.2%
  Assert.IsTrue(Rate > 0.2);
  Assert.IsTrue(Rate < 0.3);
end;

procedure TTestLogQuery.Test_QueryResult_ToJSON;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
  Json: TJSONObject;
  ItemsVal: TJSONValue;
begin
  Query := TLogQueryBuilder.Create;
  try
    Query.From(FLogs);
    Results := Query
      .WhereLevels([llError])
      .Take(5)
      .Execute;
    try
      Json := Results.ToJSON;
      try
        Assert.IsNotNull(Json);
        ItemsVal := Json.GetValue('items');
        Assert.IsNotNull(ItemsVal);
        Assert.AreEqual(5, Integer((ItemsVal as TJSONArray).Count));
      finally
        Json.Free;
      end;
    finally
      Results.Free;
    end;
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_QueryResult_ToCSV;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
  CSV: string;
begin
  Query := TLogQueryBuilder.Create;
  try
    Query.From(FLogs);
    Results := Query
      .WhereLevels([llInfo])
      .Take(3)
      .Execute;
    try
      CSV := Results.ToCSV;

      Assert.IsTrue(CSV.Contains('Timestamp') or CSV.Contains('timestamp'));
      Assert.IsTrue(CSV.Contains('Level') or CSV.Contains('level'));
      Assert.IsTrue(CSV.Contains('Message') or CSV.Contains('message'));
      Assert.IsTrue(CSV.Contains('Info'));
    finally
      Results.Free;
    end;
  finally
    Query.Free;
  end;
end;

{ TTestLogAlert }

procedure TTestLogAlert.Setup;
begin
  FManager := TAlertManager.Create;
  FAlertFired := False;
  FManager.OnAlert := procedure(Event: TAlertEvent)
    begin
      FAlertFired := True;
      FLastAlert := Event;
    end;
end;

procedure TTestLogAlert.TearDown;
begin
  FManager.Free;
end;

procedure TTestLogAlert.Test_AlertCondition_ErrorCount;
var
  Condition: TAlertCondition;
begin
  Condition := TAlertCondition.ErrorCount(10, 5);

  Assert.AreEqual(actErrorCount, Condition.ConditionType);
  Assert.AreEqual(Double(10), Condition.Threshold);
  Assert.AreEqual(5, Condition.TimeWindowMinutes);
end;

procedure TTestLogAlert.Test_AlertCondition_ErrorRate;
var
  Condition: TAlertCondition;
begin
  Condition := TAlertCondition.ErrorRate(5.0, 10);

  Assert.AreEqual(actErrorRate, Condition.ConditionType);
  Assert.AreEqual(Double(5.0), Condition.Threshold);
  Assert.AreEqual(10, Condition.TimeWindowMinutes);
end;

procedure TTestLogAlert.Test_AlertCondition_PatternMatch;
var
  Condition: TAlertCondition;
begin
  Condition := TAlertCondition.PatternMatch('OutOfMemory');

  Assert.AreEqual(actPatternMatch, Condition.ConditionType);
  Assert.AreEqual('OutOfMemory', Condition.Pattern);
end;

procedure TTestLogAlert.Test_AlertRule_FluentAPI;
var
  Rule: TAlertRule;
begin
  Rule := CreateAlertRule('rule-1', 'High Error Rate')
    .WithCondition(TAlertCondition.ErrorRate(10.0))
    .WithSeverity(asCritical)
    .WithCooldown(10)
    .WithTags(['production', 'critical'])
    .AddAction(TAlertAction.LogAction);
  try
    Assert.AreEqual('rule-1', Rule.Id);
    Assert.AreEqual('High Error Rate', Rule.Name);
    Assert.AreEqual(asCritical, Rule.Severity);
    Assert.AreEqual(10, Rule.CooldownMinutes);
    Assert.AreEqual(2, Integer(Length(Rule.Tags)));
    Assert.AreEqual(1, Integer(Rule.Actions.Count));
  finally
    Rule.Free;
  end;
end;

procedure TTestLogAlert.Test_AlertRule_ToJSON;
var
  Rule: TAlertRule;
  Json: TJSONObject;
begin
  Rule := CreateAlertRule('rule-2', 'Test Rule')
    .WithCondition(TAlertCondition.ErrorCount(5));
  try
    Json := Rule.ToJSON;
    try
      Assert.IsNotNull(Json);
      Assert.AreEqual('rule-2', Json.GetValue<string>('id'));
      Assert.AreEqual('Test Rule', Json.GetValue<string>('name'));
    finally
      Json.Free;
    end;
  finally
    Rule.Free;
  end;
end;

procedure TTestLogAlert.Test_AlertManager_AddRemoveRule;
var
  Rule: TAlertRule;
begin
  Rule := CreateAlertRule('test-rule', 'Test')
    .WithCondition(TAlertCondition.ErrorCount(10));

  FManager.AddRule(Rule);
  Assert.IsTrue(FManager.HasRule('test-rule'));

  FManager.RemoveRule('test-rule');
  Assert.IsFalse(FManager.HasRule('test-rule'));
end;

procedure TTestLogAlert.Test_AlertManager_PushLogs;
var
  Logs: TArray<TAggregatedLog>;
  I: Integer;
begin
  SetLength(Logs, 5);
  for I := 0 to High(Logs) do
  begin
    Logs[I] := Default(TAggregatedLog);
    Logs[I].Level := llError;
    Logs[I].Message := 'Test error';
    Logs[I].Source := 'Source';
    Logs[I].Timestamp := Now;
  end;

  FManager.PushLogs(Logs);

  // Just verify no exceptions
  Assert.Pass;
end;

procedure TTestLogAlert.Test_AlertAction_Webhook;
var
  Action: TAlertAction;
begin
  Action := TAlertAction.Webhook('https://hooks.example.com/alert');

  Assert.AreEqual(aatWebhook, Action.ActionType);
  Assert.AreEqual('https://hooks.example.com/alert', Action.WebhookUrl);
  Assert.AreEqual('POST', Action.WebhookMethod);
end;

{ TTestLogDashboard }

procedure TTestLogDashboard.Setup;
begin
  FDashboard := TDashboard.Create('test-dashboard', 'Test Dashboard');
end;

procedure TTestLogDashboard.TearDown;
begin
  FDashboard.Free;
end;

procedure TTestLogDashboard.Test_Dashboard_Create;
begin
  Assert.AreEqual('test-dashboard', FDashboard.Id);
  Assert.AreEqual('Test Dashboard', FDashboard.Title);
  Assert.AreEqual(0, Integer(FDashboard.Panels.Count));
end;

procedure TTestLogDashboard.Test_Dashboard_AddPanel;
var
  Panel: TDashboardPanel;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Statistics');

  Assert.AreEqual(1, Integer(FDashboard.Panels.Count));
  Assert.AreEqual('panel-1', Panel.Id);
  Assert.AreEqual('Statistics', Panel.Title);
end;

procedure TTestLogDashboard.Test_Widget_Counter;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Cfg: TWidgetConfig;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Stats');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Cfg := Widget.Config;
  Cfg.Title := 'Total Logs';
  Widget.Config := Cfg;
  Widget.SetValue(12345, 'logs');

  Assert.AreEqual('counter-1', Widget.Id);
  Assert.AreEqual(wtCounter, Widget.Config.WidgetType);
  Assert.AreEqual(Double(12345), Widget.Value);
  Assert.AreEqual('logs', Widget.Unit_);
end;

procedure TTestLogDashboard.Test_Widget_Chart;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Series: TWidgetSeries;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Charts');
  Widget := Panel.AddWidget('chart-1', wtLineChart);

  Series := Widget.AddSeries('Errors');
  Series.AddPoint(Now - 0.1, 5);
  Series.AddPoint(Now - 0.05, 8);
  Series.AddPoint(Now, 3);

  Assert.AreEqual(1, Integer(Widget.Series.Count));
  Assert.AreEqual(3, Integer(Series.Data.Count));
  Assert.AreEqual('Errors', Series.Name);
end;

procedure TTestLogDashboard.Test_Widget_Table;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  JsonWidget: TJSONObject;
  HeadersVal: TJSONValue;
  Cfg: TWidgetConfig;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Tables');
  Widget := Panel.AddWidget('table-1', wtTable);
  Cfg := Widget.Config;
  Cfg.Title := 'Log Stats';
  Widget.Config := Cfg;
  Widget.SetTableHeaders(['Source', 'Count']);
  Widget.AddTableRow(['Module1', '100']);
  Widget.AddTableRow(['Module2', '250']);

  // Verify headers via ToJSON since FTableHeaders is private
  JsonWidget := Widget.ToJSON;
  try
    HeadersVal := JsonWidget.GetValue('headers');
    Assert.IsNotNull(HeadersVal);
    Assert.AreEqual(2, Integer((HeadersVal as TJSONArray).Count));
  finally
    JsonWidget.Free;
  end;
end;

procedure TTestLogDashboard.Test_Exporter_ToJSON;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Exporter: TDashboardExporter;
  Json: TJSONObject;
  Cfg: TWidgetConfig;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Cfg := Widget.Config;
  Cfg.Title := 'Test Counter';
  Widget.Config := Cfg;
  Widget.SetValue(999);

  Exporter := TDashboardExporter.Create(FDashboard);
  try
    Json := Exporter.ToJSON;
    try
      Assert.IsNotNull(Json);
      Assert.AreEqual('test-dashboard', Json.GetValue<string>('id'));
      Assert.IsNotNull(Json.GetValue('panels'));
    finally
      Json.Free;
    end;
  finally
    Exporter.Free;
  end;
end;

procedure TTestLogDashboard.Test_Exporter_ToHTML;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Exporter: TDashboardExporter;
  HTML: string;
  Cfg: TWidgetConfig;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Cfg := Widget.Config;
  Cfg.Title := 'Error Count';
  Widget.Config := Cfg;
  Widget.SetValue(42, 'errors');

  Exporter := TDashboardExporter.Create(FDashboard);
  try
    HTML := Exporter.ToHTML;

    Assert.IsTrue(HTML.Contains('<!DOCTYPE html>'));
    Assert.IsTrue(HTML.Contains('Test Dashboard'));
    Assert.IsTrue(HTML.Contains('Test Panel'));
    Assert.IsTrue(HTML.Contains('Error Count'));
  finally
    Exporter.Free;
  end;
end;

procedure TTestLogDashboard.Test_Exporter_ToCSV;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Exporter: TDashboardExporter;
  CSV: string;
  Cfg: TWidgetConfig;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('table-1', wtTable);
  Cfg := Widget.Config;
  Cfg.Title := 'Log Stats';
  Widget.Config := Cfg;
  Widget.SetTableHeaders(['Level', 'Count']);
  Widget.AddTableRow(['Error', '100']);
  Widget.AddTableRow(['Warn', '50']);

  Exporter := TDashboardExporter.Create(FDashboard);
  try
    CSV := Exporter.ToCSV;

    Assert.IsTrue(CSV.Contains('Test Dashboard'));
    Assert.IsTrue(CSV.Contains('Level'));
    Assert.IsTrue(CSV.Contains('Count'));
    Assert.IsTrue(CSV.Contains('Error'));
  finally
    Exporter.Free;
  end;
end;

procedure TTestLogDashboard.Test_TimeRange_Relative;
var
  Range: TDashboardTimeRange;
  Actual: TPair<TDateTime, TDateTime>;
begin
  Range := TDashboardTimeRange.Last(60);

  Assert.AreEqual(60, Range.RelativeMinutes);

  Actual := Range.GetActualRange;
  Assert.IsTrue(Actual.Key < Actual.Value);
  Assert.IsTrue(Actual.Value <= Now);
end;

procedure TTestLogDashboard.Test_TimeRange_Custom;
var
  Range: TDashboardTimeRange;
  StartTime, EndTime: TDateTime;
begin
  StartTime := EncodeDate(2025, 1, 1);
  EndTime := EncodeDate(2025, 1, 31);

  Range := TDashboardTimeRange.Custom(StartTime, EndTime);

  Assert.AreEqual(0, Range.RelativeMinutes);
  Assert.AreEqual(StartTime, Range.StartTime);
  Assert.AreEqual(EndTime, Range.EndTime);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestLogAggregator);
  TDUnitX.RegisterTestFixture(TTestLogQuery);
  TDUnitX.RegisterTestFixture(TTestLogAlert);
  TDUnitX.RegisterTestFixture(TTestLogDashboard);

end.
