{ ============================================================================
  TestPlugin11NoInvoke.CAbi — 1.1 缺 invoke 导出 fixture 纯 C ABI 转发层（task#11 场景4）

  - dbp_get_abi 报 major=1 / minor=1（与宿主匹配，过版本门）
  - 不导出 dbp_invoke / dbp_invoke_alloc（触发 capability 不一致）
  - 9 项必需导出齐全（过必需导出门）
  - 法源：core/DeepBase.Plugins.CAbiLoader.pas L187-196（minor>=1 无 invoke → 拒）
  ============================================================================ }
unit TestPlugin11NoInvoke.CAbi;

interface

uses
  DeepBase.Plugins.CAbi;

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
  TestPlugin11NoInvoke.Impl;

type
  TDbpWrapper = class
  public
    Plugin: IPluginContract;
  end;

function dbp_create(const AConfig: Pdbp_buffer): dbp_plugin_handle; stdcall;
var
  LWrapper: TDbpWrapper;
begin
  try
    LWrapper := TDbpWrapper.Create;
    try
      LWrapper.Plugin := CreateNoInvokePlugin;
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
  { 与宿主匹配 major=1/minor=1，过版本门；但因无 invoke 导出，倒在 L189。 }
  Result.major := 1;
  Result.minor := 1;
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
  { 无 invoke_alloc 不分配输出指针，nil 安全 no-op }
  if APtr = nil then
    Exit;
end;

end.
