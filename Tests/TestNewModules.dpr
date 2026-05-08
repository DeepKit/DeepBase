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
  DeepBase.Types in '..\Core\DeepBase.Types.pas',
  DeepBase.CloudSync in '..\Features\DeepBase.CloudSync.pas',
  DeepBase.CLI.SSH in '..\Tools\CLI\DeepBase.CLI.SSH.pas',
  DeepBase.Updater in '..\Features\DeepBase.Updater.pas',
  DeepBase.Crypto in '..\Core\DeepBase.Crypto.pas',
  // Test units
  Test.DeepBase.CloudSync in 'Test.DeepBase.CloudSync.pas',
  Test.DeepBase.CLI.SSH in 'Test.DeepBase.CLI.SSH.pas',
  Test.DeepBase.Updater in 'Test.DeepBase.Updater.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;

begin
  try
    WriteLn('');
    WriteLn('========================================');
    WriteLn('  DeepBase New Module Tests');
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
    WriteLn(Format('  Ignored:  %d', [Results.IgnoredCount]));
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
