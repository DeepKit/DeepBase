{ ============================================================================
  TestPlugin77 - 77-S3 验收测试 fixture 插件 DLL

  法源：docs/77a.adr.Plugin-ABI-and-Lifetime §4（验收测试）

  纪律落点：
  - 第一个 uses 必须 ShareMem（跨边界共享内存管理器，77a §2.3）；
  - 与宿主编译同一份 DeepBase.Plugins.Contracts 源码（ABI 一致）；
  - 导出工厂按 Manager Kind 前缀约定：Create + <插件名> + Plugin。
  ============================================================================ }
library TestPlugin77;

uses
  ShareMem,
  System.SysUtils,
  DeepBase.Plugins.Contracts in '..\..\..\Core\DeepBase.Plugins.Contracts.pas',
  TestPlugin77.Impl in 'TestPlugin77.Impl.pas';

exports
  CreateEchoPlugin name 'CreateEchoPlugin',
  CreateBasePlugin name 'CreateBasePlugin',
  CreateAbiBadPlugin name 'CreateAbiBadPlugin';

begin
end.
