program Phase1Demo;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  UniBase.Manager,
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

var
  ErrorMsg: string;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // Initialize UniBase
  if not UniBase.Manager.UniBase.InitializeEx(ErrorMsg) then
  begin
    ShowMessage('UniBase Initialization Failed: ' + ErrorMsg);
  end;

  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
  
  UniBase.Manager.UniBase.Finalize;
end.
