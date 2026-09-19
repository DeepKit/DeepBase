{ ============================================================================
  DeepBase.FMX.ConfigEdit - FMX 閰嶇疆缂栬緫鎺т欢
  
  鐗堟湰: 1.0
  璇存槑: 鑷姩缁戝畾鍒?DeepBase 閰嶇疆鐨?FMX 缂栬緫鎺т欢
  鎺т欢:
    - TFMXConfigEdit: 瀛楃涓查厤缃紪杈?
    - TFMXConfigSpinBox: 鏁板€奸厤缃紪杈?
    - TFMXConfigSwitch: 甯冨皵閰嶇疆寮€鍏?
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
  /// 鑷姩淇濆瓨妯″紡
  /// </summary>
  TConfigAutoSaveMode = (
    asmNone,        // 涓嶈嚜鍔ㄤ繚瀛橈紝闇€鎵嬪姩璋冪敤 SaveValue
    asmOnExit,      // 澶卞幓鐒︾偣鏃惰嚜鍔ㄤ繚瀛?
    asmOnChange     // 鍊煎彉鍖栨椂绔嬪嵆淇濆瓨
  );

  /// <summary>
  /// FMX 閰嶇疆缂栬緫鎺т欢 - 瀛楃涓插€?
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
    /// 淇濆瓨褰撳墠鍊煎埌閰嶇疆
    /// </summary>
    procedure SaveValue;
    
    /// <summary>
    /// 閲嶆柊鍔犺浇閰嶇疆鍊?
    /// </summary>
    procedure ReloadValue;
    
    /// <summary>
    /// 妫€鏌ュ€兼槸鍚﹀凡淇敼
    /// </summary>
    function IsModified: Boolean;
    
    /// <summary>
    /// 鎭㈠鍘熷鍊?
    /// </summary>
    procedure RevertToOriginal;
    
  published
    /// <summary>
    /// 閰嶇疆閿悕
    /// </summary>
    property ConfigKey: string read FConfigKey write SetConfigKey;
    
    /// <summary>
    /// 閰嶇疆鍒嗙被锛堥粯璁?'General'锛?
    /// </summary>
    property ConfigCategory: string read FConfigCategory write FConfigCategory;
    
    /// <summary>
    /// 鑷姩淇濆瓨妯″紡
    /// </summary>
    property AutoSaveMode: TConfigAutoSaveMode read FAutoSaveMode write FAutoSaveMode default asmOnExit;
  end;

  /// <summary>
  /// FMX 閰嶇疆缂栬緫鎺т欢 - 鏁板€?
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
    /// 鏄惁浣滀负鏁存暟淇濆瓨锛堥粯璁?True锛?
    /// </summary>
    property IsInteger: Boolean read FIsInteger write FIsInteger default True;
  end;

  /// <summary>
  /// FMX 閰嶇疆寮€鍏虫帶浠?- 甯冨皵鍊?
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
  FAutoSaveMode := asmOnChange;  // 寮€鍏抽粯璁ょ珛鍗充繚瀛?
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
