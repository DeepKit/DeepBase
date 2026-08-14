{ ============================================================================
  DeepBase.Plugins.Contracts - DLL 插件公共契约（字节缓冲区协议版）

  法源：docs/77.extend.PluginHotReload §3/§5/§6
        docs/77a.adr.Plugin-ABI-and-Lifetime §2.1/§2.3/§2.4

  ABI 纪律（77a §2.1）：
  - 宿主与插件 DLL 必须编译本单元同一份源码；
  - PLUGIN_ABI_MAJOR 必须完全相等，PLUGIN_ABI_MINOR 宿主 >= 插件；
  - IPluginContract GUID 一经发布禁止改动；契约扩展只能接口继承新增。

  跨边界内存纪律（77a §2.3）：
  - 跨 DLL 边界禁止传递 Delphi 对象引用（TJSONObject/TJSONArray 等）；
  - TBytes 参数一律 var：调用方分配、被调方只写、释放权始终归调用方；
  - 宿主与插件必须链接同一共享内存管理器（BorlndMM/ShareMem）；
  - 跨边界不抛异常：DLL 内捕获，转错误码 + GetLastError 文本返回。
  ============================================================================ }

unit DeepBase.Plugins.Contracts;

interface

uses
  System.SysUtils;

const
  { ABI 版本模型（77a §2.1；本 ADR 冻结 MAJOR=1） }
  PLUGIN_ABI_MAJOR = 1;
  PLUGIN_ABI_MINOR = 0;

  { 错误码规范（77a §2.4；跨边界返回的唯一通道） }
  PLUGIN_OK                 = 0;   // 成功
  PLUGIN_LOAD_FAILED        = -1;  // 加载失败（含签名/ABI 校验失败）
  PLUGIN_RELOADING          = -2;  // 插件正在热重载，新调用请求降级处理
  PLUGIN_BUSY               = -3;  // 调用超时/熔断中
  PLUGIN_INVALID_INPUT      = -4;  // 入参校验失败
  PLUGIN_INTERNAL_ERROR     = -5;  // 插件内部异常（DLL 内已捕获）
  PLUGIN_DEPENDENCY_FAILED  = -6;  // 依赖插件加载失败
  PLUGIN_LEASE_TIMEOUT      = -7;  // Lease 获取超时

  { Lease 等待硬超时（77a §2.2 唯一语义：300 秒；超时 psError+告警人工介入，
    禁止强制 FreeLibrary） }
  PLUGIN_LEASE_TIMEOUT_MS   = 300000;

type
  TPluginType = (ptCore, ptExtended, ptExperimental);

  TPluginState = (
    psUnloaded,       // 未加载
    psLoading,        // 加载中
    psLoaded,         // 已加载且 Initialize 成功
    psReloading,      // 热重载窗口期（新调用返回 PLUGIN_RELOADING）
    psPendingRestart, // 配置变更、不支持热重载，等宿主重启（新调用返回 PLUGIN_RELOADING）
    psError,          // 加载/初始化/Lease 超时失败（人工介入）
    psUnloading       // 卸载中
  );

  TPluginMetadata = record
    Name: string;
    Version: string;
    PluginType: TPluginType;
    Description: string;
    Author: string;
    AbiMajor: Integer;
    AbiMinor: Integer;
    SupportsHotReload: Boolean;
    DependsOn: TArray<string>;
    Capabilities: TArray<string>;  // 声明能力，如 ['has_invoke']（F3: 能力门禁）
  end;

  TPluginHealthStatus = record
    IsHealthy: Boolean;
    LastCheckTime: TDateTime;
    ErrorMessage: string;
    UptimeSeconds: Int64;
    RequestCount: Int64;
    ErrorCount: Int64;
  end;

  { =========================================================================
    IPluginContract - 所有 DLL 插件必须实现的基接口
    注意：方法布局即 ABI，禁止修改签名；扩展请继承新接口（新 GUID）。
    ========================================================================= }
  IPluginContract = interface
    ['{8F2A6C1D-4B7E-4E9A-B3C5-D61A07E2F488}']

    { --- 生命周期（返回错误码，见上方常量表） --- }
    function Initialize(const AConfigBytes: TBytes): Integer; stdcall;
    function Shutdown: Integer; stdcall;
    function ReloadConfig(const AConfigBytes: TBytes): Integer; stdcall;

    { --- ABI 协商（宿主加载时校验） --- }
    function GetAbiMajor: Integer; stdcall;
    function GetAbiMinor: Integer; stdcall;

    { --- 元数据/健康：JSON 字节流（被调方写入，释放权归调用方） --- }
    function GetMetadata(var AMetaJsonBytes: TBytes): Integer; stdcall;
    function GetHealthStatus(var AHealthJsonBytes: TBytes): Integer; stdcall;
    function IsHealthy: Boolean; stdcall;

    { --- 最近一次错误码对应文本（宿主告警用；空表示无错误） --- }
    function GetLastError(var AMsgBytes: TBytes): Integer; stdcall;
  end;

  { DLL 导出函数类型：每个插件 DLL 导出一个此签名函数（stdcall），
    函数名由宿主 Manager 按 Kind 前缀约定解析（如 Create + 插件名 + Plugin） }
  TCreatePluginFunc = function: IPluginContract; stdcall;

{ --- Helpers --- }
function PluginStateToStr(AState: TPluginState): string;
function PluginTypeToStr(AType: TPluginType): string;
function StrToPluginType(const AStr: string): TPluginType;
function PluginErrorCodeToStr(ACode: Integer): string;

{ --- 元数据 JSON <-> record（宿主与插件共用，GetMetadata 的序列化格式） --- }
function MetadataToJsonBytes(const AMeta: TPluginMetadata): TBytes;
function JsonBytesToMetadata(const ABytes: TBytes;
  out AMeta: TPluginMetadata): Boolean;
function HealthToJsonBytes(const AHealth: TPluginHealthStatus): TBytes;

implementation

uses
  System.JSON, System.Generics.Collections;

function PluginStateToStr(AState: TPluginState): string;
begin
  case AState of
    psUnloaded:   Result := 'Unloaded';
    psLoading:    Result := 'Loading';
    psLoaded:     Result := 'Loaded';
    psReloading:  Result := 'Reloading';
    psPendingRestart: Result := 'PendingRestart';
    psError:      Result := 'Error';
    psUnloading:  Result := 'Unloading';
  else
    Result := 'Unknown';
  end;
end;

function PluginTypeToStr(AType: TPluginType): string;
begin
  case AType of
    ptCore:         Result := 'Core';
    ptExtended:     Result := 'Extended';
    ptExperimental: Result := 'Experimental';
  else
    Result := 'Unknown';
  end;
end;

function StrToPluginType(const AStr: string): TPluginType;
begin
  if SameText(AStr, 'Core') then
    Result := ptCore
  else if SameText(AStr, 'Extended') then
    Result := ptExtended
  else if SameText(AStr, 'Experimental') then
    Result := ptExperimental
  else
    Result := ptExperimental;
end;

function PluginErrorCodeToStr(ACode: Integer): string;
begin
  case ACode of
    PLUGIN_OK:                Result := 'OK';
    PLUGIN_LOAD_FAILED:       Result := 'LOAD_FAILED';
    PLUGIN_RELOADING:         Result := 'RELOADING';
    PLUGIN_BUSY:              Result := 'BUSY';
    PLUGIN_INVALID_INPUT:     Result := 'INVALID_INPUT';
    PLUGIN_INTERNAL_ERROR:    Result := 'INTERNAL_ERROR';
    PLUGIN_DEPENDENCY_FAILED: Result := 'DEPENDENCY_FAILED';
    PLUGIN_LEASE_TIMEOUT:     Result := 'LEASE_TIMEOUT';
  else
    Result := Format('UNKNOWN(%d)', [ACode]);
  end;
end;

function MetadataToJsonBytes(const AMeta: TPluginMetadata): TBytes;
var
  LJson: TJSONObject;
  LDeps: TJSONArray;
  LCaps: TJSONArray;
  LDep: string;
  LCap: string;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('name', AMeta.Name);
    LJson.AddPair('version', AMeta.Version);
    LJson.AddPair('plugin_type', PluginTypeToStr(AMeta.PluginType));
    LJson.AddPair('description', AMeta.Description);
    LJson.AddPair('author', AMeta.Author);
    LJson.AddPair('abi_major', TJSONNumber.Create(AMeta.AbiMajor));
    LJson.AddPair('abi_minor', TJSONNumber.Create(AMeta.AbiMinor));
    if AMeta.SupportsHotReload then
      LJson.AddPair('supports_hot_reload', TJSONTrue.Create)
    else
      LJson.AddPair('supports_hot_reload', TJSONFalse.Create);
    LDeps := TJSONArray.Create;
    try
      for LDep in AMeta.DependsOn do
        LDeps.Add(LDep);
      LJson.AddPair('depends_on', LDeps);
    except
      LDeps.Free;
      raise;
    end;
    LCaps := TJSONArray.Create;
    try
      for LCap in AMeta.Capabilities do
        LCaps.Add(LCap);
      LJson.AddPair('capabilities', LCaps);
    except
      LCaps.Free;
      raise;
    end;
    Result := TEncoding.UTF8.GetBytes(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function JsonBytesToMetadata(const ABytes: TBytes;
  out AMeta: TPluginMetadata): Boolean;
var
  LValue: TJSONValue;
  LJson: TJSONObject;
  LDeps: TJSONArray;
  I: Integer;
begin
  Result := False;
  AMeta := Default(TPluginMetadata);
  if Length(ABytes) = 0 then
    Exit;
  try
    LValue := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(ABytes));
  except
    Exit;
  end;
  if LValue = nil then
    Exit;
  try
    if not (LValue is TJSONObject) then
      Exit;
    LJson := TJSONObject(LValue);
    if LJson.TryGetValue<string>('name', AMeta.Name) and
       LJson.TryGetValue<string>('version', AMeta.Version) then
    begin
      LJson.TryGetValue<string>('description', AMeta.Description);
      LJson.TryGetValue<string>('author', AMeta.Author);
      LJson.TryGetValue<Integer>('abi_major', AMeta.AbiMajor);
      LJson.TryGetValue<Integer>('abi_minor', AMeta.AbiMinor);
      LJson.TryGetValue<Boolean>('supports_hot_reload', AMeta.SupportsHotReload);
      if LJson.TryGetValue<TJSONValue>('plugin_type', LValue) then
        AMeta.PluginType := StrToPluginType(LValue.Value);
      if LJson.TryGetValue<TJSONArray>('depends_on', LDeps) then
      begin
        SetLength(AMeta.DependsOn, LDeps.Count);
        for I := 0 to LDeps.Count - 1 do
          AMeta.DependsOn[I] := LDeps.Items[I].Value;
      end;
      if LJson.TryGetValue<TJSONArray>('capabilities', LDeps) then
      begin
        SetLength(AMeta.Capabilities, LDeps.Count);
        for I := 0 to LDeps.Count - 1 do
          AMeta.Capabilities[I] := LDeps.Items[I].Value;
      end;
      Result := True;
    end;
  finally
    LValue.Free;
  end;
end;

function HealthToJsonBytes(const AHealth: TPluginHealthStatus): TBytes;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    if AHealth.IsHealthy then
      LJson.AddPair('is_healthy', TJSONTrue.Create)
    else
      LJson.AddPair('is_healthy', TJSONFalse.Create);
    LJson.AddPair('last_check_time',
      FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', AHealth.LastCheckTime));
    LJson.AddPair('error_message', AHealth.ErrorMessage);
    LJson.AddPair('uptime_seconds', TJSONNumber.Create(AHealth.UptimeSeconds));
    LJson.AddPair('request_count', TJSONNumber.Create(AHealth.RequestCount));
    LJson.AddPair('error_count', TJSONNumber.Create(AHealth.ErrorCount));
    Result := TEncoding.UTF8.GetBytes(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

end.
