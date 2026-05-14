// AI-GENERATED
// DeepBase.Governance.EventBridge.pas
// P02：事件桥 — 把 Delphi 原生事件转换为 Runtime.EnterGate 请求

unit DeepBase.Governance.EventBridge;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// 事件桥绑定项
  TEventBridgeBinding = record
    NativeObjectName: string;
    NativeEventName: string;
    GateKey: string;
    ContextBuilder: TFunc<TJSONObject>;  // 构建上下文的回调
  end;

  /// 事件桥 — 把原生事件转为 Runtime.EnterGate
  TEventBridge = class
  private
    FRuntime: IOCGSRuntime;
    FBindings: TList<TEventBridgeBinding>;
    FDefaultMode: TRunMode;
  public
    constructor Create(ARuntime: IOCGSRuntime);
    destructor Destroy; override;

    /// 绑定：原生事件 → GateKey
    procedure Bind(const ANativeObjectName, ANativeEventName, AGateKey: string;
      AContextBuilder: TFunc<TJSONObject> = nil);

    /// 解绑
    procedure Unbind(const ANativeObjectName, ANativeEventName: string);

    /// 触发：当原生事件发生时调用此方法
    function Fire(const ANativeObjectName, ANativeEventName: string;
      AExtraContext: TJSONObject = nil): TActionResult;

    /// 预览：检查门禁状态但不执行
    function Preview(const ANativeObjectName, ANativeEventName: string;
      AExtraContext: TJSONObject = nil): TGateResolution;

    /// 查找绑定
    function FindBinding(const ANativeObjectName, ANativeEventName: string): Integer;
    function GetBindingCount: Integer;

    property DefaultMode: TRunMode read FDefaultMode write FDefaultMode;
  end;

implementation

{ TEventBridge }

constructor TEventBridge.Create(ARuntime: IOCGSRuntime);
begin
  inherited Create;
  FRuntime := ARuntime;
  FBindings := TList<TEventBridgeBinding>.Create;
  FDefaultMode := rmCommit;
end;

destructor TEventBridge.Destroy;
begin
  FBindings.Free;
  inherited;
end;

procedure TEventBridge.Bind(const ANativeObjectName, ANativeEventName,
  AGateKey: string; AContextBuilder: TFunc<TJSONObject>);
var
  LBinding: TEventBridgeBinding;
begin
  LBinding.NativeObjectName := ANativeObjectName;
  LBinding.NativeEventName := ANativeEventName;
  LBinding.GateKey := AGateKey;
  LBinding.ContextBuilder := AContextBuilder;
  FBindings.Add(LBinding);
end;

procedure TEventBridge.Unbind(const ANativeObjectName, ANativeEventName: string);
var
  LIdx: Integer;
begin
  LIdx := FindBinding(ANativeObjectName, ANativeEventName);
  if LIdx >= 0 then
    FBindings.Delete(LIdx);
end;

function TEventBridge.FindBinding(const ANativeObjectName,
  ANativeEventName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FBindings.Count - 1 do
  begin
    if SameText(FBindings[I].NativeObjectName, ANativeObjectName) and
       SameText(FBindings[I].NativeEventName, ANativeEventName) then
      Exit(I);
  end;
  Result := -1;
end;

function TEventBridge.GetBindingCount: Integer;
begin
  Result := FBindings.Count;
end;

function TEventBridge.Fire(const ANativeObjectName, ANativeEventName: string;
  AExtraContext: TJSONObject): TActionResult;
var
  LIdx: Integer;
  LBinding: TEventBridgeBinding;
  LContext: TJSONObject;
begin
  LIdx := FindBinding(ANativeObjectName, ANativeEventName);
  if LIdx < 0 then
    Exit(TActionResult.Fail('', 'No binding for ' + ANativeObjectName + '.' + ANativeEventName));

  LBinding := FBindings[LIdx];

  // 构建上下文
  if Assigned(LBinding.ContextBuilder) then
    LContext := LBinding.ContextBuilder()
  else if AExtraContext <> nil then
    LContext := AExtraContext
  else
    LContext := TJSONObject.Create;

  try
    Result := FRuntime.EnterGate(LBinding.GateKey, LContext, FDefaultMode);
  finally
    if (LContext <> AExtraContext) and not Assigned(LBinding.ContextBuilder) then
      LContext.Free
    else if Assigned(LBinding.ContextBuilder) then
      LContext.Free;
  end;
end;

function TEventBridge.Preview(const ANativeObjectName, ANativeEventName: string;
  AExtraContext: TJSONObject): TGateResolution;
var
  LIdx: Integer;
  LBinding: TEventBridgeBinding;
  LContext: TJSONObject;
begin
  LIdx := FindBinding(ANativeObjectName, ANativeEventName);
  if LIdx < 0 then
  begin
    Result.GateKey := '';
    Result.State := gsClosed;
    Result.BlockedReason := 'No binding';
    Result.AvailableActions := nil;
    Exit;
  end;

  LBinding := FBindings[LIdx];

  if Assigned(LBinding.ContextBuilder) then
    LContext := LBinding.ContextBuilder()
  else if AExtraContext <> nil then
    LContext := AExtraContext
  else
    LContext := TJSONObject.Create;

  try
    Result := FRuntime.PreviewGate(LBinding.GateKey, LContext);
  finally
    if (LContext <> AExtraContext) and not Assigned(LBinding.ContextBuilder) then
      LContext.Free
    else if Assigned(LBinding.ContextBuilder) then
      LContext.Free;
  end;
end;

end.
