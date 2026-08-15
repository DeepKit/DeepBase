{ ============================================================================
  TestPlugin11NoInvoke - 1.1 缺 invoke 导出 fixture DLL（task#11 场景4）

  用途：模拟报 ABI 1.1、metadata 声明 has_invoke、但 .dpr 故意不导出 dbp_invoke，
  验证 CAbiLoader L189 拒载 "声明 MINOR>=1 但缺 dbp_invoke 导出, capability 不一致"。

  纪律落点：
  - 第一个 uses 必须 ShareMem（跨边界共享内存管理器，77a §2.3）；
  - 与宿主编译同一份 Core/...Contracts + Core/...CAbi 源码（ABI 一致）；
  - 仅导出 9 项必需 dbp_*（无 dbp_invoke / dbp_invoke_alloc）—— 故意缺。
  ============================================================================ }
library TestPlugin11NoInvoke;

uses
  ShareMem,
  System.SysUtils,
  DeepBase.Plugins.Contracts in '..\..\..\Core\DeepBase.Plugins.Contracts.pas',
  DeepBase.Plugins.CAbi in '..\..\..\Core\DeepBase.Plugins.CAbi.pas',
  TestPlugin11NoInvoke.Impl in 'TestPlugin11NoInvoke.Impl.pas',
  TestPlugin11NoInvoke.CAbi in 'TestPlugin11NoInvoke.CAbi.pas';

exports
  dbp_create name 'dbp_create',
  dbp_destroy name 'dbp_destroy',
  dbp_get_abi name 'dbp_get_abi',
  dbp_initialize name 'dbp_initialize',
  dbp_shutdown name 'dbp_shutdown',
  dbp_reload_config name 'dbp_reload_config',
  dbp_get_metadata name 'dbp_get_metadata',
  dbp_get_health name 'dbp_get_health',
  dbp_get_last_error name 'dbp_get_last_error',
  dbp_free_buffer name 'dbp_free_buffer';

begin
end.
