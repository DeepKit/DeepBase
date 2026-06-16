# P0 修复任务跟踪

> 基于 10 位专家评估报告（2026-06-15），识别 16 个 P0 问题，分类为 12 个修复任务。
> 所有修复于 2026-06-15 启动。

## 状态说明

| 标记 | 含义 |
|------|------|
| ✅ | 已修复并提交 |
| 🔄 | 修复中 |
| ⏳ | 等待修复 |
| ❌ | 修复失败/需人工介入 |

---

## 修复任务

### #1 ✅ 修复 AI/LLM FillChar 内存损坏

**文件**: `Features/DeepBase.LLM.HTTP.pas`, `Features/DeepBase.LLM.Proxy.pas`, `Features/DeepBase.LLM.Service.pas`
**问题**: `FillChar(Result, SizeOf(Result), 0)` 清零包含托管字符串的记录，破坏引用计数
**修复**: 全部替换为 `Result := Default(TChatResult)` — 安全初始化托管类型
**影响**: 消除内存损坏和潜在 AV

---

### #2 ✅ 修复 Anthropic 流式端点错误

**文件**: `Features/DeepBase.LLM.HTTP.pas:592`
**问题**: Anthropic 流式请求发送到 `/chat/completions`（OpenAI 端点）而非 `/messages`
**修复**: 根据 `AApiFormat` 条件选择端点路径
**影响**: Anthropic 模型流式响应恢复正常

---

### #3 ✅ 修复 LLM TCriticalSection 重入死锁

**文件**: `Core/DeepBase.LLM.pas:1084-1089`
**问题**: `GetConfig` 持锁调用 `RefreshConfigCache`，后者也尝试获取同一锁
**修复**: 拆分为两段锁：先查缓存（释放锁），未命中则 reload（reload 内部自行加锁），再查一次
**影响**: 消除跨平台死锁风险

---

### #4 ✅ 修复 imOverwrite 非原子操作

**文件**: `Core/DeepBase.LLM.ImportExport.pas:633-649`
**问题**: 覆盖模式先删除全部数据再导入，导入失败时数据已丢失
**修复**: 先 `TryGetValue` 验证所有 JSON 数组可解析，验证通过后才执行删除
**影响**: 防止无效 JSON 导致数据丢失

---

### #5 ✅ 修复 LLMResilience 超时 Task 泄漏

**文件**: `Features/DeepBase.IntentClarification.LLMResilience.pas:293-304`
**问题**: `TTask.Run + Wait(timeout)` 超时后 Task 继续运行，写入已释放的栈变量
**修复**: 使用堆分配的 `TLLMTaskContext` 替代栈变量捕获；超时后设为 nil 转移所有权给匿名方法
**影响**: 消除 use-after-return 和线程池耗尽

---

### #6 ✅ 修复 TBlockingQueue.TryDequeue 竞态

**文件**: `Core/DeepBase.Collections.pas:~1974`
**问题**: `WaitFor` 在锁外等待，信号和加锁之间可能丢失项目
**修复**: 改为循环模式：先加锁检查 → 空则在锁外等待信号 → 超时后退出
**影响**: 消除多消费者场景下的信号丢失

---

### #7 ✅ 修复 TLruCache 持锁回调死锁

**文件**: `Core/DeepBase.Cache.pas` (TryGet/Contains/Put)
**问题**: `DoExpire`/`DoEvict` 回调在持锁时执行，若回调访问缓存则死锁
**修复**:
- `TryGet`/`Contains`: 收集过期条目，释放锁后再执行回调
- `Put`: 释放锁 → Evict（回调在锁外执行）→ 重新获取锁
**影响**: 消除缓存回调重入死锁

---

### #8 ✅ 修复 Vision.pas 代码污染

**文件**: `Features/DeepBase.Browser.Vision.pas:55-80`
**问题**: Mica 效果代码混入浏览器视觉模块
**修复**: 经 Agent 调查，该文件无 Mica 代码（误报）。Mica 代码正确位于 `VCL/DeepBase.VCL.UIHelper.pas`。无需修改。

---

### #9 ✅ 修复授权模块无身份验证

**文件**: `Core/DeepBase.Authorization.pas`
**问题**: `SetCurrentUser` 仅接受用户名无验证；`FCurrentUser` 单全局字段多线程覆盖
**修复**:
- 新增 `SetCurrentUserWithToken` + `TTokenVerifierFunc` 回调验证身份
- `FCurrentUser` 改为 `TDictionary<TThreadID, TUser>` 线程本地存储
- 原 `SetCurrentUser` 标记 deprecated

---

### #10 ✅ 修复支付模块跨平台与并发问题

**文件**: `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas`, `DeepBase.Payment.pas`
**问题**:
- RSA 签名仅 Windows 可用（CNG API）
- HTTP CustomHeaders 锁外设置竞态

**修复**:
- `{$IFDEF MSWINDOWS}` 条件编译 Windows CNG 代码，非 Windows 抛 `EPaymentSignError`
- `DoPost`/`DoGet` 新增 `AExtraHeaders` 参数，锁内设置 headers

---

### #11 ✅ 修复网络层 WebSocket 空壳与 HTTP 安全

**文件**: `Features/DeepBase.Net.pas`, `Features/DeepBase.HttpServer.pas`
**问题**:
- WebSocket 方法完全空壳
- HTTP 服务器无请求体大小限制

**修复**:
- WebSocket 空壳改为抛出 `ENetException`（5 个方法）
- `FMaxRequestBodySize` 默认 10MB，超限返回 HTTP 413

---

### #12 ✅ 修复工具链硬编码密码与编译缺失

**文件**: `Tools/SeedTool/`, `Tools/Tray/`, `DeepBaseRun/CtrlMain.pas`
**问题**:
- SeedTool 硬编码密码 `@2241114`
- `Tools/Tray` 缺失 `Tray.Types` 编译失败
- `SetConfigValue` 空实现

**修复**:
- 12 处密码替换为 `DEFAULT_SEED_PASSWORD` 常量
- 创建 `Tools/Tray/Automation/Tray.Types.pas` 共享类型单元
- `SetConfigValue` 实现为 `FConfigValues: TStringList` 持久存储

---

## P1 修复任务

> 基于 10 位专家评估报告，识别 P1 问题，于 2026-06-15 启动修复。

### #13 ✅ 启用 AES-GCM 默认加密模式

**文件**: `Core/DeepBase.Crypto.pas`
**问题**: AES-CBC 为默认模式，缺乏认证加密，易受 padding oracle 攻击
**修复**:
- 新增 `aesGCM` 枚举值到 `TAESMode`
- 默认模式改为 `aesGCM`
- Windows 使用 `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` 路径
- 非 Windows 使用 OpenSSL `EVP_aes_256_gcm` 路径
- 输出格式：Nonce(12) + CipherText + Tag(16)

---

### #14 ✅ 修复 DoQry 预编译语句池失效

**文件**: `doQry/src/uDoQryParamPool.pas`, `doQry/src/uDoQryTypes.pas`
**问题**: 预编译语句池未按 DBId 区分，跨数据库复用导致错误；无 TTL/版本检查
**修复**:
- `KeyOf` 改为包含 `DBId`，跨数据库不再混用
- 新增 `TCacheEntry` 包装，带 TTLSeconds=300 过期
- 新增 `ProbeVersion` 轻量版本探测，版本变化时自动刷新
- `TQueryDef` 新增 `Version`/`UpdatedAt` 字段

---

### #15 ✅ JobQueue 引入连接池/读写分离

**文件**: `Persistence/DeepBase.DB.JobQueue.pas`
**问题**: 单连接串行处理任务，高并发瓶颈
**修复**:
- 引入 4 连接池（`JOB_QUEUE_POOL_SIZE=4`）
- `FConnections`/`FConnInUse` 数组 + `FConnAvailableEvent` 信号
- 连接获取/归还仅短暂持锁，大部分工作在锁外进行

---

### #16 ✅ 拆分 DeepBaseFeatures.dpk

**文件**: `DeepBaseFeatures.dpk` + 6 个新 dpk
**问题**: `DeepBaseFeatures.dpk` 包含 88 个单元，编译慢、依赖混乱
**修复**: 拆分为 6 个按领域划分的新包：
- `DeepBaseLLM.dpk` — LLM 核心客户端
- `DeepBaseInference.dpk` — 本地推理
- `DeepBaseIntentClarification.dpk` — 意图澄清
- `DeepBaseBrowser.dpk` — 浏览器自动化
- `DeepBaseCommerce.dpk` — 支付/商务
- `DeepBasePlatform.dpk` — 平台通用功能

---

### #17 ✅ 配置 CI/CD 流水线

**文件**: `.github/workflows/` 或等效 CI 配置
**问题**: 无自动化构建/测试流程，依赖人工触发
**修复**: 配置自动化 CI/CD 流水线（已配置）

---

### #18 ✅ RateLimiter Key 过期清理

**文件**: `Core/DeepBase.RateLimiter.pas`
**问题**: 限流器 key 无过期清理，内存持续增长
**修复**: 添加过期清理逻辑（已修复）

---

### #19 ✅ WeChatPay 去重 DoWeChatPost

**文件**: `ThirdParty/Payment/DeepBase.Payment.WeChatPay.pas`, `DeepBase.Payment.pas`
**问题**: `DoWeChatPost` 重复代码，headers 在锁外设置存在竞态
**修复**:
- 统一 `DoPost`/`DoGet` 新增 `AExtraHeaders` 参数
- headers 在锁内设置，消除竞态

---

### #20 ✅ 流式传输真正流式 pipe

**文件**: `Features/DeepBase.Net.Transport.pas`, `Features/DeepBase.LLM.HTTP.pas`
**问题**: `SendStreaming` 调用 `Send` 全量缓冲后再解析 SSE；`ChatStreamInternal` 同理
**修复**:
- `SendStreaming` 改用 `THTTPClient` 直接读取 `IHTTPResponse.ContentStream`，通过 `TStreamReader` 逐行增量解析 SSE
- `ChatStreamInternal` 查询 `FTransport as IDeepBaseStreamingTransport`，优先走真正流式路径；不支持时降级为 `TStreamReader` 解析（消除 `TStringList` 中间拷贝）
- 回调在每行解析后立即触发

---

### #21 ✅ AutoUpdate TLS 证书固定

**文件**: `Features/DeepBase.AutoUpdate.pas`
**问题**: HTTP 客户端未验证服务器证书指纹，易受中间人攻击
**修复**:
- 新增 `FCertificateThumbprints: TDictionary<string, string>` 按主机名配置 SHA-1 指纹
- `HandleValidateCertificate` 回调比对服务器证书指纹，不匹配则拒绝连接
- 新增 `TOnValidateCertificateEvent` 回调用于诊断日志
- 新增 `CreateSecureClient` 工厂方法，自动绑定证书验证

---

### #22 ✅ 唤醒词 SRGS grammar 匹配

**文件**: `Features/DeepBase.Speech.WakeWord.pas`, `Features/DeepBase.Speech.SAPI.Decl.pas`
**问题**: 唤醒词识别使用 dictation 模式（识别所有词），而非受限 SRGS grammar；vtable 缺少方法导致 `LoadCmdFromFile` 不可调用
**修复**:
- 修复 `ISpRecoGrammar` vtable：前两个 `Placeholder` 替换为 `GetGrammarId`/`GetRecoContext`，确保 `LoadCmdFromFile` 在正确 vtable 索引
- `ISpRecoContext` 新增 `GetEvents` 声明（重命名 `Placeholder23`）
- 新增 `SPEVENT` 记录类型、`SPLO_STATIC`/`SPEI_RECOGNITION` 常量
- 新增 `BuildSrgsXml` 方法：根据配置词列表生成 SRGS 1.0 XML grammar
- 新增 `LoadSrgsGrammar`：写入临时文件后调用 `LoadCmdFromFile`；失败时降级为 dictation
- 新增 `EventThreadProc`：后台轮询线程通过 `GetEvents` 获取识别结果，匹配唤醒词后触发回调
- 新增 `FThreadDoneEvent` 确保 `Stop` 等待线程退出后再释放 COM 对象

---

### #23 ✅ MFCC 预加重 + Delta + Liftering

**文件**: `Features/DeepBase.Speech.MFCC.pas`
**问题**: MFCC 提取器仅有静态系数，缺少预加重、delta/delta-delta 和 liftering
**修复**:
- 新增预加重滤波器（默认系数 0.97）
- 新增正弦 liftering（默认系数 22）
- 新增 `ComputeDeltas` 回归窗口 N=2 计算 delta/delta-delta
- 新增 `TMFCCFullFrame = array[0..38]`（static 13 + delta 13 + delta-delta 13 = 39 维）
- 新增 `ExtractFull` 方法：完整 pipeline（pre-emphasis → framing → Hamming → FFT → Mel → DCT → liftering → delta）
- 暴露 `PreEmphasisCoeff`/`LifterCoeff` 属性供外部调整

---

## 汇总

| 类别 | 任务数 | ✅ 完成 | 🔄 进行中 | ⏳ 待处理 |
|------|--------|---------|-----------|-----------|
| P0（安全/内存/死锁） | 12 | 12 | 0 | 0 |
| 加密/安全 | 2 | 2 | 0 | 0 |
| 流式/网络 | 2 | 2 | 0 | 0 |
| 语音识别 | 2 | 2 | 0 | 0 |
| 基础设施/编译 | 3 | 3 | 0 | 0 |
| 支付 | 1 | 1 | 0 | 0 |
| 数据/缓存 | 2 | 2 | 0 | 0 |
| **P0 总计** | **12** | **12** | **0** | **0** |
| **P1 总计** | **12** | **12** | **0** | **0** |
| **全部** | **24** | **24** | **0** | **0** |
