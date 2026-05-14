program InferenceTests;
{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  // Test units
  Test.DeepBase.Inference.Types in 'Test.DeepBase.Inference.Types.pas',
  Test.DeepBase.Inference.Runtime in 'Test.DeepBase.Inference.Runtime.pas',
  Test.DeepBase.Inference.Session in 'Test.DeepBase.Inference.Session.pas',
  Test.DeepBase.Inference.Service in 'Test.DeepBase.Inference.Service.pas',
  Test.DeepBase.Inference.IoC in 'Test.DeepBase.Inference.IoC.pas',
  // Inference feature units
  DeepBase.Inference.Types in '..\Features\DeepBase.Inference.Types.pas',
  DeepBase.Inference.Runtime in '..\Features\DeepBase.Inference.Runtime.pas',
  DeepBase.Inference.Session in '..\Features\DeepBase.Inference.Session.pas',
  DeepBase.Inference.Service in '..\Features\DeepBase.Inference.Service.pas',
  DeepBase.Inference.IoC in '..\Features\DeepBase.Inference.IoC.pas',
  // Core dependencies
  DeepBase.Config in '..\Core\DeepBase.Config.pas',
  DeepBase.Logging in '..\Core\DeepBase.Logging.pas',
  DeepBase.IoC in '..\Core\DeepBase.IoC.pas',
  DeepBase.Manager in '..\Core\DeepBase.Manager.pas',
  DeepBase.Types in '..\Core\DeepBase.Types.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    if TDUnitX.Options.XMLOutputFile <> '' then
    begin
      NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      Runner.AddLogger(NUnitLogger);
    end;

    Results := Runner.Execute;

    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior <> TDUnitXExitBehavior.Continue then
    begin
      System.Write('Press Enter to exit..');
      System.Readln;
    end;
    {$ENDIF}

    if not Results.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
