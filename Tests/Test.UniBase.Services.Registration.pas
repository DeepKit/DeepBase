unit Test.UniBase.Services.Registration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestServicesRegistration = class
  public
    [Test]
    procedure RegisterDefaultRuntimeComponents_IsSideEffectFree;

    [Test]
    procedure RegisterDefaultRuntimeComponents_UsesDeterministicLifecycleOrder;

    [Test]
    procedure RegisterDefaultRuntimeComponents_CanExcludeManager;
  end;

implementation

uses
  UniBase.RuntimeContext,
  UniBase.Services.Registration;

procedure TTestServicesRegistration.RegisterDefaultRuntimeComponents_IsSideEffectFree;
var
  Context: TUniBaseRuntimeContext;
begin
  Context := TUniBaseRuntimeContext.Create;
  try
    RegisterDefaultRuntimeComponents(Context);

    Assert.AreEqual(5, Context.ComponentCount);
    Assert.IsFalse(Context.Configured);
    Assert.IsFalse(Context.Initialized);
    Assert.IsFalse(Context.Started);
  finally
    Context.Free;
  end;
end;

procedure TTestServicesRegistration.RegisterDefaultRuntimeComponents_UsesDeterministicLifecycleOrder;
var
  Context: TUniBaseRuntimeContext;
begin
  Context := TUniBaseRuntimeContext.Create;
  try
    RegisterDefaultRuntimeComponents(Context);

    Assert.AreEqual('UniBase.Manager', Context.ComponentName(0));
    Assert.AreEqual('IoC.Container', Context.ComponentName(1));
    Assert.AreEqual('EventBus', Context.ComponentName(2));
    Assert.AreEqual('Scheduler', Context.ComponentName(3));
    Assert.AreEqual('WorkerQueue', Context.ComponentName(4));
  finally
    Context.Free;
  end;
end;

procedure TTestServicesRegistration.RegisterDefaultRuntimeComponents_CanExcludeManager;
var
  Context: TUniBaseRuntimeContext;
begin
  Context := TUniBaseRuntimeContext.Create;
  try
    RegisterDefaultRuntimeComponents(Context, '', False);

    Assert.AreEqual(4, Context.ComponentCount);
    Assert.AreEqual('IoC.Container', Context.ComponentName(0));
    Assert.AreEqual('EventBus', Context.ComponentName(1));
    Assert.AreEqual('Scheduler', Context.ComponentName(2));
    Assert.AreEqual('WorkerQueue', Context.ComponentName(3));
  finally
    Context.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestServicesRegistration);

end.
