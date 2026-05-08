unit Tray.MainForm;

{*******************************************************************************
  DeepBaseTray - 开发工作台悬浮窗口
  
  功能:
  - 悬浮窗口，可拖动，半透明
  - 系统托盘图标，双击显示/隐藏
  - 开发日志快速录入
  - 常用命令面板
  - 快速启动工具
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.IniFiles,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Menus, Vcl.Imaging.pngimage,
  DeepBase.VCL.TrayIcon,
  Tray.Hotkey,
  Tray.DevLogFrame, Tray.CommandFrame, Tray.MonitorFrame, Tray.NotesFrame,
  Tray.SchedulerFrame, Tray.ProjectsFrame;
  
type
  TTrayMainForm = class(TForm)
  private
    { 托盘相关 }
    FTrayIcon: TDeepBaseTrayIcon;
    FTrayMenu: TPopupMenu;
    FHotkeyManager: TTrayHotkeyManager;
    
    { 窗口状态 }
    FDragging: Boolean;
    FDragStart: TPoint;
    FOpacity: Byte;
    FAlwaysOnTop: Boolean;
    FSettingsPath: string;
    
    { 界面组件 }
    FPageControl: TPageControl;
    FTabDevLog: TTabSheet;
    FTabCommands: TTabSheet;
    FTabLaunch: TTabSheet;
    FTabMonitor: TTabSheet;
    FTabNotes: TTabSheet;
    FTabScheduler: TTabSheet;
    FTabProjects: TTabSheet;
    FTitleBar: TPanel;
    FLblTitle: TLabel;
    FBtnMinimize: TButton;
    FBtnClose: TButton;
    
    { Frames }
    FDevLogFrame: TDevLogFrame;
    FCommandFrame: TCommandFrame;
    FMonitorFrame: TMonitorFrame;
    FNotesFrame: TNotesFrame;
    FSchedulerFrame: TSchedulerFrame;
    FProjectsFrame: TProjectsFrame;
    
    { 托盘方法 }
    procedure CreateTrayIcon;
    procedure RemoveTrayIcon;
    procedure ShowFromTray;
    procedure HideToTray;
    
    { 托盘菜单 }
    procedure CreateTrayMenu;
    procedure OnTrayMenuShow(Sender: TObject);
    procedure OnTrayMenuHide(Sender: TObject);
    procedure OnTrayMenuCheckUpdate(Sender: TObject);
    procedure OnTrayMenuLicenseStatus(Sender: TObject);
    procedure OnTrayMenuSettings(Sender: TObject);
    procedure OnTrayMenuExit(Sender: TObject);

    { 热键 }
    procedure HandleHotkey(Action: THotkeyAction);
    procedure WMHotKey(var Msg: TMessage); message WM_HOTKEY;
    
    { 窗口拖动 }
    procedure TitleBarMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TitleBarMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure TitleBarMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    
    { 界面事件 }
    procedure OnBtnMinimizeClick(Sender: TObject);
    procedure OnBtnCloseClick(Sender: TObject);
    
    { 设置 }
    procedure LoadSettings;
    procedure SaveSettings;
    function GetSettingsPath: string;
    
    { 窗口位置 }
    procedure EnsureOnScreen;
    
    { 界面创建 }
    procedure CreateUI;
    procedure CreateTitleBar;
    procedure CreatePageControl;
    procedure CreateLaunchTab;
    procedure CreateMonitorTab;
    procedure CreateNotesTab;
    procedure CreateSchedulerTab;
    procedure CreateProjectsTab;
    
    { 快速启动 }
    procedure OnLaunchStudio(Sender: TObject);
    procedure OnLaunchCmd(Sender: TObject);
    procedure OnLaunchPowerShell(Sender: TObject);
    procedure OnLaunchCmdAdmin(Sender: TObject);
    procedure OnLaunchPowerShellAdmin(Sender: TObject);
    procedure OnLaunchExplorer(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMNCHitTest(var Msg: TWMNCHitTest); message WM_NCHITTEST;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    property Opacity: Byte read FOpacity write FOpacity;
    property AlwaysOnTop: Boolean read FAlwaysOnTop write FAlwaysOnTop;
  end;

var
  TrayMainForm: TTrayMainForm;

implementation

uses
  Tray.Launcher, Tray.Database, Tray.SettingsForm;

{$R *.dfm}

const
  DEFAULT_WIDTH = 320;
  DEFAULT_HEIGHT = 480;
  DEFAULT_OPACITY = 217;  // 85%
  TITLE_BAR_HEIGHT = 32;
  
{ TTrayMainForm }

constructor TTrayMainForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FTrayIcon := nil;
  FHotkeyManager := nil;
  FDragging := False;
  FOpacity := DEFAULT_OPACITY;
  FAlwaysOnTop := True;
  FSettingsPath := GetSettingsPath;
  
  // 窗口样式
  BorderStyle := bsNone;
  Width := DEFAULT_WIDTH;
  Height := DEFAULT_HEIGHT;
  Color := $002D2D2D;  // 深灰色背景
  
  // 加载设置（包括位置）
  LoadSettings;
  
  // 应用透明度
  AlphaBlend := True;
  AlphaBlendValue := FOpacity;
  
  // 置顶
  if FAlwaysOnTop then
    FormStyle := fsStayOnTop;
  
  // 确保窗口在屏幕内
  EnsureOnScreen;
  
  // 创建界面
  CreateUI;
  
  // 创建托盘
  CreateTrayMenu;
  CreateTrayIcon;

  // 全局热键（托盘/窗口联动）
  TTrayHotkeyManager.Initialize(Handle);
  FHotkeyManager := TrayHotkeys;
  if Assigned(FHotkeyManager) then
  begin
    FHotkeyManager.OnHotkey := HandleHotkey;
    FHotkeyManager.RegisterDefaults;
  end;
end;

destructor TTrayMainForm.Destroy;
begin
  if Assigned(FHotkeyManager) then
  begin
    FHotkeyManager.OnHotkey := nil;
    FHotkeyManager.UnregisterAll;
    FHotkeyManager := nil;
  end;
  TTrayHotkeyManager.Finalize;
  SaveSettings;
  RemoveTrayIcon;
  FTrayMenu.Free;
  inherited;
end;

procedure TTrayMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  // 工具窗口样式：不在任务栏显示
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TTrayMainForm.WMNCHitTest(var Msg: TWMNCHitTest);
begin
  inherited;
  // 允许从边缘调整大小（可选）
end;

{ 托盘图标 }

procedure TTrayMainForm.CreateTrayIcon;
begin
  if Assigned(FTrayIcon) then
    Exit;

  FTrayIcon := TDeepBaseTrayIcon.Create(Self);
  FTrayIcon.ToolTip := 'DeepBase 工作台';
  FTrayIcon.HostForm := Self;
  FTrayIcon.PopupMenu := FTrayMenu;
  FTrayIcon.MinimizeToTray := True;
  FTrayIcon.CloseToTray := TrayDB.GetSettingBool('Tray.MinimizeOnClose', True);
  FTrayIcon.RestoreOnDoubleClick := True;
  if Application.Icon.Handle <> 0 then
    FTrayIcon.Icon.Handle := Application.Icon.Handle;
  FTrayIcon.Visible := True;
end;

procedure TTrayMainForm.RemoveTrayIcon;
begin
  if Assigned(FTrayIcon) then
  begin
    FTrayIcon.Visible := False;
    FreeAndNil(FTrayIcon);
  end;
end;

procedure TTrayMainForm.ShowFromTray;
begin
  if Assigned(FTrayIcon) then
    FTrayIcon.ShowHostForm
  else
  begin
    Show;
    WindowState := wsNormal;
    SetForegroundWindow(Handle);
  end;
end;

procedure TTrayMainForm.HideToTray;
begin
  if Assigned(FTrayIcon) then
    FTrayIcon.HideHostForm
  else
    Hide;
end;

{ 托盘菜单 }

procedure TTrayMainForm.CreateTrayMenu;
var
  MenuItem: TMenuItem;
begin
  FTrayMenu := TPopupMenu.Create(Self);
  
  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '显示工作台(&S)';
  MenuItem.Default := True;
  MenuItem.OnClick := OnTrayMenuShow;
  FTrayMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '隐藏(&H)';
  MenuItem.OnClick := OnTrayMenuHide;
  FTrayMenu.Items.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '-';
  FTrayMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '检查更新(&U)';
  MenuItem.OnClick := OnTrayMenuCheckUpdate;
  FTrayMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '授权状态(&L)';
  MenuItem.OnClick := OnTrayMenuLicenseStatus;
  FTrayMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '设置(&T)';
  MenuItem.OnClick := OnTrayMenuSettings;
  FTrayMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '-';
  FTrayMenu.Items.Add(MenuItem);

  MenuItem := TMenuItem.Create(FTrayMenu);
  MenuItem.Caption := '退出(&X)';
  MenuItem.OnClick := OnTrayMenuExit;
  FTrayMenu.Items.Add(MenuItem);
end;

procedure TTrayMainForm.OnTrayMenuShow(Sender: TObject);
begin
  ShowFromTray;
end;

procedure TTrayMainForm.OnTrayMenuHide(Sender: TObject);
begin
  HideToTray;
end;

procedure TTrayMainForm.OnTrayMenuCheckUpdate(Sender: TObject);
begin
  MessageDlg('更新检查将在 UPD-P0-001 接入服务器后启用。', mtInformation, [mbOK], 0);
end;

procedure TTrayMainForm.OnTrayMenuLicenseStatus(Sender: TObject);
begin
  MessageDlg('授权状态将在 SEC-P0-001 完成后接入。', mtInformation, [mbOK], 0);
end;

procedure TTrayMainForm.OnTrayMenuSettings(Sender: TObject);
var
  SettingsForm: TTraySettingsForm;
begin
  SettingsForm := TTraySettingsForm.Create(Self);
  try
    if SettingsForm.ShowModal = mrOk then
    begin
      FOpacity := TrayDB.GetSettingInt('Tray.Opacity', FOpacity);
      AlphaBlendValue := FOpacity;
      FAlwaysOnTop := TrayDB.GetSettingBool('Tray.AlwaysOnTop', FAlwaysOnTop);
      if FAlwaysOnTop then
        FormStyle := fsStayOnTop
      else
        FormStyle := fsNormal;
      if Assigned(FTrayIcon) then
        FTrayIcon.CloseToTray := TrayDB.GetSettingBool('Tray.MinimizeOnClose', True);
    end;
  finally
    SettingsForm.Free;
  end;
end;

procedure TTrayMainForm.OnTrayMenuExit(Sender: TObject);
begin
  if Assigned(FTrayIcon) then
  begin
    FTrayIcon.CloseToTray := False;
    FTrayIcon.Visible := False;
  end;
  Application.Terminate;
end;

{ 热键 }

procedure TTrayMainForm.WMHotKey(var Msg: TMessage);
begin
  if Assigned(FHotkeyManager) then
    FHotkeyManager.ProcessMessage(Msg)
  else
    Msg.Result := DefWindowProc(Handle, Msg.Msg, Msg.WParam, Msg.LParam);
end;

procedure TTrayMainForm.HandleHotkey(Action: THotkeyAction);
begin
  case Action of
    haShowHide:
      begin
        if Visible then
          HideToTray
        else
          ShowFromTray;
      end;
    haQuickNote:
      begin
        ShowFromTray;
        if Assigned(FPageControl) and Assigned(FTabNotes) then
          FPageControl.ActivePage := FTabNotes;
      end;
    haLaunchStudio:
      TTrayLauncher.LaunchStudio;
    haLaunchCmd:
      TTrayLauncher.LaunchCmd;
    haLaunchPwsh:
      TTrayLauncher.LaunchPowerShell;
    haClipboard:
      ; // reserved
    haScreenshot:
      ; // reserved
  end;
end;

{ 窗口拖动 }

procedure TTrayMainForm.TitleBarMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDragging := True;
    FDragStart := Point(X, Y);
    (Sender as TControl).Cursor := crSizeAll;
  end;
end;

procedure TTrayMainForm.TitleBarMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
begin
  if FDragging then
  begin
    Left := Left + X - FDragStart.X;
    Top := Top + Y - FDragStart.Y;
  end;
end;

procedure TTrayMainForm.TitleBarMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDragging := False;
    (Sender as TControl).Cursor := crDefault;
    SaveSettings;  // 保存新位置
  end;
end;

{ 界面事件 }

procedure TTrayMainForm.OnBtnMinimizeClick(Sender: TObject);
begin
  HideToTray;
end;

procedure TTrayMainForm.OnBtnCloseClick(Sender: TObject);
begin
  if Assigned(FTrayIcon) and FTrayIcon.CloseToTray then
    HideToTray
  else
    Application.Terminate;
end;

{ 设置 }

function TTrayMainForm.GetSettingsPath: string;
var
  AppDataPath: string;
begin
  AppDataPath := GetEnvironmentVariable('APPDATA');
  Result := IncludeTrailingPathDelimiter(AppDataPath) + 'DeepBase';
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
  Result := IncludeTrailingPathDelimiter(Result) + 'tray_settings.ini';
end;

procedure TTrayMainForm.LoadSettings;
var
  Ini: TIniFile;
begin
  if not FileExists(FSettingsPath) then
  begin
    // 默认位置：右下角
    Left := Screen.WorkAreaWidth - Width - 20;
    Top := Screen.WorkAreaHeight - Height - 20;
    Exit;
  end;
  
  Ini := TIniFile.Create(FSettingsPath);
  try
    Left := Ini.ReadInteger('Window', 'Left', Screen.WorkAreaWidth - Width - 20);
    Top := Ini.ReadInteger('Window', 'Top', Screen.WorkAreaHeight - Height - 20);
    Width := Ini.ReadInteger('Window', 'Width', DEFAULT_WIDTH);
    Height := Ini.ReadInteger('Window', 'Height', DEFAULT_HEIGHT);
    FOpacity := Ini.ReadInteger('Window', 'Opacity', DEFAULT_OPACITY);
    FAlwaysOnTop := Ini.ReadBool('Window', 'AlwaysOnTop', True);
  finally
    Ini.Free;
  end;
end;

procedure TTrayMainForm.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FSettingsPath);
  try
    Ini.WriteInteger('Window', 'Left', Left);
    Ini.WriteInteger('Window', 'Top', Top);
    Ini.WriteInteger('Window', 'Width', Width);
    Ini.WriteInteger('Window', 'Height', Height);
    Ini.WriteInteger('Window', 'Opacity', FOpacity);
    Ini.WriteBool('Window', 'AlwaysOnTop', FAlwaysOnTop);
  finally
    Ini.Free;
  end;
end;

procedure TTrayMainForm.EnsureOnScreen;
var
  WorkArea: TRect;
begin
  WorkArea := Screen.WorkAreaRect;
  
  // 确保窗口至少有一部分在屏幕内
  if Left + Width < WorkArea.Left + 50 then
    Left := WorkArea.Left;
  if Left > WorkArea.Right - 50 then
    Left := WorkArea.Right - Width;
  if Top < WorkArea.Top then
    Top := WorkArea.Top;
  if Top > WorkArea.Bottom - 50 then
    Top := WorkArea.Bottom - Height;
end;

{ 界面创建 }

procedure TTrayMainForm.CreateUI;
begin
  CreateTitleBar;
  CreatePageControl;
  CreateLaunchTab;
  CreateMonitorTab;
  CreateNotesTab;
  CreateSchedulerTab;
  CreateProjectsTab;
end;

procedure TTrayMainForm.CreateTitleBar;
begin
  FTitleBar := TPanel.Create(Self);
  FTitleBar.Parent := Self;
  FTitleBar.Align := alTop;
  FTitleBar.Height := TITLE_BAR_HEIGHT;
  FTitleBar.BevelOuter := bvNone;
  FTitleBar.Color := $00404040;
  FTitleBar.ParentBackground := False;
  FTitleBar.OnMouseDown := TitleBarMouseDown;
  FTitleBar.OnMouseMove := TitleBarMouseMove;
  FTitleBar.OnMouseUp := TitleBarMouseUp;
  
  // 标题
  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FTitleBar;
  FLblTitle.Caption := 'DeepBase 工作台';
  FLblTitle.Font.Color := clWhite;
  FLblTitle.Font.Size := 10;
  FLblTitle.Left := 10;
  FLblTitle.Top := (TITLE_BAR_HEIGHT - FLblTitle.Height) div 2;
  FLblTitle.OnMouseDown := TitleBarMouseDown;
  FLblTitle.OnMouseMove := TitleBarMouseMove;
  FLblTitle.OnMouseUp := TitleBarMouseUp;
  
  // 关闭按钮
  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := FTitleBar;
  FBtnClose.Caption := '×';
  FBtnClose.Width := 32;
  FBtnClose.Height := TITLE_BAR_HEIGHT;
  FBtnClose.Align := alRight;
  FBtnClose.OnClick := OnBtnCloseClick;
  
  // 最小化按钮
  FBtnMinimize := TButton.Create(Self);
  FBtnMinimize.Parent := FTitleBar;
  FBtnMinimize.Caption := '—';
  FBtnMinimize.Width := 32;
  FBtnMinimize.Height := TITLE_BAR_HEIGHT;
  FBtnMinimize.Align := alRight;
  FBtnMinimize.OnClick := OnBtnMinimizeClick;
end;

procedure TTrayMainForm.CreatePageControl;
begin
  FPageControl := TPageControl.Create(Self);
  FPageControl.Parent := Self;
  FPageControl.Align := alClient;
  
  // 开发日志标签页
  FTabDevLog := TTabSheet.Create(FPageControl);
  FTabDevLog.PageControl := FPageControl;
  FTabDevLog.Caption := '日志';
  
  // 创建 DevLog Frame
  FDevLogFrame := TDevLogFrame.Create(Self);
  FDevLogFrame.Parent := FTabDevLog;
  FDevLogFrame.Align := alClient;
  
  // 命令面板标签页
  FTabCommands := TTabSheet.Create(FPageControl);
  FTabCommands.PageControl := FPageControl;
  FTabCommands.Caption := '命令';
  
  // 创建 Command Frame
  FCommandFrame := TCommandFrame.Create(Self);
  FCommandFrame.Parent := FTabCommands;
  FCommandFrame.Align := alClient;
  
  // 快速启动标签页
  FTabLaunch := TTabSheet.Create(FPageControl);
  FTabLaunch.PageControl := FPageControl;
  FTabLaunch.Caption := '启动';
  
  // 系统监控标签页
  FTabMonitor := TTabSheet.Create(FPageControl);
  FTabMonitor.PageControl := FPageControl;
  FTabMonitor.Caption := '监控';
  
  // 笔记标签页
  FTabNotes := TTabSheet.Create(FPageControl);
  FTabNotes.PageControl := FPageControl;
  FTabNotes.Caption := '笔记';
  
  // 定时任务标签页
  FTabScheduler := TTabSheet.Create(FPageControl);
  FTabScheduler.PageControl := FPageControl;
  FTabScheduler.Caption := '任务';
  
  // 项目切换器标签页
  FTabProjects := TTabSheet.Create(FPageControl);
  FTabProjects.PageControl := FPageControl;
  FTabProjects.Caption := '项目';
end;

procedure TTrayMainForm.CreateLaunchTab;
var
  Btn: TButton;
  Y: Integer;
begin
  Y := 10;
  
  // Studio 按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '启动 Studio';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchStudio;
  Inc(Y, 40);
  
  // CMD 按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '打开 CMD';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchCmd;
  Inc(Y, 40);
  
  // PowerShell 按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '打开 PowerShell';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchPowerShell;
  Inc(Y, 40);
  
  // CMD (管理员) 按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '打开 CMD (管理员)';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchCmdAdmin;
  Inc(Y, 40);
  
  // PowerShell (管理员) 按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '打开 PowerShell (管理员)';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchPowerShellAdmin;
  Inc(Y, 40);
  
  // 资源管理器按钮
  Btn := TButton.Create(Self);
  Btn.Parent := FTabLaunch;
  Btn.Caption := '打开资源管理器';
  Btn.Left := 10;
  Btn.Top := Y;
  Btn.Width := FTabLaunch.Width - 20;
  Btn.Height := 32;
  Btn.Anchors := [akLeft, akTop, akRight];
  Btn.OnClick := OnLaunchExplorer;
end;

{ 快速启动事件 }

procedure TTrayMainForm.OnLaunchStudio(Sender: TObject);
begin
  TTrayLauncher.LaunchStudio;
end;

procedure TTrayMainForm.OnLaunchCmd(Sender: TObject);
begin
  TTrayLauncher.LaunchCmd;
end;

procedure TTrayMainForm.OnLaunchPowerShell(Sender: TObject);
begin
  TTrayLauncher.LaunchPowerShell;
end;

procedure TTrayMainForm.OnLaunchCmdAdmin(Sender: TObject);
begin
  TTrayLauncher.LaunchCmdAdmin;
end;

procedure TTrayMainForm.OnLaunchPowerShellAdmin(Sender: TObject);
begin
  TTrayLauncher.LaunchPowerShellAdmin;
end;

procedure TTrayMainForm.OnLaunchExplorer(Sender: TObject);
begin
  TTrayLauncher.LaunchExplorer;
end;

procedure TTrayMainForm.CreateMonitorTab;
begin
  // 创建 Monitor Frame
  FMonitorFrame := TMonitorFrame.Create(Self);
  FMonitorFrame.Parent := FTabMonitor;
  FMonitorFrame.Align := alClient;
  
  // 启动监控
  FMonitorFrame.StartMonitoring;
end;

procedure TTrayMainForm.CreateNotesTab;
begin
  // 创建 Notes Frame
  FNotesFrame := TNotesFrame.Create(Self);
  FNotesFrame.Parent := FTabNotes;
  FNotesFrame.Align := alClient;
end;

procedure TTrayMainForm.CreateSchedulerTab;
begin
  // 创建 Scheduler Frame
  FSchedulerFrame := TSchedulerFrame.Create(Self);
  FSchedulerFrame.Parent := FTabScheduler;
  FSchedulerFrame.Align := alClient;
  
  // 启动定时器
  FSchedulerFrame.StartScheduler;
end;

procedure TTrayMainForm.CreateProjectsTab;
begin
  // 创建 Projects Frame
  FProjectsFrame := TProjectsFrame.Create(Self);
  FProjectsFrame.Parent := FTabProjects;
  FProjectsFrame.Align := alClient;
end;

end.
