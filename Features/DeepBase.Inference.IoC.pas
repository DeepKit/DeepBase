{ ============================================================================
  DeepBase.Inference.IoC
  ---------------------------------------------------------------------------
  Description : One-line IoC registration for the Inference framework.
                Reads config, creates runtime, initializes provider,
                registers singletons, wires static service facade.

  Usage (downstream):
    var Container := TIoCContainer.Create;
    TInferenceIoCRegistration.RegisterAll(Container);
  ============================================================================ }

unit DeepBase.Inference.IoC;

interface

uses
  System.SysUtils,
  DeepBase.IoC,
  DeepBase.Inference.Types;

type
  TInferenceIoCRegistration = class
  public
    class procedure RegisterAll(AContainer: TIoCContainer); static;
  end;

implementation

uses
  DeepBase.Inference.Runtime,
  DeepBase.Inference.Session,
  DeepBase.Inference.Service,
  DeepBase.Logging;

{ --- TInferenceIoCRegistration ------------------------------------------- }

class procedure TInferenceIoCRegistration.RegisterAll(
  AContainer: TIoCContainer);
var
  LConfig: TInferenceConfig;
  LRuntime: IInferenceRuntime;
  LFactory: IInferenceSessionFactory;
begin
  if AContainer = nil then
    raise EArgumentNilException.Create('AContainer cannot be nil');

  LConfig := TInferenceConfig.FromConfig;

  // Create and initialize the runtime with configured provider
  LRuntime := TInferenceRuntime.Create;
  try
    LRuntime.Initialize(LConfig);
    try
      // Register runtime as singleton
      AContainer.RegisterSingleton<IInferenceRuntime>(LRuntime);

      // Create session factory wired to the runtime
      LFactory := TInferenceSessionFactory.Create(LRuntime);
      AContainer.RegisterSingleton<IInferenceSessionFactory>(LFactory);

      // Wire the static service facade so downstream code can use
      // TInferenceService.CreateSession / Run directly
      TInferenceService.SetRuntime(LRuntime);
      TInferenceService.SetSessionFactory(LFactory);

      Logger.InfoFmt('Inference.IoC: registered (provider=%s)',
        [InferenceProviderToString(LConfig.Provider)], 'Inference');
    except
      LRuntime.Shutdown;
      raise;
    end;
  except
    on E: Exception do
    begin
      if not LRuntime.IsInitialized then
        LRuntime.Shutdown;
      raise;
    end;
  end;
end;

end.
