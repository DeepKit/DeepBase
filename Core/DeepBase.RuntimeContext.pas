{ ============================================================================
  DeepBase.RuntimeContext

  Runtime lifecycle coordinator for DeepBase services.
  This unit intentionally has no UI, database, or manager dependencies.
  ============================================================================ }

unit DeepBase.RuntimeContext;

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  ERuntimeContextError = class(Exception);

  IRuntimeContext = interface;

  IRuntimeComponent = interface
    ['{7D2A89C1-3F0C-4D55-96E6-8B49F13F8028}']
    function GetName: string;
    procedure Configure;
    procedure Initialize;
    procedure Start;
    procedure Stop;
    procedure Shutdown;

    property Name: string read GetName;
  end;

  IRuntimeContext = interface
    ['{77E11187-AC41-4E1F-91E4-FA26D90E7B1F}']
    function GetComponentCount: Integer;
    function GetConfigured: Boolean;
    function GetInitialized: Boolean;
    function GetStarted: Boolean;
    function GetShutdownComplete: Boolean;

    procedure RegisterComponent(const Component: IRuntimeComponent);
    procedure Configure;
    procedure Initialize;
    procedure Start;
    procedure Stop;
    procedure Shutdown;

    property ComponentCount: Integer read GetComponentCount;
    property Configured: Boolean read GetConfigured;
    property Initialized: Boolean read GetInitialized;
    property Started: Boolean read GetStarted;
    property ShutdownComplete: Boolean read GetShutdownComplete;
  end;

  TDeepBaseRuntimeComponent = class(TInterfacedObject, IRuntimeComponent)
  private
    FName: string;
  protected
    function GetName: string; virtual;
  public
    constructor Create(const AName: string); virtual;
    procedure Configure; virtual;
    procedure Initialize; virtual;
    procedure Start; virtual;
    procedure Stop; virtual;
    procedure Shutdown; virtual;

    property Name: string read GetName;
  end;

  TDeepBaseRuntimeContext = class(TObject, IRuntimeContext)
  private
    FComponents: TList<IRuntimeComponent>;
    FShutdownStack: TList<IRuntimeComponent>;
    FStartedStack: TList<IRuntimeComponent>;
    FConfigured: Boolean;
    FInitialized: Boolean;
    FStarted: Boolean;
    FShutdown: Boolean;

    function GetComponentCount: Integer;
    function GetConfigured: Boolean;
    function GetInitialized: Boolean;
    function GetStarted: Boolean;
    function GetShutdownComplete: Boolean;
    procedure EnsureMutable;
    procedure StopStartedComponents(PropagateErrors: Boolean);
    procedure ShutdownConfiguredComponents(PropagateErrors: Boolean);
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterComponent(const Component: IRuntimeComponent);
    function ComponentName(Index: Integer): string;
    procedure Configure;
    procedure Initialize;
    procedure Start;
    procedure Stop;
    procedure Shutdown;

    property ComponentCount: Integer read GetComponentCount;
    property Configured: Boolean read FConfigured;
    property Initialized: Boolean read FInitialized;
    property Started: Boolean read FStarted;
    property ShutdownComplete: Boolean read FShutdown;
  end;

function RuntimeContext: TDeepBaseRuntimeContext;
procedure SetRuntimeContext(AContext: TDeepBaseRuntimeContext);

implementation

var
  GRuntimeContext: TDeepBaseRuntimeContext;
  GRuntimeContextLock: TObject;

{ TDeepBaseRuntimeComponent }

constructor TDeepBaseRuntimeComponent.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TDeepBaseRuntimeComponent.GetName: string;
begin
  Result := FName;
end;

procedure TDeepBaseRuntimeComponent.Configure;
begin
end;

procedure TDeepBaseRuntimeComponent.Initialize;
begin
end;

procedure TDeepBaseRuntimeComponent.Start;
begin
end;

procedure TDeepBaseRuntimeComponent.Stop;
begin
end;

procedure TDeepBaseRuntimeComponent.Shutdown;
begin
end;

{ TDeepBaseRuntimeContext }

constructor TDeepBaseRuntimeContext.Create;
begin
  inherited Create;
  FComponents := TList<IRuntimeComponent>.Create;
  FShutdownStack := TList<IRuntimeComponent>.Create;
  FStartedStack := TList<IRuntimeComponent>.Create;
end;

destructor TDeepBaseRuntimeContext.Destroy;
begin
  if not FShutdown then
    Shutdown;

  FreeAndNil(FStartedStack);
  FreeAndNil(FShutdownStack);
  FreeAndNil(FComponents);
  inherited Destroy;
end;

function TDeepBaseRuntimeContext.GetComponentCount: Integer;
begin
  Result := FComponents.Count;
end;

function TDeepBaseRuntimeContext.GetConfigured: Boolean;
begin
  Result := FConfigured;
end;

function TDeepBaseRuntimeContext.GetInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TDeepBaseRuntimeContext.GetStarted: Boolean;
begin
  Result := FStarted;
end;

function TDeepBaseRuntimeContext.GetShutdownComplete: Boolean;
begin
  Result := FShutdown;
end;

function TDeepBaseRuntimeContext._AddRef: Integer;
begin
  Result := -1;
end;

function TDeepBaseRuntimeContext._Release: Integer;
begin
  Result := -1;
end;

function TDeepBaseRuntimeContext.QueryInterface(const IID: TGUID;
  out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

procedure TDeepBaseRuntimeContext.EnsureMutable;
begin
  if FConfigured or FInitialized or FStarted then
    raise ERuntimeContextError.Create(
      'Runtime components cannot be registered after configuration starts');
  if FShutdown then
    raise ERuntimeContextError.Create(
      'Runtime components cannot be registered after shutdown');
end;

procedure TDeepBaseRuntimeContext.RegisterComponent(
  const Component: IRuntimeComponent);
var
  Existing: IRuntimeComponent;
begin
  EnsureMutable;

  if Component = nil then
    raise ERuntimeContextError.Create('Runtime component must not be nil');
  if Component.Name.Trim = '' then
    raise ERuntimeContextError.Create('Runtime component name must not be empty');

  for Existing in FComponents do
    if SameText(Existing.Name, Component.Name) then
      raise ERuntimeContextError.CreateFmt(
        'Runtime component "%s" is already registered', [Component.Name]);

  FComponents.Add(Component);
end;

function TDeepBaseRuntimeContext.ComponentName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= FComponents.Count) then
    raise ERuntimeContextError.CreateFmt(
      'Runtime component index out of range: %d', [Index]);

  Result := FComponents[Index].Name;
end;

procedure TDeepBaseRuntimeContext.Configure;
var
  Component: IRuntimeComponent;
begin
  if FConfigured then
    Exit;
  if FShutdown then
    raise ERuntimeContextError.Create('Runtime context has already shut down');

  try
    for Component in FComponents do
    begin
      Component.Configure;
      FShutdownStack.Add(Component);
    end;
    FConfigured := True;
  except
    ShutdownConfiguredComponents(False);
    raise;
  end;
end;

procedure TDeepBaseRuntimeContext.Initialize;
var
  Component: IRuntimeComponent;
begin
  if FInitialized then
    Exit;

  Configure;

  try
    for Component in FComponents do
      Component.Initialize;
    FInitialized := True;
  except
    ShutdownConfiguredComponents(False);
    raise;
  end;
end;

procedure TDeepBaseRuntimeContext.Start;
var
  Component: IRuntimeComponent;
begin
  if FStarted then
    Exit;

  Initialize;

  try
    for Component in FComponents do
    begin
      Component.Start;
      FStartedStack.Add(Component);
    end;
    FStarted := True;
  except
    StopStartedComponents(False);
    ShutdownConfiguredComponents(False);
    raise;
  end;
end;

procedure TDeepBaseRuntimeContext.Stop;
begin
  StopStartedComponents(True);
end;

procedure TDeepBaseRuntimeContext.Shutdown;
begin
  StopStartedComponents(True);
  ShutdownConfiguredComponents(True);
  FShutdown := True;
end;

procedure TDeepBaseRuntimeContext.StopStartedComponents(
  PropagateErrors: Boolean);
var
  I: Integer;
  Component: IRuntimeComponent;
  FirstError: string;
begin
  FirstError := '';

  for I := FStartedStack.Count - 1 downto 0 do
  begin
    Component := FStartedStack[I];
    try
      Component.Stop;
    except
      on E: Exception do
        if PropagateErrors and (FirstError = '') then
          FirstError := Format('%s.Stop failed: %s', [Component.Name, E.Message]);
    end;
  end;

  FStartedStack.Clear;
  FStarted := False;

  if FirstError <> '' then
    raise ERuntimeContextError.Create(FirstError);
end;

procedure TDeepBaseRuntimeContext.ShutdownConfiguredComponents(
  PropagateErrors: Boolean);
var
  I: Integer;
  Component: IRuntimeComponent;
  FirstError: string;
begin
  FirstError := '';

  for I := FShutdownStack.Count - 1 downto 0 do
  begin
    Component := FShutdownStack[I];
    try
      Component.Shutdown;
    except
      on E: Exception do
        if PropagateErrors and (FirstError = '') then
          FirstError := Format('%s.Shutdown failed: %s',
            [Component.Name, E.Message]);
    end;
  end;

  FShutdownStack.Clear;
  FConfigured := False;
  FInitialized := False;

  if FirstError <> '' then
    raise ERuntimeContextError.Create(FirstError);
end;

function RuntimeContext: TDeepBaseRuntimeContext;
begin
  // BASIC-005 fix: double-checked lock so concurrent first-access from
  // multiple threads does not create two instances.
  if GRuntimeContext = nil then
  begin
    TMonitor.Enter(GRuntimeContextLock);
    try
      if GRuntimeContext = nil then
        GRuntimeContext := TDeepBaseRuntimeContext.Create;
    finally
      TMonitor.Exit(GRuntimeContextLock);
    end;
  end;
  Result := GRuntimeContext;
end;

procedure SetRuntimeContext(AContext: TDeepBaseRuntimeContext);
begin
  TMonitor.Enter(GRuntimeContextLock);
  try
    if GRuntimeContext = AContext then
      Exit;
    FreeAndNil(GRuntimeContext);
    GRuntimeContext := AContext;
  finally
    TMonitor.Exit(GRuntimeContextLock);
  end;
end;

initialization
  GRuntimeContextLock := TObject.Create;

finalization
  FreeAndNil(GRuntimeContext);
  FreeAndNil(GRuntimeContextLock);

end.
