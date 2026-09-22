{ ============================================================================
  Test.DeepBase.Security.MasterKey - Unit tests for the user master key store

  UBS2 v2 derives every sealed record from this single 32-byte file, so the net
  below covers the three halves of its contract: a key this store creates is
  readable only by its owner unless that is declared away out loud, a backup is
  delivered byte-identical and owner-restricted or not delivered at all, and an
  operation that needs the user's existing secret refuses to mint a new one.

  DEEPBASE_MASTER_KEY_FILE points at a private temporary directory for the
  duration of every case, so the real per-user key file is never opened.

  Test Coverage:
    - Key path resolution: environment override and per-user default
    - KeyFileExists: answers without provisioning
    - Load: exact bytes, missing file, wrong size in both directions
    - LoadOrCreate: reuse of an existing secret, atomic provisioning, owner-only
      access on the file provisioning leaves behind, the declared exemption and
      what each branch announces
    - RequireExistingKey: refusal on an absent key, pass-through on a present one,
      and the caller's authorisation
    - ExportTo: byte-identical copy, owner-only destination, and every refusal
      (existing destination, missing directory, empty destination, leftover
      sibling, absent key)
    - FingerprintOf: known answer, determinism, sensitivity, missing file
  ============================================================================ }

unit Test.DeepBase.Security.MasterKey;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  DeepBase.Security.MasterKey,
  DeepBase.Security.UBS2;

type
  [TestFixture]
  TTestUserMasterKey = class
  private
    FDir: string;
    FKeyFile: string;
    FPriorEnv: string;
    FPriorAclEnv: string;
    FNotices: string;
    function TempPath(const AName: string): string;
    function TestKey: TBytes;
    function BytesEqual(const ALeft, ARight: TBytes): Boolean;
    function NoticeSink: TMasterKeyNotice;
    function AccessReport(const AFile, ARole: string;
      out OwnerOnly: Boolean): string;
    procedure AssertOwnerOnlyAccess(const AFile, ARole: string);
    procedure AssertAccessNotOwnerOnly(const AFile, ARole: string);
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_KeyFilePath_UsesEnvironmentOverride;
    [Test]
    procedure Test_KeyFilePath_DefaultsUnderUserHome;
    [Test]
    procedure Test_KeyFileExists_AnswersWithoutProvisioning;
    [Test]
    procedure Test_AccessManagedExternally_NeedsOverrideAndDeclaration;
    [Test]
    procedure Test_Load_ReturnsRawKeyBytes;
    [Test]
    procedure Test_Load_MissingFile_Raises;
    [Test]
    procedure Test_Load_TruncatedFile_Raises;
    [Test]
    procedure Test_Load_OversizedFile_Raises;
    [Test]
    procedure Test_LoadOrCreate_ReusesExistingKey;
    [Test]
    procedure Test_LoadOrCreate_ProvisionsAtomicKeyWhenAbsent;
    [Test]
    procedure Test_LoadOrCreate_ProvisionedFileIsOwnerOnly;
    [Test]
    procedure Test_LoadOrCreate_DeclaredExemptionLeavesFileUnrestricted;
    [Test]
    procedure Test_LoadOrCreate_NoticesOnlyWhatItProvisioned;
    [Test]
    procedure Test_RequireExistingKey_MissingKey_RaisesAndProvisionsNothing;
    [Test]
    procedure Test_RequireExistingKey_ExistingKey_Returns;
    [Test]
    procedure Test_RequireExistingKey_AuthorisedByUser_Returns;
    [Test]
    procedure Test_ExportTo_WritesByteIdenticalCopy;
    [Test]
    procedure Test_ExportTo_DestinationIsOwnerOnly;
    [Test]
    procedure Test_ExportTo_RefusesExistingDestination;
    [Test]
    procedure Test_ExportTo_RefusesMissingDirectory;
    [Test]
    procedure Test_ExportTo_RefusesEmptyDestination;
    [Test]
    procedure Test_ExportTo_RefusesLeftoverTempFile;
    [Test]
    procedure Test_ExportTo_MissingKey_RaisesAndProvisionsNothing;
    [Test]
    procedure Test_FingerprintOf_KnownAnswer;
    [Test]
    procedure Test_FingerprintOf_StableAndKeySensitive;
    [Test]
    procedure Test_FingerprintOf_MissingFile_Raises;
  end;

implementation

uses
  {$IF DEFINED(MSWINDOWS)}
  Winapi.Windows,
  Winapi.AccCtrl,
  Winapi.AclAPI,
  {$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
  Posix.SysStat,
  {$ENDIF}
  DeepBase.Exceptions;

const
  // The fixture secret is the raw byte sequence 0x00..0x1F -- a public test
  // vector, not secret material -- so its SHA-256 is a hardcoded known answer
  // that was produced outside this code base (node: crypto.createHash over the
  // same 32 bytes) rather than by the unit under test.
  FINGERPRINT_KNOWN_ANSWER =
    '630dcd2966c4336691125448bbb25b4ff412a49c732db2c8abc1b8581bd710dd';

  // Mirrors the private sibling suffix the store writes before renaming, which
  // is what a finished export must never leave behind.
  TMP_SUFFIX = '.tmp';

procedure TTestUserMasterKey.Setup;
begin
  FDir := TPath.Combine(TPath.GetTempPath, 'DeepBase.Security.MasterKey.Tests');
  if TDirectory.Exists(FDir) then
    TDirectory.Delete(FDir, True);
  TDirectory.CreateDirectory(FDir);

  FPriorEnv := GetEnvironmentVariable(MASTER_KEY_FILE_ENV);
  FKeyFile := TPath.Combine(FDir, MASTER_KEY_FILE_NAME);
  SetEnvironmentVariable(MASTER_KEY_FILE_ENV, PChar(FKeyFile));

  // The exemption is a declared, per-run fact; leaving it set by a previous case
  // would let the next one provision a readable key and still call it a pass.
  FPriorAclEnv := GetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV);
  SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, nil);
  FNotices := '';

  // Each case starts from a fixed, already-provisioned secret so the export and
  // fingerprint assertions are exact and no case depends on random first-run
  // material. Cases that want the provisioning path delete this file first.
  TFile.WriteAllBytes(FKeyFile, TestKey);
end;

procedure TTestUserMasterKey.TearDown;
begin
  if FPriorEnv = '' then
    SetEnvironmentVariable(MASTER_KEY_FILE_ENV, nil)
  else
    SetEnvironmentVariable(MASTER_KEY_FILE_ENV, PChar(FPriorEnv));
  if FPriorAclEnv = '' then
    SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, nil)
  else
    SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, PChar(FPriorAclEnv));
  if TDirectory.Exists(FDir) then
    TDirectory.Delete(FDir, True);
end;

function TTestUserMasterKey.TempPath(const AName: string): string;
begin
  Result := TPath.Combine(FDir, AName);
end;

function TTestUserMasterKey.TestKey: TBytes;
var
  I: Integer;
begin
  SetLength(Result, UBS2_MASTER_SECRET_MIN_SIZE);
  for I := 0 to High(Result) do
    Result[I] := Byte(I);
end;

function TTestUserMasterKey.BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(ALeft) = Length(ARight);
  if not Result then
    Exit;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

function TTestUserMasterKey.NoticeSink: TMasterKeyNotice;
begin
  Result :=
    procedure(const AMessage: string)
    begin
      FNotices := FNotices + AMessage + sLineBreak;
    end;
end;

{ What the file's access really is, and whether that amounts to "readable by its
  owner and nobody else". Read straight from the securable object -- the DACL on
  Windows, the mode bits on macOS and Linux -- rather than through anything the
  product exposes, so the guarantee is verified against the operating system's own
  answer. A file whose access cannot be read fails the case outright: an
  unreadable ACL is what a "not owner-only" assertion would otherwise mistake for
  success. }
function TTestUserMasterKey.AccessReport(const AFile, ARole: string;
  out OwnerOnly: Boolean): string;
{$IF DEFINED(MSWINDOWS)}
const
  // ACCESS_ALLOWED_ACE and ACCESS_DENIED_ACE in the public ACE layout: a 4-byte
  // header (type, flags, size) followed by a 4-byte access mask, so the trustee
  // SID starts at offset 8. The RTL declares neither the records nor their type
  // constants, and reading the stored ACL through the documented layout is what
  // keeps this independent of how the product builds it.
  ACE_TYPE_ACCESS_ALLOWED = 0;
  ACE_FLAGS_INHERITED = $10;  // INHERITED_ACE; icacls prints it as (I)
  ACE_SID_OFFSET = 8;
  // TOKEN_USER is 8 bytes and the SID behind it is capped at 68 by the format,
  // so one buffer covering both is enough.
  TOKEN_USER_PROBE_SIZE = 256;
var
  Token: THandle;
  TokenBuffer: array [0 .. TOKEN_USER_PROBE_SIZE - 1] of Byte;
  Required: Cardinal;
  UserSid: Pointer;
  SecurityDescriptor: PSECURITY_DESCRIPTOR;
  Dacl: PACL;
  DaclPresent, DaclDefaulted: BOOL;
  Ace: Pointer;
  I: Integer;
  Flags: Byte;
  Mask: DWORD;
  Kind: string;
  Trustee: string;
  TrusteeIsThisUser: Boolean;
{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  StatBuffer: _stat;
  Mode: Cardinal;
{$ENDIF}
begin
  OwnerOnly := False;
  {$IF DEFINED(MSWINDOWS)}
  if not OpenProcessToken(GetCurrentProcess, TOKEN_READ, Token) then
    Assert.FailFmt('Test cannot read this process token (Win32 error %d).', [GetLastError]);
  try
    if not GetTokenInformation(Token, TokenUser, @TokenBuffer,
      SizeOf(TokenBuffer), Required) then
      Assert.FailFmt('Test cannot read the current user SID (Win32 error %d).', [GetLastError]);
    UserSid := PTokenUser(@TokenBuffer).User.Sid;

    SecurityDescriptor := nil;
    Assert.AreEqual(DWORD(ERROR_SUCCESS),
      GetNamedSecurityInfoW(PWideChar(AFile), SE_FILE_OBJECT,
        DACL_SECURITY_INFORMATION, nil, nil, nil, nil, @SecurityDescriptor),
      'Test cannot read back the ACL of the ' + ARole + '.');
    try
      Assert.IsTrue(GetSecurityDescriptorDacl(SecurityDescriptor, DaclPresent, Dacl,
        DaclDefaulted), 'Test cannot inspect the ACL of the ' + ARole + '.');
      if not DaclPresent then
        Exit('the ' + ARole + ' has no explicit DACL, so its access comes from elsewhere');
      if DaclDefaulted then
        Exit('the ' + ARole + ' has a defaulted DACL inherited from its directory');
      if (Dacl = nil) or (not IsValidAcl(Dacl)) then
        Exit('the ' + ARole + ' reports a DACL that cannot be parsed');

      Result := Format('%d entries', [Dacl.AceCount]);
      for I := 0 to Dacl.AceCount - 1 do
      begin
        Assert.IsTrue(GetAce(Dacl, I, Ace),
          'Test cannot read ACE ' + I.ToString + ' of the ' + ARole + '.');
        Flags := PByte(NativeUInt(Ace) + 1)^;
        Mask := PDWORD(NativeUInt(Ace) + 4)^;
        TrusteeIsThisUser := EqualSid(Pointer(NativeUInt(Ace) + ACE_SID_OFFSET), UserSid);
        if PByte(Ace)^ = ACE_TYPE_ACCESS_ALLOWED then
          Kind := 'grant'
        else
          Kind := 'deny';
        if TrusteeIsThisUser then
          Trustee := 'this user'
        else
          Trustee := 'someone else';
        Result := Result + sLineBreak + Format('[%d] %s flags=$%.2X mask=$%.8X trustee=%s',
          [I, Kind, Flags, Mask, Trustee]);
      end;

      if Dacl.AceCount <> 1 then
        Exit(Result);
      OwnerOnly := (PByte(Ace)^ = ACE_TYPE_ACCESS_ALLOWED)
        and (Flags = 0)  // neither inherited nor an object/callback variant
        and TrusteeIsThisUser
        and IsValidSid(Pointer(NativeUInt(Ace) + ACE_SID_OFFSET));
    finally
      LocalFree(SecurityDescriptor);
    end;
  finally
    CloseHandle(Token);
  end;
  {$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
  if Posix.SysStat.stat(PAnsiChar(AnsiString(AFile)), StatBuffer) <> 0 then
    Assert.Fail('Test cannot read the mode of the ' + ARole + '.');
  Mode := StatBuffer.st_mode and $7777;
  Result := Format('mode 0%o', [Mode]);
  OwnerOnly := Mode = $180;  // 0600
  {$ELSE}
  Assert.Fail('This platform has no owner-only access assertion implemented for the ' + ARole + '.');
  {$ENDIF}
end;

procedure TTestUserMasterKey.AssertOwnerOnlyAccess(const AFile, ARole: string);
var
  OwnerOnly: Boolean;
  Report: string;
begin
  Report := AccessReport(AFile, ARole, OwnerOnly);
  Assert.IsTrue(OwnerOnly,
    'The ' + ARole + ' must be restricted to its owner; any further entry is ' +
    'someone else holding a readable copy. Actual access: ' + Report);
end;

procedure TTestUserMasterKey.AssertAccessNotOwnerOnly(const AFile, ARole: string);
var
  OwnerOnly: Boolean;
  Report: string;
begin
  Report := AccessReport(AFile, ARole, OwnerOnly);
  Assert.IsFalse(OwnerOnly,
    'The ' + ARole + ' must not carry the single owner entry, because this case ' +
    'declared that somebody else administers its access. Actual access: ' + Report);
end;

{ TTestUserMasterKey }

procedure TTestUserMasterKey.Test_KeyFilePath_UsesEnvironmentOverride;
begin
  Assert.AreEqual(FKeyFile, TUserMasterKey.KeyFilePath,
    'DEEPBASE_MASTER_KEY_FILE must be the whole answer when it is set; there is ' +
    'no second source and no fallback.');
end;

procedure TTestUserMasterKey.Test_KeyFilePath_DefaultsUnderUserHome;
var
  Path: string;
begin
  SetEnvironmentVariable(MASTER_KEY_FILE_ENV, nil);
  Path := TUserMasterKey.KeyFilePath;
  Assert.AreEqual(MASTER_KEY_FILE_NAME, TPath.GetFileName(Path),
    'Without the override the store resolves to its per-user default file name.');
  Assert.AreEqual(MASTER_KEY_DIR_NAME, TPath.GetFileName(TPath.GetDirectoryName(Path)),
    'The default file lives in the per-user .deepbase directory.');
  Assert.AreNotEqual(FKeyFile, Path,
    'The temporary fixture path must not leak into the default resolution.');
end;

procedure TTestUserMasterKey.Test_KeyFileExists_AnswersWithoutProvisioning;
begin
  Assert.IsTrue(TUserMasterKey.KeyFileExists,
    'A key that is already there must answer as existing.');
  TFile.Delete(FKeyFile);
  Assert.IsFalse(TUserMasterKey.KeyFileExists,
    'A user with no key yet must be able to ask without getting one.');
  Assert.IsFalse(TFile.Exists(FKeyFile),
    'KeyFileExists must never create the file it is only asked about.');
end;

procedure TTestUserMasterKey.Test_AccessManagedExternally_NeedsOverrideAndDeclaration;
begin
  Assert.IsFalse(TUserMasterKey.AccessManagedExternally,
    'No declaration means no exemption: provisioning must restrict the key.');
  SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, PChar('MAYBE'));
  Assert.IsFalse(TUserMasterKey.AccessManagedExternally,
    'A value other than the one accepted token is not a declaration. A mis-typed ' +
    'exemption has to restrict the key, not open it.');
  SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, PChar(MASTER_KEY_EXTERNAL_ACL_YES));
  Assert.IsTrue(TUserMasterKey.AccessManagedExternally,
    'The accepted declaration on an override path is what exempts the owner-only ' +
    'restriction.');

  // The per-user default sits inside the user's own profile, where "somebody else
  // administers this path" is never a claim worth accepting, so the declaration is
  // honoured for an override only.
  SetEnvironmentVariable(MASTER_KEY_FILE_ENV, nil);
  Assert.IsFalse(TUserMasterKey.AccessManagedExternally,
    'The default per-user key path can never be declared away.');
end;

procedure TTestUserMasterKey.Test_Load_ReturnsRawKeyBytes;
var
  Loaded: TBytes;
begin
  Loaded := TUserMasterKey.Load(FKeyFile);
  Assert.AreEqual<Integer>(UBS2_MASTER_SECRET_MIN_SIZE, Length(Loaded),
    'Load returns exactly the raw key length the store accepts.');
  Assert.IsTrue(BytesEqual(TestKey, Loaded),
    'Load must hand back the file bytes unchanged; any encoding step in between ' +
    'would silently change the derived key.');
end;

procedure TTestUserMasterKey.Test_Load_MissingFile_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.Load(TempPath('absent.key'));
    end, ESecurityException);
end;

procedure TTestUserMasterKey.Test_Load_TruncatedFile_Raises;
var
  Truncated: TBytes;
begin
  Truncated := Copy(TestKey, 0, UBS2_MASTER_SECRET_MIN_SIZE - 1);
  TFile.WriteAllBytes(TempPath('short.key'), Truncated);
  // The reported size is part of the contract: it is what tells a user that the
  // file was truncated rather than emptied, and the buffer is wiped before the
  // message is built, so a message that says "found 0" is a bug, not a detail.
  Assert.WillRaiseWithMessageRegex(
    procedure
    begin
      TUserMasterKey.Load(TempPath('short.key'));
    end, ESecurityException, 'found 31');
end;

procedure TTestUserMasterKey.Test_Load_OversizedFile_Raises;
var
  Oversized: TBytes;
begin
  // Size is checked for equality, not a floor: a longer file is a different
  // format or a corrupted record, and deriving from a prefix of it would let a
  // trailing-edit attack pass unnoticed.
  Oversized := Copy(TestKey);
  SetLength(Oversized, UBS2_MASTER_SECRET_MIN_SIZE + 1);
  Oversized[UBS2_MASTER_SECRET_MIN_SIZE] := $FF;
  TFile.WriteAllBytes(TempPath('long.key'), Oversized);
  Assert.WillRaiseWithMessageRegex(
    procedure
    begin
      TUserMasterKey.Load(TempPath('long.key'));
    end, ESecurityException, 'found 33');
end;

procedure TTestUserMasterKey.Test_LoadOrCreate_ReusesExistingKey;
var
  Loaded: TBytes;
begin
  Loaded := TUserMasterKey.LoadOrCreate;
  Assert.IsTrue(BytesEqual(TestKey, Loaded),
    'LoadOrCreate must return the secret that already seals this user''s data.');
  Assert.IsTrue(BytesEqual(TestKey, TFile.ReadAllBytes(FKeyFile)),
    'An existing key file must not be rewritten.');
end;

procedure TTestUserMasterKey.Test_LoadOrCreate_ProvisionsAtomicKeyWhenAbsent;
var
  First, Second: TBytes;
begin
  TFile.Delete(FKeyFile);
  First := TUserMasterKey.LoadOrCreate;
  Assert.AreEqual<Integer>(UBS2_MASTER_SECRET_MIN_SIZE, Length(First),
    'A provisioned secret has the length UBS2 requires.');
  Assert.IsTrue(TFile.Exists(FKeyFile),
    'Provisioning must leave the file at the name the next run trusts.');
  Assert.IsFalse(TFile.Exists(FKeyFile + TMP_SUFFIX),
    'Provisioning writes a sibling and renames; a leftover sibling means the ' +
    'rename never happened.');
  Second := TUserMasterKey.LoadOrCreate;
  Assert.IsTrue(BytesEqual(First, Second),
    'The second run must read the secret the first one created.');
end;

procedure TTestUserMasterKey.Test_LoadOrCreate_ProvisionedFileIsOwnerOnly;
begin
  // Provisioning is the face that mints the only entropy source in the product,
  // so it must land behind the same single-entry DACL as a backup does: an
  // inherited ACL on the live key leaves the whole secret set readable by
  // whoever the parent folder happens to grant.
  TFile.Delete(FKeyFile);
  TUserMasterKey.LoadOrCreate;
  AssertOwnerOnlyAccess(FKeyFile, 'provisioned master key');
end;

procedure TTestUserMasterKey.Test_LoadOrCreate_DeclaredExemptionLeavesFileUnrestricted;
begin
  // A key path somebody else administers is the one case where writing a
  // single-entry DACL would fight the operator's own policy. The exemption is
  // declarative and must be visible: no declaration, no exemption.
  TFile.Delete(FKeyFile);
  SetEnvironmentVariable(MASTER_KEY_EXTERNAL_ACL_ENV, PChar(MASTER_KEY_EXTERNAL_ACL_YES));
  Assert.AreEqual<Integer>(UBS2_MASTER_SECRET_MIN_SIZE,
    Length(TUserMasterKey.LoadOrCreate(NoticeSink())));
  Assert.IsTrue(TFile.Exists(FKeyFile),
    'The exemption covers how access is set, not whether the key is created.');
  AssertAccessNotOwnerOnly(FKeyFile, 'exempted master key');
  Assert.Contains(FNotices, MASTER_KEY_EXTERNAL_ACL_ENV,
    'An exemption that quietly skipped the owner-only restriction is the silent ' +
    'failure this ticket exists to remove: the announcement has to name the ' +
    'declaration it honoured.');
  Assert.IsFalse(FNotices.Contains('restricted to its owner.'),
    'The announcement must not claim a restriction the file does not carry.');
end;

procedure TTestUserMasterKey.Test_LoadOrCreate_NoticesOnlyWhatItProvisioned;
begin
  TUserMasterKey.LoadOrCreate(NoticeSink());
  Assert.AreEqual('', FNotices,
    'Reading the secret that already seals this user''s data is not an event worth ' +
    'announcing; noise here would train the user to ignore the one that matters.');

  FNotices := '';
  TFile.Delete(FKeyFile);
  TUserMasterKey.LoadOrCreate;  // a caller with nowhere to announce must still work
  Assert.AreEqual('', FNotices, 'The sink is optional, not a precondition.');

  FNotices := '';
  TFile.Delete(FKeyFile);
  TUserMasterKey.LoadOrCreate(NoticeSink());
  Assert.IsTrue(TFile.Exists(FKeyFile));
  Assert.Contains(FNotices, 'provisioned',
    'A key this call creates has to be announced, because the user who never sees ' +
    'it is the user whose later backups match nothing.');
  Assert.Contains(FNotices, 'restricted to its owner',
    'The announcement has to state what happened to access on the file it just made.');
end;

procedure TTestUserMasterKey.Test_RequireExistingKey_MissingKey_RaisesAndProvisionsNothing;
begin
  // The migration path is the caller this gate exists for: minting a key there
  // would seal the records it just rewrote against a secret no earlier backup
  // holds, and still report success.
  TFile.Delete(FKeyFile);
  Assert.WillRaiseWithMessageRegex(
    procedure
    begin
      TUserMasterKey.RequireExistingKey('a test operation', False);
    end, ESecurityException, 'Refusing to provision');
  Assert.IsFalse(TFile.Exists(FKeyFile),
    'Refusing means refusing: no key file may survive the refusal.');
  Assert.IsFalse(TFile.Exists(FKeyFile + TMP_SUFFIX),
    'A refusal must not leave a half-written sibling behind either.');
end;

procedure TTestUserMasterKey.Test_RequireExistingKey_ExistingKey_Returns;
begin
  TUserMasterKey.RequireExistingKey('a test operation', False);
  Assert.IsTrue(TFile.Exists(FKeyFile));
  Assert.IsTrue(BytesEqual(TestKey, TFile.ReadAllBytes(FKeyFile)),
    'An existing key must be left exactly as the records that seal against it ' +
    'expect it.');
end;

procedure TTestUserMasterKey.Test_RequireExistingKey_AuthorisedByUser_Returns;
begin
  // The gate is a default, not a wall: the caller passes True only when the user
  // authorised a new secret in this run, and authorising still creates nothing.
  TFile.Delete(FKeyFile);
  TUserMasterKey.RequireExistingKey('a test operation', True);
  Assert.IsFalse(TFile.Exists(FKeyFile),
    'Authorising a new key is the caller''s record of consent, not a reason to ' +
    'provision one here.');
end;

procedure TTestUserMasterKey.Test_ExportTo_WritesByteIdenticalCopy;
var
  Dest: string;
begin
  Dest := TempPath('backup.key');
  TUserMasterKey.ExportTo(Dest);
  Assert.IsTrue(TFile.Exists(Dest), 'The export must deliver the destination file.');
  Assert.IsTrue(BytesEqual(TestKey, TFile.ReadAllBytes(Dest)),
    'The backup must be byte-identical to the master secret.');
  Assert.AreEqual(TUserMasterKey.FingerprintOf(FKeyFile),
    TUserMasterKey.FingerprintOf(Dest),
    'A backup that does not carry the same fingerprint is not a backup.');
  Assert.IsFalse(TFile.Exists(Dest + TMP_SUFFIX),
    'A finished export leaves no unfinished sibling holding key material.');
end;

procedure TTestUserMasterKey.Test_ExportTo_DestinationIsOwnerOnly;
var
  Dest: string;
begin
  Dest := TempPath('owner-only.key');
  TUserMasterKey.ExportTo(Dest);
  Assert.IsTrue(TFile.Exists(Dest));

  // Asserted on the destination, after the rename: restricting the temporary
  // sibling alone would say nothing about the file the user ends up trusting.
  AssertOwnerOnlyAccess(Dest, 'exported backup');
end;

procedure TTestUserMasterKey.Test_ExportTo_RefusesExistingDestination;
var
  Dest: string;
  Sentinel: TBytes;
begin
  Dest := TempPath('backup.key');
  Sentinel := TEncoding.UTF8.GetBytes('an older backup that must survive');
  TFile.WriteAllBytes(Dest, Sentinel);

  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.ExportTo(Dest);
    end, ESecurityException);

  Assert.IsTrue(BytesEqual(Sentinel, TFile.ReadAllBytes(Dest)),
    'Refusing an existing destination means refusing it without touching it.');
end;

procedure TTestUserMasterKey.Test_ExportTo_RefusesMissingDirectory;
begin
  // The destination file must not exist, but its directory must not either:
  // the store refuses to guess where a copy of the master secret should go.
  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.ExportTo(
        TPath.Combine(TPath.Combine(FDir, 'no-such-dir'), 'backup.key'));
    end, ESecurityException);
end;

procedure TTestUserMasterKey.Test_ExportTo_RefusesEmptyDestination;
begin
  // Whitespace only, so the assertion also covers the trim in front of the check.
  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.ExportTo('   ');
    end, ESecurityException);
end;

procedure TTestUserMasterKey.Test_ExportTo_RefusesLeftoverTempFile;
var
  Dest: string;
begin
  Dest := TempPath('backup.key');
  TFile.WriteAllText(Dest + TMP_SUFFIX, 'leftover from an unfinished export');

  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.ExportTo(Dest);
    end, ESecurityException);

  // The leftover is deliberately kept: it may hold key material, and deleting a
  // file nobody created through this command is not ours to decide.
  Assert.IsTrue(TFile.Exists(Dest + TMP_SUFFIX),
    'A leftover export sibling must be reported, not silently removed.');
  Assert.IsFalse(TFile.Exists(Dest));
end;

procedure TTestUserMasterKey.Test_ExportTo_MissingKey_RaisesAndProvisionsNothing;
var
  Dest: string;
begin
  // Exporting is not a reason to mint a new secret: a fresh key seals nothing
  // and would hand the user a backup with the authority of the real one.
  TFile.Delete(FKeyFile);
  Dest := TempPath('never.key');

  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.ExportTo(Dest);
    end, ESecurityException);

  Assert.IsFalse(TFile.Exists(FKeyFile),
    'Export must not provision a master key as a side effect.');
  Assert.IsFalse(TFile.Exists(Dest));
end;

procedure TTestUserMasterKey.Test_FingerprintOf_KnownAnswer;
begin
  Assert.AreEqual(FINGERPRINT_KNOWN_ANSWER, TUserMasterKey.FingerprintOf(FKeyFile),
    'The fingerprint must be the lowercase SHA-256 of the raw key bytes.');
end;

procedure TTestUserMasterKey.Test_FingerprintOf_StableAndKeySensitive;
var
  Altered: TBytes;
  AlteredFile: string;
begin
  Assert.AreEqual(TUserMasterKey.FingerprintOf(FKeyFile),
    TUserMasterKey.FingerprintOf(FKeyFile),
    'Re-reading a backup must always produce the same fingerprint.');

  AlteredFile := TempPath('other.key');
  Altered := Copy(TestKey);
  Altered[0] := Altered[0] xor $01;
  TFile.WriteAllBytes(AlteredFile, Altered);
  Assert.AreNotEqual(FINGERPRINT_KNOWN_ANSWER, TUserMasterKey.FingerprintOf(AlteredFile),
    'A one-bit difference in the secret must be visible in the fingerprint, or ' +
    'reconciling a backup against the live key is meaningless.');
end;

procedure TTestUserMasterKey.Test_FingerprintOf_MissingFile_Raises;
begin
  // The same gate as Load: an absent or malformed file has no fingerprint, and
  // reporting one for it would let a broken backup look like a valid one.
  Assert.WillRaise(
    procedure
    begin
      TUserMasterKey.FingerprintOf(TempPath('absent.key'));
    end, ESecurityException);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUserMasterKey);

end.
