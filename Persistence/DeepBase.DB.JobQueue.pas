unit DeepBase.DB.JobQueue;

interface

uses
  System.SysUtils,
  System.JSON,
  System.SyncObjs,
  FireDAC.Comp.Client;

const
  JOB_QUEUE_POOL_SIZE = 4;

type
  TTaskRec = record
    TaskID: string;
    QueueName: string;
    LogicalKey: string;
    Payload: TJSONObject;
    Status: string;
    Attempts: Integer;
    LastError: string;
    procedure Clear;
  end;

  /// <summary>
  /// Dead-letter record moved out of the hot-path queue after exhausting
  /// its retry budget. EXP-P1-015.
  /// </summary>
  TDeadLetterRec = record
    OriginalID: string;
    QueueName: string;
    LogicalKey: string;
    Payload: TJSONObject;
    Attempts: Integer;
    LastError: string;
    CreatedAt: TDateTime;
    MovedAt: TDateTime;
    procedure Clear;
  end;

  TJobQueue = class
  private
    class var FConnectionProvider: TFunc<TFDConnection>;
    class var FAutoEnsureSchema: Boolean;
    class var FSchemaEnsured: Boolean;
    class var FLock: TCriticalSection;
    // Connection pool: POOL_SIZE TFDConnection slots. Acquire scans for a
    // free slot, marks it in-use, and returns immediately — the lock is
    // NOT held during the DB operation, so up to POOL_SIZE operations can
    // proceed concurrently on separate connections.
    class var FConnections: array[0..JOB_QUEUE_POOL_SIZE - 1] of TFDConnection;
    class var FConnInUse: array[0..JOB_QUEUE_POOL_SIZE - 1] of Boolean;
    class var FConnLock: TCriticalSection;
    class var FConnAvailableEvent: TEvent;
    class var FResetRequested: Boolean;

    class function AcquireConnection: TFDConnection; static;
    class procedure ReleaseConnection(AConnection: TFDConnection); static;
    class procedure ResetCachedConnection; static;
    class function CreateTaskID: string; static;
    class function IsPostgreSQL(Connection: TFDConnection): Boolean; static;
    class function IsSQLite(Connection: TFDConnection): Boolean; static;
    class function PayloadToText(Payload: TJSONObject): string; static;
    class function ParsePayload(const PayloadText: string): TJSONObject; static;
    class procedure ValidateQueueName(const QueueName: string); static;
    class procedure ValidateLogicalKey(const LogicalKey: string); static;
    class procedure ValidateTaskID(const TaskID: string); static;
    class procedure EnsureSchemaIfNeeded; static;
    class procedure EnsureSchemaOnConnection(Connection: TFDConnection); static;
    class procedure LoadTaskFromQuery(Query: TFDQuery; out Task: TTaskRec); static;
    class procedure LoadDeadLetterFromQuery(Query: TFDQuery;
      out Rec: TDeadLetterRec); static;
    class function DequeuePostgreSQL(Connection: TFDConnection;
      const QueueName: string; out Task: TTaskRec): Boolean; static;
    class function DequeueSQLite(Connection: TFDConnection;
      const QueueName: string; out Task: TTaskRec): Boolean; static;
    class function ComputeBackoffSeconds(Attempts: Integer): Integer; static;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure SetConnectionProvider(const Provider: TFunc<TFDConnection>); static;
    class procedure Clear; static;
    class procedure SetAutoEnsureSchema(Value: Boolean); static;
    class procedure EnsureSchema; static;

    class function Enqueue(const QueueName, LogicalKey: string;
      Payload: TJSONObject): Boolean; static;
    class function Dequeue(const QueueName: string;
      out Task: TTaskRec): Boolean; static;
    class procedure Heartbeat(const TaskID: string); static;
    class function RecycleDeadTasks(const QueueName: string;
      TimeoutSec: Integer; AMaxAttempts: Integer = 0): Integer; static;
    class function Complete(const TaskID: string): Boolean; static;
    /// <summary>
    /// Mark a running task as failed. When <c>ARequeue = True</c> the task is
    /// scheduled for retry with exponential backoff (<c>next_run_at</c> set to
    /// now + min(<c>BASE * 2^(attempts-1)</c>, <c>CAP</c>)); when the number
    /// of previous attempts reaches <c>AMaxRetries</c> (default
    /// <c>DEFAULT_JOB_MAX_RETRIES</c> = 5) the row is atomically moved to
    /// the dedicated dead-letter table <c>DeepBase_job_queue_dlq</c> so the
    /// hot-path queue stays small.
    /// </summary>
    /// <remarks>BUG EXP-P1-015.</remarks>
    class function Fail(const TaskID, ErrorMessage: string;
      Requeue: Boolean = False): Boolean; overload; static;
    class function Fail(const TaskID, ErrorMessage: string;
      Requeue: Boolean; AMaxRetries: Integer): Boolean; overload; static;

    /// <summary>Count of rows in the dead-letter table; optional queue filter.</summary>
    class function DeadLetterCount(const QueueName: string = ''): Integer; static;
    /// <summary>
    /// Return up to <c>Limit</c> dead-letter records ordered by most recently
    /// moved first. Empty <c>QueueName</c> means all queues.
    /// </summary>
    class function PeekDeadLetters(const QueueName: string;
      Limit: Integer): TArray<TDeadLetterRec>; static;
    /// <summary>
    /// Copy a dead-letter row back into the main queue as <c>pending</c> with
    /// <c>next_run_at = NULL</c> and <c>attempts = 0</c>; the DLQ row is then
    /// removed. Returns False if the original ID is not in the DLQ.
    /// </summary>
    class function ReplayDeadLetter(const OriginalID: string): Boolean; static;
    /// <summary>
    /// Permanently remove a dead-letter row by its original task ID. Returns
    /// False if no matching DLQ row existed.
    /// </summary>
    class function PurgeDeadLetter(const OriginalID: string): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.TimeSpan,
  FireDAC.Stan.Param,
  DeepBase.DB.Factory,
  DeepBase.Exceptions;

const
  JOB_QUEUE_TABLE = 'DeepBase_job_queue';
  JOB_QUEUE_DLQ_TABLE = 'DeepBase_job_queue_dlq';
  CONN_ACQUIRE_TIMEOUT_MS = 30000;
  CONN_ACQUIRE_MAX_RETRIES = 10;
  // BUG EXP-P1-015: max retry attempts before a task is diverted to the DLQ
  // table by TJobQueue.Fail(..., Requeue=True). Callers can override per call
  // via the AMaxRetries overload.
  DEFAULT_JOB_MAX_RETRIES = 5;
  // EXP-P1-015: exponential backoff parameters. delay(attempts) =
  // min(BASE * 2^(attempts-1), CAP). With BASE=5, CAP=300, the ladder is
  // 5s / 10s / 20s / 40s / 80s for attempts 1..5.
  JOB_QUEUE_BACKOFF_BASE_SEC = 5;
  JOB_QUEUE_BACKOFF_CAP_SEC = 300;

{ TTaskRec }

procedure TTaskRec.Clear;
begin
  TaskID := '';
  QueueName := '';
  LogicalKey := '';
  // EXP-P1-015: do NOT free Payload here — records are value types and copies
  // share the same TJSONObject reference. Callers that need to release the
  // payload should FreeAndNil the record's Payload field explicitly.
  Payload := nil;
  Status := '';
  Attempts := 0;
  LastError := '';
end;

procedure TDeadLetterRec.Clear;
begin
  OriginalID := '';
  QueueName := '';
  LogicalKey := '';
  // EXP-P1-015: same ownership rule as TTaskRec.Clear — leave the Payload
  // reference intact so copies don't double-free.
  Payload := nil;
  Attempts := 0;
  LastError := '';
  CreatedAt := 0;
  MovedAt := 0;
end;

{ TJobQueue }

class constructor TJobQueue.Create;
var
  I: Integer;
begin
  FLock := TCriticalSection.Create;
  FConnLock := TCriticalSection.Create;
  FConnAvailableEvent := TEvent.Create(nil, False, False, '');
  FAutoEnsureSchema := True;
  FSchemaEnsured := False;
  FResetRequested := False;
  for I := 0 to JOB_QUEUE_POOL_SIZE - 1 do
  begin
    FConnections[I] := nil;
    FConnInUse[I] := False;
  end;
end;

class destructor TJobQueue.Destroy;
begin
  ResetCachedConnection;
  FreeAndNil(FConnAvailableEvent);
  FreeAndNil(FConnLock);
  FreeAndNil(FLock);
end;

class procedure TJobQueue.SetConnectionProvider(
  const Provider: TFunc<TFDConnection>);
begin
  // Provider change invalidates pooled connections; reset the pool so
  // idle connections are freed and in-use ones are freed on release.
  ResetCachedConnection;
  FLock.Enter;
  try
    FConnectionProvider := Provider;
    FSchemaEnsured := False;
  finally
    FLock.Leave;
  end;
end;

class procedure TJobQueue.Clear;
begin
  ResetCachedConnection;
  FLock.Enter;
  try
    FConnectionProvider := nil;
    FAutoEnsureSchema := True;
    FSchemaEnsured := False;
  finally
    FLock.Leave;
  end;
end;

class procedure TJobQueue.SetAutoEnsureSchema(Value: Boolean);
begin
  FLock.Enter;
  try
    FAutoEnsureSchema := Value;
    if not Value then
      FSchemaEnsured := False;
  finally
    FLock.Leave;
  end;
end;

class function TJobQueue.AcquireConnection: TFDConnection;
var
  Provider: TFunc<TFDConnection>;
  I: Integer;
  RetryCount: Integer;
  Found: Boolean;
begin
  Result := nil;
  // Scan the pool for a free slot. The connection lock is held only while
  // claiming a slot — the actual DB work happens outside the lock so up
  // to POOL_SIZE operations can proceed concurrently.
  RetryCount := 0;
  while True do
  begin
    Found := False;
    FConnLock.Enter;
    try
      for I := 0 to JOB_QUEUE_POOL_SIZE - 1 do
      begin
        if not FConnInUse[I] then
        begin
          // Found a free slot — ensure the connection is usable.
          if Assigned(FConnections[I]) then
          begin
            // A connection that lost its session (e.g. server restarted)
            // is dropped so we recreate cleanly below.
            if not FConnections[I].Connected then
            try
              FConnections[I].Open;
            except
              FreeAndNil(FConnections[I]);
            end;
          end;

          if not Assigned(FConnections[I]) then
          begin
            FLock.Enter;
            try
              Provider := FConnectionProvider;
            finally
              FLock.Leave;
            end;

            if Assigned(Provider) then
              FConnections[I] := Provider()
            else
              FConnections[I] := TDBConnectionFactory.GetShared;

            if not Assigned(FConnections[I]) then
              raise EDatabaseException.Create(
                'Job queue connection provider returned nil');
          end;

          FConnInUse[I] := True;
          Result := FConnections[I];
          Found := True;
          Break;
        end;
      end;
    finally
      FConnLock.Leave;
    end;

    if Found then
      Exit;

    // All slots are in use — wait for a release signal and retry.
    Inc(RetryCount);
    if RetryCount > CONN_ACQUIRE_MAX_RETRIES then
      raise EDatabaseException.Create(
        'Job queue connection pool exhausted');

    FConnAvailableEvent.WaitFor(CONN_ACQUIRE_TIMEOUT_MS);
  end;
end;

class procedure TJobQueue.ReleaseConnection(AConnection: TFDConnection);
var
  I, J: Integer;
  Found: Boolean;
  AllNil: Boolean;
begin
  // Return the connection to its pool slot. If a pool reset was requested
  // (SetConnectionProvider / Clear), free the connection instead so the
  // pool is fully drained once all in-flight operations complete.
  FConnLock.Enter;
  try
    Found := False;
    for I := 0 to JOB_QUEUE_POOL_SIZE - 1 do
    begin
      if FConnections[I] = AConnection then
      begin
        FConnInUse[I] := False;
        if FResetRequested then
        begin
          FreeAndNil(FConnections[I]);
          // When every slot has been drained, clear the reset flag so
          // subsequent AcquireConnection calls rebuild the pool.
          AllNil := True;
          for J := 0 to JOB_QUEUE_POOL_SIZE - 1 do
          begin
            if FConnections[J] <> nil then
            begin
              AllNil := False;
              Break;
            end;
          end;
          if AllNil then
            FResetRequested := False;
        end;
        Found := True;
        Break;
      end;
    end;
    if Found then
      FConnAvailableEvent.SetEvent;
  finally
    FConnLock.Leave;
  end;

  // Connection not found in the pool — orphan from a provider change.
  // Free it here to avoid a leak.
  if (not Found) and Assigned(AConnection) then
    AConnection.Free;
end;

class procedure TJobQueue.ResetCachedConnection;
var
  I: Integer;
begin
  // Free all idle connections immediately. In-use connections will be
  // freed by ReleaseConnection when the owning operation completes (the
  // FResetRequested flag tells ReleaseConnection to free rather than
  // return the slot to the pool).
  FConnLock.Enter;
  try
    for I := 0 to JOB_QUEUE_POOL_SIZE - 1 do
    begin
      if not FConnInUse[I] then
        FreeAndNil(FConnections[I]);
    end;
    FResetRequested := True;
  finally
    FConnLock.Leave;
  end;
end;

class function TJobQueue.CreateTaskID: string;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  Result := LowerCase(GuidText);
end;

class function TJobQueue.IsPostgreSQL(Connection: TFDConnection): Boolean;
begin
  Result := Assigned(Connection) and
    (SameText(Connection.DriverName, 'PG') or SameText(Connection.DriverName, 'PostgreSQL'));
end;

class function TJobQueue.IsSQLite(Connection: TFDConnection): Boolean;
begin
  Result := Assigned(Connection) and SameText(Connection.DriverName, 'SQLite');
end;

class procedure TJobQueue.ValidateQueueName(const QueueName: string);
begin
  if Trim(QueueName) = '' then
    raise EInvalidOperationException.Create('QueueName cannot be empty');
end;

class procedure TJobQueue.ValidateLogicalKey(const LogicalKey: string);
begin
  if Trim(LogicalKey) = '' then
    raise EInvalidOperationException.Create('LogicalKey cannot be empty');
end;

class procedure TJobQueue.ValidateTaskID(const TaskID: string);
begin
  if Trim(TaskID) = '' then
    raise EInvalidOperationException.Create('TaskID cannot be empty');
end;

class function TJobQueue.PayloadToText(Payload: TJSONObject): string;
begin
  if Assigned(Payload) then
    Result := Payload.ToJSON
  else
    Result := '{}';
end;

class function TJobQueue.ParsePayload(const PayloadText: string): TJSONObject;
var
  Value: TJSONValue;
begin
  Result := nil;
  Value := nil;
  if Trim(PayloadText) <> '' then
    Value := TJSONObject.ParseJSONValue(PayloadText);

  if Value is TJSONObject then
    Exit(TJSONObject(Value));

  Value.Free;
  Result := TJSONObject.Create;
end;

class procedure TJobQueue.EnsureSchemaIfNeeded;
var
  AutoEnsure: Boolean;
  SchemaEnsured: Boolean;
begin
  FLock.Enter;
  try
    AutoEnsure := FAutoEnsureSchema;
    SchemaEnsured := FSchemaEnsured;
  finally
    FLock.Leave;
  end;

  if (not AutoEnsure) or SchemaEnsured then
    Exit;

  EnsureSchema;
end;

class procedure TJobQueue.EnsureSchema;
var
  Connection: TFDConnection;
begin
  Connection := AcquireConnection;
  try
    EnsureSchemaOnConnection(Connection);
  finally
    ReleaseConnection(Connection);
  end;

  FLock.Enter;
  try
    FSchemaEnsured := True;
  finally
    FLock.Leave;
  end;
end;

class procedure TJobQueue.EnsureSchemaOnConnection(Connection: TFDConnection);
var
  CheckQ: TFDQuery;
  HasNextRunAt: Boolean;
begin
  if IsPostgreSQL(Connection) then
  begin
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + JOB_QUEUE_TABLE + ' (' +
      'id TEXT PRIMARY KEY, ' +
      'queue_name TEXT NOT NULL, ' +
      'logical_key TEXT NOT NULL, ' +
      'payload JSONB NOT NULL DEFAULT CAST(''{}'' AS jsonb), ' +
      'status TEXT NOT NULL, ' +
      'attempts INTEGER NOT NULL DEFAULT 0, ' +
      'last_error TEXT, ' +
      'created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'dequeued_at TIMESTAMP NULL, ' +
      'heartbeat_at TIMESTAMP NULL, ' +
      'next_run_at TIMESTAMP NULL)');
    // EXP-P1-015: idempotent column upgrade for pre-existing tables.
    Connection.ExecSQL(
      'ALTER TABLE ' + JOB_QUEUE_TABLE +
      ' ADD COLUMN IF NOT EXISTS next_run_at TIMESTAMP NULL');
    // EXP-P1-015: dead-letter table.
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + JOB_QUEUE_DLQ_TABLE + ' (' +
      'original_id TEXT PRIMARY KEY, ' +
      'queue_name TEXT NOT NULL, ' +
      'logical_key TEXT NOT NULL, ' +
      'payload JSONB NOT NULL DEFAULT CAST(''{}'' AS jsonb), ' +
      'attempts INTEGER NOT NULL DEFAULT 0, ' +
      'last_error TEXT, ' +
      'created_at TIMESTAMP NOT NULL, ' +
      'moved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)');
  end
  else if IsSQLite(Connection) then
  begin
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + JOB_QUEUE_TABLE + ' (' +
      'id TEXT PRIMARY KEY, ' +
      'queue_name TEXT NOT NULL, ' +
      'logical_key TEXT NOT NULL, ' +
      'payload TEXT NOT NULL DEFAULT ''{}'', ' +
      'status TEXT NOT NULL, ' +
      'attempts INTEGER NOT NULL DEFAULT 0, ' +
      'last_error TEXT, ' +
      'created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
      'dequeued_at TEXT, ' +
      'heartbeat_at TEXT, ' +
      'next_run_at TEXT)');
    // EXP-P1-015: SQLite lacks "ADD COLUMN IF NOT EXISTS". Probe via
    // pragma_table_info and only ALTER when the column is absent.
    CheckQ := TFDQuery.Create(nil);
    try
      CheckQ.Connection := Connection;
      CheckQ.SQL.Text :=
        'SELECT 1 FROM pragma_table_info(''' + JOB_QUEUE_TABLE +
        ''') WHERE name = ''next_run_at''';
      CheckQ.Open;
      HasNextRunAt := not CheckQ.Eof;
    finally
      CheckQ.Free;
    end;
    if not HasNextRunAt then
      Connection.ExecSQL(
        'ALTER TABLE ' + JOB_QUEUE_TABLE + ' ADD COLUMN next_run_at TEXT');
    // EXP-P1-015: dead-letter table.
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + JOB_QUEUE_DLQ_TABLE + ' (' +
      'original_id TEXT PRIMARY KEY, ' +
      'queue_name TEXT NOT NULL, ' +
      'logical_key TEXT NOT NULL, ' +
      'payload TEXT NOT NULL DEFAULT ''{}'', ' +
      'attempts INTEGER NOT NULL DEFAULT 0, ' +
      'last_error TEXT, ' +
      'created_at TEXT NOT NULL, ' +
      'moved_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
  end
  else
    raise EDatabaseException.Create('Job queue supports SQLite and PostgreSQL only');

  Connection.ExecSQL(
    'CREATE UNIQUE INDEX IF NOT EXISTS ux_DeepBase_job_queue_logical ' +
    'ON ' + JOB_QUEUE_TABLE + ' (queue_name, logical_key)');
  Connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_DeepBase_job_queue_pending ' +
    'ON ' + JOB_QUEUE_TABLE + ' (queue_name, status, next_run_at, created_at)');
end;

class function TJobQueue.Enqueue(const QueueName, LogicalKey: string;
  Payload: TJSONObject): Boolean;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  ValidateQueueName(QueueName);
  ValidateLogicalKey(LogicalKey);
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      if IsPostgreSQL(Connection) then
        Query.SQL.Text :=
          'INSERT INTO ' + JOB_QUEUE_TABLE + ' ' +
          '(id, queue_name, logical_key, payload, status, created_at, updated_at) ' +
          'VALUES (:id, :queue_name, :logical_key, CAST(:payload AS jsonb), ' +
          '''pending'', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) ' +
          'ON CONFLICT (queue_name, logical_key) DO NOTHING'
      else
        Query.SQL.Text :=
          'INSERT OR IGNORE INTO ' + JOB_QUEUE_TABLE + ' ' +
          '(id, queue_name, logical_key, payload, status, created_at, updated_at) ' +
          'VALUES (:id, :queue_name, :logical_key, :payload, ' +
          '''pending'', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)';

      Query.ParamByName('id').AsString := CreateTaskID;
      Query.ParamByName('queue_name').AsString := QueueName;
      Query.ParamByName('logical_key').AsString := LogicalKey;
      Query.ParamByName('payload').AsString := PayloadToText(Payload);
      Query.ExecSQL;
      Result := Query.RowsAffected > 0;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class procedure TJobQueue.LoadTaskFromQuery(Query: TFDQuery;
  out Task: TTaskRec);
begin
  Task.TaskID := Query.FieldByName('id').AsString;
  Task.QueueName := Query.FieldByName('queue_name').AsString;
  Task.LogicalKey := Query.FieldByName('logical_key').AsString;
  Task.Payload := ParsePayload(Query.FieldByName('payload').AsString);
  Task.Status := Query.FieldByName('status').AsString;
  Task.Attempts := Query.FieldByName('attempts').AsInteger;
  Task.LastError := Query.FieldByName('last_error').AsString;
end;

class function TJobQueue.DequeuePostgreSQL(Connection: TFDConnection;
  const QueueName: string; out Task: TTaskRec): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text :=
      'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
      'status = ''running'', attempts = attempts + 1, last_error = NULL, ' +
      'dequeued_at = CURRENT_TIMESTAMP, heartbeat_at = CURRENT_TIMESTAMP, ' +
      'updated_at = CURRENT_TIMESTAMP, next_run_at = NULL ' +
      'WHERE id = (' +
      '  SELECT id FROM ' + JOB_QUEUE_TABLE + ' ' +
      '  WHERE queue_name = :queue_name AND status = ''pending'' ' +
      '    AND (next_run_at IS NULL OR next_run_at <= CURRENT_TIMESTAMP) ' +
      '  ORDER BY created_at, id ' +
      '  LIMIT 1 ' +
      // CR-003: PostgreSQL 要求锁定子句位于 LIMIT/OFFSET 之后
      '  FOR UPDATE SKIP LOCKED' +
      ') ' +
      'RETURNING id, queue_name, logical_key, payload, status, attempts, last_error';
    Query.ParamByName('queue_name').AsString := QueueName;
    Query.Open;
    if Query.Eof then
      Exit(False);

    LoadTaskFromQuery(Query, Task);
    Result := True;
  finally
    Query.Free;
  end;
end;

class function TJobQueue.DequeueSQLite(Connection: TFDConnection;
  const QueueName: string; out Task: TTaskRec): Boolean;
var
  SelectQuery: TFDQuery;
  UpdateQuery: TFDQuery;
  TaskID: string;
  OwnTransaction: Boolean;
begin
  Result := False;
  OwnTransaction := not Connection.InTransaction;
  if OwnTransaction then
    Connection.StartTransaction;
  try
    SelectQuery := TFDQuery.Create(nil);
    try
      SelectQuery.Connection := Connection;
      SelectQuery.SQL.Text :=
        'SELECT id FROM ' + JOB_QUEUE_TABLE + ' ' +
        'WHERE queue_name = :queue_name AND status = ''pending'' ' +
        '  AND (next_run_at IS NULL OR next_run_at <= datetime(''now'')) ' +
        'ORDER BY created_at, id LIMIT 1';
      SelectQuery.ParamByName('queue_name').AsString := QueueName;
      SelectQuery.Open;
      if SelectQuery.Eof then
      begin
        if OwnTransaction then
          Connection.Commit;
        Exit(False);
      end;
      TaskID := SelectQuery.FieldByName('id').AsString;
    finally
      SelectQuery.Free;
    end;

    UpdateQuery := TFDQuery.Create(nil);
    try
      UpdateQuery.Connection := Connection;
      UpdateQuery.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
        'status = ''running'', attempts = attempts + 1, last_error = NULL, ' +
        'dequeued_at = CURRENT_TIMESTAMP, heartbeat_at = CURRENT_TIMESTAMP, ' +
        'updated_at = CURRENT_TIMESTAMP, next_run_at = NULL ' +
        'WHERE id = :id AND status = ''pending''';
      UpdateQuery.ParamByName('id').AsString := TaskID;
      UpdateQuery.ExecSQL;
      if UpdateQuery.RowsAffected = 0 then
      begin
        if OwnTransaction then
          Connection.Commit;
        Exit(False);
      end;

      UpdateQuery.SQL.Text :=
        'SELECT id, queue_name, logical_key, payload, status, attempts, last_error ' +
        'FROM ' + JOB_QUEUE_TABLE + ' WHERE id = :id';
      UpdateQuery.ParamByName('id').AsString := TaskID;
      UpdateQuery.Open;
      if not UpdateQuery.Eof then
      begin
        LoadTaskFromQuery(UpdateQuery, Task);
        Result := True;
      end;
    finally
      UpdateQuery.Free;
    end;

    if OwnTransaction then
      Connection.Commit;
  except
    if OwnTransaction and Connection.InTransaction then
      Connection.Rollback;
    raise;
  end;
end;

class function TJobQueue.Dequeue(const QueueName: string;
  out Task: TTaskRec): Boolean;
var
  Connection: TFDConnection;
begin
  ValidateQueueName(QueueName);
  EnsureSchemaIfNeeded;
  Task.TaskID := '';
  Task.QueueName := '';
  Task.LogicalKey := '';
  Task.Payload := nil;
  Task.Status := '';
  Task.Attempts := 0;
  Task.LastError := '';

  Connection := AcquireConnection;
  try
    if IsPostgreSQL(Connection) then
      Result := DequeuePostgreSQL(Connection, QueueName, Task)
    else if IsSQLite(Connection) then
      Result := DequeueSQLite(Connection, QueueName, Task)
    else
      raise EDatabaseException.Create('Job queue supports SQLite and PostgreSQL only');
  finally
    ReleaseConnection(Connection);
  end;
end;

class procedure TJobQueue.Heartbeat(const TaskID: string);
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  ValidateTaskID(TaskID);
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
        'heartbeat_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP ' +
        'WHERE id = :id AND status = ''running''';
      Query.ParamByName('id').AsString := TaskID;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.RecycleDeadTasks(const QueueName: string;
  TimeoutSec: Integer; AMaxAttempts: Integer): Integer;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  HBCond: string;
  OwnTx: Boolean;
begin
  ValidateQueueName(QueueName);
  if TimeoutSec <= 0 then
    raise EInvalidOperationException.Create('TimeoutSec must be greater than zero');
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    // CR-232: 心跳超时谓词按方言构造，供"进 DLQ"与"重新入队"两步复用
    if IsPostgreSQL(Connection) then
      HBCond := 'AND heartbeat_at < (CURRENT_TIMESTAMP - (:timeout_sec * INTERVAL ''1 second''))'
    else
      HBCond := 'AND heartbeat_at < datetime(''now'', ''-'' || :timeout_sec || '' seconds'')';

    // ── 第一步（CR-232）：达到重试上限仍超时的毒丸任务直接迁入 DLQ，
    //    不再无条件回 pending 无限循环烧 attempts 预算。
    //    AMaxAttempts <= 0 保持旧行为（不启用毒丸识别）。
    if AMaxAttempts > 0 then
    begin
      OwnTx := False;
      if not Connection.InTransaction then
      begin
        Connection.StartTransaction;
        OwnTx := True;
      end;
      Query := TFDQuery.Create(nil);
      try
        try
          Query.Connection := Connection;
          Query.SQL.Text :=
            'INSERT INTO ' + JOB_QUEUE_DLQ_TABLE + ' ' +
            '(original_id, queue_name, logical_key, payload, attempts, ' +
            ' last_error, created_at, moved_at) ' +
            'SELECT id, queue_name, logical_key, payload, attempts, ' +
            '       ''recycle: attempts exhausted (poison pill)'', created_at, CURRENT_TIMESTAMP ' +
            'FROM ' + JOB_QUEUE_TABLE +
            ' WHERE queue_name = :queue_name AND status = ''running'' ' +
            'AND attempts >= :max_attempts ' + HBCond;
          Query.ParamByName('queue_name').AsString := QueueName;
          Query.ParamByName('timeout_sec').AsInteger := TimeoutSec;
          Query.ParamByName('max_attempts').AsInteger := AMaxAttempts;
          Query.ExecSQL;

          Query.SQL.Text :=
            'DELETE FROM ' + JOB_QUEUE_TABLE +
            ' WHERE queue_name = :queue_name AND status = ''running'' ' +
            'AND attempts >= :max_attempts ' + HBCond;
          Query.ParamByName('queue_name').AsString := QueueName;
          Query.ParamByName('timeout_sec').AsInteger := TimeoutSec;
          Query.ParamByName('max_attempts').AsInteger := AMaxAttempts;
          Query.ExecSQL;

          if OwnTx then
            Connection.Commit;
        except
          if OwnTx then
            Connection.Rollback;
          raise;
        end;
      finally
        Query.Free;
      end;
    end;

    // ── 第二步：其余超时任务照旧回 pending 重投
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
        'status = ''pending'', dequeued_at = NULL, heartbeat_at = NULL, ' +
        'next_run_at = NULL, updated_at = CURRENT_TIMESTAMP ' +
        'WHERE queue_name = :queue_name AND status = ''running'' ' +
        HBCond;

      Query.ParamByName('queue_name').AsString := QueueName;
      Query.ParamByName('timeout_sec').AsInteger := TimeoutSec;
      Query.ExecSQL;
      Result := Query.RowsAffected;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.Complete(const TaskID: string): Boolean;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  ValidateTaskID(TaskID);
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
        'status = ''done'', updated_at = CURRENT_TIMESTAMP ' +
        'WHERE id = :id AND status = ''running''';
      Query.ParamByName('id').AsString := TaskID;
      Query.ExecSQL;
      Result := Query.RowsAffected > 0;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.Fail(const TaskID, ErrorMessage: string;
  Requeue: Boolean): Boolean;
begin
  // Default-max-retry overload: delegate to the explicit-max variant using
  // DEFAULT_JOB_MAX_RETRIES (5).
  Result := Fail(TaskID, ErrorMessage, Requeue, DEFAULT_JOB_MAX_RETRIES);
end;

class function TJobQueue.ComputeBackoffSeconds(Attempts: Integer): Integer;
var
  Delay: Integer;
  I: Integer;
begin
  // EXP-P1-015: delay = min(BASE * 2^(attempts-1), CAP). Implemented as a
  // simple loop to avoid floating-point Pow and to keep behavior identical on
  // all platforms. Attempts <= 0 yields BASE; attempts >= 30 saturates at CAP
  // without overflow because we short-circuit once Delay reaches CAP.
  if Attempts <= 0 then
    Exit(JOB_QUEUE_BACKOFF_BASE_SEC);
  Delay := JOB_QUEUE_BACKOFF_BASE_SEC;
  for I := 2 to Attempts do
  begin
    if Delay >= JOB_QUEUE_BACKOFF_CAP_SEC then
    begin
      Delay := JOB_QUEUE_BACKOFF_CAP_SEC;
      Break;
    end;
    Delay := Delay * 2;
    if Delay > JOB_QUEUE_BACKOFF_CAP_SEC then
      Delay := JOB_QUEUE_BACKOFF_CAP_SEC;
  end;
  Result := Delay;
end;

class function TJobQueue.Fail(const TaskID, ErrorMessage: string;
  Requeue: Boolean; AMaxRetries: Integer): Boolean;
var
  Connection: TFDConnection;
  LookupQuery, UpdateQuery, InsertQuery: TFDQuery;
  CurrentAttempts: Integer;
  BackoffSec: Integer;
  IsPG: Boolean;
  DLQInsertSQL, DLQDeleteSQL: string;
  OwnTx: Boolean;
begin
  ValidateTaskID(TaskID);
  EnsureSchemaIfNeeded;

  // EXP-P1-015 rewrite: when Requeue is requested, either schedule the row
  // back to 'pending' with an exponential-backoff next_run_at (below the max
  // retry threshold), or atomically move it to the dedicated dead-letter
  // table (at or above the threshold). This removes the row from the hot
  // path and stops retry storms against a broken downstream.

  Connection := AcquireConnection;
  try
    IsPG := IsPostgreSQL(Connection);

    if Requeue then
    begin
      // Read current attempt count + payload snapshot under the same
      // connection so the decision and the DLQ payload are consistent.
      LookupQuery := TFDQuery.Create(nil);
      try
        LookupQuery.Connection := Connection;
        LookupQuery.SQL.Text :=
          'SELECT attempts, payload, queue_name, logical_key, created_at ' +
          'FROM ' + JOB_QUEUE_TABLE +
          ' WHERE id = :id AND status = ''running''';
        LookupQuery.ParamByName('id').AsString := TaskID;
        LookupQuery.Open;
        if LookupQuery.Eof then
        begin
          Result := False;
          Exit;
        end;
        CurrentAttempts := LookupQuery.FieldByName('attempts').AsInteger;

        if CurrentAttempts >= AMaxRetries then
        begin
          // DATA2-046: always wrap the INSERT+DELETE pair in a transaction on
          // both PG and SQLite. Previously PG ran the two statements without a
          // transaction, so a DELETE failure left the row in BOTH the main
          // queue and the DLQ. FireDAC's StartTransaction/Commit/Rollback
          // works uniformly for both drivers.
          OwnTx := not Connection.InTransaction;

          DLQInsertSQL :=
            'INSERT INTO ' + JOB_QUEUE_DLQ_TABLE + ' ' +
            '(original_id, queue_name, logical_key, payload, attempts, ' +
            ' last_error, created_at, moved_at) ' +
            'SELECT id, queue_name, logical_key, payload, attempts, ' +
            '       :last_error, created_at, CURRENT_TIMESTAMP ' +
            'FROM ' + JOB_QUEUE_TABLE +
            ' WHERE id = :id AND status = ''running''';
          DLQDeleteSQL :=
            'DELETE FROM ' + JOB_QUEUE_TABLE +
            ' WHERE id = :id AND status = ''running''';

          if OwnTx then
            Connection.StartTransaction;
          try
            InsertQuery := TFDQuery.Create(nil);
            try
              InsertQuery.Connection := Connection;
              InsertQuery.SQL.Text := DLQInsertSQL;
              InsertQuery.ParamByName('last_error').AsString := ErrorMessage;
              InsertQuery.ParamByName('id').AsString := TaskID;
              InsertQuery.ExecSQL;
              Result := InsertQuery.RowsAffected > 0;
            finally
              InsertQuery.Free;
            end;

            if Result then
            begin
              UpdateQuery := TFDQuery.Create(nil);
              try
                UpdateQuery.Connection := Connection;
                UpdateQuery.SQL.Text := DLQDeleteSQL;
                UpdateQuery.ParamByName('id').AsString := TaskID;
                UpdateQuery.ExecSQL;
              finally
                UpdateQuery.Free;
              end;
            end;

            if OwnTx then
              Connection.Commit;
          except
            if OwnTx and Connection.InTransaction then
              Connection.Rollback;
            raise;
          end;
          Exit;
        end;
      finally
        LookupQuery.Free;
      end;

      // Below max retries: schedule back to 'pending' with exponential
      // backoff. delay = min(BASE * 2^(attempts-1), CAP).
      BackoffSec := ComputeBackoffSeconds(CurrentAttempts);

      UpdateQuery := TFDQuery.Create(nil);
      try
        UpdateQuery.Connection := Connection;
        if IsPG then
        begin
          // DATA2-048: let the server compute next_run_at from
          // CURRENT_TIMESTAMP so client/server clock drift cannot cause
          // retries to fire at the wrong time. The previous code passed a
          // Delphi Now()+backoff TDateTime; the PG driver sent it as a
          // TIMESTAMP WITH TIME ZONE literal, but if the client clock was
          // ahead/behind the server the stored instant was wrong.
          UpdateQuery.SQL.Text :=
            'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
            'status = ''pending'', last_error = :last_error, ' +
            'dequeued_at = NULL, heartbeat_at = NULL, ' +
            'next_run_at = CURRENT_TIMESTAMP + (:secs * INTERVAL ''1 second''), ' +
            'updated_at = CURRENT_TIMESTAMP ' +
            'WHERE id = :id AND status = ''running''';
          UpdateQuery.ParamByName('secs').AsInteger := BackoffSec;
        end
        else
        begin
          // SQLite: datetime('now') returns UTC text (yyyy-mm-dd hh:nn:ss).
          // Compute next_run_at using the same server-side function so the
          // stored text has identical format to the Dequeue comparison.
          // This avoids any client/server timezone drift.
          UpdateQuery.SQL.Text :=
            'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
            'status = ''pending'', last_error = :last_error, ' +
            'dequeued_at = NULL, heartbeat_at = NULL, ' +
            'next_run_at = datetime(''now'', ''+'' || :secs || '' seconds''), ' +
            'updated_at = CURRENT_TIMESTAMP ' +
            'WHERE id = :id AND status = ''running''';
          UpdateQuery.ParamByName('secs').AsInteger := BackoffSec;
        end;
        UpdateQuery.ParamByName('last_error').AsString := ErrorMessage;
        UpdateQuery.ParamByName('id').AsString := TaskID;
        UpdateQuery.ExecSQL;
        Result := UpdateQuery.RowsAffected > 0;
      finally
        UpdateQuery.Free;
      end;
    end
    else
    begin
      // Not requeueing - mark as permanently failed.
      UpdateQuery := TFDQuery.Create(nil);
      try
        UpdateQuery.Connection := Connection;
        UpdateQuery.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
          'status = ''failed'', last_error = :last_error, ' +
          'updated_at = CURRENT_TIMESTAMP ' +
          'WHERE id = :id AND status = ''running''';
        UpdateQuery.ParamByName('id').AsString := TaskID;
        UpdateQuery.ParamByName('last_error').AsString := ErrorMessage;
        UpdateQuery.ExecSQL;
        Result := UpdateQuery.RowsAffected > 0;
      finally
        UpdateQuery.Free;
      end;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

{ ---- EXP-P1-015: DLQ API ------------------------------------------------- }

class procedure TJobQueue.LoadDeadLetterFromQuery(Query: TFDQuery;
  out Rec: TDeadLetterRec);
var
  CreatedAtText, MovedAtText: string;
begin
  Rec.OriginalID := Query.FieldByName('original_id').AsString;
  Rec.QueueName := Query.FieldByName('queue_name').AsString;
  Rec.LogicalKey := Query.FieldByName('logical_key').AsString;
  Rec.Payload := ParsePayload(Query.FieldByName('payload').AsString);
  Rec.Attempts := Query.FieldByName('attempts').AsInteger;
  Rec.LastError := Query.FieldByName('last_error').AsString;
  // EXP-P1-015: SQLite stores timestamps as TEXT, so read them as strings
  // and convert via StrToDateTime. For PG the column is TIMESTAMP and
  // AsDateTime works, but using the string path is safe for both dialects
  // (both formats are ISO-8601-ish and StrToDateTime accepts them).
  CreatedAtText := Query.FieldByName('created_at').AsString;
  MovedAtText := Query.FieldByName('moved_at').AsString;
  try
    Rec.CreatedAt := StrToDateTime(CreatedAtText);
  except
    Rec.CreatedAt := 0;
  end;
  try
    Rec.MovedAt := StrToDateTime(MovedAtText);
  except
    Rec.MovedAt := 0;
  end;
end;

class function TJobQueue.DeadLetterCount(const QueueName: string): Integer;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      if QueueName = '' then
        Query.SQL.Text := 'SELECT COUNT(*) AS cnt FROM ' + JOB_QUEUE_DLQ_TABLE
      else
      begin
        ValidateQueueName(QueueName);
        Query.SQL.Text :=
          'SELECT COUNT(*) AS cnt FROM ' + JOB_QUEUE_DLQ_TABLE +
          ' WHERE queue_name = :queue_name';
        Query.ParamByName('queue_name').AsString := QueueName;
      end;
      Query.Open;
      Result := Query.FieldByName('cnt').AsInteger;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.PeekDeadLetters(const QueueName: string;
  Limit: Integer): TArray<TDeadLetterRec>;
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Collected: TList<TDeadLetterRec>;
  Rec: TDeadLetterRec;
begin
  EnsureSchemaIfNeeded;
  if Limit < 0 then
    raise EInvalidOperationException.Create('Limit must be >= 0');

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      if QueueName = '' then
        Query.SQL.Text :=
          'SELECT original_id, queue_name, logical_key, payload, attempts, ' +
          'last_error, created_at, moved_at FROM ' + JOB_QUEUE_DLQ_TABLE +
          ' ORDER BY moved_at DESC LIMIT :lim'
      else
      begin
        ValidateQueueName(QueueName);
        Query.SQL.Text :=
          'SELECT original_id, queue_name, logical_key, payload, attempts, ' +
          'last_error, created_at, moved_at FROM ' + JOB_QUEUE_DLQ_TABLE +
          ' WHERE queue_name = :queue_name ORDER BY moved_at DESC LIMIT :lim';
        Query.ParamByName('queue_name').AsString := QueueName;
      end;
      Query.ParamByName('lim').AsInteger := Limit;
      Query.Open;

      Collected := TList<TDeadLetterRec>.Create;
      try
        while not Query.Eof do
        begin
          Rec.Clear;
          LoadDeadLetterFromQuery(Query, Rec);
          Collected.Add(Rec);
          Query.Next;
        end;
        Result := Collected.ToArray;
      finally
        Collected.Free;
      end;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.ReplayDeadLetter(const OriginalID: string): Boolean;
var
  Connection: TFDConnection;
  InsertQuery, DeleteQuery: TFDQuery;
  IsPG: Boolean;
  OwnTx: Boolean;
begin
  ValidateTaskID(OriginalID);
  EnsureSchemaIfNeeded;

  // Re-enqueue a dead-letter row back into the main queue as 'pending' with
  // attempts = 0 and no next_run_at, then remove the DLQ row.
  Connection := AcquireConnection;
  try
    IsPG := IsPostgreSQL(Connection);
    // DATA2-047: always wrap the INSERT+DELETE pair in a transaction on both
    // PG and SQLite. Previously PG ran without a transaction, so a DELETE
    // failure left the row in both the main queue and the DLQ.
    OwnTx := not Connection.InTransaction;
    if OwnTx then
      Connection.StartTransaction;
    try
      InsertQuery := TFDQuery.Create(nil);
      try
        InsertQuery.Connection := Connection;
        if IsPG then
          InsertQuery.SQL.Text :=
            'INSERT INTO ' + JOB_QUEUE_TABLE + ' ' +
            '(id, queue_name, logical_key, payload, status, attempts, ' +
            ' last_error, created_at, updated_at, next_run_at) ' +
            'SELECT original_id, queue_name, logical_key, payload, ' +
            '       ''pending'', 0, last_error, created_at, ' +
            '       CURRENT_TIMESTAMP, NULL ' +
            'FROM ' + JOB_QUEUE_DLQ_TABLE +
            ' WHERE original_id = :id'
        else
          InsertQuery.SQL.Text :=
            'INSERT INTO ' + JOB_QUEUE_TABLE + ' ' +
            '(id, queue_name, logical_key, payload, status, attempts, ' +
            ' last_error, created_at, updated_at, next_run_at) ' +
            'SELECT original_id, queue_name, logical_key, payload, ' +
            '       ''pending'', 0, last_error, created_at, ' +
            '       CURRENT_TIMESTAMP, NULL ' +
            'FROM ' + JOB_QUEUE_DLQ_TABLE +
            ' WHERE original_id = :id';
        InsertQuery.ParamByName('id').AsString := OriginalID;
        InsertQuery.ExecSQL;
        Result := InsertQuery.RowsAffected > 0;
      finally
        InsertQuery.Free;
      end;

      if Result then
      begin
        DeleteQuery := TFDQuery.Create(nil);
        try
          DeleteQuery.Connection := Connection;
          DeleteQuery.SQL.Text :=
            'DELETE FROM ' + JOB_QUEUE_DLQ_TABLE +
            ' WHERE original_id = :id';
          DeleteQuery.ParamByName('id').AsString := OriginalID;
          DeleteQuery.ExecSQL;
        finally
          DeleteQuery.Free;
        end;
      end;

      if OwnTx then
        Connection.Commit;
    except
      if OwnTx and Connection.InTransaction then
        Connection.Rollback;
      raise;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

class function TJobQueue.PurgeDeadLetter(const OriginalID: string): Boolean;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  ValidateTaskID(OriginalID);
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'DELETE FROM ' + JOB_QUEUE_DLQ_TABLE + ' WHERE original_id = :id';
      Query.ParamByName('id').AsString := OriginalID;
      Query.ExecSQL;
      Result := Query.RowsAffected > 0;
    finally
      Query.Free;
    end;
  finally
    ReleaseConnection(Connection);
  end;
end;

end.
