unit DeepFlow.Skill.Client;

interface

uses
  System.SysUtils, System.Classes, System.Net.HttpClient, System.JSON;

type
  TSkillClient = class
  private
    FHttpClient: THTTPClient;
    FBaseUrl: string;
  public
    constructor Create(const ABaseUrl: string = 'http://127.0.0.1:8000');
    destructor Destroy; override;
    function ExecuteSkill(const ASkillName: string; AInput: TJSONObject): TJSONObject;
  end;

implementation

{ TSkillClient }

constructor TSkillClient.Create(const ABaseUrl: string);
begin
  FHttpClient := THTTPClient.Create;
  FBaseUrl := ABaseUrl;
end;

destructor TSkillClient.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TSkillClient.ExecuteSkill(const ASkillName: string; AInput: TJSONObject): TJSONObject;
var
  LRequestBody: TJSONObject;
  LResponse: IHTTPResponse;
  LContentStream: TStringStream;
begin
  LRequestBody := TJSONObject.Create;
  try
    LRequestBody.AddPair('skill_name', ASkillName);
    LRequestBody.AddPair('input_data', AInput.Clone as TJSONObject);
    
    LContentStream := TStringStream.Create(LRequestBody.ToJSON, TEncoding.UTF8);
    try
      LResponse := FHttpClient.Post(FBaseUrl + '/execute', LContentStream, nil, [TNameValuePair.Create('Content-Type', 'application/json')]);
      Result := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
    finally
      LContentStream.Free;
    end;
  finally
    LRequestBody.Free;
  end;
end;

end.
