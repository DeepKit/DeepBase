{ ============================================================================
  Test.DeepBase.Security.MachineIdentity - Unit tests for the binding SSOT

  Test Coverage:
    - Canonical form and hash stability
    - Full match semantics: every source and the scheme version must agree
      (replaces the old "5 中 3" threshold)
    - Collection on the current host: all sources present, values non-empty,
      and no user-renameable identifier (computer name) involved
  ============================================================================ }

unit Test.DeepBase.Security.MachineIdentity;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Security.MachineIdentity;

type
  [TestFixture]
  TTestMachineIdentity = class
  private
    function Identity(const AScheme: Integer;
      const APairs: array of string): TMachineIdentity;
  public    [Test]
    procedure Test_Canonical_IsVersionedAndOrdered;
    [Test]
    procedure Test_ToHash_StableAndSensitiveToEverySource;
    [Test]
    procedure Test_Matches_RequiresEverySource;
    [Test]
    procedure Test_Matches_RequiresSchemeVersion;
    [Test]
    procedure Test_ToBinding_RoundTripsCanonical;
    [Test]
    procedure Test_Collect_HasAllMandatorySources;
    [Test]
    procedure Test_Collect_ExcludesUserRenameableIdentity;
    [Test]
    procedure Test_Provider_FingerprintAndBindingAgree;
  end;

implementation

{ TTestMachineIdentity }

function TTestMachineIdentity.Identity(const AScheme: Integer;
  const APairs: array of string): TMachineIdentity;
var
  I: Integer;
begin
  Result := Default(TMachineIdentity);
  Result.SchemeVersion := AScheme;
  SetLength(Result.Sources, Length(APairs) div 2);
  for I := 0 to High(Result.Sources) do
  begin
    Result.Sources[I].Name := APairs[I * 2];
    Result.Sources[I].Value := APairs[I * 2 + 1];
  end;
end;

procedure TTestMachineIdentity.Test_Canonical_IsVersionedAndOrdered;
var
  L: TMachineIdentity;
begin
  L := Identity(MACHINE_IDENTITY_SCHEME_VERSION,
    ['guid', 'AAA', 'serial', '111']);
  Assert.AreEqual('v' + IntToStr(MACHINE_IDENTITY_SCHEME_VERSION) +
    '|guid=AAA|serial=111', L.Canonical);
end;

procedure TTestMachineIdentity.Test_ToHash_StableAndSensitiveToEverySource;
var
  A, B, C: TMachineIdentity;
begin
  A := Identity(1, ['guid', 'AAA', 'serial', '111']);
  B := Identity(1, ['guid', 'AAA', 'serial', '111']);
  Assert.AreEqual(A.ToHash, B.ToHash);

  // Changing any single source changes the hash, which is what makes the
  // keystore gate a full match rather than a threshold.
  C := Identity(1, ['guid', 'AAA', 'serial', '222']);
  Assert.AreNotEqual(A.ToHash, C.ToHash);

  C := Identity(1, ['guid', 'BBB', 'serial', '111']);
  Assert.AreNotEqual(A.ToHash, C.ToHash);
end;

procedure TTestMachineIdentity.Test_Matches_RequiresEverySource;
var
  A, B: TMachineIdentity;
begin
  A := Identity(1, ['guid', 'AAA', 'serial', '111', 'third', '333']);
  Assert.IsTrue(A.Matches(Identity(1, ['guid', 'AAA', 'serial', '111', 'third', '333'])));

  // 4 of 3 sources still agree: the old "5 中 3" rule accepted this, the gate must not.
  B := Identity(1, ['guid', 'AAA', 'serial', '111', 'third', '999']);
  Assert.IsFalse(A.Matches(B));

  B := Identity(1, ['guid', 'AAA', 'serial', '111']);
  Assert.IsFalse(A.Matches(B), 'A missing source is a mismatch');
end;

procedure TTestMachineIdentity.Test_Matches_RequiresSchemeVersion;
var
  A: TMachineIdentity;
begin
  A := Identity(1, ['guid', 'AAA', 'serial', '111']);
  Assert.IsFalse(A.Matches(Identity(2, ['guid', 'AAA', 'serial', '111'])),
    'A collector scheme bump must not be treated as the same machine');
end;

procedure TTestMachineIdentity.Test_ToBinding_RoundTripsCanonical;
var
  A: TMachineIdentity;
begin
  A := Identity(1, ['guid', 'AAA', 'serial', '111']);
  Assert.AreEqual(A.Canonical, TEncoding.UTF8.GetString(A.ToBinding));
end;

procedure TTestMachineIdentity.Test_Collect_HasAllMandatorySources;
var
  A: TMachineIdentity;
  Src: TMachineSource;
begin
  A := TMachineIdentityProvider.Collect;
Assert.AreEqual(Integer(MACHINE_IDENTITY_SCHEME_VERSION), A.SchemeVersion);
  Assert.IsTrue(Length(A.Sources) >= 2,
    'At least two decorrelated sources are mandatory');
  for Src in A.Sources do
  begin
    Assert.IsNotEmpty(Src.Name);
    Assert.IsNotEmpty(Src.Value,
      'Source "' + Src.Name + '" must fail closed instead of reporting an empty value');
  end;
end;

procedure TTestMachineIdentity.Test_Collect_ExcludesUserRenameableIdentity;
var
  A: TMachineIdentity;
  Src: TMachineSource;
  ComputerName: string;
begin
  A := TMachineIdentityProvider.Collect;
  ComputerName := GetEnvironmentVariable('COMPUTERNAME');
  for Src in A.Sources do
  begin
    Assert.IsFalse(Pos('computer', LowerCase(Src.Name)) > 0,
      'Computer name must never be a binding source');
    if ComputerName <> '' then
      Assert.AreNotEqual(ComputerName, Src.Value);
  end;
end;

procedure TTestMachineIdentity.Test_Provider_FingerprintAndBindingAgree;
var
  A: TMachineIdentity;
  LExpected, LBinding: TBytes;
begin
  A := TMachineIdentityProvider.Collect;
  Assert.AreEqual(A.ToHash, TMachineIdentityProvider.Fingerprint);
  Assert.IsTrue(Length(TMachineIdentityProvider.Fingerprint) = 64,
    'The fingerprint is a full SHA-256 hex digest');

  LExpected := A.ToBinding;
  LBinding := TMachineIdentityProvider.Binding;
  try
    Assert.AreEqual(Length(LExpected), Length(LBinding));
    Assert.IsTrue(CompareMem(@LExpected[0], @LBinding[0], Length(LExpected)));
  finally
    SetLength(LExpected, 0);
    SetLength(LBinding, 0);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestMachineIdentity);

end.
