{ ============================================================================
  Demo.MainForm

  Minimal programmatically-built VCL form for the AutoFix demo. Avoids a
  .dfm file so the demo can be exercised by a CLI build without IDE save.

  See: design v2.0 §3.5 (facade) / §3.7 (VclHook)
  ============================================================================ }

unit Demo.MainForm;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Controls;

type
  TDemoMainForm = class(TForm)
  private
    FStatus: TLabel;
  protected
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  DeepBase.AutoFix;

{ TDemoMainForm }

constructor TDemoMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  Caption := 'AutoFix Demo';
  Width := 480;
  Height := 240;
  Position := poScreenCenter;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.AutoSize := False;
  FStatus.Align := alClient;
  FStatus.Alignment := taCenter;
  FStatus.Layout := tlCenter;
  FStatus.Caption := if AutoFix.Active
    then 'AutoFix mode: ON (driven by --autofix-mode)'
    else 'AutoFix mode: off (normal launch)';
end;

procedure TDemoMainForm.DoShow;
begin
  inherited;
  // No-op when AutoFix mode is inactive; emits HealthSignal + queues
  // ScenarioRunner.Run otherwise.
  AutoFix.NotifyShellShown;
end;

end.
