{ ============================================================================
  UniBase.VCL.BalanceFrame - 余额/充值 Frame
  
  Version: 1.0
  Description: Balance display, recharge options, payment methods and
               transaction history.
  ============================================================================ }

unit UniBase.VCL.BalanceFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vcl.ComCtrls, Vcl.Grids,
  UniBase.AipexBase.Client;

type
  TBalanceFrame = class(TFrame)
  private
    FPnlMain: TPanel;
    
    // Balance Card
    FPnlBalance: TPanel;
    FLblBalanceTitle: TLabel;
    FLblBalanceValue: TLabel;
    FLblBalanceCurrency: TLabel;
    
    // Recharge Section
    FPnlRecharge: TPanel;
    FLblRechargeTitle: TLabel;
    FRechargeButtons: array[0..5] of TPanel;
    FRechargeLabels: array[0..5] of TLabel;
    FRechargeBonusLabels: array[0..5] of TLabel;
    FSelectedRechargeIndex: Integer;
    
    // Custom Amount
    FLblCustomAmount: TLabel;
    FEdtCustomAmount: TEdit;
    
    // Payment Methods
    FPnlPayment: TPanel;
    FLblPaymentTitle: TLabel;
    FBtnAlipay: TPanel;
    FLblAlipay: TLabel;
    FBtnWechat: TPanel;
    FLblWechat: TLabel;
    FSelectedPaymentMethod: string;
    
    // Recharge Button
    FBtnRecharge: TButton;
    FLblStatus: TLabel;
    
    // Transaction History
    FPnlHistory: TPanel;
    FLblHistoryTitle: TLabel;
    FLvTransactions: TListView;
    FBtnRefresh: TButton;
    
    FApiClient: TAipexBaseClient;
    FBalance: TAipexBalance;
    FRechargeOptions: TAipexRechargeOptions;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleRechargeOptionClick(Sender: TObject);
    procedure HandlePaymentMethodClick(Sender: TObject);
    procedure HandleRechargeClick(Sender: TObject);
    procedure HandleRefreshClick(Sender: TObject);
    procedure HandleCustomAmountChange(Sender: TObject);
    procedure UpdateRechargeSelection;
    procedure UpdatePaymentSelection;
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure LoadBalance;
    procedure LoadRechargeOptions;
    procedure LoadTransactions;
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property Balance: TAipexBalance read FBalance;
  end;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_BG = $FAF7F5;
  COLOR_CARD = $FFFFFF;
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_ERROR = $0000FF;
  COLOR_SUCCESS = $00AA00;
  COLOR_SELECTED = $FFF5E0;
  COLOR_BORDER = $DDDDDD;

  RECHARGE_AMOUNTS: array[0..5] of Currency = (50, 100, 200, 500, 1000, 0); // 0 = custom

{ TBalanceFrame }

constructor TBalanceFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 700;
  Height := 550;
  Color := COLOR_BG;
  
  FSelectedRechargeIndex := -1;
  FSelectedPaymentMethod := '';
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
end;

destructor TBalanceFrame.Destroy;
begin
  inherited;
end;

procedure TBalanceFrame.CreateControls;
var
  I: Integer;
begin
  FPnlMain := TPanel.Create(Self);
  FPnlMain.Parent := Self;
  FPnlMain.Align := alClient;
  FPnlMain.BevelOuter := bvNone;
  FPnlMain.Color := COLOR_BG;
  
  // Balance Card
  FPnlBalance := TPanel.Create(Self);
  FPnlBalance.Parent := FPnlMain;
  FPnlBalance.BevelOuter := bvNone;
  FPnlBalance.Color := COLOR_PRIMARY;
  
  FLblBalanceTitle := TLabel.Create(Self);
  FLblBalanceTitle.Parent := FPnlBalance;
  FLblBalanceTitle.Caption := '当前余额';
  FLblBalanceTitle.Font.Color := clWhite;
  FLblBalanceTitle.Font.Size := 11;
  
  FLblBalanceCurrency := TLabel.Create(Self);
  FLblBalanceCurrency.Parent := FPnlBalance;
  FLblBalanceCurrency.Caption := '¥';
  FLblBalanceCurrency.Font.Color := clWhite;
  FLblBalanceCurrency.Font.Size := 20;
  
  FLblBalanceValue := TLabel.Create(Self);
  FLblBalanceValue.Parent := FPnlBalance;
  FLblBalanceValue.Caption := '0.00';
  FLblBalanceValue.Font.Color := clWhite;
  FLblBalanceValue.Font.Size := 32;
  FLblBalanceValue.Font.Style := [fsBold];
  
  // Recharge Section
  FPnlRecharge := TPanel.Create(Self);
  FPnlRecharge.Parent := FPnlMain;
  FPnlRecharge.BevelOuter := bvNone;
  FPnlRecharge.Color := COLOR_CARD;
  
  FLblRechargeTitle := TLabel.Create(Self);
  FLblRechargeTitle.Parent := FPnlRecharge;
  FLblRechargeTitle.Caption := '选择充值金额';
  FLblRechargeTitle.Font.Size := 12;
  FLblRechargeTitle.Font.Style := [fsBold];
  
  // Recharge option buttons
  for I := 0 to 5 do
  begin
    FRechargeButtons[I] := TPanel.Create(Self);
    FRechargeButtons[I].Parent := FPnlRecharge;
    FRechargeButtons[I].BevelOuter := bvNone;
    FRechargeButtons[I].Color := COLOR_CARD;
    FRechargeButtons[I].Tag := I;
    FRechargeButtons[I].Cursor := crHandPoint;
    FRechargeButtons[I].OnClick := HandleRechargeOptionClick;
    
    FRechargeLabels[I] := TLabel.Create(Self);
    FRechargeLabels[I].Parent := FRechargeButtons[I];
    FRechargeLabels[I].Font.Size := 14;
    FRechargeLabels[I].Font.Style := [fsBold];
    FRechargeLabels[I].Cursor := crHandPoint;
    if I < 5 then
      FRechargeLabels[I].Caption := Format('¥%.0f', [RECHARGE_AMOUNTS[I]])
    else
      FRechargeLabels[I].Caption := '自定义';
    
    FRechargeBonusLabels[I] := TLabel.Create(Self);
    FRechargeBonusLabels[I].Parent := FRechargeButtons[I];
    FRechargeBonusLabels[I].Font.Size := 8;
    FRechargeBonusLabels[I].Font.Color := COLOR_SUCCESS;
    FRechargeBonusLabels[I].Cursor := crHandPoint;
  end;
  
  // Custom amount
  FLblCustomAmount := TLabel.Create(Self);
  FLblCustomAmount.Parent := FPnlRecharge;
  FLblCustomAmount.Caption := '自定义金额：';
  FLblCustomAmount.Visible := False;
  
  FEdtCustomAmount := TEdit.Create(Self);
  FEdtCustomAmount.Parent := FPnlRecharge;
  FEdtCustomAmount.Visible := False;
  FEdtCustomAmount.OnChange := HandleCustomAmountChange;
  
  // Payment Methods
  FPnlPayment := TPanel.Create(Self);
  FPnlPayment.Parent := FPnlMain;
  FPnlPayment.BevelOuter := bvNone;
  FPnlPayment.Color := COLOR_CARD;
  
  FLblPaymentTitle := TLabel.Create(Self);
  FLblPaymentTitle.Parent := FPnlPayment;
  FLblPaymentTitle.Caption := '选择支付方式';
  FLblPaymentTitle.Font.Size := 12;
  FLblPaymentTitle.Font.Style := [fsBold];
  
  FBtnAlipay := TPanel.Create(Self);
  FBtnAlipay.Parent := FPnlPayment;
  FBtnAlipay.BevelOuter := bvNone;
  FBtnAlipay.Color := COLOR_CARD;
  FBtnAlipay.Tag := 1;
  FBtnAlipay.Cursor := crHandPoint;
  FBtnAlipay.OnClick := HandlePaymentMethodClick;
  
  FLblAlipay := TLabel.Create(Self);
  FLblAlipay.Parent := FBtnAlipay;
  FLblAlipay.Caption := '支付宝';
  FLblAlipay.Font.Size := 11;
  FLblAlipay.Cursor := crHandPoint;
  
  FBtnWechat := TPanel.Create(Self);
  FBtnWechat.Parent := FPnlPayment;
  FBtnWechat.BevelOuter := bvNone;
  FBtnWechat.Color := COLOR_CARD;
  FBtnWechat.Tag := 2;
  FBtnWechat.Cursor := crHandPoint;
  FBtnWechat.OnClick := HandlePaymentMethodClick;
  
  FLblWechat := TLabel.Create(Self);
  FLblWechat.Parent := FBtnWechat;
  FLblWechat.Caption := '微信支付';
  FLblWechat.Font.Size := 11;
  FLblWechat.Cursor := crHandPoint;
  
  // Recharge button
  FBtnRecharge := TButton.Create(Self);
  FBtnRecharge.Parent := FPnlPayment;
  FBtnRecharge.Caption := '立即充值';
  FBtnRecharge.Enabled := False;
  FBtnRecharge.OnClick := HandleRechargeClick;
  
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FPnlPayment;
  FLblStatus.Caption := '';
  FLblStatus.WordWrap := True;
  
  // Transaction History
  FPnlHistory := TPanel.Create(Self);
  FPnlHistory.Parent := FPnlMain;
  FPnlHistory.BevelOuter := bvNone;
  FPnlHistory.Color := COLOR_CARD;
  
  FLblHistoryTitle := TLabel.Create(Self);
  FLblHistoryTitle.Parent := FPnlHistory;
  FLblHistoryTitle.Caption := '交易记录';
  FLblHistoryTitle.Font.Size := 12;
  FLblHistoryTitle.Font.Style := [fsBold];
  
  FBtnRefresh := TButton.Create(Self);
  FBtnRefresh.Parent := FPnlHistory;
  FBtnRefresh.Caption := '刷新';
  FBtnRefresh.OnClick := HandleRefreshClick;
  
  FLvTransactions := TListView.Create(Self);
  FLvTransactions.Parent := FPnlHistory;
  FLvTransactions.ViewStyle := vsReport;
  FLvTransactions.RowSelect := True;
  FLvTransactions.ReadOnly := True;
  FLvTransactions.GridLines := True;
  with FLvTransactions.Columns.Add do begin Caption := '时间'; Width := 140; end;
  with FLvTransactions.Columns.Add do begin Caption := '类型'; Width := 80; end;
  with FLvTransactions.Columns.Add do begin Caption := '金额'; Width := 100; end;
  with FLvTransactions.Columns.Add do begin Caption := '余额'; Width := 100; end;
  with FLvTransactions.Columns.Add do begin Caption := '说明'; Width := 150; end;
end;

procedure TBalanceFrame.LayoutControls;
var
  I, BtnLeft, BtnTop: Integer;
begin
  // Balance card
  FPnlBalance.SetBounds(20, 10, 250, 100);
  FLblBalanceTitle.SetBounds(20, 15, 100, 20);
  FLblBalanceCurrency.SetBounds(20, 45, 30, 35);
  FLblBalanceValue.SetBounds(45, 40, 180, 45);
  
  // Recharge section
  FPnlRecharge.SetBounds(20, 120, 400, 200);
  FLblRechargeTitle.SetBounds(15, 15, 150, 22);
  
  // Recharge buttons - 3x2 grid
  for I := 0 to 5 do
  begin
    BtnLeft := 15 + (I mod 3) * 125;
    BtnTop := 50 + (I div 3) * 60;
    FRechargeButtons[I].SetBounds(BtnLeft, BtnTop, 115, 50);
    FRechargeLabels[I].SetBounds(10, 8, 95, 22);
    FRechargeBonusLabels[I].SetBounds(10, 30, 95, 14);
  end;
  
  FLblCustomAmount.SetBounds(15, 175, 80, 18);
  FEdtCustomAmount.SetBounds(100, 172, 120, 24);
  
  // Payment methods
  FPnlPayment.SetBounds(20, 330, 400, 130);
  FLblPaymentTitle.SetBounds(15, 15, 150, 22);
  FBtnAlipay.SetBounds(15, 45, 180, 40);
  FLblAlipay.SetBounds(60, 10, 80, 20);
  FBtnWechat.SetBounds(205, 45, 180, 40);
  FLblWechat.SetBounds(60, 10, 80, 20);
  FBtnRecharge.SetBounds(15, 95, 180, 32);
  FLblStatus.SetBounds(205, 95, 180, 32);
  
  // Transaction history
  FPnlHistory.SetBounds(440, 10, 240, 450);
  FLblHistoryTitle.SetBounds(15, 15, 100, 22);
  FBtnRefresh.SetBounds(160, 12, 60, 24);
  FLvTransactions.SetBounds(10, 45, 220, 395);
end;

procedure TBalanceFrame.ApplyStyle;
var
  I: Integer;
begin
  FPnlBalance.Color := COLOR_PRIMARY;
  
  for I := 0 to 5 do
  begin
    FRechargeButtons[I].Color := COLOR_CARD;
    FRechargeButtons[I].BorderWidth := 1;
  end;
  
  FBtnAlipay.BorderWidth := 1;
  FBtnWechat.BorderWidth := 1;
  
  FBtnRecharge.Font.Size := 11;
  FBtnRecharge.Font.Style := [fsBold];
end;

procedure TBalanceFrame.HandleRechargeOptionClick(Sender: TObject);
begin
  FSelectedRechargeIndex := TPanel(Sender).Tag;
  UpdateRechargeSelection;
  
  // Show/hide custom amount input
  FLblCustomAmount.Visible := (FSelectedRechargeIndex = 5);
  FEdtCustomAmount.Visible := (FSelectedRechargeIndex = 5);
  
  // Update button state
  FBtnRecharge.Enabled := (FSelectedRechargeIndex >= 0) and 
                          (FSelectedPaymentMethod <> '') and
                          ((FSelectedRechargeIndex < 5) or (StrToCurrDef(FEdtCustomAmount.Text, 0) > 0));
end;

procedure TBalanceFrame.HandlePaymentMethodClick(Sender: TObject);
begin
  if TPanel(Sender).Tag = 1 then
    FSelectedPaymentMethod := 'alipay'
  else
    FSelectedPaymentMethod := 'wechat';
  
  UpdatePaymentSelection;
  
  FBtnRecharge.Enabled := (FSelectedRechargeIndex >= 0) and 
                          (FSelectedPaymentMethod <> '') and
                          ((FSelectedRechargeIndex < 5) or (StrToCurrDef(FEdtCustomAmount.Text, 0) > 0));
end;

procedure TBalanceFrame.HandleCustomAmountChange(Sender: TObject);
begin
  FBtnRecharge.Enabled := (FSelectedRechargeIndex = 5) and 
                          (FSelectedPaymentMethod <> '') and
                          (StrToCurrDef(FEdtCustomAmount.Text, 0) > 0);
end;

procedure TBalanceFrame.UpdateRechargeSelection;
var
  I: Integer;
begin
  for I := 0 to 5 do
  begin
    if I = FSelectedRechargeIndex then
      FRechargeButtons[I].Color := COLOR_SELECTED
    else
      FRechargeButtons[I].Color := COLOR_CARD;
  end;
end;

procedure TBalanceFrame.UpdatePaymentSelection;
begin
  if FSelectedPaymentMethod = 'alipay' then
  begin
    FBtnAlipay.Color := COLOR_SELECTED;
    FBtnWechat.Color := COLOR_CARD;
  end
  else if FSelectedPaymentMethod = 'wechat' then
  begin
    FBtnAlipay.Color := COLOR_CARD;
    FBtnWechat.Color := COLOR_SELECTED;
  end;
end;

procedure TBalanceFrame.HandleRechargeClick(Sender: TObject);
var
  Amount: Currency;
  PaymentUrl: string;
begin
  if not Assigned(FApiClient) then
  begin
    UpdateStatus('API客户端未初始化', True);
    Exit;
  end;
  
  if FSelectedRechargeIndex < 5 then
    Amount := RECHARGE_AMOUNTS[FSelectedRechargeIndex]
  else
    Amount := StrToCurrDef(FEdtCustomAmount.Text, 0);
  
  if Amount <= 0 then
  begin
    UpdateStatus('请选择或输入充值金额', True);
    Exit;
  end;
  
  FBtnRecharge.Enabled := False;
  UpdateStatus('正在创建订单...', False);
  
  try
    PaymentUrl := FApiClient.CreateRechargeOrder(Amount, FSelectedPaymentMethod);
    if PaymentUrl <> '' then
    begin
      ShellExecute(0, 'open', PChar(PaymentUrl), nil, nil, SW_SHOWNORMAL);
      UpdateStatus('已打开支付页面，请完成支付', False);
      FLblStatus.Font.Color := COLOR_SUCCESS;
    end
    else
      UpdateStatus('创建订单失败', True);
  except
    on E: Exception do
      UpdateStatus('充值出错: ' + E.Message, True);
  end;
  
  FBtnRecharge.Enabled := True;
end;

procedure TBalanceFrame.HandleRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TBalanceFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
  if Assigned(FApiClient) then
    RefreshData;
end;

procedure TBalanceFrame.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := COLOR_ERROR
  else
    FLblStatus.Font.Color := COLOR_TEXT_GRAY;
end;

procedure TBalanceFrame.LoadBalance;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FBalance := FApiClient.GetBalance;
    FLblBalanceValue.Caption := FormatFloat('#,##0.00', FBalance.AvailableAmount);
  except
    on E: Exception do
      UpdateStatus('加载余额失败', True);
  end;
end;

procedure TBalanceFrame.LoadRechargeOptions;
var
  I: Integer;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FRechargeOptions := FApiClient.GetRechargeOptions;
    
    // Update bonus labels
    for I := 0 to Min(Length(FRechargeOptions), 5) - 1 do
    begin
      if FRechargeOptions[I].Bonus > 0 then
        FRechargeBonusLabels[I].Caption := Format('+¥%.0f', [FRechargeOptions[I].Bonus])
      else
        FRechargeBonusLabels[I].Caption := '';
    end;
  except
    // Ignore errors, use default options
  end;
end;

procedure TBalanceFrame.LoadTransactions;
var
  Transactions: TAipexTransactions;
  I: Integer;
  Item: TListItem;
  TypeStr: string;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    Transactions := FApiClient.GetTransactions(1, 20);
    
    FLvTransactions.Items.BeginUpdate;
    try
      FLvTransactions.Items.Clear;
      for I := 0 to Length(Transactions) - 1 do
      begin
        Item := FLvTransactions.Items.Add;
        Item.Caption := FormatDateTime('yyyy-mm-dd hh:nn', Transactions[I].CreatedAt);
        
        case LowerCase(Transactions[I].TransactionType)[1] of
          'r': TypeStr := '充值';
          'c': TypeStr := '消费';
          else TypeStr := Transactions[I].TransactionType;
        end;
        Item.SubItems.Add(TypeStr);
        
        if Transactions[I].Amount >= 0 then
          Item.SubItems.Add('+' + FormatFloat('#,##0.00', Transactions[I].Amount))
        else
          Item.SubItems.Add(FormatFloat('#,##0.00', Transactions[I].Amount));
        
        Item.SubItems.Add(FormatFloat('#,##0.00', Transactions[I].Balance));
        Item.SubItems.Add(Transactions[I].Description);
      end;
    finally
      FLvTransactions.Items.EndUpdate;
    end;
  except
    on E: Exception do
      UpdateStatus('加载交易记录失败', True);
  end;
end;

procedure TBalanceFrame.RefreshData;
begin
  LoadBalance;
  LoadRechargeOptions;
  LoadTransactions;
end;

end.
