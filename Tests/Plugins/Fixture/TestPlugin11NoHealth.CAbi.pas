{ ============================================================================
  TestPlugin11NoHealth.CAbi — 1.1 缺 dbp_get_health 导出 fixture 纯 C ABI 转发层（task#11 场景3）

  - dbp_get_abi 报 major=1 / minor=1（过版本门）
  - 导出 dbp_invoke（minor>=1 契约要求，避免误倒场景4 invoke 缺失门）
  - 故意不导出 dbp_get_health（8+invoke，少 1 必需）→ CAbiLoader ResolveProc 拒
  - 法源：core/DeepBase.Plugins.CAbiLoader.pas L230 "缺少导出函数 dbp_get_health"
  ============================================================================ }
unit TestPlugin11NoHealth.CAbi;

interface

uses
  DeepBase.Plugins.CAbi;

{ 8 项必需 + invoke；缺 dbp_get_health（故意） }
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
{ dbp_get_health 故意不实装/不导出 —— 场景3 核心点 }
function dbp_get_last_error(AHandle: dbp_plugin_handle;
  AOut: Pdbp_out_buffer): Int32; stdcall;
procedure dbp_free_buffer(APtr: Pointer); stdcall;
function dbp_invoke(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;

implementation

uses
  System.SysUtils, System.JSON,
  DeepBase.Plugins.Contracts,
  TestPlugin11NoHealth.Impl;

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
      LWrapper.Plugin := CreateNoHealthPlugin;
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

{ dbp_get_health 故意不在此实装 —— .dpr exports 也不列它。
  宿主 ResolveProc('dbp_get_health') 返回 nil → 抛 "缺少导出函数 dbp_get_health"。 }

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
  { 无 invoke_alloc 不分配输出指针；nil 安全 no-op }
  if APtr = nil then
    Exit;
end;

function dbp_invoke(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;
var
  LResp: TBytes;
begin
  Result := DBP_ERR_INVALID_INPUT;
  if AHandle = nil then
    Exit;
  try
    { 极简 echo stub —— 不依赖 Impl 的 echo 逻辑，仅证导出存在。
      宿主 LoadPlugin 仅做导出存在校验，不调 invoke，故此 stub 不会被生产调用。 }
    LResp := TEncoding.UTF8.GetBytes('{"echo":true}');
    Result := TwoPhaseCopy(LResp, AOut);
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

end.
