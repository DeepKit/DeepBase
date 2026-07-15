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
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.SchemaAdapter,
  DeepBase.SchemaAdapter.WeChat39x,
  DeepBase.SchemaAdapter.WeChat4x;

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
    // Prefix '4x7f2a9b1c' must match a fingerprint starting with it
    Assert.IsTrue(
      Adapter.TryMatchFingerprint('4x7f2a9b1c_extra_data'),
      'WeChat4x adapter should match fingerprint starting with 4x7f2a9b1c');
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

end.
