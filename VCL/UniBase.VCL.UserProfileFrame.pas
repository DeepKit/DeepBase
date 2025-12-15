{ ============================================================================
  UniBase.VCL.UserProfileFrame - 用户信息 Frame
  
  Version: 1.0
  Description: User profile frame with avatar, basic info, and password change.
  ============================================================================ }

unit UniBase.VCL.UserProfileFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  Vcl.ComCtrls, Vcl.Dialogs,
  UniBase.AipexBase.Client;

type
  TUserProfileFrame = class(TFrame)
  private
    // Main layout
    FPnlMain: TPanel;
    FPnlLeft: TPanel;
    FPnlRight: TPanel;
    
    // Avatar section
    FPnlAvatar: TPanel;
    FImgAvatar: TImage;
    FLblUsername: TLabel;
    FLblEmail: TLabel;
    FBtnChangeAvatar: TButton;
    
    // Tab control
    FTabControl: TTabControl;
    
    // Profile tab
    FPnlProfile: TPanel;
    FLblProfileUsername: TLabel;
    FEdtProfileUsername: TEdit;
    FLblProfileEmail: TLabel;
    FEdtProfileEmail: TEdit;
    FLblProfilePhone: TLabel;
    FEdtProfilePhone: TEdit;
    FBtnSaveProfile: TButton;
    FLblProfileStatus: TLabel;
    
    // Password tab
    FPnlPassword: TPanel;
    FLblOldPassword: TLabel;
    FEdtOldPassword: TEdit;
    FLblNewPassword: TLabel;
    FEdtNewPassword: TEdit;
    FLblConfirmPassword: TLabel;
    FEdtConfirmPassword: TEdit;
    FBtnChangePassword: TButton;
    FLblPasswordStatus: TLabel;
    
    // Security tab  
    FPnlSecurity: TPanel;
    FLblLastLogin: TLabel;
    FLblLastLoginValue: TLabel;
    FLblAccountStatus: TLabel;
    FLblAccountStatusValue: TLabel;
    FLblCreatedAt: TLabel;
    FLblCreatedAtValue: TLabel;
    
    FApiClient: TAipexBaseClient;
    FCurrentUser: TAipexUser;
    FOpenDialog: TOpenDialog;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleTabChange(Sender: TObject);
    procedure HandleChangeAvatarClick(Sender: TObject);
    procedure HandleSaveProfileClick(Sender: TObject);
    procedure HandleChangePasswordClick(Sender: TObject);
    procedure ShowTab(Index: Integer);
    procedure UpdateProfileStatus(const Msg: string; IsError: Boolean);
    procedure UpdatePasswordStatus(const Msg: string; IsError: Boolean);
    procedure SetApiClient(Value: TAipexBaseClient);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure LoadUserInfo;
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property CurrentUser: TAipexUser read FCurrentUser;
  end;

implementation

uses
  Winapi.Windows, System.RegularExpressions;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_BG = $FAF7F5;
  COLOR_CARD = $FFFFFF;
  COLOR_TEXT = $333333;
  COLOR_TEXT_GRAY = $999999;
  COLOR_ERROR = $0000FF;
  COLOR_SUCCESS = $00AA00;

{ TUserProfileFrame }

constructor TUserProfileFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 600;
  Height := 500;
  Color := COLOR_BG;
  
  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Filter := '图片文件|*.jpg;*.jpeg;*.png;*.bmp|所有文件|*.*';
  FOpenDialog.Title := '选择头像图片';
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
end;

destructor TUserProfileFrame.Destroy;
begin
  FOpenDialog.Free;
  inherited;
end;

procedure TUserProfileFrame.CreateControls;
begin
  // Main panel
  FPnlMain := TPanel.Create(Self);
  FPnlMain.Parent := Self;
  FPnlMain.Align := alClient;
  FPnlMain.BevelOuter := bvNone;
  FPnlMain.Color := COLOR_BG;
  
  // Left panel - Avatar
  FPnlLeft := TPanel.Create(Self);
  FPnlLeft.Parent := FPnlMain;
  FPnlLeft.Align := alLeft;
  FPnlLeft.Width := 200;
  FPnlLeft.BevelOuter := bvNone;
  FPnlLeft.Color := COLOR_BG;
  
  FPnlAvatar := TPanel.Create(Self);
  FPnlAvatar.Parent := FPnlLeft;
  FPnlAvatar.BevelOuter := bvNone;
  FPnlAvatar.Color := COLOR_CARD;
  
  FImgAvatar := TImage.Create(Self);
  FImgAvatar.Parent := FPnlAvatar;
  FImgAvatar.Stretch := True;
  FImgAvatar.Proportional := True;
  FImgAvatar.Center := True;
  
  FLblUsername := TLabel.Create(Self);
  FLblUsername.Parent := FPnlAvatar;
  FLblUsername.Caption := '用户名';
  FLblUsername.Font.Size := 14;
  FLblUsername.Font.Style := [fsBold];
  FLblUsername.Alignment := taCenter;
  
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FPnlAvatar;
  FLblEmail.Caption := 'user@example.com';
  FLblEmail.Font.Color := COLOR_TEXT_GRAY;
  FLblEmail.Alignment := taCenter;
  
  FBtnChangeAvatar := TButton.Create(Self);
  FBtnChangeAvatar.Parent := FPnlAvatar;
  FBtnChangeAvatar.Caption := '更换头像';
  FBtnChangeAvatar.OnClick := HandleChangeAvatarClick;
  
  // Right panel - Tabs
  FPnlRight := TPanel.Create(Self);
  FPnlRight.Parent := FPnlMain;
  FPnlRight.Align := alClient;
  FPnlRight.BevelOuter := bvNone;
  FPnlRight.Color := COLOR_BG;
  
  FTabControl := TTabControl.Create(Self);
  FTabControl.Parent := FPnlRight;
  FTabControl.Align := alTop;
  FTabControl.Height := 32;
  FTabControl.Tabs.Add('基本信息');
  FTabControl.Tabs.Add('修改密码');
  FTabControl.Tabs.Add('安全设置');
  FTabControl.OnChange := HandleTabChange;
  
  // Profile Panel
  FPnlProfile := TPanel.Create(Self);
  FPnlProfile.Parent := FPnlRight;
  FPnlProfile.BevelOuter := bvNone;
  FPnlProfile.Color := COLOR_CARD;
  
  FLblProfileUsername := TLabel.Create(Self);
  FLblProfileUsername.Parent := FPnlProfile;
  FLblProfileUsername.Caption := '用户名';
  
  FEdtProfileUsername := TEdit.Create(Self);
  FEdtProfileUsername.Parent := FPnlProfile;
  
  FLblProfileEmail := TLabel.Create(Self);
  FLblProfileEmail.Parent := FPnlProfile;
  FLblProfileEmail.Caption := '邮箱（不可修改）';
  
  FEdtProfileEmail := TEdit.Create(Self);
  FEdtProfileEmail.Parent := FPnlProfile;
  FEdtProfileEmail.ReadOnly := True;
  FEdtProfileEmail.Color := $F5F5F5;
  
  FLblProfilePhone := TLabel.Create(Self);
  FLblProfilePhone.Parent := FPnlProfile;
  FLblProfilePhone.Caption := '手机号';
  
  FEdtProfilePhone := TEdit.Create(Self);
  FEdtProfilePhone.Parent := FPnlProfile;
  
  FBtnSaveProfile := TButton.Create(Self);
  FBtnSaveProfile.Parent := FPnlProfile;
  FBtnSaveProfile.Caption := '保存修改';
  FBtnSaveProfile.OnClick := HandleSaveProfileClick;
  
  FLblProfileStatus := TLabel.Create(Self);
  FLblProfileStatus.Parent := FPnlProfile;
  FLblProfileStatus.Caption := '';
  FLblProfileStatus.WordWrap := True;
  
  // Password Panel
  FPnlPassword := TPanel.Create(Self);
  FPnlPassword.Parent := FPnlRight;
  FPnlPassword.BevelOuter := bvNone;
  FPnlPassword.Color := COLOR_CARD;
  FPnlPassword.Visible := False;
  
  FLblOldPassword := TLabel.Create(Self);
  FLblOldPassword.Parent := FPnlPassword;
  FLblOldPassword.Caption := '当前密码';
  
  FEdtOldPassword := TEdit.Create(Self);
  FEdtOldPassword.Parent := FPnlPassword;
  FEdtOldPassword.PasswordChar := '●';
  
  FLblNewPassword := TLabel.Create(Self);
  FLblNewPassword.Parent := FPnlPassword;
  FLblNewPassword.Caption := '新密码';
  
  FEdtNewPassword := TEdit.Create(Self);
  FEdtNewPassword.Parent := FPnlPassword;
  FEdtNewPassword.PasswordChar := '●';
  
  FLblConfirmPassword := TLabel.Create(Self);
  FLblConfirmPassword.Parent := FPnlPassword;
  FLblConfirmPassword.Caption := '确认新密码';
  
  FEdtConfirmPassword := TEdit.Create(Self);
  FEdtConfirmPassword.Parent := FPnlPassword;
  FEdtConfirmPassword.PasswordChar := '●';
  
  FBtnChangePassword := TButton.Create(Self);
  FBtnChangePassword.Parent := FPnlPassword;
  FBtnChangePassword.Caption := '修改密码';
  FBtnChangePassword.OnClick := HandleChangePasswordClick;
  
  FLblPasswordStatus := TLabel.Create(Self);
  FLblPasswordStatus.Parent := FPnlPassword;
  FLblPasswordStatus.Caption := '';
  FLblPasswordStatus.WordWrap := True;
  
  // Security Panel
  FPnlSecurity := TPanel.Create(Self);
  FPnlSecurity.Parent := FPnlRight;
  FPnlSecurity.BevelOuter := bvNone;
  FPnlSecurity.Color := COLOR_CARD;
  FPnlSecurity.Visible := False;
  
  FLblLastLogin := TLabel.Create(Self);
  FLblLastLogin.Parent := FPnlSecurity;
  FLblLastLogin.Caption := '上次登录时间：';
  FLblLastLogin.Font.Color := COLOR_TEXT_GRAY;
  
  FLblLastLoginValue := TLabel.Create(Self);
  FLblLastLoginValue.Parent := FPnlSecurity;
  FLblLastLoginValue.Caption := '-';
  
  FLblAccountStatus := TLabel.Create(Self);
  FLblAccountStatus.Parent := FPnlSecurity;
  FLblAccountStatus.Caption := '账户状态：';
  FLblAccountStatus.Font.Color := COLOR_TEXT_GRAY;
  
  FLblAccountStatusValue := TLabel.Create(Self);
  FLblAccountStatusValue.Parent := FPnlSecurity;
  FLblAccountStatusValue.Caption := '-';
  
  FLblCreatedAt := TLabel.Create(Self);
  FLblCreatedAt.Parent := FPnlSecurity;
  FLblCreatedAt.Caption := '注册时间：';
  FLblCreatedAt.Font.Color := COLOR_TEXT_GRAY;
  
  FLblCreatedAtValue := TLabel.Create(Self);
  FLblCreatedAtValue.Parent := FPnlSecurity;
  FLblCreatedAtValue.Caption := '-';
end;

procedure TUserProfileFrame.LayoutControls;
var
  PanelTop, ContentLeft, ContentWidth: Integer;
begin
  // Avatar panel
  FPnlAvatar.SetBounds(10, 10, 180, 280);
  FImgAvatar.SetBounds(40, 20, 100, 100);
  FLblUsername.SetBounds(10, 130, 160, 24);
  FLblEmail.SetBounds(10, 158, 160, 18);
  FBtnChangeAvatar.SetBounds(30, 200, 120, 32);
  
  // Tab content panels
  PanelTop := FTabControl.Height + 10;
  ContentLeft := 20;
  ContentWidth := 320;
  
  FPnlProfile.SetBounds(10, PanelTop, FPnlRight.Width - 20, 350);
  FPnlPassword.SetBounds(10, PanelTop, FPnlRight.Width - 20, 350);
  FPnlSecurity.SetBounds(10, PanelTop, FPnlRight.Width - 20, 350);
  
  // Profile fields
  FLblProfileUsername.SetBounds(ContentLeft, 20, 100, 18);
  FEdtProfileUsername.SetBounds(ContentLeft, 40, ContentWidth, 28);
  
  FLblProfileEmail.SetBounds(ContentLeft, 80, 150, 18);
  FEdtProfileEmail.SetBounds(ContentLeft, 100, ContentWidth, 28);
  
  FLblProfilePhone.SetBounds(ContentLeft, 140, 100, 18);
  FEdtProfilePhone.SetBounds(ContentLeft, 160, ContentWidth, 28);
  
  FBtnSaveProfile.SetBounds(ContentLeft, 210, 120, 36);
  FLblProfileStatus.SetBounds(ContentLeft, 260, ContentWidth, 40);
  
  // Password fields
  FLblOldPassword.SetBounds(ContentLeft, 20, 100, 18);
  FEdtOldPassword.SetBounds(ContentLeft, 40, ContentWidth, 28);
  
  FLblNewPassword.SetBounds(ContentLeft, 80, 100, 18);
  FEdtNewPassword.SetBounds(ContentLeft, 100, ContentWidth, 28);
  
  FLblConfirmPassword.SetBounds(ContentLeft, 140, 100, 18);
  FEdtConfirmPassword.SetBounds(ContentLeft, 160, ContentWidth, 28);
  
  FBtnChangePassword.SetBounds(ContentLeft, 210, 120, 36);
  FLblPasswordStatus.SetBounds(ContentLeft, 260, ContentWidth, 40);
  
  // Security fields
  FLblLastLogin.SetBounds(ContentLeft, 30, 120, 18);
  FLblLastLoginValue.SetBounds(ContentLeft + 120, 30, 200, 18);
  
  FLblAccountStatus.SetBounds(ContentLeft, 60, 120, 18);
  FLblAccountStatusValue.SetBounds(ContentLeft + 120, 60, 200, 18);
  
  FLblCreatedAt.SetBounds(ContentLeft, 90, 120, 18);
  FLblCreatedAtValue.SetBounds(ContentLeft + 120, 90, 200, 18);
end;

procedure TUserProfileFrame.ApplyStyle;
begin
  FPnlAvatar.Color := COLOR_CARD;
  FPnlProfile.Color := COLOR_CARD;
  FPnlPassword.Color := COLOR_CARD;
  FPnlSecurity.Color := COLOR_CARD;
  
  FBtnSaveProfile.Font.Style := [fsBold];
  FBtnChangePassword.Font.Style := [fsBold];
end;

procedure TUserProfileFrame.HandleTabChange(Sender: TObject);
begin
  ShowTab(FTabControl.TabIndex);
end;

procedure TUserProfileFrame.ShowTab(Index: Integer);
begin
  FPnlProfile.Visible := (Index = 0);
  FPnlPassword.Visible := (Index = 1);
  FPnlSecurity.Visible := (Index = 2);
end;

procedure TUserProfileFrame.HandleChangeAvatarClick(Sender: TObject);
var
  Stream: TFileStream;
  NewAvatarUrl: string;
begin
  if not Assigned(FApiClient) then Exit;
  
  if FOpenDialog.Execute then
  begin
    Stream := TFileStream.Create(FOpenDialog.FileName, fmOpenRead or fmShareDenyWrite);
    try
      NewAvatarUrl := FApiClient.UploadAvatar(Stream);
      if NewAvatarUrl <> '' then
      begin
        FImgAvatar.Picture.LoadFromFile(FOpenDialog.FileName);
        FCurrentUser.Avatar := NewAvatarUrl;
      end;
    finally
      Stream.Free;
    end;
  end;
end;

procedure TUserProfileFrame.HandleSaveProfileClick(Sender: TObject);
var
  Username, Phone: string;
begin
  if not Assigned(FApiClient) then
  begin
    UpdateProfileStatus('API客户端未初始化', True);
    Exit;
  end;
  
  Username := Trim(FEdtProfileUsername.Text);
  Phone := Trim(FEdtProfilePhone.Text);
  
  if Length(Username) < 2 then
  begin
    UpdateProfileStatus('用户名至少需要2个字符', True);
    FEdtProfileUsername.SetFocus;
    Exit;
  end;
  
  FBtnSaveProfile.Enabled := False;
  UpdateProfileStatus('正在保存...', False);
  
  try
    if FApiClient.UpdateProfile(Username, Phone) then
    begin
      FCurrentUser.Username := Username;
      FCurrentUser.Phone := Phone;
      FLblUsername.Caption := Username;
      UpdateProfileStatus('保存成功', False);
      FLblProfileStatus.Font.Color := COLOR_SUCCESS;
    end
    else
      UpdateProfileStatus('保存失败', True);
  except
    on E: Exception do
      UpdateProfileStatus('保存出错: ' + E.Message, True);
  end;
  
  FBtnSaveProfile.Enabled := True;
end;

procedure TUserProfileFrame.HandleChangePasswordClick(Sender: TObject);
var
  OldPwd, NewPwd, ConfirmPwd: string;
begin
  if not Assigned(FApiClient) then
  begin
    UpdatePasswordStatus('API客户端未初始化', True);
    Exit;
  end;
  
  OldPwd := FEdtOldPassword.Text;
  NewPwd := FEdtNewPassword.Text;
  ConfirmPwd := FEdtConfirmPassword.Text;
  
  if OldPwd = '' then
  begin
    UpdatePasswordStatus('请输入当前密码', True);
    FEdtOldPassword.SetFocus;
    Exit;
  end;
  
  if Length(NewPwd) < 6 then
  begin
    UpdatePasswordStatus('新密码至少需要6个字符', True);
    FEdtNewPassword.SetFocus;
    Exit;
  end;
  
  if NewPwd <> ConfirmPwd then
  begin
    UpdatePasswordStatus('两次输入的新密码不一致', True);
    FEdtConfirmPassword.SetFocus;
    Exit;
  end;
  
  FBtnChangePassword.Enabled := False;
  UpdatePasswordStatus('正在修改...', False);
  
  try
    if FApiClient.ChangePassword(OldPwd, NewPwd) then
    begin
      FEdtOldPassword.Clear;
      FEdtNewPassword.Clear;
      FEdtConfirmPassword.Clear;
      UpdatePasswordStatus('密码修改成功', False);
      FLblPasswordStatus.Font.Color := COLOR_SUCCESS;
    end
    else
      UpdatePasswordStatus('密码修改失败', True);
  except
    on E: EAipexBaseAuthError do
      UpdatePasswordStatus('当前密码错误', True);
    on E: Exception do
      UpdatePasswordStatus('修改出错: ' + E.Message, True);
  end;
  
  FBtnChangePassword.Enabled := True;
end;

procedure TUserProfileFrame.UpdateProfileStatus(const Msg: string; IsError: Boolean);
begin
  FLblProfileStatus.Caption := Msg;
  if IsError then
    FLblProfileStatus.Font.Color := COLOR_ERROR
  else
    FLblProfileStatus.Font.Color := COLOR_TEXT_GRAY;
end;

procedure TUserProfileFrame.UpdatePasswordStatus(const Msg: string; IsError: Boolean);
begin
  FLblPasswordStatus.Caption := Msg;
  if IsError then
    FLblPasswordStatus.Font.Color := COLOR_ERROR
  else
    FLblPasswordStatus.Font.Color := COLOR_TEXT_GRAY;
end;

procedure TUserProfileFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
  if Assigned(FApiClient) then
    LoadUserInfo;
end;

procedure TUserProfileFrame.LoadUserInfo;
begin
  if not Assigned(FApiClient) then Exit;
  
  try
    FCurrentUser := FApiClient.GetUserInfo;
    
    // Update avatar section
    FLblUsername.Caption := FCurrentUser.Username;
    FLblEmail.Caption := FCurrentUser.Email;
    
    // Update profile tab
    FEdtProfileUsername.Text := FCurrentUser.Username;
    FEdtProfileEmail.Text := FCurrentUser.Email;
    FEdtProfilePhone.Text := FCurrentUser.Phone;
    
    // Update security tab
    if FCurrentUser.LastLoginAt > 0 then
      FLblLastLoginValue.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', FCurrentUser.LastLoginAt)
    else
      FLblLastLoginValue.Caption := '-';
    
    if FCurrentUser.Status = 'active' then
    begin
      FLblAccountStatusValue.Caption := '正常';
      FLblAccountStatusValue.Font.Color := COLOR_SUCCESS;
    end
    else
    begin
      FLblAccountStatusValue.Caption := FCurrentUser.Status;
      FLblAccountStatusValue.Font.Color := COLOR_ERROR;
    end;
    
    if FCurrentUser.CreatedAt > 0 then
      FLblCreatedAtValue.Caption := FormatDateTime('yyyy-mm-dd', FCurrentUser.CreatedAt)
    else
      FLblCreatedAtValue.Caption := '-';
  except
    on E: Exception do
      UpdateProfileStatus('加载用户信息失败: ' + E.Message, True);
  end;
end;

procedure TUserProfileFrame.RefreshData;
begin
  LoadUserInfo;
end;

end.
