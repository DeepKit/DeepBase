{ ============================================================================
  Test.UniBase.Schema - Unit Tests for Database Schema Module
  
  Test Coverage:
    - Schema version constants
    - Tier 0/1/2 table SQL definitions
    - SQL validation and structure
  ============================================================================ }

unit Test.UniBase.Schema;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  UniBase.Schema;

type
  [TestFixture]
  TTestSchemaVersion = class
  public
    [Test]
    procedure Test_SCHEMA_VERSION_Format;
    [Test]
    procedure Test_SCHEMA_VERSION_NonEmpty;
    [Test]
    procedure Test_SCHEMA_MAJOR_VERSION;
    [Test]
    procedure Test_SCHEMA_MINOR_VERSION;
  end;

  [TestFixture]
  TTestTier0Schema = class
  public
    [Test]
    procedure Test_SQL_CREATE_CONFIG_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_CONFIG_HasPrimaryKey;
    [Test]
    procedure Test_SQL_CREATE_CONFIG_HasKeyColumn;
    [Test]
    procedure Test_SQL_CREATE_CONFIG_HasValueColumn;
    [Test]
    procedure Test_SQL_CREATE_LOG_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_LOG_HasTimestamp;
    [Test]
    procedure Test_SQL_CREATE_LOG_HasLevel;
    [Test]
    procedure Test_SQL_CREATE_LOG_HasMessage;
  end;

  [TestFixture]
  TTestTier1Schema = class
  public
    [Test]
    procedure Test_SQL_CREATE_USER_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_USER_HasIdColumn;
    [Test]
    procedure Test_SQL_CREATE_USER_HasNameColumn;
    [Test]
    procedure Test_SQL_CREATE_SESSION_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_SESSION_HasTokenColumn;
    [Test]
    procedure Test_SQL_CREATE_SESSION_HasUserIdColumn;
    [Test]
    procedure Test_SQL_CREATE_SESSION_HasExpiresAt;
  end;

  [TestFixture]
  TTestTier2Schema = class
  public
    [Test]
    procedure Test_SQL_CREATE_AUDIT_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_AUDIT_HasAction;
    [Test]
    procedure Test_SQL_CREATE_AUDIT_HasUserId;
    [Test]
    procedure Test_SQL_CREATE_CACHE_NotEmpty;
    [Test]
    procedure Test_SQL_CREATE_CACHE_HasKey;
    [Test]
    procedure Test_SQL_CREATE_CACHE_HasExpiry;
  end;

  [TestFixture]
  TTestSchemaHelpers = class
  public
    [Test]
    procedure Test_GetTier0SchemaSQL_ReturnsSQL;
    [Test]
    procedure Test_GetTier1SchemaSQL_ReturnsSQL;
    [Test]
    procedure Test_GetTier2SchemaSQL_ReturnsSQL;
    [Test]
    procedure Test_GetFullSchemaSQL_ContainsTier0;
    [Test]
    procedure Test_GetFullSchemaSQL_ContainsTier1;
    [Test]
    procedure Test_GetFullSchemaSQL_ContainsTier2;
    [Test]
    procedure Test_GetSchemaVersion_NotEmpty;
  end;

implementation

{ TTestSchemaVersion }

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_Format;
begin
  // Version should be in format like "1.0", "1.2", etc.
  Assert.IsTrue(SCHEMA_VERSION.Contains('.'), 'Version should contain a dot separator');
end;

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_NonEmpty;
begin
  Assert.IsNotEmpty(SCHEMA_VERSION);
end;

procedure TTestSchemaVersion.Test_SCHEMA_MAJOR_VERSION;
begin
  Assert.IsTrue(SCHEMA_MAJOR_VERSION >= 1, 'Major version should be at least 1');
end;

procedure TTestSchemaVersion.Test_SCHEMA_MINOR_VERSION;
begin
  Assert.IsTrue(SCHEMA_MINOR_VERSION >= 0, 'Minor version should be non-negative');
end;

{ TTestTier0Schema }

procedure TTestTier0Schema.Test_SQL_CREATE_CONFIG_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_CONFIG);
end;

procedure TTestTier0Schema.Test_SQL_CREATE_CONFIG_HasPrimaryKey;
begin
  Assert.IsTrue(
    SQL_CREATE_CONFIG.ToUpper.Contains('PRIMARY KEY') or
    SQL_CREATE_CONFIG.ToUpper.Contains('PRIMARY'),
    'Config table should have a primary key'
  );
end;

procedure TTestTier0Schema.Test_SQL_CREATE_CONFIG_HasKeyColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_CONFIG.ToUpper.Contains('KEY') or
    SQL_CREATE_CONFIG.ToUpper.Contains('NAME') or
    SQL_CREATE_CONFIG.ToUpper.Contains('SETTING'),
    'Config table should have a key/name column'
  );
end;

procedure TTestTier0Schema.Test_SQL_CREATE_CONFIG_HasValueColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_CONFIG.ToUpper.Contains('VALUE') or
    SQL_CREATE_CONFIG.ToUpper.Contains('DATA') or
    SQL_CREATE_CONFIG.ToUpper.Contains('SETTING'),
    'Config table should have a value column'
  );
end;

procedure TTestTier0Schema.Test_SQL_CREATE_LOG_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_LOG);
end;

procedure TTestTier0Schema.Test_SQL_CREATE_LOG_HasTimestamp;
begin
  Assert.IsTrue(
    SQL_CREATE_LOG.ToUpper.Contains('TIMESTAMP') or
    SQL_CREATE_LOG.ToUpper.Contains('CREATED') or
    SQL_CREATE_LOG.ToUpper.Contains('TIME') or
    SQL_CREATE_LOG.ToUpper.Contains('DATE'),
    'Log table should have a timestamp column'
  );
end;

procedure TTestTier0Schema.Test_SQL_CREATE_LOG_HasLevel;
begin
  Assert.IsTrue(
    SQL_CREATE_LOG.ToUpper.Contains('LEVEL') or
    SQL_CREATE_LOG.ToUpper.Contains('SEVERITY') or
    SQL_CREATE_LOG.ToUpper.Contains('TYPE'),
    'Log table should have a level/severity column'
  );
end;

procedure TTestTier0Schema.Test_SQL_CREATE_LOG_HasMessage;
begin
  Assert.IsTrue(
    SQL_CREATE_LOG.ToUpper.Contains('MESSAGE') or
    SQL_CREATE_LOG.ToUpper.Contains('MSG') or
    SQL_CREATE_LOG.ToUpper.Contains('TEXT') or
    SQL_CREATE_LOG.ToUpper.Contains('CONTENT'),
    'Log table should have a message column'
  );
end;

{ TTestTier1Schema }

procedure TTestTier1Schema.Test_SQL_CREATE_USER_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_USER);
end;

procedure TTestTier1Schema.Test_SQL_CREATE_USER_HasIdColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_USER.ToUpper.Contains('ID') or
    SQL_CREATE_USER.ToUpper.Contains('USER_ID'),
    'User table should have an ID column'
  );
end;

procedure TTestTier1Schema.Test_SQL_CREATE_USER_HasNameColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_USER.ToUpper.Contains('NAME') or
    SQL_CREATE_USER.ToUpper.Contains('USERNAME') or
    SQL_CREATE_USER.ToUpper.Contains('LOGIN'),
    'User table should have a name/username column'
  );
end;

procedure TTestTier1Schema.Test_SQL_CREATE_SESSION_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_SESSION);
end;

procedure TTestTier1Schema.Test_SQL_CREATE_SESSION_HasTokenColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_SESSION.ToUpper.Contains('TOKEN') or
    SQL_CREATE_SESSION.ToUpper.Contains('SESSION_ID') or
    SQL_CREATE_SESSION.ToUpper.Contains('KEY'),
    'Session table should have a token column'
  );
end;

procedure TTestTier1Schema.Test_SQL_CREATE_SESSION_HasUserIdColumn;
begin
  Assert.IsTrue(
    SQL_CREATE_SESSION.ToUpper.Contains('USER_ID') or
    SQL_CREATE_SESSION.ToUpper.Contains('USERID') or
    SQL_CREATE_SESSION.ToUpper.Contains('USER'),
    'Session table should have a user_id column'
  );
end;

procedure TTestTier1Schema.Test_SQL_CREATE_SESSION_HasExpiresAt;
begin
  Assert.IsTrue(
    SQL_CREATE_SESSION.ToUpper.Contains('EXPIRES') or
    SQL_CREATE_SESSION.ToUpper.Contains('EXPIRY') or
    SQL_CREATE_SESSION.ToUpper.Contains('VALID_UNTIL'),
    'Session table should have an expiration column'
  );
end;

{ TTestTier2Schema }

procedure TTestTier2Schema.Test_SQL_CREATE_AUDIT_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_AUDIT);
end;

procedure TTestTier2Schema.Test_SQL_CREATE_AUDIT_HasAction;
begin
  Assert.IsTrue(
    SQL_CREATE_AUDIT.ToUpper.Contains('ACTION') or
    SQL_CREATE_AUDIT.ToUpper.Contains('OPERATION') or
    SQL_CREATE_AUDIT.ToUpper.Contains('EVENT'),
    'Audit table should have an action column'
  );
end;

procedure TTestTier2Schema.Test_SQL_CREATE_AUDIT_HasUserId;
begin
  Assert.IsTrue(
    SQL_CREATE_AUDIT.ToUpper.Contains('USER') or
    SQL_CREATE_AUDIT.ToUpper.Contains('ACTOR') or
    SQL_CREATE_AUDIT.ToUpper.Contains('PERFORMER'),
    'Audit table should have a user reference'
  );
end;

procedure TTestTier2Schema.Test_SQL_CREATE_CACHE_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_CREATE_CACHE);
end;

procedure TTestTier2Schema.Test_SQL_CREATE_CACHE_HasKey;
begin
  Assert.IsTrue(
    SQL_CREATE_CACHE.ToUpper.Contains('KEY') or
    SQL_CREATE_CACHE.ToUpper.Contains('CACHE_KEY') or
    SQL_CREATE_CACHE.ToUpper.Contains('NAME'),
    'Cache table should have a key column'
  );
end;

procedure TTestTier2Schema.Test_SQL_CREATE_CACHE_HasExpiry;
begin
  Assert.IsTrue(
    SQL_CREATE_CACHE.ToUpper.Contains('EXPIR') or
    SQL_CREATE_CACHE.ToUpper.Contains('TTL') or
    SQL_CREATE_CACHE.ToUpper.Contains('VALID'),
    'Cache table should have an expiry column'
  );
end;

{ TTestSchemaHelpers }

procedure TTestSchemaHelpers.Test_GetTier0SchemaSQL_ReturnsSQL;
var
  SQL: string;
begin
  SQL := GetTier0SchemaSQL;
  Assert.IsNotEmpty(SQL);
  Assert.IsTrue(SQL.ToUpper.Contains('CREATE'), 'Should contain CREATE statements');
end;

procedure TTestSchemaHelpers.Test_GetTier1SchemaSQL_ReturnsSQL;
var
  SQL: string;
begin
  SQL := GetTier1SchemaSQL;
  Assert.IsNotEmpty(SQL);
  Assert.IsTrue(SQL.ToUpper.Contains('CREATE'), 'Should contain CREATE statements');
end;

procedure TTestSchemaHelpers.Test_GetTier2SchemaSQL_ReturnsSQL;
var
  SQL: string;
begin
  SQL := GetTier2SchemaSQL;
  Assert.IsNotEmpty(SQL);
  Assert.IsTrue(SQL.ToUpper.Contains('CREATE'), 'Should contain CREATE statements');
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsTier0;
var
  FullSQL, Tier0SQL: string;
begin
  FullSQL := GetFullSchemaSQL;
  Tier0SQL := GetTier0SchemaSQL;
  
  Assert.IsTrue(FullSQL.Contains(Tier0SQL) or 
                (FullSQL.ToUpper.Contains('CONFIG') and FullSQL.ToUpper.Contains('LOG')),
                'Full schema should contain Tier0 tables');
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsTier1;
var
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;
  
  Assert.IsTrue(FullSQL.ToUpper.Contains('USER') and 
                FullSQL.ToUpper.Contains('SESSION'),
                'Full schema should contain Tier1 tables');
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsTier2;
var
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;
  
  Assert.IsTrue(FullSQL.ToUpper.Contains('AUDIT') and 
                FullSQL.ToUpper.Contains('CACHE'),
                'Full schema should contain Tier2 tables');
end;

procedure TTestSchemaHelpers.Test_GetSchemaVersion_NotEmpty;
var
  Version: string;
begin
  Version := GetSchemaVersion;
  Assert.IsNotEmpty(Version);
  Assert.AreEqual(SCHEMA_VERSION, Version);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSchemaVersion);
  TDUnitX.RegisterTestFixture(TTestTier0Schema);
  TDUnitX.RegisterTestFixture(TTestTier1Schema);
  TDUnitX.RegisterTestFixture(TTestTier2Schema);
  TDUnitX.RegisterTestFixture(TTestSchemaHelpers);

end.
