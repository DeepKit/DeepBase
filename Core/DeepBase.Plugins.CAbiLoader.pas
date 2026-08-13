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
    FLoaded: Boolean;
    function ResolveProc(const AName: string): Pointer;
  public
    constructor Create(const ADllPath: string);
    destructor Destroy; override;

    { ABI 能力（加载时协商） }
    property Abi: dbp_abi_info read FAbi;
    property Loaded: Boolean read FLoaded;

    { 生命周期（返回 DBP_* 错误码） }
    function Initialize(const AConfigBytes: TBytes): Integer;
    function Shutdown: Integer;
    function ReloadConfig(const AConfigBytes: TBytes): Integer;

    { 元数据 / 健康 / 错误文本（两次调用模式，自动释放插件缓冲） }
    function GetMetadata: TBytes;
    function GetHealth: dbp_health_info;
    function GetLastErrorText: string;
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

  { Phase 2: 宿主分配缓冲（capacity >= LNeed），被调方只写 }
  SetLength(ABytes, LNeed);
  LOut.data := @ABytes[0];
  LOut.capacity := LNeed;
  LNeed := AGet(AHandle, @LOut);
  if LNeed < 0 then
  begin
    AErrCode := LNeed;
    ABytes := nil;
    Exit;
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

    { ABI 协商（77a §2.1） }
    FAbi := FGetAbi;
    if FAbi.major <> DBP_ABI_MAJOR then
      raise Exception.CreateFmt('CAbiLoader: ABI MAJOR 不匹配 host=%u plugin=%u',
        [DBP_ABI_MAJOR, FAbi.major]);
    if DBP_ABI_MINOR < FAbi.minor then
      raise Exception.CreateFmt('CAbiLoader: ABI MINOR 不兼容 host=%u < plugin=%u',
        [DBP_ABI_MINOR, FAbi.minor]);

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

end.
