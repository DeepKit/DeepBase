{ ============================================================================
  DeepBase.AutoFix.ErrorRecorder.VCL

  VCL-specific extension that hooks Application.OnException for L1 capture.
  The core ErrorRecorder unit only hooks System.ExceptProc (cross-platform).

  Usage in VCL apps:
    uses
      DeepBase.AutoFix.ErrorRecorder,
      DeepBase.AutoFix.ErrorRecorder.VCL;

    begin
      TAutoFixErrorRecorder.Install;
      TAutoFixErrorRecorderVCL.HookApplication;
      ...
    end.

  FMX apps: do not use this unit. The core ErrorRecorder via ExceptProc is
  sufficient for catching unhandled exceptions on background threads. FMX
  main-thread exceptions surface through ExceptProc when not caught locally.
  ============================================================================ }

unit DeepBase.AutoFix.ErrorRecorder.VCL;

interface

uses
  System.SysUtils,
  Vcl.Forms,
  DeepBase.AutoFix.ErrorRecorder;

type
  TAutoFixErrorRecorderVCL = class
  private class var
    FHooked: Boolean;
    FOldAppException: TExceptionEvent;
  private
    class procedure AppExceptionHandler(Sender: TObject; E: Exception);
  public
    /// <summary>Hook Application.OnException (L1 capture for VCL main thread).
    /// Call after TAutoFixErrorRecorder.Install.</summary>
    class procedure HookApplication;
  end;

implementation

{ TAutoFixErrorRecorderVCL }

class procedure TAutoFixErrorRecorderVCL.HookApplication;
begin
  if FHooked then Exit;
  if not TAutoFixErrorRecorder.Active then Exit;
  FHooked := True;
  FOldAppException := Application.OnException;
  Application.OnException := AppExceptionHandler;
end;

class procedure TAutoFixErrorRecorderVCL.AppExceptionHandler(Sender: TObject;
  E: Exception);
begin
  if TAutoFixErrorRecorder.Active then
    TAutoFixErrorRecorder.WriteRecord(E, ExceptAddr, '', 'main');

  if Assigned(FOldAppException) then
    FOldAppException(Sender, E);
end;

end.
