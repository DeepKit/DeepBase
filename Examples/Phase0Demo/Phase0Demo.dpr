program Phase0Demo;

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
  // In a real app, we might want to check result
  if not UniBase.Manager.UniBase.InitializeEx(ErrorMsg) then
  begin
    ShowMessage('UniBase Initialization Failed: ' + ErrorMsg);
    // Depending on severity, we might continue or exit
    // For demo, we continue but functionality might be limited
  end;

  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
  
  UniBase.Manager.UniBase.Finalize;
end.
