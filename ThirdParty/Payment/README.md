# UniBase Payment Integration

统一支付接口封装，支持主流支付服务商。

## 架构定位（2026-05）

- 本目录提供 **直连支付渠道 SDK** 的客户端能力（Alipay/WeChat/Stripe/PayPal）。
- 订单、用户和权益流程统一走 `Features/UniBase.Commerce.*`。
- 多端统一、密钥集中托管、审计与风控统一的项目，应实现 `ICommercePaymentGateway` 调用后端 API。
- Core 层不承载支付渠道实现；支付细节只在 `ThirdParty/` 或业务后端适配器中。

## 支持的支付方式

| 服务商 | 类型 | 状态 |
|--------|------|------|
| Alipay (支付宝) | 国内支付 | ✅ |
| WeChat Pay (微信支付) | 国内支付 | ✅ |
| Stripe | 国际支付 | ✅ |
| PayPal | 国际支付 | ✅ |

## 核心文件

- `UniBase.Payment.pas` - 统一支付接口和基类
- `UniBase.Payment.Alipay.pas` - 支付宝实现
- `UniBase.Payment.WeChatPay.pas` - 微信支付实现
- `UniBase.Payment.Stripe.pas` - Stripe 实现
- `UniBase.Payment.PayPal.pas` - PayPal 实现

## 快速开始

### 支付宝示例

```pascal
uses
  UniBase.Payment, UniBase.Payment.Alipay;

var
  Config: TAlipayConfig;
  Client: IPaymentClient;
  Order: TPaymentOrder;
  Result: TPaymentResult;
begin
  Config := TAlipayConfig.Create;
  Config.AppId := 'your_app_id';
  Config.PrivateKey := 'your_private_key';
  Config.AlipayPublicKey := 'alipay_public_key';
  Config.IsSandbox := True;  // 沙箱测试

  Client := TAlipayClient.Create(Config);
  
  Order.OrderNo := GenerateOrderNo;
  Order.Amount := 9.99;
  Order.Currency := 'CNY';
  Order.Subject := '测试商品';
  Order.NotifyUrl := 'https://your-server.com/notify/alipay';
  
  Result := Client.CreateOrder(Order);
  if Result.Success then
    // 跳转到 Result.PayUrl 或显示 Result.QRCode
end;
```

### Stripe 示例

```pascal
uses
  UniBase.Payment, UniBase.Payment.Stripe;

var
  Config: TStripeConfig;
  Client: IPaymentClient;
  Order: TPaymentOrder;
begin
  Config := TStripeConfig.Create;
  Config.SecretKey := 'sk_test_xxx';
  Config.PublishableKey := 'pk_test_xxx';

  Client := TStripeClient.Create(Config);
  
  Order.OrderNo := GenerateOrderNo;
  Order.Amount := 19.99;
  Order.Currency := 'USD';
  Order.Subject := 'Premium Subscription';
  Order.SuccessUrl := 'https://your-site.com/success';
  Order.CancelUrl := 'https://your-site.com/cancel';
  
  Result := Client.CreateOrder(Order);
  // 跳转到 Result.PayUrl (Stripe Checkout)
end;
```

## 回调处理

```pascal
procedure HandlePaymentNotify(const AProvider: string; const ARawData: string);
var
  Client: IPaymentClient;
  Notification: TPaymentNotification;
begin
  Client := GetPaymentClient(AProvider);
  
  if Client.VerifyNotification(ARawData, Notification) then
  begin
    if Notification.Status = psSuccess then
    begin
      // 更新订单状态
      UpdateOrderStatus(Notification.OrderNo, osCompleted);
    end;
  end;
end;
```

## 配置说明

### 支付宝配置

| 参数 | 说明 |
|------|------|
| AppId | 应用ID |
| PrivateKey | 应用私钥 (RSA2) |
| AlipayPublicKey | 支付宝公钥 |
| IsSandbox | 是否沙箱环境 |

### 微信支付配置

| 参数 | 说明 |
|------|------|
| AppId | 公众号/小程序 AppID |
| MchId | 商户号 |
| ApiKey | API 密钥 |
| CertPath | 证书路径 (退款用) |

### Stripe 配置

| 参数 | 说明 |
|------|------|
| SecretKey | 密钥 (sk_xxx) |
| PublishableKey | 公钥 (pk_xxx) |
| WebhookSecret | Webhook 签名密钥 |

### PayPal 配置

| 参数 | 说明 |
|------|------|
| ClientId | 客户端ID |
| ClientSecret | 客户端密钥 |
| IsSandbox | 是否沙箱环境 |

## 注意事项

1. **密钥安全**: 使用 `UniBase.Security.DPAPI` 安全存储密钥
2. **HTTPS**: 生产环境必须使用 HTTPS 回调地址
3. **幂等性**: 处理支付回调时注意幂等性，避免重复处理
4. **日志**: 建议记录所有支付请求和回调日志

## 相关文档

- [支付宝开放平台](https://open.alipay.com/)
- [微信支付开发文档](https://pay.weixin.qq.com/wiki/doc/api/)
- [Stripe API Reference](https://stripe.com/docs/api)
- [PayPal Developer](https://developer.paypal.com/)
