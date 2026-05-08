unit Test.DeepBase.DB.StatusMachine;

interface

uses
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  DeepBase.DB.StatusMachine;

type
  [TestFixture]
  TTestDBStatusMachine = class
  private
    FTempDir: string;
    FDBPath: string;
    function CreateConnection: TFDConnection;
    procedure CreateWorkTable;
    procedure InsertWorkItem(EntityID: Integer; const Status: string);
    function ReadColumn(EntityID: Integer; const ColumnName: string): string;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Transit_ValidTransition_UpdatesStatusColumns;

    [Test]
    procedure Test_Transit_RejectsInvalidTransition;

    [Test]
    procedure Test_Transit_RejectsWhenGuardReturnsFalse;

    [Test]
    procedure Test_Transit_AllowsFailTransition;

    [Test]
    procedure Test_Heartbeat_UpdatesHeartbeatColumn;

    [Test]
    procedure Test_RegisterTable_RejectsUnsafeTableName;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Stan.Param,
  DeepBase.Exceptions;

procedure TTestDBStatusMachine.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_StatusMachine_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FDBPath := TPath.Combine(FTempDir, 'status.db');

  TStatusMachine.Clear;
  TStatusMachine.SetConnectionProvider(
    function: TFDConnection
    begin
      Result := CreateConnection;
    end);

  CreateWorkTable;
end;

procedure TTestDBStatusMachine.TearDown;
begin
  TStatusMachine.Clear;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestDBStatusMachine.CreateConnection: TFDConnection;
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

procedure TTestDBStatusMachine.CreateWorkTable;
var
  Conn: TFDConnection;
begin
  Conn := CreateConnection;
  try
    Conn.ExecSQL(
      'CREATE TABLE work_items (' +
      'id INTEGER PRIMARY KEY, ' +
      'status TEXT NOT NULL, ' +
      'prev_status TEXT, ' +
      'heartbeat_at TEXT, ' +
      'progress_at TEXT)');
  finally
    Conn.Free;
  end;
end;

procedure TTestDBStatusMachine.InsertWorkItem(EntityID: Integer;
  const Status: string);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := CreateConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text := 'INSERT INTO work_items (id, status) VALUES (:id, :status)';
      Query.ParamByName('id').AsInteger := EntityID;
      Query.ParamByName('status').AsString := Status;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBStatusMachine.ReadColumn(EntityID: Integer;
  const ColumnName: string): string;
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
      Query.SQL.Text := Format('SELECT %s FROM work_items WHERE id = :id',
        [ColumnName]);
      Query.ParamByName('id').AsInteger := EntityID;
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

procedure TTestDBStatusMachine.Test_Transit_ValidTransition_UpdatesStatusColumns;
begin
  InsertWorkItem(1, 'pending');
  TStatusMachine.RegisterTable('work_items',
    function(Def: TTableStateDef): TTableStateDef
    begin
      Def.AddTransition('pending', 'running');
      Result := Def;
    end);

  Assert.IsTrue(TStatusMachine.Transit('work_items', 1, 'running'));
  Assert.AreEqual('running', ReadColumn(1, 'status'));
  Assert.AreEqual('pending', ReadColumn(1, 'prev_status'));
  Assert.IsNotEmpty(ReadColumn(1, 'heartbeat_at'));
  Assert.IsNotEmpty(ReadColumn(1, 'progress_at'));
end;

procedure TTestDBStatusMachine.Test_Transit_RejectsInvalidTransition;
begin
  InsertWorkItem(2, 'pending');
  TStatusMachine.RegisterTable('work_items',
    function(Def: TTableStateDef): TTableStateDef
    begin
      Def.AddTransition('pending', 'running');
      Result := Def;
    end);

  Assert.IsFalse(TStatusMachine.Transit('work_items', 2, 'done'));
  Assert.AreEqual('pending', ReadColumn(2, 'status'));
  Assert.AreEqual('', ReadColumn(2, 'prev_status'));
end;

procedure TTestDBStatusMachine.Test_Transit_RejectsWhenGuardReturnsFalse;
begin
  InsertWorkItem(3, 'selected');
  TStatusMachine.RegisterTable('work_items',
    function(Def: TTableStateDef): TTableStateDef
    begin
      Def.AddTransition('selected', 'generating',
        function: Boolean
        begin
          Result := False;
        end);
      Result := Def;
    end);

  Assert.IsFalse(TStatusMachine.Transit('work_items', 3, 'generating'));
  Assert.AreEqual('selected', ReadColumn(3, 'status'));
end;

procedure TTestDBStatusMachine.Test_Transit_AllowsFailTransition;
begin
  InsertWorkItem(4, 'generating');
  TStatusMachine.RegisterTable('work_items',
    function(Def: TTableStateDef): TTableStateDef
    begin
      Def.AddFailTransition('generating', 'gen_failed');
      Result := Def;
    end);

  Assert.IsTrue(TStatusMachine.Transit('work_items', 4, 'gen_failed'));
  Assert.AreEqual('gen_failed', ReadColumn(4, 'status'));
  Assert.AreEqual('generating', ReadColumn(4, 'prev_status'));
end;

procedure TTestDBStatusMachine.Test_Heartbeat_UpdatesHeartbeatColumn;
begin
  InsertWorkItem(5, 'running');
  TStatusMachine.RegisterTable('work_items',
    function(Def: TTableStateDef): TTableStateDef
    begin
      Def.HeartbeatIntervalSec := 0;
      Result := Def;
    end);

  TStatusMachine.Heartbeat('work_items', 5);
  Assert.IsNotEmpty(ReadColumn(5, 'heartbeat_at'));
  Assert.AreEqual('running', ReadColumn(5, 'status'));
end;

procedure TTestDBStatusMachine.Test_RegisterTable_RejectsUnsafeTableName;
begin
  Assert.WillRaise(
    procedure
    begin
      TStatusMachine.RegisterTable('work_items;drop',
        function(Def: TTableStateDef): TTableStateDef
        begin
          Result := Def;
        end);
    end,
    EInvalidOperationException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBStatusMachine);

end.
