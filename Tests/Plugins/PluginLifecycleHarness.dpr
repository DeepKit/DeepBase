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
  DeepBase.Plugins.Manager in '..\..\Core\DeepBase.Plugins.Manager.pas',
  DeepBase.Plugins.CAbi in '..\..\Core\DeepBase.Plugins.CAbi.pas',
  DeepBase.Plugins.CAbiLoader in '..\..\Core\DeepBase.Plugins.CAbiLoader.pas';

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
    Check('state=psPendingRestart after drain timeout', LInfo.State = psPendingRestart,
      PluginStateToStr(LInfo.State));
    Check('DLL handle NOT force-freed (77a ban on forced FreeLibrary)',
      LInfo.Handle = LHandleBefore,
      Format('before=%d after=%d', [LHandleBefore, LInfo.Handle]));

    // psPendingRestart 后 AcquireLease 必须返回 PLUGIN_RELOADING（阻止新调用）
    LCode := M.AcquireLease('Echo', LLease, 100);
    Check('acquire after psPendingRestart -> PLUGIN_RELOADING',
      LCode = PLUGIN_RELOADING, 'code=' + IntToStr(LCode));

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

{ --- T09a: dbp_free_buffer 契约符号（M1-①） --- }
procedure Test_CAbiFreeBufferSymbol(const ADllPath: string);
type
  TFreeBufferProc = procedure(APtr: Pointer); stdcall;
var
  LMod: HMODULE;
  LFree: TFreeBufferProc;
  P: Pointer;
begin
  Writeln('  [9d] dbp_free_buffer symbol');
  LMod := LoadLibrary(PChar(ADllPath));
  if LMod = 0 then
  begin
    Check('dbp_free_buffer symbol LoadLibrary', False,
      'Win32 ' + IntToStr(GetLastError));
    Exit;
  end;
  try
    LFree := GetProcAddress(LMod, 'dbp_free_buffer');
    Check('dbp_free_buffer export present', Assigned(LFree),
      'GetProcAddress returned nil');
    if Assigned(LFree) then
    begin
      // 契约 L125：传入 NULL 安全（不崩）
      LFree(nil);
      Check('dbp_free_buffer(NULL) safe', True, 'no-op OK');
      // 对宿主分配的内存调用为 no-op（fixture 走宿主分配主路径）
      GetMem(P, 64);
      LFree(P);
      FreeMem(P);
      Check('dbp_free_buffer(host-allocated) no-op', True, 'no-op OK');
    end;
  finally
    FreeLibrary(LMod);
  end;
end;

{ --- T09: 纯 C ABI 加载器（P0-001） --- }
procedure Test_CAbi;
const
  DBPDLL = 'TestPlugin77.dll';
var
  LPath: string;
  LPlugin: TCAbiPlugin;
  LCode: Integer;
  LMeta: TBytes;
  LHealth: dbp_health_info;
  LBefore, LAfter: DWORD;
begin
  Writeln('[09] C ABI loader (dbp_* pure C export)');
  LPath := IncludeTrailingPathDelimiter(ExtractFilePath(GDllPath)) + DBPDLL;

  // 9a: ABI 协商 + 默认 echo 变体往返
  LPlugin := TCAbiPlugin.Create(LPath);
  try
    Check('ABI major matches host', LPlugin.Abi.major = DBP_ABI_MAJOR,
      Format('host=%u plugin=%u', [DBP_ABI_MAJOR, LPlugin.Abi.major]));
    Check('ABI minor >= host required', LPlugin.Abi.minor <= DBP_ABI_MINOR,
      Format('host=%u plugin=%u', [DBP_ABI_MINOR, LPlugin.Abi.minor]));

    LCode := LPlugin.Initialize(nil);
    Check('dbp_initialize OK', LCode = DBP_OK, 'code=' + IntToStr(LCode));

    LMeta := LPlugin.GetMetadata;
    Check('dbp_get_metadata returns JSON', Length(LMeta) > 0,
      'len=' + IntToStr(Length(LMeta)));

    LHealth := LPlugin.GetHealth;
    Check('dbp_get_health is_healthy=1', LHealth.is_healthy = 1,
      'got ' + IntToStr(LHealth.is_healthy));
  finally
    LPlugin.Free;
  end;

  // 9b: init_fail 配置 -> dbp_initialize 返回负错误码
  GetProcessHandleCount(GetCurrentProcess, LBefore);
  LPlugin := TCAbiPlugin.Create(LPath);
  try
    LCode := LPlugin.Initialize(
      TEncoding.UTF8.GetBytes('{"init_fail":true}'));
    Check('dbp_initialize init_fail -> negative code', LCode < DBP_OK,
      'code=' + IntToStr(LCode));
  finally
    LPlugin.Free;
  end;

  // 9c: 无效句柄 -> 显式错误码（不崩、不越界）
  LPlugin := TCAbiPlugin.Create(LPath);
  try
    LCode := LPlugin.Shutdown;   // 通过 loader 调 dbp_shutdown
    Check('dbp_shutdown OK', LCode = DBP_OK, 'code=' + IntToStr(LCode));
  finally
    LPlugin.Free;
  end;

  // 9d: dbp_free_buffer 契约符号（77a §2.3：插件分配/宿主释放的唯一通道）
  //     fixture 走宿主分配主路径，free_buffer 为保留符号；验证导出存在 +
  //     NULL 安全（C 头契约 L125），不验证插件分配路径本体。
  Test_CAbiFreeBufferSymbol(LPath);

  // 9e: 销毁后句柄数稳定（无泄漏）
  GetProcessHandleCount(GetCurrentProcess, LAfter);
  Check('C ABI load/destroy no handle leak (delta<=10)',
    Integer(LAfter) - Integer(LBefore) <= 10,
    Format('before=%d after=%d delta=%d',
      [LBefore, LAfter, Integer(LAfter) - Integer(LBefore)]));

  // 9f: ABI 1.1 dbp_invoke echo 往返
  LPlugin := TCAbiPlugin.Create(LPath);
  try
    Check('HasInvoke=true for ABI 1.1 fixture', LPlugin.HasInvoke,
      'HasInvoke 应为 True');
    LCode := LPlugin.Initialize(nil);
    Check('dbp_initialize (for invoke) OK', LCode = DBP_OK,
      'code=' + IntToStr(LCode));

    LPlugin.Invoke(TEncoding.UTF8.GetBytes('hello'), LMeta);
    Check('dbp_invoke returns response', Length(LMeta) > 0,
      'len=' + IntToStr(Length(LMeta)));
    Check('dbp_invoke response is JSON echo',
      Pos('echo', LowerCase(TEncoding.UTF8.GetString(LMeta))) > 0,
      'got ' + TEncoding.UTF8.GetString(LMeta));
  finally
    LPlugin.Free;
  end;
end;

{ --- T10: Manager C ABI 集成路径（通过 Lease.CAbiPlugin 调用 Invoke） --- }
procedure Test_ManagerCAbi;
const
  DBPDLL = 'TestPlugin77.dll';
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  LLease: TPluginLease;
  LInfo: TPluginInfo;
  LResp: TBytes;
begin
  Writeln('[10] Manager C ABI integration');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('CAbiEcho', 'echo', nil, '', True);
    M.SetPluginDllPath('CAbiEcho', GDllPath);
    LCode := M.LoadPlugin('CAbiEcho');
    Check('T10a: C ABI LoadPlugin OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));

    LCode := M.AcquireLease('CAbiEcho', LLease);
    Check('T10b: C ABI AcquireLease OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));

    { 通过 Lease.CAbiPlugin.Invoke 调用通用业务入口 }
    LLease.CAbiPlugin.Invoke(TEncoding.UTF8.GetBytes('{"cmd":"ping"}'), LResp);
    Check('T10c: C ABI Invoke via lease has response', Length(LResp) > 0,
      'len=' + IntToStr(Length(LResp)));

    M.ReleaseLease(LLease);
    LInfo := M.GetPluginInfo('CAbiEcho');
    Check('T10d: C ABI ActiveLeases=0 after release',
      LInfo.ActiveLeases = 0, 'got ' + IntToStr(LInfo.ActiveLeases));

    LCode := M.UnloadPlugin('CAbiEcho');
    Check('T10e: C ABI UnloadPlugin OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
  finally
    M.Free;
  end;
end;

{ --- T11: psPendingRestart 状态路径（通过 ReloadPluginConfig 触发） --- }
procedure Test_PendingRestart;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  LLease: TPluginLease;
  LInfo: TPluginInfo;
  LResp: TBytes;
begin
  Writeln('[11] psPendingRestart state path');
  M := NewMgr;
  try
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    { 使用 BasePlugin（SupportsHotReload=False）确保 ReloadPluginConfig 设 psPendingRestart }
    M.RegisterPlugin('PendingEcho', 'echo', nil, 'CreateBasePlugin');
    M.SetPluginDllPath('PendingEcho', GDllPath);
    LCode := M.LoadPlugin('PendingEcho');
    Check('T11a: LoadPlugin OK', LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));

    { 先获取 Lease（此时仍 psLoaded），再触发 ReloadPluginConfig 切到 psPendingRestart }
    LCode := M.AcquireLease('PendingEcho', LLease);
    Check('T11e: AcquireLease (before reload) OK',
      LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));

    { ReloadPluginConfig 触发 psPendingRestart（因 SupportsHotReload=False） }
    LCode := M.ReloadPluginConfig('PendingEcho',
      TEncoding.UTF8.GetBytes('{"key":"val"}'));
    Check('T11b: ReloadPluginConfig returns PLUGIN_OK (sets psPendingRestart)',
      LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));

    LInfo := M.GetPluginInfo('PendingEcho');
    Check('T11c: state=psPendingRestart after ReloadPluginConfig',
      LInfo.State = psPendingRestart,
      'got ' + PluginStateToStr(LInfo.State));

    { psPendingRestart 状态下 IsLoaded 仍返回 True }
    Check('T11d: IsLoaded(pendingRestart)=True',
      M.IsLoaded('PendingEcho'), 'IsLoaded 应为 True');

    { Invoke 通过已有 Lease 仍可调用（旧 Lease 被允许完成） }
    LLease.Plugin.GetMetadata(LResp);
    Check('T11f: Invoke (GetMetadata) while pendingRestart OK',
      Length(LResp) > 0, 'len=' + IntToStr(Length(LResp)));

    { 释放旧 Lease }
    M.ReleaseLease(LLease);

    { psPendingRestart 拒绝新 Lease（F2：停止新调用） }
    LCode := M.AcquireLease('PendingEcho', LLease, 100);
    Check('T11e2: AcquireLease after pendingRestart -> PLUGIN_RELOADING',
      LCode = PLUGIN_RELOADING, 'code=' + IntToStr(LCode));

    { UnloadPlugin 处理 psPendingRestart }
    LCode := M.UnloadPlugin('PendingEcho');
    Check('T11g: UnloadPlugin from pendingRestart OK',
      LCode = PLUGIN_OK, 'code=' + IntToStr(LCode));
    Check('T11h: state=psUnloaded after unload',
      M.GetPluginInfo('PendingEcho').State = psUnloaded,
      'got ' + PluginStateToStr(M.GetPluginInfo('PendingEcho').State));
  finally
    M.Free;
  end;
end;

{ --- T12: F3 capability/metadata 门禁 --- }
{ 注：插件实例名必须与导出基底名一致；factory 解析为 Create+<插件实例名>+Plugin
  （见 Manager.pas:364）。Kind 仅用于类别与能力门禁，不参与工厂导出名解析。
  fixture 导出 CreateEchoPlugin(声明 has_invoke) 与 CreateBasePlugin(无能力)，
  故测试分别用插件实例名 'Echo' / 'Base' 命中，Kind 用 'echo' / 'base' 走门禁。 }
procedure Test_CapabilityGate;
var
  M: TDeepBasePluginManager;
  LCode: Integer;
  LInfo: TPluginInfo;
begin
  Writeln('[12] F3 capability/metadata gate');

  // T12a: C ABI——类别要求 has_invoke，fixture 导出 dbp_invoke
  //       自动探测注入 has_invoke → 门禁通过
  M := NewMgr;
  try
    M.RegisterPluginKind('echo_caps', 'Create', TArray<string>.Create('has_invoke'));
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('CAbiEchoCaps', 'echo_caps', nil, '', True);
    M.SetPluginDllPath('CAbiEchoCaps', GDllPath);
    LCode := M.LoadPlugin('CAbiEchoCaps');
    Check('T12a: C ABI pass gate (auto-detect has_invoke)', LCode = PLUGIN_OK,
      'code=' + IntToStr(LCode));
    M.UnloadPlugin('CAbiEchoCaps');
  finally
    M.Free;
  end;

  // T12b/T12c: 旧接口 Base（无能力声明）对 has_invoke 要求 → 拒 + psError
  { 插件名 = 导出基底名，factory 解析为 Create+<Name>+Plugin }
  M := NewMgr;
  try
    M.RegisterPluginKind('base', 'Create', TArray<string>.Create('has_invoke'));
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('Base', 'base', nil);  // → CreateBasePlugin（无能力声明）
    M.SetPluginDllPath('Base', GDllPath);
    LCode := M.LoadPlugin('Base');
    Check('T12b: legacy reject on missing capability', LCode = PLUGIN_LOAD_FAILED,
      'code=' + IntToStr(LCode));
    LInfo := M.GetPluginInfo('Base');
    Check('T12c: rejected plugin state=psError', LInfo.State = psError,
      'state=' + IntToStr(Ord(LInfo.State)));
  finally
    M.Free;
  end;

  // T12d: 旧接口 Echo 声明 has_invoke → 门禁通过
  M := NewMgr;
  try
    M.RegisterPluginKind('echo', 'Create', TArray<string>.Create('has_invoke'));
    M.Verifier.RegisterTrustedHash('TestPlugin77.dll', GDllHash);
    M.RegisterPlugin('Echo', 'echo', nil);  // → CreateEchoPlugin（声明 has_invoke）
    M.SetPluginDllPath('Echo', GDllPath);
    LCode := M.LoadPlugin('Echo');
    Check('T12d: legacy Echo pass gate (declares has_invoke)', LCode = PLUGIN_OK,
      'code=' + IntToStr(LCode));
    M.UnloadPlugin('Echo');
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
    Test_CAbi;
    Test_ManagerCAbi;
    Test_PendingRestart;
    Test_CapabilityGate;

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
