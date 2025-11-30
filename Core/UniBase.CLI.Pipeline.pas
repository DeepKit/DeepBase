{ ============================================================================
  UniBase.CLI.Pipeline - Command Pipeline Support
  
  Version: 0.1
  Description: Provides pipeline support for CLI commands, allowing output from
               one command to be used as input for the next command.
  
  Features:
    - Pipe operator (|) for command chaining
    - Input/Output redirection (>, >>, <)
    - Tee functionality (output to both file and next command)
    - Filter functions (grep, sort, head, tail, uniq)
    - Transform functions (map, reduce, select)
  
  Usage:
    CLI.Execute('list users | grep admin | sort -n');
    CLI.Execute('query "SELECT * FROM users" > output.csv');
    CLI.Execute('cat input.txt | process | tee result.log');
  ============================================================================ }

unit UniBase.CLI.Pipeline;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.JSON,
  System.RegularExpressions,
  System.IOUtils,
  System.StrUtils,
  System.Math;

type
  // Forward declarations
  TPipeline = class;
  TPipelineStage = class;
  
  // ============================================================================
  // Pipeline Data Types
  // ============================================================================
  
  /// <summary>
  /// Data flowing through the pipeline
  /// </summary>
  TPipelineData = class
  private
    FLines: TList<string>;
    FRawData: string;
    FIsStructured: Boolean;
    FJSON: TJSONValue;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddLine(const Line: string);
    procedure SetLines(const Lines: TArray<string>);
    procedure SetRaw(const Data: string);
    procedure SetJSON(const Data: TJSONValue);
    procedure Clear;
    
    function AsLines: TArray<string>;
    function AsString: string;
    function AsJSON: TJSONValue;
    function LineCount: Integer;
    function GetLine(Index: Integer): string;
    
    property Lines: TList<string> read FLines;
    property RawData: string read FRawData;
    property IsStructured: Boolean read FIsStructured;
    property JSON: TJSONValue read FJSON;
  end;
  
  // ============================================================================
  // Pipeline Stage
  // ============================================================================
  
  TPipelineStageType = (
    pstCommand,    // Execute CLI command
    pstFilter,     // Filter lines (grep, etc.)
    pstTransform,  // Transform data
    pstRedirect,   // Output redirection
    pstTee         // Tee to file and continue
  );
  
  /// <summary>
  /// A single stage in the pipeline
  /// </summary>
  TPipelineStage = class
  private
    FStageType: TPipelineStageType;
    FCommand: string;
    FArgs: TArray<string>;
    FOptions: TDictionary<string, string>;
    FTargetFile: string;
    FAppendMode: Boolean;
  public
    constructor Create(AType: TPipelineStageType);
    destructor Destroy; override;
    
    property StageType: TPipelineStageType read FStageType;
    property Command: string read FCommand write FCommand;
    property Args: TArray<string> read FArgs write FArgs;
    property Options: TDictionary<string, string> read FOptions;
    property TargetFile: string read FTargetFile write FTargetFile;
    property AppendMode: Boolean read FAppendMode write FAppendMode;
  end;
  
  // ============================================================================
  // Built-in Filters
  // ============================================================================
  
  TFilterFunc = reference to function(const Input: TPipelineData; 
    const Args: TArray<string>; const Options: TDictionary<string, string>): TPipelineData;
  
  TPipelineFilters = class
  public
    /// <summary>Filter lines matching pattern</summary>
    class function Grep(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Sort lines</summary>
    class function Sort(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Get first N lines</summary>
    class function Head(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Get last N lines</summary>
    class function Tail(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Remove duplicate lines</summary>
    class function Uniq(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Count lines/words/chars</summary>
    class function Wc(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Reverse lines</summary>
    class function Rev(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Cut columns</summary>
    class function Cut(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Translate/replace characters</summary>
    class function Tr(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
    
    /// <summary>Select JSON fields</summary>
    class function Jq(const Input: TPipelineData; const Args: TArray<string>;
      const Options: TDictionary<string, string>): TPipelineData; static;
  end;
  
  // ============================================================================
  // Pipeline Parser
  // ============================================================================
  
  /// <summary>
  /// Parses pipeline command strings
  /// </summary>
  TPipelineParser = class
  public
    /// <summary>Parse a pipeline string into stages</summary>
    class function Parse(const CommandLine: string): TObjectList<TPipelineStage>; static;
    
    /// <summary>Check if command contains pipeline operators</summary>
    class function IsPipeline(const CommandLine: string): Boolean; static;
    
    /// <summary>Split by pipe operator respecting quotes</summary>
    class function SplitByPipe(const CommandLine: string): TArray<string>; static;
  end;
  
  // ============================================================================
  // Pipeline Executor
  // ============================================================================
  
  TCommandExecutor = reference to function(const Command: string; 
    const Input: TPipelineData): TPipelineData;
  
  /// <summary>
  /// Executes a pipeline of commands
  /// </summary>
  TPipeline = class
  private
    FStages: TObjectList<TPipelineStage>;
    FFilters: TDictionary<string, TFilterFunc>;
    FCommandExecutor: TCommandExecutor;
    FLastError: string;
    FStdinData: TPipelineData;
    
    procedure InitBuiltinFilters;
    function ExecuteStage(const Stage: TPipelineStage; 
      const Input: TPipelineData): TPipelineData;
    function ExecuteFilter(const FilterName: string; const Input: TPipelineData;
      const Args: TArray<string>; const Options: TDictionary<string, string>): TPipelineData;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Parse and execute a pipeline</summary>
    function Execute(const CommandLine: string): TPipelineData;
    
    /// <summary>Set the command executor</summary>
    procedure SetCommandExecutor(Executor: TCommandExecutor);
    
    /// <summary>Register a custom filter</summary>
    procedure RegisterFilter(const Name: string; Func: TFilterFunc);
    
    /// <summary>Set stdin data for first command</summary>
    procedure SetStdin(const Data: string); overload;
    procedure SetStdin(const Lines: TArray<string>); overload;
    
    /// <summary>Get last error message</summary>
    property LastError: string read FLastError;
    property Stages: TObjectList<TPipelineStage> read FStages;
  end;
  
  // ============================================================================
  // Helper Functions
  // ============================================================================
  
  /// <summary>Read file into pipeline data</summary>
  function ReadFileToData(const FileName: string): TPipelineData;
  
  /// <summary>Write pipeline data to file</summary>
  procedure WriteDataToFile(const Data: TPipelineData; const FileName: string;
    Append: Boolean = False);

implementation

// ============================================================================
// TPipelineData
// ============================================================================

constructor TPipelineData.Create;
begin
  inherited Create;
  FLines := TList<string>.Create;
  FRawData := '';
  FIsStructured := False;
  FJSON := nil;
end;

destructor TPipelineData.Destroy;
begin
  // JSON values need special handling - only free if we created them
  FLines.Free;
  inherited;
end;

procedure TPipelineData.AddLine(const Line: string);
begin
  FLines.Add(Line);
  FIsStructured := False;
end;

procedure TPipelineData.SetLines(const Lines: TArray<string>);
begin
  FLines.Clear;
  FLines.AddRange(Lines);
  FIsStructured := False;
end;

procedure TPipelineData.SetRaw(const Data: string);
begin
  FRawData := Data;
  FLines.Clear;
  for var Line in Data.Split([sLineBreak], TStringSplitOptions.None) do
    FLines.Add(Line);
  FIsStructured := False;
end;

procedure TPipelineData.SetJSON(const Data: TJSONValue);
begin
  FJSON := Data;
  FIsStructured := True;
  FRawData := Data.ToJSON;
end;

procedure TPipelineData.Clear;
begin
  FLines.Clear;
  FRawData := '';
  FIsStructured := False;
  FJSON := nil;
end;

function TPipelineData.AsLines: TArray<string>;
begin
  Result := FLines.ToArray;
end;

function TPipelineData.AsString: string;
begin
  if FRawData <> '' then
    Result := FRawData
  else
    Result := string.Join(sLineBreak, FLines.ToArray);
end;

function TPipelineData.AsJSON: TJSONValue;
begin
  Result := FJSON;
end;

function TPipelineData.LineCount: Integer;
begin
  Result := FLines.Count;
end;

function TPipelineData.GetLine(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FLines.Count) then
    Result := FLines[Index]
  else
    Result := '';
end;

// ============================================================================
// TPipelineStage
// ============================================================================

constructor TPipelineStage.Create(AType: TPipelineStageType);
begin
  inherited Create;
  FStageType := AType;
  FCommand := '';
  SetLength(FArgs, 0);
  FOptions := TDictionary<string, string>.Create;
  FTargetFile := '';
  FAppendMode := False;
end;

destructor TPipelineStage.Destroy;
begin
  FOptions.Free;
  inherited;
end;

// ============================================================================
// TPipelineFilters
// ============================================================================

class function TPipelineFilters.Grep(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Pattern: string;
  IgnoreCase, Invert: Boolean;
  Regex: TRegEx;
  RegexOpt: TRegExOptions;
begin
  Result := TPipelineData.Create;
  
  if Length(Args) = 0 then
  begin
    Result.SetLines(Input.AsLines);
    Exit;
  end;
  
  Pattern := Args[0];
  IgnoreCase := Options.ContainsKey('i') or Options.ContainsKey('ignore-case');
  Invert := Options.ContainsKey('v') or Options.ContainsKey('invert');
  
  RegexOpt := [];
  if IgnoreCase then
    RegexOpt := [roIgnoreCase];
  
  try
    Regex := TRegEx.Create(Pattern, RegexOpt);
  except
    // Fallback to simple substring search if regex fails
    for var Line in Input.Lines do
    begin
      var Found := False;
      if IgnoreCase then
        Found := Pos(LowerCase(Pattern), LowerCase(Line)) > 0
      else
        Found := Pos(Pattern, Line) > 0;
      
      if Found xor Invert then
        Result.AddLine(Line);
    end;
    Exit;
  end;
  
  for var Line in Input.Lines do
  begin
    var Match := Regex.IsMatch(Line);
    if Match xor Invert then
      Result.AddLine(Line);
  end;
end;

class function TPipelineFilters.Sort(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Lines: TArray<string>;
  Reverse, Numeric, Unique: Boolean;
begin
  Result := TPipelineData.Create;
  Lines := Input.AsLines;
  
  Reverse := Options.ContainsKey('r') or Options.ContainsKey('reverse');
  Numeric := Options.ContainsKey('n') or Options.ContainsKey('numeric');
  Unique := Options.ContainsKey('u') or Options.ContainsKey('unique');
  
  if Numeric then
  begin
    TArray.Sort<string>(Lines, TComparer<string>.Construct(
      function(const Left, Right: string): Integer
      var
        LNum, RNum: Extended;
      begin
        if TryStrToFloat(Left, LNum) and TryStrToFloat(Right, RNum) then
        begin
          if LNum < RNum then Result := -1
          else if LNum > RNum then Result := 1
          else Result := 0;
        end
        else
          Result := CompareStr(Left, Right);
      end
    ));
  end
  else
    TArray.Sort<string>(Lines);
  
  if Reverse then
  begin
    var Temp: TArray<string>;
    SetLength(Temp, Length(Lines));
    for var I := 0 to Length(Lines) - 1 do
      Temp[I] := Lines[Length(Lines) - 1 - I];
    Lines := Temp;
  end;
  
  if Unique then
  begin
    var UniqueList := TList<string>.Create;
    try
      var LastLine := '';
      for var Line in Lines do
      begin
        if Line <> LastLine then
        begin
          UniqueList.Add(Line);
          LastLine := Line;
        end;
      end;
      Lines := UniqueList.ToArray;
    finally
      UniqueList.Free;
    end;
  end;
  
  Result.SetLines(Lines);
end;

class function TPipelineFilters.Head(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Count: Integer;
begin
  Result := TPipelineData.Create;
  
  if (Length(Args) > 0) and TryStrToInt(Args[0], Count) then
    // OK
  else if Options.ContainsKey('n') then
    TryStrToInt(Options['n'], Count)
  else
    Count := 10;
  
  for var I := 0 to Min(Count, Input.LineCount) - 1 do
    Result.AddLine(Input.GetLine(I));
end;

class function TPipelineFilters.Tail(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Count, Start: Integer;
begin
  Result := TPipelineData.Create;
  
  if (Length(Args) > 0) and TryStrToInt(Args[0], Count) then
    // OK
  else if Options.ContainsKey('n') then
    TryStrToInt(Options['n'], Count)
  else
    Count := 10;
  
  Start := Max(0, Input.LineCount - Count);
  for var I := Start to Input.LineCount - 1 do
    Result.AddLine(Input.GetLine(I));
end;

class function TPipelineFilters.Uniq(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Count, IgnoreCase: Boolean;
  Seen: TDictionary<string, Integer>;
  Key: string;
begin
  Result := TPipelineData.Create;
  Count := Options.ContainsKey('c') or Options.ContainsKey('count');
  IgnoreCase := Options.ContainsKey('i') or Options.ContainsKey('ignore-case');
  
  Seen := TDictionary<string, Integer>.Create;
  try
    for var Line in Input.Lines do
    begin
      if IgnoreCase then
        Key := LowerCase(Line)
      else
        Key := Line;
      
      if Seen.ContainsKey(Key) then
        Seen[Key] := Seen[Key] + 1
      else
        Seen.Add(Key, 1);
    end;
    
    // Output unique lines in order
    var LastKey := '';
    for var Line in Input.Lines do
    begin
      if IgnoreCase then
        Key := LowerCase(Line)
      else
        Key := Line;
      
      if Key <> LastKey then
      begin
        if Count then
          Result.AddLine(Format('%7d %s', [Seen[Key], Line]))
        else
          Result.AddLine(Line);
        LastKey := Key;
      end;
    end;
  finally
    Seen.Free;
  end;
end;

class function TPipelineFilters.Wc(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Lines, Words, Chars: Integer;
  ShowLines, ShowWords, ShowChars: Boolean;
begin
  Result := TPipelineData.Create;
  
  Lines := Input.LineCount;
  Words := 0;
  Chars := 0;
  
  for var Line in Input.Lines do
  begin
    Inc(Chars, Length(Line) + Length(sLineBreak));
    Inc(Words, Length(Line.Split([' ', #9], TStringSplitOptions.ExcludeEmpty)));
  end;
  
  ShowLines := Options.ContainsKey('l') or Options.ContainsKey('lines');
  ShowWords := Options.ContainsKey('w') or Options.ContainsKey('words');
  ShowChars := Options.ContainsKey('c') or Options.ContainsKey('chars');
  
  // If no flags, show all
  if not (ShowLines or ShowWords or ShowChars) then
  begin
    ShowLines := True;
    ShowWords := True;
    ShowChars := True;
  end;
  
  var Output := '';
  if ShowLines then Output := Output + Format('%7d ', [Lines]);
  if ShowWords then Output := Output + Format('%7d ', [Words]);
  if ShowChars then Output := Output + Format('%7d', [Chars]);
  
  Result.AddLine(Trim(Output));
end;

class function TPipelineFilters.Rev(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
begin
  Result := TPipelineData.Create;
  
  for var Line in Input.Lines do
    Result.AddLine(ReverseString(Line));
end;

class function TPipelineFilters.Cut(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Delimiter: string;
  Fields: TArray<Integer>;
  FieldSpec: string;
begin
  Result := TPipelineData.Create;
  
  if Options.ContainsKey('d') then
    Delimiter := Options['d']
  else if Options.ContainsKey('delimiter') then
    Delimiter := Options['delimiter']
  else
    Delimiter := #9;  // Tab default
  
  if Options.ContainsKey('f') then
    FieldSpec := Options['f']
  else if Options.ContainsKey('fields') then
    FieldSpec := Options['fields']
  else
    FieldSpec := '1';
  
  // Parse field spec (1,3,5 or 1-3)
  SetLength(Fields, 0);
  for var Part in FieldSpec.Split([',']) do
  begin
    if Part.Contains('-') then
    begin
      var Range := Part.Split(['-']);
      if Length(Range) = 2 then
      begin
        var StartF, EndF: Integer;
        if TryStrToInt(Range[0], StartF) and TryStrToInt(Range[1], EndF) then
          for var I := StartF to EndF do
          begin
            SetLength(Fields, Length(Fields) + 1);
            Fields[High(Fields)] := I;
          end;
      end;
    end
    else
    begin
      var F: Integer;
      if TryStrToInt(Part, F) then
      begin
        SetLength(Fields, Length(Fields) + 1);
        Fields[High(Fields)] := F;
      end;
    end;
  end;
  
  for var Line in Input.Lines do
  begin
    var Parts := Line.Split([Delimiter]);
    var OutputParts: TArray<string>;
    SetLength(OutputParts, 0);
    
    for var F in Fields do
    begin
      if (F >= 1) and (F <= Length(Parts)) then
      begin
        SetLength(OutputParts, Length(OutputParts) + 1);
        OutputParts[High(OutputParts)] := Parts[F - 1];
      end;
    end;
    
    Result.AddLine(string.Join(Delimiter, OutputParts));
  end;
end;

class function TPipelineFilters.Tr(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  FromChars, ToChars: string;
begin
  Result := TPipelineData.Create;
  
  if Length(Args) >= 2 then
  begin
    FromChars := Args[0];
    ToChars := Args[1];
  end
  else
  begin
    Result.SetLines(Input.AsLines);
    Exit;
  end;
  
  for var Line in Input.Lines do
  begin
    var NewLine := Line;
    for var I := 1 to Length(FromChars) do
    begin
      var ToChar: Char;
      if I <= Length(ToChars) then
        ToChar := ToChars[I]
      else
        ToChar := ToChars[Length(ToChars)];
      
      NewLine := StringReplace(NewLine, FromChars[I], ToChar, [rfReplaceAll]);
    end;
    Result.AddLine(NewLine);
  end;
end;

class function TPipelineFilters.Jq(const Input: TPipelineData; const Args: TArray<string>;
  const Options: TDictionary<string, string>): TPipelineData;
var
  Query: string;
  JSONData: TJSONValue;
  JSONArray: TJSONArray;
begin
  Result := TPipelineData.Create;
  
  if Length(Args) > 0 then
    Query := Args[0]
  else
    Query := '.';
  
  // Try to parse input as JSON
  try
    if Input.IsStructured and Assigned(Input.JSON) then
      JSONData := Input.JSON
    else
      JSONData := TJSONObject.ParseJSONValue(Input.AsString);
    
    if JSONData = nil then
    begin
      Result.AddLine('Error: Invalid JSON input');
      Exit;
    end;
    
    // Simple query support: ., .field, .[index], .[]
    if Query = '.' then
    begin
      Result.AddLine(JSONData.Format(2));
    end
    else if Query = '.[]' then
    begin
      if JSONData is TJSONArray then
      begin
        JSONArray := TJSONArray(JSONData);
        for var I := 0 to JSONArray.Count - 1 do
          Result.AddLine(JSONArray.Items[I].Format(2));
      end;
    end
    else if Query.StartsWith('.') then
    begin
      var FieldPath := Copy(Query, 2, MaxInt);
      var Current: TJSONValue := JSONData;
      
      for var Field in FieldPath.Split(['.']) do
      begin
        if Field = '' then Continue;
        
        if Field.StartsWith('[') and Field.EndsWith(']') then
        begin
          var Index: Integer;
          if TryStrToInt(Copy(Field, 2, Length(Field) - 2), Index) then
          begin
            if Current is TJSONArray then
              Current := TJSONArray(Current).Items[Index];
          end;
        end
        else if Current is TJSONObject then
          Current := TJSONObject(Current).GetValue(Field);
      end;
      
      if Current <> nil then
        Result.AddLine(Current.Format(2))
      else
        Result.AddLine('null');
    end;
    
    if not Input.IsStructured then
      JSONData.Free;
  except
    on E: Exception do
      Result.AddLine('Error: ' + E.Message);
  end;
end;

// ============================================================================
// TPipelineParser
// ============================================================================

class function TPipelineParser.Parse(const CommandLine: string): TObjectList<TPipelineStage>;
var
  Parts: TArray<string>;
  Stage: TPipelineStage;
  StageParts: TArray<string>;
  I: Integer;
  Token: string;
begin
  Result := TObjectList<TPipelineStage>.Create(True);
  
  Parts := SplitByPipe(CommandLine);
  
  for var Part in Parts do
  begin
    var TrimmedPart := Trim(Part);
    if TrimmedPart = '' then Continue;
    
    // Check for output redirection
    if TrimmedPart.Contains('>>') then
    begin
      var RedirParts := TrimmedPart.Split(['>>']);
      // Command before >>
      if Trim(RedirParts[0]) <> '' then
      begin
        Stage := TPipelineStage.Create(pstCommand);
        Stage.Command := Trim(RedirParts[0]);
        Result.Add(Stage);
      end;
      // Redirect stage
      Stage := TPipelineStage.Create(pstRedirect);
      Stage.TargetFile := Trim(RedirParts[1]);
      Stage.AppendMode := True;
      Result.Add(Stage);
      Continue;
    end
    else if TrimmedPart.Contains('>') then
    begin
      var RedirParts := TrimmedPart.Split(['>']);
      if Trim(RedirParts[0]) <> '' then
      begin
        Stage := TPipelineStage.Create(pstCommand);
        Stage.Command := Trim(RedirParts[0]);
        Result.Add(Stage);
      end;
      Stage := TPipelineStage.Create(pstRedirect);
      Stage.TargetFile := Trim(RedirParts[1]);
      Stage.AppendMode := False;
      Result.Add(Stage);
      Continue;
    end;
    
    // Check for tee
    if TrimmedPart.StartsWith('tee ') then
    begin
      Stage := TPipelineStage.Create(pstTee);
      Stage.TargetFile := Trim(Copy(TrimmedPart, 5, MaxInt));
      Result.Add(Stage);
      Continue;
    end;
    
    // Check for built-in filters
    StageParts := TrimmedPart.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(StageParts) > 0 then
    begin
      Token := LowerCase(StageParts[0]);
      if (Token = 'grep') or (Token = 'sort') or (Token = 'head') or
         (Token = 'tail') or (Token = 'uniq') or (Token = 'wc') or
         (Token = 'rev') or (Token = 'cut') or (Token = 'tr') or
         (Token = 'jq') then
      begin
        Stage := TPipelineStage.Create(pstFilter);
        Stage.Command := Token;
        
        // Parse remaining as args and options
        var ArgList: TList<string> := TList<string>.Create;
        try
          I := 1;
          while I < Length(StageParts) do
          begin
            var Arg := StageParts[I];
            if Arg.StartsWith('--') then
            begin
              var OptName := Copy(Arg, 3, MaxInt);
              if OptName.Contains('=') then
              begin
                var EqPos := Pos('=', OptName);
                Stage.Options.Add(Copy(OptName, 1, EqPos - 1), Copy(OptName, EqPos + 1, MaxInt));
              end
              else
              begin
                if I + 1 < Length(StageParts) then
                begin
                  Inc(I);
                  Stage.Options.Add(OptName, StageParts[I]);
                end
                else
                  Stage.Options.Add(OptName, '');
              end;
            end
            else if Arg.StartsWith('-') and (Length(Arg) > 1) then
            begin
              for var C in Copy(Arg, 2, MaxInt) do
                Stage.Options.Add(C, '');
            end
            else
              ArgList.Add(Arg);
            Inc(I);
          end;
          Stage.Args := ArgList.ToArray;
        finally
          ArgList.Free;
        end;
        
        Result.Add(Stage);
        Continue;
      end;
    end;
    
    // Default: treat as command
    Stage := TPipelineStage.Create(pstCommand);
    Stage.Command := TrimmedPart;
    Result.Add(Stage);
  end;
end;

class function TPipelineParser.IsPipeline(const CommandLine: string): Boolean;
var
  InQuote: Boolean;
  QuoteChar: Char;
  I: Integer;
begin
  Result := False;
  InQuote := False;
  
  for I := 1 to Length(CommandLine) do
  begin
    if InQuote then
    begin
      if CommandLine[I] = QuoteChar then
        InQuote := False;
    end
    else if (CommandLine[I] = '"') or (CommandLine[I] = '''') then
    begin
      InQuote := True;
      QuoteChar := CommandLine[I];
    end
    else if (CommandLine[I] = '|') or (CommandLine[I] = '>') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

class function TPipelineParser.SplitByPipe(const CommandLine: string): TArray<string>;
var
  Parts: TList<string>;
  Current: string;
  InQuote: Boolean;
  QuoteChar: Char;
  I: Integer;
begin
  Parts := TList<string>.Create;
  try
    Current := '';
    InQuote := False;
    QuoteChar := #0;
    
    I := 1;
    while I <= Length(CommandLine) do
    begin
      if InQuote then
      begin
        if CommandLine[I] = QuoteChar then
          InQuote := False;
        Current := Current + CommandLine[I];
      end
      else if (CommandLine[I] = '"') or (CommandLine[I] = '''') then
      begin
        InQuote := True;
        QuoteChar := CommandLine[I];
        Current := Current + CommandLine[I];
      end
      else if CommandLine[I] = '|' then
      begin
        Parts.Add(Current);
        Current := '';
      end
      else
        Current := Current + CommandLine[I];
      Inc(I);
    end;
    
    if Current <> '' then
      Parts.Add(Current);
    
    Result := Parts.ToArray;
  finally
    Parts.Free;
  end;
end;

// ============================================================================
// TPipeline
// ============================================================================

constructor TPipeline.Create;
begin
  inherited Create;
  FStages := TObjectList<TPipelineStage>.Create(True);
  FFilters := TDictionary<string, TFilterFunc>.Create;
  FCommandExecutor := nil;
  FLastError := '';
  FStdinData := nil;
  
  InitBuiltinFilters;
end;

destructor TPipeline.Destroy;
begin
  FreeAndNil(FStdinData);
  FFilters.Free;
  FStages.Free;
  inherited;
end;

procedure TPipeline.InitBuiltinFilters;
begin
  FFilters.Add('grep', TPipelineFilters.Grep);
  FFilters.Add('sort', TPipelineFilters.Sort);
  FFilters.Add('head', TPipelineFilters.Head);
  FFilters.Add('tail', TPipelineFilters.Tail);
  FFilters.Add('uniq', TPipelineFilters.Uniq);
  FFilters.Add('wc', TPipelineFilters.Wc);
  FFilters.Add('rev', TPipelineFilters.Rev);
  FFilters.Add('cut', TPipelineFilters.Cut);
  FFilters.Add('tr', TPipelineFilters.Tr);
  FFilters.Add('jq', TPipelineFilters.Jq);
end;

function TPipeline.Execute(const CommandLine: string): TPipelineData;
var
  ParsedStages: TObjectList<TPipelineStage>;
  CurrentData: TPipelineData;
begin
  FLastError := '';
  Result := nil;
  
  ParsedStages := TPipelineParser.Parse(CommandLine);
  try
    // Start with stdin data if available
    if Assigned(FStdinData) then
      CurrentData := FStdinData
    else
      CurrentData := TPipelineData.Create;
    
    try
      for var Stage in ParsedStages do
      begin
        var NextData := ExecuteStage(Stage, CurrentData);
        
        if CurrentData <> FStdinData then
          CurrentData.Free;
        
        CurrentData := NextData;
        
        if CurrentData = nil then
        begin
          FLastError := 'Stage execution failed';
          Break;
        end;
      end;
      
      Result := CurrentData;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        if CurrentData <> FStdinData then
          CurrentData.Free;
      end;
    end;
  finally
    ParsedStages.Free;
    FStdinData := nil;
  end;
end;

function TPipeline.ExecuteStage(const Stage: TPipelineStage;
  const Input: TPipelineData): TPipelineData;
begin
  Result := nil;
  
  case Stage.StageType of
    pstCommand:
    begin
      if Assigned(FCommandExecutor) then
        Result := FCommandExecutor(Stage.Command, Input)
      else
      begin
        Result := TPipelineData.Create;
        Result.AddLine('Error: No command executor configured');
      end;
    end;
    
    pstFilter:
    begin
      Result := ExecuteFilter(Stage.Command, Input, Stage.Args, Stage.Options);
    end;
    
    pstRedirect:
    begin
      WriteDataToFile(Input, Stage.TargetFile, Stage.AppendMode);
      Result := TPipelineData.Create;  // Empty result after redirect
    end;
    
    pstTee:
    begin
      WriteDataToFile(Input, Stage.TargetFile, False);
      Result := TPipelineData.Create;
      Result.SetLines(Input.AsLines);  // Pass through
    end;
  end;
end;

function TPipeline.ExecuteFilter(const FilterName: string; const Input: TPipelineData;
  const Args: TArray<string>; const Options: TDictionary<string, string>): TPipelineData;
var
  FilterFunc: TFilterFunc;
begin
  if FFilters.TryGetValue(LowerCase(FilterName), FilterFunc) then
    Result := FilterFunc(Input, Args, Options)
  else
  begin
    Result := TPipelineData.Create;
    Result.AddLine('Error: Unknown filter "' + FilterName + '"');
  end;
end;

procedure TPipeline.SetCommandExecutor(Executor: TCommandExecutor);
begin
  FCommandExecutor := Executor;
end;

procedure TPipeline.RegisterFilter(const Name: string; Func: TFilterFunc);
begin
  FFilters.AddOrSetValue(LowerCase(Name), Func);
end;

procedure TPipeline.SetStdin(const Data: string);
begin
  FreeAndNil(FStdinData);
  FStdinData := TPipelineData.Create;
  FStdinData.SetRaw(Data);
end;

procedure TPipeline.SetStdin(const Lines: TArray<string>);
begin
  FreeAndNil(FStdinData);
  FStdinData := TPipelineData.Create;
  FStdinData.SetLines(Lines);
end;

// ============================================================================
// Helper Functions
// ============================================================================

function ReadFileToData(const FileName: string): TPipelineData;
begin
  Result := TPipelineData.Create;
  if TFile.Exists(FileName) then
    Result.SetRaw(TFile.ReadAllText(FileName, TEncoding.UTF8))
  else
    Result.AddLine('Error: File not found "' + FileName + '"');
end;

procedure WriteDataToFile(const Data: TPipelineData; const FileName: string;
  Append: Boolean);
var
  Content: string;
begin
  Content := Data.AsString;
  
  if Append and TFile.Exists(FileName) then
    TFile.AppendAllText(FileName, sLineBreak + Content, TEncoding.UTF8)
  else
    TFile.WriteAllText(FileName, Content, TEncoding.UTF8);
end;

end.
