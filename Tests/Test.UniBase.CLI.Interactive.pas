{ ============================================================================
  Test.UniBase.CLI.Interactive - Unit Tests for Interactive CLI Module
  
  Test Coverage:
    - TTableColumn record creation and defaults
    - TCommandResult factory methods
    - TCommandDef configuration (aliases, options, subcommands)
    - TCommandContext parsing and argument handling
    - TInteractiveCLI command registration and execution
    - Output formatters (Text, JSON, YAML, Table, CSV)
    - TAnsiColor color codes and utilities
    - History management
    - Variable expansion
  ============================================================================ }

unit Test.UniBase.CLI.Interactive;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  UniBase.CLI.Interactive;

type
  [TestFixture]
  TTestTableColumn = class
  public
    [Test]
    procedure Test_Create_WithDefaults;
    [Test]
    procedure Test_Create_WithWidth;
    [Test]
    procedure Test_Create_WithAlignment;
    [Test]
    procedure Test_Create_FullParams;
  end;

  [TestFixture]
  TTestCommandResult = class
  public
    [Test]
    procedure Test_OK_Empty;
    [Test]
    procedure Test_OK_WithMessage;
    [Test]
    procedure Test_Error_Default;
    [Test]
    procedure Test_Error_CustomCode;
    [Test]
    procedure Test_WithData_JSONObject;
    [Test]
    procedure Test_WithData_JSONArray;
  end;

  [TestFixture]
  TTestCommandDef = class
  private
    FCmd: TCommandDef;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Name;
    [Test]
    procedure Test_AddAlias_Single;
    [Test]
    procedure Test_AddAlias_Multiple;
    [Test]
    procedure Test_AddAlias_Duplicate;
    [Test]
    procedure Test_AddOption;
    [Test]
    procedure Test_AddSubcommand;
    [Test]
    procedure Test_SetCompletion;
    [Test]
    procedure Test_Description;
    [Test]
    procedure Test_Usage;
    [Test]
    procedure Test_FluentInterface;
  end;

  [TestFixture]
  TTestCommandContext = class
  private
    FCLI: TInteractiveCLI;
    FContext: TCommandContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Parse_SimpleCommand;
    [Test]
    procedure Test_Parse_CommandWithArgs;
    [Test]
    procedure Test_Parse_CommandWithOptions;
    [Test]
    procedure Test_Parse_CommandWithFlags;
    [Test]
    procedure Test_Parse_MixedArgsOptionsFlags;
    [Test]
    procedure Test_Parse_QuotedArgs;
    [Test]
    procedure Test_GetArg_Valid;
    [Test]
    procedure Test_GetArg_OutOfRange;
    [Test]
    procedure Test_GetArg_Default;
    [Test]
    procedure Test_GetOption_Exists;
    [Test]
    procedure Test_GetOption_NotExists;
    [Test]
    procedure Test_HasFlag_True;
    [Test]
    procedure Test_HasFlag_False;
    [Test]
    procedure Test_HasOption_True;
    [Test]
    procedure Test_HasOption_False;
    [Test]
    procedure Test_GetRemainingArgs;
  end;

  [TestFixture]
  TTestInteractiveCLI = class
  private
    FCLI: TInteractiveCLI;
    FHandlerCalled: Boolean;
    FLastArgs: TArray<string>;
    
    function TestHandler(Context: TCommandContext): TCommandResult;
    function ErrorHandler(Context: TCommandContext): TCommandResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_RegisterCommand;
    [Test]
    procedure Test_RegisterCommand_WithAlias;
    [Test]
    procedure Test_UnregisterCommand;
    [Test]
    procedure Test_GetCommand_ByName;
    [Test]
    procedure Test_GetCommand_ByAlias;
    [Test]
    procedure Test_GetCommand_NotFound;
    [Test]
    procedure Test_CommandExists_True;
    [Test]
    procedure Test_CommandExists_False;
    [Test]
    procedure Test_Execute_Success;
    [Test]
    procedure Test_Execute_Error;
    [Test]
    procedure Test_Execute_UnknownCommand;
    [Test]
    procedure Test_Execute_EmptyLine;
    [Test]
    procedure Test_BuiltinHelp;
    [Test]
    procedure Test_BuiltinHistory;
    [Test]
    procedure Test_BuiltinSet;
    [Test]
    procedure Test_BuiltinFormat;
    [Test]
    procedure Test_History_Add;
    [Test]
    procedure Test_History_MaxSize;
    [Test]
    procedure Test_Variables_SetGet;
    [Test]
    procedure Test_Variables_Expand;
    [Test]
    procedure Test_OutputFormat_Change;
  end;

  [TestFixture]
  TTestTextFormatter = class
  private
    FFormatter: IOutputFormatter;
  public
    [Setup]
    procedure Setup;
    
    [Test]
    procedure Test_FormatTable_Simple;
    [Test]
    procedure Test_FormatTable_Empty;
    [Test]
    procedure Test_FormatKeyValue;
    [Test]
    procedure Test_FormatList;
    [Test]
    procedure Test_FormatJSON;
  end;

  [TestFixture]
  TTestJSONFormatter = class
  private
    FFormatter: IOutputFormatter;
  public
    [Setup]
    procedure Setup;
    
    [Test]
    procedure Test_FormatTable_AsJSONArray;
    [Test]
    procedure Test_FormatKeyValue_AsJSONObject;
    [Test]
    procedure Test_FormatList_AsJSONArray;
  end;

  [TestFixture]
  TTestCSVFormatter = class
  private
    FFormatter: IOutputFormatter;
  public
    [Setup]
    procedure Setup;
    
    [Test]
    procedure Test_FormatTable_DefaultDelimiter;
    [Test]
    procedure Test_FormatTable_CustomDelimiter;
    [Test]
    procedure Test_FormatTable_WithQuotes;
  end;

  [TestFixture]
  TTestAnsiColor = class
  public
    [Test]
    procedure Test_Colorize_Red;
    [Test]
    procedure Test_Colorize_Green;
    [Test]
    procedure Test_Colorize_Bold;
    [Test]
    procedure Test_StripColors_SingleColor;
    [Test]
    procedure Test_StripColors_MultipleColors;
    [Test]
    procedure Test_StripColors_NoColors;
    [Test]
    procedure Test_ColorConstants;
  end;

implementation

{ TTestTableColumn }

procedure TTestTableColumn.Test_Create_WithDefaults;
var
  Col: TTableColumn;
begin
  Col := TTableColumn.Create('Name');
  Assert.AreEqual('Name', Col.Name);
  Assert.AreEqual(0, Col.Width);
  Assert.AreEqual(taLeftJustify, Col.Alignment);
end;

procedure TTestTableColumn.Test_Create_WithWidth;
var
  Col: TTableColumn;
begin
  Col := TTableColumn.Create('ID', 10);
  Assert.AreEqual('ID', Col.Name);
  Assert.AreEqual(10, Col.Width);
  Assert.AreEqual(taLeftJustify, Col.Alignment);
end;

procedure TTestTableColumn.Test_Create_WithAlignment;
var
  Col: TTableColumn;
begin
  Col := TTableColumn.Create('Amount', 15, taRightJustify);
  Assert.AreEqual('Amount', Col.Name);
  Assert.AreEqual(15, Col.Width);
  Assert.AreEqual(taRightJustify, Col.Alignment);
end;

procedure TTestTableColumn.Test_Create_FullParams;
var
  Col: TTableColumn;
begin
  Col := TTableColumn.Create('Status', 20, taCenter);
  Assert.AreEqual('Status', Col.Name);
  Assert.AreEqual(20, Col.Width);
  Assert.AreEqual(taCenter, Col.Alignment);
end;

{ TTestCommandResult }

procedure TTestCommandResult.Test_OK_Empty;
var
  R: TCommandResult;
begin
  R := TCommandResult.OK;
  Assert.IsTrue(R.Success);
  Assert.AreEqual('', R.Message);
  Assert.AreEqual(0, R.ExitCode);
  Assert.IsNull(R.Data);
end;

procedure TTestCommandResult.Test_OK_WithMessage;
var
  R: TCommandResult;
begin
  R := TCommandResult.OK('Operation completed');
  Assert.IsTrue(R.Success);
  Assert.AreEqual('Operation completed', R.Message);
  Assert.AreEqual(0, R.ExitCode);
end;

procedure TTestCommandResult.Test_Error_Default;
var
  R: TCommandResult;
begin
  R := TCommandResult.Error('Something went wrong');
  Assert.IsFalse(R.Success);
  Assert.AreEqual('Something went wrong', R.Message);
  Assert.AreEqual(1, R.ExitCode);
end;

procedure TTestCommandResult.Test_Error_CustomCode;
var
  R: TCommandResult;
begin
  R := TCommandResult.Error('File not found', 404);
  Assert.IsFalse(R.Success);
  Assert.AreEqual('File not found', R.Message);
  Assert.AreEqual(404, R.ExitCode);
end;

procedure TTestCommandResult.Test_WithData_JSONObject;
var
  R: TCommandResult;
  Obj: TJSONObject;
begin
  Obj := TJSONObject.Create;
  Obj.AddPair('key', 'value');
  R := TCommandResult.WithData(Obj);
  Assert.IsTrue(R.Success);
  Assert.IsNotNull(R.Data);
  Assert.AreEqual(0, R.ExitCode);
  Obj.Free;
end;

procedure TTestCommandResult.Test_WithData_JSONArray;
var
  R: TCommandResult;
  Arr: TJSONArray;
begin
  Arr := TJSONArray.Create;
  Arr.Add('item1');
  Arr.Add('item2');
  R := TCommandResult.WithData(Arr);
  Assert.IsTrue(R.Success);
  Assert.IsNotNull(R.Data);
  Arr.Free;
end;

{ TTestCommandDef }

procedure TTestCommandDef.Setup;
begin
  FCmd := TCommandDef.Create('test');
end;

procedure TTestCommandDef.TearDown;
begin
  FCmd.Free;
end;

procedure TTestCommandDef.Test_Create_Name;
begin
  Assert.AreEqual('test', FCmd.Name);
  Assert.AreEqual('', FCmd.Description);
  Assert.AreEqual('', FCmd.Usage);
  Assert.IsNotNull(FCmd.Aliases);
  Assert.AreEqual(0, FCmd.Aliases.Count);
end;

procedure TTestCommandDef.Test_AddAlias_Single;
begin
  FCmd.AddAlias('t');
  Assert.AreEqual(1, FCmd.Aliases.Count);
  Assert.AreEqual('t', FCmd.Aliases[0]);
end;

procedure TTestCommandDef.Test_AddAlias_Multiple;
begin
  FCmd.AddAlias('t').AddAlias('tst');
  Assert.AreEqual(2, FCmd.Aliases.Count);
  Assert.IsTrue(FCmd.Aliases.Contains('t'));
  Assert.IsTrue(FCmd.Aliases.Contains('tst'));
end;

procedure TTestCommandDef.Test_AddAlias_Duplicate;
begin
  FCmd.AddAlias('t').AddAlias('t');
  Assert.AreEqual(1, FCmd.Aliases.Count);
end;

procedure TTestCommandDef.Test_AddOption;
begin
  FCmd.AddOption('--verbose', 'Enable verbose output');
  Assert.IsTrue(FCmd.Options.ContainsKey('--verbose'));
  Assert.AreEqual('Enable verbose output', FCmd.Options['--verbose']);
end;

procedure TTestCommandDef.Test_AddSubcommand;
var
  Sub: TCommandDef;
begin
  Sub := FCmd.AddSubcommand('run', 'Run the test', nil);
  Assert.IsNotNull(Sub);
  Assert.AreEqual('run', Sub.Name);
  Assert.AreEqual('Run the test', Sub.Description);
  Assert.IsTrue(FCmd.Subcommands.ContainsKey('run'));
end;

procedure TTestCommandDef.Test_SetCompletion;
var
  Provider: TCompletionProvider;
begin
  Provider := function(const Partial: string; ArgIndex: Integer): TArray<string>
  begin
    Result := ['option1', 'option2'];
  end;
  FCmd.SetCompletion(Provider);
  Assert.IsTrue(Assigned(FCmd.CompletionProvider));
end;

procedure TTestCommandDef.Test_Description;
begin
  FCmd.Description := 'Test command description';
  Assert.AreEqual('Test command description', FCmd.Description);
end;

procedure TTestCommandDef.Test_Usage;
begin
  FCmd.Usage := 'test [options] <file>';
  Assert.AreEqual('test [options] <file>', FCmd.Usage);
end;

procedure TTestCommandDef.Test_FluentInterface;
begin
  FCmd.AddAlias('t')
      .AddOption('-v', 'Verbose')
      .AddOption('-q', 'Quiet');
  Assert.AreEqual(1, FCmd.Aliases.Count);
  Assert.AreEqual(2, FCmd.Options.Count);
end;

{ TTestCommandContext }

procedure TTestCommandContext.Setup;
begin
  FCLI := TInteractiveCLI.Create;
  FContext := TCommandContext.Create(FCLI);
end;

procedure TTestCommandContext.TearDown;
begin
  FContext.Free;
  FCLI.Free;
end;

procedure TTestCommandContext.Test_Parse_SimpleCommand;
begin
  FContext.Parse('help');
  Assert.AreEqual('help', FContext.Command);
  Assert.AreEqual(0, Length(FContext.Args));
end;

procedure TTestCommandContext.Test_Parse_CommandWithArgs;
begin
  FContext.Parse('config set key value');
  Assert.AreEqual('config', FContext.Command);
  Assert.AreEqual(3, Length(FContext.Args));
  Assert.AreEqual('set', FContext.Args[0]);
  Assert.AreEqual('key', FContext.Args[1]);
  Assert.AreEqual('value', FContext.Args[2]);
end;

procedure TTestCommandContext.Test_Parse_CommandWithOptions;
begin
  FContext.Parse('query --database=mydb --limit=10');
  Assert.AreEqual('query', FContext.Command);
  Assert.IsTrue(FContext.HasOption('database'));
  Assert.IsTrue(FContext.HasOption('limit'));
  Assert.AreEqual('mydb', FContext.GetOption('database'));
  Assert.AreEqual('10', FContext.GetOption('limit'));
end;

procedure TTestCommandContext.Test_Parse_CommandWithFlags;
begin
  FContext.Parse('list -v -a --recursive');
  Assert.AreEqual('list', FContext.Command);
  Assert.IsTrue(FContext.HasFlag('v'));
  Assert.IsTrue(FContext.HasFlag('a'));
  Assert.IsTrue(FContext.HasFlag('recursive'));
end;

procedure TTestCommandContext.Test_Parse_MixedArgsOptionsFlags;
begin
  FContext.Parse('copy src dest --force -v --mode=fast');
  Assert.AreEqual('copy', FContext.Command);
  Assert.AreEqual('src', FContext.GetArg(0));
  Assert.AreEqual('dest', FContext.GetArg(1));
  Assert.IsTrue(FContext.HasFlag('force'));
  Assert.IsTrue(FContext.HasFlag('v'));
  Assert.AreEqual('fast', FContext.GetOption('mode'));
end;

procedure TTestCommandContext.Test_Parse_QuotedArgs;
begin
  FContext.Parse('echo "hello world" ''single quotes''');
  Assert.AreEqual('echo', FContext.Command);
  Assert.AreEqual(2, Length(FContext.Args));
  Assert.AreEqual('hello world', FContext.Args[0]);
  Assert.AreEqual('single quotes', FContext.Args[1]);
end;

procedure TTestCommandContext.Test_GetArg_Valid;
begin
  FContext.Parse('cmd arg1 arg2 arg3');
  Assert.AreEqual('arg1', FContext.GetArg(0));
  Assert.AreEqual('arg2', FContext.GetArg(1));
  Assert.AreEqual('arg3', FContext.GetArg(2));
end;

procedure TTestCommandContext.Test_GetArg_OutOfRange;
begin
  FContext.Parse('cmd arg1');
  Assert.AreEqual('', FContext.GetArg(5));
end;

procedure TTestCommandContext.Test_GetArg_Default;
begin
  FContext.Parse('cmd');
  Assert.AreEqual('default', FContext.GetArg(0, 'default'));
end;

procedure TTestCommandContext.Test_GetOption_Exists;
begin
  FContext.Parse('cmd --name=test');
  Assert.AreEqual('test', FContext.GetOption('name'));
end;

procedure TTestCommandContext.Test_GetOption_NotExists;
begin
  FContext.Parse('cmd');
  Assert.AreEqual('fallback', FContext.GetOption('name', 'fallback'));
end;

procedure TTestCommandContext.Test_HasFlag_True;
begin
  FContext.Parse('cmd -v --debug');
  Assert.IsTrue(FContext.HasFlag('v'));
  Assert.IsTrue(FContext.HasFlag('debug'));
end;

procedure TTestCommandContext.Test_HasFlag_False;
begin
  FContext.Parse('cmd -v');
  Assert.IsFalse(FContext.HasFlag('q'));
  Assert.IsFalse(FContext.HasFlag('verbose'));
end;

procedure TTestCommandContext.Test_HasOption_True;
begin
  FContext.Parse('cmd --output=file.txt');
  Assert.IsTrue(FContext.HasOption('output'));
end;

procedure TTestCommandContext.Test_HasOption_False;
begin
  FContext.Parse('cmd arg1');
  Assert.IsFalse(FContext.HasOption('output'));
end;

procedure TTestCommandContext.Test_GetRemainingArgs;
begin
  FContext.Parse('cmd arg1 arg2 arg3 arg4');
  Assert.AreEqual('arg2 arg3 arg4', FContext.GetRemainingArgs(1));
end;

{ TTestInteractiveCLI }

function TTestInteractiveCLI.TestHandler(Context: TCommandContext): TCommandResult;
begin
  FHandlerCalled := True;
  FLastArgs := Context.Args;
  Result := TCommandResult.OK('Test executed');
end;

function TTestInteractiveCLI.ErrorHandler(Context: TCommandContext): TCommandResult;
begin
  Result := TCommandResult.Error('Test error', 42);
end;

procedure TTestInteractiveCLI.Setup;
begin
  FCLI := TInteractiveCLI.Create;
  FHandlerCalled := False;
  SetLength(FLastArgs, 0);
end;

procedure TTestInteractiveCLI.TearDown;
begin
  FCLI.Free;
end;

procedure TTestInteractiveCLI.Test_Create_Defaults;
begin
  Assert.AreEqual('> ', FCLI.Prompt);
  Assert.IsFalse(FCLI.Running);
  Assert.AreEqual(ofText, FCLI.OutputFormat);
  Assert.AreEqual(1000, FCLI.MaxHistorySize);
end;

procedure TTestInteractiveCLI.Test_RegisterCommand;
var
  Cmd: TCommandDef;
begin
  Cmd := FCLI.RegisterCommand('mytest', 'My test command', TestHandler);
  Assert.IsNotNull(Cmd);
  Assert.AreEqual('mytest', Cmd.Name);
  Assert.AreEqual('My test command', Cmd.Description);
  Assert.IsTrue(FCLI.CommandExists('mytest'));
end;

procedure TTestInteractiveCLI.Test_RegisterCommand_WithAlias;
var
  Cmd: TCommandDef;
begin
  Cmd := FCLI.RegisterCommand('mytest', 'Test', TestHandler);
  Cmd.AddAlias('mt');
  Assert.IsTrue(FCLI.CommandExists('mytest'));
  Assert.IsTrue(FCLI.CommandExists('mt'));
end;

procedure TTestInteractiveCLI.Test_UnregisterCommand;
begin
  FCLI.RegisterCommand('temp', 'Temporary', TestHandler);
  Assert.IsTrue(FCLI.CommandExists('temp'));
  FCLI.UnregisterCommand('temp');
  Assert.IsFalse(FCLI.CommandExists('temp'));
end;

procedure TTestInteractiveCLI.Test_GetCommand_ByName;
var
  Cmd: TCommandDef;
begin
  FCLI.RegisterCommand('mytest', 'Test', TestHandler);
  Cmd := FCLI.GetCommand('mytest');
  Assert.IsNotNull(Cmd);
  Assert.AreEqual('mytest', Cmd.Name);
end;

procedure TTestInteractiveCLI.Test_GetCommand_ByAlias;
var
  Cmd: TCommandDef;
begin
  FCLI.RegisterCommand('mytest', 'Test', TestHandler).AddAlias('mt');
  Cmd := FCLI.GetCommand('mt');
  Assert.IsNotNull(Cmd);
  Assert.AreEqual('mytest', Cmd.Name);
end;

procedure TTestInteractiveCLI.Test_GetCommand_NotFound;
var
  Cmd: TCommandDef;
begin
  Cmd := FCLI.GetCommand('nonexistent');
  Assert.IsNull(Cmd);
end;

procedure TTestInteractiveCLI.Test_CommandExists_True;
begin
  FCLI.RegisterCommand('exists', 'Test', TestHandler);
  Assert.IsTrue(FCLI.CommandExists('exists'));
end;

procedure TTestInteractiveCLI.Test_CommandExists_False;
begin
  Assert.IsFalse(FCLI.CommandExists('nonexistent'));
end;

procedure TTestInteractiveCLI.Test_Execute_Success;
var
  R: TCommandResult;
begin
  FCLI.RegisterCommand('test', 'Test', TestHandler);
  R := FCLI.Execute('test arg1 arg2');
  Assert.IsTrue(R.Success);
  Assert.IsTrue(FHandlerCalled);
  Assert.AreEqual(2, Length(FLastArgs));
end;

procedure TTestInteractiveCLI.Test_Execute_Error;
var
  R: TCommandResult;
begin
  FCLI.RegisterCommand('fail', 'Fail', ErrorHandler);
  R := FCLI.Execute('fail');
  Assert.IsFalse(R.Success);
  Assert.AreEqual(42, R.ExitCode);
end;

procedure TTestInteractiveCLI.Test_Execute_UnknownCommand;
var
  R: TCommandResult;
begin
  R := FCLI.Execute('unknowncmd');
  Assert.IsFalse(R.Success);
end;

procedure TTestInteractiveCLI.Test_Execute_EmptyLine;
var
  R: TCommandResult;
begin
  R := FCLI.Execute('');
  Assert.IsTrue(R.Success);  // Empty line should be OK
end;

procedure TTestInteractiveCLI.Test_BuiltinHelp;
var
  R: TCommandResult;
begin
  R := FCLI.Execute('help');
  Assert.IsTrue(R.Success);
end;

procedure TTestInteractiveCLI.Test_BuiltinHistory;
var
  R: TCommandResult;
begin
  FCLI.AddToHistory('command1');
  FCLI.AddToHistory('command2');
  R := FCLI.Execute('history');
  Assert.IsTrue(R.Success);
end;

procedure TTestInteractiveCLI.Test_BuiltinSet;
var
  R: TCommandResult;
begin
  R := FCLI.Execute('set myvar=myvalue');
  Assert.IsTrue(R.Success);
  Assert.AreEqual('myvalue', FCLI.GetVariable('myvar', ''));
end;

procedure TTestInteractiveCLI.Test_BuiltinFormat;
var
  R: TCommandResult;
begin
  R := FCLI.Execute('format json');
  Assert.IsTrue(R.Success);
  Assert.AreEqual(ofJSON, FCLI.OutputFormat);
end;

procedure TTestInteractiveCLI.Test_History_Add;
begin
  FCLI.AddToHistory('cmd1');
  FCLI.AddToHistory('cmd2');
  Assert.AreEqual(2, FCLI.History.Count);
  Assert.AreEqual('cmd1', FCLI.GetHistoryEntry(0));
  Assert.AreEqual('cmd2', FCLI.GetHistoryEntry(1));
end;

procedure TTestInteractiveCLI.Test_History_MaxSize;
var
  I: Integer;
begin
  FCLI.MaxHistorySize := 5;
  for I := 1 to 10 do
    FCLI.AddToHistory('cmd' + IntToStr(I));
  Assert.AreEqual(5, FCLI.History.Count);
  Assert.AreEqual('cmd6', FCLI.GetHistoryEntry(0));
end;

procedure TTestInteractiveCLI.Test_Variables_SetGet;
begin
  FCLI.SetVariable('name', 'test');
  Assert.AreEqual('test', FCLI.GetVariable('name', ''));
  Assert.AreEqual('default', FCLI.GetVariable('unknown', 'default'));
end;

procedure TTestInteractiveCLI.Test_Variables_Expand;
begin
  FCLI.SetVariable('db', 'mydb');
  FCLI.RegisterCommand('use', 'Use DB', 
    function(Ctx: TCommandContext): TCommandResult
    begin
      FLastArgs := Ctx.Args;
      Result := TCommandResult.OK;
    end);
  FCLI.Execute('use $db');
  // Variable expansion should replace $db with mydb
  Assert.AreEqual(1, Length(FLastArgs));
end;

procedure TTestInteractiveCLI.Test_OutputFormat_Change;
begin
  FCLI.OutputFormat := ofJSON;
  Assert.AreEqual(ofJSON, FCLI.OutputFormat);
  
  FCLI.OutputFormat := ofTable;
  Assert.AreEqual(ofTable, FCLI.OutputFormat);
end;

{ TTestTextFormatter }

procedure TTestTextFormatter.Setup;
begin
  FFormatter := TTextFormatter.Create;
end;

procedure TTestTextFormatter.Test_FormatTable_Simple;
var
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Cols := [TTableColumn.Create('Name'), TTableColumn.Create('Value')];
  SetLength(Rows, 2);
  Rows[0] := ['key1', 'val1'];
  Rows[1] := ['key2', 'val2'];
  
  Output := FFormatter.FormatTable(Cols, Rows);
  Assert.IsTrue(Output.Contains('Name'));
  Assert.IsTrue(Output.Contains('Value'));
  Assert.IsTrue(Output.Contains('key1'));
  Assert.IsTrue(Output.Contains('val2'));
end;

procedure TTestTextFormatter.Test_FormatTable_Empty;
var
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Cols := [TTableColumn.Create('Col1')];
  SetLength(Rows, 0);
  
  Output := FFormatter.FormatTable(Cols, Rows);
  Assert.IsTrue(Output.Contains('Col1'));
end;

procedure TTestTextFormatter.Test_FormatKeyValue;
var
  Pairs: TArray<TPair<string, string>>;
  Output: string;
begin
  SetLength(Pairs, 2);
  Pairs[0] := TPair<string, string>.Create('Name', 'Test');
  Pairs[1] := TPair<string, string>.Create('Version', '1.0');
  
  Output := FFormatter.FormatKeyValue(Pairs);
  Assert.IsTrue(Output.Contains('Name'));
  Assert.IsTrue(Output.Contains('Test'));
  Assert.IsTrue(Output.Contains('Version'));
end;

procedure TTestTextFormatter.Test_FormatList;
var
  Items: TArray<string>;
  Output: string;
begin
  Items := ['item1', 'item2', 'item3'];
  Output := FFormatter.FormatList(Items);
  Assert.IsTrue(Output.Contains('item1'));
  Assert.IsTrue(Output.Contains('item2'));
  Assert.IsTrue(Output.Contains('item3'));
end;

procedure TTestTextFormatter.Test_FormatJSON;
var
  Obj: TJSONObject;
  Output: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('key', 'value');
    Output := FFormatter.FormatJSON(Obj);
    Assert.IsTrue(Output.Contains('key'));
    Assert.IsTrue(Output.Contains('value'));
  finally
    Obj.Free;
  end;
end;

{ TTestJSONFormatter }

procedure TTestJSONFormatter.Setup;
begin
  FFormatter := TJSONFormatter.Create;
end;

procedure TTestJSONFormatter.Test_FormatTable_AsJSONArray;
var
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Cols := [TTableColumn.Create('id'), TTableColumn.Create('name')];
  SetLength(Rows, 1);
  Rows[0] := ['1', 'test'];
  
  Output := FFormatter.FormatTable(Cols, Rows);
  Assert.IsTrue(Output.StartsWith('['));
  Assert.IsTrue(Output.Contains('"id"'));
  Assert.IsTrue(Output.Contains('"name"'));
end;

procedure TTestJSONFormatter.Test_FormatKeyValue_AsJSONObject;
var
  Pairs: TArray<TPair<string, string>>;
  Output: string;
begin
  SetLength(Pairs, 1);
  Pairs[0] := TPair<string, string>.Create('key', 'value');
  
  Output := FFormatter.FormatKeyValue(Pairs);
  Assert.IsTrue(Output.StartsWith('{'));
  Assert.IsTrue(Output.Contains('"key"'));
end;

procedure TTestJSONFormatter.Test_FormatList_AsJSONArray;
var
  Items: TArray<string>;
  Output: string;
begin
  Items := ['a', 'b', 'c'];
  Output := FFormatter.FormatList(Items);
  Assert.IsTrue(Output.StartsWith('['));
  Assert.IsTrue(Output.Contains('"a"'));
end;

{ TTestCSVFormatter }

procedure TTestCSVFormatter.Setup;
begin
  FFormatter := TCSVFormatter.Create;
end;

procedure TTestCSVFormatter.Test_FormatTable_DefaultDelimiter;
var
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Cols := [TTableColumn.Create('A'), TTableColumn.Create('B')];
  SetLength(Rows, 1);
  Rows[0] := ['1', '2'];
  
  Output := FFormatter.FormatTable(Cols, Rows);
  Assert.IsTrue(Output.Contains('A,B'));
  Assert.IsTrue(Output.Contains('1,2'));
end;

procedure TTestCSVFormatter.Test_FormatTable_CustomDelimiter;
var
  Formatter: TCSVFormatter;
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Formatter := TCSVFormatter.Create(';');
  try
    Cols := [TTableColumn.Create('A'), TTableColumn.Create('B')];
    SetLength(Rows, 1);
    Rows[0] := ['1', '2'];
    
    Output := Formatter.FormatTable(Cols, Rows);
    Assert.IsTrue(Output.Contains('A;B'));
  finally
    // Interface reference, auto-freed
  end;
end;

procedure TTestCSVFormatter.Test_FormatTable_WithQuotes;
var
  Cols: TArray<TTableColumn>;
  Rows: TArray<TArray<string>>;
  Output: string;
begin
  Cols := [TTableColumn.Create('Text')];
  SetLength(Rows, 1);
  Rows[0] := ['Hello, World'];  // Contains comma
  
  Output := FFormatter.FormatTable(Cols, Rows);
  Assert.IsTrue(Output.Contains('"Hello, World"'));
end;

{ TTestAnsiColor }

procedure TTestAnsiColor.Test_Colorize_Red;
var
  S: string;
begin
  S := TAnsiColor.Colorize('Error', TAnsiColor.Red);
  Assert.IsTrue(S.Contains(TAnsiColor.Red));
  Assert.IsTrue(S.Contains('Error'));
  Assert.IsTrue(S.Contains(TAnsiColor.Reset));
end;

procedure TTestAnsiColor.Test_Colorize_Green;
var
  S: string;
begin
  S := TAnsiColor.Colorize('Success', TAnsiColor.Green);
  Assert.IsTrue(S.Contains(TAnsiColor.Green));
  Assert.IsTrue(S.Contains(TAnsiColor.Reset));
end;

procedure TTestAnsiColor.Test_Colorize_Bold;
var
  S: string;
begin
  S := TAnsiColor.Colorize('Important', TAnsiColor.Bold);
  Assert.IsTrue(S.Contains(TAnsiColor.Bold));
end;

procedure TTestAnsiColor.Test_StripColors_SingleColor;
var
  S: string;
begin
  S := TAnsiColor.Colorize('Text', TAnsiColor.Red);
  S := TAnsiColor.StripColors(S);
  Assert.AreEqual('Text', S);
end;

procedure TTestAnsiColor.Test_StripColors_MultipleColors;
var
  S: string;
begin
  S := TAnsiColor.Red + 'Red' + TAnsiColor.Reset + 
       TAnsiColor.Green + 'Green' + TAnsiColor.Reset;
  S := TAnsiColor.StripColors(S);
  Assert.AreEqual('RedGreen', S);
end;

procedure TTestAnsiColor.Test_StripColors_NoColors;
var
  S: string;
begin
  S := 'Plain text';
  Assert.AreEqual('Plain text', TAnsiColor.StripColors(S));
end;

procedure TTestAnsiColor.Test_ColorConstants;
begin
  Assert.AreEqual(#27'[0m', TAnsiColor.Reset);
  Assert.AreEqual(#27'[31m', TAnsiColor.Red);
  Assert.AreEqual(#27'[32m', TAnsiColor.Green);
  Assert.AreEqual(#27'[33m', TAnsiColor.Yellow);
  Assert.AreEqual(#27'[34m', TAnsiColor.Blue);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestTableColumn);
  TDUnitX.RegisterTestFixture(TTestCommandResult);
  TDUnitX.RegisterTestFixture(TTestCommandDef);
  TDUnitX.RegisterTestFixture(TTestCommandContext);
  TDUnitX.RegisterTestFixture(TTestInteractiveCLI);
  TDUnitX.RegisterTestFixture(TTestTextFormatter);
  TDUnitX.RegisterTestFixture(TTestJSONFormatter);
  TDUnitX.RegisterTestFixture(TTestCSVFormatter);
  TDUnitX.RegisterTestFixture(TTestAnsiColor);

end.
