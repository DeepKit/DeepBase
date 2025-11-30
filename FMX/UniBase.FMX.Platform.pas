unit UniBase.FMX.Platform;

{*******************************************************************************
  UniBase FMX Platform - Cross-Platform Adapter

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
  FMX.Types, FMX.Platform, FMX.Forms;

type
  /// <summary>Platform type enumeration</summary>
  TUniPlatform = (
    upWindows,
    upMacOS,
    upAndroid,
    upiOS,
    upLinux,
    upUnknown
  );

  /// <summary>Device type enumeration</summary>
  TUniDeviceType = (
    udtDesktop,
    udtPhone,
    udtTablet,
    udtUnknown
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

    class procedure DetectPlatform;
    class procedure DetectDeviceType;
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
  Macapi.Helpers,
  {$ENDIF}
  FMX.Clipboard;

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
  {$IFDEF MSWINDOWS}
  FPlatform := upWindows;
  {$ENDIF}
  {$IFDEF MACOS}
    {$IFDEF IOS}
    FPlatform := upiOS;
    {$ELSE}
    FPlatform := upMacOS;
    {$ENDIF}
  {$ENDIF}
  {$IFDEF ANDROID}
  FPlatform := upAndroid;
  {$ENDIF}
  {$IFDEF LINUX}
  FPlatform := upLinux;
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
  // TODO: Get safe area from UIWindow.safeAreaInsets
  {$ENDIF}

  {$IFDEF ANDROID}
  // TODO: Get safe area from WindowInsets (API 28+)
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
  Result := False;

  {$IFDEF ANDROID}
  try
    var Intent := TJIntent.JavaClass.init(TJIntent.JavaClass.ACTION_SEND);
    Intent.setType(StringToJString('text/plain'));
    Intent.putExtra(TJIntent.JavaClass.EXTRA_TEXT, StringToJString(Text));
    if Subject <> '' then
      Intent.putExtra(TJIntent.JavaClass.EXTRA_SUBJECT, StringToJString(Subject));
    TAndroidHelper.Activity.startActivity(
      TJIntent.JavaClass.createChooser(Intent, StringToJString('Share')));
    Result := True;
  except
    Result := False;
  end;
  {$ENDIF}

  {$IFDEF IOS}
  // TODO: Implement using UIActivityViewController
  {$ENDIF}

  {$IFDEF MSWINDOWS}
  // Desktop: Copy to clipboard as fallback
  Result := CopyToClipboard(Text);
  {$ENDIF}
end;

class function TUniPlatformAdapter.ShareFile(const FilePath: string): Boolean;
begin
  Result := False;
  // TODO: Implement file sharing
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

class function TUniPlatformAdapter.HasPermission(const Permission: string): Boolean;
begin
  Result := True; // Default for desktop

  {$IFDEF ANDROID}
  // TODO: Check permission using ContextCompat.checkSelfPermission
  {$ENDIF}

  {$IFDEF IOS}
  // TODO: Check permission status
  {$ENDIF}
end;

class function TUniPlatformAdapter.RequestPermission(const Permission: string): Boolean;
begin
  Result := True; // Default for desktop

  {$IFDEF ANDROID}
  // TODO: Request permission using ActivityCompat.requestPermissions
  {$ENDIF}

  {$IFDEF IOS}
  // TODO: Request permission
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
