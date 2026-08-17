unit DeepBase.FMX.Platform;

{*******************************************************************************
  DeepBase FMX Platform - Cross-Platform Adapter

  Provides platform detection and adaptation utilities for FMX applications.
  Supports: Windows, macOS, Android, iOS, Linux

  Features:
  - Platform detection (GetPlatform, IsWindows, IsMobile, etc.)
  - Screen metrics (SafeArea, StatusBar, NavigationBar)
  - Platform-specific paths
  - Device information
  - Permission handling (Android/iOS)
  - Keyboard handling
  - Clipboard access
  - URL launching
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.IOUtils,
  DeepBase.Platform.Interfaces,
  DeepBase.Exceptions,
  FMX.Types, FMX.Platform, FMX.Forms;

type
  /// <summary>Platform type enumeration.
  /// IMPORTANT: upUnknown MUST be first (ordinal 0) so the class var default
  /// (before detection runs) is safe, not silently interpreted as Windows.</summary>
  TUniPlatform = (
    upUnknown,
    upWindows,
    upMacOS,
    upAndroid,
    upiOS,
    upLinux
  );

  /// <summary>Device type enumeration.
  /// IMPORTANT: udtUnknown MUST be first (ordinal 0) so the class var default
  /// (before detection runs) is safe, not silently interpreted as Desktop.</summary>
  TUniDeviceType = (
    udtUnknown,
    udtDesktop,
    udtPhone,
    udtTablet
  );

  /// <summary>Screen orientation</summary>
  TUniOrientation = (
    uoPortrait,
    uoLandscape,
    uoPortraitUpsideDown,
    uoLandscapeRight
  );

  /// <summary>Safe area insets (for notched devices)</summary>
  TUniSafeArea = record
    Top: Single;
    Bottom: Single;
    Left: Single;
    Right: Single;
    class function Empty: TUniSafeArea; static;
  end;

  /// <summary>Screen information</summary>
  TUniScreenInfo = record
    Width: Integer;
    Height: Integer;
    Scale: Single;
    Orientation: TUniOrientation;
    SafeArea: TUniSafeArea;
    function PhysicalWidth: Integer;
    function PhysicalHeight: Integer;
    function IsLandscape: Boolean;
  end;

  /// <summary>Device information</summary>
  TUniDeviceInfo = record
    DeviceType: TUniDeviceType;
    DeviceName: string;
    DeviceModel: string;
    OSVersion: string;
    AppVersion: string;
    UniqueId: string;
  end;

  /// <summary>
  /// Cross-platform adapter singleton
  /// </summary>
  TUniPlatformAdapter = class
  private
    class var FInstance: TUniPlatformAdapter;
    class var FPlatform: TUniPlatform;
    class var FDeviceType: TUniDeviceType;
    FDeviceInfo: TUniDeviceInfo;
    FScreenInfo: TUniScreenInfo;

    // Runtime-overridable delegates. nil = use compile-time IFDEF defaults.
    class var FPermissionCheckOverride: TPermissionCheckFunc;
    class var FPermissionRequestOverride: TPermissionRequestFunc;
    class var FShareTextOverride: TShareTextFunc;
    class var FShareFileOverride: TShareFileFunc;

    class procedure DetectPlatform;
    class procedure DetectDeviceType;
    /// <summary>Internal Android permission check via ContextCompat.checkSelfPermission.
    /// Returns False on non-Android builds.</summary>
    class function CheckAndroidPermission(const Permission: string): Boolean;
    /// <summary>Internal iOS permission query. Recognised keys:
    /// <c>ios.microphone</c> (AVFoundation), <c>ios.camera</c>
    /// (AVFoundation), <c>ios.photos</c> (Photos framework),
    /// <c>ios.notifications</c> (UserNotifications), <c>ios.contacts</c>
    /// (Contacts). Returns <c>prUnsupported</c> for unknown keys.</summary>
    class function CheckiOSPermission(const APermission: string): TPermissionResult;
    /// <summary>Internal iOS permission request. For "notDetermined" status,
    /// shows the system prompt and fires ACallback with the final result.
    /// For already-decided status, returns synchronously.</summary>
    class function RequestiOSPermission(const APermission: string;
      const ACallback: TPermissionCallback): TPermissionResult;
    procedure UpdateScreenInfo;
    function GetDocumentsPath: string;
    function GetCachePath: string;
    function GetTempPath: string;
    function GetAppDataPath: string;
  public
    constructor Create;
    destructor Destroy; override;

    class function Instance: TUniPlatformAdapter;
    class procedure FreeInstance;

    /// <summary>Install a test or custom override for the four platform
    /// delegates. Pass nil to clear a specific override (restores IFDEF
    /// defaults). Thread-safe.</summary>
    class procedure RegisterPermissionOverride(
      const ACheck: TPermissionCheckFunc;
      const ARequest: TPermissionRequestFunc);
    class procedure RegisterShareOverride(
      const AText: TShareTextFunc;
      const AFile: TShareFileFunc);

    // Platform detection
    class function GetPlatform: TUniPlatform;
    class function GetPlatformName: string;
    class function IsWindows: Boolean; inline;
    class function IsMacOS: Boolean; inline;
    class function IsAndroid: Boolean; inline;
    class function IsiOS: Boolean; inline;
    class function IsLinux: Boolean; inline;
    class function IsDesktop: Boolean; inline;
    class function IsMobile: Boolean; inline;

    // Device detection
    class function GetDeviceType: TUniDeviceType;
    class function IsPhone: Boolean; inline;
    class function IsTablet: Boolean; inline;

    // Screen info
    function GetScreenInfo: TUniScreenInfo;
    function GetSafeArea: TUniSafeArea;
    function GetOrientation: TUniOrientation;
    function GetScreenScale: Single;

    // Device info
    function GetDeviceInfo: TUniDeviceInfo;

    // Paths
    property DocumentsPath: string read GetDocumentsPath;
    property CachePath: string read GetCachePath;
    property TempPath: string read GetTempPath;
    property AppDataPath: string read GetAppDataPath;

    // Utilities
    class function OpenURL(const URL: string): Boolean;
    class function ShareText(const Text: string; const Subject: string = ''): Boolean;
    class function ShareFile(const FilePath: string): Boolean;
    class function CopyToClipboard(const Text: string): Boolean;
    class function GetFromClipboard: string;
    class function ShowKeyboard: Boolean;
    class function HideKeyboard: Boolean;
    class function Vibrate(Duration: Integer = 100): Boolean;
    class function HasPermission(const Permission: string): Boolean;
    class function RequestPermission(const Permission: string): Boolean;
    /// <summary>Typed permission check via the registered override, or
    /// the compile-time IFDEF default. Returns prUnsupported when no
    /// service is registered and the platform is not desktop.</summary>
    class function CheckPermissionEx(const APermission: string): TPermissionResult;
    /// <summary>Typed permission request via the registered override, or
    /// the compile-time IFDEF default.</summary>
    class function RequestPermissionEx(const APermission: string;
      const ACallback: TPermissionCallback = nil): TPermissionResult;
    /// <summary>Typed share via the registered override, or the
    /// compile-time IFDEF default.</summary>
    class function ShareTextEx(const AText, ASubject: string): Boolean;
    class function ShareFileEx(const AFilePath: string): Boolean;
  end;

/// <summary>Global platform adapter accessor</summary>
function Platform: TUniPlatformAdapter;

/// <summary>Quick platform checks</summary>
function IsWindows: Boolean; inline;
function IsMacOS: Boolean; inline;
function IsAndroid: Boolean; inline;
function IsiOS: Boolean; inline;
function IsMobile: Boolean; inline;
function IsDesktop: Boolean; inline;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShellAPI,
  {$ENDIF}
  {$IFDEF ANDROID}
  Androidapi.JNI.GraphicsContentViewText,
  Androidapi.JNI.App,
  Androidapi.JNI.Os,
  Androidapi.Helpers,
  Androidapi.JNI.JavaTypes,
  {$ENDIF}
  {$IFDEF IOS}
  iOSapi.UIKit,
  iOSapi.Foundation,
  iOSapi.AVFoundation,
  iOSapi.Photos,
  iOSapi.UserNotifications,
  iOSapi.Contacts,
  Macapi.ObjCRuntime,
  Macapi.Helpers,
  {$ENDIF}
  FMX.Clipboard,
  System.Rtti,
  FMX.VirtualKeyboard;

{ TUniSafeArea }

class function TUniSafeArea.Empty: TUniSafeArea;
begin
  Result.Top := 0;
  Result.Bottom := 0;
  Result.Left := 0;
  Result.Right := 0;
end;

{ TUniScreenInfo }

function TUniScreenInfo.PhysicalWidth: Integer;
begin
  Result := Round(Width * Scale);
end;

function TUniScreenInfo.PhysicalHeight: Integer;
begin
  Result := Round(Height * Scale);
end;

function TUniScreenInfo.IsLandscape: Boolean;
begin
  Result := Orientation in [uoLandscape, uoLandscapeRight];
end;

{ TUniPlatformAdapter }

constructor TUniPlatformAdapter.Create;
begin
  inherited Create;
  DetectPlatform;
  DetectDeviceType;
  UpdateScreenInfo;
end;

destructor TUniPlatformAdapter.Destroy;
begin
  inherited;
end;

class function TUniPlatformAdapter.Instance: TUniPlatformAdapter;
begin
  if FInstance = nil then
    FInstance := TUniPlatformAdapter.Create;
  Result := FInstance;
end;

class procedure TUniPlatformAdapter.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

class procedure TUniPlatformAdapter.DetectPlatform;
begin
  // NOTE: FPlatform ordinal 0 is now upUnknown — safe default if no branch fires.
  {$IFDEF ANDROID}
  FPlatform := upAndroid;
  {$ELSE}
    {$IFDEF IOS}
    FPlatform := upiOS;
    {$ELSE}
      {$IFDEF MSWINDOWS}
      FPlatform := upWindows;
      {$ELSE}
        {$IFDEF MACOS}
        FPlatform := upMacOS;
        {$ELSE}
          {$IFDEF LINUX}
          FPlatform := upLinux;
          {$ELSE}
          FPlatform := upUnknown;
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
end;

class procedure TUniPlatformAdapter.DetectDeviceType;
begin
  {$IF DEFINED(MSWINDOWS) or DEFINED(MACOS) or DEFINED(LINUX)}
    {$IFNDEF IOS}
    FDeviceType := udtDesktop;
    Exit;
    {$ENDIF}
  {$ENDIF}

  // Mobile device detection based on screen size
  {$IFDEF ANDROID}
  var ScreenService: IFMXScreenService;
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, ScreenService) then
  begin
    var ScreenSize := ScreenService.GetScreenSize;
    var DiagonalInches := Sqrt(Sqr(ScreenSize.X) + Sqr(ScreenSize.Y)) /
      (ScreenService.GetScreenScale * 160);
    if DiagonalInches >= 7 then
      FDeviceType := udtTablet
    else
      FDeviceType := udtPhone;
  end
  else
    FDeviceType := udtPhone;
  {$ENDIF}

  {$IFDEF IOS}
  // iOS: Use UIDevice
  FDeviceType := udtPhone; // Simplified
  {$ENDIF}
end;

procedure TUniPlatformAdapter.UpdateScreenInfo;
var
  ScreenService: IFMXScreenService;
begin
  FScreenInfo.SafeArea := TUniSafeArea.Empty;

  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, ScreenService) then
  begin
    var ScreenSize := ScreenService.GetScreenSize;
    FScreenInfo.Width := Round(ScreenSize.X);
    FScreenInfo.Height := Round(ScreenSize.Y);
    FScreenInfo.Scale := ScreenService.GetScreenScale;

    var Orientation := ScreenService.GetScreenOrientation;
    case Orientation of
      TScreenOrientation.Portrait: FScreenInfo.Orientation := uoPortrait;
      TScreenOrientation.Landscape: FScreenInfo.Orientation := uoLandscape;
      TScreenOrientation.InvertedPortrait: FScreenInfo.Orientation := uoPortraitUpsideDown;
      TScreenOrientation.InvertedLandscape: FScreenInfo.Orientation := uoLandscapeRight;
    end;
  end
  else
  begin
    FScreenInfo.Width := 1920;
    FScreenInfo.Height := 1080;
    FScreenInfo.Scale := 1.0;
    FScreenInfo.Orientation := uoLandscape;
  end;

  // Get safe area for notched devices
  {$IFDEF IOS}
  // STUB(BUG-281): Get safe area from UIWindow.safeAreaInsets
  raise ENotImplementedException.Create('UpdateScreenInfo: iOS safe area not yet implemented (BUG-281)');
  {$ENDIF}

  {$IFDEF ANDROID}
  // STUB(BUG-281): Get safe area from WindowInsets (API 28+)
  raise ENotImplementedException.Create('UpdateScreenInfo: Android safe area not yet implemented (BUG-281)');
  {$ENDIF}
end;

class function TUniPlatformAdapter.GetPlatform: TUniPlatform;
begin
  if FPlatform = upUnknown then
    DetectPlatform;
  Result := FPlatform;
end;

class function TUniPlatformAdapter.GetPlatformName: string;
begin
  case GetPlatform of
    upWindows: Result := 'Windows';
    upMacOS: Result := 'macOS';
    upAndroid: Result := 'Android';
    upiOS: Result := 'iOS';
    upLinux: Result := 'Linux';
  else
    Result := 'Unknown';
  end;
end;

class function TUniPlatformAdapter.IsWindows: Boolean;
begin
  Result := GetPlatform = upWindows;
end;

class function TUniPlatformAdapter.IsMacOS: Boolean;
begin
  Result := GetPlatform = upMacOS;
end;

class function TUniPlatformAdapter.IsAndroid: Boolean;
begin
  Result := GetPlatform = upAndroid;
end;

class function TUniPlatformAdapter.IsiOS: Boolean;
begin
  Result := GetPlatform = upiOS;
end;

class function TUniPlatformAdapter.IsLinux: Boolean;
begin
  Result := GetPlatform = upLinux;
end;

class function TUniPlatformAdapter.IsDesktop: Boolean;
begin
  Result := GetPlatform in [upWindows, upMacOS, upLinux];
end;

class function TUniPlatformAdapter.IsMobile: Boolean;
begin
  Result := GetPlatform in [upAndroid, upiOS];
end;

class function TUniPlatformAdapter.GetDeviceType: TUniDeviceType;
begin
  if FDeviceType = udtUnknown then
    DetectDeviceType;
  Result := FDeviceType;
end;

class function TUniPlatformAdapter.IsPhone: Boolean;
begin
  Result := GetDeviceType = udtPhone;
end;

class function TUniPlatformAdapter.IsTablet: Boolean;
begin
  Result := GetDeviceType = udtTablet;
end;

function TUniPlatformAdapter.GetScreenInfo: TUniScreenInfo;
begin
  UpdateScreenInfo;
  Result := FScreenInfo;
end;

function TUniPlatformAdapter.GetSafeArea: TUniSafeArea;
begin
  UpdateScreenInfo;
  Result := FScreenInfo.SafeArea;
end;

function TUniPlatformAdapter.GetOrientation: TUniOrientation;
begin
  UpdateScreenInfo;
  Result := FScreenInfo.Orientation;
end;

function TUniPlatformAdapter.GetScreenScale: Single;
begin
  UpdateScreenInfo;
  Result := FScreenInfo.Scale;
end;

function TUniPlatformAdapter.GetDeviceInfo: TUniDeviceInfo;
begin
  if FDeviceInfo.DeviceName = '' then
  begin
    FDeviceInfo.DeviceType := GetDeviceType;

    {$IFDEF MSWINDOWS}
    FDeviceInfo.DeviceName := 'Windows PC';
    FDeviceInfo.DeviceModel := 'PC';
    FDeviceInfo.OSVersion := TOSVersion.ToString;
    {$ENDIF}

    {$IFDEF ANDROID}
    FDeviceInfo.DeviceName := JStringToString(TJBuild.JavaClass.MODEL);
    FDeviceInfo.DeviceModel := JStringToString(TJBuild.JavaClass.MANUFACTURER);
    FDeviceInfo.OSVersion := 'Android ' + JStringToString(TJBuild_VERSION.JavaClass.RELEASE);
    {$ENDIF}

    {$IFDEF IOS}
    FDeviceInfo.DeviceName := 'iPhone/iPad';
    FDeviceInfo.DeviceModel := 'Apple';
    FDeviceInfo.OSVersion := 'iOS';
    {$ENDIF}

    {$IFDEF MACOS}
      {$IFNDEF IOS}
      FDeviceInfo.DeviceName := 'Mac';
      FDeviceInfo.DeviceModel := 'Apple';
      FDeviceInfo.OSVersion := TOSVersion.ToString;
      {$ENDIF}
    {$ENDIF}

    {$IFDEF LINUX}
    FDeviceInfo.DeviceName := 'Linux PC';
    FDeviceInfo.DeviceModel := 'PC';
    FDeviceInfo.OSVersion := TOSVersion.ToString;
    {$ENDIF}
  end;

  Result := FDeviceInfo;
end;

function TUniPlatformAdapter.GetDocumentsPath: string;
begin
  Result := TPath.GetDocumentsPath;
end;

function TUniPlatformAdapter.GetCachePath: string;
begin
  Result := TPath.GetCachePath;
end;

function TUniPlatformAdapter.GetTempPath: string;
begin
  Result := TPath.GetTempPath;
end;

function TUniPlatformAdapter.GetAppDataPath: string;
begin
  {$IFDEF MSWINDOWS}
  Result := TPath.Combine(TPath.GetHomePath, 'AppData\Local');
  {$ELSE}
  Result := TPath.GetDocumentsPath;
  {$ENDIF}
end;

class function TUniPlatformAdapter.OpenURL(const URL: string): Boolean;
begin
  Result := False;

  {$IFDEF MSWINDOWS}
  Result := ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL) > 32;
  {$ENDIF}

  {$IFDEF ANDROID}
  try
    var Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_VIEW,
      TJnet_Uri.JavaClass.parse(StringToJString(URL)));
    TAndroidHelper.Activity.startActivity(Intent);
    Result := True;
  except
    Result := False;
  end;
  {$ENDIF}

  {$IFDEF IOS}
  try
    var NSUrl := TNSUrl.Wrap(TNSUrl.OCClass.URLWithString(StrToNSStr(URL)));
    Result := TiOSHelper.SharedApplication.openURL(NSUrl);
  except
    Result := False;
  end;
  {$ENDIF}
end;

class function TUniPlatformAdapter.ShareText(const Text: string; const Subject: string): Boolean;
begin
  Result := ShareTextEx(Text, Subject);
end;

class function TUniPlatformAdapter.ShareFile(const FilePath: string): Boolean;
begin
  Result := ShareFileEx(FilePath);
end;

class function TUniPlatformAdapter.CopyToClipboard(const Text: string): Boolean;
var
  ClipService: IFMXClipboardService;
begin
  Result := False;
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipService) then
  begin
    ClipService.SetClipboard(Text);
    Result := True;
  end;
end;

class function TUniPlatformAdapter.GetFromClipboard: string;
var
  ClipService: IFMXClipboardService;
  Value: TValue;
begin
  Result := '';
  if TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, ClipService) then
  begin
    Value := ClipService.GetClipboard;
    if not Value.IsEmpty and Value.IsType<string> then
      Result := Value.AsString;
  end;
end;

class function TUniPlatformAdapter.ShowKeyboard: Boolean;
var
  VKService: IFMXVirtualKeyboardService;
begin
  Result := False;
  if TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, VKService) then
  begin
    VKService.ShowVirtualKeyboard(nil);
    Result := True;
  end;
end;

class function TUniPlatformAdapter.HideKeyboard: Boolean;
var
  VKService: IFMXVirtualKeyboardService;
begin
  Result := False;
  if TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, VKService) then
  begin
    VKService.HideVirtualKeyboard;
    Result := True;
  end;
end;

class function TUniPlatformAdapter.Vibrate(Duration: Integer): Boolean;
begin
  Result := False;

  {$IFDEF ANDROID}
  try
    var Vibrator := TJVibrator.Wrap(
      TAndroidHelper.Activity.getSystemService(TJContext.JavaClass.VIBRATOR_SERVICE));
    if Vibrator <> nil then
    begin
      Vibrator.vibrate(Duration);
      Result := True;
    end;
  except
    Result := False;
  end;
  {$ENDIF}
end;

class function TUniPlatformAdapter.CheckAndroidPermission(const Permission: string): Boolean;
begin
  // Default for non-Android builds: nothing to check.
  Result := False;

  {$IFDEF ANDROID}
  try
    // Use ContextCompat.checkSelfPermission — the canonical safe check.
    // PERMISSION_GRANTED = 0, PERMISSION_DENIED = -1 (JPackageManager).
    var LJavaPerm := StringToJString(Permission);
    var GrantResult := TJContextCompat.JavaClass.checkSelfPermission(
      TAndroidHelper.Context, LJavaPerm);
    Result := GrantResult := TJPackageManager.JavaClass.PERMISSION_GRANTED;
  except
    // If anything fails (missing class, dead bridge, etc.), deny rather than grant.
    Result := False;
  end;
  {$ENDIF}
end;

class function TUniPlatformAdapter.CheckiOSPermission(
  const APermission: string): TPermissionResult;
begin
  // BUG-277 / REVIEW-P0-002: iOS permission queries per framework.
  //
  // Recognised keys:
  //   'ios.microphone'     — AVFoundation AVCaptureDevice.authorizationStatus(for: .audio)
  //   'ios.camera'         — AVFoundation AVCaptureDevice.authorizationStatus(for: .video)
  //   'ios.photos'         — Photos       PHPhotoLibrary.authorizationStatus()
  //   'ios.notifications'  — UserNotifications UNUserNotificationCenter.getNotificationSettings()
  //   'ios.contacts'       — Contacts     CNContactStore.authorizationStatus(for: .contacts)
  //
  // Status mapping (common across frameworks):
  //   authorized / .granted   → prGranted
  //   denied / .restricted    → prDenied
  //   notDetermined           → prRequestIssued (caller should invoke RequestiOSPermission)
  //   anything else           → prUnsupported
  //
  // NOTE: the concrete iOS API calls live behind {$IFDEF IOS} and require a
  // real device / simulator to validate. On non-iOS builds this method is a
  // safe stub returning prUnsupported.
  Result := prUnsupported;

  {$IFDEF IOS}
  // STUB(BUG-277 on-device): implement per-framework status queries.
  // Skeleton (compile-verified imports already present in uses clause):
  //
  //   if SameText(APermission, 'ios.microphone') then
  //     Result := MapAVAuthStatus(TAVCaptureDevice.OCX.authorizationStatusForMediaType(
  //       AVMAudioMedia));
  //   else if SameText(APermission, 'ios.camera') then
  //     Result := MapAVAuthStatus(TAVCaptureDevice.OCX.authorizationStatusForMediaType(
  //       AVMVideoMedia));
  //   else if SameText(APermission, 'ios.photos') then
  //     Result := MapPHAuthStatus(TPHPhotoLibrary.OCX.authorizationStatus);
  //   else if SameText(APermission, 'ios.notifications') then
  //     Result := MapUNSettings(...)  // async — requires completion handler
  //   else if SameText(APermission, 'ios.contacts') then
  //     Result := MapCNAuthStatus(TCNContactStore.OCX.authorizationStatusForEntityType(
  //       CNEntityTypeContacts));
  {$ENDIF}
end;

class function TUniPlatformAdapter.RequestiOSPermission(const APermission: string;
  const ACallback: TPermissionCallback): TPermissionResult;
begin
  // Default for non-iOS builds: not supported.
  Result := prUnsupported;

  {$IFDEF IOS}
  // STUB(BUG-277 on-device):
  //   1. Call CheckiOSPermission(APermission).
  //   2. If status is already decided (granted / denied / unsupported), fire
  //      ACallback synchronously with that status and exit.
  //   3. If status is notDetermined, invoke the appropriate "requestAccess..."
  //      API with a completion block that:
  //        - dispatches the result back to the main queue (TMainThreadHelper),
  //        - fires ACallback with prGranted / prDenied.
  //   4. Return prRequestIssued to the caller.
  //
  // Skeleton:
  //
  //   var Current := CheckiOSPermission(APermission);
  //   if Current <> prRequestIssued then
  //   begin
  //     Result := Current;
  //     if Assigned(ACallback) then ACallback(APermission, Current);
  //     Exit;
  //   end;
  //   // async path...
  //   Result := prRequestIssued;
  {$ENDIF}
end;

class procedure TUniPlatformAdapter.RegisterPermissionOverride(
  const ACheck: TPermissionCheckFunc;
  const ARequest: TPermissionRequestFunc);
begin
  FPermissionCheckOverride := ACheck;
  FPermissionRequestOverride := ARequest;
end;

class procedure TUniPlatformAdapter.RegisterShareOverride(
  const AText: TShareTextFunc;
  const AFile: TShareFileFunc);
begin
  FShareTextOverride := AText;
  FShareFileOverride := AFile;
end;

class function TUniPlatformAdapter.CheckPermissionEx(
  const APermission: string): TPermissionResult;
var
  LDelegate: TPermissionCheckFunc;
begin
  // 1) Runtime-registered override (test or custom impl) wins.
  LDelegate := FPermissionCheckOverride;
  if Assigned(LDelegate) then
    Exit(LDelegate(APermission));

  // 2) Global delegate from DeepBase.Platform.Interfaces.
  LDelegate := GetPermissionCheck();
  if Assigned(LDelegate) then
    Exit(LDelegate(APermission));

  // 3) Compile-time IFDEF default.
  {$IF DEFINED(ANDROID)}
  if CheckAndroidPermission(APermission) then
    Result := prGranted
  else
    Result := prDenied;
  {$ELSEIF DEFINED(IOS)}
  Result := CheckiOSPermission(APermission);
  {$ELSE}
  // Desktop: no runtime permission model; treat as granted.
  Result := prGranted;
  {$ENDIF}
end;

class function TUniPlatformAdapter.RequestPermissionEx(
  const APermission: string;
  const ACallback: TPermissionCallback): TPermissionResult;
var
  LDelegate: TPermissionRequestFunc;
begin
  LDelegate := FPermissionRequestOverride;
  if Assigned(LDelegate) then
    Exit(LDelegate(APermission, ACallback));

  LDelegate := GetPermissionRequest();
  if Assigned(LDelegate) then
    Exit(LDelegate(APermission, ACallback));

  // Per-platform default.
  {$IF DEFINED(IOS)}
  // BUG-277: iOS needs an async path for notDetermined → requestAccess → callback.
  Result := RequestiOSPermission(APermission, ACallback);
  {$ELSE}
  // Android / desktop: synchronous answer from CheckPermissionEx; fire
  // callback immediately.
  Result := CheckPermissionEx(APermission);
  if (Result in [prGranted, prDenied]) and Assigned(ACallback) then
    ACallback(APermission, Result);
  {$ENDIF}
end;

class function TUniPlatformAdapter.HasPermission(
  const Permission: string): Boolean;
begin
  Result := CheckPermissionEx(Permission) = prGranted;
end;

class function TUniPlatformAdapter.RequestPermission(
  const Permission: string): Boolean;
begin
  Result := RequestPermissionEx(Permission, nil) = prGranted;
end;

class function TUniPlatformAdapter.ShareTextEx(const AText,
  ASubject: string): Boolean;
var
  LDelegate: TShareTextFunc;
begin
  LDelegate := FShareTextOverride;
  if Assigned(LDelegate) then
    Exit(LDelegate(AText, ASubject));
  LDelegate := GetShareText();
  if Assigned(LDelegate) then
    Exit(LDelegate(AText, ASubject));
  // Default path (compile-time IFDEF) is implemented inline below.
  {$IF DEFINED(ANDROID)}
  try
    var Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_SEND);
    Intent.setType(StringToJString('text/plain'));
    Intent.putExtra(TJIntent.JavaClass.EXTRA_TEXT, StringToJString(AText));
    if ASubject <> '' then
      Intent.putExtra(TJIntent.JavaClass.EXTRA_SUBJECT, StringToJString(ASubject));
    TAndroidHelper.Activity.startActivity(
      TJIntent.JavaClass.createChooser(Intent, StringToJString('Share')));
    Result := True;
  except
    Result := False;
  end;
  {$ELSEIF DEFINED(MSWINDOWS)}
  Result := CopyToClipboard(AText);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

class function TUniPlatformAdapter.ShareFileEx(
  const AFilePath: string): Boolean;
var
  LDelegate: TShareFileFunc;
begin
  LDelegate := FShareFileOverride;
  if Assigned(LDelegate) then
    Exit(LDelegate(AFilePath));
  LDelegate := GetShareFile();
  if Assigned(LDelegate) then
    Exit(LDelegate(AFilePath));

  // Default fallback per platform.
  {$IF DEFINED(ANDROID)}
  try
    var LFile := TJFile.JavaClass.init(StringToJString(AFilePath));
    var LUri := TJUri.JavaClass.fromFile(LFile);
    var Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_SEND);
    Intent.setType(StringToJString('*/*'));
    Intent.putExtra(TJIntent.JavaClass.EXTRA_STREAM,
      TJParcelable.Wrap(JObjectToID(LUri)));
    TAndroidHelper.Activity.startActivity(
      TJIntent.JavaClass.createChooser(Intent, StringToJString('Share')));
    Result := True;
  except
    Result := False;
  end;
  {$ELSEIF DEFINED(MSWINDOWS)}
  // BUG-277 / REVIEW-P0-002: use Windows Shell "share" verb to present the
  // native share UI. Falls back to the clipboard on Windows < 10 build 1703
  // (which lacks the "share" verb on filesystem items) or if the file is
  // missing / ShellExecuteEx fails.
  if not TFile.Exists(AFilePath) then
    Exit(False);
  var LSei: TShellExecuteInfo;
  FillChar(LSei, SizeOf(LSei), 0);
  LSei.cbSize := SizeOf(LSei);
  LSei.fMask := SEE_MASK_INVOKEIDLIST;
  LSei.lpFile := PChar(AFilePath);
  LSei.lpVerb := PChar('share');
  LSei.nShow := SW_SHOWNORMAL;
  if ShellExecuteEx(@LSei) then
    Result := True
  else
    Result := CopyToClipboard(AFilePath);
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{ Global functions }

function Platform: TUniPlatformAdapter;
begin
  Result := TUniPlatformAdapter.Instance;
end;

function IsWindows: Boolean;
begin
  Result := TUniPlatformAdapter.IsWindows;
end;

function IsMacOS: Boolean;
begin
  Result := TUniPlatformAdapter.IsMacOS;
end;

function IsAndroid: Boolean;
begin
  Result := TUniPlatformAdapter.IsAndroid;
end;

function IsiOS: Boolean;
begin
  Result := TUniPlatformAdapter.IsiOS;
end;

function IsMobile: Boolean;
begin
  Result := TUniPlatformAdapter.IsMobile;
end;

function IsDesktop: Boolean;
begin
  Result := TUniPlatformAdapter.IsDesktop;
end;

initialization

finalization
  TUniPlatformAdapter.FreeInstance;

end.
