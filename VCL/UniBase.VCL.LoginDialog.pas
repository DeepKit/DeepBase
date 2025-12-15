{ ============================================================================
  UniBase.VCL.LoginDialog - 用户登录对话框
  
  Version: 1.0
  Description: Modern login dialog with email/password, remember me option,
               and forgot password link.
  ============================================================================ }

unit UniBase.VCL.LoginDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  UniBase.AipexBase.Client;

type
  TLoginDialog = class(TForm)
  private
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FPnlContent: TPanel;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblPassword: TLabel;
    FEdtPassword: TEdit;
    FChkRememberMe: TCheckBox;
    FLblForgotPassword: TLabel;
    FLblStatus: TLabel;
    FPnlButtons: TPanel;
    FBtnLogin: TButton;
    FBtnRegister: TButton;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FLoginResult: TAipexLoginResult;
    FOnForgotPassword: TNotifyEvent;
    FOnRegister: TNotifyEvent;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleLoginClick(Sender: TObject);
    procedure HandleRegisterClick(Sender: TObject);
    procedure HandleForgotPasswordClick(Sender: TObject);
    procedure HandleInputChange(Sender: TObject);
    procedure HandleKeyPress(Sender: TObject; var Key: Char);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure SetButtonEnabled;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>显示登录对话框</summary>
    class function Execute(AClient: TAipexBaseClient = nil): Boolean; overload;
    class function Execute(const ABaseURL: string): Boolean; overload;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property LoginResult: TAipexLoginResult read FLoginResult;
    property OnForgotPassword: TNotifyEvent read FOnForgotPassword write FOnForgotPassword;
    property OnRegister: TNotifyEvent read FOnRegister write FOnRegister;
  end;

implementation

uses
  Winapi.Windows, Vcl.Themes;

const
  COLOR_PRIMARY = $EAEA66;      // #667eea (BGR format)
  COLOR_PRIMARY_DARK = $A24B76; // #764ba2
  COLOR_BG = $FAF7F5;           // #f5f7fa
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_ERROR = $0000FF;        // Red
  COLOR_SUCCESS = $00AA00;      // Green

{ TLoginDialog }

constructor TLoginDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '用户登录';
  Width := 420;
  Height := 480;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  Color := COLOR_BG;
  Font.Name := 'Microsoft YaHei UI';
  Font.Size := 9;
  
  FOwnsClient := True;
  FApiClient := nil;
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
end;

destructor TLoginDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TLoginDialog.CreateControls;
begin
  // Header Panel
  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := Self;
  FPnlHeader.Align := alTop;
  FPnlHeader.Height := 100;
  FPnlHeader.BevelOuter := bvNone;
  FPnlHeader.ParentBackground := False;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlHeader;
  FLblTitle.Caption := '欢迎回来';
  FLblTitle.Font.Size := 20;
  FLblTitle.Font.Style := [fsBold];
  FLblTitle.Font.Color := clWhite;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := '请登录您的账户';
  FLblSubtitle.Font.Size := 10;
  FLblSubtitle.Font.Color := $FFFFFF;
  
  // Content Panel
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;
  FPnlContent.ParentBackground := False;
  FPnlContent.Color := clWhite;
  
  // Email
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FPnlContent;
  FLblEmail.Caption := '邮箱地址';
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FPnlContent;
  FEdtEmail.OnChange := HandleInputChange;
  FEdtEmail.OnKeyPress := HandleKeyPress;
  
  // Password
  FLblPassword := TLabel.Create(Self);
  FLblPassword.Parent := FPnlContent;
  FLblPassword.Caption := '密码';
  
  FEdtPassword := TEdit.Create(Self);
  FEdtPassword.Parent := FPnlContent;
  FEdtPassword.PasswordChar := '●';
  FEdtPassword.OnChange := HandleInputChange;
  FEdtPassword.OnKeyPress := HandleKeyPress;
  
  // Remember Me & Forgot Password
  FChkRememberMe := TCheckBox.Create(Self);
  FChkRememberMe.Parent := FPnlContent;
  FChkRememberMe.Caption := '记住我';
  
  FLblForgotPassword := TLabel.Create(Self);
  FLblForgotPassword.Parent := FPnlContent;
  FLblForgotPassword.Caption := '忘记密码?';
  FLblForgotPassword.Font.Color := COLOR_PRIMARY;
  FLblForgotPassword.Cursor := crHandPoint;
  FLblForgotPassword.OnClick := HandleForgotPasswordClick;
  
  // Status
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FPnlContent;
  FLblStatus.Caption := '';
  FLblStatus.Font.Color := COLOR_TEXT_GRAY;
  FLblStatus.WordWrap := True;
  
  // Buttons Panel
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 100;
  FPnlButtons.BevelOuter := bvNone;
  FPnlButtons.ParentBackground := False;
  FPnlButtons.Color := clWhite;
  
  FBtnLogin := TButton.Create(Self);
  FBtnLogin.Parent := FPnlButtons;
  FBtnLogin.Caption := '登 录';
  FBtnLogin.Default := True;
  FBtnLogin.Enabled := False;
  FBtnLogin.OnClick := HandleLoginClick;
  
  FBtnRegister := TButton.Create(Self);
  FBtnRegister.Parent := FPnlButtons;
  FBtnRegister.Caption := '没有账户? 立即注册';
  FBtnRegister.OnClick := HandleRegisterClick;
end;

procedure TLoginDialog.LayoutControls;
var
  ContentLeft, ContentWidth: Integer;
begin
  ContentLeft := 40;
  ContentWidth := ClientWidth - 80;
  
  // Header
  FLblTitle.SetBounds(ContentLeft, 25, 300, 30);
  FLblSubtitle.SetBounds(ContentLeft, 58, 300, 20);
  
  // Content
  FLblEmail.SetBounds(ContentLeft, 30, 100, 18);
  FEdtEmail.SetBounds(ContentLeft, 50, ContentWidth, 32);
  
  FLblPassword.SetBounds(ContentLeft, 95, 100, 18);
  FEdtPassword.SetBounds(ContentLeft, 115, ContentWidth, 32);
  
  FChkRememberMe.SetBounds(ContentLeft, 160, 100, 20);
  FLblForgotPassword.SetBounds(ContentWidth - 20, 160, 80, 20);
  
  FLblStatus.SetBounds(ContentLeft, 190, ContentWidth, 40);
  
  // Buttons
  FBtnLogin.SetBounds(ContentLeft, 15, ContentWidth, 40);
  FBtnRegister.SetBounds(ContentLeft, 65, ContentWidth, 25);
end;

procedure TLoginDialog.ApplyStyle;
begin
  // Header gradient background (simplified - solid color)
  FPnlHeader.Color := COLOR_PRIMARY;
  
  // Input styling
  FEdtEmail.Font.Size := 10;
  FEdtPassword.Font.Size := 10;
  
  // Primary button style
  FBtnLogin.Font.Size := 11;
  FBtnLogin.Font.Style := [fsBold];
  
  // Link button style
  FBtnRegister.Font.Color := COLOR_PRIMARY;
  FBtnRegister.Flat := True;
end;

procedure TLoginDialog.DoShow;
begin
  inherited;
  FEdtEmail.SetFocus;
  FLblStatus.Caption := '';
end;

procedure TLoginDialog.HandleInputChange(Sender: TObject);
begin
  FLblStatus.Caption := '';
  SetButtonEnabled;
end;

procedure TLoginDialog.HandleKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if FBtnLogin.Enabled then
      HandleLoginClick(FBtnLogin);
  end;
end;

procedure TLoginDialog.SetButtonEnabled;
begin
  FBtnLogin.Enabled := (Trim(FEdtEmail.Text) <> '') and 
                       (Trim(FEdtPassword.Text) <> '');
end;

procedure TLoginDialog.HandleLoginClick(Sender: TObject);
var
  Email, Password: string;
begin
  Email := Trim(FEdtEmail.Text);
  Password := Trim(FEdtPassword.Text);
  
  if Email = '' then
  begin
    UpdateStatus('请输入邮箱地址', True);
    FEdtEmail.SetFocus;
    Exit;
  end;
  
  if Password = '' then
  begin
    UpdateStatus('请输入密码', True);
    FEdtPassword.SetFocus;
    Exit;
  end;
  
  if not Assigned(FApiClient) then
  begin
    UpdateStatus('API客户端未初始化', True);
    Exit;
  end;
  
  FBtnLogin.Enabled := False;
  UpdateStatus('正在登录...', False);
  Application.ProcessMessages;
  
  try
    FLoginResult := FApiClient.Login(Email, Password, FChkRememberMe.Checked);
    
    if FLoginResult.Success then
    begin
      UpdateStatus('登录成功!', False);
      FLblStatus.Font.Color := COLOR_SUCCESS;
      ModalResult := mrOk;
    end
    else
    begin
      UpdateStatus(FLoginResult.ErrorMessage, True);
      if FLoginResult.ErrorMessage = '' then
        UpdateStatus('登录失败，请检查邮箱和密码', True);
      FBtnLogin.Enabled := True;
    end;
  except
    on E: EAipexBaseAuthError do
    begin
      UpdateStatus('邮箱或密码错误', True);
      FBtnLogin.Enabled := True;
    end;
    on E: Exception do
    begin
      UpdateStatus('登录出错: ' + E.Message, True);
      FBtnLogin.Enabled := True;
    end;
  end;
end;

procedure TLoginDialog.HandleRegisterClick(Sender: TObject);
begin
  if Assigned(FOnRegister) then
    FOnRegister(Self)
  else
    ModalResult := mrRetry; // Use mrRetry to indicate "go to register"
end;

procedure TLoginDialog.HandleForgotPasswordClick(Sender: TObject);
begin
  if Assigned(FOnForgotPassword) then
    FOnForgotPassword(Self)
  else
    ModalResult := mrIgnore; // Use mrIgnore to indicate "go to forgot password"
end;

procedure TLoginDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TLoginDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := COLOR_ERROR
  else
    FLblStatus.Font.Color := COLOR_TEXT_GRAY;
end;

class function TLoginDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TLoginDialog;
begin
  Dlg := TLoginDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TLoginDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TLoginDialog;
begin
  Dlg := TLoginDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
