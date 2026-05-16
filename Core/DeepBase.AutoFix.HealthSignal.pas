{ ============================================================================
  DeepBase.AutoFix.HealthSignal

  Writes health-signal.json after the application is fully initialized.
  The external runner polls this file to confirm the EXE started successfully.

  Usage:
    Call TAutoFixHealthSignal.Emit after form is shown (e.g. AfterShellShown).
  ============================================================================ }

unit DeepBase.AutoFix.HealthSignal;

interface

uses
  System.SysUtils;

type
  TAutoFixHealthSignal = class
  public
    /// <summary>Write health-signal.json. Call once after app is ready.</summary>
    class procedure Emit;
  end;

implementation

uses
  System.IOUtils,
  System.Classes,
  Winapi.Windows,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.ScenarioRunner;

{ TAutoFixHealthSignal }

class procedure TAutoFixHealthSignal.Emit;
begin
  if not TAutoFixErrorRecorder.Active then Exit;

  var LScenarios := '';
  // Build scenario list from command line
  for var I := 1 to ParamCount do
  begin
    var LParam := ParamStr(I);
    if LParam.StartsWith('--autofix-scenario=', True) then
    begin
      var LNames := LParam.Substring(Length('--autofix-scenario=')).Split([',']);
      for var J := 0 to High(LNames) do
      begin
        if J > 0 then LScenarios := LScenarios + ',';
        LScenarios := LScenarios + '"' + LNames[J] + '"';
      end;
    end;
  end;

  var LJson :=
    '{' +
    '"run_id":"' + TAutoFixErrorRecorder.RunId + '",' +
    '"ready":true,' +
    '"pid":' + IntToStr(GetCurrentProcessId) + ',' +
    '"timestamp":"' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"+08:00"', Now) + '",' +
    '"autofix_mode":true,' +
    '"scenarios":[' + LScenarios + ']' +
    '}';

  var LPath := TPath.Combine(TAutoFixErrorRecorder.OutputDir, 'health-signal.json');
  TFile.WriteAllText(LPath, LJson, TEncoding.UTF8);
end;

end.
