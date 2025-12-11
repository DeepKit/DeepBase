{ ============================================================================ 
  Test.UniBase.Consts - Unit tests for UniBase.Consts constants

  Coverage:
    - Basic sanity of configuration key constants
    - Default values and language codes
    - MRU category names
    - Database table names
    - Log level string constants
  ============================================================================ }

unit Test.UniBase.Consts;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  UniBase.Consts;

type
  [TestFixture]
  TTestUniBaseConsts = class
  public
    [Test]
    procedure ConfigKeys_AreNotEmpty_AndDistinct;
    [Test]
    procedure DefaultValues_AreExpected;
    [Test]
    procedure MRUCategories_AreExpected;
    [Test]
    procedure TableNames_AreNotEmpty_AndDistinct;
    [Test]
    procedure LogLevelStrings_AreUppercaseAndExpected;
  end;

implementation

{ TTestUniBaseConsts }

procedure TTestUniBaseConsts.ConfigKeys_AreNotEmpty_AndDistinct;
var
  Seen: TDictionary<string, Boolean>;
  procedure AddKey(const Name, Value: string);
  begin
    Assert.IsNotEmpty(Value, Name + ' should not be empty');
    Assert.IsFalse(Seen.ContainsKey(Value), 'Duplicate config key value: ' + Value);
    Seen.Add(Value, True);
  end;
begin
  Seen := TDictionary<string, Boolean>.Create;
  try
    AddKey('SConfigKeyLanguage', SConfigKeyLanguage);
    AddKey('SConfigKeyTheme', SConfigKeyTheme);
    AddKey('SConfigKeyDebugMode', SConfigKeyDebugMode);
    AddKey('SConfigKeyLogLevel', SConfigKeyLogLevel);
    AddKey('SConfigKeyLogStorageMode', SConfigKeyLogStorageMode);
  finally
    Seen.Free;
  end;
end;

procedure TTestUniBaseConsts.DefaultValues_AreExpected;
begin
  Assert.AreEqual('en-US', SDefaultLanguage, 'Default language should be en-US');
  Assert.AreEqual('Windows11', SDefaultTheme, 'Default theme should be Windows11');
  Assert.AreEqual('zh-CN', SLangCodeZhCN);
  Assert.AreEqual('en-US', SLangCodeEnUS);
end;

procedure TTestUniBaseConsts.MRUCategories_AreExpected;
begin
  Assert.AreEqual('File', SMRUCategoryFile);
  Assert.AreEqual('Project', SMRUCategoryProject);
  Assert.AreEqual('Command', SMRUCategoryCommand);
  Assert.AreEqual('Search', SMRUCategorySearch);
end;

procedure TTestUniBaseConsts.TableNames_AreNotEmpty_AndDistinct;
var
  Seen: TDictionary<string, Boolean>;
  procedure AddTable(const Name, Value: string);
  begin
    Assert.IsNotEmpty(Value, Name + ' should not be empty');
    Assert.IsFalse(Seen.ContainsKey(Value), 'Duplicate table name: ' + Value);
    Seen.Add(Value, True);
  end;
begin
  Seen := TDictionary<string, Boolean>.Create;
  try
    AddTable('STableSchemaInfo', STableSchemaInfo);
    AddTable('STableProjectInfo', STableProjectInfo);
    AddTable('STableSettings', STableSettings);
    AddTable('STableFormStates', STableFormStates);
    AddTable('STableLanguages', STableLanguages);
    AddTable('STableI18nTexts', STableI18nTexts);
    AddTable('STableLogs', STableLogs);
    AddTable('STableMRU', STableMRU);
    AddTable('STableHotkeys', STableHotkeys);
    AddTable('STableThemes', STableThemes);
    AddTable('STableSecrets', STableSecrets);
  finally
    Seen.Free;
  end;
end;

procedure TTestUniBaseConsts.LogLevelStrings_AreUppercaseAndExpected;
begin
  Assert.AreEqual('DEBUG', SLogLevelDebug);
  Assert.AreEqual('INFO', SLogLevelInfo);
  Assert.AreEqual('WARN', SLogLevelWarn);
  Assert.AreEqual('ERROR', SLogLevelError);
  Assert.AreEqual('FATAL', SLogLevelFatal);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseConsts);

end.
