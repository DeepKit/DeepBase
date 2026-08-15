{ ============================================================================
  TestPluginABI10 - ABI 1.0 fixture 插件 DLL（task#11 A11-1/A11-2）

  用途：模拟报 ABI major=1/minor=0、无 dbp_invoke 导出的旧插件，验证
  CAbiLoader L187 契约（minor<1 不要求 invoke → 加载合法）+ 软拒绝 EMissingInvoke。

  纪律落点：
  - 第一个 uses 必须 ShareMem（跨边界共享内存管理器，77a §2.3）；
  - 与宿主编译同一份 Core/DeepBase.Plugins.Contracts + Core/DeepBase.Plugins.CAbi 源码（ABI 一致）；
  - 仅导出 9 项 dbp_* 必需导出（无 dbp_invoke / dbp_invoke_alloc）。
  ============================================================================ }
library TestPluginABI10;

uses
  ShareMem,
  System.SysUtils,
  DeepBase.Plugins.Contracts in '..\..\..\Core\DeepBase.Plugins.Contracts.pas',
  DeepBase.Plugins.CAbi in '..\..\..\Core\DeepBase.Plugins.CAbi.pas',
  TestPluginABI10.Impl in 'TestPluginABI10.Impl.pas',
  TestPluginABI10.CAbi in 'TestPluginABI10.CAbi.pas';

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
