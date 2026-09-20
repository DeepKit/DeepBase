unit DeepBase.Security.UBS2.Migration;

{*******************************************************************************
  DeepBase Security UBS2 Migration — one-way reader/writer pair for pre-v2 secrets.

  Before v2 the envelope key was derived from machine entropy (machine id / home /
  user, and a DEEPBASE_MASTER_KEY override), so historical records cannot be opened
  with the new user secret. This unit is the only place that still knows the old
  entropy formula, and it is reachable exclusively from migration entry points:
  the production read path rejects v1 with a clear "run the migrator" error.

  Migration is per record and non-destructive by construction: the caller decides
  when to overwrite the stored blob, so a failure leaves the v1 record intact.

  Author: DeepBase Team
  Created: 2026-09-20
*******************************************************************************}

interface

uses
  System.SysUtils,
  DeepBase.Security.UBS2;

type
  TUBS2Migrator = class
  public
    /// <summary>True when the blob is a UBS2 v1 envelope that this build can no
    /// longer read through the normal path.</summary>
    class function NeedsMigration(const AData: TBytes): Boolean; static;

    /// <summary>Open a v1 envelope with the legacy entropy string and re-seal the
    /// plaintext as v2 under the user-secret key material.</summary>
    class function Reencrypt(const AEnvelope: TBytes; const ALegacyPassphrase: string;
      const AKey: TUBS2KeyMaterial): TBytes; static;

    /// <summary>Exact pre-v2 Linux entropy input: machine-id (or hostname when the
    /// machine-id was unreadable) plus the OS user name.</summary>
    class function LegacyPassphraseLinux(const AMachineId, AUser: string): string; static;

    /// <summary>Exact pre-v2 macOS entropy input: HOME plus the OS user name.</summary>
    class function LegacyPassphraseMacOS(const AHome, AUser: string): string; static;

    {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
    /// <summary>Recompute the legacy passphrase from this machine, the way the
    /// pre-v2 writer did. Records sealed under a DEEPBASE_MASTER_KEY override must
    /// pass that value to Reencrypt instead.</summary>
    class function LegacyPassphrase: string; static;
    {$ENDIF}
  end;

implementation

uses
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  System.IOUtils,
  {$ENDIF}
  DeepBase.Exceptions,
  DeepBase.SecureMemory;

{ TUBS2Migrator }

class function TUBS2Migrator.NeedsMigration(const AData: TBytes): Boolean;
begin
  Result := TUBS2.IsUBS2(AData) and
            (TUBS2.FormatVersionOf(AData) = UBS2_FORMAT_VERSION_V1);
end;

class function TUBS2Migrator.Reencrypt(const AEnvelope: TBytes;
  const ALegacyPassphrase: string; const AKey: TUBS2KeyMaterial): TBytes;
var
  LPlain: TBytes;
begin
  if not NeedsMigration(AEnvelope) then
    raise ESecurityException.Create(
      'UBS2 migrator accepts version 1 envelopes only; this record is not legacy v1.');

  LPlain := TUBS2.UnprotectLegacyV1(AEnvelope, ALegacyPassphrase);
  try
    Result := TUBS2.Protect(LPlain, AKey);
  finally
    SecureClearBytes(LPlain);
  end;
end;

class function TUBS2Migrator.LegacyPassphraseLinux(const AMachineId,
  AUser: string): string;
begin
  Result := AMachineId + ':' + AUser + ':Linux:DeepBase';
end;

class function TUBS2Migrator.LegacyPassphraseMacOS(const AHome,
  AUser: string): string;
begin
  Result := AHome + ':' + AUser + ':macOS:DeepBase';
end;

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
class function TUBS2Migrator.LegacyPassphrase: string;
var
  LMachineId: string;
begin
  {$IFDEF LINUX}
  LMachineId := '';
  if TFile.Exists('/etc/machine-id') then
    LMachineId := Trim(TFile.ReadAllText('/etc/machine-id'));
  if LMachineId = '' then
    LMachineId := GetEnvironmentVariable('HOSTNAME');
  Result := LegacyPassphraseLinux(LMachineId, GetEnvironmentVariable('USER'));
  {$ELSE}
  Result := LegacyPassphraseMacOS(GetEnvironmentVariable('HOME'),
    GetEnvironmentVariable('USER'));
  {$ENDIF}
end;
{$ENDIF}

end.
