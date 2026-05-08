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
    procedure Test_Dequeue_EmptyQueueReturnsFalse;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.JSON,
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
