unit UniBase.DB.JobQueue;

interface

uses
  System.SysUtils,
  System.JSON,
  System.SyncObjs,
  FireDAC.Comp.Client;

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

  TJobQueue = class
  private
    class var FConnectionProvider: TFunc<TFDConnection>;
    class var FAutoEnsureSchema: Boolean;
    class var FSchemaEnsured: Boolean;
    class var FLock: TCriticalSection;

    class function AcquireConnection: TFDConnection; static;
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
    class function DequeuePostgreSQL(Connection: TFDConnection;
      const QueueName: string; out Task: TTaskRec): Boolean; static;
    class function DequeueSQLite(Connection: TFDConnection;
      const QueueName: string; out Task: TTaskRec): Boolean; static;
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
      TimeoutSec: Integer): Integer; static;
    class function Complete(const TaskID: string): Boolean; static;
    class function Fail(const TaskID, ErrorMessage: string;
      Requeue: Boolean = False): Boolean; static;
  end;

implementation

uses
  FireDAC.Stan.Param,
  UniBase.DB.Factory,
  UniBase.Exceptions;

const
  JOB_QUEUE_TABLE = 'unibase_job_queue';

{ TTaskRec }

procedure TTaskRec.Clear;
begin
  TaskID := '';
  QueueName := '';
  LogicalKey := '';
  Payload.Free;
  Payload := nil;
  Status := '';
  Attempts := 0;
  LastError := '';
end;

{ TJobQueue }

class constructor TJobQueue.Create;
begin
  FLock := TCriticalSection.Create;
  FAutoEnsureSchema := True;
  FSchemaEnsured := False;
end;

class destructor TJobQueue.Destroy;
begin
  FreeAndNil(FLock);
end;

class procedure TJobQueue.SetConnectionProvider(
  const Provider: TFunc<TFDConnection>);
begin
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
begin
  FLock.Enter;
  try
    Provider := FConnectionProvider;
  finally
    FLock.Leave;
  end;

  if Assigned(Provider) then
    Result := Provider()
  else
    Result := TDBConnectionFactory.GetShared;

  if not Assigned(Result) then
    raise EDatabaseException.Create('Job queue connection provider returned nil');
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
    Connection.Free;
  end;

  FLock.Enter;
  try
    FSchemaEnsured := True;
  finally
    FLock.Leave;
  end;
end;

class procedure TJobQueue.EnsureSchemaOnConnection(Connection: TFDConnection);
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
      'heartbeat_at TIMESTAMP NULL)');
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
      'heartbeat_at TEXT)');
  end
  else
    raise EDatabaseException.Create('Job queue supports SQLite and PostgreSQL only');

  Connection.ExecSQL(
    'CREATE UNIQUE INDEX IF NOT EXISTS ux_unibase_job_queue_logical ' +
    'ON ' + JOB_QUEUE_TABLE + ' (queue_name, logical_key)');
  Connection.ExecSQL(
    'CREATE INDEX IF NOT EXISTS ix_unibase_job_queue_pending ' +
    'ON ' + JOB_QUEUE_TABLE + ' (queue_name, status, created_at)');
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
    Connection.Free;
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
      'updated_at = CURRENT_TIMESTAMP ' +
      'WHERE id = (' +
      '  SELECT id FROM ' + JOB_QUEUE_TABLE + ' ' +
      '  WHERE queue_name = :queue_name AND status = ''pending'' ' +
      '  ORDER BY created_at, id ' +
      '  FOR UPDATE SKIP LOCKED ' +
      '  LIMIT 1' +
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
        'updated_at = CURRENT_TIMESTAMP ' +
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
    Connection.Free;
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
    Connection.Free;
  end;
end;

class function TJobQueue.RecycleDeadTasks(const QueueName: string;
  TimeoutSec: Integer): Integer;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  ValidateQueueName(QueueName);
  if TimeoutSec <= 0 then
    raise EInvalidOperationException.Create('TimeoutSec must be greater than zero');
  EnsureSchemaIfNeeded;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      if IsPostgreSQL(Connection) then
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
          'status = ''pending'', dequeued_at = NULL, heartbeat_at = NULL, ' +
          'updated_at = CURRENT_TIMESTAMP ' +
          'WHERE queue_name = :queue_name AND status = ''running'' ' +
          'AND heartbeat_at < (CURRENT_TIMESTAMP - (:timeout_sec * INTERVAL ''1 second''))'
      else
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
          'status = ''pending'', dequeued_at = NULL, heartbeat_at = NULL, ' +
          'updated_at = CURRENT_TIMESTAMP ' +
          'WHERE queue_name = :queue_name AND status = ''running'' ' +
          'AND heartbeat_at < datetime(''now'', ''-'' || :timeout_sec || '' seconds'')';

      Query.ParamByName('queue_name').AsString := QueueName;
      Query.ParamByName('timeout_sec').AsInteger := TimeoutSec;
      Query.ExecSQL;
      Result := Query.RowsAffected;
    finally
      Query.Free;
    end;
  finally
    Connection.Free;
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
    Connection.Free;
  end;
end;

class function TJobQueue.Fail(const TaskID, ErrorMessage: string;
  Requeue: Boolean): Boolean;
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
      if Requeue then
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
          'status = ''pending'', last_error = :last_error, dequeued_at = NULL, ' +
          'heartbeat_at = NULL, updated_at = CURRENT_TIMESTAMP ' +
          'WHERE id = :id AND status = ''running'''
      else
        Query.SQL.Text :=
          'UPDATE ' + JOB_QUEUE_TABLE + ' SET ' +
          'status = ''failed'', last_error = :last_error, ' +
          'updated_at = CURRENT_TIMESTAMP ' +
          'WHERE id = :id AND status = ''running''';
      Query.ParamByName('id').AsString := TaskID;
      Query.ParamByName('last_error').AsString := ErrorMessage;
      Query.ExecSQL;
      Result := Query.RowsAffected > 0;
    finally
      Query.Free;
    end;
  finally
    Connection.Free;
  end;
end;

end.
