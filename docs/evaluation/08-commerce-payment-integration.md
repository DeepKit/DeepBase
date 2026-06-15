# 电商支付与第三方集成评估报告

> 评估人：电商支付与第三方集成专家（12 年经验）
> 评估日期：2026-06-15
> 评估范围：DeepBase 框架 Commerce / Payment / Social / Cloud 模块

---

## 评估摘要

**总评分：7.5 / 10**

一句话结论：DeepBase 构建了一个架构清晰、抽象完整的电商支付框架，四大支付渠道（微信、支付宝、Stripe、PayPal）均有实质性实现，密钥安全存储（Credential Manager / SecretStore）和多渠道适配设计达到商用基础门槛；但存在 **Windows 平台锁定（RSA 签名/验签）、WeChat Pay V3 回调验签在 PaymentBridge 层缺失、PayPal 生产环境 webhook 签名校验路径不完整、缺少服务端幂等性存储** 等关键风险，距离生产上线仍需补全约 5 项高优先级修复。

---

## Commerce 核心模块评估（8.0/10）

### 架构优点

1. **分层清晰**：Types → Storage(接口) → Service(业务) → PaymentBridge(桥接) 四层分离，`ICommerceStorage` 接口抽象完整（`Storage.pas` 第 12-40 行），支持 In-Memory / Supabase / Firebase 三种后端。
2. **幂等性设计**（`Idempotency.pas`）：`TIdempotencyNonceTracker` 实现了客户端 nonce 跟踪，线程安全（`TCriticalSection`），带过期清理，格式为 `operation-timestamp-counter-GUID`（200+ 位熵）。
3. **防重放/双付**：`TDeepBaseCommerceService.ConfirmPayment` 使用 `TMonitor` 锁保护订单状态转换（`Service.pas`），`CreateOrder` 严格验证用户状态和产品有效性。
4. **桌面/服务端隔离**：`PaymentBridge.pas` 使用 `{$IFDEF DESKTOP}` 编译条件，桌面端编译时所有 verifier 工厂函数直接抛异常，防止密钥泄露到客户端。

### 问题

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | `ICommerceStorage` 缺少事务支持 — `CreateOrder` + `CreatePayment` 非原子操作，Supabase/Firebase REST API 无事务语义 | `Storage.pas:14-40` |
| **P2** | `TInMemoryCommerceStorage` 的 `ConsumeEntitlement` 未验证 `RemainingQuota > 0`，可能导致超额扣减 | `Storage.pas`（In-Memory 实现） |
| **P2** | `TDeepBaseCommerceService.CreateOrder` 生成 `OutTradeNo` 后未检查唯一性冲突（虽然 GUID 碰撞概率极低） | `Service.pas` CreateOrder 方法 |
| **P3** | `TIdempotencyNonceTracker` 是纯内存实现，进程重启后丢失，无法跨实例防重放 | `Idempotency.pas` 全文 |

---

## 支付渠道适配评估（ThirdParty/Payment）

### 抽象层设计（Payment.Core + Payment.pas）

**评分：8.5/10**

- `IPaymentClient` 接口定义完整：Create/Query/Close/Refund/QueryRefund/VerifyNotification/GetNotificationResponse，覆盖支付全生命周期。
- `TPaymentClient` 基类提供 HTTP 通信（`DoPost`/`DoGet`）和线程安全（`TMonitor.Enter(FHttpClient)`）。
- 异常层次清晰：`EPaymentConfigError`、`EPaymentSignError`、`EPaymentNetworkError`、`EPaymentBusinessError`。
- `TPaymentConfig` 集成 `ISecretStore`（Credential Manager），密钥不落盘明文。

**问题**：
- `TPaymentClient.DoPost` 在设置 `CustomHeaders` 后使用 `TMonitor` 锁，但 `DoWeChatPost` 等子类在锁外设置了 `CustomHeaders`（`WeChatPay.pas` 第 644-646 行），存在 **线程安全问题** — 两个并发请求会相互覆盖 Authorization 头。

### WeChat Pay（8.0/10）

**优点**：
- API V3 完整实现：Native / JSAPI / H5 / App 四种下单方式。
- RSA 签名使用 Windows BCrypt 直接调用（`SignWithPrivateKeyPem`），支持 PKCS#1 和 PKCS#8 私钥格式解析，DER 编码手动解析实现精确。
- 授权头构建正确：`WECHATPAY2-SHA256-RSA2048 mchid=...,nonce_str=...,signature=...,timestamp=...,serial_no=...`。
- 回调通知验证：`VerifyNotificationWithSignature` 实现了 HTTP 级签名校验（时间戳 + nonce + body → RSA-SHA256）+ AES-256-GCM 解密 resource 字段。
- 密钥安全存储：`SetApiKeyV3Secure` / `SetPrivateKeySecure` 通过 `ProtectKey` 存入 Credential Manager。

**问题**：

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | **RSA 签名/验签仅限 Windows**（`{$IFDEF MSWINDOWS}`）。非 Windows 平台直接抛异常，无法在 Linux 服务器上运行 | `WeChatPay.pas:505-515`, `VerifySignature` 非 Windows 分支 |
| **P2** | `DoWeChatPost` 在锁外设置 `CustomHeaders`（第 644-646 行），与基类 `DoPost` 内部的 `TMonitor.Enter` 不协调，并发场景下 Authorization 头可能被覆盖 | `WeChatPay.pas:644-646` |
| **P2** | `CreateJSAPIOrder` 第 800-801 行存在 **重复调用**：`DoWeChatPost('/v3/pay/transactions/jsapi', ReqBody)` 被调用了两次 | `WeChatPay.pas:800-801` |
| **P3** | `time_expire` 使用本地时间 + 固定偏移 `+08:00`，但 `Now` 本身可能是任意时区，应显式转 UTC+8 | `WeChatPay.pas:731` |
| **P3** | 证书序列号 (`SerialNo`) 为简单 string 属性，无过期检查 | `WeChatPay.pas:41` |

### Alipay（7.5/10）

**优点**：
- 支持四种支付方式：当面付 QR / 电脑网站 / 手机网站 / APP。
- RSA2 签名自动尝试 PKCS#8 和 PKCS#1 两种格式，兼容性好。
- `BuildCommonParams` 正确使用 `TTZInfo.Local.ToUniversalTime + IncHour(8)` 生成北京时间，避免本地时区偏差。
- 通知验证：`VerifyNotification` 内部调用 `VerifySignature` → `RSA2Verify`，完整实现 RSA2 验签。
- Sandbox/Production 网关自动切换。

**问题**：

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | **RSA2 签名/验签仅限 Windows**（`{$IFDEF MSWINDOWS}`），非 Windows 抛 `SIGN_NOT_IMPLEMENTED` | `Alipay.pas:311-314` |
| **P2** | `RSA2Verify` 中 `NormalizedKey` 注释行存在编码截断（第 334 行 `// 兼容仅传?Base64`），且直接拼接 PEM 头尾时使用 `sLineBreak` 而非 `\n`，可能在 Unix 系统上导致密钥加载失败 | `Alipay.pas:334-337` |
| **P2** | `ExecuteRequest` 解析响应节点时使用 `AMethod.Replace('.', '_') + '_response'`，但 Alipay 某些 API（如退款查询 `alipay.trade.fastpay.refund.query`）的响应节点名不一定遵循此规则 | `Alipay.pas:357` |
| **P3** | 缺少证书模式（`AppCertPath`/`AlipayCertPath`）的实际调用逻辑 — 属性已声明但未使用 | `Alipay.pas:65-67` |

### Stripe（8.5/10）

**优点**：
- 实现 Checkout Session 和 Payment Intent 两种模式。
- **Webhook 签名验证质量最高**（`VerifyWebhookSignature`）：
  - 正确解析 `t=timestamp,v1=signature` 格式
  - 时间戳容差 120 秒（已修复 BUG-109，从 300 秒降低）
  - HMAC-SHA256 签名计算正确
  - **常量时间比较**防止 timing attack（`Diff := Diff or (Ord(a) xor Ord(b))`）
- 幂等性：每次请求带 `Idempotency-Key` 头（格式 `cs_orderno_timestamp`）。
- Basic Auth 正确实现（`Base64(SecretKey + ':')`）。
- 生产环境强制签名校验（无签名头时抛 `SIGNATURE_REQUIRED`）。

**问题**：

| 级别 | 问题 | 位置 |
|------|------|------|
| **P2** | `DoStripePost`/`DoStripeGet` 在锁外设置 `CustomHeaders`（Authorization、Stripe-Version、Idempotency-Key），并发请求可能互相覆盖 | `Stripe.pas:213-218` |
| **P2** | `CreateCheckoutSession` 的 `expires_at` 使用 `DateTimeToUnix(Now + minutes/1440)` — `Now` 是本地时间，但 Stripe API 要求 UTC Unix 时间戳。如果系统不在 UTC 时区，过期时间会偏差 | `Stripe.pas:300` |
| **P3** | `QueryOrder` 直接调用 `RetrievePaymentIntent(AOrderNo)`，但 `AOrderNo` 是商户订单号，不是 Stripe PaymentIntent ID — 无法直接查询 | `Stripe.pas:403-406` |
| **P3** | `success_url`/`cancel_url` 默认使用 `https://example.com/success`，生产环境如果调用方未设置会产生死链 | `Stripe.pas:273-276` |

### PayPal（8.0/10）

**优点**：
- OAuth2 Bearer Token 管理：带缓存（`FAccessToken`/`FTokenExpiry`）和提前 60 秒刷新（`TOKEN_BUFFER_SECONDS`）。
- Token 获取使用 `TCriticalSection` 防止并发重复请求（PPL-01 fix）。
- Orders API v2 完整实现：创建、查询、退款。
- 退款时自动查找 capture_id（从 `purchase_units[0].payments.captures[0].id` 提取）。
- Webhook 验证调用 PayPal 官方 Verify API（`POST /v1/notifications/verify-webhook-signature`）。

**问题**：

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | **`VerifyNotification` 在生产环境直接 `Exit(False)` 无签名头**（`PayPal.pas` 第 749 行），但未像 Stripe 那样抛异常提示调用方使用带签名头的重载 — 静默失败，调用方可能误以为"验证通过但事件类型不匹配" | `PayPal.pas:749` |
| **P2** | `VerifyWebhookSignature` 使用 PayPal 的 HTTP API 验证，意味着每次验证 webhook 都要发一次 HTTP 请求到 PayPal — 高并发场景可能成为瓶颈 | `PayPal.pas:889-925` |
| **P2** | `DoPayPalPost`/`DoPayPalGet` 在锁外设置 `CustomHeaders`，与基类 `DoPost` 内部的 `TMonitor` 锁不一致 | `PayPal.pas:440-443` |
| **P3** | `CloseOrder` 直接返回 `True` 不做任何操作 — PayPal 订单确实会自动过期，但应记录日志 | `PayPal.pas:625-627` |
| **P3** | `application_context` 在 PayPal Orders API v2 已被弃用（2023 年），应使用 `payment_source` | `PayPal.pas:506-516` |

### AESGCM 加密（8.5/10）

**优点**：
- 跨平台实现：Windows BCrypt / macOS+Linux OpenSSL / 其他 fail-closed。
- 正确使用 AEAD：密钥 32 字节、Nonce 12 字节、Tag 16 字节，长度严格校验。
- Windows 实现使用 `BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO` 带 AAD 支持。
- 被 `TPaymentHelper.AES256GCMDecrypt` 正确调用，支持 WeChat Pay 通知解密（Base64 → Key/IV/Cipher → 分离 Tag → 解密）。

**问题**：

| 级别 | 问题 | 位置 |
|------|------|------|
| **P2** | OpenSSL 路径依赖 `DeepBase.Crypto.OpenSSL` 动态加载，但未检查 `OpenSSL_AES256GCM_Decrypt` 是否存在（如果 OpenSSL 版本过低 < 1.0.1c 不支持 GCM） | `AESGCM.pas:103-107` |
| **P3** | 未知平台（非 Windows/macOS/Linux）直接返回空 `TBytes`，无日志/异常 | `AESGCM.pas:111-114` |

---

## 电商后端集成评估（7.5/10）

### Firebase Adapter（7.5/10）

**优点**：
- Firestore REST API 映射完整：所有 `ICommerceStorage` 方法均已实现。
- 使用 `AllowServerOnlyPrototype` 保护标志 + 环境变量双保险，防止桌面端误用。
- Firestore 结构化查询（`runQuery`）正确使用 `fieldFilter`。

**问题**：
- **无事务支持**：Firestore REST API 需要 `beginTransaction` + `commit` 实现事务，当前实现每个操作是独立的 HTTP 请求。
- **AccessToken 无刷新**：`FConfig.AccessToken` 是静态字符串，过期后所有请求失败。
- `ExtractFields` 假设所有 Firestore 字段都是 `stringValue`/`integerValue` 等包装格式，但未处理 `nullValue`。

### Supabase Adapter（8.0/10）

**优点**：
- PostgREST API 使用正确：`Prefer: return=representation` 确保写操作返回结果。
- 支持 `ServiceRoleKey` 优先（绕过 RLS）和 `ApiKey` 降级。
- 表前缀可配置（`commerce_`），避免命名冲突。

**问题**：
- **无事务支持**：Supabase REST API 不支持多语句事务，需要改用 Postgres 函数（RPC）实现原子操作。
- `SupabaseGet` 解析 JSON Array 后 `SingleOrNull` 取第一个元素，但未验证返回行数是否为 1（可能静默丢弃重复数据）。
- 缺少 `Prefer: resolution=merge-duplicates` 等 PostgREST 特性用于 upsert。

---

## 社交登录评估（ThirdParty/Social）（7.0/10）

### 架构

- `TSocialClient` 基类 + `ISocialClient` 接口统一抽象。
- `TOAuthClient` 扩展通用 OAuth 2.0 流程（GitHub / Google / Facebook / Twitter / Microsoft）。
- 中国特色平台（微信 / QQ / 微博）独立实现。

### 优点

- Token 结构完整：`TSocialToken` 包含 Access/Refresh Token、过期时间、OpenId/UnionId。
- 微信登录支持小程序（`code2session`）和开放平台（OAuth2）两种模式。
- QQ 登录正确处理 `openid` + `appid` + `unionid` 分离。
- OAuth 客户端支持 `GetAuthUrl` → `ExchangeCode` → `RefreshToken` → `GetUserInfo` 完整流程。

### 问题

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | **Token 刷新无并发保护**：多线程同时发现 Token 过期时，可能并发发出多个 RefreshToken 请求，导致旧 Token 被多次使用后全部失效 | `Social.OAuth.pas` TOAuthClient.RefreshToken |
| **P2** | 微博 `ExchangeCode` 使用 `grant_type=authorization_code`，但微博 API 实际要求的参数名是 `grant_type`（确认一致），但返回值中的 `expires_in` 单位需验证 | `Social.Weibo.pas` |
| **P2** | `TSocialToken.IsExpired` 使用 `ExpiresAt` 比较 `Now`，但 `ExpiresAt` 在 `ExchangeCode` 中通过 `IncSecond(Now, ExpiresIn)` 计算 — 如果系统时钟漂移，会导致提前失效 | `Social.pas` TSocialToken |
| **P3** | 微信 `GetUserInfo` 返回的 `headimgurl` 未降级到无头像场景（微信用户可能拒绝授权头像） | `Social.WeChat.pas` |
| **P3** | Google OAuth 已不支持 `https://www.googleapis.com/plus/v1/people/me`（Google+ API 已关闭），应改用 `https://www.googleapis.com/oauth2/v3/userinfo` | `Social.OAuth.pas` TGoogleClient |

---

## 云存储评估（ThirdParty/Cloud）（7.0/10）

### 架构

- `ICloudStorageClient` 接口覆盖：Bucket CRUD / Object CRUD / Presigned URL / ACL / Multipart Upload。
- 支持 5 种后端：AWS S3 / Azure Blob / Ali OSS / Google Cloud / MinIO。
- `TCloudCredentials` 提供各平台的工厂方法。

### 优点

- 统一接口设计合理，`PutObject`/`GetObject`/`DeleteObject`/`ListObjects` 覆盖核心操作。
- 进度回调（`TUploadProgress`/`TDownloadProgress`）设计适合大文件场景。
- Multipart Upload 完整接口：Initiate → UploadPart → Complete / Abort。
- Presigned URL 支持限时访问。

### 问题

| 级别 | 问题 | 位置 |
|------|------|------|
| **P1** | 接口定义完整但 `ICloudStorageClient` **未找到任何实现类** — 仅有接口声明，无 S3/Azure/OSS 的实际实现 | `Cloud.Storage.pas` 全文 |
| **P2** | `TCloudCredentials.ForGoogle` 接受 `AServiceAccountJson` 字符串，但未说明格式（JSON key file? P12?），且 Google Cloud Storage 需要 JWT 签名生成 OAuth2 token | `Cloud.Storage.pas` |
| **P2** | Azure Blob 使用 Account Key 认证，但实际生产中推荐使用 SAS Token 或 Managed Identity | `Cloud.Storage.pas` ForAzure |
| **P3** | `TStorageClass` 枚举混合了不同平台的术语（`scColdline` 是 Google 的、`scGlacier` 是 AWS 的），但映射关系未定义 | `Cloud.Storage.pas:16` |

---

## 已知问题/风险汇总（按行号引用）

### 安全相关

| # | 严重度 | 文件 | 行号 | 描述 |
|---|--------|------|------|------|
| S1 | **Critical** | `WeChatPay.pas` | 505-515 | RSA 签名仅限 Windows，Linux 服务器部署将直接失败 |
| S2 | **Critical** | `Alipay.pas` | 311-314 | RSA2 签名仅限 Windows，Linux 服务器部署将直接失败 |
| S3 | **High** | `PayPal.pas` | 749 | 生产环境 VerifyNotification 静默返回 False，不抛异常 |
| S4 | **High** | `WeChatPay.pas` | 644-646 | CustomHeaders 在锁外设置，并发请求可能覆盖 Authorization |
| S5 | **High** | `Stripe.pas` | 213-218 | CustomHeaders 在锁外设置，并发请求可能覆盖 Authorization |
| S6 | **High** | `PayPal.pas` | 440-443 | CustomHeaders 在锁外设置，并发请求可能覆盖 Authorization |
| S7 | **Medium** | `WeChatPay.pas` | 800-801 | CreateJSAPIOrder 重复调用 DoWeChatPost，导致重复下单 |
| S8 | **Medium** | `Stripe.pas` | 300 | `expires_at` 使用本地时间而非 UTC，跨时区部署会偏差 |
| S9 | **Medium** | Social.OAuth | - | Token 刷新无并发保护，多线程可能导致 Token 全部失效 |

### 功能缺失

| # | 严重度 | 文件 | 行号 | 描述 |
|---|--------|------|------|------|
| F1 | **Critical** | `Cloud.Storage.pas` | 全文 | ICloudStorageClient 无实现类 |
| F2 | **High** | `Storage.pas` | 14-40 | ICommerceStorage 无事务支持 |
| F3 | **High** | `Alipay.pas` | 65-67 | 证书模式属性已声明但未使用 |
| F4 | **Medium** | `Idempotency.pas` | 全文 | 纯内存实现，无法跨进程/实例防重放 |
| F5 | **Medium** | `Stripe.pas` | 403-406 | QueryOrder 无法通过商户订单号查询 Stripe |

---

## 优先级排序的改进建议（Top 5）

### P0 — 上线前必须修复

1. **解决 RSA 签名/验签的平台锁定问题**
   - 当前：WeChat Pay 和 Alipay 的签名/验签仅在 `{$IFDEF MSWINDOWS}` 下可用。
   - 建议：为 Linux/macOS 实现基于 OpenSSL 的 RSA 签名和验签（类似 AESGCM 的跨平台模式）。可使用 `DeepBase.Crypto.OpenSSL` 中已有的 OpenSSL 动态加载基础设施，添加 `OpenSSL_RSA_Sign` 和 `OpenSSL_RSA_Verify` 导出函数。
   - 影响：不修复则无法在 Linux 服务器上部署微信支付和支付宝。

2. **修复 HTTP 并发安全性（CustomHeaders 竞态）**
   - 当前：`DoWeChatPost`/`DoStripePost`/`DoPayPalPost` 在 `TMonitor` 锁外设置 `FHttpClient.CustomHeaders`。
   - 建议：将 CustomHeaders 设置移入 `DoPost`/`DoGet` 的锁内，或改用 per-request `TNetHeaders` 参数（基类 `TPaymentClientBase.DoPost` 已支持此模式）。
   - 影响：不修复则并发支付请求会随机失败或签名错误。

### P1 — 高优先级

3. **补全 PayPal 生产环境 webhook 签名校验路径**
   - 当前：`VerifyNotification` 无签名头时静默返回 False。
   - 建议：像 Stripe 一样抛出 `EPaymentSignError`，明确告知调用方必须使用带签名头的重载方法。
   - 修复位置：`PayPal.pas` 第 749 行附近。

4. **修复 WeChatPay CreateJSAPIOrder 重复调用**
   - 当前：第 800-801 行 `DoWeChatPost` 被调用两次，产生两笔预支付订单。
   - 建议：删除第二行重复调用。

5. **为 ICommerceStorage 添加事务接口**
   - 当前：`CreateOrder` + `CreatePayment` + `UpdateOrder` 非原子，中间失败会导致脏数据。
   - 建议：在 `ICommerceStorage` 添加 `BeginTransaction`/`Commit`/`Rollback` 方法，或在 Supabase 中使用 RPC 函数，在 Firebase 中使用 `beginTransaction` + `commit`。

---

## 附录：PCI-DSS 合规快速检查

| 要求 | 状态 | 说明 |
|------|------|------|
| 密钥不明文存储 | **PASS** | 所有支付配置使用 `ISecretStore` (Credential Manager) 存储密钥 |
| 敏感数据不落盘 | **PASS** | 密钥通过 `ProtectKey`/`UnprotectKey` 加解密，不落明文 |
| 网络传输加密 | **PASS** | 所有 API 端点均使用 HTTPS |
| 签名验证 | **PARTIAL** | Stripe/PayPal webhook 签名验证已实现；WeChat/Alipay 仅 Windows |
| 常量时间比较 | **PASS** | Stripe webhook 签名使用常量时间比较（BUG-109 fix） |
| 桌面端密钥隔离 | **PASS** | `PaymentBridge.pas` 使用 `{$IFDEF DESKTOP}` 阻断密钥加载 |
| 日志脱敏 | **UNCERTAIN** | 未发现显式的日志脱敏逻辑，`RawResponse` 字段可能包含完整卡号 |

---

*评估完成。以上评估基于代码静态分析，未包含运行时渗透测试。建议上线前进行第三方安全审计。*
