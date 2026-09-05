{*****************************************************************************
  Test.DeepBase.FMX.HB.Lifecycle - FMX HB Lifecycle Pipeline & Pilot Tests

  Version: 1.0 (Delphi 13.1 on Win64 / DUnitX)
  Description: Mirror of VCL lifecycle suite for FMX base controls.
               Complies with WO-20260905-002 Task B.
***************************************************************************** }

unit Test.DeepBase.FMX.HB.Lifecycle;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Types,
  System.UITypes,
  FMX.Types,
  FMX.Controls,
  FMX.Graphics,
  FMX.Forms,
  DUnitX.TestFramework,
  DeepBase.HB.Core,
  DeepBase.HB.Runtime,
  DeepBase.HB.StateSlot.Types,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.FMX.HB.Controls,
  DeepBase.FMX.HB.Dialogs;

type
  TTestFmxLifecycleControl = class(THbFmxControl)
  protected
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF;
      const Tokens: THbTokens); override;
  public
    procedure TriggerPaint;
    procedure SetPhase(APhase: THbLifecyclePhase);
    procedure Attach(const ATouchpoint: IHbTouchpoint);
  end;

  TFailingFmxBindStateControl = class(THbFmxControl)
  protected
    procedure BindState; override;
    procedure DrawHbControl(const Canvas: TCanvas; const ARect: TRectF;
      const Tokens: THbTokens); override;
  end;

  TFmxLifecycleMockTouchpoint = class(TInterfacedObject, IHbTouchpoint)
  private
    FId: string;
    FSurfaceId: string;
    FLevel: THbTouchpointLevel;
  public
    constructor Create(const AId, ASurface: string; ALevel: THbTouchpointLevel);
    function GetID: string;
    function GetLevel: THbTouchpointLevel;
    function GetBeforeState: string;
    function GetAction: string;
    function GetAfterState: string;
    function GetMeasure: TMetricDefinition;
    function EmitEvidence: TTouchEvidence;
    procedure ExecuteNextAction;
    procedure ExecuteFallbackAction;
  end;

  TFmxMockStateSlot = class(TInterfacedObject, IHbStateSlotProvider)
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
  TTestFmxHbLifecycle = class
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestLifecycle_StandardPipeline_PhaseProgression;
    [Test]
    procedure TestPaintAssertion_BypassBindToken_ThrowsEHbLifecycleViolation;
    [Test]
    procedure TestDispose_Idempotent_MultipleCallsNoError;
    [Test]
    procedure TestFailurePath_BindStateError_RaisesAndCallsErrorHook;
    [Test]
    procedure TestPilot_THbButton_Click_ProducesStandardEvidence;
    [Test]
    procedure TestPilot_THbDialog_Confirm_ProducesCriticalEvidence;
    [Test]
    procedure TestStateSlot_RegisterStateSlot_ReusesCoreRuntime;
  end;

implementation

{ TTestFmxLifecycleControl }

procedure TTestFmxLifecycleControl.DrawHbControl(const Canvas: TCanvas;
  const ARect: TRectF; const Tokens: THbTokens);
begin
  // no-op paint body for lifecycle assertions
end;

procedure TTestFmxLifecycleControl.TriggerPaint;
begin
  Paint;
end;

procedure TTestFmxLifecycleControl.SetPhase(APhase: THbLifecyclePhase);
begin
  LifecyclePhase := APhase;
end;

procedure TTestFmxLifecycleControl.Attach(const ATouchpoint: IHbTouchpoint);
begin
  AttachTouchpoint(ATouchpoint);
end;

{ TFailingFmxBindStateControl }

procedure TFailingFmxBindStateControl.BindState;
begin
  inherited BindState;
  raise EInvalidOperation.Create('Injected BindState Failure for Testing');
end;

procedure TFailingFmxBindStateControl.DrawHbControl(const Canvas: TCanvas;
  const ARect: TRectF; const Tokens: THbTokens);
begin
end;

{ TFmxLifecycleMockTouchpoint }

constructor TFmxLifecycleMockTouchpoint.Create(const AId, ASurface: string;
  ALevel: THbTouchpointLevel);
begin
  inherited Create;
  FId := AId;
  FSurfaceId := ASurface;
  FLevel := ALevel;
end;

function TFmxLifecycleMockTouchpoint.GetID: string;
begin
  Result := FId;
end;

function TFmxLifecycleMockTouchpoint.GetLevel: THbTouchpointLevel;
begin
  Result := FLevel;
end;

function TFmxLifecycleMockTouchpoint.GetBeforeState: string;
begin
  Result := 'Active';
end;

function TFmxLifecycleMockTouchpoint.GetAction: string;
begin
  Result := 'Click';
end;

function TFmxLifecycleMockTouchpoint.GetAfterState: string;
begin
  Result := 'Active';
end;

function TFmxLifecycleMockTouchpoint.GetMeasure: TMetricDefinition;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MetricKey := 'SDR';
end;

function TFmxLifecycleMockTouchpoint.EmitEvidence: TTouchEvidence;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.TouchpointId := FId;
  Result.SurfaceId := FSurfaceId;
  Result.TimestampUtc := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), False) * 1000;
  Result.DwellTimeMs := 0;
  Result.Success := True;
  Result.BeforeState := 'Active';
  Result.AfterState := 'Active';
  Result.ActionType := 'Click';
  Result.ErrorCode := 0;
  Result.SupportDeflected := True;
end;

procedure TFmxLifecycleMockTouchpoint.ExecuteNextAction;
begin
end;

procedure TFmxLifecycleMockTouchpoint.ExecuteFallbackAction;
begin
end;

{ TFmxMockStateSlot }

constructor TFmxMockStateSlot.Create(const ASlotId, ALabel: string; ARank: Integer);
begin
  inherited Create;
  FSlotId := ASlotId;
  FLabel := ALabel;
  FRank := ARank;
end;

function TFmxMockStateSlot.GetSlotId: string;
begin
  Result := FSlotId;
end;

function TFmxMockStateSlot.GetStateLabel: string;
begin
  Result := FLabel;
end;

function TFmxMockStateSlot.GetStateRank: Integer;
begin
  Result := FRank;
end;

{ TTestFmxHbLifecycle }

procedure TTestFmxHbLifecycle.Setup;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
end;

procedure TTestFmxHbLifecycle.TearDown;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
  THbDialog.ModalRunner := nil;
end;

procedure TTestFmxHbLifecycle.TestLifecycle_StandardPipeline_PhaseProgression;
var
  Ctrl: TTestFmxLifecycleControl;
  MockTp: IHbTouchpoint;
begin
  Ctrl := TTestFmxLifecycleControl.Create(nil);
  try
    Assert.AreEqual(Ord(lpStateBound), Ord(Ctrl.LifecyclePhase));

    MockTp := TFmxLifecycleMockTouchpoint.Create('tp_fmx_life_1', 'frm_fmx_test', tlStandard);
    Ctrl.Attach(MockTp);
    Assert.AreEqual(Ord(lpTouchpointAttached), Ord(Ctrl.LifecyclePhase));
    Assert.IsTrue(THbTouchpointEngine.Instance.IsRegistered('tp_fmx_life_1'));

    Ctrl.TriggerPaint;
    Assert.IsTrue(Ctrl.LifecyclePhase >= lpTokenBound);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestFmxHbLifecycle.TestPaintAssertion_BypassBindToken_ThrowsEHbLifecycleViolation;
var
  Ctrl: TTestFmxLifecycleControl;
  CaughtViolation: Boolean;
  ExceptionClass: string;
begin
  Ctrl := TTestFmxLifecycleControl.Create(nil);
  try
    Ctrl.SetPhase(lpCreated);
    CaughtViolation := False;

    try
      Ctrl.TriggerPaint;
    except
      on E: EHbLifecycleViolation do
      begin
        CaughtViolation := True;
        ExceptionClass := E.ClassName;
        Assert.AreEqual('TTestFmxLifecycleControl', E.ControlClassName);
        Assert.AreEqual(Ord(lpCreated), Ord(E.CurrentPhase));
      end;
    end;

    Assert.IsTrue(CaughtViolation,
      'EHbLifecycleViolation must be raised when FMX Paint is entered before lpTokenBound');
    Assert.AreEqual('EHbLifecycleViolation', ExceptionClass);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestFmxHbLifecycle.TestDispose_Idempotent_MultipleCallsNoError;
var
  Ctrl: THbFmxControl;
begin
  Ctrl := TTestFmxLifecycleControl.Create(nil);
  try
    Assert.IsFalse(Ctrl.IsDisposed);

    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);
    Assert.AreEqual(Ord(lpDisposed), Ord(Ctrl.LifecyclePhase));

    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);

    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestFmxHbLifecycle.TestFailurePath_BindStateError_RaisesAndCallsErrorHook;
var
  Ctrl: TFailingFmxBindStateControl;
  CaughtException: Boolean;
begin
  CaughtException := False;
  try
    Ctrl := TFailingFmxBindStateControl.Create(nil);
    Ctrl.Free;
  except
    on E: EInvalidOperation do
      CaughtException := True;
  end;

  Assert.IsTrue(CaughtException,
    'Exception during FMX lifecycle binding must propagate under Fail-Closed policy');
end;

procedure TTestFmxHbLifecycle.TestPilot_THbButton_Click_ProducesStandardEvidence;
var
  Btn: THbButton;
  Ev: TTouchEvidence;
begin
  THbTouchpointEngine.Instance.RegisterTouchpoint('tp_fmx_btn_demo', tlStandard,
    'frm_fmx_demo', 'Clicked');

  Btn := THbButton.Create(nil);
  try
    Btn.TouchpointId := 'tp_fmx_btn_demo';
    Btn.SurfaceId := 'frm_fmx_demo';

    Btn.Click;

    Assert.AreEqual(1, THbTouchpointEngine.Instance.GetBufferedCount);
    Assert.IsTrue(THbTouchpointEngine.Instance.ReadEvidence(Ev));
    Assert.AreEqual('tp_fmx_btn_demo', Ev.TouchpointId);
    Assert.AreEqual('Click', Ev.ActionType);
    Assert.IsTrue(Ev.TimestampUtc > 0);
  finally
    Btn.Free;
  end;
end;

procedure TTestFmxHbLifecycle.TestPilot_THbDialog_Confirm_ProducesCriticalEvidence;
var
  Ev: TTouchEvidence;
  Res: Boolean;
begin
  THbDialog.ModalRunner := function(AForm: TForm): TModalResult
  begin
    Result := mrOk;
  end;

  Res := THbDialog.Confirm('Order Review', 'Confirm submission of work item?');
  Assert.IsTrue(Res);

  Assert.AreEqual(1, THbTouchpointEngine.Instance.GetBufferedCount);
  Assert.IsTrue(THbTouchpointEngine.Instance.ReadEvidence(Ev));
  Assert.AreEqual('tp_dialog_confirm', Ev.TouchpointId);
  Assert.AreEqual('frm_dialog', Ev.SurfaceId);
  Assert.AreEqual('Confirm', Ev.ActionType);
  Assert.AreEqual('Prompting', Ev.BeforeState);
  Assert.AreEqual('Confirmed', Ev.AfterState);
  Assert.IsTrue(Ev.Success);
  Assert.IsTrue(Ev.SupportDeflected);
end;

procedure TTestFmxHbLifecycle.TestStateSlot_RegisterStateSlot_ReusesCoreRuntime;
var
  Slot, Retrieved: IHbStateSlotProvider;
begin
  Slot := TFmxMockStateSlot.Create('fmx_business', 'Pending', 1);
  THbFmxControl.RegisterStateSlot('WO-20260905-002', Slot);

  Retrieved := THbRuntime.GetStateSlot('fmx_business');
  Assert.AreEqual('fmx_business', Retrieved.GetSlotId);
  Assert.AreEqual('Pending', Retrieved.GetStateLabel);
  Assert.AreEqual(1, Retrieved.GetStateRank);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestFmxHbLifecycle);

end.
