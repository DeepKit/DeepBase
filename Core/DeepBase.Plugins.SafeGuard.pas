{ ============================================================================
  DeepBase.Plugins.SafeGuard - 插件调用异常隔离层 + 熔断器

  法源：docs/77.extend.PluginHotReload §2（迁移自 Assayer.PluginSafeGuard）

  职责：
  - 所有跨 DLL 边界调用经 SafeCall* 包裹，DLL 异常在边界处截获，
    宿主进程不因插件崩溃而崩溃；
  - 故障计数 + 熔断：连续崩溃达阈值后自动禁用该插件（降级不再调用），
    需人工 ReEnablePlugin 恢复；
  - 业务类型相关的包装（如 Assayer 的 Route/Pipeline/Auth）由宿主侧
    基于本类的泛型 SafeCall<T> 自行封装，公共层不感知业务类型。
  ============================================================================ }

unit DeepBase.Plugins.SafeGuard;

interface

uses
  System.SysUtils, System.SyncObjs, System.Generics.Collections;

type
  EPluginException = class(Exception)
  private
    FPluginName: string;
    FOriginalClass: string;
  public
    constructor Create(const APluginName, AOriginalClass, AMessage: string);
    property PluginName: string read FPluginName;
    property OriginalClass: string read FOriginalClass;
  end;

  TPluginCrashEvent = procedure(const APluginName: string;
    const AErrorClass, AErrorMessage: string) of object;

  TPluginSafeGuard = class
  private
    FLock: TCriticalSection;
    FCrashCount: TDictionary<string, Integer>;
    FMaxCrashBeforeDisable: Integer;
    FDisabledPlugins: TList<string>;
    FOnCrash: TPluginCrashEvent;
  public
    constructor Create;
    destructor Destroy; override;

    { 子类/宿主自定义包装时使用：记录一次崩溃并触发熔断判断 }
    procedure RecordCrash(const APluginName: string);
    function IsPluginDisabled(const APluginName: string): Boolean;

    { 通用包装：插件已被熔断时返回 ADefault；调用异常时截获、计数并返回 ADefault }
    function SafeCall<T>(const APluginName: string;
      const AAction: TFunc<T>; const ADefault: T): T;

    { 常用具体包装（默认值语义与原 Assayer 版一致） }
    function SafeCallBool(const APluginName: string;
      const AAction: TFunc<Boolean>): Boolean;
    function SafeCallStr(const APluginName: string;
      const AAction: TFunc<string>): string;
    function SafeCallInt(const APluginName: string;
      const AAction: TFunc<Integer>): Integer;

    { 熔断器配置与查询 }
    property MaxCrashBeforeDisable: Integer
      read FMaxCrashBeforeDisable write FMaxCrashBeforeDisable;
    property OnCrash: TPluginCrashEvent read FOnCrash write FOnCrash;

    function GetCrashCount(const APluginName: string): Integer;
    procedure ResetCrashCount(const APluginName: string);
    procedure ReEnablePlugin(const APluginName: string);
    function GetDisabledPlugins: TArray<string>;
    function IsDisabled(const APluginName: string): Boolean;
  end;

implementation

{ EPluginException }

constructor EPluginException.Create(const APluginName, AOriginalClass,
  AMessage: string);
begin
  inherited CreateFmt('[%s] %s: %s', [APluginName, AOriginalClass, AMessage]);
  FPluginName := APluginName;
  FOriginalClass := AOriginalClass;
end;

{ TPluginSafeGuard }

constructor TPluginSafeGuard.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FCrashCount := TDictionary<string, Integer>.Create;
  FDisabledPlugins := TList<string>.Create;
  FMaxCrashBeforeDisable := 5;
end;

destructor TPluginSafeGuard.Destroy;
begin
  FDisabledPlugins.Free;
  FCrashCount.Free;
  FLock.Free;
  inherited;
end;

procedure TPluginSafeGuard.RecordCrash(const APluginName: string);
var
  LCount: Integer;
begin
  FLock.Enter;
  try
    if not FCrashCount.TryGetValue(APluginName, LCount) then
      LCount := 0;
    Inc(LCount);
    FCrashCount.AddOrSetValue(APluginName, LCount);

    { 熔断：连续崩溃达阈值后禁用 }
    if LCount >= FMaxCrashBeforeDisable then
      if not FDisabledPlugins.Contains(APluginName) then
        FDisabledPlugins.Add(APluginName);
  finally
    FLock.Leave;
  end;
end;

function TPluginSafeGuard.IsPluginDisabled(const APluginName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FDisabledPlugins.Contains(APluginName);
  finally
    FLock.Leave;
  end;
end;

function TPluginSafeGuard.SafeCall<T>(const APluginName: string;
  const AAction: TFunc<T>; const ADefault: T): T;
begin
  if IsPluginDisabled(APluginName) then
    Exit(ADefault);

  try
    Result := AAction();
  except
    on E: Exception do
    begin
      RecordCrash(APluginName);
      if Assigned(FOnCrash) then
        FOnCrash(APluginName, E.ClassName, E.Message);
      Result := ADefault;
    end;
  end;
end;

function TPluginSafeGuard.SafeCallBool(const APluginName: string;
  const AAction: TFunc<Boolean>): Boolean;
begin
  Result := SafeCall<Boolean>(APluginName, AAction, False);
end;

function TPluginSafeGuard.SafeCallStr(const APluginName: string;
  const AAction: TFunc<string>): string;
begin
  Result := SafeCall<string>(APluginName, AAction, '');
end;

function TPluginSafeGuard.SafeCallInt(const APluginName: string;
  const AAction: TFunc<Integer>): Integer;
begin
  Result := SafeCall<Integer>(APluginName, AAction, -1);
end;

function TPluginSafeGuard.GetCrashCount(const APluginName: string): Integer;
begin
  FLock.Enter;
  try
    if not FCrashCount.TryGetValue(APluginName, Result) then
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TPluginSafeGuard.ResetCrashCount(const APluginName: string);
begin
  FLock.Enter;
  try
    FCrashCount.AddOrSetValue(APluginName, 0);
    FDisabledPlugins.Remove(APluginName);
  finally
    FLock.Leave;
  end;
end;

procedure TPluginSafeGuard.ReEnablePlugin(const APluginName: string);
begin
  FLock.Enter;
  try
    FDisabledPlugins.Remove(APluginName);
    FCrashCount.AddOrSetValue(APluginName, 0);
  finally
    FLock.Leave;
  end;
end;

function TPluginSafeGuard.GetDisabledPlugins: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FDisabledPlugins.ToArray;
  finally
    FLock.Leave;
  end;
end;

function TPluginSafeGuard.IsDisabled(const APluginName: string): Boolean;
begin
  Result := IsPluginDisabled(APluginName);
end;

end.
