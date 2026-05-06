# UniBase 下游集成指南

> 更新日期: 2026-05-05  
> 目标: 给下游 Delphi 工程、网页测评包、小程序后端提供一份干净、当前有效的接入指南。

---

## 1. 先选包

| 需求 | 包/目录 |
|------|--------|
| 配置、日志、i18n、窗体状态、MRU、热键 | [UniBaseCore.dpk](../UniBaseCore.dpk) |
| IoC、EventBus、Scheduler、Crypto 等服务能力 | [UniBaseServices.dpk](../UniBaseServices.dpk) |
| FireDAC/DB/DoQry 持久化适配 | [UniBasePersistence.dpk](../UniBasePersistence.dpk) |
| LLM、Commerce、更新、防篡改、解锁、云同步等可选功能 | [UniBaseFeatures.dpk](../UniBaseFeatures.dpk) |
| VCL 控件/平台适配器 | [UniBaseVCL.dpk](../UniBaseVCL.dpk) / [dclUniBaseVCL.dpk](../dclUniBaseVCL.dpk) |
| FMX 控件/平台适配器 | [UniBaseFMX.dpk](../UniBaseFMX.dpk) / [dclUniBaseFMX.dpk](../dclUniBaseFMX.dpk) |

最小建议：先接 `Core + Persistence`，需要用户/付款/权益时再接 `Features`。

---

## 2. 数据库放哪里

### 2.1 本地 UniBase 配置库

每个下游应用都有自己的 `root.txt + {AppName}Config.db`：

```
{RootPath}/
├── {AppName}Config.db     # DB1: UniBase 配置、日志、i18n、AboutFrame 等
├── data/
│   └── {AppName}Data.db   # DB2: 可选，本地业务库
└── logs/
```

`{AppName}Config.db` 只放 UniBase 框架表和应用配置，不放生产用户表、订单表、支付流水表。

### 2.2 业务数据库

普通桌面工具可以把业务数据放在 DB2，例如本地 SQLite 或远程 PostgreSQL。

### 2.3 用户/订单/支付/权益数据库

涉及登录、微信支付、小程序、网页测评包、订阅、权益发放时，生产数据应放在后端数据库：

| 数据 | 推荐位置 |
|------|----------|
| 用户、身份绑定 | 后端数据库 |
| 商品、订单 | 后端数据库 |
| 支付记录、回调原文 | 后端数据库 |
| 权益、次数、有效期 | 后端数据库 |
| 支付渠道密钥 | 后端密钥管理，不放客户端 |

UniBase 侧只通过 `ICommerceStorage` 读写这些数据。开发期可用 `TInMemoryCommerceStorage` 跑通流程；生产优先用 `TCommerceHttpStorage` 对接统一后端，不能用内存存储。

生产后端的数据表、HTTP API、支付通知验签和幂等规则见 [Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md)。

---

## 3. 统一用户/付款/权益流程

必须先记录内部用户和订单，再发起支付。

1. 下游端拿到外部身份：微信 `openid/unionid`、邮箱、手机号、设备 ID 或后端用户 ID。
2. 调 `EnsureUserForIdentity` 创建或复用内部 `UserId`。
3. 调 `CreateOrder` 创建订单，生成 `OrderId` 和 `OutTradeNo`。
4. 调 `BeginPayment` 创建支付意图，拿到小程序/网页/二维码支付参数。
5. 用户完成支付。
6. 后端接收支付通知，验签、查单、校验金额/币种/订单号。
7. 调 `ConfirmPayment` 标记支付结果并发放权益。
8. 下游功能入口调用 `HasEntitlement` 或 `ConsumeEntitlement`。

客户端 UI 不直接把订单改为已支付，也不直接发放权益。

---

## 4. Commerce 最小代码

开发期可用内存存储和假支付网关跑通端到端：

```delphi
uses
  UniBase.Commerce.Types,
  UniBase.Commerce.Storage,
  UniBase.Commerce.Backend.Http,
  UniBase.Commerce.Service;

var
  Storage: ICommerceStorage;
  Commerce: TUniBaseCommerceService;
  Product: TCommerceProductData;
  User: TCommerceUserData;
  Order: TCommerceOrderData;
  Intent: TCommercePaymentIntent;
begin
  Storage := TInMemoryCommerceStorage.Create;
  Commerce := TUniBaseCommerceService.Create(Storage);
  try
    Product := TCommerceProductData.Create(
      'my_app', 'pro_year', 'Pro Year', 9900, 'CNY', 'my_app.pro', -1, 365);
    Commerce.RegisterProduct(Product);

    User := Commerce.EnsureUserForIdentity(
      capWeChatMiniProgram, 'openid_xxx', 'my_app', 'unionid_xxx');

    Order := Commerce.CreateOrder(User.UserId, 'my_app', 'pro_year');

    // 生产环境必须先 RegisterPaymentGateway，再 BeginPayment。
    Intent := Commerce.BeginPayment(
      Order.OrderId, cppWeChatPay, cpcMiniProgram, 'openid_xxx');
  finally
    Commerce.Free;
  end;
end;
```

真实项目要替换两处：

- `TInMemoryCommerceStorage` → `TCommerceHttpStorage` 或其他生产 `ICommerceStorage`。
- 假支付网关 → `TCommerceHttpPaymentGateway` 或其他生产 `ICommercePaymentGateway`。

如果是统一后端路线，优先让这两个适配器调用同一个业务后端 API，而不是让客户端直连生产数据库或支付渠道密钥。

生产 HTTP 存储最小写法：

```delphi
Storage := TCommerceHttpStorage.Create(
  TCommerceBackendHttpConfig.Create(
    'https://api.example.com',
    '<bearer-token-or-empty>',
    '<api-key-or-empty>'));
```

生产支付网关最小写法：

```delphi
Commerce.RegisterPaymentGateway(
  cppWeChatPay,
  TCommerceHttpPaymentGateway.Create(
    TCommerceBackendHttpConfig.Create(
      'https://api.example.com',
      '<bearer-token-or-empty>',
      '<api-key-or-empty>')));
```

---

## 5. 后端适配器职责

### 5.1 `ICommerceStorage`

负责持久化：

- users
- identities
- products
- orders
- payments
- entitlements

要求：

- `FindUserByIdentity` 必须幂等。
- `CreateOrder` 必须保证 `OutTradeNo` 唯一。
- `ConfirmPayment` 相关更新必须具备事务语义。
- 权益发放必须按订单幂等，重复通知不能重复发放。
- UniBase 已内置 `TCommerceHttpStorage`，后端按 [Commerce-Backend-Adapter-Spec.md](Commerce-Backend-Adapter-Spec.md) 暴露 HTTP API 即可接入。

### 5.2 `ICommercePaymentGateway`

负责创建支付意图：

- 微信小程序：返回 `prepay_id` 和前端调起支付参数。
- 网页测评包：返回 H5/Native 支付链接或二维码数据。
- 桌面工具：返回二维码数据或跳转 URL。

要求：

- 支付密钥优先放后端。
- 生成支付参数前必须已有订单。
- 回调通知必须验签，并记录原始通知。
- UniBase 已内置 `TCommerceHttpPaymentGateway`，用于把 `BeginPayment` 转发到统一后端的 `/commerce/payments/intents`。

---

## 6. 下游集成顺序

1. 接入 `root.txt + {AppName}Config.db`。
2. 接入日志、配置、i18n、窗体状态。
3. 如有业务数据库，接入 `Persistence/UniBase.DB.DoQry.pas`。
4. 如有付费功能，接入 `Features/UniBase.Commerce.*`。
5. 先用内存存储和假网关跑通单元测试。
6. 接入 `TCommerceHttpStorage` 并配置统一后端 `BaseUrl`、token 或 API key。
7. 接入 `TCommerceHttpPaymentGateway`，由后端生成微信支付/支付宝/网页/桌面支付参数。

---

## 7. 封板前检查

- [ ] 下游工程没有引用已删除的旧认证/计费 UI。
- [ ] 文档入口只指向本指南、[ARCH-QUICKSTART.md](../ARCH-QUICKSTART.md) 和当前 API/技术规范。
- [ ] 支付前一定已经创建订单和 `OutTradeNo`。
- [ ] 支付成功以可信通知为准，不信任前端返回。
- [ ] 生产环境不使用 `TInMemoryCommerceStorage`。
- [ ] 后端数据库有订单号唯一约束和通知幂等处理。
- [ ] 权益查询统一走 `HasEntitlement` / `ConsumeEntitlement`。
