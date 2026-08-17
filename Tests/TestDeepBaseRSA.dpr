program TestDeepBaseRSA;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DeepBase.Crypto.RSA in '..\Core\DeepBase.Crypto.RSA.pas',
  DeepBase.Updater in '..\Features\DeepBase.Updater.pas',
  DeepBase.AutoUpdate in '..\Features\DeepBase.AutoUpdate.pas',
  Test.DeepBase.Updater in 'Test.DeepBase.Updater.pas',
  Test.DeepBase.AutoUpdate in 'Test.DeepBase.AutoUpdate.pas';

var
  runner: ITestRunner;
  results: IRunResults;
  logger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    runner := TDUnitX.CreateRunner;
    runner.UseRTTI := True;
    logger := TDUnitXConsoleLogger.Create(True);
    runner.AddLogger(logger);

    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
