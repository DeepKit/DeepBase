{ ============================================================================
  DeepBase.FMX.UpdateDialog - FMX 更新对话�?
  版本: 1.0
  说明: 跨平台更新提示对话框，支�?Windows/macOS/iOS/Android

  特�?
    - 自适应布局（手�?平板/桌面�?    - 显示版本信息和更新日�?    - 下载进度显示
    - 支持强制更新
    - 支持跳转应用商店
  ============================================================================ }

unit DeepBase.FMX.UpdateDialog;

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  FMX.Types,
  FMX.Controls,
  FMX.Forms,
  FMX.Graphics,
  FMX.Dialogs,
  FMX.StdCtrls,
  FMX.Controls.Presentation,
  FMX.Layouts,
  FMX.Memo,
  FMX.Objects,
  FMX.Ani,
  FMX.Effects,
  FMX.Memo.Types,
  FMX.ScrollBox,
  DeepBase.Updater;

type
  TUpdateDialogAction = (udaDownload, udaOpenStore, udaLater, udaSkip);
  TUpdateDialogCallback = reference to procedure(Action: TUpdateDialogAction);

  TFMXUpdateDialog = class(TForm)
    LayoutMain: TLayout;
    RectBackground: TRectangle;
    LayoutContent: TLayout;
    LayoutHeader: TLayout;
    ImgIcon: TImage;
    LblTitle: TLabel;
    LblVersion: TLabel;
    LayoutBody: TLayout;
    MemoChangelog: TMemo;
    LayoutProgress: TLayout;
    ProgressBar: TProgressBar;
    LblProgressStatus: TLabel;
    LayoutButtons: TLayout;
    BtnUpdate: TButton;
    BtnLater: TButton;
    BtnSkip: TButton;
    ShadowEffect: TShadowEffect;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure BtnUpdateClick(Sender: TObject);
    procedure BtnLaterClick(Sender: TObject);
    procedure BtnSkipClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FUpdateInfo: TUpdateInfo;
    FCallback: TUpdateDialogCallback;
    FAutoUpdater: TComponent;
    FIsDownloading: Boolean;
    FIsMobile: Boolean;

    procedure UpdateLayout;
    procedure StartDownload;
    procedure UpdateProgress(const Progress: TUpdateProgress);
    procedure DownloadComplete(Success: Boolean; const ErrorMessage: string);
    function IsMobilePlatform: Boolean;
    procedure HandleAutoUpdaterProgress(Sender: TObject; const Progress: TUpdateProgress);
    procedure HandleAutoUpdaterComplete(Sender: TObject; Success: Boolean; const ErrorMessage: string);
  public
    class procedure ShowDialog(AAutoUpdater: TComponent; const Info: TUpdateInfo;
      Callback: TUpdateDialogCallback);
  end;

implementation

{$R *.fmx}

uses
  FMX.Platform,
  DeepBase.FMX.AutoUpdater;

{ TFMXUpdateDialog }

class procedure TFMXUpdateDialog.ShowDialog(AAutoUpdater: TComponent;
  const Info: TUpdateInfo; Callback: TUpdateDialogCallback);
var
  Dialog: TFMXUpdateDialog;
begin
  Dialog := TFMXUpdateDialog.Create(nil);
  Dialog.FAutoUpdater := AAutoUpdater;
  Dialog.FUpdateInfo := Info;
  Dialog.FCallback := Callback;

  // 设置版本信息
  Dialog.LblTitle.Text := Info.Title;
  if Dialog.LblTitle.Text = '' then
    Dialog.LblTitle.Text := 'New version available';

  Dialog.LblVersion.Text := Format('Version %s -> %s',
    [TFMXAutoUpdater(AAutoUpdater).CurrentVersion, Info.Version.ToString]);

  // 设置更新日志
  Dialog.MemoChangelog.Lines.Text := Info.ReleaseNotes;
  if Dialog.MemoChangelog.Lines.Text = '' then
    Dialog.MemoChangelog.Lines.Text := Info.Description;

  // 强制更新时禁用跳过和稍后按钮
  if Info.IsMandatory then
  begin
    Dialog.BtnLater.Enabled := False;
    Dialog.BtnSkip.Visible := False;
  end;

  // 移动端显�?前往商店"而不�?下载"
  if Dialog.IsMobilePlatform then
    Dialog.BtnUpdate.Text := '前往商店';

  Dialog.Show;
end;

procedure TFMXUpdateDialog.FormCreate(Sender: TObject);
begin
  FIsDownloading := False;
  FIsMobile := IsMobilePlatform;

  // Initially hide progress panel.
  LayoutProgress.Visible := False;
  // 根据平台调整样式
  UpdateLayout;

  {$IFDEF MSWINDOWS}
  // Rounded corners on Windows.
  RectBackground.XRadius := 8;
  {$ENDIF}

  {$IFDEF MACOS}
  // macOS 风格
  RectBackground.XRadius := 12;
  RectBackground.YRadius := 12;
  {$ENDIF}
end;

procedure TFMXUpdateDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  // 强制更新时不允许关闭
  if FUpdateInfo.IsMandatory and not FIsDownloading then
    Action := TCloseAction.caNone
  else
    Action := TCloseAction.caFree;
end;

procedure TFMXUpdateDialog.FormResize(Sender: TObject);
begin
  UpdateLayout;
end;

function TFMXUpdateDialog.IsMobilePlatform: Boolean;
begin
  {$IF DEFINED(IOS) OR DEFINED(ANDROID)}
  Result := True;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

procedure TFMXUpdateDialog.UpdateLayout;
var
  IsCompact: Boolean;
begin
  IsCompact := (Width < 400) or FIsMobile;

  if IsCompact then
  begin
    // 紧凑布局（移动端/小窗口）
    LayoutButtons.Align := TAlignLayout.Bottom;
    LayoutButtons.Height := 120;
    BtnUpdate.Align := TAlignLayout.Top;
    BtnUpdate.Margins.Bottom := 8;
    BtnLater.Align := TAlignLayout.Top;
    BtnLater.Margins.Bottom := 8;
    BtnSkip.Align := TAlignLayout.Top;
  end
  else
  begin
    // 标准布局（桌面）
    LayoutButtons.Align := TAlignLayout.Bottom;
    LayoutButtons.Height := 50;
    BtnUpdate.Align := TAlignLayout.Right;
    BtnUpdate.Width := 100;
    BtnUpdate.Margins.Left := 8;
    BtnLater.Align := TAlignLayout.Right;
    BtnLater.Width := 80;
    BtnLater.Margins.Left := 8;
    BtnSkip.Align := TAlignLayout.Left;
    BtnSkip.Width := 100;
  end;
end;

procedure TFMXUpdateDialog.BtnUpdateClick(Sender: TObject);
begin
  if FIsMobile then
  begin
    // 移动端跳转应用商�?    if Assigned(FCallback) then
      FCallback(udaOpenStore);
    Close;
  end
  else
  begin
    // 桌面端下载更�?    if not FIsDownloading then
      StartDownload;
  end;
end;

procedure TFMXUpdateDialog.BtnLaterClick(Sender: TObject);
begin
  if FIsDownloading then
  begin
    // 取消下载
    if FAutoUpdater is TFMXAutoUpdater then
      TFMXAutoUpdater(FAutoUpdater).Cancel;
    FIsDownloading := False;

    // 重置 UI
    LayoutProgress.Visible := False;
    BtnUpdate.Enabled := True;
    BtnLater.Text := '稍后';
  end
  else
  begin
    if Assigned(FCallback) then
      FCallback(udaLater);
    Close;
  end;
end;

procedure TFMXUpdateDialog.BtnSkipClick(Sender: TObject);
begin
  if MessageDlg('Skip this version? You can check for updates later in settings.',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
  begin
    if Assigned(FCallback) then
      FCallback(udaSkip);
    Close;
  end;
end;

procedure TFMXUpdateDialog.StartDownload;
var
  AutoUpdater: TFMXAutoUpdater;
begin
  if not (FAutoUpdater is TFMXAutoUpdater) then
    Exit;

  AutoUpdater := TFMXAutoUpdater(FAutoUpdater);
  FIsDownloading := True;

  // 更新 UI
  LayoutProgress.Visible := True;
  ProgressBar.Value := 0;
  LblProgressStatus.Text := '准备下载...';
  BtnUpdate.Enabled := False;
  BtnLater.Text := '取消';
  BtnSkip.Visible := False;

  // 设置进度回调
  AutoUpdater.OnProgress := HandleAutoUpdaterProgress;

  // 设置完成回调
  AutoUpdater.OnUpdateComplete := HandleAutoUpdaterComplete;

  // 开始下�?  AutoUpdater.DownloadAndInstall;
end;

procedure TFMXUpdateDialog.UpdateProgress(const Progress: TUpdateProgress);
begin
  ProgressBar.Value := Progress.ProgressPercent;

  case Progress.Status of
    usDownloading:
      begin
        if Progress.TotalBytes > 0 then
          LblProgressStatus.Text := Format('下载�?.. %d%% (%s / %s)',
            [Progress.ProgressPercent,
             FormatFloat('#,##0', Progress.DownloadedBytes / 1024) + ' KB',
             FormatFloat('#,##0', Progress.TotalBytes / 1024) + ' KB'])
        else
          LblProgressStatus.Text := Format('下载�?.. %s',
            [FormatFloat('#,##0', Progress.DownloadedBytes / 1024) + ' KB']);
      end;
    usVerifying:
      LblProgressStatus.Text := '正在验证...';
    usBackingUp:
      LblProgressStatus.Text := '正在备份...';
    usInstalling:
      LblProgressStatus.Text := '正在安装...';
    usRollingBack:
      LblProgressStatus.Text := '正在回滚...';
  else
    LblProgressStatus.Text := Progress.StatusMessage;
  end;
end;

procedure TFMXUpdateDialog.DownloadComplete(Success: Boolean; const ErrorMessage: string);
begin
  FIsDownloading := False;

  if Success then
  begin
    LblProgressStatus.Text := 'Update complete';
    ProgressBar.Value := 100;

    if MessageDlg('更新已安装完成。是否立即重启应用？',
      TMsgDlgType.mtInformation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      // TODO: 重启应用
      // Application.Terminate;
    end;

    if Assigned(FCallback) then
      FCallback(udaDownload);
    Close;
  end
  else
  begin
    // 下载失败
    LblProgressStatus.Text := '更新失败';

    if MessageDlg('Update failed: ' + ErrorMessage + #13#10#13#10 + 'Retry?',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) = mrYes then
    begin
      // Reset UI and retry.
      LayoutProgress.Visible := False;
      BtnLater.Text := '稍后';
      if not FUpdateInfo.IsMandatory then
        BtnSkip.Visible := True;
    end
    else
    begin
      // 重置 UI
      LayoutProgress.Visible := False;
      BtnUpdate.Enabled := True;
      BtnLater.Text := '稍后';
      if not FUpdateInfo.IsMandatory then
        BtnSkip.Visible := True;
    end;
  end;
end;

procedure TFMXUpdateDialog.HandleAutoUpdaterProgress(Sender: TObject;
  const Progress: TUpdateProgress);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      UpdateProgress(Progress);
    end);
end;

procedure TFMXUpdateDialog.HandleAutoUpdaterComplete(Sender: TObject;
  Success: Boolean; const ErrorMessage: string);
begin
  TThread.Synchronize(nil,
    procedure
    begin
      DownloadComplete(Success, ErrorMessage);
    end);
end;

end.
