{ ============================================================================
  UniBase.FMX.ForgotPasswordDialog - FMX 找回密码对话框
  
  Version: 1.0
  Description: Modern FMX forgot password dialog with email input and
               password reset link functionality.
  ============================================================================ }

unit UniBase.FMX.ForgotPasswordDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.StdCtrls, FMX.Edit,
  FMX.Objects, FMX.Layouts, FMX.Graphics,
  UniBase.AipexBase.Client;

type
  TFMXForgotPasswordDialog = class(TForm)
  private
    FLayoutMain: TLayout;
    FRectHeader: TRectangle;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FRectContent: TRectangle;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblStatus: TLabel;
    FBtnSend: TButton;
    FLblBack: TLabel;
    // Success state
    FRectSuccess: TRectangle;
    FLblSuccessIcon: TLabel;
    FLblSuccessTitle: TLabel;
    FLblSuccessMsg: TLabel;
    FBtnBackToLogin: TButton;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FOnBack: TNotifyEvent;
    
    procedure CreateControls;
    procedure CreateSuccessControls;
    procedure HandleSendClick(Sender: TObject);
    procedure HandleBackClick(Sender: TObject);
    procedure HandleKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char; Shift: TShiftState);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure ShowSuccessState;
    function ValidateEmail(const Email: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    class function Execute(AClient: TAipexBaseClient = nil): Boolean; overload;
    class function Execute(const ABaseURL: string): Boolean; overload;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property OnBack: TNotifyEvent read FOnBack write FOnBack;
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

{ TFMXForgotPasswordDialog }

constructor TFMXForgotPasswordDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '找回密码';
  ClientWidth := 400;
  ClientHeight := 450;
  Position := TFormPosition.ScreenCenter;
  BorderStyle := TFmxFormBorderStyle.Single;
  Fill.Color := COLOR_BG;
  Fill.Kind := TBrushKind.Solid;
  
  FOwnsClient := True;
  FApiClient := nil;
  
  CreateControls;
  CreateSuccessControls;
end;

destructor TFMXForgotPasswordDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TFMXForgotPasswordDialog.CreateControls;
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
  FLblTitle.Text := '找回密码';
  FLblTitle.Position.X := 40;
  FLblTitle.Position.Y := 25;
  FLblTitle.StyledSettings := [];
  FLblTitle.TextSettings.Font.Size := 22;
  FLblTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblTitle.TextSettings.FontColor := TAlphaColors.White;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FRectHeader;
  FLblSubtitle.Text := '输入邮箱接收重置链接';
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
  FRectContent.Height := 300;
  FRectContent.Fill.Color := TAlphaColors.White;
  FRectContent.Stroke.Kind := TBrushKind.None;
  FRectContent.XRadius := 8;
  FRectContent.YRadius := 8;
  
  // Email
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FRectContent;
  FLblEmail.Text := '注册邮箱';
  FLblEmail.Position.X := 25;
  FLblEmail.Position.Y := 30;
  FLblEmail.StyledSettings := [];
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FRectContent;
  FEdtEmail.Position.X := 25;
  FEdtEmail.Position.Y := 55;
  FEdtEmail.Width := 290;
  FEdtEmail.Height := 32;
  FEdtEmail.TextPrompt := '请输入注册时使用的邮箱';
  FEdtEmail.OnKeyDown := HandleKeyDown;
  
  // Status
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FRectContent;
  FLblStatus.Text := '';
  FLblStatus.Position.X := 25;
  FLblStatus.Position.Y := 100;
  FLblStatus.Width := 290;
  FLblStatus.Height := 50;
  FLblStatus.StyledSettings := [];
  FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
  FLblStatus.TextSettings.WordWrap := True;
  
  // Send Button
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FRectContent;
  FBtnSend.Text := '发送重置链接';
  FBtnSend.Position.X := 25;
  FBtnSend.Position.Y := 165;
  FBtnSend.Width := 290;
  FBtnSend.Height := 44;
  FBtnSend.OnClick := HandleSendClick;
  
  // Back Link
  FLblBack := TLabel.Create(Self);
  FLblBack.Parent := FRectContent;
  FLblBack.Text := '← 返回登录';
  FLblBack.Position.X := 120;
  FLblBack.Position.Y := 225;
  FLblBack.StyledSettings := [];
  FLblBack.TextSettings.FontColor := COLOR_PRIMARY;
  FLblBack.Cursor := crHandPoint;
  FLblBack.HitTest := True;
  FLblBack.OnClick := HandleBackClick;
end;

procedure TFMXForgotPasswordDialog.CreateSuccessControls;
begin
  // Success panel (initially hidden)
  FRectSuccess := TRectangle.Create(Self);
  FRectSuccess.Parent := FLayoutMain;
  FRectSuccess.Position.X := 30;
  FRectSuccess.Position.Y := 110;
  FRectSuccess.Width := 340;
  FRectSuccess.Height := 300;
  FRectSuccess.Fill.Color := TAlphaColors.White;
  FRectSuccess.Stroke.Kind := TBrushKind.None;
  FRectSuccess.XRadius := 8;
  FRectSuccess.YRadius := 8;
  FRectSuccess.Visible := False;
  
  // Success icon (checkmark)
  FLblSuccessIcon := TLabel.Create(Self);
  FLblSuccessIcon.Parent := FRectSuccess;
  FLblSuccessIcon.Text := '✓';
  FLblSuccessIcon.Position.X := 145;
  FLblSuccessIcon.Position.Y := 30;
  FLblSuccessIcon.StyledSettings := [];
  FLblSuccessIcon.TextSettings.Font.Size := 48;
  FLblSuccessIcon.TextSettings.FontColor := COLOR_SUCCESS;
  
  FLblSuccessTitle := TLabel.Create(Self);
  FLblSuccessTitle.Parent := FRectSuccess;
  FLblSuccessTitle.Text := '邮件已发送';
  FLblSuccessTitle.Position.X := 110;
  FLblSuccessTitle.Position.Y := 100;
  FLblSuccessTitle.StyledSettings := [];
  FLblSuccessTitle.TextSettings.Font.Size := 18;
  FLblSuccessTitle.TextSettings.Font.Style := [TFontStyle.fsBold];
  FLblSuccessTitle.TextSettings.FontColor := $FF333333;
  
  FLblSuccessMsg := TLabel.Create(Self);
  FLblSuccessMsg.Parent := FRectSuccess;
  FLblSuccessMsg.Text := '请检查您的邮箱，点击邮件中的链接重置密码';
  FLblSuccessMsg.Position.X := 25;
  FLblSuccessMsg.Position.Y := 140;
  FLblSuccessMsg.Width := 290;
  FLblSuccessMsg.Height := 50;
  FLblSuccessMsg.StyledSettings := [];
  FLblSuccessMsg.TextSettings.FontColor := COLOR_TEXT_GRAY;
  FLblSuccessMsg.TextSettings.HorzAlign := TTextAlign.Center;
  FLblSuccessMsg.TextSettings.WordWrap := True;
  
  FBtnBackToLogin := TButton.Create(Self);
  FBtnBackToLogin.Parent := FRectSuccess;
  FBtnBackToLogin.Text := '返回登录';
  FBtnBackToLogin.Position.X := 25;
  FBtnBackToLogin.Position.Y := 210;
  FBtnBackToLogin.Width := 290;
  FBtnBackToLogin.Height := 44;
  FBtnBackToLogin.OnClick := HandleBackClick;
end;

procedure TFMXForgotPasswordDialog.HandleKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if Key = vkReturn then
  begin
    Key := 0;
    HandleSendClick(FBtnSend);
  end;
end;

function TFMXForgotPasswordDialog.ValidateEmail(const Email: string): Boolean;
begin
  Result := TRegEx.IsMatch(Email, '^[^@]+@[^@]+\.[^@]+$');
end;

procedure TFMXForgotPasswordDialog.HandleSendClick(Sender: TObject);
var
  Email: string;
begin
  Email := Trim(FEdtEmail.Text);
  
  if Email = '' then
  begin
    UpdateStatus('请输入邮箱地址', True);
    FEdtEmail.SetFocus;
    Exit;
  end;
  
  if not ValidateEmail(Email) then
  begin
    UpdateStatus('请输入有效的邮箱地址', True);
    FEdtEmail.SetFocus;
    Exit;
  end;
  
  if not Assigned(FApiClient) then
  begin
    UpdateStatus('API客户端未初始化', True);
    Exit;
  end;
  
  FBtnSend.Enabled := False;
  UpdateStatus('正在发送...', False);
  Application.ProcessMessages;
  
  try
    if FApiClient.ForgotPassword(Email) then
      ShowSuccessState
    else
    begin
      UpdateStatus('发送失败，请稍后重试', True);
      FBtnSend.Enabled := True;
    end;
  except
    on E: Exception do
    begin
      UpdateStatus('发送出错: ' + E.Message, True);
      FBtnSend.Enabled := True;
    end;
  end;
end;

procedure TFMXForgotPasswordDialog.HandleBackClick(Sender: TObject);
begin
  if Assigned(FOnBack) then
    FOnBack(Self)
  else
    ModalResult := mrCancel;
end;

procedure TFMXForgotPasswordDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TFMXForgotPasswordDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Text := Msg;
  if IsError then
    FLblStatus.TextSettings.FontColor := COLOR_ERROR
  else
    FLblStatus.TextSettings.FontColor := COLOR_TEXT_GRAY;
end;

procedure TFMXForgotPasswordDialog.ShowSuccessState;
begin
  FRectContent.Visible := False;
  FRectSuccess.Visible := True;
end;

class function TFMXForgotPasswordDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TFMXForgotPasswordDialog;
begin
  Dlg := TFMXForgotPasswordDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

class function TFMXForgotPasswordDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TFMXForgotPasswordDialog;
begin
  Dlg := TFMXForgotPasswordDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
