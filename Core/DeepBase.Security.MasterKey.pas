unit DeepBase.Security.MasterKey;

{*******************************************************************************
  DeepBase Security MasterKey - SSOT for the user secret behind UBS2.

  UBS2 v2 derives its key from this secret alone (see DeepBase.Security.UBS2);
  machine identity travels through the AAD. That split is what makes "same
  machine, different user" decryption impossible: the secret lives in the user's
  own home directory (mode 0700 / 0600 on macOS and Linux, and on Windows inside a
  profile directory that is itself per-user), while the binding value is readable
  by anyone on the box.

  Resolution order (there is no third source and no fallback):
    1. DEEPBASE_MASTER_KEY_FILE  - path to a file holding exactly 32 raw bytes.
       Replaces the removed DEEPBASE_MASTER_KEY variable, which used to carry the
       key material itself into the process environment block where it stayed
       readable through /proc/<pid>/environ and through child processes.
    2. <home>/.deepbase/master.key - created on first run, 0600, 32 random bytes.

  Deleting the key file is indistinguishable from a first run: a new secret is
  created and previously sealed records stop authenticating. That is the intended
  fail-closed behaviour, not a bug to work around.

  The returned bytes are live key material: the caller must hand them to
  SecureClearBytes as soon as the derived key is no longer needed.

  Backing the secret up is the only recovery path a user has, so this unit owns
  that too: ExportTo writes a copy, restricts it to its owner (chmod 0600 on
  POSIX, a single-entry protected current-user DACL on Windows), reads it back and
  compares length and SHA-256 against the source, and re-asserts the owner-only
  restriction once the copy carries the destination name. Exporting onto a
  destination that already exists is refused rather than silently overwritten --
  a backup that replaced an older one without a word is not a backup.

  Author: DeepBase Team
  Created: 2026-09-20
*******************************************************************************}

interface

uses
  System.SysUtils;

type
  /// <summary>Per-user secret store used as the only password entropy of UBS2.</summary>
  TUserMasterKey = class
  public
    /// <summary>Env override when set, otherwise the per-user default path.</summary>
    class function KeyFilePath: string; static;
    /// <summary>Read the secret, creating it on first run.</summary>
    class function LoadOrCreate: TBytes; static;
    /// <summary>Read a specific key file. Raises when it is missing or not exactly
    /// UBS2_MASTER_SECRET_MIN_SIZE raw bytes.</summary>
    class function Load(const AKeyFile: string): TBytes; static;
    /// <summary>Copy the key file this process actually uses to ADestFile as a
    /// recoverable backup. The source is never a parameter: the only thing that
    /// may be exported is the secret that currently seals this user's data.
    /// Raises when the destination already exists, when its directory is missing,
    /// when it cannot be restricted to its owner, or when the read-back copy does
    /// not match the source by length and SHA-256.</summary>
    class procedure ExportTo(const ADestFile: string); static;
    /// <summary>SHA-256 of a key file's raw bytes, lowercase hex. One-way, so it
    /// identifies a backup without revealing the secret; raises on an unusable
    /// file for the same reasons as Load.</summary>
    class function FingerprintOf(const AKeyFile: string): string; static;
  end;

const
  MASTER_KEY_FILE_ENV = 'DEEPBASE_MASTER_KEY_FILE';
  MASTER_KEY_DIR_NAME = '.deepbase';
  MASTER_KEY_FILE_NAME = 'master.key';

implementation

uses
  System.IOUtils,
  {$IF DEFINED(MSWINDOWS)}
  Winapi.Windows,
  Winapi.AccCtrl,
  Winapi.AclAPI,
  {$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
  Posix.SysStat,
  {$ENDIF}
  DeepBase.Exceptions,
  DeepBase.Crypto.Hash,
  DeepBase.Crypto.Random,
  DeepBase.SecureMemory,
  DeepBase.Security.UBS2;

const
  // Provisioning and export both write a sibling first and rename, so a partial
  // file never takes the name the next run trusts.
  TMP_FILE_SUFFIX = '.tmp';

  {$IF DEFINED(MSWINDOWS)}
  // TOKEN_USER is 8 bytes and the SID it points at is capped at 68 by the format,
  // so one stack buffer that covers both is enough; anything else that could go
  // wrong is reported by the API rather than grown into.
  TOKEN_USER_PROBE_SIZE = 256;

  // The RTL declares the generic rights but not the concrete file rights, and the
  // concrete form is the one that has to be used here (see ApplyCurrentUserOnlyDacl).
  // STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or all specific file rights -- which is
  // also exactly what GENERIC_ALL expands to for a file object.
  FILE_ALL_ACCESS = $001F01FF;

  // WinBase.h. Not declared by the RTL, and without it SetNamedSecurityInfo merges
  // the parent folder's inheritable grant ACEs back into the stored DACL.
  PROTECTED_DACL_SECURITY_INFORMATION = $80000000;
  {$ENDIF}

{$IF DEFINED(MSWINDOWS)}
{ Returns the SID of the user this process runs as, as an exact-size byte copy.
  TOKEN_QUERY only: the master secret must never depend on an elevated or
  impersonated identity, and reading one's own token is the least privilege that
  answers "who may hold this copy".
  The SID is copied rather than returned as a PSID because TOKEN_USER stores it
  behind its header, so any buffer that holds it is either a local -- and then a
  returned PSID would dangle the moment this function exits -- or an allocation
  every caller would have to remember to release. }
function CurrentProcessUserSid: TBytes;
var
  Token: THandle;
  Buffer: array [0 .. TOKEN_USER_PROBE_SIZE - 1] of Byte;
  Info: PTokenUser;
  Required: Cardinal;
  SidLength: Cardinal;
begin
  if not OpenProcessToken(GetCurrentProcess, TOKEN_READ, Token) then
    raise ESecurityException.CreateFmt(
      'Cannot open this process'' token to determine its owner (Win32 error %d). ' +
      'The master key must not be exported to a file nobody owns.',
      [GetLastError]);
  try
    Required := 0;
    if not GetTokenInformation(Token, TokenUser, @Buffer, SizeOf(Buffer), Required) then
      raise ESecurityException.CreateFmt(
        'Cannot read the user SID of this process (Win32 error %d).', [GetLastError]);
    Info := PTokenUser(@Buffer);
    SidLength := GetLengthSid(Info.User.Sid);
    if SidLength = 0 then
      raise ESecurityException.Create(
        'The user SID of this process has no length; a master key copy cannot be ' +
        'restricted to it.');
    SetLength(Result, SidLength);
    if not CopySid(SidLength, @Result[0], Info.User.Sid) then
      raise ESecurityException.CreateFmt(
        'Cannot copy the user SID of this process (Win32 error %d).', [GetLastError]);
  finally
    CloseHandle(Token);
  end;
end;

{ Replaces the DACL of AFile with exactly one grant entry for the current user.
  A caller-provided path is outside the per-user profile directory, so it inherits
  no protection worth trusting; and unlike the POSIX chmod, a Windows ACL has to be
  read back to know it took effect. The read-back is therefore part of the contract:
  a volume without ACL support, or a destination whose DACL cannot be replaced,
  fails closed here instead of leaving an open copy of the secret behind.

  Two details of the Win32 security model decide the shape of this call, both
  measured rather than assumed:
    * The DACL is set as PROTECTED. A plain set leaves the parent folder's
      inheritable grant ACEs in the stored DACL next to the new entry, so the copy
      would stay readable by everyone on the machine -- the opposite of the point.
    * The entry carries FILE_ALL_ACCESS instead of GENERIC_ALL. The system expands
      generic rights into the object type's concrete ones when it stores the ACE,
      so a generic entry can never read back byte-for-byte as written; stating the
      file rights directly makes the comparison below an exact check of what the
      volume actually granted. }
procedure ApplyCurrentUserOnlyDacl(const AFile: string);
var
  Sid: TBytes;
  Entry: EXPLICIT_ACCESS_W;
  WrittenAcl, StoredAcl: PACL;
  SecurityDescriptor: PSECURITY_DESCRIPTOR;
  ErrorCode: DWORD;
  DaclPresent, DaclDefaulted: BOOL;
begin
  Sid := CurrentProcessUserSid;
  FillChar(Entry, SizeOf(Entry), 0);
  Entry.grfAccessPermissions := FILE_ALL_ACCESS;
  Entry.grfAccessMode := GRANT_ACCESS;
  Entry.grfInheritance := NO_INHERITANCE;
  Entry.Trustee.MultipleTrusteeOperation := NO_MULTIPLE_TRUSTEE;
  Entry.Trustee.TrusteeForm := TRUSTEE_IS_SID;
  Entry.Trustee.TrusteeType := TRUSTEE_IS_USER;
  Entry.Trustee.ptstrName := LPWSTR(@Sid[0]);

  WrittenAcl := nil;
  SecurityDescriptor := nil;
  try
    ErrorCode := SetEntriesInAclW(1, @Entry, nil, WrittenAcl);
    if ErrorCode <> ERROR_SUCCESS then
      raise ESecurityException.CreateFmt(
        'Cannot build an owner-only ACL for "%s" (%s).', [AFile, SysErrorMessage(ErrorCode)]);

    ErrorCode := SetNamedSecurityInfoW(PWideChar(AFile), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION or PROTECTED_DACL_SECURITY_INFORMATION,
      nil, nil, WrittenAcl, nil);
    if ErrorCode <> ERROR_SUCCESS then
      raise ESecurityException.CreateFmt(
        'Cannot restrict "%s" to its owner (%s). The destination volume must ' +
        'support NTFS ACLs; a master key copy that anyone on the machine can read ' +
        'is not a backup.', [AFile, SysErrorMessage(ErrorCode)]);
    ErrorCode := GetNamedSecurityInfoW(PWideChar(AFile), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION, nil, nil, nil, nil, @SecurityDescriptor);
    if ErrorCode <> ERROR_SUCCESS then
      raise ESecurityException.CreateFmt(
        'Cannot read back the ACL of "%s" to confirm it is owner-only (%s).',
        [AFile, SysErrorMessage(ErrorCode)]);
    if not GetSecurityDescriptorDacl(SecurityDescriptor, DaclPresent, StoredAcl,
      DaclDefaulted) then
      raise ESecurityException.CreateFmt(
        'Cannot inspect the ACL of "%s" (%s).', [AFile, SysErrorMessage(GetLastError)]);
    if (not DaclPresent) or DaclDefaulted or (StoredAcl = nil) or
      (not IsValidAcl(StoredAcl)) or (StoredAcl.AceCount <> 1) or
      (StoredAcl.AclSize <> WrittenAcl.AclSize) or
      (not CompareMem(WrittenAcl, StoredAcl, WrittenAcl.AclSize)) then
      raise ESecurityException.CreateFmt(
        'The ACL of "%s" is not the single owner entry that was written to it. ' +
        'The copy was refused because its readability cannot be proven.', [AFile]);
  finally
    LocalFree(WrittenAcl);
    LocalFree(SecurityDescriptor);
  end;
end;
{$ENDIF}

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
const
  // S_IRUSR or S_IWUSR are not exported by Posix.SysStat; use the octal literals.
  OWNER_ONLY_FILE_MODE = $180;  // 0600
  OWNER_ONLY_DIR_MODE = $1C0;   // 0700

procedure ApplyOwnerOnlyMode(const APath: string; AIsDirectory: Boolean);
var
  LMode: Cardinal;
begin
  if AIsDirectory then
    LMode := OWNER_ONLY_DIR_MODE
  else
    LMode := OWNER_ONLY_FILE_MODE;
  if Posix.SysStat.chmod(PAnsiChar(AnsiString(APath)), LMode) <> 0 then
    raise ESecurityException.CreateFmt(
      'Cannot restrict %s to its owner (chmod 0%o failed). The master secret must not ' +
      'be stored world-readable.', [APath, LMode]);
end;
{$ENDIF}

{ Restrict a file to its owner and prove the restriction took effect. Provisioning is
  deliberately not routed through here: the key file may sit at a shared
  DEEPBASE_MASTER_KEY_FILE path whose access is managed outside this program, while
  an export destination is always a path somebody just chose for a copy. }
procedure ApplyOwnerOnlyToFile(const APath: string);
begin
  {$IF DEFINED(MSWINDOWS)}
  ApplyCurrentUserOnlyDacl(APath);
  {$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
  ApplyOwnerOnlyMode(APath, False);
  {$ELSE}
  raise ESecurityException.Create(
    'This target has no way to restrict a file to its owner, so a copy of the master ' +
    'key must not be written on it: ' + APath);
  {$ENDIF}
end;

class function TUserMasterKey.KeyFilePath: string;
var
  Override: string;
begin
  Override := Trim(GetEnvironmentVariable(MASTER_KEY_FILE_ENV));
  if Override <> '' then
    Exit(Override);
  Result := TPath.Combine(TPath.Combine(TPath.GetHomePath, MASTER_KEY_DIR_NAME),
    MASTER_KEY_FILE_NAME);
end;

class function TUserMasterKey.Load(const AKeyFile: string): TBytes;
begin
  if not TFile.Exists(AKeyFile) then
    raise ESecurityException.CreateFmt(
      'Master key file "%s" does not exist. Data sealed with it stays unreadable ' +
      'unless the file is restored from the user''s own backup.', [AKeyFile]);

  Result := TFile.ReadAllBytes(AKeyFile);
  if Length(Result) <> UBS2_MASTER_SECRET_MIN_SIZE then
  begin
    SecureClearBytes(Result);
    raise ESecurityException.CreateFmt(
      'Master key file "%s" must hold exactly %d raw bytes, found %d.',
      [AKeyFile, UBS2_MASTER_SECRET_MIN_SIZE, Length(Result)]);
  end;
end;

class function TUserMasterKey.LoadOrCreate: TBytes;
var
  Path, TmpPath: string;
  Dir: string;
  Secret: TBytes;
begin
  Path := KeyFilePath;
  if TFile.Exists(Path) then
    Exit(Load(Path));

  Dir := TPath.GetDirectoryName(Path);
  TDirectory.CreateDirectory(Dir);
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  ApplyOwnerOnlyMode(Dir, True);
  {$ENDIF}

  // Write a sibling and rename, so a partially written secret never becomes the
  // file the next run trusts. A concurrent first run that wins the rename is not
  // an error: its secret is the one that gets loaded.
  TmpPath := Path + TMP_FILE_SUFFIX;
  Secret := TRandomGenerator.RandomBytes(UBS2_MASTER_SECRET_MIN_SIZE);
  try
    TFile.WriteAllBytes(TmpPath, Secret);
    {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
    ApplyOwnerOnlyMode(TmpPath, False);
    {$ENDIF}
  finally
    SecureClearBytes(Secret);
  end;

  try
    TFile.Move(TmpPath, Path);
  except
    on E: Exception do
      if not TFile.Exists(Path) then
        raise ESecurityException.CreateFmt(
          'Cannot provision master key file "%s": %s', [Path, E.Message]);
  end;

  Result := Load(Path);
end;

class procedure TUserMasterKey.ExportTo(const ADestFile: string);
var
  Dest, TmpPath, Written, Dir: string;
  Secret, ReadBack: TBytes;
  SrcHash, DstHash: string;
begin
  Dest := Trim(ADestFile);
  if Dest = '' then
    raise ESecurityException.Create(
      'Export destination is empty. Pass the full path the backup should be written to.');

  // Load fails closed on a missing or malformed key: handing out a file that
  // seals nothing would give the user a backup with the authority of one.
  Secret := Load(KeyFilePath);
  TmpPath := '';
  Written := '';
  try
    if TFile.Exists(Dest) then
      raise ESecurityException.CreateFmt(
        'Export destination "%s" already exists. Nothing was overwritten. Choose a new ' +
        'path, or remove the older backup once you have confirmed you no longer need it.',
        [Dest]);

    Dir := TPath.GetDirectoryName(Dest);
    if (Dir <> '') and not TDirectory.Exists(Dir) then
      raise ESecurityException.CreateFmt(
        'Export destination directory "%s" does not exist. Create it first; this command ' +
        'will not guess where to put a copy of the master secret.', [Dir]);

    TmpPath := Dest + TMP_FILE_SUFFIX;
    if TFile.Exists(TmpPath) then
      raise ESecurityException.CreateFmt(
        'A leftover export file "%s" exists. A previous export did not finish; delete ' +
        'that file (it may hold key material) and export again.', [TmpPath]);

    try
      TFile.WriteAllBytes(TmpPath, Secret);
      // Written tracks whichever name currently holds our unfinished copy, so
      // cleanup never deletes a file that appeared under Dest after the check above.
      Written := TmpPath;
      ApplyOwnerOnlyToFile(Written);

      // Compare against what is on disk, not against what was buffered: the file
      // the user will trust is the one that survived the write and the ACL call.
      ReadBack := TFile.ReadAllBytes(Written);
      try
        SrcHash := THashUtils.HashToHex(Secret, haSHA256).ToLower;
        DstHash := THashUtils.HashToHex(ReadBack, haSHA256).ToLower;
        if (Length(ReadBack) <> Length(Secret)) or (SrcHash <> DstHash) then
          raise ESecurityException.CreateFmt(
            'Export verification failed: the copy at "%s" does not match the master key ' +
            '(%d bytes hashed to %s, copy is %d bytes hashing to %s). The backup was not kept.',
            [Written, Length(Secret), SrcHash, Length(ReadBack), DstHash]);
      finally
        SecureClearBytes(ReadBack);
      end;

      TFile.Move(TmpPath, Dest);
      // The rename is where the copy takes the name the user will trust, and a move
      // is also where a volume may re-evaluate inherited access. Restricting the
      // sibling alone would therefore prove nothing about the delivered file, so the
      // owner-only guarantee is asserted again on the destination itself.
      Written := Dest;
      ApplyOwnerOnlyToFile(Written);
    except
      on E: Exception do
      begin
        // A half-written export is live key material in a place nobody asked for.
        if TFile.Exists(Written) then
        begin
          try
            TFile.Delete(Written);
          except
            on CleanupError: Exception do
              raise ESecurityException.Create(
                E.Message + ' An unfinished copy holding key material is still at "' +
                Written + '" and could not be removed: ' + CleanupError.Message);
          end;
        end;
        raise;
      end;
    end;
  finally
    SecureClearBytes(Secret);
  end;
end;

class function TUserMasterKey.FingerprintOf(const AKeyFile: string): string;
var
  Secret: TBytes;
begin
  Secret := Load(AKeyFile);
  try
    Result := THashUtils.HashToHex(Secret, haSHA256).ToLower;
  finally
    SecureClearBytes(Secret);
  end;
end;

end.
