unit Report.Generator;

{*******************************************************************************
  Data Analyzer Template - Report Generator
  
  Generates reports in various formats (Text, HTML, CSV, JSON).
  
  Features demonstrated:
  - Template-based report generation
  - Multiple output formats
  - Data formatting utilities
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Analysis.Engine;

type
  TReportFormat = (rfText, rfHTML, rfCSV, rfJSON);

  /// <summary>
  /// Report section with title and content
  /// </summary>
  TReportSection = record
    Title: string;
    Content: string;
    Data: TArray<TArray<string>>;  // Table data (rows x columns)
    Headers: TArray<string>;       // Column headers
  end;

  /// <summary>
  /// Report generator class
  /// </summary>
  TReportGenerator = class
  private
    FTitle: string;
    FSubtitle: string;
    FAuthor: string;
    FGeneratedAt: TDateTime;
    FSections: TList<TReportSection>;
    
    function GenerateTextReport: string;
    function GenerateHTMLReport: string;
    function GenerateCSVReport: string;
    function GenerateJSONReport: string;
    
    function FormatNumber(Value: Double; Decimals: Integer = 2): string;
    function EscapeHTML(const S: string): string;
    function EscapeCSV(const S: string): string;
    function EscapeJSON(const S: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Report configuration
    property Title: string read FTitle write FTitle;
    property Subtitle: string read FSubtitle write FSubtitle;
    property Author: string read FAuthor write FAuthor;
    
    // Section management
    procedure AddSection(const ATitle, AContent: string); overload;
    procedure AddSection(const ATitle: string; const AHeaders: TArray<string>;
      const AData: TArray<TArray<string>>); overload;
    procedure AddStatsSection(const ATitle: string; const Stats: TStatsSummary);
    procedure AddTrendSection(const ATitle: string; const Trend: TTrendResult);
    procedure AddGroupSection(const ATitle: string; const Groups: TGroupResults);
    procedure ClearSections;
    
    // Generation
    function Generate(Format: TReportFormat): string;
    procedure SaveToFile(const FileName: string; Format: TReportFormat);
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  UniBase.Logging;

{ TReportGenerator }

constructor TReportGenerator.Create;
begin
  inherited;
  FSections := TList<TReportSection>.Create;
  FGeneratedAt := Now;
  FAuthor := 'Data Analyzer';
end;

destructor TReportGenerator.Destroy;
begin
  FSections.Free;
  inherited;
end;

procedure TReportGenerator.AddSection(const ATitle, AContent: string);
var
  Section: TReportSection;
begin
  Section.Title := ATitle;
  Section.Content := AContent;
  SetLength(Section.Headers, 0);
  SetLength(Section.Data, 0);
  FSections.Add(Section);
end;

procedure TReportGenerator.AddSection(const ATitle: string;
  const AHeaders: TArray<string>; const AData: TArray<TArray<string>>);
var
  Section: TReportSection;
begin
  Section.Title := ATitle;
  Section.Content := '';
  Section.Headers := AHeaders;
  Section.Data := AData;
  FSections.Add(Section);
end;

procedure TReportGenerator.AddStatsSection(const ATitle: string;
  const Stats: TStatsSummary);
var
  Headers: TArray<string>;
  Data: TArray<TArray<string>>;
begin
  Headers := ['Metric', 'Value'];
  SetLength(Data, 11);
  
  Data[0] := ['Count', IntToStr(Stats.Count)];
  Data[1] := ['Sum', FormatNumber(Stats.Sum)];
  Data[2] := ['Mean', FormatNumber(Stats.Mean)];
  Data[3] := ['Median', FormatNumber(Stats.Median)];
  Data[4] := ['Std Dev', FormatNumber(Stats.StdDev)];
  Data[5] := ['Variance', FormatNumber(Stats.Variance)];
  Data[6] := ['Min', FormatNumber(Stats.Min)];
  Data[7] := ['Max', FormatNumber(Stats.Max)];
  Data[8] := ['Range', FormatNumber(Stats.Range)];
  Data[9] := ['Q1 (25%)', FormatNumber(Stats.Q1)];
  Data[10] := ['Q3 (75%)', FormatNumber(Stats.Q3)];
  
  AddSection(ATitle, Headers, Data);
end;

procedure TReportGenerator.AddTrendSection(const ATitle: string;
  const Trend: TTrendResult);
var
  Headers: TArray<string>;
  Data: TArray<TArray<string>>;
begin
  Headers := ['Metric', 'Value'];
  SetLength(Data, 4);
  
  Data[0] := ['Trend Direction', Trend.Trend];
  Data[1] := ['Slope', FormatNumber(Trend.Slope, 4)];
  Data[2] := ['Intercept', FormatNumber(Trend.Intercept, 4)];
  Data[3] := ['R²', FormatNumber(Trend.RSquared, 4)];
  
  AddSection(ATitle, Headers, Data);
end;

procedure TReportGenerator.AddGroupSection(const ATitle: string;
  const Groups: TGroupResults);
var
  Headers: TArray<string>;
  Data: TArray<TArray<string>>;
  I: Integer;
begin
  Headers := ['Group', 'Count', 'Sum', 'Average', 'Min', 'Max'];
  SetLength(Data, Length(Groups));
  
  for I := 0 to High(Groups) do
  begin
    SetLength(Data[I], 6);
    Data[I][0] := Groups[I].GroupKey;
    Data[I][1] := IntToStr(Groups[I].Count);
    Data[I][2] := FormatNumber(Groups[I].Sum);
    Data[I][3] := FormatNumber(Groups[I].Average);
    Data[I][4] := FormatNumber(Groups[I].Min);
    Data[I][5] := FormatNumber(Groups[I].Max);
  end;
  
  AddSection(ATitle, Headers, Data);
end;

procedure TReportGenerator.ClearSections;
begin
  FSections.Clear;
end;

function TReportGenerator.Generate(Format: TReportFormat): string;
begin
  FGeneratedAt := Now;
  
  case Format of
    rfText: Result := GenerateTextReport;
    rfHTML: Result := GenerateHTMLReport;
    rfCSV: Result := GenerateCSVReport;
    rfJSON: Result := GenerateJSONReport;
  else
    Result := GenerateTextReport;
  end;
end;

procedure TReportGenerator.SaveToFile(const FileName: string;
  Format: TReportFormat);
var
  Content: string;
begin
  Content := Generate(Format);
  TFile.WriteAllText(FileName, Content, TEncoding.UTF8);
  Log.Info('Report saved: %s', [FileName]);
end;

function TReportGenerator.GenerateTextReport: string;
var
  SB: TStringBuilder;
  Section: TReportSection;
  Row: TArray<string>;
  I, J: Integer;
  ColWidths: TArray<Integer>;
  Line: string;
begin
  SB := TStringBuilder.Create;
  try
    // Header
    SB.AppendLine('=' + StringOfChar('=', 78));
    SB.AppendLine(FTitle);
    if FSubtitle <> '' then
      SB.AppendLine(FSubtitle);
    SB.AppendLine('Generated: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', FGeneratedAt));
    SB.AppendLine('Author: ' + FAuthor);
    SB.AppendLine('=' + StringOfChar('=', 78));
    SB.AppendLine;
    
    // Sections
    for Section in FSections do
    begin
      SB.AppendLine(Section.Title);
      SB.AppendLine(StringOfChar('-', Length(Section.Title)));
      
      if Section.Content <> '' then
        SB.AppendLine(Section.Content);
      
      if Length(Section.Headers) > 0 then
      begin
        // Calculate column widths
        SetLength(ColWidths, Length(Section.Headers));
        for I := 0 to High(Section.Headers) do
          ColWidths[I] := Length(Section.Headers[I]);
        
        for Row in Section.Data do
          for I := 0 to High(Row) do
            if I < Length(ColWidths) then
              if Length(Row[I]) > ColWidths[I] then
                ColWidths[I] := Length(Row[I]);
        
        // Print header
        Line := '';
        for I := 0 to High(Section.Headers) do
        begin
          if I > 0 then Line := Line + ' | ';
          Line := Line + Format('%-' + IntToStr(ColWidths[I]) + 's', [Section.Headers[I]]);
        end;
        SB.AppendLine(Line);
        
        // Print separator
        Line := '';
        for I := 0 to High(Section.Headers) do
        begin
          if I > 0 then Line := Line + '-+-';
          Line := Line + StringOfChar('-', ColWidths[I]);
        end;
        SB.AppendLine(Line);
        
        // Print data
        for Row in Section.Data do
        begin
          Line := '';
          for I := 0 to High(Row) do
          begin
            if I > 0 then Line := Line + ' | ';
            if I < Length(ColWidths) then
              Line := Line + Format('%-' + IntToStr(ColWidths[I]) + 's', [Row[I]])
            else
              Line := Line + Row[I];
          end;
          SB.AppendLine(Line);
        end;
      end;
      
      SB.AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TReportGenerator.GenerateHTMLReport: string;
var
  SB: TStringBuilder;
  Section: TReportSection;
  Row: TArray<string>;
  Cell: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('<!DOCTYPE html>');
    SB.AppendLine('<html>');
    SB.AppendLine('<head>');
    SB.AppendLine('<meta charset="UTF-8">');
    SB.AppendLine('<title>' + EscapeHTML(FTitle) + '</title>');
    SB.AppendLine('<style>');
    SB.AppendLine('body { font-family: Arial, sans-serif; margin: 20px; }');
    SB.AppendLine('h1 { color: #333; }');
    SB.AppendLine('h2 { color: #666; margin-top: 30px; }');
    SB.AppendLine('table { border-collapse: collapse; margin: 10px 0; }');
    SB.AppendLine('th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }');
    SB.AppendLine('th { background-color: #4472c4; color: white; }');
    SB.AppendLine('tr:nth-child(even) { background-color: #f2f2f2; }');
    SB.AppendLine('.meta { color: #888; font-size: 0.9em; }');
    SB.AppendLine('</style>');
    SB.AppendLine('</head>');
    SB.AppendLine('<body>');
    
    // Header
    SB.AppendLine('<h1>' + EscapeHTML(FTitle) + '</h1>');
    if FSubtitle <> '' then
      SB.AppendLine('<p>' + EscapeHTML(FSubtitle) + '</p>');
    SB.AppendLine('<p class="meta">Generated: ' + 
      FormatDateTime('yyyy-mm-dd hh:nn:ss', FGeneratedAt) + 
      ' | Author: ' + EscapeHTML(FAuthor) + '</p>');
    
    // Sections
    for Section in FSections do
    begin
      SB.AppendLine('<h2>' + EscapeHTML(Section.Title) + '</h2>');
      
      if Section.Content <> '' then
        SB.AppendLine('<p>' + EscapeHTML(Section.Content) + '</p>');
      
      if Length(Section.Headers) > 0 then
      begin
        SB.AppendLine('<table>');
        SB.Append('<tr>');
        for Cell in Section.Headers do
          SB.Append('<th>' + EscapeHTML(Cell) + '</th>');
        SB.AppendLine('</tr>');
        
        for Row in Section.Data do
        begin
          SB.Append('<tr>');
          for Cell in Row do
            SB.Append('<td>' + EscapeHTML(Cell) + '</td>');
          SB.AppendLine('</tr>');
        end;
        SB.AppendLine('</table>');
      end;
    end;
    
    SB.AppendLine('</body>');
    SB.AppendLine('</html>');
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TReportGenerator.GenerateCSVReport: string;
var
  SB: TStringBuilder;
  Section: TReportSection;
  Row: TArray<string>;
  I: Integer;
  First: Boolean;
begin
  SB := TStringBuilder.Create;
  try
    // Header info as comments
    SB.AppendLine('# ' + FTitle);
    if FSubtitle <> '' then
      SB.AppendLine('# ' + FSubtitle);
    SB.AppendLine('# Generated: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', FGeneratedAt));
    SB.AppendLine;
    
    // Sections (only tables)
    for Section in FSections do
    begin
      if Length(Section.Headers) = 0 then
        Continue;
      
      SB.AppendLine('# ' + Section.Title);
      
      // Headers
      First := True;
      for I := 0 to High(Section.Headers) do
      begin
        if not First then SB.Append(',');
        SB.Append(EscapeCSV(Section.Headers[I]));
        First := False;
      end;
      SB.AppendLine;
      
      // Data
      for Row in Section.Data do
      begin
        First := True;
        for I := 0 to High(Row) do
        begin
          if not First then SB.Append(',');
          SB.Append(EscapeCSV(Row[I]));
          First := False;
        end;
        SB.AppendLine;
      end;
      
      SB.AppendLine;
    end;
    
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TReportGenerator.GenerateJSONReport: string;
var
  Root, SectionsArr, SectionObj, DataArr, RowArr: TJSONObject;
  Section: TReportSection;
  Row: TArray<string>;
  Cell: string;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('title', FTitle);
    Root.AddPair('subtitle', FSubtitle);
    Root.AddPair('author', FAuthor);
    Root.AddPair('generated', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', FGeneratedAt));
    
    SectionsArr := TJSONArray.Create;
    for Section in FSections do
    begin
      SectionObj := TJSONObject.Create;
      SectionObj.AddPair('title', Section.Title);
      
      if Section.Content <> '' then
        SectionObj.AddPair('content', Section.Content);
      
      if Length(Section.Headers) > 0 then
      begin
        SectionObj.AddPair('headers', TJSONArray.Create(Section.Headers));
        
        DataArr := TJSONArray.Create;
        for Row in Section.Data do
        begin
          RowArr := TJSONArray.Create;
          for Cell in Row do
            TJSONArray(RowArr).Add(Cell);
          DataArr.AddElement(RowArr);
        end;
        SectionObj.AddPair('data', DataArr);
      end;
      
      TJSONArray(SectionsArr).AddElement(SectionObj);
    end;
    Root.AddPair('sections', SectionsArr);
    
    Result := Root.Format(2);
  finally
    Root.Free;
  end;
end;

function TReportGenerator.FormatNumber(Value: Double; Decimals: Integer): string;
begin
  Result := FormatFloat('0.' + StringOfChar('0', Decimals), Value);
end;

function TReportGenerator.EscapeHTML(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function TReportGenerator.EscapeCSV(const S: string): string;
begin
  if (Pos(',', S) > 0) or (Pos('"', S) > 0) or (Pos(#13, S) > 0) or (Pos(#10, S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := S;
end;

function TReportGenerator.EscapeJSON(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

end.
