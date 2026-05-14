{ ============================================================================
  DeepBase.IntentClarification.Registration - Component Registration Facade

  Provides a simple facade for wiring up all engine components.
  ============================================================================ }

unit DeepBase.IntentClarification.Registration;

interface

uses
  System.SysUtils,
  DeepBase.IoC,
  DeepBase.LLM.Client,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces;

type
  TClarificationRegistration = class
  public
    class procedure RegisterAll(AContainer: TIoCContainer); static;

    class procedure RegisterDomainAdapter(const AEngine: IClarificationEngine;
      const AAdapter: IDomainAdapter); static;
    class procedure RegisterPresenter(const AEngine: IClarificationEngine;
      const APresenter: IPresenter); static;
    class procedure RegisterPersonaRegistry(const AEngine: IClarificationEngine;
      const ARegistry: IPersonaRegistry); static;
    class procedure RegisterLLM(const AEngine: IClarificationEngine;
      const ALLM: ILLMClient); static;
    class function ApplyPreset(const AEngine: IClarificationEngine;
      const APresetName: string): TPresetTemplate; static;
  end;

implementation

uses
  DeepBase.IntentClarification.IoC,
  DeepBase.IntentClarification.Templates,
  DeepBase.IntentClarification.Provider.L0,
  DeepBase.IntentClarification.Provider.L1,
  DeepBase.IntentClarification.Provider.L2,
  DeepBase.IntentClarification.Provider.L3,
  DeepBase.IntentClarification.Provider.L4;

{ TClarificationRegistration }

class procedure TClarificationRegistration.RegisterAll(AContainer: TIoCContainer);
begin
  TICIoCRegistration.RegisterAll(AContainer);
end;

class procedure TClarificationRegistration.RegisterDomainAdapter(
  const AEngine: IClarificationEngine; const AAdapter: IDomainAdapter);
begin
  if AEngine = nil then
    raise EArgumentNilException.Create('AEngine cannot be nil');
  AEngine.SetDomainAdapter(AAdapter);
end;

class procedure TClarificationRegistration.RegisterPresenter(
  const AEngine: IClarificationEngine; const APresenter: IPresenter);
begin
  if AEngine = nil then
    raise EArgumentNilException.Create('AEngine cannot be nil');
  AEngine.SetPresenter(APresenter);
end;

class procedure TClarificationRegistration.RegisterPersonaRegistry(
  const AEngine: IClarificationEngine; const ARegistry: IPersonaRegistry);
begin
  if AEngine = nil then
    raise EArgumentNilException.Create('AEngine cannot be nil');
  AEngine.SetPersonaRegistry(ARegistry);
end;

class procedure TClarificationRegistration.RegisterLLM(
  const AEngine: IClarificationEngine; const ALLM: ILLMClient);
begin
  if AEngine = nil then
    raise EArgumentNilException.Create('AEngine cannot be nil');

  AEngine.SetLLM(ALLM);
  AEngine.RegisterProvider(TL2ProblemProvider.Create(ALLM));
  AEngine.RegisterProvider(TL3ExpertProvider.Create(ALLM, nil));
  AEngine.RegisterProvider(TL4RoundtableProvider.Create(ALLM, nil));
end;

class function TClarificationRegistration.ApplyPreset(
  const AEngine: IClarificationEngine; const APresetName: string): TPresetTemplate;
var
  LManager: TPresetTemplateManager;
begin
  if AEngine = nil then
    raise EArgumentNilException.Create('AEngine cannot be nil');

  LManager := TPresetTemplateManager.Create;
  try
    Result := LManager.LoadTemplate(APresetName);
    AEngine.RegisterProvider(TL0BackgroundProvider.Create);
    AEngine.RegisterProvider(TL1SlotProvider.Create);
  finally
    LManager.Free;
  end;
end;

end.
