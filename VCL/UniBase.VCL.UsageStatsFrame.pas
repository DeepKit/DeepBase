{ ============================================================================
  UniBase.VCL.UsageStatsFrame - 用量统计 Frame
  
  Version: 1.0
  Description: Usage statistics with summary cards, trend chart, model breakdown
               and recent API call records.
  ============================================================================ }

unit UniBase.VCL.UsageStatsFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.DateUtils,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vcl.ComCtrls,
  UniBase.AipexBase.Client;

type
  TUsageStatsFrame = class(TFrame)
  private
    FPnlMain: TPanel;
    
    // Header with date range
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FDtpStartDate: TDateTimePicker;
    FLblTo: TLabel;
    FDtpEndDate: TDateTimePicker;
    FBtnRefresh: TButton;
    
    // Summary cards
    FPnlSummary: TPanel;
    FPnlCardCalls: TPanel;
    FLblCardCallsTitle: TLabel;
    FLblCardCallsValue: TLabel;
    FLblCardCallsChange: TLabel;
    
    FPnlCardInputTokens: TPanel;
    FLblCardInputTitle: TLabel;
    FLblCardInputValue: TLabel;
    FLblCardInputChange: TLabel;
    
    FPnlCardOutputTokens: TPanel;
    FLblCardOutputTitle: TLabel;
    FLblCardOutputValue: TLabel;
    FLblCardOutputChange: TLabel;
    
    FPnlCardCost: TPanel;
    FLblCardCostTitle: TLabel;
    FLblCardCostValue: TLabel;
    
    // Trend chart area (simplified - using paintbox)
    FPnlChart: TPanel;
    FLblChartTitle: TLabel;
    FPbxChart: TPaintBox;
    FChartData: TAipexUsageDataPoints;
    
    // Tab selector for chart
    FBtnChartDay: TButton;
    FBtnChartWeek: TButton;
    FBtnChartMonth: TButton;
    FChartGroupBy: string;
    
    // Model usage breakdown
    FPnlModels: TPanel;
    FLblModelsTitle: TLabel;
    FLvModels: TListView;
    
    // Recent calls
    FPnlCalls: TPanel;
    FLblCallsTitle: TLabel;
    FLblCallsMore: TLabel;
    FLvCalls: TListView;
    
    FApiClient: TAipexBaseClient;
    FUsageSummary: TAipexUsageSummary;
    FModelUsages: TAipexModelUsages;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleRefreshClick(Sender: TObject);
    procedure HandleChartGroupClick(Sender: TObject);
    procedure HandleChartPaint(Sender: TObject);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure CreateSummaryCard(var PnlCard: TPanel; var LblTitle, LblValue, LblChange: TLabel;
      const ATitle: string; ALeft: Integer);
    function FormatNumber(Value: Int64): string;
    procedure DrawBarChart(Canvas: TCanvas; const Data: TAipexUsageDataPoints;
      ARect: TRect);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure LoadSummary;
    procedure LoadTrendData;
    procedure LoadModelUsage;
    procedure LoadRecentCalls;
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
  end;

implementation

uses
  Winapi.Windows, System.Math;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_BG = $FAF7F5;
  COLOR_CARD = $FFFFFF;
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_SUCCESS = $50AF4C;
  COLOR_ERROR = $5252FF;
  COLOR_CHART_BAR = $EAEA66;
  COLOR_CHART_GRID = $F5F5F5;

{ TUsageStatsFrame }

constructor TUsageStatsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 800;
  Height := 600;
  Color := COLOR_BG;
  
  FChartGroupBy := 'day';
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
  
  // Set default date range
  FDtpEndDate.Date := Date;
  FDtpStartDate.Date := Date - 14;
end;

destructor TUsageStatsFrame.Destroy;
begin
  inherited;
end;

procedure TUsageStatsFrame.CreateSummaryCard(var PnlCard: TPanel; 
  var LblTitle, LblValue, LblChange: TLabel; const ATitle: string; ALeft: Integer);
begin
  PnlCard := TPanel.Create(Self);
  PnlCard.Parent := FPnlSummary;
  PnlCard.BevelOuter := bvNone;
  PnlCard.Color := COLOR_CARD;
  
  LblTitle := TLabel.Create(Self);
  LblTitle.Parent := PnlCard;
  LblTitle.Caption := ATitle;
  LblTitle.Font.Color := COLOR_TEXT_GRAY;
  LblTitle.Font.Size := 9;
  
  LblValue := TLabel.Create(Self);
  LblValue.Parent := PnlCard;
  LblValue.Caption := '0';
  LblValue.Font.Size := 20;
  LblValue.Font.Style := [fsBold];
  
  LblChange := TLabel.Create(Self);
  LblChange.Parent := PnlCard;
  LblChange.Caption := '';
  LblChange.Font.Size := 9;
end;

procedure TUsageStatsFrame.CreateControls;
begin
  FPnlMain := TPanel.Create(Self);
  FPnlMain.Parent := Self;
  FPnlMain.Align := alClient;
  FPnlMain.BevelOuter := bvNone;
  FPnlMain.Color := COLOR_BG;
  
  // Header
  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := FPnlMain;
  FPnlHeader.BevelOuter := bvNone;
  FPnlHeader.Color := COLOR_CARD;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlHeader;
  FLblTitle.Caption := '用量统计';
  FLblTitle.Font.Size := 14;
  FLblTitle.Font.Style := [fsBold];
  
  FDtpStartDate := TDateTimePicker.Create(Self);
  FDtpStartDate.Parent := FPnlHeader;
  FDtpStartDate.Kind := dtkDate;
  
  FLblTo := TLabel.Create(Self);
  FLblTo.Parent := FPnlHeader;
  FLblTo.Caption := '至';
  
  FDtpEndDate := TDateTimePicker.Create(Self);
  FDtpEndDate.Parent := FPnlHeader;
  FDtpEndDate.Kind := dtkDate;
  
  FBtnRefresh := TButton.Create(Self);
  FBtnRefresh.Parent := FPnlHeader;
  FBtnRefresh.Caption := '查询';
  FBtnRefresh.OnClick := HandleRefreshClick;
  
  // Summary cards container
  FPnlSummary := TPanel.Create(Self);
  FPnlSummary.Parent := FPnlMain;
  FPnlSummary.BevelOuter := bvNone;
  FPnlSummary.Color := COLOR_BG;
  
  CreateSummaryCard(FPnlCardCalls, FLblCardCallsTitle, FLblCardCallsValue, 
    FLblCardCallsChange, '总调用次数', 0);
  CreateSummaryCard(FPnlCardInputTokens, FLblCardInputTitle, FLblCardInputValue,
    FLblCardInputChange, '输入Token', 0);
  CreateSummaryCard(FPnlCardOutputTokens, FLblCardOutputTitle, FLblCardOutputValue,
    FLblCardOutputChange, '输出Token', 0);
  CreateSummaryCard(FPnlCardCost, FLblCardCostTitle, FLblCardCostValue,
    FLblCardCallsChange, '总消费', 0); // Reuse FLblCardCallsChange as placeholder
  FLblCardCostTitle.Caption := '总消费';
  
  // Chart panel
  FPnlChart := TPanel.Create(Self);
  FPnlChart.Parent := FPnlMain;
  FPnlChart.BevelOuter := bvNone;
  FPnlChart.Color := COLOR_CARD;
  
  FLblChartTitle := TLabel.Create(Self);
  FLblChartTitle.Parent := FPnlChart;
  FLblChartTitle.Caption := '调用趋势';
  FLblChartTitle.Font.Size := 12;
  FLblChartTitle.Font.Style := [fsBold];
  
  FBtnChartDay := TButton.Create(Self);
  FBtnChartDay.Parent := FPnlChart;
  FBtnChartDay.Caption := '日';
  FBtnChartDay.Tag := 1;
  FBtnChartDay.OnClick := HandleChartGroupClick;
  
  FBtnChartWeek := TButton.Create(Self);
  FBtnChartWeek.Parent := FPnlChart;
  FBtnChartWeek.Caption := '周';
  FBtnChartWeek.Tag := 2;
  FBtnChartWeek.OnClick := HandleChartGroupClick;
  
  FBtnChartMonth := TButton.Create(Self);
  FBtnChartMonth.Parent := FPnlChart;
  FBtnChartMonth.Caption := '月';
  FBtnChartMonth.Tag := 3;
  FBtnChartMonth.OnClick := HandleChartGroupClick;
  
  FPbxChart := TPaintBox.Create(Self);
  FPbxChart.Parent := FPnlChart;
  FPbxChart.OnPaint := HandleChartPaint;
  
  // Model usage panel
  FPnlModels := TPanel.Create(Self);
  FPnlModels.Parent := FPnlMain;
  FPnlModels.BevelOuter := bvNone;
  FPnlModels.Color := COLOR_CARD;
  
  FLblModelsTitle := TLabel.Create(Self);
  FLblModelsTitle.Parent := FPnlModels;
  FLblModelsTitle.Caption := '模型使用分布';
  FLblModelsTitle.Font.Size := 12;
  FLblModelsTitle.Font.Style := [fsBold];
  
  FLvModels := TListView.Create(Self);
  FLvModels.Parent := FPnlModels;
  FLvModels.ViewStyle := vsReport;
  FLvModels.RowSelect := True;
  FLvModels.ReadOnly := True;
  with FLvModels.Columns.Add do begin Caption := '模型'; Width := 100; end;
  with FLvModels.Columns.Add do begin Caption := '调用次数'; Width := 70; end;
  with FLvModels.Columns.Add do begin Caption := '占比'; Width := 60; end;
  
  // Recent calls panel
  FPnlCalls := TPanel.Create(Self);
  FPnlCalls.Parent := FPnlMain;
  FPnlCalls.BevelOuter := bvNone;
  FPnlCalls.Color := COLOR_CARD;
  
  FLblCallsTitle := TLabel.Create(Self);
  FLblCallsTitle.Parent := FPnlCalls;
  FLblCallsTitle.Caption := '最近调用';
  FLblCallsTitle.Font.Size := 12;
  FLblCallsTitle.Font.Style := [fsBold];
  
  FLblCallsMore := TLabel.Create(Self);
  FLblCallsMore.Parent := FPnlCalls;
  FLblCallsMore.Caption := '查看详情';
  FLblCallsMore.Font.Color := COLOR_PRIMARY;
  FLblCallsMore.Cursor := crHandPoint;
  
  FLvCalls := TListView.Create(Self);
  FLvCalls.Parent := FPnlCalls;
  FLvCalls.ViewStyle := vsReport;
  FLvCalls.RowSelect := True;
  FLvCalls.ReadOnly := True;
  with FLvCalls.Columns.Add do begin Caption := '时间'; Width := 80; end;
  with FLvCalls.Columns.Add do begin Caption := '模型'; Width := 80; end;
  with FLvCalls.Columns.Add do begin Caption := '输入'; Width := 60; end;
  with FLvCalls.Columns.Add do begin Caption := '输出'; Width := 60; end;
  with FLvCalls.Columns.Add do begin Caption := '耗时'; Width := 50; end;
  with FLvCalls.Columns.Add do begin Caption := '费用'; Width := 60; end;
end;

procedure TUsageStatsFrame.LayoutControls;
var
  CardWidth: Integer;
begin
  // Header
  FPnlHeader.SetBounds(0, 0, Width, 50);
  FLblTitle.SetBounds(20, 15, 100, 24);
  FDtpStartDate.SetBounds(Width - 400, 12, 110, 24);
  FLblTo.SetBounds(Width - 282, 15, 20, 20);
  FDtpEndDate.SetBounds(Width - 260, 12, 110, 24);
  FBtnRefresh.SetBounds(Width - 140, 12, 60, 24);
  
  // Summary cards
  FPnlSummary.SetBounds(0, 60, Width, 90);
  CardWidth := (Width - 60) div 4;
  FPnlCardCalls.SetBounds(10, 0, CardWidth, 80);
  FPnlCardInputTokens.SetBounds(20 + CardWidth, 0, CardWidth, 80);
  FPnlCardOutputTokens.SetBounds(30 + CardWidth * 2, 0, CardWidth, 80);
  FPnlCardCost.SetBounds(40 + CardWidth * 3, 0, CardWidth, 80);
  
  // Card internals
  FLblCardCallsTitle.SetBounds(15, 15, 100, 16);
  FLblCardCallsValue.SetBounds(15, 35, 120, 30);
  FLblCardCallsChange.SetBounds(CardWidth - 50, 40, 40, 16);
  
  FLblCardInputTitle.SetBounds(15, 15, 100, 16);
  FLblCardInputValue.SetBounds(15, 35, 120, 30);
  FLblCardInputChange.SetBounds(CardWidth - 50, 40, 40, 16);
  
  FLblCardOutputTitle.SetBounds(15, 15, 100, 16);
  FLblCardOutputValue.SetBounds(15, 35, 120, 30);
  FLblCardOutputChange.SetBounds(CardWidth - 50, 40, 40, 16);
  
  FLblCardCostTitle.SetBounds(15, 15, 100, 16);
  FLblCardCostValue.SetBounds(15, 35, 120, 30);
  
  // Chart panel
  FPnlChart.SetBounds(10, 160, Width - 260, 220);
  FLblChartTitle.SetBounds(15, 15, 100, 20);
  FBtnChartDay.SetBounds(120, 12, 40, 24);
  FBtnChartWeek.SetBounds(165, 12, 40, 24);
  FBtnChartMonth.SetBounds(210, 12, 40, 24);
  FPbxChart.SetBounds(15, 45, FPnlChart.Width - 30, 165);
  
  // Model usage panel
  FPnlModels.SetBounds(Width - 240, 160, 230, 220);
  FLblModelsTitle.SetBounds(15, 15, 150, 20);
  FLvModels.SetBounds(10, 45, 210, 165);
  
  // Recent calls panel
  FPnlCalls.SetBounds(10, 390, Width - 20, 200);
  FLblCallsTitle.SetBounds(15, 15, 100, 20);
  FLblCallsMore.SetBounds(Width - 100, 15, 60, 20);
  FLvCalls.SetBounds(10, 45, Width - 40, 145);
end;

procedure TUsageStatsFrame.ApplyStyle;
begin
  FPnlCardCalls.Color := COLOR_CARD;
  FPnlCardInputTokens.Color := COLOR_CARD;
  FPnlCardOutputTokens.Color := COLOR_CARD;
  FPnlCardCost.Color := COLOR_CARD;
  
  FBtnChartDay.Font.Size := 9;
  FBtnChartWeek.Font.Size := 9;
  FBtnChartMonth.Font.Size := 9;
end;

procedure TUsageStatsFrame.HandleRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TUsageStatsFrame.HandleChartGroupClick(Sender: TObject);
begin
  case TButton(Sender).Tag of
    1: FChartGroupBy := 'day';
    2: FChartGroupBy := 'week';
    3: FChartGroupBy := 'month';
  end;
  LoadTrendData;
end;

procedure TUsageStatsFrame.HandleChartPaint(Sender: TObject);
begin
  DrawBarChart(FPbxChart.Canvas, FChartData, FPbxChart.ClientRect);
end;

procedure TUsageStatsFrame.DrawBarChart(Canvas: TCanvas; 
  const Data: TAipexUsageDataPoints; ARect: TRect);
var
  I, BarWidth, BarLeft, BarHeight: Integer;
  MaxCalls: Int64;
  ChartHeight, ChartWidth: Integer;
begin
  // Clear background
  Canvas.Brush.Color := COLOR_CARD;
  Canvas.FillRect(ARect);
  
  if Length(Data) = 0 then
  begin
    Canvas.Font.Color := COLOR_TEXT_GRAY;
    Canvas.TextOut(ARect.Width div 2 - 30, ARect.Height div 2, '暂无数据');
    Exit;
  end;
  
  // Draw grid lines
  Canvas.Pen.Color := COLOR_CHART_GRID;
  ChartHeight := ARect.Height - 30;
  ChartWidth := ARect.Width - 40;
  
  for I := 0 to 4 do
  begin
    Canvas.MoveTo(40, I * (ChartHeight div 4));
    Canvas.LineTo(ARect.Width, I * (ChartHeight div 4));
  end;
  
  // Find max value
  MaxCalls := 1;
  for I := 0 to Length(Data) - 1 do
    if Data[I].Calls > MaxCalls then
      MaxCalls := Data[I].Calls;
  
  // Draw bars
  BarWidth := Max(10, (ChartWidth - 20) div Length(Data) - 5);
  Canvas.Brush.Color := COLOR_CHART_BAR;
  
  for I := 0 to Length(Data) - 1 do
  begin
    BarLeft := 45 + I * (BarWidth + 5);
    BarHeight := Round((Data[I].Calls / MaxCalls) * (ChartHeight - 10));
    Canvas.FillRect(Rect(BarLeft, ChartHeight - BarHeight, 
                         BarLeft + BarWidth, ChartHeight));
    
    // Draw date label
    Canvas.Font.Color := COLOR_TEXT_GRAY;
    Canvas.Font.Size := 7;
    Canvas.TextOut(BarLeft, ChartHeight + 5, FormatDateTime('mm/dd', Data[I].Date));
  end;
end;

function TUsageStatsFrame.FormatNumber(Value: Int64): string;
begin
  if Value >= 1000000 then
    Result := FormatFloat('#,##0.0M', Value / 1000000)
  else if Value >= 1000 then
    Result := FormatFloat('#,##0.0K', Value / 1000)
  else
    Result := IntToStr(Value);
end;

procedure TUsageStatsFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
  if Assigned(FApiClient) then
    RefreshData;
end;

procedure TUsageStatsFrame.LoadSummary;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FUsageSummary := FApiClient.GetUsageSummary(FDtpStartDate.Date, FDtpEndDate.Date);
    
    FLblCardCallsValue.Caption := FormatNumber(FUsageSummary.TotalCalls);
    FLblCardInputValue.Caption := FormatNumber(FUsageSummary.InputTokens);
    FLblCardOutputValue.Caption := FormatNumber(FUsageSummary.OutputTokens);
    FLblCardCostValue.Caption := '¥' + FormatFloat('#,##0.00', FUsageSummary.TotalCost);
  except
    // Ignore errors
  end;
end;

procedure TUsageStatsFrame.LoadTrendData;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FChartData := FApiClient.GetUsageTrend(FDtpStartDate.Date, FDtpEndDate.Date, FChartGroupBy);
    FPbxChart.Invalidate;
  except
    SetLength(FChartData, 0);
    FPbxChart.Invalidate;
  end;
end;

procedure TUsageStatsFrame.LoadModelUsage;
var
  I: Integer;
  Item: TListItem;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FModelUsages := FApiClient.GetModelUsage(FDtpStartDate.Date, FDtpEndDate.Date);
    
    FLvModels.Items.BeginUpdate;
    try
      FLvModels.Items.Clear;
      for I := 0 to Length(FModelUsages) - 1 do
      begin
        Item := FLvModels.Items.Add;
        Item.Caption := FModelUsages[I].Model;
        Item.SubItems.Add(FormatNumber(FModelUsages[I].Calls));
        Item.SubItems.Add(FormatFloat('0.0%', FModelUsages[I].Percentage));
      end;
    finally
      FLvModels.Items.EndUpdate;
    end;
  except
    // Ignore errors
  end;
end;

procedure TUsageStatsFrame.LoadRecentCalls;
var
  Calls: TAipexApiCalls;
  I: Integer;
  Item: TListItem;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    Calls := FApiClient.GetRecentCalls(10);
    
    FLvCalls.Items.BeginUpdate;
    try
      FLvCalls.Items.Clear;
      for I := 0 to Length(Calls) - 1 do
      begin
        Item := FLvCalls.Items.Add;
        Item.Caption := FormatDateTime('hh:nn:ss', Calls[I].CreatedAt);
        Item.SubItems.Add(Calls[I].Model);
        Item.SubItems.Add(IntToStr(Calls[I].InputTokens));
        Item.SubItems.Add(IntToStr(Calls[I].OutputTokens));
        Item.SubItems.Add(FormatFloat('0.0s', Calls[I].Duration / 1000));
        Item.SubItems.Add('¥' + FormatFloat('0.00', Calls[I].Cost));
      end;
    finally
      FLvCalls.Items.EndUpdate;
    end;
  except
    // Ignore errors
  end;
end;

procedure TUsageStatsFrame.RefreshData;
begin
  LoadSummary;
  LoadTrendData;
  LoadModelUsage;
  LoadRecentCalls;
end;

end.
