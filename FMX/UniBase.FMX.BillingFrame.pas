{ ============================================================================
  UniBase.FMX.BillingFrame - FMX 账单/发票 Frame
  
  Version: 1.0
  Description: Modern FMX billing frame with invoice list, filtering,
               pagination, and download functionality.
  ============================================================================ }

unit UniBase.FMX.BillingFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics, FMX.ListView, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base, FMX.ListBox,
  UniBase.AipexBase.Client;

type
  TFMXBillingFrame = class(TFrame)
  private
    FLayoutMain: TLayout;
    // Summary
    FRectSummary: TRectangle;
    FLblTotalSpent: TLabel;
    FLblTotalSpentValue: TLabel;
    FLblPendingAmount: TLabel;
    FLblPendingAmountValue: TLabel;
    FLblInvoiceCount: TLabel;
    FLblInvoiceCountValue: TLabel;
    // Filters
    FLayoutFilters: TLayout;
    FBtnAll: TButton;
    FBtnInvoiced: TButton;
    FBtnPending: TButton;
    FCmbMonth: TComboBox;
    // Invoice list
    FLblListTitle: TLabel;
    FListInvoices: TListView;
    // Pagination
    FLayoutPagination: TLayout;
    FBtnPrevPage: TButton;
    FLblPageInfo: TLabel;
    FBtnNextPage: TButton;
    // Actions
    FLayoutActions: TLayout;
    FBtnDownload: TButton;
    FBtnRequestInvoice: TButton;
    
    FApiClient: TAipexBaseClient;
    FInvoices: TArray<TAipexInvoice>;
    FCurrentFilter: string;
    FCurrentPage: Integer;
    FTotalPages: Integer;
    FSelectedInvoiceId: string;
    FOnDownload: TNotifyEvent;
    FOnRequestInvoice: TNotifyEvent;
    
    procedure CreateControls;
    procedure CreateSummary;
    procedure CreateFilters;
    procedure CreateInvoiceList;
    procedure CreatePagination;
    procedure CreateActions;
    procedure HandleFilterClick(Sender: TObject);
    procedure HandleMonthChange(Sender: TObject);
    procedure HandleInvoiceClick(Sender: TObject);
    procedure HandlePrevPageClick(Sender: TObject);
    procedure HandleNextPageClick(Sender: TObject);
    procedure HandleDownloadClick(Sender: TObject);
    procedure HandleRequestInvoiceClick(Sender: TObject);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateFilterButtons;
    procedure PopulateSummary;
    procedure PopulateInvoices;
    procedure UpdatePagination;
    procedure InitMonthComboBox;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property OnDownload: TNotifyEvent read FOnDownload write FOnDownload;
    property OnRequestInvoice: TNotifyEvent read FOnRequestInvoice write FOnRequestInvoice;
  end;

implementation

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_SUCCESS: TAlphaColor = $FF00AA00;
  COLOR_WARNING: TAlphaColor = $FFFFA500;
  PAGE_SIZE = 10;

{ TFMXBillingFrame }

constructor TFMXBillingFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 750;
  Height := 600;
  FCurrentFilter := 'all';
  FCurrentPage := 1;
  FTotalPages := 1;
  
  CreateControls;
end;

destructor TFMXBillingFrame.Destroy;
begin
  inherited;
end;

procedure TFMXBillingFrame.CreateControls;
begin
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  FLayoutMain.Padding.Left := 20;
  FLayoutMain.Padding.Right := 20;
  FLayoutMain.Padding.Top := 20;
  FLayoutMain.Padding.Bottom := 20;
  
  CreateSummary;
  CreateFilters;
  CreateInvoiceList;
  CreatePagination;
  CreateActions;
end;

procedure TFMXBillingFrame.CreateSummary;
begin
  FRectSummary := TRectangle.Create(Self);
  FRectSummary.Parent := FLayoutMain;
  FRectSummary.Position.X := 0;
  FRectSummary.Position.Y := 0;
  FRectSummary.Width := 710;
  FRectSummary.Height := 80;
  FRectSummary.Fill.Color := COLOR_PRIMARY;
  FRectSummary.Stroke.Kind := TBrushKind.None;
  FRectSummary.XRadius := 8;
  FRectSummary.YRadius := 8;
  
  // Total spent
  FLblTotalSpent := TLabel.Create(Self);
  FLblTotalSpent.Parent := FRectSummary;
  FLblTotalSpent.Text := '累计消费';
  FLblTotalSpent.Position.X := 30;
  FLblTotalSpent.Position.Y := 15;
  FLblTotalSpent.StyledSettings := [];
  FLblTotalSpent.TextSettings.Font.Size := 12;
  FLblTotalSpent.TextSettings.FontColor := $FFFFFFCC;
  
  FLblTotalSpentValue := TLabel.Create(Self);
  FLblTotalSpentValue.Parent := FRectSummary;
  FLblTotalSpentValue.Text := '¥0.00';
  FLblTotalSpentValue.Position.X := 30;
  FLblTotalSpentValue.Position.Y := 38;
  FLblTotalSpentValue.StyledSettings := [];
  FLblTotalSpentValue.TextSettings.Font.Size := 20;
  FLblTotalSpentValue.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblTotalSpentValue.TextSettings.FontColor := TAlphaColors.White;
  
  // Pending amount
  FLblPendingAmount := TLabel.Create(Self);
  FLblPendingAmount.Parent := FRectSummary;
  FLblPendingAmount.Text := '待开票金额';
  FLblPendingAmount.Position.X := 260;
  FLblPendingAmount.Position.Y := 15;
  FLblPendingAmount.StyledSettings := [];
  FLblPendingAmount.TextSettings.Font.Size := 12;
  FLblPendingAmount.TextSettings.FontColor := $FFFFFFCC;
  
  FLblPendingAmountValue := TLabel.Create(Self);
  FLblPendingAmountValue.Parent := FRectSummary;
  FLblPendingAmountValue.Text := '¥0.00';
  FLblPendingAmountValue.Position.X := 260;
  FLblPendingAmountValue.Position.Y := 38;
  FLblPendingAmountValue.StyledSettings := [];
  FLblPendingAmountValue.TextSettings.Font.Size := 20;
  FLblPendingAmountValue.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblPendingAmountValue.TextSettings.FontColor := TAlphaColors.White;
  
  // Invoice count
  FLblInvoiceCount := TLabel.Create(Self);
  FLblInvoiceCount.Parent := FRectSummary;
  FLblInvoiceCount.Text := '发票数量';
  FLblInvoiceCount.Position.X := 500;
  FLblInvoiceCount.Position.Y := 15;
  FLblInvoiceCount.StyledSettings := [];
  FLblInvoiceCount.TextSettings.Font.Size := 12;
  FLblInvoiceCount.TextSettings.FontColor := $FFFFFFCC;
  
  FLblInvoiceCountValue := TLabel.Create(Self);
  FLblInvoiceCountValue.Parent := FRectSummary;
  FLblInvoiceCountValue.Text := '0';
  FLblInvoiceCountValue.Position.X := 500;
  FLblInvoiceCountValue.Position.Y := 38;
  FLblInvoiceCountValue.StyledSettings := [];
  FLblInvoiceCountValue.TextSettings.Font.Size := 20;
  FLblInvoiceCountValue.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblInvoiceCountValue.TextSettings.FontColor := TAlphaColors.White;
end;

procedure TFMXBillingFrame.CreateFilters;
begin
  FLayoutFilters := TLayout.Create(Self);
  FLayoutFilters.Parent := FLayoutMain;
  FLayoutFilters.Position.X := 0;
  FLayoutFilters.Position.Y := 100;
  FLayoutFilters.Width := 710;
  FLayoutFilters.Height := 40;
  
  FBtnAll := TButton.Create(Self);
  FBtnAll.Parent := FLayoutFilters;
  FBtnAll.Text := '全部';
  FBtnAll.Position.X := 0;
  FBtnAll.Position.Y := 0;
  FBtnAll.Width := 80;
  FBtnAll.Height := 32;
  FBtnAll.TagString := 'all';
  FBtnAll.OnClick := HandleFilterClick;
  
  FBtnInvoiced := TButton.Create(Self);
  FBtnInvoiced.Parent := FLayoutFilters;
  FBtnInvoiced.Text := '已开票';
  FBtnInvoiced.Position.X := 90;
  FBtnInvoiced.Position.Y := 0;
  FBtnInvoiced.Width := 80;
  FBtnInvoiced.Height := 32;
  FBtnInvoiced.TagString := 'invoiced';
  FBtnInvoiced.OnClick := HandleFilterClick;
  
  FBtnPending := TButton.Create(Self);
  FBtnPending.Parent := FLayoutFilters;
  FBtnPending.Text := '待开票';
  FBtnPending.Position.X := 180;
  FBtnPending.Position.Y := 0;
  FBtnPending.Width := 80;
  FBtnPending.Height := 32;
  FBtnPending.TagString := 'pending';
  FBtnPending.OnClick := HandleFilterClick;
  
  FCmbMonth := TComboBox.Create(Self);
  FCmbMonth.Parent := FLayoutFilters;
  FCmbMonth.Position.X := 560;
  FCmbMonth.Position.Y := 0;
  FCmbMonth.Width := 150;
  FCmbMonth.Height := 32;
  FCmbMonth.OnChange := HandleMonthChange;
  InitMonthComboBox;
  
  UpdateFilterButtons;
end;

procedure TFMXBillingFrame.InitMonthComboBox;
var
  I: Integer;
  Y, M, D: Word;
begin
  FCmbMonth.Items.Clear;
  FCmbMonth.Items.Add('全部月份');
  
  DecodeDate(Date, Y, M, D);
  for I := 0 to 11 do
  begin
    FCmbMonth.Items.Add(Format('%d年%d月', [Y, M]));
    Dec(M);
    if M = 0 then
    begin
      M := 12;
      Dec(Y);
    end;
  end;
  
  FCmbMonth.ItemIndex := 0;
end;

procedure TFMXBillingFrame.CreateInvoiceList;
begin
  FLblListTitle := TLabel.Create(Self);
  FLblListTitle.Parent := FLayoutMain;
  FLblListTitle.Text := '账单列表';
  FLblListTitle.Position.X := 0;
  FLblListTitle.Position.Y := 155;
  FLblListTitle.StyledSettings := [];
  FLblListTitle.TextSettings.Font.Size := 14;
  FLblListTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FListInvoices := TListView.Create(Self);
  FListInvoices.Parent := FLayoutMain;
  FListInvoices.Position.X := 0;
  FListInvoices.Position.Y := 185;
  FListInvoices.Width := 710;
  FListInvoices.Height := 300;
  FListInvoices.ItemAppearanceClassName := 'TListItemAppearance';
  FListInvoices.ItemAppearance.ItemAppearance := 'ListItem';
  FListInvoices.OnItemClick := HandleInvoiceClick;
end;

procedure TFMXBillingFrame.CreatePagination;
begin
  FLayoutPagination := TLayout.Create(Self);
  FLayoutPagination.Parent := FLayoutMain;
  FLayoutPagination.Position.X := 250;
  FLayoutPagination.Position.Y := 495;
  FLayoutPagination.Width := 200;
  FLayoutPagination.Height := 40;
  
  FBtnPrevPage := TButton.Create(Self);
  FBtnPrevPage.Parent := FLayoutPagination;
  FBtnPrevPage.Text := '上一页';
  FBtnPrevPage.Position.X := 0;
  FBtnPrevPage.Position.Y := 0;
  FBtnPrevPage.Width := 60;
  FBtnPrevPage.Height := 30;
  FBtnPrevPage.OnClick := HandlePrevPageClick;
  
  FLblPageInfo := TLabel.Create(Self);
  FLblPageInfo.Parent := FLayoutPagination;
  FLblPageInfo.Text := '1 / 1';
  FLblPageInfo.Position.X := 70;
  FLblPageInfo.Position.Y := 5;
  FLblPageInfo.Width := 60;
  FLblPageInfo.StyledSettings := [];
  FLblPageInfo.TextSettings.HorzAlign := TTextAlign.Center;
  
  FBtnNextPage := TButton.Create(Self);
  FBtnNextPage.Parent := FLayoutPagination;
  FBtnNextPage.Text := '下一页';
  FBtnNextPage.Position.X := 140;
  FBtnNextPage.Position.Y := 0;
  FBtnNextPage.Width := 60;
  FBtnNextPage.Height := 30;
  FBtnNextPage.OnClick := HandleNextPageClick;
end;

procedure TFMXBillingFrame.CreateActions;
begin
  FLayoutActions := TLayout.Create(Self);
  FLayoutActions.Parent := FLayoutMain;
  FLayoutActions.Position.X := 0;
  FLayoutActions.Position.Y := 545;
  FLayoutActions.Width := 300;
  FLayoutActions.Height := 40;
  
  FBtnDownload := TButton.Create(Self);
  FBtnDownload.Parent := FLayoutActions;
  FBtnDownload.Text := '下载发票';
  FBtnDownload.Position.X := 0;
  FBtnDownload.Position.Y := 0;
  FBtnDownload.Width := 100;
  FBtnDownload.Height := 36;
  FBtnDownload.Enabled := False;
  FBtnDownload.OnClick := HandleDownloadClick;
  
  FBtnRequestInvoice := TButton.Create(Self);
  FBtnRequestInvoice.Parent := FLayoutActions;
  FBtnRequestInvoice.Text := '申请开票';
  FBtnRequestInvoice.Position.X := 120;
  FBtnRequestInvoice.Position.Y := 0;
  FBtnRequestInvoice.Width := 100;
  FBtnRequestInvoice.Height := 36;
  FBtnRequestInvoice.OnClick := HandleRequestInvoiceClick;
end;

procedure TFMXBillingFrame.HandleFilterClick(Sender: TObject);
begin
  FCurrentFilter := TButton(Sender).TagString;
  FCurrentPage := 1;
  UpdateFilterButtons;
  RefreshData;
end;

procedure TFMXBillingFrame.HandleMonthChange(Sender: TObject);
begin
  FCurrentPage := 1;
  RefreshData;
end;

procedure TFMXBillingFrame.HandleInvoiceClick(Sender: TObject);
var
  Item: TListViewItem;
begin
  Item := FListInvoices.Selected;
  if Assigned(Item) then
  begin
    FSelectedInvoiceId := Item.TagString;
    FBtnDownload.Enabled := Item.Tag = 1; // 1 = invoiced
  end
  else
  begin
    FSelectedInvoiceId := '';
    FBtnDownload.Enabled := False;
  end;
end;

procedure TFMXBillingFrame.HandlePrevPageClick(Sender: TObject);
begin
  if FCurrentPage > 1 then
  begin
    Dec(FCurrentPage);
    RefreshData;
  end;
end;

procedure TFMXBillingFrame.HandleNextPageClick(Sender: TObject);
begin
  if FCurrentPage < FTotalPages then
  begin
    Inc(FCurrentPage);
    RefreshData;
  end;
end;

procedure TFMXBillingFrame.HandleDownloadClick(Sender: TObject);
begin
  if (FSelectedInvoiceId <> '') and Assigned(FOnDownload) then
    FOnDownload(Self);
end;

procedure TFMXBillingFrame.HandleRequestInvoiceClick(Sender: TObject);
begin
  if Assigned(FOnRequestInvoice) then
    FOnRequestInvoice(Self);
end;

procedure TFMXBillingFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
end;

procedure TFMXBillingFrame.UpdateFilterButtons;
begin
  FBtnAll.Opacity := IfThen(FCurrentFilter = 'all', 1.0, 0.7);
  FBtnInvoiced.Opacity := IfThen(FCurrentFilter = 'invoiced', 1.0, 0.7);
  FBtnPending.Opacity := IfThen(FCurrentFilter = 'pending', 1.0, 0.7);
end;

procedure TFMXBillingFrame.PopulateSummary;
var
  TotalSpent, PendingAmount: Double;
  InvoiceCount: Integer;
  I: Integer;
begin
  TotalSpent := 0;
  PendingAmount := 0;
  InvoiceCount := 0;
  
  for I := 0 to High(FInvoices) do
  begin
    TotalSpent := TotalSpent + FInvoices[I].Amount;
    if FInvoices[I].Status = 'invoiced' then
      Inc(InvoiceCount)
    else
      PendingAmount := PendingAmount + FInvoices[I].Amount;
  end;
  
  FLblTotalSpentValue.Text := '¥' + FormatFloat('#,##0.00', TotalSpent);
  FLblPendingAmountValue.Text := '¥' + FormatFloat('#,##0.00', PendingAmount);
  FLblInvoiceCountValue.Text := IntToStr(InvoiceCount);
end;

procedure TFMXBillingFrame.PopulateInvoices;
var
  I, StartIdx, EndIdx: Integer;
  Item: TListViewItem;
  Invoice: TAipexInvoice;
  StatusText: string;
begin
  FListInvoices.Items.Clear;
  
  if Length(FInvoices) = 0 then
  begin
    FTotalPages := 1;
    UpdatePagination;
    Exit;
  end;
  
  FTotalPages := Ceil(Length(FInvoices) / PAGE_SIZE);
  StartIdx := (FCurrentPage - 1) * PAGE_SIZE;
  EndIdx := Min(StartIdx + PAGE_SIZE - 1, High(FInvoices));
  
  for I := StartIdx to EndIdx do
  begin
    Invoice := FInvoices[I];
    Item := FListInvoices.Items.Add;
    Item.Text := Invoice.Description;
    Item.Detail := FormatDateTime('yyyy-mm-dd', Invoice.CreatedAt);
    Item.ButtonText := '¥' + FormatFloat('#,##0.00', Invoice.Amount);
    Item.TagString := Invoice.InvoiceId;
    
    if Invoice.Status = 'invoiced' then
    begin
      Item.Tag := 1;
      StatusText := '已开票';
    end
    else
    begin
      Item.Tag := 0;
      StatusText := '待开票';
    end;
  end;
  
  UpdatePagination;
end;

procedure TFMXBillingFrame.UpdatePagination;
begin
  FLblPageInfo.Text := Format('%d / %d', [FCurrentPage, FTotalPages]);
  FBtnPrevPage.Enabled := FCurrentPage > 1;
  FBtnNextPage.Enabled := FCurrentPage < FTotalPages;
end;

procedure TFMXBillingFrame.RefreshData;
var
  MonthFilter: string;
begin
  if Assigned(FApiClient) then
  begin
    try
      MonthFilter := '';
      if FCmbMonth.ItemIndex > 0 then
        MonthFilter := FCmbMonth.Items[FCmbMonth.ItemIndex];
        
      FInvoices := FApiClient.GetInvoices(FCurrentFilter, MonthFilter, FCurrentPage, PAGE_SIZE);
      PopulateSummary;
      PopulateInvoices;
    except
      // Silently ignore
    end;
  end;
end;

end.
