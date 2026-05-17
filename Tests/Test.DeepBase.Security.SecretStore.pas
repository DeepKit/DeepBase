{ ============================================================================
  Test.DeepBase.Security.SecretStore - Unit tests for cross-platform
  secret store abstraction.

  Coverage:
    - Windows Credential Manager round-trip (Put then TryGet)
    - Delete removes the entry (TryGet returns False after Delete)
    - IsAvailable reports true on a usable backend
    - Dev-mode opt-in via DEEPBASE_INSECURE_DEV_MODE
    - Fail-closed contract on platforms with no backend (smoke check via
      ESecretStoreUnavailable type visibility)
  ============================================================================ }

unit Test.DeepBase.Security.SecretStore;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Security.SecretStore;

type
  [TestFixture]
  TSecretStoreTests = class
  strict private
    function MakeUniqueKey(const APrefix: string): string;
    procedure SafeDelete(const AStore: ISecretStore; const AKey: string);
  public
    [Test]
    procedure Test_PlatformStore_IsAvailable;

    [Test]
    procedure Test_PutThenTryGet_RoundTrip;

    [Test]
    procedure Test_TryGet_MissingKey_ReturnsFalse;

    [Test]
    procedure Test_Delete_Removes_Entry;

    [Test]
    procedure Test_Put_Overwrites_ExistingValue;

    [Test]
    procedure Test_ESecretStoreUnavailable_TypeVisible;
  end;

implementation

{ TSecretStoreTests }

function TSecretStoreTests.MakeUniqueKey(const APrefix: string): string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := APrefix + GUIDToString(LGuid).Trim(['{', '}']).ToLower;
end;

procedure TSecretStoreTests.SafeDelete(const AStore: ISecretStore;
  const AKey: string);
begin
  try
    AStore.Delete(AKey);
  except
    // Best-effort cleanup; tests must not fail because of teardown errors.
  end;
end;

procedure TSecretStoreTests.Test_PlatformStore_IsAvailable;
var
  LStore: ISecretStore;
begin
{$IF DEFINED(MSWINDOWS)}
  LStore := TSecretStoreFactory.CreatePlatformStore;
  Assert.IsNotNull(LStore, 'CreatePlatformStore returned nil on Windows');
  Assert.IsTrue(LStore.IsAvailable,
    'Windows secret store should report IsAvailable=True');
{$ELSE}
  // Non-Windows fail-closed: factory raises unless dev-mode env var is set.
  // Just verify the contract by toggling the dev-mode env var.
  var LPrevValue := GetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE');
  try
    SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', '1');
    LStore := TSecretStoreFactory.CreatePlatformStore;
    Assert.IsNotNull(LStore, 'Dev-mode factory returned nil');
    Assert.IsTrue(LStore.IsAvailable,
      'Dev-mode store should report IsAvailable=True');
  finally
    if LPrevValue = '' then
      SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', nil)
    else
      SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', PChar(LPrevValue));
  end;
{$ENDIF}
end;

procedure TSecretStoreTests.Test_PutThenTryGet_RoundTrip;
var
  LStore: ISecretStore;
  LKey, LValue, LRead: string;
begin
{$IF NOT DEFINED(MSWINDOWS)}
  SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', '1');
{$ENDIF}
  LStore := TSecretStoreFactory.CreatePlatformStore;
  LKey := MakeUniqueKey('deepbase.test.roundtrip.');
  LValue := 'secret-' + FormatDateTime('yyyymmddhhnnsszzz', Now);
  try
    LStore.Put(LKey, LValue);
    Assert.IsTrue(LStore.TryGet(LKey, LRead),
      'TryGet should succeed after Put');
    Assert.AreEqual(LValue, LRead, 'Round-trip value must match');
  finally
    SafeDelete(LStore, LKey);
  end;
end;

procedure TSecretStoreTests.Test_TryGet_MissingKey_ReturnsFalse;
var
  LStore: ISecretStore;
  LKey, LRead: string;
begin
{$IF NOT DEFINED(MSWINDOWS)}
  SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', '1');
{$ENDIF}
  LStore := TSecretStoreFactory.CreatePlatformStore;
  LKey := MakeUniqueKey('deepbase.test.missing.');
  // Make sure no stale value lingers from a previous failed run.
  SafeDelete(LStore, LKey);

  LRead := 'sentinel';
  Assert.IsFalse(LStore.TryGet(LKey, LRead),
    'TryGet on a non-existent key must return False');
end;

procedure TSecretStoreTests.Test_Delete_Removes_Entry;
var
  LStore: ISecretStore;
  LKey, LValue, LRead: string;
begin
{$IF NOT DEFINED(MSWINDOWS)}
  SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', '1');
{$ENDIF}
  LStore := TSecretStoreFactory.CreatePlatformStore;
  LKey := MakeUniqueKey('deepbase.test.delete.');
  LValue := 'to-be-deleted';
  try
    LStore.Put(LKey, LValue);
    LStore.Delete(LKey);
    Assert.IsFalse(LStore.TryGet(LKey, LRead),
      'TryGet must return False after Delete');
  finally
    SafeDelete(LStore, LKey);
  end;
end;

procedure TSecretStoreTests.Test_Put_Overwrites_ExistingValue;
var
  LStore: ISecretStore;
  LKey, LRead: string;
begin
{$IF NOT DEFINED(MSWINDOWS)}
  SetEnvironmentVariable('DEEPBASE_INSECURE_DEV_MODE', '1');
{$ENDIF}
  LStore := TSecretStoreFactory.CreatePlatformStore;
  LKey := MakeUniqueKey('deepbase.test.overwrite.');
  try
    LStore.Put(LKey, 'first');
    LStore.Put(LKey, 'second');
    Assert.IsTrue(LStore.TryGet(LKey, LRead),
      'TryGet should succeed after re-Put');
    Assert.AreEqual('second', LRead,
      'Put must overwrite a previously-stored value');
  finally
    SafeDelete(LStore, LKey);
  end;
end;

procedure TSecretStoreTests.Test_ESecretStoreUnavailable_TypeVisible;
begin
  // Lightweight contract check: the public exception class must remain
  // exported so callers can trap fail-closed conditions on platforms
  // without a backend.
  Assert.IsTrue(ESecretStoreUnavailable.InheritsFrom(Exception),
    'ESecretStoreUnavailable must inherit from Exception');
end;

initialization
  TDUnitX.RegisterTestFixture(TSecretStoreTests);

end.
