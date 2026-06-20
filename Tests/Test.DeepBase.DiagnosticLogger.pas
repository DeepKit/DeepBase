{ ============================================================================
  Test.DeepBase.DiagnosticLogger

  Diagnostic ITestLogger that writes each test and fixture event to
  Tests/Logs/test-diagnostic.log with a timestamp. The file is opened
  in append mode so each event is persisted immediately; when the test
  suite hangs the log shows exactly which test was the last one to
  start/complete.

  Register alongside TDUnitXConsoleLogger via Runner.AddLogger.
  ============================================================================ }

unit Test.DeepBase.DiagnosticLogger;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Null;

type
  TDunitXDiagnosticLogger = class(TDUnitXNullLogger)
  strict private
    FWriter: TStreamWriter;
    procedure WriteLn(const ALine: string);
  public
    constructor Create(const ALogPath: string);
    destructor Destroy; override;

    procedure OnTestingStarts(const threadId: TThreadID; testCount, testActiveCount: Cardinal); override;
    procedure OnStartTestFixture(const threadId: TThreadID; const fixture: ITestFixtureInfo); override;
    procedure OnBeginTest(const threadId: TThreadID; const Test: ITestInfo); override;
    procedure OnEndTest(const threadId: TThreadID; const Test: ITestResult); override;
    procedure OnTestSuccess(const threadId: TThreadID; const Test: ITestResult); override;
    procedure OnTestFailure(const threadId: TThreadID; const Failure: ITestError); override;
    procedure OnTestError(const threadId: TThreadID; const Error: ITestError); override;
    procedure OnTestIgnored(const threadId: TThreadID; const AIgnored: ITestResult); override;
    procedure OnEndTestFixture(const threadId: TThreadID; const results: IFixtureResult); override;
    procedure OnTestingEnds(const RunResults: IRunResults); override;
  end;

implementation

{ TDunitXDiagnosticLogger }

constructor TDunitXDiagnosticLogger.Create(const ALogPath: string);
var
  LStream: TFileStream;
begin
  inherited Create;
  var LDir := TPath.GetDirectoryName(ALogPath);
  if (LDir <> '') and not TDirectory.Exists(LDir) then
    TDirectory.CreateDirectory(LDir);
  // BUG-282 reference: Use fmShareDenyNone + OwnStream so readers can tail
  // the log while the suite runs, and the stream is freed with the writer.
  // fmCreate opens-or-creates, then we reopen with sharing flags.
  TFileStream.Create(ALogPath, fmCreate).Free;
  LStream := TFileStream.Create(ALogPath, fmOpenReadWrite or fmShareDenyNone);
  LStream.Seek(0, soEnd);
  FWriter := TStreamWriter.Create(LStream, TEncoding.UTF8);
  FWriter.OwnStream;
  FWriter.AutoFlush := True;
end;

destructor TDunitXDiagnosticLogger.Destroy;
begin
  FWriter.Free;
  inherited;
end;

procedure TDunitXDiagnosticLogger.WriteLn(const ALine: string);
begin
  FWriter.WriteLine(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + '  ' + ALine);
end;

procedure TDunitXDiagnosticLogger.OnTestingStarts(const threadId: TThreadID;
  testCount, testActiveCount: Cardinal);
begin
  inherited;
  WriteLn(Format('=== TestingStarts  total=%d active=%d ===', [testCount, testActiveCount]));
end;

procedure TDunitXDiagnosticLogger.OnStartTestFixture(const threadId: TThreadID;
  const fixture: ITestFixtureInfo);
begin
  inherited;
  WriteLn('>> Fixture BEGIN  ' + fixture.Name);
end;

procedure TDunitXDiagnosticLogger.OnBeginTest(const threadId: TThreadID;
  const Test: ITestInfo);
begin
  inherited;
  WriteLn('>> Test BEGIN      ' + Test.FullName);
end;

procedure TDunitXDiagnosticLogger.OnEndTest(const threadId: TThreadID;
  const Test: ITestResult);
begin
  inherited;
  WriteLn('<< Test END        ' + Test.Test.FullName);
end;

procedure TDunitXDiagnosticLogger.OnTestSuccess(const threadId: TThreadID;
  const Test: ITestResult);
begin
  inherited;
  WriteLn('   Test PASS       ' + Test.Test.FullName);
end;

procedure TDunitXDiagnosticLogger.OnTestFailure(const threadId: TThreadID;
  const Failure: ITestError);
begin
  inherited;
  WriteLn('   Test FAIL       ' + Failure.Test.FullName + ' -- ' + Failure.Message);
end;

procedure TDunitXDiagnosticLogger.OnTestError(const threadId: TThreadID;
  const Error: ITestError);
begin
  inherited;
  WriteLn('   Test ERROR      ' + Error.Test.FullName + ' -- ' + Error.Message);
end;

procedure TDunitXDiagnosticLogger.OnTestIgnored(const threadId: TThreadID;
  const AIgnored: ITestResult);
begin
  inherited;
  WriteLn('   Test IGNORED    ' + AIgnored.Test.FullName);
end;

procedure TDunitXDiagnosticLogger.OnEndTestFixture(const threadId: TThreadID;
  const results: IFixtureResult);
begin
  inherited;
  WriteLn('<< Fixture END     ' + results.Fixture.Name);
end;

procedure TDunitXDiagnosticLogger.OnTestingEnds(const RunResults: IRunResults);
begin
  inherited;
  WriteLn(Format('=== TestingEnds  allPassed=%s ===', [BoolToStr(RunResults.AllPassed, True)]));
end;

end.
