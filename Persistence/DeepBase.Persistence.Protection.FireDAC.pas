{ ============================================================================
  DeepBase.Persistence.Protection.FireDAC - FireDAC adapter for anti-tamper
  ============================================================================
  Moves SecureImages SQLite/FireDAC persistence out of service layer.
  ============================================================================ }

unit DeepBase.Persistence.Protection.FireDAC;

interface

uses
  DeepBase.Services.Interfaces,
  DeepBase.Storage.Interfaces;

function CreateAntiTamperStorage: IAntiTamperStorage;
function CreateAntiTamperImageStorage(
  const DatabasePath: string): IAntiTamperImageStorage;
procedure RegisterAntiTamperStorageFactory;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Data.DB,
  FireDAC.Comp.Client,
  DeepBase.Services.Protection;

type
  TFireDACAntiTamperStorage = class(TInterfacedObject, IAntiTamperStorage)
  private
    // PERSIST-017: cache the FireDAC connection per DatabasePath. Without
    // caching, every SaveSecureImage / TryLoadSecureImage / SetupDatabase
    // call paid for a full TFDConnection.Open + close, which on SQLite means
    // re-opening the file, re-applying PRAGMAs, and (on first use) running
    // the journal startup. The cache is keyed by DatabasePath so callers
    // that legitimately address multiple stores still work.
    FLock: TCriticalSection;
    FCachedConnection: TFDConnection;
    FCachedDatabasePath: string;

    function AcquireConnection(const ADatabasePath: string): TFDConnection;
    procedure ConfigureConnection(AConnection: TFDConnection;
      const ADatabasePath: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetupDatabase(const DatabasePath: string);
    procedure SaveSecureImage(const DatabasePath, KeyName: string;
      const EncryptedImageData: TBytes; const Hash, CreatedAt: string);
    function TryLoadSecureImage(const DatabasePath, KeyName: string;
      out EncryptedImageData: TBytes; out Hash: string): Boolean;
  end;

  TFireDACAntiTamperImageStorage = class(TInterfacedObject,
    IAntiTamperImageStorage)
  private
    FLock: TCriticalSection;
    FConnection: TFDConnection;
    FDatabasePath: string;
    function Connection: TFDConnection;
    class procedure ValidateTableName(const TableName: string); static;
  public
    constructor Create(const ADatabasePath: string);
    destructor Destroy; override;
    function SetupDatabase(const TableName: string): Boolean;
    function UpgradeDatabase(const TableName: string): Boolean;
    procedure ClearTable(const TableName: string);
    procedure ReseedMinimal(const TableName: string;
      const Data: TAntiTamperImageData);
    procedure SaveSecureImage(const TableName: string;
      const Data: TAntiTamperImageData);
    function TryLoadSecureImage(const TableName, ImageKey: string;
      out Data: TAntiTamperImageData): Boolean;
    function IsSecureImageEnabled(const TableName, ImageKey: string): Boolean;
  end;

constructor TFireDACAntiTamperStorage.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TFireDACAntiTamperStorage.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FCachedConnection);
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
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

function TFireDACAntiTamperStorage.AcquireConnection(
  const ADatabasePath: string): TFDConnection;
begin
  FLock.Enter;
  try
    // Reuse existing cached connection if still pointing at the same DB
    // and still actually open. SQLite locking will serialize access between
    // our own callers; FLock keeps the hand-off race-free.
    if (FCachedConnection <> nil) and
       SameText(FCachedDatabasePath, ADatabasePath) and
       FCachedConnection.Connected then
      Exit(FCachedConnection);

    // DB path changed (or stale) -- drop the old one before configuring fresh.
    FreeAndNil(FCachedConnection);
    FCachedDatabasePath := '';

    FCachedConnection := TFDConnection.Create(nil);
    try
      ConfigureConnection(FCachedConnection, ADatabasePath);
      FCachedDatabasePath := ADatabasePath;
      Result := FCachedConnection;
    except
      FreeAndNil(FCachedConnection);
      raise;
    end;
  finally
    FLock.Leave;
  end;
end;

constructor TFireDACAntiTamperImageStorage.Create(const ADatabasePath: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FDatabasePath := ADatabasePath;
end;

destructor TFireDACAntiTamperImageStorage.Destroy;
begin
  FLock.Enter;
  try
    FreeAndNil(FConnection);
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

function TFireDACAntiTamperImageStorage.Connection: TFDConnection;
begin
  if FDatabasePath.Trim = '' then
    raise EArgumentException.Create('AntiTamper database path is empty.');

  if (FConnection <> nil) and FConnection.Connected then
    Exit(FConnection);

  FreeAndNil(FConnection);
  FConnection := TFDConnection.Create(nil);
  try
    FConnection.Params.Values['DriverID'] := 'SQLite';
    FConnection.Params.Values['Database'] := FDatabasePath;
    FConnection.LoginPrompt := False;
    FConnection.Connected := True;
    Result := FConnection;
  except
    FreeAndNil(FConnection);
    raise;
  end;
end;
class procedure TFireDACAntiTamperImageStorage.ValidateTableName(
  const TableName: string);
begin
  if TableName.IsEmpty then
    raise EArgumentException.Create('Table name is empty.');

  if not TableName.StartsWith('_') and
     not CharInSet(TableName[1], ['A'..'Z', 'a'..'z']) then
    raise EArgumentException.CreateFmt('Invalid table name: %s', [TableName]);

  for var Ch in TableName do
    if not CharInSet(Ch, ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      raise EArgumentException.CreateFmt('Invalid table name: %s', [TableName]);
end;

procedure TFireDACAntiTamperStorage.SetupDatabase(const DatabasePath: string);
var
  Connection: TFDConnection;
begin
  FLock.Enter;
  try
    Connection := AcquireConnection(DatabasePath);
    Connection.ExecSQL(
      'CREATE TABLE IF NOT EXISTS SecureImages (' +
      '  KeyName TEXT PRIMARY KEY, ' +
      '  ImageData BLOB, ' +
      '  Hash TEXT, ' +
      '  CreatedAt TEXT, ' +
      '  Enabled INTEGER DEFAULT 1' +
      ')');
  finally
    FLock.Leave;
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
  FLock.Enter;
  try
    Connection := AcquireConnection(DatabasePath);

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
    FLock.Leave;
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

  FLock.Enter;
  try
    Connection := AcquireConnection(DatabasePath);

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
    FLock.Leave;
  end;
end;

function TFireDACAntiTamperImageStorage.SetupDatabase(
  const TableName: string): Boolean;
var
  Conn: TFDConnection;
begin
  Result := False;
  ValidateTableName(TableName);

  FLock.Enter;
  try
    Conn := Connection;
    Conn.ExecSQL(
      'CREATE TABLE IF NOT EXISTS ' + TableName + ' (' +
      '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
      '  image_key TEXT NOT NULL UNIQUE,' +
      '  image_data BLOB NOT NULL,' +
      '  address_text TEXT,' +
      '  description TEXT,' +
      '  enabled INTEGER NOT NULL DEFAULT 1,' +
      '  sha256_hash TEXT NOT NULL,' +
      '  hmac_sha256 TEXT NOT NULL,' +
      '  md5_hash TEXT,' +
      '  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,' +
      '  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP' +
      ')');
    Result := UpgradeDatabase(TableName);
  finally
    FLock.Leave;
  end;
end;

function TFireDACAntiTamperImageStorage.UpgradeDatabase(
  const TableName: string): Boolean;
var
  Conn: TFDConnection;
  ColumnName: string;
  Sql: string;
begin
  Result := False;
  ValidateTableName(TableName);

  FLock.Enter;
  try
    Conn := Connection;
    for ColumnName in ['sha256_hash TEXT', 'hmac_sha256 TEXT',
      'enabled INTEGER NOT NULL DEFAULT 1', 'md5_hash TEXT',
      'description TEXT'] do
    begin
      try
        Sql := 'ALTER TABLE ' + TableName + ' ADD COLUMN ' + ColumnName;
        Conn.ExecSQL(Sql);
      except
        // Column already exists or legacy table is absent; caller can still
        // continue because SetupDatabase creates the modern table first.
      end;
    end;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACAntiTamperImageStorage.ClearTable(const TableName: string);
var
  Sql: string;
begin
  ValidateTableName(TableName);
  FLock.Enter;
  try
    Sql := 'DELETE FROM ' + TableName + ' WHERE 1 = 1';
    Connection.ExecSQL(Sql);
  finally
    FLock.Leave;
  end;
end;

procedure TFireDACAntiTamperImageStorage.ReseedMinimal(const TableName: string;
  const Data: TAntiTamperImageData);
begin
  SaveSecureImage(TableName, Data);
end;

procedure TFireDACAntiTamperImageStorage.SaveSecureImage(const TableName: string;
  const Data: TAntiTamperImageData);
var
  Query: TFDQuery;
  Stream: TBytesStream;
begin
  ValidateTableName(TableName);

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO ' + TableName +
        ' (image_key, image_data, address_text, description, sha256_hash, hmac_sha256, md5_hash, enabled) ' +
        'VALUES (:key, :data, :addr, :desc, :sha, :hmac, :md5, :enabled)';
      Query.ParamByName('key').AsString := Data.ImageKey;
      Stream := TBytesStream.Create(Data.EncryptedImageData);
      try
        Query.ParamByName('data').LoadFromStream(Stream, ftBlob);
      finally
        Stream.Free;
      end;
      Query.ParamByName('addr').AsString := Data.AddressText;
      Query.ParamByName('desc').AsString := Data.Description;
      Query.ParamByName('sha').AsString := Data.Sha256Hash;
      Query.ParamByName('hmac').AsString := Data.HmacSha256;
      Query.ParamByName('md5').AsString := '';
      Query.ParamByName('enabled').AsInteger := Ord(Data.IsEnabled);
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFireDACAntiTamperImageStorage.TryLoadSecureImage(const TableName,
  ImageKey: string; out Data: TAntiTamperImageData): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Data.ImageKey := ImageKey;
  Data.EncryptedImageData := nil;
  Data.AddressText := '';
  Data.Description := '';
  Data.Sha256Hash := '';
  Data.HmacSha256 := '';
  Data.IsEnabled := False;
  ValidateTableName(TableName);

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'SELECT image_data, address_text, description, sha256_hash, hmac_sha256, enabled ' +
        'FROM ' + TableName + ' WHERE image_key = :key';
      Query.ParamByName('key').AsString := ImageKey;
      Query.Open;
      if Query.Eof then
        Exit(False);

      Data.EncryptedImageData := Query.FieldByName('image_data').AsBytes;
      Data.AddressText := Query.FieldByName('address_text').AsString;
      Data.Description := Query.FieldByName('description').AsString;
      Data.Sha256Hash := Query.FieldByName('sha256_hash').AsString;
      Data.HmacSha256 := Query.FieldByName('hmac_sha256').AsString;
      Data.IsEnabled := Query.FieldByName('enabled').AsInteger <> 0;
      Result := True;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFireDACAntiTamperImageStorage.IsSecureImageEnabled(const TableName,
  ImageKey: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := True;
  ValidateTableName(TableName);

  FLock.Enter;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Connection;
      Query.SQL.Text :=
        'SELECT enabled FROM ' + TableName + ' WHERE image_key = :key';
      Query.ParamByName('key').AsString := ImageKey;
      Query.Open;
      if not Query.Eof then
        Result := Query.FieldByName('enabled').AsInteger <> 0;
    finally
      Query.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function CreateAntiTamperStorage: IAntiTamperStorage;
begin
  Result := TFireDACAntiTamperStorage.Create;
end;

function CreateAntiTamperImageStorage(
  const DatabasePath: string): IAntiTamperImageStorage;
begin
  Result := TFireDACAntiTamperImageStorage.Create(DatabasePath);
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
