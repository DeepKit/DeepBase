// AI-GENERATED
unit Test.DeepBase.AuthorizationUpsertDialect;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  FireDAC.Comp.Client,
  DeepBase.Authorization,
  DeepBase.SQL.Utils,
  DeepBase.Persistence.Authorization.FireDAC;

type
  [TestFixture]
  TAuthorizationUpsertDialectTests = class
  private
    FConnection: TFDConnection;
    FTempDir: string;
    function UserRoleRowCount: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure BuildInsertIgnoreSQL_SQLite_PreservesInsertOrIgnore;
    [Test]
    procedure BuildInsertIgnoreSQL_Postgres_UsesOnConflictDoNothing;
    [Test]
    procedure BuildInsertIgnoreSQL_UnsupportedDialects_RaiseFailClosed;
    [Test]
    procedure AssignUserRole_SQLite_RepeatedAssignIsIdempotent;
  end;

implementation

uses
  System.IOUtils,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef;

{ TAuthorizationUpsertDialectTests }

procedure TAuthorizationUpsertDialectTests.Setup;
begin
  // Same temp-file SQLite pattern as the other persistence tests
  // (in-memory SQLiteAdvanced crashes this environment).
  FTempDir := TPath.Combine(TPath.GetTempPath, 'db_a216_' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FTempDir);
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Database := TPath.Combine(FTempDir, 'auth.db');
  FConnection.Params.Values['OpenMode'] := 'CreateUTF8';
  FConnection.LoginPrompt := False;
  FConnection.Open;
end;

procedure TAuthorizationUpsertDialectTests.TearDown;
begin
  if Assigned(FConnection) then
  begin
    FConnection.Close;
    FConnection.Free;
    FConnection := nil;
  end;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TAuthorizationUpsertDialectTests.UserRoleRowCount: Integer;
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConnection;
    Q.Open('SELECT COUNT(*) AS N FROM auth_user_roles');
    Result := Q.FieldByName('N').AsInteger;
  finally
    Q.Free;
  end;
end;

procedure TAuthorizationUpsertDialectTests.BuildInsertIgnoreSQL_SQLite_PreservesInsertOrIgnore;
var
  SQL: string;
begin
  SQL := TSQLUtils.BuildInsertIgnoreSQL(sdSQLite,
    'auth_user_roles', 'user_id, role_id', ':user_id, :role_id',
    'user_id, role_id');
  Assert.AreEqual(
    'INSERT OR IGNORE INTO auth_user_roles (user_id, role_id) VALUES (:user_id, :role_id)',
    SQL);
  Assert.IsFalse(SQL.Contains('ON CONFLICT'),
    'SQLite branch must keep the native INSERT OR IGNORE form');
end;

procedure TAuthorizationUpsertDialectTests.BuildInsertIgnoreSQL_Postgres_UsesOnConflictDoNothing;
var
  SQL: string;
begin
  // The legacy hardcoded 'INSERT OR IGNORE' raised a syntax error on every
  // PG connection (A2-16). PG must get the standard upsert-ignore instead.
  SQL := TSQLUtils.BuildInsertIgnoreSQL(sdPostgreSQL,
    'auth_user_roles', 'user_id, role_id', ':user_id, :role_id',
    'user_id, role_id');
  Assert.IsTrue(SQL.Contains('ON CONFLICT (user_id, role_id) DO NOTHING'),
    'PG branch must use ON CONFLICT DO NOTHING, got: ' + SQL);
  Assert.IsFalse(SQL.Contains('INSERT OR IGNORE'),
    'PG branch must not contain SQLite-only INSERT OR IGNORE, got: ' + SQL);
  Assert.IsTrue(SQL.StartsWith('INSERT INTO '),
    'PG branch must be a plain INSERT with the conflict clause, got: ' + SQL);
end;

procedure TAuthorizationUpsertDialectTests.BuildInsertIgnoreSQL_UnsupportedDialects_RaiseFailClosed;
var
  Raised: Boolean;
  Unsupported: array[0..2] of TSQLDialect;
  D: TSQLDialect;
begin
  Unsupported[0] := sdUnknown;
  Unsupported[1] := sdMSSQL;
  Unsupported[2] := sdMySQL;
  for D in Unsupported do
  begin
    Raised := False;
    try
      TSQLUtils.BuildInsertIgnoreSQL(D, 't', 'a', ':a', 'a');
    except
      on E: EArgumentException do
        Raised := True;
    end;
    Assert.IsTrue(Raised,
      'unsupported dialect ' + IntToStr(Ord(D)) + ' must raise EArgumentException (fail-closed)');
  end;
end;

procedure TAuthorizationUpsertDialectTests.AssignUserRole_SQLite_RepeatedAssignIsIdempotent;
var
  Storage: IAuthorizationStorage;
  LUserId, LRole1, LRole2: Integer;
  LUserData: TAuthorizationUserData;
  LRoleData: TAuthorizationRoleData;
begin
  Storage := CreateAuthorizationStorage(FConnection);
  Storage.EnsureTablesExist;

  LUserData := Default(TAuthorizationUserData);
  LUserData.Username := 'a216_user';
  LUserData.IsActive := True;
  LUserId := Storage.InsertUser(LUserData);

  LRoleData := Default(TAuthorizationRoleData);
  LRoleData.Name := 'a216_role1';
  LRoleData.IsActive := True;
  LRole1 := Storage.InsertRole(LRoleData);
  LRoleData.Name := 'a216_role2';
  LRole2 := Storage.InsertRole(LRoleData);

  // Duplicate assign must be silently ignored (conflict on PK user_id, role_id)
  // thanks to the dialect-dispatched INSERT OR IGNORE -- no exception, no dup.
  Storage.AssignUserRole(LUserId, LRole1);
  Storage.AssignUserRole(LUserId, LRole1);
  Storage.AssignUserRole(LUserId, LRole1);
  Assert.AreEqual(1, UserRoleRowCount,
    'repeated identical AssignUserRole must stay idempotent');

  // A different role is a different PK -- must still insert.
  Storage.AssignUserRole(LUserId, LRole2);
  Assert.AreEqual(2, UserRoleRowCount,
    'distinct (user, role) pair must not be swallowed by the conflict clause');

  // And removing one leaves the other, proving both rows are real.
  Storage.RemoveUserRole(LUserId, LRole1);
  Assert.AreEqual(1, UserRoleRowCount, 'RemoveUserRole must delete exactly one row');
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthorizationUpsertDialectTests);

end.
