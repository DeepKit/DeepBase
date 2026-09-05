{ ============================================================================
  Test.DeepBase.HB.Lifecycle - HB Control Lifecycle Pipeline & Exception Tests

  Version: 2.0 (Delphi 13.1 on Win64 / DUnitX)
  Description: Verification of THbCustomControl 7-step lifecycle pipeline,
               Paint pre-condition assertion (EHbLifecycleViolation),
               Dispose idempotency, failure path handling, and pilot touchpoint
               integrations on THbButton and THbDialog.
               Complies with WO-20260904-001 Task C2.
  ============================================================================ }

unit Test.DeepBase.HB.Lifecycle;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  Vcl.Controls,
  Vcl.Forms,
  DUnitX.TestFramework,
  DeepBase.HB.Core,
  DeepBase.HB.Runtime,
  DeepBase.HB.Lifecycle,
  DeepBase.HB.Touchpoint.Types,
  DeepBase.HB.Touchpoint.Engine,
  DeepBase.VCL.HB.Controls,
  DeepBase.VCL.HB.Dialogs;

type
  /// <summary>
  /// Test control exposed for testing protected lifecycle hooks
  /// </summary>
  TTestLifecycleControl = class(THbCustomControl)
  public
    procedure TriggerPaint;
    procedure SetPhase(APhase: THbLifecyclePhase);
    procedure CallHandleLifecycleError(const AStep: string; AException: Exception);
  end;

  /// <summary>
  /// Control that injects an exception during lifecycle BindState phase
  /// </summary>
  TFailingBindStateControl = class(THbCustomControl)
  protected
    procedure BindState; override;
  end;

  /// <summary>
  /// Mock Touchpoint for lifecycle testing
  /// </summary>
  TLifecycleMockTouchpoint = class(TInterfacedObject, IHbTouchpoint)
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

  [TestFixture]
  TTestHbLifecycle = class
  private
    FHookCalled: Boolean;
    procedure OnLifecycleErrorHandler(Sender: TObject; const AStep: string; AException: Exception);
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
    procedure TestFailurePath_CoreState_HandleError_EnforcesDispose_And_Idempotency;
    [Test]
    procedure TestFailurePath_VclControl_HandleLifecycleError_EnforcesDispose;
    [Test]
    procedure TestPilot_THbButton_Click_ProducesStandardEvidence;
    [Test]
    procedure TestPilot_THbDialog_Confirm_ProducesCriticalEvidence;
  end;

implementation

{ TTestLifecycleControl }

procedure TTestLifecycleControl.TriggerPaint;
begin
  Paint;
end;

procedure TTestLifecycleControl.SetPhase(APhase: THbLifecyclePhase);
begin
  LifecyclePhase := APhase;
end;

procedure TTestLifecycleControl.CallHandleLifecycleError(const AStep: string; AException: Exception);
begin
  HandleLifecycleError(AStep, AException);
end;

{ TFailingBindStateControl }

procedure TFailingBindStateControl.BindState;
begin
  inherited BindState;
  raise EInvalidOperation.Create('Injected BindState Failure for Testing');
end;

{ TLifecycleMockTouchpoint }

constructor TLifecycleMockTouchpoint.Create(const AId, ASurface: string; ALevel: THbTouchpointLevel);
begin
  inherited Create;
  FId := AId;
  FSurfaceId := ASurface;
  FLevel := ALevel;
end;

function TLifecycleMockTouchpoint.GetID: string;
begin
  Result := FId;
end;

function TLifecycleMockTouchpoint.GetLevel: THbTouchpointLevel;
begin
  Result := FLevel;
end;

function TLifecycleMockTouchpoint.GetBeforeState: string;
begin
  Result := 'Active';
end;

function TLifecycleMockTouchpoint.GetAction: string;
begin
  Result := 'Click';
end;

function TLifecycleMockTouchpoint.GetAfterState: string;
begin
  Result := 'Active';
end;

function TLifecycleMockTouchpoint.GetMeasure: TMetricDefinition;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.MetricKey := 'SDR';
end;

function TLifecycleMockTouchpoint.EmitEvidence: TTouchEvidence;
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

procedure TLifecycleMockTouchpoint.ExecuteNextAction;
begin
end;

procedure TLifecycleMockTouchpoint.ExecuteFallbackAction;
begin
end;

{ TTestHbLifecycle }

procedure TTestHbLifecycle.Setup;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
end;

procedure TTestHbLifecycle.TearDown;
begin
  THbTouchpointEngine.Instance.Reset;
  THbRuntime.ResetRegistry;
  THbDialog.ModalRunner := nil;
end;

procedure TTestHbLifecycle.TestLifecycle_StandardPipeline_PhaseProgression;
var
  Ctrl: TTestLifecycleControl;
  MockTp: IHbTouchpoint;
begin
  Ctrl := TTestLifecycleControl.Create(nil);
  try
    // 实例化后自动完成 BindToken 与 BindState (Phase >= lpStateBound)
    Assert.AreEqual(Ord(lpStateBound), Ord(Ctrl.LifecyclePhase));

    MockTp := TLifecycleMockTouchpoint.Create('tp_life_1', 'frm_test', tlStandard);
    Ctrl.AttachTouchpoint(MockTp);
    Assert.AreEqual(Ord(lpTouchpointAttached), Ord(Ctrl.LifecyclePhase));
    Assert.IsTrue(THbTouchpointEngine.Instance.IsRegistered('tp_life_1'));

    Ctrl.TriggerPaint;
    // Paint 顺利完成
    Assert.IsTrue(Ctrl.LifecyclePhase >= lpTokenBound);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestHbLifecycle.TestPaintAssertion_BypassBindToken_ThrowsEHbLifecycleViolation;
var
  Ctrl: TTestLifecycleControl;
  CaughtViolation: Boolean;
  ExceptionClass: string;
begin
  Ctrl := TTestLifecycleControl.Create(nil);
  try
    // 强制绕过生命周期初始化，模拟裸 Paint 违规
    Ctrl.SetPhase(lpCreated);
    CaughtViolation := False;

    try
      Ctrl.TriggerPaint;
    except
      on E: EHbLifecycleViolation do
      begin
        CaughtViolation := True;
        ExceptionClass := E.ClassName;
        Assert.AreEqual('TTestLifecycleControl', E.ControlClassName);
        Assert.AreEqual(Ord(lpCreated), Ord(E.CurrentPhase));
      end;
    end;

    Assert.IsTrue(CaughtViolation, 'EHbLifecycleViolation must be raised when Paint is entered before lpTokenBound');
    Assert.AreEqual('EHbLifecycleViolation', ExceptionClass);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestHbLifecycle.TestDispose_Idempotent_MultipleCallsNoError;
var
  Ctrl: THbCustomControl;
begin
  Ctrl := THbCustomControl.Create(nil);
  try
    Assert.IsFalse(Ctrl.IsDisposed);

    // 连续调用 3 次 DoDispose，验证幂等可重入契约
    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);
    Assert.AreEqual(Ord(lpDisposed), Ord(Ctrl.LifecyclePhase));

    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);

    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);
  finally
    // Destroy 内部再次调用 DoDispose，不应发生任何异常
    Ctrl.Free;
  end;
end;

procedure TTestHbLifecycle.TestFailurePath_BindStateError_RaisesAndCallsErrorHook;
var
  Ctrl: TFailingBindStateControl;
  CaughtException: Boolean;
begin
  CaughtException := False;
  try
    Ctrl := TFailingBindStateControl.Create(nil);
    Ctrl.Free;
  except
    on E: EInvalidOperation do
      CaughtException := True;
  end;

  Assert.IsTrue(CaughtException, 'Exception during lifecycle binding must propagate under Fail-Closed policy');
end;

procedure TTestHbLifecycle.TestFailurePath_CoreState_HandleError_EnforcesDispose_And_Idempotency;
var
  State: THbLifecycleState;
  HookCalled: Boolean;
  HookStep: string;
  HookExMsg: string;
  TestEx: Exception;
begin
  State.ResetCreated;
  State.BindToken;
  State.BindState;
  Assert.AreEqual(Ord(lpStateBound), Ord(State.Phase));
  Assert.IsFalse(State.IsDisposed);

  HookCalled := False;
  TestEx := Exception.Create('Core Lifecycle Test Error');
  try
    State.HandleError(
      procedure(const AStep: string; AEx: Exception)
      begin
        HookCalled := True;
        HookStep := AStep;
        HookExMsg := AEx.Message;
      end,
      'TestPhase',
      TestEx);

    Assert.IsTrue(HookCalled, 'Lifecycle error hook must be invoked');
    Assert.AreEqual('TestPhase', HookStep);
    Assert.AreEqual('Core Lifecycle Test Error', HookExMsg);
    Assert.IsTrue(State.IsDisposed, 'State must be disposed after HandleError');
    Assert.AreEqual(Ord(lpDisposed), Ord(State.Phase));

    // Multiple Dispose calls must be idempotent
    State.Dispose;
    Assert.IsTrue(State.IsDisposed);
    Assert.AreEqual(Ord(lpDisposed), Ord(State.Phase));
  finally
    TestEx.Free;
  end;
end;

procedure TTestHbLifecycle.OnLifecycleErrorHandler(Sender: TObject; const AStep: string; AException: Exception);
begin
  FHookCalled := True;
end;

procedure TTestHbLifecycle.TestFailurePath_VclControl_HandleLifecycleError_EnforcesDispose;
var
  Ctrl: TTestLifecycleControl;
  TestEx: Exception;
begin
  Ctrl := TTestLifecycleControl.Create(nil);
  try
    Assert.IsFalse(Ctrl.IsDisposed);
    FHookCalled := False;
    Ctrl.OnLifecycleError := OnLifecycleErrorHandler;

    TestEx := Exception.Create('VCL Lifecycle Test Exception');
    try
      Ctrl.CallHandleLifecycleError('VclRenderStep', TestEx);
    finally
      TestEx.Free;
    end;

    Assert.IsTrue(FHookCalled, 'Lifecycle error hook must be invoked on VCL control');
    Assert.IsTrue(Ctrl.IsDisposed, 'VCL Control must be marked Disposed after HandleLifecycleError');
    Assert.AreEqual(Ord(lpDisposed), Ord(Ctrl.LifecyclePhase));

    // Further DoDispose should be idempotent without error
    Ctrl.DoDispose;
    Assert.IsTrue(Ctrl.IsDisposed);
  finally
    Ctrl.Free;
  end;
end;

procedure TTestHbLifecycle.TestPilot_THbButton_Click_ProducesStandardEvidence;
var
  Btn: THbButton;
  Ev: TTouchEvidence;
begin
  THbTouchpointEngine.Instance.RegisterTouchpoint('tp_btn_demo', tlStandard, 'frm_demo', 'Clicked');

  Btn := THbButton.Create(nil);
  try
    Btn.TouchpointId := 'tp_btn_demo';
    Btn.SurfaceId := 'frm_demo';

    Btn.Click;

    Assert.AreEqual(1, THbTouchpointEngine.Instance.GetBufferedCount);
    Assert.IsTrue(THbTouchpointEngine.Instance.ReadEvidence(Ev));
    Assert.AreEqual('tp_btn_demo', Ev.TouchpointId);
    Assert.AreEqual('Click', Ev.ActionType);
    Assert.IsTrue(Ev.TimestampUtc > 0);
  finally
    Btn.Free;
  end;
end;

procedure TTestHbLifecycle.TestPilot_THbDialog_Confirm_ProducesCriticalEvidence;
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

initialization
  TDUnitX.RegisterTestFixture(TTestHbLifecycle);

end.
