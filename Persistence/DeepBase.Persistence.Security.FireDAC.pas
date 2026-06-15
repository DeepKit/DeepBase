{ ============================================================================
  DeepBase.Persistence.Security.FireDAC - FireDAC adapter for security secrets
  ============================================================================
  Moves Secrets SQL/FireDAC persistence out of Core\DeepBase.Security.
  ============================================================================
}

unit DeepBase.Persistence.Security.FireDAC;

interface

uses
  DeepBase.Security,
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateSecuritySecretStorage(
  AConnection: TFDConnection): ISecuritySecretStorage;
procedure RegisterSecurityStorageFactory;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Stan.Param,
  DeepBase.Consts;

type
  TFireDACSecuritySecretStorage = class(TInterfacedObject, ISecuritySecretStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    procedure EnsureSecretsTable;
    function TryReadCipherBlob(const AName: string; out ACipherBlobBase64: string): Boolean;
    procedure UpsertSecret(const AName, ACipherBlobBase64, ADescription,
      AUpdatedAtIso8601: string);
    procedure DeleteSecret(const AName: string);
    function SecretExists(const AName: string): Boolean;
    function ReadSecretNames: TArray<string>;
  end;

constructor TFireDACSecuritySecretStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TFireDACSecuritySecretStorage.EnsureSecretsTable;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS ' + STableSecrets + ' (' +
    '  Name        TEXT PRIMARY KEY,' +
    '  CipherBlob  TEXT NOT NULL,' +
    '  Description TEXT,' +
    '  CreatedAt   TEXT NOT NULL,' +
    '  UpdatedAt   TEXT NOT NULL' +
    ')'
  );
end;

function TFireDACSecuritySecretStorage.TryReadCipherBlob(const AName: string;
  out ACipherBlobBase64: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  ACipherBlobBase64 := '';

  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT CipherBlob FROM ' + STableSecrets +
      ' WHERE Name = :Name';
    Query.ParamByName('Name').AsString := AName;
    Query.Open;

    Result := not Query.Eof;
    if Result then
      ACipherBlobBase64 := Query.FieldByName('CipherBlob').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACSecuritySecretStorage.UpsertSecret(const AName,
  ACipherBlobBase64, ADescription, AUpdatedAtIso8601: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO ' + STableSecrets +
      ' (Name, CipherBlob, Description, CreatedAt, UpdatedAt) ' +
      'VALUES (:Name, :CipherBlob, :Description, ' +
      'COALESCE((SELECT CreatedAt FROM ' + STableSecrets + ' WHERE Name = :Name2), :CreatedAt), ' +
      ':UpdatedAt)';
    Query.ParamByName('Name').AsString := AName;
    Query.ParamByName('Name2').AsString := AName;
    Query.ParamByName('CipherBlob').AsString := ACipherBlobBase64;
    Query.ParamByName('Description').AsString := ADescription;
    Query.ParamByName('CreatedAt').AsString := AUpdatedAtIso8601;
    Query.ParamByName('UpdatedAt').AsString := AUpdatedAtIso8601;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TFireDACSecuritySecretStorage.DeleteSecret(const AName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM ' + STableSecrets + ' WHERE Name = :Name';
    Query.ParamByName('Name').AsString := AName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TFireDACSecuritySecretStorage.SecretExists(const AName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;

  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT 1 FROM ' + STableSecrets + ' WHERE Name = :Name';
    Query.ParamByName('Name').AsString := AName;
    Query.Open;
    Result := not Query.Eof;
  finally
    Query.Free;
  end;
end;

function TFireDACSecuritySecretStorage.ReadSecretNames: TArray<string>;
var
  Query: TFDQuery;
  Names: TList<string>;
begin
  SetLength(Result, 0);

  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Names := TList<string>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Name FROM ' + STableSecrets + ' ORDER BY Name';
      Query.Open;

      while not Query.Eof do
      begin
        Names.Add(Query.FieldByName('Name').AsString);
        Query.Next;
      end;
    finally
      Query.Free;
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

function CreateSecuritySecretStorage(
  AConnection: TFDConnection): ISecuritySecretStorage;
begin
  Result := TFireDACSecuritySecretStorage.Create(AConnection);
end;

procedure RegisterSecurityStorageFactory;
begin
  TDeepBaseSecurity.SetStorageFactory(
    function(AConnection: TObject): ISecuritySecretStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for Security FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateSecuritySecretStorage(FDConnection);
    end);
end;

initialization
  RegisterSecurityStorageFactory;

end.
