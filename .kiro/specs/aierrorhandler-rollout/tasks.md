# 实施计划：AIErrorHandler Rollout

**适用 design**: `.kiro/specs/aierrorhandler-rollout/design.md` v1.0
**适用 requirements**: `.kiro/specs/aierrorhandler-rollout/requirements.md`
**编译门禁**: `cmd /c compile_test.bat` ⇒ Exit code 0

> 反向补 spec：本特性已有 WIP 代码（`stash@{0}`），本 tasks 文档梳理实际落地步骤。

## Tasks

- [x] 1. AIErrorHandler.pas 主单元改造
  - [x] 1.1 新增 `SilentMode: Boolean` 字段到 `TAIErrorConfig`
    - 修改 `Core/DeepBase.AIErrorHandler.pas`
    - `TAIErrorConfig.Default` 设置 `Result.SilentMode := False`
    - _Requirements: 1.1, 1.4_
  - [x] 1.2 新增 `FOldAppException: TExceptionEvent` class var
    - `Install(AConfig)` 在覆盖 `Application.OnException` 前保存原值
    - _Requirements: 2.1, 2.3_
  - [x] 1.3 elFatal 分支添加 SilentMode 路径
    - `if FConfig.SilentMode then ExitCode := 1; Halt(1) else MessageDlg + Application.Terminate`
    - _Requirements: 1.3_
  - [x] 1.4 elAIAnalyze 分支 SilentMode 下抑制 MessageDlg
    - 把 `MessageDlg(...)` 包在 `if not FConfig.SilentMode then`
    - _Requirements: 1.2_
  - [x] 1.5 Logger 现代化
    - 全部 `DeepBase.Logging.Log(ltWarning, msg, ...)` 替换为 `Logger.Warn(msg, 'AIErrorHandler')`
    - 同样 ltError → `Logger.Error/Fatal`
    - _Requirements: 3.1, 3.2, 3.3, 3.4_
  - [x] 1.6 编译门禁
    - `cmd /c compile_test.bat` ⇒ Exit code 0
    - _Requirements: 全部_

- [x] 2. Bootstrap façade 单元
  - [x] 2.1 创建 `Core/DeepBase.AIErrorHandler.Bootstrap.pas`
    - `TAIErrorBootstrapMode = (bmAuto, bmProduction, bmTest)`
    - `InstallAIErrorHandler` 两个重载 + `InstallAIErrorHandlerForTests`
    - `IsTestMode` 检测 env `DEEP_AIEH_MODE` 与 `{$IFDEF DEEPBASE_AIEH_TEST}`
    - 单元级 `GInstalled: Boolean` guard 保证幂等
    - 内部所有失败用 `OutputDebugString` 报告，绝不外抛
    - _Requirements: 4.1, 4.2, 4.4, 4.5, 4.6, 4.7_
  - [x] 2.2 InstallLLMBridge wiring
    - Bootstrap 内部 `try InstallLLMBridge except DebugOut end`
    - _Requirements: 4.7_
  - [x] 2.3 SilentMode 解析
    - `ResolveSilent(bmTest) = True`，`bmProduction = False`，`bmAuto = IsTestMode()`
    - bmAuto / bmTest 模式下 force `LConfig.SilentMode := True`
    - _Requirements: 4.3, 4.4_

- [x] 3. LLMBridge adapter 单元
  - [x] 3.1 创建 `Core/DeepBase.AIErrorHandler.LLMBridge.pas`
    - `procedure InstallLLMBridge`
    - 内部 `CallLLM(prompt)` 调 `LLM.Chat(TierFast, prompt)`
    - try/except 全部吞，never raise
    - LResult.Success=False 时返回空字符串
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 4. 整体编译验证
  - [x] 4.1 `cmd /c compile_test.bat` ⇒ Exit code 0
    - _Requirements: 全部_

- [x] 5. Examples Demo
  - [x] 5.1 创建 `Examples/AIErrorHandlerDemo/` 项目
    - 4 个文件：dpr / Demo.MainForm.pas / dproj / build.bat / README.md
    - VCL 程序化 form，4 按钮触发 4 个分级路径（elIgnore / elAutoFix / elAIAnalyze / elFatal）
    - 状态条显示当前 mode + DEEP_AIEH_MODE 环境变量
    - README 描述 production / test 两种运行模式 + 切换方式
    - `Examples\AIErrorHandlerDemo\build.bat` ⇒ Exit code 0，输出 ~5.7MB AIErrorHandlerDemo.exe
    - _Requirements: 4.1, 4.4_

- [ ]* 6. 编写属性测试（可选 PBT）
  - [ ]* 6.1 Property 1：Bootstrap.Install 幂等
    - **Property 1: Bootstrap Install 幂等**
    - **Validates: Requirements 4.6**
    - 100 次随机 mode 序列 → 仅首次返回 True
  - [ ]* 5.2 Property 2-3：bmTest / bmAuto SilentMode 解析
    - **Property 2: bmTest 强制 SilentMode**
    - **Property 3: bmAuto 正确读取 env**
    - **Validates: Requirements 4.3, 4.4**
  - [ ]* 5.3 Property 7-9：LLMBridge 容错
    - **Property 7: callback never raises**
    - **Property 8: LLM 异常返回空字符串**
    - **Property 9: LLM Success=False 返回空字符串**
    - **Validates: Requirements 5.3, 5.4, 5.5**
