{ ============================================================================ 
  Test.UniBase.SQLLogger - Unit tests for UniBase.SQLLogger

  Coverage:
    - Basic logging to memory and statistics
    - Slow query and error classification
    - Slow / failed query filters
    - ExportToFile format
    - Session id generation
    - ExecuteCustom wrapper behavior
  ============================================================================ }

unit Test.UniBase.SQLLogger;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.Classes,
  UniBase.SQLLogger;

type
  [TestFixture]
  TTestSQLLogger = class
  private
    FPrevEnabled: Boolean;
    FPrevThreshold: Integer;
    FPrevLevel: TSQLLogLevel;
    FPrevDestinations: TLogDestinations;
    FPrevLogFilePath: string;
    FPrevMaxMemoryEntries: Integer;
    FPrevOnLog: TProc<TSQLLogEntry>;
    FPrevOnSlowQuery: TProc<TSQLLogEntry>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure LogSQLEx_WritesToMemoryAndUpdatesStats;
    [Test]
    procedure LogSQLEx_SetsLogLevelSlowAndError;
    [Test]
    procedure GetSlowAndFailedQueries_ReturnsExpectedEntries;
    [Test]
    procedure ExportToFile_WritesHeaderAndEntries;
    [Test]
    procedure NewSession_ChangesSessionId;
    [Test]
    procedure ExecuteCustom_LogsAndReraisesExceptions;
  end;

implementation

{ TTestSQLLogger }

procedure TTestSQLLogger.Setup;
begin
  FPrevEnabled := TSQLLogger.Enabled;
  FPrevThreshold := TSQLLogger.SlowQueryThresholdMs;
  FPrevLevel := TSQLLogger.LogLevel;
  FPrevDestinations := TSQLLogger.Destinations;
  FPrevLogFilePath := TSQLLogger.LogFilePath;
  FPrevMaxMemoryEntries := TSQLLogger.MaxMemoryEntries;
  FPrevOnLog := TSQLLogger.OnLog;
  FPrevOnSlowQuery := TSQLLogger.OnSlowQuery;

  TSQLLogger.Enabled := True;
  TSQLLogger.SlowQueryThresholdMs := 200;
  TSQLLogger.LogLevel := sllDebug;
  TSQLLogger.Destinations := [ldMemory];
  TSQLLogger.LogFilePath := '';
  TSQLLogger.MaxMemoryEntries := 1000;
  TSQLLogger.OnLog := nil;
  TSQLLogger.OnSlowQuery := nil;
  TSQLLogger.SetDBConnection(nil);
  TSQLLogger.ClearMemoryLog;
  TSQLLogger.ResetStatistics;
end;

procedure TTestSQLLogger.TearDown;
begin
  TSQLLogger.Enabled := FPrevEnabled;
  TSQLLogger.SlowQueryThresholdMs := FPrevThreshold;
  TSQLLogger.LogLevel := FPrevLevel;
  TSQLLogger.Destinations := FPrevDestinations;
  TSQLLogger.LogFilePath := FPrevLogFilePath;
  TSQLLogger.MaxMemoryEntries := FPrevMaxMemoryEntries;
  TSQLLogger.OnLog := FPrevOnLog;
  TSQLLogger.OnSlowQuery := FPrevOnSlowQuery;
  TSQLLogger.ClearMemoryLog;
  TSQLLogger.ResetStatistics;
end;

procedure TTestSQLLogger.LogSQLEx_WritesToMemoryAndUpdatesStats;
var
  Logs: TSQLLogEntries;
  Entry: TSQLLogEntry;
begin
  TSQLLogger.LogSQLEx('SELECT 1', 100, True, 'TestOp', '', 1);

  Logs := TSQLLogger.GetRecentLogs(10);
  Assert.IsTrue(Length(Logs) >= 1, 'Expected at least one log entry');

  Entry := Logs[High(Logs)];
  Assert.AreEqual('SELECT 1', Entry.SQL);
  Assert.AreEqual(100, Entry.DurationMs);
  Assert.IsTrue(Entry.Success);
  Assert.AreEqual('TestOp', Entry.Operation);
  Assert.AreEqual(1, Entry.RowsAffected);

  Assert.IsTrue(TSQLLogger.TotalQueries >= 1);
  Assert.IsTrue(TSQLLogger.TotalDurationMs >= 100);
end;

procedure TTestSQLLogger.LogSQLEx_SetsLogLevelSlowAndError;
var
  Logs: TSQLLogEntries;
  FastEntry, SlowEntry, ErrorEntry: TSQLLogEntry;
begin
  TSQLLogger.ClearMemoryLog;
  TSQLLogger.SlowQueryThresholdMs := 200;

  TSQLLogger.LogSQLEx('fast', 50, True, '', '', -1);
  TSQLLogger.LogSQLEx('slow', 250, True, '', '', -1);
  TSQLLogger.LogSQLEx('fail', 150, False, '', 'boom', -1);

  Logs := TSQLLogger.GetRecentLogs(10);
  Assert.AreEqual(Integer(3), Integer(Length(Logs)), 'Expected exactly three log entries');

  FastEntry := Logs[0];
  SlowEntry := Logs[1];
  ErrorEntry := Logs[2];

  Assert.AreEqual(sllInfo, FastEntry.LogLevel);
  Assert.AreEqual(sllWarn, SlowEntry.LogLevel);
  Assert.AreEqual(sllError, ErrorEntry.LogLevel);

  Assert.IsTrue(TSQLLogger.SlowQueryCount >= 1, 'SlowQueryCount should be incremented');
  Assert.IsTrue(TSQLLogger.ErrorCount >= 1, 'ErrorCount should be incremented');
end;

procedure TTestSQLLogger.GetSlowAndFailedQueries_ReturnsExpectedEntries;
var
  Slow, Failed: TSQLLogEntries;
begin
  TSQLLogger.ClearMemoryLog;
  TSQLLogger.SlowQueryThresholdMs := 200;

  TSQLLogger.LogSQLEx('A', 50, True, '', '', -1);
  TSQLLogger.LogSQLEx('B', 300, True, '', '', -1);
  TSQLLogger.LogSQLEx('C', 400, False, '', 'err', -1);

  Slow := TSQLLogger.GetSlowQueries(10);
  Assert.AreEqual(Integer(2), Integer(Length(Slow)), 'Expected two slow queries');
  Assert.IsTrue((Slow[0].SQL = 'C') or (Slow[1].SQL = 'C'),
    'One of slow queries should be C');
  Assert.IsTrue((Slow[0].SQL = 'B') or (Slow[1].SQL = 'B'),
    'One of slow queries should be B');

  Failed := TSQLLogger.GetFailedQueries(10);
  Assert.AreEqual(Integer(1), Integer(Length(Failed)), 'Expected one failed query');
  Assert.AreEqual('C', Failed[0].SQL);
end;

procedure TTestSQLLogger.ExportToFile_WritesHeaderAndEntries;
var
  Logs: TSQLLogEntries;
  TempFile: string;
  Lines: TStringList;
begin
  TSQLLogger.ClearMemoryLog;
  TSQLLogger.LogSQLEx('SELECT 1', 123, True, 'ExportOp', '', 1);
  Logs := TSQLLogger.GetRecentLogs(10);

  TempFile := TPath.Combine(TPath.GetTempPath, 'unibase_sqllogger_test.log');
  if TFile.Exists(TempFile) then
    TFile.Delete(TempFile);

  TSQLLogger.ExportToFile(TempFile, Logs);

  Assert.IsTrue(TFile.Exists(TempFile), 'Export file should exist');

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(TempFile, TEncoding.UTF8);
    Assert.IsTrue(Lines.Count >= 4);
    Assert.IsTrue(ContainsText(Lines[0], 'UniBase SQL Log Export'));
  finally
    Lines.Free;
    TFile.Delete(TempFile);
  end;
end;

procedure TTestSQLLogger.NewSession_ChangesSessionId;
var
  OldId, NewId: string;
begin
  OldId := TSQLLogger.SessionId;
  TSQLLogger.NewSession;
  NewId := TSQLLogger.SessionId;

  Assert.IsNotEmpty(NewId);
  Assert.IsFalse(OldId = NewId, 'SessionId should change after NewSession');
end;

procedure TTestSQLLogger.ExecuteCustom_LogsAndReraisesExceptions;
var
  Logs: TSQLLogEntries;
begin
  TSQLLogger.ClearMemoryLog;

  // Successful execution
  TSQLLogger.ExecuteCustom('SELECT 1', 'SuccessOp',
    procedure
    begin
      // no-op
    end);

  // Failed execution should re-raise
  Assert.WillRaise(
    procedure
    begin
      TSQLLogger.ExecuteCustom('BAD SQL', 'FailOp',
        procedure
        begin
          raise Exception.Create('boom');
        end);
    end
  );

  Logs := TSQLLogger.GetRecentLogs(10);
  Assert.IsTrue(Length(Logs) >= 2);

  // Last entry should be the failing one
  Assert.AreEqual('FailOp', Logs[High(Logs)].Operation);
  Assert.IsFalse(Logs[High(Logs)].Success);
  Assert.IsTrue(ContainsText(Logs[High(Logs)].ErrorMessage, 'boom'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSQLLogger);

end.
