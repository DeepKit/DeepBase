{ ============================================================================
  DeepBase.FMX.ConfigControls - FMX 閰嶇疆缁戝畾鎺т欢
  
  鐗堟湰: 1.0
  璇存槑: 涓?Settings 琛ㄨ嚜鍔ㄧ粦瀹氱殑 FMX 鎺т欢
  鎺т欢:
    - TFMXConfigEdit: 缁戝畾瀛楃涓查厤缃?
    - TFMXConfigCheckBox: 缁戝畾甯冨皵閰嶇疆
    - TFMXConfigSpinBox: 缁戝畾鏁板€奸厤缃?
  ============================================================================ }

unit DeepBase.FMX.ConfigControls;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.SpinBox,
  DeepBase.Config;

type
  /// <summary>
  /// 鑷姩缁戝畾閰嶇疆鐨?FMX Edit 鎺т欢
  /// </summary>
  TFMXConfigEdit = class(TEdit)
  private
    FConfigKey: string;
    FDefaultValue: string;
    FAutoLoad: Boolean;
    FAutoSave: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure DoAutoSave(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    /// <summary>
    /// 浠庨厤缃姞杞藉€?
    /// </summary>
    procedure LoadFromConfig;
    
    /// <summary>
    /// 淇濆瓨鍊煎埌閰嶇疆
    /// </summary>
    procedure SaveToConfig;
    
  published
    /// <summary>
    /// 閰嶇疆閿悕
    /// </summary>
    property ConfigKey: string read FConfigKey write SetConfigKey;
    
    /// <summary>
    /// 榛樿鍊?
    /// </summary>
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    
    /// <summary>
    /// 鑷姩鍔犺浇
    /// </summary>
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
    
    /// <summary>
    /// 鑷姩淇濆瓨
    /// </summary>
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
  end;

  /// <summary>
  /// 鑷姩缁戝畾閰嶇疆鐨?FMX CheckBox 鎺т欢
  /// </summary>
  TFMXConfigCheckBox = class(TCheckBox)
  private
    FConfigKey: string;
    FDefaultValue: Boolean;
    FAutoLoad: Boolean;
    FAutoSave: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure DoAutoSave(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    procedure LoadFromConfig;
    procedure SaveToConfig;
    
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property DefaultValue: Boolean read FDefaultValue write FDefaultValue default False;
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
  end;

  /// <summary>
  /// 鑷姩缁戝畾閰嶇疆鐨?FMX SpinBox 鎺т欢
  /// </summary>
  TFMXConfigSpinBox = class(TSpinBox)
  private
    FConfigKey: string;
    FDefaultValue: Double;
    FAutoLoad: Boolean;
    FAutoSave: Boolean;
    
    procedure SetConfigKey(const Value: string);
    procedure DoAutoSave(Sender: TObject);
    
  protected
    procedure Loaded; override;
    
  public
    constructor Create(AOwner: TComponent); override;
    
    procedure LoadFromConfig;
    procedure SaveToConfig;
    
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property DefaultValue: Double read FDefaultValue write FDefaultValue;
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
  end;

implementation

uses
  DeepBase.Manager;

{ TFMXConfigEdit }

constructor TFMXConfigEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoLoad := True;
  FAutoSave := True;
  FDefaultValue := '';
end;

procedure TFMXConfigEdit.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FAutoLoad and (FConfigKey <> '') then
      LoadFromConfig;
      
    if FAutoSave then
      OnChange := DoAutoSave;
  end;
end;

procedure TFMXConfigEdit.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if not (csDesigning in ComponentState) and FAutoLoad then
      LoadFromConfig;
  end;
end;

procedure TFMXConfigEdit.LoadFromConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    Text := DeepBase.Manager.DeepBase.Config.GetConfig(FConfigKey, FDefaultValue)
  else
    Text := FDefaultValue;
end;

procedure TFMXConfigEdit.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Config.SetConfig(FConfigKey, Text);
end;

procedure TFMXConfigEdit.DoAutoSave(Sender: TObject);
begin
  if FAutoSave then
    SaveToConfig;
end;

{ TFMXConfigCheckBox }

constructor TFMXConfigCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoLoad := True;
  FAutoSave := True;
  FDefaultValue := False;
end;

procedure TFMXConfigCheckBox.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FAutoLoad and (FConfigKey <> '') then
      LoadFromConfig;
      
    if FAutoSave then
      OnChange := DoAutoSave;
  end;
end;

procedure TFMXConfigCheckBox.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if not (csDesigning in ComponentState) and FAutoLoad then
      LoadFromConfig;
  end;
end;

procedure TFMXConfigCheckBox.LoadFromConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    IsChecked := DeepBase.Manager.DeepBase.Config.GetConfigBool(FConfigKey, FDefaultValue)
  else
    IsChecked := FDefaultValue;
end;

procedure TFMXConfigCheckBox.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Config.SetConfigBool(FConfigKey, IsChecked);
end;

procedure TFMXConfigCheckBox.DoAutoSave(Sender: TObject);
begin
  if FAutoSave then
    SaveToConfig;
end;

{ TFMXConfigSpinBox }

constructor TFMXConfigSpinBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoLoad := True;
  FAutoSave := True;
  FDefaultValue := 0;
end;

procedure TFMXConfigSpinBox.Loaded;
begin
  inherited;
  
  if not (csDesigning in ComponentState) then
  begin
    if FAutoLoad and (FConfigKey <> '') then
      LoadFromConfig;
      
    if FAutoSave then
      OnChange := DoAutoSave;
  end;
end;

procedure TFMXConfigSpinBox.SetConfigKey(const Value: string);
begin
  if FConfigKey <> Value then
  begin
    FConfigKey := Value;
    if not (csDesigning in ComponentState) and FAutoLoad then
      LoadFromConfig;
  end;
end;

procedure TFMXConfigSpinBox.LoadFromConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    Value := DeepBase.Manager.DeepBase.Config.GetConfigFloat(FConfigKey, FDefaultValue)
  else
    Value := FDefaultValue;
end;

procedure TFMXConfigSpinBox.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if DeepBase.Manager.DeepBase.IsInitialized then
    DeepBase.Manager.DeepBase.Config.SetConfigFloat(FConfigKey, Value);
end;

procedure TFMXConfigSpinBox.DoAutoSave(Sender: TObject);
begin
  if FAutoSave then
    SaveToConfig;
end;

end.
