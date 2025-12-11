unit UniPublisher.MainForm;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Hash,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Winapi.Messages,
  UniBase.Compression,
  UniBase.Unlock,
  Publisher.Config,
  Publisher.Manifest,
  Publisher.Targets;

const
  DEFAULT_VERSION_JSON_NAME = 'version.json';

const
  UNIPUBLISHER_MRU_FILE = 'UniPublisher.mru.json';
  UNIPUBLISHER_DATA_DIR = 'UniPublisher';

type
  TfrmUniPublisherMain = class(TForm)
  private
    // Config and MRU
    FConfig: TPublishConfig;
    FMRU: TPublishConfigMRU;
    FConfigLoaded: Boolean;

    // Layout
    FMainPanel: TPanel;
    FPageControl: TPageControl;
    tsGeneral: TTabSheet;
    tsGit: TTabSheet;
    tsUnlock: TTabSheet;

    // Project selection controls (new)
    pnlProject: TPanel;
    lblProject: TLabel;
    cmbProjectMRU: TComboBox;
    btnBrowseConfig: TButton;
    btnSaveConfig: TButton;

    // General tab controls
    lblProjectDproj: TLabel;
    edtDprojPath: TEdit;
    btnBrowseDproj: TButton;

    lblCurrentVersion: TLabel;
    edtCurrentVersion: TEdit;
    btnReadVersion: TButton;
    btnWriteVersion: TButton;

    lblSourceDir: TLabel;
    edtSourceDir: TEdit;
    btnBrowseSourceDir: TButton;

    lblOutputDir: TLabel;
    edtOutputDir: TEdit;
    btnBrowseOutputDir: TButton;

    lblPackageName: TLabel;
    edtPackageName: TEdit;
    btnBuildPackage: TButton;

    lblChannel: TLabel;
    cmbChannel: TComboBox;

    lblVersionJson: TLabel;
    edtVersionJsonPath: TEdit;
    btnGenerateJson: TButton;

    lblReleaseNotes: TLabel;
    memReleaseNotes: TMemo;

    // GitHub/Gitee tab controls
    grpGitHub: TGroupBox;
    lblGitHubRepo: TLabel;
    edtGitHubRepo: TEdit;
    lblGitHubTag: TLabel;
    edtGitHubTag: TEdit;
    btnPublishGitHub: TButton;

    grpGitee: TGroupBox;
    lblGiteeRepo: TLabel;
    edtGiteeRepo: TEdit;
    lblGiteeToken: TLabel;
    edtGiteeToken: TEdit;
    lblGiteeTag: TLabel;
    edtGiteeTag: TEdit;
    btnPublishGitee: TButton;

    // Unlock tab controls
    lblProductCode: TLabel;
    edtProductCode: TEdit;
    lblUnlockDate: TLabel;
    dtpUnlockDate: TDateTimePicker;
    lblUnlockLevel: TLabel;
    cmbUnlockLevel: TComboBox;
    btnGenerateUnlock: TButton;
    memUnlockCodes: TMemo;

    // Status bar
    StatusBar: TStatusBar;

    // Publish status & log panel (new)
    pnlPublishStatus: TPanel;
    grpTargetStatus: TGroupBox;
    lblHttpStatus: TLabel;
    shpHttpStatus: TShape;
    lblGitHubStatus: TLabel;
    shpGitHubStatus: TShape;
    lblGiteeStatus: TLabel;
    shpGiteeStatus: TShape;
    btnValidateConfig: TButton;

    // Convenience buttons panel
    pnlQuickActions: TPanel;
    btnReloadConfig: TButton;
    btnOpenOutputDir: TButton;
    btnOpenVersionUrl: TButton;
    btnPublishAll: TButton;

    // Publish log
    grpPublishLog: TGroupBox;
    memPublishLog: TMemo;
    btnClearLog: TButton;

    procedure CreateUI;
    procedure WireEvents;

    // Event handlers
    procedure BtnBrowseDprojClick(Sender: TObject);
    procedure BtnReadVersionClick(Sender: TObject);
    procedure BtnWriteVersionClick(Sender: TObject);
    procedure BtnBrowseSourceDirClick(Sender: TObject);
    procedure BtnBrowseOutputDirClick(Sender: TObject);
    procedure BtnBuildPackageClick(Sender: TObject);
    procedure BtnGenerateJsonClick(Sender: TObject);
    procedure BtnPublishGitHubClick(Sender: TObject);
    procedure BtnPublishGiteeClick(Sender: TObject);
    procedure BtnGenerateUnlockClick(Sender: TObject);
    procedure CmbProjectMRUChange(Sender: TObject);
    procedure BtnBrowseConfigClick(Sender: TObject);
    procedure BtnSaveConfigClick(Sender: TObject);
    procedure BtnValidateConfigClick(Sender: TObject);
    procedure BtnReloadConfigClick(Sender: TObject);
    procedure BtnOpenOutputDirClick(Sender: TObject);
    procedure BtnOpenVersionUrlClick(Sender: TObject);
    procedure BtnPublishAllClick(Sender: TObject);
    procedure BtnClearLogClick(Sender: TObject);

    // Helpers
    procedure SetStatus(const Msg: string; IsError: Boolean = False);
    function Confirm(const Msg: string): Boolean;
    procedure AppendLog(const Msg: string);
    procedure UpdateTargetStatusUI;

    // Config helpers
    function GetMRUStoragePath: string;
    procedure LoadConfigFromFile(const APath: string);
    procedure SaveConfigToFile(const APath: string);
    procedure ConfigToUI;
    procedure UIToConfig;
    procedure RefreshMRUComboBox;
    procedure LoadLastProject;

    function ReadDprojVersion(const DprojPath: string; out Version: string): Boolean;
    function WriteDprojVersion(const DprojPath, Version: string): Boolean;

    function BuildPackage(const SourceDir, OutputDir, PackageName: string;
      out PackagePath: string; out FileSize: Int64; out Sha256: string): Boolean;

    function GenerateVersionJson(const JsonPath, Channel, Version,
      DownloadUrl: string; FileSize: Int64; const Sha256, ReleaseNotes: string): Boolean;

    function ComputeFileSha256(const FileName: string): string;

    function GetSelectedChannelKey: string;

    function RunShellCommand(const ExeName, Params, WorkDir: string): Boolean;
    function PublishToGitHub(const Repo, Tag, PackagePath, ReleaseNotes: string): Boolean;
    function PublishToGitee(const Repo, Tag, Token, PackagePath, ReleaseNotes: string): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmUniPublisherMain: TfrmUniPublisherMain;

implementation

{$R *.res}

{ TfrmUniPublisherMain }

constructor TfrmUniPublisherMain.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'UniPublisher - 通用发布工具';
  Width := 900;
  Height := 750;
  Position := poScreenCenter;

  FConfig := TPublishConfig.Create;
  FMRU := TPublishConfigMRU.Create(GetMRUStoragePath, 10);
  FConfigLoaded := False;

  CreateUI;
  WireEvents;

  // Defaults
  cmbChannel.ItemIndex := 0; // stable
  cmbUnlockLevel.ItemIndex := 0; // Free
  dtpUnlockDate.Date := Date;

  // Load MRU and last project
  RefreshMRUComboBox;
  LoadLastProject;
  UpdateTargetStatusUI;

  SetStatus('就绪');
end;

destructor TfrmUniPublisherMain.Destroy;
begin
  FMRU.Free;
  FConfig.Free;
  inherited;
end;

function TfrmUniPublisherMain.GetMRUStoragePath: string;
var
  DataDir: string;
begin
  DataDir := TPath.Combine(TPath.GetHomePath, UNIPUBLISHER_DATA_DIR);
  ForceDirectories(DataDir);
  Result := TPath.Combine(DataDir, UNIPUBLISHER_MRU_FILE);
end;

procedure TfrmUniPublisherMain.RefreshMRUComboBox;
var
  Items: TArray<string>;
  S: string;
begin
  cmbProjectMRU.Items.Clear;
  Items := FMRU.GetItems;
  for S in Items do
    cmbProjectMRU.Items.Add(S);
  if cmbProjectMRU.Items.Count > 0 then
    cmbProjectMRU.ItemIndex := 0;
end;

procedure TfrmUniPublisherMain.LoadLastProject;
var
  LastPath: string;
begin
  LastPath := FMRU.GetMostRecent;
  if (LastPath <> '') and TFile.Exists(LastPath) then
    LoadConfigFromFile(LastPath);
end;

procedure TfrmUniPublisherMain.LoadConfigFromFile(const APath: string);
begin
  if not TFile.Exists(APath) then
  begin
    SetStatus('配置文件不存在: ' + APath, True);
    Exit;
  end;

  if FConfig.LoadFromFile(APath) then
  begin
    FConfigLoaded := True;
    FMRU.Add(APath);
    RefreshMRUComboBox;
    ConfigToUI;
    UpdateTargetStatusUI;
    SetStatus('已加载配置: ' + ExtractFileName(APath));
  end
  else
    SetStatus('加载配置失败: ' + APath, True);
end;

procedure TfrmUniPublisherMain.SaveConfigToFile(const APath: string);
begin
  UIToConfig;
  if FConfig.SaveToFile(APath) then
  begin
    FConfigLoaded := True;
    FMRU.Add(APath);
    RefreshMRUComboBox;
    SetStatus('已保存配置: ' + ExtractFileName(APath));
  end
  else
    SetStatus('保存配置失败: ' + APath, True);
end;

procedure TfrmUniPublisherMain.ConfigToUI;
begin
  // Basic info
  edtDprojPath.Text := FConfig.Dproj;
  edtSourceDir.Text := FConfig.OutputDir;  // OutputDir is actually the build dir
  edtOutputDir.Text := ExtractFilePath(FConfig.OutputDir); // Package output goes here

  // GitHub
  if FConfig.PublishTargets.GitHub.Enabled then
  begin
    edtGitHubRepo.Text := FConfig.PublishTargets.GitHub.GetRepoSlug;
  end;

  // Gitee
  if FConfig.PublishTargets.Gitee.Enabled then
  begin
    edtGiteeRepo.Text := FConfig.PublishTargets.Gitee.GetRepoSlug;
    // Token is not loaded from config for security
  end;

  // Update package name based on config
  if FConfig.AppName <> '' then
  begin
    edtPackageName.Text := FConfig.GetDefaultPackageName(edtCurrentVersion.Text);
  end;
end;

procedure TfrmUniPublisherMain.UIToConfig;
var
  Parts: TArray<string>;
begin
  FConfig.Dproj := edtDprojPath.Text;
  FConfig.OutputDir := edtSourceDir.Text;

  // Parse GitHub repo
  if edtGitHubRepo.Text <> '' then
  begin
    Parts := edtGitHubRepo.Text.Split(['/']);
    if Length(Parts) >= 2 then
    begin
      FConfig.PublishTargets.GitHub.Owner := Parts[0];
      FConfig.PublishTargets.GitHub.Repo := Parts[1];
      FConfig.PublishTargets.GitHub.Enabled := True;
    end;
  end;

  // Parse Gitee repo
  if edtGiteeRepo.Text <> '' then
  begin
    Parts := edtGiteeRepo.Text.Split(['/']);
    if Length(Parts) >= 2 then
    begin
      FConfig.PublishTargets.Gitee.Owner := Parts[0];
      FConfig.PublishTargets.Gitee.Repo := Parts[1];
      FConfig.PublishTargets.Gitee.Enabled := edtGiteeToken.Text <> '';
    end;
  end;
end;

procedure TfrmUniPublisherMain.CreateUI;
begin
  FMainPanel := TPanel.Create(Self);
  FMainPanel.Parent := Self;
  FMainPanel.Align := alClient;
  FMainPanel.BevelOuter := bvNone;

  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.Align := alBottom;

  // Project selection panel (top)
  pnlProject := TPanel.Create(Self);
  pnlProject.Parent := FMainPanel;
  pnlProject.Align := alTop;
  pnlProject.Height := 44;
  pnlProject.BevelOuter := bvNone;

  lblProject := TLabel.Create(Self);
  lblProject.Parent := pnlProject;
  lblProject.Left := 16;
  lblProject.Top := 14;
  lblProject.Caption := '项目配置:';

  cmbProjectMRU := TComboBox.Create(Self);
  cmbProjectMRU.Parent := pnlProject;
  cmbProjectMRU.Left := 90;
  cmbProjectMRU.Top := 10;
  cmbProjectMRU.Width := 550;
  cmbProjectMRU.Style := csDropDownList;

  btnBrowseConfig := TButton.Create(Self);
  btnBrowseConfig.Parent := pnlProject;
  btnBrowseConfig.Left := 650;
  btnBrowseConfig.Top := 8;
  btnBrowseConfig.Width := 80;
  btnBrowseConfig.Caption := '浏览...';

  btnSaveConfig := TButton.Create(Self);
  btnSaveConfig.Parent := pnlProject;
  btnSaveConfig.Left := 740;
  btnSaveConfig.Top := 8;
  btnSaveConfig.Width := 100;
  btnSaveConfig.Caption := '保存配置';

  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := FMainPanel;
  FPageControl.Align := alClient;

  tsGeneral := TTabSheet.Create(Self);
  tsGeneral.PageControl := FPageControl;
  tsGeneral.Caption := '版本 && 打包';

  tsGit := TTabSheet.Create(Self);
  tsGit.PageControl := FPageControl;
  tsGit.Caption := 'GitHub / Gitee';

  tsUnlock := TTabSheet.Create(Self);
  tsUnlock.PageControl := FPageControl;
  tsUnlock.Caption := '解锁码生成';

  // General tab layout
  lblProjectDproj := TLabel.Create(Self);
  lblProjectDproj.Parent := tsGeneral;
  lblProjectDproj.Left := 16;
  lblProjectDproj.Top := 16;
  lblProjectDproj.Caption := '.dproj 路径:';

  edtDprojPath := TEdit.Create(Self);
  edtDprojPath.Parent := tsGeneral;
  edtDprojPath.Left := 120;
  edtDprojPath.Top := 12;
  edtDprojPath.Width := 520;

  btnBrowseDproj := TButton.Create(Self);
  btnBrowseDproj.Parent := tsGeneral;
  btnBrowseDproj.Left := 650;
  btnBrowseDproj.Top := 10;
  btnBrowseDproj.Width := 80;
  btnBrowseDproj.Caption := '浏览...';

  lblCurrentVersion := TLabel.Create(Self);
  lblCurrentVersion.Parent := tsGeneral;
  lblCurrentVersion.Left := 16;
  lblCurrentVersion.Top := 52;
  lblCurrentVersion.Caption := '版本号 (x.y.z):';

  edtCurrentVersion := TEdit.Create(Self);
  edtCurrentVersion.Parent := tsGeneral;
  edtCurrentVersion.Left := 120;
  edtCurrentVersion.Top := 48;
  edtCurrentVersion.Width := 150;

  btnReadVersion := TButton.Create(Self);
  btnReadVersion.Parent := tsGeneral;
  btnReadVersion.Left := 280;
  btnReadVersion.Top := 46;
  btnReadVersion.Width := 80;
  btnReadVersion.Caption := '读取';

  btnWriteVersion := TButton.Create(Self);
  btnWriteVersion.Parent := tsGeneral;
  btnWriteVersion.Left := 370;
  btnWriteVersion.Top := 46;
  btnWriteVersion.Width := 80;
  btnWriteVersion.Caption := '写入';

  lblSourceDir := TLabel.Create(Self);
  lblSourceDir.Parent := tsGeneral;
  lblSourceDir.Left := 16;
  lblSourceDir.Top := 92;
  lblSourceDir.Caption := '构建目录:';

  edtSourceDir := TEdit.Create(Self);
  edtSourceDir.Parent := tsGeneral;
  edtSourceDir.Left := 120;
  edtSourceDir.Top := 88;
  edtSourceDir.Width := 520;

  btnBrowseSourceDir := TButton.Create(Self);
  btnBrowseSourceDir.Parent := tsGeneral;
  btnBrowseSourceDir.Left := 650;
  btnBrowseSourceDir.Top := 86;
  btnBrowseSourceDir.Width := 80;
  btnBrowseSourceDir.Caption := '浏览...';

  lblOutputDir := TLabel.Create(Self);
  lblOutputDir.Parent := tsGeneral;
  lblOutputDir.Left := 16;
  lblOutputDir.Top := 132;
  lblOutputDir.Caption := '输出目录:';

  edtOutputDir := TEdit.Create(Self);
  edtOutputDir.Parent := tsGeneral;
  edtOutputDir.Left := 120;
  edtOutputDir.Top := 128;
  edtOutputDir.Width := 520;

  btnBrowseOutputDir := TButton.Create(Self);
  btnBrowseOutputDir.Parent := tsGeneral;
  btnBrowseOutputDir.Left := 650;
  btnBrowseOutputDir.Top := 126;
  btnBrowseOutputDir.Width := 80;
  btnBrowseOutputDir.Caption := '浏览...';

  lblPackageName := TLabel.Create(Self);
  lblPackageName.Parent := tsGeneral;
  lblPackageName.Left := 16;
  lblPackageName.Top := 172;
  lblPackageName.Caption := '包文件名 (.zip):';

  edtPackageName := TEdit.Create(Self);
  edtPackageName.Parent := tsGeneral;
  edtPackageName.Left := 120;
  edtPackageName.Top := 168;
  edtPackageName.Width := 260;
  edtPackageName.Text := 'myapp-1.0.0.zip';

  btnBuildPackage := TButton.Create(Self);
  btnBuildPackage.Parent := tsGeneral;
  btnBuildPackage.Left := 390;
  btnBuildPackage.Top := 166;
  btnBuildPackage.Width := 120;
  btnBuildPackage.Caption := '打包 ZIP';

  lblChannel := TLabel.Create(Self);
  lblChannel.Parent := tsGeneral;
  lblChannel.Left := 16;
  lblChannel.Top := 212;
  lblChannel.Caption := '发布通道:';

  cmbChannel := TComboBox.Create(Self);
  cmbChannel.Parent := tsGeneral;
  cmbChannel.Left := 120;
  cmbChannel.Top := 208;
  cmbChannel.Width := 150;
  cmbChannel.Style := csDropDownList;
  cmbChannel.Items.Add('stable');
  cmbChannel.Items.Add('beta');
  cmbChannel.Items.Add('dev');

  lblVersionJson := TLabel.Create(Self);
  lblVersionJson.Parent := tsGeneral;
  lblVersionJson.Left := 16;
  lblVersionJson.Top := 252;
  lblVersionJson.Caption := 'version.json 路径:';

  edtVersionJsonPath := TEdit.Create(Self);
  edtVersionJsonPath.Parent := tsGeneral;
  edtVersionJsonPath.Left := 120;
  edtVersionJsonPath.Top := 248;
  edtVersionJsonPath.Width := 520;

  btnGenerateJson := TButton.Create(Self);
  btnGenerateJson.Parent := tsGeneral;
  btnGenerateJson.Left := 650;
  btnGenerateJson.Top := 246;
  btnGenerateJson.Width := 100;
  btnGenerateJson.Caption := '生成 JSON';

  lblReleaseNotes := TLabel.Create(Self);
  lblReleaseNotes.Parent := tsGeneral;
  lblReleaseNotes.Left := 16;
  lblReleaseNotes.Top := 292;
  lblReleaseNotes.Caption := '更新说明:';

  memReleaseNotes := TMemo.Create(Self);
  memReleaseNotes.Parent := tsGeneral;
  memReleaseNotes.Left := 16;
  memReleaseNotes.Top := 312;
  memReleaseNotes.Width := 760;
  memReleaseNotes.Height := 260;
  memReleaseNotes.ScrollBars := ssVertical;
  memReleaseNotes.Font.Name := 'Consolas';
  memReleaseNotes.Font.Size := 10;

  // Git tab
  grpGitHub := TGroupBox.Create(Self);
  grpGitHub.Parent := tsGit;
  grpGitHub.Left := 16;
  grpGitHub.Top := 16;
  grpGitHub.Width := 380;
  grpGitHub.Height := 180;
  grpGitHub.Caption := 'GitHub Release (gh CLI)';

  lblGitHubRepo := TLabel.Create(Self);
  lblGitHubRepo.Parent := grpGitHub;
  lblGitHubRepo.Left := 16;
  lblGitHubRepo.Top := 32;
  lblGitHubRepo.Caption := '仓库 (owner/repo):';

  edtGitHubRepo := TEdit.Create(Self);
  edtGitHubRepo.Parent := grpGitHub;
  edtGitHubRepo.Left := 140;
  edtGitHubRepo.Top := 28;
  edtGitHubRepo.Width := 200;

  lblGitHubTag := TLabel.Create(Self);
  lblGitHubTag.Parent := grpGitHub;
  lblGitHubTag.Left := 16;
  lblGitHubTag.Top := 68;
  lblGitHubTag.Caption := 'Tag 名称:';

  edtGitHubTag := TEdit.Create(Self);
  edtGitHubTag.Parent := grpGitHub;
  edtGitHubTag.Left := 140;
  edtGitHubTag.Top := 64;
  edtGitHubTag.Width := 200;

  btnPublishGitHub := TButton.Create(Self);
  btnPublishGitHub.Parent := grpGitHub;
  btnPublishGitHub.Left := 140;
  btnPublishGitHub.Top := 108;
  btnPublishGitHub.Width := 120;
  btnPublishGitHub.Caption := '发布到 GitHub';

  grpGitee := TGroupBox.Create(Self);
  grpGitee.Parent := tsGit;
  grpGitee.Left := 420;
  grpGitee.Top := 16;
  grpGitee.Width := 380;
  grpGitee.Height := 220;
  grpGitee.Caption := 'Gitee Release (API)';

  lblGiteeRepo := TLabel.Create(Self);
  lblGiteeRepo.Parent := grpGitee;
  lblGiteeRepo.Left := 16;
  lblGiteeRepo.Top := 32;
  lblGiteeRepo.Caption := '仓库 (owner/repo):';

  edtGiteeRepo := TEdit.Create(Self);
  edtGiteeRepo.Parent := grpGitee;
  edtGiteeRepo.Left := 140;
  edtGiteeRepo.Top := 28;
  edtGiteeRepo.Width := 200;

  lblGiteeToken := TLabel.Create(Self);
  lblGiteeToken.Parent := grpGitee;
  lblGiteeToken.Left := 16;
  lblGiteeToken.Top := 68;
  lblGiteeToken.Caption := '访问 Token:';

  edtGiteeToken := TEdit.Create(Self);
  edtGiteeToken.Parent := grpGitee;
  edtGiteeToken.Left := 140;
  edtGiteeToken.Top := 64;
  edtGiteeToken.Width := 200;
  edtGiteeToken.PasswordChar := '*';

  lblGiteeTag := TLabel.Create(Self);
  lblGiteeTag.Parent := grpGitee;
  lblGiteeTag.Left := 16;
  lblGiteeTag.Top := 104;
  lblGiteeTag.Caption := 'Tag 名称:';

  edtGiteeTag := TEdit.Create(Self);
  edtGiteeTag.Parent := grpGitee;
  edtGiteeTag.Left := 140;
  edtGiteeTag.Top := 100;
  edtGiteeTag.Width := 200;

  btnPublishGitee := TButton.Create(Self);
  btnPublishGitee.Parent := grpGitee;
  btnPublishGitee.Left := 140;
  btnPublishGitee.Top := 144;
  btnPublishGitee.Width := 150;
  btnPublishGitee.Caption := '发布到 Gitee';

  // Unlock tab
  lblProductCode := TLabel.Create(Self);
  lblProductCode.Parent := tsUnlock;
  lblProductCode.Left := 16;
  lblProductCode.Top := 24;
  lblProductCode.Caption := '产品代码 (如 TK):';

  edtProductCode := TEdit.Create(Self);
  edtProductCode.Parent := tsUnlock;
  edtProductCode.Left := 160;
  edtProductCode.Top := 20;
  edtProductCode.Width := 120;

  lblUnlockDate := TLabel.Create(Self);
  lblUnlockDate.Parent := tsUnlock;
  lblUnlockDate.Left := 16;
  lblUnlockDate.Top := 64;
  lblUnlockDate.Caption := '有效年月:';

  dtpUnlockDate := TDateTimePicker.Create(Self);
  dtpUnlockDate.Parent := tsUnlock;
  dtpUnlockDate.Left := 160;
  dtpUnlockDate.Top := 60;
  dtpUnlockDate.Width := 150;
  dtpUnlockDate.Kind := dtkDate;

  lblUnlockLevel := TLabel.Create(Self);
  lblUnlockLevel.Parent := tsUnlock;
  lblUnlockLevel.Left := 16;
  lblUnlockLevel.Top := 104;
  lblUnlockLevel.Caption := '解锁级别:';

  cmbUnlockLevel := TComboBox.Create(Self);
  cmbUnlockLevel.Parent := tsUnlock;
  cmbUnlockLevel.Left := 160;
  cmbUnlockLevel.Top := 100;
  cmbUnlockLevel.Width := 150;
  cmbUnlockLevel.Style := csDropDownList;
  cmbUnlockLevel.Items.Add('Free (默认)');
  cmbUnlockLevel.Items.Add('Follow (关注)');
  cmbUnlockLevel.Items.Add('Share (分享)');

  btnGenerateUnlock := TButton.Create(Self);
  btnGenerateUnlock.Parent := tsUnlock;
  btnGenerateUnlock.Left := 160;
  btnGenerateUnlock.Top := 140;
  btnGenerateUnlock.Width := 150;
  btnGenerateUnlock.Caption := '生成解锁码';

  memUnlockCodes := TMemo.Create(Self);
  memUnlockCodes.Parent := tsUnlock;
  memUnlockCodes.Left := 16;
  memUnlockCodes.Top := 190;
  memUnlockCodes.Width := 760;
  memUnlockCodes.Height := 360;
  memUnlockCodes.ScrollBars := ssVertical;
  memUnlockCodes.Font.Name := 'Consolas';
  memUnlockCodes.Font.Size := 10;

  // ---------- Publish status & log panel (bottom right) ----------
  pnlPublishStatus := TPanel.Create(Self);
  pnlPublishStatus.Parent := FMainPanel;
  pnlPublishStatus.Align := alRight;
  pnlPublishStatus.Width := 280;
  pnlPublishStatus.BevelOuter := bvNone;

  // Target status group
  grpTargetStatus := TGroupBox.Create(Self);
  grpTargetStatus.Parent := pnlPublishStatus;
  grpTargetStatus.Align := alTop;
  grpTargetStatus.Height := 130;
  grpTargetStatus.Caption := '发布目标状态';

  // HTTP status
  shpHttpStatus := TShape.Create(Self);
  shpHttpStatus.Parent := grpTargetStatus;
  shpHttpStatus.Left := 16;
  shpHttpStatus.Top := 28;
  shpHttpStatus.Width := 16;
  shpHttpStatus.Height := 16;
  shpHttpStatus.Shape := stCircle;
  shpHttpStatus.Brush.Color := clGray;

  lblHttpStatus := TLabel.Create(Self);
  lblHttpStatus.Parent := grpTargetStatus;
  lblHttpStatus.Left := 40;
  lblHttpStatus.Top := 28;
  lblHttpStatus.Caption := 'HTTP: 未配置';

  // GitHub status
  shpGitHubStatus := TShape.Create(Self);
  shpGitHubStatus.Parent := grpTargetStatus;
  shpGitHubStatus.Left := 16;
  shpGitHubStatus.Top := 52;
  shpGitHubStatus.Width := 16;
  shpGitHubStatus.Height := 16;
  shpGitHubStatus.Shape := stCircle;
  shpGitHubStatus.Brush.Color := clGray;

  lblGitHubStatus := TLabel.Create(Self);
  lblGitHubStatus.Parent := grpTargetStatus;
  lblGitHubStatus.Left := 40;
  lblGitHubStatus.Top := 52;
  lblGitHubStatus.Caption := 'GitHub: 未配置';

  // Gitee status
  shpGiteeStatus := TShape.Create(Self);
  shpGiteeStatus.Parent := grpTargetStatus;
  shpGiteeStatus.Left := 16;
  shpGiteeStatus.Top := 76;
  shpGiteeStatus.Width := 16;
  shpGiteeStatus.Height := 16;
  shpGiteeStatus.Shape := stCircle;
  shpGiteeStatus.Brush.Color := clGray;

  lblGiteeStatus := TLabel.Create(Self);
  lblGiteeStatus.Parent := grpTargetStatus;
  lblGiteeStatus.Left := 40;
  lblGiteeStatus.Top := 76;
  lblGiteeStatus.Caption := 'Gitee: 未配置';

  btnValidateConfig := TButton.Create(Self);
  btnValidateConfig.Parent := grpTargetStatus;
  btnValidateConfig.Left := 140;
  btnValidateConfig.Top := 96;
  btnValidateConfig.Width := 120;
  btnValidateConfig.Caption := '验证配置';

  // Quick actions panel
  pnlQuickActions := TPanel.Create(Self);
  pnlQuickActions.Parent := pnlPublishStatus;
  pnlQuickActions.Align := alTop;
  pnlQuickActions.Height := 100;
  pnlQuickActions.BevelOuter := bvNone;

  btnReloadConfig := TButton.Create(Self);
  btnReloadConfig.Parent := pnlQuickActions;
  btnReloadConfig.Left := 16;
  btnReloadConfig.Top := 8;
  btnReloadConfig.Width := 120;
  btnReloadConfig.Caption := '重新加载配置';

  btnOpenOutputDir := TButton.Create(Self);
  btnOpenOutputDir.Parent := pnlQuickActions;
  btnOpenOutputDir.Left := 144;
  btnOpenOutputDir.Top := 8;
  btnOpenOutputDir.Width := 120;
  btnOpenOutputDir.Caption := '打开输出目录';

  btnOpenVersionUrl := TButton.Create(Self);
  btnOpenVersionUrl.Parent := pnlQuickActions;
  btnOpenVersionUrl.Left := 16;
  btnOpenVersionUrl.Top := 40;
  btnOpenVersionUrl.Width := 120;
  btnOpenVersionUrl.Caption := '打开 version URL';

  btnPublishAll := TButton.Create(Self);
  btnPublishAll.Parent := pnlQuickActions;
  btnPublishAll.Left := 144;
  btnPublishAll.Top := 40;
  btnPublishAll.Width := 120;
  btnPublishAll.Height := 40;
  btnPublishAll.Caption := '一键发布';
  btnPublishAll.Font.Style := [fsBold];

  // Publish log
  grpPublishLog := TGroupBox.Create(Self);
  grpPublishLog.Parent := pnlPublishStatus;
  grpPublishLog.Align := alClient;
  grpPublishLog.Caption := '发布日志';

  memPublishLog := TMemo.Create(Self);
  memPublishLog.Parent := grpPublishLog;
  memPublishLog.Align := alClient;
  memPublishLog.ReadOnly := True;
  memPublishLog.ScrollBars := ssBoth;
  memPublishLog.Font.Name := 'Consolas';
  memPublishLog.Font.Size := 9;

  btnClearLog := TButton.Create(Self);
  btnClearLog.Parent := grpPublishLog;
  btnClearLog.Align := alBottom;
  btnClearLog.Caption := '清除日志';
end;

procedure TfrmUniPublisherMain.WireEvents;
begin
  // Project controls
  cmbProjectMRU.OnChange := CmbProjectMRUChange;
  btnBrowseConfig.OnClick := BtnBrowseConfigClick;
  btnSaveConfig.OnClick := BtnSaveConfigClick;

  // General tab
  btnBrowseDproj.OnClick := BtnBrowseDprojClick;
  btnReadVersion.OnClick := BtnReadVersionClick;
  btnWriteVersion.OnClick := BtnWriteVersionClick;
  btnBrowseSourceDir.OnClick := BtnBrowseSourceDirClick;
  btnBrowseOutputDir.OnClick := BtnBrowseOutputDirClick;
  btnBuildPackage.OnClick := BtnBuildPackageClick;
  btnGenerateJson.OnClick := BtnGenerateJsonClick;
  btnPublishGitHub.OnClick := BtnPublishGitHubClick;
  btnPublishGitee.OnClick := BtnPublishGiteeClick;
  btnGenerateUnlock.OnClick := BtnGenerateUnlockClick;

  // New controls
  btnValidateConfig.OnClick := BtnValidateConfigClick;
  btnReloadConfig.OnClick := BtnReloadConfigClick;
  btnOpenOutputDir.OnClick := BtnOpenOutputDirClick;
  btnOpenVersionUrl.OnClick := BtnOpenVersionUrlClick;
  btnPublishAll.OnClick := BtnPublishAllClick;
  btnClearLog.OnClick := BtnClearLogClick;
end;

procedure TfrmUniPublisherMain.CmbProjectMRUChange(Sender: TObject);
var
  SelectedPath: string;
begin
  if cmbProjectMRU.ItemIndex >= 0 then
  begin
    SelectedPath := cmbProjectMRU.Items[cmbProjectMRU.ItemIndex];
    if (SelectedPath <> '') and TFile.Exists(SelectedPath) then
      LoadConfigFromFile(SelectedPath)
    else
      SetStatus('配置文件不存在: ' + SelectedPath, True);
  end;
end;

procedure TfrmUniPublisherMain.BtnBrowseConfigClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Publish Config (*.publish.json)|*.publish.json|All files (*.*)|*.*';
    D.DefaultExt := 'publish.json';
    if D.Execute then
      LoadConfigFromFile(D.FileName);
  finally
    D.Free;
  end;
end;

procedure TfrmUniPublisherMain.BtnSaveConfigClick(Sender: TObject);
var
  D: TSaveDialog;
  DefaultName: string;
begin
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Publish Config (*.publish.json)|*.publish.json|All files (*.*)|*.*';
    D.DefaultExt := 'publish.json';

    // Suggest name based on dproj
    if edtDprojPath.Text <> '' then
    begin
      DefaultName := ChangeFileExt(ExtractFileName(edtDprojPath.Text), '.publish.json');
      D.FileName := DefaultName;
      D.InitialDir := ExtractFilePath(edtDprojPath.Text);
    end;

    if D.Execute then
    begin
      // Auto-fill appName if empty
      if FConfig.AppName = '' then
        FConfig.AppName := ChangeFileExt(ExtractFileName(edtDprojPath.Text), '');
      if FConfig.AppId = '' then
        FConfig.AppId := 'com.example.' + LowerCase(FConfig.AppName);

      SaveConfigToFile(D.FileName);
    end;
  finally
    D.Free;
  end;
end;

procedure TfrmUniPublisherMain.SetStatus(const Msg: string; IsError: Boolean);
begin
  StatusBar.SimpleText := Msg;
  if IsError then
    StatusBar.Font.Color := clRed
  else
    StatusBar.Font.Color := clWindowText;
end;

procedure TfrmUniPublisherMain.AppendLog(const Msg: string);
begin
  memPublishLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' ' + Msg);
  // Scroll to bottom
  SendMessage(memPublishLog.Handle, EM_SCROLLCARET, 0, 0);
end;

procedure TfrmUniPublisherMain.UpdateTargetStatusUI;

  procedure SetStatusIndicator(Shape: TShape; Lbl: TLabel; 
    const TargetName: string; Enabled, Valid: Boolean);
  begin
    if not Enabled then
    begin
      Shape.Brush.Color := clGray;
      Lbl.Caption := TargetName + ': 未启用';
    end
    else if Valid then
    begin
      Shape.Brush.Color := clLime;
      Lbl.Caption := TargetName + ': 就绪';
    end
    else
    begin
      Shape.Brush.Color := clYellow;
      Lbl.Caption := TargetName + ': 配置不完整';
    end;
  end;

var
  HttpValid, GitHubValid, GiteeValid: Boolean;
  V: TValidationResult;
begin
  // Validate each target
  V := TTargetValidator.ValidateHttp(FConfig);
  HttpValid := V.IsValid;
  
  V := TTargetValidator.ValidateGitHub(FConfig);
  GitHubValid := V.IsValid;
  
  V := TTargetValidator.ValidateGitee(FConfig);
  GiteeValid := V.IsValid;

  SetStatusIndicator(shpHttpStatus, lblHttpStatus, 'HTTP', 
    FConfig.PublishTargets.Http.Enabled, HttpValid);
  SetStatusIndicator(shpGitHubStatus, lblGitHubStatus, 'GitHub', 
    FConfig.PublishTargets.GitHub.Enabled, GitHubValid);
  SetStatusIndicator(shpGiteeStatus, lblGiteeStatus, 'Gitee', 
    FConfig.PublishTargets.Gitee.Enabled, GiteeValid);
end;

procedure TfrmUniPublisherMain.BtnValidateConfigClick(Sender: TObject);
var
  V: TValidationResult;
begin
  UIToConfig;
  V := TTargetValidator.ValidateAll(FConfig);
  UpdateTargetStatusUI;
  
  AppendLog('=== 配置验证 ===');
  AppendLog(V.GetSummary);
  
  if V.IsValid then
    SetStatus('配置验证通过')
  else
    SetStatus('配置验证失败，请检查日志', True);
end;

procedure TfrmUniPublisherMain.BtnReloadConfigClick(Sender: TObject);
var
  CurrentPath: string;
begin
  if cmbProjectMRU.ItemIndex >= 0 then
  begin
    CurrentPath := cmbProjectMRU.Items[cmbProjectMRU.ItemIndex];
    if TFile.Exists(CurrentPath) then
    begin
      LoadConfigFromFile(CurrentPath);
      UpdateTargetStatusUI;
      AppendLog('已重新加载配置: ' + ExtractFileName(CurrentPath));
    end
    else
      SetStatus('配置文件不存在', True);
  end
  else
    SetStatus('请先选择一个配置文件', True);
end;

procedure TfrmUniPublisherMain.BtnOpenOutputDirClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := Trim(edtOutputDir.Text);
  if Dir = '' then
    Dir := FConfig.OutputDir;
    
  if (Dir <> '') and TDirectory.Exists(Dir) then
  begin
    ShellExecute(Handle, 'open', PChar(Dir), nil, nil, SW_SHOWNORMAL);
    AppendLog('已打开输出目录: ' + Dir);
  end
  else
    SetStatus('输出目录不存在: ' + Dir, True);
end;

procedure TfrmUniPublisherMain.BtnOpenVersionUrlClick(Sender: TObject);
var
  Url: string;
begin
  // Try HTTP version.json path first
  Url := FConfig.PublishTargets.Http.VersionJsonPath;
  
  if Url = '' then
  begin
    // Fallback to local file
    Url := Trim(edtVersionJsonPath.Text);
    if TFile.Exists(Url) then
    begin
      ShellExecute(Handle, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
      AppendLog('已打开本地 version.json: ' + Url);
      Exit;
    end;
  end;
  
  if Url <> '' then
  begin
    ShellExecute(Handle, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
    AppendLog('已打开 version.json URL: ' + Url);
  end
  else
    SetStatus('未配置 version.json URL', True);
end;

procedure TfrmUniPublisherMain.BtnPublishAllClick(Sender: TObject);
var
  Publisher: TUnifiedPublisher;
  Results: TPublishResults;
  PackagePath, VersionJsonPath, Tag, Notes: string;
  V: TValidationResult;
begin
  UIToConfig;
  
  // Validate first
  V := TTargetValidator.ValidateAll(FConfig);
  if not V.IsValid then
  begin
    AppendLog('=== 配置验证失败，无法发布 ===');
    AppendLog(V.GetSummary);
    SetStatus('配置验证失败', True);
    Exit;
  end;
  
  // Gather params
  PackagePath := TPath.Combine(edtOutputDir.Text, edtPackageName.Text);
  VersionJsonPath := edtVersionJsonPath.Text;
  Tag := 'v' + Trim(edtCurrentVersion.Text);
  Notes := memReleaseNotes.Text;
  
  if not TFile.Exists(PackagePath) then
  begin
    SetStatus('包文件不存在: ' + PackagePath, True);
    Exit;
  end;
  
  if not Confirm(Format('发布 %s 到所有启用的目标?', [Tag])) then
    Exit;
  
  // Publish
  Publisher := TUnifiedPublisher.Create(FConfig);
  try
    Publisher.OnLog := AppendLog;
    Publisher.OnProgress := 
      procedure(const TargetName: string; Progress: Integer; const StatusText: string)
      begin
        SetStatus(Format('[%s] %d%% - %s', [TargetName, Progress, StatusText]));
        Application.ProcessMessages;
      end;
    
    Results := Publisher.PublishAll(PackagePath, VersionJsonPath, Tag, Notes);
    
    // Update status UI
    if Results.Http.Status = psSuccess then
      shpHttpStatus.Brush.Color := clGreen;
    if Results.GitHub.Status = psSuccess then
      shpGitHubStatus.Brush.Color := clGreen;
    if Results.Gitee.Status = psSuccess then
      shpGiteeStatus.Brush.Color := clGreen;
      
    if Results.Http.Status = psFailed then
      shpHttpStatus.Brush.Color := clRed;
    if Results.GitHub.Status = psFailed then
      shpGitHubStatus.Brush.Color := clRed;
    if Results.Gitee.Status = psFailed then
      shpGiteeStatus.Brush.Color := clRed;
    
    SetStatus(Results.GetSummary);
  finally
    Publisher.Free;
  end;
end;

procedure TfrmUniPublisherMain.BtnClearLogClick(Sender: TObject);
begin
  memPublishLog.Clear;
end;

function TfrmUniPublisherMain.Confirm(const Msg: string): Boolean;
begin
  Result := MessageDlg(Msg, mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TfrmUniPublisherMain.BtnBrowseDprojClick(Sender: TObject);
var
  D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Delphi Project (*.dproj)|*.dproj|All files (*.*)|*.*';
    if D.Execute then
      edtDprojPath.Text := D.FileName;
  finally
    D.Free;
  end;
end;

procedure TfrmUniPublisherMain.BtnReadVersionClick(Sender: TObject);
var
  V: string;
begin
  if ReadDprojVersion(edtDprojPath.Text, V) then
  begin
    edtCurrentVersion.Text := V;
    SetStatus('已读取版本号: ' + V);
  end
  else
    SetStatus('读取版本号失败', True);
end;

procedure TfrmUniPublisherMain.BtnWriteVersionClick(Sender: TObject);
begin
  if (edtDprojPath.Text = '') or (edtCurrentVersion.Text = '') then
  begin
    SetStatus('请先填写 .dproj 路径和版本号', True);
    Exit;
  end;

  if not Confirm('写入版本号到 .dproj ?') then
    Exit;

  if WriteDprojVersion(edtDprojPath.Text, edtCurrentVersion.Text) then
    SetStatus('已更新 .dproj 版本号')
  else
    SetStatus('更新 .dproj 版本号失败', True);
end;

procedure TfrmUniPublisherMain.BtnBrowseSourceDirClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtSourceDir.Text;
  if SelectDirectory('选择构建目录', '', Dir) then
    edtSourceDir.Text := Dir;
end;

procedure TfrmUniPublisherMain.BtnBrowseOutputDirClick(Sender: TObject);
var
  Dir: string;
begin
  Dir := edtOutputDir.Text;
  if SelectDirectory('选择输出目录', '', Dir) then
    edtOutputDir.Text := Dir;
end;

procedure TfrmUniPublisherMain.BtnBuildPackageClick(Sender: TObject);
var
  PackagePath: string;
  Size: Int64;
  Sha256: string;
begin
  if (edtSourceDir.Text = '') or (edtOutputDir.Text = '') or (edtPackageName.Text = '') then
  begin
    SetStatus('请先填写构建目录、输出目录和包文件名', True);
    Exit;
  end;

  if BuildPackage(edtSourceDir.Text, edtOutputDir.Text, edtPackageName.Text,
    PackagePath, Size, Sha256) then
  begin
    SetStatus(Format('打包完成: %s (大小: %d 字节)', [PackagePath, Size]));
    // 预填充 version.json 中可能用到的信息
    if edtVersionJsonPath.Text = '' then
      edtVersionJsonPath.Text := TPath.Combine(edtOutputDir.Text, DEFAULT_VERSION_JSON_NAME);
  end
  else
    SetStatus('打包失败', True);
end;

procedure TfrmUniPublisherMain.BtnGenerateJsonClick(Sender: TObject);
var
  ChannelKey, Version, JsonPath, PackagePath, Sha256: string;
  Size: Int64;
begin
  ChannelKey := GetSelectedChannelKey;
  Version := Trim(edtCurrentVersion.Text);
  JsonPath := Trim(edtVersionJsonPath.Text);

  if (ChannelKey = '') or (Version = '') or (JsonPath = '') then
  begin
    SetStatus('请先选择通道、填写版本号和 version.json 路径', True);
    Exit;
  end;

  PackagePath := TPath.Combine(edtOutputDir.Text, edtPackageName.Text);
  if not FileExists(PackagePath) then
  begin
    SetStatus('包文件不存在: ' + PackagePath, True);
    Exit;
  end;

  Size := TFile.GetSize(PackagePath);
  Sha256 := ComputeFileSha256(PackagePath);

  if GenerateVersionJson(JsonPath, ChannelKey, Version, PackagePath,
    Size, Sha256, memReleaseNotes.Text) then
    SetStatus('version.json 已生成: ' + JsonPath)
  else
    SetStatus('生成 version.json 失败', True);
end;

procedure TfrmUniPublisherMain.BtnPublishGitHubClick(Sender: TObject);
var
  Repo, Tag, PackagePath, Notes: string;
begin
  Repo := Trim(edtGitHubRepo.Text);
  Tag := Trim(edtGitHubTag.Text);
  PackagePath := TPath.Combine(edtOutputDir.Text, edtPackageName.Text);
  Notes := memReleaseNotes.Text;

  if (Repo = '') or (Tag = '') then
  begin
    SetStatus('请填写 GitHub 仓库和 Tag', True);
    Exit;
  end;

  if not FileExists(PackagePath) then
  begin
    SetStatus('包文件不存在: ' + PackagePath, True);
    Exit;
  end;

  if PublishToGitHub(Repo, Tag, PackagePath, Notes) then
    SetStatus('已通过 gh CLI 触发 GitHub Release 创建')
  else
    SetStatus('调用 gh CLI 失败，请检查是否已安装 gh', True);
end;

procedure TfrmUniPublisherMain.BtnPublishGiteeClick(Sender: TObject);
var
  Repo, Tag, Token, PackagePath, Notes: string;
begin
  Repo := Trim(edtGiteeRepo.Text);
  Tag := Trim(edtGiteeTag.Text);
  Token := Trim(edtGiteeToken.Text);
  PackagePath := TPath.Combine(edtOutputDir.Text, edtPackageName.Text);
  Notes := memReleaseNotes.Text;

  if (Repo = '') or (Tag = '') or (Token = '') then
  begin
    SetStatus('请填写 Gitee 仓库、Tag 和 Token', True);
    Exit;
  end;

  if not FileExists(PackagePath) then
  begin
    SetStatus('包文件不存在: ' + PackagePath, True);
    Exit;
  end;

  if PublishToGitee(Repo, Tag, Token, PackagePath, Notes) then
    SetStatus('已调用 Gitee API 创建 Release (请在 Gitee 后台确认上传)')
  else
    SetStatus('调用 Gitee API 失败', True);
end;

procedure TfrmUniPublisherMain.BtnGenerateUnlockClick(Sender: TObject);
var
  Prod: string;
  Level: TUnlockLevel;
  Code: string;
begin
  Prod := Trim(edtProductCode.Text);
  if Prod = '' then
  begin
    SetStatus('请先填写产品代码 (如 TK)', True);
    Exit;
  end;

  case cmbUnlockLevel.ItemIndex of
    0: Level := ulFree;
    1: Level := ulFollow;
    2: Level := ulShare;
  else
    Level := ulFree;
  end;

  Code := TUniBaseUnlock.GenerateCode(Prod, dtpUnlockDate.Date, Level);

  memUnlockCodes.Lines.Add(Format('%s  [%s]  %s', [Code,
    TUniBaseUnlock.UnlockLevelToStr(Level), DateToStr(dtpUnlockDate.Date)]));

  SetStatus('已生成解锁码: ' + Code);
end;

function TfrmUniPublisherMain.ReadDprojVersion(const DprojPath: string;
  out Version: string): Boolean;
var
  Content: string;
  P, StartPos, EndPos: Integer;
  KeyStr: string;
begin
  Result := False;
  Version := '';

  if not FileExists(DprojPath) then
  begin
    SetStatus('未找到 dproj 文件: ' + DprojPath, True);
    Exit;
  end;

  Content := TFile.ReadAllText(DprojPath, TEncoding.UTF8);
  KeyStr := 'FileVersion=';

  P := Pos(KeyStr, Content);
  if P <= 0 then
    Exit;

  StartPos := P + Length(KeyStr);
  EndPos := StartPos;
  while (EndPos <= Length(Content)) and (Content[EndPos] <> ';') and (Content[EndPos] <> #10) do
    Inc(EndPos);

  Version := Copy(Content, StartPos, EndPos - StartPos);
  Version := Trim(Version);

  Result := Version <> '';
end;

function TfrmUniPublisherMain.WriteDprojVersion(const DprojPath, Version: string): Boolean;
var
  Content: string;
  KeyStr: string;
  P, StartPos, EndPos: Integer;
begin
  Result := False;

  if not FileExists(DprojPath) then
  begin
    SetStatus('未找到 dproj 文件: ' + DprojPath, True);
    Exit;
  end;

  Content := TFile.ReadAllText(DprojPath, TEncoding.UTF8);
  KeyStr := 'FileVersion=';

  P := Pos(KeyStr, Content);
  if P > 0 then
  begin
    StartPos := P + Length(KeyStr);
    EndPos := StartPos;
    while (EndPos <= Length(Content)) and (Content[EndPos] <> ';') and (Content[EndPos] <> #10) do
      Inc(EndPos);

    Delete(Content, StartPos, EndPos - StartPos);
    Insert(Version, Content, StartPos);
  end;

  KeyStr := 'ProductVersion=';
  P := Pos(KeyStr, Content);
  if P > 0 then
  begin
    StartPos := P + Length(KeyStr);
    EndPos := StartPos;
    while (EndPos <= Length(Content)) and (Content[EndPos] <> ';') and (Content[EndPos] <> #10) do
      Inc(EndPos);

    Delete(Content, StartPos, EndPos - StartPos);
    Insert(Version, Content, StartPos);
  end;

  TFile.WriteAllText(DprojPath, Content, TEncoding.UTF8);
  Result := True;
end;

function TfrmUniPublisherMain.BuildPackage(const SourceDir, OutputDir,
  PackageName: string; out PackagePath: string; out FileSize: Int64;
  out Sha256: string): Boolean;
begin
  Result := False;
  PackagePath := '';
  FileSize := 0;
  Sha256 := '';

  if (not TDirectory.Exists(SourceDir)) or (PackageName = '') then
  begin
    SetStatus('无效的源目录或包文件名', True);
    Exit;
  end;

  if not TDirectory.Exists(OutputDir) then
    TDirectory.CreateDirectory(OutputDir);

  PackagePath := TPath.Combine(OutputDir, PackageName);

  try
    TCompression.ZipDirectory(SourceDir, PackagePath, nil);
    FileSize := TFile.GetSize(PackagePath);
    Sha256 := ComputeFileSha256(PackagePath);
    Result := True;
  except
    on E: Exception do
    begin
      SetStatus('打包异常: ' + E.Message, True);
      Result := False;
    end;
  end;
end;

function TfrmUniPublisherMain.GenerateVersionJson(const JsonPath, Channel,
  Version, DownloadUrl: string; FileSize: Int64; const Sha256,
  ReleaseNotes: string): Boolean;
var
  Root, ChanObj, MetaObj: TJSONObject;
  ChanName: string;
  JsonText: string;
begin
  Result := False;

  ChanName := Channel.ToLower;
  Root := TJSONObject.Create;
  try
    // 初始化三个通道，防止 JSON 结构不对齐
    ChanObj := TJSONObject.Create;
    Root.AddPair('stable', ChanObj.Clone as TJSONValue);
    Root.AddPair('beta', ChanObj.Clone as TJSONValue);
    Root.AddPair('dev', ChanObj.Clone as TJSONValue);

    ChanObj.Free;

    // 重新取出当前通道对象进行填充
    ChanObj := TJSONObject(Root.GetValue(ChanName));
    if ChanObj = nil then
    begin
      ChanObj := TJSONObject.Create;
      Root.AddPair(ChanName, ChanObj);
    end;

    ChanObj.AddPair('version', Version);
    ChanObj.AddPair('versionCode', TJSONNumber.Create(0));
    ChanObj.AddPair('downloadUrl', TJSONString.Create(DownloadUrl));
    ChanObj.AddPair('fileSize', TJSONNumber.Create(FileSize));
    ChanObj.AddPair('sha256', Sha256);
    ChanObj.AddPair('releaseNotes', ReleaseNotes);
    ChanObj.AddPair('releaseDate', DateToStr(Date));
    ChanObj.AddPair('isMandatory', TJSONBool.Create(False));
    ChanObj.AddPair('minOsVersion', '10.0');

    MetaObj := TJSONObject.Create;
    MetaObj.AddPair('lastUpdated', DateToStr(Date));
    MetaObj.AddPair('checkIntervalHours', TJSONNumber.Create(24));
    Root.AddPair('meta', MetaObj);

    JsonText := Root.Format(2);

    ForceDirectories(ExtractFilePath(JsonPath));
    TFile.WriteAllText(JsonPath, JsonText, TEncoding.UTF8);

    Result := True;
  finally
    Root.Free;
  end;
end;

function TfrmUniPublisherMain.ComputeFileSha256(const FileName: string): string;
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(FS, THashSHA2.TSHA2Version.SHA256);
  finally
    FS.Free;
  end;
end;

function TfrmUniPublisherMain.GetSelectedChannelKey: string;
begin
  case cmbChannel.ItemIndex of
    0: Result := 'stable';
    1: Result := 'beta';
    2: Result := 'dev';
  else
    Result := '';
  end;
end;

function TfrmUniPublisherMain.RunShellCommand(const ExeName, Params,
  WorkDir: string): Boolean;
var
  SEInfo: TShellExecuteInfo;
begin
  FillChar(SEInfo, SizeOf(SEInfo), 0);
  SEInfo.cbSize := SizeOf(SEInfo);
  SEInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  SEInfo.Wnd := Handle;
  SEInfo.lpFile := PChar(ExeName);
  SEInfo.lpParameters := PChar(Params);
  if WorkDir <> '' then
    SEInfo.lpDirectory := PChar(WorkDir);
  SEInfo.nShow := SW_SHOWNORMAL;

  Result := ShellExecuteEx(@SEInfo);
end;

function TfrmUniPublisherMain.PublishToGitHub(const Repo, Tag, PackagePath,
  ReleaseNotes: string): Boolean;
var
  Cmd, Args, TempNotes: string;
begin
  // 将 ReleaseNotes 写入临时文件，供 gh 使用 --notes-file
  TempNotes := TPath.Combine(TPath.GetTempPath, Format('unipub_gh_notes_%s.txt', [Tag]));
  TFile.WriteAllText(TempNotes, ReleaseNotes, TEncoding.UTF8);

  Cmd := 'gh';
  Args := Format(' release create %s "%s" --repo %s --notes-file "%s"',
    [Tag, PackagePath, Repo, TempNotes]);

  Result := RunShellCommand(Cmd, Args, ExtractFilePath(PackagePath));
end;

function TfrmUniPublisherMain.PublishToGitee(const Repo, Tag, Token,
  PackagePath, ReleaseNotes: string): Boolean;
var
  Client: THTTPClient;
  Url: string;
  Body: TStringStream;
  Json: TJSONObject;
  Response: IHTTPResponse;
begin
  Result := False;

  Json := TJSONObject.Create;
  try
    Json.AddPair('access_token', Token);
    Json.AddPair('tag_name', Tag);
    Json.AddPair('name', Tag);
    Json.AddPair('body', ReleaseNotes);

    Url := Format('https://gitee.com/api/v5/repos/%s/releases', [Repo]);
    Body := TStringStream.Create(Json.ToJSON, TEncoding.UTF8);
    try
      Client := THTTPClient.Create;
      try
        Client.ContentType := 'application/json';
        Response := Client.Post(Url, Body);
        Result := (Response.StatusCode >= 200) and (Response.StatusCode < 300);
      finally
        Client.Free;
      end;
    finally
      Body.Free;
    end;
  finally
    Json.Free;
  end;
end;

end.
