{ ============================================================================
  DeepBase.VCL.DBInitWizard - 数据库初始化向导
  
  版本: 0.3
  说明: 引导用户配置数据库路径并初始化环境
  ============================================================================ }

unit DeepBase.VCL.DBInitWizard;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.ComCtrls, DeepBase.Manager, DeepBase.VCL.UIHelper;

type
  TDBInitWizard = class(TForm)
    pnlBottom: TPanel;
    btnBack: TButton;
    btnNext: TButton;
    btnCancel: TButton;
    pnlClient: TPanel;
    pcWizard: TPageControl;
    tsWelcome: TTabSheet;
    tsPath: TTabSheet;
    tsFinish: TTabSheet;
    lblWelcomeTitle: TLabel;
    lblWelcomeText: TLabel;
    lblPathTitle: TLabel;
    lblPathInfo: TLabel;
    edtPath: TEdit;
    btnBrowse: TButton;
    radDefault: TRadioButton;
    radCustom: TRadioButton;
    dlgBrowseFolder: TFileOpenDialog;
    lblFinishTitle: TLabel;
    lblFinishText: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure radDefaultClick(Sender: TObject);
    procedure radCustomClick(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
  private
    procedure UpdateButtons;
    function ValidateStep: Boolean;
    function GetDefaultPath: string;
  public
    class function Execute: Boolean;
  end;

implementation

uses
  System.IOUtils;

{$R *.dfm}

{ TDBInitWizard }

class function TDBInitWizard.Execute: Boolean;
var
  Wizard: TDBInitWizard;
  ErrorMsg: string;
  SelectedPath: string;
begin
  Result := False;
  // Check if already initialized
  if DeepBase.Manager.DeepBase.IsInitialized then Exit(True);
  
  Wizard := TDBInitWizard.Create(nil);
  try
    if Wizard.ShowModal = mrOk then
    begin
      // Perform Initialization
      if Wizard.radDefault.Checked then
        SelectedPath := Wizard.GetDefaultPath
      else
        SelectedPath := Wizard.edtPath.Text;
        
      // Force trailing delimiter
      SelectedPath := IncludeTrailingPathDelimiter(SelectedPath);
      
      // Write root.txt if needed or directly init?
      // Manager.InitializeEx relies on finding root.txt or defaults.
      // If we write root.txt, Manager will pick it up.
      
      try
        if Wizard.radCustom.Checked then
        begin
           TFile.WriteAllText(ExtractFilePath(ParamStr(0)) + 'root.txt', SelectedPath);
        end
        else
        begin
           // If default, ensure root.txt points to it or delete it to use fallback
           // Fallback logic in Manager uses AppData/DeepBase automatically.
           if FileExists(ExtractFilePath(ParamStr(0)) + 'root.txt') then
             DeleteFile(ExtractFilePath(ParamStr(0)) + 'root.txt');
        end;
      except
        // Permission error?
      end;
      
      // Re-run init
      Result := DeepBase.Manager.DeepBase.InitializeEx(ErrorMsg);
      
      if not Result then
        MessageDlg('Initialization failed: ' + ErrorMsg, mtError, [mbOK], 0);
    end;
  finally
    Wizard.Free;
  end;
end;

procedure TDBInitWizard.FormCreate(Sender: TObject);
begin
  TDeepBaseUIHelper.ApplyMicaEffect(Self);
  pcWizard.ActivePage := tsWelcome;
  edtPath.Text := GetDefaultPath;
  UpdateButtons;
end;

function TDBInitWizard.GetDefaultPath: string;
begin
  // Similar to Manager's GetAppDataDir logic
  Result := TPath.Combine(TPath.GetHomePath, 'DeepBase');
end;

procedure TDBInitWizard.UpdateButtons;
begin
  btnBack.Enabled := pcWizard.ActivePageIndex > 0;
  
  if pcWizard.ActivePage = tsFinish then
  begin
    btnNext.Caption := 'Finish';
    btnNext.ModalResult := mrOk;
  end
  else
  begin
    btnNext.Caption := 'Next >';
    btnNext.ModalResult := mrNone;
  end;
end;

function TDBInitWizard.ValidateStep: Boolean;

  function IsPathWritable(const APath: string): Boolean;
  var
    LTestFile: string;
    LStream: TFileStream;
  begin
    // GOV-027: probe write access by creating a temporary file in the
    // candidate directory.
    Result := False;
    if not DirectoryExists(APath) then
      Exit;
    LTestFile := IncludeTrailingPathDelimiter(APath) +
      '.dbinit_write_check_' + FormatDateTime('hhnnsszzz', Now) + '.tmp';
    try
      LStream := TFileStream.Create(LTestFile, fmCreate);
      try
        Result := True;
      finally
        LStream.Free;
      end;
    except
      Result := False;
    end;
    if Result and FileExists(LTestFile) then
      DeleteFile(LTestFile);
  end;

var
  LCandidate: string;
begin
  Result := True;
  if pcWizard.ActivePage = tsPath then
  begin
    if radCustom.Checked then
    begin
      if Trim(edtPath.Text) = '' then
      begin
        MessageDlg('Please select a valid path.', mtWarning, [mbOK], 0);
        Exit(False);
      end;
      if not DirectoryExists(edtPath.Text) then
      begin
        if MessageDlg('Directory does not exist. Create it?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        begin
          if not ForceDirectories(edtPath.Text) then
          begin
            MessageDlg('Failed to create directory.', mtError, [mbOK], 0);
            Exit(False);
          end;
        end
        else
          Exit(False);
      end;
      LCandidate := edtPath.Text;
    end
    else
      LCandidate := GetDefaultPath;

    // GOV-027: ensure the chosen path is writable for both default and
    // custom selections so first-run failures surface here.
    if not IsPathWritable(LCandidate) then
    begin
      MessageDlg(Format('Path "%s" is not writable.', [LCandidate]),
        mtError, [mbOK], 0);
      Exit(False);
    end;
  end;
end;

procedure TDBInitWizard.btnNextClick(Sender: TObject);
begin
  if not ValidateStep then Exit;
  
  if pcWizard.ActivePageIndex < pcWizard.PageCount - 1 then
  begin
    pcWizard.SelectNextPage(True);
    UpdateButtons;
  end
  else
  begin
    // Finish handled by ModalResult
  end;
end;

procedure TDBInitWizard.btnBackClick(Sender: TObject);
begin
  if pcWizard.ActivePageIndex > 0 then
  begin
    pcWizard.SelectNextPage(False);
    UpdateButtons;
  end;
end;

procedure TDBInitWizard.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TDBInitWizard.radDefaultClick(Sender: TObject);
begin
  edtPath.Enabled := False;
  btnBrowse.Enabled := False;
end;

procedure TDBInitWizard.radCustomClick(Sender: TObject);
begin
  edtPath.Enabled := True;
  btnBrowse.Enabled := True;
end;

procedure TDBInitWizard.btnBrowseClick(Sender: TObject);
begin
  if dlgBrowseFolder.Execute then
    edtPath.Text := dlgBrowseFolder.FileName;
end;

end.
