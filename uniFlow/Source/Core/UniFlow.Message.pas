unit UniFlow.Message;

{*******************************************************************************
  UniFlow.Message - 消息基类定义
  
  描述：
    定义 UniFlow 角色间通信的消息基类和消息类型。
    所有角色间的通信都通过标准化消息进行。
    
  作者：鲁班（开发者）
  日期：2025-12-04
  版本：1.0
*******************************************************************************}

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;

type
  /// <summary>消息优先级</summary>
  TMessagePriority = (
    mpLow,      // 低优先级
    mpNormal,   // 普通优先级
    mpHigh,     // 高优先级
    mpCritical  // 紧急优先级
  );

  /// <summary>消息状态</summary>
  TMessageStatus = (
    msCreated,    // 已创建
    msQueued,     // 已入队
    msProcessing, // 处理中
    msCompleted,  // 已完成
    msFailed      // 已失败
  );

  /// <summary>UniFlow 消息基类</summary>
  TUniFlowMessage = class
  private
    FMsgId: string;
    FCorrelationId: string;
    FSource: string;
    FTarget: string;
    FMsgType: string;
    FPayload: TJSONObject;
    FTimestamp: TDateTime;
    FPriority: TMessagePriority;
    FStatus: TMessageStatus;
    FTraceId: string;
    FRetryCount: Integer;
    FMaxRetries: Integer;
  public
    constructor Create; overload;
    constructor Create(const AMsgType: string); overload;
    destructor Destroy; override;
    
    /// <summary>序列化为 JSON</summary>
    function ToJSON: TJSONObject;
    /// <summary>从 JSON 反序列化</summary>
    class function FromJSON(const AJSON: TJSONObject): TUniFlowMessage;
    /// <summary>克隆消息</summary>
    function Clone: TUniFlowMessage;
    
    /// <summary>消息ID（自动生成）</summary>
    property MsgId: string read FMsgId;
    /// <summary>关联ID（用于追踪请求-响应链）</summary>
    property CorrelationId: string read FCorrelationId write FCorrelationId;
    /// <summary>消息来源角色</summary>
    property Source: string read FSource write FSource;
    /// <summary>目标角色（空表示广播）</summary>
    property Target: string read FTarget write FTarget;
    /// <summary>消息类型</summary>
    property MsgType: string read FMsgType write FMsgType;
    /// <summary>消息负载</summary>
    property Payload: TJSONObject read FPayload write FPayload;
    /// <summary>创建时间戳</summary>
    property Timestamp: TDateTime read FTimestamp;
    /// <summary>优先级</summary>
    property Priority: TMessagePriority read FPriority write FPriority;
    /// <summary>状态</summary>
    property Status: TMessageStatus read FStatus write FStatus;
    /// <summary>追踪ID（跨服务追踪）</summary>
    property TraceId: string read FTraceId write FTraceId;
    /// <summary>重试次数</summary>
    property RetryCount: Integer read FRetryCount write FRetryCount;
    /// <summary>最大重试次数</summary>
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
  end;

  /// <summary>请求消息</summary>
  TRequestMessage = class(TUniFlowMessage)
  private
    FTimeout: Integer;
    FRequireResponse: Boolean;
  public
    constructor Create(const AMsgType: string);
    property Timeout: Integer read FTimeout write FTimeout;
    property RequireResponse: Boolean read FRequireResponse write FRequireResponse;
  end;

  /// <summary>响应消息</summary>
  TResponseMessage = class(TUniFlowMessage)
  private
    FSuccess: Boolean;
    FErrorCode: string;
    FErrorMessage: string;
  public
    constructor Create(const ARequest: TUniFlowMessage);
    property Success: Boolean read FSuccess write FSuccess;
    property ErrorCode: string read FErrorCode write FErrorCode;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
  end;

  /// <summary>事件消息（单向通知）</summary>
  TEventMessage = class(TUniFlowMessage)
  private
    FEventName: string;
  public
    constructor Create(const AEventName: string);
    property EventName: string read FEventName write FEventName;
  end;

/// <summary>生成唯一消息ID</summary>
function GenerateMsgId: string;
/// <summary>生成追踪ID</summary>
function GenerateTraceId: string;

implementation

uses
  System.DateUtils;

function GenerateMsgId: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := 'msg_' + Copy(GUIDToString(GUID), 2, 8);
end;

function GenerateTraceId: string;
var
  GUID: TGUID;
begin
  CreateGUID(GUID);
  Result := 'trace_' + Copy(GUIDToString(GUID), 2, 12);
end;

{ TUniFlowMessage }

constructor TUniFlowMessage.Create;
begin
  inherited Create;
  FMsgId := GenerateMsgId;
  FTimestamp := Now;
  FPriority := mpNormal;
  FStatus := msCreated;
  FRetryCount := 0;
  FMaxRetries := 3;
  FPayload := TJSONObject.Create;
end;

constructor TUniFlowMessage.Create(const AMsgType: string);
begin
  Create;
  FMsgType := AMsgType;
end;

destructor TUniFlowMessage.Destroy;
begin
  FPayload.Free;
  inherited;
end;

function TUniFlowMessage.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('msg_id', FMsgId);
  Result.AddPair('correlation_id', FCorrelationId);
  Result.AddPair('source', FSource);
  Result.AddPair('target', FTarget);
  Result.AddPair('msg_type', FMsgType);
  Result.AddPair('timestamp', DateToISO8601(FTimestamp));
  Result.AddPair('priority', Integer(FPriority));
  Result.AddPair('status', Integer(FStatus));
  Result.AddPair('trace_id', FTraceId);
  Result.AddPair('retry_count', FRetryCount);
  if Assigned(FPayload) then
    Result.AddPair('payload', FPayload.Clone as TJSONObject);
end;

class function TUniFlowMessage.FromJSON(const AJSON: TJSONObject): TUniFlowMessage;
begin
  Result := TUniFlowMessage.Create;
  // 解析基本字段
  if AJSON.TryGetValue<string>('correlation_id', Result.FCorrelationId) then;
  if AJSON.TryGetValue<string>('source', Result.FSource) then;
  if AJSON.TryGetValue<string>('target', Result.FTarget) then;
  if AJSON.TryGetValue<string>('msg_type', Result.FMsgType) then;
  if AJSON.TryGetValue<string>('trace_id', Result.FTraceId) then;
  
  var PayloadObj: TJSONObject;
  if AJSON.TryGetValue<TJSONObject>('payload', PayloadObj) then
  begin
    Result.FPayload.Free;
    Result.FPayload := PayloadObj.Clone as TJSONObject;
  end;
end;

function TUniFlowMessage.Clone: TUniFlowMessage;
begin
  Result := TUniFlowMessage.Create(FMsgType);
  Result.FCorrelationId := FCorrelationId;
  Result.FSource := FSource;
  Result.FTarget := FTarget;
  Result.FPriority := FPriority;
  Result.FTraceId := FTraceId;
  Result.FMaxRetries := FMaxRetries;
  if Assigned(FPayload) then
  begin
    Result.FPayload.Free;
    Result.FPayload := FPayload.Clone as TJSONObject;
  end;
end;

{ TRequestMessage }

constructor TRequestMessage.Create(const AMsgType: string);
begin
  inherited Create(AMsgType);
  FTimeout := 30000; // 默认30秒超时
  FRequireResponse := True;
end;

{ TResponseMessage }

constructor TResponseMessage.Create(const ARequest: TUniFlowMessage);
begin
  inherited Create('response');
  FCorrelationId := ARequest.MsgId;
  FTarget := ARequest.Source;
  FTraceId := ARequest.TraceId;
  FSuccess := True;
end;

{ TEventMessage }

constructor TEventMessage.Create(const AEventName: string);
begin
  inherited Create('event');
  FEventName := AEventName;
end;

end.
