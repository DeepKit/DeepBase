{ ============================================================================
  DeepBase.AutoFix.SelfTerminator

  Handles fatal exceptions in AutoFix mode:
  1. Marks current scenario as fatal
  2. Writes exit-reason.json
  3. Halts with exit code 2
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
  System.IOUtils,
  System.Classes,
  Winapi.Windows,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.ScenarioRunner;

{ TAutoFixSelfTerminator }

class function TAutoFixSelfTerminator.IsFatal(E: Exception): Boolean;
begin
  Result := (E is EAccessViolation) or
            (E is EOutOfMemory) or
            (E is EExternalException);
end;

class procedure TAutoFixSelfTerminator.HandleFatal(E: Exception; AExceptAddr: Pointer);
var
  LModule: string;
  LRva: NativeUInt;
  LMsg, LJson, LPath: string;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  try
    // 1. Mark current scenario as fatal
    TAutoFixScenarioRunner.MarkCurrentFatal(E.ClassName);

    // 2. Write exit-reason.json
    TAutoFixErrorRecorder.ResolveModule(AExceptAddr, LModule, LRva);

    LMsg := Copy(E.Message, 1, 200);
    LMsg := LMsg.Replace('\', '\\').Replace('"', '\"').Replace(#10, '\n').Replace(#13, '\r');

    LJson :=
      '{' +
      '"run_id":"' + TAutoFixErrorRecorder.RunId + '",' +
      '"exit_code":2,' +
      '"reason":"fatal_exception",' +
      '"class":"' + E.ClassName + '",' +
      '"msg":"' + LMsg + '",' +
      '"module":"' + LModule + '",' +
      '"rva":"$' + IntToHex(LRva) + '",' +
      '"timestamp":"' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now) + '"' +
      '}';

    LPath := TPath.Combine(TAutoFixErrorRecorder.OutputDir, 'exit-reason.json');
    TFile.WriteAllText(LPath, LJson, TEncoding.UTF8);
  except
    OutputDebugString(PChar('AutoFix.SelfTerminator: write failed'));
  end;

  // 3. Halt
  Halt(2);
end;

end.
