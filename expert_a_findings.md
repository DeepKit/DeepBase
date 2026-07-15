# 专家 A 审阅报告:Core 基础设施

> 审查日期:2026-06-21
> 审查人:专家 A(并发与基础设施专家)
> 审查范围:Core/ 下基础设施模块 - Cache、Collections、Memory、EventBus、ObjectPool、Benchmark、Compression、Crypto、DateTime、Logging、Exception(s)、Storage.Interfaces、Types、Constants
> 文件总数:12 个 .pas 文件

## 概要

| 项目 | 数值 |
|------|------|
| 审阅模块数 | 12 |
| 发现总数 | 25 |
| CRITICAL(P0) | 2 |
| HIGH(P1) | 5 |
| MEDIUM(P2) | 8 |
| LOW(P3) | 6 |
| NOTE(良好实践) | 4 |

## 发现列表

| ID | 模块 | 严重度 | 类型 | 简述 | 位置 |
|----|------|--------|------|------|------|
| INFRA-001 | DeepBase.Cache.pas | P0 | bug | TCache 声明 LFU 淘汰策略枚举和 EvictLFU 方法但从未实现,用户设 cepLFU 时静默失效导致无界增长 | L57-63, L136-143 |
| INFRA-002 | DeepBase.EventBus.pas | P0 | api-design | ALLOWED_EVENT_TYPES 硬编码白名单与 Subscribe<T>/Publish<T> RTTI 路径不一致,类型安全 API 完全绕过白名单 | L681-684, L691-703, L1225-1253 |
| INFRA-003 | DeepBase.EventBus.pas | P1 | resource-leak | finalization 中 GEventBus.Free 可能在另一线程操作时 AV;若 GEventBus 未初始化直接 Free 也会 AV | L1261-1265 |
| INFRA-004 | DeepBase.Logging.pas | P1 | thread-safety | TDeepBaseLogger.Logger() 中 GLoggerLock 的 TInterlocked.CompareExchange 与 TMonitor.Enter 混用,初始化路径竞态 | L201-237 |
| INFRA-005 | DeepBase.Cache.pas | P1 | api-design | TCache.OwnValues 所有权语义无文档,FreeValueIfOwned 对值类型 V 编译失败;缺泛型约束 `where V: class` | L134, L143, L335-348 |
| INFRA-006 | DeepBase.DateTime.pas | P1 | maintainability | TBusinessDays.IsWeekend 使用 `DayOfTheWeek mod 7` 隐式映射 Sunday=0,与枚举顺序强耦合,改动即崩 | L1139-1145 |
| INFRA-007 | DeepBase.Logging.pas / DeepBase.Exception.pas | P1 | correctness | TLogger.LogException 直接读 E.StackTrace 缺条件编译,10.3 以下编译器记录空栈 | L719, L113-118 |
| INFRA-008 | DeepBase.Collections.pas | P2 | performance | TLRUCache.MoveToEnd O(n) 移动,高频访问大容量 LRU 热点;已有 Prev/Next 指针未用 | L678-691 |
| INFRA-009 | DeepBase.Memory.pas / DeepBase.Cache.pas | P2 | api-design | TSmartCache 与 TCache 功能重叠,各自维护独立 TEvictionPolicy 枚举,认知负担 | - |
| INFRA-010 | DeepBase.Logging.pas | P2 | maintainability | TDeepBaseLogger 全局初始化嵌套双重检查锁,结构复杂;initialization 已创建 GLoggerLock,lazy-init 路径永不触发 | L201-237 |
| INFRA-011 | DeepBase.EventBus.pas | P2 | thread-safety | PublishAsync 用 TTask.Run 而 edmAsync 用 TThread,异常传播/线程池行为不一致;TTask.Run 饱和时 TrackAsyncEnd 可能不执行 | L993-1016 |
| INFRA-012 | DeepBase.Logging.pas | P2 | correctness | WriteToFile PickLogFileForWrite 无限循环,Windows 260 字符路径限制下生成无效路径但不退出 | L635-663 |
| INFRA-013 | DeepBase.Exception.pas | P2 | maintainability | TDeepBaseExceptionHandler class constructor 创建无用单例 FInstance,所有方法都是 static | L61-69 |
| INFRA-014 | DeepBase.DateTime.pas | P2 | correctness | FromRFC2822 用 StrToDateTime 简化实现,无法解析含时区的 RFC 2822 字符串,与 ToRFC2822 不对称 | L705-709 |
| INFRA-015 | DeepBase.DateTime.pas | P2 | api-design | AddBusinessDays(ADate, 0) 当 ADate 为非营业日时返回原日期,文档未明确 | L1152-1174 |
| INFRA-016 | DeepBase.Exceptions.pas | P3 | i18n | 文件头中文字符编码错误,ANSI 编辑器打开显示乱码 | L6-8 |
| INFRA-017 | DeepBase.EventBus.pas | P3 | security | IsValidEventType 黑名单仅拦截 system+exec/cmd,Subscribe<T> 完全绕过 | L1248-1253 |
| INFRA-018 | DeepBase.DateTime.pas | P3 | correctness | Diff 的 tuMonths/tuYears 用 30.4375/365.25 近似,订阅续期场景累积误差 | L940-944 |
| INFRA-019 | DeepBase.Logging.pas | P3 | resource-leak | FWriteThread.FreeOnTerminate=False,Destroy 未调用时成孤儿(可接受但可改进) | L324-326 |
| INFRA-020 | DeepBase.DateTime.pas | P3 | correctness | TTimeSpanEx.FromMilliseconds 极端大值 Days 字段(Integer)可能溢出 | L349-359 |
| INFRA-021 | DeepBase.Logging.pas | P3 | maintainability | GLogger finalization 中 GLoggerInitializedByManager 所有权边界不清晰 | L977-989 |

## 良好实践记录

- N-001: TLogEntry 用 record,FLogQueue 批量处理(MAX_BATCH_SIZE=100)性能优秀
- N-002: TEventBus.FLiveSubscriptions 在 Destroy 时批量 InvalidateBus,防御 dangling-pointer Unsubscribe
- N-003: Storage.Interfaces 端口架构清晰,支持 FireDAC 与其他后端插件化
- N-004: SanitizeLogMessage FR-014 修复正确,仅处理真正日志注入向量

## 综合评估

整体质量生产级,架构清晰,线程安全性经过专门修复(BASIC-023 等标识符显示有系统性安全审查过程)。无阻塞性问题,代码可编译运行,核心逻辑正确。

**优先级排序**:
1. INFRA-001(P0):LFU 未实现
2. INFRA-002(P0):EventBus 白名单不一致
3. INFRA-003(P1):EventBus finalization AV
4. INFRA-004(P1):Logger 初始化竞态
5. INFRA-007(P1):LogException 缺条件编译
6. INFRA-006(P1):DayOfWeek 隐式映射

主要技术债务:TLRUCache O(n) MoveToEnd(INFRA-008)、FromRFC2822 简化实现(INFRA-014)。
