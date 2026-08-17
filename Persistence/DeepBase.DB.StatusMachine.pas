unit DeepBase.DB.StatusMachine;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections,
  FireDAC.Comp.Client;

type
  TStatusTransitionRule = class
  private
    FFromStatus: string;
    FToStatus: string;
    FGuard: TFunc<Boolean>;
    FIsFailTransition: Boolean;
  public
    constructor Create(const FromStatus, ToStatus: string;
      const Guard: TFunc<Boolean>; IsFailTransition: Boolean = False);

    property FromStatus: string read FFromStatus;
    property ToStatus: string read FToStatus;
    property Guard: TFunc<Boolean> read FGuard;
    property IsFailTransition: Boolean read FIsFailTransition;
  end;

  TTableStateDef = class
  private
    FHeartbeatIntervalSec: Integer;
    FTransitions: TObjectList<TStatusTransitionRule>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddTransition(const FromStatus, ToStatus: string;
      AGuard: TFunc<Boolean> = nil);
    procedure AddFailTransition(const FromStatus, FailStatus: string);
    function FindTransition(const FromStatus, ToStatus: string): TStatusTransitionRule;

    property HeartbeatIntervalSec: Integer read FHeartbeatIntervalSec
      write FHeartbeatIntervalSec;
  end;

  TStatusMachine = class
  private
    class var FTables: TObjectDictionary<string, TTableStateDef>;
    class var FLock: TCriticalSection;
    class var FConnectionProvider: TFunc<TFDConnection>;
    class var FLastHeartbeats: TDictionary<string, TDateTime>;

    class function NormalizeTableName(const TableName: string): string; static;
    class procedure ValidateIdentifier(const Identifier: string); static;
    class function GetTableDef(const TableName: string): TTableStateDef; static;
    class function AcquireConnection: TFDConnection; static;
    class function QuoteIdentifier(const AName: string): string; static;
    class function ReadCurrentStatus(Connection: TFDConnection;
      const TableName: string; EntityID: Integer; out Status: string): Boolean; static;
    class function IsPostgreSQL(Connection: TFDConnection): Boolean; static;
    class function CanWriteHeartbeat(const TableName: string; EntityID,
      IntervalSec: Integer): Boolean; static;
    class procedure RecordHeartbeat(const TableName: string; EntityID: Integer); static;
    class function HeartbeatKey(const TableName: string; EntityID: Integer): string; static;
  public
    class constructor Create;
    class destructor Destroy;

    class procedure RegisterTable(const TableName: string;
      ConfigProc: TFunc<TTableStateDef, TTableStateDef>); static;
    class function Transit(const TableName: string; EntityID: Integer;
      const NewStatus: string): Boolean; static;
    class procedure Heartbeat(const TableName: string; EntityID: Integer); static;

    class procedure SetConnectionProvider(const Provider: TFunc<TFDConnection>); static;
    class procedure Clear; static;
  end;

implementation

uses
  FireDAC.Stan.Param,
  DeepBase.DB.Factory,
  DeepBase.Exceptions;

{ TStatusTransitionRule }

constructor TStatusTransitionRule.Create(const FromStatus, ToStatus: string;
  const Guard: TFunc<Boolean>; IsFailTransition: Boolean);
begin
  inherited Create;
  FFromStatus := FromStatus;
  FToStatus := ToStatus;
  FGuard := Guard;
  FIsFailTransition := IsFailTransition;
end;

{ TTableStateDef }

constructor TTableStateDef.Create;
begin
  inherited Create;
  FHeartbeatIntervalSec := 30;
  FTransitions := TObjectList<TStatusTransitionRule>.Create(True);
end;

destructor TTableStateDef.Destroy;
begin
  FreeAndNil(FTransitions);
  inherited;
end;

procedure TTableStateDef.AddTransition(const FromStatus, ToStatus: string;
  AGuard: TFunc<Boolean>);
begin
  if Trim(FromStatus) = '' then
    raise EInvalidOperationException.Create('FromStatus cannot be empty');
  if Trim(ToStatus) = '' then
    raise EInvalidOperationException.Create('ToStatus cannot be empty');

  FTransitions.Add(TStatusTransitionRule.Create(FromStatus, ToStatus, AGuard));
end;

procedure TTableStateDef.AddFailTransition(const FromStatus, FailStatus: string);
begin
  if Trim(FromStatus) = '' then
    raise EInvalidOperationException.Create('FromStatus cannot be empty');
  if Trim(FailStatus) = '' then
    raise EInvalidOperationException.Create('FailStatus cannot be empty');

  FTransitions.Add(TStatusTransitionRule.Create(FromStatus, FailStatus, nil, True));
end;

function TTableStateDef.FindTransition(const FromStatus,
  ToStatus: string): TStatusTransitionRule;
var
  Rule: TStatusTransitionRule;
begin
  Result := nil;
  for Rule in FTransitions do
  begin
    if SameText(Rule.FromStatus, FromStatus) and SameText(Rule.ToStatus, ToStatus) then
      Exit(Rule);
  end;
end;

{ TStatusMachine }

class constructor TStatusMachine.Create;
begin
  FTables := TObjectDictionary<string, TTableStateDef>.Create([doOwnsValues]);
  FLastHeartbeats := TDictionary<string, TDateTime>.Create;
  FLock := TCriticalSection.Create;
end;

class destructor TStatusMachine.Destroy;
begin
  FreeAndNil(FLock);
  FreeAndNil(FLastHeartbeats);
  FreeAndNil(FTables);
end;

class procedure TStatusMachine.SetConnectionProvider(
  const Provider: TFunc<TFDConnection>);
begin
  FLock.Enter;
  try
    FConnectionProvider := Provider;
  finally
    FLock.Leave;
  end;
end;

class procedure TStatusMachine.Clear;
begin
  FLock.Enter;
  try
    FTables.Clear;
    FLastHeartbeats.Clear;
    FConnectionProvider := nil;
  finally
    FLock.Leave;
  end;
end;

class function TStatusMachine.NormalizeTableName(
  const TableName: string): string;
begin
  ValidateIdentifier(TableName);
  Result := LowerCase(TableName);
end;

class procedure TStatusMachine.ValidateIdentifier(const Identifier: string);
var
  I: Integer;
  Ch: Char;
  DotSeen: Boolean;
begin
  if Trim(Identifier) = '' then
    raise EInvalidOperationException.Create('Table name cannot be empty');

  // BUG EXP-P1-016 fix: accept "schema.table" (or bare "table") form.
  // At most one dot is allowed; both sides of the dot must be valid SQL
  // identifiers. This lets callers register state machines against tables
  // in an explicit schema (e.g. "public.orders", "audit.events") without
  // resorting to quoting tricks.
  Ch := Identifier[1];
  if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '_']) then
    raise EInvalidOperationException.CreateFmt('Invalid table name: %s', [Identifier]);

  DotSeen := False;
  for I := 2 to Length(Identifier) do
  begin
    Ch := Identifier[I];
    if Ch = '.' then
    begin
      if DotSeen then
        raise EInvalidOperationException.CreateFmt(
          'Invalid table name (at most one dot allowed): %s', [Identifier]);
      DotSeen := True;
      // Character after dot must start a valid identifier segment.
      if (I = Length(Identifier)) or
         not CharInSet(Identifier[I + 1], ['A'..'Z', 'a'..'z', '_']) then
        raise EInvalidOperationException.CreateFmt(
          'Invalid table name (empty segment after dot): %s', [Identifier]);
      Continue;
    end;
    if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EInvalidOperationException.CreateFmt('Invalid table name: %s', [Identifier]);
  end;
end;

/// <summary>
///   Wraps a SQL identifier in double quotes so reserved words (Order, User,
///   Group, …) are safe to use as table or column names. Uses the SQL-92
///   standard quoting recognised by PostgreSQL, SQLite and SQL Server (ANSI).
/// </summary>
class function TStatusMachine.QuoteIdentifier(const AName: string): string;
var
  Ch: Char;
begin
  Result := '"';
  for Ch in AName do
  begin
    if Ch = '"' then
      Result := Result + '""'
    else
      Result := Result + Ch;
  end;
  Result := Result + '"';
end;

class procedure TStatusMachine.RegisterTable(const TableName: string;
  ConfigProc: TFunc<TTableStateDef, TTableStateDef>);
var
  Key: string;
  Def: TTableStateDef;
  ConfiguredDef: TTableStateDef;
begin
  Key := NormalizeTableName(TableName);
  Def := TTableStateDef.Create;
  ConfiguredDef := nil;
  try
    ConfiguredDef := Def;
    if Assigned(ConfigProc) then
      ConfiguredDef := ConfigProc(Def);
    if not Assigned(ConfiguredDef) then
      ConfiguredDef := Def;

    if ConfiguredDef <> Def then
      FreeAndNil(Def);

    FLock.Enter;
    try
      FTables.AddOrSetValue(Key, ConfiguredDef);
    finally
      FLock.Leave;
    end;

    if ConfiguredDef = Def then
      Def := nil;
    ConfiguredDef := nil;
  finally
    Def.Free;
    ConfiguredDef.Free;
  end;
end;

class function TStatusMachine.GetTableDef(
  const TableName: string): TTableStateDef;
var
  Key: string;
begin
  Key := NormalizeTableName(TableName);

  FLock.Enter;
  try
    if not FTables.TryGetValue(Key, Result) then
      raise EInvalidOperationException.CreateFmt(
        'Status machine table is not registered: %s', [TableName]);
  finally
    FLock.Leave;
  end;
end;

class function TStatusMachine.AcquireConnection: TFDConnection;
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
    raise EDatabaseException.Create('Status machine connection provider returned nil');
end;

class function TStatusMachine.IsPostgreSQL(Connection: TFDConnection): Boolean;
begin
  Result := Assigned(Connection) and
    (SameText(Connection.DriverName, 'PG') or SameText(Connection.DriverName, 'PostgreSQL'));
end;

class function TStatusMachine.ReadCurrentStatus(Connection: TFDConnection;
  const TableName: string; EntityID: Integer; out Status: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Status := '';

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := Connection;
    Query.SQL.Text := Format('SELECT status FROM %s WHERE id = :id',
      [QuoteIdentifier(TableName)]);
    if IsPostgreSQL(Connection) then
      Query.SQL.Text := Query.SQL.Text + ' FOR UPDATE';
    Query.ParamByName('id').AsInteger := EntityID;
    Query.Open;

    if not Query.Eof then
    begin
      Status := Query.FieldByName('status').AsString;
      Result := True;
    end;
  finally
    Query.Free;
  end;
end;

class function TStatusMachine.Transit(const TableName: string; EntityID: Integer;
  const NewStatus: string): Boolean;
var
  Def: TTableStateDef;
  Rule: TStatusTransitionRule;
  Connection: TFDConnection;
  Query: TFDQuery;
  CurrentStatus: string;
  OwnTransaction: Boolean;
begin
  if Trim(NewStatus) = '' then
    raise EInvalidOperationException.Create('NewStatus cannot be empty');

  Def := GetTableDef(TableName);
  ValidateIdentifier(TableName);

  Connection := AcquireConnection;
  try
    OwnTransaction := not Connection.InTransaction;
    if OwnTransaction then
      Connection.StartTransaction;
    try
      if not ReadCurrentStatus(Connection, TableName, EntityID, CurrentStatus) then
      begin
        if OwnTransaction then
          Connection.Rollback;
        Exit(False);
      end;

      Rule := Def.FindTransition(CurrentStatus, NewStatus);
      if not Assigned(Rule) then
      begin
        if OwnTransaction then
          Connection.Rollback;
        Exit(False);
      end;

      if Assigned(Rule.Guard) and not Rule.Guard() then
      begin
        if OwnTransaction then
          Connection.Rollback;
        Exit(False);
      end;

      Query := TFDQuery.Create(nil);
      try
        Query.Connection := Connection;
        Query.SQL.Text := Format(
          'UPDATE %s SET status = :new_status, prev_status = :prev_status, ' +
          'heartbeat_at = CURRENT_TIMESTAMP, progress_at = CURRENT_TIMESTAMP ' +
          'WHERE id = :id',
          [QuoteIdentifier(TableName)]);
        Query.ParamByName('new_status').AsString := NewStatus;
        Query.ParamByName('prev_status').AsString := CurrentStatus;
        Query.ParamByName('id').AsInteger := EntityID;
        Query.ExecSQL;
        Result := Query.RowsAffected > 0;
      finally
        Query.Free;
      end;

      if OwnTransaction then
        Connection.Commit;
      RecordHeartbeat(TableName, EntityID);
    except
      if OwnTransaction and Connection.InTransaction then
        Connection.Rollback;
      raise;
    end;
  finally
    Connection.Free;
  end;
end;

class function TStatusMachine.HeartbeatKey(const TableName: string;
  EntityID: Integer): string;
begin
  Result := LowerCase(TableName) + ':' + IntToStr(EntityID);
end;

class function TStatusMachine.CanWriteHeartbeat(const TableName: string;
  EntityID, IntervalSec: Integer): Boolean;
var
  Key: string;
  LastHeartbeat: TDateTime;
begin
  if IntervalSec <= 0 then
    Exit(True);

  Key := HeartbeatKey(TableName, EntityID);
  FLock.Enter;
  try
    if not FLastHeartbeats.TryGetValue(Key, LastHeartbeat) then
      Exit(True);
    Result := ((Now - LastHeartbeat) * 86400) >= IntervalSec;
  finally
    FLock.Leave;
  end;
end;

class procedure TStatusMachine.RecordHeartbeat(const TableName: string;
  EntityID: Integer);
begin
  FLock.Enter;
  try
    FLastHeartbeats.AddOrSetValue(HeartbeatKey(TableName, EntityID), Now);
  finally
    FLock.Leave;
  end;
end;

class procedure TStatusMachine.Heartbeat(const TableName: string;
  EntityID: Integer);
var
  Def: TTableStateDef;
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  Def := GetTableDef(TableName);
  ValidateIdentifier(TableName);

  if not CanWriteHeartbeat(TableName, EntityID, Def.HeartbeatIntervalSec) then
    Exit;

  Connection := AcquireConnection;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text := Format(
        'UPDATE %s SET heartbeat_at = CURRENT_TIMESTAMP WHERE id = :id',
        [QuoteIdentifier(TableName)]);
      Query.ParamByName('id').AsInteger := EntityID;
      Query.ExecSQL;
      if Query.RowsAffected > 0 then
        RecordHeartbeat(TableName, EntityID);
    finally
      Query.Free;
    end;
  finally
    Connection.Free;
  end;
end;

end.
