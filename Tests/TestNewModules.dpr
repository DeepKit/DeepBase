program TestNewModules;
{$APPTYPE CONSOLE}

{******************************************************************************
  TestNewModules - Test runner for CloudSync, SSH, and Updater module tests
  
  This is a standalone test runner to verify the new unit tests compile and run.
  
  Usage: TestNewModules.exe
******************************************************************************}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  // Core dependencies
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.CloudSync in '..\Core\UniBase.CloudSync.pas',
  UniBase.CLI.SSH in '..\Core\UniBase.CLI.SSH.pas',
  UniBase.Updater in '..\Features\UniBase.Updater.pas',
  UniBase.Crypto in '..\Core\UniBase.Crypto.pas',
  // Test units
  Test.UniBase.CloudSync in 'Test.UniBase.CloudSync.pas',
  Test.UniBase.CLI.SSH in 'Test.UniBase.CLI.SSH.pas',
  Test.UniBase.Updater in 'Test.UniBase.Updater.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;

begin
  try
    WriteLn('');
    WriteLn('========================================');
    WriteLn('  UniBase New Module Tests');
    WriteLn('========================================');
    WriteLn('');
    WriteLn('Testing: CloudSync, SSH, Updater');
    WriteLn('');
    
    // Check if fixtures are registered
    if TDUnitX.RegisteredFixtures.Count = 0 then
    begin
      WriteLn('ERROR: No test fixtures registered!');
      ExitCode := 1;
      Exit;
    end;
    
    WriteLn('Registered fixtures: ' + IntToStr(TDUnitX.RegisteredFixtures.Count));
    WriteLn('');
    
    // Create runner
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    
    // Add console logger
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    
    // Run tests
    WriteLn('Running tests...');
    WriteLn('');
    
    Results := Runner.Execute;
    
    // Print summary
    WriteLn('');
    WriteLn('========================================');
    WriteLn('  Test Summary');
    WriteLn('========================================');
    WriteLn('');
    WriteLn(Format('  Total:    %d', [Results.TestCount]));
    WriteLn(Format('  Passed:   %d', [Results.PassCount]));
    WriteLn(Format('  Failed:   %d', [Results.FailureCount]));
    WriteLn(Format('  Errors:   %d', [Results.ErrorCount]));
    WriteLn(Format('  Skipped:  %d', [Results.SkippedCount]));
    WriteLn('');
    
    if Results.AllPassed then
    begin
      WriteLn('All tests passed!');
      ExitCode := 0;
    end
    else
    begin
      WriteLn('Some tests failed!');
      ExitCode := 1;
    end;
    
    {$IFDEF DEBUG}
    WriteLn('');
    Write('Press Enter to exit...');
    ReadLn;
    {$ENDIF}
    
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ' + E.Message);
      ExitCode := 2;
    end;
  end;
end.
