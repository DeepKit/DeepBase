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
    // Container now resolves IJSScriptStore, IBrowserRecovery and
    // TBrowserService is wired with the same recovery instance.

  BUG-BA-028 fix: align Browser DX with IntentClarification.
  ============================================================================ }

unit DeepBase.Browser.IoC;

interface

uses
  System.SysUtils,
  DeepBase.IoC,
  DeepBase.Browser.Types;

type
  TBrowserIoCRegistration = class
  public
    /// <summary>
    /// Register Browser singletons into the supplied container.
    /// Registers:
    ///   IJSScriptStore   -> ScriptStore singleton
    ///   IBrowserRecovery -> BrowserRecovery singleton
    /// Also propagates the recovery instance to TBrowserService so the
    /// static facade and the IoC graph see the same object.
    /// </summary>
    class procedure RegisterAll(AContainer: TIoCContainer); static;

    /// <summary>
    /// Wire the recovery manager's session-rebuilt callback to
    /// TBrowserService.SetDefaultSession so Service.Session() always
    /// returns the most recently rebuilt session.
    /// </summary>
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
var
  LStore: IJSScriptStore;
  LRecovery: IBrowserRecovery;
begin
  if AContainer = nil then
    raise EArgumentNilException.Create('AContainer cannot be nil');

  // ScriptStore singleton (DB-backed JS template store)
  LStore := ScriptStore;
  AContainer.RegisterSingleton<IJSScriptStore>(LStore);

  // Recovery singleton (heartbeat / health / rebuild loop)
  LRecovery := BrowserRecovery;
  AContainer.RegisterSingleton<IBrowserRecovery>(LRecovery);

  // Make the static service facade observe the same recovery instance
  TBrowserService.SetRecovery(LRecovery);

  // Wire OnSessionRebuilt -> Service so downstream code that calls
  // TBrowserService.Session always sees the latest rebuilt session.
  WireServiceToRecovery(LRecovery);

  Logger.Info('Browser.IoC: ScriptStore + Recovery registered',
    'TBrowserIoCRegistration');
end;

class procedure TBrowserIoCRegistration.WireServiceToRecovery(
  ARecovery: IBrowserRecovery);
var
  LMgr: TBrowserRecoveryManager;
begin
  if ARecovery = nil then
    Exit;
  // Only the concrete manager exposes OnSessionRebuilt; the interface
  // intentionally stays minimal.
  if not (ARecovery is TBrowserRecoveryManager) then
    Exit;

  LMgr := TBrowserRecoveryManager(ARecovery);
  LMgr.OnSessionRebuilt :=
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
