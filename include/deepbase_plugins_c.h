/*
 * ============================================================================
 *  deepbase_plugins_c.h - DeepBase DLL 插件纯 C ABI（稳定契约, r2）
 *
 *  法源：docs/77.extend.PluginHotReload §5（纯 C 数据面）
 *        docs/77a.adr.Plugin-ABI-and-Lifetime §2.1/§2.3/§2.4
 *
 *  纪律（纯 C 数据面，禁止管理类型跨边界）：
 *  - 本文件是唯一稳定 ABI 权威；宿主与插件 DLL 必须按本头文件编译；
 *  - 不透明句柄 dbp_plugin_handle，宿主不得解引用内部结构；
 *  - 固定宽度整数（stdint.h），禁止 C++ 类型/模板/RTTI/异常跨边界；
 *  - 字节缓冲：入参 { data, length } 由调用方分配、被调方只读；
 *    输出走"两次调用"或 dbp_free_buffer 所有权协议（见各函数注释）；
 *  - 错误码为显式 int32_t，见 DBP_* 常量；跨边界禁止抛异常；
 *  - ABI 版本：DBP_ABI_MAJOR 必须完全相等，DBP_ABI_MINOR 宿主 >= 插件。
 * ============================================================================
 */
#ifndef DEEPBASE_PLUGINS_C_H
#define DEEPBASE_PLUGINS_C_H

#include <stdint.h>
#include <stddef.h>   /* offsetof（dbp_health_info 布局静态断言） */

/* ---------------------------- 调用约定策略 --------------------------------
 * 本 ABI 钉死调用约定为 DBP_API 宏，宿主与插件 DLL 必须一致。
 *
 *  - 默认（未定义 DBP_API）：按 C 默认调用约定 cdecl（x64 上 cdecl 与
 *    stdcall 无差别）。
 *  - x86 宿主或插件：显式钉死为 __stdcall，与 Delphi 侧 stdcall 对齐，
 *    避免 cdecl/stdcall 混用导致栈损坏。
 *    用法：编译前 `#define DBP_API __stdcall`（或编译参数 -DDBP_API=__stdcall）。
 *
 *  Delphi 声明（Core/DeepBase.Plugins.CAbi.pas）恒为 stdcall；
 *  C 侧必须经 DBP_API 与此一致（x64 天然一致，x86 需显式 __stdcall）。
 * ========================================================================== */
#ifndef DBP_API
#  define DBP_API   /* 默认 cdecl；x86 宿主 define 为 __stdcall */
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------- ABI 版本 -------------------------------- */
#define DBP_ABI_MAJOR 1u
#define DBP_ABI_MINOR 1u

/* ------------------------------- 错误码 ---------------------------------- */
#define DBP_OK                0   /* 成功                                    */
#define DBP_ERR_LOAD_FAILED   (-1) /* 加载失败（含签名/ABI 校验失败）        */
#define DBP_ERR_RELOADING     (-2) /* 插件正在热重载，新调用应降级            */
#define DBP_ERR_BUSY          (-3) /* 调用超时/熔断中                         */
#define DBP_ERR_INVALID_INPUT (-4) /* 入参校验失败                            */
#define DBP_ERR_INTERNAL      (-5) /* 插件内部错误（DLL 内已捕获）            */
#define DBP_ERR_DEPENDENCY    (-6) /* 依赖插件加载失败                        */
#define DBP_ERR_LEASE_TIMEOUT (-7) /* Lease 获取超时                           */

/* ------------------------------- 类型定义 -------------------------------- */
/* 不透明句柄：宿主通过 dbp_create 获得，不得解引用内部结构                  */
typedef void* dbp_plugin_handle;

/* ABI 能力协商结果（dbp_get_abi 返回）                                      */
typedef struct dbp_abi_info {
    uint32_t major;
    uint32_t minor;
} dbp_abi_info;

/* 字节缓冲（入参）：调用方分配，被调方只读，不跨边界转移所有权              */
typedef struct dbp_buffer {
    const uint8_t* data;
    uint32_t length;
} dbp_buffer;

/* 输出缓冲（宿主分配）：用于"两次调用"模式。调用方先调长度查询函数拿到
   required_len，再分配 capacity >= required_len 的缓冲区并传入。
   被调方只写 [0, required_len) 并返回实际写入长度，不释放。               */
typedef struct dbp_out_buffer {
    uint8_t* data;
    uint32_t capacity;
} dbp_out_buffer;

/* 固定宽时间戳/计数（跨边界统一，避免 Delphi TDateTime/Int64 歧义）        */
typedef struct dbp_health_info {
    uint8_t  is_healthy;      /* 0=不健康, 1=健康                              */
    uint8_t  _pad[7];         /* 显式 padding：UInt64 对齐，钉死跨编译器布局    */
    uint64_t uptime_seconds;  /* 自 Initialize 起的运行秒数                     */
    uint64_t request_count;   /* 累计请求数                                     */
    uint64_t error_count;     /* 累计错误数                                     */
    char     error_message[256]; /* 最近错误文本（UTF-8，固定缓冲，0 结尾）     */
} dbp_health_info;

/* 布局钉死：与 Delphi 侧 Core/DeepBase.Plugins.CAbi.pas 严格一致。
   偏移 is_healthy=0, uptime=8, request=16, error=24, msg=32；总大小 288。 */
_Static_assert(offsetof(dbp_health_info, uptime_seconds) == 8,
               "dbp_health_info.uptime_seconds offset broken");
_Static_assert(offsetof(dbp_health_info, error_message) == 32,
               "dbp_health_info.error_message offset broken");
_Static_assert(sizeof(dbp_health_info) == 288,
               "dbp_health_info size broken");

/* ---------------------------- 生命周期函数 ------------------------------- */
/*
 * 创建插件实例。返回不透明句柄；失败返回 NULL。
 * config 可为 NULL（length=0）表示无初始配置。
 */
DBP_API dbp_plugin_handle dbp_create(const dbp_buffer* config);

/* 销毁插件实例。句柄必须来自本 DLL 的 dbp_create，禁止跨模块销毁。          */
DBP_API void dbp_destroy(dbp_plugin_handle handle);

/* 查询 ABI 能力。返回 dbp_abi_info；host 填 ABI 常量。                      */
DBP_API dbp_abi_info dbp_get_abi(void);

/* 生命周期：Initialize/Shutdown/ReloadConfig，返回错误码（见 DBP_*）        */
DBP_API int32_t dbp_initialize(dbp_plugin_handle handle, const dbp_buffer* config);
DBP_API int32_t dbp_shutdown(dbp_plugin_handle handle);
DBP_API int32_t dbp_reload_config(dbp_plugin_handle handle, const dbp_buffer* config);

/* -------------------------- 元数据 / 健康 / 错误 -------------------------- */
/*
 * 获取元数据 JSON（UTF-8）。两次调用模式：
 *   第一次 data=NULL, capacity=0 -> 返回所需长度（字节数，不含 0 结尾；负数=错误码）
 *   第二次 data=宿主分配缓冲, capacity=实际容量 -> 返回实际写入长度
 *   注意：返回的是精确字节长度，不承诺 NUL 结尾；宿主如按 C 字符串使用应自行保证。
 */
DBP_API int32_t dbp_get_metadata(dbp_plugin_handle handle, dbp_out_buffer* out);

/* 获取健康信息（固定宽度结构，无内存所有权问题）                            */
DBP_API int32_t dbp_get_health(dbp_plugin_handle handle, dbp_health_info* out);

/* 获取最近错误文本（UTF-8，两次调用模式，同 dbp_get_metadata）              */
DBP_API int32_t dbp_get_last_error(dbp_plugin_handle handle, dbp_out_buffer* out);

/*
 * 释放插件分配的内存。唯一允许"插件分配、宿主释放"的通道。
 * 仅可释放本 DLL 在 dbp_get_metadata/dbp_get_last_error 中分配的缓冲。
 * 传入 NULL 安全。
 */
DBP_API void dbp_free_buffer(void* ptr);

/* -------------------------- 通用业务调用（ABI 1.1） -------------------------
 * dbp_invoke：ABI 1.1 新增可选导出（DBP_ABI_MINOR=1）。
 *
 *   request 为调用方只读字节（业务 schema 自定义，DeepBase 不感知）；
 *   out 沿用 dbp_out_buffer 两次调用模式：第一次 data=NULL/capacity=0 求所需长度，
 *   第二次宿主分配缓冲写入。允许输出为空（返回 0）。
 *   容量不足返回所需长度（正值，见两次调用契约）；错误返回 DBP_* 负错误码。
 *
 * 契约：
 *  - ABI 1.0 插件可缺失本导出，仍可完成基础生命周期加载（见 77a §2.1 MINOR 规则）；
 *  - 宿主调用前必须验证 MINOR>=1 且导出存在；
 *  - 插件内部异常不得跨边界：映射为 DBP_ERR_INTERNAL，细节走 dbp_get_last_error；
 *  - 业务 schema（如站点适配 JSON）不得出现在 DeepBase ABI 类型或函数名中。
 */
DBP_API int32_t dbp_invoke(dbp_plugin_handle handle, const dbp_buffer* request,
                           dbp_out_buffer* out);

/* dbp_invoke_alloc —— 插件分配输出归属（P0-001 ABI11 remediation §F5）
 *  形参与 dbp_invoke 一致；区别在 out->data 的所有权：
 *  - 本函数不走两次调用：插件用自身分配器分配 out->data、写入响应并返回字节数（正值）；
 *  - 调用方（宿主）持有返回的 out->data 并**必须用 dbp_free_buffer 释放**；
 *  - 负值=DBP_ERR_*，此时 out->data 未分配、宿主无需释放。
 *  错误指针对 dbp_free_buffer 安全（no-op，不在白名单即不释放）。
 *  本导出为 ABI 1.1 可选；缺失不影响基础生命周期加载。 */
DBP_API int32_t dbp_invoke_alloc(dbp_plugin_handle handle, const dbp_buffer* request,
                                 dbp_out_buffer* out);

#ifdef __cplusplus
}
#endif

#endif /* DEEPBASE_PLUGINS_C_H */
