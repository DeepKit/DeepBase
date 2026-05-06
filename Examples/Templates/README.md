# UniBase 模板工程说明

本目录下的 VCL 模板项目（`CRUDApp` / `DataAnalyzer` / `DocManager`）已默认接入
`Template.AutoUpdateBootstrap`，并启用 UniBase 策略化静默更新编排。

## 默认行为

- 自动更新入口：`Examples/Templates/Common/Template.AutoUpdateBootstrap.pas`
- 默认策略：
  - `EnablePolicyDrivenSilentUpdate = True`
  - `SilentInstallPollIntervalMs = 30000`
  - `AutoTriggerExitInstall = True`
- 若 `installPolicy.mode = onExit/whenIdle`，会先 staged 下载，再在安全窗口安装。

## 配置约定（Settings 表）

- `App.UpdateUrl`：更新清单 URL（如 `https://.../version.json`）
- `App.Version`：当前应用版本（如 `1.2.3`）

未配置 `App.UpdateUrl` 时，自动更新逻辑会安全跳过，不影响应用启动。
