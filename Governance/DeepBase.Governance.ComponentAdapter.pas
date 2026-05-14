// AI-GENERATED
// DeepBase.Governance.ComponentAdapter.pas
// P02：组件适配层 — DFM 解析 + 运行时钩子 + 三源合并
// 扫描策略：RTTI（NativeRegistry）+ DFM 解析（本单元）+ 运行时钩子（本单元）

unit DeepBase.Governance.ComponentAdapter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  DeepBase.Governance.NativeRegistry;

type
  /// DFM 解析出的控件信息
  TDfmComponentInfo = record
    ClassName: string;
    Name: string;
    ParentName: string;
    Properties: TArray<TPair<string, string>>;
    Events: TArray<TPair<string, string>>;  // EventName → HandlerName
  end;

  /// DFM 解析器 — 从 .dfm 文本中提取控件树
  TDfmParser = class
  private
    FLines: TArray<string>;
    FIndex: Integer;
    FComponents: TList<TDfmComponentInfo>;
    procedure ParseObject(const AParentName: string);
    function PeekLine: string;
    function ReadLine: string;
    function IsEOF: Boolean;
    function TrimDfmLine(const ALine: string): string;
    class function IsEventProperty(const APropName: string): Boolean; static;
    class function ClassNameToKind(const AClassName: string): TNativeObjectKind; static;
  public
    constructor Create;
    destructor Destroy; override;

    /// 解析 DFM 文本内容
    procedure Parse(const ADfmContent: string);

    /// 解析 DFM 文件
    procedure ParseFile(const AFilePath: string);

    /// 获取解析结果
    function GetComponents: TArray<TDfmComponentInfo>;
    function GetComponentCount: Integer;

    /// 清空解析结果
    procedure Clear;
  end;

  /// 运行时事件钩子 — 捕获未登记的事件触发
  TRuntimeHookEntry = record
    ObjectName: string;
    EventName: string;
    Timestamp: TDateTime;
    Handled: Boolean;
  end;

  TOnUnregisteredEvent = reference to procedure(const AEntry: TRuntimeHookEntry);

  TRuntimeEventHook = class
  private
    FCapturedEvents: TList<TRuntimeHookEntry>;
    FOnUnregistered: TOnUnregisteredEvent;
    FActive: Boolean;
    FMaxCapture: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// 记录一个事件触发（由 ApplicationEvents 或手动调用）
    procedure CaptureEvent(const AObjectName, AEventName: string);

    /// 获取所有捕获的事件
    function GetCapturedEvents: TArray<TRuntimeHookEntry>;
    function GetCapturedCount: Integer;

    /// 清空捕获记录
    procedure ClearCaptures;

    /// 标记某事件为已处理
    procedure MarkHandled(AIndex: Integer);

    property Active: Boolean read FActive write FActive;
    property MaxCapture: Integer read FMaxCapture write FMaxCapture;
    property OnUnregisteredEvent: TOnUnregisteredEvent read FOnUnregistered write FOnUnregistered;
  end;

  /// 组件适配器 — 三源合并（RTTI + DFM + Runtime）到 NativeRegistry
  TComponentAdapter = class
  private
    FRegistry: TNativeRegistry;
    FDfmParser: TDfmParser;
    FRuntimeHook: TRuntimeEventHook;
    FMergedObjectNames: TList<string>;  // 去重用
    procedure RememberRegistryObjects;
    function RememberObjectName(const AName: string): Boolean;
    function EventRegistered(const AObjectId, AEventName: string): Boolean;
  public
    constructor Create(ARegistry: TNativeRegistry);
    destructor Destroy; override;

    /// 从 DFM 文件扫描并注册到 Registry
    procedure ScanDfmFile(const AFilePath: string; const AUnitName: string = '');

    /// 从 DFM 文本扫描并注册到 Registry
    procedure ScanDfmContent(const ADfmContent: string; const AUnitName: string = '');

    /// 从运行时钩子捕获的事件注册到 Registry
    procedure MergeRuntimeCaptures;

    /// 三源合并去重：RTTI 已扫描 + DFM 已扫描 + Runtime 已捕获
    function GetMergedObjectCount: Integer;

    /// 获取 DFM 解析器（供外部直接使用）
    property DfmParser: TDfmParser read FDfmParser;

    /// 获取运行时钩子（供外部直接使用）
    property RuntimeHook: TRuntimeEventHook read FRuntimeHook;
  end;

implementation

{ TDfmParser }

constructor TDfmParser.Create;
begin
  inherited Create;
  FComponents := TList<TDfmComponentInfo>.Create;
  FIndex := 0;
end;

destructor TDfmParser.Destroy;
begin
  FComponents.Free;
  inherited;
end;

procedure TDfmParser.Clear;
begin
  FComponents.Clear;
  FIndex := 0;
  FLines := nil;
end;

procedure TDfmParser.Parse(const ADfmContent: string);
begin
  Clear;
  FLines := ADfmContent.Split([#13#10, #10, #13]);
  FIndex := 0;

  while not IsEOF do
  begin
    if TrimDfmLine(PeekLine).StartsWith('object ') or
       TrimDfmLine(PeekLine).StartsWith('inherited ') or
       TrimDfmLine(PeekLine).StartsWith('inline ') then
      ParseObject('')
    else
      ReadLine;  // skip non-object lines
  end;
end;

procedure TDfmParser.ParseFile(const AFilePath: string);
var
  LContent: string;
begin
  if not TFile.Exists(AFilePath) then
    raise EFileNotFoundException.Create('DFM file not found: ' + AFilePath);
  LContent := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
  Parse(LContent);
end;

procedure TDfmParser.ParseObject(const AParentName: string);
var
  LLine, LTrimmed: string;
  LInfo: TDfmComponentInfo;
  LProps: TList<TPair<string, string>>;
  LEvents: TList<TPair<string, string>>;
  LPropName, LPropValue: string;
  LColonPos: Integer;
begin
  LLine := ReadLine;
  LTrimmed := TrimDfmLine(LLine);

  // Parse "object Name: ClassName" or "inherited Name: ClassName"
  // Remove leading keyword
  if LTrimmed.StartsWith('object ') then
    LTrimmed := LTrimmed.Substring(7)
  else if LTrimmed.StartsWith('inherited ') then
    LTrimmed := LTrimmed.Substring(10)
  else if LTrimmed.StartsWith('inline ') then
    LTrimmed := LTrimmed.Substring(7);

  LColonPos := LTrimmed.IndexOf(':');
  if LColonPos > 0 then
  begin
    LInfo.Name := Trim(LTrimmed.Substring(0, LColonPos));
    LInfo.ClassName := Trim(LTrimmed.Substring(LColonPos + 1));
  end
  else
  begin
    // Unnamed object (root form sometimes)
    LInfo.Name := '';
    LInfo.ClassName := Trim(LTrimmed);
  end;

  LInfo.ParentName := AParentName;

  LProps := TList<TPair<string, string>>.Create;
  LEvents := TList<TPair<string, string>>.Create;
  try
    // Parse properties until 'end' or nested object
    while not IsEOF do
    begin
      LTrimmed := TrimDfmLine(PeekLine);

      if LTrimmed = 'end' then
      begin
        ReadLine;  // consume 'end'
        Break;
      end;

      if LTrimmed.StartsWith('object ') or
         LTrimmed.StartsWith('inherited ') or
         LTrimmed.StartsWith('inline ') then
      begin
        // Nested object
        ParseObject(LInfo.Name);
        Continue;
      end;

      // Property line: "PropName = Value"
      LLine := ReadLine;
      LTrimmed := TrimDfmLine(LLine);
      LColonPos := LTrimmed.IndexOf(' = ');
      if LColonPos > 0 then
      begin
        LPropName := Trim(LTrimmed.Substring(0, LColonPos));
        LPropValue := Trim(LTrimmed.Substring(LColonPos + 3));

        if IsEventProperty(LPropName) then
          LEvents.Add(TPair<string, string>.Create(LPropName, LPropValue))
        else
          LProps.Add(TPair<string, string>.Create(LPropName, LPropValue));
      end;
      // else: multi-line value or other, skip
    end;

    LInfo.Properties := LProps.ToArray;
    LInfo.Events := LEvents.ToArray;
  finally
    LEvents.Free;
    LProps.Free;
  end;

  FComponents.Add(LInfo);
end;

function TDfmParser.PeekLine: string;
begin
  if FIndex < Length(FLines) then
    Result := FLines[FIndex]
  else
    Result := '';
end;

function TDfmParser.ReadLine: string;
begin
  if FIndex < Length(FLines) then
  begin
    Result := FLines[FIndex];
    Inc(FIndex);
  end
  else
    Result := '';
end;

function TDfmParser.IsEOF: Boolean;
begin
  Result := FIndex >= Length(FLines);
end;

function TDfmParser.TrimDfmLine(const ALine: string): string;
begin
  Result := Trim(ALine);
end;

class function TDfmParser.IsEventProperty(const APropName: string): Boolean;
begin
  Result := APropName.StartsWith('On');
end;

class function TDfmParser.ClassNameToKind(const AClassName: string): TNativeObjectKind;
begin
  if AClassName.Contains('Form') then
    Result := nokForm
  else if AClassName.Contains('Frame') then
    Result := nokFrame
  else if AClassName.Contains('Button') then
    Result := nokButton
  else if AClassName.Contains('MenuItem') then
    Result := nokMenuItem
  else if AClassName.Contains('Action') and not AClassName.Contains('ActionList') then
    Result := nokTAction
  else if AClassName.Contains('Edit') then
    Result := nokEdit
  else if AClassName.Contains('Grid') then
    Result := nokGrid
  else if AClassName.Contains('Panel') then
    Result := nokPanel
  else if AClassName.Contains('Tab') then
    Result := nokTab
  else if AClassName.Contains('DataModule') then
    Result := nokDataModule
  else
    Result := nokOther;
end;

function TDfmParser.GetComponents: TArray<TDfmComponentInfo>;
begin
  Result := FComponents.ToArray;
end;

function TDfmParser.GetComponentCount: Integer;
begin
  Result := FComponents.Count;
end;

{ TRuntimeEventHook }

constructor TRuntimeEventHook.Create;
begin
  inherited Create;
  FCapturedEvents := TList<TRuntimeHookEntry>.Create;
  FActive := True;
  FMaxCapture := 1000;
end;

destructor TRuntimeEventHook.Destroy;
begin
  FCapturedEvents.Free;
  inherited;
end;

procedure TRuntimeEventHook.CaptureEvent(const AObjectName, AEventName: string);
var
  LEntry: TRuntimeHookEntry;
begin
  if not FActive then Exit;
  if FCapturedEvents.Count >= FMaxCapture then Exit;

  LEntry.ObjectName := AObjectName;
  LEntry.EventName := AEventName;
  LEntry.Timestamp := Now;
  LEntry.Handled := False;
  FCapturedEvents.Add(LEntry);

  if Assigned(FOnUnregistered) then
    FOnUnregistered(LEntry);
end;

function TRuntimeEventHook.GetCapturedEvents: TArray<TRuntimeHookEntry>;
begin
  Result := FCapturedEvents.ToArray;
end;

function TRuntimeEventHook.GetCapturedCount: Integer;
begin
  Result := FCapturedEvents.Count;
end;

procedure TRuntimeEventHook.ClearCaptures;
begin
  FCapturedEvents.Clear;
end;

procedure TRuntimeEventHook.MarkHandled(AIndex: Integer);
var
  LEntry: TRuntimeHookEntry;
begin
  if (AIndex >= 0) and (AIndex < FCapturedEvents.Count) then
  begin
    LEntry := FCapturedEvents[AIndex];
    LEntry.Handled := True;
    FCapturedEvents[AIndex] := LEntry;
  end;
end;

{ TComponentAdapter }

constructor TComponentAdapter.Create(ARegistry: TNativeRegistry);
begin
  inherited Create;
  FRegistry := ARegistry;
  FDfmParser := TDfmParser.Create;
  FRuntimeHook := TRuntimeEventHook.Create;
  FMergedObjectNames := TList<string>.Create;
end;

destructor TComponentAdapter.Destroy;
begin
  FMergedObjectNames.Free;
  FRuntimeHook.Free;
  FDfmParser.Free;
  inherited;
end;

procedure TComponentAdapter.RememberRegistryObjects;
var
  LObjects: TArray<TNativeObjectRef>;
  LObj: TNativeObjectRef;
begin
  if FRegistry = nil then
    Exit;

  LObjects := FRegistry.GetAllObjects;
  for LObj in LObjects do
    RememberObjectName(LObj.InstanceName);
end;

function TComponentAdapter.RememberObjectName(const AName: string): Boolean;
var
  LKey: string;
begin
  LKey := AName.ToLower;
  Result := (LKey <> '') and not FMergedObjectNames.Contains(LKey);
  if Result then
    FMergedObjectNames.Add(LKey);
end;

function TComponentAdapter.EventRegistered(const AObjectId,
  AEventName: string): Boolean;
var
  LEvents: TArray<TNativeEventRef>;
  LEvt: TNativeEventRef;
begin
  Result := False;
  if FRegistry = nil then
    Exit;

  LEvents := FRegistry.GetAllEvents;
  for LEvt in LEvents do
    if (LEvt.ObjectId = AObjectId) and SameText(LEvt.EventName, AEventName) then
      Exit(True);
end;

procedure TComponentAdapter.ScanDfmFile(const AFilePath: string;
  const AUnitName: string);
begin
  FDfmParser.ParseFile(AFilePath);
  ScanDfmContent('', AUnitName);  // Components already parsed
end;

procedure TComponentAdapter.ScanDfmContent(const ADfmContent: string;
  const AUnitName: string);
var
  LComponents: TArray<TDfmComponentInfo>;
  LComp: TDfmComponentInfo;
  LObj: TNativeObjectRef;
  LEvt: TNativeEventRef;
  LEvtPair: TPair<string, string>;
  LKind: TNativeObjectKind;
begin
  if ADfmContent <> '' then
    FDfmParser.Parse(ADfmContent);

  RememberRegistryObjects;
  LComponents := FDfmParser.GetComponents;

  for LComp in LComponents do
  begin
    // 去重：如果 RTTI 已经扫描过同名对象，跳过
    if not RememberObjectName(LComp.Name) then
      Continue;

    LKind := TDfmParser.ClassNameToKind(LComp.ClassName);
    LObj := TNativeObjectRef.Create(LKind, AUnitName, LComp.ClassName, LComp.Name);
    FRegistry.RegisterObject(LObj);

    // 注册事件
    for LEvtPair in LComp.Events do
    begin
      LEvt := TNativeEventRef.Create(LObj.Id, LEvtPair.Key, LEvtPair.Value);
      LEvt.Bound := LEvtPair.Value <> '';
      FRegistry.RegisterEvent(LEvt);
    end;
  end;
end;

procedure TComponentAdapter.MergeRuntimeCaptures;
var
  LCaptures: TArray<TRuntimeHookEntry>;
  LCapture: TRuntimeHookEntry;
  I: Integer;
  LObj: TNativeObjectRef;
  LEvt: TNativeEventRef;
begin
  RememberRegistryObjects;
  LCaptures := FRuntimeHook.GetCapturedEvents;

  for I := 0 to Length(LCaptures) - 1 do
  begin
    LCapture := LCaptures[I];
    if LCapture.Handled then Continue;

    // 检查对象是否已在 Registry 中
    LObj := FRegistry.FindObjectByName(LCapture.ObjectName);
    if LObj = nil then
    begin
      // 新发现的对象（运行时才出现）
      LObj := TNativeObjectRef.Create(nokOther, '', 'TUnknown', LCapture.ObjectName);
      FRegistry.RegisterObject(LObj);
      RememberObjectName(LCapture.ObjectName);
    end;

    // 注册事件
    if not EventRegistered(LObj.Id, LCapture.EventName) then
    begin
      LEvt := TNativeEventRef.Create(LObj.Id, LCapture.EventName, '(runtime)');
      LEvt.Bound := True;
      FRegistry.RegisterEvent(LEvt);
    end;
    FRuntimeHook.MarkHandled(I);
  end;
end;

function TComponentAdapter.GetMergedObjectCount: Integer;
begin
  Result := FMergedObjectNames.Count;
end;

end.
