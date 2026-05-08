# 07 - Developer Test Center & Runners (DeepBase 开发者测试中�?

> 版本: 0.1  
> 生成日期: 2025-12-11  
> 适用范围: **所有使�?DeepBase 架构的应用程序（VCL / FMX�?*

---

## 1. 目标与原�?

所有基�?DeepBase 的应用程序，都应�?*开发�?*提供一致的测试入口，用于在本地或现场环境中快速验证功能、复现问题、回归测试�?

要求提供两类入口�?

1. **控制台测�?Runner（必选）**
   - 负责运行单元测试和集成测试，适合 CI/CD 和命令行调用�?
   - 基于 DUnitX 或等价测试框架�?
2. **GUI 测试中心（推荐，Debug/内部版本必备�?*
   - 集成在应用界面中，开发者无需打开命令行或额外脚本即可运行测试�?
   - 可以复用 DeepBase �?GUI 自动化测试基础设施�?

> 注意：本规范面向“开发者”和“内部调试环境”。正式发布给终端用户�?Release 版本可以隐藏或禁用测试中心入口�?

---

## 2. 控制台测�?Runner 约定

### 2.1 工程命名

每个 DeepBase 应用应至少提供两�?DUnitX 控制台测试工程：

- `AppNameTests.dpr`  
  - 负责 **单元测试**（Unit Tests）�?
- `AppNameIntegrationTests.dpr`  
  - 负责 **集成测试**（Integration Tests），例如�?
    - HTTP/WebAPI 测试
    - 数据库读�?/ 迁移测试
    - 后台服务/调度/工作流集成测�?

**DeepBase 自身示例�?*

- 单元测试 Runner：`Tests\DeepBaseTests.dpr`
- 集成测试 Runner：`Tests\Integration\DeepBaseIntegrationTests.dpr`
- 辅助脚本：`Scripts\run_tests.ps1`（方便在本地�?CI 中一键编�?运行测试，但不作为唯一入口�?

### 2.2 命令行行�?

控制�?Runner 应遵守以下约定：

- **无参�?*时：
  - 运行全部已注册测试用例�?
  - 退出码�?
    - `0` �?所有测试通过�?
    - �?`0` �?存在失败/错误（CI 可以直接据此判定 Fail）�?
- **XML 报告输出**�?
  - 支持 `--xmlfile:SomePath.xml` �?`--xml:SomePath.xml` 参数，将结果�?NUnit XML 格式输出�?
  - 方便�?Jenkins / GitLab CI / GitHub Actions �?CI 工具集成�?
- **ExitBehavior**�?
  - DUnitX 中建议使�?`--exitbehavior:Continue`，防止测试失败时阻塞等待输入（便于自动化）�?

### 2.3 最佳实�?

- 测试 Runner �?`uses` 区尽量只依赖被测模块和测试单元，不要引入 UI 层和外部依赖�?
- 单元测试和集成测试分离：
  - 单元测试不访问真实外部资源（数据�?网络），速度要足够快�?
  - 集成测试可以访问真实资源，但要注意环境前置条件检查和清理逻辑�?

---

## 3. GUI 测试中心（面向开发者）

### 3.1 功能需�?

每个 DeepBase 桌面应用�?Debug/内部版本中，应提供一个“测试中心”界面，至少满足�?

- **测试发现与分�?*�?
  - 按类别展示测试：Unit / Integration / GUI / Stress / Other�?
  - 可使�?`TTreeView`、`TListView` �?Tab 控件分组�?
- **测试运行控制**�?
  - 支持 “运行全部”、“运行选中”、“按类别运行�?等操作�?
  - 显示当前运行进度（进度条/计数/状态文本）�?
- **结果展示**�?
  - 汇总：总测试数 / 通过 / 失败 / 错误 / 跳过�?
  - 详情：失败用例的名称、错误信息、堆�?上下文链接�?
  - 提供跳转或链接到详细 HTML 报告�?
- **运行环境**�?
  - 支持在应用内部直接运行（例如通过嵌入�?Runner 或调用外部测�?EXE）�?
  - 不强制要求安�?PowerShell/脚本环境�?

### 3.2 技术选型

推荐直接复用 DeepBase 已有测试基础设施�?

- **GUI 自动化与截图对比**�?
  - `Core\DeepBase.TestHelper.pas`  
    - 提供控件查找、模拟点�?输入、截图保存等基础能力�?
  - `Tests\GUI\DeepBase.GUITest.pas`（单元：`DeepBase.GUITest`�?
    - 提供 `TGUITestBase`、`TGUITestRunner` 等基类：
      - 步骤记录（Step/Verify）�?
      - 截图捕获、基准图对比�?
      - HTML/JSON 报告生成�?
- **参考工�?*�?
  - `Tests\GUI\DeepBaseGUITests.dpr`
    - 控制台入口的 GUI 自动化测�?Runner�?
    - 可以作为“测试中心”界面的实现参考（将其中的测试运行逻辑封装到应用内的窗体中）�?

### 3.3 典型界面结构示例

> 以下为参考设计，可根据项目实�?UI 规范调整�?

- 左侧：`TTreeView` 测试分类�?
  - `Unit Tests`
  - `Integration Tests`
  - `GUI Tests`
  - `Stress Tests`
- 中间：测试列�?
  - 列：名称 / 分类 / 最近结�?/ 耗时 / 标签
  - 多选支持（Shift/Ctrl�?
- 右侧：测试详�?
  - 单个用例的输出信�?/ 错误消息 / 堆栈摘要
  - 链接�?HTML 报告（在浏览器或内嵌 WebView 打开�?
- 底部：控制区
  - 按钮：运行全�?/ 运行选中 / 停止 / 打开报告目录
  - 进度�?+ 当前状态文�?

### 3.4 与正式版本的关系

- Debug/内部构建�?
  - 始终启用测试中心入口（用于开发、测试、现场诊断）�?
- Release/生产构建�?
  - 可以隐藏测试中心菜单项，或添加访问保护（例如：命令行开关、隐藏快捷键、仅在特定配置下可见）�?

---

## 4. DeepBase 参考实�?

### 4.1 核心测试工程

- **单元测试 Runner**：`Tests\DeepBaseTests.dpr`
  - 使用 DUnitX，涵盖核心模块（Config/i18n/Logging/DB/LLM/Crypto 等）�?
- **集成测试 Runner**：`Tests\Integration\DeepBaseIntegrationTests.dpr`
  - 使用自定义集成测试框�?`DeepBase.IntegrationTest.pas`�?
  - 当前包括�?
    - Core 集成测试：配置、日志、数据库、工作流等（部分依赖 FireDAC/SQLite 环境）�?
    - WebAPI 集成测试：`Test.Integration.WebAPI.pas` 覆盖 HTTP 路由、查询参数、CORS、JWT 认证、OpenAPI 生成�?WebSocket 消息路由�?

### 4.2 GUI 自动化测试工�?

- **GUI 测试 Runner**：`Tests\GUI\DeepBaseGUITests.dpr`
  - 使用 `DeepBase.GUITest` + `DeepBase.TestHelper`�?
    - 提供 GUI 自动化测试基�?`TGUITestBase`�?
    - 支持截图比对�?HTML/JSON 报告生成�?
  - 测试单元�?
    - `Test.GUI.Core.pas`（核心控�?窗口流程）�?
    - `Test.GUI.VCL.pas`（配置控件、i18n 控件、主题切换等 GUI 行为）�?

> 注意：`DeepBaseGUITests.exe` 当前以控制台应用形式运行测试，但内部测试逻辑完全可以嵌入到任�?VCL/FMX 窗体中，作为“测试中心”的执行后端�?

### 4.3 DeepBaseRun 示例中的自检

- `DeepBaseRun` 项目中：
  - `ViewMain.pas` �?"Tools" 页签包含 `ButtonSelfCheck`�?
    - 调用 `TDeepBaseManager.HealthCheck` 检查配置数据库、资源目录等�?
    - 调用 `CtrlMain.PerformSelfCheck` 检�?`root` 路径、日志目录、`config.db` 等�?
  - 这是一�?*运行时健康检�?/ 自诊断界�?*的示例�?
- 后续建议�?
  - �?`DeepBaseRun` 中新增“测试中心”页签：
    - 复用上述 HealthCheck 自检结果�?
    - 挂接一部分单元/集成/GUI 测试（例如关键工作流的烟雾测试）�?

---

## 5. 集成步骤建议（针对新应用�?

1. **创建测试工程**�?
   - 新建 `AppNameTests.dpr` + `AppNameIntegrationTests.dpr`，参�?`Tests\DeepBaseTests.dpr` / `Tests\Integration\DeepBaseIntegrationTests.dpr`�?
   - 为关键模块先补齐 DUnitX 单元测试�?
2. **引入 GUI 测试基础设施**�?
   - �?`DeepBase.TestHelper.pas` �?`DeepBase.GUITest.pas` 加入项目（或公共包）�?
   - 可选：添加独立�?GUI 测试工程（类�?`DeepBaseGUITests.dpr`）�?
3. **在主应用中添加“测试中心”窗�?页签**�?
   - VCL：可以用 `TForm` + `TTreeView`/`TListView` + `TMemo`/`TPageControl` 组成基本布局�?
   - FMX：可�?`TLayout` + `TTreeView`/`TListView` + `TMemo`/`TTabControl` 实现类似结构�?
4. **实现测试列表与运行逻辑**�?
   - 硬编码或通过反射维护一份测试用例清单�?
   - 调用内部 Runner 或外部测�?EXE，并解析返回结果/退出码，更新界面�?
5. **�?Debug 构建启用入口**�?
   - e.g. `{$IFDEF DEBUG}` 下注册菜单项 "测试中心..."�?
   - �?Release 构建中隐藏或通过配置开关控制�?

---

## 6. 后续扩展

- �?CI/CD 中统一�?
  - 使用控制�?Runner 提供 XML 报告，配�?GitHub Actions / GitLab CI / Jenkins 等平台汇总测试结果�?
- 在应用内扩展�?
  - 为测试中心增�?**覆盖率视�?*（从覆盖率工具导入统计结果）�?
  - 增加 **一键导出诊断包**（测试结�?+ 日志 + 环境信息）�?
- 在文档层面：
  - 所有基�?DeepBase 的项目文档应在“开发说明”章节中说明�?
    - 控制台测�?Runner 的位置与用法�?
    - GUI 测试中心的入口位置与主要功能�?

---

## 7. �?UniPublisher 的协同（测试中心 + 发布工具�?

### 7.1 职责划分

- **Developer Test Center（本文件�?*�?
  - 面向开发�?内部使用，负�?**运行测试、查看结果、导出报�?*�?
  - 每个应用各自实现，集成在主程�?UI 中（Debug/内部版本必备）�?
- **UniPublisher（独�?GUI 发布工具�?*�?
  - 面向开发�?发布负责人，负责 **打包、生�?version.json、上传发�?*�?
  - 所有应用共用一套工具：`Tools/UniPublisher/UniPublisher.exe`�?

> 约定�?*每个使用 DeepBase 的桌面应用，都必须在开发者测试中心中提供一个统一的「打开 UniPublisher」入�?*，不再各自实现一套打�?GUI�?

### 7.2 测试中心中的「打开 UniPublisher」按�?

在测试中心窗�?页签底部，推荐增加一个简单按钮：

- 按钮文本：`打开 UniPublisher...`
- 目标用户�?*开发�?内部测试人员**（Release 版本可隐藏）�?
- 行为�?
  - 通过 `ShellExecute` 或等�?API 启动 `UniPublisher.exe`�?
  - **不传递任何命令行参数**，由 UniPublisher 自己记住最近使用的项目（MRU）�?

伪代码示例：

```delphi path=null start=null
procedure TTestCenterForm.btnOpenUniPublisherClick(Sender: TObject);
begin
  // 1) 解析 UniPublisher 路径�?
  //    - 优先�?Settings 中读取配置项，例如：Update.UniPublisherPath
  //    - 若未配置，可尝试相对路径�?..\Tools\UniPublisher\UniPublisher.exe
  // 2) 若文件不存在，则给出友好错误提示�?

  if not FileExists(FUniPublisherPath) then
  begin
    ShowMessage('未找�?UniPublisher.exe，请检�?Tools 目录或配置项 Update.UniPublisherPath');
    Exit;
  end;

  ShellExecute(0, 'open', PChar(FUniPublisherPath), nil, nil, SW_SHOWNORMAL);
end;
```

> 注意：按钮本�?*不负�?*选择 `.publish.json` 或填写版本号，只是把开发者带到统一�?UniPublisher 界面中；项目选择和版本信息在 UniPublisher 内通过 MRU �?UI 完成�?

### 7.3 推荐工作�?

1. 开发者在当前应用中打开“测试中心”页签�?
2. 运行关键�?Unit / Integration / GUI Tests，确保全部通过�?
3. 若需要发布新版本：点击“打开 UniPublisher...”�?
4. UniPublisher 启动后：
   - 自动加载最近一次使用的 `{AppName}.publish.json`�?
   - 开发者确�?调整：新版本号、Channel(Stable/Beta/Dev)、Release Notes�?
   - 选择需要的发布目标（HTTP / GitHub / Gitee）�?
5. �?UniPublisher 中一键执行“打�?+ 生成 version.json + 上传发布”�?
6. 发布完成后，可以在测试中心中附加一次“安装后回归测试”（可选）�?

### 7.4 与发布工具规范的关系

- 本文件只规定**测试中心一�?*的要求：
  - 必须有统一的“打开 UniPublisher”入口�?  - 入口行为是“启动工具�?而不是直接执行打包逻辑�?- 关于 `.publish.json`、`version.json` 和发布目标配置，归发布工具项目自身维护；DeepBase 文档只保留测试中心集成入口约定�?