program prjDoQry;

uses
  Vcl.Forms,
  doQryMain in 'doQryMain.pas' {frmMain},
  uDoQryLegacy in 'uDoQryLegacy.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
