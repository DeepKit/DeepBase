{ ============================================================================
  DeepBase.Persistence.ORM.FireDAC - FireDAC adapter for DeepBase.ORM
  ============================================================================
  Implements IORMStorage/IORMTransaction for Core\DeepBase.ORM.
  ============================================================================
}

unit DeepBase.Persistence.ORM.FireDAC;

interface

uses
  DeepBase.ORM,
  FireDAC.Comp.Client;

function CreateORMStorage(AConnection: TFDConnection): IORMStorage;
procedure RegisterORMStorageFactory;

implementation

uses
  System.SysUtils,
  System.Variants,
  Data.DB;

type
  TFireDACORMTransaction = class(TInterfacedObject, IORMTransaction)
  private
    FTransaction: TFDTransaction;
    FCompleted: Boolean;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    procedure Commit;
    procedure Rollback;
  end;

  TFireDACORMStorage = class(TInterfacedObject, IORMStorage)
  private
    FConnection: TFDConnection;
    function PrepareQuery(const SQL: string;
      const Params: array of Variant): TFDQuery;
  public
    constructor Create(AConnection: TFDConnection);
    function Execute(const SQL: string; const Params: array of Variant): Integer;
    function OpenDataSet(const SQL: string;
      const Params: array of Variant): TDataSet;
    function ExecuteScalar(const SQL: string;
      const Params: array of Variant): Variant;
    function BeginTransaction: IORMTransaction;
    function GetLastAutoGenValue(const AGeneratorName: string): Variant;
  end;

{ TFireDACORMTransaction }

constructor TFireDACORMTransaction.Create(AConnection: TFDConnection);
begin
  inherited Create;
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection');

  FTransaction := TFDTransaction.Create(nil);
  FTransaction.Connection := AConnection;
  FTransaction.StartTransaction;
  FCompleted := False;
end;

destructor TFireDACORMTransaction.Destroy;
begin
  if Assigned(FTransaction) and FTransaction.Active and (not FCompleted) then
    FTransaction.Rollback;
  FreeAndNil(FTransaction);
  inherited;
end;

procedure TFireDACORMTransaction.Commit;
begin
  if not Assigned(FTransaction) or FCompleted then
    Exit;

  if FTransaction.Active then
    FTransaction.Commit;
  FCompleted := True;
end;

procedure TFireDACORMTransaction.Rollback;
begin
  if not Assigned(FTransaction) or FCompleted then
    Exit;

  if FTransaction.Active then
    FTransaction.Rollback;
  FCompleted := True;
end;

{ TFireDACORMStorage }

constructor TFireDACORMStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  if not Assigned(AConnection) then
    raise EArgumentNilException.Create('AConnection');
  FConnection := AConnection;
end;

function TFireDACORMStorage.PrepareQuery(const SQL: string;
  const Params: array of Variant): TFDQuery;
var
  I: Integer;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
  Result.SQL.Text := SQL;
  for I := 0 to High(Params) do
    Result.Params[I].Value := Params[I];
end;

function TFireDACORMStorage.Execute(const SQL: string;
  const Params: array of Variant): Integer;
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

function TFireDACORMStorage.OpenDataSet(const SQL: string;
  const Params: array of Variant): TDataSet;
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

function TFireDACORMStorage.ExecuteScalar(const SQL: string;
  const Params: array of Variant): Variant;
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

function TFireDACORMStorage.BeginTransaction: IORMTransaction;
begin
  Result := TFireDACORMTransaction.Create(FConnection);
end;

function TFireDACORMStorage.GetLastAutoGenValue(
  const AGeneratorName: string): Variant;
begin
  Result := FConnection.GetLastAutoGenValue(AGeneratorName);
end;

function CreateORMStorage(AConnection: TFDConnection): IORMStorage;
begin
  Result := TFireDACORMStorage.Create(AConnection);
end;

procedure RegisterORMStorageFactory;
begin
  TDbContext.SetStorageFactory(
    function(AConnection: TObject): IORMStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for ORM FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateORMStorage(FDConnection);
    end);
end;

initialization
  RegisterORMStorageFactory;

end.

