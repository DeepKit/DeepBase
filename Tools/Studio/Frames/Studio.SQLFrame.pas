{ ============================================================================
  Studio.SQLFrame - SQL Query Editor Frame
  
  Version: 1.0
  Description: SQL query editor with syntax highlighting, execution,
               result grid display, and query history management.
  ============================================================================ }

unit Studio.SQLFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.UITypes,
  System.Diagnostics,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Vcl.DBGrids,
  Data.DB,
  DBClient,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.DApt,
  UniBase.DB.DoQry,
  UniBase.Exceptions;

type
  TQueryHistoryItem = record
    SQL: string;
    ExecutedAt: TDateTime;
    Duration: Int64;  // milliseconds
    RowCount: Integer;
    Success: Boolean;
    ErrorMsg: string;
  end;

  TfraSQLEditor = class(TFrame)
    pnlToolbar: TPanel;
    btnExecute: TButton;
    btnClear: TButton;
    lblStatus: TLabel;
    splMain: TSplitter;
    pnlEditor: TPanel;
    lblSQL: TLabel;
    mmoSQL: TMemo;
    pnlResults: TPanel;
    pnlResultsHeader: TPanel;
    lblResults: TLabel;
    cboResultLimit: TComboBox;
    lblLimit: TLabel;
    pgcResults: TPageControl;
    tabGrid: TTabSheet;
    tabMessages: TTabSheet;
    tabHistory: TTabSheet;
    grdResults: TStringGrid;
    mmoMessages: TMemo;
    lvHistory: TListView;
    btnExportCSV: TButton;
    procedure btnExecuteClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure mmoSQLKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lvHistoryDblClick(Sender: TObject);
    procedure btnExportCSVClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    FQuery: TFDQuery;
    FHistory: TList<TQueryHistoryItem>;
    FMaxHistoryCount: Integer;
    
    { DoQry integration }
    tabDoQry: TTabSheet;
    pnlDQTop: TPanel;
    lblDQProc: TLabel;
    edtDQProc: TEdit;
    lblDQTarget: TLabel;
    cboDQTarget: TComboBox;
    btnDQPreview: TButton;
    btnDQSelect: TButton;
    btnDQExec: TButton;
    lblDQStatus: TLabel;
    mmoDQParams: TMemo;
    mmoDQResult: TMemo;
    
    procedure ExecuteQuery;
    procedure DisplayResults(AQuery: TFDQuery);
    procedure DisplayError(const AError: string);
    procedure AddToHistory(const ASQL: string; ADuration: Int64; 
      ARowCount: Integer; ASuccess: Boolean; const AError: string);
    procedure RefreshHistoryList;
    procedure SetStatus(const AText: string; AIsError: Boolean = False);
    function GetResultLimit: Integer;
    procedure ClearResults;
    procedure ApplySQLHighlighting;
    
    { DoQry helpers }
    procedure InitDoQryTab;
    procedure btnDQPreviewClick(Sender: TObject);
    procedure btnDQSelectClick(Sender: TObject);
    procedure btnDQExecClick(Sender: TObject);
    procedure DoPreviewDoQry;
    procedure DoRunDoQry(const AIsSelect: Boolean);
    function GetSetting(const AKey, ADefault: string): string;
    function CreateBusinessConnection(const ATarget: string; out ADBType: TUniDBType): TFDConnection;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

uses
  System.IOUtils,
  System.StrUtils,
  Vcl.Clipbrd
  {$IFDEF MSWINDOWS}
  , UniBase.Security.DPAPI
  {$ENDIF};

const
  SQL_KEYWORDS: array[0..49] of string = (
    'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'NOT', 'IN', 'LIKE',
    'ORDER', 'BY', 'ASC', 'DESC', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET',
    'INSERT', 'INTO', 'VALUES', 'UPDATE', 'SET', 'DELETE',
    'CREATE', 'TABLE', 'INDEX', 'VIEW', 'DROP', 'ALTER', 'ADD',
    'PRIMARY', 'KEY', 'FOREIGN', 'REFERENCES', 'UNIQUE', 'DEFAULT',
    'NULL', 'NOT', 'EXISTS', 'AS', 'JOIN', 'LEFT', 'RIGHT', 'INNER',
    'OUTER', 'ON', 'UNION', 'ALL', 'DISTINCT', 'COUNT', 'SUM'
  );

function ResolveStoredCredentialValue(const StoredValue: string): string;
var
  TargetName: string;
begin
  Result := StoredValue;
  if not StartsText('credman:', Trim(Result)) then
    Exit;

  TargetName := Copy(Trim(Result), Length('credman:') + 1, MaxInt);
  if TargetName = '' then
    Exit('');

  {$IFDEF MSWINDOWS}
  Result := TCredentialManager.GetCredential(TargetName, '');
  {$ELSE}
  Result := '';
  {$ENDIF}
end;

{ TfraSQLEditor }

constructor TfraSQLEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHistory := TList<TQueryHistoryItem>.Create;
  FMaxHistoryCount := 100;
  
  // Initialize result grid
  grdResults.ColCount := 1;
  grdResults.RowCount := 2;
  grdResults.FixedRows := 1;
  grdResults.FixedCols := 0;
  grdResults.DefaultRowHeight := 22;
  grdResults.Options := grdResults.Options + [goRowSelect, goColSizing, goThumbTracking];
  
  // Initialize history list view
  with lvHistory.Columns.Add do
  begin
    Caption := 'Time';
    Width := 140;
  end;
  with lvHistory.Columns.Add do
  begin
    Caption := 'Duration';
    Width := 80;
  end;
  with lvHistory.Columns.Add do
  begin
    Caption := 'Rows';
    Width := 60;
  end;
  with lvHistory.Columns.Add do
  begin
    Caption := 'Status';
    Width := 60;
  end;
  with lvHistory.Columns.Add do
  begin
    Caption := 'SQL';
    Width := 400;
  end;
  lvHistory.ViewStyle := vsReport;
  lvHistory.RowSelect := True;
  lvHistory.ReadOnly := True;
  
  // Initialize limit combo
  cboResultLimit.Items.Add('100');
  cboResultLimit.Items.Add('500');
  cboResultLimit.Items.Add('1000');
  cboResultLimit.Items.Add('5000');
  cboResultLimit.Items.Add('All');
  cboResultLimit.ItemIndex := 0;
  
  // Initialize messages
  mmoMessages.ReadOnly := True;
  mmoMessages.ScrollBars := ssBoth;
  mmoMessages.Font.Name := 'Consolas';
  mmoMessages.Font.Size := 10;
  
  // SQL editor font
  mmoSQL.Font.Name := 'Consolas';
  mmoSQL.Font.Size := 11;
  mmoSQL.ScrollBars := ssBoth;
  mmoSQL.WantTabs := True;
  
  // Initialize DoQry integration tab
  InitDoQryTab;
  
  SetStatus('Ready - Open a database and enter SQL query');
end;

destructor TfraSQLEditor.Destroy;
begin
  FQuery.Free;
  FHistory.Free;
  inherited;
end;

procedure TfraSQLEditor.InitDoQryTab;
begin
  tabDoQry := TTabSheet.Create(pgcResults);
  tabDoQry.PageControl := pgcResults;
  tabDoQry.Caption := 'DoQry';
  
  // Top panel (ProcName + Target + Buttons + Status)
  pnlDQTop := TPanel.Create(Self);
  pnlDQTop.Parent := tabDoQry;
  pnlDQTop.Align := alTop;
  pnlDQTop.Height := 80;
  pnlDQTop.BevelOuter := bvNone;
  
  lblDQProc := TLabel.Create(Self);
  lblDQProc.Parent := pnlDQTop;
  lblDQProc.SetBounds(8, 8, 60, 16);
  lblDQProc.Caption := 'Proc:';
  
  edtDQProc := TEdit.Create(Self);
  edtDQProc.Parent := pnlDQTop;
  edtDQProc.SetBounds(70, 4, 220, 24);
  
  lblDQTarget := TLabel.Create(Self);
  lblDQTarget.Parent := pnlDQTop;
  lblDQTarget.SetBounds(300, 8, 70, 16);
  lblDQTarget.Caption := 'Target DB:';
  
  cboDQTarget := TComboBox.Create(Self);
  cboDQTarget.Parent := pnlDQTop;
  cboDQTarget.SetBounds(370, 4, 150, 24);
  cboDQTarget.Style := csDropDownList;
  cboDQTarget.Items.Add('DB2 (SQLite)');
  cboDQTarget.Items.Add('DB3 (PostgreSQL)');
  cboDQTarget.ItemIndex := 0;
  
  btnDQPreview := TButton.Create(Self);
  btnDQPreview.Parent := pnlDQTop;
  btnDQPreview.SetBounds(530, 4, 90, 24);
  btnDQPreview.Caption := 'Preview SQL';
  btnDQPreview.OnClick := btnDQPreviewClick;
  
  btnDQSelect := TButton.Create(Self);
  btnDQSelect.Parent := pnlDQTop;
  btnDQSelect.SetBounds(630, 4, 90, 24);
  btnDQSelect.Caption := 'Run Select';
  btnDQSelect.OnClick := btnDQSelectClick;
  
  btnDQExec := TButton.Create(Self);
  btnDQExec.Parent := pnlDQTop;
  btnDQExec.SetBounds(730, 4, 90, 24);
  btnDQExec.Caption := 'Run Exec';
  btnDQExec.OnClick := btnDQExecClick;
  
  lblDQStatus := TLabel.Create(Self);
  lblDQStatus.Parent := pnlDQTop;
  lblDQStatus.SetBounds(8, 50, 820, 16);
  lblDQStatus.Caption := 'Ready';
  lblDQStatus.Font.Color := clGray;
  
  // Params JSON memo (left)
  mmoDQParams := TMemo.Create(Self);
  mmoDQParams.Parent := tabDoQry;
  mmoDQParams.Align := alLeft;
  mmoDQParams.Width := tabDoQry.ClientWidth div 2;
  mmoDQParams.ScrollBars := ssBoth;
  mmoDQParams.WordWrap := False;
  mmoDQParams.Font.Name := 'Consolas';
  mmoDQParams.Font.Size := 10;
  mmoDQParams.Text := '{"sample": "value"}';
  
  // Result memo (right)
  mmoDQResult := TMemo.Create(Self);
  mmoDQResult.Parent := tabDoQry;
  mmoDQResult.Align := alClient;
  mmoDQResult.ScrollBars := ssBoth;
  mmoDQResult.WordWrap := False;
  mmoDQResult.Font.Name := 'Consolas';
  mmoDQResult.Font.Size := 10;
end;

procedure TfraSQLEditor.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  // Recreate query with new connection
  FreeAndNil(FQuery);
  if Assigned(FConnection) and FConnection.Connected then
  begin
    FQuery := TFDQuery.Create(nil);
    FQuery.Connection := FConnection;
    SetStatus('Connected - Ready to execute queries');
  end
  else
    SetStatus('No database connection', True);
end;

procedure TfraSQLEditor.RefreshData;
begin
  // Refresh history display
  RefreshHistoryList;
  
  if Assigned(FConnection) and FConnection.Connected then
    SetStatus('Connected - Ready to execute queries')
  else
    SetStatus('No database connection', True);
end;

procedure TfraSQLEditor.btnDQPreviewClick(Sender: TObject);
begin
  DoPreviewDoQry;
end;

procedure TfraSQLEditor.btnDQSelectClick(Sender: TObject);
begin
  DoRunDoQry(True);
end;

procedure TfraSQLEditor.btnDQExecClick(Sender: TObject);
begin
  DoRunDoQry(False);
end;

procedure TfraSQLEditor.ExecuteQuery;
var
  SQL: string;
  Stopwatch: TStopwatch;
  Duration: Int64;
  RowCount: Integer;
  Limit: Integer;
begin
  if not Assigned(FQuery) then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;
  
  SQL := Trim(mmoSQL.Text);
  if SQL = '' then
  begin
    SetStatus('Please enter a SQL query', True);
    Exit;
  end;
  
  // Get result limit
  Limit := GetResultLimit;
  
  // Add LIMIT clause if needed (for SELECT queries without existing LIMIT)
  if (Limit > 0) and 
     (Pos('SELECT', UpperCase(SQL)) = 1) and 
     (Pos('LIMIT', UpperCase(SQL)) = 0) then
  begin
    SQL := SQL + ' LIMIT ' + IntToStr(Limit);
  end;
  
  ClearResults;
  SetStatus('Executing query...');
  Application.ProcessMessages;
  
  Stopwatch := TStopwatch.StartNew;
  try
    FQuery.Close;
    FQuery.SQL.Text := SQL;
    
    // Check if it's a SELECT query
    if Pos('SELECT', UpperCase(Trim(mmoSQL.Text))) = 1 then
    begin
      FQuery.Open;
      RowCount := FQuery.RecordCount;
      Duration := Stopwatch.ElapsedMilliseconds;
      
      DisplayResults(FQuery);
      AddToHistory(mmoSQL.Text, Duration, RowCount, True, '');
      SetStatus(Format('Query executed successfully - %d rows returned in %d ms', 
        [RowCount, Duration]));
      
      // Switch to results tab
      pgcResults.ActivePage := tabGrid;
    end
    else
    begin
      // Execute non-SELECT statement
      FQuery.ExecSQL;
      RowCount := FQuery.RowsAffected;
      Duration := Stopwatch.ElapsedMilliseconds;
      
      AddToHistory(mmoSQL.Text, Duration, RowCount, True, '');
      SetStatus(Format('Query executed successfully - %d rows affected in %d ms', 
        [RowCount, Duration]));
      
      // Show message
      mmoMessages.Lines.Add(Format('[%s] Query executed successfully', 
        [FormatDateTime('hh:nn:ss', Now)]));
      mmoMessages.Lines.Add(Format('Rows affected: %d', [RowCount]));
      mmoMessages.Lines.Add(Format('Duration: %d ms', [Duration]));
      mmoMessages.Lines.Add('');
      
      pgcResults.ActivePage := tabMessages;
    end;
  except
    on E: Exception do
    begin
      Duration := Stopwatch.ElapsedMilliseconds;
      DisplayError(E.Message);
      AddToHistory(mmoSQL.Text, Duration, 0, False, E.Message);
      SetStatus('Query failed: ' + E.Message, True);
    end;
  end;
end;

procedure TfraSQLEditor.DisplayResults(AQuery: TFDQuery);
var
  I, J: Integer;
  Field: TField;
begin
  if not AQuery.Active or (AQuery.FieldCount = 0) then
  begin
    grdResults.ColCount := 1;
    grdResults.RowCount := 2;
    grdResults.Cells[0, 0] := 'No data';
    Exit;
  end;
  
  // Set up columns
  grdResults.ColCount := AQuery.FieldCount;
  grdResults.RowCount := AQuery.RecordCount + 1;
  
  // Set column headers
  for I := 0 to AQuery.FieldCount - 1 do
  begin
    Field := AQuery.Fields[I];
    grdResults.Cells[I, 0] := Field.FieldName;
    
    // Set column width based on field type
    case Field.DataType of
      ftInteger, ftSmallint, ftWord, ftLargeint:
        grdResults.ColWidths[I] := 80;
      ftFloat, ftCurrency, ftBCD:
        grdResults.ColWidths[I] := 100;
      ftDate, ftTime, ftDateTime:
        grdResults.ColWidths[I] := 140;
      ftBoolean:
        grdResults.ColWidths[I] := 60;
      ftMemo, ftWideMemo:
        grdResults.ColWidths[I] := 200;
      else
        grdResults.ColWidths[I] := 150;
    end;
  end;
  
  // Fill data rows
  AQuery.First;
  J := 1;
  while not AQuery.Eof do
  begin
    for I := 0 to AQuery.FieldCount - 1 do
    begin
      Field := AQuery.Fields[I];
      if Field.IsNull then
        grdResults.Cells[I, J] := '(NULL)'
      else if Field.DataType in [ftMemo, ftWideMemo, ftBlob] then
        grdResults.Cells[I, J] := '(BLOB)'
      else
        grdResults.Cells[I, J] := Field.AsString;
    end;
    Inc(J);
    AQuery.Next;
  end;
end;

procedure TfraSQLEditor.DoPreviewDoQry;
var
  ProcName, ParamsJson, Target: string;
  Conn: TFDConnection;
  DBType: TUniDBType;
  Ctx: TUniQueryContext;
  PreviewSQL: string;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    lblDQStatus.Caption := 'No config.db connection - open a UniBase database first';
    lblDQStatus.Font.Color := clRed;
    Exit;
  end;

  ProcName := Trim(edtDQProc.Text);
  if ProcName = '' then
  begin
    lblDQStatus.Caption := 'Proc name cannot be empty';
    lblDQStatus.Font.Color := clRed;
    Exit;
  end;

  ParamsJson := Trim(mmoDQParams.Text);
  Target := cboDQTarget.Text;

  mmoDQResult.Clear;
  lblDQStatus.Caption := 'Generating SQL preview...';
  lblDQStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  UniDbInit(ExtractFilePath(FConnection.Params.Database));

  Conn := nil;
  try
    Conn := CreateBusinessConnection(Target, DBType);
    if Conn = nil then
      raise EDatabaseException.Create('Failed to create business DB connection');

    Ctx := UniDbMakeContext(Conn, DBType, 30, UniDbNewCorrelationId);
    PreviewSQL := UniDbBuildSqlPreview(ProcName, ParamsJson, Ctx);
    mmoDQResult.Lines.Text := PreviewSQL;
    lblDQStatus.Caption := 'SQL preview generated';
    lblDQStatus.Font.Color := clGreen;
  except
    on E: Exception do
    begin
      mmoDQResult.Lines.Add('[ERROR] ' + E.ClassName + ': ' + E.Message);
      lblDQStatus.Caption := 'Error: ' + E.Message;
      lblDQStatus.Font.Color := clRed;
    end;
  end;

  if Assigned(Conn) then
    Conn.Free;
end;

procedure TfraSQLEditor.DoRunDoQry(const AIsSelect: Boolean);
var
  ProcName, ParamsJson, Target: string;
  Conn: TFDConnection;
  DBType: TUniDBType;
  Ctx: TUniQueryContext;
  Data: TClientDataSet;
  RowCount: Integer;
  I, Col: Integer;
  Line: string;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    lblDQStatus.Caption := 'No config.db connection - open a UniBase database first';
    lblDQStatus.Font.Color := clRed;
    Exit;
  end;

  ProcName := Trim(edtDQProc.Text);
  if ProcName = '' then
  begin
    lblDQStatus.Caption := 'Proc name cannot be empty';
    lblDQStatus.Font.Color := clRed;
    Exit;
  end;

  ParamsJson := Trim(mmoDQParams.Text);
  Target := cboDQTarget.Text;

  mmoDQResult.Clear;
  lblDQStatus.Caption := 'Running...';
  lblDQStatus.Font.Color := clWindowText;
  Application.ProcessMessages;

  UniDbInit(ExtractFilePath(FConnection.Params.Database));

  Conn := nil;
  Data := nil;
  try
    Conn := CreateBusinessConnection(Target, DBType);
    if Conn = nil then
      raise EDatabaseException.Create('Failed to create business DB connection');

    Ctx := UniDbMakeContext(Conn, DBType, 30, UniDbNewCorrelationId);

    if AIsSelect then
    begin
      Data := TClientDataSet.Create(nil);
      RowCount := UniDbSelect(ProcName, ParamsJson, Data, Ctx);
      mmoDQResult.Lines.Add(Format('Rows: %d', [RowCount]));
      mmoDQResult.Lines.Add('');

      if RowCount > 0 then
      begin
        // Header
        Line := '';
        for Col := 0 to Data.Fields.Count - 1 do
        begin
          if Col > 0 then Line := Line + #9;
          Line := Line + Data.Fields[Col].FieldName;
        end;
        mmoDQResult.Lines.Add(Line);

        // Rows
        Data.First;
        I := 0;
        while (not Data.Eof) and (I < 50) do
        begin
          Line := '';
          for Col := 0 to Data.Fields.Count - 1 do
          begin
            if Col > 0 then Line := Line + #9;
            Line := Line + Data.Fields[Col].AsString;
          end;
          mmoDQResult.Lines.Add(Line);
          Inc(I);
          Data.Next;
        end;
        if RowCount > 50 then
          mmoDQResult.Lines.Add(Format('... (%d more rows truncated)', [RowCount - 50]));
      end;
      lblDQStatus.Caption := 'Select completed';
      lblDQStatus.Font.Color := clGreen;
    end
    else
    begin
      RowCount := UniDbExec(ProcName, ParamsJson, Ctx);
      mmoDQResult.Lines.Add(Format('Exec affected %d rows.', [RowCount]));
      lblDQStatus.Caption := 'Exec completed';
      lblDQStatus.Font.Color := clGreen;
    end;
  except
    on E: Exception do
    begin
      mmoDQResult.Lines.Add('[ERROR] ' + E.ClassName + ': ' + E.Message);
      lblDQStatus.Caption := 'Error: ' + E.Message;
      lblDQStatus.Font.Color := clRed;
    end;
  end;

  if Assigned(Data) then
    Data.Free;
  if Assigned(Conn) then
    Conn.Free;
end;

function TfraSQLEditor.GetSetting(const AKey, ADefault: string): string;
var
  Q: TFDQuery;
begin
  Result := ADefault;
  if (FConnection = nil) or (not FConnection.Connected) then
    Exit;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
    Q.ParamByName('Key').AsString := AKey;
    Q.Open;
    if not Q.Eof then
      Result := Q.FieldByName('Value').AsString;
  except
    // ignore errors, keep default
  end;
  Q.Free;
end;

function TfraSQLEditor.CreateBusinessConnection(const ATarget: string; out ADBType: TUniDBType): TFDConnection;
var
  DBPath, FullPath: string;
  Server, Database, UserName, Password: string;
  Port: Integer;
begin
  Result := nil;

  if Pos('DB2', ATarget) = 1 then
  begin
    // SQLite business DB
    DBPath := GetSetting('DB2.Path', '');
    if DBPath = '' then
      raise EDatabaseException.Create('DB2.Path not configured in Settings');

    if TPath.IsPathRooted(DBPath) then
      FullPath := DBPath
    else
      // Interpret as relative to current config.db folder
      FullPath := TPath.Combine(ExtractFilePath(FConnection.Params.Database), DBPath);

    Result := TFDConnection.Create(nil);
    Result.DriverName := 'SQLite';
    Result.Params.Database := FullPath;
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.Params.Values['Synchronous'] := 'Normal';
    Result.LoginPrompt := False;
    Result.Open;
    ADBType := udbSQLite;
  end
  else
  begin
    // PostgreSQL business DB (DB3)
    Server   := GetSetting('DB3.Server', '127.0.0.1');
    Database := GetSetting('DB3.Database', 'postgres');
    UserName := GetSetting('DB3.User', 'postgres');
    Password := ResolveStoredCredentialValue(GetSetting('DB3.Password', ''));
    Port     := StrToIntDef(GetSetting('DB3.Port', '5432'), 5432);

    Result := TFDConnection.Create(nil);
    Result.DriverName := 'PG';
    Result.Params.Values['Server']    := Server;
    Result.Params.Values['Database']  := Database;
    Result.Params.Values['User_Name'] := UserName;
    Result.Params.Values['Password']  := Password;
    Result.Params.Values['Port']      := IntToStr(Port);
    Result.LoginPrompt := False;
    Result.Open;
    ADBType := udbPostgreSQL;
  end;
end;

procedure TfraSQLEditor.DisplayError(const AError: string);
begin
  mmoMessages.Lines.Add('[ERROR] ' + AError);
  mmoMessages.Lines.Add(AError);
  mmoMessages.Lines.Add('');
  pgcResults.ActivePage := tabMessages;
end;

procedure TfraSQLEditor.AddToHistory(const ASQL: string; ADuration: Int64;
  ARowCount: Integer; ASuccess: Boolean; const AError: string);
var
  Item: TQueryHistoryItem;
begin
  Item.SQL := ASQL;
  Item.ExecutedAt := Now;
  Item.Duration := ADuration;
  Item.RowCount := ARowCount;
  Item.Success := ASuccess;
  Item.ErrorMsg := AError;
  
  // Insert at beginning
  FHistory.Insert(0, Item);
  
  // Trim history if needed
  while FHistory.Count > FMaxHistoryCount do
    FHistory.Delete(FHistory.Count - 1);
  
  RefreshHistoryList;
end;

procedure TfraSQLEditor.RefreshHistoryList;
var
  I: Integer;
  Item: TQueryHistoryItem;
  LI: TListItem;
  SQLPreview: string;
begin
  lvHistory.Items.BeginUpdate;
  try
    lvHistory.Items.Clear;
    
    for I := 0 to FHistory.Count - 1 do
    begin
      Item := FHistory[I];
      LI := lvHistory.Items.Add;
      LI.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', Item.ExecutedAt);
      LI.SubItems.Add(Format('%d ms', [Item.Duration]));
      LI.SubItems.Add(IntToStr(Item.RowCount));
      
      if Item.Success then
        LI.SubItems.Add('OK')
      else
        LI.SubItems.Add('ERROR');
      
      // Truncate long SQL for display
      SQLPreview := StringReplace(Item.SQL, #13#10, ' ', [rfReplaceAll]);
      SQLPreview := StringReplace(SQLPreview, #10, ' ', [rfReplaceAll]);
      if Length(SQLPreview) > 100 then
        SQLPreview := Copy(SQLPreview, 1, 100) + '...';
      LI.SubItems.Add(SQLPreview);
      
      LI.Data := Pointer(I);
    end;
  finally
    lvHistory.Items.EndUpdate;
  end;
end;

procedure TfraSQLEditor.SetStatus(const AText: string; AIsError: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

function TfraSQLEditor.GetResultLimit: Integer;
var
  S: string;
begin
  S := cboResultLimit.Text;
  if SameText(S, 'All') then
    Result := 0
  else
    Result := StrToIntDef(S, 100);
end;

procedure TfraSQLEditor.ClearResults;
begin
  grdResults.ColCount := 1;
  grdResults.RowCount := 2;
  grdResults.Cells[0, 0] := '';
  grdResults.Cells[0, 1] := '';
end;

procedure TfraSQLEditor.ApplySQLHighlighting;
begin
  // Note: Full syntax highlighting would require a custom control or RichEdit
  // For simplicity, we keep the basic TMemo for now
  // Future enhancement: use TSynEdit or similar for full highlighting
end;

procedure TfraSQLEditor.btnExecuteClick(Sender: TObject);
begin
  ExecuteQuery;
end;

procedure TfraSQLEditor.btnClearClick(Sender: TObject);
begin
  mmoSQL.Clear;
  ClearResults;
  mmoMessages.Clear;
  SetStatus('Ready');
end;

procedure TfraSQLEditor.mmoSQLKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  // F5 or Ctrl+Enter to execute
  if (Key = VK_F5) or ((Key = VK_RETURN) and (ssCtrl in Shift)) then
  begin
    ExecuteQuery;
    Key := 0;
  end
  // Ctrl+A to select all
  else if (Key = Ord('A')) and (ssCtrl in Shift) then
  begin
    mmoSQL.SelectAll;
    Key := 0;
  end;
end;

procedure TfraSQLEditor.lvHistoryDblClick(Sender: TObject);
var
  Idx: Integer;
begin
  if lvHistory.Selected <> nil then
  begin
    Idx := Integer(lvHistory.Selected.Data);
    if (Idx >= 0) and (Idx < FHistory.Count) then
    begin
      mmoSQL.Text := FHistory[Idx].SQL;
      pgcResults.ActivePage := tabGrid;
    end;
  end;
end;

procedure TfraSQLEditor.btnExportCSVClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  CSV: TStringList;
  I, J: Integer;
  Row: string;
begin
  if grdResults.RowCount <= 1 then
  begin
    SetStatus('No data to export', True);
    Exit;
  end;
  
  SaveDlg := TSaveDialog.Create(nil);
  try
    SaveDlg.Filter := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
    SaveDlg.DefaultExt := 'csv';
    SaveDlg.FileName := 'query_results.csv';
    
    if SaveDlg.Execute then
    begin
      CSV := TStringList.Create;
      try
        // Export all rows including header
        for I := 0 to grdResults.RowCount - 1 do
        begin
          Row := '';
          for J := 0 to grdResults.ColCount - 1 do
          begin
            if J > 0 then
              Row := Row + ',';
            // Escape quotes and wrap in quotes
            Row := Row + '"' + StringReplace(grdResults.Cells[J, I], '"', '""', [rfReplaceAll]) + '"';
          end;
          CSV.Add(Row);
        end;
        
        CSV.SaveToFile(SaveDlg.FileName, TEncoding.UTF8);
        SetStatus(Format('Exported %d rows to %s', [grdResults.RowCount - 1, SaveDlg.FileName]));
      finally
        CSV.Free;
      end;
    end;
  finally
    SaveDlg.Free;
  end;
end;

end.
