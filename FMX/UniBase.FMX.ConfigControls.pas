{ ============================================================================
  UniBase.FMX.ConfigControls - FMX 配置绑定控件
  
  版本: 1.0
  说明: 与 Settings 表自动绑定的 FMX 控件
  控件:
    - TFMXConfigEdit: 绑定字符串配置
    - TFMXConfigCheckBox: 绑定布尔配置
    - TFMXConfigSpinBox: 绑定数值配置
  ============================================================================ }

unit UniBase.FMX.ConfigControls;

interface

uses
  System.SysUtils,
  System.Classes,
  FMX.Types,
  FMX.Controls,
  FMX.StdCtrls,
  FMX.Edit,
  FMX.SpinBox,
  UniBase.Config;

type
  /// <summary>
  /// 自动绑定配置的 FMX Edit 控件
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
    /// 从配置加载值
    /// </summary>
    procedure LoadFromConfig;
    
    /// <summary>
    /// 保存值到配置
    /// </summary>
    procedure SaveToConfig;
    
  published
    /// <summary>
    /// 配置键名
    /// </summary>
    property ConfigKey: string read FConfigKey write SetConfigKey;
    
    /// <summary>
    /// 默认值
    /// </summary>
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    
    /// <summary>
    /// 自动加载
    /// </summary>
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
    
    /// <summary>
    /// 自动保存
    /// </summary>
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
  end;

  /// <summary>
  /// 自动绑定配置的 FMX CheckBox 控件
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
  /// 自动绑定配置的 FMX SpinBox 控件
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
  UniBase.Manager;

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
    
  if UniBase.Manager.UniBase.IsInitialized then
    Text := UniBase.Manager.UniBase.Config.GetConfig(FConfigKey, FDefaultValue)
  else
    Text := FDefaultValue;
end;

procedure TFMXConfigEdit.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Config.SetConfig(FConfigKey, Text);
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
    
  if UniBase.Manager.UniBase.IsInitialized then
    IsChecked := UniBase.Manager.UniBase.Config.GetConfigBool(FConfigKey, FDefaultValue)
  else
    IsChecked := FDefaultValue;
end;

procedure TFMXConfigCheckBox.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Config.SetConfigBool(FConfigKey, IsChecked);
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
    
  if UniBase.Manager.UniBase.IsInitialized then
    Value := UniBase.Manager.UniBase.Config.GetConfigFloat(FConfigKey, FDefaultValue)
  else
    Value := FDefaultValue;
end;

procedure TFMXConfigSpinBox.SaveToConfig;
begin
  if (FConfigKey = '') then
    Exit;
    
  if UniBase.Manager.UniBase.IsInitialized then
    UniBase.Manager.UniBase.Config.SetConfigFloat(FConfigKey, Value);
end;

procedure TFMXConfigSpinBox.DoAutoSave(Sender: TObject);
begin
  if FAutoSave then
    SaveToConfig;
end;

end.
