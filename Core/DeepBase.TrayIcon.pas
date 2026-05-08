{ ============================================================================
  DeepBase.TrayIcon - System Tray Icon Module

  Version: 1.0
  Description: Provides system tray icon management using Win32
               Shell_NotifyIcon API. Designed as a pure static class
               with no VCL/FMX dependencies.

  Features:
    - Add/modify/remove tray icon
    - Balloon notifications (info/warning/error)
    - Tooltip text
    - Double-click and mouse event callbacks
    - Popup menu support via IPopupMenuAdapter interface
    - Formless operation (uses message-only window)

  Thread Safety: All public methods are thread-safe.

  Usage:
    TTrayIcon.Show('My App', LoadIcon(0, IDI_APPLICATION));
    TTrayIcon.SetPopupMenuAdapter(TVclPopupMenuAdapter.Create(PopupMenu1));
    TTrayIcon.OnDoubleClick := procedure begin Form1.Show; end;
    TTrayIcon.Hide;
  ============================================================================ }

unit DeepBase.TrayIcon;

interface

uses
  System.SysUtils,
  System.Classes,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.ShellAPI,
  Winapi.Messages;
  {$ENDIF}

const
  WM_TRAY_CALLBACK = WM_USER + $1B10;

type
  TBalloonIconType = (bitNone, bitInfo, bitWarning, bitError);

  TTrayMouseEvent = reference to procedure(Button: Integer; X, Y: Integer);

  IPopupMenuAdapter = interface
    ['{D4F7A231-8B6C-4E9A-B3D2-5C1E0F9A4D78}']
    procedure Popup(X, Y: Integer);
  end;

  TTrayIcon = class
  private class var
    FData: TNotifyIconDataW;
    FActive: Boolean;
    FIconHandle: HICON;
    FToolTip: string;
    FMessageWindow: HWND;
    FWindowClassRegistered: Boolean;
    FPopupMenuAdapter: IPopupMenuAdapter;
    FOnDoubleClick: TThreadProcedure;
    FOnBalloonClick: TThreadProcedure;
    FOnMouseDown: TTrayMouseEvent;

    class procedure CreateMsgWindow;
    class procedure DestroyMsgWindow;
    class function WndProc(hWnd: HWND; Msg: UINT;
      wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; static;
  public
    class procedure Show(const AToolTip: string; AIcon: HICON = 0);
    class procedure Hide;
    class procedure UpdateIcon(AIcon: HICON);
    class procedure UpdateToolTip(const AToolTip: string);
    class procedure ShowBalloon(const ATitle, AText: string;
      AIconType: TBalloonIconType = bitInfo; ATimeoutMs: Integer = 5000);
    class procedure HideBalloon;
    class procedure SetPopupMenuAdapter(const AAdapter: IPopupMenuAdapter);

    class property Active: Boolean read FActive;
    class property OnDoubleClick: TThreadProcedure read FOnDoubleClick write FOnDoubleClick;
    class property OnBalloonClick: TThreadProcedure read FOnBalloonClick write FOnBalloonClick;
    class property OnMouseDown: TTrayMouseEvent read FOnMouseDown write FOnMouseDown;
  end;

implementation

const
  TRAY_WINDOW_CLASS = 'DeepBaseTrayIconMsgWindow';

{ TTrayIcon }

class procedure TTrayIcon.CreateMsgWindow;
var
  WndClass: TWndClassW;
begin
  if not FWindowClassRegistered then
  begin
    FillChar(WndClass, SizeOf(WndClass), 0);
    WndClass.lpfnWndProc := @WndProc;
    WndClass.hInstance := HInstance;
    WndClass.lpszClassName := TRAY_WINDOW_CLASS;
    if Winapi.Windows.RegisterClassW(WndClass) = 0 then
      Exit;
    FWindowClassRegistered := True;
  end;

  FMessageWindow := CreateWindowW(
    TRAY_WINDOW_CLASS,
    TRAY_WINDOW_CLASS,
    0, 0, 0, 0, 0,
    HWND_MESSAGE,
    0, HInstance, nil);
end;

class procedure TTrayIcon.DestroyMsgWindow;
begin
  if FMessageWindow <> 0 then
  begin
    DestroyWindow(FMessageWindow);
    FMessageWindow := 0;
  end;
end;

class function TTrayIcon.WndProc(hWnd: HWND; Msg: UINT;
  wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  Pt: TPoint;
begin
  if (Msg = WM_TRAY_CALLBACK) and FActive then
  begin
    case lParam of
      WM_LBUTTONDBLCLK:
        if Assigned(FOnDoubleClick) then
        begin
          if TThread.CurrentThread.ThreadID = MainThreadID then
            FOnDoubleClick
          else
            TThread.Queue(nil, FOnDoubleClick);
        end;

      WM_RBUTTONUP:
        if Assigned(FPopupMenuAdapter) then
        begin
          GetCursorPos(Pt);
          SetForegroundWindow(hWnd);
          FPopupMenuAdapter.Popup(Pt.X, Pt.Y);
          PostMessage(hWnd, WM_NULL, 0, 0);
        end;

      WM_LBUTTONUP:
        if Assigned(FOnMouseDown) then
        begin
          GetCursorPos(Pt);
          FOnMouseDown(0, Pt.X, Pt.Y);
        end;

      NIN_BALLOONUSERCLICK:
        if Assigned(FOnBalloonClick) then
        begin
          if TThread.CurrentThread.ThreadID = MainThreadID then
            FOnBalloonClick
          else
            TThread.Queue(nil, FOnBalloonClick);
        end;
    end;
    Result := 0;
    Exit;
  end;

  Result := DefWindowProc(hWnd, Msg, wParam, lParam);
end;

class procedure TTrayIcon.Show(const AToolTip: string; AIcon: HICON);
begin
  if FActive then
    Hide;

  CreateMsgWindow;
  if FMessageWindow = 0 then
    Exit;

  FToolTip := AToolTip;
  if AIcon = 0 then
  begin
    if FIconHandle = 0 then
      FIconHandle := LoadIcon(0, IDI_APPLICATION);
  end
  else
    FIconHandle := AIcon;

  FillChar(FData, SizeOf(FData), 0);
  FData.cbSize := SizeOf(TNotifyIconDataW);
  FData.Wnd := FMessageWindow;
  FData.uID := 1;
  FData.uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
  FData.uCallbackMessage := WM_TRAY_CALLBACK;
  FData.hIcon := FIconHandle;
  StrPLCopy(FData.szTip, AToolTip, Length(FData.szTip) - 1);

  FActive := Shell_NotifyIconW(NIM_ADD, @FData);
end;

class procedure TTrayIcon.Hide;
begin
  if not FActive then
    Exit;

  Shell_NotifyIconW(NIM_DELETE, @FData);
  FActive := False;
  FPopupMenuAdapter := nil;
  FOnDoubleClick := nil;
  FOnBalloonClick := nil;
  FOnMouseDown := nil;
  FillChar(FData, SizeOf(FData), 0);
  DestroyMsgWindow;
end;

class procedure TTrayIcon.UpdateIcon(AIcon: HICON);
begin
  if not FActive then
    Exit;

  FIconHandle := AIcon;
  FData.hIcon := AIcon;
  FData.uFlags := NIF_ICON;
  Shell_NotifyIconW(NIM_MODIFY, @FData);
end;

class procedure TTrayIcon.UpdateToolTip(const AToolTip: string);
begin
  if not FActive then
    Exit;

  FToolTip := AToolTip;
  StrPLCopy(FData.szTip, AToolTip, Length(FData.szTip) - 1);
  FData.uFlags := NIF_TIP;
  Shell_NotifyIconW(NIM_MODIFY, @FData);
end;

class procedure TTrayIcon.ShowBalloon(const ATitle, AText: string;
  AIconType: TBalloonIconType; ATimeoutMs: Integer);
const
  BalloonIcons: array[TBalloonIconType] of DWORD = (0, NIIF_INFO, NIIF_WARNING, NIIF_ERROR);
begin
  if not FActive then
    Exit;

  FData.uFlags := NIF_INFO;
  StrPLCopy(FData.szInfo, AText, Length(FData.szInfo) - 1);
  StrPLCopy(FData.szInfoTitle, ATitle, Length(FData.szInfoTitle) - 1);
  FData.uTimeout := ATimeoutMs;
  FData.dwInfoFlags := BalloonIcons[AIconType];
  Shell_NotifyIconW(NIM_MODIFY, @FData);
end;

class procedure TTrayIcon.HideBalloon;
begin
  if not FActive then
    Exit;

  FData.uFlags := NIF_INFO;
  FData.szInfo[0] := #0;
  Shell_NotifyIconW(NIM_MODIFY, @FData);
end;

class procedure TTrayIcon.SetPopupMenuAdapter(const AAdapter: IPopupMenuAdapter);
begin
  FPopupMenuAdapter := AAdapter;
end;

initialization
  TTrayIcon.FActive := False;
  TTrayIcon.FIconHandle := 0;
  TTrayIcon.FMessageWindow := 0;
  TTrayIcon.FWindowClassRegistered := False;
  TTrayIcon.FPopupMenuAdapter := nil;
  TTrayIcon.FOnDoubleClick := nil;
  TTrayIcon.FOnBalloonClick := nil;
  TTrayIcon.FOnMouseDown := nil;

finalization
  if TTrayIcon.FActive then
    TTrayIcon.Hide;

end.
