{ ============================================================================
  DeepBase.Plugins.Manager - 泛化插件生命周期管理器（注册制 + Lease 门禁）

  法源：docs/77.extend.PluginHotReload §4/§5
        docs/77a.adr.Plugin-ABI-and-Lifetime §2.2/§2.5/§2.6

  关键纪律：
  1. 注册制：宿主 RegisterPluginKind 声明契约类别（导出函数名前缀），
     RegisterPlugin 声明插件实例（可带 ADependsOn；注册时 DFS 环检测，
     发现环拒绝注册并告警）；
  2. Lease 门禁：宿主业务代码不得直接持有 IPluginContract 引用，
     一律 AcquireLease/ReleaseLease；Lease 持有期间插件计数非零，
     Unload/Reload 等待计数归零，等待上限 300 秒（唯一语义），
     超时标记 psError 并告警人工介入，禁止强制 FreeLibrary；
  3. 热重载期间新调用返回 PLUGIN_RELOADING（§5 第7条）；
  4. 配置加载不感知业务：宿主注入 OnLoadConfigBytes 回调。
  ============================================================================ }

unit DeepBase.Plugins.Manager;

interface

uses
  System.SysUtils, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows,
  DeepBase.Plugins.Contracts, DeepBase.Plugins.SafeGuard,
  DeepBase.Plugins.Verifier;

type
  TPluginLoadEvent = procedure(const APluginName: string;
    ASuccess: Boolean) of object;
  TPluginErrorEvent = procedure(const APluginName: string;
    AErrorCode: Integer; const AMessage: string) of object;
  { 宿主注入的配置加载回调：返回该插件的初始化配置 JSON 字节流 }
  TLoadPluginConfigEvent = function(const APluginName: string;
    out AConfigBytes: TBytes): Boolean of object;

  { 插件注册表项（RegisterPlugin 声明，加载前的静态信息） }
  TPluginKindInfo = record
    Kind: string;             // 契约类别名（宿主 RegisterPluginKind 定义）
    CreateFuncPrefix: string; // 导出函数名前缀，默认 'Create'
  end;

  TPluginInfo = record
    Name: string;
    Kind: string;
    DllPath: string;
    CreateFuncName: string;   // 导出函数名（缺省按 Kind 前缀约定生成）
    DependsOn: TArray<string>;
    State: TPluginState;
    Handle: HMODULE;
    Plugin: IPluginContract;
    Metadata: TPluginMetadata;
    LastLoadedAt: TDateTime;
    LastReloadAt: TDateTime;
    ReloadCount: Integer;
    ActiveLeases: Integer;    // 在途 Lease 计数（Atomic 语义由 FLock 保护）
    LastError: string;
  end;

  { =========================================================================
    TPluginLease - 调用方持有的临时插件引用（门禁中间层）
    用法：
      if Mgr.AcquireLease('Audit', LLease) = PLUGIN_OK then
      try
        LLease.Plugin.GetMetadata(LBytes);   // 单次调用生命周期内使用
      finally
        LLease.Free;   // 归还 Lease（计数减一）
      end;
    ========================================================================= }
  TPluginLease = class
  private
    FManager: TObject;        // 弱引用回指 Manager（由 Manager 负责生命周期序）
    FPluginName: string;
    FPlugin: IPluginContract;
    FReleased: Boolean;
  public
    destructor Destroy; override;
    property PluginName: string read FPluginName;
    property Plugin: IPluginContract read FPlugin;
  end;

  { =========================================================================
    TDeepBasePluginManager
    ========================================================================= }
  TDeepBasePluginManager = class
  private
    FLock: TCriticalSection;
    FPlugins: TDictionary<string, TPluginInfo>;
    FKinds: TDictionary<string, TPluginKindInfo>;
    FPluginDir: string;
    FSafeGuard: TPluginSafeGuard;
    FVerifier: IPluginVerifier;
    FOnLoadConfigBytes: TLoadPluginConfigEvent;
    FOnPluginLoaded: TPluginLoadEvent;
    FOnPluginUnloaded: TPluginLoadEvent;
    FOnPluginError: TPluginErrorEvent;
    FDestroying: Boolean;
    FLeaseDrainTimeoutMs: Integer;

    function ResolveDllPath(const APluginName, AKind: string): string;
    function LoadDll(const ADllPath: string): HMODULE;
    function GetCreateFunc(AHandle: HMODULE;
      const AFuncName: string): TCreatePluginFunc;
    { DFS 拓扑环检测：假设 AName 依赖 ADependsOn，图中是否出现环 }
    function WouldCreateCycle(const AName: string;
      const ADependsOn: TArray<string>): Boolean;
    function DoLoadPlugin(const APluginName: string;
      const AVisited: TList<string>): Integer;
    function DoUnloadPlugin(const APluginName: string): Integer;
    function WaitLeasesDrain(const APluginName: string;
      ATimeoutMs: Integer): Boolean;
    procedure SetPluginError(const AName: string; ACode: Integer;
      const AMessage: string);
    procedure SetPluginState(const AName: string; AState: TPluginState);
    function GetState(const APluginName: string): TPluginState;
    procedure DecLease(const AName: string);
    procedure ReleaseLeaseInternal(const ALease: TPluginLease);
  public
    constructor Create(const APluginDir: string);
    destructor Destroy; override;

    { --- 注册制（77 §4） --- }
    procedure RegisterPluginKind(const AKind, ACreateFuncPrefix: string);
    { ADependsOn 环检测失败时抛 EPluginDependencyError }
    procedure RegisterPlugin(const AName, AKind: string;
      const ADependsOn: TArray<string> = nil;
      const ACreateFuncName: string = '');
    procedure SetPluginDllPath(const AName, ADllPath: string);

    { --- 生命周期（返回错误码，不抛异常） --- }
    function EnsureLoaded(const APluginName: string): Integer;
    function LoadPlugin(const APluginName: string): Integer;
    function UnloadPlugin(const APluginName: string): Integer;
    function ReloadPlugin(const APluginName: string): Integer;
    { 配置热更新（SafeGuard 包裹：坏插件跨边界抛异常在此截获、计数、熔断） }
    function ReloadPluginConfig(const APluginName: string;
      const AConfigBytes: TBytes): Integer;
    procedure UnloadAll;

    { --- Lease 门禁（77a §2.2；300s 唯一语义） --- }
    function AcquireLease(const APluginName: string;
      out ALease: TPluginLease;
      ATimeoutMs: Integer = PLUGIN_LEASE_TIMEOUT_MS): Integer;
    procedure ReleaseLease(const ALease: TPluginLease);

    { --- 查询 --- }
    function IsLoaded(const APluginName: string): Boolean;
    function GetPluginInfo(const APluginName: string): TPluginInfo;
    function ListPlugins: TArray<TPluginInfo>;
    function GetLoadedCount: Integer;
    function IsRegistered(const APluginName: string): Boolean;

    { --- 宿主注入 --- }
    property SafeGuard: TPluginSafeGuard read FSafeGuard;
    property Verifier: IPluginVerifier read FVerifier write FVerifier;
    property PluginDir: string read FPluginDir;
    property OnLoadConfigBytes: TLoadPluginConfigEvent
      read FOnLoadConfigBytes write FOnLoadConfigBytes;
    property OnPluginLoaded: TPluginLoadEvent
      read FOnPluginLoaded write FOnPluginLoaded;
    property OnPluginUnloaded: TPluginLoadEvent
      read FOnPluginUnloaded write FOnPluginUnloaded;
    property OnPluginError: TPluginErrorEvent
      read FOnPluginError write FOnPluginError;
    { Unload/Reload 等待 Lease 释放的超时（默认 300s 唯一语义；
      验收测试可注入短超时，生产代码不得修改此值） }
    property LeaseDrainTimeoutMs: Integer
      read FLeaseDrainTimeoutMs write FLeaseDrainTimeoutMs;
  end;

  EPluginRegistrationError = class(Exception);
  EPluginDependencyError = class(Exception);

implementation

uses
  System.IOUtils;

{ TPluginLease }

destructor TPluginLease.Destroy;
begin
  if not FReleased then
    TDeepBasePluginManager(FManager).ReleaseLeaseInternal(Self);
  FPlugin := nil;
  inherited;
end;

{ TDeepBasePluginManager }

constructor TDeepBasePluginManager.Create(const APluginDir: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FPlugins := TDictionary<string, TPluginInfo>.Create;
  FKinds := TDictionary<string, TPluginKindInfo>.Create;
  FSafeGuard := TPluginSafeGuard.Create;
  FVerifier := PluginVerifier;
  FPluginDir := APluginDir;
  FDestroying := False;
  FLeaseDrainTimeoutMs := PLUGIN_LEASE_TIMEOUT_MS;
  ForceDirectories(FPluginDir);
end;

destructor TDeepBasePluginManager.Destroy;
begin
  FDestroying := True;
  UnloadAll;
  FVerifier := nil;
  FSafeGuard.Free;
  FKinds.Free;
  FPlugins.Free;
  FLock.Free;
  inherited;
end;

{ --- 注册制 --- }

procedure TDeepBasePluginManager.RegisterPluginKind(const AKind,
  ACreateFuncPrefix: string);
var
  LKindInfo: TPluginKindInfo;
begin
  FLock.Enter;
  try
    LKindInfo.Kind := AKind;
    LKindInfo.CreateFuncPrefix := ACreateFuncPrefix;
    FKinds.AddOrSetValue(AKind, LKindInfo);
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.WouldCreateCycle(const AName: string;
  const ADependsOn: TArray<string>): Boolean;
var
  LVisited: TList<string>;
  LDep: string;

  { 从 AStart 出发沿 DependsOn 深度遍历，若到达 AName 即成环 }
  function Reachable(const AStart: string): Boolean;
  var
    LSub: string;
    LCurInfo: TPluginInfo;
  begin
    Result := False;
    if SameText(AStart, AName) then
      Exit(True);
    if LVisited.Contains(AStart) then
      Exit(False);
    LVisited.Add(AStart);
    if FPlugins.TryGetValue(AStart, LCurInfo) then
      for LSub in LCurInfo.DependsOn do
        if Reachable(LSub) then
          Exit(True);
  end;

begin
  Result := False;
  LVisited := TList<string>.Create;
  try
    for LDep in ADependsOn do
    begin
      if SameText(LDep, AName) then
        Exit(True);  // 自依赖即环
      if Reachable(LDep) then
        Exit(True);
    end;
  finally
    LVisited.Free;
  end;
end;

procedure TDeepBasePluginManager.RegisterPlugin(const AName, AKind: string;
  const ADependsOn: TArray<string>; const ACreateFuncName: string);
var
  LInfo: TPluginInfo;
  LKindInfo: TPluginKindInfo;
  LPrefix: string;
begin
  FLock.Enter;
  try
    if FPlugins.ContainsKey(AName) then
      raise EPluginRegistrationError.Create(
        '插件已注册，禁止重复注册：' + AName);

    { DFS 拓扑环检测（77a §2.5）：发现环拒绝注册并告警 }
    if WouldCreateCycle(AName, ADependsOn) then
      raise EPluginDependencyError.Create(
        Format('依赖环检测失败，拒绝注册：%s -> [%s] 存在循环依赖',
          [AName, string.Join(', ', ADependsOn)]));

    if not FKinds.TryGetValue(AKind, LKindInfo) then
      raise EPluginRegistrationError.Create(
        '未注册的插件类别（先 RegisterPluginKind）：' + AKind);

    LPrefix := LKindInfo.CreateFuncPrefix;
    LInfo.Name := AName;
    LInfo.Kind := AKind;
    LInfo.DllPath := ResolveDllPath(AName, AKind);
    LInfo.DependsOn := ADependsOn;
    LInfo.State := psUnloaded;
    LInfo.Handle := 0;
    LInfo.Plugin := nil;
    if ACreateFuncName <> '' then
      LInfo.CreateFuncName := ACreateFuncName
    else
      LInfo.CreateFuncName := LPrefix + AName + 'Plugin';
    LInfo.Metadata := Default(TPluginMetadata);
    LInfo.Metadata.Name := AName;
    LInfo.LastLoadedAt := 0;
    LInfo.LastReloadAt := 0;
    LInfo.ReloadCount := 0;
    LInfo.ActiveLeases := 0;
    LInfo.LastError := '';
    FPlugins.Add(AName, LInfo);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBasePluginManager.SetPluginDllPath(const AName,
  ADllPath: string);
var
  LInfo: TPluginInfo;
begin
  FLock.Enter;
  try
    if FPlugins.TryGetValue(AName, LInfo) then
    begin
      LInfo.DllPath := ADllPath;
      FPlugins.AddOrSetValue(AName, LInfo);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.ResolveDllPath(const APluginName,
  AKind: string): string;
var
  LSubDir: string;
begin
  if SameText(AKind, 'core') then
    LSubDir := 'CorePlugins'
  else if SameText(AKind, 'extended') then
    LSubDir := 'ExtendedPlugins'
  else
    LSubDir := AKind;
  Result := TPath.Combine(FPluginDir,
    TPath.Combine(LSubDir, APluginName + '.dll'));
end;

{ --- 加载 / 卸载 --- }

function TDeepBasePluginManager.LoadDll(const ADllPath: string): HMODULE;
begin
  if not FileExists(ADllPath) then
    raise EFileNotFoundException.Create('Plugin DLL not found: ' + ADllPath);

  { 加载前强制签名校验（77 §7；异常穿透即拒载） }
  FVerifier.VerifyPlugin(ADllPath);

  Result := Winapi.Windows.LoadLibrary(PChar(ADllPath));
  if Result = 0 then
    raise Exception.CreateFmt('LoadLibrary failed for %s (Error: %d)',
      [ADllPath, GetLastError]);
end;

function TDeepBasePluginManager.GetCreateFunc(AHandle: HMODULE;
  const AFuncName: string): TCreatePluginFunc;
var
  LProc: Pointer;
begin
  LProc := Winapi.Windows.GetProcAddress(AHandle, PChar(AFuncName));
  if LProc = nil then
    raise Exception.CreateFmt('Export function "%s" not found in DLL',
      [AFuncName]);
  Result := TCreatePluginFunc(LProc);
end;

procedure TDeepBasePluginManager.SetPluginState(const AName: string;
  AState: TPluginState);
var
  LInfo: TPluginInfo;
begin
  FLock.Enter;
  try
    if FPlugins.TryGetValue(AName, LInfo) then
    begin
      LInfo.State := AState;
      FPlugins.AddOrSetValue(AName, LInfo);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBasePluginManager.SetPluginError(const AName: string;
  ACode: Integer; const AMessage: string);
var
  LInfo: TPluginInfo;
begin
  FLock.Enter;
  try
    if FPlugins.TryGetValue(AName, LInfo) then
    begin
      LInfo.State := psError;
      LInfo.LastError := Format('[%s] %s',
        [PluginErrorCodeToStr(ACode), AMessage]);
      FPlugins.AddOrSetValue(AName, LInfo);
    end;
  finally
    FLock.Leave;
  end;
  if Assigned(FOnPluginError) then
    FOnPluginError(AName, ACode, AMessage);
end;

function TDeepBasePluginManager.GetState(
  const APluginName: string): TPluginState;
var
  LInfo: TPluginInfo;
begin
  FLock.Enter;
  try
    if FPlugins.TryGetValue(APluginName, LInfo) then
      Result := LInfo.State
    else
      Result := psUnloaded;
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.DoLoadPlugin(const APluginName: string;
  const AVisited: TList<string>): Integer;
var
  LInfo: TPluginInfo;
  LHandle: HMODULE;
  LCreateFunc: TCreatePluginFunc;
  LPlugin: IPluginContract;
  LConfigBytes: TBytes;
  LMetaBytes: TBytes;
  LDep: string;
  LDepCode: Integer;
begin
  FLock.Enter;
  try
    if not FPlugins.TryGetValue(APluginName, LInfo) then
      Exit(PLUGIN_INVALID_INPUT);

    if LInfo.State = psLoaded then
      Exit(PLUGIN_OK);
    if LInfo.State = psError then
      Exit(PLUGIN_DEPENDENCY_FAILED);
    if AVisited.Contains(APluginName) then
      Exit(PLUGIN_OK);  // 环在注册期已拦截，此处仅防重入
    AVisited.Add(APluginName);
  finally
    FLock.Leave;
  end;

  { 先递归加载依赖项（77a §2.5） }
  for LDep in LInfo.DependsOn do
  begin
    LDepCode := DoLoadPlugin(LDep, AVisited);
    if LDepCode <> PLUGIN_OK then
    begin
      SetPluginError(APluginName, PLUGIN_DEPENDENCY_FAILED,
        Format('依赖插件 %s 加载失败（%s）',
          [LDep, PluginErrorCodeToStr(LDepCode)]));
      Exit(PLUGIN_DEPENDENCY_FAILED);
    end;
  end;

  SetPluginState(APluginName, psLoading);
  LHandle := 0;
  try
    { Step 1: 签名校验 + LoadLibrary }
    LHandle := LoadDll(LInfo.DllPath);

    { Step 2: 解析导出工厂函数 }
    LCreateFunc := GetCreateFunc(LHandle, LInfo.CreateFuncName);

    { Step 3: 创建实例 }
    LPlugin := LCreateFunc();
    if LPlugin = nil then
      raise Exception.Create('Plugin factory returned nil');

    { Step 4: ABI 协商（77a §2.1：MAJOR 必须相等，MINOR 宿主 >= 插件） }
    if LPlugin.GetAbiMajor <> PLUGIN_ABI_MAJOR then
      raise Exception.CreateFmt('ABI MAJOR 不匹配：host=%d, plugin=%d',
        [PLUGIN_ABI_MAJOR, LPlugin.GetAbiMajor]);
    if PLUGIN_ABI_MINOR < LPlugin.GetAbiMinor then
      raise Exception.CreateFmt('ABI MINOR 不兼容：host=%d < plugin=%d',
        [PLUGIN_ABI_MINOR, LPlugin.GetAbiMinor]);

    { Step 5: Initialize（宿主注入的配置回调，未注入则空配置） }
    LConfigBytes := nil;
    if Assigned(FOnLoadConfigBytes) then
      FOnLoadConfigBytes(APluginName, LConfigBytes);
    Result := LPlugin.Initialize(LConfigBytes);
    if Result <> PLUGIN_OK then
      raise Exception.CreateFmt('Plugin Initialize 返回 %s',
        [PluginErrorCodeToStr(Result)]);

    { Step 6: 元数据快照（JSON 字节流，调用方分配/释放） }
    LMetaBytes := nil;
    LPlugin.GetMetadata(LMetaBytes);

    FLock.Enter;
    try
      LInfo.State := psLoaded;
      LInfo.Handle := LHandle;
      LInfo.Plugin := LPlugin;
      LInfo.LastLoadedAt := Now;
      LInfo.LastError := '';
      JsonBytesToMetadata(LMetaBytes, LInfo.Metadata);
      LInfo.Metadata.Name := APluginName;
      FPlugins.AddOrSetValue(APluginName, LInfo);
    finally
      FLock.Leave;
    end;

    LHandle := 0;  // 所有权已转移给注册表
    if Assigned(FOnPluginLoaded) then
      FOnPluginLoaded(APluginName, True);

  except
    on E: Exception do
    begin
      { Release any factory-created interface before unloading its code. }
      LPlugin := nil;
      if LHandle <> 0 then
        FreeLibrary(LHandle);
      SetPluginError(APluginName, PLUGIN_LOAD_FAILED, E.Message);
      if Assigned(FOnPluginLoaded) then
        FOnPluginLoaded(APluginName, False);
      Result := PLUGIN_LOAD_FAILED;
    end;
  end;
end;

function TDeepBasePluginManager.WaitLeasesDrain(const APluginName: string;
  ATimeoutMs: Integer): Boolean;
var
  LDeadline: TDateTime;
  LInfo: TPluginInfo;
begin
  { 77a §2.2 唯一语义：等待上限 = ATimeoutMs（默认 300 秒）；
    超时由调用方标记 psError 并告警人工介入，禁止强制 FreeLibrary }
  LDeadline := Now + ATimeoutMs / MSecsPerDay;
  repeat
    FLock.Enter;
    try
      if FPlugins.TryGetValue(APluginName, LInfo) then
      begin
        if LInfo.ActiveLeases <= 0 then
          Exit(True);
      end
      else
        Exit(True);
    finally
      FLock.Leave;
    end;
    if Now >= LDeadline then
      Exit(False);
    Sleep(50);
  until False;
end;

function TDeepBasePluginManager.DoUnloadPlugin(
  const APluginName: string): Integer;
var
  LInfo: TPluginInfo;
  LHandle: HMODULE;
begin
  Result := PLUGIN_OK;

  FLock.Enter;
  try
    if not FPlugins.TryGetValue(APluginName, LInfo) then
      Exit(PLUGIN_INVALID_INPUT);
    if LInfo.State = psUnloaded then
      Exit(PLUGIN_OK);
    { psError may be the recoverable lease-drain timeout state: the DLL and
      interface remain loaded, and a later unload is allowed after leases return. }
    if (LInfo.State = psError) and ((LInfo.Handle = 0) or (LInfo.Plugin = nil)) then
      Exit(PLUGIN_LOAD_FAILED);
  finally
    FLock.Leave;
  end;

  SetPluginState(APluginName, psUnloading);
  LHandle := LInfo.Handle;

  { Shutdown 异常不得中断卸载。这里不能用捕获 LInfo 的匿名函数：
    匿名方法闭包会额外持有插件接口，直到过程退出；若此前 FreeLibrary，
    闭包清理时会调用已卸载 DLL 中的 _Release，导致 AV。 }
  try
    LInfo.Plugin.Shutdown;
  except
    FSafeGuard.RecordCrash(APluginName);
  end;

  { 等待所有 Lease 释放（300s 唯一语义；禁止强制 FreeLibrary；
    FLeaseDrainTimeoutMs 仅供验收测试注入短超时，生产保持 300000） }
  if not WaitLeasesDrain(APluginName, FLeaseDrainTimeoutMs) then
  begin
    SetPluginError(APluginName, PLUGIN_LEASE_TIMEOUT,
      'Unload 等待 Lease 释放超时（300 秒），DLL 保持加载，需人工介入；' +
      '禁止强制 FreeLibrary（引用非零强制卸载必崩）');
    Exit(PLUGIN_LEASE_TIMEOUT);
  end;

  { 释放接口引用（最后一个引用归零后才允许 FreeLibrary） }
  FLock.Enter;
  try
    if FPlugins.TryGetValue(APluginName, LInfo) then
    begin
      LInfo.Handle := 0;  { 先从注册表摘除句柄，避免后续记录拷贝重复持有 }
      LInfo.Plugin := nil;
      FPlugins.AddOrSetValue(APluginName, LInfo);
    end;
  finally
    FLock.Leave;
  end;
  { Delphi record 内含接口字段；AddOrSetValue 后本地 LInfo 仍保留一份引用。
    必须先保存句柄、清接口，再 FreeLibrary，禁止使用被清零后的 LInfo.Handle。 }
  LInfo.Plugin := nil;
  Finalize(LInfo);  { clear all managed record fields before unloading DLL code }
  LInfo := Default(TPluginInfo);

  if LHandle <> 0 then
  begin
    FreeLibrary(LHandle);
  end;

  FLock.Enter;
  try
    if FPlugins.TryGetValue(APluginName, LInfo) then
    begin
      LInfo.State := psUnloaded;
      LInfo.Handle := 0;
      LInfo.Plugin := nil;
      FPlugins.AddOrSetValue(APluginName, LInfo);
    end;
  finally
    FLock.Leave;
  end;

  if Assigned(FOnPluginUnloaded) then
    FOnPluginUnloaded(APluginName, True);
end;

function TDeepBasePluginManager.LoadPlugin(const APluginName: string): Integer;
var
  LVisited: TList<string>;
begin
  LVisited := TList<string>.Create;
  try
    Result := DoLoadPlugin(APluginName, LVisited);
  finally
    LVisited.Free;
  end;
end;

function TDeepBasePluginManager.EnsureLoaded(const APluginName: string): Integer;
begin
  case GetState(APluginName) of
    psLoaded:  Exit(PLUGIN_OK);
    psReloading: Exit(PLUGIN_RELOADING);
    psError:   Exit(PLUGIN_LOAD_FAILED);
  end;
  Result := LoadPlugin(APluginName);  // 懒加载（ASY-DLL-004）
end;

function TDeepBasePluginManager.UnloadPlugin(const APluginName: string): Integer;
begin
  Result := DoUnloadPlugin(APluginName);
end;

function TDeepBasePluginManager.ReloadPlugin(const APluginName: string): Integer;
var
  LInfo: TPluginInfo;
  LVisited: TList<string>;
begin
  Result := PLUGIN_INTERNAL_ERROR;

  FLock.Enter;
  try
    if not FPlugins.TryGetValue(APluginName, LInfo) then
      Exit(PLUGIN_INVALID_INPUT);
    if not LInfo.Metadata.SupportsHotReload then
      Exit(PLUGIN_BUSY);
  finally
    FLock.Leave;
  end;

  { 热重载窗口期：新调用返回 PLUGIN_RELOADING（77 §5 第7条） }
  SetPluginState(APluginName, psReloading);
  try
    try
      Result := DoUnloadPlugin(APluginName);
      if Result <> PLUGIN_OK then
        Exit;

      LVisited := TList<string>.Create;
      try
        Result := DoLoadPlugin(APluginName, LVisited);
      finally
        LVisited.Free;
      end;
    except
      on Exception do
        Result := PLUGIN_INTERNAL_ERROR;
    end;
  finally
    if Result <> PLUGIN_OK then
      if GetState(APluginName) = psReloading then
        SetPluginError(APluginName, Result, 'Reload 失败，已回退为错误态');
  end;

  if Result = PLUGIN_OK then
  begin
    FLock.Enter;
    try
      if FPlugins.TryGetValue(APluginName, LInfo) then
      begin
        LInfo.LastReloadAt := Now;
        Inc(LInfo.ReloadCount);
        FPlugins.AddOrSetValue(APluginName, LInfo);
      end;
    finally
      FLock.Leave;
    end;
  end;
end;

function TDeepBasePluginManager.ReloadPluginConfig(const APluginName: string;
  const AConfigBytes: TBytes): Integer;
var
  LLease: TPluginLease;
  LCode: Integer;
begin
  { 走 Lease 门禁拿引用，SafeGuard 截获坏插件异常（77a §2.6 宿主调用边界） }
  LCode := AcquireLease(APluginName, LLease);
  if LCode <> PLUGIN_OK then
    Exit(LCode);
  try
    Result := FSafeGuard.SafeCallInt(APluginName,
      function: Integer
      begin
        Result := LLease.Plugin.ReloadConfig(AConfigBytes);
      end);
  finally
    LLease.Free;
  end;
end;

procedure TDeepBasePluginManager.UnloadAll;
var
  LNames: TArray<string>;
  LName: string;
begin
  FLock.Enter;
  try
    LNames := FPlugins.Keys.ToArray;
  finally
    FLock.Leave;
  end;

  for LName in LNames do
    DoUnloadPlugin(LName);
end;

{ --- Lease 门禁 --- }

procedure TDeepBasePluginManager.DecLease(const AName: string);
var
  LInfo: TPluginInfo;
begin
  FLock.Enter;
  try
    if FPlugins.TryGetValue(AName, LInfo) then
    begin
      if LInfo.ActiveLeases > 0 then
        Dec(LInfo.ActiveLeases);
      FPlugins.AddOrSetValue(AName, LInfo);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.AcquireLease(const APluginName: string;
  out ALease: TPluginLease; ATimeoutMs: Integer): Integer;
var
  LDeadline: TDateTime;
  LState: TPluginState;
  LInfo: TPluginInfo;
begin
  ALease := nil;

  { 熔断中的插件直接 BUSY }
  if FSafeGuard.IsDisabled(APluginName) then
    Exit(PLUGIN_BUSY);

  LDeadline := Now + ATimeoutMs / MSecsPerDay;
  repeat
    Result := EnsureLoaded(APluginName);
    if (Result <> PLUGIN_OK) and (Result <> PLUGIN_RELOADING) and
       (Result <> PLUGIN_BUSY) then
      Exit;  // 硬错误直接返回

    LState := GetState(APluginName);
    if LState = psLoaded then
    begin
      FLock.Enter;
      try
        if FPlugins.TryGetValue(APluginName, LInfo) and
           (LInfo.State = psLoaded) and (LInfo.Plugin <> nil) then
        begin
          ALease := TPluginLease.Create;
          ALease.FManager := Self;
          ALease.FPluginName := APluginName;
          ALease.FPlugin := LInfo.Plugin;
          ALease.FReleased := False;
          Inc(LInfo.ActiveLeases);
          FPlugins.AddOrSetValue(APluginName, LInfo);
          Exit(PLUGIN_OK);
        end;
      finally
        FLock.Leave;
      end;
    end;

    if Now >= LDeadline then
    begin
      { 300s 唯一语义：超时 psError + 告警人工介入（77a §2.2） }
      SetPluginError(APluginName, PLUGIN_LEASE_TIMEOUT,
        Format('AcquireLease 等待超时（%d ms，插件当前状态 %s），需人工介入',
          [ATimeoutMs, PluginStateToStr(LState)]));
      Exit(PLUGIN_LEASE_TIMEOUT);
    end;
    Sleep(20);
  until False;
end;

procedure TDeepBasePluginManager.ReleaseLeaseInternal(
  const ALease: TPluginLease);
begin
  if (ALease = nil) or FDestroying then
    Exit;
  DecLease(ALease.FPluginName);
  ALease.FReleased := True;
end;

procedure TDeepBasePluginManager.ReleaseLease(const ALease: TPluginLease);
begin
  ReleaseLeaseInternal(ALease);
end;

{ --- 查询 --- }

function TDeepBasePluginManager.IsLoaded(const APluginName: string): Boolean;
begin
  Result := GetState(APluginName) = psLoaded;
end;

function TDeepBasePluginManager.IsRegistered(const APluginName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FPlugins.ContainsKey(APluginName);
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.GetPluginInfo(
  const APluginName: string): TPluginInfo;
begin
  FLock.Enter;
  try
    if not FPlugins.TryGetValue(APluginName, Result) then
    begin
      Result := Default(TPluginInfo);
      Result.Name := APluginName;
      Result.State := psUnloaded;
    end
    else
      Result.Plugin := nil;  { introspection snapshots must not leak DLL interface refs }
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.ListPlugins: TArray<TPluginInfo>;
var
  LPair: TPair<string, TPluginInfo>;
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FPlugins.Count);
    I := 0;
    for LPair in FPlugins do
    begin
      Result[I] := LPair.Value;
      Result[I].Plugin := nil;  { snapshot only; do not extend plugin lifetime }
      Inc(I);
    end;
  finally
    FLock.Leave;
  end;
end;

function TDeepBasePluginManager.GetLoadedCount: Integer;
var
  LPair: TPair<string, TPluginInfo>;
begin
  Result := 0;
  FLock.Enter;
  try
    for LPair in FPlugins do
      if LPair.Value.State = psLoaded then
        Inc(Result);
  finally
    FLock.Leave;
  end;
end;

end.
