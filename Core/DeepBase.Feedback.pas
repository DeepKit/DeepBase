unit DeepBase.Feedback;

{*******************************************************************************
  DeepBase Framework - User Feedback System
  
  �û������ռ�ϵͳ��֧�֣�
  - �����ύ��Bug/���ܽ���/���⣩
  - ��������־�Զ��ռ�
  - ϵͳ��Ϣ�ɼ�
  - ����׷�ٺ�״̬����
  - �û�֪ͨ����
  - ���߷�������
  
  Author: DeepBase Team
  Created: 2025-11-30
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.Types, System.Generics.Collections,
  System.JSON, System.SyncObjs, System.DateUtils, System.Hash, System.NetEncoding,
  System.Net.HttpClient, System.Net.URLClient, System.Threading, System.IOUtils,
  System.Zip;

type
  /// <summary>��������</summary>
  TFeedbackType = (
    ftBug,            // Bug����
    ftFeature,        // ���ܽ���
    ftQuestion,       // ������ѯ
    ftImprovement,    // �Ľ�����
    ftCrash,          // ��������
    ftPerformance,    // ��������
    ftOther           // ����
  );

  /// <summary>�������ȼ�</summary>
  TFeedbackPriority = (
    fpLow,            // ��
    fpNormal,         // ��ͨ
    fpHigh,           // ��
    fpCritical        // ����
  );

  /// <summary>����״̬</summary>
  TFeedbackStatus = (
    fsNew,            // �½�
    fsPending,        // ������
    fsInProgress,     // ������
    fsResolved,       // �ѽ��
    fsClosed,         // �ѹر�
    fsRejected        // �Ѿܾ�
  );

  /// <summary>֪ͨ����</summary>
  TNotificationType = (
    ntStatusChange,   // ״̬���
    ntComment,        // ������
    ntAssignment,     // ��ָ��
    ntResolution,     // �ѽ��
    ntAnnouncement,   // ����
    ntReminder        // ����
  );

  /// <summary>������Ϣ</summary>
  TAttachmentInfo = record
    Id: string;
    FileName: string;
    FileSize: Int64;
    MimeType: string;
    LocalPath: string;
    RemoteURL: string;
    UploadedAt: TDateTime;
    class function Create(const AFileName, ALocalPath: string): TAttachmentInfo; static;
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TAttachmentInfo; static;
  end;

  /// <summary>ϵͳ��Ϣ</summary>
  TSystemInfo = record
    OSName: string;
    OSVersion: string;
    OSArchitecture: string;
    CPUName: string;
    CPUCores: Integer;
    RAMTotalMB: Integer;
    RAMFreeMB: Integer;
    DiskTotalMB: Integer;
    DiskFreeMB: Integer;
    ScreenWidth: Integer;
    ScreenHeight: Integer;
    AppVersion: string;
    AppBuildDate: string;
    DelphiVersion: string;
    UserLocale: string;
    TimeZone: string;
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TSystemInfo; static;
  end;

  /// <summary>������Ŀ</summary>
  TFeedbackItem = class
  private
    FId: string;
    FFeedbackType: TFeedbackType;
    FPriority: TFeedbackPriority;
    FStatus: TFeedbackStatus;
    FTitle: string;
    FDescription: string;
    FStepsToReproduce: string;
    FExpectedBehavior: string;
    FActualBehavior: string;
    FAttachments: TList<TAttachmentInfo>;
    FSystemInfo: TSystemInfo;
    FUserId: string;
    FUserEmail: string;
    FUserName: string;
    FTags: TStringList;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FSubmittedAt: TDateTime;
    FIsSubmitted: Boolean;
    FTrackingCode: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddAttachment(const AInfo: TAttachmentInfo);
    procedure RemoveAttachment(const AId: string);
    procedure ClearAttachments;
    
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TFeedbackItem;
    
    function Validate: TArray<string>;  // ������֤����
    
    property Id: string read FId write FId;
    property FeedbackType: TFeedbackType read FFeedbackType write FFeedbackType;
    property Priority: TFeedbackPriority read FPriority write FPriority;
    property Status: TFeedbackStatus read FStatus write FStatus;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property StepsToReproduce: string read FStepsToReproduce write FStepsToReproduce;
    property ExpectedBehavior: string read FExpectedBehavior write FExpectedBehavior;
    property ActualBehavior: string read FActualBehavior write FActualBehavior;
    property Attachments: TList<TAttachmentInfo> read FAttachments;
    property SystemInfo: TSystemInfo read FSystemInfo write FSystemInfo;
    property UserId: string read FUserId write FUserId;
    property UserEmail: string read FUserEmail write FUserEmail;
    property UserName: string read FUserName write FUserName;
    property Tags: TStringList read FTags;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property SubmittedAt: TDateTime read FSubmittedAt write FSubmittedAt;
    property IsSubmitted: Boolean read FIsSubmitted write FIsSubmitted;
    property TrackingCode: string read FTrackingCode write FTrackingCode;
  end;

  /// <summary>��������</summary>
  TFeedbackComment = class
  private
    FId: string;
    FFeedbackId: string;
    FAuthorId: string;
    FAuthorName: string;
    FContent: string;
    FIsStaff: Boolean;
    FCreatedAt: TDateTime;
  public
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TFeedbackComment;
    
    property Id: string read FId write FId;
    property FeedbackId: string read FFeedbackId write FFeedbackId;
    property AuthorId: string read FAuthorId write FAuthorId;
    property AuthorName: string read FAuthorName write FAuthorName;
    property Content: string read FContent write FContent;
    property IsStaff: Boolean read FIsStaff write FIsStaff;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
  end;

  /// <summary>�û�֪ͨ</summary>
  TUserNotification = class
  private
    FId: string;
    FNotificationType: TNotificationType;
    FTitle: string;
    FMessage: string;
    FFeedbackId: string;
    FIsRead: Boolean;
    FCreatedAt: TDateTime;
    FReadAt: TDateTime;
  public
    function ToJSON: TJSONObject;
    class function FromJSON(AJSON: TJSONObject): TUserNotification;
    
    property Id: string read FId write FId;
    property NotificationType: TNotificationType read FNotificationType write FNotificationType;
    property Title: string read FTitle write FTitle;
    property Message: string read FMessage write FMessage;
    property FeedbackId: string read FFeedbackId write FFeedbackId;
    property IsRead: Boolean read FIsRead write FIsRead;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property ReadAt: TDateTime read FReadAt write FReadAt;
  end;

  /// <summary>�ύ����</summary>
  TSubmitProgress = record
    CurrentFile: string;
    TotalFiles: Integer;
    ProcessedFiles: Integer;
    TotalBytes: Int64;
    ProcessedBytes: Int64;
    function ProgressPercent: Integer;
  end;

  /// <summary>������������</summary>
  TFeedbackConfig = record
    ServiceURL: string;
    ApiKey: string;
    UserId: string;
    UserEmail: string;
    UserName: string;
    AppVersion: string;
    EnableAutoSystemInfo: Boolean;
    EnableAutoLogCollection: Boolean;
    LogRetentionDays: Integer;
    MaxAttachmentSizeMB: Integer;
    MaxTotalAttachmentsMB: Integer;
    OfflineQueuePath: string;
    class function Default: TFeedbackConfig; static;
  end;

  // �¼�����
  TFeedbackSubmitEvent = procedure(Sender: TObject; AFeedback: TFeedbackItem;
    Success: Boolean; const AErrorMsg: string) of object;
  TSubmitProgressEvent = procedure(Sender: TObject; const Progress: TSubmitProgress) of object;
  TNotificationEvent = procedure(Sender: TObject; ANotification: TUserNotification) of object;

  /// <summary>ϵͳ��Ϣ�ռ���</summary>
  TSystemInfoCollector = class
  private
    class function GetOSInfo: string;
    class function GetOSVersion: string;
    class function GetCPUInfo: string;
    class function GetMemoryInfo(out ATotalMB, AFreeMB: Integer): Boolean;
    class function GetDiskInfo(out ATotalMB, AFreeMB: Integer): Boolean;
    class function GetScreenInfo(out AWidth, AHeight: Integer): Boolean;
  public
    class function Collect: TSystemInfo;
  end;

  /// <summary>��־�ռ���</summary>
  TLogCollector = class
  private
    FLogPaths: TStringList;
    FMaxDays: Integer;
    FMaxSizeMB: Integer;
    FTempPath: string;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure AddLogPath(const APath: string);
    procedure ClearLogPaths;
    
    function CollectLogs(const AOutputPath: string): Boolean;
    function CollectRecentLogs(ADays: Integer; const AOutputPath: string): Boolean;
    function GetCollectedSize: Int64;
    
    property MaxDays: Integer read FMaxDays write FMaxDays;
    property MaxSizeMB: Integer read FMaxSizeMB write FMaxSizeMB;
  end;

  /// <summary>��ͼ������</summary>
  TScreenCaptureProc = reference to function(ALeft, ATop, AWidth, AHeight: Integer;
    const AOutputPath: string): Boolean;

  TScreenshotCapture = class
  private
    class var FCaptureProc: TScreenCaptureProc;
  public
    class procedure SetCaptureProc(AProc: TScreenCaptureProc);
    class function CaptureScreen(const AOutputPath: string): Boolean;
    class function CaptureActiveWindow(const AOutputPath: string): Boolean;
    class function CaptureRegion(ALeft, ATop, AWidth, AHeight: Integer;
      const AOutputPath: string): Boolean;
  end;

  /// <summary>��������ͻ���</summary>
  TFeedbackServiceClient = class
  private
    FConfig: TFeedbackConfig;
    FHttpClient: THTTPClient;
    FLock: TCriticalSection;
    
    function DoRequest(const AMethod, AEndpoint: string;
      ABody: TJSONObject = nil): TJSONObject;
    function UploadFile(const AEndpoint, AFilePath: string): TJSONObject;
  public
    constructor Create(const AConfig: TFeedbackConfig);
    destructor Destroy; override;
    
    function SubmitFeedback(AFeedback: TFeedbackItem): Boolean;
    function UploadAttachment(AFeedbackId: string; const AFilePath: string;
      out AAttachmentInfo: TAttachmentInfo): Boolean;
    function GetFeedbackStatus(const AFeedbackId: string): TFeedbackStatus;
    function GetFeedbackDetails(const AFeedbackId: string): TFeedbackItem;
    function GetMyFeedbacks: TObjectList<TFeedbackItem>;
    function GetComments(const AFeedbackId: string): TObjectList<TFeedbackComment>;
    function AddComment(const AFeedbackId, AContent: string): Boolean;
    function GetNotifications: TObjectList<TUserNotification>;
    function MarkNotificationRead(const ANotificationId: string): Boolean;
    function MarkAllNotificationsRead: Boolean;
    function GetUnreadCount: Integer;
    function SearchByTrackingCode(const ACode: string): TFeedbackItem;
    
    property Config: TFeedbackConfig read FConfig write FConfig;
  end;

  /// <summary>���߷�������</summary>
  TOfflineFeedbackQueue = class
  private
    FQueuePath: string;
    FItems: TObjectList<TFeedbackItem>;
    FLock: TCriticalSection;
    
    procedure LoadQueue;
    procedure SaveQueue;
  public
    constructor Create(const AQueuePath: string);
    destructor Destroy; override;
    
    procedure Enqueue(AFeedback: TFeedbackItem);
    function Dequeue: TFeedbackItem;
    function Peek: TFeedbackItem;
    function Count: Integer;
    function IsEmpty: Boolean;
    procedure Clear;
    
    function GetAll: TObjectList<TFeedbackItem>;
  end;

  /// <summary>����������</summary>
  TFeedbackManager = class
  private
    FConfig: TFeedbackConfig;
    FClient: TFeedbackServiceClient;
    FOfflineQueue: TOfflineFeedbackQueue;
    FLogCollector: TLogCollector;
    FNotifications: TObjectList<TUserNotification>;
    FLock: TCriticalSection;
    FSubmitThread: TThread;
    FPollingThread: TThread;
    FPollingEnabled: Boolean;
    FPollingInterval: Integer;
    
    FOnFeedbackSubmit: TFeedbackSubmitEvent;
    FOnSubmitProgress: TSubmitProgressEvent;
    FOnNotification: TNotificationEvent;
    
    procedure DoFeedbackSubmit(AFeedback: TFeedbackItem; Success: Boolean;
      const AErrorMsg: string);
    procedure DoSubmitProgress(const Progress: TSubmitProgress);
    procedure DoNotification(ANotification: TUserNotification);
    
    function InternalSubmit(AFeedback: TFeedbackItem): Boolean;
    procedure ProcessOfflineQueue;
    procedure PollNotifications;
    
    function GenerateFeedbackId: string;
    function GenerateTrackingCode: string;
    function PackageAttachments(AFeedback: TFeedbackItem): string;
  public
    constructor Create(const AConfig: TFeedbackConfig);
    destructor Destroy; override;
    
    // ��������
    function CreateFeedback(AType: TFeedbackType): TFeedbackItem;
    function CreateBugReport(const ATitle, ADescription: string): TFeedbackItem;
    function CreateFeatureRequest(const ATitle, ADescription: string): TFeedbackItem;
    function CreateCrashReport(const AException: Exception): TFeedbackItem;
    
    // �ύ����
    function Submit(AFeedback: TFeedbackItem): Boolean;
    procedure SubmitAsync(AFeedback: TFeedbackItem);
    function SubmitQuickFeedback(const ATitle, ADescription: string;
      AType: TFeedbackType = ftOther): string;  // ����׷����
    
    // ��������
    function AddScreenshot(AFeedback: TFeedbackItem): Boolean;
    function AddLogFiles(AFeedback: TFeedbackItem): Boolean;
    function AddFile(AFeedback: TFeedbackItem; const AFilePath: string): Boolean;
    
    // ������ѯ
    function GetFeedback(const AFeedbackId: string): TFeedbackItem;
    function GetMyFeedbacks: TObjectList<TFeedbackItem>;
    function SearchByTrackingCode(const ACode: string): TFeedbackItem;
    function GetFeedbackStatus(const AFeedbackId: string): TFeedbackStatus;
    
    // ����
    function GetComments(const AFeedbackId: string): TObjectList<TFeedbackComment>;
    function AddComment(const AFeedbackId, AContent: string): Boolean;
    
    // ֪ͨ
    function GetNotifications: TObjectList<TUserNotification>;
    function GetUnreadNotificationCount: Integer;
    procedure MarkNotificationRead(const ANotificationId: string);
    procedure MarkAllNotificationsRead;
    
    // ֪ͨ��ѯ
    procedure StartNotificationPolling(AIntervalSeconds: Integer = 300);
    procedure StopNotificationPolling;
    
    // ���߶���
    procedure ProcessOfflineQueueAsync;
    function GetOfflineQueueCount: Integer;
    
    // ϵͳ��Ϣ
    function GetSystemInfo: TSystemInfo;
    
    // ��־�ռ�
    procedure AddLogPath(const APath: string);
    function CollectLogs(const AOutputPath: string): Boolean;
    
    // ����
    property Config: TFeedbackConfig read FConfig write FConfig;
    
    // �¼�
    property OnFeedbackSubmit: TFeedbackSubmitEvent read FOnFeedbackSubmit write FOnFeedbackSubmit;
    property OnSubmitProgress: TSubmitProgressEvent read FOnSubmitProgress write FOnSubmitProgress;
    property OnNotification: TNotificationEvent read FOnNotification write FOnNotification;
  end;

  /// <summary>���ٷ����Ի�����</summary>
  TQuickFeedbackHelper = class
  public
    class function ShowBugReport(AManager: TFeedbackManager;
      const ATitle: string = ''): string;
    class function ShowFeatureRequest(AManager: TFeedbackManager;
      const ATitle: string = ''): string;
    class function ShowQuickFeedback(AManager: TFeedbackManager;
      AType: TFeedbackType = ftOther): string;
  end;

// ȫ�ֺ���
function FeedbackManager: TFeedbackManager;
procedure SetFeedbackManager(AManager: TFeedbackManager);

// ��������
function FeedbackTypeToString(AType: TFeedbackType): string;
function StringToFeedbackType(const AValue: string): TFeedbackType;
function FeedbackStatusToString(AStatus: TFeedbackStatus): string;
function StringToFeedbackStatus(const AValue: string): TFeedbackStatus;
function FeedbackPriorityToString(APriority: TFeedbackPriority): string;
function StringToFeedbackPriority(const AValue: string): TFeedbackPriority;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows, Winapi.ShlObj;
{$ENDIF}

var
  GFeedbackManager: TFeedbackManager = nil;

function GetJsonString(AJSON: TJSONObject; const AName: string;
  const ADefault: string = ''): string;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  if not Assigned(AJSON) then
    Exit;

  LValue := AJSON.GetValue(AName);
  if Assigned(LValue) then
    Result := LValue.Value;
end;

function GetJsonObject(AJSON: TJSONObject; const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  Result := nil;
  if not Assigned(AJSON) then
    Exit;

  LValue := AJSON.GetValue(AName);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue);
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

function FeedbackManager: TFeedbackManager;
begin
  Result := GFeedbackManager;
end;

procedure SetFeedbackManager(AManager: TFeedbackManager);
begin
  GFeedbackManager := AManager;
end;

function FeedbackTypeToString(AType: TFeedbackType): string;
begin
  case AType of
    ftBug: Result := 'Bug';
    ftFeature: Result := 'Feature';
    ftQuestion: Result := 'Question';
    ftImprovement: Result := 'Improvement';
    ftCrash: Result := 'Crash';
    ftPerformance: Result := 'Performance';
    ftOther: Result := 'Other';
  else
    Result := 'Other';
  end;
end;

function StringToFeedbackType(const AValue: string): TFeedbackType;
var
  LOrd: Integer;
begin
  if TryStrToInt(AValue, LOrd) and (LOrd >= Ord(Low(TFeedbackType))) and
    (LOrd <= Ord(High(TFeedbackType))) then Exit(TFeedbackType(LOrd));

  if SameText(AValue, 'Bug') then Result := ftBug
  else if SameText(AValue, 'Feature') then Result := ftFeature
  else if SameText(AValue, 'Question') then Result := ftQuestion
  else if SameText(AValue, 'Improvement') then Result := ftImprovement
  else if SameText(AValue, 'Crash') then Result := ftCrash
  else if SameText(AValue, 'Performance') then Result := ftPerformance
  else Result := ftOther;
end;

function FeedbackStatusToString(AStatus: TFeedbackStatus): string;
begin
  case AStatus of
    fsNew: Result := 'New';
    fsPending: Result := 'Pending';
    fsInProgress: Result := 'InProgress';
    fsResolved: Result := 'Resolved';
    fsClosed: Result := 'Closed';
    fsRejected: Result := 'Rejected';
  else
    Result := 'New';
  end;
end;

function StringToFeedbackStatus(const AValue: string): TFeedbackStatus;
var
  LOrd: Integer;
begin
  if TryStrToInt(AValue, LOrd) and (LOrd >= Ord(Low(TFeedbackStatus))) and
    (LOrd <= Ord(High(TFeedbackStatus))) then Exit(TFeedbackStatus(LOrd));

  if SameText(AValue, 'New') then Result := fsNew
  else if SameText(AValue, 'Pending') then Result := fsPending
  else if SameText(AValue, 'InProgress') then Result := fsInProgress
  else if SameText(AValue, 'Resolved') then Result := fsResolved
  else if SameText(AValue, 'Closed') then Result := fsClosed
  else if SameText(AValue, 'Rejected') then Result := fsRejected
  else Result := fsNew;
end;

function FeedbackPriorityToString(APriority: TFeedbackPriority): string;
begin
  case APriority of
    fpLow: Result := 'Low';
    fpNormal: Result := 'Normal';
    fpHigh: Result := 'High';
    fpCritical: Result := 'Critical';
  else
    Result := 'Normal';
  end;
end;

function StringToFeedbackPriority(const AValue: string): TFeedbackPriority;
var
  LOrd: Integer;
begin
  if TryStrToInt(AValue, LOrd) and (LOrd >= Ord(Low(TFeedbackPriority))) and
    (LOrd <= Ord(High(TFeedbackPriority))) then Exit(TFeedbackPriority(LOrd));

  if SameText(AValue, 'Low') then Result := fpLow
  else if SameText(AValue, 'Normal') then Result := fpNormal
  else if SameText(AValue, 'High') then Result := fpHigh
  else if SameText(AValue, 'Critical') then Result := fpCritical
  else Result := fpNormal;
end;

{ TAttachmentInfo }

class function TAttachmentInfo.Create(const AFileName, ALocalPath: string): TAttachmentInfo;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result.Id := GUIDToString(GUID);
  Result.FileName := AFileName;
  Result.LocalPath := ALocalPath;
  Result.RemoteURL := '';
  Result.UploadedAt := 0;
  
  if TFile.Exists(ALocalPath) then
  begin
    Result.FileSize := TFile.GetSize(ALocalPath);
    Result.MimeType := 'application/octet-stream';
    
    // ������չ������MIME����
    var LExt := LowerCase(TPath.GetExtension(AFileName));
    if LExt = '.txt' then Result.MimeType := 'text/plain'
    else if LExt = '.log' then Result.MimeType := 'text/plain'
    else if LExt = '.png' then Result.MimeType := 'image/png'
    else if LExt = '.jpg' then Result.MimeType := 'image/jpeg'
    else if LExt = '.jpeg' then Result.MimeType := 'image/jpeg'
    else if LExt = '.gif' then Result.MimeType := 'image/gif'
    else if LExt = '.zip' then Result.MimeType := 'application/zip'
    else if LExt = '.json' then Result.MimeType := 'application/json'
    else if LExt = '.xml' then Result.MimeType := 'application/xml';
  end
  else
  begin
    Result.FileSize := 0;
    Result.MimeType := 'application/octet-stream';
  end;
end;

function TAttachmentInfo.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', Id);
  Result.AddPair('fileName', FileName);
  Result.AddPair('fileSize', TJSONNumber.Create(FileSize));
  Result.AddPair('mimeType', MimeType);
  Result.AddPair('localPath', LocalPath);
  Result.AddPair('remoteURL', RemoteURL);
  if UploadedAt > 0 then
    Result.AddPair('uploadedAt', DateToISO8601(UploadedAt));
end;

class function TAttachmentInfo.FromJSON(AJSON: TJSONObject): TAttachmentInfo;
var
  LUploadedStr: string;
begin
  Result.Id := AJSON.GetValue<string>('id', '');
  Result.FileName := AJSON.GetValue<string>('fileName', '');
  Result.FileSize := AJSON.GetValue<Int64>('fileSize', 0);
  Result.MimeType := AJSON.GetValue<string>('mimeType', 'application/octet-stream');
  Result.LocalPath := AJSON.GetValue<string>('localPath', '');
  Result.RemoteURL := AJSON.GetValue<string>('remoteURL', '');
  LUploadedStr := AJSON.GetValue<string>('uploadedAt', '');
  if LUploadedStr <> '' then
    Result.UploadedAt := JsonStringToDateTime(LUploadedStr, 0)
  else
    Result.UploadedAt := 0;
end;

{ TSystemInfo }

function TSystemInfo.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('osName', OSName);
  Result.AddPair('osVersion', OSVersion);
  Result.AddPair('osArchitecture', OSArchitecture);
  Result.AddPair('cpuName', CPUName);
  Result.AddPair('cpuCores', TJSONNumber.Create(CPUCores));
  Result.AddPair('ramTotalMB', TJSONNumber.Create(RAMTotalMB));
  Result.AddPair('ramFreeMB', TJSONNumber.Create(RAMFreeMB));
  Result.AddPair('diskTotalMB', TJSONNumber.Create(DiskTotalMB));
  Result.AddPair('diskFreeMB', TJSONNumber.Create(DiskFreeMB));
  Result.AddPair('screenWidth', TJSONNumber.Create(ScreenWidth));
  Result.AddPair('screenHeight', TJSONNumber.Create(ScreenHeight));
  Result.AddPair('appVersion', AppVersion);
  Result.AddPair('appBuildDate', AppBuildDate);
  Result.AddPair('delphiVersion', DelphiVersion);
  Result.AddPair('userLocale', UserLocale);
  Result.AddPair('timeZone', TimeZone);
end;

class function TSystemInfo.FromJSON(AJSON: TJSONObject): TSystemInfo;
begin
  Result.OSName := AJSON.GetValue<string>('osName', '');
  Result.OSVersion := AJSON.GetValue<string>('osVersion', '');
  Result.OSArchitecture := AJSON.GetValue<string>('osArchitecture', '');
  Result.CPUName := AJSON.GetValue<string>('cpuName', '');
  Result.CPUCores := AJSON.GetValue<Integer>('cpuCores', 0);
  Result.RAMTotalMB := AJSON.GetValue<Integer>('ramTotalMB', 0);
  Result.RAMFreeMB := AJSON.GetValue<Integer>('ramFreeMB', 0);
  Result.DiskTotalMB := AJSON.GetValue<Integer>('diskTotalMB', 0);
  Result.DiskFreeMB := AJSON.GetValue<Integer>('diskFreeMB', 0);
  Result.ScreenWidth := AJSON.GetValue<Integer>('screenWidth', 0);
  Result.ScreenHeight := AJSON.GetValue<Integer>('screenHeight', 0);
  Result.AppVersion := AJSON.GetValue<string>('appVersion', '');
  Result.AppBuildDate := AJSON.GetValue<string>('appBuildDate', '');
  Result.DelphiVersion := AJSON.GetValue<string>('delphiVersion', '');
  Result.UserLocale := AJSON.GetValue<string>('userLocale', '');
  Result.TimeZone := AJSON.GetValue<string>('timeZone', '');
end;

{ TFeedbackItem }

constructor TFeedbackItem.Create;
var
  GUID: TGUID;
begin
  inherited Create;
  CreateGUID(GUID);
  FId := GUIDToString(GUID);
  FFeedbackType := ftOther;
  FPriority := fpNormal;
  FStatus := fsNew;
  FAttachments := TList<TAttachmentInfo>.Create;
  FTags := TStringList.Create;
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FIsSubmitted := False;
end;

destructor TFeedbackItem.Destroy;
begin
  FreeAndNil(FAttachments);
  FreeAndNil(FTags);
  inherited;
end;

procedure TFeedbackItem.AddAttachment(const AInfo: TAttachmentInfo);
begin
  FAttachments.Add(AInfo);
  FUpdatedAt := Now;
end;

procedure TFeedbackItem.RemoveAttachment(const AId: string);
var
  I: Integer;
begin
  for I := FAttachments.Count - 1 downto 0 do
    if FAttachments[I].Id = AId then
    begin
      FAttachments.Delete(I);
      FUpdatedAt := Now;
      Break;
    end;
end;

procedure TFeedbackItem.ClearAttachments;
begin
  FAttachments.Clear;
  FUpdatedAt := Now;
end;

function TFeedbackItem.ToJSON: TJSONObject;
var
  LAttArray, LTagsArray: TJSONArray;
  I: Integer;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('feedbackType', FeedbackTypeToString(FFeedbackType));
  Result.AddPair('priority', FeedbackPriorityToString(FPriority));
  Result.AddPair('status', FeedbackStatusToString(FStatus));
  Result.AddPair('title', FTitle);
  Result.AddPair('description', FDescription);
  Result.AddPair('stepsToReproduce', FStepsToReproduce);
  Result.AddPair('expectedBehavior', FExpectedBehavior);
  Result.AddPair('actualBehavior', FActualBehavior);
  Result.AddPair('userId', FUserId);
  Result.AddPair('userEmail', FUserEmail);
  Result.AddPair('userName', FUserName);
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
  Result.AddPair('updatedAt', DateToISO8601(FUpdatedAt));
  if FSubmittedAt > 0 then
    Result.AddPair('submittedAt', DateToISO8601(FSubmittedAt));
  Result.AddPair('isSubmitted', TJSONBool.Create(FIsSubmitted));
  Result.AddPair('trackingCode', FTrackingCode);
  Result.AddPair('systemInfo', FSystemInfo.ToJSON);
  
  LAttArray := TJSONArray.Create;
  for I := 0 to FAttachments.Count - 1 do
    LAttArray.Add(FAttachments[I].ToJSON);
  Result.AddPair('attachments', LAttArray);
  
  LTagsArray := TJSONArray.Create;
  for I := 0 to FTags.Count - 1 do
    LTagsArray.Add(FTags[I]);
  Result.AddPair('tags', LTagsArray);
end;

class function TFeedbackItem.FromJSON(AJSON: TJSONObject): TFeedbackItem;
var
  LAttArray, LTagsArray: TJSONArray;
  LSysObj: TJSONObject;
  I: Integer;
  LStr: string;
begin
  Result := TFeedbackItem.Create;
  try
    Result.FId := GetJsonString(AJSON, 'id', Result.FId);
    Result.FFeedbackType := StringToFeedbackType(GetJsonString(AJSON, 'feedbackType'));
    Result.FPriority := StringToFeedbackPriority(GetJsonString(AJSON, 'priority'));
    Result.FStatus := StringToFeedbackStatus(GetJsonString(AJSON, 'status'));
    Result.FTitle := GetJsonString(AJSON, 'title');
    Result.FDescription := GetJsonString(AJSON, 'description');
    Result.FStepsToReproduce := GetJsonString(AJSON, 'stepsToReproduce');
    Result.FExpectedBehavior := GetJsonString(AJSON, 'expectedBehavior');
    Result.FActualBehavior := GetJsonString(AJSON, 'actualBehavior');
    Result.FUserId := GetJsonString(AJSON, 'userId');
    Result.FUserEmail := GetJsonString(AJSON, 'userEmail');
    Result.FUserName := GetJsonString(AJSON, 'userName');
    Result.FCreatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'createdAt'), Result.FCreatedAt);
    Result.FUpdatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'updatedAt'), Result.FUpdatedAt);
    LStr := GetJsonString(AJSON, 'submittedAt');
    if LStr <> '' then
      Result.FSubmittedAt := JsonStringToDateTime(LStr, 0);
    Result.FIsSubmitted := AJSON.GetValue<Boolean>('isSubmitted', False);
    Result.FTrackingCode := GetJsonString(AJSON, 'trackingCode');

    LSysObj := GetJsonObject(AJSON, 'systemInfo');
    if Assigned(LSysObj) then
      Result.FSystemInfo := TSystemInfo.FromJSON(LSysObj);

    LAttArray := GetJsonArray(AJSON, 'attachments');
    if Assigned(LAttArray) then
      for I := 0 to LAttArray.Count - 1 do
        Result.FAttachments.Add(TAttachmentInfo.FromJSON(LAttArray.Items[I] as TJSONObject));

    LTagsArray := GetJsonArray(AJSON, 'tags');
    if Assigned(LTagsArray) then
      for I := 0 to LTagsArray.Count - 1 do
        Result.FTags.Add(LTagsArray.Items[I].Value);
  except
    Result.Free;
    raise;
  end;
end;

function TFeedbackItem.Validate: TArray<string>;
var
  LErrors: TList<string>;
begin
  LErrors := TList<string>.Create;
  try
    if FTitle.Trim = '' then
      LErrors.Add('���ⲻ��Ϊ��');
    if Length(FTitle) > 200 then
      LErrors.Add('���ⲻ�ܳ���200���ַ�');
    if FDescription.Trim = '' then
      LErrors.Add('��������Ϊ��');
    if (FUserEmail <> '') and not FUserEmail.Contains('@') then
      LErrors.Add('�����ʽ����ȷ');
      
    Result := LErrors.ToArray;
  finally
    LErrors.Free;
  end;
end;

{ TFeedbackComment }

function TFeedbackComment.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('feedbackId', FFeedbackId);
  Result.AddPair('authorId', FAuthorId);
  Result.AddPair('authorName', FAuthorName);
  Result.AddPair('content', FContent);
  Result.AddPair('isStaff', TJSONBool.Create(FIsStaff));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
end;

class function TFeedbackComment.FromJSON(AJSON: TJSONObject): TFeedbackComment;
begin
  Result := TFeedbackComment.Create;
  try
    Result.FId := GetJsonString(AJSON, 'id');
    Result.FFeedbackId := GetJsonString(AJSON, 'feedbackId');
    Result.FAuthorId := GetJsonString(AJSON, 'authorId');
    Result.FAuthorName := GetJsonString(AJSON, 'authorName');
    Result.FContent := GetJsonString(AJSON, 'content');
    Result.FIsStaff := AJSON.GetValue<Boolean>('isStaff', False);
    Result.FCreatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'createdAt'), Result.FCreatedAt);
  except
    Result.Free;
    raise;
  end;
end;

{ TUserNotification }

function TUserNotification.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', FId);
  Result.AddPair('notificationType', TJSONNumber.Create(Ord(FNotificationType)));
  Result.AddPair('title', FTitle);
  Result.AddPair('message', FMessage);
  Result.AddPair('feedbackId', FFeedbackId);
  Result.AddPair('isRead', TJSONBool.Create(FIsRead));
  Result.AddPair('createdAt', DateToISO8601(FCreatedAt));
  if FReadAt > 0 then
    Result.AddPair('readAt', DateToISO8601(FReadAt));
end;

class function TUserNotification.FromJSON(AJSON: TJSONObject): TUserNotification;
var
  LStr: string;
begin
  Result := TUserNotification.Create;
  try
    Result.FId := GetJsonString(AJSON, 'id');
    Result.FNotificationType := TNotificationType(AJSON.GetValue<Integer>('notificationType', 0));
    Result.FTitle := GetJsonString(AJSON, 'title');
    Result.FMessage := GetJsonString(AJSON, 'message');
    Result.FFeedbackId := GetJsonString(AJSON, 'feedbackId');
    Result.FIsRead := AJSON.GetValue<Boolean>('isRead', False);
    Result.FCreatedAt := JsonStringToDateTime(GetJsonString(AJSON, 'createdAt'), Result.FCreatedAt);
    LStr := GetJsonString(AJSON, 'readAt');
    if LStr <> '' then
      Result.FReadAt := JsonStringToDateTime(LStr, 0);
  except
    Result.Free;
    raise;
  end;
end;

{ TSubmitProgress }

function TSubmitProgress.ProgressPercent: Integer;
begin
  if TotalBytes > 0 then
    Result := (ProcessedBytes * 100) div TotalBytes
  else if TotalFiles > 0 then
    Result := (ProcessedFiles * 100) div TotalFiles
  else
    Result := 0;
end;

{ TFeedbackConfig }

class function TFeedbackConfig.Default: TFeedbackConfig;
begin
  Result.ServiceURL := 'https://feedback.DeepBase.cloud/v1';
  Result.ApiKey := '';
  Result.UserId := '';
  Result.UserEmail := '';
  Result.UserName := '';
  Result.AppVersion := '1.0.0';
  Result.EnableAutoSystemInfo := True;
  Result.EnableAutoLogCollection := True;
  Result.LogRetentionDays := 7;
  Result.MaxAttachmentSizeMB := 10;
  Result.MaxTotalAttachmentsMB := 50;
  Result.OfflineQueuePath := '';
end;

{ TSystemInfoCollector }

class function TSystemInfoCollector.GetOSInfo: string;
begin
  {$IFDEF MSWINDOWS}
  Result := 'Windows';
  {$ENDIF}
  {$IFDEF MACOS}
  Result := 'macOS';
  {$ENDIF}
  {$IFDEF LINUX}
  Result := 'Linux';
  {$ENDIF}
  {$IFDEF ANDROID}
  Result := 'Android';
  {$ENDIF}
  {$IFDEF IOS}
  Result := 'iOS';
  {$ENDIF}
end;

class function TSystemInfoCollector.GetOSVersion: string;
begin
  {$IFDEF MSWINDOWS}
  Result := TOSVersion.ToString;
  {$ELSE}
  Result := 'Unknown';
  {$ENDIF}
end;

class function TSystemInfoCollector.GetCPUInfo: string;
begin
  {$IFDEF MSWINDOWS}
  Result := 'x86/x64 Processor';
  {$ELSE}
  Result := 'Unknown';
  {$ENDIF}
end;

class function TSystemInfoCollector.GetMemoryInfo(out ATotalMB, AFreeMB: Integer): Boolean;
{$IFDEF MSWINDOWS}
var
  LMemStatus: TMemoryStatusEx;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  LMemStatus.dwLength := SizeOf(LMemStatus);
  Result := GlobalMemoryStatusEx(LMemStatus);
  if Result then
  begin
    ATotalMB := LMemStatus.ullTotalPhys div (1024 * 1024);
    AFreeMB := LMemStatus.ullAvailPhys div (1024 * 1024);
  end;
  {$ELSE}
  ATotalMB := 0;
  AFreeMB := 0;
  Result := False;
  {$ENDIF}
end;

class function TSystemInfoCollector.GetDiskInfo(out ATotalMB, AFreeMB: Integer): Boolean;
{$IFDEF MSWINDOWS}
var
  LFreeBytes, LTotalBytes, LTotalFreeBytes: Int64;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := GetDiskFreeSpaceEx(PChar(TPath.GetHomePath[1] + ':\'),
    LFreeBytes, LTotalBytes, @LTotalFreeBytes);
  if Result then
  begin
    ATotalMB := LTotalBytes div (1024 * 1024);
    AFreeMB := LFreeBytes div (1024 * 1024);
  end;
  {$ELSE}
  ATotalMB := 0;
  AFreeMB := 0;
  Result := False;
  {$ENDIF}
end;

class function TSystemInfoCollector.GetScreenInfo(out AWidth, AHeight: Integer): Boolean;
begin
  {$IFDEF MSWINDOWS}
  AWidth := GetSystemMetrics(SM_CXSCREEN);
  AHeight := GetSystemMetrics(SM_CYSCREEN);
  Result := True;
  {$ELSE}
  AWidth := 0;
  AHeight := 0;
  Result := False;
  {$ENDIF}
end;

class function TSystemInfoCollector.Collect: TSystemInfo;
var
  LTotalMB, LFreeMB: Integer;
  LWidth, LHeight: Integer;
begin
  Result.OSName := GetOSInfo;
  Result.OSVersion := GetOSVersion;
  
  {$IFDEF CPUX64}
  Result.OSArchitecture := 'x64';
  {$ELSE}
  Result.OSArchitecture := 'x86';
  {$ENDIF}
  
  Result.CPUName := GetCPUInfo;
  Result.CPUCores := System.CPUCount;
  
  if GetMemoryInfo(LTotalMB, LFreeMB) then
  begin
    Result.RAMTotalMB := LTotalMB;
    Result.RAMFreeMB := LFreeMB;
  end;
  
  if GetDiskInfo(LTotalMB, LFreeMB) then
  begin
    Result.DiskTotalMB := LTotalMB;
    Result.DiskFreeMB := LFreeMB;
  end;
  
  if GetScreenInfo(LWidth, LHeight) then
  begin
    Result.ScreenWidth := LWidth;
    Result.ScreenHeight := LHeight;
  end;
  
  Result.AppVersion := '';
  Result.AppBuildDate := '';
  Result.DelphiVersion := {$IFDEF VER350}'Delphi 11.x'{$ELSE}'Delphi'{$ENDIF};
  Result.UserLocale := IntToStr(TLanguages.UserDefaultLocale);
  
  {$IFDEF MSWINDOWS}
  var LTZInfo: TTimeZoneInformation;
  GetTimeZoneInformation(LTZInfo);
  Result.TimeZone := LTZInfo.StandardName;
  {$ELSE}
  Result.TimeZone := '';
  {$ENDIF}
end;

{ TLogCollector }

constructor TLogCollector.Create;
begin
  inherited Create;
  FLogPaths := TStringList.Create;
  FMaxDays := 7;
  FMaxSizeMB := 50;
  FTempPath := TPath.GetTempPath;
end;

destructor TLogCollector.Destroy;
begin
  FreeAndNil(FLogPaths);
  inherited;
end;

procedure TLogCollector.AddLogPath(const APath: string);
begin
  if FLogPaths.IndexOf(APath) < 0 then
    FLogPaths.Add(APath);
end;

procedure TLogCollector.ClearLogPaths;
begin
  FLogPaths.Clear;
end;

function TLogCollector.CollectLogs(const AOutputPath: string): Boolean;
begin
  Result := CollectRecentLogs(FMaxDays, AOutputPath);
end;

function TLogCollector.CollectRecentLogs(ADays: Integer;
  const AOutputPath: string): Boolean;
var
  LZip: TZipFile;
  LPath, LFile: string;
  LFiles: TStringDynArray;
  LCutoffDate: TDateTime;
  LTotalSize: Int64;
  LMaxSize: Int64;
begin
  Result := False;
  LCutoffDate := IncDay(Now, -ADays);
  LMaxSize := Int64(FMaxSizeMB) * 1024 * 1024;
  LTotalSize := 0;
  
  LZip := TZipFile.Create;
  try
    LZip.Open(AOutputPath, zmWrite);
    try
      for LPath in FLogPaths do
      begin
        if TDirectory.Exists(LPath) then
        begin
          LFiles := TDirectory.GetFiles(LPath, '*.log', TSearchOption.soAllDirectories);
          for LFile in LFiles do
          begin
            if TFile.GetLastWriteTime(LFile) >= LCutoffDate then
            begin
              var LFileSize := TFile.GetSize(LFile);
              if LTotalSize + LFileSize <= LMaxSize then
              begin
                LZip.Add(LFile, TPath.GetFileName(LFile));
                LTotalSize := LTotalSize + LFileSize;
              end;
            end;
          end;
        end
        else if TFile.Exists(LPath) then
        begin
          if TFile.GetLastWriteTime(LPath) >= LCutoffDate then
          begin
            var LFileSize := TFile.GetSize(LPath);
            if LTotalSize + LFileSize <= LMaxSize then
            begin
              LZip.Add(LPath, TPath.GetFileName(LPath));
              LTotalSize := LTotalSize + LFileSize;
            end;
          end;
        end;
      end;
      
      Result := True;
    finally
      LZip.Close;
    end;
  finally
    LZip.Free;
  end;
end;

function TLogCollector.GetCollectedSize: Int64;
var
  LPath, LFile: string;
  LFiles: TStringDynArray;
begin
  Result := 0;
  
  for LPath in FLogPaths do
  begin
    if TDirectory.Exists(LPath) then
    begin
      LFiles := TDirectory.GetFiles(LPath, '*.log', TSearchOption.soAllDirectories);
      for LFile in LFiles do
        Result := Result + TFile.GetSize(LFile);
    end
    else if TFile.Exists(LPath) then
      Result := Result + TFile.GetSize(LPath);
  end;
end;

{ TScreenshotCapture }

class procedure TScreenshotCapture.SetCaptureProc(AProc: TScreenCaptureProc);
begin
  FCaptureProc := AProc;
end;

class function TScreenshotCapture.CaptureScreen(const AOutputPath: string): Boolean;
begin
  if Assigned(FCaptureProc) then
    Result := FCaptureProc(-1, 0, 0, 0, AOutputPath)
  else
    Result := False;
end;

class function TScreenshotCapture.CaptureActiveWindow(const AOutputPath: string): Boolean;
begin
  if Assigned(FCaptureProc) then
    Result := FCaptureProc(-2, 0, 0, 0, AOutputPath)
  else
    Result := False;
end;

class function TScreenshotCapture.CaptureRegion(ALeft, ATop, AWidth, AHeight: Integer;
  const AOutputPath: string): Boolean;
begin
  if Assigned(FCaptureProc) then
    Result := FCaptureProc(ALeft, ATop, AWidth, AHeight, AOutputPath)
  else
    Result := False;
end;

{ TFeedbackServiceClient }

constructor TFeedbackServiceClient.Create(const AConfig: TFeedbackConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := 30000;
  FHttpClient.ResponseTimeout := 60000;
  FLock := TCriticalSection.Create;
end;

destructor TFeedbackServiceClient.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

function TFeedbackServiceClient.DoRequest(const AMethod, AEndpoint: string;
  ABody: TJSONObject): TJSONObject;
var
  LResponse: IHTTPResponse;
  LURL: string;
  LStream: TStringStream;
  LHeaders: TNetHeaders;
begin
  Result := nil;
  LURL := FConfig.ServiceURL + AEndpoint;
  
  SetLength(LHeaders, 3);
  LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/json');
  LHeaders[1] := TNameValuePair.Create('X-API-Key', FConfig.ApiKey);
  LHeaders[2] := TNameValuePair.Create('X-User-Id', FConfig.UserId);
  
  FLock.Enter;
  try
    if AMethod = 'GET' then
      LResponse := FHttpClient.Get(LURL, nil, LHeaders)
    else if AMethod = 'POST' then
    begin
      LStream := TStringStream.Create('', TEncoding.UTF8);
      try
        if Assigned(ABody) then
          LStream.WriteString(ABody.ToJSON);
        LStream.Position := 0;
        LResponse := FHttpClient.Post(LURL, LStream, nil, LHeaders);
      finally
        LStream.Free;
      end;
    end
    else if AMethod = 'PUT' then
    begin
      LStream := TStringStream.Create('', TEncoding.UTF8);
      try
        if Assigned(ABody) then
          LStream.WriteString(ABody.ToJSON);
        LStream.Position := 0;
        LResponse := FHttpClient.Put(LURL, LStream, nil, LHeaders);
      finally
        LStream.Free;
      end;
    end
    else if AMethod = 'DELETE' then
      LResponse := FHttpClient.Delete(LURL, nil, LHeaders);
      
    if (LResponse.StatusCode = 200) and (LResponse.ContentAsString <> '') then
      Result := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
  finally
    FLock.Leave;
  end;
end;

function TFeedbackServiceClient.UploadFile(const AEndpoint, AFilePath: string): TJSONObject;
var
  LResponse: IHTTPResponse;
  LURL: string;
  LStream: TFileStream;
  LHeaders: TNetHeaders;
begin
  Result := nil;
  LURL := FConfig.ServiceURL + AEndpoint;
  
  if not TFile.Exists(AFilePath) then
    Exit;
    
  SetLength(LHeaders, 3);
  LHeaders[0] := TNameValuePair.Create('Content-Type', 'application/octet-stream');
  LHeaders[1] := TNameValuePair.Create('X-API-Key', FConfig.ApiKey);
  LHeaders[2] := TNameValuePair.Create('X-File-Name', TPath.GetFileName(AFilePath));
  
  FLock.Enter;
  try
    LStream := TFileStream.Create(AFilePath, fmOpenRead or fmShareDenyWrite);
    try
      LResponse := FHttpClient.Post(LURL, LStream, nil, LHeaders);
      if (LResponse.StatusCode = 200) and (LResponse.ContentAsString <> '') then
        Result := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
    finally
      LStream.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TFeedbackServiceClient.SubmitFeedback(AFeedback: TFeedbackItem): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := DoRequest('POST', '/feedback', AFeedback.ToJSON);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Boolean>('success', False);
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.UploadAttachment(AFeedbackId: string;
  const AFilePath: string; out AAttachmentInfo: TAttachmentInfo): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := UploadFile('/feedback/' + AFeedbackId + '/attachments', AFilePath);
  try
    if Assigned(LResponse) and LResponse.GetValue<Boolean>('success', False) then
    begin
      var LAttObj := LResponse.GetValue<TJSONObject>('attachment');
      if Assigned(LAttObj) then
      begin
        AAttachmentInfo := TAttachmentInfo.FromJSON(LAttObj);
        Result := True;
      end;
    end;
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.GetFeedbackStatus(const AFeedbackId: string): TFeedbackStatus;
var
  LResponse: TJSONObject;
begin
  Result := fsNew;
  LResponse := DoRequest('GET', '/feedback/' + AFeedbackId + '/status', nil);
  try
    if Assigned(LResponse) then
      Result := StringToFeedbackStatus(LResponse.GetValue<string>('status', 'New'));
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.GetFeedbackDetails(const AFeedbackId: string): TFeedbackItem;
var
  LResponse: TJSONObject;
begin
  Result := nil;
  LResponse := DoRequest('GET', '/feedback/' + AFeedbackId, nil);
  try
    if Assigned(LResponse) then
      Result := TFeedbackItem.FromJSON(LResponse);
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.GetMyFeedbacks: TObjectList<TFeedbackItem>;
var
  LResponse: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TFeedbackItem>.Create(True);
  LResponse := DoRequest('GET', '/feedback/my', nil);
  try
    if Assigned(LResponse) then
    begin
      LItems := LResponse.GetValue<TJSONArray>('items');
      if Assigned(LItems) then
        for I := 0 to LItems.Count - 1 do
          Result.Add(TFeedbackItem.FromJSON(LItems.Items[I] as TJSONObject));
    end;
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.GetComments(const AFeedbackId: string): TObjectList<TFeedbackComment>;
var
  LResponse: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TFeedbackComment>.Create(True);
  LResponse := DoRequest('GET', '/feedback/' + AFeedbackId + '/comments', nil);
  try
    if Assigned(LResponse) then
    begin
      LItems := LResponse.GetValue<TJSONArray>('items');
      if Assigned(LItems) then
        for I := 0 to LItems.Count - 1 do
          Result.Add(TFeedbackComment.FromJSON(LItems.Items[I] as TJSONObject));
    end;
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.AddComment(const AFeedbackId, AContent: string): Boolean;
var
  LBody: TJSONObject;
  LResponse: TJSONObject;
begin
  Result := False;
  LBody := TJSONObject.Create;
  try
    LBody.AddPair('content', AContent);
    LResponse := DoRequest('POST', '/feedback/' + AFeedbackId + '/comments', LBody);
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

function TFeedbackServiceClient.GetNotifications: TObjectList<TUserNotification>;
var
  LResponse: TJSONObject;
  LItems: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TUserNotification>.Create(True);
  LResponse := DoRequest('GET', '/notifications', nil);
  try
    if Assigned(LResponse) then
    begin
      LItems := LResponse.GetValue<TJSONArray>('items');
      if Assigned(LItems) then
        for I := 0 to LItems.Count - 1 do
          Result.Add(TUserNotification.FromJSON(LItems.Items[I] as TJSONObject));
    end;
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.MarkNotificationRead(const ANotificationId: string): Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := DoRequest('PUT', '/notifications/' + ANotificationId + '/read', nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Boolean>('success', False);
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.MarkAllNotificationsRead: Boolean;
var
  LResponse: TJSONObject;
begin
  Result := False;
  LResponse := DoRequest('PUT', '/notifications/read-all', nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Boolean>('success', False);
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.GetUnreadCount: Integer;
var
  LResponse: TJSONObject;
begin
  Result := 0;
  LResponse := DoRequest('GET', '/notifications/unread-count', nil);
  try
    if Assigned(LResponse) then
      Result := LResponse.GetValue<Integer>('count', 0);
  finally
    LResponse.Free;
  end;
end;

function TFeedbackServiceClient.SearchByTrackingCode(const ACode: string): TFeedbackItem;
var
  LResponse: TJSONObject;
begin
  Result := nil;
  LResponse := DoRequest('GET', '/feedback/track/' + TNetEncoding.URL.Encode(ACode), nil);
  try
    if Assigned(LResponse) and LResponse.GetValue<Boolean>('found', False) then
    begin
      var LFeedbackObj := LResponse.GetValue<TJSONObject>('feedback');
      if Assigned(LFeedbackObj) then
        Result := TFeedbackItem.FromJSON(LFeedbackObj);
    end;
  finally
    LResponse.Free;
  end;
end;

{ TOfflineFeedbackQueue }

constructor TOfflineFeedbackQueue.Create(const AQueuePath: string);
begin
  inherited Create;
  FQueuePath := AQueuePath;
  FItems := TObjectList<TFeedbackItem>.Create(True);
  FLock := TCriticalSection.Create;
  
  if FQueuePath <> '' then
  begin
    TDirectory.CreateDirectory(TPath.GetDirectoryName(FQueuePath));
    LoadQueue;
  end;
end;

destructor TOfflineFeedbackQueue.Destroy;
begin
  SaveQueue;
  FreeAndNil(FItems);
  FreeAndNil(FLock);
  inherited;
end;

procedure TOfflineFeedbackQueue.LoadQueue;
var
  LContent: string;
  LJSON: TJSONArray;
  I: Integer;
begin
  if (FQueuePath = '') or not TFile.Exists(FQueuePath) then
    Exit;
    
  FLock.Enter;
  try
    LContent := TFile.ReadAllText(FQueuePath, TEncoding.UTF8);
    LJSON := TJSONObject.ParseJSONValue(LContent) as TJSONArray;
    try
      if Assigned(LJSON) then
        for I := 0 to LJSON.Count - 1 do
          FItems.Add(TFeedbackItem.FromJSON(LJSON.Items[I] as TJSONObject));
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TOfflineFeedbackQueue.SaveQueue;
var
  LJSON: TJSONArray;
  I: Integer;
begin
  if FQueuePath = '' then
    Exit;
    
  FLock.Enter;
  try
    LJSON := TJSONArray.Create;
    try
      for I := 0 to FItems.Count - 1 do
        LJSON.Add(FItems[I].ToJSON);
      TFile.WriteAllText(FQueuePath, LJSON.ToJSON, TEncoding.UTF8);
    finally
      LJSON.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TOfflineFeedbackQueue.Enqueue(AFeedback: TFeedbackItem);
begin
  FLock.Enter;
  try
    FItems.Add(AFeedback);
    SaveQueue;
  finally
    FLock.Leave;
  end;
end;

function TOfflineFeedbackQueue.Dequeue: TFeedbackItem;
begin
  Result := nil;
  FLock.Enter;
  try
    if FItems.Count > 0 then
    begin
      Result := FItems.Extract(FItems[0]);
      SaveQueue;
    end;
  finally
    FLock.Leave;
  end;
end;

function TOfflineFeedbackQueue.Peek: TFeedbackItem;
begin
  Result := nil;
  FLock.Enter;
  try
    if FItems.Count > 0 then
      Result := FItems[0];
  finally
    FLock.Leave;
  end;
end;

function TOfflineFeedbackQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FItems.Count;
  finally
    FLock.Leave;
  end;
end;

function TOfflineFeedbackQueue.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

procedure TOfflineFeedbackQueue.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
    SaveQueue;
  finally
    FLock.Leave;
  end;
end;

function TOfflineFeedbackQueue.GetAll: TObjectList<TFeedbackItem>;
var
  I: Integer;
begin
  Result := TObjectList<TFeedbackItem>.Create(False);  // ��ӵ�ж���
  FLock.Enter;
  try
    for I := 0 to FItems.Count - 1 do
      Result.Add(FItems[I]);
  finally
    FLock.Leave;
  end;
end;

{ TFeedbackManager }

constructor TFeedbackManager.Create(const AConfig: TFeedbackConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FClient := TFeedbackServiceClient.Create(AConfig);
  
  if AConfig.OfflineQueuePath <> '' then
    FOfflineQueue := TOfflineFeedbackQueue.Create(AConfig.OfflineQueuePath)
  else
    FOfflineQueue := TOfflineFeedbackQueue.Create(
      TPath.Combine(TPath.GetTempPath, 'DeepBase_feedback_queue.json'));
      
  FLogCollector := TLogCollector.Create;
  FLogCollector.MaxDays := AConfig.LogRetentionDays;
  FLogCollector.MaxSizeMB := AConfig.MaxTotalAttachmentsMB;
  
  FNotifications := TObjectList<TUserNotification>.Create(True);
  FLock := TCriticalSection.Create;
  FPollingEnabled := False;
  FPollingInterval := 300;
end;

destructor TFeedbackManager.Destroy;
begin
  StopNotificationPolling;
  FreeAndNil(FNotifications);
  FreeAndNil(FLogCollector);
  FreeAndNil(FOfflineQueue);
  FreeAndNil(FClient);
  FreeAndNil(FLock);
  inherited;
end;

procedure TFeedbackManager.DoFeedbackSubmit(AFeedback: TFeedbackItem;
  Success: Boolean; const AErrorMsg: string);
begin
  if Assigned(FOnFeedbackSubmit) then
    TThread.Synchronize(TThread.Current,
      procedure
      begin
        FOnFeedbackSubmit(Self, AFeedback, Success, AErrorMsg);
      end);
end;

procedure TFeedbackManager.DoSubmitProgress(const Progress: TSubmitProgress);
begin
  if Assigned(FOnSubmitProgress) then
    TThread.Synchronize(TThread.Current,
      procedure
      begin
        FOnSubmitProgress(Self, Progress);
      end);
end;

procedure TFeedbackManager.DoNotification(ANotification: TUserNotification);
begin
  if Assigned(FOnNotification) then
    TThread.Synchronize(TThread.Current,
      procedure
      begin
        FOnNotification(Self, ANotification);
      end);
end;

function TFeedbackManager.GenerateFeedbackId: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := GUIDToString(GUID);
end;

function TFeedbackManager.GenerateTrackingCode: string;
begin
  // ����6λ�׶�׷����
  Result := FormatDateTime('yymmdd', Now) + '-' +
            Copy(THashMD5.GetHashString(FormatDateTime('hhnnsszzz', Now)), 1, 6).ToUpper;
end;

function TFeedbackManager.PackageAttachments(AFeedback: TFeedbackItem): string;
var
  LZip: TZipFile;
  LOutputPath: string;
  I: Integer;
begin
  Result := '';
  
  if AFeedback.Attachments.Count = 0 then
    Exit;
    
  LOutputPath := TPath.Combine(TPath.GetTempPath,
    'feedback_' + AFeedback.Id + '_attachments.zip');
    
  LZip := TZipFile.Create;
  try
    LZip.Open(LOutputPath, zmWrite);
    try
      for I := 0 to AFeedback.Attachments.Count - 1 do
      begin
        if TFile.Exists(AFeedback.Attachments[I].LocalPath) then
          LZip.Add(AFeedback.Attachments[I].LocalPath,
                   AFeedback.Attachments[I].FileName);
      end;
    finally
      LZip.Close;
    end;
    Result := LOutputPath;
  finally
    LZip.Free;
  end;
end;

function TFeedbackManager.InternalSubmit(AFeedback: TFeedbackItem): Boolean;
begin
  Result := False;
  
  // �Զ��ռ�ϵͳ��Ϣ
  if FConfig.EnableAutoSystemInfo then
    AFeedback.SystemInfo := TSystemInfoCollector.Collect;
    
  // �����û���Ϣ
  AFeedback.UserId := FConfig.UserId;
  AFeedback.UserEmail := FConfig.UserEmail;
  AFeedback.UserName := FConfig.UserName;
  
  // ����׷����
  if AFeedback.TrackingCode = '' then
    AFeedback.TrackingCode := GenerateTrackingCode;
    
  try
    // �ύ����
    Result := FClient.SubmitFeedback(AFeedback);
    
    if Result then
    begin
      AFeedback.IsSubmitted := True;
      AFeedback.SubmittedAt := Now;
    end;
  except
    // �ύʧ�ܣ��������߶���
    FOfflineQueue.Enqueue(AFeedback);
    Result := False;
  end;
end;

procedure TFeedbackManager.ProcessOfflineQueue;
var
  LFeedback: TFeedbackItem;
begin
  while not FOfflineQueue.IsEmpty do
  begin
    LFeedback := FOfflineQueue.Peek;
    if InternalSubmit(LFeedback) then
      FOfflineQueue.Dequeue
    else
      Break;  // ��Ȼʧ�ܣ�ֹͣ����
  end;
end;

procedure TFeedbackManager.PollNotifications;
var
  LNotifications: TObjectList<TUserNotification>;
  LNotif: TUserNotification;
begin
  try
    LNotifications := FClient.GetNotifications;
    try
      for LNotif in LNotifications do
      begin
        if not LNotif.IsRead then
          DoNotification(LNotif);
      end;
      
      FLock.Enter;
      try
        FNotifications.Clear;
        FNotifications.OwnsObjects := False;
        for LNotif in LNotifications do
          FNotifications.Add(LNotif);
        FNotifications.OwnsObjects := True;
        LNotifications.OwnsObjects := False;
      finally
        FLock.Leave;
      end;
    finally
      LNotifications.Free;
    end;
  except
    on E: Exception do
      {$IFDEF DEBUG}
      OutputDebugString(PChar('DeepBase.Feedback: Polling error: ' + E.Message));
      {$ENDIF}
  end;
end;

function TFeedbackManager.CreateFeedback(AType: TFeedbackType): TFeedbackItem;
begin
  Result := TFeedbackItem.Create;
  Result.FeedbackType := AType;
  Result.Id := GenerateFeedbackId;
  
  if FConfig.EnableAutoSystemInfo then
    Result.SystemInfo := TSystemInfoCollector.Collect;
end;

function TFeedbackManager.CreateBugReport(const ATitle, ADescription: string): TFeedbackItem;
begin
  Result := CreateFeedback(ftBug);
  Result.Title := ATitle;
  Result.Description := ADescription;
end;

function TFeedbackManager.CreateFeatureRequest(const ATitle, ADescription: string): TFeedbackItem;
begin
  Result := CreateFeedback(ftFeature);
  Result.Title := ATitle;
  Result.Description := ADescription;
end;

function TFeedbackManager.CreateCrashReport(const AException: Exception): TFeedbackItem;
begin
  Result := CreateFeedback(ftCrash);
  Result.Title := '�������: ' + AException.ClassName;
  Result.Description := AException.Message;
  Result.Priority := fpCritical;
  
  // �Զ�������־
  if FConfig.EnableAutoLogCollection then
    AddLogFiles(Result);
end;

function TFeedbackManager.Submit(AFeedback: TFeedbackItem): Boolean;
begin
  FLock.Enter;
  try
    Result := InternalSubmit(AFeedback);
    DoFeedbackSubmit(AFeedback, Result, '');
  finally
    FLock.Leave;
  end;
end;

procedure TFeedbackManager.SubmitAsync(AFeedback: TFeedbackItem);
begin
  FSubmitThread := TThread.CreateAnonymousThread(
    procedure
    var
      LSuccess: Boolean;
    begin
      FLock.Enter;
      try
        LSuccess := InternalSubmit(AFeedback);
        DoFeedbackSubmit(AFeedback, LSuccess, '');
      finally
        FLock.Leave;
      end;
    end);
  FSubmitThread.FreeOnTerminate := True;
  FSubmitThread.Start;
end;

function TFeedbackManager.SubmitQuickFeedback(const ATitle, ADescription: string;
  AType: TFeedbackType): string;
var
  LFeedback: TFeedbackItem;
begin
  LFeedback := CreateFeedback(AType);
  try
    LFeedback.Title := ATitle;
    LFeedback.Description := ADescription;
    
    if Submit(LFeedback) then
      Result := LFeedback.TrackingCode
    else
      Result := '';
  finally
    LFeedback.Free;
  end;
end;

function TFeedbackManager.AddScreenshot(AFeedback: TFeedbackItem): Boolean;
var
  LPath: string;
  LInfo: TAttachmentInfo;
begin
  LPath := TPath.Combine(TPath.GetTempPath,
    'screenshot_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.png');
    
  Result := TScreenshotCapture.CaptureScreen(LPath);
  if Result then
  begin
    LInfo := TAttachmentInfo.Create('screenshot.png', LPath);
    AFeedback.AddAttachment(LInfo);
  end;
end;

function TFeedbackManager.AddLogFiles(AFeedback: TFeedbackItem): Boolean;
var
  LPath: string;
  LInfo: TAttachmentInfo;
begin
  LPath := TPath.Combine(TPath.GetTempPath,
    'logs_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.zip');
    
  Result := FLogCollector.CollectLogs(LPath);
  if Result then
  begin
    LInfo := TAttachmentInfo.Create('logs.zip', LPath);
    AFeedback.AddAttachment(LInfo);
  end;
end;

function TFeedbackManager.AddFile(AFeedback: TFeedbackItem;
  const AFilePath: string): Boolean;
var
  LInfo: TAttachmentInfo;
  LFileSize: Int64;
begin
  Result := False;
  
  if not TFile.Exists(AFilePath) then
    Exit;
    
  LFileSize := TFile.GetSize(AFilePath);
  if LFileSize > Int64(FConfig.MaxAttachmentSizeMB) * 1024 * 1024 then
    Exit;
    
  LInfo := TAttachmentInfo.Create(TPath.GetFileName(AFilePath), AFilePath);
  AFeedback.AddAttachment(LInfo);
  Result := True;
end;

function TFeedbackManager.GetFeedback(const AFeedbackId: string): TFeedbackItem;
begin
  Result := FClient.GetFeedbackDetails(AFeedbackId);
end;

function TFeedbackManager.GetMyFeedbacks: TObjectList<TFeedbackItem>;
begin
  Result := FClient.GetMyFeedbacks;
end;

function TFeedbackManager.SearchByTrackingCode(const ACode: string): TFeedbackItem;
begin
  Result := FClient.SearchByTrackingCode(ACode);
end;

function TFeedbackManager.GetFeedbackStatus(const AFeedbackId: string): TFeedbackStatus;
begin
  Result := FClient.GetFeedbackStatus(AFeedbackId);
end;

function TFeedbackManager.GetComments(const AFeedbackId: string): TObjectList<TFeedbackComment>;
begin
  Result := FClient.GetComments(AFeedbackId);
end;

function TFeedbackManager.AddComment(const AFeedbackId, AContent: string): Boolean;
begin
  Result := FClient.AddComment(AFeedbackId, AContent);
end;

function TFeedbackManager.GetNotifications: TObjectList<TUserNotification>;
var
  I: Integer;
begin
  Result := TObjectList<TUserNotification>.Create(False);
  FLock.Enter;
  try
    for I := 0 to FNotifications.Count - 1 do
      Result.Add(FNotifications[I]);
  finally
    FLock.Leave;
  end;
end;

function TFeedbackManager.GetUnreadNotificationCount: Integer;
begin
  Result := FClient.GetUnreadCount;
end;

procedure TFeedbackManager.MarkNotificationRead(const ANotificationId: string);
begin
  FClient.MarkNotificationRead(ANotificationId);
end;

procedure TFeedbackManager.MarkAllNotificationsRead;
begin
  FClient.MarkAllNotificationsRead;
end;

procedure TFeedbackManager.StartNotificationPolling(AIntervalSeconds: Integer);
begin
  FPollingInterval := AIntervalSeconds;
  FPollingEnabled := True;
  
  FPollingThread := TThread.CreateAnonymousThread(
    procedure
    begin
      while not TThread.CurrentThread.CheckTerminated and FPollingEnabled do
      begin
        PollNotifications;
        Sleep(FPollingInterval * 1000);
      end;
    end);
  FPollingThread.FreeOnTerminate := True;
  FPollingThread.Start;
end;

procedure TFeedbackManager.StopNotificationPolling;
begin
  FPollingEnabled := False;
  if Assigned(FPollingThread) then
  begin
    FPollingThread.Terminate;
    FPollingThread := nil;
  end;
end;

procedure TFeedbackManager.ProcessOfflineQueueAsync;
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      FLock.Enter;
      try
        ProcessOfflineQueue;
      finally
        FLock.Leave;
      end;
    end).Start;
end;

function TFeedbackManager.GetOfflineQueueCount: Integer;
begin
  Result := FOfflineQueue.Count;
end;

function TFeedbackManager.GetSystemInfo: TSystemInfo;
begin
  Result := TSystemInfoCollector.Collect;
  Result.AppVersion := FConfig.AppVersion;
end;

procedure TFeedbackManager.AddLogPath(const APath: string);
begin
  FLogCollector.AddLogPath(APath);
end;

function TFeedbackManager.CollectLogs(const AOutputPath: string): Boolean;
begin
  Result := FLogCollector.CollectLogs(AOutputPath);
end;

{ TQuickFeedbackHelper }

class function TQuickFeedbackHelper.ShowBugReport(AManager: TFeedbackManager;
  const ATitle: string): string;
begin
  // ����Ӧ����ʾһ���Ի������û����룬��ʵ��ֱ���ύ
  Result := AManager.SubmitQuickFeedback(ATitle, '', ftBug);
end;

class function TQuickFeedbackHelper.ShowFeatureRequest(AManager: TFeedbackManager;
  const ATitle: string): string;
begin
  Result := AManager.SubmitQuickFeedback(ATitle, '', ftFeature);
end;

class function TQuickFeedbackHelper.ShowQuickFeedback(AManager: TFeedbackManager;
  AType: TFeedbackType): string;
begin
  Result := AManager.SubmitQuickFeedback('', '', AType);
end;

end.
