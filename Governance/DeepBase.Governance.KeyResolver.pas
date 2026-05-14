// AI-GENERATED
// DeepBase.Governance.KeyResolver.pas
// 第四层：Key → 对象引用查找
// 依赖 Model，其他 Engine 都需要它

unit DeepBase.Governance.KeyResolver;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.Model;

type
  TKeyResolver = class(TInterfacedObject, IKeyResolver)
  private
    FGates: TObjectDictionary<string, TAccessGate>;
    FActions: TObjectDictionary<string, TAction>;
    FAbilities: TObjectDictionary<string, TAbility>;
    FFields: TObjectDictionary<string, TContextField>;
    FBridgeKeys: TDictionary<string, Boolean>;
  public
    constructor Create;
    destructor Destroy; override;

    // 注册
    procedure RegisterGate(AGate: TAccessGate);
    procedure RegisterAction(AAction: TAction);
    procedure RegisterAbility(AAbility: TAbility);
    procedure RegisterField(AField: TContextField);

    // IKeyResolver
    function ResolveGateKey(const AKey: string): TAccessGate;
    function ResolveActionKey(const AKey: string): TAction;
    function Exists(const AKey: string): Boolean;

    // 扩展查找
    function ResolveAbility(const AKey: string): TAbility;
    function ResolveField(const AKey: string): TContextField;
    function GetAllGateKeys: TArray<string>;
    function GetAllActionKeys: TArray<string>;
    function GetAllActions: TArray<TAction>;
    function GetAllGates: TArray<TAccessGate>;
    function GetAllAbilities: TArray<TAbility>;
    function GetAllFields: TArray<TContextField>;

    // Bridge 注册（P0 修复：Validation 需要检查 BridgeKey 是否已注册）
    procedure RegisterBridgeKey(const AKey: string);
    function IsBridgeRegistered(const AKey: string): Boolean;
  end;

implementation

{ TKeyResolver }

constructor TKeyResolver.Create;
begin
  inherited Create;
  FGates := TObjectDictionary<string, TAccessGate>.Create([doOwnsValues]);
  FActions := TObjectDictionary<string, TAction>.Create([doOwnsValues]);
  FAbilities := TObjectDictionary<string, TAbility>.Create([doOwnsValues]);
  FFields := TObjectDictionary<string, TContextField>.Create([doOwnsValues]);
  FBridgeKeys := TDictionary<string, Boolean>.Create;
end;

destructor TKeyResolver.Destroy;
begin
  FBridgeKeys.Free;
  FFields.Free;
  FAbilities.Free;
  FActions.Free;
  FGates.Free;
  inherited;
end;

procedure TKeyResolver.RegisterGate(AGate: TAccessGate);
begin
  if AGate = nil then
    raise EArgumentNilException.Create('AGate cannot be nil');
  FGates.AddOrSetValue(AGate.Key, AGate);
end;

procedure TKeyResolver.RegisterAction(AAction: TAction);
begin
  if AAction = nil then
    raise EArgumentNilException.Create('AAction cannot be nil');
  FActions.AddOrSetValue(AAction.Key, AAction);
end;

procedure TKeyResolver.RegisterAbility(AAbility: TAbility);
begin
  if AAbility = nil then
    raise EArgumentNilException.Create('AAbility cannot be nil');
  FAbilities.AddOrSetValue(AAbility.Key, AAbility);
end;

procedure TKeyResolver.RegisterField(AField: TContextField);
begin
  if AField = nil then
    raise EArgumentNilException.Create('AField cannot be nil');
  FFields.AddOrSetValue(AField.Key, AField);
end;

function TKeyResolver.ResolveGateKey(const AKey: string): TAccessGate;
begin
  if not FGates.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TKeyResolver.ResolveActionKey(const AKey: string): TAction;
begin
  if not FActions.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TKeyResolver.Exists(const AKey: string): Boolean;
begin
  Result := FGates.ContainsKey(AKey) or
            FActions.ContainsKey(AKey) or
            FAbilities.ContainsKey(AKey) or
            FFields.ContainsKey(AKey);
end;

function TKeyResolver.ResolveAbility(const AKey: string): TAbility;
begin
  if not FAbilities.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TKeyResolver.ResolveField(const AKey: string): TContextField;
begin
  if not FFields.TryGetValue(AKey, Result) then
    Result := nil;
end;

function TKeyResolver.GetAllGateKeys: TArray<string>;
begin
  Result := FGates.Keys.ToArray;
end;

function TKeyResolver.GetAllActionKeys: TArray<string>;
begin
  Result := FActions.Keys.ToArray;
end;

function TKeyResolver.GetAllActions: TArray<TAction>;
begin
  Result := FActions.Values.ToArray;
end;

function TKeyResolver.GetAllGates: TArray<TAccessGate>;
begin
  Result := FGates.Values.ToArray;
end;

function TKeyResolver.GetAllAbilities: TArray<TAbility>;
begin
  Result := FAbilities.Values.ToArray;
end;

function TKeyResolver.GetAllFields: TArray<TContextField>;
begin
  Result := FFields.Values.ToArray;
end;

procedure TKeyResolver.RegisterBridgeKey(const AKey: string);
begin
  FBridgeKeys.AddOrSetValue(AKey, True);
end;

function TKeyResolver.IsBridgeRegistered(const AKey: string): Boolean;
begin
  Result := FBridgeKeys.ContainsKey(AKey);
end;

end.
