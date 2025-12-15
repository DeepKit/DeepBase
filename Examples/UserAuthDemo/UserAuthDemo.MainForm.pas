{ ============================================================================
  UserAuthDemo.MainForm - 演示程序主窗体
  
  版本: 1.0
  说明: 展示所有用户认证和账务 UI 组件
  ============================================================================ }

unit UserAuthDemo.MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  UniBase.AipexBase.Client;

type
  TMainForm = class(TForm)
    PanelTop: TPanel;
    LblTitle: TLabel;
    LblStatus: TLabel;
    BtnLogin: TButton;
    BtnRegister: TButton;
    BtnLogout: TButton;
    PageControl: TPageControl;
    TabProfile: TTabSheet;
    TabBalance: TTabSheet;
    TabUsage: TTabSheet;
    TabBilling: TTabSheet;
    PanelConfig: TPanel;
    LblServer: TLabel;
    EdtServer: TEdit;
    BtnConnect: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure BtnConnectClick(Sender: TObject);
    procedure BtnLoginClick(Sender: TObject);
    procedure BtnRegisterClick(Sender: TObject);
    procedure BtnLogoutClick(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
  private
    FApiClient: TAipexBaseClient;
    FIsLoggedIn: Boolean;
    procedure UpdateUIState;
    procedure ClearContentPanels;
    procedure ShowProfileFrame;
    procedure ShowBalanceFrame;
    procedure ShowUsageFrame;
    procedure ShowBillingFrame;
  public
    property ApiClient: TAipexBaseClient read FApiClient;
    property IsLoggedIn: Boolean read FIsLoggedIn;
  end;

var
  MainForm: TMainForm;

implementation

uses
  UniBase.VCL.LoginDialog,
  UniBase.VCL.RegisterDialog,
  UniBase.VCL.ForgotPasswordDialog,
  UniBase.VCL.UserProfileFrame,
  UniBase.VCL.BalanceFrame,
  UniBase.VCL.UsageStatsFrame,
  UniBase.VCL.BillingFrame;

{$R *.dfm}

procedure TMainForm.FormCreate(Sender: TObject);
begin
  FApiClient := nil;
  FIsLoggedIn := False;
  
  // 设置默认服务器地址
  EdtServer.Text := 'https://dev.aipexbase.com/api';
  
  // 初始化 UI
  Caption := 'UniBase 用户认证演示 (VCL)';
  Width := 900;
  Height := 700;
  Position := poScreenCenter;
  
  UpdateUIState;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if Assigned(FApiClient) then
    FreeAndNil(FApiClient);
end;

procedure TMainForm.BtnConnectClick(Sender: TObject);
begin
  if Assigned(FApiClient) then
    FreeAndNil(FApiClient);
    
  try
    FApiClient := TAipexBaseClient.Create(Trim(EdtServer.Text));
    LblStatus.Caption := '已连接: ' + EdtServer.Text;
    LblStatus.Font.Color := clGreen;
    BtnConnect.Caption := '已连接';
    BtnConnect.Enabled := False;
    EdtServer.Enabled := False;
  except
    on E: Exception do
    begin
      LblStatus.Caption := '连接失败: ' + E.Message;
      LblStatus.Font.Color := clRed;
    end;
  end;
  
  UpdateUIState;
end;

procedure TMainForm.BtnLoginClick(Sender: TObject);
var
  LoginDlg: TVCLLoginDialog;
begin
  if not Assigned(FApiClient) then
  begin
    ShowMessage('请先连接服务器');
    Exit;
  end;
  
  LoginDlg := TVCLLoginDialog.Create(Self);
  try
    LoginDlg.ApiClient := FApiClient;
    LoginDlg.OnForgotPassword := procedure(Sender: TObject)
    begin
      LoginDlg.ModalResult := mrRetry; // 关闭登录对话框，显示找回密码
    end;
    LoginDlg.OnRegister := procedure(Sender: TObject)
    begin
      LoginDlg.ModalResult := mrYes; // 关闭登录对话框，显示注册
    end;
    
    case LoginDlg.ShowModal of
      mrOk:
        begin
          FIsLoggedIn := True;
          LblStatus.Caption := '已登录: ' + LoginDlg.LoginResult.User.Username;
          LblStatus.Font.Color := clGreen;
          UpdateUIState;
          ShowProfileFrame;
        end;
      mrRetry:
        begin
          // 显示找回密码对话框
          TVCLForgotPasswordDialog.Execute(FApiClient);
        end;
      mrYes:
        begin
          // 显示注册对话框
          BtnRegisterClick(Sender);
        end;
    end;
  finally
    LoginDlg.Free;
  end;
end;

procedure TMainForm.BtnRegisterClick(Sender: TObject);
var
  RegisterDlg: TVCLRegisterDialog;
begin
  if not Assigned(FApiClient) then
  begin
    ShowMessage('请先连接服务器');
    Exit;
  end;
  
  RegisterDlg := TVCLRegisterDialog.Create(Self);
  try
    RegisterDlg.ApiClient := FApiClient;
    if RegisterDlg.ShowModal = mrOk then
    begin
      FIsLoggedIn := True;
      LblStatus.Caption := '注册成功，已登录';
      LblStatus.Font.Color := clGreen;
      UpdateUIState;
      ShowProfileFrame;
    end;
  finally
    RegisterDlg.Free;
  end;
end;

procedure TMainForm.BtnLogoutClick(Sender: TObject);
begin
  if Assigned(FApiClient) then
  begin
    try
      FApiClient.Logout;
    except
      // 忽略登出错误
    end;
  end;
  
  FIsLoggedIn := False;
  LblStatus.Caption := '已登出';
  LblStatus.Font.Color := clGray;
  ClearContentPanels;
  UpdateUIState;
end;

procedure TMainForm.UpdateUIState;
begin
  BtnLogin.Enabled := Assigned(FApiClient) and not FIsLoggedIn;
  BtnRegister.Enabled := Assigned(FApiClient) and not FIsLoggedIn;
  BtnLogout.Enabled := FIsLoggedIn;
  PageControl.Enabled := FIsLoggedIn;
  
  if not FIsLoggedIn then
    PageControl.ActivePageIndex := 0;
end;

procedure TMainForm.ClearContentPanels;
var
  I: Integer;
begin
  for I := 0 to PageControl.PageCount - 1 do
  begin
    while PageControl.Pages[I].ControlCount > 0 do
      PageControl.Pages[I].Controls[0].Free;
  end;
end;

procedure TMainForm.PageControlChange(Sender: TObject);
begin
  if not FIsLoggedIn then Exit;
  
  case PageControl.ActivePageIndex of
    0: ShowProfileFrame;
    1: ShowBalanceFrame;
    2: ShowUsageFrame;
    3: ShowBillingFrame;
  end;
end;

procedure TMainForm.ShowProfileFrame;
var
  Frame: TVCLUserProfileFrame;
begin
  // 清除旧内容
  while TabProfile.ControlCount > 0 do
    TabProfile.Controls[0].Free;
    
  Frame := TVCLUserProfileFrame.Create(Self);
  Frame.Parent := TabProfile;
  Frame.Align := alClient;
  Frame.ApiClient := FApiClient;
  Frame.RefreshData;
end;

procedure TMainForm.ShowBalanceFrame;
var
  Frame: TVCLBalanceFrame;
begin
  while TabBalance.ControlCount > 0 do
    TabBalance.Controls[0].Free;
    
  Frame := TVCLBalanceFrame.Create(Self);
  Frame.Parent := TabBalance;
  Frame.Align := alClient;
  Frame.ApiClient := FApiClient;
  Frame.RefreshData;
end;

procedure TMainForm.ShowUsageFrame;
var
  Frame: TVCLUsageStatsFrame;
begin
  while TabUsage.ControlCount > 0 do
    TabUsage.Controls[0].Free;
    
  Frame := TVCLUsageStatsFrame.Create(Self);
  Frame.Parent := TabUsage;
  Frame.Align := alClient;
  Frame.ApiClient := FApiClient;
  Frame.RefreshData;
end;

procedure TMainForm.ShowBillingFrame;
var
  Frame: TVCLBillingFrame;
begin
  while TabBilling.ControlCount > 0 do
    TabBilling.Controls[0].Free;
    
  Frame := TVCLBillingFrame.Create(Self);
  Frame.Parent := TabBilling;
  Frame.Align := alClient;
  Frame.ApiClient := FApiClient;
  Frame.RefreshData;
end;

end.
