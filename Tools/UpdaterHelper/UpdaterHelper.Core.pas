unit UpdaterHelper.Core;

interface

uses
  System.SysUtils;

type
  THelperOptions = record
    Mode: string;
    PackagePath: string;
    AppDir: string;
    TargetExe: string;
    Restart: Boolean;
    ExpectedSha256: string;
    WaitMs: Cardinal;
  end;

  TUpdaterHelper = class
  public
    class function ParseArgs(out Options: THelperOptions;
      out ErrorMessage: string): Boolean; overload; static;
    class function ParseArgs(const Args: TArray<string>; out Options: THelperOptions;
      out ErrorMessage: string): Boolean; overload; static;
    class function Execute(const Options: THelperOptions;
      out ErrorMessage: string): Boolean; static;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.TlHelp32,
  Winapi.PsAPI,
  Winapi.ShellAPI,
  System.Classes,
  System.Types,
  System.IOUtils,
  System.Hash,
  System.Zip,
  System.Generics.Collections;

const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;

procedure LogLine(const Msg: string);
var
  LogPath: string;
  Line: string;
begin
  try
    LogPath := TPath.Combine(TPath.GetTempPath, 'UniBase.UpdaterHelper.log');
    Line := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + Msg + sLineBreak;
    TFile.AppendAllText(LogPath, Line, TEncoding.UTF8);
  except
    // ignore log failures
  end;
end;

function NormalizeFullPath(const APath: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(TPath.GetFullPath(APath));
end;

function IsPathUnderRoot(const APath, ARoot: string): Boolean;
var
  FullPath: string;
  FullRoot: string;
  Prefix: string;
begin
  FullPath := NormalizeFullPath(APath).ToLower;
  FullRoot := NormalizeFullPath(ARoot).ToLower;
  Prefix := IncludeTrailingPathDelimiter(FullRoot);
  Result := SameText(FullPath, FullRoot) or FullPath.StartsWith(Prefix);
end;

function TryGetProcessImagePath(const APID: DWORD; out ImagePath: string): Boolean;
var
  HProc: THandle;
  Buffer: array[0..4095] of Char;
  Len: DWORD;
begin
  ImagePath := '';
  Result := False;

  HProc := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, APID);
  if HProc = 0 then
    HProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, APID);
  if HProc = 0 then
    Exit;

  try
    Len := GetModuleFileNameEx(HProc, 0, Buffer, Length(Buffer));
    if Len > 0 then
    begin
      SetString(ImagePath, PChar(@Buffer[0]), Len);
      Result := ImagePath <> '';
    end;
  finally
    CloseHandle(HProc);
  end;
end;

function CollectProcessIdsUnderAppDir(const AppDir: string): TArray<DWORD>;
var
  Snapshot: THandle;
  Entry: TProcessEntry32;
  PIDs: TList<DWORD>;
  ImagePath: string;
begin
  PIDs := TList<DWORD>.Create;
  try
    Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if Snapshot = INVALID_HANDLE_VALUE then
      Exit(PIDs.ToArray);

    try
      Entry.dwSize := SizeOf(Entry);
      if Process32First(Snapshot, Entry) then
      begin
        repeat
          if Entry.th32ProcessID = GetCurrentProcessId then
            Continue;

          if TryGetProcessImagePath(Entry.th32ProcessID, ImagePath) then
          begin
            if IsPathUnderRoot(ImagePath, AppDir) then
              PIDs.Add(Entry.th32ProcessID);
          end;
        until not Process32Next(Snapshot, Entry);
      end;
    finally
      CloseHandle(Snapshot);
    end;

    Result := PIDs.ToArray;
  finally
    PIDs.Free;
  end;
end;

function KillProcessById(const APID: DWORD; const WaitMs: Cardinal): Boolean;
var
  HProc: THandle;
  WaitResult: DWORD;
begin
  Result := True;
  HProc := OpenProcess(SYNCHRONIZE or PROCESS_TERMINATE, False, APID);
  if HProc = 0 then
    Exit(True);

  try
    if not TerminateProcess(HProc, 0) then
      Exit(False);
    WaitResult := WaitForSingleObject(HProc, WaitMs);
    Result := WaitResult = WAIT_OBJECT_0;
  finally
    CloseHandle(HProc);
  end;
end;

function StopAppProcesses(const AppDir: string; const WaitMs: Cardinal;
  out ErrorMessage: string): Boolean;
var
  PID: DWORD;
  PIDs: TArray<DWORD>;
begin
  Result := True;
  ErrorMessage := '';
  PIDs := CollectProcessIdsUnderAppDir(AppDir);

  for PID in PIDs do
  begin
    LogLine(Format('Stopping process PID=%d under app dir "%s"', [PID, AppDir]));
    if not KillProcessById(PID, WaitMs) then
    begin
      ErrorMessage := Format('Failed to stop process PID=%d', [PID]);
      Exit(False);
    end;
  end;
end;

function VerifyPackageHash(const PackagePath, ExpectedSha256: string;
  out ErrorMessage: string): Boolean;
var
  FS: TFileStream;
  ActualHash: string;
begin
  Result := False;
  ErrorMessage := '';
  if Trim(ExpectedSha256) = '' then
    Exit(True);

  if not TFile.Exists(PackagePath) then
  begin
    ErrorMessage := 'Package file does not exist: ' + PackagePath;
    Exit(False);
  end;

  FS := TFileStream.Create(PackagePath, fmOpenRead or fmShareDenyWrite);
  try
    ActualHash := LowerCase(THashSHA2.GetHashString(FS, SHA256));
    if not SameText(ActualHash, Trim(ExpectedSha256)) then
    begin
      ErrorMessage := Format('Package hash mismatch. expected=%s actual=%s',
        [Trim(ExpectedSha256), ActualHash]);
      Exit(False);
    end;
  finally
    FS.Free;
  end;
  Result := True;
end;

function RestoreBackup(const BackupDir, AppDir: string;
  const CreatedFiles: TArray<string>; out ErrorMessage: string): Boolean;
var
  BackupFiles: TArray<string>;
  SrcFile: string;
  RelPath: string;
  DestFile: string;
  Created: string;
begin
  Result := False;
  ErrorMessage := '';

  for Created in CreatedFiles do
  begin
    try
      if TFile.Exists(Created) then
        TFile.Delete(Created);
    except
      on E: Exception do
      begin
        ErrorMessage := 'Failed to delete created file during rollback: ' + E.Message;
        Exit(False);
      end;
    end;
  end;

  if not TDirectory.Exists(BackupDir) then
    Exit(True);

  BackupFiles := TDirectory.GetFiles(BackupDir, '*', TSearchOption.soAllDirectories);
  for SrcFile in BackupFiles do
  begin
    RelPath := Copy(SrcFile, Length(ExcludeTrailingPathDelimiter(BackupDir)) + 2, MaxInt);
    DestFile := TPath.Combine(AppDir, RelPath);
    if not IsPathUnderRoot(DestFile, AppDir) then
    begin
      ErrorMessage := 'Rollback refused path outside app dir: ' + DestFile;
      Exit(False);
    end;
    ForceDirectories(TPath.GetDirectoryName(DestFile));
    TFile.Copy(SrcFile, DestFile, True);
  end;

  Result := True;
end;

function ApplyPackageWithRollback(const PackagePath, AppDir: string;
  out ErrorMessage: string): Boolean;
var
  TempRoot: string;
  ExtractDir: string;
  BackupDir: string;
  Zip: TZipFile;
  ExtractedFiles: TArray<string>;
  SrcFile: string;
  RelPath: string;
  DestFile: string;
  BackupFile: string;
  CreatedFiles: TList<string>;
begin
  Result := False;
  ErrorMessage := '';
  CreatedFiles := TList<string>.Create;
  TempRoot := TPath.Combine(TPath.GetTempPath, 'UniBase_UpdaterHelper');
  ExtractDir := TPath.Combine(TempRoot, 'extract_' + FormatDateTime('yyyymmdd_hhnnss_zzz', Now));
  BackupDir := TPath.Combine(TempRoot, 'backup_' + FormatDateTime('yyyymmdd_hhnnss_zzz', Now));

  ForceDirectories(ExtractDir);
  ForceDirectories(BackupDir);

  try
    try
      Zip := TZipFile.Create;
      try
        Zip.Open(PackagePath, zmRead);
        Zip.ExtractAll(ExtractDir);
        Zip.Close;
      finally
        Zip.Free;
      end;

      ExtractedFiles := TDirectory.GetFiles(ExtractDir, '*', TSearchOption.soAllDirectories);
      for SrcFile in ExtractedFiles do
      begin
        RelPath := Copy(SrcFile, Length(ExcludeTrailingPathDelimiter(ExtractDir)) + 2, MaxInt);
        DestFile := TPath.Combine(AppDir, RelPath);
        if not IsPathUnderRoot(DestFile, AppDir) then
        begin
          ErrorMessage := 'Refused zip entry outside app dir: ' + DestFile;
          Exit(False);
        end;

        if TFile.Exists(DestFile) then
        begin
          BackupFile := TPath.Combine(BackupDir, RelPath);
          if not TFile.Exists(BackupFile) then
          begin
            ForceDirectories(TPath.GetDirectoryName(BackupFile));
            TFile.Copy(DestFile, BackupFile, True);
          end;
        end
        else
          CreatedFiles.Add(DestFile);

        ForceDirectories(TPath.GetDirectoryName(DestFile));
        TFile.Copy(SrcFile, DestFile, True);
      end;

      Result := True;
    except
      on E: Exception do
      begin
        ErrorMessage := 'Install failed: ' + E.Message;
        if not RestoreBackup(BackupDir, AppDir, CreatedFiles.ToArray, ErrorMessage) then
        begin
          ErrorMessage := 'Rollback failed: ' + ErrorMessage;
          Exit(False);
        end;
        Exit(False);
      end
    end;
  finally
    CreatedFiles.Free;
    try
      if TDirectory.Exists(ExtractDir) then
        TDirectory.Delete(ExtractDir, True);
    except
      // ignore cleanup errors
    end;
  end;
end;

function RestartApplication(const TargetExe: string;
  out ErrorMessage: string): Boolean;
var
  WorkDir: string;
begin
  Result := False;
  ErrorMessage := '';

  if not TFile.Exists(TargetExe) then
  begin
    ErrorMessage := 'Target executable not found for restart: ' + TargetExe;
    Exit(False);
  end;

  WorkDir := TPath.GetDirectoryName(TargetExe);
  Result := ShellExecute(0, 'open', PChar(TargetExe), nil, PChar(WorkDir), SW_SHOWNORMAL) > 32;
  if not Result then
    ErrorMessage := 'Failed to restart target executable';
end;

class function TUpdaterHelper.ParseArgs(out Options: THelperOptions;
  out ErrorMessage: string): Boolean;
var
  I: Integer;
  Args: TArray<string>;
begin
  SetLength(Args, ParamCount);
  for I := 1 to ParamCount do
    Args[I - 1] := ParamStr(I);
  Result := ParseArgs(Args, Options, ErrorMessage);
end;

class function TUpdaterHelper.ParseArgs(const Args: TArray<string>;
  out Options: THelperOptions; out ErrorMessage: string): Boolean;
var
  I: Integer;
  Key: string;
  Value: string;
begin
  FillChar(Options, SizeOf(Options), 0);
  Options.Mode := '';
  Options.PackagePath := '';
  Options.AppDir := '';
  Options.TargetExe := '';
  Options.Restart := False;
  Options.ExpectedSha256 := '';
  Options.WaitMs := 30000;
  ErrorMessage := '';

  I := 0;
  while I < Length(Args) do
  begin
    Key := Trim(Args[I]).ToLower;
    Value := '';
    if (I + 1 < Length(Args)) and not Args[I + 1].StartsWith('--') then
      Value := Trim(Args[I + 1]);

    if Key = '--mode' then
    begin
      Options.Mode := Value;
      Inc(I);
    end
    else if Key = '--package' then
    begin
      Options.PackagePath := Value;
      Inc(I);
    end
    else if Key = '--appdir' then
    begin
      Options.AppDir := Value;
      Inc(I);
    end
    else if Key = '--target' then
    begin
      Options.TargetExe := Value;
      Inc(I);
    end
    else if Key = '--restart' then
    begin
      Options.Restart := SameText(Value, '1') or SameText(Value, 'true');
      Inc(I);
    end
    else if Key = '--sha256' then
    begin
      Options.ExpectedSha256 := LowerCase(Value);
      Inc(I);
    end
    else if Key = '--wait-ms' then
    begin
      Options.WaitMs := Cardinal(StrToIntDef(Value, Integer(Options.WaitMs)));
      Inc(I);
    end;

    Inc(I);
  end;

  if not SameText(Options.Mode, 'install') then
  begin
    ErrorMessage := 'Unsupported mode. only "--mode install" is supported.';
    Exit(False);
  end;

  if Options.PackagePath = '' then
  begin
    ErrorMessage := 'Missing required argument: --package';
    Exit(False);
  end;

  if Options.AppDir = '' then
  begin
    ErrorMessage := 'Missing required argument: --appdir';
    Exit(False);
  end;

  if Options.TargetExe = '' then
    Options.TargetExe := ParamStr(0);

  if not TPath.IsPathRooted(Options.TargetExe) then
    Options.TargetExe := TPath.Combine(Options.AppDir, Options.TargetExe);

  Options.PackagePath := NormalizeFullPath(Options.PackagePath);
  Options.AppDir := NormalizeFullPath(Options.AppDir);
  Options.TargetExe := NormalizeFullPath(Options.TargetExe);

  if not TFile.Exists(Options.PackagePath) then
  begin
    ErrorMessage := 'Package not found: ' + Options.PackagePath;
    Exit(False);
  end;

  if not TDirectory.Exists(Options.AppDir) then
  begin
    ErrorMessage := 'Application directory not found: ' + Options.AppDir;
    Exit(False);
  end;

  if not IsPathUnderRoot(Options.TargetExe, Options.AppDir) then
  begin
    ErrorMessage := 'Target executable must be under appdir';
    Exit(False);
  end;

  Result := True;
end;

class function TUpdaterHelper.Execute(const Options: THelperOptions;
  out ErrorMessage: string): Boolean;
begin
  Result := False;
  ErrorMessage := '';
  LogLine('UpdaterHelper started');
  LogLine('mode=' + Options.Mode);
  LogLine('package=' + Options.PackagePath);
  LogLine('appdir=' + Options.AppDir);
  LogLine('target=' + Options.TargetExe);
  LogLine('restart=' + BoolToStr(Options.Restart, True));

  if not StopAppProcesses(Options.AppDir, Options.WaitMs, ErrorMessage) then
  begin
    LogLine('StopAppProcesses failed: ' + ErrorMessage);
    Exit(False);
  end;

  if not VerifyPackageHash(Options.PackagePath, Options.ExpectedSha256, ErrorMessage) then
  begin
    LogLine('VerifyPackageHash failed: ' + ErrorMessage);
    Exit(False);
  end;

  if not ApplyPackageWithRollback(Options.PackagePath, Options.AppDir, ErrorMessage) then
  begin
    LogLine('ApplyPackageWithRollback failed: ' + ErrorMessage);
    Exit(False);
  end;

  if Options.Restart then
  begin
    if not RestartApplication(Options.TargetExe, ErrorMessage) then
    begin
      LogLine('RestartApplication failed: ' + ErrorMessage);
      Exit(False);
    end;
  end;

  LogLine('UpdaterHelper completed successfully');
  Result := True;
end;

end.
