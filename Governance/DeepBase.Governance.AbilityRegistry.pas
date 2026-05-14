// AI-GENERATED
// DeepBase.Governance.AbilityRegistry.pas
// P04：能力注册表 — 全局 Ability 登记、契约验证、DryRun 支持

unit DeepBase.Governance.AbilityRegistry;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model;

type
  /// 能力描述符（输入/输出契约）
  TAbilityDescriptor = record
    AbilityKey: string;
    InputFields: TArray<string>;   // 必需输入字段名
    OutputFields: TArray<string>;  // 输出字段名
    SideEffectLevel: string;       // None/ReadOnly/LocalWrite/DatabaseWrite/Destructive
    DryRunSupported: Boolean;
    MockSupported: Boolean;
  end;

  /// 能力注册表
  TAbilityRegistry = class
  private
    FAbilities: TObjectDictionary<string, TAbility>;
    FDescriptors: TDictionary<string, TAbilityDescriptor>;
    FBridges: TDictionary<string, IBridge>;
  public
    constructor Create;
    destructor Destroy; override;

    // 注册
    procedure RegisterAbility(AAbility: TAbility);
    procedure RegisterDescriptor(const ADescriptor: TAbilityDescriptor);
    procedure RegisterBridge(const AAbilityKey: string; ABridge: IBridge);

    // 查找
    function FindAbility(const AKey: string): TAbility;
    function FindDescriptor(const AKey: string): TAbilityDescriptor;
    function FindBridge(const AAbilityKey: string): IBridge;
    function Exists(const AKey: string): Boolean;

    // 契约验证
    function ValidateInput(const AAbilityKey: string;
      AContext: TJSONObject): Boolean;
    function GetMissingInputFields(const AAbilityKey: string;
      AContext: TJSONObject): TArray<string>;

    // 执行
    function Execute(const AAbilityKey: string; AContext: TJSONObject;
      AMode: TRunMode): TActionResult;
    function DryRun(const AAbilityKey: string;
      AContext: TJSONObject): TActionResult;

    // 统计
    function Count: Integer;
    function GetAllKeys: TArray<string>;
  end;

implementation

{ TAbilityRegistry }

constructor TAbilityRegistry.Create;
begin
  inherited Create;
  FAbilities := TObjectDictionary<string, TAbility>.Create([doOwnsValues]);
  FDescriptors := TDictionary<string, TAbilityDescriptor>.Create;
  FBridges := TDictionary<string, IBridge>.Create;
end;

destructor TAbilityRegistry.Destroy;
begin
  FBridges.Free;
  FDescriptors.Free;
  FAbilities.Free;
  inherited;
end;

procedure TAbilityRegistry.RegisterAbility(AAbility: TAbility);
begin
  FAbilities.AddOrSetValue(AAbility.Key, AAbility);
end;

procedure TAbilityRegistry.RegisterDescriptor(const ADescriptor: TAbilityDescriptor);
begin
  FDescriptors.AddOrSetValue(ADescriptor.AbilityKey, ADescriptor);
end;

procedure TAbilityRegistry.RegisterBridge(const AAbilityKey: string;
  ABridge: IBridge);
begin
  FBridges.AddOrSetValue(AAbilityKey, ABridge);
end;

function TAbilityRegistry.FindAbility(const AKey: string): TAbility;
begin
  if not FAbilities.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TAbilityRegistry.FindDescriptor(const AKey: string): TAbilityDescriptor;
begin
  if not FDescriptors.TryGetValue(AKey, Result) then
  begin
    Result.AbilityKey := '';
    Result.InputFields := nil;
    Result.OutputFields := nil;
    Result.SideEffectLevel := 'Unknown';
    Result.DryRunSupported := False;
    Result.MockSupported := False;
  end;
end;

function TAbilityRegistry.FindBridge(const AAbilityKey: string): IBridge;
begin
  if not FBridges.TryGetValue(AAbilityKey, Result) then
    Result := nil;
end;

function TAbilityRegistry.Exists(const AKey: string): Boolean;
begin
  Result := FAbilities.ContainsKey(AKey);
end;

function TAbilityRegistry.ValidateInput(const AAbilityKey: string;
  AContext: TJSONObject): Boolean;
begin
  Result := Length(GetMissingInputFields(AAbilityKey, AContext)) = 0;
end;

function TAbilityRegistry.GetMissingInputFields(const AAbilityKey: string;
  AContext: TJSONObject): TArray<string>;
var
  LDesc: TAbilityDescriptor;
  LMissing: TList<string>;
  LField: string;
begin
  LDesc := FindDescriptor(AAbilityKey);
  if LDesc.AbilityKey = '' then
    Exit(nil);  // 无描述符时不检查

  LMissing := TList<string>.Create;
  try
    for LField in LDesc.InputFields do
    begin
      if (AContext = nil) or (AContext.GetValue(LField) = nil) then
        LMissing.Add(LField);
    end;
    Result := LMissing.ToArray;
  finally
    LMissing.Free;
  end;
end;

function TAbilityRegistry.Execute(const AAbilityKey: string;
  AContext: TJSONObject; AMode: TRunMode): TActionResult;
var
  LBridge: IBridge;
begin
  LBridge := FindBridge(AAbilityKey);
  if LBridge = nil then
    Exit(TActionResult.Fail(AAbilityKey,
      'No Bridge registered for ability: ' + AAbilityKey));

  if not LBridge.CanExecute(AContext) then
    Exit(TActionResult.Blocked(AAbilityKey,
      'Bridge cannot execute: ' + AAbilityKey));

  // 输入契约验证
  if not ValidateInput(AAbilityKey, AContext) then
    Exit(TActionResult.Fail(AAbilityKey,
      'Missing input fields: ' + String.Join(', ',
        GetMissingInputFields(AAbilityKey, AContext))));

  Result := LBridge.Execute(AContext, AMode);
end;

function TAbilityRegistry.DryRun(const AAbilityKey: string;
  AContext: TJSONObject): TActionResult;
var
  LDesc: TAbilityDescriptor;
begin
  LDesc := FindDescriptor(AAbilityKey);
  if (LDesc.AbilityKey <> '') and not LDesc.DryRunSupported then
    Exit(TActionResult.Fail(AAbilityKey,
      'DryRun not supported for ability: ' + AAbilityKey));

  Result := Execute(AAbilityKey, AContext, rmDryRun);
end;

function TAbilityRegistry.Count: Integer;
begin
  Result := FAbilities.Count;
end;

function TAbilityRegistry.GetAllKeys: TArray<string>;
begin
  Result := FAbilities.Keys.ToArray;
end;

end.
