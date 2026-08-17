{ ============================================================================
  TestPluginABI10.CAbi — ABI 1.0 fixture 纯 C ABI 转发层（task#11 A11-1/A11-2）

  与 TestPlugin77.CAbi 区别：
  - dbp_get_abi 硬编 major=1 / minor=0（模拟 1.0 旧插件，不引用 DBP_ABI_MINOR 常量）
  - 不导出 dbp_invoke / dbp_invoke_alloc（1.0 无通用业务调用 capability）
  - 无白名单/GetMem 逻辑（不分配输出指针，dbp_free_buffer 走两次调用宿主分配 no-op）
  - metadata 返回空 capability 数组（见 Impl）

  法源：core/DeepBase.Plugins.CAbiLoader.pas L187（minor<1 不要求 invoke → 加载合法）
  仅供 CAbiLoader 门禁契约测试 harness [08] 段：场景1 成功 / 场景2 EMissingInvoke。
  ============================================================================ }
unit TestPluginABI10.CAbi;

interface

uses
  DeepBase.Plugins.CAbi;

{ --- dbp_* 纯 C ABI 导出（9 项必需，无 invoke/invoke_alloc） --- }
function dbp_create(const AConfig: Pdbp_buffer): dbp_plugin_handle; stdcall;
procedure dbp_destroy(AHandle: dbp_plugin_handle); stdcall;
function dbp_get_abi: dbp_abi_info; stdcall;
function dbp_initialize(AHandle: dbp_plugin_handle;
  const AConfig: Pdbp_buffer): Int32; stdcall;
function dbp_shutdown(AHandle: dbp_plugin_handle): Int32; stdcall;
function dbp_reload_config(AHandle: dbp_plugin_handle;
  const AConfig: Pdbp_buffer): Int32; stdcall;
function dbp_get_metadata(AHandle: dbp_plugin_handle;
  AOut: Pdbp_out_buffer): Int32; stdcall;
function dbp_get_health(AHandle: dbp_plugin_handle;
  AOut: Pdbp_health_info): Int32; stdcall;
function dbp_get_last_error(AHandle: dbp_plugin_handle;
  AOut: Pdbp_out_buffer): Int32; stdcall;
procedure dbp_free_buffer(APtr: Pointer); stdcall;

implementation

uses
  System.SysUtils, System.JSON,
  DeepBase.Plugins.Contracts,
  TestPluginABI10.Impl;

type
  TDbpWrapper = class
  public
    Plugin: IPluginContract;
    MetaJsonBytes: TBytes;
    LastErrorBytes: TBytes;
  end;

function dbp_create(const AConfig: Pdbp_buffer): dbp_plugin_handle; stdcall;
var
  LWrapper: TDbpWrapper;
begin
  try
    LWrapper := TDbpWrapper.Create;
    try
      LWrapper.Plugin := CreateAbi10Plugin;
      Result := LWrapper;
    except
      LWrapper.Free;
      raise;
    end;
  except
    on E: Exception do
      Result := nil;
  end;
end;

procedure dbp_destroy(AHandle: dbp_plugin_handle); stdcall;
begin
  if AHandle <> nil then
    TDbpWrapper(AHandle).Free;
end;

function dbp_get_abi: dbp_abi_info; stdcall;
begin
  { 模拟 ABI 1.0 旧插件：major=1 / minor=0，不引用 DBP_ABI_MINOR 常量。
    宿主 CAbiLoader L187 契约：minor<1 不要求 dbp_invoke 导出 → 加载合法。 }
  Result.major := 1;
  Result.minor := 0;
end;

function dbp_initialize(AHandle: dbp_plugin_handle;
  const AConfig: Pdbp_buffer): Int32; stdcall;
var
  LConfigBytes: TBytes;
begin
  Result := DBP_ERR_INVALID_INPUT;
  if AHandle = nil then
    Exit;
  LConfigBytes := nil;
  if (AConfig <> nil) and (AConfig.length > 0) and (AConfig.data <> nil) then
  begin
    SetLength(LConfigBytes, AConfig.length);
    Move(AConfig.data^, LConfigBytes[0], AConfig.length);
  end;
  Result := TDbpWrapper(AHandle).Plugin.Initialize(LConfigBytes);
end;

function dbp_shutdown(AHandle: dbp_plugin_handle): Int32; stdcall;
begin
  if AHandle = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  Result := TDbpWrapper(AHandle).Plugin.Shutdown;
end;

function dbp_reload_config(AHandle: dbp_plugin_handle;
  const AConfig: Pdbp_buffer): Int32; stdcall;
var
  LConfigBytes: TBytes;
begin
  if AHandle = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  LConfigBytes := nil;
  if (AConfig <> nil) and (AConfig.length > 0) and (AConfig.data <> nil) then
  begin
    SetLength(LConfigBytes, AConfig.length);
    Move(AConfig.data^, LConfigBytes[0], AConfig.length);
  end;
  Result := TDbpWrapper(AHandle).Plugin.ReloadConfig(LConfigBytes);
end;

function TwoPhaseCopy(const ASource: TBytes;
  AOut: Pdbp_out_buffer): Int32; stdcall;
begin
  if AOut = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  if AOut.capacity = 0 then
  begin
    Result := Length(ASource);
    Exit;
  end;
  if AOut.capacity < Length(ASource) then
    Exit(Length(ASource));
  Move(ASource[0], AOut.data^, Length(ASource));
  Result := Length(ASource);
end;

function dbp_get_metadata(AHandle: dbp_plugin_handle;
  AOut: Pdbp_out_buffer): Int32; stdcall;
var
  LBytes: TBytes;
begin
  if AHandle = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  try
    TDbpWrapper(AHandle).Plugin.GetMetadata(LBytes);
    Result := TwoPhaseCopy(LBytes, AOut);
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

function dbp_get_health(AHandle: dbp_plugin_handle;
  AOut: Pdbp_health_info): Int32; stdcall;
var
  LBytes: TBytes;
  LRoot: TJSONValue;
  LObj: TJSONObject;
  LB: Boolean;
begin
  Result := DBP_ERR_INVALID_INPUT;
  if (AHandle = nil) or (AOut = nil) then
    Exit;
  FillChar(AOut^, SizeOf(AOut^), 0);
  try
    TDbpWrapper(AHandle).Plugin.GetHealthStatus(LBytes);
    LRoot := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LBytes));
    try
      if LRoot is TJSONObject then
      begin
        LObj := TJSONObject(LRoot);
        if LObj.TryGetValue<Boolean>('is_healthy', LB) then
          AOut.is_healthy := Byte(Ord(LB));
      end;
    finally
      LRoot.Free;
    end;
    Result := DBP_OK;
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

function dbp_get_last_error(AHandle: dbp_plugin_handle;
  AOut: Pdbp_out_buffer): Int32; stdcall;
var
  LBytes: TBytes;
begin
  if AHandle = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  try
    TDbpWrapper(AHandle).Plugin.GetLastError(LBytes);
    Result := TwoPhaseCopy(LBytes, AOut);
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

procedure dbp_free_buffer(APtr: Pointer); stdcall;
begin
  { 1.0 fixture 不通过 GetMem 分配输出指针（无 invoke_alloc），故无插件分配
    指针需释放；nil 安全 no-op。宿主分配走两次调用自管 TBytes 自回收。 }
  if APtr = nil then
    Exit;
  { 无白名单需释放 —— no-op，不触碰非插件分配/非法指针 }
end;

end.
