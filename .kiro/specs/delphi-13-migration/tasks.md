# DeepBase — Delphi 13.1 迁移任务包

> 优先级：最高（所有 Deep* 项目的基石,必须第一个完成）
> 源版本：Delphi 12.3 Athens (BDS 23.0)
> 目标版本：Delphi 13.1 Florence (BDS 37.0)
> 总纲参考：`02Business/docs/delphi-13-migration/README.md`
> 包结构：Core / Persistence / Features / Services / VCL / FMX + 3 个设计时包

## 当前执行状态

- 当前迁移分支：`upgrade/delphi-13`
- 迁移前 tag：`pre-d13-deepbase`
- 当前工作区在迁移开始前已有大量未提交改动；本迁移提交只暂存本轮产生的文件，避免混入既有改动。
- 12.3 包编译基线：`Scripts/build_packages_win64.ps1 -Profile All` 通过；Warning 基线 `136`，Error `0`。
- 12.3 测试基线：`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` 通过；Unit `3240/3243 passed, 3 ignored`，Integration `10/10 passed`。
- 13.1 运行时包编译：`Scripts/build_packages_win64.ps1 -Profile All` 通过；Warning `136`，Error `0`，未超过 12.3 基线。
- 13.1 测试：`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` 通过；Unit `3240/3243 passed, 3 ignored`，Integration `10/10 passed`。
- 13.1 架构检查：`Scripts/run_architecture_checks.ps1` 通过；`18/18 passed`。
- 13.1 设计时包命令行 Build：`dclDeepBaseCore.dpk`、`dclDeepBaseVCL.dpk`、`dclDeepBaseFMX.dpk` 通过；IDE Install 和组件面板确认仍需人工执行。
- UniBase VCL 旧单元清理：已删除 34 个 `VCL/UniBase.VCL.*` 残留文件；源码/包/工程中未发现 `UniBase.VCL` / `UniBase.` 引用；删除后 13.1 运行时包编译通过。
- Steering 四件套：`.kiro/steering/delphi-13-global.md`、`delphi-13-syntax.md`、`skia-7.1-conventions.md`、`sse-streaming-pattern.md` 已创建。
- `.dproj` / `.dpk` / `.groupproj` 已生成 `.12.bak` 本地备份；这些文件受 `.gitignore` 的 `*.bak` 规则忽略，不纳入常规提交。
- 需要 IDE/人工参与的步骤：`.dproj` 格式自动升级、DFM/FMX 96 DPI 保存、设计时包 Install、IDE 组件面板确认。

---

## 阶段 0：准备与基线

- [x] 0.1 在 DeepBase 仓库打 git tag `pre-d13-deepbase`
- [x] 0.2 确认当前 12.3 下所有 6 个 dpk 可 Clean + Build 通过（记录 Warning 数量作为基线）
  - 2026-05-09：`Scripts/build_packages_win64.ps1 -Profile All` 通过；Warning `136`，Error `0`。
- [x] 0.3 运行现有测试套件,记录通过率作为基线
  - 2026-05-09：`Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` 通过；Unit `3240/3243 passed, 3 ignored`；Integration `10/10 passed`；总通过率 `100%`（忽略项不计失败）。
- [x] 0.4 备份所有 `.dproj` / `.dpk` / `.groupproj` 为 `.12.bak` 后缀
  - 2026-05-09：已备份 18 个项目/包文件；`.12.bak` 为本地回退备份，默认被 `.gitignore` 忽略。
- [x] 0.5 创建分支 `upgrade/delphi-13`

## 阶段 1：环境切换

- [x] 1.1 创建 `02Business/scripts/env/delphi-13.1.bat`（内容见总纲 §2）
  - 2026-05-09：已确认 `D:\_Progs\02Business\scripts\env\delphi-13.1.bat` 存在，默认 BDS 37.0。
- [x] 1.2 更新 `DeepBase/do_rebuild.bat`、`build_test.bat`、`compile_test.bat` 首行调用新环境脚本
  - 2026-05-09：已更新 `do_rebuild.bat`、`build_test.bat`、`compile_test.bat`，并同步更新同类 `rebuild_test.bat`。
  - 2026-05-09：已更新 `Scripts/build_packages_win64.ps1`、`Scripts/build_examples_win64.ps1`、`Scripts/run_architecture_checks.ps1`、`Scripts/run_tests.ps1` 默认使用 BDS 37.0，并允许通过 `BDS` 环境变量覆盖。
- [ ] 1.3 用 Delphi 13.1 IDE 打开 `DeepBaseCore.dpk`,让 IDE 自动升级 `.dproj` 格式
- [ ] 1.4 逐个打开其余 5 个 dpk + 3 个 dcl dpk,完成 dproj 格式升级
- [ ] 1.5 检查所有 `.dproj` 中 `<DCC_BPLOutput>` / `<DCC_DCPOutput>` / `<DCC_DCUOutput>` 路径是否正确
- [x] 1.6 确认 Search Path 中无硬编码 `23.0` 或 `BDS\23.0` 残留
  - 2026-05-09：已扫描 `.bat` / `.ps1` / `.cmd` / `.dproj` / `.dpk` / `.groupproj`，未发现 `Studio\23.0` / `BDS\23.0` 硬编码残留。历史文档中的 23.0 示例未作为构建配置处理。

## 阶段 2：第三方组件安装与验证

- [ ] 2.1 安装 Skia4Delphi 7.1.0 到 13.1 IDE
  - [ ] 2.1.1 确认 Skia 7.1.0 的 unit 路径变化,记录新旧映射
  - [ ] 2.1.2 更新 DeepBase 所有 dpk 的 Search Path 中 Skia 相关路径
- [x] 2.2 确认 FireDAC 随 13.1 自带,无需额外操作
  - 2026-05-09：13.1 下 Persistence、VCL/FMX 和测试套件均通过，FireDAC 单元可用。
- [ ] 2.3 检查 `ThirdParty/` 下各子目录组件是否有 13.1 兼容版本
  - [ ] 2.3.1 `ThirdParty/UI/` — 确认 UI 组件兼容性
  - [ ] 2.3.2 `ThirdParty/DB/` — 确认数据库组件兼容性
  - [ ] 2.3.3 `ThirdParty/Cloud/` — 确认云服务组件兼容性
  - [ ] 2.3.4 `ThirdParty/Payment/` — 确认支付组件兼容性
  - [ ] 2.3.5 `ThirdParty/Social/` — 确认社交组件兼容性
- [ ] 2.4 更新 `COMPATIBILITY.md` 中 DeepBase 相关行的状态

## 阶段 3：逐包编译（按依赖顺序）

### 3.1 DeepBaseCore.dpk
- [x] 3.1.1 Clean + Build `DeepBaseCore.dpk`
- [x] 3.1.2 修复所有编译错误（记录到 `docs/d13-migration-notes.md`）
  - 2026-05-09：13.1 编译通过，无 Core 编译错误。
- [x] 3.1.3 处理新增 Warning（清零或登记白名单）
  - 2026-05-09：运行时包总 Warning `136`，未超过 12.3 基线。
- [x] 3.1.4 确认 BPL 输出正确

### 3.2 DeepBasePersistence.dpk
- [x] 3.2.1 Clean + Build `DeepBasePersistence.dpk`
- [x] 3.2.2 修复编译错误（FireDAC 接口变化重点关注）
  - 2026-05-09：13.1 编译通过，无 FireDAC 接口编译错误。
- [x] 3.2.3 处理 Warning
  - 2026-05-09：运行时包总 Warning `136`，未超过 12.3 基线。

### 3.3 DeepBaseFeatures.dpk
- [x] 3.3.1 Clean + Build `DeepBaseFeatures.dpk`
- [x] 3.3.2 修复编译错误
  - 2026-05-09：13.1 编译通过，无 Features 编译错误。
- [ ] 3.3.3 重点关注 `DeepBase.LLM.*.pas` 中 `System.Net.HttpClient` 的 SSE 新 API 兼容性
  - 2026-05-09：13.1 兼容编译已通过；是否替换为 13.1 SSE API 留到阶段 6 评估。
- [x] 3.3.4 重点关注 `DeepBase.Net.Transport.*.pas` 网络层变化
  - 2026-05-09：13.1 编译和测试通过，当前网络层无阻断性 API 变化。

### 3.4 DeepBaseServices.dpk
- [x] 3.4.1 Clean + Build `DeepBaseServices.dpk`
- [x] 3.4.2 修复编译错误
  - 2026-05-09：13.1 编译通过，无 Services 编译错误。

### 3.5 DeepBaseVCL.dpk
- [x] 3.5.1 Clean + Build `DeepBaseVCL.dpk`
- [x] 3.5.2 修复编译错误
  - 2026-05-09：13.1 编译通过；为避免设计时包重复单元，已显式声明 `vclimg`、`vclFireDAC`、`VclSmp` 运行时依赖。
- [ ] 3.5.3 确认 VCL Styles / Win11 新样式兼容

### 3.6 DeepBaseFMX.dpk
- [x] 3.6.1 Clean + Build `DeepBaseFMX.dpk`
- [x] 3.6.2 修复 Skia 7.1.0 unit 路径变化导致的 uses 错误
  - 2026-05-09：13.1 编译通过，当前 FMX 包未暴露 Skia unit 路径错误。
- [ ] 3.6.3 确认 FMX 控件在 13.1 下正常渲染

### 3.7 设计时包
- [ ] 3.7.1 Build + Install `dclDeepBaseCore.dpk`
  - 2026-05-09：命令行 Build 已通过；IDE Install 待人工执行。
- [ ] 3.7.2 Build + Install `dclDeepBaseVCL.dpk`
  - 2026-05-09：命令行 Build 已通过；IDE Install 待人工执行。
- [ ] 3.7.3 Build + Install `dclDeepBaseFMX.dpk`
  - 2026-05-09：命令行 Build 已通过；IDE Install 待人工执行。
- [ ] 3.7.4 确认 IDE 组件面板中 DeepBase 控件全部可见

## 阶段 4：UniBase 残留清理

> 发现 `DeepBase/VCL/` 下仍有 33 个 `UniBase.VCL.*` 旧文件与新版并存

- [x] 4.1 确认所有 `UniBase.VCL.*.pas` 已有对应的 `DeepBase.VCL.*.pas` 替代
  - 2026-05-09：已确认 34 个 `UniBase.VCL.*` 残留文件均有 `DeepBase.VCL.*` 替代文件。
- [x] 4.2 全局搜索确认无任何 dpk / dproj / 下游项目仍引用 `UniBase.VCL.*`
  - 2026-05-09：`rg` 扫描 `.pas` / `.dpk` / `.dproj` / `.groupproj` 未发现 `UniBase.VCL` 引用。
- [x] 4.3 删除 `DeepBase/VCL/UniBase.VCL.*.pas` 和对应 `.dfm` 文件（约 33 个）
  - 2026-05-09：已删除 34 个 `VCL/UniBase.VCL.*` 旧文件，其中包含 `.pas` 与 `.dfm`。
- [x] 4.4 全局搜索 `DeepBase/Core/`、`DeepBase/Persistence/`、`DeepBase/Features/` 确认无 `UniBase.` 残留
  - 2026-05-09：`Core/`、`Persistence/`、`Features/`、`VCL/`、`FMX/` 扫描未发现 `UniBase.` 残留。
- [x] 4.5 重新 Build 所有 6 个 dpk 确认删除后无断链
  - 2026-05-09：删除后 `Scripts/build_packages_win64.ps1 -Profile All` 通过。

## 阶段 5：DFM 96 DPI 转换

- [ ] 5.1 在 13.1 IDE 中启用 DFM 96 DPI 保存模式（Project Options → Forms → Save DFM at 96 DPI）
- [ ] 5.2 逐个打开 FMX 子包中的 `.fmx` 文件,保存以触发 96 DPI 转换
  - `DeepBase.FMX.AboutFrame.fmx`
  - `DeepBase.FMX.UpdateDialog.fmx`
- [ ] 5.3 逐个打开 VCL 子包中的 `.dfm` 文件,保存以触发 96 DPI 转换
  - `DeepBase.VCL.AboutFrame.dfm`
  - `DeepBase.VCL.DBInitWizard.dfm`
  - `DeepBase.VCL.LLMConfigPanel.dfm`
  - `DeepBase.VCL.LLMSettingsFrame.dfm`
  - `DeepBase.VCL.UpdateDialog.dfm`
  - `DeepBase.VCL.WaitForm.dfm`
- [ ] 5.4 验证转换后的 DFM 在不同 DPI 下渲染正确

## 阶段 6：语法现代化（样板重构）

> 不要求一次全改 676 个文件,但每个子包至少选 1 个高频文件做样板

- [ ] 6.1 Core 样板：选 `DeepBase.Config.pas` 或 `DeepBase.Collections.pas`
  - [ ] 6.1.1 将 `if...then...else` 条件赋值改为三元表达式
  - [ ] 6.1.2 将局部变量改为 inline var（适用处）
  - [ ] 6.1.3 确认编译通过,测试不退化
- [ ] 6.2 Persistence 样板：选 `DeepBase.DB.Pool.pas`
  - [ ] 6.2.1 同上三元 + inline var 重构
- [ ] 6.3 Features 样板：选 `DeepBase.LLM.Service.pas`
  - [ ] 6.3.1 评估是否可用 13.1 SSE API 替换手写解析（仅评估,不强制改）
  - [ ] 6.3.2 三元 + inline var 重构
- [ ] 6.4 VCL 样板：选 `DeepBase.VCL.Controls.pas`
  - [ ] 6.4.1 三元 + inline var 重构
- [ ] 6.5 FMX 样板：选 `DeepBase.FMX.Controls.pas`
  - [ ] 6.5.1 三元 + inline var 重构
  - [ ] 6.5.2 Skia 7.1.0 新 API 替换（如有适用处）

## 阶段 7：Steering 文件部署

- [x] 7.1 创建 `DeepBase/.kiro/steering/delphi-13-global.md`（默认加载）
  - 内容：BDS 37.0 路径、编译器版本、禁用 API 清单
  - 2026-05-09：已创建，包含 BDS 37.0、CompilerVersion 37.0、包规则、禁用旧路径和人工步骤边界。
- [x] 7.2 创建 `DeepBase/.kiro/steering/delphi-13-syntax.md`（默认加载）
  - 内容：语法映射表 + before/after 代码示例
  - 2026-05-09：已创建，包含三元表达式、inline var、CompilerVersion 分支和迁移限制示例。
- [x] 7.3 创建 `DeepBase/.kiro/steering/skia-7.1-conventions.md`（fileMatch: `**/*Skia*.pas,**/FMX/*.pas`）
  - 内容：Skia 7.1.0 新 unit 名、推荐 API、弃用 API
  - 2026-05-09：已创建，包含 Skia 7.1.0 目标、路径约束、UI 层边界和验证要求。
- [x] 7.4 创建 `DeepBase/.kiro/steering/sse-streaming-pattern.md`（fileMatch: `**/LLM*.pas,**/Stream*.pas`）
  - 内容：13.1 SSE API 用法示例、替代旧手写解析的模式
  - 2026-05-09：已创建，包含 SSE 请求头、解析兼容点、取消、测试和迁移记录要求。

## 阶段 8：测试验证

- [x] 8.1 运行 `DeepBase/Tests/` 下所有现有测试,确认全绿
  - 2026-05-09：13.1 下 `Scripts/run_tests.ps1 -Type All -Platform Win64 -CI` 通过；Unit `3240/3243 passed, 3 ignored`；Integration `10/10 passed`。
- [ ] 8.2 运行 `TestLLMProxyClient.dpr` 确认 LLM 模块在 13.1 编译后功能正常
- [ ] 8.3 用 `mock_proxy_server.py` 跑 6 项集成测试场景
- [ ] 8.4 如有失败,修复并记录原因到 `docs/d13-migration-notes.md`

## 阶段 9：下游兼容验证

> DeepBase 完成后,必须验证下游能引用新 BPL

- [ ] 9.1 选 DeepLLM 作为验证项目,仅做 Build（不做完整迁移）
- [ ] 9.2 选一个 FMX 项目（如 DeepDev 或 DeepInsight）做 Build 验证
- [ ] 9.3 选一个 VCL 项目（如 DeepStory 或 DeepConfig）做 Build 验证
- [ ] 9.4 如有断链,回到阶段 3 修复 DeepBase 的导出接口

## 阶段 10：收尾

- [ ] 10.1 确认 Warning 数量 ≤ 阶段 0 基线（或新增全部登记白名单）
- [ ] 10.2 更新 `DeepBase/CHANGELOG.md` 记录 13.1 迁移
- [ ] 10.3 创建 `DeepBase/docs/d13-migration-notes.md` 汇总所有迁移要点
- [ ] 10.4 合并 `upgrade/delphi-13` 分支到主分支
- [ ] 10.5 打 tag `d13-deepbase-done`
- [ ] 10.6 通知 4 组 AI 可以启动各自项目的迁移

---

## 完成标准 (DoD)

- [ ] 6 个运行时 dpk + 3 个设计时 dpk 全部 Clean + Build 成功
- [ ] 所有编译脚本已切到 `delphi-13.1.bat`
- [ ] Skia4Delphi 7.1.0 已安装并集成
- [x] `UniBase.VCL.*` 残留文件已清除
- [ ] DFM 96 DPI 转换完成
- [ ] Warning ≤ 基线
- [ ] 测试全绿
- [ ] 至少 5 个样板文件已用 13.1 新语法
- [x] Steering 四件套到位
- [ ] 至少 3 个下游项目可引用新 BPL 编译通过
- [ ] CHANGELOG + migration-notes 已更新
