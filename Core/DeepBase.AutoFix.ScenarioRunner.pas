{ ============================================================================
  DeepBase.AutoFix.ScenarioRunner

  Executes registered scenarios in AutoFix mode and writes incremental
  results to scenario-results.jsonl.

  Usage:
    // Register in MainForm
    AutoFix.RegisterScenario('scan', procedure begin Controller.RunScan end);

    // Framework calls Run automatically when --autofix-mode is active
  ============================================================================ }

unit DeepBase.AutoFix.ScenarioRunner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  TScenarioProc = reference to procedure;

  TAutoFixScenarioRunner = class
  private class var
    FScenarios: TDictionary<string, TScenarioProc>;
    FRequestedScenarios: TArray<string>;
    FOutputDir: string;
    FRunId: string;
    FCurrentScenario: string;
  private
    class procedure ParseCommandLine;
    class procedure WriteStatus(const AName, AStatus: string;
      ADurationMs: Int64 = 0; const AExtra: string = '');
    class function EscapeJson(const S: string): string;
  public
    class procedure Initialize;
    /// <summary>Register a named scenario.</summary>
    class procedure RegisterScenario(const AName: string; AProc: TScenarioProc);
    /// <summary>Execute all requested scenarios. Call after form is shown.</summary>
    class procedure Run;
    /// <summary>Mark current scenario as fatal (called by SelfTerminator).</summary>
    class procedure MarkCurrentFatal(const AClass: string);
    /// <summary>Name of the currently executing scenario (empty if none).</summary>
    class property CurrentScenario: string read FCurrentScenario;
  end;

/// <summary>Shortcut to register a scenario.</summary>
procedure AutoFixRegisterScenario(const AName: string; AProc: TScenarioProc);

implementation

uses
  System.IOUtils,
  System.Diagnostics,
  DeepBase.AutoFix.ErrorRecorder;

{ TAutoFixScenarioRunner }

class procedure TAutoFixScenarioRunner.Initialize;
begin
  FScenarios := TDictionary<string, TScenarioProc>.Create;
  ParseCommandLine;
end;

class procedure TAutoFixScenarioRunner.ParseCommandLine;
begin
  FOutputDir := TAutoFixErrorRecorder.OutputDir;
  FRunId := TAutoFixErrorRecorder.RunId;

  for var I := 1 to ParamCount do
  begin
    var LParam := ParamStr(I);
    if LParam.StartsWith('--autofix-scenario=', True) then
    begin
      var LValue := LParam.Substring(Length('--autofix-scenario='));
      FRequestedScenarios := LValue.Split([',']);
    end;
  end;
end;

class procedure TAutoFixScenarioRunner.RegisterScenario(const AName: string;
  AProc: TScenarioProc);
begin
  if FScenarios = nil then
    Initialize;
  FScenarios.AddOrSetValue(AName, AProc);
end;

class procedure TAutoFixScenarioRunner.Run;
begin
  if not TAutoFixErrorRecorder.Active then Exit;
  if Length(FRequestedScenarios) = 0 then Exit;

  for var LName in FRequestedScenarios do
  begin
    FCurrentScenario := LName;

    if not FScenarios.ContainsKey(LName) then
    begin
      WriteStatus(LName, 'fail', 0, ',"error":"scenario not registered"');
      Continue;
    end;

    WriteStatus(LName, 'running');

    var LSw := TStopwatch.StartNew;
    try
      FScenarios[LName]();
      LSw.Stop;
      WriteStatus(LName, 'pass', LSw.ElapsedMilliseconds);
    except
      on E: Exception do
      begin
        LSw.Stop;
        // ErrorRecorder already captured it; just mark scenario status
        WriteStatus(LName, 'fail', LSw.ElapsedMilliseconds,
          ',"error_class":"' + EscapeJson(E.ClassName) + '"');
        // Don't re-raise; continue to next scenario unless fatal
        if (E is EAccessViolation) or (E is EOutOfMemory) or (E is EExternalException) then
        begin
          // SelfTerminator will handle fatal; mark remaining as skipped
          FCurrentScenario := '';
          Break;
        end;
      end;
    end;

    FCurrentScenario := '';
  end;

  // All scenarios done — exit cleanly
  if TAutoFixErrorRecorder.Active then
    Halt(0);
end;

class procedure TAutoFixScenarioRunner.MarkCurrentFatal(const AClass: string);
begin
  if FCurrentScenario <> '' then
    WriteStatus(FCurrentScenario, 'fatal', 0,
      ',"fatal_class":"' + EscapeJson(AClass) + '"');
end;

class procedure TAutoFixScenarioRunner.WriteStatus(const AName, AStatus: string;
  ADurationMs: Int64; const AExtra: string);
begin
  if FOutputDir = '' then Exit;

  var LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);
  var LJson :=
    '{"run_id":"' + EscapeJson(FRunId) + '"' +
    ',"name":"' + EscapeJson(AName) + '"' +
    ',"status":"' + AStatus + '"' +
    ',"ts":"' + LTs + '"';

  if ADurationMs > 0 then
    LJson := LJson + ',"duration_ms":' + IntToStr(ADurationMs);

  LJson := LJson + AExtra + '}';

  var LPath := TPath.Combine(FOutputDir, 'scenario-results.jsonl');
  // Append with flush
  var LFile := TStreamWriter.Create(LPath, True, TEncoding.UTF8);
  try
    LFile.WriteLine(LJson);
    LFile.Flush;
  finally
    LFile.Free;
  end;
end;

class function TAutoFixScenarioRunner.EscapeJson(const S: string): string;
begin
  Result := S.Replace('\', '\\').Replace('"', '\"').Replace(#10, '\n').Replace(#13, '\r');
end;

procedure AutoFixRegisterScenario(const AName: string; AProc: TScenarioProc);
begin
  TAutoFixScenarioRunner.RegisterScenario(AName, AProc);
end;

initialization
  TAutoFixScenarioRunner.Initialize;

finalization
  FreeAndNil(TAutoFixScenarioRunner.FScenarios);

end.
