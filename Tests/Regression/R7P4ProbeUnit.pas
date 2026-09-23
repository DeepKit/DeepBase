unit R7P4ProbeUnit;

{ R7-P4 / D2 (A18) end-to-end BPL fixture.

  Three observable channels, all read from OUTSIDE the module:
  - ProbeAdd: proves the module's code is resident and callable.
  - RegisterPlugin: the export name the plugin manager looks up
    (REGISTER_PLUGIN_FUNC), returning the repo plugin contract, so the fixture
    is a real plugin and not a bare DLL-shaped blob.
  - ProbeInitCount / ProbeFinalizeCount: module-local counters. A nonzero
    finalize count is only observable if Finalize really ran inside the loaded
    module, which rules out a constant-returning mock.

  DeepBase.Plugin is statically linked from Core/ on purpose: requiring
  DeepBaseCore.bpl would tie the fixture to a gitignored build output that an
  isolated worktree cannot rebuild from the repo alone. }

interface

uses
  DeepBase.Plugin;

function ProbeAdd(A, B: Integer): Integer; stdcall;
function ProbeInitCount: Integer; stdcall;
function ProbeFinalizeCount: Integer; stdcall;

type
  { Minimal real plugin: contract only, no behavior. }
  TProbePlugin = class(TDeepBasePluginBase)
  protected
    function DoGetPluginInfo: TPluginInfo; override;
    function DoInitialize: Boolean; override;
    function DoFinalize: Boolean; override;
  end;

  { Export with the DEFAULT (register) convention, like the repo's real plugins:
     TRegisterPluginFunc in DeepBase.Plugin is a plain `function: IDeepBasePlugin`,
     and Win64 register/stdcall disagree on the hidden Result pointer, so an
     stdcall export would be mis-called by TDeepBasePluginManager.GetRegisterFunc. }
function RegisterPlugin: IDeepBasePlugin; export;

exports
  ProbeAdd,
  RegisterPlugin,
  ProbeInitCount,
  ProbeFinalizeCount;

implementation

const
  PROBE_PLUGIN_ID: TGUID = '{7B7C1A23-4D5E-4F60-9A8B-1C2D3E4F5A01}';

var
  GInitCount: Integer = 0;
  GFinalizeCount: Integer = 0;

function ProbeAdd(A, B: Integer): Integer; stdcall;
begin
  Result := A + B;
end;

function ProbeInitCount: Integer; stdcall;
begin
  Result := GInitCount;
end;

function ProbeFinalizeCount: Integer; stdcall;
begin
  Result := GFinalizeCount;
end;

function TProbePlugin.DoGetPluginInfo: TPluginInfo;
begin
  Result := MakePluginInfo(PROBE_PLUGIN_ID, 'R7P4 Probe Plugin', '1.0.0',
    'DeepBase Tests', 'BPL unload fixture');
end;

function TProbePlugin.DoInitialize: Boolean;
begin
  Inc(GInitCount);
  SetState(psActive);
  Result := True;
end;

function TProbePlugin.DoFinalize: Boolean;
begin
  Inc(GFinalizeCount);
  SetState(psUnloaded);
  Result := True;
end;

function RegisterPlugin: IDeepBasePlugin;
begin
  Result := TProbePlugin.Create;
end;

end.
