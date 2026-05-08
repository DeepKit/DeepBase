program DeepBaseRun;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Dialogs,
  System.SysUtils,
  System.IOUtils,
  DeepBase.Consts in '..\Core\DeepBase.Consts.pas',
  DeepBase.Types in '..\Core\DeepBase.Types.pas',
  DeepBase.Manager in '..\Core\DeepBase.Manager.pas',
  DeepBase.Config in '..\Core\DeepBase.Config.pas',
  DeepBase.i18n in '..\Core\DeepBase.i18n.pas',
  DeepBase.Logging in '..\Core\DeepBase.Logging.pas',
  DeepBase.Theme in '..\Core\DeepBase.Theme.pas',
  DeepBase.FormState in '..\Core\DeepBase.FormState.pas',
  ViewMain in 'ViewMain.pas' {frmMain},
  CtrlMain in 'CtrlMain.pas',
  uDM in 'uDM.pas' {DM: TDataModule},
  FrameLogViewer in 'FrameLogViewer.pas' {fraLogViewer: TFrame},
  FrameConfigEditor in 'FrameConfigEditor.pas' {fraConfigEditor: TFrame};

{$R *.res}

var
  DeepBaseMgr: TDeepBaseManager;

begin
  Application.Initialize;
  
  // 创建并初始化 DeepBase 管理器
  DeepBaseMgr := TDeepBaseManager.Create(nil);
  try
    if not DeepBaseMgr.Initialize then
    begin
      // 显示错误但继续运行，允许用户查看问题
      ShowMessage('Warning: DeepBase initialization failed: ' + DeepBaseMgr.LastError);
    end;
    
    Application.CreateForm(TDM, DM);
    Application.CreateForm(TfrmMain, frmMain);
    Application.Run;
  finally
    DeepBaseMgr.Finalize;
    DeepBaseMgr.Free;
  end;
end.
