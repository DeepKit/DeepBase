program UniBaseRun;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Dialogs,
  System.SysUtils,
  System.IOUtils,
  UniBase.Consts in '..\Core\UniBase.Consts.pas',
  UniBase.Types in '..\Core\UniBase.Types.pas',
  UniBase.Manager in '..\Core\UniBase.Manager.pas',
  UniBase.Config in '..\Core\UniBase.Config.pas',
  UniBase.i18n in '..\Core\UniBase.i18n.pas',
  UniBase.Logging in '..\Core\UniBase.Logging.pas',
  UniBase.Theme in '..\Core\UniBase.Theme.pas',
  UniBase.FormState in '..\Core\UniBase.FormState.pas',
  ViewMain in 'ViewMain.pas' {frmMain},
  CtrlMain in 'CtrlMain.pas',
  uDM in 'uDM.pas' {DM: TDataModule},
  FrameLogViewer in 'FrameLogViewer.pas' {fraLogViewer: TFrame},
  FrameConfigEditor in 'FrameConfigEditor.pas' {fraConfigEditor: TFrame};

{$R *.res}

var
  UniBaseMgr: TUniBaseManager;

begin
  Application.Initialize;
  
  // 创建并初始化 UniBase 管理器
  UniBaseMgr := TUniBaseManager.Create(nil);
  try
    if not UniBaseMgr.Initialize then
    begin
      // 显示错误但继续运行，允许用户查看问题
      ShowMessage('Warning: UniBase initialization failed: ' + UniBaseMgr.LastError);
    end;
    
    Application.CreateForm(TDM, DM);
    Application.CreateForm(TfrmMain, frmMain);
    Application.Run;
  finally
    UniBaseMgr.Finalize;
    UniBaseMgr.Free;
  end;
end.
