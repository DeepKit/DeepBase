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
  Vcl.Controls,
  System.Types;

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
      // 忽略销毁时的错误
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
  if FForm = nil then Exit;
  
  // 恢复原始事件（只在我们的处理器还在时才恢复）
  if @FForm.OnShow = @InternalOnShow then
    FForm.OnShow := FOldOnShow;
    
  if @FForm.OnClose = @InternalOnClose then
    FForm.OnClose := FOldOnClose;
    
  if @FForm.OnDestroy = @InternalOnDestroy then
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
      // 忽略销毁时的错误
    end;
  end;
  
  // 链式调用原始 OnDestroy
  if Assigned(FOldOnDestroy) then
    FOldOnDestroy(Sender);
end;

procedure TFormStateHelper.EnsureFormVisible(var Data: TFormStateData);
var
  I: Integer;
  MonitorRect: TRect;
  FormRect: TRect;
  FoundMonitor: Boolean;
begin
  // 检查窗体是否在任一显示器的可见范围内
  FormRect := Rect(Data.Left, Data.Top, Data.Left + Data.Width, Data.Top + Data.Height);
  FoundMonitor := False;
  
  for I := 0 to Screen.MonitorCount - 1 do
  begin
    MonitorRect := Screen.Monitors[I].WorkareaRect;
    
    // 检查窗体是否与显示器有交集（至少有一部分可见）
    if (FormRect.Left < MonitorRect.Right) and 
       (FormRect.Right > MonitorRect.Left) and
       (FormRect.Top < MonitorRect.Bottom) and 
       (FormRect.Bottom > MonitorRect.Top) then
    begin
      FoundMonitor := True;
      Break;
    end;
  end;
  
  // 如果窗体完全不在任何显示器上，移到主显示器
  if not FoundMonitor then
  begin
    MonitorRect := Screen.PrimaryMonitor.WorkareaRect;
    
    // 确保窗体不超出屏幕
    if Data.Width > MonitorRect.Width then
      Data.Width := MonitorRect.Width - 20;
    if Data.Height > MonitorRect.Height then
      Data.Height := MonitorRect.Height - 20;
      
    // 居中显示
    Data.Left := MonitorRect.Left + (MonitorRect.Width - Data.Width) div 2;
    Data.Top := MonitorRect.Top + (MonitorRect.Height - Data.Height) div 2;
    Data.MonitorIndex := Screen.PrimaryMonitor.MonitorNum;
  end;
end;

procedure TFormStateHelper.SaveState;
var
  Data: TFormStateData;
  ExtraData: string;
  FormState: TUniBaseFormState;
  EffectiveName: string;
begin
  if FForm = nil then Exit;
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := TUniBaseFormState.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
  try
    // 收集状态数据
    Data.Init;
    
    // 如果是最大化状态，保存 RestoreBounds
    if FForm.WindowState = wsMaximized then
    begin
      Data.Left := FForm.Left;
      Data.Top := FForm.Top;
      Data.Width := FForm.Width;
      Data.Height := FForm.Height;
      Data.WindowState := 2;
    end
    else if FForm.WindowState = wsMinimized then
    begin
      // 最小化时，尝试获取正常状态的位置
      Data.Left := FForm.Left;
      Data.Top := FForm.Top;
      Data.Width := FForm.Width;
      Data.Height := FForm.Height;
      Data.WindowState := 1;
    end
    else
    begin
      Data.Left := FForm.Left;
      Data.Top := FForm.Top;
      Data.Width := FForm.Width;
      Data.Height := FForm.Height;
      Data.WindowState := 0;
    end;
    
    Data.MonitorIndex := FForm.Monitor.MonitorNum;
    
    // 收集额外数据
    ExtraData := '';
    if Assigned(FOnSaveExtra) then
      FOnSaveExtra(Self, ExtraData);
    Data.Extra := ExtraData;
    
    FormState.SaveState(EffectiveName, Data);
  finally
    FormState.Free;
  end;
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
  
  FormState := TUniBaseFormState.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
  try
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
  finally
    FormState.Free;
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
  
  FormState := TUniBaseFormState.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
  try
    Result := FormState.HasState(EffectiveName);
  finally
    FormState.Free;
  end;
end;

procedure TFormStateHelper.DeleteSavedState;
var
  FormState: TUniBaseFormState;
  EffectiveName: string;
begin
  if not UniBase.Manager.UniBase.IsInitialized then Exit;
  
  EffectiveName := GetEffectiveFormName;
  if EffectiveName = '' then Exit;
  
  FormState := TUniBaseFormState.Create(UniBase.Manager.UniBase.ConfigDB, UniBase.Manager.UniBase.Lock);
  try
    FormState.DeleteState(EffectiveName);
  finally
    FormState.Free;
  end;
end;

end.
