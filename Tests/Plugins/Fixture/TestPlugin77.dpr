{ ============================================================================
  TestPlugin77 - 77-S3 验收测试 fixture 插件 DLL

  法源：docs/77a.adr.Plugin-ABI-and-Lifetime §4（验收测试）
        docs/77.extend.PluginHotReload §5（纯 C 数据面，P0-001）

  纪律落点：
  - 第一个 uses 必须 ShareMem（跨边界共享内存管理器，77a §2.3）；
  - 与宿主编译同一份 DeepBase.Plugins.Contracts 源码（ABI 一致）；
  - 导出工厂按 Manager Kind 前缀约定：Create + <插件名> + Plugin；
  - P0-001 追加 dbp_* 纯 C 导出（exports 'dbp_*' 固定名）。
  ============================================================================ }
library TestPlugin77;

uses
  ShareMem,
  System.SysUtils,
  DeepBase.Plugins.Contracts in '..\..\..\Core\DeepBase.Plugins.Contracts.pas',
  DeepBase.Plugins.CAbi in '..\..\..\Core\DeepBase.Plugins.CAbi.pas',
  TestPlugin77.Impl in 'TestPlugin77.Impl.pas',
  TestPlugin77.CAbi in 'TestPlugin77.CAbi.pas';

exports
  { 旧 Delphi 接口工厂（41/41 兼容） }
  CreateEchoPlugin name 'CreateEchoPlugin',
  CreateBasePlugin name 'CreateBasePlugin',
  CreateAbiBadPlugin name 'CreateAbiBadPlugin',
  { P0-001 纯 C ABI（exports 'dbp_*' 固定名） }
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
