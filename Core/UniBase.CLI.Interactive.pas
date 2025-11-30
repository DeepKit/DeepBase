{ ============================================================================
  UniBase.CLI.Interactive - Interactive CLI Mode (REPL)
  
  Version: 0.3
  Description: Provides interactive command-line interface with REPL mode,
               command completion, history, and multiple output formats.
  
  Usage:
    var CLI := TInteractiveCLI.Create;
    try
      CLI.RegisterCommand('help', @HandleHelp, 'Show help');
      CLI.RegisterCommand('query', @HandleQuery, 'Execute SQL query');
      CLI.Run;  // Starts REPL loop
    finally
      CLI.Free;
    end;
  ============================================================================ }

unit UniBase.CLI.Interactive;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.StrUtils,
  System.Math;

type
  // Forward declarations
  TInteractiveCLI = class;
  TCommandContext = class;
  
  // ============================================================================
  // Output Format Types
  // ============================================================================
  
  TOutputFormat = (ofText, ofJSON, ofYAML, ofTable, ofCSV, ofMarkdown);
  
  /// <summary>
  /// Table column definition for table output
  /// </summary>
  TTableColumn = record
    Name: string;
    Width: Integer;
    Alignment: TAlignment;  // taLeftJustify, taRightJustify, taCenter
    
    class function Create(const AName: string; AWidth: Integer = 0;
      AAlignment: TAlignment = taLeftJustify): TTableColumn; static;
  end;
  
  /// <summary>
  /// Output formatter interface
  /// </summary>
  IOutputFormatter = interface
    ['{A7B8C9D0-E1F2-4A3B-5C6D-7E8F9A0B1C2D}']
    function FormatTable(const Columns: TArray<TTableColumn>; 
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  // ============================================================================
  // Command Types
  // ============================================================================
  
  /// <summary>
  /// Command execution result
  /// </summary>
  TCommandResult = record
    Success: Boolean;
    Message: string;
    Data: TJSONValue;
    ExitCode: Integer;
    
    class function OK(const Msg: string = ''): TCommandResult; static;
    class function Error(const Msg: string; Code: Integer = 1): TCommandResult; static;
    class function WithData(AData: TJSONValue): TCommandResult; static;
  end;
  
  /// <summary>
  /// Command handler signature
  /// </summary>
  TCommandHandler = reference to function(Context: TCommandContext): TCommandResult;
  
  /// <summary>
  /// Command completion provider
  /// </summary>
  TCompletionProvider = reference to function(const Partial: string; 
    ArgIndex: Integer): TArray<string>;
  
  /// <summary>
  /// Command definition
  /// </summary>
  TCommandDef = class
  private
    FName: string;
    FDescription: string;
    FUsage: string;
    FHandler: TCommandHandler;
    FCompletionProvider: TCompletionProvider;
    FAliases: TList<string>;
    FSubcommands: TObjectDictionary<string, TCommandDef>;
    FOptions: TDictionary<string, string>;  // option -> description
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    
    function AddAlias(const Alias: string): TCommandDef;
    function AddOption(const Option, Description: string): TCommandDef;
    function AddSubcommand(const Name, Description: string; 
      Handler: TCommandHandler): TCommandDef;
    function SetCompletion(Provider: TCompletionProvider): TCommandDef;
    
    property Name: string read FName;
    property Description: string read FDescription write FDescription;
    property Usage: string read FUsage write FUsage;
    property Handler: TCommandHandler read FHandler write FHandler;
    property CompletionProvider: TCompletionProvider read FCompletionProvider;
    property Aliases: TList<string> read FAliases;
    property Subcommands: TObjectDictionary<string, TCommandDef> read FSubcommands;
    property Options: TDictionary<string, string> read FOptions;
  end;
  
  // ============================================================================
  // Command Context
  // ============================================================================
  
  /// <summary>
  /// Context passed to command handlers
  /// </summary>
  TCommandContext = class
  private
    FCLI: TInteractiveCLI;
    FCommandLine: string;
    FCommand: string;
    FArgs: TArray<string>;
    FOptions: TDictionary<string, string>;
    FFlags: TList<string>;
    FOutputFormat: TOutputFormat;
  public
    constructor Create(ACLI: TInteractiveCLI);
    destructor Destroy; override;
    
    /// <summary>Parse command line into args, options, and flags</summary>
    procedure Parse(const Line: string);
    
    /// <summary>Get positional argument by index</summary>
    function GetArg(Index: Integer; const Default: string = ''): string;
    
    /// <summary>Get option value</summary>
    function GetOption(const Name: string; const Default: string = ''): string;
    
    /// <summary>Check if flag is set</summary>
    function HasFlag(const Name: string): Boolean;
    
    /// <summary>Check if option exists</summary>
    function HasOption(const Name: string): Boolean;
    
    /// <summary>Get all remaining args from index</summary>
    function GetRemainingArgs(FromIndex: Integer): string;
    
    /// <summary>Print output in current format</summary>
    procedure Print(const Text: string);
    procedure PrintTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>);
    procedure PrintJSON(const Value: TJSONValue);
    procedure PrintError(const Msg: string);
    procedure PrintSuccess(const Msg: string);
    
    property CLI: TInteractiveCLI read FCLI;
    property CommandLine: string read FCommandLine;
    property Command: string read FCommand;
    property Args: TArray<string> read FArgs;
    property Options: TDictionary<string, string> read FOptions;
    property Flags: TList<string> read FFlags;
    property OutputFormat: TOutputFormat read FOutputFormat write FOutputFormat;
  end;
  
  // ============================================================================
  // Output Formatters
  // ============================================================================
  
  TTextFormatter = class(TInterfacedObject, IOutputFormatter)
  public
    function FormatTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  TJSONFormatter = class(TInterfacedObject, IOutputFormatter)
  public
    function FormatTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  TYAMLFormatter = class(TInterfacedObject, IOutputFormatter)
  public
    function FormatTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  TTableFormatter = class(TInterfacedObject, IOutputFormatter)
  private
    FBorderStyle: Integer;  // 0=ASCII, 1=Unicode
  public
    constructor Create(BorderStyle: Integer = 0);
    function FormatTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  TCSVFormatter = class(TInterfacedObject, IOutputFormatter)
  private
    FDelimiter: Char;
  public
    constructor Create(Delimiter: Char = ',');
    function FormatTable(const Columns: TArray<TTableColumn>;
      const Rows: TArray<TArray<string>>): string;
    function FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
    function FormatList(const Items: TArray<string>): string;
    function FormatJSON(const Value: TJSONValue): string;
  end;
  
  // ============================================================================
  // Interactive CLI
  // ============================================================================
  
  /// <summary>
  /// Interactive CLI with REPL mode
  /// </summary>
  TInteractiveCLI = class
  private
    FCommands: TObjectDictionary<string, TCommandDef>;
    FAliasMap: TDictionary<string, string>;
    FHistory: TList<string>;
    FHistoryIndex: Integer;
    FMaxHistorySize: Integer;
    FPrompt: string;
    FRunning: Boolean;
    FOutputFormat: TOutputFormat;
    FFormatters: TDictionary<TOutputFormat, IOutputFormatter>;
    FOnBeforeCommand: TProc<TCommandContext>;
    FOnAfterCommand: TProc<TCommandContext, TCommandResult>;
    FVariables: TDictionary<string, string>;
    FLastResult: TCommandResult;
    
    procedure InitBuiltinCommands;
    procedure InitFormatters;
    function ParseLine(const Line: string): TArray<string>;
    function GetCompletions(const Partial: string): TArray<string>;
    function ExecuteCommand(const Line: string): TCommandResult;
    function ExpandVariables(const Line: string): string;
    
    // Built-in command handlers
    function HandleHelp(Context: TCommandContext): TCommandResult;
    function HandleExit(Context: TCommandContext): TCommandResult;
    function HandleHistory(Context: TCommandContext): TCommandResult;
    function HandleClear(Context: TCommandContext): TCommandResult;
    function HandleSet(Context: TCommandContext): TCommandResult;
    function HandleFormat(Context: TCommandContext): TCommandResult;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Register a command</summary>
    function RegisterCommand(const Name, Description: string;
      Handler: TCommandHandler): TCommandDef;
    
    /// <summary>Unregister a command</summary>
    procedure UnregisterCommand(const Name: string);
    
    /// <summary>Get command by name or alias</summary>
    function GetCommand(const Name: string): TCommandDef;
    
    /// <summary>Check if command exists</summary>
    function CommandExists(const Name: string): Boolean;
    
    /// <summary>Start REPL loop</summary>
    procedure Run;
    
    /// <summary>Stop REPL loop</summary>
    procedure Stop;
    
    /// <summary>Execute a single command line</summary>
    function Execute(const Line: string): TCommandResult;
    
    /// <summary>Execute commands from file</summary>
    function ExecuteScript(const FileName: string): TCommandResult;
    
    /// <summary>Get current output formatter</summary>
    function GetFormatter: IOutputFormatter;
    
    /// <summary>Add to history</summary>
    procedure AddToHistory(const Line: string);
    
    /// <summary>Get history entry</summary>
    function GetHistoryEntry(Index: Integer): string;
    
    /// <summary>Save history to file</summary>
    procedure SaveHistory(const FileName: string);
    
    /// <summary>Load history from file</summary>
    procedure LoadHistory(const FileName: string);
    
    /// <summary>Set variable</summary>
    procedure SetVariable(const Name, Value: string);
    
    /// <summary>Get variable</summary>
    function GetVariable(const Name, Default: string): string;
    
    /// <summary>Print text to console</summary>
    procedure Print(const Text: string);
    procedure PrintLn(const Text: string = '');
    procedure PrintError(const Text: string);
    procedure PrintSuccess(const Text: string);
    procedure PrintWarning(const Text: string);
    
    property Commands: TObjectDictionary<string, TCommandDef> read FCommands;
    property History: TList<string> read FHistory;
    property MaxHistorySize: Integer read FMaxHistorySize write FMaxHistorySize;
    property Prompt: string read FPrompt write FPrompt;
    property Running: Boolean read FRunning;
    property OutputFormat: TOutputFormat read FOutputFormat write FOutputFormat;
    property Variables: TDictionary<string, string> read FVariables;
    property LastResult: TCommandResult read FLastResult;
    property OnBeforeCommand: TProc<TCommandContext> read FOnBeforeCommand write FOnBeforeCommand;
    property OnAfterCommand: TProc<TCommandContext, TCommandResult> read FOnAfterCommand write FOnAfterCommand;
  end;
  
  // ============================================================================
  // Helper Types
  // ============================================================================
  
  /// <summary>
  /// ANSI color codes for terminal output
  /// </summary>
  TAnsiColor = class
  public const
    Reset     = #27'[0m';
    Bold      = #27'[1m';
    Dim       = #27'[2m';
    Underline = #27'[4m';
    
    Black   = #27'[30m';
    Red     = #27'[31m';
    Green   = #27'[32m';
    Yellow  = #27'[33m';
    Blue    = #27'[34m';
    Magenta = #27'[35m';
    Cyan    = #27'[36m';
    White   = #27'[37m';
    
    BgBlack   = #27'[40m';
    BgRed     = #27'[41m';
    BgGreen   = #27'[42m';
    BgYellow  = #27'[43m';
    BgBlue    = #27'[44m';
    BgMagenta = #27'[45m';
    BgCyan    = #27'[46m';
    BgWhite   = #27'[47m';
    
    class function Colorize(const Text, Color: string): string; static;
    class function StripColors(const Text: string): string; static;
  end;

implementation

uses
  System.IOUtils,
  System.RegularExpressions;

// ============================================================================
// TTableColumn
// ============================================================================

class function TTableColumn.Create(const AName: string; AWidth: Integer;
  AAlignment: TAlignment): TTableColumn;
begin
  Result.Name := AName;
  Result.Width := AWidth;
  Result.Alignment := AAlignment;
end;

// ============================================================================
// TCommandResult
// ============================================================================

class function TCommandResult.OK(const Msg: string): TCommandResult;
begin
  Result.Success := True;
  Result.Message := Msg;
  Result.Data := nil;
  Result.ExitCode := 0;
end;

class function TCommandResult.Error(const Msg: string; Code: Integer): TCommandResult;
begin
  Result.Success := False;
  Result.Message := Msg;
  Result.Data := nil;
  Result.ExitCode := Code;
end;

class function TCommandResult.WithData(AData: TJSONValue): TCommandResult;
begin
  Result.Success := True;
  Result.Message := '';
  Result.Data := AData;
  Result.ExitCode := 0;
end;

// ============================================================================
// TCommandDef
// ============================================================================

constructor TCommandDef.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FDescription := '';
  FUsage := '';
  FHandler := nil;
  FCompletionProvider := nil;
  FAliases := TList<string>.Create;
  FSubcommands := TObjectDictionary<string, TCommandDef>.Create([doOwnsValues]);
  FOptions := TDictionary<string, string>.Create;
end;

destructor TCommandDef.Destroy;
begin
  FOptions.Free;
  FSubcommands.Free;
  FAliases.Free;
  inherited;
end;

function TCommandDef.AddAlias(const Alias: string): TCommandDef;
begin
  if not FAliases.Contains(Alias) then
    FAliases.Add(Alias);
  Result := Self;
end;

function TCommandDef.AddOption(const Option, Description: string): TCommandDef;
begin
  FOptions.AddOrSetValue(Option, Description);
  Result := Self;
end;

function TCommandDef.AddSubcommand(const Name, Description: string;
  Handler: TCommandHandler): TCommandDef;
var
  Sub: TCommandDef;
begin
  Sub := TCommandDef.Create(Name);
  Sub.Description := Description;
  Sub.Handler := Handler;
  FSubcommands.AddOrSetValue(Name, Sub);
  Result := Sub;
end;

function TCommandDef.SetCompletion(Provider: TCompletionProvider): TCommandDef;
begin
  FCompletionProvider := Provider;
  Result := Self;
end;

// ============================================================================
// TCommandContext
// ============================================================================

constructor TCommandContext.Create(ACLI: TInteractiveCLI);
begin
  inherited Create;
  FCLI := ACLI;
  FOptions := TDictionary<string, string>.Create;
  FFlags := TList<string>.Create;
  FOutputFormat := ACLI.OutputFormat;
end;

destructor TCommandContext.Destroy;
begin
  FFlags.Free;
  FOptions.Free;
  inherited;
end;

procedure TCommandContext.Parse(const Line: string);
var
  Parts: TArray<string>;
  I: Integer;
  Part, Key, Value: string;
  InQuote: Boolean;
  QuoteChar: Char;
  Current: string;
  ArgList: TList<string>;
begin
  FCommandLine := Line;
  ArgList := TList<string>.Create;
  try
    // Parse line respecting quotes
    Current := '';
    InQuote := False;
    QuoteChar := #0;
    
    for I := 1 to Length(Line) do
    begin
      if InQuote then
      begin
        if Line[I] = QuoteChar then
          InQuote := False
        else
          Current := Current + Line[I];
      end
      else if (Line[I] = '"') or (Line[I] = '''') then
      begin
        InQuote := True;
        QuoteChar := Line[I];
      end
      else if Line[I] = ' ' then
      begin
        if Current <> '' then
        begin
          ArgList.Add(Current);
          Current := '';
        end;
      end
      else
        Current := Current + Line[I];
    end;
    
    if Current <> '' then
      ArgList.Add(Current);
    
    // First part is command
    if ArgList.Count > 0 then
    begin
      FCommand := ArgList[0];
      ArgList.Delete(0);
    end;
    
    // Parse remaining into args, options, and flags
    SetLength(FArgs, 0);
    I := 0;
    while I < ArgList.Count do
    begin
      Part := ArgList[I];
      
      if Part.StartsWith('--') then
      begin
        // Long option
        Key := Copy(Part, 3, MaxInt);
        if Key.Contains('=') then
        begin
          Value := Copy(Key, Pos('=', Key) + 1, MaxInt);
          Key := Copy(Key, 1, Pos('=', Key) - 1);
          FOptions.AddOrSetValue(Key, Value);
        end
        else if (I + 1 < ArgList.Count) and not ArgList[I + 1].StartsWith('-') then
        begin
          Inc(I);
          FOptions.AddOrSetValue(Key, ArgList[I]);
        end
        else
          FFlags.Add(Key);
      end
      else if Part.StartsWith('-') and (Length(Part) > 1) then
      begin
        // Short option(s)
        Key := Copy(Part, 2, MaxInt);
        if Length(Key) = 1 then
        begin
          if (I + 1 < ArgList.Count) and not ArgList[I + 1].StartsWith('-') then
          begin
            Inc(I);
            FOptions.AddOrSetValue(Key, ArgList[I]);
          end
          else
            FFlags.Add(Key);
        end
        else
        begin
          // Multiple short flags
          for var C in Key do
            FFlags.Add(C);
        end;
      end
      else
      begin
        // Positional argument
        SetLength(FArgs, Length(FArgs) + 1);
        FArgs[High(FArgs)] := Part;
      end;
      
      Inc(I);
    end;
    
    // Check for output format flag
    if HasFlag('json') or HasOption('format') and (GetOption('format') = 'json') then
      FOutputFormat := ofJSON
    else if HasFlag('yaml') or HasOption('format') and (GetOption('format') = 'yaml') then
      FOutputFormat := ofYAML
    else if HasFlag('csv') or HasOption('format') and (GetOption('format') = 'csv') then
      FOutputFormat := ofCSV
    else if HasFlag('table') or HasOption('format') and (GetOption('format') = 'table') then
      FOutputFormat := ofTable;
  finally
    ArgList.Free;
  end;
end;

function TCommandContext.GetArg(Index: Integer; const Default: string): string;
begin
  if (Index >= 0) and (Index < Length(FArgs)) then
    Result := FArgs[Index]
  else
    Result := Default;
end;

function TCommandContext.GetOption(const Name: string; const Default: string): string;
begin
  if not FOptions.TryGetValue(Name, Result) then
    Result := Default;
end;

function TCommandContext.HasFlag(const Name: string): Boolean;
begin
  Result := FFlags.Contains(Name);
end;

function TCommandContext.HasOption(const Name: string): Boolean;
begin
  Result := FOptions.ContainsKey(Name);
end;

function TCommandContext.GetRemainingArgs(FromIndex: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := FromIndex to High(FArgs) do
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + FArgs[I];
  end;
end;

procedure TCommandContext.Print(const Text: string);
begin
  FCLI.Print(Text);
end;

procedure TCommandContext.PrintTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>);
var
  Formatter: IOutputFormatter;
begin
  Formatter := FCLI.GetFormatter;
  WriteLn(Formatter.FormatTable(Columns, Rows));
end;

procedure TCommandContext.PrintJSON(const Value: TJSONValue);
begin
  if FOutputFormat = ofJSON then
    WriteLn(Value.Format)
  else
    WriteLn(Value.ToString);
end;

procedure TCommandContext.PrintError(const Msg: string);
begin
  FCLI.PrintError(Msg);
end;

procedure TCommandContext.PrintSuccess(const Msg: string);
begin
  FCLI.PrintSuccess(Msg);
end;

// ============================================================================
// TTextFormatter
// ============================================================================

function TTextFormatter.FormatTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>): string;
var
  Widths: TArray<Integer>;
  I, J: Integer;
  Line: string;
begin
  // Calculate column widths
  SetLength(Widths, Length(Columns));
  for I := 0 to High(Columns) do
  begin
    Widths[I] := Length(Columns[I].Name);
    if Columns[I].Width > 0 then
      Widths[I] := Max(Widths[I], Columns[I].Width);
  end;
  
  for I := 0 to High(Rows) do
    for J := 0 to Min(High(Columns), High(Rows[I])) do
      Widths[J] := Max(Widths[J], Length(Rows[I][J]));
  
  // Header
  Result := '';
  for I := 0 to High(Columns) do
  begin
    if I > 0 then
      Result := Result + '  ';
    Result := Result + Format('%-*s', [Widths[I], Columns[I].Name]);
  end;
  Result := Result + sLineBreak;
  
  // Separator
  for I := 0 to High(Columns) do
  begin
    if I > 0 then
      Result := Result + '  ';
    Result := Result + StringOfChar('-', Widths[I]);
  end;
  Result := Result + sLineBreak;
  
  // Rows
  for I := 0 to High(Rows) do
  begin
    Line := '';
    for J := 0 to High(Columns) do
    begin
      if J > 0 then
        Line := Line + '  ';
      if J <= High(Rows[I]) then
        Line := Line + Format('%-*s', [Widths[J], Rows[I][J]])
      else
        Line := Line + StringOfChar(' ', Widths[J]);
    end;
    Result := Result + Line + sLineBreak;
  end;
end;

function TTextFormatter.FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
var
  MaxKeyLen, I: Integer;
begin
  MaxKeyLen := 0;
  for I := 0 to High(Pairs) do
    MaxKeyLen := Max(MaxKeyLen, Length(Pairs[I].Key));
  
  Result := '';
  for I := 0 to High(Pairs) do
    Result := Result + Format('%-*s: %s' + sLineBreak, 
      [MaxKeyLen, Pairs[I].Key, Pairs[I].Value]);
end;

function TTextFormatter.FormatList(const Items: TArray<string>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Items) do
    Result := Result + '  - ' + Items[I] + sLineBreak;
end;

function TTextFormatter.FormatJSON(const Value: TJSONValue): string;
begin
  Result := Value.Format;
end;

// ============================================================================
// TJSONFormatter
// ============================================================================

function TJSONFormatter.FormatTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>): string;
var
  Root: TJSONArray;
  Row: TJSONObject;
  I, J: Integer;
begin
  Root := TJSONArray.Create;
  try
    for I := 0 to High(Rows) do
    begin
      Row := TJSONObject.Create;
      for J := 0 to Min(High(Columns), High(Rows[I])) do
        Row.AddPair(Columns[J].Name, Rows[I][J]);
      Root.AddElement(Row);
    end;
    Result := Root.Format;
  finally
    Root.Free;
  end;
end;

function TJSONFormatter.FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
var
  Obj: TJSONObject;
  I: Integer;
begin
  Obj := TJSONObject.Create;
  try
    for I := 0 to High(Pairs) do
      Obj.AddPair(Pairs[I].Key, Pairs[I].Value);
    Result := Obj.Format;
  finally
    Obj.Free;
  end;
end;

function TJSONFormatter.FormatList(const Items: TArray<string>): string;
var
  Arr: TJSONArray;
  I: Integer;
begin
  Arr := TJSONArray.Create;
  try
    for I := 0 to High(Items) do
      Arr.Add(Items[I]);
    Result := Arr.Format;
  finally
    Arr.Free;
  end;
end;

function TJSONFormatter.FormatJSON(const Value: TJSONValue): string;
begin
  Result := Value.Format;
end;

// ============================================================================
// TYAMLFormatter
// ============================================================================

function TYAMLFormatter.FormatTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>): string;
var
  I, J: Integer;
begin
  Result := '';
  for I := 0 to High(Rows) do
  begin
    Result := Result + '- ';
    for J := 0 to Min(High(Columns), High(Rows[I])) do
    begin
      if J > 0 then
        Result := Result + '  ';
      Result := Result + Columns[J].Name + ': ' + Rows[I][J] + sLineBreak;
    end;
  end;
end;

function TYAMLFormatter.FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Pairs) do
    Result := Result + Pairs[I].Key + ': ' + Pairs[I].Value + sLineBreak;
end;

function TYAMLFormatter.FormatList(const Items: TArray<string>): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Items) do
    Result := Result + '- ' + Items[I] + sLineBreak;
end;

function TYAMLFormatter.FormatJSON(const Value: TJSONValue): string;
begin
  // Simple YAML representation
  Result := Value.Format;
end;

// ============================================================================
// TTableFormatter
// ============================================================================

constructor TTableFormatter.Create(BorderStyle: Integer);
begin
  inherited Create;
  FBorderStyle := BorderStyle;
end;

function TTableFormatter.FormatTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>): string;
var
  Widths: TArray<Integer>;
  I, J: Integer;
  HLine, VLine, Cross, Corner: string;
begin
  // Border characters
  if FBorderStyle = 1 then
  begin
    HLine := '─'; VLine := '│'; Cross := '┼'; Corner := '┌┬┐├┼┤└┴┘';
  end
  else
  begin
    HLine := '-'; VLine := '|'; Cross := '+'; Corner := '++++++++++';
  end;
  
  // Calculate widths
  SetLength(Widths, Length(Columns));
  for I := 0 to High(Columns) do
  begin
    Widths[I] := Length(Columns[I].Name);
    if Columns[I].Width > 0 then
      Widths[I] := Max(Widths[I], Columns[I].Width);
  end;
  
  for I := 0 to High(Rows) do
    for J := 0 to Min(High(Columns), High(Rows[I])) do
      Widths[J] := Max(Widths[J], Length(Rows[I][J]));
  
  // Top border
  Result := Corner[1];
  for I := 0 to High(Columns) do
  begin
    Result := Result + StringOfChar(HLine[1], Widths[I] + 2);
    if I < High(Columns) then
      Result := Result + Corner[2]
    else
      Result := Result + Corner[3];
  end;
  Result := Result + sLineBreak;
  
  // Header
  Result := Result + VLine;
  for I := 0 to High(Columns) do
    Result := Result + ' ' + Format('%-*s', [Widths[I], Columns[I].Name]) + ' ' + VLine;
  Result := Result + sLineBreak;
  
  // Header separator
  Result := Result + Corner[4];
  for I := 0 to High(Columns) do
  begin
    Result := Result + StringOfChar(HLine[1], Widths[I] + 2);
    if I < High(Columns) then
      Result := Result + Corner[5]
    else
      Result := Result + Corner[6];
  end;
  Result := Result + sLineBreak;
  
  // Rows
  for I := 0 to High(Rows) do
  begin
    Result := Result + VLine;
    for J := 0 to High(Columns) do
    begin
      if J <= High(Rows[I]) then
        Result := Result + ' ' + Format('%-*s', [Widths[J], Rows[I][J]]) + ' '
      else
        Result := Result + ' ' + StringOfChar(' ', Widths[J]) + ' ';
      Result := Result + VLine;
    end;
    Result := Result + sLineBreak;
  end;
  
  // Bottom border
  Result := Result + Corner[7];
  for I := 0 to High(Columns) do
  begin
    Result := Result + StringOfChar(HLine[1], Widths[I] + 2);
    if I < High(Columns) then
      Result := Result + Corner[8]
    else
      Result := Result + Corner[9];
  end;
end;

function TTableFormatter.FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
begin
  Result := TTextFormatter.Create.FormatKeyValue(Pairs);
end;

function TTableFormatter.FormatList(const Items: TArray<string>): string;
begin
  Result := TTextFormatter.Create.FormatList(Items);
end;

function TTableFormatter.FormatJSON(const Value: TJSONValue): string;
begin
  Result := Value.Format;
end;

// ============================================================================
// TCSVFormatter
// ============================================================================

constructor TCSVFormatter.Create(Delimiter: Char);
begin
  inherited Create;
  FDelimiter := Delimiter;
end;

function TCSVFormatter.FormatTable(const Columns: TArray<TTableColumn>;
  const Rows: TArray<TArray<string>>): string;
var
  I, J: Integer;
  Value: string;
  
  function EscapeCSV(const S: string): string;
  begin
    if S.Contains(FDelimiter) or S.Contains('"') or S.Contains(#13) or S.Contains(#10) then
      Result := '"' + S.Replace('"', '""') + '"'
    else
      Result := S;
  end;
begin
  // Header
  Result := '';
  for I := 0 to High(Columns) do
  begin
    if I > 0 then
      Result := Result + FDelimiter;
    Result := Result + EscapeCSV(Columns[I].Name);
  end;
  Result := Result + sLineBreak;
  
  // Rows
  for I := 0 to High(Rows) do
  begin
    for J := 0 to High(Columns) do
    begin
      if J > 0 then
        Result := Result + FDelimiter;
      if J <= High(Rows[I]) then
        Result := Result + EscapeCSV(Rows[I][J]);
    end;
    Result := Result + sLineBreak;
  end;
end;

function TCSVFormatter.FormatKeyValue(const Pairs: TArray<TPair<string, string>>): string;
var
  I: Integer;
begin
  Result := 'Key' + FDelimiter + 'Value' + sLineBreak;
  for I := 0 to High(Pairs) do
    Result := Result + Pairs[I].Key + FDelimiter + Pairs[I].Value + sLineBreak;
end;

function TCSVFormatter.FormatList(const Items: TArray<string>): string;
var
  I: Integer;
begin
  Result := 'Item' + sLineBreak;
  for I := 0 to High(Items) do
    Result := Result + Items[I] + sLineBreak;
end;

function TCSVFormatter.FormatJSON(const Value: TJSONValue): string;
begin
  Result := Value.ToString;
end;

// ============================================================================
// TAnsiColor
// ============================================================================

class function TAnsiColor.Colorize(const Text, Color: string): string;
begin
  Result := Color + Text + Reset;
end;

class function TAnsiColor.StripColors(const Text: string): string;
begin
  Result := TRegEx.Replace(Text, #27'\[[0-9;]*m', '');
end;

// ============================================================================
// TInteractiveCLI
// ============================================================================

constructor TInteractiveCLI.Create;
begin
  inherited Create;
  FCommands := TObjectDictionary<string, TCommandDef>.Create([doOwnsValues]);
  FAliasMap := TDictionary<string, string>.Create;
  FHistory := TList<string>.Create;
  FHistoryIndex := -1;
  FMaxHistorySize := 1000;
  FPrompt := '> ';
  FRunning := False;
  FOutputFormat := ofText;
  FFormatters := TDictionary<TOutputFormat, IOutputFormatter>.Create;
  FVariables := TDictionary<string, string>.Create;
  
  InitFormatters;
  InitBuiltinCommands;
end;

destructor TInteractiveCLI.Destroy;
begin
  FVariables.Free;
  FFormatters.Free;
  FHistory.Free;
  FAliasMap.Free;
  FCommands.Free;
  inherited;
end;

procedure TInteractiveCLI.InitFormatters;
begin
  FFormatters.Add(ofText, TTextFormatter.Create);
  FFormatters.Add(ofJSON, TJSONFormatter.Create);
  FFormatters.Add(ofYAML, TYAMLFormatter.Create);
  FFormatters.Add(ofTable, TTableFormatter.Create);
  FFormatters.Add(ofCSV, TCSVFormatter.Create);
  FFormatters.Add(ofMarkdown, TTextFormatter.Create);  // Use text for now
end;

procedure TInteractiveCLI.InitBuiltinCommands;
begin
  RegisterCommand('help', 'Show help for commands', HandleHelp)
    .AddAlias('?')
    .AddOption('command', 'Show help for specific command');
    
  RegisterCommand('exit', 'Exit the CLI', HandleExit)
    .AddAlias('quit')
    .AddAlias('q');
    
  RegisterCommand('history', 'Show command history', HandleHistory)
    .AddOption('n', 'Number of entries to show')
    .AddOption('clear', 'Clear history');
    
  RegisterCommand('clear', 'Clear the screen', HandleClear)
    .AddAlias('cls');
    
  RegisterCommand('set', 'Set a variable', HandleSet)
    .AddOption('name', 'Variable name')
    .AddOption('value', 'Variable value');
    
  RegisterCommand('format', 'Set output format', HandleFormat)
    .SetCompletion(
      function(const Partial: string; ArgIndex: Integer): TArray<string>
      begin
        Result := ['text', 'json', 'yaml', 'table', 'csv'];
      end
    );
end;

function TInteractiveCLI.RegisterCommand(const Name, Description: string;
  Handler: TCommandHandler): TCommandDef;
begin
  Result := TCommandDef.Create(Name);
  Result.Description := Description;
  Result.Handler := Handler;
  FCommands.AddOrSetValue(Name, Result);
end;

procedure TInteractiveCLI.UnregisterCommand(const Name: string);
begin
  FCommands.Remove(Name);
  // Remove aliases
  for var Key in FAliasMap.Keys.ToArray do
    if FAliasMap[Key] = Name then
      FAliasMap.Remove(Key);
end;

function TInteractiveCLI.GetCommand(const Name: string): TCommandDef;
var
  RealName: string;
begin
  // Check direct name
  if FCommands.TryGetValue(Name, Result) then
    Exit;
  
  // Check aliases
  if FAliasMap.TryGetValue(Name, RealName) then
    FCommands.TryGetValue(RealName, Result)
  else
    Result := nil;
end;

function TInteractiveCLI.CommandExists(const Name: string): Boolean;
begin
  Result := FCommands.ContainsKey(Name) or FAliasMap.ContainsKey(Name);
end;

procedure TInteractiveCLI.Run;
var
  Line: string;
begin
  FRunning := True;
  PrintLn('UniBase CLI v0.3 - Type "help" for available commands');
  PrintLn;
  
  while FRunning do
  begin
    Write(FPrompt);
    ReadLn(Line);
    Line := Trim(Line);
    
    if Line = '' then
      Continue;
    
    AddToHistory(Line);
    Execute(Line);
  end;
end;

procedure TInteractiveCLI.Stop;
begin
  FRunning := False;
end;

function TInteractiveCLI.Execute(const Line: string): TCommandResult;
begin
  Result := ExecuteCommand(ExpandVariables(Line));
  FLastResult := Result;
end;

function TInteractiveCLI.ExecuteScript(const FileName: string): TCommandResult;
var
  Lines: TStringList;
  Line: string;
begin
  Result := TCommandResult.OK;
  
  if not FileExists(FileName) then
    Exit(TCommandResult.Error('File not found: ' + FileName));
  
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    for Line in Lines do
    begin
      Line := Trim(Line);
      if (Line = '') or Line.StartsWith('#') then
        Continue;
      
      Result := Execute(Line);
      if not Result.Success then
        Break;
    end;
  finally
    Lines.Free;
  end;
end;

function TInteractiveCLI.ExecuteCommand(const Line: string): TCommandResult;
var
  Context: TCommandContext;
  Cmd: TCommandDef;
begin
  Context := TCommandContext.Create(Self);
  try
    Context.Parse(Line);
    
    if Context.Command = '' then
      Exit(TCommandResult.OK);
    
    Cmd := GetCommand(Context.Command);
    if Cmd = nil then
    begin
      PrintError('Unknown command: ' + Context.Command);
      Exit(TCommandResult.Error('Unknown command'));
    end;
    
    if not Assigned(Cmd.Handler) then
    begin
      PrintError('Command not implemented: ' + Context.Command);
      Exit(TCommandResult.Error('Not implemented'));
    end;
    
    if Assigned(FOnBeforeCommand) then
      FOnBeforeCommand(Context);
    
    try
      Result := Cmd.Handler(Context);
    except
      on E: Exception do
      begin
        PrintError('Error: ' + E.Message);
        Result := TCommandResult.Error(E.Message);
      end;
    end;
    
    if Assigned(FOnAfterCommand) then
      FOnAfterCommand(Context, Result);
  finally
    Context.Free;
  end;
end;

function TInteractiveCLI.ExpandVariables(const Line: string): string;
var
  VarName, VarValue: string;
begin
  Result := Line;
  
  // Expand $varname and ${varname}
  Result := TRegEx.Replace(Result, '\$\{([^}]+)\}',
    TMatchEvaluator(
      function(const Match: TMatch): string
      begin
        VarName := Match.Groups[1].Value;
        Result := GetVariable(VarName, '');
      end
    ));
    
  Result := TRegEx.Replace(Result, '\$([a-zA-Z_][a-zA-Z0-9_]*)',
    TMatchEvaluator(
      function(const Match: TMatch): string
      begin
        VarName := Match.Groups[1].Value;
        Result := GetVariable(VarName, Match.Value);
      end
    ));
end;

function TInteractiveCLI.GetFormatter: IOutputFormatter;
begin
  FFormatters.TryGetValue(FOutputFormat, Result);
  if Result = nil then
    Result := TTextFormatter.Create;
end;

procedure TInteractiveCLI.AddToHistory(const Line: string);
begin
  // Don't add duplicates of the last entry
  if (FHistory.Count > 0) and (FHistory[FHistory.Count - 1] = Line) then
    Exit;
  
  FHistory.Add(Line);
  
  // Trim history if needed
  while FHistory.Count > FMaxHistorySize do
    FHistory.Delete(0);
  
  FHistoryIndex := FHistory.Count;
end;

function TInteractiveCLI.GetHistoryEntry(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FHistory.Count) then
    Result := FHistory[Index]
  else
    Result := '';
end;

procedure TInteractiveCLI.SaveHistory(const FileName: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.AddStrings(FHistory.ToArray);
    Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;
end;

procedure TInteractiveCLI.LoadHistory(const FileName: string);
var
  Lines: TStringList;
begin
  if not FileExists(FileName) then
    Exit;
  
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    FHistory.Clear;
    FHistory.AddRange(Lines.ToStringArray);
    FHistoryIndex := FHistory.Count;
  finally
    Lines.Free;
  end;
end;

procedure TInteractiveCLI.SetVariable(const Name, Value: string);
begin
  FVariables.AddOrSetValue(Name, Value);
end;

function TInteractiveCLI.GetVariable(const Name, Default: string): string;
begin
  if not FVariables.TryGetValue(Name, Result) then
    Result := Default;
end;

procedure TInteractiveCLI.Print(const Text: string);
begin
  Write(Text);
end;

procedure TInteractiveCLI.PrintLn(const Text: string);
begin
  WriteLn(Text);
end;

procedure TInteractiveCLI.PrintError(const Text: string);
begin
  WriteLn(TAnsiColor.Colorize('ERROR: ' + Text, TAnsiColor.Red));
end;

procedure TInteractiveCLI.PrintSuccess(const Text: string);
begin
  WriteLn(TAnsiColor.Colorize(Text, TAnsiColor.Green));
end;

procedure TInteractiveCLI.PrintWarning(const Text: string);
begin
  WriteLn(TAnsiColor.Colorize('WARNING: ' + Text, TAnsiColor.Yellow));
end;

function TInteractiveCLI.ParseLine(const Line: string): TArray<string>;
var
  List: TList<string>;
  Current: string;
  InQuote: Boolean;
  QuoteChar: Char;
  I: Integer;
begin
  List := TList<string>.Create;
  try
    Current := '';
    InQuote := False;
    QuoteChar := #0;
    
    for I := 1 to Length(Line) do
    begin
      if InQuote then
      begin
        if Line[I] = QuoteChar then
          InQuote := False
        else
          Current := Current + Line[I];
      end
      else if (Line[I] = '"') or (Line[I] = '''') then
      begin
        InQuote := True;
        QuoteChar := Line[I];
      end
      else if Line[I] = ' ' then
      begin
        if Current <> '' then
        begin
          List.Add(Current);
          Current := '';
        end;
      end
      else
        Current := Current + Line[I];
    end;
    
    if Current <> '' then
      List.Add(Current);
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TInteractiveCLI.GetCompletions(const Partial: string): TArray<string>;
var
  List: TList<string>;
  Cmd: TCommandDef;
begin
  List := TList<string>.Create;
  try
    // Command name completion
    for Cmd in FCommands.Values do
    begin
      if Cmd.Name.StartsWith(Partial, True) then
        List.Add(Cmd.Name);
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

// ============================================================================
// Built-in Command Handlers
// ============================================================================

function TInteractiveCLI.HandleHelp(Context: TCommandContext): TCommandResult;
var
  CmdName: string;
  Cmd: TCommandDef;
  Columns: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  I: Integer;
begin
  CmdName := Context.GetArg(0);
  
  if CmdName <> '' then
  begin
    // Show help for specific command
    Cmd := GetCommand(CmdName);
    if Cmd = nil then
    begin
      Context.PrintError('Unknown command: ' + CmdName);
      Exit(TCommandResult.Error('Unknown command'));
    end;
    
    Context.Print('Command: ' + Cmd.Name + sLineBreak);
    Context.Print('Description: ' + Cmd.Description + sLineBreak);
    if Cmd.Usage <> '' then
      Context.Print('Usage: ' + Cmd.Usage + sLineBreak);
    if Cmd.Aliases.Count > 0 then
      Context.Print('Aliases: ' + string.Join(', ', Cmd.Aliases.ToArray) + sLineBreak);
    if Cmd.Options.Count > 0 then
    begin
      Context.Print(sLineBreak + 'Options:' + sLineBreak);
      for var Opt in Cmd.Options do
        Context.Print('  --' + Opt.Key + ': ' + Opt.Value + sLineBreak);
    end;
  end
  else
  begin
    // Show all commands
    Context.Print('Available commands:' + sLineBreak + sLineBreak);
    
    SetLength(Columns, 2);
    Columns[0] := TTableColumn.Create('Command', 15);
    Columns[1] := TTableColumn.Create('Description', 50);
    
    SetLength(Rows, FCommands.Count);
    I := 0;
    for Cmd in FCommands.Values do
    begin
      SetLength(Rows[I], 2);
      Rows[I][0] := Cmd.Name;
      Rows[I][1] := Cmd.Description;
      Inc(I);
    end;
    
    Context.PrintTable(Columns, Rows);
    Context.Print(sLineBreak + 'Type "help <command>" for more information.' + sLineBreak);
  end;
  
  Result := TCommandResult.OK;
end;

function TInteractiveCLI.HandleExit(Context: TCommandContext): TCommandResult;
begin
  Stop;
  Result := TCommandResult.OK('Goodbye!');
end;

function TInteractiveCLI.HandleHistory(Context: TCommandContext): TCommandResult;
var
  Count, I: Integer;
begin
  if Context.HasFlag('clear') then
  begin
    FHistory.Clear;
    FHistoryIndex := 0;
    Context.PrintSuccess('History cleared');
    Exit(TCommandResult.OK);
  end;
  
  Count := StrToIntDef(Context.GetOption('n', '20'), 20);
  Count := Min(Count, FHistory.Count);
  
  for I := FHistory.Count - Count to FHistory.Count - 1 do
    Context.Print(Format('%4d  %s' + sLineBreak, [I + 1, FHistory[I]]));
  
  Result := TCommandResult.OK;
end;

function TInteractiveCLI.HandleClear(Context: TCommandContext): TCommandResult;
begin
  // ANSI clear screen
  Write(#27'[2J'#27'[H');
  Result := TCommandResult.OK;
end;

function TInteractiveCLI.HandleSet(Context: TCommandContext): TCommandResult;
var
  Name, Value: string;
begin
  if Context.Args = nil then
  begin
    // Show all variables
    Context.Print('Variables:' + sLineBreak);
    for var V in FVariables do
      Context.Print(Format('  %s = %s' + sLineBreak, [V.Key, V.Value]));
    Exit(TCommandResult.OK);
  end;
  
  Name := Context.GetArg(0);
  Value := Context.GetRemainingArgs(1);
  
  if Name = '' then
  begin
    Context.PrintError('Usage: set <name> <value>');
    Exit(TCommandResult.Error('Invalid syntax'));
  end;
  
  SetVariable(Name, Value);
  Context.PrintSuccess(Format('Set %s = %s', [Name, Value]));
  Result := TCommandResult.OK;
end;

function TInteractiveCLI.HandleFormat(Context: TCommandContext): TCommandResult;
var
  FormatName: string;
begin
  FormatName := LowerCase(Context.GetArg(0));
  
  if FormatName = '' then
  begin
    case FOutputFormat of
      ofText: FormatName := 'text';
      ofJSON: FormatName := 'json';
      ofYAML: FormatName := 'yaml';
      ofTable: FormatName := 'table';
      ofCSV: FormatName := 'csv';
      ofMarkdown: FormatName := 'markdown';
    end;
    Context.Print('Current format: ' + FormatName + sLineBreak);
    Context.Print('Available: text, json, yaml, table, csv, markdown' + sLineBreak);
    Exit(TCommandResult.OK);
  end;
  
  if FormatName = 'text' then
    FOutputFormat := ofText
  else if FormatName = 'json' then
    FOutputFormat := ofJSON
  else if FormatName = 'yaml' then
    FOutputFormat := ofYAML
  else if FormatName = 'table' then
    FOutputFormat := ofTable
  else if FormatName = 'csv' then
    FOutputFormat := ofCSV
  else if FormatName = 'markdown' then
    FOutputFormat := ofMarkdown
  else
  begin
    Context.PrintError('Unknown format: ' + FormatName);
    Exit(TCommandResult.Error('Unknown format'));
  end;
  
  Context.PrintSuccess('Output format set to: ' + FormatName);
  Result := TCommandResult.OK;
end;

end.
