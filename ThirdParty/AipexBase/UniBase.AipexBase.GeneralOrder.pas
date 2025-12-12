unit UniBase.AipexBase.GeneralOrder;

{*******************************************************************************
  UniBase <-> AipexBase Integration (GeneralOrder / Pay)

  说明:
  - 该单元不做 Stripe/微信等渠道直连；渠道对接由 AipexBase 后端统一处理。
  - UniBase 侧仅通过 HTTP 调用 AipexBase 的 /generalOrder 接口。

  关键请求头(后端 GlobalAppIdFilter / DynamicAuthFilter):
  - APP_ID: 应用 ID（必填；或用 CODE_FLYING 换取 APP_ID）
  - APP_TYPE: user/admin (可选，默认 user)
  - CODE_FLYING: API Key（可选；当 APP_ID 为空时可用它推导 APP_ID）
  - Authorization: Bearer <token>（当后端要求登录时需要）
*******************************************************************************}

interface

uses
  System.SysUtils,
  System.JSON,
  UniBase.Net;

type
  EAipexBaseException = class(Exception);

  TAipexBaseAuth = record
    AppId: string;
    AppType: string;     // user/admin
    CodeFlying: string;  // API key
    BearerToken: string; // JWT

    class function ForAppId(const AAppId: string;
      const ABearerToken: string = '';
      const AAppType: string = 'user'): TAipexBaseAuth; static;

    class function ForApiKey(const ACodeFlying: string;
      const ABearerToken: string = '';
      const AAppType: string = 'user'): TAipexBaseAuth; static;
  end;

  /// <summary>
  /// AipexBase /generalOrder 接口客户端。
  /// 注意：返回的 TJSONValue 需要由调用方 Free。
  /// </summary>
  TAipexGeneralOrderClient = class
  private
    FHttp: THttpClient_;
    FAuth: TAipexBaseAuth;

    function BuildRequest(const ARelativePath: string): THttpRequest;
    function ParseBaseResponseData(const AResponse: THttpResponse): TJSONValue;

  public
    constructor Create(const ABaseUrl: string; const AAuth: TAipexBaseAuth);
    destructor Destroy; override;

    /// <summary>GET /generalOrder/payMethod</summary>
    function PayMethods: TArray<string>;

    /// <summary>POST /generalOrder/{operateName}</summary>
    function HandleOrder(const AOperateName: string; ABody: TJSONObject): TJSONValue;

    /// <summary>POST /generalOrder/getUniqueOrderNo</summary>
    function GetUniqueOrderNo(AProductId, AUserId: Integer): string;

    /// <summary>POST /generalOrder/create</summary>
    function CreateOrder(ABody: TJSONObject): TJSONValue;

    /// <summary>POST /generalOrder/getPaymentParam</summary>
    function GetPaymentParam(const AOrderNoOrPaymentOrderId: string): TJSONValue;

    /// <summary>POST /generalOrder/getPayOrderMessage</summary>
    function GetPayOrderMessage(const AOrderNoOrPaymentOrderId: string): TJSONValue;

    /// <summary>POST /generalOrder/cancelPay</summary>
    function CancelPay(const AOrderNoOrPaymentOrderId: string): Boolean;

    /// <summary>POST /generalOrder/refund</summary>
    function Refund(const AId: string): TJSONValue;
  end;

implementation

{ TAipexBaseAuth }

class function TAipexBaseAuth.ForAppId(const AAppId, ABearerToken, AAppType: string): TAipexBaseAuth;
begin
  Result.AppId := AAppId;
  Result.AppType := AAppType;
  Result.CodeFlying := '';
  Result.BearerToken := ABearerToken;
end;

class function TAipexBaseAuth.ForApiKey(const ACodeFlying, ABearerToken, AAppType: string): TAipexBaseAuth;
begin
  Result.AppId := '';
  Result.AppType := AAppType;
  Result.CodeFlying := ACodeFlying;
  Result.BearerToken := ABearerToken;
end;

{ TAipexGeneralOrderClient }

constructor TAipexGeneralOrderClient.Create(const ABaseUrl: string; const AAuth: TAipexBaseAuth);
begin
  inherited Create;
  FHttp := THttpClient_.Create(ABaseUrl);
  FAuth := AAuth;
end;

destructor TAipexGeneralOrderClient.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TAipexGeneralOrderClient.BuildRequest(const ARelativePath: string): THttpRequest;
begin
  Result := FHttp.Request(ARelativePath)
    .Header('Accept', 'application/json');

  // APP 标识
  if FAuth.AppId <> '' then
    Result.Header('APP_ID', FAuth.AppId);

  // API key（当 APP_ID 为空时后端会用它推导 APP_ID；也可以同时发送）
  if FAuth.CodeFlying <> '' then
    Result.Header('CODE_FLYING', FAuth.CodeFlying);

  // APP_TYPE 默认 user
  if FAuth.AppType <> '' then
    Result.Header('APP_TYPE', FAuth.AppType);

  // 登录 token
  if FAuth.BearerToken <> '' then
    Result.BearerToken(FAuth.BearerToken);
end;

function TAipexGeneralOrderClient.ParseBaseResponseData(const AResponse: THttpResponse): TJSONValue;
var
  LRoot: TJSONObject;
  LCode: Integer;
  LMsg: string;
  LData: TJSONValue;
begin
  Result := nil;

  if not AResponse.IsSuccess then
    raise EAipexBaseException.CreateFmt('HTTP %d %s: %s', [AResponse.StatusCode, AResponse.StatusText, AResponse.Body]);

  LRoot := AResponse.AsJSON as TJSONObject;
  if not Assigned(LRoot) then
    raise EAipexBaseException.CreateFmt('响应不是合法 JSON: %s', [AResponse.Body]);

  try
    if not LRoot.TryGetValue<Integer>('code', LCode) then
      raise EAipexBaseException.CreateFmt('缺少字段 code: %s', [AResponse.Body]);

    LRoot.TryGetValue<string>('message', LMsg);

    if LCode <> 0 then
      raise EAipexBaseException.CreateFmt('AipexBase 错误 code=%d message=%s body=%s', [LCode, LMsg, AResponse.Body]);

    LData := LRoot.GetValue('data');
    if Assigned(LData) then
      Result := LData.Clone
    else
      Result := nil;
  finally
    LRoot.Free;
  end;
end;

function TAipexGeneralOrderClient.PayMethods: TArray<string>;
var
  LResp: THttpResponse;
  LData: TJSONValue;
  LArr: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);

  LResp := BuildRequest('/generalOrder/payMethod').Get;
  try
    LData := ParseBaseResponseData(LResp);
    try
      if not (LData is TJSONArray) then
        Exit;

      LArr := TJSONArray(LData);
      SetLength(Result, LArr.Count);
      for I := 0 to LArr.Count - 1 do
        Result[I] := LArr.Items[I].Value;
    finally
      LData.Free;
    end;
  finally
    LResp.Free;
  end;
end;

function TAipexGeneralOrderClient.HandleOrder(const AOperateName: string; ABody: TJSONObject): TJSONValue;
var
  LResp: THttpResponse;
  LPath: string;
begin
  if AOperateName.Trim = '' then
    raise EAipexBaseException.Create('operateName 不能为空');

  LPath := '/generalOrder/' + AOperateName.Trim;

  LResp := BuildRequest(LPath).JsonBody(ABody).Post;
  try
    Result := ParseBaseResponseData(LResp);
  finally
    LResp.Free;
  end;
end;

function TAipexGeneralOrderClient.GetUniqueOrderNo(AProductId, AUserId: Integer): string;
var
  LBody: TJSONObject;
  LData: TJSONValue;
begin
  Result := '';

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('productId', TJSONNumber.Create(AProductId));
    LBody.AddPair('userId', TJSONNumber.Create(AUserId));

    LData := HandleOrder('getUniqueOrderNo', LBody);
    try
      if Assigned(LData) then
        Result := LData.Value;
    finally
      LData.Free;
    end;
  finally
    LBody.Free;
  end;
end;

function TAipexGeneralOrderClient.CreateOrder(ABody: TJSONObject): TJSONValue;
begin
  Result := HandleOrder('create', ABody);
end;

function TAipexGeneralOrderClient.GetPaymentParam(const AOrderNoOrPaymentOrderId: string): TJSONValue;
var
  LBody: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    // 后端会从 orderNo 或 paymentOrderId 里择一读取
    LBody.AddPair('orderNo', AOrderNoOrPaymentOrderId);
    LBody.AddPair('paymentOrderId', AOrderNoOrPaymentOrderId);
    Result := HandleOrder('getPaymentParam', LBody);
  finally
    LBody.Free;
  end;
end;

function TAipexGeneralOrderClient.GetPayOrderMessage(const AOrderNoOrPaymentOrderId: string): TJSONValue;
var
  LBody: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    // 后端会从 orderNo / paymentOrderId / orderId 里择一读取
    LBody.AddPair('orderNo', AOrderNoOrPaymentOrderId);
    LBody.AddPair('paymentOrderId', AOrderNoOrPaymentOrderId);
    LBody.AddPair('orderId', AOrderNoOrPaymentOrderId);
    Result := HandleOrder('getPayOrderMessage', LBody);
  finally
    LBody.Free;
  end;
end;

function TAipexGeneralOrderClient.CancelPay(const AOrderNoOrPaymentOrderId: string): Boolean;
var
  LBody: TJSONObject;
  LData: TJSONValue;
begin
  Result := False;

  LBody := TJSONObject.Create;
  try
    LBody.AddPair('orderNo', AOrderNoOrPaymentOrderId);
    LBody.AddPair('paymentOrderId', AOrderNoOrPaymentOrderId);

    LData := HandleOrder('cancelPay', LBody);
    try
      if Assigned(LData) then
      begin
        // data 通常是 true/false
        Result := SameText(LData.Value, 'true') or (LData.Value = '1');
      end;
    finally
      LData.Free;
    end;
  finally
    LBody.Free;
  end;
end;

function TAipexGeneralOrderClient.Refund(const AId: string): TJSONValue;
var
  LBody: TJSONObject;
begin
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('id', AId);
    Result := HandleOrder('refund', LBody);
  finally
    LBody.Free;
  end;
end;

end.
