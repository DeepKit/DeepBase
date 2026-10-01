unit Test.DeepBase.DataBindingUnbindRefCount;
{
  WO-20260925-AUDIT-甲-A5 / A5-R01 回归单元。

  被测缺陷：TBindingManager 的退订原先按「绑定条目」逐条调用
  RemovePropertyChangedHandler，而 TObservableObject.AddPropertyChangedHandler 对
  同一 handler 去重（一个源在同一个 manager 内只登记一份订阅）⇒ 同源两条绑定解绑
  其中一条时，退订的是那份共享订阅，存活的兄弟绑定静默失效
  （BindingCount 仍在，通知不再传播）。修法为「按源引用计数退订」。

  判据来源：甲 A4 的 A4-01 探针 S2（`CodeReview/20260925-AUDIT-甲-A4-证据/附件/A401_Databinding.dpr.template`）。
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  DUnitX.TestFramework,
  DeepBase.DataBinding;

type

  {$M+}
  // A16 落笔②裁定 Q2：Bind 的 target 面只接受可登记对象 ⇒ 替身换基类为 TComponent，
  // 七个用例的断言内容、计数与限定名一字未改。无主 Create 保住原 7 处 .Create 调用点。
  TUnbindProbeTarget = class(TComponent)
  private
    FText: string;
  published
    property Text: string read FText write FText;
  public
    constructor Create; reintroduce;
  end;

  TUnbindProbeSource = class(TObservableObject)
  private
    FName: string;
    procedure SetName(const Value: string);
  published
    property Name: string read FName write SetName;
  end;

  [TestFixture]
  TDataBindingUnbindRefCount = class
  public
    [Test]
    procedure SiblingBinding_StillUpdatesAfterUnbindOfOther;

    [Test]
    procedure LastBindingForSource_UnsubscribesAndStopsUpdating;

    [Test]
    procedure UnbindObject_TargetSide_KeepsSiblingSubscription;

    [Test]
    procedure ThreeSiblings_KeepUpdatingUntilTheLastOneIsUnbound;

    [Test]
    procedure UnbindOneSource_LeavesOtherSourcesBindingsLive;

    [Test]
    procedure TwoManagersOnSameSource_EachKeepsItsOwnSubscription;

    [Test]
    procedure UnbindAll_StopsEveryNotification;
  end;

implementation

constructor TUnbindProbeTarget.Create;
begin
  // 无主创建：与原裸对象替身一致，生命周期由用例的 finally 管
  inherited Create(nil);
end;

procedure TUnbindProbeSource.SetName(const Value: string);
begin
  SetField<string>(FName, Value, 'Name');
end;

procedure TDataBindingUnbindRefCount.SiblingBinding_StillUpdatesAfterUnbindOfOther;
var
  M: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S, 'Name', T2, 'Text', bmOneWay);
    M.Unbind(S, T1);
    Assert.AreEqual<Integer>(1, M.BindingCount);
    S.Name := 'phase-B';
    Assert.AreEqual('phase-B', T2.Text,
      'unbinding one binding of a source must not unsubscribe the shared handler ' +
      'the surviving sibling binding still depends on');
    Assert.AreEqual('', T1.Text,
      'the unbound target must stop receiving updates');
  finally
    M.Free;
    S.Free;
    T1.Free;
    T2.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.LastBindingForSource_UnsubscribesAndStopsUpdating;
var
  M: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S, 'Name', T2, 'Text', bmOneWay);
    M.Unbind(S, T1);
    S.Name := 'phase-B';
    M.Unbind(S, T2);
    Assert.AreEqual<Integer>(0, M.BindingCount);
    S.Name := 'phase-C';
    Assert.AreEqual('phase-B', T2.Text,
      'after the last binding of the source is removed the source is unsubscribed ' +
      'and no further change may reach the target');
  finally
    M.Free;
    S.Free;
    T1.Free;
    T2.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.UnbindObject_TargetSide_KeepsSiblingSubscription;
var
  M: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S, 'Name', T2, 'Text', bmOneWay);
    M.UnbindObject(T1);
    Assert.AreEqual<Integer>(1, M.BindingCount);
    S.Name := 'phase-B';
    Assert.AreEqual('phase-B', T2.Text,
      'UnbindObject removes bindings in which the object takes part as a target; ' +
      'the sibling binding that keeps the same source must stay subscribed');
  finally
    M.Free;
    S.Free;
    T1.Free;
    T2.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.ThreeSiblings_KeepUpdatingUntilTheLastOneIsUnbound;
var
  M: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
  T3: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  T3 := TUnbindProbeTarget.Create;
  try
    M.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S, 'Name', T2, 'Text', bmOneWay);
    M.Bind(S, 'Name', T3, 'Text', bmOneWay);
    M.Unbind(S, T1);
    S.Name := 'phase-B';
    M.Unbind(S, T2);
    S.Name := 'phase-C';
    Assert.AreEqual('phase-C', T3.Text,
      'two partial unsubscriptions must not kill the third binding');
    Assert.AreEqual<Integer>(1, M.BindingCount);
  finally
    M.Free;
    S.Free;
    T1.Free;
    T2.Free;
    T3.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.UnbindOneSource_LeavesOtherSourcesBindingsLive;
var
  M: TBindingManager;
  S1: TUnbindProbeSource;
  S2: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S1 := TUnbindProbeSource.Create;
  S2 := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M.Bind(S1, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S2, 'Name', T2, 'Text', bmOneWay);
    M.Unbind(S1, T1);
    S2.Name := 'from-S2';
    Assert.AreEqual('from-S2', T2.Text,
      'per-source refcounting is per source: another source subscription is unaffected');
  finally
    M.Free;
    S1.Free;
    S2.Free;
    T1.Free;
    T2.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.TwoManagersOnSameSource_EachKeepsItsOwnSubscription;
var
  M1: TBindingManager;
  M2: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M1 := TBindingManager.Create;
  M2 := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M1.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M2.Bind(S, 'Name', T2, 'Text', bmOneWay);
    M1.Unbind(S, T1);
    S.Name := 'phase-B';
    Assert.AreEqual('phase-B', T2.Text,
      'two managers register different method pointers on the same source, ' +
      'so one manager unsubscribing must not silence the other');
  finally
    M1.Free;
    M2.Free;
    S.Free;
    T1.Free;
    T2.Free;
  end;
end;

procedure TDataBindingUnbindRefCount.UnbindAll_StopsEveryNotification;
var
  M: TBindingManager;
  S: TUnbindProbeSource;
  T1: TUnbindProbeTarget;
  T2: TUnbindProbeTarget;
begin
  M := TBindingManager.Create;
  S := TUnbindProbeSource.Create;
  T1 := TUnbindProbeTarget.Create;
  T2 := TUnbindProbeTarget.Create;
  try
    M.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S, 'Name', T2, 'Text', bmOneWay);
    S.Name := 'phase-A';
    M.UnbindAll;
    Assert.AreEqual<Integer>(0, M.BindingCount);
    S.Name := 'phase-B';
    Assert.AreEqual('phase-A', T1.Text,
      'UnbindAll drops every binding of the source');
    Assert.AreEqual('phase-A', T2.Text);
  finally
    M.Free;
    S.Free;
    T1.Free;
    T2.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDataBindingUnbindRefCount);

end.
