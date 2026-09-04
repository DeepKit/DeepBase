{ ============================================================================
  Test.DeepBase.HB.Touchpoint - HB Touchpoint Contract, Registry & Anti-Pollution Tests

  Version: 2.0 (Delphi 13.1 on Win64 / DUnitX)
  Description: Verification of IHbTouchpoint, TTouchEvidence, THbTouchpointLevel,
               THbTouchpointEngine sampling policies, Grid aggregations,
               State slot registration with audit log, and Core anti-pollution text scanning.
               Complies with WO-20260904-001 Task C1.
  ============================================================================ }

unit Test.DeepBase.HB.Touchpoint;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.HB.StateSlot.Types,
  DeepBase.HB.Runtime;

type
  /// <summary>
  /// Mock Touchpoint implementation for contract verification
  /// </summary>
  TMockTouchpoint = class(TInterfacedObject, IHbTouchpoint)
  private
    FId: string;
    FSurfaceId: string;
    FLevel: THbTouchpointLevel;
    FBeforeState: string;
    FAction: string;
    FAfterState: string;
    FMeasure: TMetricDefinition;
    FNextActionExecuted: Boolean;
    FFallbackActionExecuted: Boolean;
  public
    constructor Create(const AId, ASurface: string; ALevel: THbTouchpointLevel;
      const ABefore, AAction, AAfter: string);

    function GetID: string;
    function GetLevel: THbTouchpointLevel;
    function GetBeforeState: string;
    function GetAction: string;
    function GetAfterState: string;
    function GetMeasure: TMetricDefinition;
    function EmitEvidence: TTouchEvidence;
    procedure ExecuteNextAction;
    procedure ExecuteFallbackAction;

    property NextActionExecuted: Boolean read FNextActionExecuted;
    property FallbackActionExecuted: Boolean read FFallbackActionExecuted;
  end;

  /// <summary>
  /// Mock State Slot provider for runtime slot tests
  /// </summary>
  TMockStateSlot = class(TInterfacedObject, IHbStateSlotProvider)
  private
    FSlotId: string;
    FLabel: string;
    FRank: Integer;
  public
    constructor Create(const ASlotId, ALabel: string; ARank: Integer);
    function GetSlotId: string;
    function GetStateLabel: string;
    function GetStateRank: Integer;
  end;

  [TestFixture]
  TTestHbTouchpoint = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestTouchpointContract_MethodsAndEvidence;
    [Test]
    procedure TestTouchpointLevel_CriticalFullEvidence;
    [Test]
    procedure TestTouchpointLevel_StandardLightweightEvidence;
    [Test]
    procedure TestTouchpointLevel_UnregisteredZeroCost;
    [Test]
    procedure TestGridAggregation_100kInteractions_ReducesEvidenceVolume;
    [Test]
    procedure TestStateSlot_Register_Override_AuditChain;
    [Test]
    procedure TestAntiPollution_CoreUnitsZeroBusinessEnums;
  end;

implementation

{ TMockTouchpoint }

constructor TMockTouchpoint.Create(const AId, ASurface: string; ALevel: THbTouchpointLevel;
  const ABefore, AAction, AAfter: string);
begin
  inherited Create;
  FId := AId;
  FSurfaceId := ASurface;
  FLevel := ALevel;
  FBeforeState := ABefore;
  FAction := AAction;
  FAfterState := AAfter;
  FNextActionExecuted := False;
  FFallbackActionExecuted := False;

  FMeasure.MetricKey := 'SDR';
  FMeasure.BaseValue := 0.20;
  FMeasure.TargetValue := 0.05;
  FMeasure.AchievedValue := 0.02;
end;

function TMockTouchpoint.GetID: string;
begin
  Result := FId;
end;

function TMockTouchpoint.GetLevel: THbTouchpointLevel;
begin
  Result := FLevel;
end;

function TMockTouchpoint.GetBeforeState: string;
begin
  Result := FBeforeState;
end;

function TMockTouchpoint.GetAction: string;
begin
  Result := FAction;
end;

function TMockTouchpoint.GetAfterState: string;
begin
  Result := FAfterState;
end;

function TMockTouchpoint.GetMeasure: TMetricDefinition;
begin
  Result := FMeasure;
end;

function TMockTouchpoint.EmitEvidence: TTouchEvidence;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TouchpointId := FId;
  Result.SurfaceId := FSurfaceId;
  Result.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
  Result.DwellTimeMs := 850;
  Result.Success := True;
  Result.BeforeState := FBeforeState;
  Result.AfterState := FAfterState;
  Result.ActionType := FAction;
  Result.ExitPosition := '';
  Result.ErrorCode := 0;
  Result.SupportDeflected := True;
end;

procedure TMockTouchpoint.ExecuteNextAction;
begin
  FNextActionExecuted := True;
end;

procedure TMockTouchpoint.ExecuteFallbackAction;
begin
  FFallbackActionExecuted := True;
end;

{ TMockStateSlot }

constructor TMockStateSlot.Create(const ASlotId, ALabel: string; ARank: Integer);
begin
  inherited Create;
  FSlotId := ASlotId;
  FLabel := ALabel;
  FRank := ARank;
end;

function TMockStateSlot.GetSlotId: string;
begin
  Result := FSlotId;
end;

function TMockStateSlot.GetStateLabel: string;
begin
  Result := FLabel;
end;

function TMockStateSlot.GetStateRank: Integer;
begin
  Result := FRank;
end;

{ TTestHbTouchpoint }

procedure TTestHbTouchpoint.Setup;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
end;

procedure TTestHbTouchpoint.TearDown;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
end;

procedure TTestHbTouchpoint.TestTouchpointContract_MethodsAndEvidence;
var
  Tp: IHbTouchpoint;
  MockTp: TMockTouchpoint;
  Ev: TTouchEvidence;
  Measure: TMetricDefinition;
begin
  MockTp := TMockTouchpoint.Create('tp_mock_1', 'frm_mock', tlCritical, 'Browsing', 'Confirm', 'StateCompleted');
  Tp := MockTp;

  Assert.AreEqual('tp_mock_1', Tp.GetID);
  Assert.AreEqual(Ord(tlCritical), Ord(Tp.GetLevel));
  Assert.AreEqual('Browsing', Tp.GetBeforeState);
  Assert.AreEqual('Confirm', Tp.GetAction);
  Assert.AreEqual('StateCompleted', Tp.GetAfterState);

  Measure := Tp.GetMeasure;
  Assert.AreEqual('SDR', Measure.MetricKey);
  Assert.AreEqual(0.20, Measure.BaseValue, 0.001);
  Assert.AreEqual(0.05, Measure.TargetValue, 0.001);

  Ev := Tp.EmitEvidence;
  Assert.AreEqual('tp_mock_1', Ev.TouchpointId);
  Assert.AreEqual('frm_mock', Ev.SurfaceId);
  Assert.AreEqual(Cardinal(850), Ev.DwellTimeMs);
  Assert.IsTrue(Ev.Success);
  Assert.AreEqual('Browsing', Ev.BeforeState);
  Assert.AreEqual('StateCompleted', Ev.AfterState);
  Assert.AreEqual('Confirm', Ev.ActionType);
  Assert.AreEqual(0, Ev.ErrorCode);
  Assert.IsTrue(Ev.SupportDeflected);

  Tp.ExecuteNextAction;
  Assert.IsTrue(MockTp.NextActionExecuted);

  Tp.ExecuteFallbackAction;
  Assert.IsTrue(MockTp.FallbackActionExecuted);
end;

procedure TTestHbTouchpoint.TestTouchpointLevel_CriticalFullEvidence;
var
  Engine: THbTouchpointEngine;
  EvIn, EvOut: TTouchEvidence;
begin
  Engine := THbTouchpointEngine.Instance;
  Engine.RegisterTouchpoint('tp_crit_order', tlCritical, 'frm_checkout', 'Paid');
  Assert.IsTrue(Engine.IsRegistered('tp_crit_order'));

  FillChar(EvIn, SizeOf(EvIn), 0);
  EvIn.TouchpointId := 'tp_crit_order';
  EvIn.SurfaceId := 'frm_checkout';
  EvIn.TimestampUtc := 1700000000000;
  EvIn.DwellTimeMs := 3400;
  EvIn.Success := True;
  EvIn.BeforeState := 'Unpaid';
  EvIn.AfterState := 'Paid';
  EvIn.ActionType := 'SubmitPayment';
  EvIn.ExitPosition := 'None';
  EvIn.ErrorCode := 0;
  EvIn.SupportDeflected := True;

  Assert.IsTrue(Engine.EmitEvidence(EvIn));
  Assert.AreEqual(1, Engine.GetBufferedCount);

  Assert.IsTrue(Engine.ReadEvidence(EvOut));
  Assert.AreEqual('tp_crit_order', EvOut.TouchpointId);
  Assert.AreEqual('frm_checkout', EvOut.SurfaceId);
  Assert.AreEqual(Int64(1700000000000), EvOut.TimestampUtc);
  Assert.AreEqual(Cardinal(3400), EvOut.DwellTimeMs);
  Assert.IsTrue(EvOut.Success);
  Assert.AreEqual('Unpaid', EvOut.BeforeState);
  Assert.AreEqual('Paid', EvOut.AfterState);
  Assert.AreEqual('SubmitPayment', EvOut.ActionType);
  Assert.AreEqual('None', EvOut.ExitPosition);
  Assert.AreEqual(0, EvOut.ErrorCode);
  Assert.IsTrue(EvOut.SupportDeflected);
end;

procedure TTestHbTouchpoint.TestTouchpointLevel_StandardLightweightEvidence;
var
  Engine: THbTouchpointEngine;
  EvIn, EvOut: TTouchEvidence;
begin
  Engine := THbTouchpointEngine.Instance;
  Engine.RegisterTouchpoint('tp_std_filter', tlStandard, 'frm_list', 'Filtered');
  Assert.IsTrue(Engine.IsRegistered('tp_std_filter'));

  FillChar(EvIn, SizeOf(EvIn), 0);
  EvIn.TouchpointId := 'tp_std_filter';
  EvIn.SurfaceId := 'frm_list';
  EvIn.TimestampUtc := 1700000001000;
  EvIn.DwellTimeMs := 1200;
  EvIn.Success := True;
  EvIn.BeforeState := 'All';
  EvIn.AfterState := 'Filtered';
  EvIn.ActionType := 'ChipToggle';
  EvIn.ExitPosition := 'Tab2';
  EvIn.ErrorCode := 0;
  EvIn.SupportDeflected := True;

  Assert.IsTrue(Engine.EmitEvidence(EvIn));
  Assert.AreEqual(1, Engine.GetBufferedCount);

  Assert.IsTrue(Engine.ReadEvidence(EvOut));
  // Standard 触点仅保留 TouchpointId, ActionType, TimestampUtc
  Assert.AreEqual('tp_std_filter', EvOut.TouchpointId);
  Assert.AreEqual('ChipToggle', EvOut.ActionType);
  Assert.AreEqual(Int64(1700000001000), EvOut.TimestampUtc);
  // 其余字段必须为默认零/空值（轻量开销保障）
  Assert.AreEqual('', EvOut.BeforeState);
  Assert.AreEqual('', EvOut.AfterState);
  Assert.AreEqual(Cardinal(0), EvOut.DwellTimeMs);
  Assert.AreEqual(0, EvOut.ErrorCode);
  Assert.IsFalse(EvOut.SupportDeflected);
end;

procedure TTestHbTouchpoint.TestTouchpointLevel_UnregisteredZeroCost;
var
  Engine: THbTouchpointEngine;
  EvIn: TTouchEvidence;
begin
  Engine := THbTouchpointEngine.Instance;
  FillChar(EvIn, SizeOf(EvIn), 0);
  EvIn.TouchpointId := 'tp_non_registered_button';
  EvIn.ActionType := 'Click';

  Assert.IsFalse(Engine.EmitEvidence(EvIn));
  Assert.AreEqual(0, Engine.GetBufferedCount);
end;

procedure TTestHbTouchpoint.TestGridAggregation_100kInteractions_ReducesEvidenceVolume;
var
  Engine: THbTouchpointEngine;
  I: Integer;
  Count: Integer;
begin
  Engine := THbTouchpointEngine.Instance;
  Engine.RegisterTouchpoint('tp_datagrid', tlStandard, 'frm_main', 'DataExplored');
  Engine.AggregationThreshold := 50;

  for I := 1 to 100000 do
    Engine.RecordGridInteraction('tp_datagrid', 'frm_main', 'RowSelect', True);

  Engine.FlushGridAggregations;
  Count := Engine.GetBufferedCount;

  // 100,000 次交互以 N=50 聚合，必须产生恰好 2000 条聚合证据 (<= ceil(100000/50))
  Assert.IsTrue(Count <= 2000, Format('Expected <= 2000 aggregated evidences, but got %d', [Count]));
  Assert.AreEqual(2000, Count);
end;

procedure TTestHbTouchpoint.TestStateSlot_Register_Override_AuditChain;
var
  Slot1, Slot2, Retrieved: IHbStateSlotProvider;
  SlotIds: TArray<string>;
  Audit: TArray<THbStateSlotAuditRecord>;
begin
  THbRuntime.ResetRegistry;

  Slot1 := TMockStateSlot.Create('business', 'PendingReview', 1);
  THbRuntime.RegisterStateSlot('WO-20260904-001', Slot1);

  SlotIds := THbRuntime.GetRegisteredSlotIds;
  Assert.AreEqual(1, Integer(Length(SlotIds)));
  Assert.AreEqual('business', SlotIds[0]);

  Retrieved := THbRuntime.GetStateSlot('business');
  Assert.IsNotNull(Retrieved);
  Assert.AreEqual('PendingReview', Retrieved.GetStateLabel);
  Assert.AreEqual(1, Retrieved.GetStateRank);

  Audit := THbRuntime.GetStateSlotAuditLog;
  Assert.AreEqual(1, Integer(Length(Audit)));
  Assert.AreEqual('WO-20260904-001', Audit[0].WorkOrder);
  Assert.AreEqual('business', Audit[0].SlotId);

  // 重复 SlotId 注册：后注册覆盖并记录审计链，不抛异常
  Slot2 := TMockStateSlot.Create('business', 'Approved', 2);
  THbRuntime.RegisterStateSlot('WO-20260904-002', Slot2);

  Retrieved := THbRuntime.GetStateSlot('business');
  Assert.AreEqual('Approved', Retrieved.GetStateLabel);
  Assert.AreEqual(2, Retrieved.GetStateRank);

  Audit := THbRuntime.GetStateSlotAuditLog;
  Assert.AreEqual(2, Integer(Length(Audit)));
  Assert.AreEqual('WO-20260904-002', Audit[1].WorkOrder);
end;

procedure TTestHbTouchpoint.TestAntiPollution_CoreUnitsZeroBusinessEnums;
var
  CoreDir: string;
  Files: TArray<string>;
  FileName, FileContent: string;
  BannedTokens: TArray<string>;
  BannedToken: string;
  ViolationFound: Boolean;
  Violations: TStringList;
begin
  // 扫描 Core 目录下所有 DeepBase.HB.*.pas 源文件，确保零业务枚举污染
  CoreDir := TPath.Combine(TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\')), 'Core');
  if not TDirectory.Exists(CoreDir) then
    CoreDir := 'D:\_Progs\02Business\DeepBase\Core';

  Assert.IsTrue(TDirectory.Exists(CoreDir), 'Core directory must exist for anti-pollution scan');

  Files := TDirectory.GetFiles(CoreDir, 'DeepBase.HB.*.pas');
  Assert.IsTrue(Length(Files) > 0, 'Must find DeepBase.HB.*.pas files in Core');

  BannedTokens := ['bsNeedFollowUp', 'bsHighValue', 'tsMedium', 'bsCritical', 'bsPendingReview'];
  Violations := TStringList.Create;
  try
    for FileName in Files do
    begin
      FileContent := TFile.ReadAllText(FileName);
      for BannedToken in BannedTokens do
      begin
        if FileContent.Contains(BannedToken) then
          Violations.Add(Format('Unit [%s] contains banned business token [%s]', [TPath.GetFileName(FileName), BannedToken]));
      end;
    end;

    ViolationFound := Violations.Count > 0;
    Assert.IsFalse(ViolationFound, 'Anti-pollution violation detected in Core layer: ' + Violations.Text);
  finally
    Violations.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestHbTouchpoint);

end.
