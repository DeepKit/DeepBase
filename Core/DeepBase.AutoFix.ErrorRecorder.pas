{ ============================================================================
  DeepBase.AutoFix.ErrorRecorder

  Records runtime exceptions to JSONL for the AutoFix loop.
  Only active when --autofix-mode is on the command line.

  Captures:
    L1: Application.OnException (VCL main thread)
    L2: System.ExceptProc (global unhandled, all threads)
    L3: SafeRun wrapper (DeepBase managed threads)

  All handlers chain-call the previous handler after recording.

  Usage:
    TAutoFixErrorRecorder.Install;  // one line in .dpr

  See: docs/DeepBase.AutoFix-AI自动修复运行时错误方案.md
  ============================================================================ }

unit DeepBase.AutoFix.ErrorRecorder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Winapi.Windows;

type
  TExceptProcType = procedure(ExceptObject: TObject; ExceptAddr: Pointer);
  TAppExceptionEvent = procedure(Sender: TObject; E: Exception) of object;

  TAutoFixErrorRecorder = class
  private class var
    FInstalled: Boolean;
    FActive: Boolean;
    FRunId: string;
    FIteration: Integer;
    FOutputDir: string;
    FLock: TCriticalSection;
    FFileStream: TStreamWriter;
    FOldExceptProc: TExceptProcType;
  private
    class procedure ParseCommandLine;
    class procedure OpenLogFile;
    class procedure CloseLogFile;
    class function BuildDedupKey(const AClass, AContext, AModule: string;
      ARva: NativeUInt): string;
    class function EscapeJson(const S: string): string;
  public
    /// <summary>Install AutoFix error recording (core, cross-platform).
    /// Works for both VCL and FMX projects.
    /// VCL projects can additionally call HookVclApplication for L1 capture.</summary>
    class procedure Install;
    /// <summary>Record an exception. Public for adapters (VCL hook, SafeRun, etc).</summary>
    class procedure WriteRecord(E: Exception; AExceptAddr: Pointer;
      const AContext, AThread: string);
    /// <summary>Record an exception from SafeRun or thread wrapper.</summary>
    class procedure RecordFromSafeRun(E: Exception; const AContext: string);
    /// <summary>Resolve an address to module name + RVA.</summary>
    class function ResolveModule(AAddr: Pointer; out AModuleName: string;
      out ARva: NativeUInt): Boolean;
    /// <summary>True if autofix mode is active.</summary>
    class property Active: Boolean read FActive;
    /// <summary>Current run ID.</summary>
    class property RunId: string read FRunId;
    /// <summary>Current iteration number.</summary>
    class property Iteration: Integer read FIteration;
    /// <summary>Output directory for JSONL files.</summary>
    class property OutputDir: string read FOutputDir;
  end;

implementation

uses
  System.IOUtils;

const
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = $00000004;
  GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = $00000002;

function GetModuleHandleEx(dwFlags: DWORD; lpModuleName: LPCWSTR;
  out phModule: HMODULE): BOOL; stdcall; external kernel32 name 'GetModuleHandleExW';

threadvar
  GInHandler: Boolean;

{ Global ExceptProc handler — must be a standalone procedure }
procedure AutoFixGlobalExceptHandler(ExceptObject: TObject; ExceptAddr: Pointer);
begin
  if TAutoFixErrorRecorder.Active and (ExceptObject is Exception) then
    TAutoFixErrorRecorder.WriteRecord(
      Exception(ExceptObject), ExceptAddr, '',
      'thread-' + TThread.Current.ThreadID.ToString);

  // Chain old handler
  if Assigned(TAutoFixErrorRecorder.FOldExceptProc) then
    TAutoFixErrorRecorder.FOldExceptProc(ExceptObject, ExceptAddr);
end;

{ TAutoFixErrorRecorder }

class procedure TAutoFixErrorRecorder.Install;
begin
  if FInstalled then Exit;
  FInstalled := True;

  ParseCommandLine;
  if not FActive then Exit;

  FLock := TCriticalSection.Create;
  OpenLogFile;

  // L2: System.ExceptProc (chain old) — works for both VCL and FMX
  @FOldExceptProc := System.ExceptProc;
  System.ExceptProc := @AutoFixGlobalExceptHandler;
end;

class procedure TAutoFixErrorRecorder.ParseCommandLine;
begin
  FActive := False;
  FRunId := '';
  FIteration := 1;
  FOutputDir := '';

  for var I := 1 to ParamCount do
  begin
    var LParam := ParamStr(I);
    if SameText(LParam, '--autofix-mode') then
      FActive := True
    else if LParam.StartsWith('--autofix-run-id=', True) then
      FRunId := LParam.Substring(Length('--autofix-run-id='))
    else if LParam.StartsWith('--autofix-iteration=', True) then
      FIteration := StrToIntDef(LParam.Substring(Length('--autofix-iteration=')), 1)
    else if LParam.StartsWith('--autofix-output=', True) then
      FOutputDir := LParam.Substring(Length('--autofix-output='));
  end;

  if FActive and (FOutputDir = '') then
    FOutputDir := TPath.Combine(ExtractFilePath(ParamStr(0)), 'autofix-output');

  if FActive then
    ForceDirectories(FOutputDir);
end;

class procedure TAutoFixErrorRecorder.OpenLogFile;
begin
  var LPath := TPath.Combine(FOutputDir, 'runtime-errors.jsonl');
  FFileStream := TStreamWriter.Create(LPath, True, TEncoding.UTF8);
  FFileStream.AutoFlush := True;
end;

class procedure TAutoFixErrorRecorder.CloseLogFile;
begin
  FreeAndNil(FFileStream);
end;

class function TAutoFixErrorRecorder.ResolveModule(AAddr: Pointer;
  out AModuleName: string; out ARva: NativeUInt): Boolean;
var
  LModule: HMODULE;
  LBuf: array[0..MAX_PATH] of Char;
begin
  Result := False;
  AModuleName := '<unknown>';
  ARva := 0;

  if AAddr = nil then Exit;

  LModule := 0;
  if not GetModuleHandleEx(
    GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS or
    GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
    LPCWSTR(AAddr), LModule) then Exit;

  if LModule = 0 then Exit;

  GetModuleFileName(LModule, LBuf, MAX_PATH);
  AModuleName := ExtractFileName(LBuf);
  ARva := NativeUInt(AAddr) - NativeUInt(LModule);
  Result := True;
end;

class function TAutoFixErrorRecorder.BuildDedupKey(const AClass, AContext,
  AModule: string; ARva: NativeUInt): string;
begin
  Result := AClass + '|' + AContext + '|' + AModule + ':$' + IntToHex(ARva);
end;

class function TAutoFixErrorRecorder.EscapeJson(const S: string): string;
begin
  Result := S;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#13, '\r');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#9, '\t');
end;

class procedure TAutoFixErrorRecorder.WriteRecord(E: Exception;
  AExceptAddr: Pointer; const AContext, AThread: string);
var
  LModule: string;
  LRva: NativeUInt;
  LLevel, LDedupKey, LTs, LJson: string;
begin
  if GInHandler then Exit;
  GInHandler := True;
  try
    try
      ResolveModule(AExceptAddr, LModule, LRva);

      if (E is EAccessViolation) or (E is EOutOfMemory) or (E is EExternalException) then
        LLevel := 'fatal'
      else
        LLevel := 'error';

      LDedupKey := BuildDedupKey(E.ClassName, AContext, LModule, LRva);
      LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);

      LJson :=
        '{"run_id":"' + EscapeJson(FRunId) + '"' +
        ',"ts":"' + LTs + '"' +
        ',"iteration":' + IntToStr(FIteration) +
        ',"level":"' + LLevel + '"' +
        ',"class":"' + EscapeJson(E.ClassName) + '"' +
        ',"msg":"' + EscapeJson(Copy(E.Message, 1, 500)) + '"' +
        ',"module":"' + EscapeJson(LModule) + '"' +
        ',"rva":"$' + IntToHex(LRva) + '"' +
        ',"context":"' + EscapeJson(AContext) + '"' +
        ',"thread":"' + EscapeJson(AThread) + '"' +
        ',"dedup_key":"' + EscapeJson(LDedupKey) + '"' +
        '}';

      FLock.Enter;
      try
        if FFileStream <> nil then
          FFileStream.WriteLine(LJson);
      finally
        FLock.Leave;
      end;
    except
      OutputDebugString(PChar('AutoFix.ErrorRecorder: write failed'));
    end;
  finally
    GInHandler := False;
  end;
end;

class procedure TAutoFixErrorRecorder.RecordFromSafeRun(E: Exception;
  const AContext: string);
begin
  if FActive then
    WriteRecord(E, ExceptAddr, AContext, 'main');
end;

initialization

finalization
  TAutoFixErrorRecorder.CloseLogFile;
  FreeAndNil(TAutoFixErrorRecorder.FLock);

end.
