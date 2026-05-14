// AI-GENERATED
// DeepBase.Governance.ActionBinding.pas
// P02：入口绑定 — TAction/Button/MenuItem → ActionKey/GateKey 映射

unit DeepBase.Governance.ActionBinding;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  /// 绑定模式
  TBindingMode = (
    bmGate,       // 绑定到 GateKey（推荐，走完整治理链路）
    bmAction,     // 绑定到 ActionKey（跳过门禁，仅用于 L0）
    bmLegacy      // 绑定到旧事件函数（过渡期）
  );

  /// 入口绑定项
  TActionBindingEntry = class
  private
    FNativeObjectName: string;
    FNativeEventName: string;
    FMode: TBindingMode;
    FTargetKey: string;         // GateKey 或 ActionKey
    FLegacyHandlerRef: string;  // 旧事件函数引用（bmLegacy 模式）
    FActive: Boolean;
  public
    constructor Create(const ANativeObjectName, ANativeEventName: string;
      AMode: TBindingMode; const ATargetKey: string;
      const ALegacyHandlerRef: string = '');
    property NativeObjectName: string read FNativeObjectName;
    property NativeEventName: string read FNativeEventName;
    property Mode: TBindingMode read FMode;
    property TargetKey: string read FTargetKey;
    property LegacyHandlerRef: string read FLegacyHandlerRef;
    property Active: Boolean read FActive write FActive;
  end;

  /// 入口绑定注册表
  TActionBindingRegistry = class
  private
    FBindings: TObjectList<TActionBindingEntry>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Register(AEntry: TActionBindingEntry);
    procedure Unregister(const ANativeObjectName, ANativeEventName: string);

    function Find(const ANativeObjectName, ANativeEventName: string): TActionBindingEntry;
    function FindByTarget(const ATargetKey: string): TArray<TActionBindingEntry>;
    function GetAll: TArray<TActionBindingEntry>;
    function Count: Integer;

    // 批量从 TAction.Name 推导绑定（约定：TAction.Name = ActionKey）
    procedure AutoBindFromActionNames(AActionList: TComponent);
  end;

implementation

{ TActionBindingEntry }

constructor TActionBindingEntry.Create(const ANativeObjectName,
  ANativeEventName: string; AMode: TBindingMode; const ATargetKey,
  ALegacyHandlerRef: string);
begin
  inherited Create;
  FNativeObjectName := ANativeObjectName;
  FNativeEventName := ANativeEventName;
  FMode := AMode;
  FTargetKey := ATargetKey;
  FLegacyHandlerRef := ALegacyHandlerRef;
  FActive := True;
end;

{ TActionBindingRegistry }

constructor TActionBindingRegistry.Create;
begin
  inherited Create;
  FBindings := TObjectList<TActionBindingEntry>.Create(True);
end;

destructor TActionBindingRegistry.Destroy;
begin
  FBindings.Free;
  inherited;
end;

procedure TActionBindingRegistry.Register(AEntry: TActionBindingEntry);
begin
  FBindings.Add(AEntry);
end;

procedure TActionBindingRegistry.Unregister(const ANativeObjectName,
  ANativeEventName: string);
var
  I: Integer;
begin
  for I := FBindings.Count - 1 downto 0 do
  begin
    if SameText(FBindings[I].NativeObjectName, ANativeObjectName) and
       SameText(FBindings[I].NativeEventName, ANativeEventName) then
    begin
      FBindings.Delete(I);
      Exit;
    end;
  end;
end;

function TActionBindingRegistry.Find(const ANativeObjectName,
  ANativeEventName: string): TActionBindingEntry;
var
  LEntry: TActionBindingEntry;
begin
  for LEntry in FBindings do
  begin
    if SameText(LEntry.NativeObjectName, ANativeObjectName) and
       SameText(LEntry.NativeEventName, ANativeEventName) then
      Exit(LEntry);
  end;
  Result := nil;
end;

function TActionBindingRegistry.FindByTarget(
  const ATargetKey: string): TArray<TActionBindingEntry>;
var
  LList: TList<TActionBindingEntry>;
  LEntry: TActionBindingEntry;
begin
  LList := TList<TActionBindingEntry>.Create;
  try
    for LEntry in FBindings do
      if SameText(LEntry.TargetKey, ATargetKey) then
        LList.Add(LEntry);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TActionBindingRegistry.GetAll: TArray<TActionBindingEntry>;
begin
  Result := FBindings.ToArray;
end;

function TActionBindingRegistry.Count: Integer;
begin
  Result := FBindings.Count;
end;

procedure TActionBindingRegistry.AutoBindFromActionNames(AActionList: TComponent);
var
  I: Integer;
  LChild: TComponent;
  LEntry: TActionBindingEntry;
begin
  if AActionList = nil then Exit;
  for I := 0 to AActionList.ComponentCount - 1 do
  begin
    LChild := AActionList.Components[I];
    if LChild.Name <> '' then
    begin
      // 约定：TAction.Name 直接作为 ActionKey
      LEntry := TActionBindingEntry.Create(
        LChild.Name, 'OnExecute', bmAction, LChild.Name);
      Register(LEntry);
    end;
  end;
end;

end.
