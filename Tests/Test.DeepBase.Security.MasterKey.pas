{ ============================================================================
  Test.DeepBase.Security.MasterKey - Unit tests for the user master key store

  UBS2 v2 derives every sealed record from this single 32-byte file, so the net
  below covers both halves of its contract: the secret is only ever readable by
  its owner, and a backup is delivered byte-identical and owner-restricted or
  not delivered at all.

  DEEPBASE_MASTER_KEY_FILE points at a private temporary directory for the
  duration of every case, so the real per-user key file is never opened.

  Test Coverage:
    - Key path resolution: environment override and per-user default
    - Load: exact bytes, missing file, wrong size in both directions
    - LoadOrCreate: reuse of an existing secret, atomic provisioning
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
    function TempPath(const AName: string): string;
    function TestKey: TBytes;
    function BytesEqual(const ALeft, ARight: TBytes): Boolean;
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
{$IF DEFINED(MSWINDOWS)}
const
  // ACCESS_ALLOWED_ACE in the public ACE layout: a 4-byte header (type, flags,
  // size) followed by a 4-byte access mask, so the trustee SID starts at offset
  // 8. The RTL declares neither the record nor its type constant, and reading
  // the stored ACL through the documented layout is what keeps the owner-only
  // guarantee asserted independently of how the product builds it.
  ACE_TYPE_ACCESS_ALLOWED = 0;
  ACE_SID_OFFSET = 8;
  // TOKEN_USER is 8 bytes and the SID behind it is capped at 68 by the format,
  // so one buffer covering both is enough.
  TOKEN_USER_PROBE_SIZE = 256;
{$ENDIF}
var
  Dest: string;
  {$IF DEFINED(MSWINDOWS)}
  Token: THandle;
  TokenBuffer: array [0 .. TOKEN_USER_PROBE_SIZE - 1] of Byte;
  Required: Cardinal;
  UserSid: Pointer;
  SecurityDescriptor: PSECURITY_DESCRIPTOR;
  Dacl: PACL;
  DaclPresent, DaclDefaulted: BOOL;
  Ace: Pointer;
  ErrorCode: DWORD;
  {$ENDIF}
begin
  Dest := TempPath('owner-only.key');
  TUserMasterKey.ExportTo(Dest);
  Assert.IsTrue(TFile.Exists(Dest));

  {$IF DEFINED(MSWINDOWS)}
  // Asserted on the destination, after the rename: restricting the temporary
  // sibling alone would say nothing about the file the user ends up trusting.
  if not OpenProcessToken(GetCurrentProcess, TOKEN_READ, Token) then
    Assert.FailFmt('Test cannot read this process token (Win32 error %d).', [GetLastError]);
  try
    if not GetTokenInformation(Token, TokenUser, @TokenBuffer,
      SizeOf(TokenBuffer), Required) then
      Assert.FailFmt('Test cannot read the current user SID (Win32 error %d).', [GetLastError]);
    UserSid := PTokenUser(@TokenBuffer).User.Sid;

    SecurityDescriptor := nil;
    ErrorCode := GetNamedSecurityInfoW(PWideChar(Dest), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION, nil, nil, nil, nil, @SecurityDescriptor);
    Assert.AreEqual(DWORD(ERROR_SUCCESS), ErrorCode,
      'Test cannot read back the ACL of the exported backup.');
    try
      Assert.IsTrue(GetSecurityDescriptorDacl(SecurityDescriptor, DaclPresent, Dacl,
        DaclDefaulted), 'Test cannot inspect the ACL of the exported backup.');
      Assert.IsTrue(DaclPresent, 'The backup must carry an explicit DACL.');
      Assert.IsFalse(DaclDefaulted,
        'A defaulted DACL means the copy inherited its access from the directory.');
      Assert.IsTrue(Dacl <> nil, 'The backup reports a DACL but none was returned.');
      Assert.IsTrue(IsValidAcl(Dacl), 'The DACL of the backup is not a valid ACL.');
      Assert.AreEqual(Word(1), Dacl.AceCount,
        'The backup must be restricted to its owner; any further entry is someone ' +
        'else holding a readable copy.');
      Assert.IsTrue(GetAce(Dacl, 0, Ace), 'Test cannot read the single ACE.');
      Assert.AreEqual(Byte(ACE_TYPE_ACCESS_ALLOWED), PByte(Ace)^,
        'The one entry must be a grant, not a deny.');
      // A flags byte of zero rules out both inheritance and the object/callback
      // ACE variants, which is what makes the offset below land on a SID.
      Assert.AreEqual(Byte(0), PByte(NativeUInt(Ace) + 1)^,
        'The one entry must not be inherited from the parent folder.');
      Assert.IsTrue(IsValidSid(Pointer(NativeUInt(Ace) + ACE_SID_OFFSET)),
        'The one entry must name a valid SID.');
      Assert.IsTrue(EqualSid(Pointer(NativeUInt(Ace) + ACE_SID_OFFSET), UserSid),
        'The one entry must name the user this process runs as.');
    finally
      LocalFree(SecurityDescriptor);
    end;
  finally
    CloseHandle(Token);
  end;
  {$ENDIF}
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
