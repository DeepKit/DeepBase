program TestNetR7P2;

{ Standalone DUnitX runner for WO-20260920-AUDIT-Jia-R7 P2 (SSRF redirect
  gate). DeepBaseTests.dpr currently does not compile (pre-existing breakage
  in Test.Regression.CR20260824_P0Batch2.pas, untouched by this work order),
  so the Net fixture runs isolated here. Run with the repo root as working
  directory. }

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  Test.DeepBase.Net;

begin
  try
    TDUnitX.CheckCommandLine;
    var LRunner: ITestRunner := TDUnitX.CreateRunner;
    LRunner.UseRTTI := True;
    LRunner.FailsOnNoAsserts := False;

    var LConsoleLogger: ITestLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LConsoleLogger);

    TDirectory.CreateDirectory('TestResults');
    var LNUnitLogger: ITestLogger := TDUnitXXMLNUnitFileLogger.Create(
      TPath.Combine('TestResults', 'R7-P2-net.xml'));
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
