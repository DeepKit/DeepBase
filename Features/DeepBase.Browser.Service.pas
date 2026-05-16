{ ============================================================================
  DeepBase.Browser.Service
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Static facade for the Browser Automation framework.
                Provides global access to the default session, recovery
                manager, and session factory.
                Follows TSpeechService pattern from DeepBase.Speech.Service.
  ============================================================================ }

unit DeepBase.Browser.Service;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DeepBase.Browser.Types;

type
  TBrowserService = class
  private
    class var FDefaultSession: IBrowserSession;
    class var FRecovery: IBrowserRecovery;
    class var FLock: TCriticalSection;
  public
    // H8 fix: class constructor / destructor are single-threaded by the
    // Delphi RTL, removing the FLock <> nil race in finalization.
    class constructor Create;
    class destructor Destroy;

    class procedure SetDefaultSession(
      const ASession: IBrowserSession);
    class procedure SetRecovery(
      const ARecovery: IBrowserRecovery);
    class procedure Shutdown;

    class function Session: IBrowserSession;
    class function Recovery: IBrowserRecovery;
    class function IsReady: Boolean;
  end;

implementation

uses
  DeepBase.Browser.Recovery;

{ TBrowserService }
// BUG-BA-026 fix: actually use FLock for all field access.
// H8 fix: lifecycle managed by class constructor/destructor.

class constructor TBrowserService.Create;
begin
  FLock := TCriticalSection.Create;
end;

class destructor TBrowserService.Destroy;
begin
  Shutdown;
  FreeAndNil(FLock);
end;

class procedure TBrowserService.SetDefaultSession(
  const ASession: IBrowserSession);
begin
  FLock.Enter;
  try
    FDefaultSession := ASession;
  finally
    FLock.Leave;
  end;
end;

class procedure TBrowserService.SetRecovery(
  const ARecovery: IBrowserRecovery);
begin
  FLock.Enter;
  try
    FRecovery := ARecovery;
  finally
    FLock.Leave;
  end;
end;

class procedure TBrowserService.Shutdown;
begin
  // H8 fix: FLock guaranteed valid (created in class constructor, freed
  // in class destructor). No nil check needed.
  FLock.Enter;
  try
    FDefaultSession := nil;
    FRecovery := nil;
  finally
    FLock.Leave;
  end;
end;

class function TBrowserService.Session: IBrowserSession;
begin
  FLock.Enter;
  try
    Result := FDefaultSession;
  finally
    FLock.Leave;
  end;
end;

class function TBrowserService.Recovery: IBrowserRecovery;
begin
  FLock.Enter;
  try
    if FRecovery = nil then
      FRecovery := DeepBase.Browser.Recovery.BrowserRecovery;
    Result := FRecovery;
  finally
    FLock.Leave;
  end;
end;

class function TBrowserService.IsReady: Boolean;
begin
  FLock.Enter;
  try
    Result := FDefaultSession <> nil;
  finally
    FLock.Leave;
  end;
end;

end.
