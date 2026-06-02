# DeepBase ARCH-QUICKSTART (AI 入口指南)

> 本文�?**AI 工具和新开发者的入口文件**。在对本仓库做任何修改前，请先阅读本文件，然后再根据需要查�?`docs/` 目录中的详细文档�?
>
> 对于 **其它 Delphi 程序�?*，如果只是想在现有工程中集成 DeepBase（含 DoQry、LLM），**只需要完整看完下面的�?. 外部程序集成 DeepBase」一节即�?*，其余章节作为参考资料�?

---

## 0. 外部程序集成 DeepBase（一页说明）

本节面向已经有自�?Delphi 工程的开发者，目标是：

- 在现有程序中初始�?DeepBase（配�?+ 日志 + i18n + 主题 + 安全�?
- 集成 **DoQry** 做业务数据库访问
- 集成 **LLM 模块** 调用大模�?- 集成 **Commerce 模块** 统一用户、订单、支付和权益流程（如项目需要）
- 采用 `root.txt + DB1 + DB2 + DB3` 的统一目录与数据库布局，便于重构与迁移

> **不强制安装设计时�?*�?
> - 如果只是做运行时集成（不�?IDE 里拖控件），基础能力至少加入 `Core/`；使用数据库能力时还必须加入 `Persistence/`；使用可选功能时加入 `Features/`�?> - 包方式接入时，基础功能使用 `DeepBaseCore.dpk`；服务能力使�?`DeepBaseServices.dpk`；数据库能力使用 `DeepBasePersistence.dpk`；LLM/Commerce/Updater/AntiTamper/Unlock/CloudSync/CloudBackup/Graph/HttpServer 等可选功能使�?`DeepBaseFeatures.dpk`�?> - 设计时包安装仅用于在 IDE 里使�?VCL/FMX 控件：VCL 安装 `dclDeepBaseVCL.dpk`，FMX 安装 `dclDeepBaseFMX.dpk`�?> - `DeepBaseCore.dpk` 不直接依�?VCL/FMX/FireDAC；VCL 主题切换和全局异常展示�?`DeepBaseVCL.dpk` 中的适配器注册，FMX 控件通过 `DeepBaseFMX.dpk` 独立编译�?
### 0.1 为什么要在其它程序集�?DeepBase�?

对一个已�?Delphi 工程，引�?DeepBase 的直接收益：

1. **配置集中�?config.db**
   - 原来散落�?`INI/Registry/JSON` 里的配置，统一迁移�?SQLite `Settings` 表，方便备份、迁移和环境切换�?
2. **root.txt + 多库布局（DB1 + DB2 + DB3）统一管理**
   - `root.txt` 锚定项目根目录；
   - `DB1 = config.db`（框架与应用配置�?
   - `DB2 = data.db`（业务数据库：可选，或使�?PG 等外部库�?
   - `DB3+ = 其他功能库`（如 Studio、Tray 或业务子系统独立 DB�?
   - 所有路径通过 DeepBase.Manager 统一计算，便于重构、迁移到新目录或多实例部署�?
3. **基础设施统一**
   - 配置：`DeepBase.Config`
   - 日志：`DeepBase.Logging`（文�?+ SQLite�?
   - 国际化：`DeepBase.i18n` + Studio 翻译工具
   - 窗体状态：`DeepBase.FormState` / `TFormStateHelper`
   - 安全/密钥：`DeepBase.Security`（DPAPI�?
   - 业务数据访问：`DeepBase.DB.DoQry`
   - LLM 调用：`DeepBase.LLM`
4. **渐进式重构友�?*
   - 可先只接�?`root.txt + config.db` 和日志；
   - 然后逐步迁移配置、i18n、MRU、热键等，不需要“大爆炸式重写”�?

### 0.2 功能清单（给外部程序看的索引�?

| 能力             | DeepBase 模块                 | 建议用�?                                   |
|------------------|------------------------------|---------------------------------------------|
| 配置管理         | `Core/DeepBase.Config.pas`    | 所有应用配置统一�?`config.db`             |
| 国际�?          | `Core/DeepBase.i18n.pas`      | 文本翻译；配�?Studio 翻译管理             |
| 日志             | `Core/DeepBase.Logging.pas`   | 统一日志（SQLite + 文件），支持轮转         |
| 窗体状�?        | `Core/DeepBase.FormState.pas` + VCL/FMX Helper | 自动保存/恢复窗口位置/大小          |
| MRU 最近使�?    | `Core/DeepBase.MRU.pas`       | 最近文�?项目列表                          |
| 快捷�?          | `Core/DeepBase.Hotkeys.pas`   | 用户可配置快捷键                           |
| 业务数据访问     | `Persistence/DeepBase.DB.DoQry.pas` | 通过 `Queries` 表和 JSON 参数执行 SQL      |
| 安全/密钥        | `Core/DeepBase.Security.pas`  | 使用 DPAPI 加密保存 API Key/密码           |
| LLM 集成         | `DeepBaseFeatures.dpk`；兼容门�?`Core/DeepBase.LLM.pas`，扩展源码位�?`Features/DeepBase.LLM.*.pas` | �?OpenAI/Anthropic/LiteLLM/Ollama �?     |
| Commerce 商业流程 | `Features/DeepBase.Commerce.*.pas` | 用户身份、订单、支付意图、支付确认、权益发�?|
| 数学工具         | `Features/DeepBase.Math.pas` | 数值、统计、插值、矩�?向量等边界工�?|
| 云同�?云备�?    | `Features/DeepBase.CloudSync.pas` / `Features/DeepBase.CloudBackup.pas` | 多设备配置同步、备份恢�?|
| Graph/HTTP Server | `Features/DeepBase.Graph.pas` / `Features/DeepBase.HttpServer.pas` | 图结构算法、轻�?HTTP 服务 |
| CLI 扩展能力      | `Tools/CLI/DeepBase.CLI.*.pas` | 交互�?CLI、管道、SSH 远程执行 |
| ORM/IoC/MVVM    | `Core/DeepBase.ORM.pas` / `Core/DeepBase.IoC.pas` / `Core/DeepBase.MVVM.pas` | 进阶架构    |

> 对外部程序而言�?*首选集成顺�?*：`Manager + Config + Logging` �?`FormState` �?`DoQry` �?`i18n` �?`LLM`�?

### 0.3 root.txt + DB1 + DB2 + DB3 布局（非常重要）

DeepBase 推荐所有程序集成使用统一的磁盘布局�?

#### 0.3.1 �?root.txt �?{AppName}Config.db 的解析流程（最易出错）

1. **确定应用�?AppName**
   - 默认：`AppName = ExtractFileNameWithoutExt(ParamStr(0))`，也就是 EXE 文件名去掉扩展名�?
   - 例如：`MyApp.exe` �?`AppName = 'MyApp'`�?
2. **读取 root.txt 得到 RootPath**
   - 查找顺序�?
     1. `<exe_dir>\\root.txt`
     2. `%APPDATA%\\<AppName>\\root.txt`
   - `root.txt` 要求�?
     - 第一行是**存在的绝对目录路�?*，例如：
       ```text
       D:\\Projects\\MyAppRoot
       ```
     - 不要加引号、不写相对路径、不�?INI 段落头（`[Paths]` 等）�?
   - 如果找不�?root.txt，则 `InitializeEx` 会尝试在 EXE 目录�?`%APPDATA%` **自动创建** 一�?root.txt，并把对应目录作�?RootPath�?
3. **推导配置�?{AppName}Config.db**
   - Manager 代码等价于：
     - `ConfigFileName := AppName + 'Config.db';`
     - 首先尝试：`ConfigDBPath := RootPath + '\\' + ConfigFileName;`
     - 若文件不存在，则回退到：`%APPDATA%\\<AppName>\\<AppName>Config.db`�?
   - 如果两个位置都找不到，就报错 `Config database not found`，DeepBase 无法初始化�?
4. **典型错误示例**（建议在联调时检查）�?
   - `root.txt` 写了相对路径，如 `..\\data`，导�?Manager 无法识别（要求绝对路径）�?
   - 把配置库命名�?`config.db` 或放�?`RootPath\\data\\config.db`，但没有命名�?`{AppName}Config.db` 放在 RootPath�?
   - `root.txt` 指向了一个目�?A，而你却把 `{AppName}Config.db` 放在目录 B�?
   - EXE 改名�?`MyApp2.exe`，但仍然只创建了 `MyAppConfig.db`，此�?Manager 会去�?`MyApp2Config.db`�?

> 建议�?
> - 每个外部程序在第一次集成时，明确约定“EXE �?+ RootPath + {AppName}Config.db”三者；
> - 通过一个小测试程序调用 `DeepBase.InitializeEx` 并输�?`RootPath` �?`ConfigDBPath`，确认路径无误后再接入业务代码�?
>
> 如果希望�?UI 引导最终用户选择 RootPath，可以复�?`TDBInitWizard`（单�?`VCL/DeepBase.VCL.DBInitWizard.pas`），它会帮助写入/清理 EXE 目录下的 `root.txt`，然后再调用 `DeepBase.InitializeEx`�?

#### 0.3.2 DB1/DB2/DB3 角色划分

1. **DB1：配置数据库 config.db（必选）**
   - 引擎�?*SQLite（UTF-8，WAL 模式�?*�?
   - 物理文件名：`{AppName}Config.db`（例�?`MyAppConfig.db`）�?
   - 典型位置�?
     - `RootPath\\MyAppConfig.db`，或
     - `%APPDATA%\\MyApp\\MyAppConfig.db`（当 EXE 目录只读时）�?
   - 作用�?
     - 存放 DeepBase 自己的表（SchemaInfo/ProjectInfo/Settings/FormStates/Languages/I18nTexts/Logs/MRU/Hotkeys/Queries/Themes/LLMConfig/LLMCalls/...）；
     - 外部程序也可以安全地在此库中增加自有配置表，�?*建议�?DeepBase 表区�?Schema 或前缀**�?
   - Schema 版本�?
     - 当前版本：`SchemaInfo.SchemaVersion = '0.3'`�?
     - 版本范围�?`DeepBase.Schema` 中的 `MIN_COMPATIBLE_SCHEMA_VERSION` / `MAX_COMPATIBLE_SCHEMA_VERSION` 控制�?
   - **其它程序连接 DB1 的规�?*�?
     - 只要根据上节规则找到 `ConfigDBPath`，即可按普�?SQLite 打开�?
     - 推荐 PRAGMA/参数（以 Delphi FireDAC 为例）：
       ```delphi path=null start=null
       Conn := TFDConnection.Create(nil);
       Conn.DriverName := 'SQLite';
       Conn.Params.Database := ConfigDBPath;       // = DeepBase.ConfigDBPath 或上一节约定的路径
       Conn.Params.Values['LockingMode'] := 'Normal';
       Conn.Params.Values['Synchronous'] := 'Normal';
       Conn.Params.Values['JournalMode'] := 'WAL';
       Conn.Params.Values['OpenMode'] := 'CreateUTF8';
       Conn.LoginPrompt := False;
       Conn.Connected := True;
       ```
     - 其它语言/驱动�?
       - 连接字符串中建议开�?`journal_mode=WAL`、`synchronous=NORMAL`�?
       - 一律使�?UTF-8 文本�?
       - 不要关闭 WAL 或强�?`DELETE` 日志模式，否则会影响 DeepBase 并发访问�?
     - 并发与写入约束：
       - 如果 DeepBase 进程正在运行，外部程�?*尽量只读访问** DB1（读�?Settings、Queries、Languages 等）�?
       - 如需写入 Settings 等配置项，建议：
         - 在应用内使用 `DeepBase.Config.SetConfig` 完成（推荐）；或
         - �?*离线维护工具**中修改（此时停掉业务程序，避免并发写入冲突）�?
     - 禁止操作�?
       - 不要 `DROP/ALTER` DeepBase 自带的表结构（SchemaInfo/Settings/Logs/...）；
       - 不要手动更改 `SchemaInfo` 中的版本号；
       - 不要�?DeepBase 表做 `VACUUM INTO` 后替换文件，除非确定版本兼容且已停止所�?DeepBase 进程�?

2. **DB2：业务数据库 Data.db（可选）**
   - 物理文件名示例：`MyAppData.db` 或独立的 PostgreSQL/其它 RDBMS�?
   - 典型位置：`RootPath\\data\\MyAppData.db` 或专�?DB 服务器�?
   - 访问方式�?
     - 由你�?`uDM` 或仓储层创建自己�?`TFDConnection`（针�?SQLite/PG 等）�?
     - 使用 `DeepBase.DB.DoQry`（推荐）或自有封装进行访问；
     - **不要把业务数据混�?config.db �?*�?

3. **DB3 及更多：扩展子系统数据库（如 Studio/Tray/日志分析等）**
   - 可以为不同子应用或工具分库：
     - `StudioConfig.db` �?Studio 自己的设置与项目索引�?
     - `Tray.db` �?Tray 工作台的日志/快捷命令等；
     - 其他业务子系统的独立 DB�?
   - 所有这�?DB 都可以通过 `root.txt` + 约定路径派生出来，避免在代码中硬编码绝对路径�?

> 迁移/重构时，只要�?
> 1. 把整�?RootPath 目录移动到新位置�?
> 2. 更新 `root.txt` 第一行；
> 3. 外部程序无需改代码，就能使用新的配置库和数据路径�?

#### 0.3.3 �?Settings 中约�?DB2/DB3 连接配置（统一规范�?

为了�?*不同程序可以按同一个规范读�?DB2/DB3 配置**，建议所有项目在 `Settings` 表中使用以下 Key�?

1. **DB2 �?业务 SQLite（本地文件）**

   - 推荐含义：本�?SQLite 业务库，例如 `MyAppData.db`�?
   - 建议 Key�?
     - `DB2.Type` = `SQLite`
     - `DB2.Path` = 业务库路径：
       - 若以盘符开头（`C:\` / `D:\`），视为绝对路径�?
       - 否则视为**相对 `RootPath` 的相对路�?*（例�?`data\\MyAppData.db`）�?
     - （可选）`DB2.ReadOnly` = `True`/`False`
   - 任何程序都可以按以下逻辑构造连接（Delphi/FireDAC 示例）：

   ```delphi path=null start=null
   uses
     DeepBase.Manager, DeepBase.Config, FireDAC.Comp.Client;

   function CreateDB2Connection: TFDConnection;
   var
     Path, FullPath: string;
   begin
     Path := DeepBase.Config.GetConfig('DB2.Path', 'data\\MyAppData.db');
     if TPath.IsPathRooted(Path) then
       FullPath := Path
     else
       FullPath := TPath.Combine(DeepBase.RootPath, Path);

     Result := TFDConnection.Create(nil);
     Result.DriverName := 'SQLite';
     Result.Params.Database := FullPath;
     Result.Params.Values['LockingMode'] := 'Normal';
     Result.Params.Values['Synchronous'] := 'Normal';
     Result.LoginPrompt := False;
     Result.Connected := True;
   end;
   ```

2. **DB3 �?共享业务库（PostgreSQL / SQLite�?*

   - 推荐含义：共享业务数据库（可�?PostgreSQL �?SQLite）；
   - 建议 Key�?
     - `DB3.Type` = `PostgreSQL` / `PG` / `SQLite`
     - �?`DB3.Type=PostgreSQL/PG`：`DB3.Server`、`DB3.Port`、`DB3.Database`、`DB3.User`、`DB3.Password`
     - �?`DB3.Type=SQLite`：`DB3.Database`（支持相�?`RootPath`；兼容历�?`DB3.Path`�?
     - 通用可选：`DB3.ApplicationName`、`DB3.ConnectTimeoutSec`、`DB3.CommandTimeoutSec`、`DB3.ExtraParams`
     - PostgreSQL 可选：`DB3.SSLMode`、`DB3.VendorLib`
     - SQLite 可选：`DB3.SQLiteLockingMode`、`DB3.SQLiteSynchronous`、`DB3.SQLiteJournalMode`、`DB3.SQLiteOpenMode`
   - 构造连接示例（Delphi/FireDAC）：

   ```delphi path=null start=null
   uses
     DeepBase.Manager, DeepBase.Config, FireDAC.Comp.Client;

   function CreateDB3Connection: TFDConnection;
   var
     Server, Database, UserName, Password: string;
     Port: Integer;
   begin
     Server   := DeepBase.Config.GetConfig('DB3.Server', '127.0.0.1');
     Database := DeepBase.Config.GetConfig('DB3.Database', 'mydb');
     UserName := DeepBase.Config.GetConfig('DB3.User', 'postgres');
     Password := DeepBase.Config.GetConfig('DB3.Password', '');  // 如使用加密，可先调用 Security 解密
     Port     := StrToIntDef(DeepBase.Config.GetConfig('DB3.Port', '5432'), 5432);

     Result := TFDConnection.Create(nil);
     Result.DriverName := 'PG';
     Result.Params.Values['Server']   := Server;
     Result.Params.Values['Database'] := Database;
     Result.Params.Values['User_Name']:= UserName;
     Result.Params.Values['Password'] := Password;
     Result.Params.Values['Port']     := IntToStr(Port);
     Result.LoginPrompt := False;
     Result.Connected := True;
   end;
   ```

> 约定�?
> - 所有使�?DeepBase 的程序（主程序、工具、服务）都应尽量复用以上 `DB2.*` / `DB3.*` Key�?
> - 这样任何一个新工具，只要能访问 DB1（config.db），就可以按相同规范读出 DB2/DB3 配置信息，并建立自己的连接；
> - 若未来实现统一的“数据库配置窗体”，也应直接读写这些 Key，以保证兼容性�?

#### 0.3.4 DB1 表访问规范（对外开放程度）

为了避免外部程序误操�?DB1（config.db）导致框架异常，这里给出一�?*按表分类的访问建�?*�?

1. **内部核心表（禁止直接写，必要时只读）**
   - `SchemaInfo`
     - 作用：记录当�?Schema 版本号、创�?升级时间�?
     - 约定：仅�?DeepBase 自己创建和维护；外部程序只可只读查看版本，不得修改�?
   - `ExceptionReports`
     - 作用：记录异常上报信息（堆栈、截图、环境等）；
     - 约定：写入由异常捕获/上报模块负责，外部程序仅做只读分析�?

2. **配置类表（可读写，但推荐通过 DeepBase API 或官方工具）**
   - `Settings`
   - `ProjectInfo`
   - `Languages`
   - `I18nTexts`
   - `Themes`
   - `Hotkeys`
   - `Queries`
   - `LLMConfig`
   - 约定�?
     - 这些表承载应用配置、国际化、主题、快捷键、查询与 LLM 配置�?
     - 外部程序**可以在停机维护工具中直接读写**，但运行时推荐通过 `DeepBase.Config` / `DeepBase.i18n` / `DeepBase.Theme` / `DeepBase.DB.DoQry` / `DeepBase.LLM` 等模块间接访问；
     - 若需要新增字�?行，应保持向后兼容，避免删除或重命名现有列�?

3. **状态与日志类表（只读优先，写入�?DeepBase 模块负责�?*
   - `Logs`
   - `MRU`
   - `LLMCalls`
   - 约定�?
     - 这些表主要用于记录运行时行为和调用历史；
     - 外部程序通常只需�?*读取**（用于诊断、统计、看板），不要直接插入或更新记录�?
     - 清理历史数据建议通过专用工具或脚本（如按时间批量删除），而不是单行手动编辑�?

4. **状态类表（内部使用为主�?*
   - `FormStates`
   - 约定�?
     - �?`DeepBase.FormState`/`TFormStateHelper` 等模块自动读写，记录窗体位置/大小/窗口状态；
     - 外部程序一般无需操作此表，如需“重置窗口布局”，可以整体删除某些 `FormName` 对应记录，而不建议逐字段改值�?

> 总结：外部程序集�?DeepBase 时，**主要�?Settings/Queries/LLMConfig 等“配置类表”打交道**�?
> 其它表尽量视为内部实现细节，仅做只读或通过官方模块间接访问�?

### 0.4 不安装设计包的最小集成步�?

1. **�?DeepBase 源码加入工程**�?
   - 项目选项中将 `DeepBase\Core` 加入 Search Path�?
   - 如需 VCL 控件源码（但不安装包），可将 `DeepBase\VCL` 也加�?Search Path�?
2. 在你�?`.dpr` �?`uses DeepBase.Manager;`，然后按下节的方式初始化�?
3. 后续只通过代码使用 DeepBase 功能（Config/Logging/DoQry/LLM 等），不依赖设计时组件面板�?

### 0.5 在程序入口初始化 DeepBase

�?VCL 程序为例�?

```delphi path=null start=null
program MyApp;

uses
  Vcl.Forms,
  DeepBase.Manager,
  MainFormUnit in 'MainFormUnit.pas' {MainForm};

begin
  Application.Initialize;

  // 初始�?DeepBase（使�?root.txt + config.db�?
  if not DeepBase.Initialize then
  begin
    ShowMessage('Failed to initialize DeepBase: ' + DeepBase.LastError);
    Halt(1);
  end;

  Application.CreateForm(TMainForm, MainForm);
  Application.Run;

  // 程序结束前清�?
  DeepBase.Finalize;
end.
```

> 提示：第一次运行前，可使用 **DeepBase Studio** �?CLI 创建/初始�?`config.db`，并�?EXE �?`%APPDATA%` 下生�?`root.txt`�?

### 0.6 核心模块最小用�?

以下代码通常放在窗体或控制器中：

```delphi path=null start=null
uses
  DeepBase.Manager, DeepBase.i18n;

procedure TMainForm.FormCreate(Sender: TObject);
var
  UserName: string;
begin
  // 1. 配置读写（Config�?
  DeepBase.Config.SetConfig('App.Title', 'My Awesome App');
  Caption := DeepBase.Config.GetConfig('App.Title', 'MyApp');

  // 2. 日志（Logging�?
  DeepBase.Logger.Info('Main form created', 'MainForm');

  // 3. 国际化（i18n�?
  UserName := DeepBase.Config.GetConfig('User.Name', 'Guest');
  LabelWelcome.Caption := T('Welcome');
  ShowMessage(TFmt('Hello, %s!', [UserName]));

  // 4. 窗体状态（FormState）——若使用 TFormStateHelper，可不手�?
  // DeepBase.FormState.SaveFormState(Self);
  // DeepBase.FormState.RestoreFormState(Self);
end;
```

> 具体 API 可在需要时再查阅：`Core\DeepBase.Config.pas`, `Core\DeepBase.Logging.pas`, `Core\DeepBase.i18n.pas`�?

### 0.7 集成 DoQry：统一的业务数据库访问

前提：你已经有一个指向业务数据库�?`TFDConnection`（例�?PostgreSQL/SQLite），**它与 DeepBase �?config.db 连接是两条线**�?

1. 在应用初始化成功后（`DeepBase.Initialize` 之后）调用一次：

```delphi path=null start=null
uses
  DeepBase.Manager, DeepBase.DB.DoQry;

procedure InitDoQry;
begin
  // RootPath 用于定位 logs/ �?queries 定义
  UniDbInit(DeepBase.RootPath);
end;
```

2. 在需要访问业务库的地方创建查询上下文�?

```delphi path=null start=null
uses
  DeepBase.DB.DoQry, FireDAC.Comp.Client, DBClient;

procedure TUserService.ListActiveUsers(AConn: TFDConnection);
var
  Ctx: TUniQueryContext;
  Data: TClientDataSet;
  Rows: Integer;
begin
  Ctx := UniDbMakeContext(AConn, udbPostgreSQL, 30);  // �?udbSQLite

  Data := TClientDataSet.Create(nil);
  try
    // ProcName 可以�?Queries 表中的逻辑名，也可以直接写 SQL
    Rows := UniDbSelect(
      'user.list_active',                        // 推荐：在 Queries 表维�?
      '{"status": "active", "limit": 100}',  // JSON 参数
      Data,
      Ctx
    );

    // TODO: 遍历 Data，映射为实体
  finally
    Data.Free;
  end;
end;
```

3. 常用 DoQry API�?

- `UniDbExec`            �?执行 INSERT/UPDATE/DELETE，返回受影响行数
- `UniDbSelect`          �?执行查询，填�?`TClientDataSet`
- `UniDbScalar`          �?执行标量查询，返回单�?
- `UniDbInsertReturningId` �?插入并返回自�?ID
- `UniDbBeginTx` / `UniDbRunInTx` �?事务封装

详细行为可参考：`Persistence\DeepBase.DB.DoQry.pas` �?`Tests\Test.DeepBase.DB.DoQry.pas`�?

### 0.8 集成 LLM：统一大模型调�?

LLM 配置和调用依�?**DeepBase �?config.db**（使�?`LLMConfig`, `LLMCalls`, `LLMPrompts` 表）�?

包方式接入时，LLM 不再�?`DeepBaseCore.dpk` 承载，必须同时引�?`DeepBaseFeatures.dpk`；源码方式接入时使用 `Features/DeepBase.LLM.*.pas`�?

1. 先在 `LLMConfig` 中填�?Provider、API Key、Model 等（推荐�?DeepBase Studio �?LLM 配置面板）�?

2. 在代码中通过 `LLM()` facade 调用。不要再创建旧的 `TDeepBaseLLM` 实例�?

```delphi path=null start=null
uses
  DeepBase.LLM.Types,
  DeepBase.LLM.Client,
  DeepBase.LLM.Service;

procedure TestLLM;
var
  ChatResult: TChatResult;
begin
  ChatResult := LLM.Chat(TierSmart, '用一句话介绍 DeepBase 框架�?);
  if ChatResult.Success then
    ShowMessage(ChatResult.Content)
  else
    ShowMessage('LLM 调用失败: ' + ChatResult.ErrorMessage);
end;
```

3. 常用 LLM API�?

- `LLM.Chat(TierSmart, Prompt)`：高质量模型优先
- `LLM.Chat(TierBalanced, Prompt)`：质�?速度平衡
- `LLM.Chat(TierFast, Prompt)`：快速低成本任务
- `LLM.ChatWithHiDeepDeepDeepDeepDeepStory(Tier, Messages)`：多轮上下文
- `LLM.ChatStream(Tier, Messages, OnChunk, OnError)`：流式输�?
- `LLMAdmin.TestConnection(ProviderName, ModelId, DurationMs, ErrorMsg)`：测试配�?

更详细行为见：`Features\DeepBase.LLM.Types.pas`、`Features\DeepBase.LLM.Client.pas`、`Features\DeepBase.LLM.Service.pas` 以及 Studio 中的 LLM 配置/历史界面�?

### 0.9 推荐但非必读的后续文�?

在成功集成并跑通一个最�?Demo 之后，可按需阅读�?

- 架构与规范：`docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md`, `docs/03.03.DeepBase-4H-技术规�?v1.0.md`
- 最佳实践：`docs/02.quickstart.下游接入流程-downstream-integration.md`
- 数据库与 DoQry：`docs/04.03.DeepBase-4AI-数据库指�?v1.0.md`, `docs/41.api.DoQry指南-doqry-guide.md`
- LLM 设计：`docs/42.api.LLM集成指南-llm-integration.md`, `docs/ui/06-LLM-UI-Detailed-Design.md`

---

## 1. 总体目标

DeepBase 提供一�?**Delphi 桌面应用框架**�?

- 统一的配置系统（`config.db` + `DeepBase.Config`�?
- 统一的国际化（`DeepBase.I18n` + `TI18n*` 控件�?
- 统一的日�?MRU/快捷�?主题/窗体状�?异常处理
- VCL/FMX 控件库与 GUI 测试辅助（`DeepBase.TestHelper`�?
- doQry 数据访问子系统（`DeepBase.DB.DoQry`�?
- DeepBase Studio/Tray/CLI 等配套工�?

**�?AI 的核心要�?*�?

1. 先搜索、再生成，不允许绕开现有模块重复造轮子�?
2. 严格遵守分层：View �?Controller �?Domain �?uDM/DoQry�?
3. 修改业务逻辑时必须考虑相应的单元测试与测试 GUI�?
4. 禁止引入 INI/Registry/�?SQL/硬编码中�?危险线程模式�?

---

## 2. 目录与关键文件速览

项目结构（简化）�?

```text
DeepBase/
  Core/           # 核心与兼容门面；DeepBaseCore.dpk 只包含最小核�?  Persistence/    # FireDAC/DB 持久化适配�?  Features/       # 可选功�?(LLM/Updater/CloudSync/Graph/HttpServer/�?
  VCL/            # VCL 控件与平台适配�?  FMX/            # FMX 控件
  ThirdParty/     # 外部服务/SDK 适配�?  Tools/          # Studio / Tray / CLI 等工具；CLI 扩展单元位于 Tools/CLI
  Examples/       # 示例工程
  Tests/          # 单元测试与集成测�?
  sql/            # SQLite/PG Schema 与升级脚�?
  docs/           # 文档系统（标准编号文�? 下游集成文档, ui/*�?  ARCH-QUICKSTART.md  # 你正在看的文�?
```

�?AI 最重要的文档：

- `docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md` �?项目定位与边�?- `docs/03.03.DeepBase-4H-技术规�?v1.0.md` �?命名、分层、交叉访问矩�?- `docs/02.quickstart.下游接入流程-downstream-integration.md` �?下游工程标准接入流程
- `docs/03.quickstart.AI深挖集成指南-ai-deep-integration.md` �?AI 集成约束和初始化流程
- `docs/07.03.DeepBase-4H-安全与测�?v1.0.md` �?DUnitX/构建/CI/测试 GUI/静态规范检�?- `docs/84.ops.集成检查清单-integration-checklist�?v1.0.md` �?发布前集成检查清�?- `docs/83.ops.FAQ与错误速查-faq-troubleshooting.md` �?常见问题、陷阱与排查
- `docs/README.md` �?全文档导航和目录�?
在回答用户问题或修改代码前，AI 应优先从以上文件搜索相关信息�?

---

## 3. 架构分层与职�?

### 3.1 逻辑分层模型

```text
View (Form/Frame) �?Controller (Application Service)
                        �?
                     Domain (Entity + Domain Service)
                        �?
             Data Access (uDM + DoQry + 外部服务网关)
```

**View �?*

- 只负�?UI 展示与收集输入；
- 通过 Controller 接口调用业务逻辑�?
- 可以使用�?
  - `TI18nLabel/TI18nButton/TI18nMenuItem` 绑定 `TextKey`
  - `TConfigEdit/TConfigCheckBox/TConfigSpinEdit` 自动绑定配置
  - `TFormStateHelper` 自动保存/恢复窗口状�?
- **禁止**�?
  - 直接访问 `TFDConnection/TFDQuery` 或执�?SQL�?
  - 读写 INI/Registry/自建 JSON 配置�?
  - 直接使用 `TIniFile`/`OutputDebugString`�?

**Controller �?*

- 编排业务流程，调�?Domain Service/Repository/uDM�?
- 可以访问：`DeepBase.Config/Logger/DoQry` 与业�?`uDM`�?
- 通过 IView 接口或回调更�?UI，而不是直接持有具�?Form 类型�?
- 异步模式统一使用：`TTask.Run + TThread.Queue`�?

**Domain �?*

- 包含实体类型和纯业务逻辑�?
- 不依�?VCL/FMX/FireDAC/DeepBase 控件�?
- 应当有较高的单元测试覆盖率�?

**Data Access（uDM/DoQry�?*

- 只负责数据库连接、查询与事务控制�?
- 不包含业务规则，不引�?VCL/FMX�?
- 推荐通过 DoQry 的参数化查询接口访问数据�?

---

## 4. 示例项目结构（建议形态）

```text
MyApp/
  MyApp.dpr                 # 主程序入口（调用 DeepBase.InitializeEx�?
  ViewMain.pas              # 主窗�?(View)
  CtrlMain.pas              # 主控制器 (Controller)
  Model/
    ModelUser.pas           # 业务实体与领域模�?(Domain)
  DataModules/
    uDM.pas                 # 业务数据�?DataModule，仅做数据访�?
  Tests/
    Test.CtrlMain.pas       # 控制器单元测试（DUnitX�?
    Test.DeepBase.Config.pas # 配置模块单元测试
  MyApp.TestGUI/
    MyApp.TestGUI.dpr       # 测试 GUI 工程，用于人工点击回归测�?
    uFrmTestMain.pas        # 测试主窗体，承载各类测试 Frame
    Frames/
      uFrameUserCrudTests.pas   # 用户 CRUD 测试界面（复用正式业�?Frame�?
```

关键约定�?

- **View/Ctrl/Domain/uDM 分层清晰**：任何跨层访问都应通过接口或服务；
- **测试代码集中**�?`Tests/` �?`*.TestGUI` 工程�?
- **业务与测试共用同一�?Frame �?Controller**，禁止为测试再造一套近似界面�?

---

## 5. 必须复用�?DeepBase 模块

AI 在生成代码前，必须优先搜索并复用以下模块，而不是自建实现：

| 需�?           | 必须使用                 | 禁止                     |
|-----------------|--------------------------|--------------------------|
| 读写配置        | `DeepBase.Config`         | `TIniFile`/Registry/JSON |
| 多语言文本      | `DeepBase.I18n.T/TFmt`    | 硬编码中�?英文          |
| 日志            | `DeepBase.Logger`         | `OutputDebugString`      |
| 窗体状�?       | `DeepBase.FormState`/`TFormStateHelper` | 手写位置/大小保存 |
| 最近文�?MRU    | `DeepBase.MRU`           | 自建 MRU 列表            |
| 快捷�?         | `DeepBase.Hotkeys`       | 硬编码快捷键             |
| 数据库访�?     | `DeepBase.DB.DoQry` 或公�?uDM 封装 | �?SQL 字符串拼�? |
| GUI 测试        | `DeepBase.TestHelper`    | 自建 GUI 测试框架        |

**搜索示例（AI 应自动执行）�?*

```bash
# 搜索配置读取
grep -r "GetConfig\|GetConfigInt" --include="*.pas" .

# 搜索已有 HTTP 封装
grep -r "THTTPClient\|class.*HTTP" --include="*.pas" .

# 搜索工具�?
grep -r "UT.*Utils\|BT.*Helper" --include="*.pas" .

# 搜索数据库访问模�?
grep -r "DoQry\|ExecSQL" --include="*.pas" .
```

---

## 6. 测试与自动化要求（给 AI 的硬约束�?

1. **修改业务逻辑 �?必须检�?补充 DUnitX 测试**
   - 测试放在 `Tests/` 目录，遵�?`Test.<模块�?.pas` 命名�?
   - 每个公开方法至少有一个成功用例和一个失�?边界用例�?

2. **命令行构建和测试**（不要只依赖 IDE）：

```batch
call "C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\bin\\rsvars.bat"
msbuild Tests\\DeepBaseTests.dproj /t:Build /p:Config=Debug /p:Platform=Win32
Tests\\Win32\\Debug\\DeepBaseTests.exe --xmloutput=TestResults.xml --exitbehavior=Continue
```

3. **每个应用都要有测�?GUI**（见 `docs/07.03.DeepBase-4H-安全与测�?v1.0.md`）：
   - 工程名形�?`MyApp.TestGUI.dpr`�?
   - 通过按钮/Tab 触发关键业务流程，复用正�?Frame �?Controller�?
   - 人工回归时，只需点击测试 GUI 即可验证主要功能�?

4. **自动化纠错流�?*（当测试或编译失败时）：
   - 收集完整错误输出（含文件、行号、错误码）；
   - 搜索项目中类似正确用法；
   - 给出最小修改方案；
   - 再次运行构建+测试，直至通过�?

详见：`docs/07.03.DeepBase-4H-安全与测�?v1.0.md`�?

---

## 7. AI 行为红线（必须遵守）

AI 在本仓库�?**绝对禁止**�?

- 新增 INI/Registry/随机 JSON 文件作为配置来源�?
- 在任何地方硬编码中文/英文用户提示文本�?
- 直接使用 `Application.ProcessMessages` 循环�?`TThread.Synchronize`�?
- �?View 中直接创建和执行 `TFDQuery.ExecSQL`�?
- �?DataModule 中引�?`Vcl.Forms`/`Dialogs` 或直接操�?UI�?
- 引入全局变量保存业务状态（当前用户/订单等）�?

AI 必须�?

- 先搜索现有实现，再决定是否写新代码；
- 复用 `Core/`、`VCL/`、`FMX/` 中已存在的模块和模式�?
- 遵守 `docs/01`、`02`、`07`、`08`、`09` 中的所有分层与安全约束�?
- 在回答中说明�?
  - 复用了哪些现有模块；
  - 新增了哪些最小必要改动；
  - 如何编译与测试这些改动�?

---

## 8. 推荐阅读顺序（AI & 新开发者）

1. 本文�?`ARCH-QUICKSTART.md`
2. `docs/README.md`（总览与角色导读）
3. `docs/01.03.DeepBase-4H-项目定位与边�?v1.0.md`
4. `docs/03.03.DeepBase-4H-技术规�?v1.0.md`
5. `docs/02.quickstart.下游接入流程-downstream-integration.md`
6. `docs/07.03.DeepBase-4H-安全与测�?v1.0.md`
7. `docs/84.ops.集成检查清单-integration-checklist�?v1.0.md`
8. `docs/83.ops.FAQ与错误速查-faq-troubleshooting.md`

之后再根据需要查阅：

- API 细节：`docs/05.01.DeepBase-4AI-API参�?v1.0.md`
- 数据库：`docs/04.03.DeepBase-4AI-数据库指�?v1.0.md`, `docs/41.api.DoQry指南-doqry-guide.md`
- UI 设计：`docs/ui/*`

---

> �?AI：如果不确定某项修改是否符合规范，请**优先搜索并引用上述文�?*中的相关章节，再给出修改建议或代码实现�?
