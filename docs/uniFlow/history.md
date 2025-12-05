# UniFlow 开发历史记录

> 记录已完成的开发任务、里程碑和重要决策

---

## Phase 1: 核心框架 ✅ (Week 1-2)

### 2024-12-04 ~ 2024-12-05

#### 完成项目骨架与基础设施
- ✅ 创建 `Source/` 目录结构
- ✅ 创建 `Config/workflows/` 配置目录
- ✅ 创建 `Config/schemas/` Schema 目录

#### 完成核心消息与角色定义
- ✅ `UniFlow.Core.Message.pas` - 消息基类与序列化
- ✅ `UniFlow.Core.Role.pas` - 角色基类与接口定义
- ✅ `UniFlow.Core.Engine.pas` - 消息驱动引擎核心

#### 完成配置加载系统
- ✅ `UniFlow.Config.Loader.pas` - YAML/JSON 配置加载器
- ✅ `UniFlow.Config.Types.pas` - 配置类型定义

---

## Phase 2: 调度能力 ✅ (Week 3)

### 2024-12-05

#### 完成 Workflow 定义数据结构
- ✅ `UniFlow.Workflow.Definition.pas` (~2400 行)
  - `TStepType` 枚举 (action, condition, loop, parallel, subworkflow, wait, end)
  - `TActionType` 枚举 (skill, llm, guard, log, assign, http, script)
  - `TConditionOperator` 枚举 (eq, ne, gt, lt, ge, le, contains, startsWith, endsWith, matches, isEmpty, isNotEmpty, in, and, or, not)
  - `TLoopMode`, `TWaitStrategy`, `TFailureStrategy` 枚举
  - `TRetryPolicy` - 重试策略配置
  - `TConditionExpression` - 条件表达式
  - `TOutputConfig` - 输出映射配置
  - `TActionDefinition` - 动作定义
  - `TConditionBranch` - 条件分支
  - `TLoopConfig` - 循环配置
  - `TParallelConfig` - 并行配置
  - `TWaitConfig` - 等待配置
  - `TErrorHandler` - 错误处理器
  - `TWorkflowStep` - 工作流步骤
  - `TWorkflowHook/TWorkflowHooks` - 生命周期钩子
  - `TTriggerConfig` - 触发器配置
  - `TWorkflowDefinition` - 工作流定义
  - 完整 JSON 序列化/反序列化支持
  - 验证和克隆方法

#### 完成 Workflow 上下文管理
- ✅ `UniFlow.Workflow.Context.pas` (~1400 行)
  - `TVariableScope` 枚举 (global, workflow, step, input, output)
  - `TVariableValue` - 多类型变量值存储
  - `TScopeFrame` - 作用域帧
  - `TWorkflowContext` - 上下文管理器
  - `TExpressionEvaluator` - 表达式求值器
  - 变量引用语法 `{{ vars.xxx }}`
  - 内置过滤器: `default`, `upper`, `lower`, `trim`, `json`, `truncate`

#### 完成 Workflow 步骤执行器
- ✅ `UniFlow.Workflow.Executor.pas` (~1400 行)
  - `TExecutionStatus` 枚举 (idle, running, paused, waiting, completed, failed, cancelled)
  - `TStepResult` - 步骤执行结果
  - `TExecutionCursor` - 执行游标
  - `IActionExecutor` - 可扩展动作执行器接口
  - `TWorkflowExecutor` - 主执行引擎
    - 线性步骤执行
    - 条件分支求值
    - 循环执行 (forEach, while, repeat)
    - 并行执行 (简化串行实现)
    - Wait/HumanTask 处理
    - 错误处理 (retry, fallback, goto)
    - 快照保存/恢复
  - 内置执行器: `TLogActionExecutor`, `TAssignActionExecutor`, `TGuardActionExecutor`

#### 完成 Workflow 状态持久化
- ✅ `UniFlow.Workflow.State.pas` (~1200 行)
  - `TWorkflowInstanceStatus` 枚举 (created, running, paused, waiting, completed, failed, cancelled)
  - `TWorkflowInstance` - 工作流实例
  - `TWorkflowSnapshot` - 状态快照
  - `TWorkflowEvent` - 执行事件
  - `IWorkflowStateStore` - 存储接口
  - `TMemoryWorkflowStateStore` - 内存存储实现
  - `TWorkflowStateManager` - 状态管理器
    - 实例创建与状态更新
    - 检查点保存/恢复
    - 事件记录

#### 完成示例 Workflow 定义
- ✅ `Config/workflows/simple_qa.workflow.json`
  - 演示输入验证 → LLM 调用 → 输出验证完整流程
  - 包含条件分支、错误处理、日志记录
  - 支持重试策略和备选响应

---

## Phase 3: AI 集成 ✅ (Week 4)

### 2024-12-05

#### 完成 UniBase 模块复用分析
- ✅ 分析 `UniBase.LLM.pas` (~1900 行) - 多 Provider LLM 客户端
- ✅ 分析 `UniBase.LLM.Manager.pas` (~1700 行) - Prompt 管理器
- ✅ 分析 `UniBase.EventBus.pas` - 发布/订阅事件总线
- ✅ 分析 `UniBase.StateMachine.pas` - 泛型状态机
- ✅ 分析 `UniBase.Validation.pas` - 数据验证框架
- ✅ 分析 `UniBase.Logging.pas` - 日志系统
- ✅ 分析 `UniBase.Config.pas` - 配置管理
- ✅ 分析 `UniBase.Scheduler.pas` - 任务调度
- ✅ 创建 `docs/unibase-reuse-strategy.md` 复用策略文档

#### 技术决策
- **TD-004**: UniFlow 复用 UniBase.LLM 而非自建 LLM 客户端
  - 删除重复的 `UniFlow.AI.Types.pas` 和 `UniFlow.AI.LLMClient.pas`
  - 创建轻量级 `UniFlow.AI.Adapter.pas` 适配层

### 2025-12-05

#### 完成 LLM 适配层
- ✅ **TASK-301R**: 创建 `UniFlow.AI.Adapter.pas` (~460 行)
  - `TLLMExecutionOptions` - LLM 执行选项
  - `TLLMExecutionResult` - 执行结果
  - `TUniFlowLLMAdapter` - 封装 UniBase.LLM 调用
  - `TLLMActionExecutor` - 实现 IActionExecutor 接口
  - `RegisterLLMExecutor` - 辅助注册函数
- ✅ **TASK-302R**: 清理重复文件
  - 删除 `Source/AI/UniFlow.AI.Types.pas` (~1198 行)
  - 删除 `Source/AI/UniFlow.AI.LLMClient.pas` (~707 行)
  - 净减少 ~1900 行重复代码
- ✅ **TASK-303**: 创建 Prompt 模板文件
  - `Config/prompts/system_default.txt` - 默认系统 Prompt
  - `Config/prompts/qa_assistant.txt` - 问答助手 Prompt
  - `Config/prompts/code_review.txt` - 代码审查 Prompt (JSON 输出)
- ✅ **TASK-305**: `TLLMActionExecutor` 已在 Adapter 中实现
  - 实现 `IActionExecutor` 接口
  - `RegisterLLMExecutor()` 辅助注册函数
- ✅ **TASK-306**: JSON 响应解析已在 Adapter 中实现
  - `ExtractJsonValue()` JSON 路径提取
  - `JsonOutputMap` 响应映射配置

#### 完成 Python Skill 服务和 Delphi 客户端
- ✅ **TASK-307**: 创建 Python Skill 服务框架
  - `Skills/src/main.py` (~380 行) - FastAPI 入口
  - `Skills/src/skills/base.py` (~340 行) - Skill 基类
  - `Skills/src/skills/code_executor.py` (~370 行) - 代码执行 Skill
  - `Skills/src/llm/client.py` (~360 行) - LiteLLM 封装
  - `Skills/requirements.txt` - 依赖清单
  - `Skills/Dockerfile` - 容器化部署
- ✅ **TASK-308**: 创建 Delphi Skill 客户端
  - `Source/Skill/UniFlow.Skill.Types.pas` (~980 行) - 类型定义
  - `Source/Skill/UniFlow.Skill.Client.pas` (~690 行) - HTTP 客户端
  - `Source/Skill/UniFlow.Skill.Executor.pas` (~740 行) - Skill 动作执行器

---

## Phase 4: 校验与安全 ✅ (Week 4)

### 2025-12-05

#### 完成 JSON Schema 校验器
- ✅ **TASK-401**: 创建 `UniFlow.Validation.Schema.pas` (~580 行)
  - `TSchemaError` - 校验错误记录
  - `TSchemaValidationResult` - 校验结果
  - `TJSONSchema` - JSON Schema 校验器
  - 支持: type, required, properties, items, minLength, maxLength, minimum, maximum, pattern, enum
- ✅ **TASK-402**: 创建预定义 Schema 文件
  - `Config/schemas/workflow_input.schema.json` - 工作流输入模式
  - `Config/schemas/llm_response.schema.json` - LLM 响应模式
  - `Config/schemas/user_request.schema.json` - 用户请求模式

#### 完成输入消毒模块
- ✅ **TASK-403**: 创建 `UniFlow.Security.Sanitizer.pas` (~530 行)
  - `TSanitizer` - 输入消毒器
    - HTML 实体编码
    - SQL 注入防护
    - 路径遍历防护
    - 文件名消毒
    - URL/Email 验证
  - `TPromptGuard` - Prompt 注入检测
    - 22 种危险模式检测
    - Prompt 消毒

#### 完成敏感信息过滤和限流
- ✅ **TASK-405**: 创建 `UniFlow.Security.Filter.pas` (~1070 行)
  - `TSensitiveCategory` - 敏感数据分类 (PII/凭证/金融/健康)
  - `TFilterPattern` - 过滤模式定义
  - `TSensitiveWordList` - 敏感词库
  - `TSensitiveFilter` - 敏感信息过滤器
    - 17 种预置模式 (Email, 电话, SSN, 信用卡, API Key, JWT 等)
    - 部分/完全/哈希脱敏模式
  - `TLogSanitizer` - 日志脱敏器
- ✅ **TASK-406**: 创建 `UniFlow.Security.RateLimit.pas` (~1360 行)
  - `TRateLimitPolicy` - 限流策略配置
  - `TTokenBucket` - 令牌桶算法
  - `TSlidingWindowCounter` - 滑动窗口计数器
  - `TRateLimiter` - 请求限流器
    - 多种作用域 (Global/User/Session/IP/Endpoint)
    - 多种算法 (固定窗口/滑动窗口/令牌桶/漏桶)
  - `TTokenQuotaManager` - Token 配额管理
    - 每用户配额
    - 自动重置 (日/周/月)

---

## Phase 5: 会话管理 ✅ (Week 4)

### 2025-12-05

#### 完成会话类型定义
- ✅ **TASK-502**: 创建 `UniFlow.Session.Types.pas` (~510 行)
  - `TSessionStatus` - 会话状态枚举
  - `TMessageRole` - 消息角色
  - `TChatMessage` - 聊天消息记录
  - `TSession` - 会话类（消息历史、变量存储、JSON 序列化）
  - `TSessionConfig` - 会话配置

#### 完成会话管理器
- ✅ **TASK-501**: 创建 `UniFlow.Session.Manager.pas` (~660 行)
  - `ISessionStore` - 存储接口
  - `TMemorySessionStore` - 内存存储实现
  - `TFileSessionStore` - 文件存储实现 (JSON)
  - `TSessionManager` - 会话管理器
    - 创建/查找/关闭/删除会话
    - 自动过期清理
    - 用户会话限制
    - 会话事件
    - 统计信息
- ✅ **TASK-503**: 会话上下文已集成到 TSession 类

#### 完成 Commander 角色
- ✅ **TASK-505**: 创建 `UniFlow.Roles.Commander.pas` (~1080 行)
  - `TUserRequest` / `TCommanderResponse` - 请求响应类型
  - `TIntent` / `TIntentRecognizer` - 意图识别器
    - 正则模式匹配
    - 关键词匹配
    - 优先级排序
  - `TCommander` - 请求入口和路由
    - 意图识别
    - Workflow 路由
    - 响应组装
    - 事件回调
  - `TSimpleWorkflowRegistry` - Workflow 注册表

---

## Phase 6: 集成测试 ✅ (Week 4)

### 2025-12-05

#### 完成测试框架
- ✅ **TASK-601**: 创建 `UniFlow.Test.Framework.pas` (~620 行)
  - `TTestStatus` - 测试状态枚举
  - `TTestResult` / `TTestSuiteResult` - 测试结果
  - `TTestCase` - 测试用例基类 (20+ 断言方法)
  - `TTestRunner` - 测试运行器 (RTTI 方法发现)

#### 完成核心测试用例
- ✅ **TASK-602**: 创建 `UniFlow.Test.Core.pas` (~840 行)
  - `TWorkflowContextTest` - 8 个测试 (变量、作用域、表达式、过滤器)
  - `TWorkflowDefinitionTest` - 6 个测试 (创建、步骤、验证、JSON)
  - `TWorkflowExecutorTest` - 4 个测试 (Log、Assign、条件、循环)
  - `TWorkflowStateTest` - 4 个测试 (实例、状态、快照、事件)
  - `TSchemaValidationTest` - 8 个测试 (JSON Schema 校验)
  - `TSanitizerTest` - 6 个测试 (输入消毒)
  - `TSessionTest` - 6 个测试 (会话管理)
  - **共计**: 42 个单元测试

#### 完成性能基准测试
- ✅ **TASK-603**: 创建 `UniFlow.Test.Performance.pas` (~1290 行)
  - `TBenchmarkMeasurement` - 基准测量结果
  - `TBenchmarkRunner` - 性能测试运行器
    - 预热执行
    - P50/P95/P99 百分位计算
    - 内存使用跟踪
    - 并发基准测试
  - 5 个测试套件:
    - `TContextPerformanceTests` - 上下文操作性能
    - `TWorkflowParsingTests` - Workflow 解析性能
    - `TSessionPerformanceTests` - 会话管理性能
    - `TIntentPerformanceTests` - 意图识别性能
    - `TValidationPerformanceTests` - 校验性能
  - `QuickPerformanceCheck()` - 快速性能检查函数

#### 完成文档和示例
- ✅ **TASK-604**: 创建开发文档
  - `docs/api-reference.md` - 完整 API 参考文档
    - 核心组件 API
    - Workflow 定义 API
    - Session 管理 API
    - Commander API
    - AI 集成 API
    - 校验与安全 API
    - 事件回调说明
    - 线程安全说明
  - `docs/quick-start.md` - 快速入门指南
    - 5 分钟上手教程
    - 常见模式示例
    - 配置说明
    - 故障排除
- ✅ **TASK-605**: 创建示例项目
  - `Examples/QAChatbot/` - Q&A 机器人示例
    - `workflow_qa.json` - Workflow 定义
    - `QAChatbotExample.pas` - 完整示例代码
  - `Examples/CodeAssistant/` - 代码助手示例
    - `workflow_code_assistant.json` - 多分支 Workflow
  - `Examples/MultiTurnChat/` - 多轮对话示例
    - `workflow_multiturn.json` - 上下文感知 Workflow

---

## 里程碑达成

### M1: Hello World (Week 2 Target) - ✅ 完成
- ✅ 能执行简单硬编码 Workflow
- ✅ LLM 适配层已完成 (UniFlow.AI.Adapter)
- ✅ 核心模块单元测试通过

### M2: 完整流程 (Week 4 Target) - ✅ 完成
- ✅ 支持条件分支、循环、错误处理
- ✅ Commander 请求路由
- ✅ 意图识别
- ✅ 完整示例项目

### M3: 生产就绪 (Week 6 Target) - ✅ 完成
- ✅ 性能基准测试
- ✅ 文档完整
- ✅ 敏感信息过滤
- ✅ 请求限流和 Token 配额管理

---

## 技术决策记录

### TD-001: Workflow 定义格式
- **决策**: 同时支持 JSON 和 YAML 格式
- **原因**: JSON 便于程序处理，YAML 便于人工编写
- **日期**: 2024-12-05

### TD-002: 变量引用语法
- **决策**: 采用 `{{ expression }}` 语法，支持过滤器
- **原因**: 与主流模板引擎兼容，学习成本低
- **日期**: 2024-12-05

### TD-003: 状态持久化策略
- **决策**: 先实现内存存储，后续添加 SQLite 实现
- **原因**: 快速验证设计，降低初期复杂度
- **日期**: 2024-12-05

---

## 代码统计

| 模块 | 文件 | 行数 | 状态 |
|------|------|------|------|
| Workflow.Definition | pas | ~2400 | ✅ |
| Workflow.Context | pas | ~1400 | ✅ |
| Workflow.Executor | pas | ~1400 | ✅ |
| Workflow.State | pas | ~1200 | ✅ |
| AI.Adapter | pas | ~460 | ✅ |
| Validation.Schema | pas | ~580 | ✅ |
| Security.Sanitizer | pas | ~530 | ✅ |
| Session.Types | pas | ~510 | ✅ |
| Session.Manager | pas | ~660 | ✅ |
| Roles.Commander | pas | ~1080 | ✅ |
| Test.Framework | pas | ~620 | ✅ |
| Test.Core | pas | ~840 | ✅ |
| Test.Performance | pas | ~1290 | ✅ |
| Security.Filter | pas | ~1070 | ✅ |
| Security.RateLimit | pas | ~1360 | ✅ |
| Skill.Types | pas | ~980 | ✅ |
| Skill.Client | pas | ~690 | ✅ |
| Skill.Executor | pas | ~740 | ✅ |
| Audit.Types | pas | ~1,160 | ✅ |
| Audit.Store | pas | ~1,020 | ✅ |
| Audit.Manager | pas | ~1,050 | ✅ |
| **Pascal 合计** | **21 files** | **~21,030** | ✅ |

### Python 代码

| 模块 | 文件 | 行数 | 状态 |
|------|------|------|------|
| main.py | py | ~380 | ✅ |
| skills/base.py | py | ~340 | ✅ |
| skills/code_executor.py | py | ~370 | ✅ |
| llm/client.py | py | ~360 | ✅ |
| **Python 合计** | **4 files** | **~1,450** | ✅ |

---

## Phase 7: 可选增强 [P2]

### 2025-12-05

#### TASK-701: 审计日志增强 ✅
- ✅ 创建 `Source/Audit/UniFlow.Audit.Types.pas` (~1,160 行)
  - `TAuditCategory` - 审计类别 (System/Workflow/Session/Security/LLM/Skill/User/Error)
  - `TAuditSeverity` - 严重级别 (Debug/Info/Warning/Error/Critical)
  - `TAuditAction` - 35+ 审计动作类型
  - `TAuditEntry` - 审计日志条目 (Fluent API)
  - `TAuditQuery` - 查询构建器 (时间/类别/严重级别/关键词/分页)
  - `TAuditQueryResult` - 分页查询结果
  - `TAuditStats` - 聚合统计
  - `TAuditReport` - 报告结构
  - 工厂函数: `CreateAuditEntry`, `CreateSystemEntry`, `CreateWorkflowEntry` 等
- ✅ 创建 `Source/Audit/UniFlow.Audit.Store.pas` (~1,020 行)
  - `IAuditStore` - 存储接口
  - `TAuditStoreConfig` - 存储配置 (保留天数/批量大小/自动清理)
  - `TMemoryAuditStore` - 内存存储实现 (完整查询支持)
  - `TSQLiteAuditStore` - SQLite 存储占位 (Schema 已定义)
  - `TFileAuditStore` - JSON Lines 文件存储 (日志轮转)
- ✅ 创建 `Source/Audit/UniFlow.Audit.Manager.pas` (~1,050 行)
  - `TAuditManager` - 中央审计管理器
    - 日志级别过滤
    - 默认上下文 (用户/会话)
    - 关联 ID 追踪
    - 便捷方法: `LogSystem`, `LogWorkflow`, `LogSession`, `LogSecurity`, `LogLLM`, `LogSkill`, `LogError`
    - 事件订阅 (按类别/严重级别/自定义过滤)
    - 查询 API: `Query`, `GetStats`, `GetRecent`, `GetErrors`, `GetByCorrelation`
  - `TAuditReportGenerator` - 报告生成器
    - 汇总报告 (Text/HTML/JSON)
    - 详细报告 (CSV/JSON)
    - 错误报告
    - 性能报告
    - 安全审计报告
    - 导出: CSV, JSON Lines
  - 全局实例: `AuditManager()` 函数
  - 初始化: `InitializeAuditManager`, `FinalizeAuditManager`

#### TASK-702: 监控指标 ✅
- ✅ 创建 `Source/Metrics/UniFlow.Metrics.Types.pas` (~1,280 行)
  - `TMetricType` - 指标类型 (Counter/Gauge/Histogram/Summary)
  - `TMetricLabels` - 标签键值对
  - `TCounterValue` - 计数器指标
  - `TGaugeValue` - 仪表指标
  - `THistogramValue` - 直方图指标 (分桶统计)
  - `TSummaryValue` - 摘要指标 (分位数计算)
  - `TMetricFamily` - 指标族
  - `TDefaultBuckets` - 预定义分桶 (HTTP/LLM/Token)
  - `TDefaultQuantiles` - 预定义分位数
  - Prometheus 文本格式导出
  - JSON 格式导出
- ✅ 创建 `Source/Metrics/UniFlow.Metrics.Collector.pas` (~910 行)
  - `TMetricsRegistry` - 中央指标注册表
    - 命名空间/子系统支持
    - Counter/Gauge/Histogram/Summary 注册
    - Prometheus/JSON 导出
  - `TUniFlowMetrics` - 预定义 UniFlow 指标
    - Workflow: started/completed/failed/duration/active
    - Step: executed/failed/duration
    - LLM: requests/errors/duration/tokens/cost
    - Skill: invocations/errors/duration
    - Session: active/created/expired/messages
    - RateLimit: hits/quota_exceeded
    - System: uptime
  - `TMetricsHTTPHandler` - HTTP 端点处理器
  - `TMetricTimer` - 计时器帮助类
  - 全局实例: `Metrics()` 函数

#### TASK-703: 多语言 Skill ✅
- ✅ 创建 Node.js Skill 服务 `Skills/nodejs/`
  - `package.json` - 依赖配置 (Express/Zod/Winston/OpenAI)
  - `src/index.js` (~330 行) - Express 服务入口
    - 健康检查 /health
    - 技能发现 /skills
    - 技能执行 /skills/:name/execute
    - 批量执行 /batch/execute
  - `src/skills/base.js` (~260 行) - Skill 基类
    - Zod Schema 验证
    - JSON Schema 生成
    - 超时/重试辅助函数
  - `src/skills/registry.js` (~86 行) - 技能注册表
  - `src/skills/json-transform.js` (~227 行) - JSON 变换技能
  - `src/skills/http-request.js` (~177 行) - HTTP 请求技能
  - `src/skills/text-process.js` (~194 行) - 文本处理技能
  - `Dockerfile` - 容器化部署 (Node 20 Alpine)
- 内置技能:
  - `json_transform` - JSON 数据变换 (extract/rename/map/filter/merge)
  - `http_request` - HTTP 请求 (GET/POST/超时/重试)
  - `text_process` - 文本处理 (uppercase/replace/template/hash)

---

## TASK-704: Visual Workflow Editor (Web UI)
**Completed**: 2025-12-05

### Files Created (~2,600 lines)

**Editor/index.html** (~220 lines)
- Main HTML structure with header toolbar, node palette sidebar, canvas area, properties panel, status bar
- Node template for drag-drop creation

**Editor/css/editor.css** (~519 lines)
- CSS variables with Catppuccin Mocha dark theme
- Layout styles for header, sidebar, canvas, properties panel
- Toolbar and button styles

**Editor/css/nodes.css** (~299 lines)
- Node card styles with type-specific colors
- Port styles for input/output connections
- Connection path styles and animations

**Editor/js/utils.js** (~238 lines)
- Utility functions: generateId, deepClone, debounce, clamp
- EventEmitter class for pub/sub
- UndoManager with 50-level history
- SVG helper functions for connection paths

**Editor/js/node-types.js** (~746 lines)
- 14 node type definitions: start, end, llm, skill, http, script, assign, log, condition, loop, parallel, wait, subworkflow, guard
- Property schemas with validation
- toWorkflowStep converters for export

**Editor/js/canvas.js** (~578 lines)
- WorkflowCanvas class with pan/zoom/drag
- Node management: add, remove, render, update
- Connection management with bezier paths
- Selection handling for nodes and connections
- Drag-drop from palette, keyboard shortcuts

**Editor/js/properties.js** (~359 lines)
- PropertiesPanel class
- Property editors: string, text, number, boolean, select, json, array, branches
- Real-time property updates with debouncing

**Editor/js/editor.js** (~428 lines)
- WorkflowEditor main controller
- File operations: new, open, save, export
- Undo/redo support
- Keyboard shortcuts (Ctrl+S, Ctrl+Z, etc.)
- localStorage persistence

### Features
- Drag-drop node creation from categorized palette
- Visual connection drawing between ports
- Multi-select with Shift/Ctrl
- Pan with mouse drag, zoom with scroll wheel
- Fit-to-view and zoom controls
- Properties panel with type-specific editors
- Export to UniFlow workflow JSON format
- Import existing workflow definitions
- Auto-save to browser localStorage
- Undo/redo with 50-level history

---

## Phase 8: 调试与诊断

### 2025-12-05

#### TASK-901: 诊断模块 ✅
- ✅ 创建 Source/Diagnostics/UniFlow.Diagnostics.pas (~1,200 行)
  - TLogLevel - 日志级别 (Trace/Debug/Info/Warning/Error/Fatal)
  - TTraceLevel - 追踪级别 (Off/Minimal/Normal/Verbose)
  - TLogEntry - 日志条目 (支持 CorrelationId/WorkflowId/StepId)
  - ILogger / ILoggerFactory - 日志接口（宿主可注入）
  - TConsoleLogger - 默认控制台日志（ANSI 彩色）
  - TTraceEntry - 执行追踪条目
  - TErrorContext - 错误上下文（变量/输入/堆栈/执行路径）
  - TUniFlowDiagnostics - 核心诊断类
    - 日志方法: Trace/Debug/Info/Warning/Error/Fatal
    - 步骤追踪: TraceStepEnter/TraceStepExit/TraceStepError
    - 错误上下文: CaptureErrorContext
    - 状态导出: DumpState/ExportTrace
    - 事件钩子: OnBeforeStep/OnAfterStep/OnError
  - 全局实例: Diagnostics() 函数
  - 设计原则: 零侵入、可插拔、低开销

#### TASK-902: CorrelationId 支持 ✅
- ✅ 创建 Source/Diagnostics/UniFlow.Diagnostics.Integration.pas (~408 行)
  - TWorkflowDiagnostics - 工作流诊断包装器
    - 自动管理 CorrelationId 生命周期
    - StepBegin/StepEnd/StepError 快捷方法
    - CaptureError 错误上下文收集
  - THTTPDiagnostics - HTTP 请求诊断助手
    - AddTraceHeaders - 添加追踪头
    - ExtractCorrelationId - 提取追踪 ID
  - TLLMDiagnostics - LLM 调用诊断助手
    - LogRequest/LogResponse/LogTokenUsage
  - TSkillDiagnostics - Skill 调用诊断助手
  - HTTP 追踪头常量: X-Correlation-ID, X-Trace-ID 等

#### TASK-903: 错误上下文收集 ✅
- ✅ 创建 Source/Diagnostics/UniFlow.Diagnostics.ErrorCollector.pas (~931 行)
  - TErrorSeverity - 错误严重级别 (Warning/Error/Critical/Fatal)
  - TErrorCategory - 13种错误分类 (Validation/Network/Timeout/LLM/Skill等)
  - TEnhancedErrorContext - 增强错误上下文
    - 追踪信息 (CorrelationId/WorkflowId/StepId)
    - 执行路径 (已执行步骤列表)
    - 环境信息 (机器名/进程ID/线程ID)
    - 自动建议生成
  - TErrorCollector - 错误收集器
    - 自动错误分类
    - 按 CorrelationId/WorkflowId/Category/Severity 查询
    - 导出: JSON/Markdown/CSV

#### TASK-904: 执行轨迹导出 ✅
- ✅ 创建 Source/Diagnostics/UniFlow.Diagnostics.TraceExporter.pas (~661 行)
  - TExecutionSnapshot - 执行快照 (用于复现问题)
  - TTraceExporter - 轨迹导出器
    - 创建/保存/加载快照
    - 多种导出格式 (JSON/Text/Markdown/Timeline)
    - 执行报告生成
    - 时间线报告
    - 性能报告

#### TASK-905: 调试模式 ✅
- ✅ 创建 Source/Diagnostics/UniFlow.Diagnostics.Debugger.pas (~1,100 行)
  - TDebuggerState - 调试器状态 (Idle/Running/Paused/Stepping/Breakpoint)
  - TBreakpointType - 断点类型 (Step/Conditional/Error/Watch)
  - TBreakpoint - 断点定义 (支持忽略计数/命中计数)
  - TDebugFrame - 调试帧 (调用栈)
  - TWorkflowDebugger - 工作流调试器
    - 断点管理: Add/Remove/Enable/Disable
    - 执行控制: Continue/Pause/StepInto/StepOver/StepOut/Stop
    - 调用栈: GetCallStack/GetCallStackDepth
    - 变量检查: GetVariables/GetVariable/EvaluateExpression
  - TDebugConsole - 交互式调试控制台
    - GDB风格命令: c/s/n/o/bt/v/b/d/bl/e

---

### Phase 8 代码统计

| 模块 | 文件 | 行数 |
|------|------|------|
| Diagnostics | pas | ~1,200 |
| Diagnostics.Integration | pas | ~408 |
| Diagnostics.ErrorCollector | pas | ~931 |
| Diagnostics.TraceExporter | pas | ~661 |
| Diagnostics.Debugger | pas | ~1,100 |
| **Phase 8 合计** | **5 files** | **~4,300** |
