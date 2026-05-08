{ ============================================================================
  Studio.ImportExportFrame - Data Import/Export Tool Frame
  
  Version: 1.0
  Description: Import and export database table data in CSV, JSON, and XML
               formats. Supports column mapping, preview, and batch operations.
  ============================================================================ }

unit Studio.ImportExportFrame;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Types,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  System.UITypes,
  System.IOUtils,
  System.JSON,
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
  DeepBase.Exceptions;

type
  TExportFormat = (efCSV, efJSON, efXML);
  
  TfraImportExport = class(TFrame)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    pnlMain: TPanel;
    pgcMain: TPageControl;
    tabExport: TTabSheet;
    tabImport: TTabSheet;
    { Export tab controls }
    pnlExportLeft: TPanel;
    lblExportTables: TLabel;
    lvExportTables: TListView;
    pnlExportRight: TPanel;
    lblExportFormat: TLabel;
    cboExportFormat: TComboBox;
    chkExportHeaders: TCheckBox;
    chkExportSelected: TCheckBox;
    lblExportPath: TLabel;
    edtExportPath: TEdit;
    btnExportBrowse: TButton;
    btnExport: TButton;
    prgExport: TProgressBar;
    lblExportStatus: TLabel;
    { Import tab controls }
    pnlImportTop: TPanel;
    lblImportFile: TLabel;
    edtImportFile: TEdit;
    btnImportBrowse: TButton;
    lblImportFormat: TLabel;
    cboImportFormat: TComboBox;
    lblTargetTable: TLabel;
    cboTargetTable: TComboBox;
    chkCreateTable: TCheckBox;
    chkTruncateFirst: TCheckBox;
    pnlImportPreview: TPanel;
    lblPreview: TLabel;
    sgPreview: TStringGrid;
    btnImport: TButton;
    prgImport: TProgressBar;
    lblImportStatus: TLabel;
    { Dialogs }
    dlgSave: TSaveDialog;
    dlgOpen: TOpenDialog;
    procedure btnExportBrowseClick(Sender: TObject);
    procedure btnImportBrowseClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnImportClick(Sender: TObject);
    procedure cboImportFormatChange(Sender: TObject);
    procedure edtImportFileChange(Sender: TObject);
  private
    FConnection: TFDConnection;
    FTableList: TStringList;
    
    procedure LoadTables;
    procedure LoadTableColumns(const ATableName: string);
    procedure PreviewImportFile;
    
    { Export methods }
    procedure ExportToCSV(const ATableName, AFilePath: string);
    procedure ExportToJSON(const ATableName, AFilePath: string);
    procedure ExportToXML(const ATableName, AFilePath: string);
    
    { Import methods }
    procedure ImportFromCSV(const AFilePath, ATableName: string);
    procedure ImportFromJSON(const AFilePath, ATableName: string);
    procedure ImportFromXML(const AFilePath, ATableName: string);
    
    function GetSelectedTables: TStringList;
    function GetExportFormat: TExportFormat;
    function GetImportFormat: TExportFormat;
    function DetectFileFormat(const AFilePath: string): TExportFormat;
    procedure SetExportStatus(const AText: string; AIsError: Boolean = False);
    procedure SetImportStatus(const AText: string; AIsError: Boolean = False);
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    procedure SetConnection(AConnection: TFDConnection);
    procedure RefreshData;
  end;

implementation

{$R *.dfm}

{ TfraImportExport }

constructor TfraImportExport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTableList := TStringList.Create;
  
  // Initialize export format combo
  cboExportFormat.Items.Clear;
  cboExportFormat.Items.Add('CSV (Comma Separated Values)');
  cboExportFormat.Items.Add('JSON (JavaScript Object Notation)');
  cboExportFormat.Items.Add('XML (Extensible Markup Language)');
  cboExportFormat.ItemIndex := 0;
  
  // Initialize import format combo
  cboImportFormat.Items.Clear;
  cboImportFormat.Items.Add('CSV');
  cboImportFormat.Items.Add('JSON');
  cboImportFormat.Items.Add('XML');
  cboImportFormat.ItemIndex := 0;
  
  // Export options
  chkExportHeaders.Checked := True;
  chkExportSelected.Checked := False;
  
  // Import options
  chkCreateTable.Checked := False;
  chkTruncateFirst.Checked := False;
  
  // Initialize export ListView
  with lvExportTables.Columns.Add do
  begin
    Caption := 'Table Name';
    Width := 200;
  end;
  with lvExportTables.Columns.Add do
  begin
    Caption := 'Rows';
    Width := 80;
  end;
  lvExportTables.ViewStyle := vsReport;
  lvExportTables.RowSelect := True;
  lvExportTables.MultiSelect := True;
  lvExportTables.Checkboxes := True;
  
  // Initialize preview grid
  sgPreview.FixedCols := 0;
  sgPreview.FixedRows := 1;
  sgPreview.ColCount := 5;
  sgPreview.RowCount := 2;
  sgPreview.DefaultColWidth := 120;
  
  // Progress bars
  prgExport.Visible := False;
  prgImport.Visible := False;
  
  // Default to Export tab
  pgcMain.ActivePage := tabExport;
  
  SetExportStatus('Ready - Select tables to export');
  SetImportStatus('Ready - Select a file to import');
end;

destructor TfraImportExport.Destroy;
begin
  FTableList.Free;
  inherited;
end;

procedure TfraImportExport.SetConnection(AConnection: TFDConnection);
begin
  FConnection := AConnection;
  
  if Assigned(FConnection) and FConnection.Connected then
  begin
    LoadTables;
    SetExportStatus('Connected - Select tables to export');
    SetImportStatus('Connected - Select a file to import');
  end
  else
  begin
    SetExportStatus('No database connection', True);
    SetImportStatus('No database connection', True);
  end;
end;

procedure TfraImportExport.RefreshData;
begin
  LoadTables;
end;

procedure TfraImportExport.LoadTables;
var
  Query: TFDQuery;
  Item: TListItem;
  TableName: string;
  RowCount: Integer;
  CountQuery: TFDQuery;
begin
  lvExportTables.Items.Clear;
  FTableList.Clear;
  cboTargetTable.Items.Clear;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  Query := TFDQuery.Create(nil);
  CountQuery := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    CountQuery.Connection := FConnection;
    
    // Get table list (SQLite)
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' ' +
                      'AND name NOT LIKE ''sqlite_%'' ORDER BY name';
    Query.Open;
    
    lvExportTables.Items.BeginUpdate;
    try
      while not Query.Eof do
      begin
        TableName := Query.FieldByName('name').AsString;
        FTableList.Add(TableName);
        cboTargetTable.Items.Add(TableName);
        
        // Get row count
        try
          CountQuery.SQL.Text := Format('SELECT COUNT(*) AS cnt FROM [%s]', [TableName]);
          CountQuery.Open;
          RowCount := CountQuery.FieldByName('cnt').AsInteger;
          CountQuery.Close;
        except
          RowCount := -1;
        end;
        
        Item := lvExportTables.Items.Add;
        Item.Caption := TableName;
        if RowCount >= 0 then
          Item.SubItems.Add(IntToStr(RowCount))
        else
          Item.SubItems.Add('?');
        
        Query.Next;
      end;
    finally
      lvExportTables.Items.EndUpdate;
    end;
    
    if cboTargetTable.Items.Count > 0 then
      cboTargetTable.ItemIndex := 0;
      
    SetExportStatus(Format('Found %d table(s)', [FTableList.Count]));
  finally
    CountQuery.Free;
    Query.Free;
  end;
end;

procedure TfraImportExport.LoadTableColumns(const ATableName: string);
begin
  // Not implemented for now - for future column mapping
end;

function TfraImportExport.GetSelectedTables: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  
  for I := 0 to lvExportTables.Items.Count - 1 do
  begin
    if lvExportTables.Items[I].Checked then
      Result.Add(lvExportTables.Items[I].Caption);
  end;
  
  // If none checked, use selected
  if (Result.Count = 0) and (lvExportTables.Selected <> nil) then
    Result.Add(lvExportTables.Selected.Caption);
end;

function TfraImportExport.GetExportFormat: TExportFormat;
begin
  case cboExportFormat.ItemIndex of
    0: Result := efCSV;
    1: Result := efJSON;
    2: Result := efXML;
  else
    Result := efCSV;
  end;
end;

function TfraImportExport.GetImportFormat: TExportFormat;
begin
  case cboImportFormat.ItemIndex of
    0: Result := efCSV;
    1: Result := efJSON;
    2: Result := efXML;
  else
    Result := efCSV;
  end;
end;

function TfraImportExport.DetectFileFormat(const AFilePath: string): TExportFormat;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFilePath));
  
  if Ext = '.json' then
    Result := efJSON
  else if Ext = '.xml' then
    Result := efXML
  else
    Result := efCSV;
end;

procedure TfraImportExport.SetExportStatus(const AText: string; AIsError: Boolean);
begin
  lblExportStatus.Caption := AText;
  if AIsError then
    lblExportStatus.Font.Color := clRed
  else
    lblExportStatus.Font.Color := clWindowText;
end;

procedure TfraImportExport.SetImportStatus(const AText: string; AIsError: Boolean);
begin
  lblImportStatus.Caption := AText;
  if AIsError then
    lblImportStatus.Font.Color := clRed
  else
    lblImportStatus.Font.Color := clWindowText;
end;

procedure TfraImportExport.btnExportBrowseClick(Sender: TObject);
var
  Ext: string;
begin
  case GetExportFormat of
    efCSV: begin
      dlgSave.Filter := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
      dlgSave.DefaultExt := 'csv';
      Ext := '.csv';
    end;
    efJSON: begin
      dlgSave.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
      dlgSave.DefaultExt := 'json';
      Ext := '.json';
    end;
    efXML: begin
      dlgSave.Filter := 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*';
      dlgSave.DefaultExt := 'xml';
      Ext := '.xml';
    end;
  end;
  
  if dlgSave.Execute then
    edtExportPath.Text := dlgSave.FileName;
end;

procedure TfraImportExport.btnImportBrowseClick(Sender: TObject);
begin
  dlgOpen.Filter := 'All Supported|*.csv;*.json;*.xml|CSV Files (*.csv)|*.csv|' +
                    'JSON Files (*.json)|*.json|XML Files (*.xml)|*.xml|All Files (*.*)|*.*';
  
  if dlgOpen.Execute then
  begin
    edtImportFile.Text := dlgOpen.FileName;
    
    // Auto-detect format
    case DetectFileFormat(dlgOpen.FileName) of
      efCSV: cboImportFormat.ItemIndex := 0;
      efJSON: cboImportFormat.ItemIndex := 1;
      efXML: cboImportFormat.ItemIndex := 2;
    end;
    
    PreviewImportFile;
  end;
end;

procedure TfraImportExport.edtImportFileChange(Sender: TObject);
begin
  if FileExists(edtImportFile.Text) then
    PreviewImportFile;
end;

procedure TfraImportExport.cboImportFormatChange(Sender: TObject);
begin
  if FileExists(edtImportFile.Text) then
    PreviewImportFile;
end;

procedure TfraImportExport.PreviewImportFile;
var
  Lines: TStringList;
  Fields: TArray<string>;
  I, J, MaxCols, MaxRows: Integer;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  JSONValue: TJSONValue;
  Pair: TJSONPair;
begin
  if not FileExists(edtImportFile.Text) then
    Exit;
  
  MaxRows := 10;  // Preview first 10 rows
  
  sgPreview.RowCount := 2;
  sgPreview.ColCount := 1;
  
  case GetImportFormat of
    efCSV:
    begin
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(edtImportFile.Text);
        
        if Lines.Count = 0 then
        begin
          SetImportStatus('File is empty', True);
          Exit;
        end;
        
        // Parse header
        Fields := Lines[0].Split([',']);
        MaxCols := Length(Fields);
        sgPreview.ColCount := MaxCols;
        sgPreview.RowCount := Min(Lines.Count, MaxRows + 1);
        
        // Set headers
        for J := 0 to MaxCols - 1 do
          sgPreview.Cells[J, 0] := Trim(Fields[J]).DeQuotedString('"');
        
        // Set data rows
        for I := 1 to Min(Lines.Count - 1, MaxRows) do
        begin
          Fields := Lines[I].Split([',']);
          for J := 0 to Min(Length(Fields), MaxCols) - 1 do
            sgPreview.Cells[J, I] := Trim(Fields[J]).DeQuotedString('"');
        end;
        
        SetImportStatus(Format('CSV: %d rows, %d columns', [Lines.Count - 1, MaxCols]));
      finally
        Lines.Free;
      end;
    end;
    
    efJSON:
    begin
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(edtImportFile.Text);
        JSONValue := TJSONObject.ParseJSONValue(Lines.Text);
        
        if JSONValue = nil then
        begin
          SetImportStatus('Invalid JSON format', True);
          Exit;
        end;
        
        try
          if JSONValue is TJSONArray then
            JSONArray := TJSONArray(JSONValue)
          else if (JSONValue is TJSONObject) and (TJSONObject(JSONValue).Count > 0) then
          begin
            // Check if it's { "data": [...] } format
            JSONArray := TJSONObject(JSONValue).GetValue('data') as TJSONArray;
            if JSONArray = nil then
            begin
              SetImportStatus('JSON must be an array or contain "data" array', True);
              Exit;
            end;
          end
          else
          begin
            SetImportStatus('JSON must be an array', True);
            Exit;
          end;
          
          if JSONArray.Count = 0 then
          begin
            SetImportStatus('JSON array is empty', True);
            Exit;
          end;
          
          // Get columns from first object
          JSONObj := JSONArray.Items[0] as TJSONObject;
          MaxCols := JSONObj.Count;
          sgPreview.ColCount := MaxCols;
          sgPreview.RowCount := Min(JSONArray.Count, MaxRows) + 1;
          
          // Set headers
          for J := 0 to JSONObj.Count - 1 do
            sgPreview.Cells[J, 0] := JSONObj.Pairs[J].JsonString.Value;
          
          // Set data
          for I := 0 to Min(JSONArray.Count - 1, MaxRows - 1) do
          begin
            JSONObj := JSONArray.Items[I] as TJSONObject;
            for J := 0 to JSONObj.Count - 1 do
            begin
              Pair := JSONObj.Pairs[J];
              if Pair.JsonValue is TJSONString then
                sgPreview.Cells[J, I + 1] := TJSONString(Pair.JsonValue).Value
              else if Pair.JsonValue is TJSONNumber then
                sgPreview.Cells[J, I + 1] := Pair.JsonValue.ToString
              else if Pair.JsonValue is TJSONBool then
                sgPreview.Cells[J, I + 1] := BoolToStr(TJSONBool(Pair.JsonValue).AsBoolean, True)
              else if Pair.JsonValue is TJSONNull then
                sgPreview.Cells[J, I + 1] := ''
              else
                sgPreview.Cells[J, I + 1] := Pair.JsonValue.ToString;
            end;
          end;
          
          SetImportStatus(Format('JSON: %d rows, %d columns', [JSONArray.Count, MaxCols]));
        finally
          JSONValue.Free;
        end;
      finally
        Lines.Free;
      end;
    end;
    
    efXML:
    begin
      // Simple XML preview - just show file info
      SetImportStatus('XML import preview not implemented');
      sgPreview.ColCount := 1;
      sgPreview.RowCount := 2;
      sgPreview.Cells[0, 0] := 'XML Preview';
      sgPreview.Cells[0, 1] := 'Use Import to process';
    end;
  end;
end;

procedure TfraImportExport.btnExportClick(Sender: TObject);
var
  Tables: TStringList;
  I: Integer;
  BasePath, Ext, FilePath: string;
  ExpFormat: TExportFormat;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    SetExportStatus('No database connection', True);
    Exit;
  end;
  
  Tables := GetSelectedTables;
  try
    if Tables.Count = 0 then
    begin
      SetExportStatus('No tables selected for export', True);
      Exit;
    end;
    
    BasePath := edtExportPath.Text;
    if BasePath = '' then
    begin
      SetExportStatus('Please specify export path', True);
      Exit;
    end;
    
    ExpFormat := GetExportFormat;
    case ExpFormat of
      efCSV: Ext := '.csv';
      efJSON: Ext := '.json';
      efXML: Ext := '.xml';
    end;
    
    prgExport.Visible := True;
    prgExport.Position := 0;
    prgExport.Max := Tables.Count;
    
    try
      for I := 0 to Tables.Count - 1 do
      begin
        SetExportStatus(Format('Exporting %s...', [Tables[I]]));
        Application.ProcessMessages;
        
        // Generate file path
        if Tables.Count = 1 then
          FilePath := BasePath
        else
          FilePath := ChangeFileExt(BasePath, '') + '_' + Tables[I] + Ext;
        
        case ExpFormat of
          efCSV: ExportToCSV(Tables[I], FilePath);
          efJSON: ExportToJSON(Tables[I], FilePath);
          efXML: ExportToXML(Tables[I], FilePath);
        end;
        
        prgExport.Position := I + 1;
        Application.ProcessMessages;
      end;
      
      SetExportStatus(Format('Exported %d table(s) successfully', [Tables.Count]));
    except
      on E: Exception do
        SetExportStatus('Export failed: ' + E.Message, True);
    end;
    
    prgExport.Visible := False;
  finally
    Tables.Free;
  end;
end;

procedure TfraImportExport.ExportToCSV(const ATableName, AFilePath: string);
var
  Query: TFDQuery;
  Output: TStringList;
  Line: string;
  I: Integer;
  FieldValue: string;
begin
  Query := TFDQuery.Create(nil);
  Output := TStringList.Create;
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('SELECT * FROM [%s]', [ATableName]);
    Query.Open;
    
    // Header row
    if chkExportHeaders.Checked then
    begin
      Line := '';
      for I := 0 to Query.FieldCount - 1 do
      begin
        if I > 0 then
          Line := Line + ',';
        Line := Line + '"' + Query.Fields[I].FieldName + '"';
      end;
      Output.Add(Line);
    end;
    
    // Data rows
    while not Query.Eof do
    begin
      Line := '';
      for I := 0 to Query.FieldCount - 1 do
      begin
        if I > 0 then
          Line := Line + ',';
        
        if Query.Fields[I].IsNull then
          FieldValue := ''
        else
          FieldValue := Query.Fields[I].AsString;
        
        // Escape quotes and wrap in quotes
        FieldValue := StringReplace(FieldValue, '"', '""', [rfReplaceAll]);
        Line := Line + '"' + FieldValue + '"';
      end;
      Output.Add(Line);
      Query.Next;
    end;
    
    Output.SaveToFile(AFilePath, TEncoding.UTF8);
  finally
    Output.Free;
    Query.Free;
  end;
end;

procedure TfraImportExport.ExportToJSON(const ATableName, AFilePath: string);
var
  Query: TFDQuery;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  I: Integer;
  Output: TStringList;
begin
  Query := TFDQuery.Create(nil);
  JSONArray := TJSONArray.Create;
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('SELECT * FROM [%s]', [ATableName]);
    Query.Open;
    
    while not Query.Eof do
    begin
      JSONObj := TJSONObject.Create;
      
      for I := 0 to Query.FieldCount - 1 do
      begin
        if Query.Fields[I].IsNull then
          JSONObj.AddPair(Query.Fields[I].FieldName, TJSONNull.Create)
        else
        begin
          case Query.Fields[I].DataType of
            ftInteger, ftSmallint, ftWord, ftLargeint:
              JSONObj.AddPair(Query.Fields[I].FieldName, TJSONNumber.Create(Query.Fields[I].AsInteger));
            ftFloat, ftCurrency, ftBCD, ftFMTBcd:
              JSONObj.AddPair(Query.Fields[I].FieldName, TJSONNumber.Create(Query.Fields[I].AsFloat));
            ftBoolean:
              JSONObj.AddPair(Query.Fields[I].FieldName, TJSONBool.Create(Query.Fields[I].AsBoolean));
          else
            JSONObj.AddPair(Query.Fields[I].FieldName, Query.Fields[I].AsString);
          end;
        end;
      end;
      
      JSONArray.AddElement(JSONObj);
      Query.Next;
    end;
    
    Output := TStringList.Create;
    try
      Output.Text := JSONArray.Format(2);
      Output.SaveToFile(AFilePath, TEncoding.UTF8);
    finally
      Output.Free;
    end;
  finally
    JSONArray.Free;
    Query.Free;
  end;
end;

procedure TfraImportExport.ExportToXML(const ATableName, AFilePath: string);
var
  Query: TFDQuery;
  Output: TStringList;
  I: Integer;
  FieldValue: string;
begin
  Query := TFDQuery.Create(nil);
  Output := TStringList.Create;
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('SELECT * FROM [%s]', [ATableName]);
    Query.Open;
    
    Output.Add('<?xml version="1.0" encoding="UTF-8"?>');
    Output.Add('<data table="' + ATableName + '">');
    
    while not Query.Eof do
    begin
      Output.Add('  <row>');
      
      for I := 0 to Query.FieldCount - 1 do
      begin
        if Query.Fields[I].IsNull then
          Output.Add(Format('    <%s/>', [Query.Fields[I].FieldName]))
        else
        begin
          FieldValue := Query.Fields[I].AsString;
          // XML escape
          FieldValue := StringReplace(FieldValue, '&', '&amp;', [rfReplaceAll]);
          FieldValue := StringReplace(FieldValue, '<', '&lt;', [rfReplaceAll]);
          FieldValue := StringReplace(FieldValue, '>', '&gt;', [rfReplaceAll]);
          FieldValue := StringReplace(FieldValue, '"', '&quot;', [rfReplaceAll]);
          Output.Add(Format('    <%s>%s</%0:s>', [Query.Fields[I].FieldName, FieldValue]));
        end;
      end;
      
      Output.Add('  </row>');
      Query.Next;
    end;
    
    Output.Add('</data>');
    Output.SaveToFile(AFilePath, TEncoding.UTF8);
  finally
    Output.Free;
    Query.Free;
  end;
end;

procedure TfraImportExport.btnImportClick(Sender: TObject);
var
  TargetTable: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
  begin
    SetImportStatus('No database connection', True);
    Exit;
  end;
  
  if not FileExists(edtImportFile.Text) then
  begin
    SetImportStatus('Import file not found', True);
    Exit;
  end;
  
  TargetTable := cboTargetTable.Text;
  if TargetTable = '' then
  begin
    SetImportStatus('Please specify target table', True);
    Exit;
  end;
  
  prgImport.Visible := True;
  prgImport.Position := 0;
  
  try
    SetImportStatus('Importing...');
    Application.ProcessMessages;
    
    case GetImportFormat of
      efCSV: ImportFromCSV(edtImportFile.Text, TargetTable);
      efJSON: ImportFromJSON(edtImportFile.Text, TargetTable);
      efXML: ImportFromXML(edtImportFile.Text, TargetTable);
    end;
    
    SetImportStatus('Import completed successfully');
    LoadTables;  // Refresh table list
  except
    on E: Exception do
      SetImportStatus('Import failed: ' + E.Message, True);
  end;
  
  prgImport.Visible := False;
end;

procedure TfraImportExport.ImportFromCSV(const AFilePath, ATableName: string);
var
  Lines: TStringList;
  Headers: TArray<string>;
  Fields: TArray<string>;
  Query: TFDQuery;
  SQL, Values: string;
  I, J: Integer;
  FieldValue: string;
begin
  Lines := TStringList.Create;
  Query := TFDQuery.Create(nil);
  try
    Lines.LoadFromFile(AFilePath);
    Query.Connection := FConnection;
    
    if Lines.Count < 2 then
    begin
      SetImportStatus('File has no data rows', True);
      Exit;
    end;
    
    // Parse headers
    Headers := Lines[0].Split([',']);
    for I := 0 to Length(Headers) - 1 do
      Headers[I] := Trim(Headers[I]).DeQuotedString('"');
    
    // Truncate if requested
    if chkTruncateFirst.Checked then
    begin
      Query.SQL.Text := Format('DELETE FROM [%s]', [ATableName]);
      Query.ExecSQL;
    end;
    
    prgImport.Max := Lines.Count - 1;
    
    // Import data
    FConnection.StartTransaction;
    try
      for I := 1 to Lines.Count - 1 do
      begin
        if Trim(Lines[I]) = '' then
          Continue;
          
        Fields := Lines[I].Split([',']);
        
        // Build INSERT statement
        SQL := Format('INSERT INTO [%s] (', [ATableName]);
        Values := 'VALUES (';
        
        for J := 0 to Min(Length(Headers), Length(Fields)) - 1 do
        begin
          if J > 0 then
          begin
            SQL := SQL + ', ';
            Values := Values + ', ';
          end;
          
          SQL := SQL + '[' + Headers[J] + ']';
          
          FieldValue := Trim(Fields[J]).DeQuotedString('"');
          if FieldValue = '' then
            Values := Values + 'NULL'
          else
            Values := Values + QuotedStr(FieldValue);
        end;
        
        SQL := SQL + ') ' + Values + ')';
        
        Query.SQL.Text := SQL;
        Query.ExecSQL;
        
        prgImport.Position := I;
        if I mod 100 = 0 then
          Application.ProcessMessages;
      end;
      
      FConnection.Commit;
      SetImportStatus(Format('Imported %d rows', [Lines.Count - 1]));
    except
      FConnection.Rollback;
      raise;
    end;
  finally
    Query.Free;
    Lines.Free;
  end;
end;

procedure TfraImportExport.ImportFromJSON(const AFilePath, ATableName: string);
var
  Lines: TStringList;
  JSONValue: TJSONValue;
  JSONArray: TJSONArray;
  JSONObj: TJSONObject;
  Query: TFDQuery;
  SQL, Values: string;
  I, J: Integer;
  Pair: TJSONPair;
  FieldValue: string;
begin
  Lines := TStringList.Create;
  Query := TFDQuery.Create(nil);
  try
    Lines.LoadFromFile(AFilePath);
    Query.Connection := FConnection;
    
    JSONValue := TJSONObject.ParseJSONValue(Lines.Text);
    if JSONValue = nil then
      raise EOperationException.Create('Invalid JSON format');
    
    try
      if JSONValue is TJSONArray then
        JSONArray := TJSONArray(JSONValue)
      else if JSONValue is TJSONObject then
      begin
        JSONArray := TJSONObject(JSONValue).GetValue('data') as TJSONArray;
        if JSONArray = nil then
          raise EOperationException.Create('JSON must be an array or contain "data" array');
      end
      else
        raise EOperationException.Create('JSON must be an array');
      
      if JSONArray.Count = 0 then
      begin
        SetImportStatus('JSON array is empty', True);
        Exit;
      end;
      
      // Truncate if requested
      if chkTruncateFirst.Checked then
      begin
        Query.SQL.Text := Format('DELETE FROM [%s]', [ATableName]);
        Query.ExecSQL;
      end;
      
      prgImport.Max := JSONArray.Count;
      
      // Import data
      FConnection.StartTransaction;
      try
        for I := 0 to JSONArray.Count - 1 do
        begin
          JSONObj := JSONArray.Items[I] as TJSONObject;
          
          SQL := Format('INSERT INTO [%s] (', [ATableName]);
          Values := 'VALUES (';
          
          for J := 0 to JSONObj.Count - 1 do
          begin
            Pair := JSONObj.Pairs[J];
            
            if J > 0 then
            begin
              SQL := SQL + ', ';
              Values := Values + ', ';
            end;
            
            SQL := SQL + '[' + Pair.JsonString.Value + ']';
            
            if Pair.JsonValue is TJSONNull then
              Values := Values + 'NULL'
            else if Pair.JsonValue is TJSONString then
              Values := Values + QuotedStr(TJSONString(Pair.JsonValue).Value)
            else if Pair.JsonValue is TJSONNumber then
              Values := Values + Pair.JsonValue.ToString
            else if Pair.JsonValue is TJSONBool then
            begin
              if TJSONBool(Pair.JsonValue).AsBoolean then
                Values := Values + '1'
              else
                Values := Values + '0';
            end
            else
              Values := Values + QuotedStr(Pair.JsonValue.ToString);
          end;
          
          SQL := SQL + ') ' + Values + ')';
          
          Query.SQL.Text := SQL;
          Query.ExecSQL;
          
          prgImport.Position := I + 1;
          if I mod 100 = 0 then
            Application.ProcessMessages;
        end;
        
        FConnection.Commit;
        SetImportStatus(Format('Imported %d rows', [JSONArray.Count]));
      except
        FConnection.Rollback;
        raise;
      end;
    finally
      JSONValue.Free;
    end;
  finally
    Query.Free;
    Lines.Free;
  end;
end;

procedure TfraImportExport.ImportFromXML(const AFilePath, ATableName: string);
begin
  // XML import is more complex - placeholder for now
  raise EOperationException.Create('XML import not yet implemented');
end;

end.
