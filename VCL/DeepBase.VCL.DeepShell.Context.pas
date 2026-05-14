{ ============================================================================
  DeepBase.VCL.DeepShell.Context

  ContextManager keeps the current TShellContext (project / object / view)
  and publishes change events on the EventBus. Revision is monotonically
  incremented so consumers can drop stale notifications.
  See docs/72.vcl.DeepShell-核心接口与服务契约.md §2
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Context;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  DeepBase.VCL.DeepShell.Types,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellContextManager = class(TInterfacedObject, IShellContextManager)
  private
    FLock: TCriticalSection;
    FContext: TShellContext;
    FBus: IShellEventBus;
    procedure BumpRevisionAndPublish(AKind: TDeepShellEventKind;
      const AMessage: string);
  public
    constructor Create(const ABus: IShellEventBus);
    destructor Destroy; override;
    // IShellContextManager
    function Current: TShellContext;
    procedure SetProject(const AProjectId, APath: string);
    procedure SetObject(const ARef: TShellObjectRef);
    procedure SetView(const AViewId, AViewType: string);
    procedure ClearProject;
  end;

implementation

{ TShellContextManager }

constructor TShellContextManager.Create(const ABus: IShellEventBus);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FContext := TShellContext.Empty;
  FBus := ABus;
end;

destructor TShellContextManager.Destroy;
begin
  FBus := nil;
  FreeAndNil(FLock);
  inherited;
end;

function TShellContextManager.Current: TShellContext;
begin
  FLock.Enter;
  try
    Result := FContext;
  finally
    FLock.Leave;
  end;
end;

procedure TShellContextManager.BumpRevisionAndPublish(AKind: TDeepShellEventKind;
  const AMessage: string);
var
  LSnapshot: TShellContext;
  LEvent: TDeepShellEvent;
begin
  FLock.Enter;
  try
    Inc(FContext.Revision);
    LSnapshot := FContext;
  finally
    FLock.Leave;
  end;

  if FBus = nil then
    Exit;

  LEvent := Default(TDeepShellEvent);
  LEvent.Kind := AKind;
  LEvent.Context := LSnapshot;
  LEvent.ObjectRef := LSnapshot.ObjectRef;
  LEvent.MessageText := AMessage;
  FBus.Publish(LEvent);
end;

procedure TShellContextManager.SetProject(const AProjectId, APath: string);
begin
  FLock.Enter;
  try
    FContext.ProjectId := AProjectId;
    FContext.ProjectPath := APath;
    FContext.ObjectRef := TShellObjectRef.Empty;
    FContext.ViewId := '';
    FContext.ViewType := '';
  finally
    FLock.Leave;
  end;
  BumpRevisionAndPublish(sekProjectOpened, AProjectId);
  BumpRevisionAndPublish(sekContextChanged, 'project');
end;

procedure TShellContextManager.SetObject(const ARef: TShellObjectRef);
begin
  FLock.Enter;
  try
    FContext.ObjectRef := ARef;
  finally
    FLock.Leave;
  end;
  BumpRevisionAndPublish(sekObjectSelected, ARef.Id);
  BumpRevisionAndPublish(sekContextChanged, 'object');
end;

procedure TShellContextManager.SetView(const AViewId, AViewType: string);
begin
  FLock.Enter;
  try
    FContext.ViewId := AViewId;
    FContext.ViewType := AViewType;
  finally
    FLock.Leave;
  end;
  BumpRevisionAndPublish(sekViewChanged, AViewId);
  BumpRevisionAndPublish(sekContextChanged, 'view');
end;

procedure TShellContextManager.ClearProject;
var
  LProjectId: string;
begin
  FLock.Enter;
  try
    LProjectId := FContext.ProjectId;
    FContext := TShellContext.Empty;
  finally
    FLock.Leave;
  end;
  BumpRevisionAndPublish(sekProjectClosed, LProjectId);
  BumpRevisionAndPublish(sekContextChanged, 'closed');
end;

end.
