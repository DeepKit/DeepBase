// AI-GENERATED
// DeepBase.Governance.EvidenceRecorder.pas
// 第四层：证据记录（异步写入，风险分层，脱敏，失败回调）
// 依赖 Interfaces + Types
// P0 修复项：
//   - 添加 CorrelationId 字段（为 P08 ActionRun 预留）
//   - RiskLevel 从 Action/Gate 获取，不再硬编码 rlL1
//   - InputSummary 采用白名单脱敏，不直接截取完整 JSON
//   - 写入失败不再静默吞掉，支持错误回调 + 内存失败队列

unit DeepBase.Governance.EvidenceRecorder;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.Governance.Types,
  DeepBase.Governance.Interfaces;

type
  /// 证据记录项
  TEvidenceEntry = record
    Id: string;
    SchemaVersion: Integer;   // 证据格式版本，当前 P01 = 1
    CorrelationId: string;    // 关联 ID（P08 ActionRun 基座）
    Timestamp: TDateTime;
    UserId: string;
    ActionKey: string;
    RiskLevel: TRiskLevel;
    GatePath: string;
    InputSummary: string;     // 已脱敏摘要
    OutputSummary: string;
    Result: TEvidenceResult;
    BlockedReason: string;
    SnapshotData: string;
  end;

  /// Evidence Schema 迁移接口（P01 接口位，供后续 Phase 扩展时实现）
  IEvidenceMigrator = interface
    ['{F2A3B4C5-D6E7-8901-FABC-567890123456}']
    function Migrate(const AOldEntry: TEvidenceEntry;
      AFromVersion, AToVersion: Integer): TEvidenceEntry;
    function GetCurrentVersion: Integer;
  end;

  /// Context Schema 接口（P01 接口位，Phase P08 实现）
  IContextSchema = interface
    ['{A3B4C5D6-E7F8-9012-ABCD-678901234567}']
    function GetCaptureFields: TArray<string>;
    function GetSchemaVersion: Integer;
  end;

  /// 证据存储接口（持久化后端）
  IEvidenceStore = interface
    ['{F1A2B3C4-D5E6-7890-ABCD-EF1234567891}']
    procedure Save(const AEntry: TEvidenceEntry);
    function Query(const AActionKey: string; ALimit: Integer): TArray<TEvidenceEntry>;
  end;

  /// Evidence 写入失败回调（P0 修复：不再静默吞掉）
  TEvidenceFailureCallback = reference to procedure(
    const AEntry: TEvidenceEntry; const AError: string);

  /// 风险等级解析器（从 ActionKey 查询风险等级）
  TRiskLevelResolver = reference to function(
    const AActionKey: string): TRiskLevel;

  /// 证据记录器实现（异步写入，不阻塞 UI）
  TEvidenceRecorder = class(TInterfacedObject, IEvidenceRecorder)
  private
    FStore: IEvidenceStore;
    FQueue: TThreadedQueue<TEvidenceEntry>;
    FFailureQueue: TThreadedQueue<TEvidenceEntry>;  // P0：失败队列
    FWorkerThread: TThread;
    FRunning: Boolean;
    FFailureCallback: TEvidenceFailureCallback;
    FRiskResolver: TRiskLevelResolver;
    FSanitizeFields: TArray<string>;  // 白名单字段名，只有这些字段进入摘要
    procedure ProcessQueue;
    function GenerateId: string;
    function GetUserId(AContext: TJSONObject): string;
    function GetCorrelationId(AContext: TJSONObject): string;
    function ResolveRiskLevel(const AActionKey: string): TRiskLevel;
    function SanitizeInput(AContext: TJSONObject): string;
  public
    constructor Create(AStore: IEvidenceStore);
    destructor Destroy; override;

    // 配置项
    procedure SetFailureCallback(ACallback: TEvidenceFailureCallback);
    procedure SetRiskResolver(AResolver: TRiskLevelResolver);
    procedure SetSanitizeWhitelist(const AFields: TArray<string>);

    // IEvidenceRecorder
    procedure LogAction(const AActionKey: string; AContext: TJSONObject;
      AResult: TActionResult);
    procedure LogBlocked(const AGateKey: string; const AReason: string;
      AContext: TJSONObject);

    // 失败队列
    function GetFailedEntries: TArray<TEvidenceEntry>;
    function FailedCount: Integer;

    // 同步刷新（测试用）
    procedure Flush;
  end;

implementation

uses
  System.DateUtils;

const
  // 默认白名单：只保留结构性字段，排除可能的敏感数据
  DEFAULT_SANITIZE_WHITELIST: array[0..6] of string = (
    'action_key', 'gate_key', 'user_id', 'correlation_id',
    'tenant_id', 'request_id', 'risk_level'
  );

{ TEvidenceRecorder }

constructor TEvidenceRecorder.Create(AStore: IEvidenceStore);
var
  I: Integer;
begin
  inherited Create;
  FStore := AStore;
  FQueue := TThreadedQueue<TEvidenceEntry>.Create(1000, 100, 50);
  FFailureQueue := TThreadedQueue<TEvidenceEntry>.Create(100, 0, 0);
  FRunning := True;

  // 初始化默认白名单
  SetLength(FSanitizeFields, Length(DEFAULT_SANITIZE_WHITELIST));
  for I := 0 to High(DEFAULT_SANITIZE_WHITELIST) do
    FSanitizeFields[I] := DEFAULT_SANITIZE_WHITELIST[I];

  // 启动后台写入线程
  FWorkerThread := TThread.CreateAnonymousThread(ProcessQueue);
  FWorkerThread.FreeOnTerminate := False;
  FWorkerThread.Start;
end;

destructor TEvidenceRecorder.Destroy;
begin
  // GOV-020: Flush pending entries before tearing down the worker so queued
  // evidence is not silently lost.
  if FRunning then
  try
    Flush;
  except
    // Swallow flush errors — destructor must still complete teardown.
  end;
  FRunning := False;
  if FWorkerThread <> nil then
  begin
    FWorkerThread.Terminate;
    FWorkerThread.WaitFor;
    FWorkerThread.Free;
  end;
  FFailureQueue.Free;
  FQueue.Free;
  inherited;
end;

procedure TEvidenceRecorder.SetFailureCallback(ACallback: TEvidenceFailureCallback);
begin
  FFailureCallback := ACallback;
end;

procedure TEvidenceRecorder.SetRiskResolver(AResolver: TRiskLevelResolver);
begin
  FRiskResolver := AResolver;
end;

procedure TEvidenceRecorder.SetSanitizeWhitelist(const AFields: TArray<string>);
begin
  FSanitizeFields := AFields;
end;

function TEvidenceRecorder.GenerateId: string;
begin
  Result := TGUID.NewGuid.ToString;
end;

function TEvidenceRecorder.GetUserId(AContext: TJSONObject): string;
begin
  if (AContext <> nil) and (AContext.GetValue('user_id') <> nil) then
    Result := AContext.GetValue<string>('user_id', '')
  else
    Result := 'anonymous';
end;

function TEvidenceRecorder.GetCorrelationId(AContext: TJSONObject): string;
begin
  if (AContext <> nil) and (AContext.GetValue('correlation_id') <> nil) then
    Result := AContext.GetValue<string>('correlation_id', '')
  else
    // 无 correlation_id 时生成一个新的，保证 Evidence 可关联
    Result := TGUID.NewGuid.ToString;
end;

function TEvidenceRecorder.ResolveRiskLevel(const AActionKey: string): TRiskLevel;
begin
  if Assigned(FRiskResolver) then
    Result := FRiskResolver(AActionKey)
  else
    // 无 Resolver 时默认 L1（保守策略，宁可多记一些字段，也不要漏风险标注）
    Result := rlL1;
end;

function TEvidenceRecorder.SanitizeInput(AContext: TJSONObject): string;
var
  LSanitized: TJSONObject;
  LField: string;
  LValue: TJSONValue;
begin
  if AContext = nil then
    Exit('');

  // P0 修复：白名单脱敏，只保留配置过的字段
  // 不直接截取 AContext.ToJSON，避免把密码/令牌/身份证号等敏感字段写入证据数据库
  LSanitized := TJSONObject.Create;
  try
    for LField in FSanitizeFields do
    begin
      LValue := AContext.GetValue(LField);
      if LValue <> nil then
        LSanitized.AddPair(LField, LValue.Clone as TJSONValue);
    end;
    Result := LSanitized.ToJSON;
  finally
    LSanitized.Free;
  end;
end;

procedure TEvidenceRecorder.LogAction(const AActionKey: string;
  AContext: TJSONObject; AResult: TActionResult);
var
  LEntry: TEvidenceEntry;
begin
  LEntry.Id := GenerateId;
  LEntry.SchemaVersion := EvidenceSchemaVersion_P01;
  LEntry.CorrelationId := GetCorrelationId(AContext);
  LEntry.Timestamp := Now;
  LEntry.UserId := GetUserId(AContext);
  LEntry.ActionKey := AActionKey;
  LEntry.RiskLevel := ResolveRiskLevel(AActionKey);  // P0：不再硬编码
  LEntry.GatePath := '';
  LEntry.InputSummary := SanitizeInput(AContext);    // P0：白名单脱敏
  LEntry.OutputSummary := AResult.Message;
  LEntry.BlockedReason := '';
  LEntry.SnapshotData := '';

  case AResult.Status of
    arsSuccess: LEntry.Result := erSuccess;
    arsFail:    LEntry.Result := erFail;
    arsBlocked: LEntry.Result := erBlocked;
    arsDryRun:  LEntry.Result := erSuccess;
  end;

  FQueue.PushItem(LEntry);
end;

procedure TEvidenceRecorder.LogBlocked(const AGateKey, AReason: string;
  AContext: TJSONObject);
var
  LEntry: TEvidenceEntry;
begin
  LEntry.Id := GenerateId;
  LEntry.SchemaVersion := EvidenceSchemaVersion_P01;
  LEntry.CorrelationId := GetCorrelationId(AContext);
  LEntry.Timestamp := Now;
  LEntry.UserId := GetUserId(AContext);
  LEntry.ActionKey := AGateKey;
  LEntry.RiskLevel := ResolveRiskLevel(AGateKey);
  LEntry.GatePath := AGateKey;
  LEntry.InputSummary := SanitizeInput(AContext);
  LEntry.OutputSummary := '';
  LEntry.Result := erBlocked;
  LEntry.BlockedReason := AReason;
  LEntry.SnapshotData := '';

  FQueue.PushItem(LEntry);
end;

procedure TEvidenceRecorder.ProcessQueue;
var
  LEntry: TEvidenceEntry;
  LWaitResult: TWaitResult;
  LError: string;
begin
  while FRunning and not TThread.Current.CheckTerminated do
  begin
    LWaitResult := FQueue.PopItem(LEntry);
    if LWaitResult = wrSignaled then
    begin
      try
        if FStore <> nil then
          FStore.Save(LEntry);
      except
        on E: Exception do
        begin
          // P0 修复：写入失败不再静默吞掉
          LError := E.ClassName + ': ' + E.Message;

          // 1. 进入失败队列（供后续诊断/重试）
          FFailureQueue.PushItem(LEntry);

          // 2. 触发回调（如注册）
          if Assigned(FFailureCallback) then
          begin
            try
              FFailureCallback(LEntry, LError);
            except
              // 回调本身失败也不影响后续 Evidence 处理
            end;
          end;
        end;
      end;
    end;
  end;
end;

procedure TEvidenceRecorder.Flush;
var
  LEntry: TEvidenceEntry;
  LWaitResult: TWaitResult;
begin
  repeat
    LWaitResult := FQueue.PopItem(LEntry);
    if LWaitResult = wrSignaled then
    begin
      if FStore <> nil then
      begin
        try
          FStore.Save(LEntry);
        except
          on E: Exception do
          begin
            FFailureQueue.PushItem(LEntry);
            if Assigned(FFailureCallback) then
              FFailureCallback(LEntry, E.ClassName + ': ' + E.Message);
          end;
        end;
      end;
    end;
  until LWaitResult <> wrSignaled;
end;

function TEvidenceRecorder.GetFailedEntries: TArray<TEvidenceEntry>;
var
  LList: TList<TEvidenceEntry>;
  LEntry: TEvidenceEntry;
  LWaitResult: TWaitResult;
begin
  LList := TList<TEvidenceEntry>.Create;
  try
    repeat
      LWaitResult := FFailureQueue.PopItem(LEntry);
      if LWaitResult = wrSignaled then
        LList.Add(LEntry);
    until LWaitResult <> wrSignaled;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TEvidenceRecorder.FailedCount: Integer;
begin
  Result := FFailureQueue.QueueSize;
end;

end.
