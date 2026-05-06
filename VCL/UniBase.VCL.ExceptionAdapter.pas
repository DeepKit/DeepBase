{ ============================================================================
  UniBase.VCL.ExceptionAdapter - VCL exception hook for UniBase.Exception
  ============================================================================ }

unit UniBase.VCL.ExceptionAdapter;

interface

procedure RegisterUniBaseVCLExceptionAdapter;

implementation

uses
  System.SysUtils,
  Vcl.Forms,
  UniBase.Exception;

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
  TUniBaseExceptionHandler.HandleException(Sender, E);
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

procedure RegisterUniBaseVCLExceptionAdapter;
begin
  TUniBaseExceptionHandler.SetPlatformAdapter(
    InstallVclExceptionHandler,
    ShowVclException);
end;

initialization
  RegisterUniBaseVCLExceptionAdapter;

finalization
  GVclExceptionBridge.Free;

end.
