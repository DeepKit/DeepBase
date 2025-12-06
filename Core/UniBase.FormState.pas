{ ============================================================================
  UniBase.FormState - Form State Management Module
  
  Version: 1.0
  Description: Provides persistent storage for form position, size and state.
  Note: This is a Core layer module, does not depend on VCL/FMX. Actual UI
        binding is implemented by upper layer components.
  ============================================================================ }

unit UniBase.FormState;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Rtti,
  System.Types,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  FireDAC.Comp.Client,
  UniBase.Types;

type
  /// <summary>
  /// Form state data
  /// </summary>
  TFormStateData = record
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
    WindowState: Integer; // 0=Normal, 1=Minimized, 2=Maximized
    MonitorIndex: Integer;
    Extra: string;
    
    /// <summary>
    /// Initialize to default values
    /// </summary>
    procedure Init;
    
    /// <summary>
    /// Check if data is valid
    /// </summary>
    function IsValid: Boolean;
  end;

  /// <summary>
  /// Form state manager
  /// </summary>
  TUniBaseFormState = class
  private
    FConnection: TFDConnection;
    FLock: TObject;
    FOwnsLock: Boolean;
    
    procedure WriteToDB(const FormName: string; const Data: TFormStateData);
    function ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
    
  public
    constructor Create(AConnection: TFDConnection; ALock: TObject = nil);
    destructor Destroy; override;
    
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

uses
  FireDAC.Stan.Param;

{ TFormStateData }

procedure TFormStateData.Init;
begin
  Left := 100;
  Top := 100;
  Width := 800;
  Height := 600;
  WindowState := 0;
  MonitorIndex := 0;
  Extra := '';
end;

function TFormStateData.IsValid: Boolean;
begin
  Result := (Width > 0) and (Height > 0);
end;

{ TUniBaseFormState }

constructor TUniBaseFormState.Create(AConnection: TFDConnection; ALock: TObject);
begin
  inherited Create;
  FConnection := AConnection;
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

destructor TUniBaseFormState.Destroy;
begin
  if FOwnsLock then
    FLock.Free;
  inherited;
end;

procedure TUniBaseFormState.SaveState(const FormName: string; const Data: TFormStateData);
begin
  TMonitor.Enter(FLock);
  try
    WriteToDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseFormState.RestoreState(const FormName: string; out Data: TFormStateData): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := ReadFromDB(FormName, Data);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.DeleteState(const FormName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM FormStates WHERE FormName = :FormName';
      Query.ParamByName('FormName').AsString := FormName;
      Query.ExecSQL;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.WriteToDB(const FormName: string; const Data: TFormStateData);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 
      'INSERT OR REPLACE INTO FormStates ' +
      '(FormName, Left, Top, Width, Height, WindowState, MonitorIndex, Extra) ' +
      'VALUES (:FormName, :Left, :Top, :Width, :Height, :WindowState, :MonitorIndex, :Extra)';
      
    Query.ParamByName('FormName').AsString := FormName;
    Query.ParamByName('Left').AsInteger := Data.Left;
    Query.ParamByName('Top').AsInteger := Data.Top;
    Query.ParamByName('Width').AsInteger := Data.Width;
    Query.ParamByName('Height').AsInteger := Data.Height;
    Query.ParamByName('WindowState').AsInteger := Data.WindowState;
    Query.ParamByName('MonitorIndex').AsInteger := Data.MonitorIndex;
    Query.ParamByName('Extra').AsString := Data.Extra;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseFormState.ReadFromDB(const FormName: string; out Data: TFormStateData): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  Data.Init;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM FormStates WHERE FormName = :FormName';
    Query.ParamByName('FormName').AsString := FormName;
    Query.Open;
    
    if not Query.Eof then
    begin
      Data.Left := Query.FieldByName('Left').AsInteger;
      Data.Top := Query.FieldByName('Top').AsInteger;
      Data.Width := Query.FieldByName('Width').AsInteger;
      Data.Height := Query.FieldByName('Height').AsInteger;
      Data.WindowState := Query.FieldByName('WindowState').AsInteger;
      Data.MonitorIndex := Query.FieldByName('MonitorIndex').AsInteger;
      Data.Extra := Query.FieldByName('Extra').AsString;
      Result := Data.IsValid;
    end;
  finally
    Query.Free;
  end;
end;

function TUniBaseFormState.HasState(const FormName: string): Boolean;
var
  Query: TFDQuery;
begin
  Result := False;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT 1 FROM FormStates WHERE FormName = :FormName';
      Query.ParamByName('FormName').AsString := FormName;
      Query.Open;
      Result := not Query.Eof;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TUniBaseFormState.GetAllFormNames: TArray<string>;
var
  Query: TFDQuery;
  List: TArray<string>;
begin
  Result := nil;
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT FormName FROM FormStates ORDER BY FormName';
      Query.Open;
      
      SetLength(List, 0);
      while not Query.Eof do
      begin
        SetLength(List, Length(List) + 1);
        List[High(List)] := Query.FieldByName('FormName').AsString;
        Query.Next;
      end;
      Result := List;
    finally
      Query.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TUniBaseFormState.ClearAll;
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  TMonitor.Enter(FLock);
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'DELETE FROM FormStates';
      Query.ExecSQL;
    finally
      Query.Free;
    end;
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

procedure TUniBaseFormState.SaveFormState(AForm: TObject; const ExtraData: string);
var
  Data: TFormStateData;
  FormName: string;
  Placement: TWindowPlacement;
  NormalRect: TRect;
  Handle: HWND;
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

procedure TUniBaseFormState.RestoreFormState(AForm: TObject);
const
  MIN_VISIBLE_HEIGHT = 40;
  MIN_VISIBLE_WIDTH = 100;
var
  Data: TFormStateData;
  FormName: string;
  ScreenWidth, ScreenHeight: Integer;
begin
  if AForm = nil then Exit;
  
  FormName := TFormAccessor.GetFormName(AForm);
  if FormName = '' then Exit;
  
  if RestoreState(FormName, Data) then
  begin
    // 边界检查 - 确保窗体在可见范围内
    ScreenWidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
    ScreenHeight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
    
    // 确保窗体尺寸合理
    if Data.Width < 100 then Data.Width := 400;
    if Data.Height < 100 then Data.Height := 300;
    if Data.Width > ScreenWidth then Data.Width := ScreenWidth - 20;
    if Data.Height > ScreenHeight then Data.Height := ScreenHeight - 20;
    
    // 确保标题栏在可见范围内
    if Data.Left < -Data.Width + MIN_VISIBLE_WIDTH then
      Data.Left := 0;
    if Data.Left > ScreenWidth - MIN_VISIBLE_WIDTH then
      Data.Left := ScreenWidth - Data.Width;
    if Data.Top < 0 then
      Data.Top := 0;
    if Data.Top > ScreenHeight - MIN_VISIBLE_HEIGHT then
      Data.Top := ScreenHeight - Data.Height;
    
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

procedure TUniBaseFormState.DeleteFormState(const FormName: string);
begin
  DeleteState(FormName);
end;

function TUniBaseFormState.FormStateExists(const FormName: string): Boolean;
begin
  Result := HasState(FormName);
end;

function TUniBaseFormState.GetFormStateExtra(const FormName: string): string;
var
  Data: TFormStateData;
begin
  Result := '';
  if RestoreState(FormName, Data) then
    Result := Data.Extra;
end;
{$ENDIF}

end.
