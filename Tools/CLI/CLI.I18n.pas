{ ============================================================================
  CLI.I18n - CLI 国际化命令工具集

  版本: 1.0
  说明: 实现 i18n scan/sync/translate/export/import 命令
  ============================================================================ }

unit CLI.I18n;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  System.RegularExpressions,
  CLI.Commands, System.Types;

type
  TI18nCommands = class
  private
    class procedure ShowHelp;
    class function DoScan: Integer;
    class function DoSync: Integer;
    class function DoTranslate: Integer;
    class function DoExport: Integer;
    class function DoImport: Integer;
    class procedure ScanFile(const FilePath: string; Strings: TDictionary<string, string>);
    class function LoadStringsFromJson(const FilePath: string): TDictionary<string, string>;
    class procedure SaveStringsToJson(const FilePath: string; Strings: TDictionary<string, string>);
  public
    class function Execute: Integer;
  end;

implementation

{ TI18nCommands }

class function TI18nCommands.Execute: Integer;
var
  SubCmd: string;
begin
  SubCmd := TCliUtils.GetSubCommand;
  
  if (SubCmd = '') or (SubCmd = 'help') or TCliUtils.HasOption('help') or TCliUtils.HasOption('h') then
  begin
    ShowHelp;
    Result := 0;
  end
  else if SubCmd = 'scan' then
    Result := DoScan
  else if SubCmd = 'sync' then
    Result := DoSync
  else if SubCmd = 'translate' then
    Result := DoTranslate
  else if SubCmd = 'export' then
    Result := DoExport
  else if SubCmd = 'import' then
    Result := DoImport
  else
  begin
    TCliUtils.Error('Unknown i18n subcommand: %s', [SubCmd]);
    ShowHelp;
    Result := 1;
  end;
end;

class procedure TI18nCommands.ShowHelp;
begin
  Writeln('Internationalization Commands');
  Writeln('');
  Writeln('Usage: DeepBase i18n <subcommand> [options]');
  Writeln('');
  Writeln('Subcommands:');
  Writeln('  scan      Scan source files for translatable strings');
  Writeln('  sync      Sync translations with source strings');
  Writeln('  translate Auto-translate using LLM (requires API key)');
  Writeln('  export    Export translations to JSON/PO file');
  Writeln('  import    Import translations from JSON/PO file');
  Writeln('');
  Writeln('Options for scan:');
  Writeln('  --path, -p <path>     Source directory to scan (required)');
  Writeln('  --output, -o <file>   Output file for found strings (default: strings.json)');
  Writeln('  --pattern <pattern>   File pattern to scan (default: *.pas)');
  Writeln('  --recursive, -r       Scan subdirectories');
  Writeln('');
  Writeln('Options for sync:');
  Writeln('  --source, -s <file>   Source strings file (required)');
  Writeln('  --target, -t <file>   Target translations file (required)');
  Writeln('  --remove-orphans      Remove strings not in source');
  Writeln('');
  Writeln('Options for translate:');
  Writeln('  --input, -i <file>    Input strings file (required)');
  Writeln('  --output, -o <file>   Output translations file (required)');
  Writeln('  --from <lang>         Source language (default: en)');
  Writeln('  --to <lang>           Target language (required)');
  Writeln('  --api-key <key>       LLM API key (or set DeepBase_LLM_KEY env var)');
  Writeln('');
  Writeln('Options for export:');
  Writeln('  --input, -i <file>    Input JSON file (required)');
  Writeln('  --output, -o <file>   Output file (required)');
  Writeln('  --format, -f <fmt>    Output format: json, po (default: json)');
  Writeln('');
  Writeln('Options for import:');
  Writeln('  --input, -i <file>    Input file (required)');
  Writeln('  --output, -o <file>   Output JSON file (required)');
  Writeln('  --format, -f <fmt>    Input format: json, po (default: auto-detect)');
  Writeln('');
  Writeln('Examples:');
  Writeln('  DeepBase i18n scan --path ./src --output strings.json -r');
  Writeln('  DeepBase i18n sync --source strings.json --target zh-CN.json');
  Writeln('  DeepBase i18n translate -i en.json -o zh-CN.json --to zh-CN');
  Writeln('  DeepBase i18n export -i strings.json -o messages.po -f po');
end;

class procedure TI18nCommands.ScanFile(const FilePath: string; Strings: TDictionary<string, string>);
var
  Content: string;
  Matches: TMatchCollection;
  Match: TMatch;
  Key: string;
  Patterns: array[0..3] of string;
  I: Integer;
begin
  Content := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  
  // Patterns to match:
  // T('...') or T("...")
  // TFmt('...', [...]) or TFmt("...", [...])
  // TextKey = '...' or TextKey = "..."
  // resourcestring ... = '...'
  
  Patterns[0] := 'T\s*\(\s*''([^'']+)''\s*\)';           // T('...')
  Patterns[1] := 'T\s*\(\s*"([^"]+)"\s*\)';              // T("...")
  Patterns[2] := 'TFmt\s*\(\s*''([^'']+)''';             // TFmt('...', ...)
  Patterns[3] := 'TFmt\s*\(\s*"([^"]+)"';                // TFmt("...", ...)
  
  for I := 0 to High(Patterns) do
  begin
    Matches := TRegEx.Matches(Content, Patterns[I]);
    for Match in Matches do
    begin
      if Match.Groups.Count >= 2 then
      begin
        Key := Match.Groups[1].Value;
        if not Strings.ContainsKey(Key) then
          Strings.Add(Key, Key); // Default value is the key itself
      end;
    end;
  end;
end;

class function TI18nCommands.LoadStringsFromJson(const FilePath: string): TDictionary<string, string>;
var
  JsonStr: string;
  JsonObj: TJSONObject;
  Pair: TJSONPair;
begin
  Result := TDictionary<string, string>.Create;
  
  if not FileExists(FilePath) then
    Exit;
    
  JsonStr := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  JsonObj := TJSONObject.ParseJSONValue(JsonStr) as TJSONObject;
  
  if Assigned(JsonObj) then
  try
    for Pair in JsonObj do
      Result.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
  finally
    JsonObj.Free;
  end;
end;

class procedure TI18nCommands.SaveStringsToJson(const FilePath: string; Strings: TDictionary<string, string>);
var
  JsonObj: TJSONObject;
  Key: string;
  SortedKeys: TList<string>;
begin
  JsonObj := TJSONObject.Create;
  try
    SortedKeys := TList<string>.Create;
    try
      for Key in Strings.Keys do
        SortedKeys.Add(Key);
      SortedKeys.Sort;
      
      for Key in SortedKeys do
        JsonObj.AddPair(Key, Strings[Key]);
    finally
      SortedKeys.Free;
    end;
    
    TCliUtils.EnsureDirectory(TPath.GetDirectoryName(FilePath));
    TFile.WriteAllText(FilePath, JsonObj.Format(2), TEncoding.UTF8);
  finally
    JsonObj.Free;
  end;
end;

class function TI18nCommands.DoScan: Integer;
var
  ScanPath, OutputFile, Pattern: string;
  Recursive: Boolean;
  Files: TStringDynArray;
  FilePath: string;
  Strings: TDictionary<string, string>;
  SearchOption: TSearchOption;
  I, Total: Integer;
begin
  Result := 0;
  
  ScanPath := TCliUtils.GetOption('path', TCliUtils.GetOption('p'));
  if ScanPath = '' then
  begin
    TCliUtils.Error('Source path is required. Use --path or -p option.');
    Result := 1;
    Exit;
  end;
  
  ScanPath := TCliUtils.ResolvePath(ScanPath);
  
  if not DirectoryExists(ScanPath) then
  begin
    TCliUtils.Error('Directory not found: %s', [ScanPath]);
    Result := 1;
    Exit;
  end;
  
  OutputFile := TCliUtils.GetOption('output', TCliUtils.GetOption('o', 'strings.json'));
  OutputFile := TCliUtils.ResolvePath(OutputFile);
  Pattern := TCliUtils.GetOption('pattern', '*.pas');
  Recursive := TCliUtils.HasOption('recursive') or TCliUtils.HasOption('r');
  
  if Recursive then
    SearchOption := TSearchOption.soAllDirectories
  else
    SearchOption := TSearchOption.soTopDirectoryOnly;
  
  TCliUtils.Info('Scanning: %s', [ScanPath]);
  TCliUtils.Info('Pattern: %s', [Pattern]);
  TCliUtils.Info('Recursive: %s', [BoolToStr(Recursive, True)]);
  
  Strings := TDictionary<string, string>.Create;
  try
    Files := TDirectory.GetFiles(ScanPath, Pattern, SearchOption);
    Total := Length(Files);
    
    TCliUtils.Info('Found %d files to scan.', [Total]);
    
    for I := 0 to High(Files) do
    begin
      FilePath := Files[I];
      TCliUtils.Progress(I + 1, Total, TPath.GetFileName(FilePath));
      ScanFile(FilePath, Strings);
    end;
    
    TCliUtils.Info('Found %d unique strings.', [Strings.Count]);
    
    SaveStringsToJson(OutputFile, Strings);
    TCliUtils.Success('Strings saved to: %s', [OutputFile]);
  finally
    Strings.Free;
  end;
end;

class function TI18nCommands.DoSync: Integer;
var
  SourceFile, TargetFile: string;
  RemoveOrphans: Boolean;
  SourceStrings, TargetStrings: TDictionary<string, string>;
  Key: string;
  AddedCount, RemovedCount, TotalCount: Integer;
  KeysToRemove: TList<string>;
begin
  Result := 0;
  
  SourceFile := TCliUtils.GetOption('source', TCliUtils.GetOption('s'));
  if SourceFile = '' then
  begin
    TCliUtils.Error('Source file is required. Use --source or -s option.');
    Result := 1;
    Exit;
  end;
  
  TargetFile := TCliUtils.GetOption('target', TCliUtils.GetOption('t'));
  if TargetFile = '' then
  begin
    TCliUtils.Error('Target file is required. Use --target or -t option.');
    Result := 1;
    Exit;
  end;
  
  SourceFile := TCliUtils.ResolvePath(SourceFile);
  TargetFile := TCliUtils.ResolvePath(TargetFile);
  RemoveOrphans := TCliUtils.HasOption('remove-orphans');
  
  if not FileExists(SourceFile) then
  begin
    TCliUtils.Error('Source file not found: %s', [SourceFile]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Syncing translations...');
  TCliUtils.Info('Source: %s', [SourceFile]);
  TCliUtils.Info('Target: %s', [TargetFile]);
  
  SourceStrings := LoadStringsFromJson(SourceFile);
  TargetStrings := LoadStringsFromJson(TargetFile);
  try
    AddedCount := 0;
    RemovedCount := 0;
    
    // Add missing keys
    for Key in SourceStrings.Keys do
    begin
      if not TargetStrings.ContainsKey(Key) then
      begin
        TargetStrings.Add(Key, SourceStrings[Key]);
        Inc(AddedCount);
      end;
    end;
    
    // Remove orphans if requested
    if RemoveOrphans then
    begin
      KeysToRemove := TList<string>.Create;
      try
        for Key in TargetStrings.Keys do
        begin
          if not SourceStrings.ContainsKey(Key) then
            KeysToRemove.Add(Key);
        end;
        
        for Key in KeysToRemove do
        begin
          TargetStrings.Remove(Key);
          Inc(RemovedCount);
        end;
      finally
        KeysToRemove.Free;
      end;
    end;
    
    TotalCount := TargetStrings.Count;
    SaveStringsToJson(TargetFile, TargetStrings);
    
    TCliUtils.Info('Added: %d, Removed: %d, Total: %d', [AddedCount, RemovedCount, TotalCount]);
    TCliUtils.Success('Sync completed.');
  finally
    SourceStrings.Free;
    TargetStrings.Free;
  end;
end;

class function TI18nCommands.DoTranslate: Integer;
var
  InputFile, OutputFile, FromLang, ToLang, ApiKey: string;
begin
  Result := 0;
  
  InputFile := TCliUtils.GetOption('input', TCliUtils.GetOption('i'));
  if InputFile = '' then
  begin
    TCliUtils.Error('Input file is required. Use --input or -i option.');
    Result := 1;
    Exit;
  end;
  
  OutputFile := TCliUtils.GetOption('output', TCliUtils.GetOption('o'));
  if OutputFile = '' then
  begin
    TCliUtils.Error('Output file is required. Use --output or -o option.');
    Result := 1;
    Exit;
  end;
  
  ToLang := TCliUtils.GetOption('to');
  if ToLang = '' then
  begin
    TCliUtils.Error('Target language is required. Use --to option.');
    Result := 1;
    Exit;
  end;
  
  FromLang := TCliUtils.GetOption('from', 'en');
  ApiKey := TCliUtils.GetOption('api-key', GetEnvironmentVariable('DeepBase_LLM_KEY'));
  
  if ApiKey = '' then
  begin
    TCliUtils.Error('LLM API key is required. Use --api-key or set DeepBase_LLM_KEY environment variable.');
    Result := 1;
    Exit;
  end;
  
  InputFile := TCliUtils.ResolvePath(InputFile);
  OutputFile := TCliUtils.ResolvePath(OutputFile);
  
  if not FileExists(InputFile) then
  begin
    TCliUtils.Error('Input file not found: %s', [InputFile]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Translation via LLM is not yet implemented in CLI.');
  TCliUtils.Info('Please use DeepBase Studio for LLM-based translation.');
  TCliUtils.Info('');
  TCliUtils.Info('Alternatively, you can:');
  TCliUtils.Info('  1. Export to PO format: DeepBase i18n export -i %s -o messages.po -f po', [InputFile]);
  TCliUtils.Info('  2. Use external translation tools (e.g., Poedit, Crowdin)');
  TCliUtils.Info('  3. Import back: DeepBase i18n import -i translated.po -o %s', [OutputFile]);
  
  Result := 0;
end;

class function TI18nCommands.DoExport: Integer;
var
  InputFile, OutputFile, Format: string;
  Strings: TDictionary<string, string>;
  Key: string;
  Output: TStringList;
begin
  Result := 0;
  
  InputFile := TCliUtils.GetOption('input', TCliUtils.GetOption('i'));
  if InputFile = '' then
  begin
    TCliUtils.Error('Input file is required. Use --input or -i option.');
    Result := 1;
    Exit;
  end;
  
  OutputFile := TCliUtils.GetOption('output', TCliUtils.GetOption('o'));
  if OutputFile = '' then
  begin
    TCliUtils.Error('Output file is required. Use --output or -o option.');
    Result := 1;
    Exit;
  end;
  
  Format := LowerCase(TCliUtils.GetOption('format', TCliUtils.GetOption('f', 'json')));
  
  InputFile := TCliUtils.ResolvePath(InputFile);
  OutputFile := TCliUtils.ResolvePath(OutputFile);
  
  if not FileExists(InputFile) then
  begin
    TCliUtils.Error('Input file not found: %s', [InputFile]);
    Result := 1;
    Exit;
  end;
  
  TCliUtils.Info('Exporting translations...');
  TCliUtils.Info('Input: %s', [InputFile]);
  TCliUtils.Info('Output: %s', [OutputFile]);
  TCliUtils.Info('Format: %s', [Format]);
  
  Strings := LoadStringsFromJson(InputFile);
  try
    if Format = 'json' then
    begin
      SaveStringsToJson(OutputFile, Strings);
    end
    else if Format = 'po' then
    begin
      Output := TStringList.Create;
      try
        Output.Add('# DeepBase Translation File');
        Output.Add('# Generated by DeepBase CLI');
        Output.Add('');
        Output.Add('msgid ""');
        Output.Add('msgstr ""');
        Output.Add('"Content-Type: text/plain; charset=UTF-8\n"');
        Output.Add('"Content-Transfer-Encoding: 8bit\n"');
        Output.Add('');
        
        for Key in Strings.Keys do
        begin
          Output.Add('msgid "' + StringReplace(Key, '"', '\"', [rfReplaceAll]) + '"');
          Output.Add('msgstr "' + StringReplace(Strings[Key], '"', '\"', [rfReplaceAll]) + '"');
          Output.Add('');
        end;
        
        TCliUtils.EnsureDirectory(TPath.GetDirectoryName(OutputFile));
        Output.SaveToFile(OutputFile, TEncoding.UTF8);
      finally
        Output.Free;
      end;
    end
    else
    begin
      TCliUtils.Error('Unknown format: %s. Supported formats: json, po', [Format]);
      Result := 1;
      Exit;
    end;
    
    TCliUtils.Success('Export completed: %d strings.', [Strings.Count]);
  finally
    Strings.Free;
  end;
end;

class function TI18nCommands.DoImport: Integer;
var
  InputFile, OutputFile, Format: string;
  Strings: TDictionary<string, string>;
  Lines: TStringList;
  I: Integer;
  Line, MsgId, MsgStr: string;
  InMsgId, InMsgStr: Boolean;
begin
  Result := 0;
  
  InputFile := TCliUtils.GetOption('input', TCliUtils.GetOption('i'));
  if InputFile = '' then
  begin
    TCliUtils.Error('Input file is required. Use --input or -i option.');
    Result := 1;
    Exit;
  end;
  
  OutputFile := TCliUtils.GetOption('output', TCliUtils.GetOption('o'));
  if OutputFile = '' then
  begin
    TCliUtils.Error('Output file is required. Use --output or -o option.');
    Result := 1;
    Exit;
  end;
  
  InputFile := TCliUtils.ResolvePath(InputFile);
  OutputFile := TCliUtils.ResolvePath(OutputFile);
  
  if not FileExists(InputFile) then
  begin
    TCliUtils.Error('Input file not found: %s', [InputFile]);
    Result := 1;
    Exit;
  end;
  
  // Auto-detect format
  Format := LowerCase(TCliUtils.GetOption('format', TCliUtils.GetOption('f')));
  if Format = '' then
  begin
    if LowerCase(TPath.GetExtension(InputFile)) = '.po' then
      Format := 'po'
    else
      Format := 'json';
  end;
  
  TCliUtils.Info('Importing translations...');
  TCliUtils.Info('Input: %s', [InputFile]);
  TCliUtils.Info('Output: %s', [OutputFile]);
  TCliUtils.Info('Format: %s', [Format]);
  
  Strings := TDictionary<string, string>.Create;
  try
    if Format = 'json' then
    begin
      Strings.Free;
      Strings := LoadStringsFromJson(InputFile);
    end
    else if Format = 'po' then
    begin
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(InputFile, TEncoding.UTF8);
        
        MsgId := '';
        MsgStr := '';
        InMsgId := False;
        InMsgStr := False;
        
        for I := 0 to Lines.Count - 1 do
        begin
          Line := Trim(Lines[I]);
          
          if Line.StartsWith('msgid ') then
          begin
            // Save previous entry
            if (MsgId <> '') then
              Strings.AddOrSetValue(MsgId, MsgStr);
              
            MsgId := Copy(Line, 8, Length(Line) - 8); // Remove 'msgid "' and trailing '"'
            MsgId := StringReplace(MsgId, '\"', '"', [rfReplaceAll]);
            MsgStr := '';
            InMsgId := True;
            InMsgStr := False;
          end
          else if Line.StartsWith('msgstr ') then
          begin
            MsgStr := Copy(Line, 9, Length(Line) - 9); // Remove 'msgstr "' and trailing '"'
            MsgStr := StringReplace(MsgStr, '\"', '"', [rfReplaceAll]);
            InMsgId := False;
            InMsgStr := True;
          end
          else if Line.StartsWith('"') and Line.EndsWith('"') then
          begin
            // Continuation line
            Line := Copy(Line, 2, Length(Line) - 2);
            Line := StringReplace(Line, '\"', '"', [rfReplaceAll]);
            if InMsgId then
              MsgId := MsgId + Line
            else if InMsgStr then
              MsgStr := MsgStr + Line;
          end;
        end;
        
        // Save last entry
        if (MsgId <> '') then
          Strings.AddOrSetValue(MsgId, MsgStr);
          
        // Remove header entry
        Strings.Remove('');
      finally
        Lines.Free;
      end;
    end
    else
    begin
      TCliUtils.Error('Unknown format: %s. Supported formats: json, po', [Format]);
      Result := 1;
      Exit;
    end;
    
    SaveStringsToJson(OutputFile, Strings);
    TCliUtils.Success('Import completed: %d strings.', [Strings.Count]);
  finally
    Strings.Free;
  end;
end;

end.
