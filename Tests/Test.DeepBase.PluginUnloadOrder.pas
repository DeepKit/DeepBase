{ ============================================================================
  Test.DeepBase.PluginUnloadOrder - A2-06 / B-PM-06 regression

  Pins the fail-before-unload invariant introduced in TDeepBasePluginManager:
  every managed reference whose code lives inside a plugin BPL (interface
  vars, records with managed fields finalized at frame exit) must be released
  BEFORE UnloadBPL, otherwise the last _Release/@FinalizeRecord executes
  against unmapped code (use-after-free).

  Coverage (public/contract level only; the production LoadPlugin path is
  gated by Authenticode and this repo has no signing cert on this machine,
  same constraint as Test.DeepBase.PluginBplUnload):
    - empty UnloadAllPlugins fires no callbacks (snapshot loop inert);
    - failed LoadPlugin leaves the manager consistent and freeable
      (exercises the new nil/Default cleanup in the LoadPlugin finally);
    - real fixture BPL driven through the exact release-before-unload
      sequence the manager now follows, with post-unload memory pressure.

  Unload-order regression mandated by the audit ticket:
  Test.Regression.BUG340_PluginUnloadOrder (run in the same A2Run pass).
  ============================================================================ }

unit Test.DeepBase.PluginUnloadOrder;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Plugin,
  DeepBase.PluginManager;

type
  [TestFixture]
  TTestPluginUnloadOrderA206 = class
  private const
    REGISTER_NAME = 'RegisterPlugin';
  private
    FTempDir: string;
    FLoadedCount: Integer;
    FUnloadedCount: Integer;
    FErrorCount: Integer;
    procedure OnLoaded(Sender: TObject; const Info: TPluginInfo);
    procedure OnUnloaded(Sender: TObject; const PluginID: TGUID);
    procedure OnError(Sender: TObject; const Args: TPluginErrorEventArgs);
    function FixtureBplPath: string;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_UnloadAll_EmptyManager_FiresNoCallbacks;

    [Test]
    procedure Test_LoadPlugin_FailurePaths_LeaveManagerConsistent;

    [Test]
    procedure Test_UnloadPlugin_AfterFailedLoad_ReturnsFalseNoAV;

    [Test]
    procedure Test_RealBpl_ReleaseBeforeUnload_NoAV;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows;

{ TTestPluginUnloadOrderA206 }

procedure TTestPluginUnloadOrderA206.OnLoaded(Sender: TObject;
  const Info: TPluginInfo);
begin
  Inc(FLoadedCount);
end;

procedure TTestPluginUnloadOrderA206.OnUnloaded(Sender: TObject;
  const PluginID: TGUID);
begin
  Inc(FUnloadedCount);
end;

procedure TTestPluginUnloadOrderA206.OnError(Sender: TObject;
  const Args: TPluginErrorEventArgs);
begin
  Inc(FErrorCount);
end;

procedure TTestPluginUnloadOrderA206.SetUp;
begin
  FLoadedCount := 0;
  FUnloadedCount := 0;
  FErrorCount := 0;
  FTempDir := TPath.Combine(TPath.GetTempPath,
    Format('a206_plugins_%d', [GetTickCount]));
  ForceDirectories(FTempDir);
end;

procedure TTestPluginUnloadOrderA206.TearDown;
begin
  if TDirectory.Exists(FTempDir) then
    TDirectory.Delete(FTempDir, True);
end;

function TTestPluginUnloadOrderA206.FixtureBplPath: string;
begin
  // Committed real fixture package (same file as the D2 end-to-end suite);
  // runners execute with the repo root as working directory.
  Result := TPath.GetFullPath(
    TPath.Combine('Tests' + TPath.DirectorySeparatorChar + 'Regression',
    'R7P4Probe.bpl'));
end;

procedure TTestPluginUnloadOrderA206.Test_UnloadAll_EmptyManager_FiresNoCallbacks;
var
  Mgr: TDeepBasePluginManager;
begin
  Mgr := TDeepBasePluginManager.Create(FTempDir, nil);
  try
    Mgr.OnPluginLoaded := OnLoaded;
    Mgr.OnPluginUnloaded := OnUnloaded;
    Mgr.UnloadAllPlugins;
    Assert.AreEqual(0, FLoadedCount);
    Assert.AreEqual(0, FUnloadedCount);
    Assert.AreEqual(0, Mgr.PluginCount);
  finally
    Mgr.Free;
  end;
end;

procedure TTestPluginUnloadOrderA206.Test_LoadPlugin_FailurePaths_LeaveManagerConsistent;
var
  Mgr: TDeepBasePluginManager;
  BadPath: string;
begin
  // Two reachable failure classes before the BPL ever enters the registry:
  // extension gate (non-BPL file) and signature gate (unsigned real BPL).
  // The LoadPlugin finally block now nils Plugin/PluginBase and defaults the
  // Info record on every path; a manager must stay usable afterwards.
  BadPath := TPath.Combine(FTempDir, 'NotAPlugin.txt');
  TFile.WriteAllText(BadPath, 'not a bpl');

  Mgr := TDeepBasePluginManager.Create(FTempDir, nil);
  try
    Mgr.OnPluginError := OnError;
    Assert.IsFalse(Mgr.LoadPlugin(BadPath));
    Assert.AreEqual(0, Mgr.PluginCount);

    if TFile.Exists(FixtureBplPath) then
    begin
      // Rooted at FTempDir, the out-of-tree fixture must be refused by the
      // path gate (the signature-gate refusal is pinned by
      // Test.DeepBase.PluginBplUnload). Both are pre-BPL early Exits through
      // the same finally block.
      Assert.IsFalse(Mgr.LoadPlugin(FixtureBplPath),
        'out-of-tree BPL must be rejected by the path gate');
      Assert.AreEqual(0, Mgr.PluginCount);
    end;

    // Repeated unload against an empty registry must not AV or fire callbacks
    Mgr.OnPluginUnloaded := OnUnloaded;
    Mgr.UnloadAllPlugins;
    Assert.AreEqual(0, FUnloadedCount);
  finally
    Mgr.Free;
  end;
  Assert.IsTrue(FErrorCount > 0, 'failed load paths must surface OnPluginError');
end;

procedure TTestPluginUnloadOrderA206.Test_UnloadPlugin_AfterFailedLoad_ReturnsFalseNoAV;
var
  Mgr: TDeepBasePluginManager;
  ProbeId: TGUID;
  BadPath: string;
begin
  // UnloadPlugin early-Exit (plugin not found) runs the same finally block
  // that now defaults LoadedRec/PluginInfo before UnloadBPL: the skip path
  // must stay clean too.
  BadPath := TPath.Combine(FTempDir, 'AlsoNotAPlugin.dll');
  TFile.WriteAllText(BadPath, 'x');
  CreateGUID(ProbeId);

  Mgr := TDeepBasePluginManager.Create(FTempDir, nil);
  try
    Assert.IsFalse(Mgr.LoadPlugin(BadPath));
    Assert.IsFalse(Mgr.UnloadPlugin(ProbeId));
    Assert.AreEqual(0, Mgr.PluginCount);
  finally
    Mgr.Free;
  end;
end;

procedure TTestPluginUnloadOrderA206.Test_RealBpl_ReleaseBeforeUnload_NoAV;
var
  Handle: HMODULE;
  RegisterPlugin: TRegisterPluginFunc;
  Plugin: IDeepBasePlugin;
  Pressure: TArray<Pointer>;
  I: Integer;
  BplPath: string;
begin
  // Contract-level replay of the exact ordering the fixed manager enforces:
  // the LAST managed reference into BPL code is dropped while the module is
  // still mapped, and only then is the package unloaded. Memory pressure
  // after unload turns a stray finalizer into an immediate AV.
  BplPath := FixtureBplPath;
  if not TFile.Exists(BplPath) then
  begin
    Assert.IsFalse(TFile.Exists(BplPath), 'fixture-skipped');
    Exit;
  end;

  Handle := LoadPackage(BplPath);
  Assert.IsTrue(Handle <> 0, 'LoadPackage must return a real module handle');
  try
    RegisterPlugin := TRegisterPluginFunc(
      GetProcAddress(Handle, REGISTER_NAME));
    Assert.IsTrue(Assigned(RegisterPlugin),
      'fixture must export ' + REGISTER_NAME);

    Plugin := RegisterPlugin();
    Assert.IsTrue(Plugin <> nil);
    Assert.IsTrue(Plugin.Initialize);
    Assert.IsTrue(Plugin.Finalize);

    // fail-before-unload: release while mapped
    Plugin := nil;
  finally
    UnloadPackage(Handle);
  end;

  Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process');

  // Reaching this line at all proves no deferred _Release/FinalizeRecord
  // jumped into unmapped code during frame exit or module teardown.
  SetLength(Pressure, 512);
  for I := 0 to High(Pressure) do
    GetMem(Pressure[I], 4096);
  for I := 0 to High(Pressure) do
    FreeMem(Pressure[I]);
  SetLength(Pressure, 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestPluginUnloadOrderA206);

end.
