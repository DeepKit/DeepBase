{ ============================================================================
  DeepBase.VCL.UpdateDialog - 更新提示对话框
  
  版本: 0.3
  说明: 显示更新信息并执行下载
  ============================================================================ }

unit DeepBase.VCL.UpdateDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  DeepBase.AutoUpdate, DeepBase.VCL.UIHelper;

type
  TUpdateDialog = class(TForm)
    lblTitle: TLabel;
    lblVersion: TLabel;
    mmoChangelog: TMemo;
    pbDownload: TProgressBar;
    btnUpdate: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnUpdateClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
  private
    FUpdateInfo: TUpdateInfo;
    FAutoUpdate: TDeepBaseAutoUpdate;
    FIsDownloading: Boolean;
    FCancelRequested: Boolean;
    FDownloadThread: TThread;
    procedure StartDownload;
    procedure WaitForDownloadThread;
  public
    class function Execute(AAutoUpdate: TDeepBaseAutoUpdate; const Info: TUpdateInfo): Boolean;
    destructor Destroy; override;
  end;

implementation

uses
  System.IOUtils;

{$R *.dfm}

{ TUpdateDialog }

class function TUpdateDialog.Execute(AAutoUpdate: TDeepBaseAutoUpdate; const Info: TUpdateInfo): Boolean;
var
  Dlg: TUpdateDialog;
begin
  Result := False;
  Dlg := TUpdateDialog.Create(nil);
  try
    Dlg.FAutoUpdate := AAutoUpdate;
    // UI2-011: Synchronize FUpdateInfo write through the UI thread so the
    // worker thread's read (via DownloadUpdate) is properly ordered.
    TThread.Synchronize(nil, procedure
    begin
      Dlg.FUpdateInfo := Info;
    end);
    
    Dlg.lblVersion.Caption := Format('Version %s available (Current: %s)', [Info.Version, '1.0.0']); // STUB(UPD-P0-001): Pass current ver
    Dlg.mmoChangelog.Lines.Text := Info.Changelog;
    
    if Info.ForceUpdate then
    begin
      Dlg.btnCancel.Enabled := False;
      Dlg.BorderIcons := [];
    end;
    
    Dlg.ShowModal;
    // Result handled by download logic usually, but here we just return true if user clicked update
  finally
    Dlg.Free;
  end;
end;

procedure TUpdateDialog.FormCreate(Sender: TObject);
begin
  TDeepBaseUIHelper.ApplyMicaEffect(Self);
  FCancelRequested := False;
  FDownloadThread := nil;
end;

destructor TUpdateDialog.Destroy;
begin
  // REVIEW5-UI-003: Wait for download thread to prevent use-after-free
  WaitForDownloadThread;
  inherited;
end;

procedure TUpdateDialog.WaitForDownloadThread;
begin
  // Wait for download thread to complete with timeout
  if Assigned(FDownloadThread) then
  begin
    // Set cancel flag to signal thread to stop
    FCancelRequested := True;

    // Wait up to 3 seconds for thread to finish
    if FDownloadThread.WaitFor(3000) = wrTimeout then
    begin
      // Thread didn't finish in time, terminate it
      // Note: This is a last resort as termination is not clean
      FDownloadThread.Terminate;
    end;
    FreeAndNil(FDownloadThread);
  end;
end;

procedure TUpdateDialog.btnUpdateClick(Sender: TObject);
begin
  if not FIsDownloading then
    StartDownload;
end;

procedure TUpdateDialog.StartDownload;
var
  SavePath: string;
begin
  FIsDownloading := True;
  FCancelRequested := False;
  btnUpdate.Enabled := False;
  btnCancel.Enabled := not FUpdateInfo.ForceUpdate;
  pbDownload.Visible := True;
  pbDownload.Position := 0;

  SavePath := TPath.Combine(TPath.GetTempPath, 'update_setup.exe');

  // REVIEW5-UI-003: Store thread reference for lifecycle management
  FDownloadThread := TThread.CreateAnonymousThread(procedure
  var
    DownloadSuccess: Boolean;
  begin
    try
      // Check for cancellation before starting download
      if FCancelRequested then
      begin
        TThread.Synchronize(nil, procedure
        begin
          FIsDownloading := False;
          btnUpdate.Enabled := True;
        end);
        Exit;
      end;

      DownloadSuccess := FAutoUpdate.DownloadUpdate(FUpdateInfo, SavePath,
        procedure(const ReadCount, TotalCount: Int64)
        begin
          // Check for cancellation during download
          if FCancelRequested then
            Abort;  // Abort the download

          TThread.Queue(nil, procedure
          begin
            if TotalCount > 0 then
              pbDownload.Position := Round((ReadCount / TotalCount) * 100);
          end);
        end);

      if DownloadSuccess then
      begin
        // Success
        TThread.Synchronize(nil, procedure
        begin
          if MessageDlg('Download complete. Install now?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
          begin
            // Launch installer
            // ShellExecute(0, 'open', PChar(SavePath), nil, nil, SW_SHOWNORMAL);
            // Application.Terminate;
            ShowMessage('Simulated: Installer launched.');
            Close;
          end;
        end);
      end
      else
      begin
        TThread.Synchronize(nil, procedure
        begin
          if not FCancelRequested then
            ShowMessage('Download failed.');
          btnUpdate.Enabled := True;
          FIsDownloading := False;
        end);
      end;
    except
      on E: EAbort do
      begin
        // Download was cancelled
        TThread.Synchronize(nil, procedure
        begin
          btnUpdate.Enabled := True;
          FIsDownloading := False;
          pbDownload.Visible := False;
        end);
      end;
      on E: Exception do
        TThread.Synchronize(nil, procedure
        begin
          if not FCancelRequested then
            ShowMessage('Error: ' + E.Message);
          btnUpdate.Enabled := True;
          FIsDownloading := False;
        end);
    end;
  end);
  FDownloadThread.FreeOnTerminate := False;
  FDownloadThread.Start;
end;

procedure TUpdateDialog.btnCancelClick(Sender: TObject);
begin
  if FIsDownloading and FUpdateInfo.ForceUpdate then
    Exit; // Cannot cancel forced update

  // REVIEW5-UI-003: Signal download thread to stop
  if FIsDownloading then
  begin
    FCancelRequested := True;
    // Don't close immediately - wait for thread to finish
    // The thread will close the dialog when it's done
  end
  else
    Close;
end;

procedure TUpdateDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FIsDownloading and FUpdateInfo.ForceUpdate then
    Action := caNone;
end;

end.
