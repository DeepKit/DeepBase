{ ============================================================================
  Studio.I18nScanner - i18n Source Code Scanner
  
  Version: 1.0
  Description: Scans Delphi source code to collect translatable texts
  Features:
    - Scan T('...') and TFmt('...') calls
    - Scan TextKey properties in .dfm files
    - Scan resourcestring declarations
    - Generate translation entry list
    - Support incremental scanning
  ============================================================================ }

unit Studio.I18nScanner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.RegularExpressions,
  System.Generics.Collections,
  FireDAC.Comp.Client;

type
  /// <summary>
  /// Scan result entry
  /// </summary>
  TI18nEntry = record
    TextKey: string;        // Original text/Key
    SourceFile: string;     // Source file path
    LineNumber: Integer;    // Line number
    Context: string;        // Context (function name, control name, etc.)
    EntryType: string;      // Type: T_Call, TFmt_Call, TextKey, ResourceString
    IsNew: Boolean;         // Whether entry is new (not in database)
    
    procedure Clear;
  end;
  
  TI18nEntryArray = TArray<TI18nEntry>;
  
  /// <summary>
  /// Scan progress callback
  /// </summary>
  TI18nScanProgress = reference to procedure(const FileName: string; 
    Current, Total: Integer);
  
  /// <summary>
  /// i18n Source Code Scanner
  /// </summary>
  TI18nScanner = class
  private
    FConnection: TFDConnection;
    FEntries: TList<TI18nEntry>;
    FScannedFiles: TStringList;
    FOnProgress: TI18nScanProgress;
    FExcludePatterns: TStringList;
    
    // Regular expression patterns
    FPatternT: TRegEx;
    FPatternTFmt: TRegEx;
    FPatternResourceString: TRegEx;
    FPatternTextKey: TRegEx;
    
    procedure InitPatterns;
    procedure ScanPasFile(const FileName: string);
    procedure ScanDfmFile(const FileName: string);
    procedure AddEntry(const AEntry: TI18nEntry);
    function IsExcluded(const FileName: string): Boolean;
    function EntryExistsInDB(const TextKey: string): Boolean;
    
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    
    /// <summary>
    /// Scan a single file
    /// </summary>
    procedure ScanFile(const FileName: string);
    
    /// <summary>
    /// Scan directory (recursive)
    /// </summary>
    procedure ScanDirectory(const Directory: string; Recursive: Boolean = True);
    
    /// <summary>
    /// Scan project (.dproj file)
    /// </summary>
    procedure ScanProject(const ProjectFile: string);
    
    /// <summary>
    /// Get scan results
    /// </summary>
    function GetEntries: TI18nEntryArray;
    
    /// <summary>
    /// Get new entries (not in database)
    /// </summary>
    function GetNewEntries: TI18nEntryArray;
    
    /// <summary>
    /// Get scan statistics
    /// </summary>
    procedure GetStats(out TotalFiles, TotalEntries, NewEntries: Integer);
    
    /// <summary>
    /// Import new entries to database
    /// </summary>
    function ImportNewEntries(const DefaultLanguage: string = 'zh-CN'): Integer;
    
    /// <summary>
    /// Clear scan results
    /// </summary>
    procedure Clear;
    
    /// <summary>
    /// Add exclude pattern (supports wildcards)
    /// </summary>
    procedure AddExcludePattern(const Pattern: string);
    
    /// <summary>
    /// Progress callback
    /// </summary>
    property OnProgress: TI18nScanProgress read FOnProgress write FOnProgress;
  end;

implementation

{ TI18nEntry }

procedure TI18nEntry.Clear;
begin
  TextKey := '';
  SourceFile := '';
  LineNumber := 0;
  Context := '';
  EntryType := '';
  IsNew := False;
end;

{ TI18nScanner }

constructor TI18nScanner.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FEntries := TList<TI18nEntry>.Create;
  FScannedFiles := TStringList.Create;
  FScannedFiles.Sorted := True;
  FScannedFiles.Duplicates := dupIgnore;
  FExcludePatterns := TStringList.Create;
  
  // Default exclusions
  FExcludePatterns.Add('*.dcu');
  FExcludePatterns.Add('__history\*');
  FExcludePatterns.Add('__recovery\*');
  
  InitPatterns;
end;

destructor TI18nScanner.Destroy;
begin
  FEntries.Free;
  FScannedFiles.Free;
  FExcludePatterns.Free;
  inherited;
end;

procedure TI18nScanner.InitPatterns;
begin
  // T('string') 或 T("string")
  FPatternT := TRegEx.Create('\bT\s*\(\s*''([^'']+)''\s*\)', [roIgnoreCase]);
  
  // TFmt('string', [...]) 
  FPatternTFmt := TRegEx.Create('\bTFmt\s*\(\s*''([^'']+)''\s*,', [roIgnoreCase]);
  
  // resourcestring Name = 'value';
  FPatternResourceString := TRegEx.Create(
    '^\s*(\w+)\s*=\s*''([^'']+)''\s*;', [roIgnoreCase, roMultiLine]);
  
  // TextKey = 'value' in DFM
  FPatternTextKey := TRegEx.Create(
    'TextKey\s*=\s*''([^'']+)''', [roIgnoreCase]);
end;

function TI18nScanner.IsExcluded(const FileName: string): Boolean;
var
  Pattern: string;
begin
  Result := False;
  for Pattern in FExcludePatterns do
  begin
    if TPath.MatchesPattern(FileName, Pattern, False) then
      Exit(True);
  end;
end;

function TI18nScanner.EntryExistsInDB(const TextKey: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT 1 FROM I18nTexts WHERE TextKey = :Key LIMIT 1';
    Query.ParamByName('Key').AsString := TextKey;
    Query.Open;
    Result := not Query.IsEmpty;
  finally
    Query.Free;
  end;
end;

procedure TI18nScanner.AddEntry(const AEntry: TI18nEntry);
var
  Entry: TI18nEntry;
  I: Integer;
begin
  // Check if same TextKey already exists
  for I := 0 to FEntries.Count - 1 do
  begin
    if FEntries[I].TextKey = AEntry.TextKey then
      Exit; // 去重
  end;
  
  Entry := AEntry;
  Entry.IsNew := not EntryExistsInDB(Entry.TextKey);
  FEntries.Add(Entry);
end;

procedure TI18nScanner.ScanPasFile(const FileName: string);
var
  Content: string;
  Lines: TArray<string>;
  Match: TMatch;
  Entry: TI18nEntry;
  I: Integer;
  InResourceString: Boolean;
  CurrentContext: string;
begin
  if not TFile.Exists(FileName) then
    Exit;
    
  try
    Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  except
  // Try ANSI
    try
      Content := TFile.ReadAllText(FileName, TEncoding.ANSI);
    except
      Exit;
    end;
  end;
  
  Lines := Content.Split([#13#10, #10]);
  InResourceString := False;
  CurrentContext := '';
  
  for I := 0 to High(Lines) do
  begin
    // Detect resourcestring block
    if Lines[I].Trim.ToLower.StartsWith('resourcestring') then
    begin
      InResourceString := True;
      Continue;
    end;
    
    // Detect function/procedure start (update context)
    if TRegEx.IsMatch(Lines[I], '^\s*(procedure|function)\s+(\w+)', [roIgnoreCase]) then
    begin
      InResourceString := False;
      Match := TRegEx.Match(Lines[I], '^\s*(procedure|function)\s+(\w+)', [roIgnoreCase]);
      if Match.Success and (Match.Groups.Count > 2) then
        CurrentContext := Match.Groups[2].Value;
    end;
    
    // Scan T() calls
    for Match in FPatternT.Matches(Lines[I]) do
    begin
      if Match.Groups.Count > 1 then
      begin
        Entry.Clear;
        Entry.TextKey := Match.Groups[1].Value;
        Entry.SourceFile := FileName;
        Entry.LineNumber := I + 1;
        Entry.Context := CurrentContext;
        Entry.EntryType := 'T_Call';
        AddEntry(Entry);
      end;
    end;
    
    // Scan TFmt() calls
    for Match in FPatternTFmt.Matches(Lines[I]) do
    begin
      if Match.Groups.Count > 1 then
      begin
        Entry.Clear;
        Entry.TextKey := Match.Groups[1].Value;
        Entry.SourceFile := FileName;
        Entry.LineNumber := I + 1;
        Entry.Context := CurrentContext;
        Entry.EntryType := 'TFmt_Call';
        AddEntry(Entry);
      end;
    end;
    
    // Scan resourcestring
    if InResourceString then
    begin
      Match := FPatternResourceString.Match(Lines[I]);
      if Match.Success and (Match.Groups.Count > 2) then
      begin
        Entry.Clear;
        Entry.TextKey := Match.Groups[2].Value;
        Entry.SourceFile := FileName;
        Entry.LineNumber := I + 1;
        Entry.Context := 'resourcestring.' + Match.Groups[1].Value;
        Entry.EntryType := 'ResourceString';
        AddEntry(Entry);
      end;
      
      // Detect resourcestring block end
      if Lines[I].Trim.ToLower.StartsWith('const') or 
         Lines[I].Trim.ToLower.StartsWith('var') or
         Lines[I].Trim.ToLower.StartsWith('type') or
         Lines[I].Trim.ToLower.StartsWith('implementation') then
        InResourceString := False;
    end;
  end;
end;

procedure TI18nScanner.ScanDfmFile(const FileName: string);
var
  Content: string;
  Lines: TArray<string>;
  Match: TMatch;
  Entry: TI18nEntry;
  I: Integer;
  CurrentObject: string;
begin
  if not TFile.Exists(FileName) then
    Exit;
    
  try
    Content := TFile.ReadAllText(FileName, TEncoding.UTF8);
  except
    try
      Content := TFile.ReadAllText(FileName, TEncoding.ANSI);
    except
      Exit;
    end;
  end;
  
  Lines := Content.Split([#13#10, #10]);
  CurrentObject := '';
  
  for I := 0 to High(Lines) do
  begin
    // Detect object declaration
    Match := TRegEx.Match(Lines[I], '^\s*object\s+(\w+)\s*:', [roIgnoreCase]);
    if Match.Success and (Match.Groups.Count > 1) then
      CurrentObject := Match.Groups[1].Value;
    
    // Scan TextKey property
    for Match in FPatternTextKey.Matches(Lines[I]) do
    begin
      if Match.Groups.Count > 1 then
      begin
        Entry.Clear;
        Entry.TextKey := Match.Groups[1].Value;
        Entry.SourceFile := FileName;
        Entry.LineNumber := I + 1;
        Entry.Context := CurrentObject;
        Entry.EntryType := 'TextKey';
        AddEntry(Entry);
      end;
    end;
  end;
end;

procedure TI18nScanner.ScanFile(const FileName: string);
var
  Ext: string;
begin
  if IsExcluded(FileName) then
    Exit;
    
  if FScannedFiles.IndexOf(FileName) >= 0 then
    Exit; // 已扫描
    
  FScannedFiles.Add(FileName);
  
  Ext := LowerCase(TPath.GetExtension(FileName));
  
  if Ext = '.pas' then
    ScanPasFile(FileName)
  else if Ext = '.dfm' then
    ScanDfmFile(FileName);
end;

procedure TI18nScanner.ScanDirectory(const Directory: string; Recursive: Boolean);
var
  Files: TArray<string>;
  FileName: string;
  I: Integer;
  SearchOption: TSearchOption;
begin
  if not TDirectory.Exists(Directory) then
    Exit;
    
  if Recursive then
    SearchOption := TSearchOption.soAllDirectories
  else
    SearchOption := TSearchOption.soTopDirectoryOnly;
  
  // Scan .pas files
  Files := TDirectory.GetFiles(Directory, '*.pas', SearchOption);
  for I := 0 to High(Files) do
  begin
    FileName := Files[I];
    if Assigned(FOnProgress) then
      FOnProgress(FileName, I + 1, Length(Files));
    ScanFile(FileName);
  end;
  
  // Scan .dfm files
  Files := TDirectory.GetFiles(Directory, '*.dfm', SearchOption);
  for I := 0 to High(Files) do
  begin
    FileName := Files[I];
    if Assigned(FOnProgress) then
      FOnProgress(FileName, I + 1, Length(Files));
    ScanFile(FileName);
  end;
end;

procedure TI18nScanner.ScanProject(const ProjectFile: string);
var
  ProjectDir: string;
begin
  if not TFile.Exists(ProjectFile) then
    Exit;
    
  ProjectDir := TPath.GetDirectoryName(ProjectFile);
  ScanDirectory(ProjectDir, True);
end;

function TI18nScanner.GetEntries: TI18nEntryArray;
begin
  Result := FEntries.ToArray;
end;

function TI18nScanner.GetNewEntries: TI18nEntryArray;
var
  NewList: TList<TI18nEntry>;
  Entry: TI18nEntry;
begin
  NewList := TList<TI18nEntry>.Create;
  try
    for Entry in FEntries do
    begin
      if Entry.IsNew then
        NewList.Add(Entry);
    end;
    Result := NewList.ToArray;
  finally
    NewList.Free;
  end;
end;

procedure TI18nScanner.GetStats(out TotalFiles, TotalEntries, NewEntries: Integer);
var
  Entry: TI18nEntry;
begin
  TotalFiles := FScannedFiles.Count;
  TotalEntries := FEntries.Count;
  NewEntries := 0;
  
  for Entry in FEntries do
  begin
    if Entry.IsNew then
      Inc(NewEntries);
  end;
end;

function TI18nScanner.ImportNewEntries(const DefaultLanguage: string): Integer;
var
  Query: TFDQuery;
  Entry: TI18nEntry;
begin
  Result := 0;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR IGNORE INTO I18nTexts (LangCode, TextKey, TextValue, NeedsReview) ' +
      'VALUES (:Lang, :Key, :Value, 1)';
    
    FConnection.StartTransaction;
    try
      for Entry in FEntries do
      begin
        if Entry.IsNew then
        begin
          Query.ParamByName('Lang').AsString := DefaultLanguage;
          Query.ParamByName('Key').AsString := Entry.TextKey;
          Query.ParamByName('Value').AsString := Entry.TextKey; // 默认值 = Key
          Query.ExecSQL;
          
          if Query.RowsAffected > 0 then
            Inc(Result);
        end;
      end;
      FConnection.Commit;
    except
      FConnection.Rollback;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

procedure TI18nScanner.Clear;
begin
  FEntries.Clear;
  FScannedFiles.Clear;
end;

procedure TI18nScanner.AddExcludePattern(const Pattern: string);
begin
  FExcludePatterns.Add(Pattern);
end;

end.
