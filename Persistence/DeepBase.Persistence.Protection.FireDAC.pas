{ ============================================================================
  DeepBase.Persistence.Protection.FireDAC - FireDAC adapter for anti-tamper
  ============================================================================
  Moves SecureImages SQLite/FireDAC persistence out of service layer.
  ============================================================================ }

unit DeepBase.Persistence.Protection.FireDAC;

interface

uses
  DeepBase.Services.Interfaces;

function CreateAntiTamperStorage: IAntiTamperStorage;
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
