{ ============================================================================
  UniBase.VCL.RegisterDialog - 用户注册对话框
  
  Version: 1.0
  Description: Modern registration dialog with username, email, password,
               confirm password and terms agreement.
  ============================================================================ }

unit UniBase.VCL.RegisterDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  UniBase.AipexBase.Client;

type
  TRegisterDialog = class(TForm)
  private
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FPnlContent: TPanel;
    FLblUsername: TLabel;
    FEdtUsername: TEdit;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblPassword: TLabel;
    FEdtPassword: TEdit;
    FPnlStrength: TPanel;
    FLblStrength: TLabel;
    FLblConfirmPassword: TLabel;
    FEdtConfirmPassword: TEdit;
    FChkAgreeTerms: TCheckBox;
    FLblTermsLink: TLabel;
    FLblStatus: TLabel;
    FPnlButtons: TPanel;
    FBtnRegister: TButton;
    FBtnLogin: TButton;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FRegisterResult: TAipexLoginResult;
    FOnLogin: TNotifyEvent;
    FOnShowTerms: TNotifyEvent;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleRegisterClick(Sender: TObject);
    procedure HandleLoginClick(Sender: TObject);
    procedure HandleTermsClick(Sender: TObject);
    procedure HandleInputChange(Sender: TObject);
    procedure HandlePasswordChange(Sender: TObject);
    procedure HandleKeyPress(Sender: TObject; var Key: Char);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure UpdatePasswordStrength;
    procedure SetButtonEnabled;
    function ValidateInput: Boolean;
    function GetPasswordStrength(const Password: string): Integer;
  protected
    procedure DoShow; override;
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
  Winapi.Windows, System.RegularExpressions;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_PRIMARY_DARK = $A24B76;
  COLOR_BG = $FAF7F5;
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_ERROR = $0000FF;
  COLOR_SUCCESS = $00AA00;
  COLOR_WARNING = $00A5FF;
  COLOR_WEAK = $5050EE;
  COLOR_MEDIUM = $00A5FF;
  COLOR_STRONG = $00AA00;

{ TRegisterDialog }

constructor TRegisterDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '用户注册';
  Width := 420;
  Height := 580;
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

destructor TRegisterDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TRegisterDialog.CreateControls;
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
  FLblTitle.Caption := '创建账户';
  FLblTitle.Font.Size := 20;
  FLblTitle.Font.Style := [fsBold];
  FLblTitle.Font.Color := clWhite;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := '注册一个新账户开始使用';
  FLblSubtitle.Font.Size := 10;
  FLblSubtitle.Font.Color := $FFFFFF;
  
  // Content Panel
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;
  FPnlContent.ParentBackground := False;
  FPnlContent.Color := clWhite;
  
  // Username
  FLblUsername := TLabel.Create(Self);
  FLblUsername.Parent := FPnlContent;
  FLblUsername.Caption := '用户名';
  
  FEdtUsername := TEdit.Create(Self);
  FEdtUsername.Parent := FPnlContent;
  FEdtUsername.OnChange := HandleInputChange;
  FEdtUsername.OnKeyPress := HandleKeyPress;
  
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
  FEdtPassword.OnChange := HandlePasswordChange;
  FEdtPassword.OnKeyPress := HandleKeyPress;
  
  // Password Strength
  FPnlStrength := TPanel.Create(Self);
  FPnlStrength.Parent := FPnlContent;
  FPnlStrength.BevelOuter := bvNone;
  FPnlStrength.Height := 4;
  FPnlStrength.Color := $EEEEEE;
  
  FLblStrength := TLabel.Create(Self);
  FLblStrength.Parent := FPnlContent;
  FLblStrength.Caption := '';
  FLblStrength.Font.Size := 8;
  
  // Confirm Password
  FLblConfirmPassword := TLabel.Create(Self);
  FLblConfirmPassword.Parent := FPnlContent;
  FLblConfirmPassword.Caption := '确认密码';
  
  FEdtConfirmPassword := TEdit.Create(Self);
  FEdtConfirmPassword.Parent := FPnlContent;
  FEdtConfirmPassword.PasswordChar := '●';
  FEdtConfirmPassword.OnChange := HandleInputChange;
  FEdtConfirmPassword.OnKeyPress := HandleKeyPress;
  
  // Terms Agreement
  FChkAgreeTerms := TCheckBox.Create(Self);
  FChkAgreeTerms.Parent := FPnlContent;
  FChkAgreeTerms.Caption := '我已阅读并同意';
  FChkAgreeTerms.OnClick := HandleInputChange;
  
  FLblTermsLink := TLabel.Create(Self);
  FLblTermsLink.Parent := FPnlContent;
  FLblTermsLink.Caption := '服务条款';
  FLblTermsLink.Font.Color := COLOR_PRIMARY;
  FLblTermsLink.Cursor := crHandPoint;
  FLblTermsLink.OnClick := HandleTermsClick;
  
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
  
  FBtnRegister := TButton.Create(Self);
  FBtnRegister.Parent := FPnlButtons;
  FBtnRegister.Caption := '注 册';
  FBtnRegister.Default := True;
  FBtnRegister.Enabled := False;
  FBtnRegister.OnClick := HandleRegisterClick;
  
  FBtnLogin := TButton.Create(Self);
  FBtnLogin.Parent := FPnlButtons;
  FBtnLogin.Caption := '已有账户? 立即登录';
  FBtnLogin.OnClick := HandleLoginClick;
end;

procedure TRegisterDialog.LayoutControls;
var
  ContentLeft, ContentWidth: Integer;
begin
  ContentLeft := 40;
  ContentWidth := ClientWidth - 80;
  
  // Header
  FLblTitle.SetBounds(ContentLeft, 25, 300, 30);
  FLblSubtitle.SetBounds(ContentLeft, 58, 300, 20);
  
  // Content
  FLblUsername.SetBounds(ContentLeft, 20, 100, 18);
  FEdtUsername.SetBounds(ContentLeft, 40, ContentWidth, 28);
  
  FLblEmail.SetBounds(ContentLeft, 78, 100, 18);
  FEdtEmail.SetBounds(ContentLeft, 98, ContentWidth, 28);
  
  FLblPassword.SetBounds(ContentLeft, 136, 100, 18);
  FEdtPassword.SetBounds(ContentLeft, 156, ContentWidth, 28);
  FPnlStrength.SetBounds(ContentLeft, 188, ContentWidth, 4);
  FLblStrength.SetBounds(ContentLeft, 195, 100, 14);
  
  FLblConfirmPassword.SetBounds(ContentLeft, 215, 100, 18);
  FEdtConfirmPassword.SetBounds(ContentLeft, 235, ContentWidth, 28);
  
  FChkAgreeTerms.SetBounds(ContentLeft, 278, 120, 20);
  FLblTermsLink.SetBounds(ContentLeft + 122, 279, 60, 18);
  
  FLblStatus.SetBounds(ContentLeft, 310, ContentWidth, 40);
  
  // Buttons
  FBtnRegister.SetBounds(ContentLeft, 15, ContentWidth, 40);
  FBtnLogin.SetBounds(ContentLeft, 65, ContentWidth, 25);
end;

procedure TRegisterDialog.ApplyStyle;
begin
  FPnlHeader.Color := COLOR_PRIMARY;
  
  FEdtUsername.Font.Size := 10;
  FEdtEmail.Font.Size := 10;
  FEdtPassword.Font.Size := 10;
  FEdtConfirmPassword.Font.Size := 10;
  
  FBtnRegister.Font.Size := 11;
  FBtnRegister.Font.Style := [fsBold];
  
  FBtnLogin.Font.Color := COLOR_PRIMARY;
  FBtnLogin.Flat := True;
end;

procedure TRegisterDialog.DoShow;
begin
  inherited;
  FEdtUsername.SetFocus;
  FLblStatus.Caption := '';
  UpdatePasswordStrength;
end;

procedure TRegisterDialog.HandleInputChange(Sender: TObject);
begin
  FLblStatus.Caption := '';
  SetButtonEnabled;
end;

procedure TRegisterDialog.HandlePasswordChange(Sender: TObject);
begin
  UpdatePasswordStrength;
  HandleInputChange(Sender);
end;

procedure TRegisterDialog.HandleKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if FBtnRegister.Enabled then
      HandleRegisterClick(FBtnRegister);
  end;
end;

procedure TRegisterDialog.SetButtonEnabled;
begin
  FBtnRegister.Enabled := (Trim(FEdtUsername.Text) <> '') and
                          (Trim(FEdtEmail.Text) <> '') and
                          (Trim(FEdtPassword.Text) <> '') and
                          (Trim(FEdtConfirmPassword.Text) <> '') and
                          FChkAgreeTerms.Checked;
end;

function TRegisterDialog.GetPasswordStrength(const Password: string): Integer;
var
  Score: Integer;
begin
  Score := 0;
  
  // Length check
  if Length(Password) >= 6 then Inc(Score);
  if Length(Password) >= 8 then Inc(Score);
  if Length(Password) >= 12 then Inc(Score);
  
  // Character variety
  if TRegEx.IsMatch(Password, '[a-z]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[A-Z]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[0-9]') then Inc(Score);
  if TRegEx.IsMatch(Password, '[^a-zA-Z0-9]') then Inc(Score);
  
  Result := Score;
end;

procedure TRegisterDialog.UpdatePasswordStrength;
var
  Strength: Integer;
  StrengthWidth: Integer;
begin
  if FEdtPassword.Text = '' then
  begin
    FPnlStrength.Width := 0;
    FLblStrength.Caption := '';
    Exit;
  end;
  
  Strength := GetPasswordStrength(FEdtPassword.Text);
  StrengthWidth := ClientWidth - 80;
  
  if Strength <= 2 then
  begin
    FPnlStrength.Width := StrengthWidth div 3;
    FPnlStrength.Color := COLOR_WEAK;
    FLblStrength.Caption := '弱';
    FLblStrength.Font.Color := COLOR_WEAK;
  end
  else if Strength <= 4 then
  begin
    FPnlStrength.Width := (StrengthWidth * 2) div 3;
    FPnlStrength.Color := COLOR_MEDIUM;
    FLblStrength.Caption := '中等';
    FLblStrength.Font.Color := COLOR_MEDIUM;
  end
  else
  begin
    FPnlStrength.Width := StrengthWidth;
    FPnlStrength.Color := COLOR_STRONG;
    FLblStrength.Caption := '强';
    FLblStrength.Font.Color := COLOR_STRONG;
  end;
end;

function TRegisterDialog.ValidateInput: Boolean;
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
  
  if not FChkAgreeTerms.Checked then
  begin
    UpdateStatus('请阅读并同意服务条款', True);
    Exit;
  end;
  
  Result := True;
end;

procedure TRegisterDialog.HandleRegisterClick(Sender: TObject);
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
      FEdtPassword.Text,
      FEdtConfirmPassword.Text
    );
    
    if FRegisterResult.Success then
    begin
      UpdateStatus('注册成功!', False);
      FLblStatus.Font.Color := COLOR_SUCCESS;
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
    on E: EAipexBaseValidationError do
    begin
      UpdateStatus(E.Message, True);
      FBtnRegister.Enabled := True;
    end;
    on E: Exception do
    begin
      UpdateStatus('注册出错: ' + E.Message, True);
      FBtnRegister.Enabled := True;
    end;
  end;
end;

procedure TRegisterDialog.HandleLoginClick(Sender: TObject);
begin
  if Assigned(FOnLogin) then
    FOnLogin(Self)
  else
    ModalResult := mrRetry;
end;

procedure TRegisterDialog.HandleTermsClick(Sender: TObject);
begin
  if Assigned(FOnShowTerms) then
    FOnShowTerms(Self);
end;

procedure TRegisterDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TRegisterDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := COLOR_ERROR
  else
    FLblStatus.Font.Color := COLOR_TEXT_GRAY;
end;

class function TRegisterDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TRegisterDialog;
begin
  Dlg := TRegisterDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TRegisterDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TRegisterDialog;
begin
  Dlg := TRegisterDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
