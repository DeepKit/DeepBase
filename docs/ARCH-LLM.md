# UniBase LLM 模块架构

## 概述

UniBase LLM 模块提供完整的 LLM（大语言模型）集成和 Prompt 管理能力，支持：

- **多 Provider 支持**：OpenAI、Azure、Claude、本地模型等
- **Prompt 版本管理**：每个提示词最多 4 个版本，支持 A/B 测试
- **元提示词合并**：PREFIX/SUFFIX/WRAP 三种模式
- **变量模板**：`{{variable}}` 语法，支持 BoundQuery 上下文注入
- **调用统计**：Token 用量、成本、成功率追踪

## 核心组件

```
UniBase.LLM.pas           - LLM 客户端抽象层
UniBase.LLM.Manager.pas   - Prompt 管理器
UniBase.LLM.ImportExport.pas - 导入导出工具
```

## 数据模型

### 1. PromptCategories（提示词分类）

4 级树形分类结构：

| 字段 | 类型 | 说明 |
|-----|------|------|
| Id | INTEGER | 主键 |
| ParentId | INTEGER | 父分类ID |
| Level | INTEGER | 层级 (1-4) |
| Code | TEXT | 分类代码 |
| Name | TEXT | 分类名称 |

### 2. Prompts（提示词主表）

| 字段 | 类型 | 说明 |
|-----|------|------|
| Id | INTEGER | 主键 |
| CategoryId | INTEGER | 所属分类 |
| InternalCode | TEXT | 内部编码，如 `SYS-TRANS-001` |
| Name | TEXT | 显示名称 |
| BoundQueryName | TEXT | 绑定的 DoQry 查询名 |
| VariablesJson | TEXT | 变量定义 JSON |

### 3. PromptVersions（版本管理）

每个提示词最多 4 个版本，支持 A/B 测试：

| 字段 | 类型 | 说明 |
|-----|------|------|
| PromptId | INTEGER | 所属提示词 |
| VersionNumber | INTEGER | 版本号 (1-4) |
| Content | TEXT | 提示词内容 |
| IsProduction | INTEGER | 是否为生产版本 |
| TestCount | INTEGER | 测试次数 |
| SuccessCount | INTEGER | 成功次数 |
| TotalTokens | INTEGER | 累计 Token |
| TotalCost | REAL | 累计成本 |

### 4. PromptMeta（元提示词）

可复用的提示词片段：

| 字段 | 类型 | 说明 |
|-----|------|------|
| InternalCode | TEXT | 内部编码，如 `META-SEC-001` |
| Category | TEXT | 类别：SECURITY/FORMAT/ROLE/DOMAIN/QUALITY |
| Content | TEXT | 内容 |
| MergeMode | TEXT | 合并模式：PREFIX/SUFFIX/WRAP |
| Priority | INTEGER | 合并优先级 |
| Level | INTEGER | 0=框架级, 1=项目级 |

### 5. PromptMetaBinding（绑定关系）

提示词与元提示词的多对多关系。

## 使用示例

### 1. 基本使用

```pascal
var
  LLMManager: TLLMManager;
  Response: TLLMResponse;
  Params: TDictionary<string, Variant>;
begin
  LLMManager := TLLMManager.Create(Connection);
  try
    LLMManager.Initialize;
    
    // 创建参数
    Params := TDictionary<string, Variant>.Create;
    try
      Params.Add('target_lang', 'English');
      Params.Add('text', '你好，世界！');
      
      // 执行提示词（使用生产版本）
      Response := LLMManager.Execute('SYS-TRANS-001', Params);
      
      if Response.Success then
        ShowMessage(Response.Content);
    finally
      Params.Free;
    end;
  finally
    LLMManager.Free;
  end;
end;
```

### 2. 版本测试

```pascal
// 测试特定版本
Response := LLMManager.TestVersion('SYS-TRANS-001', 2, Params, 'OpenAI');

// 比较多个版本
var Responses := LLMManager.CompareVersions('SYS-TRANS-001', [1, 2, 3], Params);
for var R in Responses do
  WriteLn(Format('V%d: %d tokens, %.2f cost', [R.VersionNumber, R.TotalTokens, R.Cost]));
```

### 3. 预览最终提示词

```pascal
// 构建最终提示词（含元提示词合并和变量替换）
var FinalPrompt := LLMManager.BuildFinalPrompt('SYS-TRANS-001', Params, 1);
Memo1.Text := FinalPrompt;
```

## 元提示词合并

### PREFIX 模式
```
[Meta Content]
[Prompt Content]
```

### SUFFIX 模式
```
[Prompt Content]
[Meta Content]
```

### WRAP 模式
```
[Meta Before {{content}}]
[Prompt Content]
[Meta After {{content}}]
```

## 变量语法

提示词内容支持 `{{variable}}` 变量占位符：

```
请将以下{{source_lang}}文本翻译为{{target_lang}}：
{{text}}
```

变量定义 JSON 格式：
```json
[
  {"name": "source_lang", "type": "string", "description": "源语言", "required": false},
  {"name": "target_lang", "type": "string", "description": "目标语言", "required": true},
  {"name": "text", "type": "string", "description": "待翻译文本", "required": true}
]
```

支持的类型：`string`, `number`, `boolean`, `date`, `datetime`, `list`, `json`

## BoundQuery 上下文注入

通过绑定 DoQry 查询，可以在执行时动态注入上下文：

```pascal
// 设置上下文构建器
LLMManager.ContextBuilder := function(QueryName: string; Params: TDictionary<string, Variant>): string
begin
  Result := DoQry.Execute(QueryName, Params).AsJSON;
end;

// 提示词中使用 {{context}} 引用查询结果
```

## LLM 配置

`LLMConfiguration` 表存储 Provider 配置：

| 字段 | 说明 |
|-----|------|
| ConfigName | 配置名称 |
| Provider | 提供商：OpenAI/Azure/Claude/Local |
| ApiUrl | API 端点 |
| ApiKey | API 密钥（加密存储） |
| Model | 模型名称 |
| ContextWindow | 上下文窗口大小 |
| PricePer1kPrompt | 每千 Token 输入成本 |
| PricePer1kCompletion | 每千 Token 输出成本 |

## 调用记录

`LLMCalls` 表记录所有 LLM 调用：

- 请求/响应内容
- Token 用量
- 耗时和成本
- 状态和错误信息
- 关联的 Prompt 和版本

## 最佳实践

1. **分类规划**：先规划好 4 级分类树，保持 Code 命名一致性
2. **版本策略**：V1 为稳定版，V2-V4 用于迭代测试
3. **元提示词**：抽取通用约束（安全、格式等）为元提示词复用
4. **成本监控**：定期检查 `LLMCalls` 统计成本
5. **A/B 测试**：对比不同版本的成功率和 Token 效率
