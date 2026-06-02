{ ============================================================================
  DeepBase.AutoFix.SelfTerminator

  Handles fatal exceptions in AutoFix mode:
  1. Marks current scenario as fatal
  2. Writes exit-reason.json (with stack array, total_errors, scenario)
  3. Halts with exit code 2

  See: design v2.0 §3.2
  ============================================================================ }

unit DeepBase.AutoFix.SelfTerminator;

interface

uses
  System.SysUtils;

type
  TAutoFixSelfTerminator = class
  public
    class procedure HandleFatal(E: Exception; AExceptAddr: Pointer);
    class function IsFatal(E: Exception): Boolean;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  Winapi.Windows,
  DeepBase.AutoFix.StackWalker,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.ScenarioRunner;

function EscapeJson(const S: string): string;
begin
  Result := S;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#13, '\r');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#9, '\t');
end;

function FormatHex(AValue: NativeUInt): string;
begin
  Result := '$' + IntToHex(AValue, SizeOf(NativeUInt) * 2);
end;

function StackToJson(const AStack: TArray<TStackFrame>): string;
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

{ TAutoFixSelfTerminator }

class function TAutoFixSelfTerminator.IsFatal(E: Exception): Boolean;
begin
  {$WARN SYMBOL_DEPRECATED OFF}
  Result := (E is EAccessViolation) or
            (E is EOutOfMemory) or
            (E is EStackOverflow) or
            (E is EExternalException);
  {$WARN SYMBOL_DEPRECATED DEFAULT}
end;

class procedure TAutoFixSelfTerminator.HandleFatal(E: Exception;
  AExceptAddr: Pointer);
var
  LModuleName: string;
  LModuleBase, LRva: NativeUInt;
  LStack: TArray<TStackFrame>;
  LStackTruncated: Boolean;
  LClassName, LMsg, LScenario, LStackJson, LJson, LPath: string;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  try
    LClassName := E.ClassName;
  except
    LClassName := '<unavailable>';
  end;

  // Mark current scenario as fatal first (cheap, in-memory only)
  try
    TAutoFixScenarioRunner.MarkCurrentFatal(LClassName);
  except
    OutputDebugString(PChar('AutoFix.SelfTerminator: mark scenario failed'));
  end;

  // Resolve fault address
  LModuleName := '<unknown>';
  LModuleBase := 0;
  LRva := 0;
  try
    DeepBase.AutoFix.StackWalker.ResolveAddr(
      AExceptAddr, LModuleName, LModuleBase, LRva);
  except
    // keep defaults
  end;

  // Capture stack defensively (might fault again on stack overflow)
  LStack := nil;
  LStackTruncated := False;
  try
    LStack := DeepBase.AutoFix.StackWalker.CaptureStack(2, 20, LStackTruncated);
  except
    LStack := nil;
    LStackTruncated := False;
  end;

  try
    LMsg := EscapeJson(Copy(E.Message, 1, 200));
  except
    LMsg := '<unavailable>';
  end;

  try
    LScenario := TAutoFixScenarioRunner.CurrentScenario;
  except
    LScenario := '<unavailable>';
  end;

  try
    LStackJson := StackToJson(LStack);
  except
    LStackJson := '[]';
  end;

  // Build JSON payload (single shot write)
  var LBuilder := TStringBuilder.Create;
  try
    LBuilder
      .Append('{"run_id":"').Append(EscapeJson(TAutoFixErrorRecorder.RunId)).Append('"')
      .Append(',"exit_code":2')
      .Append(',"reason":"fatal_exception"')
      .Append(',"fatal_class":"').Append(EscapeJson(LClassName)).Append('"')
      .Append(',"fatal_msg":"').Append(LMsg).Append('"')
      .Append(',"module_name":"').Append(EscapeJson(LModuleName)).Append('"')
      .Append(',"module_base":"').Append(FormatHex(LModuleBase)).Append('"')
      .Append(',"rva":"').Append(FormatHex(LRva)).Append('"')
      .Append(',"stack":').Append(LStackJson)
      .Append(',"stack_truncated":')
        .Append(IfThen(LStackTruncated, 'true', 'false'))
      .Append(',"total_errors":').Append(TAutoFixErrorRecorder.TotalErrors)
      .Append(',"scenario":"')
        .Append(EscapeJson(LScenario)).Append('"')
      .Append(',"timestamp":"')
        .Append(FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now)).Append('"')
      .Append('}');
    LJson := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;

  try
    LPath := TPath.Combine(TAutoFixErrorRecorder.OutputDir, 'exit-reason.json');
    TFile.WriteAllText(LPath, LJson, TEncoding.UTF8);
  except
    OutputDebugString(PChar('AutoFix.SelfTerminator: write failed'));
  end;

  Halt(2);
end;

end.
