unit Test.DeepBase.DB.AutoRefreshConfig;

interface

uses
  DUnitX.TestFramework,
  FireDAC.Comp.Client,
  DeepBase.Interfaces;

type
  [TestFixture]
  TTestDBAutoRefreshConfig = class
  private
    FTempDir: string;
    FDBPath: string;
    FConnection: TFDConnection;
    FConfig: IAutoRefreshConfig;
    function CreateConnection: TFDConnection;
    procedure CreateConfigTable;
    procedure WriteConfig(const Section, Key, Value, UpdatedAt: string);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_GetValue_LoadsBySectionAndKey;

    [Test]
    procedure Test_GetValue_ReturnsDefaultForMissingKey;

    [Test]
    procedure Test_GetValue_LazilyReloadsWhenUpdatedAtChanges;

    [Test]
    procedure Test_GetInt_GetBool_ParseTypedValues;

    [Test]
    procedure Test_CustomOptions_SupportsDifferentTableShape;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Stan.Param,
  DeepBase.DB.AutoRefreshConfig;

procedure TTestDBAutoRefreshConfig.Setup;
var
  GuidText: string;
begin
  GuidText := TGUID.NewGuid.ToString;
  GuidText := StringReplace(GuidText, '{', '', [rfReplaceAll]);
  GuidText := StringReplace(GuidText, '}', '', [rfReplaceAll]);
  FTempDir := TPath.Combine(TPath.GetTempPath, 'DeepBase_AutoConfig_' + GuidText);
  TDirectory.CreateDirectory(FTempDir);
  FDBPath := TPath.Combine(FTempDir, 'config.db');
  FConnection := CreateConnection;
  CreateConfigTable;
  FConfig := TAutoRefreshConfig.Create(FConnection);
end;

procedure TTestDBAutoRefreshConfig.TearDown;
begin
  FConfig := nil;
  FConnection.Free;
  if (FTempDir <> '') and TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestDBAutoRefreshConfig.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.DriverName := 'SQLite';
    Result.Params.Database := FDBPath;
    Result.Params.Values['OpenMode'] := 'CreateUTF8';
    Result.Params.Values['LockingMode'] := 'Normal';
    Result.LoginPrompt := False;
    Result.Open;
  except
    Result.Free;
    raise;
  end;
end;

procedure TTestDBAutoRefreshConfig.CreateConfigTable;
begin
  FConnection.ExecSQL(
    'CREATE TABLE IF NOT EXISTS pg_config (' +
    'section_name TEXT NOT NULL, ' +
    'config_key TEXT NOT NULL, ' +
    'config_value TEXT NOT NULL, ' +
    'updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, ' +
    'PRIMARY KEY (section_name, config_key))');
end;

procedure TTestDBAutoRefreshConfig.WriteConfig(const Section, Key, Value,
  UpdatedAt: string);
var
  Query: TFDQuery;
begin
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO pg_config ' +
      '(section_name, config_key, config_value, updated_at) ' +
      'VALUES (:section_name, :config_key, :config_value, :updated_at)';
    Query.ParamByName('section_name').AsString := Section;
    Query.ParamByName('config_key').AsString := Key;
    Query.ParamByName('config_value').AsString := Value;
    Query.ParamByName('updated_at').AsString := UpdatedAt;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

procedure TTestDBAutoRefreshConfig.Test_GetValue_LoadsBySectionAndKey;
begin
  WriteConfig('app', 'theme', 'light', '2026-04-30 10:00:00');
  WriteConfig('worker', 'theme', 'dark', '2026-04-30 10:00:00');

  Assert.AreEqual('light', FConfig.GetValue('app', 'theme', ''));
  Assert.AreEqual('dark', FConfig.GetValue('worker', 'theme', ''));
end;

procedure TTestDBAutoRefreshConfig.Test_GetValue_ReturnsDefaultForMissingKey;
begin
  Assert.AreEqual('fallback',
    FConfig.GetValue('app', 'missing', 'fallback'));
end;

procedure TTestDBAutoRefreshConfig.Test_GetValue_LazilyReloadsWhenUpdatedAtChanges;
begin
  WriteConfig('app', 'mode', 'first', '2026-04-30 10:00:00');
  Assert.AreEqual('first', FConfig.GetValue('app', 'mode', ''));

  WriteConfig('app', 'mode', 'second', '2026-04-30 10:01:00');
  Assert.AreEqual('second', FConfig.GetValue('app', 'mode', ''));
end;

procedure TTestDBAutoRefreshConfig.Test_GetInt_GetBool_ParseTypedValues;
begin
  WriteConfig('limits', 'batch_size', '42', '2026-04-30 10:00:00');
  WriteConfig('feature', 'enabled', 'yes', '2026-04-30 10:00:00');
  WriteConfig('feature', 'disabled', 'off', '2026-04-30 10:00:00');
  WriteConfig('feature', 'invalid', 'maybe', '2026-04-30 10:00:00');

  Assert.AreEqual(42, FConfig.GetInt('limits', 'batch_size', 1));
  Assert.IsTrue(FConfig.GetBool('feature', 'enabled', False));
  Assert.IsFalse(FConfig.GetBool('feature', 'disabled', True));
  Assert.IsTrue(FConfig.GetBool('feature', 'invalid', True));
end;

procedure TTestDBAutoRefreshConfig.Test_CustomOptions_SupportsDifferentTableShape;
var
  Options: TAutoRefreshConfigOptions;
  Config: IAutoRefreshConfig;
begin
  Options := TAutoRefreshConfigOptions.Default;
  Options.TableName := 'app_config';
  Options.SectionColumn := 'scope_name';
  Options.KeyColumn := 'name';
  Options.ValueColumn := 'text_value';
  Options.UpdatedAtColumn := 'changed_at';

  Config := TAutoRefreshConfig.Create(FConnection, Options);
  Assert.AreEqual('missing', Config.GetValue('custom', 'name', 'missing'));

  FConnection.ExecSQL(
    'INSERT OR REPLACE INTO app_config ' +
    '(scope_name, name, text_value, changed_at) ' +
    'VALUES (''custom'', ''name'', ''value'', ''2026-04-30 10:00:00'')');

  Assert.AreEqual('value', Config.GetValue('custom', 'name', ''));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDBAutoRefreshConfig);

end.
