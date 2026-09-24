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
  // 明确指定使用三参数版本的doQry函数
  i := doQry( ProcName, aQry, p);
  if i> 0 then    dbgQry.Visible :=True;

end;

procedure TfrmMain.btnGenSqlClick(Sender: TObject);
var  proc_name,p:string;
begin
    p :='';
    // 仅当 tblQueries 有当前记录时才继续
    if not tblQueries.Eof then
    begin
      proc_name := tblQueries.FieldByName('proc_name').AsString;
      aQry.SQL.Text := 'select * from queries where proc_name = :p';
      aQry.Parameters.ParamByName('p').Value := proc_name; // DATA-R3-003 BUG-433: parameterize proc_name
      aQry.Open;
      // 执行 BuildSQL 拼出最终 SQL，结果显示在 MeoSQL 编辑框
      if cboxParams.Checked  then               p :=  edtParams.Text;
      MeoSQL.Text := BuildSQL(aQry,p);
    end;
end;

procedure TfrmMain.btnSearchClick(Sender: TObject);
var
  s: string;
begin
  // 读取搜索框中的文本
  s := edtSearch.Text;

  // 搜索框为空时取消过滤并隐藏结果网格
  if s = '' then
  begin
    tblQueries.Filtered := False; // 关闭过滤
    tblQueries.Filter := ''; // 清空过滤条件
    dbgQry.Visible := False;
    Exit;
  end;

  // 按 proc_name 构造模糊匹配过滤串
  tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%'); // DATA-R3-002 BUG-432: QuotedStr escapes inner quotes to prevent filter injection
  tblQueries.Filtered := True; // 启用过滤
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
  // 先获取插入前的记录数
  qryCount := TADOQuery.Create(nil);
  try
    qryCount.Connection := aQry.Connection;
    qryCount.SQL.Text := 'SELECT COUNT(*) FROM texts';
    qryCount.Open;
    oldCount := qryCount.Fields[0].AsInteger;

    // 执行插入
    try
      aQry.SQL.Clear;
      aQry.SQL.Add('INSERT INTO texts (user_id, share_link, no, title, video_url, status) VALUES (2, NULL, NULL,'
       + '''' + '我是一头猪' + '''' + ', NULL, '+ '''' + '已经分享等待下载' + '''' + ')');
      aQry.ExecSQL;

      // 获取插入后的记录数
      qryCount.Close;
      qryCount.Open;
      newCount := qryCount.Fields[0].AsInteger;

      if newCount > oldCount then
        ShowMessage('插入成功，新增记录数: ' + IntToStr(newCount - oldCount))
      else
        ShowMessage('警告：没有新增记录！' + #13#10 +
                   '执行前记录数: ' + IntToStr(oldCount) + #13#10 +
                   '执行后记录数: ' + IntToStr(newCount) + #13#10 +
                   'SQL: ' + aQry.SQL.Text);
    except
      on E: Exception do
      begin
        ShowMessage('执行出错: ' + E.Message + #13#10 +
                   'SQL: ' + aQry.SQL.Text);
      end;
    end;

  finally
    qryCount.Free;
  end;
end;

procedure TfrmMain.UpdateTablesAndFields;
begin
  // 刷新表下拉框
  cboBoxTables.Items := GetTableList(cboBoxDatabase.Text);
  if cboBoxTables.Items.Count > 0 then
  begin
    cboBoxTables.ItemIndex := 0; // 默认选中第一个表
    ShowFields; // 填充 ListBoxFields
  end
  else
    ListBoxFields.Items.Clear; // 无表可选时清空字段列表
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
  // 写库之前为参数行补上所属 proc_name
  DataSet.FieldByName('proc_name').AsString := tblQueries.FieldByName('proc_name').Value;

end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
   tblQueries.Connection.Connected := true;
   tblQueries.open;
   tblParams.Open;
  // 填充数据库下拉框
  cboBoxDatabase.Items := GetDatabaseList;
  if cboBoxDatabase.Items.Count > 0 then
  begin
    cboBoxDatabase.ItemIndex := 0; // 默认选中第一个数据库
    UpdateTablesAndFields; // 联动刷新表与字段列表
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
    aQry.SQL.Text := 'SELECT datname FROM pg_database WHERE datistemplate = false;'; // 排除模板库
    aQry.Open;
    while not aQry.Eof do
    begin
      Result.Add(aQry.FieldByName('datname').AsString); // 逐个收集数据库名
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('获取数据库列表时出错: ' + E.Message);
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
      Result.Add(aQry.FieldByName('table_name').AsString); // 逐个收集表名
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('获取表列表时出错: ' + E.Message);
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
      Result.Add(aQry.FieldByName('column_name').AsString); // 逐个收集列名
      aQry.Next;
    end;
    aQry.Close;
  except
    on E: Exception do
      ShowMessage('获取列信息时出错: ' + E.Message);
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
