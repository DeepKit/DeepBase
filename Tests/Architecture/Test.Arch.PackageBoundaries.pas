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
    function ReadTextFileWithFallback(const FilePath: string): string;
    function ReadTextFileLinesWithFallback(const FilePath: string): TArray<string>;
    function TextContainsInsensitive(const Text, Needle: string): Boolean;
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
    [Category('Architecture.KnownDebt')]
    procedure ServicesPackage_TracksKnownBoundaryViolations;

    [Test]
    procedure ServicesProject_DoesNotReferenceUiOrDbRuntime;

    [Test]
    procedure FeaturesPackage_ContainsOptionalFeatureUnits;

    [Test]
    procedure FeaturesPackage_ContainsIntentClarificationPhase2Units;

    [Test]
    procedure FeaturesSource_OptionalFeatureImplementationsLiveUnderFeatures;

    [Test]
    procedure PersistencePackage_ExposesSQLiteAndPostgreSQLRuntime;

    [Test]
    procedure PersistenceSource_DatabaseImplementationsLiveUnderPersistence;

    [Test]
    procedure LayerScript_TracksFireDacOutsidePersistenceDebt;

    [Test]
    procedure TestRunner_UsesWin64CompilerOnly;

    [Test]
    procedure RuntimePackages_DoNotContainTestHelperUnits;

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
    procedure UiHotkeyEditor_UsesHotkeyStorageFactoryOnly;

    [Test]
    procedure UiLLMConfigPanels_UseLLMStorageFactoryOnly;

    [Test]
    procedure UiAboutFrames_UseAntiTamperDatabasePortOnly;

    [Test]
    procedure DesignPackages_RegisterControlsOnly_NoRuntimeBootstrap;
  end;

implementation

const
  CORE_UI_DEPENDENCY_ALLOWLIST: array[0..4] of string = (
    'DeepBase.Exception.pas',
    'DeepBase.Export.pas',
    'DeepBase.SingleInstance.pas',
    'DeepBase.SplashScreen.pas',
    'DeepBase.TestHelper.pas'
  );

  CORE_DB_RUNTIME_DEPENDENCY_ALLOWLIST: array[0..8] of string = (
    'DeepBase.Manager.pas',
    'DeepBase.Config.pas',
    'DeepBase.i18n.pas',
    'DeepBase.FormState.pas',
    'DeepBase.MRU.pas',
    'DeepBase.Hotkeys.pas',
    'DeepBase.Theme.pas',
    'DeepBase.Diagnose.pas',
    'DeepBase.Security.pas'
  );

  CORE_MANAGER_DEPENDENCY_ALLOWLIST: array[0..4] of string = (
    'DeepBase.Manager.pas',
    'DeepBase.Manager.Schema.pas',
    'DeepBase.Manager.Operational.pas',
    'DeepBase.Config.pas',
    'DeepBase.Security.pas'
  );

function TPackageBoundaryTests.FindRepoRoot: string;
var
  Dir: string;
begin
  Dir := ExtractFilePath(ParamStr(0));
  while Dir <> '' do
  begin
    if TFile.Exists(TPath.Combine(Dir, 'DeepBaseCore.dpk')) and
       TFile.Exists(TPath.Combine(Dir, 'tasks.md')) then
      Exit(Dir);

    if TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)) = '' then
      Break;

    Dir := IncludeTrailingPathDelimiter(
      TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(Dir)));
  end;

  Assert.Fail('Could not locate DeepBase repository root from ' + ParamStr(0));
  Result := '';
end;

function TPackageBoundaryTests.ReadRepoFile(const RelativePath: string): string;
var
  FilePath: string;
begin
  FilePath := TPath.Combine(FindRepoRoot, RelativePath);
  Assert.IsTrue(TFile.Exists(FilePath), 'Missing file: ' + FilePath);
  Result := ReadTextFileWithFallback(FilePath);
end;

function TPackageBoundaryTests.ReadTextFileWithFallback(
  const FilePath: string): string;
begin
  try
    Exit(TFile.ReadAllText(FilePath, TEncoding.UTF8));
  except
    on EEncodingError do
      ;
    on EArgumentException do
      ;
  end;

  try
    Exit(TFile.ReadAllText(FilePath, TEncoding.Default));
  except
    on EEncodingError do
      ;
    on EArgumentException do
      ;
  end;

  Result := TFile.ReadAllText(FilePath);
end;

function TPackageBoundaryTests.ReadTextFileLinesWithFallback(
  const FilePath: string): TArray<string>;
var
  Normalized: string;
begin
  Normalized := ReadTextFileWithFallback(FilePath)
    .Replace(#13#10, #10)
    .Replace(#13, #10);
  Result := Normalized.Split([#10]);
end;

function TPackageBoundaryTests.TextContainsInsensitive(const Text,
  Needle: string): Boolean;
begin
  Result := Text.ToLowerInvariant.Contains(Needle.ToLowerInvariant);
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
  LowerText: string;
  Item: string;
begin
  LowerText := Text.ToLowerInvariant;
  for Item in Forbidden do
    Assert.IsFalse(LowerText.Contains(Item.ToLowerInvariant),
      Format('%s must not contain "%s"', [Subject, Item]));
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotRequireUiOrDesignPackages;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('DeepBaseCore.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'DeepBaseCore.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;',
     ' firedac,', ' firedac;', ' firedaccommondriver,',
     ' firedaccommondriver;', ' firedacsqlitedriver,',
     ' firedacsqlitedriver;', ' dbrtl,', ' dbrtl;']);
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotContainUiUnits;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('DeepBaseCore.dpk');

  AssertTextDoesNotContainAny(DpkText, 'DeepBaseCore.dpk contains section',
    ['VCL\', 'FMX\', 'DeepBase.VCL.', 'DeepBase.FMX.']);
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Manager'),
    'DeepBaseCore.dpk must contain DeepBase.Manager');
end;

procedure TPackageBoundaryTests.CorePackage_DoesNotContainOptionalFeatureUnits;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('DeepBaseCore.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'DeepBaseCore.dpk contains section',
    ['DeepBase.llm.', 'DeepBase.updater', 'DeepBase.autoupdate',
     'DeepBase.antitamper', 'DeepBase.unlock']);
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Protection'),
    'DeepBaseCore.dpk keeps DeepBase.Protection as the core sensitive-data primitive');
end;

procedure TPackageBoundaryTests.ServicesPackage_DoesNotRequireUiOrDesignPackages;
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('DeepBaseServices.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'DeepBaseServices.dpk requires section',
    [' fmx,', ' fmx;', ' designide,', ' designide;']);
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Services.Registration'),
    'DeepBaseServices.dpk must include Services.Registration');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Services.Crypto'),
    'DeepBaseServices.dpk must include Services.Crypto');
end;

procedure TPackageBoundaryTests.ServicesPackage_TracksKnownBoundaryViolations;
// BASIC-001/004: Services package previously violated L1 purity by requiring
// UI and database runtime packages. Keep this regression guard so those
// dependencies do not silently return.
var
  DpkText: string;
begin
  DpkText := ReadRepoFile('DeepBaseServices.dpk').ToLowerInvariant;

  Assert.IsFalse(TextContainsInsensitive(DpkText, 'vcl'),
    'DeepBaseServices.dpk must not regress to requiring VCL.');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'dbrtl'),
    'DeepBaseServices.dpk must not regress to requiring DBRTL.');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'firedac'),
    'DeepBaseServices.dpk must not regress to requiring FireDAC.');

  // These MUST remain forbidden even with current debt:
  AssertTextDoesNotContainAny(DpkText, 'DeepBaseServices.dpk contains section',
    ['features\']);
end;

procedure TPackageBoundaryTests.ServicesProject_DoesNotReferenceUiOrDbRuntime;
var
  DprojText: string;
begin
  DprojText := ReadRepoFile('DeepBaseServices.dproj').ToLowerInvariant;

  AssertTextDoesNotContainAny(DprojText, 'DeepBaseServices.dproj',
    ['<frameworktype>vcl</frameworktype>',
     '<dccreference include="vcl.dcp"',
     '<dccreference include="dbrtl.dcp"',
     '<dccreference include="firedac.dcp"',
     '<dccreference include="firedaccommondriver.dcp"',
     '<dccreference include="firedacsqlitedriver.dcp"',
     '<dccreference include="firedacpgdriver.dcp"',
     'core\deepbase.singleinstance.pas',
     'core\deepbase.feedback.pas',
     'core\deepbase.net.pas',
     'core\deepbase.orm.pas']);

  Assert.IsTrue(TextContainsInsensitive(DprojText,
    'Core\DeepBase.Security.SecretStore.pas'),
    'DeepBaseServices.dproj must stay aligned with DeepBaseServices.dpk');
end;

procedure TPackageBoundaryTests.FeaturesPackage_ContainsOptionalFeatureUnits;
var
  DpkText: string;
  DprojText: string;
begin
  DpkText := ReadRepoFile('DeepBaseFeatures.dpk').ToLowerInvariant;
  DprojText := ReadRepoFile('DeepBaseFeatures.dproj').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'DeepBaseFeatures.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;']);
  AssertTextDoesNotContainAny(DpkText, 'DeepBaseFeatures.dpk package boundary',
    [' dbrtl,', ' dbrtl;', 'firedac', 'firedaccommondriver',
     'deepbasepersistence', 'persistence\',
     'core\deepbase.llm.pas', 'core\deepbase.llm.manager.pas',
     'core\deepbase.llm.billingclient.pas',
     'core\deepbase.llm.importexport.pas',
     'features\deepbase.llm.configbridge.pas']);
  AssertTextDoesNotContainAny(DprojText, 'DeepBaseFeatures.dproj package boundary',
    ['dbrtl.dcp', 'firedac.dcp', 'firedaccommondriver.dcp',
     'deepbasepersistence.dcp', 'persistence\',
     'core\deepbase.llm.pas', 'core\deepbase.llm.manager.pas',
     'core\deepbase.llm.billingclient.pas',
     'core\deepbase.llm.importexport.pas',
     'features\deepbase.llm.configbridge.pas']);
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBaseCore'),
    'DeepBaseFeatures.dpk must require DeepBaseCore');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBaseServices'),
    'DeepBaseFeatures.dpk must require DeepBaseServices to avoid duplicate service primitives');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Net'),
    'DeepBaseFeatures.dpk must contain legacy network utilities');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.Net.pas'),
    'DeepBaseFeatures.dpk must source legacy network utilities from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Net.pas'),
    'DeepBaseFeatures.dpk must not source legacy network utilities from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.LLM.Types'),
    'DeepBaseFeatures.dpk must contain LLM types');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.LLM.Types.pas'),
    'DeepBaseFeatures.dpk must source LLM types from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.LLM.Types.pas'),
    'DeepBaseFeatures.dpk must not source LLM types from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.LLM.Service'),
    'DeepBaseFeatures.dpk must contain LLM service');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.LLM.Service.pas'),
    'DeepBaseFeatures.dpk must source LLM service from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.LLM.Service.pas'),
    'DeepBaseFeatures.dpk must not source LLM service from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Updater'),
    'DeepBaseFeatures.dpk must contain updater feature');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.Updater.pas'),
    'DeepBaseFeatures.dpk must source updater feature from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Updater.pas'),
    'DeepBaseFeatures.dpk must not source updater feature from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.AutoUpdate'),
    'DeepBaseFeatures.dpk must contain auto-update facade');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.AutoUpdate.pas'),
    'DeepBaseFeatures.dpk must source auto-update facade from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.AutoUpdate.pas'),
    'DeepBaseFeatures.dpk must not source auto-update facade from Core');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Features\DeepBase.Protection.pas'),
    'DeepBaseFeatures.dpk must not carry the removed duplicate Protection implementation');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.AntiTamper'),
    'DeepBaseFeatures.dpk must contain anti-tamper feature');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.AntiTamper.pas'),
    'DeepBaseFeatures.dpk must source anti-tamper feature from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.AntiTamper.pas'),
    'DeepBaseFeatures.dpk must not source anti-tamper feature from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Unlock'),
    'DeepBaseFeatures.dpk must contain unlock feature');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Features\DeepBase.Unlock.pas'),
    'DeepBaseFeatures.dpk must source unlock feature from Features');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Unlock.pas'),
    'DeepBaseFeatures.dpk must not source unlock feature from Core');
end;

procedure TPackageBoundaryTests.FeaturesPackage_ContainsIntentClarificationPhase2Units;
const
  REQUIRED_IC_UNITS: array[0..26] of string = (
    'DeepBase.IntentClarification.pas',
    'DeepBase.IntentClarification.Logging.pas',
    'DeepBase.IntentClarification.Types.pas',
    'DeepBase.IntentClarification.Interfaces.pas',
    'DeepBase.IntentClarification.Engine.pas',
    'DeepBase.IntentClarification.IoC.pas',
    'DeepBase.IntentClarification.Provider.L0.pas',
    'DeepBase.IntentClarification.Provider.L1.pas',
    'DeepBase.IntentClarification.Provider.L2.pas',
    'DeepBase.IntentClarification.Provider.L3.pas',
    'DeepBase.IntentClarification.Provider.L4.pas',
    'DeepBase.IntentClarification.Session.pas',
    'DeepBase.IntentClarification.SessionFSM.pas',
    'DeepBase.IntentClarification.Router.pas',
    'DeepBase.IntentClarification.SignalDetector.pas',
    'DeepBase.IntentClarification.Budget.pas',
    'DeepBase.IntentClarification.Exit.pas',
    'DeepBase.IntentClarification.OptionFrame.pas',
    'DeepBase.IntentClarification.Metrics.pas',
    'DeepBase.IntentClarification.FeatureConfig.pas',
    'DeepBase.IntentClarification.Templates.pas',
    'DeepBase.IntentClarification.Validation.pas',
    'DeepBase.IntentClarification.LLMResilience.pas',
    'DeepBase.IntentClarification.Anticipation.pas',
    'DeepBase.IntentClarification.Degradation.pas',
    'DeepBase.IntentClarification.Moments.pas',
    'DeepBase.IntentClarification.Rapport.pas'
  );
var
  DpkText: string;
  DprojText: string;
  UnitFile: string;
  FeaturePath: string;
begin
  DpkText := ReadRepoFile('DeepBaseFeatures.dpk').ToLowerInvariant;
  DprojText := ReadRepoFile('DeepBaseFeatures.dproj').ToLowerInvariant;

  for UnitFile in REQUIRED_IC_UNITS do
  begin
    FeaturePath := 'Features\' + UnitFile;
    Assert.IsTrue(TextContainsInsensitive(DpkText, FeaturePath),
      'DeepBaseFeatures.dpk must contain IntentClarification unit: ' + FeaturePath);
    Assert.IsTrue(TextContainsInsensitive(DprojText, FeaturePath),
      'DeepBaseFeatures.dproj must reference IntentClarification unit: ' + FeaturePath);
  end;

  Assert.IsTrue(TextContainsInsensitive(DpkText,
    'Features\DeepBase.IntentClarification.Registration.pas'),
    'DeepBaseFeatures.dpk must expose IntentClarification registration facade.');
  Assert.IsTrue(TextContainsInsensitive(DprojText,
    'Features\DeepBase.IntentClarification.Registration.pas'),
    'DeepBaseFeatures.dproj must expose IntentClarification registration facade.');
  Assert.IsFalse(TextContainsInsensitive(DpkText,
    'Features\DeepBase.IntentClarification.Storage.pas'),
    'IntentClarification FireDAC storage must stay in Persistence, not Features.');
  Assert.IsFalse(TextContainsInsensitive(DprojText,
    'Features\DeepBase.IntentClarification.Storage.pas'),
    'IntentClarification FireDAC storage must stay in Persistence, not Features.');
end;

procedure TPackageBoundaryTests.FeaturesSource_OptionalFeatureImplementationsLiveUnderFeatures;
const
  MOVED_FEATURE_UNITS: array[0..9] of string = (
    'DeepBase.Net.pas',
    'DeepBase.LLM.Types.pas',
    'DeepBase.LLM.Client.pas',
    'DeepBase.LLM.HTTP.pas',
    'DeepBase.LLM.Config.pas',
    'DeepBase.LLM.Service.pas',
    'DeepBase.Updater.pas',
    'DeepBase.AutoUpdate.pas',
    'DeepBase.AntiTamper.pas',
    'DeepBase.Unlock.pas'
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
  DpkText := ReadRepoFile('DeepBasePersistence.dpk').ToLowerInvariant;

  AssertTextDoesNotContainAny(DpkText, 'DeepBasePersistence.dpk requires section',
    [' vcl,', ' vcl;', ' fmx,', ' fmx;', ' designide,', ' designide;']);
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'FireDACSqliteDriver'),
    'DeepBasePersistence.dpk must require FireDAC SQLite driver');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'FireDACPGDriver'),
    'DeepBasePersistence.dpk must require FireDAC PostgreSQL driver');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.Pool'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.Pool');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.DB.Pool.pas'),
    'DeepBasePersistence.dpk must source DeepBase.DB.Pool from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.DB.Pool.pas'),
    'DeepBasePersistence.dpk must not source DeepBase.DB.Pool from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.ConnectionPool'),
    'DeepBasePersistence.dpk must contain legacy DeepBase.DB.ConnectionPool');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.DB.ConnectionPool.pas'),
    'DeepBasePersistence.dpk must source DeepBase.DB.ConnectionPool from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.DB.ConnectionPool.pas'),
    'DeepBasePersistence.dpk must not source DeepBase.DB.ConnectionPool from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.SQLLogger'),
    'DeepBasePersistence.dpk must contain DeepBase.SQLLogger');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.SQLLogger.pas'),
    'DeepBasePersistence.dpk must source DeepBase.SQLLogger from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.SQLLogger.pas'),
    'DeepBasePersistence.dpk must not source DeepBase.SQLLogger from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.DoQry'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.DoQry');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.DB.DoQry.pas'),
    'DeepBasePersistence.dpk must source DeepBase.DB.DoQry from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.DB.DoQry.pas'),
    'DeepBasePersistence.dpk must not source DeepBase.DB.DoQry from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.AutoRefreshConfig'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.AutoRefreshConfig');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.FormState.FireDAC'),
    'DeepBasePersistence.dpk must contain FormState FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.FormState.FireDAC.pas'),
    'DeepBasePersistence.dpk must source FormState FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.FormState.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source FormState FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.MRU.FireDAC'),
    'DeepBasePersistence.dpk must contain MRU FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.MRU.FireDAC.pas'),
    'DeepBasePersistence.dpk must source MRU FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.MRU.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source MRU FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.Hotkeys.FireDAC'),
    'DeepBasePersistence.dpk must contain Hotkeys FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.Hotkeys.FireDAC.pas'),
    'DeepBasePersistence.dpk must source Hotkeys FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.Hotkeys.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source Hotkeys FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.I18n.FireDAC'),
    'DeepBasePersistence.dpk must contain i18n FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.I18n.FireDAC.pas'),
    'DeepBasePersistence.dpk must source i18n FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.I18n.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source i18n FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.Config.FireDAC'),
    'DeepBasePersistence.dpk must contain Config FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.Config.FireDAC.pas'),
    'DeepBasePersistence.dpk must source Config FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.Config.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source Config FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.Logging.FireDAC'),
    'DeepBasePersistence.dpk must contain Logging FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.Logging.FireDAC.pas'),
    'DeepBasePersistence.dpk must source Logging FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.Logging.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source Logging FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.Protection.FireDAC'),
    'DeepBasePersistence.dpk must contain Protection FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.Protection.FireDAC.pas'),
    'DeepBasePersistence.dpk must source Protection FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.Protection.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source Protection FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.Theme.FireDAC'),
    'DeepBasePersistence.dpk must contain Theme FireDAC adapter');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.Theme.FireDAC.pas'),
    'DeepBasePersistence.dpk must source Theme FireDAC adapter from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.Theme.FireDAC.pas'),
    'DeepBasePersistence.dpk must not source Theme FireDAC adapter from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Persistence.RuntimeRegistration'),
    'DeepBasePersistence.dpk must contain Persistence runtime registration helper');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Persistence.RuntimeRegistration.pas'),
    'DeepBasePersistence.dpk must source runtime registration helper from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Core\DeepBase.Persistence.RuntimeRegistration.pas'),
    'DeepBasePersistence.dpk must not source runtime registration helper from Core');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.Speech.Schema'),
    'DeepBasePersistence.dpk must contain Speech schema FireDAC helper');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'Persistence\DeepBase.Speech.Schema.pas'),
    'DeepBasePersistence.dpk must source Speech schema helper from Persistence');
  Assert.IsFalse(TextContainsInsensitive(DpkText, 'Features\DeepBase.Speech.Schema.pas'),
    'DeepBasePersistence.dpk must not source Speech schema helper from Features');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.Factory'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.Factory');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.JobQueue'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.JobQueue');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.Migrations'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.Migrations');
  Assert.IsTrue(TextContainsInsensitive(DpkText, 'DeepBase.DB.StatusMachine'),
    'DeepBasePersistence.dpk must contain DeepBase.DB.StatusMachine');
end;

procedure TPackageBoundaryTests.PersistenceSource_DatabaseImplementationsLiveUnderPersistence;
const
  MOVED_DATABASE_UNITS: array[0..14] of string = (
    'DeepBase.DB.ConnectionPool.pas',
    'DeepBase.DB.Pool.pas',
    'DeepBase.DB.DoQry.pas',
    'DeepBase.SQLLogger.pas',
    'DeepBase.Persistence.Config.FireDAC.pas',
    'DeepBase.Persistence.FormState.FireDAC.pas',
    'DeepBase.Persistence.MRU.FireDAC.pas',
    'DeepBase.Persistence.Hotkeys.FireDAC.pas',
    'DeepBase.Persistence.I18n.FireDAC.pas',
    'DeepBase.Persistence.Logging.FireDAC.pas',
    'DeepBase.Persistence.Protection.FireDAC.pas',
    'DeepBase.Persistence.Theme.FireDAC.pas',
    'DeepBase.Persistence.RuntimeRegistration.pas',
    'DeepBase.IntentClarification.Storage.pas',
    'DeepBase.Speech.Schema.pas'
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
    Assert.IsFalse(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Features'), UnitFile)),
      UnitFile + ' must not remain under Features');
    Assert.IsTrue(TFile.Exists(TPath.Combine(TPath.Combine(Root, 'Persistence'), UnitFile)),
      UnitFile + ' must live under Persistence');
  end;
end;

procedure TPackageBoundaryTests.LayerScript_TracksFireDacOutsidePersistenceDebt;
var
  ScriptText: string;
begin
  ScriptText := ReadRepoFile('Scripts\check-layer-violations.ps1').ToLowerInvariant;

  Assert.IsTrue(TextContainsInsensitive(ScriptText, 'FireDacOutsidePersistence'),
    'Layer check must keep the FireDAC-outside-Persistence gate.');
  Assert.IsTrue(TextContainsInsensitive(ScriptText, 'KnownFireDacOutsidePersistence'),
    'Layer check must track existing FireDAC adapter debt explicitly.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'Features\DeepBase.AntiTamper.pas'),
    'AntiTamper storage moved behind Persistence adapter and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText,
    'Features\DeepBase.IntentClarification.Storage.pas'),
    'IntentClarification storage moved to Persistence and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText,
    'Features\DeepBase.Speech.Schema.pas'),
    'Speech schema moved to Persistence and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'VCL\DeepBase.VCL.LogListView.pas'),
    'VCL log viewer must use the logger view port and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'FMX\DeepBase.FMX.LogListView.pas'),
    'FMX log viewer must use the logger view port and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'FMX\DeepBase.FMX.HotkeyEditor.pas'),
    'FMX hotkey editor must use the hotkey storage factory and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'VCL\DeepBase.VCL.LLMConfigPanel.pas'),
    'VCL LLM config panel must use the LLM storage factory and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'FMX\DeepBase.FMX.LLMConfigPanel.pas'),
    'FMX LLM config panel must use the LLM storage factory and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'VCL\DeepBase.VCL.AboutFrame.pas'),
    'VCL about frame must use the anti-tamper database port and must not remain known FireDAC debt.');
  Assert.IsFalse(TextContainsInsensitive(ScriptText, 'FMX\DeepBase.FMX.AboutFrame.pas'),
    'FMX about frame must use the anti-tamper database port and must not remain known FireDAC debt.');
end;

procedure TPackageBoundaryTests.TestRunner_UsesWin64CompilerOnly;
var
  ScriptText: string;
begin
  ScriptText := ReadRepoFile('Scripts\run_tests.ps1').ToLowerInvariant;

  Assert.IsTrue(TextContainsInsensitive(ScriptText, '$platform = ''win64'''),
    'Scripts\run_tests.ps1 must default to Win64 test platform');
  Assert.IsTrue(TextContainsInsensitive(ScriptText, 'dcc64.exe'),
    'Scripts\run_tests.ps1 must compile tests with dcc64');
  Assert.IsTrue(TextContainsInsensitive(ScriptText, 'dcu\$platform'),
    'Scripts\run_tests.ps1 must write DCUs into a Win64-specific directory');
  Assert.IsTrue(TextContainsInsensitive(ScriptText, 'if ($platform -eq ''win64'')'),
    'Scripts\run_tests.ps1 must explicitly route Win64 builds to dcc64');
end;

procedure TPackageBoundaryTests.RuntimePackages_DoNotContainTestHelperUnits;
const
  RUNTIME_PACKAGES: array[0..5] of string = (
    'DeepBaseCore.dpk',
    'DeepBaseServices.dpk',
    'DeepBasePersistence.dpk',
    'DeepBaseFeatures.dpk',
    'DeepBaseVCL.dpk',
    'DeepBaseFMX.dpk'
  );
var
  PackagePath: string;
  SourceFile: string;
  FileNameOnly: string;
  Violations: TStringList;
begin
  Violations := TStringList.Create;
  try
    for PackagePath in RUNTIME_PACKAGES do
      for SourceFile in PackageContainsSourceFiles(PackagePath) do
      begin
        FileNameOnly := ExtractFileName(SourceFile);
        if FileNameOnly.StartsWith('Test.', True) or
           FileNameOnly.Contains('TestHelper') then
          Violations.Add(PackagePath + ': ' + SourceFile);
      end;

    Assert.IsTrue(Violations.Count = 0,
      'Runtime packages must not contain test helper units:' + sLineBreak +
      Violations.Text);
  finally
    Violations.Free;
  end;
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

    for FilePath in PackageContainsSourceFiles('DeepBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);
      if Allowlist.ContainsKey(FileNameOnly.ToLowerInvariant) then
        Continue;

      Lines := ReadTextFileLinesWithFallback(FilePath);
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
  Allowlist: TDictionary<string, Boolean>;
  Violations: TStringList;
begin
  Allowlist := TDictionary<string, Boolean>.Create;
  Violations := TStringList.Create;
  try
    for FileNameOnly in CORE_DB_RUNTIME_DEPENDENCY_ALLOWLIST do
      Allowlist.AddOrSetValue(FileNameOnly.ToLowerInvariant, True);

    for FilePath in PackageContainsSourceFiles('DeepBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);
      if Allowlist.ContainsKey(FileNameOnly.ToLowerInvariant) then
        Continue;

      SourceText := StripPascalComments(
        ReadTextFileWithFallback(FilePath)).ToLowerInvariant;
      if SourceText.Contains('firedac.') or
         SourceText.Contains('tfdconnection') or
         SourceText.Contains('tfdquery') or
         SourceText.Contains('data.db') then
        Violations.Add(FileNameOnly);
    end;

    Assert.IsTrue(Violations.Count = 0,
      'DeepBaseCore.dpk units must not depend on FireDAC/Data.DB/TFDConnection/TFDQuery:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
    Allowlist.Free;
  end;
end;

procedure TPackageBoundaryTests.CoreSource_DoesNotDependOnManagerOutsideBootstrap;
var
  FilePath: string;
  FileNameOnly: string;
  SourceText: string;
  Allowlist: TDictionary<string, Boolean>;
  Violations: TStringList;
begin
  Allowlist := TDictionary<string, Boolean>.Create;
  Violations := TStringList.Create;
  try
    for FileNameOnly in CORE_MANAGER_DEPENDENCY_ALLOWLIST do
      Allowlist.AddOrSetValue(FileNameOnly.ToLowerInvariant, True);

    for FilePath in PackageContainsSourceFiles('DeepBaseCore.dpk') do
    begin
      Assert.IsTrue(TFile.Exists(FilePath), 'Missing source file: ' + FilePath);
      FileNameOnly := ExtractFileName(FilePath);
      if Allowlist.ContainsKey(FileNameOnly.ToLowerInvariant) then
        Continue;

      SourceText := StripPascalComments(
        ReadTextFileWithFallback(FilePath)).ToLowerInvariant;
      if SourceText.Contains('deepbase.manager') then
        Violations.Add(FileNameOnly);
    end;

    Assert.IsTrue(Violations.Count = 0,
      'DeepBaseCore.dpk units must not depend on DeepBase.Manager:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
    Allowlist.Free;
  end;
end;

procedure TPackageBoundaryTests.ServicesRegistration_DoesNotStartBackgroundServices;
var
  SourceText: string;
  RegisterBody: string;
begin
  SourceText := StripPascalComments(
    ReadRepoFile('Core\DeepBase.Services.Registration.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(SourceText, 'RegisterFrameworkServices');

  AssertTextDoesNotContainAny(RegisterBody, 'RegisterFrameworkServices body',
    ['.start', 'tthread.create', 'ttask.run', 'scheduler.start',
     'workerqueue.start', 'eventbus.start']);
end;

procedure TPackageBoundaryTests.DownstreamPrimitives_DoNotDependOnHttpLlmNotifyOrBackgroundThreads;
const
  PRIMITIVE_UNITS: array[0..5] of string = (
    'Core\DeepBase.AppLifecycle.pas',
    'Persistence\DeepBase.DB.AutoRefreshConfig.pas',
    'Persistence\DeepBase.DB.Factory.pas',
    'Persistence\DeepBase.DB.JobQueue.pas',
    'Persistence\DeepBase.DB.Migrations.pas',
    'Persistence\DeepBase.DB.StatusMachine.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in PRIMITIVE_UNITS do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['DeepBase.llm', 'DeepBase.httpserver', 'idhttp', 'system.net.httpclient',
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
        if not ExtractFileName(FilePath).StartsWith('DeepBase.', True) then
          Continue;

        SourceText := StripPascalComments(
          ReadTextFileWithFallback(FilePath)).ToLowerInvariant;

        if TRegEx.IsMatch(SourceText,
             '\bDeepBase\.manager\.DeepBase\.configdb\b', [roIgnoreCase]) or
           TRegEx.IsMatch(SourceText,
             '\bDeepBase\.configdb\b', [roIgnoreCase]) then
          Violations.Add(FilePath);
      end;
    end;

    Assert.IsTrue(Violations.Count = 0,
      'UI adapters must not directly access DeepBase.Manager.DeepBase.ConfigDB:' +
      sLineBreak + Violations.Text);
  finally
    Violations.Free;
  end;
end;

procedure TPackageBoundaryTests.UiLogListView_UsesLoggerQueryPortOnly;
const
  FILES: array[0..1] of string = (
    'VCL\DeepBase.VCL.LogListView.pas',
    'FMX\DeepBase.FMX.LogListView.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in FILES do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    Assert.IsTrue(SourceText.Contains('readrecentlogs') and
                  SourceText.Contains('clearlogs') and
                  SourceText.Contains('message'),
      RelativePath + ' must keep stable projection for log viewer columns');
    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['firedac.', 'tfDconnection', 'tfDquery', 'tfDcommand', 'data.db',
       'deepbase.manager.deepbase.configdb', 'delete from logs']);
  end;
end;

procedure TPackageBoundaryTests.UiHotkeyEditor_UsesHotkeyStorageFactoryOnly;
var
  SourceText: string;
begin
  SourceText := StripPascalComments(
    ReadRepoFile('FMX\DeepBase.FMX.HotkeyEditor.pas')).ToLowerInvariant;

  Assert.IsTrue(SourceText.Contains('tdeepbasehotkeys.create(fconnection)'),
    'FMX hotkey editor must keep using the Core hotkey storage factory bridge.');
  AssertTextDoesNotContainAny(SourceText, 'FMX\DeepBase.FMX.HotkeyEditor.pas',
    ['firedac.', 'tfdconnection', 'tfdquery', 'tfdcommand', 'data.db']);
end;

procedure TPackageBoundaryTests.UiLLMConfigPanels_UseLLMStorageFactoryOnly;
const
  FILES: array[0..1] of string = (
    'VCL\DeepBase.VCL.LLMConfigPanel.pas',
    'FMX\DeepBase.FMX.LLMConfigPanel.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in FILES do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    Assert.IsTrue(SourceText.Contains('tdeepbasellm.create(fconnection)'),
      RelativePath + ' must keep using the Core LLM storage factory bridge.');
    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['firedac.', 'tfdconnection', 'tfdquery', 'tfdcommand', 'data.db']);
  end;
end;

procedure TPackageBoundaryTests.UiAboutFrames_UseAntiTamperDatabasePortOnly;
const
  FILES: array[0..1] of string = (
    'VCL\DeepBase.VCL.AboutFrame.pas',
    'FMX\DeepBase.FMX.AboutFrame.pas'
  );
var
  RelativePath: string;
  SourceText: string;
begin
  for RelativePath in FILES do
  begin
    SourceText := StripPascalComments(ReadRepoFile(RelativePath)).ToLowerInvariant;

    Assert.IsTrue(SourceText.Contains('loadsecureimagebytesfromdatabase'),
      RelativePath + ' must delegate secure image loading behind AntiTamper.');
    AssertTextDoesNotContainAny(SourceText, RelativePath,
      ['firedac.', 'tfdconnection', 'tfdquery', 'tfdtable',
       'tfdcommand', 'data.db']);
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
  VclDclRawText := ReadRepoFile('dclDeepBaseVCL.dpk').ToLowerInvariant;
  FmxDclRawText := ReadRepoFile('dclDeepBaseFMX.dpk').ToLowerInvariant;
  VclDclText := StripPascalComments(VclDclRawText).ToLowerInvariant;
  FmxDclText := StripPascalComments(FmxDclRawText).ToLowerInvariant;

  Assert.IsTrue(VclDclRawText.Contains('{$designonly}'),
    'dclDeepBaseVCL.dpk must remain design-only');
  Assert.IsTrue(FmxDclRawText.Contains('{$designonly}'),
    'dclDeepBaseFMX.dpk must remain design-only');

  Assert.IsTrue(TextContainsInsensitive(VclDclText, 'DeepBase.VCL.Controls in ''VCL\DeepBase.VCL.Controls.pas'''),
    'dclDeepBaseVCL.dpk should only register controls through DeepBase.VCL.Controls');
  Assert.IsTrue(TextContainsInsensitive(FmxDclText, 'DeepBase.FMX.Controls in ''FMX\DeepBase.FMX.Controls.pas'''),
    'dclDeepBaseFMX.dpk should only register controls through DeepBase.FMX.Controls');

  VclControlsText := StripPascalComments(ReadRepoFile('VCL\DeepBase.VCL.Controls.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(VclControlsText, 'Register');
  AssertTextDoesNotContainAny(RegisterBody, 'DeepBase.VCL.Controls.Register body',
    ['initialize', '.start', 'runtimecontext', 'createanonymousthread',
     'tthread.create', 'ttask.run', 'scheduler.start', 'workerqueue.start',
     'eventbus.start']);

  FmxControlsText := StripPascalComments(ReadRepoFile('FMX\DeepBase.FMX.Controls.pas')).ToLowerInvariant;
  RegisterBody := ExtractRoutineText(FmxControlsText, 'Register');
  AssertTextDoesNotContainAny(RegisterBody, 'DeepBase.FMX.Controls.Register body',
    ['initialize', '.start', 'runtimecontext', 'createanonymousthread',
     'tthread.create', 'ttask.run', 'scheduler.start', 'workerqueue.start',
     'eventbus.start']);
end;

initialization
  TDUnitX.RegisterTestFixture(TPackageBoundaryTests);

end.
