# Commerce Backend Adapter Spec

> 更新日期: 2026-05-05  
> 状�? COMMERCE-002A/B/C/D 已完成；支付通知验签适配继续进行  
> 目标: 给统一后端、Delphi 适配器、网页测评包和小程序支付接入提供同一份生产契约�?
---

## 1. 边界

DeepBase 负责统一商业流程抽象�?
- `Features/DeepBase.Commerce.Types.pas`
- `Features/DeepBase.Commerce.Storage.pas`
- `Features/DeepBase.Commerce.Service.pas`

生产后端负责可信状态：

- 用户和身份绑�?- 商品、订单、支付流�?- 支付通知验签和原文留�?- 权益、次数、有效期
- 支付渠道密钥

本地 `{AppName}Config.db` 只保存框架配置、日志、AboutFrame、i18n 等本地状态，不保存生产订单和支付流水�?
---

## 2. 推荐部署

优先路线�?
```
桌面工具 / 网页测评�?/ 小程�?        |
        v
业务后端 HTTP API
        |
        +-- 后端数据�? users/orders/payments/entitlements
        +-- 微信支付/支付宝等渠道 SDK
        +-- Webhook/notify 验签
```

Delphi 客户端和网页/小程序都只调用业务后�?API，不直接连接生产数据库，也不保存支付密钥�?
---

## 3. 数据模型

### users

| 字段 | 类型 | 约束 |
|------|------|------|
| user_id | string | PK |
| display_name | string | optional |
| email | string | optional |
| phone | string | optional |
| is_active | bool | required |
| created_at | datetime | required |
| updated_at | datetime | required |

### identities

| 字段 | 类型 | 约束 |
|------|------|------|
| identity_id | string | PK |
| user_id | string | FK users.user_id |
| provider | string | required |
| provider_user_id | string | required |
| app_id | string | required |
| union_id | string | optional |
| created_at | datetime | required |

唯一约束�?
- `(provider, provider_user_id, app_id)`
- 建议额外索引 `(union_id)`，用于微信多端合并用户�?
### products

| 字段 | 类型 | 约束 |
|------|------|------|
| app_id | string | PK part |
| product_id | string | PK part |
| name | string | required |
| description | string | optional |
| amount_minor | int64 | required，分/厘等最小货币单�?|
| currency | string | required，例�?CNY |
| entitlement_code | string | required |
| entitlement_duration_days | int | 0 表示永久 |
| initial_quota | int | -1 表示无限 |
| is_active | bool | required |

### orders

| 字段 | 类型 | 约束 |
|------|------|------|
| order_id | string | PK |
| user_id | string | FK users.user_id |
| app_id | string | required |
| product_id | string | required |
| out_trade_no | string | unique |
| title | string | required |
| amount_minor | int64 | required |
| currency | string | required |
| status | string | created/paying/paid/closed/failed/refunded |
| created_at | datetime | required |
| paid_at | datetime | optional |

关键约束�?
- `out_trade_no` 必须全局唯一�?- 创建支付前必须已经创建订单�?- 客户端不能直接把 `status` 改成 `paid`�?
### payments

| 字段 | 类型 | 约束 |
|------|------|------|
| payment_id | string | PK |
| order_id | string | unique FK orders.order_id |
| provider | string | wechat_pay/alipay/stripe/paypal/manual/external |
| channel | string | native/jsapi/mini_program/h5/app/web/manual |
| provider_trade_no | string | optional |
| prepay_id | string | optional |
| status | string | created/pending/paid/failed/refunded |
| raw_payload | text/json | 支付请求或通知原文 |
| created_at | datetime | required |
| paid_at | datetime | optional |

建议唯一约束�?
- `(provider, provider_trade_no)`，允�?`provider_trade_no` 为空时按数据库能力处理�?
### payment_notifications

| 字段 | 类型 | 约束 |
|------|------|------|
| notification_id | string | PK |
| provider | string | required |
| notification_key | string | unique |
| out_trade_no | string | required |
| provider_trade_no | string | optional |
| amount_minor | int64 | required |
| currency | string | required |
| verified | bool | required |
| processed | bool | required |
| raw_payload | text/json | required |
| received_at | datetime | required |
| processed_at | datetime | optional |

`notification_key` 推荐�?
- 微信支付优先使用平台通知 `id`�?- 无稳定通知 ID 时使�?`sha256(provider + raw_payload)`�?
### entitlements

| 字段 | 类型 | 约束 |
|------|------|------|
| entitlement_id | string | PK |
| user_id | string | FK users.user_id |
| app_id | string | required |
| product_id | string | required |
| code | string | required |
| status | string | active/consumed/expired/revoked |
| valid_from | datetime | required |
| valid_until | datetime | optional |
| remaining_quota | int | -1 表示无限 |
| source_order_id | string | unique FK orders.order_id |

关键约束�?
- `source_order_id` 必须唯一，保证重复支付通知不会重复发放权益�?
---

## 4. HTTP API 契约

Delphi 侧的路由�?JSON 字段名常量定义在 `Features/DeepBase.Commerce.Backend.Contract.pas`，后�?HTTP 适配器和 contract tests 必须复用该单元，避免文档、测试和实现各写一套字符串�?
所有接口必须走 HTTPS。生产环境建议要求：

- `Authorization: Bearer <app/user token>`，或服务端到服务�?API key�?- `Idempotency-Key` 用于创建订单、创建支付意图、处理通知等可重试请求�?- 响应统一返回 JSON�?
### 4.1 创建或复用用�?
`POST /commerce/users/ensure`

请求�?
```json
{
  "provider": "wechat_mini_program",
  "provider_user_id": "openid_xxx",
  "union_id": "unionid_xxx",
  "app_id": "my_app"
}
```

响应�?
```json
{
  "user_id": "usr_xxx",
  "is_active": true
}
```

要求�?
- 幂等：同一 `(provider, provider_user_id, app_id)` 必须返回同一�?`user_id`�?- 微信体系建议优先记录 `union_id`，后续可做多端账号合并�?
### 4.2 创建订单

`POST /commerce/orders`

请求�?
```json
{
  "user_id": "usr_xxx",
  "app_id": "my_app",
  "product_id": "pro_year"
}
```

响应�?
```json
{
  "order_id": "ord_xxx",
  "out_trade_no": "UB202605050001",
  "amount_minor": 9900,
  "currency": "CNY",
  "status": "created"
}
```

要求�?
- 后端�?`products` 读取价格，不信任前端传入金额�?- `out_trade_no` 全局唯一�?
### 4.3 创建支付意图

`POST /commerce/payments/intents`

请求�?
```json
{
  "order_id": "ord_xxx",
  "provider": "wechat_pay",
  "channel": "mini_program",
  "payer_open_id": "openid_xxx"
}
```

响应�?
```json
{
  "payment_id": "pay_xxx",
  "out_trade_no": "UB202605050001",
  "prepay_id": "wx201410272009395522657a690389285100",
  "client_params_json": "{\"timeStamp\":\"...\",\"nonceStr\":\"...\",\"package\":\"prepay_id=...\",\"signType\":\"RSA\",\"paySign\":\"...\"}",
  "pay_url": "",
  "qr_code_data": ""
}
```

要求�?
- 后端持有微信商户号、证书、私钥、API v3 key�?- 客户端只拿支付参数，不参与签名密钥管理�?- 同一未支付订单重复调用可复用同一 payment，也可以刷新支付参数，但不能创建多条互相冲突的支付流水�?
### 4.4 支付通知入口

`POST /commerce/payments/wechat_pay/notify`

处理步骤�?
1. 验证微信平台证书/签名、时间戳、nonce�?2. 解密通知资源�?3. 记录 `payment_notifications.raw_payload`�?4. �?`out_trade_no` 查订单�?5. 校验订单号、金额、币种、商户号、支付状态�?6. 在事务内更新 payment/order，并�?`source_order_id` 幂等发放 entitlement�?7. 返回微信支付要求的成功响应�?
后端内部可调�?Commerce 等价流程�?
```text
ConfirmPayment(notification)
```

但传�?`ConfirmPayment` 前，通知必须已经验签和校验�?
### 4.5 查询权益

`GET /commerce/entitlements?user_id=usr_xxx&app_id=my_app`

响应�?
```json
{
  "items": [
    {
      "code": "my_app.pro",
      "status": "active",
      "valid_until": "2027-05-05T12:00:00Z",
      "remaining_quota": -1
    }
  ]
}
```

### 4.6 消费权益

`POST /commerce/entitlements/consume`

请求�?
```json
{
  "user_id": "usr_xxx",
  "app_id": "my_app",
  "code": "assessment.report",
  "count": 1
}
```

要求�?
- `remaining_quota=-1` 表示无限，不扣减�?- 有限次数必须原子扣减，不能并发扣成负数�?
---

## 5. Delphi 适配器映�?
DeepBase 已提供生产向 HTTP 后端转发�?`ICommerceStorage` 适配器：

- 单元：`Features/DeepBase.Commerce.Backend.Http.pas`
- 类：`TCommerceHttpStorage`
- 配置：`TCommerceBackendHttpConfig.BaseUrl / RoutePrefix / BearerToken / ApiKey / TimeoutMs`
- 默认 Header：`Accept: application/json`、`Content-Type: application/json`、可�?`Authorization: Bearer <token>`、可�?`X-API-Key`
- 测试扩展点：`ICommerceBackendHttpTransport`

后端需要按下表提供接口。Delphi 侧路由和字段常量仍以 `Features/DeepBase.Commerce.Backend.Contract.pas` 为准�?
如服务端真实路由带统一前缀（如 `/dk`），可在客户端设置 `RoutePrefix='/dk'`，或直接使用 `CreateDeepKitClient` / `CreateDeepKitServerAdmin`。
| `ICommerceStorage` 方法 | 推荐后端动作 |
|-------------------------|--------------|
| `FindUserById` | `GET /commerce/users/{user_id}` |
| `FindUserByIdentity` | `GET /commerce/users/by-identity?provider=...&provider_user_id=...&app_id=...` |
| `UpsertUser` | `PUT /commerce/users/{user_id}` |
| `LinkIdentity` | `POST /commerce/users/identities` |
| `FindProduct` / `UpsertProduct` | `GET/PUT /commerce/products/{app_id}/{product_id}`；生产建议只允许管理端修�?|
| `CreateOrder` | `POST /commerce/orders` |
| `FindOrderById` | `GET /commerce/orders/{order_id}` |
| `FindOrderByOutTradeNo` | `GET /commerce/orders/by-out-trade-no/{out_trade_no}` |
| `UpdateOrder` | `PUT /commerce/orders/{order_id}` |
| `CreatePayment` | `POST /commerce/payments` |
| `FindPaymentByOrderId` | `GET /commerce/payments/by-order/{order_id}` |
| `UpdatePayment` | `PUT /commerce/payments/{payment_id}` |
| `UpsertEntitlement` | `PUT /commerce/entitlements/{entitlement_id}` |
| `ListEntitlements` | `GET /commerce/entitlements?user_id=...&app_id=...` |
| `FindEntitlement` | `GET /commerce/entitlements/by-code?user_id=...&app_id=...&code=...` |
| `ConsumeEntitlement` | `POST /commerce/entitlements/consume`，请求可使用 `entitlement_id + count`，也可由后端兼容 `user_id + app_id + code + count` |

`TCommerceHttpStorage` 另提供 server-admin 管理方法（不在 `ICommerceStorage` 接口内）：
- `RefundOrder(order_id, amount_minor, reason)` -> `POST /commerce/orders/{order_id}/refund`
- `RevokeEntitlement(entitlement_id, reason)` -> `POST /commerce/entitlements/{entitlement_id}/revoke`
- `RevokeLicenseSnapshot(app_id, device_id, snapshot_id, reason)` -> `POST /license/snapshot/revoke`（配合 `CreateDeepKitServerAdmin` 通常走 `/dk/license/snapshot/revoke`）

如下游需要统一网络栈、代理或后续 ICS 适配，可通过 `TCommerceBackendUnifiedTransport` 把 `IDeepBaseHttpTransport` 注入到 Commerce HTTP 适配器。

DeepBase 已提供生产向 HTTP 后端转发�?`ICommercePaymentGateway` 适配器：

- 单元：`Features/DeepBase.Commerce.Backend.Http.pas`
- 类：`TCommerceHttpPaymentGateway`
- 入口：`POST /commerce/payments/intents`
- 请求字段：`order_id`、`payment_id`、`out_trade_no`、`provider`、`channel`、`payer_open_id`、`amount_minor`、`currency`
- Header：复�?`Authorization` / `X-API-Key`，并�?`Idempotency-Key: <payment_id>` 防止客户端重试创建冲�?- 响应字段：`payment_id`、`out_trade_no`、`prepay_id`、`client_params_json`、`pay_url`、`qr_code_data`

后端仍必须以服务端订单和商品表为准，不能信任客户端传入的金额、币种或订单状态�?
由后端真正调用微信支付、支付宝等渠道�?

桌面端直连安全 API（`/dk`）可使用 `Features/DeepBase.Commerce.SafeClient.pas` 的 `TDeepKitSafeClient`。该 facade 只暴露客户端允许的操作（认证、下单、支付意图、权益查询/核销、license snapshot、更新 manifest），避免客户端误用 server-admin storage 写接口。

桌面端免费版升级到收费版应优先使用 `Features/DeepBase.Commerce.UpgradeFlow.pas` 的 `TDeepKitUpgradeFlowClient`，不要在业务项目里重新拼流程。该 facade 已串联：

- `ListProducts`
- `StartPaidUpgrade`：列商品、创建订单、创建支付意图
- `CheckEntitlement`
- `RefreshLicenseSnapshot`
- `GetUpdateManifest`

付费功能入口使用 `Features/DeepBase.Commerce.Permissions.pas` 的 `TDeepKitPermissionClient`，统一执行 `HasFeature`、`RequireFeature`、`ConsumeQuota` 和 `RefreshLicenseSnapshot`。

完整桌面上线流程优先使用 `Features/DeepBase.Desktop.Lifecycle.pas` 的 `TDeepBaseDesktopLifecycle`。该 facade 在 `TDeepKitSafeClient` 之上统一处理设备匿名登录、access token 注入 updater、权限检查、配额扣减、付费升级、权益轮询、license snapshot 刷新和更新 manifest 获取。VCL/FMX 工程可再接 `DeepBase.VCL.DesktopLifecycle` / `DeepBase.FMX.DesktopLifecycle` helper 做授权标签、功能灰显、升级按钮、系统浏览器支付页和 GUI 测试窗体位置固定。

`DeepBase.Commerce.Adapter.Supabase`、`DeepBase.Commerce.Adapter.Firebase`、`DeepBase.Commerce.PaymentBridge` 已按 server-only/prototype 管控：默认需要显式 server-only 开关或环境变量 `DEEPBASE_ALLOW_PROTOTYPE_COMMERCE_ADAPTERS=1`，不作为桌面生产直连入口。
---

## 6. 幂等规则

- 用户幂等键：`provider + provider_user_id + app_id`
- 订单幂等键：`Idempotency-Key` 或业务侧 `client_order_key`
- 支付意图幂等键：`order_id + provider`
- 支付通知幂等键：微信通知 `id` �?`sha256(raw_payload)`
- 权益幂等键：`source_order_id`

任何可重试接口都必须做到�?
- 重复请求返回同一业务结果�?- 不重复扣款�?- 不重复发放权益�?- 不覆盖已支付订单为失败状态�?
---

## 7. 安全要求

- 生产全链�?HTTPS�?- 商户私钥、API v3 key、Webhook secret 只放后端密钥管理�?- 支付通知必须 fail-closed：验签失败、金额不符、币种不符、订单不存在时拒绝确认�?- 客户端返回的“支付成功”只能用�?UI 提示，不能作为发放权益依据�?- 管理端修改商品价格、权益码、订单状态必须有审计日志�?- 后端日志不得输出完整密钥、身份证、手机号、邮箱明文；必要时脱敏�?
---

## 8. 实施顺序

1. 已完成：固化本契约并评审字段命名�?2. 已完成：用内�?mock 后端�?contract tests�?3. 已完成：实现 HTTP `ICommerceStorage` 适配器�?4. 已完成：实现后端微信支付 intent API �?Delphi `ICommercePaymentGateway` 后端代理适配器�?5. 下一步：实现微信支付 notify 验签和幂等确认�?6. 跑通一个下游端到端样例�?7. 再评�?CloudBase/Firebase/Supabase 等托管后端是否需要官方适配�?
---

## 9. 封板标准

- `TInMemoryCommerceStorage` 仅用于测试和开发文档，不用于生产�?- 下游项目只依�?`Features/DeepBase.Commerce.*` 的流程入口，不再引用旧认�?计费 UI �?AiPEX/AipexBase�?- 支付确认以可信后端通知为准�?- 后端数据库有唯一约束和事务保护�?- 文档入口只指向本契约、`DeepBase-Downstream-Integration.md` �?ThirdParty 扩展指南�?
