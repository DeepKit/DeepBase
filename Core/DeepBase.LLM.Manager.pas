{ ============================================================================
  DeepBase.LLM.Manager - LLM Prompt Management System
  
  Version: 1.0
  Description: Provides unified LLM prompt management with version control,
               meta-prompt merging, BoundQuery context building, and testing.
  
  Features:
    - 4-level prompt categorization
    - Up to 4 versions per prompt with production flag
    - Meta-prompt merging (PREFIX/SUFFIX/WRAP)
    - BoundQuery context injection via DoQry
    - LLM configuration management
    - Call hiDeepStory and statistics tracking
  ============================================================================ }

unit DeepBase.LLM.Manager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  System.SyncObjs,
  System.Threading,
  System.DateUtils,
  DeepBase.Types,
  DeepBase.LLM,
  DeepBase.Logging,
  DeepBase.StorageFactory;

type
  // Forward declarations
  TLLMManager = class;
  
  /// <summary>
  /// Variable type for prompt variables
  /// </summary>
  TPromptVariableType = (
    pvtString,    // �ַ���
    pvtNumber,    // ��ֵ
    pvtBoolean,   // ����
    pvtDate,      // ����
    pvtDateTime,  // ����ʱ��
    pvtList,      // �б�/����
    pvtJson       // JSON����
  );
  
  /// <summary>
  /// Prompt variable definition
  /// </summary>
  TPromptVariable = record
    Name: string;              // ������
    VarType: TPromptVariableType;  // ��������
    DefaultValue: Variant;     // Ĭ��ֵ
    Description: string;       // ˵��
    Required: Boolean;         // �Ƿ����
    
    function TypeToStr: string;
    class function StrToType(const S: string): TPromptVariableType; static;
  end;
  TPromptVariableArray = TArray<TPromptVariable>;
  
  /// <summary>
  /// Meta-prompt merge mode
  /// </summary>
  TMetaMergeMode = (
    mmPrefix,     // ǰ׺ģʽ��Ԫ��ʾ�� + ��ʾ��
    mmSuffix,     // ��׺ģʽ����ʾ�� + Ԫ��ʾ��
    mmWrap        // ����ģʽ��Ԫ��ʾ��ǰ�� + ��ʾ�� + Ԫ��ʾ�ʺ��
  );
  
  /// <summary>
  /// Meta-prompt category
  /// </summary>
  TMetaCategory = (
    mcSecurity,   // ��ȫԼ��
    mcFormat,     // �����ʽ
    mcRole,       // ��ɫ�趨
    mcDomain,     // ����֪ʶ
    mcQuality     // ����Ҫ��
  );
  
  /// <summary>
  /// Prompt category (4-level tree node)
  /// </summary>
  TPromptCategory = record
    Id: Integer;
    ParentId: Integer;
    Level: Integer;           // 1-4
    Code: string;             // �� '01', '02'
    Name: string;
    Description: string;
    SortOrder: Integer;
    IsActive: Boolean;
    
    function FullPath: string;
  end;
  TPromptCategoryArray = TArray<TPromptCategory>;
  
  /// <summary>
  /// Prompt version
  /// </summary>
  TPromptVersion = record
    Id: Integer;
    PromptId: Integer;
    VersionNumber: Integer;   // 1-4
    Content: string;          // ��ʾ������
    IsProduction: Boolean;    // �Ƿ�Ϊ�����汾
    TestCount: Integer;
    SuccessCount: Integer;
    TotalTokens: Integer;
    TotalCost: Double;
    AvgDuration: Double;      // ƽ����ʱ(ms)
    LastTestedAt: TDateTime;
    LastResponse: string;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    
    function SuccessRate: Double;
  end;
  TPromptVersionArray = TArray<TPromptVersion>;
  
  /// <summary>
  /// Meta-prompt
  /// </summary>
  TMetaPrompt = record
    Id: Integer;
    InternalCode: string;     // �� 'META-001'
    Name: string;
    Category: TMetaCategory;
    Content: string;
    MergeMode: TMetaMergeMode;
    Priority: Integer;        // �ϲ����ȼ� (����С���Ⱥϲ�)
    Level: Integer;           // 0=��ܼ�, 1=��Ŀ��
    IsActive: Boolean;
    
    function CategoryToStr: string;
    function MergeModeToStr: string;
    class function StrToCategory(const S: string): TMetaCategory; static;
    class function StrToMergeMode(const S: string): TMetaMergeMode; static;
  end;
  TMetaPromptArray = TArray<TMetaPrompt>;
  
  /// <summary>
  /// Main prompt record
  /// </summary>
  TPrompt = record
    Id: Integer;
    CategoryId: Integer;
    InternalCode: string;     // �� '01-01-001'
    Name: string;
    Description: string;
    BoundQueryName: string;   // �󶨵� DoQry ��ѯ��
    Variables: TPromptVariableArray;
    IsActive: Boolean;
    CreatedAt: TDateTime;
    UpdatedAt: TDateTime;
    
    // Populated on load
    Versions: TPromptVersionArray;
    MetaPrompts: TMetaPromptArray;
    CategoryPath: string;     // �� 'ϵͳ��ʾ��/����/ͨ��'
    
    function GetProductionVersion: Integer;
    function GetVersion(AVersionNum: Integer): TPromptVersion;
    function HasVersion(AVersionNum: Integer): Boolean;
  end;
  TPromptArray = TArray<TPrompt>;
  
  /// <summary>
  /// LLM response
  /// </summary>
  TLLMResponse = record
    Success: Boolean;
    Content: string;
    FinishReason: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    TotalTokens: Integer;
    DurationMs: Int64;
    ErrorCode: string;
    ErrorMessage: string;
    PromptId: Integer;
    VersionNumber: Integer;
    ConfigName: string;
    Cost: Double;
    
    procedure Init;
  end;
  
  /// <summary>
  /// Async callback
  /// </summary>
  TLLMResponseCallback = reference to procedure(const Response: TLLMResponse);
  
  /// <summary>
  /// Context builder function type (for BoundQuery)
  /// </summary>
  TContextBuilderFunc = reference to function(const QueryName: string; 
    const Params: TDictionary<string, Variant>): string;
  
  /// <summary>
  /// LLM Prompt Manager - Main management class
  /// </summary>
  TLLMManager = class
  private
    FConnection: TObject;
    FStorage: ILLMStorage;
    FLLMClient: TDeepBaseLLM;
    FPromptCache: TDictionary<string, TPrompt>;  // InternalCode -> TPrompt
    FCategoryCache: TDictionary<Integer, TPromptCategory>;  // Id -> TPromptCategory
    FMetaCache: TDictionary<Integer, TMetaPrompt>;  // Id -> TMetaPrompt
    FCacheLock: TCriticalSection;
    FContextBuilder: TContextBuilderFunc;
    FOwnsConnection: Boolean;
    // BIZ2-006 fix: track ExecuteAsync tasks so Destroy can wait for them
    // before freeing fields the closures still reference.
    FExecuteTasks: TList<ITask>;
    FExecuteTasksLock: TCriticalSection;

    procedure LoadCategories;
    procedure LoadPrompts;
    procedure LoadMetaPrompts;
    procedure LoadPromptVersions(var Prompt: TPrompt);
    procedure LoadPromptMetaBindings(var Prompt: TPrompt);
    function BuildCategoryPath(CategoryId: Integer): string;
    function MergeMetaPrompts(const Prompt: TPrompt; VersionNum: Integer): string;
    function ReplaceVariables(const Template: string; const Params: TDictionary<string, Variant>): string;
    function BuildContext(const Prompt: TPrompt; const Params: TDictionary<string, Variant>): string;
    procedure RecordLLMCall(const Prompt: TPrompt; VersionNum: Integer; const ConfigName: string;
      const FinalPrompt: string; const Response: TLLMResponse);
    procedure UpdateVersionStats(PromptId, VersionNum: Integer; const Response: TLLMResponse);
    function GetStorage: ILLMStorage;
    function HasActiveConnection: Boolean;
    function IsPG: Boolean;
    procedure EnsurePromptSchema;

  public
    constructor Create(AConnection: TObject; AOwnsConnection: Boolean = False); overload;
    constructor Create(const AStorage: ILLMStorage); overload;
    destructor Destroy; override;
    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, ILLMStorage>); static;
    
    /// <summary>Initialize and load data from database</summary>
    procedure Initialize;
    
    /// <summary>Refresh cache from database</summary>
    procedure RefreshCache;
    
    // ========================================================================
    // Category Management
    // ========================================================================
    
    /// <summary>Get all categories</summary>
    function GetCategories: TPromptCategoryArray;
    
    /// <summary>Get categories by level</summary>
    function GetCategoriesByLevel(Level: Integer): TPromptCategoryArray;
    
    /// <summary>Get child categories</summary>
    function GetChildCategories(ParentId: Integer): TPromptCategoryArray;
    
    /// <summary>Save category</summary>
    procedure SaveCategory(var Category: TPromptCategory);
    
    /// <summary>Delete category</summary>
    procedure DeleteCategory(CategoryId: Integer);
    
    // ========================================================================
    // Prompt Management
    // ========================================================================
    
    /// <summary>Get prompt by internal code</summary>
    function GetPrompt(const InternalCode: string): TPrompt;
    
    /// <summary>Get prompts by category</summary>
    function GetPromptsByCategory(CategoryId: Integer): TPromptArray;
    
    /// <summary>Get all prompts</summary>
    function GetAllPrompts: TPromptArray;
    
    /// <summary>Save prompt</summary>
    procedure SavePrompt(var Prompt: TPrompt);
    
    /// <summary>Delete prompt</summary>
    procedure DeletePrompt(const InternalCode: string);
    
    /// <summary>Check if prompt exists</summary>
    function PromptExists(const InternalCode: string): Boolean;
    
    // ========================================================================
    // Version Management
    // ========================================================================
    
    /// <summary>Get prompt version</summary>
    function GetVersion(const InternalCode: string; VersionNum: Integer): TPromptVersion;
    
    /// <summary>Save version</summary>
    procedure SaveVersion(const InternalCode: string; var Version: TPromptVersion);
    
    /// <summary>Set production version</summary>
    procedure SetProductionVersion(const InternalCode: string; VersionNum: Integer);
    
    /// <summary>Delete version</summary>
    procedure DeleteVersion(const InternalCode: string; VersionNum: Integer);

    /// <summary>Delete multiple versions in a single round-trip.</summary>
    /// <remarks>
    ///   BUG-308 (BIZ-013): 批量删除，只触发一次 RefreshCache；底层使用单条
    ///   DELETE + IN 子句，避免逐版本循环导致的多次 SQL 往返与缓存刷新。
    /// </remarks>
    procedure DeleteVersions(const InternalCode: string; const VersionNums: array of Integer);

    /// <summary>Test-only: seed the prompt cache without hitting OpenDataSet.</summary>
    /// <remarks>仅供单元测试注入缓存数据，生产代码请勿调用。</remarks>
    procedure TestSeedPrompt(const InternalCode: string; const Prompt: TPrompt);
    
    // ========================================================================
    // Meta-Prompt Management
    // ========================================================================
    
    /// <summary>Get all meta-prompts</summary>
    function GetMetaPrompts: TMetaPromptArray;
    
    /// <summary>Get meta-prompt by code</summary>
    function GetMetaPrompt(const InternalCode: string): TMetaPrompt;
    
    /// <summary>Save meta-prompt</summary>
    procedure SaveMetaPrompt(var Meta: TMetaPrompt);
    
    /// <summary>Delete meta-prompt</summary>
    procedure DeleteMetaPrompt(const InternalCode: string);
    
    /// <summary>Bind meta-prompt to prompt</summary>
    procedure BindMetaPrompt(const PromptCode, MetaCode: string; OrderIndex: Integer = 0);
    
    /// <summary>Unbind meta-prompt from prompt</summary>
    procedure UnbindMetaPrompt(const PromptCode, MetaCode: string);
    
    // ========================================================================
    // Execution
    // ========================================================================
    
    /// <summary>Execute prompt (use production version)</summary>
    function Execute(const InternalCode: string): TLLMResponse; overload;
    
    /// <summary>Execute prompt with parameters</summary>
    function Execute(const InternalCode: string; 
      const Params: TDictionary<string, Variant>): TLLMResponse; overload;
    
    /// <summary>Execute prompt with specific version and config</summary>
    function Execute(const InternalCode: string;
      const Params: TDictionary<string, Variant>;
      VersionNum: Integer;
      const ConfigName: string = ''): TLLMResponse; overload;
    
    /// <summary>Execute async</summary>
    procedure ExecuteAsync(const InternalCode: string;
      const Params: TDictionary<string, Variant>;
      OnComplete: TLLMResponseCallback;
      VersionNum: Integer = 0;
      const ConfigName: string = '');
    
    /// <summary>Build final prompt (for preview/debugging)</summary>
    function BuildFinalPrompt(const InternalCode: string;
      const Params: TDictionary<string, Variant>;
      VersionNum: Integer = 0): string;
    
    // ========================================================================
    // Testing
    // ========================================================================
    
    /// <summary>Test prompt version</summary>
    function TestVersion(const InternalCode: string; VersionNum: Integer;
      const Params: TDictionary<string, Variant>;
      const ConfigName: string = ''): TLLMResponse;
    
    /// <summary>Compare multiple versions</summary>
    function CompareVersions(const InternalCode: string;
      const VersionNums: array of Integer;
      const Params: TDictionary<string, Variant>;
      const ConfigName: string = ''): TArray<TLLMResponse>;
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property Connection: TObject read FConnection;
    property LLMClient: TDeepBaseLLM read FLLMClient;
    property ContextBuilder: TContextBuilderFunc read FContextBuilder write FContextBuilder;
  end;

/// <summary>Parse variables JSON</summary>
function ParseVariablesJson(const Json: string): TPromptVariableArray;

/// <summary>Variables to JSON</summary>
function VariablesToJson(const Variables: TPromptVariableArray): string;

implementation

uses
  Data.DB,
  System.Variants,
  System.StrUtils,
  DeepBase.Schema,
  DeepBase.SQL.Splitter;

{ Helper Functions }

function LLMParam(const AName: string;
  const AValue: Variant): TLLMStorageParam;
begin
  Result := TLLMStorageParam.Create(AName, AValue);
end;

function ParseVariablesJson(const Json: string): TPromptVariableArray;
var
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  I: Integer;
  V: TPromptVariable;
begin
  SetLength(Result, 0);
  if Json = '' then
    Exit;
    
  try
    JsonArray := TJSONObject.ParseJSONValue(Json) as TJSONArray;
    if JsonArray = nil then
      Exit;
      
    try
      SetLength(Result, JsonArray.Count);
      for I := 0 to JsonArray.Count - 1 do
      begin
        JsonObj := JsonArray.Items[I] as TJSONObject;
        V.Name := JsonObj.GetValue<string>('name', '');
        V.VarType := TPromptVariable.StrToType(JsonObj.GetValue<string>('type', 'string'));
        V.Description := JsonObj.GetValue<string>('description', '');
        V.Required := JsonObj.GetValue<Boolean>('required', False);
        
        // Parse default value based on type
        case V.VarType of
          pvtNumber:
            V.DefaultValue := JsonObj.GetValue<Double>('default', 0);
          pvtBoolean:
            V.DefaultValue := JsonObj.GetValue<Boolean>('default', False);
        else
          V.DefaultValue := JsonObj.GetValue<string>('default', '');
        end;
        
        Result[I] := V;
      end;
    finally
      JsonArray.Free;
    end;
  except
    SetLength(Result, 0);
  end;
end;

function VariablesToJson(const Variables: TPromptVariableArray): string;
var
  JsonArray: TJSONArray;
  JsonObj: TJSONObject;
  V: TPromptVariable;
begin
  JsonArray := TJSONArray.Create;
  try
    for V in Variables do
    begin
      JsonObj := TJSONObject.Create;
      JsonObj.AddPair('name', V.Name);
      JsonObj.AddPair('type', V.TypeToStr);
      JsonObj.AddPair('description', V.Description);
      JsonObj.AddPair('required', TJSONBool.Create(V.Required));
      
      case V.VarType of
        pvtNumber:
          JsonObj.AddPair('default', TJSONNumber.Create(Double(V.DefaultValue)));
        pvtBoolean:
          JsonObj.AddPair('default', TJSONBool.Create(Boolean(V.DefaultValue)));
      else
        JsonObj.AddPair('default', VarToStr(V.DefaultValue));
      end;
      
      JsonArray.Add(JsonObj);
    end;
    
    Result := JsonArray.ToJSON;
  finally
    JsonArray.Free;
  end;
end;

{ TPromptVariable }

function TPromptVariable.TypeToStr: string;
begin
  case VarType of
    pvtString:   Result := 'string';
    pvtNumber:   Result := 'number';
    pvtBoolean:  Result := 'boolean';
    pvtDate:     Result := 'date';
    pvtDateTime: Result := 'datetime';
    pvtList:     Result := 'list';
    pvtJson:     Result := 'json';
  else
    Result := 'string';
  end;
end;

class function TPromptVariable.StrToType(const S: string): TPromptVariableType;
var
  Lower: string;
begin
  Lower := LowerCase(Trim(S));
  if Lower = 'number' then Result := pvtNumber
  else if Lower = 'boolean' then Result := pvtBoolean
  else if Lower = 'date' then Result := pvtDate
  else if Lower = 'datetime' then Result := pvtDateTime
  else if Lower = 'list' then Result := pvtList
  else if Lower = 'json' then Result := pvtJson
  else Result := pvtString;
end;

{ TPromptCategory }

function TPromptCategory.FullPath: string;
begin
  // This should be set by BuildCategoryPath
  Result := Name;
end;

{ TPromptVersion }

function TPromptVersion.SuccessRate: Double;
begin
  if TestCount > 0 then
    Result := SuccessCount / TestCount * 100
  else
    Result := 0;
end;

{ TMetaPrompt }

function TMetaPrompt.CategoryToStr: string;
begin
  case Category of
    mcSecurity: Result := 'security';
    mcFormat:   Result := 'format';
    mcRole:     Result := 'role';
    mcDomain:   Result := 'domain';
    mcQuality:  Result := 'quality';
  else
    Result := 'security';
  end;
end;

function TMetaPrompt.MergeModeToStr: string;
begin
  case MergeMode of
    mmPrefix: Result := 'PREFIX';
    mmSuffix: Result := 'SUFFIX';
    mmWrap:   Result := 'WRAP';
  else
    Result := 'PREFIX';
  end;
end;

class function TMetaPrompt.StrToCategory(const S: string): TMetaCategory;
var
  Lower: string;
begin
  Lower := LowerCase(Trim(S));
  if Lower = 'format' then Result := mcFormat
  else if Lower = 'role' then Result := mcRole
  else if Lower = 'domain' then Result := mcDomain
  else if Lower = 'quality' then Result := mcQuality
  else Result := mcSecurity;
end;

class function TMetaPrompt.StrToMergeMode(const S: string): TMetaMergeMode;
var
  Upper: string;
begin
  Upper := UpperCase(Trim(S));
  if Upper = 'SUFFIX' then Result := mmSuffix
  else if Upper = 'WRAP' then Result := mmWrap
  else Result := mmPrefix;
end;

{ TPrompt }

function TPrompt.GetProductionVersion: Integer;
var
  V: TPromptVersion;
begin
  Result := 0;
  for V in Versions do
    if V.IsProduction then
    begin
      Result := V.VersionNumber;
      Break;
    end;
  // If no production version, use first available
  if (Result = 0) and (Length(Versions) > 0) then
    Result := Versions[0].VersionNumber;
end;

function TPrompt.GetVersion(AVersionNum: Integer): TPromptVersion;
var
  V: TPromptVersion;
begin
  Result.Id := 0;
  Result.VersionNumber := 0;
  
  for V in Versions do
    if V.VersionNumber = AVersionNum then
    begin
      Result := V;
      Break;
    end;
end;

function TPrompt.HasVersion(AVersionNum: Integer): Boolean;
var
  V: TPromptVersion;
begin
  Result := False;
  for V in Versions do
    if V.VersionNumber = AVersionNum then
    begin
      Result := True;
      Break;
    end;
end;

{ TLLMResponse }

procedure TLLMResponse.Init;
begin
  Success := False;
  Content := '';
  FinishReason := '';
  InputTokens := 0;
  OutputTokens := 0;
  TotalTokens := 0;
  DurationMs := 0;
  ErrorCode := '';
  ErrorMessage := '';
  PromptId := 0;
  VersionNumber := 0;
  ConfigName := '';
  Cost := 0;
end;

{ TLLMManager }

constructor TLLMManager.Create(AConnection: TObject; AOwnsConnection: Boolean);
var
  LStorage: ILLMStorage;
begin
  LStorage := nil;
  if Supports(AConnection, ILLMStorage, LStorage) then
  else
    LStorage := TConnectionStorageFactory<ILLMStorage>.Create(AConnection);
  if (LStorage = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No LLM manager storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.LLM.FireDAC.');
  Create(LStorage);
  FConnection := AConnection;
  FOwnsConnection := AOwnsConnection;
  FreeAndNil(FLLMClient);
  FLLMClient := TDeepBaseLLM.Create(AConnection);
end;

constructor TLLMManager.Create(const AStorage: ILLMStorage);
begin
  inherited Create;
  FConnection := nil;
  FStorage := AStorage;
  FOwnsConnection := False;
  FLLMClient := TDeepBaseLLM.Create(AStorage);
  FPromptCache := TDictionary<string, TPrompt>.Create;
  FCategoryCache := TDictionary<Integer, TPromptCategory>.Create;
  FMetaCache := TDictionary<Integer, TMetaPrompt>.Create;
  FCacheLock := TCriticalSection.Create;
  FContextBuilder := nil;
  // BIZ2-006 fix: initialize execute-task tracking
  FExecuteTasks := TList<ITask>.Create;
  FExecuteTasksLock := TCriticalSection.Create;
end;

class procedure TLLMManager.SetStorageFactory(
  const AFactory: TFunc<TObject, ILLMStorage>);
begin
  TConnectionStorageFactory<ILLMStorage>.SetFactory(AFactory);
end;

function TLLMManager.GetStorage: ILLMStorage;
begin
  Result := FStorage;
end;

function TLLMManager.HasActiveConnection: Boolean;
var
  Storage: ILLMStorage;
begin
  Storage := GetStorage;
  Result := Assigned(Storage) and Storage.IsConnected;
end;

function TLLMManager.IsPG: Boolean;
begin
  Result := Assigned(FStorage) and FStorage.IsPostgreSQL;
end;

destructor TLLMManager.Destroy;
var
  LLocalTasks: TArray<ITask>;
  LT: ITask;
  LWaited: Boolean;
  LAnyTimeout: Boolean;
begin
  // BIZ2-006 fix: wait for pending ExecuteAsync tasks before freeing fields
  // their closures reference (FLLMClient, FPromptCache, etc.).
  // BIZ-R3-002 fix: the previous Wait(5000) was far shorter than an in-flight
  // HTTP call (TLLMClient default timeout is 60s, user-configurable higher),
  // so a still-running ExecuteAsync task could outlive the wait and keep
  // calling FLLMClient.Chat after FreeAndNil(FLLMClient) below -> use-after-free.
  // Now: (1) Cancel each task first so cooperative cleanup paths return early;
  // (2) wait long enough to cover the HTTP timeout window (2x default = 120s);
  // (3) if even that expires, do NOT free the objects the task still touches
  // (FLLMClient, caches, FExecuteTasks/FExecuteTasksLock which the task's
  // finally block also accesses) — leaking them until process exit is safer
  // than a guaranteed use-after-free. Log loudly so the leak is never silent.
  LAnyTimeout := False;
  if Assigned(FExecuteTasks) then
  begin
    FExecuteTasksLock.Enter;
    try
      LLocalTasks := FExecuteTasks.ToArray;
      FExecuteTasks.Clear;
    finally
      FExecuteTasksLock.Leave;
    end;
    for LT in LLocalTasks do
    begin
      if Assigned(LT) then
      begin
        LT.Cancel;
        LWaited := LT.Wait(120000);
        if not LWaited then
        begin
          LAnyTimeout := True;
          if IsLoggerInitialized then
            Logger.LogException(nil,
              Format('TLLMManager.Destroy: ExecuteAsync task %p did not finish ' +
                'within 120s; leaking owned objects to avoid use-after-free ' +
                '(task still touches FLLMClient/caches)', [Pointer(LT)]), llError);
        end;
      end;
    end;
  end;
  if LAnyTimeout then
    // Objects above are still referenced by a running task; skip their teardown.
    Exit;
  FreeAndNil(FExecuteTasks);
  FreeAndNil(FExecuteTasksLock);
  FreeAndNil(FCacheLock);
  FreeAndNil(FMetaCache);
  FreeAndNil(FCategoryCache);
  FreeAndNil(FPromptCache);
  FreeAndNil(FLLMClient);
  if FOwnsConnection then
    FreeAndNil(FConnection);
  inherited;
end;

procedure TLLMManager.Initialize;
begin
  EnsurePromptSchema;
  RefreshCache;
end;

procedure TLLMManager.EnsurePromptSchema;
begin
  if not HasActiveConnection then
    Exit;
  // Only create if the key table is missing — idempotent via CREATE IF NOT EXISTS
  if not FStorage.TableExists('PromptCategories') then
  begin
    var LStatements := TDeepBaseSQLSplitter.Split(GetLLMPromptSchemaSQL);
    for var LSQL in LStatements do
    begin
      var LTrimmed := LSQL.Trim;
      if LTrimmed <> '' then
        FStorage.Execute(LTrimmed, []);
    end;
  end;
end;

procedure TLLMManager.RefreshCache;
begin
  FCacheLock.Enter;
  try
    FPromptCache.Clear;
    FCategoryCache.Clear;
    FMetaCache.Clear;
    
    LoadCategories;
    LoadMetaPrompts;
    LoadPrompts;
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.LoadCategories;
var
  Query: TDataSet;
  Cat: TPromptCategory;
begin
  if not HasActiveConnection then
    Exit;

  if IsPG then
    Query := FStorage.OpenDataSet(
      'SELECT * FROM PromptCategories WHERE IsActive = TRUE ORDER BY Level, SortOrder, Name',
      [])
  else
    Query := FStorage.OpenDataSet(
      'SELECT * FROM PromptCategories WHERE IsActive = 1 ORDER BY Level, SortOrder, Name',
      []);
  try
    while not Query.Eof do
    begin
      Cat.Id := Query.FieldByName('Id').AsInteger;
      Cat.ParentId := Query.FieldByName('ParentId').AsInteger;
      Cat.Level := Query.FieldByName('Level').AsInteger;
      Cat.Code := Query.FieldByName('Code').AsString;
      Cat.Name := Query.FieldByName('Name').AsString;
      Cat.Description := Query.FieldByName('Description').AsString;
      Cat.SortOrder := Query.FieldByName('SortOrder').AsInteger;
      if IsPG then Cat.IsActive := Query.FieldByName('IsActive').AsBoolean else Cat.IsActive := Query.FieldByName('IsActive').AsInteger = 1;
      
      FCategoryCache.AddOrSetValue(Cat.Id, Cat);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TLLMManager.LoadMetaPrompts;
var
  Query: TDataSet;
  Meta: TMetaPrompt;
begin
  if not HasActiveConnection then
    Exit;

  if IsPG then
    Query := FStorage.OpenDataSet(
      'SELECT * FROM PromptMeta WHERE IsActive = TRUE ORDER BY Priority',
      [])
  else
    Query := FStorage.OpenDataSet(
      'SELECT * FROM PromptMeta WHERE IsActive = 1 ORDER BY Priority',
      []);
  try
    while not Query.Eof do
    begin
      Meta.Id := Query.FieldByName('Id').AsInteger;
      Meta.InternalCode := Query.FieldByName('InternalCode').AsString;
      Meta.Name := Query.FieldByName('Name').AsString;
      Meta.Category := TMetaPrompt.StrToCategory(Query.FieldByName('Category').AsString);
      Meta.Content := Query.FieldByName('Content').AsString;
      Meta.MergeMode := TMetaPrompt.StrToMergeMode(Query.FieldByName('MergeMode').AsString);
      Meta.Priority := Query.FieldByName('Priority').AsInteger;
      Meta.Level := Query.FieldByName('Level').AsInteger;
      if IsPG then Meta.IsActive := Query.FieldByName('IsActive').AsBoolean else Meta.IsActive := Query.FieldByName('IsActive').AsInteger = 1;
      
      FMetaCache.AddOrSetValue(Meta.Id, Meta);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TLLMManager.LoadPrompts;
var
  Query: TDataSet;
  Prompt: TPrompt;
begin
  if not HasActiveConnection then
    Exit;

  if IsPG then
    Query := FStorage.OpenDataSet(
      'SELECT * FROM Prompts WHERE IsActive = TRUE ORDER BY InternalCode',
      [])
  else
    Query := FStorage.OpenDataSet(
      'SELECT * FROM Prompts WHERE IsActive = 1 ORDER BY InternalCode',
      []);
  try
    while not Query.Eof do
    begin
      Prompt.Id := Query.FieldByName('Id').AsInteger;
      Prompt.CategoryId := Query.FieldByName('CategoryId').AsInteger;
      Prompt.InternalCode := Query.FieldByName('InternalCode').AsString;
      Prompt.Name := Query.FieldByName('Name').AsString;
      Prompt.Description := Query.FieldByName('Description').AsString;
      Prompt.BoundQueryName := Query.FieldByName('BoundQueryName').AsString;
      Prompt.Variables := ParseVariablesJson(Query.FieldByName('VariablesJson').AsString);
      if IsPG then Prompt.IsActive := Query.FieldByName('IsActive').AsBoolean else Prompt.IsActive := Query.FieldByName('IsActive').AsInteger = 1;
      Prompt.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
      Prompt.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
      Prompt.CategoryPath := BuildCategoryPath(Prompt.CategoryId);
      
      // Load versions and meta bindings
      LoadPromptVersions(Prompt);
      LoadPromptMetaBindings(Prompt);
      
      FPromptCache.AddOrSetValue(Prompt.InternalCode, Prompt);
      Query.Next;
    end;
  finally
    Query.Free;
  end;
end;

procedure TLLMManager.LoadPromptVersions(var Prompt: TPrompt);
var
  Query: TDataSet;
  V: TPromptVersion;
  List: TList<TPromptVersion>;
begin
  List := TList<TPromptVersion>.Create;
  try
    Query := FStorage.OpenDataSet(
      'SELECT * FROM PromptVersions WHERE PromptId = :PromptId ORDER BY VersionNumber',
      [LLMParam('PromptId', Prompt.Id)]);
    try
      while not Query.Eof do
      begin
        V.Id := Query.FieldByName('Id').AsInteger;
        V.PromptId := Query.FieldByName('PromptId').AsInteger;
        V.VersionNumber := Query.FieldByName('VersionNumber').AsInteger;
        V.Content := Query.FieldByName('Content').AsString;
        if IsPG then V.IsProduction := Query.FieldByName('IsProduction').AsBoolean else V.IsProduction := Query.FieldByName('IsProduction').AsInteger = 1;
        V.TestCount := Query.FieldByName('TestCount').AsInteger;
        V.SuccessCount := Query.FieldByName('SuccessCount').AsInteger;
        V.TotalTokens := Query.FieldByName('TotalTokens').AsInteger;
        V.TotalCost := Query.FieldByName('TotalCost').AsFloat;
        V.AvgDuration := Query.FieldByName('AvgDuration').AsFloat;
        V.LastTestedAt := Query.FieldByName('LastTestedAt').AsDateTime;
        V.LastResponse := Query.FieldByName('LastResponse').AsString;
        V.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
        V.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
        
        List.Add(V);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Prompt.Versions := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TLLMManager.LoadPromptMetaBindings(var Prompt: TPrompt);
var
  Query: TDataSet;
  Meta: TMetaPrompt;
  List: TList<TMetaPrompt>;
begin
  List := TList<TMetaPrompt>.Create;
  try
    if IsPG then
      Query := FStorage.OpenDataSet(
        'SELECT m.* FROM PromptMeta m ' +
        'INNER JOIN PromptMetaBinding b ON m.Id = b.MetaPromptId ' +
        'WHERE b.PromptId = :PromptId AND b.IsEnabled = TRUE AND m.IsActive = TRUE ' +
        'ORDER BY m.Priority, b.OrderIndex',
        [LLMParam('PromptId', Prompt.Id)])
    else
      Query := FStorage.OpenDataSet(
        'SELECT m.* FROM PromptMeta m ' +
        'INNER JOIN PromptMetaBinding b ON m.Id = b.MetaPromptId ' +
        'WHERE b.PromptId = :PromptId AND b.IsEnabled = 1 AND m.IsActive = 1 ' +
        'ORDER BY m.Priority, b.OrderIndex',
        [LLMParam('PromptId', Prompt.Id)]);
    try
      while not Query.Eof do
      begin
        Meta.Id := Query.FieldByName('Id').AsInteger;
        Meta.InternalCode := Query.FieldByName('InternalCode').AsString;
        Meta.Name := Query.FieldByName('Name').AsString;
        Meta.Category := TMetaPrompt.StrToCategory(Query.FieldByName('Category').AsString);
        Meta.Content := Query.FieldByName('Content').AsString;
        Meta.MergeMode := TMetaPrompt.StrToMergeMode(Query.FieldByName('MergeMode').AsString);
        Meta.Priority := Query.FieldByName('Priority').AsInteger;
        Meta.Level := Query.FieldByName('Level').AsInteger;
        Meta.IsActive := True;
        
        List.Add(Meta);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Prompt.MetaPrompts := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLLMManager.BuildCategoryPath(CategoryId: Integer): string;
var
  Cat: TPromptCategory;
  Parts: TList<string>;
  CurrentId: Integer;
begin
  Result := '';
  if CategoryId <= 0 then
    Exit;
    
  Parts := TList<string>.Create;
  try
    CurrentId := CategoryId;
    while (CurrentId > 0) and FCategoryCache.TryGetValue(CurrentId, Cat) do
    begin
      Parts.Insert(0, Cat.Name);
      CurrentId := Cat.ParentId;
    end;
    
    Result := string.Join('/', Parts.ToArray);
  finally
    Parts.Free;
  end;
end;

function TLLMManager.MergeMetaPrompts(const Prompt: TPrompt; VersionNum: Integer): string;
var
  Meta: TMetaPrompt;
  Version: TPromptVersion;
  PrefixParts, SuffixParts: TStringList;
  BaseContent: string;
begin
  Version := Prompt.GetVersion(VersionNum);
  if Version.VersionNumber = 0 then
  begin
    Result := '';
    Exit;
  end;
  
  BaseContent := Version.Content;
  
  PrefixParts := TStringList.Create;
  SuffixParts := TStringList.Create;
  try
    for Meta in Prompt.MetaPrompts do
    begin
      case Meta.MergeMode of
        mmPrefix:
          PrefixParts.Add(Meta.Content);
        mmSuffix:
          SuffixParts.Add(Meta.Content);
        mmWrap:
          begin
            // WRAP mode: split at {{content}} placeholder
            var WrapContent := Meta.Content;
            var Pos := System.Pos('{{content}}', LowerCase(WrapContent));
            if Pos > 0 then
            begin
              PrefixParts.Add(Copy(WrapContent, 1, Pos - 1));
              SuffixParts.Add(Copy(WrapContent, Pos + 11, MaxInt));
            end
            else
              PrefixParts.Add(WrapContent);
          end;
      end;
    end;
    
    // Build final prompt
    Result := '';
    if PrefixParts.Count > 0 then
      Result := PrefixParts.Text + #13#10;
    Result := Result + BaseContent;
    if SuffixParts.Count > 0 then
      Result := Result + #13#10 + SuffixParts.Text;
  finally
    SuffixParts.Free;
    PrefixParts.Free;
  end;
end;

function TLLMManager.ReplaceVariables(const Template: string; 
  const Params: TDictionary<string, Variant>): string;
var
  Key: string;
  Value: Variant;
begin
  Result := Template;
  if not Assigned(Params) then
    Exit;
    
  for Key in Params.Keys do
  begin
    Params.TryGetValue(Key, Value);
    Result := StringReplace(Result, '{{' + Key + '}}', VarToStr(Value), [rfReplaceAll, rfIgnoreCase]);
  end;
end;

function TLLMManager.BuildContext(const Prompt: TPrompt;
  const Params: TDictionary<string, Variant>): string;
begin
  Result := '';

  // If BoundQuery is set and we have a context builder, execute it
  if (Prompt.BoundQueryName <> '') and Assigned(FContextBuilder) then
  begin
    try
      Result := FContextBuilder(Prompt.BoundQueryName, Params);
    except
      on E: Exception do
      begin
        // BUG EXP-P2-002 fix: do not leak internal error details (paths, SQL,
        // stack traces) into the context payload that is forwarded to the LLM.
        // Log the full error via the global logger and return a generic message.
        if IsLoggerInitialized then
          Logger.LogException(E, 'BuildContext failed for "' + Prompt.BoundQueryName + '"', llError);
        Result := '{"error": "context builder failed"}';
      end;
    end;
  end;
end;

procedure TLLMManager.RecordLLMCall(const Prompt: TPrompt; VersionNum: Integer;
  const ConfigName: string; const FinalPrompt: string; const Response: TLLMResponse);
var
  Status, NowStr: string;
begin
  if not HasActiveConnection then
    Exit;
    
  if Response.Success then
    Status := 'success'
  else if Response.ErrorCode = 'timeout' then
    Status := 'timeout'
  else if Response.ErrorCode = 'cancelled' then
    Status := 'cancelled'
  else if Response.ErrorCode = 'rate_limited' then
    Status := 'rate_limited'
  else
    Status := 'error';
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

  FStorage.Execute(
    'INSERT INTO LLMCalls (PromptId, VersionNumber, ConfigId, Provider, Model, ' +
    'InputText, OutputText, InputTokens, OutputTokens, TotalTokens, Duration, ' +
    'Cost, Status, ErrorMessage, CreatedAt) ' +
    'VALUES (:PromptId, :VersionNumber, ' +
    '(SELECT Id FROM LLMConfig WHERE Name = :ConfigName), ' +
    ':Provider, :Model, :InputText, :OutputText, :InputTokens, :OutputTokens, ' +
    ':TotalTokens, :Duration, :Cost, :Status, :ErrorMessage, :CreatedAt)',
    [
      LLMParam('PromptId', Prompt.Id),
      LLMParam('VersionNumber', VersionNum),
      LLMParam('ConfigName', ConfigName),
      LLMParam('Provider', ''),
      LLMParam('Model', ''),
      LLMParam('InputText', FinalPrompt),
      LLMParam('OutputText', Response.Content),
      LLMParam('InputTokens', Response.InputTokens),
      LLMParam('OutputTokens', Response.OutputTokens),
      LLMParam('TotalTokens', Response.TotalTokens),
      LLMParam('Duration', Response.DurationMs),
      LLMParam('Cost', Response.Cost),
      LLMParam('Status', Status),
      LLMParam('ErrorMessage', Response.ErrorMessage),
      LLMParam('CreatedAt', NowStr)
    ]);
end;

procedure TLLMManager.UpdateVersionStats(PromptId, VersionNum: Integer; 
  const Response: TLLMResponse);
var
  NowStr: string;
begin
  if not HasActiveConnection then
    Exit;
  
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

  FStorage.Execute(
    'UPDATE PromptVersions SET ' +
    'TestCount = TestCount + 1, ' +
    'SuccessCount = SuccessCount + :Success, ' +
    'TotalTokens = TotalTokens + :Tokens, ' +
    'TotalCost = TotalCost + :Cost, ' +
    'AvgDuration = (AvgDuration * TestCount + :Duration) / (TestCount + 1), ' +
    'LastTestedAt = :NowTime, ' +
    'LastResponse = :LastResponse, ' +
    'UpdatedAt = :NowTime ' +
    'WHERE PromptId = :PromptId AND VersionNumber = :VersionNumber',
    [
      LLMParam('Success', Ord(Response.Success)),
      LLMParam('Tokens', Response.TotalTokens),
      LLMParam('Cost', Response.Cost),
      LLMParam('Duration', Response.DurationMs),
      LLMParam('LastResponse', Response.Content),
      LLMParam('PromptId', PromptId),
      LLMParam('VersionNumber', VersionNum),
      LLMParam('NowTime', NowStr)
    ]);
end;

// ============================================================================
// Category Management
// ============================================================================

function TLLMManager.GetCategories: TPromptCategoryArray;
var
  Pair: TPair<Integer, TPromptCategory>;
  I: Integer;
begin
  FCacheLock.Enter;
  try
    SetLength(Result, FCategoryCache.Count);
    I := 0;
    for Pair in FCategoryCache do
    begin
      Result[I] := Pair.Value;
      Inc(I);
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TLLMManager.GetCategoriesByLevel(Level: Integer): TPromptCategoryArray;
var
  Pair: TPair<Integer, TPromptCategory>;
  List: TList<TPromptCategory>;
begin
  List := TList<TPromptCategory>.Create;
  try
    FCacheLock.Enter;
    try
      for Pair in FCategoryCache do
        if Pair.Value.Level = Level then
          List.Add(Pair.Value);
    finally
      FCacheLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLLMManager.GetChildCategories(ParentId: Integer): TPromptCategoryArray;
var
  Pair: TPair<Integer, TPromptCategory>;
  List: TList<TPromptCategory>;
begin
  List := TList<TPromptCategory>.Create;
  try
    FCacheLock.Enter;
    try
      for Pair in FCategoryCache do
        if Pair.Value.ParentId = ParentId then
          List.Add(Pair.Value);
    finally
      FCacheLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TLLMManager.SaveCategory(var Category: TPromptCategory);
var
  ParentValue: Variant;
  NewId: Variant;
  UpdatedAtIso: string;
begin
  if not HasActiveConnection then
    Exit;

  if Category.ParentId > 0 then
    ParentValue := Category.ParentId
  else
    ParentValue := Null;

  if Category.Id > 0 then
  begin
    UpdatedAtIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    FStorage.Execute(
      'UPDATE PromptCategories SET ' +
      'ParentId = :ParentId, Level = :Level, Code = :Code, Name = :Name, ' +
      'Description = :Description, SortOrder = :SortOrder, IsActive = :IsActive, ' +
      'UpdatedAt = :UpdatedAt ' +
      'WHERE Id = :Id',
      [
        LLMParam('ParentId', ParentValue),
        LLMParam('Level', Category.Level),
        LLMParam('Code', Category.Code),
        LLMParam('Name', Category.Name),
        LLMParam('Description', Category.Description),
        LLMParam('SortOrder', Category.SortOrder),
        LLMParam('IsActive', Category.IsActive),
        LLMParam('UpdatedAt', UpdatedAtIso),
        LLMParam('Id', Category.Id)
      ]);
  end
  else
  begin
    FStorage.Execute(
      'INSERT INTO PromptCategories (ParentId, Level, Code, Name, Description, SortOrder, IsActive) ' +
      'VALUES (:ParentId, :Level, :Code, :Name, :Description, :SortOrder, :IsActive)',
      [
        LLMParam('ParentId', ParentValue),
        LLMParam('Level', Category.Level),
        LLMParam('Code', Category.Code),
        LLMParam('Name', Category.Name),
        LLMParam('Description', Category.Description),
        LLMParam('SortOrder', Category.SortOrder),
        LLMParam('IsActive', Category.IsActive)
      ]);

    if IsPG then
      NewId := FStorage.ExecuteScalar('SELECT LASTVAL()', [])
    else
      NewId := FStorage.ExecuteScalar('SELECT last_insert_rowid()', []);
    if not VarIsNull(NewId) then
      Category.Id := NewId;
  end;

  // Update cache
  FCacheLock.Enter;
  try
    FCategoryCache.AddOrSetValue(Category.Id, Category);
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.DeleteCategory(CategoryId: Integer);
begin
  if not HasActiveConnection then
    Exit;

  FStorage.Execute(
    'DELETE FROM PromptCategories WHERE Id = :Id',
    [LLMParam('Id', CategoryId)]);

  FCacheLock.Enter;
  try
    FCategoryCache.Remove(CategoryId);
  finally
    FCacheLock.Leave;
  end;
end;

// ============================================================================
// Prompt Management
// ============================================================================

function TLLMManager.GetPrompt(const InternalCode: string): TPrompt;
begin
  FCacheLock.Enter;
  try
    if not FPromptCache.TryGetValue(InternalCode, Result) then
    begin
      Result.Id := 0;
      Result.InternalCode := '';
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TLLMManager.GetPromptsByCategory(CategoryId: Integer): TPromptArray;
var
  Pair: TPair<string, TPrompt>;
  List: TList<TPrompt>;
begin
  List := TList<TPrompt>.Create;
  try
    FCacheLock.Enter;
    try
      for Pair in FPromptCache do
        if Pair.Value.CategoryId = CategoryId then
          List.Add(Pair.Value);
    finally
      FCacheLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TLLMManager.GetAllPrompts: TPromptArray;
var
  Pair: TPair<string, TPrompt>;
  I: Integer;
begin
  FCacheLock.Enter;
  try
    SetLength(Result, FPromptCache.Count);
    I := 0;
    for Pair in FPromptCache do
    begin
      Result[I] := Pair.Value;
      Inc(I);
    end;
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.SavePrompt(var Prompt: TPrompt);
var
  CategoryValue: Variant;
  NewId: Variant;
  UpdatedAtIso: string;
begin
  if not HasActiveConnection then
    Exit;

  if Prompt.CategoryId > 0 then
    CategoryValue := Prompt.CategoryId
  else
    CategoryValue := Null;

  if Prompt.Id > 0 then
  begin
    UpdatedAtIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    FStorage.Execute(
      'UPDATE Prompts SET ' +
      'CategoryId = :CategoryId, InternalCode = :InternalCode, Name = :Name, ' +
      'Description = :Description, BoundQueryName = :BoundQueryName, ' +
      'VariablesJson = :VariablesJson, IsActive = :IsActive, ' +
      'UpdatedAt = :UpdatedAt, UpdatedBy = :UpdatedBy ' +
      'WHERE Id = :Id',
      [
        LLMParam('CategoryId', CategoryValue),
        LLMParam('InternalCode', Prompt.InternalCode),
        LLMParam('Name', Prompt.Name),
        LLMParam('Description', Prompt.Description),
        LLMParam('BoundQueryName', Prompt.BoundQueryName),
        LLMParam('VariablesJson', VariablesToJson(Prompt.Variables)),
        LLMParam('IsActive', Prompt.IsActive),
        LLMParam('UpdatedAt', UpdatedAtIso),
        LLMParam('UpdatedBy', ''),
        LLMParam('Id', Prompt.Id)
      ]);
  end
  else
  begin
    FStorage.Execute(
      'INSERT INTO Prompts (CategoryId, InternalCode, Name, Description, ' +
      'BoundQueryName, VariablesJson, IsActive, CreatedBy) ' +
      'VALUES (:CategoryId, :InternalCode, :Name, :Description, ' +
      ':BoundQueryName, :VariablesJson, :IsActive, :CreatedBy)',
      [
        LLMParam('CategoryId', CategoryValue),
        LLMParam('InternalCode', Prompt.InternalCode),
        LLMParam('Name', Prompt.Name),
        LLMParam('Description', Prompt.Description),
        LLMParam('BoundQueryName', Prompt.BoundQueryName),
        LLMParam('VariablesJson', VariablesToJson(Prompt.Variables)),
        LLMParam('IsActive', Prompt.IsActive),
        LLMParam('CreatedBy', '')
      ]);

    if IsPG then
      NewId := FStorage.ExecuteScalar('SELECT LASTVAL()', [])
    else
      NewId := FStorage.ExecuteScalar('SELECT last_insert_rowid()', []);
    if not VarIsNull(NewId) then
      Prompt.Id := NewId;
  end;

  Prompt.CategoryPath := BuildCategoryPath(Prompt.CategoryId);
  
  // Update cache
  FCacheLock.Enter;
  try
    FPromptCache.AddOrSetValue(Prompt.InternalCode, Prompt);
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.DeletePrompt(const InternalCode: string);
begin
  if not HasActiveConnection then
    Exit;

  // BIZ2-005 fix: cascade-delete child records that reference this prompt.
  // Without this, deleting a prompt leaves orphaned rows in PromptVersions,
  // PromptMetaBinding, and LLMCalls referencing a PromptId that no longer
  // exists, breaking subsequent loads and producing FK violations on DBs
  // that enforce referential integrity. We resolve the Prompt.Id once via
  // subquery so all deletes target the same parent.
  // BIZ-R3-006: Combined into single multi-statement SQL for atomicity.
  // SQLite and PostgreSQL both support semicolon-separated statements in
  // one Execute call, ensuring all-or-nothing cascade deletion.
  FStorage.Execute(
    'DELETE FROM LLMCalls WHERE PromptId = ' +
    '(SELECT Id FROM Prompts WHERE InternalCode = :InternalCode); ' +
    'DELETE FROM PromptMetaBinding WHERE PromptId = ' +
    '(SELECT Id FROM Prompts WHERE InternalCode = :InternalCode); ' +
    'DELETE FROM PromptVersions WHERE PromptId = ' +
    '(SELECT Id FROM Prompts WHERE InternalCode = :InternalCode); ' +
    'DELETE FROM Prompts WHERE InternalCode = :InternalCode',
    [LLMParam('InternalCode', InternalCode)]);

  FCacheLock.Enter;
  try
    FPromptCache.Remove(InternalCode);
  finally
    FCacheLock.Leave;
  end;
end;

function TLLMManager.PromptExists(const InternalCode: string): Boolean;
begin
  FCacheLock.Enter;
  try
    Result := FPromptCache.ContainsKey(InternalCode);
  finally
    FCacheLock.Leave;
  end;
end;

// ============================================================================
// Version Management
// ============================================================================

function TLLMManager.GetVersion(const InternalCode: string; VersionNum: Integer): TPromptVersion;
var
  Prompt: TPrompt;
begin
  Result.Id := 0;
  Result.VersionNumber := 0;
  
  Prompt := GetPrompt(InternalCode);
  if Prompt.Id > 0 then
    Result := Prompt.GetVersion(VersionNum);
end;

procedure TLLMManager.SaveVersion(const InternalCode: string; var Version: TPromptVersion);
var
  Prompt: TPrompt;
  UpdatedAtIso: string;
  NewId: Variant;
begin
  if not HasActiveConnection then
    Exit;
    
  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
    Exit;
    
  Version.PromptId := Prompt.Id;

  if Version.Id > 0 then
  begin
    UpdatedAtIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    FStorage.Execute(
      'UPDATE PromptVersions SET ' +
      'Content = :Content, IsProduction = :IsProduction, ' +
      'UpdatedAt = :UpdatedAt ' +
      'WHERE Id = :Id',
      [
        LLMParam('Content', Version.Content),
        LLMParam('IsProduction', Version.IsProduction),
        LLMParam('UpdatedAt', UpdatedAtIso),
        LLMParam('Id', Version.Id)
      ]);
  end
  else
  begin
    FStorage.Execute(
      'INSERT INTO PromptVersions (PromptId, VersionNumber, Content, IsProduction) ' +
      'VALUES (:PromptId, :VersionNumber, :Content, :IsProduction)',
      [
        LLMParam('PromptId', Prompt.Id),
        LLMParam('VersionNumber', Version.VersionNumber),
        LLMParam('Content', Version.Content),
        LLMParam('IsProduction', Version.IsProduction)
      ]);

    if IsPG then
      NewId := FStorage.ExecuteScalar('SELECT LASTVAL()', [])
    else
      NewId := FStorage.ExecuteScalar('SELECT last_insert_rowid()', []);
    if not VarIsNull(NewId) then
      Version.Id := NewId;
  end;
  
  // Refresh prompt in cache
  RefreshCache;
end;

procedure TLLMManager.SetProductionVersion(const InternalCode: string; VersionNum: Integer);
var
  Prompt: TPrompt;
  ProdTrue, ProdFalse: string;
begin
  if not HasActiveConnection then
    Exit;

  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
    Exit;

  // BUG-308 (BIZ-013): 原子化 —— 将两次 UPDATE 合并为一条 CASE 语句，
  // 单条 SQL 同时完成"清除旧生产版本 + 设置新生产版本"，避免中间态。
  if IsPG then
  begin
    ProdTrue := 'TRUE';
    ProdFalse := 'FALSE';
  end
  else
  begin
    ProdTrue := '1';
    ProdFalse := '0';
  end;

  FStorage.Execute(
    'UPDATE PromptVersions SET IsProduction = CASE ' +
    'WHEN VersionNumber = :VersionNumber THEN ' + ProdTrue + ' ' +
    'ELSE ' + ProdFalse + ' END ' +
    'WHERE PromptId = :PromptId',
    [LLMParam('PromptId', Prompt.Id), LLMParam('VersionNumber', VersionNum)]);

  RefreshCache;
end;

procedure TLLMManager.DeleteVersion(const InternalCode: string; VersionNum: Integer);
var
  Prompt: TPrompt;
begin
  if not HasActiveConnection then
    Exit;

  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
    Exit;

  FStorage.Execute(
    'DELETE FROM PromptVersions WHERE PromptId = :PromptId AND VersionNumber = :VersionNumber',
    [LLMParam('PromptId', Prompt.Id), LLMParam('VersionNumber', VersionNum)]);

  RefreshCache;
end;

procedure TLLMManager.TestSeedPrompt(const InternalCode: string; const Prompt: TPrompt);
begin
  FPromptCache.AddOrSetValue(InternalCode, Prompt);
end;

procedure TLLMManager.DeleteVersions(const InternalCode: string; const VersionNums: array of Integer);
var
  Prompt: TPrompt;
  SQL: string;
  Params: TArray<TLLMStorageParam>;
  I: Integer;
begin
  if not HasActiveConnection then
    Exit;
  if Length(VersionNums) = 0 then
    Exit;

  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
    Exit;

  // BUG-308 (BIZ-013): 批量删除 —— 单条 DELETE + IN 子句，只触发一次 RefreshCache。
  SetLength(Params, Length(VersionNums) + 1);
  Params[0] := LLMParam('PromptId', Prompt.Id);
  SQL := 'DELETE FROM PromptVersions WHERE PromptId = :PromptId AND VersionNumber IN (';
  for I := 0 to High(VersionNums) do
  begin
    Params[I + 1] := LLMParam('V' + I.ToString, VersionNums[I]);
    if I > 0 then
      SQL := SQL + ',';
    SQL := SQL + ':V' + I.ToString;
  end;
  SQL := SQL + ')';

  FStorage.Execute(SQL, Params);
  RefreshCache;
end;

// ============================================================================
// Meta-Prompt Management
// ============================================================================

function TLLMManager.GetMetaPrompts: TMetaPromptArray;
var
  Pair: TPair<Integer, TMetaPrompt>;
  I: Integer;
begin
  FCacheLock.Enter;
  try
    SetLength(Result, FMetaCache.Count);
    I := 0;
    for Pair in FMetaCache do
    begin
      Result[I] := Pair.Value;
      Inc(I);
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TLLMManager.GetMetaPrompt(const InternalCode: string): TMetaPrompt;
var
  Pair: TPair<Integer, TMetaPrompt>;
begin
  Result.Id := 0;
  Result.InternalCode := '';
  
  FCacheLock.Enter;
  try
    for Pair in FMetaCache do
      if Pair.Value.InternalCode = InternalCode then
      begin
        Result := Pair.Value;
        Break;
      end;
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.SaveMetaPrompt(var Meta: TMetaPrompt);
var
  UpdatedAtIso: string;
  NewId: Variant;
begin
  if not HasActiveConnection then
    Exit;

  if Meta.Id > 0 then
  begin
    UpdatedAtIso := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
    FStorage.Execute(
      'UPDATE PromptMeta SET ' +
      'InternalCode = :InternalCode, Name = :Name, Category = :Category, ' +
      'Content = :Content, MergeMode = :MergeMode, Priority = :Priority, ' +
      'Level = :Level, IsActive = :IsActive, ' +
      'UpdatedAt = :UpdatedAt ' +
      'WHERE Id = :Id',
      [
        LLMParam('InternalCode', Meta.InternalCode),
        LLMParam('Name', Meta.Name),
        LLMParam('Category', Meta.CategoryToStr),
        LLMParam('Content', Meta.Content),
        LLMParam('MergeMode', Meta.MergeModeToStr),
        LLMParam('Priority', Meta.Priority),
        LLMParam('Level', Meta.Level),
        LLMParam('IsActive', Meta.IsActive),
        LLMParam('UpdatedAt', UpdatedAtIso),
        LLMParam('Id', Meta.Id)
      ]);
  end
  else
  begin
    FStorage.Execute(
      'INSERT INTO PromptMeta (InternalCode, Name, Category, Content, MergeMode, Priority, Level, IsActive) ' +
      'VALUES (:InternalCode, :Name, :Category, :Content, :MergeMode, :Priority, :Level, :IsActive)',
      [
        LLMParam('InternalCode', Meta.InternalCode),
        LLMParam('Name', Meta.Name),
        LLMParam('Category', Meta.CategoryToStr),
        LLMParam('Content', Meta.Content),
        LLMParam('MergeMode', Meta.MergeModeToStr),
        LLMParam('Priority', Meta.Priority),
        LLMParam('Level', Meta.Level),
        LLMParam('IsActive', Meta.IsActive)
      ]);

    if IsPG then
      NewId := FStorage.ExecuteScalar('SELECT LASTVAL()', [])
    else
      NewId := FStorage.ExecuteScalar('SELECT last_insert_rowid()', []);
    if not VarIsNull(NewId) then
      Meta.Id := NewId;
  end;

  FCacheLock.Enter;
  try
    FMetaCache.AddOrSetValue(Meta.Id, Meta);
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.DeleteMetaPrompt(const InternalCode: string);
var
  Meta: TMetaPrompt;
begin
  if not HasActiveConnection then
    Exit;
    
  Meta := GetMetaPrompt(InternalCode);
  if Meta.Id = 0 then
    Exit;

  FStorage.Execute(
    'DELETE FROM PromptMeta WHERE InternalCode = :InternalCode',
    [LLMParam('InternalCode', InternalCode)]);

  FCacheLock.Enter;
  try
    FMetaCache.Remove(Meta.Id);
  finally
    FCacheLock.Leave;
  end;
end;

procedure TLLMManager.BindMetaPrompt(const PromptCode, MetaCode: string; OrderIndex: Integer);
var
  Prompt: TPrompt;
  Meta: TMetaPrompt;
begin
  if not HasActiveConnection then
    Exit;
    
  Prompt := GetPrompt(PromptCode);
  Meta := GetMetaPrompt(MetaCode);
  if (Prompt.Id = 0) or (Meta.Id = 0) then
    Exit;

  if IsPG then
    FStorage.Execute(
      'INSERT INTO PromptMetaBinding (PromptId, MetaPromptId, OrderIndex, IsEnabled) ' +
      'VALUES (:PromptId, :MetaPromptId, :OrderIndex, TRUE) ' +
      'ON CONFLICT (PromptId, MetaPromptId) DO UPDATE SET OrderIndex = EXCLUDED.OrderIndex, IsEnabled = EXCLUDED.IsEnabled',
      [
        LLMParam('PromptId', Prompt.Id),
        LLMParam('MetaPromptId', Meta.Id),
        LLMParam('OrderIndex', OrderIndex)
      ])
  else
    FStorage.Execute(
      'INSERT OR REPLACE INTO PromptMetaBinding (PromptId, MetaPromptId, OrderIndex, IsEnabled) ' +
      'VALUES (:PromptId, :MetaPromptId, :OrderIndex, 1)',
      [
        LLMParam('PromptId', Prompt.Id),
        LLMParam('MetaPromptId', Meta.Id),
        LLMParam('OrderIndex', OrderIndex)
      ]);
  
  RefreshCache;
end;

procedure TLLMManager.UnbindMetaPrompt(const PromptCode, MetaCode: string);
var
  Prompt: TPrompt;
  Meta: TMetaPrompt;
begin
  if not HasActiveConnection then
    Exit;
    
  Prompt := GetPrompt(PromptCode);
  Meta := GetMetaPrompt(MetaCode);
  if (Prompt.Id = 0) or (Meta.Id = 0) then
    Exit;

  FStorage.Execute(
    'DELETE FROM PromptMetaBinding WHERE PromptId = :PromptId AND MetaPromptId = :MetaPromptId',
    [LLMParam('PromptId', Prompt.Id), LLMParam('MetaPromptId', Meta.Id)]);

  RefreshCache;
end;

// ============================================================================
// Execution
// ============================================================================

function TLLMManager.Execute(const InternalCode: string): TLLMResponse;
begin
  Result := Execute(InternalCode, nil, 0, '');
end;

function TLLMManager.Execute(const InternalCode: string;
  const Params: TDictionary<string, Variant>): TLLMResponse;
begin
  Result := Execute(InternalCode, Params, 0, '');
end;

function TLLMManager.Execute(const InternalCode: string;
  const Params: TDictionary<string, Variant>;
  VersionNum: Integer;
  const ConfigName: string): TLLMResponse;
var
  Prompt: TPrompt;
  FinalPrompt: string;
  LLMResponse: TLLMChatResponse;
  Config: TLLMConfig;
  ActualConfigName: string;
  ActualVersionNum: Integer;
begin
  Result.Init;
  
  // Get prompt
  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
  begin
    Result.ErrorCode := 'prompt_not_found';
    Result.ErrorMessage := 'Prompt not found: ' + InternalCode;
    Exit;
  end;
  
  // Determine version
  if VersionNum > 0 then
    ActualVersionNum := VersionNum
  else
    ActualVersionNum := Prompt.GetProductionVersion;
    
  if ActualVersionNum = 0 then
  begin
    Result.ErrorCode := 'no_version';
    Result.ErrorMessage := 'No version available for prompt: ' + InternalCode;
    Exit;
  end;
  
  // Build final prompt
  FinalPrompt := BuildFinalPrompt(InternalCode, Params, ActualVersionNum);
  
  // Determine config
  if ConfigName <> '' then
    ActualConfigName := ConfigName
  else
    ActualConfigName := 'Default';
    
  // Execute via LLM client
  if FLLMClient.Chat(FinalPrompt, LLMResponse, ActualConfigName) then
  begin
    Result.Success := True;
    Result.Content := LLMResponse.Content;
    Result.FinishReason := LLMResponse.FinishReason;
    Result.InputTokens := LLMResponse.InputTokens;
    Result.OutputTokens := LLMResponse.OutputTokens;
    Result.TotalTokens := LLMResponse.TotalTokens;
    Result.DurationMs := LLMResponse.DurationMs;
    
    // Calculate cost
    Config := FLLMClient.GetConfig(ActualConfigName);
    Result.Cost := (LLMResponse.InputTokens / 1000.0 * Config.InputTokenPrice) +
                   (LLMResponse.OutputTokens / 1000.0 * Config.OutputTokenPrice);
  end
  else
  begin
    Result.ErrorCode := LLMResponse.ErrorCode;
    Result.ErrorMessage := LLMResponse.ErrorMessage;
    Result.DurationMs := LLMResponse.DurationMs;
  end;
  
  Result.PromptId := Prompt.Id;
  Result.VersionNumber := ActualVersionNum;
  Result.ConfigName := ActualConfigName;
  
  // Record call and update stats
  RecordLLMCall(Prompt, ActualVersionNum, ActualConfigName, FinalPrompt, Result);
  UpdateVersionStats(Prompt.Id, ActualVersionNum, Result);
end;

procedure TLLMManager.ExecuteAsync(const InternalCode: string;
  const Params: TDictionary<string, Variant>;
  OnComplete: TLLMResponseCallback;
  VersionNum: Integer;
  const ConfigName: string);
var
  ParamsCopy: TDictionary<string, Variant>;
  Key: string;
  LTask: ITask;
begin
  // Create a copy of params for the async task
  ParamsCopy := nil;
  if Assigned(Params) then
  begin
    ParamsCopy := TDictionary<string, Variant>.Create;
    for Key in Params.Keys do
      ParamsCopy.Add(Key, Params[Key]);
  end;

  // BIZ2-006 fix: track the ITask so Destroy can wait for it before freeing
  // fields the closure references (FLLMClient, FPromptCache, etc.).
  LTask := TTask.Run(
    procedure
    var
      Response: TLLMResponse;
    begin
      try
        Response := Execute(InternalCode, ParamsCopy, VersionNum, ConfigName);

        TThread.Queue(nil,
          procedure
          begin
            if Assigned(OnComplete) then
              OnComplete(Response);
          end
        );
      finally
        ParamsCopy.Free;
        // Always remove ourselves from the execute-tasks list so Destroy
        // doesn't wait on a finished task.
        FExecuteTasksLock.Enter;
        try
          FExecuteTasks.Remove(LTask);
        finally
          FExecuteTasksLock.Leave;
        end;
      end;
    end
  );
  FExecuteTasksLock.Enter;
  try
    FExecuteTasks.Add(LTask);
  finally
    FExecuteTasksLock.Leave;
  end;
end;

function TLLMManager.BuildFinalPrompt(const InternalCode: string;
  const Params: TDictionary<string, Variant>;
  VersionNum: Integer): string;
var
  Prompt: TPrompt;
  Context: string;
  ActualVersionNum: Integer;
begin
  Result := '';
  
  Prompt := GetPrompt(InternalCode);
  if Prompt.Id = 0 then
    Exit;
    
  // Determine version
  if VersionNum > 0 then
    ActualVersionNum := VersionNum
  else
    ActualVersionNum := Prompt.GetProductionVersion;
    
  if ActualVersionNum = 0 then
    Exit;
  
  // Merge meta-prompts
  Result := MergeMetaPrompts(Prompt, ActualVersionNum);
  
  // Replace variables first
  Result := ReplaceVariables(Result, Params);
  
  // Build context from BoundQuery and replace {{context}}
  Context := BuildContext(Prompt, Params);
  if Context <> '' then
    Result := StringReplace(Result, '{{context}}', Context, [rfReplaceAll, rfIgnoreCase]);
end;

// ============================================================================
// Testing
// ============================================================================

function TLLMManager.TestVersion(const InternalCode: string; VersionNum: Integer;
  const Params: TDictionary<string, Variant>;
  const ConfigName: string): TLLMResponse;
begin
  Result := Execute(InternalCode, Params, VersionNum, ConfigName);
end;

function TLLMManager.CompareVersions(const InternalCode: string;
  const VersionNums: array of Integer;
  const Params: TDictionary<string, Variant>;
  const ConfigName: string): TArray<TLLMResponse>;
var
  I: Integer;
begin
  SetLength(Result, Length(VersionNums));
  for I := 0 to High(VersionNums) do
    Result[I] := TestVersion(InternalCode, VersionNums[I], Params, ConfigName);
end;

end.

