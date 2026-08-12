{ ============================================================================
  PluginLifecycleHarness - 77a ADR §4 验收测试独立运行器

  法源：docs/77a.adr.Plugin-ABI-and-Lifetime §4 验收要点：
    1. 热重载循环 100 次句柄不泄漏；
    2. Lease 超时用例（人为占用）触发 psError 且进程不崩；
    3. 依赖环用例（A→B→A）注册即被拒。

  独立 harness 原因：主测试工程 DeepBaseTests.exe 为静态 RTL，
  插件 DLL 跨边界共享内存管理器需宿主/DLL 均 ShareMem，独立编译链路
  （仿 Tests\Governance\build_pbt.bat）避免污染主测试工程。

  用法：build_plugin_tests.bat 编译 fixture DLL 与本工程后运行，
  exit code = 失败项数（0 = 全绿）。
  ============================================================================ }
program PluginLifecycleHarness;

{$APPTYPE CONSOLE}

uses
  ShareMem,
  System.SysUtils, System.Classes, System.IOUtils, System.Hash,
  Winapi.Windows,
  DeepBase.Plugins.Contracts in '..\..\Core\DeepBase.Plugins.Contracts.pas',
  DeepBase.Plugins.SafeGuard in '..\..\Core\DeepBase.Plugins.SafeGuard.pas',
  DeepBase.Plugins.Verifier in '..\..\Core\DeepBase.Plugins.Verifier.pas',
  DeepBase.Plugins.Manager in '..\..\Core\DeepBase.Plugins.Manager.pas';

function GetProcessHandleCount(hProcess: THandle;
  var lpdwHandleCount: DWORD): BOOL; stdcall;
  external kernel32 name 'GetProcessHandleCount';

var
  GPass, GFail: Integer;
  GDllPath: string;
  GDllHash: string;

procedure Check(const AName: string; ACond: Boolean; const ADetail: string);
begin
  if ACond then
  begin
    Inc(GPass);
    Writeln('  PASS  ', AName);
  end
  else
  begin
    Inc(GFail);
    Writeln('  FAIL  ', AName, '  [', ADetail, ']');
  end;
end;

function NewMgr: TDeepBasePluginManager;
begin
  { 每个用例独立 Manager + 独立 Verifier（避免全局单例与 psError 残留） }
  Result := TDeepBasePluginManager.Create(ExtractFilePath(GDllPath));
  Result.Verifier := TPluginVerifier.Create;  // StrictMode 默认 True，空白名单
  Result.RegisterPluginKind('echo', 'Create');
end;

procedure RegEcho(AMgr: TDeepBasePluginManager; const AName: string);
begin
  AMgr.RegisterPlugin(AName, 'echo');
  AMgr.SetPluginDllPath(AName, GDllPath);
end;

{ --- T01: 依赖环注册即拒（ADR §4 验收点 3） --- }
procedure Test_CycleDetection;
var
  M: TDeepBasePluginManager;
  LRaised: Boolean;
begin
  Writeln('[01] dependency cycle detection at registration');
  M := NewMgr;
  try
    RegEcho(M, 'A');
    M.RegisterPlugin('B', 'echo', TArray<string>.Create('A'));
    // B 依赖 A 已成立，A->B->A 环应在 B 反向注册时拒绝
    LRaised := False;
    try
      M.RegisterPlugin('A2', 'echo', TArray<string>.Create('B2'));
      // 先造 B2 依赖 A2 的环：此处 A2 依赖未注册的 B2，无环，应成功
    except
      LRaised := True;
    end;
    Check('forward dep (no cycle) accepted', not LRaised, '意外抛异常');

    LRaised := False;
    try
      M.RegisterPlugin('B2', 'echo', TArray<string>.Create('A2'));
      // B2->A2->B2 成环（A2 已声明依赖 B2）
    except
      on E: Exception do
        LRaised := E is EPluginDependencyError;
    end;
    Check('A2->B2->A2 cycle rejected at register', LRaised,
      '未抛 EPluginDependencyError');

    LRaised := False;
    try
      M.RegisterPlugin('Self', 'echo', TArray<string>.Create('Self'));
    except
      on E: Exception do
        LRaised := E is EPluginDependencyError;
    end;
    Check('self-dependency rejected', LRaised, '未抛 EPluginDependencyError');

    M.RegisterPlugin('X', 'echo', TArray<string>.Create('Y'));
    M.RegisterPlugin('Y', 'echo', TArray<string>.Create('Z'));
    LRaised := False;
    try
      M.RegisterPlugin('Z', 'echo', TArray<string>.Create('X'));
    except
      on E: Exception do
        LRaised := E is EPluginDependencyError;
    end;
    Check('3-node cycle X->Y->Z->X rejected', LRaised,
      '未抛 EPluginDependencyError');

    LRaised := False;
    try
      M.RegisterPlugin('A', 'echo');
    except
      on E: Exception do
        LRaised := E is EPluginRegistrationError;
    end;
    Check('duplicate registration rejected', LRaised,
      '未抛 EPluginRegistrationError');
  finally
    M.Free;
  end;
end;

{ --- T02: 签名严格模式（ADR §2.6 白名单 SHA-256） --- }
procedure Test_Signature;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  LV: TPluginVerifier;
begin
  Writeln('[02] signature verification (strict mode)');

  // 2a: 未注册可信哈希 -> 严格模式拒载
  M := NewMgr;
  try
    RegEcho(M, 'Echo');
    LCode := M.LoadPlugin('Echo');
    Check('unregistered hash rejected', LCode = PLUGIN_LOAD_FAILED,
      'code=' + IntToStr(LCode));
    Check('state=psError after reject',
      M.GetPluginInfo('Echo').State = psError,
      PluginStateToStr(M.GetPluginInfo('Echo').State));
  finally
    M.Free;
  end;

  // 2b: 哈希不匹配（疑似篡改）-> 拒载
  M := NewMgr;
  try
    LV := TPluginVerifier(M.Verifier);
    LV.RegisterTrustedHash('TestPlugin77.dll', StringOfChar('0', 64));
    RegEcho(M, 'Echo');
    LCode := M.LoadPlugin('Echo');
    Check('hash mismatch rejected', LCode = PLUGIN_LOAD_FAILED,
      'code=' + IntToStr(LCode));
  finally
    M.Free;
  end;

  // 2c: 白名单放行
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    RegEcho(M, 'Echo');
    LCode := M.LoadPlugin('Echo');
    Check('whitelisted hash loads OK', LCode = PLUGIN_OK,
      'code=' + IntToStr(LCode));
  finally
    M.Free;
  end;
end;

{ --- T03: ABI major 不兼容必须拒载（ADR §2.1） --- }
procedure Test_AbiNegotiation;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
begin
  Writeln('[03] ABI negotiation');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('AbiBad', 'echo', nil, 'CreateAbiBadPlugin');
    M.SetPluginDllPath('AbiBad', GDllPath);
    LCode := M.LoadPlugin('AbiBad');
    Check('ABI major mismatch rejected', LCode = PLUGIN_LOAD_FAILED,
      'code=' + IntToStr(LCode));
    Check('state=psError after ABI reject',
      M.GetPluginInfo('AbiBad').State = psError,
      PluginStateToStr(M.GetPluginInfo('AbiBad').State));
  finally
    M.Free;
  end;
end;
{ --- T04: Lease 获取/释放计数 --- }
procedure Test_LeaseAcquireRelease;
var
  M: TDeepBasePluginManager;
  L1, L2: TPluginLease;
  LCode: Integer;
  LMeta: TBytes;
begin
  Writeln('[04] lease acquire/release counting');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    RegEcho(M, 'Echo');
    LCode := M.AcquireLease('Echo', L1);
    Check('acquire #1 OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    LCode := M.AcquireLease('Echo', L2);
    Check('acquire #2 OK (concurrent)', LCode = PLUGIN_OK,
      'code=' + IntToStr(LCode));
    Check('ActiveLeases=2', M.GetPluginInfo('Echo').ActiveLeases = 2,
      'got ' + IntToStr(M.GetPluginInfo('Echo').ActiveLeases));

    // Lease 持有期间跨边界调用（TBytes var 协议）
    LMeta := nil;
    LCode := L1.Plugin.GetMetadata(LMeta);
    Check('cross-boundary GetMetadata OK',
      (LCode = PLUGIN_OK) and (Length(LMeta) > 0), 'code=' + IntToStr(LCode));

    M.ReleaseLease(L1);
    M.ReleaseLease(L2);
    Check('ActiveLeases=0 after release',
      M.GetPluginInfo('Echo').ActiveLeases = 0,
      'got ' + IntToStr(M.GetPluginInfo('Echo').ActiveLeases));
  finally
    M.Free;
  end;
end;

{ --- T05: Lease 占用导致 Unload 超时 -> psError 且禁止强制 FreeLibrary
         （ADR §4 验收点 2；注入 LeaseDrainTimeoutMs 短超时） --- }
procedure Test_LeaseDrainTimeout;
var
  M: TDeepBasePluginManager;
  LLease, LHeldLease: TPluginLease;
  LCode, LCode2: Integer;
  LThreadCode: Integer;
  LInfo: TPluginInfo;
  LHandleBefore: HMODULE;
  T: TThread;
begin
  Writeln('[05] lease drain timeout -> psError, DLL kept loaded');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.LeaseDrainTimeoutMs := 1500;  // 验收注入点（生产保持 300000）
    RegEcho(M, 'Echo');
    LCode := M.AcquireLease('Echo', LLease, 2000);
    Check('acquire lease OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    if LCode <> PLUGIN_OK then Exit;

    LHeldLease := LLease;
    LHandleBefore := M.GetPluginInfo('Echo').Handle;
    LThreadCode := PLUGIN_OK;
    T := TThread.CreateAnonymousThread(
      procedure
      begin
        LThreadCode := M.UnloadPlugin('Echo');
      end);
    T.FreeOnTerminate := False;
    T.Start;
    T.WaitFor;
    T.Free;
    Check('unload with held lease -> PLUGIN_LEASE_TIMEOUT',
      LThreadCode = PLUGIN_LEASE_TIMEOUT, 'code=' + IntToStr(LThreadCode));

    LInfo := M.GetPluginInfo('Echo');
    Check('state=psError after drain timeout', LInfo.State = psError,
      PluginStateToStr(LInfo.State));
    Check('DLL handle NOT force-freed (77a ban on forced FreeLibrary)',
      LInfo.Handle = LHandleBefore,
      Format('before=%d after=%d', [LHandleBefore, LInfo.Handle]));

    // psError 后 AcquireLease 必须快速失败（人工介入语义）
    LCode := M.AcquireLease('Echo', LLease);
    Check('acquire after psError rejected',
      (LCode <> PLUGIN_OK), 'code=' + IntToStr(LCode));

    // 持有者归还后，二次 Unload 应能完成收尾（无需人工 FreeLibrary）
    M.ReleaseLease(LHeldLease);
    LCode2 := M.UnloadPlugin('Echo');
    Check('second unload succeeds after lease released',
      LCode2 = PLUGIN_OK, 'code=' + IntToStr(LCode2));
    Check('state=psUnloaded finally',
      M.GetPluginInfo('Echo').State = psUnloaded,
      PluginStateToStr(M.GetPluginInfo('Echo').State));
  finally
    M.Free;
  end;
end;

{ --- T06: 热重载 100 次句柄不泄漏（ADR §4 验收点 1） --- }
procedure Test_HotReload100;
const
  RELOADS = 100;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  I: Integer;
  LBefore, LAfter, LFinal: DWORD;
  LFirstErr: string;
begin
  Writeln('[06] hot reload x', RELOADS, ' (handle leak check)');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    RegEcho(M, 'Echo');
    LCode := M.LoadPlugin('Echo');
    Check('initial load OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    if LCode <> PLUGIN_OK then Exit;

    GetProcessHandleCount(GetCurrentProcess, LBefore);
    LFirstErr := '';
    for I := 1 to RELOADS do
    begin
      LCode := M.ReloadPlugin('Echo');
      if (LCode <> PLUGIN_OK) and (LFirstErr = '') then
        LFirstErr := Format('iter %d: code=%d', [I, LCode]);
    end;
    GetProcessHandleCount(GetCurrentProcess, LAfter);

    Check('all 100 reloads OK', LFirstErr = '', LFirstErr);
    Check('ReloadCount=' + IntToStr(RELOADS),
      M.GetPluginInfo('Echo').ReloadCount = RELOADS,
      'got ' + IntToStr(M.GetPluginInfo('Echo').ReloadCount));
    Check('process handle count stable (delta<=10)',
      Integer(LAfter) - Integer(LBefore) <= 10,
      Format('before=%d after=%d delta=%d',
        [LBefore, LAfter, Integer(LAfter) - Integer(LBefore)]));

    LCode := M.UnloadPlugin('Echo');
    Check('final unload OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    GetProcessHandleCount(GetCurrentProcess, LFinal);
    Check('handles drained after unload (delta<=10 vs baseline)',
      Integer(LFinal) - Integer(LBefore) <= 10,
      Format('baseline=%d final=%d delta=%d',
        [LBefore, LFinal, Integer(LFinal) - Integer(LBefore)]));
  finally
    M.Free;
  end;
end;

{ --- T07: SafeGuard 崩溃隔离 + 熔断 + 恢复 --- }
procedure Test_SafeGuardCrash;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  I: Integer;
  LLease: TPluginLease;
  LCrashCfg: TBytes;
  LOkCfg: TBytes;
begin
  Writeln('[07] SafeGuard crash isolation + circuit breaker');
  LCrashCfg := TEncoding.UTF8.GetBytes('{"trigger":"crash"}');
  LOkCfg := TEncoding.UTF8.GetBytes('{}');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.SafeGuard.MaxCrashBeforeDisable := 3;
    RegEcho(M, 'Echo');
    LCode := M.LoadPlugin('Echo');
    Check('load OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    if LCode <> PLUGIN_OK then Exit;

    for I := 1 to 3 do
    begin
      LCode := M.ReloadPluginConfig('Echo', LCrashCfg);
      Check(Format('crash #%d caught by SafeGuard (no host crash)', [I]),
        LCode <> PLUGIN_OK, 'code=' + IntToStr(LCode));
    end;
    Check('crash count=3', M.SafeGuard.GetCrashCount('Echo') = 3,
      'got ' + IntToStr(M.SafeGuard.GetCrashCount('Echo')));
    Check('plugin disabled after 3 crashes',
      M.SafeGuard.IsDisabled('Echo'), '未熔断');

    LCode := M.AcquireLease('Echo', LLease, 100);
    Check('acquire while circuit-open -> PLUGIN_BUSY',
      LCode = PLUGIN_BUSY, 'code=' + IntToStr(LCode));

    M.SafeGuard.ReEnablePlugin('Echo');
    LCode := M.ReloadPluginConfig('Echo', LOkCfg);
    Check('re-enabled plugin recovers (ReloadConfig OK)',
      LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
  finally
    M.Free;
  end;
end;

{ --- T08: 依赖加载（失败传播 + 正向链） --- }
procedure Test_DependencyLoad;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
begin
  Writeln('[08] dependency loading');

  // 8a: 依赖 DLL 不存在 -> PLUGIN_DEPENDENCY_FAILED 传播
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('Top', 'echo', TArray<string>.Create('Ghost'));
    M.SetPluginDllPath('Top', GDllPath);
    M.RegisterPlugin('Ghost', 'echo');
    M.SetPluginDllPath('Ghost',
      ExtractFilePath(GDllPath) + 'NoSuchGhostPlugin.dll');
    LCode := M.LoadPlugin('Top');
    Check('missing dep propagates PLUGIN_DEPENDENCY_FAILED',
      LCode = PLUGIN_DEPENDENCY_FAILED, 'code=' + IntToStr(LCode));
    Check('Top state=psError', M.GetPluginInfo('Top').State = psError,
      PluginStateToStr(M.GetPluginInfo('Top').State));
  finally
    M.Free;
  end;

  // 8b: 正向依赖链（同一 DLL 两个注册名）
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('Base', 'echo', nil, 'CreateBasePlugin');
    M.SetPluginDllPath('Base', GDllPath);
    M.RegisterPlugin('Top', 'echo', TArray<string>.Create('Base'),
      'CreateEchoPlugin');
    M.SetPluginDllPath('Top', GDllPath);
    LCode := M.LoadPlugin('Top');
    Check('dep chain loads OK', LCode = PLUGIN_OK,
      'code=' + IntToStr(LCode));
    Check('Base auto-loaded as dependency', M.IsLoaded('Base'), 'Base 未加载');
  finally
    M.Free;
  end;
end;

begin
  try
    Writeln('========================================================');
    Writeln(' PluginLifecycleHarness - 77a ADR acceptance tests');
    Writeln('========================================================');
    GDllPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
      'TestPlugin77.dll';
    if not FileExists(GDllPath) then
    begin
      Writeln('FATAL: fixture DLL not found: ', GDllPath);
      ExitCode := 2;
      Exit;
    end;
    GDllHash := LowerCase(THashSHA2.GetHashStringFromFile(GDllPath));
    Writeln('fixture: ', GDllPath);
    Writeln('sha256 : ', GDllHash);
    Writeln;

    Test_CycleDetection;
    Test_Signature;
    Test_AbiNegotiation;
    Test_LeaseAcquireRelease;
    Test_LeaseDrainTimeout;
    Test_HotReload100;
    Test_SafeGuardCrash;
    Test_DependencyLoad;

    Writeln;
    Writeln(Format('RESULT: %d passed, %d failed', [GPass, GFail]));
    if GFail = 0 then
      Writeln('ALL GREEN - 77a ADR acceptance criteria satisfied')
    else
      Writeln('ACCEPTANCE FAILED');
    ExitCode := GFail;
  except
    on E: Exception do
    begin
      Writeln('FATAL exception in harness: ', E.ClassName, ': ', E.Message);
      ExitCode := 3;
    end;
  end;
end.
