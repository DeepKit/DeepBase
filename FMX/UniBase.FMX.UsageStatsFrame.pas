{ ============================================================================
  UniBase.FMX.UsageStatsFrame - FMX 用量统计 Frame
  
  Version: 1.0
  Description: Modern FMX usage statistics frame with summary cards, bar chart,
               model breakdown, and recent calls list.
  ============================================================================ }

unit UniBase.FMX.UsageStatsFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics, FMX.ListView, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.DateTimeCtrls,
  UniBase.AipexBase.Client;

type
  TFMXUsageStatsFrame = class(TFrame)
  private
    FLayoutMain: TLayout;
    // Summary cards
    FLayoutSummary: TLayout;
    FRectCalls: TRectangle;
    FLblCallsTitle: TLabel;
    FLblCallsValue: TLabel;
    FRectInputTokens: TRectangle;
    FLblInputTitle: TLabel;
    FLblInputValue: TLabel;
    FRectOutputTokens: TRectangle;
    FLblOutputTitle: TLabel;
    FLblOutputValue: TLabel;
    FRectCost: TRectangle;
    FLblCostTitle: TLabel;
    FLblCostValue: TLabel;
    // Date range
    FLayoutDateRange: TLayout;
    FLblPeriod: TLabel;
    FDateStart: TDateEdit;
    FLblTo: TLabel;
    FDateEnd: TDateEdit;
    FBtnRefresh: TButton;
    // Chart
    FLblChartTitle: TLabel;
    FPaintBoxChart: TPaintBox;
    // Model breakdown
    FLblModelTitle: TLabel;
    FListModels: TListView;
    // Recent calls
    FLblRecentTitle: TLabel;
    FListRecent: TListView;
    
    FApiClient: TAipexBaseClient;
    FUsageSummary: TAipexUsageSummary;
    FDailyUsage: TArray<TAipexDailyUsage>;
    
    procedure CreateControls;
    procedure CreateSummaryCards;
    procedure CreateDateRange;
    procedure CreateChart;
    procedure CreateModelBreakdown;
    procedure CreateRecentCalls;
    procedure HandleRefreshClick(Sender: TObject);
    procedure HandleChartPaint(Sender: TObject; Canvas: TCanvas; const ARect: TRectF);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure SetUsageSummary(const Value: TAipexUsageSummary);
    procedure PopulateSummary;
    procedure PopulateModels;
    procedure PopulateRecentCalls;
    function FormatTokenCount(Count: Int64): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property UsageSummary: TAipexUsageSummary read FUsageSummary write SetUsageSummary;
  end;

implementation

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_CARD_1: TAlphaColor = $FF667EEA;
  COLOR_CARD_2: TAlphaColor = $FF00C853;
  COLOR_CARD_3: TAlphaColor = $FFFF9800;
  COLOR_CARD_4: TAlphaColor = $FFE91E63;
  COLOR_CHART_BAR: TAlphaColor = $FF667EEA;

{ TFMXUsageStatsFrame }

constructor TFMXUsageStatsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 800;
  Height := 600;
  
  CreateControls;
end;

destructor TFMXUsageStatsFrame.Destroy;
begin
  inherited;
end;

procedure TFMXUsageStatsFrame.CreateControls;
begin
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  FLayoutMain.Padding.Left := 20;
  FLayoutMain.Padding.Right := 20;
  FLayoutMain.Padding.Top := 20;
  FLayoutMain.Padding.Bottom := 20;
  
  CreateSummaryCards;
  CreateDateRange;
  CreateChart;
  CreateModelBreakdown;
  CreateRecentCalls;
end;

procedure TFMXUsageStatsFrame.CreateSummaryCards;
  procedure CreateCard(var ARect: TRectangle; var ATitle, AValue: TLabel;
    X: Single; AColor: TAlphaColor; const TitleText: string);
  begin
    ARect := TRectangle.Create(Self);
    ARect.Parent := FLayoutSummary;
    ARect.Position.X := X;
    ARect.Position.Y := 0;
    ARect.Width := 170;
    ARect.Height := 90;
    ARect.Fill.Color := AColor;
    ARect.Stroke.Kind := TBrushKind.None;
    ARect.XRadius := 8;
    ARect.YRadius := 8;
    
    ATitle := TLabel.Create(Self);
    ATitle.Parent := ARect;
    ATitle.Text := TitleText;
    ATitle.Position.X := 15;
    ATitle.Position.Y := 15;
    ATitle.StyledSettings := [];
    ATitle.TextSettings.Font.Size := 12;
    ATitle.TextSettings.FontColor := $FFFFFFCC;
    
    AValue := TLabel.Create(Self);
    AValue.Parent := ARect;
    AValue.Text := '0';
    AValue.Position.X := 15;
    AValue.Position.Y := 40;
    AValue.StyledSettings := [];
    AValue.TextSettings.Font.Size := 24;
    AValue.TextSettings.Font.Style := [TFontStyle.fsBold];
    AValue.TextSettings.FontColor := TAlphaColors.White;
  end;
begin
  FLayoutSummary := TLayout.Create(Self);
  FLayoutSummary.Parent := FLayoutMain;
  FLayoutSummary.Position.X := 0;
  FLayoutSummary.Position.Y := 0;
  FLayoutSummary.Width := 760;
  FLayoutSummary.Height := 100;
  
  CreateCard(FRectCalls, FLblCallsTitle, FLblCallsValue, 0, COLOR_CARD_1, 'API调用次数');
  CreateCard(FRectInputTokens, FLblInputTitle, FLblInputValue, 190, COLOR_CARD_2, '输入Token');
  CreateCard(FRectOutputTokens, FLblOutputTitle, FLblOutputValue, 380, COLOR_CARD_3, '输出Token');
  CreateCard(FRectCost, FLblCostTitle, FLblCostValue, 570, COLOR_CARD_4, '消费金额 (元)');
end;

procedure TFMXUsageStatsFrame.CreateDateRange;
begin
  FLayoutDateRange := TLayout.Create(Self);
  FLayoutDateRange.Parent := FLayoutMain;
  FLayoutDateRange.Position.X := 0;
  FLayoutDateRange.Position.Y := 110;
  FLayoutDateRange.Width := 500;
  FLayoutDateRange.Height := 40;
  
  FLblPeriod := TLabel.Create(Self);
  FLblPeriod.Parent := FLayoutDateRange;
  FLblPeriod.Text := '统计周期:';
  FLblPeriod.Position.X := 0;
  FLblPeriod.Position.Y := 8;
  FLblPeriod.StyledSettings := [];
  
  FDateStart := TDateEdit.Create(Self);
  FDateStart.Parent := FLayoutDateRange;
  FDateStart.Position.X := 70;
  FDateStart.Position.Y := 0;
  FDateStart.Width := 120;
  FDateStart.Height := 32;
  FDateStart.Date := Date - 30;
  
  FLblTo := TLabel.Create(Self);
  FLblTo.Parent := FLayoutDateRange;
  FLblTo.Text := '至';
  FLblTo.Position.X := 200;
  FLblTo.Position.Y := 8;
  FLblTo.StyledSettings := [];
  
  FDateEnd := TDateEdit.Create(Self);
  FDateEnd.Parent := FLayoutDateRange;
  FDateEnd.Position.X := 225;
  FDateEnd.Position.Y := 0;
  FDateEnd.Width := 120;
  FDateEnd.Height := 32;
  FDateEnd.Date := Date;
  
  FBtnRefresh := TButton.Create(Self);
  FBtnRefresh.Parent := FLayoutDateRange;
  FBtnRefresh.Text := '刷新';
  FBtnRefresh.Position.X := 360;
  FBtnRefresh.Position.Y := 0;
  FBtnRefresh.Width := 80;
  FBtnRefresh.Height := 32;
  FBtnRefresh.OnClick := HandleRefreshClick;
end;

procedure TFMXUsageStatsFrame.CreateChart;
begin
  FLblChartTitle := TLabel.Create(Self);
  FLblChartTitle.Parent := FLayoutMain;
  FLblChartTitle.Text := '每日用量趋势';
  FLblChartTitle.Position.X := 0;
  FLblChartTitle.Position.Y := 160;
  FLblChartTitle.StyledSettings := [];
  FLblChartTitle.TextSettings.Font.Size := 14;
  FLblChartTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FPaintBoxChart := TPaintBox.Create(Self);
  FPaintBoxChart.Parent := FLayoutMain;
  FPaintBoxChart.Position.X := 0;
  FPaintBoxChart.Position.Y := 190;
  FPaintBoxChart.Width := 760;
  FPaintBoxChart.Height := 150;
  FPaintBoxChart.OnPaint := HandleChartPaint;
end;

procedure TFMXUsageStatsFrame.CreateModelBreakdown;
begin
  FLblModelTitle := TLabel.Create(Self);
  FLblModelTitle.Parent := FLayoutMain;
  FLblModelTitle.Text := '模型用量分布';
  FLblModelTitle.Position.X := 0;
  FLblModelTitle.Position.Y := 350;
  FLblModelTitle.StyledSettings := [];
  FLblModelTitle.TextSettings.Font.Size := 14;
  FLblModelTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FListModels := TListView.Create(Self);
  FListModels.Parent := FLayoutMain;
  FListModels.Position.X := 0;
  FListModels.Position.Y := 380;
  FListModels.Width := 370;
  FListModels.Height := 180;
  FListModels.ItemAppearanceClassName := 'TListItemAppearance';
  FListModels.ItemAppearance.ItemAppearance := 'ListItem';
end;

procedure TFMXUsageStatsFrame.CreateRecentCalls;
begin
  FLblRecentTitle := TLabel.Create(Self);
  FLblRecentTitle.Parent := FLayoutMain;
  FLblRecentTitle.Text := '最近调用';
  FLblRecentTitle.Position.X := 390;
  FLblRecentTitle.Position.Y := 350;
  FLblRecentTitle.StyledSettings := [];
  FLblRecentTitle.TextSettings.Font.Size := 14;
  FLblRecentTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FListRecent := TListView.Create(Self);
  FListRecent.Parent := FLayoutMain;
  FListRecent.Position.X := 390;
  FListRecent.Position.Y := 380;
  FListRecent.Width := 370;
  FListRecent.Height := 180;
  FListRecent.ItemAppearanceClassName := 'TListItemAppearance';
  FListRecent.ItemAppearance.ItemAppearance := 'ListItem';
end;

procedure TFMXUsageStatsFrame.HandleRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TFMXUsageStatsFrame.HandleChartPaint(Sender: TObject; Canvas: TCanvas;
  const ARect: TRectF);
var
  I: Integer;
  BarWidth, BarHeight, MaxValue: Single;
  X, Y: Single;
  DayCount: Integer;
begin
  Canvas.Fill.Color := COLOR_BG;
  Canvas.FillRect(ARect, 0, 0, [], 1.0);
  
  DayCount := Length(FDailyUsage);
  if DayCount = 0 then
  begin
    Canvas.Fill.Color := COLOR_TEXT_GRAY;
    Canvas.FillText(ARect, '暂无数据', False, 1.0, [], TTextAlign.Center, TTextAlign.Center);
    Exit;
  end;
  
  // Find max value for scaling
  MaxValue := 1;
  for I := 0 to DayCount - 1 do
    if FDailyUsage[I].TotalCalls > MaxValue then
      MaxValue := FDailyUsage[I].TotalCalls;
  
  BarWidth := (ARect.Width - 40) / DayCount - 4;
  
  Canvas.Fill.Color := COLOR_CHART_BAR;
  
  for I := 0 to DayCount - 1 do
  begin
    BarHeight := (FDailyUsage[I].TotalCalls / MaxValue) * (ARect.Height - 30);
    X := 20 + I * (BarWidth + 4);
    Y := ARect.Height - 20 - BarHeight;
    
    Canvas.FillRect(RectF(X, Y, X + BarWidth, ARect.Height - 20), 4, 4, 
      [TCorner.TopLeft, TCorner.TopRight], 1.0);
  end;
end;

procedure TFMXUsageStatsFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
end;

procedure TFMXUsageStatsFrame.SetUsageSummary(const Value: TAipexUsageSummary);
begin
  FUsageSummary := Value;
  PopulateSummary;
  PopulateModels;
  PopulateRecentCalls;
end;

function TFMXUsageStatsFrame.FormatTokenCount(Count: Int64): string;
begin
  if Count >= 1000000 then
    Result := FormatFloat('#,##0.0M', Count / 1000000)
  else if Count >= 1000 then
    Result := FormatFloat('#,##0.0K', Count / 1000)
  else
    Result := IntToStr(Count);
end;

procedure TFMXUsageStatsFrame.PopulateSummary;
begin
  FLblCallsValue.Text := FormatFloat('#,##0', FUsageSummary.TotalCalls);
  FLblInputValue.Text := FormatTokenCount(FUsageSummary.TotalInputTokens);
  FLblOutputValue.Text := FormatTokenCount(FUsageSummary.TotalOutputTokens);
  FLblCostValue.Text := FormatFloat('#,##0.00', FUsageSummary.TotalCost);
end;

procedure TFMXUsageStatsFrame.PopulateModels;
var
  I: Integer;
  Item: TListViewItem;
  Model: TAipexModelUsage;
begin
  FListModels.Items.Clear;
  
  for I := 0 to High(FUsageSummary.ModelUsage) do
  begin
    Model := FUsageSummary.ModelUsage[I];
    Item := FListModels.Items.Add;
    Item.Text := Model.ModelName;
    Item.Detail := Format('%d 次调用', [Model.Calls]);
    Item.ButtonText := FormatFloat('#,##0.00', Model.Cost) + '元';
  end;
end;

procedure TFMXUsageStatsFrame.PopulateRecentCalls;
var
  I: Integer;
  Item: TListViewItem;
  Call: TAipexRecentCall;
begin
  FListRecent.Items.Clear;
  
  for I := 0 to High(FUsageSummary.RecentCalls) do
  begin
    Call := FUsageSummary.RecentCalls[I];
    Item := FListRecent.Items.Add;
    Item.Text := Call.ModelName;
    Item.Detail := FormatDateTime('mm-dd hh:nn', Call.CalledAt);
    Item.ButtonText := FormatFloat('#,##0', Call.TotalTokens) + ' tokens';
  end;
end;

procedure TFMXUsageStatsFrame.RefreshData;
begin
  if Assigned(FApiClient) then
  begin
    try
      FUsageSummary := FApiClient.GetUsageStats(FDateStart.Date, FDateEnd.Date);
      FDailyUsage := FApiClient.GetDailyUsage(FDateStart.Date, FDateEnd.Date);
      PopulateSummary;
      PopulateModels;
      PopulateRecentCalls;
      FPaintBoxChart.Repaint;
    except
      // Silently ignore
    end;
  end;
end;

end.
