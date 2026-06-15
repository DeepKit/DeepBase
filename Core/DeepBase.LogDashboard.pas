unit DeepBase.LogDashboard;

{*******************************************************************************
  DeepBase Log Dashboard Export
  Dashboard data structures and exporters:
  - Widget types (Counter, Gauge, Chart, Table, Heatmap)
  - Dashboard layout and configuration
  - Export to JSON (Grafana-compatible), HTML, CSV
  
  Author: DeepBase Team
  Created: 2025-12-02
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.StrUtils, System.Rtti,
  DeepBase.Types, DeepBase.LogAggregator, DeepBase.LogQuery;

type
  /// <summary>Widget type enumeration</summary>
  TWidgetType = (
    wtCounter,      // Single numeric value
    wtGauge,        // Percentage/ratio display
    wtLineChart,    // Time series line chart
    wtBarChart,     // Bar chart
    wtPieChart,     // Pie/donut chart
    wtTable,        // Data table
    wtHeatmap,      // Heatmap visualization
    wtLogList,      // Recent log entries
    wtAlertList     // Active alerts
  );

  /// <summary>Time range for dashboard</summary>
  TDashboardTimeRange = record
    StartTime: TDateTime;
    EndTime: TDateTime;
    RelativeMinutes: Integer; // If > 0, use relative time
    
    class function Last(AMinutes: Integer): TDashboardTimeRange; static;
    class function Custom(AStart, AEnd: TDateTime): TDashboardTimeRange; static;
    function GetActualRange: TPair<TDateTime, TDateTime>;
    function ToString: string;
  end;

  /// <summary>Widget data point</summary>
  TWidgetDataPoint = record
    Timestamp: TDateTime;
    Value: Double;
    Label_: string;
    
    class function Create(ATimestamp: TDateTime; AValue: Double; const ALabel: string = ''): TWidgetDataPoint; static;
  end;

  /// <summary>Widget series for charts</summary>
  TWidgetSeries = class
  private
    FName: string;
    FData: TList<TWidgetDataPoint>;
    FColor: string;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    
    procedure AddPoint(const APoint: TWidgetDataPoint); overload;
    procedure AddPoint(ATimestamp: TDateTime; AValue: Double); overload;
    
    property Name: string read FName write FName;
    property Data: TList<TWidgetDataPoint> read FData;
    property Color: string read FColor write FColor;
  end;

  /// <summary>Widget configuration</summary>
  TWidgetConfig = record
    Title: string;
    Description: string;
    WidgetType: TWidgetType;
    Width: Integer;  // Grid units (1-12)
    Height: Integer; // Grid units
    RefreshIntervalSec: Integer;
    Thresholds: TArray<Double>;
    ThresholdColors: TArray<string>;
    
    class function Default(AType: TWidgetType): TWidgetConfig; static;
  end;

  /// <summary>Dashboard widget</summary>
  TDashboardWidget = class
  private
    FId: string;
    FConfig: TWidgetConfig;
    FSeries: TObjectList<TWidgetSeries>;
    FValue: Double;
    FUnit: string;
    FTableHeaders: TArray<string>;
    FTableRows: TList<TArray<string>>;
  public
    constructor Create(const AId: string; AType: TWidgetType);
    destructor Destroy; override;
    
    // For counter/gauge
    procedure SetValue(AValue: Double; const AUnit: string = '');
    
    // For charts
    function AddSeries(const AName: string): TWidgetSeries;
    procedure ClearSeries;
    
    // For tables
    procedure SetTableHeaders(const AHeaders: TArray<string>);
    procedure AddTableRow(const ARow: TArray<string>);
    procedure ClearTable;
    
    function ToJSON: TJSONObject;
    
    property Id: string read FId;
    property Config: TWidgetConfig read FConfig write FConfig;
    property Series: TObjectList<TWidgetSeries> read FSeries;
    property Value: Double read FValue;
    property Unit_: string read FUnit;
  end;

  /// <summary>Dashboard panel (group of widgets)</summary>
  TDashboardPanel = class
  private
    FId: string;
    FTitle: string;
    FWidgets: TObjectList<TDashboardWidget>;
    FCollapsed: Boolean;
  public
    constructor Create(const AId, ATitle: string);
    destructor Destroy; override;
    
    function AddWidget(const AId: string; AType: TWidgetType): TDashboardWidget;
    
    property Id: string read FId;
    property Title: string read FTitle write FTitle;
    property Widgets: TObjectList<TDashboardWidget> read FWidgets;
    property Collapsed: Boolean read FCollapsed write FCollapsed;
  end;

  /// <summary>Dashboard definition</summary>
  TDashboard = class
  private
    FId: string;
    FTitle: string;
    FDescription: string;
    FPanels: TObjectList<TDashboardPanel>;
    FTimeRange: TDashboardTimeRange;
    FRefreshIntervalSec: Integer;
    FTags: TArray<string>;
    FCreated: TDateTime;
    FModified: TDateTime;
  public
    constructor Create(const AId, ATitle: string);
    destructor Destroy; override;
    
    function AddPanel(const AId, ATitle: string): TDashboardPanel;
    
    property Id: string read FId;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Panels: TObjectList<TDashboardPanel> read FPanels;
    property TimeRange: TDashboardTimeRange read FTimeRange write FTimeRange;
    property RefreshIntervalSec: Integer read FRefreshIntervalSec write FRefreshIntervalSec;
    property Tags: TArray<string> read FTags write FTags;
  end;

  /// <summary>Dashboard exporter - exports to various formats</summary>
  TDashboardExporter = class
  private
    FDashboard: TDashboard;
    
    function WidgetTypeToString(AType: TWidgetType): string;
    function SeriesDataToJSON(ASeries: TWidgetSeries): TJSONArray;
    function WidgetToGrafanaPanel(AWidget: TDashboardWidget; AIndex: Integer): TJSONObject;
    function GenerateCSVForWidget(AWidget: TDashboardWidget): string;
    function EscapeCSV(const AValue: string): string;
    function EscapeHTML(const AValue: string): string;
  public
    constructor Create(ADashboard: TDashboard);
    
    /// <summary>Export to JSON (internal format)</summary>
    function ToJSON: TJSONObject;
    
    /// <summary>Export to Grafana-compatible JSON</summary>
    function ToGrafanaJSON: TJSONObject;
    
    /// <summary>Export to standalone HTML</summary>
    function ToHTML(const ATitle: string = ''): string;
    
    /// <summary>Export widget data to CSV</summary>
    function ToCSV: string;
    
    /// <summary>Export single widget to CSV</summary>
    function WidgetToCSV(const AWidgetId: string): string;
    
    property Dashboard: TDashboard read FDashboard;
  end;

  /// <summary>Dashboard builder - creates dashboards from log data</summary>
  TDashboardBuilder = class
  private
    FAnalyzer: TLogAnalyzer;
    FTimeRange: TDashboardTimeRange;
  public
    constructor Create(AAnalyzer: TLogAnalyzer);
    
    /// <summary>Set time range for dashboard</summary>
    function SetTimeRange(const ARange: TDashboardTimeRange): TDashboardBuilder;
    
    /// <summary>Build overview dashboard</summary>
    function BuildOverviewDashboard: TDashboard;
    
    /// <summary>Build error analysis dashboard</summary>
    function BuildErrorDashboard: TDashboard;
    
    /// <summary>Build performance dashboard</summary>
    function BuildPerformanceDashboard: TDashboard;
  end;

implementation

{ TDashboardTimeRange }

class function TDashboardTimeRange.Last(AMinutes: Integer): TDashboardTimeRange;
begin
  Result.StartTime := 0;
  Result.EndTime := 0;
  Result.RelativeMinutes := AMinutes;
end;

class function TDashboardTimeRange.Custom(AStart, AEnd: TDateTime): TDashboardTimeRange;
begin
  Result.StartTime := AStart;
  Result.EndTime := AEnd;
  Result.RelativeMinutes := 0;
end;

function TDashboardTimeRange.GetActualRange: TPair<TDateTime, TDateTime>;
begin
  if RelativeMinutes > 0 then
  begin
    Result.Value := Now;
    Result.Key := IncMinute(Result.Value, -RelativeMinutes);
  end
  else
  begin
    Result.Key := StartTime;
    Result.Value := EndTime;
  end;
end;

function TDashboardTimeRange.ToString: string;
begin
  if RelativeMinutes > 0 then
  begin
    if RelativeMinutes < 60 then
      Result := Format('Last %d minutes', [RelativeMinutes])
    else if RelativeMinutes < 1440 then
      Result := Format('Last %d hours', [RelativeMinutes div 60])
    else
      Result := Format('Last %d days', [RelativeMinutes div 1440]);
  end
  else
    Result := Format('%s - %s', [DateTimeToStr(StartTime), DateTimeToStr(EndTime)]);
end;

{ TWidgetDataPoint }

class function TWidgetDataPoint.Create(ATimestamp: TDateTime; AValue: Double; const ALabel: string): TWidgetDataPoint;
begin
  Result.Timestamp := ATimestamp;
  Result.Value := AValue;
  Result.Label_ := ALabel;
end;

{ TWidgetSeries }

constructor TWidgetSeries.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FData := TList<TWidgetDataPoint>.Create;
  FColor := '';
end;

destructor TWidgetSeries.Destroy;
begin
  FreeAndNil(FData);
  inherited;
end;

procedure TWidgetSeries.AddPoint(const APoint: TWidgetDataPoint);
begin
  FData.Add(APoint);
end;

procedure TWidgetSeries.AddPoint(ATimestamp: TDateTime; AValue: Double);
begin
  FData.Add(TWidgetDataPoint.Create(ATimestamp, AValue, ''));
end;

{ TWidgetConfig }

class function TWidgetConfig.Default(AType: TWidgetType): TWidgetConfig;
begin
  Result.Title := '';
  Result.Description := '';
  Result.WidgetType := AType;
  Result.RefreshIntervalSec := 60;
  SetLength(Result.Thresholds, 0);
  SetLength(Result.ThresholdColors, 0);
  
  case AType of
    wtCounter, wtGauge:
    begin
      Result.Width := 3;
      Result.Height := 2;
    end;
    wtLineChart, wtBarChart:
    begin
      Result.Width := 6;
      Result.Height := 4;
    end;
    wtPieChart:
    begin
      Result.Width := 4;
      Result.Height := 4;
    end;
    wtTable, wtLogList, wtAlertList:
    begin
      Result.Width := 12;
      Result.Height := 6;
    end;
    wtHeatmap:
    begin
      Result.Width := 12;
      Result.Height := 4;
    end;
  else
    Result.Width := 6;
    Result.Height := 4;
  end;
end;

{ TDashboardWidget }

constructor TDashboardWidget.Create(const AId: string; AType: TWidgetType);
begin
  inherited Create;
  FId := AId;
  FConfig := TWidgetConfig.Default(AType);
  FSeries := TObjectList<TWidgetSeries>.Create(True);
  FTableRows := TList<TArray<string>>.Create;
  FValue := 0;
  FUnit := '';
  SetLength(FTableHeaders, 0);
end;

destructor TDashboardWidget.Destroy;
begin
  FreeAndNil(FTableRows);
  FreeAndNil(FSeries);
  inherited;
end;

procedure TDashboardWidget.SetValue(AValue: Double; const AUnit: string);
begin
  FValue := AValue;
  FUnit := AUnit;
end;

function TDashboardWidget.AddSeries(const AName: string): TWidgetSeries;
begin
  Result := TWidgetSeries.Create(AName);
  FSeries.Add(Result);
end;

procedure TDashboardWidget.ClearSeries;
begin
  FSeries.Clear;
end;

procedure TDashboardWidget.SetTableHeaders(const AHeaders: TArray<string>);
begin
  FTableHeaders := AHeaders;
end;

procedure TDashboardWidget.AddTableRow(const ARow: TArray<string>);
begin
  FTableRows.Add(ARow);
end;

procedure TDashboardWidget.ClearTable;
begin
  FTableRows.Clear;
end;

function TDashboardWidget.ToJSON: TJSONObject;
var
  ConfigObj, SeriesObj, PointObj: TJSONObject;
  SeriesArr, DataArr, HeadersArr, RowsArr, RowArr: TJSONArray;
  Series: TWidgetSeries;
  Point: TWidgetDataPoint;
  Row: TArray<string>;
  S: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  
  // Config
  ConfigObj := TJSONObject.Create;
  ConfigObj.AddPair('title', FConfig.Title);
  ConfigObj.AddPair('description', FConfig.Description);
  ConfigObj.AddPair('type', TRttiEnumerationType.GetName(FConfig.WidgetType));
  ConfigObj.AddPair('width', TJSONNumber.Create(FConfig.Width));
  ConfigObj.AddPair('height', TJSONNumber.Create(FConfig.Height));
  ConfigObj.AddPair('refreshInterval', TJSONNumber.Create(FConfig.RefreshIntervalSec));
  Result.AddPair('config', ConfigObj);
  
  // Value for counter/gauge
  if FConfig.WidgetType in [wtCounter, wtGauge] then
  begin
    Result.AddPair('value', TJSONNumber.Create(FValue));
    if FUnit <> '' then
      Result.AddPair('unit', FUnit);
  end;
  
  // Series for charts
  if FSeries.Count > 0 then
  begin
    SeriesArr := TJSONArray.Create;
    for Series in FSeries do
    begin
      SeriesObj := TJSONObject.Create;
      SeriesObj.AddPair('name', Series.Name);
      if Series.Color <> '' then
        SeriesObj.AddPair('color', Series.Color);
      
      DataArr := TJSONArray.Create;
      for Point in Series.Data do
      begin
        PointObj := TJSONObject.Create;
        PointObj.AddPair('t', DateToISO8601(Point.Timestamp, False));
        PointObj.AddPair('v', TJSONNumber.Create(Point.Value));
        if Point.Label_ <> '' then
          PointObj.AddPair('l', Point.Label_);
        DataArr.AddElement(PointObj);
      end;
      SeriesObj.AddPair('data', DataArr);
      SeriesArr.AddElement(SeriesObj);
    end;
    Result.AddPair('series', SeriesArr);
  end;
  
  // Table data
  if Length(FTableHeaders) > 0 then
  begin
    HeadersArr := TJSONArray.Create;
    for S in FTableHeaders do
      HeadersArr.Add(S);
    Result.AddPair('headers', HeadersArr);
    
    RowsArr := TJSONArray.Create;
    for Row in FTableRows do
    begin
      RowArr := TJSONArray.Create;
      for S in Row do
        RowArr.Add(S);
      RowsArr.AddElement(RowArr);
    end;
    Result.AddPair('rows', RowsArr);
  end;
end;

{ TDashboardPanel }

constructor TDashboardPanel.Create(const AId, ATitle: string);
begin
  inherited Create;
  FId := AId;
  FTitle := ATitle;
  FWidgets := TObjectList<TDashboardWidget>.Create(True);
  FCollapsed := False;
end;

destructor TDashboardPanel.Destroy;
begin
  FreeAndNil(FWidgets);
  inherited;
end;

function TDashboardPanel.AddWidget(const AId: string; AType: TWidgetType): TDashboardWidget;
begin
  Result := TDashboardWidget.Create(AId, AType);
  FWidgets.Add(Result);
end;

{ TDashboard }

constructor TDashboard.Create(const AId, ATitle: string);
begin
  inherited Create;
  FId := AId;
  FTitle := ATitle;
  FDescription := '';
  FPanels := TObjectList<TDashboardPanel>.Create(True);
  FTimeRange := TDashboardTimeRange.Last(60);
  FRefreshIntervalSec := 60;
  SetLength(FTags, 0);
  FCreated := Now;
  FModified := Now;
end;

destructor TDashboard.Destroy;
begin
  FreeAndNil(FPanels);
  inherited;
end;

function TDashboard.AddPanel(const AId, ATitle: string): TDashboardPanel;
begin
  Result := TDashboardPanel.Create(AId, ATitle);
  FPanels.Add(Result);
  FModified := Now;
end;

{ TDashboardExporter }

constructor TDashboardExporter.Create(ADashboard: TDashboard);
begin
  inherited Create;
  FDashboard := ADashboard;
end;

function TDashboardExporter.WidgetTypeToString(AType: TWidgetType): string;
begin
  case AType of
    wtCounter: Result := 'stat';
    wtGauge: Result := 'gauge';
    wtLineChart: Result := 'timeseries';
    wtBarChart: Result := 'barchart';
    wtPieChart: Result := 'piechart';
    wtTable: Result := 'table';
    wtHeatmap: Result := 'heatmap';
    wtLogList: Result := 'logs';
    wtAlertList: Result := 'alertlist';
  else
    Result := 'unknown';
  end;
end;

function TDashboardExporter.SeriesDataToJSON(ASeries: TWidgetSeries): TJSONArray;
var
  Point: TWidgetDataPoint;
  PointArr: TJSONArray;
begin
  Result := TJSONArray.Create;
  for Point in ASeries.Data do
  begin
    PointArr := TJSONArray.Create;
    PointArr.AddElement(TJSONNumber.Create(DateTimeToUnix(Point.Timestamp, False) * 1000));
    PointArr.AddElement(TJSONNumber.Create(Point.Value));
    Result.AddElement(PointArr);
  end;
end;

function TDashboardExporter.ToJSON: TJSONObject;
var
  PanelsArr: TJSONArray;
  Panel: TDashboardPanel;
  PanelObj: TJSONObject;
  WidgetsArr: TJSONArray;
  Widget: TDashboardWidget;
  TagsArr: TJSONArray;
  Tag: string;
  TimeObj: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FDashboard.Id);
  Result.AddPair('title', FDashboard.Title);
  Result.AddPair('description', FDashboard.Description);
  Result.AddPair('refreshInterval', TJSONNumber.Create(FDashboard.RefreshIntervalSec));
  
  // Time range
  TimeObj := TJSONObject.Create;
  if FDashboard.TimeRange.RelativeMinutes > 0 then
    TimeObj.AddPair('relative', TJSONNumber.Create(FDashboard.TimeRange.RelativeMinutes))
  else
  begin
    TimeObj.AddPair('from', DateToISO8601(FDashboard.TimeRange.StartTime, False));
    TimeObj.AddPair('to', DateToISO8601(FDashboard.TimeRange.EndTime, False));
  end;
  Result.AddPair('timeRange', TimeObj);
  
  // Tags
  TagsArr := TJSONArray.Create;
  for Tag in FDashboard.Tags do
    TagsArr.Add(Tag);
  Result.AddPair('tags', TagsArr);
  
  // Panels
  PanelsArr := TJSONArray.Create;
  for Panel in FDashboard.Panels do
  begin
    PanelObj := TJSONObject.Create;
    PanelObj.AddPair('id', Panel.Id);
    PanelObj.AddPair('title', Panel.Title);
    PanelObj.AddPair('collapsed', TJSONBool.Create(Panel.Collapsed));
    
    WidgetsArr := TJSONArray.Create;
    for Widget in Panel.Widgets do
      WidgetsArr.AddElement(Widget.ToJSON);
    PanelObj.AddPair('widgets', WidgetsArr);
    
    PanelsArr.AddElement(PanelObj);
  end;
  Result.AddPair('panels', PanelsArr);
end;

function TDashboardExporter.WidgetToGrafanaPanel(AWidget: TDashboardWidget; AIndex: Integer): TJSONObject;
var
  TargetsArr: TJSONArray;
  Series: TWidgetSeries;
  TargetObj: TJSONObject;
  GridPos, Options, ReduceOpts: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', TJSONNumber.Create(AIndex));
  Result.AddPair('title', AWidget.Config.Title);
  Result.AddPair('type', WidgetTypeToString(AWidget.Config.WidgetType));
  
  // Grid position
  GridPos := TJSONObject.Create;
  GridPos.AddPair('x', TJSONNumber.Create((AIndex mod 2) * 12));
  GridPos.AddPair('y', TJSONNumber.Create((AIndex div 2) * AWidget.Config.Height));
  GridPos.AddPair('w', TJSONNumber.Create(AWidget.Config.Width));
  GridPos.AddPair('h', TJSONNumber.Create(AWidget.Config.Height));
  Result.AddPair('gridPos', GridPos);
  
  // Targets (data queries - placeholder)
  TargetsArr := TJSONArray.Create;
  for Series in AWidget.Series do
  begin
    TargetObj := TJSONObject.Create;
    TargetObj.AddPair('refId', Series.Name);
    TargetObj.AddPair('expr', ''); // Would be filled with actual query
    TargetsArr.AddElement(TargetObj);
  end;
  Result.AddPair('targets', TargetsArr);
  
  // Options based on type
  Options := TJSONObject.Create;
  case AWidget.Config.WidgetType of
    wtCounter, wtGauge:
    begin
      ReduceOpts := TJSONObject.Create;
      ReduceOpts.AddPair('values', TJSONBool.Create(False));
      ReduceOpts.AddPair('calcs', TJSONArray.Create.Add('lastNotNull'));
      ReduceOpts.AddPair('fields', '');
      Options.AddPair('reduceOptions', ReduceOpts);
    end;
  end;
  Result.AddPair('options', Options);
end;

function TDashboardExporter.ToGrafanaJSON: TJSONObject;
var
  PanelsArr, TagsArr: TJSONArray;
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  PanelIndex: Integer;
  TimeObj, RowPanel: TJSONObject;
  Tag: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('uid', FDashboard.Id);
  Result.AddPair('title', FDashboard.Title);
  Result.AddPair('description', FDashboard.Description);
  Result.AddPair('schemaVersion', TJSONNumber.Create(39));
  Result.AddPair('version', TJSONNumber.Create(1));  // Time range
  TimeObj := TJSONObject.Create;
  if FDashboard.TimeRange.RelativeMinutes > 0 then
  begin
    TimeObj.AddPair('from', Format('now-%dm', [FDashboard.TimeRange.RelativeMinutes]));
    TimeObj.AddPair('to', 'now');
  end
  else
  begin
    TimeObj.AddPair('from', DateToISO8601(FDashboard.TimeRange.StartTime, False));
    TimeObj.AddPair('to', DateToISO8601(FDashboard.TimeRange.EndTime, False));
  end;
  Result.AddPair('time', TimeObj);
  
  // Refresh
  if FDashboard.RefreshIntervalSec > 0 then
    Result.AddPair('refresh', Format('%ds', [FDashboard.RefreshIntervalSec]));
  
  // Panels
  PanelsArr := TJSONArray.Create;
  PanelIndex := 0;
  for Panel in FDashboard.Panels do
  begin
    // Add row panel
    RowPanel := TJSONObject.Create;
    RowPanel.AddPair('id', TJSONNumber.Create(PanelIndex));
    RowPanel.AddPair('type', 'row');
    RowPanel.AddPair('title', Panel.Title);
    RowPanel.AddPair('collapsed', TJSONBool.Create(Panel.Collapsed));
    PanelsArr.AddElement(RowPanel);
    Inc(PanelIndex);
    
    // Add widget panels
    for Widget in Panel.Widgets do
    begin
      PanelsArr.AddElement(WidgetToGrafanaPanel(Widget, PanelIndex));
      Inc(PanelIndex);
    end;
  end;
  Result.AddPair('panels', PanelsArr);
  
  // Tags
  TagsArr := TJSONArray.Create;
  for Tag in FDashboard.Tags do
    TagsArr.Add(Tag);
  Result.AddPair('tags', TagsArr);
end;

function TDashboardExporter.EscapeHTML(const AValue: string): string;
begin
  Result := AValue;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function TDashboardExporter.ToHTML(const ATitle: string): string;
var
  SB: TStringBuilder;
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Series: TWidgetSeries;
  Point: TWidgetDataPoint;
  Row: TArray<string>;
  H, S: string;
  Title: string;
begin
  if ATitle <> '' then
    Title := ATitle
  else
    Title := FDashboard.Title;
  
  SB := TStringBuilder.Create;
  try
    // HTML Header
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html lang="en">');
    SB.AppendLine('<head>');
    SB.AppendLine('  <meta charset="UTF-8">');
    SB.AppendLine('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    SB.AppendFormat('  <title>%s</title>', [EscapeHTML(Title)]).AppendLine;
    SB.AppendLine('  <style>');
    SB.AppendLine('    * { box-sizing: border-box; margin: 0; padding: 0; }');
    SB.AppendLine('    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #1a1a2e; color: #eee; padding: 20px; }');
    SB.AppendLine('    .dashboard { max-width: 1400px; margin: 0 auto; }');
    SB.AppendLine('    .header { margin-bottom: 24px; padding-bottom: 16px; border-bottom: 1px solid #333; }');
    SB.AppendLine('    .header h1 { font-size: 24px; font-weight: 500; }');
    SB.AppendLine('    .header p { color: #888; margin-top: 4px; }');
    SB.AppendLine('    .panel { margin-bottom: 24px; }');
    SB.AppendLine('    .panel-title { font-size: 16px; font-weight: 500; margin-bottom: 12px; padding: 8px 0; border-bottom: 1px solid #333; }');
    SB.AppendLine('    .widgets { display: grid; grid-template-columns: repeat(12, 1fr); gap: 16px; }');
    SB.AppendLine('    .widget { background: #16213e; border-radius: 8px; padding: 16px; }');
    SB.AppendLine('    .widget-title { font-size: 14px; color: #888; margin-bottom: 8px; }');
    SB.AppendLine('    .widget-value { font-size: 32px; font-weight: 600; color: #00d4aa; }');
    SB.AppendLine('    .widget-unit { font-size: 14px; color: #666; margin-left: 4px; }');
    SB.AppendLine('    table { width: 100%; border-collapse: collapse; }');
    SB.AppendLine('    th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #333; }');
    SB.AppendLine('    th { background: #0f3460; font-weight: 500; }');
    SB.AppendLine('    tr:hover { background: #1a3a5c; }');
    SB.AppendLine('    .time-range { color: #888; font-size: 12px; }');
    SB.AppendLine('  </style>');
    SB.AppendLine('</head>');
    SB.AppendLine('<body>');
    SB.AppendLine('  <div class="dashboard">');
    
    // Header
    SB.AppendLine('    <div class="header">');
    SB.AppendFormat('      <h1>%s</h1>', [EscapeHTML(Title)]).AppendLine;
    if FDashboard.Description <> '' then
      SB.AppendFormat('      <p>%s</p>', [EscapeHTML(FDashboard.Description)]).AppendLine;
    SB.AppendFormat('      <p class="time-range">Time Range: %s</p>', [EscapeHTML(FDashboard.TimeRange.ToString)]).AppendLine;
    SB.AppendLine('    </div>');
    
    // Panels
    for Panel in FDashboard.Panels do
    begin
      SB.AppendLine('    <div class="panel">');
      SB.AppendFormat('      <div class="panel-title">%s</div>', [EscapeHTML(Panel.Title)]).AppendLine;
      SB.AppendLine('      <div class="widgets">');
      
      for Widget in Panel.Widgets do
      begin
        SB.AppendFormat('        <div class="widget" style="grid-column: span %d;">',
          [Widget.Config.Width]).AppendLine;
        SB.AppendFormat('          <div class="widget-title">%s</div>',
          [EscapeHTML(Widget.Config.Title)]).AppendLine;
        
        case Widget.Config.WidgetType of
          wtCounter, wtGauge:
          begin
            SB.AppendFormat('          <div class="widget-value">%.0f<span class="widget-unit">%s</span></div>',
              [Widget.Value, EscapeHTML(Widget.Unit_)]).AppendLine;
          end;
          wtTable:
          begin
            SB.AppendLine('          <table>');
            if Length(Widget.FTableHeaders) > 0 then
            begin
              SB.Append('            <tr>');
              for H in Widget.FTableHeaders do
                SB.AppendFormat('<th>%s</th>', [EscapeHTML(H)]);
              SB.AppendLine('</tr>');
            end;
            for Row in Widget.FTableRows do
            begin
              SB.Append('            <tr>');
              for S in Row do
                SB.AppendFormat('<td>%s</td>', [EscapeHTML(S)]);
              SB.AppendLine('</tr>');
            end;
            SB.AppendLine('          </table>');
          end;
          wtLineChart, wtBarChart:
          begin
            // Simplified chart representation
            SB.AppendLine('          <div class="chart-placeholder">');
            for Series in Widget.Series do
            begin
              SB.AppendFormat('            <div><strong>%s</strong>: ', [EscapeHTML(Series.Name)]);
              if Series.Data.Count > 0 then
                SB.AppendFormat('%.2f (latest)', [Series.Data.Last.Value]);
              SB.AppendLine('</div>');
            end;
            SB.AppendLine('          </div>');
          end;
        end;
        
        SB.AppendLine('        </div>');
      end;
      
      SB.AppendLine('      </div>');
      SB.AppendLine('    </div>');
    end;
    
    SB.AppendLine('  </div>');
    SB.AppendFormat('  <script>console.log("Dashboard: %s");</script>', [EscapeHTML(FDashboard.Id)]).AppendLine;
    SB.AppendLine('</body>');
    SB.AppendLine('</html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TDashboardExporter.EscapeCSV(const AValue: string): string;
begin
  if (Pos(',', AValue) > 0) or (Pos('"', AValue) > 0) or (Pos(#13, AValue) > 0) or (Pos(#10, AValue) > 0) then
    Result := '"' + StringReplace(AValue, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := AValue;
end;

function TDashboardExporter.GenerateCSVForWidget(AWidget: TDashboardWidget): string;
var
  SB: TStringBuilder;
  Series: TWidgetSeries;
  Point: TWidgetDataPoint;
  Row: TArray<string>;
  H: string;
  I: Integer;
begin
  SB := TStringBuilder.Create;
  try
    // Widget header
    SB.AppendFormat('# Widget: %s', [AWidget.Config.Title]).AppendLine;
    SB.AppendFormat('# Type: %s', [TRttiEnumerationType.GetName(AWidget.Config.WidgetType)]).AppendLine;
    SB.AppendLine;
    
    case AWidget.Config.WidgetType of
      wtCounter, wtGauge:
      begin
        SB.AppendLine('Value,Unit');
        SB.AppendFormat('%g,%s', [AWidget.Value, EscapeCSV(AWidget.Unit_)]).AppendLine;
      end;
      
      wtLineChart, wtBarChart:
      begin
        // Output each series
        for Series in AWidget.Series do
        begin
          SB.AppendFormat('# Series: %s', [Series.Name]).AppendLine;
          SB.AppendLine('Timestamp,Value');
          for Point in Series.Data do
            SB.AppendFormat('%s,%g', [DateToISO8601(Point.Timestamp, False), Point.Value]).AppendLine;
          SB.AppendLine;
        end;
      end;
      
      wtTable:
      begin
        // Headers
        for I := 0 to High(AWidget.FTableHeaders) do
        begin
          if I > 0 then SB.Append(',');
          SB.Append(EscapeCSV(AWidget.FTableHeaders[I]));
        end;
        SB.AppendLine;
        
        // Rows
        for Row in AWidget.FTableRows do
        begin
          for I := 0 to High(Row) do
          begin
            if I > 0 then SB.Append(',');
            SB.Append(EscapeCSV(Row[I]));
          end;
          SB.AppendLine;
        end;
      end;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TDashboardExporter.ToCSV: string;
var
  SB: TStringBuilder;
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendFormat('# Dashboard: %s', [FDashboard.Title]).AppendLine;
    SB.AppendFormat('# Time Range: %s', [FDashboard.TimeRange.ToString]).AppendLine;
    SB.AppendLine;
    
    for Panel in FDashboard.Panels do
    begin
      SB.AppendFormat('## Panel: %s', [Panel.Title]).AppendLine;
      SB.AppendLine;
      
      for Widget in Panel.Widgets do
      begin
        SB.Append(GenerateCSVForWidget(Widget));
        SB.AppendLine;
      end;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TDashboardExporter.WidgetToCSV(const AWidgetId: string): string;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
begin
  Result := '';
  for Panel in FDashboard.Panels do
    for Widget in Panel.Widgets do
      if Widget.Id = AWidgetId then
      begin
        Result := GenerateCSVForWidget(Widget);
        Exit;
      end;
end;

{ TDashboardBuilder }

constructor TDashboardBuilder.Create(AAnalyzer: TLogAnalyzer);
begin
  inherited Create;
  FAnalyzer := AAnalyzer;
  FTimeRange := TDashboardTimeRange.Last(60);
end;

function TDashboardBuilder.SetTimeRange(const ARange: TDashboardTimeRange): TDashboardBuilder;
begin
  FTimeRange := ARange;
  Result := Self;
end;

function TDashboardBuilder.BuildOverviewDashboard: TDashboard;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Stats: TLogStats;
  TimeSeries: TLogTimeSeries;
  Series: TWidgetSeries;
  Point: TTimeSeriesPoint;
  CountByLevel: TArray<TCountResult>;
  CR: TCountResult;
  WConfig: TWidgetConfig;
begin
  Stats := FAnalyzer.GetStats;
  
  Result := TDashboard.Create('log-overview', 'Log Overview Dashboard');
  Result.Description := 'Overview of log metrics and statistics';
  Result.TimeRange := FTimeRange;
  Result.Tags := ['logs', 'overview'];
  
  // Stats panel
  Panel := Result.AddPanel('stats', 'Statistics');
  
  // Total logs counter
  Widget := Panel.AddWidget('total-logs', wtCounter);
  WConfig := Widget.Config;
  WConfig.Title := 'Total Logs';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.TotalCount, 'logs');
  
  // Error count
  Widget := Panel.AddWidget('error-count', wtCounter);
  WConfig := Widget.Config;
  WConfig.Title := 'Errors';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.ErrorCount + Stats.FatalCount, 'errors');
  
  // Error rate
  Widget := Panel.AddWidget('error-rate', wtGauge);
  WConfig := Widget.Config;
  WConfig.Title := 'Error Rate';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.ErrorRate * 100, '%');
  
  // Unique sources
  Widget := Panel.AddWidget('unique-sources', wtCounter);
  WConfig := Widget.Config;
  WConfig.Title := 'Unique Sources';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.UniqueSourceCount, 'sources');
  
  // Time series panel
  Panel := Result.AddPanel('timeseries', 'Log Volume Over Time');
  
  Widget := Panel.AddWidget('log-volume', wtLineChart);
  WConfig := Widget.Config;
  WConfig.Title := 'Logs per Minute';
  WConfig.Width := 12;
  Widget.Config := WConfig;
  
  TimeSeries := FAnalyzer.CountByTime(tbMinute);
  Series := Widget.AddSeries('All Logs');
  for Point in TimeSeries.Points do
    Series.AddPoint(Point.Timestamp, Point.Value);
  TimeSeries.Free;
  
  // Distribution panel
  Panel := Result.AddPanel('distribution', 'Log Distribution');
  
  Widget := Panel.AddWidget('by-level', wtTable);
  WConfig := Widget.Config;
  WConfig.Title := 'Logs by Level';
  WConfig.Width := 6;
  Widget.Config := WConfig;
  Widget.SetTableHeaders(['Level', 'Count', 'Percentage']);
  
  CountByLevel := FAnalyzer.CountByLevel;
  for CR in CountByLevel do
    Widget.AddTableRow([CR.Category, IntToStr(CR.Count),
      Format('%.1f%%', [CR.Percentage])]);
end;

function TDashboardBuilder.BuildErrorDashboard: TDashboard;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  Stats: TLogStats;
  TopErrors: TArray<TTopError>;
  TE: TTopError;
  Series: TWidgetSeries;
  TimeSeries: TLogTimeSeries;
  Point: TTimeSeriesPoint;
  WConfig: TWidgetConfig;
begin
  Stats := FAnalyzer.GetStats;
  
  Result := TDashboard.Create('error-analysis', 'Error Analysis Dashboard');
  Result.Description := 'Detailed error analysis and trends';
  Result.TimeRange := FTimeRange;
  Result.Tags := ['logs', 'errors', 'analysis'];
  
  // Error stats panel
  Panel := Result.AddPanel('error-stats', 'Error Statistics');
  
  Widget := Panel.AddWidget('total-errors', wtCounter);
  WConfig := Widget.Config;
  WConfig.Title := 'Total Errors';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.ErrorCount + Stats.FatalCount, 'errors');
  
  Widget := Panel.AddWidget('error-rate', wtGauge);
  WConfig := Widget.Config;
  WConfig.Title := 'Error Rate';
  Widget.Config := WConfig;
  Widget.SetValue(Stats.ErrorRate * 100, '%');
  
  // Error trend
  Panel := Result.AddPanel('error-trend', 'Error Trend');
  
  Widget := Panel.AddWidget('error-timeline', wtLineChart);
  WConfig := Widget.Config;
  WConfig.Title := 'Errors Over Time';
  WConfig.Width := 12;
  Widget.Config := WConfig;
  
  TimeSeries := FAnalyzer.ErrorRateByTime(tbMinute);
  Series := Widget.AddSeries('Error Rate');
  Series.Color := '#ff4444';
  for Point in TimeSeries.Points do
    Series.AddPoint(Point.Timestamp, Point.Value);
  TimeSeries.Free;
  
  // Top errors
  Panel := Result.AddPanel('top-errors', 'Top Errors');
  
  Widget := Panel.AddWidget('error-table', wtTable);
  WConfig := Widget.Config;
  WConfig.Title := 'Most Frequent Errors';
  WConfig.Width := 12;
  Widget.Config := WConfig;
  Widget.SetTableHeaders(['Error Message', 'Count']);
  
  TopErrors := FAnalyzer.TopErrors(20);
  for TE in TopErrors do
    Widget.AddTableRow([TE.Message, IntToStr(TE.Count)]);
end;

function TDashboardBuilder.BuildPerformanceDashboard: TDashboard;
var
  Panel: TDashboardPanel;
  Widget: TDashboardWidget;
  CountBySource: TArray<TCountResult>;
  CR: TCountResult;
  Series: TWidgetSeries;
  TimeSeries: TLogTimeSeries;
  Point: TTimeSeriesPoint;
  WConfig: TWidgetConfig;
begin
  Result := TDashboard.Create('performance', 'Performance Dashboard');
  Result.Description := 'System performance metrics from logs';
  Result.TimeRange := FTimeRange;
  Result.Tags := ['logs', 'performance'];
  
  // Volume panel
  Panel := Result.AddPanel('volume', 'Log Volume');
  
  Widget := Panel.AddWidget('volume-chart', wtLineChart);
  WConfig := Widget.Config;
  WConfig.Title := 'Log Volume per Minute';
  WConfig.Width := 12;
  Widget.Config := WConfig;
  
  TimeSeries := FAnalyzer.CountByTime(tbMinute);
  Series := Widget.AddSeries('Volume');
  for Point in TimeSeries.Points do
    Series.AddPoint(Point.Timestamp, Point.Value);
  TimeSeries.Free;
  
  // By source
  Panel := Result.AddPanel('sources', 'By Source');
  
  Widget := Panel.AddWidget('source-table', wtTable);
  WConfig := Widget.Config;
  WConfig.Title := 'Logs by Source';
  WConfig.Width := 12;
  Widget.Config := WConfig;
  Widget.SetTableHeaders(['Source', 'Count']);
  
  CountBySource := FAnalyzer.CountBySource;
  for CR in CountBySource do
    Widget.AddTableRow([CR.Category, IntToStr(CR.Count)]);
end;

end.
