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
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO Settings (Key, Value, Category, Description) ' +
      'VALUES (''license_key'', :Value, ''License'', ''License activation key'')';
    Query.ParamByName('Value').AsString := LicenseKey;
    Query.ExecSQL;
  finally
    Query.Free;
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
