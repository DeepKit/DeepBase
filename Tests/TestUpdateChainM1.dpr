program TestUpdateChainM1;

{ Minimal DUnitX runner for WO-20260920-AUDIT-甲-R5 M1 (Top20#01 update
  signature chain). Covers both update channels without touching
  DeepBaseTests.dpr. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Test.DeepBase.UpdateFixtures,
  Test.DeepBase.Updater,
  Test.DeepBase.AutoUpdate;

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
    var LXmlFile := TPath.Combine(LXPath, '20260920-AUDIT-M1-UpdateChain.xml');
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
