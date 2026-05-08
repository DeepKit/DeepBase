program Studio;

uses
  Winapi.Windows,
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  Vcl.Dialogs,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  System.SysUtils,
  DeepBase.Manager,
  DeepBase.Types,
  Studio.MainForm in 'Forms\Studio.MainForm.pas' {frmStudioMain},
  Studio.ConfigFrame in 'Frames\Studio.ConfigFrame.pas' {fraConfig: TFrame},
  Studio.LogFrame in 'Frames\Studio.LogFrame.pas' {fraLog: TFrame},
  Studio.HotkeyFrame in 'Frames\Studio.HotkeyFrame.pas' {fraHotkey: TFrame},
  Studio.ThemeFrame in 'Frames\Studio.ThemeFrame.pas' {fraTheme: TFrame},
  Studio.SQLFrame in 'Frames\Studio.SQLFrame.pas' {fraSQLEditor: TFrame},
  Studio.QueriesFrame in 'Frames\Studio.QueriesFrame.pas' {fraQueries: TFrame},
  Studio.SchemaFrame in 'Frames\Studio.SchemaFrame.pas' {fraSchemaViewer: TFrame},
  Studio.BackupFrame in 'Frames\Studio.BackupFrame.pas' {fraBackupWizard: TFrame},
  Studio.ImportExportFrame in 'Frames\Studio.ImportExportFrame.pas' {fraImportExport: TFrame},
  Studio.ProfileFrame in 'Frames\Studio.ProfileFrame.pas' {fraProfiler: TFrame},
  Studio.HelpPanel in 'Studio.HelpPanel.pas';

{$R *.res}

var
  ErrorMsg: string;
  UB: TDeepBaseManager;
  LangCode: Cardinal;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'DeepBase Studio';
  
  // 获取 DeepBase 单例
  UB := DeepBase.Manager.DeepBase;
  
  // 初始化 DeepBase - 用于演示 i18n 和其他核心功能
  try
    if not UB.InitializeEx(ErrorMsg) then
    begin
      ShowMessage('Failed to initialize DeepBase: ' + ErrorMsg);
      Exit;
    end;
    
    // 检测系统语言并设置 i18n
    LangCode := GetUserDefaultLCID;
    case LangCode of
      $0804: UB.CurrentLanguage := 'zh-CN';  // 简体中文
      $0404: UB.CurrentLanguage := 'zh-TW';  // 繁体中文
      $0409: UB.CurrentLanguage := 'en-US';  // 英文
    else
      UB.CurrentLanguage := 'en-US';
    end;
  except
    on E: Exception do
    begin
      ShowMessage('Error during initialization: ' + E.Message);
      Exit;
    end;
  end;
  
  Application.CreateForm(TfrmStudioMain, frmStudioMain);
  Application.Run;
  
  // 清理
  try
    UB.Finalize;
  except
    // Ignore cleanup errors
  end;
end.
