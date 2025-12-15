{ ============================================================================
  UniBase.FMX.LoginDialog - FMX 用户登录对话框
  
  Version: 1.0
  Description: Modern FMX login dialog with email/password, remember me option,
               and forgot password link.
  ============================================================================ }

unit UniBase.FMX.LoginDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Effects, FMX.Graphics,
  UniBase.AipexBase.Client;

type
  TFMXLoginDialog = class(TForm)
  private
    FLayoutMain: TLayout;
    FRectHeader: TRectangle;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FRectContent: TRectangle;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblPassword: TLabel;
    FEdtPassword: TEdit;
    FChkRememberMe: TCheckBox;
    FLblForgotPassword: TLabel;
    FLblStatus: TLabel;
    FBtnLogin: TButton;
    FLblRegister: TLabel;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FLoginResult: TAipexLoginResult;
    FOnForgotPassword: TNotifyEvent;
    FOnRegister: TNotifyEvent;
    
    procedure CreateControls;
    procedure HandleLoginClick(Sender: TObject);
    procedure HandleRegisterClick(Sender: TObject);
    procedure HandleForgotPasswordClick(Sender: TObject);
    procedure HandleInputChange(Sender: TObject);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure SetButtonEnabled;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    class function Execute(AClient: TAipexBaseClient = nil): Boolean; overload;
    class function Execute(const ABaseURL: string): Boolean; overload;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property LoginResult: TAipexLoginResult read FLoginResult;
    property OnForgotPassword: TNotifyEvent read FOnForgotPassword write FOnForgotPassword;
    property OnRegister: TNotifyEvent read FOnRegister write FOnRegister;
  end;

implementation

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_ERROR: TAlphaColor = $FFFF0000;
  COLOR_SUCCESS: TAlphaColor = $FF00AA00;

{ TFMXLoginDialog }

constructor TFMXLoginDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '用户登录';
  ClientWidth := 400;
  ClientHeight := 500;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;
  Fill.Color := COLOR_BG;
  Fill.Kind := TBrushKind.Solid;
  
  FOwnsClient := True;
  FApiClient := nil;
  
  CreateControls;
end;

destructor TFMXLoginDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TFMXLoginDialog.CreateControls;
begin
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  
  // Header
  FRectHeader := TRectangle.Create(Self);
  FRectHeader.Parent := FLayoutMain;
  FRectHeader.Align := TAlignLayout.Top;
  FRectHeader.Height := 100;
  FRectHeader.Fill.Color := COLOR_PRIMARY;
  FRectHeader.Stroke.Kind := TBrushKind.None;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FRectHeader;
  FLblTitle.Text := '欢迎回来';
  FLblTitle.Position.X := 40;
  FLblTitle.Position.Y := 25;
  FLblTitle.StyledSettings := [];
  FLblTitle.TextSettings.Font.Size := 22;
  FLblTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblTitle.TextSettings.FontColor := TAlphaColors.White;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FRectHeader;
  FLblSubtitle.Text := '请登录您的账户';
  FLblSubtitle.Position.X := 40;
  FLblSubtitle.Position.Y := 60;
  FLblSubtitle.StyledSettings := [];
  FLblSubtitle.TextSettings.Font.Size := 12;
  FLblSubtitle.TextSettings.FontColor := $FFFFFFCC;
  
  // Content
  FRectContent := TRectangle.Create(Self);
  FRectContent.Parent := FLayoutMain;
  FRectContent.Position.X := 30;
  FRectContent.Position.Y := 110;
  FRectContent.Width := 340;
  FRectContent.Height := 380;
  FRectContent.Fill.Color := TAlphaColors.White;
  FRectContent.Stroke.Kind := TBrushKind.None;
  FRectContent.XRadius := 8;
  FRectContent.YRadius := 8;
  
  // Email
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FRectContent;
  FLblEmail.Text := '邮箱地址';
  FLblEmail.Position.X := 25;
  FLblEmail.Position.Y := 25;
  FLblEmail.StyledSettings := [];
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FRectContent;
  FEdtEmail.Position.X := 25;
  FEdtEmail.Position.Y := 50;
  FEdtEmail.Width := 290;
  FEdtEmail.Height := 36;
  FEdtEmail.OnChange := HandleInputChange;
  FEdtEmail.OnKeyDown := HandleKeyDown;
  
  // Password
  FLblPassword := TLabel.Create(Self);
  FLblPassword.Parent := FRectContent;
  FLblPassword.Text := '密码';
  FLblPassword.Position.X := 25;
  FLblPassword.Position.Y := 100;
  FLblPassword.StyledSettings := [];
  
  FEdtPassword := TEdit.Create(Self);
  FEdtPassword.Parent := FRectContent;
  FEdtPassword.Position.X := 25;
  FEdtPassword.Position.Y := 125;
  FEdtPassword.Width := 290;
  FEdtPassword.Height := 36;
  FEdtPassword.Password := True;
  FEdtPassword.OnChange := HandleInputChange;
  FEdtPassword.OnKeyDown := HandleKeyDown;
  
  // Remember Me & Forgot Password
  FChkRememberMe := TCheckBox.Create(Self);
  FChkRememberMe.Parent := FRectContent;
  FChkRememberMe.Text := '记住我';
  FChkRememberMe.Position.X := 25;
  FChkRememberMe.Position.Y := 175;
  
  FLblForgotPassword := TLabel.Create(Self);
  FLblForgotPassword.Parent := FRectContent;
  FLblForgotPassword.Text := '忘记密码?';
  FLblForgotPassword.Position.X := 230;
  FLblForgotPassword.Position.Y := 177;
  FLblForgotPassword.StyledSettings := [];
  FLblForgotPassword.TextSettings.FontColor := COLOR_PRIMARY;
  FLblForgotPassword.Cursor := crHandPoint;
  FLblForgotPassword.HitTest := True;
  FLblForgotPassword.OnClick := HandleForgotPasswordClick;
  
  // Status
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FRectContent;
  FLblStatus.Text := '';
  FLblStatus.Position.X := 25;
  FLblStatus.Position.Y := 210;
  FLblStatus.Width := 290;
  FLblStatus.Height := 40;
  FLblStatus.StyledSettings := [];
  FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
  FLblStatus.TextSettings.WordWrap := True;
  
  // Login Button
  FBtnLogin := TButton.Create(Self);
  FBtnLogin.Parent := FRectContent;
  FBtnLogin.Text := '登 录';
  FBtnLogin.Position.X := 25;
  FBtnLogin.Position.Y := 260;
  FBtnLogin.Width := 290;
  FBtnLogin.Height := 44;
  FBtnLogin.Enabled := False;
  FBtnLogin.OnClick := HandleLoginClick;
  
  // Register Link
  FLblRegister := TLabel.Create(Self);
  FLblRegister.Parent := FRectContent;
  FLblRegister.Text := '没有账户? 立即注册';
  FLblRegister.Position.X := 100;
  FLblRegister.Position.Y := 320;
  FLblRegister.StyledSettings := [];
  FLblRegister.TextSettings.FontColor := COLOR_PRIMARY;
  FLblRegister.Cursor := crHandPoint;
  FLblRegister.HitTest := True;
  FLblRegister.OnClick := HandleRegisterClick;
end;

procedure TFMXLoginDialog.HandleInputChange(Sender: TObject);
begin
  FLblStatus.Text := '';
  SetButtonEnabled;
end;

procedure TFMXLoginDialog.HandleKeyDown(Sender: TObject; var Key: Word; 
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    if FBtnLogin.Enabled then
      HandleLoginClick(FBtnLogin);
  end;
end;

procedure TFMXLoginDialog.SetButtonEnabled;
begin
  FBtnLogin.Enabled := (Trim(FEdtEmail.Text) <> '') and 
                       (Trim(FEdtPassword.Text) <> '');
end;

procedure TFMXLoginDialog.HandleLoginClick(Sender: TObject);
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
    FLoginResult := FApiClient.Login(Email, Password, FChkRememberMe.IsChecked);
    
    if FLoginResult.Success then
    begin
      UpdateStatus('登录成功!', False);
      FLblStatus.TextSettings.FontColor := COLOR_SUCCESS;
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

procedure TFMXLoginDialog.HandleRegisterClick(Sender: TObject);
begin
  if Assigned(FOnRegister) then
    FOnRegister(Self)
  else
    ModalResult := mrRetry;
end;

procedure TFMXLoginDialog.HandleForgotPasswordClick(Sender: TObject);
begin
  if Assigned(FOnForgotPassword) then
    FOnForgotPassword(Self)
  else
    ModalResult := mrIgnore;
end;

procedure TFMXLoginDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TFMXLoginDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Text := Msg;
  if IsError then
    FLblStatus.TextSettings.FontColor := COLOR_ERROR
  else
    FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
end;

class function TFMXLoginDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TFMXLoginDialog;
begin
  Dlg := TFMXLoginDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TFMXLoginDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TFMXLoginDialog;
begin
  Dlg := TFMXLoginDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
