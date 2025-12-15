{ ============================================================================
  UniBase.FMX.UserProfileFrame - FMX 用户信息 Frame
  
  Version: 1.0
  Description: Modern FMX user profile frame with tabs for basic info,
               change password, and security settings.
  ============================================================================ }

unit UniBase.FMX.UserProfileFrame;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics, FMX.TabControl,
  UniBase.AipexBase.Client;

type
  TFMXUserProfileFrame = class(TFrame)
  private
    FLayoutMain: TLayout;
    FRectHeader: TRectangle;
    // Avatar area
    FCircleAvatar: TCircle;
    FLblAvatarText: TLabel;
    FLblUsername: TLabel;
    FLblEmail: TLabel;
    // Tab control
    FTabControl: TTabControl;
    FTabBasicInfo: TTabItem;
    FTabChangePassword: TTabItem;
    FTabSecurity: TTabItem;
    // Basic info tab
    FLblNickname: TLabel;
    FEdtNickname: TEdit;
    FLblPhone: TLabel;
    FEdtPhone: TEdit;
    FLblBio: TLabel;
    FEdtBio: TEdit;
    FLblInfoStatus: TLabel;
    FBtnSaveInfo: TButton;
    // Change password tab
    FLblOldPassword: TLabel;
    FEdtOldPassword: TEdit;
    FLblNewPassword: TLabel;
    FEdtNewPassword: TEdit;
    FLblConfirmPassword: TLabel;
    FEdtConfirmPassword: TEdit;
    FLblPasswordStatus: TLabel;
    FBtnChangePassword: TButton;
    // Security tab
    FLblSecurityTitle: TLabel;
    FLblLastLogin: TLabel;
    FLblLastLoginValue: TLabel;
    FLblLastIP: TLabel;
    FLblLastIPValue: TLabel;
    FLblAccountCreated: TLabel;
    FLblAccountCreatedValue: TLabel;
    FLblTwoFactor: TLabel;
    FChkTwoFactor: TCheckBox;
    
    FApiClient: TAipexBaseClient;
    FUser: TAipexUser;
    FOnProfileUpdated: TNotifyEvent;
    
    procedure CreateControls;
    procedure CreateBasicInfoTab;
    procedure CreateChangePasswordTab;
    procedure CreateSecurityTab;
    procedure HandleSaveInfoClick(Sender: TObject);
    procedure HandleChangePasswordClick(Sender: TObject);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure SetUser(const Value: TAipexUser);
    procedure UpdateInfoStatus(const Msg: string; IsError: Boolean);
    procedure UpdatePasswordStatus(const Msg: string; IsError: Boolean);
    procedure PopulateUserData;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure RefreshData;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property User: TAipexUser read FUser write SetUser;
    property OnProfileUpdated: TNotifyEvent read FOnProfileUpdated write FOnProfileUpdated;
  end;

implementation

const
  COLOR_PRIMARY: TAlphaColor = $FF667EEA;
  COLOR_BG: TAlphaColor = $FFF5F7FA;
  COLOR_TEXT_GRAY: TAlphaColor = $FF999999;
  COLOR_ERROR: TAlphaColor = $FFFF0000;
  COLOR_SUCCESS: TAlphaColor = $FF00AA00;

{ TFMXUserProfileFrame }

constructor TFMXUserProfileFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Width := 600;
  Height := 500;
  
  CreateControls;
end;

destructor TFMXUserProfileFrame.Destroy;
begin
  inherited;
end;

procedure TFMXUserProfileFrame.CreateControls;
begin
  FLayoutMain := TLayout.Create(Self);
  FLayoutMain.Parent := Self;
  FLayoutMain.Align := TAlignLayout.Client;
  
  // Header with avatar
  FRectHeader := TRectangle.Create(Self);
  FRectHeader.Parent := FLayoutMain;
  FRectHeader.Align := TAlignLayout.Top;
  FRectHeader.Height := 120;
  FRectHeader.Fill.Color := COLOR_PRIMARY;
  FRectHeader.Stroke.Kind := TBrushKind.None;
  
  // Avatar circle
  FCircleAvatar := TCircle.Create(Self);
  FCircleAvatar.Parent := FRectHeader;
  FCircleAvatar.Position.X := 30;
  FCircleAvatar.Position.Y := 25;
  FCircleAvatar.Width := 70;
  FCircleAvatar.Height := 70;
  FCircleAvatar.Fill.Color := TAlphaColors.White;
  FCircleAvatar.Stroke.Kind := TBrushKind.None;
  
  FLblAvatarText := TLabel.Create(Self);
  FLblAvatarText.Parent := FCircleAvatar;
  FLblAvatarText.Align := TAlignLayout.Client;
  FLblAvatarText.Text := 'U';
  FLblAvatarText.StyledSettings := [];
  FLblAvatarText.TextSettings.Font.Size := 28;
  FLblAvatarText.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblAvatarText.TextSettings.FontColor := COLOR_PRIMARY;
  FLblAvatarText.TextSettings.HorzAlign := TTextAlign.Center;
  FLblAvatarText.TextSettings.VertAlign := TTextAlign.Center;
  
  FLblUsername := TLabel.Create(Self);
  FLblUsername.Parent := FRectHeader;
  FLblUsername.Text := '用户名';
  FLblUsername.Position.X := 120;
  FLblUsername.Position.Y := 35;
  FLblUsername.StyledSettings := [];
  FLblUsername.TextSettings.Font.Size := 18;
  FLblUsername.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblUsername.TextSettings.FontColor := TAlphaColors.White;
  
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FRectHeader;
  FLblEmail.Text := 'user@example.com';
  FLblEmail.Position.X := 120;
  FLblEmail.Position.Y := 65;
  FLblEmail.StyledSettings := [];
  FLblEmail.TextSettings.Font.Size := 12;
  FLblEmail.TextSettings.FontColor := $FFFFFFCC;
  
  // Tab Control
  FTabControl := TTabControl.Create(Self);
  FTabControl.Parent := FLayoutMain;
  FTabControl.Align := TAlignLayout.Client;
  FTabControl.Margins.Left := 20;
  FTabControl.Margins.Right := 20;
  FTabControl.Margins.Top := 10;
  FTabControl.Margins.Bottom := 20;
  
  FTabBasicInfo := FTabControl.Add(TTabItem);
  FTabBasicInfo.Text := '基本信息';
  
  FTabChangePassword := FTabControl.Add(TTabItem);
  FTabChangePassword.Text := '修改密码';
  
  FTabSecurity := FTabControl.Add(TTabItem);
  FTabSecurity.Text := '安全设置';
  
  CreateBasicInfoTab;
  CreateChangePasswordTab;
  CreateSecurityTab;
end;

procedure TFMXUserProfileFrame.CreateBasicInfoTab;
var
  LLayout: TLayout;
begin
  LLayout := TLayout.Create(Self);
  LLayout.Parent := FTabBasicInfo;
  LLayout.Align := TAlignLayout.Client;
  LLayout.Padding.Left := 20;
  LLayout.Padding.Right := 20;
  LLayout.Padding.Top := 20;
  
  FLblNickname := TLabel.Create(Self);
  FLblNickname.Parent := LLayout;
  FLblNickname.Text := '昵称';
  FLblNickname.Position.X := 0;
  FLblNickname.Position.Y := 0;
  FLblNickname.StyledSettings := [];
  
  FEdtNickname := TEdit.Create(Self);
  FEdtNickname.Parent := LLayout;
  FEdtNickname.Position.X := 0;
  FEdtNickname.Position.Y := 25;
  FEdtNickname.Width := 300;
  FEdtNickname.Height := 32;
  
  FLblPhone := TLabel.Create(Self);
  FLblPhone.Parent := LLayout;
  FLblPhone.Text := '手机号码';
  FLblPhone.Position.X := 0;
  FLblPhone.Position.Y := 70;
  FLblPhone.StyledSettings := [];
  
  FEdtPhone := TEdit.Create(Self);
  FEdtPhone.Parent := LLayout;
  FEdtPhone.Position.X := 0;
  FEdtPhone.Position.Y := 95;
  FEdtPhone.Width := 300;
  FEdtPhone.Height := 32;
  
  FLblBio := TLabel.Create(Self);
  FLblBio.Parent := LLayout;
  FLblBio.Text := '个人简介';
  FLblBio.Position.X := 0;
  FLblBio.Position.Y := 140;
  FLblBio.StyledSettings := [];
  
  FEdtBio := TEdit.Create(Self);
  FEdtBio.Parent := LLayout;
  FEdtBio.Position.X := 0;
  FEdtBio.Position.Y := 165;
  FEdtBio.Width := 500;
  FEdtBio.Height := 32;
  
  FLblInfoStatus := TLabel.Create(Self);
  FLblInfoStatus.Parent := LLayout;
  FLblInfoStatus.Text := '';
  FLblInfoStatus.Position.X := 0;
  FLblInfoStatus.Position.Y := 215;
  FLblInfoStatus.Width := 300;
  FLblInfoStatus.StyledSettings := [];
  FLblInfoStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  FBtnSaveInfo := TButton.Create(Self);
  FBtnSaveInfo.Parent := LLayout;
  FBtnSaveInfo.Text := '保存修改';
  FBtnSaveInfo.Position.X := 0;
  FBtnSaveInfo.Position.Y := 250;
  FBtnSaveInfo.Width := 120;
  FBtnSaveInfo.Height := 36;
  FBtnSaveInfo.OnClick := HandleSaveInfoClick;
end;

procedure TFMXUserProfileFrame.CreateChangePasswordTab;
var
  LLayout: TLayout;
begin
  LLayout := TLayout.Create(Self);
  LLayout.Parent := FTabChangePassword;
  LLayout.Align := TAlignLayout.Client;
  LLayout.Padding.Left := 20;
  LLayout.Padding.Right := 20;
  LLayout.Padding.Top := 20;
  
  FLblOldPassword := TLabel.Create(Self);
  FLblOldPassword.Parent := LLayout;
  FLblOldPassword.Text := '当前密码';
  FLblOldPassword.Position.X := 0;
  FLblOldPassword.Position.Y := 0;
  FLblOldPassword.StyledSettings := [];
  
  FEdtOldPassword := TEdit.Create(Self);
  FEdtOldPassword.Parent := LLayout;
  FEdtOldPassword.Position.X := 0;
  FEdtOldPassword.Position.Y := 25;
  FEdtOldPassword.Width := 300;
  FEdtOldPassword.Height := 32;
  FEdtOldPassword.Password := True;
  
  FLblNewPassword := TLabel.Create(Self);
  FLblNewPassword.Parent := LLayout;
  FLblNewPassword.Text := '新密码';
  FLblNewPassword.Position.X := 0;
  FLblNewPassword.Position.Y := 70;
  FLblNewPassword.StyledSettings := [];
  
  FEdtNewPassword := TEdit.Create(Self);
  FEdtNewPassword.Parent := LLayout;
  FEdtNewPassword.Position.X := 0;
  FEdtNewPassword.Position.Y := 95;
  FEdtNewPassword.Width := 300;
  FEdtNewPassword.Height := 32;
  FEdtNewPassword.Password := True;
  
  FLblConfirmPassword := TLabel.Create(Self);
  FLblConfirmPassword.Parent := LLayout;
  FLblConfirmPassword.Text := '确认新密码';
  FLblConfirmPassword.Position.X := 0;
  FLblConfirmPassword.Position.Y := 140;
  FLblConfirmPassword.StyledSettings := [];
  
  FEdtConfirmPassword := TEdit.Create(Self);
  FEdtConfirmPassword.Parent := LLayout;
  FEdtConfirmPassword.Position.X := 0;
  FEdtConfirmPassword.Position.Y := 165;
  FEdtConfirmPassword.Width := 300;
  FEdtConfirmPassword.Height := 32;
  FEdtConfirmPassword.Password := True;
  
  FLblPasswordStatus := TLabel.Create(Self);
  FLblPasswordStatus.Parent := LLayout;
  FLblPasswordStatus.Text := '';
  FLblPasswordStatus.Position.X := 0;
  FLblPasswordStatus.Position.Y := 215;
  FLblPasswordStatus.Width := 300;
  FLblPasswordStatus.StyledSettings := [];
  FLblPasswordStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  FBtnChangePassword := TButton.Create(Self);
  FBtnChangePassword.Parent := LLayout;
  FBtnChangePassword.Text := '修改密码';
  FBtnChangePassword.Position.X := 0;
  FBtnChangePassword.Position.Y := 250;
  FBtnChangePassword.Width := 120;
  FBtnChangePassword.Height := 36;
  FBtnChangePassword.OnClick := HandleChangePasswordClick;
end;

procedure TFMXUserProfileFrame.CreateSecurityTab;
var
  LLayout: TLayout;
begin
  LLayout := TLayout.Create(Self);
  LLayout.Parent := FTabSecurity;
  LLayout.Align := TAlignLayout.Client;
  LLayout.Padding.Left := 20;
  LLayout.Padding.Right := 20;
  LLayout.Padding.Top := 20;
  
  FLblSecurityTitle := TLabel.Create(Self);
  FLblSecurityTitle.Parent := LLayout;
  FLblSecurityTitle.Text := '安全信息';
  FLblSecurityTitle.Position.X := 0;
  FLblSecurityTitle.Position.Y := 0;
  FLblSecurityTitle.StyledSettings := [];
  FLblSecurityTitle.TextSettings.Font.Size := 14;
  FLblSecurityTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FLblLastLogin := TLabel.Create(Self);
  FLblLastLogin.Parent := LLayout;
  FLblLastLogin.Text := '上次登录时间:';
  FLblLastLogin.Position.X := 0;
  FLblLastLogin.Position.Y := 40;
  FLblLastLogin.StyledSettings := [];
  FLblLastLogin.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  FLblLastLoginValue := TLabel.Create(Self);
  FLblLastLoginValue.Parent := LLayout;
  FLblLastLoginValue.Text := '--';
  FLblLastLoginValue.Position.X := 120;
  FLblLastLoginValue.Position.Y := 40;
  FLblLastLoginValue.StyledSettings := [];
  
  FLblLastIP := TLabel.Create(Self);
  FLblLastIP.Parent := LLayout;
  FLblLastIP.Text := '上次登录IP:';
  FLblLastIP.Position.X := 0;
  FLblLastIP.Position.Y := 70;
  FLblLastIP.StyledSettings := [];
  FLblLastIP.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  FLblLastIPValue := TLabel.Create(Self);
  FLblLastIPValue.Parent := LLayout;
  FLblLastIPValue.Text := '--';
  FLblLastIPValue.Position.X := 120;
  FLblLastIPValue.Position.Y := 70;
  FLblLastIPValue.StyledSettings := [];
  
  FLblAccountCreated := TLabel.Create(Self);
  FLblAccountCreated.Parent := LLayout;
  FLblAccountCreated.Text := '账户创建时间:';
  FLblAccountCreated.Position.X := 0;
  FLblAccountCreated.Position.Y := 100;
  FLblAccountCreated.StyledSettings := [];
  FLblAccountCreated.TextSettings.FontColor := COLOR_TEXT_GRAY;
  
  FLblAccountCreatedValue := TLabel.Create(Self);
  FLblAccountCreatedValue.Parent := LLayout;
  FLblAccountCreatedValue.Text := '--';
  FLblAccountCreatedValue.Position.X := 120;
  FLblAccountCreatedValue.Position.Y := 100;
  FLblAccountCreatedValue.StyledSettings := [];
  
  FLblTwoFactor := TLabel.Create(Self);
  FLblTwoFactor.Parent := LLayout;
  FLblTwoFactor.Text := '两步验证';
  FLblTwoFactor.Position.X := 0;
  FLblTwoFactor.Position.Y := 150;
  FLblTwoFactor.StyledSettings := [];
  FLblTwoFactor.TextSettings.Font.Size := 14;
  FLblTwoFactor.TextSettings.Font.Style := [TFontStyle.fsBold];
  
  FChkTwoFactor := TCheckBox.Create(Self);
  FChkTwoFactor.Parent := LLayout;
  FChkTwoFactor.Text := '启用两步验证（登录时需要验证码）';
  FChkTwoFactor.Position.X := 0;
  FChkTwoFactor.Position.Y := 180;
  FChkTwoFactor.Enabled := False; // Read-only for now
end;

procedure TFMXUserProfileFrame.HandleSaveInfoClick(Sender: TObject);
var
  UpdateReq: TAipexUserUpdateRequest;
begin
  if not Assigned(FApiClient) then
  begin
    UpdateInfoStatus('API客户端未初始化', True);
    Exit;
  end;
  
  FBtnSaveInfo.Enabled := False;
  UpdateInfoStatus('正在保存...', False);
  
  try
    UpdateReq.Nickname := Trim(FEdtNickname.Text);
    UpdateReq.Phone := Trim(FEdtPhone.Text);
    UpdateReq.Bio := Trim(FEdtBio.Text);
    
    if FApiClient.UpdateProfile(UpdateReq) then
    begin
      UpdateInfoStatus('保存成功', False);
      FLblInfoStatus.TextSettings.FontColor := COLOR_SUCCESS;
      if Assigned(FOnProfileUpdated) then
        FOnProfileUpdated(Self);
    end
    else
      UpdateInfoStatus('保存失败', True);
  except
    on E: Exception do
      UpdateInfoStatus('保存出错: ' + E.Message, True);
  end;
  
  FBtnSaveInfo.Enabled := True;
end;

procedure TFMXUserProfileFrame.HandleChangePasswordClick(Sender: TObject);
begin
  if not Assigned(FApiClient) then
  begin
    UpdatePasswordStatus('API客户端未初始化', True);
    Exit;
  end;
  
  if Trim(FEdtOldPassword.Text) = '' then
  begin
    UpdatePasswordStatus('请输入当前密码', True);
    FEdtOldPassword.SetFocus;
    Exit;
  end;
  
  if Length(FEdtNewPassword.Text) < 6 then
  begin
    UpdatePasswordStatus('新密码至少需要6个字符', True);
    FEdtNewPassword.SetFocus;
    Exit;
  end;
  
  if FEdtNewPassword.Text <> FEdtConfirmPassword.Text then
  begin
    UpdatePasswordStatus('两次输入的新密码不一致', True);
    FEdtConfirmPassword.SetFocus;
    Exit;
  end;
  
  FBtnChangePassword.Enabled := False;
  UpdatePasswordStatus('正在修改...', False);
  
  try
    if FApiClient.ChangePassword(FEdtOldPassword.Text, FEdtNewPassword.Text) then
    begin
      UpdatePasswordStatus('密码修改成功', False);
      FLblPasswordStatus.TextSettings.FontColor := COLOR_SUCCESS;
      FEdtOldPassword.Text := '';
      FEdtNewPassword.Text := '';
      FEdtConfirmPassword.Text := '';
    end
    else
      UpdatePasswordStatus('修改失败，请检查当前密码是否正确', True);
  except
    on E: Exception do
      UpdatePasswordStatus('修改出错: ' + E.Message, True);
  end;
  
  FBtnChangePassword.Enabled := True;
end;

procedure TFMXUserProfileFrame.SetApiClient(Value: TAipexBaseClient);
begin
  FApiClient := Value;
end;

procedure TFMXUserProfileFrame.SetUser(const Value: TAipexUser);
begin
  FUser := Value;
  PopulateUserData;
end;

procedure TFMXUserProfileFrame.UpdateInfoStatus(const Msg: string; IsError: Boolean);
begin
  FLblInfoStatus.Text := Msg;
  if IsError then
    FLblInfoStatus.TextSettings.FontColor := COLOR_ERROR
  else
    FLblInfoStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
end;

procedure TFMXUserProfileFrame.UpdatePasswordStatus(const Msg: string; IsError: Boolean);
begin
  FLblPasswordStatus.Text := Msg;
  if IsError then
    FLblPasswordStatus.TextSettings.FontColor := COLOR_ERROR
  else
    FLblPasswordStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
end;

procedure TFMXUserProfileFrame.PopulateUserData;
begin
  if FUser.Username <> '' then
  begin
    FLblUsername.Text := FUser.Username;
    FLblAvatarText.Text := UpperCase(Copy(FUser.Username, 1, 1));
  end;
  
  if FUser.Email <> '' then
    FLblEmail.Text := FUser.Email;
    
  FEdtNickname.Text := FUser.Nickname;
  FEdtPhone.Text := FUser.Phone;
  FEdtBio.Text := FUser.Bio;
  
  if FUser.LastLoginAt > 0 then
    FLblLastLoginValue.Text := FormatDateTime('yyyy-mm-dd hh:nn:ss', FUser.LastLoginAt)
  else
    FLblLastLoginValue.Text := '--';
    
  FLblLastIPValue.Text := FUser.LastLoginIP;
  
  if FUser.CreatedAt > 0 then
    FLblAccountCreatedValue.Text := FormatDateTime('yyyy-mm-dd hh:nn:ss', FUser.CreatedAt)
  else
    FLblAccountCreatedValue.Text := '--';
    
  FChkTwoFactor.IsChecked := FUser.TwoFactorEnabled;
end;

procedure TFMXUserProfileFrame.RefreshData;
begin
  if Assigned(FApiClient) then
  begin
    try
      FUser := FApiClient.GetProfile;
      PopulateUserData;
    except
      // Silently ignore errors during refresh
    end;
  end;
end;

end.
