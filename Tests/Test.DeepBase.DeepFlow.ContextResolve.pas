unit Test.DeepBase.DeepFlow.ContextResolve;

(********************************************************************************
  Test.DeepBase.DeepFlow.ContextResolve - B2-11 回归

  被测面：TWorkflowContext 的变量解析（ResolveString / ResolveJSON）。
  ResolveJSON 会在持锁状态横向调用 ResolveString 并按嵌套深度自递归，
  旧实现把正确性押在"同一把临界区可重入"这一平台副作用上。

  两条判据用例（有界返回 / 高并发无死锁）必须在工作线程里跑解析：
  真死锁时主线程只放弃等待、绝不 Join——否则整台 runner 一起挂住，
  证据里就只剩一条墙钟超时而不是可读的用例红。
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON,
  DUnitX.TestFramework,
  DeepFlow.Workflow.Context;

type
  /// <summary>在独立线程内跑若干轮解析，供主线程做有界等待。</summary>
  TResolveWorker = class(TThread)
  private
    FContext: TWorkflowContext;
    FTag: Integer;
    FIterations: Integer;
    FCompleted: Integer;
    FMismatched: Integer;
    FFirstLevel3: string;
    FFinished: TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(AContext: TWorkflowContext; ATag, AIterations: Integer);
    destructor Destroy; override;
    function FinishedWithin(ATimeoutMs: Integer): Boolean;
    property Completed: Integer read FCompleted;
    property Mismatched: Integer read FMismatched;
    property FirstLevel3: string read FFirstLevel3;
  end;

  [TestFixture]
  TTestDeepFlowContextResolve = class
  private
    FContext: TWorkflowContext;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_ResolveString_SingleVariable;
    [Test]
    procedure Test_ResolveString_UnknownVariableYieldsEmpty;
    [Test]
    procedure Test_ResolveString_TypedVariableUsesAsString;
    [Test]
    procedure Test_ResolveJSON_ResolvesEveryNestedLevel;
    [Test]
    procedure Test_ResolveJSON_LeavesNonStringValuesUntouched;
    [Test]
    procedure Test_ResolveJSON_DoesNotMutateTemplate;
    [Test]
    procedure Test_ResolveJSON_NestedReturnsBounded;
    [Test]
    procedure Test_ResolveJSON_HighConcurrency_NoDeadlock;
  end;

implementation

/// <summary>三层模板：根串 + 子对象 + 孙对象，覆盖 ResolveJSON 的横向调用与自递归。</summary>
function NestedTemplate(ATag: Integer): TJSONObject;
var
  Branch, Leaf: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('level1', '${shared}-${t' + ATag.ToString + '}');
  Branch := TJSONObject.Create;
  Branch.AddPair('level2', '${shared}');
  Leaf := TJSONObject.Create;
  Leaf.AddPair('level3', '${t' + ATag.ToString + '}-${shared}');
  Branch.AddPair('nested', Leaf);
  Result.AddPair('branch', Branch);
end;

{ TResolveWorker }

constructor TResolveWorker.Create(AContext: TWorkflowContext; ATag, AIterations: Integer);
begin
  inherited Create(True);
  FContext := AContext;
  FTag := ATag;
  FIterations := AIterations;
  FCompleted := 0;
  FMismatched := 0;
  FFirstLevel3 := '';
  FFinished := TEvent.Create(nil, True, False, '');
end;

destructor TResolveWorker.Destroy;
begin
  FFinished.Free;
  inherited;
end;

function TResolveWorker.FinishedWithin(ATimeoutMs: Integer): Boolean;
begin
  Result := FFinished.WaitFor(ATimeoutMs) = wrSignaled;
end;

procedure TResolveWorker.Execute;
var
  I: Integer;
  Template, Resolved, Branch, Leaf: TJSONObject;
  Level1, Level3: string;
begin
  for I := 0 to FIterations - 1 do
  begin
    // 删掉再重建本线程私有的键：只读的并发测不到字典结构变更那侧的锁竞争。
    // 键归本线程私有且值由自己写回，解析期望保持确定，红点只可能来自并发本身。
    FContext.DeleteVariable('t' + FTag.ToString);
    FContext.SetVariable('t' + FTag.ToString, 'V' + FTag.ToString, vsWorkflow);
    Template := NestedTemplate(FTag);
    try
      Resolved := FContext.ResolveJSON(Template);
      try
        Level1 := Resolved.GetValue<string>('level1');
        Branch := Resolved.GetValue('branch') as TJSONObject;
        Leaf := Branch.GetValue('nested') as TJSONObject;
        Level3 := Leaf.GetValue<string>('level3');
        if Level1 <> 'S-V' + FTag.ToString then
          TInterlocked.Increment(FMismatched);
        if Level3 <> 'V' + FTag.ToString + '-S' then
          TInterlocked.Increment(FMismatched);
        if I = 0 then
          FFirstLevel3 := Level3;
      finally
        Resolved.Free;
      end;
    finally
      Template.Free;
    end;
    TInterlocked.Increment(FCompleted);
  end;
  FFinished.SetEvent;
end;

{ TTestDeepFlowContextResolve }

procedure TTestDeepFlowContextResolve.SetUp;
begin
  FContext := TWorkflowContext.Create('wf-test', 'inst-test');
  FContext.SetVariable('shared', 'S', vsGlobal);
  for var I := 0 to 7 do
    FContext.SetVariable('t' + I.ToString, 'V' + I.ToString, vsWorkflow);
end;

procedure TTestDeepFlowContextResolve.TearDown;
begin
  FContext.Free;
end;

procedure TTestDeepFlowContextResolve.Test_ResolveString_SingleVariable;
begin
  Assert.AreEqual('Hello S!', FContext.ResolveString('Hello ${shared}!'));
end;

procedure TTestDeepFlowContextResolve.Test_ResolveString_UnknownVariableYieldsEmpty;
begin
  Assert.AreEqual('[]-', FContext.ResolveString('[${nope}]-'));
end;

procedure TTestDeepFlowContextResolve.Test_ResolveString_TypedVariableUsesAsString;
begin
  FContext.SetVariable('count', Int64(42), vsWorkflow);
  Assert.AreEqual('n=42', FContext.ResolveString('n=${count}'));
end;

procedure TTestDeepFlowContextResolve.Test_ResolveJSON_ResolvesEveryNestedLevel;
var
  Template, Resolved, Branch, Leaf: TJSONObject;
begin
  Template := NestedTemplate(1);
  try
    Resolved := FContext.ResolveJSON(Template);
    try
      Assert.AreEqual('S-V1', Resolved.GetValue<string>('level1'));
      Branch := Resolved.GetValue('branch') as TJSONObject;
      Assert.AreEqual('S', Branch.GetValue<string>('level2'));
      Leaf := Branch.GetValue('nested') as TJSONObject;
      Assert.AreEqual('V1-S', Leaf.GetValue<string>('level3'));
    finally
      Resolved.Free;
    end;
  finally
    Template.Free;
  end;
end;

procedure TTestDeepFlowContextResolve.Test_ResolveJSON_LeavesNonStringValuesUntouched;
var
  Template, Resolved, Obj: TJSONObject;
  Arr: TJSONArray;
begin
  Template := TJSONObject.Create;
  Template.AddPair('num', TJSONNumber.Create(7));
  Template.AddPair('flag', TJSONBool.Create(True));
  Arr := TJSONArray.Create;
  // 非串、非对象的值走克隆分支：数组元素内容不经解析，这条断言把该边界固化下来
  Arr.Add('${shared}');
  Template.AddPair('arr', Arr);
  Obj := TJSONObject.Create;
  Obj.AddPair('keep', TJSONNull.Create);
  Template.AddPair('emptyObj', Obj);
  try
    Resolved := FContext.ResolveJSON(Template);
    try
      Assert.AreEqual('7', Resolved.GetValue('num').ToString);
      Assert.AreEqual('true', Resolved.GetValue('flag').ToString);
      Assert.AreEqual('null', TJSONObject(Resolved.GetValue('emptyObj')).GetValue('keep').ToString);
      Assert.AreEqual('"${shared}"', TJSONArray(Resolved.GetValue('arr')).Items[0].ToString);
    finally
      Resolved.Free;
    end;
  finally
    Template.Free;
  end;
end;

procedure TTestDeepFlowContextResolve.Test_ResolveJSON_DoesNotMutateTemplate;
var
  Template, Resolved: TJSONObject;
begin
  Template := NestedTemplate(2);
  try
    Resolved := FContext.ResolveJSON(Template);
    Resolved.Free;
    // 返回值与入参不共享节点：模板被就地改写的话，第二次解析拿到的就是已解析过的串
    Assert.AreEqual('${shared}-${t2}', Template.GetValue<string>('level1'));
    Resolved := FContext.ResolveJSON(Template);
    try
      Assert.AreEqual('S-V2', Resolved.GetValue<string>('level1'));
    finally
      Resolved.Free;
    end;
  finally
    Template.Free;
  end;
end;

procedure TTestDeepFlowContextResolve.Test_ResolveJSON_NestedReturnsBounded;
var
  Worker: TResolveWorker;
  Finished: Boolean;
begin
  Worker := TResolveWorker.Create(FContext, 3, 1);
  Worker.Start;
  Finished := Worker.FinishedWithin(5000);
  if not Finished then
  begin
    // 故意不 Free：TThread.Destroy 会等已死锁的线程，会把整台 runner 一起挂住
    Worker.Terminate;
    Assert.Fail('嵌套 ResolveJSON 未在 5s 内返回——锁被重入。');
    Exit;
  end;
  try
    Assert.AreEqual<Integer>(1, Worker.Completed);
    Assert.AreEqual<Integer>(0, Worker.Mismatched);
    Assert.AreEqual('V3-S', Worker.FirstLevel3);
  finally
    Worker.Free;
  end;
end;

procedure TTestDeepFlowContextResolve.Test_ResolveJSON_HighConcurrency_NoDeadlock;
const
  THREAD_COUNT = 8;
  ITERATIONS = 150;
var
  I, TotalCompleted, TotalMismatched: Integer;
  Workers: array of TResolveWorker;
  Worker: TResolveWorker;
  Finished: Boolean;
begin
  SetLength(Workers, THREAD_COUNT);
  // 每线程写自己的变量并读共享变量：写入口与解析入口真并发，而不是只读
  for I := 0 to High(Workers) do
  begin
    Workers[I] := TResolveWorker.Create(FContext, I, ITERATIONS);
    Workers[I].Start;
  end;

  Finished := True;
  TotalCompleted := 0;
  TotalMismatched := 0;
  for Worker in Workers do
  begin
    if not Worker.FinishedWithin(20000) then
      Finished := False;
  end;
  if not Finished then
  begin
    for Worker in Workers do
      Worker.Terminate;
    Assert.Fail('并发解析未在预算内全部返回——存在死锁或活锁。');
    Exit;
  end;

  for Worker in Workers do
  begin
    Inc(TotalCompleted, Worker.Completed);
    Inc(TotalMismatched, Worker.Mismatched);
  end;
  for Worker in Workers do
    Worker.Free;

  Assert.AreEqual<Integer>(THREAD_COUNT * ITERATIONS, TotalCompleted);
  Assert.AreEqual<Integer>(0, TotalMismatched);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestDeepFlowContextResolve);

end.
