{ ============================================================================
  DeepBase.AutoFix.ErrorRecorder

  Records runtime exceptions to JSONL for the AutoFix loop.
  Only active when --autofix-mode is on the command line.

  Captures:
    L1: Application.OnException (VCL main thread)  -- via DeepBase.AutoFix.VclHook
    L2: System.ExceptProc (global unhandled, all threads)
    L3: SafeRun wrapper (DeepBase managed threads) -- via RecordFromSafeRun

  All handlers chain-call the previous handler after recording.

  Usage:
    TAutoFixErrorRecorder.Install;  // one line in .dpr (or AutoFix.Install facade)

  See: design v2.0 §3.1 / §4.2
  ============================================================================ }

unit DeepBase.AutoFix.ErrorRecorder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  Winapi.Windows,
  DeepBase.AutoFix.StackWalker;

type
  TExceptProcType = procedure(ExceptObject: TObject; ExceptAddr: Pointer);

  TAutoFixErrorRecorder = class
  private class var
    FInstalled: Boolean;
    FActive: Boolean;
    FRunId: string;
    FIteration: Integer;
    FOutputDir: string;
    FCurrentScenario: string;
    FTotalErrors: Integer;
    FActiveWriters: Integer;
    FShuttingDown: Boolean;
    FLock: TCriticalSection;
    FFileStream: TStreamWriter;
    FOldExceptProc: TExceptProcType;
  private
    class procedure ParseCommandLine;
    class procedure OpenLogFile;
    class procedure CloseLogFile;
    class function BuildDedupKey(const AClass, AModuleName: string;
      ARva: NativeUInt; const AScenario: string): string;
    class function EscapeJson(const S: string): string;
    class function FormatHex(AValue: NativeUInt): string;
    class function GetCurrentScenarioSafe: string; static;
    class function NewRunId: string;
    class function StackToJson(const AStack: TArray<TStackFrame>): string;
  public
    /// <summary>Install AutoFix error recording (core, cross-platform).
    /// Works for both VCL and FMX projects.
    /// VCL projects can additionally call TAutoFixVclHook.Install for L1 capture.</summary>
    class procedure Install;
    /// <summary>Record an exception. Public for adapters (VCL hook, SafeRun, etc).</summary>
    class procedure WriteRecord(E: Exception; AExceptAddr: Pointer;
      const AContext, AThread: string;
      const AParams: string = ''; const AState: string = '');
    /// <summary>Record an exception from SafeRun or thread wrapper.</summary>
    class procedure RecordFromSafeRun(E: Exception; const AContext: string);
    /// <summary>Resolve an address to module name + base + RVA.</summary>
    class function ResolveModule(AAddr: Pointer; out AModuleName: string;
      out AModuleBase: NativeUInt; out ARva: NativeUInt): Boolean;
    /// <summary>Internal hook used by AutoFixGlobalExceptHandler. Public so
    /// the handler procedure (file scope) can chain the previous handler.</summary>
    class property OldExceptProc: TExceptProcType read FOldExceptProc;
    /// <summary>True if autofix mode is active.</summary>
    class property Active: Boolean read FActive;
    /// <summary>Current run ID (UUID v4 string, lower-case, no braces).</summary>
    class property RunId: string read FRunId;
    /// <summary>Current iteration number.</summary>
    class property Iteration: Integer read FIteration;
    /// <summary>Output directory for JSONL files.</summary>
    class property OutputDir: string read FOutputDir;
    /// <summary>Total number of errors recorded since Install (thread-safe).</summary>
    class property TotalErrors: Integer read FTotalErrors;
    /// <summary>Set the currently executing scenario under the recorder lock.</summary>
    class procedure SetCurrentScenario(const AName: string);
    /// <summary>Name of the currently executing scenario. Thread-safe snapshot.</summary>
    class property CurrentScenario: string read GetCurrentScenarioSafe;
    /// <summary>Test scaffold: forces autofix mode active with the supplied
    /// run_id / output dir / iteration, opens runtime-errors.jsonl, but does
    /// NOT replace System.ExceptProc. Pair with ResetForTest in TearDown.
    /// Production callers must use Install instead.</summary>
    class procedure ActivateForTest(const ARunId, AOutputDir: string;
      AIteration: Integer = 1);
    /// <summary>Test scaffold: closes the log file and resets every class-
    /// level field touched by ActivateForTest / Install. Safe to call when
    /// nothing was activated.</summary>
    class procedure ResetForTest;
  end;

implementation

uses
  System.IOUtils, System.StrUtils,
  DeepBase.AutoFix.SelfTerminator;

threadvar
  GInHandler: Boolean;

{ Global ExceptProc handler -- must be a standalone procedure }
procedure AutoFixGlobalExceptHandler(ExceptObject: TObject; ExceptAddr: Pointer);
var
  LThread: string;
begin
  if TAutoFixErrorRecorder.Active and (ExceptObject is Exception) then
  begin
    if (TThread.CurrentThread = nil) or
       (TThread.CurrentThread.ThreadID = MainThreadID) then
      LThread := 'main'
    else
      LThread := 'thread-' + TThread.CurrentThread.ThreadID.ToString;

    TAutoFixErrorRecorder.WriteRecord(
      Exception(ExceptObject), ExceptAddr, '', LThread);

    if TAutoFixSelfTerminator.IsFatal(Exception(ExceptObject)) then
      TAutoFixSelfTerminator.HandleFatal(Exception(ExceptObject), ExceptAddr);
  end;

  // Chain old handler (only reached for non-fatal; HandleFatal calls Halt(2))
  if Assigned(TAutoFixErrorRecorder.OldExceptProc) then
    TAutoFixErrorRecorder.OldExceptProc(ExceptObject, ExceptAddr);
end;

{ TAutoFixErrorRecorder }

class procedure TAutoFixErrorRecorder.Install;
begin
  if FInstalled then Exit;
  FInstalled := True;

  ParseCommandLine;
  if not FActive then Exit;

  if FRunId = '' then
    FRunId := NewRunId;

  FShuttingDown := False;
  FActiveWriters := 0;
  FLock := TCriticalSection.Create;
  OpenLogFile;

  // L2: System.ExceptProc (chain old) -- works for both VCL and FMX
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
  FShuttingDown := True;
  for var I := 1 to 50 do
  begin
    if FActiveWriters <= 0 then Break;
    Sleep(10);
  end;
  if FLock <> nil then FLock.Enter;
  try
    FreeAndNil(FFileStream);
  finally
    if FLock <> nil then FLock.Leave;
  end;
end;

class function TAutoFixErrorRecorder.NewRunId: string;
var
  LGuid: TGUID;
begin
  if CreateGUID(LGuid) <> S_OK then
    Exit('00000000-0000-4000-8000-000000000000');
  Result := GUIDToString(LGuid).Trim(['{', '}']).ToLower;
end;

class function TAutoFixErrorRecorder.FormatHex(AValue: NativeUInt): string;
begin
  Result := '$' + IntToHex(AValue, SizeOf(NativeUInt) * 2);
end;

class function TAutoFixErrorRecorder.GetCurrentScenarioSafe: string;
begin
  if FLock <> nil then FLock.Enter;
  try
    Result := FCurrentScenario;
  finally
    if FLock <> nil then FLock.Leave;
  end;
end;

class procedure TAutoFixErrorRecorder.SetCurrentScenario(const AName: string);
begin
  if FLock <> nil then FLock.Enter;
  try
    FCurrentScenario := AName;
  finally
    if FLock <> nil then FLock.Leave;
  end;
end;

class function TAutoFixErrorRecorder.ResolveModule(AAddr: Pointer;
  out AModuleName: string; out AModuleBase: NativeUInt;
  out ARva: NativeUInt): Boolean;
begin
  Result := DeepBase.AutoFix.StackWalker.ResolveAddr(
    AAddr, AModuleName, AModuleBase, ARva);
end;

class function TAutoFixErrorRecorder.BuildDedupKey(const AClass,
  AModuleName: string; ARva: NativeUInt; const AScenario: string): string;
begin
  Result := AClass + '|' + AModuleName + ':' + FormatHex(ARva) + '|' + AScenario;
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

class function TAutoFixErrorRecorder.StackToJson(
  const AStack: TArray<TStackFrame>): string;
begin
  if Length(AStack) = 0 then Exit('[]');

  var LBuilder := TStringBuilder.Create;
  try
    LBuilder.Append('[');
    for var I := 0 to High(AStack) do
    begin
      if I > 0 then LBuilder.Append(',');
      LBuilder
        .Append('{"module_name":"').Append(EscapeJson(AStack[I].ModuleName))
        .Append('","module_base":"').Append(FormatHex(AStack[I].ModuleBase))
        .Append('","rva":"').Append(FormatHex(AStack[I].Rva))
        .Append('"}');
    end;
    LBuilder.Append(']');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

class procedure TAutoFixErrorRecorder.WriteRecord(E: Exception;
  AExceptAddr: Pointer; const AContext, AThread: string;
  const AParams: string; const AState: string);
var
  LModuleName: string;
  LModuleBase, LRva: NativeUInt;
  LStack: TArray<TStackFrame>;
  LStackTruncated: Boolean;
begin
  if GInHandler or FShuttingDown then Exit;
  TInterlocked.Increment(FActiveWriters);
  GInHandler := True;
  try
    try
      ResolveModule(AExceptAddr, LModuleName, LModuleBase, LRva);

      LStackTruncated := False;
      LStack := nil;
      try
        // Skip 2: the handler proc + this method itself.
        LStack := DeepBase.AutoFix.StackWalker.CaptureStack(2, 20, LStackTruncated);
      except
        LStack := nil;
        LStackTruncated := False;
      end;

      var LLevel: string :=
        {$WARN SYMBOL_DEPRECATED OFF}
        if (E is EAccessViolation) or (E is EOutOfMemory) or
           (E is EStackOverflow) or (E is EExternalException)
        then 'fatal' else 'error';
        {$WARN SYMBOL_DEPRECATED DEFAULT}

      var LScenario: string;
      LScenario := GetCurrentScenarioSafe;
      var LDedupKey := BuildDedupKey(E.ClassName, LModuleName, LRva, LScenario);
      var LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);

      var LBuilder := TStringBuilder.Create;
      try
        LBuilder
          .Append('{"run_id":"').Append(EscapeJson(FRunId)).Append('"')
          .Append(',"iteration":').Append(FIteration)
          .Append(',"ts":"').Append(LTs).Append('"')
          .Append(',"level":"').Append(LLevel).Append('"')
          .Append(',"class":"').Append(EscapeJson(E.ClassName)).Append('"')
          .Append(',"msg":"').Append(EscapeJson(Copy(E.Message, 1, 500))).Append('"')
          .Append(',"module_name":"').Append(EscapeJson(LModuleName)).Append('"')
          .Append(',"module_base":"').Append(FormatHex(LModuleBase)).Append('"')
          .Append(',"rva":"').Append(FormatHex(LRva)).Append('"')
          .Append(',"stack":').Append(StackToJson(LStack))
          .Append(',"stack_truncated":')
            .Append(IfThen(LStackTruncated, 'true', 'false'))
          .Append(',"context":"').Append(EscapeJson(AContext)).Append('"')
          .Append(',"params":"').Append(EscapeJson(AParams)).Append('"')
          .Append(',"state":"').Append(EscapeJson(AState)).Append('"')
          .Append(',"thread":"').Append(EscapeJson(AThread)).Append('"')
          .Append(',"scenario":"').Append(EscapeJson(LScenario)).Append('"')
          .Append(',"dedup_key":"').Append(EscapeJson(LDedupKey)).Append('"')
          .Append('}');

        var LJson := LBuilder.ToString;

        FLock.Enter;
        try
          if FFileStream <> nil then
            FFileStream.WriteLine(LJson);
        finally
          FLock.Leave;
        end;

        TInterlocked.Increment(FTotalErrors);
      finally
        LBuilder.Free;
      end;
    except
      OutputDebugString(PChar('AutoFix.ErrorRecorder: write failed'));
    end;
  finally
    GInHandler := False;
    TInterlocked.Decrement(FActiveWriters);
  end;
end;

class procedure TAutoFixErrorRecorder.RecordFromSafeRun(E: Exception;
  const AContext: string);
var
  LThread: string;
begin
  if not FActive then Exit;
  if (TThread.CurrentThread = nil) or
     (TThread.CurrentThread.ThreadID = MainThreadID) then
    LThread := 'main'
  else
    LThread := 'thread-' + TThread.CurrentThread.ThreadID.ToString;
  WriteRecord(E, ExceptAddr, AContext, LThread);
end;

class procedure TAutoFixErrorRecorder.ActivateForTest(const ARunId,
  AOutputDir: string; AIteration: Integer);
begin
  // Tear down any prior test or production state first so the file lock
  // is released and the log handle is rebound to AOutputDir.
  ResetForTest;

  FInstalled := True;
  FActive := True;
  FRunId := if ARunId = '' then NewRunId else ARunId;
  FOutputDir := AOutputDir;
  FIteration := AIteration;
  FCurrentScenario := '';
  FTotalErrors := 0;
  FActiveWriters := 0;
  FShuttingDown := False;

  if FLock = nil then
    FLock := TCriticalSection.Create;

  if FOutputDir <> '' then
  begin
    ForceDirectories(FOutputDir);
    OpenLogFile;
  end;
end;

class procedure TAutoFixErrorRecorder.ResetForTest;
begin
  CloseLogFile;
  FInstalled := False;
  FActive := False;
  FRunId := '';
  FOutputDir := '';
  FIteration := 1;
  FCurrentScenario := '';
  FTotalErrors := 0;
  FActiveWriters := 0;
  FShuttingDown := False;
  // Note: System.ExceptProc is intentionally not restored here. Tests that
  // exercise Install do so against a fresh class state and the global hook
  // is re-chained idempotently via FInstalled.
end;

initialization

finalization
  TAutoFixErrorRecorder.CloseLogFile;
  FreeAndNil(TAutoFixErrorRecorder.FLock);

end.
