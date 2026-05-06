# 07 - Developer Test Center & Runners (UniBase 开发者测试中心)

> 版本: 0.1  
> 生成日期: 2025-12-11  
> 适用范围: **所有使用 UniBase 架构的应用程序（VCL / FMX）**

---

## 1. 目标与原则

所有基于 UniBase 的应用程序，都应为**开发者**提供一致的测试入口，用于在本地或现场环境中快速验证功能、复现问题、回归测试。

要求提供两类入口：

1. **控制台测试 Runner（必选）**
   - 负责运行单元测试和集成测试，适合 CI/CD 和命令行调用。
   - 基于 DUnitX 或等价测试框架。
2. **GUI 测试中心（推荐，Debug/内部版本必备）**
   - 集成在应用界面中，开发者无需打开命令行或额外脚本即可运行测试。
   - 可以复用 UniBase 的 GUI 自动化测试基础设施。

> 注意：本规范面向“开发者”和“内部调试环境”。正式发布给终端用户的 Release 版本可以隐藏或禁用测试中心入口。

---

## 2. 控制台测试 Runner 约定

### 2.1 工程命名

每个 UniBase 应用应至少提供两个 DUnitX 控制台测试工程：

- `AppNameTests.dpr`  
  - 负责 **单元测试**（Unit Tests）。
- `AppNameIntegrationTests.dpr`  
  - 负责 **集成测试**（Integration Tests），例如：
    - HTTP/WebAPI 测试
    - 数据库读写 / 迁移测试
    - 后台服务/调度/工作流集成测试

**UniBase 自身示例：**

- 单元测试 Runner：`Tests\UniBaseTests.dpr`
- 集成测试 Runner：`Tests\Integration\UniBaseIntegrationTests.dpr`
- 辅助脚本：`Scripts\run_tests.ps1`（方便在本地或 CI 中一键编译+运行测试，但不作为唯一入口）

### 2.2 命令行行为

控制台 Runner 应遵守以下约定：

- **无参数**时：
  - 运行全部已注册测试用例。
  - 退出码：
    - `0` → 所有测试通过；
    - 非 `0` → 存在失败/错误（CI 可以直接据此判定 Fail）。
- **XML 报告输出**：
  - 支持 `--xmlfile:SomePath.xml` 或 `--xml:SomePath.xml` 参数，将结果以 NUnit XML 格式输出。
  - 方便与 Jenkins / GitLab CI / GitHub Actions 等 CI 工具集成。
- **ExitBehavior**：
  - DUnitX 中建议使用 `--exitbehavior:Continue`，防止测试失败时阻塞等待输入（便于自动化）。

### 2.3 最佳实践

- 测试 Runner 的 `uses` 区尽量只依赖被测模块和测试单元，不要引入 UI 层和外部依赖。
- 单元测试和集成测试分离：
  - 单元测试不访问真实外部资源（数据库/网络），速度要足够快。
  - 集成测试可以访问真实资源，但要注意环境前置条件检查和清理逻辑。

---

## 3. GUI 测试中心（面向开发者）

### 3.1 功能需求

每个 UniBase 桌面应用在 Debug/内部版本中，应提供一个“测试中心”界面，至少满足：

- **测试发现与分组**：
  - 按类别展示测试：Unit / Integration / GUI / Stress / Other。
  - 可使用 `TTreeView`、`TListView` 或 Tab 控件分组。
- **测试运行控制**：
  - 支持 “运行全部”、“运行选中”、“按类别运行” 等操作。
  - 显示当前运行进度（进度条/计数/状态文本）。
- **结果展示**：
  - 汇总：总测试数 / 通过 / 失败 / 错误 / 跳过。
  - 详情：失败用例的名称、错误信息、堆栈/上下文链接。
  - 提供跳转或链接到详细 HTML 报告。
- **运行环境**：
  - 支持在应用内部直接运行（例如通过嵌入式 Runner 或调用外部测试 EXE）。
  - 不强制要求安装 PowerShell/脚本环境。

### 3.2 技术选型

推荐直接复用 UniBase 已有测试基础设施：

- **GUI 自动化与截图对比**：
  - `Core\UniBase.TestHelper.pas`  
    - 提供控件查找、模拟点击/输入、截图保存等基础能力。
  - `Tests\GUI\UniBase.GUITest.pas`（单元：`UniBase.GUITest`）
    - 提供 `TGUITestBase`、`TGUITestRunner` 等基类：
      - 步骤记录（Step/Verify）。
      - 截图捕获、基准图对比。
      - HTML/JSON 报告生成。
- **参考工程**：
  - `Tests\GUI\UniBaseGUITests.dpr`
    - 控制台入口的 GUI 自动化测试 Runner。
    - 可以作为“测试中心”界面的实现参考（将其中的测试运行逻辑封装到应用内的窗体中）。

### 3.3 典型界面结构示例

> 以下为参考设计，可根据项目实际 UI 规范调整。

- 左侧：`TTreeView` 测试分类树
  - `Unit Tests`
  - `Integration Tests`
  - `GUI Tests`
  - `Stress Tests`
- 中间：测试列表
  - 列：名称 / 分类 / 最近结果 / 耗时 / 标签
  - 多选支持（Shift/Ctrl）
- 右侧：测试详情
  - 单个用例的输出信息 / 错误消息 / 堆栈摘要
  - 链接到 HTML 报告（在浏览器或内嵌 WebView 打开）
- 底部：控制区
  - 按钮：运行全部 / 运行选中 / 停止 / 打开报告目录
  - 进度条 + 当前状态文本

### 3.4 与正式版本的关系

- Debug/内部构建：
  - 始终启用测试中心入口（用于开发、测试、现场诊断）。
- Release/生产构建：
  - 可以隐藏测试中心菜单项，或添加访问保护（例如：命令行开关、隐藏快捷键、仅在特定配置下可见）。

---

## 4. UniBase 参考实现

### 4.1 核心测试工程

- **单元测试 Runner**：`Tests\UniBaseTests.dpr`
  - 使用 DUnitX，涵盖核心模块（Config/i18n/Logging/DB/LLM/Crypto 等）。
- **集成测试 Runner**：`Tests\Integration\UniBaseIntegrationTests.dpr`
  - 使用自定义集成测试框架 `UniBase.IntegrationTest.pas`。
  - 当前包括：
    - Core 集成测试：配置、日志、数据库、工作流等（部分依赖 FireDAC/SQLite 环境）。
    - WebAPI 集成测试：`Test.Integration.WebAPI.pas` 覆盖 HTTP 路由、查询参数、CORS、JWT 认证、OpenAPI 生成和 WebSocket 消息路由。

### 4.2 GUI 自动化测试工程

- **GUI 测试 Runner**：`Tests\GUI\UniBaseGUITests.dpr`
  - 使用 `UniBase.GUITest` + `UniBase.TestHelper`：
    - 提供 GUI 自动化测试基类 `TGUITestBase`。
    - 支持截图比对与 HTML/JSON 报告生成。
  - 测试单元：
    - `Test.GUI.Core.pas`（核心控件/窗口流程）。
    - `Test.GUI.VCL.pas`（配置控件、i18n 控件、主题切换等 GUI 行为）。

> 注意：`UniBaseGUITests.exe` 当前以控制台应用形式运行测试，但内部测试逻辑完全可以嵌入到任意 VCL/FMX 窗体中，作为“测试中心”的执行后端。

### 4.3 UniBaseRun 示例中的自检

- `UniBaseRun` 项目中：
  - `ViewMain.pas` 的 "Tools" 页签包含 `ButtonSelfCheck`：
    - 调用 `TUniBaseManager.HealthCheck` 检查配置数据库、资源目录等。
    - 调用 `CtrlMain.PerformSelfCheck` 检查 `root` 路径、日志目录、`config.db` 等。
  - 这是一个**运行时健康检查 / 自诊断界面**的示例。
- 后续建议：
  - 在 `UniBaseRun` 中新增“测试中心”页签：
    - 复用上述 HealthCheck 自检结果。
    - 挂接一部分单元/集成/GUI 测试（例如关键工作流的烟雾测试）。

---

## 5. 集成步骤建议（针对新应用）

1. **创建测试工程**：
   - 新建 `AppNameTests.dpr` + `AppNameIntegrationTests.dpr`，参考 `Tests\UniBaseTests.dpr` / `Tests\Integration\UniBaseIntegrationTests.dpr`。
   - 为关键模块先补齐 DUnitX 单元测试。
2. **引入 GUI 测试基础设施**：
   - 将 `UniBase.TestHelper.pas` 和 `UniBase.GUITest.pas` 加入项目（或公共包）。
   - 可选：添加独立的 GUI 测试工程（类似 `UniBaseGUITests.dpr`）。
3. **在主应用中添加“测试中心”窗体/页签**：
   - VCL：可以用 `TForm` + `TTreeView`/`TListView` + `TMemo`/`TPageControl` 组成基本布局。
   - FMX：可用 `TLayout` + `TTreeView`/`TListView` + `TMemo`/`TTabControl` 实现类似结构。
4. **实现测试列表与运行逻辑**：
   - 硬编码或通过反射维护一份测试用例清单。
   - 调用内部 Runner 或外部测试 EXE，并解析返回结果/退出码，更新界面。
5. **在 Debug 构建启用入口**：
   - e.g. `{$IFDEF DEBUG}` 下注册菜单项 "测试中心..."。
   - 在 Release 构建中隐藏或通过配置开关控制。

---

## 6. 后续扩展

- 在 CI/CD 中统一：
  - 使用控制台 Runner 提供 XML 报告，配合 GitHub Actions / GitLab CI / Jenkins 等平台汇总测试结果。
- 在应用内扩展：
  - 为测试中心增加 **覆盖率视图**（从覆盖率工具导入统计结果）。
  - 增加 **一键导出诊断包**（测试结果 + 日志 + 环境信息）。
- 在文档层面：
  - 所有基于 UniBase 的项目文档应在“开发说明”章节中说明：
    - 控制台测试 Runner 的位置与用法。
    - GUI 测试中心的入口位置与主要功能。

---

## 7. 与 UniPublisher 的协同（测试中心 + 发布工具）

### 7.1 职责划分

- **Developer Test Center（本文件）**：
  - 面向开发者/内部使用，负责 **运行测试、查看结果、导出报告**。
  - 每个应用各自实现，集成在主程序 UI 中（Debug/内部版本必备）。
- **UniPublisher（独立 GUI 发布工具）**：
  - 面向开发者/发布负责人，负责 **打包、生成 version.json、上传发布**。
  - 所有应用共用一套工具：`Tools/UniPublisher/UniPublisher.exe`。

> 约定：**每个使用 UniBase 的桌面应用，都必须在开发者测试中心中提供一个统一的「打开 UniPublisher」入口**，不再各自实现一套打包 GUI。

### 7.2 测试中心中的「打开 UniPublisher」按钮

在测试中心窗体/页签底部，推荐增加一个简单按钮：

- 按钮文本：`打开 UniPublisher...`
- 目标用户：**开发者/内部测试人员**（Release 版本可隐藏）。
- 行为：
  - 通过 `ShellExecute` 或等价 API 启动 `UniPublisher.exe`。
  - **不传递任何命令行参数**，由 UniPublisher 自己记住最近使用的项目（MRU）。

伪代码示例：

```delphi path=null start=null
procedure TTestCenterForm.btnOpenUniPublisherClick(Sender: TObject);
begin
  // 1) 解析 UniPublisher 路径：
  //    - 优先从 Settings 中读取配置项，例如：Update.UniPublisherPath
  //    - 若未配置，可尝试相对路径： ..\Tools\UniPublisher\UniPublisher.exe
  // 2) 若文件不存在，则给出友好错误提示。

  if not FileExists(FUniPublisherPath) then
  begin
    ShowMessage('未找到 UniPublisher.exe，请检查 Tools 目录或配置项 Update.UniPublisherPath');
    Exit;
  end;

  ShellExecute(0, 'open', PChar(FUniPublisherPath), nil, nil, SW_SHOWNORMAL);
end;
```

> 注意：按钮本身**不负责**选择 `.publish.json` 或填写版本号，只是把开发者带到统一的 UniPublisher 界面中；项目选择和版本信息在 UniPublisher 内通过 MRU 和 UI 完成。

### 7.3 推荐工作流

1. 开发者在当前应用中打开“测试中心”页签。
2. 运行关键的 Unit / Integration / GUI Tests，确保全部通过。
3. 若需要发布新版本：点击“打开 UniPublisher...”。
4. UniPublisher 启动后：
   - 自动加载最近一次使用的 `{AppName}.publish.json`。
   - 开发者确认/调整：新版本号、Channel(Stable/Beta/Dev)、Release Notes。
   - 选择需要的发布目标（HTTP / GitHub / Gitee）。
5. 在 UniPublisher 中一键执行“打包 + 生成 version.json + 上传发布”。
6. 发布完成后，可以在测试中心中附加一次“安装后回归测试”（可选）。

### 7.4 与发布工具规范的关系

- 本文件只规定**测试中心一侧**的要求：
  - 必须有统一的“打开 UniPublisher”入口。
  - 入口行为是“启动工具”,而不是直接执行打包逻辑。
- 关于 `.publish.json`、`version.json` 和发布目标配置，归发布工具项目自身维护；UniBase 文档只保留测试中心集成入口约定。
