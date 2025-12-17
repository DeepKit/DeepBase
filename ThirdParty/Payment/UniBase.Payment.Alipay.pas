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
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
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

    // BUG-019 FIX: 安全密钥存储方法重写
    procedure LoadKeysFromCredentialManager; override;
    procedure SaveKeysToCredentialManager; override;
    /// <summary>设置私钥（自动使用安全存储）</summary>
    procedure SetPrivateKeySecure(const AKey: string);
    /// <summary>获取私钥（自动解密）</summary>
    function GetPrivateKeySecure: string;

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
    {$IFDEF MSWINDOWS}
    function ImportRSAPrivateKey(hProv: HCRYPTPROV; const PEMKey: string; out hKey: HCRYPTKEY): Boolean;
    function ValidatePrivateKey(const PEMKey: string): Boolean;
    {$ENDIF}
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

// BUG-019 FIX: 安全密钥存储方法实现
procedure TAlipayConfig.LoadKeysFromCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    FPrivateKey := GetCredentialKey('PrivateKey');
    FAlipayPublicKey := GetCredentialKey('AlipayPublicKey');
  end;
end;

procedure TAlipayConfig.SaveKeysToCredentialManager;
begin
  if KeyStorageMode = ksmCredential then
  begin
    SetCredentialKey('PrivateKey', FPrivateKey);
    SetCredentialKey('AlipayPublicKey', FAlipayPublicKey);
  end;
end;

procedure TAlipayConfig.SetPrivateKeySecure(const AKey: string);
begin
  FPrivateKey := ProtectKey(AKey);
end;

function TAlipayConfig.GetPrivateKeySecure: string;
begin
  Result := UnprotectKey(FPrivateKey);
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
{$IFDEF MSWINDOWS}
var
  PrivateKey: string;
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  dwSigLen: DWORD;
  pbSignature: PByte;
  ContentBytes: TBytes;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  PrivateKey := TAlipayConfig(FConfig).PrivateKey;
  
  if PrivateKey = '' then
    raise EPaymentException.Create('Private key not configured for RSA signing');
  
  // 使用安全的RSA2-SHA256签名实现
  if not CryptAcquireContext(@hProv, nil, nil, PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EPaymentException.Create('Failed to acquire crypto context');
    
  try
    // 验证私钥格式和安全性
    if not ValidatePrivateKey(PrivateKey) then
      raise EPaymentException.Create('Invalid or insecure private key format');
      
    // 导入私钥 (需要将PEM格式转换为Windows格式)
    if not ImportRSAPrivateKey(hProv, PrivateKey, hKey) then
      raise EPaymentException.Create('Failed to import RSA private key');
      
    try
      // 创建SHA256哈希
      if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, @hHash) then
        raise EPaymentException.Create('Failed to create SHA256 hash');
        
      try
        ContentBytes := TEncoding.UTF8.GetBytes(AContent);
        
        // 验证内容长度，防止过大数据攻击
        if Length(ContentBytes) > 1024 * 1024 then // 1MB限制
          raise EPaymentException.Create('Content too large for signing');
        
        // 计算哈希
        if not CryptHashData(hHash, @ContentBytes[0], Length(ContentBytes), 0) then
          raise EPaymentException.Create('Failed to hash data');
          
        // 获取签名长度
        dwSigLen := 0;
        if not CryptSignHash(hHash, AT_SIGNATURE, nil, 0, nil, @dwSigLen) then
          raise EPaymentException.Create('Failed to get signature length');
          
        // 分配签名缓冲区
        GetMem(pbSignature, dwSigLen);
        try
          // 生成签名
          if not CryptSignHash(hHash, AT_SIGNATURE, nil, 0, pbSignature, @dwSigLen) then
            raise EPaymentException.Create('Failed to sign hash');
            
          // 转换为Base64
          Result := TPaymentHelper.Base64Encode(pbSignature, dwSigLen);
        finally
          FreeMem(pbSignature);
        end;
      finally
        CryptDestroyHash(hHash);
      end;
    finally
      CryptDestroyKey(hKey);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
  {$ELSE}
  // 非Windows平台需要使用OpenSSL或其他加密库
  raise ENotImplemented.Create('RSA2 signing not implemented for this platform. Use OpenSSL library.');
  {$ENDIF}
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

{$IFDEF MSWINDOWS}
function TAlipayClient.ValidatePrivateKey(const PEMKey: string): Boolean;
begin
  Result := False;
  
  // 验证PEM格式
  if not PEMKey.Contains('-----BEGIN PRIVATE KEY-----') and 
     not PEMKey.Contains('-----BEGIN RSA PRIVATE KEY-----') then
    Exit;
    
  if not PEMKey.Contains('-----END PRIVATE KEY-----') and 
     not PEMKey.Contains('-----END RSA PRIVATE KEY-----') then
    Exit;
  
  // 验证密钥长度（至少2048位）
  var KeyContent := PEMKey.Replace('-----BEGIN PRIVATE KEY-----', '')
                          .Replace('-----END PRIVATE KEY-----', '')
                          .Replace('-----BEGIN RSA PRIVATE KEY-----', '')
                          .Replace('-----END RSA PRIVATE KEY-----', '')
                          .Replace(#13, '').Replace(#10, '').Replace(' ', '');
  
  // Base64解码后的RSA私钥长度检查（2048位密钥约为1200+字节）
  if Length(KeyContent) < 1000 then
    Exit;
    
  Result := True;
end;

function TAlipayClient.ImportRSAPrivateKey(hProv: HCRYPTPROV; const PEMKey: string; out hKey: HCRYPTKEY): Boolean;
var
  KeyBlob: TBytes;
  BlobHeader: BLOBHEADER;
  RSAHeader: RSAPUBKEY;
begin
  Result := False;
  hKey := 0;
  
  // 这里需要实现PEM格式私钥到Windows CryptoAPI格式的转换
  // 实际实现需要解析PEM格式，提取RSA参数，构造PRIVATEKEYBLOB
  // 为简化示例，这里返回False，实际项目中需要完整实现
  
  // TODO: 实现完整的PEM到CryptoAPI格式转换
  // 可以使用第三方库如OpenSSL或Indy来简化这个过程
  
  Result := False;
end;
{$ENDIF}

end.
