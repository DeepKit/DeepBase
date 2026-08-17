{ ============================================================================
  DeepBase.Persistence.LLM.FireDAC - FireDAC adapter for DeepBase.LLM
  ============================================================================
  Implements ILLMStorage for Core\DeepBase.LLM.
  ============================================================================
}

unit DeepBase.Persistence.LLM.FireDAC;

interface

uses
  DeepBase.LLM,
  FireDAC.Comp.Client;

function CreateLLMStorage(AConnection: TFDConnection): ILLMStorage;
procedure RegisterLLMStorageFactory;

implementation

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  FireDAC.Stan.Param,
  DeepBase.LLM.Manager,
  DeepBase.SQL.Utils;

type
  TFireDACLLMStorage = class(TInterfacedObject, ILLMStorage)
  private
    FConnection: TFDConnection;
    function PrepareQuery(const SQL: string;
      const Params: array of TLLMStorageParam): TFDQuery;
  public
    constructor Create(AConnection: TFDConnection);
    function IsConnected: Boolean;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function OpenDataSet(const SQL: string;
      const Params: array of TLLMStorageParam): TDataSet;
    function Execute(const SQL: string;
      const Params: array of TLLMStorageParam): Integer;
    function ExecuteScalar(const SQL: string;
      const Params: array of TLLMStorageParam): Variant;
    function IsPostgreSQL: Boolean;
  end;

constructor TFireDACLLMStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection');
  FConnection := AConnection;
end;

function TFireDACLLMStorage.IsConnected: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.Connected;
end;

function TFireDACLLMStorage.PrepareQuery(const SQL: string;
  const Params: array of TLLMStorageParam): TFDQuery;
var
  I: Integer;
  Param: TFDParam;
  V: Variant;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := SQL;
  for I := 0 to High(Params) do
  begin
    Param := Result.Params.FindParam(Params[I].Name);
    if Assigned(Param) then
    begin
      V := Params[I].Value;
      if VarIsNull(V) or VarIsEmpty(V) then
      begin
        Param.DataType := ftInteger;
        Param.Clear;
      end
      else if VarIsType(V, varBoolean) then
      begin
        if IsPostgreSQL then
        begin
          Param.DataType := ftBoolean;
          Param.AsBoolean := Boolean(V);
        end
        else
        begin
          Param.DataType := ftInteger;
          Param.AsInteger := Ord(Boolean(V));
        end;
      end
      else if VarIsType(V, varInteger) or VarIsType(V, varSmallint) then
      begin
        Param.DataType := ftInteger;
        Param.AsInteger := Integer(V);
      end
      else if VarIsType(V, varInt64) or VarIsType(V, varWord) or VarIsType(V, varLongWord) then
      begin
        Param.DataType := ftLargeint;
        Param.AsLargeInt := V;
      end
      else if VarIsType(V, varDouble) or VarIsType(V, varSingle) then
      begin
        Param.DataType := ftFloat;
        Param.AsFloat := Double(V);
      end
      else
      begin
        Param.DataType := ftWideString;
        Param.AsWideString := VarToStr(V);
      end;
    end;
  end;
end;

function TFireDACLLMStorage.OpenDataSet(const SQL: string;
  const Params: array of TLLMStorageParam): TDataSet;
var
  Query: TFDQuery;
begin
  Query := PrepareQuery(SQL, Params);
  try
    Query.Open;
    Result := Query;
  except
    Query.Free;
    raise;
  end;
end;

function TFireDACLLMStorage.Execute(const SQL: string;
  const Params: array of TLLMStorageParam): Integer;
var
  Query: TFDQuery;
begin
  Query := PrepareQuery(SQL, Params);
  try
    Query.ExecSQL;
    Result := Query.RowsAffected;
  finally
    Query.Free;
  end;
end;

function TFireDACLLMStorage.ExecuteScalar(const SQL: string;
  const Params: array of TLLMStorageParam): Variant;
var
  Query: TFDQuery;
begin
  Query := PrepareQuery(SQL, Params);
  try
    Query.Open;
    if not Query.IsEmpty then
      Result := Query.Fields[0].Value
    else
      Result := Null;
  finally
    Query.Free;
  end;
end;

function TFireDACLLMStorage.IsPostgreSQL: Boolean;
var
  DriverName: string;
begin
  if not Assigned(FConnection) then
    Exit(False);
  DriverName := FConnection.DriverName;
  if DriverName = '' then
    DriverName := FConnection.Params.Values['DriverID'];
  Result := SameText(DriverName, 'PG') or SameText(DriverName, 'PostgreSQL');
end;

function TFireDACLLMStorage.TableExists(const TableName: string): Boolean;
var
  DataSet: TDataSet;
  Query: TFDQuery;
begin
  Result := False;
  if not IsConnected then
    Exit;

  try
    if IsPostgreSQL then
    begin
      Query := TFDQuery.Create(nil);
      try
        Query.Connection := FConnection;
        Query.SQL.Text :=
          'SELECT COUNT(*) FROM information_schema.tables ' +
          'WHERE table_schema = current_schema() AND table_name = :TableName';
        Query.ParamByName('TableName').AsString := TableName;
        Query.Open;
        Result := Query.Fields[0].AsInteger > 0;
      finally
        Query.Free;
      end;
    end
    else
    begin
      DataSet := OpenDataSet(
        'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :Name',
        [TLLMStorageParam.Create('Name', TableName)]);
      try
        Result := not DataSet.Eof;
      finally
        DataSet.Free;
      end;
    end;
  except
    Result := False;
  end;
end;

function TFireDACLLMStorage.TableHasColumn(const TableName,
  ColumnName: string): Boolean;
var
  DataSet: TDataSet;
begin
  Result := False;

  // Validate identifiers to prevent SQL injection (DATA2-018)
  TSQLUtils.ValidateIdentifier(TableName, 'TableName');
  TSQLUtils.ValidateIdentifier(ColumnName, 'ColumnName');

  if not TableExists(TableName) then
    Exit;

  DataSet := OpenDataSet(Format('SELECT * FROM %s WHERE 1 = 0', [TableName]), []);
  try
    try
      Result := Assigned(DataSet.FindField(ColumnName));
    except
      Result := False;
    end;
  finally
    DataSet.Free;
  end;
end;

function CreateLLMStorage(AConnection: TFDConnection): ILLMStorage;
begin
  Result := TFireDACLLMStorage.Create(AConnection);
end;

procedure RegisterLLMStorageFactory;
begin
  TDeepBaseLLM.SetStorageFactory(
    function(AConnection: TObject): ILLMStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for LLM FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateLLMStorage(FDConnection);
    end);

  TLLMManager.SetStorageFactory(
    function(AConnection: TObject): ILLMStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for LLM FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateLLMStorage(FDConnection);
    end);
end;

initialization
  RegisterLLMStorageFactory;

end.
