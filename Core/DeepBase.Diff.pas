unit DeepBase.Diff;

(*******************************************************************************
  DeepBase Text Diff
  A text comparison and patching system with:
  - Longest Common Subsequence (LCS) algorithm
  - Line-by-line and character-by-character diff
  - Unified diff format output
  - Context diff format
  - Side-by-side diff view
  - Patch generation and application
  - Three-way merge
  - Diff statistics
  - Ignore whitespace/case options
  - Binary file detection

  Author: DeepBase Team
  Created: 2025-11-28
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.Math, System.StrUtils, System.RegularExpressions;

type
  EDiffException = class(Exception);

  /// <summary>Type of diff operation</summary>
  TDiffOperation = (doEqual, doInsert, doDelete);

  /// <summary>Diff options</summary>
  TDiffOptions = record
    IgnoreCase: Boolean;
    IgnoreWhitespace: Boolean;
    IgnoreBlankLines: Boolean;
    TrimLines: Boolean;
    ContextLines: Integer;
    
    class function Default: TDiffOptions; static;
  end;

  /// <summary>Single diff item</summary>
  TDiffItem = record
    Operation: TDiffOperation;
    Text: string;
    OldIndex: Integer;
    NewIndex: Integer;
    
    class function CreateEqual(const AText: string; AOldIndex, ANewIndex: Integer): TDiffItem; static;
    class function CreateInsert(const AText: string; ANewIndex: Integer): TDiffItem; static;
    class function CreateDelete(const AText: string; AOldIndex: Integer): TDiffItem; static;
  end;

  /// <summary>Diff hunk (group of changes)</summary>
  TDiffHunk = class
  private
    FItems: TList<TDiffItem>;
    FOldStart: Integer;
    FOldCount: Integer;
    FNewStart: Integer;
    FNewCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddItem(const AItem: TDiffItem);
    
    property Items: TList<TDiffItem> read FItems;
    property OldStart: Integer read FOldStart write FOldStart;
    property OldCount: Integer read FOldCount write FOldCount;
    property NewStart: Integer read FNewStart write FNewStart;
    property NewCount: Integer read FNewCount write FNewCount;
  end;

  /// <summary>Diff result</summary>
  TDiffResult = class
  private
    FItems: TList<TDiffItem>;
    FHunks: TObjectList<TDiffHunk>;
    FOldLines: TArray<string>;
    FNewLines: TArray<string>;
    FOptions: TDiffOptions;
    
    function GetAddedCount: Integer;
    function GetDeletedCount: Integer;
    function GetChangedCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Generate unified diff format</summary>
    function ToUnifiedDiff(const AOldName, ANewName: string): string;
    
    /// <summary>Generate context diff format</summary>
    function ToContextDiff(const AOldName, ANewName: string): string;
    
    /// <summary>Generate side-by-side diff</summary>
    function ToSideBySide(AWidth: Integer = 80): string;
    
    /// <summary>Generate HTML diff</summary>
    function ToHTML: string;
    
    /// <summary>Check if there are differences</summary>
    function HasDifferences: Boolean;
    
    /// <summary>Get summary statistics</summary>
    function GetSummary: string;
    
    property Items: TList<TDiffItem> read FItems;
    property Hunks: TObjectList<TDiffHunk> read FHunks;
    property OldLines: TArray<string> read FOldLines write FOldLines;
    property NewLines: TArray<string> read FNewLines write FNewLines;
    property AddedCount: Integer read GetAddedCount;
    property DeletedCount: Integer read GetDeletedCount;
    property ChangedCount: Integer read GetChangedCount;
    property Options: TDiffOptions read FOptions write FOptions;
  end;

  /// <summary>Patch operation</summary>
  TPatchOperation = class
  private
    FHunk: TDiffHunk;
    FApplied: Boolean;
    FOffset: Integer;
    FFuzzFactor: Integer;
  public
    constructor Create(AHunk: TDiffHunk);
    destructor Destroy; override;
    
    property Hunk: TDiffHunk read FHunk;
    property Applied: Boolean read FApplied write FApplied;
    property Offset: Integer read FOffset write FOffset;
    property FuzzFactor: Integer read FFuzzFactor write FFuzzFactor;
  end;

  /// <summary>Patch file</summary>
  TPatch = class
  private
    FOperations: TObjectList<TPatchOperation>;
    FOldFileName: string;
    FNewFileName: string;
    
    function ParseHunkHeader(const ALine: string; var AOldStart, AOldCount, ANewStart, ANewCount: Integer): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Parse unified diff format</summary>
    procedure ParseUnifiedDiff(const ADiff: string);
    
    /// <summary>Apply patch to text</summary>
    function Apply(const AText: string; out AResult: string): Boolean;
    
    /// <summary>Apply patch with fuzz factor</summary>
    function ApplyWithFuzz(const AText: string; AFuzzFactor: Integer; out AResult: string): Boolean;
    
    /// <summary>Reverse the patch</summary>
    procedure Reverse;
    
    /// <summary>Check if patch can be applied</summary>
    function CanApply(const AText: string): Boolean;
    
    property Operations: TObjectList<TPatchOperation> read FOperations;
    property OldFileName: string read FOldFileName write FOldFileName;
    property NewFileName: string read FNewFileName write FNewFileName;
  end;

  /// <summary>Merge conflict</summary>
  TMergeConflict = record
    StartLine: Integer;
    EndLine: Integer;
    BaseContent: TArray<string>;
    OursContent: TArray<string>;
    TheirsContent: TArray<string>;
  end;

  /// <summary>Three-way merge result</summary>
  TMergeResult = class
  private
    FMergedLines: TList<string>;
    FConflicts: TList<TMergeConflict>;
    FHasConflicts: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Get merged text</summary>
    function GetMergedText: string;
    
    /// <summary>Get merged text with conflict markers</summary>
    function GetMergedTextWithMarkers: string;
    
    property MergedLines: TList<string> read FMergedLines;
    property Conflicts: TList<TMergeConflict> read FConflicts;
    property HasConflicts: Boolean read FHasConflicts write FHasConflicts;
  end;

  /// <summary>Text differ</summary>
  TTextDiff = class
  private
    FOptions: TDiffOptions;
    
    function SplitLines(const AText: string): TArray<string>;
    function NormalizeLine(const ALine: string): string;
    function ComputeLCS(const AOld, ANew: TArray<string>): TArray<TArray<Integer>>;
    procedure BacktrackLCS(const AOld, ANew: TArray<string>; const ALCS: TArray<TArray<Integer>>;
      I, J: Integer; var AResult: TList<TDiffItem>);
    procedure BuildHunks(AResult: TDiffResult);
  public
    constructor Create; overload;
    constructor Create(const AOptions: TDiffOptions); overload;
    
    /// <summary>Compare two strings</summary>
    function Compare(const AOldText, ANewText: string): TDiffResult;
    
    /// <summary>Compare two files</summary>
    function CompareFiles(const AOldFile, ANewFile: string): TDiffResult;
    
    /// <summary>Compare two string arrays</summary>
    function CompareLines(const AOldLines, ANewLines: TArray<string>): TDiffResult;
    
    /// <summary>Character-level diff</summary>
    function CompareChars(const AOldText, ANewText: string): TDiffResult;
    
    /// <summary>Word-level diff</summary>
    function CompareWords(const AOldText, ANewText: string): TDiffResult;
    
    /// <summary>Three-way merge</summary>
    function Merge3Way(const ABase, AOurs, ATheirs: string): TMergeResult;
    
    property Options: TDiffOptions read FOptions write FOptions;
  end;

  /// <summary>Diff utilities</summary>
  TDiff = class
  private
    class var FDefaultDiff: TTextDiff;
    class function GetDefault: TTextDiff; static;
  public
    class destructor Destroy;
    
    /// <summary>Quick compare two strings</summary>
    class function Compare(const AOldText, ANewText: string): TDiffResult; overload;
    class function Compare(const AOldText, ANewText: string; const AOptions: TDiffOptions): TDiffResult; overload;
    
    /// <summary>Quick compare files</summary>
    class function CompareFiles(const AOldFile, ANewFile: string): TDiffResult;
    
    /// <summary>Generate unified diff</summary>
    class function UnifiedDiff(const AOldText, ANewText: string; const AOldName: string = 'old'; const ANewName: string = 'new'): string;
    
    /// <summary>Apply patch</summary>
    class function ApplyPatch(const AText, APatch: string): string;
    
    /// <summary>Check if texts are equal (with options)</summary>
    class function AreEqual(const AText1, AText2: string; const AOptions: TDiffOptions): Boolean;
    
    /// <summary>Three-way merge</summary>
    class function Merge(const ABase, AOurs, ATheirs: string): TMergeResult;
    
    /// <summary>Calculate similarity ratio (0.0 to 1.0)</summary>
    class function Similarity(const AText1, AText2: string): Double;
    
    /// <summary>Detect if content is binary</summary>
    class function IsBinary(const AContent: TBytes): Boolean;
    
    /// <summary>Default differ instance</summary>
    class property Default: TTextDiff read GetDefault;
  end;

implementation

uses
  System.IOUtils;

{ TDiffOptions }

class function TDiffOptions.Default: TDiffOptions;
begin
  Result.IgnoreCase := False;
  Result.IgnoreWhitespace := False;
  Result.IgnoreBlankLines := False;
  Result.TrimLines := False;
  Result.ContextLines := 3;
end;

{ TDiffItem }

class function TDiffItem.CreateEqual(const AText: string; AOldIndex, ANewIndex: Integer): TDiffItem;
begin
  Result.Operation := doEqual;
  Result.Text := AText;
  Result.OldIndex := AOldIndex;
  Result.NewIndex := ANewIndex;
end;

class function TDiffItem.CreateInsert(const AText: string; ANewIndex: Integer): TDiffItem;
begin
  Result.Operation := doInsert;
  Result.Text := AText;
  Result.OldIndex := -1;
  Result.NewIndex := ANewIndex;
end;

class function TDiffItem.CreateDelete(const AText: string; AOldIndex: Integer): TDiffItem;
begin
  Result.Operation := doDelete;
  Result.Text := AText;
  Result.OldIndex := AOldIndex;
  Result.NewIndex := -1;
end;

{ TDiffHunk }

constructor TDiffHunk.Create;
begin
  inherited;
  FItems := TList<TDiffItem>.Create;
end;

destructor TDiffHunk.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TDiffHunk.AddItem(const AItem: TDiffItem);
begin
  FItems.Add(AItem);
end;

{ TDiffResult }

constructor TDiffResult.Create;
begin
  inherited;
  FItems := TList<TDiffItem>.Create;
  FHunks := TObjectList<TDiffHunk>.Create(True);
  FOptions := TDiffOptions.Default;
end;

destructor TDiffResult.Destroy;
begin
  FreeAndNil(FHunks);
  FreeAndNil(FItems);
  inherited;
end;

function TDiffResult.GetAddedCount: Integer;
var
  LHunk: TDiffHunk;
  LItem: TDiffItem;
begin
  Result := 0;
  for LHunk in FHunks do
  begin
    for LItem in LHunk.Items do
    begin
      if LItem.Operation = doInsert then
        Inc(Result);
    end;
  end;
end;

function TDiffResult.GetDeletedCount: Integer;
var
  LHunk: TDiffHunk;
  LItem: TDiffItem;
begin
  Result := 0;
  for LHunk in FHunks do
  begin
    for LItem in LHunk.Items do
    begin
      if LItem.Operation = doDelete then
        Inc(Result);
    end;
  end;
end;

function TDiffResult.GetChangedCount: Integer;
begin
  Result := GetAddedCount + GetDeletedCount;
end;

function TDiffResult.HasDifferences: Boolean;
var
  LHunk: TDiffHunk;
  LItem: TDiffItem;
begin
  for LHunk in FHunks do
  begin
    for LItem in LHunk.Items do
    begin
      if LItem.Operation <> doEqual then
        Exit(True);
    end;
  end;
  Result := False;
end;

function TDiffResult.ToUnifiedDiff(const AOldName, ANewName: string): string;
var
  LSB: TStringBuilder;
  LHunk: TDiffHunk;
  LItem: TDiffItem;
begin
  LSB := TStringBuilder.Create;
  try
    // File headers
    LSB.AppendLine('--- ' + AOldName);
    LSB.AppendLine('+++ ' + ANewName);
    
    for LHunk in FHunks do
    begin
      // Hunk header
      LSB.AppendFormat('@@ -%d,%d +%d,%d @@', [
        LHunk.OldStart + 1,
        LHunk.OldCount,
        LHunk.NewStart + 1,
        LHunk.NewCount
      ]);
      LSB.AppendLine;
      
      // Hunk content
      for LItem in LHunk.Items do
      begin
        case LItem.Operation of
          doEqual:
            LSB.AppendLine(' ' + LItem.Text);
          doInsert:
            LSB.AppendLine('+' + LItem.Text);
          doDelete:
            LSB.AppendLine('-' + LItem.Text);
        end;
      end;
    end;
    
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TDiffResult.ToContextDiff(const AOldName, ANewName: string): string;
var
  LSB: TStringBuilder;
  LHunk: TDiffHunk;
  LItem: TDiffItem;
begin
  LSB := TStringBuilder.Create;
  try
    // File headers
    LSB.AppendLine('*** ' + AOldName);
    LSB.AppendLine('--- ' + ANewName);
    
    for LHunk in FHunks do
    begin
      LSB.AppendLine('***************');
      
      // Old file section
      LSB.AppendFormat('*** %d,%d ****', [
        LHunk.OldStart + 1,
        LHunk.OldStart + LHunk.OldCount
      ]);
      LSB.AppendLine;
      
      for LItem in LHunk.Items do
      begin
        case LItem.Operation of
          doEqual:
            LSB.AppendLine('  ' + LItem.Text);
          doDelete:
            LSB.AppendLine('- ' + LItem.Text);
        end;
      end;
      
      // New file section
      LSB.AppendFormat('--- %d,%d ----', [
        LHunk.NewStart + 1,
        LHunk.NewStart + LHunk.NewCount
      ]);
      LSB.AppendLine;
      
      for LItem in LHunk.Items do
      begin
        case LItem.Operation of
          doEqual:
            LSB.AppendLine('  ' + LItem.Text);
          doInsert:
            LSB.AppendLine('+ ' + LItem.Text);
        end;
      end;
    end;
    
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TDiffResult.ToSideBySide(AWidth: Integer): string;
var
  LSB: TStringBuilder;
  LHunk: TDiffHunk;
  LItem: TDiffItem;
  LColWidth, LLineNumWidth: Integer;
  LOldLine, LNewLine: string;
  LOldIdx, LNewIdx: Integer;
  
  function PadRight(const S: string; ALen: Integer): string;
  begin
    if Length(S) >= ALen then
      Result := Copy(S, 1, ALen)
    else
      Result := S + StringOfChar(' ', ALen - Length(S));
  end;
  
  function FormatLine(AIndex: Integer; const AText: string): string;
  begin
    if AIndex >= 0 then
      Result := Format('%*d | %s', [LLineNumWidth, AIndex + 1, PadRight(AText, LColWidth)])
    else
      Result := StringOfChar(' ', LLineNumWidth) + ' | ' + StringOfChar(' ', LColWidth);
  end;
begin
  LSB := TStringBuilder.Create;
  try
    LLineNumWidth := 4;
    LColWidth := (AWidth - LLineNumWidth * 2 - 7) div 2;
    
    // Header
    LSB.AppendLine(StringOfChar('-', AWidth));
    
    LOldIdx := 0;
    LNewIdx := 0;
    
    for LHunk in FHunks do
    begin
      for LItem in LHunk.Items do
      begin
        case LItem.Operation of
          doEqual:
            begin
              LOldLine := FormatLine(LOldIdx, LItem.Text);
              LNewLine := FormatLine(LNewIdx, LItem.Text);
              LSB.AppendLine(LOldLine + ' ' + LNewLine);
              Inc(LOldIdx);
              Inc(LNewIdx);
            end;
            
          doDelete:
            begin
              LOldLine := FormatLine(LOldIdx, LItem.Text);
              LNewLine := FormatLine(-1, '');
              LSB.AppendLine(LOldLine + '<' + LNewLine);
              Inc(LOldIdx);
            end;
            
          doInsert:
            begin
              LOldLine := FormatLine(-1, '');
              LNewLine := FormatLine(LNewIdx, LItem.Text);
              LSB.AppendLine(LOldLine + '>' + LNewLine);
              Inc(LNewIdx);
            end;
        end;
      end;
    end;
    
    LSB.AppendLine(StringOfChar('-', AWidth));
    
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TDiffResult.ToHTML: string;
var
  LSB: TStringBuilder;
  LHunk: TDiffHunk;
  LItem: TDiffItem;
  
  function HTMLEncode(const S: string): string;
  begin
    Result := S;
    Result := StringReplace(Result, '&', '&amp;', [rfReplaceAll]);
    Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
    Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  end;
begin
  LSB := TStringBuilder.Create;
  try
    LSB.AppendLine('<div class="diff">');
    LSB.AppendLine('<style>');
    LSB.AppendLine('.diff { font-family: monospace; white-space: pre; }');
    LSB.AppendLine('.diff-equal { color: #333; }');
    LSB.AppendLine('.diff-insert { background-color: #dfd; color: #080; }');
    LSB.AppendLine('.diff-delete { background-color: #fdd; color: #800; }');
    LSB.AppendLine('.diff-hunk-header { color: #00a; background-color: #eef; }');
    LSB.AppendLine('</style>');
    
    for LHunk in FHunks do
    begin
      LSB.AppendFormat('<div class="diff-hunk-header">@@ -%d,%d +%d,%d @@</div>', [
        LHunk.OldStart + 1,
        LHunk.OldCount,
        LHunk.NewStart + 1,
        LHunk.NewCount
      ]);
      LSB.AppendLine;
      
      for LItem in LHunk.Items do
      begin
        case LItem.Operation of
          doEqual:
            LSB.AppendFormat('<div class="diff-equal"> %s</div>', [HTMLEncode(LItem.Text)]);
          doInsert:
            LSB.AppendFormat('<div class="diff-insert">+%s</div>', [HTMLEncode(LItem.Text)]);
          doDelete:
            LSB.AppendFormat('<div class="diff-delete">-%s</div>', [HTMLEncode(LItem.Text)]);
        end;
        LSB.AppendLine;
      end;
    end;
    
    LSB.AppendLine('</div>');
    
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TDiffResult.GetSummary: string;
begin
  Result := Format('%d insertions(+), %d deletions(-)', [GetAddedCount, GetDeletedCount]);
end;

{ TPatchOperation }

constructor TPatchOperation.Create(AHunk: TDiffHunk);
begin
  inherited Create;
  FHunk := AHunk;
  FApplied := False;
  FOffset := 0;
  FFuzzFactor := 0;
end;

destructor TPatchOperation.Destroy;
begin
  FreeAndNil(FHunk);
  inherited;
end;

{ TPatch }

constructor TPatch.Create;
begin
  inherited;
  FOperations := TObjectList<TPatchOperation>.Create(True);
end;

destructor TPatch.Destroy;
begin
  FreeAndNil(FOperations);
  inherited;
end;

function TPatch.ParseHunkHeader(const ALine: string; var AOldStart, AOldCount, ANewStart, ANewCount: Integer): Boolean;
var
  LMatch: TMatch;
begin
  // Parse @@ -start,count +start,count @@
  LMatch := TRegEx.Match(ALine, '@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@');
  if LMatch.Success then
  begin
    AOldStart := StrToIntDef(LMatch.Groups[1].Value, 1) - 1;
    if LMatch.Groups[2].Success then
      AOldCount := StrToIntDef(LMatch.Groups[2].Value, 1)
    else
      AOldCount := 1;
    ANewStart := StrToIntDef(LMatch.Groups[3].Value, 1) - 1;
    if LMatch.Groups[4].Success then
      ANewCount := StrToIntDef(LMatch.Groups[4].Value, 1)
    else
      ANewCount := 1;
    Result := True;
  end
  else
    Result := False;
end;

procedure TPatch.ParseUnifiedDiff(const ADiff: string);
var
  LLines: TArray<string>;
  I: Integer;
  LLine: string;
  LHunk: TDiffHunk;
  LOldStart, LOldCount, LNewStart, LNewCount: Integer;
  LItem: TDiffItem;
  LOldIdx, LNewIdx: Integer;
begin
  FOperations.Clear;
  
  LLines := ADiff.Split([#13#10, #10, #13], TStringSplitOptions.None);
  I := 0;
  LHunk := nil;
  LOldIdx := 0;
  LNewIdx := 0;
  
  while I < Length(LLines) do
  begin
    LLine := LLines[I];
    
    // Parse file headers
    if LLine.StartsWith('--- ') then
    begin
      FOldFileName := Copy(LLine, 5, MaxInt).Trim;
    end
    else if LLine.StartsWith('+++ ') then
    begin
      FNewFileName := Copy(LLine, 5, MaxInt).Trim;
    end
    // Parse hunk header
    else if LLine.StartsWith('@@') then
    begin
      if Assigned(LHunk) then
        FOperations.Add(TPatchOperation.Create(LHunk));
        
      LHunk := TDiffHunk.Create;
      if ParseHunkHeader(LLine, LOldStart, LOldCount, LNewStart, LNewCount) then
      begin
        LHunk.OldStart := LOldStart;
        LHunk.OldCount := LOldCount;
        LHunk.NewStart := LNewStart;
        LHunk.NewCount := LNewCount;
        LOldIdx := LOldStart;
        LNewIdx := LNewStart;
      end;
    end
    // Parse diff lines
    else if Assigned(LHunk) then
    begin
      if LLine.StartsWith(' ') then
      begin
        LItem := TDiffItem.CreateEqual(Copy(LLine, 2, MaxInt), LOldIdx, LNewIdx);
        LHunk.AddItem(LItem);
        Inc(LOldIdx);
        Inc(LNewIdx);
      end
      else if LLine.StartsWith('+') then
      begin
        LItem := TDiffItem.CreateInsert(Copy(LLine, 2, MaxInt), LNewIdx);
        LHunk.AddItem(LItem);
        Inc(LNewIdx);
      end
      else if LLine.StartsWith('-') then
      begin
        LItem := TDiffItem.CreateDelete(Copy(LLine, 2, MaxInt), LOldIdx);
        LHunk.AddItem(LItem);
        Inc(LOldIdx);
      end;
    end;
    
    Inc(I);
  end;
  
  if Assigned(LHunk) then
    FOperations.Add(TPatchOperation.Create(LHunk));
end;

function TPatch.Apply(const AText: string; out AResult: string): Boolean;
begin
  Result := ApplyWithFuzz(AText, 0, AResult);
end;

function TPatch.ApplyWithFuzz(const AText: string; AFuzzFactor: Integer; out AResult: string): Boolean;
var
  LLines: TList<string>;
  LSourceLines: TArray<string>;
  LOp: TPatchOperation;
  LItem: TDiffItem;
  LOffset, LSearchStart, LSearchEnd, I, J: Integer;
  LFound: Boolean;
  LContextMatch: Boolean;
begin
  Result := True;
  
  if AText.Contains(#13#10) then
    LSourceLines := AText.Split([#13#10])
  else if AText.Contains(#10) then
    LSourceLines := AText.Split([#10])
  else
    LSourceLines := AText.Split([#13]);
    
  LLines := TList<string>.Create;
  try
    for I := 0 to High(LSourceLines) do
      LLines.Add(LSourceLines[I]);
      
    LOffset := 0;
    
    for LOp in FOperations do
    begin
      LFound := False;
      
      // Try to find context with offset
      LSearchStart := Max(0, LOp.Hunk.OldStart + LOffset - AFuzzFactor);
      LSearchEnd := Min(LLines.Count - 1, LOp.Hunk.OldStart + LOffset + AFuzzFactor);
      
      for I := LSearchStart to LSearchEnd do
      begin
        LContextMatch := True;
        
        // Check if context lines match
        J := 0;
        for LItem in LOp.Hunk.Items do
        begin
          if LItem.Operation in [doEqual, doDelete] then
          begin
            if (I + J >= LLines.Count) or (LLines[I + J] <> LItem.Text) then
            begin
              LContextMatch := False;
              Break;
            end;
            Inc(J);
          end;
        end;
        
        if LContextMatch then
        begin
          LFound := True;
          LOp.Offset := I - LOp.Hunk.OldStart;
          
          // Apply changes
          J := I;
          for LItem in LOp.Hunk.Items do
          begin
            case LItem.Operation of
              doEqual:
                Inc(J);
              doDelete:
                begin
                  if J < LLines.Count then
                    LLines.Delete(J);
                end;
              doInsert:
                begin
                  LLines.Insert(J, LItem.Text);
                  Inc(J);
                end;
            end;
          end;
          
          // Update offset for next hunk
          LOffset := LOffset + (LOp.Hunk.NewCount - LOp.Hunk.OldCount);
          LOp.Applied := True;
          Break;
        end;
      end;
      
      if not LFound then
      begin
        Result := False;
        LOp.Applied := False;
      end;
    end;
    
    // Build result
    AResult := '';
    for I := 0 to LLines.Count - 1 do
    begin
      if I > 0 then
        AResult := AResult + sLineBreak;
      AResult := AResult + LLines[I];
    end;
  finally
    LLines.Free;
  end;
end;

procedure TPatch.Reverse;
var
  LOp: TPatchOperation;
  LItem: TDiffItem;
  LNewItems: TList<TDiffItem>;
  LTemp: Integer;
  I: Integer;
begin
  for LOp in FOperations do
  begin
    // Swap old and new positions
    LTemp := LOp.Hunk.OldStart;
    LOp.Hunk.OldStart := LOp.Hunk.NewStart;
    LOp.Hunk.NewStart := LTemp;
    
    LTemp := LOp.Hunk.OldCount;
    LOp.Hunk.OldCount := LOp.Hunk.NewCount;
    LOp.Hunk.NewCount := LTemp;
    
    // Reverse operations
    LNewItems := TList<TDiffItem>.Create;
    try
      for I := 0 to LOp.Hunk.Items.Count - 1 do
      begin
        LItem := LOp.Hunk.Items[I];
        case LItem.Operation of
          doInsert:
            LItem.Operation := doDelete;
          doDelete:
            LItem.Operation := doInsert;
        end;
        LNewItems.Add(LItem);
      end;
      
      LOp.Hunk.Items.Clear;
      for LItem in LNewItems do
        LOp.Hunk.Items.Add(LItem);
    finally
      LNewItems.Free;
    end;
  end;
end;

function TPatch.CanApply(const AText: string): Boolean;
var
  LResult: string;
begin
  Result := Apply(AText, LResult);
end;

{ TMergeResult }

constructor TMergeResult.Create;
begin
  inherited;
  FMergedLines := TList<string>.Create;
  FConflicts := TList<TMergeConflict>.Create;
end;

destructor TMergeResult.Destroy;
begin
  FreeAndNil(FConflicts);
  FreeAndNil(FMergedLines);
  inherited;
end;

function TMergeResult.GetMergedText: string;
var
  LSB: TStringBuilder;
  I: Integer;
begin
  LSB := TStringBuilder.Create;
  try
    for I := 0 to FMergedLines.Count - 1 do
    begin
      if I > 0 then
        LSB.AppendLine;
      LSB.Append(FMergedLines[I]);
    end;
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TMergeResult.GetMergedTextWithMarkers: string;
var
  LSB: TStringBuilder;
  I, J, LConflictIdx: Integer;
  LConflict: TMergeConflict;
  LInConflict: Boolean;
begin
  if not FHasConflicts then
    Exit(GetMergedText);
    
  LSB := TStringBuilder.Create;
  try
    LConflictIdx := 0;
    I := 0;
    
    while I < FMergedLines.Count do
    begin
      LInConflict := False;
      
      // Check if we're at a conflict
      if LConflictIdx < FConflicts.Count then
      begin
        LConflict := FConflicts[LConflictIdx];
        if I = LConflict.StartLine then
        begin
          LInConflict := True;
          
          LSB.AppendLine('<<<<<<< OURS');
          for J := 0 to High(LConflict.OursContent) do
            LSB.AppendLine(LConflict.OursContent[J]);
            
          LSB.AppendLine('=======');
          for J := 0 to High(LConflict.TheirsContent) do
            LSB.AppendLine(LConflict.TheirsContent[J]);
            
          LSB.AppendLine('>>>>>>> THEIRS');
          
          I := LConflict.EndLine + 1;
          Inc(LConflictIdx);
        end;
      end;
      
      if not LInConflict then
      begin
        if I > 0 then
          LSB.AppendLine;
        LSB.Append(FMergedLines[I]);
        Inc(I);
      end;
    end;
    
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

{ TTextDiff }

constructor TTextDiff.Create;
begin
  inherited;
  FOptions := TDiffOptions.Default;
end;

constructor TTextDiff.Create(const AOptions: TDiffOptions);
begin
  inherited Create;
  FOptions := AOptions;
end;

function TTextDiff.SplitLines(const AText: string): TArray<string>;
begin
  if AText.Contains(#13#10) then
    Result := AText.Split([#13#10])
  else if AText.Contains(#10) then
    Result := AText.Split([#10])
  else if AText.Contains(#13) then
    Result := AText.Split([#13])
  else if AText = '' then
    SetLength(Result, 0)
  else
  begin
    SetLength(Result, 1);
    Result[0] := AText;
  end;
end;

function TTextDiff.NormalizeLine(const ALine: string): string;
begin
  Result := ALine;
  
  if FOptions.TrimLines then
    Result := Result.Trim;
    
  if FOptions.IgnoreWhitespace then
    Result := TRegEx.Replace(Result, '\s+', ' ');
    
  if FOptions.IgnoreCase then
    Result := Result.ToLower;
end;

function TTextDiff.ComputeLCS(const AOld, ANew: TArray<string>): TArray<TArray<Integer>>;
var
  I, J, M, N: Integer;
  LOldNorm, LNewNorm: string;
begin
  M := Length(AOld);
  N := Length(ANew);
  
  SetLength(Result, M + 1);
  for I := 0 to M do
    SetLength(Result[I], N + 1);
    
  // Initialize first row and column
  for I := 0 to M do
    Result[I][0] := 0;
  for J := 0 to N do
    Result[0][J] := 0;
    
  // Fill the LCS table
  for I := 1 to M do
  begin
    for J := 1 to N do
    begin
      LOldNorm := NormalizeLine(AOld[I - 1]);
      LNewNorm := NormalizeLine(ANew[J - 1]);
      
      if LOldNorm = LNewNorm then
        Result[I][J] := Result[I - 1][J - 1] + 1
      else
        Result[I][J] := Max(Result[I - 1][J], Result[I][J - 1]);
    end;
  end;
end;

procedure TTextDiff.BacktrackLCS(const AOld, ANew: TArray<string>; const ALCS: TArray<TArray<Integer>>;
  I, J: Integer; var AResult: TList<TDiffItem>);
var
  LOldNorm, LNewNorm: string;
begin
  if (I = 0) and (J = 0) then
    Exit;
    
  if I = 0 then
  begin
    BacktrackLCS(AOld, ANew, ALCS, I, J - 1, AResult);
    AResult.Add(TDiffItem.CreateInsert(ANew[J - 1], J - 1));
  end
  else if J = 0 then
  begin
    BacktrackLCS(AOld, ANew, ALCS, I - 1, J, AResult);
    AResult.Add(TDiffItem.CreateDelete(AOld[I - 1], I - 1));
  end
  else
  begin
    LOldNorm := NormalizeLine(AOld[I - 1]);
    LNewNorm := NormalizeLine(ANew[J - 1]);
    
    if LOldNorm = LNewNorm then
    begin
      BacktrackLCS(AOld, ANew, ALCS, I - 1, J - 1, AResult);
      AResult.Add(TDiffItem.CreateEqual(ANew[J - 1], I - 1, J - 1));
    end
    else if ALCS[I - 1][J] > ALCS[I][J - 1] then
    begin
      BacktrackLCS(AOld, ANew, ALCS, I - 1, J, AResult);
      AResult.Add(TDiffItem.CreateDelete(AOld[I - 1], I - 1));
    end
    else
    begin
      BacktrackLCS(AOld, ANew, ALCS, I, J - 1, AResult);
      AResult.Add(TDiffItem.CreateInsert(ANew[J - 1], J - 1));
    end;
  end;
end;

procedure TTextDiff.BuildHunks(AResult: TDiffResult);
var
  LItems: TList<TDiffItem>;
  I, J, K: Integer;
  LHunk: TDiffHunk;
  LItem: TDiffItem;
  LInHunk: Boolean;
  LContextStart, LContextEnd: Integer;
  LDiffItems: TList<TDiffItem>;
begin
  LDiffItems := TList<TDiffItem>.Create;
  try
    // Collect all diff items using LCS backtracking
    BacktrackLCS(AResult.OldLines, AResult.NewLines, 
      ComputeLCS(AResult.OldLines, AResult.NewLines),
      Length(AResult.OldLines), Length(AResult.NewLines), LDiffItems);
    
    // Build hunks with context
    LInHunk := False;
    LHunk := nil;
    I := 0;
    
    while I < LDiffItems.Count do
    begin
      LItem := LDiffItems[I];
      
      if LItem.Operation <> doEqual then
      begin
        if not LInHunk then
        begin
          // Start new hunk with context
          LHunk := TDiffHunk.Create;
          LContextStart := Max(0, I - FOptions.ContextLines);
          
          // Set hunk start positions
          if LContextStart > 0 then
          begin
            LHunk.OldStart := LDiffItems[LContextStart].OldIndex;
            LHunk.NewStart := LDiffItems[LContextStart].NewIndex;
          end
          else
          begin
            LHunk.OldStart := 0;
            LHunk.NewStart := 0;
          end;
          
          // Add leading context
          for J := LContextStart to I - 1 do
            LHunk.AddItem(LDiffItems[J]);
            
          LInHunk := True;
        end;
        
        LHunk.AddItem(LItem);
      end
      else
      begin
        if LInHunk then
        begin
          // Check if we should end the hunk
          LContextEnd := I;
          K := I;
          while (K < LDiffItems.Count) and (K - I < FOptions.ContextLines) do
          begin
            if LDiffItems[K].Operation <> doEqual then
            begin
              LContextEnd := K;
              Break;
            end;
            Inc(K);
          end;
          
          if K >= LDiffItems.Count then
            LContextEnd := LDiffItems.Count;
            
          // Add trailing context and potentially more changes
          for J := I to Min(LContextEnd, I + FOptions.ContextLines) - 1 do
          begin
            if J < LDiffItems.Count then
              LHunk.AddItem(LDiffItems[J]);
          end;
          
          // Check if there's another change within context distance
          if (K < LDiffItems.Count) and (LDiffItems[K].Operation <> doEqual) then
          begin
            // Continue with same hunk
            I := LContextEnd - 1;
          end
          else
          begin
          // End hunk - count items
            var LOldCnt := 0;
            var LNewCnt := 0;
            for LItem in LHunk.Items do
            begin
              if LItem.Operation in [doEqual, doDelete] then
                Inc(LOldCnt);
              if LItem.Operation in [doEqual, doInsert] then
                Inc(LNewCnt);
            end;
            LHunk.OldCount := LOldCnt;
            LHunk.NewCount := LNewCnt;
            
            AResult.Hunks.Add(LHunk);
            LHunk := nil;
            LInHunk := False;
            I := Min(LContextEnd, I + FOptions.ContextLines) - 1;
          end;
        end;
      end;
      
      Inc(I);
    end;
    
    // Finalize last hunk if open
    if LInHunk and Assigned(LHunk) then
    begin
      var LFinalOldCnt := 0;
      var LFinalNewCnt := 0;
      for LItem in LHunk.Items do
      begin
        if LItem.Operation in [doEqual, doDelete] then
          Inc(LFinalOldCnt);
        if LItem.Operation in [doEqual, doInsert] then
          Inc(LFinalNewCnt);
      end;
      LHunk.OldCount := LFinalOldCnt;
      LHunk.NewCount := LFinalNewCnt;
      AResult.Hunks.Add(LHunk);
    end;
  finally
    LDiffItems.Free;
  end;
end;

function TTextDiff.Compare(const AOldText, ANewText: string): TDiffResult;
begin
  Result := CompareLines(SplitLines(AOldText), SplitLines(ANewText));
end;

function TTextDiff.CompareFiles(const AOldFile, ANewFile: string): TDiffResult;
var
  LOldText, LNewText: string;
begin
  LOldText := TFile.ReadAllText(AOldFile, TEncoding.UTF8);
  LNewText := TFile.ReadAllText(ANewFile, TEncoding.UTF8);
  Result := Compare(LOldText, LNewText);
end;

function TTextDiff.CompareLines(const AOldLines, ANewLines: TArray<string>): TDiffResult;
begin
  Result := TDiffResult.Create;
  Result.OldLines := AOldLines;
  Result.NewLines := ANewLines;
  Result.Options := FOptions;
  
  BuildHunks(Result);
end;

function TTextDiff.CompareChars(const AOldText, ANewText: string): TDiffResult;
var
  LOldChars, LNewChars: TArray<string>;
  I: Integer;
begin
  SetLength(LOldChars, Length(AOldText));
  for I := 1 to Length(AOldText) do
    LOldChars[I - 1] := AOldText[I];
    
  SetLength(LNewChars, Length(ANewText));
  for I := 1 to Length(ANewText) do
    LNewChars[I - 1] := ANewText[I];
    
  Result := CompareLines(LOldChars, LNewChars);
end;

function TTextDiff.CompareWords(const AOldText, ANewText: string): TDiffResult;
var
  LOldWords, LNewWords: TArray<string>;
begin
  LOldWords := TRegEx.Split(AOldText, '\s+');
  LNewWords := TRegEx.Split(ANewText, '\s+');
  Result := CompareLines(LOldWords, LNewWords);
end;

function TTextDiff.Merge3Way(const ABase, AOurs, ATheirs: string): TMergeResult;
var
  LBaseLines, LOursLines, LTheirsLines: TArray<string>;
  LBaseDiff, LTheirsDiff: TDiffResult;
  I, J, K: Integer;
  LBaseItem, LOurItem, LTheirItem: TDiffItem;
  LConflict: TMergeConflict;
  LMergeIdx: Integer;
  LBaseIdx, LOurIdx, LTheirIdx: Integer;
  LOurChanges, LTheirChanges: TList<TDiffItem>;
begin
  Result := TMergeResult.Create;
  
  LBaseLines := SplitLines(ABase);
  LOursLines := SplitLines(AOurs);
  LTheirsLines := SplitLines(ATheirs);
  
  // Compute diffs from base
  LBaseDiff := CompareLines(LBaseLines, LOursLines);
  LTheirsDiff := CompareLines(LBaseLines, LTheirsLines);
  
  try
    LOurChanges := TList<TDiffItem>.Create;
    LTheirChanges := TList<TDiffItem>.Create;
    try
      // Collect changes
      BacktrackLCS(LBaseLines, LOursLines, ComputeLCS(LBaseLines, LOursLines),
        Length(LBaseLines), Length(LOursLines), LOurChanges);
      BacktrackLCS(LBaseLines, LTheirsLines, ComputeLCS(LBaseLines, LTheirsLines),
        Length(LBaseLines), Length(LTheirsLines), LTheirChanges);
      
      // Simple three-way merge
      LBaseIdx := 0;
      LOurIdx := 0;
      LTheirIdx := 0;
      I := 0;
      J := 0;
      
      while (I < LOurChanges.Count) or (J < LTheirChanges.Count) do
      begin
        if I < LOurChanges.Count then
          LOurItem := LOurChanges[I]
        else
          LOurItem := TDiffItem.CreateEqual('', -1, -1);
          
        if J < LTheirChanges.Count then
          LTheirItem := LTheirChanges[J]
        else
          LTheirItem := TDiffItem.CreateEqual('', -1, -1);
        
        // Both equal - no conflict
        if (LOurItem.Operation = doEqual) and (LTheirItem.Operation = doEqual) then
        begin
          if I < LOurChanges.Count then
            Result.MergedLines.Add(LOurItem.Text);
          Inc(I);
          Inc(J);
        end
        // Only ours changed
        else if (LOurItem.Operation <> doEqual) and (LTheirItem.Operation = doEqual) then
        begin
          if LOurItem.Operation = doInsert then
            Result.MergedLines.Add(LOurItem.Text);
          // doDelete: skip the line
          Inc(I);
          if LTheirItem.Operation = doEqual then
            Inc(J);
        end
        // Only theirs changed
        else if (LOurItem.Operation = doEqual) and (LTheirItem.Operation <> doEqual) then
        begin
          if LTheirItem.Operation = doInsert then
            Result.MergedLines.Add(LTheirItem.Text);
          Inc(J);
          if LOurItem.Operation = doEqual then
            Inc(I);
        end
        // Both changed - potential conflict
        else
        begin
          // Check if they made the same change
          if (LOurItem.Operation = LTheirItem.Operation) and (LOurItem.Text = LTheirItem.Text) then
          begin
            if LOurItem.Operation = doInsert then
              Result.MergedLines.Add(LOurItem.Text);
            Inc(I);
            Inc(J);
          end
          else
          begin
            // Conflict!
            Result.HasConflicts := True;
            
            LConflict.StartLine := Result.MergedLines.Count;
            SetLength(LConflict.BaseContent, 0);
            SetLength(LConflict.OursContent, 0);
            SetLength(LConflict.TheirsContent, 0);
            
            // Gather conflicting lines from ours
            while (I < LOurChanges.Count) and (LOurChanges[I].Operation <> doEqual) do
            begin
              if LOurChanges[I].Operation = doInsert then
              begin
                SetLength(LConflict.OursContent, Length(LConflict.OursContent) + 1);
                LConflict.OursContent[High(LConflict.OursContent)] := LOurChanges[I].Text;
              end
              else if LOurChanges[I].Operation = doDelete then
              begin
                SetLength(LConflict.BaseContent, Length(LConflict.BaseContent) + 1);
                LConflict.BaseContent[High(LConflict.BaseContent)] := LOurChanges[I].Text;
              end;
              Inc(I);
            end;
            
            // Gather conflicting lines from theirs
            while (J < LTheirChanges.Count) and (LTheirChanges[J].Operation <> doEqual) do
            begin
              if LTheirChanges[J].Operation = doInsert then
              begin
                SetLength(LConflict.TheirsContent, Length(LConflict.TheirsContent) + 1);
                LConflict.TheirsContent[High(LConflict.TheirsContent)] := LTheirChanges[J].Text;
              end;
              Inc(J);
            end;
            
            // Add conflict marker placeholder
            Result.MergedLines.Add('<CONFLICT>');
            LConflict.EndLine := Result.MergedLines.Count - 1;
            Result.Conflicts.Add(LConflict);
          end;
        end;
      end;
    finally
      LOurChanges.Free;
      LTheirChanges.Free;
    end;
  finally
    LBaseDiff.Free;
    LTheirsDiff.Free;
  end;
end;

{ TDiff }

class destructor TDiff.Destroy;
begin
  FreeAndNil(FDefaultDiff);
end;

class function TDiff.GetDefault: TTextDiff;
begin
  if not Assigned(FDefaultDiff) then
    FDefaultDiff := TTextDiff.Create;
  Result := FDefaultDiff;
end;

class function TDiff.Compare(const AOldText, ANewText: string): TDiffResult;
begin
  Result := Default.Compare(AOldText, ANewText);
end;

class function TDiff.Compare(const AOldText, ANewText: string; const AOptions: TDiffOptions): TDiffResult;
var
  LDiff: TTextDiff;
begin
  LDiff := TTextDiff.Create(AOptions);
  try
    Result := LDiff.Compare(AOldText, ANewText);
  finally
    LDiff.Free;
  end;
end;

class function TDiff.CompareFiles(const AOldFile, ANewFile: string): TDiffResult;
begin
  Result := Default.CompareFiles(AOldFile, ANewFile);
end;

class function TDiff.UnifiedDiff(const AOldText, ANewText: string; const AOldName, ANewName: string): string;
var
  LResult: TDiffResult;
begin
  LResult := Compare(AOldText, ANewText);
  try
    Result := LResult.ToUnifiedDiff(AOldName, ANewName);
  finally
    LResult.Free;
  end;
end;

class function TDiff.ApplyPatch(const AText, APatch: string): string;
var
  LPatch: TPatch;
begin
  LPatch := TPatch.Create;
  try
    LPatch.ParseUnifiedDiff(APatch);
    if not LPatch.Apply(AText, Result) then
      raise EDiffException.Create('Failed to apply patch');
  finally
    LPatch.Free;
  end;
end;

class function TDiff.AreEqual(const AText1, AText2: string; const AOptions: TDiffOptions): Boolean;
var
  LResult: TDiffResult;
begin
  LResult := Compare(AText1, AText2, AOptions);
  try
    Result := not LResult.HasDifferences;
  finally
    LResult.Free;
  end;
end;

class function TDiff.Merge(const ABase, AOurs, ATheirs: string): TMergeResult;
begin
  Result := Default.Merge3Way(ABase, AOurs, ATheirs);
end;

class function TDiff.Similarity(const AText1, AText2: string): Double;
var
  LPrev, LCurr, LTemp: TArray<Integer>;
  I, J, LLCSLen, LMaxLen: Integer;
begin
  if (AText1 = '') and (AText2 = '') then
    Exit(1.0);
    
  if (AText1 = '') or (AText2 = '') then
    Exit(0.0);
    
  SetLength(LPrev, Length(AText2) + 1);
  SetLength(LCurr, Length(AText2) + 1);

  for I := 1 to Length(AText1) do
  begin
    for J := 1 to Length(AText2) do
    begin
      if AText1[I] = AText2[J] then
        LCurr[J] := LPrev[J - 1] + 1
      else
        LCurr[J] := Max(LPrev[J], LCurr[J - 1]);
    end;

    LTemp := LPrev;
    LPrev := LCurr;
    LCurr := LTemp;
    FillChar(LCurr[0], Length(LCurr) * SizeOf(Integer), 0);
  end;

  LLCSLen := LPrev[Length(AText2)];
  LMaxLen := Max(Length(AText1), Length(AText2));
  
  if LMaxLen = 0 then
    Result := 1.0
  else
    Result := LLCSLen / LMaxLen;
end;

class function TDiff.IsBinary(const AContent: TBytes): Boolean;
var
  I: Integer;
  LNullCount: Integer;
  LCheckLen: Integer;
begin
  // Check first 8KB for binary content
  LCheckLen := Min(Length(AContent), 8192);
  LNullCount := 0;
  
  for I := 0 to LCheckLen - 1 do
  begin
    // Check for NULL bytes
    if AContent[I] = 0 then
      Inc(LNullCount);
      
    // Check for non-text control characters
    if (AContent[I] < 32) and not (AContent[I] in [9, 10, 13]) then
    begin
      if LNullCount > 0 then
        Exit(True);
    end;
  end;
  
  // If more than 1% NULL bytes, consider binary
  Result := (LCheckLen > 0) and (LNullCount * 100 / LCheckLen > 1);
end;

end.
