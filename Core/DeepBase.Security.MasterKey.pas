unit DeepBase.Security.MasterKey;

{*******************************************************************************
  DeepBase Security MasterKey - SSOT for the user secret behind UBS2.

  UBS2 v2 derives its key from this secret alone (see DeepBase.Security.UBS2);
  machine identity travels through the AAD. That split is what makes "same
  machine, different user" decryption impossible: the secret lives in the user's
  own home directory with owner-only permissions, while the binding value is
  readable by anyone on the box.

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
  end;

const
  MASTER_KEY_FILE_ENV = 'DEEPBASE_MASTER_KEY_FILE';
  MASTER_KEY_DIR_NAME = '.deepbase';
  MASTER_KEY_FILE_NAME = 'master.key';

implementation

uses
  System.IOUtils,
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  Posix.SysStat,
  {$ENDIF}
  DeepBase.Exceptions,
  DeepBase.Crypto.Random,
  DeepBase.SecureMemory,
  DeepBase.Security.UBS2;

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
const
  // S_IRUSR or S_IWUSR are not exported by Posix.SysStat; use the octal literals.
  OWNER_ONLY_FILE_MODE = $180;  // 0600
  OWNER_ONLY_DIR_MODE = $1C0;   // 0700

procedure ApplyOwnerOnlyMode(const APath: string; AIsDirectory: Boolean);
var
  LMode: Cardinal;
begin
  LMode := IIf(AIsDirectory, OWNER_ONLY_DIR_MODE, OWNER_ONLY_FILE_MODE);
  if Posix.SysStat.chmod(PAnsiChar(AnsiString(APath)), LMode) <> 0 then
    raise ESecurityException.CreateFmt(
      'Cannot restrict %s to its owner (chmod 0%o failed). The master secret must not ' +
      'be stored world-readable.', [APath, LMode]);
end;
{$ENDIF}

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
  TmpPath := Path + '.tmp';
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

end.
