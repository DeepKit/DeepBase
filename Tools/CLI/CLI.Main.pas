{ ============================================================================
  CLI.Main - CLI 主入口和命令分发
  
  版本: 1.0
  说明: 解析命令行参数，分发到各子命令模�?
  ============================================================================ }

unit CLI.Main;

interface

uses
  System.SysUtils,
  System.Classes,
  CLI.Commands;

type
  TCliMain = class
  private
    class procedure ShowHelp;
    class procedure ShowVersion;
  public
    class function Run: Integer;
  end;

implementation

uses
  CLI.DB,
  CLI.I18n,
  CLI.Config;

const
  VERSION = '1.0.0';

{ TCliMain }

class function TCliMain.Run: Integer;
var
  Cmd: string;
begin
  Result := 0;
  
  if ParamCount < 1 then
  begin
    ShowHelp;
    Exit;
  end;
  
  Cmd := LowerCase(ParamStr(1));
  
  if (Cmd = '-h') or (Cmd = '--help') or (Cmd = 'help') then
  begin
    ShowHelp;
    Exit;
  end;
  
  if (Cmd = '-v') or (Cmd = '--version') or (Cmd = 'version') then
  begin
    ShowVersion;
    Exit;
  end;
  
  if Cmd = 'db' then
    Result := TDBCommands.Execute
  else if Cmd = 'i18n' then
    Result := TI18nCommands.Execute
  else if Cmd = 'config' then
    Result := TConfigCommands.Execute
  else
  begin
    Writeln('Unknown command: ', Cmd);
    Writeln('Use "DeepBase --help" for usage information.');
    Result := 1;
  end;
end;

class procedure TCliMain.ShowHelp;
begin
  Writeln('DeepBase CLI Tool v', VERSION);
  Writeln('');
  Writeln('Usage: DeepBase <command> [subcommand] [options]');
  Writeln('');
  Writeln('Commands:');
  Writeln('  db        Database management');
  Writeln('            init      Initialize a new database');
  Writeln('            upgrade   Upgrade database schema');
  Writeln('            backup    Create database backup');
  Writeln('            check     Check database integrity');
  Writeln('');
  Writeln('  i18n      Internationalization');
  Writeln('            scan      Scan source files for translatable strings');
  Writeln('            sync      Sync translations with source');
  Writeln('            translate Auto-translate using LLM');
  Writeln('            export    Export translations to file');
  Writeln('            import    Import translations from file');
  Writeln('');
  Writeln('  config    Configuration management');
  Writeln('            get       Get configuration value');
  Writeln('            set       Set configuration value');
  Writeln('            export    Export configuration to file');
  Writeln('            import    Import configuration from file');
  Writeln('');
  Writeln('Options:');
  Writeln('  -h, --help      Show this help message');
  Writeln('  -v, --version   Show version information');
  Writeln('');
  Writeln('Examples:');
  Writeln('  DeepBase db init --tier 1 --path ./mydb.db');
  Writeln('  DeepBase i18n scan --path ./src --output strings.json');
  Writeln('  DeepBase config get app.theme');
end;

class procedure TCliMain.ShowVersion;
begin
  Writeln('DeepBase CLI Tool');
  Writeln('Version: ', VERSION);
  Writeln('Copyright (c) 2024 DeepBase');
end;

end.
