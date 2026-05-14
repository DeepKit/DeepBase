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
    function NewToken: string;
    procedure DispatchInline(const ASub: TSubscription; const AEvent: TDeepShellEvent);
  public
    constructor Create;
    destructor Destroy; override;
    // IShellEventBus
    function Subscribe(AKind: TDeepShellEventKind; AHandler: TShellEventHandler): string;
    function SubscribeAll(AHandler: TShellEventHandler): string;
    procedure Unsubscribe(const AToken: string);
    procedure Publish(const AEvent: TDeepShellEvent);
  end;

implementation

{ TShellEventBus }

constructor TShellEventBus.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSubs := TList<TSubscription>.Create;
  FNextToken := 0;
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
    // Intentionally swallow. Surfacing UI errors here would bypass StatusManager
    // which the caller may not have constructed yet.
  end;
end;

procedure TShellEventBus.Publish(const AEvent: TDeepShellEvent);
var
  LSnapshot: TArray<TSubscription>;
  LIsMain: Boolean;
  I: Integer;
begin
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
      // Capture by value into the queued closure.
      // LSelfRef extends the bus lifetime via interface refcount so the
      // queued main-thread dispatch cannot UAF the bus instance.
      var LCapturedSub := LSub;
      var LCapturedEvent := AEvent;
      var LSelfRef: IShellEventBus := Self;
      var LProc: TThreadProcedure :=
        procedure
        begin
          // Touch LSelfRef so the closure keeps its reference until done.
          if LSelfRef <> nil then
            DispatchInline(LCapturedSub, LCapturedEvent);
        end;
      TThread.Queue(nil, LProc);
    end;
  end;
end;

end.
