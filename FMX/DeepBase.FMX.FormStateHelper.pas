{ ============================================================================
  DeepBase.FMX.FormStateHelper - FMX 窗体状态助手组�?
  
  版本: 1.0
  说明: 拖放�?FMX 窗体上即可自动保�?恢复窗体状�?
  功能:
    - 自动保存窗体位置、大小、WindowState
    - 自动恢复时检查显示器边界
    - 支持 Extra 数据（自定义状态）
    - 事件链式钩子，不覆盖用户事件
  ============================================================================ }

unit DeepBase.FMX.FormStateHelper;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Forms,
  FMX.Platform,
  DeepBase.Manager,
  DeepBase.FormState,
  DeepBase.Types;

type
  /// <summary>
  /// 保存额外数据事件
  /// </summary>
  TFMXSaveExtraEvent = procedure(Sender: TObject; var ExtraData: string) of object;
  
  /// <summary>
  /// 恢复额外数据事件
  /// </summary>
  TFMXRestoreExtraEvent = procedure(Sender: TObject; const ExtraData: string) of object;

  /// <summary>
  /// FMX 窗体状态助手组�?
  /// </summary>
  TFMXFormStateHelper = class(TFmxObject)
  private
    FAutoSave: Boolean;
    FAutoRestore: Boolean;
    FForm: TCommonCustomForm;
    FFormName: string;  // 可自定义，默认使�?Form.Name
    FOnSaveExtra: TFMXSaveExtraEvent;
    FOnRestoreExtra: TFMXRestoreExtraEvent;
    
    // 保存原始事件处理器（链式调用�?
    FOldOnShow: TNotifyEvent;
    FOldOnClose: TCloseEvent;
    
    FStateRestored: Boolean;
    FStateSaved: Boolean;
    
    procedure InternalOnShow(Sender: TObject);
    procedure InternalOnClose(Sender: TObject; var Action: TCloseAction);
    
    procedure HookFormEvents;
    procedure UnhookFormEvents;
    
    function GetEffectiveFormName: string;
    procedure EnsureFormVisible(var Data: TFormStateData);
    function GetScreenWorkArea: TRectF;
    
  protected
    procedure Loaded; override;
    procedure SetParent(const Value: TFmxObject); override;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    /// <summary>
    /// 手动保存状�?
    /// </summary>
    procedure SaveState;
    
    /// <summary>
    /// 手动恢复状�?
    /// </summary>
    procedure RestoreState;
    
    /// <summary>
    /// 检查是否有已保存的状�?
    /// </summary>
    function HasSavedState: Boolean;
    
    /// <summary>
    /// 删除已保存的状�?
    /// </summary>
    procedure DeleteSavedState;
    
  published
    /// <summary>
    /// 窗体关闭时自动保存状�?
    /// </summary>
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
    
    /// <summary>
    /// 窗体显示时自动恢复状�?
    /// </summary>
    property AutoRestore: Boolean read FAutoRestore write FAutoRestore default True;
    
    /// <summary>
    /// 自定义窗体名（留空则使用 Form.Name�?
    /// </summary>
    property FormName: string read FFormName write FFormName;
    
    /// <summary>
    /// 保存额外数据事件
    /// </summary>
    property OnSaveExtra: TFMXSaveExtraEvent read FOnSaveExtra write FOnSaveExtra;
    
    /// <summary>
    /// 恢复额外数据事件
    /// </summary>
    property OnRestoreExtra: TFMXRestoreExtraEvent read FOnRestoreExtra write FOnRestoreExtra;
  end;

implementation

{ TFMXFormStateHelper }

constructor TFMXFormStateHelper.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoSave := True;
  FAutoRestore := True;
  FStateRestored := False;
  FStateSaved := False;
  
  // 尝试获取父窗�?
  if AOwner is TCommonCustomForm then
    FForm := TCommonCustomForm(AOwner);
end;

destructor TFMXFormStateHelper.Destroy;
begin
  // 如果自动保存且还没保存，在销毁前保存
  if FAutoSave and (not FStateSaved) and (FForm <> nil) then
  begin
    try
      SaveState;
    except
      // 忽略销毁时的错�?
    end;
  end;
  
  UnhookFormEvents;
  inherited;
end;

procedure TFMXFormStateHelper.SetParent(const Value: TFmxObject);
begin
  inherited;
  
  // 当添加到窗体时，获取窗体引用
  if (Value <> nil) and (Value.Root is TCommonCustomForm) then
  begin
    FForm := TCommonCustomForm(Value.Root);
    if not (csDesigning in ComponentState) and not (csLoading in ComponentState) then
      HookFormEvents;
  end
  else if Value = nil then
  begin
    UnhookFormEvents;
    FForm := nil;
  end;
end;

procedure TFMXFormStateHelper.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    // 获取窗体引用
    if (FForm = nil) and (Root is TCommonCustomForm) then
      FForm := TCommonCustomForm(Root);
      
    HookFormEvents;
  end;
end;

function TFMXFormStateHelper.GetEffectiveFormName: string;
begin
  if FFormName <> '' then
    Result := FFormName
  else if FForm <> nil then
    Result := FForm.Name
  else
    Result := '';
end;

procedure TFMXFormStateHelper.HookFormEvents;
begin
  if FForm = nil then Exit;
  
  // 保存并替�?OnShow
  FOldOnShow := FForm.OnShow;
  FForm.OnShow := InternalOnShow;
  
  // 保存并替�?OnClose
  FOldOnClose := FForm.OnClose;
  FForm.OnClose := InternalOnClose;
end;

procedure TFMXFormStateHelper.UnhookFormEvents;
begin
  if FForm = nil then Exit;
  
  // 恢复原始事件（只在我们的处理器还在时才恢复）
  if TMethod(FForm.OnShow).Code = @TFMXFormStateHelper.InternalOnShow then
    FForm.OnShow := FOldOnShow;

  if TMethod(FForm.OnClose).Code = @TFMXFormStateHelper.InternalOnClose then
    FForm.OnClose := FOldOnClose;
end;

procedure TFMXFormStateHelper.InternalOnShow(Sender: TObject);
begin
  // 先恢复状态（如果尚未恢复�?
  if FAutoRestore and (not FStateRestored) then
  begin
    RestoreState;
    FStateRestored := True;
  end;
  
  // 链式调用原始 OnShow
  if Assigned(FOldOnShow) then
    FOldOnShow(Sender);
end;

procedure TFMXFormStateHelper.InternalOnClose(Sender: TObject; var Action: TCloseAction);
begin
  // 保存状�?
  if FAutoSave and (not FStateSaved) then
  begin
    SaveState;
    FStateSaved := True;
  end;
  
  // 链式调用原始 OnClose
  if Assigned(FOldOnClose) then
    FOldOnClose(Sender, Action);
end;

function TFMXFormStateHelper.GetScreenWorkArea: TRectF;
var
  ScreenSvc: IFMXScreenService;
begin
  Result := TRectF.Create(0, 0, 1920, 1080); // 默认�?
  
  if TPlatformServices.Current.SupportsPlatformService(IFMXScreenService, ScreenSvc) then
    Result := TRectF.Create(0, 0, ScreenSvc.GetScreenSize.X, ScreenSvc.GetScreenSize.Y);
end;

procedure TFMXFormStateHelper.EnsureFormVisible(var Data: TFormStateData);
var
  WorkArea: TRectF;
  FormRect: TRectF;
begin
  WorkArea := GetScreenWorkArea;
  FormRect := TRectF.Create(Data.Left, Data.Top, Data.Left + Data.Width, Data.Top + Data.Height);
  
  // 检查窗体是否在工作区内
  if not WorkArea.IntersectsWith(FormRect) then
  begin
    // 窗体完全在工作区外，移到工作区中�?
    if Data.Width > WorkArea.Width then
      Data.Width := Round(WorkArea.Width - 20);
    if Data.Height > WorkArea.Height then
      Data.Height := Round(WorkArea.Height - 20);
      
    // 居中显示
    Data.Left := Round(WorkArea.Left + (WorkArea.Width - Data.Width) / 2);
    Data.Top := Round(WorkArea.Top + (WorkArea.Height - Data.Height) / 2);
  end;
end;

procedure TFMXFormStateHelper.SaveState;
var
  Data: TFormStateData;
  ExtraData: string;
  FormState: TDeepBaseFormState;
  EffectiveName: string;
begin
  if FForm = nil then Exit;
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := DeepBase.Manager.DeepBase.FormState;
  // Collect state data.
  Data.Init;
  // Handle FMX window state.
  if FForm.WindowState = TWindowState.wsMaximized then
  begin
    // Save current bounds even when maximized.
    Data.Left := Round(FForm.Left);
    Data.Top := Round(FForm.Top);
    Data.Width := Round(FForm.ClientWidth);
    Data.Height := Round(FForm.ClientHeight);
    Data.WindowState := 2;
  end
  else if FForm.WindowState = TWindowState.wsMinimized then
  begin
    Data.Left := Round(FForm.Left);
    Data.Top := Round(FForm.Top);
    Data.Width := Round(FForm.ClientWidth);
    Data.Height := Round(FForm.ClientHeight);
    Data.WindowState := 1;
  end
  else
  begin
    Data.Left := Round(FForm.Left);
    Data.Top := Round(FForm.Top);
    Data.Width := Round(FForm.ClientWidth);
    Data.Height := Round(FForm.ClientHeight);
    Data.WindowState := 0;
  end;
  
  Data.MonitorIndex := 0; // FMX 暂不支持多显示器索引
  
  // 收集额外数据
  ExtraData := '';
  if Assigned(FOnSaveExtra) then
    FOnSaveExtra(Self, ExtraData);
  Data.Extra := ExtraData;
  
  FormState.SaveState(EffectiveName, Data);
end;

procedure TFMXFormStateHelper.RestoreState;
var
  Data: TFormStateData;
  FormState: TDeepBaseFormState;
  EffectiveName: string;
begin
  if FForm = nil then Exit;
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := DeepBase.Manager.DeepBase.FormState;
  if FormState.RestoreState(EffectiveName, Data) then
  begin
    // 确保窗体在可见范围内
    EnsureFormVisible(Data);
    // Set normal state before applying bounds.
    FForm.WindowState := TWindowState.wsNormal;

    // Apply bounds.
    FForm.SetBounds(Data.Left, Data.Top, Data.Width, Data.Height);

    // Restore window state.
    case Data.WindowState of
      2: FForm.WindowState := TWindowState.wsMaximized;
      // Do not restore minimized state; the user expects a visible form.
    end;
    // 恢复额外数据
    if Assigned(FOnRestoreExtra) and (Data.Extra <> '') then
      FOnRestoreExtra(Self, Data.Extra);
  end;
end;

function TFMXFormStateHelper.HasSavedState: Boolean;
var
  FormState: TDeepBaseFormState;
  EffectiveName: string;
begin
  Result := False;
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := DeepBase.Manager.DeepBase.FormState;
  Result := FormState.HasState(EffectiveName);
end;

procedure TFMXFormStateHelper.DeleteSavedState;
var
  FormState: TDeepBaseFormState;
  EffectiveName: string;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := DeepBase.Manager.DeepBase.FormState;
  FormState.DeleteState(EffectiveName);
end;

end.
