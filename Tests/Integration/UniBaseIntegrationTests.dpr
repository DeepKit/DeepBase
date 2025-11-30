program UniBaseIntegrationTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  // Integration Test Framework
  UniBase.IntegrationTest in 'UniBase.IntegrationTest.pas',
  // Integration Tests
  Test.Integration.Core in 'Test.Integration.Core.pas';

{$IFNDEF TESTINSIGHT}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
{$ENDIF}

begin
  ReportMemoryLeaksOnShutdown := True;

  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  {$ELSE}
  try
    WriteLn('===============================================');
    WriteLn('     UniBase Integration Tests');
    WriteLn('===============================================');
    WriteLn('');

    // Check command line
    TDUnitX.CheckCommandLine;

    // Create test runner
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;

    // Add console logger
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    // Add NUnit XML logger for CI
    if TDUnitX.Options.XMLOutputFile <> '' then
    begin
      NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
      Runner.AddLogger(NUnitLogger);
    end
    else
    begin
      // Default output file for CI
      NUnitLogger := TDUnitXXMLNUnitFileLogger.Create('TestResults\IntegrationTestResults.xml');
      Runner.AddLogger(NUnitLogger);
    end;

    // Run tests
    Results := Runner.Execute;

    // Print summary
    WriteLn('');
    WriteLn('===============================================');
    WriteLn('              TEST SUMMARY');
    WriteLn('===============================================');
    WriteLn(Format('Total:    %d', [Results.TestCount]));
    WriteLn(Format('Passed:   %d', [Results.PassCount]));
    WriteLn(Format('Failed:   %d', [Results.FailureCount]));
    WriteLn(Format('Errors:   %d', [Results.ErrorCount]));
    if Results.TestCount > 0 then
      WriteLn(Format('Pass Rate: %.1f%%', [(Results.PassCount / Results.TestCount) * 100]))
    else
      WriteLn('Pass Rate: N/A');
    WriteLn('===============================================');
    WriteLn('');

    // Wait for user input if not running in CI
    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior <> TDUnitXExitBehavior.Continue then
    begin
      System.Write('Press Enter to exit...');
      System.Readln;
    end;
    {$ENDIF}

    // Set exit code based on results
    if not Results.AllPassed then
      System.ExitCode := 1;

  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 2;
    end;
  end;
  {$ENDIF}
end.
