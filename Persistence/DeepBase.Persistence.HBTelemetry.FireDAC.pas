{ ============================================================================
  DeepBase.Persistence.HBTelemetry.FireDAC - SQLite WAL Persistence Adapter
  for HB Touchpoint Telemetry & Session Snapshots

  Version: 1.0 (Delphi 13.1 on Win64)
  Description: Persistence adapter for WO-20260904-004:
               - Implements IHbTelemetrySink for local-first SQLite WAL storage.
               - Implements THbFireDACSnapshotStorage for session snapshots.
               - Zero PII: only structured evidence & control context payloads.
               - Best-effort persistence with auto-purge (7-day TTL).
  ============================================================================ }

unit DeepBase.Persistence.HBTelemetry.FireDAC;

{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.SyncObjs,
  System.DateUtils,
  System.Generics.Collections,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  DeepBase.HB.Touchpoint.Types;

type
  /// <summary>
  /// FireDAC-backed SQLite WAL implementation of IHbTelemetrySink.
  /// </summary>
  THbFireDACTelemetrySink = class(TNoRefCountObject, IHbTelemetrySink)
  private
    FDBPath: string;
    FConnection: TFDConnection;
    FLock: TCriticalSection;
    procedure EnsureConnection;
    procedure EnsureSchema;
  public
    constructor Create(const ADBPath: string = '');
    destructor Destroy; override;

    // IHbTelemetrySink implementation
    procedure PersistEvidence(const AEvidence: TArray<TTouchEvidence>);
    procedure Flush;

    // Audit & Query methods for verification
    function GetTotalEvidenceCount: Int64;
    function ReadEvidences(const ATouchpointId: string = ''; AMaxCount: Integer = 100): TArray<TTouchEvidence>;
    procedure ClearAll;
    function GetDatabasePath: string;
    function IsWALMode: Boolean;
    property Connection: TFDConnection read FConnection;
  end;

  /// <summary>
  /// FireDAC-backed SQLite storage for HB Session Snapshots.
  /// </summary>
  THbFireDACSnapshotStorage = class
  private
    class var FInstance: THbFireDACSnapshotStorage;
    class var FClassLock: TCriticalSection;
    class constructor ClassCreate;
    class destructor ClassDestroy;
    class function GetInstance: THbFireDACSnapshotStorage; static;
  private
    FDBPath: string;
    FConnection: TFDConnection;
    FLock: TCriticalSection;
    procedure EnsureConnection;
    procedure EnsureSchema;
  public
    constructor Create(const ADBPath: string = '');
    destructor Destroy; override;

    class property Instance: THbFireDACSnapshotStorage read GetInstance;

    procedure SaveSnapshot(const ASurfaceId, AControlId, APayload: string);
    function LoadSnapshot(const ASurfaceId, AControlId: string; out APayload: string): Boolean;
    procedure DeleteSnapshot(const ASurfaceId, AControlId: string);
    procedure ClearSurfaceSnapshots(const ASurfaceId: string);
    procedure PurgeExpiredSnapshots(AMaxAgeDays: Integer = 7);
    function HasSnapshot(const ASurfaceId, AControlId: string): Boolean;
    function GetTotalSnapshotCount: Int64;
    procedure ClearAll;
    function GetDatabasePath: string;
    property Connection: TFDConnection read FConnection;
  end;

function GetDefaultHbDatabasePath: string;
function CreateHbTelemetrySink(const ADBPath: string = ''): IHbTelemetrySink;
function CreateHbSnapshotStorage(const ADBPath: string = ''): THbFireDACSnapshotStorage;

implementation

function GetDefaultHbDatabasePath: string;
var
  BaseDir: string;
begin
  BaseDir := TPath.GetHomePath; // %LOCALAPPDATA%
  BaseDir := TPath.Combine(BaseDir, 'DeepBase');
  if not TDirectory.Exists(BaseDir) then
    TDirectory.CreateDirectory(BaseDir);
  Result := TPath.Combine(BaseDir, 'hbtelemetry.sqlite');
end;

function CreateHbTelemetrySink(const ADBPath: string): IHbTelemetrySink;
begin
  Result := THbFireDACTelemetrySink.Create(ADBPath);
end;

function CreateHbSnapshotStorage(const ADBPath: string): THbFireDACSnapshotStorage;
begin
  Result := THbFireDACSnapshotStorage.Create(ADBPath);
end;

{ THbFireDACTelemetrySink }

constructor THbFireDACTelemetrySink.Create(const ADBPath: string);
begin
  inherited Create;
  if ADBPath <> '' then
    FDBPath := ADBPath
  else
    FDBPath := GetDefaultHbDatabasePath;
  FLock := TCriticalSection.Create;
  EnsureConnection;
  EnsureSchema;
end;

destructor THbFireDACTelemetrySink.Destroy;
begin
  Flush;
  FLock.Enter;
  try
    FreeAndNil(FConnection);
  finally
    FLock.Leave;
  end;
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure THbFireDACTelemetrySink.EnsureConnection;
var
  ParentDir: string;
begin
  if Assigned(FConnection) and FConnection.Connected then
    Exit;

  ParentDir := ExtractFilePath(FDBPath);
  if (ParentDir <> '') and not TDirectory.Exists(ParentDir) then
    TDirectory.CreateDirectory(ParentDir);

  FConnection := TFDConnection.Create(nil);
  try
    FConnection.LoginPrompt := False;
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Database := FDBPath;
    FConnection.Params.Values['LockingMode'] := 'Normal';
    FConnection.Params.Values['Synchronous'] := 'Normal';
    FConnection.Params.Values['JournalMode'] := 'WAL';
    FConnection.Open;
  except
    FreeAndNil(FConnection);
    raise;
  end;
end;

procedure THbFireDACTelemetrySink.EnsureSchema;
var
  Qry: TFDQuery;
begin
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS hb_evidence (' +
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
        '  touchpoint_id TEXT NOT NULL,' +
        '  surface_id TEXT,' +
        '  timestamp_utc INTEGER NOT NULL,' +
        '  dwell_time_ms INTEGER,' +
        '  success INTEGER NOT NULL,' +
        '  before_state TEXT,' +
        '  after_state TEXT,' +
        '  action_type TEXT,' +
        '  exit_position TEXT,' +
        '  error_code INTEGER,' +
        '  support_deflected INTEGER' +
        ');';
      Qry.ExecSQL;

      Qry.SQL.Text :=
        'CREATE INDEX IF NOT EXISTS idx_hb_ev_tp ON hb_evidence(touchpoint_id, timestamp_utc);';
      Qry.ExecSQL;

      Qry.SQL.Text :=
        'CREATE INDEX IF NOT EXISTS idx_hb_ev_surf ON hb_evidence(surface_id);';
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACTelemetrySink.PersistEvidence(const AEvidence: TArray<TTouchEvidence>);
var
  Qry: TFDQuery;
  I: Integer;
begin
  if Length(AEvidence) = 0 then
    Exit;

  FLock.Enter;
  try
    EnsureConnection;
    if not FConnection.Connected then
      Exit;

    FConnection.StartTransaction;
    try
      Qry := TFDQuery.Create(nil);
      try
        Qry.Connection := FConnection;
        Qry.SQL.Text :=
          'INSERT INTO hb_evidence (' +
          '  touchpoint_id, surface_id, timestamp_utc, dwell_time_ms, success, ' +
          '  before_state, after_state, action_type, exit_position, error_code, support_deflected' +
          ') VALUES (' +
          '  :tp, :surf, :ts, :dwell, :succ, :before_s, :after_s, :act, :exit_p, :err, :supp' +
          ');';

        for I := 0 to High(AEvidence) do
        begin
          Qry.ParamByName('tp').AsString := AEvidence[I].TouchpointId;
          Qry.ParamByName('surf').AsString := AEvidence[I].SurfaceId;
          Qry.ParamByName('ts').AsLargeInt := AEvidence[I].TimestampUtc;
          Qry.ParamByName('dwell').AsInteger := Integer(AEvidence[I].DwellTimeMs);
          if AEvidence[I].Success then
            Qry.ParamByName('succ').AsInteger := 1
          else
            Qry.ParamByName('succ').AsInteger := 0;
          Qry.ParamByName('before_s').AsString := AEvidence[I].BeforeState;
          Qry.ParamByName('after_s').AsString := AEvidence[I].AfterState;
          Qry.ParamByName('act').AsString := AEvidence[I].ActionType;
          Qry.ParamByName('exit_p').AsString := AEvidence[I].ExitPosition;
          Qry.ParamByName('err').AsInteger := AEvidence[I].ErrorCode;
          if AEvidence[I].SupportDeflected then
            Qry.ParamByName('supp').AsInteger := 1
          else
            Qry.ParamByName('supp').AsInteger := 0;

          Qry.ExecSQL;
        end;
      finally
        Qry.Free;
      end;
      FConnection.Commit;
    except
      if FConnection.InTransaction then
        FConnection.Rollback;
      raise;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACTelemetrySink.Flush;
var
  Qry: TFDQuery;
begin
  FLock.Enter;
  try
    if Assigned(FConnection) and FConnection.Connected then
    begin
      try
        Qry := TFDQuery.Create(nil);
        try
          Qry.Connection := FConnection;
          Qry.SQL.Text := 'PRAGMA wal_checkpoint(PASSIVE);';
          Qry.ExecSQL;
        finally
          Qry.Free;
        end;
      except
        // Best-effort checkpoint, ignore passive lock contention
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACTelemetrySink.GetTotalEvidenceCount: Int64;
var
  Qry: TFDQuery;
begin
  Result := 0;
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT COUNT(*) FROM hb_evidence;';
      Qry.Open;
      if not Qry.Eof then
        Result := Qry.Fields[0].AsLargeInt;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACTelemetrySink.ReadEvidences(const ATouchpointId: string; AMaxCount: Integer): TArray<TTouchEvidence>;
var
  Qry: TFDQuery;
  List: TList<TTouchEvidence>;
  Ev: TTouchEvidence;
begin
  List := TList<TTouchEvidence>.Create;
  try
    FLock.Enter;
    try
      EnsureConnection;
      Qry := TFDQuery.Create(nil);
      try
        Qry.Connection := FConnection;
        if ATouchpointId <> '' then
        begin
          Qry.SQL.Text := 'SELECT * FROM hb_evidence WHERE touchpoint_id = :tp ORDER BY timestamp_utc DESC LIMIT :lim;';
          Qry.ParamByName('tp').AsString := ATouchpointId;
        end
        else
        begin
          Qry.SQL.Text := 'SELECT * FROM hb_evidence ORDER BY timestamp_utc DESC LIMIT :lim;';
        end;
        Qry.ParamByName('lim').AsInteger := AMaxCount;
        Qry.Open;

        while not Qry.Eof do
        begin
          FillChar(Ev, SizeOf(Ev), 0);
          Ev.TouchpointId := Qry.FieldByName('touchpoint_id').AsString;
          Ev.SurfaceId := Qry.FieldByName('surface_id').AsString;
          Ev.TimestampUtc := Qry.FieldByName('timestamp_utc').AsLargeInt;
          Ev.DwellTimeMs := Cardinal(Qry.FieldByName('dwell_time_ms').AsInteger);
          Ev.Success := (Qry.FieldByName('success').AsInteger = 1);
          Ev.BeforeState := Qry.FieldByName('before_state').AsString;
          Ev.AfterState := Qry.FieldByName('after_state').AsString;
          Ev.ActionType := Qry.FieldByName('action_type').AsString;
          Ev.ExitPosition := Qry.FieldByName('exit_position').AsString;
          Ev.ErrorCode := Qry.FieldByName('error_code').AsInteger;
          Ev.SupportDeflected := (Qry.FieldByName('support_deflected').AsInteger = 1);

          List.Add(Ev);
          Qry.Next;
        end;
      finally
        Qry.Free;
      end;
    finally
      FLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure THbFireDACTelemetrySink.ClearAll;
var
  Qry: TFDQuery;
begin
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'DELETE FROM hb_evidence;';
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACTelemetrySink.GetDatabasePath: string;
begin
  Result := FDBPath;
end;

function THbFireDACTelemetrySink.IsWALMode: Boolean;
var
  Qry: TFDQuery;
begin
  Result := False;
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'PRAGMA journal_mode;';
      Qry.Open;
      if not Qry.Eof then
        Result := SameText(Qry.Fields[0].AsString, 'wal');
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ THbFireDACSnapshotStorage }

class constructor THbFireDACSnapshotStorage.ClassCreate;
begin
  FClassLock := TCriticalSection.Create;
  FInstance := nil;
end;

class destructor THbFireDACSnapshotStorage.ClassDestroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FClassLock);
end;

class function THbFireDACSnapshotStorage.GetInstance: THbFireDACSnapshotStorage;
begin
  if FInstance = nil then
  begin
    FClassLock.Enter;
    try
      if FInstance = nil then
        FInstance := THbFireDACSnapshotStorage.Create;
    finally
      FClassLock.Leave;
    end;
  end;
  Result := FInstance;
end;

constructor THbFireDACSnapshotStorage.Create(const ADBPath: string);
begin
  inherited Create;
  if ADBPath <> '' then
    FDBPath := ADBPath
  else
    FDBPath := GetDefaultHbDatabasePath;
  FLock := TCriticalSection.Create;
  EnsureConnection;
  EnsureSchema;
end;

destructor THbFireDACSnapshotStorage.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FConnection);
  finally
    FLock.Leave;
  end;
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure THbFireDACSnapshotStorage.EnsureConnection;
var
  ParentDir: string;
begin
  if Assigned(FConnection) and FConnection.Connected then
    Exit;

  ParentDir := ExtractFilePath(FDBPath);
  if (ParentDir <> '') and not TDirectory.Exists(ParentDir) then
    TDirectory.CreateDirectory(ParentDir);

  FConnection := TFDConnection.Create(nil);
  try
    FConnection.LoginPrompt := False;
    FConnection.DriverName := 'SQLite';
    FConnection.Params.Database := FDBPath;
    FConnection.Params.Values['LockingMode'] := 'Normal';
    FConnection.Params.Values['Synchronous'] := 'Normal';
    FConnection.Params.Values['JournalMode'] := 'WAL';
    FConnection.Open;
  except
    FreeAndNil(FConnection);
    raise;
  end;
end;

procedure THbFireDACSnapshotStorage.EnsureSchema;
var
  Qry: TFDQuery;
begin
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text :=
        'CREATE TABLE IF NOT EXISTS hb_snapshots (' +
        '  surface_id TEXT NOT NULL,' +
        '  control_id TEXT NOT NULL,' +
        '  payload TEXT NOT NULL,' +
        '  captured_at_utc INTEGER NOT NULL,' +
        '  PRIMARY KEY(surface_id, control_id)' +
        ');';
      Qry.ExecSQL;

      Qry.SQL.Text :=
        'CREATE INDEX IF NOT EXISTS idx_hb_snap_captured ON hb_snapshots(captured_at_utc);';
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACSnapshotStorage.SaveSnapshot(const ASurfaceId, AControlId, APayload: string);
var
  Qry: TFDQuery;
  NowUtc: Int64;
begin
  if (ASurfaceId = '') or (AControlId = '') then
    Exit;

  NowUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text :=
        'INSERT OR REPLACE INTO hb_snapshots (surface_id, control_id, payload, captured_at_utc) ' +
        'VALUES (:surf, :ctrl, :payload, :ts);';
      Qry.ParamByName('surf').AsString := ASurfaceId;
      Qry.ParamByName('ctrl').AsString := AControlId;
      Qry.ParamByName('payload').AsString := APayload;
      Qry.ParamByName('ts').AsLargeInt := NowUtc;
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACSnapshotStorage.LoadSnapshot(const ASurfaceId, AControlId: string; out APayload: string): Boolean;
var
  Qry: TFDQuery;
begin
  Result := False;
  APayload := '';

  if (ASurfaceId = '') or (AControlId = '') then
    Exit;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text :=
        'SELECT payload FROM hb_snapshots WHERE surface_id = :surf AND control_id = :ctrl;';
      Qry.ParamByName('surf').AsString := ASurfaceId;
      Qry.ParamByName('ctrl').AsString := AControlId;
      Qry.Open;

      if not Qry.Eof then
      begin
        APayload := Qry.FieldByName('payload').AsString;
        Result := (APayload <> '');
      end;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACSnapshotStorage.DeleteSnapshot(const ASurfaceId, AControlId: string);
var
  Qry: TFDQuery;
begin
  if (ASurfaceId = '') or (AControlId = '') then
    Exit;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'DELETE FROM hb_snapshots WHERE surface_id = :surf AND control_id = :ctrl;';
      Qry.ParamByName('surf').AsString := ASurfaceId;
      Qry.ParamByName('ctrl').AsString := AControlId;
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACSnapshotStorage.ClearSurfaceSnapshots(const ASurfaceId: string);
var
  Qry: TFDQuery;
begin
  if ASurfaceId = '' then
    Exit;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'DELETE FROM hb_snapshots WHERE surface_id = :surf;';
      Qry.ParamByName('surf').AsString := ASurfaceId;
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACSnapshotStorage.PurgeExpiredSnapshots(AMaxAgeDays: Integer);
var
  Qry: TFDQuery;
  CutoffUtc: Int64;
begin
  if AMaxAgeDays <= 0 then
    AMaxAgeDays := 7;

  CutoffUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(IncDay(Now, -AMaxAgeDays)), False) * 1000;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'DELETE FROM hb_snapshots WHERE captured_at_utc < :cutoff;';
      Qry.ParamByName('cutoff').AsLargeInt := CutoffUtc;
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACSnapshotStorage.HasSnapshot(const ASurfaceId, AControlId: string): Boolean;
var
  Qry: TFDQuery;
begin
  Result := False;
  if (ASurfaceId = '') or (AControlId = '') then
    Exit;

  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT 1 FROM hb_snapshots WHERE surface_id = :surf AND control_id = :ctrl;';
      Qry.ParamByName('surf').AsString := ASurfaceId;
      Qry.ParamByName('ctrl').AsString := AControlId;
      Qry.Open;
      Result := not Qry.Eof;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACSnapshotStorage.GetTotalSnapshotCount: Int64;
var
  Qry: TFDQuery;
begin
  Result := 0;
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'SELECT COUNT(*) FROM hb_snapshots;';
      Qry.Open;
      if not Qry.Eof then
        Result := Qry.Fields[0].AsLargeInt;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure THbFireDACSnapshotStorage.ClearAll;
var
  Qry: TFDQuery;
begin
  FLock.Enter;
  try
    EnsureConnection;
    Qry := TFDQuery.Create(nil);
    try
      Qry.Connection := FConnection;
      Qry.SQL.Text := 'DELETE FROM hb_snapshots;';
      Qry.ExecSQL;
    finally
      Qry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function THbFireDACSnapshotStorage.GetDatabasePath: string;
begin
  Result := FDBPath;
end;

end.
