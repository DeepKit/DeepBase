{ ============================================================================
  DeepBase.FMX.AutoUpdater - FMX 鑷姩鏇存柊缁勪欢
  
  鐗堟湰: 1.0
  璇存槑: 璺ㄥ钩鍙伴潪鍙缁勪欢锛屽皝瑁呰嚜鍔ㄦ洿鏂版牳蹇冩ā鍧楀拰 UI 浜や簰
  
  鏀寔骞冲彴:
    - Windows: 鐩存帴涓嬭浇瀹夎鍖?
    - macOS: 鐩存帴涓嬭浇 DMG/PKG
    - iOS: 璺宠浆 App Store
    - Android: 涓嬭浇 APK 鎴栬烦杞?Play Store
  ============================================================================ }

unit DeepBase.FMX.AutoUpdater;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Messaging,
  FMX.Types,
  FMX.Dialogs,
  DeepBase.Update.Contracts,
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
    
    /// <summary>鎵嬪姩妫€鏌ユ洿鏂?/summary>
    procedure CheckForUpdates;
    
    /// <summary>闈欓粯妫€鏌ユ洿鏂帮紙涓嶆樉绀哄璇濇锛?/summary>
    procedure CheckForUpdatesSilent(Callback: TCheckUpdateCallback);
    
    /// <summary>涓嬭浇骞跺畨瑁呮洿鏂?/summary>
    procedure DownloadAndInstall;
    
    /// <summary>浠呬笅杞芥洿鏂?/summary>
    procedure DownloadOnly;
    
    /// <summary>鍙栨秷褰撳墠鎿嶄綔</summary>
    procedure Cancel;
    
    /// <summary>鎵撳紑搴旂敤鍟嗗簵椤甸潰锛堢Щ鍔ㄧ锛?/summary>
    procedure OpenAppStore;
    
    /// <summary>鑾峰彇褰撳墠鏇存柊淇℃伅</summary>
    property CurrentUpdateInfo: TUpdateInfo read FCurrentUpdateInfo;
    
    /// <summary>鏄惁姝ｅ湪妫€鏌?/summary>
    property IsChecking: Boolean read FIsChecking;
    
    /// <summary>鏄惁姝ｅ湪涓嬭浇</summary>
    property IsDownloading: Boolean read FIsDownloading;
    
    /// <summary>涓婃妫€鏌ユ椂闂?/summary>
    property LastCheckTime: TDateTime read FLastCheckTime;
    
  published
    /// <summary>鏇存柊鏈嶅姟鍣?URL</summary>
    property UpdateUrl: string read FUpdateUrl write FUpdateUrl;
    
    /// <summary>褰撳墠鐗堟湰鍙?/summary>
    property CurrentVersion: string read FCurrentVersion write FCurrentVersion;
    
    /// <summary>鏇存柊棰戦亾</summary>
    property Channel: TUpdateChannel read FChannel write FChannel default ucStable;
    
    /// <summary>妫€鏌ユā寮?/summary>
    property CheckMode: TUpdateCheckMode read FCheckMode write FCheckMode default ucmOnStartup;
    
    /// <summary>鍛ㄦ湡妫€鏌ラ棿闅旓紙灏忔椂锛?/summary>
    property CheckIntervalHours: Integer read FCheckIntervalHours write FCheckIntervalHours default 24;
    
    /// <summary>鍙戠幇鏇存柊鏃惰嚜鍔ㄦ樉绀哄璇濇</summary>
    property ShowDialogOnUpdate: Boolean read FShowDialogOnUpdate write FShowDialogOnUpdate default True;
    
    /// <summary>iOS App Store URL</summary>
    property AppStoreUrl: string read FAppStoreUrl write FAppStoreUrl;
    
    /// <summary>Android Play Store URL</summary>
    property PlayStoreUrl: string read FPlayStoreUrl write FPlayStoreUrl;
    
    /// <summary>RSA 鍏挜锛堢敤浜庣鍚嶉獙璇侊級</summary>
    property PublicKey: string read FPublicKey write FPublicKey;
    
    /// <summary>鍙戠幇鏇存柊鏃惰Е鍙?/summary>
    property OnUpdateAvailable: TUpdateAvailableEvent read FOnUpdateAvailable write FOnUpdateAvailable;
    
    /// <summary>涓嬭浇杩涘害</summary>
    property OnProgress: TUpdateProgressEvent read FOnProgress write FOnProgress;
    
    /// <summary>鏇存柊瀹屾垚</summary>
    property OnUpdateComplete: TUpdateCompleteEvent read FOnUpdateComplete write FOnUpdateComplete;
    
    /// <summary>娌℃湁鏇存柊鏃惰Е鍙?/summary>
    property OnNoUpdate: TNotifyEvent read FOnNoUpdate write FOnNoUpdate;
    
    /// <summary>妫€鏌ュ嚭閿欐椂瑙﹀彂</summary>
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
    // 鍒濆鍖栨洿鏂扮鐞嗗櫒
    if FUpdateUrl <> '' then
    begin
      Updater.Initialize(FUpdateUrl, FCurrentVersion);
      Updater.Channel := FChannel;
      if FPublicKey <> '' then
        Updater.SetPublicKey(FPublicKey);
    end;
    
    // 鍚姩鏃舵鏌?
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
  Result := 'playstore'; // 鎴?'apk'
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
        
        // 瑙﹀彂浜嬩欢锛屽厑璁哥敤鎴峰鐞?
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
  // 鏄剧ず鏇存柊瀵硅瘽妗?
  TFMXUpdateDialog.ShowDialog(Self, Info,
    procedure(Action: TUpdateDialogAction)
    begin
      case Action of
        udaDownload:
          DownloadAndInstall;
        udaOpenStore:
          OpenAppStore;
        udaLater:
          ; // 鐢ㄦ埛閫夋嫨绋嶅悗
        udaSkip:
          ; // 鐢ㄦ埛閫夋嫨璺宠繃姝ょ増鏈?
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
  
  // 绉诲姩绔烦杞簲鐢ㄥ晢搴?
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
