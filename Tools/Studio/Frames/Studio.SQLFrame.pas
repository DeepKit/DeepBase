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
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.DApt;

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
  Vcl.Clipbrd;

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
  
  SetStatus('Ready - Open a database and enter SQL query');
end;

destructor TfraSQLEditor.Destroy;
begin
  FQuery.Free;
  FHistory.Free;
  inherited;
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

procedure TfraSQLEditor.DisplayError(const AError: string);
begin
  mmoMessages.Lines.Add(Format('[%s] ERROR:', [FormatDateTime('hh:nn:ss', Now)]));
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
