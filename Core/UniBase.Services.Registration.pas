{ ============================================================================
  UniBase.Services.Registration - Service Registration Module

  Version: 1.0
  Description: Registers all service implementations with the IoC container.
               Call RegisterDefaultServices to configure the global container
               with default implementations.

  Usage:
    uses
      UniBase.IoC,
      UniBase.Services.Registration;

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

unit UniBase.Services.Registration;

interface

uses
  UniBase.IoC,
  UniBase.RuntimeContext;

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
  UniBase.Services.Interfaces,
  UniBase.Services.Crypto,
  UniBase.Services.Math,
  UniBase.Services.Serialization,
  UniBase.Services.Protection,
  UniBase.EventBus,
  UniBase.Scheduler,
  UniBase.WorkerQueue,
  UniBase.Manager,
  UniBase.Interfaces;

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
  var UnusedPath := ManagerDBPath;
  var UnusedInclude := IncludeManager;

  if Context = nil then
    raise EArgumentNilException.Create('Context');
  // Runtime component factories are being migrated to UniBase.RuntimeContext.
  // Keep this API side-effect free until the new factories are exported.
  UnusedPath := UnusedPath;
  UnusedInclude := UnusedInclude;
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
