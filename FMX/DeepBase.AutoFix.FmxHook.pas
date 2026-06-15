{ ============================================================================
  DeepBase.AutoFix.FmxHook

  L1 capture for FMX apps: hooks Application.OnException so main-thread
  exceptions are routed into TAutoFixErrorRecorder before the previous handler.

  Usage in FMX .dpr:
    AutoFix.Install;        // L2 ExceptProc
    TAutoFixFmxHook.Install; // L1 Application.OnException
    Application.Initialize;
    ...

  See: design v2.0 §3.7
  ============================================================================ }

unit DeepBase.AutoFix.FmxHook;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Forms;

type
  TAutoFixFmxHook = class
  private class var
    FInstalled: Boolean;
    FOldOnException: TExceptionEvent;
  private
    class procedure HandleAppException(Sender: TObject; E: Exception);
  public
    class procedure Install;
    class procedure Uninstall;
  end;

implementation

uses
  DeepBase.AutoFix.ErrorRecorder;

{ TAutoFixFmxHook }

class procedure TAutoFixFmxHook.Install;
begin
  if FInstalled then Exit;
  if not TAutoFixErrorRecorder.Active then Exit;
  FInstalled := True;
  FOldOnException := Application.OnException;
  Application.OnException := HandleAppException;
end;

class procedure TAutoFixFmxHook.Uninstall;
begin
  if not FInstalled then Exit;
  FInstalled := False;
  Application.OnException := FOldOnException;
  FOldOnException := nil;
end;

class procedure TAutoFixFmxHook.HandleAppException(Sender: TObject;
  E: Exception);
begin
  if TAutoFixErrorRecorder.Active then
    TAutoFixErrorRecorder.WriteRecord(E, ExceptAddr, '<fmx-onexception>', 'main');

  if Assigned(FOldOnException) then
    FOldOnException(Sender, E);
end;

end.
