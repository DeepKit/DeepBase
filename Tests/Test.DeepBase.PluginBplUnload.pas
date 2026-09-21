{ ============================================================================
  Test.DeepBase.PluginBplUnload - R7-P4 (A18) end-to-end BPL unload

  Loads the REAL fixture package Tests/Regression/R7P4Probe.bpl (built with
  the repo dcc64; CLI builds .bpl fine), calls its exported function,
  unloads it, and proves the module left the process (GetModuleHandle = 0)
  and can be loaded again (no stale refcount).

  Scope notes (no masking):
  - TDeepBasePluginManager.LoadBPL/UnloadBPL are PRIVATE, so this test
    exercises the same OS primitives (LoadPackage/UnloadPackage) the manager
    wraps in try/except; production API visibility is not changed for tests.
  - The full LoadPlugin path additionally requires an Authenticode signature
    (WinVerifyTrust) plus a RegisterPlugin export; no signtool exists on this
    machine, so Test_LoadPlugin_UnsignedFixture_FailClosed pins the
    signature gate fail-closed instead of bypassing it.
  - Counting-gate semantics (Acquire/Release/drain/EPluginInUse) are covered
    by Test.Regression.A8_InFlightUnloadGate.
  ============================================================================ }

unit Test.DeepBase.PluginBplUnload;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPluginBplUnloadTests = class
  private
    function FixtureBplPath: string;
  public
    [Test]
    procedure Test_RealBpl_LoadCallUnload;
    [Test]
    procedure Test_RealBpl_ReloadAfterUnload;
    [Test]
    procedure Test_LoadPlugin_UnsignedFixture_FailClosed;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows,
  DeepBase.PluginManager;

type
  TProbeAddFunc = function(A, B: Integer): Integer; stdcall;

function TPluginBplUnloadTests.FixtureBplPath: string;
begin
  // Test runners execute with the repo root as working directory
  // (same convention as the HB benchmark evidence/probe paths).
  Result := TPath.GetFullPath(
    TPath.Combine('Tests' + TPath.DirectorySeparatorChar + 'Regression',
    'R7P4Probe.bpl'));
end;

procedure TPluginBplUnloadTests.Test_RealBpl_LoadCallUnload;
var
  Handle: HMODULE;
  ProbeAdd: TProbeAddFunc;
  BplPath: string;
begin
  BplPath := FixtureBplPath;
  Assert.IsTrue(TFile.Exists(BplPath), 'fixture BPL missing: ' + BplPath);
  Handle := LoadPackage(BplPath);
  Assert.IsTrue(Handle <> 0, 'LoadPackage must return a real module handle');
  try
    ProbeAdd := TProbeAddFunc(GetProcAddress(Handle, 'ProbeAdd'));
    Assert.IsTrue(Assigned(ProbeAdd), 'fixture must export ProbeAdd');
    Assert.AreEqual(7, ProbeAdd(3, 4), 'ProbeAdd(3,4) must equal 7');
  finally
    UnloadPackage(Handle);
  end;
  Assert.AreEqual(HMODULE(0),
    GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process after UnloadPackage');
end;

procedure TPluginBplUnloadTests.Test_RealBpl_ReloadAfterUnload;
var
  H1, H2: HMODULE;
  BplPath: string;
begin
  BplPath := FixtureBplPath;
  Assert.IsTrue(TFile.Exists(BplPath), 'fixture BPL missing: ' + BplPath);
  H1 := LoadPackage(BplPath);
  Assert.IsTrue(H1 <> 0, 'first load must succeed');
  UnloadPackage(H1);
  Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process after first unload');
  H2 := LoadPackage(BplPath);
  Assert.IsTrue(H2 <> 0, 'reload after unload must succeed (no stale refcount)');
  UnloadPackage(H2);
  Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process after second unload');
end;

procedure TPluginBplUnloadTests.Test_LoadPlugin_UnsignedFixture_FailClosed;
var
  Mgr: TDeepBasePluginManager;
  BplPath: string;
begin
  // The unsigned fixture cannot satisfy the Authenticode gate, so the
  // public LoadPlugin path must refuse it (False) rather than load it.
  // The manager is rooted at the fixture directory so the path gate passes
  // and the rejection provably comes from the signature gate.
  BplPath := FixtureBplPath;
  Assert.IsTrue(TFile.Exists(BplPath), 'fixture BPL missing: ' + BplPath);
  Mgr := TDeepBasePluginManager.Create(ExtractFileDir(BplPath), nil);
  try
    Assert.IsFalse(Mgr.LoadPlugin(BplPath),
      'unsigned BPL must be rejected by the signature gate');
    Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
      'rejected plugin must not remain loaded');
  finally
    Mgr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPluginBplUnloadTests);

end.
