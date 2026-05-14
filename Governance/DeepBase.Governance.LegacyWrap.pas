// AI-GENERATED
// DeepBase.Governance.LegacyWrap.pas
// P02：旧事件函数包装 Bridge — 让老代码先进入治理链路

unit DeepBase.Governance.LegacyWrap;

interface

uses
  System.SysUtils,
  System.JSON,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces,
  DeepBase.Governance.NativeRegistry;

type
  /// 旧事件函数签名（无参数版本）
  TLegacyProc = reference to procedure;

  /// 旧事件函数签名（带 Context 版本）
  TLegacyContextProc = reference to procedure(AContext: TJSONObject);

  /// 旧事件包装 Bridge
  TLegacyWrapBridge = class(TInterfacedObject, IBridge)
  private
    FKey: string;
    FLegacyProc: TLegacyProc;
    FLegacyContextProc: TLegacyContextProc;
    FRefactorStatus: TRefactorStatus;
    FDescription: string;
  public
    /// 包装无参数旧函数
    constructor CreateSimple(const AKey: string; AProc: TLegacyProc;
      const ADescription: string = '');
    /// 包装带 Context 旧函数
    constructor CreateWithContext(const AKey: string; AProc: TLegacyContextProc;
      const ADescription: string = '');

    // IBridge
    function GetKey: string;
    function Execute(AContext: TJSONObject; AMode: TRunMode): TActionResult;
    function CanExecute(AContext: TJSONObject): Boolean;

    property RefactorStatus: TRefactorStatus read FRefactorStatus write FRefactorStatus;
    property Description: string read FDescription;
  end;

implementation

{ TLegacyWrapBridge }

constructor TLegacyWrapBridge.CreateSimple(const AKey: string;
  AProc: TLegacyProc; const ADescription: string);
begin
  inherited Create;
  FKey := AKey;
  FLegacyProc := AProc;
  FLegacyContextProc := nil;
  FRefactorStatus := rsLegacyMixed;
  FDescription := ADescription;
end;

constructor TLegacyWrapBridge.CreateWithContext(const AKey: string;
  AProc: TLegacyContextProc; const ADescription: string);
begin
  inherited Create;
  FKey := AKey;
  FLegacyProc := nil;
  FLegacyContextProc := AProc;
  FRefactorStatus := rsLegacyMixed;
  FDescription := ADescription;
end;

function TLegacyWrapBridge.GetKey: string;
begin
  Result := FKey;
end;

function TLegacyWrapBridge.CanExecute(AContext: TJSONObject): Boolean;
begin
  Result := Assigned(FLegacyProc) or Assigned(FLegacyContextProc);
end;

function TLegacyWrapBridge.Execute(AContext: TJSONObject;
  AMode: TRunMode): TActionResult;
begin
  // DryRun 模式不执行旧代码
  if AMode = rmDryRun then
    Exit(TActionResult.DryRunOK(FKey, 'LegacyWrap DryRun: would call ' + FKey));

  try
    if Assigned(FLegacyContextProc) then
      FLegacyContextProc(AContext)
    else if Assigned(FLegacyProc) then
      FLegacyProc
    else
      Exit(TActionResult.Fail(FKey, 'No legacy procedure assigned'));

    Result := TActionResult.Success(FKey, 'Legacy procedure executed');
  except
    on E: Exception do
      Result := TActionResult.Fail(FKey, 'Legacy error: ' + E.Message);
  end;
end;

end.
