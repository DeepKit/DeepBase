{ ============================================================================
  DeepBase.Services.Registration - Service Registration Module

  Version: 1.0
  Description: Registers all service implementations with the IoC container.
               Call RegisterDefaultServices to configure the global container
               with default implementations.

  Usage:
    uses
      DeepBase.IoC,
      DeepBase.Services.Registration;

    // In application initialization
    RegisterDefaultServices(GlobalContainer);

    // Then use services
    var HashSvc := GlobalContainer.Resolve<IHashService>;
    var Hash := HashSvc.SHA256('data');

  Testing:
    // Create isolated container for testing
    var TestContainer := TIoCContainer.Create;
    try
      // Register mock implementations
      TestContainer.Register<IHashService>(TMockHashService.Create);

      // Run tests with mocked dependencies
      RunTests(TestContainer);
    finally
      TestContainer.Free;
    end;
  ============================================================================ }

unit DeepBase.Services.Registration;

interface

uses
  DeepBase.IoC,
  DeepBase.RuntimeContext;

/// <summary>
/// Register all default service implementations with the container
/// </summary>
procedure RegisterDefaultServices(Container: TIoCContainer);

/// <summary>
/// Register framework-level facades into the IoC container.
/// Registration must not start background services; factories create/resolve
/// global instances only when consumers explicitly resolve them.
/// </summary>
procedure RegisterFrameworkServices(Container: TIoCContainer);

/// <summary>
/// Register default runtime lifecycle components into a RuntimeContext.
/// Registration is side-effect free; components are not started until the
/// caller explicitly calls RuntimeContext.Start.
/// </summary>
procedure RegisterDefaultRuntimeComponents(Context: IRuntimeContext;
  const ManagerDBPath: string = ''; IncludeManager: Boolean = True);

/// <summary>
/// Register crypto services (IHashService, IEncodingService, etc.)
/// </summary>
procedure RegisterCryptoServices(Container: TIoCContainer);

/// <summary>
/// Register math services (IStatisticsService, IMathUtilsService, etc.)
/// </summary>
procedure RegisterMathServices(Container: TIoCContainer);

/// <summary>
/// Register serialization services
/// </summary>
procedure RegisterSerializationServices(Container: TIoCContainer);

/// <summary>
/// Register protection services (IBasicProtectionService, IAntiTamperService)
/// </summary>
procedure RegisterProtectionServices(Container: TIoCContainer;
  const DefaultPassword: string = '');

/// <summary>
/// Check if default services are registered
/// </summary>
function AreServicesRegistered(Container: TIoCContainer): Boolean;

implementation

uses
  System.SysUtils,
  DeepBase.Services.Interfaces,
  DeepBase.Services.Crypto,
  DeepBase.Services.Math,
  DeepBase.Services.Serialization,
  DeepBase.Services.Protection,
  DeepBase.EventBus,
  DeepBase.Scheduler,
  DeepBase.WorkerQueue,
  DeepBase.Manager,
  DeepBase.Interfaces;

type
  TDeepBaseManagerRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FDBPath: string;
    FManager: TDeepBaseManager;
    FInitializedByComponent: Boolean;
  public
    constructor Create(const ADBPath: string); reintroduce;
    procedure Start; override;
    procedure Shutdown; override;
  end;

  TIoCRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FActivated: Boolean;
  public
    constructor Create; reintroduce;
    procedure Start; override;
    procedure Shutdown; override;
  end;

  TEventBusRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FBus: TEventBus;
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create; reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  TSchedulerRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FScheduler: TTaskScheduler;
    FRegisteredGlobal: Boolean;
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create; reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

  TWorkerQueueRuntimeComponent = class(TDeepBaseRuntimeComponent)
  private
    FQueue: TWorkerQueue;
    FActivated: Boolean;
    FStarted: Boolean;
  public
    constructor Create; reintroduce;
    procedure Start; override;
    procedure Stop; override;
    procedure Shutdown; override;
  end;

{ TDeepBaseManagerRuntimeComponent }

constructor TDeepBaseManagerRuntimeComponent.Create(const ADBPath: string);
begin
  inherited Create('DeepBase.Manager');
  FDBPath := ADBPath;
end;

procedure TDeepBaseManagerRuntimeComponent.Start;
var
  ErrorMsg: string;
begin
  FManager := DeepBase.Manager.DeepBase;

  if FManager.IsInitialized then
    Exit;

  if FDBPath <> '' then
  begin
    if not FManager.InitializeWithDB(FDBPath) then
      raise ERuntimeContextError.CreateFmt(
        'DeepBase.Manager initialization failed: %s', [FManager.LastError]);
  end
  else if not FManager.InitializeEx(ErrorMsg) then
    raise ERuntimeContextError.CreateFmt(
      'DeepBase.Manager initialization failed: %s', [ErrorMsg]);

  FInitializedByComponent := True;
end;

procedure TDeepBaseManagerRuntimeComponent.Shutdown;
begin
  if FInitializedByComponent and (FManager <> nil) then
    FManager.Finalize;

  FInitializedByComponent := False;
end;

{ TIoCRuntimeComponent }

constructor TIoCRuntimeComponent.Create;
begin
  inherited Create('IoC.Container');
end;

procedure TIoCRuntimeComponent.Start;
begin
  GlobalContainer;
  FActivated := True;
end;

procedure TIoCRuntimeComponent.Shutdown;
begin
  if FActivated then
    GlobalContainer.Clear;

  FActivated := False;
end;

{ TEventBusRuntimeComponent }

constructor TEventBusRuntimeComponent.Create;
begin
  inherited Create('EventBus');
end;

procedure TEventBusRuntimeComponent.Start;
begin
  if FBus = nil then
    FBus := EventBus;

  FBus.Enabled := True;
  FStarted := True;
  FActivated := True;
end;

procedure TEventBusRuntimeComponent.Stop;
begin
  if FStarted and (FBus <> nil) then
    FBus.WaitForAsyncHandlers(5000);

  FStarted := False;
end;

procedure TEventBusRuntimeComponent.Shutdown;
begin
  if FActivated and (FBus <> nil) then
  begin
    FBus.WaitForAsyncHandlers(5000);
    FBus.Enabled := False;
    FBus.Clear;
  end;

  FStarted := False;
  FActivated := False;
end;

{ TSchedulerRuntimeComponent }

constructor TSchedulerRuntimeComponent.Create;
begin
  inherited Create('Scheduler');
end;

procedure TSchedulerRuntimeComponent.Start;
begin
  if FScheduler = nil then
  begin
    FScheduler := TTaskScheduler.Create;
    SetScheduler(FScheduler);
    FRegisteredGlobal := True;
  end;

  FScheduler.Start;
  FStarted := True;
  FActivated := True;
end;

procedure TSchedulerRuntimeComponent.Stop;
begin
  if FStarted and (FScheduler <> nil) then
    FScheduler.Stop;

  FStarted := False;
end;

procedure TSchedulerRuntimeComponent.Shutdown;
begin
  if FActivated and (FScheduler <> nil) then
    FScheduler.Stop;

  if FRegisteredGlobal then
  begin
    SetScheduler(nil);
    FScheduler := nil;
    FRegisteredGlobal := False;
  end;

  FStarted := False;
  FActivated := False;
end;

{ TWorkerQueueRuntimeComponent }

constructor TWorkerQueueRuntimeComponent.Create;
begin
  inherited Create('WorkerQueue');
end;

procedure TWorkerQueueRuntimeComponent.Start;
begin
  if FQueue = nil then
    FQueue := WorkerQueue('default');

  FQueue.Start;
  FStarted := True;
  FActivated := True;
end;

procedure TWorkerQueueRuntimeComponent.Stop;
begin
  if FStarted and (FQueue <> nil) then
    FQueue.Stop(True);

  FStarted := False;
end;

procedure TWorkerQueueRuntimeComponent.Shutdown;
begin
  if FActivated and (FQueue <> nil) then
    FQueue.Stop(True);

  FStarted := False;
  FActivated := False;
end;

procedure RegisterCryptoServices(Container: TIoCContainer);
begin
  // Hash Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IHashService>(
    function: IHashService
    begin
      Result := THashServiceImpl.Create;
    end,
    slSingleton);

  // Encoding Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IEncodingService>(
    function: IEncodingService
    begin
      Result := TEncodingServiceImpl.Create;
    end,
    slSingleton);

  // Password Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IPasswordService>(
    function: IPasswordService
    begin
      Result := TPasswordServiceImpl.Create;
    end,
    slSingleton);

  // Random Service - Singleton (thread-safe with internal locking)
  Container.RegisterFactory<IRandomService>(
    function: IRandomService
    begin
      Result := TRandomServiceImpl.Create;
    end,
    slSingleton);

  // Crypto Service (AES) - Singleton (stateless, thread-safe)
  Container.RegisterFactory<ICryptoService>(
    function: ICryptoService
    begin
      Result := TCryptoServiceImpl.Create;
    end,
    slSingleton);

  // CRC Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<ICRCService>(
    function: ICRCService
    begin
      Result := TCRCServiceImpl.Create;
    end,
    slSingleton);
end;

procedure RegisterMathServices(Container: TIoCContainer);
begin
  // Statistics Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IStatisticsService>(
    function: IStatisticsService
    begin
      Result := TStatisticsServiceImpl.Create;
    end,
    slSingleton);

  // Math Utils Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IMathUtilsService>(
    function: IMathUtilsService
    begin
      Result := TMathUtilsServiceImpl.Create;
    end,
    slSingleton);

  // Interpolation Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IInterpolationService>(
    function: IInterpolationService
    begin
      Result := TInterpolationServiceImpl.Create;
    end,
    slSingleton);

  // Easing Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<IEasingService>(
    function: IEasingService
    begin
      Result := TEasingServiceImpl.Create;
    end,
    slSingleton);

  // Random Distribution Service - Singleton (thread-safe)
  Container.RegisterFactory<IRandomDistributionService>(
    function: IRandomDistributionService
    begin
      Result := TRandomDistributionServiceImpl.Create;
    end,
    slSingleton);
end;

procedure RegisterSerializationServices(Container: TIoCContainer);
begin
  // Serialization Service - Singleton (stateless, thread-safe)
  Container.RegisterFactory<ISerializationService>(
    function: ISerializationService
    begin
      Result := TSerializationServiceImpl.Create;
    end,
    slSingleton);
end;

procedure RegisterProtectionServices(Container: TIoCContainer;
  const DefaultPassword: string);
begin
  // Basic Protection Service - Singleton
  Container.RegisterFactory<IBasicProtectionService>(
    function: IBasicProtectionService
    begin
      Result := TBasicProtectionServiceImpl.Create(DefaultPassword);
    end,
    slSingleton);

  // Anti-Tamper Service - Transient (requires configuration)
  Container.RegisterFactory<IAntiTamperService>(
    function: IAntiTamperService
    begin
      Result := TAntiTamperServiceImpl.Create;
    end,
    slTransient);
end;

procedure RegisterFrameworkServices(Container: TIoCContainer);
var
  RuntimeFactory: TServiceFactory<IRuntimeContext>;
begin
  // Register framework facades in IoC container. These factories return
  // global instances but do not transfer ownership to the container.
  RuntimeFactory :=
    function: IRuntimeContext
    begin
      Result := RuntimeContext;
    end;
  Container.RegisterFactory<IRuntimeContext>(RuntimeFactory);

  // No startup side effects here. Runtime lifecycle belongs to RuntimeContext
  // or explicit application bootstrap, not service registration.
end;

procedure RegisterDefaultRuntimeComponents(Context: IRuntimeContext;
  const ManagerDBPath: string; IncludeManager: Boolean);
begin
  if Context = nil then
    raise EArgumentNilException.Create('Context');

  if IncludeManager then
    Context.RegisterComponent(TDeepBaseManagerRuntimeComponent.Create(ManagerDBPath));

  Context.RegisterComponent(TIoCRuntimeComponent.Create);
  Context.RegisterComponent(TEventBusRuntimeComponent.Create);
  Context.RegisterComponent(TSchedulerRuntimeComponent.Create);
  Context.RegisterComponent(TWorkerQueueRuntimeComponent.Create);
end;

procedure RegisterDefaultServices(Container: TIoCContainer);
begin
  // Register all service categories
  RegisterCryptoServices(Container);
  RegisterMathServices(Container);
  RegisterSerializationServices(Container);
  RegisterProtectionServices(Container, '');
  RegisterFrameworkServices(Container);
end;

function AreServicesRegistered(Container: TIoCContainer): Boolean;
begin
  // Check if core services are registered
  Result := Container.IsRegistered<IHashService> and
            Container.IsRegistered<IEncodingService> and
            Container.IsRegistered<IRandomService>;
end;

end.
