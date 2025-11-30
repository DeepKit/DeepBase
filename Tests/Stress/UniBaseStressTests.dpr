{ ============================================================================
  UniBase Stress Tests
  
  Comprehensive stress testing suite for UniBase framework.
  Tests high-concurrency, large-scale operations, and long-running stability.
  
  Usage:
    UniBaseStressTests.exe [options]
    
    Options:
      -duration=N    Test duration in seconds (default 60)
      -threads=N     Number of concurrent threads (default 10)
      -suite=NAME    Run specific test suite (config/logging/database/stability/all)
      -output=FILE   Output report file
      -format=FMT    Report format (text/json/html/csv)
      -quick         Run quick tests (30 seconds each)
      -verbose       Verbose output
  
  Examples:
    UniBaseStressTests.exe -suite=all -duration=300 -threads=20
    UniBaseStressTests.exe -suite=config -output=report.html -format=html
    UniBaseStressTests.exe -quick -verbose
  ============================================================================ }

program UniBaseStressTests;

{$APPTYPE CONSOLE}

// {$R *.res} // Resource file not needed for console app

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  UniBase.StressTest in 'UniBase.StressTest.pas',
  Stress.Config in 'Stress.Config.pas',
  Stress.Logging in 'Stress.Logging.pas',
  Stress.Database in 'Stress.Database.pas',
  Stress.Stability in 'Stress.Stability.pas',
  UniBase.Manager in '..\..\Core\UniBase.Manager.pas';

var
  Duration: Integer = 60;
  ThreadCount: Integer = 10;
  Suite: string = 'all';
  OutputFile: string = '';
  OutputFormat: TStressReportFormat = srfText;
  QuickMode: Boolean = False;
  Verbose: Boolean = False;
  
procedure ParseCommandLine;
var
  I: Integer;
  Param, Key, Value: string;
  P: Integer;
begin
  for I := 1 to ParamCount do
  begin
    Param := ParamStr(I);
    
    if Param = '-quick' then
      QuickMode := True
    else if Param = '-verbose' then
      Verbose := True
    else if Param.StartsWith('-') then
    begin
      P := Pos('=', Param);
      if P > 0 then
      begin
        Key := Copy(Param, 2, P - 2).ToLower;
        Value := Copy(Param, P + 1, MaxInt);
        
        if Key = 'duration' then
          Duration := StrToIntDef(Value, 60)
        else if Key = 'threads' then
          ThreadCount := StrToIntDef(Value, 10)
        else if Key = 'suite' then
          Suite := Value.ToLower
        else if Key = 'output' then
          OutputFile := Value
        else if Key = 'format' then
        begin
          Value := Value.ToLower;
          if Value = 'json' then
            OutputFormat := srfJSON
          else if Value = 'html' then
            OutputFormat := srfHTML
          else if Value = 'csv' then
            OutputFormat := srfCSV
          else
            OutputFormat := srfText;
        end;
      end;
    end;
  end;
  
  if QuickMode then
    Duration := 30;
end;

procedure PrintHeader;
begin
  WriteLn;
  WriteLn('================================================================================');
  WriteLn('  UniBase Stress Tests');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn(Format('  Duration:     %d seconds', [Duration]));
  WriteLn(Format('  Threads:      %d', [ThreadCount]));
  WriteLn(Format('  Suite:        %s', [Suite]));
  WriteLn(Format('  Quick Mode:   %s', [BoolToStr(QuickMode, True)]));
  if OutputFile <> '' then
    WriteLn(Format('  Output:       %s', [OutputFile]));
  WriteLn;
  WriteLn('--------------------------------------------------------------------------------');
  WriteLn;
end;

// Event handlers moved to helper class
type
  TEventHelper = class
  public
    class var Verbose: Boolean;
    class procedure PrintProgress(Sender: TObject; Progress: Integer; const Status: string);
    class procedure PrintError(Sender: TObject; const Error: string);
  end;

class procedure TEventHelper.PrintProgress(Sender: TObject; Progress: Integer; const Status: string);
begin
  if Verbose then
    WriteLn(Format('[%3d%%] %s', [Progress, Status]));
end;

class procedure TEventHelper.PrintError(Sender: TObject; const Error: string);
begin
  WriteLn(Format('ERROR: %s', [Error]));
end;

procedure PrintResult(const R: TStressTestResult);
begin
  WriteLn(Format('  Test: %s', [R.TestName]));
  WriteLn(Format('  Status: %s', [R.GetStatusString]));
  WriteLn(Format('  Duration: %.2f sec', [R.DurationSec]));
  WriteLn(Format('  Operations: %d (%.2f ops/sec)', 
    [R.Throughput.TotalOperations, R.Throughput.OpsPerSecond]));
  WriteLn(Format('  Success Rate: %.2f%%', [R.Throughput.SuccessRate * 100]));
  WriteLn(Format('  Latency: min=%.2f ms, avg=%.2f ms, p99=%.2f ms, max=%.2f ms',
    [R.Latency.MinMs, R.Latency.MeanMs, R.Latency.P99Ms, R.Latency.MaxMs]));
  WriteLn(Format('  Memory Leak: %s', [TMemoryStats.FormatBytes(R.MemoryLeakBytes)]));
  if R.ErrorCount > 0 then
    WriteLn(Format('  Errors: %d', [R.ErrorCount]));
  WriteLn;
end;

procedure RunConfigTests;
var
  Runner: TStressTestRunner;
  R: TStressTestResult;
begin
  WriteLn('Running Configuration Stress Tests...');
  WriteLn;
  
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := Duration;
    Runner.Config.ThreadCount := ThreadCount;
    Runner.OnProgress := TEventHelper.PrintProgress;
    Runner.OnError := TEventHelper.PrintError;
    
    Runner.AddTest(TConfigReadStressTest.Create);
    Runner.AddTest(TConfigWriteStressTest.Create);
    Runner.AddTest(TConfigMixedStressTest.Create);
    Runner.AddTest(TConfigCacheStressTest.Create);
    
    Runner.Run;
    
    for R in Runner.Report.Results do
      PrintResult(R);
    
    if OutputFile <> '' then
      Runner.Report.SaveToFile(OutputFile, OutputFormat);
  finally
    Runner.Free;
  end;
end;

procedure RunLoggingTests;
var
  Runner: TStressTestRunner;
  R: TStressTestResult;
begin
  WriteLn('Running Logging Stress Tests...');
  WriteLn;
  
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := Duration;
    Runner.Config.ThreadCount := ThreadCount;
    Runner.OnProgress := TEventHelper.PrintProgress;
    Runner.OnError := TEventHelper.PrintError;
    
    Runner.AddTest(TLogWriteStressTest.Create);
    Runner.AddTest(TLogLevelMixStressTest.Create);
    Runner.AddTest(TLogFormattedStressTest.Create);
    Runner.AddTest(TLogThroughputStressTest.Create);
    
    Runner.Run;
    
    for R in Runner.Report.Results do
      PrintResult(R);
    
    if OutputFile <> '' then
      Runner.Report.SaveToFile(OutputFile, OutputFormat);
  finally
    Runner.Free;
  end;
end;

procedure RunDatabaseTests;
var
  Runner: TStressTestRunner;
  R: TStressTestResult;
begin
  WriteLn('Running Database Stress Tests...');
  WriteLn;
  
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := Duration;
    Runner.Config.ThreadCount := ThreadCount;
    Runner.OnProgress := TEventHelper.PrintProgress;
    Runner.OnError := TEventHelper.PrintError;
    
    Runner.AddTest(TDBQueryStressTest.Create);
    Runner.AddTest(TDBInsertStressTest.Create);
    Runner.AddTest(TDBTransactionStressTest.Create);
    Runner.AddTest(TDBMixedOperationsStressTest.Create);
    
    Runner.Run;
    
    for R in Runner.Report.Results do
      PrintResult(R);
    
    if OutputFile <> '' then
      Runner.Report.SaveToFile(OutputFile, OutputFormat);
  finally
    Runner.Free;
  end;
end;

procedure RunStabilityTests;
var
  Runner: TStressTestRunner;
  R: TStressTestResult;
begin
  WriteLn('Running Stability Stress Tests...');
  WriteLn;
  
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := Duration;
    Runner.Config.ThreadCount := ThreadCount;
    Runner.OnProgress := TEventHelper.PrintProgress;
    Runner.OnError := TEventHelper.PrintError;
    
    Runner.AddTest(TLongRunningStressTest.Create);
    Runner.AddTest(TMemoryLeakStabilityTest.Create);
    Runner.AddTest(TContinuousOperationStressTest.Create);
    Runner.AddTest(TGCStressTest.Create);
    Runner.AddTest(TThreadChurnStressTest.Create);
    
    Runner.Run;
    
    for R in Runner.Report.Results do
      PrintResult(R);
    
    if OutputFile <> '' then
      Runner.Report.SaveToFile(OutputFile, OutputFormat);
  finally
    Runner.Free;
  end;
end;

procedure RunAllTests;
var
  Runner: TStressTestRunner;
  R: TStressTestResult;
  TotalTests, PassedTests: Integer;
begin
  WriteLn('Running All Stress Tests...');
  WriteLn;
  
  Runner := TStressTestRunner.Create;
  try
    Runner.Config.DurationSec := Duration;
    Runner.Config.ThreadCount := ThreadCount;
    Runner.OnProgress := TEventHelper.PrintProgress;
    Runner.OnError := TEventHelper.PrintError;
    
    // Config tests
    Runner.AddTest(TConfigReadStressTest.Create);
    Runner.AddTest(TConfigWriteStressTest.Create);
    Runner.AddTest(TConfigMixedStressTest.Create);
    
    // Logging tests
    Runner.AddTest(TLogWriteStressTest.Create);
    Runner.AddTest(TLogLevelMixStressTest.Create);
    Runner.AddTest(TLogThroughputStressTest.Create);
    
    // Database tests
    Runner.AddTest(TDBQueryStressTest.Create);
    Runner.AddTest(TDBInsertStressTest.Create);
    Runner.AddTest(TDBMixedOperationsStressTest.Create);
    
    // Stability tests
    Runner.AddTest(TLongRunningStressTest.Create);
    Runner.AddTest(TMemoryLeakStabilityTest.Create);
    Runner.AddTest(TContinuousOperationStressTest.Create);
    
    Runner.Run;
    
    TotalTests := Runner.Report.Results.Count;
    PassedTests := 0;
    
    for R in Runner.Report.Results do
    begin
      PrintResult(R);
      if R.IsSuccess then
        Inc(PassedTests);
    end;
    
    WriteLn('================================================================================');
    WriteLn(Format('  Summary: %d/%d tests passed', [PassedTests, TotalTests]));
    WriteLn('================================================================================');
    
    if OutputFile <> '' then
      Runner.Report.SaveToFile(OutputFile, OutputFormat);
  finally
    Runner.Free;
  end;
end;

begin
  try
    ParseCommandLine;
    TEventHelper.Verbose := Verbose;  // Set verbose flag for helper class
    PrintHeader;
    
    // Initialize UniBase
    WriteLn('Initializing UniBase...');
    try
      if not UniBase.Manager.UniBase.InitializeWithDB(
        ExtractFilePath(ParamStr(0)) + 'stress_test.db') then
      begin
        WriteLn('Warning: UniBase initialization returned false: ' + 
          UniBase.Manager.UniBase.LastError);
      end
      else
        WriteLn('UniBase initialized successfully.');
      WriteLn;
    except
      on E: Exception do
      begin
        WriteLn('Failed to initialize UniBase: ' + E.Message);
        WriteLn('Some tests may fail or be skipped.');
        WriteLn;
      end;
    end;
    
    // Run selected test suite
    if Suite = 'config' then
      RunConfigTests
    else if Suite = 'logging' then
      RunLoggingTests
    else if Suite = 'database' then
      RunDatabaseTests
    else if Suite = 'stability' then
      RunStabilityTests
    else
      RunAllTests;
    
    WriteLn;
    WriteLn('Stress tests completed.');
    
    // Cleanup
    try
      UniBase.Manager.UniBase.Finalize;
    except
      // Ignore cleanup errors
    end;
    
  except
    on E: Exception do
    begin
      WriteLn('Fatal error: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
