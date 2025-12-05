# UniFlow MVP 开发任务清单

> **创建时间**: 2025-12-04  
> **更新时间**: 2025-12-04 (团队评审后)  
> **基于文档**: `06.11.Dev-UniFlow-MVP定义与实现指南` / `06.12.Dev-UniFlow-落地实施策略与避坑指南`  
> **目标**: 8 周内完成 MVP，验证核心架构

---

## 🎯 2025-12-04 团队评审行动计划

> 参与评审角色：盘古(架构师) / 灵儿(产品经理) / 鲁班(开发者) / 仙儿(安全专家) / 李冰(测试工程师)

### 第一周：文档完善 + 骨架搭建 (2025-12-04 ~ 12-10)

#### P0 级（立即执行）

| 任务 | 负责人 | 产出物 | 状态 |
|------|--------|--------|------|
| Prompt安全规范 | 仙儿 | `08.15.Quality-UniFlow-Prompt安全规范-v1.0.md` | ✅ |
| Python服务异常恢复流程 | 鲁班 | 补充到 `06.14.Dev-UniFlow-IPC通信详细设计-v1.0.md` | ✅ |
| 骨架项目初始化 | 鲁班 | `uniFlow/Source/` 目录结构 | ✅ |
| Mock LLM服务搭建 | 李冰 | `Skills/tests/mock_llm.py` | ✅ |

#### P1 级（本周完成）

| 任务 | 负责人 | 产出物 | 状态 |
|------|--------|--------|------|
| 消息总线可靠性设计 | 盘古 | `03.16.Arch-UniFlow-消息总线设计-v1.0.md` 或补充到03.01 | ✅ |
| AI输出质量测试策略 | 李冰 | `08.17.Quality-UniFlow-AI质量测试策略-v1.0.md` | ✅ |
| MCP第三方服务准入标准 | 仿安 | 补充到 `08.01` 或新建文档 | ✅ |
| 成功标准量化 | 灵儿 | 补充到 `01.00.Product-UniFlow-核心定位-v1.0.md` | ✅ |
| Golden Dataset定义 | 李冰 | `Tests/golden_dataset/` | ✅ |

#### P2 级（下周完成）

| 任务 | 负责人 | 产出物 | 状态 |
|------|--------|--------|------|
| Skill脚手架CLI工具 | 鲁班 | `Tools/CLI/uniflow-skill-create.py` | ✅ |
| 性能基准测试方案 | 李冰 | `08.19.Quality-UniFlow-性能基准-v1.0.md` | ✅ |
| Workflow版本迁移策略 | 盘古 | `ADR/ADR-001-Workflow版本迁移策略.md` | ✅ |
| 数据库迁移脚本管理 | 鲁班 | `sql/migrations/README.md` | ✅ |

### 第二周：最小可运行系统 (2025-12-11 ~ 12-17)

**目标**: 黄金路径跑通，5分钟Demo就绪

| 任务 | 负责人 | 验收标准 | 状态 |
|------|--------|----------|------|
| Engine+核心角色可运行 | 鲁班 | Commander/Executor/Guard/Chronicler 消息流转 | ✅ |
| SkillLLM跑通 | 鲁班 | Delphi→Python→LLM→返回 | ✅ |
| Guard基础校验 | 仙儿 | 输入/输出校验框架 | ✅ |
| 审计日志框架 | 仙儿 | 基础审计事件记录 | ✅ |
| CI流程配置 | 李冰 | 每次提交运行基础测试 | ✅ |
| 黄金路径Demo | 灵儿 | 5分钟演示脚本 | ✅ |

### 关键里程碑

```
Week1 End (12-10): 骨架项目+核心角色可运行，P0文档完成
Week2 End (12-17): 黄金路径跑通，5分钟Demo就绪
Week3 End (12-24): MVP核心功能完成
```

### 评审发现的改进清单汇总

| 优先级 | 类别 | 改进项 | 文档/代码 | 负责人 |
|--------|------|--------|-----------|--------|
| P0 | 安全 | Prompt注入防护策略 | 新建08.15 | 仙儿+盘古 |
| P0 | 开发 | Python服务异常恢复详细流程 | 补充06.14 | 鲁班 |
| P1 | 架构 | 消息总线可靠性保障 | 新建03.16 | 盘古 |
| P1 | 测试 | AI输出质量测试策略 | 新建08.17 | 李冰 |
| P1 | 安全 | MCP第三方服务准入标准 | 补充08.01 | 仙儿 |
| P2 | 开发 | Skill脚手架CLI工具 | 新建CLI | 鲁班 |
| P2 | 产品 | 成功标准量化 | 补充01.00 | 灵儿 |
| P2 | 测试 | 性能基准测试方案 | 新建08.19 | 李冰 |
| P3 | 架构 | Workflow版本迁移策略 | ADR | 盘古 |
| P3 | 开发 | 数据库迁移脚本管理 | 新建README | 鲁班 |

---

## Phase 0: 连通性验证 (The Bridge) - Week 1

### 目标
打通 Delphi -> Python HTTP -> LLM 的完整链路。

### 任务

- [x] 创建项目目录结构
- [x] 创建 Python FastAPI 骨架 (`Skills/src/main.py`)
- [x] 创建 Delphi 工程骨架 (`Source/UniFlow.dpr`)
- [x] 创建 HTTP Client 封装 (`UniFlow.Skill.Client.pas`)
- [x] 创建基础配置文件 (`Config/uniFlow.config.json`)
- [ ] 验证 Python 服务启动 (`pip install` + `python main.py`)
- [ ] 验证 Delphi 编译通过
- [ ] 实现 Delphi 调用 Python `/execute` 端点并获取响应
- [ ] 实现 Python 进程由 Delphi 自动启动/管理

---

## Phase 1: 核心框架 (Core Framework) - Week 2

### 目标
实现消息驱动的角色运行时基础。

### 任务

- [ ] 定义消息基类 `TUniFlowMessage` (MsgId, CorrelationId, From, To, Timestamp)
- [ ] 实现消息序列化 `ToJSON` / `FromJSON`
- [ ] 定义角色接口 `IUniFlowRole` (GetRoleName, HandleMessage, Start, Stop)
- [ ] 实现 `TUniFlowEngine` 消息循环 (内存队列 + 事件驱动)
- [ ] 实现角色注册与路由机制
- [ ] 实现配置加载器 (读取 `uniFlow.config.json`)

### 产出文件
- `Source/Core/UniFlow.Message.pas`
- `Source/Core/UniFlow.Role.pas`
- `Source/Core/UniFlow.Engine.pas` (完善)
- `Source/Core/UniFlow.Config.pas`

---

## Phase 2: 调度能力 (Workflow Engine) - Week 3-4

### 目标
实现简易状态机式的 Workflow 执行器。

### 任务

- [ ] 定义 Workflow 数据结构 (`TWorkflowDefinition`, `TWorkflowStep`)
- [ ] 实现 YAML/JSON Workflow 解析器
- [ ] 实现步骤执行器 (线性执行 + 简单分支)
- [ ] 实现变量上下文管理 (`TWorkflowContext`)
- [ ] 实现状态持久化 (SQLite: `workflow_instances`, `step_cursor`)
- [ ] 实现断点恢复机制

### 产出文件
- `Source/Workflow/UniFlow.Workflow.Definition.pas`
- `Source/Workflow/UniFlow.Workflow.Parser.pas`
- `Source/Workflow/UniFlow.Workflow.Executor.pas`
- `Source/Workflow/UniFlow.Workflow.State.pas`
- `Config/schemas/workflow.schema.json`

### 里程碑 M1 (Week 2 末)
- [ ] 能执行简单硬编码 Workflow
- [ ] 能调用 LLM 并返回结果

---

## Phase 3: AI 集成 (Advisor Role) - Week 5

### 目标
完善 Advisor 角色，封装 LLM 调用能力。

### 任务

- [ ] 实现 `IAdvisor` 接口 (Query, QueryAsync)
- [ ] 实现 Prompt 模板引擎 (变量替换, 条件块)
- [ ] 实现响应解析器 (提取 JSON/置信度)
- [ ] 实现置信度分级路由 (High/Medium/Low)
- [ ] 完善 Python 侧 LiteLLM 集成
- [ ] 实现 Mock AI 模式 (读取配置 `UseMockAI`)

### 产出文件
- `Source/Roles/UniFlow.Advisor.pas`
- `Source/AI/UniFlow.Prompt.Template.pas`
- `Source/AI/UniFlow.Response.Parser.pas`
- `Skills/src/skills/llm_skill.py`

---

## Phase 4: 校验与安全 (Guard Role) - Week 5

### 目标
实现输入输出校验和基础安全检查。

### 任务

- [ ] 实现 `IGuard` 接口 (ValidateInput, ValidateOutput, CheckSecurity)
- [ ] 实现 JSON Schema 校验器
- [ ] 实现输入消毒 (防注入)
- [ ] 实现敏感信息过滤
- [ ] 实现基础速率限制

### 产出文件
- `Source/Roles/UniFlow.Guard.pas`
- `Source/Utils/UniFlow.JSON.Schema.pas`
- `Source/Utils/UniFlow.Sanitizer.pas`
- `Config/schemas/input.schema.json`

### 里程碑 M2 (Week 4 末)
- [ ] 支持条件分支、循环的复杂 Workflow
- [ ] 支持错误处理与重试

---

## Phase 5: 会话与日志 (Commander + Chronicler) - Week 6

### 目标
实现会话管理和审计日志。

### 任务

- [ ] 实现 `ICommander` 接口 (ParseRequest, ManageSession, RouteToWorkflow)
- [ ] 实现会话生命周期管理 (Create, Resume, Terminate)
- [ ] 实现会话上下文存储 (SQLite: `sessions`, `session_context`)
- [ ] 实现 `IChronicler` 接口 (LogEvent, GetAuditTrail)
- [ ] 实现结构化日志写入 (JSON 格式)
- [ ] 实现 SQLite 审计表

### 产出文件
- `Source/Roles/UniFlow.Commander.pas`
- `Source/Roles/UniFlow.Chronicler.pas`
- `Source/Core/UniFlow.Session.pas`
- `Source/Utils/UniFlow.Logger.pas`

---

## Phase 6: 集成测试 (Integration) - Week 7-8

### 目标
端到端测试，性能验证，文档完善。

### 任务

- [ ] 编写单元测试 (每个角色)
- [ ] 编写集成测试 (完整 Workflow)
- [ ] 编写错误场景测试 (LLM 超时, 校验失败)
- [ ] 性能基准测试 (消息延迟 <10ms, 并发 >100)
- [ ] 完善 README 和开发者文档
- [ ] 清理代码和注释

### 里程碑 M3 (Week 6 末)
- [ ] 审计功能完备
- [ ] 性能达标
- [ ] 文档完整

### 产出文件
- `Tests/Unit/*.pas`
- `Tests/Integration/*.pas`
- `README.md`

---

## 验收标准 (Acceptance Criteria)

| 场景 | 描述 | 通过标准 |
|------|------|----------|
| 简单问答 | 用户提问，AI 回答 | 正确返回，<3秒 |
| 条件分支 | 基于用户输入走不同分支 | 正确路由 |
| 置信度路由 | 低置信度触发人工审核 | 正确识别并路由 |
| 错误恢复 | LLM 超时后重试 | 3次重试后优雅失败 |
| 会话恢复 | 应用重启后恢复会话 | 状态正确恢复 |

---

## 性能基准 (Performance Benchmarks)

| 指标 | 目标值 |
|------|--------|
| 消息处理延迟 | <10ms (不含 LLM) |
| Workflow 解析 | <100ms |
| 并发会话数 | >100 |
| 内存占用 | <200MB (100 会话) |

---

## 风险与依赖

| 风险 | 缓解措施 |
|------|----------|
| Python 环境依赖 | 使用 Embeddable Python，打包 site-packages |
| IPC 延迟 | HTTP Keep-Alive，本地回环优化 |
| Workflow 引擎复杂度 | 保持简单状态机，不做复杂图调度 |
| JSON 处理 Bug | 使用 System.JSON，禁止手动拼接 |

---

## 相关文档

- `06.11.Dev-UniFlow-MVP定义与实现指南-v1.0.md`
- `06.12.Dev-UniFlow-落地实施策略与避坑指南-v1.0.md`
- `03.01.Arch-UniFlow架构设计-v1.0.md`
- `05.01.API-UniFlow接口规范-v1.0.md`
