{ ============================================================================
  DeepBase CLI Tool
  
  版本: 1.0
  说明: DeepBase 命令行工�?
  命令:
    - db init/upgrade/backup/check
    - i18n scan/sync/translate/export/import
    - config get/set/export/import
  ============================================================================ }

program DeepBase;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  CLI.Main in 'CLI.Main.pas',
  CLI.Commands in 'CLI.Commands.pas',
  CLI.DB in 'CLI.DB.pas',
  CLI.I18n in 'CLI.I18n.pas',
  CLI.Config in 'CLI.Config.pas';

begin
  try
    ExitCode := TCliMain.Run;
  except
    on E: Exception do
    begin
      Writeln('Error: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
