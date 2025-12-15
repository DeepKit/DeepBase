unit UniBase.Payment.WeChatPay;

{*******************************************************************************
  UniBase WeChat Pay (微信支付) Integration

  Supports:
    - Native支付 (扫码支付)
    - JSAPI支付 (公众号/小程序)
    - H5支付 (手机网页)
    - APP支付
    - 退款

  Official Docs: https://pay.weixin.qq.com/wiki/doc/apiv3/
  API Version: V3
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Payment;

type
  /// <summary>WeChat Pay trade type</summary>
  TWeChatTradeType = (wttNative, wttJSAPI, wttApp, wttH5, wttMiniProgram);

  /// <summary>WeChat Pay configuration</summary>
  TWeChatPayConfig = class(TPaymentConfig)
  private
    FAppId: string;           // 公众号/小程序 AppID
    FMchId: string;           // 商户号
    FApiKeyV3: string;        // APIv3 密钥
    FSerialNo: string;        // 商户证书序列号
    FPrivateKey: string;      // 商户私钥 (PEM)
    FCertPath: string;        // 证书路径 (退款用)
    FSubAppId: string;        // 子商户 AppID (服务商模式)
    FSubMchId: string;        // 子商户号 (服务商模式)
  public
    constructor Create; reintroduce;

    property AppId: string read FAppId write FAppId;
    property MchId: string read FMchId write FMchId;
    property ApiKeyV3: string read FApiKeyV3 write FApiKeyV3;
    property SerialNo: string read FSerialNo write FSerialNo;
    property PrivateKey: string read FPrivateKey write FPrivateKey;
    property CertPath: string read FCertPath write FCertPath;
    property SubAppId: string read FSubAppId write FSubAppId;
    property SubMchId: string read FSubMchId write FSubMchId;
  end;

  /// <summary>WeChat Pay client implementation (API V3)</summary>
  TWeChatPayClient = class(TPaymentClient)
  private
    function GetApiUrl: string;
    function BuildAuthorizationHeader(const AMethod, AUrl, ABody: string): string;
    function GenerateNonceStr: string;
    function DoWeChatPost(const AEndpoint: string; ABody: TJSONObject): TJSONObject;
    function DoWeChatGet(const AEndpoint: string): TJSONObject;
    function RSASign(const AContent: string): string;
    function ParseWeChatStatus(const AState: string): TPaymentStatus;
  protected
    function SignRequest(const AParams: TDictionary<string, string>): string; override;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; override;
  public
    constructor Create(AConfig: TWeChatPayConfig); reintroduce;

    // IPaymentClient
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; override;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; override;
    function CloseOrder(const AOrderNo: string): Boolean; override;
    function Refund(const ARequest: TRefundRequest): TRefundResult; override;
    function QueryRefund(const ARefundNo: string): TRefundResult; override;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; override;
    function GetNotificationResponse(ASuccess: Boolean): string; override;

    // WeChat specific
    function CreateNativeOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateJSAPIOrder(const AOrder: TPaymentOrder; const AOpenId: string): TPaymentResult;
    function CreateH5Order(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateAppOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function BuildJSAPIPayParams(const APrepayId: string): string;
    function BuildAppPayParams(const APrepayId: string): string;
  end;

implementation

uses
  System.Hash, System.StrUtils;

const
  WECHAT_API_URL = 'https://api.mch.weixin.qq.com';

{ TWeChatPayConfig }

constructor TWeChatPayConfig.Create;
begin
  inherited Create(ppWeChatPay);
end;

{ TWeChatPayClient }

constructor TWeChatPayClient.Create(AConfig: TWeChatPayConfig);
begin
  inherited Create(AConfig);
end;

function TWeChatPayClient.GetApiUrl: string;
begin
  Result := WECHAT_API_URL;
end;

function TWeChatPayClient.GenerateNonceStr: string;
begin
  Result := TPaymentHelper.GenerateNonceStr(32);
end;

function TWeChatPayClient.RSASign(const AContent: string): string;
begin
  // TODO: Implement actual RSA-SHA256 signing with PKCS#1 v1.5 padding
  // For production, use OpenSSL or Windows CryptoAPI
  Result := TPaymentHelper.Base64Encode(
    TEncoding.UTF8.GetBytes(TPaymentHelper.SHA256(AContent))
  );
end;

function TWeChatPayClient.BuildAuthorizationHeader(const AMethod, AUrl, ABody: string): string;
var
  Cfg: TWeChatPayConfig;
  Timestamp: Int64;
  NonceStr: string;
  SignContent: string;
  Signature: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Build sign content: HTTP请求方法\nURL\n时间戳\n随机字符串\n请求报文主体\n
  SignContent := AMethod + #10 +
                 AUrl + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 ABody + #10;

  Signature := RSASign(SignContent);

  // WECHATPAY2-SHA256-RSA2048 authorization
  Result := Format('WECHATPAY2-SHA256-RSA2048 mchid="%s",nonce_str="%s",signature="%s",timestamp="%d",serial_no="%s"',
    [Cfg.MchId, NonceStr, Signature, Timestamp, Cfg.SerialNo]);
end;

function TWeChatPayClient.SignRequest(const AParams: TDictionary<string, string>): string;
begin
  // WeChat V3 uses HTTP Authorization header, not query string signing
  Result := '';
end;

function TWeChatPayClient.VerifySignature(const AParams: TDictionary<string, string>;
  const ASign: string): Boolean;
begin
  // TODO: Implement signature verification using WeChat public key
  Result := True;
end;

function TWeChatPayClient.DoWeChatPost(const AEndpoint: string; ABody: TJSONObject): TJSONObject;
var
  AuthHeader, BodyStr, Response: string;
begin
  Result := nil;

  if Assigned(ABody) then
    BodyStr := ABody.ToString
  else
    BodyStr := '';

  AuthHeader := BuildAuthorizationHeader('POST', AEndpoint, BodyStr);
  FHttpClient.CustomHeaders['Authorization'] := AuthHeader;
  FHttpClient.CustomHeaders['Accept'] := 'application/json';
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';

  Response := DoPost(GetApiUrl + AEndpoint, BodyStr, 'application/json');

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppWeChatPay);

  // Check for error
  if Result.GetValue('code') <> nil then
  begin
    var ErrCode := Result.GetValue<string>('code', '');
    var ErrMsg := Result.GetValue<string>('message', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppWeChatPay);
  end;
end;

function TWeChatPayClient.DoWeChatGet(const AEndpoint: string): TJSONObject;
var
  AuthHeader, Response: string;
begin
  Result := nil;

  AuthHeader := BuildAuthorizationHeader('GET', AEndpoint, '');
  FHttpClient.CustomHeaders['Authorization'] := AuthHeader;
  FHttpClient.CustomHeaders['Accept'] := 'application/json';

  Response := DoGet(GetApiUrl + AEndpoint);

  Result := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(Result) then
    raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppWeChatPay);

  if Result.GetValue('code') <> nil then
  begin
    var ErrCode := Result.GetValue<string>('code', '');
    var ErrMsg := Result.GetValue<string>('message', '');
    Result.Free;
    raise EPaymentBusinessError.Create(ErrMsg, ErrCode, ppWeChatPay);
  end;
end;

function TWeChatPayClient.ParseWeChatStatus(const AState: string): TPaymentStatus;
begin
  if AState = 'SUCCESS' then
    Result := psSuccess
  else if AState = 'NOTPAY' then
    Result := psPending
  else if AState = 'CLOSED' then
    Result := psClosed
  else if AState = 'REVOKED' then
    Result := psClosed
  else if AState = 'USERPAYING' then
    Result := psPending
  else if AState = 'PAYERROR' then
    Result := psFailed
  else if AState = 'REFUND' then
    Result := psRefunded
  else
    Result := psUnknown;
end;

function TWeChatPayClient.CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
begin
  case AOrder.PaymentMethod of
    pmQRCode: Result := CreateNativeOrder(AOrder);
    pmH5: Result := CreateH5Order(AOrder);
    pmApp: Result := CreateAppOrder(AOrder);
  else
    // Default to Native (QR code)
    Result := CreateNativeOrder(AOrder);
  end;
end;

function TWeChatPayClient.CreateNativeOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  try
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    ReqBody.AddPair('amount', AmountObj);

    if AOrder.ExpireMinutes > 0 then
      ReqBody.AddPair('time_expire', FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"+08:00"',
        Now + AOrder.ExpireMinutes / 1440));

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/native', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.QRCodeData := RespObj.GetValue<string>('code_url', '');
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateJSAPIOrder(const AOrder: TPaymentOrder;
  const AOpenId: string): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj, PayerObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  if AOpenId = '' then
  begin
    Result := TPaymentResult.Fail('MISSING_OPENID', 'OpenId is required for JSAPI payment');
    Exit;
  end;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  PayerObj := TJSONObject.Create;
  try
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));
    PayerObj.AddPair('openid', AOpenId);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    ReqBody.AddPair('amount', AmountObj);
    ReqBody.AddPair('payer', PayerObj);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/jsapi', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PrepayId := RespObj.GetValue<string>('prepay_id', '');
        Result.AppPayParams := BuildJSAPIPayParams(Result.PrepayId);
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateH5Order(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj, SceneInfoObj, H5InfoObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  SceneInfoObj := TJSONObject.Create;
  H5InfoObj := TJSONObject.Create;
  try
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));

    H5InfoObj.AddPair('type', 'Wap');
    SceneInfoObj.AddPair('payer_client_ip', IfThen(AOrder.ClientIP <> '', AOrder.ClientIP, '127.0.0.1'));
    SceneInfoObj.AddPair('h5_info', H5InfoObj);

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    ReqBody.AddPair('amount', AmountObj);
    ReqBody.AddPair('scene_info', SceneInfoObj);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/h5', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PayUrl := RespObj.GetValue<string>('h5_url', '');
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.CreateAppOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  AmountFen: Int64;
begin
  Result.Clear;
  AOrder.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  AmountFen := Round(AOrder.Amount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  try
    AmountObj.AddPair('total', TJSONNumber.Create(AmountFen));
    AmountObj.AddPair('currency', IfThen(AOrder.Currency <> '', AOrder.Currency, 'CNY'));

    ReqBody.AddPair('appid', Cfg.AppId);
    ReqBody.AddPair('mchid', Cfg.MchId);
    ReqBody.AddPair('description', AOrder.Subject);
    ReqBody.AddPair('out_trade_no', AOrder.OrderNo);

    if AOrder.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', FConfig.NotifyUrl);

    ReqBody.AddPair('amount', AmountObj);

    try
      RespObj := DoWeChatPost('/v3/pay/transactions/app', ReqBody);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.PrepayId := RespObj.GetValue<string>('prepay_id', '');
        Result.AppPayParams := BuildAppPayParams(Result.PrepayId);
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.BuildJSAPIPayParams(const APrepayId: string): string;
var
  Cfg: TWeChatPayConfig;
  Params: TJSONObject;
  Timestamp: Int64;
  NonceStr, SignContent, PaySign: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Sign content for JSAPI
  SignContent := Cfg.AppId + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 'prepay_id=' + APrepayId + #10;
  PaySign := RSASign(SignContent);

  Params := TJSONObject.Create;
  try
    Params.AddPair('appId', Cfg.AppId);
    Params.AddPair('timeStamp', IntToStr(Timestamp));
    Params.AddPair('nonceStr', NonceStr);
    Params.AddPair('package', 'prepay_id=' + APrepayId);
    Params.AddPair('signType', 'RSA');
    Params.AddPair('paySign', PaySign);
    Result := Params.ToString;
  finally
    Params.Free;
  end;
end;

function TWeChatPayClient.BuildAppPayParams(const APrepayId: string): string;
var
  Cfg: TWeChatPayConfig;
  Params: TJSONObject;
  Timestamp: Int64;
  NonceStr, SignContent, PaySign: string;
begin
  Cfg := TWeChatPayConfig(FConfig);
  Timestamp := DateTimeToUnix(Now, False);
  NonceStr := GenerateNonceStr;

  // Sign content for APP
  SignContent := Cfg.AppId + #10 +
                 IntToStr(Timestamp) + #10 +
                 NonceStr + #10 +
                 APrepayId + #10;
  PaySign := RSASign(SignContent);

  Params := TJSONObject.Create;
  try
    Params.AddPair('appid', Cfg.AppId);
    Params.AddPair('partnerid', Cfg.MchId);
    Params.AddPair('prepayid', APrepayId);
    Params.AddPair('package', 'Sign=WXPay');
    Params.AddPair('noncestr', NonceStr);
    Params.AddPair('timestamp', IntToStr(Timestamp));
    Params.AddPair('sign', PaySign);
    Result := Params.ToString;
  finally
    Params.Free;
  end;
end;

function TWeChatPayClient.QueryOrder(const AOrderNo: string): TPaymentQueryResult;
var
  Cfg: TWeChatPayConfig;
  RespObj, AmountObj: TJSONObject;
begin
  Result.Clear;
  Cfg := TWeChatPayConfig(FConfig);

  try
    RespObj := DoWeChatGet('/v3/pay/transactions/out-trade-no/' + AOrderNo +
      '?mchid=' + Cfg.MchId);
    try
      Result.Success := True;
      Result.OrderNo := RespObj.GetValue<string>('out_trade_no', '');
      Result.TradeNo := RespObj.GetValue<string>('transaction_id', '');
      Result.Status := ParseWeChatStatus(RespObj.GetValue<string>('trade_state', ''));

      AmountObj := RespObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountObj) then
      begin
        Result.Amount := AmountObj.GetValue<Int64>('total', 0) / 100;
        Result.PaidAmount := AmountObj.GetValue<Int64>('payer_total', 0) / 100;
      end;

      Result.RawResponse := RespObj.ToString;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
    begin
      Result.ErrorCode := E.ErrorCode;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TWeChatPayClient.CloseOrder(const AOrderNo: string): Boolean;
var
  Cfg: TWeChatPayConfig;
  ReqBody: TJSONObject;
begin
  Result := False;
  Cfg := TWeChatPayConfig(FConfig);

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('mchid', Cfg.MchId);

    try
      // Close order returns 204 No Content on success
      DoWeChatPost('/v3/pay/transactions/out-trade-no/' + AOrderNo + '/close', ReqBody);
      Result := True;
    except
      on E: EPaymentError do
        Result := False;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.Refund(const ARequest: TRefundRequest): TRefundResult;
var
  Cfg: TWeChatPayConfig;
  ReqBody, AmountObj: TJSONObject;
  RespObj: TJSONObject;
  RefundFen, TotalFen: Int64;
begin
  Result.Clear;
  ARequest.Validate;

  Cfg := TWeChatPayConfig(FConfig);
  RefundFen := Round(ARequest.RefundAmount * 100);
  TotalFen := Round(ARequest.TotalAmount * 100);

  ReqBody := TJSONObject.Create;
  AmountObj := TJSONObject.Create;
  try
    AmountObj.AddPair('refund', TJSONNumber.Create(RefundFen));
    AmountObj.AddPair('total', TJSONNumber.Create(TotalFen));
    AmountObj.AddPair('currency', 'CNY');

    ReqBody.AddPair('out_trade_no', ARequest.OrderNo);
    ReqBody.AddPair('out_refund_no', ARequest.RefundNo);
    if ARequest.Reason <> '' then
      ReqBody.AddPair('reason', ARequest.Reason);
    ReqBody.AddPair('amount', AmountObj);

    if ARequest.NotifyUrl <> '' then
      ReqBody.AddPair('notify_url', ARequest.NotifyUrl);

    try
      RespObj := DoWeChatPost('/v3/refund/domestic/refunds', ReqBody);
      try
        Result.Success := True;
        Result.RefundNo := RespObj.GetValue<string>('out_refund_no', '');
        Result.RefundTradeNo := RespObj.GetValue<string>('refund_id', '');

        var RefundStatus := RespObj.GetValue<string>('status', '');
        if RefundStatus = 'SUCCESS' then
          Result.Status := psRefunded
        else if RefundStatus = 'PROCESSING' then
          Result.Status := psRefunding
        else
          Result.Status := psFailed;

        var AmountInfo := RespObj.GetValue<TJSONObject>('amount');
        if Assigned(AmountInfo) then
          Result.RefundAmount := AmountInfo.GetValue<Int64>('refund', 0) / 100;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    ReqBody.Free;
  end;
end;

function TWeChatPayClient.QueryRefund(const ARefundNo: string): TRefundResult;
var
  RespObj: TJSONObject;
begin
  Result.Clear;

  try
    RespObj := DoWeChatGet('/v3/refund/domestic/refunds/' + ARefundNo);
    try
      Result.Success := True;
      Result.RefundNo := RespObj.GetValue<string>('out_refund_no', '');
      Result.RefundTradeNo := RespObj.GetValue<string>('refund_id', '');

      var RefundStatus := RespObj.GetValue<string>('status', '');
      if RefundStatus = 'SUCCESS' then
        Result.Status := psRefunded
      else if RefundStatus = 'PROCESSING' then
        Result.Status := psRefunding
      else if RefundStatus = 'ABNORMAL' then
        Result.Status := psFailed
      else
        Result.Status := psUnknown;

      var AmountInfo := RespObj.GetValue<TJSONObject>('amount');
      if Assigned(AmountInfo) then
        Result.RefundAmount := AmountInfo.GetValue<Int64>('refund', 0) / 100;
    finally
      RespObj.Free;
    end;
  except
    on E: EPaymentError do
      Result := TRefundResult.Fail(E.ErrorCode, E.Message);
  end;
end;

function TWeChatPayClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
var
  JsonObj, ResourceObj, AmountObj: TJSONObject;
  EventType: string;
begin
  Result := False;
  ANotification.Clear;
  ANotification.Provider := ppWeChatPay;
  ANotification.RawData := ARawData;

  // TODO: Verify signature using WeChat platform certificate
  // The notification body is encrypted, need to decrypt using AES-256-GCM

  try
    JsonObj := TJSONObject.ParseJSONValue(ARawData) as TJSONObject;
    if not Assigned(JsonObj) then
      Exit;

    try
      EventType := JsonObj.GetValue<string>('event_type', '');

      // For simplified implementation, assuming decrypted resource
      ResourceObj := JsonObj.GetValue<TJSONObject>('resource');
      if not Assigned(ResourceObj) then
        Exit;

      if EventType = 'TRANSACTION.SUCCESS' then
      begin
        ANotification.OrderNo := ResourceObj.GetValue<string>('out_trade_no', '');
        ANotification.TradeNo := ResourceObj.GetValue<string>('transaction_id', '');
        ANotification.Status := psSuccess;

        AmountObj := ResourceObj.GetValue<TJSONObject>('amount');
        if Assigned(AmountObj) then
          ANotification.Amount := AmountObj.GetValue<Int64>('total', 0) / 100;

        Result := True;
      end
      else if EventType = 'REFUND.SUCCESS' then
      begin
        ANotification.OrderNo := ResourceObj.GetValue<string>('out_trade_no', '');
        ANotification.RefundNo := ResourceObj.GetValue<string>('out_refund_no', '');
        ANotification.RefundTradeNo := ResourceObj.GetValue<string>('refund_id', '');
        ANotification.RefundStatus := psRefunded;

        AmountObj := ResourceObj.GetValue<TJSONObject>('amount');
        if Assigned(AmountObj) then
          ANotification.RefundAmount := AmountObj.GetValue<Int64>('refund', 0) / 100;

        Result := True;
      end;
    finally
      JsonObj.Free;
    end;
  except
    Result := False;
  end;
end;

function TWeChatPayClient.GetNotificationResponse(ASuccess: Boolean): string;
var
  Resp: TJSONObject;
begin
  Resp := TJSONObject.Create;
  try
    if ASuccess then
    begin
      Resp.AddPair('code', 'SUCCESS');
      Resp.AddPair('message', '');
    end
    else
    begin
      Resp.AddPair('code', 'FAIL');
      Resp.AddPair('message', 'Processing failed');
    end;
    Result := Resp.ToString;
  finally
    Resp.Free;
  end;
end;

end.
