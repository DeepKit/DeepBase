unit Test.DeepBase.DataBindingLifetime;
{ ============================================================================
  Test.DeepBase.DataBindingLifetime - 绑定关系生命周期回归单元

  工单：WO-20261001-MC-甲-A16（A5-R02 强路线 (a-1) 落笔① · source 面）
  被测缺陷：TBindingEntry 以裸指针持有 Source/Target，绑定对象先于 manager 释放时
            条目不会消失，后续任意绑定路径都会读写已释放实例（read-after-free）。
  判据来源：A5-R02 停机上报的 A4-01 探针 S4 现场（CodeReview/20260925-AUDIT-甲-A4-证据/
            附件/A401_Databinding.dpr.template），本单元是其 DUnitX 化。
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  DeepBase.DataBinding;

type
  // 目标替身用 TComponent：与生产面（TControl/TEdit/TCheckBox）同族，
  // 使本单元在落笔②（target 面闸门）之后仍逐字可编译，避免为绕开闸门再改一次断言。
  {$M+}
  TLiveTarget = class(TComponent)
  private
    FText: string;
  public
    constructor Create; reintroduce;
  published
    property Text: string read FText write FText;
  end;

  {$M+}
  TLiveSource = class(TObservableObject)
  private
    FName: string;
    procedure SetName(const Value: string);
  published
    property Name: string read FName write SetName;
  end;

  [TestFixture]
  TDataBindingLifetimeTests = class
  public
    [Test]
    procedure SourceDestroy_DropsItsBindingsAndStopsUpdates;

    [Test]
    procedure SourceDestroy_WithDecoyAtFreedSlot_TargetNotResurrected;

    [Test]
    procedure SourceDestroy_OneTimeBindingAlsoDropped;

    [Test]
    procedure SourceDestroy_LeavesOtherSourcesBindingsLive;

    [Test]
    procedure TwoManagersOnSameSource_BothDropWhenSourceFreed;

    [Test]
    procedure SourceFreedBeforeManager_BothTeardownsSafe;
  end;

implementation

{ TLiveTarget }

constructor TLiveTarget.Create;
begin
  inherited Create(nil);
end;

{ TLiveSource }

procedure TLiveSource.SetName(const Value: string);
begin
  SetField<string>(FName, Value, 'Name');
end;

{ TDataBindingLifetimeTests }

// S4 复刻（甲）：源释放后条目必须消失，且再入绑定路径不得复活更新
procedure TDataBindingLifetimeTests.SourceDestroy_DropsItsBindingsAndStopsUpdates;
var
  M: TBindingManager;
  S: TLiveSource;
  T: TLiveTarget;
begin
  M := TBindingManager.Create;
  S := TLiveSource.Create;
  T := TLiveTarget.Create;
  try
    M.Bind(S, 'Name', T, 'Text', bmOneWay);
    Assert.AreEqual<Integer>(1, M.BindingCount);
    S.Free;
    S := nil;
    // 修前红点：裸指针条目仍在（BindingCount=1），后续路径会读已释放实例
    Assert.AreEqual<Integer>(0, M.BindingCount,
      'a freed source must have all of its binding entries removed');
    M.UpdateAllTargets;
    T.Text := '';
    M.NotifyTargetChanged(T, 'Text');
    Assert.AreEqual('', T.Text, 'a freed source must not be written back through any bind path');
  finally
    M.Free;
    T.Free;
    if S <> nil then
      S.Free;
  end;
end;

// S4 复刻（乙）：释放槽位被同型替身复用后，manager 仍不得把旧槽当活源读
procedure TDataBindingLifetimeTests.SourceDestroy_WithDecoyAtFreedSlot_TargetNotResurrected;
var
  M: TBindingManager;
  S: TLiveSource;
  Decoy: TLiveSource;
  T: TLiveTarget;
  FreedAddr: NativeInt;
begin
  M := TBindingManager.Create;
  S := TLiveSource.Create;
  T := TLiveTarget.Create;
  try
    M.Bind(S, 'Name', T, 'Text', bmOneWay);
    FreedAddr := NativeInt(S);
    S.Free;
    S := nil;
    Decoy := TLiveSource.Create;
    try
      Decoy.Name := 'DECOY-VALUE';
      // 断言顺序即 fail-closed 顺序：先卡确定性红点（条目残留），
      // 只有修法在场时才会走到依赖地址复用的那段读取。
      Assert.AreEqual<Integer>(0, M.BindingCount,
        'entries left behind a freed source re-read whichever object reuses the slot');
      if NativeInt(Decoy) = FreedAddr then
      begin
        M.UpdateAllTargets;
        Assert.AreNotEqual('DECOY-VALUE', T.Text,
          'the stale entry read the slot-reuse decoy as if it were the original source');
      end;
    finally
      Decoy.Free;
    end;
  finally
    M.Free;
    T.Free;
    if S <> nil then
      S.Free;
  end;
end;

// bmOneTime 也持源指针：UpdateAllTargets 不分模式重读 ⇒ 一次性绑定同样要摘
procedure TDataBindingLifetimeTests.SourceDestroy_OneTimeBindingAlsoDropped;
var
  M: TBindingManager;
  S: TLiveSource;
  T: TLiveTarget;
begin
  M := TBindingManager.Create;
  S := TLiveSource.Create;
  T := TLiveTarget.Create;
  try
    S.Name := 'Initial';
    M.Bind(S, 'Name', T, 'Text', bmOneTime);
    Assert.AreEqual('Initial', T.Text);
    S.Free;
    S := nil;
    Assert.AreEqual<Integer>(0, M.BindingCount,
      'bmOneTime entries keep the raw source pointer and must drop with it');
    M.UpdateAllTargets;
  finally
    M.Free;
    T.Free;
    if S <> nil then
      S.Free;
  end;
end;

// 反向半：只摘该源的条目，其它源的绑定必须继续活着（防做成全局清空）
procedure TDataBindingLifetimeTests.SourceDestroy_LeavesOtherSourcesBindingsLive;
var
  M: TBindingManager;
  S1, S2: TLiveSource;
  T1, T2: TLiveTarget;
begin
  M := TBindingManager.Create;
  S1 := TLiveSource.Create;
  S2 := TLiveSource.Create;
  T1 := TLiveTarget.Create;
  T2 := TLiveTarget.Create;
  try
    M.Bind(S1, 'Name', T1, 'Text', bmOneWay);
    M.Bind(S2, 'Name', T2, 'Text', bmOneWay);
    S1.Free;
    S1 := nil;
    Assert.AreEqual<Integer>(1, M.BindingCount, 'only the freed source entries may be dropped');
    S2.Name := 'still-live';
    Assert.AreEqual('still-live', T2.Text, 'a live source must keep updating its own binding');
    Assert.AreEqual('', T1.Text, 'the freed source must no longer write into its target');
  finally
    M.Free;
    T1.Free;
    T2.Free;
    S2.Free;
    if S1 <> nil then
      S1.Free;
  end;
end;

// 同一源被两个 manager 分别绑定：源析构时两侧都要摘，且互不影响计数
procedure TDataBindingLifetimeTests.TwoManagersOnSameSource_BothDropWhenSourceFreed;
var
  M1, M2: TBindingManager;
  S: TLiveSource;
  T1, T2: TLiveTarget;
begin
  M1 := TBindingManager.Create;
  M2 := TBindingManager.Create;
  S := TLiveSource.Create;
  T1 := TLiveTarget.Create;
  T2 := TLiveTarget.Create;
  try
    M1.Bind(S, 'Name', T1, 'Text', bmOneWay);
    M2.Bind(S, 'Name', T2, 'Text', bmOneWay);
    S.Free;
    S := nil;
    Assert.AreEqual<Integer>(0, M1.BindingCount);
    Assert.AreEqual<Integer>(0, M2.BindingCount);
    M1.UpdateAllTargets;
    M2.UpdateAllTargets;
  finally
    M1.Free;
    M2.Free;
    T1.Free;
    T2.Free;
    if S <> nil then
      S.Free;
  end;
end;

// 拆解顺序对照：源先死、manager 后死 ⇒ 退订路径不得回调进已释放对象
procedure TDataBindingLifetimeTests.SourceFreedBeforeManager_BothTeardownsSafe;
var
  M: TBindingManager;
  S: TLiveSource;
  T: TLiveTarget;
begin
  M := TBindingManager.Create;
  S := TLiveSource.Create;
  T := TLiveTarget.Create;
  try
    M.Bind(S, 'Name', T, 'Text', bmTwoWay);
    S.Free;
    S := nil;
    M.UnbindObject(T);
    M.UnbindAll;
    Assert.AreEqual<Integer>(0, M.BindingCount);
  finally
    M.Free;
    T.Free;
    if S <> nil then
      S.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TDataBindingLifetimeTests);

end.
