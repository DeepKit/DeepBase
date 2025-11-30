# UniBase ARCH-QUICKSTART (AI 入口指南)

> 本文是 **AI 工具和新开发者的入口文件**。在对本仓库做任何修改前，请先阅读本文件，然后再根据需要查阅 `docs/` 目录中的详细文档。

---

## 1. 总体目标

UniBase 提供一套 **Delphi 桌面应用框架**：

- 统一的配置系统（`config.db` + `UniBase.Config`）
- 统一的国际化（`UniBase.I18n` + `TI18n*` 控件）
- 统一的日志/MRU/快捷键/主题/窗体状态/异常处理
- VCL/FMX 控件库与 GUI 测试辅助（`UniBase.TestHelper`）
- doQry 数据访问子系统（`UniBase.DB.DoQry`）
- UniBase Studio/Tray/CLI 等配套工具

**对 AI 的核心要求**：

1. 先搜索、再生成，不允许绕开现有模块重复造轮子。
2. 严格遵守分层：View → Controller → Domain → uDM/DoQry。
3. 修改业务逻辑时必须考虑相应的单元测试与测试 GUI。
4. 禁止引入 INI/Registry/裸 SQL/硬编码中文/危险线程模式。

---

## 2. 目录与关键文件速览

项目结构（简化）：

```text
UniBase/
  Core/           # UniBase 核心模块 (Manager/Config/I18n/Logging/…)
  VCL/            # VCL 控件
  FMX/            # FMX 控件
  Tools/          # Studio / Tray / CLI 等工具
  Examples/       # 示例工程
  Tests/          # 单元测试与集成测试
  sql/            # SQLite/PG Schema 与升级脚本
  docs/           # 文档系统（00–18, ui/*）
  ARCH-QUICKSTART.md  # 你正在看的文件
```

对 AI 最重要的文档：

- `docs/00_UniBase架构与核心理念.md` – 双库策略、整体架构概念
- `docs/01_项目开发规范与标准.md` – 命名、分层、交叉访问矩阵
- `docs/02_UniBase最佳实践指南.md` – 可直接复制的 View/Ctrl/uDM 模板
- `docs/06_快速启动Checklist.md` – 新项目 10 步 Checklist
- `docs/07_测试与自动化指南.md` – DUnitX/构建/CI/测试 GUI/静态规范检查
- `docs/08_AI辅助开发规范.md` – AI 行为红线与自检清单
- `docs/09_Delphi架构陷阱防范.md` – 10 大 Delphi 架构/实现陷阱与示例
- `docs/10.docs-overview.md` – 全文档导航和目录树

在回答用户问题或修改代码前，AI 应优先从以上文件搜索相关信息。

---

## 3. 架构分层与职责

### 3.1 逻辑分层模型

```text
View (Form/Frame) → Controller (Application Service)
                        ↓
                     Domain (Entity + Domain Service)
                        ↓
             Data Access (uDM + DoQry + 外部服务网关)
```

**View 层**

- 只负责 UI 展示与收集输入；
- 通过 Controller 接口调用业务逻辑；
- 可以使用：
  - `TI18nLabel/TI18nButton/TI18nMenuItem` 绑定 `TextKey`
  - `TConfigEdit/TConfigCheckBox/TConfigSpinEdit` 自动绑定配置
  - `TFormStateHelper` 自动保存/恢复窗口状态
- **禁止**：
  - 直接访问 `TFDConnection/TFDQuery` 或执行 SQL；
  - 读写 INI/Registry/自建 JSON 配置；
  - 直接使用 `TIniFile`/`OutputDebugString`。

**Controller 层**

- 编排业务流程，调用 Domain Service/Repository/uDM；
- 可以访问：`UniBase.Config/Logger/DoQry` 与业务 `uDM`；
- 通过 IView 接口或回调更新 UI，而不是直接持有具体 Form 类型；
- 异步模式统一使用：`TTask.Run + TThread.Queue`。

**Domain 层**

- 包含实体类型和纯业务逻辑；
- 不依赖 VCL/FMX/FireDAC/UniBase 控件；
- 应当有较高的单元测试覆盖率。

**Data Access（uDM/DoQry）**

- 只负责数据库连接、查询与事务控制；
- 不包含业务规则，不引用 VCL/FMX；
- 推荐通过 DoQry 的参数化查询接口访问数据。

---

## 4. 示例项目结构（建议形态）

```text
MyApp/
  MyApp.dpr                 # 主程序入口（调用 UniBase.InitializeEx）
  ViewMain.pas              # 主窗体 (View)
  CtrlMain.pas              # 主控制器 (Controller)
  Model/
    ModelUser.pas           # 业务实体与领域模型 (Domain)
  DataModules/
    uDM.pas                 # 业务数据库 DataModule，仅做数据访问
  Tests/
    Test.CtrlMain.pas       # 控制器单元测试（DUnitX）
    Test.UniBase.Config.pas # 配置模块单元测试
  MyApp.TestGUI/
    MyApp.TestGUI.dpr       # 测试 GUI 工程，用于人工点击回归测试
    uFrmTestMain.pas        # 测试主窗体，承载各类测试 Frame
    Frames/
      uFrameUserCrudTests.pas   # 用户 CRUD 测试界面（复用正式业务 Frame）
```

关键约定：

- **View/Ctrl/Domain/uDM 分层清晰**：任何跨层访问都应通过接口或服务；
- **测试代码集中**在 `Tests/` 与 `*.TestGUI` 工程；
- **业务与测试共用同一批 Frame 和 Controller**，禁止为测试再造一套近似界面。

---

## 5. 必须复用的 UniBase 模块

AI 在生成代码前，必须优先搜索并复用以下模块，而不是自建实现：

| 需求            | 必须使用                 | 禁止                     |
|-----------------|--------------------------|--------------------------|
| 读写配置        | `UniBase.Config`         | `TIniFile`/Registry/JSON |
| 多语言文本      | `UniBase.I18n.T/TFmt`    | 硬编码中文/英文          |
| 日志            | `UniBase.Logger`         | `OutputDebugString`      |
| 窗体状态        | `UniBase.FormState`/`TFormStateHelper` | 手写位置/大小保存 |
| 最近文件/MRU    | `UniBase.MRU`           | 自建 MRU 列表            |
| 快捷键          | `UniBase.Hotkeys`       | 硬编码快捷键             |
| 数据库访问      | `UniBase.DB.DoQry` 或公共 uDM 封装 | 裸 SQL 字符串拼接  |
| GUI 测试        | `UniBase.TestHelper`    | 自建 GUI 测试框架        |

**搜索示例（AI 应自动执行）：**

```bash
# 搜索配置读取
grep -r "GetConfig\|GetConfigInt" --include="*.pas" .

# 搜索已有 HTTP 封装
grep -r "THTTPClient\|class.*HTTP" --include="*.pas" .

# 搜索工具类
grep -r "UT.*Utils\|BT.*Helper" --include="*.pas" .

# 搜索数据库访问模式
grep -r "DoQry\|ExecSQL" --include="*.pas" .
```

---

## 6. 测试与自动化要求（给 AI 的硬约束）

1. **修改业务逻辑 → 必须检查/补充 DUnitX 测试**
   - 测试放在 `Tests/` 目录，遵守 `Test.<模块名>.pas` 命名；
   - 每个公开方法至少有一个成功用例和一个失败/边界用例。

2. **命令行构建和测试**（不要只依赖 IDE）：

```batch
call "C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\bin\\rsvars.bat"
msbuild Tests\\UniBaseTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32
Tests\\Win32\\Debug\\UniBaseTests.exe --xmloutput=TestResults.xml --exitbehavior=Continue
```

3. **每个应用都要有测试 GUI**（见 `07_测试与自动化指南.md`）：
   - 工程名形如 `MyApp.TestGUI.dpr`；
   - 通过按钮/Tab 触发关键业务流程，复用正式 Frame 与 Controller；
   - 人工回归时，只需点击测试 GUI 即可验证主要功能。

4. **自动化纠错流程**（当测试或编译失败时）：
   - 收集完整错误输出（含文件、行号、错误码）；
   - 搜索项目中类似正确用法；
   - 给出最小修改方案；
   - 再次运行构建+测试，直至通过。

详见：`docs/07_测试与自动化指南.md`。

---

## 7. AI 行为红线（必须遵守）

AI 在本仓库中 **绝对禁止**：

- 新增 INI/Registry/随机 JSON 文件作为配置来源；
- 在任何地方硬编码中文/英文用户提示文本；
- 直接使用 `Application.ProcessMessages` 循环或 `TThread.Synchronize`；
- 在 View 中直接创建和执行 `TFDQuery.ExecSQL`；
- 在 DataModule 中引用 `Vcl.Forms`/`Dialogs` 或直接操作 UI；
- 引入全局变量保存业务状态（当前用户/订单等）。

AI 必须：

- 先搜索现有实现，再决定是否写新代码；
- 复用 `Core/`、`VCL/`、`FMX/` 中已存在的模块和模式；
- 遵守 `docs/01`、`02`、`07`、`08`、`09` 中的所有分层与安全约束；
- 在回答中说明：
  - 复用了哪些现有模块；
  - 新增了哪些最小必要改动；
  - 如何编译与测试这些改动。

---

## 8. 推荐阅读顺序（AI & 新开发者）

1. 本文件 `ARCH-QUICKSTART.md`
2. `docs/10.docs-overview.md`（总览与角色导读）
3. `docs/00_UniBase架构与核心理念.md`
4. `docs/01_项目开发规范与标准.md`
5. `docs/02_UniBase最佳实践指南.md`
6. `docs/07_测试与自动化指南.md`
7. `docs/08_AI辅助开发规范.md`
8. `docs/09_Delphi架构陷阱防范.md`

之后再根据需要查阅：

- API 细节：`docs/13.api.md`, `docs/14.api-reference.md`
- 数据库：`docs/03_PostgreSQL业务数据库指南.md`, `docs/16/17` doQry 文档
- UI 设计：`docs/ui/*`

---

> 对 AI：如果不确定某项修改是否符合规范，请**优先搜索并引用上述文档**中的相关章节，再给出修改建议或代码实现。