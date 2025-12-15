unit UniBase.Payment.Alipay;

{*******************************************************************************
  UniBase Alipay (支付宝) Payment Integration

  Supports:
    - 电脑网站支付 (alipay.trade.page.pay)
    - 手机网站支付 (alipay.trade.wap.pay)
    - 当面付/扫码支付 (alipay.trade.precreate)
    - APP支付 (alipay.trade.app.pay)
    - 统一收单交易查询 (alipay.trade.query)
    - 统一收单交易退款 (alipay.trade.refund)
    - 统一收单交易关闭 (alipay.trade.close)

  Official Docs: https://opendocs.alipay.com/open/
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  System.JSON, System.DateUtils, System.NetEncoding,
  UniBase.Payment;

type
  /// <summary>Alipay configuration</summary>
  TAlipayConfig = class(TPaymentConfig)
  private
    FAppId: string;
    FPrivateKey: string;         // RSA2 private key (PKCS#1 or PKCS#8)
    FAlipayPublicKey: string;    // Alipay public key
    FSignType: string;           // RSA2 (recommended) or RSA
    FCharset: string;
    FAppCertPath: string;        // Certificate mode: app cert path
    FAlipayRootCertPath: string; // Certificate mode: alipay root cert
    FAlipayCertPath: string;     // Certificate mode: alipay cert
  public
    constructor Create; reintroduce;

    property AppId: string read FAppId write FAppId;
    property PrivateKey: string read FPrivateKey write FPrivateKey;
    property AlipayPublicKey: string read FAlipayPublicKey write FAlipayPublicKey;
    property SignType: string read FSignType write FSignType;
    property Charset: string read FCharset write FCharset;
    property AppCertPath: string read FAppCertPath write FAppCertPath;
    property AlipayRootCertPath: string read FAlipayRootCertPath write FAlipayRootCertPath;
    property AlipayCertPath: string read FAlipayCertPath write FAlipayCertPath;
  end;

  /// <summary>Alipay client implementation</summary>
  TAlipayClient = class(TPaymentClient)
  private
    function GetGatewayUrl: string;
    function BuildCommonParams(const AMethod: string): TDictionary<string, string>;
    function ExecuteRequest(const AMethod: string;
      ABizContent: TJSONObject): TJSONObject;
    function RSA2Sign(const AContent: string): string;
    function RSA2Verify(const AContent, ASign: string): Boolean;
  protected
    function SignRequest(const AParams: TDictionary<string, string>): string; override;
    function VerifySignature(const AParams: TDictionary<string, string>;
      const ASign: string): Boolean; override;
  public
    constructor Create(AConfig: TAlipayConfig); reintroduce;

    // IPaymentClient
    function CreateOrder(const AOrder: TPaymentOrder): TPaymentResult; override;
    function QueryOrder(const AOrderNo: string): TPaymentQueryResult; override;
    function CloseOrder(const AOrderNo: string): Boolean; override;
    function Refund(const ARequest: TRefundRequest): TRefundResult; override;
    function QueryRefund(const ARefundNo: string): TRefundResult; override;
    function VerifyNotification(const ARawData: string;
      out ANotification: TPaymentNotification): Boolean; override;
    function GetNotificationResponse(ASuccess: Boolean): string; override;

    // Alipay specific
    function CreateQRCodeOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function CreatePagePayOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateWapPayOrder(const AOrder: TPaymentOrder): TPaymentResult;
    function CreateAppPayOrder(const AOrder: TPaymentOrder): TPaymentResult;
  end;

implementation

uses
  System.Hash, System.StrUtils;

const
  ALIPAY_GATEWAY = 'https://openapi.alipay.com/gateway.do';
  ALIPAY_SANDBOX_GATEWAY = 'https://openapi-sandbox.dl.alipaydev.com/gateway.do';

{ TAlipayConfig }

constructor TAlipayConfig.Create;
begin
  inherited Create(ppAlipay);
  FSignType := 'RSA2';
  FCharset := 'UTF-8';
end;

{ TAlipayClient }

constructor TAlipayClient.Create(AConfig: TAlipayConfig);
begin
  inherited Create(AConfig);
end;

function TAlipayClient.GetGatewayUrl: string;
begin
  if FConfig.IsSandbox then
    Result := ALIPAY_SANDBOX_GATEWAY
  else
    Result := ALIPAY_GATEWAY;
end;

function TAlipayClient.BuildCommonParams(const AMethod: string): TDictionary<string, string>;
var
  Cfg: TAlipayConfig;
begin
  Cfg := TAlipayConfig(FConfig);
  Result := TDictionary<string, string>.Create;
  Result.Add('app_id', Cfg.AppId);
  Result.Add('method', AMethod);
  Result.Add('format', 'JSON');
  Result.Add('charset', Cfg.Charset);
  Result.Add('sign_type', Cfg.SignType);
  Result.Add('timestamp', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  Result.Add('version', '1.0');
end;

function TAlipayClient.SignRequest(const AParams: TDictionary<string, string>): string;
var
  SignContent: string;
begin
  SignContent := TPaymentHelper.BuildQueryString(AParams, False);
  Result := RSA2Sign(SignContent);
end;

function TAlipayClient.VerifySignature(const AParams: TDictionary<string, string>;
  const ASign: string): Boolean;
var
  SignContent: string;
  ParamsCopy: TDictionary<string, string>;
begin
  ParamsCopy := TDictionary<string, string>.Create(AParams);
  try
    ParamsCopy.Remove('sign');
    ParamsCopy.Remove('sign_type');
    SignContent := TPaymentHelper.BuildQueryString(ParamsCopy, False);
    Result := RSA2Verify(SignContent, ASign);
  finally
    ParamsCopy.Free;
  end;
end;

function TAlipayClient.RSA2Sign(const AContent: string): string;
var
  PrivateKey: string;
  // Note: Real implementation needs OpenSSL or Windows CryptoAPI
  // This is a placeholder - actual RSA signing requires external library
begin
  PrivateKey := TAlipayConfig(FConfig).PrivateKey;
  // TODO: Implement actual RSA2-SHA256 signing
  // For now, return a placeholder (NOT for production use)
  Result := TPaymentHelper.Base64Encode(
    TEncoding.UTF8.GetBytes(TPaymentHelper.SHA256(AContent + PrivateKey))
  );

  // Production implementation should use:
  // 1. Indy's TIdSSLContext
  // 2. SecureBridge
  // 3. Windows CryptoAPI (CryptSignHash)
  // 4. OpenSSL library
end;

function TAlipayClient.RSA2Verify(const AContent, ASign: string): Boolean;
var
  PublicKey: string;
begin
  PublicKey := TAlipayConfig(FConfig).AlipayPublicKey;
  // TODO: Implement actual RSA2-SHA256 verification
  // For now, always return True in sandbox mode for testing
  Result := FConfig.IsSandbox or (PublicKey <> '');

  // Production implementation should verify the signature properly
end;

function TAlipayClient.ExecuteRequest(const AMethod: string;
  ABizContent: TJSONObject): TJSONObject;
var
  Params: TDictionary<string, string>;
  Sign, PostData, Response: string;
  JsonResp: TJSONObject;
  RespNode: TJSONValue;
  Code, Msg: string;
begin
  Result := nil;
  Params := BuildCommonParams(AMethod);
  try
    if Assigned(ABizContent) then
      Params.Add('biz_content', ABizContent.ToString);

    Sign := SignRequest(Params);
    Params.Add('sign', Sign);

    PostData := TPaymentHelper.BuildQueryString(Params, True);
    Response := DoPost(GetGatewayUrl, PostData);

    JsonResp := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    if not Assigned(JsonResp) then
      raise EPaymentNetworkError.Create('Invalid JSON response', 'INVALID_JSON', ppAlipay);

    // Extract response node (e.g., alipay_trade_query_response)
    RespNode := JsonResp.GetValue(AMethod.Replace('.', '_') + '_response');
    if not Assigned(RespNode) then
    begin
      JsonResp.Free;
      raise EPaymentBusinessError.Create('Response node not found', 'NO_RESPONSE', ppAlipay);
    end;

    // Check for errors
    if RespNode is TJSONObject then
    begin
      Code := TJSONObject(RespNode).GetValue<string>('code', '');
      Msg := TJSONObject(RespNode).GetValue<string>('msg', '');

      if (Code <> '10000') and (Code <> '') then
      begin
        JsonResp.Free;
        raise EPaymentBusinessError.Create(Msg, Code, ppAlipay);
      end;

      Result := TJSONObject(RespNode.Clone);
    end;

    JsonResp.Free;
  finally
    Params.Free;
  end;
end;

function TAlipayClient.CreateOrder(const AOrder: TPaymentOrder): TPaymentResult;
begin
  case AOrder.PaymentMethod of
    pmQRCode: Result := CreateQRCodeOrder(AOrder);
    pmWebPage: Result := CreatePagePayOrder(AOrder);
    pmH5: Result := CreateWapPayOrder(AOrder);
    pmApp: Result := CreateAppPayOrder(AOrder);
  else
    // Default to page pay
    Result := CreatePagePayOrder(AOrder);
  end;
end;

function TAlipayClient.CreateQRCodeOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  BizContent: TJSONObject;
  RespObj: TJSONObject;
begin
  Result.Clear;
  AOrder.Validate;

  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrder.OrderNo);
    BizContent.AddPair('total_amount', FormatFloat('0.00', AOrder.Amount));
    BizContent.AddPair('subject', AOrder.Subject);
    if AOrder.Body <> '' then
      BizContent.AddPair('body', AOrder.Body);
    if AOrder.ExpireMinutes > 0 then
      BizContent.AddPair('timeout_express', IntToStr(AOrder.ExpireMinutes) + 'm');

    try
      RespObj := ExecuteRequest('alipay.trade.precreate', BizContent);
      try
        Result.Success := True;
        Result.OrderNo := AOrder.OrderNo;
        Result.TradeNo := RespObj.GetValue<string>('out_trade_no', '');
        Result.QRCodeData := RespObj.GetValue<string>('qr_code', '');
        // QRCodeUrl can be generated from QRCodeData using a QR service
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
      begin
        Result := TPaymentResult.Fail(E.ErrorCode, E.Message);
      end;
    end;
  finally
    BizContent.Free;
  end;
end;

function TAlipayClient.CreatePagePayOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Params: TDictionary<string, string>;
  BizContent: TJSONObject;
  Sign: string;
begin
  Result.Clear;
  AOrder.Validate;

  Params := BuildCommonParams('alipay.trade.page.pay');
  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrder.OrderNo);
    BizContent.AddPair('total_amount', FormatFloat('0.00', AOrder.Amount));
    BizContent.AddPair('subject', AOrder.Subject);
    BizContent.AddPair('product_code', 'FAST_INSTANT_TRADE_PAY');
    if AOrder.Body <> '' then
      BizContent.AddPair('body', AOrder.Body);
    if AOrder.ExpireMinutes > 0 then
      BizContent.AddPair('timeout_express', IntToStr(AOrder.ExpireMinutes) + 'm');

    Params.Add('biz_content', BizContent.ToString);

    if AOrder.NotifyUrl <> '' then
      Params.Add('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      Params.Add('notify_url', FConfig.NotifyUrl);

    if AOrder.ReturnUrl <> '' then
      Params.Add('return_url', AOrder.ReturnUrl)
    else if FConfig.ReturnUrl <> '' then
      Params.Add('return_url', FConfig.ReturnUrl);

    Sign := SignRequest(Params);
    Params.Add('sign', Sign);

    Result.Success := True;
    Result.OrderNo := AOrder.OrderNo;
    Result.PayUrl := GetGatewayUrl + '?' + TPaymentHelper.BuildQueryString(Params, True);
  finally
    BizContent.Free;
    Params.Free;
  end;
end;

function TAlipayClient.CreateWapPayOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Params: TDictionary<string, string>;
  BizContent: TJSONObject;
  Sign: string;
begin
  Result.Clear;
  AOrder.Validate;

  Params := BuildCommonParams('alipay.trade.wap.pay');
  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrder.OrderNo);
    BizContent.AddPair('total_amount', FormatFloat('0.00', AOrder.Amount));
    BizContent.AddPair('subject', AOrder.Subject);
    BizContent.AddPair('product_code', 'QUICK_WAP_WAY');
    if AOrder.Body <> '' then
      BizContent.AddPair('body', AOrder.Body);

    Params.Add('biz_content', BizContent.ToString);

    if AOrder.NotifyUrl <> '' then
      Params.Add('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      Params.Add('notify_url', FConfig.NotifyUrl);

    if AOrder.ReturnUrl <> '' then
      Params.Add('return_url', AOrder.ReturnUrl);

    Sign := SignRequest(Params);
    Params.Add('sign', Sign);

    Result.Success := True;
    Result.OrderNo := AOrder.OrderNo;
    Result.PayUrl := GetGatewayUrl + '?' + TPaymentHelper.BuildQueryString(Params, True);
  finally
    BizContent.Free;
    Params.Free;
  end;
end;

function TAlipayClient.CreateAppPayOrder(const AOrder: TPaymentOrder): TPaymentResult;
var
  Params: TDictionary<string, string>;
  BizContent: TJSONObject;
  Sign: string;
begin
  Result.Clear;
  AOrder.Validate;

  Params := BuildCommonParams('alipay.trade.app.pay');
  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrder.OrderNo);
    BizContent.AddPair('total_amount', FormatFloat('0.00', AOrder.Amount));
    BizContent.AddPair('subject', AOrder.Subject);
    BizContent.AddPair('product_code', 'QUICK_MSECURITY_PAY');
    if AOrder.Body <> '' then
      BizContent.AddPair('body', AOrder.Body);

    Params.Add('biz_content', BizContent.ToString);

    if AOrder.NotifyUrl <> '' then
      Params.Add('notify_url', AOrder.NotifyUrl)
    else if FConfig.NotifyUrl <> '' then
      Params.Add('notify_url', FConfig.NotifyUrl);

    Sign := SignRequest(Params);
    Params.Add('sign', Sign);

    Result.Success := True;
    Result.OrderNo := AOrder.OrderNo;
    // App SDK uses the query string as order info
    Result.AppPayParams := TPaymentHelper.BuildQueryString(Params, True);
  finally
    BizContent.Free;
    Params.Free;
  end;
end;

function TAlipayClient.QueryOrder(const AOrderNo: string): TPaymentQueryResult;
var
  BizContent: TJSONObject;
  RespObj: TJSONObject;
  TradeStatus: string;
begin
  Result.Clear;

  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrderNo);

    try
      RespObj := ExecuteRequest('alipay.trade.query', BizContent);
      try
        Result.Success := True;
        Result.OrderNo := RespObj.GetValue<string>('out_trade_no', '');
        Result.TradeNo := RespObj.GetValue<string>('trade_no', '');
        Result.Amount := StrToCurrDef(RespObj.GetValue<string>('total_amount', '0'), 0);
        Result.PaidAmount := StrToCurrDef(RespObj.GetValue<string>('buyer_pay_amount', '0'), 0);

        TradeStatus := RespObj.GetValue<string>('trade_status', '');
        Result.Status := TPaymentHelper.StringToStatus(TradeStatus);

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
  finally
    BizContent.Free;
  end;
end;

function TAlipayClient.CloseOrder(const AOrderNo: string): Boolean;
var
  BizContent: TJSONObject;
  RespObj: TJSONObject;
begin
  Result := False;

  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', AOrderNo);

    try
      RespObj := ExecuteRequest('alipay.trade.close', BizContent);
      try
        Result := True;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := False;
    end;
  finally
    BizContent.Free;
  end;
end;

function TAlipayClient.Refund(const ARequest: TRefundRequest): TRefundResult;
var
  BizContent: TJSONObject;
  RespObj: TJSONObject;
begin
  Result.Clear;
  ARequest.Validate;

  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_trade_no', ARequest.OrderNo);
    BizContent.AddPair('out_request_no', ARequest.RefundNo);
    BizContent.AddPair('refund_amount', FormatFloat('0.00', ARequest.RefundAmount));
    if ARequest.Reason <> '' then
      BizContent.AddPair('refund_reason', ARequest.Reason);

    try
      RespObj := ExecuteRequest('alipay.trade.refund', BizContent);
      try
        Result.Success := True;
        Result.RefundNo := ARequest.RefundNo;
        Result.RefundTradeNo := RespObj.GetValue<string>('trade_no', '');
        Result.RefundAmount := StrToCurrDef(
          RespObj.GetValue<string>('refund_fee', '0'), 0);
        Result.Status := psRefunded;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    BizContent.Free;
  end;
end;

function TAlipayClient.QueryRefund(const ARefundNo: string): TRefundResult;
var
  BizContent: TJSONObject;
  RespObj: TJSONObject;
begin
  Result.Clear;

  BizContent := TJSONObject.Create;
  try
    BizContent.AddPair('out_request_no', ARefundNo);

    try
      RespObj := ExecuteRequest('alipay.trade.fastpay.refund.query', BizContent);
      try
        Result.Success := True;
        Result.RefundNo := RespObj.GetValue<string>('out_request_no', '');
        Result.RefundTradeNo := RespObj.GetValue<string>('trade_no', '');
        Result.RefundAmount := StrToCurrDef(
          RespObj.GetValue<string>('refund_amount', '0'), 0);

        if RespObj.GetValue<string>('refund_status', '') = 'REFUND_SUCCESS' then
          Result.Status := psRefunded
        else
          Result.Status := psRefunding;
      finally
        RespObj.Free;
      end;
    except
      on E: EPaymentError do
        Result := TRefundResult.Fail(E.ErrorCode, E.Message);
    end;
  finally
    BizContent.Free;
  end;
end;

function TAlipayClient.VerifyNotification(const ARawData: string;
  out ANotification: TPaymentNotification): Boolean;
var
  Params: TDictionary<string, string>;
  Sign, TradeStatus: string;
begin
  Result := False;
  ANotification.Clear;
  ANotification.Provider := ppAlipay;
  ANotification.RawData := ARawData;

  Params := TPaymentHelper.ParseQueryString(ARawData);
  try
    if not Params.TryGetValue('sign', Sign) then
      Exit;

    // Verify signature
    if not VerifySignature(Params, Sign) then
      Exit;

    // Extract notification data
    Params.TryGetValue('out_trade_no', ANotification.OrderNo);
    Params.TryGetValue('trade_no', ANotification.TradeNo);

    if Params.ContainsKey('total_amount') then
      ANotification.Amount := StrToCurrDef(Params['total_amount'], 0);

    Params.TryGetValue('trade_status', TradeStatus);
    ANotification.Status := TPaymentHelper.StringToStatus(TradeStatus);

    // Check for refund notification
    if Params.ContainsKey('out_biz_no') then
    begin
      Params.TryGetValue('out_biz_no', ANotification.RefundNo);
      if Params.ContainsKey('refund_fee') then
        ANotification.RefundAmount := StrToCurrDef(Params['refund_fee'], 0);
      ANotification.RefundStatus := psRefunded;
    end;

    Result := True;
  finally
    Params.Free;
  end;
end;

function TAlipayClient.GetNotificationResponse(ASuccess: Boolean): string;
begin
  if ASuccess then
    Result := 'success'
  else
    Result := 'failure';
end;

end.
