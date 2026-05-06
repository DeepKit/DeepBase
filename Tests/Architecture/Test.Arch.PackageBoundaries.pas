{ ============================================================================
  Test.Arch.PackageBoundaries - Package boundary architecture tests

  These tests make package boundaries executable. They intentionally inspect
  .dpk and source files instead of relying on documentation claims.
  ============================================================================ }

unit Test.Arch.PackageBoundaries;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.RegularExpressions,
  DUnitX.TestFramework;

type
  [TestFixture]
  [Category('Architecture')]
  TPackageBoundaryTests = class
  private
    function FindRepoRoot: string;
    function ReadRepoFile(const RelativePath: string): string;
    function PackageContainsSourceFiles(const RelativePackagePath: string): TArray<string>;
    function StripPascalComments(const Text: string): string;
    function ExtractRoutineText(const Text, RoutineName: string): string;
    procedure AssertTextDoesNotContainAny(const Text, Subject: string;
      const Forbidden: array of string);
  public
    [Test]
    procedure CorePackage_DoesNotRequireUiOrDesignPackages;

    [Test]
    procedure CorePackage_DoesNotContainUiUnits;

    [Test]
    procedure CorePackage_DoesNotContainOptionalFeatureUnits;

    [Test]
    procedure ServicesPackage_DoesNotRequireUiOrDesignPackages;

    [Test]
    procedure FeaturesPackage_ContainsOptionalFeatureUnits;

    [Test]
    procedure FeaturesSource_OptionalFeatureImplementationsLiveUnderFeatures;

    [Test]
    procedure PersistencePackage_ExposesSQLiteAndPostgreSQLRuntime;

    [Test]
    procedure PersistenceSource_DatabaseImplementationsLiveUnderPersistence;

    [Test]
    procedure TestRunner_UsesWin64CompilerOnly;

    [Test]
    procedure SourceDirectories_DoNotContainDcuArtifacts;

    [Test]
    procedure CoreSource_UiDependenciesAreExplicitlyAllowlisted;

    [Test]
    procedure CoreSource_DbRuntimeDependenciesAreExplicitlyAllowlisted;

    [Test]
    procedure CoreSource_DoesNotDependOnManagerOutsideBootstrap;

    [Test]
    procedure ServicesRegistration_DoesNotStartBackgroundServices;

    [Test]
    procedure DownstreamPrimitives_DoNotDependOnHttpLlmNotifyOrBackgroundThreads;

    [Test]
    procedure UiAdapters_DoNotDependOnManagerConfigDB;

    [Test]
    procedure UiLogListView_UsesLoggerQueryPortOnly;

    [Test]
    procedure DesignPackages_RegisterControlsOnly_NoRuntimeBootstrap;
  end;

implementation

const
  CORE_UI_DEPENDENCY_ALLOWLIST: array[0..4] of string = (
    'UniBase.Exception.pas',
    'UniBase.Export.pas',
    'UniBase.SingleInstance.pas',
    'UniBase.SplashScreen.pas',
    'UniBase.TestHelper.pas'
  );

function TPackageBoundaryTests.FindRepoRoot: string;
var
  Dir: string;
begin
  Dir := ExtractFilePath(ParamStr(0));
  while Dir <> '' do
  begin
    if TFile.Exists(TPath.Combine(Dir, 'UniBaseCore.dpk')) and
       TFile.Exists(TPath.Combine(Dir, 'tasks.md')) then
      Exit(Dir);

    if TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)) = '' then
      Break;

    Dir := IncludeTrailingPathDelimiter(
      TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)));
  end;

  Assert.Fail('Could not locate UniBase repository root from ' + ParamStr(0));
  Result := '';
end;

function TPackageBoundaryTests.ReadRepoFile(const RelativePath: string): string;
var
  FilePath: string;
begin
  FilePath := TPath.Combine(FindRepoRoot, RelativePath);
  Assert.IsTrue(TFile.Exists(FilePath), 'Missing file: ' + FilePath);
  Result := TFile.ReadAllText(FilePath, TEncoding.UTF8);
end;

function TPackageBoundaryTests.PackageContainsSourceFiles(
  const RelativePackagePath: string): TArray<string>;
var
  Root: string;
  DpkText: string;
  Matches: TMatchCollection;
  Match: TMatch;
  RelativeSourcePath: string;
  SourceFilePath: string;
  Items: TList<string>;
begin
  Root := FindRepoRoot;
  DpkText := ReadRepoFile(RelativePackagePath);
  Matches := TRegEx.Matches(DpkText, '\bin\s+''([^'']+\.pas)''',
    [roIgnoreCase]);
  Items := TList<string>.Create;
  try
    for Match in Matches do
    begin
      RelativeSourcePath := Match.Groups[1].Value;
      SourceFilePath := TPath.Combine(Root,
        RelativeSourcePath.Replace('\', PathDelim));
      Items.Add(SourceFilePath);
    end;
    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

function TPackageBoundaryTests.StripPascalComments(const Text: string): string;
var
  Builder: TStringBuilder;
  I: Integer;
  Ch: Char;
  NextCh: Char;
  InBraceComment: Boolean;
  InParenStarComment: Boolean;
  InLineComment: Boolean;
begin
  Builder := TStringBuilder.Create;
  try
    I := 1;
    InBraceComment := False;
    InParenStarComment := False;
    InLineComment := False;

    while I <= Length(Text) do
    begin
      Ch := Text[I];
      if I < Length(Text) then
        NextCh := Text[I + 1]
      else
        NextCh := #0;

      if InLineComment then
      begin
        if CharInSet(Ch, [#10, #13]) then
        begin
          InLineComment := False;
          Builder.Append(Ch);
        end;
        Inc(I);
        Continue;
      end;

      if InBraceComment then
      begin
        if Ch = '}' then
          InBraceComment := False
        else if CharInSet(Ch, [#10, #13]) then
          Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      if InParenStarComment then
      begin
        if (Ch = '*') and (NextCh = ')') then
        begin
          InParenStarComment := False;
          Inc(I, 2);
          Continue;
        end;

        if CharInSet(Ch, [#10, #13]) then
          Builder.Append(Ch);
        Inc(I);
        Continue;
      end;

      if (Ch = '/') and (NextCh = '/') then
      begin
        InLineComment := True;
        Inc(I, 2);
        Continue;
      end;

      if Ch = '{' then
      begin
        InBraceComment := True;
        Inc(I);
        Continue;
      end;

      if (Ch = '(') and (NextCh = '*') then
      begin
        InParenStarComment := True;
        Inc(I, 2);
        Continue;
      end;

      Builder.Append(Ch);
      Inc(I);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TPackageBoundaryTests.ExtractRoutineText(const Text,
  RoutineName: string): string;
var
  LowerText: string;
  Marker: string;
  ImplementationPos: Integer;
  StartPos: Integer;
  EndPos: Integer;
begin
  LowerText := Text.ToLowerInvariant;
  Marker := 'procedure ' + RoutineName.ToLowerInvariant;
  ImplementationPos := Pos('implementation', LowerText);
  Assert.IsTrue(ImplementationPos > 0,
    'Could not locate implementation section');

  StartPos := Pos(Marker, Copy(LowerText, ImplementationPos, MaxInt));
  Assert.IsTrue(StartPos > 0, 'Could not locate routine: ' + RoutineName);
  StartPos := ImplementationPos + StartPos - 1;

  EndPos := Pos('procedure ', Copy(LowerText, StartPos + Length(Marker),
    MaxInt));
  if EndPos > 0 then
    Result := Copy(Text, StartPos, Length(Marker) + EndPos - 2)
  else
    Result := Copy(Text, StartPos, MaxInt);
end;

procedure TPackageBoundaryTests.AssertTextDoesNotContainAny(const Text,
  Subject: string; const Forbidden: array of string);
var
  Item: string;
begin
  for Item in Forbidden do
    Assert.IsFalse(Text.Contains(Item),
      Format('%s must not contain "%s"', [Subject, Item]));
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotRequireUiOrDesignPackages;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBaseCore.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'UniBaseCore.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;',
     ' firedac,', ' firedac;', ' firedaccommondriver,',
     ' firedaccommondriver;', ' firedacsqlitedriver,',
     ' firedacsqlitedriver;', ' dbrtl,', ' dbrtl;']);
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotContainUiUnits;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBaseCore.dpk');

  AssertTextDoesNotContainAny(DpkText, 'UniBaseCore.dpk contains section',
    ['VCL\', 'FMX\', 'UniBase.VCL.', 'UniBase.FMX.']);
  Assert.IsTrue(DpkText.ToLowerInvariant.Contains('unibase.manager'),
    'UniBaseCore.dpk must contain UniBase.Manager');
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotContainOptionalFeatureUnits;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBaseCore.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'UniBaseCore.dpk contains section',
    ['unibase.llm.', 'unibase.updater', 'unibase.autoupdate',
     'unibase.antitamper', 'unibase.unlock']);
  Assert.IsTrue(DpkText.Contains('unibase.protection'),
    'UniBaseCore.dpk keeps UniBase.Protection as the core sensitive-data primitive');
end;

procedure TPackageBoundaryTests.ServicesPackage_DoesNotRequireUiOrDesignPackages;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBaseServices.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'UniBaseServices.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;']);
  Assert.IsTrue(DpkText.Contains('unibase.services.registration'),
    'UniBaseServices.dpk must include Services.Registration');
  Assert.IsTrue(DpkText.Contains('unibase.services.crypto'),
    'UniBaseServices.dpk must include Services.Crypto');
end;

procedure TPackageBoundaryTests.FeaturesPackage_ContainsOptionalFeatureUnits;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBaseFeatures.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'UniBaseFeatures.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;']);
  Assert.IsTrue(DpkText.Contains('unibasecore'),
    'UniBaseFeatures.dpk must require UniBaseCore');
  Assert.IsTrue(DpkText.Contains('unibaseservices'),
    'UniBaseFeatures.dpk must require UniBaseServices to avoid duplicate service primitives');
  Assert.IsTrue(DpkText.Contains('unibase.llm.types'),
    'UniBaseFeatures.dpk must contain LLM types');
  Assert.IsTrue(DpkText.Contains('features\unibase.llm.types.pas'),
    'UniBaseFeatures.dpk must source LLM types from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.llm.types.pas'),
    'UniBaseFeatures.dpk must not source LLM types from Core');
  Assert.IsTrue(DpkText.Contains('unibase.llm.service'),
    'UniBaseFeatures.dpk must contain LLM service');
  Assert.IsTrue(DpkText.Contains('features\unibase.llm.service.pas'),
    'UniBaseFeatures.dpk must source LLM service from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.llm.service.pas'),
    'UniBaseFeatures.dpk must not source LLM service from Core');
  Assert.IsTrue(DpkText.Contains('unibase.updater'),
    'UniBaseFeatures.dpk must contain updater feature');
  Assert.IsTrue(DpkText.Contains('features\unibase.updater.pas'),
    'UniBaseFeatures.dpk must source updater feature from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.updater.pas'),
    'UniBaseFeatures.dpk must not source updater feature from Core');
  Assert.IsTrue(DpkText.Contains('unibase.autoupdate'),
    'UniBaseFeatures.dpk must contain auto-update facade');
  Assert.IsTrue(DpkText.Contains('features\unibase.autoupdate.pas'),
    'UniBaseFeatures.dpk must source auto-update facade from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.autoupdate.pas'),
    'UniBaseFeatures.dpk must not source auto-update facade from Core');
  Assert.IsFalse(DpkText.Contains('features\unibase.protection.pas'),
    'UniBaseFeatures.dpk must not carry the removed duplicate Protection implementation');
  Assert.IsTrue(DpkText.Contains('unibase.antitamper'),
    'UniBaseFeatures.dpk must contain anti-tamper feature');
  Assert.IsTrue(DpkText.Contains('features\unibase.antitamper.pas'),
    'UniBaseFeatures.dpk must source anti-tamper feature from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.antitamper.pas'),
    'UniBaseFeatures.dpk must not source anti-tamper feature from Core');
  Assert.IsTrue(DpkText.Contains('unibase.unlock'),
    'UniBaseFeatures.dpk must contain unlock feature');
  Assert.IsTrue(DpkText.Contains('features\unibase.unlock.pas'),
    'UniBaseFeatures.dpk must source unlock feature from Features');
  Assert.IsFalse(DpkText.Contains('core\unibase.unlock.pas'),
    'UniBaseFeatures.dpk must not source unlock feature from Core');
end;

procedure TPackageBoundaryTests.FeaturesSource_OptionalFeatureImplementationsLiveUnderFeatures;
const
  MOVED_FEATURE_UNITS: array[0..8] of string = (
    'UniBase.LLM.Types.pas',
    'UniBase.LLM.Client.pas',
    'UniBase.LLM.HTTP.pas',
    'UniBase.LLM.Config.pas',
    'UniBase.LLM.Service.pas',
    'UniBase.Updater.pas',
    'UniBase.AutoUpdate.pas',
    'UniBase.AntiTamper.pas',
    'UniBase.Unlock.pas'
  );
var
  Root: string;
  UnitFile: string;
begin
  Root := FindRepoRoot;

  for UnitFile in MOVED_FEATURE_UNITS do
  begin
    Assert.IsFalse(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Core'), UnitFile)),
      UnitFile + ' must not remain under Core');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Features'), UnitFile)),
      UnitFile + ' must live under Features');
  end;
end;

procedure TPackageBoundaryTests.PersistencePackage_ExposesSQLiteAndPostgreSQLRuntime;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('UniBasePersistence.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'UniBasePersistence.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;']);
  Assert.IsTrue(DpkText.Contains('firedacsqlitedriver'),
    'UniBasePersistence.dpk must require FireDAC SQLite driver');
  Assert.IsTrue(DpkText.Contains('firedacpgdriver'),
    'UniBasePersistence.dpk must require FireDAC PostgreSQL driver');
  Assert.IsTrue(DpkText.Contains('unibase.db.pool'),
    'UniBasePersistence.dpk must contain UniBase.DB.Pool');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.db.pool.pas'),
    'UniBasePersistence.dpk must source UniBase.DB.Pool from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.db.pool.pas'),
    'UniBasePersistence.dpk must not source UniBase.DB.Pool from Core');
  Assert.IsTrue(DpkText.Contains('unibase.db.connectionpool'),
    'UniBasePersistence.dpk must contain legacy UniBase.DB.ConnectionPool');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.db.connectionpool.pas'),
    'UniBasePersistence.dpk must source UniBase.DB.ConnectionPool from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.db.connectionpool.pas'),
    'UniBasePersistence.dpk must not source UniBase.DB.ConnectionPool from Core');
  Assert.IsTrue(DpkText.Contains('unibase.sqllogger'),
    'UniBasePersistence.dpk must contain UniBase.SQLLogger');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.sqllogger.pas'),
    'UniBasePersistence.dpk must source UniBase.SQLLogger from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.sqllogger.pas'),
    'UniBasePersistence.dpk must not source UniBase.SQLLogger from Core');
  Assert.IsTrue(DpkText.Contains('unibase.db.doqry'),
    'UniBasePersistence.dpk must contain UniBase.DB.DoQry');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.db.doqry.pas'),
    'UniBasePersistence.dpk must source UniBase.DB.DoQry from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.db.doqry.pas'),
    'UniBasePersistence.dpk must not source UniBase.DB.DoQry from Core');
  Assert.IsTrue(DpkText.Contains('unibase.db.autorefreshconfig'),
    'UniBasePersistence.dpk must contain UniBase.DB.AutoRefreshConfig');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.formstate.firedac'),
    'UniBasePersistence.dpk must contain FormState FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.formstate.firedac.pas'),
    'UniBasePersistence.dpk must source FormState FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.formstate.firedac.pas'),
    'UniBasePersistence.dpk must not source FormState FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.mru.firedac'),
    'UniBasePersistence.dpk must contain MRU FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.mru.firedac.pas'),
    'UniBasePersistence.dpk must source MRU FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.mru.firedac.pas'),
    'UniBasePersistence.dpk must not source MRU FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.hotkeys.firedac'),
    'UniBasePersistence.dpk must contain Hotkeys FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.hotkeys.firedac.pas'),
    'UniBasePersistence.dpk must source Hotkeys FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.hotkeys.firedac.pas'),
    'UniBasePersistence.dpk must not source Hotkeys FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.i18n.firedac'),
    'UniBasePersistence.dpk must contain i18n FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.i18n.firedac.pas'),
    'UniBasePersistence.dpk must source i18n FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.i18n.firedac.pas'),
    'UniBasePersistence.dpk must not source i18n FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.config.firedac'),
    'UniBasePersistence.dpk must contain Config FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.config.firedac.pas'),
    'UniBasePersistence.dpk must source Config FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.config.firedac.pas'),
    'UniBasePersistence.dpk must not source Config FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.logging.firedac'),
    'UniBasePersistence.dpk must contain Logging FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.logging.firedac.pas'),
    'UniBasePersistence.dpk must source Logging FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.logging.firedac.pas'),
    'UniBasePersistence.dpk must not source Logging FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.protection.firedac'),
    'UniBasePersistence.dpk must contain Protection FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.protection.firedac.pas'),
    'UniBasePersistence.dpk must source Protection FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.protection.firedac.pas'),
    'UniBasePersistence.dpk must not source Protection FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.theme.firedac'),
    'UniBasePersistence.dpk must contain Theme FireDAC adapter');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.theme.firedac.pas'),
    'UniBasePersistence.dpk must source Theme FireDAC adapter from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.theme.firedac.pas'),
    'UniBasePersistence.dpk must not source Theme FireDAC adapter from Core');
  Assert.IsTrue(DpkText.Contains('unibase.persistence.runtimeregistration'),
    'UniBasePersistence.dpk must contain Persistence runtime registration helper');
  Assert.IsTrue(DpkText.Contains('persistence\unibase.persistence.runtimeregistration.pas'),
    'UniBasePersistence.dpk must source runtime registration helper from Persistence');
  Assert.IsFalse(DpkText.Contains('core\unibase.persistence.runtimeregistration.pas'),
    'UniBasePersistence.dpk must not source runtime registration helper from Core');
  Assert.IsTrue(DpkText.Contains('unibase.db.factory'),
    'UniBasePersistence.dpk must contain UniBase.DB.Factory');
  Assert.IsTrue(DpkText.Contains('unibase.db.jobqueue'),
    'UniBasePersistence.dpk must contain UniBase.DB.JobQueue');
  Assert.IsTrue(DpkText.Contains('unibase.db.migrations'),
    'UniBasePersistence.dpk must contain UniBase.DB.Migrations');
  Assert.IsTrue(DpkText.Contains('unibase.db.statusmachine'),
    'UniBasePersistence.dpk must contain UniBase.DB.StatusMachine');
end;

procedure TPackageBoundaryTests.PersistenceSource_DatabaseImplementationsLiveUnderPersistence;
const
  MOVED_DATABASE_UNITS: array[0..12] of string = (
    'UniBase.DB.ConnectionPool.pas',
    'UniBase.DB.Pool.pas',
    'UniBase.DB.DoQry.pas',
    'UniBase.SQLLogger.pas',
    'UniBase.Persistence.Config.FireDAC.pas',
    'UniBase.Persistence.FormState.FireDAC.pas',
    'UniBase.Persistence.MRU.FireDAC.pas',
    'UniBase.Persistence.Hotkeys.FireDAC.pas',
    'UniBase.Persistence.I18n.FireDAC.pas',
    'UniBase.Persistence.Logging.FireDAC.pas',
    'UniBase.Persistence.Protection.FireDAC.pas',
    'UniBase.Persistence.Theme.FireDAC.pas',
    'UniBase.Persistence.RuntimeRegistration.pas'
  );
var
  Root: string;
  UnitFile: string;
begin
  Root := FindRepoRoot;

  for UnitFile in MOVED_DATABASE_UNITS do
  begin
    Assert.IsFalse(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Core'), UnitFile)),
      UnitFile + ' must not remain under Core');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Persistence'), UnitFile)),
      UnitFile + ' must live under Persistence');
  end;
end;

procedure TPackageBoundaryTests.TestRunner_UsesWin64CompilerOnly;
var
  ScriptText: string;
begin
  ScriptText := ReadRepoFile('Scripts\run_tests.ps1').ToLowerInvariant;

  Assert.IsTrue(ScriptText.Contains('dcc64.exe'),
    'Scripts\run_tests.ps1 must compile tests with dcc64');
  Assert.IsTrue(ScriptText.Contains('dcu64'),
    'Scripts\run_tests.ps1 must write DCUs into a Win64-specific directory');
  Assert.IsFalse(ScriptText.Contains('dcc32'),
    'Scripts\run_tests.ps1 must not use the Win32 compiler');
end;

procedure TPackageBoundaryTests.SourceDirectories_DoNotContainDcuArtifacts;
const
  SOURCE_DIRS: array[0..6] of string = (
    'Core',
    'Persistence',
    'Features',
    'Tests',
    'VCL',
    'FMX',
    'ThirdParty'
  );
var
  Root: string;
  RelativeDir: string;
  FullDir: string;
  DcuFile: string;
  Violations: TStringList;
begin
  Root := FindRepoRoot;
  Violations := TStringList.Create;
  try
    for RelativeDir in SOURCE_DIRS do
    begin
      FullDir := TPath.Combine(Root, RelativeDir);
      if not TDirectory.Exists(FullDir) then
        Continue;

      for DcuFile in TDirectory.GetFiles(FullDir, '*.dcu',
        TSearchOption.soAllDirectories) do
        Violations.Add(DcuFile);
    end;

    Assert.IsTrue(Violations.Count = 0,
      'Source directories must not contain .dcu artifacts:' + sLineBreak +
      Violations.Text);
  finally
    Violations.Free;
  end;
end;

procedure TPackageBoundaryTests.CoreSource_UiDependenciesAreExplicitlyAllowlisted;
var
  FilePath: string;
  FileNameOnly: string;
  Lines: TArray<string>;
  Line: string;
  TrimmedLine: string;
  Allowlist: TDictionary<string, Boolean>;
  Violations: TStringList;
begin
  Allowlist := TDictionary<string, Boolean>.Create;
  Violations := TStringList.Create;
  try
    for FileNameOnly in CORE_UI_DEPENDENCY_ALLOWLIST do
      Allowlist.AddOrSetValue(FileNameOnly.ToLowerInvariant, True);

    for FilePath in PackageContainsSourceFiles('UniBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);
      if Allowlist.ContainsKey(FileNameOnly.ToLowerInvariant) then
        Continue;

      Lines := TFile.ReadAllLines(FilePath, TEncoding.UTF8);
      for Line in Lines do
      begin
        TrimmedLine := Line.TrimLeft;
        if TrimmedLine.StartsWith('Vcl.', True) or
           TrimmedLine.StartsWith('FMX.', True) or
           TrimmedLine.StartsWith('DesignIntf', True) or
           TrimmedLine.StartsWith('DesignEditors', True) then
          Violations.Add(FileNameOnly + ': ' + TrimmedLine);
      end;
    end;

    Assert.IsTrue(Violations.Count = 0,
      'Unexpected Core UI dependencies outside allowlist:' + sLineBreak +
      Violations.Text);
  finally
    Violations.Free;
    Allowlist.Free;
  end;
end;

procedure TPackageBoundaryTests.CoreSource_DbRuntimeDependenciesAreExplicitlyAllowlisted;
var
  FilePath: string;
  FileNameOnly: string;
  SourceText: string;
  Violations: TStringList;
begin
  Violations := TStringList.Create;
  try
    for FilePath in PackageContainsSourceFiles('UniBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);

      SourceText := StripPascalComments(
        TFile.ReadAllText(FilePath, TEncoding.UTF8)).ToLowerInvariant;
      if SourceText.Contains('firedac.') or
         SourceText.Contains('tfdconnection') or
         SourceText.Contains('tfdquery') or
         SourceText.Contains('data.db') then
        Violations.Add(FileNameOnly);
    end;

    Assert.IsTrue(Violations.Count = 0,
      'UniBaseCore.dpk units must not depend on FireDAC/Data.DB/TFDConnection/TFDQuery:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
  end;
end;

procedure TPackageBoundaryTests.CoreSource_DoesNotDependOnManagerOutsideBootstrap;
var
  FilePath: string;
  FileNameOnly: string;
  SourceText: string;
  Violations: TStringList;
begin
  Violations := TStringList.Create;
  try
    for FilePath in PackageContainsSourceFiles('UniBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);

      SourceText := StripPascalComments(
        TFile.ReadAllText(FilePath, TEncoding.UTF8)).ToLowerInvariant;
      if SourceText.Contains('unibase.manager') then
        Violations.Add(FileNameOnly);
    end;

    Assert.IsTrue(Violations.Count = 0,
      'UniBaseCore.dpk units must not depend on UniBase.Manager:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
  end;
end;

procedure TPackageBoundaryTests.ServicesRegistration_DoesNotStartBackgroundServices;
var
  SourceText: string;
  RegisterBody: string;
begin
  SourceText := StripPascalComments(
    ReadRepoFile('Core\UniBase.Services.Registration.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(SourceText, 'RegisterFrameworkServices');

  AssertTextDoesNotContainAny(RegisterBody, 'RegisterFrameworkServices body',
    ['.start', 'tthread.create', 'ttask.run', 'scheduler.start',
     'workerqueue.start', 'eventbus.start']);
end;

procedure TPackageBoundaryTests.DownstreamPrimitives_DoNotDependOnHttpLlmNotifyOrBackgroundThreads;
const
  PRIMITIVE_UNITS: array[0..5] of string = (
    'Core\UniBase.AppLifecycle.pas',
    'Persistence\UniBase.DB.AutoRefreshConfig.pas',
    'Persistence\UniBase.DB.Factory.pas',
    'Persistence\UniBase.DB.JobQueue.pas',
    'Persistence\UniBase.DB.Migrations.pas',
    'Persistence\UniBase.DB.StatusMachine.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in PRIMITIVE_UNITS do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['unibase.llm', 'unibase.httpserver', 'idhttp', 'system.net.httpclient',
       'tfdeventalerter', ' pg_notify', ' notify ', ' listen ',
       'createthread', 'tthread.createanonymousthread']);
  end;
end;

procedure TPackageBoundaryTests.UiAdapters_DoNotDependOnManagerConfigDB;
const
  UI_DIRS: array[0..1] of string = ('VCL', 'FMX');
var
  Root: string;
  RelativeDir: string;
  FullDir: string;
  FilePath: string;
  SourceText: string;
  Violations: TStringList;
begin
  Root := FindRepoRoot;
  Violations := TStringList.Create;
  try
    for RelativeDir in UI_DIRS do
    begin
      FullDir := TPath.Combine(Root, RelativeDir);
      if not TDirectory.Exists(FullDir) then
        Continue;

      for FilePath in TDirectory.GetFiles(FullDir, '*.pas',
        TSearchOption.soAllDirectories) do
      begin
        SourceText := StripPascalComments(
          TFile.ReadAllText(FilePath, TEncoding.UTF8)).ToLowerInvariant;

        if TRegEx.IsMatch(SourceText,
             '\bunibase\.manager\.unibase\.configdb\b', [roIgnoreCase]) or
           TRegEx.IsMatch(SourceText,
             '\bunibase\.configdb\b', [roIgnoreCase]) then
          Violations.Add(FilePath);
      end;
    end;

    Assert.IsTrue(Violations.Count = 0,
      'UI adapters must not directly access UniBase.Manager.UniBase.ConfigDB:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
  end;
end;

procedure TPackageBoundaryTests.UiLogListView_UsesLoggerQueryPortOnly;
const
  FILES: array[0..1] of string = (
    'VCL\UniBase.VCL.LogListView.pas',
    'FMX\UniBase.FMX.LogListView.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in FILES do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['firedac.', 'tfdconnection', 'tfdquery', 'configdbpath', 'from logs']);

    Assert.IsTrue(SourceText.Contains('readrecententries'),
      RelativePath + ' must query logs via TUniBaseLogger.ReadRecentEntries');
    Assert.IsTrue(SourceText.Contains('clearalllogs'),
      RelativePath + ' must clear logs via TUniBaseLogger.ClearAllLogs');
  end;
end;

procedure TPackageBoundaryTests.DesignPackages_RegisterControlsOnly_NoRuntimeBootstrap;
var
  VclDclRawText: string;
  FmxDclRawText: string;
  VclDclText: string;
  FmxDclText: string;
  VclControlsText: string;
  FmxControlsText: string;
  RegisterBody: string;
begin
  VclDclRawText := ReadRepoFile('dclUniBaseVCL.dpk').ToLowerInvariant;
  FmxDclRawText := ReadRepoFile('dclUniBaseFMX.dpk').ToLowerInvariant;
  VclDclText := StripPascalComments(VclDclRawText).ToLowerInvariant;
  FmxDclText := StripPascalComments(FmxDclRawText).ToLowerInvariant;

  Assert.IsTrue(VclDclRawText.Contains('{$designonly}'),
    'dclUniBaseVCL.dpk must remain design-only');
  Assert.IsTrue(FmxDclRawText.Contains('{$designonly}'),
    'dclUniBaseFMX.dpk must remain design-only');

  Assert.IsTrue(VclDclText.Contains('unibase.vcl.controls in ''vcl\unibase.vcl.controls.pas'''),
    'dclUniBaseVCL.dpk should only register controls through UniBase.VCL.Controls');
  Assert.IsTrue(FmxDclText.Contains('unibase.fmx.controls in ''fmx\unibase.fmx.controls.pas'''),
    'dclUniBaseFMX.dpk should only register controls through UniBase.FMX.Controls');

  VclControlsText := StripPascalComments(ReadRepoFile('VCL\UniBase.VCL.Controls.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(VclControlsText, 'Register');
  AssertTextDoesNotContainAny(RegisterBody, 'UniBase.VCL.Controls.Register body',
    ['initialize', '.start', 'runtimecontext', 'createanonymousthread',
     'tthread.create', 'ttask.run', 'scheduler.start', 'workerqueue.start',
     'eventbus.start']);

  FmxControlsText := StripPascalComments(ReadRepoFile('FMX\UniBase.FMX.Controls.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(FmxControlsText, 'Register');
  AssertTextDoesNotContainAny(RegisterBody, 'UniBase.FMX.Controls.Register body',
    ['initialize', '.start', 'runtimecontext', 'createanonymousthread',
     'tthread.create', 'ttask.run', 'scheduler.start', 'workerqueue.start',
     'eventbus.start']);
end;

initialization
  TDUnitX.RegisterTestFixture(TPackageBoundaryTests);

end.
