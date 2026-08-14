{ ============================================================================
  TestPlugin77.CAbi - fixture DLL 的纯 C ABI 转发层（P0-001）

  法源：include/deepbase_plugins_c.h（C 权威）
        docs/77a.adr.Plugin-ABI-and-Lifetime §2.3（跨边界内存纪律）

  设计：
  - 本 DLL 同时导出旧 Delphi 接口工厂（Create*Plugin，供 41/41）与
    dbp_* 纯 C 函数（供 P0-001 C ABI 测试）；
  - dbp_create 读 config JSON 的 plugin_type 字段决定创建哪种变体
    （echo / base），默认 echo；返回不透明句柄 = 内部包装器；
    abi_bad 变体不支持（C ABI 为 DLL 级契约，无 per-instance ABI 变体，见 77a §4.1）；
  - 内部持有 IPluginContract + TBytes 仅在 DLL 内部使用，不跨边界；
    跨边界的只有 dbp_* 函数签名（纯 C 数据面）；
  - 变长输出（metadata / last_error）走两次调用：先 GetMetadata 得 TBytes，
    再拷入宿主分配的 dbp_out_buffer；FreeBuffer 用于释放 DLL 内部缓存。
  ============================================================================ }

unit TestPlugin77.CAbi;

interface

uses
  DeepBase.Plugins.CAbi;

{ --- dbp_* 纯 C ABI 导出函数（exports 'dbp_*' 固定名） --- }
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
{ ABI 1.1 通用业务调用 }
function dbp_invoke(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;
{ ABI 1.1 插件分配归属变体：out.data 由本 DLL 分配，宿主须用 dbp_free_buffer 释放 }
function dbp_invoke_alloc(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;

implementation

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs, System.JSON,
  DeepBase.Plugins.Contracts,
  TestPlugin77.Impl;

{ 插件分配白名单（P0-001 ABI11 remediation §F5）：
  dbp_invoke_alloc 用 GetMem 分配的输出指针登记入 GAllocated，dbp_free_buffer
  只有命中白名单的指针才 FreeMem，其它（nil / 宿主分配 / 非法指针）一律 no-op，
  既保证宿主分配指针不被误释放（与旧 no-op 语义/既有 T09a L562 断言兼容），
  又给错误指针契约留出安全余量。GLock 防御并发（为后续并发验收复用）。 }
var
  GAllocated: TList<Pointer> = nil;
  GLock: TCriticalSection = nil;

type
  { 内部包装器：一个 dbp 句柄 = 一个 IPluginContract 实例 }
  TDbpWrapper = class
  public
    Plugin: IPluginContract;
    MetaJsonBytes: TBytes;    { dbp_get_metadata 缓存（两次调用用） }
    LastErrorBytes: TBytes;   { dbp_get_last_error 缓存 }
  end;

{ --- 工具：从 config JSON 解析 plugin_type，创建对应变体 --- }
function ResolvePluginType(const AConfig: Pdbp_buffer): string;
var
  LRoot: TJSONValue;
  LObj: TJSONObject;
  LType: string;
  LConfigBytes: TBytes;
begin
  Result := 'echo';   { 默认 echo }
  if (AConfig = nil) or (AConfig.length = 0) or (AConfig.data = nil) then
    Exit;
  LRoot := nil;
  try
    LConfigBytes := nil;
    SetLength(LConfigBytes, AConfig.length);
    Move(AConfig.data^, LConfigBytes[0], AConfig.length);
    LRoot := TJSONObject.ParseJSONValue(
      TEncoding.UTF8.GetString(LConfigBytes));
    if LRoot is TJSONObject then
    begin
      LObj := TJSONObject(LRoot);
      if LObj.TryGetValue<string>('plugin_type', LType) then
        Result := LType;
    end;
  finally
    LRoot.Free;
  end;
end;

function CreateByType(const AType: string): IPluginContract;
begin
  { C ABI 是 DLL 级契约（77a §4.1）：无 per-instance ABI 变体，故不支持 abi_bad。
    abi_bad 由旧接口世界独立导出 CreateAbiBadPlugin（[03] harness 测试消费）。 }
  if AType = 'base' then
    Result := CreateBasePlugin      { 调 Impl 导出的工厂（类在 implementation 区，不可直接引用） }
  else
    Result := CreateEchoPlugin;     { echo 默认 }
end;

{ ============================================================================ }
{ dbp_* 实现                                                                   }
{ ============================================================================ }

function dbp_create(const AConfig: Pdbp_buffer): dbp_plugin_handle; stdcall;
var
  LWrapper: TDbpWrapper;
begin
  Result := nil;
  try
    LWrapper := TDbpWrapper.Create;
    try
      LWrapper.Plugin := CreateByType(ResolvePluginType(AConfig));
      Result := LWrapper;
    except
      LWrapper.Free;
      raise;
    end;
  except
    on E: Exception do
    begin
      Result := nil;   { 失败返回 NULL，错误经 GetLastError 通道 }
    end;
  end;
end;

procedure dbp_destroy(AHandle: dbp_plugin_handle); stdcall;
begin
  if AHandle <> nil then
    TDbpWrapper(AHandle).Free;
end;

function dbp_get_abi: dbp_abi_info; stdcall;
begin
  Result.major := DBP_ABI_MAJOR;
  Result.minor := DBP_ABI_MINOR;
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

{ 两次调用：Phase1 返回所需长度（含 0 结尾），Phase2 拷入宿主缓冲 }
function TwoPhaseCopy(const ASource: TBytes;
  AOut: Pdbp_out_buffer): Int32; stdcall;
begin
  if AOut = nil then
    Exit(DBP_ERR_INVALID_INPUT);
  if AOut.capacity = 0 then
  begin
    { 宿主询问长度 }
    Result := Length(ASource);
    Exit;
  end;
  if AOut.capacity < Length(ASource) then
    Exit(Length(ASource));   { 缓冲不足：报告所需长度，宿主据此扩容重试 }
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
    { 每次调用重新取，避免缓存过期；只有内存足够时才复用缓存 }
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
        { uptime/request/error count 由 JSON 数字字段解析，简化处理 }
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
var
  LIdx: Integer;
begin
  { §F5 真实路径：仅释放 dbp_invoke_alloc 登记入白名单的插件分配指针。
    nil / 宿主分配 / 非法指针一律 no-op（命中检查在 GLock 保护下进行）。 }
  if APtr = nil then
    Exit;
  if GLock = nil then
    Exit;  { finalization 阶段兜底调用安全：对象已释放则 no-op }
  GLock.Enter;
  try
    LIdx := GAllocated.IndexOf(APtr);
    if LIdx >= 0 then
    begin
      GAllocated.Delete(LIdx);
      FreeMem(APtr);
    end;
    { 未命中 → no-op：不释放非插件分配内存，不触碰非法指针 }
  finally
    GLock.Leave;
  end;
end;

{ ABI 1.1 插件分配归属变体：out.data 由本 DLL GetMem 分配并登记白名单，
  宿主用完调 dbp_free_buffer 释放。不走两次调用询问。 }
function dbp_invoke_alloc(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;
var
  LReqBytes: TBytes;
  LReqStr: string;
  LResp: TBytes;
  LBuf: PByte;
begin
  if (AHandle = nil) or (ARequest = nil) or (AOut = nil) then
    Exit(DBP_ERR_INVALID_INPUT);
  try
    if (ARequest.data = nil) or (ARequest.length = 0) then
      Exit(DBP_ERR_INVALID_INPUT);
    SetLength(LReqBytes, ARequest.length);
    Move(ARequest.data^, LReqBytes[0], ARequest.length);
    LReqStr := TEncoding.UTF8.GetString(LReqBytes);
    if Pos('crash', LowerCase(LReqStr)) > 0 then
      raise Exception.Create('crash requested');
    { 构造 echo_alloc 响应（区别于 dbp_invoke 的 echo，便于断言区分） }
    LResp := TEncoding.UTF8.GetBytes(
      '{"echo_alloc":true,"request_len":' + IntToStr(Length(LReqStr)) + '}');
    { 插件分配：GetMem 一段足量缓冲写入响应，登记白名单 }
    GetMem(LBuf, Length(LResp));
    Move(LResp[0], LBuf^, Length(LResp));
    GLock.Enter;
    try
      GAllocated.Add(LBuf);
    finally
      GLock.Leave;
    end;
    AOut.data := LBuf;
    AOut.capacity := Length(LResp);
    Result := Length(LResp);
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

{ ABI 1.1 通用业务调用：echo 回显请求内容 }
function dbp_invoke(AHandle: dbp_plugin_handle;
  const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;
var
  LReqBytes: TBytes;
  LReqStr: string;
  LResp: TBytes;
begin
  if (AHandle = nil) or (ARequest = nil) then
    Exit(DBP_ERR_INVALID_INPUT);
  try
    { 读入请求（ARequest.data 是 raw ptr，转 TBytes 用 Move 拷贝，不可直接 cast） }
    if (ARequest.data = nil) or (ARequest.length = 0) then
      Exit(DBP_ERR_INVALID_INPUT);
    SetLength(LReqBytes, ARequest.length);
    Move(ARequest.data^, LReqBytes[0], ARequest.length);
    LReqStr := TEncoding.UTF8.GetString(LReqBytes);
    { 若请求含 "crash" 字样则模拟崩溃 }
    if Pos('crash', LowerCase(LReqStr)) > 0 then
      raise Exception.Create('crash requested');
    { 构造 echo 响应 }
    LResp := TEncoding.UTF8.GetBytes(
      '{"echo":true,"request_len":' + IntToStr(Length(LReqStr)) + '}');
    Result := TwoPhaseCopy(LResp, AOut);
  except
    Result := DBP_ERR_INTERNAL;
  end;
end;

{ 白名单对象生命周期：unit 加载时创建，unit 卸载（DLL FreeLibrary）前
  finalization 兜底回收仍登记在册的活指针，防宿主漏调 dbp_free_buffer 导致
  DLL 卸载后悬挂。回收完置 nil，dbp_free_buffer 此后调用见 GLock=nil 安全 no-op。 }
initialization
  GAllocated := TList<Pointer>.Create;
  GLock := TCriticalSection.Create;

finalization
  if GAllocated <> nil then
  begin
    while GAllocated.Count > 0 do
    begin
      FreeMem(GAllocated.Items[0]);
      GAllocated.Delete(0);
    end;
    FreeAndNil(GAllocated);
  end;
  FreeAndNil(GLock);

end.
