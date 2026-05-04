{******************************************************************************
  UniBase.Persistence.Manager.FireDAC - FireDAC adapter for manager storage
  ============================================================================
  Moves Manager schema/project metadata SQL out of Core\UniBase.Manager.
  ============================================================================
******************************************************************************}

unit UniBase.Persistence.Manager.FireDAC;

interface

uses
  UniBase.Manager,
  UniBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateManagerStorage(AConnection: TFDConnection): IManagerStorage;
procedure RegisterManagerStorageFactory;

implementation

uses
  System.SysUtils,
  UniBase.Persistence.Config.FireDAC,
  UniBase.Persistence.I18n.FireDAC,
  UniBase.Persistence.Theme.FireDAC,
  UniBase.Persistence.Security.FireDAC,
  UniBase.Persistence.FormState.FireDAC,
  UniBase.Persistence.MRU.FireDAC,
  UniBase.Persistence.Hotkeys.FireDAC;

type
  TFireDACManagerStorage = class(TInterfacedObject, IManagerStorage)
  private
    FConnection: TFDConnection;
    function IsPostgreSQL: Boolean;
    class function BuildQuotedList(const Items: array of string): string; static;
  public
    constructor Create(AConnection: TFDConnection);
    function CountCoreTables(const TableNames: array of string): Integer;
    function TableExists(const TableName: string): Boolean;
    procedure ExecuteStatement(const SQL: string);
    function ColumnExists(const TableName, ColumnName: string): Boolean;
    procedure AddColumn(const TableName, ColumnName, ColumnDef: string);
    function ReadSchemaVersion: string;
    procedure UpdateSchemaInfo(const SchemaVersion, LastUpgradeIso8601: string);
    function ReadProjectInfo(const Key: string): string;
    procedure UpsertProjectInfo(const Key, Value: string);
    function CreateConfigStorage: IConfigStorage;
    function CreateI18nStorage: II18nStorage;
    function CreateThemeStorage: IThemeStorage;
    function CreateSecuritySecretStorage: ISecuritySecretStorage;
    function CreateFormStateStorage: IFormStateStorage;
    function CreateMRUStorage: IMRUStorage;
    function CreateHotkeyStorage: IHotkeyStorage;
  end;

constructor TFireDACManagerStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACManagerStorage.IsPostgreSQL: Boolean;
begin
  Result := Assigned(FConnection) and
    (SameText(FConnection.DriverName, 'PG') or
     SameText(FConnection.DriverName, 'PostgreSQL'));
end;

class function TFireDACManagerStorage.BuildQuotedList(
  const Items: array of string): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Items) to High(Items) do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + QuotedStr(Items[I]);
  end;
end;

function TFireDACManagerStorage.CountCoreTables(
  const TableNames: array of string): Integer;
var
  Query: TFDQuery;
  TableList: string;
begin
  Result := 0;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  TableList := BuildQuotedList(TableNames);
  if TableList = '' then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM information_schema.tables ' +
        'WHERE table_schema = current_schema() AND table_name IN (' + TableList + ')'
    else
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name IN (' +
        TableList + ')';
    Query.Open;
    Result := Query.Fields[0].AsInteger;
  finally
    Query.Free;
  end;
end;

function TFireDACManagerStorage.TableExists(const TableName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected or
     (Trim(TableName) = '') then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
    begin
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM information_schema.tables ' +
        'WHERE table_schema = current_schema() AND table_name = :TableName';
      Query.ParamByName('TableName').AsString := TableName;
    end
    else
    begin
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM sqlite_master WHERE type = ''table'' AND name = :TableName';
      Query.ParamByName('TableName').AsString := TableName;
    end;
    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
end;

procedure TFireDACManagerStorage.ExecuteStatement(const SQL: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.ResourceOptions.ParamCreate := False;
    Query.SQL.Text := SQL;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACManagerStorage.ColumnExists(
  const TableName, ColumnName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    if IsPostgreSQL then
    begin
      Query.SQL.Text :=
        'SELECT COUNT(*) FROM information_schema.columns ' +
        'WHERE table_schema = current_schema() AND table_name = :TableName ' +
        'AND column_name = :ColumnName';
      Query.ParamByName('TableName').AsString := TableName;
      Query.ParamByName('ColumnName').AsString := ColumnName;
    end
    else
      Query.SQL.Text := Format(
        'SELECT COUNT(*) FROM pragma_table_info(''%s'') WHERE name = ''%s''',
        [TableName, ColumnName]);

    Query.Open;
    Result := Query.Fields[0].AsInteger > 0;
  finally
    Query.Free;
  end;
end;

procedure TFireDACManagerStorage.AddColumn(
  const TableName, ColumnName, ColumnDef: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := Format('ALTER TABLE %s ADD COLUMN %s %s',
      [TableName, ColumnName, ColumnDef]);
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACManagerStorage.ReadSchemaVersion: string;
var
  Query: TFDQuery;
begin
  Result := '';
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM SchemaInfo WHERE Key = ''SchemaVersion''';
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACManagerStorage.UpdateSchemaInfo(
  const SchemaVersion, LastUpgradeIso8601: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE SchemaInfo SET Value = :Ver WHERE Key = ''SchemaVersion''';
    Query.ParamByName('Ver').AsString := SchemaVersion;
    Query.ExecSQL;

    Query.SQL.Text := 'UPDATE SchemaInfo SET Value = :NowTime WHERE Key = ''LastUpgrade''';
    Query.ParamByName('NowTime').AsString := LastUpgradeIso8601;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACManagerStorage.ReadProjectInfo(const Key: string): string;
var
  Query: TFDQuery;
begin
  Result := '';
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM ProjectInfo WHERE Key = :Key';
    Query.ParamByName('Key').AsString := Key;
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACManagerStorage.UpsertProjectInfo(const Key, Value: string);
var
  UpdateQuery: TFDQuery;
  ExistsQuery: TFDQuery;
  InsertQuery: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  UpdateQuery := TFDQuery.Create(nil);
  ExistsQuery := TFDQuery.Create(nil);
  InsertQuery := TFDQuery.Create(nil);
  try
    UpdateQuery.Connection := FConnection;
    UpdateQuery.SQL.Text :=
      'UPDATE ProjectInfo SET Value = :Value WHERE Key = :Key';
    UpdateQuery.ParamByName('Key').AsString := Key;
    UpdateQuery.ParamByName('Value').AsString := Value;
    UpdateQuery.ExecSQL;

    if UpdateQuery.RowsAffected = 0 then
    begin
      ExistsQuery.Connection := FConnection;
      ExistsQuery.SQL.Text := 'SELECT 1 FROM ProjectInfo WHERE Key = :Key';
      ExistsQuery.ParamByName('Key').AsString := Key;
      ExistsQuery.Open;
      try
        if ExistsQuery.Eof then
        begin
          InsertQuery.Connection := FConnection;
          InsertQuery.SQL.Text :=
            'INSERT INTO ProjectInfo (Key, Value) VALUES (:Key, :Value)';
          InsertQuery.ParamByName('Key').AsString := Key;
          InsertQuery.ParamByName('Value').AsString := Value;
          InsertQuery.ExecSQL;
        end;
      finally
        ExistsQuery.Close;
      end;
    end;
  finally
    UpdateQuery.Free;
    ExistsQuery.Free;
    InsertQuery.Free;
  end;
end;

function TFireDACManagerStorage.CreateConfigStorage: IConfigStorage;
begin
  Result := UniBase.Persistence.Config.FireDAC.CreateConfigStorage(FConnection);
end;

function TFireDACManagerStorage.CreateI18nStorage: II18nStorage;
begin
  Result := UniBase.Persistence.I18n.FireDAC.CreateI18nStorage(FConnection);
end;

function TFireDACManagerStorage.CreateThemeStorage: IThemeStorage;
begin
  Result := UniBase.Persistence.Theme.FireDAC.CreateThemeStorage(FConnection);
end;

function TFireDACManagerStorage.CreateSecuritySecretStorage: ISecuritySecretStorage;
begin
  Result := UniBase.Persistence.Security.FireDAC.CreateSecuritySecretStorage(FConnection);
end;

function TFireDACManagerStorage.CreateFormStateStorage: IFormStateStorage;
begin
  Result := UniBase.Persistence.FormState.FireDAC.CreateFormStateStorage(FConnection);
end;

function TFireDACManagerStorage.CreateMRUStorage: IMRUStorage;
begin
  Result := UniBase.Persistence.MRU.FireDAC.CreateMRUStorage(FConnection);
end;

function TFireDACManagerStorage.CreateHotkeyStorage: IHotkeyStorage;
begin
  Result := UniBase.Persistence.Hotkeys.FireDAC.CreateHotkeyStorage(FConnection);
end;

function CreateManagerStorage(AConnection: TFDConnection): IManagerStorage;
begin
  Result := TFireDACManagerStorage.Create(AConnection);
end;

procedure RegisterManagerStorageFactory;
begin
  TUniBaseManager.SetStorageFactory(
    function(AConnection: TObject): IManagerStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Manager FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateManagerStorage(FDConnection);
    end);
end;

initialization
  RegisterManagerStorageFactory;

end.
