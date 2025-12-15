{ ============================================================================
  UniBase.FMX.BalanceFrame - FMX 余额/充值 Frame
  
  Version: 1.0
  Description: Modern FMX balance frame with balance display, recharge options,
               payment methods, and transaction history.
  ============================================================================ }

unit UniBase.FMX.BalanceFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections,
  System.Math,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics, FMX.ListView, FMX.ListView.Types,
  FMX.ListView.Appearances, FMX.ListView.Adapters.Base,
  UniBase.AipexBase.Client;

type
  TFMXBalanceFrame = class(TFrame)
  private
    FLayoutMain: TLayout;
    // Balance card
    FRectBalance: TRectangle;
    FLblBalanceTitle: TLabel;
    FLblBalanceValue: TLabel;
    FLblBalanceUnit: TLabel;
    // Recharge section
    FLblRechargeTitle: TLabel;
    FLayoutAmounts: TLayout;
    FBtnAmount50: TButton;
    FBtnAmount100: TButton;
    FBtnAmount200: TButton;
    FBtnAmount500: TButton;
    FBtnAmount1000: TButton;
    FEdtCustomAmount: TEdit;
    FLblCustomHint: TLabel;
    // Payment methods
    FLblPaymentTitle: TLabel;
    FLayoutPayment: TLayout;
    FBtnAlipay: TButton;
    FBtnWechat: TButton;
    FBtnRecharge: TButton;
    // Transaction history
    FLblHistoryTitle: TLabel;
    FListHistory: TListView;
    
    FApiClient: TAipexBaseClient;
    FBalance: TAipexBalance;
    FSelectedAmount: Double;
    FSelectedPayment: string;
    FOnRecharge: TNotifyEvent;
    
    procedure CreateControls;
    procedure CreateBalanceCard;
    procedure CreateRechargeSection;
    procedure CreatePaymentSection;
    procedure CreateHistorySection;
    procedure HandleAmountClick(Sender: TObject);
    procedure HandlePaymentClick(Sender: TObject);
    procedure HandleRechargeClick(Sender: TObject);
    procedure HandleCustomAmountChange(Sender: TObject);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure SetBalance(const Value: TAipexBalance);
    procedure UpdateAmountButtons;
    procedure UpdatePaymentButtons;
    procedure PopulateBalance;
    procedure PopulateHistory;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property Balance: TAipexBalance read FBalance write SetBalance;
    property OnRecharge: TNotifyEvent read FOnRecharge write FOnRecharge;
  end;

implementation

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_GOLD: TAlphaColor = $FFFFD700;
  COLOR_SUCCESS: TAlphaColor = $FF00AA00;
  COLOR_ERROR: TAlphaColor = $FFFF0000;

{ TFMXBalanceFrame }

constructor TFMXBalanceFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 700;
  Height := 550;
  FSelectedAmount := 100;
  FSelectedPayment := 'alipay';
  
  CreateControls;
end;

destructor TFMXBalanceFrame.Destroy;
begin
  inherited;
end;

procedure TFMXBalanceFrame.CreateControls;
begin
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  FLayoutMain.Padding.Left := 20;
  FLayoutMain.Padding.Right := 20;
  FLayoutMain.Padding.Top := 20;
  FLayoutMain.Padding.Bottom := 20;
  
  CreateBalanceCard;
  CreateRechargeSection;
  CreatePaymentSection;
  CreateHistorySection;
end;

procedure TFMXBalanceFrame.CreateBalanceCard;
begin
  FRectBalance := TRectangle.Create(Self);
  FRectBalance.Parent := FLayoutMain;
  FRectBalance.Position.X := 0;
  FRectBalance.Position.Y := 0;
  FRectBalance.Width := 300;
  FRectBalance.Height := 140;
  FRectBalance.Fill.Color := COLOR_PRIMARY;
  FRectBalance.Stroke.Kind := TBrushKind.None;
  FRectBalance.XRadius := 12;
  FRectBalance.YRadius := 12;
  
  FLblBalanceTitle := TLabel.Create(Self);
  FLblBalanceTitle.Parent := FRectBalance;
  FLblBalanceTitle.Text := '账户余额';
  FLblBalanceTitle.Position.X := 25;
  FLblBalanceTitle.Position.Y := 20;
  FLblBalanceTitle.StyledSettings := [];
  FLblBalanceTitle.TextSettings.Font.Size := 14;
  FLblBalanceTitle.TextSettings.FontColor := $FFFFFFCC;
  
  FLblBalanceValue := TLabel.Create(Self);
  FLblBalanceValue.Parent := FRectBalance;
  FLblBalanceValue.Text := '0.00';
  FLblBalanceValue.Position.X := 25;
  FLblBalanceValue.Position.Y := 50;
  FLblBalanceValue.StyledSettings := [];
  FLblBalanceValue.TextSettings.Font.Size := 36;
  FLblBalanceValue.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblBalanceValue.TextSettings.FontColor := TAlphaColors.White;
  
  FLblBalanceUnit := TLabel.Create(Self);
  FLblBalanceUnit.Parent := FRectBalance;
  FLblBalanceUnit.Text := '元';
  FLblBalanceUnit.Position.X := 180;
  FLblBalanceUnit.Position.Y := 70;
  FLblBalanceUnit.StyledSettings := [];
  FLblBalanceUnit.TextSettings.Font.Size := 14;
  FLblBalanceUnit.TextSettings.FontColor := $FFFFFFCC;
end;

procedure TFMXBalanceFrame.CreateRechargeSection;
begin
  FLblRechargeTitle := TLabel.Create(Self);
  FLblRechargeTitle.Parent := FLayoutMain;
  FLblRechargeTitle.Text := '选择充值金额';
  FLblRechargeTitle.Position.X := 0;
  FLblRechargeTitle.Position.Y := 160;
  FLblRechargeTitle.StyledSettings := [];
  FLblRechargeTitle.TextSettings.Font.Size := 14;
  FLblRechargeTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FLayoutAmounts := TLayout.Create(Self);
  FLayoutAmounts.Parent := FLayoutMain;
  FLayoutAmounts.Position.X := 0;
  FLayoutAmounts.Position.Y := 190;
  FLayoutAmounts.Width := 660;
  FLayoutAmounts.Height := 50;
  
  FBtnAmount50 := TButton.Create(Self);
  FBtnAmount50.Parent := FLayoutAmounts;
  FBtnAmount50.Text := '¥50';
  FBtnAmount50.Position.X := 0;
  FBtnAmount50.Position.Y := 0;
  FBtnAmount50.Width := 80;
  FBtnAmount50.Height := 40;
  FBtnAmount50.Tag := 50;
  FBtnAmount50.OnClick := HandleAmountClick;
  
  FBtnAmount100 := TButton.Create(Self);
  FBtnAmount100.Parent := FLayoutAmounts;
  FBtnAmount100.Text := '¥100';
  FBtnAmount100.Position.X := 90;
  FBtnAmount100.Position.Y := 0;
  FBtnAmount100.Width := 80;
  FBtnAmount100.Height := 40;
  FBtnAmount100.Tag := 100;
  FBtnAmount100.OnClick := HandleAmountClick;
  
  FBtnAmount200 := TButton.Create(Self);
  FBtnAmount200.Parent := FLayoutAmounts;
  FBtnAmount200.Text := '¥200';
  FBtnAmount200.Position.X := 180;
  FBtnAmount200.Position.Y := 0;
  FBtnAmount200.Width := 80;
  FBtnAmount200.Height := 40;
  FBtnAmount200.Tag := 200;
  FBtnAmount200.OnClick := HandleAmountClick;
  
  FBtnAmount500 := TButton.Create(Self);
  FBtnAmount500.Parent := FLayoutAmounts;
  FBtnAmount500.Text := '¥500';
  FBtnAmount500.Position.X := 270;
  FBtnAmount500.Position.Y := 0;
  FBtnAmount500.Width := 80;
  FBtnAmount500.Height := 40;
  FBtnAmount500.Tag := 500;
  FBtnAmount500.OnClick := HandleAmountClick;
  
  FBtnAmount1000 := TButton.Create(Self);
  FBtnAmount1000.Parent := FLayoutAmounts;
  FBtnAmount1000.Text := '¥1000';
  FBtnAmount1000.Position.X := 360;
  FBtnAmount1000.Position.Y := 0;
  FBtnAmount1000.Width := 80;
  FBtnAmount1000.Height := 40;
  FBtnAmount1000.Tag := 1000;
  FBtnAmount1000.OnClick := HandleAmountClick;
  
  FEdtCustomAmount := TEdit.Create(Self);
  FEdtCustomAmount.Parent := FLayoutAmounts;
  FEdtCustomAmount.Position.X := 460;
  FEdtCustomAmount.Position.Y := 0;
  FEdtCustomAmount.Width := 100;
  FEdtCustomAmount.Height := 40;
  FEdtCustomAmount.TextPrompt := '自定义';
  FEdtCustomAmount.OnChange := HandleCustomAmountChange;
  
  FLblCustomHint := TLabel.Create(Self);
  FLblCustomHint.Parent := FLayoutAmounts;
  FLblCustomHint.Text := '元';
  FLblCustomHint.Position.X := 565;
  FLblCustomHint.Position.Y := 10;
  FLblCustomHint.StyledSettings := [];
  FLblCustomHint.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  UpdateAmountButtons;
end;

procedure TFMXBalanceFrame.CreatePaymentSection;
begin
  FLblPaymentTitle := TLabel.Create(Self);
  FLblPaymentTitle.Parent := FLayoutMain;
  FLblPaymentTitle.Text := '选择支付方式';
  FLblPaymentTitle.Position.X := 0;
  FLblPaymentTitle.Position.Y := 255;
  FLblPaymentTitle.StyledSettings := [];
  FLblPaymentTitle.TextSettings.Font.Size := 14;
  FLblPaymentTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FLayoutPayment := TLayout.Create(Self);
  FLayoutPayment.Parent := FLayoutMain;
  FLayoutPayment.Position.X := 0;
  FLayoutPayment.Position.Y := 285;
  FLayoutPayment.Width := 400;
  FLayoutPayment.Height := 50;
  
  FBtnAlipay := TButton.Create(Self);
  FBtnAlipay.Parent := FLayoutPayment;
  FBtnAlipay.Text := '支付宝';
  FBtnAlipay.Position.X := 0;
  FBtnAlipay.Position.Y := 0;
  FBtnAlipay.Width := 120;
  FBtnAlipay.Height := 40;
  FBtnAlipay.TagString := 'alipay';
  FBtnAlipay.OnClick := HandlePaymentClick;
  
  FBtnWechat := TButton.Create(Self);
  FBtnWechat.Parent := FLayoutPayment;
  FBtnWechat.Text := '微信支付';
  FBtnWechat.Position.X := 130;
  FBtnWechat.Position.Y := 0;
  FBtnWechat.Width := 120;
  FBtnWechat.Height := 40;
  FBtnWechat.TagString := 'wechat';
  FBtnWechat.OnClick := HandlePaymentClick;
  
  FBtnRecharge := TButton.Create(Self);
  FBtnRecharge.Parent := FLayoutPayment;
  FBtnRecharge.Text := '立即充值';
  FBtnRecharge.Position.X := 280;
  FBtnRecharge.Position.Y := 0;
  FBtnRecharge.Width := 120;
  FBtnRecharge.Height := 40;
  FBtnRecharge.OnClick := HandleRechargeClick;
  
  UpdatePaymentButtons;
end;

procedure TFMXBalanceFrame.CreateHistorySection;
begin
  FLblHistoryTitle := TLabel.Create(Self);
  FLblHistoryTitle.Parent := FLayoutMain;
  FLblHistoryTitle.Text := '交易记录';
  FLblHistoryTitle.Position.X := 0;
  FLblHistoryTitle.Position.Y := 350;
  FLblHistoryTitle.StyledSettings := [];
  FLblHistoryTitle.TextSettings.Font.Size := 14;
  FLblHistoryTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FListHistory := TListView.Create(Self);
  FListHistory.Parent := FLayoutMain;
  FListHistory.Position.X := 0;
  FListHistory.Position.Y := 380;
  FListHistory.Width := 660;
  FListHistory.Height := 150;
  FListHistory.ItemAppearanceClassName := 'TListItemAppearance';
  FListHistory.ItemAppearance.ItemAppearance := 'ListItem';
end;

procedure TFMXBalanceFrame.HandleAmountClick(Sender: TObject);
begin
  FSelectedAmount := TButton(Sender).Tag;
  FEdtCustomAmount.Text := '';
  UpdateAmountButtons;
end;

procedure TFMXBalanceFrame.HandleCustomAmountChange(Sender: TObject);
var
  Val: Double;
begin
  if TryStrToFloat(FEdtCustomAmount.Text, Val) and (Val > 0) then
  begin
    FSelectedAmount := Val;
    UpdateAmountButtons;
  end;
end;

procedure TFMXBalanceFrame.HandlePaymentClick(Sender: TObject);
begin
  FSelectedPayment := TButton(Sender).TagString;
  UpdatePaymentButtons;
end;

procedure TFMXBalanceFrame.HandleRechargeClick(Sender: TObject);
begin
  if FSelectedAmount <= 0 then
    Exit;
    
  if not Assigned(FApiClient) then
    Exit;
    
  try
    FApiClient.CreateRecharge(FSelectedAmount, FSelectedPayment);
    if Assigned(FOnRecharge) then
      FOnRecharge(Self);
  except
    // Handle error
  end;
end;

procedure TFMXBalanceFrame.UpdateAmountButtons;
  procedure SetSelected(Btn: TButton; Selected: Boolean);
  begin
    // Visual feedback for selection - simplified
    Btn.Opacity := IfThen(Selected, 1.0, 0.7);
  end;
begin
  SetSelected(FBtnAmount50, Abs(FSelectedAmount - 50) < 0.01);
  SetSelected(FBtnAmount100, Abs(FSelectedAmount - 100) < 0.01);
  SetSelected(FBtnAmount200, Abs(FSelectedAmount - 200) < 0.01);
  SetSelected(FBtnAmount500, Abs(FSelectedAmount - 500) < 0.01);
  SetSelected(FBtnAmount1000, Abs(FSelectedAmount - 1000) < 0.01);
end;

procedure TFMXBalanceFrame.UpdatePaymentButtons;
begin
  FBtnAlipay.Opacity := IfThen(FSelectedPayment = 'alipay', 1.0, 0.7);
  FBtnWechat.Opacity := IfThen(FSelectedPayment = 'wechat', 1.0, 0.7);
end;

procedure TFMXBalanceFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
end;

procedure TFMXBalanceFrame.SetBalance(const Value: TAipexBalance);
begin
  FBalance := Value;
  PopulateBalance;
  PopulateHistory;
end;

procedure TFMXBalanceFrame.PopulateBalance;
begin
  FLblBalanceValue.Text := FormatFloat('#,##0.00', FBalance.Balance);
end;

procedure TFMXBalanceFrame.PopulateHistory;
var
  I: Integer;
  Item: TListViewItem;
  Trans: TAipexTransaction;
begin
  FListHistory.Items.Clear;
  
  for I := 0 to High(FBalance.RecentTransactions) do
  begin
    Trans := FBalance.RecentTransactions[I];
    Item := FListHistory.Items.Add;
    Item.Text := Trans.Description;
    Item.Detail := FormatDateTime('yyyy-mm-dd hh:nn', Trans.CreatedAt);
    if Trans.Amount >= 0 then
      Item.ButtonText := '+' + FormatFloat('#,##0.00', Trans.Amount)
    else
      Item.ButtonText := FormatFloat('#,##0.00', Trans.Amount);
  end;
end;

procedure TFMXBalanceFrame.RefreshData;
begin
  if Assigned(FApiClient) then
  begin
    try
      FBalance := FApiClient.GetBalance;
      PopulateBalance;
      PopulateHistory;
    except
      // Silently ignore
    end;
  end;
end;

end.
