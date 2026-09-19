program TestGateVerdictAndA8;

{ Minimal DUnitX runner for WO-20260919-AUDIT-甲 A6+A8 test cases. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Test.DeepBase.Manifest.Verifier,
  Test.DeepBase.Updater,
  Test.DeepBase.Crypto,
  Test.Regression.BUG340_PluginUnloadOrder,
  Test.Regression.A8_InFlightUnloadGate;

begin
  try
    TDUnitX.CheckCommandLine;
    var LRunner: ITestRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;

    var LConsoleLogger: ITestLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LConsoleLogger);

    var LXPath := TPath.Combine(ExtractFilePath(ParamStr(0)), '..\TestResults');
    TDirectory.CreateDirectory(LXPath);
    var LXmlFile := TPath.Combine(LXPath, '20260919-AUDIT-A6A8.xml');
    var LNUnitLogger: ITestLogger := TDUnitXXMLNUnitFileLogger.Create(LXmlFile);
    LRunner.AddLogger(LNUnitLogger);

    var LResults: IRunResults := LRunner.Execute;
    var LPassed := LResults.AllPassed;
    LResults := nil;
    LRunner := nil;
    LNUnitLogger := nil;
    LConsoleLogger := nil;

    if not LPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
end.
