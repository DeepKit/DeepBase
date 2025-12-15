{ ============================================================================
  UniBase.VCL.ForgotPasswordDialog - 找回密码对话框
  
  Version: 1.0
  Description: Password recovery dialog for sending reset link to email.
  ============================================================================ }

unit UniBase.VCL.ForgotPasswordDialog;

interface

uses
  System.SysUtils, System.Classes, System.UITypes,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Graphics,
  UniBase.AipexBase.Client;

type
  TForgotPasswordDialog = class(TForm)
  private
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FPnlContent: TPanel;
    FImgIcon: TImage;
    FLblInstruction: TLabel;
    FLblEmail: TLabel;
    FEdtEmail: TEdit;
    FLblStatus: TLabel;
    FPnlButtons: TPanel;
    FBtnSend: TButton;
    FBtnBack: TButton;
    
    FApiClient: TAipexBaseClient;
    FOwnsClient: Boolean;
    FOnBackToLogin: TNotifyEvent;
    FSentSuccess: Boolean;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure ApplyStyle;
    procedure HandleSendClick(Sender: TObject);
    procedure HandleBackClick(Sender: TObject);
    procedure HandleInputChange(Sender: TObject);
    procedure HandleKeyPress(Sender: TObject; var Key: Char);
    procedure SetApiClient(Value: TAipexBaseClient);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
    procedure ShowSuccessState;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    class function Execute(AClient: TAipexBaseClient = nil): Boolean; overload;
    class function Execute(const ABaseURL: string): Boolean; overload;
    
    property ApiClient: TAipexBaseClient read FApiClient write SetApiClient;
    property OnBackToLogin: TNotifyEvent read FOnBackToLogin write FOnBackToLogin;
  end;

implementation

uses
  Winapi.Windows, System.RegularExpressions;

const
  COLOR_PRIMARY = $EAEA66;
  COLOR_BG = $FAF7F5;
  COLOR_TEXT_GRAY = $999999;
  COLOR_ERROR = $0000FF;
  COLOR_SUCCESS = $00AA00;

{ TForgotPasswordDialog }

constructor TForgotPasswordDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := '找回密码';
  Width := 420;
  Height := 420;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  Color := COLOR_BG;
  Font.Name := 'Microsoft YaHei UI';
  Font.Size := 9;
  
  FOwnsClient := True;
  FApiClient := nil;
  FSentSuccess := False;
  
  CreateControls;
  LayoutControls;
  ApplyStyle;
end;

destructor TForgotPasswordDialog.Destroy;
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  inherited;
end;

procedure TForgotPasswordDialog.CreateControls;
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
  FLblTitle.Caption := '找回密码';
  FLblTitle.Font.Size := 20;
  FLblTitle.Font.Style := [fsBold];
  FLblTitle.Font.Color := clWhite;
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := '我们将发送重置链接到您的邮箱';
  FLblSubtitle.Font.Size := 10;
  FLblSubtitle.Font.Color := $FFFFFF;
  
  // Content Panel
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;
  FPnlContent.ParentBackground := False;
  FPnlContent.Color := clWhite;
  
  // Icon placeholder
  FImgIcon := TImage.Create(Self);
  FImgIcon.Parent := FPnlContent;
  FImgIcon.Visible := False; // Will show on success
  
  // Instruction text
  FLblInstruction := TLabel.Create(Self);
  FLblInstruction.Parent := FPnlContent;
  FLblInstruction.Caption := '请输入您注册时使用的邮箱地址，我们将发送密码重置链接到该邮箱。';
  FLblInstruction.WordWrap := True;
  FLblInstruction.Font.Color := COLOR_TEXT_GRAY;
  
  // Email
  FLblEmail := TLabel.Create(Self);
  FLblEmail.Parent := FPnlContent;
  FLblEmail.Caption := '邮箱地址';
  
  FEdtEmail := TEdit.Create(Self);
  FEdtEmail.Parent := FPnlContent;
  FEdtEmail.OnChange := HandleInputChange;
  FEdtEmail.OnKeyPress := HandleKeyPress;
  
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
  
  FBtnSend := TButton.Create(Self);
  FBtnSend.Parent := FPnlButtons;
  FBtnSend.Caption := '发送重置链接';
  FBtnSend.Default := True;
  FBtnSend.Enabled := False;
  FBtnSend.OnClick := HandleSendClick;
  
  FBtnBack := TButton.Create(Self);
  FBtnBack.Parent := FPnlButtons;
  FBtnBack.Caption := '返回登录';
  FBtnBack.OnClick := HandleBackClick;
end;

procedure TForgotPasswordDialog.LayoutControls;
var
  ContentLeft, ContentWidth: Integer;
begin
  ContentLeft := 40;
  ContentWidth := ClientWidth - 80;
  
  // Header
  FLblTitle.SetBounds(ContentLeft, 25, 300, 30);
  FLblSubtitle.SetBounds(ContentLeft, 58, 300, 20);
  
  // Content
  FLblInstruction.SetBounds(ContentLeft, 30, ContentWidth, 50);
  
  FLblEmail.SetBounds(ContentLeft, 95, 100, 18);
  FEdtEmail.SetBounds(ContentLeft, 115, ContentWidth, 32);
  
  FLblStatus.SetBounds(ContentLeft, 160, ContentWidth, 50);
  
  // Buttons
  FBtnSend.SetBounds(ContentLeft, 15, ContentWidth, 40);
  FBtnBack.SetBounds(ContentLeft, 65, ContentWidth, 25);
end;

procedure TForgotPasswordDialog.ApplyStyle;
begin
  FPnlHeader.Color := COLOR_PRIMARY;
  
  FEdtEmail.Font.Size := 10;
  
  FBtnSend.Font.Size := 11;
  FBtnSend.Font.Style := [fsBold];
  
  FBtnBack.Font.Color := COLOR_PRIMARY;
  FBtnBack.Flat := True;
end;

procedure TForgotPasswordDialog.DoShow;
begin
  inherited;
  FEdtEmail.SetFocus;
  FLblStatus.Caption := '';
  FSentSuccess := False;
end;

procedure TForgotPasswordDialog.HandleInputChange(Sender: TObject);
begin
  FLblStatus.Caption := '';
  FBtnSend.Enabled := Trim(FEdtEmail.Text) <> '';
end;

procedure TForgotPasswordDialog.HandleKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    Key := #0;
    if FBtnSend.Enabled then
      HandleSendClick(FBtnSend);
  end;
end;

procedure TForgotPasswordDialog.HandleSendClick(Sender: TObject);
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
  
  // Validate email format
  if not TRegEx.IsMatch(Email, '^[^@]+@[^@]+\.[^@]+$') then
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
    begin
      FSentSuccess := True;
      ShowSuccessState;
    end
    else
    begin
      UpdateStatus('发送失败，请稍后重试', True);
      FBtnSend.Enabled := True;
    end;
  except
    on E: EAipexBaseNotFoundError do
    begin
      // Don't reveal if email exists or not for security
      FSentSuccess := True;
      ShowSuccessState;
    end;
    on E: Exception do
    begin
      UpdateStatus('发送出错: ' + E.Message, True);
      FBtnSend.Enabled := True;
    end;
  end;
end;

procedure TForgotPasswordDialog.ShowSuccessState;
begin
  FLblTitle.Caption := '邮件已发送';
  FLblSubtitle.Caption := '请检查您的收件箱';
  
  FLblInstruction.Caption := '我们已将密码重置链接发送到您的邮箱。' + #13#10 +
    '如果几分钟内没有收到邮件，请检查垃圾邮件文件夹。';
  FLblInstruction.Font.Color := COLOR_SUCCESS;
  
  FLblEmail.Visible := False;
  FEdtEmail.Visible := False;
  FLblStatus.Caption := '';
  
  FBtnSend.Caption := '重新发送';
  FBtnSend.Enabled := True;
  FBtnBack.Caption := '返回登录';
end;

procedure TForgotPasswordDialog.HandleBackClick(Sender: TObject);
begin
  if Assigned(FOnBackToLogin) then
    FOnBackToLogin(Self)
  else
    ModalResult := mrCancel;
end;

procedure TForgotPasswordDialog.SetApiClient(Value: TAipexBaseClient);
begin
  if FOwnsClient and Assigned(FApiClient) then
    FreeAndNil(FApiClient);
  
  FApiClient := Value;
  FOwnsClient := False;
end;

procedure TForgotPasswordDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := COLOR_ERROR
  else
    FLblStatus.Font.Color := COLOR_TEXT_GRAY;
end;

class function TForgotPasswordDialog.Execute(AClient: TAipexBaseClient): Boolean;
var
  Dlg: TForgotPasswordDialog;
begin
  Dlg := TForgotPasswordDialog.Create(Application);
  try
    if Assigned(AClient) then
      Dlg.ApiClient := AClient;
    Dlg.ShowModal;
    Result := Dlg.FSentSuccess;
  finally
    Dlg.Free;
  end;
end;

class function TForgotPasswordDialog.Execute(const ABaseURL: string): Boolean;
var
  Dlg: TForgotPasswordDialog;
begin
  Dlg := TForgotPasswordDialog.Create(Application);
  try
    Dlg.FApiClient := TAipexBaseClient.Create(ABaseURL);
    Dlg.FOwnsClient := True;
    Dlg.ShowModal;
    Result := Dlg.FSentSuccess;
  finally
    Dlg.Free;
  end;
end;

end.
