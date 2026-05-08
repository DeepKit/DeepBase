{ ============================================================================
  DeepBase.Export - Simple Data Export
  
  Version: 1.0
  Description: Provides simple data export functionality for CSV and HTML
               formats. Supports exporting from TDataSet, TStringGrid, and
               generic arrays.
  Thread Safety: Methods are not thread-safe. Synchronize if needed.
  ============================================================================ }

unit DeepBase.Export;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Math,
  Data.DB,
  Vcl.Grids;

type
  /// <summary>
  /// CSV export options
  /// </summary>
  TCSVOptions = record
    Delimiter: Char;
    QuoteChar: Char;
    Encoding: TEncoding;
    IncludeHeader: Boolean;
    QuoteAllFields: Boolean;
    LineBreak: string;
    
    class function Default: TCSVOptions; static;
  end;

  /// <summary>
  /// HTML export options
  /// </summary>
  THTMLOptions = record
    Title: string;
    TableClass: string;
    HeaderClass: string;
    RowClass: string;
    AltRowClass: string;
    IncludeStyles: Boolean;
    Encoding: TEncoding;
    
    class function Default: THTMLOptions; static;
  end;

  /// <summary>
  /// Column definition for export
  /// </summary>
  TExportColumn = record
    FieldName: string;
    Title: string;
    Width: Integer;
    Alignment: TAlignment;
    Format: string;
    
    constructor Create(const AFieldName: string; const ATitle: string = ''; 
      AWidth: Integer = 0);
  end;

  /// <summary>
  /// Data export helper class
  /// </summary>
  TDataExport = class
  private
    class function EscapeCSV(const Value: string; const Options: TCSVOptions): string;
    class function EscapeHTML(const Value: string): string;
    class function GetDefaultCSS: string;
    
  public
    // ========================================
    // CSV Export
    // ========================================
    
    /// <summary>
    /// Export TDataSet to CSV file
    /// </summary>
    class procedure DataSetToCSV(DataSet: TDataSet; const FileName: string;
      const Options: TCSVOptions); overload;
    class procedure DataSetToCSV(DataSet: TDataSet; const FileName: string); overload;
    
    /// <summary>
    /// Export TDataSet to CSV stream
    /// </summary>
    class procedure DataSetToCSV(DataSet: TDataSet; Stream: TStream;
      const Options: TCSVOptions); overload;
    
    /// <summary>
    /// Export TStringGrid to CSV file
    /// </summary>
    class procedure GridToCSV(Grid: TStringGrid; const FileName: string;
      const Options: TCSVOptions); overload;
    class procedure GridToCSV(Grid: TStringGrid; const FileName: string); overload;
    
    /// <summary>
    /// Export 2D string array to CSV file
    /// </summary>
    class procedure ArrayToCSV(const Data: TArray<TArray<string>>; 
      const FileName: string; const Options: TCSVOptions); overload;
    class procedure ArrayToCSV(const Data: TArray<TArray<string>>; 
      const FileName: string); overload;
    
    // ========================================
    // HTML Export
    // ========================================
    
    /// <summary>
    /// Export TDataSet to HTML file
    /// </summary>
    class procedure DataSetToHTML(DataSet: TDataSet; const FileName: string;
      const Options: THTMLOptions); overload;
    class procedure DataSetToHTML(DataSet: TDataSet; const FileName: string;
      const Title: string = ''); overload;
    
    /// <summary>
    /// Export TDataSet to HTML stream
    /// </summary>
    class procedure DataSetToHTML(DataSet: TDataSet; Stream: TStream;
      const Options: THTMLOptions); overload;
    
    /// <summary>
    /// Export TStringGrid to HTML file
    /// </summary>
    class procedure GridToHTML(Grid: TStringGrid; const FileName: string;
      const Options: THTMLOptions); overload;
    class procedure GridToHTML(Grid: TStringGrid; const FileName: string;
      const Title: string = ''); overload;
    
    /// <summary>
    /// Export 2D string array to HTML file
    /// </summary>
    class procedure ArrayToHTML(const Data: TArray<TArray<string>>;
      const Headers: TArray<string>; const FileName: string;
      const Options: THTMLOptions); overload;
    class procedure ArrayToHTML(const Data: TArray<TArray<string>>;
      const Headers: TArray<string>; const FileName: string;
      const Title: string = ''); overload;
      
    // ========================================
    // Quick Export (Simplified API)
    // ========================================
    
    /// <summary>Quick CSV export</summary>
    class procedure ToCSV(DataSet: TDataSet; const FileName: string); overload;
    class procedure ToCSV(Grid: TStringGrid; const FileName: string); overload;
    
    /// <summary>Quick HTML export</summary>
    class procedure ToHTML(DataSet: TDataSet; const FileName: string;
      const Title: string = ''); overload;
    class procedure ToHTML(Grid: TStringGrid; const FileName: string;
      const Title: string = ''); overload;

    // ========================================
    // JSON Export
    // ========================================

    class function DataSetToJSON(DataSet: TDataSet): string;
    class function GridToJSON(Grid: TStringGrid): string;
    class function ArrayToJSON(const Data: TArray<TArray<string>>;
      const Headers: TArray<string>): string;

    /// <summary>Quick JSON export</summary>
    class procedure ToJSON(DataSet: TDataSet; const FileName: string);
  end;

implementation

uses
  System.IOUtils;

{ TCSVOptions }

class function TCSVOptions.Default: TCSVOptions;
begin
  Result.Delimiter := ',';
  Result.QuoteChar := '"';
  Result.Encoding := TEncoding.UTF8;
  Result.IncludeHeader := True;
  Result.QuoteAllFields := False;
  Result.LineBreak := sLineBreak;
end;

{ THTMLOptions }

class function THTMLOptions.Default: THTMLOptions;
begin
  Result.Title := 'Data Export';
  Result.TableClass := 'data-table';
  Result.HeaderClass := 'header';
  Result.RowClass := 'row';
  Result.AltRowClass := 'row-alt';
  Result.IncludeStyles := True;
  Result.Encoding := TEncoding.UTF8;
end;

{ TExportColumn }

constructor TExportColumn.Create(const AFieldName, ATitle: string; AWidth: Integer);
begin
  FieldName := AFieldName;
  if ATitle = '' then
    Title := AFieldName
  else
    Title := ATitle;
  Width := AWidth;
  Alignment := taLeftJustify;
  Format := '';
end;

{ TDataExport }

class function TDataExport.EscapeCSV(const Value: string; const Options: TCSVOptions): string;
var
  NeedQuote: Boolean;
begin
  NeedQuote := Options.QuoteAllFields or
               Value.Contains(Options.Delimiter) or
               Value.Contains(Options.QuoteChar) or
               Value.Contains(#13) or
               Value.Contains(#10);
               
  if NeedQuote then
  begin
    // Escape quote chars by doubling them
    Result := Options.QuoteChar + 
              Value.Replace(Options.QuoteChar, Options.QuoteChar + Options.QuoteChar) +
              Options.QuoteChar;
  end
  else
    Result := Value;
end;

class function TDataExport.EscapeHTML(const Value: string): string;
begin
  Result := Value;
  Result := Result.Replace('&', '&amp;');
  Result := Result.Replace('<', '&lt;');
  Result := Result.Replace('>', '&gt;');
  Result := Result.Replace('"', '&quot;');
  Result := Result.Replace('''', '&#39;');
end;

class function TDataExport.GetDefaultCSS: string;
begin
  Result :=
    '<style>' + sLineBreak +
    '.data-table { border-collapse: collapse; width: 100%; font-family: Arial, sans-serif; font-size: 14px; }' + sLineBreak +
    '.data-table th, .data-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }' + sLineBreak +
    '.data-table th { background-color: #4472C4; color: white; font-weight: bold; }' + sLineBreak +
    '.data-table tr:nth-child(even) { background-color: #f9f9f9; }' + sLineBreak +
    '.data-table tr:hover { background-color: #e8f4fd; }' + sLineBreak +
    'body { font-family: Arial, sans-serif; margin: 20px; }' + sLineBreak +
    'h1 { color: #333; }' + sLineBreak +
    '</style>' + sLineBreak;
end;

// ============================================================================
// CSV Export Implementation
// ============================================================================

class procedure TDataExport.DataSetToCSV(DataSet: TDataSet; const FileName: string;
  const Options: TCSVOptions);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    DataSetToCSV(DataSet, Stream, Options);
  finally
    Stream.Free;
  end;
end;

class procedure TDataExport.DataSetToCSV(DataSet: TDataSet; const FileName: string);
begin
  DataSetToCSV(DataSet, FileName, TCSVOptions.Default);
end;

class procedure TDataExport.DataSetToCSV(DataSet: TDataSet; Stream: TStream;
  const Options: TCSVOptions);
var
  Writer: TStreamWriter;
  I: Integer;
  Line: string;
  Bookmark: TBookmark;
begin
  Writer := TStreamWriter.Create(Stream, Options.Encoding);
  try
    // Write BOM for UTF-8
    if Options.Encoding = TEncoding.UTF8 then
    begin
      Stream.Position := 0;
      // UTF-8 BOM is written by TStreamWriter
    end;
    
    // Header
    if Options.IncludeHeader then
    begin
      Line := '';
      for I := 0 to DataSet.FieldCount - 1 do
      begin
        if I > 0 then
          Line := Line + Options.Delimiter;
        Line := Line + EscapeCSV(DataSet.Fields[I].DisplayLabel, Options);
      end;
      Writer.WriteLine(Line);
    end;
    
    // Data
    Bookmark := DataSet.Bookmark;
    DataSet.DisableControls;
    try
      DataSet.First;
      while not DataSet.Eof do
      begin
        Line := '';
        for I := 0 to DataSet.FieldCount - 1 do
        begin
          if I > 0 then
            Line := Line + Options.Delimiter;
          Line := Line + EscapeCSV(DataSet.Fields[I].AsString, Options);
        end;
        Writer.WriteLine(Line);
        DataSet.Next;
      end;
    finally
      DataSet.Bookmark := Bookmark;
      DataSet.EnableControls;
    end;
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.GridToCSV(Grid: TStringGrid; const FileName: string;
  const Options: TCSVOptions);
var
  Writer: TStreamWriter;
  Row, Col: Integer;
  Line: string;
  StartRow: Integer;
begin
  Writer := TStreamWriter.Create(FileName, False, Options.Encoding);
  try
    StartRow := 0;
    if Options.IncludeHeader and (Grid.FixedRows > 0) then
      StartRow := 0
    else
      StartRow := Grid.FixedRows;
      
    for Row := StartRow to Grid.RowCount - 1 do
    begin
      Line := '';
      for Col := 0 to Grid.ColCount - 1 do
      begin
        if Col > 0 then
          Line := Line + Options.Delimiter;
        Line := Line + EscapeCSV(Grid.Cells[Col, Row], Options);
      end;
      Writer.WriteLine(Line);
    end;
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.GridToCSV(Grid: TStringGrid; const FileName: string);
begin
  GridToCSV(Grid, FileName, TCSVOptions.Default);
end;

class procedure TDataExport.ArrayToCSV(const Data: TArray<TArray<string>>;
  const FileName: string; const Options: TCSVOptions);
var
  Writer: TStreamWriter;
  Row, Col: Integer;
  Line: string;
begin
  Writer := TStreamWriter.Create(FileName, False, Options.Encoding);
  try
    for Row := 0 to High(Data) do
    begin
      Line := '';
      for Col := 0 to High(Data[Row]) do
      begin
        if Col > 0 then
          Line := Line + Options.Delimiter;
        Line := Line + EscapeCSV(Data[Row][Col], Options);
      end;
      Writer.WriteLine(Line);
    end;
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.ArrayToCSV(const Data: TArray<TArray<string>>;
  const FileName: string);
begin
  ArrayToCSV(Data, FileName, TCSVOptions.Default);
end;

// ============================================================================
// HTML Export Implementation
// ============================================================================

class procedure TDataExport.DataSetToHTML(DataSet: TDataSet; const FileName: string;
  const Options: THTMLOptions);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    DataSetToHTML(DataSet, Stream, Options);
  finally
    Stream.Free;
  end;
end;

class procedure TDataExport.DataSetToHTML(DataSet: TDataSet; const FileName: string;
  const Title: string);
var
  Options: THTMLOptions;
begin
  Options := THTMLOptions.Default;
  if Title <> '' then
    Options.Title := Title;
  DataSetToHTML(DataSet, FileName, Options);
end;

class procedure TDataExport.DataSetToHTML(DataSet: TDataSet; Stream: TStream;
  const Options: THTMLOptions);
var
  Writer: TStreamWriter;
  I: Integer;
  RowClass: string;
  IsAlt: Boolean;
  Bookmark: TBookmark;
begin
  Writer := TStreamWriter.Create(Stream, Options.Encoding);
  try
    // HTML Header
    Writer.WriteLine('<!DOCTYPE html>');
    Writer.WriteLine('<html>');
    Writer.WriteLine('<head>');
    Writer.WriteLine('  <meta charset="utf-8">');
    Writer.WriteLine('  <title>' + EscapeHTML(Options.Title) + '</title>');
    
    if Options.IncludeStyles then
      Writer.Write(GetDefaultCSS);
      
    Writer.WriteLine('</head>');
    Writer.WriteLine('<body>');
    Writer.WriteLine('<h1>' + EscapeHTML(Options.Title) + '</h1>');
    Writer.WriteLine('<table class="' + Options.TableClass + '">');
    
    // Table Header
    Writer.WriteLine('  <thead>');
    Writer.WriteLine('    <tr>');
    for I := 0 to DataSet.FieldCount - 1 do
      Writer.WriteLine('      <th>' + EscapeHTML(DataSet.Fields[I].DisplayLabel) + '</th>');
    Writer.WriteLine('    </tr>');
    Writer.WriteLine('  </thead>');
    
    // Table Body
    Writer.WriteLine('  <tbody>');
    
    Bookmark := DataSet.Bookmark;
    DataSet.DisableControls;
    try
      IsAlt := False;
      DataSet.First;
      while not DataSet.Eof do
      begin
        if IsAlt then
          RowClass := Options.AltRowClass
        else
          RowClass := Options.RowClass;
          
        Writer.WriteLine('    <tr class="' + RowClass + '">');
        for I := 0 to DataSet.FieldCount - 1 do
          Writer.WriteLine('      <td>' + EscapeHTML(DataSet.Fields[I].AsString) + '</td>');
        Writer.WriteLine('    </tr>');
        
        IsAlt := not IsAlt;
        DataSet.Next;
      end;
    finally
      DataSet.Bookmark := Bookmark;
      DataSet.EnableControls;
    end;
    
    Writer.WriteLine('  </tbody>');
    Writer.WriteLine('</table>');
    
    // Footer
    Writer.WriteLine('<p style="color: #888; font-size: 12px;">');
    Writer.WriteLine('  Generated by DeepBase on ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Writer.WriteLine('</p>');
    Writer.WriteLine('</body>');
    Writer.WriteLine('</html>');
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.GridToHTML(Grid: TStringGrid; const FileName: string;
  const Options: THTMLOptions);
var
  Writer: TStreamWriter;
  Row, Col: Integer;
  RowClass: string;
  IsAlt: Boolean;
begin
  Writer := TStreamWriter.Create(FileName, False, Options.Encoding);
  try
    // HTML Header
    Writer.WriteLine('<!DOCTYPE html>');
    Writer.WriteLine('<html>');
    Writer.WriteLine('<head>');
    Writer.WriteLine('  <meta charset="utf-8">');
    Writer.WriteLine('  <title>' + EscapeHTML(Options.Title) + '</title>');
    
    if Options.IncludeStyles then
      Writer.Write(GetDefaultCSS);
      
    Writer.WriteLine('</head>');
    Writer.WriteLine('<body>');
    Writer.WriteLine('<h1>' + EscapeHTML(Options.Title) + '</h1>');
    Writer.WriteLine('<table class="' + Options.TableClass + '">');
    
    // Header from fixed rows
    if Grid.FixedRows > 0 then
    begin
      Writer.WriteLine('  <thead>');
      for Row := 0 to Grid.FixedRows - 1 do
      begin
        Writer.WriteLine('    <tr>');
        for Col := 0 to Grid.ColCount - 1 do
          Writer.WriteLine('      <th>' + EscapeHTML(Grid.Cells[Col, Row]) + '</th>');
        Writer.WriteLine('    </tr>');
      end;
      Writer.WriteLine('  </thead>');
    end;
    
    // Body
    Writer.WriteLine('  <tbody>');
    IsAlt := False;
    for Row := Grid.FixedRows to Grid.RowCount - 1 do
    begin
      if IsAlt then
        RowClass := Options.AltRowClass
      else
        RowClass := Options.RowClass;
        
      Writer.WriteLine('    <tr class="' + RowClass + '">');
      for Col := 0 to Grid.ColCount - 1 do
        Writer.WriteLine('      <td>' + EscapeHTML(Grid.Cells[Col, Row]) + '</td>');
      Writer.WriteLine('    </tr>');
      
      IsAlt := not IsAlt;
    end;
    Writer.WriteLine('  </tbody>');
    Writer.WriteLine('</table>');
    
    Writer.WriteLine('<p style="color: #888; font-size: 12px;">');
    Writer.WriteLine('  Generated by DeepBase on ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Writer.WriteLine('</p>');
    Writer.WriteLine('</body>');
    Writer.WriteLine('</html>');
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.GridToHTML(Grid: TStringGrid; const FileName: string;
  const Title: string);
var
  Options: THTMLOptions;
begin
  Options := THTMLOptions.Default;
  if Title <> '' then
    Options.Title := Title;
  GridToHTML(Grid, FileName, Options);
end;

class procedure TDataExport.ArrayToHTML(const Data: TArray<TArray<string>>;
  const Headers: TArray<string>; const FileName: string;
  const Options: THTMLOptions);
var
  Writer: TStreamWriter;
  Row, Col: Integer;
  RowClass: string;
  IsAlt: Boolean;
begin
  Writer := TStreamWriter.Create(FileName, False, Options.Encoding);
  try
    // HTML Header
    Writer.WriteLine('<!DOCTYPE html>');
    Writer.WriteLine('<html>');
    Writer.WriteLine('<head>');
    Writer.WriteLine('  <meta charset="utf-8">');
    Writer.WriteLine('  <title>' + EscapeHTML(Options.Title) + '</title>');
    
    if Options.IncludeStyles then
      Writer.Write(GetDefaultCSS);
      
    Writer.WriteLine('</head>');
    Writer.WriteLine('<body>');
    Writer.WriteLine('<h1>' + EscapeHTML(Options.Title) + '</h1>');
    Writer.WriteLine('<table class="' + Options.TableClass + '">');
    
    // Header
    if Length(Headers) > 0 then
    begin
      Writer.WriteLine('  <thead>');
      Writer.WriteLine('    <tr>');
      for Col := 0 to High(Headers) do
        Writer.WriteLine('      <th>' + EscapeHTML(Headers[Col]) + '</th>');
      Writer.WriteLine('    </tr>');
      Writer.WriteLine('  </thead>');
    end;
    
    // Body
    Writer.WriteLine('  <tbody>');
    IsAlt := False;
    for Row := 0 to High(Data) do
    begin
      if IsAlt then
        RowClass := Options.AltRowClass
      else
        RowClass := Options.RowClass;
        
      Writer.WriteLine('    <tr class="' + RowClass + '">');
      for Col := 0 to High(Data[Row]) do
        Writer.WriteLine('      <td>' + EscapeHTML(Data[Row][Col]) + '</td>');
      Writer.WriteLine('    </tr>');
      
      IsAlt := not IsAlt;
    end;
    Writer.WriteLine('  </tbody>');
    Writer.WriteLine('</table>');
    
    Writer.WriteLine('<p style="color: #888; font-size: 12px;">');
    Writer.WriteLine('  Generated by DeepBase on ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
    Writer.WriteLine('</p>');
    Writer.WriteLine('</body>');
    Writer.WriteLine('</html>');
  finally
    Writer.Free;
  end;
end;

class procedure TDataExport.ArrayToHTML(const Data: TArray<TArray<string>>;
  const Headers: TArray<string>; const FileName: string; const Title: string);
var
  Options: THTMLOptions;
begin
  Options := THTMLOptions.Default;
  if Title <> '' then
    Options.Title := Title;
  ArrayToHTML(Data, Headers, FileName, Options);
end;

// ============================================================================
// Quick Export
// ============================================================================

class procedure TDataExport.ToCSV(DataSet: TDataSet; const FileName: string);
begin
  DataSetToCSV(DataSet, FileName, TCSVOptions.Default);
end;

class procedure TDataExport.ToCSV(Grid: TStringGrid; const FileName: string);
begin
  GridToCSV(Grid, FileName, TCSVOptions.Default);
end;

class procedure TDataExport.ToHTML(DataSet: TDataSet; const FileName: string;
  const Title: string);
begin
  DataSetToHTML(DataSet, FileName, Title);
end;

class procedure TDataExport.ToHTML(Grid: TStringGrid; const FileName: string;
  const Title: string);
begin
  GridToHTML(Grid, FileName, Title);
end;

// ========================================
// JSON Export
// ========================================

class function TDataExport.DataSetToJSON(DataSet: TDataSet): string;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  I: Integer;
begin
  LArray := TJSONArray.Create;
  try
    if not DataSet.Active then
      DataSet.Open;
    DataSet.First;
    while not DataSet.Eof do
    begin
      LObj := TJSONObject.Create;
      for I := 0 to DataSet.FieldCount - 1 do
        LObj.AddPair(DataSet.Fields[I].FieldName, TJSONString.Create(DataSet.Fields[I].AsString));
      LArray.AddElement(LObj);
      DataSet.Next;
    end;
    Result := LArray.Format(2);
  finally
    LArray.Free;
  end;
end;

class function TDataExport.GridToJSON(Grid: TStringGrid): string;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  Row, Col: Integer;
begin
  LArray := TJSONArray.Create;
  try
    for Row := Grid.FixedRows to Grid.RowCount - 1 do
    begin
      LObj := TJSONObject.Create;
      for Col := Grid.FixedCols to Grid.ColCount - 1 do
        LObj.AddPair(Grid.Cells[Col, 0], TJSONString.Create(Grid.Cells[Col, Row]));
      LArray.AddElement(LObj);
    end;
    Result := LArray.Format(2);
  finally
    LArray.Free;
  end;
end;

class function TDataExport.ArrayToJSON(const Data: TArray<TArray<string>>;
  const Headers: TArray<string>): string;
var
  LArray: TJSONArray;
  LObj: TJSONObject;
  Row, Col: Integer;
begin
  LArray := TJSONArray.Create;
  try
    for Row := 0 to Length(Data) - 1 do
    begin
      LObj := TJSONObject.Create;
      for Col := 0 to Min(Length(Headers), Length(Data[Row])) - 1 do
        LObj.AddPair(Headers[Col], TJSONString.Create(Data[Row][Col]));
      LArray.AddElement(LObj);
    end;
    Result := LArray.Format(2);
  finally
    LArray.Free;
  end;
end;

class procedure TDataExport.ToJSON(DataSet: TDataSet; const FileName: string);
var
  LStr: string;
begin
  LStr := DataSetToJSON(DataSet);
  TFile.WriteAllText(FileName, LStr, TEncoding.UTF8);
end;

end.
