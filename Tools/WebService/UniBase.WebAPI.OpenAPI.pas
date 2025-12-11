{*******************************************************}
{                                                       }
{       UniBase Framework                               }
{       OpenAPI / Swagger Documentation Generator       }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit UniBase.WebAPI.OpenAPI;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Rtti,
  System.TypInfo,
  UniBase.WebAPI.Core;

type
  // OpenAPI 数据类型
  TOpenApiDataType = (odtString, odtInteger, odtNumber, odtBoolean, odtArray, odtObject);

  // 参数位置
  TParameterLocation = (plPath, plQuery, plHeader, plCookie);

  // 前置声明
  TOpenApiSchema = class;
  TOpenApiParameter = class;
  TOpenApiRequestBody = class;
  TOpenApiResponse = class;
  TOpenApiOperation = class;
  TOpenApiPathItem = class;
  TOpenApiDocument = class;
  TOpenApiGenerator = class;

  // Schema 定义
  TOpenApiSchema = class
  private
    FType: TOpenApiDataType;
    FFormat: string;
    FTitle: string;
    FDescription: string;
    FDefault: TJSONValue;
    FEnum: TStringList;
    FMinimum: Double;
    FMaximum: Double;
    FMinLength: Integer;
    FMaxLength: Integer;
    FPattern: string;
    FItems: TOpenApiSchema;
    FProperties: TObjectDictionary<string, TOpenApiSchema>;
    FRequired: TStringList;
    FRef: string;
    FNullable: Boolean;
    FExample: TJSONValue;
  public
    constructor Create;
    destructor Destroy; override;

    property DataType: TOpenApiDataType read FType write FType;
    property Format: string read FFormat write FFormat;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property DefaultValue: TJSONValue read FDefault write FDefault;
    property Enum: TStringList read FEnum;
    property Minimum: Double read FMinimum write FMinimum;
    property Maximum: Double read FMaximum write FMaximum;
    property MinLength: Integer read FMinLength write FMinLength;
    property MaxLength: Integer read FMaxLength write FMaxLength;
    property Pattern: string read FPattern write FPattern;
    property Items: TOpenApiSchema read FItems write FItems;
    property Properties: TObjectDictionary<string, TOpenApiSchema> read FProperties;
    property Required: TStringList read FRequired;
    property Ref: string read FRef write FRef;
    property Nullable: Boolean read FNullable write FNullable;
    property Example: TJSONValue read FExample write FExample;

    function ToJSON: TJSONObject;
    function AddProperty(const AName: string): TOpenApiSchema;
    procedure AddRequired(const AName: string);

    class function CreateString(const ADesc: string = ''): TOpenApiSchema;
    class function CreateInteger(const ADesc: string = ''): TOpenApiSchema;
    class function CreateNumber(const ADesc: string = ''): TOpenApiSchema;
    class function CreateBoolean(const ADesc: string = ''): TOpenApiSchema;
    class function CreateArray(AItems: TOpenApiSchema): TOpenApiSchema;
    class function CreateObject: TOpenApiSchema;
    class function CreateRef(const ARef: string): TOpenApiSchema;
  end;

  // 参数定义
  TOpenApiParameter = class
  private
    FName: string;
    FIn: TParameterLocation;
    FDescription: string;
    FRequired: Boolean;
    FDeprecated: Boolean;
    FSchema: TOpenApiSchema;
    FExample: TJSONValue;
  public
    constructor Create;
    destructor Destroy; override;

    property Name: string read FName write FName;
    property Location: TParameterLocation read FIn write FIn;
    property Description: string read FDescription write FDescription;
    property Required: Boolean read FRequired write FRequired;
    property Deprecated: Boolean read FDeprecated write FDeprecated;
    property Schema: TOpenApiSchema read FSchema write FSchema;
    property Example: TJSONValue read FExample write FExample;

    function ToJSON: TJSONObject;

    class function CreatePath(const AName, ADesc: string): TOpenApiParameter;
    class function CreateQuery(const AName, ADesc: string; ARequired: Boolean = False): TOpenApiParameter;
    class function CreateHeader(const AName, ADesc: string; ARequired: Boolean = False): TOpenApiParameter;
  end;

  // 请求体定义
  TOpenApiRequestBody = class
  private
    FDescription: string;
    FRequired: Boolean;
    FContent: TObjectDictionary<string, TOpenApiSchema>;
  public
    constructor Create;
    destructor Destroy; override;

    property Description: string read FDescription write FDescription;
    property Required: Boolean read FRequired write FRequired;
    property Content: TObjectDictionary<string, TOpenApiSchema> read FContent;

    function ToJSON: TJSONObject;
    procedure AddContent(const AMediaType: string; ASchema: TOpenApiSchema);

    class function CreateJSON(ASchema: TOpenApiSchema; const ADesc: string = ''): TOpenApiRequestBody;
  end;

  // 响应定义
  TOpenApiResponse = class
  private
    FDescription: string;
    FContent: TObjectDictionary<string, TOpenApiSchema>;
    FHeaders: TObjectDictionary<string, TOpenApiSchema>;
  public
    constructor Create;
    destructor Destroy; override;

    property Description: string read FDescription write FDescription;
    property Content: TObjectDictionary<string, TOpenApiSchema> read FContent;
    property Headers: TObjectDictionary<string, TOpenApiSchema> read FHeaders;

    function ToJSON: TJSONObject;
    procedure AddContent(const AMediaType: string; ASchema: TOpenApiSchema);
    procedure AddHeader(const AName: string; ASchema: TOpenApiSchema);

    class function CreateSuccess(const ADesc: string = 'Successful response'): TOpenApiResponse;
    class function CreateJSON(ASchema: TOpenApiSchema; const ADesc: string = 'Successful response'): TOpenApiResponse;
    class function CreateError(const ADesc: string): TOpenApiResponse;
  end;

  // 安全要求
  TOpenApiSecurityScheme = class
  private
    FType: string;
    FScheme: string;
    FBearerFormat: string;
    FName: string;
    FIn: string;
    FDescription: string;
  public
    property SecurityType: string read FType write FType;
    property Scheme: string read FScheme write FScheme;
    property BearerFormat: string read FBearerFormat write FBearerFormat;
    property Name: string read FName write FName;
    property Location: string read FIn write FIn;
    property Description: string read FDescription write FDescription;

    function ToJSON: TJSONObject;

    class function CreateBearer(const ADesc: string = ''): TOpenApiSecurityScheme;
    class function CreateApiKey(const AName, ALocation, ADesc: string): TOpenApiSecurityScheme;
    class function CreateBasic(const ADesc: string = ''): TOpenApiSecurityScheme;
  end;

  // 操作定义
  TOpenApiOperation = class
  private
    FOperationId: string;
    FSummary: string;
    FDescription: string;
    FTags: TStringList;
    FParameters: TObjectList<TOpenApiParameter>;
    FRequestBody: TOpenApiRequestBody;
    FResponses: TObjectDictionary<string, TOpenApiResponse>;
    FDeprecated: Boolean;
    FSecurity: TList<TStringList>;
    FExternalDocs: string;
  public
    constructor Create;
    destructor Destroy; override;

    property OperationId: string read FOperationId write FOperationId;
    property Summary: string read FSummary write FSummary;
    property Description: string read FDescription write FDescription;
    property Tags: TStringList read FTags;
    property Parameters: TObjectList<TOpenApiParameter> read FParameters;
    property RequestBody: TOpenApiRequestBody read FRequestBody write FRequestBody;
    property Responses: TObjectDictionary<string, TOpenApiResponse> read FResponses;
    property Deprecated: Boolean read FDeprecated write FDeprecated;
    property Security: TList<TStringList> read FSecurity;
    property ExternalDocs: string read FExternalDocs write FExternalDocs;

    function ToJSON: TJSONObject;
    function AddParameter(AParam: TOpenApiParameter): TOpenApiOperation;
    function AddResponse(const AStatusCode: string; AResponse: TOpenApiResponse): TOpenApiOperation;
    function AddTag(const ATag: string): TOpenApiOperation;
    function SetSecurity(const ASchemes: array of string): TOpenApiOperation;
  end;

  // 路径项定义
  TOpenApiPathItem = class
  private
    FGet: TOpenApiOperation;
    FPost: TOpenApiOperation;
    FPut: TOpenApiOperation;
    FPatch: TOpenApiOperation;
    FDelete: TOpenApiOperation;
    FOptions: TOpenApiOperation;
    FHead: TOpenApiOperation;
    FSummary: string;
    FDescription: string;
    FParameters: TObjectList<TOpenApiParameter>;
  public
    constructor Create;
    destructor Destroy; override;

    property Get: TOpenApiOperation read FGet write FGet;
    property Post: TOpenApiOperation read FPost write FPost;
    property Put: TOpenApiOperation read FPut write FPut;
    property Patch: TOpenApiOperation read FPatch write FPatch;
    property Delete: TOpenApiOperation read FDelete write FDelete;
    property Options: TOpenApiOperation read FOptions write FOptions;
    property Head: TOpenApiOperation read FHead write FHead;
    property Summary: string read FSummary write FSummary;
    property Description: string read FDescription write FDescription;
    property Parameters: TObjectList<TOpenApiParameter> read FParameters;

    function ToJSON: TJSONObject;
    function GetOperation(AMethod: THttpMethod): TOpenApiOperation;
    procedure SetOperation(AMethod: THttpMethod; AOperation: TOpenApiOperation);
  end;

  // 标签定义
  TOpenApiTag = class
  private
    FName: string;
    FDescription: string;
    FExternalDocs: string;
  public
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property ExternalDocs: string read FExternalDocs write FExternalDocs;

    function ToJSON: TJSONObject;
  end;

  // 服务器定义
  TOpenApiServer = class
  private
    FUrl: string;
    FDescription: string;
  public
    property Url: string read FUrl write FUrl;
    property Description: string read FDescription write FDescription;

    function ToJSON: TJSONObject;
  end;

  // 联系信息
  TOpenApiContact = class
  private
    FName: string;
    FUrl: string;
    FEmail: string;
  public
    property Name: string read FName write FName;
    property Url: string read FUrl write FUrl;
    property Email: string read FEmail write FEmail;

    function ToJSON: TJSONObject;
  end;

  // 许可信息
  TOpenApiLicense = class
  private
    FName: string;
    FUrl: string;
  public
    property Name: string read FName write FName;
    property Url: string read FUrl write FUrl;

    function ToJSON: TJSONObject;
  end;

  // API 信息
  TOpenApiInfo = class
  private
    FTitle: string;
    FDescription: string;
    FVersion: string;
    FTermsOfService: string;
    FContact: TOpenApiContact;
    FLicense: TOpenApiLicense;
  public
    constructor Create;
    destructor Destroy; override;

    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Version: string read FVersion write FVersion;
    property TermsOfService: string read FTermsOfService write FTermsOfService;
    property Contact: TOpenApiContact read FContact;
    property License: TOpenApiLicense read FLicense;

    function ToJSON: TJSONObject;
  end;

  // OpenAPI 文档
  TOpenApiDocument = class
  private
    FOpenApi: string;
    FInfo: TOpenApiInfo;
    FServers: TObjectList<TOpenApiServer>;
    FPaths: TObjectDictionary<string, TOpenApiPathItem>;
    FComponents: TObjectDictionary<string, TOpenApiSchema>;
    FSecuritySchemes: TObjectDictionary<string, TOpenApiSecurityScheme>;
    FSecurity: TList<TStringList>;
    FTags: TObjectList<TOpenApiTag>;
    FExternalDocs: string;
  public
    constructor Create;
    destructor Destroy; override;

    property OpenApi: string read FOpenApi write FOpenApi;
    property Info: TOpenApiInfo read FInfo;
    property Servers: TObjectList<TOpenApiServer> read FServers;
    property Paths: TObjectDictionary<string, TOpenApiPathItem> read FPaths;
    property Components: TObjectDictionary<string, TOpenApiSchema> read FComponents;
    property SecuritySchemes: TObjectDictionary<string, TOpenApiSecurityScheme> read FSecuritySchemes;
    property Security: TList<TStringList> read FSecurity;
    property Tags: TObjectList<TOpenApiTag> read FTags;
    property ExternalDocs: string read FExternalDocs write FExternalDocs;

    function ToJSON: TJSONObject;
    function ToYAML: string;
    procedure SaveToFile(const APath: string);

    function AddServer(const AUrl, ADesc: string): TOpenApiServer;
    function AddPath(const APath: string): TOpenApiPathItem;
    function AddComponent(const AName: string; ASchema: TOpenApiSchema): TOpenApiSchema;
    function AddSecurityScheme(const AName: string; AScheme: TOpenApiSecurityScheme): TOpenApiSecurityScheme;
    function AddTag(const AName, ADesc: string): TOpenApiTag;
    procedure SetGlobalSecurity(const ASchemes: array of string);
  end;

  // API 文档生成器
  TOpenApiGenerator = class
  private
    FDocument: TOpenApiDocument;
    FRouter: TApiRouter;
    FBasePath: string;
    FAutoGenerateSchemas: Boolean;

    procedure GenerateFromRoutes;
    function ConvertRoutePattern(const APattern: string): string;
    function ExtractPathParameters(const APattern: string): TArray<string>;
    function GenerateOperationId(const AMethod: string; const APath: string): string;
  public
    constructor Create(ARouter: TApiRouter);
    destructor Destroy; override;

    property Document: TOpenApiDocument read FDocument;
    property BasePath: string read FBasePath write FBasePath;
    property AutoGenerateSchemas: Boolean read FAutoGenerateSchemas write FAutoGenerateSchemas;

    // 生成文档
    procedure Generate;

    // 配置
    procedure SetInfo(const ATitle, ADesc, AVersion: string);
    procedure SetContact(const AName, AEmail, AUrl: string);
    procedure SetLicense(const AName, AUrl: string);
    procedure AddServer(const AUrl, ADesc: string);
    procedure AddBearerAuth(const AName: string = 'bearerAuth');
    procedure AddApiKeyAuth(const AName, AHeaderName: string);

    // 获取 JSON/YAML
    function GetJSON: string;
    function GetYAML: string;
    procedure SaveToFile(const APath: string);

    // 注册 Swagger UI 路由
    procedure RegisterSwaggerUI(const ADocsPath: string = '/docs');
    procedure RegisterReDocUI(const ADocsPath: string = '/redoc');
  end;

  // Swagger UI HTML 生成
  TSwaggerUIGenerator = class
  public
    class function GenerateHTML(const ASpecUrl: string; const ATitle: string = 'API Documentation'): string;
    class function GenerateReDocHTML(const ASpecUrl: string; const ATitle: string = 'API Documentation'): string;
  end;

  // 辅助函数
  function DataTypeToString(AType: TOpenApiDataType): string;
  function ParameterLocationToString(ALocation: TParameterLocation): string;

implementation

uses
  System.IOUtils,
  System.RegularExpressions,
  System.Math;

function ExtractFirstPathSegment(const APath: string): string; forward;

{ 辅助函数 }

function DataTypeToString(AType: TOpenApiDataType): string;
begin
  case AType of
    odtString: Result := 'string';
    odtInteger: Result := 'integer';
    odtNumber: Result := 'number';
    odtBoolean: Result := 'boolean';
    odtArray: Result := 'array';
    odtObject: Result := 'object';
  else
    Result := 'string';
  end;
end;

function ParameterLocationToString(ALocation: TParameterLocation): string;
begin
  case ALocation of
    plPath: Result := 'path';
    plQuery: Result := 'query';
    plHeader: Result := 'header';
    plCookie: Result := 'cookie';
  else
    Result := 'query';
  end;
end;

{ TOpenApiSchema }

constructor TOpenApiSchema.Create;
begin
  inherited;
  FType := odtString;
  FEnum := TStringList.Create;
  FProperties := TObjectDictionary<string, TOpenApiSchema>.Create([doOwnsValues]);
  FRequired := TStringList.Create;
  FMinimum := NaN;
  FMaximum := NaN;
  FMinLength := -1;
  FMaxLength := -1;
end;

destructor TOpenApiSchema.Destroy;
begin
  FEnum.Free;
  FItems.Free;
  FProperties.Free;
  FRequired.Free;
  FDefault.Free;
  FExample.Free;
  inherited;
end;

function TOpenApiSchema.ToJSON: TJSONObject;
var
  LProps: TJSONObject;
  LPair: TPair<string, TOpenApiSchema>;
  LRequired: TJSONArray;
  LEnumArr: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    // 引用
    if FRef <> '' then
    begin
      Result.AddPair('$ref', '#/components/schemas/' + FRef);
      Exit;
    end;

    Result.AddPair('type', DataTypeToString(FType));

    if FFormat <> '' then
      Result.AddPair('format', FFormat);
    if FTitle <> '' then
      Result.AddPair('title', FTitle);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
    if FNullable then
      Result.AddPair('nullable', TJSONBool.Create(True));

    // 枚举
    if FEnum.Count > 0 then
    begin
      LEnumArr := TJSONArray.Create;
      for I := 0 to FEnum.Count - 1 do
        LEnumArr.Add(FEnum[I]);
      Result.AddPair('enum', LEnumArr);
    end;

    // 数值约束
    if not IsNaN(FMinimum) then
      Result.AddPair('minimum', TJSONNumber.Create(FMinimum));
    if not IsNaN(FMaximum) then
      Result.AddPair('maximum', TJSONNumber.Create(FMaximum));

    // 字符串约束
    if FMinLength >= 0 then
      Result.AddPair('minLength', TJSONNumber.Create(FMinLength));
    if FMaxLength >= 0 then
      Result.AddPair('maxLength', TJSONNumber.Create(FMaxLength));
    if FPattern <> '' then
      Result.AddPair('pattern', FPattern);

    // 数组项
    if (FType = odtArray) and (FItems <> nil) then
      Result.AddPair('items', FItems.ToJSON);

    // 对象属性
    if (FType = odtObject) and (FProperties.Count > 0) then
    begin
      LProps := TJSONObject.Create;
      for LPair in FProperties do
        LProps.AddPair(LPair.Key, LPair.Value.ToJSON);
      Result.AddPair('properties', LProps);

      if FRequired.Count > 0 then
      begin
        LRequired := TJSONArray.Create;
        for I := 0 to FRequired.Count - 1 do
          LRequired.Add(FRequired[I]);
        Result.AddPair('required', LRequired);
      end;
    end;

    // 默认值
    if FDefault <> nil then
      Result.AddPair('default', FDefault.Clone as TJSONValue);

    // 示例
    if FExample <> nil then
      Result.AddPair('example', FExample.Clone as TJSONValue);
  except
    Result.Free;
    raise;
  end;
end;

function TOpenApiSchema.AddProperty(const AName: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  FProperties.Add(AName, Result);
end;

procedure TOpenApiSchema.AddRequired(const AName: string);
begin
  if FRequired.IndexOf(AName) < 0 then
    FRequired.Add(AName);
end;

class function TOpenApiSchema.CreateString(const ADesc: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtString;
  Result.Description := ADesc;
end;

class function TOpenApiSchema.CreateInteger(const ADesc: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtInteger;
  Result.Format := 'int64';
  Result.Description := ADesc;
end;

class function TOpenApiSchema.CreateNumber(const ADesc: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtNumber;
  Result.Format := 'double';
  Result.Description := ADesc;
end;

class function TOpenApiSchema.CreateBoolean(const ADesc: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtBoolean;
  Result.Description := ADesc;
end;

class function TOpenApiSchema.CreateArray(AItems: TOpenApiSchema): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtArray;
  Result.Items := AItems;
end;

class function TOpenApiSchema.CreateObject: TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.DataType := odtObject;
end;

class function TOpenApiSchema.CreateRef(const ARef: string): TOpenApiSchema;
begin
  Result := TOpenApiSchema.Create;
  Result.Ref := ARef;
end;

{ TOpenApiParameter }

constructor TOpenApiParameter.Create;
begin
  inherited;
  FSchema := TOpenApiSchema.Create;
end;

destructor TOpenApiParameter.Destroy;
begin
  FSchema.Free;
  FExample.Free;
  inherited;
end;

function TOpenApiParameter.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('name', FName);
    Result.AddPair('in', ParameterLocationToString(FIn));
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
    Result.AddPair('required', TJSONBool.Create(FRequired));
    if FDeprecated then
      Result.AddPair('deprecated', TJSONBool.Create(True));
    if FSchema <> nil then
      Result.AddPair('schema', FSchema.ToJSON);
    if FExample <> nil then
      Result.AddPair('example', FExample.Clone as TJSONValue);
  except
    Result.Free;
    raise;
  end;
end;

class function TOpenApiParameter.CreatePath(const AName, ADesc: string): TOpenApiParameter;
begin
  Result := TOpenApiParameter.Create;
  Result.Name := AName;
  Result.Location := plPath;
  Result.Description := ADesc;
  Result.Required := True;
  Result.Schema.DataType := odtString;
end;

class function TOpenApiParameter.CreateQuery(const AName, ADesc: string; ARequired: Boolean): TOpenApiParameter;
begin
  Result := TOpenApiParameter.Create;
  Result.Name := AName;
  Result.Location := plQuery;
  Result.Description := ADesc;
  Result.Required := ARequired;
  Result.Schema.DataType := odtString;
end;

class function TOpenApiParameter.CreateHeader(const AName, ADesc: string; ARequired: Boolean): TOpenApiParameter;
begin
  Result := TOpenApiParameter.Create;
  Result.Name := AName;
  Result.Location := plHeader;
  Result.Description := ADesc;
  Result.Required := ARequired;
  Result.Schema.DataType := odtString;
end;

{ TOpenApiRequestBody }

constructor TOpenApiRequestBody.Create;
begin
  inherited;
  FContent := TObjectDictionary<string, TOpenApiSchema>.Create([doOwnsValues]);
end;

destructor TOpenApiRequestBody.Destroy;
begin
  FContent.Free;
  inherited;
end;

function TOpenApiRequestBody.ToJSON: TJSONObject;
var
  LContent: TJSONObject;
  LPair: TPair<string, TOpenApiSchema>;
  LMediaType: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
    Result.AddPair('required', TJSONBool.Create(FRequired));

    LContent := TJSONObject.Create;
    for LPair in FContent do
    begin
      LMediaType := TJSONObject.Create;
      LMediaType.AddPair('schema', LPair.Value.ToJSON);
      LContent.AddPair(LPair.Key, LMediaType);
    end;
    Result.AddPair('content', LContent);
  except
    Result.Free;
    raise;
  end;
end;

procedure TOpenApiRequestBody.AddContent(const AMediaType: string; ASchema: TOpenApiSchema);
begin
  FContent.AddOrSetValue(AMediaType, ASchema);
end;

class function TOpenApiRequestBody.CreateJSON(ASchema: TOpenApiSchema; const ADesc: string): TOpenApiRequestBody;
begin
  Result := TOpenApiRequestBody.Create;
  Result.Description := ADesc;
  Result.Required := True;
  Result.AddContent('application/json', ASchema);
end;

{ TOpenApiResponse }

constructor TOpenApiResponse.Create;
begin
  inherited;
  FContent := TObjectDictionary<string, TOpenApiSchema>.Create([doOwnsValues]);
  FHeaders := TObjectDictionary<string, TOpenApiSchema>.Create([doOwnsValues]);
end;

destructor TOpenApiResponse.Destroy;
begin
  FContent.Free;
  FHeaders.Free;
  inherited;
end;

function TOpenApiResponse.ToJSON: TJSONObject;
var
  LContent: TJSONObject;
  LHeaders: TJSONObject;
  LPair: TPair<string, TOpenApiSchema>;
  LMediaType: TJSONObject;
  LHeader: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('description', FDescription);

    if FContent.Count > 0 then
    begin
      LContent := TJSONObject.Create;
      for LPair in FContent do
      begin
        LMediaType := TJSONObject.Create;
        LMediaType.AddPair('schema', LPair.Value.ToJSON);
        LContent.AddPair(LPair.Key, LMediaType);
      end;
      Result.AddPair('content', LContent);
    end;

    if FHeaders.Count > 0 then
    begin
      LHeaders := TJSONObject.Create;
      for LPair in FHeaders do
      begin
        LHeader := TJSONObject.Create;
        LHeader.AddPair('schema', LPair.Value.ToJSON);
        LHeaders.AddPair(LPair.Key, LHeader);
      end;
      Result.AddPair('headers', LHeaders);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure TOpenApiResponse.AddContent(const AMediaType: string; ASchema: TOpenApiSchema);
begin
  FContent.AddOrSetValue(AMediaType, ASchema);
end;

procedure TOpenApiResponse.AddHeader(const AName: string; ASchema: TOpenApiSchema);
begin
  FHeaders.AddOrSetValue(AName, ASchema);
end;

class function TOpenApiResponse.CreateSuccess(const ADesc: string): TOpenApiResponse;
begin
  Result := TOpenApiResponse.Create;
  Result.Description := ADesc;
end;

class function TOpenApiResponse.CreateJSON(ASchema: TOpenApiSchema; const ADesc: string): TOpenApiResponse;
begin
  Result := TOpenApiResponse.Create;
  Result.Description := ADesc;
  Result.AddContent('application/json', ASchema);
end;

class function TOpenApiResponse.CreateError(const ADesc: string): TOpenApiResponse;
var
  LSchema: TOpenApiSchema;
begin
  Result := TOpenApiResponse.Create;
  Result.Description := ADesc;
  
  LSchema := TOpenApiSchema.CreateObject;
  LSchema.AddProperty('error').DataType := odtString;
  LSchema.AddProperty('code').DataType := odtInteger;
  LSchema.AddRequired('error');
  
  Result.AddContent('application/json', LSchema);
end;

{ TOpenApiSecurityScheme }

function TOpenApiSecurityScheme.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('type', FType);
    if FScheme <> '' then
      Result.AddPair('scheme', FScheme);
    if FBearerFormat <> '' then
      Result.AddPair('bearerFormat', FBearerFormat);
    if FName <> '' then
      Result.AddPair('name', FName);
    if FIn <> '' then
      Result.AddPair('in', FIn);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
  except
    Result.Free;
    raise;
  end;
end;

class function TOpenApiSecurityScheme.CreateBearer(const ADesc: string): TOpenApiSecurityScheme;
begin
  Result := TOpenApiSecurityScheme.Create;
  Result.SecurityType := 'http';
  Result.Scheme := 'bearer';
  Result.BearerFormat := 'JWT';
  Result.Description := ADesc;
  if Result.Description = '' then
    Result.Description := 'JWT Bearer token authentication';
end;

class function TOpenApiSecurityScheme.CreateApiKey(const AName, ALocation, ADesc: string): TOpenApiSecurityScheme;
begin
  Result := TOpenApiSecurityScheme.Create;
  Result.SecurityType := 'apiKey';
  Result.Name := AName;
  Result.Location := ALocation;
  Result.Description := ADesc;
end;

class function TOpenApiSecurityScheme.CreateBasic(const ADesc: string): TOpenApiSecurityScheme;
begin
  Result := TOpenApiSecurityScheme.Create;
  Result.SecurityType := 'http';
  Result.Scheme := 'basic';
  Result.Description := ADesc;
  if Result.Description = '' then
    Result.Description := 'Basic HTTP authentication';
end;

{ TOpenApiOperation }

constructor TOpenApiOperation.Create;
begin
  inherited;
  FTags := TStringList.Create;
  FParameters := TObjectList<TOpenApiParameter>.Create(True);
  FResponses := TObjectDictionary<string, TOpenApiResponse>.Create([doOwnsValues]);
  FSecurity := TList<TStringList>.Create;
end;

destructor TOpenApiOperation.Destroy;
var
  LSec: TStringList;
begin
  FTags.Free;
  FParameters.Free;
  FRequestBody.Free;
  FResponses.Free;
  for LSec in FSecurity do
    LSec.Free;
  FSecurity.Free;
  inherited;
end;

function TOpenApiOperation.ToJSON: TJSONObject;
var
  LTagsArr: TJSONArray;
  LParams: TJSONArray;
  LResponses: TJSONObject;
  LSecurityArr: TJSONArray;
  LSecItem: TJSONObject;
  LParam: TOpenApiParameter;
  LPair: TPair<string, TOpenApiResponse>;
  LSec: TStringList;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    if FOperationId <> '' then
      Result.AddPair('operationId', FOperationId);
    if FSummary <> '' then
      Result.AddPair('summary', FSummary);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
    if FDeprecated then
      Result.AddPair('deprecated', TJSONBool.Create(True));

    // Tags
    if FTags.Count > 0 then
    begin
      LTagsArr := TJSONArray.Create;
      for I := 0 to FTags.Count - 1 do
        LTagsArr.Add(FTags[I]);
      Result.AddPair('tags', LTagsArr);
    end;

    // Parameters
    if FParameters.Count > 0 then
    begin
      LParams := TJSONArray.Create;
      for LParam in FParameters do
        LParams.Add(LParam.ToJSON);
      Result.AddPair('parameters', LParams);
    end;

    // Request Body
    if FRequestBody <> nil then
      Result.AddPair('requestBody', FRequestBody.ToJSON);

    // Responses
    LResponses := TJSONObject.Create;
    for LPair in FResponses do
      LResponses.AddPair(LPair.Key, LPair.Value.ToJSON);
    if FResponses.Count = 0 then
    begin
      // 添加默认响应
      var LDefaultResp := TOpenApiResponse.CreateSuccess;
      try
        LResponses.AddPair('200', LDefaultResp.ToJSON);
      finally
        LDefaultResp.Free;
      end;
    end;
    Result.AddPair('responses', LResponses);

    // Security
    if FSecurity.Count > 0 then
    begin
      LSecurityArr := TJSONArray.Create;
      for LSec in FSecurity do
      begin
        LSecItem := TJSONObject.Create;
        for I := 0 to LSec.Count - 1 do
          LSecItem.AddPair(LSec[I], TJSONArray.Create);
        LSecurityArr.Add(LSecItem);
      end;
      Result.AddPair('security', LSecurityArr);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TOpenApiOperation.AddParameter(AParam: TOpenApiParameter): TOpenApiOperation;
begin
  FParameters.Add(AParam);
  Result := Self;
end;

function TOpenApiOperation.AddResponse(const AStatusCode: string; AResponse: TOpenApiResponse): TOpenApiOperation;
begin
  FResponses.AddOrSetValue(AStatusCode, AResponse);
  Result := Self;
end;

function TOpenApiOperation.AddTag(const ATag: string): TOpenApiOperation;
begin
  if FTags.IndexOf(ATag) < 0 then
    FTags.Add(ATag);
  Result := Self;
end;

function TOpenApiOperation.SetSecurity(const ASchemes: array of string): TOpenApiOperation;
var
  LSec: TStringList;
  LScheme: string;
begin
  LSec := TStringList.Create;
  for LScheme in ASchemes do
    LSec.Add(LScheme);
  FSecurity.Add(LSec);
  Result := Self;
end;

{ TOpenApiPathItem }

constructor TOpenApiPathItem.Create;
begin
  inherited;
  FParameters := TObjectList<TOpenApiParameter>.Create(True);
end;

destructor TOpenApiPathItem.Destroy;
begin
  FGet.Free;
  FPost.Free;
  FPut.Free;
  FPatch.Free;
  FDelete.Free;
  FOptions.Free;
  FHead.Free;
  FParameters.Free;
  inherited;
end;

function TOpenApiPathItem.ToJSON: TJSONObject;
var
  LParams: TJSONArray;
  LParam: TOpenApiParameter;
begin
  Result := TJSONObject.Create;
  try
    if FSummary <> '' then
      Result.AddPair('summary', FSummary);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);

    if FGet <> nil then
      Result.AddPair('get', FGet.ToJSON);
    if FPost <> nil then
      Result.AddPair('post', FPost.ToJSON);
    if FPut <> nil then
      Result.AddPair('put', FPut.ToJSON);
    if FPatch <> nil then
      Result.AddPair('patch', FPatch.ToJSON);
    if FDelete <> nil then
      Result.AddPair('delete', FDelete.ToJSON);
    if FOptions <> nil then
      Result.AddPair('options', FOptions.ToJSON);
    if FHead <> nil then
      Result.AddPair('head', FHead.ToJSON);

    if FParameters.Count > 0 then
    begin
      LParams := TJSONArray.Create;
      for LParam in FParameters do
        LParams.Add(LParam.ToJSON);
      Result.AddPair('parameters', LParams);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TOpenApiPathItem.GetOperation(AMethod: THttpMethod): TOpenApiOperation;
begin
  case AMethod of
    hmGet: Result := FGet;
    hmPost: Result := FPost;
    hmPut: Result := FPut;
    hmPatch: Result := FPatch;
    hmDelete: Result := FDelete;
    hmOptions: Result := FOptions;
    hmHead: Result := FHead;
  else
    Result := nil;
  end;
end;

procedure TOpenApiPathItem.SetOperation(AMethod: THttpMethod; AOperation: TOpenApiOperation);
begin
  case AMethod of
    hmGet: begin FGet.Free; FGet := AOperation; end;
    hmPost: begin FPost.Free; FPost := AOperation; end;
    hmPut: begin FPut.Free; FPut := AOperation; end;
    hmPatch: begin FPatch.Free; FPatch := AOperation; end;
    hmDelete: begin FDelete.Free; FDelete := AOperation; end;
    hmOptions: begin FOptions.Free; FOptions := AOperation; end;
    hmHead: begin FHead.Free; FHead := AOperation; end;
  end;
end;

{ TOpenApiTag }

function TOpenApiTag.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('name', FName);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
  except
    Result.Free;
    raise;
  end;
end;

{ TOpenApiServer }

function TOpenApiServer.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('url', FUrl);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
  except
    Result.Free;
    raise;
  end;
end;

{ TOpenApiContact }

function TOpenApiContact.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    if FName <> '' then
      Result.AddPair('name', FName);
    if FUrl <> '' then
      Result.AddPair('url', FUrl);
    if FEmail <> '' then
      Result.AddPair('email', FEmail);
  except
    Result.Free;
    raise;
  end;
end;

{ TOpenApiLicense }

function TOpenApiLicense.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('name', FName);
    if FUrl <> '' then
      Result.AddPair('url', FUrl);
  except
    Result.Free;
    raise;
  end;
end;

{ TOpenApiInfo }

constructor TOpenApiInfo.Create;
begin
  inherited;
  FContact := TOpenApiContact.Create;
  FLicense := TOpenApiLicense.Create;
end;

destructor TOpenApiInfo.Destroy;
begin
  FContact.Free;
  FLicense.Free;
  inherited;
end;

function TOpenApiInfo.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('title', FTitle);
    if FDescription <> '' then
      Result.AddPair('description', FDescription);
    Result.AddPair('version', FVersion);
    if FTermsOfService <> '' then
      Result.AddPair('termsOfService', FTermsOfService);
    if (FContact.Name <> '') or (FContact.Email <> '') or (FContact.Url <> '') then
      Result.AddPair('contact', FContact.ToJSON);
    if FLicense.Name <> '' then
      Result.AddPair('license', FLicense.ToJSON);
  except
    Result.Free;
    raise;
  end;
end;

{ TOpenApiDocument }

constructor TOpenApiDocument.Create;
begin
  inherited;
  FOpenApi := '3.0.3';
  FInfo := TOpenApiInfo.Create;
  FServers := TObjectList<TOpenApiServer>.Create(True);
  FPaths := TObjectDictionary<string, TOpenApiPathItem>.Create([doOwnsValues]);
  FComponents := TObjectDictionary<string, TOpenApiSchema>.Create([doOwnsValues]);
  FSecuritySchemes := TObjectDictionary<string, TOpenApiSecurityScheme>.Create([doOwnsValues]);
  FSecurity := TList<TStringList>.Create;
  FTags := TObjectList<TOpenApiTag>.Create(True);
end;

destructor TOpenApiDocument.Destroy;
var
  LSec: TStringList;
begin
  FInfo.Free;
  FServers.Free;
  FPaths.Free;
  FComponents.Free;
  FSecuritySchemes.Free;
  for LSec in FSecurity do
    LSec.Free;
  FSecurity.Free;
  FTags.Free;
  inherited;
end;

function TOpenApiDocument.ToJSON: TJSONObject;
var
  LServers: TJSONArray;
  LPaths: TJSONObject;
  LComponents: TJSONObject;
  LSchemas: TJSONObject;
  LSecSchemes: TJSONObject;
  LTags: TJSONArray;
  LSecurity: TJSONArray;
  LSecItem: TJSONObject;
  LServer: TOpenApiServer;
  LTag: TOpenApiTag;
  LPair: TPair<string, TOpenApiPathItem>;
  LSchemaPair: TPair<string, TOpenApiSchema>;
  LSecSchemePair: TPair<string, TOpenApiSecurityScheme>;
  LSec: TStringList;
  I: Integer;
begin
  Result := TJSONObject.Create;
  try
    Result.AddPair('openapi', FOpenApi);
    Result.AddPair('info', FInfo.ToJSON);

    // Servers
    if FServers.Count > 0 then
    begin
      LServers := TJSONArray.Create;
      for LServer in FServers do
        LServers.Add(LServer.ToJSON);
      Result.AddPair('servers', LServers);
    end;

    // Paths
    LPaths := TJSONObject.Create;
    for LPair in FPaths do
      LPaths.AddPair(LPair.Key, LPair.Value.ToJSON);
    Result.AddPair('paths', LPaths);

    // Components
    if (FComponents.Count > 0) or (FSecuritySchemes.Count > 0) then
    begin
      LComponents := TJSONObject.Create;

      if FComponents.Count > 0 then
      begin
        LSchemas := TJSONObject.Create;
        for LSchemaPair in FComponents do
          LSchemas.AddPair(LSchemaPair.Key, LSchemaPair.Value.ToJSON);
        LComponents.AddPair('schemas', LSchemas);
      end;

      if FSecuritySchemes.Count > 0 then
      begin
        LSecSchemes := TJSONObject.Create;
        for LSecSchemePair in FSecuritySchemes do
          LSecSchemes.AddPair(LSecSchemePair.Key, LSecSchemePair.Value.ToJSON);
        LComponents.AddPair('securitySchemes', LSecSchemes);
      end;

      Result.AddPair('components', LComponents);
    end;

    // Global Security
    if FSecurity.Count > 0 then
    begin
      LSecurity := TJSONArray.Create;
      for LSec in FSecurity do
      begin
        LSecItem := TJSONObject.Create;
        for I := 0 to LSec.Count - 1 do
          LSecItem.AddPair(LSec[I], TJSONArray.Create);
        LSecurity.Add(LSecItem);
      end;
      Result.AddPair('security', LSecurity);
    end;

    // Tags
    if FTags.Count > 0 then
    begin
      LTags := TJSONArray.Create;
      for LTag in FTags do
        LTags.Add(LTag.ToJSON);
      Result.AddPair('tags', LTags);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TOpenApiDocument.ToYAML: string;
var
  LJson: TJSONObject;

  function JsonToYaml(AValue: TJSONValue; AIndent: Integer = 0): string;
  var
    LObj: TJSONObject;
    LArr: TJSONArray;
    LPair: TJSONPair;
    LItem: TJSONValue;
    LPrefix: string;
    I: Integer;
  begin
    LPrefix := StringOfChar(' ', AIndent);
    Result := '';

    if AValue is TJSONObject then
    begin
      LObj := TJSONObject(AValue);
      for I := 0 to LObj.Count - 1 do
      begin
        LPair := LObj.Pairs[I];
        if LPair.JsonValue is TJSONObject then
        begin
          Result := Result + LPrefix + LPair.JsonString.Value + ':' + sLineBreak;
          Result := Result + JsonToYaml(LPair.JsonValue, AIndent + 2);
        end
        else if LPair.JsonValue is TJSONArray then
        begin
          Result := Result + LPrefix + LPair.JsonString.Value + ':' + sLineBreak;
          Result := Result + JsonToYaml(LPair.JsonValue, AIndent + 2);
        end
        else if LPair.JsonValue is TJSONString then
        begin
          var LStr := TJSONString(LPair.JsonValue).Value;
          if (Pos(sLineBreak, LStr) > 0) or (Pos(':', LStr) > 0) or (Pos('#', LStr) > 0) then
            Result := Result + LPrefix + LPair.JsonString.Value + ': "' + LStr.Replace('"', '\"') + '"' + sLineBreak
          else
            Result := Result + LPrefix + LPair.JsonString.Value + ': ' + LStr + sLineBreak;
        end
        else if LPair.JsonValue is TJSONBool then
          Result := Result + LPrefix + LPair.JsonString.Value + ': ' + LowerCase(LPair.JsonValue.ToString) + sLineBreak
        else
          Result := Result + LPrefix + LPair.JsonString.Value + ': ' + LPair.JsonValue.ToString + sLineBreak;
      end;
    end
    else if AValue is TJSONArray then
    begin
      LArr := TJSONArray(AValue);
      for I := 0 to LArr.Count - 1 do
      begin
        LItem := LArr.Items[I];
        if LItem is TJSONObject then
        begin
          Result := Result + LPrefix + '- ' + sLineBreak;
          Result := Result + JsonToYaml(LItem, AIndent + 2);
        end
        else if LItem is TJSONString then
          Result := Result + LPrefix + '- ' + TJSONString(LItem).Value + sLineBreak
        else
          Result := Result + LPrefix + '- ' + LItem.ToString + sLineBreak;
      end;
    end;
  end;

begin
  LJson := ToJSON;
  try
    Result := JsonToYaml(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TOpenApiDocument.SaveToFile(const APath: string);
var
  LExt: string;
begin
  LExt := LowerCase(TPath.GetExtension(APath));
  if (LExt = '.yaml') or (LExt = '.yml') then
    TFile.WriteAllText(APath, ToYAML, TEncoding.UTF8)
  else
  begin
    var LJson := ToJSON;
    try
      TFile.WriteAllText(APath, LJson.Format(2), TEncoding.UTF8);
    finally
      LJson.Free;
    end;
  end;
end;

function TOpenApiDocument.AddServer(const AUrl, ADesc: string): TOpenApiServer;
begin
  Result := TOpenApiServer.Create;
  Result.Url := AUrl;
  Result.Description := ADesc;
  FServers.Add(Result);
end;

function TOpenApiDocument.AddPath(const APath: string): TOpenApiPathItem;
begin
  if not FPaths.TryGetValue(APath, Result) then
  begin
    Result := TOpenApiPathItem.Create;
    FPaths.Add(APath, Result);
  end;
end;

function TOpenApiDocument.AddComponent(const AName: string; ASchema: TOpenApiSchema): TOpenApiSchema;
begin
  FComponents.AddOrSetValue(AName, ASchema);
  Result := ASchema;
end;

function TOpenApiDocument.AddSecurityScheme(const AName: string;
  AScheme: TOpenApiSecurityScheme): TOpenApiSecurityScheme;
begin
  FSecuritySchemes.AddOrSetValue(AName, AScheme);
  Result := AScheme;
end;

function TOpenApiDocument.AddTag(const AName, ADesc: string): TOpenApiTag;
begin
  Result := TOpenApiTag.Create;
  Result.Name := AName;
  Result.Description := ADesc;
  FTags.Add(Result);
end;

procedure TOpenApiDocument.SetGlobalSecurity(const ASchemes: array of string);
var
  LSec: TStringList;
  LScheme: string;
begin
  LSec := TStringList.Create;
  for LScheme in ASchemes do
    LSec.Add(LScheme);
  FSecurity.Add(LSec);
end;

{ TOpenApiGenerator }

constructor TOpenApiGenerator.Create(ARouter: TApiRouter);
begin
  inherited Create;
  FRouter := ARouter;
  FDocument := TOpenApiDocument.Create;
  FBasePath := '';
  FAutoGenerateSchemas := True;
end;

destructor TOpenApiGenerator.Destroy;
begin
  FDocument.Free;
  inherited;
end;

procedure TOpenApiGenerator.GenerateFromRoutes;
var
  LRoute: TRouteDefinition;
  LPath: string;
  LPathItem: TOpenApiPathItem;
  LOperation: TOpenApiOperation;
  LMethod: THttpMethod;
  LParams: TArray<string>;
  LParam: string;
  LTag: string;
  I: Integer;
begin
  for LRoute in FRouter.Routes do
  begin
    LPath := ConvertRoutePattern(LRoute.Pattern);
    LPathItem := FDocument.AddPath(FBasePath + LPath);

    // 提取路径参数
    LParams := ExtractPathParameters(LRoute.Pattern);

    for LMethod := Low(THttpMethod) to High(THttpMethod) do
    begin
      if LMethod in LRoute.Methods then
      begin
        LOperation := TOpenApiOperation.Create;
        LOperation.OperationId := GenerateOperationId(HttpMethodToStr(LMethod), LRoute.Pattern);

        if LRoute.Name <> '' then
          LOperation.Summary := LRoute.Name;
        if LRoute.Description <> '' then
          LOperation.Description := LRoute.Description;

        // 添加标签
        for I := 0 to LRoute.Tags.Count - 1 do
          LOperation.AddTag(LRoute.Tags[I]);

        // 如果没有标签，从路径提取
        if LRoute.Tags.Count = 0 then
        begin
          LTag := ExtractFirstPathSegment(LRoute.Pattern);
          if LTag <> '' then
            LOperation.AddTag(LTag);
        end;

        // 添加路径参数
        for LParam in LParams do
          LOperation.AddParameter(TOpenApiParameter.CreatePath(LParam, ''));

        // 添加默认响应
        LOperation.AddResponse('200', TOpenApiResponse.CreateSuccess('Successful response'));
        LOperation.AddResponse('400', TOpenApiResponse.CreateError('Bad request'));
        LOperation.AddResponse('401', TOpenApiResponse.CreateError('Unauthorized'));
        LOperation.AddResponse('404', TOpenApiResponse.CreateError('Not found'));
        LOperation.AddResponse('500', TOpenApiResponse.CreateError('Internal server error'));

        LPathItem.SetOperation(LMethod, LOperation);
      end;
    end;
  end;
end;

function TOpenApiGenerator.ConvertRoutePattern(const APattern: string): string;
begin
  // 将 :param 转换为 {param}
  Result := TRegEx.Replace(APattern, ':([a-zA-Z_][a-zA-Z0-9_]*)', '{$1}');
end;

function TOpenApiGenerator.ExtractPathParameters(const APattern: string): TArray<string>;
var
  LRegex: TRegEx;
  LMatches: TMatchCollection;
  LMatch: TMatch;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    LRegex := TRegEx.Create(':([a-zA-Z_][a-zA-Z0-9_]*)');
    LMatches := LRegex.Matches(APattern);
    for LMatch in LMatches do
      LList.Add(LMatch.Groups[1].Value);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TOpenApiGenerator.GenerateOperationId(const AMethod: string; const APath: string): string;
var
  LParts: TArray<string>;
  LPart: string;
begin
  // 生成如 getUsers, getUserById, createUser 的操作ID
  Result := LowerCase(AMethod);
  LParts := APath.Split(['/']);
  for LPart in LParts do
  begin
    if (LPart <> '') and not LPart.StartsWith(':') then
    begin
      // 首字母大写
      Result := Result + UpperCase(LPart[1]) + Copy(LPart, 2, Length(LPart));
    end
    else if LPart.StartsWith(':') then
    begin
      // 参数转换为 ById 之类
      Result := Result + 'By' + UpperCase(LPart[2]) + Copy(LPart, 3, Length(LPart));
    end;
  end;
end;

function ExtractFirstPathSegment(const APath: string): string;
var
  LParts: TArray<string>;
begin
  Result := '';
  LParts := APath.Trim(['/']).Split(['/']);
  if Length(LParts) > 0 then
  begin
    Result := LParts[0];
    if Result.StartsWith(':') then
      Result := '';
  end;
end;

procedure TOpenApiGenerator.Generate;
begin
  GenerateFromRoutes;
end;

procedure TOpenApiGenerator.SetInfo(const ATitle, ADesc, AVersion: string);
begin
  FDocument.Info.Title := ATitle;
  FDocument.Info.Description := ADesc;
  FDocument.Info.Version := AVersion;
end;

procedure TOpenApiGenerator.SetContact(const AName, AEmail, AUrl: string);
begin
  FDocument.Info.Contact.Name := AName;
  FDocument.Info.Contact.Email := AEmail;
  FDocument.Info.Contact.Url := AUrl;
end;

procedure TOpenApiGenerator.SetLicense(const AName, AUrl: string);
begin
  FDocument.Info.License.Name := AName;
  FDocument.Info.License.Url := AUrl;
end;

procedure TOpenApiGenerator.AddServer(const AUrl, ADesc: string);
begin
  FDocument.AddServer(AUrl, ADesc);
end;

procedure TOpenApiGenerator.AddBearerAuth(const AName: string);
begin
  FDocument.AddSecurityScheme(AName, TOpenApiSecurityScheme.CreateBearer);
  FDocument.SetGlobalSecurity([AName]);
end;

procedure TOpenApiGenerator.AddApiKeyAuth(const AName, AHeaderName: string);
begin
  FDocument.AddSecurityScheme(AName,
    TOpenApiSecurityScheme.CreateApiKey(AHeaderName, 'header', 'API Key authentication'));
end;

function TOpenApiGenerator.GetJSON: string;
var
  LJson: TJSONObject;
begin
  LJson := FDocument.ToJSON;
  try
    Result := LJson.Format(2);
  finally
    LJson.Free;
  end;
end;

function TOpenApiGenerator.GetYAML: string;
begin
  Result := FDocument.ToYAML;
end;

procedure TOpenApiGenerator.SaveToFile(const APath: string);
begin
  FDocument.SaveToFile(APath);
end;

procedure TOpenApiGenerator.RegisterSwaggerUI(const ADocsPath: string);
begin
  // 注册 OpenAPI JSON 端点
  FRouter.Get(ADocsPath + '/openapi.json',
    procedure(AContext: TApiContext)
    begin
      AContext.Response.ContentType := TContentType.JSON;
      AContext.Response.OK(GetJSON);
    end
  );

  // 注册 Swagger UI 端点
  FRouter.Get(ADocsPath,
    procedure(AContext: TApiContext)
    begin
      AContext.Response.ContentType := TContentType.HTML;
      AContext.Response.OK(TSwaggerUIGenerator.GenerateHTML(ADocsPath + '/openapi.json',
        FDocument.Info.Title));
    end
  );
end;

procedure TOpenApiGenerator.RegisterReDocUI(const ADocsPath: string);
begin
  // 注册 OpenAPI JSON 端点
  FRouter.Get(ADocsPath + '/openapi.json',
    procedure(AContext: TApiContext)
    begin
      AContext.Response.ContentType := TContentType.JSON;
      AContext.Response.OK(GetJSON);
    end
  );

  // 注册 ReDoc UI 端点
  FRouter.Get(ADocsPath,
    procedure(AContext: TApiContext)
    begin
      AContext.Response.ContentType := TContentType.HTML;
      AContext.Response.OK(TSwaggerUIGenerator.GenerateReDocHTML(ADocsPath + '/openapi.json',
        FDocument.Info.Title));
    end
  );
end;

{ TSwaggerUIGenerator }

class function TSwaggerUIGenerator.GenerateHTML(const ASpecUrl: string; const ATitle: string): string;
begin
  Result :=
    '<!DOCTYPE html>' + sLineBreak +
    '<html lang="en">' + sLineBreak +
    '<head>' + sLineBreak +
    '  <meta charset="UTF-8">' + sLineBreak +
    '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' + sLineBreak +
    '  <title>' + ATitle + '</title>' + sLineBreak +
    '  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css" />' + sLineBreak +
    '  <style>' + sLineBreak +
    '    body { margin: 0; padding: 0; }' + sLineBreak +
    '    .swagger-ui .topbar { display: none; }' + sLineBreak +
    '  </style>' + sLineBreak +
    '</head>' + sLineBreak +
    '<body>' + sLineBreak +
    '  <div id="swagger-ui"></div>' + sLineBreak +
    '  <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>' + sLineBreak +
    '  <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>' + sLineBreak +
    '  <script>' + sLineBreak +
    '    window.onload = function() {' + sLineBreak +
    '      SwaggerUIBundle({' + sLineBreak +
    '        url: "' + ASpecUrl + '",' + sLineBreak +
    '        dom_id: "#swagger-ui",' + sLineBreak +
    '        deepLinking: true,' + sLineBreak +
    '        presets: [' + sLineBreak +
    '          SwaggerUIBundle.presets.apis,' + sLineBreak +
    '          SwaggerUIStandalonePreset' + sLineBreak +
    '        ],' + sLineBreak +
    '        plugins: [' + sLineBreak +
    '          SwaggerUIBundle.plugins.DownloadUrl' + sLineBreak +
    '        ],' + sLineBreak +
    '        layout: "StandaloneLayout"' + sLineBreak +
    '      });' + sLineBreak +
    '    };' + sLineBreak +
    '  </script>' + sLineBreak +
    '</body>' + sLineBreak +
    '</html>';
end;

class function TSwaggerUIGenerator.GenerateReDocHTML(const ASpecUrl: string; const ATitle: string): string;
begin
  Result :=
    '<!DOCTYPE html>' + sLineBreak +
    '<html>' + sLineBreak +
    '<head>' + sLineBreak +
    '  <title>' + ATitle + '</title>' + sLineBreak +
    '  <meta charset="utf-8"/>' + sLineBreak +
    '  <meta name="viewport" content="width=device-width, initial-scale=1">' + sLineBreak +
    '  <link href="https://fonts.googleapis.com/css?family=Montserrat:300,400,700|Roboto:300,400,700" rel="stylesheet">' + sLineBreak +
    '  <style>' + sLineBreak +
    '    body { margin: 0; padding: 0; }' + sLineBreak +
    '  </style>' + sLineBreak +
    '</head>' + sLineBreak +
    '<body>' + sLineBreak +
    '  <redoc spec-url="' + ASpecUrl + '"></redoc>' + sLineBreak +
    '  <script src="https://cdn.redoc.ly/redoc/latest/bundles/redoc.standalone.js"></script>' + sLineBreak +
    '</body>' + sLineBreak +
    '</html>';
end;

end.
