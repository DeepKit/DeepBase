{ ============================================================================
  DeepBase.Persistence.Logging.FireDAC - FireDAC adapter for logger storage
  ============================================================================
  Provides FireDAC-backed ILogStorage/ILogQueryStorage/ILogViewStorage and registers the
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
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Logging;

type
  TFireDACLogStorage = class(TInterfacedObject, ILogStorage, ILogQueryStorage,
    ILogViewStorage)
  private
    FDBPath: string;
    FConnection: TFDConnection;
    FInsertQuery: TFDQuery;
    FLegacyInsertQuery: TFDQuery;
    FLock: TCriticalSection;
    procedure EnsureConnection;
    procedure EnsureInsertQuery;
    procedure EnsureLegacyInsertQuery;
    function ColumnExists(const TableName, ColumnName: string): Boolean;
    function LogLevelCaseExpression(const ColumnName: string): string;
  public
    constructor Create(const ADBPath: string);
    destructor Destroy; override;
    procedure WriteLog(const Data: TLogStorageData);
    procedure PurgeOlderThan(const CutoffISO: string);
    function CountByLevel(const LevelText: string): Int64;
    function CountAll: Int64;
    function ReadRecent(MinLevel: TLogLevel; MaxItems: Integer): TLogViewDataArray;
    procedure ClearAll;
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

function TFireDACLogStorage.ColumnExists(const TableName,
  ColumnName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  EnsureConnection;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if not SameText(TableName, 'Logs') then
      Exit;

    Query.SQL.Text := 'PRAGMA table_info(Logs)';
    Query.Open;
    while not Query.Eof do
    begin
      if SameText(Query.FieldByName('name').AsString, ColumnName) then
        Exit(True);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

function TFireDACLogStorage.LogLevelCaseExpression(
  const ColumnName: string): string;
begin
  Result :=
    'CASE UPPER(' + ColumnName + ') ' +
    'WHEN ''DEBUG'' THEN 0 ' +
    'WHEN ''INFO'' THEN 1 ' +
    'WHEN ''WARN'' THEN 2 ' +
    'WHEN ''WARNING'' THEN 2 ' +
    'WHEN ''ERROR'' THEN 3 ' +
    'WHEN ''FATAL'' THEN 4 ' +
    'ELSE 1 END';
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

function TFireDACLogStorage.ReadRecent(MinLevel: TLogLevel;
  MaxItems: Integer): TLogViewDataArray;
var
  Query: TFDQuery;
  Items: TList<TLogViewData>;
  Item: TLogViewData;
  HasIntegerLevel: Boolean;
  HasLogLevel: Boolean;
  HasId: Boolean;
  OrderBy: string;
  LevelExpr: string;
  LimitValue: Integer;
begin
  SetLength(Result, 0);
  LimitValue := MaxItems;
  if LimitValue <= 0 then
    LimitValue := 1000;

  FLock.Enter;
  try
    EnsureConnection;
    if not Assigned(FConnection) or not FConnection.Connected then
      Exit;

    HasIntegerLevel := ColumnExists('Logs', 'Level');
    HasLogLevel := ColumnExists('Logs', 'LogLevel');
    HasId := ColumnExists('Logs', 'Id');
    if not HasIntegerLevel and not HasLogLevel then
      Exit;

    if HasId then
      OrderBy := 'Id DESC'
    else
      OrderBy := 'LogTime DESC';

    Query := TFDQuery.Create(nil);
    Items := TList<TLogViewData>.Create;
    try
      Query.Connection := FConnection;
      if HasIntegerLevel then
      begin
        Query.SQL.Text :=
          'SELECT LogTime, Level, Source, Message, ThreadId FROM Logs ' +
          'WHERE Level >= :MinLevel ORDER BY ' + OrderBy + ' LIMIT :Max';
      end
      else
      begin
        LevelExpr := LogLevelCaseExpression('LogLevel');
        Query.SQL.Text :=
          'SELECT LogTime, LogLevel, Source, Message, ThreadId FROM Logs ' +
          'WHERE ' + LevelExpr + ' >= :MinLevel ORDER BY ' + OrderBy + ' LIMIT :Max';
      end;

      Query.ParamByName('MinLevel').AsInteger := Ord(MinLevel);
      Query.ParamByName('Max').AsInteger := LimitValue;
      Query.Open;

      while not Query.Eof do
      begin
        Item.TimestampISO := Query.FieldByName('LogTime').AsString;
        Item.Source := Query.FieldByName('Source').AsString;
        Item.MessageText := Query.FieldByName('Message').AsString;
        Item.ThreadId := Query.FieldByName('ThreadId').AsInteger;
        if HasIntegerLevel then
        begin
          Item.Level := TLogLevel(Query.FieldByName('Level').AsInteger);
          Item.LevelText := LogLevelToStr(Item.Level);
        end
        else
        begin
          Item.LevelText := Query.FieldByName('LogLevel').AsString;
          Item.Level := StrToLogLevel(Item.LevelText);
        end;
        Items.Add(Item);
        Query.Next;
      end;

      Result := Items.ToArray;
    finally
      Items.Free;
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACLogStorage.ClearAll;
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
      Query.SQL.Text := 'DELETE FROM Logs WHERE 1 = 1';
      Query.ExecSQL;
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
