unit Test.DeepBase.DB.Factory;

interface

uses
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  DeepBase.DB.Factory;

type
  [TestFixture]
  TTestDBConnectionFactory = class
  private
    FTempDir: string;
    FLocalDBPath: string;
    procedure CreateSettingsTable;
    procedure WriteSetting(const Key, Value: string);
    function ReadSetting(const Key: string): string;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_GetLocal_OpensConfiguredSQLite;

    [Test]
    procedure Test_LoadSharedProfile_FromLocalSettings;

    [Test]
    procedure Test_CreateSharedUnopenedConnection_FromLocalSettings_NoPGOpen;

    [Test]
    procedure Test_CreateSharedUnopenedConnection_FromLocalSettings_SQLite;

    [Test]
    procedure Test_VerifyBoth_ReturnsFalseWhenSharedSettingsMissing;

    {$IFDEF MSWINDOWS}
    [Test]
    procedure Test_LoadSharedProfile_MigratesPlainPasswordToCredentialManager;

    [Test]
    procedure Test_LoadSharedProfile_ResolvesCredentialReferencePassword;
    {$ENDIF}
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.StrUtils,
  FireDAC.Stan.Param,
  DeepBase.DB.Pool
  {$IFDEF MSWINDOWS}
  , DeepBase.Security.DPAPI
  {$ENDIF};

procedure TTestDBConnectionFactory.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_DBFactory_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FLocalDBPath := TPath.Combine(FTempDir, 'config.db');
  TDBConnectionFactory.Reset;
  TDBConnectionFactory.Configure(FLocalDBPath, FTempDir);
end;

procedure TTestDBConnectionFactory.TearDown;
begin
  TDBConnectionFactory.Reset;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

procedure TTestDBConnectionFactory.CreateSettingsTable;
var
  Conn: TFDConnection;
begin
  Conn := TDBConnectionFactory.GetLocal;
  try
    Conn.ExecSQL(
      'CREATE TABLE IF NOT EXISTS Settings (' +
      'Key TEXT PRIMARY KEY, Value TEXT)');
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionFactory.WriteSetting(const Key, Value: string);
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Conn := TDBConnectionFactory.GetLocal;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text :=
        'INSERT OR REPLACE INTO Settings (Key, Value) VALUES (:Key, :Value)';
      Query.ParamByName('Key').AsString := Key;
      Query.ParamByName('Value').AsString := Value;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

function TTestDBConnectionFactory.ReadSetting(const Key: string): string;
var
  Conn: TFDConnection;
  Query: TFDQuery;
begin
  Result := '';
  Conn := TDBConnectionFactory.GetLocal;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := Conn;
      Query.SQL.Text := 'SELECT Value FROM Settings WHERE Key = :Key';
      Query.ParamByName('Key').AsString := Key;
      Query.Open;
      if not Query.Eof then
        Result := Query.FieldByName('Value').AsString;
    finally
      Query.Free;
    end;
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionFactory.Test_GetLocal_OpensConfiguredSQLite;
var
  Conn: TFDConnection;
begin
  Conn := TDBConnectionFactory.GetLocal;
  try
    Assert.IsTrue(Conn.Connected);
    Assert.AreEqual('SQLite', Conn.DriverName);
    Assert.AreEqual(FLocalDBPath, Conn.Params.Database);
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionFactory.Test_LoadSharedProfile_FromLocalSettings;
var
  Profile: TDBConnectionProfile;
begin
  CreateSettingsTable;
  WriteSetting('DB3.Type', 'PostgreSQL');
  WriteSetting('DB3.Server', 'db.internal');
  WriteSetting('DB3.Port', '6432');
  WriteSetting('DB3.Database', 'betterciv');
  WriteSetting('DB3.User', 'app_user');
  WriteSetting('DB3.Password', 'secret');
  WriteSetting('DB3.ApplicationName', 'collector');
  WriteSetting('DB3.SSLMode', 'require');

  Profile := TDBConnectionFactory.LoadSharedProfile;

  Assert.AreEqual(dbPostgreSQL, Profile.DatabaseType);
  Assert.AreEqual('db.internal', Profile.Host);
  Assert.AreEqual(6432, Profile.Port);
  Assert.AreEqual('betterciv', Profile.Database);
  Assert.AreEqual('app_user', Profile.Username);
  Assert.AreEqual('collector', Profile.ApplicationName);
  Assert.AreEqual('require', Profile.SSLMode);
end;

procedure TTestDBConnectionFactory.Test_CreateSharedUnopenedConnection_FromLocalSettings_NoPGOpen;
var
  Conn: TFDConnection;
begin
  CreateSettingsTable;
  WriteSetting('DB3.Type', 'PG');
  WriteSetting('DB3.Server', 'pgbouncer.internal');
  WriteSetting('DB3.Port', '6432');
  WriteSetting('DB3.Database', 'betterciv');
  WriteSetting('DB3.User', 'app_user');
  WriteSetting('DB3.Password', 'secret;with;semicolons');
  WriteSetting('DB3.SSLMode', 'prefer');
  WriteSetting('DB3.CommandTimeoutSec', '9');
  WriteSetting('DB3.ExtraParams', 'MetaDefSchema=public');

  Conn := TDBConnectionFactory.CreateSharedUnopenedConnection;
  try
    Assert.IsFalse(Conn.Connected);
    Assert.AreEqual('PG', Conn.DriverName);
    Assert.AreEqual('pgbouncer.internal', Conn.Params.Values['Server']);
    Assert.AreEqual('6432', Conn.Params.Values['Port']);
    Assert.AreEqual('betterciv', Conn.Params.Database);
    Assert.AreEqual('app_user', Conn.Params.UserName);
    Assert.AreEqual('secret;with;semicolons', Conn.Params.Password);
    Assert.AreEqual('sslmode=prefer', Conn.Params.Values['PGAdvanced']);
    Assert.AreEqual('public', Conn.Params.Values['MetaDefSchema']);
    Assert.AreEqual(9000, Conn.ResourceOptions.CmdExecTimeout);
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionFactory.Test_CreateSharedUnopenedConnection_FromLocalSettings_SQLite;
var
  Conn: TFDConnection;
  ExpectedPath: string;
begin
  CreateSettingsTable;
  WriteSetting('DB3.Type', 'SQLite');
  WriteSetting('DB3.Database', 'shared\biz.db');
  WriteSetting('DB3.SQLiteLockingMode', 'Exclusive');
  WriteSetting('DB3.SQLiteSynchronous', 'Off');
  WriteSetting('DB3.SQLiteJournalMode', 'Memory');
  WriteSetting('DB3.SQLiteOpenMode', 'CreateUTF8');
  WriteSetting('DB3.CommandTimeoutSec', '7');
  WriteSetting('DB3.ExtraParams', 'Cache=Shared');

  Conn := TDBConnectionFactory.CreateSharedUnopenedConnection;
  try
    ExpectedPath := TPath.Combine(FTempDir, 'shared\biz.db');
    Assert.IsFalse(Conn.Connected);
    Assert.AreEqual('SQLite', Conn.DriverName);
    Assert.AreEqual(ExpectedPath, Conn.Params.Database);
    Assert.AreEqual('Exclusive', Conn.Params.Values['LockingMode']);
    Assert.AreEqual('Off', Conn.Params.Values['Synchronous']);
    Assert.AreEqual('Memory', Conn.Params.Values['JournalMode']);
    Assert.AreEqual('CreateUTF8', Conn.Params.Values['OpenMode']);
    Assert.AreEqual('Shared', Conn.Params.Values['Cache']);
    Assert.AreEqual(7000, Conn.ResourceOptions.CmdExecTimeout);
  finally
    Conn.Free;
  end;
end;

procedure TTestDBConnectionFactory.Test_VerifyBoth_ReturnsFalseWhenSharedSettingsMissing;
begin
  Assert.IsFalse(TDBConnectionFactory.VerifyBoth);
  Assert.IsNotEmpty(TDBConnectionFactory.LastError);
end;

{$IFDEF MSWINDOWS}
procedure TTestDBConnectionFactory.Test_LoadSharedProfile_MigratesPlainPasswordToCredentialManager;
const
  CREDENTIAL_TARGET = 'DeepBase_DB3_PostgreSQL_Password';
  PLAIN_PASSWORD = 'secret-plain-password';
var
  Profile: TDBConnectionProfile;
  StoredPassword: string;
begin
  TCredentialManager.DeleteCredential(CREDENTIAL_TARGET);
  try
    CreateSettingsTable;
    WriteSetting('DB3.Type', 'PostgreSQL');
    WriteSetting('DB3.Server', 'db.internal');
    WriteSetting('DB3.Port', '5432');
    WriteSetting('DB3.Database', 'betterciv');
    WriteSetting('DB3.User', 'app_user');
    WriteSetting('DB3.Password', PLAIN_PASSWORD);

    Profile := TDBConnectionFactory.LoadSharedProfile;
    StoredPassword := ReadSetting('DB3.Password');

    Assert.AreEqual(PLAIN_PASSWORD, Profile.Password);
    Assert.IsTrue(StartsText('credman:', StoredPassword),
      'DB3.Password should be migrated to a Credential Manager reference');
    Assert.AreNotEqual(PLAIN_PASSWORD, StoredPassword,
      'DB3.Password should no longer store plaintext');
    Assert.AreEqual(PLAIN_PASSWORD,
      TCredentialManager.GetCredential(CREDENTIAL_TARGET, ''));
  finally
    TCredentialManager.DeleteCredential(CREDENTIAL_TARGET);
  end;
end;

procedure TTestDBConnectionFactory.Test_LoadSharedProfile_ResolvesCredentialReferencePassword;
const
  CREDENTIAL_TARGET = 'DeepBase_DB3_PostgreSQL_Password';
  SECRET_PASSWORD = 'secret-from-credential-manager';
var
  Profile: TDBConnectionProfile;
begin
  TCredentialManager.DeleteCredential(CREDENTIAL_TARGET);
  try
    TCredentialManager.SaveCredential(CREDENTIAL_TARGET, '', SECRET_PASSWORD);

    CreateSettingsTable;
    WriteSetting('DB3.Type', 'PostgreSQL');
    WriteSetting('DB3.Server', 'db.internal');
    WriteSetting('DB3.Port', '5432');
    WriteSetting('DB3.Database', 'betterciv');
    WriteSetting('DB3.User', 'app_user');
    WriteSetting('DB3.Password', 'credman:' + CREDENTIAL_TARGET);

    Profile := TDBConnectionFactory.LoadSharedProfile;

    Assert.AreEqual(SECRET_PASSWORD, Profile.Password);
    Assert.AreEqual('credman:' + CREDENTIAL_TARGET, ReadSetting('DB3.Password'),
      'Credential reference should remain stored in Settings');
  finally
    TCredentialManager.DeleteCredential(CREDENTIAL_TARGET);
  end;
end;
{$ENDIF}

initialization
  TDUnitX.RegisterTestFixture(TTestDBConnectionFactory);

end.
