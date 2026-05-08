unit Test.DeepBase.Persistence.RuntimeRegistration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestPersistenceRuntimeRegistration = class
  public
    [Test]
    procedure RegisterPersistenceRuntimeComponents_IsSideEffectFree;

    [Test]
    procedure RegisterPersistenceRuntimeComponents_RegistersDBPoolManager;

    [Test]
    procedure RegisterPersistenceRuntimeComponents_RejectsNilContext;

    [Test]
    procedure CombinedRegistration_PersistenceFirst_RegistersDBPoolBeforeCoreComponents;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.RuntimeContext,
  DeepBase.Persistence.RuntimeRegistration,
  DeepBase.Services.Registration;

procedure TTestPersistenceRuntimeRegistration.RegisterPersistenceRuntimeComponents_IsSideEffectFree;
var
  Context: TDeepBaseRuntimeContext;
begin
  Context := TDeepBaseRuntimeContext.Create;
  try
    RegisterPersistenceRuntimeComponents(Context);

    Assert.AreEqual(1, Context.ComponentCount);
    Assert.IsFalse(Context.Configured);
    Assert.IsFalse(Context.Initialized);
    Assert.IsFalse(Context.Started);
  finally
    Context.Free;
  end;
end;

procedure TTestPersistenceRuntimeRegistration.RegisterPersistenceRuntimeComponents_RegistersDBPoolManager;
var
  Context: TDeepBaseRuntimeContext;
begin
  Context := TDeepBaseRuntimeContext.Create;
  try
    RegisterPersistenceRuntimeComponents(Context);
    Assert.AreEqual('DB.PoolManager', Context.ComponentName(0));
  finally
    Context.Free;
  end;
end;

procedure TTestPersistenceRuntimeRegistration.RegisterPersistenceRuntimeComponents_RejectsNilContext;
begin
  Assert.WillRaise(
    procedure
    begin
      RegisterPersistenceRuntimeComponents(nil);
    end,
    EArgumentNilException);
end;

procedure TTestPersistenceRuntimeRegistration.CombinedRegistration_PersistenceFirst_RegistersDBPoolBeforeCoreComponents;
var
  Context: TDeepBaseRuntimeContext;
begin
  Context := TDeepBaseRuntimeContext.Create;
  try
    RegisterPersistenceRuntimeComponents(Context);
    RegisterDefaultRuntimeComponents(Context);

    Assert.AreEqual(6, Context.ComponentCount);
    Assert.AreEqual('DB.PoolManager', Context.ComponentName(0));
    Assert.AreEqual('DeepBase.Manager', Context.ComponentName(1));
    Assert.AreEqual('IoC.Container', Context.ComponentName(2));
    Assert.AreEqual('EventBus', Context.ComponentName(3));
    Assert.AreEqual('Scheduler', Context.ComponentName(4));
    Assert.AreEqual('WorkerQueue', Context.ComponentName(5));
  finally
    Context.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPersistenceRuntimeRegistration);

end.
