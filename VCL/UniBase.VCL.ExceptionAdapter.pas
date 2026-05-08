{ ============================================================================
  DeepBase.VCL.ExceptionAdapter - VCL exception hook for DeepBase.Exception
  ============================================================================ }

unit DeepBase.VCL.ExceptionAdapter;

interface

procedure RegisterDeepBaseVCLExceptionAdapter;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  DeepBase.Exception;

type
  TVclExceptionBridge = class
  public
    procedure HandleApplicationException(Sender: TObject; E: Exception);
  end;

var
  GVclExceptionBridge: TVclExceptionBridge;

procedure TVclExceptionBridge.HandleApplicationException(Sender: TObject;
  E: Exception);
begin
  TDeepBaseExceptionHandler.HandleException(Sender, E);
end;

procedure InstallVclExceptionHandler;
begin
  if not Assigned(GVclExceptionBridge) then
    GVclExceptionBridge := TVclExceptionBridge.Create;
  Application.OnException := GVclExceptionBridge.HandleApplicationException;
end;

procedure ShowVclException(Sender: TObject; E: Exception);
begin
  if not (E is EAbort) then
    Application.ShowException(E);
end;

procedure RegisterDeepBaseVCLExceptionAdapter;
begin
  TDeepBaseExceptionHandler.SetPlatformAdapter(
    InstallVclExceptionHandler,
    ShowVclException);
end;

initialization
  RegisterDeepBaseVCLExceptionAdapter;

finalization
  GVclExceptionBridge.Free;

end.
