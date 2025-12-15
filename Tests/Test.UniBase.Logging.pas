unit Test.UniBase.Logging;

{*******************************************************************************
  UniBase Logging module tests

  Notes:
  - TUniBaseLogger writes asynchronously via a background thread.
  - In unit tests we use file-only mode to avoid SQLite ':memory:' multi-connection
    limitations and to keep assertions deterministic.
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Threading,
  System.Diagnostics,
  UniBase.Logging,
  UniBase.Types;

type
  [TestFixture]
  TTestUniBaseLogging = class
  private
    FLog: TUniBaseLogger;
    FLogDir: string;
    FDatePrefix: string;

    procedure CleanupTodayLogs;
    function FindTodayLogFiles: TArray<string>;
    function WaitForAnyTodayFileContains(const SubStr: string; TimeoutMs: Integer = 3000): Boolean;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Info_WritesToFile;

    [Test]
    procedure Test_InfoFmt_WritesFormattedText;

    [Test]
    procedure Test_ClearOldLogs_DoesNotRaise;

    [Test]
    procedure Test_ThreadSafety_ConcurrentWrites_DoesNotRaise;
  end;

implementation

procedure TTestUniBaseLogging.CleanupTodayLogs;
var
  Files: TArray<string>;
  F: string;
begin
  Files := FindTodayLogFiles;
  for F in Files do
  begin
    try
      if TFile.Exists(F) then
        TFile.Delete(F);
    except
      // ignore
    end;
  end;
end;

function TTestUniBaseLogging.FindTodayLogFiles: TArray<string>;
begin
  if not DirectoryExists(FLogDir) then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // e.g. Log_2025-12-13.txt, Log_2025-12-13.1.txt, etc.
  Result := TDirectory.GetFiles(FLogDir, FDatePrefix + '*.txt');
end;

function TTestUniBaseLogging.WaitForAnyTodayFileContains(const SubStr: string; TimeoutMs: Integer): Boolean;
var
  SW: TStopwatch;
  Files: TArray<string>;
  F: string;
  Content: string;
begin
  Result := False;

  SW := TStopwatch.StartNew;
  while SW.ElapsedMilliseconds < TimeoutMs do
  begin
    Files := FindTodayLogFiles;
    for F in Files do
    begin
      try
        Content := TFile.ReadAllText(F, TEncoding.UTF8);
        if Content.Contains(SubStr) then
          Exit(True);
      except
        // ignore (file may be locked briefly while being appended)
      end;
    end;

    Sleep(50);
  end;
end;

procedure TTestUniBaseLogging.Setup;
begin
  // Default log dir is <exe-dir>\Logs
  FLogDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Logs');
  FDatePrefix := 'Log_' + FormatDateTime('yyyy-MM-dd', Date);

  CleanupTodayLogs;

  // File-only logger (DBPath = '')
  FLog := TUniBaseLogger.Create('');
  FLog.StorageMode := lsmFile;
  FLog.LogFormat := lfText;
  FLog.MinLevel := llDebug;
end;

procedure TTestUniBaseLogging.TearDown;
begin
  FreeAndNil(FLog);
  CleanupTodayLogs;
end;

procedure TTestUniBaseLogging.Test_Info_WritesToFile;
var
  Msg: string;
begin
  Msg := 'Test_Info_WritesToFile ' + TGUID.NewGuid.ToString;

  FLog.Info(Msg, 'Test');

  Assert.IsTrue(
    WaitForAnyTodayFileContains(Msg, 4000),
    '日志应写入到当天的日志文件中'
  );
end;

procedure TTestUniBaseLogging.Test_InfoFmt_WritesFormattedText;
var
  MsgPart: string;
begin
  MsgPart := 'Hello Alice ' + TGUID.NewGuid.ToString;

  FLog.InfoFmt('Hello %s %s', ['Alice', MsgPart], 'Test');

  Assert.IsTrue(
    WaitForAnyTodayFileContains(MsgPart, 4000),
    'InfoFmt 应输出正确格式化后的文本'
  );
end;

procedure TTestUniBaseLogging.Test_ClearOldLogs_DoesNotRaise;
begin
  try
    // Just verify it doesn't raise in file-only mode.
    FLog.ClearOldLogs(0);
  except
    on E: Exception do
      Assert.Fail('ClearOldLogs should not raise: ' + E.Message);
  end;
end;

procedure TTestUniBaseLogging.Test_ThreadSafety_ConcurrentWrites_DoesNotRaise;
const
  THREADS = 8;
  PER_THREAD = 200;
var
  Tasks: array[0..THREADS - 1] of ITask;
  I: Integer;
  Marker: string;
begin
  Marker := 'ThreadSafetyMarker ' + TGUID.NewGuid.ToString;

  for I := 0 to THREADS - 1 do
  begin
    Tasks[I] := TTask.Create(
      procedure
      var
        J: Integer;
      begin
        for J := 1 to PER_THREAD do
          FLog.Info(Marker + ' ' + IntToStr(J), 'ThreadTest');
      end
    );
  end;

  for I := 0 to THREADS - 1 do
    Tasks[I].Start;

  TTask.WaitForAll(Tasks);

  Assert.IsTrue(
    WaitForAnyTodayFileContains(Marker, 5000),
    '并发写入后应能在日志文件中找到标记字符串'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseLogging);

end.
