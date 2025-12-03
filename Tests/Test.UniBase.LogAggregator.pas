unit Test.UniBase.LogAggregator;

{*******************************************************************************
  Unit Tests for UniBase Log Aggregation System
  Tests cover:
  - Log aggregation and batching
  - Query builder and analyzer
  - Alert rules and manager
  - Dashboard generation and export
  
  Author: UniBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.DateUtils, DUnitX.TestFramework,
  UniBase.Types, UniBase.LogAggregator, UniBase.LogQuery, UniBase.LogAlert,
  UniBase.LogDashboard;

type
  [TestFixture]
  TTestLogAggregator = class
  public
    [Test]
    procedure Test_TAggregatedLog_Create;
    
    [Test]
    procedure Test_TLogBatch_AddAndCount;
    
    [Test]
    procedure Test_TLogBatch_ToJSON;
    
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
    procedure Test_QueryBuilder_WhereLevelIn;
    
    [Test]
    procedure Test_QueryBuilder_WhereSourceContains;
    
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

procedure TTestLogAggregator.Test_TAggregatedLog_Create;
var
  Log: TAggregatedLog;
begin
  Log := TAggregatedLog.Create(llError, 'Test error message', 'TestSource');
  
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
    
    Log := TAggregatedLog.Create(llInfo, 'Message 1', 'Source1');
    Batch.Add(Log);
    Assert.AreEqual(1, Batch.Count);
    
    Log := TAggregatedLog.Create(llWarn, 'Message 2', 'Source2');
    Batch.Add(Log);
    Assert.AreEqual(2, Batch.Count);
    
    Batch.Clear;
    Assert.AreEqual(0, Batch.Count);
  finally
    Batch.Free;
  end;
end;

procedure TTestLogAggregator.Test_TLogBatch_ToJSON;
var
  Batch: TLogBatch;
  Log: TAggregatedLog;
  JsonArr: TJSONArray;
begin
  Batch := TLogBatch.Create;
  try
    Log := TAggregatedLog.Create(llInfo, 'Test message', 'TestSource');
    Batch.Add(Log);
    
    JsonArr := Batch.ToJSONArray;
    try
      Assert.AreEqual(1, JsonArr.Count);
      Assert.IsNotNull(JsonArr.Items[0] as TJSONObject);
    finally
      JsonArr.Free;
    end;
  finally
    Batch.Free;
  end;
end;

procedure TTestLogAggregator.Test_TLogFilter_Fluent;
var
  Filter: TLogFilter;
begin
  Filter := TLogFilter.Create
    .WithLevels([llError, llFatal])
    .WithSource('MyApp')
    .WithTimeRange(Now - 1, Now);
  
  Assert.AreEqual(2, Length(Filter.Levels));
  Assert.AreEqual('MyApp', Filter.Source);
  Assert.IsTrue(Filter.StartTime > 0);
  Assert.IsTrue(Filter.EndTime > 0);
end;

procedure TTestLogAggregator.Test_TBackendConfig_ElasticSearch;
var
  Config: TBackendConfig;
begin
  Config := TBackendConfig.ElasticSearch('http://localhost:9200', 'app-logs');
  
  Assert.AreEqual(lbtElasticSearch, Config.BackendType);
  Assert.AreEqual('http://localhost:9200', Config.Endpoint);
  Assert.AreEqual('app-logs', Config.IndexName);
end;

procedure TTestLogAggregator.Test_TBackendConfig_Loki;
var
  Config: TBackendConfig;
begin
  Config := TBackendConfig.Loki('http://localhost:3100');
  
  Assert.AreEqual(lbtLoki, Config.BackendType);
  Assert.AreEqual('http://localhost:3100', Config.Endpoint);
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
    Log := TAggregatedLog.Create(llDebug, Format('Debug message %d', [I]), 'Module1');
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
  
  for I := 1 to 20 do
  begin
    Log := TAggregatedLog.Create(llInfo, Format('Info message %d', [I]), 'Module2');
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
  
  for I := 1 to 5 do
  begin
    Log := TAggregatedLog.Create(llWarn, Format('Warning message %d', [I]), 'Module1');
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
  
  for I := 1 to 8 do
  begin
    Log := TAggregatedLog.Create(llError, Format('Error: Connection failed %d', [I mod 3]), 'Module3');
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
  
  for I := 1 to 2 do
  begin
    Log := TAggregatedLog.Create(llFatal, 'Fatal: System crash', 'Kernel');
    Log.Timestamp := IncMinute(Now, -I);
    FLogs.Add(Log);
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_WhereLevelIn;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create(FLogs);
  try
    Results := Query
      .WhereLevelIn([llError, llFatal])
      .Execute;
    
    Assert.AreEqual(10, Results.Count); // 8 errors + 2 fatals
    Assert.AreEqual(10, Length(Results.Logs));
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_WhereSourceContains;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create(FLogs);
  try
    Results := Query
      .WhereSourceContains('Module1')
      .Execute;
    
    Assert.AreEqual(15, Results.Count); // 10 debug + 5 warn from Module1
  finally
    Query.Free;
  end;
end;

procedure TTestLogQuery.Test_QueryBuilder_TimeRange;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
begin
  Query := TLogQueryBuilder.Create(FLogs);
  try
    Results := Query
      .WhereTimeBetween(IncMinute(Now, -5), Now)
      .Execute;
    
    // Should get logs from last 5 minutes only
    Assert.IsTrue(Results.Count <= 45); // Could be less depending on timing
    Assert.IsTrue(Results.Count > 0);
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
  Counts: TArray<TKeyCount>;
begin
  Counts := FAnalyzer.CountByLevel;
  
  Assert.IsTrue(Length(Counts) > 0);
  // Should have counts for each level that has logs
end;

procedure TTestLogQuery.Test_Analyzer_CountBySource;
var
  Counts: TArray<TKeyCount>;
begin
  Counts := FAnalyzer.CountBySource;
  
  Assert.IsTrue(Length(Counts) >= 4); // Module1, Module2, Module3, Kernel
end;

procedure TTestLogQuery.Test_Analyzer_TopErrors;
var
  TopErrors: TArray<TKeyCount>;
begin
  TopErrors := FAnalyzer.TopErrors(5);
  
  Assert.IsTrue(Length(TopErrors) > 0);
  Assert.IsTrue(Length(TopErrors) <= 5);
end;

procedure TTestLogQuery.Test_Analyzer_ErrorRate;
var
  Rate: Double;
begin
  Rate := FAnalyzer.ErrorRate;
  
  // (8 errors + 2 fatals) / 45 total ≈ 22.2%
  Assert.IsTrue(Rate > 0.2);
  Assert.IsTrue(Rate < 0.3);
end;

procedure TTestLogQuery.Test_QueryResult_ToJSON;
var
  Query: TLogQueryBuilder;
  Results: TLogQueryResult;
  Json: TJSONArray;
begin
  Query := TLogQueryBuilder.Create(FLogs);
  try
    Results := Query
      .WhereLevelIn([llError])
      .Take(5)
      .Execute;
    
    Json := Results.ToJSON;
    try
      Assert.IsNotNull(Json);
      Assert.AreEqual(5, Json.Count);
    finally
      Json.Free;
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
  Query := TLogQueryBuilder.Create(FLogs);
  try
    Results := Query
      .WhereLevelIn([llInfo])
      .Take(3)
      .Execute;
    
    CSV := Results.ToCSV;
    
    Assert.IsTrue(CSV.Contains('Timestamp'));
    Assert.IsTrue(CSV.Contains('Level'));
    Assert.IsTrue(CSV.Contains('Message'));
    Assert.IsTrue(CSV.Contains('Info'));
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
    Assert.AreEqual(2, Length(Rule.Tags));
    Assert.AreEqual(1, Rule.Actions.Count);
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
    Logs[I] := TAggregatedLog.Create(llError, 'Test error', 'Source');
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
  Assert.AreEqual(0, FDashboard.Panels.Count);
end;

procedure TTestLogDashboard.Test_Dashboard_AddPanel;
var
  Panel: TDashboardPanel;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Statistics');
  
  Assert.AreEqual(1, FDashboard.Panels.Count);
  Assert.AreEqual('panel-1', Panel.Id);
  Assert.AreEqual('Statistics', Panel.Title);
end;

procedure TTestLogDashboard.Test_Widget_Counter;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Stats');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Widget.Config.Title := 'Total Logs';
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
  
  Assert.AreEqual(1, Widget.Series.Count);
  Assert.AreEqual(3, Series.Data.Count);
  Assert.AreEqual('Errors', Series.Name);
end;

procedure TTestLogDashboard.Test_Widget_Table;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Tables');
  Widget := Panel.AddWidget('table-1', wtTable);
  Widget.SetTableHeaders(['Source', 'Count']);
  Widget.AddTableRow(['Module1', '100']);
  Widget.AddTableRow(['Module2', '250']);
  
  Assert.AreEqual(2, Length(Widget.FTableHeaders));
end;

procedure TTestLogDashboard.Test_Exporter_ToJSON;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Exporter: TDashboardExporter;
  Json: TJSONObject;
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Widget.Config.Title := 'Test Counter';
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
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('counter-1', wtCounter);
  Widget.Config.Title := 'Error Count';
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
begin
  Panel := FDashboard.AddPanel('panel-1', 'Test Panel');
  Widget := Panel.AddWidget('table-1', wtTable);
  Widget.Config.Title := 'Log Stats';
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
