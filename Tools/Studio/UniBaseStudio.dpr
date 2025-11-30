{ ============================================================================
  UniBase Studio - 配置管理工具
  
  版本: 1.0
  说明: UniBase 框架的可视化配置和管理工具
  ============================================================================ }

program UniBaseStudio;

uses
  Vcl.Forms,
  Vcl.Themes,
  Vcl.Styles,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  FireDAC.Stan.ExprFuncs,
  Studio.MainForm in 'Forms\Studio.MainForm.pas' {StudioMainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'UniBase Studio';
  
  // 应用 Windows 11 样式（如果可用）
  if TStyleManager.IsValidStyle('Windows11') then
    TStyleManager.TrySetStyle('Windows11');
    
  Application.CreateForm(TStudioMainForm, StudioMainForm);
  Application.Run;
end.
