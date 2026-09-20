unit DeepBase.Security.MachineIdentity;

{*******************************************************************************
  DeepBase Security MachineIdentity - SSOT for the machine affinity value.

  The machine identity answers one question only: "is this still the same
  machine?". It is therefore used as
    - additional authenticated data (AAD) of a UBS2 envelope, and
    - a gate/checksum value stored next to a keystore.
  It is never secret entropy and never part of a password derivation; the user
  secret in DeepBase.Security.MasterKey is the only entropy source.

  Source policy (A11-02 / Top20 #5):
    Windows : HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid + system volume serial
    Linux   : /etc/machine-id + root mount device from /proc/mounts
    macOS   : machine-scope install id (single mandatory source; see Collect)
  Every source is mandatory: if one cannot be read the collector raises instead
  of degrading. Values that a user or an OEM can rename or that are identical
  across a machine fleet (computer name, product id, BIOS/Disk placeholders) are
  deliberately excluded, because a binding built from them proves nothing.

  SMBIOS (GetSystemFirmwareTable/RSMD) is not part of the scheme: it is absent in
  several virtualized/remote Windows hosts, so mandating it would lock real
  installations out of their own secrets.

  Changing the source set or its order requires bumping
  MACHINE_IDENTITY_SCHEME_VERSION, which makes previously sealed envelopes fail
  the AAD check rather than silently accept a weaker binding.

  Author: DeepBase Team
  Created: 2026-09-20
*******************************************************************************}

interface

uses
  System.SysUtils;

type
  /// <summary>One decorrelated machine source.</summary>
  TMachineSource = record
    Name: string;
    Value: string;
  end;

  /// <summary>Versioned tuple of machine sources; ordered, canonical, comparable.</summary>
  TMachineIdentity = record
    SchemeVersion: Integer;
    Sources: TArray<TMachineSource>;
    /// <summary>Stable textual form: v{scheme}|name=value|name=value</summary>
    function Canonical: string;
    /// <summary>Bytes fed to UBS2 as AAD.</summary>
    function ToBinding: TBytes;
    /// <summary>Hex SHA-256 of Canonical, for stored gate/checksum values.</summary>
    function ToHash: string;
    /// <summary>Full match: same scheme version, same sources, same order, all values equal.</summary>
    function Matches(const AOther: TMachineIdentity): Boolean;
  end;

  /// <summary>Machine identity collector.</summary>
  TMachineIdentityProvider = class
  public
    /// <summary>Collect all mandatory sources. Raises ESecurityException when any is unavailable.</summary>
    class function Collect: TMachineIdentity; static;
    /// <summary>AAD material for the current machine.</summary>
    class function Binding: TBytes; static;
    /// <summary>Hex fingerprint of the current machine.</summary>
    class function Fingerprint: string; static;
  end;

const
  MACHINE_IDENTITY_SCHEME_VERSION = 1;

implementation

uses
  System.IOUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  System.Win.Registry,
  {$ENDIF}
  DeepBase.Exceptions,
  DeepBase.Crypto.Hash,
  DeepBase.Crypto.Random,
  DeepBase.SecureMemory;

const
  SCHEME_PREFIX = 'v';
  SOURCE_SEPARATOR = '|';
  NAME_VALUE_SEPARATOR = '=';

procedure FailSourceUnavailable(const AName: string);
begin
  raise ESecurityException.CreateFmt(
    'Machine identity source "%s" is unavailable. Machine binding is fail-closed ' +
    'and never falls back to user- or OEM-configurable values.', [AName]);
end;

function StripWhitespace(const AValue: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(AValue) do
    if not CharInSet(AValue[I], [#9, #10, #13, #32]) then
      Result := Result + AValue[I];
end;

{ TMachineIdentity }

function TMachineIdentity.Canonical: string;
var
  Src: TMachineSource;
begin
  Result := SCHEME_PREFIX + IntToStr(SchemeVersion);
  for Src in Sources do
    Result := Result + SOURCE_SEPARATOR + Src.Name + NAME_VALUE_SEPARATOR + Src.Value;
end;

function TMachineIdentity.ToBinding: TBytes;
begin
  Result := TEncoding.UTF8.GetBytes(Canonical);
end;

function TMachineIdentity.ToHash: string;
begin
  Result := THashUtils.SHA256(Canonical);
end;

function TMachineIdentity.Matches(const AOther: TMachineIdentity): Boolean;
var
  I: Integer;
begin
  if (SchemeVersion <> AOther.SchemeVersion) or
     (Length(Sources) <> Length(AOther.Sources)) then
    Exit(False);
  for I := 0 to High(Sources) do
    if (Sources[I].Name <> AOther.Sources[I].Name) or
       (Sources[I].Value <> AOther.Sources[I].Value) then
      Exit(False);
  Result := True;
end;

{$IFDEF MSWINDOWS}
function ReadRegistryValue(ARoot: HKEY; const AKey, AValueName: string): string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := ARoot;
    if Reg.OpenKeyReadOnly(AKey) then
    begin
      try
        if Reg.ValueExists(AValueName) then
          Result := Reg.ReadString(AValueName);
      finally
        Reg.CloseKey;
      end;
    end;
  finally
    Reg.Free;
  end;
end;

function ReadSystemVolumeSerial: string;
var
  Root: string;
  Serial, MaxComponent, FsFlags: DWORD;
begin
  // GetVolumeInformationW only accepts a drive root; a directory path fails with
  // ERROR_PATH_NOT_FOUND.
  Root := Copy(GetEnvironmentVariable('SystemRoot'), 1, 2);
  if Length(Root) < 2 then
    Exit('');
  Root := Root + '\';
  Serial := 0;
  MaxComponent := 0;
  FsFlags := 0;
  if not GetVolumeInformationW(PWideChar(Root), nil, 0, @Serial, MaxComponent,
       FsFlags, nil, 0) then
    Exit('');
  Result := IntToHex(Serial, 8);
end;
{$ENDIF}

{$IFDEF LINUX}
// The device the root filesystem is mounted from, read from /proc/mounts. It is a
// pure file read (no libc binding), machine-unique for a fixed disk layout, and
// independent of /etc/machine-id, which is what makes the pair decorrelated.
function ReadRootMountDevice: string;
var
  Lines: TArray<string>;
  Line: string;
  Parts: TArray<string>;
begin
  Result := '';
  if not TFile.Exists('/proc/mounts') then
    Exit;

  Lines := TFile.ReadAllLines('/proc/mounts');
  for Line in Lines do
  begin
    Parts := Line.Split([' ']);
    if (Length(Parts) < 2) or (Parts[1] <> '/') then
      Continue;
    Exit(Parts[0]);
  end;
end;
{$ENDIF}

{$IFDEF MACOS}
const
  MACHINE_ID_DIR = '/Library/Application Support/DeepBase';
  MACHINE_ID_FILE = 'machine.id';

function MachineInstallIdPath: string;
begin
  Result := MACHINE_ID_DIR + '/' + MACHINE_ID_FILE;
end;

// Machine-scope, world-readable on purpose: it is an affinity marker, not a
// secret (the secret entropy is the per-user master key). It must be shared by
// all users of one Mac, so a per-user file cannot be used here.
function ReadOrCreateMachineInstallId: string;
var
  Path: string;
  Raw: TBytes;
begin
  Path := MachineInstallIdPath;
  if TFile.Exists(Path) then
    Exit(StripWhitespace(TFile.ReadAllText(Path)));

  Raw := TRandomGenerator.RandomBytes(16);
  try
    TDirectory.CreateDirectory(MACHINE_ID_DIR);
    TFile.WriteAllText(Path, THashUtils.HashToHex(Raw).ToLower);
  finally
    SecureClearBytes(Raw);
  end;
  Result := StripWhitespace(TFile.ReadAllText(Path));
end;
{$ENDIF}

function Source(const AName, AValue: string): TMachineSource;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

{ TMachineIdentityProvider }

class function TMachineIdentityProvider.Collect: TMachineIdentity;
begin
  Result := Default(TMachineIdentity);
  Result.SchemeVersion := MACHINE_IDENTITY_SCHEME_VERSION;

  {$IFDEF MSWINDOWS}
  SetLength(Result.Sources, 2);
  Result.Sources[0] := Source('hklm-machine-guid',
    ReadRegistryValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Cryptography', 'MachineGuid'));
  if Result.Sources[0].Value = '' then
    FailSourceUnavailable(Result.Sources[0].Name);
  Result.Sources[1] := Source('system-volume-serial', ReadSystemVolumeSerial);
  if Result.Sources[1].Value = '' then
    FailSourceUnavailable(Result.Sources[1].Name);
  {$ENDIF}

  {$IFDEF LINUX}
  SetLength(Result.Sources, 2);
  Result.Sources[0] := Source('etc-machine-id',
    StripWhitespace(TFile.ReadAllText('/etc/machine-id')));
  if Result.Sources[0].Value = '' then
    FailSourceUnavailable(Result.Sources[0].Name);
  Result.Sources[1] := Source('root-mount-device', ReadRootMountDevice);
  if Result.Sources[1].Value = '' then
    FailSourceUnavailable(Result.Sources[1].Name);
  {$ENDIF}

  {$IFDEF MACOS}
  // macOS is limited to one mandatory source: a pure-Pascal reader for a second
  // decorrelated hardware-ish identifier is not available in the RTL, and neither
  // the computer name nor the host name may be substituted (fail-closed rule).
  // Enlarging the set requires an IOKit binding and a scheme version bump.
  SetLength(Result.Sources, 1);
  Result.Sources[0] := Source('machine-install-id', ReadOrCreateMachineInstallId);
  if Result.Sources[0].Value = '' then
    FailSourceUnavailable(Result.Sources[0].Name);
  {$ENDIF}

  {$IFNDEF MSWINDOWS}
  {$IFNDEF LINUX}
  {$IFNDEF MACOS}
  raise ESecurityException.Create(
    'No machine identity sources are implemented for this platform; ' +
    'machine-bound secrets are unavailable by design.');
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

class function TMachineIdentityProvider.Binding: TBytes;
begin
  Result := Collect.ToBinding;
end;

class function TMachineIdentityProvider.Fingerprint: string;
begin
  Result := Collect.ToHash;
end;

end.
