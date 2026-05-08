unit Test.DeepBase.Export;

{*******************************************************************************
  Unit Tests for DeepBase.Export
  Tests CSV and HTML export functionality for arrays
  Note: DataSet and StringGrid tests are excluded as they require VCL components
*******************************************************************************}

interface

{$IFDEF TESTDeepInsight}
uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestExport = class
  private
    FTempDir: string;
    function GetTempFileName(const Ext: string): string;
    function ReadFileContent(const FileName: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    // TCSVOptions Tests
    [Test]
    procedure TestCSVOptionsDefault;
    [Test]
    procedure TestCSVOptionsCustom;

    // THTMLOptions Tests
    [Test]
    procedure TestHTMLOptionsDefault;
    [Test]
    procedure TestHTMLOptionsCustom;

    // TExportColumn Tests
    [Test]
    procedure TestExportColumnCreate;
    [Test]
    procedure TestExportColumnDefaultTitle;

    // ArrayToCSV Tests
    [Test]
    procedure TestArrayToCSVBasic;
    [Test]
    procedure TestArrayToCSVWithOptions;
    [Test]
    procedure TestArrayToCSVCustomDelimiter;
    [Test]
    procedure TestArrayToCSVWithQuotes;
    [Test]
    procedure TestArrayToCSVQuoteAllFields;
    [Test]
    procedure TestArrayToCSVEscapeDelimiter;
    [Test]
    procedure TestArrayToCSVEscapeQuotes;
    [Test]
    procedure TestArrayToCSVEscapeNewlines;
    [Test]
    procedure TestArrayToCSVEmpty;
    [Test]
    procedure TestArrayToCSVSingleRow;
    [Test]
    procedure TestArrayToCSVSingleColumn;

    // ArrayToHTML Tests
    [Test]
    procedure TestArrayToHTMLBasic;
    [Test]
    procedure TestArrayToHTMLWithTitle;
    [Test]
    procedure TestArrayToHTMLWithOptions;
    [Test]
    procedure TestArrayToHTMLEscapeChars;
    [Test]
    procedure TestArrayToHTMLEmpty;
    [Test]
    procedure TestArrayToHTMLIncludesStyle;
    [Test]
    procedure TestArrayToHTMLNoStyle;
  end;
{$ENDIF}

implementation

{$IFDEF TESTDeepInsight}
uses
  System.SysUtils, System.Classes, System.IOUtils,
  DeepBase.Export;

{ TTestExport }

procedure TTestExport.Setup;
begin
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBaseExportTest_' + FormatDateTime('yyyymmddhhnnss', Now));
  ForceDirectories(FTempDir);
end;

procedure TTestExport.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestExport.GetTempFileName(const Ext: string): string;
begin
  Result := TPath.Combine(FTempDir, 'test' + FormatDateTime('hhnnsszzz', Now) + Ext);
end;

function TTestExport.ReadFileContent(const FileName: string): string;
begin
  Result := TFile.ReadAllText(FileName, TEncoding.UTF8);
end;

// ============================================================================
// TCSVOptions Tests
// ============================================================================

procedure TTestExport.TestCSVOptionsDefault;
var
  Opts: TCSVOptions;
begin
  Opts := TCSVOptions.Default;
  
  Assert.AreEqual(',', Opts.Delimiter);
  Assert.AreEqual('"', Opts.QuoteChar);
  Assert.IsTrue(Opts.IncludeHeader);
  Assert.IsFalse(Opts.QuoteAllFields);
  Assert.AreEqual(sLineBreak, Opts.LineBreak);
end;

procedure TTestExport.TestCSVOptionsCustom;
var
  Opts: TCSVOptions;
begin
  Opts := TCSVOptions.Default;
  Opts.Delimiter := ';';
  Opts.QuoteChar := '''';
  Opts.QuoteAllFields := True;
  Opts.IncludeHeader := False;
  
  Assert.AreEqual(';', Opts.Delimiter);
  Assert.AreEqual('''', Opts.QuoteChar);
  Assert.IsTrue(Opts.QuoteAllFields);
  Assert.IsFalse(Opts.IncludeHeader);
end;

// ============================================================================
// THTMLOptions Tests
// ============================================================================

procedure TTestExport.TestHTMLOptionsDefault;
var
  Opts: THTMLOptions;
begin
  Opts := THTMLOptions.Default;
  
  Assert.AreEqual('Data Export', Opts.Title);
  Assert.AreEqual('data-table', Opts.TableClass);
  Assert.AreEqual('header', Opts.HeaderClass);
  Assert.AreEqual('row', Opts.RowClass);
  Assert.AreEqual('row-alt', Opts.AltRowClass);
  Assert.IsTrue(Opts.IncludeStyles);
end;

procedure TTestExport.TestHTMLOptionsCustom;
var
  Opts: THTMLOptions;
begin
  Opts := THTMLOptions.Default;
  Opts.Title := 'My Report';
  Opts.TableClass := 'custom-table';
  Opts.IncludeStyles := False;
  
  Assert.AreEqual('My Report', Opts.Title);
  Assert.AreEqual('custom-table', Opts.TableClass);
  Assert.IsFalse(Opts.IncludeStyles);
end;

// ============================================================================
// TExportColumn Tests
// ============================================================================

procedure TTestExport.TestExportColumnCreate;
var
  Col: TExportColumn;
begin
  Col := TExportColumn.Create('field_name', 'Display Title', 100);
  
  Assert.AreEqual('field_name', Col.FieldName);
  Assert.AreEqual('Display Title', Col.Title);
  Assert.AreEqual(100, Col.Width);
end;

procedure TTestExport.TestExportColumnDefaultTitle;
var
  Col: TExportColumn;
begin
  Col := TExportColumn.Create('my_field');
  
  Assert.AreEqual('my_field', Col.FieldName);
  Assert.AreEqual('my_field', Col.Title);  // Title defaults to FieldName
  Assert.AreEqual(0, Col.Width);
end;

// ============================================================================
// ArrayToCSV Tests
// ============================================================================

procedure TTestExport.TestArrayToCSVBasic;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Name', 'Age', 'City'],
    ['Alice', '25', 'New York'],
    ['Bob', '30', 'Los Angeles']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('Name,Age,City'));
  Assert.IsTrue(Content.Contains('Alice,25,New York'));
  Assert.IsTrue(Content.Contains('Bob,30,Los Angeles'));
end;

procedure TTestExport.TestArrayToCSVWithOptions;
var
  Data: TArray<TArray<string>>;
  Opts: TCSVOptions;
  FileName, Content: string;
begin
  Data := [
    ['A', 'B'],
    ['1', '2']
  ];
  
  Opts := TCSVOptions.Default;
  Opts.Delimiter := ';';
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('A;B'));
  Assert.IsTrue(Content.Contains('1;2'));
end;

procedure TTestExport.TestArrayToCSVCustomDelimiter;
var
  Data: TArray<TArray<string>>;
  Opts: TCSVOptions;
  FileName, Content: string;
begin
  Data := [
    ['Col1', 'Col2', 'Col3'],
    ['a', 'b', 'c']
  ];
  
  Opts := TCSVOptions.Default;
  Opts.Delimiter := #9;  // Tab delimiter
  
  FileName := GetTempFileName('.tsv');
  TDataExport.ArrayToCSV(Data, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('Col1'#9'Col2'#9'Col3'));
end;

procedure TTestExport.TestArrayToCSVWithQuotes;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Name', 'Description'],
    ['Test', 'Contains "quotes"']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  // Quotes should be escaped by doubling
  Assert.IsTrue(Content.Contains('Contains ""quotes""'));
end;

procedure TTestExport.TestArrayToCSVQuoteAllFields;
var
  Data: TArray<TArray<string>>;
  Opts: TCSVOptions;
  FileName, Content: string;
begin
  Data := [
    ['Simple', 'Values'],
    ['a', 'b']
  ];
  
  Opts := TCSVOptions.Default;
  Opts.QuoteAllFields := True;
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('"Simple","Values"'));
  Assert.IsTrue(Content.Contains('"a","b"'));
end;

procedure TTestExport.TestArrayToCSVEscapeDelimiter;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Field'],
    ['Value, with comma']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  // Values with delimiters should be quoted
  Assert.IsTrue(Content.Contains('"Value, with comma"'));
end;

procedure TTestExport.TestArrayToCSVEscapeQuotes;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Quote Test'],
    ['He said "Hello"']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  // Internal quotes should be doubled and field quoted
  Assert.IsTrue(Content.Contains('"He said ""Hello"""'));
end;

procedure TTestExport.TestArrayToCSVEscapeNewlines;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Multiline'],
    ['Line1' + #13#10 + 'Line2']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  // Values with newlines should be quoted
  Assert.IsTrue(Content.Contains('"Line1'));
end;

procedure TTestExport.TestArrayToCSVEmpty;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  SetLength(Data, 0);
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.AreEqual('', Trim(Content));
end;

procedure TTestExport.TestArrayToCSVSingleRow;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['One', 'Two', 'Three']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('One,Two,Three'));
end;

procedure TTestExport.TestArrayToCSVSingleColumn;
var
  Data: TArray<TArray<string>>;
  FileName, Content: string;
begin
  Data := [
    ['Header'],
    ['Row1'],
    ['Row2'],
    ['Row3']
  ];
  
  FileName := GetTempFileName('.csv');
  TDataExport.ArrayToCSV(Data, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('Header'));
  Assert.IsTrue(Content.Contains('Row1'));
  Assert.IsTrue(Content.Contains('Row2'));
  Assert.IsTrue(Content.Contains('Row3'));
end;

// ============================================================================
// ArrayToHTML Tests
// ============================================================================

procedure TTestExport.TestArrayToHTMLBasic;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  FileName, Content: string;
begin
  Data := [
    ['Alice', '25'],
    ['Bob', '30']
  ];
  Headers := ['Name', 'Age'];
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('<!DOCTYPE html>'));
  Assert.IsTrue(Content.Contains('<table'));
  Assert.IsTrue(Content.Contains('<th>Name</th>'));
  Assert.IsTrue(Content.Contains('<th>Age</th>'));
  Assert.IsTrue(Content.Contains('<td>Alice</td>'));
  Assert.IsTrue(Content.Contains('<td>25</td>'));
  Assert.IsTrue(Content.Contains('</table>'));
end;

procedure TTestExport.TestArrayToHTMLWithTitle;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  FileName, Content: string;
begin
  Data := [['A']];
  Headers := ['Col'];
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName, 'My Custom Title');
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('<title>My Custom Title</title>'));
  Assert.IsTrue(Content.Contains('<h1>My Custom Title</h1>'));
end;

procedure TTestExport.TestArrayToHTMLWithOptions;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  Opts: THTMLOptions;
  FileName, Content: string;
begin
  Data := [['X']];
  Headers := ['Header'];
  
  Opts := THTMLOptions.Default;
  Opts.Title := 'Custom Report';
  Opts.TableClass := 'my-table';
  Opts.RowClass := 'my-row';
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('class="my-table"'));
  Assert.IsTrue(Content.Contains('class="my-row"'));
end;

procedure TTestExport.TestArrayToHTMLEscapeChars;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  FileName, Content: string;
begin
  Data := [['<script>alert("XSS")</script>']];
  Headers := ['Unsafe & Content'];
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName);
  
  Content := ReadFileContent(FileName);
  // HTML entities should be escaped
  Assert.IsTrue(Content.Contains('&lt;script&gt;'));
  Assert.IsTrue(Content.Contains('&amp;'));
  Assert.IsFalse(Content.Contains('<script>alert'));  // Should NOT contain raw script
end;

procedure TTestExport.TestArrayToHTMLEmpty;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  FileName, Content: string;
begin
  SetLength(Data, 0);
  Headers := ['Empty'];
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('<!DOCTYPE html>'));
  Assert.IsTrue(Content.Contains('<table'));
  Assert.IsTrue(Content.Contains('<th>Empty</th>'));
  Assert.IsTrue(Content.Contains('<tbody>'));
end;

procedure TTestExport.TestArrayToHTMLIncludesStyle;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  Opts: THTMLOptions;
  FileName, Content: string;
begin
  Data := [['A']];
  Headers := ['Col'];
  
  Opts := THTMLOptions.Default;
  Opts.IncludeStyles := True;
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsTrue(Content.Contains('<style>'));
  Assert.IsTrue(Content.Contains('border-collapse'));
end;

procedure TTestExport.TestArrayToHTMLNoStyle;
var
  Data: TArray<TArray<string>>;
  Headers: TArray<string>;
  Opts: THTMLOptions;
  FileName, Content: string;
begin
  Data := [['A']];
  Headers := ['Col'];
  
  Opts := THTMLOptions.Default;
  Opts.IncludeStyles := False;
  
  FileName := GetTempFileName('.html');
  TDataExport.ArrayToHTML(Data, Headers, FileName, Opts);
  
  Content := ReadFileContent(FileName);
  Assert.IsFalse(Content.Contains('<style>'));
end;

{$ENDIF}

end.
