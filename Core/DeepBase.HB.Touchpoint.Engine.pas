{ ============================================================================
  DeepBase.HB.Touchpoint.Engine - HB Touchpoint Registry & Sampling Engine

  Version: 2.0 (Delphi 13.1 on Win64 / Cross-Platform RTL)
  Description: Runtime engine for HB Touchpoints:
               - Thread-safe touchpoint registry.
               - 3-tier sampling policy (tlCritical full, tlStandard lightweight,
                 unregistered zero-cost).
               - Grid aggregated interaction batching (configurable threshold N).
               - In-memory ring buffer (capacity 10,000) using TRingBuffer<T>.
               Complies with docs/30.touchpoint.md v2.0 Section 2 & Section 6.
  ============================================================================ }

unit DeepBase.HB.Touchpoint.Engine;

{ IMPLICIT_STRING_CAST OFF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.Memory,
  DeepBase.HB.Touchpoint.Types;

type
  /// <summary>
  /// 触点登记项
  /// </summary>
  THbTouchpointRegistration = record
    TouchpointId: string;
    Level: THbTouchpointLevel;
    SurfaceId: string;
    TargetState: string;
    RegisteredAtUtc: Int64;
  end;

  /// <summary>
  /// Grid 聚合采样状态追踪器
  /// </summary>
  THbGridAggregator = record
    TouchpointId: string;
    SurfaceId: string;
    ActionType: string;
    AccumulatedCount: Integer;
    SuccessCount: Integer;
    FirstTimestampUtc: Int64;
    LastTimestampUtc: Int64;
  end;

  /// <summary>
  /// 触点登记与分级采样引擎
  /// </summary>
  THbTouchpointEngine = class
  private
    class var FInstance: THbTouchpointEngine;
    class var FLock: TCriticalSection;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  private
    FRegistryLock: TCriticalSection;
    FRegistry: TDictionary<string, THbTouchpointRegistration>;
    FBuffer: TRingBuffer<TTouchEvidence>;
    FAggregators: TDictionary<string, THbGridAggregator>;
    FAggregationThreshold: Integer;
    FSink: IHbTelemetrySink;
    FLastFlushUtc: Int64;
    FFlushThresholdCount: Integer;
    FFlushIntervalMs: Int64;

    procedure PushToBuffer(const AEvidence: TTouchEvidence);
  public
    constructor Create(ABufferCapacity: Integer = 10000; AAggregationThreshold: Integer = 50);
    destructor Destroy; override;

    // 单例访问
    class property Instance: THbTouchpointEngine read FInstance;

    // 持久化槽注入 (Sink)
    procedure SetSink(const ASink: IHbTelemetrySink);
    function GetSink: IHbTelemetrySink;
    procedure FlushSink;
    procedure CheckAutoFlush(ANowUtc: Int64 = 0);

    // 触点登记与注销
    procedure RegisterTouchpoint(const ATouchpoint: IHbTouchpoint); overload;
    procedure RegisterTouchpoint(const ATouchpointId: string; ALevel: THbTouchpointLevel;
      const ASurfaceId: string = ''; const ATargetState: string = ''); overload;
    procedure UnregisterTouchpoint(const ATouchpointId: string);
    function IsRegistered(const ATouchpointId: string): Boolean;
    function TryGetRegistration(const ATouchpointId: string; out AReg: THbTouchpointRegistration): Boolean;
    function GetRegisteredCount: Integer;

    // 分级上报 API (tlCritical: 全量 11 字段, tlStandard: 轻量 3 字段, 未登记: 拒绝/零开销)
    function RecordTouchpoint(const ATouchpoint: IHbTouchpoint): Boolean;
    function EmitEvidence(const AEvidence: TTouchEvidence): Boolean;

    // Grid 聚合采样 API (每 N 次同类行交互合并为一条聚合证据)
    procedure RecordGridInteraction(const ATouchpointId: string; const ASurfaceId: string = '';
      const AActionType: string = 'RowSelect'; ASuccess: Boolean = True);
    procedure FlushGridAggregations;

    // 环形缓冲查询与提取
    function GetBufferedCount: Integer;
    function GetBufferCapacity: Integer;
    function ReadEvidence(out AEvidence: TTouchEvidence): Boolean;
    function ReadAllBufferedEvidences: TArray<TTouchEvidence>;
    procedure ClearBuffer;
    procedure Reset;

    property AggregationThreshold: Integer read FAggregationThreshold write FAggregationThreshold;
    property FlushThresholdCount: Integer read FFlushThresholdCount write FFlushThresholdCount;
    property FlushIntervalMs: Int64 read FFlushIntervalMs write FFlushIntervalMs;
  end;

implementation

{ THbTouchpointEngine }

class constructor THbTouchpointEngine.ClassCreate;
begin
  FLock := TCriticalSection.Create;
  FInstance := THbTouchpointEngine.Create;
end;

class destructor THbTouchpointEngine.ClassDestroy;
begin
  FreeAndNil(FInstance);
  FreeAndNil(FLock);
end;

constructor THbTouchpointEngine.Create(ABufferCapacity: Integer; AAggregationThreshold: Integer);
begin
  inherited Create;
  FRegistryLock := TCriticalSection.Create;
  FRegistry := TDictionary<string, THbTouchpointRegistration>.Create;
  FBuffer := TRingBuffer<TTouchEvidence>.Create(ABufferCapacity);
  FAggregators := TDictionary<string, THbGridAggregator>.Create;
  FAggregationThreshold := AAggregationThreshold;
  if FAggregationThreshold <= 0 then
    FAggregationThreshold := 50;
  FSink := nil;
  FFlushThresholdCount := ABufferCapacity div 2;
  if FFlushThresholdCount <= 0 then
    FFlushThresholdCount := 5000;
  FFlushIntervalMs := 30000;
  FLastFlushUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
end;

destructor THbTouchpointEngine.Destroy;
begin
  FlushSink;
  FAggregators.Free;
  FBuffer.Free;
  FRegistry.Free;
  FRegistryLock.Free;
  inherited Destroy;
end;

procedure THbTouchpointEngine.SetSink(const ASink: IHbTelemetrySink);
begin
  FRegistryLock.Enter;
  try
    FSink := ASink;
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.GetSink: IHbTelemetrySink;
begin
  FRegistryLock.Enter;
  try
    Result := FSink;
  finally
    FRegistryLock.Leave;
  end;
end;

procedure THbTouchpointEngine.CheckAutoFlush(ANowUtc: Int64);
var
  ShouldFlush: Boolean;
  Items: TArray<TTouchEvidence>;
  Item: TTouchEvidence;
  List: TList<TTouchEvidence>;
  SinkRef: IHbTelemetrySink;
begin
  if FSink = nil then
    Exit;

  if ANowUtc <= 0 then
    ANowUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;

  FRegistryLock.Enter;
  try
    ShouldFlush := (FBuffer.Count >= FFlushThresholdCount) or
      (ANowUtc - FLastFlushUtc >= FFlushIntervalMs);

    if ShouldFlush and (FBuffer.Count > 0) then
    begin
      List := TList<TTouchEvidence>.Create;
      try
        while FBuffer.Read(Item) do
          List.Add(Item);
        Items := List.ToArray;
      finally
        List.Free;
      end;
      FLastFlushUtc := ANowUtc;
      SinkRef := FSink;
    end
    else
      SinkRef := nil;
  finally
    FRegistryLock.Leave;
  end;

  if (SinkRef <> nil) and (Length(Items) > 0) then
    SinkRef.PersistEvidence(Items);
end;

procedure THbTouchpointEngine.FlushSink;
var
  Items: TArray<TTouchEvidence>;
  Item: TTouchEvidence;
  List: TList<TTouchEvidence>;
  SinkRef: IHbTelemetrySink;
begin
  FlushGridAggregations;
  if FSink = nil then
    Exit;

  FRegistryLock.Enter;
  try
    SinkRef := FSink;
    List := TList<TTouchEvidence>.Create;
    try
      while FBuffer.Read(Item) do
        List.Add(Item);
      Items := List.ToArray;
    finally
      List.Free;
    end;
    FLastFlushUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
  finally
    FRegistryLock.Leave;
  end;

  if (SinkRef <> nil) then
  begin
    if Length(Items) > 0 then
      SinkRef.PersistEvidence(Items);
    SinkRef.Flush;
  end;
end;

procedure THbTouchpointEngine.PushToBuffer(const AEvidence: TTouchEvidence);
var
  Dummy: TTouchEvidence;
begin
  if FBuffer.IsFull then
    FBuffer.Read(Dummy);
  FBuffer.Write(AEvidence);
  CheckAutoFlush(AEvidence.TimestampUtc);
end;

procedure THbTouchpointEngine.RegisterTouchpoint(const ATouchpoint: IHbTouchpoint);
begin
  if ATouchpoint = nil then
    Exit;
  RegisterTouchpoint(ATouchpoint.GetID, ATouchpoint.GetLevel, '', ATouchpoint.GetAfterState);
end;

procedure THbTouchpointEngine.RegisterTouchpoint(const ATouchpointId: string; ALevel: THbTouchpointLevel;
  const ASurfaceId: string; const ATargetState: string);
var
  Id: string;
  Reg: THbTouchpointRegistration;
begin
  Id := ATouchpointId.Trim;
  if Id = '' then
    Exit;

  Reg.TouchpointId := Id;
  Reg.Level := ALevel;
  Reg.SurfaceId := ASurfaceId.Trim;
  Reg.TargetState := ATargetState.Trim;
  Reg.RegisteredAtUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;

  FRegistryLock.Enter;
  try
    FRegistry.AddOrSetValue(Id, Reg);
  finally
    FRegistryLock.Leave;
  end;
end;

procedure THbTouchpointEngine.UnregisterTouchpoint(const ATouchpointId: string);
begin
  FRegistryLock.Enter;
  try
    FRegistry.Remove(ATouchpointId.Trim);
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.IsRegistered(const ATouchpointId: string): Boolean;
begin
  FRegistryLock.Enter;
  try
    Result := FRegistry.ContainsKey(ATouchpointId.Trim);
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.TryGetRegistration(const ATouchpointId: string; out AReg: THbTouchpointRegistration): Boolean;
begin
  FRegistryLock.Enter;
  try
    Result := FRegistry.TryGetValue(ATouchpointId.Trim, AReg);
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.GetRegisteredCount: Integer;
begin
  FRegistryLock.Enter;
  try
    Result := FRegistry.Count;
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.RecordTouchpoint(const ATouchpoint: IHbTouchpoint): Boolean;
begin
  Result := False;
  if ATouchpoint = nil then
    Exit;
  Result := EmitEvidence(ATouchpoint.EmitEvidence);
end;

function THbTouchpointEngine.EmitEvidence(const AEvidence: TTouchEvidence): Boolean;
var
  Reg: THbTouchpointRegistration;
  FilteredEv: TTouchEvidence;
begin
  Result := False;
  if not TryGetRegistration(AEvidence.TouchpointId, Reg) then
    Exit; // 未在引擎登记元素 -> 零开销，引擎不得为非触点保留任何对象

  FRegistryLock.Enter;
  try
    case Reg.Level of
      tlCritical:
      begin
        // 全量 11 字段
        FilteredEv := AEvidence;
        if FilteredEv.TimestampUtc <= 0 then
          FilteredEv.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
        if (FilteredEv.SurfaceId = '') and (Reg.SurfaceId <> '') then
          FilteredEv.SurfaceId := Reg.SurfaceId;
        PushToBuffer(FilteredEv);
        Result := True;
      end;

      tlStandard:
      begin
        // 轻量证据：仅 TouchpointId + ActionType + TimestampUtc 三字段有效，其余零值/空值
        FillChar(FilteredEv, SizeOf(FilteredEv), 0);
        FilteredEv.TouchpointId := AEvidence.TouchpointId;
        FilteredEv.ActionType := AEvidence.ActionType;
        if AEvidence.TimestampUtc > 0 then
          FilteredEv.TimestampUtc := AEvidence.TimestampUtc
        else
          FilteredEv.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
        PushToBuffer(FilteredEv);
        Result := True;
      end;
    end;
  finally
    FRegistryLock.Leave;
  end;
end;

procedure THbTouchpointEngine.RecordGridInteraction(const ATouchpointId: string; const ASurfaceId: string;
  const AActionType: string; ASuccess: Boolean);
var
  Reg: THbTouchpointRegistration;
  Agg: THbGridAggregator;
  Ev: TTouchEvidence;
  NowUtc: Int64;
  Key: string;
begin
  if not TryGetRegistration(ATouchpointId, Reg) then
    Exit;

  NowUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
  Key := ATouchpointId.Trim + ':' + AActionType.Trim;

  FRegistryLock.Enter;
  try
    if not FAggregators.TryGetValue(Key, Agg) then
    begin
      Agg.TouchpointId := ATouchpointId.Trim;
      Agg.SurfaceId := ASurfaceId.Trim;
      if (Agg.SurfaceId = '') and (Reg.SurfaceId <> '') then
        Agg.SurfaceId := Reg.SurfaceId;
      Agg.ActionType := AActionType.Trim;
      Agg.AccumulatedCount := 0;
      Agg.SuccessCount := 0;
      Agg.FirstTimestampUtc := NowUtc;
      Agg.LastTimestampUtc := NowUtc;
    end;

    Inc(Agg.AccumulatedCount);
    if ASuccess then
      Inc(Agg.SuccessCount);
    Agg.LastTimestampUtc := NowUtc;

    if Agg.AccumulatedCount >= FAggregationThreshold then
    begin
      FillChar(Ev, SizeOf(Ev), 0);
      Ev.TouchpointId := Agg.TouchpointId;
      Ev.SurfaceId := Agg.SurfaceId;
      Ev.TimestampUtc := Agg.LastTimestampUtc;
      Ev.DwellTimeMs := Cardinal(Agg.LastTimestampUtc - Agg.FirstTimestampUtc);
      Ev.Success := (Agg.SuccessCount > 0);
      Ev.BeforeState := 'Aggregated';
      Ev.AfterState := 'Processed';
      Ev.ActionType := Format('GridAggregated:%d', [Agg.AccumulatedCount]);
      Ev.ErrorCode := 0;
      Ev.SupportDeflected := True;

      PushToBuffer(Ev);
      FAggregators.Remove(Key);
    end
    else
      FAggregators.AddOrSetValue(Key, Agg);
  finally
    FRegistryLock.Leave;
  end;
end;

procedure THbTouchpointEngine.FlushGridAggregations;
var
  Pair: TPair<string, THbGridAggregator>;
  Ev: TTouchEvidence;
begin
  FRegistryLock.Enter;
  try
    for Pair in FAggregators do
    begin
      if Pair.Value.AccumulatedCount > 0 then
      begin
        FillChar(Ev, SizeOf(Ev), 0);
        Ev.TouchpointId := Pair.Value.TouchpointId;
        Ev.SurfaceId := Pair.Value.SurfaceId;
        Ev.TimestampUtc := Pair.Value.LastTimestampUtc;
        Ev.DwellTimeMs := Cardinal(Pair.Value.LastTimestampUtc - Pair.Value.FirstTimestampUtc);
        Ev.Success := (Pair.Value.SuccessCount > 0);
        Ev.BeforeState := 'Aggregated';
        Ev.AfterState := 'Processed';
        Ev.ActionType := Format('GridAggregated:%d', [Pair.Value.AccumulatedCount]);
        Ev.ErrorCode := 0;
        Ev.SupportDeflected := True;
        PushToBuffer(Ev);
      end;
    end;
    FAggregators.Clear;
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.GetBufferedCount: Integer;
begin
  FRegistryLock.Enter;
  try
    Result := FBuffer.Count;
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.GetBufferCapacity: Integer;
begin
  Result := FBuffer.Capacity;
end;

function THbTouchpointEngine.ReadEvidence(out AEvidence: TTouchEvidence): Boolean;
begin
  FRegistryLock.Enter;
  try
    Result := FBuffer.Read(AEvidence);
  finally
    FRegistryLock.Leave;
  end;
end;

function THbTouchpointEngine.ReadAllBufferedEvidences: TArray<TTouchEvidence>;
var
  List: TList<TTouchEvidence>;
  Item: TTouchEvidence;
begin
  List := TList<TTouchEvidence>.Create;
  try
    FRegistryLock.Enter;
    try
      while FBuffer.Read(Item) do
        List.Add(Item);
    finally
      FRegistryLock.Leave;
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure THbTouchpointEngine.ClearBuffer;
begin
  FRegistryLock.Enter;
  try
    FBuffer.Clear;
  finally
    FRegistryLock.Leave;
  end;
end;

procedure THbTouchpointEngine.Reset;
begin
  FRegistryLock.Enter;
  try
    FRegistry.Clear;
    FBuffer.Clear;
    FAggregators.Clear;
    FSink := nil;
  finally
    FRegistryLock.Leave;
  end;
end;

end.
