{ ============================================================================
  DeepBase.VCL.LicenseAuthDialog - 许可证激活对话框
  
  版本: 1.0
  功能: 提供许可证输入、激活和验证界面
  ============================================================================ }

unit DeepBase.VCL.LicenseAuthDialog;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.Buttons,
  Vcl.Clipbrd,
  DeepBase.License;

type
  TLicenseAuthDialog = class(TForm)
  private
    FPnlHeader: TPanel;
    FLblTitle: TLabel;
    FLblSubtitle: TLabel;
    FPnlContent: TPanel;
    FLblKey: TLabel;
    FEdtKey: TMemo;
    FLblDeviceId: TLabel;
    FEdtDeviceId: TEdit;
    FBtnCopyDeviceId: TSpeedButton;
    FLblStatus: TLabel;
    FPnlButtons: TPanel;
    FBtnActivate: TButton;
    FBtnCancel: TButton;
    FBtnPaste: TButton;
    FLicense: TDeepBaseLicense;
    FOwnsLicense: Boolean;
    FActivationResult: TLicenseInfo;
    
    procedure CreateControls;
    procedure LayoutControls;
    procedure HandleActivateClick(Sender: TObject);
    procedure HandleCancelClick(Sender: TObject);
    procedure HandlePasteClick(Sender: TObject);
    procedure HandleCopyDeviceIdClick(Sender: TObject);
    procedure HandleKeyChange(Sender: TObject);
    procedure SetLicense(Value: TDeepBaseLicense);
    procedure UpdateStatus(const Msg: string; IsError: Boolean);
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>显示激活对话框</summary>
    class function Execute(ALicense: TDeepBaseLicense = nil): Boolean;
    
    /// <summary>关联的许可证管理器</summary>
    property License: TDeepBaseLicense read FLicense write SetLicense;
    
    /// <summary>激活结果</summary>
    property ActivationResult: TLicenseInfo read FActivationResult;
  end;

implementation

{ TLicenseAuthDialog }

constructor TLicenseAuthDialog.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  
  Caption := 'License Activation';
  Width := 500;
  Height := 340;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  
  FOwnsLicense := True;
  FLicense := TDeepBaseLicense.Create;
  
  CreateControls;
  LayoutControls;
end;

destructor TLicenseAuthDialog.Destroy;
begin
  if FOwnsLicense then
    FreeAndNil(FLicense);
  inherited;
end;

procedure TLicenseAuthDialog.CreateControls;
begin
  // 头部面板
  FPnlHeader := TPanel.Create(Self);
  FPnlHeader.Parent := Self;
  FPnlHeader.Align := alTop;
  FPnlHeader.Height := 60;
  FPnlHeader.BevelOuter := bvNone;
  FPnlHeader.Color := clWhite;
  FPnlHeader.ParentBackground := False;
  
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FPnlHeader;
  FLblTitle.Caption := 'Activate License';
  FLblTitle.Font.Size := 14;
  FLblTitle.Font.Style := [fsBold];
  
  FLblSubtitle := TLabel.Create(Self);
  FLblSubtitle.Parent := FPnlHeader;
  FLblSubtitle.Caption := 'Enter your license key to activate the software';
  FLblSubtitle.Font.Color := clGray;
  
  // 内容面板
  FPnlContent := TPanel.Create(Self);
  FPnlContent.Parent := Self;
  FPnlContent.Align := alClient;
  FPnlContent.BevelOuter := bvNone;
  
  FLblKey := TLabel.Create(Self);
  FLblKey.Parent := FPnlContent;
  FLblKey.Caption := 'License Key:';
  
  FEdtKey := TMemo.Create(Self);
  FEdtKey.Parent := FPnlContent;
  FEdtKey.ScrollBars := ssVertical;
  FEdtKey.OnChange := HandleKeyChange;
  
  FBtnPaste := TButton.Create(Self);
  FBtnPaste.Parent := FPnlContent;
  FBtnPaste.Caption := 'Paste';
  FBtnPaste.OnClick := HandlePasteClick;
  
  FLblDeviceId := TLabel.Create(Self);
  FLblDeviceId.Parent := FPnlContent;
  FLblDeviceId.Caption := 'Device ID:';
  
  FEdtDeviceId := TEdit.Create(Self);
  FEdtDeviceId.Parent := FPnlContent;
  FEdtDeviceId.ReadOnly := True;
  FEdtDeviceId.Color := clBtnFace;
  
  FBtnCopyDeviceId := TSpeedButton.Create(Self);
  FBtnCopyDeviceId.Parent := FPnlContent;
  FBtnCopyDeviceId.Caption := 'Copy';
  FBtnCopyDeviceId.OnClick := HandleCopyDeviceIdClick;
  
  FLblStatus := TLabel.Create(Self);
  FLblStatus.Parent := FPnlContent;
  FLblStatus.Caption := '';
  FLblStatus.Font.Color := clGray;
  FLblStatus.WordWrap := True;
  
  // 按钮面板
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 50;
  FPnlButtons.BevelOuter := bvNone;
  
  FBtnActivate := TButton.Create(Self);
  FBtnActivate.Parent := FPnlButtons;
  FBtnActivate.Caption := 'Activate';
  FBtnActivate.Default := True;
  FBtnActivate.Enabled := False;
  FBtnActivate.OnClick := HandleActivateClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPnlButtons;
  FBtnCancel.Caption := 'Cancel';
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := HandleCancelClick;
end;

procedure TLicenseAuthDialog.LayoutControls;
begin
  // 头部
  FLblTitle.SetBounds(16, 12, 300, 24);
  FLblSubtitle.SetBounds(16, 36, 400, 16);
  
  // 内容
  FLblKey.SetBounds(16, 16, 100, 16);
  FEdtKey.SetBounds(16, 34, ClientWidth - 100, 80);
  FBtnPaste.SetBounds(ClientWidth - 76, 34, 60, 25);
  
  FLblDeviceId.SetBounds(16, 124, 100, 16);
  FEdtDeviceId.SetBounds(16, 142, ClientWidth - 100, 24);
  FBtnCopyDeviceId.SetBounds(ClientWidth - 76, 142, 60, 24);
  
  FLblStatus.SetBounds(16, 176, ClientWidth - 32, 40);
  
  // 按钮
  FBtnCancel.SetBounds(ClientWidth - 92, 12, 80, 28);
  FBtnActivate.SetBounds(ClientWidth - 180, 12, 80, 28);
end;

procedure TLicenseAuthDialog.DoShow;
begin
  inherited;
  
  // 显示设备 ID
  if Assigned(FLicense) then
    FEdtDeviceId.Text := Copy(FLicense.GetDeviceId, 1, 32) + '...';
  
  FEdtKey.SetFocus;
end;

procedure TLicenseAuthDialog.HandleKeyChange(Sender: TObject);
begin
  FBtnActivate.Enabled := Trim(FEdtKey.Text) <> '';
  FLblStatus.Caption := '';
end;

procedure TLicenseAuthDialog.HandleActivateClick(Sender: TObject);
var
  Key: string;
begin
  Key := Trim(FEdtKey.Text);
  
  if Key = '' then
  begin
    UpdateStatus('Please enter a license key', True);
    Exit;
  end;
  
  UpdateStatus('Validating license...', False);
  Application.ProcessMessages;
  
  // 尝试激活
  FActivationResult := FLicense.ValidateLicense(Key);

  if FActivationResult.IsValid then
  begin
    FLicense.ActivateLicense(Key);
    UpdateStatus('License activated successfully!', False);
    FLblStatus.Font.Color := clGreen;
    ModalResult := mrOk;
  end
  else
  begin
    UpdateStatus('Activation failed: ' +
      TDeepBaseLicense.LicenseStatusToStr(FActivationResult.Status), True);
  end;
end;

procedure TLicenseAuthDialog.HandleCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TLicenseAuthDialog.HandlePasteClick(Sender: TObject);
begin
  if Clipboard.AsText <> '' then
  begin
    FEdtKey.Text := Clipboard.AsText;
    HandleKeyChange(nil);
  end;
end;

procedure TLicenseAuthDialog.HandleCopyDeviceIdClick(Sender: TObject);
begin
  if Assigned(FLicense) then
  begin
    Clipboard.AsText := FLicense.GetDeviceId;
    UpdateStatus('Device ID copied to clipboard', False);
  end;
end;

procedure TLicenseAuthDialog.SetLicense(Value: TDeepBaseLicense);
begin
  if FOwnsLicense and Assigned(FLicense) then
    FreeAndNil(FLicense);
  
  FLicense := Value;
  FOwnsLicense := False;
  
  if Assigned(FLicense) then
    FEdtDeviceId.Text := Copy(FLicense.GetDeviceId, 1, 32) + '...';
end;

procedure TLicenseAuthDialog.UpdateStatus(const Msg: string; IsError: Boolean);
begin
  FLblStatus.Caption := Msg;
  if IsError then
    FLblStatus.Font.Color := clRed
  else
    FLblStatus.Font.Color := clGray;
end;

class function TLicenseAuthDialog.Execute(ALicense: TDeepBaseLicense): Boolean;
var
  Dlg: TLicenseAuthDialog;
begin
  Dlg := TLicenseAuthDialog.Create(Application);
  try
    if Assigned(ALicense) then
      Dlg.License := ALicense;
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
