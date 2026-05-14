// AI-GENERATED
// DeepBase.Governance.Run.pas
// P08：运行实例层 — ActionRun / AbilityRun / BridgeCall / ExecutionAttempt

unit DeepBase.Governance.Run;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DeepBase.Governance.Types;

type
  TRunStatus = (
    rsRequested, rsRunning, rsSucceeded, rsFailed,
    rsCancelled, rsTimedOut, rsCompensating, rsCompleted
  );

  TActionRun = class
  private
    FId: string;
    FActionKey: string;
    FCorrelationId: string;
    FActorKey: string;
    FGateKey: string;
    FStatus: TRunStatus;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FErrorMessage: string;
  public
    constructor Create(const AActionKey, ACorrelationId, AActorKey, AGateKey: string);
    procedure Start;
    procedure Succeed;
    procedure Fail(const AError: string);
    procedure Cancel;
    function DurationMs: Int64;
    property Id: string read FId;
    property ActionKey: string read FActionKey;
    property CorrelationId: string read FCorrelationId;
    property ActorKey: string read FActorKey;
    property GateKey: string read FGateKey;
    property Status: TRunStatus read FStatus;
    property StartTime: TDateTime read FStartTime;
    property EndTime: TDateTime read FEndTime;
    property ErrorMessage: string read FErrorMessage;
  end;

  TBridgeCall = class
  private
    FId: string;
    FActionRunId: string;
    FBridgeKey: string;
    FStatus: TRunStatus;
    FStartTime: TDateTime;
    FEndTime: TDateTime;
    FErrorMessage: string;
  public
    constructor Create(const AActionRunId, ABridgeKey: string);
    procedure Start;
    procedure Succeed;
    procedure Fail(const AError: string);
    property Id: string read FId;
    property ActionRunId: string read FActionRunId;
    property BridgeKey: string read FBridgeKey;
    property Status: TRunStatus read FStatus;
  end;

  TExecutionAttempt = class
  private
    FId: string;
    FRunId: string;
    FAttemptNo: Integer;
    FTriggerReason: string;
    FStatus: TRunStatus;
    FErrorMessage: string;
  public
    constructor Create(const ARunId: string; AAttemptNo: Integer;
      const ATriggerReason: string);
    procedure Succeed;
    procedure Fail(const AError: string);
    property Id: string read FId;
    property RunId: string read FRunId;
    property AttemptNo: Integer read FAttemptNo;
    property TriggerReason: string read FTriggerReason;
    property Status: TRunStatus read FStatus;
  end;

  /// 运行实例注册表
  TRunRegistry = class
  private
    FActionRuns: TObjectList<TActionRun>;
    FBridgeCalls: TObjectList<TBridgeCall>;
    FAttempts: TObjectList<TExecutionAttempt>;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateActionRun(const AActionKey, ACorrelationId, AActorKey, AGateKey: string): TActionRun;
    function CreateBridgeCall(const AActionRunId, ABridgeKey: string): TBridgeCall;
    function CreateAttempt(const ARunId: string; AAttemptNo: Integer; const AReason: string): TExecutionAttempt;
    function FindActionRun(const AId: string): TActionRun;
    function FindByCorrelation(const ACorrelationId: string): TArray<TActionRun>;
    function ActionRunCount: Integer;
  end;

implementation

uses System.DateUtils;

{ TActionRun }

constructor TActionRun.Create(const AActionKey, ACorrelationId, AActorKey, AGateKey: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FActionKey := AActionKey;
  FCorrelationId := ACorrelationId;
  FActorKey := AActorKey;
  FGateKey := AGateKey;
  FStatus := rsRequested;
  FStartTime := 0;
  FEndTime := 0;
end;

procedure TActionRun.Start;
begin
  FStatus := rsRunning;
  FStartTime := Now;
end;

procedure TActionRun.Succeed;
begin
  FStatus := rsSucceeded;
  FEndTime := Now;
end;

procedure TActionRun.Fail(const AError: string);
begin
  FStatus := rsFailed;
  FEndTime := Now;
  FErrorMessage := AError;
end;

procedure TActionRun.Cancel;
begin
  FStatus := rsCancelled;
  FEndTime := Now;
end;

function TActionRun.DurationMs: Int64;
begin
  if (FStartTime > 0) and (FEndTime > 0) then
    Result := MilliSecondsBetween(FEndTime, FStartTime)
  else
    Result := 0;
end;

{ TBridgeCall }

constructor TBridgeCall.Create(const AActionRunId, ABridgeKey: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FActionRunId := AActionRunId;
  FBridgeKey := ABridgeKey;
  FStatus := rsRequested;
end;

procedure TBridgeCall.Start;
begin
  FStatus := rsRunning;
  FStartTime := Now;
end;

procedure TBridgeCall.Succeed;
begin
  FStatus := rsSucceeded;
  FEndTime := Now;
end;

procedure TBridgeCall.Fail(const AError: string);
begin
  FStatus := rsFailed;
  FEndTime := Now;
  FErrorMessage := AError;
end;

{ TExecutionAttempt }

constructor TExecutionAttempt.Create(const ARunId: string; AAttemptNo: Integer;
  const ATriggerReason: string);
begin
  inherited Create;
  FId := TGUID.NewGuid.ToString;
  FRunId := ARunId;
  FAttemptNo := AAttemptNo;
  FTriggerReason := ATriggerReason;
  FStatus := rsRunning;
end;

procedure TExecutionAttempt.Succeed;
begin
  FStatus := rsSucceeded;
end;

procedure TExecutionAttempt.Fail(const AError: string);
begin
  FStatus := rsFailed;
  FErrorMessage := AError;
end;

{ TRunRegistry }

constructor TRunRegistry.Create;
begin
  inherited Create;
  FActionRuns := TObjectList<TActionRun>.Create(True);
  FBridgeCalls := TObjectList<TBridgeCall>.Create(True);
  FAttempts := TObjectList<TExecutionAttempt>.Create(True);
end;

destructor TRunRegistry.Destroy;
begin
  FAttempts.Free;
  FBridgeCalls.Free;
  FActionRuns.Free;
  inherited;
end;

function TRunRegistry.CreateActionRun(const AActionKey, ACorrelationId,
  AActorKey, AGateKey: string): TActionRun;
begin
  Result := TActionRun.Create(AActionKey, ACorrelationId, AActorKey, AGateKey);
  FActionRuns.Add(Result);
end;

function TRunRegistry.CreateBridgeCall(const AActionRunId, ABridgeKey: string): TBridgeCall;
begin
  Result := TBridgeCall.Create(AActionRunId, ABridgeKey);
  FBridgeCalls.Add(Result);
end;

function TRunRegistry.CreateAttempt(const ARunId: string; AAttemptNo: Integer;
  const AReason: string): TExecutionAttempt;
begin
  Result := TExecutionAttempt.Create(ARunId, AAttemptNo, AReason);
  FAttempts.Add(Result);
end;

function TRunRegistry.FindActionRun(const AId: string): TActionRun;
var
  LRun: TActionRun;
begin
  for LRun in FActionRuns do
    if LRun.Id = AId then
      Exit(LRun);
  Result := nil;
end;

function TRunRegistry.FindByCorrelation(const ACorrelationId: string): TArray<TActionRun>;
var
  LList: TList<TActionRun>;
  LRun: TActionRun;
begin
  LList := TList<TActionRun>.Create;
  try
    for LRun in FActionRuns do
      if LRun.CorrelationId = ACorrelationId then
        LList.Add(LRun);
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRunRegistry.ActionRunCount: Integer;
begin
  Result := FActionRuns.Count;
end;

end.
