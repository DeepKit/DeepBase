# 24. AI 开发完整上下文（给 AI 看）

> 📖 **本文件是 AI 辅助开发的技术上下文参考**
> 当 AI 需要为 UniBase 项目生成代码时，应首先阅读本文档以获取必要的架构和约定背景。

---

## 1. UniBase 框架概览

### 1.1 框架定位

UniBase 是一个 **Delphi 应用基础设施框架**，为桌面应用（VCL/FMX）提供：

- **配置管理**：基于 SQLite 的 config.db，统一存储应用配置
- **日志系统**：分级日志（DEBUG/INFO/WARN/ERROR/FATAL）
- **国际化**：多语言支持（i18n）
- **异常报告**：统一异常捕获与上报
- **查询框架**：doQry 系统，配置化 SQL 管理
- **安全模块**：敏感数据加密、完整性校验

### 1.2 核心设计原则

```
1. Manager 单例模式：所有基础设施通过 TxxxManager.Instance 访问
2. 配置驱动：行为通过 config.db 配置，非硬编码
3. 分层架构：UI → 业务 → 数据 → 基础设施
4. 复用优先：优先使用 UT/BT/DB/PG 公共库
5. 离线优先：支持无网络环境下的完整功能
```

### 1.3 目录结构

```
UniBase/
├── Core/           # 核心模块（Manager 类、基础服务）
├── VCL/            # VCL 平台相关
├── FMX/            # FMX 平台相关
├── Tools/          # 命令行工具与 Studio
├── Tests/          # 单元测试
├── docs/           # 文档（你正在读的）
│   └── V1.0版/     # 未来规划文档
├── migrations/     # Schema 迁移脚本
└── templates/      # 项目模板
```

---

## 2. 核心 Manager 组件

### 2.1 TConfigManager（配置管理）

```pascal
// 获取配置值
Value := TConfigManager.Instance.GetValue('Section', 'Key', 'DefaultValue');

// 设置配置值
TConfigManager.Instance.SetValue('Section', 'Key', 'Value');

// 获取/设置加密配置
Password := TConfigManager.Instance.GetSecureValue('DB', 'Password');
TConfigManager.Instance.SetSecureValue('DB', 'Password', APassword);

// 配置存储在 config.db 的 Settings 表
// 结构：ID, Section, Key, Value, ValueType, IsEncrypted, Description
```

### 2.2 TLogManager（日志管理）

```pascal
// 日志级别：DEBUG < INFO < WARN < ERROR < FATAL
TLogManager.Instance.LogDebug('调试信息');
TLogManager.Instance.LogInfo('常规信息');
TLogManager.Instance.LogWarn('警告信息');
TLogManager.Instance.LogError('错误信息');
TLogManager.Instance.LogFatal('致命错误');

// 带异常的日志
TLogManager.Instance.LogException(E, '上下文描述');

// 日志存储在 config.db 的 Logs 表
// 结构：ID, Timestamp, Level, Message, Source, StackTrace
```

### 2.3 TLanguageManager（国际化）

```pascal
// 获取翻译文本
Caption := TLanguageManager.Instance.GetText('BTN_SAVE');
// 返回当前语言的 "保存" 或 "Save"

// 带参数的翻译
Msg := TLanguageManager.Instance.GetText('MSG_WELCOME', [UserName]);
// 模板：'欢迎，%s！' → '欢迎，张三！'

// 切换语言
TLanguageManager.Instance.SetLanguage('en-US');

// 翻译存储在 config.db 的 Languages/Translations 表
```

### 2.4 TExceptionReporter（异常报告）

```pascal
// 自动全局异常捕获（在 Application 初始化时设置）
Application.OnException := TExceptionReporter.Instance.HandleException;

// 手动报告异常
try
  DoSomething;
except
  on E: Exception do
    TExceptionReporter.Instance.ReportException(E, '操作上下文');
end;

// 异常报告存储在 config.db 的 ExceptionReports 表
```

### 2.5 TQueryManager / doQry（查询框架）

```pascal
// 执行命名查询
DataSet := TQueryManager.Instance.Execute('GetCustomerById', ['Id', CustomerId]);

// 查询定义存储在 config.db 的 QueryDefinitions 表
// 结构：ID, QueryName, SQL, ConnectionName, Description, Parameters

// 连接配置存储在 Connections 表
// 结构：ID, ConnectionName, ConnectionType, ConnectionString, IsEncrypted
```

---

## 3. 公共库单元前缀约定

### 3.1 UT* - 通用工具（Universal Tools）

无业务依赖，纯工具函数：

```pascal
// 示例单元：
UTString     // 字符串处理：格式化、编码、解析
UTMath       // 数学计算：精度运算、统计函数
UTFile       // 文件操作：读写、路径处理
UTDateTime   // 日期时间：格式化、计算、时区
UTJson       // JSON 处理：序列化、反序列化
UTCrypto     // 加密解密：哈希、对称/非对称加密
```

### 3.2 BT* - 基础工具（Base Tools）

可依赖 UT*，提供基础业务支持：

```pascal
// 示例单元：
BTException  // 异常处理：自定义异常类、堆栈跟踪
BTValidation // 数据验证：规则引擎、校验器
BTThread     // 线程辅助：线程池、任务调度
BTProcess    // 进程管理：子进程启动、IPC
BTNetwork    // 网络工具：HTTP 客户端、连接检测
```

### 3.3 DB* - 数据库访问（Database）

数据库相关功能：

```pascal
// 示例单元：
DBConnection  // 连接管理：连接池、事务
DBRepository  // 仓储模式：CRUD 基类
DBCache       // 数据缓存：查询缓存、失效策略
DBMigration   // Schema 迁移：版本管理、脚本执行
```

### 3.4 PG* - PostgreSQL 专用

PostgreSQL 特有功能：

```pascal
// 示例单元：
PGQueue       // 消息队列：LISTEN/NOTIFY
PGSearch      // 全文搜索：tsvector/tsquery
PGTimeSeries  // 时序数据：TimescaleDB 集成
PGJson        // JSONB 操作：查询、索引
```

---

## 4. config.db Schema 概览

### 4.1 核心表结构

```sql
-- 应用基本信息
CREATE TABLE ProjectInfo (
    ID INTEGER PRIMARY KEY,
    ProjectName TEXT NOT NULL,
    Version TEXT,
    UniBaseVersion TEXT,
    CreatedAt TEXT,
    UpdatedAt TEXT
);

-- 配置存储
CREATE TABLE Settings (
    ID INTEGER PRIMARY KEY,
    Section TEXT NOT NULL,
    Key TEXT NOT NULL,
    Value TEXT,
    ValueType TEXT DEFAULT 'string',  -- string/integer/boolean/json
    IsEncrypted INTEGER DEFAULT 0,
    Description TEXT,
    UNIQUE(Section, Key)
);

-- 日志记录
CREATE TABLE Logs (
    ID INTEGER PRIMARY KEY,
    Timestamp TEXT NOT NULL,
    Level TEXT NOT NULL,  -- DEBUG/INFO/WARN/ERROR/FATAL
    Message TEXT,
    Source TEXT,
    StackTrace TEXT
);

-- 异常报告
CREATE TABLE ExceptionReports (
    ID INTEGER PRIMARY KEY,
    Timestamp TEXT NOT NULL,
    ExceptionClass TEXT,
    Message TEXT,
    StackTrace TEXT,
    Context TEXT,
    UserAction TEXT,
    IsSent INTEGER DEFAULT 0
);

-- 查询定义
CREATE TABLE QueryDefinitions (
    ID INTEGER PRIMARY KEY,
    QueryName TEXT NOT NULL UNIQUE,
    SQL TEXT NOT NULL,
    ConnectionName TEXT,
    Description TEXT,
    Parameters TEXT,  -- JSON 格式
    IsActive INTEGER DEFAULT 1
);

-- 数据库连接
CREATE TABLE Connections (
    ID INTEGER PRIMARY KEY,
    ConnectionName TEXT NOT NULL UNIQUE,
    ConnectionType TEXT NOT NULL,  -- SQLite/PostgreSQL/MySQL
    ConnectionString TEXT NOT NULL,
    IsEncrypted INTEGER DEFAULT 0,
    IsDefault INTEGER DEFAULT 0
);

-- 国际化
CREATE TABLE Languages (
    ID INTEGER PRIMARY KEY,
    LanguageCode TEXT NOT NULL UNIQUE,  -- zh-CN, en-US
    LanguageName TEXT NOT NULL,
    IsDefault INTEGER DEFAULT 0
);

CREATE TABLE Translations (
    ID INTEGER PRIMARY KEY,
    LanguageCode TEXT NOT NULL,
    Key TEXT NOT NULL,
    Value TEXT NOT NULL,
    UNIQUE(LanguageCode, Key)
);

-- Schema 版本
CREATE TABLE SchemaInfo (
    ID INTEGER PRIMARY KEY,
    SchemaVersion INTEGER NOT NULL,
    AppliedAt TEXT NOT NULL
);

CREATE TABLE SchemaMigrations (
    ID INTEGER PRIMARY KEY,
    Version TEXT NOT NULL,
    ScriptName TEXT NOT NULL,
    Checksum TEXT,
    AppliedAt TEXT NOT NULL,
    Success INTEGER DEFAULT 1
);
```

---

## 5. 异常类型体系

### 5.1 异常继承结构

```pascal
Exception
└── EUniBaseException              // UniBase 基类异常
    ├── EUniBaseConfigException    // 配置相关（100-199）
    │   ├── EConfigKeyNotFound     // 配置键不存在
    │   ├── EConfigTypeMismatch    // 配置类型不匹配
    │   └── EConfigEncryptError    // 加密/解密失败
    │
    ├── EUniBaseDBException        // 数据库相关（200-299）
    │   ├── EDBConnectionFailed    // 连接失败
    │   ├── EDBQueryError          // 查询执行错误
    │   ├── EDBMigrationError      // 迁移执行错误
    │   └── EDBTransactionError    // 事务错误
    │
    ├── EUniBaseIOException        // 文件/IO相关（300-399）
    │   ├── EFileNotFound          // 文件不存在
    │   ├── EFileAccessDenied      // 访问被拒绝
    │   └── EPathTooLong           // 路径过长
    │
    ├── EUniBaseNetworkException   // 网络相关（400-499）
    │   ├── ENetworkTimeout        // 网络超时
    │   ├── ENetworkUnreachable    // 网络不可达
    │   └── EAPICallFailed         // API 调用失败
    │
    └── EUniBaseValidationException // 验证相关（500-599）
        ├── ERequiredFieldMissing  // 必填字段缺失
        ├── EInvalidFormat         // 格式无效
        └── EValueOutOfRange       // 值超出范围
```

### 5.2 异常使用示例

```pascal
// 抛出配置异常
if not TConfigManager.Instance.KeyExists('Section', 'Key') then
  raise EConfigKeyNotFound.CreateFmt('配置键不存在: %s.%s', [Section, Key]);

// 抛出数据库异常
try
  FDQuery.Open;
except
  on E: Exception do
    raise EDBQueryError.Create('查询执行失败: ' + E.Message);
end;

// 抛出验证异常
if CustomerName.IsEmpty then
  raise ERequiredFieldMissing.Create('客户名称不能为空');
```

---

## 6. 代码生成模板

### 6.1 新建 Manager 类模板

```pascal
unit UMyFeatureManager;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs,
  UConfigManager, ULogManager;

type
  TMyFeatureManager = class
  private
    class var FInstance: TMyFeatureManager;
    class var FLock: TCriticalSection;
  private
    FInitialized: Boolean;
    procedure Initialize;
  public
    class function Instance: TMyFeatureManager;
    class procedure ReleaseInstance;
    
    // 业务方法
    procedure DoSomething;
  end;

implementation

{ TMyFeatureManager }

class function TMyFeatureManager.Instance: TMyFeatureManager;
begin
  if not Assigned(FInstance) then
  begin
    FLock.Enter;
    try
      if not Assigned(FInstance) then
      begin
        FInstance := TMyFeatureManager.Create;
        FInstance.Initialize;
      end;
    finally
      FLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TMyFeatureManager.ReleaseInstance;
begin
  FLock.Enter;
  try
    FreeAndNil(FInstance);
  finally
    FLock.Leave;
  end;
end;

procedure TMyFeatureManager.Initialize;
begin
  if FInitialized then Exit;
  // 初始化逻辑
  TLogManager.Instance.LogInfo('MyFeatureManager initialized');
  FInitialized := True;
end;

procedure TMyFeatureManager.DoSomething;
begin
  // 业务实现
end;

initialization
  TMyFeatureManager.FLock := TCriticalSection.Create;

finalization
  TMyFeatureManager.ReleaseInstance;
  TMyFeatureManager.FLock.Free;

end.
```

### 6.2 新建服务类模板

```pascal
unit SvcCustomer;

interface

uses
  System.SysUtils, System.Generics.Collections,
  UQueryManager, ULogManager,
  EntityCustomer;  // 实体定义

type
  TCustomerService = class
  private
    FQueryManager: TQueryManager;
  public
    constructor Create;
    
    function GetById(AId: Integer): TCustomer;
    function GetAll: TObjectList<TCustomer>;
    procedure Save(ACustomer: TCustomer);
    procedure Delete(AId: Integer);
  end;

implementation

{ TCustomerService }

constructor TCustomerService.Create;
begin
  inherited;
  FQueryManager := TQueryManager.Instance;
end;

function TCustomerService.GetById(AId: Integer): TCustomer;
var
  LDataSet: TDataSet;
begin
  Result := nil;
  LDataSet := FQueryManager.Execute('GetCustomerById', ['Id', AId]);
  try
    if not LDataSet.IsEmpty then
      Result := TCustomer.CreateFromDataSet(LDataSet);
  finally
    LDataSet.Free;
  end;
end;

// ... 其他方法实现

end.
```

### 6.3 新建 Form 模板

```pascal
unit FrmCustomerList;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, Vcl.DBGrids,
  Data.DB,
  ULanguageManager, ULogManager,
  SvcCustomer;

type
  TfrmCustomerList = class(TForm)
    DBGrid1: TDBGrid;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FService: TCustomerService;
    FLang: TLanguageManager;
    procedure LoadData;
    procedure ApplyLanguage;
  public
  end;

implementation

{$R *.dfm}

procedure TfrmCustomerList.FormCreate(Sender: TObject);
begin
  FService := TCustomerService.Create;
  FLang := TLanguageManager.Instance;
  ApplyLanguage;
  LoadData;
end;

procedure TfrmCustomerList.FormDestroy(Sender: TObject);
begin
  FService.Free;
end;

procedure TfrmCustomerList.ApplyLanguage;
begin
  Caption := FLang.GetText('FRM_CUSTOMER_LIST_TITLE');
  // 其他控件翻译
end;

procedure TfrmCustomerList.LoadData;
begin
  try
    // 通过服务层加载数据
    // FService.GetAll...
  except
    on E: Exception do
    begin
      TLogManager.Instance.LogException(E, 'LoadData');
      ShowMessage(FLang.GetText('ERR_LOAD_FAILED'));
    end;
  end;
end;

end.
```

---

## 7. 文档导航

当需要更详细的信息时，参考以下文档：

| 主题 | 文档 | 说明 |
|------|------|------|
| 架构总览 | `00_UniBase架构与核心理念.md` | 设计思想和整体架构 |
| 开发规范 | `01_项目开发规范与标准.md` | 命名、注释、目录结构 |
| 最佳实践 | `02_UniBase最佳实践指南.md` | 推荐的开发模式 |
| API 参考 | `14.api-reference.md` | Manager 类完整 API |
| doQry 指南 | `16.doQry-development-guide.md` | 查询框架使用 |
| 测试指南 | `07_测试与自动化指南.md` | 单元测试编写 |
| AI 约束 | `V1.0版/23_AI编码硬约束-强约束AI.md` | **必须遵守的规则** |
| 常见陷阱 | `09_Delphi架构陷阱防范.md` | 避免的错误模式 |

---

## 8. AI 开发工作流

### 8.1 接收任务后

```
1. 阅读任务描述，明确需求
2. 检查是否有类似功能已实现（搜索代码库）
3. 确认涉及的 Manager/Service/Entity
4. 规划实现方案（必要时询问确认）
```

### 8.2 编码前

```
1. 搜索 UT/BT/DB/PG 单元，确认无可复用代码
2. 确认分层归属（这是 UI/Service/Data/Infrastructure？）
3. 确认命名前缀（新单元应用什么前缀？）
4. 阅读 23_AI编码硬约束-强约束AI.md 的检查清单
```

### 8.3 编码中

```
1. 使用框架提供的 Manager，不自行实现基础功能
2. 所有用户可见文本使用 LanguageManager
3. 所有配置使用 ConfigManager
4. 所有日志使用 LogManager
5. 异常使用 UniBase 异常体系
6. 对象创建后确保有释放机制
```

### 8.4 编码后

```
1. 执行 23_AI编码硬约束 中的自检清单
2. 附加自检声明
3. 提供简要说明（做了什么、为什么这样做）
```

---

## 9. 常见问题快速参考

### Q: 如何读取配置？
```pascal
Value := TConfigManager.Instance.GetValue('Section', 'Key', 'Default');
```

### Q: 如何记录日志？
```pascal
TLogManager.Instance.LogInfo('消息');
TLogManager.Instance.LogException(E, '上下文');
```

### Q: 如何获取翻译文本？
```pascal
Text := TLanguageManager.Instance.GetText('KEY');
```

### Q: 如何执行数据库查询？
```pascal
DataSet := TQueryManager.Instance.Execute('QueryName', ['Param', Value]);
```

### Q: 如何报告异常？
```pascal
TExceptionReporter.Instance.ReportException(E, '上下文');
```

### Q: 新功能应该放在哪个层？
```
- 纯工具函数 → UT*.pas
- 基础支持（可依赖UT）→ BT*.pas
- 数据库相关 → DB*.pas
- PostgreSQL专用 → PG*.pas
- 业务服务 → Svc*.pas
- 界面 → Frm*.pas / UI*.pas
```

---

> 📌 **本文档为 AI 提供开发上下文，配合 `23_AI编码硬约束-强约束AI.md` 使用**
