{ ============================================================================
  UniBase.AipexBase.Client - Optional AipexBase API Client

  Version: 1.0
  Description: API client for AipexBase backend service.
               This unit is intentionally located under ThirdParty/AipexBase,
               not Core, because it binds UniBase to a specific backend.
  ============================================================================ }

unit UniBase.AipexBase.Client;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.DateUtils,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  System.Generics.Collections, System.NetEncoding, System.Net.Mime;

type
  /// <summary>API Exception base class</summary>
  EAipexBaseError = class(Exception)
  public
    StatusCode: Integer;
    ErrorCode: string;
    constructor Create(const AMessage: string; AStatusCode: Integer = 0;
      const AErrorCode: string = ''); reintroduce;
  end;

  EAipexBaseAuthError = class(EAipexBaseError);
  EAipexBaseNotFoundError = class(EAipexBaseError);
  EAipexBaseValidationError = class(EAipexBaseError);

  TAipexTransaction = record
    TransactionId: string;
    TransactionType: string;
    Amount: Currency;
    Balance: Currency;
    Description: string;
    CreatedAt: TDateTime;
    Status: string;
  end;
  TAipexTransactions = TArray<TAipexTransaction>;

  /// <summary>User info record</summary>
  TAipexUser = record
    UserId: Integer;
    Username: string;
    Email: string;
    Phone: string;
    Avatar: string;
    CreatedAt: TDateTime;
    LastLoginAt: TDateTime;
    Status: string;

    // Compatibility fields used by legacy FMX frames.
    Nickname: string;
    Bio: string;
    TwoFactorEnabled: Boolean;

    procedure Clear;
  end;

  TAipexUserUpdateRequest = record
    Nickname: string;
    Phone: string;
    Bio: string;
  end;

  /// <summary>Balance info record</summary>
  TAipexBalance = record
    Balance: Currency;
    Currency: string;
    FrozenAmount: Currency;
    AvailableAmount: Currency;
    RecentTransactions: TAipexTransactions;

    procedure Clear;
  end;

  /// <summary>Recharge option</summary>
  TAipexRechargeOption = record
    Amount: Currency;
    Bonus: Currency;
    Description: string;
  end;
  TAipexRechargeOptions = TArray<TAipexRechargeOption>;

  /// <summary>Daily usage data point</summary>
  TAipexUsageDataPoint = record
    Date: TDate;
    Calls: Int64;
    InputTokens: Int64;
    OutputTokens: Int64;
    Cost: Currency;
  end;
  TAipexUsageDataPoints = TArray<TAipexUsageDataPoint>;
  TAipexDailyUsage = TAipexUsageDataPoint;

  /// <summary>Model usage breakdown</summary>
  TAipexModelUsage = record
    Model: string;
    Calls: Int64;
    Tokens: Int64;
    Cost: Currency;
    Percentage: Double;

    // Compatibility aliases used by legacy FMX frames.
    ModelName: string;
  end;
  TAipexModelUsages = TArray<TAipexModelUsage>;

  /// <summary>API call record</summary>
  TAipexApiCall = record
    CallId: string;
    Model: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    Duration: Integer;
    Cost: Currency;
    CreatedAt: TDateTime;
    Status: string;

    // Compatibility aliases used by legacy FMX frames.
    ModelName: string;
    CalledAt: TDateTime;
    TotalTokens: Integer;
  end;
  TAipexApiCalls = TArray<TAipexApiCall>;
  TAipexRecentCall = TAipexApiCall;

  /// <summary>Usage statistics summary</summary>
  TAipexUsageSummary = record
    TotalCalls: Int64;
    InputTokens: Int64;
    OutputTokens: Int64;
    TotalCost: Currency;
    PeriodStart: TDateTime;
    PeriodEnd: TDateTime;

    // Compatibility fields used by legacy FMX frames.
    TotalInputTokens: Int64;
    TotalOutputTokens: Int64;
    ModelUsage: TAipexModelUsages;
    RecentCalls: TAipexApiCalls;
  end;

  /// <summary>Invoice/Billing record</summary>
  TAipexInvoice = record
    InvoiceId: string;
    InvoiceNo: string;
    PeriodStart: TDateTime;
    PeriodEnd: TDateTime;
    Amount: Currency;
    Status: string;
    InvoiceUrl: string;
    CreatedAt: TDateTime;
  end;
  TAipexInvoices = TArray<TAipexInvoice>;

  /// <summary>Login response</summary>
  TAipexLoginResult = record
    Success: Boolean;
    AccessToken: string;
    RefreshToken: string;
    ExpiresIn: Integer;
    User: TAipexUser;
    ErrorMessage: string;
  end;

  /// <summary>Generic API response</summary>
  TAipexApiResponse = record
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;
    Data: TJSONValue;
  end;

  /// <summary>AipexBase API Client</summary>
  TAipexBaseClient = class
  private
    FBaseURL: string;
    FAccessToken: string;
    FRefreshToken: string;
    FHttpClient: THTTPClient;
    FTimeout: Integer;
    FCurrentUser: TAipexUser;
    FOnTokenRefreshed: TProc<string, string>;

    procedure SetupHeaders;
    function DoGet(const AEndpoint: string): string;
    function DoPost(const AEndpoint: string; const ABody: string): string;
    function DoPut(const AEndpoint: string; const ABody: string): string;
    function DoDelete(const AEndpoint: string): string;
    procedure HandleHttpError(StatusCode: Integer; const ResponseBody: string);
    function ParseJsonResponse(const AJson: string): TAipexApiResponse;

  public
    constructor Create(const ABaseURL: string);
    destructor Destroy; override;

    function Login(const AUsername, APassword: string; ARememberMe: Boolean = False): TAipexLoginResult;
    function Register(const AUsername, AEmail, APassword, AConfirmPassword: string): TAipexLoginResult;
    function ForgotPassword(const AEmail: string): Boolean;
    function ResetPassword(const AToken, ANewPassword: string): Boolean;
    function RefreshAccessToken: Boolean;
    procedure Logout;
    function IsLoggedIn: Boolean;

    function GetUserInfo: TAipexUser;
    function GetProfile: TAipexUser;
    function UpdateProfile(const AUsername, APhone: string): Boolean; overload;
    function UpdateProfile(const ARequest: TAipexUserUpdateRequest): Boolean; overload;
    function ChangePassword(const AOldPassword, ANewPassword: string): Boolean;
    function UploadAvatar(AStream: TStream): string;

    function GetBalance: TAipexBalance;
    function GetRechargeOptions: TAipexRechargeOptions;
    function CreateRechargeOrder(AAmount: Currency; const APaymentMethod: string): string;
    function CreateRecharge(AAmount: Currency; const APaymentMethod: string): string;
    function GetTransactions(APage, APageSize: Integer): TAipexTransactions;

    function GetUsageSummary(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
    function GetUsageTrend(AStartDate, AEndDate: TDateTime; const AGroupBy: string = 'day'): TAipexUsageDataPoints;
    function GetDailyUsage(AStartDate, AEndDate: TDateTime): TArray<TAipexDailyUsage>;
    function GetUsageStats(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
    function GetModelUsage(AStartDate, AEndDate: TDateTime): TAipexModelUsages;
    function GetRecentCalls(ALimit: Integer = 20): TAipexApiCalls;

    function GetInvoices(APage, APageSize: Integer; const AStatus: string = ''): TAipexInvoices; overload;
    function GetInvoices(const AStatus, AMonth: string; APage, APageSize: Integer): TAipexInvoices; overload;
    function RequestInvoice(const AInvoiceId: string): Boolean;
    function DownloadInvoice(const AInvoiceId: string; AStream: TStream): Boolean;

    property BaseURL: string read FBaseURL write FBaseURL;
    property AccessToken: string read FAccessToken write FAccessToken;
    property RefreshToken: string read FRefreshToken write FRefreshToken;
    property Timeout: Integer read FTimeout write FTimeout;
    property CurrentUser: TAipexUser read FCurrentUser;
    property OnTokenRefreshed: TProc<string, string> read FOnTokenRefreshed write FOnTokenRefreshed;
  end;

implementation

{ EAipexBaseError }

constructor EAipexBaseError.Create(const AMessage: string; AStatusCode: Integer;
  const AErrorCode: string);
begin
  inherited Create(AMessage);
  StatusCode := AStatusCode;
  ErrorCode := AErrorCode;
end;

{ TAipexUser }

procedure TAipexUser.Clear;
begin
  UserId := 0;
  Username := '';
  Email := '';
  Phone := '';
  Avatar := '';
  CreatedAt := 0;
  LastLoginAt := 0;
  Status := '';
  Nickname := '';
  Bio := '';
  TwoFactorEnabled := False;
end;

{ TAipexBalance }

procedure TAipexBalance.Clear;
begin
  Balance := 0;
  Currency := 'CNY';
  FrozenAmount := 0;
  AvailableAmount := 0;
  SetLength(RecentTransactions, 0);
end;

{ TAipexBaseClient }

constructor TAipexBaseClient.Create(const ABaseURL: string);
begin
  inherited Create;
  FBaseURL := ABaseURL.TrimRight(['/']);
  FTimeout := 30000;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
  FCurrentUser.Clear;
end;

destructor TAipexBaseClient.Destroy;
begin
  FreeAndNil(FHttpClient);
  inherited;
end;

procedure TAipexBaseClient.SetupHeaders;
begin
  FHttpClient.CustomHeaders['Content-Type'] := 'application/json';
  FHttpClient.CustomHeaders['Accept'] := 'application/json';
  if FAccessToken <> '' then
    FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAccessToken;
end;

function TAipexBaseClient.DoGet(const AEndpoint: string): string;
var
  Response: IHTTPResponse;
begin
  SetupHeaders;
  Response := FHttpClient.Get(FBaseURL + AEndpoint);
  if Response.StatusCode >= 400 then
    HandleHttpError(Response.StatusCode, Response.ContentAsString);
  Result := Response.ContentAsString;
end;

function TAipexBaseClient.DoPost(const AEndpoint: string; const ABody: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  SetupHeaders;
  Content := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Response := FHttpClient.Post(FBaseURL + AEndpoint, Content);
    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);
    Result := Response.ContentAsString;
  finally
    Content.Free;
  end;
end;

function TAipexBaseClient.DoPut(const AEndpoint: string; const ABody: string): string;
var
  Response: IHTTPResponse;
  Content: TStringStream;
begin
  SetupHeaders;
  Content := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    Response := FHttpClient.Put(FBaseURL + AEndpoint, Content);
    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);
    Result := Response.ContentAsString;
  finally
    Content.Free;
  end;
end;

function TAipexBaseClient.DoDelete(const AEndpoint: string): string;
var
  Response: IHTTPResponse;
begin
  SetupHeaders;
  Response := FHttpClient.Delete(FBaseURL + AEndpoint);
  if Response.StatusCode >= 400 then
    HandleHttpError(Response.StatusCode, Response.ContentAsString);
  Result := Response.ContentAsString;
end;

procedure TAipexBaseClient.HandleHttpError(StatusCode: Integer; const ResponseBody: string);
var
  Json: TJSONObject;
  ErrorMsg, ErrorCode: string;
begin
  ErrorMsg := 'HTTP Error ' + IntToStr(StatusCode);
  ErrorCode := '';

  try
    Json := TJSONObject.ParseJSONValue(ResponseBody) as TJSONObject;
    if Assigned(Json) then
    try
      Json.TryGetValue<string>('message', ErrorMsg);
      Json.TryGetValue<string>('error_code', ErrorCode);
    finally
      Json.Free;
    end;
  except
    // Ignore JSON parse errors.
  end;

  case StatusCode of
    400: raise EAipexBaseValidationError.Create(ErrorMsg, StatusCode, ErrorCode);
    401: raise EAipexBaseAuthError.Create(ErrorMsg, StatusCode, ErrorCode);
    404: raise EAipexBaseNotFoundError.Create(ErrorMsg, StatusCode, ErrorCode);
  else
    raise EAipexBaseError.Create(ErrorMsg, StatusCode, ErrorCode);
  end;
end;

function TAipexBaseClient.ParseJsonResponse(const AJson: string): TAipexApiResponse;
var
  Json: TJSONObject;
begin
  Result.Success := False;
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
  Result.Data := nil;

  Json := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if Assigned(Json) then
  try
    Json.TryGetValue<Boolean>('success', Result.Success);
    Json.TryGetValue<string>('error_code', Result.ErrorCode);
    Json.TryGetValue<string>('message', Result.ErrorMessage);
    Result.Data := Json.GetValue('data');
    if Assigned(Result.Data) then
      Result.Data := Result.Data.Clone as TJSONValue;
  finally
    Json.Free;
  end;
end;

function TAipexBaseClient.Login(const AUsername, APassword: string; ARememberMe: Boolean): TAipexLoginResult;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
  UserObj: TJSONObject;
begin
  Result.Success := False;
  Result.ErrorMessage := '';

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('password', APassword);
    ReqBody.AddPair('remember_me', TJSONBool.Create(ARememberMe));

    Response := ParseJsonResponse(DoPost('/api/auth/login', ReqBody.ToString));
    Result.Success := Response.Success;
    Result.ErrorMessage := Response.ErrorMessage;

    if Response.Success and Assigned(Response.Data) then
    begin
      if Response.Data is TJSONObject then
      begin
        TJSONObject(Response.Data).TryGetValue<string>('access_token', Result.AccessToken);
        TJSONObject(Response.Data).TryGetValue<string>('refresh_token', Result.RefreshToken);
        TJSONObject(Response.Data).TryGetValue<Integer>('expires_in', Result.ExpiresIn);

        FAccessToken := Result.AccessToken;
        FRefreshToken := Result.RefreshToken;

        if TJSONObject(Response.Data).TryGetValue<TJSONObject>('user', UserObj) then
        begin
          UserObj.TryGetValue<Integer>('user_id', Result.User.UserId);
          UserObj.TryGetValue<string>('username', Result.User.Username);
          UserObj.TryGetValue<string>('email', Result.User.Email);
          UserObj.TryGetValue<string>('phone', Result.User.Phone);
          UserObj.TryGetValue<string>('avatar', Result.User.Avatar);
          UserObj.TryGetValue<string>('status', Result.User.Status);
          UserObj.TryGetValue<string>('nickname', Result.User.Nickname);
          UserObj.TryGetValue<string>('bio', Result.User.Bio);
          UserObj.TryGetValue<Boolean>('two_factor_enabled', Result.User.TwoFactorEnabled);
          FCurrentUser := Result.User;
        end;
      end;
      Response.Data.Free;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.Register(const AUsername, AEmail, APassword, AConfirmPassword: string): TAipexLoginResult;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  Result.Success := False;
  Result.ErrorMessage := '';

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('email', AEmail);
    ReqBody.AddPair('password', APassword);
    ReqBody.AddPair('confirm_password', AConfirmPassword);

    Response := ParseJsonResponse(DoPost('/api/auth/register', ReqBody.ToString));
    Result.Success := Response.Success;
    Result.ErrorMessage := Response.ErrorMessage;

    if Response.Success and Assigned(Response.Data) then
    begin
      if Response.Data is TJSONObject then
      begin
        TJSONObject(Response.Data).TryGetValue<string>('access_token', Result.AccessToken);
        TJSONObject(Response.Data).TryGetValue<string>('refresh_token', Result.RefreshToken);
        FAccessToken := Result.AccessToken;
        FRefreshToken := Result.RefreshToken;
      end;
      Response.Data.Free;
    end;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ForgotPassword(const AEmail: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('email', AEmail);
    Response := ParseJsonResponse(DoPost('/api/auth/forgot-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ResetPassword(const AToken, ANewPassword: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('token', AToken);
    ReqBody.AddPair('new_password', ANewPassword);
    Response := ParseJsonResponse(DoPost('/api/auth/reset-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.RefreshAccessToken: Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
  NewAccessToken, NewRefreshToken: string;
begin
  Result := False;
  if FRefreshToken = '' then
    Exit;

  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('refresh_token', FRefreshToken);
    Response := ParseJsonResponse(DoPost('/api/auth/refresh', ReqBody.ToString));

    if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
    begin
      TJSONObject(Response.Data).TryGetValue<string>('access_token', NewAccessToken);
      TJSONObject(Response.Data).TryGetValue<string>('refresh_token', NewRefreshToken);

      FAccessToken := NewAccessToken;
      if NewRefreshToken <> '' then
        FRefreshToken := NewRefreshToken;

      if Assigned(FOnTokenRefreshed) then
        FOnTokenRefreshed(FAccessToken, FRefreshToken);

      Result := True;
    end;

    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

procedure TAipexBaseClient.Logout;
begin
  try
    DoPost('/api/auth/logout', '{}');
  except
    // Ignore errors on logout.
  end;
  FAccessToken := '';
  FRefreshToken := '';
  FCurrentUser.Clear;
end;

function TAipexBaseClient.IsLoggedIn: Boolean;
begin
  Result := FAccessToken <> '';
end;

function TAipexBaseClient.GetUserInfo: TAipexUser;
var
  Response: TAipexApiResponse;
  UserObj: TJSONObject;
begin
  Result.Clear;
  Response := ParseJsonResponse(DoGet('/api/user/profile'));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    UserObj := TJSONObject(Response.Data);
    UserObj.TryGetValue<Integer>('user_id', Result.UserId);
    UserObj.TryGetValue<string>('username', Result.Username);
    UserObj.TryGetValue<string>('email', Result.Email);
    UserObj.TryGetValue<string>('phone', Result.Phone);
    UserObj.TryGetValue<string>('avatar', Result.Avatar);
    UserObj.TryGetValue<string>('status', Result.Status);
    UserObj.TryGetValue<string>('nickname', Result.Nickname);
    UserObj.TryGetValue<string>('bio', Result.Bio);
    UserObj.TryGetValue<Boolean>('two_factor_enabled', Result.TwoFactorEnabled);
    FCurrentUser := Result;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetProfile: TAipexUser;
begin
  Result := GetUserInfo;
end;

function TAipexBaseClient.UpdateProfile(const AUsername, APhone: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('username', AUsername);
    ReqBody.AddPair('phone', APhone);
    Response := ParseJsonResponse(DoPut('/api/user/profile', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.UpdateProfile(const ARequest: TAipexUserUpdateRequest): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('nickname', ARequest.Nickname);
    ReqBody.AddPair('phone', ARequest.Phone);
    ReqBody.AddPair('bio', ARequest.Bio);
    Response := ParseJsonResponse(DoPut('/api/user/profile', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.ChangePassword(const AOldPassword, ANewPassword: string): Boolean;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('old_password', AOldPassword);
    ReqBody.AddPair('new_password', ANewPassword);
    Response := ParseJsonResponse(DoPost('/api/user/change-password', ReqBody.ToString));
    Result := Response.Success;
    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.UploadAvatar(AStream: TStream): string;
var
  Response: IHTTPResponse;
  FormData: TMultipartFormData;
  ApiResponse: TAipexApiResponse;
begin
  Result := '';
  SetupHeaders;

  FormData := TMultipartFormData.Create;
  try
    FormData.AddStream('avatar', AStream, 'avatar.png', 'image/png');
    Response := FHttpClient.Post(FBaseURL + '/api/user/avatar', FormData);

    if Response.StatusCode >= 400 then
      HandleHttpError(Response.StatusCode, Response.ContentAsString);

    ApiResponse := ParseJsonResponse(Response.ContentAsString);
    if ApiResponse.Success and Assigned(ApiResponse.Data) and (ApiResponse.Data is TJSONObject) then
      TJSONObject(ApiResponse.Data).TryGetValue<string>('avatar_url', Result);
    if Assigned(ApiResponse.Data) then
      ApiResponse.Data.Free;
  finally
    FormData.Free;
  end;
end;

function TAipexBaseClient.GetBalance: TAipexBalance;
var
  Response: TAipexApiResponse;
  DataObj: TJSONObject;
begin
  Result.Clear;
  Response := ParseJsonResponse(DoGet('/api/billing/balance'));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    DataObj := TJSONObject(Response.Data);
    DataObj.TryGetValue<Currency>('balance', Result.Balance);
    DataObj.TryGetValue<string>('currency', Result.Currency);
    DataObj.TryGetValue<Currency>('frozen_amount', Result.FrozenAmount);
    DataObj.TryGetValue<Currency>('available_amount', Result.AvailableAmount);
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetRechargeOptions: TAipexRechargeOptions;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet('/api/billing/recharge-options'));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<Currency>('amount', Result[I].Amount);
      Item.TryGetValue<Currency>('bonus', Result[I].Bonus);
      Item.TryGetValue<string>('description', Result[I].Description);
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.CreateRechargeOrder(AAmount: Currency; const APaymentMethod: string): string;
var
  ReqBody: TJSONObject;
  Response: TAipexApiResponse;
begin
  Result := '';
  ReqBody := TJSONObject.Create;
  try
    ReqBody.AddPair('amount', TJSONNumber.Create(AAmount));
    ReqBody.AddPair('payment_method', APaymentMethod);
    Response := ParseJsonResponse(DoPost('/api/billing/recharge', ReqBody.ToString));

    if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
      TJSONObject(Response.Data).TryGetValue<string>('payment_url', Result);

    if Assigned(Response.Data) then
      Response.Data.Free;
  finally
    ReqBody.Free;
  end;
end;

function TAipexBaseClient.CreateRecharge(AAmount: Currency; const APaymentMethod: string): string;
begin
  Result := CreateRechargeOrder(AAmount, APaymentMethod);
end;

function TAipexBaseClient.GetTransactions(APage, APageSize: Integer): TAipexTransactions;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/billing/transactions?page=%d&page_size=%d', [APage, APageSize])));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    if TJSONObject(Response.Data).TryGetValue<TJSONArray>('items', Arr) then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        Item.TryGetValue<string>('transaction_id', Result[I].TransactionId);
        Item.TryGetValue<string>('type', Result[I].TransactionType);
        Item.TryGetValue<Currency>('amount', Result[I].Amount);
        Item.TryGetValue<Currency>('balance', Result[I].Balance);
        Item.TryGetValue<string>('description', Result[I].Description);
        Item.TryGetValue<string>('status', Result[I].Status);
        if Item.TryGetValue<string>('created_at', DateStr) then
          Result[I].CreatedAt := ISO8601ToDate(DateStr);
      end;
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetUsageSummary(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
var
  Response: TAipexApiResponse;
  DataObj: TJSONObject;
begin
  Result := Default(TAipexUsageSummary);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/summary?start=%s&end=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate)])));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    DataObj := TJSONObject(Response.Data);
    DataObj.TryGetValue<Int64>('total_calls', Result.TotalCalls);
    DataObj.TryGetValue<Int64>('input_tokens', Result.InputTokens);
    DataObj.TryGetValue<Int64>('output_tokens', Result.OutputTokens);
    DataObj.TryGetValue<Currency>('total_cost', Result.TotalCost);
    Result.TotalInputTokens := Result.InputTokens;
    Result.TotalOutputTokens := Result.OutputTokens;
    Result.PeriodStart := AStartDate;
    Result.PeriodEnd := AEndDate;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetUsageTrend(AStartDate, AEndDate: TDateTime; const AGroupBy: string): TAipexUsageDataPoints;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/trend?start=%s&end=%s&group_by=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate), AGroupBy])));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      if Item.TryGetValue<string>('date', DateStr) then
        Result[I].Date := StrToDateDef(DateStr, 0);
      Item.TryGetValue<Int64>('calls', Result[I].Calls);
      Item.TryGetValue<Int64>('input_tokens', Result[I].InputTokens);
      Item.TryGetValue<Int64>('output_tokens', Result[I].OutputTokens);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetDailyUsage(AStartDate, AEndDate: TDateTime): TArray<TAipexDailyUsage>;
begin
  Result := GetUsageTrend(AStartDate, AEndDate, 'day');
end;

function TAipexBaseClient.GetUsageStats(AStartDate, AEndDate: TDateTime): TAipexUsageSummary;
begin
  Result := GetUsageSummary(AStartDate, AEndDate);
  Result.ModelUsage := GetModelUsage(AStartDate, AEndDate);
  Result.RecentCalls := GetRecentCalls(20);
end;

function TAipexBaseClient.GetModelUsage(AStartDate, AEndDate: TDateTime): TAipexModelUsages;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/models?start=%s&end=%s',
    [FormatDateTime('yyyy-mm-dd', AStartDate), FormatDateTime('yyyy-mm-dd', AEndDate)])));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<string>('model', Result[I].Model);
      Item.TryGetValue<Int64>('calls', Result[I].Calls);
      Item.TryGetValue<Int64>('tokens', Result[I].Tokens);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
      Item.TryGetValue<Double>('percentage', Result[I].Percentage);
      Result[I].ModelName := Result[I].Model;
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetRecentCalls(ALimit: Integer): TAipexApiCalls;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
begin
  SetLength(Result, 0);
  Response := ParseJsonResponse(DoGet(Format('/api/usage/calls?limit=%d', [ALimit])));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
  begin
    Arr := TJSONArray(Response.Data);
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<string>('call_id', Result[I].CallId);
      Item.TryGetValue<string>('model', Result[I].Model);
      Item.TryGetValue<Integer>('input_tokens', Result[I].InputTokens);
      Item.TryGetValue<Integer>('output_tokens', Result[I].OutputTokens);
      Item.TryGetValue<Integer>('duration', Result[I].Duration);
      Item.TryGetValue<Currency>('cost', Result[I].Cost);
      Item.TryGetValue<string>('status', Result[I].Status);
      if Item.TryGetValue<string>('created_at', DateStr) then
        Result[I].CreatedAt := ISO8601ToDate(DateStr);
      Result[I].ModelName := Result[I].Model;
      Result[I].CalledAt := Result[I].CreatedAt;
      Result[I].TotalTokens := Result[I].InputTokens + Result[I].OutputTokens;
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetInvoices(APage, APageSize: Integer; const AStatus: string): TAipexInvoices;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
  URL: string;
begin
  SetLength(Result, 0);
  URL := Format('/api/billing/invoices?page=%d&page_size=%d', [APage, APageSize]);
  if AStatus <> '' then
    URL := URL + '&status=' + TNetEncoding.URL.Encode(AStatus);

  Response := ParseJsonResponse(DoGet(URL));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) then
  begin
    if TJSONObject(Response.Data).TryGetValue<TJSONArray>('items', Arr) then
    begin
      SetLength(Result, Arr.Count);
      for I := 0 to Arr.Count - 1 do
      begin
        Item := Arr.Items[I] as TJSONObject;
        Item.TryGetValue<string>('invoice_id', Result[I].InvoiceId);
        Item.TryGetValue<string>('invoice_no', Result[I].InvoiceNo);
        Item.TryGetValue<Currency>('amount', Result[I].Amount);
        Item.TryGetValue<string>('status', Result[I].Status);
        Item.TryGetValue<string>('invoice_url', Result[I].InvoiceUrl);
        if Item.TryGetValue<string>('period_start', DateStr) then
          Result[I].PeriodStart := ISO8601ToDate(DateStr);
        if Item.TryGetValue<string>('period_end', DateStr) then
          Result[I].PeriodEnd := ISO8601ToDate(DateStr);
        if Item.TryGetValue<string>('created_at', DateStr) then
          Result[I].CreatedAt := ISO8601ToDate(DateStr);
      end;
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.GetInvoices(const AStatus, AMonth: string; APage, APageSize: Integer): TAipexInvoices;
var
  Response: TAipexApiResponse;
  Arr: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  DateStr: string;
  URL: string;
begin
  SetLength(Result, 0);
  URL := Format('/api/billing/invoices?page=%d&page_size=%d', [APage, APageSize]);
  if AStatus <> '' then
    URL := URL + '&status=' + TNetEncoding.URL.Encode(AStatus);
  if AMonth <> '' then
    URL := URL + '&month=' + TNetEncoding.URL.Encode(AMonth);

  Response := ParseJsonResponse(DoGet(URL));

  if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONArray) then
    Arr := TJSONArray(Response.Data)
  else if Response.Success and Assigned(Response.Data) and (Response.Data is TJSONObject) and
    TJSONObject(Response.Data).TryGetValue<TJSONArray>('items', Arr) then
  else
    Arr := nil;

  if Arr <> nil then
  begin
    SetLength(Result, Arr.Count);
    for I := 0 to Arr.Count - 1 do
    begin
      Item := Arr.Items[I] as TJSONObject;
      Item.TryGetValue<string>('invoice_id', Result[I].InvoiceId);
      Item.TryGetValue<string>('invoice_no', Result[I].InvoiceNo);
      Item.TryGetValue<Currency>('amount', Result[I].Amount);
      Item.TryGetValue<string>('status', Result[I].Status);
      Item.TryGetValue<string>('invoice_url', Result[I].InvoiceUrl);
      if Item.TryGetValue<string>('period_start', DateStr) then
        Result[I].PeriodStart := ISO8601ToDate(DateStr);
      if Item.TryGetValue<string>('period_end', DateStr) then
        Result[I].PeriodEnd := ISO8601ToDate(DateStr);
      if Item.TryGetValue<string>('created_at', DateStr) then
        Result[I].CreatedAt := ISO8601ToDate(DateStr);
    end;
  end;

  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.RequestInvoice(const AInvoiceId: string): Boolean;
var
  Response: TAipexApiResponse;
begin
  Response := ParseJsonResponse(DoPost('/api/billing/invoices/' + AInvoiceId + '/request', '{}'));
  Result := Response.Success;
  if Assigned(Response.Data) then
    Response.Data.Free;
end;

function TAipexBaseClient.DownloadInvoice(const AInvoiceId: string; AStream: TStream): Boolean;
var
  Response: IHTTPResponse;
begin
  Result := False;
  SetupHeaders;

  Response := FHttpClient.Get(FBaseURL + '/api/billing/invoices/' + AInvoiceId + '/download');
  if Response.StatusCode = 200 then
  begin
    AStream.CopyFrom(Response.ContentStream, 0);
    Result := True;
  end;
end;

end.
