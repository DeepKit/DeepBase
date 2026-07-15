unit Test.DeepBase.DB.JobQueue;

interface

uses
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  DeepBase.DB.JobQueue;

type
  [TestFixture]
  TTestDBJobQueue = class
  private
    FTempDir: string;
    FDBPath: string;
    function CreateConnection: TFDConnection;
    function CountRows(const QueueName, Status: string): Integer;
    function ReadStatus(const TaskID: string): string;
    function ReadHeartbeat(const TaskID: string): string;
    procedure SetHeartbeatToPast(const TaskID: string; SecondsAgo: Integer);
    procedure ResetNextRunAt(const TaskID: string);
    function ReadNextRunAt(const TaskID: string): string;
    function ReadDLQRow(const OriginalID: string; out QueueName, LogicalKey,
      LastError: string; out Attempts: Integer; out Payload: string): Boolean;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Enqueue_IsIdempotentByQueueAndLogicalKey;

    [Test]
    procedure Test_Dequeue_ClaimsPendingTaskAndReturnsPayload;

    [Test]
    procedure Test_Dequeue_DoesNotCrossQueues;

    [Test]
    procedure Test_Heartbeat_UpdatesRunningTask;

    [Test]
    procedure Test_RecycleDeadTasks_RequeuesStaleRunningTask;

    [Test]
    procedure Test_Complete_MarksRunningTaskDone;

    [Test]
    procedure Test_Fail_WithRequeue_MakesTaskPendingAgain;

    [Test]
    procedure Test_Dequeue_RespectsNextRunAt;

    [Test]
    procedure Test_Fail_SetsNextRunAt_ExponentialBackoff;

    [Test]
    procedure Test_Fail_ExceedsMaxRetries_TransfersToDLQ;

    [Test]
    procedure Test_DeadLetterCount_FiltersByQueue;

    [Test]
    procedure Test_PeekDeadLetters_RespectsLimitAndQueue;

    [Test]
    procedure Test_ReplayDeadLetter_MovesBackToMainPending;

    [Test]
    procedure Test_PurgeDeadLetter_RemovesRow;

    [Test]
    procedure Test_Dequeue_EmptyQueueReturnsFalse;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.DateUtils,
  FireDAC.Stan.Param;

const
  JOB_QUEUE_TABLE = 'DeepBase_job_queue';

procedure TTestDBJobQueue.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_JobQueue_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FDBPath := TPath.Combine(FTempDir, 'queue.db');

  TJobQueue.Clear;
  TJobQueue.SetConnectionProvider(
    function: TFDConnection
    begin
      Result := CreateConnection;
    end);
  // EXP-P1-015: force the pool to materialise the DLQ table up-front so that
  // helper connections (used for direct SQL in tests) and pooled connections
  // share a consistent view of the schema.
  TJobQueue.EnsureSchema;
end;

procedure TTestDBJobQueue.TearDown;
begin
  TJobQueue.Clear;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestDBJobQueue.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Database := FDBPath;
    Result.Params.Values['OpenMode'] := 'CreateUTF8';
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.LoginPrompt := False;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

function TTestDBJobQueue.CountRows(const QueueName, Status: string): Integer;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM ' + JOB_QUEUE_TABLE +
        ' WHERE queue_name = :queue_name AND status = :status';
      Query.ParamByName('queue_name').AsString := QueueName;
      Query.ParamByName('status').AsString := Status;
      Query.Open;
      Result := Query.Fields[0].AsInteger;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBJobQueue.ReadStatus(const TaskID: string): string;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := '';
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'SELECT status FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
      Query.ParamByName('id').AsString := TaskID;
      Query.Open;
      if not Query.Eof then
        Result := Query.Fields[0].AsString;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBJobQueue.ReadHeartbeat(const TaskID: string): string;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := '';
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'SELECT heartbeat_at FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
      Query.ParamByName('id').AsString := TaskID;
      Query.Open;
      if not Query.Eof then
        Result := Query.Fields[0].AsString;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TTestDBJobQueue.SetHeartbeatToPast(const TaskID: string;
  SecondsAgo: Integer);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET heartbeat_at = ' +
        'datetime(''now'', ''-'' || :seconds || '' seconds'') WHERE id = :id';
      Query.ParamByName('seconds').AsInteger := SecondsAgo;
      Query.ParamByName('id').AsString := TaskID;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TTestDBJobQueue.ResetNextRunAt(const TaskID: string);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET next_run_at = NULL WHERE id = :id';
      Query.ParamByName('id').AsString := TaskID;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBJobQueue.ReadNextRunAt(const TaskID: string): string;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := '';
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'SELECT next_run_at FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
      Query.ParamByName('id').AsString := TaskID;
      Query.Open;
      if not Query.Eof then
        Result := Query.Fields[0].AsString;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBJobQueue.ReadDLQRow(const OriginalID: string;
  out QueueName, LogicalKey, LastError: string; out Attempts: Integer;
  out Payload: string): Boolean;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'SELECT queue_name, logical_key, last_error, attempts, payload ' +
        'FROM DeepBase_job_queue_dlq WHERE original_id = :id';
      Query.ParamByName('id').AsString := OriginalID;
      Query.Open;
      Result := not Query.Eof;
      if Result then
      begin
        QueueName := Query.FieldByName('queue_name').AsString;
        LogicalKey := Query.FieldByName('logical_key').AsString;
        LastError := Query.FieldByName('last_error').AsString;
        Attempts := Query.FieldByName('attempts').AsInteger;
        Payload := Query.FieldByName('payload').AsString;
      end
      else
      begin
        QueueName := '';
        LogicalKey := '';
        LastError := '';
        Attempts := 0;
        Payload := '';
      end;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TTestDBJobQueue.Test_Enqueue_IsIdempotentByQueueAndLogicalKey;
var
  Payload: TJSONObject;
begin
  Payload := TJSONObject.Create;
  try
    Payload.AddPair('kind', 'demo');

    Assert.IsTrue(TJobQueue.Enqueue('default', 'task-1', Payload));
    Assert.IsFalse(TJobQueue.Enqueue('default', 'task-1', Payload));
    Assert.AreEqual(1, CountRows('default', 'pending'));
  finally
    Payload.Free;
  end;
end;

procedure TTestDBJobQueue.Test_Dequeue_ClaimsPendingTaskAndReturnsPayload;
var
  Payload: TJSONObject;
  Task: TTaskRec;
begin
  Payload := TJSONObject.Create;
  try
    Payload.AddPair('name', 'first');
    Assert.IsTrue(TJobQueue.Enqueue('default', 'task-1', Payload));
  finally
    Payload.Free;
  end;

  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    Assert.IsNotEmpty(Task.TaskID);
    Assert.AreEqual('default', Task.QueueName);
    Assert.AreEqual('task-1', Task.LogicalKey);
    Assert.AreEqual('running', Task.Status);
    Assert.AreEqual(1, Task.Attempts);
    Assert.AreEqual('first', Task.Payload.GetValue<string>('name'));
    Assert.AreEqual('running', ReadStatus(Task.TaskID));
    Assert.AreEqual(0, CountRows('default', 'pending'));
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Dequeue_DoesNotCrossQueues;
var
  Task: TTaskRec;
begin
  Assert.IsTrue(TJobQueue.Enqueue('queue-a', 'a-1', nil));
  Assert.IsTrue(TJobQueue.Enqueue('queue-b', 'b-1', nil));

  Assert.IsTrue(TJobQueue.Dequeue('queue-b', Task));
  try
    Assert.AreEqual('queue-b', Task.QueueName);
    Assert.AreEqual('b-1', Task.LogicalKey);
    Assert.AreEqual(1, CountRows('queue-a', 'pending'));
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Heartbeat_UpdatesRunningTask;
var
  Task: TTaskRec;
  BeforeHeartbeat: string;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-heartbeat', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    SetHeartbeatToPast(Task.TaskID, 120);
    BeforeHeartbeat := ReadHeartbeat(Task.TaskID);

    TJobQueue.Heartbeat(Task.TaskID);

    Assert.AreNotEqual(BeforeHeartbeat, ReadHeartbeat(Task.TaskID));
    Assert.AreEqual('running', ReadStatus(Task.TaskID));
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_RecycleDeadTasks_RequeuesStaleRunningTask;
var
  Task: TTaskRec;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-dead', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    SetHeartbeatToPast(Task.TaskID, 120);
    Assert.AreEqual(1, TJobQueue.RecycleDeadTasks('default', 60));
    Assert.AreEqual('pending', ReadStatus(Task.TaskID));
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Complete_MarksRunningTaskDone;
var
  Task: TTaskRec;
  EmptyTask: TTaskRec;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-complete', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    Assert.IsTrue(TJobQueue.Complete(Task.TaskID));
    Assert.AreEqual('done', ReadStatus(Task.TaskID));
    Assert.IsFalse(TJobQueue.Dequeue('default', EmptyTask));
  finally
    Task.Clear;
    EmptyTask.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Fail_WithRequeue_MakesTaskPendingAgain;
var
  Task: TTaskRec;
  RetriedTask: TTaskRec;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-retry', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'temporary error', True));
    Assert.AreEqual('pending', ReadStatus(Task.TaskID));
    // EXP-P1-015: Fail(Requeue=True) schedules the row with
    // next_run_at = now + backoff. Clear it so the immediate re-Dequeue
    // does not have to wait for the backoff window.
    ResetNextRunAt(Task.TaskID);
    Assert.IsTrue(TJobQueue.Dequeue('default', RetriedTask));
    try
      Assert.AreEqual(Task.TaskID, RetriedTask.TaskID);
      Assert.AreEqual(2, RetriedTask.Attempts);
    finally
      RetriedTask.Clear;
    end;
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Dequeue_RespectsNextRunAt;
var
  Task: TTaskRec;
  OutTask: TTaskRec;
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-next-run', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    // Put row back as pending with next_run_at 30s in the future.
    Conn := CreateConnection;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE +
          ' SET status = ''pending'', next_run_at = ' +
          'datetime(''now'', ''+30 seconds'') WHERE id = :id';
        Query.ParamByName('id').AsString := Task.TaskID;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    finally
      Conn.Free;
    end;

    Assert.AreEqual('pending', ReadStatus(Task.TaskID));
    Assert.IsFalse(TJobQueue.Dequeue('default', OutTask),
      'Dequeue must not pick up a row whose next_run_at is in the future');
    OutTask.Clear;

    // Move next_run_at to the past; now Dequeue should succeed.
    Conn := CreateConnection;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE +
          ' SET next_run_at = datetime(''now'', ''-10 seconds'') ' +
          'WHERE id = :id';
        Query.ParamByName('id').AsString := Task.TaskID;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    finally
      Conn.Free;
    end;

    Assert.IsTrue(TJobQueue.Dequeue('default', OutTask));
    try
      Assert.AreEqual(Task.TaskID, OutTask.TaskID);
    finally
      OutTask.Clear;
    end;
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Fail_SetsNextRunAt_ExponentialBackoff;
var
  Task: TTaskRec;
  NextRunAt1, NextRunAt2: string;

  procedure RequeueAsRunning;
  var
    C: TFDConnection;
    Q: TFDQuery;
  begin
    C := CreateConnection;
    try
      Q := TFDQuery.Create(nil);
      try
        Q.Connection := C;
        Q.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE +
          ' SET status = ''running'', next_run_at = NULL WHERE id = :id';
        Q.ParamByName('id').AsString := Task.TaskID;
        Q.ExecSQL;
      finally
        Q.Free;
      end;
    finally
      C.Free;
    end;
  end;

begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-backoff', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    // attempts = 1 -> backoff = BASE * 2^0 = 5s
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err1', True),
      'Fail(1) should succeed');
    NextRunAt1 := ReadNextRunAt(Task.TaskID);
    Assert.IsNotEmpty(NextRunAt1,
      'next_run_at must be set after Fail(Requeue=True)');

    // Sleep enough to ensure the second backoff window lands in a later
    // second than the first, so second-precision SQLite datetime strings
    // are strictly increasing.
    Sleep(1200);

    RequeueAsRunning;
    // attempts still = 1 -> backoff = 5s again; wall-clock is now >= 1.2s
    // later, so the new next_run_at > the previous next_run_at by >= 1s.
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err2', True),
      'Fail(2) should succeed; status=' + ReadStatus(Task.TaskID));
    NextRunAt2 := ReadNextRunAt(Task.TaskID);
    Assert.IsTrue(NextRunAt2 > NextRunAt1,
      Format('next_run_at must grow monotonically: [%s] > [%s]',
        [NextRunAt2, NextRunAt1]));
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Fail_ExceedsMaxRetries_TransfersToDLQ;
const
  DLQ_TABLE = 'DeepBase_job_queue_dlq';
var
  Task: TTaskRec;
  Conn: TFDConnection;
  Query: TFDQuery;
  DLQQueue, DLQKey, DLQError, DLQPayload: string;
  DLQAttempts: Integer;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-dlq', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    // 5 Fail(Requeue=True) cycles — each uses the default AMaxRetries=5.
    // Before each re-Dequeue, clear next_run_at so the row is immediately
    // available.
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err-1', True));
    ResetNextRunAt(Task.TaskID);
    Assert.IsTrue(TJobQueue.Dequeue('default', Task));
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err-2', True));
    ResetNextRunAt(Task.TaskID);
    Assert.IsTrue(TJobQueue.Dequeue('default', Task));
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err-3', True));
    ResetNextRunAt(Task.TaskID);
    Assert.IsTrue(TJobQueue.Dequeue('default', Task));
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'err-4', True));
    ResetNextRunAt(Task.TaskID);
    Assert.IsTrue(TJobQueue.Dequeue('default', Task));
    // attempts=5, AMaxRetries=5 -> this Fail moves the row to the DLQ.
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'terminal-error', True));

    // Row is gone from the main queue.
    Conn := CreateConnection;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'SELECT COUNT(*) FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
        Query.ParamByName('id').AsString := Task.TaskID;
        Query.Open;
        Assert.AreEqual<Integer>(0, Query.Fields[0].AsInteger,
          'Main-queue row must be deleted after DLQ transfer');
      finally
        Query.Free;
      end;
    finally
      Conn.Free;
    end;

    // Row is in the DLQ with the correct metadata.
    Assert.IsTrue(ReadDLQRow(Task.TaskID, DLQQueue, DLQKey, DLQError,
      DLQAttempts, DLQPayload),
      'DLQ row must exist after exceeding max retries');
    Assert.AreEqual('default', DLQQueue);
    Assert.AreEqual('task-dlq', DLQKey);
    Assert.AreEqual('terminal-error', DLQError);
    Assert.AreEqual<Integer>(5, DLQAttempts);
    Assert.AreEqual('{}', DLQPayload);
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_DeadLetterCount_FiltersByQueue;
var
  TaskA, TaskB: TTaskRec;
  Conn: TFDConnection;
  Query: TFDQuery;
  I: Integer;
begin
  // Drive two tasks into the DLQ by using the AMaxRetries=1 overload
  // (immediate DLQ transfer on first Fail).
  Assert.IsTrue(TJobQueue.Enqueue('queue-a', 'a-dlq-1', nil));
  Assert.IsTrue(TJobQueue.Dequeue('queue-a', TaskA));
  Assert.IsTrue(TJobQueue.Fail(TaskA.TaskID, 'term-a', True, 1));

  Assert.IsTrue(TJobQueue.Enqueue('queue-b', 'b-dlq-1', nil));
  Assert.IsTrue(TJobQueue.Dequeue('queue-b', TaskB));
  Assert.IsTrue(TJobQueue.Fail(TaskB.TaskID, 'term-b', True, 1));

  // Add two more DLQ entries in queue-a by direct INSERT for counting.
  Conn := CreateConnection;
  try
    for I := 2 to 3 do
    begin
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'INSERT INTO DeepBase_job_queue_dlq ' +
          '(original_id, queue_name, logical_key, payload, attempts, ' +
          ' last_error, created_at, moved_at) ' +
          'VALUES (:id, ''queue-a'', ''a-extra-' + IntToStr(I) + ''', ' +
          '''{}'', 5, ''err'', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';
        Query.ParamByName('id').AsString := 'a-extra-' + IntToStr(I);
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    end;
  finally
    Conn.Free;
  end;

  Assert.AreEqual<Integer>(3, TJobQueue.DeadLetterCount('queue-a'));
  Assert.AreEqual<Integer>(1, TJobQueue.DeadLetterCount('queue-b'));
  Assert.AreEqual<Integer>(4, TJobQueue.DeadLetterCount(''));

  TaskA.Clear;
  TaskB.Clear;
end;

procedure TTestDBJobQueue.Test_PeekDeadLetters_RespectsLimitAndQueue;
var
  Conn: TFDConnection;
  Query: TFDQuery;
  I: Integer;
  Peeked: TArray<TDeadLetterRec>;
  SeenB: TStringList;
  SeenGlobal: TStringList;
begin
  // Insert test data into the DLQ via a helper connection (not the pool).
  // Use distinct moved_at values across both queues so the ORDER BY
  // moved_at DESC is unambiguous:
  //   queue-a: now - 1s .. now - 5s (the newest 5 rows in the DLQ)
  //   queue-b: now - 100s .. now - 101s (older)
  Conn := CreateConnection;
  try
    for I := 1 to 5 do
    begin
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'INSERT INTO DeepBase_job_queue_dlq ' +
          '(original_id, queue_name, logical_key, payload, attempts, ' +
          ' last_error, created_at, moved_at) ' +
          'VALUES (:id, ''queue-a'', ''lk-' + IntToStr(I) + ''', ' +
          '''{}'', 5, ''err-' + IntToStr(I) + ''', ' +
          'datetime(''now'', ''-' + IntToStr(I) + ' seconds''), ' +
          'datetime(''now'', ''-' + IntToStr(I) + ' seconds''))';
        Query.ParamByName('id').AsString := 'a-peek-' + IntToStr(I);
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    end;
    for I := 1 to 2 do
    begin
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'INSERT INTO DeepBase_job_queue_dlq ' +
          '(original_id, queue_name, logical_key, payload, attempts, ' +
          ' last_error, created_at, moved_at) ' +
          'VALUES (:id, ''queue-b'', ''lk-b-' + IntToStr(I) + ''', ' +
          '''{}'', 5, ''err-b-' + IntToStr(I) + ''', ' +
          'datetime(''now'', ''-' + IntToStr(100 + I) + ' seconds''), ' +
          'datetime(''now'', ''-' + IntToStr(100 + I) + ' seconds''))';
        Query.ParamByName('id').AsString := 'b-peek-' + IntToStr(I);
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    end;
  finally
    Conn.Free;
  end;

  // Force the pool to refresh its view of the DLQ table.
  TJobQueue.EnsureSchema;

  Peeked := TJobQueue.PeekDeadLetters('queue-a', 2);
  Assert.AreEqual<Integer>(2, Length(Peeked), 'queue-a peek must respect limit');
  Assert.AreEqual('queue-a', Peeked[0].QueueName);
  Assert.AreEqual('queue-a', Peeked[1].QueueName);
  // Descending by moved_at — the newest (a-peek-1, now - 1s) comes first,
  // then a-peek-2 (now - 2s).
  Assert.AreEqual('a-peek-1', Peeked[0].OriginalID);
  Assert.AreEqual('a-peek-2', Peeked[1].OriginalID);

  Peeked := TJobQueue.PeekDeadLetters('queue-b', 10);
  Assert.AreEqual<Integer>(2, Length(Peeked),
    'queue-b peek must return only the rows belonging to queue-b');
  SeenB := TStringList.Create;
  try
    for I := 0 to Length(Peeked) - 1 do
    begin
      Assert.AreEqual('queue-b', Peeked[I].QueueName);
      SeenB.Add(Peeked[I].OriginalID);
    end;
    SeenB.Sort;
    Assert.AreEqual('b-peek-1' + sLineBreak + 'b-peek-2', SeenB.Text.Trim);
  finally
    SeenB.Free;
  end;

  // Global peek with Limit=3 should return the 3 newest rows across all
  // queues — which, given our timestamp layout, are all from queue-a.
  Peeked := TJobQueue.PeekDeadLetters('', 3);
  Assert.AreEqual<Integer>(3, Length(Peeked),
    'empty-queue peek must cap at the global Limit');
  SeenGlobal := TStringList.Create;
  try
    for I := 0 to Length(Peeked) - 1 do
      SeenGlobal.Add(Peeked[I].OriginalID);
    SeenGlobal.Sort;
    Assert.AreEqual('a-peek-1' + sLineBreak + 'a-peek-2' + sLineBreak + 'a-peek-3',
      SeenGlobal.Text.Trim,
      'empty-queue peek with Limit=3 should return the 3 newest rows');
  finally
    SeenGlobal.Free;
  end;
end;

procedure TTestDBJobQueue.Test_ReplayDeadLetter_MovesBackToMainPending;
var
  Task: TTaskRec;
  OutTask: TTaskRec;
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  // Set up a row in the DLQ by direct SQL — this keeps the test focused on
  // ReplayDeadLetter's behaviour without depending on the Fail method's
  // DLQ-transfer code path (which is exercised separately).
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-replay', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    // Remove the running row from the main queue and insert the equivalent
    // row into the DLQ (mimics what Fail does when max retries is reached).
    Conn := CreateConnection;
    try
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'DELETE FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
        Query.ParamByName('id').AsString := Task.TaskID;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Conn;
        Query.SQL.Text :=
          'INSERT INTO DeepBase_job_queue_dlq ' +
          '(original_id, queue_name, logical_key, payload, attempts, ' +
          ' last_error, created_at, moved_at) ' +
          'VALUES (:id, ''default'', ''task-replay'', ''{}'', 5, ' +
          '''replay-err'', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';
        Query.ParamByName('id').AsString := Task.TaskID;
        Query.ExecSQL;
      finally
        Query.Free;
      end;
    finally
      Conn.Free;
    end;

    Assert.AreEqual<Integer>(1, TJobQueue.DeadLetterCount(''));

    Assert.IsTrue(TJobQueue.ReplayDeadLetter(Task.TaskID),
      'Replay must succeed for a known DLQ row');

    // DLQ row gone; main-queue row back as 'pending' with NULL next_run_at.
    Assert.AreEqual<Integer>(0, TJobQueue.DeadLetterCount(''));
    Assert.AreEqual('pending', ReadStatus(Task.TaskID));
    Assert.IsEmpty(ReadNextRunAt(Task.TaskID),
      'next_run_at must be cleared after replay');

    Assert.IsTrue(TJobQueue.Dequeue('default', OutTask));
    try
      Assert.AreEqual(Task.TaskID, OutTask.TaskID);
      // Dequeue bumps attempts from 0 (reset by Replay) to 1.
      Assert.AreEqual<Integer>(1, OutTask.Attempts);
    finally
      OutTask.Clear;
    end;

    Assert.IsFalse(TJobQueue.ReplayDeadLetter(Task.TaskID),
      'Second replay must report False — the DLQ row is gone');
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_PurgeDeadLetter_RemovesRow;
var
  Task: TTaskRec;
begin
  Assert.IsTrue(TJobQueue.Enqueue('default', 'task-purge', nil));
  Assert.IsTrue(TJobQueue.Dequeue('default', Task));
  try
    Assert.IsTrue(TJobQueue.Fail(Task.TaskID, 'purge-err', True, 1));
    Assert.AreEqual<Integer>(1, TJobQueue.DeadLetterCount(''));

    Assert.IsTrue(TJobQueue.PurgeDeadLetter(Task.TaskID),
      'Purge must return True for a known DLQ row');
    Assert.AreEqual<Integer>(0, TJobQueue.DeadLetterCount(''));

    Assert.IsFalse(TJobQueue.PurgeDeadLetter(Task.TaskID),
      'Purge on an already-purged id must return False');
  finally
    Task.Clear;
  end;
end;

procedure TTestDBJobQueue.Test_Dequeue_EmptyQueueReturnsFalse;
var
  Task: TTaskRec;
begin
  Assert.IsFalse(TJobQueue.Dequeue('empty', Task));
  Task.Clear;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBJobQueue);

end.
