unit doQryMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Data.DB, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Grids, Vcl.DBGrids, Vcl.Buttons, Vcl.DBCtrls, FireDAC.Stan.Intf,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.Phys.PG, FireDAC.Phys.PGDef, FireDAC.VCLUI.Wait, FireDAC.Comp.Client,
  Data.Win.ADODB,uDoQryLegacy, Vcl.ComCtrls, Vcl.Samples.Spin, Vcl.Mask;

type
  TfrmMain = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Splitter1: TSplitter;
    edtSearch: TEdit;
    btnSearch: TButton;
    btnGenSql: TButton;
    btnExecQry: TButton;
    dsParams: TDataSource;
    dsQueries: TDataSource;
    aQry: TADOQuery;
    dsQry: TDataSource;
    tblQueries: TADOTable;
    tblParams: TADOTable;
    Panel5: TPanel;
    dbgQueries: TDBGrid;
    Splitter2: TSplitter;
    dbgQry: TDBGrid;
    DBNavigator1: TDBNavigator;
    Label1: TLabel;
    Label2: TLabel;
    DBNavigator2: TDBNavigator;
    btnClose: TButton;
    Splitter3: TSplitter;
    Splitter4: TSplitter;
    ListBoxFields: TListBox;
    CboBoxDatabase: TComboBox;
    cboBoxTables: TComboBox;
    btnShowCurrRec: TButton;
    StatusBar1: TStatusBar;
    sEdtFieldsNum: TSpinEdit;
    Panel6: TPanel;
    meoSql: TMemo;
    DBMemo1: TDBMemo;
    Splitter5: TSplitter;
    Splitter6: TSplitter;
    Panel7: TPanel;
    dbgParams: TDBGrid;
    Panel8: TPanel;
    Label3: TLabel;
    edtParams: TEdit;
    cBoxParams: TCheckBox;
    DBEdit2: TDBEdit;
    Conn: TADOConnection;

    procedure btnCloseClick(Sender: TObject);

    procedure btnSearchClick(Sender: TObject);
    procedure btnGenSqlClick(Sender: TObject);
    procedure btnExecQryClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure CboBoxDatabaseChange(Sender: TObject);
    procedure cboBoxTablesChange(Sender: TObject);
    procedure ShowFields;
    function GetDatabaseList: TStringList;
    function GetTableList(DatabaseName: string): TStringList;
    function GetFieldList(TableName: string): TStringList;
    procedure UpdateTablesAndFields;
    procedure FormShow(Sender: TObject);
    procedure btnShowCurrRecClick(Sender: TObject);
    procedure tblParamsBeforePost(DataSet: TDataSet);
    procedure tblParamsAfterInsert(DataSet: TDataSet);
    procedure Button1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;


implementation

{$R *.dfm}


  //s_qureies = ' SELECT * FROM queries order by id desc' ;
  //s_params = 'SELECT * FROM query_parameters WHERE proc_name = :ProcName ORDER BY para_order';

procedure TfrmMain.btnCloseClick(Sender: TObject);
begin
  Close;
end;


procedure TfrmMain.btnExecQryClick(Sender: TObject);
var ProcName,p:String; i:Integer;
begin
  p := '';
  procName :=   tblQueries.FieldByName('proc_name').Value ;
  //showMessage(procName);
  if cboxParams.checked then p :=  edtParams.Text;
  // 鏄庣‘鎸囧畾浣跨敤涓夊弬鏁扮増鏈殑doQry鍑芥暟
  i := doQry( ProcName, aQry, p);
  if i> 0 then    dbgQry.Visible :=True;

end;

procedure TfrmMain.btnGenSqlClick(Sender: TObject);
var  proc_name,p:string;
begin
    p :='';
    // 锟斤拷锟斤拷 tblQueries 锟窖撅拷锟津开诧拷锟揭达拷锟斤拷锟斤拷确锟侥硷拷录锟斤拷
    if not tblQueries.Eof then
    begin
      proc_name := tblQueries.FieldByName('proc_name').AsString;
      aQry.SQL.Text := 'select * from queries where proc_name = :p';
      aQry.Parameters.ParamByName('p').Value := proc_name; // DATA-R3-003 BUG-433: parameterize proc_name
      aQry.Open;
      // 执锟斤拷 BuildSQL 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟?MeoSQL 锟侥憋拷锟斤拷锟斤拷
      if cboxParams.Checked  then               p :=  edtParams.Text;
      MeoSQL.Text := BuildSQL(aQry,p);
    end;
end;

procedure TfrmMain.btnSearchClick(Sender: TObject);
var
  s: string;
begin
  // 锟斤拷取锟矫伙拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷谋锟?
  s := edtSearch.Text;

  // 锟斤拷锟斤拷锟斤拷锟斤拷谋锟轿拷眨锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷示锟斤拷锟斤拷锟斤拷锟斤拷
  if s = '' then
  begin
    tblQueries.Filtered := False; // 锟截闭癸拷锟斤拷
    tblQueries.Filter := ''; // 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟?
    dbgQry.Visible := False;
    Exit;
  end;

  // 锟斤拷锟斤拷模锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷
  tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%'); // DATA-R3-002 BUG-432: QuotedStr escapes inner quotes to prevent filter injection
  tblQueries.Filtered := True; // 锟斤拷锟矫癸拷锟斤拷
end;

procedure TfrmMain.btnShowCurrRecClick(Sender: TObject);
var
  TotalRecords: Integer;
begin
  showMessage(ShowCurrRecord(aQry,sEdtFieldsNum.Value) )         ;
end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  oldCount, newCount: Integer;
  qryCount: TADOQuery;
begin
  // 鍏堣幏鍙栨彃鍏ュ墠鐨勮褰曟暟
  qryCount := TADOQuery.Create(nil);
  try
    qryCount.Connection := aQry.Connection;
    qryCount.SQL.Text := 'SELECT COUNT(*) FROM texts';
    qryCount.Open;
    oldCount := qryCount.Fields[0].AsInteger;

    // 鎵ц鎻掑叆
    try
      aQry.SQL.Clear;
      aQry.SQL.Add('INSERT INTO texts (user_id, share_link, no, title, video_url, status) VALUES (2, NULL, NULL,'
       + '''' + '鎴戞槸涓€澶寸尓' + '''' + ', NULL, '+ '''' + '宸茬粡鍒嗕韩绛夊緟涓嬭浇' + '''' + ')');
      aQry.ExecSQL;

      // 鑾峰彇鎻掑叆鍚庣殑璁板綍鏁?
      qryCount.Close;
      qryCount.Open;
      newCount := qryCount.Fields[0].AsInteger;

      if newCount > oldCount then
        ShowMessage('鎻掑叆鎴愬姛锛屾柊澧炶褰曟暟: ' + IntToStr(newCount - oldCount))
      else
        ShowMessage('璀﹀憡锛氭病鏈夋柊澧炶褰曪紒' + #13#10 +
                   '鎵ц鍓嶈褰曟暟: ' + IntToStr(oldCount) + #13#10 +
                   '鎵ц鍚庤褰曟暟: ' + IntToStr(newCount) + #13#10 +
                   'SQL: ' + aQry.SQL.Text);
    except
      on E: Exception do
      begin
        ShowMessage('鎵ц鍑洪敊: ' + E.Message + #13#10 +
                   'SQL: ' + aQry.SQL.Text);
      end;
    end;

  finally
    qryCount.Free;
  end;
end;

procedure TfrmMain.UpdateTablesAndFields;
begin
  // 锟斤拷锟斤拷 cboBoxTables
  cboBoxTables.Items := GetTableList(cboBoxDatabase.Text);
  if cboBoxTables.Items.Count > 0 then
  begin
    cboBoxTables.ItemIndex := 0; // 默锟斤拷选锟斤拷锟揭伙拷锟斤拷锟?
    ShowFields; // 锟斤拷锟斤拷 ListBoxFields
  end
  else
    ListBoxFields.Items.Clear; // 锟斤拷锟矫伙拷斜锟斤拷锟斤拷锟斤拷锟街讹拷锟叫憋拷
end;


procedure TfrmMain.ShowFields;
begin
  ListBoxFields.Items := GetFieldList(cboBoxTables.Text);
end;




procedure TfrmMain.tblParamsAfterInsert(DataSet: TDataSet);
begin
   DataSet.FieldByName('para_order').AsInteger := 99;
end;

procedure TfrmMain.tblParamsBeforePost(DataSet: TDataSet);
begin
  // 锟节诧拷锟斤拷之前锟斤拷为锟接憋拷锟斤拷 proc_name 锟街段革拷值
  DataSet.FieldByName('proc_name').AsString := tblQueries.FieldByName('proc_name').Value;

end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
   tblQueries.Connection.Connected := true;
   tblQueries.open;
   tblParams.Open;
  // 锟斤拷锟?cboBoxDatabase
  cboBoxDatabase.Items := GetDatabaseList;
  if cboBoxDatabase.Items.Count > 0 then
  begin
    cboBoxDatabase.ItemIndex := 0; // 默锟斤拷选锟斤拷锟揭伙拷锟斤拷锟斤拷菘锟?
    UpdateTablesAndFields; // 锟斤拷锟斤拷 cboBoxTables 锟斤拷 ListBoxFields
  end;
end;

procedure TfrmMain.FormShow(Sender: TObject);
begin
  if  not conn.Connected then
   conn.Connected := True;
end;

function TfrmMain.GetDatabaseList: TStringList;
begin
  Result := TStringList.Create;
  try
    aQry.Close;
    aQry.SQL.Text := 'SELECT datname FROM pg_database WHERE datistemplate = false;'; // 锟斤拷取锟斤拷模锟斤拷锟斤拷锟捷匡拷
    aQry.Open;
    while not aQry.Eof do
    begin
      Result.Add(aQry.FieldByName('datname').AsString); // 锟斤拷锟斤拷锟捷匡拷锟斤拷锟斤拷锟斤拷锟接碉拷锟斤拷锟斤拷锟?
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('锟斤拷取锟斤拷锟捷匡拷锟叫憋拷时锟斤拷锟斤拷: ' + E.Message);
  end;
end;


function TfrmMain.GetTableList(DatabaseName: string): TStringList;
begin
  Result := TStringList.Create;
  try
    aQry.Close;
    aQry.SQL.Text := Format('SELECT table_name FROM information_schema.tables WHERE table_schema = ''public'';', [DatabaseName]);
    aQry.Open;
    while not aQry.Eof do
    begin
      Result.Add(aQry.FieldByName('table_name').AsString); // 锟斤拷锟斤拷锟斤拷锟斤拷锟斤拷锟接碉拷锟斤拷锟斤拷锟?
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('锟斤拷取锟斤拷锟叫憋拷时锟斤拷锟斤拷: ' + E.Message);
  end;
end;

function TfrmMain.GetFieldList(TableName: string): TStringList;
begin
  Result := TStringList.Create;
  try
    aQry.Close;
    aQry.SQL.Text := 'SELECT column_name FROM information_schema.columns WHERE table_name = :t';
    aQry.Parameters.ParamByName('t').Value := TableName; // DATA-R3-003 BUG-433: parameterize table_name to prevent injection
    aQry.Open;
    while not aQry.Eof do
    begin
      Result.Add(aQry.FieldByName('column_name').AsString); // 锟斤拷锟街讹拷锟斤拷锟斤拷锟斤拷锟接碉拷锟斤拷锟斤拷锟?
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('锟斤拷取锟街讹拷锟叫憋拷时锟斤拷锟斤拷: ' + E.Message);
  end;
end;

procedure TfrmMain.CboBoxDatabaseChange(Sender: TObject);
begin
   UpdateTablesAndFields;
end;

procedure TfrmMain.cboBoxTablesChange(Sender: TObject);
begin
  ShowFields;
end;




end.
