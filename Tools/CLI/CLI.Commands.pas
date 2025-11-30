{ ============================================================================
  CLI.Commands - 命令行解析和通用工具
  
  版本: 1.0
  说明: 提供命令行参数解析和通用输出工具
  ============================================================================ }

unit CLI.Commands;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TCommandOption = record
    Name: string;
    ShortName: string;
    HasValue: Boolean;
    Description: string;
  end;
  
  TCliUtils = class
  private
    class var FOptions: TDictionary<string, string>;
    class var FArgs: TList<string>;
    class procedure ParseArgs;
  public
    class constructor Create;
    class destructor Destroy;
    
    // 参数解析
    class function GetSubCommand: string;
    class function GetOption(const Name: string; const Default: string = ''): string;
    class function HasOption(const Name: string): Boolean;
    class function GetArg(Index: Integer): string;
    class function ArgCount: Integer;
    
    // 输出工具
    class procedure Info(const Msg: string); overload;
    class procedure Info(const Fmt: string; const Args: array of const); overload;
    class procedure Success(const Msg: string); overload;
    class procedure Success(const Fmt: string; const Args: array of const); overload;
    class procedure Warning(const Msg: string); overload;
    class procedure Warning(const Fmt: string; const Args: array of const); overload;
    class procedure Error(const Msg: string); overload;
    class procedure Error(const Fmt: string; const Args: array of const); overload;
    class procedure Progress(Current, Total: Integer; const Task: string = '');
    
    // 确认
    class function Confirm(const Prompt: string; Default: Boolean = False): Boolean;
    class function Prompt(const Question: string; const Default: string = ''): string;
    
    // 文件工具
    class function ResolvePath(const Path: string): string;
    class function EnsureDirectory(const Path: string): Boolean;
  end;

implementation

{ TCliUtils }

class constructor TCliUtils.Create;
begin
  FOptions := TDictionary<string, string>.Create;
  FArgs := TList<string>.Create;
  ParseArgs;
end;

class destructor TCliUtils.Destroy;
begin
  FreeAndNil(FOptions);
  FreeAndNil(FArgs);
end;

class procedure TCliUtils.ParseArgs;
var
  I: Integer;
  Param, Key, Value: string;
  EqPos: Integer;
begin
  FOptions.Clear;
  FArgs.Clear;
  
  I := 3; // Skip program name, command, subcommand
  while I <= ParamCount do
  begin
    Param := ParamStr(I);
    
    if Param.StartsWith('--') then
    begin
      // Long option: --name=value or --name value or --flag
      Key := Copy(Param, 3, MaxInt);
      EqPos := Pos('=', Key);
      
      if EqPos > 0 then
      begin
        Value := Copy(Key, EqPos + 1, MaxInt);
        Key := Copy(Key, 1, EqPos - 1);
        FOptions.AddOrSetValue(Key, Value);
      end
      else if (I < ParamCount) and not ParamStr(I + 1).StartsWith('-') then
      begin
        Inc(I);
        FOptions.AddOrSetValue(Key, ParamStr(I));
      end
      else
        FOptions.AddOrSetValue(Key, 'true');
    end
    else if Param.StartsWith('-') and (Length(Param) = 2) then
    begin
      // Short option: -n value or -f
      Key := Copy(Param, 2, 1);
      if (I < ParamCount) and not ParamStr(I + 1).StartsWith('-') then
      begin
        Inc(I);
        FOptions.AddOrSetValue(Key, ParamStr(I));
      end
      else
        FOptions.AddOrSetValue(Key, 'true');
    end
    else
    begin
      // Positional argument
      FArgs.Add(Param);
    end;
    
    Inc(I);
  end;
end;

class function TCliUtils.GetSubCommand: string;
begin
  if ParamCount >= 2 then
    Result := LowerCase(ParamStr(2))
  else
    Result := '';
end;

class function TCliUtils.GetOption(const Name, Default: string): string;
begin
  if not FOptions.TryGetValue(Name, Result) then
    Result := Default;
end;

class function TCliUtils.HasOption(const Name: string): Boolean;
begin
  Result := FOptions.ContainsKey(Name);
end;

class function TCliUtils.GetArg(Index: Integer): string;
begin
  if (Index >= 0) and (Index < FArgs.Count) then
    Result := FArgs[Index]
  else
    Result := '';
end;

class function TCliUtils.ArgCount: Integer;
begin
  Result := FArgs.Count;
end;

class procedure TCliUtils.Info(const Msg: string);
begin
  Writeln(Msg);
end;

class procedure TCliUtils.Info(const Fmt: string; const Args: array of const);
begin
  Writeln(Format(Fmt, Args));
end;

class procedure TCliUtils.Success(const Msg: string);
begin
  Writeln('[OK] ', Msg);
end;

class procedure TCliUtils.Success(const Fmt: string; const Args: array of const);
begin
  Writeln('[OK] ', Format(Fmt, Args));
end;

class procedure TCliUtils.Warning(const Msg: string);
begin
  Writeln('[WARN] ', Msg);
end;

class procedure TCliUtils.Warning(const Fmt: string; const Args: array of const);
begin
  Writeln('[WARN] ', Format(Fmt, Args));
end;

class procedure TCliUtils.Error(const Msg: string);
begin
  Writeln('[ERROR] ', Msg);
end;

class procedure TCliUtils.Error(const Fmt: string; const Args: array of const);
begin
  Writeln('[ERROR] ', Format(Fmt, Args));
end;

class procedure TCliUtils.Progress(Current, Total: Integer; const Task: string);
var
  Pct: Integer;
  Bar: string;
  I: Integer;
begin
  if Total > 0 then
    Pct := (Current * 100) div Total
  else
    Pct := 0;
    
  Bar := '[';
  for I := 1 to 20 do
  begin
    if I <= Pct div 5 then
      Bar := Bar + '='
    else if I = (Pct div 5) + 1 then
      Bar := Bar + '>'
    else
      Bar := Bar + ' ';
  end;
  Bar := Bar + ']';
  
  if Task <> '' then
    Write(#13, Bar, ' ', Pct:3, '% ', Task, '          ')
  else
    Write(#13, Bar, ' ', Pct:3, '%          ');
    
  if Current >= Total then
    Writeln;
end;

class function TCliUtils.Confirm(const Prompt: string; Default: Boolean): Boolean;
var
  Input: string;
  DefaultStr: string;
begin
  if Default then
    DefaultStr := '[Y/n]'
  else
    DefaultStr := '[y/N]';
    
  Write(Prompt, ' ', DefaultStr, ': ');
  Readln(Input);
  Input := LowerCase(Trim(Input));
  
  if Input = '' then
    Result := Default
  else
    Result := (Input = 'y') or (Input = 'yes');
end;

class function TCliUtils.Prompt(const Question, Default: string): string;
begin
  if Default <> '' then
    Write(Question, ' [', Default, ']: ')
  else
    Write(Question, ': ');
    
  Readln(Result);
  Result := Trim(Result);
  
  if Result = '' then
    Result := Default;
end;

class function TCliUtils.ResolvePath(const Path: string): string;
begin
  if TPath.IsRelativePath(Path) then
    Result := TPath.GetFullPath(TPath.Combine(GetCurrentDir, Path))
  else
    Result := Path;
end;

class function TCliUtils.EnsureDirectory(const Path: string): Boolean;
begin
  Result := True;
  try
    if not DirectoryExists(Path) then
      ForceDirectories(Path);
  except
    Result := False;
  end;
end;

end.
