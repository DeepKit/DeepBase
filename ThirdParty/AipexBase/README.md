# UniBase - AipexBase 对接（支付 /generalOrder）

本目录用于 **UniBase 客户端** 调用 **AipexBase 后端** 的统一支付接口。

> 目标：支付渠道（Stripe/微信/Mock…）全部由 AipexBase 后端处理；
> UniBase 侧只做 HTTP 调用，不再实现各渠道 SDK/签名。

## 已包含

- `UniBase.AipexBase.GeneralOrder.pas`
  - `TAipexGeneralOrderClient`
  - 主要覆盖：
    - `GET /generalOrder/payMethod`
    - `POST /generalOrder/{operateName}`（create/getUniqueOrderNo/getPaymentParam/getPayOrderMessage/cancelPay/refund…）

## 必要请求头

AipexBase 后端会通过 Filter 校验 APP 标识与登录态：

- `APP_ID`: 应用 ID（必填；或用 `CODE_FLYING` 推导）
- `APP_TYPE`: `user`/`admin`（可选，默认 `user`）
- `CODE_FLYING`: API Key（可选）
- `Authorization: Bearer <token>`：当后端需要登录时必须

## 最小调用示例

```pascal
uses
  System.JSON,
  UniBase.AipexBase.GeneralOrder;

procedure Demo;
var
  Auth: TAipexBaseAuth;
  Client: TAipexGeneralOrderClient;
  OpId: string;
  Body: TJSONObject;
  Data: TJSONValue;
begin
  // 1) 认证信息（任选：APP_ID 或 CODE_FLYING）
  Auth := TAipexBaseAuth.ForAppId('your_app_id', 'your_jwt_token');

  // 2) BaseUrl 指向 AipexBase 后端
  Client := TAipexGeneralOrderClient.Create('https://api.your-domain.com', Auth);
  try
    // 可用支付方式
    var Methods := Client.PayMethods;

    // 获取防重 opId
    OpId := Client.GetUniqueOrderNo(123, 456);

    // 创建订单（字段按 AipexBase OrderCreatRequest 传）
    Body := TJSONObject.Create;
    try
      Body.AddPair('productId', TJSONNumber.Create(123));
      Body.AddPair('userId', TJSONNumber.Create(456));
      Body.AddPair('payChanel', 'stripe');
      Body.AddPair('opId', OpId);
      Body.AddPair('quality', TJSONNumber.Create(1));
      Body.AddPair('productSubject', 'Demo Product');
      Body.AddPair('currentUrl', 'https://your-redirect-url');

      Data := Client.CreateOrder(Body);
      try
        // Data 为 BaseResponse.data（类型可能是对象/数组/字符串）
      finally
        Data.Free;
      end;
    finally
      Body.Free;
    end;

  finally
    Client.Free;
  end;
end;
```

## 备注

- AipexBase 接口返回为 `BaseResponse`：`code=0` 代表成功。
- `TAipexGeneralOrderClient` 已在解析阶段将 `BaseResponse.data` **Clone** 出来返回；因此调用方需要 `Free` 返回的 `TJSONValue`。
