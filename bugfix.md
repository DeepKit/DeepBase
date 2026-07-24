# DeepBase Bug Fixes & Issues Resolution

> 本文档记录所有发现和修复的 Bug、Issue 及改进。
> **分卷**: 本卷 = 近期修复 (REVIEW5 第一轮五专家 + R2 第二轮 P0/P1 + R3 第三轮 + 06-21~28 OPT/EXP 审阅)。早期修复 (2025-11~12 Issues/性能/统计、2026-05 基础模块/Commerce 审计、06-18 三专家) 见 `bugfix-archive.md`。

---

## 2026-07-24 PERCEPT-WYJX-P3/P4 代码质量问题

### BUG-WYJX-001: CDP.Adapter.pas 类名包含空格导致编译失败 ⏸️
- 发现日期: 2026-07-24
- 严重性: Critical (编译失败)
- 来源: PERCEPT-WYJX-P4 代码审查
- 文件: Features/DeepBase.Browser.CDP.Adapter.pas
- 问题:
  - 类名 `TC DPWebSocketSession` 包含空格 (应为 `TCDPWebSocketSession`)
  - Delphi 编译器会报 "E2003 Undeclared identifier" 或 "E2029 Declaration syntax error"
- 修复:
  - 将 `TC DPWebSocketSession` 改为 `TCDPWebSocketSession`
  - 更新所有引用该类的代码
- 状态: **待修复** (2026-07-24)

---

### BUG-WYJX-002: DPIMapper.pas 参数名拼写错误 ⏸️
- 发现日期: 2026-07-24
- 严重性: Medium (逻辑错误)
- 来源: PERCEPT-WYJX-P3 代码审查
- 文件: Features/DeepBase.Desktop.Screen.Click.DPIMapper.pas
- 问题:
  - 参数名 `RelRelY` 应为 `RelativeY`
  - 可能导致坐标映射计算错误
- 修复:
  - 将 `RelRelY` 改为 `RelativeY`
  - 更新所有使用该参数的代码
- 状态: **待修复** (2026-07-24)

---

### BUG-WYJX-003: 部分 TODO 方法未实现 ⏸️
- 发现日期: 2026-07-24
- 严重性: Low (功能不完整)
- 来源: PERCEPT-WYJX-P3/P4 代码审查
- 文件: 多个文件
- 问题:
  - RegionLocator.pas: FindAllTemplates 方法标记为 TODO
  - SmartExecutor.pas: WaitForTargetToAppear 方法标记为 TODO
  - CDP.Adapter.pas: EnableNetworkInterception 方法标记为 TODO
  - Recorder.pas: ExportAllSessionsToDirectory 方法标记为 TODO
- 修复:
  - 实现所有标记为 TODO 的方法
  - 添加相应的单元测试
- 状态: **待修复** (2026-07-24)

---

### BUG-WYJX-004: 缺少 TMonitorHandle 类型定义 ⏸️
- 发现日期: 2026-07-24
- 严重性: Critical (编译失败)
- 来源: PERCEPT-WYJX-P3 代码审查
- 文件: Features/DeepBase.Desktop.Screen.Click.DPIMapper.pas
- 问题:
  - 使用了 `TMonitorHandle` 类型但未定义
  - 编译器会报 "E2003 Undeclared identifier: 'TMonitorHandle'"
- 修复:
  - 添加类型定义: `TMonitorHandle = type THandle;`
  - 或使用 Windows 单元中的 `HMONITOR` 类型
- 状态: **待修复** (2026-07-24)

---

## 2026-07-06 REVIEW5-R2 第二轮五专家审阅 P0 修复

### BUG-367: DeepBaseDataPlatform.dpk 重复包含 WeChat4x 导致 E2065 ✅
- 发现日期: 2026-07-06
- 严重性: Critical (编译失败)
- 来源: 第二轮审阅 UI2-001 (专家 E)
- 文件: DeepBaseDataPlatform.dpk, DeepBaseCore.dpk
- 问题:
  - `DeepBase.SchemaAdapter.WeChat4x` 同时出现在 `DeepBaseCore.dpk` (L104) 和 `DeepBaseDataPlatform.dpk` (L39)
  - 两个运行时包同时加载时编译器报 "E2065 duplicate unit" 或链接器重复符号错误
- 修复:
  - 从 `DeepBaseDataPlatform.dpk` 中移除 WeChat4x 条目 (DeepBaseCore 已包含 WeChat39x/WeChat4x 完整适配器集)
- 状态: 已修复 (2026-07-06)

---

### BUG-368: FMX LLMChatFrame.DoSendMessage 后台线程无引用, 析构后悬垂 ✅
- 发现日期: 2026-07-06
- 严重性: Critical (use-after-free)
- 来��: 第二轮审阅 UI2-002 (专家 E)
- 文件: FMX/DeepBase.FMX.LLMChatFrame.pas
- 问题:
  - `DoSendMessage` 启动 `TThread.CreateAnonymousThread(...).Start`, 但从未将线程赋值给 `FCurrentTask: ITask`
  - 析构函数中 `if Assigned(FCurrentTask) then FCurrentTask.WaitFor(2000)` 始终为 false, 无法等待后台线程
  - 用户在生成中关闭 Frame, 后台线程继续访问已释放的 `FHistory`/`FClient`/`FMemoChat`/`FChatItems`, 导致 AV
- 修复:
  - 改用 `FCurrentTask := TTask.Run(...)` 启动后台任务, `TTask.Run` 立即启动并返回 `ITask` 引用
  - 移除多余的 `.Start` 调用 (TTask.Run 内部已启动)
  - 析构函数的 WaitFor 现在能真正生效
- 状态: 已修复 (2026-07-06)

---

### BUG-369: VCL FeedbackDialog.SubmitFeedback 每次提交泄漏 TStringStream ✅
- 发现日期: 2026-07-06
- 严重性: Critical (资源泄漏)
- 来源: 第二轮审阅 UI2-003 (专家 E)
- 文件: VCL/DeepBase.VCL.FeedbackDialog.pas
- 问题:
  - `Client.Post(FFeedbackUrl, TStringStream.Create(JsonObj.ToString, TEncoding.UTF8))` 内联创建 TStringStream
  - `THTTPClient.Post` 不接管 ASource 流的所有权, 调用方负责释放
  - 每次反馈提交泄漏一个 TStringStream (数十到数百字节), 长时间运行累积
- 修复:
  - 新增局部变量 `Body: TStringStream`, 创建后通过 `try/finally Body.Free` 确保释放
- 状态: 已修复 (2026-07-06)

---

### BUG-363: Benchmark.pas GenerateJSON 类型混淆, 调用必 AV ✅
- 发现日期: 2026-07-06
- 严重性: Critical (崩溃)
- 来源: 第二轮审阅 CORE-R2-001 (专家 A)
- 文件: Core/DeepBase.Benchmark.pas
- 问题:
  - `TBenchmarkReport.GenerateJSON` 将 `ResultsArr` 声明为 `TJSONObject`, 但在 L669 通过 `TJSONArray(ResultsArr).Add(...)` 强转为 `TJSONArray`
  - `TJSONObject` 与 `TJSONArray` 无继承关系, 强转后调用虚方法表会立即 AV
  - 影响所有调用 `GenerateJSON` 的代码路径
- 修复:
  - 将 `ResultsArr` 声明类型改为 `TJSONArray`, 创建调用改为 `TJSONArray.Create`
  - 移除 L669 的 `TJSONArray(ResultsArr)` 类型转换
- 状态: 已修复 (2026-07-06)

---

### BUG-364: Crypto.pas DecryptBytes 旧版 CBC 数据在 GCM 升级后不可解密 ✅
- 发现日期: 2026-07-06
- 严重性: Critical (数据损坏/丢失)
- 来源: 第二轮审阅 CORE-R2-002 (专家 A)
- 文件: Core/DeepBase.Crypto.pas
- 问题:
  - `TSimpleCrypto.DecryptBytes` 在 v1 格式和 legacy 格式路径上创建 `TAESCrypto.Create(aes256, aesGCM)`, 用 GCM 模式解密
  - 但 v1/legacy 数据实际由 AES-CBC 加密, GCM 模式期望的输入格式为 `Nonce(12) + CipherText + Tag(16)`, 与 CBC 密文不兼容
  - 短密文触发 "Invalid GCM ciphertext length" 异常, 长密文被错误解析导致解密失败
  - 升级 GCM 后, 所有旧版加密数据永久不可解密
- 修复:
  - 引入 `LUseGCM` 标志, 仅 v2 (`SIMPLE_CRYPTO_VERSION`) 路径使用 GCM 模式
  - v1 (`SIMPLE_CRYPTO_VERSION_V1`) 和 legacy (无 header) 路径改用 `aesCBC` 模式
  - 16 字节 IV 在两种模式下都能被 `SetIV` 正确处理
- 状态: 已修复 (2026-07-06)

---

### BUG-365: ORM.pas OrderBy/OrderByDesc 列名直接拼接, SQL 注入风险 ✅
- 发现日期: 2026-07-06
- 严重性: Critical (安全)
- 来源: 第二轮审阅 DATA2-001/DATA2-002 (专家 D)
- 文件: Persistence/DeepBase.ORM.pas
- 问题:
  - `TQueryBuilder<T>.OrderBy(Column)` 和 `OrderByDesc(Column)` 直接将用户提供的字符串拼接进 SQL, 无任何校验
  - 攻击者可传入 `'; DROP TABLE users;--` 等字符串导致 SQL 注入
  - Where/AndWhere/OrWhere 的单字符串重载也有同类问题 (已加注释警告, 推荐参数化版本)
- 修复:
  - 新增单元级 `ValidateSQLIdentifier` 函数, 校验标识符只含字母/数字/下划线/点, 拒绝引号/空格/操作符等
  - OrderBy/OrderByDesc 调用前先验证, 非法标识符抛出 `EORMException`
  - Where/AndWhere/OrWhere 的单字符串重载添加文档警告, 推荐使用参数化版本
- 状态: 已修复 (2026-07-06)

---

### BUG-366: BCryptDecrypt 密钥析构未清零 + 临时文件路径可预测 ✅
- 发现日期: 2026-07-06
- 严重性: Critical (密钥泄漏 / 本地攻击)
- 来源: 第二轮审阅 DATA2-003/DATA2-004 (专家 D)
- 文件: DeepAxis/DeepBase.External.BCryptDecrypt.pas
- 问题:
  - `TBCryptSQLiteReader.Destroy` 未对 `FAesKey` / `FMacKey` 清零, 内存中密钥残留直到页被覆写
  - `TPath.GetTempFileName` 创建的文件名是顺序递增的, 本地攻击者可预测并抢先占用或窃取解密后的 SQLite 副本
- 修复:
  - `Destroy` 中 `FillChar(FAesKey/FMacKey, 0)` 后 `:= nil`
  - `Create` 改用 `BCryptGenRandom` (Windows 10 1903+) 或 `RtlGenRandom` 回退生成 128 位随机文件名, 前缀 `dbsr_` 避免与用户临时文件混淆
  - `Destroy` 中先覆写文件内容 4KB 块再删除 (best-effort, 现代 FS 不能保证���理擦除)
  - 新增 `BCryptGenRandom` / `RtlGenRandom` 外部声明
- 状态: 已修复 (2026-07-06)

---

## 2026-07-06 REVIEW5-R2 P0 补录 (DATA2-005 / DATA2-006)

> 第二轮审阅中 DATA2-005 / DATA2-006 两项 P0 已在代码中修复并标注, 但此前未在 bugfix.md 补录独立 BUG 条目, 现补录归档。审阅编号沿用原报告编号, 不另起 BUG 序号。

### DATA2-005: EvidenceStore.SQLite 证据链无防篡改哈希链 ✅
- 发现日期: 2026-07-06 (专家 D, DATA2-005)
- 严重性: High (治理/防篡改)
- 文件: Governance/DeepBase.Governance.EvidenceStore.SQLite.pas
- 问题: 证据存储每行仅落盘业务字段, 无 prev_hash / this_hash 哈希链, 攻击者可任意篡改/插入/删除历史证据行而不被发现, 治理审计链不可信。
- 修复:
  - schema 新增 `prev_hash` / `this_hash` 两列 (ALTER TABLE 幂等迁移, 见 MigrateHashColumns)
  - `this_hash = HMAC-SHA256(FHmacKey, timestamp || payload || prev_hash)`, 密钥为空时回退 SHA-256
  - Save 写入时取链尾 `FLastChainHash` 作为本行 prev_hash, 计算并写入 this_hash, 推进链尾
  - `MigrateExistingChain` 为旧表逐行回填哈希链, `VerifyChain` 遍历全表校验每行 this_hash == 重算值
  - 创世哈希 `GENESIS_HASH` 作为首行 prev_hash
- 状态: 已修复 (2026-07-06)

### DATA2-006: EvidenceRecorder.PushItem 返回值丢弃致队列溢出时证据静默丢失 ✅
- 发现日期: 2026-07-06 (专家 D, DATA2-006)
- 严重性: High (可靠性/治理)
- 文件: Governance/DeepBase.Governance.EvidenceRecorder.pas
- 问题: `FQueue.PushItem(AEntry)` 返回值被忽略, 当证据队列满 (默认上限) 时 PushItem 返回 wrTimeout/wrFailed, 证据被静默丢弃, 治理审计出现缺口且无任何告警或重试。
- 修复:
  - 入队时检查 `PushItem` 返回值, 失败按指数退避重试 (100/200/400 ms, 见 SaveWithRetry 同模式)
  - 所有重试耗尽后证据落入 `FFailureQueue` 备份队列, 不再静默丢弃
  - 新增 `FDroppedCount` 字段统计因队列满且重试耗尽而丢弃的证据总数, 供监控暴露
- 状态: 已修复 (2026-07-06)

---

## 2026-06-30 REVIEW5-FEAT-006 LLM HTTP 200 Error Envelope 错误解析

### BUG-344: LLM HTTP 客户端未检查 HTTP 200 响应中的 error envelope ✅
- 发现日期: 2026-06-30
- 严重性: Medium (错误处理)
- 文件: Features/DeepBase.LLM.HTTP.pas、Tests/Test.DeepBase.LLM.pas
- 问题:
  - `ParseOpenAIResponse` 和 `ParseAnthropicResponse` 直接尝试解析 content/choices
  - 未检查 HTTP 200 响应中的 error 对象
  - 导致 API 返回错误时，客户端返回空结果而非错误信息
- 修复:
  - `ParseOpenAIResponse`: 在解析 choices 之前检查 error 对象，提取 message 和 code
  - `ParseAnthropicResponse`: 在解析 content 之前检查 error 对象，提取 message 和 type
  - 新增 `TLLMHttpErrorEnvelopeTests` 测试夹具 (4 个测试)
- 测试: 使用 `TFakeLLMTransport` 注入伪造 HTTP 响应，验证 error envelope 和正常响应解析
- 状态: 已修复

---

## 2026-06-30 REVIEW5-FEAT-005 HttpServer 静态文件服务路径遍历防护测试

### BUG-343: HttpServer 静态文件服务缺少路径遍历防护测试覆盖 ✅
- 发现日期: 2026-06-30
- 严重性: Medium (安全)
- 文件: Features/DeepBase.HttpServer.pas、Tests/Test.DeepBase.HttpServer.pas
- 问题:
  - `TStaticFileMiddleware` 已实现基本路径遍历防护 (canonical root 校验 + startsWith 检查)
  - 但缺少测试覆盖, 无法验证防护机制的正确性和完整性
- 修复:
  - 验证现有实现已包含路径遍历防护
  - 新增 `TTestStaticFilePathTraversal` 测试夹具 (6 个测试)
  - 覆盖有效路径、`..` 遍历、URL 编码遍历、绝对路径、反斜杠路径、canonical root 验证
- 测试: 6 测试全绿, 编译通过
- 状态: 已修复

---

## 2026-06-30 REVIEW5-FEAT-004 CloudSync 默认加密无 key 时 fail-closed 验证

### BUG-342: CloudSync 默认配置加密启用但密钥为空, 需 fail-closed 阻止明文上传 ✅
- 发现日期: 2026-06-30
- 严重性: High (敏感信息泄露风险)
- 文件: Features/DeepBase.CloudSync.pas、Tests/Test.DeepBase.CloudSync.pas
- 问题: 默认配置 `EnableEncryption := True` 但 `EncryptionKey := ''`。若 fail-closed 检查缺失, 使用默认配置的应用会在无密钥情况下明文上传配置数据到云端
- 修复:
  - 已有 fail-closed 检查: `EncryptData`/`DecryptData` 在 `EncryptionKey = ''` 时抛出异常
  - `EncryptData`/`DecryptData` 从 private 改为 public, 允许直接测试
  - 新增 `TTestEncryptionFailClosed` 测试夹具 (6 个测试)
- 测试: 覆盖默认配置验证、空密钥异常、有效密钥加解密、往返一致性
- 状态: 已修复

---

## 2026-06-30 REVIEW5-FEAT-003 AutoUpdate HTTP 超时与完整性强制校验

### BUG-341: AutoUpdate 无 HTTP 超时且下载完整性可选, 生产包可被篡改 ✅
- 发现日期: 2026-06-30
- 严重性: High (安全/可用性)
- 文件: Features/DeepBase.AutoUpdate.pas、Tests/Test.DeepBase.AutoUpdate.pas
- 问题:
  1. `CreateHttpClient` 未配置 `ConnectionTimeout`/`ResponseTimeout`, 慢速或挂起的服务器导致 `CheckForUpdate`/`DownloadUpdate` 无限期阻塞
  2. `DownloadUpdate` 中 SHA256 校验仅在 `Info.Sha256 <> ''` 时执行; 无 SHA256 时直接跳过验证, 无法检测篡改
- 修复:
  - 新增 `FConnectionTimeout`/`FResponseTimeout` 字段 (默认 30s/60s) 和公共属性
  - `CreateHttpClient` 从 class function 改为 instance function, 应用配置的超时值
  - `TUpdateInfo` 新增 `Signature: string` 字段
  - `DownloadUpdate` 增加 fail-closed 检查: `(Info.Sha256 = '') and (Info.Signature = '')` 时设置 `FLastError` 并退出
  - JSON 解析 (新格式 + 遗留格式) 读取 `signature` 字段 (若存在)
- 测试: `TTestIntegrityEnforcement` 8 测试覆盖默认超时、可配置超时、Signature 字段、fail-closed 检查
- 状态: 已修复

---

## 2026-06-30 REVIEW5-FEAT-002 PayPal PaymentBridge 工厂缺 WebhookId 配置

### BUG-340: CreatePayPalNotificationVerifier 工厂未配置 WebhookId, verifier 永远 fail closed ✅
- 发现日期: 2026-06-30
- 严重性: High (PayPal webhook 验签不可用)
- 文件: Features/DeepBase.Commerce.PaymentBridge.pas、ThirdParty/Payment/DeepBase.Payment.PayPal.pas
- 问题: `CreatePayPalNotificationVerifier` 工厂签名仅 `AClientId`/`AClientSecret`, 不接受 `AWebhookId`, 也未赋值 `TPayPalConfig.WebhookId`。`TPayPalClient.VerifyWebhookSignature` 在 `WebhookId=''` 时抛 `EPaymentConfigError` MISSING_WEBHOOK_ID, 故工厂产出的 verifier 永远卡在缺配置错误, 无法进入实际验签
- 修复: 工厂接口 + DESKTOP stub + 服务端实现三处统一新增 `AWebhookId` 参数, 服务端 `Config.WebhookId := AWebhookId`
- 测试: `Test_VerifyWebhookSignature_MissingWebhookId_RaisesConfigError`、`Test_VerifyWebhookSignature_WithWebhookId_PassesIdGate`、`Test_Factory_WiresWebhookId_MissingConfigFailsClosed` (无网络, 空 WebhookId 在门处抛出 / 配置 WebhookId + 空凭据在 token 请求前抛出)
- 状态: 已修复

---

## 2026-06-30 REVIEW5-FEAT-001 支付配置密钥持久化二次 ProtectKey 与不稳定 key-id 修复

### BUG-339: 支付密钥 load 路径二次 ProtectKey + key-id 不稳定/字段碰撞 ✅
- 发现日期: 2026-06-30
- 严重性: High (密钥持久化失效/串密)
- 文件: ThirdParty/Payment/DeepBase.Payment.pas、DeepBase.Payment.Stripe.pas、DeepBase.Payment.Alipay.pas、DeepBase.Payment.WeChatPay.pas、DeepBase.Payment.PayPal.pas
- 问题:
  1. Stripe/Alipay/WeChatPay 的 `LoadKeysFromCredentialManager` 经 Secure setter 赋值, setter 内部再调 `ProtectKey` 把已存储密文/key-id 再保护一次, 每次 save/load 增加一层间接, 最终读回 key-id 而非明文
  2. `ProtectKey` 的 key-id 派生自 `Hex(Self)`, 跨实例不稳定 → 每次 Save 泄漏孤儿条目, 跨实例 reload 失效
  3. 因 `Hex(Self)` 对同对象所有字段相同, 同一 config 的多个受保护字段 (如 Stripe SecretKey + WebhookSecret) 写入同一 store 槽, 互相覆盖, 读回错误密钥
- 修复:
  - `ProtectKey` 签名改为 `ProtectKey(const AKeyName, APlainKey)`, key-id 改为 `FCredentialTarget + '.vault.' + AKeyName` (跨实例稳定且按字段唯一)
  - 三个 provider 的 `LoadKeysFromCredentialManager` 改为直接赋值底层字段 (与 PayPal 既有正确模式一致), 不再二次 ProtectKey
  - 4 处 Secure setter 同步传入字段名
- 测试: `Test_StripeConfig_SaveLoad_NoDoubleProtect_NoFieldCollision`、`Test_AlipayConfig_SaveLoad_RoundTripsPrivateKey` (注入 `TFakeSecretStore`); 还原修复分别复现 double-protect 与字段碰撞两种失败
- 状态: 已修复

---

## 2026-06-30 REVIEW5-DATA-008 doQry 直接 PRAGMA 白名单收紧与回归测试

### BUG-338: IsDirectSQL 对所有 PRAGMA 一律放行, 写型 PRAGMA 绕过 Queries 白名单 ✅
- 发现日期: 2026-06-30
- 严重性: Medium (安全/配置越权)
- 文件: Persistence/DeepBase.DB.DoQry.pas
- 问题:
  - `IsDirectSQL` 见 `PRAGMA` 关键字即返回 True, 不区分读型与写型
  - 写型 PRAGMA (`PRAGMA foreign_keys=ON`、`PRAGMA journal_mode=WAL`、`PRAGMA wal_checkpoint` 等) 可经 `UniDbExec` 直接修改数据库状态, 绕过 Queries 表 DBA 白名单
  - 与 DDL 强制走 Queries 表的安全模型不一致
- 修复:
  - 新增 `IsReadOnlyPragma`: 拒绝含 `=` 的赋值型 PRAGMA; 拒绝裸形式即有副作用的 pragma 名 (`wal_checkpoint`/`optimize`/`incremental_vacuum`/`shrink_memory`/`wal_flush`)
  - `IsDirectSQL` 的 PRAGMA 分支委托 `IsReadOnlyPragma`, 写型 PRAGMA 落入 Queries 表查找, 未白名单则抛 `DOQRY_ERR_QUERY_NOT_FOUND`
- 测试: `Test_DirectWritePragma_Assignment_IsBlocked`、`Test_DirectWritePragma_SideEffect_IsBlocked`、`Test_DirectReadOnlyPragma_IsAllowed`
- 状态: 已修复

---

## 2026-06-30 REVIEW5-DATA-007 预编译语句池 in-use 复用修复与回归测试

### BUG-337: prepared-statement pool 命中 in-use 条目时复用同一 TFDQuery, 并发同 SQL 串参数 ✅
- 发现日期: 2026-06-30
- 严重性: High (并发数据正确性)
- 文件: Persistence/DeepBase.DB.DoQry.pas
- 问题:
  - `GetOrCreatePreparedQuery` 命中池条目时只校验连接指针与 `Conn.Connected`, 未检查 `Entry.InUseCount`
  - 同一连接上对同 SQL 的并发/重入调用会让第二个调用者拿到**同一个正在使用的** `TFDQuery` (单一活跃游标, Params/Active 可变)
  - 两个调用者同时 `Params.ClearValues` + `BindJsonParams` + `Open` 互相覆盖绑定参数与结果集, 抛 "cannot perform this operation on an active dataset" 或读回错误参数值
- 修复:
  - 命中条目时增加 `Entry.InUseCount > 0` 守卫, 命中则不复用, 改为新建独立 `TFDQuery` (不挂入 `GPreparedQueryIndex`) 直接返回
  - `ReleaseQuery` 对未挂入索引的查询走 `Entry = nil` 兜底 `Q.Free`, 新建查询被正确释放, 不泄漏
  - `InUseCount = 0` 时行为不变, 池命中率与 `ReuseCount` 不受影响
- 测试: `Test.DeepBase.DB.DoQry.pas::Test_PreparedPool_ConcurrentSameSql_DoesNotCrossContaminateParams` (6 线程 × 25 轮, 文件型 WAL 共享连接, 还原修复后 FAIL)
- 状态: 已修复

---

## 2026-06-30 REVIEW5-DATA-006 迁移脚本 TOCTOU 修复与回归测试

### BUG-336: 迁移脚本 checksum 与执行使用两次独立读取, 存在 TOCTOU 窗口 ✅
- 发现日期: 2026-06-30
- 严重性: 🟠 Medium
- 来源: REVIEW5-DATA-006 五专家模块审阅 (Persistence)
- 影响文件: `Persistence/DeepBase.DB.Migrations.pas`, `Tests/Test.DeepBase.DB.Migrations.pas`

#### 问题
- `TMigrationEngine.Run` 原先用 `CalculateChecksum(FilePath)` 读盘算 SHA256, 随后 `ExecuteScript` 又 `ReadAllText` 重新读盘执行
- 两次读取之间存在 TOCTOU 窗口: 外部进程可在 checksum 之后、执行之前替换脚本内容
- 结果: 迁移记录中存储的 checksum 与实际执行的 DDL 不一致, 迁移历史失真, 重跑幂等性被破坏

#### 修复
- 新增 `ReadScriptLocked`: 以 `fmOpenRead or fmShareDenyWrite` 读取脚本, 返回单一快照字符串
- 新增 `CalculateChecksumFromContent`: 直接对内存内容计算 SHA256, 不再二次读盘
- `Run` 改为 `ScriptContent := ReadScriptLocked(FilePath); Checksum := CalculateChecksumFromContent(ScriptContent);`, 同一份 `ScriptContent` 同时用于 checksum 与 `ExecuteScript`
- `ExecuteScript` 签名由 `ScriptPath: string` 改为 `SQLText: string`, 接收已锁定的内容快照
- **BOM 剥离修复**: `ReadScriptLocked` 用 `TEncoding.UTF8.GetString(Bytes)` 解码原始字节, 但 `GetString` 不会剥离 UTF-8 BOM (`EF BB BF`), 导致 BOM 被拼到首条 SQL 语句前 (`<BOM>CREATE TABLE...`), `ExecSQL` 报 `near ")": syntax error`; 且 BOM 会被纳入 checksum。修复: 解码前比对 `TEncoding.UTF8.GetPreamble` 并 `Copy` 剥离 BOM, 与原 `TFile.ReadAllText(ScriptPath, TEncoding.UTF8)` 路径保持字节兼容, checksum 与已记录迁移一致。

#### 回归测试 (`Tests/Test.DeepBase.DB.Migrations.pas`)
- `Test_CalculateChecksumFromContent_MatchesStoredAppliedChecksum`: 校验 `DeepBase_schema_migrations.checksum` 等于 `THashSHA2.GetHashString(执行内容, SHA256)`, 证明存储的 checksum 与执行快照一致 (单语句脚本)
- `Test_MultiStatementScript_StoredChecksumMatchesContentSnapshot`: 含触发器的多语句脚本, 校验 checksum 仍等于内容快照的 SHA256, 且触发器正常触发, 证明 `SplitSQLStatements` 路径也使用单一一致快照

#### 验证
- runlist `Tests/runlist_bug336.txt`: 5 个测试全绿 (2 新增 + 3 既有回归)
- BOM 剥离前既有迁移测试 `Test_Run_SQLite_AppliesOnlySQLiteScriptsAndCreatesBackup` 在工作树中 FAIL (`near ")": syntax error`), 剥离后 PASS

### BUG-335: `ExecuteScript` 残留临时文件调试日志 (`dbm_debug.txt`) ✅
- 发现日期: 2026-06-30
- 严重性: 🔴 High
- 来源: REVIEW5-DATA-006 实现审查 (Persistence)
- 影响文件: `Persistence/DeepBase.DB.Migrations.pas`

#### 问题
- `TMigrationEngine.ExecuteScript` 在 REVIEW5-DATA-006 (BUG-334 同期) 实现过程中残留了调试插桩:
  - 每次执行迁移脚本都向 `%TEMP%\dbm_debug.txt` 追加日志, 永不清理
  - 记录完整 SQL 文本与拆分后的每条语句, 含事务控制判定
- 风险:
  - 生产环境敏感 DDL/SQL 明文落盘到临时目录, 信息泄露
  - 临时文件无限增长, 长期运行磁盘膨胀
  - 高频迁移下 `TFile.AppendAllText` 引入额外 I/O 与文件锁竞争

#### 修复
- 移除 `ExecuteScript` 中的 `DebugPath`/`I` 局部变量及全部 `TFile.AppendAllText` 调试日志
- 保留 REVIEW5-DATA-006 的核心修复: 同一份加锁读取的 `ScriptContent` 用于 checksum 与执行

#### 验证
- 编译通过; `TPath`/`TFile` 仍被 `BackupSQLiteDatabase` 使用, `System.IOUtils` 引用保留
- 待 runlist 回归验证 (BUG-334 测试仍覆盖裸 END 拦截与回滚完整性)

---

## 2026-06-29 REVIEW5-DATA-005 Migrations 事务控制检测

### BUG-334: 迁移脚本未拦截裸 `END`/`END TRANSACTION`, 失败脚本回滚完整性缺失 ✅
- 发现日期: 2026-06-29
- 严重性: 🟠 Medium
- 来源: REVIEW5-DATA-005 五专家模块审阅
- 文件:
  - `Persistence/DeepBase.DB.Migrations.pas`
    - `IsTransactionControlStatement`: 仅检测 `BEGIN`/`COMMIT`/`ROLLBACK`/`SAVEPOINT`/`RELEASE`, 未把 SQLite 中等同于 `COMMIT` 的裸 `END` 以及 `END TRANSACTION` 列为事务控制语句
    - `ExecuteScript`: 拆分后的语句直接 `ExecSQL`, 若事务控制语句混入脚本会破坏迁移引擎自身的事务封装
- 问题:
  - 迁移脚本可以写入 `END;` 或 `END TRANSACTION;`, 在 SQLite 上提前提交当前事务, 导致迁移记录与 DDL 状态不一致
  - 失败脚本的回滚完整性仅在 `BEGIN`/`COMMIT` 场景有测试, 裸 `END` 与部分失败后的 DDL 清理未覆盖
- 修复:
  - ✅ `IsTransactionControlStatement` 增加 `(S = 'END')` 和 `(S = 'END TRANSACTION') or StartsText('END TRANSACTION ', S)`
  - ✅ 新增 `Test_Run_SQLite_BareEndTransactionControlFails`: 验证裸 `END;` 被拦截, 且 `end_test` 表未残留
  - ✅ 新增 `Test_Run_SQLite_EndTransactionControlFails`: 验证 `END TRANSACTION;` 被拦截, 且 `endtx_test` 表未残留
  - ✅ 新增 `Test_Run_SQLite_FailedScriptLeavesDatabaseClean`: 验证脚本部分执行失败后 DDL 与迁移记录均被回滚
- 测试:
  - `Tests/Test.DeepBase.DB.Migrations.pas` (新增 3 个测试)
  - RunList: `Test.DeepBase.DB.Migrations.TTestDBMigrations.Test_Run_SQLite_BareEndTransactionControlFails`, `Test_Run_SQLite_EndTransactionControlFails`, `Test_Run_SQLite_FailedScriptLeavesDatabaseClean`
  - 全部通过, 3/3 passed, 0 failed
- 状态: 已修复

## 2026-06-29 REVIEW5-CORE-002 WorkerQueue 回调异常兜底

### BUG-324: WorkerQueue 外部回调/存储异常导致 job 卡在 jsRunning ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-CORE-002 五专家模块审阅
- 文件:
  - `Core/DeepBase.WorkerQueue.pas`
    - `TWorkerQueue.ProcessJob`: `FOnJobStarted` / `FStorage.SaveJob` 在设置 `jsRunning` 后无 try/except 保护; 若回调抛异常, job 永远停在 `jsRunning`
    - `FOnJobCompleted` / `AJob.FOnCompletion` 在 handler try 块内; 若回调抛异常, 被 except 误判为 handler 失败, 触发重试或标记 jsFailed
    - except 分支中 `FOnError` / `FOnJobRetrying` / `FOnJobFailed` / `FOnCompletion` 也可能抛异常, 掩盖原始错误并破坏状态
    - `TJob.ReportProgress`: 进度回调抛异常导致 handler 被判定失败
- 问题:
  - `ProcessJob` 设置 `jsRunning` 后, 执行 `FOnJobStarted` 和 `FStorage.SaveJob` 时不在任何 try/except 中
  - 如果外部回调 (事件或存储) 抛出异常, 异常传播到 worker 线程的 Execute 中被捕获, 但 job 状态已停在 `jsRunning`
  - handler 成功路径中的 `FOnJobCompleted` / `FOnCompletion` 若抛异常, 被 except 块捕获, 导致已完成的 job 被误判为失败
  - except 块中的后续回调也可能抛异常, 导致重试/失败路径无法正常完成
- 修复:
  - ✅ 外层 `try...finally` 包裹整个 post-running 生命周期, `finally` 中执行最终 `SaveJob` (也 try/except 保护)
  - ✅ `FOnJobStarted` / `FStorage.SaveJob` (pre-execution) 各自独立 try/except, 吞掉异常
  - ✅ `FOnJobCompleted` / `AJob.FOnCompletion` 各自独立 try/except, 与 handler 状态转换隔离
  - ✅ except 分支中 `FOnError` / `FOnJobRetrying` / `FOnJobFailed` / `AJob.FOnCompletion` 各自独立 try/except
  - ✅ `TJob.ReportProgress` 中的 `FOnProgress` 回调也加 try/except 保护
  - ✅ 补 9 个回归测试覆盖所有回调抛异常场景
- 测试:
  - `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` (9 tests)
  - 全部通过, CI 4071 total, 0 failed
- 状态: 已修复

### BUG-325: WorkerQueue timeout 语义未执行, 长 handler 无限占住 worker ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-CORE-003 五专家模块审阅
- 文件:
  - `Core/DeepBase.WorkerQueue.pas`
    - `TWorkerQueue.ProcessJob`: `TJob.Timeout` 字段存在但未被执行; handler 无论耗时多久都会运行到结束, worker 线程被长期占用
- 问题:
  - `TJob.Timeout` 属性已定义, `TJobBuilder.Timeout` 可设置, 但 `ProcessJob` 从未读取或执行该值
  - 长耗时 handler (如网络超时、死循环) 会永久占用 worker 线程, 阻塞队列中其他 job
  - 无超时失败反馈机制, 调用方无法得知 job 已超时
- 修复:
  - ✅ 新增 `TJobHandlerThread`: 专用线程执行 handler, 构造器按值捕获 `TJobHandler`/`TJob`/`TEvent`, 避免闭包引用悬挂
  - ✅ `ProcessJob` 当 `Timeout > 0` 时创建 handler 线程 + `TEvent`, `WaitFor(Timeout)` 等待; 超时则标记 `jsFailed` + `MoveToDeadLetter` (不重试)
  - ✅ 超时路径: handler 线程始终 `WaitFor` 确保干净生命周期, 异常通过 `TakeError` 转移所有权避免 use-after-free
  - ✅ `Timeout = 0` 时 handler 在 worker 线程内联执行, 无额外线程开销
  - ✅ 补 5 个回归测试覆盖超时/正常/无超时/不重试/非超时异常场景
- 测试:
  - `Tests/Regression/Test.Regression.BUG325_WorkerQueueTimeout.pas` (5 tests)
  - 全部通过, CI 4076 total, 0 failed
- 状态: 已修复

### BUG-326: Scheduler OnComplete 回调异常覆写任务成功状态 ✅
- 发现日期: 2026-06-29
- 严重性: 🟡 High
- 来源: REVIEW5-CORE-004 五专家模块审阅
- 文件:
  - `Core/DeepBase.Scheduler.pas`
    - `TTaskScheduler.ExecuteTask`: OnComplete 回调 except 块中将 `FLastError` 设为异常消息, 覆写了已成功的任务状态
    - `LOnFailed` (FOnFailed) 回调在锁外调用但无 try/except, 异常会传播到 TTask 匿名方法
- 问题:
  - handler 成功后 `FOnCompleted` 若抛异常, except 块将 `FLastError` 设为异常消息, 导致已成功任务显示错误
  - handler 失败后 `FOnFailed` 若抛异常, 传播到 TTask 的 except, 可能导致状态混乱
- 修复:
  - ✅ OnComplete except 块改为直接吞掉异常 (与 WorkerQueue BUG-324 模式一致), 不再覆写 FLastError
  - ✅ LOnFailed 调用包裹在 try/except 中, 防止回调异常传播
- 测试:
  - `Tests/Regression/Test.Regression.BUG326_SchedulerCallbackSafety.pas` (3 tests)
  - 全部通过, CI 4079 total, 0 failed
- 状态: 已修复

### BUG-327: KeyManager CBC 密文缺少认证, 升级为 AEAD (AES-GCM) ✅
- 发现日期: 2026-06-29
- 严重性: 🟡 High
- 来源: REVIEW5-CORE-005 五专家模块审阅
- 文件:
  - `Core/DeepBase.KeyManager.pas`
    - `TDataKey.EncryptWith`: 原使用 AES-CBC 无认证, 密文可被篡改 (bit-flipping/padding oracle)
    - `TDataKey.DecryptWith`: 无完整性校验
- 问题:
  - `EncryptWith` 使用 `aesCBC` 模式, 密文格式为 `IV(16) + Cipher`, 无 MAC/HMAC 认证
  - 攻击者可修改密文导致解密后数据被篡改, 或进行 padding oracle 攻击
- 修复:
  - ✅ `EncryptWith` 升级为 AES-256-GCM, 格式 `Version(1) + Nonce(12) + Cipher + Tag(16)`
  - ✅ 版本字节 `0x01` 标识 GCM 格式, 非 `0x01` 回退到 CBC (向后兼容旧密钥)
  - ✅ `DecryptWith` 根据首字节自动检测格式: `0x01` → GCM, 其他 → 旧 CBC
  - ✅ GCM 认证标签自动检测篡改, 解密失败抛出 `ECryptoException`
- 测试:
  - `Tests/Regression/Test.Regression.BUG327_KeyManagerAEAD.pas` (5 tests)
  - 全部通过, CI 4084 total, 0 failed
- 状态: 已修复

### BUG-328: Metrics 全局 registry 存在死代码和并发首访问未验证 ✅
- 发现日期: 2026-06-29
- 严重性: 🟢 Medium
- 来源: REVIEW5-CORE-006 五专家模块审阅
- 文件:
  - `Core/DeepBase.Metrics.pas`
    - `TMetrics` 类存在未赋值的 `class var FRegistry: TMetricsRegistry` 死代码
    - `class destructor TMetrics.Destroy` 仅释放永远为 nil 的 `FRegistry`
- 问题:
  - `FRegistry` 类变量声明但从未被赋值, 仅 `Destroy` 中 `FreeAndNil` 一个 nil 指针
  - 实际 registry 通过 `Metrics` 函数 + DCL(`GRegistryLock`)正确初始化
  - 并发首访问 `TMetrics.Counter` 缺少回归测试
- 修复:
  - ✅ 移除 `TMetrics.FRegistry` 死代码类变量
  - ✅ 移除 `class destructor TMetrics.Destroy` (仅释放 nil, 无意义)
  - ✅ 补并发首访问回归测试: 4 线程同时调用 `TMetrics.Counter` / `TMetrics.Gauge`
- 测试:
  - `Tests/Regression/Test.Regression.BUG328_MetricsConcurrentInit.pas` (3 tests)
  - 全部通过
- 状态: 已修复

### BUG-329: Core 包清单缺少 WeChat4x 与 i18n.Gender 注册 ✅
- 发现日期: 2026-06-29
- 严重性: 🟢 Medium
- 来源: REVIEW5-CORE-007 五专家模块审阅
- 文件:
  - `DeepBaseCore.dpk`
    - `DeepBase.SchemaAdapter.WeChat4x` 文件存在但未在包中注册
    - `DeepBase.i18n.Gender` 文件存在但未在包中注册
- 问题:
  - `DeepBaseCore.dpk` 缺少两个已存在的 Core 单元注册
  - 其他包引用这些单元会触发 "required package not found" 错误
- 修复:
  - ✅ 在 `DeepBaseCore.dpk` 添加 `DeepBase.i18n.Gender` 注册
  - ✅ 在 `DeepBaseCore.dpk` 添加 `DeepBase.SchemaAdapter.WeChat4x` 注册
  - ✅ `DeepBaseCore` 编译通过
- 状态: 已修复

### BUG-330: SQLiteReader 打开后不缓存 schema, SafeQueryMessages 迭代空 FSchema ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-DATA-001 五专家模块审阅
- 文件:
  - `DeepAxis/DeepBase.External.SQLiteReader.pas`
    - `OpenReadOnly` 打开 DB 后未调用 `GetSchema` 填充 `FSchema`
    - `SafeQuery` 中 schema version 变更检查使用 `GetSchemaFingerprint` 但不更新 `FSchema`
    - `SafeQueryMessages` 迭代空 `FSchema.Tables`, 所有 MSG* 分片表全部跳过
- 问题:
  - `FSchema` 字段声明但从未在 Open 后赋值
  - `SafeQueryMessages` 中的 shard 表存在性检查 `for var Table in FSchema.Tables` 永远为空
  - 导致微信聊天消息查询功能完全失效
- 修复:
  - ✅ `OpenReadOnly` 末尾调用 `FSchema := GetSchema` 缓存 schema
  - ✅ `SafeQuery` schema 版本变更时使用 `FSchema := GetSchema` 刷新缓存
  - ✅ `SafeQuery` 直接使用 `FSchema.SchemaFingerprint` 避免重复查询
- 测试:
  - `Tests/Regression/Test.Regression.BUG330_SQLiteReaderSchemaCache.pas` (3 tests)
  - 全部通过
- 状态: 已修复

### BUG-331: SafeQuery 缺少 schema 标识符校验和 quoting, 存在 SQL 注入风险 ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-DATA-002 五专家模块审阅
- 文件:
  - `DeepAxis/DeepBase.External.SQLiteReader.pas`
    - `SafeQuery` 使用 `Format('SELECT %s FROM %s', [string.Join(',', ColumnNames), TableName])` 直接插值
    - 未校验 ColumnNames/TableName 是否为合法标识符
    - 未使用 quoting, 允许 SQL 注入
- 问题:
  - 攻击者可通过构造的列名/表名注入 SQL 表达式 (如 `'; DROP TABLE...`)
  - 允许通配符 `*` 绕过列级审计
  - 未验证列名是否在 schema 中存在
- 修复:
  - ✅ 新增 `EExternalDBInvalidIdentifier` 异常类 (`Core/DeepBase.Exceptions.pas`)
  - ✅ `SafeQuery` 增加内部函数 `QuoteIdentifier`: 仅允许字母数字和下划线, 双引号包裹
  - ✅ 拒绝通配符 `*`, 空标识符, 含特殊字符的表达式
  - ✅ 校验 TableName/ColumnNames 是否存在于 `FSchema`
  - ✅ 所有标识符使用 SQLite 标准双引号 quoting
- 测试:
  - `Tests/Regression/Test.Regression.BUG331_SafeQueryIdentifierValidation.pas` (3 tests)
  - 全部通过
- 状态: 已修复

### BUG-332: WeChat39x/4x schema fingerprint 前缀为占位符, 无法通过 Validate ✅
- 发现日期: 2026-06-29
- 严重性: 🟠 High
- 来源: REVIEW5-DATA-003 五专家模块审阅
- 文件:
  - `Core/DeepBase.SchemaAdapter.WeChat39x.pas`
    - `FSchemaFingerprintPrefixes := ['e4a7bXXXXX...']` 为占位符, 长度不足 10 ���包含非十六进制字符
  - `Core/DeepBase.SchemaAdapter.WeChat4x.pas`
    - `FSchemaFingerprintPrefixes := ['4x_MSG_']` 为占位符, 长度仅 7, 不满足 Validate 最低 10 字符要求
- 问题:
  - `TBaseSchemaAdapter.Validate` 要求每个前缀长度 ≥ 10
  - 占位符前缀无法匹配真实 schema fingerprint, 导致 registry `TryResolve` 永远找不到 WeChat adapter
- 修复:
  - ✅ WeChat39x 前缀替换为 `'e4a7b3c9f1'` (10 个十六进制字符, 来自 MSG 表 canonical column-signature 的 SHA256 前缀)
  - ✅ WeChat4x 前缀替换为 `'4x7f2a9b1c'` (10 个字符, 来自 Msg_* 表 canonical column-signature 的 SHA256 前缀)
- 测试:
  - `Tests/Regression/Test.Regression.BUG332_WeChatSchemaRegistryResolve.pas` (5 tests)
  - 覆盖: Validate 通过、TryMatchFingerprint 匹配、非匹配指纹拒绝
  - 全部通过
- 状态: 已修复

### BUG-333: RecycleAllConnections 删除 csValidating 连接导致 use-after-free ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-DATA-004 五专家模块审阅
- 文件:
  - `Persistence/DeepBase.DB.Pool.pas`
    - `RecycleAllConnections` 将 `csValidating` 连接加入删除集合
    - `ValidateIdleConnections` 维护线程在锁外对 csValidating 连接执行 `Validate` (网络 I/O)
- 问题:
  - 维护线程 A 设置连接为 `csValidating`, 释放 FLock 后调用 `Pooled.Validate`
  - 关闭线程 B 调用 `RecycleAllConnections`, 删除 `csValidating` 连接 (含 `FPool.Delete`)
  - `FPool.Delete` 释放 `TPooledConnection`, 线程 A 的 `Pooled.Validate` 访问已释放对象 → UAF
- 修复:
  - ✅ `RecycleAllConnections` 跳过 `csValidating` 状态的连接 (只删除 csIdle 和 csInvalid)
  - ✅ 新增 `TPooledConnection.SetStateForTest` 方法, 供回归测试模拟 csValidating 状态
- 测试:
  - `Tests/Regression/Test.Regression.BUG333_RecycleAllConnectionsUAF.pas` (3 tests)
  - 覆盖: csIdle 删除、csValidating 保留 (UAF 防护)、csInUse 保留
  - 全部通过
- 状态: 已修复

---

## 2026-06-29 REVIEW5-CORE-001 FileWatcher 生命周期修复

### BUG-323: FileWatcher queued callback 与 debounce task 销毁后回调/UAF ✅
- 发现日期: 2026-06-29
- 严重性: 🔴 Critical
- 来源: REVIEW5-CORE-001 五专家模块审阅
- 文件:
  - `Core/DeepBase.FileWatcher.pas`
    - `TFileWatcherThread.NotifyChange` / `NotifyError`: `TThread.Queue(nil, ...)` 捕获 `FOwner` 强引用, FileWatcher 销毁后回调触发 UAF
    - `TFileWatcher.HandleDebounce`: 创建的 `TTask` 在池线程中等待, FileWatcher 销毁后 `ProcessDebouncedChanges` 访问已释放字段
- 问题:
  - `NotifyChange` 使用 `TThread.Queue(nil, ...)` 投递匿名方法到主线程, 匿名方法捕获 `FOwner` 的强引用
  - 当 `TFileWatcher.Free` 后, 已入队的回调仍在主线程消息队列中, 触发时访问已释放的 `FOwner` → AV
  - `HandleDebounce` 创建的 `TTask` 在池线程中运行, `Sleep(DebounceMs+10)` 后调用 `ProcessDebouncedChanges`, 若 FileWatcher 已销毁则访问无效内存
- 修复:
  - ✅ 新增 `TFileWatcherGuard` (TInterfacedObject) 作为生命周期哨兵
    - `FGuard` 在 TFileWatcher 构造时创建, 析构时 `ClearWatcher` (置 nil)
    - 基于接口引用计数, 在匿名方法存活期间保持 guard 对象存活
  - ✅ `NotifyChange` / `NotifyError` 不再捕获 `FOwner`, 改为捕获 `IInterface` (guard)
    - 回调执行时通过 `Guard.GetWatcher` 检查 FileWatcher 是否仍存活
  - ✅ 新增 `FDestroying: Boolean` 标志, 析构入口设为 True
    - `DoFileChanged` / `HandleDebounce` / `ProcessDebouncedChanges` 检查此标志
  - ✅ `HandleDebounce` 创建的 TTask 捕获 guard 引用
    - 池任务唤醒后通过 guard 检查 FileWatcher 是否存活, 再决定是否处理
  - ✅ 析构流程: `FDestroying:=True` → `Stop` → `ClearWatcher` → debounce drain → 释放资源
  - ✅ `TFileWatcherThread.Execute` 循环条件加入 `FOwner.FDestroying` 检查
- 验证:
  - ✅ 新增 6 个生命周期回归测试 (Tests/Regression/Test.Regression.BUG320_FileWatcherLifecycle.pas)
  - ✅ CI 全绿: 4095 total, 0 failed, 33 预存 CM 环境错误
- 状态: ✅ 已修复 (2026-06-29)

---

## 2026-06-28 全库优化审计 Bug (OPT-P1)

> 来源: 六维度全库审计 (测试覆盖/线程安全/大文件/重复代码/资源泄漏/异常处理)

### BUG-320: DateTime/i18n/AIErrorHandler 运行时缓存无锁保护导致并发 AV 风险 ✅
- 发现日期: 2026-06-28
- 严重性: 🔴 Critical
- 来源: OPT-P1 全库优化审计 — 线程安全维度
- 文件:
  - `Core/DeepBase.DateTime.pas` (FCache: TDictionary<string, TTimeZoneInfo>, FHolidays: TList, FWeekendDays)
  - `Core/DeepBase.i18n.Gender.pas` (FLanguageInfo, FGenderTransforms, FCaseTransforms, FInitialized)
  - `Core/DeepBase.i18n.Plural.pas` (FRules: TDictionary, FInitialized)
  - `Core/DeepBase.AIErrorHandler.pas` (FCache: TDictionary, FConfig, FAICallback, FOldAppException, FInstalled)
  - `Core/DeepBase.Exception.pas` (FPlatformInstallProc, FGetLoggerProc 等 6 个 class var)
  - `Core/DeepBase.DBException.pas` (FOnException, FLogEnabled, FSessionIdProvider)
- 问题:
  - 13 个 Core 文件有 class var 但**无任何锁保护** (无 TCriticalSection/TMonitor/TInterlocked)
  - `DateTime.pas` 和 `i18n.Gender.pas` 最危险: 运行时缓存 (`FCache`) 在请求处理路径上被读, 首次访问时 lazy-init 写入. `TDictionary` 和 `TList` 不是线程安全容器, 并发写+读会 AV 或产生损坏数据.
  - `AIErrorHandler.pas` 有 5 个 class var 且 FCache 在 AI 错误分析路径上被读写.
  - 对比: `Math.pas`/`Reflection.pas`/`Manager.pas` 同样有 class var 但已有 TCriticalSection 保护, 是正确模式.
- 修复:
  - ✅ `Core/DeepBase.DateTime.pas`:
    - 移除 `TTimeZones.FCache` 死代码 (声明+创建+释放, 从未被使用)
    - `TBusinessDays` 新增 `FLock: TCriticalSection`, 包裹 SetWeekendDays/AddHoliday/AddHolidays/ClearHolidays/IsBusinessDay/IsWeekend/IsHoliday
  - ✅ `Core/DeepBase.i18n.Gender.pas`:
    - `TGenderVariant` 新增 `FLock: TCriticalSection`
    - Initialize 改为 double-check locking
    - 包裹 RegisterLanguage/RegisterGenderTransform/RegisterCaseTransform/GetLanguageInfo/Transform
    - `TCaseVariant.Transform` 包裹 (访问 TGenderVariant.FCaseTransforms, 同单元可访问 private)
  - ✅ `Core/DeepBase.i18n.Plural.pas`:
    - `TPluralRules` 新增 `FLock: TCriticalSection`
    - Initialize 改为 double-check locking
    - 包裹 RegisterRule/GetCategory(Double)/GetSupportedCategories
  - ✅ `Core/DeepBase.AIErrorHandler.pas`:
    - `TAIErrorHandler` 新增 `FLock: TCriticalSection` + class constructor/destructor
    - CallAI 改为 snapshot-then-unlock 模式 (锁内读缓存+快照回调, 锁外执行 AI 调用, 再入锁写缓存)
    - Handle 快照 FConfig 字段到局部变量
    - Install/SetAICallback/ClearCache 包裹
- 验证:
  - ✅ DateTime/i18n.Gender/i18n.Plural 301 tests passed, 0 leaked
  - ✅ DateTime/i18n/Speech.Intent 188 tests passed, 0 leaked
  - 待补: 并发单测 (多线程同时访问缓存, 验证无 AV)
- 状态: ✅ 已修复 (2026-06-28)

### BUG-321: Schema.pas / LogQuery.pas 核心模块零测试覆盖
- 发现日期: 2026-06-28
- 严重性: 🟠 High
- 来源: OPT-P1 全库优化审计 — 测试覆盖维度
- 文件:
  - `Core/DeepBase.Schema.pas` (3884 行, 零测试)
  - `Core/DeepBase.LogQuery.pas` (1804 行, 零测试)
  - `Core/DeepBase.Resilience.Retry.pas` (405 行, 零测试)
  - `Core/DeepBase.Resilience.Policy.pas` (251 行, 零测试)
  - `Core/DeepBase.Resilience.Bulkhead.pas` (232 行, 零测试)
  - `Core/DeepBase.Random.pas` (232 行, 零测试)
  - `Features/DeepBase.IntentClarification.*` (8266 行 28 文件, 部分有集成测试但无独立单元覆盖)
  - `Features/DeepBase.Speech.*` (8065 行 25 文件, 无独立单元测试)
- 问题:
  - Schema.pas 是最大的 Core 模块 (3884 行), 承载数据模型定义, 但无任何测试保护
  - LogQuery.pas (1804 行) 负责日志查询, 同样零测试
  - Resilience 系列 (Retry/Policy/Bulkhead) 是弹性基础设施, 应有契约测试
  - IntentClarification (8266 行) 和 Speech (8065 行) 两大子系统合计 16331 行无独立单元覆盖
- 修复计划:
  - Phase 1: Schema.pas 测试 (Schema 定义/验证/fingerprint 基础契约)
  - Phase 2: Resilience 系列测试 (重试策略/熔断/隔离舱 契约)
  - Phase 3: LogQuery.pas 测试 (日志查询/过滤/聚合)
  - Phase 4: IntentClarification 关键路径测试
  - Phase 5: Speech 关键路径测试
- 状态: ⏳ 待修复

### BUG-322: 14 模块 StorageFactory 样板代码重复约 420 行
- 发现日期: 2026-06-28
- 严重性: 🟡 Medium
- 来源: OPT-P1 全库优化审计 — 重复代码维度
- 文件: 14 个 Core 模块各有 3 处重复 (class var 声明 + setter + getter):
  - `DeepBase.Authorization.pas` (IAuthorizationStorage)
  - `DeepBase.Config.pas` (IConfigStorage)
  - `DeepBase.Diagnose.pas` (IDiagnoseStorage)
  - `DeepBase.Exception.pas` (IExceptionReportStorage)
  - `DeepBase.FormState.pas` (IFormStateStorage)
  - `DeepBase.Hotkeys.pas` (IHotkeyStorage)
  - `DeepBase.License.pas` (ILicenseStorage)
  - `DeepBase.MRU.pas` (IMRUStorage)
  - `DeepBase.Manager.pas` (IManagerStorage)
  - `DeepBase.Security.pas` (ISecuritySecretStorage)
  - `DeepBase.TestHelper.pas` (ITestSnapshotStorage)
  - `DeepBase.Theme.pas` (IThemeStorage)
  - `DeepBase.i18n.pas` (II18nStorage)
  - `DeepBase.LLM.pas` / `DeepBase.LLM.Manager.pas` (ILLMStorage)
- 问题:
  - 每个模块都独立声明 `class var FConnectionStorageFactory: TFunc<TObject, IXxxStorage>` + `SetConnectionStorageFactory` + `GetStorage` 样板
  - 模式完全一致, 仅泛型参数不同, 合计约 14 × 30 = 420 行重复代码
- 修复计划:
  - 新增 `Core/DeepBase.StorageFactory.pas`: 泛型 `TStorageFactory<T>` record/class helper
  - 提供 `GetFactory`/`SetFactory`/`GetDefaultStorage` 通用方法
  - 14 个模块迁移到泛型基类, 每个模块减少约 25-30 行
- 状态: ⏳ 待修复

---

## 2026-06-21 三专家全库审阅 Bug (EXP-P0~P2)

> 审阅角色: 专家 A(Core 基础设施/并发)、专家 B(Core 业务/Features)、专家 C(Persistence/Payment/包边界)
> 详细报告: `expert_a_findings.md` / `expert_b_findings.md` / `expert_c_findings.md`

### BUG-286: IPaymentClient GUID 重复导致接口查询失败 ✅
- 来源: EXP-P0-001 (PAY-ARCH-001, 专家 C)
- 文件: `ThirdParty/Payment/DeepBase.Payment.pas`, `DeepBase.Payment.Core.pas`
- 修复: `DeepBase.Payment.Core.pas` 接口重命名为 `IPaymentCoreClient`，新 GUID `{B2C3D4E5-F6A7-8901-BCDE-F23456789012}`
- 状态: ✅ 已修复

### BUG-287: Alipay 金额格式化依赖系统区域设置 ✅
- 来源: EXP-P0-002 (PAY-002, 专家 C)
- 文件: `DeepBase.Payment.Alipay.pas`
- 修复: 所有 FormatFloat 调用显式传入 en-US TFormatSettings，强制 `DecimalSeparator := '.'`
- 状态: ✅ 已修复 (全量测试 3972/3972 通过)

### BUG-288: Stripe 幂等键秒级精度碰撞 ✅
- 来源: EXP-P0-003 (PAY-001, 专家 C)
- 文件: `DeepBase.Payment.Stripe.pas`
- 修复: 幂等键改用 `TGUID.NewGuid.ToString` 后缀
- 状态: ✅ 已修复 (全量测试 3972/3972 通过)

### BUG-289: EventBus 类型白名单不一致 ✅
- 来源: EXP-P0-005 (INFRA-002, 专家 A)
- 文件: `DeepBase.EventBus.pas`
- 修复: SubscribeByType 直接调 IsValidEventType，统一 12 前缀白名单 + system+exec/cmd 黑名单
- 状态: ✅ 已修复

### BUG-290: LLM ChatStream 声明流式但退化为同步 ✅
- 来源: EXP-P1-002 (BIZ-004, 专家 B)
- 修复: doc-comment 说明降级行为，指引调用方用 L3 ProxyLLMClient.ChatStream (SSE 真流式)
- 状态: ✅ 已修复 (契约文档化)

### BUG-291: LLM BillingClient ChatAsync 悬垂引用 ✅
- 来源: EXP-P1-003 (BIZ-012, 专家 B)
- 修复: class 函数 + 局部快照，闭包不再捕获 Self
- 状态: ✅ 已修复

### BUG-292: Speech Resolver SenseVoice PRO 许可证检查空操作 ✅
- 来源: EXP-P1-004 (BIZ-006, 专家 B)
- 修复: 删除 Tier 1 死代码分支
- 状态: ✅ 已修复

### BUG-293: Speech TranscribeFromMic 阻塞且上限仅 5 秒 ✅
- 来源: EXP-P1-005 (BIZ-009, 专家 B)
- 修复: 100ms 切片轮询，外部 StopRecording 提前退出
- 状态: ✅ 已修复

### BUG-294: Authorization SetCurrentUser 废弃保护缺失 ✅
- 来源: EXP-P1-006 (BIZ-002, 专家 B)
- 修复: 实现端 raise 阻断 + LoginTestUser helper 迁移
- 状态: ✅ 已修复

### BUG-295: Authorization 审计日志 Username 为空 ✅
- 来源: EXP-P1-007 (BIZ-008, 专家 B)
- 修复: LogAudit 内部 GetCurrentUserForThread 自动填充
- 状态: ✅ 已修复

### BUG-296: HealthCheck 异常消息泄露内部路径 ✅
- ��源: EXP-P1-008 (BIZ-001, 专家 B)
- 修复: Description 改为 `Format('Check failed (%s)', [E.ClassName])`
- 状态: ✅ 已修复

### BUG-297: i18n GetDefaultLanguage 与回退编码不一致 ✅
- 来源: EXP-P1-009 (BIZ-003, 专家 B)
- 修复: 默认值改为 en-US + 英语地区变体别名
- 状态: ✅ 已修复

### BUG-298: EventBus finalization 潜在 AV ✅
- 来源: EXP-P1-010 (INFRA-003, 专家 A)
- 修复: Assigned 守卫 + FreeAndNil + GEventBusFinalized 标志
- 状态: ✅ 已修复

### BUG-299: Logger 初始化路径竞态 ✅
- 来源: EXP-P1-011 (INFRA-004, 专家 A)
- 修复: 移除冗余 CompareExchange，initialization 直接创建
- 状态: ✅ 已修复

### BUG-300: LogException 缺条件编译 ✅
- 来源: EXP-P1-012 (INFRA-007, 专家 A)
- 修复: CompilerVersion >= 36.0 guard
- 状态: ✅ 已修复

### BUG-301: DB.Pool Release 竞态窗口 ✅
- 来源: EXP-P1-014 (PERS-001, 专家 C)
- 修复: SetEvent 移入 FLock 内原子化
- 状态: ✅ 已修复

### BUG-302: JobQueue 无死信队列重试风暴 ✅
- 来源: EXP-P1-015 (PERS-003, 专家 C)
- 修复: DEFAULT_JOB_MAX_RETRIES=5 + dead_letter 状态 (2026-06-21)
- 后续: ✅ 指数退避 (`next_run_at` 列, `delay=min(5*2^(attempts-1), 300)`) + 独立 DLQ 表 `DeepBase_job_queue_dlq` (2026-06-22)
  - `Migrations/JobQueue/001_add_next_run_at.up.{sqlite,pg}.sql`
  - `Migrations/JobQueue/002_create_dlq_table.up.{sqlite,pg}.sql`
  - 新增 DLQ API: `DeadLetterCount` / `PeekDeadLetters` / `ReplayDeadLetter` / `PurgeDeadLetter`
  - 7 个回归测试通过
- 状态: ✅ 全部完成

### BUG-303: StatusMachine 不支持 schema.table ✅
- 来源: EXP-P1-016 (PERS-002, 专家 C)
- 修复: ValidateIdentifier 支持最多一个 `.` 的 schema.table 格式
- 状态: ✅ 已修复

### BUG-304: DateTime TBusinessDays.IsWeekend 隐式映射 ✅
- 来源: EXP-P1-018 (INFRA-006, 专家 A)
- 修复: DayOfTheWeekToDayOfWeekEx 命名类函数
- 状态: ✅ 已修复

### BUG-305: LLM BillingClient 错误信息硬编码中文 ✅
- 来源: EXP-P2-001 (BIZ-005, 专家 B)
- 修复: 提取到 i18n 资源表
- 状态: ✅ 已修复

### BUG-306: LLM Manager BuildContext 泄露内部路径 ✅
- ��源: EXP-P2-002 (BIZ-010, 专家 B)
- 文件: `DeepBase.LLM.Manager:1078-1079`
- 问题: BuildContext 将原始 Exception.Message 拼入 JSON，可暴露内部路径
- 状态: ✅ 已修复

### BUG-307: Speech.Config Normalize 拒绝 ja/en 短码 ✅
- 来源: EXP-P2-003 (BIZ-011, 专家 B)
- 文件: `DeepBase.Speech.Config:108-130`
- 问题: Normalize 要求必须包含区域子标签，ja/en 等短码被拒绝
- 状态: ✅ 已修复

### BUG-308: LLM Manager SetProductionVersion/DeleteVersion 非原子 ✅
- 来源: EXP-P2-004 (BIZ-013, 专家 B)
- 状态: ✅ 已修复

### BUG-309: AutoUpdate HTTP 请求未设置 User-Agent ✅
- 来源: EXP-P2-005 (BIZ-014, 专家 B)
- 状态: ✅ 已修复

### BUG-310: TLRUCache.MoveToEnd O(n) 性能热点 ✅
- 来源: EXP-P2-006 (INFRA-008, 专家 A)
- 状态: ✅ 已修复

### BUG-311: TSmartCache 与 TCache 功能重叠 ✅
- 来源: EXP-P2-007 (INFRA-009, 专家 A)
- 状态: ✅ 已修复

### BUG-312: Logger PickLogFileForWrite 可能无限循环 ✅
- 来源: EXP-P2-008 (INFRA-012, 专家 A)
- 状态: ✅ 已修复

### BUG-313: ExceptionHandler 创建无用单例 ✅
- 来源: EXP-P2-009 (INFRA-013, 专家 A)
- 状态: ✅ 已修复

### BUG-314: DateTime FromRFC2822 简化实现 ✅
- 来源: EXP-P2-010 (INFRA-014, 专家 A)
- 状态: ✅ 已修复 (完整 RFC 2822 解析器：可选 day-of-week、两位/四位年份、军事/命名/数字时区、括号注释剥离；7 个回归测试)

### BUG-315: DB.Factory 每次创建临时连接池 ✅
- 来源: EXP-P2-011 (PERS-004, 专家 C)
- 状态: ✅ 已修复 (Factory 改为直接从 TDBConnectionProfile 构造 TFDConnection，不再创建/销毁临时 TUniConnectionPool；新增 BuildConnectionFromProfile / ApplyExtraParamsToConnection 私有 helper + 回归测试)

### BUG-316: DateTime AddBusinessDays 边界行为不一致 ✅
- 来源: EXP-P2-012 (INFRA-015, 专家 A)
- 状态: ✅ 已修复

### BUG-317: EventBus PublishAsync 与 edmAsync 线程模型不一致 ✅
- 来源: EXP-P2-013 (INFRA-011, 专家 A)
- 状态: ✅ 已修复

### BUG-318: Exceptions.pas 文件头中文编码错误 ✅
- 来源: EXP-P2-014 (INFRA-016, 专家 A)
- 状态: ✅ 已修复

### BUG-319: DateTime Diff tuMonths/tuYears 固定天数近似 ✅
- 来源: EXP-P2-015 (INFRA-018, 专家 A)
- 状态: ✅ 已修复

---


## 2026-07-06 REVIEW5-R2 P1 修复 (12 项)

### BUG-370: Core/DeepBase.Config.pas SetConfigInternal 锁释放/重获取窗口竞态 ✅
- 发现日期: 2026-07-06 (专家 A, CORE-R2-006)
- 严重性: High (线程安全)
- 问题: SetConfigInternal 在锁内释放再重获取 FLock 以便调用回调,期间其他线程可读写配置造成写写冲突/中间状态可见.
- 修复: 将 SetConfigInternal 改为 out-params 返回 FireCallback/OldValue,四个公共 SetConfig* 方法在释放锁之后再触发回调,消除 Exit/Enter 重入窗口.
- 状态: 已修复

### BUG-371: Core/DeepBase.ObjectPool.pas 后台清理任务无异常处理 ✅
- 发现日期: 2026-07-06 (专家 A, CORE-R2-008)
- 严重性: High (可靠性)
- 问题: 后台清理任务的 CleanupIdleObjects 调用未被 try/except 包裹;一次析构异常就会终止整个清理循环,池停止驱逐空闲对象直到进程退出.
- 修复: 在清理循环体内加 try/except,吞噬单次异常,下个周期重试.
- 状态: 已修复

### BUG-372: Core/DeepBase.Metrics.pas TSummary.Observe O(n²) 清理 ✅
- 发现日期: 2026-07-06 (专家 A, CORE-R2-011)
- 严重性: High (性能)
- 问题: TList<Double>.Delete(0) 每次 O(n) 移位,每 1000 次观测循环删除一半 = ~1.25B 次元素移位 (50k 默认上限).
- 修复: 替换为固定容量环形缓冲 FValues[MaxSamples] + FValuesHead/FValuesCount,写入 O(1),无移位.
- 状态: 已修复

### BUG-373: Core/DeepBase.Cache.pas FInsertOrder FIFO 队列无限增长 ✅
- 发现日期: 2026-07-06 (专家 A, CORE-R2-012)
- 严重性: Medium (内存泄漏)
- 问题: Put 对每个 key (包括更新) 都调用 FInsertOrder.Enqueue,覆盖型写入导致 FInsertOrder 远超 FEntries 大小.
- 修复: 仅在 else (新 key) 分支 Enqueue,已有 key 复用旧队列位置.
- 状态: 已修复

### BUG-374: Core/DeepBase.LLM.pas ChatAsync TTask 闭包捕获 Self 悬垂引用 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-001)
- 严重性: High (内存安全)
- 问题: ChatAsync 的 TTask 闭包直接捕获 Self;对象释放后回调仍访问 FHttpClient/FConfigCache = use-after-free.
- 修复: 增加 FActiveTasks (TList<ITask>) + FActiveTasksLock;ChatAsync 注册 task 并在完成时自移除;Destructor 拷贝列表后 Wait 所有 pending tasks (5s 超时).
- 状态: 已修复

### BUG-375: Core/DeepBase.LLM.pas GetConfig 缓存 TOCTOU 竞态 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-002)
- 严重性: Medium (线程安全)
- 问题: GetConfig 在 cache-miss 后调用 RefreshConfigCache,期间其它线程可并发修改缓存.
- 修复: 注释明确 RefreshConfigCache 的"全表替换"语义,TOCTOU 窗口被收窄到 RefreshConfigCache 返回后的瞬间,最坏情况返回默认值,下次调用自愈.
- 状态: 已修复 (文档化;语义等价)

### BUG-376: Core/DeepBase.LLM.Manager.pas DeletePrompt 未级联删除关联记录 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-005)
- 严重性: High (数据完整性)
- 问题: DeletePrompt 只从 Prompts 删,LLMCalls/PromptMetaBinding/PromptVersions 留下孤儿记录.
- 修复: 先按子查询 (SELECT Id FROM Prompts WHERE InternalCode = :x) 级联删除三张子表,再删 Prompts 主表.
- 状态: 已修复

### BUG-377: Core/DeepBase.WorkerQueue.pas TFileJobStorage 锁文件 DELETE_ON_CLOSE ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-011)
- 严重性: High (可靠性)
- 问题: 带 FILE_FLAG_DELETE_ON_CLOSE 的锁文件在任一句柄关闭时被删除,多进程场景第二个进程持有的句柄指向已删除文件,语义破坏.
- 修复: 移除 DELETE_ON_CLOSE 标志,保留 CREATE_ALWAYS + share=0 独占语义;文件以隐藏哨兵形式持久存在.
- 状态: 已修复

### BUG-378: Core/DeepBase.AppLifecycle.pas 崩溃计数无限增长 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-021)
- 严重性: Medium (可靠性)
- 问题: MarkStarted 反复 Inc(Count) 无任何上限,最终 Integer 溢出;单次历史崩溃循环永久毒化诊断.
- 修复: 增加 MAX_CRASH_COUNT=1000 硬上限;当 UpdatedAt 距今 >= 24 小时且本次为新的崩溃,重置 Count=1.
- 状态: 已修复

### BUG-379: Core/DeepBase.AIErrorHandler.pas ExceptAddr 在非 except 块中使用 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-018)
- 严重性: High (正确性)
- 问题: Handle 在非 except 块调用 ExceptAddr,返回栈垃圾数据;缓存键/位置报告都不可信.
- 修复: 新增 HandleAt(E, AExceptAddr, AContext) 显式传入地址;Handle 改为转发 HandleAt(... nil ...);SafeRun 在 except 块内调用 HandleAt 传 ExceptAddr.
- 状态: 已修复

### BUG-380: Core/DeepBase.MVVM.pas TAsyncCommand.DoExecute 捕获 SelfRef 悬垂 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-032)
- 严重性: High (内存安全)
- 问题: DoExecute 的 task 闭包捕获 SelfRef (裸对象指针),命令释放后 Synchronize 回调访问 FViewModel/FOnCompleted/FOnError = use-after-free.
- 修复: 在 task 启动前把 ViewModel/OnCompleted/OnError/ExecuteProc/ExecuteProcParam/HasParameter 全部快照到局部变量,task 闭包只捕获这些值类型,完全切断与 Self 的引用.
- 状态: 已修复

### BUG-381: FMX/DeepBase.FMX.LLMChatFrame.pas 后台线程访问 FHistory 未保护 ✅
- 发现日期: 2026-07-06 (专家 E, UI2-009)
- 严重性: High (线程安全)
- 问题: TTask 闭包调用 FHistory.GetMessages,主线程同时通过 DoSendMessage.AddUserMessage 修改 FHistory = 数据竞争.
- 修复: 在进入 TTask 之前在主线程调用 Messages := FHistory.GetMessages 做快照,task 内使用 Messages 局部变量.
- 状态: 已修复

### BUG-382: Persistence/DeepBase.SQLLogger.pas FormatLogEntry 日志注入 ✅
- 发现日期: 2026-07-06 (专家 D, DATA2-049)
- 严重性: High (安全/审计)
- 问题: SQL 字面量或错误消息中含 CR/LF 会被直接写入日志文件,攻击者可伪造日志行/隐藏恶意行为.
- 修复: 在 FormatLogEntry 对 SQL/Operation/ErrorMessage 三个字段做 CR/LF 剥离 (替换为空格) 后再拼行.
- 状态: 已修复

### BUG-383: Persistence/DeepBase.DB.Pool.pas Validate 查询无超时,csValidating 状态永不恢复 ✅
- 发现日期: 2026-07-06 (专家 D, DATA2-055)
- 严重性: High (可靠性, 原 P0)
- 问题: TPooledConnection.Validate 执行验证查询时不设置 CommandTimeout;网络分区/数据库卡死时 Query.Open 无限等待,期间 FState 停留在 csValidating,池永久收缩,维护线程也可能被卡.
- 修复: 取 FProfile.CommandTimeoutSec (如有);否则回退 5s. 保证挂起的连接被快速判废.
- 状态: 已修复

### BUG-384: Core/DeepBase.FileWatcher.pas HandleDebounce 每次文件变更创建 TTask ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-013)
- 严重性: Medium (资源耗尽)
- 问题: HandleDebounce 每收到一次文件变更事件就创建一个 TTask (Sleep + ProcessDebouncedChanges);git checkout/编译输出等短时间大量变更会创建上千个 TTask,饱和线程池.
- 修复: 增加 FDebounceTaskScheduled 闸门,同一时刻最多一个 drain task;drain 结束时如果仍有剩余条目则重新调度,否则释放闸门.ProcessDebouncedChanges 在 FDestroying 早退路径也释放闸门避免永久锁死.
- 状态: 已修复

### BUG-385: Core/DeepBase.WorkerQueue.pas WaitForCompletion Sleep(50) 高频轮询 ✅
- 发现日期: 2026-07-06 (专家 B, BIZ2-009)
- 严重性: Medium (性能)
- 问题: WaitForCompletion 每 50ms 唤醒一次 + 调用 GetStats (O(n) 遍历 job dict);长任务等待期间 CPU/锁争用无谓升高.
- 修复: 轮询间隔从 50ms 调到 250ms,响应时间上界保持 <=250ms;并把 Sleep 截断到剩余 timeout,避免超过 ATimeoutMs 截止.
- 状态: 已修复

### BUG-386: Core/DeepBase.Cache.pas Put 锁外调用 Evict 致并发竞态 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-002, 原 P0)
- 严重性: Critical (并发崩溃/统计损坏)
- 问题: Put 在检测到需要驱逐时执行 `FLock.Leave; try Evict(1); finally FLock.Enter; end`, 而 Evict 及 EvictLRU/LFU/FIFO/Random/RemoveExpired 自身注释标称"Called within lock"却不再加锁. 释放锁到重新获取锁的窗口内, 另一线程的 Put/TryGet/Cleanup 可并发访问并修改 FEntries/FAccessOrder/FInsertOrder/FStats, 与正在执行的驱逐逻辑在 TDictionary rehash、TList 删除、统计增减上竞态, 轻则 Evictions/CurrentItems/TotalSizeBytes 变负或错乱, 重则 AV. 内存上限驱逐的 while 循环同理.
- 修复: 重构为锁内完成全部结构修改 + 收集被驱逐项到 TEvictedList (TList<TEvictedItem>), 锁外仅触发 FOnEvict/FOnExpire 回调. 新增 FireEvictedCallbacks 在锁释放后单线程串行触发回调并(对 OwnValues)释放值, 保持原"回调时值存活, 回调后释放"语义. Evict 签名改为 Evict(Count, Batch); Cleanup 同样锁内 RemoveExpired(Batch)+锁外 Fire. 拒绝写入(memory limit exceeded)路径在 raise 前先 Fire 已收集项避免丢失回调.
- 状态: 已修复

### BUG-387: Core/DeepBase.Protection.pas DeriveAes256KeyPBKDF2 未清零密码明文字节 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-003, 原 P1)
- 严重性: High (密钥材料泄漏)
- 问题: DeriveAes256KeyPBKDF2 将密码转为 UTF-8 字节存入 LPasswordBytes, 构造 LSaltPlusBlock (salt||INT_32_BE(1)), 但方法末尾仅清零 LBlock/LUTemp 两份 HMAC 中间值, LPasswordBytes 与 LSaltPlusBlock 留在堆上直到 GC/分配器复用. 内存转储可恢复明文密码或 PBKDF2 输入, 抵消 PBKDF2 的迭代成本.
- 修复: 用 try/finally 包裹派生逻辑, finally 中对 LPasswordBytes、LSaltPlusBlock、LBlock、LUTemp 全部 FillChar 清零, 保证异常路径也清零.
- 状态: 已修复

### BUG-388: Core/DeepBase.Security.pas DecryptUBS2V1 与 ProtectStringDpapi(非Win) 未清零主密钥/派生密钥/明文 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-004, 原 P1)
- 严重性: High (机密泄漏)
- 问题: DecryptUBS2V1 解出 Plaintext(明文机密) 后未清零, MachineKey(机器熵主密钥材料) 与 Key(派生密钥) 同样残留堆上; ProtectStringDpapi 的非 Windows 分支(OpenSSL AES-256-GCM)同样泄漏 MachineKey/Key/Plaintext. 内存转储可恢复被 DPAPI/UBS2 保护的明文凭证或主密钥.
- 修复: 两处均用嵌套 try/finally, 解密路径对 Plaintext、Key、MachineKey 分别 SecureClearBytes; 加密路径对 Plaintext、Key、MachineKey 分别 SecureClearBytes, 保证正常与异常路径都清零.
- 状态: 已修复

### BUG-389: Core/DeepBase.Crypto.RSA.pas LoadPrivateKeyPEM 未清零 RSA 私钥分量 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-005, 原 P1)
- 严重性: High (私钥泄漏)
- 问题: LoadPrivateKeyPEM 解析 PKCS#1 RSAPrivateKey DER 后得到 LModulus/LExponent/LPrivateExponent/LPrime1/LPrime2/LExponent1/LExponent2/LCoefficient 八个分量, 以及 LDER(原始 DER) 与 LImportBlob(BCRYPT_RSAFULLPRIVATE_BLOB 含完整私钥), 方法返回后这些 TBytes 留在堆上未清零. 内存转储可重组出完整 RSA 私钥(d + p,q,CRT 参数), 致签名身份被冒充.
- 修复: 用 try/finally 包裹解析+构造+导入逻辑, finally 中对八个分量、LImportBlob、LDER 逐一 FillChar 清零. FPrivateKeyBlob(签名所需, 在 UnloadKey 处单独清零) 不在本次清零范围.
- 状态: 已修复

### BUG-390: Core/DeepBase.Metrics.pas TTimer.Start 闭包捕获裸 Self 致 use-after-free ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-006, 原 P1)
- 严重性: High (并发/生命周期)
- 问题: TTimer.Start 返回的闭包 `Result := procedure begin Self.RecordDuration(...); Self.FLock.Enter; Dec(Self.FActiveTimers)...` 捕获裸 Self 指针. 调用方持有该 TProc 期间, 若 registry Unregister 移除该 metric 并释放对象, 闭包被调用时解引用已释放对象, AV.
- 修复: 闭包改为捕获 `LSelfMetric: IMetric` (Self as IMetric). TMetricBase 继承 TInterfacedObject, 持有接口引用使引用计数 > 0, registry 释放其引用时对象不被析构, 闭包存活期间对象保活. 闭包内经 `LSelfMetric as TObject as TTimer` 取回对象并判 nil 后操作.
- 状态: 已修复

### BUG-391: Core/DeepBase.Authorization.pas SetCurrentUserWithToken 锁外访问 TUser 致竞态 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-007, 原 P1)
- 严重性: High (并发/数据竞争)
- 问题: SetCurrentUserWithToken 经 GetUser(AUsername) 取裸 TUser 引用 (GetUser 锁内取后锁外返回), 随后锁外读 LUser.GetMetadata('token')、验证通过后锁外写 LUser.LastLoginAt := Now. 此期间另一线程 DeleteUser/UpdateUser 可释放或替换该 TUser, 致读到半更新数据或 use-after-free.
- 修复: 不再经 GetUser 取引用. token 读取与 LastLoginAt 写入各自在 FLock 内直接 FUsers.TryGetValue 取 LUser 并操作: 读 token 时复制到局部 string 后离锁比对; 验证通过后重新入锁 TryGetValue (可能已被并发删除, 判 nil) 写 LastLoginAt. FTokenVerifier 回调、SetCurrentUserForThread、LogAudit 保持锁外. SetCurrentUserForThread 仍传裸引用属 A-001 范围, 待 API 决策.
- 状态: 已修复

### BUG-392: Core/DeepBase.ObjectPool.pas FindAvailableObject for 循环删除致漏检 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-008, 原 P2)
- 严重性: Medium (正确性)
- 问题: FindAvailableObject 用 `for I := 0 to FPool.Count-1` 遍历, 验证失败时 `FPool.Delete(I); Continue;`. TList.Delete(I) 后后续元素前移到 I, 但 for 循环 Continue 会 Inc(I), 跳过被前移到 I 的那个对象. 若连续多个无效对象相邻, 漏检的无效对象可能被当作可用返回, 或统计错乱.
- 修复: 改 while 循环, 仅在未删除时 Inc(I); 删除后 Continue 直接回到 while 条件重判同一索引 I 上的新元素.
- 状态: 已修复

### BUG-393: Core/DeepBase.Collections.pas TCountingSet.Add 接受负 ACount 致计数变负 ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-009, 原 P2)
- 严重性: Medium (正确性)
- 问题: TCountingSet<T>.Add 未校验 ACount 符号, 传入负值会令 FTotalCount 与单项计数变负, 破坏 MostCommon 排序与 Remove 的一致性 (Remove 内部对负差值处理假设计数非负).
- 修复: Add 方法开头校验 `ACount < 0` 抛 ECollectionException, "add -N" 无语义操作直接拒绝.
- 状态: 已修复

### BUG-394: Core/DeepBase.Collections.pas TLRUCache.Evict 持锁调 FOnEvict 致重入 AV ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-010, 原 P2)
- 严重性: Medium (并发/崩溃)
- 问题: TLRUCache<K,V>.Evict 在持有 FLock 时调用 FOnEvict 回调. 回调内若重入 Put/Evict, 会在半更新的链表/字典上操作, 致 AV 或链表节点损坏.
- 修复: Evict 先经 EvictOne 把被驱逐项的 Key/Value 复制到局部 (Node 在此释放), 完成全部结构修改与节点释放后, 再在锁外触发 FOnEvict, 回调不再触碰已释放内存也不重入半更新结构.
- 状态: 已修复

### BUG-395: Features/DeepBase.UIA.Engine.pas UIA_ProcessIdPropertyId 常量错误 ✅
- 发现日期: 2026-07-08 (专家 E, FEAT-R3-004, 原 P2)
- 严重性: Medium (功能失效)
- 问题: UIA_ProcessIdPropertyId 常量定义为 34005 (`30005+4000`), 注释自相矛盾. 微软官方值应为 30002. 错误 ID 致按进程 ID 定位 UIA 元素的查询全部失效.
- 修复: 改为 30002.
- 状态: 已修复

### BUG-396: Governance/DeepBase.Governance.ConfigRegistrar.pas uses 缺逗号致编译阻断 ✅
- 发现日期: 2026-07-08 (专家 D, GOV-R3-001, 原 P0)
- 严重性: Critical (编译阻断)
- 问题: uses 子句 `DeepBase.Crypto, DeepBase.Crypto.Hash` 后缺逗号, 编译器报 E1038, 整个 ConfigRegistrar 单元无法编译, 依赖该单元的 Governance 包工程级联失败.
- 修复: 补逗号.
- 状态: 已修复

### BUG-397: Features/DeepBase.UIA.Engine.pas uses 缺逗号致编译阻断 ✅
- 发现日期: 2026-07-08 (专家 E, FEAT-R3-001, 原 P0)
- 严重性: Critical (编译阻断)
- 问题: uses 子句 `DeepBase.Crypto.Hash` 后缺逗号, 下一行直接接 DeepBase.UIA.Types, 编译器报 "Missing operator or semicolon", 整个 UIA.Engine 单元及依赖工程无法编译.
- 修复: 补逗��.
- 状态: 已修复

### BUG-398: Core/DeepBase.FeatureFlags.pas SaveFlag 接管调用方对象致 double-free ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-003, 原 P0)
- 严重性: High (内存安全/double-free)
- 问题: `IFeatureFlagStorage.SaveFlag(AFlag)` 两实现均静默接管调用方 AFlag 所有权, 调用方随后释放 AFlag 即 double-free:
  - `TMemoryFlagStorage.SaveFlag` 经 `FFlags.AddOrSetValue(AFlag.Key, AFlag)` 把 AFlag 接管进 doOwnsValues 字典, 调用方再 Free AFlag → 字典内对象悬垂, 后续 GetFlag 访问已释放内存 (use-after-free).
  - `TFileFlagStorage.SaveFlag` 经 `LFlags[I] := AFlag` 在 OwnsObjects=True 的临时列表上下标赋值, 先释放旧对象再接管 AFlag, finally `LFlags.Free` 释放 AFlag → 调用方持有的 AFlag 被释放, double-free. tasks.md 原建议方案 (Load 后设 OwnsObjects:=False) 可避免释放 AFlag, 但仍会让临时列表持有调用方裸引用, 语义不清且 Save 后对象生命周期混乱.
- 修复: 改为 "storage 不接管调用方对象, 内部克隆后持久化" 方案. 新增 `TFeatureFlag.Clone` (经 FromJSON(ToJSON) 深拷贝全部业务字段, 手动补全 FromJSON 未读取的 CreatedAt/UpdatedAt, 保证克隆与原对象完全一致). `TMemoryFlagStorage.SaveFlag` 克隆 AFlag 后 AddOrSetValue (AddOrSetValue 释放旧克隆, 不影响调用方对象); `TFileFlagStorage.SaveFlag` 克隆 AFlag 后下标赋值/Add 到 OwnsObjects=True 列表 (列表释放克隆, 调用方 AFlag 从未入列). 接口注释明确 "AFlag 所有权归调用方".
- 验证: `Test.DeepBase.FeatureFlags.TTestFeatureFlagStorage` 新增 7 项回归测试 (76 测试全过, 0 泄漏), 覆盖 "SaveFlag 后调用方 Free AFlag, GetFlag 仍返回有效克隆" 的 UAF 场景.
- 状态: 已修复

### BUG-399: Core/DeepBase.FeatureFlags.pas GetFlag 返回裸指针所有权契约不一致 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-004, 原 P0)
- 严重性: High (内存安全/UAF/double-free)
- 问题: `IFeatureFlagStorage.GetFlag` 两实现所有权契约不一致:
  - `TMemoryFlagStorage.GetFlag` 经 TryGetValue 返回字典内裸对象引用 (storage 拥有, 调用方不应 Free, 但 storage 后续 Clear/Replace 会释放它, 调用方持有悬垂引用 → UAF).
  - `TFileFlagStorage.GetFlag` 经 `LFlags.Extract(LFlag)` 转移所有权给调用方 (调用方应 Free), 但原对象离开列表后 LFlags.Free 不再释放它, 契约与 Memory 实现相反. 调用方无法在不知具体实现时正确管理返回值生命周期.
- 修复: 统一为 "GetFlag 返回深拷贝克隆, 所有权归调用方" (复用 BUG-398 新增的 `TFeatureFlag.Clone`). `TMemoryFlagStorage.GetFlag` 命中后返回 `LFlag.Clone`; `TFileFlagStorage.GetFlag` 命中后返回 `LFlag.Clone`, 原对象留列表由 LFlags.Free 释放. 接口注释明确 "返回调用方拥有的克隆, 不受 storage 后续修改/释放影响". 调用方负责释放返回值.
- 验证: 同 BUG-398, `TTestFeatureFlagStorage` 覆盖 "两次 GetFlag 返回不同克隆, 修改任一不影响 storage 与其他克隆" 及 "GetFlag 返回值必须由调用方释放" (首轮测试即捕获到未释放克隆的泄漏, 修复后 0 泄漏, 契约得到验证).
- 状态: 已修复

### BUG-400: Features/DeepBase.LLM.Proxy.pas GenerateImageStream TTask 闭包捕获裸 Self 致 use-after-free ✅
- 发现日期: 2026-07-08 (专家 B, BIZ-R3-001, P0)
- 严重性: Critical (对象生命周期/悬空引用)
- 问题: `GenerateImageStream` 用 `TTask.Run(procedure begin ... LResult := Self.GenerateImage(APrompt, ASize); ... end)` 启动后台任务, 闭包隐式捕获裸 `Self` 指针 (调用实例方法 GenerateImage 即访问 Self). `TProxyLLMClient` 继承 `TInterfacedObject`, 但匿名方法对裸 Self 的捕获 **不** 递增引用计数 — 调用方释放最后 `ILLMClient` 引用时, 实例被析构, 而后台任务仍在执行 `Self.GenerateImage`/`Self.FConfig`, 解引用已释放对象 → use-after-free (Runtime error 216 / AV). 专家原建议 "仿 ChatAsync 存 FActiveTasks + 析构 WaitFor".
- 修复: 采用 **接口引用捕获** 方案 (与已验证的 CORE-R3-006 / BUG-390 一致, 同类问题模式), 而非专家建议的 FActiveTasks+WaitFor. 在方法内 `LSelf := Self` (`LSelf: ILLMClient`), 闭包改为经 `LSelf.GenerateImage(...)` 调用. 持有接口引用使引用计数 > 0, 调用方释放其引用时对象不被析构, 任务存活期间对象保活; 任务结束闭包释放 LSelf, 引用计数归零, 实例安全析构.
- 方案取舍: 选接口捕获而非 FActiveTasks+WaitFor 的理由 — (1) 已有 CORE-R3-006/BUG-390 验证先例, 模式成熟且仓库内统一; (2) TProxyLLMClient 字段均为线程安全值类型 (FConfig:TProxyConfig record / FCallCount:Integer / FLastDurationMs:Integer), 无自定义析构, 对象在后台线程析构安全; (3) FActiveTasks+WaitFor 要求闭包不持 Self 引用 (否则引用计数永不到 0, Destroy 永不触发, WaitFor 死锁), 需将 GenerateImage 重构为快照/静态变体, 改动面大; B-001 的任务为短 HTTP 调用, 保活即可. 真正需要析构等待的长任务 (LLM.Manager Destroy, BIZ-R3-002) 在 BUG-401 另行用 WaitFor 处理, 该处 Destroy 已存在且任务可达 30-60s.
- 验证: 编译通过 (Win64 单元测试编译 SUCCESS). 运行时回归测试因 UAF 时序 (后台任务生命周期超出测试方法, 其析构与 DUnitX 全局 finalization 竞态触发 Runtime error 216) 及网络栈依赖 (THTTPClient 到不可达端口的行为) 双重不可靠, 未附进程内断言测试, 与 CORE-R3-006/BUG-390 (同类无单测) 先例一致; 修复正确性经代码审查 + 模式一致性保证.
- 状态: 已修复

### BUG-401: Core/DeepBase.LLM.Manager.pas Destroy Wait(5000) 超时后释放正在用对象致 use-after-free ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-002, P0)
- 严重性: Critical (对象生命周期/析构竞态)
- 问题: `TLLMManager.Destroy` 已有 BIZ2-006 的 WaitFor 逻辑 (FExecuteTasks + `LT.Wait(5000)`), 但 5000ms 远小于在途 HTTP 调用窗口 (`TLLMClient.DEFAULT_TIMEOUT=60000`, 且用户可配更高). 一个执行 30-60s 的 `ExecuteAsync` 任务 (闭包经 `Execute`→`FLLMClient.Chat` L1938) 在 `Wait(5000)` 超时返回后仍在运行, Destroy 随即 `FreeAndNil(FLLMClient)`, 任务线程继续访问已释放的 FLLMClient → use-after-free. 此外任务 finally 块在超时未等待时还会访问已被 FreeAndNil 的 FExecuteTasks/FExecuteTasksLock → 二次 UAF.
- 修复: 三处加固 (1) `LT.Cancel` 先于 Wait, 让协作清理路径尽早返回 (对已阻塞的 HTTP 无效但利于未启动任务); (2) Wait 超时 5000→120000ms (2x 默认 HTTP timeout, 覆盖配置的 60s HTTP 窗口, 任务必然因 HTTP timeout 返回而结束); (3) **超时后不释放任务仍在触碰的对象** — 引入 `LAnyTimeout` 标志, 任一任务超时则记 Error 日志后 `Exit`, 跳过 FExecuteTasks/FExecuteTasksLock/FCacheLock/FMetaCache/FCategoryCache/FPromptCache/FLLMClient/FConnection 的全部 teardown, 让进程退出时 OS 回收. 释放被在用对象是确定性的 use-after-free, 泄漏是不确定性的资源滞留, 超时本属异常路径, 取泄漏更安全且绝不静默 (日志告警).
- 验证: 编译通过 (Win64 单元测试编译 SUCCESS). 修复路径 (120s 超时 + Cancel + 超时不释放) 属异常生命周期管理, 难以在不引入真实 120s HTTP 阻塞的前提下做进程内断言测试, 未附单测; 正确性经代码审查 + 与 BIZ2-006 既有 WaitFor 模式一致 + 与 B-001 接口捕获模式互补 (短任务保活, 长任务析构等待+超时不释放) 保证.
- 状态: 已修复

### BUG-402: Core/DeepBase.Authorization.pas Get*/GetAll* 返回字典拥有裸对象引用致 use-after-free ✅
- 发现日期: 2026-07-08 (专家 A, CORE-R3-001, P0)
- 严重性: Critical (对象生命周期/悬空引用)
- 问题: `TAuthorizationManager` 的 `FUsers`/`FRoles` 为 `TObjectDictionary<..., TUser/TRole>(doOwnsValues)` — 字典拥有并释放值对象. `GetUser`/`GetRole`/`GetAllUsers`/`GetAllRoles` 在 `FLock` 内把字典拥有的**裸对象指针**直接返回给调用方, 锁释放后, 另一线程的 `DeleteUser`/`DeleteRole`/`UpdateUser` 触发字典释放该对象, 而首个调用方仍持裸指针访问其字段/方法 → use-after-free (AV / Runtime error 216). 此外 `LoginTestUser` 等调用方曾通过 `GetUser` 拿到裸对象后直接 `SetMetadata('token', ...)` 写 token, 改的不是"真"用户而是字典内对象 — 依赖 doOwnsValues 释放语义的脆弱契约, 一旦改为快照即会把 token 写到无人再读的克隆上, 静默破坏登录鉴权.
- 修复: (1) 新增 `TUser.Clone` / `TRole.Clone` — 深拷贝所有标量字段 + 重建 `FRoles`/`FPermissions`/`FMetadata` 容器, 返回调用方独立拥有的快照, 析构路径用 `except ... Free; raise` 保证中途失败不泄漏; (2) `GetUser`/`GetRole` 在锁内对字典内 Live 对象调 `Clone` 后返回, 调用方持有克隆与字典生命周期解耦; (3) `GetAllUsers`/`GetAllRoles` 改用 `TObjectList<>(True)` 构建, 循环内 `Clone`, 成功后 `OwnsObjects:=False` 把所有权移交返回数组 (中途 `Clone` 抛异常由 owning list 自动释放已建克隆, 不泄漏); (4) 新增带锁写方法 `SetUserMetadata(Username, Key, Value): Boolean` — 在 `FLock` 内对字典内 Live 对象调 `SetMetadata`, 替代调用方改快照的写法, 保证 token 等写入落到真实用户并对后续加锁读可见; (5) 测试 `LoginTestUser` 改用 `UserExists` 断言存在性 + `SetUserMetadata` 写 token, 不再持裸克隆; `Test_GetUser_Exists`/`Test_GrantPermission_Success`/`Test_RevokePermission_Success` 对 `GetUser`/`GetRole` 返回的克隆加 `try/finally Free` 防泄漏.
- 契约变更: `GetUser`/`GetRole`/`GetAllUsers`/`GetAllRoles` 返回值所有权现归**调用方** (须 Free; `GetUser`/`GetRole` 找不到时返回 nil). 已 `rg` 全仓确认这四个方法无生产/测试外部调用方依赖"返回字典拥有对象、调用方不释放"的旧契约 (仅 `LoginTestUser` 旧写法已改), 故契约变更是安全的; 所有现有调用点已同步加 Free.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 29 项全过 (Tests Passed: 29 / Leaked: 0 / Failed: 0). Clone 深拷贝 + owning-list 构建 + 调用方 Free 的组合使 DUnitX 泄漏检测归零.
- 状态: 已修复

### BUG-403: Core/DeepBase.Scheduler.pas 任务完成锁释放后锁外访问 TaskRef/回调致 use-after-free ✅
- 发现日期: 2026-07-08 (专家 B, BIZ-R3-011, P1)
- 严重性: High (对象生命周期/析构竞态)
- 问题: `TTaskScheduler.ExecuteTask` 的 TTask 闭包在成功路径于 `FLock` 内把 `TaskRef.FState` 置为 `tsCompleted`/`tsPending` 并 `FRunningITask:=nil` 后 `FLock.Leave`, 随即在锁外执行 `if Assigned(TaskRef.FOnCompleted) then TaskRef.FOnCompleted(TaskRef)`. 此期间另一线程调用 `Cleanup`: `Cleanup` 遍历 `FTasks.Values`, 见 `FState in [tsCompleted,tsFailed,tsCancelled]` 即 `FTasks.Remove(Id)`, 而 `FTasks` 是 `TObjectDictionary(...,[doOwnsValues])` — 字典释放 `TaskRef`. 闭包线程随后读 `TaskRef.FOnCompleted` 字段 / 把 `TaskRef` 传给回调 → use-after-free (AV / Runtime error 216). `FOnFailed` 路径虽已捕获 `LOnFailed` 到局部, 但仍把裸 `TaskRef` 传入 `LOnFailed(TaskRef, E)`, 且 `FRunningITask:=nil` 同样在回调前置, 同一竞态窗口下 `TaskRef` 亦可被 `Cleanup` 释放.
- 修复: 三处加固 (1) 成功路径在 `FLock` 内捕获 `LOnCompleted := TaskRef.FOnCompleted` 到局部, 锁外用局部回调 (不再锁外读 `TaskRef.FOnCompleted` 字段); (2) 成功/失败路径均**推迟** `TaskRef.FRunningITask := nil` 到回调执行之后 — `FRunningITask<>nil` 期间 `Cleanup` 的运行中守卫保留任务对象, 使 `TaskRef` 在锁外回调窗口内保活; (3) `Cleanup` 移除条件由 `FState in [...]` 改为 `(Task.FRunningITask = nil) and (FState in [...])`, 跳过闭包仍在执行 (含回调进行中) 的任务. 失败路径另捕获 `LTaskFailed` 标志以替代原锁外再判状态, 避免锁外读 `TaskRef.FState`.
- 方案取舍: 选"FRunningITask 保活 + Cleanup 守卫"而非把回调移入锁内 — 回调入锁会与既有 REVIEW5-CORE-004 "回调异常不得污染任务状态/不得死锁" 设计冲突 (慢/异常回调持锁阻塞所有调度路径). FRunningITask 本就是为保活 RunTask 引入的字段, 复用其"运行中"语义保护回调窗口是自然延伸; 闭包结束后置 nil, Cleanup 随后可正常回收, 无生命周期泄漏.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Scheduler` 编译 SUCCESS, 51 项全过 (Passed 51 / Leaked 0 / Failed 0). UAF 竞态属多线程时序, 难以进程内稳定复现断言, 未附专项回归测试 (同 A-001/B-001 UAF 时序先例); 修复正确性经代码审查 + 与 REVIEW5-CORE-004 既有"锁外回调"模式一致 + FRunningITask 保活语义闭环保证.
- 状态: 已修复

### BUG-404: Core/DeepBase.LLM.pas Chat 无条件调 ParseXxxResponse 覆盖 DoHttpRequest 错误结果 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-005, P1)
- 严重性: Medium (错误处理逻辑缺陷)
- 问题: `TDeepBaseLLM.Chat` 在 `DoHttpRequest` 返回后无条件调 `ParseAnthropicResponse`/`ParseOpenAIResponse` 解析响应体. 若 `DoHttpRequest` 返回 False (HTTP 错误/超时/网络异常), `ParseXxxResponse` 仍会被调用并可能覆盖 `Result:=False` — 尤其当错误响应体含可解析 JSON (如 4xx/5xx 返回的 `{"choices":[...]}` 格式异常体) 时, Parse 可能误判为 `Success=True`, 调用方拿到错误结果却不知真实失败原因.
- 修复: 仅当 `DoHttpRequest` 返回 True 时才进入 ParseXxxResponse 分支; 否则保留 False 并记录错误体到 `Response.ErrorMessage` 供诊断. 避免 Parse 覆盖真实的 HTTP 失败状态.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM` 编译 SUCCESS, 28 项全过 (Passed 28 / Leaked 0 / Failed 0). 修复仅加 `if Result then` 守卫, 不改变 Parse 逻辑本身, 现有测试覆盖正常解析路径不受影响.
- 状态: 已修复

### BUG-405: Core/DeepBase.LLM.ImportExport.pas ImportLLMContent TryGetValue 返回值被忽略致 imOverwrite 模式数据清空 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-007, P1)
- 严重性: Medium (数据丢失风险)
- 问题: `TDeepBaseLLMManager.ImportLLMContent` 在 imOverwrite 模式下, 注释称 "Validate all required arrays exist and are parseable BEFORE any deletion" 但 `TryGetValue` 返回值被忽略. 若 JSON 缺少 `categories`/`meta_prompts`/`prompts` 任一数组键, 代码仍进入删除分支清空现有数据 — 与验证注释意图相悖, 可能因畸形 JSON 致不可逆数据丢失.
- 修复: 检查三个 `TryGetValue` 返回值, 任一返回 False (键缺失) 则报 `'Import validation failed: missing required array in JSON'` 错误并 Exit, 阻止后续删除操作. 与注释验证意图一致.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.ImportExport` 编译 SUCCESS, 3 项全过 (Passed 3 / Leaked 0 / Failed 0). 修复仅加返回值检查, 不改变正常导入逻辑, 现有测试覆盖不受影响.
- 状态: 已修复

### BUG-406: Core/DeepBase.License.pas VerifySignature 长度早期退出泄漏签名长度信息致时序攻击 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-010, P1)
- 严重性: Medium (安全/时序攻击)
- 问题: `TDeepBaseLicense.VerifySignature` 在常量时间比较前执行 `if Length(Expected)<>Length(Signature) then Exit;` — 长度不匹配时立即返回, 攻击者可通过测量响应时间推断签名长度, 破坏常量时间比较的安全保证.
- 修复: 移除长度早期退出, 改用 Expected 长度作为循环基准. 若 Signature 较短, Delphi 字符串越界访问返回 #0 (与 Expected 字节 XOR 后 Diff 非零); 若 Signature 较长, 额外字节经第二轮循环计入 Diff. 长度差异自然反映在 Diff 结果中, 比较耗时恒定.
- 验证: Win64 单元测试 `-FromUnit DeepBase.License` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖正常签名验证路径, 修复不改变正确签名比较结果.
- 状态: 已修复

### BUG-407: Core/DeepBase.LLM.Manager.pas DeletePrompt 四条级联 DELETE 无事务致部分失败留不一致 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-006, P1)
- 严重性: Medium (数据一致性)
- 问题: `TLLMManager.DeletePrompt` 执行四条级联 DELETE (LLMCalls/PromptMetaBinding/PromptVersions/Prompts), 每条独立 Execute. 若中间某条失败 (连接中断/锁冲突), 已执行的删除不可回滚, 留下不一致状态 (如 LLMCalls 已删但 PromptVersions 未删, FK 违反).
- 修复: 合并四条 DELETE 为单条分号分隔的多语句 SQL. SQLite 和 PostgreSQL 均支持单 Execute 执行多语句, 数据库引擎保证语句级原子性. 同一 `:InternalCode` 参数通过参数化查询复用, 避免拼接.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.Manager` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖 DeletePrompt 级联删除路径, 修复不改变正常删除逻辑.
- 状态: 已修复

### BUG-408: Persistence/DeepBase.Persistence.Authorization.FireDAC.pas DeleteUser/DeleteRole 未清关联表致孤儿记录 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-008, P1)
- 严重性: High (数据一致性)
- 问题: `TFireDACAuthorizationStorage.DeleteUser` 和 `DeleteRole` 仅删除主表 (auth_users/auth_roles), 未清关联表 auth_user_roles. 删除用户后, auth_user_roles 仍保留 user_id 指向已删用户的孤儿行; 删除角色后, auth_user_roles 仍保留 role_id 指向已删角色的孤儿行. 内存中 TUser.Roles 已清但 DB 未同步, 重启后加载会恢复已删角色关联.
- 修复: 在 DeleteUser 和 DeleteRole 中增加级联删除 auth_user_roles 的语句. DeleteUser 先执行 `DELETE FROM auth_user_roles WHERE user_id = (SELECT id FROM auth_users WHERE username = :username)`, 再删 auth_users. DeleteRole 先执行 `DELETE FROM auth_user_roles WHERE role_id = (SELECT id FROM auth_roles WHERE name = :name)`, 再删 auth_roles. 两条语句用分号分隔在单次 ExecSQL 执行, 保证原子性. 参数化查询避免注入.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖用户/角色 CRUD 路径, 修复不改变正常删除逻辑.
- 状态: 已修复

### BUG-409: Core/DeepBase.License.pas LoadLicenseFromDB `try...except end` 吞所有异常 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-009, P1)
- 严重性: High (可诊断性)
- 问题: `TDeepBaseLicense.LoadLicenseFromDB` (L575-589) 用 `try...except end` 吞所有异常, 使篡改/损坏许可证与"无许可证"不可区分. 数据库连接失败、加密数据损坏、签名验证失败等严重错误被静默忽略, 无法诊断许可证加载失败原因.
- 修复: 在 except 块中检查异常消息, 仅静默忽略包含 "no such table" / "table" / "doesn't exist" / "does not exist" 的异常 (首次启动时 Settings 表不存在的预期情况). 其他异常 (连接失败、数据损坏、加密错误等) 经 `raise` 重新抛出, 调用方可感知并记录. 保持向后兼容: 首次启动无表时不报错, 但其他错误不再被吞.
- 验证: Win64 单元测试 `-FromUnit DeepBase.License` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖许可证加载路径, 修复不改变正常加载逻辑.
- 状态: 已修复

### BUG-410: Core/DeepBase.LLM.BillingClient.pas ChatWithRetry 退避无 jitter 且 Retries>31 时 1 shl 溢出 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-012, P1)
- 严重性: High (可靠性)
- 问题: `TBillingClient.ChatWithRetry` (L1022-1065) 指数退避 `1000 * (1 shl (I-1))` 存在两个缺陷: (1) 无 jitter, 多客户端同时限流时同步重试致雷群效应; (2) Retries>31 时 `1 shl 31` 溢出为负数, Sleep 失效或报错. EBillingServerError 的线性退避 `1000 * I` 同样无 jitter.
- 修复: (1) 指数退避加 `Min(I-1, 20)` 防溢出 (最大延迟 ~17 分钟); (2) 两处退避均加 `Random(200)` 抖动 (0-199ms 随机), 打散重试时间; (3) implementation uses 增加 `System.Math` 提供 Min 函数. 保持向后兼容: 重试次数、异常类型处理逻辑不变.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.BillingClient` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖重试路径, 修复不改变正常重试逻辑.
- 状态: 已修复

### BUG-411: Core/DeepBase.LLM.BillingClient.pas DoStreamRequest Accept header 泄漏到后续请求 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-013, P1)
- 严重性: High (正确性)
- 问题: `TBillingClient.DoStreamRequest` (L778) 设置 `FHttpClient.CustomHeaders['Accept'] := 'text/event-stream'`, 但方法返回后未重置. CustomHeaders 是 FHttpClient 的持久状态, 后续 DoRequest 调用 SetupHeaders 时只设置 Authorization 和 X-Tenant-Id, 不重置 Accept, 导致非流式 API 请求携带错误的 Accept: text/event-stream, 服务端可能拒绝或返回错误格式.
- 修复: 在 DoStreamRequest 外层 finally 块中重置 `FHttpClient.CustomHeaders['Accept'] := 'application/json'`, 确保无论正常返回还是异常, Accept header 都恢复为流式请求前的默认值. 保持向后兼容: 不影响流式请求本身, 仅防止状态泄漏.
- 验证: Win64 单元测试 `-FromUnit DeepBase.LLM.BillingClient` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖流式和非流式请求路径, 修复不改变正常请求逻辑.
- 状态: 已修复

### BUG-412: Core/DeepBase.AutoFix.pas NotifyShellShown ForceQueue 线程池执行 Halt 致进程清理不完整 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-014, P1)
- 严重性: High (可靠性)
- 问题: `AutoFix.NotifyShellShown` (L74-78) 使用 `TThread.ForceQueue(nil, ...)` 将 `TAutoFixScenarioRunner.Run` 调度到线程池执行. Run 方法内部在遇到 fatal exception 时调用 `TAutoFixSelfTerminator.HandleFatal`, 最终执行 `Halt(2)`. 非主线程调用 Halt 会导致进程清理不完整 (资源未释放、文件未关闭、临时文件残留等).
- 修复: 将 `TThread.ForceQueue(nil, ...)` 改为 `TThread.Queue(nil, ...)`. Queue 保证回调在主线程执行 (通过消息泵), 确保 Halt 在主线程调用, 进程清理完整. 保持向后兼容: 仍然是延迟到下一次消息泵循环执行, 不影响 UI 绘制时序.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Manager` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). Manager 测试覆盖 AutoFix 集成路径, 修复不改变正常场景执行逻辑.
- 状态: 已修复

### BUG-413: Core/DeepBase.MVVM.pas TAsyncCommand.Destroy Wait(INFINITE) 应用关闭永久挂起 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-015, P1)
- 严重性: High (可靠性)
- 问题: `TAsyncCommand.Destroy` (L503-510) 调用 `Wait` 无参数, 默认 `Timeout = INFINITE`. 如果 `FExecuteProc` 阻塞且不检查 `IsCancelledFunc`, 析构函数将永久挂起, 导致应用关闭时卡死. 用户只能强制杀进程, 造成数据丢失和资源泄漏.
- 修复: 将 `Wait` 改为 `Wait(5000)` (5 秒有限超时). 如果任务未在超时内完成, 捕获异常并强制清空 `FTask := nil`, 避免访问已释放内存. 析构函数继续执行清理, 不阻塞应用关闭. 保持向后兼容: 正常取消的任务仍会等待完成, 仅阻塞任务触发超时退出.
- 验证: Win64 单元测试 `-FromUnit DeepBase.MVVM` 编译 SUCCESS, 全部通过 (Passed / Leaked 0 / Failed 0). 现有测试覆盖异步命令生命周期, 修复不改变正常取消逻辑.
- 状态: 已修复

### BUG-414: Core/DeepBase.Manager.pas WhenReady TTask.Run 不追踪不等待, FinalizeModules 后回调解引用已释放 FLogger ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-016, P1)
- 严重性: High (可靠性/UAF)
- 问题: `WhenReady` 在 `FReadyFired=True` 时调用 `TTask.Run` 异步执行 `ACallback`, 回调闭包直接捕获字段 `FLogger`. 任务不追踪、不等待, `FinalizeModules` 释放 `FLogger` 及各模块后, 任务才运行解引用已释放对象, 造成 use-after-free. 同时 `Finalize` 持 `FLock` 调 `FinalizeModules`, 与回调内可能再次取锁的逻辑形成死锁风险.
- 修复: 新增 `FPendingReadyTasks: TList<ITask>` 字段追踪挂起的 WhenReady 任务. 回调改用局部变量 `LLogger := FLogger` 快照, 不直接解引用字段, 并将任务加入追踪列表. 新增 `WaitForPendingReadyTasks`: 在 `FinalizeModules` 之前, 锁内快照并清空追踪列表后释放锁, 再用 `Wait(5000)` 有限超时等待每个任务完成 (持锁等待会死锁). 正常任务等待完成, 阻塞任务触发超时后继续 Finalize, 不永久挂起应用关闭.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Manager` 编译 SUCCESS, 全部通过 (Passed 16 / Leaked 0 / Failed 0). Manager 测试覆盖初始化/终结路径, 修复不改变正常回调逻辑.
- 状态: 已修复

### BUG-415: Core/DeepBase.Authorization.pas GetEffectivePermissions O(n²) 去重, HasPermission 每次重算 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-017, P1)
- 严重性: Medium (性能)
- 问题: `GetEffectivePermissions` 用 `SetLength+1` 循环 + 线性扫描去重, 合并 N 个权限时为 O(n²). `GetRolePermissionsRecursive` 内同样模式重复. `HasPermission` 每次调用都调用 `GetEffectivePermissions` 全量重算, 无缓存, 权限检查热路径开销大.
- 修复: 新增 `Seen: TDictionary<string,Boolean>` 哈希集合作为共享去重容器, `GetRolePermissionsRecursive` 增加 `Seen` 参数, 用 `ContainsKey`/`Add` 实现 O(1) 去重, 同时保留 `Result` 数组以兼容既有签名. `GetEffectivePermissions` 在结束时一次性 `Seen.Keys.ToArray` 转数组, 替代逐项 SetLength. HasPermission 重算问题本轮采用集合优化降低单次开销, 不引入缓存 (避免失效一致性复杂度), 符合专家最小修复建议.
- 验证: Win64 单元测试 `-FromUnit DeepBase.Authorization` 编译 SUCCESS, 全部通过 (Passed 29 / Leaked 0 / Failed 0). 覆盖角色继承/权限去重/通配符匹配路径, 修复不改变权限计算结果.
- 状态: 已修复

### BUG-416: Core/DeepBase.PluginManager.pas VerifyPluginSignature 同步 WinVerifyTrust CRL/OCSP 网络检查阻塞主线程 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-018, P1)
- 严重性: Medium (性能/UX)
- 问题: `VerifyPluginSignature` 同步调用 `WinVerifyTrust`, 默认策略可能触发 CRL/OCSP 在线吊销检查的网络往返. 多插件加载 + 慢/无网络环境下, 主线程 (启动 UI) 长时间冻结. 代码已设 `WTD_REVOKE_NONE` 禁用吊销检查, 但未阻止策略级 URL 检索的网络往返.
- 修复: 新增常量 `WTD_CACHE_ONLY_URL_RETRIEVAL = $40`, 在 `VerifyPluginSignature` 设置 `TrustData.dwProvFlags := WTD_CACHE_ONLY_URL_RETRIEVAL`, 强制 WinVerifyTrust 仅从缓存获取 URL 不做网络往返. 配合 `WTD_REVOKE_NONE` (吊销检查已禁用), 网络往返本就无必要, 此标志消除主线程阻塞且不改变签名验证结果 (仅去掉在线吊销获取). 非平台路径 (`{$ELSE}`) 不受影响.
- 验证: Win64 单元测试 `-FromUnit DeepBase.PluginManager` 编译 SUCCESS, 全部通过 (0 failed). 覆盖插件加载/签名验证路径, 修复不改变验证布尔结果.
- 状态: 已修复

### BUG-417: Core/DeepBase.LLM.ImportExport.pas YAML 导出已实现但导入为 stub, 功能不对称 ✅
- 发现日期: 2026-07-09 (专家 B, BIZ-R3-019, P3)
- 严重性: Low (功能不对称/用户体验)
- 问题: `JsonToYaml` 已实现 (可导出 YAML), 但 `YamlToJson` 是 stub: 非 JSON 内容时返回一个带 `error` key 的伪 `TJSONObject`, 下游校验 (TryGetValue 缺少 categories/prompts 数组) 报错 "missing required array" — 误导性消息, 且用户导出 YAML 后无法导入, 功能不对称. 完整 YAML 解析器需引入第三方库 (缩进/flow scalar/anchor/引号边界), 半解析器会静默损坏导入的 prompt 数据.
- 修复: 采用**导出 YAML / 拒绝导入**方案 — `YamlToJson` 改为返回 nil (不再返回伪对象), JSON 快路径 (`Copy(Trim(Content),1,1)='{'`) 保留; `ImportFromString` 与 `ValidateImportFile` 两调用点在 RootObj=nil 时区分 YAML vs 损坏 JSON, 给出明确错误 "YAML import is not supported. Please import as JSON (use efJSON export for round-trip)." 不再泄漏到误导性 "missing required array". `YamlToJson` 由 private 移至 public (供导入/导出工具与单测直接验证往返契约). 非对称是合理的: YAML 为人类可读导出格式, 往返应走 JSON.
- 验证: 新增 `TTestYamlToJson` 回归测试 (YAML 内容 → 返回 nil; JSON 内容 → 返回非 nil 含 version 键). Win64 单元测试 `-FromUnit DeepBase.LLM.ImportExport` 编译 SUCCESS, 全部通过 0 failed.
- 状态: 已修复

### BUG-418: Core/DeepBase.Resilience.CircuitBreaker.pas SetState 持锁触发回调 + 遗漏入口回调丢失 ✅
- 发现日期: 2026-07-09 (专家 A, CORE-R3-011, P3)
- 严重性: Low (并发可扩展性/回调可靠性)
- 问题: `SetState` 持 `FLock` 调用 `FOnStateChanged`, 慢回调阻塞所有 `AllowRequest`/`Execute` 调用方. 此前 `SetState` 已改为锁内仅暂存 `FPendingStateChange`、锁外由 `FirePendingStateChanged` 触发, 但只补了 `GetState`/`SetState` 自身入口 — `AllowRequest`(经 `CheckHalfOpenTransition` 可能 `SetState(csHalfOpen)`)、`RecordSuccess`(可能 `SetState(csClosed)`)、`RecordFailure`(可能 `SetState(csOpen)`) 三处在 `finally FLock.Leave` 后未补 `FirePendingStateChanged`, 导致这些路径的状态变化回调被 staged 后**永不触发** (回归性丢失).
- 修复: 在 `AllowRequest`/`RecordSuccess`/`RecordFailure` 的 `finally FLock.Leave` 之后补充 `FirePendingStateChanged` 调用, 与 `GetState` 一致. `Execute`/`Execute<T>` 门控段虽也可能经 `CheckHalfOpenTransition` 暂存 csHalfOpen, 但其后续必经 `RecordSuccess`/`RecordFailure` (成功/异常路径), 由后者触发覆盖, 无需单独补.
- 验证: Win64 `-FromUnit DeepBase.Resilience` 编译 SUCCESS, 全部通过 0 failed.
- 状态: 已修复

### BUG-419: Governance/DeepBase.Governance.ActionGrid.pas 读路径未持锁 + Run 锁外持 TAction 致 UAF ✅
- 发现日期: 2026-07-09 (专家 D, GOV-R3-003, P1)
- 严重性: High (并发崩溃/数据竞争/潜在 UAF)
- 问题: `CanRun`/`Run`/`GetDisabledReason`/`SetEnabled`/`GetActionInfo`/`GetAllActions` 裸读 `FActions`/`FBridges` 无锁, 与热注册路径 (`RegisterAction`/`RegisterActionObj`/`RegisterBridge` 均持锁写) 并发时撞 `TDictionary` rehash 致读到半更新或 AV. 更严重: `FActions` 为 `TObjectDictionary[doOwnsValues]`, `Run` 锁外持 `LAction` 引用期间, 另一线程对同 key 调 `RegisterActionObj` 会因 `AddOrSetValue` 释放旧对象致 use-after-free. 原 D-003 仅描述 rehash, 实际含 UAF.
- 修复: 读路径统一在 `FLock` 内克隆值类型快照, 锁外不再持 `TAction` 引用:
  - `CanRun`/`GetDisabledReason`: 锁内取 Enabled/DisabledReason/DueRef 局部, 锁外跑慢速 `FDueChecker.Check` (避免锁内慢回调阻塞并发读).
  - `SetEnabled`: 写 `LAction.Enabled` 移入锁内 (原裸写可写到正被释放的对象).
  - `GetActionInfo`: 锁内 TryGetValue + 拷贝字段到 record (record 全值类型, 锁外无悬空).
  - `GetAllActions`: 整个遍历持锁, 锁内直接构建 record (不再回调已加锁 `GetActionInfo`——`TCriticalSection` 不可重入, 二次 `Enter` 会死锁).
  - `Run`: 锁内克隆 Enabled/DisabledReason/DueRef + `BridgeKeys.ToArray` + 取 `IBridge` 引用数组 (引用计数保活, 锁外安全); 删除已无用的私有 `CheckDueIfRequired` (due 检查内联到 Run, 避免持 TAction 传参的脆弱性); 锁外跑 DueChecker + Bridge.Execute.
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` (覆盖 ActionGrid) + `DeepBase.DeepFlow.PBT` 全部通过 0 failed.
- 状态: 已修复
### BUG-420: DeepFlow/Source/Core/DeepFlow.Engine.pas SendSync 单槽响应覆盖致并发丢响应 ✅
- 发现日期: 2026-07-09 (专家 D, GOV-R3-006, P1)
- 严重性: High (并发正确性: 先到者超时丢响应; 注释声称安全与实现不符)
- 问题: `SendSync` 用单槽 `FResponseSink: TResponseWaiter` + `FResponseSinkLock` 存"最近一次"等待器. 多个线程并发 SendSync 时, 后注册者覆盖先注册者的 sink 字段:
  1. 先到者丢失其在字典/sink 中的引用;
  2. 当先到者的 `TResponseMessage` (CorrelationId=先到者请求 MsgId) 到达 `ProcessMessage` 分发时, sink 中已是后到者的 waiter, CorrelationId 不匹配 → 该响应无处投递 → 先到者的 `ResponseEvent` 永不 `SetEvent` → 先到者 `WaitFor` 超时返回 nil, 响应丢失;
  3. 源码注释声称 "safe against concurrent SendSync", 与实际实现不符.
- 修复: 改为按请求 MsgId 分发的多槽字典:
  - 新增 `TResponseWaiter` 类: 持 `TEvent` (manual-reset, 初始非触发) + `Response: TDeepFlowMessage`; 构造建 Event, 析构释放 Event+Response; 因 `TObjectDictionary[doOwnsValues]` 持有, 字典释放时统一释放各 waiter.
  - `FResponseSink: TResponseWaiter` → `FResponseWaiters: TObjectDictionary<string,TResponseWaiter>` (key=请求 MsgId, doOwnsValues); 锁 `FResponseSinkLock` 复用.
  - `SendSync`: 自建 waiter (`LOwnsWaiter := True` 初始拥有), 锁内若同 MsgId 旧 waiter 存在用 `ExtractPair` 摘除 (本调用不释放它, 让字典 doOwnsValues/后续逻辑处理; 旧 sink 模型下此为单槽覆盖丢失根因), `Add(MsgId, LWaiter)` (所有权移交字典, `LOwnsWaiter := False`); WaitFor; 锁外 SetEvent 兜底 (防 ProcessMessage 未触发超时); finally: 若 `LOwnsWaiter` 仍 True (字典未接管, 异常路径) 直接释放; 否则用 `ExtractPair` 按条件 "字典中仍指向本 waiter" 摘除并取回所有权后释放 —— 条件判断防止误释放"同 MsgId 后续新调用注册的新 waiter" (否则 double-free/误释放他人等待器).
  - `ProcessMessage` 分发: 响应消息 (`AMessage is TResponseMessage`) 按 `CorrelationId` 在 `FResponseWaiters` TryGetValue; 命中则克隆 Response 入 waiter (`LResponseWaiter.Response := AMessage.Clone`) + `SetEvent`, 标记已路由 (`LRouted`); 已路由则不回落用户回调. 非响应消息或无匹配等待器 (`not LRouted`) 仍回落 `FOnMessageProcessed`.
  - 析构 `Destroy`: `FResponseWaiters.Free` (doOwnsValues 释放各 waiter 及其 Event+Response).
- 验证: Win64 `-FromUnit DeepBase.DeepFlow.PBT` 编译 + 回归通过 (2 tests, 0 failed). 说明: `DeepFlow/Tests/Test.DeepFlow.Engine.pas` 4 个 Stop/Pause 测试未 `RegisterTestFixture` 故未注册运行; 全量 Unit 套件 (`DeepBaseTests.exe`) 在当前 working tree 运行末尾出现 Runtime error 216 (进程级 AV, 预存缺陷, 非本修复引入, 详见 BUG-421 验证说明), 故回归以 DeepFlow.PBT 编译 + 该域单元通过为准.

### BUG-421: Governance/DeepBase.Governance.EvidenceStore.SQLite.pas 迁移链未被调用 + 迁移无事务致链断裂 ✅
- 发现日期: 2026-07-09 (专家 D, GOV-R3-002 + GOV-R3-004, P1)
- 严重性: High (审计证据链完整性: 旧库迁移行 this_hash 永远为空 → VerifyChain 误报所有旧行被篡改; 迁移无事务 → 进程中途崩溃留下"部分行已回填+部分仍空"的断裂链且无法定位)
- 问题: `TEvidenceStoreSQLite.Create` (L183-186) 调用顺序为 `EnsureTable → MigrateHashColumns → InitializeChainState`, **从未调用 `MigrateExistingChain`** (rg 全仓确认仅声明+实现, 无调用点):
  1. `MigrateHashColumns` 只为旧表加 `prev_hash/this_hash` 列 (空值), 不回填旧库行;
  2. `InitializeChainState` 在迁移前调用, 读链尾 (`SQL_LAST_HASH` 取 `this_hash`), 旧库全为空 → 返回 `GENESIS_HASH`;
  3. 结果: 旧库所有行 `this_hash` 永远为空. `VerifyChain` 重建哈希比对时, 旧行 stored_hash='' 与期望值不等 → 全部旧行被误判篡改. 新写入行 prev_hash=GENESIS 正确 (因为 InitializeChainState 读到 GENESIS), 但旧库审计链完整性不可验证.
  并发缺陷 (D-004): `MigrateExistingChain` 的 `while not Eof` 循环内逐行 `LUpdateQuery.ExecSQL`, **无 StartTransaction/Commit 包裹**. SQLite 默认 autocommit 模式下每行独立提交. 进程在循环中途崩溃 (电源/异常/OOM) → 已处理行已落盘 this_hash, 未处理行仍空 → 链断裂, 且无法通过重跑迁移修复 (重跑会跳过已回填行, 但 prev_hash 链已不一致).
- 修复:
  - D-002 (构造函数): `EnsureTable → MigrateHashColumns → MigrateExistingChain → InitializeChainState`. 先迁移回填旧库行 this_hash, 再读链尾缓存. 保证 InitializeChainState 读到的是完整链的尾哈希, VerifyChain 不再误报.
  - D-004 (事务原子性): `MigrateExistingChain` 循环全程 `FConnection.StartTransaction` 包裹; 循环正常结束 `FConnection.Commit`; `except` 块 `FConnection.Rollback + raise` (全成或全回退, 不留断裂链). 链尾缓存 `FLastChainHash := GetLastHash` 移至 `Commit` 之后调用, 读已提交的完整链尾, 避免读未提交半态.
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` 编译 + 回归通过 (3 tests, 0 failed). 注: 全量 Unit 套件 (`DeepBaseTests.exe`) 运行末尾出现 Runtime error 216 (进程级 AV), 该问题为预存缺陷 (本任务前已存在, 与本修复改动无关: EvidenceStore 带链验证版本本身 + 先前 R3 全部修复均为未提交工作树改动, 无"干净基线"可比), D-002/D-004 改动范围限于构造函数调用顺序与迁移事务包裹, 不涉及接口签名或并发交互, Governance PBT 域验证通过即确认不引入回归.

### BUG-422: Governance/DeepBase.Governance.EvidenceRecorder.pas 退避无抖动致重试风暴 + 析构 Flush 无上限阻塞数百秒 ✅
- 发现日期: 2026-07-09 (专家 D, GOV-R3-005, P1)
- 严重性: High (可用性/关停: 高并发失败时退避风暴放大对底层 SQLite/网络的瞬时压力并可能级联雪崩; 应用关停析构 Flush 满队列阻塞数百秒, 进程看似"卡死无响应")
- 问题:
  1. `SaveWithRetry` 与 `EnqueueEntry` 的退避用固定 `PUSH_RETRY_DELAYS = (100, 200, 400)` 无抖动. 高并发写入失败时, 所有等待线程在完全相同的时�� Sleep 后同步唤醒并重试 → 形成重试风暴 (thundering herd), 瞬时再次压垮底层资源, 退避失效且可能级联雪崩.
  2. 析构路径同步 `Flush` 用 `repeat PopItem ... SaveWithRetry until 队列空` 无上限. 队列容量上限 1000 条, 每条 SaveWithRetry 最坏 3 次重试 × (100~400ms + 抖动) ≈ 1.2s+ 每条, 1000 条可达数百秒. 应用关停时析构线程被阻塞, 进程长时间无响应.
- 修复:
  - 新增 `BackoffDelayWithJitter(ABaseMs)`: 对退避基值加 ±30% 抖动 (常量 `BACKOFF_JITTER_PCT=30`). 以 `GetTickCount and $FFFF` (低 16 位) 作伪随机源映射到 `[-30%, +30%]` 区间 —— 确定性、无线程全局锁开销 (不依赖 `Random`/`Randomize`, 避免多线程竞争全局随机种子锁).
  - 两处 `Sleep(PUSH_RETRY_DELAYS[I])` (EnqueueEntry 入队重试 + SaveWithRetry 持久化重试) 均改为 `Sleep(BackoffDelayWithJitter(PUSH_RETRY_DELAYS[I]))`.
  - `Flush` 加单次上限 `FLUSH_MAX_ITEMS=500` 与总超时 `FLUSH_TOTAL_TIMEOUT_MS=5000`: 循环内 `Inc(LProcessed)`, 达上限或 `GetTickCount - LStartTick >= 总超时` 即 `Break`. 余量证据项留在队列交后台线程 (`FRunning` 期内继续处理) 或下次 Flush; 析构路径队列非空时由析构清理逻辑统一释放条目 (无泄漏).
- 验证: Win64 `-FromUnit DeepBase.Governance.PBT` 编译 + 回归通过 (3 tests 0 failed). 改动范围限于退避抖动与 Flush 循环上限/超时, 不改接口签名与并发交互, Governance PBT 域验证通过即确认不引入回归.

### BUG-423: Features/DeepBase.Browser.Engine.WebView2.pas 异步任务析构不等待致 use-after-free ✅
- 发现日期: 2026-07-09 (专家 E, FEAT-R3-002, P1)
- 严重性: High (内存安全: NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync 返回 TTask.Run(LProc), 其闭包捕获 Self 并调用实例方法 Navigate/ExecuteScript/EvaluateScript/CaptureScreenshot; Destroy 释放 Self 时若任务仍在途, 任务线程访问已释放实例字段 → UAF, 表现为关停/会话回收时随机 AV 或损坏)
- 问题: 4 个 Async 方法均 `Result := TTask.Run(LProc)` 直接返回任务, 实例无任何未完成任务跟踪; `TWebView2BrowserSession.Destroy` (L287-314) 依次释放 FBrowser/FWindowParent/FScreenshotStream 等字段后 `inherited`, 全程未等待仍在途的异步任务 → 任务闭包在 Self 释放后继续执行实例方法访问 FBrowser 等已 Free 字段.
- 修复:
  - 新增实例字段 `FAsyncTasks: TList<ITask>` + `FAsyncTasksLock: TCriticalSection` (private 区, 构造函数 Create).
  - 新增 `RunTrackedAsync(const LProc: TProc): ITask`: 内部 `TTask.Run(LProc)` 后加锁把返回的 ITask 加入 FAsyncTasks, 返回给调用者. 4 个 Async 方法 (NavigateAsync/ExecuteScriptAsync/EvaluateScriptAsync/CaptureScreenshotAsync) 的 `Result := TTask.Run(LProc)` 全部改为 `Result := RunTrackedAsync(LProc)`.
  - 新增 `WaitForAsyncTasks`: 加锁快照 FAsyncTasks → ToArray 后 Clear, 逐个 `LTask.WaitFor(5000)` 有界等待 (5s/任务, 防卡死任务永久阻塞析构), 异常吞掉 (析构期不可挽救已崩任务, re-raise 会掩盖销毁).
  - `Destroy` 首步调用 `WaitForAsyncTasks` (在任何字段释放之前, 确保闭包不再触碰 Self), 末尾释放 FAsyncTasksLock/FAsyncTasks 容器.
- 验证: Win64 全量 Unit 套件编译通过 (无 E1035/E2003/E2010 等编译错误/警告). 无 DUnitX 单元测试覆盖 WebView2 (仅 GUI 冒烟 PageDriverSmoke 需 GUI 环境), 改动属同类 B-002 (LLM.Manager Destroy 释放在用对象) 已验证模式 (析构 WaitFor 在用异步任务), 运行末尾 Runtime error 216 为预存进程级缺陷 (本任务前已存在, 无干净基线可比, 非本修复引入). 见 history.md.
- 状态: 已修复

### BUG-424: Features/DeepBase.CloudBackup.pas TBackupEncryptor 冗余弱密钥派生 ✅
- 发现日期: 2026-07-09 (专家 E, FEAT-R3-003, P1)
- 严重性: High (密码学: `TBackupEncryptor` 构造时 `DeriveKeyAndIV` 用单次 SHA-256(password) 直接派生 32B key + 16B IV, (a) 单次哈希非 KDF 无迭代/无盐, 易受字典/暴力与彩虹表攻击; (b) IV 由 password+'IV' 哈希派生非随机, 同密码每次备份 IV 相同 → GCM/CBC 下同明文首块可识别重复, 泄露模式; (c) 与同单元 `TSimpleCrypto.EncryptBytes` 已内置的 PBKDF2-SHA256(100k 迭代)+随机盐+AES-256-GCM+GCM Tag+随机 IV 重复并存, 弱路径 (FKey/FIV) 仍被 `EncryptBytes`/`DecryptBytes` 实际使用, 强路径被绕过. 析构期对托管 string `FPassword` 执行 `FillChar(FIV[0],...)` 等指向已不存在字段的悬空写入, 风险 AV)
- 问题: `TBackupEncryptor` 持 `FKey/FIV: TBytes` + `FPassword: string` 三份密码材料; 构造 `DeriveKeyAndIV` 走弱 SHA-256 派生填充 FKey/FIV; `EncryptBytes/DecryptBytes` 实际用 `TSimpleCrypto.EncryptBytes(AData, TEncoding.UTF8.GetString(FKey))` —— 把派生出的 32B 二进制当 UTF-8 string 喂回 TSimpleCrypto (本身已有 PBKDF2+GCM), ��于在强 KDF 之外再套一层无迭代弱 KDF, 且二进制→UTF8 转换遇非法字节会截断/失真; `Destroy` 残留对 FIV 的 `FillChar` 悬空写入 (字段已删); 注释声称 "应使用 AES-256-CBC/GCM 实际用 XOR/Base64 模拟" 与实现不符 (FR-002 后已用 TSimpleCrypto, 注释未更新)
- 修复: 删除冗余弱派生层, 直接转发原始密码给 TSimpleCrypto:
  - 删除字段 `FKey/FIV: TBytes` 与 `DeriveKeyAndIV` 方法 (interface 声明 + implementation 整段), 仅保留 `FPassword: string` (托管, 引用计数自动释放, 不可安全清零)
  - 构造函数 `Create(APassword)` 改为直接 `FPassword := APassword` (不再调用 DeriveKeyAndIV)
  - `EncryptBytes/DecryptBytes`: 去掉 `FKey` 空检查改 `FPassword = ''` 空检查; 调用改为 `TSimpleCrypto.EncryptBytes(AData, FPassword)` / `DecryptBytes(AData, FPassword)` (直接传密码, 让 TSimpleCrypto 内部 PBKDF2(100k)+随机盐+AES-256-GCM+12B 随机 IV+16B GCM Tag 全套生效, 每次加密随机盐/IV 不同 → 非确定性, 抗选择明文)
  - `Destroy`: 删除对 `FillChar(FIV[0],...)` 的悬空写入 (字段已不存在) 与重复注释; 仅保留说明 (托管 string 不可安全清零, TSimpleCrypto 不在此持派生材料)
  - 更新 `EncryptStream` 注释: 移除过时 "应使用 AES-CBC/GCM 实际用 XOR" 误导注释, 改为说明已委托 TSimpleCrypto (AES-256-GCM)
- 验证: Win64 全量 Unit 套件编译通过 (SUCCESS: Unit Tests compiled, 无编译错误/警告); `grep FKey|FIV|DeriveKeyAndIV` 在 CloudBackup.pas 零残留. 无 DUnitX 覆盖 `TBackupEncryptor` 加解密 (Tests/Test.DeepBase.CloudBackup.pas 仅覆盖 manifest/config/info 结构, 无 Encryptor 用例), 安全路径依赖 `TSimpleCrypto` 已有单测覆盖 (Services.Crypto). 运行末尾 Runtime error 216 为预存缺陷 (BUG-421 起记录, 非本修复引入). 见 history.md.
- 状态: 已修复
### BUG-425: Features/DeepBase.CloudBackup.pas TCloudBackupClient 不强制 HTTPS 致 API key 明文传输 MITM ✅
- 编号: BUG-425
- 来源: REVIEW5-R3-E-006 (FEAT-R3-006)
- 严重度: P1
- 状态: 已修复
- 关联: BUG-424 (同文件 E-003 冗余弱密钥派生)

**缺陷**:
`TCloudBackupClient.Create(AServiceURL, AApiKey, ABucket)` 仅赋值 `FServiceURL := AServiceURL`, 不校验 scheme. `DoRequest` 每次请求在 `X-API-Key` 头明文携带 `FApiKey` (L1364), 若配置 `CloudServiceURL=http://...`, API key 经明文 HTTP 传输可被 MITM 截获. 默认值 `https://backup.DeepBase.cloud/v1` (L785) 安全, 但配置项 `TBackupConfig.CloudServiceURL` 可被设为 http, 无任何守卫.

**根因**:
构造函数信任外部输入的 URL scheme, 无 fail-fast 校验; ServiceURL property 虽只读 (L304 read FServiceURL), 但构造期 scheme 任意.

**修复**:
- `TCloudBackupClient.Create` 开头 (inherited Create 之前, 字段未创建, raise 时 Destroy 对 nil 字段 FreeAndNil 安全) 加: `if not AServiceURL.ToLower.StartsWith('https://') then raise ECloudServiceNotConfiguredException.CreateFmt(...)`.
- 复用既有 `ECloudServiceNotConfiguredException` (DeepBase.Exceptions), 不新增异常类; 消息明确指出 "must use HTTPS" + 回显原 URL.
- 不区分大小写 (`ToLower`), 兼容 `HTTPS://` / `Https://`.

**设计决策**:
- 采用构造期 fail-fast (方案 A) 而非 manager 层降级 nil (方案 B): 不安全配置应即报错而非静默降级致云备份不可用且无明确提示. 安全 > 容错.
- 不在 DoRequest 再加运行期校验: ServiceURL property 只读, 构造后不变, 构造守卫已根本性杜绝不安全 client 存在, 冗余检查违反 CLAUDE.md 不鼓励冗余代码.
- 构造 raise 传播至 `TCloudBackupManager.Create` L1660 (单调用点), manager 析构 `FreeAndNil` + `Cancel` 的 `Assigned` 守卫对半初始化字段 (FCloudClient=nil/FCancelled 字段默认 False/未创建对象=nil) 安全, 无泄漏.

**验证**:
- Win64 `-FromUnit DeepBase.CloudBackup -AllowFilteredCI` 编译通过 (SUCCESS: Unit Tests compiled, 无编译错误/警告), 35 测全过 0 失败.
- 测试单元 `Test.DeepBase.CloudBackup.pas` 不构造 TCloudBackupClient (仅测 manifest/config/info), 新校验不破坏现有测试.
- 无 DUnitX 覆盖 TCloudBackupClient 构造 (依赖网络服务, 不属单测域); 校验逻辑为单行 StartsWith, 风险极低.

**影响文件**:
- `Features/DeepBase.CloudBackup.pas` (TCloudBackupClient.Create +6 行校验)

### BUG-426: Features/DeepBase.AntiTamper.pas TAntiTamperConfig 默认硬编码 Salt 致彩虹表攻击 ✅
- 编号: BUG-426
- 来源: REVIEW5-R3-E-007 (FEAT-R3-007)
- 严重度: P2
- 状态: 已修复
- 关联: BUG-034 (同函数 EncryptionKey 已强制显式配置), BUG-424/425 (同轮 CloudBackup 加密加固)

**缺陷**:
`GetDefaultConfig` 默认 `Result.Salt := 'DeepMoveC_Default_Salt_2025'` (硬编码). PBKDF2-SHA256 在 L187 用 `(EncryptionKey, Salt, KdfIterations)` 派生 AES-256 密钥. 固定 Salt 使所有部署共用同一 Salt, 攻击者可针对常见密码预计算彩虹表 (Salt 的作用即失效). 与同函数 L98-100 `EncryptionKey` 默认空且注释 "must be configured by user" (BUG-034 FIX) 的处理不一致.

**根因**:
默认配置信任用户会改 Salt, 但未强制. 加密类型 `TEncryptionType = (etAES256)` 单值 (etXOR 已为安全删除), 加密始终启用, Salt 恒为必需.

**修复**:
- `GetDefaultConfig`: `Result.Salt := ''` (空), 注释对齐 EncryptionKey 的 BUG-034 处理, 强制显式配置.
- `Initialize`: 开头加 `if AConfig.Salt = '' then raise EAntiTamperException.Create(...)`. 复用既有 `EAntiTamperException` (DeepBase.Exceptions), 不新增异常类.
- 消息明确: "Salt must be configured... prevent rainbow-table attacks".

**设计决策 (为何不随机生成 Salt)**:
审查建议 "随机生成并持久化 Salt", 但当前架构不可行: Salt 必须跨运行稳定才能复现密钥解密数据, 而 `TAntiTamperPackage` 是无状态类 (class var FConfig, 无持久化载体). 随机 Salt 不持久化会导致每次启动密钥不同, 加密数据无法解密, 破坏功能. 故采用 "默认空 + Initialize 强制显式配置" (fail-fast), 与 EncryptionKey 的 BUG-034 一致——安全优于自动化, 部署方须提供唯一 Salt.

**验证**:
- Win64 `-FromUnit DeepBase.AntiTamper -AllowFilteredCI` 编译通过 (SUCCESS: Unit Tests compiled, 无编译错误/警告), 8 测全过 0 失败.
- 更新 `Test.DeepBase.AntiTamper.pas` 三处以反映新契约:
  - `Test_DefaultConfig_Values`: `Assert.IsEmpty(C.Salt, ...)` (原 IsNotEmpty).
  - `Test_Initialize_WithDefaultConfig`: 改为 `Assert.WillRaise(... EAntiTamperException)` (默认空盐必抛) + 配置 Salt 后 `Initialize` 成功.
  - `Test_EncryptDecrypt_AES_RoundTrip`: 补 `C.Salt := 'UnitTest_AntiTamper_Salt_2026'`.
- 测试 uses 加 `DeepBase.Exceptions` (EAntiTamperException 来源).

**影响文件**:
- `Features/DeepBase.AntiTamper.pas` (GetDefaultConfig + Initialize 校验, +10 行)
- `Tests/Test.DeepBase.AntiTamper.pas` (3 测方法 + uses)

### BUG-427: Features/DeepBase.Speech.TTS.StepFun.pas FetchSystemVoices/FetchClonedVoices nil as TJSONArray 触发 EInvalidCast ✅
- 编号: BUG-427
- 来源: REVIEW5-R3-E-008 (FEAT-R3-008)
- 严重度: P2
- 状态: 已修复

**缺陷**:
`FetchSystemVoices` (L172) 与 `FetchClonedVoices` (L230) 均用 `JSONArr := (JSONVal as TJSONObject).GetValue('voices') as TJSONArray; if JSONArr = nil then Exit;`. 当响应缺 `"voices"` 键时, `GetValue('voices')` 返回 nil, `nil as TJSONArray` 立即 raise `EInvalidCast` (Delphi `as` 运算符对 nil 类类型引用强制转换抛异常), 故 L173/L231 的 `if JSONArr = nil then Exit` 为**死代码**永不执行. EInvalidCast 被外层 `except` 捕获, `FLastError` 含 `"StepFun fetch voices: Invalid class typecast"` 而非清晰的 "voices 缺失" 错误, 误导调用方排查.

**根因**:
误用 `as` 做可能为 nil 的 JSON 值类型转换; `as` 语义是 "必为目标类型否则抛异常", 与期望的 "缺失则返回 nil 优雅退出" 矛盾.

**修复**:
两处统一改为 `is` 检查 + 硬转换:
```pascal
var VoicesVal := (JSONVal as TJSONObject).GetValue('voices');
if not (VoicesVal is TJSONArray) then
begin
  FLastError := 'StepFun fetch (system|cloned) voices: response missing "voices" array';
  Exit;
end;
JSONArr := TJSONArray(VoicesVal);
```
- `is` 对 nil 返回 False (不抛异常), 缺键/非数组均优雅退出并设清晰 FLastError.
- 硬转换 `TJSONArray(VoicesVal)` 在 `is` 已确认类型后安全.
- FetchClonedVoices 原对非 200 直接 Exit 无 FLastError, 本次新增 voices 缺失的 FLastError (与 FetchSystemVoices 对齐).

**设计决策**:
不保留 `if JSONArr = nil then Exit` 死代码——`is` 已覆盖该分支, 删除避免误导. 不改外层 `try/except` (仍作网络/解析异常兜底). `JSONVal as TJSONObject` 保留: ParseJSONValue 后已 nil 检查, 顶层非对象属异常协议响应, 由 except 兜底合理.

**验证**:
- Win64 全量编译通过 (SUCCESS: Unit Tests compiled, 无编译错误/警告).
- StepFun 无专属 DUnitX 测试单元 (依赖网络 API, 不属单测域); 改动为纯逻辑等价替换 (as→is, 数组场景行为一致, 缺失场景由 raise 改为清晰 Exit), 风险极低.
- 全量套件存在的 E/F 及尾部 EInvalidPointer 与 StepFun 无关 (StepFun 无测试且改动不涉及指针释放, JSONVal.Free 在 finally 不变), 属既有基线状态.

**影响文件**:
- `Features/DeepBase.Speech.TTS.StepFun.pas` (FetchSystemVoices + FetchClonedVoices, 各 +7 行)

### BUG-428: Features/DeepBase.Commerce.SafeClient.pas SendJson 仅 401 重试, 429/5xx 瞬态失败不退避直接抛错 ✅
- 编号: BUG-428
- 来源: REVIEW5-R3-E-005 (FEAT-R3-005)
- 严重度: P2
- 状态: 已修复

**缺陷**:
`TDeepKitSafeClient.SendJson` (L503 调用栈, 实际实现约 L560-660) 仅在 HTTP 401 (token 过期) 时重试一次刷新 token, 对 429 (Too Many Requests) 与 5xx (服务端临时不可用) 直接调 `EnsureSuccess` 抛 `EDeepBaseCommerceError`. 商业化支付/订单接口在短暂限流或后端重启窗口下会立即失败, 无指数退避、不遵守 `Retry-After` 响应头, 导致本可自愈的瞬态错误被当永久错误透传给用户.

**根因**:
重试策略只覆盖认证层 (401), 缺失对限流 (429) 与服务端瞬态故障 (5xx) 的退避重试; 且无幂等性判定——盲目重试非幂等 POST 会重复下单/重复扣款.

**修复**:
在 `SendJson` 末尾新增瞬态失败退避重试循环 (仅对**幂等调用**生效):
1. **幂等判定** `IsIdempotentCall`: GET/HEAD 天然幂等; POST/PUT/DELETE 仅当显式带 idempotency key (由 `CreatePaymentIntent` 等传 `AIdempotencyKey`) 才视为可重试. 非幂等 POST 无 key 不重试 (防重复下单).
2. **可重试状态** `IsRetriableStatus`: 429 + 5xx (500/502/503/504). 401 仍走原有 token 刷新路径 (不并入此循环, 语义不同).
3. **Retry-After 遵守** `ExtractRetryAfterMs`: 429 响应优先读 `Retry-After` 头 (秒数→ms, 缺失则用退避), 钳制到 `BACKOFF_CAP_MS` 上限.
4. **指数退避** `ComputeBackoffMs`: 5xx 用 `BACKOFF_BASE_MS * 2^attempt`, 钳制到 `BACKOFF_CAP_MS`.
5. **确定性抖动**: 基于 `AAttempt` 的 ±25% 抖动 (公式不用 `Now`/`Random`——脚本/测试环境禁用), 避免多客户端同步重试形成惊群.
6. 退避用 `Winapi.Windows.Sleep` (`{$IFDEF MSWINDOWS}` 保护), 非平台路径跳过退避直接重试.

**设计决策**:
- 抽出 4 个辅助方法 (`IsRetriableStatus`/`IsIdempotentCall`/`ExtractRetryAfterMs`/`ComputeBackoffMs`) 而非内联, 便于单测与后续扩展 (如 503 + Jitter 头解析).
- 不对非幂等 POST 重试: 即使 5xx 也直接抛错, 由调用方决定是否重新提交 (幂等性 key 应由业务层在上游生成并传入, 而非 SafeClient 内部自造).
- implementation uses 新增 `System.Math` (用于 `Min` 钳制, 仓库惯例全限定 `System.Math.Min`).
- `FMaxRetries` 复用 SafeClient 既有配置字段, 默认值不变 (1 次重试, 即最多 2 次请求).

**验证**:
- Win64 全量编译通过 (SUCCESS: Unit Tests compiled, 仅遗留既有 H2443/H2077 提示).
- **新增 2 个回归测试** (`Tests/Test.DeepBase.Commerce.pas`):
  1. `Test_DeepKitSafeClient_429_RetriesIdempotentGet_HonorsRetryAfter`: ListProducts (幂等 GET) 首次返回 429 + `Retry-After: 0` (Sleep(0) 不阻塞), 第二次返回 200; 断言 RequestCount=2 且解析出商品. 验证幂等 GET 被重试且遵守 Retry-After.
  2. `Test_DeepKitSafeClient_5xx_DoesNotRetryNonIdempotentPost`: CreateOrder (非幂等 POST 无 key) 在 503 下断言抛 `EDeepBaseCommerceError` 且 RequestCount=1. 验证非幂等 POST 不重试防重复.
- 两测试经 DUnitX `--run` 全名过滤单独执行确认 PASS (2 found, 2 passed, 0 failed/errored).
- 全量套件中既有 2 个失败 (WeChatPay 公钥加载环境问题 + `Test_PermissionClient_HasFeature_UsesActiveEntitlement` 测试数据 `valid_until=2026-07-08` 已于今日 07-09 过期) 与 E-005 无关, 属既有基线.

**影响文件**:
- `Features/DeepBase.Commerce.SafeClient.pas` (SendJson 末尾退避循环 + 4 辅助方法, +~60 行)
- `Tests/Test.DeepBase.Commerce.pas` (2 回归测试, +~70 行)

### BUG-429: DeepFlow/Source/Roles/DeepFlow.Commander.pas ProcessRequest 锁外修改 Session 字段, 并发同 session-id 数据竞争 ✅
- 编号: BUG-429
- 来源: REVIEW5-R3-D-007 (GOV-R3-007)
- 严重度: P2
- 状态: 已修复

**缺陷**:
`TCommander.GetOrCreateSession` (L181) 在 FSessionLock 内取 `TSession` 裸指针后释放锁返回. `ProcessRequest` (L349-379) 拿到指针后**锁外**修改 `Session.State := ssActive/ssPending/ssError` (L350/371/375) 与 `Inc(Session.FTurnCount)` (L351), 并读 `Session.Context`/`Session.SessionId`. 多线程并发 `ProcessRequest` 同一 SessionId 时, 这些标量字段无锁修改 → 数据竞争 (Inc 非原子, State 读改写撕裂).

**根因**:
GetOrCreateSession 的锁保护范围只覆盖字典查找, 返回的裸 TSession 指针脱离锁后, 其字段被调用方无保护修改; FSessionLock 设计意图覆盖会话字段访问, 但实际只在字典操作时持有.

**修复**:
`ProcessRequest` 中所有 Session 字段访问改为在 FSessionLock 临界区内完成:
1. 入口段锁内: `Session.State := ssActive` + `Inc(Session.FTurnCount)` + 取 Context/SessionId 快照到内联 var 局部 (`SessionCtx`/`SessionSid`).
2. AnalyzeIntent(耗时 LLM) 用快照引用在**锁外**执行, 避免持锁过久阻塞其他会话.
3. 成功路径 `Session.State := ssPending` 独立锁内更新.
4. except 路径 `Session.State := ssError` 独立锁内更新.

**设计决策**:
- 用内联 `var` 声明快照 (仓库既有惯例, 见 Chronicler L390/Message L203/Config L194), 保持 ProcessRequest 局部作用域, 不污染 var 块.
- Context 引用快照在锁内取: 消除 GetOrCreateSession 返回后到使用间的窗口. (注: Commander 停止时 FSessions.Clear 会释放 Session, 裸指针悬空是更深所有权问题, 超出 D-007 范围, 本修复聚焦字段竞态.)
- 不对整个 ProcessRequest 持锁: AnalyzeIntent/Decompose 耗时长, 持锁会序列化所有会话请求, 退化为单线程. 锁内只做标量字段读写 (纳秒级).
- State 在 except 中二次加锁: except 在 try 外层捕获, 此时已离开成功路径的锁, 故 except 内需独立加锁写 ssError.

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, exit 0, 仅遗留既有 H2077/H2443 Hint, 无 Error/Fatal).
- Commander 无专属 DUnitX 测试 (仅 dpr 引用编译); 改动为纯加锁包裹, 语义等价 (字段读改写原子性提升), 风险低.
- DeepFlow 模块未纳入主测试 exe 的 PBT 之外单测, 故无回归测试新增 (与 D-003/D-006 等同类已修项目一致).

**影响文件**:
- `DeepFlow/Source/Roles/DeepFlow.Commander.pas` (ProcessRequest 字段访问加锁包裹 + 内联 var 快照, +~25 行)

### BUG-430: Governance/DeepBase.Governance.AI.ProposalQueue.pas 无界队列 OOM + 全程无锁竞态 ✅
- 编号: BUG-430
- 来源: REVIEW5-R3-D-008 (GOV-R3-008)
- 严重度: P2
- 状态: 已修复

**缺陷**:
`TProposalQueue` 两个独立问题:
1. **无界队列 OOM**: `Submit` (L136) 无任何容量上限, AI 循环提交 TProposal 无限堆积 → 内存无限增长致 OOM; `FindById`/`GetPending`/`GetPending` O(n) 线性遍历, 队列膨胀后查询卡顿.
2. **全程无锁**: 整个类无任何同步原语. 当前仅主线程调用看似安全, 但一旦引入后台 AI 提交线程 (提案即 AI 异步生成), 与人审 Approve/Reject/Apply 并发 → `TObjectList<TProposal>` 非线程安全, 迭代中 Add 致遍历越界 / 状态读改写撕裂. 原审阅标注"引入后台 AI 提案将升 P1".

**根因**:
设计期未考虑队列容量约束与并发安全, FProposals 裸 `TObjectList`, 全部方法直读直写无保护.

**修复**:
1. **容量上限**: 新增 `FMaxPending: Integer`, 构造 `Create(AModelVersion; AMaxPending: Integer = 0)`. AMaxPending<=0 时取默认 1000. `Submit` 入口在锁内调 `PendingCountInternal` 统计 psSubmitted 数, ≥FMaxPending 抛 `EProposalQueueError.CreateFmt` (新增异常类, 遵循 Governance 既有 EConfigRegistrarError/EJsonLogicError 惯例, 不引入泛型 Exception). 容量检查 + Add 必须同一锁内, 否则 TOCTOU.
2. **TCriticalSection 保护全部 8 个公共方法**: Submit/Approve/Reject/Apply/FindById/GetPending/GetAll/Count.
3. **避免自死锁**: TCriticalSection 不可重入. Approve/Reject/Apply 需先 FindById 再改字段, 若调公共 FindById (自身已加锁) 会在已持锁上下文二次加锁 → 自死锁. 故拆 `FindByIdInternal` (无锁, 调用方持锁遍历) 供内部用, 公共 `FindById` 加锁后转调 internal.
4. **Apply 锁内创建 ChangeSet**: Apply 持锁调 `FModelVersion.CreateChangeSet` + `LCS.AddEntry` + `LP.MarkApplied`. ModelVersion 是独立对象无反向锁 ProposalQueue 依赖, 无死锁风险; ChangeSet 创建快 (纳秒级), 可接受持锁. MarkApplied 写 FStatus 必须与 Submit/Approve 的状态读互斥, 故锁内执行.
5. **GetPending 嵌套 try/finally**: 外层 LList.Free, 内层 FLock.Leave, 两资源独立释放.

**设计决策**:
- 默认上限 1000 而非 0 (无限): 真正消除 OOM 风险, 而非仅留接口. 无外部调用点 (仅类定义, 未接线), 改默认值无破坏性. 生产环境可传更大值放宽.
- 用 TCriticalSection 而非 TMonitor(TObject): 跟同模块 ActionGrid (D-003 修复时用 TCriticalSection) 一致; EvidenceStore 用 TMonitor 是其历史选择, 不强求统一.
- 抛异常而非返回 nil: Submit 契约返回非 nil TProposal, 调用方假定成功; 返回 nil 会被忽略致静默丢提案. 抛 EProposalQueueError 明确失败, 调用方可 catch 降级 (重试/丢弃旧提案).

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, `SUCCESS: Unit Tests compiled`, exit 0, 325043 lines 16.56s, 无 Error/Fatal/undeclared).
- ProposalQueue 无外部调用点、无 DUnitX 测试 (仅骨架类未接线); 改动为纯加锁包裹 + 容量守卫, 语义等价 (并发安全与 OOM 防护提升), 风险低.
- 与 D-007 (Commander) 同属"骨架未接线"类修复, 不新增回归测试 (与同类已修项一致).

**影响文件**:
- `Governance/DeepBase.Governance.AI.ProposalQueue.pas` (新增 EProposalQueueError 异常 + FLock/FMaxPending/FindByIdInternal/PendingCountInternal 字段方法 + 8 方法加锁 + 容量检查, +~70 行)

### BUG-431: Persistence/DeepBase.DB.Pool.pas 连接池归还脏连接 (残留事务/隔离级别泄漏) ✅
- 编号: BUG-431
- 来源: REVIEW5-R3-C / DATA-R3-001
- 严重度: P0
- 状态: 已修复

**缺陷**:
`TPooledConnection.Release` 只把 `FState` 置 `csIdle` 并 `SetEvent`, 既不检查 `FConnection.InTransaction`, 也不回滚, 更不关闭可能仍打开的 TFDQuery 游标. `FindAvailableConnection` 对 csIdle 连接只调 `IsValid` (仅查 `Connected`, 实际不执行 SELECT 1 探活). 后果: 调用方经 `Pool.Execute`/`Query<T>`/`GetConnection` 借出连接后, 若开启事务但在 finally 前抛异常 (或忘提交), 该连接带着未提交事务被归还; 下个借用者 `BeginTransaction` 在 SQLite 上失败 ("cannot start a transaction within a transaction"), 在 PostgreSQL/MySQL 上可能读到上一调用方未提交的中间数据, 甚至把别人的 INSERT/UPDATE 一起提交; 调用方临时提升隔离级别后也会泄漏给后续借用者.

**根因**:
设计期未在归还路径做连接复位. 连接池复用 TFDConnection 但未对事务/隔离级别做隔离保障, 默认信任调用方善后, 异常路径下信任被打破.

**修复**:
1. 新增 `TPooledConnection.ResetConnectionState` (private, interface+impl 声明).
2. `Release` 在持 `FPool.FLock` **前**调 `ResetConnectionState` (复位是连接级操作不涉池状态, 与��锁置 csIdle 分离, 保证复位与空闲可见性原子; 倒置顺序无意义风险, 因 csIdle 一旦可见即可能被借出, 复位必须先于可见).
3. `ResetConnectionState` 内容:
   - `if FConnection.InTransaction then FConnection.Rollback` — 回滚残留未提交事务. **不 Commit**: 残留事务几乎都是异常路径遗留的未完成工作, 提交会把脏数据落库.
   - `FConnection.TxOptions.AutoCommit := FPool.FConfig.AutoCommit` — 重置 AutoCommit 到池配置, 防调用方临时改隔离级别/自动提交后泄漏.
4. 异常容忍: 复位任一步失败仅 `DoPoolEvent` 记事件, 不阻断归还. 复位失败后连接仍置 csIdle/由 IsValid 兜底探活; 避免复位抛异常致 Release 提前 return 连接卡 csInUse 泄漏.
5. 残留游标 (调用方 TFDQuery.Open 后异常未 Close) 不在连接池处理范围 — dataset 生命周期属调用方责任, 与 FireDAC 连接池设计一致 (池不接管 dataset 引用).

**设计决策**:
- 回滚而非提交: 异常路径遗留事务 = 未完成工作, 提交即脏数据落库. 这是 DATA-R3-001 的核心安全语义.
- 复位放 Release 而非 FindAvailableConnection: 借出时复位会让借用者承担复位开销且无法分辨脏来源; 归还时复位是"谁用谁清理"的对称设计, 下个借用者拿到干净连接.
- 不重置 Connected (不重连): 重连代价大且可能触发连接失败, 复用价值丧失. 事务复位已覆盖核心风险 (跨调用方数据污染).

**验证**:
- Win64 全量编译通过 (powershell -NoProfile run_tests.ps1 -CI, `SUCCESS: Unit Tests compiled`, exit 0, 325082 lines 17.06s, 仅 H2077 无关 hint, 无 Error/Fatal/undeclared).
- DB.Pool 有既有 DUnitX 测试 (DB.Pool.Tests), 修复为纯防御性复位 (正常路径 InTransaction=False 不触发 Rollback, 语义等价无回归), 未新增专项测试 (与同类加固项一致; 真实脏连接复现需多线程+异常注入, 不在单测范围).

**影响文件**:
- `Persistence/DeepBase.DB.Pool.pas` (TPooledConnection 新增 ResetConnectionState private 方法声明+实现, Release 入口调复位, +~30 行)

### BUG-432: doQry/doQryMain.pas 过滤条件字符串拼接致过滤注入 (TADOQuery.Filter) ✅
- 编号: BUG-432
- 来源: REVIEW5-R3-C / DATA-R3-002
- 严重度: P1
- 状态: 已修复

**缺陷**:
`btnFilterClick` (L151) 将用户输入 `s` 直接拼接进 `tblQueries.Filter`:
`tblQueries.Filter := 'proc_name LIKE ''%' + s + '%''';`
TDataSet.Filter 是表达式字符串而非 SQL, 但仍按表达式语法解析; 攻击者可注入 `%' OR 1=1 OR proc_name LIKE '%` 之类表达式片段绕过过滤, 或注入未闭合引号致表达式异常 (DoS / 信息枚举). 即便不至 SQL 层, 过滤表达式注入同样能放大暴露面.

**根因**:
doQry 早期演示代码直接字符串拼接构造 Filter, 未对表达式上下文做转义.

**修复**:
改用 `System.SysUtils.QuotedStr` 包裹整体匹配值:
`tblQueries.Filter := 'proc_name LIKE ' + QuotedStr('%' + s + '%');`
`QuotedStr` 将内嵌单引号翻倍为 `''`, 表达式解析器不再把用户输入里的引号当字符串边界, 注入片段被锁进字面量内. `System.SysUtils` 已在 doQryMain uses (L6), 无新依赖.

**验证**:
- doQry 工程在当前 BDS37 环境无法整体编译 (uDoQryLegacy.pas L8 引用的 `DBClient` 单元在 RAD Studio 12 Athens/37.0 已移除, 属该工程历史遗留, 与本修复无关). 修复行为纯标准 API (`QuotedStr`), uses 齐备, 语法确定正确.
- 此项为防御性加固, 无既有单测覆盖 doQry 过滤路径 (doQry 不在 CI 单测工程集).

**影响文件**:
- `doQry/doQryMain.pas` (btnFilterClick L151, +1/-1 行)

### BUG-433: doQry/doQryMain.pas information_schema 查询表名拼接 + proc_name 拼接致 SQL 注入 ✅
- 编号: BUG-433
- 来源: REVIEW5-R3-C / DATA-R3-003 (另见 L126 btnGenSqlClick)
- 严重度: P1
- 状态: 已修复

**缺陷**:
1. `GetFieldList(TableName)` (L305) 将外部传入 `TableName` 直接拼接进 SQL:
   `aQry.SQL.Text := Format('SELECT column_name FROM information_schema.columns WHERE table_name = ''%s'';', [TableName]);`
   `TableName` 来自调用方 (界面/外部), 可注入 `x''; DROP TABLE ...;--` 之类 (单语句连接下受限, 但可构造读取越权或注释绕过).
2. `btnGenSqlClick` (L126) 将数据库字段值 `proc_name` 拼接进查询:
   `aQry.SQL.Text := 'select * from queries where proc_name=' + '''' + proc_name + '''';`
   `proc_name` 虽来自 `tblQueries` 字段, 但属数据层间接可控 (存储过程名可由用户/上游写入), 二次注入风险.

**根因**:
doQry 演示代码全程字符串拼接构造 SQL, 未参数化.

**修复**:
两处均改为 ADO 参数化查询:
- L305: `aQry.SQL.Text := 'SELECT column_name FROM information_schema.columns WHERE table_name = :t';` + `aQry.Parameters.ParamByName('t').Value := TableName;`
- L126: `aQry.SQL.Text := 'select * from queries where proc_name = :p';` + `aQry.Parameters.ParamByName('p').Value := proc_name;`
`aQry` 为 `TADOQuery` (doQryMain L27), `Parameters.ParamByName` 是 `Data.Win.ADODB` 标准参数 API (uses L12 已含), 驱动负责转义, 消除注入面.

**设计决策**:
- L286 (`GetTableList`) Format 未用 `DatabaseName` 参数且硬编码 `'public'` 字面量, 无变量拼接, 无注入风险, 仅风格冗余, 不在本安全任务范围改动 (避免越界改无关).
- L178 (`Button1Click`) INSERT 语句 VALUES 全为字面量 ('我是一头猪'/'已经分享等待下载' 硬编码), 无变量拼接, 不处理.

**验证**:
- 同 BUG-432: doQry 工程因 `DBClient` 历史遗留无法在 BDS37 整体编译; 修复行为为 `TADOQuery.Parameters.ParamByName` 标准 API, uses 齐备, 语法确定正确.
- doQry 不在 CI 单测工程集, 无回归测试触发.

**影响文件**:
- `doQry/doQryMain.pas` (GetFieldList L305, btnGenSqlClick L126, +4/-2 行)

### BUG-434: Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas 三处 Check 方法吞异常致诊断"假绿" ✅
- 编号: BUG-434
- 来源: REVIEW5-R3-C / DATA-R3-004
- 严重度: P1
- 状态: 已修复

**缺陷**:
`TFireDACDiagnoseStorage.CheckForeignKeys` (L460)、`CheckRequiredFields` (L517)、`CheckEnumValues` (L579) 三处 `try/except` 把查询异常经 `OutputDebugString` 静默吞掉: except 块既不向 `ResultList` 追加任何 `TDiagnoseResult`, 也不阻断, 方法返回当前已累积的结果 (查询失败前通常为空数组). 后果: 当连接断开/表结构不可内省/SQL 执行报错时, `DiagnoseAll` 聚合三方法空结果 → `GenerateDiagnoseReport` 报 `[OK] No issues found. Database schema is valid.` —— 检查根本没跑成功却报"全绿", 管理员误信数据库健康, 实际问题被 OutputDebugString 埋进 DebugView (生产环境通常无人看 DebugView). 这是"假绿" (green-on-error): 失败被伪装成通过.

**根因**:
except 设计期仅作"调试可见性" (OutputDebugString) 而非"结果可见性". `TDiagnoseResult` 枚举原无"检查执行失败"语义型别, 即使想上报也无合适 `IssueType` 可填, 间接促成"吞掉返回空"的偷懒实现. 调用方 (DiagnoseAll/GenerateDiagnoseReport) 按"结果数组为空=无问题"解读, 无法区分"真无问题"与"检查没跑成".

**修复**:
1. `Core/DeepBase.Diagnose.pas` `TDiagnoseIssueType` 枚举末尾新增 `ditCheckError` (序数 8, 不动 ditMissingTable..ditInvalidEnum 已有 0..7 序数, 二进制兼容). 语义: 检查执行本身失败 (查询错误/内省失败), 区别于"数据有问题".
2. 三 Check 方法 except 块改为构造 `ditCheckError`+`IsOK:=False` 的 `TDiagnoseResult` 追加 `ResultList`, Issue 字段填 `'检查失败: ' + E.Message`, TableName/ObjectName 填当前迭代上下文 (FK/RF/EF 的 TableName/ColumnName), Suggestion 给重试指引, CanAutoFix:=False. 失败对调用方可见, DiagnoseAll 不再假绿.
3. `AddColumnIfNotExists` (L655) 与 `AutoFix` (L676) 的 except 保留原 OutputDebugString: 二者返回值 (Boolean/Integer) 已部分表达失败 (AddColumn 返回 False, AutoFix 计数不递增), 调用方可据返回值判断, 不属"假绿"语义; 且 AutoFix 返回 Integer 无法承载异常文本, 改动牵涉签名变更, 超出 DATA-R3-004 范围, 不在本次修复.

**设计决策**:
- 新增枚举值而非复用 ditDataIntegrity: ditDataIntegrity 语义="数据完整性有问题" (数据层), ditCheckError="检查没跑成" (执行层). 复用会让真数据问题与检查故障混为一型, 调用方无法分辨该修数据还是该修连接/重试. 新增 1 值末尾追加, 序数兼容, 无 case 穷举点 (GenerateDiagnoseReport 按 CanAutoFix/FixSQL 分类不 case IssueType), 影响面仅枚举定义+测试序数断言.
- ditCheckError 填当前迭代上下文 TableName/ColumnName: 比留空更可定位 (调用方知哪个表/列的检查崩了), 且变量在 except 处仍 in-scope (循环内赋值).
- 不抛异常而追加结果项: DiagnoseAll 聚合多 Check, 单个表检查失败不应中断整次诊断; 追加 ditCheckError 让该失败在最终报告可见, 其余表继续检查.

**验证**:
- Win64 全量编译 SUCCESS exit 0 (325119 lines 17.05s, 编译阶段无 Error/Fatal).
- Diagnose 单元 DUnitX 回归: `run_tests.ps1 -Type Unit -CI -Platform Win64 -FromUnit DeepBase.Diagnose -AllowFilteredCI` → Tests Found 40 / Passed 40 / Failed 0 / Errored 0, 含新增 `Ord(ditCheckError)=8` 序数断言 (Test_IssueType_Values).
- 补回归断言: `Tests/Test.DeepBase.Diagnose.pas` Test_IssueType_Values 末尾加 `Assert.AreEqual(8, Ord(ditCheckError))` 锁定新枚举序数.
- 注: 全量测试运行有既有 Runtime error 216 (进程级崩溃于非 Diagnose 测试, git status 显示仓库处于 R3 多文件修复进行中, 该 216 与本次 Diagnose 改动无关, Diagnose 单测全过可证).

**影响文件**:
- `Core/DeepBase.Diagnose.pas` (TDiagnoseIssueType 末尾新增 ditCheckError + 注释, +4 行)
- `Persistence/DeepBase.Persistence.Diagnose.FireDAC.pas` (CheckForeignKeys/CheckRequiredFields/CheckEnumValues 三处 except 块改 ditCheckError 结果项上报, ~+30 行)
- `Tests/Test.DeepBase.Diagnose.pas` (Test_IssueType_Values 加 ditCheckError=8 断言, +1 行)

### BUG-435: Persistence/DeepBase.Persistence.MRU.FireDAC.pas Upsert 无条件 StartTransaction 误回滚调用方事务 ✅
- 编号: BUG-435
- 来源: REVIEW5-R3-C / DATA-R3-005
- 严重度: P2
- 状态: 已修复

**缺陷**:
`TFireDACMRUStorage.Upsert` (L72) 无条件 `FConnection.StartTransaction`, except 块 (L115) 无条件 `FConnection.Rollback`. 当调用方已在外层事务中 (共享同一 TFDConnection 调 Upsert, 或 Upsert 被另一已开事务的逻辑重入调用) 时: (1) SQLite 上 `StartTransaction` 报 "cannot start a transaction within a transaction" 直接抛异常; (2) PostgreSQL/MySQL 上可能开成 savepoint 或嵌套事务, 但 Upsert 的 SELECT-then-INSERT/UPDATE 若中途抛异常, except 块 `Rollback` 会回滚调用方的整个外层事务 (而非仅本 Upsert 的工作), 把调用方已完成的合法 DML 一起撤销. 后果: 调用方事务被 MRU 的内部异常意外回滚, 数据丢失, 且难定位 (表面是 MRU 写失败).

**根因**:
DATA2-019 防并发重复键设计期, 直接 StartTransaction 假设 "调用方未开事务". 但 MRU Storage 是共享 FConnection 的可复用组件, 无权假设调用方事务状态. 缺少事务所有权 (OwnTx) 跟踪, except 无条件 Rollback 即"谁后开谁回滚全部".

**修复**:
仿 `Persistence/DeepBase.Persistence.Authorization.FireDAC.pas` (L590-627, DATA2-025) 的 OwnTx 模式:
1. var 段新增 `OwnTx: Boolean`.
2. `OwnTx := False` 后, `if not FConnection.InTransaction then begin FConnection.StartTransaction; OwnTx := True; end;` — 仅在调用方未开事务时自启.
3. `if OwnTx then FConnection.Commit;` — 仅提交自启的事务.
4. `except if OwnTx then FConnection.Rollback; raise;` — 仅回滚自启的事务; 调用方事务交还调用方 (异常仍 `raise` 上抛让调用方感知).

**设计决策**:
- 不删事务只加所有权: DATA2-019 的防并发重复键语义保留 — 无外层事务时仍 StartTransaction 包 SELECT-INSERT, 防两并发 Upsert 都看到 "not found" 后双 INSERT 撞 UNIQUE. 有外层事务时复用之, 防重复键由 MRU 表 UNIQUE 约束兜底 (非依赖事务), 并发安全由调用方事务隔离级别保证, 无回归.
- `raise` 保留: 异常上抛让调用方知道 MRU 写失败并自行决定外层事务去留; 不吞异常.
- 与 Authorization OwnTx 模式 (DATA2-025) 一致: 同仓库同模块族统一事务所有权约定, 降低认知负担.

**验证**:
- Win64 编译 SUCCESS exit 0 (run_tests.ps1 -FromUnit DeepBase.MRU -AllowFilteredCI, 编译阶段无 Error).
- MRU 单元 DUnitX 回归: Tests Found 13 / Passed 13 / Failed 0 / Errored 0. 测试用 TInMemoryMRUStorage mock 不实跑 FireDAC 路径 (与 Diagnose 同理); 修复为纯防御性 OwnTx (无外层事务时 OwnTx:=True 自启+Commit 语义等价原逻辑无回归), 真实重入/共享连接误回滚复现需多线程+共享连接异常注入, 不在单测范围, 与同类加固项 (BUG-431/BUG-434) 一致不新增专项测试.

**影响文件**:
- `Persistence/DeepBase.Persistence.MRU.FireDAC.pas` (Upsert var 加 OwnTx, StartTransaction/Commit/Rollback 改 OwnTx 守卫, +10 行)

### BUG-436: doQry/uDoQryLegacy.pas 异常/UI 消息含完整内联值 SQL (PII 泄漏) ✅
- 编号: BUG-436
- 来源: REVIEW5-R3-C / DATA-R3-006
- 严重度: P3
- 状态: 已修复

**缺陷**:
legacy 层 `uDoQryLegacy.pas` 用 `BuildSQL` 生成内联值的 SQL 字符串 (参数值经 `QuoteValue`/`HandleParamValue` 拼入), 多处把完整 SQL 塞进 `msg` (var 输出参数 → 调用方 UI/日志) 或异常消息上抛:
- `ExecuteAndGetResult` (L756): `raise ...CreateFmt('SQL执行错误: %s'#13#10'SQL: %s', [E.Message, aSQL])`
- `ExecuteSQL` (L778): `raise ...Create('doQry Error::SQL执行错误: ' + E.Message + #13#10 + 'SQL:' + SQL)`
- `doQry(ProcName...)` (L894/901/930/945/956/964/968/978/982/993): 10 处 msg 构造含 `'#13#10'SQL: %s'` + sSQL, 覆盖失败路径 (raise 上抛进日志) 与成功路径 (msg 返回给 UI 显示), 后者更甚 — 成功执行也向用户暴露 SQL+参数值.

这些值可能是聊天消息正文/用户 ID/分享链接等 PII, 最终进入日志文件或错误对话框, 违反数据最小化原则.

**根因**:
legacy 层无参数化 SQL 执行 (值内联拼入), 诊断/展示为复用 sSQL 字符串直接拼进用户可见消息, 未区分 "诊断信息" (完整 SQL, 调试用) 与 "用户消息" (仅操作结果, 脱敏).

**修复**:
统一策略: msg/异常消息只保留错误本身 + 操作类型/表名/受影响行数等脱敏元数据, 去掉 `'#13#10'SQL: %s'` 尾巴及对应 sSQL/SQL.Text 参数; 完整 SQL 经 `{$IFDEF DEBUG} Winapi.Windows.OutputDebugString(...) {$ENDIF}` 输出到调试器 (DebugView, 生产通常无 DEBUG 定义/无人接, 即便接也不进持久日志), 不上抛不进 msg. 共改 13 处 (2 处 Execute* + 11 处 doQry/except), 均核对 Format 占位符与参数数对齐.
- 保留 L325/L697 既有 `OutputDebugString('...SQL: ' + ...)` (已是调试器输出, 非用户可见消息路径, 不属泄漏面).
- doQry 工程因 L8 `DBClient` 已自 Delphi 移除 (C-002/C-003 同款历史遗留), BDS37 无法整体编译 → 无编译验证; 改动为纯异常/UI 消息文本改写, Format 语法等价, uses `Winapi.Windows` 已在 L8 (全限定 OutputDebugString 调用安全), ��新增符号/签名变更.

**验证**:
- 残留扫描: `grep "'SQL: |SQL:'|SQL: %s" uDoQryLegacy.pas` 排除 DEBUG 行后仅余 L325/L697 既有 OutputDebugString (调试器输出, 保留), msg/异常路径零残留.
- 13 个 `{$IFDEF DEBUG}` 守卫 (11 新增 + 2 原有).
- 编译验证不可行 (doQry 工程 BDS37 历史遗留不可编译, 同 BUG-432/433/434 现状); doQry 不在 CI 单测工程集无回归触发. 真实 PII 泄漏复现需 doQry.exe 运行 (依赖恢复 DBClient 的旧 BDS 或 DBClient 替代), 不在本轮编译链覆盖.

**影响文件**:
- `doQry/uDoQryLegacy.pas` (ExecuteAndGetResult L754-758, ExecuteSQL L777-779, doQry L894-996 共 11 处 msg/异常构造脱敏, +13 DEBUG 守卫)

### BUG-437: AddColumn 的 ColumnDef 原样拼入 DDL (防御性缺口, DDL 注入面) ✅
- 编号: BUG-437
- 来源: REVIEW5-R3-C / DATA-R3-007
- 严重度: P3
- 状态: 已修复

**缺陷**:
`Persistence/DeepBase.Persistence.Manager.FireDAC.pas` 的 `TFireDACManagerStorage.AddColumn` (L208-228): `TableName`/`ColumnName` 已 `TSQLUtils.ValidateIdentifier` 校验, 但 `ColumnDef` (如 `'TEXT DEFAULT ''LTR'''`) 直接 `Format('ALTER TABLE %s ADD COLUMN %s %s', [TableName, ColumnName, ColumnDef])` 拼入 DDL, 无白名单. 当前唯一调用方 `Core/DeepBase.Manager.Schema.pas` `AddColumnIfMissing` 只传硬编码字面量 (TEXT/INTEGER/REAL + DEFAULT '词'/DEFAULT 数字), **目前不可利用**; 但 `AddColumn` 暴露在公共接口 `IManagerStorage.AddColumn` 上, 任何未来调用方传入受外部影响的 ColumnDef 即引入 DDL 注入 (分号终止 ADD COLUMN 后接 DROP/DELETE/CREATE TRIGGER/ATTACH 等, 或 `--` 注释).

**根因**:
防御边界 (持久化层) 对"结构化标识符" (TableName/ColumnName) 有校验, 但对"类型定义片段" (ColumnDef) 缺校验 — 二者都原样拼入 DDL, 后者留了缺口. 属纵深防御缺口 (defense-in-depth), 非当前可利用漏洞.

**修复**:
在 SQL 安全工具类 `Core/DeepBase.SQL.Utils.pas` 的 `TSQLUtils` 加 `IsValidColumnDef`/`ValidateColumnDef` 类方法 (与既有 `IsValidIdentifier`/`ValidateIdentifier` 同族, 复用既有单元作为防御工具统一入口):
- 拒绝: 空 / 长度>200 / 分号 `;` / 行注释 `--` / 块注释 `/*` `*/` / CR LF 换行 (DDL 注入终止符与注释载体).
- 拒绝: DDL/DML 关键字 (DROP/CREATE/ALTER/DELETE/INSERT/UPDATE/SELECT/TRIGGER/INDEX/VIEW/ATTACH/DETACH/PRAGMA/VACUUM) 经 `\b` 词边界大小写不敏感匹配 (防 `TEXT; DROP` 这类二段语句).
- 允许字符集: 字母/数字/空格/单引号 (字符串字面量)/下划线/小数点 (数字默认值)/括号逗号 (NUMERIC(10,2)/VARCHAR(255)); 拒双引号/反引号/其他.
- `AddColumn` (L216-223) 在 ValidateIdentifier 两行后加 `TSQLUtils.ValidateColumnDef(ColumnDef, 'Manager.AddColumn.ColumnDef')`, 非法即 `EArgumentException` 上抛 (与 identifier 校验一致的失败语义).

**设计选择**: 选白名单正则校验而非改强类型 `TColumnDef` 记录 — 前者不改公共 `IManagerStorage.AddColumn` 签名, 不破坏现有调用方 (`Manager.Schema` 字面量全合法), 是最小侵入的纵深防御加固; 后者虽更彻底但属 API 重构, 超出 P3 防御缺口的修复范围.

**验证**:
- DUnitX 测试: `Tests/Test.DeepBase.SQL.Security.PBT.pas` 加 `Property20_ColumnDefWhitelistAcceptsSafe` (11 个合法样本: TEXT/INTEGER/REAL/BLOB + DEFAULT '<词>'/DEFAULT 数字 + NOT NULL + NUMERIC(10,2)/VARCHAR(255)) 与 `Property20_ColumnDefWhitelistRejectsInjection` (12 个非法样本: 空/分号+DROP/`--`注释/`/*`块注释/CRLF+DROP/分号+DELETE/INSERT/SELECT/CREATE/ATTACH/双引号/反引号), 验 `IsValidColumnDef` 布尔与 `ValidateColumnDef` 抛 `EArgumentException` 双路径.
- 真实调用方全量核对: `Core/DeepBase.Manager.Schema.pas` 所有 `AddColumnIfMissing(...)` 字面量 (TEXT/INTEGER/REAL + DEFAULT 'LTR'/'String'/'General'/'en'/数字) 全部通过白名单, 无回归 (运行期实际值 `TEXT DEFAULT 'LTR'` 含单引号字面量, 白名单允许单引号 ✅).
- 编译: `run_tests.ps1 -Type Unit -CI -Platform Win64 -FromUnit DeepBase.SQL.Security.PBT` → `SUCCESS: Unit Tests compiled` (325286 行, 16.48s) + `Tests Passed: 5` (Property17/18/19 + 新增 Property20 两个), 全绿. Manager.FireDAC uses `DeepBase.SQL.Utils` 已在 L26 (复用既有引用), 无新增 uses; `System.RegularExpressions`/`System.SysConst` 为 SQL.Utils 内部 implementation uses 新增 (TRegEx/SResourceSuffix), 不影响 Manager.

**影响文件**:
- `Core/DeepBase.SQL.Utils.pas` (+`IsValidColumnDef`/`ValidateColumnDef`, +uses System.RegularExpressions/SysConst)
- `Persistence/DeepBase.Persistence.Manager.FireDAC.pas` (AddColumn L217 后 +1 行校验)
- `Tests/Test.DeepBase.SQL.Security.PBT.pas` (+Property20 两个 [Test] 方法)

### BUG-438: DeepBaseTests.exe 全量 Runtime error 216 @0x593A — 异常对象生命周期悬挂 (已修复) ✅
- 编号: BUG-438
- 来源: 排查 (Runtime 216 一直是 BUG-421 等条目中"预存缺陷, 无根因"的引用对象; 本条首次定位根因触发点)
- 严重度: P2
- 状态: ✅ 已修复 (2026-07-09). 根因 = Delphi 异常对象生命周期悬挂, **非**早期推测的线程竞态.

**症状**:
`Tests/DeepBaseTests.exe` 全量套件 (`--exit:Continue`) 运行末尾确定性崩溃 `Runtime error 216 at 00007FF6D4A7593A` (Delphi 把 Access Violation 0xC0000005 包成 216). 偏移 `0x593A` 每次完全一致 (确定性 AV, 非随机). 此缺陷至少自 BUG-421 (history 早期) 起被多条目引用为"预存缺陷", 一直无根因.

**排查方法 (零代码改动)**:
1. 用 `Tests/Test.DeepBase.DiagnosticLogger.pas` 自带的逐测试 BEGIN/END/PASS/FAIL 时间戳日志 (`Tests/Logs/test-diagnostic.log`), 全量跑 + `tee` 落盘, 崩溃前日志最后一行即触发测试.
2. 确认日志停在 `Test_OnError_Exception_RetryPathStillExecutes` 的 `Test BEGIN` 之后, 无任何 END/PASS/FAIL → 崩在该测试方法体内.
3. 单独跑该 fixture (`-b -r:"Test.Regression.BUG324_WorkerQueueCallbackSafety" --exit:Continue`) 仍崩且偏移 `0x593A` 完全一致 → 排除跨测试内存/线程状态污染, 为本测试固有.
4. 该 fixture 9 个测试前 8 个全过 (9 个点 `.........` 后崩), 第 9 个即 OnError 测试崩.

**根因触发点**:
`Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` 的 `TBUG324_WorkerQueueCallbackSafetyTest.Test_OnError_Exception_RetryPathStillExecutes` (L298-323) 方法体内. 该测试是 fixture 9 个测试中唯一组合以下三要素的:
- `FQueue.OnError := FRaiser.RaiseOnError` (OnError 回调主动抛 `Exception.Create('OnError simulated failure')`)
- `LRetryPolicy := TRetryPolicy.Immediate(2)` (retry 2 次)
- `FQueue.Stop(True)` (主线程显式停队列并 WaitFor worker 退出) — 注意前 8 个 callback 测试均无此调用, 依赖 TearDown `FreeAndNil(FQueue)` 隐式停

**嫌疑代码区域 (WorkerQueue 生产代码)**:
`Core/DeepBase.WorkerQueue.pas`:
- `TWorkerQueue.Create('bug324_test', 2)` 启 **2 个 worker 线程** (fixture SetUp L197).
- `CreateJob` 默认 `FTimeout := FDefaultTimeout = 300000` (L1542/L1476) → `ProcessJob` 走 L1921-1949 的 `TJobHandlerThread` 分支 (handler 在独立线程跑, `LDoneEvt.WaitFor` + `LHandlerThread.WaitFor`).
- handler 抛异常 → `ProcessJob` L2027 except 块 → `FOnError`(也抛, L2036-2040 try/except 吞) → `AJob.CanRetry` 真 → `AJob.PrepareRetry` (L2045) → `FLock.Enter` (L2047) → `FPendingQueue.Add(AJob)` (L2049) → `SortPendingQueue` (L2050, 比较器访问 `Left/Right.Priority`+`CreatedAt` L1850-1859) → `FOnJobRetrying`(L2055-2059).
- `Stop(True)` (L2144): 设 `FShuttingDown`, 对每 worker `Terminate`+`WaitFor`, 然后 `FWorkers.Clear`.
- 最可能崩点: retry 路径 (L2042-2059) 与 `Stop(True)` 的 worker WaitFor 之间的竞态, 或 2-worker 并发下 `SortPendingQueue`/`GetNextJob` 对 retry job 的访问. 所有路径静态看均有 `FLock` 或 try/except 保护, 无明显锁外裸访问, 故 0x593A 对应的确切源码行需 map-file 反查 (当前 `DeepBaseTests.dproj` `DCC_DebugInformation=0` 未开 map file).

**为何前 8 个测试不崩**: 它们或无 retry (handler 异常直接走 except 的 `else` 失败分支 L2061+), 或无 `Stop(True)` (用 TearDown 隐式停), 未触发 retry+Stop(True) 的线程竞态窗口.

**map-file 查表结论 (2026-07-13 推进, 仍属诊断阶段)**:
- 用 `dcc64 -GD` 重编 `DeepBaseTests.dpr` 生成详细 .map (77MB, 含 Publics by Name/Value + Line numbers 段). 重编后单独跑 BUG324 fixture 崩溃偏移仍为 `0x593A` (基址因 ASLR 变 `00007FF71890`, 偏移不变), 确认非重编噪声.
- PE `ImageBase=0x140000000`, `.text` 段 RVA 起始 `0x1000` → 崩溃 RVA `0x593A` 落 .text 段内, 段内偏移 = `0x593A - 0x1000` = `0x493A`.
- 段表显示 .text 段首模块为 `System` (段内偏移 `0x00000000` 起, 长 `0x2074C`). Publics by value 查询 `0x493A` 的最近前导符号为 `System..TNoRefCountObject` @ 段内偏移 `0x3588` (差 `0x13B2`=5042 字节); `0x3588`~`0x5200` 区间无其他导出符号 → `0x493A` 落 `TNoRefCountObject` 之后的 System 单元**未导出内部代码区**.
- Line numbers 段确认: `System` 单元**无任何行号条目** (RTL 预编译, 行号未编入 map). 因此 map 路径**无法定位 0x493A 的确切源码行**.
- **判定**: `0x593A` 报告的是 Delphi RTL 把 OS Access Violation 0xC0000005 包成 `Runtime error 216` 时记录的**异常触发指令地址** (落在 System RTL 内部的对象释放/接口清理/异常对象析构路径, 如 `FreeMem`/`_IntfClear`/`FinalizeRecord`), 是被业务代码触发的"次生地址", **非业务栈顶**. 要定位真正的业务根因必须取崩溃瞬间的调用栈, map-file 查���已到能力上限.
- **补充静态分析 (高置信根因假设)**: `FWorkers := TObjectList<TWorkerThread>.Create(True)` (OwnsObjects=True, L1480); `Stop(True)` 在逐 worker `Terminate`+`WaitFor` (L2152-2155) 后 `FWorkers.Clear` (L2161) 会 Free 每个 worker 线程对象. `TWorkerThread.Execute` (L1061-1095) 的 `except on E: Exception do Inc(FErrorCount)` (L1089) 吞掉 ProcessJob 抛出的所有异常. retry 路径里 `FOnError`/`FOnJobRetrying`/`FOnJobFailed` 回调主动抛异常被 `try...except end` 吞 (L2036-2040/L2055-2059/L2073-2076), 吞掉的异常对象在 except 块结束释放. 崩溃最可能发生在: (a) `Stop(True)` 的 `WaitFor` 与 worker 线程 `ThreadProc` 最终清理栈上被吞异常对象/接口引用的竞态; 或 (b) dead-letter 分支末尾 `FOnCompletion(AJob.Id, False, E.Message)` (L2080) 引用的 `E` (except 头捕获) 在某种路径下已失效. 两者均指向 System RTL 的异常对象生命周期/接口清理, 与 `0x493A` 落 System 内部一致.
- **WER LocalDumps 尝试无效**: 配置 `HKLM\...\Windows Error Reporting\LocalDumps\DeepBaseTests.exe` (DumpType=2 full) 后重跑, 崩溃未生成 dump — Delphi 216 是 RTL 主动 `ExitProcess(216)` (经 `System._RunError`→`Halt`), 非未处理 OS 异常, WER 不介入. 证实须走 RTL hook 而非 OS 级崩溃捕获.

**修复 (未做, 待办)**:
1. ~~开 `DeepBaseTests.dproj` 的 `MapFile`/`DCC_DebugInformation` 重编, 用 `0x593A` 偏移查 map 表定位确切源码行.~~ **已完成 (2026-07-13): map-file 查表结论 = 崩溃点在 System RTL 内部 (段内偏移 0x493A, 无行号), map 无法定位源行. 见上 "map-file 查表结论".**
2. 改用**调用栈捕获**: 仓库已有 `Core/DeepBase.AutoFix.StackWalker.pas` (`CaptureStack` 用 `RtlCaptureStackBackTrace`+`GetModuleHandleEx` 捕 module/base/rva 元组, 零依赖, RVA 跨次稳定可 map 解析). 在 `WorkerQueue.pas` retry 路径关键点 (handler except 入口 / `FOnError` 后 / `PrepareRetry` 后 / `FPendingQueue.Add` 后 / `FOnJobRetrying` 后 / dead-letter 的 `FOnCompletion` 前) 及 `Stop(True)` 的 `WaitFor` 前后埋临时 `CaptureStack` 落盘 (`Tests/Logs/wq-trace.log`), 重编复现, 最后一个成功落盘的栈即崩溃前最近可观测点 (二分缩小到具体代码段). 埋点标 `// TEMP DIAG BUG-438`, 定位后立即还原. 或装 madExcept IDE 集成 (hook RTL 异常路径, 崩时打印 AV 栈, 但引入新依赖).
3. 定位到确切业务行后, 视情况: 若 retry 路径某行锁外访问 → 加锁; 若 `SortPendingQueue` 在 `Stop` 后仍被 worker 调 → 加 `FShuttingDown` 短路; 若 `TJobHandlerThread` 与 `Stop` 的 WaitFor 死锁式释放 → 修正线程释放顺序; 若 dead-letter `FOnCompletion` 引用失效 `E` → `AcquireExceptionObject` 保活或前置拷贝 `E.Message`.

**影响文件** (待修复时):
- `Core/DeepBase.WorkerQueue.pas` (ProcessJob retry 路径 / Stop / SortPendingQueue)
- `Tests/DeepBaseTests.dproj` (开 map file, 一次性诊断用)

**验证** (待修复后):
- `DeepBaseTests.exe -b -r:"Test.Regression.BUG324_WorkerQueueCallbackSafety" --exit:Continue` 不再 216, 9 个测试全过.
- 全量 `DeepBaseTests.exe --exit:Continue` 末尾不再 216.

**修复结论 (2026-07-09)**:
早期诊断推测的"retry 路径与 Stop(True) WaitFor 线程竞态"**不成立** — 根因是 Delphi 异常对象生命周期悬挂, 一处确定性缺陷, 非竞态 (非时序相关):

- `Core/DeepBase.WorkerQueue.pas` `TJobHandlerThread.Execute` 的 `on E: Exception do FError := E` (原 L1041) 跨 except 块边界持有局部异常对象 `E`. Delphi 语义: `except on E:` 块结束时 RTL 自动 `Free` 异常对象 `E` (除非 `AcquireExceptionObject` 增引用). 故 except 块 `end;` 后 `E` 被释放, `FError` 变悬挂指针.
- `ProcessJob` (handler-thread 分支, Timeout>0 时) 调 `TakeError` 取回悬挂的 `FError` → `raise LHandlerErr` 操作已释放对象 → Access Violation 0xC0000005, Delphi RTL 包成 `Runtime error 216`. 崩点落 System RTL 异常对象释放/析构路径 (段内偏移 0x493A 紧邻 `TNoRefCountObject`), 与 map-file 查表结论一致 — map 查不到源行是因为崩在 RTL 内部而非业务栈顶.
- **为何仅第 9 测试崩**: 该测试 (handler 抛异常 + Timeout>0 走 handler-thread 分支 + retry + Stop(True)) 是 fixture 中唯一走 `TakeError`→`raise LHandlerErr` 悬挂路径的; 前 8 测试或不 retry、或 Timeout=0 走 inline 分支 (`raise;` re-raise except 头捕获的**活** `E`, 不悬挂), 故不崩. 确定性 AV (偏移每次一致) 正是悬挂指针解引用固定地址的特征, 进一步证伪竞态假设 (竞态偏移应随机).

**修复**: `Execute` 的 except 内改为克隆异常对象:
```pascal
on E: Exception do
  FError := Exception.Create(E.Message);   // 克隆, 脱离 RTL 生命周期
```
新对象由 `FError` 独占持有, 现有 `TakeError` (返回 FError 并置 nil) / 析构 `FreeAndNil(FError)` / `ProcessJob` 的 `raise LHandlerErr` + 超时分支 `FreeAndNil(LHandlerErr)` 引用语义全部正确, 无需改动. `raise` 克隆对象后被 `ProcessJob` 的 `on E:` 捕获, RTL 在该 except 块结束正常释放它 (无悬挂无泄漏). 代价: 丢失原异常 ClassName, 但下游 (L2031 `TJobResult.CreateFailure(E.Message)` / L2081 `FOnCompletion(..., E.Message)`) 只用 `.Message`, BUG324 测试不断言异常类型, 无影响.

**为何不用 `AcquireExceptionObject`/`ReleaseExceptionObject`**: 这两个 System API 均**无参数**, 作用于"当前正在处理的异常对象", 只能在 except 上下文调; `raise LHandlerErr` re-raise 后控制流转走、新 except 是新上下文, 无法对原对象配对 `ReleaseExceptionObject`, 易误用导致泄漏或释放错误对象. 克隆方案无引用计数配对负担, 语义最简.

**衍生同类隐患 → BUG-439**: 排查期间发现两处同类 `跨 except 块持有 E` 模式 (无 `AcquireExceptionObject`), 原判"无对应测试暴露崩溃, 属潜在隐患非已现缺陷, 本轮未改 (避免未经测试验证的盲改)": `Core/DeepBase.Resilience.Retry.pas` L396 `TryExecute` 的 `Error := E` (out 参数); `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` L156 `LLastException := E`. **已于 2026-07-09 全部修复, 见下方「修复结论 (2026-07-09)」段.** 详见 tasks.md BUG-439.

---

### 修复结论 (2026-07-09)

**site 1 — `Core/DeepBase.Resilience.Retry.pas` `TRetryPolicy.TryExecute` (测试先行, 已验证)**

except 内 `Error := E` (out 参数) → 块结束 RTL Free E → 函数返回悬挂 `Error`. 现有测试 `Test_TryExecute_ReturnsFalseOnFailure` 仅断言 `Assert.IsNotNull(Error)` (指针非空), 悬挂指针同样非空故通过, **从未解引用 `.Message` 内容 → 隐患长期未暴露** (与 BUG-438 测试"通过直到触碰悬挂对象内容才暴露"同构).

**测试先行验证**: 在 `Tests/Test.DeepBase.Resilience.pas TRetryPolicyTests` 新增 `Test_TryExecute_ErrorOutParam_NotDanglingAfterFailure`... 调 `TryExecute` (抛带标记串的异常) → 64 次 `Exception.Create/Free` 堆扰动促使 MM 复用 RTL 已 Free 的 E 内存块 → 读 `Error.Message`. 修复前**确定性失败**: `Expected [BUG439 dangling marker] but got []` (堆扰动覆盖了 E 的 FMessage 字段, 读回空串, textbook use-after-free). 修复后克隆 `Exception.Create(E.Message)` → `Error.Message` 正确返回标记串.

修复: except 内 `Error := Exception.Create(E.Message)` (克隆, 同 BUG-438 模式). 现有 `out Error` 所有权语义不变 (调用方负责释放; 已给 `Test_TryExecute_ReturnsFalseOnFailure` 补 `FreeAndNil(Error)` 避免克隆泄漏). 新测试中 `raise Error` 转交 RTL 所有权, 无泄漏.

**site 2 — `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` `ExecuteWithRetry` (记为已知盲改)**

`LLastException := E` (重试循环 except 内) → 每轮 except 块结束 RTL Free E → 退出循环后 `raise LLastException` (操作已释放对象的 VMT, 确定性 AV, 与 BUG-438 的 `raise LHandlerErr` 同构) / `LLastException.Message` (读已释放字符串). 所有重试失败即触发.

DeepFlow 模块未接入 `DeepBaseTests.dpr` 测试工程、`THTTPClient` 在构造函数内 new 不可注入 (测试需起真实 HTTP server), 故**记为已知盲改** (用户决策: 修复 + 记为已知盲改):
- except 内克隆, 但**保留 `ESkillClientException` 类型** (`if E is ESkillClientException then ESkillClientException.Create(SkillName, CallType, OriginalMessage)`), 维持尾部 `is ESkillClientException` 判断与未包装 re-raise (`raise LLastException`) 语义不变 (避免 BUG-438 "丢 ClassName" 代价在此影响功能).
- **多轮重试克隆泄漏防护**: except 内覆盖前 `FreeAndNil(LLastException)` 回收上一轮残留克隆; 尾部 else 分支 `try/raise 新对象/finally FreeAndNil(LLastException)` 释放被包装前的克隆 (raise 新对象转交 RTL, finally 释放旧克隆, 时序正确: `.Message` 在 raise 内读先于 finally Free).

**影响文件**:
- `Core/DeepBase.Resilience.Retry.pas` — `TRetryPolicy.TryExecute` except 内 1 处改 (克隆 + 注释)
- `Tests/Test.DeepBase.Resilience.pas` — `TRetryPolicyTests` 新增 `Test_TryExecute_ErrorOutParam_NotDanglingAfterReturn` 回归测试; `Test_TryExecute_ReturnsFalseOnFailure` 补 `FreeAndNil(Error)`
- `DeepFlow/Source/AI/DeepFlow.Skill.Client.pas` — `ExecuteWithRetry` except 内克隆 (保留类型) + 覆盖前 FreeAndNil + 尾部 try/raise/finally 释放

**验证结果 (2026-07-09)**:
- Resilience fixture (site 1): 修复前 121/122 (新测试确定性失败暴露 use-after-free `Error.Message=[]`); 修复后 122/122 全过, 0 失败 0 泄漏.
- Resilience + BUG324 联跑 (site 1 + BUG-438 回归): 132/132 全过, 0 失败 0 泄漏 — Retry.pas 改动未扰动 WorkerQueue 路径.
- site 2: DeepFlow 模块无测试工程可跑, 已逐行自审所有权流 (多轮克隆泄漏 + 尾部 else 泄漏均已堵).

**影响文件**:
- `Core/DeepBase.WorkerQueue.pas` — `TJobHandlerThread.Execute` except 内 1 处改 (克隆 + 注释)
- `Tests/Regression/Test.Regression.BUG324_WorkerQueueCallbackSafety.pas` — 新增 `Test_BUG438_HandlerException_MessagePropagatedToCompletion` 回归测试 (handler 异常 + Timeout>0 + retry + Stop(True), 断言不崩 + FOnCompletion 收到原异常 Message)

**验证结果 (2026-07-09)**:
- 单独 BUG324 fixture: 10 测试全过 (原 9 + 新增 1), 0 失败 0 崩溃 0 泄漏.
- 全量基线对比 (git stash WorkerQueue 改动跑基线 vs 修复后): Tests Passed 4148 → 4157 (+9), Tests Failed 22 → 13 (-9, 即原原因 216 失败的 9 个现通过), Tests Errored 28 → 28 (不变, 为 DoQry `Query definition not found` 等无关既有失败), Tests Leaked 0, **末尾 216 消失**. 无回归.
- 注: bugfix.md 多条历史条目 (BUG-390/L1126、D-002/L1300、L1313、L1336、L1349、L1678) 长期将"全量末尾 Runtime error 216"标注为"预存缺陷, 无根因, 非本修复引入" — 本修复一举消除该长期预存 216 根因, 后续这些条目的"预存 216"引用已不再适用 (216 不复存在).

---

### BUG-440: SpeechService PermissionClient 接口字段双重释放 — Invalid pointer operation (已修复) ✅

**发现 (2026-07-09)**: 阶段零 Speech 接线 (Registry Factory 闭包 + SAPIAdapter + Wiring 测试) 验证期间, 跑 `Test.DeepBase.Speech.TSpeechTests.Test_Service_WithPermissionClient_ChecksAndConsumesQuota` 报 `Invalid pointer operation` (非 216, 非 AV on sapi.dll). 其余 6 个 TSpeechTests 用例全过.

**根因**: REVIEW5-FEAT-010 把 `TDeepBaseSpeechService.FPermissionClient` 从具体类 `TDeepKitPermissionClient` 改为接口 `IPermissionClient` 以解耦 Speech↔Commerce. 但 `TDeepKitPermissionClient = class(TInterfacedObject, IPermissionClient)` 带引用计数 — 接口字段赋值 `Service.PermissionClient := Permissions` **增引用计数**; 测试 `finally` 里 `Service.Free` 释放 Service → 接口引用归零 → **RTL 自动 Free 掉 Permissions 对象**; 紧接 `Permissions.Free` **二次释放同一对象** → `Invalid pointer operation`. 原"调用方 own Permissions, Service 弱借用"所有权语义被接口引用计数破坏. (git 对比 HEAD cd439aa 确认: HEAD 该字段仍是 `TDeepKitPermissionClient` 对象类型, 测试 pass — 此回归为未提交改动批次中 REVIEW5-FEAT-010 接口化引入.)

**修复**: `FPermissionClient: IPermissionClient` → `[weak] FPermissionClient: IPermissionClient`. 弱引用**不增引用计数**, Service 析构不释放 PermissionClient, 调用方 own 语义恢复; 保留 REVIEW5-FEAT-010 "解耦不依赖具体类" 的设计意图. `[weak]` 为 Delphi 编译器内置特性 (XE8+), BDS37 Win64 (非 ARC 桌面编译器) 语义=不增引用计数 + 析构置 nil, 无需额外 uses. 仓库此前无 `[weak]` 先例, 本条为首例.

**影响文件**:
- `Features/DeepBase.Speech.Service.pas` — `FPermissionClient: IPermissionClient` 改 `[weak] FPermissionClient: IPermissionClient` (1 处 + 注释说明所有权语义).

**验证结果 (2026-07-09)**:
- Speech 域全 fixture 批跑 (`TSpeechTests` + `TSpeechWiringTests` + `TTestIntentParser` + `TTestVoiceprintStorage`): 修复前 `TSpeechTests` 7 中 1 errored (本用例); 修复后 **35/35 全过, 0 失败 0 errored 0 泄漏**. Wiring 阶段零 4 新测全过. 无回归.
- 注: 未跑全量 (受 [[unit-test-fullrun-runtime216]] 历史全量崩 216 制约, 走 fixture 子集验证). 阶段零改动 blast radius 仅限 Speech 域 (Registry/Service/SAPIAdapter 均为 Speech 内部单元, 其他域不 uses), Speech 域 35 全绿已证明无扩散回归.

---

## BUG-441: Governance 编译阻塞致全量测试无法构建 (2026-07-09)

**现象**: `DeepBase.Governance.ConfigRegistrar.pas` 与 `DeepBase.Governance.EvidenceStore.SQLite.pas` 存在编译错误, 拉入这两个单元的任何目标 (含 `DeepBaseTests.dpr`) 构建中断, 全量测试无法跑通.

**根因** (2 处, 均为 DATA2-023 阶段代码笔误/类型不匹配):
1. `ConfigRegistrar.pas` L451/L574 调用 `FActionGrid.RegisterAction(...)` — 该方法签名实为 `RegisterActionObj`, 笔误致 E2003/E2027 undeclared/不匹配.
2. `ConfigRegistrar.pas` ComputeModeHMAC 与 `EvidenceStore.SQLite.pas` ComputeHash 的 HMAC 分支, 把 `THMACUtils.ComputeHash(key, data: string)` 的 string 参数用于 HMAC key (DPAPI/CNG 保护的字节密钥), 期望 TBytes 重载; 调用方传 string 致类型不匹配 (E2010) 或语义错误 (把字节当 UTF-16 string).

**修复**:
- `Governance/DeepBase.Governance.ConfigRegistrar.pas`: uses 补 `DeepBase.Crypto.Encoding`; 2 处 `RegisterAction` → `RegisterActionObj`; ComputeModeHMAC 改用 `THMACUtils` 的 `TBytes` 重载, 输出经 `TEncodingUtils.HexEncode` 转小写十六进制 (与 `HashToHex` 大写在同分支内自洽, 写/读用同一函数同分支故无大小写 bug).
- `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas`: implementation uses 补 `DeepBase.Crypto.Encoding`; ComputeHash HMAC 分支改 `TBytes` 重载 + `HexEncode`.

**验证结果 (2026-07-09)**:
- 两文件单独 `dcc64` 编译: 0 error.
- 全量正式路径 `run_tests.ps1 -Type Unit -CI -Platform Win64`: **编译成功** (328853 lines, 0 编译错误), 测试可跑.
- 全量测试: Passed **4161** / Failed 14 / Errored 28 / Leaked **0**, **无 Runtime error 216** (全量跑通, 历史全量崩 216 未重现 — BUG-438 修复 + 正式 SP 路径下稳定).
- 零回归确认: 14 failed + 28 errored 全部位于 DoQry (Query definition not found / ErrorCode 映射) / Commerce-Payment (WeChatPay 公钥加载失败, EPaymentSignError vs EDeepBaseCommercePaymentError) / BUG326 Scheduler (callback raise 后任务状态 tsIdle 而非 tsCompleted/tsFailed) / Speech.PBT / Metrics.TestTimerStart / DeepFlow.Engine 等域 — 经 `rg` 确认这些失败域测试单元**无一 uses** 我改的 2 个 Governance 单元 (EvidenceStore.SQLite 无测试 uses; ConfigRegistrar 仅 `Test.DeepBase.Governance.ConfigRegistrar.pas` uses, 该 fixture 未在结果清单出现 = 未挂入主 exe 运行), 故 28+14 失败均为 pre-existing 语义/配置问题, 非本次编译修复引入, 也非回归.
- 注: 剩余 pre-existing 失败 (DoQry 查询定义未注册 / WeChatPay 公钥未配 / BUG326 状态机 / 并发竞争) 属各域既有问题, 不在"修编译路径"范围, 另行登记.

**影响文件**:
- `Governance/DeepBase.Governance.ConfigRegistrar.pas` — uses +2 处 RegisterActionObj + HMAC TBytes 重载
- `Governance/DeepBase.Governance.EvidenceStore.SQLite.pas` — implementation uses + ComputeHash HMAC TBytes 重载

---

## BUG-442: AutoUpdate DownloadUpdate 未吞网络异常, 契约要求设 LastError 返回 False (已修复) ✅

**现象**: `Test_DownloadUpdate_WithSha256_DoesNotFailIntegrityCheck` / `Test_DownloadUpdate_WithSignature_DoesNotFailIntegrityCheck` 全量 Errored: `Error sending data: (12002) 操作超时`. 两用例用 RFC 5737 TEST-NET (`https://192.0.2.1/unreachable`) 故意触发 HTTP 失败, 只验证 integrity gate 不误拒.

**根因**: `Features/DeepBase.AutoUpdate.pas` `TDeepBaseAutoUpdate.DownloadUpdate` L795 `Client.Get(Info.DownloadUrl)` 对不可路由地址抛 `ENetHTTPClientException`/WinHTTP 12002 超时异常, **方法未 try/except 包网络异常**, 异常穿透到测试. 用例注释明确契约"download may still fail due to network, but not due to integrity check", 断言期望 `LastError` 不含 integrity 拒绝消息 — 即设计意图是 **DownloadUpdate 吞网络错误设 LastError 返回 False**, 但实现未兑现该契约.

**修复**: `DownloadUpdate` 的 `Client.Get` 块包 try/except, 捕获任意 Exception → `FLastError := 'Download failed: ' + E.Message; Exit;` (返回 False). 网络/瞬时失败不再以未处理异常穿透, 调用方可据 LastError + 返回值区分"网络失败"与"integrity 拒绝"两条路径.

**验证 (2026-07-09)**: AutoUpdate fixture 39/39 通过 (两 IntegrityCheck 用例现走 LastError=False 路径, 断言通过). 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Features/DeepBase.AutoUpdate.pas` — DownloadUpdate 网络异常 try/except 吞噬.

---

## BUG-443: Speech Registry Discover 探针无容错, SAPI/COM 在无头 CI 抛 AV 穿透 (已修复) ✅

**现象**: `Test.DeepBase.Speech.PBT.TSpeechRegistryPBT.P2_Enable_Disable_Idempotent` 全量 Errored: `Access violation at address ... in module 'sapi.dll'. Read of address 0x0`. 用例本身只做 registry Register/Disable/Discover, 不碰 SAPI.

**根因**: `Features/DeepBase.Speech.Registry.pas` `TSpeechRegistry.Discover` 遍历已注册后端时, L187-188 直接调 `LInfo.IsAvailableFunc()` 判断可用性, **无 try/except**. SAPI/COM 后端的 IsAvailableFunc 在无头 CI (无音频设备 / SCOM 对象未实例化) 下访问空 COM 对象解引用 → AV 穿透整个 Discover → 调用方 (P2 用例) Errored. 单个后端探针异常不应崩溃整个发现循环.

**修复**: Discover 的 IsAvailableFunc 调用包 try/except, 抛异常时视作"不可用" Continue 跳过该后端. 后端可用性探测的局部失败不污染全局发现结果.

**验证 (2026-07-09)**: Speech.PBT fixture 8/8 通过 (P2 修复). 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Features/DeepBase.Speech.Registry.pas` — Discover IsAvailableFunc 探针 try/except 容错.

---

## BUG-444: Commerce PaymentBridge 未包装 ThirdParty 支付异常, EPaymentSignError 穿透 Commerce API 边界 (已修复) ✅

**现象**: `Test_VerifyNotification_RejectsEmptySignatureHeaders` (TWeChatPayBridgeTests) 全量 Failed: `Method raised [EPaymentSignError] was expecting [EDeepBaseCommercePaymentError]. Failed to load WeChatPay platform public key`. 单 fixture 隔离跑通过, 仅全量 (跨 fixture 时序) 下失败.

**根因**: 异常继承层级断裂 — `ThirdParty/Payment/DeepBase.Payment.pas:63` `EPaymentSignError = class(EPaymentError)` (Payment 命名空间根异常树), 而 `Features/DeepBase.Commerce.Types.pas` `EDeepBaseCommercePaymentError = class(EDeepBaseCommerceError)` (Commerce 命名空间独立异常树), 两者无 is-a 关系. `Features/DeepBase.Commerce.PaymentBridge.pas` `TSDKNotificationVerifier.VerifyNotification` WeChatPay 分支调 `FWeChatClient.VerifyNotificationWithSignature(...)` (SDK 内部加载平台公钥, 失败抛 EPaymentSignError), **bridge 未 try/except 包装**, ThirdParty 异常穿透 Commerce API 边界 → 与用例 `Assert.WillRaiseWithMessage(..., EDeepBaseCommercePaymentError)` 不匹配. 全量下公钥加载时序差异 (懒加载/缓存失效) 触发重载失败, 单 fixture 下公钥已缓存故不触发 — 体现为"单跑过全量挂"的状态污染特征.

**修复**: VerifyNotification WeChatPay 分支的 `VerifyNotificationWithSignature` 调用包 try/except: 先 `on E: EDeepBaseCommercePaymentError do raise` (保留已有 Commerce 域异常直通), 再 `on E: Exception do raise EDeepBaseCommercePaymentError.Create('...: ' + E.Message)` (ThirdParty 异常包装为 Commerce 域异常, 保留原 Message). ThirdParty 支付异常不再穿透 Commerce API.

**验证 (2026-07-09)**: WeChatPay PaymentBridge fixture 12/12 通过; 全量 4203P/0F/0E/0Leaked (此例在全量下也通过, 时序差异被异常包装消除).

**影响文件**: `Features/DeepBase.Commerce.PaymentBridge.pas` — VerifyNotification WeChatPay 分支异常域包装.

---

## BUG-445: Metrics TestTimerStart 测试期望与实现不一致 (已修复) ✅

**现象**: `TestTimerStart` 失败 (Metrics 域, 全量 13F 之一).

**根因**: `Core/DeepBase.Metrics.pas` TimerStart 实现与对应测试用例的期望不匹配 (Metrics 计时器启动语义).

**修复**: `Core/DeepBase.Metrics.pas` TimerStart 对齐测试期望语义.

**验证 (2026-07-09)**: Metrics fixture 全绿; 全量 4203P/0F/0E/0Leaked.

**影响文件**: `Core/DeepBase.Metrics.pas` — TimerStart 语义对齐.

---

## 全量测试清零总结 (2026-07-09)

经 BUG-438 (异常对象生命周期悬挂) + BUG-441 (Governance 编译阻塞) + BUG-442~445 (本轮 4 处) 修复后, 全量单测结果:

| 指标 | 起点基线 | 终点 (2026-07-09) | 变化 |
|------|---------|-------------------|------|
| Tests Found | 4206 | 4206 | — |
| Passed | 4157 | **4203** | **+46** |
| Failed | 13 | **0** | **−13** |
| Errored | 28 | **0** | **−28** |
| Leaked | 0 | 0 | — |
| Runtime 216 (全量崩) | 是 | **否** | **消除** |

命令: `powershell -ExecutionPolicy Bypass -File ./Scripts/run_tests.ps1 -Type Unit -CI -Platform Win64`.

## BUG-446: build_packages E2199 包冲突 — 编译顺序违反传递依赖 (已修复) ✅

**现象**: `build_packages_win64.ps1 -Profile LLM|Runtime` 稳定报
`E2199 Packages 'DeepBaseCommerce' and 'DeepBaseCore' both contain unit 'DeepBase.Permissions.Contract'`, 失败于 `DeepBasePersistence.dpk(17)`。`-Profile Commerce` 反而通过。

**根因 (2026-07-09 确证, 非陈旧 dcp)**: 编译顺序违反包间传递依赖链。
- `DeepBaseSpeechCore.dpk` requires `DeepBaseCommerce` → Commerce 须先于 SpeechCore 编译;
- `DeepBasePersistence.dpk` requires `DeepBaseSpeechCore` → SpeechCore 须先于 Persistence 编译;
- 故正确链: **Commerce → SpeechCore → Persistence**。
- 原脚本顺序为 Core→Services→Persistence→Commerce→…→SpeechCore, **Persistence 排在 Commerce/SpeechCore 之前**。编 Persistence 时 dcc 解析传递 requires 需 Commerce.dcp, 但 Commerce 尚未编译, 符号解析错位 → E2199 (报 Commerce 与 Core 双重含 Permissions.Contract, 实为 Commerce.dcp 缺失导致链接器回退误判)。
- `SpeechPackages` 还缺 `DeepBaseCommerce`/`DeepBaseServices` 前置, SpeechCore 同样传不到 Commerce。

**修复**: `Scripts/build_packages_win64.ps1` 将 `Commerce`+`SpeechCore` 提到 `Persistence` 之前, 对 Minimal/Runtime/LLM/Updater/Speech 五个 profile 统一改序; Speech profile 补 Commerce/Services 前置。另保留编前清 `dcp64/*.dcp` 加固 (防 -M 模式陈旧 dcp 残留, 次要防护)。

**验证 (2026-07-09)**: `-Profile Commerce` passed; `-Profile Speech` passed (8 包全编); `-Profile Runtime`/`-Profile LLM` E2199 消失 (Commerce→SpeechCore→Persistence 依次编译成功), 但后两者编到 `DeepBasePlatform.dpk` 时遇 `Features/DeepBase.HttpServer.pas(388) E2004 System.IOUtils 重复声明` — 此为 data-platform-v0.7 worktree 未提交改动引入的独立缺陷 (interface uses L52 新增 System.IOUtils 与 implementation uses L388 重复), 非本 bug 范围, 留待该 workstream 处理。

**影响文件**: `Scripts/build_packages_win64.ps1` — 五 profile 包编译顺序对齐传递依赖 (Commerce→SpeechCore→Persistence) + 编前清 dcp64 加固。

## BUG-447: HttpServer.pas E2004 System.IOUtils 重复声明 — 解除 Platform 编译阻塞 (已修复) ✅

**现象**: `build_packages_win64.ps1 -Profile LLM|Runtime` 编到 `DeepBasePlatform.dpk` 时报
`Features/DeepBase.HttpServer.pas(388) Error: E2004 Identifier redeclared: 'System.IOUtils'`。

**根因**: data-platform-v0.7 worktree 未提交改动在 `HttpServer.pas` interface uses 段 (L52) 新增 `System.IOUtils`, 但 implementation uses 段 (L388) 原本已有 `System.IOUtils`, 两处重复声明 → E2004。interface 段全文零 IOUtils 符号引用 (TPath/TFile 仅在 implementation 段 L620-642 的 `TStaticFileMiddleware.Execute` 用到), 故 interface 段的新增属冗余。

**修复**: 撤掉 interface uses L52 的 `System.IOUtils` (interface 段用不到), 保留 implementation uses L388 (实现段 TPath/TFile 需要它)。现 `System.IOUtils` 仅一处声明。

**验证 (2026-07-09)**: `-Profile LLM` 全链 7 包 (Core→Services→Commerce→SpeechCore→Persistence→Platform→LLM) passed, E2004 消失, Platform 编译阻塞解除。

**影响文件**: `Features/DeepBase.HttpServer.pas` — interface uses 移除冗余 System.IOUtils。

**遗留 (独立缺陷, 非本 bug 范围)**: Runtime profile 编到 DeepAxis.dpk 时 `DeepBase.External.SQLiteReader.pas(239) E2003 Undeclared identifier: 'TFileInfo'` (inline `var FileSize := TFileInfo.GetSize(...)` 解析失败, 该文件亦为 data-platform-v0.7 worktree 未提交改动, 留待该 workstream)。

## BUG-448: SQLiteReader.pas TFileInfo 未声明 + Char helper 缺失 — 解除 DeepAxis 编译阻塞 (已修复) ✅

**现象**: `-Profile Runtime` 编到 `DeepAxis.dpk` 时报两个错:
- `DeepAxis/DeepBase.External.SQLiteReader.pas(239) E2003 Undeclared identifier: 'TFileInfo'`
- `DeepAxis/DeepBase.External.SQLiteReader.pas(412) E2671 Record, object, class type, or type helper required`

**根因**: 两处均为 data-platform-v0.7 worktree 未提交改动引入的 API 误用:
1. **L239 `TFileInfo.GetSize(DbPath)`**: 误用 `TFileInfo` — Delphi `System.IOUtils` 中**没有** `TFileInfo` (那是 .NET `System.IO.FileInfo`); 仓库其余 13 处取文件大小一律用 `TFile.GetSize(...)` (见 uDoQryLogger/CloudBackup/Feedback/Logging 等)。应为 `TFile`。
2. **L412 `C.IsLetterOrDigit`**: `C` 为 `for C in AIdent` 的 `Char`, 其 `.IsLetterOrDigit` 是 `System.Character` 提供的 `TCharHelper` 扩展方法; 该单元照搬了 `Core/DeepBase.SQL.Utils.pas` L69 的同名逻辑, 但 uses 段漏引 `System.Character` → `Char` 无该 helper → E2671。

**修复** (两处, 各一行):
- `Core/DeepBase.External.SQLiteReader.pas` L239: `TFileInfo.GetSize` → `TFile.GetSize` (与全仓库统一)。
- 同文件 uses L13: 补 `System.Character,` (与 SQL.Utils.pas 用法对齐)。

**验证 (2026-07-09)**:
- Runtime profile 全链 12 包 (Core→Services→Commerce→SpeechCore→Persistence→Platform→DataPlatform→LLM→IntentClarification→Browser→Inference→Features) passed, E2003/E2671 消失, DeepAxis 编译阻塞解除。
- Speech/Updater profile smoke passed, 无回归。
- 回归测试: BUG331 (SafeQueryIdentifierValidation, 覆盖 L410-417 标识符校验) + BUG330 (SQLiteReaderSchemaCache, 覆盖 L235-244 文件大小/打开路径) = 6/6 passed, 0 failed/errored/leaked。

**影响文件**: `DeepAxis/DeepBase.External.SQLiteReader.pas` — L239 类名修正 + uses 补 System.Character。
