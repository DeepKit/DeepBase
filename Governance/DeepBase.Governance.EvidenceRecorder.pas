// AI-GENERATED
// DeepBase.Governance.EvidenceRecorder.pas
// 第四层：证据记录（异步写入，风险分层，脱敏，失败回调）
// 依赖 Interfaces + EvidenceRecorder
// P0 修复项：
//   - 添加 CorrelationId 字段（为 P08 ActionRun 预留）
//   - RiskLevel 从 Action/Gate 获取，不再硬编码 rlL1
//   - InputSummary 采用白名单脱敏，不直接截取完整 JSON
//   - 写入失败不再静默吞掉，支持错误回调 + 内存失败队列
//   - DATA2-006: PushItem 返回值必须检查，失败时重试 + 丢弃计数

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
  /// <remarks>
  /// DATA2-006 修复：PushItem 返回值必须检查。队列满时重试 3 次（100/200/400 ms
  /// 指数退避），全部失败则递增 DroppedEvidenceCount 并输出调试日志。
  /// </remarks>
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
    FDroppedEvidenceCount: Integer;   // DATA2-006：丢弃证据计数
    procedure ProcessQueue;
    procedure SaveWithRetry(const AEntry: TEvidenceEntry);
    procedure EnqueueEntry(const AEntry: TEvidenceEntry);
    function BackoffDelayWithJitter(ABaseMs: Integer): Integer;
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

    /// <summary>DATA2-006: 因队列满且重试耗尽而丢弃的证据总数</summary>
    property DroppedEvidenceCount: Integer read FDroppedEvidenceCount;

    // 同步刷新（测试用）
    procedure Flush;
  end;

implementation

uses
  System.DateUtils,
  Winapi.Windows;

const
  // 默认白名单：只保留结构性字段，排除可能的敏感数据
  DEFAULT_SANITIZE_WHITELIST: array[0..6] of string = (
    'action_key', 'gate_key', 'user_id', 'correlation_id',
    'tenant_id', 'request_id', 'risk_level'
  );

  // DATA2-006: 入队重试参数（指数退避基值，实际 Sleep 加 ±30% 抖动）
  PUSH_RETRY_DELAYS: array[0..2] of Integer = (100, 200, 400);

  // GOV-R3-005 (D-005): 退避抖动幅度 ±30%，避免高并发失败时所有线程同步重试形成风暴
  BACKOFF_JITTER_PCT = 30;

  // GOV-R3-005 (D-005): Flush 上限与超时，防止析构时队列满 1000 条阻塞数百秒
  FLUSH_MAX_ITEMS = 500;        // 单次 Flush 最多处理条数，余量交后台线程/下次 Flush
  FLUSH_TOTAL_TIMEOUT_MS = 5000; // Flush 总预算（含 SaveWithRetry 退避），超时即停

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
  FDroppedEvidenceCount := 0;

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

{ GOV-R3-005 (D-005): 对退避基值加 ±30% 抖动，避免高并发失败时所有线程同步重试形成风暴。
  以 GetTickCount 低 16 位作伪随机源（确定性、无线程全局锁开销），不依赖 Randomize。 }
function TEvidenceRecorder.BackoffDelayWithJitter(ABaseMs: Integer): Integer;
var
  LTick: Cardinal;
  LJitterRange: Integer;
begin
  if ABaseMs <= 0 then
    Exit(ABaseMs);
  LTick := GetTickCount and $FFFF;          // 0..65535
  LJitterRange := (ABaseMs * BACKOFF_JITTER_PCT) div 100;  // ±30% 幅度
  // 将 LTick 映射到 [-LJitterRange, +LJitterRange]
  Result := ABaseMs - LJitterRange + (Integer(LTick mod Cardinal(2 * LJitterRange + 1)));
end;

{ DATA2-006: 入队时检查 PushItem 返回值，队列满则指数退避重试 }
procedure TEvidenceRecorder.EnqueueEntry(const AEntry: TEvidenceEntry);
var
  LWaitResult: TWaitResult;
  I: Integer;
begin
  // 首次尝试
  LWaitResult := FQueue.PushItem(AEntry);
  if LWaitResult = wrSignaled then
    Exit;

  // 队列可能已满，指数退避重试（D-005: 加 ±30% 抖动避免重试风暴）
  for I := Low(PUSH_RETRY_DELAYS) to High(PUSH_RETRY_DELAYS) do
  begin
    Sleep(BackoffDelayWithJitter(PUSH_RETRY_DELAYS[I]));
    if not FRunning then
      Break;
    LWaitResult := FQueue.PushItem(AEntry);
    if LWaitResult = wrSignaled then
      Exit;
  end;

  // 所有重试均失败 — 证据被丢弃
  TInterlocked.Increment(FDroppedEvidenceCount);
  OutputDebugString(
    PChar('[Governance] Evidence DROPPED after retries — queue full. ' +
    'EntryId=' + AEntry.Id + ', ActionKey=' + AEntry.ActionKey +
    '. Total dropped=' + IntToStr(FDroppedEvidenceCount)));
end;

{ DATA2-006: 持久化写入，带重试 }
procedure TEvidenceRecorder.SaveWithRetry(const AEntry: TEvidenceEntry);
var
  I: Integer;
  LLastError: string;
begin
  if FStore = nil then
    Exit;

  for I := Low(PUSH_RETRY_DELAYS) to High(PUSH_RETRY_DELAYS) do
  begin
    try
      FStore.Save(AEntry);
      Exit; // 成功
    except
      on E: Exception do
      begin
        LLastError := E.ClassName + ': ' + E.Message;
        // D-005: 加 ±30% 抖动，避免高并发失败时所有线程同步重试形成风暴
        if I < High(PUSH_RETRY_DELAYS) then
          Sleep(BackoffDelayWithJitter(PUSH_RETRY_DELAYS[I]));
      end;
    end;
  end;

  // 所有重试均失败
  OutputDebugString(
    PChar('[Governance] Evidence SAVE FAILED after retries — EntryId=' +
    AEntry.Id + ', Error=' + LLastError));

  // 进入失败队列（供后续诊断）
  FFailureQueue.PushItem(AEntry);

  // 触发回调
  if Assigned(FFailureCallback) then
  begin
    try
      FFailureCallback(AEntry, LLastError);
    except
      // 回调本身失败也不影响后续 Evidence 处理
    end;
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

  // DATA2-006: 检查入队结果，失败时重试
  EnqueueEntry(LEntry);
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

  // DATA2-006: 检查入队结果，失败时重试
  EnqueueEntry(LEntry);
end;

procedure TEvidenceRecorder.ProcessQueue;
var
  LEntry: TEvidenceEntry;
  LWaitResult: TWaitResult;
begin
  while FRunning and not TThread.Current.CheckTerminated do
  begin
    LWaitResult := FQueue.PopItem(LEntry);
    if LWaitResult = wrSignaled then
    begin
      // DATA2-006: 持久化写入带重试
      SaveWithRetry(LEntry);
    end;
  end;
end;

procedure TEvidenceRecorder.Flush;
var
  LEntry: TEvidenceEntry;
  LWaitResult: TWaitResult;
  LProcessed: Integer;
  LStartTick: Cardinal;
  LElapsed: Cardinal;
begin
  // GOV-R3-005 (D-005): 析构同步 Flush 队列满 1000 条可阻塞数百秒
  //   —— 加单次上限与总超时，余量交后台线程（FRunning 期）或下次 Flush。
  //   超时后剩余证据项留在队列，待后台线程处理；析构路径若队列非空仍会清队列释放条目（无泄漏）。
  LProcessed := 0;
  LStartTick := GetTickCount;
  repeat
    LWaitResult := FQueue.PopItem(LEntry);
    if LWaitResult = wrSignaled then
    begin
      // DATA2-006: 持久化写入带重试
      SaveWithRetry(LEntry);
      Inc(LProcessed);
      if LProcessed >= FLUSH_MAX_ITEMS then
        Break;
      // 卡死 32 位计数器回绕保护
      LElapsed := GetTickCount - LStartTick;
      if LElapsed >= FLUSH_TOTAL_TIMEOUT_MS then
        Break;
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
