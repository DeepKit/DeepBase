{ ============================================================================
  DeepBase.VCL.ExceptionAdapter - VCL Application.OnException bridge

  Keeps DeepBase.Exception UI-neutral while wiring the global VCL exception
  hook when this adapter unit is linked by a VCL application.
  ============================================================================ }

unit DeepBase.VCL.ExceptionAdapter;

interface

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  DeepBase.Exception;

type
  TDeepBaseVCLExceptionBridge = class
  public
    procedure ApplicationException(Sender: TObject; E: Exception);
  end;

var
  GVCLExceptionBridge: TDeepBaseVCLExceptionBridge;
  GPreviousOnException: TExceptionEvent;
  GInstalled: Boolean;

procedure TDeepBaseVCLExceptionBridge.ApplicationException(Sender: TObject;
  E: Exception);
begin
  TDeepBaseExceptionHandler.HandleException(Sender, E);
end;

procedure InstallVCLExceptionHandler;
begin
  if not Assigned(GVCLExceptionBridge) then
    GVCLExceptionBridge := TDeepBaseVCLExceptionBridge.Create;
  if not GInstalled then
  begin
    GPreviousOnException := Application.OnException;
    GInstalled := True;
  end;
  Application.OnException := GVCLExceptionBridge.ApplicationException;
end;

procedure ShowVCLException(Sender: TObject; E: Exception);
begin
  if E is EAbort then
    Exit;
  if Assigned(Application) then
    Application.ShowException(E);
end;

initialization
  TDeepBaseExceptionHandler.SetPlatformAdapter(
    InstallVCLExceptionHandler,
    ShowVCLException);

finalization
  if Assigned(Application) and GInstalled then
    Application.OnException := GPreviousOnException;
  TDeepBaseExceptionHandler.SetPlatformAdapter(nil, nil);
  FreeAndNil(GVCLExceptionBridge);

end.
