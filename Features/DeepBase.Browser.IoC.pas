{ ============================================================================
  DeepBase.Browser.IoC
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : One-line IoC registration for the Browser Automation
                framework, mirroring TICIoCRegistration from the
                IntentClarification module.

  Usage (downstream):
    var Container := TIoCContainer.Create;
    TBrowserIoCRegistration.RegisterAll(Container);
    // Container now resolves IJSScriptStore, IBrowserRecovery, IPageDriver
    // and TBrowserService is wired with the same recovery instance.

  BUG-BA-028 fix: align Browser DX with IntentClarification.
  ============================================================================ }

unit DeepBase.Browser.IoC;

interface

uses
  System.SysUtils,
  DeepBase.IoC,
  DeepBase.Browser.Types,
  DeepBase.Browser.PageDriver;

type
  TBrowserIoCRegistration = class
  public
    class procedure RegisterAll(AContainer: TIoCContainer); overload; static;
    class procedure RegisterAll(AContainer: TIoCContainer;
      const APageDriverConfig: TPageDriverConfig); overload; static;

    class procedure WireServiceToRecovery(
      ARecovery: IBrowserRecovery); static;
  end;

implementation

uses
  DeepBase.Browser.ScriptStore,
  DeepBase.Browser.Recovery,
  DeepBase.Browser.Service,
  DeepBase.Browser.Registry,
  DeepBase.Logging;

{ TBrowserIoCRegistration }

class procedure TBrowserIoCRegistration.RegisterAll(
  AContainer: TIoCContainer);
begin
  RegisterAll(AContainer, TPageDriverConfig.Default);
end;

class procedure TBrowserIoCRegistration.RegisterAll(
  AContainer: TIoCContainer;
  const APageDriverConfig: TPageDriverConfig);
var
  LStore: IJSScriptStore;
  LRecovery: IBrowserRecovery;
  LDriver: IPageDriver;
begin
  if AContainer = nil then
    raise EArgumentNilException.Create('AContainer cannot be nil');

  // ScriptStore singleton
  LStore := ScriptStore;
  AContainer.RegisterSingleton<IJSScriptStore>(LStore);

  // Recovery singleton
  LRecovery := BrowserRecovery;
  AContainer.RegisterSingleton<IBrowserRecovery>(LRecovery);

  // PageDriver singleton
  LDriver := TPageDriver.Create(APageDriverConfig);
  AContainer.RegisterSingleton<IPageDriver>(LDriver);

  TBrowserService.SetRecovery(LRecovery);

  WireServiceToRecovery(LRecovery);

  Logger.Info('Browser.IoC: ScriptStore + Recovery + PageDriver registered',
    'TBrowserIoCRegistration');
end;

class procedure TBrowserIoCRegistration.WireServiceToRecovery(
  ARecovery: IBrowserRecovery);
var
  LEvents: IBrowserRecoveryEvents;
begin
  if ARecovery = nil then
    Exit;
  if not Supports(ARecovery, IBrowserRecoveryEvents, LEvents) then
    Exit;

  LEvents.OnSessionRebuilt :=
    procedure(const AOldSessionId: TBrowserSessionId;
      const ANewSession: IBrowserSession)
    begin
      TBrowserService.SetDefaultSession(ANewSession);
      Logger.InfoFmt(
        'Browser.IoC: Service session swapped (%s -> %s)',
        [AOldSessionId, ANewSession.GetSessionId],
        'TBrowserIoCRegistration');
    end;
end;

end.
