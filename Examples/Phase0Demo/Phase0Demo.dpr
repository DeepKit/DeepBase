program Phase0Demo;

uses
  Vcl.Forms,
  Vcl.Dialogs,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  DeepBase.Manager,
  DeepBase.Persistence.Manager.FireDAC,
  MainForm in 'MainForm.pas' {frmMain};

{$R *.res}

var
  ErrorMsg: string;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  
  // Initialize DeepBase
  // In a real app, we might want to check result
  if not DeepBase.Manager.DeepBase.InitializeEx(ErrorMsg) then
  begin
    ShowMessage('DeepBase Initialization Failed: ' + ErrorMsg);
    // Depending on severity, we might continue or exit
    // For demo, we continue but functionality might be limited
  end;

  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
  
  DeepBase.Manager.DeepBase.Finalize;
end.
