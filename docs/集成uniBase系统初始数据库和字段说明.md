# 集成 UniBase 系统初始数据库和字段说明

> 版本: 1.0.0  
> 更新日期: 2025-12-05

## 概述

UniBase 提供了一套完整的基础设施数据库，包含 **23 张表**，分为三个层级：

- **Tier 0 - 核心必需 (5张)**: 框架运行必需的表
- **Tier 1 - 推荐使用 (7张)**: 常用功能支撑表
- **Tier 2 - 扩展功能 (11张)**: LLM、异常报告等高级功能

### 设计原则

1. **字段冗余优先** - 宁可多建字段，也不要后期频繁修改表结构
2. **两个兜底字段** - 每张表都有 `Extra TEXT` (JSON扩展) 和 `Remarks TEXT` (备注)
3. **首次初始化创建全部** - 三层表在首次使用时一次性创建，包括 LLM 相关表
4. **UTF-8 支持** - 完整支持中文和多语言
5. **英文字段名 + i18n 显示** - 字段名用英文，界面显示通过 i18n 翻译

### 样例数据库

位置: `UniBase\data\样例Config.db`

此数据库包含完整的表结构、索引、约束和示例数据。集成程序可直接复制使用，在产品交付前删除不需要的表。

---

## 表结构详细说明

### Tier 0 - 核心必需表 (5张)

#### 1. SchemaInfo - 数据库版本管理
存储数据库元信息，用于版本管理和升级检测。

| 字段 | 类型 | 说明 |
|------|------|------|
| Key | TEXT | 主键，元信息键名 |
| Value | TEXT | 元信息值 |
| Extra | TEXT | JSON扩展字段 |
| Remarks | TEXT | 备注 |

预置数据:
- `SchemaVersion` - 架构版本号 (如 "1.0.0")
- `UniBaseVersion` - UniBase版本号
- `CreatedAt` - 创建时间

---

#### 2. Settings - 应用配置存储
键值对形式存储应用程序配置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Key | TEXT | - | 主键，配置项名称 |
| Value | TEXT | - | 配置值 |
| ValueType | TEXT | 'String' | 值类型: String/Integer/Boolean/Float/Json |
| Category | TEXT | 'General' | 分类: General/UI/LLM/Network等 |
| Description | TEXT | - | 配置项描述 |
| DefaultValue | TEXT | - | 默认值 |
| IsEncrypted | INTEGER | 0 | 是否加密存储 |
| IsReadOnly | INTEGER | 0 | 是否只读 |
| IsSystem | INTEGER | 0 | 是否系统配置 |
| SortOrder | INTEGER | 0 | 排序序号 |
| CreatedAt | TEXT | now() | 创建时间 |
| UpdatedAt | TEXT | now() | 更新时间 |
| Extra | TEXT | - | JSON扩展字段 |
| Remarks | TEXT | - | 备注 |

预置配置:
- `App.Language` - 应用语言
- `App.Theme` - 主题
- `LLM.DefaultProvider` - 默认LLM提供商
- `LLM.DefaultModel` - 默认模型

---

#### 3. FormStates - 窗口状态持久化
保存窗口位置、大小和状态。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| FormName | TEXT | - | 主键，窗口名称 |
| Left | INTEGER | - | X坐标 |
| Top | INTEGER | - | Y坐标 |
| Width | INTEGER | - | 宽度 |
| Height | INTEGER | - | 高度 |
| WindowState | INTEGER | 0 | 窗口状态: 0=正常,1=最小化,2=最大化 |
| MonitorIndex | INTEGER | 0 | 显示器索引 |
| Splitters | TEXT | - | 分隔条位置 (JSON) |
| Columns | TEXT | - | 列宽 (JSON) |
| TabIndex | INTEGER | 0 | 当前标签页 |
| ScrollPos | TEXT | - | 滚动位置 (JSON) |
| LastAccess | TEXT | - | 最后访问时间 |
| Extra | TEXT | - | JSON扩展字段 |
| Remarks | TEXT | - | 备注 |

---

#### 4. Languages - 支持的语言定义
定义应用支持的语言列表。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| LangCode | TEXT | - | 主键，语言代码 (如 zh-CN) |
| LangName | TEXT | - | 语言名称 (英文) |
| NativeName | TEXT | - | 本地名称 (如 "简体中文") |
| FlagIcon | TEXT | - | 国旗图标名 |
| DateFormat | TEXT | - | 日期格式 |
| TimeFormat | TEXT | - | 时间格式 |
| NumberFormat | TEXT | - | 数字格式 |
| CurrencySymbol | TEXT | - | 货币符号 |
| TextDirection | TEXT | 'LTR' | 文本方向: LTR/RTL |
| FontFamily | TEXT | - | 推荐字体 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsDefault | INTEGER | 0 | 是否默认语言 |
| IsComplete | INTEGER | 0 | 翻译是否完整 |
| SortOrder | INTEGER | 0 | 排序 |
| Extra | TEXT | - | JSON扩展字段 |
| Remarks | TEXT | - | 备注 |

预置语言: en-US, zh-CN, zh-TW, ja-JP, ko-KR, de-DE, fr-FR, es-ES

---

#### 5. I18nTexts - 翻译文本
存储界面文本的多语言翻译。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| SourceText | TEXT | - | 源文本 (英文) |
| LangCode | TEXT | - | 目标语言代码 |
| TranslatedText | TEXT | - | 翻译文本 |
| Context | TEXT | - | 上下文提示 |
| Module | TEXT | - | 所属模块 |
| IsAutoTranslated | INTEGER | 0 | 是否机器翻译 |
| IsVerified | INTEGER | 0 | 是否已校验 |
| LastUsedAt | TEXT | - | 最后使用时间 |
| Extra | TEXT | - | JSON扩展字段 |
| Remarks | TEXT | - | 备注 |

索引: `idx_i18n_lang`, `idx_i18n_source`, `idx_i18n_module`  
唯一约束: `UNIQUE(SourceText, LangCode)`

---

### Tier 1 - 推荐使用表 (7张)

#### 6. Logs - 应用日志
记录应用程序运行日志。

| 字段 | 类型 | 说明 |
|------|------|------|
| Id | INTEGER | 主键 |
| LogTime | TEXT | 日志时间 |
| LogLevel | TEXT | 级别: DEBUG/INFO/WARN/ERROR/FATAL |
| Source | TEXT | 来源模块 |
| Message | TEXT | 日志消息 |
| ExceptionClass | TEXT | 异常类名 |
| ExceptionMessage | TEXT | 异常消息 |
| StackTrace | TEXT | 堆栈跟踪 |
| ThreadId | INTEGER | 线程ID |
| UserId | TEXT | 用户ID |
| SessionId | TEXT | 会话ID |
| MachineName | TEXT | 机器名 |
| Extra | TEXT | JSON扩展 |
| Remarks | TEXT | 备注 |

索引: `idx_logs_time`, `idx_logs_level`, `idx_logs_source`

---

#### 7. MRU - 最近使用项
记录最近使用的文件、项目等。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Category | TEXT | 'File' | 类别: File/Project/Database等 |
| ItemPath | TEXT | - | 项目路径 |
| DisplayName | TEXT | - | 显示名称 |
| IconIndex | INTEGER | 0 | 图标索引 |
| IsPinned | INTEGER | 0 | 是否置顶 |
| AccessCount | INTEGER | 1 | 访问次数 |
| LastAccess | TEXT | now() | 最后访问时间 |
| CreatedAt | TEXT | now() | 首次添加时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

唯一约束: `UNIQUE(Category, ItemPath)`

---

#### 8. Hotkeys - 快捷键配置
存储和管理键盘快捷键。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| ActionName | TEXT | - | 动作名称 (唯一) |
| Shortcut | TEXT | - | 当前快捷键 |
| DefaultShortcut | TEXT | - | 默认快捷键 |
| Category | TEXT | 'General' | 分类: File/Edit/View等 |
| Description | TEXT | - | 描述 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsGlobal | INTEGER | 0 | 是否全局热键 |
| IsCustom | INTEGER | 0 | 是否用户自定义 |
| SortOrder | INTEGER | 0 | 排序 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置快捷键: Ctrl+N/O/S/W, Ctrl+Z/Y/X/C/V, F1, F5 等

---

#### 9. Queries - 预定义查询 (doQry支撑)
存储预定义的SQL查询，支持 doQry 功能。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Name | TEXT | - | 查询名称 (唯一) |
| Category | TEXT | 'General' | 分类 |
| Description | TEXT | - | 描述 |
| SqlText | TEXT | - | SQL语句 |
| ConnectionName | TEXT | - | 数据库连接名 |
| Parameters | TEXT | - | 参数定义 (JSON) |
| ReturnType | TEXT | 'Dataset' | 返回类型: Dataset/Scalar/None |
| CacheSeconds | INTEGER | 0 | 缓存秒数 |
| IsSystem | INTEGER | 0 | 是否系统查询 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| SortOrder | INTEGER | 0 | 排序 |
| CreatedAt | TEXT | now() | 创建时间 |
| UpdatedAt | TEXT | now() | 更新时间 |
| CreatedBy | TEXT | - | 创建者 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

---

#### 10. Themes - UI主题
管理界面主题。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| ThemeName | TEXT | - | 主键，主题名称 |
| DisplayName | TEXT | - | 显示名称 |
| Description | TEXT | - | 描述 |
| StyleFile | TEXT | - | 样式文件路径 |
| PreviewImage | TEXT | - | 预览图路径 |
| IsDark | INTEGER | 0 | 是否深色主题 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| AccentColor | TEXT | - | 强调色 |
| BackgroundColor | TEXT | - | 背景色 |
| TextColor | TEXT | - | 文字色 |
| FontName | TEXT | - | 字体名 |
| FontSize | INTEGER | - | 字体大小 |
| SortOrder | INTEGER | 0 | 排序 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置主题: Windows, Windows11, Windows11Dark, Carbon, Aqua

---

#### 11. Categories - 通用分类表
通用的分类/枚举存储表，用于存放各种分类数据。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| GroupName | TEXT | - | 分组名称 (如 'Priority', 'Status') |
| Code | TEXT | - | 分类代码 |
| Name | TEXT | - | 分类名称 |
| Description | TEXT | - | 描述 |
| ParentCode | TEXT | - | 父级代码 (支持层级) |
| IconName | TEXT | - | 图标名 |
| Color | TEXT | - | 颜色值 |
| SortOrder | INTEGER | 0 | 排序 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| IsDefault | INTEGER | 0 | 是否默认选项 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

唯一约束: `UNIQUE(GroupName, Code)`

预置分类组:
- **Priority**: low, normal, high, urgent
- **Status**: draft, pending, active, completed, archived
- **LogLevel**: debug, info, warn, error, fatal

使用示例:
```sql
-- 获取优先级列表
SELECT * FROM Categories WHERE GroupName = 'Priority' ORDER BY SortOrder;

-- 添加自定义状态
INSERT INTO Categories (GroupName, Code, Name, IsBuiltIn) 
VALUES ('Status', 'review', 'Under Review', 0);
```

---

#### 12. Tags - 标签系统
通用标签表，支持为任意实体添加标签。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| GroupName | TEXT | 'Default' | 标签分组 |
| Name | TEXT | - | 标签名称 |
| Description | TEXT | - | 描述 |
| Color | TEXT | - | 颜色 |
| IconName | TEXT | - | 图标 |
| SortOrder | INTEGER | 0 | 排序 |
| UsageCount | INTEGER | 0 | 使用次数 |
| IsBuiltIn | INTEGER | 0 | 是否内置 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| CreatedAt | TEXT | now() | 创建时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

唯一约束: `UNIQUE(GroupName, Name)`

---

### Tier 2 - 扩展功能表 (11张)

#### 13. Providers - LLM服务提供商
定义 LLM API 提供商信息。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Code | TEXT | - | 提供商代码 (唯一) |
| Name | TEXT | - | 显示名称 |
| Description | TEXT | - | 描述 |
| BaseUrl | TEXT | - | API基础URL |
| DefaultModel | TEXT | - | 默认模型 |
| AuthType | TEXT | 'Bearer' | 认证类型 |
| AuthHeader | TEXT | 'Authorization' | 认证头名称 |
| ChatEndpoint | TEXT | '/chat/completions' | 聊天端点 |
| ModelsEndpoint | TEXT | '/models' | 模型列表端点 |
| SupportsStreaming | INTEGER | 1 | 支持流式输出 |
| SupportsVision | INTEGER | 0 | 支持图像 |
| SupportsTools | INTEGER | 0 | 支持工具调用 |
| RateLimitRPM | INTEGER | - | 每分钟请求限制 |
| RateLimitTPM | INTEGER | - | 每分钟token限制 |
| Website | TEXT | - | 官网 |
| DocsUrl | TEXT | - | 文档URL |
| IconName | TEXT | - | 图标 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| SortOrder | INTEGER | 0 | 排序 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置提供商: openai, anthropic, azure, ollama, deepseek, groq, litellm, custom

---

#### 14. Models - LLM模型元数据
存储各提供商的模型信息。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| ProviderCode | TEXT | - | 提供商代码 |
| ModelId | TEXT | - | 模型ID |
| DisplayName | TEXT | - | 显示名称 |
| Description | TEXT | - | 描述 |
| ModelFamily | TEXT | - | 模型系列 |
| ContextWindow | INTEGER | 4096 | 上下文窗口大小 |
| MaxOutputTokens | INTEGER | 4096 | 最大输出token |
| InputPricePer1M | REAL | 0 | 输入价格($/1M tokens) |
| OutputPricePer1M | REAL | 0 | 输出价格($/1M tokens) |
| SupportsVision | INTEGER | 0 | 支持图像 |
| SupportsTools | INTEGER | 0 | 支持工具 |
| SupportsStreaming | INTEGER | 1 | 支持流式 |
| SupportsJson | INTEGER | 0 | 支持JSON模式 |
| IsChat | INTEGER | 1 | 是否聊天模型 |
| IsEmbedding | INTEGER | 0 | 是否嵌入模型 |
| IsDeprecated | INTEGER | 0 | 是否已弃用 |
| DeprecationDate | TEXT | - | 弃用日期 |
| ReleaseDate | TEXT | - | 发布日期 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| SortOrder | INTEGER | 0 | 排序 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

唯一约束: `UNIQUE(ProviderCode, ModelId)`

预置模型: gpt-4o, gpt-4o-mini, claude-3-5-sonnet, deepseek-chat, llama3.1 等

---

#### 15. LLMConfig - LLM配置
存储不同场景的LLM调用配置。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Name | TEXT | - | 配置名称 (唯一) |
| Description | TEXT | - | 描述 |
| ProviderCode | TEXT | - | 提供商代码 |
| ModelId | TEXT | - | 模型ID |
| BaseUrl | TEXT | - | 自定义API地址 |
| ApiKeyRef | TEXT | - | API密钥引用名 |
| MaxTokens | INTEGER | 4096 | 最大token数 |
| Temperature | REAL | 0.7 | 温度参数 |
| TopP | REAL | 1.0 | Top-P采样 |
| FrequencyPenalty | REAL | 0 | 频率惩罚 |
| PresencePenalty | REAL | 0 | 存在惩罚 |
| SystemPrompt | TEXT | - | 系统提示词 |
| StopSequences | TEXT | - | 停止序列 (JSON) |
| TimeoutMs | INTEGER | 60000 | 超时毫秒 |
| RetryCount | INTEGER | 3 | 重试次数 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsDefault | INTEGER | 0 | 是否默认配置 |
| SortOrder | INTEGER | 0 | 排序 |
| CreatedAt | TEXT | now() | 创建时间 |
| UpdatedAt | TEXT | now() | 更新时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置配置: Default (通用), Creative (创作), Precise (精确/编码)

---

#### 16. LLMCalls - LLM调用历史
记录所有LLM API调用，用于分析和调试。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| ConfigName | TEXT | - | 使用的配置名 |
| ProviderCode | TEXT | - | 提供商代码 |
| ModelId | TEXT | - | 模型ID |
| SystemPrompt | TEXT | - | 系统提示词 |
| UserPrompt | TEXT | - | 用户输入 |
| AssistantResponse | TEXT | - | 模型回复 |
| FinishReason | TEXT | - | 结束原因 |
| InputTokens | INTEGER | 0 | 输入token数 |
| OutputTokens | INTEGER | 0 | 输出token数 |
| TotalTokens | INTEGER | 0 | 总token数 |
| EstimatedCost | REAL | 0 | 预估费用 |
| DurationMs | INTEGER | 0 | 耗时毫秒 |
| FirstTokenMs | INTEGER | - | 首token延迟 |
| Success | INTEGER | 1 | 是否成功 |
| ErrorCode | TEXT | - | 错误代码 |
| ErrorMessage | TEXT | - | 错误信息 |
| CallerModule | TEXT | - | 调用模块 |
| CallerFunction | TEXT | - | 调用函数 |
| SessionId | TEXT | - | 会话ID |
| RequestId | TEXT | - | 请求ID |
| CallTime | TEXT | now() | 调用时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

索引: `idx_llmcalls_time`, `idx_llmcalls_config`, `idx_llmcalls_success`

---

#### 17. LLMPrompts - 提示词模板
存储可复用的提示词模板。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Name | TEXT | - | 模板名称 (唯一) |
| Category | TEXT | 'General' | 分类 |
| Description | TEXT | - | 描述 |
| SystemPrompt | TEXT | - | 系统提示词 |
| UserPromptTemplate | TEXT | - | 用户提示词模板 |
| Variables | TEXT | - | 变量列表 (JSON) |
| DefaultValues | TEXT | - | 变量默认值 (JSON) |
| OutputFormat | TEXT | 'text' | 输出格式 |
| RecommendedModel | TEXT | - | 推荐模型 |
| Temperature | REAL | - | 推荐温度 |
| MaxTokens | INTEGER | - | 推荐最大token |
| Examples | TEXT | - | 示例 (JSON) |
| ParentTemplate | TEXT | - | 父模板名 |
| Version | INTEGER | 1 | 版本号 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| SortOrder | INTEGER | 0 | 排序 |
| CreatedAt | TEXT | now() | 创建时间 |
| UpdatedAt | TEXT | now() | 更新时间 |
| CreatedBy | TEXT | - | 创建者 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置模板: translate_text, summarize, explain_code

变量语法: `{{variable_name}}`

---

#### 18. LLMApiKeys - API密钥存储
安全存储 LLM API 密钥 (加密)。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Name | TEXT | - | 密钥名称 (唯一) |
| ProviderCode | TEXT | - | 提供商代码 |
| ApiKey | TEXT | - | API密钥 (加密存储) |
| OrgId | TEXT | - | 组织ID |
| IsEncrypted | INTEGER | 1 | 是否已加密 |
| EncryptionMethod | TEXT | 'DPAPI' | 加密方法 |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsDefault | INTEGER | 0 | 是否默认 |
| UsageCount | INTEGER | 0 | 使用次数 |
| LastUsedAt | TEXT | - | 最后使用时间 |
| ExpiresAt | TEXT | - | 过期时间 |
| CreatedAt | TEXT | now() | 创建时间 |
| UpdatedAt | TEXT | now() | 更新时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

**安全说明**: API密钥默认使用 Windows DPAPI 加密，不以明文存储。

---

#### 19. ExceptionReports - 异常报告
记录应用程序异常和崩溃信息。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| ExceptionClass | TEXT | - | 异常类名 |
| ExceptionMessage | TEXT | - | 异常消息 |
| StackTrace | TEXT | - | 堆栈跟踪 |
| Module | TEXT | - | 模块名 |
| UnitName | TEXT | - | 单元名 |
| ClassName | TEXT | - | 类名 |
| MethodName | TEXT | - | 方法名 |
| LineNumber | INTEGER | - | 行号 |
| AppVersion | TEXT | - | 应用版本 |
| OSVersion | TEXT | - | 操作系统版本 |
| MachineName | TEXT | - | 机器名 |
| UserName | TEXT | - | 用户名 |
| ProcessId | INTEGER | - | 进程ID |
| ThreadId | INTEGER | - | 线程ID |
| UserAction | TEXT | - | 用户操作描述 |
| FormName | TEXT | - | 窗体名 |
| ControlName | TEXT | - | 控件名 |
| Severity | INTEGER | 2 | 严重程度: 1-5 |
| IsHandled | INTEGER | 0 | 是否已处理 |
| IsReported | INTEGER | 0 | 是否已上报 |
| ReportedAt | TEXT | - | 上报时间 |
| Resolution | TEXT | - | 解决方案 |
| OccurredAt | TEXT | now() | 发生时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

---

#### 20. AnimationAssets - 动画资源
存储 SVG/Lottie 动画资源。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Name | TEXT | - | 资源名称 (唯一) |
| DisplayName | TEXT | - | 显示名称 |
| Category | TEXT | 'General' | 分类 |
| Description | TEXT | - | 描述 |
| AssetType | TEXT | 'svg' | 类型: svg/lottie/gif |
| Content | TEXT | - | 内容 (SVG/JSON) |
| FilePath | TEXT | - | 文件路径 |
| ContentHash | TEXT | - | 内容哈希 |
| Width | INTEGER | 64 | 宽度 |
| Height | INTEGER | 64 | 高度 |
| FrameCount | INTEGER | 1 | 帧数 |
| FrameDuration | INTEGER | 100 | 帧间隔(ms) |
| Duration | INTEGER | - | 总时长(ms) |
| LoopCount | INTEGER | -1 | 循环次数 (-1=无限) |
| Author | TEXT | - | 作者 |
| License | TEXT | - | 许可证 |
| SourceUrl | TEXT | - | 来源URL |
| IsEnabled | INTEGER | 1 | 是否启用 |
| IsBuiltIn | INTEGER | 1 | 是否内置 |
| SortOrder | INTEGER | 0 | 排序 |
| CreatedAt | TEXT | now() | 创建时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

预置动画: spinner_circle, checkmark, error_cross

---

#### 21. Attachments - 附件存储
通用附件存储表。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| RefType | TEXT | - | 关联类型 (表名) |
| RefId | TEXT | - | 关联ID |
| FileName | TEXT | - | 文件名 |
| OriginalName | TEXT | - | 原始文件名 |
| FilePath | TEXT | - | 存储路径 |
| FileSize | INTEGER | 0 | 文件大小 |
| MimeType | TEXT | - | MIME类型 |
| ContentHash | TEXT | - | 内容哈希 |
| ThumbnailPath | TEXT | - | 缩略图路径 |
| IsEmbedded | INTEGER | 0 | 是否嵌入存储 |
| Content | BLOB | - | 文件内容 (嵌入时) |
| Description | TEXT | - | 描述 |
| UploadedBy | TEXT | - | 上传者 |
| UploadedAt | TEXT | now() | 上传时间 |
| CreatedAt | TEXT | now() | 创建时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

索引: `idx_attachments_ref`, `idx_attachments_hash`

---

#### 22. TagMappings - 标签关联
将标签关联到具体实体。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| TagId | INTEGER | - | 标签ID (FK → Tags.Id) |
| RefType | TEXT | - | 关联类型 (表名) |
| RefId | TEXT | - | 关联ID |
| CreatedAt | TEXT | now() | 创建时间 |
| CreatedBy | TEXT | - | 创建者 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

唯一约束: `UNIQUE(TagId, RefType, RefId)`  
外键: `FOREIGN KEY (TagId) REFERENCES Tags(Id) ON DELETE CASCADE`

使用示例:
```sql
-- 为日志记录添加标签
INSERT INTO TagMappings (TagId, RefType, RefId) 
VALUES (1, 'Logs', '123');

-- 获取某实体的所有标签
SELECT t.* FROM Tags t
JOIN TagMappings tm ON t.Id = tm.TagId
WHERE tm.RefType = 'Logs' AND tm.RefId = '123';
```

---

#### 23. Notifications - 用户通知
存储用户通知消息。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Id | INTEGER | AUTO | 主键 |
| Type | TEXT | 'Info' | 类型: Info/Warning/Error/Success |
| Title | TEXT | - | 标题 |
| Content | TEXT | - | 内容 |
| Source | TEXT | - | 来源模块 |
| RefType | TEXT | - | 关联类型 |
| RefId | TEXT | - | 关联ID |
| ActionUrl | TEXT | - | 点击跳转URL |
| IconName | TEXT | - | 图标 |
| IsRead | INTEGER | 0 | 是否已读 |
| ReadAt | TEXT | - | 已读时间 |
| IsDismissed | INTEGER | 0 | 是否已关闭 |
| DismissedAt | TEXT | - | 关闭时间 |
| ExpiresAt | TEXT | - | 过期时间 |
| Priority | INTEGER | 0 | 优先级 |
| UserId | TEXT | - | 用户ID |
| CreatedAt | TEXT | now() | 创建时间 |
| Extra | TEXT | - | JSON扩展 |
| Remarks | TEXT | - | 备注 |

索引: `idx_notifications_user`, `idx_notifications_read`, `idx_notifications_time`

---

## 使用指南

### 初始化数据库

1. **直接复制样例数据库**
   ```
   复制 UniBase\data\样例Config.db → 你的应用目录\Config.db
   ```

2. **使用 SQL 脚本创建**
   ```
   sqlite3 Config.db ".read UniBase\data\create_sample_db.sql"
   ```

3. **通过 UniBase API 创建**
   ```pascal
   ConfigDB.EnsureSchema;  // 自动创建所有表
   ```

### 删除不需要的表

产品交付前，可删除不需要的表：

```sql
-- 如果不用 LLM 功能，可删除
DROP TABLE IF EXISTS LLMCalls;
DROP TABLE IF EXISTS LLMPrompts;
DROP TABLE IF EXISTS LLMApiKeys;
DROP TABLE IF EXISTS LLMConfig;
DROP TABLE IF EXISTS Models;
DROP TABLE IF EXISTS Providers;

-- 如果不用标签功能，可删除
DROP TABLE IF EXISTS TagMappings;
DROP TABLE IF EXISTS Tags;
```

### Extra 字段使用

每张表都有 `Extra TEXT` 字段用于 JSON 扩展：

```sql
-- 存储扩展数据
UPDATE Settings SET Extra = '{"customField1": "value1", "customField2": 123}' 
WHERE Key = 'App.Language';

-- 读取扩展数据 (SQLite JSON 函数)
SELECT json_extract(Extra, '$.customField1') FROM Settings WHERE Key = 'App.Language';
```

### Categories 表使用

Categories 表是通用分类表，用于存放各种枚举/分类数据：

```sql
-- 添加任务类型分类
INSERT INTO Categories (GroupName, Code, Name, Description) VALUES
  ('TaskType', 'bug', '缺陷', '软件缺陷'),
  ('TaskType', 'feature', '功能', '新功能需求'),
  ('TaskType', 'improvement', '改进', '现有功能改进');

-- 获取某分类组的所有选项
SELECT * FROM Categories WHERE GroupName = 'TaskType' AND IsEnabled = 1 ORDER BY SortOrder;
```

---

## 版本历史

### v1.0.0 (2025-12-05)
- 初始版本
- 23 张基础设施表
- 完整的初始数据
- 支持 UTF-8 中文
