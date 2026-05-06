{ ============================================================================
  UniBase.VCL.FormStateHelper - 窗体状态助手组件
  
  版本: 1.0
  说明: 拖放到窗体上即可自动保存/恢复窗体状态
  功能:
    - 自动保存窗体位置、大小、WindowState
    - 自动恢复时检查显示器边界
    - 支持 Extra 数据（自定义状态）
    - 事件链式钩子，不覆盖用户事件
  ============================================================================ }

unit UniBase.VCL.FormStateHelper;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  UniBase.Manager,
  UniBase.FormState,
  UniBase.Types;

type
  /// <summary>
  /// 窗体状态助手组件
  /// </summary>
  TFormStateHelper = class(TComponent)
  private
    FAutoSave: Boolean;
    FAutoRestore: Boolean;
    FForm: TForm;
    FFormName: string;  // 可自定义，默认使用 Form.Name
    FOnSaveExtra: TSaveExtraEvent;
    FOnRestoreExtra: TRestoreExtraEvent;
    
    // 保存原始事件处理器（链式调用）
    FOldOnShow: TNotifyEvent;
    FOldOnClose: TCloseEvent;
    FOldOnDestroy: TNotifyEvent;
    
    FStateRestored: Boolean;
    FStateSaved: Boolean;
    
    procedure InternalOnShow(Sender: TObject);
    procedure InternalOnClose(Sender: TObject; var Action: TCloseAction);
    procedure InternalOnDestroy(Sender: TObject);
    
    procedure HookFormEvents;
    procedure UnhookFormEvents;
    
    function GetEffectiveFormName: string;
    procedure EnsureFormVisible(var Data: TFormStateData);
    
  protected
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure SetName(const NewName: TComponentName); override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 手动保存状态
    /// </summary>
    procedure SaveState;
    
    /// <summary>
    /// 手动恢复状态
    /// </summary>
    procedure RestoreState;
    
    /// <summary>
    /// 检查是否有已保存的状态
    /// </summary>
    function HasSavedState: Boolean;
    
    /// <summary>
    /// 删除已保存的状态
    /// </summary>
    procedure DeleteSavedState;
    
  published
    /// <summary>
    /// 窗体关闭时自动保存状态
    /// </summary>
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
    
    /// <summary>
    /// 窗体显示时自动恢复状态
    /// </summary>
    property AutoRestore: Boolean read FAutoRestore write FAutoRestore default True;
    
    /// <summary>
    /// 自定义窗体名（留空则使用 Form.Name）
    /// </summary>
    property FormName: string read FFormName write FFormName;
    
    /// <summary>
    /// 保存额外数据事件
    /// </summary>
    property OnSaveExtra: TSaveExtraEvent read FOnSaveExtra write FOnSaveExtra;
    
    /// <summary>
    /// 恢复额外数据事件
    /// </summary>
    property OnRestoreExtra: TRestoreExtraEvent read FOnRestoreExtra write FOnRestoreExtra;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.MultiMon,
  Vcl.Controls,
  System.Math,
  System.Types,
  UniBase.Logging;  // BUG-023 FIX: 添加日志支持

{ TFormStateHelper }

constructor TFormStateHelper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoSave := True;
  FAutoRestore := True;
  FStateRestored := False;
  FStateSaved := False;
  
  if AOwner is TForm then
    FForm := TForm(AOwner);
end;

destructor TFormStateHelper.Destroy;
begin
  // 如果自动保存且还没保存，在销毁前保存
  if FAutoSave and (not FStateSaved) and (FForm <> nil) then
  begin
    try
      SaveState;
    except
      // BUG-023 FIX: 记录异常信息用于调试，而不是完全忽略
      on E: Exception do
        Logger.WarnFmt('FormStateHelper.Destroy: Failed to save state for form "%s": %s',
          [GetEffectiveFormName, E.Message], 'FormStateHelper');
    end;
  end;

  UnhookFormEvents;
  inherited;
end;

procedure TFormStateHelper.SetName(const NewName: TComponentName);
begin
  inherited;
  // 如果 FormName 为空，则默认使用组件所在窗体的 Name
end;

procedure TFormStateHelper.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if (FForm = nil) and (Owner is TForm) then
      FForm := TForm(Owner);
      
    HookFormEvents;
  end;
end;

procedure TFormStateHelper.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FForm) then
  begin
    UnhookFormEvents;
    FForm := nil;
  end;
end;

function TFormStateHelper.GetEffectiveFormName: string;
begin
  if FFormName <> '' then
    Result := FFormName
  else if FForm <> nil then
    Result := FForm.Name
  else
    Result := '';
end;

procedure TFormStateHelper.HookFormEvents;
begin
  if FForm = nil then Exit;
  
  // 保存并替换 OnShow
  FOldOnShow := FForm.OnShow;
  FForm.OnShow := InternalOnShow;
  
  // 保存并替换 OnClose
  FOldOnClose := FForm.OnClose;
  FForm.OnClose := InternalOnClose;
  
  // 保存并替换 OnDestroy
  FOldOnDestroy := FForm.OnDestroy;
  FForm.OnDestroy := InternalOnDestroy;
end;

procedure TFormStateHelper.UnhookFormEvents;
begin
  var CurrentHandler: TMethod;
  var InternalHandler: TMethod;
  var NotifyHandler: TNotifyEvent;
  var CloseHandler: TCloseEvent;

  if FForm = nil then Exit;

  // 恢复原始事件（只在我们的处理器还在时才恢复）
  CurrentHandler := TMethod(FForm.OnShow);
  NotifyHandler := InternalOnShow;
  InternalHandler := TMethod(NotifyHandler);
  if (CurrentHandler.Code = InternalHandler.Code) and
     (CurrentHandler.Data = InternalHandler.Data) then
    FForm.OnShow := FOldOnShow;

  CurrentHandler := TMethod(FForm.OnClose);
  CloseHandler := InternalOnClose;
  InternalHandler := TMethod(CloseHandler);
  if (CurrentHandler.Code = InternalHandler.Code) and
     (CurrentHandler.Data = InternalHandler.Data) then
    FForm.OnClose := FOldOnClose;

  CurrentHandler := TMethod(FForm.OnDestroy);
  NotifyHandler := InternalOnDestroy;
  InternalHandler := TMethod(NotifyHandler);
  if (CurrentHandler.Code = InternalHandler.Code) and
     (CurrentHandler.Data = InternalHandler.Data) then
    FForm.OnDestroy := FOldOnDestroy;
end;

procedure TFormStateHelper.InternalOnShow(Sender: TObject);
begin
  // 先恢复状态（如果尚未恢复）
  if FAutoRestore and (not FStateRestored) then
  begin
    RestoreState;
    FStateRestored := True;
  end;
  
  // 链式调用原始 OnShow
  if Assigned(FOldOnShow) then
    FOldOnShow(Sender);
end;

procedure TFormStateHelper.InternalOnClose(Sender: TObject; var Action: TCloseAction);
begin
  // 保存状态
  if FAutoSave and (not FStateSaved) then
  begin
    SaveState;
    FStateSaved := True;
  end;
  
  // 链式调用原始 OnClose
  if Assigned(FOldOnClose) then
    FOldOnClose(Sender, Action);
end;

procedure TFormStateHelper.InternalOnDestroy(Sender: TObject);
begin
  // 如果 OnClose 没触发（比如 Application.Terminate），在这里保存
  if FAutoSave and (not FStateSaved) then
  begin
    try
      SaveState;
      FStateSaved := True;
    except
      // BUG-023 FIX: 记录异常信息用于调试，而不是完全忽略
      on E: Exception do
        Logger.WarnFmt('FormStateHelper.OnDestroy: Failed to save state for form "%s": %s',
          [GetEffectiveFormName, E.Message], 'FormStateHelper');
    end;
  end;

  // 链式调用原始 OnDestroy
  if Assigned(FOldOnDestroy) then
    FOldOnDestroy(Sender);
end;

procedure TFormStateHelper.EnsureFormVisible(var Data: TFormStateData);
const
  MIN_VISIBLE_HEIGHT = 40;  // 至少需要40像素高度可见（标题栏+一点内容）
  MIN_VISIBLE_WIDTH = 100;  // 至少需要100像素宽度可见（可以拖动）
var
  I: Integer;
  MonitorRect: TRect;
  TitleBarRect: TRect;
  VisibleWidth, VisibleHeight: Integer;
  BestMonitor: Integer;
  BestOverlap: Integer;
  CurrentOverlap: Integer;
  TargetMonitor: TMonitor;
begin
  // 策略：确保窗体标题栏区域有足够的可见部分让用户能够拖动
  // 标题栏区域定义为窗体顶部 MIN_VISIBLE_HEIGHT 像素
  TitleBarRect := Rect(
    Data.Left, 
    Data.Top, 
    Data.Left + Data.Width, 
    Data.Top + MIN_VISIBLE_HEIGHT
  );
  
  BestMonitor := -1;
  BestOverlap := 0;
  
  // 首先尝试找到保存时的显示器
  if (Data.MonitorIndex >= 0) and (Data.MonitorIndex < Screen.MonitorCount) then
  begin
    MonitorRect := Screen.Monitors[Data.MonitorIndex].WorkareaRect;
    // 检查窗体是否在这个显示器的合理范围内
    if (Data.Left >= MonitorRect.Left - Data.Width + MIN_VISIBLE_WIDTH) and
       (Data.Left <= MonitorRect.Right - MIN_VISIBLE_WIDTH) and
       (Data.Top >= MonitorRect.Top) and
       (Data.Top <= MonitorRect.Bottom - MIN_VISIBLE_HEIGHT) then
    begin
      // 原显示器仍然有效，只需要微调确保可见
      BestMonitor := Data.MonitorIndex;
    end;
  end;
  
  // 如果原显示器不可用，找到与标题栏重叠最多的显示器
  if BestMonitor < 0 then
  begin
    for I := 0 to Screen.MonitorCount - 1 do
    begin
      MonitorRect := Screen.Monitors[I].WorkareaRect;
      
      // 计算标题栏与显示器的重叠面积
      VisibleWidth := Min(TitleBarRect.Right, MonitorRect.Right) - 
                      Max(TitleBarRect.Left, MonitorRect.Left);
      VisibleHeight := Min(TitleBarRect.Bottom, MonitorRect.Bottom) - 
                       Max(TitleBarRect.Top, MonitorRect.Top);
      
      if (VisibleWidth > 0) and (VisibleHeight > 0) then
      begin
        CurrentOverlap := VisibleWidth * VisibleHeight;
        if CurrentOverlap > BestOverlap then
        begin
          BestOverlap := CurrentOverlap;
          BestMonitor := I;
        end;
      end;
    end;
  end;
  
  // 如果没有找到任何重叠的显示器，使用主显示器
  if BestMonitor < 0 then
    BestMonitor := Screen.PrimaryMonitor.MonitorNum;
  
  TargetMonitor := Screen.Monitors[BestMonitor];
  MonitorRect := TargetMonitor.WorkareaRect;
  
  // 确保窗体尺寸不超出目标显示器
  if Data.Width > MonitorRect.Width - 20 then
    Data.Width := MonitorRect.Width - 20;
  if Data.Height > MonitorRect.Height - 20 then
    Data.Height := MonitorRect.Height - 20;
  
  // 确保标题栏完全在显示器内
  // 左边界：至少 MIN_VISIBLE_WIDTH 像素在屏幕内
  if Data.Left < MonitorRect.Left - Data.Width + MIN_VISIBLE_WIDTH then
    Data.Left := MonitorRect.Left;
  // 右边界：至少 MIN_VISIBLE_WIDTH 像素在屏幕内
  if Data.Left > MonitorRect.Right - MIN_VISIBLE_WIDTH then
    Data.Left := MonitorRect.Right - Data.Width;
  // 上边界：标题栏必须在屏幕内
  if Data.Top < MonitorRect.Top then
    Data.Top := MonitorRect.Top;
  // 下边界：至少 MIN_VISIBLE_HEIGHT 像素在屏幕内
  if Data.Top > MonitorRect.Bottom - MIN_VISIBLE_HEIGHT then
    Data.Top := MonitorRect.Bottom - Data.Height;
    
  Data.MonitorIndex := BestMonitor;
end;

procedure TFormStateHelper.SaveState;
var
  Data: TFormStateData;
  ExtraData: string;
  FormState: TUniBaseFormState;
  EffectiveName: string;
  Placement: TWindowPlacement;
  NormalRect: TRect;
  Mon: HMONITOR;
  MonInfo: TMonitorInfo;
begin
  if FForm = nil then Exit;
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := UniBase.Manager.UniBase.FormState;
  // 收集状态数据
  Data.Init;
  
  // 使用 GetWindowPlacement 获取正常状态下的窗口边界
  // 这在最大化/最小化状态下也能正确返回 RestoreBounds
  Placement.length := SizeOf(TWindowPlacement);
  if GetWindowPlacement(FForm.Handle, @Placement) then
  begin
    NormalRect := Placement.rcNormalPosition;
    Mon := MonitorFromWindow(FForm.Handle, MONITOR_DEFAULTTONEAREST);
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
    // 回退到直接读取属性
    Data.Left := FForm.Left;
    Data.Top := FForm.Top;
    Data.Width := FForm.Width;
    Data.Height := FForm.Height;
  end;
  
  // 保存窗口状态
  case FForm.WindowState of
    wsMaximized: Data.WindowState := 2;
    wsMinimized: Data.WindowState := 1;
  else
    Data.WindowState := 0;
  end;
  
  Data.MonitorIndex := FForm.Monitor.MonitorNum;
  
  // 收集额外数据
  ExtraData := '';
  if Assigned(FOnSaveExtra) then
    FOnSaveExtra(Self, ExtraData);
  Data.Extra := ExtraData;
  
  FormState.SaveState(EffectiveName, Data);
end;

procedure TFormStateHelper.RestoreState;
var
  Data: TFormStateData;
  FormState: TUniBaseFormState;
  EffectiveName: string;
begin
  if FForm = nil then Exit;
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := UniBase.Manager.UniBase.FormState;
  if FormState.RestoreState(EffectiveName, Data) then
  begin
    // 确保窗体在可见范围内
    EnsureFormVisible(Data);
    
    // 先设置为正常状态以便设置位置
    FForm.WindowState := wsNormal;
    
    // 应用位置和大小
    FForm.SetBounds(Data.Left, Data.Top, Data.Width, Data.Height);
    
    // 恢复窗口状态
    case Data.WindowState of
      2: FForm.WindowState := wsMaximized;
      // 不恢复最小化状态，因为用户显然想看到窗体
    end;
    
    // 恢复额外数据
    if Assigned(FOnRestoreExtra) and (Data.Extra <> '') then
      FOnRestoreExtra(Self, Data.Extra);
  end;
end;

function TFormStateHelper.HasSavedState: Boolean;
var
  FormState: TUniBaseFormState;
  EffectiveName: string;
begin
  Result := False;
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := UniBase.Manager.UniBase.FormState;
  Result := FormState.HasState(EffectiveName);
end;

procedure TFormStateHelper.DeleteSavedState;
var
  FormState: TUniBaseFormState;
  EffectiveName: string;
begin
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := UniBase.Manager.UniBase.FormState;
  FormState.DeleteState(EffectiveName);
end;

end.
