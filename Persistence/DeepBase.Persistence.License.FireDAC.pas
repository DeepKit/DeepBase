{ ============================================================================
  DeepBase.Persistence.License.FireDAC - FireDAC adapter for license storage
  ============================================================================
  Moves LicenseInfo SQL/FireDAC persistence out of Core\DeepBase.License.
  ============================================================================ }

unit DeepBase.Persistence.License.FireDAC;

interface

uses
  DeepBase.License,
  DeepBase.Storage.Interfaces,
  FireDAC.Comp.Client;

function CreateLicenseStorage(AConnection: TFDConnection): ILicenseStorage;
procedure RegisterLicenseStorageFactory;

implementation

uses
  System.SysUtils,
  FireDAC.Stan.Param;

type
  TFireDACLicenseStorage = class(TInterfacedObject, ILicenseStorage)
  private
    FConnection: TFDConnection;
  public
    constructor Create(AConnection: TFDConnection);
    function ReadLicenseKey: string;
    procedure WriteLicenseKey(const LicenseKey: string);
    procedure DeleteLicenseKey;
  end;

constructor TFireDACLicenseStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TFireDACLicenseStorage.ReadLicenseKey: string;
var
  Query: TFDQuery;
begin
  Result := '';

  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = ''license_key''';
    Query.Open;
    if not Query.Eof then
      Result := Query.FieldByName('Value').AsString;
  finally
    Query.Free;
  end;
end;

procedure TFireDACLicenseStorage.WriteLicenseKey(const LicenseKey: string);
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
      'UPDATE Settings SET Value = :Value, Category = ''License'', ' +
      'Description = ''License activation key'' WHERE Key = ''license_key''';
    UpdateQuery.ParamByName('Value').AsString := LicenseKey;
    UpdateQuery.ExecSQL;

    if UpdateQuery.RowsAffected = 0 then
    begin
      ExistsQuery.Connection := FConnection;
      ExistsQuery.SQL.Text := 'SELECT 1 FROM Settings WHERE Key = ''license_key''';
      ExistsQuery.Open;
      try
        if ExistsQuery.Eof then
        begin
          InsertQuery.Connection := FConnection;
          InsertQuery.SQL.Text :=
            'INSERT INTO Settings (Key, Value, Category, Description) ' +
            'VALUES (''license_key'', :Value, ''License'', ''License activation key'')';
          InsertQuery.ParamByName('Value').AsString := LicenseKey;
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

procedure TFireDACLicenseStorage.DeleteLicenseKey;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM Settings WHERE Key = ''license_key''';
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function CreateLicenseStorage(AConnection: TFDConnection): ILicenseStorage;
begin
  Result := TFireDACLicenseStorage.Create(AConnection);
end;

procedure RegisterLicenseStorageFactory;
begin
  TDeepBaseLicense.SetStorageFactory(
    function(AConnection: TObject): ILicenseStorage
    var
      FDConnection: TFDConnection;
    begin
      if not (AConnection is TFDConnection) then
        raise EInvalidCast.Create(
          'Expected TFDConnection for License FireDAC storage.');
      FDConnection := TFDConnection(AConnection);
      Result := CreateLicenseStorage(FDConnection);
    end);
end;

initialization
  RegisterLicenseStorageFactory;

end.
