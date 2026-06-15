# 09 - 网络通信与可观测性评估

> 评估范围：Features/DeepBase.Net.pas、DeepBase.Net.Transport.pas、DeepBase.Net.Transport.ICS.pas、DeepBase.HttpServer.pas；Core/DeepBase.Resilience.CircuitBreaker.pas、DeepBase.RateLimiter.pas、DeepBase.Scheduler.pas、DeepBase.Metrics.pas

---

## 评估摘要

**总评分：6.5 / 10**

框架在网络通信与可观测性方面提供了**完整度较高的功能骨架**：HTTP 客户端/服务器、四种限流算法、标准三态熔断器、Cron 调度器、Prometheus/JSON/InfluxDB 多格式指标导出均已到位。弹性子系统（熔断/限流）设计质量最高，状态机严谨、线程安全处理良好。主要短板集中在两处：(1) WebSocket 客户端完全是空壳（Connect/Send/Ping 均为注释占位），(2) ICS 传输适配器未实现真正的 HTTP 请求执行（Send 方法直接 raise）。此外，HTTP 服务器缺少连接池/Keep-Alive 调优、请求体大小限制和 graceful shutdown；流式传输是伪流式（先缓冲再拆 SSE）；Summary 指标使用排序数组计算分位数，内存/精度权衡粗糙。

---

## 各子模块评估

### 1. DeepBase.HttpServer (40.3K, 1361 行)

**职责**：基于 Indy TIdHTTPServer 的轻量 HTTP 服务器，提供路由、中间件管线、静态文件服务、请求/响应抽象。

**设计质量：7/10**

**优点**：
- 路由系统使用正则编译模式（`TRoute.CompilePattern`，行 729-752），支持 `:param` 路径参数，模式编译一次、匹配多次，效率合理
- 中间件采用递归链式调用（`RunMiddlewareChain`，行 1312-1323），符合 Express/Koa 风格，支持 `Next()` 短路
- 内建四个实用中间件：Logging、CORS（支持 preflight OPTIONS 204）、BasicAuth、StaticFile
- 响应抽象完整：Text/Html/Json/Bytes/Redirect + 快捷错误方法（NotFound/BadRequest/Unauthorized/Forbidden/InternalError）
- 静态文件中间件有路径穿越防护（行 1001-1002，替换 `..` 和 `//`）
- 二进制响应支持（BUG-049 FIX，行 136, 153, 620-625），使用 `TFile.ReadAllBytes` 避免编码损坏
- `Mount()` 支持子路由挂载（行 1138-1145）
- `THttpContext.Data` 使用 `TDictionary<string, TValue>` 提供请求级数据传递，中间件可向 handler 传递上下文

**已知问题/风险**：

1. **[严重] 无请求体大小限制**：`ProcessRequest` 行 1253-1261 直接 `CopyFrom(PostStream, 0)` 读取全部请求体到内存，无上限检查。攻击者可发送数 GB 的 POST body 导致 OOM。
2. **[严重] 无连接数/并发控制**：直接依赖 Indy 默认线程池，未配置 `MaxConnections`、`ListenQueue`，也无全局限流中间件集成。高并发下线程爆炸。
3. **[中等] 路径穿越防护不充分**：行 1001 的 `StringReplace(RelPath, '..', '', [rfReplaceAll])` 只删除 `..` 但不拒绝请求。`....//` 经过替换后变成 `../`，仍可逃逸。应改为检测并返回 403。
4. **[中等] 无 graceful shutdown**：`Stop` 方法（行 1344-1358）直接设 `FIdServer.Active := False`，不等待进行中的请求完成，可能导致响应被截断。
5. **[低] 中间件注册无接口约束检查**：`Use(Middleware: IMiddleware)` 接受接口，但 `FMiddlewares` 是 `TList<IMiddleware>`，如果调用方传入的 COM 对象引用计数不当，可能导致提前释放。
6. **[低] 路由匹配是线性扫描**：`TRouter.Match`（行 1083-1098）遍历全部路由，每条路由执行正则匹配。路由数量大时性能退化。未使用路由树或字典索引。
7. **[低] CORS 中间件在 preflight 时不调用 `Next()`**（行 877-881），直接返回 204。如果后续有认证中间件需要先执行，这种行为可能不符合预期。

**改进建议**：
- 增加 `MaxRequestBodySize` 配置（默认 10MB），超过时返回 413
- 路径穿越改为直接拒绝（返回 403）而非替换
- 增加 `THttpServer.GracefulStop(TimeoutMs)` 方法
- 考虑路由基数树（radix tree）优化匹配性能
- 增加请求 ID 注入中间件，便于链路追踪

---

### 2. DeepBase.Net (60.9K, ~1100 行)

**职责**：综合网络工具模块，包含 HTTP 客户端封装、WebSocket 客户端（占位）、DNS 解析、IPv4/子网计算、网络连通性检测、SSRF 防护。

**设计质量：6/10**

**优点**：
- HTTP 客户端采用 Fluent API（`THttpRequest`），链式配置 Method/Header/QueryParam/Body/Timeout/Auth，API 设计友好
- SSRF 防护：行 599-602 在请求前验证 URL 安全性（`IsSafeUrl`）并校验解析后的 IP（`ValidateResolvedUrlForHttp`），防止 DNS rebinding
- HTTP Header 注入防护：行 578-582 调用 `IsValidHttpHeader` 验证头部名/值
- IPv4 地址和子网计算功能完整：`TIPv4Address` 支持运算符重载（BitwiseAnd/Or/Xor/Not），`TIPv4Subnet` 支持 CIDR 解析、包含判断、广播地址计算
- DNS 解析封装了 Indy TIdDNSResolver，支持 A/AAAA/CNAME/MX/NS/PTR/SOA/SRV/TXT 全记录类型
- 全局单例 `Http()` 函数提供零配置 HTTP 访问

**已知问题/风险**：

1. **[严重] WebSocket 完全是空壳**：行 898-952，`Connect` 直接设 `FState := wssOpen`，`Send`/`Ping` 内部只有注释 `// Send implementation would go here`。整个 WebSocket 客户端没有任何实际网络操作，但对外暴露了完整的 API 表面。使用者如果不读源码会以为功能可用。
2. **[中等] THttpResponse 是 record 但有 Free 方法**：行 420-424，`THttpResponse.Free` 只释放 Headers 字典。Record 类型不应有 Free 方法（容易被遗忘或重复调用），应改为 procedure 或使用接口管理生命周期。
3. **[中等] 全局单例 GHttpClient 无 finalization 清理**：行 375-391，`GHttpClient` 在 `Http()` 中延迟创建，但单元没有 `finalization` 节来释放它，造成内存泄漏（虽然进程退出时 OS 回收）。
4. **[中等] 每次请求都新建 THTTPClient**：`THttpRequest.Execute`（行 568）每次调用都 `THTTPClient.Create`，不复用连接。HTTP Keep-Alive 失效，每个请求都经历 TCP 握手 + TLS 协商，性能差。
5. **[低] THttpClient_ 方法中 Request 对象创建后在 finally 中 Free**，但如果 `LRequest.Get` 内部抛异常，`Result`（THttpResponse record）中的 Headers 字典已在行 549 被创建但不会被释放。

**改进建议**：
- 立即实现 WebSocket 或明确标记为 `[Stub]` 并在 Connect 时 raise ENetException('Not implemented')
- 引入连接池/持久化 THTTPClient 实例
- 在 finalization 节释放 GHttpClient
- 将 THttpResponse 改为 class 或改用 IDisposable 模式管理资源

---

### 3. DeepBase.Net.Transport (11.0K, 354 行) + Transport.ICS (4.9K, 145 行)

**职责**：HTTP 传输层抽象接口（`IDeepBaseHttpTransport`），支持请求/响应结构体、流式传输扩展（`IDeepBaseStreamingTransport`）、取消令牌、ICS 适配器。

**设计质量：7/10**

**优点**：
- 接口分离设计良好：基础 `IDeepBaseHttpTransport` 和扩展 `IDeepBaseStreamingTransport`，支持依赖注入替换实现
- `ICancellationToken` 使用 `TInterlocked.CompareExchange`（行 282-289）实现无锁取消，线程安全
- 流式传输接口支持 `TStreamChunkEvent` 回调 + `ACancel` 中止，API 设计合理
- `TDeepBaseHttpTransportRequest` 使用 record + 静态 `Create` 工厂方法，默认值合理（Timeout 30s, FollowRedirects True, MaxRedirects 5）
- ICS 配置提供 `CreateSecure` 工厂（行 74-82），强制 TLS 1.2+、证书校验

**已知问题/风险**：

1. **[严重] 流式传输是伪流式**：`TDeepBaseSystemNetTransport.SendStreaming`（行 294-352）先调用 `Send()` 完成全部 HTTP 请求获得完整响应体，再拆分 SSE `data:` 行逐行回调。对于 LLM 流式响应场景，TTFT（首 Token 延迟）等于完整响应延迟，完全没有流式优势。代码注释（行 303-306）也承认了这一限制。
2. **[严重] ICS 传输 Send 方法未实现**：行 125-142，`TDeepBaseIcsHttpTransport.Send` 经过配置合并后直接 `raise EDeepBaseNetTransportError`，提示需要下游项目链接 ICS 实现单元。但仓库内没有该实现单元。这意味着 ICS 传输路径完全不可用。
3. **[中等] FirstTokenMs 通过 StatusText 字符串拼接传递**：行 350-351，`Result.StatusText := Result.StatusText + ' [FirstTokenMs=' + IntToStr(LFirstTokenMs) + ']'`。这种元数据传递方式脆弱，调用方需要字符串解析。应使用独立字段或返回结构体。
4. **[低] 每次 Send 都新建 THTTPClient**（行 189），与 DeepBase.Net 同样的连接不复用问题。

**改进建议**：
- 实现真正的基于 `THTTPClient.BeginGet`/`OnRequestStreamChunk` 事件的流式传输
- 要么实现 ICS 传输，要么移除该模块避免误导
- 为流式响应定义独立的 `TStreamingResponse` record，包含 FirstTokenMs 字段
- 复用 THTTPClient 实例

---

### 4. DeepBase.Resilience.CircuitBreaker (14.4K, ~500 行)

**职责**：熔断器模式实现，三态状态机（Closed/Open/HalfOpen），防止对故障服务的重复调用。

**设计质量：8/10**

**优点**：
- 状态机转换逻辑正确：Closed → (失败达阈值) → Open → (超时) → HalfOpen → (成功达阈值) → Closed；HalfOpen 中任一失败立即回 Open
- `Execute` 方法（行 365-398）将状态检查和活跃计数管理封装在同一锁内，然后在锁外执行用户代码，成功后调 `RecordSuccess`，异常时调 `RecordFailure`。这种设计避免了持锁执行业务代码
- BUG-119 FIX（行 58-59, 273-285）：HalfOpen 状态限制并发探测请求数（`FMaxHalfOpenRequests`），防止高并发下大量请求同时进入探测导致状态混乱
- `AllowRequest` 被标记为 `deprecated`（行 76），引导用户使用 `Execute` 方法保持原子性，这是良好的 API 演进实践
- 支持超时集成（行 401-415）：`Execute(Proc, TimeoutMs)` 组合 `TTimeoutPolicy`，熔断 + 超时双重保护
- 全局注册表 `TCircuitBreakerRegistry` 使用 double-checked locking（行 128-145），线程安全
- 状态变更回调 `TOnCircuitStateChanged` 支持外部监控集成

**已知问题/风险**：

1. **[中等] Execute 方法中 HalfOpen 活跃计数未在所有路径递减**：`Execute(Proc)` 行 385 递增 `FHalfOpenActiveCount` 后，如果 `Proc` 正常执行，调 `RecordSuccess`（行 304-306 递减）；如果异常，调 `RecordFailure`（行 338-339 递减）。但如果 Proc 内部触发了 `Abort`/`Exit` 而非异常（例如通过 `TThread.RaiseException`），或者 RecordSuccess/RecordFailure 本身抛异常，计数将泄漏。
2. **[中等] 默认 OpenDuration 依赖 `DEFAULT_KEEP_ALIVE_TIMEOUT_MS`**（行 171），这个常量来自 `DeepBase.Constants`，语义上"Keep-Alive 超时"与"熔断器开路持续时间"不同，可能造成配置混淆。
3. **[低] 状态变更回调在锁内执行**（行 225-226）：`SetState` 在 `FLock.Enter` 保护��被调用（通过 `CheckHalfOpenTransition` → `SetState`），如果回调执行耗时或重入，可能导致死锁。
4. **[低] 无事件总线/指标集成**：熔断器状态变更不自动上报 Metrics 模块，需要手动配置。

**改进建议**：
- 为 HalfOpen 活跃计数增加 `try/finally` 保护（在 Execute 方法的调用方包装）
- 定义专用的 `DEFAULT_CIRCUIT_BREAKER_OPEN_DURATION_MS` 常量
- 将 `SetState` 回调移到锁外执行
- 自动在状态变更时上报 Metrics Counter

---

### 5. DeepBase.RateLimiter (36.3K, ~900 行)

**职责**：多维度限流模块，实现四种算法（Token Bucket、Fixed Window、Sliding Window Log、Sliding Window Counter），支持 Key 级别隔离和全局管理器。

**设计质量：8/10**

**优点**：
- 四种算法覆盖全面：TokenBucket（平滑+突发）、FixedWindow（简单高效）、SlidingWindowLog（精确）、SlidingWindowCounter（内存高效近似）
- 统一接口 `IRateLimiter`（TryAcquire/Acquire/Reset/GetStats），算法可替换
- Key 级别限流：每个 Key（用户 ID、IP 等）独立桶/窗口，`TDictionary<string, TBucket>` 隔离
- `TRateLimitConfig` 提供流式配置 + `Build` 工厂方法，API 友好
- `TRateLimitManager` 全局单例管理多个限流器，支持 `CheckAll`（多限流器 AND 检查）
- `TRateLimitDecorator` 提供函数级限流装饰器，支持 `ExecuteOrWait` 等待获取
- 参数校验：TokenBucket 构造时验证 Capacity/RefillRate 正数（行 365-368）
- `TRateLimitResult` 包含 `RetryAfterMs` 和 `ResetTime`，便于返回 HTTP 429 头

**已知问题/风险**：

1. **[中等] 无内存回收机制**：`FBuckets`/`FWindows`/`FRequestLogs` 字典随 Key 增长无限膨胀。如果 Key 是高基数（如每用户独立限流 + 百万用户），内存将持续增长无上限。应增加 LRU 淘汰或定期清理过期 Key。
2. **[中等] SlidingWindowLimiter 内存开销大**：行 164，`FRequestLogs` 为每个 Key 维护 `TList<TDateTime>`，每个请求一个 TDateTime（8 字节）。100 万请求 = 8MB/Key。虽有 `CleanupOldRequests`（行 690），但只在 TryAcquire 时触发，不活跃 Key 的旧数据不会被清理。
3. **[中等] 所有算法都依赖 `TDateTime`（系统时钟）**：NTP 时钟回拨会导致限流异常（窗口重新开放、令牌倒退）。高精度场景应改用 `TStopwatch`/`GetTickCount64` 单调时钟。
4. **[低] 全局单例 `RateLimitManager` 的初始化锁 `_RateLimitManagerLock`**（行 320-335）在单元初始化时未创建（无 `initialization` 节），依赖首次调用时创建。如果 `initialization` 缺失，首次调用时 `_RateLimitManagerLock` 可能为 nil 导致 AV。

**改进建议**：
- 增加 Key 过期清理（如每 60 秒扫描一次，删除超过 2 个窗口期无活动的 Key）
- 将 `TDateTime` 替换为 `TThread.GetTickCount64` 单调时钟
- 在 `initialization` 节初始化全局锁和实例
- 考虑增加 Redis 后端接口支持分布式限流

---

### 6. DeepBase.Scheduler (33.6K, ~1100 行)

**职责**：后台任务调度系统，支持 Cron 表达式、一次性延迟、周期间隔、重试退避、任务依赖、优先级、持久化。

**设计质量：7.5/10**

**优点**：
- Cron 解析器支持标准 5 字段（分 时 日 月 周），含通配符 `*`、范围 `1-5`、步进 `*/5`、逗号列表 `1,3,5`（行 389-456）
- 重试策略使用指数退避：`GetDelay(Attempt)` = `InitialDelay * Multiplier^(Attempt-1)`，上限 `MaxDelayMs`（行 608-614）
- 任务持久化通过 `IJobStore` 接口抽象（行 91-97），支持 Save/Remove/LoadAll/Clear，解耦存储实现
- `TTaskMeta` record 记录任务元数据（不含 proc 引用），重启后可重新注册处理函数
- 优雅停机：`Stop` 方法（行 890-922）等待运行中任务完成，支持超时（`StopDrainTimeoutMs`，默认 30 秒，-1 表示无限等待）
- 析构函数（行 791-808）将 `StopDrainTimeoutMs` 临时设为 -1（无限等待），确保不会在任务运行时释放任务对象
- 并发控制：`FMaxConcurrentTasks` 默认 4，`FRunningCount` 原子管理
- `TimerProc`（行 924-933）使用 `TEvent.WaitFor` 代替 `Sleep`，可在 Stop 时立即唤醒

**已知问题/风险**：

1. **[中等] Cron GetNextRun 使用逐分钟遍历**：行 552-576，从当前时间开始逐分钟递增检查 `Matches(DT)`，最多迭代 366*24*60 = 527,040 次。对于稀疏 Cron（如 `0 0 29 2 *` 闰年 2 月 29 日），需要遍历大量无效时间点。应改为基于字段约束的智能跳转。
2. **[中等] 任务执行在 TTask 线程中直接调用用户 Proc**：行 1035 `TaskRef.FProc()`，如果 Proc 抛异常，异常在 TTask 线程中被捕获（行 1078），但行 1074 的 `OnCompleted` 回调在锁外执行。如果 OnCompleted 回调抛异常，将导致未处理异常（TTask 吞掉异常后任务状态可能不一致）。
3. **[中等] ProcessPendingTasks 中优先级排序使用 `Ord(R.FPriority) - Ord(L.FPriority)`**（行 993-995）：`TTaskPriority` 枚举 `tpLow=0, tpNormal=1, tpHigh=2, tpCritical=3`，降序排列正确（Critical 先执行）。但同优先级任务之间无 FIFO 保证（`TObjectDictionary.Values` 遍历顺序不确定）。
4. **[低] SaveTaskMeta 在 `CanRunTask` 和 `ExecuteTask` 路径中未被调用**：任务状态变更后没有自动持久化。如果进程崩溃，`IJobStore` 中的数据可能过期。
5. **[低] `FRunningITask: ITask`**（行 196）字段用于保持 TTask 引用防止 GC，但在行 1067 置 nil 后，如果 TTask 内部还有异步操作，可能过早释放。

**改进建议**：
- 实现基于字段跳转的 Cron 下次计算（先跳到最近的匹配分钟，而非逐分钟递增）
- 增加任务状态变更后的自动持久化钩子
- 同优先级任务改用 `TQueue` 或增加序列号保证 FIFO
- 在 OnCompleted/OnFailed 回调外层增加 try/except 保护

---

### 7. DeepBase.Metrics (44.2K, ~1400 行)

**职责**：应用指标采集系统，支持 Counter、Gauge、Histogram、Timer、Summary 五种指标类型，支持标签（Labels）、MetricFamily、全局注册表、多格式导出（Prometheus/JSON/InfluxDB Line Protocol）。

**设计质量：8/10**

**优点**：
- 指标类型覆盖完整，与 Prometheus 数据模型对齐：Counter（只增）、Gauge（可增减）、Histogram（桶分布）、Timer（基于 Histogram 的持续时间）、Summary（分位数）
- `IMetric` 接口统一，所有指标支持 `ToJSON`/`ToPrometheus`/`ToInfluxLine` 三种导出格式
- `TMetricsRegistry` 提供类型安全的工厂方法（Counter/Gauge/Histogram/Timer/Summary），自动注册
- `TMetricFamily<T>` 支持按标签变体创建同族指标（如 `http_requests_total{method="GET"}`, `http_requests_total{method="POST"}`），行 1280-1313
- Histogram 支持自定义桶、默认桶（行 921-923）、线性桶、指数桶（行 926-947），桶自动排序并追加 +Inf
- Timer 提供 `Start` 返回 `TProc` 停止器（行 966-989），支持 `begin/finally end` 模式
- `IScopedTimer` 接口（行 348-362）支持 RAII 风格计时
- 全局 `TMetrics` 类提供便捷访问（`TMetrics.Counter('name').Inc`）
- 所有读写操作都有 `TCriticalSection` 保护，线程安全

**已知问题/风险**：

1. **[中等] Summary 分位数计算粗糙**：行 1089-1113，使用 `TList<Double>` 存储所有观测值，超限时删除前半部分（行 1101-1102）。这种方式：(a) 删除旧数据导致分位数计算偏差；(b) `FValues.Delete(0)` 是 O(n) 操作（TList 前移）；(c) 分位数通过排序后索引取值（行 1142），无插值，精度差。应改为 t-digest 或 GK 算法。
2. **[中等] Histogram 桶计数使用 `System.Inc`**（行 740, 751）而非 `TInterlocked.Increment`。虽然在锁内调用，但与 Counter 的 `FValue := FValue + AAmount`（行 559）风格不一致。如果将来重构移除锁，会导致竞态。
3. **[中等] Prometheus 导出格式中 `_bucket` 后缀的 le 标签处理**：行 891-899，当有 Labels 时，使用 `Copy(LabelsToPrometheus, 1, Length-1)` 去掉尾部 `}` 再加逗号。这种字符串操作脆弱，如果 Labels 为空或格式变化会出错。
4. **[低] 无 push gateway 支持**：只有 pull 模式（ToPrometheus/ToJSON 等），不支持主动推送到 Prometheus Pushgateway 或远程写入。
5. **[低] 无指标过期/TTL 机制**：注册的指标永久存在，如果标签基数膨胀（如每个请求一个唯一 label），内存无限增长。

**改进建议**：
- 将 Summary 实现替换为 t-digest 算法，提供有界内存 + 准确分位数
- 增加 Push Gateway 导出器
- 增加指标 TTL 支持（如 5 分钟无更新自动注销）
- 统一使用 `TInterlocked` 原子操作（即使当前在锁内）

---

## 弹性/可靠性子系统评估

**综合评分：8/10**

弹性子系统（CircuitBreaker + RateLimiter + Scheduler）是本项目中设计质量最高的模块之一。三个组件协同覆盖了微服务可靠性的核心场景：

| 场景 | 覆盖度 |
|------|--------|
| 故障隔离（熔断） | 完整，三态机 + HalfOpen 探测限制 |
| 流量控制（限流） | 完整，四种算法 + 多维度 Key |
| 重试退避 | 完整，指数退避 + 上限截断 |
| 超时保护 | 完整，CircuitBreaker.Execute 集成 TTimeoutPolicy |
| 任务调度 | 完整，Cron + 依赖 + 持久化 + 优雅停机 |
| 分布式限流 | **缺失**，仅进程内限流 |
| 熔断器联动 | **缺失**，不自动集成 Metrics |

主要风险是 RateLimiter 的内存膨胀问题（无 Key 淘汰）和时钟依赖（TDateTime 非单调）。

---

## 网络层评估

**综合评分：5/10**

网络层是本项目最薄弱的环节。核心问题：

1. **WebSocket 空壳**：整个 `TWebSocketClient` 无一行实际网络代码，但 API 表面完整，容易误导使用者
2. **ICS 传输未实现**：`TDeepBaseIcsHttpTransport.Send` 直接 raise，仓库内无实现单元
3. **伪流式传输**：`SendStreaming` 先缓冲完整响应再拆 SSE，TTFT 等于全响应延迟
4. **连接不复用**：每次请求新建 `THTTPClient`，HTTP Keep-Alive 失效
5. **HTTP 服务器缺少生产加固**：无请求体大小限制、无连接数控制、无 graceful shutdown

HTTP 客户端的 Fluent API 设计和 SSRF/Header 注入防护是亮点，但功能完整性不足以支撑生产环境的网络通信需求。

---

## 优先级排序的改进建议（Top 5）

### P0 - 立即修复

1. **WebSocket 空壳应 raise 而非静默假装成功**
   - 文件：`Features/DeepBase.Net.pas` 行 898-952
   - 影响：当前 Connect 成功但 Send 无效果，数据静默丢失
   - 方案：要么实现真正的 WebSocket（基于 Indy TIdWebSocket 或 Overbyte ICS），要么在 Connect 时 raise `ENetException.Create('WebSocket client is not yet implemented')`

2. **HTTP 服务器增加请求体大小限制**
   - 文件：`Features/DeepBase.HttpServer.pas` 行 1253-1261
   - 影响：无限制读取 POST body 可被 OOM 攻击
   - 方案：在 `ProcessRequest` 中检查 `ARequestInfo.ContentLength`，超过阈值（默认 10MB）返回 413

### P1 - 短期改进

3. **实现真正的流式 HTTP 传输**
   - 文件：`Core/DeepBase.Net.Transport.pas` 行 294-352
   - 影响：LLM 流式响应场景下 TTFT 等于完整延迟
   - 方案：使用 `THTTPClient` 的 `BeginGet` + `OnReceiveData` 事件实现分块接收，或切换到基于 TCP Socket 的 SSE 解析

4. **RateLimiter 增加 Key 过期清理**
   - 文件：`Core/DeepBase.RateLimiter.pas` 所有四种算法
   - 影响：高基数 Key 场景下内存无限增长
   - 方案：在 `TryAcquire` 中增��过期检查，或启动后台线程定期清理超过 2 个窗口期无活动的 Key

### P2 - 中期完善

5. **HTTP 连接池/客户端复用**
   - 文件：`Features/DeepBase.Net.pas` 行 568、`Core/DeepBase.Net.Transport.pas` 行 189
   - 影响：每次请求新建 THTTPClient，TCP+TLS 握手开销大
   - 方案：维护 per-host 的 THTTPClient 池，设置 `ConnectionTimeout` 和 `MaxConnections`
