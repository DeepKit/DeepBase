{ ============================================================================
  DeepBase.Plugins.CAbi - 纯 C ABI 声明（r2 稳定契约）

  权威：include/deepbase_plugins_c.h（C 头文件为本 ABI 唯一权威来源）
  法源：docs/77.extend.PluginHotReload §5（纯 C 数据面）
        docs/77a.adr.Plugin-ABI-and-Lifetime §2.1/§2.3/§2.4

  纪律（与 C 头文件严格 1:1，禁止管理类型跨边界）：
  - 本单元只含 C 兼容类型：指针、固定宽整数（UInt32/Int32）、
    固定缓冲、记录；禁止 interface/string/TBytes/动态数组/Delphi 对象；
  - 所有导出函数 stdcall，符号名固定（exports 'dbp_*'）；
  - 错误码用 DBP_* 常量，与 Contracts.PLUGIN_* 语义一一对应；
  - ABI 版本：DBP_ABI_MAJOR 完全相等，DBP_ABI_MINOR 宿主 >= 插件。
  ============================================================================ }

unit DeepBase.Plugins.CAbi;

interface

type
  { 不透明句柄：宿主不得解引用内部结构 }
  dbp_plugin_handle = Pointer;

  { ABI 能力协商结果（dbp_get_abi 返回） }
  dbp_abi_info = record
    major: UInt32;
    minor: UInt32;
  end;

  { 字节缓冲（入参）：调用方分配，被调方只读，不跨边界转移所有权 }
  dbp_buffer = record
    data: PByte;
    length: UInt32;
  end;
  Pdbp_buffer = ^dbp_buffer;

  { 输出缓冲（宿主分配）：两次调用模式；被调方只写，不释放 }
  dbp_out_buffer = record
    data: PByte;
    capacity: UInt32;
  end;
  Pdbp_out_buffer = ^dbp_out_buffer;

  { 固定宽时间戳/计数（跨边界统一，避免 Delphi TDateTime/Int64 歧义） }
  { 布局钉死：与 C 头 include/deepbase_plugins_c.h 严格一致（x64 自然对齐）。
    is_healthy(1) + padding(7) + uptime(8) + request(8) + error(8) + msg(256) = 288。 }
  dbp_health_info = record
    is_healthy: Byte;          { 0=不健康, 1=健康 }
    _pad: array [0..6] of Byte; { 显式 padding 使 UInt64 对齐，不依赖编译器对齐设置 }
    uptime_seconds: UInt64;
    request_count: UInt64;
    error_count: UInt64;
    error_message: array [0..255] of AnsiChar;  { UTF-8，固定缓冲，0 结尾 }
  end;
  Pdbp_health_info = ^dbp_health_info;

  { 导出函数类型（stdcall，符号名见 exports 'dbp_*'）。
    注意与 C 头文件 1:1：dbp_buffer 一律按指针传递（C 风格），
    dbp_out_buffer / dbp_health_info 也按指针，跨边界无按值复制。 }
  TDbpCreateFunc      = function(const AConfig: Pdbp_buffer): dbp_plugin_handle; stdcall;
  TDbpDestroyFunc     = procedure(AHandle: dbp_plugin_handle); stdcall;
  TDbpGetAbiFunc      = function: dbp_abi_info; stdcall;
  TDbpInitializeFunc  = function(AHandle: dbp_plugin_handle; const AConfig: Pdbp_buffer): Int32; stdcall;
  TDbpShutdownFunc    = function(AHandle: dbp_plugin_handle): Int32; stdcall;
  TDbpReloadConfigFunc= function(AHandle: dbp_plugin_handle; const AConfig: Pdbp_buffer): Int32; stdcall;
  TDbpGetMetadataFunc = function(AHandle: dbp_plugin_handle; AOut: Pdbp_out_buffer): Int32; stdcall;
  TDbpGetHealthFunc   = function(AHandle: dbp_plugin_handle; AOut: Pdbp_health_info): Int32; stdcall;
  TDbpGetLastErrorFunc= function(AHandle: dbp_plugin_handle; AOut: Pdbp_out_buffer): Int32; stdcall;
  TDbpFreeBufferFunc  = procedure(APtr: Pointer); stdcall;
  { ABI 1.1 通用业务调用（可选导出，host 需验证 MINOR>=1 且导出存在后再调用） }
  TDbpInvokeFunc      = function(AHandle: dbp_plugin_handle;
    const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;
  { ABI 1.1 插件分配归属变体：同参数，但 AOut.data 由插件分配、宿主须用
    dbp_free_buffer 释放（P0-001 ABI11 remediation §F5）。 }
  TDbpInvokeAllocFunc = function(AHandle: dbp_plugin_handle;
    const ARequest: Pdbp_buffer; AOut: Pdbp_out_buffer): Int32; stdcall;

const
  { ABI 版本（与 C 头文件 DBP_ABI_MAJOR/MINOR 严格一致） }
  DBP_ABI_MAJOR = 1;
  DBP_ABI_MINOR = 1;

  { 错误码（与 Contracts.PLUGIN_* 语义一一对应，见 77a §2.4） }
  DBP_OK                 = 0;
  DBP_ERR_LOAD_FAILED    = -1;
  DBP_ERR_RELOADING      = -2;
  DBP_ERR_BUSY           = -3;
  DBP_ERR_INVALID_INPUT  = -4;
  DBP_ERR_INTERNAL       = -5;
  DBP_ERR_DEPENDENCY     = -6;
  DBP_ERR_LEASE_TIMEOUT  = -7;

  { 导出函数符号名（与 C 头文件声明一致；经 exports 固定） }
  DBP_EXPORT_PREFIX = 'dbp_';
  DBP_EXPORT_CREATE       = 'dbp_create';
  DBP_EXPORT_DESTROY      = 'dbp_destroy';
  DBP_EXPORT_GET_ABI      = 'dbp_get_abi';
  DBP_EXPORT_INITIALIZE   = 'dbp_initialize';
  DBP_EXPORT_SHUTDOWN     = 'dbp_shutdown';
  DBP_EXPORT_RELOAD_CFG   = 'dbp_reload_config';
  DBP_EXPORT_GET_METADATA = 'dbp_get_metadata';
  DBP_EXPORT_GET_HEALTH   = 'dbp_get_health';
  DBP_EXPORT_GET_LAST_ERR = 'dbp_get_last_error';
  DBP_EXPORT_FREE_BUFFER  = 'dbp_free_buffer';
  DBP_EXPORT_INVOKE       = 'dbp_invoke';
  DBP_EXPORT_INVOKE_ALLOC = 'dbp_invoke_alloc';

implementation

end.
