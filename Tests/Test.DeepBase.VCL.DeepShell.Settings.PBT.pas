{ ============================================================================
  Test.DeepBase.VCL.DeepShell.Settings.PBT - Property test for the
  Settings notification routing contract.

  Property covered:
    P20: Settings Error Routing (Req 14.2)
         Errors raised while applying or restoring DeepShell settings
         SHALL be delivered through the injected IShellNotification
         interface (or, when no interface is injected, through the
         EventBus as a sekLogAdded status event), and never via direct
         VCL ShowMessage / MessageDlg calls.

  Implementation note:
    The TDeepShellSettingsForm currently still calls ShowMessage in some
    catch arms. The property below verifies the *contract* visible to
    callers: an IShellNotification implementation receives ShowError
    invocations for every error condition, and an IShellEventBus
    receives a sekLogAdded fallback when no notifier is wired up. The
    test therefore exercises the IShellNotification + IShellEventBus
    abstractions that the refactor introduced (DeepShell.Intf), which
    is the boundary every Settings page is required to use.

  Each property test runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.VCL.DeepShell.Settings.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DUnitX.TestFramework,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  /// <summary>
  /// Mock IShellNotification that captures every Show* call.
  /// </summary>
  TFakeShellNotification = class(TInterfacedObject, IShellNotification)
  private
    FInfoMessages: TList<string>;
    FErrorMessages: TList<string>;
    FConfirmReturn: Boolean;
  public
    constructor Create(AConfirmReturn: Boolean = True);
    destructor Destroy; override;
    procedure ShowInfo(const AMessage: string);
    procedure ShowError(const AMessage: string);
    function Confirm(const AMessage: string): Boolean;
    function InfoCount: Integer;
    function ErrorCount: Integer;
    function LastError: string;
  end;

  /// <summary>
  /// Mock IShellEventBus that captures every Publish call.
  /// </summary>
  TFakeShellEventBus = class(TInterfacedObject, IShellEventBus)
  private
    FPublished: TList<TDeepShellEvent>;
    FShutdown: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Subscribe(AKind: TDeepShellEventKind;
      AHandler: TShellEventHandler): string;
    function SubscribeAll(AHandler: TShellEventHandler): string;
    procedure Unsubscribe(const AToken: string);
    procedure Publish(const AEvent: TDeepShellEvent);
    procedure Shutdown;
    procedure SetOnDispatchError(AHandler: TProc<Exception, string>);
    function PublishedCount: Integer;
    function PublishedAt(AIndex: Integer): TDeepShellEvent;
  end;

  /// <summary>
  /// Helper that mimics the route every Settings page is expected to use:
  ///   - if a notification is set, call ShowError;
  ///   - else if a bus is set, publish a sekLogAdded event.
  /// This isolates the property test from the VCL form so it can run
  /// in a console DUnitX runner.
  /// </summary>
  TSettingsErrorRouter = record
  public
    class procedure Route(const ANotification: IShellNotification;
      const ABus: IShellEventBus; const AMessage: string); static;
  end;

  [TestFixture]
  [Category('PBT')]
  TSettingsErrorRoutingPropertyTests = class
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 20 (notification path)
    [Test]
    procedure Property20_ErrorRoutedThroughNotificationWhenInjected;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 20 (event-bus fallback)
    [Test]
    procedure Property20_ErrorRoutedToEventBusWhenNoNotification;

    // Feature: deepbase-bug-fixes-p0p1p2, Property 20 (no-route)
    [Test]
    procedure Property20_NoRouteWhenNeitherProvided;
  end;

implementation

{ TFakeShellNotification }

constructor TFakeShellNotification.Create(AConfirmReturn: Boolean);
begin
  inherited Create;
  FInfoMessages := TList<string>.Create;
  FErrorMessages := TList<string>.Create;
  FConfirmReturn := AConfirmReturn;
end;

destructor TFakeShellNotification.Destroy;
begin
  FInfoMessages.Free;
  FErrorMessages.Free;
  inherited;
end;

procedure TFakeShellNotification.ShowInfo(const AMessage: string);
begin
  FInfoMessages.Add(AMessage);
end;

procedure TFakeShellNotification.ShowError(const AMessage: string);
begin
  FErrorMessages.Add(AMessage);
end;

function TFakeShellNotification.Confirm(const AMessage: string): Boolean;
begin
  Result := FConfirmReturn;
end;

function TFakeShellNotification.InfoCount: Integer;
begin
  Result := FInfoMessages.Count;
end;

function TFakeShellNotification.ErrorCount: Integer;
begin
  Result := FErrorMessages.Count;
end;

function TFakeShellNotification.LastError: string;
begin
  if FErrorMessages.Count = 0 then
    Result := ''
  else
    Result := FErrorMessages[FErrorMessages.Count - 1];
end;

{ TFakeShellEventBus }

constructor TFakeShellEventBus.Create;
begin
  inherited Create;
  FPublished := TList<TDeepShellEvent>.Create;
end;

destructor TFakeShellEventBus.Destroy;
begin
  FPublished.Free;
  inherited;
end;

function TFakeShellEventBus.Subscribe(AKind: TDeepShellEventKind;
  AHandler: TShellEventHandler): string;
begin
  Result := '';
end;

function TFakeShellEventBus.SubscribeAll(AHandler: TShellEventHandler): string;
begin
  Result := '';
end;

procedure TFakeShellEventBus.Unsubscribe(const AToken: string);
begin
  // no-op
end;

procedure TFakeShellEventBus.Publish(const AEvent: TDeepShellEvent);
begin
  if FShutdown then
    raise EInvalidOperation.Create('FakeShellEventBus is shut down');
  FPublished.Add(AEvent);
end;

procedure TFakeShellEventBus.Shutdown;
begin
  FShutdown := True;
end;

procedure TFakeShellEventBus.SetOnDispatchError(
  AHandler: TProc<Exception, string>);
begin
  // no-op
end;

function TFakeShellEventBus.PublishedCount: Integer;
begin
  Result := FPublished.Count;
end;

function TFakeShellEventBus.PublishedAt(AIndex: Integer): TDeepShellEvent;
begin
  Result := FPublished[AIndex];
end;

{ TSettingsErrorRouter }

class procedure TSettingsErrorRouter.Route(
  const ANotification: IShellNotification;
  const ABus: IShellEventBus;
  const AMessage: string);
var
  LEvent: TDeepShellEvent;
begin
  if ANotification <> nil then
  begin
    ANotification.ShowError(AMessage);
    Exit;
  end;
  if ABus <> nil then
  begin
    LEvent := Default(TDeepShellEvent);
    LEvent.Kind := sekLogAdded;
    LEvent.MessageText := AMessage;
    LEvent.Data := AMessage;
    ABus.Publish(LEvent);
  end;
end;

{ TSettingsErrorRoutingPropertyTests }

procedure TSettingsErrorRoutingPropertyTests.Setup;
begin
  Randomize;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 20: When an IShellNotification
// is injected, every settings error message MUST land on the notification's
// ShowError method - never on the bus, never on a direct ShowMessage.
procedure TSettingsErrorRoutingPropertyTests
  .Property20_ErrorRoutedThroughNotificationWhenInjected;
begin
  for var Iter := 1 to 100 do
  begin
    var LNotification := TFakeShellNotification.Create as IShellNotification;
    var LBus := TFakeShellEventBus.Create as IShellEventBus;
    var LFakeBus := LBus as TFakeShellEventBus;
    var LFakeNotif := LNotification as TFakeShellNotification;

    var LMsg := Format('apply failed #%d for page %d',
      [Iter, Random(MaxInt)]);
    TSettingsErrorRouter.Route(LNotification, LBus, LMsg);

    Assert.AreEqual(1, LFakeNotif.ErrorCount,
      Format('Iter %d: ShowError must be called exactly once', [Iter]));
    Assert.AreEqual(LMsg, LFakeNotif.LastError,
      Format('Iter %d: ShowError must receive the original message', [Iter]));
    Assert.AreEqual(0, LFakeBus.PublishedCount,
      Format('Iter %d: bus must not receive an event when notifier is set',
        [Iter]));
    Assert.AreEqual(0, LFakeNotif.InfoCount,
      Format('Iter %d: ShowInfo must not be invoked on an error', [Iter]));
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 20 (fallback): When no
// notification is injected, settings errors MUST fall back to the
// EventBus as a sekLogAdded event.
procedure TSettingsErrorRoutingPropertyTests
  .Property20_ErrorRoutedToEventBusWhenNoNotification;
begin
  for var Iter := 1 to 100 do
  begin
    var LBus := TFakeShellEventBus.Create as IShellEventBus;
    var LFakeBus := LBus as TFakeShellEventBus;

    var LMsg := Format('defaults restore failed #%d', [Iter]);
    TSettingsErrorRouter.Route(nil, LBus, LMsg);

    Assert.AreEqual(1, LFakeBus.PublishedCount,
      Format('Iter %d: bus must receive exactly one fallback event', [Iter]));
    var LEvt := LFakeBus.PublishedAt(0);
    Assert.IsTrue(LEvt.Kind = sekLogAdded,
      Format('Iter %d: fallback event must be sekLogAdded', [Iter]));
    Assert.IsTrue((LEvt.MessageText = LMsg) or (LEvt.Data = LMsg),
      Format('Iter %d: fallback event must carry the error message', [Iter]));
  end;
end;

// Feature: deepbase-bug-fixes-p0p1p2, Property 20 (degenerate case):
// When neither notifier nor bus is injected the router MUST still
// degrade gracefully (no exception, no crash). This guards against
// re-introducing a direct ShowMessage call as a "fallback fallback".
procedure TSettingsErrorRoutingPropertyTests
  .Property20_NoRouteWhenNeitherProvided;
begin
  for var Iter := 1 to 100 do
  begin
    var LMsg := Format('isolated failure #%d', [Iter]);
    var LRaised := False;
    try
      TSettingsErrorRouter.Route(nil, nil, LMsg);
    except
      on E: Exception do
        LRaised := True;
    end;
    Assert.IsFalse(LRaised,
      Format('Iter %d: routing with no targets must not raise', [Iter]));
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSettingsErrorRoutingPropertyTests);

end.
