// AI-GENERATED
// DeepBase.Governance.NativeRegistry.pas
// P02：原生入口与适配层 — NativeObject / NativeEvent / NativeRoutine 登记
// 扫描策略：RTTI（本单元）+ DFM 解析（单独单元）+ 运行时钩子（单独单元）

unit DeepBase.Governance.NativeRegistry;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  Vcl.Forms;

type
  /// 原生对象类型
  TNativeObjectKind = (
    nokForm,
    nokFrame,
    nokButton,
    nokMenuItem,
    nokTAction,
    nokEdit,
    nokGrid,
    nokPanel,
    nokTab,
    nokDataModule,
    nokOther
  );

  /// 原生例程类型
  TNativeRoutineKind = (
    nrkEventHandler,
    nrkFormMethod,
    nrkDataModuleMethod,
    nrkServiceMethod,
    nrkPureFunction,
    nrkCompositeLegacy
  );

  /// 重构状态
  TRefactorStatus = (
    rsClean,
    rsLegacyMixed,
    rsToBeSplit,
    rsDeprecated
  );

  /// 原生对象引用
  TNativeObjectRef = class
  private
    FId: string;
    FObjectKind: TNativeObjectKind;
    FUnitName: string;
    FClassName: string;
    FInstanceName: string;
    FScannedAt: TDateTime;
  public
    constructor Create(AKind: TNativeObjectKind; const AUnitName, AClassName,
      AInstanceName: string);
    property Id: string read FId;
    property ObjectKind: TNativeObjectKind read FObjectKind;
    property SourceUnitName: string read FUnitName;
    property ClassName_: string read FClassName;
    property InstanceName: string read FInstanceName;
    property ScannedAt: TDateTime read FScannedAt;
  end;

  /// 原生事件引用
  TNativeEventRef = class
  private
    FObjectId: string;
    FEventName: string;
    FMethodName: string;
    FBound: Boolean;
  public
    constructor Create(const AObjectId, AEventName, AMethodName: string);
    property ObjectId: string read FObjectId;
    property EventName: string read FEventName;
    property HandlerMethodName: string read FMethodName;
    property Bound: Boolean read FBound write FBound;
  end;

  /// 原生例程引用
  TNativeRoutineRef = class
  private
    FId: string;
    FRoutineKind: TNativeRoutineKind;
    FHostUnit: string;
    FHostClass: string;
    FMethodName: string;
    FSignature: string;
    FRefactorStatus: TRefactorStatus;
    FDeclaredSideEffects: string;
  public
    constructor Create(AKind: TNativeRoutineKind;
      const AHostUnit, AHostClass, AMethodName, ASignature: string);
    property Id: string read FId;
    property RoutineKind: TNativeRoutineKind read FRoutineKind;
    property HostUnit: string read FHostUnit;
    property HostClass: string read FHostClass;
    property RoutineMethodName: string read FMethodName;
    property Signature: string read FSignature;
    property RefactorStatus: TRefactorStatus read FRefactorStatus write FRefactorStatus;
    property DeclaredSideEffects: string read FDeclaredSideEffects write FDeclaredSideEffects;
  end;

  /// 原生注册表
  TNativeRegistry = class
  private
    FObjects: TObjectList<TNativeObjectRef>;
    FEvents: TObjectList<TNativeEventRef>;
    FRoutines: TObjectList<TNativeRoutineRef>;
  public
    constructor Create;
    destructor Destroy; override;

    // 手动注册
    procedure RegisterObject(AObj: TNativeObjectRef);
    procedure RegisterEvent(AEvt: TNativeEventRef);
    procedure RegisterRoutine(ARoutine: TNativeRoutineRef);

    // RTTI 扫描（扫描一个 TComponent 及其子组件）
    procedure ScanComponent(AComponent: TComponent; const AUnitName: string = '');

    // 查询
    function GetObjectCount: Integer;
    function GetEventCount: Integer;
    function GetRoutineCount: Integer;
    function FindObjectByName(const AName: string): TNativeObjectRef;
    function FindUnboundEvents: TArray<TNativeEventRef>;
    function GetAllObjects: TArray<TNativeObjectRef>;
    function GetAllEvents: TArray<TNativeEventRef>;
    function GetAllRoutines: TArray<TNativeRoutineRef>;
  end;

implementation

{ TNativeObjectRef }

constructor TNativeObjectRef.Create(AKind: TNativeObjectKind;
  const AUnitName, AClassName, AInstanceName: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FObjectKind := AKind;
  FUnitName := AUnitName;
  FClassName := AClassName;
  FInstanceName := AInstanceName;
  FScannedAt := Now;
end;

{ TNativeEventRef }

constructor TNativeEventRef.Create(const AObjectId, AEventName, AMethodName: string);
begin
  inherited Create;
  FObjectId := AObjectId;
  FEventName := AEventName;
  FMethodName := AMethodName;
  FBound := False;
end;

{ TNativeRoutineRef }

constructor TNativeRoutineRef.Create(AKind: TNativeRoutineKind;
  const AHostUnit, AHostClass, AMethodName, ASignature: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FRoutineKind := AKind;
  FHostUnit := AHostUnit;
  FHostClass := AHostClass;
  FMethodName := AMethodName;
  FSignature := ASignature;
  FRefactorStatus := rsLegacyMixed;
  FDeclaredSideEffects := '';
end;

{ TNativeRegistry }

constructor TNativeRegistry.Create;
begin
  inherited Create;
  FObjects := TObjectList<TNativeObjectRef>.Create(True);
  FEvents := TObjectList<TNativeEventRef>.Create(True);
  FRoutines := TObjectList<TNativeRoutineRef>.Create(True);
end;

destructor TNativeRegistry.Destroy;
begin
  FRoutines.Free;
  FEvents.Free;
  FObjects.Free;
  inherited;
end;

procedure TNativeRegistry.RegisterObject(AObj: TNativeObjectRef);
begin
  FObjects.Add(AObj);
end;

procedure TNativeRegistry.RegisterEvent(AEvt: TNativeEventRef);
begin
  FEvents.Add(AEvt);
end;

procedure TNativeRegistry.RegisterRoutine(ARoutine: TNativeRoutineRef);
begin
  FRoutines.Add(ARoutine);
end;

procedure TNativeRegistry.ScanComponent(AComponent: TComponent;
  const AUnitName: string);
var
  I: Integer;
  LChild: TComponent;
  LObj: TNativeObjectRef;
  LKind: TNativeObjectKind;
  LCtx: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LPropInfo: PPropInfo;
  LEvt: TNativeEventRef;
  LMethod: TMethod;
begin
  if AComponent = nil then Exit;

  // 确定对象类型
  if AComponent.InheritsFrom(TCustomForm) then
    LKind := nokForm
  else if AComponent.InheritsFrom(TCustomFrame) then
    LKind := nokFrame
  else if AComponent.ClassName.Contains('Button') then
    LKind := nokButton
  else if AComponent.ClassName.Contains('MenuItem') then
    LKind := nokMenuItem
  else if AComponent.ClassName.Contains('Action') and
          not AComponent.ClassName.Contains('ActionList') then
    LKind := nokTAction
  else if AComponent.ClassName.Contains('Edit') then
    LKind := nokEdit
  else if AComponent.ClassName.Contains('Grid') then
    LKind := nokGrid
  else if AComponent.ClassName.Contains('Panel') then
    LKind := nokPanel
  else if AComponent.ClassName.Contains('Tab') then
    LKind := nokTab
  else if AComponent.InheritsFrom(TDataModule) then
    LKind := nokDataModule
  else
    LKind := nokOther;

  // 注册对象
  LObj := TNativeObjectRef.Create(LKind, AUnitName,
    AComponent.ClassName, AComponent.Name);
  RegisterObject(LObj);

  // RTTI 扫描事件属性
  LCtx := TRttiContext.Create;
  try
    LType := LCtx.GetType(AComponent.ClassType);
    if LType <> nil then
    begin
      for LProp in LType.GetProperties do
      begin
        if (LProp.PropertyType <> nil) and
           (LProp.PropertyType.TypeKind = tkMethod) and
           LProp.Name.StartsWith('On') then
        begin
          LPropInfo := GetPropInfo(AComponent, LProp.Name);
          if LPropInfo = nil then
            Continue;

          // 检查事件是否已绑定
          LMethod := GetMethodProp(AComponent, LPropInfo);
          if LMethod.Code <> nil then
          begin
            LEvt := TNativeEventRef.Create(LObj.Id, LProp.Name, '(bound)');
            LEvt.Bound := True;
            RegisterEvent(LEvt);
          end
          else
          begin
            LEvt := TNativeEventRef.Create(LObj.Id, LProp.Name, '');
            LEvt.Bound := False;
            RegisterEvent(LEvt);
          end;
        end;
      end;
    end;
  finally
    LCtx.Free;
  end;

  // 递归扫描子组件
  for I := 0 to AComponent.ComponentCount - 1 do
  begin
    LChild := AComponent.Components[I];
    ScanComponent(LChild, AUnitName);
  end;
end;

function TNativeRegistry.GetObjectCount: Integer;
begin
  Result := FObjects.Count;
end;

function TNativeRegistry.GetEventCount: Integer;
begin
  Result := FEvents.Count;
end;

function TNativeRegistry.GetRoutineCount: Integer;
begin
  Result := FRoutines.Count;
end;

function TNativeRegistry.FindObjectByName(const AName: string): TNativeObjectRef;
var
  LObj: TNativeObjectRef;
begin
  for LObj in FObjects do
    if SameText(LObj.InstanceName, AName) then
      Exit(LObj);
  Result := nil;
end;

function TNativeRegistry.FindUnboundEvents: TArray<TNativeEventRef>;
var
  LList: TList<TNativeEventRef>;
  LEvt: TNativeEventRef;
begin
  LList := TList<TNativeEventRef>.Create;
  try
    for LEvt in FEvents do
      if not LEvt.Bound then
        LList.Add(LEvt);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TNativeRegistry.GetAllObjects: TArray<TNativeObjectRef>;
begin
  Result := FObjects.ToArray;
end;

function TNativeRegistry.GetAllEvents: TArray<TNativeEventRef>;
begin
  Result := FEvents.ToArray;
end;

function TNativeRegistry.GetAllRoutines: TArray<TNativeRoutineRef>;
begin
  Result := FRoutines.ToArray;
end;

end.
