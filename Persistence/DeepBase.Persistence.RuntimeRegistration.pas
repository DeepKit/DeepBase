unit DeepBase.Persistence.RuntimeRegistration;

interface

uses
  DeepBase.RuntimeContext;

/// <summary>
/// Register Persistence lifecycle components into a RuntimeContext.
/// Registration is side-effect free and does not start background services.
/// </summary>
procedure RegisterPersistenceRuntimeComponents(Context: IRuntimeContext);

implementation

uses
  System.SysUtils,
  DeepBase.DB.Pool;

procedure RegisterPersistenceRuntimeComponents(Context: IRuntimeContext);
begin
  if Context = nil then
    raise EArgumentNilException.Create('Context');

  Context.RegisterComponent(CreateDBPoolManagerRuntimeComponent);
end;

end.
