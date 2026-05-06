{ ============================================================================
  UniBase.Persistence.Protection.FireDAC - FireDAC adapter for anti-tamper
  ============================================================================
  Moves SecureImages SQLite/FireDAC persistence out of service layer.
  ============================================================================ }

unit UniBase.Persistence.Protection.FireDAC;

interface

uses
  UniBase.Services.Interfaces;

function CreateAntiTamperStorage: IAntiTamperStorage;
procedure RegisterAntiTamperStorageFactory;

implementation

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  UniBase.Services.Protection;

type
  TFireDACAntiTamperStorage = class(TInterfacedObject, IAntiTamperStorage)
  private
    procedure ConfigureConnection(AConnection: TFDConnection;
      const ADatabasePath: string);
  public
    procedure SetupDatabase(const DatabasePath: string);
    procedure SaveSecureImage(const DatabasePath, KeyName: string;
      const EncryptedImageData: TBytes; const Hash, CreatedAt: string);
    function TryLoadSecureImage(const DatabasePath, KeyName: string;
      out EncryptedImageData: TBytes; out Hash: string): Boolean;
  end;

procedure TFireDACAntiTamperStorage.ConfigureConnection(
  AConnection: TFDConnection; const ADatabasePath: string);
begin
  if ADatabasePath.Trim = '' then
    raise EArgumentException.Create(
      'AntiTamper DatabasePath is empty. Configure TAntiTamperConfig.DatabasePath before use.');

  AConnection.Params.Values['DriverID'] := 'SQLite';
  AConnection.Params.Values['Database'] := ADatabasePath;
  AConnection.Connected := True;
end;

procedure TFireDACAntiTamperStorage.SetupDatabase(const DatabasePath: string);
var
  Connection: TFDConnection;
begin
  Connection := TFDConnection.Create(nil);
  try
    ConfigureConnection(Connection, DatabasePath);
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS SecureImages (' +
      '  KeyName TEXT PRIMARY KEY, ' +
      '  ImageData BLOB, ' +
      '  Hash TEXT, ' +
      '  CreatedAt TEXT, ' +
      '  Enabled INTEGER DEFAULT 1' +
      ')');
  finally
    Connection.Free;
  end;
end;

procedure TFireDACAntiTamperStorage.SaveSecureImage(const DatabasePath,
  KeyName: string; const EncryptedImageData: TBytes; const Hash,
  CreatedAt: string);
var
  Connection: TFDConnection;
  Query: TFDQuery;
  Stream: TBytesStream;
begin
  Connection := TFDConnection.Create(nil);
  try
    ConfigureConnection(Connection, DatabasePath);

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO SecureImages (KeyName, ImageData, Hash, CreatedAt) ' +
        'VALUES (:KeyName, :ImageData, :Hash, :CreatedAt)';
      Query.ParamByName('KeyName').AsString := KeyName;
      Stream := TBytesStream.Create(EncryptedImageData);
      try
        Query.ParamByName('ImageData').LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
      Query.ParamByName('Hash').AsString := Hash;
      Query.ParamByName('CreatedAt').AsString := CreatedAt;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    Connection.Free;
  end;
end;

function TFireDACAntiTamperStorage.TryLoadSecureImage(const DatabasePath,
  KeyName: string; out EncryptedImageData: TBytes; out Hash: string): Boolean;
var
  Connection: TFDConnection;
  Query: TFDQuery;
begin
  Result := False;
  SetLength(EncryptedImageData, 0);
  Hash := '';

  Connection := TFDConnection.Create(nil);
  try
    ConfigureConnection(Connection, DatabasePath);

    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'SELECT ImageData, Hash FROM SecureImages ' +
        'WHERE KeyName = :KeyName AND Enabled = 1';
      Query.ParamByName('KeyName').AsString := KeyName;
      Query.Open;
      if Query.Eof then
        Exit(False);

      EncryptedImageData := Query.FieldByName('ImageData').AsBytes;
      Hash := Query.FieldByName('Hash').AsString;
      Result := True;
    finally
      Query.Free;
    end;
  finally
    Connection.Free;
  end;
end;

function CreateAntiTamperStorage: IAntiTamperStorage;
begin
  Result := TFireDACAntiTamperStorage.Create;
end;

procedure RegisterAntiTamperStorageFactory;
begin
  TAntiTamperServiceImpl.SetStorageFactory(
    function: IAntiTamperStorage
    begin
      Result := CreateAntiTamperStorage;
    end);
end;

initialization
  RegisterAntiTamperStorageFactory;

end.
