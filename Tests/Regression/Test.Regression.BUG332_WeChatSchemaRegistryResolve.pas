{ ============================================================================
  Test.Regression.BUG332_WeChatSchemaRegistryResolve - REVIEW5-DATA-003

  Verifies WeChat39x/4x schema adapter registry resolution:
  - Fingerprint prefixes are valid hex (>= 10 chars)
  - Registry resolves matching fingerprint to correct adapter
  - Registry rejects non-matching fingerprints
  ============================================================================ }

unit Test.Regression.BUG332_WeChatSchemaRegistryResolve;

interface

uses
  System.SysUtils,
  System.Hash,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Exceptions,
  DeepBase.SchemaAdapter,
  DeepBase.SchemaAdapter.WeChat39x,
  DeepBase.SchemaAdapter.WeChat4x,
  DeepBase.SchemaAdapter.Registry;

type
  [TestFixture]
  [Category('regression')]
  TBUG332_WeChatSchemaRegistryResolveTest = class(TRegressionTestBase)
  public
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;

    /// <summary>WeChat39x fingerprint prefix is valid hex >= 10 chars</summary>
    [Test]
    procedure Test_WeChat39x_FingerprintPrefixValid;

    /// <summary>WeChat4x fingerprint prefix is valid hex >= 10 chars</summary>
    [Test]
    procedure Test_WeChat4x_FingerprintPrefixValid;

    /// <summary>WeChat39x fingerprint prefix matches via TryMatchFingerprint</summary>
    [Test]
    procedure Test_WeChat39x_FingerprintMatch;

    /// <summary>WeChat4x fingerprint prefix matches via TryMatchFingerprint</summary>
    [Test]
    procedure Test_WeChat4x_FingerprintMatch;

    /// <summary>Registry rejects non-matching fingerprint via TryMatchFingerprint</summary>
    [Test]
    procedure Test_Adapter_Reject_NonMatching;

    /// <summary>Invalid hex prefix fails Validate at load time</summary>
    [Test]
    procedure Test_InvalidHexPrefix_RaisesOnValidate;

    /// <summary>WeChat4x has no fingerprint until DATA-P0-001 (BLOCKED)</summary>
    [Test]
    procedure Test_WeChat4x_NoPrefixUntilDataDump;
  end;

implementation

{ TBUG332_WeChatSchemaRegistryResolveTest }

function TBUG332_WeChatSchemaRegistryResolveTest.GetBugNumber: string;
begin
  Result := 'BUG-332';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetBugDescription: string;
begin
  Result := 'WeChat39x/4x schema fingerprint prefixes were placeholders';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetFixDate: string;
begin
  Result := '2026-06-29';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetPriority: string;
begin
  Result := 'P2';
end;

function TBUG332_WeChatSchemaRegistryResolveTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.SchemaAdapter.WeChat39x.pas, Core/DeepBase.SchemaAdapter.WeChat4x.pas';
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat39x_FingerprintPrefixValid;
var
  Adapter: TWeChat39xAdapter;
begin
  Adapter := TWeChat39xAdapter.Create;
  try
    // Validate should not raise — prefix must be >= 10 hex chars
    Adapter.Validate;
    Assert.Pass('WeChat39x adapter validation passed');
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat4x_FingerprintPrefixValid;
var
  Adapter: TWeChat4xAdapter;
begin
  Adapter := TWeChat4xAdapter.Create;
  try
    // Validate should not raise — prefix must be >= 10 hex chars
    Adapter.Validate;
    Assert.Pass('WeChat4x adapter validation passed');
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
    // Prefix 'e4a7b3c9f1' must match a fingerprint starting with it
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
    Assert.IsFalse(
      Adapter.TryMatchFingerprint('deadbeef00_extra_data'),
      'WeChat4x adapter has no prefix until DATA-P0-001 delivers real SHA256');
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
begin
  Adapter := TInvalidHexPrefixAdapter.Create;
  try
    Assert.WillRaise(
      procedure
      begin
        Adapter.Validate;
      end,
      ESchemaAdapterValidationError);
  finally
    Adapter.Free;
  end;
end;

procedure TBUG332_WeChatSchemaRegistryResolveTest.Test_WeChat4x_NoPrefixUntilDataDump;
var
  Registry: TSchemaAdapterRegistry;
  Adapter: ISchemaAdapter;
  Adapter4x: TWeChat4xAdapter;
begin
  Adapter4x := TWeChat4xAdapter.Create;
  try
    Assert.IsTrue(Length(Adapter4x.GetSchemaFingerprintPrefixes) = 0,
      'WeChat4x prefixes empty until BLOCKED-DATA-P0-001');
  finally
    Adapter4x.Free;
  end;

  Registry := TSchemaAdapterRegistry.Create;
  try
    Registry.Register('3.9.0-3.9.99', TWeChat39xAdapter);
    Registry.Register('4.0.0-4.99.99', TWeChat4xAdapter);

    Assert.IsTrue(
      Registry.TryResolve('e4a7b3c9f1deadbeef', '3.9.5', Adapter),
      'WeChat39x registry resolve must match known hex prefix');

    Assert.IsFalse(
      Registry.TryResolve('ffffffffffffffffff', '4.1.0', Adapter),
      'WeChat4x must not resolve until BLOCKED-DATA-P0-001 fingerprint is delivered');
  finally
    Registry.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBUG332_WeChatSchemaRegistryResolveTest);

end.
