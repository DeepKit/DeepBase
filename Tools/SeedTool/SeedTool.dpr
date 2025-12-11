program SeedTool;

uses
  Vcl.Forms,
  uSeedMain in 'uSeedMain.pas' {frmSeedMain},
  uAntiTamperPackage in 'uAntiTamperPackage.pas',
  uBasicProtection in 'uBasicProtection.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := '防篡改播种工具';
  Application.CreateForm(TfrmSeedMain, frmSeedMain);
  Application.Run;
end.
