{ ============================================================================
  DeepBase.VCL.DeepShell.Services

  Service registry for DeepShell. Stores interfaces by string id, allows
  capability lookups, and lets the host enumerate registered service ids.
  See docs/72.vcl.DeepShell-核心接口与服务契约.md §3
  ============================================================================ }

unit DeepBase.VCL.DeepShell.Services;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.VCL.DeepShell.Intf;

type
  TShellServiceRegistry = class(TInterfacedObject, IShellServiceRegistry)
  private
    FLock: TCriticalSection;
    FServices: TDictionary<string, IInterface>;
    /// <summary>
    /// Insertion-ordered list of service ids; lets ServiceIds return registry
    /// contents in registration order. TDictionary.Keys has no defined order.
    /// </summary>
    FOrderedIds: TList<string>;
  public
    constructor Create;
    destructor Destroy; override;
    // IShellServiceRegistry
    procedure RegisterService(const AServiceId: string; const AService: IInterface);
    function TryGetService(const AServiceId: string; out AService: IInterface): Boolean;
    function SupportsCapability(const ACapabilityId: string): Boolean;
    function ServiceIds: TArray<string>;
  end;

implementation

{ TShellServiceRegistry }

constructor TShellServiceRegistry.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FServices := TDictionary<string, IInterface>.Create;
  FOrderedIds := TList<string>.Create;
end;

destructor TShellServiceRegistry.Destroy;
begin
  FreeAndNil(FOrderedIds);
  FreeAndNil(FServices);
  FreeAndNil(FLock);
  inherited;
end;

procedure TShellServiceRegistry.RegisterService(const AServiceId: string;
  const AService: IInterface);
begin
  if AServiceId = '' then
    raise EArgumentException.Create('TShellServiceRegistry.RegisterService: empty service id');
  if AService = nil then
    raise EArgumentNilException.Create('TShellServiceRegistry.RegisterService: nil service');

  FLock.Enter;
  try
    if not FServices.ContainsKey(AServiceId) then
      FOrderedIds.Add(AServiceId);
    FServices.AddOrSetValue(AServiceId, AService);
  finally
    FLock.Leave;
  end;
end;

function TShellServiceRegistry.TryGetService(const AServiceId: string;
  out AService: IInterface): Boolean;
begin
  AService := nil;
  FLock.Enter;
  try
    Result := FServices.TryGetValue(AServiceId, AService);
  finally
    FLock.Leave;
  end;
end;

function TShellServiceRegistry.SupportsCapability(const ACapabilityId: string): Boolean;
begin
  // For the MVP, capability == service id. Adapters can extend this later.
  FLock.Enter;
  try
    Result := FServices.ContainsKey(ACapabilityId);
  finally
    FLock.Leave;
  end;
end;

function TShellServiceRegistry.ServiceIds: TArray<string>;
begin
  FLock.Enter;
  try
    Result := FOrderedIds.ToArray;
  finally
    FLock.Leave;
  end;
end;

end.
