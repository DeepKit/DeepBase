{ ============================================================================
  DeepBase.VCL.UIHelper - VCL UI 辅助工具
  
  版本: 0.3
  说明: 提供 Windows 11 Mica/Acrylic 等现代 UI 效果的支持
  ============================================================================ }

unit DeepBase.VCL.UIHelper;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.Graphics;

type
  TDeepBaseUIHelper = class
  public
    /// <summary>
    /// 尝试在指定窗体上启用 Mica 效果 (Windows 11)
    /// </summary>
    class function ApplyMicaEffect(AForm: TForm; IsDark: Boolean = False): Boolean;
    
    /// <summary>
    /// 设置标题栏颜色模式
    /// </summary>
    class procedure SetTitleBarMode(AForm: TForm; IsDark: Boolean);
  end;

implementation

const
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
  DWMWA_MICA_EFFECT = 1029; // Undocumented old Mica
  DWMWA_SYSTEMBACKDROP_TYPE = 38; // Windows 11 22H2+
  
  DWMSBT_AUTO = 0;
  DWMSBT_NONE = 1;
  DWMSBT_MAINWINDOW = 2; // Mica
  DWMSBT_TRANSIENTWINDOW = 3; // Acrylic
  DWMSBT_TABBEDWINDOW = 4; // Mica Alt

function DwmSetWindowAttribute(hwnd: HWND; dwAttribute: DWORD; pvAttribute: LPCVOID; cbAttribute: DWORD): HRESULT; stdcall; external 'dwmapi.dll';

{ TDeepBaseUIHelper }

class function TDeepBaseUIHelper.ApplyMicaEffect(AForm: TForm; IsDark: Boolean): Boolean;
var
  BackdropType: Integer;
  TrueValue: Integer;
  Res: HRESULT;
begin
  Result := False;
  
  // 1. Set Title Bar Color Mode
  SetTitleBarMode(AForm, IsDark);
  
  // 2. Try Windows 11 22H2+ Method (SystemBackdropType)
  BackdropType := DWMSBT_MAINWINDOW; // Mica
  Res := DwmSetWindowAttribute(AForm.Handle, DWMWA_SYSTEMBACKDROP_TYPE, @BackdropType, SizeOf(BackdropType));
  
  if Res = S_OK then
  begin
    Result := True;
  end
  else
  begin
    // 3. Try Old Windows 11 Method (Undocumented Mica)
    TrueValue := 1;
    Res := DwmSetWindowAttribute(AForm.Handle, DWMWA_MICA_EFFECT, @TrueValue, SizeOf(TrueValue));
    if Res = S_OK then
      Result := True;
  end;
  
  if Result then
  begin
    // Mica requires transparent background to show through
    AForm.Color := clBlack; // Or clWhite, doesn't matter much but strictly should be handled by OS
    // Actually for Mica, the client area needs to be effectively transparent or handled by OS.
    // In VCL, usually leaving Color as clBtnFace blocks it unless we do something else.
    // But DwmSetWindowAttribute usually handles the background *if* the app doesn't paint over it entirely opaquely.
    // VCL Forms paint background. We might need to set AlphaBlend? No, that makes whole window transparent.
    // For VCL, simply setting this attribute works on standard forms, but components (Panels) will block it.
    // User needs to make sure panels are not covering everything or are semi-transparent (difficult in VCL).
    // We'll leave AForm.Color alone for now or set to clNone? No clNone.
  end;
end;

class procedure TDeepBaseUIHelper.SetTitleBarMode(AForm: TForm; IsDark: Boolean);
var
  DarkMode: Integer;
begin
  if IsDark then DarkMode := 1 else DarkMode := 0;
  DwmSetWindowAttribute(AForm.Handle, DWMWA_USE_IMMERSIVE_DARK_MODE, @DarkMode, SizeOf(DarkMode));
end;

end.
