program UpdaterHelper;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  UpdaterHelper.Core in 'UpdaterHelper.Core.pas';

var
  Options: THelperOptions;
  ErrorMessage: string;
begin
  try
    if not TUpdaterHelper.ParseArgs(Options, ErrorMessage) then
    begin
      Writeln('ERROR: ' + ErrorMessage);
      ExitCode := 2;
      Exit;
    end;

    if not TUpdaterHelper.Execute(Options, ErrorMessage) then
    begin
      Writeln('ERROR: ' + ErrorMessage);
      ExitCode := 3;
      Exit;
    end;

    Writeln('OK');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('FATAL: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 10;
    end;
  end;
end.

