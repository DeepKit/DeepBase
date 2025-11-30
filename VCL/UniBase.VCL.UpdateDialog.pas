{ ============================================================================
  UniBase.VCL.UpdateDialog - 更新提示对话框
  
  版本: 0.3
  说明: 显示更新信息并执行下载
  ============================================================================ }

unit UniBase.VCL.UpdateDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  UniBase.AutoUpdate, UniBase.VCL.UIHelper;

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
    FAutoUpdate: TUniBaseAutoUpdate;
    FIsDownloading: Boolean;
    
    procedure StartDownload;
  public
    class function Execute(AAutoUpdate: TUniBaseAutoUpdate; const Info: TUpdateInfo): Boolean;
  end;

implementation

uses
  System.IOUtils;

{$R *.dfm}

{ TUpdateDialog }

class function TUpdateDialog.Execute(AAutoUpdate: TUniBaseAutoUpdate; const Info: TUpdateInfo): Boolean;
var
  Dlg: TUpdateDialog;
begin
  Result := False;
  Dlg := TUpdateDialog.Create(nil);
  try
    Dlg.FAutoUpdate := AAutoUpdate;
    Dlg.FUpdateInfo := Info;
    
    Dlg.lblVersion.Caption := Format('Version %s available (Current: %s)', [Info.Version, '1.0.0']); // TODO: Pass current ver
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
  TUniBaseUIHelper.ApplyMicaEffect(Self);
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
  btnUpdate.Enabled := False;
  btnCancel.Enabled := not FUpdateInfo.ForceUpdate;
  pbDownload.Visible := True;
  pbDownload.Position := 0;
  
  SavePath := TPath.Combine(TPath.GetTempPath, 'update_setup.exe');
  
  // Async download
  TThread.CreateAnonymousThread(procedure
  begin
    try
      if FAutoUpdate.DownloadUpdate(FUpdateInfo, SavePath, 
        procedure(const ReadCount, TotalCount: Int64)
        begin
          TThread.Queue(nil, procedure
          begin
            if TotalCount > 0 then
              pbDownload.Position := Round((ReadCount / TotalCount) * 100);
          end);
        end) then
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
          ShowMessage('Download failed.');
          btnUpdate.Enabled := True;
          FIsDownloading := False;
        end);
      end;
    except
      on E: Exception do
        TThread.Synchronize(nil, procedure
        begin
          ShowMessage('Error: ' + E.Message);
          btnUpdate.Enabled := True;
          FIsDownloading := False;
        end);
    end;
  end).Start;
end;

procedure TUpdateDialog.btnCancelClick(Sender: TObject);
begin
  if FIsDownloading and FUpdateInfo.ForceUpdate then
    Exit; // Cannot cancel forced update
    
  Close;
end;

procedure TUpdateDialog.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FIsDownloading and FUpdateInfo.ForceUpdate then
    Action := caNone;
end;

end.
