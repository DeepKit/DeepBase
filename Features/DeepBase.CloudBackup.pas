unit DeepBase.CloudBackup;

{*******************************************************************************
  DeepBase Framework - Cloud Backup & Restore
  
  �ƶ˱��ݻָ�ģ�飬֧�֣�
  - �������ݣ������ݱ����
  - ѹ���洢��ZLib/LZMA��
  - �汾��������汾������
  - һ���ָ�
  - ���ݼ��ܣ�AES-256��
  - �Զ����ݵ���
  
  Author: DeepBase Team
  Created: 2025-11-30
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Generics.Collections,
  System.JSON, System.SyncObjs, System.DateUtils, System.Hash, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient, System.Threading, System.IOUtils,
  System.Zip, System.ZLib, DeepBase.Exceptions;

type
  /// <summary>����״̬</summary>
  TBackupStatus = (
    bsIdle,           // ����
    bsPreparing,      // ׼����
    bsCompressing,    // ѹ����
    bsEncrypting,     // ������
    bsUploading,      // �ϴ���
    bsDownloading,    // ������
    bsDecrypting,     // ������
    bsDecompressing,  // ��ѹ��
    bsRestoring,      // �ָ���
    bsCompleted,      // ���
    bsError           // ����
  );

  /// <summary>��������</summary>
  TBackupType = (
    btFull,           // ȫ������
    btIncremental,    // ��������
    btDifferential    // ���챸�ݣ�����������ȫ����
  );

  /// <summary>ѹ������</summary>
  TCompressionLevel = (
    clNone,           // ��ѹ��
    clFast,           // ����ѹ��
    clNormal,         // ��ͨѹ��
    clMax             // ���ѹ��
  );

  /// <summary>���ݵ�������</summary>
  TScheduleType = (
    stNone,           // ������
    stHourly,         // ÿСʱ
    stDaily,          // ÿ��
    stWeekly,         // ÿ��
    stMonthly         // ÿ��
  );

  /// <summary>�ļ��������</summary>
  TFileChangeType = (
    fctAdded,         // ����
    fctModified,      // �޸�
    fctDeleted        // ɾ��
  );

  /// <summary>�����ļ���Ϣ</summary>
  TBackupFileInfo = record
    RelativePath: string;       // ���·��
    FileSize: Int64;            // �ļ���С
    ModifiedTime: TDateTime;    // �޸�ʱ��
    Checksum: string;           // SHA256У���
    ChangeType: TFileChangeType;
    class function Create(const APath: string; ASize: Int64;
      AModTime: TDateTime; const AChecksum: string): TBackupFileInfo; static;
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TBackupFileInfo; static;
  end;

  /// <summary>�����嵥</summary>
  TBackupManifest = class
  private
    FBackupId: string;
    FBackupType: TBackupType;
    FCreatedAt: TDateTime;
    FBasePath: string;
    FFiles: TList<TBackupFileInfo>;
    FTotalSize: Int64;
    FCompressedSize: Int64;
    FFileCount: Integer;
    FParentBackupId: string;    // ����/���챸�ݵĸ�����
    FDescription: string;
    FTags: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddFile(const AFileInfo: TBackupFileInfo);
    procedure RemoveFile(const APath: string);
    function FindFile(const APath: string): Integer;
    
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TBackupManifest;
    
    procedure SaveToFile(const APath: string);
    class function LoadFromFile(const APath: string): TBackupManifest;
    
    property BackupId: string read FBackupId write FBackupId;
    property BackupType: TBackupType read FBackupType write FBackupType;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property BasePath: string read FBasePath write FBasePath;
    property Files: TList<TBackupFileInfo> read FFiles;
    property TotalSize: Int64 read FTotalSize write FTotalSize;
    property CompressedSize: Int64 read FCompressedSize write FCompressedSize;
    property FileCount: Integer read FFileCount write FFileCount;
    property ParentBackupId: string read FParentBackupId write FParentBackupId;
    property Description: string read FDescription write FDescription;
    property Tags: TStringList read FTags;
  end;

  /// <summary>���ݰ汾��Ϣ</summary>
  TBackupVersion = class
  private
    FBackupId: string;
    FBackupType: TBackupType;
    FCreatedAt: TDateTime;
    FFileCount: Integer;
    FTotalSize: Int64;
    FCompressedSize: Int64;
    FDescription: string;
    FIsLocal: Boolean;
    FIsCloud: Boolean;
    FParentBackupId: string;
  public
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TBackupVersion;
    
    property BackupId: string read FBackupId write FBackupId;
    property BackupType: TBackupType read FBackupType write FBackupType;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property FileCount: Integer read FFileCount write FFileCount;
    property TotalSize: Int64 read FTotalSize write FTotalSize;
    property CompressedSize: Int64 read FCompressedSize write FCompressedSize;
    property Description: string read FDescription write FDescription;
    property IsLocal: Boolean read FIsLocal write FIsLocal;
    property IsCloud: Boolean read FIsCloud write FIsCloud;
    property ParentBackupId: string read FParentBackupId write FParentBackupId;
  end;

  /// <summary>���ݽ���</summary>
  TBackupProgress = record
    Status: TBackupStatus;
    CurrentFile: string;
    TotalFiles: Integer;
    ProcessedFiles: Integer;
    TotalBytes: Int64;
    ProcessedBytes: Int64;
    BytesPerSecond: Int64;
    EstimatedSecondsRemaining: Integer;
    ErrorMessage: string;
    function ProgressPercent: Integer;
    function FormattedProgress: string;
  end;

  /// <summary>��������</summary>
  TBackupConfig = record
    SourcePaths: TArray<string>;      // Ҫ���ݵ�·��
    ExcludePatterns: TArray<string>;  // �ų�ģʽ
    IncludePatterns: TArray<string>;  // ����ģʽ
    LocalBackupPath: string;          // ���ر���·��
    CloudServiceURL: string;          // �Ʒ���URL
    CloudApiKey: string;              // ��API��Կ
    CloudBucket: string;              // �ƴ洢Ͱ
    EncryptionKey: string;            // ������Կ
    EnableEncryption: Boolean;        // ���ü���
    CompressionLevel: TCompressionLevel;
    MaxVersionsToKeep: Integer;       // �����汾��
    MaxBackupSizeGB: Integer;         // ��󱸷ݴ�С(GB)
    ScheduleType: TScheduleType;
    ScheduleTime: TTime;              // ����ʱ��
    ScheduleDayOfWeek: Integer;       // �ܼ�������ÿ�ܵ��ȣ�
    ScheduleDayOfMonth: Integer;      // ���ţ�����ÿ�µ��ȣ�
    class function Default: TBackupConfig; static;
  end;

  /// <summary>����ͳ��</summary>
  TBackupStatistics = record
    TotalBackups: Integer;
    SuccessfulBackups: Integer;
    FailedBackups: Integer;
    TotalBytesBackedUp: Int64;
    TotalBytesRestored: Int64;
    LastBackupTime: TDateTime;
    LastRestoreTime: TDateTime;
    AverageBackupDurationSec: Double;
    procedure Reset;
  end;

  // �¼�����
  TBackupProgressEvent = procedure(Sender: TObject; const Progress: TBackupProgress) of object;
  TBackupCompleteEvent = procedure(Sender: TObject; Success: Boolean;
    const BackupId, ErrorMsg: string) of object;
  TRestoreCompleteEvent = procedure(Sender: TObject; Success: Boolean;
    const ErrorMsg: string) of object;

  /// <summary>�ļ���������</summary>
  TFileChangeDetector = class
  private
    FBasePath: string;
    FLastSnapshot: TDictionary<string, TBackupFileInfo>;
    FLock: TCriticalSection;
    
    function CalculateFileChecksum(const APath: string): string;
    function ShouldInclude(const APath: string;
      const AIncludePatterns, AExcludePatterns: TArray<string>): Boolean;
  public
    constructor Create(const ABasePath: string);
    destructor Destroy; override;
    
    procedure TakeSnapshot(const AIncludePatterns, AExcludePatterns: TArray<string>);
    function DetectChanges(const AIncludePatterns, AExcludePatterns: TArray<string>): TList<TBackupFileInfo>;
    procedure LoadSnapshot(const AManifest: TBackupManifest);
    procedure SaveSnapshot(AManifest: TBackupManifest);
    
    property BasePath: string read FBasePath;
  end;

  /// <summary>����ѹ����</summary>
  TBackupCompressor = class
  private
    FCompressionLevel: TCompressionLevel;
    
    function GetZLibLevel: TZCompressionLevel;
  public
    constructor Create(ALevel: TCompressionLevel = clNormal);
    
    procedure CompressFile(const ASourcePath, ADestPath: string);
    procedure DecompressFile(const ASourcePath, ADestPath: string);
    procedure CompressStream(ASource, ADest: TStream);
    procedure DecompressStream(ASource, ADest: TStream);
    function CompressBytes(const AData: TBytes): TBytes;
    function DecompressBytes(const AData: TBytes): TBytes;
    
    // ZIP����
    procedure CreateArchive(const AArchivePath: string;
      const AFiles: TList<TBackupFileInfo>; const ABasePath: string;
      AProgressCallback: TProc<Integer, Integer> = nil);
    procedure ExtractArchive(const AArchivePath, ADestPath: string;
      AProgressCallback: TProc<Integer, Integer> = nil);
    
    property CompressionLevel: TCompressionLevel read FCompressionLevel write FCompressionLevel;
  end;

  /// <summary>���ݼ�����</summary>
  TBackupEncryptor = class
  private
    FKey: TBytes;
    FIV: TBytes;
    
    procedure DeriveKeyAndIV(const APassword: string);
  public
    constructor Create(const APassword: string);
    destructor Destroy; override;
    
    procedure EncryptFile(const ASourcePath, ADestPath: string);
    procedure DecryptFile(const ASourcePath, ADestPath: string);
    procedure EncryptStream(ASource, ADest: TStream);
    procedure DecryptStream(ASource, ADest: TStream);
    function EncryptBytes(const AData: TBytes): TBytes;
    function DecryptBytes(const AData: TBytes): TBytes;
  end;

  /// <summary>�ƶ˱��ݿͻ���</summary>
  TCloudBackupClient = class
  private
    FServiceURL: string;
    FApiKey: string;
    FBucket: string;
    FHttpClient: THTTPClient;
    FLock: TCriticalSection;
    
    function DoRequest(const AMethod, AEndpoint: string;
      ABody: TStream = nil; AHeaders: TNetHeaders = nil): IHTTPResponse;
  public
    constructor Create(const AServiceURL, AApiKey, ABucket: string);
    destructor Destroy; override;
    
    function UploadBackup(const ALocalPath, ARemoteKey: string;
      AProgressCallback: TProc<Int64, Int64> = nil): Boolean;
    function DownloadBackup(const ARemoteKey, ALocalPath: string;
      AProgressCallback: TProc<Int64, Int64> = nil): Boolean;
    function DeleteBackup(const ARemoteKey: string): Boolean;
    function ListBackups(const APrefix: string = ''): TObjectList<TBackupVersion>;
    function GetBackupInfo(const ABackupId: string): TBackupVersion;
    function BackupExists(const ARemoteKey: string): Boolean;
    
    property ServiceURL: string read FServiceURL;
    property Bucket: string read FBucket;
  end;

  /// <summary>���ݵ�����</summary>
  TBackupScheduler = class
  private
    FConfig: TBackupConfig;
    FEnabled: Boolean;
    FSchedulerThread: TThread;
    FStopEvent: TEvent;
    FOnBackupTriggered: TNotifyEvent;
    FLastTriggerTime: TDateTime;
    FLock: TCriticalSection;
    
    function ShouldTrigger: Boolean;
    procedure SchedulerLoop;
  public
    constructor Create(const AConfig: TBackupConfig);
    destructor Destroy; override;
    
    procedure Start;
    procedure Stop;
    function GetNextScheduledTime: TDateTime;
    
    property Enabled: Boolean read FEnabled;
    property LastTriggerTime: TDateTime read FLastTriggerTime;
    property OnBackupTriggered: TNotifyEvent read FOnBackupTriggered write FOnBackupTriggered;
  end;

  /// <summary>�ƶ˱��ݹ�����</summary>
  TCloudBackupManager = class
  private
    FConfig: TBackupConfig;
    FCloudClient: TCloudBackupClient;
    FChangeDetector: TFileChangeDetector;
    FCompressor: TBackupCompressor;
    FEncryptor: TBackupEncryptor;
    FScheduler: TBackupScheduler;
    FVersions: TObjectList<TBackupVersion>;
    FStatus: TBackupStatus;
    FProgress: TBackupProgress;
    FStatistics: TBackupStatistics;
    FLock: TCriticalSection;
    FBackupThread: TThread;
    FRestoreThread: TThread;
    FCancelled: Boolean;
    
    FOnProgress: TBackupProgressEvent;
    FOnBackupComplete: TBackupCompleteEvent;
    FOnRestoreComplete: TRestoreCompleteEvent;
    
    procedure DoProgress;
    procedure DoBackupComplete(Success: Boolean; const ABackupId, AErrorMsg: string);
    procedure DoRestoreComplete(Success: Boolean; const AErrorMsg: string);
    
    function GenerateBackupId: string;
    function GetBackupArchivePath(const ABackupId: string): string;
    function GetManifestPath(const ABackupId: string): string;
    
    procedure InternalBackup(ABackupType: TBackupType; const ADescription: string);
    procedure InternalRestore(const ABackupId: string; const ATargetPath: string);
    
    procedure LoadVersions;
    procedure SaveVersions;
    procedure CleanupOldVersions;
    
    procedure SchedulerBackupTriggered(Sender: TObject);
  public
    constructor Create(const AConfig: TBackupConfig);
    destructor Destroy; override;
    
    // ���ݲ���
    procedure BackupFull(const ADescription: string = '');
    procedure BackupIncremental(const ADescription: string = '');
    procedure BackupDifferential(const ADescription: string = '');
    procedure BackupFullAsync(const ADescription: string = '');
    procedure BackupIncrementalAsync(const ADescription: string = '');
    
    // �ָ�����
    procedure Restore(const ABackupId: string; const ATargetPath: string = '');
    procedure RestoreAsync(const ABackupId: string; const ATargetPath: string = '');
    procedure RestoreLatest(const ATargetPath: string = '');
    
    // ȡ������
    procedure Cancel;
    
    // �汾����
    function GetVersions: TObjectList<TBackupVersion>;
    function GetVersion(const ABackupId: string): TBackupVersion;
    procedure DeleteVersion(const ABackupId: string);
    procedure DeleteAllVersions;
    
    // �ƶ�ͬ��
    procedure SyncToCloud(const ABackupId: string);
    procedure SyncFromCloud(const ABackupId: string);
    procedure SyncAllToCloud;
    function GetCloudVersions: TObjectList<TBackupVersion>;
    
    // ��֤
    function VerifyBackup(const ABackupId: string): Boolean;
    function GetBackupManifest(const ABackupId: string): TBackupManifest;
    
    // ����
    procedure EnableScheduler;
    procedure DisableScheduler;
    function GetNextScheduledBackup: TDateTime;
    
    // ״̬
    property Status: TBackupStatus read FStatus;
    property Progress: TBackupProgress read FProgress;
    property Statistics: TBackupStatistics read FStatistics;
    property Config: TBackupConfig read FConfig write FConfig;
    
    // �¼�
    property OnProgress: TBackupProgressEvent read FOnProgress write FOnProgress;
    property OnBackupComplete: TBackupCompleteEvent read FOnBackupComplete write FOnBackupComplete;
    property OnRestoreComplete: TRestoreCompleteEvent read FOnRestoreComplete write FOnRestoreComplete;
  end;

// ȫ�ֺ���
function CloudBackup: TCloudBackupManager;
procedure SetCloudBackup(AManager: TCloudBackupManager);

// ��������
function FormatFileSize(ABytes: Int64): string;
function FormatDuration(ASeconds: Integer): string;

implementation

var
  GCloudBackup: TCloudBackupManager = nil;

function GetJsonString(AJSON: TJSONObject; const AName: string;
  const AFallbackName: string = ''; const ADefault: string = ''): string;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJSON) then
    Exit;

  LValue := AJSON.GetValue(AName);
  if (not Assigned(LValue)) and (AFallbackName <> '') then
    LValue := AJSON.GetValue(AFallbackName);

  if Assigned(LValue) then
    Result := LValue.Value;
end;

function GetJsonInt64(AJSON: TJSONObject; const AName: string;
  const AFallbackName: string = ''; const ADefault: Int64 = 0): Int64;
var
  LValue: string;
begin
  LValue := GetJsonString(AJSON, AName, AFallbackName, '');
  if (LValue = '') or (not TryStrToInt64(LValue, Result)) then
    Result := ADefault;
end;

function GetJsonInteger(AJSON: TJSONObject; const AName: string;
  const AFallbackName: string = ''; const ADefault: Integer = 0): Integer;
var
  LValue: string;
begin
  LValue := GetJsonString(AJSON, AName, AFallbackName, '');
  if (LValue = '') or (not TryStrToInt(LValue, Result)) then
    Result := ADefault;
end;

function GetJsonArray(AJSON: TJSONObject; const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if not Assigned(AJSON) then
    Exit;

  LValue := AJSON.GetValue(AName);
  if LValue is TJSONArray then
    Result := TJSONArray(LValue);
end;

function JsonStringToDateTime(const AValue: string; const ADefault: TDateTime): TDateTime;
var
  LValue: string;
  LFloat: Double;
  LFormatSettings: TFormatSettings;
begin
  LValue := Trim(AValue);
  if LValue = '' then
    Exit(ADefault);

  if TryStrToFloat(LValue, LFloat) then
    Exit(LFloat);

  LFormatSettings := TFormatSettings.Create;
  LFormatSettings.DecimalSeparator := '.';
  LFormatSettings.ThousandSeparator := ',';
  if TryStrToFloat(LValue, LFloat, LFormatSettings) then
    Exit(LFloat);

  Result := ISO8601ToDate(LValue);
end;

function CloudBackup: TCloudBackupManager;
begin
  Result := GCloudBackup;
end;

procedure SetCloudBackup(AManager: TCloudBackupManager);
begin
  GCloudBackup := AManager;
end;

function FormatFileSize(ABytes: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.2f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.2f KB', [ABytes / KB])
  else
    Result := Format('%d B', [ABytes]);
end;

function FormatDuration(ASeconds: Integer): string;
var
  H, M, S: Integer;
begin
  H := ASeconds div 3600;
  M := (ASeconds mod 3600) div 60;
  S := ASeconds mod 60;
  
  if H > 0 then
    Result := Format('%dh %dm %ds', [H, M, S])
  else if M > 0 then
    Result := Format('%dm %ds', [M, S])
  else
    Result := Format('%ds', [S]);
end;

{ TBackupFileInfo }

class function TBackupFileInfo.Create(const APath: string; ASize: Int64;
  AModTime: TDateTime; const AChecksum: string): TBackupFileInfo;
begin
  Result.RelativePath := APath;
  Result.FileSize := ASize;
  Result.ModifiedTime := AModTime;
  Result.Checksum := AChecksum;
  Result.ChangeType := fctAdded;
end;

function TBackupFileInfo.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('relativePath', RelativePath);
  Result.AddPair('fileSize', TJSONNumber.Create(FileSize));
  Result.AddPair('modifiedTime', DateToISO8601(ModifiedTime));
  Result.AddPair('checksum', Checksum);
  Result.AddPair('changeType', TJSONNumber.Create(Ord(ChangeType)));
end;

class function TBackupFileInfo.FromJSON(AJSON: TJSONObject): TBackupFileInfo;
begin
  Result.RelativePath := GetJsonString(AJSON, 'relativePath', 'path');
  Result.FileSize := GetJsonInt64(AJSON, 'fileSize', 'size');
  Result.ModifiedTime := JsonStringToDateTime(
    GetJsonString(AJSON, 'modifiedTime', 'modified'), 0);
  Result.Checksum := GetJsonString(AJSON, 'checksum');
  Result.ChangeType := TFileChangeType(GetJsonInteger(AJSON, 'changeType'));
end;

{ TBackupManifest }

constructor TBackupManifest.Create;
begin
  inherited Create;
  FFiles := TList<TBackupFileInfo>.Create;
  FTags := TStringList.Create;
  FBackupId := '';
  FCreatedAt := Now;
end;

destructor TBackupManifest.Destroy;
begin
  FreeAndNil(FFiles);
  FreeAndNil(FTags);
  inherited;
end;

procedure TBackupManifest.AddFile(const AFileInfo: TBackupFileInfo);
begin
  FFiles.Add(AFileInfo);
  Inc(FFileCount);
  FTotalSize := FTotalSize + AFileInfo.FileSize;
end;

procedure TBackupManifest.RemoveFile(const APath: string);
var
  I: Integer;
begin
  I := FindFile(APath);
  if I >= 0 then
  begin
    FTotalSize := FTotalSize - FFiles[I].FileSize;
    Dec(FFileCount);
    FFiles.Delete(I);
  end;
end;

function TBackupManifest.FindFile(const APath: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FFiles.Count - 1 do
    if SameText(FFiles[I].RelativePath, APath) then
      Exit(I);
end;

function TBackupManifest.ToJSON: TJSONObject;
var
  LFilesArray, LTagsArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('backupId', FBackupId);
  Result.AddPair('backupType', TJSONNumber.Create(Ord(FBackupType)));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
  Result.AddPair('basePath', FBasePath);
  Result.AddPair('totalSize', TJSONNumber.Create(FTotalSize));
  Result.AddPair('compressedSize', TJSONNumber.Create(FCompressedSize));
  Result.AddPair('fileCount', TJSONNumber.Create(FFileCount));
  Result.AddPair('parentBackupId', FParentBackupId);
  Result.AddPair('description', FDescription);
  
  LFilesArray := TJSONArray.Create;
  for I := 0 to FFiles.Count - 1 do
    LFilesArray.Add(FFiles[I].ToJSON);
  Result.AddPair('files', LFilesArray);
  
  LTagsArray := TJSONArray.Create;
  for I := 0 to FTags.Count - 1 do
    LTagsArray.Add(FTags[I]);
  Result.AddPair('tags', LTagsArray);
end;

class function TBackupManifest.FromJSON(AJSON: TJSONObject): TBackupManifest;
var
  LFilesArray, LTagsArray: TJSONArray;
  I: Integer;
begin
  Result := TBackupManifest.Create;
  try
    Result.FBackupId := GetJsonString(AJSON, 'backupId');
    Result.FBackupType := TBackupType(GetJsonInteger(AJSON, 'backupType'));
    Result.FCreatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'createdAt'), 0);
    Result.FBasePath := GetJsonString(AJSON, 'basePath');
    Result.FTotalSize := GetJsonInt64(AJSON, 'totalSize');
    Result.FCompressedSize := GetJsonInt64(AJSON, 'compressedSize');
    Result.FFileCount := GetJsonInteger(AJSON, 'fileCount');
    Result.FParentBackupId := GetJsonString(AJSON, 'parentBackupId');
    Result.FDescription := GetJsonString(AJSON, 'description');

    LFilesArray := GetJsonArray(AJSON, 'files');
    if Assigned(LFilesArray) then
      for I := 0 to LFilesArray.Count - 1 do
        Result.FFiles.Add(TBackupFileInfo.FromJSON(LFilesArray.Items[I] as TJSONObject));

    LTagsArray := GetJsonArray(AJSON, 'tags');
    if Assigned(LTagsArray) then
      for I := 0 to LTagsArray.Count - 1 do
        Result.FTags.Add(LTagsArray.Items[I].Value);
  except
    Result.Free;
    raise;
  end;
end;

procedure TBackupManifest.SaveToFile(const APath: string);
var
  LJSON: TJSONObject;
begin
  LJSON := ToJSON;
  try
    TFile.WriteAllText(APath, LJSON.ToJSON, TEncoding.UTF8);
  finally
    LJSON.Free;
  end;
end;

class function TBackupManifest.LoadFromFile(const APath: string): TBackupManifest;
var
  LContent: string;
  LJSON: TJSONObject;
begin
  LContent := TFile.ReadAllText(APath, TEncoding.UTF8);
  LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONObject;
  try
    Result := FromJSON(LJSON);
  finally
    LJSON.Free;
  end;
end;

{ TBackupVersion }

function TBackupVersion.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('backupId', FBackupId);
  Result.AddPair('backupType', TJSONNumber.Create(Ord(FBackupType)));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
  Result.AddPair('fileCount', TJSONNumber.Create(FFileCount));
  Result.AddPair('totalSize', TJSONNumber.Create(FTotalSize));
  Result.AddPair('compressedSize', TJSONNumber.Create(FCompressedSize));
  Result.AddPair('description', FDescription);
  Result.AddPair('isLocal', TJSONBool.Create(FIsLocal));
  Result.AddPair('isCloud', TJSONBool.Create(FIsCloud));
  Result.AddPair('parentBackupId', FParentBackupId);
end;

class function TBackupVersion.FromJSON(AJSON: TJSONObject): TBackupVersion;
begin
  Result := TBackupVersion.Create;
  try
    Result.FBackupId := GetJsonString(AJSON, 'backupId');
    Result.FBackupType := TBackupType(GetJsonInteger(AJSON, 'backupType'));
    Result.FCreatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'createdAt'), 0);
    Result.FFileCount := GetJsonInteger(AJSON, 'fileCount');
    Result.FTotalSize := GetJsonInt64(AJSON, 'totalSize');
    Result.FCompressedSize := GetJsonInt64(AJSON, 'compressedSize');
    Result.FDescription := GetJsonString(AJSON, 'description');
    Result.FIsLocal := AJSON.GetValue<Boolean>('isLocal', False);
    Result.FIsCloud := AJSON.GetValue<Boolean>('isCloud', False);
    Result.FParentBackupId := GetJsonString(AJSON, 'parentBackupId');
  except
    Result.Free;
    raise;
  end;
end;

{ TBackupProgress }

function TBackupProgress.ProgressPercent: Integer;
begin
  if TotalBytes > 0 then
    Result := (ProcessedBytes * 100) div TotalBytes
  else if TotalFiles > 0 then
    Result := (ProcessedFiles * 100) div TotalFiles
  else
    Result := 0;
end;

function TBackupProgress.FormattedProgress: string;
begin
  Result := Format('%d%% (%s / %s) - %s/s',
    [ProgressPercent,
     FormatFileSize(ProcessedBytes),
     FormatFileSize(TotalBytes),
     FormatFileSize(BytesPerSecond)]);
end;

{ TBackupConfig }

class function TBackupConfig.Default: TBackupConfig;
begin
  SetLength(Result.SourcePaths, 0);
  SetLength(Result.ExcludePatterns, 0);
  SetLength(Result.IncludePatterns, 0);
  Result.LocalBackupPath := TPath.Combine(TPath.GetHomePath, 'DeepBaseBackups');
  Result.CloudServiceURL := 'https://backup.DeepBase.cloud/v1';
  Result.CloudApiKey := '';
  Result.CloudBucket := 'default';
  Result.EncryptionKey := '';
  Result.EnableEncryption := False;
  Result.CompressionLevel := clNormal;
  Result.MaxVersionsToKeep := 10;
  Result.MaxBackupSizeGB := 100;
  Result.ScheduleType := stNone;
  Result.ScheduleTime := EncodeTime(2, 0, 0, 0);  // Ĭ���賿2��
  Result.ScheduleDayOfWeek := 1;  // ��һ
  Result.ScheduleDayOfMonth := 1; // 1��
end;

{ TBackupStatistics }

procedure TBackupStatistics.Reset;
begin
  TotalBackups := 0;
  SuccessfulBackups := 0;
  FailedBackups := 0;
  TotalBytesBackedUp := 0;
  TotalBytesRestored := 0;
  LastBackupTime := 0;
  LastRestoreTime := 0;
  AverageBackupDurationSec := 0;
end;

{ TFileChangeDetector }

constructor TFileChangeDetector.Create(const ABasePath: string);
begin
  inherited Create;
  FBasePath := ABasePath;
  FLastSnapshot := TDictionary<string, TBackupFileInfo>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TFileChangeDetector.Destroy;
begin
  FreeAndNil(FLastSnapshot);
  FreeAndNil(FLock);
  inherited;
end;

function TFileChangeDetector.CalculateFileChecksum(const APath: string): string;
var
  LStream: TFileStream;
  LHash: THashSHA2;
begin
  LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(LStream);
  finally
    LStream.Free;
  end;
end;

function TFileChangeDetector.ShouldInclude(const APath: string;
  const AIncludePatterns, AExcludePatterns: TArray<string>): Boolean;
var
  LPattern: string;
  LFileName: string;
begin
  LFileName := ExtractFileName(APath);
  
  // ����ų�ģʽ
  for LPattern in AExcludePatterns do
    if TPath.MatchesPattern(LFileName, LPattern, False) then
      Exit(False);
  
  // ���û�а���ģʽ��Ĭ�ϰ�������
  if Length(AIncludePatterns) = 0 then
    Exit(True);
    
  // ������ģʽ
  for LPattern in AIncludePatterns do
    if TPath.MatchesPattern(LFileName, LPattern, False) then
      Exit(True);
      
  Result := False;
end;

procedure TFileChangeDetector.TakeSnapshot(const AIncludePatterns,
  AExcludePatterns: TArray<string>);
var
  LFiles: TStringDynArray;
  LFile: string;
  LInfo: TBackupFileInfo;
  LRelPath: string;
begin
  FLock.Enter;
  try
    FLastSnapshot.Clear;
    
    if not TDirectory.Exists(FBasePath) then
      Exit;
      
    LFiles := TDirectory.GetFiles(FBasePath, '*', TSearchOption.soAllDirectories);
    for LFile in LFiles do
    begin
      if not ShouldInclude(LFile, AIncludePatterns, AExcludePatterns) then
        Continue;
        
      LRelPath := ExtractRelativePath(FBasePath + PathDelim, LFile);
      LInfo.RelativePath := LRelPath;
      LInfo.FileSize := TFile.GetSize(LFile);
      LInfo.ModifiedTime := TFile.GetLastWriteTime(LFile);
      LInfo.Checksum := CalculateFileChecksum(LFile);
      LInfo.ChangeType := fctAdded;
      
      FLastSnapshot.Add(LRelPath, LInfo);
    end;
  finally
    FLock.Leave;
  end;
end;

function TFileChangeDetector.DetectChanges(const AIncludePatterns,
  AExcludePatterns: TArray<string>): TList<TBackupFileInfo>;
var
  LFiles: TStringDynArray;
  LFile: string;
  LInfo, LOldInfo: TBackupFileInfo;
  LRelPath: string;
  LCurrentFiles: TDictionary<string, TBackupFileInfo>;
  LPair: TPair<string, TBackupFileInfo>;
begin
  Result := TList<TBackupFileInfo>.Create;
  LCurrentFiles := TDictionary<string, TBackupFileInfo>.Create;
  
  FLock.Enter;
  try
    try
      if not TDirectory.Exists(FBasePath) then
        Exit;
        
      // ɨ�赱ǰ�ļ�
      LFiles := TDirectory.GetFiles(FBasePath, '*', TSearchOption.soAllDirectories);
      for LFile in LFiles do
      begin
        if not ShouldInclude(LFile, AIncludePatterns, AExcludePatterns) then
          Continue;
          
        LRelPath := ExtractRelativePath(FBasePath + PathDelim, LFile);
        LInfo.RelativePath := LRelPath;
        LInfo.FileSize := TFile.GetSize(LFile);
        LInfo.ModifiedTime := TFile.GetLastWriteTime(LFile);
        LInfo.Checksum := CalculateFileChecksum(LFile);
        
        // ����Ƿ����������޸�
        if FLastSnapshot.TryGetValue(LRelPath, LOldInfo) then
        begin
          if LInfo.Checksum <> LOldInfo.Checksum then
          begin
            LInfo.ChangeType := fctModified;
            Result.Add(LInfo);
          end;
        end
        else
        begin
          LInfo.ChangeType := fctAdded;
          Result.Add(LInfo);
        end;
        
        LCurrentFiles.Add(LRelPath, LInfo);
      end;
      
      // ���ɾ�����ļ�
      for LPair in FLastSnapshot do
      begin
        if not LCurrentFiles.ContainsKey(LPair.Key) then
        begin
          LInfo := LPair.Value;
          LInfo.ChangeType := fctDeleted;
          Result.Add(LInfo);
        end;
      end;
      
      // ���¿���
      FLastSnapshot.Clear;
      for LPair in LCurrentFiles do
        FLastSnapshot.Add(LPair.Key, LPair.Value);
        
    finally
      LCurrentFiles.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TFileChangeDetector.LoadSnapshot(const AManifest: TBackupManifest);
var
  I: Integer;
begin
  FLock.Enter;
  try
    FLastSnapshot.Clear;
    for I := 0 to AManifest.Files.Count - 1 do
      FLastSnapshot.Add(AManifest.Files[I].RelativePath, AManifest.Files[I]);
  finally
    FLock.Leave;
  end;
end;

procedure TFileChangeDetector.SaveSnapshot(AManifest: TBackupManifest);
var
  LPair: TPair<string, TBackupFileInfo>;
begin
  FLock.Enter;
  try
    AManifest.Files.Clear;
    AManifest.FFileCount := 0;
    AManifest.FTotalSize := 0;
    
    for LPair in FLastSnapshot do
      AManifest.AddFile(LPair.Value);
  finally
    FLock.Leave;
  end;
end;

{ TBackupCompressor }

constructor TBackupCompressor.Create(ALevel: TCompressionLevel);
begin
  inherited Create;
  FCompressionLevel := ALevel;
end;

function TBackupCompressor.GetZLibLevel: TZCompressionLevel;
begin
  case FCompressionLevel of
    clNone: Result := zcNone;
    clFast: Result := zcFastest;
    clNormal: Result := zcDefault;
    clMax: Result := zcMax;
  else
    Result := zcDefault;
  end;
end;

procedure TBackupCompressor.CompressFile(const ASourcePath, ADestPath: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestPath, fmCreate);
    try
      CompressStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TBackupCompressor.DecompressFile(const ASourcePath, ADestPath: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestPath, fmCreate);
    try
      DecompressStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TBackupCompressor.CompressStream(ASource, ADest: TStream);
begin
  if FCompressionLevel = clNone then
  begin
    ADest.CopyFrom(ASource, 0);
    Exit;
  end;
  
  ZCompressStream(ASource, ADest, GetZLibLevel);
end;

procedure TBackupCompressor.DecompressStream(ASource, ADest: TStream);
var
  LDecompressor: TZDecompressionStream;
  LBuffer: TBytes;
  LBytesRead: Integer;
begin
  LDecompressor := TZDecompressionStream.Create(ASource);
  try
    SetLength(LBuffer, 65536);
    repeat
      LBytesRead := LDecompressor.Read(LBuffer[0], Length(LBuffer));
      if LBytesRead > 0 then
        ADest.WriteBuffer(LBuffer[0], LBytesRead);
    until LBytesRead = 0;
  finally
    LDecompressor.Free;
  end;
end;

function TBackupCompressor.CompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  try
    LDest := TBytesStream.Create;
    try
      CompressStream(LSource, LDest);
      Result := LDest.Bytes;
      SetLength(Result, LDest.Size);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

function TBackupCompressor.DecompressBytes(const AData: TBytes): TBytes;
var
  LSource, LDest: TBytesStream;
begin
  LSource := TBytesStream.Create(AData);
  try
    LDest := TBytesStream.Create;
    try
      DecompressStream(LSource, LDest);
      Result := LDest.Bytes;
      SetLength(Result, LDest.Size);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TBackupCompressor.CreateArchive(const AArchivePath: string;
  const AFiles: TList<TBackupFileInfo>; const ABasePath: string;
  AProgressCallback: TProc<Integer, Integer>);
var
  LZip: TZipFile;
  I: Integer;
  LFullPath: string;
begin
  LZip := TZipFile.Create;
  try
    LZip.Open(AArchivePath, zmWrite);
    try
      for I := 0 to AFiles.Count - 1 do
      begin
        if AFiles[I].ChangeType <> fctDeleted then
        begin
          LFullPath := TPath.Combine(ABasePath, AFiles[I].RelativePath);
          if TFile.Exists(LFullPath) then
            LZip.Add(LFullPath, AFiles[I].RelativePath);
        end;
        
        if Assigned(AProgressCallback) then
          AProgressCallback(I + 1, AFiles.Count);
      end;
    finally
      LZip.Close;
    end;
  finally
    LZip.Free;
  end;
end;

procedure TBackupCompressor.ExtractArchive(const AArchivePath, ADestPath: string;
  AProgressCallback: TProc<Integer, Integer>);
var
  LZip: TZipFile;
  I: Integer;
  LEntryName: string;
  LDestPath: string;
  LBytes: TBytes;
  LStream: TFileStream;

  function BuildSafeDestination(const AEntryName: string): string;
  var
    LRoot: string;
    LEntry: string;
  begin
    LEntry := StringReplace(AEntryName, '/', PathDelim, [rfReplaceAll]);
    LEntry := StringReplace(LEntry, '\', PathDelim, [rfReplaceAll]);

    if (LEntry = '') or (ExtractFileDrive(LEntry) <> '') or
       LEntry.StartsWith(PathDelim) or LEntry.StartsWith('/') or
       LEntry.StartsWith('\') then
      raise Exception.CreateFmt('Unsafe backup archive entry path: %s', [AEntryName]);

    LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ADestPath));
    Result := TPath.GetFullPath(TPath.Combine(LRoot, LEntry));

    if not SameText(Copy(Result, 1, Length(LRoot)), LRoot) then
      raise Exception.CreateFmt('Backup archive entry escapes destination directory: %s', [AEntryName]);
  end;
begin
  TDirectory.CreateDirectory(ADestPath);
  
  LZip := TZipFile.Create;
  try
    LZip.Open(AArchivePath, zmRead);
    try
      for I := 0 to LZip.FileCount - 1 do
      begin
        LEntryName := LZip.FileName[I];
        LDestPath := BuildSafeDestination(LEntryName);

        if LEntryName.EndsWith('/') or LEntryName.EndsWith('\') then
          TDirectory.CreateDirectory(LDestPath)
        else
        begin
          TDirectory.CreateDirectory(TPath.GetDirectoryName(LDestPath));
          LZip.Read(I, LBytes);
          LStream := TFileStream.Create(LDestPath, fmCreate);
          try
            if Length(LBytes) > 0 then
              LStream.WriteBuffer(LBytes[0], Length(LBytes));
          finally
            LStream.Free;
          end;
        end;
        
        if Assigned(AProgressCallback) then
          AProgressCallback(I + 1, LZip.FileCount);
      end;
    finally
      LZip.Close;
    end;
  finally
    LZip.Free;
  end;
end;
{ TBackupEncryptor }

constructor TBackupEncryptor.Create(const APassword: string);
begin
  inherited Create;
  DeriveKeyAndIV(APassword);
end;

destructor TBackupEncryptor.Destroy;
begin
  // �����Կ
  FillChar(FKey[0], Length(FKey), 0);
  FillChar(FIV[0], Length(FIV), 0);
  inherited;
end;

procedure TBackupEncryptor.DeriveKeyAndIV(const APassword: string);
var
  LHash: TBytes;
begin
  // ʹ��SHA-256������Կ��ʵ��Ӧʹ��PBKDF2��
  LHash := THashSHA2.GetHashBytes(APassword);
  
  SetLength(FKey, 32);  // 256 bits
  SetLength(FIV, 16);   // 128 bits
  
  Move(LHash[0], FKey[0], 32);
  
  // ���������һ����ϣ����IV
  LHash := THashSHA2.GetHashBytes(APassword + 'IV');
  Move(LHash[0], FIV[0], 16);
end;

procedure TBackupEncryptor.EncryptFile(const ASourcePath, ADestPath: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestPath, fmCreate);
    try
      EncryptStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TBackupEncryptor.DecryptFile(const ASourcePath, ADestPath: string);
var
  LSource, LDest: TFileStream;
begin
  LSource := TFileStream.Create(ASourcePath, fmOpenRead or fmShareDenyWrite);
  try
    LDest := TFileStream.Create(ADestPath, fmCreate);
    try
      DecryptStream(LSource, LDest);
    finally
      LDest.Free;
    end;
  finally
    LSource.Free;
  end;
end;

procedure TBackupEncryptor.EncryptStream(ASource, ADest: TStream);
var
  LData: TBytes;
begin
  // ��ʵ�֣�ʵ��Ӧʹ��AES-256-CBC/GCM
  // ������XOR��Base64ģ�⣬����������Ҫʹ�������ļ��ܿ�
  SetLength(LData, ASource.Size);
  ASource.Position := 0;
  ASource.ReadBuffer(LData[0], Length(LData));
  
  LData := EncryptBytes(LData);
  
  ADest.WriteBuffer(LData[0], Length(LData));
end;

procedure TBackupEncryptor.DecryptStream(ASource, ADest: TStream);
var
  LData: TBytes;
begin
  SetLength(LData, ASource.Size);
  ASource.Position := 0;
  ASource.ReadBuffer(LData[0], Length(LData));
  
  LData := DecryptBytes(LData);
  
  ADest.WriteBuffer(LData[0], Length(LData));
end;

function TBackupEncryptor.EncryptBytes(const AData: TBytes): TBytes;
var
  I: Integer;
begin
  // �򻯵�XOR���ܣ�ʵ��ʹ�����滻ΪAES��
  SetLength(Result, Length(AData));
  for I := 0 to Length(AData) - 1 do
    Result[I] := AData[I] xor FKey[I mod Length(FKey)];
end;

function TBackupEncryptor.DecryptBytes(const AData: TBytes): TBytes;
begin
  // XOR�ǶԳƵ�
  Result := EncryptBytes(AData);
end;

{ TCloudBackupClient }

constructor TCloudBackupClient.Create(const AServiceURL, AApiKey, ABucket: string);
begin
  inherited Create;
  FServiceURL := AServiceURL;
  FApiKey := AApiKey;
  FBucket := ABucket;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := 60000;
  FHttpClient.ResponseTimeout := 300000;  // 5����
  FLock := TCriticalSection.Create;
end;

destructor TCloudBackupClient.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

function TCloudBackupClient.DoRequest(const AMethod, AEndpoint: string;
  ABody: TStream; AHeaders: TNetHeaders): IHTTPResponse;
var
  LURL: string;
  LDefaultHeaders: TNetHeaders;
begin
  LURL := FServiceURL + AEndpoint;
  
  SetLength(LDefaultHeaders, 2);
  LDefaultHeaders[0] := TNameValuePair.Create('X-API-Key', FApiKey);
  LDefaultHeaders[1] := TNameValuePair.Create('X-Bucket', FBucket);
  
  if Length(AHeaders) > 0 then
  begin
    SetLength(LDefaultHeaders, Length(LDefaultHeaders) + Length(AHeaders));
    Move(AHeaders[0], LDefaultHeaders[2], Length(AHeaders) * SizeOf(TNameValuePair));
  end;
  
  FLock.Enter;
  try
    if AMethod = 'GET' then
      Result := FHttpClient.Get(LURL, nil, LDefaultHeaders)
    else if AMethod = 'POST' then
      Result := FHttpClient.Post(LURL, ABody, nil, LDefaultHeaders)
    else if AMethod = 'PUT' then
      Result := FHttpClient.Put(LURL, ABody, nil, LDefaultHeaders)
    else if AMethod = 'DELETE' then
      Result := FHttpClient.Delete(LURL, nil, LDefaultHeaders);
  finally
    FLock.Leave;
  end;
end;

function TCloudBackupClient.UploadBackup(const ALocalPath, ARemoteKey: string;
  AProgressCallback: TProc<Int64, Int64>): Boolean;
var
  LStream: TFileStream;
  LResponse: IHTTPResponse;
  LTotalSize: Int64;
begin
  Result := False;
  
  if not TFile.Exists(ALocalPath) then
    Exit;
    
  LStream := TFileStream.Create(ALocalPath, fmOpenRead or fmShareDenyWrite);
  try
    LTotalSize := LStream.Size;
    
    // ��ʵ�֣�ʵ��Ӧ�ֿ��ϴ���֧�ֽ��Ȼص�
    LResponse := DoRequest('PUT', '/backup/' + TNetEncoding.URL.Encode(ARemoteKey), LStream);
    
    if Assigned(AProgressCallback) then
      AProgressCallback(LTotalSize, LTotalSize);
      
    Result := LResponse.StatusCode = 200;
  finally
    LStream.Free;
  end;
end;

function TCloudBackupClient.DownloadBackup(const ARemoteKey, ALocalPath: string;
  AProgressCallback: TProc<Int64, Int64>): Boolean;
var
  LResponse: IHTTPResponse;
  LStream: TFileStream;
begin
  Result := False;
  
  TDirectory.CreateDirectory(TPath.GetDirectoryName(ALocalPath));
  
  LResponse := DoRequest('GET', '/backup/' + TNetEncoding.URL.Encode(ARemoteKey), nil);
  
  if LResponse.StatusCode = 200 then
  begin
    LStream := TFileStream.Create(ALocalPath, fmCreate);
    try
      LStream.CopyFrom(LResponse.ContentStream, 0);
      
      if Assigned(AProgressCallback) then
        AProgressCallback(LStream.Size, LStream.Size);
        
      Result := True;
    finally
      LStream.Free;
    end;
  end;
end;

function TCloudBackupClient.DeleteBackup(const ARemoteKey: string): Boolean;
var
  LResponse: IHTTPResponse;
begin
  LResponse := DoRequest('DELETE', '/backup/' + TNetEncoding.URL.Encode(ARemoteKey), nil);
  Result := LResponse.StatusCode = 200;
end;

function TCloudBackupClient.ListBackups(const APrefix: string): TObjectList<TBackupVersion>;
var
  LResponse: IHTTPResponse;
  LJSON: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TBackupVersion>.Create(True);
  
  LResponse := DoRequest('GET', '/backups?prefix=' + TNetEncoding.URL.Encode(APrefix), nil);
  
  if LResponse.StatusCode = 200 then
  begin
    LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    try
      if Assigned(LJSON) then
      begin
        LItems := LJSON.GetValue<TJSONArray>('items');
        if Assigned(LItems) then
          for I := 0 to LItems.Count - 1 do
            Result.Add(TBackupVersion.FromJSON(LItems.Items[I] as TJSONObject));
      end;
    finally
      LJSON.Free;
    end;
  end;
end;

function TCloudBackupClient.GetBackupInfo(const ABackupId: string): TBackupVersion;
var
  LResponse: IHTTPResponse;
  LJSON: TJSONObject;
begin
  Result := nil;
  
  LResponse := DoRequest('GET', '/backup/' + TNetEncoding.URL.Encode(ABackupId) + '/info', nil);
  
  if LResponse.StatusCode = 200 then
  begin
    LJSON := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    try
      if Assigned(LJSON) then
        Result := TBackupVersion.FromJSON(LJSON);
    finally
      LJSON.Free;
    end;
  end;
end;

function TCloudBackupClient.BackupExists(const ARemoteKey: string): Boolean;
var
  LResponse: IHTTPResponse;
begin
  LResponse := DoRequest('GET', '/backup/' + TNetEncoding.URL.Encode(ARemoteKey) + '/exists', nil);
  Result := LResponse.StatusCode = 200;
end;

{ TBackupScheduler }

constructor TBackupScheduler.Create(const AConfig: TBackupConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FEnabled := False;
  FLastTriggerTime := 0;
  FLock := TCriticalSection.Create;
  FStopEvent := TEvent.Create(nil, True, False, '');
end;

destructor TBackupScheduler.Destroy;
begin
  Stop;
  FreeAndNil(FStopEvent);
  FreeAndNil(FLock);
  inherited;
end;

function TBackupScheduler.ShouldTrigger: Boolean;
var
  LNow: TDateTime;
  LNextTime: TDateTime;
begin
  Result := False;
  
  if FConfig.ScheduleType = stNone then
    Exit;
    
  LNow := Now;
  LNextTime := GetNextScheduledTime;
  
  // ����Ƿ񵽴����ʱ��
  if (LNextTime <= LNow) and
     ((FLastTriggerTime = 0) or (MinutesBetween(LNow, FLastTriggerTime) > 1)) then
  begin
    Result := True;
    FLastTriggerTime := LNow;
  end;
end;

procedure TBackupScheduler.SchedulerLoop;
begin
  while not TThread.CurrentThread.CheckTerminated and FEnabled do
  begin
    if Assigned(FStopEvent) and (FStopEvent.WaitFor(60000) <> wrTimeout) then
      Break;

    if TThread.CurrentThread.CheckTerminated or not FEnabled then
      Break;

    if ShouldTrigger then
    begin
      if Assigned(FOnBackupTriggered) then
        FOnBackupTriggered(Self);
    end;
  end;
end;

procedure TBackupScheduler.Start;
begin
  if FEnabled then
    Exit;

  FEnabled := True;
  if Assigned(FStopEvent) then
    FStopEvent.ResetEvent;
  FSchedulerThread := TThread.CreateAnonymousThread(SchedulerLoop);
  FSchedulerThread.FreeOnTerminate := False;
  FSchedulerThread.Start;
end;

procedure TBackupScheduler.Stop;
var
  LThread: TThread;
begin
  FEnabled := False;
  if Assigned(FStopEvent) then
    FStopEvent.SetEvent;

  LThread := FSchedulerThread;
  FSchedulerThread := nil;
  if Assigned(LThread) then
  begin
    LThread.Terminate;
    LThread.WaitFor;
    LThread.Free;
  end;
end;

function TBackupScheduler.GetNextScheduledTime: TDateTime;
var
  LNow: TDateTime;
  LDate: TDate;
  LNextDate: TDate;
begin
  LNow := Now;
  LDate := DateOf(LNow);
  
  case FConfig.ScheduleType of
    stHourly:
      begin
        Result := IncHour(Trunc(LNow), HourOf(LNow) + 1);
        Result := Result + TimeOf(FConfig.ScheduleTime);
      end;
      
    stDaily:
      begin
        Result := LDate + TimeOf(FConfig.ScheduleTime);
        if Result <= LNow then
          Result := IncDay(Result, 1);
      end;
      
    stWeekly:
      begin
        LNextDate := LDate;
        while DayOfTheWeek(LNextDate) <> FConfig.ScheduleDayOfWeek do
          LNextDate := IncDay(LNextDate, 1);
        Result := LNextDate + TimeOf(FConfig.ScheduleTime);
        if Result <= LNow then
          Result := IncDay(Result, 7);
      end;
      
    stMonthly:
      begin
        LNextDate := EncodeDate(YearOf(LDate), MonthOf(LDate), FConfig.ScheduleDayOfMonth);
        Result := LNextDate + TimeOf(FConfig.ScheduleTime);
        if Result <= LNow then
          Result := IncMonth(Result, 1);
      end;
  else
    Result := 0;
  end;
end;

{ TCloudBackupManager }

constructor TCloudBackupManager.Create(const AConfig: TBackupConfig);
begin
  inherited Create;
  FConfig := AConfig;
  
  if (FConfig.CloudServiceURL <> '') and (FConfig.CloudApiKey <> '') then
    FCloudClient := TCloudBackupClient.Create(
      FConfig.CloudServiceURL, FConfig.CloudApiKey, FConfig.CloudBucket)
  else
    FCloudClient := nil;
    
  FChangeDetector := nil;  // ���贴��
  FCompressor := TBackupCompressor.Create(FConfig.CompressionLevel);
  
  if FConfig.EnableEncryption and (FConfig.EncryptionKey <> '') then
    FEncryptor := TBackupEncryptor.Create(FConfig.EncryptionKey)
  else
    FEncryptor := nil;
    
  FScheduler := TBackupScheduler.Create(FConfig);
  FScheduler.OnBackupTriggered := SchedulerBackupTriggered;
  
  FVersions := TObjectList<TBackupVersion>.Create(True);
  FStatus := bsIdle;
  FLock := TCriticalSection.Create;
  FCancelled := False;
  FStatistics.Reset;
  
  // ȷ������Ŀ¼����
  if FConfig.LocalBackupPath <> '' then
    TDirectory.CreateDirectory(FConfig.LocalBackupPath);
    
  LoadVersions;
end;

destructor TCloudBackupManager.Destroy;
begin
  Cancel;
  FreeAndNil(FScheduler);
  FreeAndNil(FVersions);
  FreeAndNil(FEncryptor);
  FreeAndNil(FCompressor);
  FreeAndNil(FChangeDetector);
  FreeAndNil(FCloudClient);
  FreeAndNil(FLock);
  inherited;
end;

procedure TCloudBackupManager.DoProgress;
begin
  if Assigned(FOnProgress) then
    FOnProgress(Self, FProgress);
end;

procedure TCloudBackupManager.DoBackupComplete(Success: Boolean;
  const ABackupId, AErrorMsg: string);
begin
  if Assigned(FOnBackupComplete) then
    FOnBackupComplete(Self, Success, ABackupId, AErrorMsg);
end;

procedure TCloudBackupManager.DoRestoreComplete(Success: Boolean;
  const AErrorMsg: string);
begin
  if Assigned(FOnRestoreComplete) then
    FOnRestoreComplete(Self, Success, AErrorMsg);
end;

function TCloudBackupManager.GenerateBackupId: string;
begin
  Result := FormatDateTime('yyyymmdd_hhnnss', Now) + '_' +
            Copy(THashMD5.GetHashString(FormatDateTime('yyyymmddhhnnsszzz', Now)), 1, 8);
end;

function TCloudBackupManager.GetBackupArchivePath(const ABackupId: string): string;
begin
  Result := TPath.Combine(FConfig.LocalBackupPath, ABackupId + '.zip');
  if FConfig.EnableEncryption then
    Result := Result + '.enc';
end;

function TCloudBackupManager.GetManifestPath(const ABackupId: string): string;
begin
  Result := TPath.Combine(FConfig.LocalBackupPath, ABackupId + '.manifest.json');
end;

procedure TCloudBackupManager.InternalBackup(ABackupType: TBackupType;
  const ADescription: string);
var
  LBackupId: string;
  LManifest: TBackupManifest;
  LFiles: TList<TBackupFileInfo>;
  LArchivePath, LTempPath: string;
  LStartTime: TDateTime;
  LVersion: TBackupVersion;
  I: Integer;
begin
  LStartTime := Now;
  LBackupId := GenerateBackupId;
  FCancelled := False;
  
  FStatus := bsPreparing;
  FProgress.Status := bsPreparing;
  FProgress.ErrorMessage := '';
  DoProgress;
  
  try
    // �����嵥
    LManifest := TBackupManifest.Create;
    try
      LManifest.BackupId := LBackupId;
      LManifest.BackupType := ABackupType;
      LManifest.CreatedAt := Now;
      LManifest.Description := ADescription;
      
      // ��ȡҪ���ݵ��ļ�
      if Length(FConfig.SourcePaths) > 0 then
        LManifest.BasePath := FConfig.SourcePaths[0];
        
      // ��ʼ����������
      if not Assigned(FChangeDetector) and (LManifest.BasePath <> '') then
        FChangeDetector := TFileChangeDetector.Create(LManifest.BasePath);
        
      // ���ݱ������ͻ�ȡ�ļ��б�
      case ABackupType of
        btFull:
          begin
            if Assigned(FChangeDetector) then
            begin
              FChangeDetector.TakeSnapshot(FConfig.IncludePatterns, FConfig.ExcludePatterns);
              FChangeDetector.SaveSnapshot(LManifest);
            end;
          end;
          
        btIncremental, btDifferential:
          begin
            if Assigned(FChangeDetector) then
            begin
              // ������һ�εĿ���
              if FVersions.Count > 0 then
              begin
                var LLastManifest := TBackupManifest.LoadFromFile(
                  GetManifestPath(FVersions[FVersions.Count - 1].BackupId));
                try
                  FChangeDetector.LoadSnapshot(LLastManifest);
                  LManifest.ParentBackupId := LLastManifest.BackupId;
                finally
                  LLastManifest.Free;
                end;
              end;
              
              // �����
              LFiles := FChangeDetector.DetectChanges(
                FConfig.IncludePatterns, FConfig.ExcludePatterns);
              try
                for I := 0 to LFiles.Count - 1 do
                  LManifest.AddFile(LFiles[I]);
              finally
                LFiles.Free;
              end;
            end;
          end;
      end;
      
      if FCancelled then
        raise EBackupCancelledException.Create('Backup cancelled');
        
      FProgress.TotalFiles := LManifest.FileCount;
      FProgress.TotalBytes := LManifest.TotalSize;
      
      // ѹ��
      FStatus := bsCompressing;
      FProgress.Status := bsCompressing;
      DoProgress;
      
      LTempPath := TPath.Combine(FConfig.LocalBackupPath, LBackupId + '.tmp.zip');
      FCompressor.CreateArchive(LTempPath, LManifest.Files, LManifest.BasePath,
        procedure(ACurrent, ATotal: Integer)
        begin
          FProgress.ProcessedFiles := ACurrent;
          DoProgress;
        end);
        
      if FCancelled then
      begin
        TFile.Delete(LTempPath);
        raise EBackupCancelledException.Create('Backup cancelled');
      end;
      
      LArchivePath := GetBackupArchivePath(LBackupId);
      
      // ���ܣ�������ã�
      if Assigned(FEncryptor) then
      begin
        FStatus := bsEncrypting;
        FProgress.Status := bsEncrypting;
        DoProgress;
        
        FEncryptor.EncryptFile(LTempPath, LArchivePath);
        TFile.Delete(LTempPath);
      end
      else
      begin
        LArchivePath := TPath.Combine(FConfig.LocalBackupPath, LBackupId + '.zip');
        TFile.Move(LTempPath, LArchivePath);
      end;
      
      // �����嵥�е�ѹ����С
      LManifest.CompressedSize := TFile.GetSize(LArchivePath);
      
      // �����嵥
      LManifest.SaveToFile(GetManifestPath(LBackupId));
      
      // �����汾��¼
      LVersion := TBackupVersion.Create;
      LVersion.BackupId := LBackupId;
      LVersion.BackupType := ABackupType;
      LVersion.CreatedAt := LManifest.CreatedAt;
      LVersion.FileCount := LManifest.FileCount;
      LVersion.TotalSize := LManifest.TotalSize;
      LVersion.CompressedSize := LManifest.CompressedSize;
      LVersion.Description := ADescription;
      LVersion.IsLocal := True;
      LVersion.IsCloud := False;
      LVersion.ParentBackupId := LManifest.ParentBackupId;
      
      FVersions.Add(LVersion);
      SaveVersions;
      
      // �����ɰ汾
      CleanupOldVersions;
      
      // ����ͳ��
      Inc(FStatistics.TotalBackups);
      Inc(FStatistics.SuccessfulBackups);
      FStatistics.TotalBytesBackedUp := FStatistics.TotalBytesBackedUp + LManifest.TotalSize;
      FStatistics.LastBackupTime := Now;
      
      var LDuration := SecondsBetween(Now, LStartTime);
      if FStatistics.TotalBackups > 1 then
        FStatistics.AverageBackupDurationSec :=
          (FStatistics.AverageBackupDurationSec * (FStatistics.TotalBackups - 1) + LDuration) /
          FStatistics.TotalBackups
      else
        FStatistics.AverageBackupDurationSec := LDuration;
      
      FStatus := bsCompleted;
      FProgress.Status := bsCompleted;
      DoBackupComplete(True, LBackupId, '');
      
    finally
      LManifest.Free;
    end;
    
  except
    on E: Exception do
    begin
      FStatus := bsError;
      FProgress.Status := bsError;
      FProgress.ErrorMessage := E.Message;
      Inc(FStatistics.TotalBackups);
      Inc(FStatistics.FailedBackups);
      DoBackupComplete(False, '', E.Message);
    end;
  end;
  
  FStatus := bsIdle;
end;

procedure TCloudBackupManager.InternalRestore(const ABackupId: string;
  const ATargetPath: string);
var
  LArchivePath, LTempPath, LDestPath: string;
  LManifest: TBackupManifest;
  LStartTime: TDateTime;
begin
  LStartTime := Now;
  FCancelled := False;
  
  FStatus := bsPreparing;
  FProgress.Status := bsPreparing;
  FProgress.ErrorMessage := '';
  DoProgress;
  
  try
    LArchivePath := GetBackupArchivePath(ABackupId);
    
    if not TFile.Exists(LArchivePath) then
      raise EBackupFileNotFoundException.CreateFmt('Backup file not found: %s', [LArchivePath]);
      
    // �����嵥
    LManifest := TBackupManifest.LoadFromFile(GetManifestPath(ABackupId));
    try
      FProgress.TotalFiles := LManifest.FileCount;
      FProgress.TotalBytes := LManifest.TotalSize;
      
      // ȷ��Ŀ��·��
      if ATargetPath <> '' then
        LDestPath := ATargetPath
      else
        LDestPath := LManifest.BasePath;
        
      TDirectory.CreateDirectory(LDestPath);
      
      // ���ܣ������Ҫ��
      if Assigned(FEncryptor) and LArchivePath.EndsWith('.enc') then
      begin
        FStatus := bsDecrypting;
        FProgress.Status := bsDecrypting;
        DoProgress;
        
        LTempPath := TPath.Combine(FConfig.LocalBackupPath, ABackupId + '.tmp.zip');
        FEncryptor.DecryptFile(LArchivePath, LTempPath);
      end
      else
        LTempPath := LArchivePath;
        
      if FCancelled then
      begin
        if LTempPath <> LArchivePath then
          TFile.Delete(LTempPath);
        raise EBackupCancelledException.Create('Restore cancelled');
      end;
      
      // ��ѹ
      FStatus := bsDecompressing;
      FProgress.Status := bsDecompressing;
      DoProgress;
      
      FStatus := bsRestoring;
      FProgress.Status := bsRestoring;
      DoProgress;
      
      FCompressor.ExtractArchive(LTempPath, LDestPath,
        procedure(ACurrent, ATotal: Integer)
        begin
          FProgress.ProcessedFiles := ACurrent;
          DoProgress;
        end);
        
      // ������ʱ�ļ�
      if LTempPath <> LArchivePath then
        TFile.Delete(LTempPath);
        
      // ����ͳ��
      FStatistics.TotalBytesRestored := FStatistics.TotalBytesRestored + LManifest.TotalSize;
      FStatistics.LastRestoreTime := Now;
      
      FStatus := bsCompleted;
      FProgress.Status := bsCompleted;
      DoRestoreComplete(True, '');
      
    finally
      LManifest.Free;
    end;
    
  except
    on E: Exception do
    begin
      FStatus := bsError;
      FProgress.Status := bsError;
      FProgress.ErrorMessage := E.Message;
      DoRestoreComplete(False, E.Message);
    end;
  end;
  
  FStatus := bsIdle;
end;

procedure TCloudBackupManager.LoadVersions;
var
  LVersionsPath: string;
  LContent: string;
  LJSON: TJSONArray;
  I: Integer;
begin
  LVersionsPath := TPath.Combine(FConfig.LocalBackupPath, 'versions.json');
  
  if not TFile.Exists(LVersionsPath) then
    Exit;
    
  LContent := TFile.ReadAllText(LVersionsPath, TEncoding.UTF8);
  LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONArray;
  try
    if Assigned(LJSON) then
      for I := 0 to LJSON.Count - 1 do
        FVersions.Add(TBackupVersion.FromJSON(LJSON.Items[I] as TJSONObject));
  finally
    LJSON.Free;
  end;
end;

procedure TCloudBackupManager.SaveVersions;
var
  LVersionsPath: string;
  LJSON: TJSONArray;
  I: Integer;
begin
  LVersionsPath := TPath.Combine(FConfig.LocalBackupPath, 'versions.json');
  
  LJSON := TJSONArray.Create;
  try
    for I := 0 to FVersions.Count - 1 do
      LJSON.Add(FVersions[I].ToJSON);
      
    TFile.WriteAllText(LVersionsPath, LJSON.ToJSON, TEncoding.UTF8);
  finally
    LJSON.Free;
  end;
end;

procedure TCloudBackupManager.CleanupOldVersions;
var
  I: Integer;
  LVersion: TBackupVersion;
begin
  // ����ָ�������İ汾
  while FVersions.Count > FConfig.MaxVersionsToKeep do
  begin
    LVersion := FVersions[0];
    
    // ɾ�������ļ�
    if TFile.Exists(GetBackupArchivePath(LVersion.BackupId)) then
      TFile.Delete(GetBackupArchivePath(LVersion.BackupId));
    if TFile.Exists(GetManifestPath(LVersion.BackupId)) then
      TFile.Delete(GetManifestPath(LVersion.BackupId));
      
    FVersions.Delete(0);
  end;
  
  SaveVersions;
end;

procedure TCloudBackupManager.SchedulerBackupTriggered(Sender: TObject);
begin
  // �����������ı���ʹ����������
  if FVersions.Count = 0 then
    BackupFullAsync('Scheduled full backup')
  else
    BackupIncrementalAsync('Scheduled incremental backup');
end;

procedure TCloudBackupManager.BackupFull(const ADescription: string);
begin
  if FStatus <> bsIdle then
    raise EBackupInProgressException.Create('Backup operation in progress');
    
  FLock.Enter;
  try
    InternalBackup(btFull, ADescription);
  finally
    FLock.Leave;
  end;
end;

procedure TCloudBackupManager.BackupIncremental(const ADescription: string);
begin
  if FStatus <> bsIdle then
    raise EBackupInProgressException.Create('Backup operation in progress');
    
  // ���û��֮ǰ�ı��ݣ�ִ��ȫ������
  if FVersions.Count = 0 then
  begin
    BackupFull(ADescription);
    Exit;
  end;
  
  FLock.Enter;
  try
    InternalBackup(btIncremental, ADescription);
  finally
    FLock.Leave;
  end;
end;

procedure TCloudBackupManager.BackupDifferential(const ADescription: string);
begin
  if FStatus <> bsIdle then
    raise EBackupInProgressException.Create('Backup operation in progress');
    
  if FVersions.Count = 0 then
  begin
    BackupFull(ADescription);
    Exit;
  end;
  
  FLock.Enter;
  try
    InternalBackup(btDifferential, ADescription);
  finally
    FLock.Leave;
  end;
end;

procedure TCloudBackupManager.BackupFullAsync(const ADescription: string);
begin
  if FStatus <> bsIdle then
    raise EBackupInProgressException.Create('Backup operation in progress');
    
  FBackupThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FLock.Enter;
      try
        InternalBackup(btFull, ADescription);
      finally
        FLock.Leave;
      end;
    end);
  FBackupThread.FreeOnTerminate := False;
  FBackupThread.Start;
end;

procedure TCloudBackupManager.BackupIncrementalAsync(const ADescription: string);
begin
  if FStatus <> bsIdle then
    raise EBackupInProgressException.Create('Backup operation in progress');
    
  if FVersions.Count = 0 then
  begin
    BackupFullAsync(ADescription);
    Exit;
  end;
  
  FBackupThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FLock.Enter;
      try
        InternalBackup(btIncremental, ADescription);
      finally
        FLock.Leave;
      end;
    end);
  FBackupThread.FreeOnTerminate := False;
  FBackupThread.Start;
end;

procedure TCloudBackupManager.Restore(const ABackupId: string;
  const ATargetPath: string);
begin
  if FStatus <> bsIdle then
    raise EOperationInProgressException.Create('Operation in progress');
    
  FLock.Enter;
  try
    InternalRestore(ABackupId, ATargetPath);
  finally
    FLock.Leave;
  end;
end;

procedure TCloudBackupManager.RestoreAsync(const ABackupId: string;
  const ATargetPath: string);
begin
  if FStatus <> bsIdle then
    raise EOperationInProgressException.Create('Operation in progress');
    
  FRestoreThread := TThread.CreateAnonymousThread(
    procedure
    begin
      FLock.Enter;
      try
        InternalRestore(ABackupId, ATargetPath);
      finally
        FLock.Leave;
      end;
    end);
  FRestoreThread.FreeOnTerminate := False;
  FRestoreThread.Start;
end;

procedure TCloudBackupManager.RestoreLatest(const ATargetPath: string);
begin
  if FVersions.Count = 0 then
    raise EBackupFileNotFoundException.Create('No available backups');
    
  Restore(FVersions[FVersions.Count - 1].BackupId, ATargetPath);
end;

procedure TCloudBackupManager.Cancel;
var
  LBackupThread: TThread;
  LRestoreThread: TThread;
begin
  FCancelled := True;

  LBackupThread := FBackupThread;
  FBackupThread := nil;
  if Assigned(LBackupThread) then
  begin
    LBackupThread.Terminate;
    LBackupThread.WaitFor;
    LBackupThread.Free;
  end;

  LRestoreThread := FRestoreThread;
  FRestoreThread := nil;
  if Assigned(LRestoreThread) then
  begin
    LRestoreThread.Terminate;
    LRestoreThread.WaitFor;
    LRestoreThread.Free;
  end;
end;

function TCloudBackupManager.GetVersions: TObjectList<TBackupVersion>;
begin
  Result := FVersions;
end;

function TCloudBackupManager.GetVersion(const ABackupId: string): TBackupVersion;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FVersions.Count - 1 do
    if FVersions[I].BackupId = ABackupId then
      Exit(FVersions[I]);
end;

procedure TCloudBackupManager.DeleteVersion(const ABackupId: string);
var
  I: Integer;
begin
  for I := FVersions.Count - 1 downto 0 do
  begin
    if FVersions[I].BackupId = ABackupId then
    begin
      // ɾ���ļ�
      if TFile.Exists(GetBackupArchivePath(ABackupId)) then
        TFile.Delete(GetBackupArchivePath(ABackupId));
      if TFile.Exists(GetManifestPath(ABackupId)) then
        TFile.Delete(GetManifestPath(ABackupId));
        
      FVersions.Delete(I);
      SaveVersions;
      Break;
    end;
  end;
end;

procedure TCloudBackupManager.DeleteAllVersions;
var
  I: Integer;
begin
  for I := FVersions.Count - 1 downto 0 do
  begin
    if TFile.Exists(GetBackupArchivePath(FVersions[I].BackupId)) then
      TFile.Delete(GetBackupArchivePath(FVersions[I].BackupId));
    if TFile.Exists(GetManifestPath(FVersions[I].BackupId)) then
      TFile.Delete(GetManifestPath(FVersions[I].BackupId));
  end;
  
  FVersions.Clear;
  SaveVersions;
end;

procedure TCloudBackupManager.SyncToCloud(const ABackupId: string);
var
  LVersion: TBackupVersion;
  LArchivePath: string;
begin
  if not Assigned(FCloudClient) then
    raise ECloudServiceNotConfiguredException.Create('Cloud service not configured');
    
  LVersion := GetVersion(ABackupId);
  if not Assigned(LVersion) then
    raise EBackupFileNotFoundException.CreateFmt('Backup version not found: %s', [ABackupId]);
    
  LArchivePath := GetBackupArchivePath(ABackupId);
  if not TFile.Exists(LArchivePath) then
    raise EBackupFileNotFoundException.Create('Local backup file not found');
    
  FStatus := bsUploading;
  FProgress.Status := bsUploading;
  DoProgress;
  
  try
    if FCloudClient.UploadBackup(LArchivePath, ABackupId,
      procedure(AProcessed, ATotal: Int64)
      begin
        FProgress.ProcessedBytes := AProcessed;
        FProgress.TotalBytes := ATotal;
        DoProgress;
      end) then
    begin
      LVersion.IsCloud := True;
      SaveVersions;
    end
    else
      raise EBackupTransferException.Create('Upload failed');
  finally
    FStatus := bsIdle;
  end;
end;

procedure TCloudBackupManager.SyncFromCloud(const ABackupId: string);
var
  LArchivePath: string;
  LVersion: TBackupVersion;
begin
  if not Assigned(FCloudClient) then
    raise ECloudServiceNotConfiguredException.Create('Cloud service not configured');
    
  LArchivePath := GetBackupArchivePath(ABackupId);
  
  FStatus := bsDownloading;
  FProgress.Status := bsDownloading;
  DoProgress;
  
  try
    if FCloudClient.DownloadBackup(ABackupId, LArchivePath,
      procedure(AProcessed, ATotal: Int64)
      begin
        FProgress.ProcessedBytes := AProcessed;
        FProgress.TotalBytes := ATotal;
        DoProgress;
      end) then
    begin
      // ���»򴴽��汾��¼
      LVersion := GetVersion(ABackupId);
      if not Assigned(LVersion) then
      begin
        LVersion := FCloudClient.GetBackupInfo(ABackupId);
        if Assigned(LVersion) then
          FVersions.Add(LVersion);
      end;
      
      if Assigned(LVersion) then
      begin
        LVersion.IsLocal := True;
        SaveVersions;
      end;
    end
    else
      raise EBackupTransferException.Create('Download failed');
  finally
    FStatus := bsIdle;
  end;
end;

procedure TCloudBackupManager.SyncAllToCloud;
var
  I: Integer;
begin
  for I := 0 to FVersions.Count - 1 do
  begin
    if FVersions[I].IsLocal and not FVersions[I].IsCloud then
      SyncToCloud(FVersions[I].BackupId);
  end;
end;

function TCloudBackupManager.GetCloudVersions: TObjectList<TBackupVersion>;
begin
  if not Assigned(FCloudClient) then
    raise ECloudServiceNotConfiguredException.Create('Cloud service not configured');
    
  Result := FCloudClient.ListBackups;
end;

function TCloudBackupManager.VerifyBackup(const ABackupId: string): Boolean;
var
  LArchivePath: string;
  LManifest: TBackupManifest;
  LZip: TZipFile;
begin
  Result := False;
  
  LArchivePath := GetBackupArchivePath(ABackupId);
  if not TFile.Exists(LArchivePath) then
    Exit;
    
  // ��֤�嵥
  if not TFile.Exists(GetManifestPath(ABackupId)) then
    Exit;
    
  try
    LManifest := TBackupManifest.LoadFromFile(GetManifestPath(ABackupId));
    try
      // ��֤ZIP������
      LZip := TZipFile.Create;
      try
        LZip.Open(LArchivePath, zmRead);
        try
          Result := LZip.FileCount = LManifest.FileCount;
        finally
          LZip.Close;
        end;
      finally
        LZip.Free;
      end;
    finally
      LManifest.Free;
    end;
  except
    Result := False;
  end;
end;

function TCloudBackupManager.GetBackupManifest(const ABackupId: string): TBackupManifest;
begin
  Result := TBackupManifest.LoadFromFile(GetManifestPath(ABackupId));
end;

procedure TCloudBackupManager.EnableScheduler;
begin
  FScheduler.Start;
end;

procedure TCloudBackupManager.DisableScheduler;
begin
  FScheduler.Stop;
end;

function TCloudBackupManager.GetNextScheduledBackup: TDateTime;
begin
  Result := FScheduler.GetNextScheduledTime;
end;

end.
