{ ============================================================================
  DeepBase.FormState - Form State Management Module
  
  Version: 1.0
  Description: Provides persistent storage for form position, size and state.
  Note: This is a Core layer module, does not depend on VCL/FMX. Actual UI
        binding is implemented by upper layer components.
  ============================================================================ }

unit DeepBase.FormState;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Rtti,
  System.Types,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  Winapi.MultiMon,
  {$ENDIF}
  DeepBase.Types,
  DeepBase.Storage.Interfaces;

type
  TFormStateData = DeepBase.Storage.Interfaces.TFormStateData;

  /// <summary>
  /// Form state manager
  /// </summary>
  TDeepBaseFormState = class
  private
    FConnection: TObject;
    FStorage: IFormStateStorage;
    FLock: TObject;
    FOwnsLock: Boolean;
    class var FConnectionStorageFactory: TFunc<TObject, IFormStateStorage>;
    
    procedure WriteToDB(const FormName: string; const Data: TFormStateData);
    function ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
    class function CreateStorageFromConnection(
      AConnection: TObject): IFormStateStorage; static;
    
  public
    constructor Create(AConnection: TObject; ALock: TObject = nil); overload;
    constructor Create(const AStorage: IFormStateStorage;
      ALock: TObject = nil); overload;
    destructor Destroy; override;
    
    class procedure SetConnectionStorageFactory(
      const AFactory: TFunc<TObject, IFormStateStorage>); static;
    
    /// <summary>
    /// Save form state
    /// </summary>
    procedure SaveState(const FormName: string; const Data: TFormStateData);
    
    /// <summary>
    /// Restore form state
    /// </summary>
    function RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
    
    /// <summary>
    /// Delete form state
    /// </summary>
    procedure DeleteState(const FormName: string);
    
    /// <summary>
    /// Check if state exists
    /// </summary>
    function HasState(const FormName: string): Boolean;
    
    /// <summary>
    /// Get all saved form names
    /// </summary>
    function GetAllFormNames: TArray<string>;
    
    /// <summary>
    /// Clear all states
    /// </summary>
    procedure ClearAll;
    
    {$IFDEF MSWINDOWS}
    // ========================================
    // High-level VCL Form API
    // ========================================
    
    /// <summary>
    /// Save form state directly from a TForm
    /// </summary>
    procedure SaveFormState(AForm: TObject; const ExtraData: string = '');
    
    /// <summary>
    /// Restore form state directly to a TForm
    /// </summary>
    procedure RestoreFormState(AForm: TObject);
    
    /// <summary>
    /// Delete form state by form name
    /// </summary>
    procedure DeleteFormState(const FormName: string);
    
    /// <summary>
    /// Check if form state exists
    /// </summary>
    function FormStateExists(const FormName: string): Boolean;
    
    /// <summary>
    /// Get extra data for a form
    /// </summary>
    function GetFormStateExtra(const FormName: string): string;
    {$ENDIF}
  end;

implementation

{ TDeepBaseFormState }

constructor TDeepBaseFormState.Create(AConnection: TObject; ALock: TObject);
begin
  Create(CreateStorageFromConnection(AConnection), ALock);
  FConnection := AConnection;
end;

constructor TDeepBaseFormState.Create(const AStorage: IFormStateStorage;
  ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if ALock <> nil then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
end;

destructor TDeepBaseFormState.Destroy;
begin
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

class procedure TDeepBaseFormState.SetConnectionStorageFactory(
  const AFactory: TFunc<TObject, IFormStateStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

class function TDeepBaseFormState.CreateStorageFromConnection(
  AConnection: TObject): IFormStateStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);
  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No form-state storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.FormState.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
end;

procedure TDeepBaseFormState.SaveState(const FormName: string; const Data: TFormStateData);
begin
  TMonitor.Enter(FLock);
  try
    WriteToDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseFormState.RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := ReadFromDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseFormState.DeleteState(const FormName: string);
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      FStorage.DeleteState(FormName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseFormState.WriteToDB(const FormName: string; const Data: TFormStateData);
begin
  if Assigned(FStorage) then
    FStorage.WriteState(FormName, Data);
end;

function TDeepBaseFormState.ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
begin
  if Assigned(FStorage) then
    Result := FStorage.ReadState(FormName, Data)
  else
  begin
    Data.Init;
    Result := False;
  end;
end;

function TDeepBaseFormState.HasState(const FormName: string): Boolean;
begin
  Result := False;
    
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      Result := FStorage.StateExists(FormName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseFormState.GetAllFormNames: TArray<string>;
begin
  Result := nil;
    
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      Result := FStorage.ReadFormNames;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseFormState.ClearAll;
begin
  TMonitor.Enter(FLock);
  try
    if Assigned(FStorage) then
      FStorage.ClearAll;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{$IFDEF MSWINDOWS}
// ============================================================================
// High-level VCL Form API
// ============================================================================

type
  // 使用记录访问 TForm 的属性，避免直接依赖 Vcl.Forms
  TFormAccessor = class
  private
    class var FCtx: System.Rtti.TRttiContext;
    class var FCtxInitialized: Boolean;
    class function GetRttiContext: System.Rtti.TRttiContext; static;
  public
    class function GetFormName(AForm: TObject): string;
    class function GetFormHandle(AForm: TObject): HWND;
    class function GetFormBounds(AForm: TObject): TRect;
    class function GetFormWindowState(AForm: TObject): Integer; // 0=Normal, 1=Min, 2=Max
    class function GetFormMonitorIndex(AForm: TObject): Integer;
    class procedure SetFormBounds(AForm: TObject; const R: TRect);
    class procedure SetFormWindowState(AForm: TObject; State: Integer);
  end;

class function TFormAccessor.GetRttiContext: System.Rtti.TRttiContext;
begin
  if not FCtxInitialized then
  begin
    FCtx := System.Rtti.TRttiContext.Create;
    FCtxInitialized := True;
  end;
  Result := FCtx;
end;

class function TFormAccessor.GetFormName(AForm: TObject): string;
var
  Ctx: System.Rtti.TRttiContext;
  Prop: System.Rtti.TRttiProperty;
begin
  Result := '';
  if AForm = nil then Exit;
  
  // 使用 RTTI 获取 Name 属性
  if AForm.ClassName.Contains('Form') then
  begin
    Ctx := GetRttiContext;
    Prop := Ctx.GetType(AForm.ClassType).GetProperty('Name');
    if Prop <> nil then
      Result := Prop.GetValue(AForm).AsString;
  end;
end;

class function TFormAccessor.GetFormHandle(AForm: TObject): HWND;
var
  Ctx: System.Rtti.TRttiContext;
  Prop: System.Rtti.TRttiProperty;
begin
  Result := 0;
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  Prop := Ctx.GetType(AForm.ClassType).GetProperty('Handle');
  if Prop <> nil then
    Result := HWND(Prop.GetValue(AForm).AsOrdinal);
end;

class function TFormAccessor.GetFormBounds(AForm: TObject): TRect;
var
  Ctx: System.Rtti.TRttiContext;
  RttiType: System.Rtti.TRttiType;
  PropLeft, PropTop, PropWidth, PropHeight: System.Rtti.TRttiProperty;
begin
  Result := TRect.Empty;
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  RttiType := Ctx.GetType(AForm.ClassType);
  PropLeft := RttiType.GetProperty('Left');
  PropTop := RttiType.GetProperty('Top');
  PropWidth := RttiType.GetProperty('Width');
  PropHeight := RttiType.GetProperty('Height');
  
  if (PropLeft <> nil) and (PropTop <> nil) and 
     (PropWidth <> nil) and (PropHeight <> nil) then
  begin
    Result.Left := PropLeft.GetValue(AForm).AsInteger;
    Result.Top := PropTop.GetValue(AForm).AsInteger;
    Result.Width := PropWidth.GetValue(AForm).AsInteger;
    Result.Height := PropHeight.GetValue(AForm).AsInteger;
  end;
end;

class function TFormAccessor.GetFormWindowState(AForm: TObject): Integer;
var
  Ctx: System.Rtti.TRttiContext;
  Prop: System.Rtti.TRttiProperty;
begin
  Result := 0; // wsNormal
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  Prop := Ctx.GetType(AForm.ClassType).GetProperty('WindowState');
  if Prop <> nil then
    Result := Prop.GetValue(AForm).AsOrdinal;
end;

class function TFormAccessor.GetFormMonitorIndex(AForm: TObject): Integer;
var
  Ctx: System.Rtti.TRttiContext;
  Prop, MonProp: System.Rtti.TRttiProperty;
  Monitor: TObject;
begin
  Result := 0;
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  Prop := Ctx.GetType(AForm.ClassType).GetProperty('Monitor');
  if Prop <> nil then
  begin
    Monitor := Prop.GetValue(AForm).AsObject;
    if Monitor <> nil then
    begin
      MonProp := Ctx.GetType(Monitor.ClassType).GetProperty('MonitorNum');
      if MonProp <> nil then
        Result := MonProp.GetValue(Monitor).AsInteger;
    end;
  end;
end;

class procedure TFormAccessor.SetFormBounds(AForm: TObject; const R: TRect);
var
  Ctx: System.Rtti.TRttiContext;
  RttiType: System.Rtti.TRttiType;
  PropLeft, PropTop, PropWidth, PropHeight: System.Rtti.TRttiProperty;
begin
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  RttiType := Ctx.GetType(AForm.ClassType);
  PropLeft := RttiType.GetProperty('Left');
  PropTop := RttiType.GetProperty('Top');
  PropWidth := RttiType.GetProperty('Width');
  PropHeight := RttiType.GetProperty('Height');
  
  if (PropLeft <> nil) and (PropTop <> nil) and 
     (PropWidth <> nil) and (PropHeight <> nil) then
  begin
    PropLeft.SetValue(AForm, R.Left);
    PropTop.SetValue(AForm, R.Top);
    PropWidth.SetValue(AForm, R.Width);
    PropHeight.SetValue(AForm, R.Height);
  end;
end;

class procedure TFormAccessor.SetFormWindowState(AForm: TObject; State: Integer);
var
  Ctx: System.Rtti.TRttiContext;
  Prop: System.Rtti.TRttiProperty;
begin
  if AForm = nil then Exit;
  
  Ctx := GetRttiContext;
  Prop := Ctx.GetType(AForm.ClassType).GetProperty('WindowState');
  if Prop <> nil then
    Prop.SetValue(AForm, TValue.FromOrdinal(Prop.PropertyType.Handle, State));
end;

function RectWidth(const R: TRect): Integer;
begin
  Result := R.Right - R.Left;
end;

function RectHeight(const R: TRect): Integer;
begin
  Result := R.Bottom - R.Top;
end;

function VirtualScreenWorkArea: TRect;
begin
  Result.Left := GetSystemMetrics(SM_XVIRTUALSCREEN);
  Result.Top := GetSystemMetrics(SM_YVIRTUALSCREEN);
  Result.Right := Result.Left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
  Result.Bottom := Result.Top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
end;

function WorkAreaForSavedBounds(const Data: TFormStateData): TRect;
var
  SavedRect: TRect;
  Mon: HMONITOR;
  MonInfo: TMonitorInfo;
begin
  SavedRect := Rect(Data.Left, Data.Top,
    Data.Left + Max(Data.Width, 1),
    Data.Top + Max(Data.Height, 1));

  Result := VirtualScreenWorkArea;
  Mon := MonitorFromRect(@SavedRect, MONITOR_DEFAULTTONEAREST);
  if Mon <> 0 then
  begin
    MonInfo.cbSize := SizeOf(MONITORINFO);
    if GetMonitorInfo(Mon, @MonInfo) then
      Result := MonInfo.rcWork;
  end;
end;

procedure EnsureFormStateVisible(var Data: TFormStateData);
const
  MIN_FORM_WIDTH = 100;
  MIN_FORM_HEIGHT = 100;
  DEFAULT_FORM_WIDTH = 400;
  DEFAULT_FORM_HEIGHT = 300;
  WORKAREA_MARGIN = 20;
var
  WorkArea: TRect;
  WorkWidth: Integer;
  WorkHeight: Integer;
begin
  WorkArea := WorkAreaForSavedBounds(Data);
  WorkWidth := Max(RectWidth(WorkArea), 1);
  WorkHeight := Max(RectHeight(WorkArea), 1);

  if Data.Width < MIN_FORM_WIDTH then
    Data.Width := DEFAULT_FORM_WIDTH;
  if Data.Height < MIN_FORM_HEIGHT then
    Data.Height := DEFAULT_FORM_HEIGHT;

  if Data.Width > WorkWidth then
    Data.Width := Max(MIN_FORM_WIDTH, WorkWidth - WORKAREA_MARGIN);
  if Data.Width > WorkWidth then
    Data.Width := WorkWidth;

  if Data.Height > WorkHeight then
    Data.Height := Max(MIN_FORM_HEIGHT, WorkHeight - WORKAREA_MARGIN);
  if Data.Height > WorkHeight then
    Data.Height := WorkHeight;

  if Data.Left + Data.Width > WorkArea.Right then
    Data.Left := WorkArea.Right - Data.Width;
  if Data.Left < WorkArea.Left then
    Data.Left := WorkArea.Left;

  if Data.Top + Data.Height > WorkArea.Bottom then
    Data.Top := WorkArea.Bottom - Data.Height;
  if Data.Top < WorkArea.Top then
    Data.Top := WorkArea.Top;
end;

procedure TDeepBaseFormState.SaveFormState(AForm: TObject; const ExtraData: string);
var
  Data: TFormStateData;
  FormName: string;
  Placement: TWindowPlacement;
  NormalRect: TRect;
  Handle: HWND;
  Mon: HMONITOR;
  MonInfo: TMonitorInfo;
begin
  if AForm = nil then Exit;
  
  FormName := TFormAccessor.GetFormName(AForm);
  if FormName = '' then Exit;
  
  Data.Init;
  
  // 使用 GetWindowPlacement 获取正常状态下的窗口边界
  Handle := TFormAccessor.GetFormHandle(AForm);
  if Handle <> 0 then
  begin
    Placement.length := SizeOf(TWindowPlacement);
    if GetWindowPlacement(Handle, @Placement) then
    begin
      NormalRect := Placement.rcNormalPosition;
      // WINDOWPLACEMENT.rcNormalPosition for regular top-level windows uses
      // workspace coordinates. Convert to monitor screen coordinates so we
      // persist absolute Left/Top consistently across taskbar positions.
      Mon := MonitorFromWindow(Handle, MONITOR_DEFAULTTONEAREST);
      if Mon <> 0 then
      begin
        MonInfo.cbSize := SizeOf(MONITORINFO);
        if GetMonitorInfo(Mon, @MonInfo) then
          OffsetRect(NormalRect,
            MonInfo.rcWork.Left - MonInfo.rcMonitor.Left,
            MonInfo.rcWork.Top - MonInfo.rcMonitor.Top);
      end;
      Data.Left := NormalRect.Left;
      Data.Top := NormalRect.Top;
      Data.Width := NormalRect.Width;
      Data.Height := NormalRect.Height;
    end
    else
    begin
      var Bounds := TFormAccessor.GetFormBounds(AForm);
      Data.Left := Bounds.Left;
      Data.Top := Bounds.Top;
      Data.Width := Bounds.Width;
      Data.Height := Bounds.Height;
    end;
  end
  else
  begin
    var Bounds := TFormAccessor.GetFormBounds(AForm);
    Data.Left := Bounds.Left;
    Data.Top := Bounds.Top;
    Data.Width := Bounds.Width;
    Data.Height := Bounds.Height;
  end;
  
  Data.WindowState := TFormAccessor.GetFormWindowState(AForm);
  Data.MonitorIndex := TFormAccessor.GetFormMonitorIndex(AForm);
  Data.Extra := ExtraData;
  
  SaveState(FormName, Data);
end;

procedure TDeepBaseFormState.RestoreFormState(AForm: TObject);
var
  Data: TFormStateData;
  FormName: string;
begin
  if AForm = nil then Exit;
  
  FormName := TFormAccessor.GetFormName(AForm);
  if FormName = '' then Exit;
  
  if RestoreState(FormName, Data) then
  begin
    // Clamp stale multi-monitor coordinates to the nearest current work area.
    EnsureFormStateVisible(Data);
    
    // 先设置为正常状态以便设置位置
    TFormAccessor.SetFormWindowState(AForm, 0); // wsNormal
    
    // 应用位置和大小
    TFormAccessor.SetFormBounds(AForm, TRect.Create(Data.Left, Data.Top, 
      Data.Left + Data.Width, Data.Top + Data.Height));
    
    // 恢复窗口状态 (不恢复最小化状态)
    if Data.WindowState = 2 then // wsMaximized
      TFormAccessor.SetFormWindowState(AForm, 2);
  end;
end;

procedure TDeepBaseFormState.DeleteFormState(const FormName: string);
begin
  DeleteState(FormName);
end;

function TDeepBaseFormState.FormStateExists(const FormName: string): Boolean;
begin
  Result := HasState(FormName);
end;

function TDeepBaseFormState.GetFormStateExtra(const FormName: string): string;
var
  Data: TFormStateData;
begin
  Result := '';
  if RestoreState(FormName, Data) then
    Result := Data.Extra;
end;
{$ENDIF}

end.
