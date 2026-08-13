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

#ifdef __cplusplus
extern "C" {
#endif

/* ------------------------------- ABI 版本 -------------------------------- */
#define DBP_ABI_MAJOR 1u
#define DBP_ABI_MINOR 0u

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
    uint64_t uptime_seconds;  /* 自 Initialize 起的运行秒数                     */
    uint64_t request_count;   /* 累计请求数                                     */
    uint64_t error_count;     /* 累计错误数                                     */
    char     error_message[256]; /* 最近错误文本（UTF-8，固定缓冲，0 结尾）     */
} dbp_health_info;

/* ---------------------------- 生命周期函数 ------------------------------- */
/*
 * 创建插件实例。返回不透明句柄；失败返回 NULL。
 * config 可为 NULL（length=0）表示无初始配置。
 */
dbp_plugin_handle dbp_create(const dbp_buffer* config);

/* 销毁插件实例。句柄必须来自本 DLL 的 dbp_create，禁止跨模块销毁。          */
void dbp_destroy(dbp_plugin_handle handle);

/* 查询 ABI 能力。返回 dbp_abi_info；host 填 ABI 常量。                      */
dbp_abi_info dbp_get_abi(void);

/* 生命周期：Initialize/Shutdown/ReloadConfig，返回错误码（见 DBP_*）        */
int32_t dbp_initialize(dbp_plugin_handle handle, const dbp_buffer* config);
int32_t dbp_shutdown(dbp_plugin_handle handle);
int32_t dbp_reload_config(dbp_plugin_handle handle, const dbp_buffer* config);

/* -------------------------- 元数据 / 健康 / 错误 -------------------------- */
/*
 * 获取元数据 JSON（UTF-8）。两次调用模式：
 *   第一次 data=NULL, capacity=0 -> 返回所需长度（含 0 结尾，负数=错误码）
 *   第二次 data=宿主分配缓冲, capacity=实际容量 -> 返回实际写入长度
 */
int32_t dbp_get_metadata(dbp_plugin_handle handle, dbp_out_buffer* out);

/* 获取健康信息（固定宽度结构，无内存所有权问题）                            */
int32_t dbp_get_health(dbp_plugin_handle handle, dbp_health_info* out);

/* 获取最近错误文本（UTF-8，两次调用模式，同 dbp_get_metadata）              */
int32_t dbp_get_last_error(dbp_plugin_handle handle, dbp_out_buffer* out);

/*
 * 释放插件分配的内存。唯一允许"插件分配、宿主释放"的通道。
 * 仅可释放本 DLL 在 dbp_get_metadata/dbp_get_last_error 中分配的缓冲。
 * 传入 NULL 安全。
 */
void dbp_free_buffer(void* ptr);

#ifdef __cplusplus
}
#endif

#endif /* DEEPBASE_PLUGINS_C_H */
