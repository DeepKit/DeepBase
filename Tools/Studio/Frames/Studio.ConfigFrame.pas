{ ============================================================================
  Studio.ConfigFrame - Enhanced Configuration Editor
  
  Version: 1.1
  Features:
    - Category filtering
    - Text search by Key
    - StringGrid with Key/Value/Type/Description columns
    - In-grid editing with explicit Save
    - Modified row tracking
    - Status bar with statistics
  ============================================================================ }

unit Studio.ConfigFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  System.UITypes, System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  FireDAC.Stan.Param,
  FireDAC.Comp.Client;

type
  TConfigEntry = record
    Key: string;
    Value: string;
    ValueType: string;
    Category: string;
    Description: string;
    IsEncrypted: Boolean;
    Modified: Boolean;
  end;

  TfraConfig = class(TFrame)
    pnlToolbar: TPanel;
    pnlMain: TPanel;
    sgConfig: TStringGrid;
    btnRefresh: TButton;
    btnAdd: TButton;
    btnDelete: TButton;
    btnSave: TButton;
    lblCategory: TLabel;
    lblSearch: TLabel;
    cmbCategory: TComboBox;
    edtSearch: TEdit;
    StatusBar: TStatusBar;
    procedure btnRefreshClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure cmbCategoryChange(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure sgConfigSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure sgConfigSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
  private
    FConnection: TFDConnection;
    FEntries: TList<TConfigEntry>;
    FModifiedRows: TDictionary<Integer, Boolean>;
    FTotalCount: Integer;
    FModifiedCount: Integer;
    procedure LoadConfig;
    procedure LoadCategories;
    procedure UpdateGrid;
    procedure UpdateStatusBar;
    procedure SaveRow(Row: Integer);
    function GetCategoryFilter: string;
    function GetSearchFilter: string;
    function MatchesFilter(const Entry: TConfigEntry): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

constructor TfraConfig.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEntries := TList<TConfigEntry>.Create;
  FModifiedRows := TDictionary<Integer, Boolean>.Create;
end;

destructor TfraConfig.Destroy;
begin
  FModifiedRows.Free;
  FEntries.Free;
  inherited;
end;

procedure TfraConfig.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
end;

procedure TfraConfig.RefreshData;
begin
  LoadCategories;
  LoadConfig;
end;

function TfraConfig.GetCategoryFilter: string;
begin
  if (cmbCategory <> nil) and (cmbCategory.ItemIndex > 0) then
    Result := cmbCategory.Text
  else
    Result := '';
end;

function TfraConfig.GetSearchFilter: string;
begin
  if edtSearch <> nil then
    Result := LowerCase(Trim(edtSearch.Text))
  else
    Result := '';
end;

function TfraConfig.MatchesFilter(const Entry: TConfigEntry): Boolean;
var
  CatFilter, SearchFilter: string;
begin
  Result := True;
  
  CatFilter := GetCategoryFilter;
  if (CatFilter <> '') and (Entry.Category <> CatFilter) then
    Exit(False);
    
  SearchFilter := GetSearchFilter;
  if (SearchFilter <> '') and 
     (Pos(SearchFilter, LowerCase(Entry.Key)) = 0) and
     (Pos(SearchFilter, LowerCase(Entry.Description)) = 0) then
    Exit(False);
end;

procedure TfraConfig.LoadCategories;
var
  Query: TFDQuery;
begin
  if cmbCategory = nil then Exit;
  cmbCategory.Items.Clear;
  cmbCategory.Items.Add('All Categories');
  
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT DISTINCT Category FROM Settings WHERE Category IS NOT NULL ORDER BY Category';
    try
      Query.Open;
      while not Query.Eof do
      begin
        if Query.Fields[0].AsString <> '' then
          cmbCategory.Items.Add(Query.Fields[0].AsString);
        Query.Next;
      end;
    except
      // Ignore
    end;
  finally
    Query.Free;
  end;
  
  cmbCategory.ItemIndex := 0;
end;

procedure TfraConfig.LoadConfig;
var
  Query: TFDQuery;
  Entry: TConfigEntry;
begin
  FEntries.Clear;
  FModifiedRows.Clear;
  FModifiedCount := 0;
  
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    UpdateGrid;
    UpdateStatusBar;
    Exit;
  end;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'SELECT Key, Value, ValueType, Category, Description, IsEncrypted ' +
      'FROM Settings ORDER BY Category, Key';
    try
      Query.Open;
      
      while not Query.Eof do
      begin
        Entry.Key := Query.FieldByName('Key').AsString;
        Entry.Value := Query.FieldByName('Value').AsString;
        Entry.ValueType := Query.FieldByName('ValueType').AsString;
        Entry.Category := Query.FieldByName('Category').AsString;
        Entry.Description := Query.FieldByName('Description').AsString;
        Entry.IsEncrypted := Query.FieldByName('IsEncrypted').AsInteger = 1;
        Entry.Modified := False;
        FEntries.Add(Entry);
        Query.Next;
      end;
    except
      // Table may not exist or have old schema
    end;
  finally
    Query.Free;
  end;
  
  FTotalCount := FEntries.Count;
  UpdateGrid;
  UpdateStatusBar;
end;

procedure TfraConfig.UpdateGrid;
var
  I, Row: Integer;
  Entry: TConfigEntry;
begin
  if sgConfig = nil then Exit;
  
  sgConfig.RowCount := 1;
  sgConfig.ColCount := 4;
  sgConfig.Cells[0, 0] := 'Key';
  sgConfig.Cells[1, 0] := 'Value';
  sgConfig.Cells[2, 0] := 'Type';
  sgConfig.Cells[3, 0] := 'Description';
  
  Row := 1;
  for I := 0 to FEntries.Count - 1 do
  begin
    Entry := FEntries[I];
    if not MatchesFilter(Entry) then
      Continue;
      
    sgConfig.RowCount := Row + 1;
    sgConfig.Cells[0, Row] := Entry.Key;
    if Entry.IsEncrypted then
      sgConfig.Cells[1, Row] := '********'
    else
      sgConfig.Cells[1, Row] := Entry.Value;
    sgConfig.Cells[2, Row] := Entry.ValueType;
    sgConfig.Cells[3, Row] := Entry.Description;
    sgConfig.Objects[0, Row] := TObject(I);  // Store entry index
    Inc(Row);
  end;
end;

procedure TfraConfig.UpdateStatusBar;
begin
  if StatusBar = nil then Exit;
  
  StatusBar.Panels[0].Text := Format('Showing: %d', [sgConfig.RowCount - 1]);
  StatusBar.Panels[1].Text := Format('Total: %d configs', [FTotalCount]);
  if FModifiedCount > 0 then
    StatusBar.Panels[2].Text := Format('%d modified', [FModifiedCount])
  else
    StatusBar.Panels[2].Text := '';
end;

procedure TfraConfig.sgConfigSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  // Allow editing only Value column (col 1) for non-encrypted entries
  CanSelect := True;
end;

procedure TfraConfig.sgConfigSetEditText(Sender: TObject; ACol, ARow: Integer; const Value: string);
var
  EntryIdx: Integer;
  Entry: TConfigEntry;
begin
  if (ACol <> 1) or (ARow < 1) then Exit;  // Only Value column
  
  EntryIdx := NativeInt(sgConfig.Objects[0, ARow]);
  if (EntryIdx < 0) or (EntryIdx >= FEntries.Count) then Exit;
  
  Entry := FEntries[EntryIdx];
  if Entry.IsEncrypted then Exit;  // Don't edit encrypted values in grid
  
  if Entry.Value <> Value then
  begin
    Entry.Value := Value;
    Entry.Modified := True;
    FEntries[EntryIdx] := Entry;
    
    if not FModifiedRows.ContainsKey(ARow) then
    begin
      FModifiedRows.Add(ARow, True);
      Inc(FModifiedCount);
      UpdateStatusBar;
    end;
  end;
end;

procedure TfraConfig.SaveRow(Row: Integer);
var
  EntryIdx: Integer;
  Entry: TConfigEntry;
  Query: TFDQuery;
begin
  EntryIdx := NativeInt(sgConfig.Objects[0, Row]);
  if (EntryIdx < 0) or (EntryIdx >= FEntries.Count) then Exit;
  
  Entry := FEntries[EntryIdx];
  if Entry.IsEncrypted then Exit;
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE Settings SET Value = :Value WHERE Key = :Key';
    Query.ParamByName('Value').AsString := Entry.Value;
    Query.ParamByName('Key').AsString := Entry.Key;
    Query.ExecSQL;
    
    Entry.Modified := False;
    FEntries[EntryIdx] := Entry;
  finally
    Query.Free;
  end;
end;

procedure TfraConfig.btnSaveClick(Sender: TObject);
var
  Row: Integer;
begin
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  if FModifiedCount = 0 then Exit;
  
  for Row in FModifiedRows.Keys do
    SaveRow(Row);
    
  FModifiedRows.Clear;
  FModifiedCount := 0;
  UpdateStatusBar;
  ShowMessage('Changes saved');
end;

procedure TfraConfig.cmbCategoryChange(Sender: TObject);
begin
  UpdateGrid;
  UpdateStatusBar;
end;

procedure TfraConfig.edtSearchChange(Sender: TObject);
begin
  UpdateGrid;
  UpdateStatusBar;
end;

procedure TfraConfig.btnRefreshClick(Sender: TObject);
begin
  if FModifiedCount > 0 then
  begin
    if MessageDlg('Discard unsaved changes?', mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;
  LoadCategories;
  LoadConfig;
end;

procedure TfraConfig.btnAddClick(Sender: TObject);
var
  Key, Value, Category: string;
  Query: TFDQuery;
begin
  if (FConnection = nil) or (not FConnection.Connected) then
  begin
    ShowMessage('No database connection');
    Exit;
  end;
  
  Key := InputBox('Add Config', 'Enter Key (e.g. App.MyKey):', '');
  if Key = '' then Exit;
  
  Value := InputBox('Add Config', 'Enter Value:', '');
  
  Category := 'General';
  if GetCategoryFilter <> '' then
    Category := GetCategoryFilter;
  Category := InputBox('Add Config', 'Category:', Category);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO Settings (Key, Value, ValueType, Category) ' +
      'VALUES (:Key, :Value, ''String'', :Category)';
    Query.ParamByName('Key').AsString := Key;
    Query.ParamByName('Value').AsString := Value;
    Query.ParamByName('Category').AsString := Category;
    try
      Query.ExecSQL;
      LoadCategories;
      LoadConfig;
    except
      on E: Exception do
        ShowMessage('Error: ' + E.Message);
    end;
  finally
    Query.Free;
  end;
end;

procedure TfraConfig.btnDeleteClick(Sender: TObject);
var
  Key: string;
  Row, EntryIdx: Integer;
  Entry: TConfigEntry;
  Query: TFDQuery;
begin
  if (FConnection = nil) or (not FConnection.Connected) then Exit;
  
  Row := sgConfig.Row;
  if Row < 1 then Exit;
  
  EntryIdx := NativeInt(sgConfig.Objects[0, Row]);
  if (EntryIdx < 0) or (EntryIdx >= FEntries.Count) then Exit;
  
  Entry := FEntries[EntryIdx];
  Key := Entry.Key;
  
  if MessageDlg('Delete config "' + Key + '"?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.ExecSQL;
      LoadConfig;
    finally
      Query.Free;
    end;
  end;
end;

end.
