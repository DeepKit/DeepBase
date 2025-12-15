{ ============================================================================
  UniBase.FMX.RegisterDialog - FMX 用户注册对话框
  
  Version: 1.0
  Description: Modern FMX registration dialog with username, email, password,
               confirm password and terms agreement.
  ============================================================================ }

unit UniBase.FMX.RegisterDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics,
  UniBase.AipexBase.Client;

type
  TFMXRegisterDialog = class(TForm)
  private
    FLayoutMain: TLayout;
    FRectHeader: TRectangle;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FRectContent: TRectangle;
    FLblUsername: TLabel;
    FEdtUsername: TEdit;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblPassword: TLabel;
    FEdtPassword: TEdit;
    FRectStrength: TRectangle;
    FLblStrength: TLabel;
    FLblConfirmPassword: TLabel;
    FEdtConfirmPassword: TEdit;
    FChkAgreeTerms: TCheckBox;
    FLblTermsLink: TLabel;
    FLblStatus: TLabel;
    FBtnRegister: TButton;
    FLblLogin: TLabel;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FRegisterResult: TAipexLoginResult;
    FOnLogin: TNotifyEvent;
    FOnShowTerms: TNotifyEvent;
    
    procedure CreateControls;
    procedure HandleRegisterClick(Sender: TObject);
    procedure HandleLoginClick(Sender: TObject);
    procedure HandleTermsClick(Sender: TObject);
    procedure HandleInputChange(Sender: TObject);
    procedure HandlePasswordChange(Sender: TObject);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure UpdatePasswordStrength;
    procedure SetButtonEnabled;
    function ValidateInput: Boolean;
    function GetPasswordStrength(const Password: string): Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    class function Execute(AClient: TAipexBaseClient = nil): Boolean; overload;
    class function Execute(const ABaseURL: string): Boolean; overload;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property RegisterResult: TAipexLoginResult read FRegisterResult;
    property OnLogin: TNotifyEvent read FOnLogin write FOnLogin;
    property OnShowTerms: TNotifyEvent read FOnShowTerms write FOnShowTerms;
  end;

implementation

uses
  System.RegularExpressions;

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_ERROR: TAlphaColor = $FFFF0000;
  COLOR_SUCCESS: TAlphaColor = $FF00AA00;
  COLOR_WEAK: TAlphaColor = $FFEE5050;
  COLOR_MEDIUM: TAlphaColor = $FFFFA500;
  COLOR_STRONG: TAlphaColor = $FF00AA00;

{ TFMXRegisterDialog }

constructor TFMXRegisterDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '用户注册';
  ClientWidth := 400;
  ClientHeight := 600;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;
  Fill.Color := COLOR_BG;
  Fill.Kind := TBrushKind.Solid;
  
  FOwnsClient := True;
  FApiClient := nil;
  
  CreateControls;
end;

destructor TFMXRegisterDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TFMXRegisterDialog.CreateControls;
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
  FLblTitle.Text := '创建账户';
  FLblTitle.Position.X := 40;
  FLblTitle.Position.Y := 25;
  FLblTitle.StyledSettings := [];
  FLblTitle.TextSettings.Font.Size := 22;
  FLblTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblTitle.TextSettings.FontColor := TAlphaColors.White;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FRectHeader;
  FLblSubtitle.Text := '注册一个新账户开始使用';
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
  FRectContent.Height := 480;
  FRectContent.Fill.Color := TAlphaColors.White;
  FRectContent.Stroke.Kind := TBrushKind.None;
  FRectContent.XRadius := 8;
  FRectContent.YRadius := 8;
  
  // Username
  FLblUsername := TLabel.Create(Self);
  FLblUsername.Parent := FRectContent;
  FLblUsername.Text := '用户名';
  FLblUsername.Position.X := 25;
  FLblUsername.Position.Y := 15;
  FLblUsername.StyledSettings := [];
  
  FEdtUsername := TEdit.Create(Self);
  FEdtUsername.Parent := FRectContent;
  FEdtUsername.Position.X := 25;
  FEdtUsername.Position.Y := 38;
  FEdtUsername.Width := 290;
  FEdtUsername.Height := 32;
  FEdtUsername.OnChange := HandleInputChange;
  FEdtUsername.OnKeyDown := HandleKeyDown;
  
  // Email
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FRectContent;
  FLblEmail.Text := '邮箱地址';
  FLblEmail.Position.X := 25;
  FLblEmail.Position.Y := 78;
  FLblEmail.StyledSettings := [];
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FRectContent;
  FEdtEmail.Position.X := 25;
  FEdtEmail.Position.Y := 101;
  FEdtEmail.Width := 290;
  FEdtEmail.Height := 32;
  FEdtEmail.OnChange := HandleInputChange;
  FEdtEmail.OnKeyDown := HandleKeyDown;
  
  // Password
  FLblPassword := TLabel.Create(Self);
  FLblPassword.Parent := FRectContent;
  FLblPassword.Text := '密码';
  FLblPassword.Position.X := 25;
  FLblPassword.Position.Y := 141;
  FLblPassword.StyledSettings := [];
  
  FEdtPassword := TEdit.Create(Self);
  FEdtPassword.Parent := FRectContent;
  FEdtPassword.Position.X := 25;
  FEdtPassword.Position.Y := 164;
  FEdtPassword.Width := 290;
  FEdtPassword.Height := 32;
  FEdtPassword.Password := True;
  FEdtPassword.OnChange := HandlePasswordChange;
  FEdtPassword.OnKeyDown := HandleKeyDown;
  
  // Password Strength
  FRectStrength := TRectangle.Create(Self);
  FRectStrength.Parent := FRectContent;
  FRectStrength.Position.X := 25;
  FRectStrength.Position.Y := 200;
  FRectStrength.Width := 0;
  FRectStrength.Height := 4;
  FRectStrength.Fill.Color := COLOR_WEAK;
  FRectStrength.Stroke.Kind := TBrushKind.None;
  FRectStrength.XRadius := 2;
  FRectStrength.YRadius := 2;
  
  FLblStrength := TLabel.Create(Self);
  FLblStrength.Parent := FRectContent;
  FLblStrength.Text := '';
  FLblStrength.Position.X := 25;
  FLblStrength.Position.Y := 207;
  FLblStrength.StyledSettings := [];
  FLblStrength.TextSettings.Font.Size := 10;
  
  // Confirm Password
  FLblConfirmPassword := TLabel.Create(Self);
  FLblConfirmPassword.Parent := FRectContent;
  FLblConfirmPassword.Text := '确认密码';
  FLblConfirmPassword.Position.X := 25;
  FLblConfirmPassword.Position.Y := 225;
  FLblConfirmPassword.StyledSettings := [];
  
  FEdtConfirmPassword := TEdit.Create(Self);
  FEdtConfirmPassword.Parent := FRectContent;
  FEdtConfirmPassword.Position.X := 25;
  FEdtConfirmPassword.Position.Y := 248;
  FEdtConfirmPassword.Width := 290;
  FEdtConfirmPassword.Height := 32;
  FEdtConfirmPassword.Password := True;
  FEdtConfirmPassword.OnChange := HandleInputChange;
  FEdtConfirmPassword.OnKeyDown := HandleKeyDown;
  
  // Terms Agreement
  FChkAgreeTerms := TCheckBox.Create(Self);
  FChkAgreeTerms.Parent := FRectContent;
  FChkAgreeTerms.Text := '我已阅读并同意';
  FChkAgreeTerms.Position.X := 25;
  FChkAgreeTerms.Position.Y := 295;
  FChkAgreeTerms.OnChange := HandleInputChange;
  
  FLblTermsLink := TLabel.Create(Self);
  FLblTermsLink.Parent := FRectContent;
  FLblTermsLink.Text := '服务条款';
  FLblTermsLink.Position.X := 145;
  FLblTermsLink.Position.Y := 297;
  FLblTermsLink.StyledSettings := [];
  FLblTermsLink.TextSettings.FontColor := COLOR_PRIMARY;
  FLblTermsLink.Cursor := crHandPoint;
  FLblTermsLink.HitTest := True;
  FLblTermsLink.OnClick := HandleTermsClick;
  
  // Status
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FRectContent;
  FLblStatus.Text := '';
  FLblStatus.Position.X := 25;
  FLblStatus.Position.Y := 325;
  FLblStatus.Width := 290;
  FLblStatus.Height := 40;
  FLblStatus.StyledSettings := [];
  FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
  FLblStatus.TextSettings.WordWrap := True;
  
  // Register Button
  FBtnRegister := TButton.Create(Self);
  FBtnRegister.Parent := FRectContent;
  FBtnRegister.Text := '注 册';
  FBtnRegister.Position.X := 25;
  FBtnRegister.Position.Y := 375;
  FBtnRegister.Width := 290;
  FBtnRegister.Height := 44;
  FBtnRegister.Enabled := False;
  FBtnRegister.OnClick := HandleRegisterClick;
  
  // Login Link
  FLblLogin := TLabel.Create(Self);
  FLblLogin.Parent := FRectContent;
  FLblLogin.Text := '已有账户? 立即登录';
  FLblLogin.Position.X := 100;
  FLblLogin.Position.Y := 435;
  FLblLogin.StyledSettings := [];
  FLblLogin.TextSettings.FontColor := COLOR_PRIMARY;
  FLblLogin.Cursor := crHandPoint;
  FLblLogin.HitTest := True;
  FLblLogin.OnClick := HandleLoginClick;
end;

procedure TFMXRegisterDialog.HandleInputChange(Sender: TObject);
begin
  FLblStatus.Text := '';
  SetButtonEnabled;
end;

procedure TFMXRegisterDialog.HandlePasswordChange(Sender: TObject);
begin
  UpdatePasswordStrength;
  HandleInputChange(Sender);
end;

procedure TFMXRegisterDialog.HandleKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    if FBtnRegister.Enabled then
      HandleRegisterClick(FBtnRegister);
  end;
end;

procedure TFMXRegisterDialog.SetButtonEnabled;
begin
  FBtnRegister.Enabled := (Trim(FEdtUsername.Text) <> '') and
                          (Trim(FEdtEmail.Text) <> '') and
                          (Trim(FEdtPassword.Text) <> '') and
                          (Trim(FEdtConfirmPassword.Text) <> '') and
                          FChkAgreeTerms.IsChecked;
end;

function TFMXRegisterDialog.GetPasswordStrength(const Password: string): Integer;
var
  Score: Integer;
begin
  Score := 0;
  if Length(Password) >= 6 then Inc(Score);
  if Length(Password) >= 8 then Inc(Score);
  if Length(Password) >= 12 then Inc(Score);
  if TRegEx.IsMatch(Password, '[a-z]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[A-Z]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[0-9]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[^a-zA-Z0-9]') then Inc(Score);
  Result := Score;
end;

procedure TFMXRegisterDialog.UpdatePasswordStrength;
var
  Strength: Integer;
begin
  if FEdtPassword.Text = '' then
  begin
    FRectStrength.Width := 0;
    FLblStrength.Text := '';
    Exit;
  end;
  
  Strength := GetPasswordStrength(FEdtPassword.Text);
  
  if Strength <= 2 then
  begin
    FRectStrength.Width := 97;
    FRectStrength.Fill.Color := COLOR_WEAK;
    FLblStrength.Text := '弱';
    FLblStrength.TextSettings.FontColor := COLOR_WEAK;
  end
  else if Strength <= 4 then
  begin
    FRectStrength.Width := 193;
    FRectStrength.Fill.Color := COLOR_MEDIUM;
    FLblStrength.Text := '中等';
    FLblStrength.TextSettings.FontColor := COLOR_MEDIUM;
  end
  else
  begin
    FRectStrength.Width := 290;
    FRectStrength.Fill.Color := COLOR_STRONG;
    FLblStrength.Text := '强';
    FLblStrength.TextSettings.FontColor := COLOR_STRONG;
  end;
end;

function TFMXRegisterDialog.ValidateInput: Boolean;
var
  Email: string;
begin
  Result := False;
  
  if Length(Trim(FEdtUsername.Text)) < 2 then
  begin
    UpdateStatus('用户名至少需要2个字符', True);
    FEdtUsername.SetFocus;
    Exit;
  end;
  
  Email := Trim(FEdtEmail.Text);
  if not TRegEx.IsMatch(Email, '^[^@]+@[^@]+\.[^@]+$') then
  begin
    UpdateStatus('请输入有效的邮箱地址', True);
    FEdtEmail.SetFocus;
    Exit;
  end;
  
  if Length(FEdtPassword.Text) < 6 then
  begin
    UpdateStatus('密码至少需要6个字符', True);
    FEdtPassword.SetFocus;
    Exit;
  end;
  
  if FEdtPassword.Text <> FEdtConfirmPassword.Text then
  begin
    UpdateStatus('两次输入的密码不一致', True);
    FEdtConfirmPassword.SetFocus;
    Exit;
  end;
  
  if not FChkAgreeTerms.IsChecked then
  begin
    UpdateStatus('请阅读并同意服务条款', True);
    Exit;
  end;
  
  Result := True;
end;

procedure TFMXRegisterDialog.HandleRegisterClick(Sender: TObject);
begin
  if not ValidateInput then Exit;
  
  if not Assigned(FApiClient) then
  begin
    UpdateStatus('API客户端未初始化', True);
    Exit;
  end;
  
  FBtnRegister.Enabled := False;
  UpdateStatus('正在注册...', False);
  Application.ProcessMessages;
  
  try
    FRegisterResult := FApiClient.Register(
      Trim(FEdtUsername.Text),
      Trim(FEdtEmail.Text),
      FEdtPassword.Text
    );
    
    if FRegisterResult.Success then
    begin
      UpdateStatus('注册成功!', False);
      FLblStatus.TextSettings.FontColor := COLOR_SUCCESS;
      ModalResult := mrOk;
    end
    else
    begin
      UpdateStatus(FRegisterResult.ErrorMessage, True);
      if FRegisterResult.ErrorMessage = '' then
        UpdateStatus('注册失败，请稍后重试', True);
      FBtnRegister.Enabled := True;
    end;
  except
    on E: Exception do
    begin
      UpdateStatus('注册出错: ' + E.Message, True);
      FBtnRegister.Enabled := True;
    end;
  end;
end;

procedure TFMXRegisterDialog.HandleLoginClick(Sender: TObject);
begin
  if Assigned(FOnLogin) then
    FOnLogin(Self)
  else
    ModalResult := mrRetry;
end;

procedure TFMXRegisterDialog.HandleTermsClick(Sender: TObject);
begin
  if Assigned(FOnShowTerms) then
    FOnShowTerms(Self);
end;

procedure TFMXRegisterDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TFMXRegisterDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Text := Msg;
  if IsError then
    FLblStatus.TextSettings.FontColor := COLOR_ERROR
  else
    FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
end;

class function TFMXRegisterDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TFMXRegisterDialog;
begin
  Dlg := TFMXRegisterDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TFMXRegisterDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TFMXRegisterDialog;
begin
  Dlg := TFMXRegisterDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
