{ ============================================================================
  TestPlugin11NoHealth - 1.1 缺 dbp_get_health 导出 fixture DLL（task#11 场景3）

  用途：模拟报 ABI 1.1、带 dbp_invoke 导出（避免误倒场景4 invoke 缺失门）、但
  故意不导出 dbp_get_health，验证 CAbiLoader ResolveProc L230 拒载
  "缺少导出函数 dbp_get_health"。

  纪律落点：
  - 第一个 uses 必须 ShareMem（跨边界共享内存管理器，77a §2.3）；
  - 与宿主编译同一份 Core/...Contracts + Core/...CAbi 源码（ABI 一致）；
  - 导出 8 项必需 + dbp_invoke；故意缺 dbp_get_health。
  ============================================================================ }
library TestPlugin11NoHealth;

uses
  ShareMem,
  System.SysUtils,
  DeepBase.Plugins.Contracts in '..\..\..\Core\DeepBase.Plugins.Contracts.pas',
  DeepBase.Plugins.CAbi in '..\..\..\Core\DeepBase.Plugins.CAbi.pas',
  TestPlugin11NoHealth.Impl in 'TestPlugin11NoHealth.Impl.pas',
  TestPlugin11NoHealth.CAbi in 'TestPlugin11NoHealth.CAbi.pas';

exports
  dbp_create name 'dbp_create',
  dbp_destroy name 'dbp_destroy',
  dbp_get_abi name 'dbp_get_abi',
  dbp_initialize name 'dbp_initialize',
  dbp_shutdown name 'dbp_shutdown',
  dbp_reload_config name 'dbp_reload_config',
  dbp_get_metadata name 'dbp_get_metadata',
  { dbp_get_health 故意缺 —— 场景3 核心点 }
  dbp_get_last_error name 'dbp_get_last_error',
  dbp_free_buffer name 'dbp_free_buffer',
  dbp_invoke name 'dbp_invoke';

begin
end.
