{ ============================================================================
  DeepBase.FMX.ConfigEdit - FMX 配置编辑控件
  
  版本: 1.0
  说明: 自动绑定�?DeepBase 配置�?FMX 编辑控件
  控件:
    - TFMXConfigEdit: 字符串配置编�?
    - TFMXConfigSpinBox: 数值配置编�?
    - TFMXConfigSwitch: 布尔配置开�?
  ============================================================================ }

unit DeepBase.FMX.ConfigEdit;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Controls.Presentation,
  FMX.Edit,
  FMX.SpinBox,
  FMX.StdCtrls,
  DeepBase.Manager;

type
  /// <summary>
  /// 自动保存模式
  /// </summary>
  TConfigAutoSaveMode = (
    asmNone,        // 不自动保存，需手动调用 SaveValue
    asmOnExit,      // 失去焦点时自动保�?
    asmOnChange     // 值变化时立即保存
  );

  /// <summary>
  /// FMX 配置编辑控件 - 字符串�?
  /// </summary>
  TFMXConfigEdit = class(TEdit)
  private
    FConfigKey: string;
    FConfigCategory: string;
    FAutoSaveMode: TConfigAutoSaveMode;
    FOriginalValue: string;
    FLoaded: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure LoadValue;
    procedure DoChangeTracking(Sender: TObject);
    procedure DoExit(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>
    /// 保存当前值到配置
    /// </summary>
    procedure SaveValue;
    
    /// <summary>
    /// 重新加载配置�?
    /// </summary>
    procedure ReloadValue;
    
    /// <summary>
    /// 检查值是否已修改
    /// </summary>
    function IsModified: Boolean;
    
    /// <summary>
    /// 恢复原始�?
    /// </summary>
    procedure RevertToOriginal;
    
  published
    /// <summary>
    /// 配置键名
    /// </summary>
    property ConfigKey: string read FConfigKey write SetConfigKey;
    
    /// <summary>
    /// 配置分类（默�?'General'�?
    /// </summary>
    property ConfigCategory: string read FConfigCategory write FConfigCategory;
    
    /// <summary>
    /// 自动保存模式
    /// </summary>
    property AutoSaveMode: TConfigAutoSaveMode read FAutoSaveMode write FAutoSaveMode default asmOnExit;
  end;

  /// <summary>
  /// FMX 配置编辑控件 - 数�?
  /// </summary>
  TFMXConfigSpinBox = class(TSpinBox)
  private
    FConfigKey: string;
    FConfigCategory: string;
    FAutoSaveMode: TConfigAutoSaveMode;
    FOriginalValue: Single;
    FLoaded: Boolean;
    FIsInteger: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure LoadValue;
    procedure DoChangeTracking(Sender: TObject);
    procedure DoExit(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    procedure SaveValue;
    procedure ReloadValue;
    function IsModified: Boolean;
    procedure RevertToOriginal;
    
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property ConfigCategory: string read FConfigCategory write FConfigCategory;
    property AutoSaveMode: TConfigAutoSaveMode read FAutoSaveMode write FAutoSaveMode default asmOnExit;
    
    /// <summary>
    /// 是否作为整数保存（默�?True�?
    /// </summary>
    property IsInteger: Boolean read FIsInteger write FIsInteger default True;
  end;

  /// <summary>
  /// FMX 配置开关控�?- 布尔�?
  /// </summary>
  TFMXConfigSwitch = class(TSwitch)
  private
    FConfigKey: string;
    FConfigCategory: string;
    FAutoSaveMode: TConfigAutoSaveMode;
    FOriginalValue: Boolean;
    FLoaded: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure LoadValue;
    procedure DoSwitch(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    procedure SaveValue;
    procedure ReloadValue;
    function IsModified: Boolean;
    procedure RevertToOriginal;
    
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property ConfigCategory: string read FConfigCategory write FConfigCategory;
    property AutoSaveMode: TConfigAutoSaveMode read FAutoSaveMode write FAutoSaveMode default asmOnChange;
  end;

implementation

uses
  DeepBase.Consts;

{ TFMXConfigEdit }

constructor TFMXConfigEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfigKey := '';
  FConfigCategory := SConfigCategoryGeneral;
  FAutoSaveMode := asmOnExit;
  FOriginalValue := '';
  FLoaded := False;
  
  OnChangeTracking := DoChangeTracking;
  OnExit := DoExit;
end;

procedure TFMXConfigEdit.Loaded;
begin
  inherited;
  FLoaded := True;
  
  if not (csDesigning in ComponentState) then
    LoadValue;
end;

procedure TFMXConfigEdit.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if FLoaded and not (csDesigning in ComponentState) then
      LoadValue;
  end;
end;

procedure TFMXConfigEdit.LoadValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  Text := DeepBase.Manager.DeepBase.Config.GetConfig(FConfigKey, '');
  FOriginalValue := Text;
end;

procedure TFMXConfigEdit.SaveValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  DeepBase.Manager.DeepBase.Config.SetConfig(FConfigKey, Text, FConfigCategory);
  FOriginalValue := Text;
end;

procedure TFMXConfigEdit.ReloadValue;
begin
  LoadValue;
end;

function TFMXConfigEdit.IsModified: Boolean;
begin
  Result := Text <> FOriginalValue;
end;

procedure TFMXConfigEdit.RevertToOriginal;
begin
  Text := FOriginalValue;
end;

procedure TFMXConfigEdit.DoChangeTracking(Sender: TObject);
begin
  if FAutoSaveMode = asmOnChange then
    SaveValue;
end;

procedure TFMXConfigEdit.DoExit(Sender: TObject);
begin
  if FAutoSaveMode = asmOnExit then
    SaveValue;
end;

{ TFMXConfigSpinBox }

constructor TFMXConfigSpinBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfigKey := '';
  FConfigCategory := SConfigCategoryGeneral;
  FAutoSaveMode := asmOnExit;
  FOriginalValue := 0;
  FLoaded := False;
  FIsInteger := True;
  
  OnChange := DoChangeTracking;
  OnExit := DoExit;
end;

procedure TFMXConfigSpinBox.Loaded;
begin
  inherited;
  FLoaded := True;
  
  if not (csDesigning in ComponentState) then
    LoadValue;
end;

procedure TFMXConfigSpinBox.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if FLoaded and not (csDesigning in ComponentState) then
      LoadValue;
  end;
end;

procedure TFMXConfigSpinBox.LoadValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  if FIsInteger then
    Value := DeepBase.Manager.DeepBase.Config.GetConfigInt(FConfigKey, 0)
  else
    Value := DeepBase.Manager.DeepBase.Config.GetConfigFloat(FConfigKey, 0);
    
  FOriginalValue := Value;
end;

procedure TFMXConfigSpinBox.SaveValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  if FIsInteger then
    DeepBase.Manager.DeepBase.Config.SetConfigInt(FConfigKey, Round(Value), FConfigCategory)
  else
    DeepBase.Manager.DeepBase.Config.SetConfigFloat(FConfigKey, Value, FConfigCategory);
    
  FOriginalValue := Value;
end;

procedure TFMXConfigSpinBox.ReloadValue;
begin
  LoadValue;
end;

function TFMXConfigSpinBox.IsModified: Boolean;
begin
  Result := Value <> FOriginalValue;
end;

procedure TFMXConfigSpinBox.RevertToOriginal;
begin
  Value := FOriginalValue;
end;

procedure TFMXConfigSpinBox.DoChangeTracking(Sender: TObject);
begin
  if FAutoSaveMode = asmOnChange then
    SaveValue;
end;

procedure TFMXConfigSpinBox.DoExit(Sender: TObject);
begin
  if FAutoSaveMode = asmOnExit then
    SaveValue;
end;

{ TFMXConfigSwitch }

constructor TFMXConfigSwitch.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConfigKey := '';
  FConfigCategory := SConfigCategoryGeneral;
  FAutoSaveMode := asmOnChange;  // 开关默认立即保�?
  FOriginalValue := False;
  FLoaded := False;
  
  OnSwitch := DoSwitch;
end;

procedure TFMXConfigSwitch.Loaded;
begin
  inherited;
  FLoaded := True;
  
  if not (csDesigning in ComponentState) then
    LoadValue;
end;

procedure TFMXConfigSwitch.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if FLoaded and not (csDesigning in ComponentState) then
      LoadValue;
  end;
end;

procedure TFMXConfigSwitch.LoadValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  IsChecked := DeepBase.Manager.DeepBase.Config.GetConfigBool(FConfigKey, False);
  FOriginalValue := IsChecked;
end;

procedure TFMXConfigSwitch.SaveValue;
begin
  if (FConfigKey = '') or not DeepBase.Manager.DeepBase.IsInitialized then
    Exit;
    
  DeepBase.Manager.DeepBase.Config.SetConfigBool(FConfigKey, IsChecked, FConfigCategory);
  FOriginalValue := IsChecked;
end;

procedure TFMXConfigSwitch.ReloadValue;
begin
  LoadValue;
end;

function TFMXConfigSwitch.IsModified: Boolean;
begin
  Result := IsChecked <> FOriginalValue;
end;

procedure TFMXConfigSwitch.RevertToOriginal;
begin
  IsChecked := FOriginalValue;
end;

procedure TFMXConfigSwitch.DoSwitch(Sender: TObject);
begin
  if FAutoSaveMode = asmOnChange then
    SaveValue;
end;

end.
