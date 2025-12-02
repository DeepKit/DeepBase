# LLM 提示词系统集成指南

本文档指导其他程序如何集成 UniBase 的 LLM 提示词管理系统。

## 1. 系统概述

### 1.1 核心概念

| 概念 | 说明 |
|------|------|
| **提示词 (Prompt)** | 发送给 LLM 的指令模板，支持变量占位符 |
| **元提示词 (MetaPrompt)** | 提示词的前缀/后缀约束，如安全规则、输出格式 |
| **版本 (Version)** | 每个提示词最多4个版本，一个为生产版本 |
| **LLM配置** | Provider + Model + API Key 的组合 |
| **BoundQuery** | 绑定 DoQry 查询，自动注入业务数据作为上下文 |

### 1.2 运行时三要素

提示词执行由三个因素确定：
```
最终执行 = 提示词(InternalCode) + 版本(V1-V4) + LLM配置(Provider/Model)
```

## 2. 集成步骤

### 2.1 引用单元

```pascal
uses
  UniBase.LLM.Manager,        // LLM 管理器 (包含类型定义)
  UniBase.LLM.ImportExport;   // 导入导出 (JSON/YAML)
```

### 2.2 初始化

```pascal
var
  LLMManager: TLLMManager;
begin
  // 创建 TLLMManager，传入数据库连接
  LLMManager := TLLMManager.Create(FConnection);
  LLMManager.Initialize;  // 加载缓存
end;
```

### 2.3 基础调用

```pascal
// 方式1：按内部编码调用（推荐）
var
  Response: TLLMResponse;
begin
  Response := LLMManager.Execute('01-01-001');  // 使用生产版本
  if Response.Success then
    ShowMessage(Response.Content)
  else
    ShowMessage('Error: ' + Response.ErrorMessage);
end;

// 方式2：带变量调用
var
  Params: TDictionary<string, Variant>;
begin
  Params := TDictionary<string, Variant>.Create;
  try
    Params.Add('customer_id', 10086);
    Params.Add('date_range', 'last_30_days');
    
    Response := LLMManager.Execute('01-01-001', Params);
  finally
    Params.Free;
  end;
end;

// 方式3：指定版本和LLM配置
Response := LLMManager.Execute(
  '01-01-001',           // 提示词编码
  Params,                // 变量
  3,                     // 使用版本3
  'OpenAI-GPT4'          // 使用指定的LLM配置名
);

// TLLMResponse 结构
// Response.Success       : Boolean  - 是否成功
// Response.Content       : string   - LLM返回内容
// Response.InputTokens   : Integer  - 输入Token数
// Response.OutputTokens  : Integer  - 输出Token数
// Response.TotalTokens   : Integer  - 总Token数
// Response.DurationMs    : Int64    - 耗时(ms)
// Response.Cost          : Double   - 费用
// Response.ErrorMessage  : string   - 错误信息
```

### 2.4 异步调用

```pascal
// 异步调用，不阻塞UI
LLMManager.ExecuteAsync(
  '01-01-001',
  Params,
  procedure(Response: TLLMResponse)
  begin
    // 回调在主线程执行
    if Response.Success then
      Memo1.Text := Response.Content;
  end
);
```

### 2.5 使用 BoundQuery 集成 DoQry

BoundQuery 允许提示词自动查询业务数据并注入到上下文中。

**步骤 1: 设置 ContextBuilder 回调**

```pascal
uses
  UniBase.DB.DoQry, System.JSON, DBClient;

// 创建 ContextBuilder 回调函数
function MyContextBuilder(const QueryName: string; 
  const Params: TDictionary<string, Variant>): string;
var
  Ctx: TUniQueryContext;
  Data: TClientDataSet;
  ParamsJson: string;
  JsonArray: TJSONArray;
begin
  Result := '';
  if QueryName = '' then Exit;
  
  // 将参数转为 JSON
  ParamsJson := ParamsToJson(Params);  // 自实现转换
  
  // 执行 DoQry 查询
  Ctx := UniDbMakeContext(FConnection, udbPostgreSQL);
  Data := TClientDataSet.Create(nil);
  try
    if UniDbSelect(QueryName, ParamsJson, Data, Ctx) > 0 then
    begin
      // 将 DataSet 转为 JSON
      JsonArray := DataSetToJson(Data);  // 自实现转换
      try
        Result := JsonArray.ToJSON;
      finally
        JsonArray.Free;
      end;
    end;
  finally
    Data.Free;
  end;
end;

// 初始化时设置回调
LLMManager.ContextBuilder := MyContextBuilder;
```

**步骤 2: 配置提示词绑定查询**

在提示词配置中设置 `BoundQueryName = 'qry_CustomerDetail'`

**步骤 3: 提示词内容使用 {{context}}**

```
你是客户服务分析助手。

客户数据：
{{context}}

请分析该客户的购买行为并提供建议。
```

**步骤 4: 调用执行**

```pascal
Params.Add('customer_id', 10086);  // 作为 DoQry SQL 参数
Response := LLMManager.Execute('01-01-001', Params);
// 系统自动：
// 1. 调用 ContextBuilder('qry_CustomerDetail', {customer_id: 10086})
// 2. 将返回的 JSON 注入到 {{context}} 变量
// 3. 合并元提示词
// 4. 发送给 LLM
```

## 3. 数据库表结构

### 3.1 提示词分类表 (PromptCategories)

```sql
CREATE TABLE PromptCategories (
    Id          INTEGER PRIMARY KEY AUTOINCREMENT,
    ParentId    INTEGER REFERENCES PromptCategories(Id),
    Level       INTEGER NOT NULL,        -- 1-4
    Code        TEXT NOT NULL,           -- 如 '01', '02'
    Name        TEXT NOT NULL,           -- 如 '系统提示词'
    Description TEXT,
    SortOrder   INTEGER DEFAULT 0,
    CreatedAt   TEXT DEFAULT CURRENT_TIMESTAMP
);
```

### 3.2 提示词表 (Prompts)

```sql
CREATE TABLE Prompts (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryId      INTEGER REFERENCES PromptCategories(Id),
    InternalCode    TEXT NOT NULL UNIQUE,  -- 如 '01-01-001'
    Name            TEXT NOT NULL,
    Description     TEXT,                  -- 用途说明
    BoundQueryName  TEXT,                  -- 绑定的 DoQry 查询名
    VariablesJson   TEXT,                  -- 变量定义 JSON
    IsActive        INTEGER DEFAULT 1,
    CreatedAt       TEXT DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt       TEXT
);
```

### 3.3 提示词版本表 (PromptVersions)

```sql
CREATE TABLE PromptVersions (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER NOT NULL REFERENCES Prompts(Id),
    VersionNumber   INTEGER NOT NULL,      -- 1-4
    Content         TEXT NOT NULL,         -- 提示词内容
    IsProduction    INTEGER DEFAULT 0,     -- 是否为生产版本
    TestCount       INTEGER DEFAULT 0,     -- 测试次数
    SuccessCount    INTEGER DEFAULT 0,     -- 成功次数
    TotalTokens     INTEGER DEFAULT 0,     -- 总Token数
    TotalCost       REAL DEFAULT 0,        -- 总费用
    AvgDuration     REAL DEFAULT 0,        -- 平均耗时(ms)
    LastTestedAt    TEXT,                  -- 最后测试时间
    LastResponse    TEXT,                  -- 最后一次LLM回复
    CreatedAt       TEXT DEFAULT (datetime('now', 'localtime')),
    UpdatedAt       TEXT,
    UNIQUE(PromptId, VersionNumber)
);
```

### 3.4 元提示词表 (PromptMeta)

```sql
CREATE TABLE PromptMeta (
    Id           INTEGER PRIMARY KEY AUTOINCREMENT,
    InternalCode TEXT NOT NULL UNIQUE,    -- 如 'META-001'
    Name         TEXT NOT NULL,
    Category     TEXT,                    -- security/format/role/domain
    Content      TEXT NOT NULL,
    MergeMode    TEXT DEFAULT 'PREFIX',   -- PREFIX/SUFFIX/WRAP
    Priority     INTEGER DEFAULT 100,
    IsActive     INTEGER DEFAULT 1,
    CreatedAt    TEXT DEFAULT CURRENT_TIMESTAMP
);
```

### 3.5 提示词-元提示词绑定表 (PromptMetaBinding)

```sql
CREATE TABLE PromptMetaBinding (
    PromptId     INTEGER REFERENCES Prompts(Id),
    MetaPromptId INTEGER REFERENCES PromptMeta(Id),
    OrderIndex   INTEGER DEFAULT 0,
    PRIMARY KEY (PromptId, MetaPromptId)
);
```

### 3.6 LLM配置表 (LLMConfigurations)

```sql
CREATE TABLE LLMConfigurations (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    Name            TEXT NOT NULL UNIQUE,   -- 配置名称
    Provider        TEXT NOT NULL,          -- LiteLLM/OpenAI/Azure/Anthropic
    Model           TEXT NOT NULL,          -- gpt-4o/claude-3/etc
    ApiUrl          TEXT,
    ApiKey          TEXT,                   -- 加密存储
    Temperature     REAL DEFAULT 0.7,
    MaxTokens       INTEGER DEFAULT 4096,
    Timeout         INTEGER DEFAULT 60000,
    RetryCount      INTEGER DEFAULT 3,
    InputPrice      REAL DEFAULT 0,         -- $/1K tokens
    OutputPrice     REAL DEFAULT 0,
    IsEnabled       INTEGER DEFAULT 1,
    IsDefault       INTEGER DEFAULT 0,      -- 是否默认配置
    CreatedAt       TEXT DEFAULT CURRENT_TIMESTAMP
);
```

### 3.7 LLM调用记录表 (LLMCalls)

```sql
CREATE TABLE LLMCalls (
    Id              INTEGER PRIMARY KEY AUTOINCREMENT,
    PromptId        INTEGER REFERENCES Prompts(Id),
    VersionNumber   INTEGER,
    ConfigId        INTEGER REFERENCES LLMConfigurations(Id),
    InputTokens     INTEGER,
    OutputTokens    INTEGER,
    Duration        INTEGER,                -- 耗时(ms)
    Cost            REAL,                   -- 费用
    Status          TEXT,                   -- success/error/timeout
    ErrorMessage    TEXT,
    RequestHash     TEXT,                   -- 请求内容哈希(用于去重)
    CreatedAt       TEXT DEFAULT CURRENT_TIMESTAMP
);
```

## 4. 导入导出

### 4.1 导出格式 (JSON)

```json
{
  "version": "1.0",
  "exportDate": "2024-11-30T10:00:00Z",
  "prompts": [
    {
      "internalCode": "01-01-001",
      "name": "客户行为分析",
      "category": ["系统提示词", "通用", "分析"],
      "description": "用于分析客户行为数据",
      "boundQueryName": "qry_CustomerDetail",
      "variables": [
        {"name": "customer_id", "type": "Integer", "required": true},
        {"name": "date_range", "type": "String", "default": "last_30_days"}
      ],
      "metaPrompts": ["META-001", "META-003"],
      "versions": [
        {
          "number": 1,
          "content": "你是一个专业的分析师...",
          "isProduction": true
        }
      ]
    }
  ],
  "metaPrompts": [
    {
      "internalCode": "META-001",
      "name": "安全约束",
      "category": "security",
      "content": "你必须遵守以下规则...",
      "mergeMode": "PREFIX"
    }
  ]
}
```

### 4.2 导入导出 API

```pascal
uses UniBase.LLM.ImportExport;

var
  ImportExport: TLLMImportExport;
  Result: TImportResult;
begin
  ImportExport := TLLMImportExport.Create(LLMManager);
  try
    // 导出全部
    ImportExport.ExportPrompts('C:\backup\prompts.json', efJSON);
    ImportExport.ExportPrompts('C:\backup\prompts.yaml', efYAML);
    
    // 导出指定提示词
    ImportExport.ExportSelectedPrompts('C:\backup\selected.json', 
      ['01-01-001', '01-02-001'], efJSON);
    
    // 导入 (imMerge=合并, imReplace=替换, imOverwrite=覆盖)
    Result := ImportExport.ImportPrompts('C:\backup\prompts.json', imMerge);
    
    if Result.Success then
      ShowMessage(Result.Summary)
    else
      ShowMessage('导入失败: ' + String.Join(#13#10, Result.Errors));
  finally
    ImportExport.Free;
  end;
end;
```

## 5. Studio 集成

提示词管理界面由 UniBase Studio 提供：

- **LLM 配置窗口**: 管理 Provider/Model/API Key
- **提示词调试窗口**: 编辑、测试、发送提示词
- **版本对比窗口**: 对比4个版本的提示词和回复

应用程序只需调用 `LLMManager.Execute()` 即可使用，无需关心 UI。

## 6. 最佳实践

### 6.1 提示词编码规范

```
格式: XX-YY-ZZZ
  XX  = 一级分类编号 (01-99)
  YY  = 二级分类编号 (01-99)
  ZZZ = 序号 (001-999)

示例:
  01-01-001 = 系统/通用/第1个
  02-03-015 = 业务/报表/第15个
```

### 6.2 变量命名规范

```
使用 snake_case：customer_id, order_date, max_items
BoundQuery 变量使用前缀：context_data, query_result
```

### 6.3 错误处理

```pascal
Response := LLMManager.Execute('01-01-001', Params);

if Response.Success then
  ProcessResult(Response.Content)
else
begin
  // 根据错误码处理
  if Response.ErrorCode = 'timeout' then
    RetryOrNotify
  else if Response.ErrorCode = 'rate_limited' then
    WaitAndRetry
  else
    LogError(Response.ErrorMessage);
end;
```

## 7. 常见问题

**Q: 如何在运行时切换LLM配置？**
A: 修改 `LLMConfigurations.IsDefault` 字段，或在调用时指定配置名。

**Q: 如何知道提示词消耗了多少Token？**
A: `Response.InputTokens` 和 `Response.OutputTokens`，费用在 `Response.Cost`，耗时在 `Response.DurationMs`。

**Q: 元提示词修改后会影响哪些提示词？**
A: 查询 `PromptMetaBinding` 表获取绑定关系。
