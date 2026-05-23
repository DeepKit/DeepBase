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
  System.SyncObjs,
  DeepBase.Security.DPAPI,
  FireDAC.Stan.Param;

type
  TFireDACLicenseStorage = class(TInterfacedObject, ILicenseStorage)
  private
    FConnection: TFDConnection;
    FLock: TCriticalSection;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    function ReadLicenseKey: string;
    procedure WriteLicenseKey(const LicenseKey: string);
    procedure DeleteLicenseKey;
  end;

constructor TFireDACLicenseStorage.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FLock := TCriticalSection.Create;
end;

destructor TFireDACLicenseStorage.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TFireDACLicenseStorage.ReadLicenseKey: string;
var
  Query: TFDQuery;
  Encrypted: string;
begin
  Result := '';

  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = ''license_key''';
      Query.Open;
      if not Query.Eof then
      begin
        Encrypted := Query.FieldByName('Value').AsString;
        if Encrypted <> '' then
        begin
          try
            Result := TDPAPIHelper.UnprotectString(Encrypted);
          except
            // If DPAPI decryption fails, treat as no license
            Result := '';
          end;
        end;
      end;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACLicenseStorage.WriteLicenseKey(const LicenseKey: string);
var
  Query: TFDQuery;
  Encrypted: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  Encrypted := TDPAPIHelper.ProtectString(LicenseKey);

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO Settings (Key, Value, Category, Description) ' +
        'VALUES (''license_key'', :Value, ''License'', ''License activation key'')';
      Query.ParamByName('Value').AsString := Encrypted;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACLicenseStorage.DeleteLicenseKey;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM Settings WHERE Key = ''license_key''';
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
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
