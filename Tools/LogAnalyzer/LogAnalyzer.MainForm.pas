{ ============================================================================
  LogAnalyzer.MainForm - 鏃ュ織鍒嗘瀽鍣ㄤ富绐椾綋

  鐗堟湰: 1.0
  鍔熻兘:
    - 鎵撳紑澶氫釜鏁版嵁搴?
    - 鏃ュ織鍒楄〃鏄剧ず
    - 鏃堕棿/绾у埆/鍏抽敭璇嶈繃婊?
    - 缁熻闈㈡澘
    - 瀵煎嚭鍔熻兘
  ============================================================================ }

unit LogAnalyzer.MainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.UITypes,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.Menus,
  Data.DB,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Option,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  FireDAC.DApt.Intf,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.UI.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Pool,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet,
  LogAnalyzer.Data,
  LogAnalyzer.Stats,
  LogAnalyzer.Export;

type
  TfrmLogAnalyzer = class(TForm)
    { 鑿滃崟 }
    MainMenu: TMainMenu;
    mnuFile: TMenuItem;
    mnuFileOpen: TMenuItem;
    mnuFileClose: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuFileExportCSV: TMenuItem;
    mnuFileExportJSON: TMenuItem;
    mnuFileExportHTML: TMenuItem;
    mnuFileSep2: TMenuItem;
    mnuFileExit: TMenuItem;
    mnuView: TMenuItem;
    mnuViewRefresh: TMenuItem;
    mnuViewStats: TMenuItem;
    mnuHelp: TMenuItem;
    mnuHelpAbout: TMenuItem;

    { 宸ュ叿鏍?}
    pnlToolbar: TPanel;
    lblDatabase: TLabel;
    cboDatabase: TComboBox;
    btnOpenDB: TButton;
    btnCloseDB: TButton;
    btnRefresh: TButton;

    { 杩囨护闈㈡澘 }
    pnlFilter: TPanel;
    lblFromTime: TLabel;
    dtpFrom: TDateTimePicker;
    lblToTime: TLabel;
    dtpTo: TDateTimePicker;
    lblLevel: TLabel;
    chkTrace: TCheckBox;
    chkDebug: TCheckBox;
    chkInfo: TCheckBox;
    chkWarn: TCheckBox;
    chkError: TCheckBox;
    chkFatal: TCheckBox;
    lblSource: TLabel;
    edtSource: TEdit;
    lblMessage: TLabel;
    edtMessage: TEdit;
    btnSearch: TButton;
    btnClear: TButton;

    { 涓诲唴瀹瑰尯 }
    splMain: TSplitter;
    pnlLeft: TPanel;
    lvLogs: TListView;
    pnlRight: TPanel;
    pgcDetails: TPageControl;
    tabDetails: TTabSheet;
    tabStats: TTabSheet;
    mmoDetails: TMemo;
    pnlStats: TPanel;
    lblStatsTitle: TLabel;
    lvStats: TListView;

    { 鐘舵€佹爮 }
    StatusBar: TStatusBar;

    { 瀵硅瘽妗?}
    dlgOpen: TOpenDialog;
    dlgSave: TSaveDialog;

    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnOpenDBClick(Sender: TObject);
    procedure btnCloseDBClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure lvLogsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure mnuFileOpenClick(Sender: TObject);
    procedure mnuFileCloseClick(Sender: TObject);
    procedure mnuFileExportCSVClick(Sender: TObject);
    procedure mnuFileExportJSONClick(Sender: TObject);
    procedure mnuFileExportHTMLClick(Sender: TObject);
    procedure mnuFileExitClick(Sender: TObject);
    procedure mnuViewRefreshClick(Sender: TObject);
    procedure mnuViewStatsClick(Sender: TObject);
    procedure mnuHelpAboutClick(Sender: TObject);
    procedure cboDatabaseChange(Sender: TObject);

  private
    FConnections: TObjectDictionary<string, TFDConnection>;
    FCurrentDB: string;
    FLogs: TArray<TLogEntry>;
    FLogSource: ILogSource;

    procedure CreateUI;
    procedure CreateMenu;
    procedure CreateToolbar;
    procedure CreateFilterPanel;
    procedure CreateMainContent;
    procedure CreateStatusBar;

    procedure OpenDatabase(const APath: string);
    procedure CloseDatabase(const APath: string);
    procedure CloseAllDatabases;
    procedure LoadLogs;
    procedure DisplayLogs;
    procedure DisplayLogDetails(const AEntry: TLogEntry);
    procedure UpdateStats;
    procedure UpdateStatusBar;
    procedure ClearFilter;

    function GetCurrentConnection: TFDConnection;
    function GetLogQuery: TLogQuery;
    function GetSelectedLevels: TLogLevels;
    function LevelToString(ALevel: TLogLevel): string;
    function LevelToColor(ALevel: TLogLevel): TColor;

  public
    property CurrentDB: string read FCurrentDB;
  end;

var
  frmLogAnalyzer: TfrmLogAnalyzer;

implementation

{$R *.dfm}

const
  APP_TITLE = 'DeepBase 鏃ュ織鍒嗘瀽鍣?;
  VERSION = '1.0';

{ TfrmLogAnalyzer }

procedure TfrmLogAnalyzer.FormCreate(Sender: TObject);
begin
  FConnections := TObjectDictionary<string, TFDConnection>.Create([doOwnsValues]);
  FCurrentDB := '';
  SetLength(FLogs, 0);

  Caption := APP_TITLE;
  Width := 1200;
  Height := 800;
  Position := poScreenCenter;

  CreateUI;

  // 榛樿鏃堕棿鑼冨洿: 鏈€杩?4灏忔椂
  dtpFrom.DateTime := IncHour(Now, -24);
  dtpTo.DateTime := Now;

  // 榛樿绾у埆
  chkInfo.Checked := True;
  chkWarn.Checked := True;
  chkError.Checked := True;
  chkFatal.Checked := True;

  UpdateStatusBar;
end;

procedure TfrmLogAnalyzer.FormDestroy(Sender: TObject);
begin
  FLogSource := nil;
  FreeAndNil(FConnections);
end;

procedure TfrmLogAnalyzer.CreateUI;
begin
  CreateMenu;
  CreateToolbar;
  CreateFilterPanel;
  CreateMainContent;
  CreateStatusBar;
end;

procedure TfrmLogAnalyzer.CreateMenu;
begin
  MainMenu := TMainMenu.Create(Self);

  // 鏂囦欢鑿滃崟
  mnuFile := TMenuItem.Create(MainMenu);
  mnuFile.Caption := '鏂囦欢(&F)';
  MainMenu.Items.Add(mnuFile);

  mnuFileOpen := TMenuItem.Create(mnuFile);
  mnuFileOpen.Caption := '鎵撳紑鏁版嵁搴?&O)...';
  mnuFileOpen.ShortCut := TextToShortCut('Ctrl+O');
  mnuFileOpen.OnClick := mnuFileOpenClick;
  mnuFile.Add(mnuFileOpen);

  mnuFileClose := TMenuItem.Create(mnuFile);
  mnuFileClose.Caption := '鍏抽棴鏁版嵁搴?&C)';
  mnuFileClose.OnClick := mnuFileCloseClick;
  mnuFile.Add(mnuFileClose);

  mnuFileSep1 := TMenuItem.Create(mnuFile);
  mnuFileSep1.Caption := '-';
  mnuFile.Add(mnuFileSep1);

  mnuFileExportCSV := TMenuItem.Create(mnuFile);
  mnuFileExportCSV.Caption := '瀵煎嚭涓?CSV...';
  mnuFileExportCSV.OnClick := mnuFileExportCSVClick;
  mnuFile.Add(mnuFileExportCSV);

  mnuFileExportJSON := TMenuItem.Create(mnuFile);
  mnuFileExportJSON.Caption := '瀵煎嚭涓?JSON...';
  mnuFileExportJSON.OnClick := mnuFileExportJSONClick;
  mnuFile.Add(mnuFileExportJSON);

  mnuFileExportHTML := TMenuItem.Create(mnuFile);
  mnuFileExportHTML.Caption := '瀵煎嚭涓?HTML...';
  mnuFileExportHTML.OnClick := mnuFileExportHTMLClick;
  mnuFile.Add(mnuFileExportHTML);

  mnuFileSep2 := TMenuItem.Create(mnuFile);
  mnuFileSep2.Caption := '-';
  mnuFile.Add(mnuFileSep2);

  mnuFileExit := TMenuItem.Create(mnuFile);
  mnuFileExit.Caption := '閫€鍑?&X)';
  mnuFileExit.ShortCut := TextToShortCut('Alt+F4');
  mnuFileExit.OnClick := mnuFileExitClick;
  mnuFile.Add(mnuFileExit);

  // 瑙嗗浘鑿滃崟
  mnuView := TMenuItem.Create(MainMenu);
  mnuView.Caption := '瑙嗗浘(&V)';
  MainMenu.Items.Add(mnuView);

  mnuViewRefresh := TMenuItem.Create(mnuView);
  mnuViewRefresh.Caption := '鍒锋柊(&R)';
  mnuViewRefresh.ShortCut := TextToShortCut('F5');
  mnuViewRefresh.OnClick := mnuViewRefreshClick;
  mnuView.Add(mnuViewRefresh);

  mnuViewStats := TMenuItem.Create(mnuView);
  mnuViewStats.Caption := '鏄剧ず缁熻(&S)';
  mnuViewStats.OnClick := mnuViewStatsClick;
  mnuView.Add(mnuViewStats);

  // 甯姪鑿滃崟
  mnuHelp := TMenuItem.Create(MainMenu);
  mnuHelp.Caption := '甯姪(&H)';
  MainMenu.Items.Add(mnuHelp);

  mnuHelpAbout := TMenuItem.Create(mnuHelp);
  mnuHelpAbout.Caption := '鍏充簬(&A)...';
  mnuHelpAbout.OnClick := mnuHelpAboutClick;
  mnuHelp.Add(mnuHelpAbout);
end;

procedure TfrmLogAnalyzer.CreateToolbar;
begin
  pnlToolbar := TPanel.Create(Self);
  pnlToolbar.Parent := Self;
  pnlToolbar.Align := alTop;
  pnlToolbar.Height := 40;
  pnlToolbar.BevelOuter := bvNone;
  pnlToolbar.ParentBackground := False;

  lblDatabase := TLabel.Create(Self);
  lblDatabase.Parent := pnlToolbar;
  lblDatabase.SetBounds(10, 12, 50, 16);
  lblDatabase.Caption := '鏁版嵁搴?';

  cboDatabase := TComboBox.Create(Self);
  cboDatabase.Parent := pnlToolbar;
  cboDatabase.SetBounds(70, 8, 300, 24);
  cboDatabase.Style := csDropDownList;
  cboDatabase.OnChange := cboDatabaseChange;

  btnOpenDB := TButton.Create(Self);
  btnOpenDB.Parent := pnlToolbar;
  btnOpenDB.SetBounds(380, 7, 80, 26);
  btnOpenDB.Caption := '鎵撳紑...';
  btnOpenDB.OnClick := btnOpenDBClick;

  btnCloseDB := TButton.Create(Self);
  btnCloseDB.Parent := pnlToolbar;
  btnCloseDB.SetBounds(470, 7, 60, 26);
  btnCloseDB.Caption := '鍏抽棴';
  btnCloseDB.OnClick := btnCloseDBClick;

  btnRefresh := TButton.Create(Self);
  btnRefresh.Parent := pnlToolbar;
  btnRefresh.SetBounds(540, 7, 60, 26);
  btnRefresh.Caption := '鍒锋柊';
  btnRefresh.OnClick := btnRefreshClick;

  // 瀵硅瘽妗?
  dlgOpen := TOpenDialog.Create(Self);
  dlgOpen.Filter := 'SQLite 鏁版嵁搴搢*.db;*.sqlite;*.sqlite3|鎵€鏈夋枃浠秥*.*';
  dlgOpen.Title := '鎵撳紑鏃ュ織鏁版嵁搴?;

  dlgSave := TSaveDialog.Create(Self);
  dlgSave.Title := '瀵煎嚭鏃ュ織';
end;

procedure TfrmLogAnalyzer.CreateFilterPanel;
begin
  pnlFilter := TPanel.Create(Self);
  pnlFilter.Parent := Self;
  pnlFilter.Align := alTop;
  pnlFilter.Height := 80;
  pnlFilter.BevelOuter := bvNone;
  pnlFilter.ParentBackground := False;

  // 绗竴琛? 鏃堕棿鑼冨洿
  lblFromTime := TLabel.Create(Self);
  lblFromTime.Parent := pnlFilter;
  lblFromTime.SetBounds(10, 12, 50, 16);
  lblFromTime.Caption := '浠?';

  dtpFrom := TDateTimePicker.Create(Self);
  dtpFrom.Parent := pnlFilter;
  dtpFrom.SetBounds(40, 8, 150, 24);
  dtpFrom.Kind := dtkDateTime;

  lblToTime := TLabel.Create(Self);
  lblToTime.Parent := pnlFilter;
  lblToTime.SetBounds(200, 12, 30, 16);
  lblToTime.Caption := '鍒?';

  dtpTo := TDateTimePicker.Create(Self);
  dtpTo.Parent := pnlFilter;
  dtpTo.SetBounds(230, 8, 150, 24);
  dtpTo.Kind := dtkDateTime;

  lblLevel := TLabel.Create(Self);
  lblLevel.Parent := pnlFilter;
  lblLevel.SetBounds(400, 12, 40, 16);
  lblLevel.Caption := '绾у埆:';

  chkTrace := TCheckBox.Create(Self);
  chkTrace.Parent := pnlFilter;
  chkTrace.SetBounds(450, 10, 60, 20);
  chkTrace.Caption := 'Trace';

  chkDebug := TCheckBox.Create(Self);
  chkDebug.Parent := pnlFilter;
  chkDebug.SetBounds(510, 10, 60, 20);
  chkDebug.Caption := 'Debug';

  chkInfo := TCheckBox.Create(Self);
  chkInfo.Parent := pnlFilter;
  chkInfo.SetBounds(580, 10, 50, 20);
  chkInfo.Caption := 'Info';

  chkWarn := TCheckBox.Create(Self);
  chkWarn.Parent := pnlFilter;
  chkWarn.SetBounds(640, 10, 60, 20);
  chkWarn.Caption := 'Warn';

  chkError := TCheckBox.Create(Self);
  chkError.Parent := pnlFilter;
  chkError.SetBounds(710, 10, 55, 20);
  chkError.Caption := 'Error';

  chkFatal := TCheckBox.Create(Self);
  chkFatal.Parent := pnlFilter;
  chkFatal.SetBounds(775, 10, 55, 20);
  chkFatal.Caption := 'Fatal';

  // 绗簩琛? 鍏抽敭璇嶆悳绱?
  lblSource := TLabel.Create(Self);
  lblSource.Parent := pnlFilter;
  lblSource.SetBounds(10, 48, 40, 16);
  lblSource.Caption := '鏉ユ簮:';

  edtSource := TEdit.Create(Self);
  edtSource.Parent := pnlFilter;
  edtSource.SetBounds(50, 44, 150, 24);

  lblMessage := TLabel.Create(Self);
  lblMessage.Parent := pnlFilter;
  lblMessage.SetBounds(210, 48, 40, 16);
  lblMessage.Caption := '娑堟伅:';

  edtMessage := TEdit.Create(Self);
  edtMessage.Parent := pnlFilter;
  edtMessage.SetBounds(260, 44, 250, 24);

  btnSearch := TButton.Create(Self);
  btnSearch.Parent := pnlFilter;
  btnSearch.SetBounds(520, 43, 60, 26);
  btnSearch.Caption := '鎼滅储';
  btnSearch.OnClick := btnSearchClick;

  btnClear := TButton.Create(Self);
  btnClear.Parent := pnlFilter;
  btnClear.SetBounds(590, 43, 60, 26);
  btnClear.Caption := '娓呴櫎';
  btnClear.OnClick := btnClearClick;
end;

procedure TfrmLogAnalyzer.CreateMainContent;
begin
  // 宸︿晶鏃ュ織鍒楄〃
  pnlLeft := TPanel.Create(Self);
  pnlLeft.Parent := Self;
  pnlLeft.Align := alClient;
  pnlLeft.BevelOuter := bvNone;

  lvLogs := TListView.Create(Self);
  lvLogs.Parent := pnlLeft;
  lvLogs.Align := alClient;
  lvLogs.ViewStyle := vsReport;
  lvLogs.RowSelect := True;
  lvLogs.ReadOnly := True;
  lvLogs.GridLines := True;
  lvLogs.OnSelectItem := lvLogsSelectItem;

  with lvLogs.Columns.Add do
  begin
    Caption := 'ID';
    Width := 60;
  end;
  with lvLogs.Columns.Add do
  begin
    Caption := '鏃堕棿';
    Width := 150;
  end;
  with lvLogs.Columns.Add do
  begin
    Caption := '绾у埆';
    Width := 60;
  end;
  with lvLogs.Columns.Add do
  begin
    Caption := '鏉ユ簮';
    Width := 120;
  end;
  with lvLogs.Columns.Add do
  begin
    Caption := '娑堟伅';
    Width := 500;
  end;

  // 鍙充晶璇︽儏闈㈡澘
  pnlRight := TPanel.Create(Self);
  pnlRight.Parent := Self;
  pnlRight.Align := alRight;
  pnlRight.Width := 350;
  pnlRight.BevelOuter := bvNone;

  splMain := TSplitter.Create(Self);
  splMain.Parent := Self;
  splMain.Align := alRight;
  splMain.Width := 5;

  pgcDetails := TPageControl.Create(Self);
  pgcDetails.Parent := pnlRight;
  pgcDetails.Align := alClient;

  tabDetails := TTabSheet.Create(pgcDetails);
  tabDetails.PageControl := pgcDetails;
  tabDetails.Caption := '璇︽儏';

  mmoDetails := TMemo.Create(Self);
  mmoDetails.Parent := tabDetails;
  mmoDetails.Align := alClient;
  mmoDetails.ReadOnly := True;
  mmoDetails.ScrollBars := ssBoth;
  mmoDetails.Font.Name := 'Consolas';
  mmoDetails.Font.Size := 10;
  mmoDetails.WordWrap := True;

  tabStats := TTabSheet.Create(pgcDetails);
  tabStats.PageControl := pgcDetails;
  tabStats.Caption := '缁熻';

  pnlStats := TPanel.Create(Self);
  pnlStats.Parent := tabStats;
  pnlStats.Align := alClient;
  pnlStats.BevelOuter := bvNone;

  lblStatsTitle := TLabel.Create(Self);
  lblStatsTitle.Parent := pnlStats;
  lblStatsTitle.SetBounds(10, 10, 200, 16);
  lblStatsTitle.Caption := '鏃ュ織缁熻';
  lblStatsTitle.Font.Style := [fsBold];

  lvStats := TListView.Create(Self);
  lvStats.Parent := pnlStats;
  lvStats.SetBounds(10, 35, 320, 400);
  lvStats.ViewStyle := vsReport;
  lvStats.RowSelect := True;
  lvStats.ReadOnly := True;
  lvStats.GridLines := True;

  with lvStats.Columns.Add do
  begin
    Caption := '椤圭洰';
    Width := 150;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := '鏁伴噺';
    Width := 80;
    Alignment := taRightJustify;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := '鐧惧垎姣?;
    Width := 80;
    Alignment := taRightJustify;
  end;
end;

procedure TfrmLogAnalyzer.CreateStatusBar;
begin
  StatusBar := TStatusBar.Create(Self);
  StatusBar.Parent := Self;
  StatusBar.SimplePanel := False;

  with StatusBar.Panels.Add do
  begin
    Width := 200;
    Text := '灏辩华';
  end;
  with StatusBar.Panels.Add do
  begin
    Width := 150;
    Text := '鏃ュ織: 0';
  end;
  with StatusBar.Panels.Add do
  begin
    Width := 200;
    Text := '';
  end;
end;

procedure TfrmLogAnalyzer.OpenDatabase(const APath: string);
var
  Conn: TFDConnection;
begin
  if FConnections.ContainsKey(APath) then
  begin
    FCurrentDB := APath;
    cboDatabase.ItemIndex := cboDatabase.Items.IndexOf(APath);
    LoadLogs;
    Exit;
  end;

  if not FileExists(APath) then
  begin
    MessageDlg('鏁版嵁搴撴枃浠朵笉瀛樺湪: ' + APath, mtError, [mbOK], 0);
    Exit;
  end;

  Conn := TFDConnection.Create(nil);
  try
    Conn.DriverName := 'SQLite';
    Conn.Params.Database := APath;
    Conn.Params.Values['LockingMode'] := 'Normal';
    Conn.LoginPrompt := False;
    Conn.Open;

    FConnections.Add(APath, Conn);
    cboDatabase.Items.Add(APath);
    cboDatabase.ItemIndex := cboDatabase.Items.Count - 1;
    FCurrentDB := APath;

    LoadLogs;
    UpdateStatusBar;
  except
    on E: Exception do
    begin
      Conn.Free;
      MessageDlg('鎵撳紑鏁版嵁搴撳け璐? ' + E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TfrmLogAnalyzer.CloseDatabase(const APath: string);
var
  Idx: Integer;
begin
  if not FConnections.ContainsKey(APath) then
    Exit;

  FConnections.Remove(APath);

  Idx := cboDatabase.Items.IndexOf(APath);
  if Idx >= 0 then
    cboDatabase.Items.Delete(Idx);

  if FCurrentDB = APath then
  begin
    FCurrentDB := '';
    FLogSource := nil;
    SetLength(FLogs, 0);
    lvLogs.Items.Clear;
    mmoDetails.Clear;

    if cboDatabase.Items.Count > 0 then
    begin
      cboDatabase.ItemIndex := 0;
      FCurrentDB := cboDatabase.Text;
      LoadLogs;
    end;
  end;

  UpdateStatusBar;
end;

procedure TfrmLogAnalyzer.CloseAllDatabases;
begin
  FConnections.Clear;
  cboDatabase.Clear;
  FCurrentDB := '';
  FLogSource := nil;
  SetLength(FLogs, 0);
  lvLogs.Items.Clear;
  mmoDetails.Clear;
  UpdateStatusBar;
end;

function TfrmLogAnalyzer.GetCurrentConnection: TFDConnection;
begin
  Result := nil;
  if (FCurrentDB <> '') and FConnections.ContainsKey(FCurrentDB) then
    Result := FConnections[FCurrentDB];
end;

function TfrmLogAnalyzer.GetSelectedLevels: TLogLevels;
begin
  Result := [];
  if chkTrace.Checked then Include(Result, llTrace);
  if chkDebug.Checked then Include(Result, llDebug);
  if chkInfo.Checked then Include(Result, llInfo);
  if chkWarn.Checked then Include(Result, llWarn);
  if chkError.Checked then Include(Result, llError);
  if chkFatal.Checked then Include(Result, llFatal);
end;

function TfrmLogAnalyzer.GetLogQuery: TLogQuery;
begin
  Result.FromTime := dtpFrom.DateTime;
  Result.ToTime := dtpTo.DateTime;
  Result.Levels := GetSelectedLevels;
  Result.SourceKeyword := Trim(edtSource.Text);
  Result.MessageKeyword := Trim(edtMessage.Text);
end;

procedure TfrmLogAnalyzer.LoadLogs;
var
  Conn: TFDConnection;
  Query: TLogQuery;
begin
  Conn := GetCurrentConnection;
  if Conn = nil then
  begin
    SetLength(FLogs, 0);
    DisplayLogs;
    Exit;
  end;

  FLogSource := TDbLogSource.Create(Conn);
  Query := GetLogQuery;

  Screen.Cursor := crHourGlass;
  try
    FLogs := FLogSource.LoadLogs(Query);
    DisplayLogs;
    UpdateStats;
    UpdateStatusBar;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TfrmLogAnalyzer.DisplayLogs;
var
  I: Integer;
  Item: TListItem;
begin
  lvLogs.Items.BeginUpdate;
  try
    lvLogs.Items.Clear;

    for I := 0 to High(FLogs) do
    begin
      Item := lvLogs.Items.Add;
      Item.Caption := IntToStr(FLogs[I].Id);
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss', FLogs[I].Timestamp));
      Item.SubItems.Add(LevelToString(FLogs[I].Level));
      Item.SubItems.Add(FLogs[I].Source);
      Item.SubItems.Add(FLogs[I].Message);
      Item.Data := Pointer(I);
    end;
  finally
    lvLogs.Items.EndUpdate;
  end;
end;

procedure TfrmLogAnalyzer.DisplayLogDetails(const AEntry: TLogEntry);
begin
  mmoDetails.Clear;
  mmoDetails.Lines.Add('=== 鏃ュ織璇︽儏 ===');
  mmoDetails.Lines.Add('');
  mmoDetails.Lines.Add('ID: ' + IntToStr(AEntry.Id));
  mmoDetails.Lines.Add('鏃堕棿: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', AEntry.Timestamp));
  mmoDetails.Lines.Add('绾у埆: ' + LevelToString(AEntry.Level));
  mmoDetails.Lines.Add('鏉ユ簮: ' + AEntry.Source);
  mmoDetails.Lines.Add('');
  mmoDetails.Lines.Add('=== 娑堟伅 ===');
  mmoDetails.Lines.Add(AEntry.Message);

  if AEntry.Details <> '' then
  begin
    mmoDetails.Lines.Add('');
    mmoDetails.Lines.Add('=== 璇︾粏淇℃伅 ===');
    mmoDetails.Lines.Add(AEntry.Details);
  end;
end;

procedure TfrmLogAnalyzer.UpdateStats;
var
  Stats: TLogStats;
  Item: TListItem;
  Total: Integer;
  I: TLogLevel;
begin
  Stats := TLogStats.Calculate(FLogs);
  Total := Length(FLogs);

  lvStats.Items.BeginUpdate;
  try
    lvStats.Items.Clear;

    Item := lvStats.Items.Add;
    Item.Caption := '鎬绘暟';
    Item.SubItems.Add(IntToStr(Total));
    Item.SubItems.Add('100%');

    for I := Low(TLogLevel) to High(TLogLevel) do
    begin
      Item := lvStats.Items.Add;
      Item.Caption := LevelToString(I);
      Item.SubItems.Add(IntToStr(Stats.CountByLevel[I]));
      if Total > 0 then
        Item.SubItems.Add(Format('%.1f%%', [Stats.CountByLevel[I] * 100 / Total]))
      else
        Item.SubItems.Add('0%');
    end;

    Item := lvStats.Items.Add;
    Item.Caption := '';
    Item.SubItems.Add('');
    Item.SubItems.Add('');

    Item := lvStats.Items.Add;
    Item.Caption := '鍞竴鏉ユ簮鏁?;
    Item.SubItems.Add(IntToStr(Stats.UniqueSources));
    Item.SubItems.Add('');

    if Stats.FirstTime > 0 then
    begin
      Item := lvStats.Items.Add;
      Item.Caption := '鏈€鏃╂椂闂?;
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', Stats.FirstTime));
      Item.SubItems.Add('');

      Item := lvStats.Items.Add;
      Item.Caption := '鏈€鏅氭椂闂?;
      Item.SubItems.Add(FormatDateTime('yyyy-mm-dd hh:nn', Stats.LastTime));
      Item.SubItems.Add('');
    end;
  finally
    lvStats.Items.EndUpdate;
  end;
end;

procedure TfrmLogAnalyzer.UpdateStatusBar;
begin
  if FCurrentDB <> '' then
    StatusBar.Panels[0].Text := '宸茶繛鎺? ' + ExtractFileName(FCurrentDB)
  else
    StatusBar.Panels[0].Text := '鏈繛鎺?;

  StatusBar.Panels[1].Text := Format('鏃ュ織: %d', [Length(FLogs)]);
  StatusBar.Panels[2].Text := Format('鏁版嵁搴? %d', [FConnections.Count]);
end;

procedure TfrmLogAnalyzer.ClearFilter;
begin
  dtpFrom.DateTime := IncHour(Now, -24);
  dtpTo.DateTime := Now;
  chkTrace.Checked := False;
  chkDebug.Checked := False;
  chkInfo.Checked := True;
  chkWarn.Checked := True;
  chkError.Checked := True;
  chkFatal.Checked := True;
  edtSource.Clear;
  edtMessage.Clear;
end;

function TfrmLogAnalyzer.LevelToString(ALevel: TLogLevel): string;
begin
  case ALevel of
    llTrace: Result := 'TRACE';
    llDebug: Result := 'DEBUG';
    llInfo:  Result := 'INFO';
    llWarn:  Result := 'WARN';
    llError: Result := 'ERROR';
    llFatal: Result := 'FATAL';
  else
    Result := '?';
  end;
end;

function TfrmLogAnalyzer.LevelToColor(ALevel: TLogLevel): TColor;
begin
  case ALevel of
    llTrace: Result := clGray;
    llDebug: Result := clNavy;
    llInfo:  Result := clGreen;
    llWarn:  Result := $0080FF; // Orange
    llError: Result := clRed;
    llFatal: Result := clMaroon;
  else
    Result := clBlack;
  end;
end;

{ 浜嬩欢澶勭悊 }

procedure TfrmLogAnalyzer.btnOpenDBClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    OpenDatabase(dlgOpen.FileName);
end;

procedure TfrmLogAnalyzer.btnCloseDBClick(Sender: TObject);
begin
  if FCurrentDB <> '' then
    CloseDatabase(FCurrentDB);
end;

procedure TfrmLogAnalyzer.btnRefreshClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfrmLogAnalyzer.btnSearchClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfrmLogAnalyzer.btnClearClick(Sender: TObject);
begin
  ClearFilter;
  LoadLogs;
end;

procedure TfrmLogAnalyzer.lvLogsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
var
  Idx: Integer;
begin
  if Selected and (Item <> nil) then
  begin
    Idx := NativeInt(Item.Data);
    if (Idx >= 0) and (Idx <= High(FLogs)) then
      DisplayLogDetails(FLogs[Idx]);
  end;
end;

procedure TfrmLogAnalyzer.cboDatabaseChange(Sender: TObject);
begin
  if cboDatabase.ItemIndex >= 0 then
  begin
    FCurrentDB := cboDatabase.Text;
    LoadLogs;
  end;
end;

procedure TfrmLogAnalyzer.mnuFileOpenClick(Sender: TObject);
begin
  btnOpenDBClick(Sender);
end;

procedure TfrmLogAnalyzer.mnuFileCloseClick(Sender: TObject);
begin
  btnCloseDBClick(Sender);
end;

procedure TfrmLogAnalyzer.mnuFileExportCSVClick(Sender: TObject);
begin
  if Length(FLogs) = 0 then
  begin
    MessageDlg('娌℃湁鏃ュ織鍙鍑?, mtInformation, [mbOK], 0);
    Exit;
  end;

  dlgSave.Filter := 'CSV 鏂囦欢|*.csv';
  dlgSave.DefaultExt := 'csv';
  dlgSave.FileName := 'logs_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.csv';

  if dlgSave.Execute then
  begin
    TLogExporter.ExportToCSV(FLogs, dlgSave.FileName);
    MessageDlg('瀵煎嚭鎴愬姛: ' + dlgSave.FileName, mtInformation, [mbOK], 0);
  end;
end;

procedure TfrmLogAnalyzer.mnuFileExportJSONClick(Sender: TObject);
begin
  if Length(FLogs) = 0 then
  begin
    MessageDlg('娌℃湁鏃ュ織鍙鍑?, mtInformation, [mbOK], 0);
    Exit;
  end;

  dlgSave.Filter := 'JSON 鏂囦欢|*.json';
  dlgSave.DefaultExt := 'json';
  dlgSave.FileName := 'logs_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.json';

  if dlgSave.Execute then
  begin
    TLogExporter.ExportToJSON(FLogs, dlgSave.FileName);
    MessageDlg('瀵煎嚭鎴愬姛: ' + dlgSave.FileName, mtInformation, [mbOK], 0);
  end;
end;

procedure TfrmLogAnalyzer.mnuFileExportHTMLClick(Sender: TObject);
begin
  if Length(FLogs) = 0 then
  begin
    MessageDlg('娌℃湁鏃ュ織鍙鍑?, mtInformation, [mbOK], 0);
    Exit;
  end;

  dlgSave.Filter := 'HTML 鏂囦欢|*.html';
  dlgSave.DefaultExt := 'html';
  dlgSave.FileName := 'logs_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.html';

  if dlgSave.Execute then
  begin
    TLogExporter.ExportToHTML(FLogs, dlgSave.FileName, '鏃ュ織瀵煎嚭 - ' + ExtractFileName(FCurrentDB));
    MessageDlg('瀵煎嚭鎴愬姛: ' + dlgSave.FileName, mtInformation, [mbOK], 0);
  end;
end;

procedure TfrmLogAnalyzer.mnuFileExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfrmLogAnalyzer.mnuViewRefreshClick(Sender: TObject);
begin
  LoadLogs;
end;

procedure TfrmLogAnalyzer.mnuViewStatsClick(Sender: TObject);
begin
  pgcDetails.ActivePage := tabStats;
  UpdateStats;
end;

procedure TfrmLogAnalyzer.mnuHelpAboutClick(Sender: TObject);
begin
  MessageDlg(
    APP_TITLE + ' v' + VERSION + #13#10#13#10 +
    'DeepBase 鏃ュ織鍒嗘瀽宸ュ叿' + #13#10 +
    '鐢ㄤ簬鏌ョ湅鍜屽垎鏋?DeepBase 妗嗘灦鐢熸垚鐨勬棩蹇楁暟鎹€? + #13#10#13#10 +
    '鍔熻兘:' + #13#10 +
    '- 澶氭暟鎹簱鏀寔' + #13#10 +
    '- 鏃堕棿/绾у埆/鍏抽敭璇嶈繃婊? + #13#10 +
    '- 缁熻淇℃伅' + #13#10 +
    '- CSV/JSON/HTML 瀵煎嚭',
    mtInformation, [mbOK], 0);
end;

end.
