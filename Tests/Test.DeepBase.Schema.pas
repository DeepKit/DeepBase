{ ============================================================================
  Test.DeepBase.Schema - Unit Tests for Database Schema Module

  Test Coverage:
    - Schema version constants
    - Tier 0/1/2 table SQL definitions
    - SQL validation and structure
    - Helper functions (GetTier*SchemaSQL, GetFullSchemaSQL)
  ============================================================================ }

unit Test.DeepBase.Schema;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  DeepBase.Schema;

type
  [TestFixture]
  TTestSchemaVersion = class
  public
    [Test]
    procedure Test_SCHEMA_VERSION_Format;
    [Test]
    procedure Test_SCHEMA_VERSION_NonEmpty;
    [Test]
    procedure Test_SCHEMA_VERSION_MajorIsAtLeast1;
    [Test]
    procedure Test_SCHEMA_VERSION_MinorIsNonNegative;
    [Test]
    procedure Test_CompatibleVersionRange;
  end;

  [TestFixture]
  TTestTier0Schema = class
  public
    [Test]
    procedure Test_SQL_TIER0_SCHEMA_INFO_NotEmpty;
    [Test]
    procedure Test_SQL_TIER0_SCHEMA_INFO_HasPrimaryKey;
    [Test]
    procedure Test_SQL_TIER0_SETTINGS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER0_SETTINGS_HasPrimaryKey;
    [Test]
    procedure Test_SQL_TIER0_SETTINGS_HasKeyColumn;
    [Test]
    procedure Test_SQL_TIER0_SETTINGS_HasValueColumn;
    [Test]
    procedure Test_SQL_TIER0_FORM_STATES_NotEmpty;
    [Test]
    procedure Test_SQL_TIER0_LANGUAGES_NotEmpty;
    [Test]
    procedure Test_SQL_TIER0_I18N_TEXTS_NotEmpty;
  end;

  [TestFixture]
  TTestTier1Schema = class
  public
    [Test]
    procedure Test_SQL_TIER1_LOGS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER1_LOGS_HasTimestamp;
    [Test]
    procedure Test_SQL_TIER1_LOGS_HasLevel;
    [Test]
    procedure Test_SQL_TIER1_LOGS_HasMessage;
    [Test]
    procedure Test_SQL_TIER1_MRU_NotEmpty;
    [Test]
    procedure Test_SQL_TIER1_HOTKEYS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER1_QUERIES_NotEmpty;
    [Test]
    procedure Test_SQL_TIER1_THEMES_NotEmpty;
  end;

  [TestFixture]
  TTestTier2Schema = class
  public
    [Test]
    procedure Test_SQL_TIER2_PROVIDERS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER2_PROVIDERS_HasBaseUrl;
    [Test]
    procedure Test_SQL_TIER2_EXCEPTION_REPORTS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER2_EXCEPTION_REPORTS_HasExceptionClass;
    [Test]
    procedure Test_SQL_TIER2_LLM_CONFIG_NotEmpty;
    [Test]
    procedure Test_SQL_TIER2_NOTIFICATIONS_NotEmpty;
    [Test]
    procedure Test_SQL_TIER2_NOTIFICATIONS_HasContent;
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
    procedure Test_GetFullSchemaSQL_ContainsVersion;
  end;

  [TestFixture]
  TTestSchemaEncoding = class
  public
    [Test]
    procedure Test_LanguagesData_ContainsCorrectNativeName_zhCN;
    [Test]
    procedure Test_LanguagesData_ContainsCorrectNativeName_zhTW;
    [Test]
    procedure Test_LanguagesData_ContainsCorrectNativeName_jaJP;
    [Test]
    procedure Test_I18nTextsData_NoMojibake;
    [Test]
    procedure Test_I18nTextsData_ContainsCorrectChineseTranslations;
  end;

implementation

{ TTestSchemaVersion }

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_Format;
begin
  // Version should be in format like "1.0.0" (major.minor.patch)
  Assert.IsTrue(SCHEMA_VERSION.Contains('.'), 'Version should contain a dot separator');
end;

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_NonEmpty;
begin
  Assert.IsNotEmpty(SCHEMA_VERSION);
end;

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_MajorIsAtLeast1;
var
  MajorStr: string;
  MajorVal: Integer;
begin
  // SCHEMA_VERSION = '1.0.0' �?extract major part before first dot
  MajorStr := SCHEMA_VERSION.Split(['.'])[0];
  MajorVal := StrToIntDef(MajorStr, 0);
  Assert.IsTrue(MajorVal >= 1, 'Major version should be at least 1');
end;

procedure TTestSchemaVersion.Test_SCHEMA_VERSION_MinorIsNonNegative;
var
  Parts: TArray<string>;
  MinorVal: Integer;
begin
  // SCHEMA_VERSION = '1.0.0' �?extract minor part (second segment)
  Parts := SCHEMA_VERSION.Split(['.']);
  Assert.IsTrue(Length(Parts) >= 2, 'Version should have at least major.minor');
  MinorVal := StrToIntDef(Parts[1], 0);
  Assert.IsTrue(MinorVal >= 0, 'Minor version should be non-negative');
end;

procedure TTestSchemaVersion.Test_CompatibleVersionRange;
begin
  Assert.IsNotEmpty(MIN_COMPATIBLE_SCHEMA_VERSION, 'MIN_COMPATIBLE_SCHEMA_VERSION should be set');
  Assert.IsNotEmpty(MAX_COMPATIBLE_SCHEMA_VERSION, 'MAX_COMPATIBLE_SCHEMA_VERSION should be set');
end;

{ TTestTier0Schema }

procedure TTestTier0Schema.Test_SQL_TIER0_SCHEMA_INFO_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER0_SCHEMA_INFO);
end;

procedure TTestTier0Schema.Test_SQL_TIER0_SCHEMA_INFO_HasPrimaryKey;
begin
  Assert.IsTrue(
    SQL_TIER0_SCHEMA_INFO.ToUpper.Contains('PRIMARY KEY'),
    'SchemaInfo table should have a primary key'
  );
end;

procedure TTestTier0Schema.Test_SQL_TIER0_SETTINGS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER0_SETTINGS);
end;

procedure TTestTier0Schema.Test_SQL_TIER0_SETTINGS_HasPrimaryKey;
begin
  Assert.IsTrue(
    SQL_TIER0_SETTINGS.ToUpper.Contains('PRIMARY KEY'),
    'Settings table should have a primary key'
  );
end;

procedure TTestTier0Schema.Test_SQL_TIER0_SETTINGS_HasKeyColumn;
begin
  Assert.IsTrue(
    SQL_TIER0_SETTINGS.ToUpper.Contains('KEY') or
    SQL_TIER0_SETTINGS.ToUpper.Contains('NAME') or
    SQL_TIER0_SETTINGS.ToUpper.Contains('SETTING'),
    'Settings table should have a key/name column'
  );
end;

procedure TTestTier0Schema.Test_SQL_TIER0_SETTINGS_HasValueColumn;
begin
  Assert.IsTrue(
    SQL_TIER0_SETTINGS.ToUpper.Contains('VALUE') or
    SQL_TIER0_SETTINGS.ToUpper.Contains('DATA') or
    SQL_TIER0_SETTINGS.ToUpper.Contains('SETTING'),
    'Settings table should have a value column'
  );
end;

procedure TTestTier0Schema.Test_SQL_TIER0_FORM_STATES_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER0_FORM_STATES);
end;

procedure TTestTier0Schema.Test_SQL_TIER0_LANGUAGES_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER0_LANGUAGES);
end;

procedure TTestTier0Schema.Test_SQL_TIER0_I18N_TEXTS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER0_I18N_TEXTS);
end;

{ TTestTier1Schema }

procedure TTestTier1Schema.Test_SQL_TIER1_LOGS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER1_LOGS);
end;

procedure TTestTier1Schema.Test_SQL_TIER1_LOGS_HasTimestamp;
begin
  Assert.IsTrue(
    SQL_TIER1_LOGS.ToUpper.Contains('LOGTIME') or
    SQL_TIER1_LOGS.ToUpper.Contains('TIMESTAMP') or
    SQL_TIER1_LOGS.ToUpper.Contains('CREATED') or
    SQL_TIER1_LOGS.ToUpper.Contains('TIME'),
    'Logs table should have a timestamp/time column'
  );
end;

procedure TTestTier1Schema.Test_SQL_TIER1_LOGS_HasLevel;
begin
  Assert.IsTrue(
    SQL_TIER1_LOGS.ToUpper.Contains('LOGLEVEL') or
    SQL_TIER1_LOGS.ToUpper.Contains('LEVEL') or
    SQL_TIER1_LOGS.ToUpper.Contains('SEVERITY'),
    'Logs table should have a level/severity column'
  );
end;

procedure TTestTier1Schema.Test_SQL_TIER1_LOGS_HasMessage;
begin
  Assert.IsTrue(
    SQL_TIER1_LOGS.ToUpper.Contains('MESSAGE') or
    SQL_TIER1_LOGS.ToUpper.Contains('MSG'),
    'Logs table should have a message column'
  );
end;

procedure TTestTier1Schema.Test_SQL_TIER1_MRU_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER1_MRU);
end;

procedure TTestTier1Schema.Test_SQL_TIER1_HOTKEYS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER1_HOTKEYS);
end;

procedure TTestTier1Schema.Test_SQL_TIER1_QUERIES_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER1_QUERIES);
end;

procedure TTestTier1Schema.Test_SQL_TIER1_THEMES_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER1_THEMES);
end;

{ TTestTier2Schema }

procedure TTestTier2Schema.Test_SQL_TIER2_PROVIDERS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER2_PROVIDERS);
end;

procedure TTestTier2Schema.Test_SQL_TIER2_PROVIDERS_HasBaseUrl;
begin
  Assert.IsTrue(
    SQL_TIER2_PROVIDERS.ToUpper.Contains('BASEURL') or
    SQL_TIER2_PROVIDERS.ToUpper.Contains('URL'),
    'Providers table should have a URL/BaseUrl column'
  );
end;

procedure TTestTier2Schema.Test_SQL_TIER2_EXCEPTION_REPORTS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER2_EXCEPTION_REPORTS);
end;

procedure TTestTier2Schema.Test_SQL_TIER2_EXCEPTION_REPORTS_HasExceptionClass;
begin
  Assert.IsTrue(
    SQL_TIER2_EXCEPTION_REPORTS.ToUpper.Contains('EXCEPTIONCLASS') or
    SQL_TIER2_EXCEPTION_REPORTS.ToUpper.Contains('EXCEPTION'),
    'ExceptionReports table should have an ExceptionClass column'
  );
end;

procedure TTestTier2Schema.Test_SQL_TIER2_LLM_CONFIG_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER2_LLM_CONFIG);
end;

procedure TTestTier2Schema.Test_SQL_TIER2_NOTIFICATIONS_NotEmpty;
begin
  Assert.IsNotEmpty(SQL_TIER2_NOTIFICATIONS);
end;

procedure TTestTier2Schema.Test_SQL_TIER2_NOTIFICATIONS_HasContent;
begin
  Assert.IsTrue(
    SQL_TIER2_NOTIFICATIONS.ToUpper.Contains('CONTENT') or
    SQL_TIER2_NOTIFICATIONS.ToUpper.Contains('TITLE'),
    'Notifications table should have a content/title column'
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
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;

  Assert.IsTrue(
    FullSQL.ToUpper.Contains('SCHEMAINFO') and
    FullSQL.ToUpper.Contains('SETTINGS'),
    'Full schema should contain Tier0 tables (SchemaInfo, Settings)'
  );
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsTier1;
var
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;

  Assert.IsTrue(
    FullSQL.ToUpper.Contains('LOGS') and
    FullSQL.ToUpper.Contains('MRU'),
    'Full schema should contain Tier1 tables (Logs, MRU)'
  );
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsTier2;
var
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;

  Assert.IsTrue(
    FullSQL.ToUpper.Contains('PROVIDERS') and
    FullSQL.ToUpper.Contains('MODELS'),
    'Full schema should contain Tier2 tables (Providers, Models)'
  );
end;

procedure TTestSchemaHelpers.Test_GetFullSchemaSQL_ContainsVersion;
var
  FullSQL: string;
begin
  FullSQL := GetFullSchemaSQL;

  Assert.IsTrue(
    FullSQL.Contains(SCHEMA_VERSION),
    'Full schema should reference SCHEMA_VERSION'
  );
end;

{ TTestSchemaEncoding }

procedure TTestSchemaEncoding.Test_LanguagesData_ContainsCorrectNativeName_zhCN;
begin
  // BUG-276: zh-CN NativeName must be 简体中文, not mojibake
  Assert.IsTrue(
    SQL_TIER0_LANGUAGES_DATA.Contains('简体中文'),
    'zh-CN NativeName should be 简体中文, not corrupted'
  );
end;

procedure TTestSchemaEncoding.Test_LanguagesData_ContainsCorrectNativeName_zhTW;
begin
  // BUG-276: zh-TW NativeName must be 繁體中文, not mojibake
  Assert.IsTrue(
    SQL_TIER0_LANGUAGES_DATA.Contains('繁體中文'),
    'zh-TW NativeName should be 繁體中文, not corrupted'
  );
end;

procedure TTestSchemaEncoding.Test_LanguagesData_ContainsCorrectNativeName_jaJP;
begin
  // BUG-276: ja-JP NativeName must be 日本語, not mojibake
  Assert.IsTrue(
    SQL_TIER0_LANGUAGES_DATA.Contains('日本語'),
    'ja-JP NativeName should be 日本語, not corrupted'
  );
end;

procedure TTestSchemaEncoding.Test_I18nTextsData_NoMojibake;
var
  Data: string;
begin
  // BUG-276: Ensure no replacement characters or typical mojibake sequences
  Data := SQL_TIER0_I18N_TEXTS_DATA;

  Assert.IsFalse(
    Data.Contains(''),
    'I18nTexts data should not contain Unicode replacement character '
  );

  // Check for common mojibake patterns (corrupted multi-byte sequences)
  Assert.IsFalse(
    Data.Contains('ȷ') or Data.Contains('ȡ') or Data.Contains('ر') or Data.Contains('Ϣ'),
    'I18nTexts data should not contain mojibake sequences from encoding corruption'
  );
end;

procedure TTestSchemaEncoding.Test_I18nTextsData_ContainsCorrectChineseTranslations;
var
  Data: string;
begin
  // BUG-276: Verify all 8 built-in translations are correct
  Data := SQL_TIER0_I18N_TEXTS_DATA;

  Assert.IsTrue(Data.Contains('确定'), 'OK should translate to 确定');
  Assert.IsTrue(Data.Contains('取消'), 'Cancel should translate to 取消');
  Assert.IsTrue(Data.Contains('保存'), 'Save should translate to 保存');
  Assert.IsTrue(Data.Contains('关闭'), 'Close should translate to 关闭');
  Assert.IsTrue(Data.Contains('错误'), 'Error should translate to 错误');
  Assert.IsTrue(Data.Contains('警告'), 'Warning should translate to 警告');
  Assert.IsTrue(Data.Contains('信息'), 'Information should translate to 信息');
  Assert.IsTrue(Data.Contains('确认'), 'Confirm should translate to 确认');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestSchemaVersion);
  TDUnitX.RegisterTestFixture(TTestTier0Schema);
  TDUnitX.RegisterTestFixture(TTestTier1Schema);
  TDUnitX.RegisterTestFixture(TTestTier2Schema);
  TDUnitX.RegisterTestFixture(TTestSchemaHelpers);
  TDUnitX.RegisterTestFixture(TTestSchemaEncoding);

end.
