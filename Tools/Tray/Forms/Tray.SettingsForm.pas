unit Tray.SettingsForm;

{*******************************************************************************
  DeepBaseTray - 设置窗体
  
  功能:
  - Studio 路径配置
  - 窗口透明度设置
  - 置顶设置
  - 命令确认设置
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.StrUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls,
  Tray.Database;

type
  TTraySettingsForm = class(TForm)
  private
    { 界面组件 }
    FPnlButtons: TPanel;
    FBtnOK: TButton;
    FBtnCancel: TButton;
    FBtnApply: TButton;
    
    { Studio 设置 }
    FGrpStudio: TGroupBox;
    FLblStudioPath: TLabel;
    FEdtStudioPath: TEdit;
    FBtnBrowseStudio: TButton;
    
    { 窗口设置 }
    FGrpWindow: TGroupBox;
    FLblOpacity: TLabel;
    FTrkOpacity: TTrackBar;
    FLblOpacityValue: TLabel;
    FChkAlwaysOnTop: TCheckBox;
    FChkMinimizeOnClose: TCheckBox;
    FChkAutoStart: TCheckBox;
    
    { 命令设置 }
    FGrpCommand: TGroupBox;
    FChkCommandConfirm: TCheckBox;
    FChkDangerousConfirm: TCheckBox;
    
    procedure CreateUI;
    procedure LoadSettings;
    procedure SaveSettings;
    
    procedure OnBtnOKClick(Sender: TObject);
    procedure OnBtnCancelClick(Sender: TObject);
    procedure OnBtnApplyClick(Sender: TObject);
    procedure OnBtnBrowseStudioClick(Sender: TObject);
    procedure OnOpacityChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    class function Execute: Boolean;
  end;

implementation

{ TTraySettingsForm }

constructor TTraySettingsForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  Caption := '设置';
  Width := 450;
  Height := 400;
  Position := poMainFormCenter;
  BorderStyle := bsDialog;
  
  CreateUI;
  LoadSettings;
end;

procedure TTraySettingsForm.CreateUI;
begin
  // 按钮面板
  FPnlButtons := TPanel.Create(Self);
  FPnlButtons.Parent := Self;
  FPnlButtons.Align := alBottom;
  FPnlButtons.Height := 45;
  FPnlButtons.BevelOuter := bvNone;
  FPnlButtons.Caption := '';
  
  FBtnOK := TButton.Create(Self);
  FBtnOK.Parent := FPnlButtons;
  FBtnOK.Caption := '确定';
  FBtnOK.Width := 80;
  FBtnOK.Height := 28;
  FBtnOK.Left := FPnlButtons.Width - 270;
  FBtnOK.Top := 8;
  FBtnOK.Anchors := [akTop, akRight];
  FBtnOK.Default := True;
  FBtnOK.OnClick := OnBtnOKClick;
  
  FBtnCancel := TButton.Create(Self);
  FBtnCancel.Parent := FPnlButtons;
  FBtnCancel.Caption := '取消';
  FBtnCancel.Width := 80;
  FBtnCancel.Height := 28;
  FBtnCancel.Left := FPnlButtons.Width - 180;
  FBtnCancel.Top := 8;
  FBtnCancel.Anchors := [akTop, akRight];
  FBtnCancel.Cancel := True;
  FBtnCancel.OnClick := OnBtnCancelClick;
  
  FBtnApply := TButton.Create(Self);
  FBtnApply.Parent := FPnlButtons;
  FBtnApply.Caption := '应用';
  FBtnApply.Width := 80;
  FBtnApply.Height := 28;
  FBtnApply.Left := FPnlButtons.Width - 90;
  FBtnApply.Top := 8;
  FBtnApply.Anchors := [akTop, akRight];
  FBtnApply.OnClick := OnBtnApplyClick;
  
  // Studio 设置组
  FGrpStudio := TGroupBox.Create(Self);
  FGrpStudio.Parent := Self;
  FGrpStudio.Caption := ' Studio 设置 ';
  FGrpStudio.Left := 10;
  FGrpStudio.Top := 10;
  FGrpStudio.Width := Width - 30;
  FGrpStudio.Height := 70;
  FGrpStudio.Anchors := [akLeft, akTop, akRight];
  
  FLblStudioPath := TLabel.Create(Self);
  FLblStudioPath.Parent := FGrpStudio;
  FLblStudioPath.Caption := 'Studio 路径:';
  FLblStudioPath.Left := 15;
  FLblStudioPath.Top := 25;
  
  FEdtStudioPath := TEdit.Create(Self);
  FEdtStudioPath.Parent := FGrpStudio;
  FEdtStudioPath.Left := 15;
  FEdtStudioPath.Top := 42;
  FEdtStudioPath.Width := FGrpStudio.Width - 110;
  FEdtStudioPath.Anchors := [akLeft, akTop, akRight];
  
  FBtnBrowseStudio := TButton.Create(Self);
  FBtnBrowseStudio.Parent := FGrpStudio;
  FBtnBrowseStudio.Caption := '浏览...';
  FBtnBrowseStudio.Left := FGrpStudio.Width - 90;
  FBtnBrowseStudio.Top := 40;
  FBtnBrowseStudio.Width := 75;
  FBtnBrowseStudio.Anchors := [akTop, akRight];
  FBtnBrowseStudio.OnClick := OnBtnBrowseStudioClick;
  
  // 窗口设置组
  FGrpWindow := TGroupBox.Create(Self);
  FGrpWindow.Parent := Self;
  FGrpWindow.Caption := ' 窗口设置 ';
  FGrpWindow.Left := 10;
  FGrpWindow.Top := 90;
  FGrpWindow.Width := Width - 30;
  FGrpWindow.Height := 130;
  FGrpWindow.Anchors := [akLeft, akTop, akRight];
  
  FLblOpacity := TLabel.Create(Self);
  FLblOpacity.Parent := FGrpWindow;
  FLblOpacity.Caption := '透明度:';
  FLblOpacity.Left := 15;
  FLblOpacity.Top := 25;
  
  FTrkOpacity := TTrackBar.Create(Self);
  FTrkOpacity.Parent := FGrpWindow;
  FTrkOpacity.Left := 70;
  FTrkOpacity.Top := 20;
  FTrkOpacity.Width := FGrpWindow.Width - 150;
  FTrkOpacity.Min := 50;
  FTrkOpacity.Max := 255;
  FTrkOpacity.Position := 217;
  FTrkOpacity.Frequency := 20;
  FTrkOpacity.Anchors := [akLeft, akTop, akRight];
  FTrkOpacity.OnChange := OnOpacityChange;
  
  FLblOpacityValue := TLabel.Create(Self);
  FLblOpacityValue.Parent := FGrpWindow;
  FLblOpacityValue.Caption := '85%';
  FLblOpacityValue.Left := FGrpWindow.Width - 70;
  FLblOpacityValue.Top := 25;
  FLblOpacityValue.Anchors := [akTop, akRight];
  
  FChkAlwaysOnTop := TCheckBox.Create(Self);
  FChkAlwaysOnTop.Parent := FGrpWindow;
  FChkAlwaysOnTop.Caption := '窗口置顶';
  FChkAlwaysOnTop.Left := 15;
  FChkAlwaysOnTop.Top := 55;
  
  FChkMinimizeOnClose := TCheckBox.Create(Self);
  FChkMinimizeOnClose.Parent := FGrpWindow;
  FChkMinimizeOnClose.Caption := '关闭时最小化到托盘';
  FChkMinimizeOnClose.Left := 15;
  FChkMinimizeOnClose.Top := 80;
  
  FChkAutoStart := TCheckBox.Create(Self);
  FChkAutoStart.Parent := FGrpWindow;
  FChkAutoStart.Caption := '开机自动启动';
  FChkAutoStart.Left := 15;
  FChkAutoStart.Top := 105;
  
  // 命令设置组
  FGrpCommand := TGroupBox.Create(Self);
  FGrpCommand.Parent := Self;
  FGrpCommand.Caption := ' 命令设置 ';
  FGrpCommand.Left := 10;
  FGrpCommand.Top := 230;
  FGrpCommand.Width := Width - 30;
  FGrpCommand.Height := 80;
  FGrpCommand.Anchors := [akLeft, akTop, akRight];
  
  FChkCommandConfirm := TCheckBox.Create(Self);
  FChkCommandConfirm.Parent := FGrpCommand;
  FChkCommandConfirm.Caption := '执行命令前确认';
  FChkCommandConfirm.Left := 15;
  FChkCommandConfirm.Top := 25;
  
  FChkDangerousConfirm := TCheckBox.Create(Self);
  FChkDangerousConfirm.Parent := FGrpCommand;
  FChkDangerousConfirm.Caption := '危险命令双重确认';
  FChkDangerousConfirm.Left := 15;
  FChkDangerousConfirm.Top := 50;
end;

procedure TTraySettingsForm.LoadSettings;
begin
  FEdtStudioPath.Text := TrayDB.GetSetting('Tray.StudioPath', '');
  FTrkOpacity.Position := TrayDB.GetSettingInt('Tray.Opacity', 217);
  FChkAlwaysOnTop.Checked := TrayDB.GetSettingBool('Tray.AlwaysOnTop', True);
  FChkMinimizeOnClose.Checked := TrayDB.GetSettingBool('Tray.MinimizeOnClose', True);
  FChkAutoStart.Checked := TrayDB.GetSettingBool('Tray.AutoStart', False);
  FChkCommandConfirm.Checked := TrayDB.GetSettingBool('Tray.CommandConfirm', True);
  FChkDangerousConfirm.Checked := TrayDB.GetSettingBool('Tray.DangerousConfirm', True);
  
  OnOpacityChange(nil);
end;

procedure TTraySettingsForm.SaveSettings;
begin
  TrayDB.SetSetting('Tray.StudioPath', FEdtStudioPath.Text);
  TrayDB.SetSetting('Tray.Opacity', IntToStr(FTrkOpacity.Position));
  TrayDB.SetSetting('Tray.AlwaysOnTop', IfThen(FChkAlwaysOnTop.Checked, '1', '0'));
  TrayDB.SetSetting('Tray.MinimizeOnClose', IfThen(FChkMinimizeOnClose.Checked, '1', '0'));
  TrayDB.SetSetting('Tray.AutoStart', IfThen(FChkAutoStart.Checked, '1', '0'));
  TrayDB.SetSetting('Tray.CommandConfirm', IfThen(FChkCommandConfirm.Checked, '1', '0'));
  TrayDB.SetSetting('Tray.DangerousConfirm', IfThen(FChkDangerousConfirm.Checked, '1', '0'));
end;

procedure TTraySettingsForm.OnBtnOKClick(Sender: TObject);
begin
  SaveSettings;
  ModalResult := mrOK;
end;

procedure TTraySettingsForm.OnBtnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TTraySettingsForm.OnBtnApplyClick(Sender: TObject);
begin
  SaveSettings;
end;

procedure TTraySettingsForm.OnBtnBrowseStudioClick(Sender: TObject);
var
  Dlg: TOpenDialog;
begin
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Filter := '可执行文件 (*.exe)|*.exe|所有文件 (*.*)|*.*';
    Dlg.Title := '选择 Studio 可执行文件';
    if FEdtStudioPath.Text <> '' then
      Dlg.InitialDir := ExtractFilePath(FEdtStudioPath.Text);
    if Dlg.Execute then
      FEdtStudioPath.Text := Dlg.FileName;
  finally
    Dlg.Free;
  end;
end;

procedure TTraySettingsForm.OnOpacityChange(Sender: TObject);
var
  Percent: Integer;
begin
  Percent := Round(FTrkOpacity.Position / 255 * 100);
  FLblOpacityValue.Caption := IntToStr(Percent) + '%';
end;

class function TTraySettingsForm.Execute: Boolean;
var
  Form: TTraySettingsForm;
begin
  Form := TTraySettingsForm.Create(Application);
  try
    Result := Form.ShowModal = mrOK;
  finally
    Form.Free;
  end;
end;

end.
