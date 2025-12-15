{ ============================================================================
  UniBase.VCL.BillingFrame - 账单/发票 Frame
  
  Version: 1.0
  Description: Billing frame with invoice list, filters, download and
               request invoice functionality.
  ============================================================================ }

unit UniBase.VCL.BillingFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vcl.ComCtrls, Vcl.Dialogs,
  UniBase.AipexBase.Client;

type
  TBillingFrame = class(TFrame)
  private
    FPnlMain: TPanel;
    
    // Header with summary
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    
    // Summary cards
    FPnlSummary: TPanel;
    FLblMonthCostTitle: TLabel;
    FLblMonthCostValue: TLabel;
    FLblPendingTitle: TLabel;
    FLblPendingValue: TLabel;
    FLblInvoicedTitle: TLabel;
    FLblInvoicedValue: TLabel;
    FBtnRequestInvoice: TButton;
    
    // Filter bar
    FPnlFilter: TPanel;
    FLblStatusFilter: TLabel;
    FBtnFilterAll: TButton;
    FBtnFilterInvoiced: TButton;
    FBtnFilterPending: TButton;
    FLblDateFilter: TLabel;
    FCbxMonth: TComboBox;
    FEdtSearch: TEdit;
    
    // Invoice list
    FPnlList: TPanel;
    FLvInvoices: TListView;
    
    // Pagination
    FPnlPagination: TPanel;
    FLblTotal: TLabel;
    FBtnPrev: TButton;
    FLblPage: TLabel;
    FBtnNext: TButton;
    
    FApiClient: TAipexBaseClient;
    FInvoices: TAipexInvoices;
    FCurrentPage: Integer;
    FPageSize: Integer;
    FTotalCount: Integer;
    FCurrentFilter: string;
    FSaveDialog: TSaveDialog;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleFilterClick(Sender: TObject);
    procedure HandleRequestInvoiceClick(Sender: TObject);
    procedure HandleInvoiceDblClick(Sender: TObject);
    procedure HandlePrevClick(Sender: TObject);
    procedure HandleNextClick(Sender: TObject);
    procedure HandleMonthChange(Sender: TObject);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateFilterButtons;
    procedure UpdatePagination;
    function GetStatusText(const Status: string): string;
    function GetStatusColor(const Status: string): TColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure LoadInvoices;
    procedure RefreshData;
    procedure DownloadInvoice(const InvoiceId: string);
    procedure RequestInvoice(const InvoiceId: string);
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
  end;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI, System.DateUtils;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_PRIMARY_DARK = $A24B76;
  COLOR_BG = $FAF7F5;
  COLOR_CARD = $FFFFFF;
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_SUCCESS = $50E8AF;
  COLOR_WARNING = $00E0FF;
  COLOR_SELECTED = $FFF5E0;

{ TBillingFrame }

constructor TBillingFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 750;
  Height := 600;
  Color := COLOR_BG;
  
  FCurrentPage := 1;
  FPageSize := 10;
  FTotalCount := 0;
  FCurrentFilter := '';
  
  FSaveDialog := TSaveDialog.Create(Self);
  FSaveDialog.Filter := 'PDF文件|*.pdf|所有文件|*.*';
  FSaveDialog.DefaultExt := 'pdf';
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
  
  // Initialize month filter
  InitializeMonthFilter;
end;

destructor TBillingFrame.Destroy;
begin
  FSaveDialog.Free;
  inherited;
end;

procedure InitializeMonthFilter;
begin
  // Will be called in CreateControls
end;

procedure TBillingFrame.CreateControls;
var
  I: Integer;
  Y, M: Word;
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
  FPnlHeader.Color := COLOR_PRIMARY;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlHeader;
  FLblTitle.Caption := '账单与发票';
  FLblTitle.Font.Size := 16;
  FLblTitle.Font.Style := [fsBold];
  FLblTitle.Font.Color := clWhite;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := '查看历史账单，下载电子发票';
  FLblSubtitle.Font.Color := clWhite;
  
  // Summary panel
  FPnlSummary := TPanel.Create(Self);
  FPnlSummary.Parent := FPnlMain;
  FPnlSummary.BevelOuter := bvNone;
  FPnlSummary.Color := COLOR_CARD;
  
  FLblMonthCostTitle := TLabel.Create(Self);
  FLblMonthCostTitle.Parent := FPnlSummary;
  FLblMonthCostTitle.Caption := '本月消费';
  FLblMonthCostTitle.Font.Color := COLOR_TEXT_GRAY;
  
  FLblMonthCostValue := TLabel.Create(Self);
  FLblMonthCostValue.Parent := FPnlSummary;
  FLblMonthCostValue.Caption := '¥0.00';
  FLblMonthCostValue.Font.Size := 16;
  FLblMonthCostValue.Font.Style := [fsBold];
  
  FLblPendingTitle := TLabel.Create(Self);
  FLblPendingTitle.Parent := FPnlSummary;
  FLblPendingTitle.Caption := '待开票金额';
  FLblPendingTitle.Font.Color := COLOR_TEXT_GRAY;
  
  FLblPendingValue := TLabel.Create(Self);
  FLblPendingValue.Parent := FPnlSummary;
  FLblPendingValue.Caption := '¥0.00';
  FLblPendingValue.Font.Size := 16;
  FLblPendingValue.Font.Style := [fsBold];
  
  FLblInvoicedTitle := TLabel.Create(Self);
  FLblInvoicedTitle.Parent := FPnlSummary;
  FLblInvoicedTitle.Caption := '已开票金额';
  FLblInvoicedTitle.Font.Color := COLOR_TEXT_GRAY;
  
  FLblInvoicedValue := TLabel.Create(Self);
  FLblInvoicedValue.Parent := FPnlSummary;
  FLblInvoicedValue.Caption := '¥0.00';
  FLblInvoicedValue.Font.Size := 16;
  FLblInvoicedValue.Font.Style := [fsBold];
  
  FBtnRequestInvoice := TButton.Create(Self);
  FBtnRequestInvoice.Parent := FPnlSummary;
  FBtnRequestInvoice.Caption := '申请开票';
  FBtnRequestInvoice.OnClick := HandleRequestInvoiceClick;
  
  // Filter bar
  FPnlFilter := TPanel.Create(Self);
  FPnlFilter.Parent := FPnlMain;
  FPnlFilter.BevelOuter := bvNone;
  FPnlFilter.Color := COLOR_CARD;
  
  FLblStatusFilter := TLabel.Create(Self);
  FLblStatusFilter.Parent := FPnlFilter;
  FLblStatusFilter.Caption := '状态:';
  FLblStatusFilter.Font.Color := COLOR_TEXT_GRAY;
  
  FBtnFilterAll := TButton.Create(Self);
  FBtnFilterAll.Parent := FPnlFilter;
  FBtnFilterAll.Caption := '全部';
  FBtnFilterAll.Tag := 0;
  FBtnFilterAll.OnClick := HandleFilterClick;
  
  FBtnFilterInvoiced := TButton.Create(Self);
  FBtnFilterInvoiced.Parent := FPnlFilter;
  FBtnFilterInvoiced.Caption := '已开票';
  FBtnFilterInvoiced.Tag := 1;
  FBtnFilterInvoiced.OnClick := HandleFilterClick;
  
  FBtnFilterPending := TButton.Create(Self);
  FBtnFilterPending.Parent := FPnlFilter;
  FBtnFilterPending.Caption := '未开票';
  FBtnFilterPending.Tag := 2;
  FBtnFilterPending.OnClick := HandleFilterClick;
  
  FLblDateFilter := TLabel.Create(Self);
  FLblDateFilter.Parent := FPnlFilter;
  FLblDateFilter.Caption := '时间:';
  FLblDateFilter.Font.Color := COLOR_TEXT_GRAY;
  
  FCbxMonth := TComboBox.Create(Self);
  FCbxMonth.Parent := FPnlFilter;
  FCbxMonth.Style := csDropDownList;
  FCbxMonth.OnChange := HandleMonthChange;
  
  // Populate month filter
  DecodeDate(Date, Y, M, I);
  for I := 0 to 11 do
  begin
    FCbxMonth.Items.Add(Format('%d年%d月', [Y, M]));
    Dec(M);
    if M = 0 then
    begin
      M := 12;
      Dec(Y);
    end;
  end;
  FCbxMonth.ItemIndex := 0;
  
  FEdtSearch := TEdit.Create(Self);
  FEdtSearch.Parent := FPnlFilter;
  FEdtSearch.TextHint := '搜索账单...';
  
  // Invoice list
  FPnlList := TPanel.Create(Self);
  FPnlList.Parent := FPnlMain;
  FPnlList.BevelOuter := bvNone;
  FPnlList.Color := COLOR_CARD;
  
  FLvInvoices := TListView.Create(Self);
  FLvInvoices.Parent := FPnlList;
  FLvInvoices.ViewStyle := vsReport;
  FLvInvoices.RowSelect := True;
  FLvInvoices.ReadOnly := True;
  FLvInvoices.GridLines := True;
  FLvInvoices.OnDblClick := HandleInvoiceDblClick;
  with FLvInvoices.Columns.Add do begin Caption := '账单编号'; Width := 130; end;
  with FLvInvoices.Columns.Add do begin Caption := '账单周期'; Width := 150; end;
  with FLvInvoices.Columns.Add do begin Caption := '金额'; Width := 100; end;
  with FLvInvoices.Columns.Add do begin Caption := '状态'; Width := 80; end;
  with FLvInvoices.Columns.Add do begin Caption := '操作'; Width := 100; end;
  
  // Pagination
  FPnlPagination := TPanel.Create(Self);
  FPnlPagination.Parent := FPnlMain;
  FPnlPagination.BevelOuter := bvNone;
  FPnlPagination.Color := COLOR_CARD;
  
  FLblTotal := TLabel.Create(Self);
  FLblTotal.Parent := FPnlPagination;
  FLblTotal.Caption := '共 0 条记录';
  FLblTotal.Font.Color := COLOR_TEXT_GRAY;
  
  FBtnPrev := TButton.Create(Self);
  FBtnPrev.Parent := FPnlPagination;
  FBtnPrev.Caption := '<';
  FBtnPrev.OnClick := HandlePrevClick;
  
  FLblPage := TLabel.Create(Self);
  FLblPage.Parent := FPnlPagination;
  FLblPage.Caption := '1';
  
  FBtnNext := TButton.Create(Self);
  FBtnNext.Parent := FPnlPagination;
  FBtnNext.Caption := '>';
  FBtnNext.OnClick := HandleNextClick;
end;

procedure TBillingFrame.LayoutControls;
begin
  // Header
  FPnlHeader.SetBounds(0, 0, Width, 80);
  FLblTitle.SetBounds(30, 20, 200, 28);
  FLblSubtitle.SetBounds(30, 50, 300, 18);
  
  // Summary
  FPnlSummary.SetBounds(20, 65, Width - 40, 65);
  FLblMonthCostTitle.SetBounds(20, 12, 80, 16);
  FLblMonthCostValue.SetBounds(20, 32, 120, 24);
  FLblPendingTitle.SetBounds(170, 12, 80, 16);
  FLblPendingValue.SetBounds(170, 32, 120, 24);
  FLblInvoicedTitle.SetBounds(320, 12, 80, 16);
  FLblInvoicedValue.SetBounds(320, 32, 120, 24);
  FBtnRequestInvoice.SetBounds(Width - 160, 18, 100, 32);
  
  // Filter bar
  FPnlFilter.SetBounds(20, 145, Width - 40, 45);
  FLblStatusFilter.SetBounds(15, 15, 40, 18);
  FBtnFilterAll.SetBounds(60, 10, 60, 26);
  FBtnFilterInvoiced.SetBounds(125, 10, 60, 26);
  FBtnFilterPending.SetBounds(190, 10, 60, 26);
  FLblDateFilter.SetBounds(280, 15, 40, 18);
  FCbxMonth.SetBounds(320, 10, 120, 26);
  FEdtSearch.SetBounds(Width - 200, 10, 150, 26);
  
  // Invoice list
  FPnlList.SetBounds(20, 200, Width - 40, 340);
  FLvInvoices.SetBounds(10, 10, FPnlList.Width - 20, FPnlList.Height - 20);
  
  // Pagination
  FPnlPagination.SetBounds(20, 550, Width - 40, 40);
  FLblTotal.SetBounds(15, 12, 100, 18);
  FBtnPrev.SetBounds(Width - 200, 8, 30, 26);
  FLblPage.SetBounds(Width - 160, 12, 30, 18);
  FBtnNext.SetBounds(Width - 120, 8, 30, 26);
end;

procedure TBillingFrame.ApplyStyle;
begin
  FPnlHeader.Color := COLOR_PRIMARY;
  
  FBtnRequestInvoice.Font.Style := [fsBold];
  
  FBtnFilterAll.Font.Size := 9;
  FBtnFilterInvoiced.Font.Size := 9;
  FBtnFilterPending.Font.Size := 9;
  
  UpdateFilterButtons;
end;

procedure TBillingFrame.HandleFilterClick(Sender: TObject);
begin
  case TButton(Sender).Tag of
    0: FCurrentFilter := '';
    1: FCurrentFilter := 'invoiced';
    2: FCurrentFilter := 'pending';
  end;
  FCurrentPage := 1;
  UpdateFilterButtons;
  LoadInvoices;
end;

procedure TBillingFrame.HandleRequestInvoiceClick(Sender: TObject);
begin
  // Open request invoice dialog or select pending invoices
  if FLvInvoices.Selected <> nil then
    RequestInvoice(FInvoices[FLvInvoices.Selected.Index].InvoiceId);
end;

procedure TBillingFrame.HandleInvoiceDblClick(Sender: TObject);
begin
  if FLvInvoices.Selected <> nil then
  begin
    if FInvoices[FLvInvoices.Selected.Index].Status = 'invoiced' then
      DownloadInvoice(FInvoices[FLvInvoices.Selected.Index].InvoiceId)
    else
      RequestInvoice(FInvoices[FLvInvoices.Selected.Index].InvoiceId);
  end;
end;

procedure TBillingFrame.HandlePrevClick(Sender: TObject);
begin
  if FCurrentPage > 1 then
  begin
    Dec(FCurrentPage);
    LoadInvoices;
  end;
end;

procedure TBillingFrame.HandleNextClick(Sender: TObject);
begin
  if FCurrentPage * FPageSize < FTotalCount then
  begin
    Inc(FCurrentPage);
    LoadInvoices;
  end;
end;

procedure TBillingFrame.HandleMonthChange(Sender: TObject);
begin
  FCurrentPage := 1;
  LoadInvoices;
end;

procedure TBillingFrame.UpdateFilterButtons;
begin
  if FCurrentFilter = '' then
    FBtnFilterAll.Font.Style := [fsBold]
  else
    FBtnFilterAll.Font.Style := [];
  
  if FCurrentFilter = 'invoiced' then
    FBtnFilterInvoiced.Font.Style := [fsBold]
  else
    FBtnFilterInvoiced.Font.Style := [];
  
  if FCurrentFilter = 'pending' then
    FBtnFilterPending.Font.Style := [fsBold]
  else
    FBtnFilterPending.Font.Style := [];
end;

procedure TBillingFrame.UpdatePagination;
var
  TotalPages: Integer;
begin
  FLblTotal.Caption := Format('共 %d 条记录', [FTotalCount]);
  
  TotalPages := (FTotalCount + FPageSize - 1) div FPageSize;
  if TotalPages = 0 then TotalPages := 1;
  
  FLblPage.Caption := Format('%d / %d', [FCurrentPage, TotalPages]);
  FBtnPrev.Enabled := FCurrentPage > 1;
  FBtnNext.Enabled := FCurrentPage < TotalPages;
end;

function TBillingFrame.GetStatusText(const Status: string): string;
begin
  if Status = 'invoiced' then
    Result := '已开票'
  else if Status = 'pending' then
    Result := '未开票'
  else if Status = 'cancelled' then
    Result := '已取消'
  else
    Result := Status;
end;

function TBillingFrame.GetStatusColor(const Status: string): TColor;
begin
  if Status = 'invoiced' then
    Result := COLOR_SUCCESS
  else if Status = 'pending' then
    Result := COLOR_WARNING
  else
    Result := COLOR_TEXT_GRAY;
end;

procedure TBillingFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
  if Assigned(FApiClient) then
    RefreshData;
end;

procedure TBillingFrame.LoadInvoices;
var
  I: Integer;
  Item: TListItem;
  ActionText: string;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FInvoices := FApiClient.GetInvoices(FCurrentPage, FPageSize, FCurrentFilter);
    FTotalCount := Length(FInvoices); // Simplified - should come from API
    
    FLvInvoices.Items.BeginUpdate;
    try
      FLvInvoices.Items.Clear;
      for I := 0 to Length(FInvoices) - 1 do
      begin
        Item := FLvInvoices.Items.Add;
        Item.Caption := FInvoices[I].InvoiceNo;
        Item.SubItems.Add(FormatDateTime('yyyy-mm-dd', FInvoices[I].PeriodStart) + 
                          ' ~ ' + FormatDateTime('mm-dd', FInvoices[I].PeriodEnd));
        Item.SubItems.Add('¥' + FormatFloat('#,##0.00', FInvoices[I].Amount));
        Item.SubItems.Add(GetStatusText(FInvoices[I].Status));
        
        if FInvoices[I].Status = 'invoiced' then
          ActionText := '下载 | 详情'
        else
          ActionText := '开票 | 详情';
        Item.SubItems.Add(ActionText);
      end;
    finally
      FLvInvoices.Items.EndUpdate;
    end;
    
    UpdatePagination;
  except
    // Ignore errors
  end;
end;

procedure TBillingFrame.RefreshData;
begin
  LoadInvoices;
end;

procedure TBillingFrame.DownloadInvoice(const InvoiceId: string);
var
  Stream: TFileStream;
begin
  if not Assigned(FApiClient) then Exit;
  
  FSaveDialog.FileName := 'invoice_' + InvoiceId + '.pdf';
  if FSaveDialog.Execute then
  begin
    Stream := TFileStream.Create(FSaveDialog.FileName, fmCreate);
    try
      if FApiClient.DownloadInvoice(InvoiceId, Stream) then
        ShellExecute(0, 'open', PChar(FSaveDialog.FileName), nil, nil, SW_SHOWNORMAL);
    finally
      Stream.Free;
    end;
  end;
end;

procedure TBillingFrame.RequestInvoice(const InvoiceId: string);
begin
  if not Assigned(FApiClient) then Exit;
  
  if FApiClient.RequestInvoice(InvoiceId) then
  begin
    ShowMessage('开票申请已提交，请等待处理');
    LoadInvoices;
  end
  else
    ShowMessage('开票申请失败，请稍后重试');
end;

end.
