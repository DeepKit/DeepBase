{******************************************************************************}
{                                                                              }
{  UniFlow Skill Executor                                                      }
{  Workflow action executor for Skill invocations                              }
{                                                                              }
{  Features:                                                                   }
{  - Integration with workflow engine                                          }
{  - Skill action execution                                                    }
{  - Result mapping to workflow context                                        }
{  - Error handling and retry logic                                            }
{                                                                              }
{******************************************************************************}

unit UniFlow.Skill.Executor;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  UniFlow.Skill.Types,
  UniFlow.Skill.Client;

type
  //----------------------------------------------------------------------------
  // Forward declarations
  //----------------------------------------------------------------------------

  TSkillActionExecutor = class;
  TSkillActionConfig = class;
  TSkillActionResult = class;

  //----------------------------------------------------------------------------
  // TSkillActionConfig - Configuration for Skill action
  //----------------------------------------------------------------------------

  TSkillActionConfig = class
  private
    FSkillName: string;
    FParams: TJSONObject;
    FTimeoutMs: Integer;
    FRetryCount: Integer;
    FRetryDelayMs: Integer;
    FResultMapping: TDictionary<string, string>;
    FErrorHandling: TSkillErrorHandling;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Add parameter from literal value</summary>
    procedure AddParam(const AName, AValue: string); overload;
    procedure AddParam(const AName: string; AValue: Integer); overload;
    procedure AddParam(const AName: string; AValue: Boolean); overload;
    procedure AddParam(const AName: string; AValue: Double); overload;

    /// <summary>Add parameter from context expression</summary>
    procedure AddParamExpr(const AName, AExpression: string);

    /// <summary>Map result field to context variable</summary>
    procedure MapResult(const AResultField, AContextVar: string);

    function ToJSON: TJSONObject;
    class function FromJSON(const AJSON: TJSONObject): TSkillActionConfig; static;

    property SkillName: string read FSkillName write FSkillName;
    property Params: TJSONObject read FParams;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property RetryCount: Integer read FRetryCount write FRetryCount;
    property RetryDelayMs: Integer read FRetryDelayMs write FRetryDelayMs;
    property ResultMapping: TDictionary<string, string> read FResultMapping;
    property ErrorHandling: TSkillErrorHandling read FErrorHandling write FErrorHandling;
  end;

  //----------------------------------------------------------------------------
  // TSkillErrorHandling - Error handling strategy
  //----------------------------------------------------------------------------

  TSkillErrorHandling = (
    ehRaise,      // Raise exception on error
    ehIgnore,     // Ignore error, continue workflow
    ehDefault,    // Use default value on error
    ehRetry       // Retry before failing
  );

  //----------------------------------------------------------------------------
  // TSkillActionResult - Result of Skill action execution
  //----------------------------------------------------------------------------

  TSkillActionResult = class
  private
    FSuccess: Boolean;
    FSkillName: string;
    FData: TJSONValue;
    FError: string;
    FExecutionTimeMs: Integer;
    FRetryAttempts: Integer;
  public
    constructor Create;
    destructor Destroy; override;

    property Success: Boolean read FSuccess write FSuccess;
    property SkillName: string read FSkillName write FSkillName;
    property Data: TJSONValue read FData write FData;
    property Error: string read FError write FError;
    property ExecutionTimeMs: Integer read FExecutionTimeMs write FExecutionTimeMs;
    property RetryAttempts: Integer read FRetryAttempts write FRetryAttempts;
  end;

  //----------------------------------------------------------------------------
  // TSkillActionExecutor - Executes Skill actions in workflow
  //----------------------------------------------------------------------------

  TContextResolver = reference to function(const AExpression: string): TValue;
  TContextUpdater = reference to procedure(const AName: string; const AValue: TValue);

  TSkillActionExecutor = class
  private
    FClient: TSkillClient;
    FOwnsClient: Boolean;
    FDefaultTimeout: Integer;
    FDefaultRetryCount: Integer;

    function ResolveParams(const AParams: TJSONObject;
      const AResolver: TContextResolver): TJSONObject;
    function ExtractValue(const AData: TJSONValue;
      const APath: string): TValue;
    procedure ApplyResultMapping(const AResult: TSkillActionResult;
      const AMapping: TDictionary<string, string>;
      const AUpdater: TContextUpdater);
  public
    constructor Create(AClient: TSkillClient; AOwnsClient: Boolean = False); overload;
    constructor Create(const ABaseURL: string); overload;
    destructor Destroy; override;

    /// <summary>Execute a Skill action</summary>
    function Execute(const AConfig: TSkillActionConfig;
      const AResolver: TContextResolver = nil;
      const AUpdater: TContextUpdater = nil): TSkillActionResult;

    /// <summary>Execute code in sandbox</summary>
    function ExecuteCode(const ACode: string;
      const AVariables: TJSONObject = nil;
      const AReturnVar: string = 'result'): TSkillActionResult;

    /// <summary>Execute LLM chat</summary>
    function ExecuteLLM(const AMessages: TObjectList<TLLMMessage>;
      const AModel: string = '';
      ATemperature: Double = 0.7;
      AMaxTokens: Integer = 4096): TSkillActionResult;

    /// <summary>Simple LLM query</summary>
    function QueryLLM(const AUserMessage: string;
      const ASystemPrompt: string = '';
      const AModel: string = ''): string;

    property Client: TSkillClient read FClient;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
    property DefaultRetryCount: Integer read FDefaultRetryCount write FDefaultRetryCount;
  end;

  //----------------------------------------------------------------------------
  // TSkillActionBuilder - Fluent builder for Skill actions
  //----------------------------------------------------------------------------

  TSkillActionBuilder = class
  private
    FConfig: TSkillActionConfig;
  public
    constructor Create(const ASkillName: string);
    destructor Destroy; override;

    function WithParam(const AName, AValue: string): TSkillActionBuilder; overload;
    function WithParam(const AName: string; AValue: Integer): TSkillActionBuilder; overload;
    function WithParam(const AName: string; AValue: Boolean): TSkillActionBuilder; overload;
    function WithParam(const AName: string; AValue: Double): TSkillActionBuilder; overload;
    function WithParamExpr(const AName, AExpression: string): TSkillActionBuilder;
    function WithTimeout(ATimeoutMs: Integer): TSkillActionBuilder;
    function WithRetry(ACount: Integer; ADelayMs: Integer = 1000): TSkillActionBuilder;
    function MapResultTo(const AResultField, AContextVar: string): TSkillActionBuilder;
    function OnError(AHandling: TSkillErrorHandling): TSkillActionBuilder;

    function Build: TSkillActionConfig;
  end;

  //----------------------------------------------------------------------------
  // Helper functions
  //----------------------------------------------------------------------------

  function SkillAction(const ASkillName: string): TSkillActionBuilder;

implementation

uses
  System.Rtti,
  System.StrUtils,
  System.RegularExpressions;

//------------------------------------------------------------------------------
// TSkillActionConfig
//------------------------------------------------------------------------------

constructor TSkillActionConfig.Create;
begin
  inherited Create;
  FParams := TJSONObject.Create;
  FResultMapping := TDictionary<string, string>.Create;
  FTimeoutMs := 30000;
  FRetryCount := 0;
  FRetryDelayMs := 1000;
  FErrorHandling := ehRaise;
end;

destructor TSkillActionConfig.Destroy;
begin
  FParams.Free;
  FResultMapping.Free;
  inherited Destroy;
end;

procedure TSkillActionConfig.AddParam(const AName, AValue: string);
begin
  FParams.RemovePair(AName);
  FParams.AddPair(AName, AValue);
end;

procedure TSkillActionConfig.AddParam(const AName: string; AValue: Integer);
begin
  FParams.RemovePair(AName);
  FParams.AddPair(AName, TJSONNumber.Create(AValue));
end;

procedure TSkillActionConfig.AddParam(const AName: string; AValue: Boolean);
begin
  FParams.RemovePair(AName);
  FParams.AddPair(AName, TJSONBool.Create(AValue));
end;

procedure TSkillActionConfig.AddParam(const AName: string; AValue: Double);
begin
  FParams.RemovePair(AName);
  FParams.AddPair(AName, TJSONNumber.Create(AValue));
end;

procedure TSkillActionConfig.AddParamExpr(const AName, AExpression: string);
begin
  // Store expression with special prefix for later resolution
  FParams.RemovePair(AName);
  FParams.AddPair(AName, '${' + AExpression + '}');
end;

procedure TSkillActionConfig.MapResult(const AResultField, AContextVar: string);
begin
  FResultMapping.AddOrSetValue(AResultField, AContextVar);
end;

function TSkillActionConfig.ToJSON: TJSONObject;
var
  MappingObj: TJSONObject;
  Pair: TPair<string, string>;
begin
  Result := TJSONObject.Create;
  Result.AddPair('skill_name', FSkillName);
  Result.AddPair('params', FParams.Clone as TJSONObject);
  Result.AddPair('timeout_ms', TJSONNumber.Create(FTimeoutMs));
  Result.AddPair('retry_count', TJSONNumber.Create(FRetryCount));
  Result.AddPair('retry_delay_ms', TJSONNumber.Create(FRetryDelayMs));

  MappingObj := TJSONObject.Create;
  for Pair in FResultMapping do
    MappingObj.AddPair(Pair.Key, Pair.Value);
  Result.AddPair('result_mapping', MappingObj);
end;

class function TSkillActionConfig.FromJSON(const AJSON: TJSONObject): TSkillActionConfig;
var
  MappingObj: TJSONObject;
  Pair: TJSONPair;
  ParamsObj: TJSONObject;
begin
  Result := TSkillActionConfig.Create;
  Result.SkillName := AJSON.GetValue<string>('skill_name', '');
  Result.TimeoutMs := AJSON.GetValue<Integer>('timeout_ms', 30000);
  Result.RetryCount := AJSON.GetValue<Integer>('retry_count', 0);
  Result.RetryDelayMs := AJSON.GetValue<Integer>('retry_delay_ms', 1000);

  if AJSON.TryGetValue<TJSONObject>('params', ParamsObj) then
  begin
    Result.FParams.Free;
    Result.FParams := ParamsObj.Clone as TJSONObject;
  end;

  if AJSON.TryGetValue<TJSONObject>('result_mapping', MappingObj) then
  begin
    for Pair in MappingObj do
      Result.ResultMapping.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
  end;
end;

//------------------------------------------------------------------------------
// TSkillActionResult
//------------------------------------------------------------------------------

constructor TSkillActionResult.Create;
begin
  inherited Create;
  FSuccess := False;
end;

destructor TSkillActionResult.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

//------------------------------------------------------------------------------
// TSkillActionExecutor
//------------------------------------------------------------------------------

constructor TSkillActionExecutor.Create(AClient: TSkillClient; AOwnsClient: Boolean);
begin
  inherited Create;
  FClient := AClient;
  FOwnsClient := AOwnsClient;
  FDefaultTimeout := 30000;
  FDefaultRetryCount := 0;
end;

constructor TSkillActionExecutor.Create(const ABaseURL: string);
begin
  Create(TSkillClient.Create(ABaseURL), True);
end;

destructor TSkillActionExecutor.Destroy;
begin
  if FOwnsClient then
    FClient.Free;
  inherited Destroy;
end;

function TSkillActionExecutor.ResolveParams(const AParams: TJSONObject;
  const AResolver: TContextResolver): TJSONObject;
var
  Pair: TJSONPair;
  Value, ResolvedStr: string;
  ResolvedValue: TValue;
  Match: TMatch;
begin
  Result := TJSONObject.Create;

  for Pair in AParams do
  begin
    if Pair.JsonValue is TJSONString then
    begin
      Value := Pair.JsonValue.Value;
      // Check for expression: ${expression}
      if Value.StartsWith('${') and Value.EndsWith('}') and Assigned(AResolver) then
      begin
        ResolvedStr := Copy(Value, 3, Length(Value) - 3);
        ResolvedValue := AResolver(ResolvedStr);

        // Convert TValue to JSON
        case ResolvedValue.Kind of
          tkInteger, tkInt64:
            Result.AddPair(Pair.JsonString.Value,
              TJSONNumber.Create(ResolvedValue.AsInt64));
          tkFloat:
            Result.AddPair(Pair.JsonString.Value,
              TJSONNumber.Create(ResolvedValue.AsExtended));
          tkEnumeration:
            if ResolvedValue.TypeInfo = TypeInfo(Boolean) then
              Result.AddPair(Pair.JsonString.Value,
                TJSONBool.Create(ResolvedValue.AsBoolean))
            else
              Result.AddPair(Pair.JsonString.Value, ResolvedValue.ToString);
        else
          Result.AddPair(Pair.JsonString.Value, ResolvedValue.ToString);
        end;
      end
      else
        Result.AddPair(Pair.JsonString.Value, Value);
    end
    else
      Result.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue);
  end;
end;

function TSkillActionExecutor.ExtractValue(const AData: TJSONValue;
  const APath: string): TValue;
var
  Parts: TArray<string>;
  Current: TJSONValue;
  Part: string;
  Obj: TJSONObject;
  Arr: TJSONArray;
  Index: Integer;
begin
  Result := TValue.Empty;
  Current := AData;

  if APath = '' then
  begin
    if Current is TJSONString then
      Result := TJSONString(Current).Value
    else if Current is TJSONNumber then
      Result := TJSONNumber(Current).AsDouble
    else if Current is TJSONBool then
      Result := TJSONBool(Current).AsBoolean
    else
      Result := Current.ToString;
    Exit;
  end;

  Parts := APath.Split(['.']);
  for Part in Parts do
  begin
    if Current = nil then
      Exit;

    // Handle array index: field[0]
    if Part.Contains('[') then
    begin
      if Current is TJSONObject then
      begin
        Obj := Current as TJSONObject;
        Current := Obj.GetValue(Part.Substring(0, Part.IndexOf('[')));
      end;

      if Current is TJSONArray then
      begin
        Arr := Current as TJSONArray;
        Index := StrToIntDef(Part.Substring(Part.IndexOf('[') + 1,
          Part.IndexOf(']') - Part.IndexOf('[') - 1), 0);
        if (Index >= 0) and (Index < Arr.Count) then
          Current := Arr.Items[Index]
        else
          Exit;
      end;
    end
    else if Current is TJSONObject then
    begin
      Obj := Current as TJSONObject;
      Current := Obj.GetValue(Part);
    end
    else
      Exit;
  end;

  if Current <> nil then
  begin
    if Current is TJSONString then
      Result := TJSONString(Current).Value
    else if Current is TJSONNumber then
      Result := TJSONNumber(Current).AsDouble
    else if Current is TJSONBool then
      Result := TJSONBool(Current).AsBoolean
    else
      Result := Current.ToString;
  end;
end;

procedure TSkillActionExecutor.ApplyResultMapping(const AResult: TSkillActionResult;
  const AMapping: TDictionary<string, string>;
  const AUpdater: TContextUpdater);
var
  Pair: TPair<string, string>;
  Value: TValue;
begin
  if not Assigned(AUpdater) or (AResult.Data = nil) then
    Exit;

  for Pair in AMapping do
  begin
    Value := ExtractValue(AResult.Data, Pair.Key);
    if not Value.IsEmpty then
      AUpdater(Pair.Value, Value);
  end;
end;

function TSkillActionExecutor.Execute(const AConfig: TSkillActionConfig;
  const AResolver: TContextResolver;
  const AUpdater: TContextUpdater): TSkillActionResult;
var
  Request: TSkillRequest;
  Response: TSkillResponse;
  ResolvedParams: TJSONObject;
  Attempt: Integer;
  MaxAttempts: Integer;
  LastError: string;
begin
  Result := TSkillActionResult.Create;
  Result.SkillName := AConfig.SkillName;

  MaxAttempts := AConfig.RetryCount + 1;
  LastError := '';

  for Attempt := 1 to MaxAttempts do
  begin
    try
      Result.RetryAttempts := Attempt - 1;

      // Resolve parameters
      ResolvedParams := ResolveParams(AConfig.Params, AResolver);
      try
        // Create request
        Request := TSkillRequest.Create;
        try
          Request.SkillName := AConfig.SkillName;
          Request.FParams.Free;
          Request.FParams := ResolvedParams.Clone as TJSONObject;
          Request.TimeoutMs := AConfig.TimeoutMs;

          // Execute
          Response := FClient.ExecuteSkill(Request);
          try
            Result.Success := Response.IsSuccess;
            Result.ExecutionTimeMs := Response.ExecutionTimeMs;

            if Response.IsSuccess then
            begin
              if Assigned(Response.Result) then
                Result.FData := Response.Result.Clone as TJSONValue;

              // Apply result mapping
              ApplyResultMapping(Result, AConfig.ResultMapping, AUpdater);
              Exit;
            end
            else
            begin
              Result.Error := Response.Error;
              LastError := Response.Error;
            end;

          finally
            Response.Free;
          end;

        finally
          Request.Free;
        end;

      finally
        ResolvedParams.Free;
      end;

    except
      on E: Exception do
      begin
        LastError := E.Message;
        Result.Error := E.Message;
      end;
    end;

    // Retry delay
    if Attempt < MaxAttempts then
      Sleep(AConfig.RetryDelayMs);
  end;

  // Handle error based on strategy
  case AConfig.ErrorHandling of
    ehRaise:
      raise ESkillException.Create(LastError);
    ehIgnore:
      Result.Success := True;  // Mark as success despite error
    ehDefault:
      ; // Keep default values
  end;
end;

function TSkillActionExecutor.ExecuteCode(const ACode: string;
  const AVariables: TJSONObject;
  const AReturnVar: string): TSkillActionResult;
var
  Config: TSkillActionConfig;
begin
  Config := TSkillActionConfig.Create;
  try
    Config.SkillName := 'code_executor';
    Config.AddParam('code', ACode);
    Config.AddParam('return_var', AReturnVar);

    if Assigned(AVariables) then
    begin
      Config.FParams.RemovePair('variables');
      Config.FParams.AddPair('variables', AVariables.Clone as TJSONObject);
    end;

    Result := Execute(Config);
  finally
    Config.Free;
  end;
end;

function TSkillActionExecutor.ExecuteLLM(const AMessages: TObjectList<TLLMMessage>;
  const AModel: string;
  ATemperature: Double;
  AMaxTokens: Integer): TSkillActionResult;
var
  Request: TLLMRequest;
  Response: TLLMResponse;
  Msg: TLLMMessage;
begin
  Result := TSkillActionResult.Create;
  Result.SkillName := 'llm_chat';

  Request := TLLMRequest.Create;
  try
    if AModel <> '' then
      Request.Model := AModel;
    Request.Temperature := ATemperature;
    Request.MaxTokens := AMaxTokens;

    for Msg in AMessages do
      Request.Messages.Add(TLLMMessage.Create(Msg.Role, Msg.Content));

    try
      Response := FClient.Chat(Request);
      try
        Result.Success := True;
        Result.FData := TJSONObject.Create;
        TJSONObject(Result.FData).AddPair('content', Response.Content);
        TJSONObject(Result.FData).AddPair('model', Response.Model);
        TJSONObject(Result.FData).AddPair('finish_reason', Response.FinishReason);
        TJSONObject(Result.FData).AddPair('usage', Response.Usage.ToJSON);
      finally
        Response.Free;
      end;
    except
      on E: Exception do
      begin
        Result.Success := False;
        Result.Error := E.Message;
      end;
    end;

  finally
    Request.Free;
  end;
end;

function TSkillActionExecutor.QueryLLM(const AUserMessage: string;
  const ASystemPrompt: string;
  const AModel: string): string;
begin
  Result := FClient.SimpleChat(AUserMessage, ASystemPrompt, AModel);
end;

//------------------------------------------------------------------------------
// TSkillActionBuilder
//------------------------------------------------------------------------------

constructor TSkillActionBuilder.Create(const ASkillName: string);
begin
  inherited Create;
  FConfig := TSkillActionConfig.Create;
  FConfig.SkillName := ASkillName;
end;

destructor TSkillActionBuilder.Destroy;
begin
  // Don't free FConfig - it's returned via Build
  inherited Destroy;
end;

function TSkillActionBuilder.WithParam(const AName, AValue: string): TSkillActionBuilder;
begin
  FConfig.AddParam(AName, AValue);
  Result := Self;
end;

function TSkillActionBuilder.WithParam(const AName: string; AValue: Integer): TSkillActionBuilder;
begin
  FConfig.AddParam(AName, AValue);
  Result := Self;
end;

function TSkillActionBuilder.WithParam(const AName: string; AValue: Boolean): TSkillActionBuilder;
begin
  FConfig.AddParam(AName, AValue);
  Result := Self;
end;

function TSkillActionBuilder.WithParam(const AName: string; AValue: Double): TSkillActionBuilder;
begin
  FConfig.AddParam(AName, AValue);
  Result := Self;
end;

function TSkillActionBuilder.WithParamExpr(const AName, AExpression: string): TSkillActionBuilder;
begin
  FConfig.AddParamExpr(AName, AExpression);
  Result := Self;
end;

function TSkillActionBuilder.WithTimeout(ATimeoutMs: Integer): TSkillActionBuilder;
begin
  FConfig.TimeoutMs := ATimeoutMs;
  Result := Self;
end;

function TSkillActionBuilder.WithRetry(ACount: Integer; ADelayMs: Integer): TSkillActionBuilder;
begin
  FConfig.RetryCount := ACount;
  FConfig.RetryDelayMs := ADelayMs;
  Result := Self;
end;

function TSkillActionBuilder.MapResultTo(const AResultField, AContextVar: string): TSkillActionBuilder;
begin
  FConfig.MapResult(AResultField, AContextVar);
  Result := Self;
end;

function TSkillActionBuilder.OnError(AHandling: TSkillErrorHandling): TSkillActionBuilder;
begin
  FConfig.ErrorHandling := AHandling;
  Result := Self;
end;

function TSkillActionBuilder.Build: TSkillActionConfig;
begin
  Result := FConfig;
  FConfig := nil;  // Transfer ownership
end;

//------------------------------------------------------------------------------
// Helper functions
//------------------------------------------------------------------------------

function SkillAction(const ASkillName: string): TSkillActionBuilder;
begin
  Result := TSkillActionBuilder.Create(ASkillName);
end;

end.
