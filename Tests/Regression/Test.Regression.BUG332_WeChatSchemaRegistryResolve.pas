{*****************************************************************************
  Test.Regression.BUG332_WeChatSchemaRegistryResolve - REVIEW5-DATA-003 / WO-002

  Verifies WeChat39x/4x schema adapter registry resolution:
  - Fingerprint prefixes are valid hex (>= 10 chars)
  - Msg column-signature SHA256 from fixture matches frozen authority
  - Registry resolves column-signature fingerprint to WeChat4x
  - Name2Id signature does not falsely match 4x
  - Empty Msg column signature must not be fed to Registry (helpers)
  *****************************************************************************}

unit Test.Regression.BUG332_WeChatSchemaRegistryResolve;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.Hash,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Exceptions,
  DeepBase.SchemaAdapter,
  DeepBase.SchemaAdapter.WeChat39x,
  DeepBase.SchemaAdapter.WeChat4x,
  DeepBase.SchemaAdapter.Registry,
  DeepBase.External.Types;

type
  [TestFixture]
  [Category('regression')]
  TBUG332_WeChatSchemaRegistryResolveTest = class(TRegressionTestBase)
  private
    function FixtureDir: string;
    procedure LoadTableInfoNamesTypes(const APath: string;
      out ANames, ATypes: TArray<string>);
  public
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;

    [Test]
    procedure Test_WeChat39x_FingerprintPrefixValid;

    [Test]
    procedure Test_WeChat4x_FingerprintPrefixValid;

    [Test]
    procedure Test_WeChat39x_FingerprintMatch;

    [Test]
    procedure Test_WeChat4x_FingerprintMatch;

    [Test]
    procedure Test_Adapter_Reject_NonMatching;

    [Test]
    procedure Test_InvalidHexPrefix_RaisesOnValidate;

    /// <summary>Fixture Msg column signature SHA256 equals frozen authority</summary>
    [Test]
    procedure Test_Fixture_MsgColumnSignature_MatchesFrozenSHA256;

    /// <summary>Registry TryResolve(columnSig) hits TWeChat4xAdapter</summary>
    [Test]
    procedure Test_Registry_Resolve_ColumnSignature_HitsWeChat4x;

    /// <summary>Name2Id column signature must not match WeChat4x</summary>
    [Test]
    procedure Test_Name2Id_Signature_DoesNotMatchWeChat4x;

    /// <summary>Empty column-signature fingerprint skips Registry match</summary>
    [Test]
    procedure Test_EmptyColumnSignature_DoesNotMatchAnyAdapter;
  end;

implementation

const
  CFrozenMsgColumnSigSHA256 =
    '26d53fe31f389e65779419dc30bfdd73df5f1c299215fa4a0dccd525910cda84';
  CFrozenMsgColumnSigPrefix = '26d53fe31f';

{ TBUG332_WeChatSchemaRegistryResolveTest }

function TBUG332_WeChatSchemaRegistryResolveTest.GetBugNumber: string;
begin
  Result := 'BUG-332';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetBugDescription: string;
begin
  Result := 'SchemaAdapter resolve used full fingerprint vs column-signature prefixes';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetFixDate: string;
begin
  Result := '2026-09-02';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetAffectedFile: string;
begin
  Result := 'DeepAxis/DeepBase.External.SQLiteReader.pas, Core/DeepBase.SchemaAdapter.WeChat4x.pas';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.FixtureDir: string;
begin
  // Tests\Regression\Fixtures\WeChat4x relative to exe or project Tests root
  Result := TPath.Combine(ExtractFilePath(ParamStr(0)),
    'Tests\Regression\Fixtures\WeChat4x');
  if not TDirectory.Exists(Result) then
    Result := TPath.Combine(ExtractFilePath(ParamStr(0)),
      'Regression\Fixtures\WeChat4x');
  if not TDirectory.Exists(Result) then
  begin
    // DeepBaseTests often runs with cwd = repo root or Tests\
    Result := TPath.GetFullPath(TPath.Combine(TDirectory.GetCurrentDirectory,
      'Tests\Regression\Fixtures\WeChat4x'));
    if not TDirectory.Exists(Result) then
      Result := TPath.GetFullPath(TPath.Combine(TDirectory.GetCurrentDirectory,
        'Regression\Fixtures\WeChat4x'));
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.LoadTableInfoNamesTypes(
  const APath: string; out ANames, ATypes: TArray<string>);
var
  Lines: TStringList;
  I, Tab1, Tab2: Integer;
  Line, Name, ColType: string;
  Names, Types: TList<string>;
begin
  Names := TList<string>.Create;
  Types := TList<string>.Create;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(APath, TEncoding.UTF8);
    // Skip header: cid name type ...
    for I := 1 to Lines.Count - 1 do
    begin
      Line := Lines[I].Trim;
      if Line = '' then
        Continue;
      Tab1 := Pos(#9, Line);
      Assert.IsTrue(Tab1 > 0, 'Expected tab-separated table_info: ' + APath);
      Line := Copy(Line, Tab1 + 1, MaxInt);
      Tab1 := Pos(#9, Line);
      Assert.IsTrue(Tab1 > 0, 'Expected name column: ' + APath);
      Name := Copy(Line, 1, Tab1 - 1);
      Line := Copy(Line, Tab1 + 1, MaxInt);
      Tab2 := Pos(#9, Line);
      if Tab2 > 0 then
        ColType := Copy(Line, 1, Tab2 - 1)
      else
        ColType := Line;
      Names.Add(Name);
      Types.Add(ColType);
    end;
    ANames := Names.ToArray;
    ATypes := Types.ToArray;
  finally
    Lines.Free;
    Names.Free;
    Types.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat39x_FingerprintPrefixValid;
var
  Adapter: TWeChat39xAdapter;
begin
  Adapter := TWeChat39xAdapter.Create;
  try
    Adapter.Validate;
    Assert.Pass('WeChat39x adapter validation passed');
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat4x_FingerprintPrefixValid;
var
  Adapter: TWeChat4xAdapter;
  Prefixes: TArray<string>;
begin
  Adapter := TWeChat4xAdapter.Create;
  try
    Adapter.Validate;
    Prefixes := Adapter.GetSchemaFingerprintPrefixes;
    Assert.AreEqual(1, Integer(Length(Prefixes)));
    Assert.AreEqual(CFrozenMsgColumnSigPrefix, Prefixes[0]);
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat39x_FingerprintMatch;
var
  Adapter: TWeChat39xAdapter;
begin
  Adapter := TWeChat39xAdapter.Create;
  try
    // Placeholder prefix still matches its own contract string (BLOCKED-39X-DATA).
    Assert.IsTrue(
      Adapter.TryMatchFingerprint('e4a7b3c9f1_extra_data'),
      'WeChat39x adapter should match fingerprint starting with e4a7b3c9f1');
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat4x_FingerprintMatch;
var
  Adapter: TWeChat4xAdapter;
begin
  Adapter := TWeChat4xAdapter.Create;
  try
    Assert.IsTrue(
      Adapter.TryMatchFingerprint(CFrozenMsgColumnSigSHA256),
      'WeChat4x must match frozen Msg column-signature SHA256');
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_Adapter_Reject_NonMatching;
var
  Adapter39x: TWeChat39xAdapter;
  Adapter4x: TWeChat4xAdapter;
begin
  Adapter39x := TWeChat39xAdapter.Create;
  try
    Assert.IsFalse(
      Adapter39x.TryMatchFingerprint('deadbeef00_unknown'),
      'WeChat39x adapter should NOT match unrelated fingerprint');
  finally
    Adapter39x.Free;
  end;

  Adapter4x := TWeChat4xAdapter.Create;
  try
    Assert.IsFalse(
      Adapter4x.TryMatchFingerprint('deadbeef00_unknown'),
      'WeChat4x adapter should NOT match unrelated fingerprint');
  finally
    Adapter4x.Free;
  end;
end;

type
  TInvalidHexPrefixAdapter = class(TWeChat39xAdapter)
  public
    constructor Create; override;
  end;

constructor TInvalidHexPrefixAdapter.Create;
begin
  inherited;
  FSchemaFingerprintPrefixes := ['zzzzzzzzzz'];
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_InvalidHexPrefix_RaisesOnValidate;
var
  Adapter: TInvalidHexPrefixAdapter;
  LProc: TProc;
begin
  Adapter := TInvalidHexPrefixAdapter.Create;
  try
    LProc := procedure
      begin
        Adapter.Validate;
      end;
    Assert.WillRaise(LProc, ESchemaAdapterValidationError);
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_Fixture_MsgColumnSignature_MatchesFrozenSHA256;
var
  Dir, Sig, Hash: string;
  Names, Types: TArray<string>;
begin
  Dir := FixtureDir;
  Assert.IsTrue(TDirectory.Exists(Dir), 'Fixture dir missing: ' + Dir);
  LoadTableInfoNamesTypes(TPath.Combine(Dir, 'Msg_sample.txt'), Names, Types);
  Assert.AreEqual(17, Integer(Length(Names)), 'Msg sample must have 17 columns');
  Sig := FormatColumnSignature(Names, Types);
  Hash := HashColumnSignatureFingerprint(Sig);
  Assert.AreEqual(CFrozenMsgColumnSigSHA256, Hash,
    'Fixture Msg column signature SHA256 must equal frozen authority');
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_Registry_Resolve_ColumnSignature_HitsWeChat4x;
var
  Registry: TSchemaAdapterRegistry;
  Adapter: ISchemaAdapter;
  Dir, Hash: string;
  Names, Types: TArray<string>;
begin
  Dir := FixtureDir;
  LoadTableInfoNamesTypes(TPath.Combine(Dir, 'Msg_sample.txt'), Names, Types);
  Hash := HashColumnSignatureFingerprint(FormatColumnSignature(Names, Types));

  Registry := TSchemaAdapterRegistry.Create;
  try
    Registry.Register('3.9.0-3.9.99', TWeChat39xAdapter);
    Registry.Register('4.0.0-4.99.99', TWeChat4xAdapter);

    Assert.IsTrue(
      Registry.TryResolve(Hash, '4.1.13', Adapter),
      'Registry must resolve frozen Msg column-signature to an adapter');
    Assert.IsTrue(Supports(Adapter, ISchemaAdapter));
    Assert.AreEqual('4.x', Adapter.GetVersion,
      'Resolved adapter must be WeChat4x (version 4.x)');
  finally
    Registry.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_Name2Id_Signature_DoesNotMatchWeChat4x;
var
  Registry: TSchemaAdapterRegistry;
  Adapter: ISchemaAdapter;
  Dir, Hash: string;
  Names, Types: TArray<string>;
  Adapter4x: TWeChat4xAdapter;
begin
  Dir := FixtureDir;
  LoadTableInfoNamesTypes(TPath.Combine(Dir, 'Name2Id.txt'), Names, Types);
  Hash := HashColumnSignatureFingerprint(FormatColumnSignature(Names, Types));

  Adapter4x := TWeChat4xAdapter.Create;
  try
    Assert.IsFalse(Adapter4x.TryMatchFingerprint(Hash),
      'Name2Id column signature must not match WeChat4x prefix');
  finally
    Adapter4x.Free;
  end;

  Registry := TSchemaAdapterRegistry.Create;
  try
    Registry.Register('4.0.0-4.99.99', TWeChat4xAdapter);
    Assert.IsFalse(
      Registry.TryResolve(Hash, '4.1.0', Adapter),
      'Registry must not resolve Name2Id signature to WeChat4x');
  finally
    Registry.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_EmptyColumnSignature_DoesNotMatchAnyAdapter;
var
  Registry: TSchemaAdapterRegistry;
  Adapter: ISchemaAdapter;
begin
  // Mirrors SQLiteReader: empty Msg column signature must not enter TryResolve
  // as a match candidate. Registry should reject empty fingerprint.
  Registry := TSchemaAdapterRegistry.Create;
  try
    Registry.Register('3.9.0-3.9.99', TWeChat39xAdapter);
    Registry.Register('4.0.0-4.99.99', TWeChat4xAdapter);
    Assert.IsFalse(
      Registry.TryResolve('', '4.1.0', Adapter),
      'Empty fingerprint must not resolve any adapter');
  finally
    Registry.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG332_WeChatSchemaRegistryResolveTest);

end.
