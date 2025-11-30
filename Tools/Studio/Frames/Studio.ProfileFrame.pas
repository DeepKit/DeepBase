{ ============================================================================
  Studio.ProfileFrame - Database Performance Analysis Frame
  
  Version: 1.0
  Description: Analyzes SQLite database performance including table statistics,
               query execution plans, and index optimization suggestions.
  ============================================================================ }

unit Studio.ProfileFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Types,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.UITypes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Grids,
  Data.DB,
  FireDAC.Comp.Client;

type
  TTableStats = record
    TableName: string;
    RowCount: Int64;
    PageCount: Int64;
    UnusedSpace: Int64;
    IndexCount: Integer;
    AvgRowSize: Double;
  end;

  TIndexInfo = record
    TableName: string;
    IndexName: string;
    IsUnique: Boolean;
    IsPrimary: Boolean;
    Columns: string;
    Used: Boolean;  // Approximate usage indicator
  end;

  TfraProfiler = class(TFrame)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    btnRefresh: TButton;
    btnAnalyze: TButton;
    pnlMain: TPanel;
    pgcMain: TPageControl;
    tabStats: TTabSheet;
    tabQueryPlan: TTabSheet;
    tabIndexes: TTabSheet;
    tabSuggestions: TTabSheet;
    { Stats tab }
    lvStats: TListView;
    pnlStatsFooter: TPanel;
    lblTotalRows: TLabel;
    lblTotalSize: TLabel;
    { Query Plan tab }
    pnlQueryTop: TPanel;
    lblQuery: TLabel;
    mmoQuery: TMemo;
    btnExplain: TButton;
    pnlQueryBottom: TPanel;
    lblPlan: TLabel;
    mmoExplain: TMemo;
    { Index tab }
    lvIndexes: TListView;
    pnlIndexFooter: TPanel;
    lblIndexCount: TLabel;
    { Suggestions tab }
    mmoSuggestions: TMemo;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    prgProgress: TProgressBar;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnAnalyzeClick(Sender: TObject);
    procedure btnExplainClick(Sender: TObject);
  private
    FConnection: TFDConnection;
    FTableStats: TList<TTableStats>;
    FIndexes: TList<TIndexInfo>;
    
    procedure LoadTableStats;
    procedure LoadIndexInfo;
    procedure AnalyzeDatabase;
    procedure GenerateSuggestions;
    procedure RefreshStatsView;
    procedure RefreshIndexView;
    procedure SetStatus(const AText: string; AIsError: Boolean = False);
    function FormatBytes(ABytes: Int64): string;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

{ TfraProfiler }

constructor TfraProfiler.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTableStats := TList<TTableStats>.Create;
  FIndexes := TList<TIndexInfo>.Create;
  
  // Initialize Stats ListView
  with lvStats.Columns.Add do
  begin
    Caption := 'Table';
    Width := 180;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := 'Rows';
    Width := 100;
    Alignment := taRightJustify;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := 'Size (est)';
    Width := 100;
    Alignment := taRightJustify;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := 'Avg Row';
    Width := 80;
    Alignment := taRightJustify;
  end;
  with lvStats.Columns.Add do
  begin
    Caption := 'Indexes';
    Width := 70;
    Alignment := taRightJustify;
  end;
  lvStats.ViewStyle := vsReport;
  lvStats.RowSelect := True;
  lvStats.ReadOnly := True;
  
  // Initialize Index ListView
  with lvIndexes.Columns.Add do
  begin
    Caption := 'Table';
    Width := 150;
  end;
  with lvIndexes.Columns.Add do
  begin
    Caption := 'Index Name';
    Width := 180;
  end;
  with lvIndexes.Columns.Add do
  begin
    Caption := 'Unique';
    Width := 60;
  end;
  with lvIndexes.Columns.Add do
  begin
    Caption := 'Primary';
    Width := 60;
  end;
  with lvIndexes.Columns.Add do
  begin
    Caption := 'Columns';
    Width := 250;
  end;
  lvIndexes.ViewStyle := vsReport;
  lvIndexes.RowSelect := True;
  lvIndexes.ReadOnly := True;
  
  // Query memo
  mmoQuery.Font.Name := 'Consolas';
  mmoQuery.Font.Size := 10;
  mmoQuery.ScrollBars := ssBoth;
  mmoQuery.WordWrap := False;
  
  // Explain output memo
  mmoExplain.Font.Name := 'Consolas';
  mmoExplain.Font.Size := 10;
  mmoExplain.ReadOnly := True;
  mmoExplain.ScrollBars := ssBoth;
  mmoExplain.WordWrap := False;
  
  // Suggestions memo
  mmoSuggestions.Font.Name := 'Segoe UI';
  mmoSuggestions.Font.Size := 10;
  mmoSuggestions.ReadOnly := True;
  mmoSuggestions.ScrollBars := ssVertical;
  mmoSuggestions.WordWrap := True;
  
  prgProgress.Visible := False;
  pgcMain.ActivePage := tabStats;
  
  SetStatus('Ready - Open a database to analyze');
end;

destructor TfraProfiler.Destroy;
begin
  FIndexes.Free;
  FTableStats.Free;
  inherited;
end;

procedure TfraProfiler.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  if Assigned(FConnection) and FConnection.Connected then
    SetStatus('Connected')
  else
    SetStatus('No database connection', True);
end;

procedure TfraProfiler.RefreshData;
begin
  LoadTableStats;
  LoadIndexInfo;
end;

procedure TfraProfiler.btnRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TfraProfiler.btnAnalyzeClick(Sender: TObject);
begin
  AnalyzeDatabase;
end;

procedure TfraProfiler.btnExplainClick(Sender: TObject);
var
  Query: TFDQuery;
  SQL: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;
  
  SQL := Trim(mmoQuery.Text);
  if SQL = '' then
  begin
    SetStatus('Enter a SQL query to explain', True);
    Exit;
  end;
  
  mmoExplain.Clear;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'EXPLAIN QUERY PLAN ' + SQL;
    
    try
      Query.Open;
      
      mmoExplain.Lines.Add('=== QUERY PLAN ===');
      mmoExplain.Lines.Add('');
      
      while not Query.Eof do
      begin
        mmoExplain.Lines.Add(Format('id=%d parent=%d notused=%d detail=%s', [
          Query.FieldByName('id').AsInteger,
          Query.FieldByName('parent').AsInteger,
          Query.FieldByName('notused').AsInteger,
          Query.FieldByName('detail').AsString
        ]));
        Query.Next;
      end;
      
      Query.Close;
      
      // Also show regular EXPLAIN
      mmoExplain.Lines.Add('');
      mmoExplain.Lines.Add('=== BYTECODE ===');
      mmoExplain.Lines.Add('');
      
      Query.SQL.Text := 'EXPLAIN ' + SQL;
      Query.Open;
      
      while not Query.Eof do
      begin
        mmoExplain.Lines.Add(Format('%4d | %-15s | %s | %s | %s | %s',
          [Query.Fields[0].AsInteger,
           Query.Fields[1].AsString,
           Query.Fields[2].AsString,
           Query.Fields[3].AsString,
           Query.Fields[4].AsString,
           Query.Fields[5].AsString]));
        Query.Next;
      end;
      
      SetStatus('Query plan generated');
    except
      on E: Exception do
      begin
        mmoExplain.Lines.Add('Error: ' + E.Message);
        SetStatus('Failed to explain query', True);
      end;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraProfiler.LoadTableStats;
var
  Query: TFDQuery;
  CountQuery: TFDQuery;
  TableName: string;
  Stats: TTableStats;
  TotalRows: Int64;
  TotalSize: Int64;
begin
  FTableStats.Clear;
  TotalRows := 0;
  TotalSize := 0;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  CountQuery := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    CountQuery.Connection := FConnection;
    
    // Get all tables
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' ' +
                      'AND name NOT LIKE ''sqlite_%'' ORDER BY name';
    Query.Open;
    
    while not Query.Eof do
    begin
      TableName := Query.FieldByName('name').AsString;
      
      Stats.TableName := TableName;
      Stats.RowCount := 0;
      Stats.PageCount := 0;
      Stats.UnusedSpace := 0;
      Stats.IndexCount := 0;
      Stats.AvgRowSize := 0;
      
      // Get row count
      try
        CountQuery.SQL.Text := Format('SELECT COUNT(*) AS cnt FROM [%s]', [TableName]);
        CountQuery.Open;
        Stats.RowCount := CountQuery.FieldByName('cnt').AsLargeInt;
        CountQuery.Close;
      except
        Stats.RowCount := -1;
      end;
      
      // Get index count
      try
        CountQuery.SQL.Text := Format(
          'SELECT COUNT(*) AS cnt FROM sqlite_master WHERE type=''index'' AND tbl_name=''%s''',
          [TableName]);
        CountQuery.Open;
        Stats.IndexCount := CountQuery.FieldByName('cnt').AsInteger;
        CountQuery.Close;
      except
        Stats.IndexCount := 0;
      end;
      
      // Estimate average row size (rough estimate based on schema)
      try
        CountQuery.SQL.Text := Format(
          'SELECT SUM(LENGTH(CAST([%s].* AS TEXT))) / COUNT(*) AS avg_size FROM [%0:s] WHERE EXISTS (SELECT 1 FROM [%0:s] LIMIT 1)',
          [TableName]);
        CountQuery.Open;
        if not CountQuery.FieldByName('avg_size').IsNull then
          Stats.AvgRowSize := CountQuery.FieldByName('avg_size').AsFloat
        else
          Stats.AvgRowSize := 0;
        CountQuery.Close;
      except
        Stats.AvgRowSize := 0;
      end;
      
      // Estimate size (rows * avg row size)
      if Stats.AvgRowSize > 0 then
        Stats.PageCount := Round(Stats.RowCount * Stats.AvgRowSize)
      else
        Stats.PageCount := Stats.RowCount * 100;  // Default estimate
      
      TotalRows := TotalRows + Stats.RowCount;
      TotalSize := TotalSize + Stats.PageCount;
      
      FTableStats.Add(Stats);
      Query.Next;
    end;
    
    // Sort by row count descending
    FTableStats.Sort(TComparer<TTableStats>.Construct(
      function(const L, R: TTableStats): Integer
      begin
        Result := CompareValue(R.RowCount, L.RowCount);
      end));
    
    RefreshStatsView;
    
    lblTotalRows.Caption := Format('Total Rows: %s', [FormatFloat('#,##0', TotalRows)]);
    lblTotalSize.Caption := Format('Estimated Size: %s', [FormatBytes(TotalSize)]);
    
    SetStatus(Format('Loaded stats for %d tables', [FTableStats.Count]));
  finally
    CountQuery.Free;
    Query.Free;
  end;
end;

procedure TfraProfiler.RefreshStatsView;
var
  I: Integer;
  Stats: TTableStats;
  Item: TListItem;
begin
  lvStats.Items.BeginUpdate;
  try
    lvStats.Items.Clear;
    
    for I := 0 to FTableStats.Count - 1 do
    begin
      Stats := FTableStats[I];
      Item := lvStats.Items.Add;
      Item.Caption := Stats.TableName;
      
      if Stats.RowCount >= 0 then
        Item.SubItems.Add(FormatFloat('#,##0', Stats.RowCount))
      else
        Item.SubItems.Add('?');
      
      Item.SubItems.Add(FormatBytes(Stats.PageCount));
      
      if Stats.AvgRowSize > 0 then
        Item.SubItems.Add(Format('%.0f B', [Stats.AvgRowSize]))
      else
        Item.SubItems.Add('-');
      
      Item.SubItems.Add(IntToStr(Stats.IndexCount));
    end;
  finally
    lvStats.Items.EndUpdate;
  end;
end;

procedure TfraProfiler.LoadIndexInfo;
var
  Query: TFDQuery;
  IndexQuery: TFDQuery;
  TableName, IndexName: string;
  IndexInfo: TIndexInfo;
begin
  FIndexes.Clear;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  IndexQuery := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    IndexQuery.Connection := FConnection;
    
    // Get all indexes
    Query.SQL.Text := 'SELECT tbl_name, name, sql FROM sqlite_master ' +
                      'WHERE type=''index'' AND name NOT LIKE ''sqlite_%'' ' +
                      'ORDER BY tbl_name, name';
    Query.Open;
    
    while not Query.Eof do
    begin
      TableName := Query.FieldByName('tbl_name').AsString;
      IndexName := Query.FieldByName('name').AsString;
      
      IndexInfo.TableName := TableName;
      IndexInfo.IndexName := IndexName;
      IndexInfo.IsUnique := Pos('UNIQUE', UpperCase(Query.FieldByName('sql').AsString)) > 0;
      IndexInfo.IsPrimary := Pos('PRIMARY', UpperCase(IndexName)) > 0;
      IndexInfo.Columns := '';
      IndexInfo.Used := True;  // Default assumption
      
      // Get index columns
      try
        IndexQuery.SQL.Text := Format('PRAGMA index_info(''%s'')', [IndexName]);
        IndexQuery.Open;
        
        while not IndexQuery.Eof do
        begin
          if IndexInfo.Columns <> '' then
            IndexInfo.Columns := IndexInfo.Columns + ', ';
          IndexInfo.Columns := IndexInfo.Columns + IndexQuery.FieldByName('name').AsString;
          IndexQuery.Next;
        end;
        IndexQuery.Close;
      except
        IndexInfo.Columns := '?';
      end;
      
      FIndexes.Add(IndexInfo);
      Query.Next;
    end;
    
    RefreshIndexView;
    lblIndexCount.Caption := Format('Total Indexes: %d', [FIndexes.Count]);
  finally
    IndexQuery.Free;
    Query.Free;
  end;
end;

procedure TfraProfiler.RefreshIndexView;
var
  I: Integer;
  IndexInfo: TIndexInfo;
  Item: TListItem;
begin
  lvIndexes.Items.BeginUpdate;
  try
    lvIndexes.Items.Clear;
    
    for I := 0 to FIndexes.Count - 1 do
    begin
      IndexInfo := FIndexes[I];
      Item := lvIndexes.Items.Add;
      Item.Caption := IndexInfo.TableName;
      Item.SubItems.Add(IndexInfo.IndexName);
      
      if IndexInfo.IsUnique then
        Item.SubItems.Add('Yes')
      else
        Item.SubItems.Add('');
      
      if IndexInfo.IsPrimary then
        Item.SubItems.Add('Yes')
      else
        Item.SubItems.Add('');
      
      Item.SubItems.Add(IndexInfo.Columns);
    end;
  finally
    lvIndexes.Items.EndUpdate;
  end;
end;

procedure TfraProfiler.AnalyzeDatabase;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;
  
  prgProgress.Visible := True;
  prgProgress.Position := 0;
  SetStatus('Analyzing database...');
  Application.ProcessMessages;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // Run ANALYZE to update statistics
    prgProgress.Position := 30;
    Application.ProcessMessages;
    
    try
      Query.SQL.Text := 'ANALYZE';
      Query.ExecSQL;
      
      prgProgress.Position := 60;
      Application.ProcessMessages;
      
      // Vacuum to reclaim space (optional, can be slow)
      // Query.SQL.Text := 'VACUUM';
      // Query.ExecSQL;
      
      prgProgress.Position := 80;
      Application.ProcessMessages;
      
      // Refresh stats after analysis
      LoadTableStats;
      LoadIndexInfo;
      GenerateSuggestions;
      
      prgProgress.Position := 100;
      SetStatus('Analysis complete');
    except
      on E: Exception do
        SetStatus('Analysis failed: ' + E.Message, True);
    end;
  finally
    Query.Free;
    prgProgress.Visible := False;
  end;
end;

procedure TfraProfiler.GenerateSuggestions;
var
  I: Integer;
  Stats: TTableStats;
  IndexInfo: TIndexInfo;
  Suggestions: TStringList;
  TablesWithoutIndex: Integer;
  LargeTables: Integer;
begin
  Suggestions := TStringList.Create;
  try
    Suggestions.Add('=== Database Performance Suggestions ===');
    Suggestions.Add('');
    
    TablesWithoutIndex := 0;
    LargeTables := 0;
    
    // Check tables without indexes
    for I := 0 to FTableStats.Count - 1 do
    begin
      Stats := FTableStats[I];
      
      if Stats.IndexCount = 0 then
      begin
        Inc(TablesWithoutIndex);
        if Stats.RowCount > 100 then
        begin
          Suggestions.Add(Format('⚠ Table "%s" has %d rows but no indexes.',
            [Stats.TableName, Stats.RowCount]));
          Suggestions.Add('  Consider adding an index on frequently queried columns.');
          Suggestions.Add('');
        end;
      end;
      
      if Stats.RowCount > 10000 then
      begin
        Inc(LargeTables);
        Suggestions.Add(Format('📊 Large table "%s" with %s rows.',
          [Stats.TableName, FormatFloat('#,##0', Stats.RowCount)]));
        Suggestions.Add('  Ensure proper indexes exist for common queries.');
        Suggestions.Add('');
      end;
    end;
    
    // Summary
    Suggestions.Add('--- Summary ---');
    Suggestions.Add(Format('Total Tables: %d', [FTableStats.Count]));
    Suggestions.Add(Format('Tables without indexes: %d', [TablesWithoutIndex]));
    Suggestions.Add(Format('Large tables (>10K rows): %d', [LargeTables]));
    Suggestions.Add(Format('Total indexes: %d', [FIndexes.Count]));
    Suggestions.Add('');
    
    // General recommendations
    Suggestions.Add('--- General Recommendations ---');
    Suggestions.Add('');
    Suggestions.Add('1. Use EXPLAIN QUERY PLAN to analyze slow queries');
    Suggestions.Add('2. Add indexes on columns used in WHERE, JOIN, and ORDER BY');
    Suggestions.Add('3. Avoid SELECT * - specify only needed columns');
    Suggestions.Add('4. Use transactions for batch operations');
    Suggestions.Add('5. Run ANALYZE periodically to update query statistics');
    Suggestions.Add('6. Consider VACUUM to reclaim unused space');
    
    // Check for potential issues
    if TablesWithoutIndex > FTableStats.Count div 2 then
    begin
      Suggestions.Add('');
      Suggestions.Add('⚠ WARNING: More than half of tables have no indexes!');
      Suggestions.Add('  This may significantly impact query performance.');
    end;
    
    mmoSuggestions.Lines.Assign(Suggestions);
  finally
    Suggestions.Free;
  end;
end;

procedure TfraProfiler.SetStatus(const AText: string; AIsError: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

function TfraProfiler.FormatBytes(ABytes: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.2f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.2f KB', [ABytes / KB])
  else
    Result := Format('%d B', [ABytes]);
end;

end.
