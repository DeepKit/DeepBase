// AI-GENERATED
unit Test.DeepBase.SQLLoggerDialect;

interface

uses
  DUnitX.TestFramework,
  DeepBase.SQL.Utils,
  DeepBase.SQLLogger;

type
  [TestFixture]
  TSQLLoggerDialectTests = class
  public
    [Test]
    procedure DriverNameToDialect_ExactMatchTable;
    [Test]
    procedure DriverNameToDialect_CaseInsensitive_And_Alias;
    [Test]
    procedure DriverNameToDialect_UnknownDrivers_ReturnUnknown;
    [Test]
    procedure DialectContainsPostgres_LegacyContainsTrap_ReturnsFalse;
    [Test]
    procedure BuildCreateLogsTableSQL_SQLite_UsesAutoincrement;
    [Test]
    procedure BuildCreateLogsTableSQL_Postgres_UsesBigserialNoAutoincrement;
    [Test]
    procedure BuildCreateLogsTableSQL_UnsupportedDialect_Raises;
  end;

implementation

uses
  System.SysUtils;

{ TSQLLoggerDialectTests }

procedure TSQLLoggerDialectTests.DriverNameToDialect_ExactMatchTable;
begin
  Assert.AreEqual(Ord(sdSQLite), Ord(TSQLUtils.DriverNameToDialect('SQLITE')));
  Assert.AreEqual(Ord(sdPostgreSQL), Ord(TSQLUtils.DriverNameToDialect('PG')));
  Assert.AreEqual(Ord(sdMSSQL), Ord(TSQLUtils.DriverNameToDialect('MSSQL')));
  Assert.AreEqual(Ord(sdMySQL), Ord(TSQLUtils.DriverNameToDialect('MYSQL')));
end;

procedure TSQLLoggerDialectTests.DriverNameToDialect_CaseInsensitive_And_Alias;
begin
  // FireDAC real-world casing variations + DriverID alias used by some
  // deployment configs (Params.Values['DriverID'] = 'PostgreSQL').
  Assert.AreEqual(Ord(sdPostgreSQL), Ord(TSQLUtils.DriverNameToDialect('pg')));
  Assert.AreEqual(Ord(sdPostgreSQL), Ord(TSQLUtils.DriverNameToDialect('PostgreSQL')));
  Assert.AreEqual(Ord(sdSQLite), Ord(TSQLUtils.DriverNameToDialect('sqlite')));
  Assert.AreEqual(Ord(sdMSSQL), Ord(TSQLUtils.DriverNameToDialect('mssql')));
  Assert.AreEqual(Ord(sdMySQL), Ord(TSQLUtils.DriverNameToDialect('MySQL')));
end;

procedure TSQLLoggerDialectTests.DriverNameToDialect_UnknownDrivers_ReturnUnknown;
begin
  Assert.AreEqual(Ord(sdUnknown), Ord(TSQLUtils.DriverNameToDialect('')));
  Assert.AreEqual(Ord(sdUnknown), Ord(TSQLUtils.DriverNameToDialect('ORACLE')));
  Assert.AreEqual(Ord(sdUnknown), Ord(TSQLUtils.DriverNameToDialect('ODBC')));
  // 'postgres' is NOT a FireDAC driver name -- it must not silently map.
  Assert.AreEqual(Ord(sdUnknown), Ord(TSQLUtils.DriverNameToDialect('postgres')));
end;

procedure TSQLLoggerDialectTests.DialectContainsPostgres_LegacyContainsTrap_ReturnsFalse;
begin
  // A2-15 root cause pin: the legacy SQLLogger predicate
  // Conn.DriverName.ToLower.Contains('postgres') was ALWAYS False for a real
  // PG connection because FireDAC reports DriverName='PG'. Any future
  // "contains"-style dialect sniff reintroduces the same class of bug.
  const
    LRealPgDriverName = 'PG';
  Assert.IsFalse(LRealPgDriverName.ToLower.Contains('postgres'),
    'legacy Contains(postgres) predicate must remain false for real PG driver name');
  Assert.AreEqual(Ord(sdPostgreSQL), Ord(TSQLUtils.DriverNameToDialect(LRealPgDriverName)),
    'exact-match table is the only sanctioned dialect dispatch route');
end;

procedure TSQLLoggerDialectTests.BuildCreateLogsTableSQL_SQLite_UsesAutoincrement;
var
  SQL: string;
begin
  SQL := TSQLLogger.BuildCreateLogsTableSQL(sdSQLite);
  Assert.Contains(SQL, 'CREATE TABLE IF NOT EXISTS Logs');
  Assert.Contains(SQL, 'INTEGER PRIMARY KEY AUTOINCREMENT');
  Assert.IsFalse(SQL.Contains('BIGSERIAL'),
    'SQLite DDL must not contain PG-only BIGSERIAL');
end;

procedure TSQLLoggerDialectTests.BuildCreateLogsTableSQL_Postgres_UsesBigserialNoAutoincrement;
var
  SQL: string;
begin
  // This is the branch the legacy Contains('postgres') predicate could never
  // reach -- PG connections were handed SQLite AUTOINCREMENT DDL and the
  // CREATE failed on every write.
  SQL := TSQLLogger.BuildCreateLogsTableSQL(sdPostgreSQL);
  Assert.Contains(SQL, 'CREATE TABLE IF NOT EXISTS Logs');
  Assert.Contains(SQL, 'BIGSERIAL PRIMARY KEY');
  Assert.IsFalse(SQL.Contains('AUTOINCREMENT'),
    'PG DDL must not contain SQLite-only AUTOINCREMENT');
end;

procedure TSQLLoggerDialectTests.BuildCreateLogsTableSQL_UnsupportedDialect_Raises;
var
  Raised: Boolean;
  Unsupported: array[0..2] of TSQLDialect;
  D: TSQLDialect;
begin
  // fail-closed: no silent fallback to a foreign-engine DDL.
  Unsupported[0] := sdUnknown;
  Unsupported[1] := sdMSSQL;
  Unsupported[2] := sdMySQL;
  for D in Unsupported do
  begin
    Raised := False;
    try
      TSQLLogger.BuildCreateLogsTableSQL(D);
    except
      on E: EArgumentException do
        Raised := True;
    end;
    Assert.IsTrue(Raised,
      'unsupported dialect ' + IntToStr(Ord(D)) + ' must raise EArgumentException');
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSQLLoggerDialectTests);

end.
