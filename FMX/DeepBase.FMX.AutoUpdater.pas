{ ============================================================================
  DeepBase.FMX.AutoUpdater - FMX 自动更新组件
  
  版本: 1.0
  说明: 跨平台非可视组件，封装自动更新核心模块和 UI 交互
  
  支持平台:
    - Windows: 直接下载安装�?
    - macOS: 直接下载 DMG/PKG
    - iOS: 跳转 App Store
    - Android: 下载 APK 或跳�?Play Store
  ============================================================================ }

unit DeepBase.FMX.AutoUpdater;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Messaging,
  FMX.Types,
  FMX.Dialogs,
  DeepBase.Updater;

type
  TUpdateCheckMode = (ucmManual, ucmOnStartup, ucmPeriodic);
  
  TUpdateAvailableEvent = procedure(Sender: TObject; const Info: TUpdateInfo; 
    var ShowDialog: Boolean) of object;
  TUpdateProgressEvent = procedure(Sender: TObject; const Progress: TUpdateProgress) of object;
  TUpdateCompleteEvent = procedure(Sender: TObject; Success: Boolean; 
    const ErrorMessage: string) of object;

  TFMXAutoUpdater = class(TFmxObject)
  private
    FUpdateUrl: string;
    FCurrentVersion: string;
    FChannel: TUpdateChannel;
    FCheckMode: TUpdateCheckMode;
    FCheckIntervalHours: Integer;
    FShowDialogOnUpdate: Boolean;
    FAppStoreUrl: string;      // iOS App Store URL
    FPlayStoreUrl: string;     // Android Play Store URL
    FPublicKey: string;
    
    FOnUpdateAvailable: TUpdateAvailableEvent;
    FOnProgress: TUpdateProgressEvent;
    FOnUpdateComplete: TUpdateCompleteEvent;
    FOnNoUpdate: TNotifyEvent;
    FOnCheckError: TGetStrProc;
    
    FLastCheckTime: TDateTime;
    FIsChecking: Boolean;
    FIsDownloading: Boolean;
    FCurrentUpdateInfo: TUpdateInfo;
    
    procedure DoCheckForUpdates;
    procedure HandleUpdateAvailable(const Info: TUpdateInfo);
    procedure HandleProgress(const Progress: TUpdateProgress);
    function ShouldCheckOnStartup: Boolean;
    function GetPlatformUpdateMethod: string;
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>手动检查更�?/summary>
    procedure CheckForUpdates;
    
    /// <summary>静默检查更新（不显示对话框�?/summary>
    procedure CheckForUpdatesSilent(Callback: TCheckUpdateCallback);
    
    /// <summary>下载并安装更�?/summary>
    procedure DownloadAndInstall;
    
    /// <summary>仅下载更�?/summary>
    procedure DownloadOnly;
    
    /// <summary>取消当前操作</summary>
    procedure Cancel;
    
    /// <summary>打开应用商店页面（移动端�?/summary>
    procedure OpenAppStore;
    
    /// <summary>获取当前更新信息</summary>
    property CurrentUpdateInfo: TUpdateInfo read FCurrentUpdateInfo;
    
    /// <summary>是否正在检�?/summary>
    property IsChecking: Boolean read FIsChecking;
    
    /// <summary>是否正在下载</summary>
    property IsDownloading: Boolean read FIsDownloading;
    
    /// <summary>上次检查时�?/summary>
    property LastCheckTime: TDateTime read FLastCheckTime;
    
  published
    /// <summary>更新服务�?URL</summary>
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    
    /// <summary>当前版本�?/summary>
    property CurrentVersion: string read FCurrentVersion write FCurrentVersion;
    
    /// <summary>更新频道</summary>
    property Channel: TUpdateChannel read FChannel write FChannel default ucStable;
    
    /// <summary>检查模�?/summary>
    property CheckMode: TUpdateCheckMode read FCheckMode write FCheckMode default ucmOnStartup;
    
    /// <summary>周期检查间隔（小时�?/summary>
    property CheckIntervalHours: Integer read FCheckIntervalHours write FCheckIntervalHours default 24;
    
    /// <summary>发现更新时自动显示对话框</summary>
    property ShowDialogOnUpdate: Boolean read FShowDialogOnUpdate write FShowDialogOnUpdate default True;
    
    /// <summary>iOS App Store URL</summary>
    property AppStoreUrl: string read FAppStoreUrl write FAppStoreUrl;
    
    /// <summary>Android Play Store URL</summary>
    property PlayStoreUrl: string read FPlayStoreUrl write FPlayStoreUrl;
    
    /// <summary>RSA 公钥（用于签名验证）</summary>
    property PublicKey: string read FPublicKey write FPublicKey;
    
    /// <summary>发现更新时触�?/summary>
    property OnUpdateAvailable: TUpdateAvailableEvent read FOnUpdateAvailable write FOnUpdateAvailable;
    
    /// <summary>下载进度</summary>
    property OnProgress: TUpdateProgressEvent read FOnProgress write FOnProgress;
    
    /// <summary>更新完成</summary>
    property OnUpdateComplete: TUpdateCompleteEvent read FOnUpdateComplete write FOnUpdateComplete;
    
    /// <summary>没有更新时触�?/summary>
    property OnNoUpdate: TNotifyEvent read FOnNoUpdate write FOnNoUpdate;
    
    /// <summary>检查出错时触发</summary>
    property OnCheckError: TGetStrProc read FOnCheckError write FOnCheckError;
  end;

procedure Register;

implementation

uses
  System.IOUtils,
  System.DateUtils,
  {$IF DEFINED(IOS) OR DEFINED(ANDROID)}
  FMX.Helpers.Android,
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Winapi.ShellAPI,
  Winapi.Windows,
  {$ENDIF}
  {$IFDEF MACOS}
  Macapi.AppKit,
  Macapi.Foundation,
  {$ENDIF}
  DeepBase.FMX.UpdateDialog;

procedure Register;
begin
  RegisterComponents('DeepBase FMX', [TFMXAutoUpdater]);
end;

{ TFMXAutoUpdater }

constructor TFMXAutoUpdater.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FChannel := ucStable;
  FCheckMode := ucmOnStartup;
  FCheckIntervalHours := 24;
  FShowDialogOnUpdate := True;
  FIsChecking := False;
  FIsDownloading := False;
  FLastCheckTime := 0;
end;

destructor TFMXAutoUpdater.Destroy;
begin
  inherited;
end;

procedure TFMXAutoUpdater.Loaded;
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    // 初始化更新管理器
    if FUpdateUrl <> '' then
    begin
      Updater.Initialize(FUpdateUrl, FCurrentVersion);
      Updater.Channel := FChannel;
      if FPublicKey <> '' then
        Updater.SetPublicKey(FPublicKey);
    end;
    
    // 启动时检�?
    if ShouldCheckOnStartup then
    begin
      TThread.ForceQueue(nil,
        procedure
        begin
          DoCheckForUpdates;
        end);
    end;
  end;
end;

function TFMXAutoUpdater.ShouldCheckOnStartup: Boolean;
begin
  Result := False;
  
  case FCheckMode of
    ucmOnStartup:
      Result := True;
    ucmPeriodic:
      begin
        if FLastCheckTime = 0 then
          Result := True
        else
          Result := HoursBetween(Now, FLastCheckTime) >= FCheckIntervalHours;
      end;
  end;
end;

function TFMXAutoUpdater.GetPlatformUpdateMethod: string;
begin
  {$IF DEFINED(IOS)}
  Result := 'appstore';
  {$ELSEIF DEFINED(ANDROID)}
  Result := 'playstore'; // �?'apk'
  {$ELSEIF DEFINED(MACOS)}
  Result := 'dmg';
  {$ELSE}
  Result := 'exe';
  {$ENDIF}
end;

procedure TFMXAutoUpdater.CheckForUpdates;
begin
  DoCheckForUpdates;
end;

procedure TFMXAutoUpdater.CheckForUpdatesSilent(Callback: TCheckUpdateCallback);
begin
  if FIsChecking then
    Exit;
    
  FIsChecking := True;
  
  Updater.CheckForUpdates(
    procedure(Available: Boolean; const Info: TUpdateInfo)
    begin
      FIsChecking := False;
      FLastCheckTime := Now;
      FCurrentUpdateInfo := Info;
      
      if Assigned(Callback) then
        Callback(Available, Info);
    end);
end;

procedure TFMXAutoUpdater.DoCheckForUpdates;
var
  ShowDialog: Boolean;
begin
  if FIsChecking or (FUpdateUrl = '') then
    Exit;
  
  FIsChecking := True;
  
  Updater.OnProgress :=
    procedure(const Progress: TUpdateProgress)
    begin
      HandleProgress(Progress);
    end;
  
  Updater.CheckForUpdates(
    procedure(Available: Boolean; const Info: TUpdateInfo)
    begin
      FIsChecking := False;
      FLastCheckTime := Now;
      
      if Available then
      begin
        FCurrentUpdateInfo := Info;
        ShowDialog := FShowDialogOnUpdate;
        
        // 触发事件，允许用户处�?
        if Assigned(FOnUpdateAvailable) then
          FOnUpdateAvailable(Self, Info, ShowDialog);
        
        if ShowDialog then
          HandleUpdateAvailable(Info);
      end
      else
      begin
        if Assigned(FOnNoUpdate) then
          FOnNoUpdate(Self);
      end;
    end);
end;

procedure TFMXAutoUpdater.HandleUpdateAvailable(const Info: TUpdateInfo);
begin
  // 显示更新对话�?
  TFMXUpdateDialog.ShowDialog(Self, Info,
    procedure(Action: TUpdateDialogAction)
    begin
      case Action of
        udaDownload:
          DownloadAndInstall;
        udaOpenStore:
          OpenAppStore;
        udaLater:
          ; // 用户选择稍后
        udaSkip:
          ; // 用户选择跳过此版�?
      end;
    end);
end;

procedure TFMXAutoUpdater.HandleProgress(const Progress: TUpdateProgress);
begin
  if Assigned(FOnProgress) then
    TThread.Queue(nil,
      procedure
      begin
        FOnProgress(Self, Progress);
      end);
end;

procedure TFMXAutoUpdater.DownloadAndInstall;
begin
  if FIsDownloading then
    Exit;
  
  // 移动端跳转应用商�?
  {$IF DEFINED(IOS) OR DEFINED(ANDROID)}
  OpenAppStore;
  Exit;
  {$ENDIF}
  
  FIsDownloading := True;
  
  Updater.DownloadAndInstall(FCurrentUpdateInfo,
    procedure(Success: Boolean; const ErrorMessage: string)
    begin
      FIsDownloading := False;
      
      if Assigned(FOnUpdateComplete) then
        TThread.Queue(nil,
          procedure
          begin
            FOnUpdateComplete(Self, Success, ErrorMessage);
          end);
    end);
end;

procedure TFMXAutoUpdater.DownloadOnly;
begin
  if FIsDownloading then
    Exit;
  
  FIsDownloading := True;
  
  Updater.DownloadOnly(FCurrentUpdateInfo,
    procedure(Success: Boolean; const ErrorMessage: string)
    begin
      FIsDownloading := False;
      
      if Assigned(FOnUpdateComplete) then
        TThread.Queue(nil,
          procedure
          begin
            FOnUpdateComplete(Self, Success, ErrorMessage);
          end);
    end);
end;

procedure TFMXAutoUpdater.Cancel;
begin
  Updater.Cancel;
  FIsChecking := False;
  FIsDownloading := False;
end;

procedure TFMXAutoUpdater.OpenAppStore;
var
  Url: string;
begin
  {$IF DEFINED(IOS)}
  if FAppStoreUrl <> '' then
    Url := FAppStoreUrl
  else
    Exit;
  {$ELSEIF DEFINED(ANDROID)}
  if FPlayStoreUrl <> '' then
    Url := FPlayStoreUrl
  else
    Exit;
  {$ELSE}
  // Desktop: open download URL directly
  Url := FCurrentUpdateInfo.DownloadUrl;
  {$ENDIF}
  
  if Url = '' then
    Exit;
  
  {$IFDEF MSWINDOWS}
  ShellExecute(0, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
  {$ENDIF}
  
  {$IFDEF MACOS}
  TNSWorkspace.Wrap(TNSWorkspace.OCClass.sharedWorkspace).openURL(
    TNSURL.Wrap(TNSURL.OCClass.URLWithString(StrToNSStr(Url))));
  {$ENDIF}
  
  {$IFDEF ANDROID}
  // Android: Use intent to open URL
  // MainActivity.startActivity(TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_VIEW,
  //   TJnet_Uri.JavaClass.parse(StringToJString(Url))));
  {$ENDIF}
  
  {$IFDEF IOS}
  // iOS: Use UIApplication to open URL
  // TiOSHelper.SharedApplication.openURL(TNSURL.Wrap(TNSURL.OCClass.URLWithString(StrToNSStr(Url))));
  {$ENDIF}
end;

end.
