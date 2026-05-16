program Phase1Demo;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC,
  MainForm in 'MainForm.pas' {frmMain};

var
  ErrorMsg: string;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // Initialize DeepBase
  if not DeepBase.Manager.DeepBase.InitializeEx(ErrorMsg) then
  begin
    ShowMessage('DeepBase Initialization Failed: ' + ErrorMsg);
  end;

  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
  
  DeepBase.Manager.DeepBase.Finalize;
end.
