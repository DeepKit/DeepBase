{ ============================================================================
  DeepBase.IntentClarification.IoC - IoC Container Integration

  Registers all IntentClarification components into the DeepBase IoC container.
  Provides a single entry point (RegisterAll) for application startup.

  Phase 2 Task 20: IoC Integration
    - Registers IClarificationEngine -> TClarificationEngine (Singleton)
    - Registers ILevelProvider implementations (L0-L4)
    - Registers TSignalDetector, TBudgetController, TGracefulExitHandler,
      TPostureDepthRouter as singletons
    - Engine constructor overload accepts TIoCContainer and resolves deps

  Requirements: 20.1, 20.2
  ============================================================================ }

unit DeepBase.IntentClarification.IoC;

interface

uses
  System.SysUtils,
  DeepBase.IoC,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Engine,
  DeepBase.IntentClarification.Router,
  DeepBase.IntentClarification.SignalDetector,
  DeepBase.IntentClarification.Budget,
  DeepBase.IntentClarification.Exit,
  DeepBase.IntentClarification.Rapport,
  DeepBase.IntentClarification.Provider.L0,
  DeepBase.IntentClarification.Provider.L1,
  DeepBase.IntentClarification.Provider.L2,
  DeepBase.IntentClarification.Provider.L3,
  DeepBase.IntentClarification.Provider.L4,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>
  /// IoC registration helper for the IntentClarification module.
  /// Call RegisterAll during application startup to wire all IC components.
  /// </summary>
  TICIoCRegistration = class
  public
    /// <summary>
    /// Registers all IntentClarification components into the IoC container.
    ///
    /// Singletons:
    ///   IClarificationEngine -> TClarificationEngine
    ///   TSignalDetector
    ///   TBudgetController
    ///   TGracefulExitHandler
    ///   TPostureDepthRouter
    ///   TRapportLayer
    ///
    /// Transient (overridable):
    ///   ILevelProvider -> TL0BackgroundProvider (named 'L0')
    ///   ILevelProvider -> TL1SlotProvider (named 'L1')
    /// </summary>
    class procedure RegisterAll(AContainer: TIoCContainer); static;

    /// <summary>
    /// Creates and configures a TClarificationEngine by resolving all
    /// dependencies from the given IoC container.
    /// Use this when you need an engine instance wired via IoC.
    /// </summary>
    class function CreateEngineFromContainer(AContainer: TIoCContainer): IClarificationEngine; static;
  end;

implementation

{ TICIoCRegistration }

class procedure TICIoCRegistration.RegisterAll(AContainer: TIoCContainer);
var
  LProvider: ILevelProvider;
begin
  if AContainer = nil then
    raise EArgumentNilException.Create('AContainer cannot be nil');

  // Core engine (Singleton - one engine instance per application)
  AContainer.RegisterSingleton<IClarificationEngine, TClarificationEngine>;

  // Internal sub-systems (Singleton - stateless/shared services)
  AContainer.RegisterClass<TSignalDetector>(slSingleton);
  AContainer.RegisterClass<TBudgetController>(slSingleton);
  AContainer.RegisterClass<TGracefulExitHandler>(slSingleton);
  AContainer.RegisterClass<TPostureDepthRouter>(slSingleton);

  // Rapport layer (Singleton - maintains user profiles in memory)
  AContainer.RegisterClass<TRapportLayer>(slSingleton);

  // Default level providers (named registrations for multi-resolve).
  // Register instances because some provider constructors have optional
  // Delphi parameters that the generic IoC constructor resolver still tries
  // to resolve via RTTI.
  LProvider := TL0BackgroundProvider.Create;
  AContainer.RegisterSingleton<ILevelProvider>(LProvider, 'L0');
  LProvider := TL1SlotProvider.Create;
  AContainer.RegisterSingleton<ILevelProvider>(LProvider, 'L1');
  LProvider := TL2ProblemProvider.Create(nil);
  AContainer.RegisterSingleton<ILevelProvider>(LProvider, 'L2');
  LProvider := TL3ExpertProvider.Create(nil, nil);
  AContainer.RegisterSingleton<ILevelProvider>(LProvider, 'L3');
  LProvider := TL4RoundtableProvider.Create(nil, nil);
  AContainer.RegisterSingleton<ILevelProvider>(LProvider, 'L4');

  Log(ltInfo, 'IC.IoC: All components registered');
end;

class function TICIoCRegistration.CreateEngineFromContainer(
  AContainer: TIoCContainer): IClarificationEngine;
var
  LEngine: IClarificationEngine;
  LProviderL0: ILevelProvider;
  LProviderL1: ILevelProvider;
  LProviderL2: ILevelProvider;
  LProviderL3: ILevelProvider;
  LProviderL4: ILevelProvider;
begin
  if AContainer = nil then
    raise EArgumentNilException.Create('AContainer cannot be nil');

  // Resolve the engine singleton
  LEngine := AContainer.Resolve<IClarificationEngine>;

  // Register default providers from container
  if AContainer.IsRegistered<ILevelProvider>('L0') then
  begin
    LProviderL0 := AContainer.Resolve<ILevelProvider>('L0');
    LEngine.RegisterProvider(LProviderL0);
  end;

  if AContainer.IsRegistered<ILevelProvider>('L1') then
  begin
    LProviderL1 := AContainer.Resolve<ILevelProvider>('L1');
    LEngine.RegisterProvider(LProviderL1);
  end;

  if AContainer.IsRegistered<ILevelProvider>('L2') then
  begin
    LProviderL2 := AContainer.Resolve<ILevelProvider>('L2');
    LEngine.RegisterProvider(LProviderL2);
  end;

  if AContainer.IsRegistered<ILevelProvider>('L3') then
  begin
    LProviderL3 := AContainer.Resolve<ILevelProvider>('L3');
    LEngine.RegisterProvider(LProviderL3);
  end;

  if AContainer.IsRegistered<ILevelProvider>('L4') then
  begin
    LProviderL4 := AContainer.Resolve<ILevelProvider>('L4');
    LEngine.RegisterProvider(LProviderL4);
  end;

  Result := LEngine;
  Log(ltInfo, 'IC.IoC: Engine created from container with providers');
end;

end.
