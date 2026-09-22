{ ============================================================================
  CLI.Security - Master key backup commands

  Version: 1.0
  Notes: Security-related subcommands (security export/status/verify) for the
  per-user master key owned by DeepBase.Security.MasterKey. This unit adds no
  key-handling policy of its own: it resolves the destination, states the risk,
  and calls into that unit, which is the single source of truth.
  ============================================================================ }

unit CLI.Security;

interface

uses
  System.SysUtils,
  CLI.Commands;

type
  TSecurityCommands = class
  private
    class procedure ShowHelp;
    class function DoExport: Integer;
    class function DoStatus: Integer;
    class function DoVerify: Integer;
  public
    class function Execute: Integer;
  end;

implementation

uses
  System.IOUtils,
  DeepBase.Security.MasterKey;

{ TSecurityCommands }

class function TSecurityCommands.Execute: Integer;
var
  SubCmd: string;
begin
  SubCmd := TCliUtils.GetSubCommand;

  if (SubCmd = '') or (SubCmd = 'help') or TCliUtils.HasOption('help') then
  begin
    ShowHelp;
    Result := 0;
  end
  else if SubCmd = 'export' then
    Result := DoExport
  else if SubCmd = 'status' then
    Result := DoStatus
  else if SubCmd = 'verify' then
    Result := DoVerify
  else
  begin
    TCliUtils.Error('Unknown security subcommand: %s', [SubCmd]);
    ShowHelp;
    Result := 1;
  end;
end;

class procedure TSecurityCommands.ShowHelp;
begin
  Writeln('Security Commands');
  Writeln('');
  Writeln('Usage: DeepBase security <subcommand> [options]');
  Writeln('');
  Writeln('Subcommands:');
  Writeln('  export      Write a verified backup of the master key to a file');
  Writeln('  status      Report the master key path, its source and access policy');
  Writeln('  verify      Compare a backup against the current master key');
  Writeln('');
  Writeln('Options:');
  Writeln('  --output, -o <path>   Destination file for export (must not exist)');
  Writeln('  --file, -f <path>     Backup file for verify');
  Writeln('  --yes                 Skip the interactive confirmation of export');
  Writeln('  --help                Show this help');
  Writeln('');
  Writeln('Examples:');
  Writeln('  DeepBase security export --output E:\deepbase-master-key-20260921.key');
  Writeln('  DeepBase security status');
  Writeln('  DeepBase security verify --file E:\deepbase-master-key-20260921.key');
end;

class function TSecurityCommands.DoExport: Integer;
var
  Dest: string;
begin
  Result := 1;

  Dest := Trim(TCliUtils.GetOption('output', TCliUtils.GetOption('o', '')));
  if Dest = '' then
  begin
    TCliUtils.Error('export needs a destination: DeepBase security export --output <path>');
    Exit;
  end;
  Dest := TCliUtils.ResolvePath(Dest);

  Writeln('');
  TCliUtils.Warning('You are about to write the DeepBase master key to a plain file.');
  Writeln('  Source      : ', TUserMasterKey.KeyFilePath);
  Writeln('  Destination : ', Dest);
  Writeln('');
  Writeln('  That file is the ONLY secret behind every credential DeepBase seals for');
  Writeln('  this user. Anyone who reads it can decrypt those records. If it is lost,');
  Writeln('  the records sealed with it can never be recovered again - there is no');
  Writeln('  server-side reset and no second copy on this machine.');
  Writeln('');
  Writeln('  Keep the export offline: an encrypted drive, a password manager, or a');
  Writeln('  removable medium in a drawer. Do not commit it to a repository, send it');
  Writeln('  by mail or chat, or leave it in a folder a cloud drive syncs.');
  Writeln('');
  Writeln('  Relation to the UBS2 v1 -> v2 migration window: migration re-seals');
  Writeln('  records and never rewrites the key file, so one backup is valid on both');
  Writeln('  sides of that window. Export before migrating, then run');
  Writeln('    DeepBase security verify --file <this backup>');
  Writeln('  afterwards. A fingerprint that no longer matches means a different');
  Writeln('  secret is in place, which is a lost key, not a failed migration.');
  Writeln('');
  if not TCliUtils.HasOption('yes') then
    if not TCliUtils.Confirm('Write the export now?', False) then
    begin
      TCliUtils.Info('Cancelled. Nothing was written.');
      Exit;
    end;

  // ExportTo restricts the copy to its owner and compares length and SHA-256
  // against the live key before the destination name appears; a mismatch raises
  // and leaves nothing behind, so a non-zero exit here really means "no backup".
  TUserMasterKey.ExportTo(Dest);

  TCliUtils.Success('Master key exported and verified: %s', [Dest]);
  Writeln('Fingerprint (SHA-256): ', TUserMasterKey.FingerprintOf(Dest));
  Writeln('Record this fingerprint next to the backup; verify --file re-derives it.');
  Result := 0;
end;

class function TSecurityCommands.DoStatus: Integer;
var
  KeyPath: string;
begin
  Result := 1;
  KeyPath := TUserMasterKey.KeyFilePath;

  Writeln('Master key file  : ', KeyPath);
  if Trim(GetEnvironmentVariable(MASTER_KEY_FILE_ENV)) <> '' then
    Writeln('Resolved from    : environment variable ', MASTER_KEY_FILE_ENV);

  // Read-only by design: status must never provision a key, because a query that
  // creates the secret would hide the very loss it is meant to report. Neither line
  // below says anything about the access an existing file carries: status reads it
  // nowhere, and a key predating this restriction keeps the ACL it was created with
  // until its owner sets one (icacls / ls -l).
  if TUserMasterKey.AccessManagedExternally then
    TCliUtils.Warning('Access policy    : newly provisioned keys are NOT restricted to ' +
      'their owner, because ' + MASTER_KEY_EXTERNAL_ACL_ENV + ' declares that somebody ' +
      'else administers access to the path held in ' + MASTER_KEY_FILE_ENV)
  else
    Writeln('Access policy    : newly provisioned keys are restricted to their owner; ' +
      'this command changes nothing about a file that already exists');

  if not TFile.Exists(KeyPath) then
  begin
    Writeln('Key source       : no key file yet - the first use that seals data ' +
      'provisions one at the path above');
    TCliUtils.Warning('The master key does not exist yet. It is created on the first ' +
      'use that seals data; until then there is nothing to back up.');
    Exit;
  end;

  Writeln('Key source       : existing key file, read as it is');
  Writeln('Size (bytes)     : ', TFile.GetSize(KeyPath):0);
  Writeln('Fingerprint      : ', TUserMasterKey.FingerprintOf(KeyPath));
  Writeln('(One-way SHA-256 of the key material. Publishing it reveals nothing,');
  Writeln('but it lets any copy be checked with "security verify".)');
  Result := 0;
end;

class function TSecurityCommands.DoVerify: Integer;
var
  LivePath, BackupPath, LiveFp, BackupFp: string;
begin
  Result := 1;
  BackupPath := Trim(TCliUtils.GetOption('file', TCliUtils.GetOption('f', '')));
  if BackupPath = '' then
  begin
    TCliUtils.Error('verify needs a file: DeepBase security verify --file <path>');
    Exit;
  end;
  BackupPath := TCliUtils.ResolvePath(BackupPath);
  LivePath := TUserMasterKey.KeyFilePath;

  LiveFp := TUserMasterKey.FingerprintOf(LivePath);
  BackupFp := TUserMasterKey.FingerprintOf(BackupPath);

  Writeln('Current key      : ', LivePath);
  Writeln('  fingerprint    : ', LiveFp);
  Writeln('Checked file     : ', BackupPath);
  Writeln('  fingerprint    : ', BackupFp);

  if SameText(LiveFp, BackupFp) then
  begin
    TCliUtils.Success('Match. This file is a usable backup of the current master key.');
    Result := 0;
  end
  else
    TCliUtils.Error('Mismatch. This file seals nothing that the current key seals. ' +
      'Either it belongs to another secret or it was damaged.');
end;

end.
