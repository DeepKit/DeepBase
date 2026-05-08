program DeepBaseTray;

{*******************************************************************************
  DeepBaseTray - 开发工作台
  
  悬浮窗口工具，提供:
  - 开发日志快速录入
  - 常用命令面板
  - 快速启动工具
  - 多步操作自动化
*******************************************************************************}

uses
  Vcl.Forms,
  DeepBase.VCL.TrayIcon in '..\..\VCL\DeepBase.VCL.TrayIcon.pas',
  Tray.MainForm in 'Tray.MainForm.pas' {TrayMainForm},
  Tray.Launcher in 'Tray.Launcher.pas',
  Tray.Database in 'Tray.Database.pas',
  Tray.DevLogFrame in 'Frames\Tray.DevLogFrame.pas',
  Tray.CommandFrame in 'Frames\Tray.CommandFrame.pas',
  Tray.Automation in 'Automation\Tray.Automation.pas',
  Tray.SettingsForm in 'Forms\Tray.SettingsForm.pas',
  Tray.LogSearchForm in 'Forms\Tray.LogSearchForm.pas',
  Tray.Hotkey in 'Tray.Hotkey.pas',
  Tray.SysMonitor in 'Tray.SysMonitor.pas',
  Tray.MonitorFrame in 'Frames\Tray.MonitorFrame.pas',
  Tray.NotesFrame in 'Frames\Tray.NotesFrame.pas',
  Tray.SchedulerFrame in 'Frames\Tray.SchedulerFrame.pas',
  Tray.ProjectsFrame in 'Frames\Tray.ProjectsFrame.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := False;  // 不在任务栏显示
  Application.Title := 'DeepBase 工作台';
  Application.CreateForm(TTrayMainForm, TrayMainForm);
  Application.Run;
end.
