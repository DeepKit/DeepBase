program DeepBaseIntegrationTests;

{$IFNDEF TESTDeepInsight}
{$APPTYPE CONSOLE}
{$ENDIF}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTDeepInsight}
  TestDeepInsight.DUnitX,
  {$ELSE}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  {$ENDIF}
  DUnitX.TestFramework,
  // FireDAC SQLite Driver
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  DeepBase.Persistence.Manager.FireDAC in '..\..\Persistence\DeepBase.Persistence.Manager.FireDAC.pas',
  DeepBase.Persistence.Exception.FireDAC in '..\..\Persistence\DeepBase.Persistence.Exception.FireDAC.pas',
  DeepBase.Persistence.Diagnose.FireDAC in '..\..\Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas',
  DeepBase.Persistence.ORM.FireDAC in '..\..\Persistence\DeepBase.Persistence.ORM.FireDAC.pas',
  DeepBase.Persistence.LLM.FireDAC in '..\..\Persistence\DeepBase.Persistence.LLM.FireDAC.pas',
  // Integration Test Framework
  DeepBase.IntegrationTest in 'DeepBase.IntegrationTest.pas',
  // Integration Tests
  Test.Integration.Core in 'Test.Integration.Core.pas',
  Test.Integration.WebAPI in 'Test.Integration.WebAPI.pas',
  Test.Integration.CommerceE2E in 'Test.Integration.CommerceE2E.pas';

{$IFNDEF TESTDeepInsight}
var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;
{$ENDIF}

begin
  ReportMemoryLeaksOnShutdown := True;

  {$IFDEF TESTDeepInsight}
  TestDeepInsight.DUnitX.RunRegisteredTests;
  {$ELSE}
  try
    WriteLn('===============================================');
    WriteLn('     DeepBase Integration Tests');
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
