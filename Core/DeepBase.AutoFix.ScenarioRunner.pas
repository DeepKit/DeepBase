{ ============================================================================
  DeepBase.AutoFix.ScenarioRunner

  Executes registered scenarios in AutoFix mode and writes incremental
  results to scenario-results.jsonl.

  Usage:
    AutoFix.RegisterScenario('scan', procedure begin Controller.RunScan end);
    // Framework calls Run after the shell is shown (via AutoFix.NotifyShellShown)

  See: design v2.0 §3.4
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
    FInitialized: Boolean;
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
    class procedure SetCurrentScenario(const AName: string);
  public
    class procedure Initialize;
    /// <summary>Register a named scenario.</summary>
    class procedure RegisterScenario(const AName: string; AProc: TScenarioProc);
    /// <summary>Execute all requested scenarios. Halts with code 0 (no errors)
    /// or 1 (non-fatal errors recorded) when finished.</summary>
    class procedure Run;
    /// <summary>Mark current scenario as fatal (called by SelfTerminator).</summary>
    class procedure MarkCurrentFatal(const AClass: string);
    /// <summary>Name of the currently executing scenario (empty if none).</summary>
    class property CurrentScenario: string read FCurrentScenario;
    /// <summary>Test scaffold: clears registered scenarios, sets the requested
    /// list, and rebinds output dir / run_id from ErrorRecorder. Pair with
    /// RunForTest in property tests.</summary>
    class procedure ResetForTest(const ARequestedScenarios: TArray<string>);
    /// <summary>Test scaffold: same iteration semantics as Run but never calls
    /// Halt, so test runners survive. Returns the array of scenario names that
    /// were actually invoked, in order.</summary>
    class function RunForTest: TArray<string>;
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
  if FInitialized then Exit;
  FInitialized := True;
  if FScenarios = nil then
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
  if not FInitialized then
    Initialize;
  FScenarios.AddOrSetValue(AName, AProc);
end;

class procedure TAutoFixScenarioRunner.SetCurrentScenario(const AName: string);
begin
  FCurrentScenario := AName;
  TAutoFixErrorRecorder.CurrentScenario := AName;
end;

class procedure TAutoFixScenarioRunner.Run;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  if Length(FRequestedScenarios) > 0 then
  begin
    for var LName in FRequestedScenarios do
    begin
      SetCurrentScenario(LName);

      if not FScenarios.ContainsKey(LName) then
      begin
        WriteStatus(LName, 'fail', 0, ',"error_class":"NotRegistered"' +
          ',"error_msg":"scenario not registered"');
        Continue;
      end;

      WriteStatus(LName, 'running');

      var LSw := TStopwatch.StartNew;
      var LFatal := False;
      try
        FScenarios[LName]();
        LSw.Stop;
        WriteStatus(LName, 'pass', LSw.ElapsedMilliseconds);
      except
        on E: Exception do
        begin
          LSw.Stop;
          // ErrorRecorder already captured it via L1/L2 hooks; mark scenario
          var LExtra :=
            ',"error_class":"' + EscapeJson(E.ClassName) + '"' +
            ',"error_msg":"' + EscapeJson(Copy(E.Message, 1, 200)) + '"';
          WriteStatus(LName, 'fail', LSw.ElapsedMilliseconds, LExtra);

          // Don't re-raise; continue to next scenario unless fatal
          if (E is EAccessViolation) or (E is EOutOfMemory) or
             (E is EStackOverflow) or (E is EExternalException) then
          begin
            LFatal := True;
            // SelfTerminator will halt(2). If it doesn't (e.g. not installed),
            // we still bail out of the loop here.
          end;
        end;
      end;

      SetCurrentScenario('');
      if LFatal then Break;
    end;
  end;

  // All requested scenarios done -- exit with 0 (clean) or 1 (errors recorded)
  if TAutoFixErrorRecorder.Active then
  begin
    var LCode :=
      if TAutoFixErrorRecorder.TotalErrors > 0 then 1 else 0;
    Halt(LCode);
  end;
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
  if FOutputDir = '' then
    FOutputDir := TAutoFixErrorRecorder.OutputDir;
  if FRunId = '' then
    FRunId := TAutoFixErrorRecorder.RunId;
  if FOutputDir = '' then Exit;

  var LTs := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now);
  var LBuilder := TStringBuilder.Create;
  try
    LBuilder
      .Append('{"run_id":"').Append(EscapeJson(FRunId)).Append('"')
      .Append(',"name":"').Append(EscapeJson(AName)).Append('"')
      .Append(',"status":"').Append(AStatus).Append('"')
      .Append(',"ts":"').Append(LTs).Append('"');

    if ADurationMs > 0 then
      LBuilder.Append(',"duration_ms":').Append(ADurationMs);

    LBuilder.Append(AExtra).Append('}');

    var LJson := LBuilder.ToString;
    var LPath := TPath.Combine(FOutputDir, 'scenario-results.jsonl');
    var LFile := TStreamWriter.Create(LPath, True, TEncoding.UTF8);
    try
      LFile.WriteLine(LJson);
      LFile.Flush;
    finally
      LFile.Free;
    end;
  finally
    LBuilder.Free;
  end;
end;

class function TAutoFixScenarioRunner.EscapeJson(const S: string): string;
begin
  Result := S;
  Result := Result.Replace('\', '\\');
  Result := Result.Replace('"', '\"');
  Result := Result.Replace(#13, '\r');
  Result := Result.Replace(#10, '\n');
  Result := Result.Replace(#9, '\t');
end;

procedure AutoFixRegisterScenario(const AName: string; AProc: TScenarioProc);
begin
  TAutoFixScenarioRunner.RegisterScenario(AName, AProc);
end;

class procedure TAutoFixScenarioRunner.ResetForTest(
  const ARequestedScenarios: TArray<string>);
begin
  if FScenarios = nil then
    FScenarios := TDictionary<string, TScenarioProc>.Create
  else
    FScenarios.Clear;
  FRequestedScenarios := ARequestedScenarios;
  FCurrentScenario := '';
  FOutputDir := TAutoFixErrorRecorder.OutputDir;
  FRunId := TAutoFixErrorRecorder.RunId;
  FInitialized := True;
end;

class function TAutoFixScenarioRunner.RunForTest: TArray<string>;
begin
  Result := nil;
  if not TAutoFixErrorRecorder.Active then Exit;

  for var LName in FRequestedScenarios do
  begin
    SetCurrentScenario(LName);
    Result := Result + [LName];

    if not FScenarios.ContainsKey(LName) then
    begin
      WriteStatus(LName, 'fail', 0, ',"error_class":"NotRegistered"' +
        ',"error_msg":"scenario not registered"');
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
        var LExtra :=
          ',"error_class":"' + EscapeJson(E.ClassName) + '"' +
          ',"error_msg":"' + EscapeJson(Copy(E.Message, 1, 200)) + '"';
        WriteStatus(LName, 'fail', LSw.ElapsedMilliseconds, LExtra);
      end;
    end;

    SetCurrentScenario('');
  end;
end;

initialization
  TAutoFixScenarioRunner.Initialize;

finalization
  FreeAndNil(TAutoFixScenarioRunner.FScenarios);

end.
