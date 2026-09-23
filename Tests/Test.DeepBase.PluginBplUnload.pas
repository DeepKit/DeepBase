{ ============================================================================
  Test.DeepBase.PluginBplUnload - R7-P4 / D2 (A18) end-to-end BPL unload

  Loads the REAL fixture package Tests/Regression/R7P4Probe.bpl (built with the
  repo dcc64; CLI builds .bpl fine), drives it through the repo plugin contract,
  unloads it, and proves at the FILE level that the module stopped holding the
  .bpl: an exclusive open fails while loaded and succeeds after unload.

  Scope notes (no masking):
  - TDeepBasePluginManager.LoadBPL/UnloadBPL are PRIVATE, so these tests
    exercise the same OS primitives (LoadPackage/UnloadPackage) the manager
    wraps in try/except; production API visibility is not changed for tests.
  - The full public LoadPlugin path additionally requires an Authenticode
    signature (WinVerifyTrust) plus a RegisterPlugin export; no signtool exists
    on this machine, so Test_LoadPlugin_UnsignedFixture_FailClosed pins the
    signature gate fail-closed instead of bypassing it.
  - GetPluginInfo is deliberately NOT called here: returning TPluginInfo
    (five UnicodeStrings + TArray<TGUID>) from the package into a host that
    statically links the RTL makes the host free package-heap blocks and
    raises EAccessViolation while finalizing the record. Repro and bisect
    evidence: CodeReview D2 evidence probe_d2_bpl_lifecycle.log. The
    interface call itself, Initialize/Finalize and the module unload are
    exercised below because their payloads are POD.
  - Counting-gate semantics (Acquire/Release/drain/EPluginInUse) are covered
    by Test.Regression.A8_InFlightUnloadGate.
  - Exclusive open (share mode 0) is the occupancy probe, not delete: the image
    loader opens images with FILE_SHARE_DELETE, so DeleteFile on a loaded module
    can succeed as a pending-delete and would be a weak signal.
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
    function TryExclusiveOpen(const APath: string; out AErrorCode: Cardinal): Boolean;
    function TryDelete(const APath: string; out AErrorCode: Cardinal): Boolean;
    function CopyFixtureToTemp(out ATempDir: string): string;
  public
    [Test]
    procedure Test_RealBpl_LoadCallUnload;
    [Test]
    procedure Test_RealBpl_ReloadAfterUnload;
    [Test]
    procedure Test_LoadPlugin_UnsignedFixture_FailClosed;
    [Test]
    procedure Test_Contract_Lifecycle_PODOnly;
    [Test]
    procedure Test_LoadedBpl_IsLocked_NegativeControl;
    [Test]
    procedure Test_UnloadedBpl_FileReleasedAndDeletable;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, Winapi.Windows,
  DeepBase.Plugin, DeepBase.PluginManager;

type
  TProbeAddFunc = function(A, B: Integer): Integer; stdcall;
  TProbeCountFunc = function: Integer; stdcall;

function TPluginBplUnloadTests.FixtureBplPath: string;
begin
  // Test runners execute with the repo root as working directory
  // (same convention as the HB benchmark evidence/probe paths).
  Result := TPath.GetFullPath(
    TPath.Combine('Tests' + TPath.DirectorySeparatorChar + 'Regression',
    'R7P4Probe.bpl'));
end;

function TPluginBplUnloadTests.TryExclusiveOpen(const APath: string;
  out AErrorCode: Cardinal): Boolean;
var
  Handle: THandle;
begin
  AErrorCode := 0;
  Handle := CreateFile(PChar(APath), GENERIC_READ or GENERIC_WRITE, 0, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if Handle = INVALID_HANDLE_VALUE then
  begin
    AErrorCode := GetLastError;
    Exit(False);
  end;
  CloseHandle(Handle);
  Result := True;
end;

function TPluginBplUnloadTests.TryDelete(const APath: string;
  out AErrorCode: Cardinal): Boolean;
begin
  AErrorCode := 0;
  if DeleteFile(PChar(APath)) then
    Exit(True);
  AErrorCode := GetLastError;
  Result := False;
end;

function TPluginBplUnloadTests.CopyFixtureToTemp(out ATempDir: string): string;
var
  Source: string;
begin
  Source := FixtureBplPath;
  ATempDir := TPath.Combine(TPath.GetTempPath,
    'deepbase_d2_bpl_' + IntToStr(GetTickCount));
  TDirectory.CreateDirectory(ATempDir);
  Result := TPath.Combine(ATempDir, TPath.GetFileName(Source));
  TFile.Copy(Source, Result);
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

procedure TPluginBplUnloadTests.Test_Contract_Lifecycle_PODOnly;
var
  Handle: HMODULE;
  RegisterPlugin: TRegisterPluginFunc;
  InitCount, FinalizeCount: TProbeCountFunc;
  Plugin: IDeepBasePlugin;
  BplPath: string;
begin
  // Contract level, not mock level: the fixture is loaded, the manager's own
  // export name and function type are used, and the lifecycle counters are
  // read back from inside the module. A finalize count of 1 can only be
  // observed if Finalize really ran in the loaded BPL. Payloads crossing the
  // boundary here are POD only; see the GetPluginInfo note in the unit header.
  BplPath := FixtureBplPath;
  Assert.IsTrue(TFile.Exists(BplPath), 'fixture BPL missing: ' + BplPath);
  Handle := LoadPackage(BplPath);
  Assert.IsTrue(Handle <> 0, 'LoadPackage must return a real module handle');
  try
    RegisterPlugin := TRegisterPluginFunc(GetProcAddress(Handle, REGISTER_PLUGIN_FUNC));
    Assert.IsTrue(Assigned(RegisterPlugin),
      'fixture must export ' + REGISTER_PLUGIN_FUNC);
    InitCount := TProbeCountFunc(GetProcAddress(Handle, 'ProbeInitCount'));
    FinalizeCount := TProbeCountFunc(GetProcAddress(Handle, 'ProbeFinalizeCount'));
    Assert.IsTrue(Assigned(InitCount) and Assigned(FinalizeCount),
      'fixture must export the lifecycle counters');

    Assert.AreEqual(0, InitCount(), 'no Initialize may have run yet');
    Assert.AreEqual(0, FinalizeCount(), 'no Finalize may have run yet');

    Plugin := RegisterPlugin();
    Assert.IsTrue(Plugin <> nil, 'RegisterPlugin must return a plugin instance');

    Assert.IsTrue(Plugin.Initialize, 'contract Initialize must succeed');
    Assert.AreEqual(1, InitCount(), 'Initialize must run inside the module');

    Assert.IsTrue(Plugin.Finalize, 'contract Finalize must succeed');
    Assert.AreEqual(1, FinalizeCount(), 'Finalize must run inside the module');

    Plugin := nil;
  finally
    UnloadPackage(Handle);
  end;
  Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process after contract-driven unload');
end;

procedure TPluginBplUnloadTests.Test_LoadedBpl_IsLocked_NegativeControl;
var
  Handle: HMODULE;
  OpenedExclusively: Boolean;
  ErrorCode: Cardinal;
  BplPath: string;
begin
  // Negative control for the occupancy probe: without this the "file is free
  // after unload" assertion in Test_UnloadedBpl_FileReleasedAndDeletable would
  // be a tautology (an always-succeeding probe reports freedom either way).
  BplPath := FixtureBplPath;
  Assert.IsTrue(TFile.Exists(BplPath), 'fixture BPL missing: ' + BplPath);
  Handle := LoadPackage(BplPath);
  Assert.IsTrue(Handle <> 0, 'LoadPackage must return a real module handle');
  try
    OpenedExclusively := TryExclusiveOpen(BplPath, ErrorCode);
    WriteLn(Format('[D2-probe] loaded state: exclusive open=%s GetLastError=%d',
      [BoolToStr(OpenedExclusively, True), Integer(ErrorCode)]));
    Assert.IsFalse(OpenedExclusively,
      'exclusive open of a LOADED bpl must fail (probe validity), GetLastError='
      + IntToStr(Integer(ErrorCode)));
    Assert.AreEqual(Cardinal(ERROR_SHARING_VIOLATION), ErrorCode,
      'loaded bpl must be held by the image section (sharing violation)');
  finally
    UnloadPackage(Handle);
  end;
  Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
    'module must leave the process after the negative control');
end;

procedure TPluginBplUnloadTests.Test_UnloadedBpl_FileReleasedAndDeletable;
var
  Handle: HMODULE;
  TempDir, BplPath: string;
  OpenedExclusively: Boolean;
  ErrorCode: Cardinal;
begin
  // File-level release, on a temp copy so the committed fixture stays put:
  // loaded -> probe says locked; unloaded -> exclusive open AND delete succeed.
  BplPath := CopyFixtureToTemp(TempDir);
  try
    Handle := LoadPackage(BplPath);
    Assert.IsTrue(Handle <> 0, 'LoadPackage must return a real module handle');
    Assert.IsFalse(TryExclusiveOpen(BplPath, ErrorCode),
      'temp copy must be locked while loaded');
    UnloadPackage(Handle);
    Assert.AreEqual(HMODULE(0), GetModuleHandle(PChar('R7P4Probe.bpl')),
      'module must leave the process after unload');

    OpenedExclusively := TryExclusiveOpen(BplPath, ErrorCode);
    WriteLn(Format('[D2-probe] unloaded state: exclusive open=%s GetLastError=%d',
      [BoolToStr(OpenedExclusively, True), Integer(ErrorCode)]));
    Assert.IsTrue(OpenedExclusively,
      'exclusive open must succeed after unload (no residual handle), GetLastError='
      + IntToStr(Integer(ErrorCode)));

    Assert.IsTrue(TryDelete(BplPath, ErrorCode),
      'unloaded bpl file must be deletable, GetLastError='
      + IntToStr(Integer(ErrorCode)));
    Assert.IsFalse(TFile.Exists(BplPath), 'file must be gone after delete');
  finally
    if TDirectory.Exists(TempDir) then
      TDirectory.Delete(TempDir, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPluginBplUnloadTests);

end.
