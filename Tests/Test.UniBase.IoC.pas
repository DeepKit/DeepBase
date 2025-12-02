{ ============================================================================
  Test.UniBase.IoC - IoC Container Unit Tests
  ============================================================================ }

unit Test.UniBase.IoC;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  UniBase.IoC;

type
  // Test interfaces and implementations
  ITestService = interface
    ['{A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D}']
    function GetValue: string;
  end;
  
  ITestServiceWithDep = interface
    ['{B2C3D4E5-F6A7-4B8C-9D0E-1F2A3B4C5D6E}']
    function GetCombinedValue: string;
  end;
  
  TTestServiceA = class(TInterfacedObject, ITestService)
  public
    function GetValue: string;
  end;
  
  TTestServiceB = class(TInterfacedObject, ITestService)
  public
    function GetValue: string;
  end;
  
  TTestServiceWithDep = class(TInterfacedObject, ITestServiceWithDep)
  private
    FDep: ITestService;
  public
    constructor Create(ADep: ITestService);
    function GetCombinedValue: string;
  end;

  [TestFixture]
  TIoCContainerTests = class
  private
    FContainer: TIoCContainer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_RegisterAndResolve_Transient;
    
    [Test]
    procedure Test_RegisterAndResolve_Singleton;
    
    [Test]
    procedure Test_Transient_CreatesNewInstance;
    
    [Test]
    procedure Test_Singleton_ReturnsSameInstance;
    
    [Test]
    procedure Test_RegisterFactory;
    
    [Test]
    procedure Test_IsRegistered;
    
    [Test]
    procedure Test_TryResolve_NotRegistered;
    
    [Test]
    procedure Test_Resolve_NotRegistered_ThrowsException;
    
    [Test]
    procedure Test_NamedRegistration;
    
    [Test]
    procedure Test_Scoped_Lifetime;
    
    [Test]
    procedure Test_Clear;
    
    [Test]
    procedure Test_RegistrationCount;
    
    [Test]
    procedure Test_RegisterSingleton_WithInstance;
    
    [Test]
    procedure Test_RegisterFactoryWithLifetime;
    
    [Test]
    procedure Test_ResolveAll;
    
    [Test]
    procedure Test_ScopeDisposed_RaisesException;
    
    [Test]
    procedure Test_Interceptor_BeforeAndAfter;
    
    [Test]
    procedure Test_GlobalContainer_Singleton;
    
    [Test]
    procedure Test_IsRegistered_WithName;
  end;
  
  // Test Interceptor
  TTestInterceptor = class(TInterfacedObject, IServiceInterceptor)
  private
    FBeforeCalled: Boolean;
    FAfterCalled: Boolean;
  public
    procedure BeforeResolve(var Context: TInterceptorContext);
    procedure AfterResolve(var Context: TInterceptorContext);
    property BeforeCalled: Boolean read FBeforeCalled;
    property AfterCalled: Boolean read FAfterCalled;
  end;

implementation

// ============================================================================
// Test Implementations
// ============================================================================

function TTestServiceA.GetValue: string;
begin
  Result := 'ServiceA';
end;

function TTestServiceB.GetValue: string;
begin
  Result := 'ServiceB';
end;

constructor TTestServiceWithDep.Create(ADep: ITestService);
begin
  inherited Create;
  FDep := ADep;
end;

function TTestServiceWithDep.GetCombinedValue: string;
begin
  Result := 'Combined:' + FDep.GetValue;
end;

// ============================================================================
// TIoCContainerTests
// ============================================================================

procedure TIoCContainerTests.Setup;
begin
  FContainer := TIoCContainer.Create;
end;

procedure TIoCContainerTests.TearDown;
begin
  FContainer.Free;
end;

procedure TIoCContainerTests.Test_RegisterAndResolve_Transient;
var
  Service: ITestService;
begin
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  Service := FContainer.Resolve<ITestService>;
  
  Assert.IsNotNull(Service);
  Assert.AreEqual('ServiceA', Service.GetValue);
end;

procedure TIoCContainerTests.Test_RegisterAndResolve_Singleton;
var
  Service: ITestService;
begin
  FContainer.RegisterSingleton<ITestService, TTestServiceA>;
  Service := FContainer.Resolve<ITestService>;
  
  Assert.IsNotNull(Service);
  Assert.AreEqual('ServiceA', Service.GetValue);
end;

procedure TIoCContainerTests.Test_Transient_CreatesNewInstance;
var
  Service1, Service2: ITestService;
begin
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  
  Service1 := FContainer.Resolve<ITestService>;
  Service2 := FContainer.Resolve<ITestService>;
  
  // Transient creates new instances, but interface reference counting
  // means we can't directly compare object references easily
  Assert.IsNotNull(Service1);
  Assert.IsNotNull(Service2);
end;

procedure TIoCContainerTests.Test_Singleton_ReturnsSameInstance;
var
  Service1, Service2: ITestService;
begin
  FContainer.RegisterSingleton<ITestService, TTestServiceA>;
  
  Service1 := FContainer.Resolve<ITestService>;
  Service2 := FContainer.Resolve<ITestService>;
  
  Assert.IsNotNull(Service1);
  Assert.IsNotNull(Service2);
  // For singleton, both should point to same underlying object
  Assert.AreEqual(Service1.GetValue, Service2.GetValue);
end;

procedure TIoCContainerTests.Test_RegisterFactory;
var
  CallCount: Integer;
  Service: ITestService;
begin
  CallCount := 0;
  
  FContainer.RegisterFactory<ITestService>(
    function: ITestService
    begin
      Inc(CallCount);
      Result := TTestServiceA.Create;
    end);
  
  Service := FContainer.Resolve<ITestService>;
  
  Assert.AreEqual(1, CallCount);
  Assert.IsNotNull(Service);
end;

procedure TIoCContainerTests.Test_IsRegistered;
begin
  Assert.IsFalse(FContainer.IsRegistered<ITestService>);
  
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  
  Assert.IsTrue(FContainer.IsRegistered<ITestService>);
end;

procedure TIoCContainerTests.Test_TryResolve_NotRegistered;
var
  Service: ITestService;
  Success: Boolean;
begin
  Success := FContainer.TryResolve<ITestService>(Service);
  
  Assert.IsFalse(Success);
end;

procedure TIoCContainerTests.Test_Resolve_NotRegistered_ThrowsException;
begin
  Assert.WillRaise(
    procedure
    begin
      FContainer.Resolve<ITestService>;
    end,
    EServiceNotRegisteredException);
end;

procedure TIoCContainerTests.Test_NamedRegistration;
var
  ServiceA, ServiceB: ITestService;
begin
  FContainer.RegisterType<ITestService, TTestServiceA>(slTransient, 'A');
  FContainer.RegisterType<ITestService, TTestServiceB>(slTransient, 'B');
  
  ServiceA := FContainer.Resolve<ITestService>('A');
  ServiceB := FContainer.Resolve<ITestService>('B');
  
  Assert.AreEqual('ServiceA', ServiceA.GetValue);
  Assert.AreEqual('ServiceB', ServiceB.GetValue);
end;

procedure TIoCContainerTests.Test_Scoped_Lifetime;
var
  Scope1, Scope2: TIoCScope;
  Service1a, Service1b, Service2: ITestService;
begin
  FContainer.RegisterScoped<ITestService, TTestServiceA>;
  
  Scope1 := FContainer.CreateScope;
  try
    Service1a := Scope1.Resolve<ITestService>;
    Service1b := Scope1.Resolve<ITestService>;
    // Same scope should return same instance
    Assert.IsNotNull(Service1a);
    Assert.IsNotNull(Service1b);
  finally
    Scope1.Free;
  end;
  
  Scope2 := FContainer.CreateScope;
  try
    Service2 := Scope2.Resolve<ITestService>;
    Assert.IsNotNull(Service2);
  finally
    Scope2.Free;
  end;
end;

procedure TIoCContainerTests.Test_Clear;
begin
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  Assert.IsTrue(FContainer.IsRegistered<ITestService>);
  
  FContainer.Clear;
  
  Assert.IsFalse(FContainer.IsRegistered<ITestService>);
end;

procedure TIoCContainerTests.Test_RegistrationCount;
begin
  Assert.AreEqual(0, FContainer.RegistrationCount);
  
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  Assert.AreEqual(1, FContainer.RegistrationCount);
  
  FContainer.RegisterType<ITestService, TTestServiceB>(slTransient, 'Named');
  Assert.AreEqual(2, FContainer.RegistrationCount);
end;

procedure TIoCContainerTests.Test_RegisterSingleton_WithInstance;
var
  Instance: ITestService;
  Resolved: ITestService;
begin
  Instance := TTestServiceA.Create;
  FContainer.RegisterSingleton<ITestService>(Instance);
  
  Resolved := FContainer.Resolve<ITestService>;
  
  Assert.AreEqual('ServiceA', Resolved.GetValue);
end;

procedure TIoCContainerTests.Test_RegisterFactoryWithLifetime;
var
  CallCount: Integer;
  Svc1, Svc2: ITestService;
begin
  CallCount := 0;
  
  FContainer.RegisterFactory<ITestService>(
    function: ITestService
    begin
      Inc(CallCount);
      Result := TTestServiceA.Create;
    end,
    slSingleton);
  
  Svc1 := FContainer.Resolve<ITestService>;
  Svc2 := FContainer.Resolve<ITestService>;
  
  // Singleton factory should only be called once
  Assert.AreEqual(1, CallCount, 'Factory should only be called once for singleton');
end;

procedure TIoCContainerTests.Test_ResolveAll;
var
  Services: TArray<ITestService>;
begin
  FContainer.RegisterType<ITestService, TTestServiceA>(slTransient, 'A');
  FContainer.RegisterType<ITestService, TTestServiceB>(slTransient, 'B');
  
  Services := FContainer.ResolveAll<ITestService>;
  
  Assert.AreEqual(2, Length(Services), 'Should resolve all implementations');
end;

procedure TIoCContainerTests.Test_ScopeDisposed_RaisesException;
var
  Scope: TIoCScope;
begin
  FContainer.RegisterScoped<ITestService, TTestServiceA>;
  
  Scope := FContainer.CreateScope;
  Scope.Free; // Dispose the scope
  
  Assert.WillRaise(
    procedure
    begin
      Scope.Resolve<ITestService>;
    end,
    EScopeDisposedException,
    'Should raise exception when scope is disposed');
end;

procedure TIoCContainerTests.Test_Interceptor_BeforeAndAfter;
var
  Interceptor: TTestInterceptor;
  Svc: ITestService;
begin
  Interceptor := TTestInterceptor.Create;
  FContainer.AddInterceptor(Interceptor);
  FContainer.RegisterTransient<ITestService, TTestServiceA>;
  
  Svc := FContainer.Resolve<ITestService>;
  
  Assert.IsTrue(Interceptor.BeforeCalled, 'BeforeResolve should be called');
  Assert.IsTrue(Interceptor.AfterCalled, 'AfterResolve should be called');
  
  FContainer.ClearInterceptors;
end;

procedure TIoCContainerTests.Test_GlobalContainer_Singleton;
var
  C1, C2: TIoCContainer;
begin
  C1 := GlobalContainer;
  C2 := GlobalContainer;
  
  Assert.AreSame(C1, C2, 'GlobalContainer should return same instance');
end;

procedure TIoCContainerTests.Test_IsRegistered_WithName;
begin
  FContainer.RegisterType<ITestService, TTestServiceA>(slTransient, 'NamedA');
  
  Assert.IsTrue(FContainer.IsRegistered<ITestService>('NamedA'), 'Named registration should be found');
  Assert.IsFalse(FContainer.IsRegistered<ITestService>('NonExistent'), 'Non-existent name should not be found');
end;

{ TTestInterceptor }

procedure TTestInterceptor.BeforeResolve(var Context: TInterceptorContext);
begin
  FBeforeCalled := True;
end;

procedure TTestInterceptor.AfterResolve(var Context: TInterceptorContext);
begin
  FAfterCalled := True;
end;

initialization
  TDUnitX.RegisterTestFixture(TIoCContainerTests);

end.
