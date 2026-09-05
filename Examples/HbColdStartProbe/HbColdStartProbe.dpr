{*****************************************************************************}
{  HbColdStartProbe - Gate #1 cold-start first-paint signal (WO-20260905-002) }
{*****************************************************************************}

program HbColdStartProbe;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Graphics,
  DeepBase.HB.Core,
  DeepBase.VCL.HB.Theme,
  DeepBase.VCL.HB.Controls;

type
  TProbeForm = class(TForm)
  private
    FSignaled: Boolean;
    FBtn: THbButton;
    procedure SignalFirstPaint;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  public
    constructor Create(AOwner: TComponent); override;
    property Signaled: Boolean read FSignaled;
  end;

constructor TProbeForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'HbColdStartProbe';
  Position := poScreenCenter;
  ClientWidth := 320;
  ClientHeight := 200;
  FSignaled := False;
  FBtn := THbButton.Create(Self);
  FBtn.Parent := Self;
  FBtn.Caption := 'HB';
  FBtn.SetBounds(24, 24, 120, 40);
end;

procedure TProbeForm.SignalFirstPaint;
var
  Marker: string;
begin
  if FSignaled then
    Exit;
  FSignaled := True;
  WriteLn('FIRST_PAINT');
  Flush(Output);
  Marker := TPath.Combine(TPath.GetTempPath, 'hb_coldstart_first_paint.marker');
  TFile.WriteAllText(Marker, 'FIRST_PAINT', TEncoding.UTF8);
end;

procedure TProbeForm.WMPaint(var Message: TWMPaint);
begin
  inherited;
  SignalFirstPaint;
end;

var
  Form: TProbeForm;
  Guard: Integer;
begin
  SetConsoleOutputCP(CP_UTF8);
  Application.Initialize;
  Application.MainFormOnTaskbar := False;
  Form := TProbeForm.Create(nil);
  try
    Form.Show;
    Form.Update; // forces WM_PAINT → FIRST_PAINT
    Guard := 0;
    while (not Form.Signaled) and (Guard < 200) do
    begin
      Application.ProcessMessages;
      Sleep(1);
      Inc(Guard);
    end;
  finally
    Form.Free;
  end;
  if not FileExists(TPath.Combine(TPath.GetTempPath, 'hb_coldstart_first_paint.marker')) then
    Halt(2);
end.
