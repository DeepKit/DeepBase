{ ============================================================================
  DeepBase.SingleInstance - Single Instance Application Support
  
  Version: 1.0
  Description: Prevents multiple instances of the application from running.
               Supports activating existing instance and passing command line
               parameters to it.
  Thread Safety: All public methods are thread-safe.
  Platform: Windows only (uses Mutex and Window messages)
  ============================================================================ }

unit DeepBase.SingleInstance;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  Winapi.Messages;

type
  /// <summary>
  /// Callback for receiving command line from new instance
  /// </summary>
  TCommandLineReceivedEvent = procedure(const CommandLine: string) of object;

  /// <summary>
  /// Single instance application helper
  /// </summary>
  TAppInstance = class
  private class var
    FMutexHandle: THandle;
    FMutexName: string;
    FIsFirstInstance: Boolean;
    FMessageWindowHandle: HWND;
    FOnCommandLineReceived: TCommandLineReceivedEvent;
    FAllowMultipleInstances: Boolean;
    
    class procedure CreateMessageWindow;
    class procedure DestroyMessageWindow;
    class function MessageWindowProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; static;
    class function GetRunningInstanceWindow: HWND;
    class procedure SendCommandLineToInstance(TargetWnd: HWND);
    
  public
    /// <summary>
    /// Check if this is the first instance of the application.
    /// Call this early in your application startup (before Application.Initialize).
    /// </summary>
    /// <param name="AppIdentifier">Unique identifier for your application (e.g. 'MyCompany.MyApp')</param>
    /// <returns>True if this is the first instance, False if another instance is already running</returns>
    class function CheckSingleInstance(const AppIdentifier: string): Boolean;
    
    /// <summary>
    /// Activate the existing instance window (bring to front).
    /// Call this when CheckSingleInstance returns False.
    /// </summary>
    /// <returns>True if existing instance was activated</returns>
    class function ActivateExistingInstance: Boolean;
    
    /// <summary>
    /// Send command line to the existing instance.
    /// The existing instance will receive OnCommandLineReceived event.
    /// </summary>
    class procedure SendToExistingInstance(const Data: string);
    
    /// <summary>
    /// Release the mutex and cleanup.
    /// Call this when your application is closing.
    /// </summary>
    class procedure Release;
    
    /// <summary>
    /// Check if current instance is the first (primary) instance
    /// </summary>
    class property IsFirstInstance: Boolean read FIsFirstInstance;
    
    /// <summary>
    /// Event fired when another instance sends command line data
    /// </summary>
    class property OnCommandLineReceived: TCommandLineReceivedEvent 
      read FOnCommandLineReceived write FOnCommandLineReceived;
    
    /// <summary>
    /// Set to True to allow multiple instances (disables single-instance check)
    /// Default is False.
    /// </summary>
    class property AllowMultipleInstances: Boolean 
      read FAllowMultipleInstances write FAllowMultipleInstances;
  end;

const
  /// <summary>
  /// Custom message ID for inter-instance communication
  /// </summary>
  WM_DeepBase_COPYDATA = WM_USER + $1B01;
  WM_DeepBase_ACTIVATE = WM_USER + $1B02;

implementation

uses
  Vcl.Forms;

const
  MESSAGE_WINDOW_CLASS = 'DeepBase_SingleInstance_MessageWindow';

var
  GWindowClassRegistered: Boolean = False;

{ TAppInstance }

class function TAppInstance.CheckSingleInstance(const AppIdentifier: string): Boolean;
begin
  // If multiple instances allowed, always return True
  if FAllowMultipleInstances then
  begin
    FIsFirstInstance := True;
    Exit(True);
  end;
  
  // Create unique mutex name
  FMutexName := 'Global\DeepBase_' + AppIdentifier;
  
  // Try to create mutex
  FMutexHandle := CreateMutex(nil, True, PChar(FMutexName));
  
  if FMutexHandle = 0 then
  begin
    // Failed to create mutex
    FIsFirstInstance := False;
    Result := False;
    Exit;
  end;
  
  // Check if mutex already existed
  if GetLastError = ERROR_ALREADY_EXISTS then
  begin
    // Another instance is running
    CloseHandle(FMutexHandle);
    FMutexHandle := 0;
    FIsFirstInstance := False;
    Result := False;
  end
  else
  begin
    // This is the first instance
    FIsFirstInstance := True;
    Result := True;
    
    // Create message window for receiving data from other instances
    CreateMessageWindow;
  end;
end;

class function TAppInstance.ActivateExistingInstance: Boolean;
var
  TargetWnd: HWND;
begin
  Result := False;
  
  TargetWnd := GetRunningInstanceWindow;
  if TargetWnd <> 0 then
  begin
    // Send activate message
    PostMessage(TargetWnd, WM_DeepBase_ACTIVATE, 0, 0);
    
    // Also send command line if any
    if ParamCount > 0 then
      SendCommandLineToInstance(TargetWnd);
      
    Result := True;
  end;
end;

class procedure TAppInstance.SendToExistingInstance(const Data: string);
var
  TargetWnd: HWND;
  CopyData: TCopyDataStruct;
  DataBytes: TBytes;
begin
  TargetWnd := GetRunningInstanceWindow;
  if TargetWnd = 0 then
    Exit;
    
  DataBytes := TEncoding.UTF8.GetBytes(Data);
  
  CopyData.dwData := WM_DeepBase_COPYDATA;
  CopyData.cbData := Length(DataBytes);
  CopyData.lpData := @DataBytes[0];
  
  SendMessage(TargetWnd, WM_COPYDATA, 0, LPARAM(@CopyData));
end;

class procedure TAppInstance.SendCommandLineToInstance(TargetWnd: HWND);
var
  CopyData: TCopyDataStruct;
  CmdLine: string;
  DataBytes: TBytes;
begin
  CmdLine := GetCommandLine;
  DataBytes := TEncoding.UTF8.GetBytes(CmdLine);
  
  CopyData.dwData := WM_DeepBase_COPYDATA;
  CopyData.cbData := Length(DataBytes);
  CopyData.lpData := @DataBytes[0];
  
  SendMessage(TargetWnd, WM_COPYDATA, 0, LPARAM(@CopyData));
end;

class function TAppInstance.GetRunningInstanceWindow: HWND;
var
  WindowName: string;
begin
  WindowName := MESSAGE_WINDOW_CLASS + '_' + FMutexName;
  Result := FindWindow(MESSAGE_WINDOW_CLASS, PChar(WindowName));
end;

class procedure TAppInstance.CreateMessageWindow;
var
  WndClass: TWndClass;
  WindowName: string;
begin
  if not GWindowClassRegistered then
  begin
    FillChar(WndClass, SizeOf(WndClass), 0);
    WndClass.lpfnWndProc := @MessageWindowProc;
    WndClass.hInstance := HInstance;
    WndClass.lpszClassName := MESSAGE_WINDOW_CLASS;
    
    if Winapi.Windows.RegisterClass(WndClass) = 0 then
      Exit;
      
    GWindowClassRegistered := True;
  end;
  
  WindowName := MESSAGE_WINDOW_CLASS + '_' + FMutexName;
  
  FMessageWindowHandle := CreateWindow(
    MESSAGE_WINDOW_CLASS,
    PChar(WindowName),
    0, 0, 0, 0, 0,
    HWND_MESSAGE,  // Message-only window
    0,
    HInstance,
    nil
  );
end;

class procedure TAppInstance.DestroyMessageWindow;
begin
  if FMessageWindowHandle <> 0 then
  begin
    DestroyWindow(FMessageWindowHandle);
    FMessageWindowHandle := 0;
  end;
end;

class function TAppInstance.MessageWindowProc(hWnd: HWND; Msg: UINT; 
  wParam: WPARAM; lParam: LPARAM): LRESULT;
var
  CopyData: PCopyDataStruct;
  ReceivedData: string;
  DataBytes: TBytes;
begin
  Result := 0;
  
  case Msg of
    WM_COPYDATA:
      begin
        CopyData := PCopyDataStruct(lParam);
        if (CopyData <> nil) and (CopyData^.dwData = WM_DeepBase_COPYDATA) then
        begin
          SetLength(DataBytes, CopyData^.cbData);
          if CopyData^.cbData > 0 then
          begin
            Move(CopyData^.lpData^, DataBytes[0], CopyData^.cbData);
            ReceivedData := TEncoding.UTF8.GetString(DataBytes);
            
            if Assigned(FOnCommandLineReceived) then
              FOnCommandLineReceived(ReceivedData);
          end;
          Result := 1;
        end;
      end;
      
    WM_DeepBase_ACTIVATE:
      begin
        // Activate the main form
        if Assigned(Application) and Assigned(Application.MainForm) then
        begin
          if Application.MainForm.WindowState = wsMinimized then
            Application.MainForm.WindowState := wsNormal;
            
          SetForegroundWindow(Application.MainForm.Handle);
          Application.BringToFront;
        end;
        Result := 1;
      end;
      
  else
    Result := DefWindowProc(hWnd, Msg, wParam, lParam);
  end;
end;

class procedure TAppInstance.Release;
begin
  DestroyMessageWindow;
  
  if FMutexHandle <> 0 then
  begin
    ReleaseMutex(FMutexHandle);
    CloseHandle(FMutexHandle);
    FMutexHandle := 0;
  end;
  
  FIsFirstInstance := False;
end;

initialization
  TAppInstance.FMutexHandle := 0;
  TAppInstance.FIsFirstInstance := False;
  TAppInstance.FAllowMultipleInstances := False;
  TAppInstance.FMessageWindowHandle := 0;

finalization
  TAppInstance.Release;

end.
