{ ============================================================================
  DeepBase.VCL.DeepShell.Events

  In-process EventBus for DeepShell. UI-safe dispatch:
    - Publish from main thread: handler runs synchronously.
    - Publish from background thread: handler is queued to main thread.
  See docs/72.vcl.DeepShell-核心接口与服务契约.md §5
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Events;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellEventBus = class(TInterfacedObject, IShellEventBus)
  private
    type
      TSubscription = record
        Token: string;
        Kind: TDeepShellEventKind;
        AllKinds: Boolean;
        Handler: TShellEventHandler;
      end;
  private
    FLock: TCriticalSection;
    FSubs: TList<TSubscription>;
    FNextToken: Int64;
    FShutdown: Boolean;
    FOnDispatchError: TProc<Exception, string>;
    function NewToken: string;
    procedure DispatchInline(const ASub: TSubscription; const AEvent: TDeepShellEvent);
    /// <summary>
    /// Look up a still-subscribed handler by token. Returns False if the
    /// caller already unsubscribed since the queued dispatch was posted.
    /// Used by the background-publish path so unsubscribe is honoured even
    /// for queue items already in flight.
    /// </summary>
    function TryGetHandlerByToken(const AToken: string;
      out AHandler: TShellEventHandler): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    // IShellEventBus
    function Subscribe(AKind: TDeepShellEventKind; AHandler: TShellEventHandler): string;
    function SubscribeAll(AHandler: TShellEventHandler): string;
    procedure Unsubscribe(const AToken: string);
    procedure Publish(const AEvent: TDeepShellEvent);
    procedure Shutdown;
    procedure SetOnDispatchError(AHandler: TProc<Exception, string>);
  end;

implementation

uses
  Vcl.Forms;

{ TShellEventBus }

constructor TShellEventBus.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSubs := TList<TSubscription>.Create;
  FNextToken := 0;
  FShutdown := False;
  FOnDispatchError := nil;
end;

destructor TShellEventBus.Destroy;
begin
  FreeAndNil(FSubs);
  FreeAndNil(FLock);
  inherited;
end;

function TShellEventBus.NewToken: string;
begin
  Result := Format('evt-%d', [TInterlocked.Increment(FNextToken)]);
end;

function TShellEventBus.Subscribe(AKind: TDeepShellEventKind;
  AHandler: TShellEventHandler): string;
var
  LSub: TSubscription;
begin
  if not Assigned(AHandler) then
    raise EArgumentNilException.Create('TShellEventBus.Subscribe: AHandler is nil');

  LSub.Token := NewToken;
  LSub.Kind := AKind;
  LSub.AllKinds := False;
  LSub.Handler := AHandler;

  FLock.Enter;
  try
    FSubs.Add(LSub);
  finally
    FLock.Leave;
  end;
  Result := LSub.Token;
end;

function TShellEventBus.SubscribeAll(AHandler: TShellEventHandler): string;
var
  LSub: TSubscription;
begin
  if not Assigned(AHandler) then
    raise EArgumentNilException.Create('TShellEventBus.SubscribeAll: AHandler is nil');

  LSub.Token := NewToken;
  LSub.Kind := Low(TDeepShellEventKind);
  LSub.AllKinds := True;
  LSub.Handler := AHandler;

  FLock.Enter;
  try
    FSubs.Add(LSub);
  finally
    FLock.Leave;
  end;
  Result := LSub.Token;
end;

procedure TShellEventBus.Unsubscribe(const AToken: string);
var
  I: Integer;
begin
  if AToken = '' then
    Exit;
  FLock.Enter;
  try
    for I := FSubs.Count - 1 downto 0 do
      if FSubs[I].Token = AToken then
      begin
        FSubs.Delete(I);
        Break;
      end;
  finally
    FLock.Leave;
  end;
end;

procedure TShellEventBus.DispatchInline(const ASub: TSubscription;
  const AEvent: TDeepShellEvent);
begin
  // Per-handler exception isolation. A faulty handler must not break the bus.
  try
    ASub.Handler(AEvent);
  except
    on E: Exception do
      if Assigned(FOnDispatchError) then
        FOnDispatchError(E, ASub.Token);
  end;
end;

function TShellEventBus.TryGetHandlerByToken(const AToken: string;
  out AHandler: TShellEventHandler): Boolean;
var
  I: Integer;
begin
  Result := False;
  AHandler := nil;
  if AToken = '' then
    Exit;
  FLock.Enter;
  try
    for I := 0 to FSubs.Count - 1 do
      if FSubs[I].Token = AToken then
      begin
        AHandler := FSubs[I].Handler;
        Result := True;
        Exit;
      end;
  finally
    FLock.Leave;
  end;
end;

procedure TShellEventBus.Publish(const AEvent: TDeepShellEvent);
var
  LSnapshot: TArray<TSubscription>;
  LIsMain: Boolean;
  I: Integer;
begin
  if FShutdown then
    raise EInvalidOperation.Create('EventBus has been shut down');

  // Snapshot under lock so unsubscribe during dispatch is safe.
  FLock.Enter;
  try
    LSnapshot := FSubs.ToArray;
  finally
    FLock.Leave;
  end;

  if Length(LSnapshot) = 0 then
    Exit;

  LIsMain := TThread.CurrentThread.ThreadID = MainThreadID;

  for I := 0 to High(LSnapshot) do
  begin
    var LSub := LSnapshot[I];
    if (not LSub.AllKinds) and (LSub.Kind <> AEvent.Kind) then
      Continue;

    if LIsMain then
      DispatchInline(LSub, AEvent)
    else
    begin
      // Background path: capture the bus interface ref (extends bus
      // lifetime) and the SUBSCRIPTION TOKEN (not the handler closure).
      // When the queued proc runs we re-lookup the handler by token; if
      // the caller has already Unsubscribed, the token is gone and we
      // silently no-op. This makes general-purpose Unsubscribe correct
      // even for items already in the main-thread queue.
      var LCapturedToken := LSub.Token;
      var LCapturedEvent := AEvent;
      var LSelfRef: IShellEventBus := Self;
      var LProc: TThreadProcedure :=
        procedure
        var
          LCurrent: TShellEventHandler;
        begin
          if (LSelfRef <> nil)
             and (LSelfRef as TShellEventBus).TryGetHandlerByToken(LCapturedToken, LCurrent) then
          begin
            try
              LCurrent(LCapturedEvent);
            except
              on E: Exception do
                if Assigned((LSelfRef as TShellEventBus).FOnDispatchError) then
                  (LSelfRef as TShellEventBus).FOnDispatchError(E, LCapturedToken);
            end;
          end;
        end;
      TThread.Queue(nil, LProc);
    end;
  end;
end;

procedure TShellEventBus.Shutdown;
begin
  FShutdown := True;
  // Process any remaining queued handlers on the main thread
  if TThread.CurrentThread.ThreadID = MainThreadID then
    Vcl.Forms.Application.ProcessMessages;
end;

procedure TShellEventBus.SetOnDispatchError(AHandler: TProc<Exception, string>);
begin
  FOnDispatchError := AHandler;
end;

end.
