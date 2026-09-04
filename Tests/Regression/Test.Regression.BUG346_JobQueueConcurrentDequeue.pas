unit Test.Regression.BUG346_JobQueueConcurrentDequeue;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.Generics.Collections,
  System.Threading,
  FireDAC.Comp.Client,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.DB.JobQueue;

type
  [TestFixture]
  [Category('regression')]
  TBUG346_JobQueueConcurrentDequeueTest = class(TRegressionTestBase)
  private
    FTempDir: string;
    FDBPath: string;
    function CreateConnection: TFDConnection;
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Setup]
    procedure SetUp; override;
    [TearDown]
    procedure TearDown; override;

    [Test]
    procedure Test_ConcurrentDequeue_NoBusyAndNoDoubleClaim;
  end;

implementation

const
  CQueueName = 'bug346_queue';
  CTaskCount = 20;

procedure TBUG346_JobQueueConcurrentDequeueTest.SetUp;
var
  GuidText: string;
  I: Integer;
  Payload: TJSONObject;
begin
  inherited;
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_BUG346_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FDBPath := TPath.Combine(FTempDir, 'queue.db');

  TJobQueue.Clear;
  TJobQueue.SetConnectionProvider(
    function: TFDConnection
    begin
      Result := CreateConnection;
    end);
  TJobQueue.EnsureSchema;

  for I := 1 to CTaskCount do
  begin
    Payload := TJSONObject.Create;
    try
      Payload.AddPair('idx', TJSONNumber.Create(I));
      Assert.IsTrue(TJobQueue.Enqueue(CQueueName, Format('key_%d', [I]), Payload));
    finally
      Payload.Free;
    end;
  end;
end;

procedure TBUG346_JobQueueConcurrentDequeueTest.TearDown;
begin
  TJobQueue.Clear;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
  inherited;
end;

function TBUG346_JobQueueConcurrentDequeueTest.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Database := FDBPath;
    Result.Params.Values['OpenMode'] := 'CreateUTF8';
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.Params.Values['JournalMode'] := 'WAL';
    Result.Params.Values['Synchronous'] := 'Normal';
    Result.Params.Values['BusyTimeout'] := '10000';
    Result.Params.Values['SharedCache'] := 'False';
    Result.LoginPrompt := False;
    Result.Open;
    Result.ExecSQL('PRAGMA busy_timeout=10000');
    Result.ExecSQL('PRAGMA journal_mode=WAL');
  except
    Result.Free;
    raise;
  end;
end;

function TBUG346_JobQueueConcurrentDequeueTest.GetBugNumber: string;
begin
  Result := 'BUG-346';
end;

function TBUG346_JobQueueConcurrentDequeueTest.GetBugDescription: string;
begin
  Result := 'JobQueue concurrent Dequeue must not SQLITE_BUSY or double-claim tasks';
end;

function TBUG346_JobQueueConcurrentDequeueTest.GetFixDate: string;
begin
  Result := '2026-09-03';
end;

function TBUG346_JobQueueConcurrentDequeueTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG346_JobQueueConcurrentDequeueTest.GetAffectedFile: string;
begin
  Result := 'Persistence/DeepBase.DB.JobQueue.pas';
end;

procedure TBUG346_JobQueueConcurrentDequeueTest.Test_ConcurrentDequeue_NoBusyAndNoDoubleClaim;
var
  LClaimed: TDictionary<string, Byte>;
  LLock: TObject;
  LErrors: Integer;
  LBusyErrors: Integer;
  LDoubleClaims: Integer;
  LDequeuedCount: Integer;
  LTasks: array[0..1] of ITask;
  LStartGate: TCountdownEvent;
  LLastError: string;
  I: Integer;
begin
  LClaimed := TDictionary<string, Byte>.Create;
  LLock := TObject.Create;
  LErrors := 0;
  LBusyErrors := 0;
  LDoubleClaims := 0;
  LDequeuedCount := 0;
  LLastError := '';
  LStartGate := TCountdownEvent.Create(2);
  try
    for I := 0 to 1 do
    begin
      LTasks[I] := TTask.Run(
        procedure
        var
          LocalTask: TTaskRec;
        begin
          try
            LStartGate.Signal;
            LStartGate.WaitFor;
            while TJobQueue.Dequeue(CQueueName, LocalTask) do
            begin
              TMonitor.Enter(LLock);
              try
                if LClaimed.ContainsKey(LocalTask.TaskID) then
                  TInterlocked.Increment(LDoubleClaims);
                LClaimed.AddOrSetValue(LocalTask.TaskID, 1);
                TInterlocked.Increment(LDequeuedCount);
              finally
                TMonitor.Exit(LLock);
              end;
              if Assigned(LocalTask.Payload) then
                FreeAndNil(LocalTask.Payload);
            end;
          except
            on E: Exception do
            begin
              TInterlocked.Increment(LErrors);
              if (Pos('busy', LowerCase(E.Message)) > 0) or
                 (Pos('locked', LowerCase(E.Message)) > 0) then
                TInterlocked.Increment(LBusyErrors);
              TMonitor.Enter(LLock);
              try
                LLastError := E.ClassName + ': ' + E.Message;
              finally
                TMonitor.Exit(LLock);
              end;
            end;
          end;
        end);
    end;

    TTask.WaitForAll([LTasks[0], LTasks[1]]);

    Assert.AreEqual(Integer(0), Integer(LBusyErrors),
      'Concurrent Dequeue must not raise SQLITE_BUSY/locked: ' + LLastError);
    Assert.AreEqual(Integer(0), Integer(LDoubleClaims), 'Concurrent Dequeue must not double-claim');
    Assert.AreEqual(Integer(0), Integer(LErrors), 'Concurrent Dequeue must not raise: ' + LLastError);
    Assert.AreEqual(Integer(CTaskCount), Integer(LDequeuedCount),
      Format('All enqueued tasks must be dequeued exactly once (got %d)', [LDequeuedCount]));
    Assert.AreEqual(Integer(CTaskCount), Integer(LClaimed.Count),
      Format('Each task id must appear at most once across workers (got %d)', [LClaimed.Count]));
  finally
    LStartGate.Free;
    LLock.Free;
    LClaimed.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG346_JobQueueConcurrentDequeueTest);

end.
