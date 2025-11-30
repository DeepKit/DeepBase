{ ============================================================================
  Studio.SchemaFrame - Database Schema Viewer Frame
  
  Version: 1.0
  Description: Displays database schema including tables, columns, indexes,
               and foreign key relationships in a visual tree structure.
  ============================================================================ }

unit Studio.SchemaFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
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
  FireDAC.Comp.Client,
  FireDAC.Stan.Param;

type
  TColumnInfo = record
    Name: string;
    DataType: string;
    NotNull: Boolean;
    DefaultValue: string;
    IsPrimaryKey: Boolean;
  end;

  TIndexInfo = record
    Name: string;
    IsUnique: Boolean;
    Columns: string;
  end;

  TForeignKeyInfo = record
    Name: string;
    FromColumns: string;
    ToTable: string;
    ToColumns: string;
    OnUpdate: string;
    OnDelete: string;
  end;

  TfraSchemaViewer = class(TFrame)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    btnRefresh: TButton;
    splMain: TSplitter;
    pnlLeft: TPanel;
    lblTables: TLabel;
    tvSchema: TTreeView;
    pnlRight: TPanel;
    pgcDetails: TPageControl;
    tabColumns: TTabSheet;
    tabIndexes: TTabSheet;
    tabForeignKeys: TTabSheet;
    tabDDL: TTabSheet;
    grdColumns: TStringGrid;
    grdIndexes: TStringGrid;
    grdForeignKeys: TStringGrid;
    mmoDDL: TMemo;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    procedure btnRefreshClick(Sender: TObject);
    procedure tvSchemaChange(Sender: TObject; Node: TTreeNode);
  private
    FConnection: TFDConnection;
    FTableNames: TStringList;
    FSelectedTable: string;
    
    procedure LoadSchema;
    procedure LoadTableDetails(const ATableName: string);
    procedure LoadColumns(const ATableName: string);
    procedure LoadIndexes(const ATableName: string);
    procedure LoadForeignKeys(const ATableName: string);
    procedure LoadDDL(const ATableName: string);
    procedure SetStatus(const AText: string; AIsError: Boolean = False);
    procedure InitGrids;
    procedure ClearDetails;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

{ TfraSchemaViewer }

constructor TfraSchemaViewer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTableNames := TStringList.Create;
  FTableNames.Sorted := True;
  FSelectedTable := '';
  
  InitGrids;
  
  // DDL memo settings
  mmoDDL.ReadOnly := True;
  mmoDDL.Font.Name := 'Consolas';
  mmoDDL.Font.Size := 10;
  mmoDDL.ScrollBars := ssBoth;
  mmoDDL.WordWrap := False;
  
  SetStatus('Ready - Open a database to view schema');
end;

destructor TfraSchemaViewer.Destroy;
begin
  FTableNames.Free;
  inherited;
end;

procedure TfraSchemaViewer.InitGrids;
begin
  // Columns grid
  grdColumns.ColCount := 5;
  grdColumns.RowCount := 2;
  grdColumns.FixedRows := 1;
  grdColumns.FixedCols := 0;
  grdColumns.DefaultRowHeight := 22;
  grdColumns.Options := grdColumns.Options + [goRowSelect, goColSizing, goThumbTracking];
  grdColumns.Cells[0, 0] := 'Column Name';
  grdColumns.Cells[1, 0] := 'Data Type';
  grdColumns.Cells[2, 0] := 'Not Null';
  grdColumns.Cells[3, 0] := 'Default';
  grdColumns.Cells[4, 0] := 'Primary Key';
  grdColumns.ColWidths[0] := 150;
  grdColumns.ColWidths[1] := 120;
  grdColumns.ColWidths[2] := 70;
  grdColumns.ColWidths[3] := 100;
  grdColumns.ColWidths[4] := 80;
  
  // Indexes grid
  grdIndexes.ColCount := 3;
  grdIndexes.RowCount := 2;
  grdIndexes.FixedRows := 1;
  grdIndexes.FixedCols := 0;
  grdIndexes.DefaultRowHeight := 22;
  grdIndexes.Options := grdIndexes.Options + [goRowSelect, goColSizing, goThumbTracking];
  grdIndexes.Cells[0, 0] := 'Index Name';
  grdIndexes.Cells[1, 0] := 'Unique';
  grdIndexes.Cells[2, 0] := 'Columns';
  grdIndexes.ColWidths[0] := 200;
  grdIndexes.ColWidths[1] := 60;
  grdIndexes.ColWidths[2] := 250;
  
  // Foreign Keys grid
  grdForeignKeys.ColCount := 6;
  grdForeignKeys.RowCount := 2;
  grdForeignKeys.FixedRows := 1;
  grdForeignKeys.FixedCols := 0;
  grdForeignKeys.DefaultRowHeight := 22;
  grdForeignKeys.Options := grdForeignKeys.Options + [goRowSelect, goColSizing, goThumbTracking];
  grdForeignKeys.Cells[0, 0] := 'Constraint';
  grdForeignKeys.Cells[1, 0] := 'From Columns';
  grdForeignKeys.Cells[2, 0] := 'To Table';
  grdForeignKeys.Cells[3, 0] := 'To Columns';
  grdForeignKeys.Cells[4, 0] := 'On Update';
  grdForeignKeys.Cells[5, 0] := 'On Delete';
  grdForeignKeys.ColWidths[0] := 120;
  grdForeignKeys.ColWidths[1] := 100;
  grdForeignKeys.ColWidths[2] := 100;
  grdForeignKeys.ColWidths[3] := 100;
  grdForeignKeys.ColWidths[4] := 80;
  grdForeignKeys.ColWidths[5] := 80;
end;

procedure TfraSchemaViewer.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  if Assigned(FConnection) and FConnection.Connected then
    SetStatus('Connected - Click Refresh to load schema')
  else
    SetStatus('No database connection', True);
end;

procedure TfraSchemaViewer.RefreshData;
begin
  LoadSchema;
end;

procedure TfraSchemaViewer.LoadSchema;
var
  Query: TFDQuery;
  TableNode: TTreeNode;
  RootNode: TTreeNode;
begin
  tvSchema.Items.Clear;
  FTableNames.Clear;
  ClearDetails;
  
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    SetStatus('No database connection', True);
    Exit;
  end;
  
  SetStatus('Loading schema...');
  Application.ProcessMessages;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    // SQLite specific: get table names
    Query.SQL.Text := 
      'SELECT name FROM sqlite_master ' +
      'WHERE type = ''table'' AND name NOT LIKE ''sqlite_%'' ' +
      'ORDER BY name';
    
    try
      Query.Open;
      
      // Create root node
      RootNode := tvSchema.Items.Add(nil, 'Tables');
      RootNode.ImageIndex := 0;
      
      while not Query.Eof do
      begin
        FTableNames.Add(Query.FieldByName('name').AsString);
        
        TableNode := tvSchema.Items.AddChild(RootNode, Query.FieldByName('name').AsString);
        TableNode.ImageIndex := 1;
        TableNode.SelectedIndex := 1;
        
        // Add placeholder children for columns, indexes, foreign keys
        tvSchema.Items.AddChild(TableNode, 'Columns');
        tvSchema.Items.AddChild(TableNode, 'Indexes');
        tvSchema.Items.AddChild(TableNode, 'Foreign Keys');
        
        Query.Next;
      end;
      
      RootNode.Expand(False);
      
      SetStatus(Format('Loaded %d tables', [FTableNames.Count]));
    except
      on E: Exception do
      begin
        SetStatus('Error loading schema: ' + E.Message, True);
      end;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraSchemaViewer.LoadTableDetails(const ATableName: string);
begin
  if ATableName = '' then
  begin
    ClearDetails;
    Exit;
  end;
  
  FSelectedTable := ATableName;
  lblTitle.Caption := 'Schema: ' + ATableName;
  
  LoadColumns(ATableName);
  LoadIndexes(ATableName);
  LoadForeignKeys(ATableName);
  LoadDDL(ATableName);
end;

procedure TfraSchemaViewer.LoadColumns(const ATableName: string);
var
  Query: TFDQuery;
  Row: Integer;
begin
  grdColumns.RowCount := 2;
  grdColumns.Cells[0, 1] := '';
  grdColumns.Cells[1, 1] := '';
  grdColumns.Cells[2, 1] := '';
  grdColumns.Cells[3, 1] := '';
  grdColumns.Cells[4, 1] := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('PRAGMA table_info(%s)', [ATableName]);
    Query.Open;
    
    if Query.RecordCount > 0 then
      grdColumns.RowCount := Query.RecordCount + 1;
    
    Row := 1;
    while not Query.Eof do
    begin
      grdColumns.Cells[0, Row] := Query.FieldByName('name').AsString;
      grdColumns.Cells[1, Row] := Query.FieldByName('type').AsString;
      
      if Query.FieldByName('notnull').AsInteger = 1 then
        grdColumns.Cells[2, Row] := 'Yes'
      else
        grdColumns.Cells[2, Row] := 'No';
      
      grdColumns.Cells[3, Row] := Query.FieldByName('dflt_value').AsString;
      
      if Query.FieldByName('pk').AsInteger > 0 then
        grdColumns.Cells[4, Row] := 'Yes'
      else
        grdColumns.Cells[4, Row] := '';
      
      Inc(Row);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraSchemaViewer.LoadIndexes(const ATableName: string);
var
  Query, QueryCols: TFDQuery;
  Row: Integer;
  IndexName: string;
  Columns: string;
begin
  grdIndexes.RowCount := 2;
  grdIndexes.Cells[0, 1] := '';
  grdIndexes.Cells[1, 1] := '';
  grdIndexes.Cells[2, 1] := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  QueryCols := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    QueryCols.Connection := FConnection;
    
    Query.SQL.Text := Format('PRAGMA index_list(%s)', [ATableName]);
    Query.Open;
    
    if Query.RecordCount > 0 then
      grdIndexes.RowCount := Query.RecordCount + 1;
    
    Row := 1;
    while not Query.Eof do
    begin
      IndexName := Query.FieldByName('name').AsString;
      grdIndexes.Cells[0, Row] := IndexName;
      
      if Query.FieldByName('unique').AsInteger = 1 then
        grdIndexes.Cells[1, Row] := 'Yes'
      else
        grdIndexes.Cells[1, Row] := 'No';
      
      // Get index columns
      Columns := '';
      QueryCols.SQL.Text := Format('PRAGMA index_info(%s)', [IndexName]);
      QueryCols.Open;
      while not QueryCols.Eof do
      begin
        if Columns <> '' then
          Columns := Columns + ', ';
        Columns := Columns + QueryCols.FieldByName('name').AsString;
        QueryCols.Next;
      end;
      QueryCols.Close;
      
      grdIndexes.Cells[2, Row] := Columns;
      
      Inc(Row);
      Query.Next;
    end;
  finally
    Query.Free;
    QueryCols.Free;
  end;
end;

procedure TfraSchemaViewer.LoadForeignKeys(const ATableName: string);
var
  Query: TFDQuery;
  Row: Integer;
begin
  grdForeignKeys.RowCount := 2;
  grdForeignKeys.Cells[0, 1] := '';
  grdForeignKeys.Cells[1, 1] := '';
  grdForeignKeys.Cells[2, 1] := '';
  grdForeignKeys.Cells[3, 1] := '';
  grdForeignKeys.Cells[4, 1] := '';
  grdForeignKeys.Cells[5, 1] := '';
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('PRAGMA foreign_key_list(%s)', [ATableName]);
    Query.Open;
    
    if Query.RecordCount > 0 then
      grdForeignKeys.RowCount := Query.RecordCount + 1;
    
    Row := 1;
    while not Query.Eof do
    begin
      grdForeignKeys.Cells[0, Row] := Format('fk_%d', [Query.FieldByName('id').AsInteger]);
      grdForeignKeys.Cells[1, Row] := Query.FieldByName('from').AsString;
      grdForeignKeys.Cells[2, Row] := Query.FieldByName('table').AsString;
      grdForeignKeys.Cells[3, Row] := Query.FieldByName('to').AsString;
      grdForeignKeys.Cells[4, Row] := Query.FieldByName('on_update').AsString;
      grdForeignKeys.Cells[5, Row] := Query.FieldByName('on_delete').AsString;
      
      Inc(Row);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraSchemaViewer.LoadDDL(const ATableName: string);
var
  Query: TFDQuery;
begin
  mmoDDL.Clear;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT sql FROM sqlite_master WHERE type = ''table'' AND name = :name';
    Query.ParamByName('name').AsString := ATableName;
    Query.Open;
    
    if not Query.Eof then
    begin
      mmoDDL.Lines.Text := Query.FieldByName('sql').AsString;
    end;
    
    // Also add index DDL
    Query.Close;
    Query.SQL.Text := 
      'SELECT sql FROM sqlite_master WHERE type = ''index'' AND tbl_name = :name AND sql IS NOT NULL';
    Query.ParamByName('name').AsString := ATableName;
    Query.Open;
    
    if not Query.Eof then
    begin
      mmoDDL.Lines.Add('');
      mmoDDL.Lines.Add('-- Indexes:');
      while not Query.Eof do
      begin
        mmoDDL.Lines.Add(Query.FieldByName('sql').AsString + ';');
        Query.Next;
      end;
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraSchemaViewer.ClearDetails;
var
  I: Integer;
begin
  FSelectedTable := '';
  lblTitle.Caption := 'Schema Viewer';
  
  // Clear columns grid
  grdColumns.RowCount := 2;
  for I := 0 to grdColumns.ColCount - 1 do
    grdColumns.Cells[I, 1] := '';
  
  // Clear indexes grid  
  grdIndexes.RowCount := 2;
  for I := 0 to grdIndexes.ColCount - 1 do
    grdIndexes.Cells[I, 1] := '';
  
  // Clear foreign keys grid
  grdForeignKeys.RowCount := 2;
  for I := 0 to grdForeignKeys.ColCount - 1 do
    grdForeignKeys.Cells[I, 1] := '';
  
  // Clear DDL
  mmoDDL.Clear;
end;

procedure TfraSchemaViewer.SetStatus(const AText: string; AIsError: Boolean);
begin
  lblStatus.Caption := AText;
  if AIsError then
    lblStatus.Font.Color := clRed
  else
    lblStatus.Font.Color := clWindowText;
end;

procedure TfraSchemaViewer.btnRefreshClick(Sender: TObject);
begin
  LoadSchema;
end;

procedure TfraSchemaViewer.tvSchemaChange(Sender: TObject; Node: TTreeNode);
var
  TableName: string;
begin
  if Node = nil then
    Exit;
  
  // If this is a table node (has parent = root "Tables" node)
  if (Node.Parent <> nil) and (Node.Parent.Text = 'Tables') then
  begin
    TableName := Node.Text;
    LoadTableDetails(TableName);
  end
  // If this is a child of a table node (Columns, Indexes, Foreign Keys)
  else if (Node.Parent <> nil) and (Node.Parent.Parent <> nil) and 
          (Node.Parent.Parent.Text = 'Tables') then
  begin
    TableName := Node.Parent.Text;
    LoadTableDetails(TableName);
    
    // Switch to appropriate tab
    if Node.Text = 'Columns' then
      pgcDetails.ActivePage := tabColumns
    else if Node.Text = 'Indexes' then
      pgcDetails.ActivePage := tabIndexes
    else if Node.Text = 'Foreign Keys' then
      pgcDetails.ActivePage := tabForeignKeys;
  end;
end;

end.
