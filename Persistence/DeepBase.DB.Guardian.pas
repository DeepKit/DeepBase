{ ============================================================================
  DeepBase.DB.Guardian - SQLite database corruption prevention & recovery
  ============================================================================
  Provides:
    1. Recommended PRAGMAs for durability (WAL + synchronous + busy_timeout ...)
    2. Integrity check on open (PRAGMA integrity_check / quick_check)
    3. Automatic corruption quarantine + best-effort recovery
    4. Online backup using SQLite backup API (via FireDAC)
    5. Periodic WAL checkpoint to prevent unbounded WAL growth

  Design goals:
    - Zero cost when DB is healthy
    - When corrupted: quarantine to [db].corrupted_[timestamp],
      try restore from newest [db].backup*, else start fresh
    - Never lose data silently: always log + keep quarantine file
  ============================================================================ }

unit DeepBase.DB.Guardian;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client;

type
  TIntegrityStatus = (isOk, isCorrupted, isUnknown);

  TGuardianResult = record
    Status: TIntegrityStatus;
    Message: string;
    QuarantinePath: string;
    RestoredFromBackup: Boolean;
  end;

  TDBGuardian = class
  public
    /// <summary>Apply recommended PRAGMAs for durability. Call after Open.</summary>
    class procedure ApplyRecommendedPragmas(AConn: TFDConnection); static;

    /// <summary>Run PRAGMA quick_check (fast) or integrity_check (thorough).</summary>
    class function CheckIntegrity(AConn: TFDConnection;
      AQuickOnly: Boolean = True): TIntegrityStatus; static;

    /// <summary>WAL checkpoint to shrink -wal file.</summary>
    class procedure Checkpoint(AConn: TFDConnection;
      const AMode: string = 'TRUNCATE'); static;

    /// <summary>Online backup via VACUUM INTO (atomic snapshot).</summary>
    class function BackupTo(AConn: TFDConnection; const ADestPath: string)
      : Boolean; static;

    /// <summary>
    /// Quarantine a corrupted DB file and (if available) restore from a backup.
    /// Returns details about what happened.
    /// </summary>
    class function QuarantineAndRecover(const ADBPath: string)
      : TGuardianResult; static;

    /// <summary>
    /// Full protection workflow: open, pragma, integrity check,
    /// auto-recover if corrupted. Caller passes a closed connection.
    /// Returns true if connection is now usable.
    /// </summary>
    class function ProtectConnection(AConn: TFDConnection;
      out AResult: TGuardianResult): Boolean; static;

    /// <summary>
    /// Find newest backup file in same folder matching {dbname}.backup*.
    /// Returns empty string if none found.
    /// </summary>
    class function FindLatestBackup(const ADBPath: string): string; static;
  end;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  FireDAC.Stan.Def,
  FireDAC.Stan.Error;

{ ---------- TDBGuardian ---------- }

class procedure TDBGuardian.ApplyRecommendedPragmas(AConn: TFDConnection);
begin
  if (AConn = nil) or (not AConn.Connected) then
    Exit;
  // These are idempotent and safe to run on every open
  try
    // journal_mode=WAL: allows concurrent reads during write, atomic commits
    AConn.ExecSQL('PRAGMA journal_mode=WAL');
    // synchronous=NORMAL: fsync on checkpoint, safe with WAL
    AConn.ExecSQL('PRAGMA synchronous=NORMAL');
    // foreign_keys=ON: enforce FK constraints (SQLite default is OFF)
    AConn.ExecSQL('PRAGMA foreign_keys=ON');
    // busy_timeout: wait up to 5 seconds for locks instead of failing
    AConn.ExecSQL('PRAGMA busy_timeout=5000');
    // wal_autocheckpoint: keep -wal file bounded (default 1000 pages)
    AConn.ExecSQL('PRAGMA wal_autocheckpoint=1000');
    // temp_store=MEMORY: temp tables in RAM (faster, no disk corruption risk)
    AConn.ExecSQL('PRAGMA temp_store=MEMORY');
    // secure_delete=OFF: faster DELETE (we don't need to zero pages)
    AConn.ExecSQL('PRAGMA secure_delete=OFF');
  except
    // Pragmas are best-effort. Don't fail connection just because one failed.
  end;
end;

class function TDBGuardian.CheckIntegrity(AConn: TFDConnection;
  AQuickOnly: Boolean): TIntegrityStatus;
var
  Query: TFDQuery;
  Sql: string;
  Value: string;
begin
  Result := isUnknown;
  if (AConn = nil) or (not AConn.Connected) then
    Exit;

  if AQuickOnly then
    Sql := 'PRAGMA quick_check'
  else
    Sql := 'PRAGMA integrity_check';

  Query := TFDQuery.Create(nil);
  try
    try
      Query.Connection := AConn;
      Query.SQL.Text := Sql;
      Query.Open;
      if Query.Eof then
        Exit(isUnknown);
      Value := Trim(Query.Fields[0].AsString);
      if SameText(Value, 'ok') then
        Result := isOk
      else
        Result := isCorrupted;
    except
      // An exception here most likely means the DB file itself can't be read
      Result := isCorrupted;
    end;
  finally
    Query.Free;
  end;
end;

class procedure TDBGuardian.Checkpoint(AConn: TFDConnection;
  const AMode: string);
var
  LMode: string;
begin
  if (AConn = nil) or (not AConn.Connected) then
    Exit;

  LMode := AMode;
  if LMode = '' then
    LMode := 'PASSIVE';

  LMode := LMode.ToUpper;
  if not ((LMode = 'PASSIVE') or (LMode = 'FULL') or (LMode = 'RESTART') or (LMode = 'TRUNCATE')) then
    raise EArgumentOutOfRangeException.CreateFmt('Invalid checkpoint mode: %s', [AMode]);

  try
    // PASSIVE / FULL / RESTART / TRUNCATE
    AConn.ExecSQL('PRAGMA wal_checkpoint(' + LMode + ')');
  except
    // Checkpoint failure shouldn't break caller
  end;
end;

class function TDBGuardian.BackupTo(AConn: TFDConnection;
  const ADestPath: string): Boolean;
var
  DestDir: string;
  TempPath: string;
begin
  Result := False;
  if (AConn = nil) or (not AConn.Connected) or (ADestPath = '') then
    Exit;

  DestDir := TPath.GetDirectoryName(ADestPath);
  if (DestDir <> '') and (not TDirectory.Exists(DestDir)) then
    TDirectory.CreateDirectory(DestDir);

  // Write to temporary file first, then rename to prevent data loss on crash
  TempPath := ADestPath + '.tmp';

  // VACUUM INTO requires target to not exist
  if TFile.Exists(TempPath) then
    TFile.Delete(TempPath);

  try
    // VACUUM INTO produces a compact, consistent copy without locking readers
    AConn.ExecSQL('VACUUM INTO ' + QuotedStr(TempPath));
    if not TFile.Exists(TempPath) then
      Exit;

    // Atomic rename: delete old backup then move temp into place
    if TFile.Exists(ADestPath) then
      TFile.Delete(ADestPath);
    TFile.Move(TempPath, ADestPath);
    Result := TFile.Exists(ADestPath);
  except
    // Backup failure is non-fatal; clean up temp file
    if TFile.Exists(TempPath) then
      try TFile.Delete(TempPath); except end;
  end;
end;

class function TDBGuardian.FindLatestBackup(const ADBPath: string): string;
var
  Dir: string;
  DBName: string;
  Files: TArray<string>;
  I: Integer;
  LatestTime: TDateTime;
  FileTime: TDateTime;
begin
  Result := '';
  if ADBPath = '' then
    Exit;

  Dir := TPath.GetDirectoryName(ADBPath);
  DBName := TPath.GetFileName(ADBPath);
  if (Dir = '') or (not TDirectory.Exists(Dir)) then
    Exit;

  // Match {dbname}.backup, {dbname}.backup.2026-05-10, etc.
  Files := TDirectory.GetFiles(Dir, DBName + '.backup*');
  LatestTime := 0;
  for I := 0 to High(Files) do
  begin
    FileTime := TFile.GetLastWriteTime(Files[I]);
    if FileTime > LatestTime then
    begin
      LatestTime := FileTime;
      Result := Files[I];
    end;
  end;
end;

class function TDBGuardian.QuarantineAndRecover(const ADBPath: string)
  : TGuardianResult;
var
  TimeStamp: string;
  QuarantinePath: string;
  BackupPath: string;
  Dir: string;
  SideFile: string;
  SideFiles: TArray<string>;
  I: Integer;
begin
  Result.Status := isCorrupted;
  Result.Message := '';
  Result.QuarantinePath := '';
  Result.RestoredFromBackup := False;

  if (ADBPath = '') or (not TFile.Exists(ADBPath)) then
  begin
    Result.Message := 'DB file not found: ' + ADBPath;
    Exit;
  end;

  // 1. Move corrupted DB aside (keep for user/engineer forensics)
  TimeStamp := FormatDateTime('yyyymmdd_hhnnss_zzz', Now);
  QuarantinePath := ADBPath + '.corrupted_' + TimeStamp;
  try
    TFile.Move(ADBPath, QuarantinePath);
    Result.QuarantinePath := QuarantinePath;
  except
    on E: Exception do
    begin
      Result.Message := 'Failed to quarantine corrupted DB: ' + E.Message;
      Exit;
    end;
  end;

  // Also move side files (-wal, -shm, -journal) so they don't reattach
  Dir := TPath.GetDirectoryName(ADBPath);
  SetLength(SideFiles, 3);
  SideFiles[0] := ADBPath + '-wal';
  SideFiles[1] := ADBPath + '-shm';
  SideFiles[2] := ADBPath + '-journal';
  for I := 0 to High(SideFiles) do
  begin
    SideFile := SideFiles[I];
    if TFile.Exists(SideFile) then
    begin
      try
        TFile.Move(SideFile, SideFile + '.corrupted_' + TimeStamp);
      except
        // Non-fatal
      end;
    end;
  end;

  // 2. Try to restore from newest backup
  BackupPath := FindLatestBackup(ADBPath);
  if (BackupPath <> '') and TFile.Exists(BackupPath) then
  begin
    try
      TFile.Copy(BackupPath, ADBPath);
      Result.RestoredFromBackup := True;
      Result.Status := isOk;
      Result.Message := 'Restored from backup: ' + TPath.GetFileName(BackupPath);
      Exit;
    except
      on E: Exception do
        Result.Message := 'Backup restore failed: ' + E.Message + '; ';
    end;
  end;

  // 3. No backup or backup failed: app will create a fresh DB on next open
  Result.Message := Result.Message +
    'No usable backup. A fresh DB will be created. ' +
    'Corrupted file preserved at: ' + QuarantinePath;
  Result.Status := isCorrupted; // Still "corrupted" in the sense data was lost
end;

class function TDBGuardian.ProtectConnection(AConn: TFDConnection;
  out AResult: TGuardianResult): Boolean;
var
  DBPath: string;
  Recovery: TGuardianResult;

  procedure CleanupSideFiles(const APath: string);
  var
    LSide: string;
  begin
    // Remove stale WAL/SHM/journal files that can prevent a fresh DB from opening
    for LSide in [APath + '-wal', APath + '-shm', APath + '-journal'] do
      if TFile.Exists(LSide) then
        try TFile.Delete(LSide); except end;
  end;

begin
  Result := False;
  AResult.Status := isUnknown;
  AResult.Message := '';
  AResult.QuarantinePath := '';
  AResult.RestoredFromBackup := False;

  if AConn = nil then
  begin
    AResult.Message := 'Connection is nil';
    Exit;
  end;

  DBPath := AConn.Params.Database;

  // If DB file does not exist, clean up any stale side files from previous runs
  if not TFile.Exists(DBPath) then
    CleanupSideFiles(DBPath);

  // Ensure open
  if not AConn.Connected then
  try
    AConn.Open;
  except
    on E: Exception do
    begin
      // Open itself failed: DB file likely corrupted at filesystem level
      AResult.Message := 'Open failed: ' + E.Message;
      AResult.Status := isCorrupted;

      // Try quarantine + recovery
      Recovery := QuarantineAndRecover(DBPath);
      AResult.QuarantinePath := Recovery.QuarantinePath;
      AResult.RestoredFromBackup := Recovery.RestoredFromBackup;

      // Reset connection to clear any stale state from the failed open
      try
        AConn.Close;
      except
        // Ignore close errors
      end;
      // Also clean up any side files left behind
      CleanupSideFiles(DBPath);
      AConn.Params.Database := DBPath;

      // Retry open (will create fresh DB if no backup restored)
      try
        AConn.Open;
      except
        on E2: Exception do
        begin
          AResult.Message := AResult.Message +
            '; Retry open failed: ' + E2.Message;
          Exit;
        end;
      end;

      // Retry succeeded - apply pragmas and check integrity
      ApplyRecommendedPragmas(AConn);
      AResult.Status := CheckIntegrity(AConn, True);
      // If retry open succeeded and integrity is OK, return success immediately
      // regardless of the Recovery.Status (which is always isCorrupted when no backup exists)
      Result := AConn.Connected and (AResult.Status = isOk);
      Exit;
    end;
  end;

  // Apply recommended pragmas
  ApplyRecommendedPragmas(AConn);

  // Integrity check (quick_check is fast; full integrity_check is slow)
  AResult.Status := CheckIntegrity(AConn, True);

  if AResult.Status = isCorrupted then
  begin
    // Close, quarantine, recover, reopen
    try
      AConn.Close;
    except
      // Ignore
    end;

    Recovery := QuarantineAndRecover(DBPath);
    AResult.QuarantinePath := Recovery.QuarantinePath;
    AResult.RestoredFromBackup := Recovery.RestoredFromBackup;
    if AResult.Message = '' then
      AResult.Message := Recovery.Message
    else
      AResult.Message := AResult.Message + '; ' + Recovery.Message;

    // Clean side files before reopen
    CleanupSideFiles(DBPath);

    // Reopen (fresh DB if no backup)
    try
      AConn.Open;
      ApplyRecommendedPragmas(AConn);
      AResult.Status := CheckIntegrity(AConn, True);
    except
      on E: Exception do
      begin
        AResult.Message := AResult.Message + '; Reopen failed: ' + E.Message;
        Exit;
      end;
    end;
  end;

  Result := AConn.Connected and (AResult.Status = isOk);
end;

end.
