unit DeepBase.CloudSync;

{*******************************************************************************
  DeepBase Framework - Cloud Configuration Sync
  
  �ƶ�����ͬ��ģ�飬֧�֣�
  - ���豸����ͬ��
  - �汾��ͻ�������
  - �����޸ı��غϲ�
  - ���ܴ���ʹ洢
  - ����ͬ���Ż�
  
  Author: DeepBase Team
  Created: 2025-11-30
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.SyncObjs, System.DateUtils, System.Hash, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient, System.Threading,
  System.Math, DeepBase.Exceptions;

type
  /// <summary>ͬ��״̬</summary>
  TSyncStatus = (
    ssIdle,           // ����
    ssSyncing,        // ͬ����
    ssUploading,      // �ϴ���
    ssDownloading,    // ������
    ssConflict,       // ��ͻ
    ssError           // ����
  );

  /// <summary>��ͻ�������</summary>
  TConflictResolution = (
    crLocalWins,      // ��������
    crRemoteWins,     // Զ������
    crNewerWins,      // ����������
    crMerge,          // ���ܺϲ�
    crManual          // �ֶ����
  );
  
  /// <summary>����ϲ�����</summary>
  TArrayMergeStrategy = (
    amsReplace,       // �滻 - ��Դ�����滻Ŀ������
    amsAppend,        // ׷�� - ��Դ����Ԫ��׷�ӵ�Ŀ������
    amsMergeByIndex,  // �������ϲ� - ��ͬ������Ԫ�ؽ��кϲ�
    amsUnion          // ���� - ȥ�غϲ�������JSONֵ����ԣ�
  );

  /// <summary>ͬ������</summary>
  TSyncDirection = (
    sdBidirectional,  // ˫��ͬ��
    sdUploadOnly,     // ���ϴ�
    sdDownloadOnly    // ������
  );

  /// <summary>����������</summary>
  TConfigItemType = (
    citString,
    citInteger,
    citFloat,
    citBoolean,
    citDateTime,
    citJSON,
    citBinary
  );

  /// <summary>������汾��Ϣ</summary>
  TConfigVersion = record
    Version: Integer;           // �汾��
    ModifiedAt: TDateTime;      // �޸�ʱ��
    ModifiedBy: string;         // �޸��豸ID
    Checksum: string;           // ����У���
    class function Create(AVersion: Integer; AModifiedAt: TDateTime;
      const AModifiedBy, AChecksum: string): TConfigVersion; static;
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TConfigVersion; static;
  end;

  /// <summary>������</summary>
  TConfigItem = class
  private
    FKey: string;
    FValue: string;
    FItemType: TConfigItemType;
    FLocalVersion: TConfigVersion;
    FRemoteVersion: TConfigVersion;
    FIsDeleted: Boolean;
    FIsDirty: Boolean;
  public
    constructor Create(const AKey: string; AItemType: TConfigItemType = citString);
    destructor Destroy; override;
    
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TConfigItem;
    
    function GetStringValue: string;
    function GetIntegerValue: Integer;
    function GetFloatValue: Double;
    function GetBooleanValue: Boolean;
    function GetDateTimeValue: TDateTime;
    function GetJSONValue: TJSONValue;
    
    procedure SetStringValue(const AValue: string);
    procedure SetIntegerValue(AValue: Integer);
    procedure SetFloatValue(AValue: Double);
    procedure SetBooleanValue(AValue: Boolean);
    procedure SetDateTimeValue(AValue: TDateTime);
    procedure SetJSONValue(AValue: TJSONValue);
    
    property Key: string read FKey;
    property Value: string read FValue write FValue;
    property ItemType: TConfigItemType read FItemType write FItemType;
    property LocalVersion: TConfigVersion read FLocalVersion write FLocalVersion;
    property RemoteVersion: TConfigVersion read FRemoteVersion write FRemoteVersion;
    property IsDeleted: Boolean read FIsDeleted write FIsDeleted;
    property IsDirty: Boolean read FIsDirty write FIsDirty;
  end;

  /// <summary>ͬ����ͻ</summary>
  TSyncConflict = class
  private
    FKey: string;
    FLocalItem: TConfigItem;
    FRemoteItem: TConfigItem;
    FResolved: Boolean;
    FResolution: TConflictResolution;
  public
    constructor Create(const AKey: string; ALocalItem, ARemoteItem: TConfigItem);
    destructor Destroy; override;
    
    procedure Resolve(AResolution: TConflictResolution);
    function GetResolvedItem: TConfigItem;
    
    property Key: string read FKey;
    property LocalItem: TConfigItem read FLocalItem;
    property RemoteItem: TConfigItem read FRemoteItem;
    property Resolved: Boolean read FResolved;
    property Resolution: TConflictResolution read FResolution;
  end;

  /// <summary>ͬ������</summary>
  TSyncProgress = record
    Status: TSyncStatus;
    TotalItems: Integer;
    ProcessedItems: Integer;
    UploadedItems: Integer;
    DownloadedItems: Integer;
    ConflictCount: Integer;
    ErrorMessage: string;
    function ProgressPercent: Integer;
  end;

  /// <summary>ͬ��ͳ��</summary>
  TSyncStatistics = record
    LastSyncTime: TDateTime;
    TotalSyncs: Integer;
    SuccessfulSyncs: Integer;
    FailedSyncs: Integer;
    TotalUploaded: Int64;
    TotalDownloaded: Int64;
    ConflictsResolved: Integer;
    AverageSyncDurationMs: Double;
    procedure Reset;
  end;

  /// <summary>�ƶ˷�������</summary>
  TCloudServiceConfig = record
    ServiceURL: string;           // ����URL
    ApiKey: string;               // API��Կ
    DeviceId: string;             // �豸ID
    UserId: string;               // �û�ID
    EncryptionKey: string;        // ������Կ (AES-256)
    TimeoutSeconds: Integer;      // ��ʱ����
    RetryCount: Integer;          // ���Դ���
    EnableCompression: Boolean;   // ����ѹ��
    EnableEncryption: Boolean;    // ���ü���
    SyncDirection: TSyncDirection;
    ConflictResolution: TConflictResolution;
    class function Default: TCloudServiceConfig; static;
  end;

  // �¼�����
  TSyncProgressEvent = procedure(Sender: TObject; const Progress: TSyncProgress) of object;
  TSyncCompleteEvent = procedure(Sender: TObject; Success: Boolean; const ErrorMsg: string) of object;
  TConflictEvent = procedure(Sender: TObject; Conflict: TSyncConflict; var Resolution: TConflictResolution) of object;

  /// <summary>�ƶ�ͬ���ͻ���</summary>
  TCloudSyncClient = class
  private
    FConfig: TCloudServiceConfig;
    FHttpClient: THTTPClient;
    FLock: TCriticalSection;
    
    function DoRequest(const AMethod, AEndpoint: string; ABody: TJSONObject = nil): TJSONObject;
    function EncryptData(const AData: string): string;
    function DecryptData(const AData: string): string;
  public
    constructor Create(const AConfig: TCloudServiceConfig);
    destructor Destroy; override;
    
    // API����
    function Authenticate: Boolean;
    function GetRemoteConfig(const AKey: string): TConfigItem;
    function GetAllRemoteConfigs: TObjectList<TConfigItem>;
    function GetChangedConfigs(ASinceVersion: Integer): TObjectList<TConfigItem>;
    function UploadConfig(AItem: TConfigItem): Boolean;
    function UploadConfigs(AItems: TObjectList<TConfigItem>): Boolean;
    function DeleteRemoteConfig(const AKey: string): Boolean;
    function GetServerVersion: Integer;
    
    property Config: TCloudServiceConfig read FConfig write FConfig;
  end;

  /// <summary>�������ô洢</summary>
  TLocalConfigStore = class
  private
    FFilePath: string;
    FItems: TObjectDictionary<string, TConfigItem>;
    FLock: TCriticalSection;
    FCurrentVersion: Integer;
    FIsDirty: Boolean;
    
    procedure LoadFromFile;
    procedure SaveToFile;
    procedure SetCurrentVersion(AValue: Integer);
  public
    constructor Create(const AFilePath: string);
    destructor Destroy; override;
    
    function Get(const AKey: string): TConfigItem;
    function GetOrCreate(const AKey: string; AItemType: TConfigItemType = citString): TConfigItem;
    procedure Put(AItem: TConfigItem);
    procedure Delete(const AKey: string);
    function Exists(const AKey: string): Boolean;
    function GetAll: TObjectList<TConfigItem>;
    function GetDirtyItems: TObjectList<TConfigItem>;
    procedure MarkAllClean;
    procedure Clear;
    
    property FilePath: string read FFilePath;
    property CurrentVersion: Integer read FCurrentVersion write SetCurrentVersion;
    property IsDirty: Boolean read FIsDirty;
  end;

  /// <summary>����ͬ��������</summary>
  TCloudConfigSync = class
  private
    FConfig: TCloudServiceConfig;
    FClient: TCloudSyncClient;
    FLocalStore: TLocalConfigStore;
    FConflicts: TObjectList<TSyncConflict>;
    FStatus: TSyncStatus;
    FProgress: TSyncProgress;
    FStatistics: TSyncStatistics;
    FLock: TCriticalSection;
    FSyncThread: TThread;
    FAutoSyncInterval: Integer;  // �Զ�ͬ��������룩
    FAutoSyncEnabled: Boolean;
    FAutoSyncTimer: TThread;
    
    FOnProgress: TSyncProgressEvent;
    FOnComplete: TSyncCompleteEvent;
    FOnConflict: TConflictEvent;
    
    procedure DoProgress;
    procedure DoComplete(Success: Boolean; const ErrorMsg: string);
    function DoResolveConflict(AConflict: TSyncConflict): TConflictResolution;
    
    function DetectConflicts(ALocalItems, ARemoteItems: TObjectList<TConfigItem>): TObjectList<TSyncConflict>;
    procedure ApplyResolution(AConflict: TSyncConflict);
    
    procedure InternalSync;
    procedure StartAutoSyncTimer;
    procedure StopAutoSyncTimer;
    function HasConflictForKey(const AKey: string): Boolean;
  public
    constructor Create(const AConfig: TCloudServiceConfig; const ALocalStorePath: string);
    destructor Destroy; override;
    
    // ͬ������
    procedure Sync;
    procedure SyncAsync;
    procedure CancelSync;
    procedure ForceUpload;
    procedure ForceDownload;
    
    // ���ò��� (���Զ�ͬ�����)
    function GetString(const AKey: string; const ADefault: string = ''): string;
    function GetInteger(const AKey: string; ADefault: Integer = 0): Integer;
    function GetFloat(const AKey: string; ADefault: Double = 0): Double;
    function GetBoolean(const AKey: string; ADefault: Boolean = False): Boolean;
    function GetDateTime(const AKey: string; ADefault: TDateTime = 0): TDateTime;
    function GetJSON(const AKey: string): TJSONValue;
    
    procedure SetString(const AKey, AValue: string);
    procedure SetInteger(const AKey: string; AValue: Integer);
    procedure SetFloat(const AKey: string; AValue: Double);
    procedure SetBoolean(const AKey: string; AValue: Boolean);
    procedure SetDateTime(const AKey: string; AValue: TDateTime);
    procedure SetJSON(const AKey: string; AValue: TJSONValue);
    
    procedure DeleteKey(const AKey: string);
    function KeyExists(const AKey: string): Boolean;
    
    // ��ͻ����
    function HasConflicts: Boolean;
    function GetConflicts: TObjectList<TSyncConflict>;
    procedure ResolveConflict(const AKey: string; AResolution: TConflictResolution);
    procedure ResolveAllConflicts(AResolution: TConflictResolution);
    
    // �Զ�ͬ��
    procedure EnableAutoSync(AIntervalSeconds: Integer = 300);
    procedure DisableAutoSync;
    
    // ״̬
    property Status: TSyncStatus read FStatus;
    property Progress: TSyncProgress read FProgress;
    property Statistics: TSyncStatistics read FStatistics;
    property Config: TCloudServiceConfig read FConfig write FConfig;
    property AutoSyncEnabled: Boolean read FAutoSyncEnabled;
    property AutoSyncInterval: Integer read FAutoSyncInterval;
    
    // �¼�
    property OnProgress: TSyncProgressEvent read FOnProgress write FOnProgress;
    property OnComplete: TSyncCompleteEvent read FOnComplete write FOnComplete;
    property OnConflict: TConflictEvent read FOnConflict write FOnConflict;
  end;

  /// <summary>���ñ����־</summary>
  TConfigChangeLog = class
  private
    FLogPath: string;
    FLock: TCriticalSection;
  public
    constructor Create(const ALogPath: string);
    destructor Destroy; override;
    
    procedure LogChange(const AKey, AOldValue, ANewValue: string; AChangeType: string);
    procedure LogSync(const ASyncId: string; ASuccess: Boolean; const ADetails: string);
    procedure LogConflict(const AKey: string; AResolution: TConflictResolution);
    function GetRecentChanges(ACount: Integer = 100): TJSONArray;
    procedure Cleanup(ADaysToKeep: Integer = 30);
  end;

  /// <summary>���⻧ͬ��������</summary>
  TMultiTenantSyncManager = class
  private
    FSyncInstances: TObjectDictionary<string, TCloudConfigSync>;
    FLock: TCriticalSection;
    FDefaultTenantId: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    function RegisterTenant(const ATenantId: string; const AConfig: TCloudServiceConfig;
      const ALocalStorePath: string): TCloudConfigSync;
    procedure UnregisterTenant(const ATenantId: string);
    function GetSync(const ATenantId: string): TCloudConfigSync;
    function GetDefaultSync: TCloudConfigSync;
    procedure SetDefaultTenant(const ATenantId: string);
    procedure SyncAllTenants;
    function GetTenantIds: TArray<string>;
    
    property DefaultTenantId: string read FDefaultTenantId;
  end;

// ȫ�ֺ���
function CloudSync: TCloudConfigSync;
procedure SetCloudSync(ASync: TCloudConfigSync);

function MultiTenantSync: TMultiTenantSyncManager;

// ��������
function GenerateDeviceId: string;
function CalculateChecksum(const AData: string): string;

/// <summary>JSON��Ⱥϲ�</summary>
/// <param name="ATarget">Ŀ��JSON���󣨽����޸ģ�</param>
/// <param name="ASource">ԴJSON����</param>
/// <param name="AArrayStrategy">����ϲ�����</param>
/// <remarks>
/// �ݹ�ϲ�����JSON����
/// - �����ֶΣ��ݹ�ϲ�
/// - �����ֶΣ����ݲ��Ժϲ�
/// - ���ֶΣ�Դֵ����Ŀ��ֵ
/// - Դ�д��ڵ�Ŀ�겻���ڵ��ֶΣ����ӵ�Ŀ��
/// </remarks>
procedure JSONDeepMerge(ATarget, ASource: TJSONObject;
  AArrayStrategy: TArrayMergeStrategy = amsReplace);

/// <summary>��¡JSONֵ</summary>
function JSONClone(AValue: TJSONValue): TJSONValue;

/// <summary>�Ƚ�����JSONֵ�Ƿ����</summary>
function JSONValuesEqual(A, B: TJSONValue): Boolean;

/// <summary>�����Ժϲ�����JSON����</summary>
procedure JSONMergeArrays(ATarget, ASource: TJSONArray;
  AStrategy: TArrayMergeStrategy);

implementation

uses
  System.IOUtils,
  DeepBase.Crypto;

var
  GCloudSync: TCloudConfigSync = nil;
  GMultiTenantSync: TMultiTenantSyncManager = nil;

function CloudSync: TCloudConfigSync;
begin
  Result := GCloudSync;
end;

procedure SetCloudSync(ASync: TCloudConfigSync);
begin
  GCloudSync := ASync;
end;

function MultiTenantSync: TMultiTenantSyncManager;
begin
  if GMultiTenantSync = nil then
    GMultiTenantSync := TMultiTenantSyncManager.Create;
  Result := GMultiTenantSync;
end;

function GenerateDeviceId: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := THashMD5.GetHashString(GUIDToString(GUID) + FormatDateTime('yyyymmddhhnnsszzz', Now));
end;

function CalculateChecksum(const AData: string): string;
begin
  Result := THashSHA2.GetHashString(AData, THashSHA2.TSHA2Version.SHA256);
end;

function JSONClone(AValue: TJSONValue): TJSONValue;
begin
  if AValue = nil then
    Exit(nil);
  Result := TJSONObject.ParseJSONValue(AValue.ToJSON);
end;

function JSONValuesEqual(A, B: TJSONValue): Boolean;
begin
  if (A = nil) and (B = nil) then
    Exit(True);
  if (A = nil) or (B = nil) then
    Exit(False);
  Result := A.ToJSON = B.ToJSON;
end;

procedure JSONMergeArrays(ATarget, ASource: TJSONArray;
  AStrategy: TArrayMergeStrategy);
var
  I, J: Integer;
  LSourceItem, LTargetItem, LCloned, LRemoved: TJSONValue;
  LFound: Boolean;
begin
  case AStrategy of
    amsReplace:
      begin
        // ���Ŀ�����鲢����Դ��������
        while ATarget.Count > 0 do
        begin
          LRemoved := ATarget.Remove(0);
          LRemoved.Free;
        end;
        for I := 0 to ASource.Count - 1 do
        begin
          LCloned := JSONClone(ASource.Items[I]);
          if LCloned <> nil then
            ATarget.AddElement(LCloned);
        end;
      end;
      
    amsAppend:
      begin
        // ׷��Դ����Ԫ�ص�Ŀ��
        for I := 0 to ASource.Count - 1 do
        begin
          LCloned := JSONClone(ASource.Items[I]);
          if LCloned <> nil then
            ATarget.AddElement(LCloned);
        end;
      end;
      
    amsMergeByIndex:
      begin
        // �������ϲ�
        for I := 0 to ASource.Count - 1 do
        begin
          LSourceItem := ASource.Items[I];
          if I < ATarget.Count then
          begin
            LTargetItem := ATarget.Items[I];
            // ������߶��Ƕ��󣬵ݹ�ϲ�
            if (LTargetItem is TJSONObject) and (LSourceItem is TJSONObject) then
              JSONDeepMerge(TJSONObject(LTargetItem), TJSONObject(LSourceItem), amsMergeByIndex)
            else
            begin
              // ������Դֵ�滻
              LCloned := JSONClone(LSourceItem);
              if LCloned <> nil then
              begin
                LRemoved := ATarget.Remove(I);
                LRemoved.Free;
                // TJSONArrayû��Insert��������Ҫ�ؽ�
                // �򻯴��������ڷǶ���Ԫ��ֱ���滻
                ATarget.AddElement(LCloned);
              end;
            end;
          end
          else
          begin
            // Ŀ������϶̣�׷��
            LCloned := JSONClone(LSourceItem);
            if LCloned <> nil then
              ATarget.AddElement(LCloned);
          end;
        end;
      end;
      
    amsUnion:
      begin
        // ����ȥ��
        for I := 0 to ASource.Count - 1 do
        begin
          LSourceItem := ASource.Items[I];
          LFound := False;
          for J := 0 to ATarget.Count - 1 do
          begin
            if JSONValuesEqual(ATarget.Items[J], LSourceItem) then
            begin
              LFound := True;
              Break;
            end;
          end;
          if not LFound then
          begin
            LCloned := JSONClone(LSourceItem);
            if LCloned <> nil then
              ATarget.AddElement(LCloned);
          end;
        end;
      end;
  end;
end;

procedure JSONDeepMerge(ATarget, ASource: TJSONObject;
  AArrayStrategy: TArrayMergeStrategy);
var
  LPair: TJSONPair;
  LTargetValue, LSourceValue, LCloned: TJSONValue;
  LKey: string;
begin
  if (ATarget = nil) or (ASource = nil) then
    Exit;
  
  for LPair in ASource do
  begin
    LKey := LPair.JsonString.Value;
    LSourceValue := LPair.JsonValue;
    LTargetValue := ATarget.GetValue(LKey);
    
    if LTargetValue = nil then
    begin
      // Ŀ�겻���ڴ˼���ֱ�����ӿ�¡
      LCloned := JSONClone(LSourceValue);
      if LCloned <> nil then
        ATarget.AddPair(LKey, LCloned);
    end
    else if (LTargetValue is TJSONObject) and (LSourceValue is TJSONObject) then
    begin
      // ���߶��Ƕ��󣬵ݹ�ϲ�
      JSONDeepMerge(TJSONObject(LTargetValue), TJSONObject(LSourceValue), AArrayStrategy);
    end
    else if (LTargetValue is TJSONArray) and (LSourceValue is TJSONArray) then
    begin
      // ���߶������飬�����Ժϲ�
      JSONMergeArrays(TJSONArray(LTargetValue), TJSONArray(LSourceValue), AArrayStrategy);
    end
    else
    begin
      // ��ֵ�����Ͳ�ƥ�䣬��Դֵ����
      LCloned := JSONClone(LSourceValue);
      if LCloned <> nil then
      begin
        ATarget.RemovePair(LKey).Free;
        ATarget.AddPair(LKey, LCloned);
      end;
    end;
  end;
end;

{ TConfigVersion }

class function TConfigVersion.Create(AVersion: Integer; AModifiedAt: TDateTime;
  const AModifiedBy, AChecksum: string): TConfigVersion;
begin
  Result.Version := AVersion;
  Result.ModifiedAt := AModifiedAt;
  Result.ModifiedBy := AModifiedBy;
  Result.Checksum := AChecksum;
end;

function TConfigVersion.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('version', TJSONNumber.Create(Version));
  Result.AddPair('modifiedAt', DateToISO8601(ModifiedAt));
  Result.AddPair('modifiedBy', ModifiedBy);
  Result.AddPair('checksum', Checksum);
end;

class function TConfigVersion.FromJSON(AJSON: TJSONObject): TConfigVersion;
begin
  Result.Version := AJSON.GetValue<Integer>('version', 0);
  Result.ModifiedAt := ISO8601ToDate(AJSON.GetValue<string>('modifiedAt', ''));
  Result.ModifiedBy := AJSON.GetValue<string>('modifiedBy', '');
  Result.Checksum := AJSON.GetValue<string>('checksum', '');
end;

{ TConfigItem }

constructor TConfigItem.Create(const AKey: string; AItemType: TConfigItemType);
begin
  inherited Create;
  FKey := AKey;
  FItemType := AItemType;
  FValue := '';
  FIsDeleted := False;
  FIsDirty := False;
  FLocalVersion.Version := 0;
  FRemoteVersion.Version := 0;
end;

destructor TConfigItem.Destroy;
begin
  inherited;
end;

function TConfigItem.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('key', FKey);
  Result.AddPair('value', FValue);
  Result.AddPair('type', TJSONNumber.Create(Ord(FItemType)));
  Result.AddPair('isDeleted', TJSONBool.Create(FIsDeleted));
  Result.AddPair('isDirty', TJSONBool.Create(FIsDirty));
  Result.AddPair('localVersion', FLocalVersion.ToJSON);
  Result.AddPair('remoteVersion', FRemoteVersion.ToJSON);
end;

class function TConfigItem.FromJSON(AJSON: TJSONObject): TConfigItem;
var
  LValue: TJSONValue;
begin
  Result := TConfigItem.Create(AJSON.GetValue<string>('key', ''));
  Result.FValue := AJSON.GetValue<string>('value', '');
  Result.FItemType := TConfigItemType(AJSON.GetValue<Integer>('type', 0));
  Result.FIsDeleted := AJSON.GetValue<Boolean>('isDeleted', False);
  Result.FIsDirty := AJSON.GetValue<Boolean>('isDirty', False);
  
  LValue := AJSON.GetValue('localVersion');
  if LValue is TJSONObject then
    Result.FLocalVersion := TConfigVersion.FromJSON(TJSONObject(LValue));
    
  LValue := AJSON.GetValue('remoteVersion');
  if LValue is TJSONObject then
    Result.FRemoteVersion := TConfigVersion.FromJSON(TJSONObject(LValue));
end;

function TConfigItem.GetStringValue: string;
begin
  Result := FValue;
end;

function TConfigItem.GetIntegerValue: Integer;
begin
  Result := StrToIntDef(FValue, 0);
end;

function TConfigItem.GetFloatValue: Double;
begin
  Result := StrToFloatDef(FValue, 0);
end;

function TConfigItem.GetBooleanValue: Boolean;
begin
  Result := SameText(FValue, 'true') or (FValue = '1');
end;

function TConfigItem.GetDateTimeValue: TDateTime;
begin
  if FValue <> '' then
    Result := ISO8601ToDate(FValue)
  else
    Result := 0;
end;

function TConfigItem.GetJSONValue: TJSONValue;
begin
  if FValue <> '' then
    Result := TJSONObject.ParseJSONValue(FValue)
  else
    Result := nil;
end;

procedure TConfigItem.SetStringValue(const AValue: string);
begin
  FValue := AValue;
  FItemType := citString;
  FIsDirty := True;
end;

procedure TConfigItem.SetIntegerValue(AValue: Integer);
begin
  FValue := IntToStr(AValue);
  FItemType := citInteger;
  FIsDirty := True;
end;

procedure TConfigItem.SetFloatValue(AValue: Double);
begin
  FValue := FloatToStr(AValue);
  FItemType := citFloat;
  FIsDirty := True;
end;

procedure TConfigItem.SetBooleanValue(AValue: Boolean);
begin
  if AValue then
    FValue := 'true'
  else
    FValue := 'false';
  FItemType := citBoolean;
  FIsDirty := True;
end;

procedure TConfigItem.SetDateTimeValue(AValue: TDateTime);
begin
  FValue := DateToISO8601(AValue);
  FItemType := citDateTime;
  FIsDirty := True;
end;

procedure TConfigItem.SetJSONValue(AValue: TJSONValue);
begin
  if Assigned(AValue) then
    FValue := AValue.ToJSON
  else
    FValue := '';
  FItemType := citJSON;
  FIsDirty := True;
end;

{ TSyncConflict }

constructor TSyncConflict.Create(const AKey: string; ALocalItem, ARemoteItem: TConfigItem);
begin
  inherited Create;
  FKey := AKey;
  FLocalItem := ALocalItem;
  FRemoteItem := ARemoteItem;
  FResolved := False;
  FResolution := crManual;
end;

destructor TSyncConflict.Destroy;
begin
  // Items are owned by stores, don't free them
  inherited;
end;

procedure TSyncConflict.Resolve(AResolution: TConflictResolution);
begin
  FResolution := AResolution;
  FResolved := True;
end;

function TSyncConflict.GetResolvedItem: TConfigItem;
begin
  Result := nil;
  if not FResolved then
    Exit;
    
  case FResolution of
    crLocalWins:
      Result := FLocalItem;
    crRemoteWins:
      Result := FRemoteItem;
    crNewerWins:
      begin
        if FLocalItem.LocalVersion.ModifiedAt > FRemoteItem.RemoteVersion.ModifiedAt then
          Result := FLocalItem
        else
          Result := FRemoteItem;
      end;
    crMerge, crManual:
      Result := FLocalItem;  // Default to local for manual/merge
  end;
end;

{ TSyncProgress }

function TSyncProgress.ProgressPercent: Integer;
begin
  if TotalItems > 0 then
    Result := (ProcessedItems * 100) div TotalItems
  else
    Result := 0;
end;

{ TSyncStatistics }

procedure TSyncStatistics.Reset;
begin
  LastSyncTime := 0;
  TotalSyncs := 0;
  SuccessfulSyncs := 0;
  FailedSyncs := 0;
  TotalUploaded := 0;
  TotalDownloaded := 0;
  ConflictsResolved := 0;
  AverageSyncDurationMs := 0;
end;

{ TCloudServiceConfig }

class function TCloudServiceConfig.Default: TCloudServiceConfig;
begin
  Result.ServiceURL := 'https://api.DeepBase.cloud/v1';
  Result.ApiKey := '';
  Result.DeviceId := GenerateDeviceId;
  Result.UserId := '';
  Result.EncryptionKey := '';
  Result.TimeoutSeconds := 30;
  Result.RetryCount := 3;
  Result.EnableCompression := True;
  Result.EnableEncryption := True;
  Result.SyncDirection := sdBidirectional;
  Result.ConflictResolution := crNewerWins;
end;

{ TCloudSyncClient }

constructor TCloudSyncClient.Create(const AConfig: TCloudServiceConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := AConfig.TimeoutSeconds * 1000;
  FHttpClient.ResponseTimeout := AConfig.TimeoutSeconds * 1000;
  FLock := TCriticalSection.Create;
end;

destructor TCloudSyncClient.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

function TCloudSyncClient.DoRequest(const AMethod, AEndpoint: string;
  ABody: TJSONObject): TJSONObject;
var
  LResponse: IHTTPResponse;
  LURL: string;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
  LRetry: Integer;
  LBodyStr: string;
begin
  Result := nil;
  LURL := FConfig.ServiceURL + AEndpoint;
  
  SetLength(LHeaders, 3);
  LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/json');
  LHeaders[1] := TNameValuePair.Create('X-API-Key', FConfig.ApiKey);
  LHeaders[2] := TNameValuePair.Create('X-Device-Id', FConfig.DeviceId);
  
  LRetry := 0;
  while LRetry <= FConfig.RetryCount do
  begin
    try
      FLock.Enter;
      try
        if AMethod = 'GET' then
        begin
          LResponse := FHttpClient.Get(LURL, nil, LHeaders);
        end
        else if AMethod = 'POST' then
        begin
          if Assigned(ABody) then
          begin
            LBodyStr := ABody.ToJSON;
            if FConfig.EnableEncryption then
              LBodyStr := EncryptData(LBodyStr);
            LStream := TStringStream.Create(LBodyStr, TEncoding.UTF8);
            try
              LResponse := FHttpClient.Post(LURL, LStream, nil, LHeaders);
            finally
              LStream.Free;
            end;
          end
          else
          begin
            LStream := TStringStream.Create('', TEncoding.UTF8);
            try
              LResponse := FHttpClient.Post(LURL, LStream, nil, LHeaders);
            finally
              LStream.Free;
            end;
          end;
        end
        else if AMethod = 'PUT' then
        begin
          if Assigned(ABody) then
          begin
            LBodyStr := ABody.ToJSON;
            if FConfig.EnableEncryption then
              LBodyStr := EncryptData(LBodyStr);
            LStream := TStringStream.Create(LBodyStr, TEncoding.UTF8);
            try
              LResponse := FHttpClient.Put(LURL, LStream, nil, LHeaders);
            finally
              LStream.Free;
            end;
          end
          else
          begin
            LStream := TStringStream.Create('', TEncoding.UTF8);
            try
              LResponse := FHttpClient.Put(LURL, LStream, nil, LHeaders);
            finally
              LStream.Free;
            end;
          end;
        end
        else if AMethod = 'DELETE' then
        begin
          LResponse := FHttpClient.Delete(LURL, nil, LHeaders);
        end;
        
        if LResponse.StatusCode = 200 then
        begin
          LBodyStr := LResponse.ContentAsString;
          if FConfig.EnableEncryption and (LBodyStr <> '') then
            LBodyStr := DecryptData(LBodyStr);
          if LBodyStr <> '' then
            Result := TJSONObject.ParseJSONValue(LBodyStr) as TJSONObject;
          Break;
        end
        else if LResponse.StatusCode >= 500 then
        begin
          Inc(LRetry);
          if LRetry <= FConfig.RetryCount then
            Sleep(1000 * LRetry);  // ָ���˱�
        end
        else
          Break;  // �ͻ��˴��󣬲�����
      finally
        FLock.Leave;
      end;
    except
      Inc(LRetry);
      if LRetry > FConfig.RetryCount then
        raise;
      Sleep(1000 * LRetry);
    end;
  end;
end;

function TCloudSyncClient.EncryptData(const AData: string): string;
var
  LCipher: TBytes;
begin
  // FR-002 fix: previous "encryption" was just Base64 encoding, which gave
  // zero confidentiality. Switch to AES (TSimpleCrypto) keyed by the
  // configured EncryptionKey. When no key is configured, fail-closed
  // and return the data as-is so the caller's enable flag is the
  // single source of truth.
  if FConfig.EncryptionKey = '' then
  begin
    Result := AData;
    Exit;
  end;
  LCipher := TSimpleCrypto.EncryptBytes(
    TEncoding.UTF8.GetBytes(AData), FConfig.EncryptionKey);
  Result := TNetEncoding.Base64.EncodeBytesToString(LCipher);
end;

function TCloudSyncClient.DecryptData(const AData: string): string;
var
  LCipher, LPlain: TBytes;
begin
  if FConfig.EncryptionKey = '' then
  begin
    Result := AData;
    Exit;
  end;
  LCipher := TNetEncoding.Base64.DecodeStringToBytes(AData);
  LPlain := TSimpleCrypto.DecryptBytes(LCipher, FConfig.EncryptionKey);
  Result := TEncoding.UTF8.GetString(LPlain);
end;

function TCloudSyncClient.Authenticate: Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := DoRequest('POST', '/auth/verify', nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Boolean>('success', False);
  finally
    LResponse.Free;
  end;
end;

function TCloudSyncClient.GetRemoteConfig(const AKey: string): TConfigItem;
var
  LResponse: TJSONObject;
begin
  Result := nil;
  LResponse := DoRequest('GET', '/config/' + TNetEncoding.URL.Encode(AKey), nil);
  try
    if Assigned(LResponse) then
      Result := TConfigItem.FromJSON(LResponse);
  finally
    LResponse.Free;
  end;
end;

function TCloudSyncClient.GetAllRemoteConfigs: TObjectList<TConfigItem>;
var
  LResponse: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TConfigItem>.Create(True);
  LResponse := DoRequest('GET', '/config', nil);
  try
    if Assigned(LResponse) then
    begin
      LItems := LResponse.GetValue<TJSONArray>('items');
      if Assigned(LItems) then
      begin
        for I := 0 to LItems.Count - 1 do
          Result.Add(TConfigItem.FromJSON(LItems.Items[I] as TJSONObject));
      end;
    end;
  finally
    LResponse.Free;
  end;
end;

function TCloudSyncClient.GetChangedConfigs(ASinceVersion: Integer): TObjectList<TConfigItem>;
var
  LResponse: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TConfigItem>.Create(True);
  LResponse := DoRequest('GET', '/config/changes?since=' + IntToStr(ASinceVersion), nil);
  try
    if Assigned(LResponse) then
    begin
      LItems := LResponse.GetValue<TJSONArray>('items');
      if Assigned(LItems) then
      begin
        for I := 0 to LItems.Count - 1 do
          Result.Add(TConfigItem.FromJSON(LItems.Items[I] as TJSONObject));
      end;
    end;
  finally
    LResponse.Free;
  end;
end;

function TCloudSyncClient.UploadConfig(AItem: TConfigItem): Boolean;
var
  LResponse: TJSONObject;
  LBody: TJSONObject;
begin
  Result := False;
  LBody := AItem.ToJSON;
  try
    LResponse := DoRequest('PUT', '/config/' + TNetEncoding.URL.Encode(AItem.Key), LBody);
    try
      if Assigned(LResponse) then
        Result := LResponse.GetValue<Boolean>('success', False);
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

function TCloudSyncClient.UploadConfigs(AItems: TObjectList<TConfigItem>): Boolean;
var
  LResponse: TJSONObject;
  LBody: TJSONObject;
  LArray: TJSONArray;
  LItem: TConfigItem;
begin
  Result := False;
  LBody := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    for LItem in AItems do
      LArray.Add(LItem.ToJSON);
    LBody.AddPair('items', LArray);
    
    LResponse := DoRequest('POST', '/config/batch', LBody);
    try
      if Assigned(LResponse) then
        Result := LResponse.GetValue<Boolean>('success', False);
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

function TCloudSyncClient.DeleteRemoteConfig(const AKey: string): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := DoRequest('DELETE', '/config/' + TNetEncoding.URL.Encode(AKey), nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Boolean>('success', False);
  finally
    LResponse.Free;
  end;
end;

function TCloudSyncClient.GetServerVersion: Integer;
var
  LResponse: TJSONObject;
begin
  Result := 0;
  LResponse := DoRequest('GET', '/config/version', nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Integer>('version', 0);
  finally
    LResponse.Free;
  end;
end;

{ TLocalConfigStore }

constructor TLocalConfigStore.Create(const AFilePath: string);
begin
  inherited Create;
  FFilePath := AFilePath;
  FItems := TObjectDictionary<string, TConfigItem>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FCurrentVersion := 0;
  FIsDirty := False;
  
  if TFile.Exists(FFilePath) then
    LoadFromFile;
end;

destructor TLocalConfigStore.Destroy;
begin
  if FIsDirty then
    SaveToFile;
  FreeAndNil(FItems);
  FreeAndNil(FLock);
  inherited;
end;

procedure TLocalConfigStore.LoadFromFile;
var
  LContent: string;
  LJSON: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
  LItem: TConfigItem;
begin
  FLock.Enter;
  try
    LContent := TFile.ReadAllText(FFilePath, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
    try
      if Assigned(LJSON) then
      begin
        FCurrentVersion := LJSON.GetValue<Integer>('version', 0);
        LItems := LJSON.GetValue<TJSONArray>('items');
        if Assigned(LItems) then
        begin
          for I := 0 to LItems.Count - 1 do
          begin
            LItem := TConfigItem.FromJSON(LItems.Items[I] as TJSONObject);
            FItems.AddOrSetValue(LItem.Key, LItem);
          end;
        end;
      end;
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.SaveToFile;
var
  LJSON: TJSONObject;
  LItems: TJSONArray;
  LPair: TPair<string, TConfigItem>;
begin
  FLock.Enter;
  try
    LJSON := TJSONObject.Create;
    try
      LJSON.AddPair('version', TJSONNumber.Create(FCurrentVersion));
      LItems := TJSONArray.Create;
      for LPair in FItems do
        LItems.Add(LPair.Value.ToJSON);
      LJSON.AddPair('items', LItems);
      
      TDirectory.CreateDirectory(TPath.GetDirectoryName(FFilePath));
      TFile.WriteAllText(FFilePath, LJSON.ToJSON, TEncoding.UTF8);
      FIsDirty := False;
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.SetCurrentVersion(AValue: Integer);
begin
  FLock.Enter;
  try
    if FCurrentVersion <> AValue then
    begin
      FCurrentVersion := AValue;
      FIsDirty := True;
    end;
  finally
    FLock.Leave;
  end;
end;

function TLocalConfigStore.Get(const AKey: string): TConfigItem;
begin
  FLock.Enter;
  try
    if not FItems.TryGetValue(AKey, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TLocalConfigStore.GetOrCreate(const AKey: string;
  AItemType: TConfigItemType): TConfigItem;
begin
  FLock.Enter;
  try
    if not FItems.TryGetValue(AKey, Result) then
    begin
      Result := TConfigItem.Create(AKey, AItemType);
      FItems.Add(AKey, Result);
      FIsDirty := True;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.Put(AItem: TConfigItem);
begin
  FLock.Enter;
  try
    FItems.AddOrSetValue(AItem.Key, AItem);
    FIsDirty := True;
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.Delete(const AKey: string);
var
  LItem: TConfigItem;
begin
  FLock.Enter;
  try
    if FItems.TryGetValue(AKey, LItem) then
    begin
      LItem.IsDeleted := True;
      LItem.IsDirty := True;
      FIsDirty := True;
    end;
  finally
    FLock.Leave;
  end;
end;

function TLocalConfigStore.Exists(const AKey: string): Boolean;
var
  LItem: TConfigItem;
begin
  FLock.Enter;
  try
    Result := FItems.TryGetValue(AKey, LItem) and not LItem.IsDeleted;
  finally
    FLock.Leave;
  end;
end;

function TLocalConfigStore.GetAll: TObjectList<TConfigItem>;
var
  LPair: TPair<string, TConfigItem>;
begin
  Result := TObjectList<TConfigItem>.Create(False);  // Don't own objects
  FLock.Enter;
  try
    for LPair in FItems do
      if not LPair.Value.IsDeleted then
        Result.Add(LPair.Value);
  finally
    FLock.Leave;
  end;
end;

function TLocalConfigStore.GetDirtyItems: TObjectList<TConfigItem>;
var
  LPair: TPair<string, TConfigItem>;
begin
  Result := TObjectList<TConfigItem>.Create(False);
  FLock.Enter;
  try
    for LPair in FItems do
      if LPair.Value.IsDirty then
        Result.Add(LPair.Value);
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.MarkAllClean;
var
  LPair: TPair<string, TConfigItem>;
begin
  FLock.Enter;
  try
    for LPair in FItems do
      LPair.Value.IsDirty := False;
    SaveToFile;
  finally
    FLock.Leave;
  end;
end;

procedure TLocalConfigStore.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    FCurrentVersion := 0;
    FIsDirty := True;
    SaveToFile;
  finally
    FLock.Leave;
  end;
end;

{ TCloudConfigSync }

constructor TCloudConfigSync.Create(const AConfig: TCloudServiceConfig;
  const ALocalStorePath: string);
begin
  inherited Create;
  FConfig := AConfig;
  FClient := TCloudSyncClient.Create(AConfig);
  FLocalStore := TLocalConfigStore.Create(ALocalStorePath);
  FConflicts := TObjectList<TSyncConflict>.Create(True);
  FStatus := ssIdle;
  FLock := TCriticalSection.Create;
  FAutoSyncEnabled := False;
  FAutoSyncInterval := 300;
  FStatistics.Reset;
end;

destructor TCloudConfigSync.Destroy;
begin
  DisableAutoSync;
  CancelSync;
  FreeAndNil(FConflicts);
  FreeAndNil(FLocalStore);
  FreeAndNil(FClient);
  FreeAndNil(FLock);
  inherited;
end;

procedure TCloudConfigSync.DoProgress;
var
  LProgress: TSyncProgress;
begin
  if Assigned(FOnProgress) then
  begin
    LProgress := FProgress;
    if TThread.CurrentThread.ThreadID = MainThreadID then
      FOnProgress(Self, LProgress)
    else
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FOnProgress) then
            FOnProgress(Self, LProgress);
        end);
  end;
end;

procedure TCloudConfigSync.DoComplete(Success: Boolean; const ErrorMsg: string);
var
  LSuccess: Boolean;
  LErrorMsg: string;
begin
  if Assigned(FOnComplete) then
  begin
    LSuccess := Success;
    LErrorMsg := ErrorMsg;
    if TThread.CurrentThread.ThreadID = MainThreadID then
      FOnComplete(Self, LSuccess, LErrorMsg)
    else
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(FOnComplete) then
            FOnComplete(Self, LSuccess, LErrorMsg);
        end);
  end;
end;

function TCloudConfigSync.DoResolveConflict(AConflict: TSyncConflict): TConflictResolution;
begin
  Result := FConfig.ConflictResolution;
  // Note: Conflict resolution callback must be synchronous because we need the result immediately
  // If not on main thread, use default resolution strategy
  if Assigned(FOnConflict) then
  begin
    if TThread.CurrentThread.ThreadID = MainThreadID then
      FOnConflict(Self, AConflict, Result);
    // Cannot call async for conflict resolution as we need the result immediately
  end;
end;

function TCloudConfigSync.DetectConflicts(ALocalItems,
  ARemoteItems: TObjectList<TConfigItem>): TObjectList<TSyncConflict>;
var
  LLocalItem, LRemoteItem: TConfigItem;
  LRemoteMap: TDictionary<string, TConfigItem>;
  LConflict: TSyncConflict;
begin
  Result := TObjectList<TSyncConflict>.Create(True);
  LRemoteMap := TDictionary<string, TConfigItem>.Create;
  try
    // ����Զ��������
    for LRemoteItem in ARemoteItems do
      LRemoteMap.AddOrSetValue(LRemoteItem.Key, LRemoteItem);
    
    // ��鱾�����Ƿ��г�ͻ
    for LLocalItem in ALocalItems do
    begin
      if LLocalItem.IsDirty and LRemoteMap.TryGetValue(LLocalItem.Key, LRemoteItem) then
      begin
        // �������޸���Զ��Ҳ���޸� = ��ͻ
        if (LRemoteItem.RemoteVersion.Version > LLocalItem.RemoteVersion.Version) and
           (LLocalItem.LocalVersion.Checksum <> LRemoteItem.RemoteVersion.Checksum) then
        begin
          LConflict := TSyncConflict.Create(LLocalItem.Key, LLocalItem, LRemoteItem);
          Result.Add(LConflict);
        end;
      end;
    end;
  finally
    LRemoteMap.Free;
  end;
end;


procedure TCloudConfigSync.ApplyResolution(AConflict: TSyncConflict);
var
  LResolvedItem: TConfigItem;
begin
  if not AConflict.Resolved then
    Exit;
    
  LResolvedItem := AConflict.GetResolvedItem;
  if Assigned(LResolvedItem) then
  begin
    // ���±��ش洢
    FLocalStore.Put(LResolvedItem);
    Inc(FStatistics.ConflictsResolved);
  end;
end;

procedure TCloudConfigSync.InternalSync;
var
  LLocalItems, LRemoteItems, LDirtyItems: TObjectList<TConfigItem>;
  LDetectedConflicts: TObjectList<TSyncConflict>;
  LItem: TConfigItem;
  LConflict: TSyncConflict;
  LResolution: TConflictResolution;
  LStartTime: TDateTime;
  LDuration: Double;
begin
  LStartTime := Now;
  FStatus := ssSyncing;
  FProgress.Status := ssSyncing;
  FProgress.ErrorMessage := '';
  DoProgress;
  
  try
    // 1. ��ȡԶ������
    FProgress.Status := ssDownloading;
    DoProgress;
    
    LRemoteItems := FClient.GetChangedConfigs(FLocalStore.CurrentVersion);
    try
      FProgress.DownloadedItems := LRemoteItems.Count;
      
      // 2. ��ȡ����������
      LLocalItems := FLocalStore.GetAll;
      LDirtyItems := FLocalStore.GetDirtyItems;
      try
        FProgress.TotalItems := LDirtyItems.Count + LRemoteItems.Count;
        
        // 3. ����ͻ
        if FConfig.SyncDirection = sdBidirectional then
        begin
          LDetectedConflicts := DetectConflicts(LDirtyItems, LRemoteItems);
          try
            FProgress.ConflictCount := LDetectedConflicts.Count;
            
            if LDetectedConflicts.Count > 0 then
            begin
              FProgress.Status := ssConflict;
              DoProgress;
              
              // ������ͻ
              for LConflict in LDetectedConflicts do
              begin
                LResolution := DoResolveConflict(LConflict);
                LConflict.Resolve(LResolution);
                ApplyResolution(LConflict);
                FConflicts.Add(LConflict);
              end;
              LDetectedConflicts.OwnsObjects := False;  // ת������Ȩ
            end;
          finally
            LDetectedConflicts.Free;
          end;
        end;
        
        // 4. Ӧ��Զ�̸��ĵ�����
        if FConfig.SyncDirection in [sdBidirectional, sdDownloadOnly] then
        begin
          for LItem in LRemoteItems do
          begin
            // �����г�ͻ����Ѵ�����
            if not HasConflictForKey(LItem.Key) then
            begin
              FLocalStore.Put(LItem);
              Inc(FProgress.ProcessedItems);
            end;
          end;
        end;
        
        // 5. �ϴ����ظ���
        if FConfig.SyncDirection in [sdBidirectional, sdUploadOnly] then
        begin
          FProgress.Status := ssUploading;
          DoProgress;
          
          if LDirtyItems.Count > 0 then
          begin
            if FClient.UploadConfigs(LDirtyItems) then
            begin
              FProgress.UploadedItems := LDirtyItems.Count;
              FLocalStore.MarkAllClean;
            end;
          end;
        end;
        
        // 6. ���°汾
        FLocalStore.CurrentVersion := FClient.GetServerVersion;
        
        // ����ͳ��
        Inc(FStatistics.TotalSyncs);
        Inc(FStatistics.SuccessfulSyncs);
        FStatistics.LastSyncTime := Now;
        FStatistics.TotalUploaded := FStatistics.TotalUploaded + FProgress.UploadedItems;
        FStatistics.TotalDownloaded := FStatistics.TotalDownloaded + FProgress.DownloadedItems;
        
        LDuration := MilliSecondsBetween(Now, LStartTime);
        if FStatistics.TotalSyncs > 1 then
          FStatistics.AverageSyncDurationMs :=
            (FStatistics.AverageSyncDurationMs * (FStatistics.TotalSyncs - 1) + LDuration) /
            FStatistics.TotalSyncs
        else
          FStatistics.AverageSyncDurationMs := LDuration;
        
        FStatus := ssIdle;
        FProgress.Status := ssIdle;
        DoComplete(True, '');
        
      finally
        LLocalItems.Free;
        LDirtyItems.Free;
      end;
    finally
      LRemoteItems.Free;
    end;
    
  except
    on E: Exception do
    begin
      FStatus := ssError;
      FProgress.Status := ssError;
      FProgress.ErrorMessage := E.Message;
      Inc(FStatistics.TotalSyncs);
      Inc(FStatistics.FailedSyncs);
      DoComplete(False, E.Message);
    end;
  end;
end;

function TCloudConfigSync.HasConflictForKey(const AKey: string): Boolean;
var
  LConflict: TSyncConflict;
begin
  Result := False;
  for LConflict in FConflicts do
    if LConflict.Key = AKey then
      Exit(True);
end;

procedure TCloudConfigSync.Sync;
begin
  if FStatus = ssSyncing then
    Exit;
    
  FLock.Enter;
  try
    InternalSync;
  finally
    FLock.Leave;
  end;
end;

procedure TCloudConfigSync.SyncAsync;
begin
  if FStatus = ssSyncing then
    Exit;

  // EDGE-003 fix: do not use FreeOnTerminate — it creates a dangling pointer
  // window between Terminate and actual thread destruction. Instead, manage
  // the thread lifecycle explicitly via CancelSync/Destroy.
  CancelSync;  // ensure previous thread is fully stopped

  FSyncThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FLock.Enter;
      try
        InternalSync;
      finally
        FLock.Leave;
      end;
    end);
  FSyncThread.FreeOnTerminate := False;
  FSyncThread.Start;
end;

procedure TCloudConfigSync.CancelSync;
var
  LThread: TThread;
begin
  // EDGE-003 fix: capture reference, nil the field, then wait+free.
  // This prevents dangling pointer if another thread calls SyncAsync concurrently.
  LThread := FSyncThread;
  FSyncThread := nil;
  if Assigned(LThread) then
  begin
    LThread.Terminate;
    LThread.WaitFor;
    LThread.Free;
  end;
  FStatus := ssIdle;
end;

procedure TCloudConfigSync.ForceUpload;
var
  LItems: TObjectList<TConfigItem>;
begin
  LItems := FLocalStore.GetAll;
  try
    // ���������Ϊ��
    for var LItem in LItems do
      LItem.IsDirty := True;
    
    if FClient.UploadConfigs(LItems) then
      FLocalStore.MarkAllClean;
  finally
    LItems.Free;
  end;
end;

procedure TCloudConfigSync.ForceDownload;
var
  LRemoteItems: TObjectList<TConfigItem>;
begin
  FLocalStore.Clear;
  
  LRemoteItems := FClient.GetAllRemoteConfigs;
  try
    for var LItem in LRemoteItems do
      FLocalStore.Put(LItem);
    
    FLocalStore.CurrentVersion := FClient.GetServerVersion;
  finally
    LRemoteItems.Free;
  end;
end;

// ���÷��ʷ���

function TCloudConfigSync.GetString(const AKey: string; const ADefault: string): string;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetStringValue
  else
    Result := ADefault;
end;

function TCloudConfigSync.GetInteger(const AKey: string; ADefault: Integer): Integer;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetIntegerValue
  else
    Result := ADefault;
end;

function TCloudConfigSync.GetFloat(const AKey: string; ADefault: Double): Double;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetFloatValue
  else
    Result := ADefault;
end;

function TCloudConfigSync.GetBoolean(const AKey: string; ADefault: Boolean): Boolean;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetBooleanValue
  else
    Result := ADefault;
end;

function TCloudConfigSync.GetDateTime(const AKey: string; ADefault: TDateTime): TDateTime;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetDateTimeValue
  else
    Result := ADefault;
end;

function TCloudConfigSync.GetJSON(const AKey: string): TJSONValue;
var
  LItem: TConfigItem;
begin
  LItem := FLocalStore.Get(AKey);
  if Assigned(LItem) and not LItem.IsDeleted then
    Result := LItem.GetJSONValue
  else
    Result := nil;
end;

procedure TCloudConfigSync.SetString(const AKey, AValue: string);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citString);
  LItem.SetStringValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  LVersion.Checksum := CalculateChecksum(AValue);
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.SetInteger(const AKey: string; AValue: Integer);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citInteger);
  LItem.SetIntegerValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  LVersion.Checksum := CalculateChecksum(IntToStr(AValue));
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.SetFloat(const AKey: string; AValue: Double);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citFloat);
  LItem.SetFloatValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  LVersion.Checksum := CalculateChecksum(FloatToStr(AValue));
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.SetBoolean(const AKey: string; AValue: Boolean);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citBoolean);
  LItem.SetBooleanValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  LVersion.Checksum := CalculateChecksum(BoolToStr(AValue, True));
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.SetDateTime(const AKey: string; AValue: TDateTime);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citDateTime);
  LItem.SetDateTimeValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  LVersion.Checksum := CalculateChecksum(DateToISO8601(AValue));
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.SetJSON(const AKey: string; AValue: TJSONValue);
var
  LItem: TConfigItem;
  LVersion: TConfigVersion;
begin
  LItem := FLocalStore.GetOrCreate(AKey, citJSON);
  LItem.SetJSONValue(AValue);
  LVersion := LItem.LocalVersion;
  LVersion.Version := LVersion.Version + 1;
  LVersion.ModifiedAt := Now;
  LVersion.ModifiedBy := FConfig.DeviceId;
  if Assigned(AValue) then
    LVersion.Checksum := CalculateChecksum(AValue.ToJSON)
  else
    LVersion.Checksum := '';
  LItem.LocalVersion := LVersion;
end;

procedure TCloudConfigSync.DeleteKey(const AKey: string);
begin
  FLocalStore.Delete(AKey);
end;

function TCloudConfigSync.KeyExists(const AKey: string): Boolean;
begin
  Result := FLocalStore.Exists(AKey);
end;

function TCloudConfigSync.HasConflicts: Boolean;
begin
  Result := FConflicts.Count > 0;
end;

function TCloudConfigSync.GetConflicts: TObjectList<TSyncConflict>;
begin
  Result := FConflicts;
end;

procedure TCloudConfigSync.ResolveConflict(const AKey: string;
  AResolution: TConflictResolution);
var
  LConflict: TSyncConflict;
begin
  for LConflict in FConflicts do
  begin
    if LConflict.Key = AKey then
    begin
      LConflict.Resolve(AResolution);
      ApplyResolution(LConflict);
      Break;
    end;
  end;
end;

procedure TCloudConfigSync.ResolveAllConflicts(AResolution: TConflictResolution);
var
  LConflict: TSyncConflict;
begin
  for LConflict in FConflicts do
  begin
    if not LConflict.Resolved then
    begin
      LConflict.Resolve(AResolution);
      ApplyResolution(LConflict);
    end;
  end;
end;

procedure TCloudConfigSync.EnableAutoSync(AIntervalSeconds: Integer);
begin
  FAutoSyncInterval := AIntervalSeconds;
  FAutoSyncEnabled := True;
  StartAutoSyncTimer;
end;

procedure TCloudConfigSync.DisableAutoSync;
begin
  FAutoSyncEnabled := False;
  StopAutoSyncTimer;
end;

procedure TCloudConfigSync.StartAutoSyncTimer;
begin
  StopAutoSyncTimer;
  
  FAutoSyncTimer := TThread.CreateAnonymousThread(
    procedure
    begin
      while not TThread.CurrentThread.CheckTerminated and FAutoSyncEnabled do
      begin
        Sleep(FAutoSyncInterval * 1000);
        if not TThread.CurrentThread.CheckTerminated and FAutoSyncEnabled then
          SyncAsync;
      end;
    end);
  FAutoSyncTimer.FreeOnTerminate := True;
  FAutoSyncTimer.Start;
end;

procedure TCloudConfigSync.StopAutoSyncTimer;
begin
  if Assigned(FAutoSyncTimer) then
  begin
    FAutoSyncTimer.Terminate;
    FAutoSyncTimer := nil;
  end;
end;

{ TConfigChangeLog }

constructor TConfigChangeLog.Create(const ALogPath: string);
begin
  inherited Create;
  FLogPath := ALogPath;
  FLock := TCriticalSection.Create;
  TDirectory.CreateDirectory(TPath.GetDirectoryName(FLogPath));
end;

destructor TConfigChangeLog.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

procedure TConfigChangeLog.LogChange(const AKey, AOldValue, ANewValue: string;
  AChangeType: string);
var
  LEntry: TJSONObject;
  LFile: TStreamWriter;
begin
  FLock.Enter;
  try
    LEntry := TJSONObject.Create;
    try
      LEntry.AddPair('timestamp', DateToISO8601(Now));
      LEntry.AddPair('type', 'change');
      LEntry.AddPair('changeType', AChangeType);
      LEntry.AddPair('key', AKey);
      LEntry.AddPair('oldValue', AOldValue);
      LEntry.AddPair('newValue', ANewValue);
      
      LFile := TStreamWriter.Create(FLogPath, True, TEncoding.UTF8);
      try
        LFile.WriteLine(LEntry.ToJSON);
      finally
        LFile.Free;
      end;
    finally
      LEntry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigChangeLog.LogSync(const ASyncId: string; ASuccess: Boolean;
  const ADetails: string);
var
  LEntry: TJSONObject;
  LFile: TStreamWriter;
begin
  FLock.Enter;
  try
    LEntry := TJSONObject.Create;
    try
      LEntry.AddPair('timestamp', DateToISO8601(Now));
      LEntry.AddPair('type', 'sync');
      LEntry.AddPair('syncId', ASyncId);
      LEntry.AddPair('success', TJSONBool.Create(ASuccess));
      LEntry.AddPair('details', ADetails);
      
      LFile := TStreamWriter.Create(FLogPath, True, TEncoding.UTF8);
      try
        LFile.WriteLine(LEntry.ToJSON);
      finally
        LFile.Free;
      end;
    finally
      LEntry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigChangeLog.LogConflict(const AKey: string;
  AResolution: TConflictResolution);
var
  LEntry: TJSONObject;
  LFile: TStreamWriter;
  LResStr: string;
begin
  case AResolution of
    crLocalWins: LResStr := 'LocalWins';
    crRemoteWins: LResStr := 'RemoteWins';
    crNewerWins: LResStr := 'NewerWins';
    crMerge: LResStr := 'Merge';
    crManual: LResStr := 'Manual';
  end;
  
  FLock.Enter;
  try
    LEntry := TJSONObject.Create;
    try
      LEntry.AddPair('timestamp', DateToISO8601(Now));
      LEntry.AddPair('type', 'conflict');
      LEntry.AddPair('key', AKey);
      LEntry.AddPair('resolution', LResStr);
      
      LFile := TStreamWriter.Create(FLogPath, True, TEncoding.UTF8);
      try
        LFile.WriteLine(LEntry.ToJSON);
      finally
        LFile.Free;
      end;
    finally
      LEntry.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TConfigChangeLog.GetRecentChanges(ACount: Integer): TJSONArray;
var
  LLines: TStringList;
  I, LStart: Integer;
  LObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  
  if not TFile.Exists(FLogPath) then
    Exit;
    
  FLock.Enter;
  try
    LLines := TStringList.Create;
    try
      LLines.LoadFromFile(FLogPath, TEncoding.UTF8);
      LStart := Max(0, LLines.Count - ACount);
      for I := LLines.Count - 1 downto LStart do
      begin
        LObj := TJSONObject.ParseJSONValue(LLines[I]) as TJSONObject;
        if Assigned(LObj) then
          Result.Add(LObj);
      end;
    finally
      LLines.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TConfigChangeLog.Cleanup(ADaysToKeep: Integer);
var
  LLines, LNewLines: TStringList;
  I: Integer;
  LObj: TJSONObject;
  LTimestamp: TDateTime;
  LCutoff: TDateTime;
begin
  if not TFile.Exists(FLogPath) then
    Exit;
    
  LCutoff := IncDay(Now, -ADaysToKeep);
  
  FLock.Enter;
  try
    LLines := TStringList.Create;
    LNewLines := TStringList.Create;
    try
      LLines.LoadFromFile(FLogPath, TEncoding.UTF8);
      
      for I := 0 to LLines.Count - 1 do
      begin
        LObj := TJSONObject.ParseJSONValue(LLines[I]) as TJSONObject;
        if Assigned(LObj) then
        begin
          try
            LTimestamp := ISO8601ToDate(LObj.GetValue<string>('timestamp', ''));
            if LTimestamp >= LCutoff then
              LNewLines.Add(LLines[I]);
          finally
            LObj.Free;
          end;
        end;
      end;
      
      LNewLines.SaveToFile(FLogPath, TEncoding.UTF8);
    finally
      LLines.Free;
      LNewLines.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TMultiTenantSyncManager }

constructor TMultiTenantSyncManager.Create;
begin
  inherited Create;
  FSyncInstances := TObjectDictionary<string, TCloudConfigSync>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FDefaultTenantId := '';
end;

destructor TMultiTenantSyncManager.Destroy;
begin
  FreeAndNil(FSyncInstances);
  FreeAndNil(FLock);
  inherited;
end;

function TMultiTenantSyncManager.RegisterTenant(const ATenantId: string;
  const AConfig: TCloudServiceConfig; const ALocalStorePath: string): TCloudConfigSync;
begin
  FLock.Enter;
  try
    if FSyncInstances.ContainsKey(ATenantId) then
      raise EInvalidOperationException.CreateFmt('Tenant "%s" already registered', [ATenantId]);
      
    Result := TCloudConfigSync.Create(AConfig, ALocalStorePath);
    FSyncInstances.Add(ATenantId, Result);
    
    if FDefaultTenantId = '' then
      FDefaultTenantId := ATenantId;
  finally
    FLock.Leave;
  end;
end;

procedure TMultiTenantSyncManager.UnregisterTenant(const ATenantId: string);
begin
  FLock.Enter;
  try
    FSyncInstances.Remove(ATenantId);
    if FDefaultTenantId = ATenantId then
    begin
      if FSyncInstances.Count > 0 then
        FDefaultTenantId := FSyncInstances.Keys.ToArray[0]
      else
        FDefaultTenantId := '';
    end;
  finally
    FLock.Leave;
  end;
end;

function TMultiTenantSyncManager.GetSync(const ATenantId: string): TCloudConfigSync;
begin
  FLock.Enter;
  try
    if not FSyncInstances.TryGetValue(ATenantId, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TMultiTenantSyncManager.GetDefaultSync: TCloudConfigSync;
begin
  if FDefaultTenantId <> '' then
    Result := GetSync(FDefaultTenantId)
  else
    Result := nil;
end;

procedure TMultiTenantSyncManager.SetDefaultTenant(const ATenantId: string);
begin
  FLock.Enter;
  try
    if FSyncInstances.ContainsKey(ATenantId) then
      FDefaultTenantId := ATenantId
    else
      raise EConfigNotFoundException.CreateFmt('Tenant "%s" not found', [ATenantId]);
  finally
    FLock.Leave;
  end;
end;

procedure TMultiTenantSyncManager.SyncAllTenants;
var
  LPair: TPair<string, TCloudConfigSync>;
begin
  FLock.Enter;
  try
    for LPair in FSyncInstances do
      LPair.Value.SyncAsync;
  finally
    FLock.Leave;
  end;
end;

function TMultiTenantSyncManager.GetTenantIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FSyncInstances.Keys.ToArray;
  finally
    FLock.Leave;
  end;
end;

initialization

finalization
  FreeAndNil(GMultiTenantSync);

end.
