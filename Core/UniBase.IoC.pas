{ ============================================================================
  UniBase.IoC - Inversion of Control / Dependency Injection Container
  
  Version: 0.3
  Description: Provides a lightweight dependency injection container with
               support for different lifetimes, factory pattern, and interceptors.
  
  Thread Safety: The container is thread-safe for registration and resolution.
                 Scoped containers are not thread-safe by design.
  
  Usage:
    // Register
    Container.RegisterType<ILogger, TFileLogger>;
    Container.RegisterSingleton<IConfig, TAppConfig>;
    Container.RegisterFactory<IService>(
      function: IService begin Result := TMyService.Create; end);
    
    // Resolve
    var Logger := Container.Resolve<ILogger>;
    
    // Scoped
    var Scope := Container.CreateScope;
    try
      var ScopedService := Scope.Resolve<IScopedService>;
    finally
      Scope.Free;
    end;
  ============================================================================ }

unit UniBase.IoC;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Rtti,
  System.TypInfo,
  System.SyncObjs,
  System.Generics.Collections;

type
  // Forward declarations
  TIoCContainer = class;
  TIoCScope = class;
  
  // ============================================================================
  // Lifetime Types
  // ============================================================================
  
  /// <summary>
  /// Service lifetime management options
  /// </summary>
  TServiceLifetime = (
    /// <summary>New instance created for each resolution</summary>
    slTransient,
    /// <summary>Single instance shared across all resolutions</summary>
    slSingleton,
    /// <summary>Single instance per scope</summary>
    slScoped
  );
  
  // ============================================================================
  // Factory Types
  // ============================================================================
  
  /// <summary>
  /// Generic factory function
  /// </summary>
  TServiceFactory<T> = reference to function: T;
  
  /// <summary>
  /// Factory function with container access
  /// </summary>
  TServiceFactoryWithContainer<T> = reference to function(Container: TIoCContainer): T;
  
  /// <summary>
  /// Non-generic factory function
  /// </summary>
  TServiceFactoryFunc = reference to function(Container: TIoCContainer): TObject;
  
  // ============================================================================
  // Interceptor Types
  // ============================================================================
  
  /// <summary>
  /// Interceptor context passed to before/after handlers
  /// </summary>
  TInterceptorContext = record
    ServiceType: PTypeInfo;
    ImplementationType: PTypeInfo;
    Instance: TObject;
    MethodName: string;
    Args: TArray<TValue>;
    Result: TValue;
    Proceed: Boolean;
    
    class function Create(AServiceType, AImplType: PTypeInfo; 
      AInstance: TObject): TInterceptorContext; static;
  end;
  
  /// <summary>
  /// Interceptor procedure types
  /// </summary>
  TBeforeResolveProc = reference to procedure(var Context: TInterceptorContext);
  TAfterResolveProc = reference to procedure(var Context: TInterceptorContext);
  
  /// <summary>
  /// Interceptor interface
  /// </summary>
  IServiceInterceptor = interface
    ['{D4E5F6A7-B8C9-4D0E-1F2A-3B4C5D6E7F8A}']
    procedure BeforeResolve(var Context: TInterceptorContext);
    procedure AfterResolve(var Context: TInterceptorContext);
  end;
  
  // ============================================================================
  // Service Registration
  // ============================================================================
  
  /// <summary>
  /// Internal service registration record
  /// </summary>
  TServiceRegistration = class
  private
    FServiceType: PTypeInfo;
    FImplementationType: PTypeInfo;
    FLifetime: TServiceLifetime;
    FFactory: TServiceFactoryFunc;
    FSingletonInstance: TObject;
    FOwnsInstance: Boolean;
    FName: string;
  public
    constructor Create(AServiceType, AImplType: PTypeInfo; 
      ALifetime: TServiceLifetime; AFactory: TServiceFactoryFunc = nil);
    destructor Destroy; override;
    
    property ServiceType: PTypeInfo read FServiceType;
    property ImplementationType: PTypeInfo read FImplementationType;
    property Lifetime: TServiceLifetime read FLifetime;
    property Factory: TServiceFactoryFunc read FFactory write FFactory;
    property SingletonInstance: TObject read FSingletonInstance write FSingletonInstance;
    property OwnsInstance: Boolean read FOwnsInstance write FOwnsInstance;
    property Name: string read FName write FName;
  end;
  
  // ============================================================================
  // IoC Scope
  // ============================================================================
  
  /// <summary>
  /// Scoped container for scoped lifetime services
  /// </summary>
  TIoCScope = class
  private
    FParent: TIoCContainer;
    FScopedInstances: TObjectDictionary<PTypeInfo, TObject>;
    FDisposed: Boolean;
  public
    constructor Create(AParent: TIoCContainer);
    destructor Destroy; override;
    
    /// <summary>Resolve a service within this scope</summary>
    function Resolve<T>: T; overload;
    function Resolve(ServiceType: PTypeInfo): TObject; overload;
    
    /// <summary>Check if scope is disposed</summary>
    property IsDisposed: Boolean read FDisposed;
  end;
  
  // ============================================================================
  // IoC Container
  // ============================================================================
  
  /// <summary>
  /// Main IoC container class
  /// </summary>
  TIoCContainer = class
  private
    FRegistrations: TObjectDictionary<string, TServiceRegistration>;
    FNamedRegistrations: TObjectDictionary<string, TServiceRegistration>;
    FInterceptors: TList<IServiceInterceptor>;
    FLock: TCriticalSection;
    FRttiContext: TRttiContext;
    FResolving: TDictionary<PTypeInfo, Integer>;
    
    function GetRegistrationKey(ServiceType: PTypeInfo): string;
    function GetNamedKey(ServiceType: PTypeInfo; const Name: string): string;
    function FindRegistration(ServiceType: PTypeInfo; const Name: string = ''): TServiceRegistration;
    function CreateInstance(Reg: TServiceRegistration; Scope: TIoCScope = nil): TObject;
    function ResolveInternal(ServiceType: PTypeInfo; Scope: TIoCScope; 
      const Name: string = ''): TObject;
    procedure ApplyInterceptors(var Context: TInterceptorContext; IsBefore: Boolean);
    procedure EnterResolving(ServiceType: PTypeInfo; out AlreadyResolving: Boolean);
    procedure LeaveResolving(ServiceType: PTypeInfo);
  public
    constructor Create;
    destructor Destroy; override;
    
    // ========================================================================
    // Registration Methods
    // ========================================================================
    
    /// <summary>Register interface to implementation mapping</summary>
    procedure RegisterType<TService: IInterface; TImplementation: class>; overload;
    procedure RegisterType<TService: IInterface; TImplementation: class>(
      Lifetime: TServiceLifetime); overload;
    procedure RegisterType<TService: IInterface; TImplementation: class>(
      Lifetime: TServiceLifetime; const Name: string); overload;
    
    /// <summary>Register as singleton</summary>
    procedure RegisterSingleton<TService: IInterface; TImplementation: class>; overload;
    procedure RegisterSingleton<TService: IInterface>(Instance: TService); overload;
    procedure RegisterSingleton<TService: IInterface>(Instance: TService; 
      const Name: string); overload;
    
    /// <summary>Register as transient (new instance each time)</summary>
    procedure RegisterTransient<TService: IInterface; TImplementation: class>;
    
    /// <summary>Register as scoped (one per scope)</summary>
    procedure RegisterScoped<TService: IInterface; TImplementation: class>;
    
    /// <summary>Register with factory function</summary>
    procedure RegisterFactory<TService: IInterface>(
      Factory: TServiceFactory<TService>); overload;
    procedure RegisterFactory<TService: IInterface>(
      Factory: TServiceFactory<TService>; Lifetime: TServiceLifetime); overload;
    procedure RegisterFactory<TService: IInterface>(
      Factory: TServiceFactoryWithContainer<TService>; Lifetime: TServiceLifetime); overload;
    
    /// <summary>Register class type (no interface)</summary>
    procedure RegisterClass<T: class>; overload;
    procedure RegisterClass<T: class>(Lifetime: TServiceLifetime); overload;
    
    // ========================================================================
    // Resolution Methods
    // ========================================================================
    
    /// <summary>Resolve a service</summary>
    function Resolve<T>: T; overload;
    function Resolve(ServiceType: PTypeInfo): TObject; overload;
    function Resolve<T>(const Name: string): T; overload;
    
    /// <summary>Try to resolve a service (returns nil if not registered)</summary>
    function TryResolve<T>(out Service: T): Boolean; overload;
    function TryResolve(ServiceType: PTypeInfo; out Instance: TObject): Boolean; overload;
    
    /// <summary>Check if a service is registered</summary>
    function IsRegistered<T>: Boolean; overload;
    function IsRegistered(ServiceType: PTypeInfo): Boolean; overload;
    function IsRegistered<T>(const Name: string): Boolean; overload;
    
    /// <summary>Resolve all registered implementations of a service</summary>
    function ResolveAll<T>: TArray<T>;
    
    // ========================================================================
    // Scope Management
    // ========================================================================
    
    /// <summary>Create a new scope</summary>
    function CreateScope: TIoCScope;
    
    // ========================================================================
    // Interceptor Management
    // ========================================================================
    
    /// <summary>Add an interceptor</summary>
    procedure AddInterceptor(Interceptor: IServiceInterceptor);
    
    /// <summary>Remove an interceptor</summary>
    procedure RemoveInterceptor(Interceptor: IServiceInterceptor);
    
    /// <summary>Clear all interceptors</summary>
    procedure ClearInterceptors;
    
    // ========================================================================
    // Utility Methods
    // ========================================================================
    
    /// <summary>Clear all registrations</summary>
    procedure Clear;
    
    /// <summary>Get count of registrations</summary>
    function RegistrationCount: Integer;
  end;
  
  // ============================================================================
  // Exception Types
  // ============================================================================
  
  EIoCException = class(Exception);
  EServiceNotRegisteredException = class(EIoCException);
  ECircularDependencyException = class(EIoCException);
  EScopeDisposedException = class(EIoCException);
  
  // ============================================================================
  // Global Container
  // ============================================================================

/// <summary>Get the global IoC container instance</summary>
function GlobalContainer: TIoCContainer;

/// <summary>Set a custom global container (for testing)</summary>
procedure SetGlobalContainer(Container: TIoCContainer);

implementation

var
  FGlobalContainer: TIoCContainer = nil;
  FGlobalContainerLock: TCriticalSection = nil;

function GlobalContainer: TIoCContainer;
begin
  if FGlobalContainer = nil then
  begin
    FGlobalContainerLock.Enter;
    try
      if FGlobalContainer = nil then
        FGlobalContainer := TIoCContainer.Create;
    finally
      FGlobalContainerLock.Leave;
    end;
  end;
  Result := FGlobalContainer;
end;

procedure SetGlobalContainer(Container: TIoCContainer);
begin
  FGlobalContainerLock.Enter;
  try
    if (FGlobalContainer <> nil) and (FGlobalContainer <> Container) then
      FGlobalContainer.Free;
    FGlobalContainer := Container;
  finally
    FGlobalContainerLock.Leave;
  end;
end;

// ============================================================================
// TInterceptorContext
// ============================================================================

class function TInterceptorContext.Create(AServiceType, AImplType: PTypeInfo;
  AInstance: TObject): TInterceptorContext;
begin
  Result.ServiceType := AServiceType;
  Result.ImplementationType := AImplType;
  Result.Instance := AInstance;
  Result.MethodName := '';
  Result.Args := nil;
  Result.Result := TValue.Empty;
  Result.Proceed := True;
end;

// ============================================================================
// TServiceRegistration
// ============================================================================

constructor TServiceRegistration.Create(AServiceType, AImplType: PTypeInfo;
  ALifetime: TServiceLifetime; AFactory: TServiceFactoryFunc);
begin
  inherited Create;
  FServiceType := AServiceType;
  FImplementationType := AImplType;
  FLifetime := ALifetime;
  FFactory := AFactory;
  FSingletonInstance := nil;
  FOwnsInstance := True;
  FName := '';
end;

destructor TServiceRegistration.Destroy;
begin
  if FOwnsInstance and (FSingletonInstance <> nil) then
    FSingletonInstance.Free;
  inherited;
end;

// ============================================================================
// TIoCScope
// ============================================================================

constructor TIoCScope.Create(AParent: TIoCContainer);
begin
  inherited Create;
  FParent := AParent;
  FScopedInstances := TObjectDictionary<PTypeInfo, TObject>.Create([doOwnsValues]);
  FDisposed := False;
end;

destructor TIoCScope.Destroy;
begin
  FDisposed := True;
  FScopedInstances.Free;
  inherited;
end;

function TIoCScope.Resolve<T>: T;
var
  Instance: TObject;
begin
  Instance := Resolve(TypeInfo(T));
  if Instance.GetInterface(GetTypeData(TypeInfo(T))^.GUID, Result) then
    Exit;
  raise EIoCException.CreateFmt('Cannot cast to interface: %s', [GetTypeName(TypeInfo(T))]);
end;

function TIoCScope.Resolve(ServiceType: PTypeInfo): TObject;
begin
  if FDisposed then
    raise EScopeDisposedException.Create('Cannot resolve from disposed scope');
  Result := FParent.ResolveInternal(ServiceType, Self);
end;

// ============================================================================
// TIoCContainer
// ============================================================================

constructor TIoCContainer.Create;
begin
  inherited Create;
  FRegistrations := TObjectDictionary<string, TServiceRegistration>.Create([doOwnsValues]);
  FNamedRegistrations := TObjectDictionary<string, TServiceRegistration>.Create([doOwnsValues]);
  FInterceptors := TList<IServiceInterceptor>.Create;
  FLock := TCriticalSection.Create;
  FRttiContext := TRttiContext.Create;
  FResolving := TDictionary<PTypeInfo, Integer>.Create;
end;

destructor TIoCContainer.Destroy;
begin
  FLock.Enter;
  try
    FInterceptors.Free;
    FNamedRegistrations.Free;
    FRegistrations.Free;
    FResolving.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  FRttiContext.Free;
  inherited;
end;

function TIoCContainer.GetRegistrationKey(ServiceType: PTypeInfo): string;
begin
  Result := GetTypeName(ServiceType);
end;

function TIoCContainer.GetNamedKey(ServiceType: PTypeInfo; const Name: string): string;
begin
  Result := GetTypeName(ServiceType) + '#' + Name;
end;

function TIoCContainer.FindRegistration(ServiceType: PTypeInfo; 
  const Name: string): TServiceRegistration;
var
  Key: string;
begin
  Result := nil;
  FLock.Enter;
  try
    if Name <> '' then
    begin
      Key := GetNamedKey(ServiceType, Name);
      FNamedRegistrations.TryGetValue(Key, Result);
    end
    else
    begin
      Key := GetRegistrationKey(ServiceType);
      FRegistrations.TryGetValue(Key, Result);
    end;
  finally
    FLock.Leave;
  end;
end;

function TIoCContainer.CreateInstance(Reg: TServiceRegistration; 
  Scope: TIoCScope): TObject;
var
  RttiType: TRttiType;
  RttiMethod: TRttiMethod;
  Params: TArray<TRttiParameter>;
  Args: TArray<TValue>;
  I: Integer;
  ParamType: PTypeInfo;
  ParamInstance: TObject;
begin
  // Use factory if available
  if Assigned(Reg.Factory) then
    Exit(Reg.Factory(Self));
  
  // Use RTTI to create instance
  RttiType := FRttiContext.GetType(Reg.ImplementationType);
  if RttiType = nil then
    raise EIoCException.CreateFmt('Cannot get RTTI for type: %s', 
      [GetTypeName(Reg.ImplementationType)]);
  
  // Find constructor
  for RttiMethod in RttiType.GetMethods do
  begin
    if RttiMethod.IsConstructor and (RttiMethod.Name = 'Create') then
    begin
      Params := RttiMethod.GetParameters;
      SetLength(Args, Length(Params));
      
      // Resolve constructor parameters
      for I := 0 to High(Params) do
      begin
        ParamType := Params[I].ParamType.Handle;
        
        // Try to resolve parameter from container
        if Scope <> nil then
          ParamInstance := ResolveInternal(ParamType, Scope)
        else if TryResolve(ParamType, ParamInstance) then
          // Got it
        else
          raise EIoCException.CreateFmt('Cannot resolve constructor parameter: %s for type: %s',
            [Params[I].Name, GetTypeName(Reg.ImplementationType)]);
        
        Args[I] := TValue.From<TObject>(ParamInstance);
      end;
      
      Result := RttiMethod.Invoke(RttiType.AsInstance.MetaclassType, Args).AsObject;
      Exit;
    end;
  end;
  
  // No constructor found, try parameterless create
  if RttiType.AsInstance <> nil then
    Result := RttiType.AsInstance.MetaclassType.Create
  else
    raise EIoCException.CreateFmt('Cannot create instance of type: %s', 
      [GetTypeName(Reg.ImplementationType)]);
end;

function TIoCContainer.ResolveInternal(ServiceType: PTypeInfo; Scope: TIoCScope;
  const Name: string): TObject;
var
  Reg: TServiceRegistration;
  Context: TInterceptorContext;
  AlreadyResolving: Boolean;
begin
  Result := nil;

  // 检测循环依赖：同一 ServiceType 在当前解析栈中再次出现
  EnterResolving(ServiceType, AlreadyResolving);
  if AlreadyResolving then
  begin
    LeaveResolving(ServiceType);
    raise ECircularDependencyException.CreateFmt('Circular dependency detected while resolving %s',
      [GetTypeName(ServiceType)]);
  end;

  try
    Reg := FindRegistration(ServiceType, Name);
    
    if Reg = nil then
      raise EServiceNotRegisteredException.CreateFmt('Service not registered: %s', 
        [GetTypeName(ServiceType)]);
    
    case Reg.Lifetime of
      slTransient:
        Result := CreateInstance(Reg, Scope);
        
      slSingleton:
        begin
          FLock.Enter;
          try
            if Reg.SingletonInstance = nil then
              Reg.SingletonInstance := CreateInstance(Reg, Scope);
            Result := Reg.SingletonInstance;
          finally
            FLock.Leave;
          end;
        end;
        
      slScoped:
        begin
          if Scope = nil then
            raise EIoCException.Create('Scoped service requires a scope. Use CreateScope.');
          
          if not Scope.FScopedInstances.TryGetValue(ServiceType, Result) then
          begin
            Result := CreateInstance(Reg, Scope);
            Scope.FScopedInstances.Add(ServiceType, Result);
          end;
        end;
    end;
    
    // Apply interceptors
    if FInterceptors.Count > 0 then
    begin
      Context := TInterceptorContext.Create(ServiceType, Reg.ImplementationType, Result);
      ApplyInterceptors(Context, False); // AfterResolve
      if Context.Instance <> Result then
        Result := Context.Instance;
    end;
  finally
    LeaveResolving(ServiceType);
  end;
end;

procedure TIoCContainer.ApplyInterceptors(var Context: TInterceptorContext; 
  IsBefore: Boolean);
var
  Interceptor: IServiceInterceptor;
begin
  FLock.Enter;
  try
    for Interceptor in FInterceptors do
    begin
      if IsBefore then
        Interceptor.BeforeResolve(Context)
      else
        Interceptor.AfterResolve(Context);
      
      if not Context.Proceed then
        Break;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.EnterResolving(ServiceType: PTypeInfo; out AlreadyResolving: Boolean);
var
  Count: Integer;
begin
  FLock.Enter;
  try
    if not FResolving.TryGetValue(ServiceType, Count) then
      Count := 0;
    AlreadyResolving := Count > 0;
    Inc(Count);
    FResolving.AddOrSetValue(ServiceType, Count);
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.LeaveResolving(ServiceType: PTypeInfo);
var
  Count: Integer;
begin
  FLock.Enter;
  try
    if FResolving.TryGetValue(ServiceType, Count) then
    begin
      Dec(Count);
      if Count <= 0 then
        FResolving.Remove(ServiceType)
      else
        FResolving.AddOrSetValue(ServiceType, Count);
    end;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Registration Methods
// ============================================================================

procedure TIoCContainer.RegisterType<TService, TImplementation>;
begin
  RegisterType<TService, TImplementation>(slTransient);
end;

procedure TIoCContainer.RegisterType<TService, TImplementation>(
  Lifetime: TServiceLifetime);
begin
  RegisterType<TService, TImplementation>(Lifetime, '');
end;

procedure TIoCContainer.RegisterType<TService, TImplementation>(
  Lifetime: TServiceLifetime; const Name: string);
var
  Reg: TServiceRegistration;
  Key: string;
begin
  Reg := TServiceRegistration.Create(TypeInfo(TService), TypeInfo(TImplementation), Lifetime);
  Reg.Name := Name;
  
  FLock.Enter;
  try
    if Name <> '' then
    begin
      Key := GetNamedKey(TypeInfo(TService), Name);
      FNamedRegistrations.AddOrSetValue(Key, Reg);
    end
    else
    begin
      Key := GetRegistrationKey(TypeInfo(TService));
      FRegistrations.AddOrSetValue(Key, Reg);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.RegisterSingleton<TService, TImplementation>;
begin
  RegisterType<TService, TImplementation>(slSingleton);
end;

procedure TIoCContainer.RegisterSingleton<TService>(Instance: TService);
begin
  RegisterSingleton<TService>(Instance, '');
end;

procedure TIoCContainer.RegisterSingleton<TService>(Instance: TService; 
  const Name: string);
var
  Reg: TServiceRegistration;
  Key: string;
  IntfInstance: IInterface;
  Obj: TObject;
begin
  Reg := TServiceRegistration.Create(TypeInfo(TService), nil, slSingleton);
  Reg.Name := Name;
  Reg.OwnsInstance := False; // Caller owns the instance
  
  // Get underlying object from interface
  // Note: TService is constrained to IInterface
  Obj := nil;
  // For interfaces, try to get the implementing object
  if Instance.QueryInterface(IInterface, IntfInstance) = S_OK then
  begin
    // Use RTTI or a known pattern to extract the object
    // Most Delphi objects implementing interfaces inherit from TInterfacedObject
    // and the interface reference points to the object instance
    Obj := IntfInstance as TObject;
  end;
  
  Reg.SingletonInstance := Obj;
  
  FLock.Enter;
  try
    if Name <> '' then
    begin
      Key := GetNamedKey(TypeInfo(TService), Name);
      FNamedRegistrations.AddOrSetValue(Key, Reg);
    end
    else
    begin
      Key := GetRegistrationKey(TypeInfo(TService));
      FRegistrations.AddOrSetValue(Key, Reg);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.RegisterTransient<TService, TImplementation>;
begin
  RegisterType<TService, TImplementation>(slTransient);
end;

procedure TIoCContainer.RegisterScoped<TService, TImplementation>;
begin
  RegisterType<TService, TImplementation>(slScoped);
end;

procedure TIoCContainer.RegisterFactory<TService>(Factory: TServiceFactory<TService>);
begin
  RegisterFactory<TService>(Factory, slTransient);
end;

procedure TIoCContainer.RegisterFactory<TService>(Factory: TServiceFactory<TService>;
  Lifetime: TServiceLifetime);
var
  Reg: TServiceRegistration;
  Key: string;
begin
  Reg := TServiceRegistration.Create(TypeInfo(TService), nil, Lifetime);
  Reg.Factory := function(Container: TIoCContainer): TObject
    begin
      Result := Factory() as TObject;
    end;
  
  FLock.Enter;
  try
    Key := GetRegistrationKey(TypeInfo(TService));
    FRegistrations.AddOrSetValue(Key, Reg);
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.RegisterFactory<TService>(
  Factory: TServiceFactoryWithContainer<TService>; Lifetime: TServiceLifetime);
var
  Reg: TServiceRegistration;
  Key: string;
begin
  Reg := TServiceRegistration.Create(TypeInfo(TService), nil, Lifetime);
  Reg.Factory := function(Container: TIoCContainer): TObject
    begin
      Result := Factory(Container) as TObject;
    end;
  
  FLock.Enter;
  try
    Key := GetRegistrationKey(TypeInfo(TService));
    FRegistrations.AddOrSetValue(Key, Reg);
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.RegisterClass<T>;
begin
  RegisterClass<T>(slTransient);
end;

procedure TIoCContainer.RegisterClass<T>(Lifetime: TServiceLifetime);
var
  Reg: TServiceRegistration;
  Key: string;
begin
  Reg := TServiceRegistration.Create(TypeInfo(T), TypeInfo(T), Lifetime);
  
  FLock.Enter;
  try
    Key := GetRegistrationKey(TypeInfo(T));
    FRegistrations.AddOrSetValue(Key, Reg);
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Resolution Methods
// ============================================================================

function TIoCContainer.Resolve<T>: T;
var
  Instance: TObject;
  TypeData: PTypeData;
  ServiceTypeInfo: PTypeInfo;
  V: TValue;
begin
  ServiceTypeInfo := TypeInfo(T);
  Instance := ResolveInternal(ServiceTypeInfo, nil);
  
  // Handle interface types
  if ServiceTypeInfo^.Kind = tkInterface then
  begin
    TypeData := GetTypeData(ServiceTypeInfo);
    if not Instance.GetInterface(TypeData^.GUID, Result) then
      raise EIoCException.CreateFmt('Cannot cast to interface: %s', [GetTypeName(ServiceTypeInfo)]);
  end
  else
  begin
    // Handle class types using TValue to avoid direct cast issues
    V := TValue.From<TObject>(Instance);
    Result := V.AsType<T>;
  end;
end;

function TIoCContainer.Resolve(ServiceType: PTypeInfo): TObject;
begin
  Result := ResolveInternal(ServiceType, nil);
end;

function TIoCContainer.Resolve<T>(const Name: string): T;
var
  Instance: TObject;
  TypeData: PTypeData;
  ServiceTypeInfo: PTypeInfo;
  V: TValue;
begin
  ServiceTypeInfo := TypeInfo(T);
  Instance := ResolveInternal(ServiceTypeInfo, nil, Name);
  
  if ServiceTypeInfo^.Kind = tkInterface then
  begin
    TypeData := GetTypeData(ServiceTypeInfo);
    if not Instance.GetInterface(TypeData^.GUID, Result) then
      raise EIoCException.CreateFmt('Cannot cast to interface: %s', [GetTypeName(ServiceTypeInfo)]);
  end
  else
  begin
    V := TValue.From<TObject>(Instance);
    Result := V.AsType<T>;
  end;
end;

function TIoCContainer.TryResolve<T>(out Service: T): Boolean;
var
  Instance: TObject;
  ServiceTypeInfo: PTypeInfo;
  V: TValue;
begin
  ServiceTypeInfo := TypeInfo(T);
  Result := TryResolve(ServiceTypeInfo, Instance);
  if Result then
  begin
    if ServiceTypeInfo^.Kind = tkInterface then
    begin
      if not Instance.GetInterface(GetTypeData(ServiceTypeInfo)^.GUID, Service) then
        Result := False;
    end
    else
    begin
      V := TValue.From<TObject>(Instance);
      Service := V.AsType<T>;
    end;
  end;
end;

function TIoCContainer.TryResolve(ServiceType: PTypeInfo; 
  out Instance: TObject): Boolean;
var
  Reg: TServiceRegistration;
begin
  Reg := FindRegistration(ServiceType);
  Result := Reg <> nil;
  if Result then
  begin
    try
      Instance := ResolveInternal(ServiceType, nil);
    except
      Result := False;
      Instance := nil;
    end;
  end
  else
    Instance := nil;
end;

function TIoCContainer.IsRegistered<T>: Boolean;
begin
  Result := IsRegistered(TypeInfo(T));
end;

function TIoCContainer.IsRegistered(ServiceType: PTypeInfo): Boolean;
begin
  Result := FindRegistration(ServiceType) <> nil;
end;

function TIoCContainer.IsRegistered<T>(const Name: string): Boolean;
begin
  Result := FindRegistration(TypeInfo(T), Name) <> nil;
end;

function TIoCContainer.ResolveAll<T>: TArray<T>;
var
  Key: string;
  Reg: TServiceRegistration;
  List: TList<T>;
  Instance: TObject;
  TypeData: PTypeData;
  Intf: T;
begin
  List := TList<T>.Create;
  try
    TypeData := GetTypeData(TypeInfo(T));
    
    FLock.Enter;
    try
      // Check both regular and named registrations
      for Key in FRegistrations.Keys do
      begin
        if Key.StartsWith(GetTypeName(TypeInfo(T))) then
        begin
          Reg := FRegistrations[Key];
          Instance := CreateInstance(Reg, nil);
          if Instance.GetInterface(TypeData^.GUID, Intf) then
            List.Add(Intf);
        end;
      end;
      
      for Key in FNamedRegistrations.Keys do
      begin
        if Key.StartsWith(GetTypeName(TypeInfo(T))) then
        begin
          Reg := FNamedRegistrations[Key];
          Instance := CreateInstance(Reg, nil);
          if Instance.GetInterface(TypeData^.GUID, Intf) then
            List.Add(Intf);
        end;
      end;
    finally
      FLock.Leave;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

// ============================================================================
// Scope Management
// ============================================================================

function TIoCContainer.CreateScope: TIoCScope;
begin
  Result := TIoCScope.Create(Self);
end;

// ============================================================================
// Interceptor Management
// ============================================================================

procedure TIoCContainer.AddInterceptor(Interceptor: IServiceInterceptor);
begin
  FLock.Enter;
  try
    FInterceptors.Add(Interceptor);
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.RemoveInterceptor(Interceptor: IServiceInterceptor);
begin
  FLock.Enter;
  try
    FInterceptors.Remove(Interceptor);
  finally
    FLock.Leave;
  end;
end;

procedure TIoCContainer.ClearInterceptors;
begin
  FLock.Enter;
  try
    FInterceptors.Clear;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// Utility Methods
// ============================================================================

procedure TIoCContainer.Clear;
begin
  FLock.Enter;
  try
    FRegistrations.Clear;
    FNamedRegistrations.Clear;
    FInterceptors.Clear;
  finally
    FLock.Leave;
  end;
end;

function TIoCContainer.RegistrationCount: Integer;
begin
  FLock.Enter;
  try
    Result := FRegistrations.Count + FNamedRegistrations.Count;
  finally
    FLock.Leave;
  end;
end;

initialization
  FGlobalContainerLock := TCriticalSection.Create;

finalization
  if FGlobalContainer <> nil then
    FreeAndNil(FGlobalContainer);
  FreeAndNil(FGlobalContainerLock);

end.
