{ ============================================================================
  Demo.Services

  Sample fake services for the DeepShell demo. Real apps register DB1-backed
  Settings / Recent / Layout services here.
  ============================================================================ }

unit Demo.Services;

interface

uses
  System.SysUtils,
  DeepBase.VCL.DeepShell;

type
  IDemoProjectService = interface
    ['{B59A1E5A-6F88-4C29-9B5C-8B3DAA0F0A11}']
    procedure OpenProject(const AProjectId: string);
    function CurrentProjectId: string;
  end;

  TDemoProjectServiceImpl = class(TInterfacedObject, IDemoProjectService)
  private
    FCurrentProjectId: string;
  public
    procedure OpenProject(const AProjectId: string);
    function CurrentProjectId: string;
  end;

implementation

procedure TDemoProjectServiceImpl.OpenProject(const AProjectId: string);
begin
  FCurrentProjectId := AProjectId;
end;

function TDemoProjectServiceImpl.CurrentProjectId: string;
begin
  Result := FCurrentProjectId;
end;

end.
