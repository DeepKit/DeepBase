unit Tray.Launcher;

{*******************************************************************************
  UniBaseTray - 快速启动器
  
  功能:
  - 启动 Studio
  - 启动 CMD/PowerShell (普通/管理员)
  - 打开资源管理器
*******************************************************************************}

interface

uses
  Winapi.Windows, Winapi.ShellAPI,
  System.SysUtils, System.Classes, System.IniFiles;

type
  TTrayLauncher = class
  private
    class var FStudioPath: string;
    class var FWorkingDir: string;
    class function GetSettingsPath: string;
    class procedure LoadSettings;
  public
    class procedure Initialize;
    
    { 启动方法 }
    class procedure LaunchStudio;
    class procedure LaunchCmd(const AWorkingDir: string = '');
    class procedure LaunchPowerShell(const AWorkingDir: string = '');
    class procedure LaunchCmdAdmin(const AWorkingDir: string = '');
    class procedure LaunchPowerShellAdmin(const AWorkingDir: string = '');
    class procedure LaunchExplorer(const APath: string = '');
    
    { 通用启动 }
    class procedure LaunchProgram(const APath: string; const AParams: string = '';
      const AWorkingDir: string = ''; ARunAsAdmin: Boolean = False);
    
    { 配置 }
    class property StudioPath: string read FStudioPath write FStudioPath;
    class property WorkingDir: string read FWorkingDir write FWorkingDir;
  end;

implementation

{ TTrayLauncher }

class procedure TTrayLauncher.Initialize;
begin
  FWorkingDir := GetCurrentDir;
  LoadSettings;
end;

class function TTrayLauncher.GetSettingsPath: string;
var
  AppDataPath: string;
begin
  AppDataPath := GetEnvironmentVariable('APPDATA');
  Result := IncludeTrailingPathDelimiter(AppDataPath) + 'UniBase';
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
  Result := IncludeTrailingPathDelimiter(Result) + 'tray_settings.ini';
end;

class procedure TTrayLauncher.LoadSettings;
var
  Ini: TIniFile;
  SettingsPath: string;
begin
  SettingsPath := GetSettingsPath;
  if not FileExists(SettingsPath) then
    Exit;
    
  Ini := TIniFile.Create(SettingsPath);
  try
    FStudioPath := Ini.ReadString('Launcher', 'StudioPath', '');
  finally
    Ini.Free;
  end;
end;

class procedure TTrayLauncher.LaunchProgram(const APath, AParams, AWorkingDir: string;
  ARunAsAdmin: Boolean);
var
  ShellInfo: TShellExecuteInfo;
  WorkDir: string;
begin
  if AWorkingDir <> '' then
    WorkDir := AWorkingDir
  else if FWorkingDir <> '' then
    WorkDir := FWorkingDir
  else
    WorkDir := GetCurrentDir;
    
  ZeroMemory(@ShellInfo, SizeOf(ShellInfo));
  ShellInfo.cbSize := SizeOf(TShellExecuteInfo);
  ShellInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  ShellInfo.Wnd := 0;
  
  if ARunAsAdmin then
    ShellInfo.lpVerb := 'runas'
  else
    ShellInfo.lpVerb := 'open';
    
  ShellInfo.lpFile := PChar(APath);
  
  if AParams <> '' then
    ShellInfo.lpParameters := PChar(AParams)
  else
    ShellInfo.lpParameters := nil;
    
  ShellInfo.lpDirectory := PChar(WorkDir);
  ShellInfo.nShow := SW_SHOWNORMAL;
  
  ShellExecuteEx(@ShellInfo);
end;

class procedure TTrayLauncher.LaunchStudio;
begin
  if FStudioPath = '' then
  begin
    // 尝试查找 Studio.exe
    if FileExists('Studio.exe') then
      FStudioPath := ExpandFileName('Studio.exe')
    else if FileExists('..\Studio\Studio.exe') then
      FStudioPath := ExpandFileName('..\Studio\Studio.exe');
  end;
  
  if (FStudioPath <> '') and FileExists(FStudioPath) then
    LaunchProgram(FStudioPath)
  else
    raise Exception.Create('Studio 路径未配置或文件不存在');
end;

class procedure TTrayLauncher.LaunchCmd(const AWorkingDir: string);
var
  CmdPath: string;
  WorkDir: string;
begin
  CmdPath := GetEnvironmentVariable('COMSPEC');
  if CmdPath = '' then
    CmdPath := 'cmd.exe';
    
  if AWorkingDir <> '' then
    WorkDir := AWorkingDir
  else
    WorkDir := FWorkingDir;
    
  LaunchProgram(CmdPath, '', WorkDir, False);
end;

class procedure TTrayLauncher.LaunchPowerShell(const AWorkingDir: string);
var
  PSPath: string;
  WorkDir: string;
begin
  // 优先使用 PowerShell 7 (pwsh)
  PSPath := 'pwsh.exe';
  // 如果 pwsh 不存在，回退到 Windows PowerShell
  // ShellExecute 会自动处理路径查找
  
  if AWorkingDir <> '' then
    WorkDir := AWorkingDir
  else
    WorkDir := FWorkingDir;
    
  LaunchProgram(PSPath, '-NoExit -Command "Set-Location ''' + WorkDir + '''"', '', False);
end;

class procedure TTrayLauncher.LaunchCmdAdmin(const AWorkingDir: string);
var
  CmdPath: string;
  WorkDir: string;
begin
  CmdPath := GetEnvironmentVariable('COMSPEC');
  if CmdPath = '' then
    CmdPath := 'cmd.exe';
    
  if AWorkingDir <> '' then
    WorkDir := AWorkingDir
  else
    WorkDir := FWorkingDir;
    
  // 管理员模式下，使用 /K 命令切换目录
  LaunchProgram(CmdPath, '/K cd /d "' + WorkDir + '"', '', True);
end;

class procedure TTrayLauncher.LaunchPowerShellAdmin(const AWorkingDir: string);
var
  PSPath: string;
  WorkDir: string;
begin
  PSPath := 'pwsh.exe';
  
  if AWorkingDir <> '' then
    WorkDir := AWorkingDir
  else
    WorkDir := FWorkingDir;
    
  LaunchProgram(PSPath, '-NoExit -Command "Set-Location ''' + WorkDir + '''"', '', True);
end;

class procedure TTrayLauncher.LaunchExplorer(const APath: string);
var
  TargetPath: string;
begin
  if APath <> '' then
    TargetPath := APath
  else if FWorkingDir <> '' then
    TargetPath := FWorkingDir
  else
    TargetPath := GetCurrentDir;
    
  LaunchProgram('explorer.exe', '"' + TargetPath + '"', '', False);
end;

initialization
  TTrayLauncher.Initialize;

end.
