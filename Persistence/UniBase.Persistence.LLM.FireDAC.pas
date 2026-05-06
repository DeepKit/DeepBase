{ ============================================================================
  UniBase.Persistence.LLM.FireDAC - FireDAC adapter for UniBase.LLM
  ============================================================================
  Implements ILLMStorage for Core\UniBase.LLM.
  ============================================================================
}

unit UniBase.Persistence.LLM.FireDAC;

interface

uses
  UniBase.LLM,
  FireDAC.Comp.Client;

function CreateLLMStorage(AConnection: TFDConnection): ILLMStorage;
procedure RegisterLLMStorageFactory;

implementation

uses
  System.SysUtils,
  System.Variants,
  Data.DB,
  FireDAC.Stan.Param,
  UniBase.LLM.Manager;

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
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := SQL;
  for I := 0 to High(Params) do
  begin
    Param := Result.Params.FindParam(Params[I].Name);
    if Assigned(Param) then
      Param.Value := Params[I].Value;
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

function TFireDACLLMStorage.TableExists(const TableName: string): Boolean;
var
  DataSet: TDataSet;
begin
  Result := False;
  if not IsConnected then
    Exit;

  try
    DataSet := OpenDataSet(
      'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = :Name',
      [TLLMStorageParam.Create('Name', TableName)]);
    try
      Result := not DataSet.Eof;
    finally
      DataSet.Free;
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
  TUniBaseLLM.SetStorageFactory(
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
