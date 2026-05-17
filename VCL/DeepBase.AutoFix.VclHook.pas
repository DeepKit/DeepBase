{ ============================================================================
  DeepBase.AutoFix.VclHook

  L1 capture for VCL apps: hooks Application.OnException so all main-thread
  exceptions are routed into TAutoFixErrorRecorder before any dialog is shown.

  Usage in VCL .dpr:
    AutoFix.Install;        // L2 ExceptProc
    TAutoFixVclHook.Install; // L1 Application.OnException
    Application.Initialize;
    ...

  Coexistence with TAIErrorHandler (DeepBase.AIErrorHandler):
    - When AutoFix mode is active, this hook records and suppresses the
      Application.OnException chain (no dialog is shown).
    - When AutoFix mode is inactive, Install is a no-op so AIErrorHandler
      keeps full control.

  See: design v2.0 §3.7
  ============================================================================ }

unit DeepBase.AutoFix.VclHook;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms;

type
  TAutoFixVclHook = class
  private class var
    FInstalled: Boolean;
    FOldOnException: TExceptionEvent;
  private
    class procedure HandleAppException(Sender: TObject; E: Exception);
  public
    /// <summary>Hook Application.OnException. No-op when AutoFix mode is
    /// inactive. Safe to call multiple times (idempotent).</summary>
    class procedure Install;
    /// <summary>Restore the previous Application.OnException handler.</summary>
    class procedure Uninstall;
  end;

implementation

uses
  DeepBase.AutoFix.ErrorRecorder;

{ TAutoFixVclHook }

class procedure TAutoFixVclHook.Install;
begin
  if FInstalled then Exit;
  if not TAutoFixErrorRecorder.Active then Exit;
  FInstalled := True;
  FOldOnException := Application.OnException;
  Application.OnException := HandleAppException;
end;

class procedure TAutoFixVclHook.Uninstall;
begin
  if not FInstalled then Exit;
  FInstalled := False;
  Application.OnException := FOldOnException;
  FOldOnException := nil;
end;

class procedure TAutoFixVclHook.HandleAppException(Sender: TObject;
  E: Exception);
begin
  if TAutoFixErrorRecorder.Active then
  begin
    // Record then swallow the exception: the AutoFix loop reads the JSONL
    // file, no dialog needed. This intentionally bypasses TAIErrorHandler.
    TAutoFixErrorRecorder.WriteRecord(E, ExceptAddr, '<vcl-onexception>', 'main');
    Exit;
  end;

  // Defensive: AutoFix toggled off mid-run; chain to the original handler.
  if Assigned(FOldOnException) then
    FOldOnException(Sender, E);
end;

end.
