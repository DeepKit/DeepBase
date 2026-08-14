{ ============================================================================
  DeepBase.Plugins.CAbiLoader - 宿主侧纯 C ABI 加载器（r2）

  权威：include/deepbase_plugins_c.h + Core/DeepBase.Plugins.CAbi.pas
  法源：docs/77.extend.PluginHotReload §5（纯 C 数据面）
        docs/77a.adr.Plugin-ABI-and-Lifetime §2.1/§2.3/§2.4

  职责：
  - LoadLibrary + GetProcAddress 解析固定导出名 dbp_*（不依赖 Delphi 接口）；
  - ABI 能力协商（77a §2.1：MAJOR 必须相等，MINOR 宿主 >= 插件）；
  - 封装跨边界调用为 Pascal 方法（TBytes 入参/出参），宿主内部可安全使用；
  - 跨边界内存所有权：变长输出走两次调用（宿主分配 dbp_out_buffer）
    或 dbp_free_buffer（插件分配/宿主释放），本类负责正确释放；
  - 错误码显式返回，禁止跨边界异常（SafeGuard 层在更上层）。
  ============================================================================ }

unit DeepBase.Plugins.CAbiLoader;

interface

uses
  System.SysUtils, Winapi.Windows,
  DeepBase.Plugins.CAbi;

type
  { 插件无 dbp_invoke 导出（加载的是 ABI 1.0 插件） }
  EMissingInvoke = class(Exception)
  public
    constructor Create(const APluginName: string);
  end;

  { dbp_invoke 返回负错误码（跨边界契约：异常已映射为 DBP_ERR_INTERNAL） }
  EPluginInvokeError = class(Exception)
  private
    FCode: Integer;
  public
    constructor Create(const ACode: Integer; const AMessage: string);
    property Code: Integer read FCode;
  end;

  { C ABI 插件实例：持有 DLL 模块句柄与全部导出函数指针 }
  TCAbiPlugin = class
  private
    FModule: HMODULE;
    FAbi: dbp_abi_info;
    FHandle: dbp_plugin_handle;
    FCreate: TDbpCreateFunc;
    FDestroy: TDbpDestroyFunc;
    FGetAbi: TDbpGetAbiFunc;
    FInitialize: TDbpInitializeFunc;
    FShutdown: TDbpShutdownFunc;
    FReloadConfig: TDbpReloadConfigFunc;
    FGetMetadata: TDbpGetMetadataFunc;
    FGetHealth: TDbpGetHealthFunc;
    FGetLastError: TDbpGetLastErrorFunc;
    FFreeBuffer: TDbpFreeBufferFunc;
    FInvoke: TDbpInvokeFunc;          { ABI 1.1 可选，nil 表示无 dbp_invoke }
    FHasInvoke: Boolean;
    FLoaded: Boolean;
    function ResolveProc(const AName: string): Pointer;
    function ResolveOptionalProc(const AName: string): Pointer;
  public
    constructor Create(const ADllPath: string);
    destructor Destroy; override;

    { ABI 能力（加载时协商） }
    property Abi: dbp_abi_info read FAbi;
    property Loaded: Boolean read FLoaded;

    { dbp_invoke 可用性（ABI 1.1 可选导出） }
    property HasInvoke: Boolean read FHasInvoke;

    { 生命周期（返回 DBP_* 错误码） }
    function Initialize(const AConfigBytes: TBytes): Integer;
    function Shutdown: Integer;
    function ReloadConfig(const AConfigBytes: TBytes): Integer;

    { 元数据 / 健康 / 错误文本（两次调用模式，自动释放插件缓冲） }
    function GetMetadata: TBytes;
    function GetHealth: dbp_health_info;
    function GetLastErrorText: string;

    { 通用业务调用（ABI 1.1）。HasInvoke 为 False 时抛 EMissingInvoke。
      ARequest 传入调用方只读字节，AResponse 返回宿主分配的响应字节。
      对 nil handle / nil request / 空输入 / 大输入做确定性处理；
      插件返回负错误码时抛出 EPluginInvokeError（含 GetLastErrorText）。}
    procedure Invoke(const ARequest: TBytes; out AResponse: TBytes);
  end;

implementation

{ ============================================================================ }
{ 两次调用模式：先问长度，宿主分配缓冲，再取数据，最后释放插件缓冲。        }
{ 返回 True=成功，False=调用返回负错误码（AErrCode 回传）。                  }
function TwoPhaseFetch(AGet: TDbpGetMetadataFunc; AHandle: dbp_plugin_handle;
  out AErrCode: Integer; out ABytes: TBytes): Boolean;
var
  LOut: dbp_out_buffer;
  LNeed: Int32;
  LFree: TDbpFreeBufferFunc;
  P: Pointer;
  LRetries: Integer;
begin
  Result := False;
  AErrCode := DBP_ERR_INVALID_INPUT;
  ABytes := nil;

  { Phase 1: 查询所需长度（data=NULL, capacity=0） }
  LOut.data := nil;
  LOut.capacity := 0;
  LNeed := AGet(AHandle, @LOut);
  if LNeed < 0 then
  begin
    AErrCode := LNeed;
    Exit;
  end;

  { Phase 2: 宿主分配缓冲，被调方只写；若返回所需长度 > capacity 说明容量不足，
    扩容重试（容量不足报告所需长度契约，最多 3 次防死循环） }
  LRetries := 0;
  repeat
    SetLength(ABytes, LNeed);
    LOut.data := @ABytes[0];
    LOut.capacity := LNeed;
    LNeed := AGet(AHandle, @LOut);
    Inc(LRetries);
    if LNeed < 0 then
    begin
      AErrCode := LNeed;
      ABytes := nil;
      Exit;
    end;
  until (LNeed <= Integer(LOut.capacity)) or (LRetries >= 3);

  if LNeed > Integer(LOut.capacity) then
  begin
    AErrCode := LNeed;   { 3 次仍不足：报告所需长度，调用方感知 }
    ABytes := nil;
    Exit(False);
  end;

  { 收缩到实际写入长度（若小于 capacity） }
  if LNeed < Length(ABytes) then
    SetLength(ABytes, LNeed);

  AErrCode := DBP_OK;
  Result := True;
end;

{ ============================================================================ }
{ TCAbiPlugin                                                                    }
{ ============================================================================ }

constructor TCAbiPlugin.Create(const ADllPath: string);
begin
  inherited Create;
  FModule := LoadLibrary(PChar(ADllPath));
  if FModule = 0 then
    raise Exception.CreateFmt('CAbiLoader: LoadLibrary 失败: %s (Win32 error %d)',
      [ADllPath, GetLastError]);

  try
    FCreate       := TDbpCreateFunc(ResolveProc(DBP_EXPORT_CREATE));
    FDestroy      := TDbpDestroyFunc(ResolveProc(DBP_EXPORT_DESTROY));
    FGetAbi       := TDbpGetAbiFunc(ResolveProc(DBP_EXPORT_GET_ABI));
    FInitialize   := TDbpInitializeFunc(ResolveProc(DBP_EXPORT_INITIALIZE));
    FShutdown     := TDbpShutdownFunc(ResolveProc(DBP_EXPORT_SHUTDOWN));
    FReloadConfig := TDbpReloadConfigFunc(ResolveProc(DBP_EXPORT_RELOAD_CFG));
    FGetMetadata  := TDbpGetMetadataFunc(ResolveProc(DBP_EXPORT_GET_METADATA));
    FGetHealth    := TDbpGetHealthFunc(ResolveProc(DBP_EXPORT_GET_HEALTH));
    FGetLastError := TDbpGetLastErrorFunc(ResolveProc(DBP_EXPORT_GET_LAST_ERR));
    FFreeBuffer   := TDbpFreeBufferFunc(ResolveProc(DBP_EXPORT_FREE_BUFFER));

    { dbp_invoke 为 ABI 1.1 可选导出：缺少时基础生命周期照常加载 }
    FInvoke     := TDbpInvokeFunc(ResolveOptionalProc(DBP_EXPORT_INVOKE));
    FHasInvoke  := Assigned(FInvoke);

    { ABI 协商（77a §2.1） }
    FAbi := FGetAbi;
    if FAbi.major <> DBP_ABI_MAJOR then
      raise Exception.CreateFmt('CAbiLoader: ABI MAJOR 不匹配 host=%u plugin=%u',
        [DBP_ABI_MAJOR, FAbi.major]);
    if DBP_ABI_MINOR < FAbi.minor then
      raise Exception.CreateFmt('CAbiLoader: ABI MINOR 不兼容 host=%u < plugin=%u',
        [DBP_ABI_MINOR, FAbi.minor]);
    { 若插件声明 MINOR>=1 声称支持 ABI 1.1，则必须实际带 dbp_invoke 导出；
      否则能力协商与实际导出不一致，拒绝加载（77a §2.1 宿主检查 capability） }
    if (FAbi.minor >= 1) and (not FHasInvoke) then
      raise Exception.CreateFmt(
        'CAbiLoader: 插件声明 MINOR>=%u 但缺少 dbp_invoke 导出，capability 不一致',
        [FAbi.minor]);

    { 创建实例（空配置） }
    FHandle := FCreate(nil);
    if FHandle = nil then
      raise Exception.Create('CAbiLoader: dbp_create 返回 NULL');
  except
    if FModule <> 0 then
    begin
      FreeLibrary(FModule);
      FModule := 0;
    end;
    raise;
  end;
  FLoaded := True;
end;

destructor TCAbiPlugin.Destroy;
begin
  if FHandle <> nil then
  begin
    if Assigned(FShutdown) then
      FShutdown(FHandle);   { 尽力 shutdown，忽略错误 }
    if Assigned(FDestroy) then
      FDestroy(FHandle);    { 同模块销毁，禁止跨模块 }
    FHandle := nil;
  end;
  if FModule <> 0 then
  begin
    FreeLibrary(FModule);
    FModule := 0;
  end;
  inherited Destroy;
end;

function TCAbiPlugin.ResolveProc(const AName: string): Pointer;
begin
  Result := GetProcAddress(FModule, PChar(AName));
  if Result = nil then
    raise Exception.CreateFmt('CAbiLoader: 缺少导出函数 %s (Win32 error %d)',
      [AName, GetLastError]);
end;

function TCAbiPlugin.ResolveOptionalProc(const AName: string): Pointer;
begin
  Result := GetProcAddress(FModule, PChar(AName));
  { 可选导出：GetProcAddress 失败时返回 nil，不抛异常 }
end;

function TCAbiPlugin.Initialize(const AConfigBytes: TBytes): Integer;
var
  LBuf: dbp_buffer;
  LCode: Int32;
begin
  LBuf.data := nil;
  LBuf.length := 0;
  if Length(AConfigBytes) > 0 then
  begin
    LBuf.data := @AConfigBytes[0];
    LBuf.length := Length(AConfigBytes);
  end;
  LCode := FInitialize(FHandle, @LBuf);
  Result := LCode;
end;

function TCAbiPlugin.Shutdown: Integer;
begin
  Result := FShutdown(FHandle);
end;

function TCAbiPlugin.ReloadConfig(const AConfigBytes: TBytes): Integer;
var
  LBuf: dbp_buffer;
begin
  LBuf.data := nil;
  LBuf.length := 0;
  if Length(AConfigBytes) > 0 then
  begin
    LBuf.data := @AConfigBytes[0];
    LBuf.length := Length(AConfigBytes);
  end;
  Result := FReloadConfig(FHandle, @LBuf);
end;

function TCAbiPlugin.GetMetadata: TBytes;
var
  LErr: Integer;
begin
  if not TwoPhaseFetch(FGetMetadata, FHandle, LErr, Result) then
    raise Exception.CreateFmt('CAbiLoader: dbp_get_metadata 失败 code=%d',
      [LErr]);
end;

function TCAbiPlugin.GetHealth: dbp_health_info;
var
  LCode: Int32;
begin
  FillChar(Result, SizeOf(Result), 0);
  LCode := FGetHealth(FHandle, @Result);
  if LCode <> DBP_OK then
    raise Exception.CreateFmt('CAbiLoader: dbp_get_health 失败 code=%d', [LCode]);
end;

function TCAbiPlugin.GetLastErrorText: string;
var
  LBytes: TBytes;
  LErr: Integer;
begin
  if not TwoPhaseFetch(FGetLastError, FHandle, LErr, LBytes) then
    Exit('');
  Result := TEncoding.UTF8.GetString(LBytes);
end;

procedure TCAbiPlugin.Invoke(const ARequest: TBytes; out AResponse: TBytes);
var
  LReq: dbp_buffer;
  LOut: dbp_out_buffer;
  LNeed: Int32;
  LCode: Int32;
  LRetries: Integer;
begin
  AResponse := nil;

  { 确定性输入校验 }
  if not FHasInvoke then
    raise EMissingInvoke.Create('CAbiPlugin');
  if FHandle = nil then
    raise EPluginInvokeError.Create(DBP_ERR_INVALID_INPUT, 'nil handle');
  if Length(ARequest) = 0 then
    raise EPluginInvokeError.Create(DBP_ERR_INVALID_INPUT, 'empty request');

  { 输入缓冲：调用方只读，被调方只读 }
  LReq.data := nil;
  LReq.length := 0;
  if Length(ARequest) > 0 then
  begin
    LReq.data := @ARequest[0];
    LReq.length := Length(ARequest);
  end;

  { Phase 1: 查询所需输出长度（data=NULL, capacity=0）。
    返回正长度=需要 capacity；返回 0=无输出；返回负=DBP_* 错误码 }
  LOut.data := nil;
  LOut.capacity := 0;
  LCode := FInvoke(FHandle, @LReq, @LOut);
  if LCode < 0 then
    raise EPluginInvokeError.Create(LCode, GetLastErrorText);
  LNeed := LCode;
  if LNeed = 0 then
    Exit;                    { 输出为空，AResponse 保持 nil }

  { Phase 2: 宿主分配缓冲，被调方只写。容量不足返回所需长度，扩容重试（最多 3 次） }
  LRetries := 0;
  repeat
    SetLength(AResponse, LNeed);
    LOut.data := @AResponse[0];
    LOut.capacity := LNeed;
    LCode := FInvoke(FHandle, @LReq, @LOut);
    Inc(LRetries);
    if LCode < 0 then
      raise EPluginInvokeError.Create(LCode, GetLastErrorText);
    if LCode = 0 then
    begin
      AResponse := nil;      { 无输出 }
      Exit;
    end;
    if LCode <= Integer(LOut.capacity) then
      Break;                 { 实际写入长度 <= capacity，成功 }
    { 所需长度 > capacity 继续扩容重试 }
    LNeed := LCode;
    if LRetries >= 3 then
      raise EPluginInvokeError.Create(LCode,
        'dbp_invoke 输出容量持续不足（3 次重试后所需长度 ' + IntToStr(LNeed) + '）');
  until False;

  { 收缩到实际写入长度 }
  if LCode < Integer(LOut.capacity) then
    SetLength(AResponse, LCode);
end;

{ EMissingInvoke }

constructor EMissingInvoke.Create(const APluginName: string);
begin
  inherited CreateFmt('%s 插件未导出 dbp_invoke（ABI 1.0 或无 invoke 能力）',
    [APluginName]);
end;

{ EPluginInvokeError }

constructor EPluginInvokeError.Create(const ACode: Integer; const AMessage: string);
begin
  FCode := ACode;
  inherited CreateFmt('dbp_invoke 调用失败 code=%d: %s', [ACode, AMessage]);
end;

end.
