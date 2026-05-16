{ ============================================================================
  DeepBase.Persistence.Logging.FireDAC - FireDAC adapter for logger storage
  ============================================================================
  Provides FireDAC-backed ILogStorage/ILogQueryStorage and registers the
  factory into TDeepBaseLogger.
  ============================================================================ }

unit DeepBase.Persistence.Logging.FireDAC;

interface

uses
  DeepBase.Storage.Interfaces;

function CreateLogStorage(const DBPath: string): ILogStorage;
procedure RegisterLogStorageFactory;

implementation

uses
  System.SysUtils,
  System.SyncObjs,
  Data.DB,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.Phys.SQLite,
  DeepBase.Logging;

type
  TFireDACLogStorage = class(TInterfacedObject, ILogStorage, ILogQueryStorage)
  private
    FDBPath: string;
    FConnection: TFDConnection;
    FInsertQuery: TFDQuery;
    FLegacyInsertQuery: TFDQuery;
    FLock: TCriticalSection;
    procedure EnsureConnection;
    procedure EnsureInsertQuery;
    procedure EnsureLegacyInsertQuery;
  public
    constructor Create(const ADBPath: string);
    destructor Destroy; override;
    procedure WriteLog(const Data: TLogStorageData);
    procedure PurgeOlderThan(const CutoffISO: string);
    function CountByLevel(const LevelText: string): Int64;
    function CountAll: Int64;
  end;

constructor TFireDACLogStorage.Create(const ADBPath: string);
begin
  inherited Create;
  FDBPath := ADBPath;
  FLock := TCriticalSection.Create;
end;

destructor TFireDACLogStorage.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FLegacyInsertQuery);
    FreeAndNil(FInsertQuery);
    FreeAndNil(FConnection);
  finally
    FLock.Leave;
  end;
  FreeAndNil(FLock);
  inherited;
end;

procedure TFireDACLogStorage.EnsureConnection;
begin
  if Assigned(FConnection) then
    Exit;
  if FDBPath = '' then
    Exit;

  FConnection := TFDConnection.Create(nil);
  try
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

procedure TFireDACLogStorage.EnsureInsertQuery;
begin
  if Assigned(FInsertQuery) then
    Exit;

  EnsureConnection;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FInsertQuery := TFDQuery.Create(nil);
  FInsertQuery.Connection := FConnection;
  FInsertQuery.SQL.Text :=
    'INSERT INTO Logs (LogTime, LogLevel, Source, Message, StackTrace, ThreadId, Extra) ' +
    'VALUES (:LogTime, :Level, :Source, :Msg, :Stack, :TID, :Extra)';
  FInsertQuery.ParamByName('LogTime').DataType := ftString;
  FInsertQuery.ParamByName('Level').DataType := ftString;
  FInsertQuery.ParamByName('Source').DataType := ftString;
  FInsertQuery.ParamByName('Msg').DataType := ftString;
  FInsertQuery.ParamByName('Stack').DataType := ftString;
  FInsertQuery.ParamByName('TID').DataType := ftInteger;
  FInsertQuery.ParamByName('Extra').DataType := ftString;
  FInsertQuery.Prepare;
end;

procedure TFireDACLogStorage.EnsureLegacyInsertQuery;
begin
  if Assigned(FLegacyInsertQuery) then
    Exit;

  EnsureConnection;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FLegacyInsertQuery := TFDQuery.Create(nil);
  FLegacyInsertQuery.Connection := FConnection;
  FLegacyInsertQuery.SQL.Text :=
    'INSERT INTO Logs (LogTime, LogLevel, Source, Message, StackTrace, ThreadId) ' +
    'VALUES (:LogTime, :Level, :Source, :Msg, :Stack, :TID)';
  FLegacyInsertQuery.ParamByName('LogTime').DataType := ftString;
  FLegacyInsertQuery.ParamByName('Level').DataType := ftString;
  FLegacyInsertQuery.ParamByName('Source').DataType := ftString;
  FLegacyInsertQuery.ParamByName('Msg').DataType := ftString;
  FLegacyInsertQuery.ParamByName('Stack').DataType := ftString;
  FLegacyInsertQuery.ParamByName('TID').DataType := ftInteger;
  FLegacyInsertQuery.Prepare;
end;

procedure TFireDACLogStorage.WriteLog(const Data: TLogStorageData);
begin
  // BASIC-010 fix: serialize all writes so concurrent callers don't
  // interleave parameter assignments on the shared FInsertQuery.
  FLock.Enter;
  try
    EnsureConnection;
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;

    try
      EnsureInsertQuery;
      if not Assigned(FInsertQuery) then
        Exit;

      FInsertQuery.ParamByName('LogTime').AsString := Data.TimestampISO;
      FInsertQuery.ParamByName('Level').AsString := Data.LevelText;
      FInsertQuery.ParamByName('Source').AsString := Data.Source;
      FInsertQuery.ParamByName('Msg').AsString := Data.MessageText;
      FInsertQuery.ParamByName('Stack').AsString := Data.StackTrace;
      FInsertQuery.ParamByName('TID').AsInteger := Data.ThreadId;
      FInsertQuery.ParamByName('Extra').AsString := Data.Extra;
      FInsertQuery.ExecSQL;
    except
      // Backward compatibility: allow old schema without "Extra" column.
      EnsureLegacyInsertQuery;
      if not Assigned(FLegacyInsertQuery) then
        Exit;

      FLegacyInsertQuery.ParamByName('LogTime').AsString := Data.TimestampISO;
      FLegacyInsertQuery.ParamByName('Level').AsString := Data.LevelText;
      FLegacyInsertQuery.ParamByName('Source').AsString := Data.Source;
      FLegacyInsertQuery.ParamByName('Msg').AsString := Data.MessageText;
      FLegacyInsertQuery.ParamByName('Stack').AsString := Data.StackTrace;
      FLegacyInsertQuery.ParamByName('TID').AsInteger := Data.ThreadId;
      FLegacyInsertQuery.ExecSQL;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACLogStorage.PurgeOlderThan(const CutoffISO: string);
var
  Query: TFDQuery;
begin
  FLock.Enter;
  try
    EnsureConnection;
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Logs WHERE LogTime < :CutoffTime';
      Query.ParamByName('CutoffTime').AsString := CutoffISO;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFireDACLogStorage.CountByLevel(const LevelText: string): Int64;
var
  Query: TFDQuery;
begin
  Result := 0;
  FLock.Enter;
  try
    EnsureConnection;
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT COUNT(*) FROM Logs WHERE LogLevel = :Level';
      Query.ParamByName('Level').AsString := LevelText;
      Query.Open;
      Result := Query.Fields[0].AsLargeInt;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFireDACLogStorage.CountAll: Int64;
var
  Query: TFDQuery;
begin
  Result := 0;
  FLock.Enter;
  try
    EnsureConnection;
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT COUNT(*) FROM Logs';
      Query.Open;
      Result := Query.Fields[0].AsLargeInt;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function CreateLogStorage(const DBPath: string): ILogStorage;
begin
  Result := TFireDACLogStorage.Create(DBPath);
end;

procedure RegisterLogStorageFactory;
begin
  TDeepBaseLogger.SetStorageFactory(
    function(DBPath: string): ILogStorage
    begin
      Result := CreateLogStorage(DBPath);
    end);
end;

initialization
  RegisterLogStorageFactory;

end.
