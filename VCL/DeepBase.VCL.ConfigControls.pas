{ ============================================================================
  DeepBase.VCL.ConfigControls - 配置绑定控件
  
  版本: 1.0
  说明: 自动绑定 DeepBase.Config 的 VCL 控件
  ============================================================================ }

unit DeepBase.VCL.ConfigControls;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.StdCtrls,
  Vcl.Samples.Spin,
  Vcl.Controls,
  DeepBase.Manager,
  DeepBase.Config;

type
  /// <summary>
  /// 自动保存到 Config 的 Edit 控件
  /// </summary>
  TConfigEdit = class(TEdit)
  private
    FConfigKey: string;
    FDefaultValue: string;
    FCategory: string;
    FAutoSave: Boolean;
    FAutoLoad: Boolean;
    procedure SetConfigKey(const Value: string);
  protected
    procedure Loaded; override;
    procedure Change; override;
    procedure LoadFromConfig; virtual;
    procedure SaveToConfig; virtual;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property DefaultValue: string read FDefaultValue write FDefaultValue;
    property Category: string read FCategory write FCategory;
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
  end;

  /// <summary>
  /// 自动保存到 Config 的 CheckBox 控件
  /// </summary>
  TConfigCheckBox = class(TCheckBox)
  private
    FConfigKey: string;
    FDefaultValue: Boolean;
    FCategory: string;
    FAutoSave: Boolean;
    FAutoLoad: Boolean;
    procedure SetConfigKey(const Value: string);
  protected
    procedure Loaded; override;
    procedure Click; override;
    procedure LoadFromConfig; virtual;
    procedure SaveToConfig; virtual;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property DefaultValue: Boolean read FDefaultValue write FDefaultValue;
    property Category: string read FCategory write FCategory;
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
  end;

  /// <summary>
  /// 自动保存到 Config 的 SpinEdit 控件
  /// </summary>
  TConfigSpinEdit = class(TSpinEdit)
  private
    FConfigKey: string;
    FDefaultValue: Integer;
    FCategory: string;
    FAutoSave: Boolean;
    FAutoLoad: Boolean;
    procedure SetConfigKey(const Value: string);
  protected
    procedure Loaded; override;
    procedure Change; override;
    procedure LoadFromConfig; virtual;
    procedure SaveToConfig; virtual;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property ConfigKey: string read FConfigKey write SetConfigKey;
    property DefaultValue: Integer read FDefaultValue write FDefaultValue;
    property Category: string read FCategory write FCategory;
    property AutoSave: Boolean read FAutoSave write FAutoSave default True;
    property AutoLoad: Boolean read FAutoLoad write FAutoLoad default True;
  end;

implementation

{ TConfigEdit }

constructor TConfigEdit.Create(AOwner: TComponent);
begin
  inherited;
  FAutoSave := True;
  FAutoLoad := True;
  FCategory := 'General';
end;

procedure TConfigEdit.SetConfigKey(const Value: string);
begin
  FConfigKey := Value;
  // Design-time feedback could go here
end;

procedure TConfigEdit.Loaded;
begin
  inherited;
  // AutoLoad: 在窗体加载完成后自动从配置加载
  if (not (csDesigning in ComponentState)) and FAutoLoad and (FConfigKey <> '') then
    LoadFromConfig;
end;

procedure TConfigEdit.Change;
begin
  inherited;
  // AutoSave: 当用户编辑时自动保存到配置
  if (not (csDesigning in ComponentState)) and FAutoSave and (FConfigKey <> '') then
    SaveToConfig;
  // 注意: LoadFromConfig 应该在 Loaded 中调用，而不是 Change 中
end;

procedure TConfigEdit.LoadFromConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  Text := DeepBase.Manager.DeepBase.Config.GetConfig(FConfigKey, FDefaultValue);
end;

procedure TConfigEdit.SaveToConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  DeepBase.Manager.DeepBase.Config.SetConfig(FConfigKey, Text, FCategory);
end;

{ TConfigCheckBox }

constructor TConfigCheckBox.Create(AOwner: TComponent);
begin
  inherited;
  FAutoSave := True;
  FAutoLoad := True;
  FCategory := 'General';
end;

procedure TConfigCheckBox.SetConfigKey(const Value: string);
begin
  FConfigKey := Value;
end;

procedure TConfigCheckBox.Loaded;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoLoad and (FConfigKey <> '') then
    LoadFromConfig;
end;

procedure TConfigCheckBox.Click;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoSave and (FConfigKey <> '') then
    SaveToConfig;
end;

procedure TConfigCheckBox.LoadFromConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  Checked := DeepBase.Manager.DeepBase.Config.GetConfigBool(FConfigKey, FDefaultValue);
end;

procedure TConfigCheckBox.SaveToConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  DeepBase.Manager.DeepBase.Config.SetConfigBool(FConfigKey, Checked, FCategory);
end;

{ TConfigSpinEdit }

constructor TConfigSpinEdit.Create(AOwner: TComponent);
begin
  inherited;
  FAutoSave := True;
  FAutoLoad := True;
  FCategory := 'General';
end;

procedure TConfigSpinEdit.SetConfigKey(const Value: string);
begin
  FConfigKey := Value;
end;

procedure TConfigSpinEdit.Loaded;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoLoad and (FConfigKey <> '') then
    LoadFromConfig;
end;

procedure TConfigSpinEdit.Change;
begin
  inherited;
  if (not (csDesigning in ComponentState)) and FAutoSave and (FConfigKey <> '') then
    SaveToConfig;
end;

procedure TConfigSpinEdit.LoadFromConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  Value := DeepBase.Manager.DeepBase.Config.GetConfigInt(FConfigKey, FDefaultValue);
end;

procedure TConfigSpinEdit.SaveToConfig;
begin
  if not DeepBase.Manager.DeepBase.IsInitialized then Exit;
  
  DeepBase.Manager.DeepBase.Config.SetConfigInt(FConfigKey, Value, FCategory);
end;

end.
