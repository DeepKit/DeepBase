unit UniBase.AipexBase.Factory;

interface

uses
  UniBase.AipexBase.Client,
  UniBase.AipexBase.GeneralOrder;

type
  TAipexBaseFactory = class
  public
    class function CreateClient(const ABaseURL: string;
      const AAccessToken: string = '';
      const ARefreshToken: string = ''): TAipexBaseClient; static;

    class function CreateGeneralOrderClientByAppId(const ABaseURL, AAppId: string;
      const ABearerToken: string = '';
      const AAppType: string = 'user'): TAipexGeneralOrderClient; static;

    class function CreateGeneralOrderClientByApiKey(const ABaseURL, ACodeFlying: string;
      const ABearerToken: string = '';
      const AAppType: string = 'user'): TAipexGeneralOrderClient; static;
  end;

implementation

class function TAipexBaseFactory.CreateClient(const ABaseURL, AAccessToken,
  ARefreshToken: string): TAipexBaseClient;
begin
  Result := TAipexBaseClient.Create(ABaseURL);
  Result.AccessToken := AAccessToken;
  Result.RefreshToken := ARefreshToken;
end;

class function TAipexBaseFactory.CreateGeneralOrderClientByAppId(
  const ABaseURL, AAppId, ABearerToken, AAppType: string): TAipexGeneralOrderClient;
var
  Auth: TAipexBaseAuth;
begin
  Auth := TAipexBaseAuth.ForAppId(AAppId, ABearerToken, AAppType);
  Result := TAipexGeneralOrderClient.Create(ABaseURL, Auth);
end;

class function TAipexBaseFactory.CreateGeneralOrderClientByApiKey(
  const ABaseURL, ACodeFlying, ABearerToken, AAppType: string): TAipexGeneralOrderClient;
var
  Auth: TAipexBaseAuth;
begin
  Auth := TAipexBaseAuth.ForApiKey(ACodeFlying, ABearerToken, AAppType);
  Result := TAipexGeneralOrderClient.Create(ABaseURL, Auth);
end;

end.
